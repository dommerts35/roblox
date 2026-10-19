--[[
	ClientController.client.lua
	Cliente: camara fija por jugador, controles de deslizamiento y
	marcador en pantalla.
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameEvent = Remotes:WaitForChild("GameEvent")

local SIDES = Config.Sides
local SLIDE = Config.Slide

-- Interfaz -------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "Marcador"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.fromScale(0.5, 0.02)
panel.Size = UDim2.fromOffset(460, 64)
panel.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
panel.BackgroundTransparency = 0.15
panel.BorderSizePixel = 0
panel.Parent = gui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.Padding = UDim.new(0, 6)
layout.Parent = panel

local message = Instance.new("TextLabel")
message.Name = "Mensaje"
message.AnchorPoint = Vector2.new(0.5, 0.5)
message.Position = UDim2.fromScale(0.5, 0.38)
message.Size = UDim2.fromOffset(700, 90)
message.BackgroundTransparency = 1
message.Font = Enum.Font.FredokaOne
message.TextScaled = true
message.Text = ""
message.TextColor3 = Color3.fromRGB(255, 255, 255)
message.TextStrokeTransparency = 0.4
message.TextTransparency = 1
message.Parent = gui

local messageScale = Instance.new("UITextSizeConstraint")
messageScale.MaxTextSize = 56
messageScale.Parent = message

local help = Instance.new("TextLabel")
help.AnchorPoint = Vector2.new(0.5, 1)
help.Position = UDim2.fromScale(0.5, 0.98)
help.Size = UDim2.fromOffset(700, 26)
help.BackgroundTransparency = 1
help.Font = Enum.Font.GothamMedium
help.TextSize = 16
help.TextColor3 = Color3.fromRGB(220, 225, 235)
help.TextStrokeTransparency = 0.6
help.Text = "A / D o flechas: deslizate  -  Espacio o Cuadrado: pulso  -  1 bola en tu porteria = 1 vida"
help.Parent = gui

-- Barra del pulso -------------------------------------------------------
-- Se vacia al usar el pulso y se vuelve a llenar mientras recarga: llena y
-- con el color del lado = listo para volver a empujar.

local pulsePanel = Instance.new("Frame")
pulsePanel.Name = "Pulso"
pulsePanel.AnchorPoint = Vector2.new(0.5, 1)
pulsePanel.Position = UDim2.new(0.5, 0, 0.98, -34)
pulsePanel.Size = UDim2.fromOffset(330, 30)
pulsePanel.BackgroundColor3 = Color3.fromRGB(16, 18, 24)
pulsePanel.BackgroundTransparency = 0.15
pulsePanel.BorderSizePixel = 0
pulsePanel.Visible = false
pulsePanel.Parent = gui

local pulseCorner = Instance.new("UICorner")
pulseCorner.CornerRadius = UDim.new(0, 8)
pulseCorner.Parent = pulsePanel

local pulseFill = Instance.new("Frame")
pulseFill.Name = "Relleno"
pulseFill.Size = UDim2.fromScale(1, 1)
pulseFill.BackgroundColor3 = SIDES[1].Color
pulseFill.BackgroundTransparency = 0.2
pulseFill.BorderSizePixel = 0
pulseFill.Parent = pulsePanel

local pulseFillCorner = Instance.new("UICorner")
pulseFillCorner.CornerRadius = UDim.new(0, 8)
pulseFillCorner.Parent = pulseFill

local pulseText = Instance.new("TextLabel")
pulseText.Name = "Texto"
pulseText.Size = UDim2.fromScale(1, 1)
pulseText.BackgroundTransparency = 1
pulseText.Font = Enum.Font.GothamBold
pulseText.TextSize = 14
pulseText.TextColor3 = Color3.fromRGB(255, 255, 255)
pulseText.TextStrokeTransparency = 0.6
pulseText.Text = "ESPACIO: PULSO LISTO"
pulseText.Parent = pulsePanel

-- Estado de la barra, en tiempo del cliente (el servidor manda duraciones,
-- no instantes, asi que no depende de la latencia).
local pulseEnds = 0       -- cuando vuelve a estar listo
local pulseSpan = 1       -- lo que dura la recarga en curso
local pulseArmedUntil = 0 -- ventana en la que el pulso esta cargado

local function updatePulseBar()
	local side = player:GetAttribute("Side")
	local out = player:GetAttribute("Out")
	pulsePanel.Visible = side ~= nil and not out
	if not side then return end

	local now = os.clock()
	local ready = now >= pulseEnds
	local armed = now < pulseArmedUntil
	local color = SIDES[side].Color

	local fraction = 1
	if not ready then
		fraction = 1 - (pulseEnds - now) / math.max(pulseSpan, 0.01)
	end
	fraction = math.clamp(fraction, 0, 1)

	pulseFill.Size = UDim2.fromScale(fraction, 1)
	pulseFill.BackgroundColor3 = armed and Color3.fromRGB(255, 255, 255) or color
	pulseFill.BackgroundTransparency = ready and 0.2 or 0.45

	if armed then
		pulseText.Text = "¡AHORA!  golpea la bola"
		pulseText.TextColor3 = Color3.fromRGB(255, 255, 255)
	elseif ready then
		pulseText.Text = "ESPACIO: PULSO LISTO"
		pulseText.TextColor3 = color
	else
		pulseText.Text = string.format("PULSO RECARGANDO  %.1f s", pulseEnds - now)
		pulseText.TextColor3 = Color3.fromRGB(205, 210, 220)
	end
end

local cells = {}
for i = 1, #SIDES do
	local cell = Instance.new("Frame")
	cell.Name = "Lado" .. i
	cell.Size = UDim2.fromOffset(104, 48)
	cell.BackgroundColor3 = Color3.fromRGB(30, 34, 44)
	cell.BorderSizePixel = 0
	cell.Parent = panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = cell

	local bar = Instance.new("Frame")
	bar.Name = "Barra"
	bar.Size = UDim2.new(1, 0, 0, 4)
	bar.Position = UDim2.new(0, 0, 0, 0)
	bar.BackgroundColor3 = SIDES[i].Color
	bar.BorderSizePixel = 0
	bar.Parent = cell

	local name = Instance.new("TextLabel")
	name.Name = "Nombre"
	name.Position = UDim2.new(0, 0, 0, 8)
	name.Size = UDim2.new(1, 0, 0, 16)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.GothamBold
	name.TextSize = 13
	name.TextColor3 = SIDES[i].Color
	name.Text = SIDES[i].Name
	name.Parent = cell

	local who = Instance.new("TextLabel")
	who.Name = "Jugador"
	who.Position = UDim2.new(0, 0, 0, 23)
	who.Size = UDim2.new(1, 0, 0, 12)
	who.BackgroundTransparency = 1
	who.Font = Enum.Font.Gotham
	who.TextSize = 11
	who.TextColor3 = Color3.fromRGB(190, 195, 205)
	who.TextTruncate = Enum.TextTruncate.AtEnd
	who.Text = "libre"
	who.Parent = cell

	local livesLabel = Instance.new("TextLabel")
	livesLabel.Name = "Vidas"
	livesLabel.AnchorPoint = Vector2.new(1, 0)
	livesLabel.Position = UDim2.new(1, -6, 0, 11)
	livesLabel.Size = UDim2.fromOffset(38, 26)
	livesLabel.BackgroundTransparency = 1
	livesLabel.Font = Enum.Font.FredokaOne
	livesLabel.TextSize = 24
	livesLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	livesLabel.Text = "30"
	livesLabel.Parent = cell

	cells[i] = { frame = cell, player = who, lives = livesLabel }
end

local function flashMessage(text, color, duration)
	message.Text = text
	message.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	message.TextTransparency = 0
	task.delay(duration or 2, function()
		if message.Text == text then
			message.TextTransparency = 1
		end
	end)
end

local function updateState(state)
	for i, info in ipairs(state) do
		local cell = cells[i]
		if cell then
			-- Un lado sin jugador nunca se marca como "eliminado": se queda
			-- como libre aunque sus puntos hayan llegado a 0.
			local ownerless = not info.player
			local down = info.out and not ownerless
			cell.lives.Text = down and "--" or tostring(info.lives)
			cell.lives.TextColor3 = (info.out or info.lives <= 5)
					and Color3.fromRGB(255, 85, 85)
				or Color3.fromRGB(255, 255, 255)
			cell.player.Text = down and "eliminado" or (info.player or "libre")
			local mine = player:GetAttribute("Side") == i
			cell.frame.BackgroundColor3 = mine and Color3.fromRGB(54, 62, 82) or Color3.fromRGB(30, 34, 44)
		end
	end
end

-- Camara ---------------------------------------------------------------

camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = Config.Camera.FieldOfView

local function updateCamera(side)
	local rot = Config.sideRotation(side)
	local outward = -rot.LookVector
	local half = Config.Arena.Size / 2
	local pos = outward * (half + Config.Camera.Distance) + Vector3.new(0, Config.Camera.Height, 0)
	camera.CFrame = CFrame.lookAt(pos, Vector3.new(0, 0, 0))
end

-- Suelo de la mesa -----------------------------------------------------
-- La pala se pega a la superficie midiendo con un rayo contra la arena, en
-- vez de calcular la inclinacion: asi queda clavada en la mesa tal y como
-- se ve, por muy brusco que sea el tiron de la plataforma. Sin esto, un
-- cambio fuerte del suelo la dejaba en el aire o la colaba por debajo.

local arena = workspace:WaitForChild("Arena", 30)

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { arena }
groundParams.IgnoreWater = true

local GROUND_CLEARANCE = 0.1  -- holgura de los pies sobre el suelo

-- Punto de la mesa justo debajo de (x, z), o nil si no hay nada.
local function groundBelow(x, z)
	if not arena then return nil end
	return workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -140, 0), groundParams)
