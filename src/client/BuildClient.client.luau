--!nonstrict
-- Cliente da S4: camera isometrica fixa + UI de build 5x5 + HUD de debug (FPS/tempos).
-- O cliente so manda intencao (place/remove/upgrade); o servidor valida no WallService e
-- devolve o snapshot. A muralha real e a do perfil, nao a peca visual.
-- Estado, HUD e layout sao modulos puros em src/shared/build (provados no CLI); aqui so
-- desenhamos. Layout: 375x812 e 720x1280 sao os alvos do QA (docs/teste-s4-studio.md §4).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local sharedBuild = ReplicatedStorage:WaitForChild("Shared"):WaitForChild("build")
local GridLayout = require(sharedBuild:WaitForChild("GridLayout"))
local BuildClientState = require(sharedBuild:WaitForChild("BuildClientState"))
local BuildHud = require(sharedBuild:WaitForChild("BuildHud"))
local BuildLayout = require(sharedBuild:WaitForChild("BuildLayout"))

local startedAt = os.clock()

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

-- ---------------------------------------------------------------- estado e HUD
local state = BuildClientState.new()
local hud = BuildHud.new(startedAt)
local currentLayout = nil

local statusMessages = {
	no_snapshot = "Aguarde o perfil carregar",
	no_trap = "Escolha uma armadilha",
	bad_cell = "Celula invalida",
	cell_occupied = "Celula ocupada",
	empty_cell = "Celula vazia",
	bad_mode = "Modo invalido",
}

local function statusFor(err: string?): string
	return statusMessages[err or ""] or ("Recusado: " .. tostring(err))
end

-- ---------------------------------------------------------------- UI
local gui = Instance.new("ScreenGui")
gui.Name = "BuildGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = false
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

local function limitText(parent: Instance, maxSize: number): UITextSizeConstraint
	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MinTextSize = 8
	constraint.MaxTextSize = maxSize
	constraint.Parent = parent
	return constraint
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
goldLabel.Size = UDim2.new(0.55, 0, 1, 0)
goldLabel.Position = UDim2.fromOffset(12, 0)
goldLabel.BackgroundTransparency = 1
goldLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
goldLabel.TextXAlignment = Enum.TextXAlignment.Left
goldLabel.TextTruncate = Enum.TextTruncate.AtEnd
goldLabel.Font = Enum.Font.GothamBold
goldLabel.Text = "OURO 0"
goldLabel.Parent = top

local versionLabel = Instance.new("TextLabel")
versionLabel.Name = "Version"
versionLabel.Size = UDim2.new(0.43, -12, 1, 0)
versionLabel.Position = UDim2.new(0.55, 0, 0, 0)
versionLabel.BackgroundTransparency = 1
versionLabel.TextColor3 = Color3.fromRGB(180, 180, 190)
versionLabel.TextXAlignment = Enum.TextXAlignment.Right
versionLabel.TextTruncate = Enum.TextTruncate.AtEnd
versionLabel.Font = Enum.Font.Gotham
versionLabel.Text = "content v2"
versionLabel.Parent = top

-- HUD de debug da S4 (§6): FPS, tempo desde o Play e tempo ate a UI interativa.
local hudFrame = Instance.new("Frame")
hudFrame.Name = "Hud"
hudFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
hudFrame.BackgroundTransparency = 0.25
hudFrame.BorderSizePixel = 0
hudFrame.Parent = root
corner(hudFrame, 6)

local hudMetrics = Instance.new("TextLabel")
hudMetrics.Name = "Metrics"
hudMetrics.Size = UDim2.new(0.62, -8, 1, 0)
hudMetrics.Position = UDim2.fromOffset(8, 0)
hudMetrics.BackgroundTransparency = 1
hudMetrics.TextColor3 = Color3.fromRGB(150, 230, 170)
hudMetrics.TextXAlignment = Enum.TextXAlignment.Left
hudMetrics.TextTruncate = Enum.TextTruncate.AtEnd
hudMetrics.Font = Enum.Font.Code
hudMetrics.Text = "FPS -- · T -- · UI --"
hudMetrics.Parent = hudFrame

local hudSelection = Instance.new("TextLabel")
hudSelection.Name = "Selection"
hudSelection.Size = UDim2.new(0.38, -8, 1, 0)
hudSelection.Position = UDim2.new(0.62, 0, 0, 0)
hudSelection.BackgroundTransparency = 1
hudSelection.TextColor3 = Color3.fromRGB(235, 220, 150)
hudSelection.TextXAlignment = Enum.TextXAlignment.Right
hudSelection.TextTruncate = Enum.TextTruncate.AtEnd
hudSelection.Font = Enum.Font.GothamBold
hudSelection.Text = "COLOCAR"
hudSelection.Parent = hudFrame

