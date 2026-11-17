--!strict
-- S8/S8.2: VFX cosmeticos e fisica real F2 local (ragdoll/fratura isolados em CollisionGroup).
-- Tudo local no cliente; nao altera o resultado deterministico da batalha.

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

local VfxAssets = if IS_ROBLOX
	then require(
		game:GetService("ReplicatedStorage")
			:WaitForChild("Shared")
			:WaitForChild("visual")
			:WaitForChild("VfxAssets")
	)
	else Mock.shared("VfxAssets") :: any

local PbrAssets = if IS_ROBLOX
	then require(
		game:GetService("ReplicatedStorage")
			:WaitForChild("Shared")
			:WaitForChild("visual")
			:WaitForChild("PbrAssets")
	)
	else Mock.shared("PbrAssets") :: any

local activeGame = if IS_ROBLOX then game else Mock.game :: typeof(game)
local Instance = if IS_ROBLOX then Instance else Mock.Instance :: typeof(Instance)
local Vector3 = if IS_ROBLOX then Vector3 else Mock.Vector3 :: typeof(Vector3)
local Vector2 = if IS_ROBLOX then Vector2 else Mock.Vector2 :: typeof(Vector2)
local CFrame = if IS_ROBLOX then CFrame else Mock.CFrame :: typeof(CFrame)
local Color3 = if IS_ROBLOX then Color3 else Mock.Color3 :: typeof(Color3)
local ColorSequenceKeypoint = if IS_ROBLOX
	then ColorSequenceKeypoint
	else Mock.ColorSequenceKeypoint :: typeof(ColorSequenceKeypoint)
local ColorSequence = if IS_ROBLOX
	then ColorSequence
	else Mock.ColorSequence :: typeof(ColorSequence)
local NumberSequence = if IS_ROBLOX
	then NumberSequence
	else Mock.NumberSequence :: typeof(NumberSequence)
local NumberSequenceKeypoint = if IS_ROBLOX
	then NumberSequenceKeypoint
	else Mock.NumberSequenceKeypoint :: typeof(NumberSequenceKeypoint)
local NumberRange = if IS_ROBLOX then NumberRange else Mock.NumberRange :: typeof(NumberRange)
local TweenInfo = if IS_ROBLOX then TweenInfo else Mock.TweenInfo :: typeof(TweenInfo)
local PhysicalProperties: typeof(PhysicalProperties) = if IS_ROBLOX
	then PhysicalProperties
	else {
		new = function(
			density: number,
			friction: number,
			elasticity: number,
			fw: number?,
			ew: number?
		)
			return {
				Density = density,
				Friction = friction,
				Elasticity = elasticity,
				FrictionWeight = fw or 1,
				ElasticityWeight = ew or 1,
			}
		end,
	} :: any
local Enum = if IS_ROBLOX then Enum else Mock.Enum :: typeof(Enum)
local task = if IS_ROBLOX then task else Mock.task :: typeof(task)
local time = if IS_ROBLOX then time else Mock.time :: typeof(time)

local Debris = activeGame:GetService("Debris")
local PhysicsService = activeGame:GetService("PhysicsService")
local ReplicatedStorage = activeGame:GetService("ReplicatedStorage")
local RunService = activeGame:GetService("RunService")
local TweenService = activeGame:GetService("TweenService")
local Workspace = activeGame:GetService("Workspace")

local Vfx = {}

export type QualityTier = "Low" | "Mid" | "High"

type QualityConfig = {
	particleScale: number,
	dynamicLights: boolean,
}

type F2Entry = {
	instance: Instance,
	expiresAt: number,
}

type EmitterSpec = {
	name: string?,
	color: ColorSequence,
	size: NumberSequence,
	transparency: NumberSequence,
	lifetime: NumberRange,
	speed: NumberRange,
	spreadAngle: Vector2?,
	acceleration: Vector3?,
	drag: number?,
	lightEmission: number?,
	emissionDirection: Enum.NormalId?,
	rotSpeed: NumberRange?,
	rate: number?,
	burstCount: number?,
	activeSeconds: number?,
	-- Texturas Forge3D (VfxAssets): vazio/nil = partícula padrão (fallback procedural, ID 0).
	texture: string?,
	flipbookLayout: EnumItem?,
	flipbookMode: EnumItem?,
	flipbookFramerate: NumberRange?,
	orientation: EnumItem?,
	squash: NumberSequence?,
	zOffset: number?,
}

local TIER_TTL: { [QualityTier]: number } = {
	Low = 1.2,
	Mid = 2.0,
	High = 3.0,
}

local activeProjectiles = 0
local collisionGroupsConfigured = false
local currentTier: QualityTier = "Mid"
local lowFpsSeconds = 0
local activeF2: { F2Entry } = {}
local governorConn: RBXScriptConnection? = nil
local lastPortalBreachAt = -1
local PORTAL_BREACH_COOLDOWN = 0.065

local camImpulseStart = -10
local camImpulseDuration = 0
local camImpulseIntensity = 0
local camImpulseFovDelta = 0
local camImpulseSampledAt = -10

local telegraphExpiresAt: { [Instance]: number } = {}

local function rgb(value: { number }): Color3
	return Color3.fromRGB(value[1], value[2], value[3])
end

local DEFAULT_QUALITY: QualityConfig = {
	particleScale = 0.6,
	dynamicLights = true,
}

local function qualityConfig(tier: QualityTier): QualityConfig
	local map = VisualTheme.VFX.quality :: { [QualityTier]: QualityConfig }
	return map[tier] or DEFAULT_QUALITY
end

local function scaleParticles(baseCount: number): number
	if baseCount <= 0 then
		return 0
	end
	local scale = qualityConfig(currentTier).particleScale
	local scaled = math.floor(baseCount * scale + 0.5)
	return math.clamp(scaled, 1, VisualTheme.VFX.maxParticlesPerEmitter)
end

local function lightsEnabled(): boolean
	return qualityConfig(currentTier).dynamicLights
end

local function makePart(
	parent: Instance,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local piece = Instance.new("Part")
	piece.Size = size
	piece.Position = position
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanTouch = false
	piece.CanQuery = false
	piece.CastShadow = false
	piece.Material = material or Enum.Material.SmoothPlastic
	piece.Color = color
	if shape ~= nil then
		piece.Shape = shape
	end
	piece.Parent = parent
	return piece
end

local function makeAnchor(parent: Instance, position: Vector3, ttl: number, name: string?): Part
	local anchor =
		makePart(parent, Vector3.new(0.2, 0.2, 0.2), position, rgb(VisualTheme.PALETTE.stoneDark))
	anchor.Name = name or "VfxAnchor"
	anchor.Transparency = 1
	Debris:AddItem(anchor, ttl)
	return anchor
end

local function fadeAndDestroy(piece: BasePart, lifetime: number): ()
	TweenService:Create(
		piece,
		TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Transparency = 1 }
	):Play()
	Debris:AddItem(piece, lifetime + 0.05)
end

local function spawnLightFlash(
	parent: Instance,
	position: Vector3,
	color: Color3,
	brightness: number,
	range: number,
	duration: number
): PointLight?
	if not lightsEnabled() then
		return nil
	end
	local anchor = makeAnchor(parent, position, duration + 0.08, "VfxLightFlash")
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Enabled = true
	light.Parent = anchor
	TweenService:Create(
		light,
		TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Brightness = 0 }
	):Play()
	return light
end

local function attachEmitter(parent: Instance, spec: EmitterSpec): ParticleEmitter
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = spec.name or "VfxEmitter"
	emitter.Color = spec.color
	emitter.Size = spec.size
	emitter.Transparency = spec.transparency
	emitter.Lifetime = spec.lifetime
	emitter.Speed = spec.speed
	emitter.SpreadAngle = spec.spreadAngle or Vector2.new(45, 45)
	emitter.Acceleration = spec.acceleration or Vector3.new(0, 0, 0)
	emitter.Drag = spec.drag or 1
	emitter.LightEmission = spec.lightEmission or 0.4
	emitter.LightInfluence = 0.2
	emitter.EmissionDirection = spec.emissionDirection or Enum.NormalId.Top
	emitter.RotSpeed = spec.rotSpeed or NumberRange.new(-60, 60)

	local texture = spec.texture or ""
	if texture ~= "" then
		emitter.Texture = texture
		if spec.flipbookLayout ~= nil then
			emitter.FlipbookLayout = spec.flipbookLayout :: any
			emitter.FlipbookMode = (spec.flipbookMode or Enum.ParticleFlipbookMode.OneShot) :: any
			emitter.FlipbookFramerate = spec.flipbookFramerate
				or NumberRange.new(VfxAssets.FLIPBOOK.fps)
		end
	end
	if spec.orientation ~= nil then
		emitter.Orientation = spec.orientation :: any
	end
	if spec.squash ~= nil then
		emitter.Squash = spec.squash
	end
	if spec.zOffset ~= nil then
		emitter.ZOffset = spec.zOffset
	end

	local rate = spec.rate or 0
	if rate > 0 then
		emitter.Rate = scaleParticles(rate)
		emitter.Enabled = true
	else
		emitter.Rate = 0
		emitter.Enabled = false
	end

	emitter.Parent = parent

	if spec.burstCount ~= nil and spec.burstCount > 0 then
		emitter:Emit(scaleParticles(spec.burstCount))
	end

	if spec.activeSeconds ~= nil and spec.activeSeconds > 0 and rate > 0 then
		task.delay(spec.activeSeconds, function()
			if emitter.Parent ~= nil then
				emitter.Enabled = false
			end
		end)
	end

	return emitter
end

local function attachTrail(
	part: BasePart,
	color0: Color3,
	color1: Color3,
	width: number,
	lifetime: number,
	offset: number?
): Trail
	local span = offset or (width * 0.5)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, span, 0)
	a0.Parent = part
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -span, 0)
	a1.Parent = part

	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(color0, color1)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.WidthScale = NumberSequence.new(1, 0.1)
	trail.Lifetime = lifetime
	trail.LightEmission = 0.7
	trail.LightInfluence = 0.1
	trail.FaceCamera = true
	local trailTexture: string = VfxAssets.contentId("beamEnergyTrail")
	if trailTexture ~= "" then
		trail.Texture = trailTexture
		trail.TextureMode = Enum.TextureMode.Stretch
		trail.TextureLength = 1
	end
	trail.MinLength = 0.05
	trail.Enabled = true
	trail.Parent = part
	return trail
end

-- ===== Camada de texturas Forge3D (flipbooks 8x8/4x4, decals elementais, beams, ondas 3D). Sem ID publicado: fallback leve. =====
local function resolveFlipbookEnums(key: string): (EnumItem, EnumItem, number, number)
	local fb = VfxAssets.flipbookSpec(key)
	local layout: EnumItem = if fb.layout == "Grid8x8"
		then Enum.ParticleFlipbookLayout.Grid8x8
		else Enum.ParticleFlipbookLayout.Grid4x4
	local mode: EnumItem = if fb.mode == "Loop"
		then Enum.ParticleFlipbookMode.Loop
		else Enum.ParticleFlipbookMode.OneShot
	return layout, mode, fb.fps, fb.frames
end

local function flipbookEmitterSpec(
	key: string,
	name: string,
	color: Color3,
	sizeStart: number,
	sizeEnd: number,
	burst: number
): EmitterSpec
	local texture: string = VfxAssets.contentId(key)
	local white = Color3.new(1, 1, 1)
	if texture ~= "" then
		local layout, mode, fps, frames = resolveFlipbookEnums(key)
		return {
			name = name,
			texture = texture,
			flipbookLayout = layout,
			flipbookMode = mode,
			flipbookFramerate = NumberRange.new(fps),
			color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, white),
				ColorSequenceKeypoint.new(0.35, color:Lerp(white, 0.35)),
				ColorSequenceKeypoint.new(1, color),
			}),
			size = NumberSequence.new(sizeStart, sizeEnd),
			transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(0.75, 0.1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			lifetime = NumberRange.new(frames / fps),
			speed = NumberRange.new(0, 0.4),
			spreadAngle = Vector2.new(0, 0),
			drag = 1,
			lightEmission = 0.85,
			rotSpeed = NumberRange.new(0, 0),
			zOffset = 0.5,
			burstCount = burst,
		}
	end
	-- Fallback: um flare suave (softGlowFlare se publicado; senao partícula padrão).
	return {
		name = name .. "Glow",
		texture = VfxAssets.contentId("softGlowFlare"),
		color = ColorSequence.new(white, color),
		size = NumberSequence.new(sizeStart * 0.6, sizeEnd * 0.8),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		}),
		lifetime = NumberRange.new(0.18, 0.3),
		speed = NumberRange.new(0, 0.5),
		spreadAngle = Vector2.new(0, 0),
		lightEmission = 1,
		rotSpeed = NumberRange.new(0, 0),
		burstCount = 1,
	}
end

local function emitFlipbook(
	parent: Instance,
	key: string,
	position: Vector3,
	color: Color3,
	sizeStart: number,
	sizeEnd: number,
	burst: number?
): ()
	local fb = VfxAssets.flipbookSpec(key)
	local ttl = math.max(1.0, (fb.frames / fb.fps) + 0.25)
	local anchor = makeAnchor(parent, position, ttl, "VfxFlipbook")
	attachEmitter(
		anchor,
		flipbookEmitterSpec(key, "Flipbook", color, sizeStart, sizeEnd, burst or 2)
	)
end