end

-- Controles ------------------------------------------------------------

local KEYS_PLUS = { Enum.KeyCode.D, Enum.KeyCode.Right, Enum.KeyCode.W, Enum.KeyCode.Up }
local KEYS_MINUS = { Enum.KeyCode.A, Enum.KeyCode.Left, Enum.KeyCode.S, Enum.KeyCode.Down }

local function readDirection()
	local plus, minus = false, false
	for _, key in ipairs(KEYS_PLUS) do
		if UserInputService:IsKeyDown(key) then plus = true end
	end
	for _, key in ipairs(KEYS_MINUS) do
		if UserInputService:IsKeyDown(key) then minus = true end
	end

	if not (plus and minus) then
		local ok, state = pcall(function()
			return UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
		end)
		if ok and state and state[Enum.KeyCode.Thumbstick1] then
			local x = state[Enum.KeyCode.Thumbstick1].Position.X
			if x > 0.4 then plus = true elseif x < -0.4 then minus = true end
		end
	end

	return (plus and 1 or 0) - (minus and 1 or 0)
end

local lastSide = nil

-- El cliente mueve su propio personaje (la pala) para que sea inmediato.
local function drivePaddle(side, dir)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return end

	local rot = Config.sideRotation(side)
	local along = rot.RightVector    -- eje del lado
	local outward = -rot.LookVector  -- del centro hacia el lado

	local pos = root.Position
	local a = pos:Dot(along)
	local p = pos:Dot(outward)

	-- Vuelve a su linea y no se sale por los extremos.
	local perr = (SLIDE.LaneDistance - p) * SLIDE.ReturnStiffness
	perr = math.clamp(perr, -SLIDE.ReturnMax, SLIDE.ReturnMax)

	local aerr = 0
	if a > SLIDE.LaneLimit then
		aerr = (SLIDE.LaneLimit - a) * SLIDE.ReturnStiffness
	elseif a < -SLIDE.LaneLimit then
		aerr = (-SLIDE.LaneLimit - a) * SLIDE.ReturnStiffness
	end
	aerr = math.clamp(aerr, -SLIDE.ReturnMax, SLIDE.ReturnMax)

	local target = along * (dir * SLIDE.Speed + aerr) + outward * perr

	-- Solo se mueve en horizontal: la vertical la manda el pegamento al
	-- suelo, asi que ni la gravedad ni un tiron de la mesa la levantan.
	root.AssemblyLinearVelocity = Vector3.new(target.X, 0, target.Z)

	-- Pega la pala a la mesa: los pies sobre la superficie y la pala
	-- tumbada con la misma inclinacion que el suelo (asi no se hunde un
	-- borde ni se queda flotando el otro).
	local hit = groundBelow(pos.X, pos.Z)
	if hit then
		local up = hit.Normal
		-- El eje de la linea proyectado sobre el plano del suelo.
		local right = along - up * along:Dot(up)
		if right.Magnitude < 0.01 then
			right = along
		end
		right = right.Unit

		local feet = character:GetAttribute("FeetOffset")
			or (humanoid.HipHeight + root.Size.Y / 2)
		local y = hit.Position.Y + GROUND_CLEARANCE + feet
		root.CFrame = CFrame.fromMatrix(
			Vector3.new(pos.X, y, pos.Z), right, up, right:Cross(up)
		)
	else
		-- Sin suelo debajo (no deberia pasar): recta donde estaba.
		root.CFrame = CFrame.new(pos) * rot.Rotation
	end
