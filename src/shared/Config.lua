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
-- Cuando la cara delantera de la pala (la que mira al centro de la mesa)
-- toca una bola, el servidor la lanza hacia el centro con fuerza. El punto
-- del ancho donde le da desvia el tiro, asi que se puede apuntar.
Config.Hit = {
	Enabled = true,
	Speed = 120,            -- rebote normal de la pala (studs/segundo)
	Aim = 70,               -- desvio maximo al golpear en un extremo de la pala
	Reach = 4,              -- studs por delante de la cara que cuentan como toque
	Cooldown = 0.15,        -- segundos entre dos golpes a la misma bola
	-- Pulso de energia: el golpe fuerte de Ballistix. Se pulsa en el
	-- momento justo; si se gasta sin tocar ninguna bola, queda bloqueado
	-- un rato (por eso conviene esperar a tener una cerca).
	Power = 180,            -- velocidad del golpe con el pulso cargado
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
