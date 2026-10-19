--!nocheck
--=====================================================================
--  INSTALADOR - "Hockey de Mesa 4 Jugadores"
--  Pega TODO este archivo en la barra de comandos de Roblox Studio
--  (View > Command Bar) y pulsa Enter.
--
--  Crea: la arena cuadrada, las 4 porterias, los 4 pilares que sueltan
--  bolas, los RemoteEvents, el modulo Config y los scripts de servidor
--  y cliente. No borra nada mas que un Baseplate/SpawnLocation previos.
--=====================================================================

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

-- Codigo embebido (generado por tools/build.py) -----------------------
local CONFIG_SRC = [=[
--[[
	Config.lua
	Valores compartidos por el servidor y el cliente.
	El instalador coloca este modulo en ReplicatedStorage.
--]]

local Config = {}

-- Geometria de la arena ------------------------------------------------
Config.Arena = {
	Size = 130,             -- lado del cuadrado en studs
	FloorThickness = 4,
	WallHeight = 12,
	WallThickness = 6,
	GoalWidth = 42,         -- ancho de la boca de la porteria
	PillarInset = 12,       -- distancia del borde al centro del pilar
	PillarRadius = 4.5,
	PillarHeight = 18,
	FloorTop = 0,           -- altura de la superficie de juego
}

-- Deslizamiento del jugador (el personaje es la pala) ------------------
Config.Slide = {
	Speed = 62,             -- studs/segundo de deslizamiento lateral
	LaneDistance = 46,      -- distancia del centro a la linea del jugador
	LaneLimit = 32,         -- maximo |coordenada| a lo largo de la linea
	ReturnStiffness = 9,    -- fuerza con la que vuelve a su linea
	ReturnMax = 34,         -- limite de la correccion
	ResetMargin = 14,       -- margen antes de recolocar al jugador
}

-- Bola -----------------------------------------------------------------
-- El numero de bolas va subiendo solo con el tiempo: al empezar la
-- partida hay entre StartMin y StartMax, y cada GrowEvery segundos el
-- tope sube 1 hasta llegar a MaxAlive.
Config.Ball = {
	Diameter = 7,
	StartMin = 3,           -- bolas al empezar la partida
	StartMax = 5,
	GrowEvery = 2,          -- segundos entre cada subida del tope
	MaxAlive = 15,          -- tope maximo de bolas simultaneas
	Batch = 3,              -- bolas que puede soltar de golpe el spawner
	Interval = 0.6,         -- segundos entre rondas de aparicion
	LaunchSpeed = 62,
	LaunchUp = 6,
	SpreadDeg = 26,         -- dispersion del disparo del pilar
	Density = 0.5,
	Friction = 0.05,
	Elasticity = 0.85,
	MaxSpeed = 180,         -- tope de velocidad (evita atravesar muros)
	SpeedRamp = 0.04,       -- % que ganan de velocidad por segundo (Ballistix)
	MinSpeed = 12,          -- por debajo de esto la bola se considera parada
	StuckTime = 2,          -- segundos parada antes de empujarla
	NudgeSpeed = 46,
	Colors = {
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(255, 214, 92),
		Color3.fromRGB(120, 235, 255),
		Color3.fromRGB(255, 150, 190),
	},
}

-- Pala (el rectangulo que controla cada jugador) ----------------------
-- El personaje queda invisible y lo que se ve (y golpea la bola) es este
-- rectangulo, pintado del color del lado.
Config.Paddle = {
	Width = 14,             -- largo a lo largo de la linea del jugador
	Height = 9,             -- alto
	Depth = 3,              -- grosor (hacia el centro de la mesa)
	Gap = 0.5,              -- hueco bajo la pala, para que las piernas toquen
}

-- Golpe de la pala -----------------------------------------------------
-- La pala rebota las bolas con su propia fisica; el unico golpe fuerte es
-- el pulso de energia. Se pulsa en el momento justo y la bola sale
-- disparada hacia el centro (el punto del ancho donde le da desvia el tiro).
Config.Hit = {
	Enabled = true,
	Power = 180,            -- velocidad del golpe con el pulso cargado
	Aim = 70,               -- desvio maximo al golpear en un extremo de la pala
	Reach = 4,              -- studs por delante de la cara que cuentan como toque
	-- El pulso se carga una ventana corta; si se gasta sin tocar ninguna
	-- bola queda bloqueado un rato (por eso conviene esperar a tener una cerca).
	PulseWindow = 0.3,      -- segundos que el pulso esta cargado esperando bola
	PulseLock = 3,          -- segundos de bloqueo si se falla el pulso
}

-- Partida --------------------------------------------------------------
-- Cada jugador tiene vidas. Cada vez que una bola entra en su porteria
-- (da igual quien la metio) pierde 1 vida. Al llegar a 0 se acaba la
-- partida y gana quien mas vidas tenga.
Config.Match = {
	StartLives = 30,        -- vidas con las que empieza cada jugador
	EndPause = 5,           -- segundos antes de reiniciar tras el final
}

-- Inclinacion de la plataforma -----------------------------------------
-- La arena entera gira sobre su centro: la gravedad hace rodar las bolas
-- hacia el lado bajo. Cada Step segundos elige una inclinacion nueva al
-- azar (amplitud y direccion), asi que va a tirones y nunca repite el
-- ciclo. TurnSpeed mantiene ademas un giro constante por debajo.
Config.Tilt = {
	Enabled = true,
	MinDegrees = 7,         -- inclinacion minima
	MaxDegrees = 15,        -- inclinacion maxima
	Step = 0.9,             -- segundos entre cambio y cambio de inclinacion
	Jitter = 0.35,          -- tiron de direccion aleatorio (radianes)
	Pulse = 0.2,            -- latido rapido de la inclinacion
	WobbleSpeed = 1.2,      -- rad/s del latido
	TurnSpeed = 0.45,       -- rad/s del giro base de la direccion
	UpdateRate = 60,        -- Hz a los que se mueve la arena
}

-- Camara (vista fija por jugador) --------------------------------------
Config.Camera = {
	Height = 90,
	Distance = 32,          -- studs por detras del borde
	FieldOfView = 88,
}

-- Lados de la arena (Angulo = rotacion sobre Y, 0 = Sur/+Z) ------------
Config.Sides = {
	{ Name = "Sur",   Angle = 0,   Color = Color3.fromRGB(235, 70, 60) },
	{ Name = "Este",  Angle = 90,  Color = Color3.fromRGB(60, 130, 250) },
	{ Name = "Norte", Angle = 180, Color = Color3.fromRGB(70, 200, 110) },
	{ Name = "Oeste", Angle = 270, Color = Color3.fromRGB(245, 190, 60) },
}

-- Utilidades -----------------------------------------------------------

function Config.sideRotation(side)
	return CFrame.Angles(0, math.rad(Config.Sides[side].Angle), 0)
end

-- Inclinacion de la arena en el instante t (solo rotacion). Es una
-- funcion pura de t: el mismo instante da siempre la misma inclinacion.

-- Ruido determinista 0..1 a partir de un indice, sin usar estado.
local function tiltHash(n, seed)
	local x = math.sin(n * 127.1 + seed * 311.7) * 43758.5453123
	return x - math.floor(x)
end

local function tiltNoise(n, seed, a, b)
	return a + (b - a) * tiltHash(n, seed)
end

-- Paso angular mas corto de "from" a "to", en radianes.
local function tiltShortestArc(from, to)
	local d = (to - from) % (2 * math.pi)
	if d > math.pi then
		d = d - 2 * math.pi
	end
	return d
end

function Config.tiltCFrame(t)
	local T = Config.Tilt
	if not T.Enabled then
		return CFrame.new(0, 0, 0)
	end

	-- Cada Step segundos la arena "cambia de idea": amplitud y direccion
	-- nuevas al azar. Cada tramo es independiente del anterior, asi que el
	-- movimiento da tirones y no se repite nunca.
	local n = math.floor(t / T.Step)
	local f = t / T.Step - n

	-- La direccion reacciona antes (ease-out) y la amplitud sube redonda.
	local sDir = f * (2 - f)
	local sAmp = f * f * (3 - 2 * f)

	local amp0 = tiltNoise(n, 1.7, T.MinDegrees, T.MaxDegrees)
	local amp1 = tiltNoise(n + 1, 1.7, T.MinDegrees, T.MaxDegrees)
	local ampDeg = amp0 + (amp1 - amp0) * sAmp

	-- Latido rapido para que la mesa nunca este quieta (sin salirse del
	-- rango de grados, para no comerse la vista del jugador).
	ampDeg = math.clamp(ampDeg * (1 + T.Pulse * math.sin(t * T.WobbleSpeed)), T.MinDegrees, T.MaxDegrees)
	local amp = math.rad(ampDeg)

	-- Direccion: giro constante por debajo mas tirones aleatorios encima.
	local base = t * T.TurnSpeed
	local from = base + tiltNoise(n, 9.3, -T.Jitter, T.Jitter)
	local to = base + tiltNoise(n + 1, 9.3, -T.Jitter, T.Jitter)
	local dir = from + tiltShortestArc(from, to) * sDir

	return CFrame.Angles(0, dir, 0) * CFrame.Angles(amp, 0, 0) * CFrame.Angles(0, -dir, 0)
end

-- Altura de la superficie de juego en (x, z) con la arena inclinada.
-- El plano de juego pasa por el centro de la arena.
function Config.surfaceHeight(tilt, x, z)
	local n = tilt.UpVector
	if math.abs(n.Y) < 0.0001 then
		return Config.Arena.FloorTop
	end
	return -(n.X * x + n.Z * z) / n.Y
end

-- CFrame del punto de la linea del jugador "along" studs a lo largo de
-- su lado (0 = centro del lado), apoyado sobre la plataforma inclinada.
function Config.laneCFrame(side, along, tilt)
	local rot = Config.sideRotation(side)
	local p = rot * Vector3.new(along, 0, Config.Slide.LaneDistance)
	local y = Config.Arena.FloorTop + 3
	if tilt then
		y = Config.surfaceHeight(tilt, p.X, p.Z) + 3
	end
	return CFrame.new(p.X, y, p.Z) * rot.Rotation
end

return Config
]=]
local SERVER_SRC = [=[
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
-- la mesa, y gana el ultimo que siga jugando. No hay limite de tiempo.

-- Lados que siguen en juego: con dueno, con puntos y sin haber caido. Una
-- porteria vacia no cuenta: si nadie la defiende no compite, y sus goles no
-- pueden dar por ganada la ronda a otro.
local function aliveSides()
	local count, last = 0, nil
	for i = 1, #SIDES do
		if sideOwner[i] and lives[i] > 0 and not eliminated[i] then
			count = count + 1
			last = i
		end
	end
	return count, last
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

	-- La ronda solo se acaba cuando cae un jugador de verdad y ya no queda
	-- ninguno mas con puntos. Si la que se queda a 0 es una porteria vacia no
	-- se acaba nada: no hay nadie a quien dar por ganador.
	local alive, last = aliveSides()
	if player and alive <= 1 then
		endRound(last)
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
]=]
local CLIENT_SRC = [=[
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
	if now - lastPulse < 0.15 then return end
	lastPulse = now
	pulseRemote:FireServer()
end)

RunService.RenderStepped:Connect(function()
	local side = player:GetAttribute("Side")
	if not side then return end

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
		if data.side == player:GetAttribute("Side") and data.state == "miss" then
			flashMessage("Pulso fallado: bloqueado", Color3.fromRGB(255, 150, 80), 1.2)
		end
	elseif kind == "Reset" then
		flashMessage("Nueva partida", Color3.fromRGB(255, 255, 255), 2)
	end
end)
]=]
local EMBED_SCRIPTS = true