local gridFrame = Instance.new("Frame")
gridFrame.Name = "Grid"
gridFrame.BackgroundTransparency = 1
gridFrame.Parent = root

local gridLayout = Instance.new("UIGridLayout")
gridLayout.FillDirection = Enum.FillDirection.Horizontal
gridLayout.FillDirectionMaxCells = GridLayout.WIDTH
gridLayout.CellSize = UDim2.fromOffset(48, 48)
gridLayout.CellPadding = UDim2.fromOffset(4, 4)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridFrame

local cellButtons: { [string]: TextButton } = {}

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
			limitText(button, 20)
			cellButtons[cell] = button
		end
	end
end

local bottom = Instance.new("Frame")
bottom.Name = "Bottom"
bottom.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
bottom.BackgroundTransparency = 0.12
bottom.BorderSizePixel = 0
bottom.Parent = root
corner(bottom, 10)

local modes = Instance.new("Frame")
modes.Name = "Modes"
modes.BackgroundTransparency = 1
modes.Parent = bottom

local modeLayout = Instance.new("UIListLayout")
modeLayout.FillDirection = Enum.FillDirection.Horizontal
modeLayout.Padding = UDim.new(0, 6)
modeLayout.SortOrder = Enum.SortOrder.LayoutOrder
modeLayout.Parent = modes

local modeButtons: { [string]: TextButton } = {}
local function makeMode(order: number, id: string, text: string): TextButton
	local button = Instance.new("TextButton")
	button.Name = id
	button.LayoutOrder = order
	button.Size = UDim2.new(0.32, -4, 1, 0)
	button.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
	button.BorderSizePixel = 0
	button.TextColor3 = Color3.fromRGB(235, 235, 240)
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.Parent = modes
	corner(button, 6)
	limitText(button, 20)
	modeButtons[id] = button
	return button
end

makeMode(1, "place", "COLOCAR")
makeMode(2, "remove", "REMOVER")
makeMode(3, "upgrade", "UPGRADE")

local trapRow = Instance.new("Frame")
trapRow.Name = "Traps"
trapRow.BackgroundTransparency = 1
trapRow.Parent = bottom

local trapLayout = Instance.new("UIListLayout")
trapLayout.FillDirection = Enum.FillDirection.Horizontal
trapLayout.Padding = UDim.new(0, 6)
trapLayout.SortOrder = Enum.SortOrder.LayoutOrder
trapLayout.Parent = trapRow

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "Status"
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(170, 220, 255)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextTruncate = Enum.TextTruncate.AtEnd
statusLabel.Font = Enum.Font.Gotham
statusLabel.Text = "carregando perfil..."
statusLabel.Parent = bottom

local trapButtons: { [string]: TextButton } = {}

-- ---------------------------------------------------------------- acoes
local function setStatus(text: string): ()
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

local function refreshSelection(): ()
	local trapLabel = nil
	if state.selectedTrap ~= nil then
		trapLabel = GridLayout.labelFor(state.selectedTrap)
	end
	hudSelection.Text = BuildHud.formatSelection(state.mode, trapLabel)
end

local function clearTrapHighlight(): ()
	for _, button in pairs(trapButtons) do
		button.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
	end
end

local function selectTrap(trapId: string): ()
	if not BuildClientState.selectTrap(state, trapId) then
		return
	end
	updateModeButtons()
	clearTrapHighlight()
	local button = trapButtons[trapId]
	if button ~= nil then
		button.BackgroundColor3 = colorFor(trapId)
	end
	refreshSelection()
	setStatus("Colocando " .. (GridLayout.labelFor(trapId) or trapId))
end

local function ensureTrapButtons(catalog: { any }): ()
	for index, entry in ipairs(catalog) do
		local id = entry.id
		if trapButtons[id] == nil then
			local button = Instance.new("TextButton")
			button.Name = id
			button.LayoutOrder = index
			button.BackgroundColor3 = Color3.fromRGB(45, 45, 52)
			button.BorderSizePixel = 0
			button.TextColor3 = Color3.fromRGB(235, 235, 240)
			button.TextScaled = true
			button.Font = Enum.Font.GothamBold
			button.Text = string.format("%s\n%d", GridLayout.labelFor(id) or id, entry.cost)
			button.Parent = trapRow
			corner(button, 6)
			limitText(button, 18)
			if currentLayout ~= nil then
				button.Size =
					UDim2.fromOffset(currentLayout.trapButton.w, currentLayout.trapButton.h)
			else
				button.Size = UDim2.new(0.19, -4, 1, 0)
			end
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
		local entry = BuildClientState.catalogEntry(state, id)
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
	BuildClientState.setSnapshot(state, snapshot)
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

	local wasReady = hud.uiSeconds ~= nil
	local uiSeconds = BuildHud.markReady(hud, os.clock())
	if not wasReady then
		print(string.format("[build] cliente pronto em %.1fs", uiSeconds))
	end
