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
local CONFIG_SRC = __CONFIG_SRC__
local SERVER_SRC = __SERVER_SRC__
local CLIENT_SRC = __CLIENT_SRC__
local EMBED_SCRIPTS = __EMBED_SCRIPTS__

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