local function attachFireLoopFlipbook(
	parent: Instance,
	color: Color3,
	sizeStart: number,
	sizeEnd: number,
	rate: number,
	activeSeconds: number,
	burst: number?
): ParticleEmitter
	local texture: string = VfxAssets.contentId("fireLoopFlipbook")
	local white = Color3.new(1, 1, 1)
	local layout, mode, fps, _frames = resolveFlipbookEnums("fireLoopFlipbook")
	local spec: EmitterSpec = {
		name = "FireLoopFlipbook",
		color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, white),
			ColorSequenceKeypoint.new(0.4, color),
			ColorSequenceKeypoint.new(1, rgb(VisualTheme.PALETTE.danger)),
		}),
		size = NumberSequence.new(sizeStart, sizeEnd),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.08),
			NumberSequenceKeypoint.new(0.75, 0.22),
			NumberSequenceKeypoint.new(1, 1),
		}),
		lifetime = NumberRange.new(0.55, 0.95),
		speed = NumberRange.new(1.5, 3.8),
		spreadAngle = Vector2.new(22, 22),
		acceleration = Vector3.new(0, 3.5, 0),
		drag = 1.5,
		lightEmission = 0.9,
		rotSpeed = NumberRange.new(-15, 15),
		zOffset = 0.35,
		rate = rate,
		activeSeconds = activeSeconds,
		burstCount = burst or 4,
	}
	if texture ~= "" then
		spec.texture = texture
		spec.flipbookLayout = layout
		spec.flipbookMode = mode
		spec.flipbookFramerate = NumberRange.new(fps)
	end
	return attachEmitter(parent, spec)
end

local function emitExplosion(parent: Instance, position: Vector3, color: Color3, scale: number?): ()
	local k = scale or 1
	emitFlipbook(parent, "explosionFlipbook", position, color, 2.4 * k, 5.2 * k, 2)
end

local function emitFrostShatter(
	parent: Instance,
	position: Vector3,
	color: Color3,
	scale: number?
): ()
	local k = scale or 1
	emitFlipbook(parent, "frostShatterFlipbook", position, color, 1.8 * k, 4.2 * k, 2)
end

local function emitArcaneRift(
	parent: Instance,
	position: Vector3,
	color: Color3,
	scale: number?
): ()
	local k = scale or 1
	emitFlipbook(parent, "arcaneRiftFlipbook", position, color, 2.0 * k, 4.6 * k, 2)
end

-- Faiscas/cortes alongados (Orientation VelocityParallel + Squash).
local function emitSlashSparks(
	parent: Instance,
	position: Vector3,
	color: Color3,
	burst: number?,
	direction: Enum.NormalId?
): ()
	local texture: string = VfxAssets.contentId("slashSparkFlipbook")
	local anchor = makeAnchor(parent, position, 0.8, "VfxSlashSparks")
	local spec: EmitterSpec = {
		name = "SlashSparks",
		color = ColorSequence.new(Color3.new(1, 1, 1), color),
		size = NumberSequence.new(0.5, 0.08),
		transparency = NumberSequence.new(0, 1),
		lifetime = NumberRange.new(0.18, 0.34),
		speed = NumberRange.new(10, 18),
		spreadAngle = Vector2.new(55, 55),
		emissionDirection = direction,
		drag = 2,
		lightEmission = 1,
		rotSpeed = NumberRange.new(0, 0),
		orientation = Enum.ParticleOrientation.VelocityParallel,
		squash = NumberSequence.new(-0.5, 0),
		burstCount = burst or 6,
	}
	if texture ~= "" then
		local layout, mode, fps, _frames = resolveFlipbookEnums("slashSparkFlipbook")
		spec.texture = texture
		spec.flipbookLayout = layout
		spec.flipbookMode = mode
		spec.flipbookFramerate = NumberRange.new(fps)
		spec.lifetime = NumberRange.new(0.3, 0.5)
		spec.speed = NumberRange.new(4, 9)
	end
	attachEmitter(anchor, spec)
end

-- Anel de choque texturizado deitado no chao (Orientation VelocityPerpendicular). Sem ID: nada.
local function emitRingTexture(
	parent: Instance,
	position: Vector3,
	color: Color3,
	endSize: number
): ()
	local texture: string = VfxAssets.contentId("shockwaveRing")
	if texture == "" then
		return
	end
	local anchor = makeAnchor(parent, position, 0.9, "VfxRingTexture")
	attachEmitter(anchor, {
		name = "ShockwaveRingTexture",
		texture = texture,
		color = ColorSequence.new(Color3.new(1, 1, 1), color),
		size = NumberSequence.new(0.8, endSize),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		}),
		lifetime = NumberRange.new(0.4, 0.45),
		speed = NumberRange.new(0.5, 0.5),
		spreadAngle = Vector2.new(0, 0),
		drag = 0,
		lightEmission = 0.9,
		rotSpeed = NumberRange.new(0, 0),
		orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		burstCount = 1,
	})
end

-- Placas de decal no chao (cratera, piche, geada). Apenas Mid/High; pool circular limita o custo.
local DECAL_POOL_MAX = 12
local groundDecalPlates: { BasePart } = {}

