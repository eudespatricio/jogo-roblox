--!strict
-- S8/S8.2: VFX cosmeticos e fisica real F2 local (ragdoll/fratura isolados em CollisionGroup).
-- Tudo local no cliente; nao altera o resultado deterministico da batalha.

local Debris = game:GetService("Debris")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local VisualTheme = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("visual"):WaitForChild("VisualTheme")
)

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
	trail.MinLength = 0.05
	trail.Enabled = true
	trail.Parent = part
	return trail
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

function Vfx.death(parent: Instance, position: Vector3, color: Color3): ()
	Vfx.impact(parent, position + Vector3.new(0, 0.8, 0), color, 5)
	Vfx.dust(parent, position, 3)
end

function Vfx.ragdollEnemy(parent: Instance, position: Vector3, color: Color3, impulse: Vector3?): ()
	Vfx.configureCollisionGroups()
	ensureGovernor()
	local maxBodies, ttl = tierBudget(currentTier)
	if maxBodies <= 0 then
		return
	end
	pruneF2(time(), 1)

	local ragdoll = Instance.new("Model")
	ragdoll.Name = "F2_Ragdoll"

	local torso = makePart(
		ragdoll,
		Vector3.new(1.1, 1.2, 0.8),
		position + Vector3.new(0, 1.2, 0),
		color,
		Enum.Material.SmoothPlastic
	)
	torso.Name = "Torso"
	applyF2Flags(torso, "RagdollBody")

	local head = makePart(
		ragdoll,
		Vector3.new(0.75, 0.75, 0.75),
		position + Vector3.new(0, 2.2, 0),
		color,
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	head.Name = "Head"
	applyF2Flags(head, "RagdollBody")

	local neckA = Instance.new("Attachment")
	neckA.Position = Vector3.new(0, 0.65, 0)
	neckA.Parent = torso
	local neckB = Instance.new("Attachment")
	neckB.Position = Vector3.new(0, -0.35, 0)
	neckB.Parent = head

	local socket = Instance.new("BallSocketConstraint")
	socket.Attachment0 = neckA
	socket.Attachment1 = neckB
	socket.LimitsEnabled = true
	socket.UpperAngle = 35
	socket.TwistLimitsEnabled = true
	socket.TwistLowerAngle = -20
	socket.TwistUpperAngle = 20
	socket.MaxFrictionTorque = 8
	socket.Parent = torso

	ragdoll.PrimaryPart = torso
	ragdoll.Parent = parent

	local dir = impulse or Vector3.new(10, 14, 2)
	torso:ApplyImpulse(dir * torso.AssemblyMass)
	torso:ApplyAngularImpulse(Vector3.new(4, 2, -6) * torso.AssemblyMass)
	trackF2(ragdoll, ttl)
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
