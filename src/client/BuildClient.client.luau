--!nonstrict
-- Cliente da S4: camera isometrica fixa + UI de build 5x5.
-- O cliente so manda intencao (place/remove/upgrade); o servidor valida no WallService e
-- devolve o snapshot. A muralha real e a do perfil, nao a peca visual.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GridLayout = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("build"):WaitForChild("GridLayout")
)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("MuralhaRemotes")
local buildAction = remotes:WaitForChild("BuildAction") :: RemoteFunction
local buildSnapshot = remotes:WaitForChild("BuildSnapshot") :: RemoteFunction

-- Camera isometrica fixa (GDD §1: sem livre-orbitar; vira clipe).
local camera = Workspace.CurrentCamera
if camera == nil then
	camera = Workspace:WaitForChild("Camera") :: Camera
end
camera.CameraType = Enum.CameraType.Scriptable
camera.CFrame = CFrame.lookAt(Vector3.new(50, 46, 62), Vector3.new(0, 2, 0))
camera.FieldOfView = 42

local function hideCharacter(character: Model): ()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid ~= nil then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CanCollide = false
		end
	end
end

if player.Character ~= nil then
	hideCharacter(player.Character)
end
player.CharacterAdded:Connect(hideCharacter)

-- ---------------------------------------------------------------- UI
local gui = Instance.new("ScreenGui")
gui.Name = "BuildGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 10
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.Parent = gui

local function corner(parent: Instance, radius: number): ()
	local uiCorner = Instance.new("UICorner")
	uiCorner.CornerRadius = UDim.new(0, radius)
	uiCorner.Parent = parent
end

local top = Instance.new("Frame")
top.Name = "TopBar"
top.Size = UDim2.new(1, -24, 0, 42)
top.Position = UDim2.fromOffset(12, 12)
top.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
top.BackgroundTransparency = 0.15
top.BorderSizePixel = 0
top.Parent = root
corner(top, 8)

local goldLabel = Instance.new("TextLabel")
goldLabel.Name = "Gold"
goldLabel.Size = UDim2.new(0.5, 0, 1, 0)
goldLabel.Position = UDim2.fromOffset(12, 0)
goldLabel.BackgroundTransparency = 1
goldLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
goldLabel.TextXAlignment = Enum.TextXAlignment.Left
goldLabel.TextScaled = true
goldLabel.Font = Enum.Font.GothamBold
goldLabel.Text = "OURO 0"
goldLabel.Parent = top

local versionLabel = Instance.new("TextLabel")
versionLabel.Name = "Version"
versionLabel.Size = UDim2.new(0.48, -12, 1, 0)
versionLabel.Position = UDim2.new(0.52, 0, 0, 0)
versionLabel.BackgroundTransparency = 1
versionLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
versionLabel.TextXAlignment = Enum.TextXAlignment.Right
versionLabel.TextScaled = true
versionLabel.Font = Enum.Font.Gotham
versionLabel.Text = "content v2"
versionLabel.Parent = top

local gridFrame = Instance.new("Frame")
gridFrame.Name = "Grid"
gridFrame.AnchorPoint = Vector2.new(0.5, 0.5)
gridFrame.Position = UDim2.fromScale(0.68, 0.5)
gridFrame.Size = UDim2.fromScale(0.42, 0.62)
gridFrame.BackgroundTransparency = 1
gridFrame.Parent = root

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.fromScale(0.2, 0.2)
gridLayout.CellPadding = UDim2.fromOffset(4, 4)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridFrame

local cellButtons: { [string]: TextButton } = {}

local state = {
	snapshot = nil :: any,
	selectedTrap = nil :: string?,
	mode = "place",
}
local setStatus: (string) -> ()
local send: (string, string, string) -> ()

local function onCell(cell: string): ()
	if state.snapshot == nil then
		setStatus("Aguarde o perfil carregar")
		return
	end
	if state.mode == "place" then
		if state.selectedTrap == nil then
			setStatus("Escolha uma armadilha")
			return
		end
		send("place", state.selectedTrap, cell)
	elseif state.mode == "remove" then
		send("remove", "", cell)
	else
		send("upgrade", "", cell)
	end