end

-- Pulso de energia -----------------------------------------------------
-- El "extra kick" de Ballistix: se pulsa en el momento justo y la proxima
-- bola sale disparada. Si se gasta sin tocar nada, el servidor lo bloquea.

local pulseRemote = Remotes:WaitForChild("Pulse")
local lastPulse = 0

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode ~= Enum.KeyCode.Space
		and input.KeyCode ~= Enum.KeyCode.ButtonX then
		return
	end
	if not player:GetAttribute("Side") or player:GetAttribute("Out") then return end

	local now = os.clock()
	-- Si la barra aun no esta llena, ni se intenta (el servidor lo rechazaria
	-- igual): asi no se sale el pulso por pulsar a lo loco.
	if now < pulseEnds or now < pulseArmedUntil then return end
	if now - lastPulse < 0.15 then return end
	lastPulse = now
	pulseRemote:FireServer()
end)

RunService.RenderStepped:Connect(function()
	local side = player:GetAttribute("Side")
	if not side then
		updatePulseBar()
		return
	end

	updatePulseBar()
	updateCamera(side)

	-- Eliminado: se queda mirando la mesa desde su lado, sin pala.
	if player:GetAttribute("Out") then return end

	if side ~= lastSide then
		lastSide = side
		local cell = cells[side]
		if cell then
			flashMessage("Eres " .. SIDES[side].Name, SIDES[side].Color, 3)
		end
	end

	drivePaddle(side, readDirection())
end)