-- Helpers --------------------------------------------------------------

local function newPart(props, parent)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(props) do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function newFolder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function destroyIfExists(parent, name)
	local old = parent and parent:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end

-- 1. Limpieza de la instalacion anterior -------------------------------

destroyIfExists(Workspace, "Arena")
destroyIfExists(Workspace, "Extras")
destroyIfExists(Workspace, "Balls")
destroyIfExists(ReplicatedStorage, "Config")
destroyIfExists(ReplicatedStorage, "Remotes")
destroyIfExists(ServerScriptService, "HockeyServer")
destroyIfExists(ServerScriptService, "GameServer")
destroyIfExists(StarterPlayer.StarterPlayerScripts, "HockeyClient")
destroyIfExists(StarterPlayer.StarterPlayerScripts, "ClientController")

-- Sustituye el escenario por defecto
destroyIfExists(Workspace, "Baseplate")
for _, child in ipairs(Workspace:GetChildren()) do
	if child:IsA("SpawnLocation") then
		child:Destroy()
	end
end

-- 2. Modulo compartido Config ------------------------------------------

local configModule = Instance.new("ModuleScript")
configModule.Name = "Config"
configModule.Source = CONFIG_SRC
configModule.Parent = ReplicatedStorage
local Config = require(configModule)

local A = Config.Arena
local SLIDE = Config.Slide
local SIDES = Config.Sides

