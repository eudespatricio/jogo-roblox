--!strict
-- S8/S8.2: kit visual das 5 armadilhas (<=12 partes cada). Constroi modelos de pecas
-- (madeira/ferro/neon) com RankMast + 3 LevelChevrons, CanQuery+Cell para raycast 3D e
-- maquina de estado 60Hz (Deploy Pop 220ms -> Idle -> Fire Recoil).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local VisualTheme = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("visual"):WaitForChild("VisualTheme")
)
local GridLayout = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("build"):WaitForChild("GridLayout")
)
local MeshAssets = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("visual"):WaitForChild("MeshAssets")
)

local TrapKit = {}

local DEPLOY_POP_SEC = 0.22
local DEFAULT_FLOOR_TOP_Y = 0.33

type TrapSpec = {
	label: string,
	icon: string,
	color: { number },
	accent: { number },
	parts: number,
	height: number,
}

export type TrapData = {
	trap: string,
	level: number,
	x: number?,
	y: number?,
}

export type SyncOptions = {
	floorTopY: number?,
}

type MovingPartRest = {
	part: BasePart,
	restLocal: CFrame,
	role: string,
}

type TrapAnimState = {
	model: Model,
	trapId: string,
	baseCFrame: CFrame,
	deployElapsed: number,
	deployActive: boolean,
	recoilPos: number,
	recoilVel: number,
	recoilActive: boolean,
	movingParts: { MovingPartRest },
}

local animStates: { [Model]: TrapAnimState } = {}
local renderConn: RBXScriptConnection? = nil

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
	piece.CanQuery = true
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
	piece.CanQuery = true
	piece.Material = material or Enum.Material.SmoothPlastic
	piece.Color = color
	piece.Parent = parent
	return piece
end

local function addRankChevrons(container: Instance): ()
	local mast = makePart(
		container,
		"RankMast",
		Vector3.new(0.16, 1.8, 0.16),
		Vector3.new(2.1, 1.05, 2.1),
		rgb(VisualTheme.PALETTE.ironDark),
		Enum.Material.Metal
	)
	mast.CanQuery = false
	local cSize = VisualTheme.CHEVRON.size
	local chevronSize = Vector3.new(cSize[1], cSize[2], cSize[3])
	for index = 1, 3 do
		local chevron = makePart(
			container,
			"LevelChevron" .. tostring(index),
			chevronSize,
			Vector3.new(2.1, 1.4 + (index - 1) * 0.42, 2.1),
			rgb(VisualTheme.PALETTE.amber),
			Enum.Material.Neon
		)
		chevron.CanQuery = false
		chevron.Transparency = 1
	end
end

