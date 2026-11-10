--!nonstrict
-- S8: kit visual das 5 armadilhas. Constroi modelos de pecas (madeira/ferro/neon) no lugar dos
-- cubos com BillboardGui. O nivel aparece em pinos de ambar; o modelo e cosmetico e nao toca
-- no WallService nem no motor.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local VisualTheme = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("visual"):WaitForChild("VisualTheme")
)
local GridLayout = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("build"):WaitForChild("GridLayout")
)

local TrapKit = {}

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
	piece.Material = material or Enum.Material.SmoothPlastic
	piece.Color = color
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	if shape ~= nil then
		piece.Shape = shape
	end
	piece.Parent = parent
	return piece
end

local function makeWedge(
	parent: Instance,
	name: string,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	material: Enum.Material?
): WedgePart
	local piece = Instance.new("WedgePart")
	piece.Name = name
	piece.Size = size
	piece.CFrame = CFrame.new(offset)
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanTouch = false
	piece.CanQuery = false
	piece.Material = material or Enum.Material.SmoothPlastic
	piece.Color = color
	piece.Parent = parent
	return piece
end

local function addPips(model: Model): ()
	for index = 1, 3 do
		local pip = makePart(
			model,
			"LevelPip" .. tostring(index),
			Vector3.new(0.26, 0.16, 0.26),
			Vector3.new(-1.2 + index * 0.6, 0.34, 2.25),
			rgb(VisualTheme.PALETTE.amber),
			Enum.Material.Neon
		)
		pip.Transparency = 1
	end
end

local function archer(model: Model, spec: any): ()
	makePart(
		model,
		"TowerBase",
		Vector3.new(2.8, 0.5, 2.8),
		Vector3.new(0, 0.45, 0),
		rgb(VisualTheme.PALETTE.woodDark),
		Enum.Material.WoodPlanks
	)
	makePart(
		model,
		"TowerBody",
		Vector3.new(2.4, 3.4, 2.4),
		Vector3.new(0, 2.35, 0),
		rgb(VisualTheme.PALETTE.wood),
		Enum.Material.WoodPlanks
	)
	makeWedge(
		model,
		"TowerRoof",
		Vector3.new(3.0, 1.3, 3.0),
		Vector3.new(0, 4.55, 0),
		rgb(spec.accent),
		Enum.Material.WoodPlanks
	)
	makePart(
		model,
		"Banner",
		Vector3.new(0.12, 2.0, 1.2),
		Vector3.new(1.25, 3.1, 0),
		rgb(VisualTheme.PALETTE.amber),
		Enum.Material.Fabric
	)
	makePart(
		model,
		"ArcherBody",
		Vector3.new(0.55, 1.0, 0.55),
		Vector3.new(0, 3.25, 0.8),
		rgb(VisualTheme.PALETTE.amber),
		Enum.Material.SmoothPlastic
	)
	makePart(
		model,
		"ArcherHead",
		Vector3.new(0.52, 0.52, 0.52),
		Vector3.new(0, 3.95, 0.8),
		rgb(VisualTheme.PALETTE.parchment),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Ball
	)
	makePart(
		model,
		"Bow",
		Vector3.new(0.12, 1.2, 0.12),
		Vector3.new(0.45, 3.25, 1.15),
		rgb(VisualTheme.PALETTE.woodDark),
		Enum.Material.Wood
	)
end