end

for row = 1, GridLayout.HEIGHT do
	for col = 1, GridLayout.WIDTH do
		local cell = GridLayout.cellName(row, col)
		if cell ~= nil then
			local button = Instance.new("TextButton")
			button.Name = cell
			button.LayoutOrder = row * 10 + col
			button.Text = ""
			button.BackgroundColor3 = Color3.fromRGB(55, 55, 62)
			button.BorderSizePixel = 0
			button.TextColor3 = Color3.fromRGB(240, 240, 240)
			button.TextScaled = true
			button.Font = Enum.Font.GothamBold
			button.AutoButtonColor = true
			button.Parent = gridFrame
			corner(button, 6)
			button.MouseButton1Click:Connect(function()
				onCell(cell)
			end)
			cellButtons[cell] = button
		end
	end
end

local bottom = Instance.new("Frame")
bottom.Name = "Bottom"
bottom.AnchorPoint = Vector2.new(0.5, 1)
bottom.Position = UDim2.new(0.5, 0, 1, -12)
bottom.Size = UDim2.new(0.96, -24, 0, 168)
bottom.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
bottom.BackgroundTransparency = 0.12
bottom.BorderSizePixel = 0
bottom.Parent = root
corner(bottom, 10)

local modeRow = Instance.new("Frame")
modeRow.Name = "Modes"
modeRow.Size = UDim2.new(1, -16, 0, 38)
modeRow.Position = UDim2.fromOffset(8, 8)
modeRow.BackgroundTransparency = 1
modeRow.Parent = bottom

local modeLayout = Instance.new("UIListLayout")
modeLayout.FillDirection = Enum.FillDirection.Horizontal
modeLayout.Padding = UDim.new(0, 6)
modeLayout.Parent = modeRow

local modeButtons: { [string]: TextButton } = {}
local function makeMode(id: string, text: string): TextButton
	local button = Instance.new("TextButton")
	button.Name = id
	button.Size = UDim2.new(1 / 3, -4, 1, 0)
	button.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
	button.BorderSizePixel = 0
	button.TextColor3 = Color3.fromRGB(235, 235, 240)
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.Parent = modeRow
	corner(button, 6)
	modeButtons[id] = button
	return button
end

makeMode("place", "COLOCAR")
makeMode("remove", "REMOVER")
makeMode("upgrade", "UPGRADE")

local trapRow = Instance.new("Frame")
trapRow.Name = "Traps"
trapRow.Size = UDim2.new(1, -16, 0, 54)
trapRow.Position = UDim2.fromOffset(8, 54)
trapRow.BackgroundTransparency = 1
trapRow.Parent = bottom

local trapLayout = Instance.new("UIListLayout")
trapLayout.FillDirection = Enum.FillDirection.Horizontal
trapLayout.Padding = UDim.new(0, 6)
trapLayout.Parent = trapRow

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.Size = UDim2.new(1, -16, 0, 22)
statusLabel.Position = UDim2.new(0, 8, 1, -28)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(170, 220, 255)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextScaled = true
statusLabel.Font = Enum.Font.Gotham
statusLabel.Text = "carregando perfil..."
statusLabel.Parent = bottom

local trapButtons: { [string]: TextButton } = {}

function setStatus(text: string): ()
	statusLabel.Text = text
end

local function colorFor(trapId: string): Color3
	local color = GridLayout.colorFor(trapId)
	if color == nil then
		return Color3.fromRGB(90, 90, 90)
	end
	return Color3.fromRGB(
		math.floor(color[1] * 255 + 0.5),
		math.floor(color[2] * 255 + 0.5),
		math.floor(color[3] * 255 + 0.5)
	)
end

local function updateModeButtons(): ()
	for id, button in pairs(modeButtons) do
		if id == state.mode then
			button.BackgroundColor3 = Color3.fromRGB(70, 130, 90)
		else
			button.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
		end
	end