-- 6 partes + Base + BaseTrim + RankMast + 3 Chevrons = 12 partes (BUDGET.trapParts = 12).
local function archer(model: Instance, spec: TrapSpec): ()
	makePart(
		model,
		"TowerBody",
		Vector3.new(2.4, 3.7, 2.4),
		Vector3.new(0, 2.15, 0),
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

-- 4 partes + Base + RankMast + 3 Chevrons = 9 partes.
local function tar(model: Instance, spec: TrapSpec): ()
	local pool = makePart(
		model,
		"TarPool",
		Vector3.new(0.3, 4.4, 4.4),
		Vector3.new(0, 0.42, 0),
		rgb(spec.color),
		Enum.Material.SmoothPlastic,
		Enum.PartType.Cylinder
	)
	-- Cylinder do Roblox tem eixo em X; girar 90 deg em Z deixa o disco plano em Y.
	pool.CFrame = CFrame.new(0, 0.42, 0) * CFrame.Angles(0, 0, math.rad(90))
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

-- 5 partes + Base + RankMast + 3 Chevrons = 10 partes.
local function frost(model: Instance, spec: TrapSpec): ()
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

-- 5 partes + Base + RankMast + 3 Chevrons = 10 partes.
local function cannon(model: Instance, spec: TrapSpec): ()
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
	makePart(
		model,
		"Barrel",
		Vector3.new(2.8, 1.15, 1.15),
		Vector3.new(0.35, 1.8, 0),
		rgb(spec.color),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
	makePart(
		model,
		"Muzzle",
		Vector3.new(0.4, 1.4, 1.4),
		Vector3.new(1.8, 1.8, 0),
		rgb(VisualTheme.PALETTE.ironDark),
		Enum.Material.Metal,
		Enum.PartType.Cylinder
	)
end

-- 6 partes + Base + RankMast + 3 Chevrons = 11 partes.
local function catapult(model: Instance, spec: TrapSpec): ()
	makePart(
		model,
		"Frame",
		Vector3.new(3.8, 0.55, 2.6),
		Vector3.new(0, 0.85, 0),
		rgb(VisualTheme.PALETTE.woodDark),
		Enum.Material.WoodPlanks
	)
	for side = -1, 1, 2 do
		-- Wheel raio 0.75 sobre Base topo 0.30 => local Y = 1.05.
		local wheel = makePart(
			model,
			"Wheel" .. tostring(side),
			Vector3.new(0.4, 1.5, 1.5),
			Vector3.new(0, 1.05, side * 1.55),
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

local function collectMovingParts(model: Model, trapId: string): { MovingPartRest }
	local primary = model.PrimaryPart
	if primary == nil then
		return {}
	end
	local rootCF = primary.CFrame
	local targetNames: { [string]: boolean } = if trapId == "cannon"
		then { Barrel = true, Muzzle = true }
		elseif trapId == "catapult" then { Arm = true, Basket = true }
		elseif trapId == "archer" then { Bow = true, ArcherBody = true }
		elseif trapId == "frost" then { Crystal2 = true }
		else { TarBubble1 = true, TarBubble2 = true, TarBubble3 = true }

	local list: { MovingPartRest } = {}
	local proc = model:FindFirstChild("ProceduralVisual")
	local searchRoot: Instance = proc or model
	for _, child in ipairs(searchRoot:GetChildren()) do
		if child:IsA("BasePart") and targetNames[child.Name] then
			list[#list + 1] = {
				part = child,
				restLocal = rootCF:ToObjectSpace(child.CFrame),
				role = child.Name,
			}
		end
	end
	if #list == 0 then
		local meshVisual = model:FindFirstChild("MeshVisual")
		if meshVisual ~= nil then
			for _, descendant in ipairs(meshVisual:GetDescendants()) do
				if descendant:IsA("BasePart") then
					list[#list + 1] = {
						part = descendant,
						restLocal = rootCF:ToObjectSpace(descendant.CFrame),
						role = "MeshWhole",
					}
				end
			end
		end
	end
	return list
end

local function applyRecoilTransform(state: TrapAnimState, value: number): ()
	local primary = state.model.PrimaryPart
	if primary == nil then
		return
	end
	local rootCF = primary.CFrame
	for _, entry in ipairs(state.movingParts) do
		if entry.role == "MeshWhole" then
			local worldDelta = if state.trapId == "cannon"
				then CFrame.new(-0.45 * value, 0, 0)
				elseif state.trapId == "catapult" then CFrame.Angles(
					0,
					0,
					math.rad(-14 * value)
				)
				elseif state.trapId == "archer" then CFrame.Angles(0, 0, math.rad(-6 * value))
				elseif state.trapId == "frost" then CFrame.new(0, 0.25 * value, 0)
				else CFrame.new(0, 0.14 * value, 0)
			entry.part.CFrame = rootCF * worldDelta * entry.restLocal
		else
			local delta = if state.trapId == "cannon"
				then CFrame.new(-0.65 * value, 0, 0)
				elseif state.trapId == "catapult" then CFrame.Angles(
					0,
					0,
					math.rad(42 * value)
				)
				elseif state.trapId == "archer" then CFrame.Angles(math.rad(-6 * value), 0, 0)
				elseif state.trapId == "frost" then CFrame.new(0, 0.35 * value, 0) * CFrame.Angles(
					0,
					math.rad(120 * value),
					0
				)
				else CFrame.new(0, 0.25 * value, 0)
			entry.part.CFrame = rootCF * entry.restLocal * delta
		end
	end
end

local function ensureRenderLoop(): ()
	if renderConn ~= nil then
		return
	end
	renderConn = RunService.RenderStepped:Connect(function(dt: number)
		local anyActive = TrapKit.step(dt)
		if not anyActive and renderConn ~= nil then
			renderConn:Disconnect()
			renderConn = nil
		end
	end)
end

local function registerAnimState(model: Model, trapId: string, baseCFrame: CFrame): ()
	local state: TrapAnimState = {
		model = model,
		trapId = trapId,
		baseCFrame = baseCFrame,
		deployElapsed = 0,
		deployActive = true,
		recoilPos = 0,
		recoilVel = 0,
		recoilActive = false,
		movingParts = collectMovingParts(model, trapId),
	}
	animStates[model] = state
	model:ScaleTo(0.05)
	model:PivotTo(baseCFrame)
	ensureRenderLoop()
end

function TrapKit.step(dt: number): boolean
	local cDt = math.min(dt, 1 / 30)
	local anyActive = false
	for model, state in pairs(animStates) do
		if model.Parent == nil then
			animStates[model] = nil
			continue
		end

		if state.deployActive then
			state.deployElapsed += cDt
			local alpha = math.clamp(state.deployElapsed / DEPLOY_POP_SEC, 0, 1)
			local scale: number
			if alpha < 0.6 then
				local t = alpha / 0.6
				scale = 0.05 + 1.07 * t
			else
				local t = (alpha - 0.6) / 0.4
				scale = 1.12 - 0.12 * t
			end
			model:ScaleTo(math.max(0.05, scale))
			model:PivotTo(state.baseCFrame)
			if alpha >= 1 then
				state.deployActive = false
				model:ScaleTo(1)
				model:PivotTo(state.baseCFrame)
				state.movingParts = collectMovingParts(model, state.trapId)
			else
				anyActive = true
			end
		end

		if state.recoilActive then
			local zeta = 0.7
			local omega = 18
			local f = 1 + 2 * cDt * zeta * omega
			local oo = omega * omega
			local hoo = cDt * oo
			local hhoo = cDt * hoo
			local detInv = 1 / (f + hhoo)
			local detPos = f * state.recoilPos + cDt * state.recoilVel
			local detVel = state.recoilVel + hoo * (0 - state.recoilPos)
			state.recoilPos = detPos * detInv
			state.recoilVel = detVel * detInv

			if math.abs(state.recoilPos) < 0.005 and math.abs(state.recoilVel) < 0.01 then
				state.recoilPos = 0
				state.recoilVel = 0
				state.recoilActive = false
				applyRecoilTransform(state, 0)
			else
				applyRecoilTransform(state, state.recoilPos)
				anyActive = true
			end
		end
	end
	return anyActive
end

function TrapKit.fire(model: Model): ()
	local state = animStates[model]
	if state == nil or model.Parent == nil then
		return
	end
	if state.deployActive then
		state.deployActive = false
		model:ScaleTo(1)
		model:PivotTo(state.baseCFrame)
		state.movingParts = collectMovingParts(model, state.trapId)
	end
	state.recoilPos = 1
	state.recoilVel = -4
	state.recoilActive = true
	applyRecoilTransform(state, 1)
	ensureRenderLoop()
end

local pendingMeshModels: { [Model]: boolean } = {}
local assetsFolderConn: RBXScriptConnection? = nil
local repAddedConn: RBXScriptConnection? = nil

local function setPartQuerySlot(part: BasePart, slot: string?): ()
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = true
	if slot ~= nil then
		part:SetAttribute("Cell", slot)
		part:SetAttribute("Slot", slot)
	end
end

local function bindCellAttribute(model: Model, cell: string): ()
	model:SetAttribute("Cell", cell)
	model:SetAttribute("Slot", cell)
	local base = model.PrimaryPart
	if base ~= nil then
		base:SetAttribute("Cell", cell)
		base:SetAttribute("Slot", cell)
		base.CanQuery = true
	end
	local baseTrim = model:FindFirstChild("BaseTrim")
	if baseTrim ~= nil and baseTrim:IsA("BasePart") then
		baseTrim:SetAttribute("Cell", cell)
		baseTrim:SetAttribute("Slot", cell)
		baseTrim.CanQuery = true
	end
	local meshVisual = model:FindFirstChild("MeshVisual")
	if meshVisual ~= nil then
		if meshVisual:IsA("BasePart") then
			meshVisual:SetAttribute("Cell", cell)
			meshVisual:SetAttribute("Slot", cell)
			meshVisual.CanQuery = true
		else
			for _, desc in ipairs(meshVisual:GetDescendants()) do
				if desc:IsA("BasePart") then
					desc:SetAttribute("Cell", cell)
					desc:SetAttribute("Slot", cell)
					desc.CanQuery = true
				end
			end
		end
	end
end

local function tryMountTrapMesh(model: Model, trapId: string, level: number): boolean
	local assetsFolder = ReplicatedStorage:FindFirstChild(MeshAssets.FOLDER)
	if assetsFolder == nil then
		return false
	end
	local assetName = MeshAssets.trapModelName(trapId, level)
	local template = assetsFolder:FindFirstChild(assetName)
	if template == nil then
		return false
	end
	local primary = model.PrimaryPart
	if primary == nil then
		return false
	end

	local prevScale = model:GetScale()
	local anim = animStates[model]
	if prevScale ~= 1 then
		model:ScaleTo(1)
		if anim ~= nil then
			model:PivotTo(anim.baseCFrame)
		end
	end

	local oldMesh = model:FindFirstChild("MeshVisual")
	if oldMesh ~= nil then
		oldMesh:Destroy()
	end

	local slotAttr = model:GetAttribute("Slot")
	local cellAttr = model:GetAttribute("Cell")
	local slotStr: string? = if type(slotAttr) == "string"
		then slotAttr
		elseif type(cellAttr) == "string" then cellAttr
		else nil

	local clone = template:Clone()
	clone.Name = "MeshVisual"
	local orient = primary.CFrame.Rotation * CFrame.Angles(0, math.rad(-90), 0)
	local targetBottomY = primary.Position.Y - primary.Size.Y * 0.5

	if clone:IsA("Model") then
		for _, desc in ipairs(clone:GetDescendants()) do
			if desc:IsA("BasePart") then
				setPartQuerySlot(desc, slotStr)
			end
		end
		clone.Parent = model
		clone:PivotTo(CFrame.new(primary.Position) * orient)
		local bbCf, bbSize = clone:GetBoundingBox()
		local currentBottomY = bbCf.Position.Y - bbSize.Y * 0.5
		local dy = targetBottomY - currentBottomY
		clone:PivotTo(clone:GetPivot() + Vector3.new(0, dy, 0))
	elseif clone:IsA("BasePart") then
		setPartQuerySlot(clone, slotStr)
		clone.CFrame = CFrame.new(
			primary.Position.X,
			targetBottomY + clone.Size.Y * 0.5,
			primary.Position.Z
		) * orient
		clone.Parent = model
	else
		clone:Destroy()
		if prevScale ~= 1 then
			model:ScaleTo(prevScale)
			if anim ~= nil then
				model:PivotTo(anim.baseCFrame)
			end
		end
		return false
	end

	local proc = model:FindFirstChild("ProceduralVisual")
	if proc ~= nil then
		proc:Destroy()
	end
	primary.Transparency = 1
	local baseTrim = model:FindFirstChild("BaseTrim")
	if baseTrim ~= nil and baseTrim:IsA("BasePart") then
		baseTrim.Transparency = 1
	end

	model:SetAttribute("MeshLevel", level)
	if anim ~= nil then
		anim.movingParts = collectMovingParts(model, trapId)
	end
	if prevScale ~= 1 then
		model:ScaleTo(prevScale)
		if anim ~= nil then
			model:PivotTo(anim.baseCFrame)
		end
	end
	return true
end

local function flushPendingMeshes(): ()
	for model in pairs(pendingMeshModels) do
		if model.Parent == nil then
			pendingMeshModels[model] = nil
		else
			local trapIdAttr = model:GetAttribute("TrapId")
			local levelAttr = model:GetAttribute("Level")
			if type(trapIdAttr) == "string" and type(levelAttr) == "number" then
				local clamped = math.clamp(math.floor(levelAttr), 1, 5)
				if tryMountTrapMesh(model, trapIdAttr, clamped) then
					pendingMeshModels[model] = nil
				end
			end
		end
	end
end

local function ensureMeshWatcher(): ()
	local assetsFolder = ReplicatedStorage:FindFirstChild(MeshAssets.FOLDER)
	if assetsFolder ~= nil then
		if assetsFolderConn == nil then
			assetsFolderConn = assetsFolder.ChildAdded:Connect(function()
				flushPendingMeshes()
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
				ensureMeshWatcher()
				flushPendingMeshes()
			end
		end)
	end
end

function TrapKit.create(trapId: string, level: number, parent: Instance, cframe: CFrame): Model?
	local traps = VisualTheme.TRAPS :: { [string]: TrapSpec }
	local spec = traps[trapId]
	if spec == nil then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "Trap_" .. trapId
	model:SetAttribute("TrapId", trapId)
	model:SetAttribute("Level", level)

	-- Pedestal chanfrado pedra + colarinho de ferro sobre floorTopY (0.33 / 0.39).
	local base = makePart(
		model,
		"Base",
		Vector3.new(4.6, 0.3, 4.6),
		Vector3.new(0, 0.15, 0),
		Color3.fromRGB(118, 122, 130),
		Enum.Material.Slate
	)
	base.CanQuery = true
	model.PrimaryPart = base
	local baseTrim = makePart(
		model,
		"BaseTrim",
		Vector3.new(5.2, 0.14, 5.2),
		Vector3.new(0, 0.07, 0),
		rgb(VisualTheme.PALETTE.ironDark),
		Enum.Material.Metal
	)
	baseTrim.CanQuery = true

	local proc = Instance.new("Folder")
	proc.Name = "ProceduralVisual"
	proc.Parent = model
	addRankChevrons(proc)

	if trapId == "archer" then
		archer(proc, spec)
	elseif trapId == "tar" then
		tar(proc, spec)
	elseif trapId == "frost" then
		frost(proc, spec)
	elseif trapId == "cannon" then
		cannon(proc, spec)
	elseif trapId == "catapult" then
		catapult(proc, spec)
	end

	model.Parent = parent
	model:PivotTo(cframe)
	registerAnimState(model, trapId, cframe)
	TrapKit.setLevel(model, level)
	return model
end

function TrapKit.setLevel(model: Model, level: number): ()
	local clamped = math.clamp(math.floor(level), 1, 5)
	model:SetAttribute("Level", clamped)

	local proc = model:FindFirstChild("ProceduralVisual")
	if proc ~= nil then
		local chevronColor = if clamped >= 5
			then Color3.fromRGB(255, 245, 175)
			elseif clamped >= 4 then rgb(VisualTheme.PALETTE.teal)
			elseif clamped >= 2 then rgb(VisualTheme.PALETTE.amberBright)
			else rgb(VisualTheme.PALETTE.amber)
		local visibleCount = math.min(clamped, 3)
		for index = 1, 3 do
			local chevron = proc:FindFirstChild("LevelChevron" .. tostring(index))
			if chevron ~= nil and chevron:IsA("BasePart") then
				chevron.Color = chevronColor
				chevron.Transparency = if index <= visibleCount then 0 else 1
			end
		end
	end

	local trapIdAttr = model:GetAttribute("TrapId")
	local meshLevelAttr = model:GetAttribute("MeshLevel")
	if type(trapIdAttr) == "string" and meshLevelAttr ~= clamped then
		if tryMountTrapMesh(model, trapIdAttr, clamped) then
			pendingMeshModels[model] = nil
		else
			pendingMeshModels[model] = true
			ensureMeshWatcher()
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

local function resolveTrapWorldPos(
	slot: string,
	data: TrapData
): (number?, number?, number?, number?)
	if type(data.x) == "number" and type(data.y) == "number" then
		local wx, _, wz = GridLayout.arenaPosToWorld(data.x, data.y)
		return wx, wz, data.x, data.y
	end
	local wx, _, wz = GridLayout.cellToWorld(slot)
	local ax, ay = GridLayout.cellToArenaPos(slot)
	return wx, wz, ax, ay
end

function TrapKit.sync(
	parent: Instance,
	cells: { [string]: TrapData },
	origin: Vector3,
	options: SyncOptions?
): ()
	local folder = ensureFolder(parent)
	local floorTopY = if options ~= nil and type(options.floorTopY) == "number"
		then options.floorTopY :: number
		else DEFAULT_FLOOR_TOP_Y
	local alive: { [string]: boolean } = {}
	for slot, data in pairs(cells) do
		local x, z, ax, ay = resolveTrapWorldPos(slot, data)
		if x ~= nil and z ~= nil then
			alive[slot] = true
			local model = folder:FindFirstChild("Trap_" .. slot)
			-- Base tem altura 0.3 (centro local Y = 0.15) => Base Y = floorTopY + 0.15.
			local target = CFrame.new(origin + Vector3.new(x, floorTopY + 0.15, z))
			if model == nil then
				local created = TrapKit.create(data.trap, data.level, folder, target)
				if created ~= nil then
					created.Name = "Trap_" .. slot
					bindCellAttribute(created, slot)
					if ax ~= nil and ay ~= nil then
						created:SetAttribute("ArenaX", ax)
						created:SetAttribute("ArenaY", ay)
					end
					TrapKit.pulse(created)
				end
			elseif model:IsA("Model") then
				local anim = animStates[model]
				if anim ~= nil then
					anim.baseCFrame = target
				end
				model:PivotTo(target)
				bindCellAttribute(model, slot)
				if ax ~= nil and ay ~= nil then
					model:SetAttribute("ArenaX", ax)
					model:SetAttribute("ArenaY", ay)
				end
				local currentTrap = model:GetAttribute("TrapId")
				if currentTrap ~= data.trap then
					pendingMeshModels[model] = nil
					animStates[model] = nil
					model:Destroy()
					local replaced = TrapKit.create(data.trap, data.level, folder, target)
					if replaced ~= nil then
						replaced.Name = "Trap_" .. slot
						bindCellAttribute(replaced, slot)
						if ax ~= nil and ay ~= nil then
							replaced:SetAttribute("ArenaX", ax)
							replaced:SetAttribute("ArenaY", ay)
						end
					end
				else
					TrapKit.setLevel(model, data.level)
				end
			end
		end
	end
	for _, child in ipairs(folder:GetChildren()) do
		local slot = string.gsub(child.Name, "^Trap_", "")
		if child:IsA("Model") and not alive[slot] then
			pendingMeshModels[child] = nil
			animStates[child] = nil
			child:Destroy()
		end
	end
end

function TrapKit.clear(parent: Instance): ()
	local existing = parent:FindFirstChild("MuralhaTraps")
	if existing ~= nil then
		for _, child in ipairs(existing:GetChildren()) do
			if child:IsA("Model") then
				pendingMeshModels[child] = nil
				animStates[child] = nil
			end
		end
		existing:Destroy()
	end
end

return TrapKit