-- 3. RemoteEvents ------------------------------------------------------

local remotes = newFolder("Remotes", ReplicatedStorage)
do
	local events = Instance.new("RemoteEvent")
	events.Name = "GameEvent"
	events.Parent = remotes

	-- Pulso de energia (el "extra kick" de Ballistix).
	local pulse = Instance.new("RemoteEvent")
	pulse.Name = "Pulse"
	pulse.Parent = remotes
end

-- 4. Arena -------------------------------------------------------------

Workspace.FallenPartsDestroyHeight = -60

-- La arena es un Model: el servidor la inclina con PivotTo y la
-- gravedad mueve las bolas.
local arena = Instance.new("Model")
arena.Name = "Arena"
arena.Parent = Workspace

-- Cosas que NO deben inclinarse con la arena
local extras = newFolder("Extras", Workspace)

local walls = newFolder("Muros", arena)
local deco = newFolder("Deco", arena)
local pillarsFolder = newFolder("Pillars", arena)

local half = A.Size / 2
local t = A.WallThickness
local h = A.WallHeight
local gw = A.GoalWidth
local ft = A.FloorThickness
local segLen = (half + t) - gw / 2
local segCenter = gw / 2 + segLen / 2

-- Suelo de juego (poco rozamiento, tipo air-hockey)
newPart({
	Name = "Suelo",
	Size = Vector3.new(A.Size, ft, A.Size),
	CFrame = CFrame.new(0, A.FloorTop - ft / 2, 0),
	Color = Color3.fromRGB(22, 26, 38),
	CustomPhysicalProperties = PhysicalProperties.new(2, 0.05, 0.5, 0.05, 0.5),
}, arena)

