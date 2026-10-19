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
local Pulse = Remotes:WaitForChild("Pulse")

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
local HIT = Config.Hit
local PADDLE = Config.Paddle

-- Estado ---------------------------------------------------------------
local sideOwner = {}   -- [lado] = Player
local playerSide = {}  -- [Player] = lado
local lives = {}       -- [lado] = vidas restantes
local paddles = {}     -- [lado] = pala del jugador que ocupa ese lado
local eliminated = {}  -- [lado] = true si se ha quedado a 0 (fuera)
local pulseUntil = {}  -- [lado] = instante hasta el que dura el pulso cargado
local pulseLock = {}   -- [lado] = instante hasta el que el pulso esta bloqueado
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
			out = eliminated[i] and true or false,
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

	if not side or eliminated[side] then
		-- Espectador (o jugador eliminado): queda libre en la grada.
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
	paddles[side] = buildPaddle(character, humanoid, root, SIDES[side].Color)
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
			if side and root and not eliminated[side] then
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
-- Como en Ballistix: el que se queda a 0 puntos explota y queda fuera de
-- la mesa, y gana el ultimo que siga con puntos. No hay limite de tiempo.

-- Lados que aun tienen puntos, tengan jugador o no. Es lo que decide el
-- ganador: cuando solo queda uno, ese gana (asi, si tu eres el unico que
-- sigue con puntos, ganas aunque las porterias vacias se hayan ido a 0).
local function sidesWithPoints()
	local count, last = 0, nil
	for i = 1, #SIDES do
		if lives[i] > 0 then
			count = count + 1
			last = i
		end
	end
	return count, last
end

-- Jugadores que siguen en pie (con dueno y con puntos).
local function playersAlive()
	local n = 0
	for i = 1, #SIDES do
		if sideOwner[i] and lives[i] > 0 then
			n = n + 1
		end
	end
	return n
end


local function restartRound()
	for i = 1, #SIDES do
		lives[i] = MATCH.StartLives
		eliminated[i] = nil
		pulseUntil[i] = nil
		pulseLock[i] = nil
	end
	matchOver = false
	resetBallTarget()
	trimBalls(targetBalls)

	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("Out", nil)
	end

	broadcast("Reset", { lives = lives })
	broadcastState()

	-- Personajes nuevos: los eliminados vuelven a la mesa como pala.
	for _, player in ipairs(Players:GetPlayers()) do
		pcall(function()
			player:LoadCharacter()
		end)
	end
end

local function endRound(winner)
	matchOver = true
	broadcast("GameOver", { winner = winner, lives = lives })
	task.delay(MATCH.EndPause, restartRound)
end

local function eliminateSide(side)
	eliminated[side] = true
	pulseUntil[side] = nil
	pulseLock[side] = nil

	local player = sideOwner[side]

	-- Solo hay "eliminacion" de verdad si hay jugador detras: una porteria
	-- vacia que se queda a 0 deja de contar y ya esta (no hay nave que
	-- reventar ni a quien avisar).
	if player then
		player:SetAttribute("Out", true)

		-- La nave explota: fogonazo sin fuerza, no empuja nada.
		local pad = paddles[side]
		if pad and pad.Parent then
			local boom = Instance.new("Explosion")
			boom.Position = pad.Position
			boom.BlastPressure = 0
			boom.BlastRadius = 6
			boom.DestroyJointRadiusPercent = 0
			boom.Parent = Workspace
			pad:Destroy()
		end
		paddles[side] = nil

		broadcast("Eliminated", { side = side })
	end

	-- El estado va DESPUES de marcar la caida: si no, el marcador del
	-- eliminado se queda mostrando sus puntos en vez de "--".
	broadcastState()

	-- Se acaba la ronda cuando ya solo queda un lado con puntos (ese gana) o
	-- cuando ya no queda ningun jugador en pie. Asi, si las otras porterias se
	-- van a 0 y tu sigues con puntos, ganas en el acto; y si caes tu antes, la
	-- ronda tambien termina (no te quedas de espectador para siempre).
	local left, winner = sidesWithPoints()
	if left <= 1 or playersAlive() == 0 then
		endRound(left == 1 and winner or nil)
	end

	-- Reaparece como espectador (setupCharacter lo detecta).
	if player and player.Character then
		player:LoadCharacter()
	end
end

-- Cualquier bola que entre en una porteria le quita una vida a su dueno,
-- este ocupada o no: el marcador tiene que ensenar el peligro real de cada
-- lado. Una porteria vacia que llega a 0 se queda fuera sin "eliminar" a
-- nadie (no hay jugador detras), y si luego entra alguien recupera puntos.
local function onGoal(ball, ownerSide)
	if lives[ownerSide] and not matchOver and not eliminated[ownerSide] then
		lives[ownerSide] = math.max(0, lives[ownerSide] - 1)
		broadcast("Life", { side = ownerSide, lives = lives[ownerSide] })
		broadcastState()

		if lives[ownerSide] <= 0 then
			eliminateSide(ownerSide)
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