local function tar(model: Model, spec: any): ()
	local pool = makePart(
		model,
		"TarPool",
		Vector3.new(0.3, 4.4, 4.4),
		Vector3.new(0, 0.35, 0),
		rgb(spec.color),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	pool.Transparency = 0.05
	for index = 1, 3 do
		makePart(
			model,
			"TarBubble" .. tostring(index),
			Vector3.new(0.55, 0.4, 0.55),
			Vector3.new(-0.9 + index * 0.9, 0.55, -0.6 + (index % 2) * 1.2),
			rgb(VisualTheme.shade(spec.color, 1.35)),
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
	end
end

local function frost(model: Model, spec: any): ()
	makePart(
		model,
		"FrostBase",
		Vector3.new(4.4, 0.3, 4.4),
		Vector3.new(0, 0.35, 0),
		rgb(VisualTheme.PALETTE.stoneDark),
		Enum.Material.Ice
	)
	for index = -1, 1 do
		local crystal = makePart(
			model,
			"Crystal" .. tostring(index + 2),
			Vector3.new(0.55, 3.2 - math.abs(index) * 0.6, 0.55),
			Vector3.new(index * 0.95, 1.8 - math.abs(index) * 0.2, 0),
			rgb(spec.color),
			Enum.Material.Neon
		)
		crystal.CFrame = crystal.CFrame
			* CFrame.Angles(math.rad(8 * index), 0, math.rad(12 * index))
	end
	makePart(
		model,
		"FrostGlow",
		Vector3.new(4.6, 0.2, 4.6),
		Vector3.new(0, 0.54, 0),
		rgb(spec.accent),
		Enum.Material.Neon
	).Transparency =
		0.55
end

local function cannon(model: Model, spec: any): ()
	makePart(
		model,
		"Carriage",
		Vector3.new(3.2, 0.8, 2.2),
		Vector3.new(0, 0.9, 0),
		rgb(VisualTheme.PALETTE.wood),
		Enum.Material.WoodPlanks
	)
	for side = -1, 1, 2 do
		local wheel = makePart(
			model,
			"Wheel" .. tostring(side),
			Vector3.new(0.35, 1.25, 1.25),
			Vector3.new(0, 0.8, side * 1.35),
			rgb(VisualTheme.PALETTE.woodDark),
			Enum.Material.Wood,
			Enum.PartType.Cylinder
		)
		wheel.CFrame = wheel.CFrame * CFrame.Angles(0, 0, math.rad(90))
	end
	local barrel = makePart(
		model,
		"Barrel",
		Vector3.new(2.8, 1.15, 1.15),
		Vector3.new(0.35, 1.8, 0),
		rgb(spec.color),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	barrel.CFrame = barrel.CFrame
	local muzzle = makePart(
		model,
		"Muzzle",
		Vector3.new(0.4, 1.4, 1.4),
		Vector3.new(1.8, 1.8, 0),
		rgb(VisualTheme.PALETTE.ironDark),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	muzzle.CFrame = muzzle.CFrame
end

local function catapult(model: Model, spec: any): ()
	makePart(
		model,
		"Frame",
		Vector3.new(3.8, 0.55, 2.6),
		Vector3.new(0, 0.85, 0),
		rgb(VisualTheme.PALETTE.woodDark),
		Enum.Material.WoodPlanks
	)
	for side = -1, 1, 2 do
		local wheel = makePart(
			model,
			"Wheel" .. tostring(side),
			Vector3.new(0.4, 1.5, 1.5),
			Vector3.new(0, 0.8, side * 1.55),
			rgb(VisualTheme.PALETTE.wood),
			Enum.Material.Wood,
			Enum.PartType.Cylinder
		)
		wheel.CFrame = wheel.CFrame * CFrame.Angles(0, 0, math.rad(90))
	end
	local arm = makePart(
		model,
		"Arm",
		Vector3.new(0.4, 0.4, 4.4),
		Vector3.new(-0.2, 2.2, 0),
		rgb(spec.accent),
		Enum.Material.Wood
	)
	arm.CFrame = arm.CFrame * CFrame.Angles(0, 0, math.rad(-35))
	makePart(
		model,
		"Counterweight",
		Vector3.new(1.1, 1.1, 1.1),
		Vector3.new(-1.9, 1.2, 0),
		rgb(VisualTheme.PALETTE.iron),
		Enum.Material.Metal,
		Enum.PartType.Ball
	)
	makePart(
		model,
		"Basket",
		Vector3.new(1.1, 0.5, 1.1),
		Vector3.new(1.6, 2.9, 0),
		rgb(VisualTheme.PALETTE.wood),
		Enum.Material.WoodPlanks
	)
end

function TrapKit.create(trapId: string, level: number, parent: Instance, cframe: CFrame): Model?
	local spec = VisualTheme.TRAPS[trapId]
	if spec == nil then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Trap_" .. trapId
	model:SetAttribute("TrapId", trapId)
	model:SetAttribute("Level", level)

	local base = makePart(
		model,
		"Base",
		Vector3.new(4.8, 0.3, 4.8),
		Vector3.new(0, 0.15, 0),
		rgb(VisualTheme.PALETTE.stone),
		Enum.Material.Slate
	)
	base.CanQuery = false
	model.PrimaryPart = base
	addPips(model)

	if trapId == "archer" then
		archer(model, spec)
	elseif trapId == "tar" then
		tar(model, spec)
	elseif trapId == "frost" then
		frost(model, spec)
	elseif trapId == "cannon" then
		cannon(model, spec)
	elseif trapId == "catapult" then
		catapult(model, spec)
	end

	model.Parent = parent
	model:PivotTo(cframe)
	TrapKit.setLevel(model, level)
	return model
end

function TrapKit.setLevel(model: Model, level: number): ()
	local clamped = math.clamp(level, 1, 3)
	model:SetAttribute("Level", clamped)
	for index = 1, 3 do
		local pip = model:FindFirstChild("LevelPip" .. tostring(index))
		if pip ~= nil and pip:IsA("BasePart") then
			pip.Transparency = index <= clamped and 0 or 1
		end
	end
end

function TrapKit.pulse(model: Model): ()
	local highlight = Instance.new("Highlight")
	highlight.Name = "PlacePulse"
	highlight.Adornee = model
	highlight.FillColor = rgb(VisualTheme.PALETTE.amber)
	highlight.FillTransparency = 0.55
	highlight.OutlineTransparency = 1
	highlight.Parent = model
	TweenService:Create(
		highlight,
		TweenInfo.new(VisualTheme.MOTION.hitFlash * 2.5, Enum.EasingStyle.Quad),
		{ FillTransparency = 1 }
	):Play()
	task.delay(VisualTheme.MOTION.hitFlash * 3, function()
		if highlight.Parent ~= nil then
			highlight:Destroy()
		end
	end)
end

local function ensureFolder(parent: Instance): Folder
	local existing = parent:FindFirstChild("MuralhaTraps")
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	if existing ~= nil then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "MuralhaTraps"
	folder.Parent = parent
	return folder
end

function TrapKit.sync(
	parent: Instance,
	cells: { [string]: { trap: string, level: number } },
	origin: Vector3
): ()
	local folder = ensureFolder(parent)
	local alive: { [string]: boolean } = {}
	for cell, data in pairs(cells) do
		local row, col = GridLayout.parseCell(cell)
		if row ~= nil and col ~= nil then
			alive[cell] = true
			local x, _, z = GridLayout.cellPosition(row, col)
			local model = folder:FindFirstChild("Trap_" .. cell)
			local target = CFrame.new(origin + Vector3.new(x, 0.4, z))
			if model == nil then
				model = TrapKit.create(data.trap, data.level, folder, target)
				if model ~= nil then
					model.Name = "Trap_" .. cell
					TrapKit.pulse(model)
				end
			elseif model:IsA("Model") then
				model:PivotTo(target)
				local currentTrap = model:GetAttribute("TrapId")
				if currentTrap ~= data.trap then
					model:Destroy()
					model = TrapKit.create(data.trap, data.level, folder, target)
					if model ~= nil then
						model.Name = "Trap_" .. cell
					end
				else
					TrapKit.setLevel(model, data.level)
				end
			end
		end
	end
	for _, child in ipairs(folder:GetChildren()) do
		local cell = string.gsub(child.Name, "^Trap_", "")
		if child:IsA("Model") and not alive[cell] then
			child:Destroy()
		end
	end
end

function TrapKit.clear(parent: Instance): ()
	local existing = parent:FindFirstChild("MuralhaTraps")
	if existing ~= nil then
		existing:Destroy()
	end
end

return TrapKit