-- Pivote invisible en el centro exacto de la superficie de juego: la
-- arena gira alrededor de este punto, asi que el plano de juego pasa
-- siempre por (0, 0, 0) y las cuentas de altura cuadran.
local pivotPart = newPart({
	Name = "Pivote",
	Size = Vector3.new(1, 1, 1),
	CFrame = CFrame.new(0, A.FloorTop, 0),
	Transparency = 1,
	CanCollide = false,
	CanQuery = false,
	CanTouch = false,
}, arena)
arena.PrimaryPart = pivotPart

-- Punto de aparicion invisible en alto: los personajes aparecen ahi y
-- el servidor los coloca al instante en su linea. Asi nunca aparecen
-- dentro de la arena.
local spawnPad = Instance.new("SpawnLocation")
spawnPad.Name = "PuntoDeAparicion"
spawnPad.Size = Vector3.new(12, 1, 12)
spawnPad.CFrame = CFrame.new(0, 60, 0)
spawnPad.Anchored = true
spawnPad.CanCollide = false
spawnPad.CanTouch = false
spawnPad.Transparency = 1
spawnPad.Neutral = true
spawnPad.Duration = 0
spawnPad.Parent = extras

-- Grada de espectadores
newPart({
	Name = "Grada",
	Size = Vector3.new(120, 4, 24),
	CFrame = CFrame.new(0, A.FloorTop - 2, 105),
	Color = Color3.fromRGB(30, 34, 44),
}, extras)

