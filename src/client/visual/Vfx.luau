--!nonstrict
-- S8: VFX cosmeticos baratos (impacto, poeira, morte, projetil, anel e shake). Tudo local no
-- cliente; nao altera o resultado da batalha. Respeita o orcamento de VisualTheme.VFX.

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local VisualTheme = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("visual"):WaitForChild("VisualTheme")
)

local Vfx = {}

local function rgb(value: { number }): Color3
	return Color3.fromRGB(value[1], value[2], value[3])
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

local function fadeAndDestroy(piece: BasePart, lifetime: number): ()
	TweenService:Create(
		piece,
		TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Transparency = 1 }
	):Play()
	Debris:AddItem(piece, lifetime + 0.05)
end

function Vfx.impact(parent: Instance, position: Vector3, color: Color3, count: number?): ()
	local total = math.min(count or 6, VisualTheme.VFX.maxImpactParts)
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
	local total = math.min(count or 6, VisualTheme.VFX.maxDustParts)
	for index = 1, total do
		local piece = makePart(
			parent,
			Vector3.new(0.35, 0.35, 0.35),
			position + Vector3.new((index % 3) - 1, 0.2, ((index + 1) % 3) - 1) * 0.6,
			rgb(VisualTheme.PALETTE.stone),
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

local projectileColors = {
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
		return rgb(VisualTheme.PALETTE.teal)
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
	local color = (projectileColors[kind] or projectileColors.cannon)()
	local isArrow = kind == "arrow"
	local piece = makePart(
		parent,
		isArrow and Vector3.new(0.12, 0.12, 1.4) or Vector3.new(0.55, 0.55, 0.55),
		from,
		color,
		isArrow and Enum.Material.SmoothPlastic or Enum.Material.Slate,
		isArrow and nil or Enum.PartType.Ball
	)
	if isArrow then
		piece.CFrame = CFrame.lookAt(from, to)
	elseif kind == "frost" then
		piece.Material = Enum.Material.Neon
	end
	local travel = duration or 0.35
	local arc = kind == "boulder" and 5 or 2
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
		if piece.Parent ~= nil then
			Vfx.impact(parent, to, color, 5)
			piece:Destroy()
			if onHit ~= nil then
				onHit()
			end
		end
	end)
end

function Vfx.shake(camera: Camera, base: CFrame, intensity: number, duration: number): ()
	local elapsed = 0
	local connection
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