-- Eventos --------------------------------------------------------------

GameEvent.OnClientEvent:Connect(function(kind, data)
	if kind == "State" then
		updateState(data)
	elseif kind == "Life" then
		local side = data.side
		flashMessage("-1 vida para " .. SIDES[side].Name, SIDES[side].Color, 1.4)
	elseif kind == "GameOver" then
		local winner = data.winner
		if winner then
			flashMessage("Gana " .. SIDES[winner].Name, SIDES[winner].Color, Config.Match.EndPause)
		else
			flashMessage("Fin de la ronda", Color3.fromRGB(255, 255, 255), Config.Match.EndPause)
		end
	elseif kind == "Eliminated" then
		local side = data.side
		flashMessage(SIDES[side].Name .. " eliminado", SIDES[side].Color, 2.2)
	elseif kind == "Pulse" then
		if data.side ~= player:GetAttribute("Side") then return end

		if data.state == "armed" then
			pulseArmedUntil = os.clock() + (data.duration or Config.Hit.PulseWindow)
		elseif data.state == "hit" or data.state == "miss" then
			pulseArmedUntil = 0
			pulseSpan = math.max(data.duration or 0.01, 0.01)
			pulseEnds = os.clock() + pulseSpan
			if data.state == "miss" then
				flashMessage("Pulso fallado: bloqueado", Color3.fromRGB(255, 150, 80), 1.2)
			end
		elseif data.state == "locked" then
			-- Pulsado mientras recargaba: se resincroniza la barra con lo que
			-- le queda, para que empiece a llenarse desde donde toca.
			local remaining = data.remaining or 0
			if remaining > 0 then
				pulseArmedUntil = 0
				pulseSpan = math.max(remaining, 0.01)
				pulseEnds = os.clock() + remaining
			end
		end
	elseif kind == "Reset" then
		flashMessage("Nueva partida", Color3.fromRGB(255, 255, 255), 2)
	end
end)