local function spawnGroundDecalPlate(
	parent: Instance,
	position: Vector3,
	radius: number,
	textureKey: string,
	plateName: string,
	decalName: string,
	fallbackColor: Color3,
	baseAlpha: number?
): ()
	if currentTier == "Low" then
		return
	end
	local alive: { BasePart } = {}
	for _, plate in ipairs(groundDecalPlates) do
		if plate.Parent ~= nil then
			alive[#alive + 1] = plate
		end
	end
	groundDecalPlates = alive
	while #groundDecalPlates >= DECAL_POOL_MAX do
		local oldest = table.remove(groundDecalPlates, 1)
		if oldest ~= nil then
			oldest:Destroy()
		end
	end

	local texture: string = VfxAssets.contentId(textureKey)
	local ttl = if currentTier == "High" then 4.5 else 3.0
	local plate = makePart(
		parent,
		Vector3.new(radius * 2, 0.04, radius * 2),
		position + Vector3.new(0, 0.07, 0),
		fallbackColor,
		Enum.Material.SmoothPlastic
	)
	plate.Name = plateName
	plate.CanCollide = false
	plate.CanTouch = false
	plate.CanQuery = false
	groundDecalPlates[#groundDecalPlates + 1] = plate
	if texture ~= "" then
		plate.Transparency = 1
		local decal = Instance.new("Decal")
		decal.Name = decalName
		decal.Texture = texture
		decal.Face = Enum.NormalId.Top
		decal.Transparency = baseAlpha or 0.1
		decal.Parent = plate
		TweenService:Create(
			decal,
			TweenInfo.new(ttl, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Transparency = 1 }
		):Play()
	else
		plate.Shape = Enum.PartType.Cylinder
		plate.Size = Vector3.new(0.04, radius * 2, radius * 2)
		plate.CFrame = CFrame.new(position + Vector3.new(0, 0.07, 0))
			* CFrame.Angles(0, 0, math.rad(90))
		plate.Transparency = 0.55
		TweenService:Create(
			plate,
			TweenInfo.new(ttl, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Transparency = 1 }
		):Play()
	end
	Debris:AddItem(plate, ttl + 0.1)
end

local function spawnScorchDecal(parent: Instance, position: Vector3, radius: number): ()
	spawnGroundDecalPlate(
		parent,
		position,
		radius,
		"scorchCraterDecal",
		"VfxScorchPlate",
		"ScorchDecal",
		rgb(VisualTheme.PALETTE.ink),
		0.1
	)
end

local function spawnTarPuddleDecal(parent: Instance, position: Vector3, radius: number): ()
	spawnGroundDecalPlate(
		parent,
		position,
		radius,
		"tarPuddleDecal",
		"VfxTarPuddlePlate",
		"TarPuddleDecal",
		rgb(VisualTheme.PALETTE.tarDark),
		0.08
	)
end

local function spawnFrostGroundDecal(parent: Instance, position: Vector3, radius: number): ()
	spawnGroundDecalPlate(
		parent,
		position,
		radius,
		"frostGroundDecal",
		"VfxFrostGroundPlate",
		"FrostGroundDecal",
		rgb(VisualTheme.PALETTE.frost),
		0.12
	)
end

local function spawnLightningArc(
	parent: Instance,
	fromPos: Vector3,
	toPos: Vector3,
	color0: Color3,
	color1: Color3,
	width: number?,
	duration: number?
): Part
	local ttl = duration or 0.26
	local anchor = makeAnchor(parent, fromPos, ttl + 0.08, "VfxLightningArc")
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.zero
	a0.Parent = anchor
	local a1 = Instance.new("Attachment")
	a1.Position = toPos - fromPos
	a1.Parent = anchor

	local beam = Instance.new("Beam")
	beam.Name = "LightningArcBeam"
	beam.Attachment0 = a0
	beam.Attachment1 = a1
	local tex: string = VfxAssets.contentId("lightningArcBeam")
	if tex ~= "" then
		beam.Texture = tex
		beam.TextureMode = Enum.TextureMode.Wrap
		beam.TextureLength = 1.6
		beam.TextureSpeed = 6
	end
	beam.Color = ColorSequence.new(color0, color1)
	local w = width or 0.65
	beam.Width0 = w
	beam.Width1 = w * 0.82
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = 6
	beam.CurveSize0 = 0.35
	beam.CurveSize1 = -0.35
	beam.Enabled = true
	beam.Parent = anchor
	return anchor
end

local function spawnVolumeWave(
	parent: Instance,
	position: Vector3,
	color: Color3,
	startRadius: number,
	endRadius: number,
	duration: number
): Part?
	if currentTier == "Low" then
		return nil
	end
	local wave = makePart(
		parent,
		Vector3.new(startRadius, startRadius * 0.72, startRadius),
		position,
		color,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	wave.Name = "VfxVolumeWave"
	wave.CanCollide = false
	wave.CanTouch = false
	wave.CanQuery = false
	wave.CastShadow = false
	wave.Transparency = 0.35
	TweenService
		:Create(wave, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(endRadius * 2, endRadius * 1.35, endRadius * 2),
			Transparency = 1,
		})
		:Play()
	Debris:AddItem(wave, duration + 0.05)
	return wave
end

local function moveCarrier(
	parent: Instance,
	from: Vector3,
	to: Vector3,
	travel: number,
	arcHeight: number,
	color0: Color3,
	color1: Color3,
	width: number,
	trailLife: number,
	onArrive: (() -> ())?
): Part
	local carrier = makeAnchor(parent, from, travel + trailLife + 0.25, "VfxTrailCarrier")
	attachTrail(carrier, color0, color1, width, trailLife)

	if arcHeight <= 0 then
		local tween = TweenService:Create(
			carrier,
			TweenInfo.new(travel, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
			{ Position = to }
		)
		tween.Completed:Once(function()
			if onArrive ~= nil and carrier.Parent ~= nil then
				onArrive()
			end
		end)
		tween:Play()
	elseif not IS_ROBLOX then
		task.delay(travel, function()
			if onArrive ~= nil and carrier.Parent ~= nil then
				onArrive()
			end
		end)
	else
		task.spawn(function()
			local started = time()
			while carrier.Parent ~= nil do
				local alpha = math.min((time() - started) / travel, 1)
				carrier.Position = from:Lerp(to, alpha)
					+ Vector3.new(0, math.sin(alpha * math.pi) * arcHeight, 0)
				if alpha >= 1 then
					break
				end
				RunService.Heartbeat:Wait()
			end
			if onArrive ~= nil and carrier.Parent ~= nil then
				onArrive()
			end
		end)
	end

	return carrier
end

local function applyF2Flags(part: BasePart, groupName: string): ()
	part.Anchored = false
	part.CanCollide = true
	part.CanQuery = VisualTheme.PHYSICS_F2.debrisCanQuery
	part.CanTouch = VisualTheme.PHYSICS_F2.debrisCanTouch
	part.CastShadow = false
	pcall(function()
		part.CollisionGroup = groupName
	end)
end

local function tierBudget(tier: QualityTier): (number, number)
	local tiers = VisualTheme.PHYSICS_F2.tiers :: { [QualityTier]: number }
	local maxBodies = tiers[tier] or 18
	local ttl = TIER_TTL[tier] or 2.0
	return maxBodies, ttl
end

local function pruneF2(now: number, reserve: number): ()
	local maxBodies = tierBudget(currentTier)
	local kept: { F2Entry } = {}
	for _, entry in ipairs(activeF2) do
		if entry.instance.Parent ~= nil and now < entry.expiresAt then
			kept[#kept + 1] = entry
		end
	end
	activeF2 = kept
	while #activeF2 + reserve > maxBodies and #activeF2 > 0 do
		local oldest = table.remove(activeF2, 1)
		if oldest ~= nil and oldest.instance.Parent ~= nil then
			oldest.instance:Destroy()
		end
	end
end

local function trackF2(inst: Instance, ttl: number): ()
	local now = time()
	activeF2[#activeF2 + 1] = {
		instance = inst,
		expiresAt = now + ttl,
	}
	Debris:AddItem(inst, ttl + 0.05)
end

function Vfx.configureCollisionGroups(): ()
	if collisionGroupsConfigured then
		return
	end
	collisionGroupsConfigured = true
	local groups = { "ArenaStatic", "LiveProxy", "RagdollBody", "FractureDebris", "RaycastGrid" }
	for _, g in ipairs(groups) do
		pcall(function()
			PhysicsService:RegisterCollisionGroup(g)
		end)
	end
	for _, a in ipairs(groups) do
		for _, b in ipairs(groups) do
			pcall(function()
				PhysicsService:CollisionGroupSetCollidable(a, b, false)
			end)
		end
	end
	pcall(function()
		PhysicsService:CollisionGroupSetCollidable("RagdollBody", "ArenaStatic", true)
		PhysicsService:CollisionGroupSetCollidable("RagdollBody", "FractureDebris", true)
		PhysicsService:CollisionGroupSetCollidable("FractureDebris", "ArenaStatic", true)
		PhysicsService:CollisionGroupSetCollidable("FractureDebris", "FractureDebris", true)
	end)
end

function Vfx.getQualityTier(): QualityTier
	return currentTier
end

function Vfx.setQualityTier(tier: QualityTier): ()
	currentTier = tier
	lowFpsSeconds = 0
	pruneF2(time(), 0)
end

function Vfx.stepGovernor(dt: number): QualityTier
	if dt <= 0 then
		return currentTier
	end
	local fps = 1 / dt
	if fps < 48 then
		lowFpsSeconds += dt
		if lowFpsSeconds >= 2.0 then
			if currentTier == "High" then
				currentTier = "Mid"
				lowFpsSeconds = 0
			elseif currentTier == "Mid" then
				currentTier = "Low"
				lowFpsSeconds = 0
			end
		end
	else
		lowFpsSeconds = math.max(0, lowFpsSeconds - dt * 0.5)
	end
	return currentTier
end

local function ensureGovernor(): ()
	if governorConn ~= nil then
		return
	end
	governorConn = RunService.RenderStepped:Connect(function(dt: number)
		Vfx.stepGovernor(dt)
	end)
end

function Vfx.impact(parent: Instance, position: Vector3, color: Color3, count: number?): ()
	local rawTotal = math.min(count or 6, VisualTheme.VFX.maxImpactParts)
	local total = scaleParticles(rawTotal)
	local anchor = makeAnchor(parent, position, VisualTheme.VFX.impactLifetime + 0.35, "VfxImpact")
	attachEmitter(anchor, {
		name = "ImpactBurst",
		texture = VfxAssets.contentId("softGlowFlare"),
		color = ColorSequence.new(color, rgb(VisualTheme.PALETTE.white)),
		size = NumberSequence.new(0.28, 0.04),
		transparency = NumberSequence.new(0.05, 1),
		lifetime = NumberRange.new(0.25, VisualTheme.VFX.impactLifetime),
		speed = NumberRange.new(5, 11),
		spreadAngle = Vector2.new(85, 85),
		acceleration = Vector3.new(0, -18, 0),
		lightEmission = 0.8,
		burstCount = rawTotal * 2,
	})
	spawnLightFlash(parent, position, color, 1.8, 7, 0.16)
	if currentTier ~= "Low" then
		emitSlashSparks(parent, position, color, math.min(rawTotal, 4))
	end

	for index = 1, total do
		local piece = makePart(
			parent,
			Vector3.new(0.18, 0.18, 0.18),
			position,
			color,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		local angle = (index / total) * math.pi * 2
		local distance = 1.2 + (index % 3) * 0.5
		local target = position
			+ Vector3.new(
				math.cos(angle) * distance,
				1.1 + (index % 2) * 0.7,
				math.sin(angle) * distance
			)
		TweenService:Create(
			piece,
			TweenInfo.new(
				VisualTheme.VFX.impactLifetime,
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.Out
			),
			{ Position = target, Size = Vector3.new(0.04, 0.04, 0.04) }
		):Play()
		fadeAndDestroy(piece, VisualTheme.VFX.impactLifetime)
	end
end

function Vfx.dust(parent: Instance, position: Vector3, count: number?): ()
	local rawTotal = math.min(count or 6, VisualTheme.VFX.maxDustParts)
	local total = scaleParticles(rawTotal)
	local stone = rgb(VisualTheme.PALETTE.stone)
	local anchor = makeAnchor(parent, position, 1.1, "VfxDust")
	attachEmitter(anchor, {
		name = "DustCloud",
		texture = VfxAssets.contentId("smokeWispy"),
		color = ColorSequence.new(stone, rgb(VisualTheme.PALETTE.stoneDark)),
		size = NumberSequence.new(0.45, 1.4),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
		lifetime = NumberRange.new(0.45, 0.8),
		speed = NumberRange.new(2, 5),
		spreadAngle = Vector2.new(75, 75),
		acceleration = Vector3.new(0, 2.5, 0),
		drag = 3,
		lightEmission = 0,
		burstCount = rawTotal * 2,
	})

	for index = 1, total do
		local piece = makePart(
			parent,
			Vector3.new(0.35, 0.35, 0.35),
			position + Vector3.new((index % 3) - 1, 0.2, ((index + 1) % 3) - 1) * 0.6,
			stone,
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
		piece.Transparency = 0.35
		local target = piece.Position + Vector3.new((index % 3) - 1, 1.2 + (index % 2) * 0.6, 0)
		TweenService:Create(
			piece,
			TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Position = target, Size = Vector3.new(1.1, 1.1, 1.1) }
		):Play()
		fadeAndDestroy(piece, 0.7)
	end
end

local function makeWedge(
	parent: Instance,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?
): WedgePart
	local piece = Instance.new("WedgePart")
	piece.Size = size
	piece.Position = position
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanTouch = false
	piece.CanQuery = false
	piece.CastShadow = false
	piece.Material = material or Enum.Material.SmoothPlastic
	piece.Color = color
	piece.Parent = parent
	return piece
end

local function spawnShockwaveRing(
	parent: Instance,
	position: Vector3,
	color: Color3,
	startDiam: number,
	endDiam: number,
	thickness: number,
	duration: number,
	extraTilt: CFrame?
): Part
	local ring = makePart(
		parent,
		Vector3.new(thickness, startDiam, startDiam),
		position,
		color,
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	ring.Name = "VfxShockwaveRing"
	ring.Transparency = 0.12
	local baseTilt = CFrame.Angles(0, 0, math.rad(90))
	ring.CFrame = CFrame.new(position)
		* (if extraTilt ~= nil then extraTilt * baseTilt else baseTilt)
	TweenService
		:Create(ring, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(math.max(0.05, thickness * 0.5), endDiam, endDiam),
			Transparency = 1,
		})
		:Play()
	Debris:AddItem(ring, duration + 0.05)
	emitRingTexture(parent, position, color, endDiam)
	return ring
end

local function triggerCameraImpulse(intensity: number, duration: number, fovDelta: number): ()
	local now = time()
	local prevRemaining = math.max(0, (camImpulseStart + camImpulseDuration) - now)
	if duration >= prevRemaining or intensity >= camImpulseIntensity then
		camImpulseStart = now
		camImpulseDuration = duration
		camImpulseIntensity = intensity
		camImpulseFovDelta = fovDelta
	end
	task.defer(function()
		if camImpulseSampledAt < camImpulseStart then
			local cam = Workspace.CurrentCamera
			if cam ~= nil then
				Vfx.shake(cam, cam.CFrame, intensity, duration)
			end
		end
	end)
end

local function sanitizeClonedVisualPart(part: BasePart): BasePart
	for _, child in ipairs(part:GetChildren()) do
		local cls = child.ClassName
		if
			cls == "WeldConstraint"
			or cls == "Motor6D"
			or cls == "Weld"
			or cls == "BillboardGui"
			or cls == "Trail"
		then
			child:Destroy()
		end
	end
	return part
end

local function computePartsBounds(parts: { BasePart }): (Vector3, Vector3)
	if #parts == 0 then
		return Vector3.zero, Vector3.one
	end
	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge
	for _, part in ipairs(parts) do
		local cf = part.CFrame
		local pos = cf.Position
		local half = part.Size * 0.5
		local right = cf.RightVector
		local up = cf.UpVector
		local back = -cf.LookVector
		local ex = math.abs(right.X) * half.X + math.abs(up.X) * half.Y + math.abs(back.X) * half.Z
		local ey = math.abs(right.Y) * half.X + math.abs(up.Y) * half.Y + math.abs(back.Y) * half.Z
		local ez = math.abs(right.Z) * half.X + math.abs(up.Z) * half.Y + math.abs(back.Z) * half.Z
		if pos.X - ex < minX then
			minX = pos.X - ex
		end
		if pos.X + ex > maxX then
			maxX = pos.X + ex
		end
		if pos.Y - ey < minY then
			minY = pos.Y - ey
		end
		if pos.Y + ey > maxY then
			maxY = pos.Y + ey
		end
		if pos.Z - ez < minZ then
			minZ = pos.Z - ez
		end
		if pos.Z + ez > maxZ then
			maxZ = pos.Z + ez
		end
	end
	local center = Vector3.new((minX + maxX) * 0.5, (minY + maxY) * 0.5, (minZ + maxZ) * 0.5)
	local size = Vector3.new(
		math.max(0.1, maxX - minX),
		math.max(0.1, maxY - minY),
		math.max(0.1, maxZ - minZ)
	)
	return center, size
end

local function resolveRagdollVisualParts(
	sourceModel: Model?,
	archetype: string,
	spawnOrigin: Vector3
): { BasePart }
	local parts: { BasePart } = {}

	-- 1) Live MeshVisual from sourceModel (preserves live scale, pose, and PBR SurfaceAppearance)
	if sourceModel ~= nil then
		local meshVisual = sourceModel:FindFirstChild("MeshVisual")
		if meshVisual ~= nil then
			if meshVisual:IsA("BasePart") and not meshVisual:IsA("WedgePart") then
				local cloned = sanitizeClonedVisualPart(meshVisual:Clone())
				if cloned.Transparency >= 0.99 then
					cloned.Transparency = 0
				end
				parts[#parts + 1] = cloned
				return parts
			else
				local clonedContainer = meshVisual:Clone()
				for _, desc in ipairs(clonedContainer:GetDescendants()) do
					if desc:IsA("BasePart") and not desc:IsA("WedgePart") then
						desc.Parent = nil
						sanitizeClonedVisualPart(desc)
						if desc.Transparency >= 0.99 then
							desc.Transparency = 0
						end
						parts[#parts + 1] = desc
					end
				end
				clonedContainer:Destroy()
				if #parts > 0 then
					return parts
				end
			end
		end
	end

	-- 2) ReplicatedStorage.MuralhaAssets template CMD_<archetype>
	local assetsFolder = ReplicatedStorage:FindFirstChild("MuralhaAssets")
	local assetName = "CMD_" .. archetype
	local template = if assetsFolder ~= nil then assetsFolder:FindFirstChild(assetName) else nil
	if template ~= nil then
		local enemySpec = (VisualTheme.ENEMIES :: any)[archetype]
		local targetH = if enemySpec ~= nil and type(enemySpec.height) == "number"
			then enemySpec.height
			elseif enemySpec ~= nil and type(enemySpec.scale) == "number" then enemySpec.scale * 3.8
			else 3.4
		local tplClone = template:Clone()
		PbrAssets.reapply(tplClone, assetName)
		if tplClone:IsA("BasePart") and not tplClone:IsA("WedgePart") then
			sanitizeClonedVisualPart(tplClone)
			if tplClone.Size.Y > 0.05 then
				tplClone.Size = tplClone.Size * (targetH / tplClone.Size.Y)
			end
			tplClone.CFrame =
				CFrame.new(spawnOrigin + Vector3.new(0, tplClone.Size.Y * 0.5 + 0.16, 0))
			tplClone.Transparency = 0
			parts[#parts + 1] = tplClone
			return parts
		else
			for _, desc in ipairs(tplClone:GetDescendants()) do
				if desc:IsA("BasePart") and not desc:IsA("WedgePart") then
					desc.Parent = nil
					sanitizeClonedVisualPart(desc)
					desc.Transparency = 0
					parts[#parts + 1] = desc
				end
			end
			tplClone:Destroy()
			if #parts > 0 then
				local rawCenter, rawSize = computePartsBounds(parts)
				local scaleFactor = if rawSize.Y > 0.05 then targetH / rawSize.Y else 1
				for _, part in ipairs(parts) do
					local rel = (part.Position - rawCenter) * scaleFactor
					part.Size = part.Size * scaleFactor
					part.CFrame = CFrame.new(spawnOrigin + rel) * part.CFrame.Rotation
				end
				return parts
			end
		end
	end

	-- 3) Visible non-RootPart / non-ChampionCrest BasePart descendants from sourceModel
	if sourceModel ~= nil then
		for _, desc in ipairs(sourceModel:GetDescendants()) do
			if
				desc:IsA("BasePart")
				and not desc:IsA("WedgePart")
				and desc.Name ~= "RootPart"
				and desc.Name ~= "ChampionCrest"
				and desc.Transparency < 0.95
			then
				local cloned = sanitizeClonedVisualPart(desc:Clone())
				parts[#parts + 1] = cloned
			end
		end
	end

	return parts
end

function Vfx.death(parent: Instance, position: Vector3, color: Color3, isFrozen: boolean?): ()
	local frozen = isFrozen == true
	local frostBright = rgb(VisualTheme.PALETTE.frostBright)
	local white = rgb(VisualTheme.PALETTE.white)
	local burstColor = if frozen then frostBright else color

	Vfx.impact(parent, position + Vector3.new(0, 0.8, 0), burstColor, 5)
	Vfx.dust(parent, position, 3)
	if frozen then
		emitFrostShatter(parent, position + Vector3.new(0, 0.8, 0), color, 1.0)
		spawnFrostGroundDecal(parent, position, 1.8)
	else
		local glowAnchor =
			makeAnchor(parent, position + Vector3.new(0, 0.8, 0), 0.7, "VfxDeathGlow")
		attachEmitter(glowAnchor, {
			name = "DeathGlow",
			texture = VfxAssets.contentId("softGlowFlare"),
			color = ColorSequence.new(white, color),
			size = NumberSequence.new(1.2, 2.6),
			transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.25),
				NumberSequenceKeypoint.new(1, 1),
			}),
			lifetime = NumberRange.new(0.2, 0.35),
			speed = NumberRange.new(0, 0),
			spreadAngle = Vector2.new(0, 0),
			lightEmission = 1,
			rotSpeed = NumberRange.new(0, 0),
			burstCount = 1,
		})
		if VfxAssets.contentId("smokeWispy") ~= "" then
			attachEmitter(glowAnchor, {
				name = "DeathSmoke",
				texture = VfxAssets.contentId("smokeWispy"),
				color = ColorSequence.new(
					color:Lerp(white, 0.3),
					rgb(VisualTheme.PALETTE.stoneDark)
				),
				size = NumberSequence.new(0.9, 2.2),
				transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.4),
					NumberSequenceKeypoint.new(1, 1),
				}),
				lifetime = NumberRange.new(0.4, 0.7),
				speed = NumberRange.new(1, 3),
				spreadAngle = Vector2.new(60, 60),
				acceleration = Vector3.new(0, 2, 0),
				drag = 2,
				lightEmission = 0,
				burstCount = 3,
			})
		end
	end

	-- Expanding ground shockwave ring
	spawnShockwaveRing(
		parent,
		position + Vector3.new(0, 0.34, 0),
		burstColor,
		0.95,
		5.4,
		0.11,
		0.32
	)

	-- Brief bright core flash
	local flashOrb = makePart(
		parent,
		Vector3.new(0.55, 0.55, 0.55),
		position + Vector3.new(0, 0.9, 0),
		white,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	flashOrb.Name = "VfxDeathFlash"
	flashOrb.Transparency = 0.12
	TweenService:Create(
		flashOrb,
		TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(1.45, 1.45, 1.45), Transparency = 1 }
	):Play()
	Debris:AddItem(flashOrb, 0.19)
	spawnLightFlash(parent, position + Vector3.new(0, 0.95, 0), burstColor, 2.6, 9, 0.14)

	-- <= 6 directional spark streaks
	local streakCount = math.min(6, VisualTheme.VFX.maxImpactParts, scaleParticles(6))
	local origin = position + Vector3.new(0, 0.85, 0)
	for index = 1, streakCount do
		local angle = ((index - 1) / math.max(1, streakCount)) * math.pi * 2 + 0.35
		local reach = 1.85 + (index % 2) * 0.75
		local target = origin
			+ Vector3.new(
				math.cos(angle) * reach + 0.65,
				0.85 + (index % 3) * 0.45,
				math.sin(angle) * reach
			)
		local streak = makePart(
			parent,
			Vector3.new(0.08, 0.08, 0.68),
			origin,
			if index % 2 == 0 then white else burstColor,
			Enum.Material.Neon
		)
		streak.Name = "VfxDeathStreak"
		streak.CFrame = CFrame.lookAt(origin, target)
		TweenService
			:Create(streak, TweenInfo.new(0.24, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = CFrame.lookAt(target, target + (target - origin)),
				Size = Vector3.new(0.02, 0.02, 0.16),
				Transparency = 1,
			})
			:Play()
		Debris:AddItem(streak, 0.29)
	end
end

function Vfx.ragdollEnemy(
	parent: Instance,
	position: Vector3,
	color: Color3,
	impulse: Vector3?,
	kind: string?,
	sourceModel: Model?,
	isFrozen: boolean?
): ()
	Vfx.configureCollisionGroups()
	ensureGovernor()
	local maxBodies, ttl = tierBudget(currentTier)
	if maxBodies <= 0 then
		return
	end
	pruneF2(time(), 1)

	local archetype = kind or "runner"
	local frozen = isFrozen == true
	local rawDir = impulse or Vector3.new(12, 14.5, 2.5)
	local baseX = math.max(math.abs(rawDir.X), 9.5)
	local baseY = math.max(rawDir.Y, 11.5)
	local baseZ = if math.abs(rawDir.Z) > 0.2 then rawDir.Z else 2.6

	local isAerial = archetype == "drake" or archetype == "wisp"
	local spawnOrigin = if isAerial and position.Y < 2.0
		then position + Vector3.new(0, VisualTheme.AERIAL.hoverY, 0)
		else position

	local density = 1.0
	local friction = if frozen then 0.22 else 0.45
	local elasticity = if frozen then 0.32 else 0.25
	local launchDir = Vector3.new(baseX * 1.35, baseY * 1.18 + 2.0, baseZ * 1.15)
	local spinDir = Vector3.new(7, 4, -11)

	if archetype == "wisp" or archetype == "pyromancer" then
		density = 0.45
		friction = 0.25
		elasticity = 0.5
		launchDir = Vector3.new(baseX * 1.05, baseY * 0.92 + 3.4, baseZ * 1.15)
		spinDir = Vector3.new(7, 11, -9)
	elseif archetype == "sapper" then
		density = 0.85
		friction = 0.35
		elasticity = 0.35
		launchDir = Vector3.new(baseX * 1.65 + 4.0, baseY * 1.38 + 4.5, baseZ * 1.45)
		spinDir = Vector3.new(14, 9, -16)
	elseif archetype == "brute" or archetype == "shieldbearer" then
		density = 2.35
		launchDir = Vector3.new(baseX * 1.25 + 2.5, baseY * 1.05 + 1.5, baseZ)
		spinDir = Vector3.new(5.5, 3.5, -8.5)
	elseif archetype == "swarm" then
		density = 0.55
		launchDir = Vector3.new(baseX * 1.48 + 3.0, baseY * 1.42 + 4.5, baseZ * 1.45)
		spinDir = Vector3.new(13, 9, -17)
	elseif archetype == "drake" then
		density = 1.45
		launchDir = Vector3.new(baseX * 1.38 + 2.5, baseY * 0.92 + 2.0, baseZ * 1.35)
		spinDir = Vector3.new(10, 7, -14)
	end
	if frozen then
		launchDir = Vector3.new(launchDir.X * 1.12, launchDir.Y * 1.05 + 1.2, launchDir.Z * 1.1)
		spinDir = spinDir * 1.15
	end

	local visualParts = resolveRagdollVisualParts(sourceModel, archetype, spawnOrigin)
	local ragdoll = Instance.new("Model")
	ragdoll.Name = "F2_Ragdoll_" .. archetype

	if #visualParts == 0 then
		-- Headless CLI fallback (only when zero real visual parts exist anywhere):
		-- invisible physics driver, zero visible square blocks or wedges/cones.
		if archetype == "wisp" or archetype == "pyromancer" then
			emitArcaneRift(parent, spawnOrigin + Vector3.new(0, 0.9, 0), color, 0.7)
		elseif archetype == "sapper" then
			emitExplosion(parent, spawnOrigin + Vector3.new(0, 0.8, 0), color, 0.55)
		end
		if frozen then
			emitFrostShatter(
				parent,
				spawnOrigin + Vector3.new(0, 0.8, 0),
				rgb(VisualTheme.PALETTE.frostBright),
				0.85
			)
		end
		local driver = makePart(
			ragdoll,
			Vector3.new(1.0, 1.2, 0.9),
			spawnOrigin + Vector3.new(0, 0.8, 0),
			color
		)
		driver.Name = "RagdollDriver"
		driver.Transparency = 1
		driver.CustomPhysicalProperties =
			PhysicalProperties.new(density, friction, elasticity, 1, 1)
		applyF2Flags(driver, "RagdollBody")
		driver.CanQuery = false
		driver.CanTouch = false
		ragdoll.PrimaryPart = driver
		ragdoll.Parent = parent
		local mass = if driver.AssemblyMass > 0 then driver.AssemblyMass else 1
		driver:ApplyImpulse(launchDir * mass)
		driver:ApplyAngularImpulse(spinDir * mass)
		local fallbackTtl = if frozen
			then math.min(ttl, 0.75)
			elseif archetype == "wisp" or archetype == "pyromancer" then math.min(ttl, 0.75)
			else ttl
		trackF2(ragdoll, fallbackTtl)
		return
	end

	local bbCenter, bbSize = computePartsBounds(visualParts)
	local driverSize = Vector3.new(
		math.clamp(bbSize.X, 0.6, 2.2),
		math.clamp(bbSize.Y, 0.6, 2.4),
		math.clamp(bbSize.Z, 0.6, 2.2)
	)
	local targetCenter = spawnOrigin
		+ Vector3.new(0, math.max(driverSize.Y, bbSize.Y) * 0.5 + 0.16, 0)
	local delta = targetCenter - bbCenter

	local driver = makePart(ragdoll, driverSize, targetCenter, color)
	driver.Name = "RagdollDriver"
	driver.Transparency = 1
	driver.CustomPhysicalProperties = PhysicalProperties.new(density, friction, elasticity, 1, 1)
	applyF2Flags(driver, "RagdollBody")
	driver.CanQuery = false
	driver.CanTouch = false

	for _, part in ipairs(visualParts) do
		part.CFrame = part.CFrame + delta
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = false
		pcall(function()
			part.CollisionGroup = "RagdollBody"
		end)
		part.Parent = ragdoll
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = driver
		weld.Part1 = part
		weld.Parent = driver
	end

	if archetype == "drake" then
		attachTrail(driver, rgb(VisualTheme.PALETTE.amberBright), color, 0.36, 0.22)
	elseif archetype == "wisp" or archetype == "pyromancer" then
		attachTrail(driver, Color3.fromRGB(165, 243, 252), color, 0.38, 0.24)
	end

	ragdoll.PrimaryPart = driver
	ragdoll.Parent = parent

	-- Brief hit-flash Highlight (0.14s white or icy cyan if frozen, Occluded)
	local okHl, rawHl: any = pcall(Instance.new, "Highlight")
	if okHl and rawHl ~= nil then
		local hl: any = rawHl
		local flashColor = if frozen
			then rgb(VisualTheme.PALETTE.frostBright)
			else rgb(VisualTheme.PALETTE.white)
		pcall(function()
			hl.Name = "HitFlashHighlight"
			hl.Adornee = ragdoll
			hl.DepthMode = Enum.HighlightDepthMode.Occluded
			hl.FillColor = flashColor
			hl.OutlineColor = flashColor
			hl.FillTransparency = 0.25
			hl.OutlineTransparency = 0.4
			hl.Parent = ragdoll
			TweenService:Create(
				hl,
				TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ FillTransparency = 1, OutlineTransparency = 1 }
			):Play()
			Debris:AddItem(hl, 0.2)
		end)
	end

	local mass = if driver.AssemblyMass > 0 then driver.AssemblyMass else 1
	driver:ApplyImpulse(launchDir * mass)
	driver:ApplyAngularImpulse(spinDir * mass)

	local effectiveTtl = ttl
	if archetype == "wisp" or archetype == "pyromancer" then
		emitArcaneRift(parent, spawnOrigin + Vector3.new(0, 0.9, 0), color, 0.75)
		if frozen then
			emitFrostShatter(
				parent,
				spawnOrigin + Vector3.new(0, 0.8, 0),
				rgb(VisualTheme.PALETTE.frostBright),
				0.85
			)
		end
		effectiveTtl = math.min(ttl, 0.75)
		for _, part in ipairs(visualParts) do
			TweenService:Create(
				part,
				TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Transparency = 1 }
			):Play()
		end
	else
		if archetype == "sapper" then
			emitExplosion(parent, spawnOrigin + Vector3.new(0, 0.8, 0), color, 0.55)
		end
		if frozen then
			emitFrostShatter(
				parent,
				spawnOrigin + Vector3.new(0, 0.8, 0),
				rgb(VisualTheme.PALETTE.frostBright),
				0.85
			)
			effectiveTtl = math.min(ttl, 0.75)
		end
		local dissolveDur = 0.45
		local dissolveDelay = math.max(0.05, effectiveTtl - dissolveDur)
		task.delay(dissolveDelay, function()
			if ragdoll.Parent == nil then
				return
			end
			for _, part in ipairs(visualParts) do
				if part.Parent ~= nil then
					TweenService
						:Create(
							part,
							TweenInfo.new(
								dissolveDur,
								Enum.EasingStyle.Quad,
								Enum.EasingDirection.Out
							),
							{ Transparency = 1 }
						)
						:Play()
				end
			end
		end)
	end

	trackF2(ragdoll, effectiveTtl)
