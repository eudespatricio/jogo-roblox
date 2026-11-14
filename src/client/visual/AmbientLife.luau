--!strict
-- Ambient Sky & Ground Fauna Animator: 16 animated creatures (2 wyverns, 8 birds in 2 flocks,
-- 2 pack oxen, 2 woodland stags, 2 mountain rams) patrolling valley/sky coordinates around `origin`.
-- Purely visual/cosmetic: non-yielding build, inert parts, sculpted fallbacks with seamless async
-- Open Cloud mesh swap via ReplicatedStorage.MuralhaAssets (`FAUNA_*`).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VisualTheme = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("visual"):WaitForChild("VisualTheme")
)

local AmbientLife = {}

-- TODO(Torcida): implementar futuramente arquibancada/torcida ao redor do perimetro da arena
-- com personagens do jogo (arqueiros, engenheiros e aldeoes do bastiao) reagindo em tempo real
-- a abates da horda, combos de sinergia, dano na muralha e vitoria/derrota.
-- Requisitos quando entrar: puramente client-side, CanCollide/CanQuery/CanTouch = false,
-- animacao em lote no Heartbeat e dentro do orcamento mobile de partes (VisualTheme.BUDGET).

local FOLDER_NAME = "AmbientLife"
local ASSETS_FOLDER = "MuralhaAssets"
local FAUNA_PREFIX = "FAUNA_"
local LATE_WAIT_S = 90
local DEFAULT_GROUND_Y = -0.20

local ROT_GLTF_TO_LOCAL = CFrame.Angles(0, math.rad(180), 0)

type Piece = {
	part: BasePart,
	localCF: CFrame,
}

type PieceSpec = {
	name: string,
	kind: "Ball" | "Cylinder" | "Wedge",
	size: Vector3,
	cf: CFrame,
	color: Color3,
	mat: Enum.Material?,
}

type BodySlot = {
	model: Model,
	pieces: { Piece },
	shoulderOffsetX: number,
	shoulderY: number,
	shoulderZ: number,
	meshAsset: string,
	hasMesh: boolean,
}

type WingSlot = {
	model: Model,
	pieces: { Piece },
	dir: number,
	meshAsset: string,
	hasMesh: boolean,
}

type FlyingCreature = {
	kind: "wyvern" | "bird",
	variant: "drake" | "rift" | "raven" | "falcon",
	root: Model,
	body: BodySlot,
	wingL: WingSlot,
	wingR: WingSlot,
	wingspan: number,
	targetHeight: number,
	pathMode: "ellipse" | "figure8",
	center: Vector3,
	rx: number,
	rz: number,
	yAmp: number,
	yFreq: number,
	orbitSpeed: number,
	phase: number,
	flapHz: number,
	flapBurstSec: number,
	glideSec: number,
	flapAmpRad: number,
	dihedralRad: number,
	bankGain: number,
	maxBankRad: number,
	prevForward: Vector3?,
	smoothBank: number,
}

type GroundCreature = {
	kind: "pack_ox" | "stag" | "ram",
	root: Model,
	visual: Model,
	pieces: { Piece },
	meshAsset: string,
	hasMesh: boolean,
	targetHeight: number,
	lightPart: BasePart?,
	lightLocalOffset: Vector3,
	motionMode: "road" | "loop",
	waypoints: { Vector2 }?,
	segLengths: { number }?,
	totalLength: number,
	roadLateralOffset: number,
	roadProgress: number,
	roadDir: number,
	loopCenter: Vector2?,
	loopRx: number,
	loopRz: number,
	loopSpeed: number,
	speed: number,
	phase: number,
	bobHz: number,
	bobAmp: number,
	swayAmp: number,
	walkSec: number,
	pauseSec: number,
	hopMode: boolean,
	smoothForward: Vector3?,
	smoothPitch: number,
}

local function rgb(values: { number }): Color3
	return Color3.fromRGB(values[1], values[2], values[3])
end

local COLOR_AMBER = rgb(VisualTheme.PALETTE.amber)
local COLOR_AMBER_BRIGHT = rgb(VisualTheme.PALETTE.amberBright)
local COLOR_WOOD = rgb(VisualTheme.PALETTE.wood)
local COLOR_WOOD_DARK = rgb(VisualTheme.PALETTE.woodDark)
local COLOR_IRON = rgb(VisualTheme.PALETTE.iron)
local COLOR_IRON_DARK = rgb(VisualTheme.PALETTE.ironDark)
local COLOR_STONE = rgb(VisualTheme.PALETTE.stone)
local COLOR_STONE_DARK = rgb(VisualTheme.PALETTE.stoneDark)
local COLOR_TEAL = rgb(VisualTheme.PALETTE.teal)
local COLOR_TEAL_DARK = rgb(VisualTheme.PALETTE.tealDark)
local COLOR_TEAL_BRIGHT = Color3.fromRGB(45, 212, 191)
local COLOR_PARCHMENT = rgb(VisualTheme.PALETTE.parchment)
local COLOR_TAWNY = Color3.fromRGB(164, 112, 68)
local COLOR_WOOL = Color3.fromRGB(218, 210, 194)
local COLOR_OX_LIGHT = Color3.fromRGB(255, 188, 82)

local function inert(part: BasePart): ()
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
end