-- Pulso de energia -----------------------------------------------------
-- La pala NO lanza sola: cuando toca una bola, la bola rebota como en
-- cualquier otra superficie. El golpe fuerte es solo el pulso (Espacio /
-- Cuadrado), igual que en Ballistix: se carga una ventana corta y, si
-- llega una bola, sale disparada hacia el centro.
-- Se mira por posicion (igual que los goles), pasando la bola al espacio
-- de la pala. Como la pala va tumbada con la mesa, su LookVector sigue el
-- plano del suelo, asi que el tiro sale bien con cualquier inclinacion.
-- La punta con la que se golpea desvia el tiro a un lado o a otro.

local function paddlePulses()
	if not HIT.Enabled then return end

	local now = time()
	local front = -(PADDLE.Depth / 2)      -- cara delantera, en local
	local halfW = PADDLE.Width / 2
	local halfH = PADDLE.Height / 2

	for side = 1, #SIDES do
		local pad = paddles[side]
		-- pad.Parent es nil si el jugador esta reapareciendo o se ha ido.
		if pad and pad.Parent then
			-- Pulso cargado que se gasta sin tocar bola: queda bloqueado
			-- unos segundos (asi se paga el pulsar a lo loco).
			if pulseUntil[side] and now > pulseUntil[side] then
				pulseUntil[side] = nil
				pulseLock[side] = now + HIT.PulseLock
				if sideOwner[side] then
					broadcast("Pulse", { side = side, state = "miss" })
				end
			end

			if pulseUntil[side] then
				local cf = pad.CFrame
				local hit = false

				for _, ball in ipairs(Balls:GetChildren()) do
					if ball:IsA("BasePart") then
						local r = ball.Size.X / 2
						local lp = cf:PointToObjectSpace(ball.Position)

						-- Delante de la cara delantera, a lo sumo Reach
						-- studs por delante (asi no se le escapa una bola
						-- rapida) y dentro del ancho y el alto de la pala.
						if lp.Z <= front + r
							and lp.Z >= front - r - HIT.Reach
							and math.abs(lp.X) <= halfW + r
							and math.abs(lp.Y) <= halfH + r then
							local aim = math.clamp(lp.X / halfW, -1, 1)
							ball.AssemblyLinearVelocity =
								cf.LookVector * HIT.Power
								+ cf.RightVector * (aim * HIT.Aim)
							hit = true
						end
					end
				end

				if hit then
					pulseUntil[side] = nil
					pulseLock[side] = nil
					broadcast("Pulse", { side = side, state = "hit" })
				end
			end
		end
	end
end

-- Red de seguridad del suelo -------------------------------------------
-- La mesa no se simula: se mueve con PivotTo por debajo de las bolas, asi
-- que en un tiron fuerte una bola puede quedarse dentro del suelo. Ahora
-- que hay pocas bolas sale barato mirarlo cada frame y devolver arriba las
-- que se hayan colado, en vez de dejarlas caer fuera de la mesa.
local function keepOnTable(ball)
	local pos = ball.Position
	local r = ball.Size.X / 2
	local floor = Config.surfaceHeight(currentTilt, pos.X, pos.Z) + ARENA.FloorTop

	if pos.Y < floor - r * 0.5 then
		local vel = ball.AssemblyLinearVelocity
		ball.CFrame = CFrame.new(pos.X, floor + r + 0.2, pos.Z)
		ball.AssemblyLinearVelocity = Vector3.new(vel.X, math.abs(vel.Y) * 0.3 + 6, vel.Z)
	end
end

-- Goles, pulso de energia y tope de velocidad de las bolas, una vez por
-- frame.
RunService.Heartbeat:Connect(function()
	paddlePulses()
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
				keepOnTable(ball)
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

				-- Ballistix: las bolas van ganando velocidad con el tiempo,
				-- asi que la partida se calienta sola.
				if flat >= BALL.MinSpeed and vel.Magnitude < BALL.MaxSpeed * 0.95 then
					ball.AssemblyLinearVelocity = vel * (1 + BALL.SpeedRamp)
				end

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

-- Pulso de energia -----------------------------------------------------
-- El cliente avisa al pulsar. El pulso queda cargado unos instantes y la
-- siguiente bola que toque la cara delantera sale a toda velocidad.
Pulse.OnServerEvent:Connect(function(player)
	local side = playerSide[player]
	if not side or matchOver or eliminated[side] or not lives[side] or lives[side] <= 0 then
		return
	end

	local now = time()
	if pulseUntil[side] then return end                       -- ya cargado
	if pulseLock[side] and now < pulseLock[side] then return end  -- bloqueado

	pulseUntil[side] = now + HIT.PulseWindow
end)

-- Alta y baja de jugadores ---------------------------------------------

local function freeSide()
	for i = 1, #SIDES do
		local owner = sideOwner[i]
		if not owner or not owner.Parent then
			sideOwner[i] = nil
			eliminated[i] = nil
			pulseUntil[i] = nil
			pulseLock[i] = nil
			-- Un lado que ya habia caido vuelve con sus puntos: el que llega
			-- no hereda una porteria a 0.
			if not lives[i] or lives[i] <= 0 then
				lives[i] = MATCH.StartLives
			end
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
		paddles[side] = nil
		eliminated[side] = nil
		pulseUntil[side] = nil
		pulseLock[side] = nil
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
