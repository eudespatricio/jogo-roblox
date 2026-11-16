--!strict
-- S8/S8.2: horda cosmetica em rig hibrido articulado (<=8 BaseParts incluindo RootPart).
-- Malhas Open Cloud esculpem tronco/capuz/elmo; pernas, bracos, cutelo e satelites orbitais
-- sao articulados no cliente a 60 Hz com ciclo de caminhada e golpe na muralha.

local IS_ROBLOX = type(game) == "userdata"
local cliRequire: any = require
local Mock: any = if IS_ROBLOX
	then nil
	else cliRequire("../../shared/visual/" .. "HeadlessRobloxMock")

local VisualTheme = if IS_ROBLOX
	then require(
		game:GetService("ReplicatedStorage")
			:WaitForChild("Shared")
			:WaitForChild("visual")
			:WaitForChild("VisualTheme")
	)
	else Mock.shared("VisualTheme") :: any
local MeshAssets = if IS_ROBLOX
	then require(
		game:GetService("ReplicatedStorage")
			:WaitForChild("Shared")
			:WaitForChild("visual")
			:WaitForChild("MeshAssets")
	)
	else Mock.shared("MeshAssets") :: any
local PortalThemes = if IS_ROBLOX
	then require(
		game:GetService("ReplicatedStorage")
			:WaitForChild("Shared")
			:WaitForChild("visual")
			:WaitForChild("PortalThemes")
	)
	else Mock.shared("PortalThemes") :: any

local ReplicatedStorage = if IS_ROBLOX
	then game:GetService("ReplicatedStorage")
	else Mock.game:GetService("ReplicatedStorage") :: typeof(game:GetService("ReplicatedStorage"))
local Instance = if IS_ROBLOX then Instance else Mock.Instance :: typeof(Instance)
local Vector3 = if IS_ROBLOX then Vector3 else Mock.Vector3 :: typeof(Vector3)
local CFrame = if IS_ROBLOX then CFrame else Mock.CFrame :: typeof(CFrame)
local Color3 = if IS_ROBLOX then Color3 else Mock.Color3 :: typeof(Color3)
local ColorSequence = if IS_ROBLOX
	then ColorSequence
	else Mock.ColorSequence :: typeof(ColorSequence)
local NumberSequence = if IS_ROBLOX
	then NumberSequence
	else Mock.NumberSequence :: typeof(NumberSequence)
local Enum = if IS_ROBLOX then Enum else Mock.Enum :: typeof(Enum)
local UDim = if IS_ROBLOX then UDim else Mock.UDim :: typeof(UDim)
local UDim2 = if IS_ROBLOX then UDim2 else Mock.UDim2 :: typeof(UDim2)
local task = if IS_ROBLOX then task else Mock.task :: typeof(task)
local time = if IS_ROBLOX then time else Mock.time :: typeof(time)

local HordeKit = {}

local HIT_SQUASH_DURATION = 0.09
local HIT_SQUASH_XZ = 1.18
local HIT_SQUASH_Y = 0.82
local GOLDEN_RATIO = 0.6180339
local DEG_TO_RAD = math.pi / 180

type EnemySpec = {
	label: string,
	color: { number },
	dark: { number },
	accent: { number }?,
	scale: number,
	parts: number,
	flying: boolean?,
}

type RigMetrics = {
	hipY: number,
	torsoMountY: number,
	torsoHeight: number,
}

local RIG_METRICS: { [string]: RigMetrics } = {
	runner = {
		hipY = 1.48,
		torsoMountY = 0.76,
		torsoHeight = 3.55,
	},
	brute = {
		hipY = 1.88,
		torsoMountY = 1.05,
		torsoHeight = 4.90,
	},
	swarm = {
		hipY = 1.05,
		torsoMountY = 0.92,
		torsoHeight = 2.05,
	},
	shieldbearer = {
		hipY = 1.68,
		torsoMountY = 0.92,
		torsoHeight = 4.25,
	},
	pyromancer = {
		hipY = 1.52,
		torsoMountY = 0.82,
		torsoHeight = 3.85,
	},
	sapper = {
		hipY = 1.42,
		torsoMountY = 0.74,
		torsoHeight = 3.45,
	},
	wisp = {
		hipY = 1.15,
		torsoMountY = 1.05,
		torsoHeight = 2.45,
	},
	drake = {
		hipY = 1.55,
		torsoMountY = 1.10,
		torsoHeight = 3.90,
	},
}

type TorsoPiece = {
	part: BasePart,
	size: Vector3,
	localCF: CFrame,
}

type LimbSpec = {
	part: BasePart,
	size: Vector3,
}

export type HordeUnit = {
	model: Model,
	rootPart: BasePart,
	base: CFrame,
	phase: number,
	kind: string,
	flying: boolean,
	isChampion: boolean,
	approachScale: number,
	squashUntil: number,
	squashSeq: number,
	squashed: boolean,
	lastX: number,
	lastNow: number,
	lastMoving: boolean,
	stillTime: number,
	attackBlend: number,
	torsoParts: { TorsoPiece },
	limbs: { [string]: LimbSpec },
	championCrest: BasePart?,
}

local EYE_NEON_COLOR = Color3.fromRGB(220, 255, 245)
local EMBER_NEON_COLOR = Color3.fromRGB(255, 199, 64)
local TEAL_SWARM_COLOR = Color3.fromRGB(45, 212, 191)
local WISP_CYAN_COLOR = Color3.fromRGB(165, 243, 252)
local DRAKE_GOLD_COLOR = Color3.fromRGB(245, 190, 48)
local CLEAVER_STEEL_COLOR = Color3.fromRGB(140, 145, 158)
local SHIELD_STEEL_COLOR = Color3.fromRGB(110, 122, 138)
local BLAST_PACK_COLOR = Color3.fromRGB(139, 90, 43)

local function rgb(value: { number }): Color3
	return Color3.fromRGB(value[1], value[2], value[3])
end

local function configurePart(piece: BasePart, color: Color3, material: Enum.Material): ()
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanTouch = false
	piece.CanQuery = false
	piece.CastShadow = true
	piece.Material = material
	piece.Color = color
end