end

local function selectTrap(trapId: string): ()
	state.selectedTrap = trapId
	state.mode = "place"
	updateModeButtons()
	for id, button in pairs(trapButtons) do
		if id == trapId then
			button.BackgroundColor3 = colorFor(trapId)
		else
			button.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
		end
	end
	setStatus("Colocando " .. (GridLayout.labelFor(trapId) or trapId))
end

local function ensureTrapButtons(catalog: { any }): ()
	for _, entry in ipairs(catalog) do
		local id = entry.id
		if trapButtons[id] == nil then
			local button = Instance.new("TextButton")
			button.Name = id
			button.Size = UDim2.new(0.2, -5, 1, 0)
			button.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
			button.BorderSizePixel = 0
			button.TextColor3 = Color3.fromRGB(235, 235, 240)
			button.TextScaled = true
			button.Font = Enum.Font.GothamBold
			button.Text = string.format("%s\n%d", GridLayout.labelFor(id) or id, entry.cost)
			button.Parent = trapRow
			corner(button, 6)
			button.MouseButton1Click:Connect(function()
				selectTrap(id)
			end)
			trapButtons[id] = button
		end
	end
end

local function updateTrapAffordability(): ()
	local snapshot = state.snapshot
	if snapshot == nil then
		return
	end
	for id, button in pairs(trapButtons) do
		local entry = nil
		for _, item in ipairs(snapshot.catalog) do
			if item.id == id then
				entry = item
				break
			end
		end
		if entry ~= nil then
			if entry.unlockLeague > snapshot.league then
				button.Text =
					string.format("%s\nliga %d", GridLayout.labelFor(id) or id, entry.unlockLeague)
				button.TextColor3 = Color3.fromRGB(140, 140, 145)
			else
				button.Text = string.format("%s\n%d", GridLayout.labelFor(id) or id, entry.cost)
				button.TextColor3 = Color3.fromRGB(235, 235, 240)
			end
		end
	end
end

local function refresh(snapshot: any): ()
	state.snapshot = snapshot
	goldLabel.Text = string.format("OURO %d", snapshot.gold)
	versionLabel.Text =
		string.format("content v%d · liga %d", snapshot.contentVersion, snapshot.league)
	ensureTrapButtons(snapshot.catalog)
	updateTrapAffordability()

	for cell, button in pairs(cellButtons) do
		local data = snapshot.cells[cell]
		if data ~= nil then
			local label = GridLayout.labelFor(data.trap) or data.trap
			button.Text = string.format("%s\nL%d", label, data.level)
			button.BackgroundColor3 = colorFor(data.trap)
			button.TextColor3 = Color3.fromRGB(255, 255, 255)
		else
			button.Text = ""
			button.BackgroundColor3 = Color3.fromRGB(55, 55, 62)
		end
	end
end

function send(action: string, trapId: string, cell: string): ()
	local ok, result = pcall(function()
		return buildAction:InvokeServer(action, trapId, cell)
	end)
	if not ok or type(result) ~= "table" then
		setStatus("Servidor indisponivel")
		return
	end
	if result.ok then
		if result.snapshot ~= nil then
			refresh(result.snapshot)
		end
		setStatus("OK")
	else
		setStatus("Recusado: " .. tostring(result.err))
	end
end

for id, button in pairs(modeButtons) do
	button.MouseButton1Click:Connect(function()
		state.mode = id
		state.selectedTrap = nil
		updateModeButtons()
		for _, trapButton in pairs(trapButtons) do
			trapButton.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
		end
	end)
end

updateModeButtons()

task.spawn(function()
	for _ = 1, 30 do
		local ok, snapshot = pcall(function()
			return buildSnapshot:InvokeServer()
		end)
		if ok and type(snapshot) == "table" then
			refresh(snapshot)
			setStatus("Muralha carregada")
			return
		end
		task.wait(0.5)
	end
	setStatus("Perfil ainda carregando; aguarde")
end)