end

local function send(action: string, trapId: string, cell: string): ()
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

local function onCell(cell: string): ()
	local intent, err = BuildClientState.intent(state, cell, GridLayout)
	if intent == nil then
		setStatus(statusFor(err))
		return
	end
	send(intent.action, intent.trapId, intent.cell)
end

-- ---------------------------------------------------------------- layout
local function applyLayout(): ()
	local size = root.AbsoluteSize
	local layout = BuildLayout.compute(size.X, size.Y)
	if layout == nil then
		return
	end
	currentLayout = layout

	top.Position = UDim2.fromOffset(layout.top.x, layout.top.y)
	top.Size = UDim2.fromOffset(layout.top.w, layout.top.h)
	goldLabel.TextSize = layout.topFont
	versionLabel.TextSize = layout.topFont

	hudFrame.Position = UDim2.fromOffset(layout.hud.x, layout.hud.y)
	hudFrame.Size = UDim2.fromOffset(layout.hud.w, layout.hud.h)
	hudMetrics.TextSize = layout.hudFont
	hudSelection.TextSize = layout.hudFont

	gridFrame.Position = UDim2.fromOffset(layout.grid.x, layout.grid.y)
	gridFrame.Size = UDim2.fromOffset(layout.grid.w, layout.grid.h)
	gridLayout.CellSize = UDim2.fromOffset(layout.cellSize, layout.cellSize)
	gridLayout.CellPadding = UDim2.fromOffset(layout.cellPadding, layout.cellPadding)
	for _, button in pairs(cellButtons) do
		local constraint = button:FindFirstChildOfClass("UITextSizeConstraint")
		if constraint ~= nil then
			constraint.MaxTextSize = layout.cellFont
		end
	end

	bottom.Position = UDim2.fromOffset(layout.bottom.x, layout.bottom.y)
	bottom.Size = UDim2.fromOffset(layout.bottom.w, layout.bottom.h)

	modes.Position =
		UDim2.fromOffset(layout.modes.x - layout.bottom.x, layout.modes.y - layout.bottom.y)
	modes.Size = UDim2.fromOffset(layout.modes.w, layout.modes.h)
	modeLayout.Padding = UDim.new(0, layout.modeButton.gap)
	for _, button in pairs(modeButtons) do
		button.Size = UDim2.fromOffset(layout.modeButton.w, layout.modeButton.h)
		local constraint = button:FindFirstChildOfClass("UITextSizeConstraint")
		if constraint ~= nil then
			constraint.MaxTextSize = layout.modeButton.font
		end
	end

	trapRow.Position =
		UDim2.fromOffset(layout.traps.x - layout.bottom.x, layout.traps.y - layout.bottom.y)
	trapRow.Size = UDim2.fromOffset(layout.traps.w, layout.traps.h)
	trapLayout.Padding = UDim.new(0, layout.trapButton.gap)
	for _, button in pairs(trapButtons) do
		button.Size = UDim2.fromOffset(layout.trapButton.w, layout.trapButton.h)
		local constraint = button:FindFirstChildOfClass("UITextSizeConstraint")
		if constraint ~= nil then
			constraint.MaxTextSize = layout.trapButton.font
		end
	end

	statusLabel.Position =
		UDim2.fromOffset(layout.status.x - layout.bottom.x, layout.status.y - layout.bottom.y)
	statusLabel.Size = UDim2.fromOffset(layout.status.w, layout.status.h)
	statusLabel.TextSize = layout.statusFont
end

root:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyLayout)
task.defer(applyLayout)

-- ---------------------------------------------------------------- ligacoes
for id, button in pairs(modeButtons) do
	button.MouseButton1Click:Connect(function()
		if BuildClientState.setMode(state, id) then
			updateModeButtons()
			clearTrapHighlight()
			refreshSelection()
		end
	end)
end

for cell, button in pairs(cellButtons) do
	button.MouseButton1Click:Connect(function()
		onCell(cell)
	end)
end

updateModeButtons()
refreshSelection()

task.spawn(function()
	for attempt = 1, 60 do
		local ok, snapshot = pcall(function()
			return buildSnapshot:InvokeServer()
		end)
		if ok and type(snapshot) == "table" then
			refresh(snapshot)
			setStatus("Muralha carregada")
			return
		end
		if attempt == 1 then
			setStatus("Aguardando perfil...")
		end
		task.wait(0.5)
	end
	setStatus("Perfil nao carregou em 30s")
end)

local hudAccumulator = 0
RunService.RenderStepped:Connect(function(dt: number)
	local now = os.clock()
	BuildHud.tick(hud, now)
	hudAccumulator += dt
	if hudAccumulator >= 0.1 then
		hudAccumulator = 0
		hudMetrics.Text = BuildHud.formatMetrics(hud, now)
	end
end)