end

function Vfx.championDeath(
	parent: Instance,
	position: Vector3,
	haloColor: Color3?,
	accentColor: Color3?
): ()
	local gold = haloColor or rgb(VisualTheme.CHAMPION.haloColor)
	local teal = accentColor or rgb(VisualTheme.CHAMPION.accentColor)
	local white = rgb(VisualTheme.PALETTE.white)

	emitSlashSparks(parent, position + Vector3.new(0, 1.2, 0), gold, 14)
	emitSlashSparks(parent, position + Vector3.new(0, 1.0, 0), teal, 8, Enum.NormalId.Right)
	spawnLightningArc(
		parent,
		position + Vector3.new(0, 0.4, 0),
		position + Vector3.new(1.8, 5.2, 1.1),
		white,
		gold,
		0.65,
		0.32
	)
	spawnLightningArc(
		parent,
		position + Vector3.new(0, 0.4, 0),
		position + Vector3.new(-1.6, 4.8, -1.2),
		white,
		teal,
		0.55,
		0.28
	)

	-- Dual golden/teal shockwave rings
	spawnShockwaveRing(parent, position + Vector3.new(0, 0.42, 0), gold, 1.25, 9.6, 0.16, 0.42)
	spawnShockwaveRing(
		parent,
		position + Vector3.new(0, 0.72, 0),
		teal,
		0.95,
		7.4,
		0.14,
		0.34,
		CFrame.Angles(math.rad(14), 0, math.rad(-10))
	)

	-- Vertical energy flare
	local flareCenter = position + Vector3.new(0, 4.4, 0)
	local flare = makePart(
		parent,
		Vector3.new(8.8, 1.35, 1.35),
		flareCenter,
		gold,
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	flare.Name = "VfxChampionFlare"
	flare.Transparency = 0.12
	flare.CFrame = CFrame.new(flareCenter) * CFrame.Angles(0, 0, math.rad(90))
	TweenService
		:Create(flare, TweenInfo.new(0.36, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(12.2, 0.08, 0.08),
			Transparency = 1,
		})
		:Play()
	Debris:AddItem(flare, 0.41)

	local burstAnchor =
		makeAnchor(parent, position + Vector3.new(0, 1.2, 0), 0.75, "VfxChampionBurst")
	attachEmitter(burstAnchor, {
		name = "ChampionCrestSparks",
		color = ColorSequence.new(white, gold),
		size = NumberSequence.new(0.34, 0.05),
		transparency = NumberSequence.new(0, 1),
		lifetime = NumberRange.new(0.24, 0.52),
		speed = NumberRange.new(9, 18),
		spreadAngle = Vector2.new(80, 80),
		acceleration = Vector3.new(0, -16, 0),
		lightEmission = 0.95,
		burstCount = 22,
	})
	spawnLightFlash(parent, position + Vector3.new(0, 1.6, 0), gold, 3.4, 14, 0.24)

	-- 4 shattered golden crest shards (FractureDebris)
	Vfx.configureCollisionGroups()
	ensureGovernor()
	local maxBodies, ttl = tierBudget(currentTier)
	local shardCount = math.min(4, maxBodies)
	if shardCount > 0 then
		pruneF2(time(), shardCount)
		local shardTtl = math.min(ttl, 1.6)
		for idx = 1, shardCount do
			local ang = ((idx - 1) / shardCount) * math.pi * 2 + math.pi * 0.25
			local spawnPos = position + Vector3.new(math.cos(ang) * 0.45, 2.1, math.sin(ang) * 0.45)
			local shard = makeWedge(
				parent,
				Vector3.new(0.28, 0.68, 0.42),
				spawnPos,
				if idx % 2 == 0 then gold else rgb(VisualTheme.PALETTE.amber),
				Enum.Material.Neon
			)
			shard.Name = "F2_ChampionCrestShard_" .. tostring(idx)
			applyF2Flags(shard, "FractureDebris")
			local vel =
				Vector3.new(math.cos(ang) * 7.5 + 2.5, 15.0 + (idx % 2) * 3.0, math.sin(ang) * 7.5)
			shard:ApplyImpulse(vel * shard.AssemblyMass)
			shard:ApplyAngularImpulse(Vector3.new(10, -8 + idx * 4, 12) * shard.AssemblyMass)
			trackF2(shard, shardTtl)
		end
	end

	-- 0.14s camera punch
	triggerCameraImpulse(0.28, 0.14, -2.2)
end

function Vfx.fractureGate(parent: Instance, position: Vector3, impulseDir: Vector3?): ()
	Vfx.configureCollisionGroups()
	ensureGovernor()
	local maxBodies, ttl = tierBudget(currentTier)
	local desiredChunks = VisualTheme.PHYSICS_F2.gateChunks
	local count = if currentTier == "Low"
		then math.min(6, maxBodies)
		else math.min(desiredChunks, maxBodies)
	if count <= 0 then
		return
	end
	pruneF2(time(), count)

	local baseImpulse = impulseDir or Vector3.new(-16, 12, 0)
	for index = 1, count do
		local row = math.floor((index - 1) / 3)
		local col = (index - 1) % 3
		local offset = Vector3.new(0, (row - 1.5) * 1.1, (col - 1) * 2.2)
		local isIron = index % 4 == 0
		local chunk = makePart(
			parent,
			Vector3.new(1.1, 1.0, 1.8),
			position + offset,
			if isIron then rgb(VisualTheme.PALETTE.iron) else rgb(VisualTheme.PALETTE.woodDark),
			if isIron then Enum.Material.Metal else Enum.Material.WoodPlanks
		)
		chunk.Name = "F2_GateChunk_" .. tostring(index)
		applyF2Flags(chunk, "FractureDebris")
		local scatter = Vector3.new(
			baseImpulse.X - (index % 3) * 3,
			baseImpulse.Y + (row * 2.5),
			baseImpulse.Z + (col - 1) * 6
		)
		chunk:ApplyImpulse(scatter * chunk.AssemblyMass)
		chunk:ApplyAngularImpulse(Vector3.new((col - 1) * 5, (row - 1) * 4, 6) * chunk.AssemblyMass)
		trackF2(chunk, ttl)
	end
end

function Vfx.ring(parent: Instance, position: Vector3, color: Color3): ()
	local ring = makePart(
		parent,
		Vector3.new(0.12, 1.0, 1.0),
		position + Vector3.new(0, 0.4, 0),
		color,
		Enum.Material.Neon,
		Enum.PartType.Cylinder
	)
	ring.CFrame = ring.CFrame * CFrame.Angles(0, 0, math.rad(90))
	TweenService:Create(
		ring,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.12, 7, 7), Transparency = 1 }
	):Play()
	Debris:AddItem(ring, 0.5)
	emitRingTexture(parent, position + Vector3.new(0, 0.4, 0), color, 7)