-- Muros, marcos de porteria y guias por cada lado
for i, def in ipairs(SIDES) do
	local cf = Config.sideRotation(i)
	local dark = Color3.new(def.Color.R * 0.35, def.Color.G * 0.35, def.Color.B * 0.35)

	-- Dos segmentos de muro, con hueco en el centro para la porteria
	for _, sgn in ipairs({ 1, -1 }) do
		local suffix = sgn > 0 and "A" or "B"

		newPart({
			Name = "Muro_" .. def.Name .. "_" .. suffix,
			Size = Vector3.new(segLen, h, t),
			CFrame = cf * CFrame.new(sgn * segCenter, h / 2, half + t / 2),
			Color = dark,
		}, walls)

		newPart({
			Name = "Riel_" .. def.Name .. "_" .. suffix,
			Size = Vector3.new(segLen, 1.2, t + 1.4),
			CFrame = cf * CFrame.new(sgn * segCenter, h, half + t / 2),
			Color = def.Color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, deco)

		-- Poste vertical del marco de la porteria
		newPart({
			Name = "Poste_" .. def.Name .. "_" .. suffix,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(h, 2.4, 2.4),
			CFrame = cf * CFrame.new(sgn * (gw / 2 - 1), h / 2, half + 1) * CFrame.Angles(0, 0, math.rad(90)),
			Color = def.Color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, deco)
	end

	-- Travesano superior del marco (decorativo, no choca)
	newPart({
		Name = "Travesano_" .. def.Name,
		Size = Vector3.new(gw + 2, 1.4, 3),
		CFrame = cf * CFrame.new(0, h, half + 1),
		Color = def.Color,
		Material = Enum.Material.Neon,
		CanCollide = false,
	}, deco)

	-- Guia de la linea de deslizamiento del jugador
	newPart({
		Name = "Pista_" .. def.Name,
		Size = Vector3.new(SLIDE.LaneLimit * 2, 0.3, 2),
		CFrame = cf * CFrame.new(0, A.FloorTop + 0.15, SLIDE.LaneDistance),
		Color = def.Color,
		Material = Enum.Material.Neon,
		Transparency = 0.25,
		CanCollide = false,
	}, deco)
end

-- Pilares de las esquinas
local inset = A.PillarInset
for _, sx in ipairs({ 1, -1 }) do
	for _, sz in ipairs({ 1, -1 }) do
		local x = sx * (half - inset)
		local z = sz * (half - inset)

		newPart({
			Name = "Pilar",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(A.PillarHeight, A.PillarRadius * 2, A.PillarRadius * 2),
			CFrame = CFrame.new(x, A.FloorTop + A.PillarHeight / 2, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(48, 54, 70),
		}, pillarsFolder)

		newPart({
			Name = "AroPilar",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1.6, A.PillarRadius * 2 + 2, A.PillarRadius * 2 + 2),
			CFrame = CFrame.new(x, A.FloorTop + A.PillarHeight, z) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(130, 150, 255),
			Material = Enum.Material.Neon,
			CanCollide = false,
		}, deco)
	end
end

-- Contenedor de bolas
newFolder("Balls", Workspace)

-- 5. Iluminacion -------------------------------------------------------

Lighting.Ambient = Color3.fromRGB(70, 76, 92)
Lighting.OutdoorAmbient = Color3.fromRGB(80, 88, 105)
Lighting.Brightness = 2.5
Lighting.ClockTime = 15
Lighting.EnvironmentDiffuseScale = 0.5
Lighting.GlobalShadows = true

-- 6. Scripts -----------------------------------------------------------

if EMBED_SCRIPTS then
	local serverScript = Instance.new("Script")
	serverScript.Name = "HockeyServer"
	serverScript.Source = SERVER_SRC
	serverScript.Parent = ServerScriptService

	local clientScript = Instance.new("LocalScript")
	clientScript.Name = "HockeyClient"
	clientScript.Source = CLIENT_SRC
	clientScript.Parent = StarterPlayer.StarterPlayerScripts

	print("[Hockey] Instalacion completa. Pulsa Play para jugar.")
else
	print("[Hockey] Mapa creado. Falta pegar los scripts:")
	print("[Hockey]  - dist/HockeyServer.lua  -> Script 'HockeyServer' en ServerScriptService")
	print("[Hockey]  - dist/HockeyClient.lua  -> LocalScript 'HockeyClient' en StarterPlayerScripts")
end