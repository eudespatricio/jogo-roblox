--!strict
-- S8/S8.2: horda cosmetica em rig hibrido articulado (<=8 BaseParts incluindo RootPart).
-- Malhas Open Cloud esculpem tronco/capuz/elmo; pernas, bracos, cutelo e satelites orbitais
-- sao articulados no cliente a 60 Hz com ciclo de caminhada e golpe na muralha.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VisualTheme = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("visual"):WaitForChild("VisualTheme")
)
local MeshAssets = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("visual"):WaitForChild("MeshAssets")
)

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
	scale: number,
	parts: number,
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
}

local EYE_NEON_COLOR = Color3.fromRGB(220, 255, 245)
local EMBER_NEON_COLOR = Color3.fromRGB(255, 199, 64)
local TEAL_SWARM_COLOR = Color3.fromRGB(45, 212, 191)
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

export type BossUnit = {
	model: Model,
	rootPart: BasePart,
	base: CFrame,
	bossId: string,
	height: number,
	color: Color3,
	accent: Color3,
	squashUntil: number,
	squashSeq: number,
	squashed: boolean,
	lastState: string,
	lastEnraged: boolean,
	lastNow: number,
	visualParts: { TorsoPiece },
	stateHighlight: Highlight,
}

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

local function tryMountBossMesh(model: Model, bossId: string, targetHeight: number): { TorsoPiece }?
	return tryMountScaledMesh(model, MeshAssets.bossModelName(bossId), targetHeight)
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
	local rigCF = CFrame.new(unit.base.Position)
		* unit.base.Rotation
		* CFrame.Angles(0, math.rad(90), 0)
	unit.rootPart.CFrame = rigCF

	local metrics = RIG_METRICS[unit.kind] or RIG_METRICS.runner
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
		local hoverY = math.sin(p * 0.65) * 0.32
		local weaveX = math.cos(p * 0.45) * 0.24
		local lungeZ = -math.max(0, math.sin(p * 1.1)) * 0.65 * atkWeight
		local bank = math.sin(p * 0.45) * (14 * DEG_TO_RAD)

		torsoCF = rigCF
			* CFrame.new(weaveX, metrics.torsoMountY + hoverY, lungeZ)
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
end

local function poseBoss(unit: BossUnit, now: number, state: string?, enraged: boolean?): ()
	local resolvedState = state or "MARCH"
	local isEnraged = enraged == true
	unit.lastState = resolvedState
	unit.lastEnraged = isEnraged
	unit.lastNow = now

	local sxz = 1
	local sy = 1
	if now < unit.squashUntil then
		local alpha = math.clamp(1 - (unit.squashUntil - now) / HIT_SQUASH_DURATION, 0, 1)
		sxz = 1.09 + (1 - 1.09) * alpha
		sy = 0.91 + (1 - 0.91) * alpha
		unit.squashed = true
	elseif unit.squashed then
		unit.squashed = false
	end

	local bobY = 0
	local pitch = 0
	local roll = 0
	local lungeZ = 0
	local jitterX = 0

	if resolvedState == "TELEGRAPH" then
		local vib = math.sin(now * 28)
		jitterX = vib * 0.22
		bobY = 0.28 + math.abs(math.sin(now * 6)) * 0.24
		pitch = math.rad(12)
		unit.stateHighlight.Enabled = true
		unit.stateHighlight.FillColor = rgb(VisualTheme.PALETTE.amberBright)
		unit.stateHighlight.OutlineColor = rgb(VisualTheme.PALETTE.danger)
		unit.stateHighlight.FillTransparency = 0.55 + math.sin(now * 16) * 0.20
		unit.stateHighlight.OutlineTransparency = 0
	elseif resolvedState == "ABILITY" then
		lungeZ = -1.15
		bobY = -0.18
		pitch = math.rad(-16)
		unit.stateHighlight.Enabled = true
		unit.stateHighlight.FillColor = unit.accent
		unit.stateHighlight.OutlineColor = Color3.new(1, 1, 1)
		unit.stateHighlight.FillTransparency = 0.45
		unit.stateHighlight.OutlineTransparency = 0
	elseif resolvedState == "VULNERABLE" then
		bobY = -0.78 + math.sin(now * 5) * 0.08
		pitch = math.rad(14)
		roll = math.sin(now * 7) * math.rad(7)
		unit.stateHighlight.Enabled = true
		unit.stateHighlight.FillColor = rgb(VisualTheme.PALETTE.teal)
		unit.stateHighlight.OutlineColor = Color3.new(1, 1, 1)
		unit.stateHighlight.FillTransparency = 0.50 + math.sin(now * 12) * 0.18
		unit.stateHighlight.OutlineTransparency = 0
	else
		local omega = if isEnraged then 6.8 else 4.6
		local p = now * omega
		bobY = math.abs(math.sin(p)) * 0.34
		pitch = math.rad(-5)
		roll = math.sin(p * 0.5) * math.rad(5)
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

	local rigCF = CFrame.new(unit.base.Position)
		* unit.base.Rotation
		* CFrame.Angles(0, math.rad(90), 0)
	local animCF = rigCF * CFrame.new(jitterX, bobY, lungeZ) * CFrame.Angles(pitch, 0, roll)
	unit.rootPart.CFrame = animCF

	local enrageScale = if isEnraged then 1.04 else 1.0
	for _, entry in ipairs(unit.visualParts) do
		placeScaled(
			animCF,
			entry.part,
			entry.size,
			animCF * entry.localCF,
			sxz * enrageScale,
			sy * enrageScale
		)
	end
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
			local meshPieces = tryMountBossMesh(model, bossUnit.bossId, bossUnit.height)
			if meshPieces ~= nil then
				bossUnit.visualParts = meshPieces
				pendingBossUnits[model] = nil
				poseBoss(
					bossUnit,
					if bossUnit.lastNow > 0 then bossUnit.lastNow else time(),
					bossUnit.lastState,
					bossUnit.lastEnraged
				)
			end
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

