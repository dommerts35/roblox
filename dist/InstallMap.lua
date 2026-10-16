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
	Diameter = 4,
	StartMin = 3,           -- bolas al empezar la partida
	StartMax = 5,
	GrowEvery = 2,          -- segundos entre cada subida del tope
	MaxAlive = 100,         -- tope maximo de bolas simultaneas
	Batch = 3,              -- bolas que puede soltar de golpe el spawner
	Interval = 0.6,         -- segundos entre rondas de aparicion
	LaunchSpeed = 62,
	LaunchUp = 6,
	SpreadDeg = 26,         -- dispersion del disparo del pilar
	Density = 0.5,
	Friction = 0.05,
	Elasticity = 0.85,
	MaxSpeed = 180,         -- tope de velocidad (evita atravesar muros)
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
-- Cuando la cara delantera de la pala (la que mira al centro de la mesa)
-- toca una bola, el servidor la lanza hacia el centro con fuerza. El punto
-- del ancho donde le da desvia el tiro, asi que se puede apuntar.
Config.Hit = {
	Enabled = true,
	Speed = 150,            -- velocidad a la que sale la bola (studs/segundo)
	Aim = 80,               -- desvio maximo al golpear en un extremo de la pala
	Reach = 4,              -- studs por delante de la cara que cuentan como toque
	Cooldown = 0.15,        -- segundos entre dos golpes a la misma bola
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
	Step = 0.35,            -- segundos entre cambio y cambio de inclinacion
	Jitter = 1.1,           -- tiron de direccion aleatorio (radianes)
	Pulse = 0.3,            -- latido rapido de la inclinacion
	WobbleSpeed = 3,        -- rad/s del latido
	TurnSpeed = 1.8,        -- rad/s del giro base de la direccion
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
local SERVER_SRC = nil
local CLIENT_SRC = nil
local EMBED_SCRIPTS = false

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