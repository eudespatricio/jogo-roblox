--!nonstrict
-- S8: horda cosmetica (3 silhuetas) para drop-in e replay. O cliente escolhe o tipo por lane/
-- indice; a simulacao e o resultado continuam no servidor/Core. Sem mudanca de gameplay.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local VisualTheme = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("visual"):WaitForChild("VisualTheme")
)

local HordeKit = {}

local function rgb(value: { number }): Color3
	return Color3.fromRGB(value[1], value[2], value[3])
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
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanTouch = false
	piece.CanQuery = false
	piece.CastShadow = true
	piece.Material = material or Enum.Material.SmoothPlastic
	piece.Color = color
	if shape ~= nil then
		piece.Shape = shape
	end
	piece.Parent = parent
	return piece
end

local function eye(model: Instance, position: Vector3): Part
	return makePart(
		model,
		"Eye",
		Vector3.new(0.16, 0.16, 0.16),
		position,
		Color3.fromRGB(220, 255, 245),
		Enum.Material.Neon,
		Enum.PartType.Ball
	)
end

local function runner(model: Model, spec: any): ()
	local body = makePart(
		model,
		"Body",
		Vector3.new(1.2, 1.4, 0.9),
		Vector3.new(0, 1.15, 0),
		rgb(spec.color),
		Enum.Material.SmoothPlastic
	)
	model.PrimaryPart = body
	makePart(
		model,
		"Head",
		Vector3.new(0.9, 0.9, 0.9),
		Vector3.new(0, 2.15, 0),
		rgb(VisualTheme.shade(spec.color, 0.8)),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	for side = -1, 1, 2 do
		makePart(
			model,
			"Leg" .. tostring(side),
			Vector3.new(0.3, 0.85, 0.3),
			Vector3.new(side * 0.35, 0.45, 0),
			rgb(spec.dark),
			Enum.Material.SmoothPlastic
		)
		makePart(
			model,
			"Arm" .. tostring(side),
			Vector3.new(0.25, 0.9, 0.25),
			Vector3.new(side * 0.7, 1.2, 0),
			rgb(spec.dark),
			Enum.Material.SmoothPlastic
		)
	end
	makePart(
		model,
		"Horn",
		Vector3.new(0.18, 0.8, 0.18),
		Vector3.new(0, 2.7, 0),
		rgb(VisualTheme.PALETTE.iron),
		Enum.Material.Metal
	)
	eye(model, Vector3.new(0.18, 2.25, -0.42))
	eye(model, Vector3.new(-0.18, 2.25, -0.42))
end

local function brute(model: Model, spec: any): ()
	local body = makePart(
		model,
		"Body",
		Vector3.new(2.3, 2.2, 1.4),
		Vector3.new(0, 1.75, 0),
		rgb(spec.color),
		Enum.Material.SmoothPlastic
	)
	model.PrimaryPart = body
	makePart(
		model,
		"Head",
		Vector3.new(1.2, 1.2, 1.2),
		Vector3.new(0, 3.25, 0),
		rgb(VisualTheme.shade(spec.color, 0.75)),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	for side = -1, 1, 2 do
		makePart(
			model,
			"Leg" .. tostring(side),
			Vector3.new(0.5, 1.0, 0.5),
			Vector3.new(side * 0.55, 0.5, 0),
			rgb(spec.dark),
			Enum.Material.SmoothPlastic
		)
		makePart(
			model,
			"Shoulder" .. tostring(side),
			Vector3.new(0.7, 0.7, 0.7),
			Vector3.new(side * 1.35, 2.2, 0),
			rgb(VisualTheme.PALETTE.iron),
			Enum.Material.Metal,
			Enum.PartType.Ball
		)
	end
	makePart(
		model,
		"Cleaver",
		Vector3.new(0.15, 1.8, 0.8),
		Vector3.new(1.5, 1.7, 0),
		rgb(VisualTheme.PALETTE.iron),
		Enum.Material.Metal
	)
	eye(model, Vector3.new(0.25, 3.35, -0.55))
	eye(model, Vector3.new(-0.25, 3.35, -0.55))
end

local function swarm(model: Model, spec: any): ()
	local body = makePart(
		model,
		"Body",
		Vector3.new(0.9, 0.9, 0.9),
		Vector3.new(0, 0.9, 0),
		rgb(spec.color),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	model.PrimaryPart = body
	makePart(
		model,
		"Head",
		Vector3.new(0.55, 0.55, 0.55),
		Vector3.new(0, 1.55, 0),
		rgb(VisualTheme.shade(spec.color, 0.8)),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	for side = -1, 1, 2 do
		makePart(
			model,
			"Swarmling" .. tostring(side),
			Vector3.new(0.55, 0.55, 0.55),
			Vector3.new(side * 0.65, 0.55, side * 0.25),
			rgb(VisualTheme.shade(spec.color, 0.9)),
			Enum.Material.SmoothPlastic,
			Enum.PartType.Ball
		)
		makePart(
			model,
			"Leg" .. tostring(side),
			Vector3.new(0.16, 0.45, 0.16),
			Vector3.new(side * 0.3, 0.25, 0),
			rgb(spec.dark),
			Enum.Material.SmoothPlastic
		)
	end
	eye(model, Vector3.new(0.14, 1.62, -0.24))
	eye(model, Vector3.new(-0.14, 1.62, -0.24))
end

function HordeKit.create(kind: string, parent: Instance, cframe: CFrame): any?
	local spec = VisualTheme.ENEMIES[kind] or VisualTheme.ENEMIES.runner
	local model = Instance.new("Model")
	model.Name = "Horde_" .. kind
	model:SetAttribute("Kind", kind)
	if kind == "brute" then
		brute(model, spec)
	elseif kind == "swarm" then
		swarm(model, spec)
	else
		runner(model, spec)
	end
	model.Parent = parent
	model:PivotTo(cframe)
	model:ScaleTo(spec.scale)
	return {
		model = model,
		base = cframe,
		phase = (cframe.Position.X + cframe.Position.Z) * 0.1,
		kind = kind,
	}
end

function HordeKit.setBase(unit: any, cframe: CFrame): ()
	unit.base = cframe
end

function HordeKit.step(unit: any, now: number, moving: boolean): ()
	if unit == nil or unit.model == nil or unit.model.Parent == nil then
		return
	end
	local bob = 0
	local tilt = 0
	if moving then
		local phase = now * VisualTheme.MOTION.bobSpeed + unit.phase
		bob = math.sin(phase) * VisualTheme.MOTION.bobAmplitude
		tilt = math.sin(phase * 0.5) * 0.04
	end
	unit.model:PivotTo(unit.base * CFrame.new(0, bob, 0) * CFrame.Angles(0, 0, tilt))
end

function HordeKit.setVisible(unit: any, visible: boolean): ()
	if unit == nil or unit.model == nil then
		return
	end
	for _, descendant in ipairs(unit.model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = visible and 0 or 1
		end
	end
end

return HordeKit