local function buildPieces(parent: Instance, specs: { PieceSpec }): { Piece }
	local pieces: { Piece } = {}
	for _, spec in ipairs(specs) do
		local base: BasePart
		if spec.kind == "Wedge" then
			base = Instance.new("WedgePart")
		else
			local part = Instance.new("Part")
			part.Shape = if spec.kind == "Ball" then Enum.PartType.Ball else Enum.PartType.Cylinder
			base = part
		end
		base.Name = spec.name
		base.Size = spec.size
		base.CFrame = spec.cf
		base.Color = spec.color
		base.Material = spec.mat or Enum.Material.SmoothPlastic
		base.TopSurface = Enum.SurfaceType.Smooth
		base.BottomSurface = Enum.SurfaceType.Smooth
		inert(base)
		base.Parent = parent
		pieces[#pieces + 1] = { part = base, localCF = spec.cf }
	end
	return pieces
end

local function buildWingFallback(
	parent: Instance,
	name: string,
	dir: number,
	span: number,
	chord: number,
	thickness: number,
	primary: Color3,
	accent: Color3,
	meshAsset: string
): WingSlot
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent

	local innerSpan = span * 0.56
	local outerSpan = span * 0.48
	local wedgeOrient = if dir > 0
		then CFrame.Angles(0, math.rad(-90), 0) * CFrame.Angles(0, 0, math.rad(90))
		else CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(0, 0, math.rad(-90))

	local specs: { PieceSpec } = {
		{
			name = "SparInner",
			kind = "Cylinder",
			size = Vector3.new(innerSpan, thickness * 1.4, thickness * 1.4),
			cf = CFrame.new(dir * innerSpan * 0.5, 0, -chord * 0.28)
				* CFrame.Angles(0, dir * math.rad(-10), 0),
			color = accent,
		},
		{
			name = "SparOuter",
			kind = "Cylinder",
			size = Vector3.new(outerSpan, thickness, thickness),
			cf = CFrame.new(dir * (innerSpan + outerSpan * 0.45), 0, chord * 0.02)
				* CFrame.Angles(0, dir * math.rad(-22), 0),
			color = accent,
		},
		{
			name = "MembraneInner",
			kind = "Wedge",
			size = Vector3.new(thickness * 0.75, chord, innerSpan),
			cf = CFrame.new(dir * innerSpan * 0.5, 0, chord * 0.04) * wedgeOrient,
			color = primary,
		},
		{
			name = "MembraneOuter",
			kind = "Wedge",
			size = Vector3.new(thickness * 0.6, chord * 0.72, outerSpan),
			cf = CFrame.new(dir * (innerSpan + outerSpan * 0.42), 0, chord * 0.16)
				* CFrame.Angles(0, dir * math.rad(-12), 0)
				* wedgeOrient,
			color = primary,
		},
	}

	return {
		model = model,
		pieces = buildPieces(model, specs),
		dir = dir,
		meshAsset = meshAsset,
		hasMesh = false,
	}
end

local function buildWyvernFallback(
	parent: Instance,
	variant: "drake" | "rift",
	targetHeight: number,
	wingspan: number
): (BodySlot, WingSlot, WingSlot)
	local s = targetHeight / 3.6
	local isRift = variant == "rift"
	local primary = if isRift then COLOR_IRON else COLOR_AMBER
	local secondary = if isRift then COLOR_TEAL_DARK else COLOR_WOOD_DARK
	local wingColor = if isRift then COLOR_TEAL else COLOR_AMBER
	local crestColor = if isRift then COLOR_TEAL_BRIGHT else COLOR_AMBER_BRIGHT

	local bodyModel = Instance.new("Model")
	bodyModel.Name = "FallbackBody"
	bodyModel.Parent = parent

	local specs: { PieceSpec } = {
		{
			name = "Chest",
			kind = "Ball",
			size = Vector3.new(1.75 * s, 1.5 * s, 2.5 * s),
			cf = CFrame.new(0, 0, -0.35 * s),
			color = primary,
		},
		{
			name = "Abdomen",
			kind = "Ball",
			size = Vector3.new(1.35 * s, 1.2 * s, 2.3 * s),
			cf = CFrame.new(0, -0.1 * s, 1.25 * s),
			color = secondary,
		},
		{
			name = "Neck",
			kind = "Cylinder",
			size = Vector3.new(1.8 * s, 0.72 * s, 0.72 * s),
			cf = CFrame.new(0, 0.45 * s, -1.85 * s) * CFrame.Angles(math.rad(-22), math.rad(90), 0),
			color = primary,
		},
		{
			name = "Head",
			kind = "Ball",
			size = Vector3.new(1.0 * s, 0.85 * s, 1.15 * s),
			cf = CFrame.new(0, 0.8 * s, -2.7 * s),
			color = primary,
		},
		{
			name = "Snout",
			kind = "Wedge",
			size = Vector3.new(0.65 * s, 0.48 * s, 1.05 * s),
			cf = CFrame.new(0, 0.72 * s, -3.4 * s),
			color = secondary,
		},
		{
			name = "TailA",
			kind = "Cylinder",
			size = Vector3.new(2.2 * s, 0.65 * s, 0.65 * s),
			cf = CFrame.new(0, -0.05 * s, 2.85 * s) * CFrame.Angles(math.rad(6), math.rad(90), 0),
			color = secondary,
		},
		{
			name = "TailB",
			kind = "Cylinder",
			size = Vector3.new(1.8 * s, 0.35 * s, 0.35 * s),
			cf = CFrame.new(0, 0.12 * s, 4.45 * s) * CFrame.Angles(math.rad(-8), math.rad(90), 0),
			color = primary,
		},
		{
			name = "TailFin",
			kind = "Wedge",
			size = Vector3.new(0.14 * s, 0.95 * s, 1.05 * s),
			cf = CFrame.new(0, 0.25 * s, 5.45 * s)
				* CFrame.Angles(math.rad(180), math.rad(180), math.rad(90)),
			color = crestColor,
		},
	}
	for _, side in ipairs({ -1, 1 }) do
		specs[#specs + 1] = {
			name = if side < 0 then "HornL" else "HornR",
			kind = "Wedge",
			size = Vector3.new(0.18 * s, 0.32 * s, 0.95 * s),
			cf = CFrame.new(side * 0.34 * s, 1.18 * s, -2.18 * s)
				* CFrame.Angles(math.rad(28), math.rad(180 + side * 14), 0),
			color = crestColor,
			mat = Enum.Material.Neon,
		}
		specs[#specs + 1] = {
			name = if side < 0 then "EyeL" else "EyeR",
			kind = "Ball",
			size = Vector3.new(0.18 * s, 0.16 * s, 0.18 * s),
			cf = CFrame.new(side * 0.36 * s, 0.92 * s, -3.02 * s),
			color = crestColor,
			mat = Enum.Material.Neon,
		}
	end

	local shoulderOffsetX = 0.68 * s
	local wingSpan = math.max(wingspan * 0.5 - shoulderOffsetX, wingspan * 0.36)
	local wingL = buildWingFallback(
		parent,
		"FallbackWingL",
		1,
		wingSpan,
		1.7 * s,
		0.14 * s,
		wingColor,
		secondary,
		FAUNA_PREFIX .. "wyvern_wing_l"
	)
	local wingR = buildWingFallback(
		parent,
		"FallbackWingR",
		-1,
		wingSpan,
		1.7 * s,
		0.14 * s,
		wingColor,
		secondary,
		FAUNA_PREFIX .. "wyvern_wing_r"
	)

	local bodySlot: BodySlot = {
		model = bodyModel,
		pieces = buildPieces(bodyModel, specs),
		shoulderOffsetX = shoulderOffsetX,
		shoulderY = 0.28 * s,
		shoulderZ = -0.45 * s,
		meshAsset = FAUNA_PREFIX .. "wyvern_body",
		hasMesh = false,
	}
	return bodySlot, wingL, wingR
end

local function buildBirdFallback(
	parent: Instance,
	variant: "raven" | "falcon",
	targetHeight: number,
	wingspan: number
): (BodySlot, WingSlot, WingSlot)
	local s = targetHeight / 0.65
	local isFalcon = variant == "falcon"
	local primary = if isFalcon then COLOR_STONE_DARK else COLOR_IRON_DARK
	local accent = if isFalcon then COLOR_TEAL_DARK else COLOR_WOOD_DARK
	local beakColor = if isFalcon then COLOR_AMBER_BRIGHT else COLOR_AMBER

	local bodyModel = Instance.new("Model")
	bodyModel.Name = "FallbackBody"
	bodyModel.Parent = parent

	local specs: { PieceSpec } = {
		{
			name = "Torso",
			kind = "Ball",
			size = Vector3.new(0.42 * s, 0.36 * s, 0.92 * s),
			cf = CFrame.new(0, 0, 0),
			color = primary,
		},
		{
			name = "Breast",
			kind = "Ball",
			size = Vector3.new(0.36 * s, 0.30 * s, 0.45 * s),
			cf = CFrame.new(0, -0.05 * s, -0.22 * s),
			color = accent,
		},
		{
			name = "Head",
			kind = "Ball",
			size = Vector3.new(0.28 * s, 0.26 * s, 0.32 * s),
			cf = CFrame.new(0, 0.14 * s, -0.48 * s),
			color = primary,
		},
		{
			name = "Beak",
			kind = "Wedge",
			size = Vector3.new(0.11 * s, 0.12 * s, 0.28 * s),
			cf = CFrame.new(0, 0.12 * s, -0.72 * s),
			color = beakColor,
		},
		{
			name = "Tail",
			kind = "Wedge",
			size = Vector3.new(0.06 * s, 0.34 * s, 0.56 * s),
			cf = CFrame.new(0, 0.04 * s, 0.62 * s) * CFrame.Angles(0, math.rad(180), math.rad(90)),
			color = accent,
		},
	}

	local shoulderOffsetX = 0.15 * s
	local wingSpan = math.max(wingspan * 0.5 - shoulderOffsetX, wingspan * 0.36)
	local wingL = buildWingFallback(
		parent,
		"FallbackWingL",
		1,
		wingSpan,
		0.45 * s,
		0.05 * s,
		primary,
		accent,
		FAUNA_PREFIX .. "bird_wing_l"
	)
	local wingR = buildWingFallback(
		parent,
		"FallbackWingR",
		-1,
		wingSpan,
		0.45 * s,
		0.05 * s,
		primary,
		accent,
		FAUNA_PREFIX .. "bird_wing_r"
	)

	local bodySlot: BodySlot = {
		model = bodyModel,
		pieces = buildPieces(bodyModel, specs),
		shoulderOffsetX = shoulderOffsetX,
		shoulderY = 0.05 * s,
		shoulderZ = -0.08 * s,
		meshAsset = FAUNA_PREFIX .. "bird_body",
		hasMesh = false,
	}
	return bodySlot, wingL, wingR
end

local function appendQuadrupedLegs(
	specs: { PieceSpec },
	legRadius: number,
	legHeight: number,
	halfX: number,
	frontZ: number,
	backZ: number,
	color: Color3
): ()
	local offsets = {
		{ name = "LegFL", x = -halfX, z = frontZ },
		{ name = "LegFR", x = halfX, z = frontZ },
		{ name = "LegBL", x = -halfX, z = backZ },
		{ name = "LegBR", x = halfX, z = backZ },
	}
	for _, info in ipairs(offsets) do
		specs[#specs + 1] = {
			name = info.name,
			kind = "Cylinder",
			size = Vector3.new(legHeight, legRadius * 2, legRadius * 2),
			cf = CFrame.new(info.x, legHeight * 0.5, info.z) * CFrame.Angles(0, 0, math.rad(90)),
			color = color,
		}
	end
end

local function buildGroundFallback(
	kind: "pack_ox" | "stag" | "ram",
	parent: Instance,
	targetHeight: number
): (Model, { Piece })
	local model = Instance.new("Model")
	model.Name = "FallbackVisual"
	model.Parent = parent

	local specs: { PieceSpec } = {}
	if kind == "pack_ox" then
		local s = targetHeight / 2.8
		specs = {
			{
				name = "Chest",
				kind = "Ball",
				size = Vector3.new(1.75 * s, 1.65 * s, 2.2 * s),
				cf = CFrame.new(0, 1.38 * s, -0.55 * s),
				color = COLOR_WOOD,
			},
			{
				name = "Hind",
				kind = "Ball",
				size = Vector3.new(1.55 * s, 1.5 * s, 1.9 * s),
				cf = CFrame.new(0, 1.34 * s, 0.85 * s),
				color = COLOR_WOOD_DARK,
			},
			{
				name = "Neck",
				kind = "Cylinder",
				size = Vector3.new(1.1 * s, 0.95 * s, 0.95 * s),
				cf = CFrame.new(0, 1.68 * s, -1.65 * s)
					* CFrame.Angles(math.rad(-12), math.rad(90), 0),
				color = COLOR_WOOD_DARK,
			},
			{
				name = "Head",
				kind = "Ball",
				size = Vector3.new(1.05 * s, 0.95 * s, 1.15 * s),
				cf = CFrame.new(0, 1.72 * s, -2.25 * s),
				color = COLOR_WOOD,
			},
			{
				name = "Muzzle",
				kind = "Wedge",
				size = Vector3.new(0.68 * s, 0.55 * s, 0.72 * s),
				cf = CFrame.new(0, 1.54 * s, -2.85 * s),
				color = COLOR_STONE_DARK,
			},
			{
				name = "SaddlePack",
				kind = "Ball",
				size = Vector3.new(1.95 * s, 0.85 * s, 1.55 * s),
				cf = CFrame.new(0, 2.02 * s, 0.15 * s),
				color = COLOR_IRON_DARK,
				mat = Enum.Material.Fabric,
			},
		}
		for _, side in ipairs({ -1, 1 }) do
			specs[#specs + 1] = {
				name = if side < 0 then "HornL" else "HornR",
				kind = "Wedge",
				size = Vector3.new(0.18 * s, 0.34 * s, 0.75 * s),
				cf = CFrame.new(side * 0.52 * s, 2.2 * s, -2.38 * s)
					* CFrame.Angles(math.rad(28), math.rad(side * -35), 0),
				color = COLOR_PARCHMENT,
			}
			specs[#specs + 1] = {
				name = if side < 0 then "CargoCrystalL" else "CargoCrystalR",
				kind = "Wedge",
				size = Vector3.new(0.45 * s, 0.88 * s, 0.58 * s),
				cf = CFrame.new(side * 0.62 * s, 2.28 * s, 0.15 * s)
					* CFrame.Angles(math.rad(12), 0, math.rad(side * -24)),
				color = COLOR_AMBER_BRIGHT,
				mat = Enum.Material.Neon,
			}
		end
		appendQuadrupedLegs(
			specs,
			0.24 * s,
			1.0 * s,
			0.52 * s,
			-0.92 * s,
			1.02 * s,
			COLOR_WOOD_DARK
		)
	elseif kind == "stag" then
		local s = targetHeight / 3.1
		specs = {
			{
				name = "Torso",
				kind = "Ball",
				size = Vector3.new(0.95 * s, 0.92 * s, 2.1 * s),
				cf = CFrame.new(0, 1.48 * s, 0.1 * s),
				color = COLOR_TAWNY,
			},
			{
				name = "Ruff",
				kind = "Ball",
				size = Vector3.new(0.82 * s, 0.82 * s, 0.92 * s),
				cf = CFrame.new(0, 1.56 * s, -0.78 * s),
				color = COLOR_PARCHMENT,
			},
			{
				name = "Neck",
				kind = "Cylinder",
				size = Vector3.new(1.15 * s, 0.44 * s, 0.44 * s),
				cf = CFrame.new(0, 2.15 * s, -1.05 * s)
					* CFrame.Angles(math.rad(55), math.rad(90), 0),
				color = COLOR_TAWNY,
			},
			{
				name = "Head",
				kind = "Ball",
				size = Vector3.new(0.44 * s, 0.42 * s, 0.62 * s),
				cf = CFrame.new(0, 2.58 * s, -1.38 * s),
				color = COLOR_TAWNY,
			},
			{
				name = "Muzzle",
				kind = "Wedge",
				size = Vector3.new(0.28 * s, 0.24 * s, 0.52 * s),
				cf = CFrame.new(0, 2.48 * s, -1.78 * s),
				color = COLOR_WOOD_DARK,
			},
			{
				name = "Tail",
				kind = "Wedge",
				size = Vector3.new(0.22 * s, 0.28 * s, 0.36 * s),
				cf = CFrame.new(0, 1.65 * s, 1.15 * s)
					* CFrame.Angles(math.rad(15), math.rad(180), 0),
				color = COLOR_PARCHMENT,
			},
		}
		for _, side in ipairs({ -1, 1 }) do
			specs[#specs + 1] = {
				name = if side < 0 then "AntlerMainL" else "AntlerMainR",
				kind = "Wedge",
				size = Vector3.new(0.10 * s, 0.72 * s, 0.42 * s),
				cf = CFrame.new(side * 0.26 * s, 2.98 * s, -1.16 * s)
					* CFrame.Angles(math.rad(14), math.rad(180 + side * 22), math.rad(side * -18)),
				color = COLOR_WOOD_DARK,
				mat = Enum.Material.Wood,
			}
			specs[#specs + 1] = {
				name = if side < 0 then "AntlerTineL" else "AntlerTineR",
				kind = "Wedge",
				size = Vector3.new(0.08 * s, 0.42 * s, 0.28 * s),
				cf = CFrame.new(side * 0.42 * s, 3.06 * s, -1.36 * s)
					* CFrame.Angles(math.rad(-20), math.rad(side * -26), 0),
				color = COLOR_WOOD_DARK,
				mat = Enum.Material.Wood,
			}
		end
		appendQuadrupedLegs(
			specs,
			0.11 * s,
			1.25 * s,
			0.28 * s,
			-0.65 * s,
			0.78 * s,
			COLOR_WOOD_DARK
		)
	else
		local s = targetHeight / 2.2
		specs = {
			{
				name = "Body",
				kind = "Ball",
				size = Vector3.new(1.1 * s, 1.0 * s, 1.75 * s),
				cf = CFrame.new(0, 1.12 * s, 0.05 * s),
				color = COLOR_WOOL,
			},
			{
				name = "Neck",
				kind = "Cylinder",
				size = Vector3.new(0.75 * s, 0.52 * s, 0.52 * s),
				cf = CFrame.new(0, 1.52 * s, -0.78 * s)
					* CFrame.Angles(math.rad(38), math.rad(90), 0),
				color = COLOR_WOOL,
			},
			{
				name = "Head",
				kind = "Ball",
				size = Vector3.new(0.56 * s, 0.54 * s, 0.68 * s),
				cf = CFrame.new(0, 1.78 * s, -1.12 * s),
				color = COLOR_STONE,
			},
			{
				name = "Snout",
				kind = "Wedge",
				size = Vector3.new(0.36 * s, 0.28 * s, 0.46 * s),
				cf = CFrame.new(0, 1.66 * s, -1.52 * s),
				color = COLOR_IRON_DARK,
			},
		}
		for _, side in ipairs({ -1, 1 }) do
			specs[#specs + 1] = {
				name = if side < 0 then "HornBaseL" else "HornBaseR",
				kind = "Cylinder",
				size = Vector3.new(0.45 * s, 0.28 * s, 0.28 * s),
				cf = CFrame.new(side * 0.36 * s, 1.98 * s, -1.04 * s)
					* CFrame.Angles(math.rad(20), math.rad(side * -30), math.rad(side * 25)),
				color = COLOR_WOOD_DARK,
			}
			specs[#specs + 1] = {
				name = if side < 0 then "HornCurlL" else "HornCurlR",
				kind = "Wedge",
				size = Vector3.new(0.18 * s, 0.36 * s, 0.48 * s),
				cf = CFrame.new(side * 0.48 * s, 1.84 * s, -0.82 * s)
					* CFrame.Angles(math.rad(-25), math.rad(180 + side * 15), 0),
				color = COLOR_WOOD_DARK,
			}
		end
		appendQuadrupedLegs(
			specs,
			0.14 * s,
			0.85 * s,
			0.34 * s,
			-0.52 * s,
			0.62 * s,
			COLOR_IRON_DARK
		)
	end

	return model, buildPieces(model, specs)
end

local function wrapAndNormalizeMesh(
	template: Instance,
	modelName: string,
	parent: Instance,
	scaleAxis: "X" | "Y",
	targetSize: number,
	anchorMode: "center" | "bottom" | "wing",
	isLeftWing: boolean
): (Model?, { Piece }, Vector3, number)
	local wrapper: Model
	if template:IsA("Model") then
		wrapper = template:Clone()
		wrapper.Name = modelName
	elseif template:IsA("BasePart") then
		wrapper = Instance.new("Model")
		wrapper.Name = modelName
		local partClone = template:Clone()
		partClone.Parent = wrapper
		wrapper.PrimaryPart = partClone
	else
		return nil, {}, Vector3.zero, 0
	end

	local hasParts = false
	for _, desc in ipairs(wrapper:GetDescendants()) do
		if desc:IsA("BasePart") then
			inert(desc)
			hasParts = true
		end
	end
	if not hasParts then
		wrapper:Destroy()
		return nil, {}, Vector3.zero, 0
	end

	wrapper.Parent = parent

	local _, rawSize = wrapper:GetBoundingBox()
	local denom = if scaleAxis == "X" then rawSize.X else rawSize.Y
	if denom <= 0.05 then
		denom = rawSize.Magnitude
	end
	if denom > 0.01 then
		wrapper:ScaleTo(wrapper:GetScale() * (targetSize / denom))
	end

	wrapper:PivotTo(ROT_GLTF_TO_LOCAL)
	local bbCf, bbSize = wrapper:GetBoundingBox()

	local anchor: Vector3
	local dir = 0
	if anchorMode == "center" then
		anchor = bbCf.Position
	elseif anchorMode == "bottom" then
		anchor = Vector3.new(bbCf.Position.X, bbCf.Position.Y - bbSize.Y * 0.5, bbCf.Position.Z)
	else
		local minX = bbCf.Position.X - bbSize.X * 0.5
		local maxX = bbCf.Position.X + bbSize.X * 0.5
		local shoulderX: number
		if math.abs(math.abs(minX) - math.abs(maxX)) > 0.01 then
			if math.abs(minX) <= math.abs(maxX) then
				shoulderX = minX
				dir = 1
			else
				shoulderX = maxX
				dir = -1
			end
		elseif isLeftWing then
			shoulderX = minX
			dir = 1
		else
			shoulderX = maxX
			dir = -1
		end
		anchor = Vector3.new(shoulderX, bbCf.Position.Y, bbCf.Position.Z)
	end

	local shift = CFrame.new(-anchor)
	local pieces: { Piece } = {}
	for _, desc in ipairs(wrapper:GetDescendants()) do
		if desc:IsA("BasePart") then
			pieces[#pieces + 1] = {
				part = desc,
				localCF = shift * desc.CFrame,
			}
		end
	end

	if #pieces == 0 then
		wrapper:Destroy()
		return nil, {}, Vector3.zero, 0
	end

	return wrapper, pieces, bbSize, dir
end

local function trySwapFlyingSlots(creature: FlyingCreature, assets: Instance): (boolean, boolean)
	local swapped = false
	if not creature.body.hasMesh then
		local bodyTemplate = assets:FindFirstChild(creature.body.meshAsset)
		if bodyTemplate ~= nil then
			local model, pieces, bbSize = wrapAndNormalizeMesh(
				bodyTemplate,
				"MeshBody",
				creature.root,
				"Y",
				creature.targetHeight,
				"center",
				false
			)
			if model ~= nil then
				creature.body.model:Destroy()
				creature.body.model = model
				creature.body.pieces = pieces
				creature.body.shoulderOffsetX = math.clamp(
					bbSize.X * 0.32,
					creature.targetHeight * 0.14,
					creature.wingspan * 0.14
				)
				creature.body.shoulderY = bbSize.Y * 0.12
				creature.body.shoulderZ = -bbSize.Z * 0.06
				creature.body.hasMesh = true
				swapped = true
			end
		end
	end

	local wingPairs: { { slot: WingSlot, isLeft: boolean, name: string } } = {
		{ slot = creature.wingL, isLeft = true, name = "MeshWingL" },
		{ slot = creature.wingR, isLeft = false, name = "MeshWingR" },
	}
	for _, entry in ipairs(wingPairs) do
		local slot = entry.slot
		if not slot.hasMesh then
			local wingTemplate = assets:FindFirstChild(slot.meshAsset)
			if wingTemplate ~= nil then
				local targetSpanX = math.max(
					creature.wingspan * 0.5 - creature.body.shoulderOffsetX,
					creature.wingspan * 0.36
				)
				local model, pieces, _, dir = wrapAndNormalizeMesh(
					wingTemplate,
					entry.name,
					creature.root,
					"X",
					targetSpanX,
					"wing",
					entry.isLeft
				)
				if model ~= nil then
					slot.model:Destroy()
					slot.model = model
					slot.pieces = pieces
					slot.dir = dir
					slot.hasMesh = true
					swapped = true
				end
			end
		end
	end

	return creature.body.hasMesh and creature.wingL.hasMesh and creature.wingR.hasMesh, swapped
end

local function trySwapGroundMesh(creature: GroundCreature, assets: Instance): boolean
	if creature.hasMesh then
		return true
	end
	local template = assets:FindFirstChild(creature.meshAsset)
	if template == nil then
		return false
	end
	local model, pieces = wrapAndNormalizeMesh(
		template,
		"MeshVisual",
		creature.root,
		"Y",
		creature.targetHeight,
		"bottom",
		false
	)
	if model == nil then
		return false
	end
	creature.visual:Destroy()
	creature.visual = model
	creature.pieces = pieces
	creature.hasMesh = true
	return true
end

local function sampleFlightPath(creature: FlyingCreature, theta: number): Vector3
	local c = creature.center
	if creature.pathMode == "figure8" then
		local x = c.X + creature.rx * math.sin(theta)
		local z = c.Z + creature.rz * math.sin(2 * theta)
		local y = c.Y + creature.yAmp * math.cos(theta * creature.yFreq)
		return Vector3.new(x, y, z)
	end
	local x = c.X + creature.rx * math.cos(theta)
	local z = c.Z + creature.rz * math.sin(theta)
	local y = c.Y + creature.yAmp * math.sin(theta * creature.yFreq + 0.4)
	return Vector3.new(x, y, z)
end

local function computeFlapAngle(creature: FlyingCreature, now: number): number
	local cycle = creature.flapBurstSec + creature.glideSec
	local t = (now + creature.phase) % cycle
	if t >= creature.flapBurstSec then
		return creature.dihedralRad + 0.025 * math.sin(now * 2.1 + creature.phase)
	end
	local fadeIn = math.clamp(t / 0.2, 0, 1)
	local fadeOut = math.clamp((creature.flapBurstSec - t) / 0.25, 0, 1)
	local env = math.min(fadeIn, fadeOut)
	local stroke = math.sin(t * creature.flapHz * math.pi * 2)
	return creature.dihedralRad * (1 - env) + stroke * creature.flapAmpRad * env
end

local function posePieces(rootCF: CFrame, pieces: { Piece }): ()
	for _, piece in ipairs(pieces) do
		piece.part.CFrame = rootCF * piece.localCF
	end
end

local function poseFlying(creature: FlyingCreature, origin: Vector3, now: number, dt: number): ()
	local theta = now * creature.orbitSpeed + creature.phase
	local posLocal = sampleFlightPath(creature, theta)
	local aheadLocal = sampleFlightPath(creature, theta + 0.02)
	local rawFwd = aheadLocal - posLocal
	local forwardDir = if rawFwd.Magnitude > 1e-4 then rawFwd.Unit else Vector3.new(0, 0, -1)

	local rightVec = forwardDir:Cross(Vector3.new(0, 1, 0))
	rightVec = if rightVec.Magnitude > 1e-4 then rightVec.Unit else Vector3.new(1, 0, 0)

	if creature.prevForward == nil then
		local prevPos = sampleFlightPath(creature, theta - creature.orbitSpeed * 0.02)
		local prevRaw = posLocal - prevPos
		local prevFwd = if prevRaw.Magnitude > 1e-4 then prevRaw.Unit else forwardDir
		local lateralTurn = ((forwardDir - prevFwd) / 0.02):Dot(rightVec)
		creature.smoothBank =
			-math.clamp(lateralTurn * creature.bankGain, -creature.maxBankRad, creature.maxBankRad)
	elseif dt > 1e-4 then
		local lateralTurn = ((forwardDir - creature.prevForward) / dt):Dot(rightVec)
		local targetBank =
			-math.clamp(lateralTurn * creature.bankGain, -creature.maxBankRad, creature.maxBankRad)
		local bankAlpha = 1 - math.exp(-dt * 4.5)
		creature.smoothBank += (targetBank - creature.smoothBank) * bankAlpha
	end
	creature.prevForward = forwardDir

	local flapRad = computeFlapAngle(creature, now)
	local heaveY = -flapRad * (if creature.kind == "wyvern" then 0.22 else 0.04)
	local worldPos = origin + posLocal + Vector3.new(0, heaveY, 0)
	local rootCF = CFrame.lookAt(worldPos, worldPos + forwardDir)
		* CFrame.Angles(0, 0, creature.smoothBank)

	posePieces(rootCF, creature.body.pieces)

	local body = creature.body
	for _, slot in ipairs({ creature.wingL, creature.wingR }) do
		local shoulderCF = rootCF
			* CFrame.new(slot.dir * body.shoulderOffsetX, body.shoulderY, body.shoulderZ)
			* CFrame.Angles(0, 0, slot.dir * flapRad)
		posePieces(shoulderCF, slot.pieces)
	end
end

local function samplePolyline(
	waypoints: { Vector2 },
	segLengths: { number },
	totalLength: number,
	dist: number,
	dir: number,
	lateralOffset: number
): (Vector2, Vector2)
	local clamped = math.clamp(dist, 0, totalLength)
	local accum = 0
	local segIdx = #segLengths
	local segT = 1
	for idx, segLen in ipairs(segLengths) do
		if clamped <= accum + segLen or idx == #segLengths then
			segIdx = idx
			segT = if segLen > 1e-4 then math.clamp((clamped - accum) / segLen, 0, 1) else 0
			break
		end
		accum += segLen
	end

	local a = waypoints[segIdx]
	local b = waypoints[segIdx + 1]
	local segVec = b - a
	local basePos = a:Lerp(b, segT)
	local fwd2D = if segVec.Magnitude > 1e-4 then segVec.Unit else Vector2.new(-1, 0)
	if dir < 0 then
		fwd2D = -fwd2D
	end
	local right2D = Vector2.new(-fwd2D.Y, fwd2D.X)
	return basePos + right2D * lateralOffset, fwd2D
end

local function poseGround(
	creature: GroundCreature,
	origin: Vector3,
	groundHeight: (number, number) -> number,
	now: number,
	dt: number
): ()
	local pos2D: Vector2
	local desiredFwd2D: Vector2
	local walkWeight = 1
	local grazePitch = 0
	local stepBobY = 0
	local swayRoll = 0

	if
		creature.motionMode == "road"
		and creature.waypoints ~= nil
		and creature.segLengths ~= nil
	then
		local edgeDist =
			math.min(creature.roadProgress, creature.totalLength - creature.roadProgress)
		local speedFactor = math.clamp(edgeDist / 3.0, 0.35, 1.0)
		creature.roadProgress += creature.roadDir * creature.speed * speedFactor * dt
		if creature.roadProgress >= creature.totalLength then
			creature.roadProgress = creature.totalLength
			creature.roadDir = -1
		elseif creature.roadProgress <= 0 then
			creature.roadProgress = 0
			creature.roadDir = 1
		end
		pos2D, desiredFwd2D = samplePolyline(
			creature.waypoints,
			creature.segLengths,
			creature.totalLength,
			creature.roadProgress,
			creature.roadDir,
			creature.roadLateralOffset
		)
	else
		local center = creature.loopCenter or Vector2.new(-64, -76)
		if creature.pauseSec > 0 then
			local cycle = creature.walkSec + creature.pauseSec
			local phaseTime = (now + creature.phase) % cycle
			if phaseTime < creature.walkSec then
				local rampIn = math.clamp(phaseTime / 0.35, 0, 1)
				local rampOut = math.clamp((creature.walkSec - phaseTime) / 0.45, 0, 1)
				walkWeight = math.min(rampIn, rampOut)
			else
				walkWeight = 0
				local gt = phaseTime - creature.walkSec
				local dipIn = math.clamp(gt / 0.45, 0, 1)
				local dipOut = math.clamp((creature.pauseSec - gt) / 0.45, 0, 1)
				local dipEnv = math.min(dipIn, dipOut)
				grazePitch = (-0.34 + 0.055 * math.sin(gt * 8.0)) * dipEnv
			end
		end
		creature.roadProgress += creature.loopSpeed * walkWeight * dt
		local theta = creature.roadProgress
		pos2D = Vector2.new(
			center.X + creature.loopRx * math.cos(theta),
			center.Y + creature.loopRz * math.sin(theta)
		)
		local tangent =
			Vector2.new(-creature.loopRx * math.sin(theta), creature.loopRz * math.cos(theta))
		desiredFwd2D = if tangent.Magnitude > 1e-4 then tangent.Unit else Vector2.new(0, -1)
	end

	local rawFwd3D = Vector3.new(desiredFwd2D.X, 0, desiredFwd2D.Y)
	local desiredFwd3D = if rawFwd3D.Magnitude > 1e-4 then rawFwd3D.Unit else Vector3.new(0, 0, -1)

	local isFirstPose = creature.smoothForward == nil
	local currentForward: Vector3
	if isFirstPose then
		currentForward = desiredFwd3D
	elseif dt > 0 then
		local turnAlpha = 1 - math.exp(-dt * 4.2)
		local blendedFwd = (creature.smoothForward :: Vector3):Lerp(desiredFwd3D, turnAlpha)
		currentForward = if blendedFwd.Magnitude > 1e-4 then blendedFwd.Unit else desiredFwd3D
	else
		currentForward = creature.smoothForward :: Vector3
	end
	creature.smoothForward = currentForward

	local groundY = groundHeight(pos2D.X, pos2D.Y)
	local aheadY = groundHeight(pos2D.X + currentForward.X * 0.9, pos2D.Y + currentForward.Z * 0.9)
	local slopePitch = math.clamp(math.atan2(aheadY - groundY, 0.9), -0.45, 0.45)
	if isFirstPose then
		creature.smoothPitch = slopePitch
	elseif dt > 0 then
		local pitchAlpha = 1 - math.exp(-dt * 6.0)
		creature.smoothPitch += (slopePitch - creature.smoothPitch) * pitchAlpha
	end

	if creature.hopMode then
		local hopPhase = (now * creature.bobHz + creature.phase) * math.pi
		stepBobY = math.abs(math.sin(hopPhase)) * creature.bobAmp
		grazePitch = 0.09 * math.cos(hopPhase)
	else
		local gait = (now * creature.bobHz + creature.phase) * math.pi
		stepBobY = math.abs(math.sin(gait)) * creature.bobAmp * walkWeight
		swayRoll = math.sin(gait * 0.5) * creature.swayAmp * walkWeight
	end

	local worldPos = origin + Vector3.new(pos2D.X, groundY + stepBobY, pos2D.Y)
	local baseCF = CFrame.lookAt(worldPos, worldPos + currentForward)
		* CFrame.Angles(creature.smoothPitch, 0, swayRoll)

	local pivotY = creature.targetHeight * 0.48
	local rootCF = if math.abs(grazePitch) > 1e-4
		then baseCF * CFrame.new(0, pivotY, 0) * CFrame.Angles(grazePitch, 0, 0) * CFrame.new(
			0,
			-pivotY,
			0
		)
		else baseCF

	posePieces(rootCF, creature.pieces)
	if creature.lightPart ~= nil then
		creature.lightPart.CFrame = rootCF * CFrame.new(creature.lightLocalOffset)
	end
end

local function createFlyingCreature(
	folder: Folder,
	name: string,
	kind: "wyvern" | "bird",
	variant: "drake" | "rift" | "raven" | "falcon",
	targetHeight: number,
	wingspan: number,
	pathMode: "ellipse" | "figure8",
	center: Vector3,
	rx: number,
	rz: number,
	yAmp: number,
	yFreq: number,
	orbitSpeed: number,
	phase: number,
	flapHz: number,
	flapBurstSec: number,
	glideSec: number,
	flapAmpRad: number,
	dihedralRad: number,
	bankGain: number,
	maxBankRad: number
): FlyingCreature
	local root = Instance.new("Model")
	root.Name = name
	root.Parent = folder

	local bodySlot: BodySlot
	local wingL: WingSlot
	local wingR: WingSlot
	if kind == "wyvern" then
		bodySlot, wingL, wingR =
			buildWyvernFallback(root, variant :: "drake" | "rift", targetHeight, wingspan)
	else
		bodySlot, wingL, wingR =
			buildBirdFallback(root, variant :: "raven" | "falcon", targetHeight, wingspan)
	end

	return {
		kind = kind,
		variant = variant,
		root = root,
		body = bodySlot,
		wingL = wingL,
		wingR = wingR,
		wingspan = wingspan,
		targetHeight = targetHeight,
		pathMode = pathMode,
		center = center,
		rx = rx,
		rz = rz,
		yAmp = yAmp,
		yFreq = yFreq,
		orbitSpeed = orbitSpeed,
		phase = phase,
		flapHz = flapHz,
		flapBurstSec = flapBurstSec,
		glideSec = glideSec,
		flapAmpRad = flapAmpRad,
		dihedralRad = dihedralRad,
		bankGain = bankGain,
		maxBankRad = maxBankRad,
		prevForward = nil,
		smoothBank = 0,
	}
end

local function computePolylineMetrics(waypoints: { Vector2 }): ({ number }, number)
	local lengths: { number } = {}
	local total = 0
	for i = 1, #waypoints - 1 do
		local d = (waypoints[i + 1] - waypoints[i]).Magnitude
		lengths[i] = d
		total += d
	end
	return lengths, total
end

local function createGroundCreature(
	folder: Folder,
	name: string,
	kind: "pack_ox" | "stag" | "ram",
	targetHeight: number,
	motionMode: "road" | "loop",
	waypoints: { Vector2 }?,
	roadLateralOffset: number,
	startProgress: number,
	roadDir: number,
	loopCenter: Vector2?,
	loopRx: number,
	loopRz: number,
	loopSpeed: number,
	speed: number,
	phase: number,
	bobHz: number,
	bobAmp: number,
	swayAmp: number,
	walkSec: number,
	pauseSec: number,
	hopMode: boolean
): GroundCreature
	local root = Instance.new("Model")
	root.Name = name
	root.Parent = folder

	local visual, pieces = buildGroundFallback(kind, root, targetHeight)

	local lightPart: BasePart? = nil
	local lightLocalOffset = Vector3.new(0, targetHeight * 0.72, 0.12)
	if kind == "pack_ox" then
		local anchor = Instance.new("Part")
		anchor.Name = "CargoGlow"
		anchor.Shape = Enum.PartType.Ball
		anchor.Size = Vector3.new(0.2, 0.2, 0.2)
		anchor.Transparency = 1
		inert(anchor)
		anchor.Parent = root

		local pointLight = Instance.new("PointLight")
		pointLight.Name = "AmberCargoLight"
		pointLight.Color = COLOR_OX_LIGHT
		pointLight.Range = 12
		pointLight.Brightness = 0.75
		pointLight.Shadows = false
		pointLight.Parent = anchor
		lightPart = anchor
	end

	local segLengths: { number }? = nil
	local totalLength = 0
	if waypoints ~= nil then
		segLengths, totalLength = computePolylineMetrics(waypoints)
	end

	return {
		kind = kind,
		root = root,
		visual = visual,
		pieces = pieces,
		meshAsset = FAUNA_PREFIX .. kind,
		hasMesh = false,
		targetHeight = targetHeight,
		lightPart = lightPart,
		lightLocalOffset = lightLocalOffset,
		motionMode = motionMode,
		waypoints = waypoints,
		segLengths = segLengths,
		totalLength = totalLength,
		roadLateralOffset = roadLateralOffset,
		roadProgress = startProgress,
		roadDir = roadDir,
		loopCenter = loopCenter,
		loopRx = loopRx,
		loopRz = loopRz,
		loopSpeed = loopSpeed,
		speed = speed,
		phase = phase,
		bobHz = bobHz,
		bobAmp = bobAmp,
		swayAmp = swayAmp,
		walkSec = walkSec,
		pauseSec = pauseSec,
		hopMode = hopMode,
		smoothForward = nil,
		smoothPitch = 0,
	}
end

local function createEcosystem(folder: Folder): ({ FlyingCreature }, { GroundCreature })
	local flyers: { FlyingCreature } = {}
	local walkers: { GroundCreature } = {}

	-- 2 Flying Dragons / Wyverns
	flyers[#flyers + 1] = createFlyingCreature(
		folder,
		"AmberBastionDrake",
		"wyvern",
		"drake",
		3.6,
		9.5,
		"ellipse",
		Vector3.new(-165, 48, -75),
		72,
		68,
		3.4,
		2,
		0.21,
		0.0,
		1.25,
		2.4,
		2.6,
		0.48,
		0.12,
		1.55,
		0.42
	)
	flyers[#flyers + 1] = createFlyingCreature(
		folder,
		"RiftWyvern",
		"wyvern",
		"rift",
		4.2,
		11.0,
		"figure8",
		Vector3.new(-145, 60, -175),
		85,
		55,
		4.0,
		1,
		0.15,
		1.7,
		0.95,
		3.16,
		3.2,
		0.46,
		0.14,
		1.4,
		0.40
	)

	-- Flock A: 4 birds near Windmill & Watchtower (-112, 24, -24), r ~ 18..26
	local flockARadii = { 18.5, 21.0, 23.5, 25.8 }
	for i = 1, 4 do
		local r = flockARadii[i]
		flyers[#flyers + 1] = createFlyingCreature(
			folder,
			string.format("WatchRaven_A%d", i),
			"bird",
			if i % 2 == 1 then "raven" else "falcon",
			0.65,
			2.3,
			"ellipse",
			Vector3.new(-112, 24 + (i - 2.5) * 1.1, -24),
			r,
			r * 0.92,
			1.6,
			1.5,
			0.46 + (i - 1) * 0.04,
			(i - 1) * (math.pi * 0.5) + i * 0.37,
			5.2,
			1.15,
			1.35,
			0.52,
			0.16,
			0.85,
			0.48
		)
	end

	-- Flock B: 4 birds above North Oak Forest (-44, 22, -88), r ~ 20..30
	local flockBRadii = { 20.5, 23.8, 26.8, 29.5 }
	for i = 1, 4 do
		local r = flockBRadii[i]
		flyers[#flyers + 1] = createFlyingCreature(
			folder,
			string.format("BastionFalcon_B%d", i),
			"bird",
			if i % 2 == 0 then "falcon" else "raven",
			0.60,
			2.1,
			"ellipse",
			Vector3.new(-44, 22 + (i - 2.5) * 1.0, -88),
			r,
			r * 0.94,
			1.5,
			1.5,
			-0.44 - (i - 1) * 0.035,
			(i - 1) * (math.pi * 0.5) + 0.9 + i * 0.41,
			5.2,
			1.05,
			1.25,
			0.52,
			0.16,
			0.85,
			0.48
		)
	end

	-- 2 Amber Pack Oxen along Citadel Road
	local roadWaypoints: { Vector2 } = {
		Vector2.new(-36, -2),
		Vector2.new(-46, -6),
		Vector2.new(-70, -22),
		Vector2.new(-96, -38),
		Vector2.new(-118, -54),
	}
	local _, roadLen = computePolylineMetrics(roadWaypoints)
	walkers[#walkers + 1] = createGroundCreature(
		folder,
		"AmberPackOx_1",
		"pack_ox",
		2.8,
		"road",
		roadWaypoints,
		1.0,
		10.0,
		1,
		nil,
		0,
		0,
		0,
		3.2,
		0.0,
		4.2,
		0.09,
		0.035,
		0,
		0,
		false
	)
	walkers[#walkers + 1] = createGroundCreature(
		folder,
		"AmberPackOx_2",
		"pack_ox",
		2.8,
		"road",
		roadWaypoints,
		-1.0,
		roadLen * 0.72,
		-1,
		nil,
		0,
		0,
		0,
		3.2,
		1.4,
		4.2,
		0.09,
		0.035,
		0,
		0,
		false
	)

	-- 2 Woodland Stags: alternating 4.5s walking + 2.8s grazing pauses
	walkers[#walkers + 1] = createGroundCreature(
		folder,
		"WoodlandStag_1",
		"stag",
		3.1,
		"loop",
		nil,
		0,
		0.4,
		1,
		Vector2.new(-64, -76),
		8.5,
		6.0,
		0.48,
		3.5,
		0.0,
		4.4,
		0.11,
		0.025,
		4.5,
		2.8,
		false
	)
	walkers[#walkers + 1] = createGroundCreature(
		folder,
		"WoodlandStag_2",
		"stag",
		3.1,
		"loop",
		nil,
		0,
		2.8,
		1,
		Vector2.new(-22, -58),
		7.5,
		5.5,
		-0.52,
		3.5,
		3.6,
		4.4,
		0.11,
		0.025,
		4.5,
		2.8,
		false
	)

	-- 2 Mountain Rams: energetic 5.0 Hz hops
	walkers[#walkers + 1] = createGroundCreature(
		folder,
		"MountainRam_1",
		"ram",
		2.2,
		"loop",
		nil,
		0,
		0.8,
		1,
		Vector2.new(-86, 44),
		7.5,
		6.0,
		0.65,
		4.2,
		0.4,
		5.0,
		0.24,
		0.03,
		0,
		0,
		true
	)
	walkers[#walkers + 1] = createGroundCreature(
		folder,
		"MountainRam_2",
		"ram",
		2.2,
		"loop",
		nil,
		0,
		3.9,
		1,
		Vector2.new(14, -52),
		7.0,
		5.5,
		-0.68,
		4.2,
		2.1,
		5.0,
		0.24,
		0.03,
		0,
		0,
		true
	)

	return flyers, walkers
end

function AmbientLife.build(
	arenaFolder: Instance,
	origin: Vector3,
	groundHeightFn: ((number, number) -> number)?
): Folder
	local existing = arenaFolder:FindFirstChild(FOLDER_NAME)
	if existing ~= nil then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder.Parent = arenaFolder

	local groundHeight: (number, number) -> number = groundHeightFn
		or function(_x: number, _z: number): number
			return DEFAULT_GROUND_Y
		end

	local flyers, walkers = createEcosystem(folder)

	local startClock = os.clock()
	local function updateAll(dt: number): ()
		local now = os.clock() - startClock
		for _, flyer in ipairs(flyers) do
			poseFlying(flyer, origin, now, dt)
		end
		for _, walker in ipairs(walkers) do
			poseGround(walker, origin, groundHeight, now, dt)
		end
	end

	local function flushMeshes(assets: Instance, poseOnSwap: boolean): boolean
		local anyPending = false
		local swappedAny = false
		for _, flyer in ipairs(flyers) do
			local isComplete, swapped = trySwapFlyingSlots(flyer, assets)
			if swapped then
				swappedAny = true
			end
			if not isComplete then
				anyPending = true
			end
		end
		for _, walker in ipairs(walkers) do
			local wasComplete = walker.hasMesh
			local isComplete = trySwapGroundMesh(walker, assets)
			if isComplete and not wasComplete then
				swappedAny = true
			end
			if not isComplete then
				anyPending = true
			end
		end
		if poseOnSwap and swappedAny then
			updateAll(0)
		end
		return anyPending
	end

	local pendingMeshes = true
	local existingAssets = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER)
	if existingAssets ~= nil then
		pendingMeshes = flushMeshes(existingAssets, false)
	end

	updateAll(0)

	local alive = true
	local wasInGame = arenaFolder:IsDescendantOf(game)
	local heartbeatConn: RBXScriptConnection? = nil
	local assetsChildConn: RBXScriptConnection? = nil
	local repChildConn: RBXScriptConnection? = nil
	local arenaDestroyConn: RBXScriptConnection? = nil
	local folderDestroyConn: RBXScriptConnection? = nil

	local function disconnectWatchers(): ()
		if assetsChildConn ~= nil then
			assetsChildConn:Disconnect()
			assetsChildConn = nil
		end
		if repChildConn ~= nil then
			repChildConn:Disconnect()
			repChildConn = nil
		end
	end

	local function cleanup(): ()
		if not alive then
			return
		end
		alive = false
		if heartbeatConn ~= nil then
			heartbeatConn:Disconnect()
			heartbeatConn = nil
		end
		disconnectWatchers()
		if arenaDestroyConn ~= nil then
			arenaDestroyConn:Disconnect()
			arenaDestroyConn = nil
		end
		if folderDestroyConn ~= nil then
			folderDestroyConn:Disconnect()
			folderDestroyConn = nil
		end
	end

	arenaDestroyConn = arenaFolder.Destroying:Connect(cleanup)
	folderDestroyConn = folder.Destroying:Connect(cleanup)

	heartbeatConn = RunService.Heartbeat:Connect(function(dt: number)
		if not alive then
			return
		end
		local inGame = arenaFolder:IsDescendantOf(game)
		if inGame then
			wasInGame = true
		elseif wasInGame or folder.Parent == nil then
			cleanup()
			return
		end
		updateAll(math.min(dt, 0.1))
	end)

	if pendingMeshes then
		task.spawn(function()
			local deadline = os.clock() + LATE_WAIT_S
			local function attachAssetsListener(assets: Instance): ()
				if not alive then
					return
				end
				if not flushMeshes(assets, true) then
					disconnectWatchers()
					return
				end
				assetsChildConn = assets.ChildAdded:Connect(function(child: Instance)
					if not alive then
						disconnectWatchers()
						return
					end
					if string.sub(child.Name, 1, #FAUNA_PREFIX) == FAUNA_PREFIX then
						task.defer(function()
							if alive and not flushMeshes(assets, true) then
								disconnectWatchers()
							end
						end)
					end
				end)
				local remaining = deadline - os.clock()
				if remaining > 0 then
					task.delay(remaining, disconnectWatchers)
				else
					disconnectWatchers()
				end
			end

			local assets = ReplicatedStorage:FindFirstChild(ASSETS_FOLDER)
			if assets ~= nil then
				attachAssetsListener(assets)
				return
			end

			repChildConn = ReplicatedStorage.ChildAdded:Connect(function(child: Instance)
				if not alive then
					disconnectWatchers()
					return
				end
				if child.Name == ASSETS_FOLDER then
					if repChildConn ~= nil then
						repChildConn:Disconnect()
						repChildConn = nil
					end
					attachAssetsListener(child)
				end
			end)
			task.delay(LATE_WAIT_S, disconnectWatchers)
		end)
	end

	return folder
end

return table.freeze(AmbientLife)