end

local function spawnBreachEllipse(
	parent: Instance,
	center: Vector3,
	color: Color3,
	startSpan: number,
	endSpan: number,
	duration: number
): ()
	local disc = makePart(
		parent,
		Vector3.new(0.24, startSpan * 1.25, startSpan * 0.88),
		center,
		color,
		Enum.Material.Neon
	)
	disc.Name = "VfxPortalBreach"
	disc.Transparency = 0.15
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = disc

	TweenService
		:Create(disc, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(0.12, endSpan * 1.25, endSpan * 0.88),
			Transparency = 1,
		})
		:Play()
	Debris:AddItem(disc, duration + 0.05)
end

function Vfx.portalBreach(
	parent: Instance,
	worldPos: Vector3,
	veilColor: Color3,
	accentColor: Color3,
	isBoss: boolean?
): ()
	local boss = isBoss == true
	local now = time()
	if not boss then
		if now - lastPortalBreachAt < PORTAL_BREACH_COOLDOWN then
			return
		end
		lastPortalBreachAt = now
	end

	local center =
		Vector3.new(worldPos.X + 0.35, worldPos.Y + (if boss then 4.5 else 2.2), worldPos.Z)
	local startSpan = if boss then 4.5 else 2.0
	local endSpan = if boss then 12.0 else 5.4

	spawnBreachEllipse(parent, center, veilColor, startSpan, endSpan, 0.28)
	emitArcaneRift(parent, center, accentColor, if boss then 2.2 else 0.8)
	if boss then
		spawnBreachEllipse(
			parent,
			center + Vector3.new(-0.14, 0, 0),
			accentColor,
			startSpan * 0.82,
			endSpan * 1.15,
			0.28
		)
	end

	local mistAnchor = makeAnchor(parent, center, 0.55, "VfxPortalBreachMist")
	attachEmitter(mistAnchor, {
		name = "PortalBreachMist",
		color = ColorSequence.new(accentColor, veilColor),
		size = NumberSequence.new(if boss then 1.1 else 0.55, if boss then 2.8 else 1.4),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		}),
		lifetime = NumberRange.new(0.22, 0.42),
		speed = NumberRange.new(if boss then 6 else 4, if boss then 13 else 8),
		spreadAngle = Vector2.new(65, 65),
		emissionDirection = Enum.NormalId.Left,
		drag = 3,
		lightEmission = 0.85,
		burstCount = if boss then 18 else 8,
	})
	spawnLightFlash(
		parent,
		center,
		veilColor,
		if boss then 2.6 else 1.4,
		if boss then 18 else 10,
		0.24
	)
end

-- Lei HSV (§1): defensores nunca usam 160-195 deg (teal); frost usa azul glacial > 200 deg.
local projectileColors: { [string]: () -> Color3 } = {
	boulder = function()
		return rgb(VisualTheme.PALETTE.stoneDark)
	end,
	cannon = function()
		return rgb(VisualTheme.PALETTE.iron)
	end,
	arrow = function()
		return rgb(VisualTheme.PALETTE.amberBright)
	end,
	frost = function()
		return rgb(VisualTheme.PALETTE.frost)
	end,
}

function Vfx.projectile(
	parent: Instance,
	from: Vector3,
	to: Vector3,
	kind: string,
	duration: number?,
	onHit: (() -> ())?
): ()
	if activeProjectiles >= VisualTheme.VFX.maxConcurrentProjectiles then
		if onHit ~= nil then
			onHit()
		end
		return
	end
	activeProjectiles += 1

	local colorFn = projectileColors[kind] or projectileColors.cannon
	local color = colorFn()
	local isArrow = kind == "arrow"
	local piece = makePart(
		parent,
		if isArrow then Vector3.new(0.12, 0.12, 1.4) else Vector3.new(0.55, 0.55, 0.55),
		from,
		color,
		if isArrow then Enum.Material.SmoothPlastic else Enum.Material.Slate,
		if isArrow then Enum.PartType.Block else Enum.PartType.Ball
	)
	if isArrow then
		piece.CFrame = CFrame.lookAt(from, to)
	elseif kind == "frost" then
		piece.Material = Enum.Material.Neon
	end

	local trailEnd = if kind == "frost"
		then rgb(VisualTheme.PALETTE.frostBright)
		elseif isArrow then rgb(VisualTheme.PALETTE.amber)
		else rgb(VisualTheme.PALETTE.danger)
	attachTrail(piece, color, trailEnd, if isArrow then 0.18 else 0.42, 0.18)

	if kind == "boulder" or kind == "cannon" then
		attachEmitter(piece, {
			name = "ProjectileSmoke",
			color = ColorSequence.new(
				rgb(VisualTheme.PALETTE.amber),
				rgb(VisualTheme.PALETTE.stoneDark)
			),
			size = NumberSequence.new(0.3, 0.75),
			transparency = NumberSequence.new(0.35, 1),
			lifetime = NumberRange.new(0.2, 0.35),
			speed = NumberRange.new(1, 2.5),
			lightEmission = 0.3,
			rate = 16,
		})
	end

	local travel = duration or 0.35
	Debris:AddItem(piece, travel + 0.5)
	local arc = if kind == "boulder" then 5 else 2
	task.spawn(function()
		local started = time()
		while piece.Parent ~= nil do
			local now = time()
			local alpha = math.min((now - started) / travel, 1)
			local position = from:Lerp(to, alpha)
				+ Vector3.new(0, math.sin(alpha * math.pi) * arc, 0)
			piece.Position = position
			if alpha >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
		activeProjectiles = math.max(0, activeProjectiles - 1)
		if piece.Parent ~= nil then
			Vfx.impact(parent, to, color, 5)
			piece:Destroy()
			if onHit ~= nil then
				onHit()
			end
		end
	end)
end

local function spawnCrossBatteryEffect(parent: Instance, originPos: Vector3, targetPos: Vector3): ()
	local amber = rgb(VisualTheme.PALETTE.amber)
	local amberBright = rgb(VisualTheme.PALETTE.amberBright)
	local offset = Vector3.new(0, 0.28, 0.48)
	spawnLightningArc(
		parent,
		originPos + offset,
		targetPos + offset,
		amberBright,
		amber,
		0.52,
		0.22
	)
	moveCarrier(
		parent,
		originPos + offset,
		targetPos + offset,
		0.15,
		0.3,
		amberBright,
		amber,
		0.22,
		0.16,
		function()
			local burstAnchor = makeAnchor(parent, targetPos + offset, 0.7, "VfxCrossBatteryHit")
			emitSlashSparks(parent, targetPos + offset, amberBright, 8)
			attachEmitter(burstAnchor, {
				name = "CrossBatterySparks",
				color = ColorSequence.new(amberBright, amber),
				size = NumberSequence.new(0.24, 0.04),
				transparency = NumberSequence.new(0, 1),
				lifetime = NumberRange.new(0.2, 0.4),
				speed = NumberRange.new(8, 15),
				spreadAngle = Vector2.new(80, 80),
				lightEmission = 0.9,
				burstCount = 12,
			})
		end
	)
	spawnLightFlash(parent, originPos, amberBright, 2.2, 9, 0.14)
	spawnLightFlash(parent, targetPos, amberBright, 2.4, 9, 0.18)
end