function HordeKit.create(kind: string, parent: Instance, cframe: CFrame, unitId: number?): HordeUnit
	local enemies = VisualTheme.ENEMIES :: { [string]: EnemySpec }
	local spec = enemies[kind] or enemies.runner
	local model = Instance.new("Model")
	model.Name = "Horde_" .. kind
	model:SetAttribute("Kind", kind)

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
		else
			torsoParts = buildRunnerFallbackTorso(proc, spec)
		end
	end

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
	}

	poseUnit(unit, now, false)

	if not hasMesh then
		pendingHordeUnits[model] = unit
		ensureHordeMeshWatcher()
	end

	return unit
end

function HordeKit.setBase(unit: HordeUnit, cframe: CFrame): ()
	unit.base = cframe
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
		end
	end
end

local function buildBossFallbackVisual(parent: Instance, spec: BossSpec): { TorsoPiece }
	local h = spec.height
	local k = h / 12.0
	local primary = rgb(spec.color)
	local accent = rgb(spec.accent)
	local dark = Color3.fromRGB(28, 32, 38)

	local legs = makePart(
		parent,
		"BossLegs",
		Vector3.new(4.2 * k, 3.6 * k, 2.8 * k),
		Vector3.new(0, 1.8 * k, 0),
		dark,
		Enum.Material.Metal
	)
	legs.CFrame = CFrame.new(0, 1.8 * k, 0)

	local torso = makeEllipsoid(
		parent,
		"BossTorso",
		Vector3.new(6.8 * k, 5.4 * k, 4.4 * k),
		primary,
		Enum.Material.Metal
	)
	torso.CFrame = CFrame.new(0, 5.8 * k, 0)

	local core = makePart(
		parent,
		"BossCore",
		Vector3.new(2.2 * k, 2.2 * k, 1.2 * k),
		Vector3.new(0, 6.0 * k, -2.0 * k),
		accent,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	core.CFrame = CFrame.new(0, 6.0 * k, -2.0 * k)

	for _, sx in ipairs({ -1, 1 }) do
		local shoulder = makePart(
			parent,
			if sx < 0 then "BossShoulderL" else "BossShoulderR",
			Vector3.new(2.8 * k, 2.8 * k, 2.8 * k),
			Vector3.new(sx * 4.2 * k, 7.6 * k, 0),
			primary,
			Enum.Material.Metal,
			Enum.PartType.Ball
		)
		shoulder.CFrame = CFrame.new(sx * 4.2 * k, 7.6 * k, 0)
	end

	local head = makePart(
		parent,
		"BossHead",
		Vector3.new(2.8 * k, 2.8 * k, 2.8 * k),
		Vector3.new(0, 9.6 * k, -0.4 * k),
		dark,
		Enum.Material.Metal,
		Enum.PartType.Ball
	)
	head.CFrame = CFrame.new(0, 9.6 * k, -0.4 * k)

	local visor = makeEllipsoid(
		parent,
		"BossVisor",
		Vector3.new(1.8 * k, 0.55 * k, 0.7 * k),
		accent,
		Enum.Material.Neon
	)
	visor.CFrame = CFrame.new(0, 9.7 * k, -1.65 * k)

	local list: { TorsoPiece } = {}
	registerTorsoChildren(parent, list)
	return list
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

	local visualParts = tryMountBossMesh(model, bossId, spec.height)
	local hasMesh = visualParts ~= nil
	if visualParts == nil then
		local proc = Instance.new("Folder")
		proc.Name = "ProceduralVisual"
		proc.Parent = model
		visualParts = buildBossFallbackVisual(proc, spec)
	end

	local now = time()
	local bossUnit: BossUnit = {
		model = model,
		rootPart = rootPart,
		base = cframe,
		bossId = bossId,
		height = spec.height,
		color = rgb(spec.color),
		accent = rgb(spec.accent),
		squashUntil = 0,
		squashSeq = 0,
		squashed = false,
		lastState = "MARCH",
		lastEnraged = false,
		lastNow = now,
		visualParts = visualParts :: { TorsoPiece },
		stateHighlight = stateHighlight,
	}

	poseBoss(bossUnit, now, "MARCH", false)

	if not hasMesh then
		pendingBossUnits[model] = bossUnit
		ensureHordeMeshWatcher()
	end

	return bossUnit
end

function HordeKit.setBossBase(bossUnit: BossUnit, cframe: CFrame): ()
	bossUnit.base = cframe
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
	bossUnit.squashUntil = now + HIT_SQUASH_DURATION
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

	task.delay(HIT_SQUASH_DURATION + 0.01, function()
		local parent: Instance? = bossUnit.model.Parent
		if bossUnit.squashSeq == seq and bossUnit.squashed and parent ~= nil then
			bossUnit.squashed = false
			poseBoss(bossUnit, time(), bossUnit.lastState, bossUnit.lastEnraged)
		end
	end)
end

function HordeKit.setBossVisible(bossUnit: BossUnit, visible: boolean): ()
	bossUnit.model:SetAttribute("Hidden", not visible)
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
