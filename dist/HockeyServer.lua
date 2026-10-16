--[[
	GameServer.server.lua
	Servidor principal del juego "Hockey de Mesa 4 Jugadores".

	 - Asigna a cada jugador un lado de la arena (maximo 4).
	 - El personaje es la pala: se desliza por su linea y golpea bolas.
	 - Los pilares de las esquinas sueltan bolas periodicamente.
	 - La arena se inclina sola y la gravedad mueve las bolas.
	 - Cada jugador tiene vidas: cada bola que entra en su porteria le
	   quita una. Al llegar a 0 termina la partida.
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Config"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GameEvent = Remotes:WaitForChild("GameEvent")

local Workspace = game:GetService("Workspace")
local Arena = Workspace:WaitForChild("Arena")
local Pillars = Arena:WaitForChild("Pillars")
local Balls = Workspace:WaitForChild("Balls")

local SIDES = Config.Sides
local ARENA = Config.Arena
local SLIDE = Config.Slide
local BALL = Config.Ball
local MATCH = Config.Match
local TILT = Config.Tilt

-- Estado ---------------------------------------------------------------
local sideOwner = {}   -- [lado] = Player
local playerSide = {}  -- [Player] = lado
local lives = {}       -- [lado] = vidas restantes
local stuckTime = {}   -- [bola] = segundos parada
local currentTilt = CFrame.new(0, 0, 0) -- inclinacion actual de la arena
local matchOver = false
local targetBalls = 0   -- bolas que queremos tener ahora (sube con el tiempo)
local pillarCursor = 0  -- rotacion de pilares, para repartir las bolas

for i = 1, #SIDES do
	lives[i] = MATCH.StartLives
end

Players.RespawnTime = 2
Players.CharacterAutoLoads = true

local function broadcast(kind, data)
	GameEvent:FireAllClients(kind, data)
end

local function buildState()
	local state = {}
	for i = 1, #SIDES do
		state[i] = {
			name = SIDES[i].Name,
			color = SIDES[i].Color,
			lives = lives[i],
			player = sideOwner[i] and sideOwner[i].Name or nil,
		}
	end
	return state
end

local function broadcastState()
	broadcast("State", buildState())
end

-- Jugador como pala ----------------------------------------------------
-- El personaje (el humanoid, que es quien resbala y choca de verdad) se
-- queda invisible, y encima lleva soldado un rectangulo del color del
-- lado: eso es lo que se ve y lo que golpea la bola.

local function hideCharacter(character)
	-- Sin el script de animaciones el rectangulo no se menea al deslizarse.
	local animate = character:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = 1
		elseif d:IsA("Decal") or d:IsA("Texture") then
			d.Transparency = 1
		end
	end
end

local function buildPaddle(character, humanoid, root, color)
	local P = Config.Paddle

	-- Altura de los pies: la pala apoya justo encima, con un pelin de
	-- hueco para que el humanoid siga pisando el suelo como hasta ahora.
	local feetY
	local ok, boxCF, boxSize = pcall(function()
		return character:GetBoundingBox()
	end)
	if ok and boxCF then
		feetY = boxCF.Y - boxSize.Y / 2
	else
		feetY = root.Position.Y - (root.Size.Y / 2 + humanoid.HipHeight)
	end

	local offsetY = (feetY + P.Gap + P.Height / 2) - root.Position.Y

	-- De cuanto es el root a los pies: el cliente lo usa para pegar la pala
	-- al suelo sin tener que adivinar la altura del rig (R6/R15).
	character:SetAttribute("FeetOffset", root.Position.Y - feetY)

	local pad = Instance.new("Part")
	pad.Name = "Pala"
	pad.Size = Vector3.new(P.Width, P.Height, P.Depth)
	pad.Color = color
	pad.Material = Enum.Material.SmoothPlastic
	pad.TopSurface = Enum.SurfaceType.Smooth
	pad.BottomSurface = Enum.SurfaceType.Smooth
	pad.CanCollide = true
	pad.CanTouch = true
	pad.Massless = true
	-- El root mira al centro de la mesa: su eje X local es el de la linea
	-- y su Z local apunta al centro, asi que el ancho va a lo largo.
	pad.CFrame = root.CFrame * CFrame.new(0, offsetY, 0)
	pad.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = pad
	weld.Parent = pad

	return pad
end

local function setupCharacter(player, character)
	local side = playerSide[player]
	local humanoid = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not root then return end

	humanoid.MaxHealth = 1000000
	humanoid.Health = 1000000

	if not side then
		-- Espectador: queda libre en la grada.
		humanoid.WalkSpeed = 20
		humanoid.UseJumpPower = true
		humanoid.JumpPower = 50
		character:PivotTo(CFrame.new(0, 4, 105))
		return
	end

	humanoid.WalkSpeed = 0
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0
	humanoid.AutoRotate = false
	-- El personaje no camina: es una pala que movemos nosotros. Con
	-- PlatformStand el humanoid deja de intentar mantenerse de pie, que es
	-- lo que peleaba con la inclinacion de la mesa.
	humanoid.PlatformStand = true
	-- El pivote del modelo es el root, para que PivotTo lo deje donde
	-- decimos (el rectangulo soldado no debe desviar el pivote).
	character.PrimaryPart = root
	-- Nada de nombre ni barra de vida flotando sobre el rectangulo.
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	pcall(function()
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Climbing, false)
	end)

	character:PivotTo(Config.laneCFrame(side, 0, currentTilt))
	hideCharacter(character)
	buildPaddle(character, humanoid, root, SIDES[side].Color)
end

-- Inclinacion de la plataforma ----------------------------------------
-- Rotamos la arena entera sobre su centro. La gravedad real hace rodar
-- las bolas hacia el lado bajo; los jugadores siguen clavados en su
-- linea porque su velocidad lateral la fija el controlador.

local tiltAccum = 0

RunService.Heartbeat:Connect(function(dt)
	if TILT.Enabled then
		currentTilt = Config.tiltCFrame(time())

		tiltAccum = tiltAccum + dt
		if tiltAccum >= 1 / TILT.UpdateRate then
			tiltAccum = 0
			Arena:PivotTo(currentTilt)
		end
	end
end)

-- Vigilancia del jugador ----------------------------------------------
-- El deslizamiento lo controla el cliente (mucho mas reactivo). El
-- servidor solo comprueba de vez en cuando que nadie se salga de su
-- zona y lo devuelve a su linea si es necesario.
local GUARD_INTERVAL = 0.5

task.spawn(function()
	while true do
		task.wait(GUARD_INTERVAL)
		for _, player in ipairs(Players:GetPlayers()) do
			local side = playerSide[player]
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if side and root then
				local rot = Config.sideRotation(side)
				local pos = root.Position
				local a = pos:Dot(rot.RightVector)
				local p = pos:Dot(-rot.LookVector)

				-- Red de seguridad vertical: si el cliente no lo ha podido
				-- pegar al suelo (lag, un tiron muy brusco...), lo hacemos
				-- nosotros con la inclinacion que manda el servidor.
				local feet = character:GetAttribute("FeetOffset") or 3
				local floorY = Config.surfaceHeight(currentTilt, pos.X, pos.Z) + ARENA.FloorTop

				if math.abs((pos.Y - feet) - floorY) > 8
					or math.abs(a) > SLIDE.LaneLimit + SLIDE.ResetMargin
					or p > SLIDE.LaneDistance + SLIDE.ResetMargin
					or p < 4 then
					character:PivotTo(
						Config.laneCFrame(side, math.clamp(a, -SLIDE.LaneLimit, SLIDE.LaneLimit), currentTilt)
					)
				end
			end
		end
	end
end)

-- Bolas ----------------------------------------------------------------

local function removeBall(ball)
	stuckTime[ball] = nil
	ball:Destroy()
end

local function countBalls()
	local n = 0
	for _, child in ipairs(Balls:GetChildren()) do
		if child:IsA("BasePart") then
			n = n + 1
		end
	end
	return n
end

-- Presupuesto de bolas -------------------------------------------------

-- Bolas que la arena intenta mantener ahora mismo. Al empezar la partida
-- son StartMin..StartMax y el tope sube de uno en uno con el tiempo.
local function resetBallTarget()
	targetBalls = math.random(BALL.StartMin, BALL.StartMax)
end

-- Quita bolas hasta dejar el presupuesto actual (se usa al reiniciar la
-- partida, para que no sigan en la mesa las 100 del pico anterior).
local function trimBalls(target)
	for _, ball in ipairs(Balls:GetChildren()) do
		if countBalls() <= target then return end
		if ball:IsA("BasePart") then
			removeBall(ball)
		end
	end
end

-- Goles y vidas --------------------------------------------------------

local function endMatch(playerWhoLost)
	local winner, best = nil, -1
	for i = 1, #SIDES do
		if lives[i] > best then
			best = lives[i]
			winner = i
		end
	end

	matchOver = true
	broadcast("GameOver", { out = playerWhoLost, winner = winner, lives = lives })

	task.delay(MATCH.EndPause, function()
		for i = 1, #SIDES do
			lives[i] = MATCH.StartLives
		end
		matchOver = false
		resetBallTarget()
		trimBalls(targetBalls)
		broadcast("Reset", { lives = lives })
		broadcastState()
	end)
end

-- Cualquier bola que entre en una porteria le quita una vida a su dueno.
local function onGoal(ball, ownerSide)
	if lives[ownerSide] and not matchOver then
		lives[ownerSide] = math.max(0, lives[ownerSide] - 1)
		broadcast("Life", { side = ownerSide, lives = lives[ownerSide] })
		broadcastState()

		if lives[ownerSide] <= 0 then
			endMatch(ownerSide)
		end
	end

	removeBall(ball)
end

-- Deteccion de gol -----------------------------------------------------
-- La porteria es el hueco del muro: no hay caja, ni suelo, ni sensor. La
-- bola que cruza el hueco simplemente desaparece, asi que no puede
-- rebotar ni volver a salir. Se comprueba por posicion, que es inmediato.

local ARENA_HALF = ARENA.Size / 2
local GOAL_LINE = ARENA_HALF + BALL.Diameter / 2
-- Un poco generoso a proposito: cualquier bola que llegue al hueco cuenta,
-- asi ninguna se queda "colgada" sin gol y sin vida descontada.
local GOAL_HALF = ARENA.GoalWidth / 2

local sideAxis = {}
for i = 1, #SIDES do
	local rot = Config.sideRotation(i)
	sideAxis[i] = { outward = -rot.LookVector, along = rot.RightVector }
end

-- Devuelve el lado cuya porteria ha recibido la bola, o nil.
local function goalSideOf(ball)
	local pos = ball.Position
	if pos.Y > ARENA.WallHeight then return nil end
	for i = 1, #SIDES do
		local axis = sideAxis[i]
		if pos:Dot(axis.outward) > GOAL_LINE and math.abs(pos:Dot(axis.along)) < GOAL_HALF then
			return i
		end
	end
	return nil
end

-- Goles y tope de velocidad de las bolas, una vez por frame.
RunService.Heartbeat:Connect(function()
	for _, ball in ipairs(Balls:GetChildren()) do
		if ball:IsA("BasePart") then
			local side = goalSideOf(ball)
			if side then
				onGoal(ball, side)
			else
				local vel = ball.AssemblyLinearVelocity
				local speed = vel.Magnitude
				if speed > BALL.MaxSpeed then
					ball.AssemblyLinearVelocity = vel * (BALL.MaxSpeed / speed)
				end
			end
		end
	end
end)

local function getPillars()
	local list = {}
	for _, child in ipairs(Pillars:GetChildren()) do
		if child:IsA("BasePart") then
			list[#list + 1] = child
		end
	end
	return list
end

-- Devuelve el siguiente pilar de la rotacion: asi un lote de bolas no sale
-- siempre del mismo pilar (y no se apilan unas dentro de otras).
local function nextPillar()
	local pillars = getPillars()
	if #pillars == 0 then return nil end
	pillarCursor = pillarCursor % #pillars + 1
	return pillars[pillarCursor]
end

local function spawnBall()
	if countBalls() >= targetBalls then return end
	local pillar = nextPillar()
	if not pillar then return end
	local base = pillar.Position
	local inward = -Vector3.new(base.X, 0, base.Z)
	if inward.Magnitude < 0.01 then
		inward = Vector3.new(0, 0, 1)
	end
	inward = inward.Unit

	-- Punta del pilar (el cilindro tiene su eje en el X local), ya con
	-- la inclinacion que tenga la plataforma en este momento.
	local top = pillar.CFrame * CFrame.new(pillar.Size.X / 2, 0, 0)
	local spawnPos = top.Position + inward * (ARENA.PillarRadius + BALL.Diameter * 0.6)

	local ang = math.rad(math.random(-BALL.SpreadDeg, BALL.SpreadDeg))
	local dir = CFrame.Angles(0, ang, 0) * inward
	local speed = BALL.LaunchSpeed * (0.85 + math.random() * 0.3)

	local ball = Instance.new("Part")
	ball.Name = "Bola"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(BALL.Diameter, BALL.Diameter, BALL.Diameter)
	ball.Material = Enum.Material.SmoothPlastic
	ball.Color = BALL.Colors[math.random(1, #BALL.Colors)]
	ball.CustomPhysicalProperties = PhysicalProperties.new(BALL.Density, BALL.Friction, BALL.Elasticity, 0.05, 1)
	ball.CFrame = CFrame.new(spawnPos)
	ball.CanCollide = true
	ball.CanTouch = true
	ball.Parent = Balls
	CollectionService:AddTag(ball, "Ball")

	ball.AssemblyLinearVelocity = dir * speed + Vector3.new(0, BALL.LaunchUp, 0)
end

-- Aparicion de bolas ---------------------------------------------------
-- El spawner rellena hasta el presupuesto actual en lotes pequenos, y otro
-- bucle sube ese presupuesto con el tiempo. Si el spawner no diera abasto
-- (con MaxAlive alto y muchas bolas entrando), sube Batch.
task.spawn(function()
	task.wait(2)
	resetBallTarget()
	while true do
		if #Players:GetPlayers() > 0 then
			local missing = targetBalls - countBalls()
			for _ = 1, math.min(BALL.Batch, missing) do
				spawnBall()
			end
		end
		task.wait(BALL.Interval)
	end
end)

-- Crecimiento del presupuesto de bolas (solo con jugadores dentro).
task.spawn(function()
	task.wait(2 + BALL.GrowEvery)
	while true do
		if #Players:GetPlayers() > 0 and targetBalls < BALL.MaxAlive then
			targetBalls = targetBalls + 1
		end
		task.wait(BALL.GrowEvery)
	end
end)

-- Vigilancia de bolas (paradas o fuera de la arena) --------------------
task.spawn(function()
	while true do
		task.wait(1)
		for _, ball in ipairs(Balls:GetChildren()) do
			if ball:IsA("BasePart") then
				local vel = ball.AssemblyLinearVelocity
				local flat = Vector3.new(vel.X, 0, vel.Z).Magnitude
				if flat < BALL.MinSpeed then
					stuckTime[ball] = (stuckTime[ball] or 0) + 1
					if stuckTime[ball] >= BALL.StuckTime then
						stuckTime[ball] = 0
						local ang = math.random() * math.pi * 2
						ball.AssemblyLinearVelocity = Vector3.new(math.cos(ang), 0, math.sin(ang)) * BALL.NudgeSpeed
							+ Vector3.new(0, 6, 0)
					end
				else
					stuckTime[ball] = 0
				end

				local p = ball.Position
				if p.Y < -40 or math.abs(p.X) > 220 or math.abs(p.Z) > 220 then
					removeBall(ball)
				end
			end
		end
	end
end)

-- Alta y baja de jugadores ---------------------------------------------

local function freeSide()
	for i = 1, #SIDES do
		local owner = sideOwner[i]
		if not owner or not owner.Parent then
			sideOwner[i] = nil
			return i
		end
	end
	return nil
end

local function onPlayerAdded(player)
	local side = freeSide()
	if side then
		sideOwner[side] = player
		playerSide[player] = side
		player:SetAttribute("Side", side)
		player:SetAttribute("SideName", SIDES[side].Name)
	else
		player:SetAttribute("Side", nil)
		player:SetAttribute("SideName", "Espectador")
	end

	player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
	end)
	if player.Character then
		task.spawn(setupCharacter, player, player.Character)
	end

	broadcastState()
end

local function onPlayerRemoving(player)
	local side = playerSide[player]
	if side then
		sideOwner[side] = nil
	end
	playerSide[player] = nil
	broadcastState()
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

-- Estado inicial -------------------------------------------------------
broadcastState()
print("[Hockey] Servidor listo.")