local function spawnIncendiaryTarEffect(parent: Instance, targetPos: Vector3): ()
	local amberBright = rgb(VisualTheme.PALETTE.amberBright)
	local danger = rgb(VisualTheme.PALETTE.danger)
	local smokeTop = rgb(VisualTheme.PALETTE.stoneDark)
	local smokeBot = rgb(VisualTheme.PALETTE.ironDark)

	local anchor = makeAnchor(parent, targetPos + Vector3.new(0, 0.35, 0), 2.2, "VfxIncendiaryTar")
	emitExplosion(parent, targetPos + Vector3.new(0, 0.9, 0), amberBright, 1.2)
	spawnScorchDecal(parent, targetPos, 1.9)
	spawnTarPuddleDecal(parent, targetPos, 2.1)
	attachFireLoopFlipbook(anchor, amberBright, 1.4, 2.8, 14, 1.4, 5)
	attachEmitter(anchor, {
		name = "IncendiaryFire",
		color = ColorSequence.new(amberBright, danger),
		size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55),
			NumberSequenceKeypoint.new(0.6, 0.75),
			NumberSequenceKeypoint.new(1, 0.1),
		}),
		transparency = NumberSequence.new(0.1, 1),
		lifetime = NumberRange.new(0.35, 0.65),
		speed = NumberRange.new(2.5, 5.5),
		spreadAngle = Vector2.new(35, 35),
		acceleration = Vector3.new(0, 4, 0),
		lightEmission = 0.9,
		rate = 20,
		activeSeconds = 1.2,
	})
	attachEmitter(anchor, {
		name = "IncendiarySmoke",
		color = ColorSequence.new(smokeTop, smokeBot),
		size = NumberSequence.new(0.5, 1.5),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 1),
		}),
		lifetime = NumberRange.new(0.6, 1.0),
		speed = NumberRange.new(2.5, 4.5),
		spreadAngle = Vector2.new(25, 25),
		acceleration = Vector3.new(0, 3, 0),
		drag = 2,
		lightEmission = 0,
		rate = 14,
		activeSeconds = 1.2,
	})

	if lightsEnabled() then
		local light = Instance.new("PointLight")
		light.Color = rgb(VisualTheme.PALETTE.amber)
		light.Brightness = 2.4
		light.Range = 11
		light.Shadows = false
		light.Parent = anchor
		task.spawn(function()
			local started = time()
			while light.Parent ~= nil do
				local elapsed = time() - started
				if elapsed >= 1.2 then
					light.Brightness = 0
					break
				end
				local flicker = 1.8 + math.sin(elapsed * 28) * 0.65 + math.cos(elapsed * 43) * 0.35
				light.Brightness = flicker * (1 - elapsed / 1.4)
				RunService.Heartbeat:Wait()
			end
		end)
	end
end

local function spawnThermalShockEffect(parent: Instance, targetPos: Vector3): ()
	local frost = rgb(VisualTheme.PALETTE.frost)
	local frostBright = rgb(VisualTheme.PALETTE.frostBright)
	local white = rgb(VisualTheme.PALETTE.white)

	local anchor = makeAnchor(parent, targetPos + Vector3.new(0, 0.5, 0), 1.3, "VfxThermalShock")
	emitFrostShatter(parent, targetPos + Vector3.new(0, 0.9, 0), frostBright, 1.3)
	spawnFrostGroundDecal(parent, targetPos, 2.1)
	spawnLightningArc(
		parent,
		targetPos + Vector3.new(0, 3.2, 0),
		targetPos + Vector3.new(1.5, 0.25, -1.1),
		white,
		frostBright,
		0.65,
		0.26
	)
	spawnLightningArc(
		parent,
		targetPos + Vector3.new(0, 3.0, 0),
		targetPos + Vector3.new(-1.4, 0.25, 1.2),
		white,
		frost,
		0.55,
		0.24
	)
	attachEmitter(anchor, {
		name = "IceShatter",
		color = ColorSequence.new(frostBright, frost),
		size = NumberSequence.new(0.38, 0.08),
		transparency = NumberSequence.new(0, 1),
		lifetime = NumberRange.new(0.3, 0.6),
		speed = NumberRange.new(9, 17),
		spreadAngle = Vector2.new(90, 90),
		acceleration = Vector3.new(0, -22, 0),
		lightEmission = 0.75,
		burstCount = 20,
	})
	attachEmitter(anchor, {
		name = "SteamCloud",
		color = ColorSequence.new(white, frostBright),
		size = NumberSequence.new(0.65, 2.2),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		lifetime = NumberRange.new(0.5, 0.9),
		speed = NumberRange.new(3, 6.5),
		spreadAngle = Vector2.new(60, 60),
		acceleration = Vector3.new(0, 5, 0),
		drag = 3,
		lightEmission = 0.15,
		burstCount = 14,
	})
	Vfx.ring(parent, targetPos, frostBright)
	spawnLightFlash(parent, targetPos, white, 3.5, 13, 0.2)
end

type TrapHandler = (
	parent: Instance,
	originPos: Vector3,
	targetPos: Vector3,
	synergyKind: string?
) -> ()

local trapHandlers: { [string]: TrapHandler } = {
	archer = function(parent, originPos, targetPos, synergyKind)
		local amber = rgb(VisualTheme.PALETTE.amber)
		local amberBright = rgb(VisualTheme.PALETTE.amberBright)
		moveCarrier(
			parent,
			originPos,
			targetPos,
			0.16,
			0.25,
			amberBright,
			amber,
			0.24,
			0.18,
			function()
				local hitAnchor = makeAnchor(parent, targetPos, 0.7, "VfxArcherHit")
				attachEmitter(hitAnchor, {
					name = "ArcherSparks",
					color = ColorSequence.new(amberBright, amber),
					size = NumberSequence.new(0.22, 0.03),
					transparency = NumberSequence.new(0, 1),
					lifetime = NumberRange.new(0.18, 0.38),
					speed = NumberRange.new(7, 13),
					spreadAngle = Vector2.new(75, 75),
					acceleration = Vector3.new(0, -14, 0),
					lightEmission = 0.85,
					burstCount = 12,
				})
				emitSlashSparks(parent, targetPos + Vector3.new(0, 0.3, 0), amberBright, 6)
			end
		)
		if synergyKind == "cross_battery" then
			spawnCrossBatteryEffect(parent, originPos, targetPos)
		end
	end,

	tar = function(parent, _originPos, targetPos)
		local tarDark = rgb(VisualTheme.PALETTE.tarDark)
		local stoneDark = rgb(VisualTheme.PALETTE.stoneDark)
		local amber = rgb(VisualTheme.PALETTE.amber)
		local anchor = makeAnchor(parent, targetPos + Vector3.new(0, 0.25, 0), 1.9, "VfxTarSplash")
		spawnTarPuddleDecal(parent, targetPos, 1.85)
		attachFireLoopFlipbook(anchor, amber, 0.9, 1.8, 8, 0.9, 3)
		attachEmitter(anchor, {
			name = "TarSplash",
			color = ColorSequence.new(tarDark, stoneDark),
			size = NumberSequence.new(0.45, 0.15),
			transparency = NumberSequence.new(0.05, 1),
			lifetime = NumberRange.new(0.3, 0.55),
			speed = NumberRange.new(5, 10),
			spreadAngle = Vector2.new(80, 80),
			acceleration = Vector3.new(0, -18, 0),
			lightEmission = 0,
			burstCount = 14,
		})
		attachEmitter(anchor, {
			name = "TarBubbles",
			color = ColorSequence.new(amber, tarDark),
			size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.18),
				NumberSequenceKeypoint.new(0.7, 0.34),
				NumberSequenceKeypoint.new(1, 0.05),
			}),
			transparency = NumberSequence.new(0.15, 1),
			lifetime = NumberRange.new(0.45, 0.8),
			speed = NumberRange.new(1.5, 3.2),
			spreadAngle = Vector2.new(30, 30),
			acceleration = Vector3.new(0, 2, 0),
			lightEmission = 0.25,
			rate = 14,
			activeSeconds = 0.9,
		})
	end,

	frost = function(parent, _originPos, targetPos)
		local frost = rgb(VisualTheme.PALETTE.frost)
		local frostBright = rgb(VisualTheme.PALETTE.frostBright)
		local anchor = makeAnchor(parent, targetPos + Vector3.new(0, 0.4, 0), 1.1, "VfxFrostBurst")
		spawnFrostGroundDecal(parent, targetPos, 1.8)
		attachEmitter(anchor, {
			name = "FrostShards",
			color = ColorSequence.new(frostBright, frost),
			size = NumberSequence.new(0.34, 0.06),
			transparency = NumberSequence.new(0, 1),
			lifetime = NumberRange.new(0.28, 0.55),
			speed = NumberRange.new(7, 13),
			spreadAngle = Vector2.new(85, 85),
			acceleration = Vector3.new(0, -15, 0),
			lightEmission = 0.7,
			burstCount = 16,
		})
		attachEmitter(anchor, {
			name = "FrostMist",
			color = ColorSequence.new(frostBright, frost),
			size = NumberSequence.new(0.6, 1.6),
			transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.45),
				NumberSequenceKeypoint.new(1, 1),
			}),
			lifetime = NumberRange.new(0.4, 0.75),
			speed = NumberRange.new(2, 4.5),
			spreadAngle = Vector2.new(75, 75),
			drag = 3,
			lightEmission = 0.3,
			burstCount = 10,
		})
		Vfx.ring(parent, targetPos, frost)
		emitFrostShatter(parent, targetPos + Vector3.new(0, 0.8, 0), frostBright, 1)
		spawnLightFlash(parent, targetPos, frostBright, 2.2, 10, 0.22)
	end,

	cannon = function(parent, originPos, targetPos)
		local amberBright = rgb(VisualTheme.PALETTE.amberBright)
		local amber = rgb(VisualTheme.PALETTE.amber)
		local danger = rgb(VisualTheme.PALETTE.danger)
		local smoke = rgb(VisualTheme.PALETTE.stoneDark)

		local muzzleAnchor = makeAnchor(parent, originPos, 0.9, "VfxCannonMuzzle")
		attachEmitter(muzzleAnchor, {
			name = "MuzzleSmoke",
			color = ColorSequence.new(amber, smoke),
			size = NumberSequence.new(0.45, 1.25),
			transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.25),
				NumberSequenceKeypoint.new(1, 1),
			}),
			lifetime = NumberRange.new(0.3, 0.6),
			speed = NumberRange.new(3, 7),
			spreadAngle = Vector2.new(45, 45),
			drag = 3,
			lightEmission = 0.35,
			burstCount = 12,
		})
		spawnLightFlash(parent, originPos, amberBright, 2.8, 10, 0.14)

		moveCarrier(
			parent,
			originPos,
			targetPos,
			0.14,
			0,
			amberBright,
			danger,
			0.32,
			0.16,
			function()
				local impactAnchor = makeAnchor(parent, targetPos, 0.95, "VfxCannonImpact")
				attachEmitter(impactAnchor, {
					name = "CannonEmbers",
					color = ColorSequence.new(amberBright, danger),
					size = NumberSequence.new(0.32, 0.05),
					transparency = NumberSequence.new(0, 1),
					lifetime = NumberRange.new(0.28, 0.55),
					speed = NumberRange.new(8, 16),
					spreadAngle = Vector2.new(85, 85),
					acceleration = Vector3.new(0, -16, 0),
					lightEmission = 0.95,
					burstCount = 18,
				})
				spawnLightFlash(parent, targetPos, danger, 2.4, 10, 0.18)
				emitExplosion(parent, targetPos + Vector3.new(0, 0.9, 0), amberBright, 1)
				spawnScorchDecal(parent, targetPos, 1.6)
				spawnVolumeWave(
					parent,
					targetPos + Vector3.new(0, 0.55, 0),
					amberBright,
					1.1,
					4.4,
					0.28
				)
			end
		)
	end,

	catapult = function(parent, originPos, targetPos)
		local amberBright = rgb(VisualTheme.PALETTE.amberBright)
		local danger = rgb(VisualTheme.PALETTE.danger)
		local carrier = moveCarrier(
			parent,
			originPos,
			targetPos,
			0.38,
			5,
			amberBright,
			danger,
			0.55,
			0.28,
			function()
				Vfx.ring(parent, targetPos, danger)
				Vfx.dust(parent, targetPos, 8)
				emitExplosion(parent, targetPos + Vector3.new(0, 1.2, 0), amberBright, 1.5)
				spawnScorchDecal(parent, targetPos, 2.2)
				spawnVolumeWave(parent, targetPos + Vector3.new(0, 0.65, 0), danger, 1.5, 6.2, 0.34)
				spawnLightFlash(parent, targetPos, danger, 2.6, 12, 0.2)
			end
		)
		attachEmitter(carrier, {
			name = "CatapultFlame",
			color = ColorSequence.new(amberBright, danger),
			size = NumberSequence.new(0.45, 0.1),
			transparency = NumberSequence.new(0.15, 1),
			lifetime = NumberRange.new(0.2, 0.38),
			speed = NumberRange.new(1.5, 3.5),
			lightEmission = 0.85,
			rate = 22,
			activeSeconds = 0.38,
		})
	end,
}

function Vfx.trapEffect(
	parent: Instance,
	trapType: string,
	originPos: Vector3,
	targetPos: Vector3,
	synergyKind: string?
): ()
	local handler = trapHandlers[trapType]
	if handler ~= nil then
		handler(parent, originPos, targetPos, synergyKind)
	end

	if synergyKind == "incendiary_tar" then
		spawnIncendiaryTarEffect(parent, targetPos)
	elseif synergyKind == "thermal_shock" then
		spawnThermalShockEffect(parent, targetPos)
	elseif synergyKind == "cross_battery" and trapType ~= "archer" then
		spawnCrossBatteryEffect(parent, originPos, targetPos)
	end
end

local function clearBossTelegraph(parent: Instance): ()
	local existing = parent:FindFirstChild("VfxBossTelegraphZone")
	if existing ~= nil then
		telegraphExpiresAt[existing] = nil
		existing:Destroy()
	end
end