local function makePart(
	parent: Instance,
	name: string,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.CFrame = CFrame.new(offset)
	configurePart(piece, color, material or Enum.Material.SmoothPlastic)
	if shape ~= nil then
		piece.Shape = shape
	end
	piece.Parent = parent
	return piece
end

-- Capsula/elipsoide organica sem quinas retangulares usando SpecialMesh(Sphere).
local function makeEllipsoid(
	parent: Instance,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local piece = makePart(parent, name, size, Vector3.zero, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = piece
	return piece
end

local function makeWedge(
	parent: Instance,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material?
): WedgePart
	local piece = Instance.new("WedgePart")
	piece.Name = name
	piece.Size = size
	piece.CFrame = CFrame.identity
	configurePart(piece, color, material or Enum.Material.Metal)
	piece.Parent = parent
	return piece
end

local function attachGhostTrail(part: BasePart, offsetY: number, color: Color3): ()
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailA0"
	a0.Position = Vector3.new(0, offsetY, 0)
	a0.Parent = part

	local a1 = Instance.new("Attachment")
	a1.Name = "TrailA1"
	a1.Position = Vector3.new(0, -offsetY, 0)
	a1.Parent = part

	local trail = Instance.new("Trail")
	trail.Name = "MotionTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.16
	trail.MinLength = 0.08
	trail.LightEmission = 0.75
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(color, EYE_NEON_COLOR)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	trail.Parent = part
end

-- Converte um TorsoGroup procedural (coordenadas locais ao redor da cintura Y=0) para TorsoPiece.
local function registerTorsoChildren(group: Instance, list: { TorsoPiece }): ()
	for _, desc in ipairs(group:GetDescendants()) do
		if desc:IsA("BasePart") then
			list[#list + 1] = {
				part = desc,
				size = desc.Size,
				localCF = desc.CFrame,
			}
		end
	end
end

-- Runner offline fallback (3 partes torso + 4 membros + RootPart = 8).
local function buildRunnerFallbackTorso(parent: Instance, spec: EnemySpec): { TorsoPiece }
	local torso = makeEllipsoid(
		parent,
		"Torso",
		Vector3.new(1.32, 1.95, 1.02),
		rgb(spec.color),
		Enum.Material.SmoothPlastic
	)
	torso.CFrame = CFrame.new(0, 1.28, 0)

	local hood = makePart(
		parent,
		"Head",
		Vector3.new(1.06, 1.18, 1.08),
		Vector3.new(0, 2.52, 0.02),
		rgb(spec.dark),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	hood.CFrame = CFrame.new(0, 2.52, 0.02)

	local visor = makeEllipsoid(
		parent,
		"Visor",
		Vector3.new(0.60, 0.18, 0.24),
		EYE_NEON_COLOR,
		Enum.Material.Neon
	)
	visor.CFrame = CFrame.new(0, 2.56, -0.46)

	local list: { TorsoPiece } = {}
	registerTorsoChildren(parent, list)
	return list
end

-- Brute offline fallback (2 partes torso + 5 membros + RootPart = 8).
local function buildBruteFallbackTorso(parent: Instance, spec: EnemySpec): { TorsoPiece }
	local torso = makeEllipsoid(
		parent,
		"Torso",
		Vector3.new(2.75, 2.95, 1.85),
		rgb(spec.color),
		Enum.Material.SmoothPlastic
	)
	torso.CFrame = CFrame.new(0, 1.75, 0)

	local head = makePart(
		parent,
		"Head",
		Vector3.new(1.42, 1.42, 1.42),
		Vector3.new(0, 3.65, -0.22),
		rgb(spec.dark),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	head.CFrame = CFrame.new(0, 3.65, -0.22)

	local list: { TorsoPiece } = {}
	registerTorsoChildren(parent, list)
	return list
end

-- Swarm offline fallback (3 partes torso + 4 membros/orbes + RootPart = 8).
local function buildSwarmFallbackTorso(parent: Instance, spec: EnemySpec): { TorsoPiece }
	local core = makePart(
		parent,
		"Core",
		Vector3.new(1.18, 1.18, 1.18),
		Vector3.new(0, 0.92, 0),
		rgb(spec.color),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	core.CFrame = CFrame.new(0, 0.92, 0)

	local crown = makePart(
		parent,
		"Crown",
		Vector3.new(0.76, 0.76, 0.76),
		Vector3.new(0, 1.56, 0.06),
		rgb(spec.dark),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	crown.CFrame = CFrame.new(0, 1.56, 0.06)

	local visor = makeEllipsoid(
		parent,
		"Visor",
		Vector3.new(0.46, 0.16, 0.22),
		EYE_NEON_COLOR,
		Enum.Material.Neon
	)
	visor.CFrame = CFrame.new(0, 1.00, -0.52)

	local list: { TorsoPiece } = {}
	registerTorsoChildren(parent, list)
	return list
end

-- Shieldbearer offline fallback (2 partes torso + 5 membros + RootPart = 8).
local function buildShieldbearerFallbackTorso(parent: Instance, spec: EnemySpec): { TorsoPiece }
	local torso = makeEllipsoid(
		parent,
		"Torso",
		Vector3.new(2.10, 2.35, 1.45),
		rgb(spec.color),
		Enum.Material.Metal
	)
	torso.CFrame = CFrame.new(0, 1.45, 0)

	local head = makePart(
		parent,
		"Head",
		Vector3.new(1.22, 1.24, 1.24),
		Vector3.new(0, 3.05, -0.10),
		rgb(spec.dark),
		Enum.Material.Metal,
		Enum.PartType.Ball
	)
	head.CFrame = CFrame.new(0, 3.05, -0.10)

	local list: { TorsoPiece } = {}
	registerTorsoChildren(parent, list)
	return list
end

-- Pyromancer offline fallback (3 partes torso + 4 membros + RootPart = 8).
local function buildPyromancerFallbackTorso(parent: Instance, spec: EnemySpec): { TorsoPiece }
	local torso = makeEllipsoid(
		parent,
		"Torso",
		Vector3.new(1.48, 2.15, 1.16),
		rgb(spec.color),
		Enum.Material.SmoothPlastic
	)
	torso.CFrame = CFrame.new(0, 1.38, 0)

	local emberCore = makePart(
		parent,
		"EmberCore",
		Vector3.new(0.56, 0.56, 0.34),
		Vector3.new(0, 1.50, -0.50),
		EMBER_NEON_COLOR,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	emberCore.CFrame = CFrame.new(0, 1.50, -0.50)

	local hood = makePart(
		parent,
		"Head",
		Vector3.new(1.12, 1.24, 1.12),
		Vector3.new(0, 2.72, -0.02),
		rgb(spec.dark),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	hood.CFrame = CFrame.new(0, 2.72, -0.02)

	local list: { TorsoPiece } = {}
	registerTorsoChildren(parent, list)
	return list
end

-- Sapper offline fallback (3 partes torso + 4 membros + RootPart = 8).
local function buildSapperFallbackTorso(parent: Instance, spec: EnemySpec): { TorsoPiece }
	local torso = makeEllipsoid(
		parent,
		"Torso",
		Vector3.new(1.36, 1.88, 1.08),
		rgb(spec.color),
		Enum.Material.SmoothPlastic
	)
	torso.CFrame = CFrame.new(0, 1.24, 0)

	local blastPack = makePart(
		parent,
		"BlastPack",
		Vector3.new(0.92, 1.12, 0.72),
		Vector3.new(0, 1.32, 0.68),
		BLAST_PACK_COLOR,
		Enum.Material.WoodPlanks
	)
	blastPack.CFrame = CFrame.new(0, 1.32, 0.68)

	local head = makePart(
		parent,
		"Head",
		Vector3.new(1.06, 1.10, 1.08),
		Vector3.new(0, 2.46, -0.04),
		rgb(spec.dark),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	head.CFrame = CFrame.new(0, 2.46, -0.04)

	local list: { TorsoPiece } = {}
	registerTorsoChildren(parent, list)
	return list
end

-- Wisp offline fallback (3 partes torso + 3 membros + RootPart = 7 <= 8).
local function buildWispFallbackTorso(parent: Instance, spec: EnemySpec): { TorsoPiece }
	local accentColor = if spec.accent ~= nil then rgb(spec.accent) else WISP_CYAN_COLOR
	local core = makePart(
		parent,
		"Core",
		Vector3.new(1.08, 1.08, 1.08),
		Vector3.new(0, 1.05, 0),
		accentColor,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	core.CFrame = CFrame.new(0, 1.05, 0)

	local cowl = makeEllipsoid(
		parent,
		"Cowl",
		Vector3.new(1.38, 1.56, 1.24),
		rgb(spec.dark),
		Enum.Material.SmoothPlastic
	)
	cowl.CFrame = CFrame.new(0, 1.32, 0.16)

	local visor = makeEllipsoid(
		parent,
		"Visor",
		Vector3.new(0.56, 0.22, 0.28),
		EYE_NEON_COLOR,
		Enum.Material.Neon
	)
	visor.CFrame = CFrame.new(0, 1.16, -0.52)

	local list: { TorsoPiece } = {}
	registerTorsoChildren(parent, list)
	return list
end

-- Drake offline fallback (4 partes torso + 5 membros + RootPart = 10 <= 12).
local function buildDrakeFallbackTorso(parent: Instance, spec: EnemySpec): { TorsoPiece }
	local goldColor = if spec.accent ~= nil then rgb(spec.accent) else DRAKE_GOLD_COLOR
	local torso = makeEllipsoid(
		parent,
		"Torso",
		Vector3.new(1.88, 1.45, 2.85),
		rgb(spec.color),
		Enum.Material.Metal
	)
	torso.CFrame = CFrame.new(0, 1.32, 0.08)

	local breastplate = makeEllipsoid(
		parent,
		"Breastplate",
		Vector3.new(1.36, 0.92, 1.85),
		goldColor,
		Enum.Material.Metal
	)
	breastplate.CFrame = CFrame.new(0, 1.08, -0.32)

	local head = makeEllipsoid(
		parent,
		"Head",
		Vector3.new(1.08, 0.92, 1.48),
		rgb(spec.dark),
		Enum.Material.Metal
	)
	head.CFrame = CFrame.new(0, 1.98, -1.56)

	local visor = makeEllipsoid(
		parent,
		"Visor",
		Vector3.new(0.76, 0.22, 0.36),
		EMBER_NEON_COLOR,
		Enum.Material.Neon
	)
	visor.CFrame = CFrame.new(0, 2.06, -2.14)

	local list: { TorsoPiece } = {}
	registerTorsoChildren(parent, list)
	return list
end

local function buildChampionCrest(model: Model): BasePart
	local haloColor = rgb(VisualTheme.CHAMPION.haloColor)
	local accentColor = rgb(VisualTheme.CHAMPION.accentColor)
	local crest = makePart(
		model,
		"ChampionCrest",
		Vector3.new(0.20, 1.72, 1.72),
		Vector3.zero,
		haloColor,
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	crest.CastShadow = false

	local tag = Instance.new("BillboardGui")
	tag.Name = "ChampionTag"
	tag.Size = UDim2.fromOffset(38, 18)
	tag.StudsOffset = Vector3.new(0, 1.25, 0)
	tag.AlwaysOnTop = false
	tag.MaxDistance = 110
	tag.Parent = crest

	local pill = Instance.new("Frame")
	pill.Name = "Pill"
	pill.Size = UDim2.fromScale(1, 1)
	pill.BackgroundColor3 = rgb(VisualTheme.PALETTE.ink)
	pill.BackgroundTransparency = 0.12
	pill.BorderSizePixel = 0
	pill.Parent = tag

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = pill

	local stroke = Instance.new("UIStroke")
	stroke.Color = accentColor
	stroke.Thickness = 1.5
	stroke.Parent = pill

	local star = Instance.new("TextLabel")
	star.Name = "Star"
	star.Size = UDim2.fromScale(1, 1)
	star.BackgroundTransparency = 1
	star.Text = "★"
	star.TextColor3 = haloColor
	star.Font = Enum.Font.GothamBlack
	star.TextScaled = true
	star.Parent = pill

	return crest
end

local function createLimbs(model: Instance, kind: string, spec: EnemySpec): { [string]: LimbSpec }
	local limbs: { [string]: LimbSpec } = {}
	local function add(name: string, p: BasePart): ()
		limbs[name] = { part = p, size = p.Size }
	end

	if kind == "brute" then
		local legSize = Vector3.new(0.84, 2.02, 0.92)
		local armSize = Vector3.new(0.70, 2.05, 0.74)
		add(
			"LegL",
			makeEllipsoid(model, "LegL", legSize, rgb(spec.dark), Enum.Material.SmoothPlastic)
		)
		add(
			"LegR",
			makeEllipsoid(model, "LegR", legSize, rgb(spec.dark), Enum.Material.SmoothPlastic)
		)
		add(
			"ArmL",
			makeEllipsoid(model, "ArmL", armSize, rgb(spec.color), Enum.Material.SmoothPlastic)
		)
		add(
			"ArmR",
			makeEllipsoid(model, "ArmR", armSize, rgb(spec.color), Enum.Material.SmoothPlastic)
		)
		local cleaver = makeWedge(
			model,
			"Cleaver",
			Vector3.new(0.26, 2.48, 1.12),
			CLEAVER_STEEL_COLOR,
			Enum.Material.Metal
		)
		attachGhostTrail(cleaver, 0.95, TEAL_SWARM_COLOR)
		add("Cleaver", cleaver)
	elseif kind == "shieldbearer" then
		local legSize = Vector3.new(0.62, 1.76, 0.68)
		local armSize = Vector3.new(0.50, 1.70, 0.54)
		add("LegL", makeEllipsoid(model, "LegL", legSize, rgb(spec.dark), Enum.Material.Metal))
		add("LegR", makeEllipsoid(model, "LegR", legSize, rgb(spec.dark), Enum.Material.Metal))
		add("ArmL", makeEllipsoid(model, "ArmL", armSize, rgb(spec.color), Enum.Material.Metal))
		add("ArmR", makeEllipsoid(model, "ArmR", armSize, rgb(spec.color), Enum.Material.Metal))
		local shield = makePart(
			model,
			"TowerShield",
			Vector3.new(1.85, 2.65, 0.28),
			Vector3.zero,
			SHIELD_STEEL_COLOR,
			Enum.Material.Metal
		)
		add("TowerShield", shield)
	elseif kind == "pyromancer" then
		local legSize = Vector3.new(0.42, 1.58, 0.48)
		local armSize = Vector3.new(0.34, 1.52, 0.42)
		add(
			"LegL",
			makeEllipsoid(model, "LegL", legSize, rgb(spec.dark), Enum.Material.SmoothPlastic)
		)
		add(
			"LegR",
			makeEllipsoid(model, "LegR", legSize, rgb(spec.dark), Enum.Material.SmoothPlastic)
		)
		local armL =
			makeEllipsoid(model, "ArmL", armSize, rgb(spec.color), Enum.Material.SmoothPlastic)
		local armR =
			makeEllipsoid(model, "ArmR", armSize, rgb(spec.color), Enum.Material.SmoothPlastic)
		attachGhostTrail(armL, 0.48, EMBER_NEON_COLOR)
		attachGhostTrail(armR, 0.48, EMBER_NEON_COLOR)
		add("ArmL", armL)
		add("ArmR", armR)
	elseif kind == "sapper" then
		local legSize = Vector3.new(0.40, 1.48, 0.46)
		local armSize = Vector3.new(0.32, 1.38, 0.40)
		add(
			"LegL",
			makeEllipsoid(model, "LegL", legSize, rgb(spec.dark), Enum.Material.SmoothPlastic)
		)
		add(
			"LegR",
			makeEllipsoid(model, "LegR", legSize, rgb(spec.dark), Enum.Material.SmoothPlastic)
		)
		add(
			"ArmL",
			makeEllipsoid(model, "ArmL", armSize, rgb(spec.color), Enum.Material.SmoothPlastic)
		)
		add(
			"ArmR",
			makeEllipsoid(model, "ArmR", armSize, rgb(spec.color), Enum.Material.SmoothPlastic)
		)
	elseif kind == "swarm" then
		local orbSize = Vector3.new(0.62, 0.62, 0.62)
		local tailSize = Vector3.new(0.28, 1.08, 0.30)
		local orbL = makePart(
			model,
			"OrbL",
			orbSize,
			Vector3.zero,
			rgb(spec.color),
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		local orbR = makePart(
			model,
			"OrbR",
			orbSize,
			Vector3.zero,
			rgb(spec.color),
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		attachGhostTrail(orbL, 0.20, rgb(spec.color))
		attachGhostTrail(orbR, 0.20, rgb(spec.color))
		add("OrbL", orbL)
		add("OrbR", orbR)
		add(
			"TailL",
			makeEllipsoid(model, "TailL", tailSize, rgb(spec.dark), Enum.Material.SmoothPlastic)
		)
		add(
			"TailR",
			makeEllipsoid(model, "TailR", tailSize, rgb(spec.dark), Enum.Material.SmoothPlastic)
		)
	elseif kind == "wisp" then
		local accentColor = if spec.accent ~= nil then rgb(spec.accent) else WISP_CYAN_COLOR
		local wispSize = Vector3.new(0.48, 0.48, 0.48)
		local wispL = makePart(
			model,
			"WispL",
			wispSize,
			Vector3.zero,
			rgb(spec.color),
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		local wispR = makePart(
			model,
			"WispR",
			wispSize,
			Vector3.zero,
			accentColor,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		attachGhostTrail(wispL, 0.22, accentColor)
		attachGhostTrail(wispR, 0.22, rgb(spec.color))
		add("WispL", wispL)
		add("WispR", wispR)
		add(
			"TailWisp",
			makeEllipsoid(
				model,
				"TailWisp",
				Vector3.new(0.44, 1.35, 0.44),
				rgb(spec.color),
				Enum.Material.Neon
			)
		)
	elseif kind == "drake" then
		local goldColor = if spec.accent ~= nil then rgb(spec.accent) else DRAKE_GOLD_COLOR
		local wingSize = Vector3.new(2.65, 0.16, 1.58)
		local wingL = makeWedge(model, "WingL", wingSize, rgb(spec.dark), Enum.Material.Metal)
		local wingR = makeWedge(model, "WingR", wingSize, rgb(spec.dark), Enum.Material.Metal)
		attachGhostTrail(wingL, 0.12, goldColor)
		attachGhostTrail(wingR, 0.12, goldColor)
		add("WingL", wingL)
		add("WingR", wingR)
		add(
			"Tail",
			makeEllipsoid(
				model,
				"Tail",
				Vector3.new(0.52, 0.52, 2.15),
				goldColor,
				Enum.Material.Metal
			)
		)
		add(
			"LegL",
			makeEllipsoid(
				model,
				"LegL",
				Vector3.new(0.44, 1.05, 0.48),
				rgb(spec.dark),
				Enum.Material.Metal
			)
		)
		add(
			"LegR",
			makeEllipsoid(
				model,
				"LegR",
				Vector3.new(0.44, 1.05, 0.48),
				rgb(spec.dark),
				Enum.Material.Metal
			)
		)
	else
		local legSize = Vector3.new(0.38, 1.56, 0.44)
		local armSize = Vector3.new(0.30, 1.50, 0.44)
		add(
			"LegL",
			makeEllipsoid(model, "LegL", legSize, rgb(spec.dark), Enum.Material.SmoothPlastic)
		)
		add(
			"LegR",
			makeEllipsoid(model, "LegR", legSize, rgb(spec.dark), Enum.Material.SmoothPlastic)
		)
		local armL =
			makeEllipsoid(model, "ArmL", armSize, rgb(spec.color), Enum.Material.SmoothPlastic)
		local armR =
			makeEllipsoid(model, "ArmR", armSize, rgb(spec.color), Enum.Material.SmoothPlastic)
		attachGhostTrail(armL, 0.45, TEAL_SWARM_COLOR)
		attachGhostTrail(armR, 0.45, TEAL_SWARM_COLOR)
		add("ArmL", armL)
		add("ArmR", armR)
	end

	return limbs
end

type BossSpec = {
	label: string,
	color: { number },
	accent: { number },
	scale: number,
	height: number,
}

type BossRigMetrics = {
	hipY: number,
	torsoHeight: number,
	hipX: number,
	shoulderX: number,
	shoulderY: number,
	shoulderZ: number,
}

type BossSlots = {
	torso: { TorsoPiece },
	armR: { TorsoPiece },
	armL: { TorsoPiece },
	legL: { TorsoPiece },
	legR: { TorsoPiece },
}

type BossMountedSlots = {
	torso: boolean,
	armR: boolean,
	armL: boolean,
	legL: boolean,
	legR: boolean,
}

export type BossUnit = {
	model: Model,
	rootPart: BasePart,
	base: CFrame,
	bossId: string,
	height: number,
	approachScale: number,
	color: Color3,
	accent: Color3,
	squashUntil: number,
	squashSeq: number,
	squashed: boolean,
	lastState: string,
	lastEnraged: boolean,
	lastNow: number,
	deathStartAt: number?,
	rigMetrics: BossRigMetrics,
	slots: BossSlots,
	mountedSlots: BossMountedSlots,
	torsoMeshScale: number?,
	stateHighlight: Highlight,
}

local BOSS_HIT_KNOCKBACK_DURATION = 0.11
local BOSS_HIT_KNOCKBACK_Z = 0.32
local BOSS_HIT_FLINCH_DEG = 6
local BOSS_DEATH_DURATION = 0.85

local pendingHordeUnits: { [Model]: HordeUnit } = {}
local pendingBossUnits: { [Model]: BossUnit } = {}
local assetsFolderConn: RBXScriptConnection? = nil
local repAddedConn: RBXScriptConnection? = nil

local function configureHordeMeshPart(part: BasePart, hidden: boolean): ()
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = true
	part.Transparency = if hidden then 1 else 0
end

local function tryMountScaledMesh(model: Model, assetName: string, targetH: number): { TorsoPiece }?
	local assetsFolder = ReplicatedStorage:FindFirstChild(MeshAssets.FOLDER)
	if assetsFolder == nil then
		return nil
	end
	local template = assetsFolder:FindFirstChild(assetName)
	if template == nil then
		return nil
	end

	if model:GetScale() ~= 1 then
		model:ScaleTo(1)
	end

	local oldMesh = model:FindFirstChild("MeshVisual")
	if oldMesh ~= nil then
		oldMesh:Destroy()
	end

	local hidden = model:GetAttribute("Hidden") == true
	local clone = template:Clone()
	clone.Name = "MeshVisual"
	local pieces: { TorsoPiece } = {}

	if clone:IsA("Model") then
		for _, desc in ipairs(clone:GetDescendants()) do
			if desc:IsA("BasePart") then
				configureHordeMeshPart(desc, hidden)
			end
		end
		clone.Parent = model
		local _, rawSize = clone:GetBoundingBox()
		if rawSize.Y > 0.05 then
			clone:ScaleTo(clone:GetScale() * (targetH / rawSize.Y))
		end
		-- Importador glTF do Roblox ja entrega a frente da malha em -Z; apenas ancorar na base inferior.
		local bbCf, bbSize = clone:GetBoundingBox()
		local bottomCenter =
			Vector3.new(bbCf.Position.X, bbCf.Position.Y - bbSize.Y * 0.5, bbCf.Position.Z)
		local toRigLocal = CFrame.new(-bottomCenter)
		for _, desc in ipairs(clone:GetDescendants()) do
			if desc:IsA("BasePart") then
				local localCF = toRigLocal * desc.CFrame
				pieces[#pieces + 1] = {
					part = desc,
					size = desc.Size,
					localCF = localCF,
				}
			end
		end
	elseif clone:IsA("BasePart") then
		configureHordeMeshPart(clone, hidden)
		local rawY = clone.Size.Y
		if rawY > 0.05 then
			clone.Size = clone.Size * (targetH / rawY)
		end
		clone.CFrame = CFrame.new(0, clone.Size.Y * 0.5, 0) * clone.CFrame.Rotation
		clone.Parent = model
		pieces[#pieces + 1] = {
			part = clone,
			size = clone.Size,
			localCF = clone.CFrame,
		}
	else
		clone:Destroy()
		return nil
	end

	if #pieces == 0 then
		clone:Destroy()
		return nil
	end

	local proc = model:FindFirstChild("ProceduralVisual")
	if proc ~= nil then
		proc:Destroy()
	end

	model:SetAttribute("HasMeshVisual", true)
	return pieces
end

local function tryMountHordeMesh(model: Model, kind: string): { TorsoPiece }?
	local metrics = RIG_METRICS[kind] or RIG_METRICS.runner
	return tryMountScaledMesh(model, MeshAssets.hordeModelName(kind), metrics.torsoHeight)
end

local function computeBossRigMetrics(bossId: string, height: number): BossRigMetrics
	local hipY = height * 0.42
	local torsoHeight = height * 0.58
	if bossId == "slag_juggernaut" then
		return {
			hipY = hipY,
			torsoHeight = torsoHeight,
			hipX = height * 0.18,
			shoulderX = torsoHeight * 0.44,
			shoulderY = torsoHeight * 0.46,
			shoulderZ = 0,
		}
	elseif bossId == "rime_matriarch" then
		return {
			hipY = hipY,
			torsoHeight = torsoHeight,
			hipX = height * 0.13,
			shoulderX = torsoHeight * 0.34,
			shoulderY = torsoHeight * 0.50,
			shoulderZ = -torsoHeight * 0.03,
		}
	elseif bossId == "powder_baron" then
		return {
			hipY = hipY,
			torsoHeight = torsoHeight,
			hipX = height * 0.15,
			shoulderX = torsoHeight * 0.36,
			shoulderY = torsoHeight * 0.52,
			shoulderZ = 0,
		}
	elseif bossId == "rift_titan" then
		return {
			hipY = hipY,
			torsoHeight = torsoHeight,
			hipX = height * 0.15,
			shoulderX = torsoHeight * 0.35,
			shoulderY = torsoHeight * 0.48,
			shoulderZ = -torsoHeight * 0.03,
		}
	end
	return {
		hipY = hipY,
		torsoHeight = torsoHeight,
		hipX = height * 0.16,
		shoulderX = torsoHeight * 0.39,
		shoulderY = torsoHeight * 0.54,
		shoulderZ = 0,
	}
end

local function computeBossPartAnchor(partKey: string, bbCf: CFrame, bbSize: Vector3): Vector3
	local pos = bbCf.Position
	if partKey == "torso" then
		return Vector3.new(pos.X, pos.Y - bbSize.Y * 0.5, pos.Z)
	elseif partKey == "leg_l" or partKey == "leg_r" then
		return Vector3.new(pos.X, pos.Y + bbSize.Y * 0.5, pos.Z)
	elseif partKey == "arm_l" then
		return Vector3.new(pos.X, pos.Y + bbSize.Y * 0.44, pos.Z)
	end
	return Vector3.new(pos.X, pos.Y + bbSize.Y * 0.42, pos.Z + bbSize.Z * 0.28)
end

local function ensureChildFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function mountBossSlotMesh(
	model: Model,
	slotName: string,
	partKey: string,
	assetName: string,
	targetHeight: number?,
	uniformScale: number?
): ({ TorsoPiece }?, number?)
	local assetsFolder = ReplicatedStorage:FindFirstChild(MeshAssets.FOLDER)
	if assetsFolder == nil then
		return nil, nil
	end
	local template = assetsFolder:FindFirstChild(assetName)
	if template == nil then
		return nil, nil
	end

	local meshSlots = ensureChildFolder(model, "MeshSlots")
	local oldSlot = meshSlots:FindFirstChild(slotName)
	if oldSlot ~= nil then
		oldSlot:Destroy()
	end

	local hidden = model:GetAttribute("Hidden") == true
	local clone = template:Clone()
	clone.Name = slotName
	local pieces: { TorsoPiece } = {}
	local appliedScale: number? = nil

	if clone:IsA("Model") then
		for _, desc in ipairs(clone:GetDescendants()) do
			if desc:IsA("BasePart") then
				configureHordeMeshPart(desc, hidden)
			end
		end
		clone.Parent = meshSlots
		local _, rawSize = clone:GetBoundingBox()
		local scaleFactor = 1
		if targetHeight ~= nil and rawSize.Y > 0.05 then
			scaleFactor = targetHeight / rawSize.Y
		elseif uniformScale ~= nil and uniformScale > 0 then
			scaleFactor = uniformScale
		end
		appliedScale = scaleFactor
		if scaleFactor ~= 1 then
			clone:ScaleTo(clone:GetScale() * scaleFactor)
		end
		local bbCf, bbSize = clone:GetBoundingBox()
		local anchorPos = computeBossPartAnchor(partKey, bbCf, bbSize)
		local toJointLocal = CFrame.new(-anchorPos)
		for _, desc in ipairs(clone:GetDescendants()) do
			if desc:IsA("BasePart") then
				pieces[#pieces + 1] = {
					part = desc,
					size = desc.Size,
					localCF = toJointLocal * desc.CFrame,
				}
			end
		end
	elseif clone:IsA("BasePart") then
		configureHordeMeshPart(clone, hidden)
		local rawY = clone.Size.Y
		local scaleFactor = 1
		if targetHeight ~= nil and rawY > 0.05 then
			scaleFactor = targetHeight / rawY
		elseif uniformScale ~= nil and uniformScale > 0 then
			scaleFactor = uniformScale
		end
		appliedScale = scaleFactor
		if scaleFactor ~= 1 then
			clone.Size = clone.Size * scaleFactor
		end
		clone.CFrame = CFrame.identity * clone.CFrame.Rotation
		clone.Parent = meshSlots
		local anchorPos = computeBossPartAnchor(partKey, clone.CFrame, clone.Size)
		local toJointLocal = CFrame.new(-anchorPos)
		pieces[#pieces + 1] = {
			part = clone,
			size = clone.Size,
			localCF = toJointLocal * clone.CFrame,
		}
	else
		clone:Destroy()
		return nil, nil
	end

	if #pieces == 0 then
		clone:Destroy()
		return nil, nil
	end

	local proc = model:FindFirstChild("ProceduralVisual")
	if proc ~= nil then
		local procSlot = proc:FindFirstChild("Slot_" .. slotName)
		if procSlot ~= nil then
			procSlot:Destroy()
		end
	end

	return pieces, appliedScale
end

local function tryMountBossFivePartRig(unit: BossUnit): boolean
	local assetsFolder = ReplicatedStorage:FindFirstChild(MeshAssets.FOLDER)
	if assetsFolder == nil then
		return false
	end

	local model = unit.model
	if model:GetScale() ~= 1 then
		model:ScaleTo(1)
	end

	local bossId = unit.bossId
	local m = unit.rigMetrics

	if not unit.mountedSlots.torso then
		local pieces, torsoScale = mountBossSlotMesh(
			model,
			"torso",
			"torso",
			MeshAssets.bossPartModelName(bossId, "torso"),
			m.torsoHeight,
			nil
		)
		if pieces ~= nil then
			unit.slots.torso = pieces
			unit.mountedSlots.torso = true
			unit.torsoMeshScale = torsoScale
		end
	end

	if not unit.mountedSlots.legL then
		local pieces = mountBossSlotMesh(
			model,
			"legL",
			"leg_l",
			MeshAssets.bossPartModelName(bossId, "leg_l"),
			m.hipY,
			nil
		)
		if pieces ~= nil then
			unit.slots.legL = pieces
			unit.mountedSlots.legL = true
		end
	end

	if not unit.mountedSlots.legR then
		local pieces = mountBossSlotMesh(
			model,
			"legR",
			"leg_r",
			MeshAssets.bossPartModelName(bossId, "leg_r"),
			m.hipY,
			nil
		)
		if pieces ~= nil then
			unit.slots.legR = pieces
			unit.mountedSlots.legR = true
		end
	end

	local armScale = unit.torsoMeshScale
	if armScale ~= nil then
		if not unit.mountedSlots.armL then
			local pieces = mountBossSlotMesh(
				model,
				"armL",
				"arm_l",
				MeshAssets.bossPartModelName(bossId, "arm_l"),
				nil,
				armScale
			)
			if pieces ~= nil then
				unit.slots.armL = pieces
				unit.mountedSlots.armL = true
			end
		end
		if not unit.mountedSlots.armR then
			local pieces = mountBossSlotMesh(
				model,
				"armR",
				"arm_r",
				MeshAssets.bossPartModelName(bossId, "arm_r"),
				nil,
				armScale
			)
			if pieces ~= nil then
				unit.slots.armR = pieces
				unit.mountedSlots.armR = true
			end
		end
	end

	local ms = unit.mountedSlots
	if ms.torso and ms.armR and ms.armL and ms.legL and ms.legR then
		local proc = model:FindFirstChild("ProceduralVisual")
		if proc ~= nil then
			proc:Destroy()
		end
		model:SetAttribute("HasMeshVisual", true)
		return true
	end
	return false
end

local function placeScaled(
	rootCF: CFrame,
	part: BasePart,
	baseSize: Vector3,
	worldCF: CFrame,
	sxz: number,
	sy: number
): ()
	if sxz == 1 and sy == 1 then
		part.Size = baseSize
		part.CFrame = worldCF
		return
	end
	part.Size = Vector3.new(baseSize.X * sxz, baseSize.Y * sy, baseSize.Z * sxz)
	local rel = rootCF:ToObjectSpace(worldCF)
	local pos = rel.Position
	local scaledPos = Vector3.new(pos.X * sxz, pos.Y * sy, pos.Z * sxz)
	part.CFrame = rootCF * CFrame.new(scaledPos) * (rel - pos)
end

-- Poses a 60 Hz: +X direita, +Y cima, -Z frente em rigCF (rotacionado +90 deg -> encara muralha em -X).
local function poseUnit(unit: HordeUnit, now: number, moving: boolean): ()
	local metrics = RIG_METRICS[unit.kind] or RIG_METRICS.runner
	local approach = math.clamp(unit.approachScale, 0.45, 1.25)
	local hoverY = 0
	if unit.flying then
		local hoverRamp = math.clamp(
			(approach - PortalThemes.MIN_SCALE) / (PortalThemes.MAX_SCALE - PortalThemes.MIN_SCALE),
			0,
			1
		)
		local hoverBob = math.sin(now * VisualTheme.AERIAL.bobSpeed + unit.phase)
			* VisualTheme.AERIAL.bobAmplitude
		hoverY = (VisualTheme.AERIAL.hoverY + hoverBob) * hoverRamp
	end

	local rigCF = CFrame.new(unit.base.Position + Vector3.new(0, hoverY, 0))
		* unit.base.Rotation
		* CFrame.Angles(0, math.rad(90), 0)
	unit.rootPart.CFrame = rigCF

	local champScale = if unit.isChampion then VisualTheme.CHAMPION.scale else 1
	local sxz = 1
	local sy = 1
	if now < unit.squashUntil then
		local alpha = math.clamp(1 - (unit.squashUntil - now) / HIT_SQUASH_DURATION, 0, 1)
		sxz = HIT_SQUASH_XZ + (1 - HIT_SQUASH_XZ) * alpha
		sy = HIT_SQUASH_Y + (1 - HIT_SQUASH_Y) * alpha
		unit.squashed = true
	elseif unit.squashed then
		unit.squashed = false
	end
	sxz *= approach * champScale
	sy *= approach * champScale

	local posX = unit.base.Position.X
	if unit.lastNow > 0 then
		local dt = math.clamp(now - unit.lastNow, 0, 0.1)
		local movedX = math.abs(posX - unit.lastX)
		if moving then
			if movedX > 0.0015 then
				unit.stillTime = 0
				unit.attackBlend = math.max(0, unit.attackBlend - dt * 8.0)
			else
				unit.stillTime += dt
				if unit.stillTime > 0.12 then
					unit.attackBlend = math.min(1, unit.attackBlend + dt * 6.0)
				end
			end
		else
			unit.stillTime = 0
			unit.attackBlend = math.max(0, unit.attackBlend - dt * 6.0)
		end
	end
	unit.lastX = posX
	unit.lastNow = now
	unit.lastMoving = moving

	local walkWeight = if moving then (1 - unit.attackBlend * 0.72) else 0
	local atkWeight = if moving then unit.attackBlend else 0
	local torsoCF: CFrame

	if unit.kind == "brute" then
		local omega = 7.4 + atkWeight * 2.2
		local p = now * omega + unit.phase
		local swing = math.sin(p) * walkWeight
		local stompBounce = math.abs(math.cos(p)) * 0.24 * walkWeight
		local roll = math.sin(p) * (9 * DEG_TO_RAD) * walkWeight
		local hunch = -(10 * DEG_TO_RAD) * walkWeight
		local atkHeave = math.sin(p * 1.15) * (16 * DEG_TO_RAD) * atkWeight

		torsoCF = rigCF
			* CFrame.new(0, metrics.torsoMountY + stompBounce, 0)
			* CFrame.Angles(hunch + atkHeave, math.sin(p) * 0.10 * (walkWeight + atkWeight), roll)

		local legL = unit.limbs.LegL
		local legR = unit.limbs.LegR
		if legL ~= nil then
			local lCF = rigCF
				* CFrame.new(-0.64, metrics.hipY + stompBounce * 0.4, 0)
				* CFrame.Angles(swing * 0.56, 0, 0)
				* CFrame.new(0, -0.92, 0)
			placeScaled(rigCF, legL.part, legL.size, lCF, sxz, sy)
		end
		if legR ~= nil then
			local rCF = rigCF
				* CFrame.new(0.64, metrics.hipY + stompBounce * 0.4, 0)
				* CFrame.Angles(-swing * 0.56, 0, 0)
				* CFrame.new(0, -0.92, 0)
			placeScaled(rigCF, legR.part, legR.size, rCF, sxz, sy)
		end

		local armL = unit.limbs.ArmL
		local armR = unit.limbs.ArmR
		local cleaver = unit.limbs.Cleaver
		if armL ~= nil then
			local aLCF = torsoCF
				* CFrame.new(-1.44, 2.95, -0.06)
				* CFrame.Angles(-swing * 0.58 + 0.18 * atkWeight, 0, math.rad(-8))
				* CFrame.new(0, -0.92, 0)
			placeScaled(rigCF, armL.part, armL.size, aLCF, sxz, sy)
		end
		if armR ~= nil then
			-- Walk: balanco pesado com o cutelo; Ataque: ergue alto e corta contra a muralha.
			local walkArmPitch = 0.28 + math.sin(p) * 0.62
			local atkArmPitch = 0.90 + math.sin(p * 1.15 - 0.5) * 0.95
			local rPitch = walkArmPitch * (1 - atkWeight) + atkArmPitch * atkWeight
			local rJointCF = torsoCF
				* CFrame.new(1.44, 2.95, -0.06)
				* CFrame.Angles(rPitch, 0, math.rad(8))
			local aRCF = rJointCF * CFrame.new(0, -0.92, 0)
			placeScaled(rigCF, armR.part, armR.size, aRCF, sxz, sy)
			if cleaver ~= nil then
				local cCF = rJointCF
					* CFrame.new(0.05, -1.82, -1.05)
					* CFrame.Angles(math.rad(-105), 0, 0)
				placeScaled(rigCF, cleaver.part, cleaver.size, cCF, sxz, sy)
			end
		end
	elseif unit.kind == "swarm" then
		local omega = 14.5 + atkWeight * 4.5
		local p = now * omega + unit.phase
		local swarmHoverY = math.sin(p * 0.65) * 0.32
		local weaveX = math.cos(p * 0.45) * 0.24
		local lungeZ = -math.max(0, math.sin(p * 1.1)) * 0.65 * atkWeight
		local bank = math.sin(p * 0.45) * (14 * DEG_TO_RAD)

		torsoCF = rigCF
			* CFrame.new(weaveX, metrics.torsoMountY + swarmHoverY, lungeZ)
			* CFrame.Angles(-(10 * DEG_TO_RAD) * (walkWeight + atkWeight), 0, bank)

		local radius = 1.28 + atkWeight * 0.25
		local orbL = unit.limbs.OrbL
		local orbR = unit.limbs.OrbR
		if orbL ~= nil then
			local lCF = rigCF
				* CFrame.new(
					math.cos(p) * radius,
					1.65 + math.sin(p * 2) * 0.46,
					math.sin(p) * (radius * 0.85) + lungeZ
				)
			placeScaled(rigCF, orbL.part, orbL.size, lCF, sxz, sy)
		end
		if orbR ~= nil then
			local rCF = rigCF
				* CFrame.new(
					math.cos(p + math.pi) * radius,
					1.65 + math.sin((p + math.pi) * 2) * 0.46,
					math.sin(p + math.pi) * (radius * 0.85) + lungeZ
				)
			placeScaled(rigCF, orbR.part, orbR.size, rCF, sxz, sy)
		end

		local tailL = unit.limbs.TailL
		local tailR = unit.limbs.TailR
		if tailL ~= nil then
			local tLCF = torsoCF
				* CFrame.new(-0.30, 0.42, 0.22)
				* CFrame.Angles(math.sin(p * 1.3) * 0.48 - 0.35, 0, math.rad(-14))
				* CFrame.new(0, -0.45, 0)
			placeScaled(rigCF, tailL.part, tailL.size, tLCF, sxz, sy)
		end
		if tailR ~= nil then
			local tRCF = torsoCF
				* CFrame.new(0.30, 0.42, 0.22)
				* CFrame.Angles(-math.sin(p * 1.3) * 0.48 - 0.35, 0, math.rad(14))
				* CFrame.new(0, -0.45, 0)
			placeScaled(rigCF, tailR.part, tailR.size, tRCF, sxz, sy)
		end
	elseif unit.kind == "shieldbearer" then
		local omega = 8.4 + atkWeight * 2.4
		local p = now * omega + unit.phase
		local swing = math.sin(p) * walkWeight
		local stompBounce = math.abs(math.cos(p)) * 0.16 * walkWeight
		local braceLean = -(8 * DEG_TO_RAD) * walkWeight
			+ math.sin(p * 1.1) * (12 * DEG_TO_RAD) * atkWeight

		torsoCF = rigCF
			* CFrame.new(0, metrics.torsoMountY + stompBounce, 0)
			* CFrame.Angles(
				braceLean,
				math.sin(p) * 0.06 * walkWeight,
				math.sin(p) * (5 * DEG_TO_RAD) * walkWeight
			)

		local legL = unit.limbs.LegL
		local legR = unit.limbs.LegR
		if legL ~= nil then
			local lCF = rigCF
				* CFrame.new(-0.48, metrics.hipY + stompBounce * 0.4, 0)
				* CFrame.Angles(swing * 0.52, 0, 0)
				* CFrame.new(0, -0.82, 0)
			placeScaled(rigCF, legL.part, legL.size, lCF, sxz, sy)
		end
		if legR ~= nil then
			local rCF = rigCF
				* CFrame.new(0.48, metrics.hipY + stompBounce * 0.4, 0)
				* CFrame.Angles(-swing * 0.52, 0, 0)
				* CFrame.new(0, -0.82, 0)
			placeScaled(rigCF, legR.part, legR.size, rCF, sxz, sy)
		end

		local armL = unit.limbs.ArmL
		local armR = unit.limbs.ArmR
		local shield = unit.limbs.TowerShield
		if armL ~= nil then
			local lJointCF = torsoCF
				* CFrame.new(-1.08, 2.24, -0.18)
				* CFrame.Angles(
					0.52 + atkWeight * 0.42 * math.sin(p * 1.1),
					math.rad(16),
					math.rad(-8)
				)
			placeScaled(rigCF, armL.part, armL.size, lJointCF * CFrame.new(0, -0.75, 0), sxz, sy)
			if shield ~= nil then
				local sCF = torsoCF
					* CFrame.new(
						-0.28,
						1.55,
						-0.96 - atkWeight * 0.35 * math.max(0, math.sin(p * 1.1))
					)
					* CFrame.Angles(math.rad(6), math.rad(-10), 0)
				placeScaled(rigCF, shield.part, shield.size, sCF, sxz, sy)
			end
		end
		if armR ~= nil then
			local rPitch = swing * 0.60 + atkWeight * (0.75 + math.sin(p) * 0.62)
			local aRCF = torsoCF
				* CFrame.new(1.08, 2.24, -0.06)
				* CFrame.Angles(rPitch, 0, math.rad(10))
				* CFrame.new(0, -0.75, 0)
			placeScaled(rigCF, armR.part, armR.size, aRCF, sxz, sy)
		end
	elseif unit.kind == "pyromancer" then
		local omega = 10.8 + atkWeight * 3.2
		local p = now * omega + unit.phase
		local swing = math.sin(p) * walkWeight
		local hoverBounce = math.abs(math.sin(p)) * 0.18 * walkWeight
			+ math.sin(p * 1.5) * 0.08 * atkWeight

		torsoCF = rigCF
			* CFrame.new(0, metrics.torsoMountY + hoverBounce, 0)
			* CFrame.Angles(
				-(10 * DEG_TO_RAD) * walkWeight,
				math.sin(p) * 0.08,
				math.cos(p) * (4 * DEG_TO_RAD) * walkWeight
			)

		local legL = unit.limbs.LegL
		local legR = unit.limbs.LegR
		if legL ~= nil then
			local lCF = rigCF
				* CFrame.new(-0.36, metrics.hipY + hoverBounce * 0.4, 0)
				* CFrame.Angles(swing * 0.62, 0, 0)
				* CFrame.new(0, -0.76, 0)
			placeScaled(rigCF, legL.part, legL.size, lCF, sxz, sy)
		end
		if legR ~= nil then
			local rCF = rigCF
				* CFrame.new(0.36, metrics.hipY + hoverBounce * 0.4, 0)
				* CFrame.Angles(-swing * 0.62, 0, 0)
				* CFrame.new(0, -0.76, 0)
			placeScaled(rigCF, legR.part, legR.size, rCF, sxz, sy)
		end

		local armL = unit.limbs.ArmL
		local armR = unit.limbs.ArmR
		if armL ~= nil then
			local castPitch = 0.65 + math.sin(p) * 0.55 + atkWeight * 0.75
			local aLCF = torsoCF
				* CFrame.new(-0.82, 1.86, -0.06)
				* CFrame.Angles(castPitch, 0, math.rad(-18))
				* CFrame.new(0, -0.68, 0)
			placeScaled(rigCF, armL.part, armL.size, aLCF, sxz, sy)
		end
		if armR ~= nil then
			local castPitch = 0.65 - math.sin(p) * 0.55 + atkWeight * 0.75
			local aRCF = torsoCF
				* CFrame.new(0.82, 1.86, -0.06)
				* CFrame.Angles(castPitch, 0, math.rad(18))
				* CFrame.new(0, -0.68, 0)
			placeScaled(rigCF, armR.part, armR.size, aRCF, sxz, sy)
		end
	elseif unit.kind == "wisp" then
		local omega = 8.4 + atkWeight * 3.2
		local p = now * omega + unit.phase
		local driftX = math.cos(p * 0.55) * 0.20
		local driftY = math.sin(p * 0.75) * 0.16
		local lungeZ = -math.max(0, math.sin(p * 1.15)) * 0.50 * atkWeight

		torsoCF = rigCF
			* CFrame.new(driftX, metrics.torsoMountY + driftY, lungeZ)
			* CFrame.Angles(
				-(12 * DEG_TO_RAD) * (walkWeight + atkWeight),
				0,
				math.sin(p * 0.5) * (8 * DEG_TO_RAD)
			)

		local radius = 1.24 + atkWeight * 0.25
		local wispL = unit.limbs.WispL
		local wispR = unit.limbs.WispR
		if wispL ~= nil then
			local lCF = torsoCF
				* CFrame.new(
					math.cos(p) * radius,
					1.05 + math.sin(p * 2) * 0.34,
					math.sin(p) * (radius * 0.85)
				)
			placeScaled(rigCF, wispL.part, wispL.size, lCF, sxz, sy)
		end
		if wispR ~= nil then
			local rCF = torsoCF
				* CFrame.new(
					math.cos(p + math.pi) * radius,
					1.05 + math.sin((p + math.pi) * 2) * 0.34,
					math.sin(p + math.pi) * (radius * 0.85)
				)
			placeScaled(rigCF, wispR.part, wispR.size, rCF, sxz, sy)
		end

		local tailWisp = unit.limbs.TailWisp
		if tailWisp ~= nil then
			local tCF = torsoCF
				* CFrame.new(0, 0.35, 0.42)
				* CFrame.Angles(math.rad(34) + math.sin(p * 1.4) * 0.24, 0, math.cos(p) * 0.16)
				* CFrame.new(0, -0.55, 0)
			placeScaled(rigCF, tailWisp.part, tailWisp.size, tCF, sxz, sy)
		end
	elseif unit.kind == "drake" then
		local omega = VisualTheme.AERIAL.wingSpeed + atkWeight * 3.0
		local p = now * omega + unit.phase
		local flap = math.sin(p) * (VisualTheme.AERIAL.wingAmplitudeDeg * DEG_TO_RAD)
		local counterBob = -math.sin(p) * 0.18
		local divePitch = -(8 * DEG_TO_RAD) * walkWeight
			+ math.sin(p * 1.2) * (14 * DEG_TO_RAD) * atkWeight

		torsoCF = rigCF
			* CFrame.new(0, metrics.torsoMountY + counterBob, 0)
			* CFrame.Angles(
				divePitch,
				math.sin(p * 0.5) * 0.06,
				math.cos(p * 0.5) * (4 * DEG_TO_RAD)
			)

		local wingL = unit.limbs.WingL
		local wingR = unit.limbs.WingR
		if wingL ~= nil then
			local wLCF = torsoCF
				* CFrame.new(-0.88, 1.65, -0.15)
				* CFrame.Angles(0, math.rad(12), flap)
				* CFrame.new(-1.32, 0, 0.18)
			placeScaled(rigCF, wingL.part, wingL.size, wLCF, sxz, sy)
		end
		if wingR ~= nil then
			local wRCF = torsoCF
				* CFrame.new(0.88, 1.65, -0.15)
				* CFrame.Angles(0, math.rad(-12), -flap)
				* CFrame.new(1.32, 0, 0.18)
			placeScaled(rigCF, wingR.part, wingR.size, wRCF, sxz, sy)
		end

		local tail = unit.limbs.Tail
		if tail ~= nil then
			local tailCF = torsoCF
				* CFrame.new(0, 1.15, 1.35)
				* CFrame.Angles(-0.18 + math.sin(p) * 0.14, math.cos(p * 0.5) * 0.18, 0)
				* CFrame.new(0, 0, 0.95)
			placeScaled(rigCF, tail.part, tail.size, tailCF, sxz, sy)
		end

		local legL = unit.limbs.LegL
		local legR = unit.limbs.LegR
		if legL ~= nil then
			local lCF = torsoCF
				* CFrame.new(-0.54, 0.78, 0.18)
				* CFrame.Angles(math.rad(-24) + math.sin(p) * 0.12, 0, 0)
				* CFrame.new(0, -0.45, 0)
			placeScaled(rigCF, legL.part, legL.size, lCF, sxz, sy)
		end
		if legR ~= nil then
			local rCF = torsoCF
				* CFrame.new(0.54, 0.78, 0.18)
				* CFrame.Angles(math.rad(-24) - math.sin(p) * 0.12, 0, 0)
				* CFrame.new(0, -0.45, 0)
			placeScaled(rigCF, legR.part, legR.size, rCF, sxz, sy)
		end
	else
		local omega = (if unit.kind == "sapper" then 15.2 else 13.5) + atkWeight * 3.5
		local p = now * omega + unit.phase
		local swing = math.sin(p) * walkWeight
		local strideBounce = math.abs(math.sin(p)) * 0.22 * walkWeight
		local forwardLean = -(if unit.kind == "sapper" then 22 else 16) * DEG_TO_RAD * walkWeight
			- (24 * DEG_TO_RAD) * atkWeight
		local yawTwist = math.sin(p) * (9 * DEG_TO_RAD) * walkWeight
		local atkBob = math.abs(math.cos(p)) * 0.14 * atkWeight

		torsoCF = rigCF
			* CFrame.new(0, metrics.torsoMountY + strideBounce + atkBob, 0)
			* CFrame.Angles(forwardLean, yawTwist, math.cos(p) * (4 * DEG_TO_RAD) * walkWeight)

		local legL = unit.limbs.LegL
		local legR = unit.limbs.LegR
		if legL ~= nil then
			local lCF = rigCF
				* CFrame.new(-0.34, metrics.hipY + strideBounce * 0.5, 0)
				* CFrame.Angles(swing * 0.78, 0, 0)
				* CFrame.new(0, -0.74, 0)
			placeScaled(rigCF, legL.part, legL.size, lCF, sxz, sy)
		end
		if legR ~= nil then
			local rCF = rigCF
				* CFrame.new(0.34, metrics.hipY + strideBounce * 0.5, 0)
				* CFrame.Angles(-swing * 0.78, 0, 0)
				* CFrame.new(0, -0.74, 0)
			placeScaled(rigCF, legR.part, legR.size, rCF, sxz, sy)
		end

		local armL = unit.limbs.ArmL
		local armR = unit.limbs.ArmR
		if armL ~= nil then
			local aLPitch = -swing * 0.74 + atkWeight * (0.85 + math.sin(p) * 0.72)
			local aLCF = torsoCF
				* CFrame.new(-0.72, 1.66, -0.05)
				* CFrame.Angles(aLPitch, 0, math.rad(-10))
				* CFrame.new(0, -0.68, 0)
			placeScaled(rigCF, armL.part, armL.size, aLCF, sxz, sy)
		end
		if armR ~= nil then
			local aRPitch = swing * 0.74 + atkWeight * (0.85 - math.sin(p) * 0.72)
			local aRCF = torsoCF
				* CFrame.new(0.72, 1.66, -0.05)
				* CFrame.Angles(aRPitch, 0, math.rad(10))
				* CFrame.new(0, -0.68, 0)
			placeScaled(rigCF, armR.part, armR.size, aRCF, sxz, sy)
		end
	end

	for _, entry in ipairs(unit.torsoParts) do
		placeScaled(rigCF, entry.part, entry.size, torsoCF * entry.localCF, sxz, sy)
	end

	if unit.championCrest ~= nil then
		local crestY = metrics.torsoMountY
			+ metrics.torsoHeight * 0.78
			+ 0.85
			+ math.sin(now * 4.0 + unit.phase) * 0.10
		local crestCF = rigCF
			* CFrame.new(0, crestY, 0)
			* CFrame.Angles(math.rad(8), now * 1.8 + unit.phase, math.rad(90))
		placeScaled(rigCF, unit.championCrest, Vector3.new(0.20, 1.72, 1.72), crestCF, sxz, sy)
	end
end

local function placeBossSlot(
	rootCF: CFrame,
	pieces: { TorsoPiece },
	jointCF: CFrame,
	scale: number
): ()
	for _, entry in ipairs(pieces) do
		placeScaled(rootCF, entry.part, entry.size, jointCF * entry.localCF, scale, scale)
	end
end

local function poseBoss(unit: BossUnit, now: number, state: string?, enraged: boolean?): ()
	local resolvedState = state or "MARCH"
	local isEnraged = enraged == true
	unit.lastState = resolvedState
	unit.lastEnraged = isEnraged
	unit.lastNow = now

	if resolvedState == "DYING" then
		if unit.deathStartAt == nil then
			unit.deathStartAt = now
		end
	else
		unit.deathStartAt = nil
	end

	local approach = math.clamp(unit.approachScale, 0.45, 1.25)
	local hitKnockbackZ = 0
	local hitFlinchPitch = 0
	if now < unit.squashUntil then
		local remaining = math.clamp((unit.squashUntil - now) / BOSS_HIT_KNOCKBACK_DURATION, 0, 1)
		hitKnockbackZ = BOSS_HIT_KNOCKBACK_Z * remaining
		hitFlinchPitch = math.rad(BOSS_HIT_FLINCH_DEG * remaining)
		unit.squashed = true
	elseif unit.squashed then
		unit.squashed = false
	end

	local m = unit.rigMetrics
	local bobY = 0
	local lungeZ = 0
	local jitterX = 0
	local torsoPitch = 0
	local torsoYaw = 0
	local torsoRoll = 0
	local armRPitch = 0.30
	local armRYaw = 0
	local armRRoll = math.rad(6)
	local armLPitch = 0
	local armLYaw = 0
	local armLRoll = math.rad(-6)
	local legLPitch = 0
	local legLYaw = 0
	local legLRoll = 0
	local legRPitch = 0
	local legRYaw = 0
	local legRRoll = 0
	local deathScale = 1.0
	local armROffset = Vector3.zero
	local armLOffset = Vector3.zero
	local legLOffset = Vector3.zero
	local legROffset = Vector3.zero

	if resolvedState == "DYING" then
		local startAt = unit.deathStartAt or now
		local t = math.clamp((now - startAt) / BOSS_DEATH_DURATION, 0, 1)
		unit.stateHighlight.Enabled = false

		if unit.bossId == "rift_titan" then
			armRPitch = 0.30 * (1 - t) - 0.55 * t
			armRRoll = math.rad(6 + 38 * t)
			armLPitch = -0.35 * t
			armLRoll = math.rad(-6 - 30 * t)
			torsoYaw = t * 5.5
			deathScale = math.max(0.08, 1 - t * t * 0.88)
			bobY = -t * 0.15
			legLPitch = 0.22 * t
			legRPitch = -0.22 * t
		elseif unit.bossId == "iron_ram_colossus" then
			bobY = -t * (m.hipY * 0.42)
			legLPitch = 0.72 * t
			legRPitch = 0.72 * t
			torsoPitch = math.rad(-80 * (t * t))
			armRPitch = 0.30 - 0.85 * t
			armLPitch = -0.55 * t
		elseif unit.bossId == "slag_juggernaut" then
			torsoPitch = math.rad(72 * (t * t))
			bobY = -t * (m.hipY * 0.36)
			armROffset = Vector3.new(3.2 * t, 1.4 * math.sin(t * math.pi), 1.8 * t)
			armLOffset = Vector3.new(-3.2 * t, 1.4 * math.sin(t * math.pi), -1.4 * t)
			legLOffset = Vector3.new(-2.0 * t, 0.4 * math.sin(t * math.pi), 1.6 * t)
			legROffset = Vector3.new(2.0 * t, 0.4 * math.sin(t * math.pi), -1.6 * t)
			armRPitch = 0.30 + 2.4 * t
			armLPitch = -2.2 * t
			legLPitch = 0.8 * t
			legRPitch = -0.8 * t
		elseif unit.bossId == "rime_matriarch" then
			bobY = math.sin(t * math.pi) * 0.75 - t * 0.20
			torsoPitch = math.rad(28 * math.sin(t * math.pi * 0.65))
			armRPitch = 0.30 + 1.4 * t
			armLPitch = 1.4 * t
			armRRoll = math.rad(35 * t)
			armLRoll = math.rad(-35 * t)
			armROffset = Vector3.new(1.8 * t, 0.8 * t, 0)
			armLOffset = Vector3.new(-1.8 * t, 0.8 * t, 0)
			local shatterT = math.max(0, t - 0.20) / 0.80
			deathScale = math.max(0.08, 1 - shatterT * shatterT * 0.88)
		else
			torsoYaw = t * 4.4
			bobY = -t * (m.hipY * 0.45)
			torsoPitch = math.rad(-68 * (t * t))
			armRPitch = 0.30 + 1.2 * t
			armRRoll = math.rad(42 * t)
			armLPitch = -0.8 * t
			armLRoll = math.rad(-42 * t)
			legLPitch = 0.65 * t
			legRPitch = -0.55 * t
		end
	elseif resolvedState == "TELEGRAPH" then
		bobY = 0
		jitterX = math.sin(now * 36) * 0.05
		torsoPitch = math.rad(12) + hitFlinchPitch
		torsoYaw = math.rad(-16)
		armRPitch = 1.90
		armRRoll = math.rad(4)
		armLPitch = 0.55
		armLRoll = math.rad(-12)
		legLPitch = 0.14
		legRPitch = -0.14
		unit.stateHighlight.Enabled = true
		unit.stateHighlight.FillColor = rgb(VisualTheme.PALETTE.amberBright)
		unit.stateHighlight.OutlineColor = rgb(VisualTheme.PALETTE.danger)
		unit.stateHighlight.FillTransparency = 0.55 + math.sin(now * 16) * 0.20
		unit.stateHighlight.OutlineTransparency = 0
	elseif resolvedState == "ABILITY" then
		lungeZ = -0.82
		bobY = -0.14
		torsoPitch = math.rad(-15) + hitFlinchPitch
		torsoYaw = math.rad(12)
		torsoRoll = math.rad(-4)
		armRPitch = 0.10
		armLPitch = -0.45
		legLPitch = 0.32
		legRPitch = -0.32
		unit.stateHighlight.Enabled = true
		unit.stateHighlight.FillColor = unit.accent
		unit.stateHighlight.OutlineColor = Color3.new(1, 1, 1)
		unit.stateHighlight.FillTransparency = 0.45
		unit.stateHighlight.OutlineTransparency = 0
	elseif resolvedState == "VULNERABLE" then
		bobY = -0.22
		torsoPitch = math.rad(-20) + hitFlinchPitch
		torsoRoll = math.sin(now * 6) * math.rad(4)
		torsoYaw = math.sin(now * 3.5) * math.rad(5)
		armRPitch = -0.08 + math.sin(now * 4) * 0.04
		armLPitch = -0.08 - math.sin(now * 4) * 0.04
		legLPitch = 0.28
		legRPitch = -0.28
		legLRoll = math.rad(-6)
		legRRoll = math.rad(6)
		unit.stateHighlight.Enabled = true
		unit.stateHighlight.FillColor = rgb(VisualTheme.PALETTE.teal)
		unit.stateHighlight.OutlineColor = Color3.new(1, 1, 1)
		unit.stateHighlight.FillTransparency = 0.50 + math.sin(now * 12) * 0.18
		unit.stateHighlight.OutlineTransparency = 0
	else
		local omega = if isEnraged then 6.2 else 4.2
		local p = now * omega
		local legSwing = math.sin(p) * 0.46
		legLPitch = legSwing
		legRPitch = -legSwing
		bobY = -math.abs(math.cos(p)) * 0.14
		torsoYaw = -math.sin(p) * 0.10
		torsoPitch = math.rad(-5) + hitFlinchPitch
		torsoRoll = math.sin(p) * math.rad(3)
		armLPitch = -legSwing
		armRPitch = 0.30 + math.sin(p) * 0.22
		if isEnraged then
			unit.stateHighlight.Enabled = true
			unit.stateHighlight.FillColor = rgb(VisualTheme.PALETTE.danger)
			unit.stateHighlight.OutlineColor = rgb(VisualTheme.PALETTE.amberBright)
			unit.stateHighlight.FillTransparency = 0.72 + math.sin(now * 10) * 0.12
			unit.stateHighlight.OutlineTransparency = 0.15
		else
			unit.stateHighlight.Enabled = false
		end
	end

	if unit.model:GetAttribute("Hidden") == true then
		unit.stateHighlight.Enabled = false
	end

	local rigCF = CFrame.new(unit.base.Position)
		* unit.base.Rotation
		* CFrame.Angles(0, math.rad(90), 0)
	local rootAnimCF = rigCF * CFrame.new(0, 0, hitKnockbackZ * approach)
	unit.rootPart.CFrame = rootAnimCF

	local uniformScale = approach * deathScale
	local torsoCF = rootAnimCF
		* CFrame.new(jitterX, m.hipY + bobY, lungeZ)
		* CFrame.Angles(torsoPitch, torsoYaw, torsoRoll)

	local minLegLHipY = m.hipY * math.cos(legLPitch) * math.cos(legLRoll)
	local minLegRHipY = m.hipY * math.cos(legRPitch) * math.cos(legRRoll)
	local legLHipY = if resolvedState == "DYING"
		then math.max(m.hipY + bobY, minLegLHipY * 0.5)
		else math.max(minLegLHipY, m.hipY + bobY)
	local legRHipY = if resolvedState == "DYING"
		then math.max(m.hipY + bobY, minLegRHipY * 0.5)
		else math.max(minLegRHipY, m.hipY + bobY)

	local legLCF = rootAnimCF
		* (CFrame.new(-m.hipX + jitterX, legLHipY, lungeZ) + legLOffset)
		* CFrame.Angles(legLPitch, legLYaw, legLRoll)
	local legRCF = rootAnimCF
		* (CFrame.new(m.hipX + jitterX, legRHipY, lungeZ) + legROffset)
		* CFrame.Angles(legRPitch, legRYaw, legRRoll)
	local armLCF = torsoCF
		* (CFrame.new(-m.shoulderX, m.shoulderY, m.shoulderZ) + armLOffset)
		* CFrame.Angles(armLPitch, armLYaw, armLRoll)
	local armRCF = torsoCF
		* (CFrame.new(m.shoulderX, m.shoulderY, m.shoulderZ) + armROffset)
		* CFrame.Angles(armRPitch, armRYaw, armRRoll)

	placeBossSlot(rootAnimCF, unit.slots.torso, torsoCF, uniformScale)
	placeBossSlot(rootAnimCF, unit.slots.legL, legLCF, uniformScale)
	placeBossSlot(rootAnimCF, unit.slots.legR, legRCF, uniformScale)
	placeBossSlot(rootAnimCF, unit.slots.armL, armLCF, uniformScale)
	placeBossSlot(rootAnimCF, unit.slots.armR, armRCF, uniformScale)
end

local function flushPendingHordeMeshes(): ()
	for model, unit in pairs(pendingHordeUnits) do
		if model.Parent == nil then
			pendingHordeUnits[model] = nil
		else
			local meshPieces = tryMountHordeMesh(model, unit.kind)
			if meshPieces ~= nil then
				unit.torsoParts = meshPieces
				pendingHordeUnits[model] = nil
				poseUnit(unit, if unit.lastNow > 0 then unit.lastNow else time(), unit.lastMoving)
			end
		end
	end
	for model, bossUnit in pairs(pendingBossUnits) do
		if model.Parent == nil then
			pendingBossUnits[model] = nil
		else
			local allMounted = tryMountBossFivePartRig(bossUnit)
			if allMounted then
				pendingBossUnits[model] = nil
			end
			poseBoss(
				bossUnit,
				if bossUnit.lastNow > 0 then bossUnit.lastNow else time(),
				bossUnit.lastState,
				bossUnit.lastEnraged
			)
		end
	end
end

local function ensureHordeMeshWatcher(): ()
	local assetsFolder = ReplicatedStorage:FindFirstChild(MeshAssets.FOLDER)
	if assetsFolder ~= nil then
		if assetsFolderConn == nil then
			assetsFolderConn = assetsFolder.ChildAdded:Connect(function()
				flushPendingHordeMeshes()
			end)
		end
		return
	end
	if repAddedConn == nil then
		repAddedConn = ReplicatedStorage.ChildAdded:Connect(function(child: Instance)
			if child.Name == MeshAssets.FOLDER then
				if repAddedConn ~= nil then
					repAddedConn:Disconnect()
					repAddedConn = nil
				end
				ensureHordeMeshWatcher()
				flushPendingHordeMeshes()
			end
		end)
	end
end

function HordeKit.create(
	kind: string,
	parent: Instance,
	cframe: CFrame,
	unitId: number?,
	isChampion: boolean?
): HordeUnit
	local enemies = (VisualTheme.ENEMIES :: any) :: { [string]: EnemySpec }
	local spec = enemies[kind] or enemies.runner
	local flying = spec.flying == true
	local champion = isChampion == true
	local model = Instance.new("Model")
	model.Name = "Horde_" .. kind
	model:SetAttribute("Kind", kind)
	model:SetAttribute("Flying", flying)
	model:SetAttribute("IsChampion", champion)

	local rootPart = makePart(
		model,
		"RootPart",
		Vector3.new(0.1, 0.1, 0.1),
		Vector3.new(0, 0, 0),
		Color3.new(0, 0, 0)
	)
	rootPart.Transparency = 1
	rootPart.CastShadow = false
	model.PrimaryPart = rootPart

	model.Parent = parent
	model:PivotTo(cframe)

	local limbs = createLimbs(model, kind, spec)
	local torsoParts = tryMountHordeMesh(model, kind)
	local hasMesh = torsoParts ~= nil
	if torsoParts == nil then
		local proc = Instance.new("Folder")
		proc.Name = "ProceduralVisual"
		proc.Parent = model
		if kind == "brute" then
			torsoParts = buildBruteFallbackTorso(proc, spec)
		elseif kind == "swarm" then
			torsoParts = buildSwarmFallbackTorso(proc, spec)
		elseif kind == "shieldbearer" then
			torsoParts = buildShieldbearerFallbackTorso(proc, spec)
		elseif kind == "pyromancer" then
			torsoParts = buildPyromancerFallbackTorso(proc, spec)
		elseif kind == "sapper" then
			torsoParts = buildSapperFallbackTorso(proc, spec)
		elseif kind == "wisp" then
			torsoParts = buildWispFallbackTorso(proc, spec)
		elseif kind == "drake" then
			torsoParts = buildDrakeFallbackTorso(proc, spec)
		else
			torsoParts = buildRunnerFallbackTorso(proc, spec)
		end
	end

	local championCrest: BasePart? = if champion then buildChampionCrest(model) else nil

	local phase = if unitId ~= nil
		then ((unitId * GOLDEN_RATIO) % 1) * math.pi * 2
		else (cframe.Position.X + cframe.Position.Z) * 0.1

	local now = time()
	local unit: HordeUnit = {
		model = model,
		rootPart = rootPart,
		base = cframe,
		phase = phase,
		kind = kind,
		flying = flying,
		isChampion = champion,
		approachScale = 1.0,
		squashUntil = 0,
		squashSeq = 0,
		squashed = false,
		lastX = cframe.Position.X,
		lastNow = now,
		lastMoving = false,
		stillTime = 0,
		attackBlend = 0,
		torsoParts = torsoParts :: { TorsoPiece },
		limbs = limbs,
		championCrest = championCrest,
	}

	poseUnit(unit, now, false)

	if not hasMesh then
		pendingHordeUnits[model] = unit
		ensureHordeMeshWatcher()
	end

	return unit
end

function HordeKit.setChampion(unit: HordeUnit, isChampion: boolean): ()
	local champion = isChampion == true
	if unit.isChampion == champion then
		return
	end
	unit.isChampion = champion
	unit.model:SetAttribute("IsChampion", champion)
	local existingCrest = unit.championCrest
	if champion then
		if existingCrest == nil then
			local createdCrest = buildChampionCrest(unit.model)
			unit.championCrest = createdCrest
			local hidden = unit.model:GetAttribute("Hidden") == true
			if hidden then
				createdCrest.Transparency = 1
				local tag = createdCrest:FindFirstChildOfClass("BillboardGui")
				if tag ~= nil then
					tag.Enabled = false
				end
			end
		end
	else
		if existingCrest ~= nil then
			existingCrest:Destroy()
			unit.championCrest = nil
		end
	end
	poseUnit(unit, if unit.lastNow > 0 then unit.lastNow else time(), unit.lastMoving)
end

function HordeKit.setBase(unit: HordeUnit, cframe: CFrame): ()
	unit.base = cframe
end

function HordeKit.setApproachScale(unit: HordeUnit, scale: number): ()
	unit.approachScale = math.clamp(scale, 0.45, 1.25)
end

function HordeKit.hitSquash(unit: HordeUnit): ()
	if unit.model.Parent == nil then
		return
	end
	local now = time()
	unit.squashUntil = now + HIT_SQUASH_DURATION
	unit.squashSeq += 1
	local seq = unit.squashSeq
	unit.squashed = true
	poseUnit(unit, now, unit.lastMoving)

	local existing = unit.model:FindFirstChild("HitFlash")
	if existing ~= nil then
		existing:Destroy()
	end
	local flash = Instance.new("Highlight")
	flash.Name = "HitFlash"
	flash.Adornee = unit.model
	flash.FillColor = Color3.new(1, 1, 1)
	flash.FillTransparency = 0.35
	flash.OutlineTransparency = 1
	flash.Parent = unit.model
	task.delay(VisualTheme.MOTION.hitFlash, function()
		if flash.Parent ~= nil then
			flash:Destroy()
		end
	end)

	task.delay(HIT_SQUASH_DURATION + 0.01, function()
		local parent: Instance? = unit.model.Parent
		if unit.squashSeq == seq and unit.squashed and parent ~= nil then
			unit.squashed = false
			poseUnit(unit, time(), unit.lastMoving)
		end
	end)
end

function HordeKit.step(unit: HordeUnit, now: number, moving: boolean): ()
	if unit.model.Parent == nil then
		return
	end
	poseUnit(unit, now, moving)
end

function HordeKit.setVisible(unit: HordeUnit, visible: boolean): ()
	unit.model:SetAttribute("Hidden", not visible)
	for _, descendant in ipairs(unit.model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if descendant.Name == "RootPart" then
				descendant.Transparency = 1
			else
				descendant.Transparency = if visible then 0 else 1
			end
		elseif descendant:IsA("Trail") then
			if not visible then
				descendant:Clear()
			end
			descendant.Enabled = visible
		elseif descendant:IsA("BillboardGui") then
			descendant.Enabled = visible
		end
	end
end

local function collectSlotPieces(slotFolder: Instance): { TorsoPiece }
	local list: { TorsoPiece } = {}
	registerTorsoChildren(slotFolder, list)
	return list
end

local function buildBossLegsFallback(
	proc: Instance,
	bossId: string,
	spec: BossSpec,
	m: BossRigMetrics
): ({ TorsoPiece }, { TorsoPiece })
	local h = spec.height
	local k = h / 12.0
	local primary = rgb(spec.color)
	local accent = rgb(spec.accent)
	local dark = Color3.fromRGB(28, 32, 38)
	local legH = m.hipY

	local results: { { TorsoPiece } } = {}
	for _, slotName in ipairs({ "Slot_legL", "Slot_legR" }) do
		local folder = Instance.new("Folder")
		folder.Name = slotName
		folder.Parent = proc

		if bossId == "rime_matriarch" then
			local upper = makePart(
				folder,
				"SpireUpper",
				Vector3.new(1.05 * k, legH * 0.62, 1.05 * k),
				Vector3.zero,
				dark,
				Enum.Material.Metal
			)
			upper.CFrame = CFrame.new(0, -legH * 0.31, 0)

			local spire = makePart(
				folder,
				"CryoSpire",
				Vector3.new(0.76 * k, legH * 0.44, 0.88 * k),
				Vector3.zero,
				primary,
				Enum.Material.Ice
			)
			spire.CFrame = CFrame.new(0, -legH + legH * 0.22, -0.08 * k)

			local facet = makeWedge(
				folder,
				"IceFacet",
				Vector3.new(0.62 * k, 0.9 * k, 0.8 * k),
				accent,
				Enum.Material.Neon
			)
			facet.CFrame = CFrame.new(0, -legH * 0.46, -0.58 * k)
		else
			local legW = if bossId == "slag_juggernaut" then 1.55 * k else 1.28 * k
			local greave = makePart(
				folder,
				"Greave",
				Vector3.new(legW, legH * 0.86, legW * 0.96),
				Vector3.zero,
				if bossId == "slag_juggernaut" then rgb(VisualTheme.PALETTE.stoneDark) else dark,
				Enum.Material.Metal
			)
			greave.CFrame = CFrame.new(0, -legH * 0.43, 0)

			local bootH = legH * 0.24
			local boot = makePart(
				folder,
				"Boot",
				Vector3.new(legW * 1.12, bootH, legW * 1.38),
				Vector3.zero,
				if bossId == "powder_baron" then rgb(VisualTheme.PALETTE.woodDark) else dark,
				Enum.Material.Metal
			)
			boot.CFrame = CFrame.new(0, -legH + bootH * 0.5, -0.24 * k)

			local kneeColor = if bossId == "rift_titan"
				then rgb(VisualTheme.PALETTE.teal)
				elseif bossId == "powder_baron" then accent
				else primary
			local kneeMat = if bossId == "rift_titan"
				then Enum.Material.Neon
				else Enum.Material.Metal
			local knee = makePart(
				folder,
				"Knee",
				Vector3.new(legW * 0.72, 0.68 * k, 0.52 * k),
				Vector3.zero,
				kneeColor,
				kneeMat
			)
			knee.CFrame = CFrame.new(0, -legH * 0.46, -legW * 0.54)
		end

		results[#results + 1] = collectSlotPieces(folder)
	end

	return results[1], results[2]
end

local function buildBossFallbackRig(
	proc: Instance,
	bossId: string,
	spec: BossSpec,
	m: BossRigMetrics
): BossSlots
	local h = spec.height
	local k = h / 12.0
	local tH = m.torsoHeight
	local primary = rgb(spec.color)
	local accent = rgb(spec.accent)
	local dark = Color3.fromRGB(28, 32, 38)
	local steel = Color3.fromRGB(130, 140, 152)
	local gold = rgb(VisualTheme.PALETTE.amberBright)

	local torsoFolder = Instance.new("Folder")
	torsoFolder.Name = "Slot_torso"
	torsoFolder.Parent = proc

	local armLFolder = Instance.new("Folder")
	armLFolder.Name = "Slot_armL"
	armLFolder.Parent = proc

	local armRFolder = Instance.new("Folder")
	armRFolder.Name = "Slot_armR"
	armRFolder.Parent = proc

	local legLPieces, legRPieces = buildBossLegsFallback(proc, bossId, spec, m)

	if bossId == "slag_juggernaut" then
		local chest = makePart(
			torsoFolder,
			"CauldronTorso",
			Vector3.new(5.2 * k, tH * 0.62, 3.8 * k),
			Vector3.zero,
			dark,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		chest.CFrame = CFrame.new(0, tH * 0.34, 0) * CFrame.Angles(0, 0, math.rad(90))

		local magma = makePart(
			torsoFolder,
			"MagmaCore",
			Vector3.new(2.2 * k, 2.2 * k, 1.3 * k),
			Vector3.zero,
			accent,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		magma.CFrame = CFrame.new(0, tH * 0.38, -1.75 * k)

		for _, sx in ipairs({ -1, 1 }) do
			local stack = makePart(
				torsoFolder,
				if sx < 0 then "StackL" else "StackR",
				Vector3.new(1.0 * k, 2.6 * k, 1.0 * k),
				Vector3.zero,
				rgb(VisualTheme.PALETTE.stoneDark),
				Enum.Material.Slate
			)
			stack.CFrame = CFrame.new(sx * 1.6 * k, tH * 0.72, 1.45 * k)
				* CFrame.Angles(math.rad(16), 0, math.rad(-sx * 8))

			local ember = makePart(
				torsoFolder,
				if sx < 0 then "StackEmberL" else "StackEmberR",
				Vector3.new(0.85 * k, 0.85 * k, 0.85 * k),
				Vector3.zero,
				gold,
				Enum.Material.Neon,
				Enum.PartType.Ball
			)
			ember.CFrame = CFrame.new(sx * 1.78 * k, tH * 0.92, 1.80 * k)
		end

		local head = makeEllipsoid(
			torsoFolder,
			"Helm",
			Vector3.new(2.3 * k, 1.9 * k, 2.2 * k),
			dark,
			Enum.Material.Metal
		)
		head.CFrame = CFrame.new(0, tH * 0.78, -0.5 * k)
		local crest = makePart(
			torsoFolder,
			"MagmaCrest",
			Vector3.new(0.6 * k, 1.1 * k, 1.6 * k),
			Vector3.zero,
			accent,
			Enum.Material.Neon
		)
		crest.CFrame = CFrame.new(0, tH * 0.93, -0.3 * k)

		-- Left arm: heavy foundry gauntlet
		local lArm = makePart(
			armLFolder,
			"ArmL",
			Vector3.new(1.25 * k, 3.0 * k, 1.25 * k),
			Vector3.zero,
			dark,
			Enum.Material.Metal
		)
		lArm.CFrame = CFrame.new(0, -1.4 * k, -0.2 * k)
		local lFist = makePart(
			armLFolder,
			"SlagFist",
			Vector3.new(1.65 * k, 1.45 * k, 1.65 * k),
			Vector3.zero,
			accent,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		lFist.CFrame = CFrame.new(0, -2.95 * k, -0.55 * k)

		-- Right arm: molten slag warhammer
		local rArm = makePart(
			armRFolder,
			"ArmR",
			Vector3.new(1.25 * k, 2.8 * k, 1.25 * k),
			Vector3.zero,
			dark,
			Enum.Material.Metal
		)
		rArm.CFrame = CFrame.new(0, -1.3 * k, -0.25 * k)
		local shaft = makePart(
			armRFolder,
			"HammerShaft",
			Vector3.new(0.36 * k, 0.36 * k, 4.2 * k),
			Vector3.zero,
			steel,
			Enum.Material.Metal
		)
		shaft.CFrame = CFrame.new(0, -2.6 * k, -1.8 * k) * CFrame.Angles(math.rad(-20), 0, 0)
		local headHammer = makePart(
			armRFolder,
			"HammerHead",
			Vector3.new(2.2 * k, 1.55 * k, 1.45 * k),
			Vector3.zero,
			accent,
			Enum.Material.Neon
		)
		headHammer.CFrame = CFrame.new(0, -2.0 * k, -3.55 * k) * CFrame.Angles(math.rad(-20), 0, 0)
	elseif bossId == "rime_matriarch" then
		local bodice = makeEllipsoid(
			torsoFolder,
			"Bodice",
			Vector3.new(3.8 * k, tH * 0.62, 2.6 * k),
			dark,
			Enum.Material.Metal
		)
		bodice.CFrame = CFrame.new(0, tH * 0.36, 0)

		local cryoCore = makePart(
			torsoFolder,
			"CryoCore",
			Vector3.new(1.25 * k, 1.85 * k, 0.9 * k),
			Vector3.zero,
			accent,
			Enum.Material.Neon
		)
		cryoCore.CFrame = CFrame.new(0, tH * 0.44, -1.25 * k) * CFrame.Angles(math.rad(12), 0, 0)

		for _, sx in ipairs({ -1, 1 }) do
			local mantle = makeWedge(
				torsoFolder,
				if sx < 0 then "MantleL" else "MantleR",
				Vector3.new(1.3 * k, 2.6 * k, 1.4 * k),
				primary,
				Enum.Material.Ice
			)
			mantle.CFrame = CFrame.new(sx * 2.1 * k, tH * 0.64, 0.25 * k)
				* CFrame.Angles(math.rad(-14), 0, math.rad(-sx * 22))
		end

		local head = makePart(
			torsoFolder,
			"Helm",
			Vector3.new(1.9 * k, 2.1 * k, 1.9 * k),
			Vector3.zero,
			dark,
			Enum.Material.Metal,
			Enum.PartType.Ball
		)
		head.CFrame = CFrame.new(0, tH * 0.78, -0.15 * k)
		local crown = makePart(
			torsoFolder,
			"IceCrown",
			Vector3.new(2.2 * k, 1.35 * k, 0.55 * k),
			Vector3.zero,
			accent,
			Enum.Material.Neon
		)
		crown.CFrame = CFrame.new(0, tH * 0.94, -0.2 * k)

		-- Left arm: razor ice claw
		local lArm = makePart(
			armLFolder,
			"ArmL",
			Vector3.new(0.85 * k, 2.8 * k, 0.85 * k),
			Vector3.zero,
			dark,
			Enum.Material.Metal
		)
		lArm.CFrame = CFrame.new(0, -1.3 * k, -0.25 * k)
		local lClaw = makeWedge(
			armLFolder,
			"IceClaw",
			Vector3.new(0.45 * k, 1.65 * k, 0.9 * k),
			accent,
			Enum.Material.Neon
		)
		lClaw.CFrame = CFrame.new(0, -2.9 * k, -0.95 * k) * CFrame.Angles(math.rad(-55), 0, 0)

		-- Right arm: cryo crystal scepter
		local rArm = makePart(
			armRFolder,
			"ArmR",
			Vector3.new(0.85 * k, 2.6 * k, 0.85 * k),
			Vector3.zero,
			dark,
			Enum.Material.Metal
		)
		rArm.CFrame = CFrame.new(0, -1.2 * k, -0.25 * k)
		local staff = makePart(
			armRFolder,
			"ScepterShaft",
			Vector3.new(0.32 * k, 0.32 * k, 4.4 * k),
			Vector3.zero,
			steel,
			Enum.Material.Metal
		)
		staff.CFrame = CFrame.new(0, -2.4 * k, -1.75 * k) * CFrame.Angles(math.rad(-25), 0, 0)
		local crystal = makePart(
			armRFolder,
			"ScepterCrystal",
			Vector3.new(1.05 * k, 1.45 * k, 1.05 * k),
			Vector3.zero,
			accent,
			Enum.Material.Neon
		)
		crystal.CFrame = CFrame.new(0, -1.65 * k, -3.75 * k)
			* CFrame.Angles(math.rad(-25), math.rad(45), 0)
	elseif bossId == "powder_baron" then
		local coat = makePart(
			torsoFolder,
			"SiegeCoat",
			Vector3.new(4.4 * k, tH * 0.62, 3.0 * k),
			Vector3.zero,
			primary,
			Enum.Material.SmoothPlastic
		)
		coat.CFrame = CFrame.new(0, tH * 0.34, 0)

		local buckle = makePart(
			torsoFolder,
			"GoldBuckle",
			Vector3.new(1.3 * k, 0.9 * k, 0.5 * k),
			Vector3.zero,
			gold,
			Enum.Material.Neon
		)
		buckle.CFrame = CFrame.new(0, tH * 0.32, -1.45 * k)

		for _, sx in ipairs({ -1, 1 }) do
			local mortar = makePart(
				torsoFolder,
				if sx < 0 then "MortarL" else "MortarR",
				Vector3.new(1.25 * k, 2.5 * k, 1.25 * k),
				Vector3.zero,
				dark,
				Enum.Material.Metal
			)
			mortar.CFrame = CFrame.new(sx * 2.1 * k, tH * 0.72, -0.35 * k)
				* CFrame.Angles(math.rad(32), 0, 0)

			local ring = makePart(
				torsoFolder,
				if sx < 0 then "MortarRimL" else "MortarRimR",
				Vector3.new(1.42 * k, 0.38 * k, 1.42 * k),
				Vector3.zero,
				gold,
				Enum.Material.Metal
			)
			ring.CFrame = CFrame.new(sx * 2.1 * k, tH * 0.84, -0.95 * k)
				* CFrame.Angles(math.rad(32), 0, 0)
		end

		local head = makePart(
			torsoFolder,
			"Head",
			Vector3.new(1.9 * k, 1.9 * k, 1.9 * k),
			Vector3.zero,
			dark,
			Enum.Material.Metal,
			Enum.PartType.Ball
		)
		head.CFrame = CFrame.new(0, tH * 0.76, -0.1 * k)
		local brim = makePart(
			torsoFolder,
			"TricorneBrim",
			Vector3.new(3.4 * k, 0.36 * k, 3.0 * k),
			Vector3.zero,
			dark,
			Enum.Material.Fabric
		)
		brim.CFrame = CFrame.new(0, tH * 0.88, -0.1 * k)
		local hatCrown = makePart(
			torsoFolder,
			"TricorneCrown",
			Vector3.new(2.0 * k, 0.95 * k, 1.8 * k),
			Vector3.zero,
			accent,
			Enum.Material.Metal
		)
		hatCrown.CFrame = CFrame.new(0, tH * 0.94, -0.1 * k)

		-- Left arm: gauntlet + powder brace
		local lArm = makePart(
			armLFolder,
			"ArmL",
			Vector3.new(1.0 * k, 2.8 * k, 1.0 * k),
			Vector3.zero,
			dark,
			Enum.Material.Metal
		)
		lArm.CFrame = CFrame.new(0, -1.3 * k, -0.2 * k)
		local lCuff = makePart(
			armLFolder,
			"BronzeCuff",
			Vector3.new(1.25 * k, 1.0 * k, 1.25 * k),
			Vector3.zero,
			primary,
			Enum.Material.Metal
		)
		lCuff.CFrame = CFrame.new(0, -2.6 * k, -0.45 * k)

		-- Right arm: brass bombard arm cannon
		local rArm = makePart(
			armRFolder,
			"ArmR",
			Vector3.new(1.05 * k, 2.5 * k, 1.05 * k),
			Vector3.zero,
			dark,
			Enum.Material.Metal
		)
		rArm.CFrame = CFrame.new(0, -1.15 * k, -0.2 * k)
		local cannon = makePart(
			armRFolder,
			"BombardBarrel",
			Vector3.new(1.25 * k, 1.25 * k, 3.2 * k),
			Vector3.zero,
			primary,
			Enum.Material.Metal
		)
		cannon.CFrame = CFrame.new(0, -2.35 * k, -1.65 * k) * CFrame.Angles(math.rad(-12), 0, 0)
		local muzzle = makePart(
			armRFolder,
			"BombardMuzzle",
			Vector3.new(1.45 * k, 1.45 * k, 0.45 * k),
			Vector3.zero,
			gold,
			Enum.Material.Neon
		)
		muzzle.CFrame = CFrame.new(0, -2.02 * k, -3.15 * k) * CFrame.Angles(math.rad(-12), 0, 0)
	elseif bossId == "rift_titan" then
		local chest = makeEllipsoid(
			torsoFolder,
			"SovereignChest",
			Vector3.new(4.8 * k, tH * 0.56, 3.2 * k),
			steel,
			Enum.Material.Metal
		)
		chest.CFrame = CFrame.new(0, tH * 0.36, -0.1 * k)

		local heart = makePart(
			torsoFolder,
			"RiftHeart",
			Vector3.new(1.55 * k, 1.85 * k, 0.9 * k),
			Vector3.zero,
			primary,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		heart.CFrame = CFrame.new(0, tH * 0.40, -1.45 * k)

		local cape = makePart(
			torsoFolder,
			"SovereignCape",
			Vector3.new(4.2 * k, tH * 0.72, 0.32 * k),
			Vector3.zero,
			rgb(VisualTheme.PALETTE.tealDark),
			Enum.Material.Fabric
		)
		cape.CFrame = CFrame.new(0, tH * 0.32, 1.55 * k) * CFrame.Angles(math.rad(14), 0, 0)

		for _, sx in ipairs({ -1, 1 }) do
			local pauldron = makePart(
				torsoFolder,
				if sx < 0 then "PauldronL" else "PauldronR",
				Vector3.new(1.85 * k, 1.45 * k, 2.05 * k),
				Vector3.zero,
				dark,
				Enum.Material.Metal
			)
			pauldron.CFrame = CFrame.new(sx * 2.55 * k, tH * 0.54, 0)
				* CFrame.Angles(0, 0, math.rad(-sx * 16))
			local spike = makeWedge(
				torsoFolder,
				if sx < 0 then "PauldronSpikeL" else "PauldronSpikeR",
				Vector3.new(0.6 * k, 1.5 * k, 0.9 * k),
				primary,
				Enum.Material.Neon
			)
			spike.CFrame = CFrame.new(sx * 2.95 * k, tH * 0.68, 0.1 * k)
				* CFrame.Angles(math.rad(-12), 0, math.rad(-sx * 24))
		end

		local helm = makeEllipsoid(
			torsoFolder,
			"SovereignHelm",
			Vector3.new(1.95 * k, 2.15 * k, 2.05 * k),
			dark,
			Enum.Material.Metal
		)
		helm.CFrame = CFrame.new(0, tH * 0.78, -0.15 * k)
		local visor = makePart(
			torsoFolder,
			"RiftVisor",
			Vector3.new(1.25 * k, 0.35 * k, 0.45 * k),
			Vector3.zero,
			accent,
			Enum.Material.Neon
		)
		visor.CFrame = CFrame.new(0, tH * 0.79, -1.05 * k)
		for _, sx in ipairs({ -1, 1 }) do
			local horn = makeWedge(
				torsoFolder,
				if sx < 0 then "HelmHornL" else "HelmHornR",
				Vector3.new(0.45 * k, 1.85 * k, 0.65 * k),
				primary,
				Enum.Material.Neon
			)
			horn.CFrame = CFrame.new(sx * 1.1 * k, tH * 0.92, -0.2 * k)
				* CFrame.Angles(math.rad(10), 0, math.rad(-sx * 20))
		end

		-- Left arm: armored arm + wrist Rift claw blade
		local lArm = makePart(
			armLFolder,
			"ArmL",
			Vector3.new(1.0 * k, 2.9 * k, 1.0 * k),
			Vector3.zero,
			dark,
			Enum.Material.Metal
		)
		lArm.CFrame = CFrame.new(0, -1.35 * k, -0.25 * k)
		local lClaw = makeWedge(
			armLFolder,
			"RiftClaw",
			Vector3.new(0.4 * k, 1.8 * k, 0.85 * k),
			primary,
			Enum.Material.Neon
		)
		lClaw.CFrame = CFrame.new(0, -2.9 * k, -0.95 * k) * CFrame.Angles(math.rad(-55), 0, 0)

		-- Right arm: armored arm + colossal Rift Obelisk Greatsword poised forward-downward (~35 deg ready angle, NEVER touching ground)
		local rArm = makePart(
			armRFolder,
			"ArmR",
			Vector3.new(1.05 * k, 2.75 * k, 1.05 * k),
			Vector3.zero,
			dark,
			Enum.Material.Metal
		)
		rArm.CFrame = CFrame.new(0, -1.25 * k, -0.25 * k) * CFrame.Angles(math.rad(14), 0, 0)

		local swordTilt = math.rad(-55) -- points forward (-Z) and slightly down (-Y), ~35 deg below horizontal
		local hilt = makePart(
			armRFolder,
			"ObeliskHilt",
			Vector3.new(0.32 * k, 1.15 * k, 0.32 * k),
			Vector3.zero,
			gold,
			Enum.Material.Metal
		)
		hilt.CFrame = CFrame.new(0, -2.5 * k, -0.65 * k) * CFrame.Angles(swordTilt, 0, 0)

		local guard = makePart(
			armRFolder,
			"ObeliskGuard",
			Vector3.new(1.45 * k, 0.36 * k, 0.55 * k),
			Vector3.zero,
			gold,
			Enum.Material.Metal
		)
		guard.CFrame = CFrame.new(0, -2.75 * k, -1.05 * k) * CFrame.Angles(swordTilt, 0, 0)

		local blade = makePart(
			armRFolder,
			"ObeliskBlade",
			Vector3.new(0.88 * k, 4.4 * k, 0.28 * k),
			Vector3.zero,
			dark,
			Enum.Material.Metal
		)
		blade.CFrame = CFrame.new(0, -3.72 * k, -2.50 * k) * CFrame.Angles(swordTilt, 0, 0)

		local bladeCore = makePart(
			armRFolder,
			"ObeliskCore",
			Vector3.new(0.34 * k, 4.15 * k, 0.36 * k),
			Vector3.zero,
			primary,
			Enum.Material.Neon
		)
		bladeCore.CFrame = CFrame.new(0, -3.72 * k, -2.50 * k) * CFrame.Angles(swordTilt, 0, 0)
	else
		-- iron_ram_colossus (default)
		local chest = makeEllipsoid(
			torsoFolder,
			"IronChest",
			Vector3.new(5.0 * k, tH * 0.58, 3.4 * k),
			primary,
			Enum.Material.Metal
		)
		chest.CFrame = CFrame.new(0, tH * 0.36, 0)

		local furnace = makePart(
			torsoFolder,
			"FurnaceCore",
			Vector3.new(1.65 * k, 1.85 * k, 0.9 * k),
			Vector3.zero,
			accent,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		furnace.CFrame = CFrame.new(0, tH * 0.38, -1.55 * k)

		for _, sx in ipairs({ -1, 1 }) do
			local pauldron = makePart(
				torsoFolder,
				if sx < 0 then "PauldronL" else "PauldronR",
				Vector3.new(1.9 * k, 1.65 * k, 1.9 * k),
				Vector3.zero,
				primary,
				Enum.Material.Metal,
				Enum.PartType.Ball
			)
			pauldron.CFrame = CFrame.new(sx * 2.55 * k, tH * 0.56, 0)
			local horn = makeWedge(
				torsoFolder,
				if sx < 0 then "PauldronHornL" else "PauldronHornR",
				Vector3.new(0.55 * k, 1.45 * k, 0.75 * k),
				steel,
				Enum.Material.Metal
			)
			horn.CFrame = CFrame.new(sx * 2.85 * k, tH * 0.72, -0.1 * k)
				* CFrame.Angles(math.rad(15), 0, math.rad(-sx * 25))
		end

		local helm = makePart(
			torsoFolder,
			"SiegeHelm",
			Vector3.new(2.1 * k, 2.0 * k, 2.1 * k),
			Vector3.zero,
			dark,
			Enum.Material.Metal,
			Enum.PartType.Ball
		)
		helm.CFrame = CFrame.new(0, tH * 0.78, -0.2 * k)
		local visor = makeEllipsoid(
			torsoFolder,
			"SiegeVisor",
			Vector3.new(1.45 * k, 0.42 * k, 0.55 * k),
			accent,
			Enum.Material.Neon
		)
		visor.CFrame = CFrame.new(0, tH * 0.79, -1.15 * k)
		for _, sx in ipairs({ -1, 1 }) do
			local horn = makeWedge(
				torsoFolder,
				if sx < 0 then "HelmHornL" else "HelmHornR",
				Vector3.new(0.45 * k, 1.55 * k, 0.65 * k),
				steel,
				Enum.Material.Metal
			)
			horn.CFrame = CFrame.new(sx * 0.95 * k, tH * 0.91, -0.35 * k)
				* CFrame.Angles(math.rad(28), 0, math.rad(-sx * 22))
		end

		-- Left arm: iron gauntlet
		local lArm = makePart(
			armLFolder,
			"ArmL",
			Vector3.new(1.1 * k, 2.8 * k, 1.1 * k),
			Vector3.zero,
			dark,
			Enum.Material.Metal
		)
		lArm.CFrame = CFrame.new(0, -1.3 * k, -0.25 * k)
		local lShield = makePart(
			armLFolder,
			"RamShield",
			Vector3.new(0.75 * k, 1.9 * k, 1.65 * k),
			Vector3.zero,
			primary,
			Enum.Material.Metal
		)
		lShield.CFrame = CFrame.new(-0.35 * k, -2.65 * k, -0.75 * k)

		-- Right arm: iron battering-ram gauntlet
		local rArm = makePart(
			armRFolder,
			"ArmR",
			Vector3.new(1.1 * k, 2.6 * k, 1.1 * k),
			Vector3.zero,
			dark,
			Enum.Material.Metal
		)
		rArm.CFrame = CFrame.new(0, -1.2 * k, -0.25 * k)
		local ramHead = makePart(
			armRFolder,
			"BatteringRam",
			Vector3.new(1.55 * k, 1.45 * k, 2.45 * k),
			Vector3.zero,
			primary,
			Enum.Material.Metal
		)
		ramHead.CFrame = CFrame.new(0, -2.5 * k, -1.35 * k)
		local ramSpike = makeWedge(
			armRFolder,
			"RamSpike",
			Vector3.new(0.9 * k, 1.2 * k, 1.4 * k),
			accent,
			Enum.Material.Neon
		)
		ramSpike.CFrame = CFrame.new(0, -2.45 * k, -2.75 * k) * CFrame.Angles(math.rad(-90), 0, 0)
	end

	return {
		torso = collectSlotPieces(torsoFolder),
		armR = collectSlotPieces(armRFolder),
		armL = collectSlotPieces(armLFolder),
		legL = legLPieces,
		legR = legRPieces,
	}
end

function HordeKit.createBoss(bossId: string, parent: Instance, cframe: CFrame): BossUnit
	local bosses = VisualTheme.BOSSES :: { [string]: BossSpec }
	local spec = bosses[bossId] or bosses.iron_ram_colossus
	local model = Instance.new("Model")
	model.Name = "Boss_" .. bossId
	model:SetAttribute("BossId", bossId)

	local rootPart = makePart(
		model,
		"RootPart",
		Vector3.new(0.2, 0.2, 0.2),
		Vector3.new(0, 0, 0),
		Color3.new(0, 0, 0)
	)
	rootPart.Transparency = 1
	rootPart.CastShadow = false
	model.PrimaryPart = rootPart

	model.Parent = parent
	model:PivotTo(cframe)

	local stateHighlight = Instance.new("Highlight")
	stateHighlight.Name = "StateHighlight"
	stateHighlight.Adornee = model
	stateHighlight.Enabled = false
	stateHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
	stateHighlight.Parent = model

	local rigMetrics = computeBossRigMetrics(bossId, spec.height)
	local proc = Instance.new("Folder")
	proc.Name = "ProceduralVisual"
	proc.Parent = model
	local slots = buildBossFallbackRig(proc, bossId, spec, rigMetrics)

	local now = time()
	local bossUnit: BossUnit = {
		model = model,
		rootPart = rootPart,
		base = cframe,
		bossId = bossId,
		height = spec.height,
		approachScale = 1.0,
		color = rgb(spec.color),
		accent = rgb(spec.accent),
		squashUntil = 0,
		squashSeq = 0,
		squashed = false,
		lastState = "MARCH",
		lastEnraged = false,
		lastNow = now,
		deathStartAt = nil,
		rigMetrics = rigMetrics,
		slots = slots,
		mountedSlots = {
			torso = false,
			armR = false,
			armL = false,
			legL = false,
			legR = false,
		},
		torsoMeshScale = nil,
		stateHighlight = stateHighlight,
	}

	local allMounted = tryMountBossFivePartRig(bossUnit)
	poseBoss(bossUnit, now, "MARCH", false)

	if not allMounted then
		pendingBossUnits[model] = bossUnit
		ensureHordeMeshWatcher()
	end

	return bossUnit
end

function HordeKit.setBossBase(bossUnit: BossUnit, cframe: CFrame): ()
	bossUnit.base = cframe
end

function HordeKit.setBossApproachScale(bossUnit: BossUnit, scale: number): ()
	bossUnit.approachScale = math.clamp(scale, 0.45, 1.25)
end

function HordeKit.stepBoss(bossUnit: BossUnit, now: number, state: string?, enraged: boolean?): ()
	if bossUnit.model.Parent == nil then
		return
	end
	poseBoss(bossUnit, now, state, enraged)
end

function HordeKit.hitSquashBoss(bossUnit: BossUnit): ()
	if bossUnit.model.Parent == nil then
		return
	end
	local now = time()
	bossUnit.squashUntil = now + BOSS_HIT_KNOCKBACK_DURATION
	bossUnit.squashSeq += 1
	local seq = bossUnit.squashSeq
	bossUnit.squashed = true
	poseBoss(bossUnit, now, bossUnit.lastState, bossUnit.lastEnraged)

	local existing = bossUnit.model:FindFirstChild("HitFlash")
	if existing ~= nil then
		existing:Destroy()
	end
	local flash = Instance.new("Highlight")
	flash.Name = "HitFlash"
	flash.Adornee = bossUnit.model
	flash.FillColor = Color3.new(1, 1, 1)
	flash.FillTransparency = 0.3
	flash.OutlineTransparency = 1
	flash.Parent = bossUnit.model
	task.delay(VisualTheme.MOTION.hitFlash, function()
		if flash.Parent ~= nil then
			flash:Destroy()
		end
	end)

	task.delay(BOSS_HIT_KNOCKBACK_DURATION + 0.01, function()
		local parent: Instance? = bossUnit.model.Parent
		if bossUnit.squashSeq == seq and bossUnit.squashed and parent ~= nil then
			bossUnit.squashed = false
			poseBoss(bossUnit, time(), bossUnit.lastState, bossUnit.lastEnraged)
		end
	end)
end

function HordeKit.setBossVisible(bossUnit: BossUnit, visible: boolean): ()
	bossUnit.model:SetAttribute("Hidden", not visible)
	if not visible then
		bossUnit.stateHighlight.Enabled = false
	end
	for _, descendant in ipairs(bossUnit.model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			if descendant.Name == "RootPart" then
				descendant.Transparency = 1
			else
				descendant.Transparency = if visible then 0 else 1
			end
		end
	end
end

return HordeKit
