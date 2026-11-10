--!strict
-- Cena 5x5 da S4: cria o grid visual e os marcadores das armadilhas no Workspace.
-- Server-only; o cliente so desenha a UI e manda intencao. A parede real e do perfil,
-- validada por WallService.toBattleWall antes de qualquer batalha.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GridLayout = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("build"):WaitForChild("GridLayout")
)

local BuildGrid = {}

local folder: Folder? = nil
local cellParts: { [string]: BasePart } = {}
local trapParts: { [string]: BasePart } = {}

local function ensureFolder(): Folder
	if folder ~= nil and folder.Parent ~= nil then
		return folder
	end
	local existing = workspace:FindFirstChild("MuralhaGrid")
	if existing ~= nil and existing:IsA("Folder") then
		folder = existing
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "MuralhaGrid"
	created.Parent = workspace
	folder = created
	return created
end

local function cellPart(cell: string): BasePart?
	return cellParts[cell]
end

local function makeMarkers()
	for _, cell in ipairs(GridLayout.allCells()) do
		local part = cellPart(cell)
		assert(part ~= nil, "celula sem parte: " .. cell)
		part:SetAttribute("Cell", cell)
	end
end

function BuildGrid.init(): ()
	local root = ensureFolder()
	if next(cellParts) ~= nil then
		return
	end

	for row = 1, GridLayout.HEIGHT do
		for col = 1, GridLayout.WIDTH do
			local cell = GridLayout.cellName(row, col)
			if cell ~= nil then
				local x, y, z = GridLayout.cellPosition(row, col)
				local part = Instance.new("Part")
				part.Name = "Cell_" .. cell
				part.Size = Vector3.new(GridLayout.CELL_SIZE - 0.5, 0.3, GridLayout.CELL_SIZE - 0.5)
				part.Position = Vector3.new(x, y, z)
				part.Anchored = true
				part.CanCollide = false
				part.CanTouch = false
				part.CanQuery = false
				part.Material = Enum.Material.SmoothPlastic
				part.Color = Color3.fromRGB(66, 66, 72)
				part.Transparency = 0.35
				part:SetAttribute("Cell", cell)
				part:SetAttribute("Row", row)
				part:SetAttribute("Col", col)
				part.Parent = root
				cellParts[cell] = part
			end
		end
	end

	-- Muralha visual no lado c1 (a "parede" que o jogador defende).
	local wall = Instance.new("Part")
	wall.Name = "Muralha"
	wall.Size = Vector3.new(2, 8, GridLayout.HEIGHT * GridLayout.CELL_SIZE + 2)
	wall.Position = Vector3.new(GridLayout.WALL_X, 4, 0)
	wall.Anchored = true
	wall.CanCollide = false
	wall.CanTouch = false
	wall.CanQuery = false
	wall.Material = Enum.Material.WoodPlanks
	wall.Color = Color3.fromRGB(120, 82, 45)
	wall.Parent = root

	makeMarkers()
end

local function markerFor(cell: string): BasePart
	local existing = trapParts[cell]
	if existing ~= nil and existing.Parent ~= nil then
		return existing
	end
	local root = ensureFolder()
	local part = Instance.new("Part")
	part.Name = "Trap_" .. cell
	part.Size = Vector3.new(4.2, 1.6, 4.2)
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Material = Enum.Material.SmoothPlastic
	part:SetAttribute("Cell", cell)
	part.Parent = root

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(90, 24)
	billboard.StudsOffset = Vector3.new(0, 2.2, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 80
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard

	trapParts[cell] = part
	return part
end

-- Atualiza os marcadores a partir de `profile.wall.cells`. Idempotente: chamar de novo
-- com a mesma parede nao cria pecas duplicadas.
function BuildGrid.refresh(cells: { [string]: { trap: string, level: number } }): ()
	BuildGrid.init()
	local alive: { [string]: boolean } = {}
	for cell, data in pairs(cells) do
		local row, col = GridLayout.parseCell(cell)
		if row ~= nil and col ~= nil then
			alive[cell] = true
			local x, y, z = GridLayout.cellPosition(row, col)
			local part = markerFor(cell)
			part.Position = Vector3.new(x, y + 1.2, z)
			local color = GridLayout.colorFor(data.trap)
			if color ~= nil then
				part.Color = Color3.fromRGB(
					math.floor(color[1] * 255 + 0.5),
					math.floor(color[2] * 255 + 0.5),
					math.floor(color[3] * 255 + 0.5)
				)
			else
				part.Color = Color3.fromRGB(90, 90, 90)
			end
			local label = part:FindFirstChild("Label")
			if label ~= nil and label:IsA("BillboardGui") then
				local text = label:FindFirstChild("Text")
				if text ~= nil and text:IsA("TextLabel") then
					local name = GridLayout.labelFor(data.trap) or data.trap
					text.Text = string.format("%s L%d", name, data.level)
				end
			end
		end
	end
	for cell, part in pairs(trapParts) do
		if not alive[cell] then
			part:Destroy()
			trapParts[cell] = nil
		end
	end
end

function BuildGrid.clear(): ()
	for _, part in pairs(trapParts) do
		part:Destroy()
	end
	trapParts = {}
end

return BuildGrid