function Vfx.bossTelegraph(
	parent: Instance,
	pos: Vector3,
	accentColor: Color3,
	progress: number?
): ()
	local p = math.clamp(progress or 0.5, 0, 1)
	local now = time()
	local stripLen = 14.5
	local stripWidth = 11.2
	local centerX = pos.X - (stripLen * 0.5 + 1.4)
	local floorY = pos.Y + 0.05

	local zone = parent:FindFirstChild("VfxBossTelegraphZone")
	local isNew = false
	if zone == nil then
		isNew = true
		local folder = Instance.new("Folder")
		folder.Name = "VfxBossTelegraphZone"
		folder.Parent = parent
		zone = folder

		local fill = makePart(
			folder,
			Vector3.new(stripLen, 0.06, stripWidth),
			Vector3.new(centerX, floorY, pos.Z),
			rgb(VisualTheme.PALETTE.danger),
			Enum.Material.Neon
		)
		fill.Name = "StripFill"
		fill.Transparency = 0.62

		for _, sz in ipairs({ -1, 1 }) do
			local border = makePart(
				folder,
				Vector3.new(stripLen, 0.09, 0.28),
				Vector3.new(centerX, floorY + 0.02, pos.Z + sz * (stripWidth * 0.5)),
				accentColor,
				Enum.Material.Neon
			)
			border.Name = if sz < 0 then "BorderL" else "BorderR"
			border.Transparency = 0.22
		end

		local frontEdge = makePart(
			folder,
			Vector3.new(0.36, 0.10, stripWidth + 0.28),
			Vector3.new(centerX - stripLen * 0.5, floorY + 0.02, pos.Z),
			accentColor,
			Enum.Material.Neon
		)
		frontEdge.Name = "FrontEdge"
		frontEdge.Transparency = 0.18

		local sweep = makePart(
			folder,
			Vector3.new(1.1, 0.09, stripWidth - 0.5),
			Vector3.new(pos.X - 2.0, floorY + 0.03, pos.Z),
			accentColor,
			Enum.Material.Neon
		)
		sweep.Name = "ChargeSweep"
		sweep.Transparency = 0.25

		local beamTexture: string = VfxAssets.contentId("beamEnergyTrail")
		if beamTexture ~= "" then
			local halfSpan = (stripWidth - 0.5) * 0.5
			local beamA0 = Instance.new("Attachment")
			beamA0.Position = Vector3.new(0, 0.1, -halfSpan)
			beamA0.Parent = sweep
			local beamA1 = Instance.new("Attachment")
			beamA1.Position = Vector3.new(0, 0.1, halfSpan)
			beamA1.Parent = sweep
			local beam = Instance.new("Beam")
			beam.Name = "ChargeBeam"
			beam.Attachment0 = beamA0
			beam.Attachment1 = beamA1
			beam.Texture = beamTexture
			beam.TextureMode = Enum.TextureMode.Stretch
			beam.Color = ColorSequence.new(rgb(VisualTheme.PALETTE.white), accentColor)
			beam.Width0 = 0.9
			beam.Width1 = 0.9
			beam.LightEmission = 0.9
			beam.FaceCamera = true
			beam.Segments = 1
			beam.Parent = sweep
		end

		if currentTier ~= "Low" then
			local runeTexture: string = VfxAssets.contentId("bossRuneDecal")
			if runeTexture ~= "" then
				local runePlate = makePart(
					folder,
					Vector3.new(stripWidth * 0.85, 0.04, stripWidth * 0.85),
					Vector3.new(centerX, floorY + 0.03, pos.Z),
					accentColor,
					Enum.Material.SmoothPlastic
				)
				runePlate.Name = "VfxBossRunePlate"
				runePlate.Transparency = 1
				runePlate.CanCollide = false
				runePlate.CanTouch = false
				runePlate.CanQuery = false
				local runeDecal = Instance.new("Decal")
				runeDecal.Name = "BossRuneDecal"
				runeDecal.Texture = runeTexture
				runeDecal.Face = Enum.NormalId.Top
				runeDecal.Color3 = accentColor
				runeDecal.Transparency = 0.12
				runeDecal.Parent = runePlate
			end
		end
	end

	local activeZone = zone :: Instance
	telegraphExpiresAt[activeZone] = now + 0.45

	local pulse = 0.5 + 0.5 * math.sin(now * (10 + p * 18))
	local runePlatePart = activeZone:FindFirstChild("VfxBossRunePlate")
	if runePlatePart ~= nil and runePlatePart:IsA("BasePart") then
		runePlatePart.Position = Vector3.new(centerX, floorY + 0.03, pos.Z)
	end
	local fillPart = activeZone:FindFirstChild("StripFill")
	if fillPart ~= nil and fillPart:IsA("BasePart") then
		fillPart.Position = Vector3.new(centerX, floorY, pos.Z)
		fillPart.Color = rgb(VisualTheme.PALETTE.danger):Lerp(accentColor, 0.35 * pulse)
		fillPart.Transparency = math.clamp(0.68 - p * 0.34 - pulse * 0.12, 0.18, 0.78)
	end
	for _, bName in ipairs({ "BorderL", "BorderR" }) do
		local sz = if bName == "BorderL" then -1 else 1
		local borderPart = activeZone:FindFirstChild(bName)
		if borderPart ~= nil and borderPart:IsA("BasePart") then
			borderPart.Position =
				Vector3.new(centerX, floorY + 0.02, pos.Z + sz * (stripWidth * 0.5))
			borderPart.Color = accentColor
			borderPart.Transparency = math.clamp(0.36 - p * 0.22 - pulse * 0.08, 0.06, 0.5)
		end
	end
	local frontPart = activeZone:FindFirstChild("FrontEdge")
	if frontPart ~= nil and frontPart:IsA("BasePart") then
		frontPart.Position = Vector3.new(centerX - stripLen * 0.5, floorY + 0.02, pos.Z)
		frontPart.Color = accentColor
		frontPart.Transparency = math.clamp(0.32 - p * 0.22, 0.05, 0.45)
	end
	local sweepPart = activeZone:FindFirstChild("ChargeSweep")
	if sweepPart ~= nil and sweepPart:IsA("BasePart") then
		local sweepX = (pos.X - 2.0) - (stripLen - 1.2) * p
		sweepPart.Position = Vector3.new(sweepX, floorY + 0.03, pos.Z)
		sweepPart.Color = rgb(VisualTheme.PALETTE.white):Lerp(accentColor, 0.65)
		sweepPart.Transparency = math.clamp(0.42 - p * 0.28, 0.08, 0.5)
	end

	if isNew then
		task.spawn(function()
			while activeZone.Parent ~= nil do
				local exp = telegraphExpiresAt[activeZone]
				if exp == nil or time() >= exp then
					telegraphExpiresAt[activeZone] = nil
					for _, child in ipairs(activeZone:GetChildren()) do
						if child:IsA("BasePart") then
							fadeAndDestroy(child, 0.18)
						end
					end
					Debris:AddItem(activeZone, 0.24)
					break
				end
				task.wait(0.12)
			end
		end)
	end
end

function Vfx.bossSlamImpact(parent: Instance, pos: Vector3, accentColor: Color3): ()
	clearBossTelegraph(parent)
	local danger = rgb(VisualTheme.PALETTE.danger)
	local stone = rgb(VisualTheme.PALETTE.stone)
	local stoneDark = rgb(VisualTheme.PALETTE.stoneDark)
	local white = rgb(VisualTheme.PALETTE.white)
	local slamPos = pos + Vector3.new(-2.2, 0.08, 0)
	spawnScorchDecal(parent, pos, 3.2)
	emitSlashSparks(parent, pos + Vector3.new(0, 0.9, 0), accentColor, 10)
	spawnVolumeWave(parent, slamPos + Vector3.new(0, 0.85, 0), accentColor, 2.0, 9.5, 0.42)
	for arcIdx = 1, 3 do
		local ang = ((arcIdx - 1) / 3) * math.pi * 2 + 0.35
		spawnLightningArc(
			parent,
			slamPos + Vector3.new(0, 1.4, 0),
			slamPos + Vector3.new(math.cos(ang) * 4.8, 0.25, math.sin(ang) * 4.8),
			white,
			accentColor,
			0.7,
			0.3
		)
	end

	-- Dual seismic shockwave rings
	spawnShockwaveRing(
		parent,
		slamPos + Vector3.new(0, 0.28, 0),
		accentColor,
		2.4,
		18.5,
		0.24,
		0.48
	)
	spawnShockwaveRing(
		parent,
		slamPos + Vector3.new(0, 0.56, 0),
		danger:Lerp(accentColor, 0.45),
		1.6,
		12.6,
		0.20,
		0.34
	)

	-- Seismic dust & spark burst
	local slamAnchor = makeAnchor(parent, slamPos + Vector3.new(0, 0.45, 0), 1.15, "VfxBossSlam")
	attachEmitter(slamAnchor, {
		name = "SeismicPlume",
		color = ColorSequence.new(accentColor, stoneDark),
		size = NumberSequence.new(0.75, 2.4),
		transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		lifetime = NumberRange.new(0.38, 0.78),
		speed = NumberRange.new(6, 15),
		spreadAngle = Vector2.new(85, 85),
		acceleration = Vector3.new(0, -10, 0),
		drag = 2.5,
		lightEmission = 0.55,
		burstCount = 24,
	})
	spawnLightFlash(parent, slamPos + Vector3.new(0, 1.4, 0), accentColor, 3.6, 17, 0.26)

	-- <= 8 stone chips (F2 FractureDebris)
	Vfx.configureCollisionGroups()
	ensureGovernor()
	local maxBodies, ttl = tierBudget(currentTier)
	local chipCount = math.min(8, VisualTheme.VFX.maxImpactParts, maxBodies)
	if chipCount > 0 then
		pruneF2(time(), chipCount)
		local chipTtl = math.min(ttl, 1.45)
		for idx = 1, chipCount do
			local ang = ((idx - 1) / chipCount) * math.pi * 2 + 0.18
			local spawnPos = slamPos
				+ Vector3.new(math.cos(ang) * 1.15, 0.45 + (idx % 2) * 0.2, math.sin(ang) * 1.15)
			local chip = makePart(
				parent,
				Vector3.new(
					0.52 + (idx % 3) * 0.14,
					0.36 + (idx % 2) * 0.14,
					0.62 + ((idx + 1) % 3) * 0.14
				),
				spawnPos,
				if idx % 2 == 0 then stone else stoneDark,
				Enum.Material.Slate
			)
			chip.Name = "F2_BossStoneChip_" .. tostring(idx)
			applyF2Flags(chip, "FractureDebris")
			local vel = Vector3.new(
				math.cos(ang) * 10.5 - 2.0,
				13.5 + (idx % 3) * 3.5,
				math.sin(ang) * 10.5
			)
			chip:ApplyImpulse(vel * chip.AssemblyMass)
			chip:ApplyAngularImpulse(
				Vector3.new(8 - (idx % 3) * 4, 6, -10 + idx * 3) * chip.AssemblyMass
			)
			trackF2(chip, chipTtl)
		end
	end

	-- 0.28s seismic camera shake
	triggerCameraImpulse(0.44, 0.28, -2.8)
end

local function spawnBossDebrisBurst(
	parent: Instance,
	center: Vector3,
	desiredCount: number,
	colorA: Color3,
	colorB: Color3,
	material: Enum.Material,
	transparency: number
): ()
	Vfx.configureCollisionGroups()
	ensureGovernor()
	local maxBodies, ttl = tierBudget(currentTier)
	local count = math.min(desiredCount, 6, maxBodies)
	if count <= 0 then
		return
	end
	pruneF2(time(), count)
	local chunkTtl = math.min(ttl, 1.65)
	for idx = 1, count do
		local ang = ((idx - 1) / count) * math.pi * 2 + 0.3
		local spawnPos = center
			+ Vector3.new(math.cos(ang) * 1.2, 1.8 + (idx % 3) * 0.7, math.sin(ang) * 1.2)
		local chunk = makeWedge(
			parent,
			Vector3.new(0.68, 1.05 + (idx % 2) * 0.35, 0.88),
			spawnPos,
			if idx % 2 == 0 then colorA else colorB,
			material
		)
		chunk.Name = "F2_BossClimaxShard_" .. tostring(idx)
		chunk.Transparency = transparency
		applyF2Flags(chunk, "FractureDebris")
		local vel =
			Vector3.new(math.cos(ang) * 12.0 + 3.0, 16.0 + (idx % 3) * 4.0, math.sin(ang) * 12.0)
		chunk:ApplyImpulse(vel * chunk.AssemblyMass)
		chunk:ApplyAngularImpulse(Vector3.new(11, -9 + idx * 4, 13) * chunk.AssemblyMass)
		trackF2(chunk, chunkTtl)
	end
end

function Vfx.bossDeathSequence(
	parent: Instance,
	bossId: string,
	pos: Vector3,
	primaryColor: Color3,
	accentColor: Color3
): ()
	clearBossTelegraph(parent)
	local white = rgb(VisualTheme.PALETTE.white)
	local danger = rgb(VisualTheme.PALETTE.danger)
	local ink = rgb(VisualTheme.PALETTE.ink)
	local coreCenter = pos + Vector3.new(0, 4.8, 0)

	if bossId == "rift_titan" then
		-- Act 5: Rift Singularity Implosion (0..0.46s) + Radial Pulse Detonation (0.46..0.85s)
		emitArcaneRift(parent, coreCenter, accentColor, 3)
		local horizonShell = makePart(
			parent,
			Vector3.new(11.5, 11.5, 11.5),
			coreCenter,
			accentColor,
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		horizonShell.Name = "VfxRiftHorizon"
		horizonShell.Transparency = 0.24
		TweenService:Create(
			horizonShell,
			TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Size = Vector3.new(0.75, 0.75, 0.75), Transparency = 0.02 }
		):Play()
		Debris:AddItem(horizonShell, 0.49)

		local voidCore = makePart(
			parent,
			Vector3.new(4.8, 4.8, 4.8),
			coreCenter,
			ink,
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
		voidCore.Name = "VfxRiftSingularityCore"
		TweenService:Create(
			voidCore,
			TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.In),
			{ Size = Vector3.new(0.45, 0.45, 0.45) }
		):Play()
		Debris:AddItem(voidCore, 0.49)

		-- Contracting floor horizon ring
		spawnShockwaveRing(
			parent,
			pos + Vector3.new(0, 0.45, 0),
			primaryColor,
			14.5,
			1.2,
			0.22,
			0.44
		)

		-- 6 inward-pulled rift ribbons converging into singularity
		for idx = 1, 6 do
			local ang = ((idx - 1) / 6) * math.pi * 2
			local elev = ((idx % 3) - 1) * 2.2
			local startPt = coreCenter + Vector3.new(math.cos(ang) * 9.5, elev, math.sin(ang) * 9.5)
			local ribbon = makePart(
				parent,
				Vector3.new(0.18, 0.18, 2.2),
				startPt,
				if idx % 2 == 0 then accentColor else primaryColor,
				Enum.Material.Neon
			)
			ribbon.Name = "VfxRiftInwardRibbon"
			ribbon.CFrame = CFrame.lookAt(startPt, coreCenter)
			TweenService
				:Create(
					ribbon,
					TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{
						CFrame = CFrame.lookAt(coreCenter, coreCenter + (coreCenter - startPt)),
						Size = Vector3.new(0.05, 0.05, 0.35),
						Transparency = 0.85,
					}
				)
				:Play()
			Debris:AddItem(ribbon, 0.46)
		end

		triggerCameraImpulse(0.24, 0.22, -1.6)
		spawnLightFlash(parent, coreCenter, primaryColor, 2.8, 16, 0.42)

		-- Phase 2: Radial Pulse Detonation at 0.46s
		task.delay(0.46, function()
			if parent.Parent == nil then
				return
			end
			local pulseWave = makePart(
				parent,
				Vector3.new(1.1, 1.1, 1.1),
				coreCenter,
				accentColor,
				Enum.Material.Neon,
				Enum.PartType.Ball
			)
			pulseWave.Name = "VfxRiftRadialPulse"
			pulseWave.Transparency = 0.08
			TweenService:Create(
				pulseWave,
				TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = Vector3.new(22.5, 22.5, 22.5), Transparency = 1 }
			):Play()
			Debris:AddItem(pulseWave, 0.42)

			spawnShockwaveRing(
				parent,
				pos + Vector3.new(0, 0.5, 0),
				accentColor,
				2.0,
				24.0,
				0.28,
				0.40
			)
			spawnShockwaveRing(
				parent,
				coreCenter,
				primaryColor,
				1.8,
				20.0,
				0.22,
				0.36,
				CFrame.Angles(math.rad(24), 0, math.rad(-18))
			)

			local pillar = makePart(
				parent,
				Vector3.new(16.0, 2.2, 2.2),
				pos + Vector3.new(0, 8.0, 0),
				white,
				Enum.Material.Neon,
				Enum.PartType.Cylinder
			)
			pillar.Name = "VfxRiftPillar"
			pillar.Transparency = 0.15
			pillar.CFrame = CFrame.new(pos + Vector3.new(0, 8.0, 0))
				* CFrame.Angles(0, 0, math.rad(90))
			TweenService:Create(
				pillar,
				TweenInfo.new(0.36, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Size = Vector3.new(20.0, 0.12, 0.12), Transparency = 1 }
			):Play()
			Debris:AddItem(pillar, 0.40)

			local detAnchor = makeAnchor(parent, coreCenter, 0.9, "VfxRiftNovaBurst")
			attachEmitter(detAnchor, {
				name = "RiftSingularitySparks",
				color = ColorSequence.new(white, primaryColor),
				size = NumberSequence.new(0.55, 0.08),
				transparency = NumberSequence.new(0, 1),
				lifetime = NumberRange.new(0.28, 0.62),
				speed = NumberRange.new(14, 28),
				spreadAngle = Vector2.new(90, 90),
				drag = 2,
				lightEmission = 1,
				burstCount = 36,
			})
			spawnBossDebrisBurst(parent, pos, 6, primaryColor, ink, Enum.Material.Neon, 0.08)
			spawnLightFlash(parent, coreCenter, accentColor, 4.5, 24, 0.36)
			triggerCameraImpulse(0.48, 0.28, -3.2)
		end)
		return
	end

	if bossId == "rime_matriarch" then
		-- Act 3: Boreal Cryo Supernova
		local frostBright = rgb(VisualTheme.PALETTE.frostBright)
		emitFrostShatter(parent, coreCenter, frostBright, 3)
		spawnShockwaveRing(
			parent,
			pos + Vector3.new(0, 0.45, 0),
			accentColor,
			2.2,
			20.5,
			0.24,
			0.55
		)
		spawnShockwaveRing(
			parent,
			coreCenter,
			frostBright,
			1.6,
			15.5,
			0.18,
			0.44,
			CFrame.Angles(math.rad(18), 0, math.rad(14))
		)
		local spire = makePart(
			parent,
			Vector3.new(13.5, 2.4, 2.4),
			pos + Vector3.new(0, 6.8, 0),
			frostBright,
			Enum.Material.Neon,
			Enum.PartType.Cylinder
		)
		spire.Name = "VfxCryoSpire"
		spire.Transparency = 0.16
		spire.CFrame = CFrame.new(pos + Vector3.new(0, 6.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
		TweenService:Create(
			spire,
			TweenInfo.new(0.52, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(17.5, 0.10, 0.10), Transparency = 1 }
		):Play()
		Debris:AddItem(spire, 0.56)

		local cryoAnchor = makeAnchor(parent, coreCenter, 1.1, "VfxCryoNova")
		attachEmitter(cryoAnchor, {
			name = "CryoBlizzardBurst",
			color = ColorSequence.new(white, primaryColor),
			size = NumberSequence.new(0.5, 0.1),
			transparency = NumberSequence.new(0, 1),
			lifetime = NumberRange.new(0.35, 0.72),
			speed = NumberRange.new(11, 22),
			spreadAngle = Vector2.new(90, 90),
			acceleration = Vector3.new(0, -14, 0),
			lightEmission = 0.85,
			burstCount = 32,
		})
		spawnBossDebrisBurst(parent, pos, 6, accentColor, primaryColor, Enum.Material.Ice, 0.25)
		spawnLightFlash(parent, coreCenter, accentColor, 3.8, 20, 0.35)
		triggerCameraImpulse(0.38, 0.28, -2.5)
		return
	end

	if bossId == "powder_baron" then
		-- Act 4: Staggered Munitions Chain-Detonation across 0.85s
		emitExplosion(parent, coreCenter, danger, 2.4)
		spawnScorchDecal(parent, pos, 4)
		local offsets = {
			Vector3.new(-1.4, 3.4, -1.8),
			Vector3.new(1.8, 4.8, 1.6),
			Vector3.new(0, 5.6, 0),
		}
		for idx, off in ipairs(offsets) do
			task.delay((idx - 1) * 0.18, function()
				if parent.Parent == nil then
					return
				end
				local blastPos = pos + off
				local fireball = makePart(
					parent,
					Vector3.new(1.8, 1.8, 1.8),
					blastPos,
					if idx == 3 then white else accentColor,
					Enum.Material.Neon,
					Enum.PartType.Ball
				)
				fireball.Name = "VfxPowderBlast_" .. tostring(idx)
				fireball.Transparency = 0.12
				local endScale = if idx == 3 then 12.5 else 7.8
				TweenService:Create(
					fireball,
					TweenInfo.new(0.34, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Size = Vector3.new(endScale, endScale, endScale), Transparency = 1 }
				):Play()
				Debris:AddItem(fireball, 0.38)

				spawnShockwaveRing(
					parent,
					pos + Vector3.new(0, 0.4 + idx * 0.2, 0),
					if idx == 3 then danger else accentColor,
					1.8,
					11.0 + idx * 3.8,
					0.20,
					0.38
				)
				local blastAnchor = makeAnchor(parent, blastPos, 0.95, "VfxPowderSmoke")
				attachEmitter(blastAnchor, {
					name = "MunitionSparks",
					color = ColorSequence.new(accentColor, danger),
					size = NumberSequence.new(0.46, 1.35),
					transparency = NumberSequence.new(0.1, 1),
					lifetime = NumberRange.new(0.3, 0.65),
					speed = NumberRange.new(8, 19),
					spreadAngle = Vector2.new(85, 85),
					drag = 2,
					lightEmission = 0.8,
					burstCount = 24,
				})
				spawnLightFlash(parent, blastPos, accentColor, 3.4, 17, 0.22)
				if idx == 1 or idx == 3 then
					triggerCameraImpulse(0.36, 0.22, -2.2)
				end
			end)
		end
		spawnBossDebrisBurst(parent, pos, 6, primaryColor, accentColor, Enum.Material.Metal, 0)
		return
	end

	if bossId == "slag_juggernaut" then
		-- Act 2: Molten Magma Eruption
		spawnShockwaveRing(parent, pos + Vector3.new(0, 0.42, 0), danger, 2.4, 20.0, 0.26, 0.52)
		spawnShockwaveRing(parent, pos + Vector3.new(0, 1.1, 0), accentColor, 1.6, 14.5, 0.20, 0.38)
		local geyser = makePart(
			parent,
			Vector3.new(12.5, 2.8, 2.8),
			pos + Vector3.new(0, 6.2, 0),
			accentColor,
			Enum.Material.Neon,
			Enum.PartType.Cylinder
		)
		geyser.Name = "VfxMagmaGeyser"
		geyser.Transparency = 0.14
		geyser.CFrame = CFrame.new(pos + Vector3.new(0, 6.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		TweenService:Create(
			geyser,
			TweenInfo.new(0.50, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(16.5, 0.14, 0.14), Transparency = 1 }
		):Play()
		Debris:AddItem(geyser, 0.55)

		local slagAnchor = makeAnchor(parent, coreCenter, 1.15, "VfxSlagEruption")
		attachEmitter(slagAnchor, {
			name = "MoltenEmbers",
			color = ColorSequence.new(rgb(VisualTheme.PALETTE.amberBright), danger),
			size = NumberSequence.new(0.52, 0.08),
			transparency = NumberSequence.new(0, 1),
			lifetime = NumberRange.new(0.35, 0.78),
			speed = NumberRange.new(10, 22),
			spreadAngle = Vector2.new(80, 80),
			acceleration = Vector3.new(0, -18, 0),
			lightEmission = 0.95,
			burstCount = 34,
		})
		spawnBossDebrisBurst(parent, pos, 6, primaryColor, danger, Enum.Material.Slate, 0)
		spawnLightFlash(parent, coreCenter, danger, 4.0, 20, 0.36)
		triggerCameraImpulse(0.42, 0.28, -2.6)
		return
	end

	-- Act 1 (iron_ram_colossus) & generic heavy colossus forge shatter
	spawnShockwaveRing(parent, pos + Vector3.new(0, 0.42, 0), accentColor, 2.2, 19.5, 0.24, 0.50)
	spawnShockwaveRing(parent, pos + Vector3.new(0, 0.95, 0), primaryColor, 1.6, 13.5, 0.18, 0.38)
	local coreFlash = makePart(
		parent,
		Vector3.new(2.2, 2.2, 2.2),
		coreCenter,
		accentColor,
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
	coreFlash.Name = "VfxColossusCoreFlash"
	coreFlash.Transparency = 0.12
	TweenService:Create(
		coreFlash,
		TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(11.5, 11.5, 11.5), Transparency = 1 }
	):Play()
	Debris:AddItem(coreFlash, 0.46)

	local forgeAnchor = makeAnchor(parent, coreCenter, 1.05, "VfxForgeShatter")
	attachEmitter(forgeAnchor, {
		name = "AnvilSparks",
		color = ColorSequence.new(white, accentColor),
		size = NumberSequence.new(0.42, 0.06),
		transparency = NumberSequence.new(0, 1),
		lifetime = NumberRange.new(0.3, 0.68),
		speed = NumberRange.new(11, 23),
		spreadAngle = Vector2.new(85, 85),
		acceleration = Vector3.new(0, -18, 0),
		lightEmission = 0.9,
		burstCount = 32,
	})
	Vfx.dust(parent, pos, 8)
	spawnBossDebrisBurst(parent, pos, 6, primaryColor, accentColor, Enum.Material.Metal, 0)
	spawnLightFlash(parent, coreCenter, accentColor, 3.6, 18, 0.32)
	triggerCameraImpulse(0.40, 0.28, -2.5)
end

function Vfx.sampleCameraImpulse(now: number): (CFrame, number)
	camImpulseSampledAt = now
	local elapsed = now - camImpulseStart
	if elapsed < 0 or elapsed >= camImpulseDuration or camImpulseDuration <= 0 then
		return CFrame.identity, 0
	end
	local fade = 1 - (elapsed / camImpulseDuration)
	local ease = fade * fade
	local x = math.sin(elapsed * 96) * camImpulseIntensity * fade
	local y = math.cos(elapsed * 124) * camImpulseIntensity * 0.68 * fade
	local roll = math.rad(x * 1.6)
	local fovDelta = camImpulseFovDelta * ease
	return CFrame.new(x, y, 0) * CFrame.Angles(0, 0, roll), fovDelta
end

function Vfx.shake(camera: Camera, base: CFrame, intensity: number, duration: number): ()
	local elapsed = 0
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function(dt: number)
		elapsed += dt
		if elapsed >= duration then
			camera.CFrame = base
			connection:Disconnect()
			return
		end
		local fade = 1 - elapsed / duration
		local x = math.sin(elapsed * 90) * intensity * fade
		local y = math.cos(elapsed * 117) * intensity * 0.6 * fade
		camera.CFrame = base * CFrame.new(x, y, 0) * CFrame.Angles(0, 0, math.rad(x * 1.5))
	end)
end

return Vfx
