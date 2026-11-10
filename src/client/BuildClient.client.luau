--!nonstrict
-- S8: cliente de build. Camera isometrica, arena de diorama, traps 3D e UI de cartoes.
-- O servidor continua autoritativo (WallService/BuildProtocol); aqui so desenhamos e mandamos
-- intencao. O HUD de debug da S4 vive atras de F3 e nasce oculto.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local sharedBuild = Shared:WaitForChild("build")
local GridLayout = require(sharedBuild:WaitForChild("GridLayout"))
local BuildClientState = require(sharedBuild:WaitForChild("BuildClientState"))
local BuildHud = require(sharedBuild:WaitForChild("BuildHud"))
local BuildLayout = require(sharedBuild:WaitForChild("BuildLayout"))
local VisualTheme = require(Shared:WaitForChild("visual"):WaitForChild("VisualTheme"))

local visual = script.Parent:WaitForChild("visual")
local UiKit = require(visual:WaitForChild("UiKit"))
local VisualSetup = require(visual:WaitForChild("VisualSetup"))
local ArenaVisual = require(visual:WaitForChild("ArenaVisual"))
local TrapKit = require(visual:WaitForChild("TrapKit"))
local AudioKit = require(visual:WaitForChild("AudioKit"))
local Vfx = require(visual:WaitForChild("Vfx"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local remotes = ReplicatedStorage:WaitForChild("MuralhaRemotes")
local buildAction = remotes:WaitForChild("BuildAction") :: RemoteFunction
local buildSnapshot = remotes:WaitForChild("BuildSnapshot") :: RemoteFunction

local function waitForDropIn(): ()
	for _ = 1, 50 do
		if ReplicatedStorage:GetAttribute("DropInEnabled") ~= nil then
			break
		end
		task.wait(0.1)
	end
	if ReplicatedStorage:GetAttribute("DropInEnabled") ~= true then
		return
	end
	while player:GetAttribute("DropInDone") ~= true do
		task.wait(0.1)
	end
end

waitForDropIn()

local camera = Workspace.CurrentCamera
if camera == nil then
	camera = Workspace:WaitForChild("Camera") :: Camera
end
camera.CameraType = Enum.CameraType.Scriptable
local BASE_CAMERA = CFrame.lookAt(Vector3.new(48, 34, 52), Vector3.new(0, 2, 0))
camera.CFrame = BASE_CAMERA
camera.FieldOfView = 40

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

VisualSetup.apply()
ArenaVisual.build(Workspace, Vector3.new(0, 0, 0))

local state = BuildClientState.new()
local hud = BuildHud.new(time())
local currentLayout = nil

local statusMessages = {
	no_snapshot = "Aguarde o perfil carregar",
	no_trap = "Escolha uma armadilha",
	bad_cell = "Celula invalida",
	cell_occupied = "Celula ocupada",
	empty_cell = "Celula vazia",
	bad_mode = "Modo invalido",
	insufficient_gold = "Ouro insuficiente",
	max_level = "Nivel maximo",
	gold_cap = "Ouro no teto",
	trap_locked = "Armadilha bloqueada",
	trap_limit = "Limite de 5 armadilhas",
	unknown_trap = "Armadilha desconhecida",
	content_version = "Conteudo desatualizado",
	content_future = "Conteudo futuro",
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

local top = UiKit.panel(root, "TopBar")
local coin = UiKit.iconCoin(top, 22)
coin.AnchorPoint = Vector2.new(0, 0.5)
coin.Position = UDim2.new(0, 10, 0.5, 0)

local goldLabel = UiKit.label(
	top,
	"Gold",
	"0",
	UiKit.color(VisualTheme.PALETTE.amberBright),
	Enum.Font.GothamBlack
)
goldLabel.Position = UDim2.new(0, 40, 0, 0)
goldLabel.Size = UDim2.new(0.34, -40, 1, 0)
goldLabel.TextScaled = true

local leagueLabel = UiKit.label(
	top,
	"League",
	"LIGA 1",
	UiKit.color(VisualTheme.PALETTE.parchment),
	Enum.Font.GothamBold
)
leagueLabel.Position = UDim2.new(0.34, 0, 0, 0)
leagueLabel.Size = UDim2.new(0.33, 0, 1, 0)
leagueLabel.TextXAlignment = Enum.TextXAlignment.Center
leagueLabel.TextScaled = true

local versionLabel =
	UiKit.label(top, "Version", "v2", UiKit.color(VisualTheme.PALETTE.stone), Enum.Font.Gotham)
versionLabel.Position = UDim2.new(0.67, 0, 0, 0)
versionLabel.Size = UDim2.new(0.33, -10, 1, 0)
versionLabel.TextXAlignment = Enum.TextXAlignment.Right
versionLabel.TextScaled = true

local selectionBar = UiKit.panel(root, "SelectionBar")
local selectionLabel = UiKit.label(
	selectionBar,
	"Selection",
	"COLOCAR · ESCOLHA UMA ARMADILHA",
	UiKit.color(VisualTheme.PALETTE.parchment),
	Enum.Font.GothamBold
)
selectionLabel.Position = UDim2.fromOffset(10, 0)
selectionLabel.Size = UDim2.new(1, -20, 1, 0)
selectionLabel.TextScaled = true

local gridFrame = Instance.new("Frame")
gridFrame.Name = "Grid"
gridFrame.BackgroundTransparency = 1
gridFrame.Parent = root

local gridLayout = Instance.new("UIGridLayout")
gridLayout.FillDirection = Enum.FillDirection.Horizontal
gridLayout.FillDirectionMaxCells = GridLayout.WIDTH
gridLayout.CellSize = UDim2.fromOffset(48, 48)
gridLayout.CellPadding = UDim2.fromOffset(5, 5)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridFrame

local cellButtons: { [string]: TextButton } = {}

local send: (action: string, trapId: string, cell: string) -> ()
local setStatus: (text: string) -> ()

local function makeCellButton(cell: string, row: number, col: number): TextButton
	local button = Instance.new("TextButton")
	button.Name = cell
	button.LayoutOrder = row * 10 + col
	button.Text = ""
	button.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.stoneDark)
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Parent = gridFrame
	UiKit.corner(button, 7)
	UiKit.stroke(button, UiKit.color(VisualTheme.PALETTE.iron), 1, 0.25)

	local nameLabel = UiKit.label(
		button,
		"Name",
		"",
		UiKit.color(VisualTheme.PALETTE.parchment),
		Enum.Font.GothamBlack
	)
	nameLabel.Position = UDim2.new(0, 3, 0, 4)
	nameLabel.Size = UDim2.new(1, -6, 0.58, -4)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextScaled = true

	local levelLabel = UiKit.label(
		button,
		"Level",
		"",
		UiKit.color(VisualTheme.PALETTE.ink),
		Enum.Font.GothamBlack
	)
	levelLabel.AnchorPoint = Vector2.new(1, 1)
	levelLabel.Position = UDim2.new(1, -5, 1, -3)
	levelLabel.Size = UDim2.fromOffset(22, 14)
	levelLabel.TextXAlignment = Enum.TextXAlignment.Right
	levelLabel.TextScaled = true

	button.MouseButton1Click:Connect(function()
		local intent, err = BuildClientState.intent(state, cell, GridLayout)
		if intent == nil then
			AudioKit.play("ui_deny")
			setStatus(statusFor(err))
			return
		end
		if intent.action == "upgrade" then
			local cost = BuildClientState.upgradeCost(state, cell)
			local data = state.snapshot and state.snapshot.cells[cell]
			if cost ~= nil and data ~= nil then
				local label = GridLayout.labelFor(data.trap) or data.trap
				setStatus(
					string.format(
						"UPGRADE %s L%d→L%d · %d OURO",
						label,
						data.level,
						data.level + 1,
						cost
					)
				)
			end
		end
		send(intent.action, intent.trapId, intent.cell)
	end)
	return button
end

for row = 1, GridLayout.HEIGHT do
	for col = 1, GridLayout.WIDTH do
		local cell = GridLayout.cellName(row, col)
		if cell ~= nil then
			cellButtons[cell] = makeCellButton(cell, row, col)
		end
	end
end

local bottom = UiKit.panel(root, "Bottom")
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
	local button = UiKit.button(modes, id, text)
	button.LayoutOrder = order
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

local statusLabel = UiKit.label(
	bottom,
	"Status",
	"carregando perfil...",
	UiKit.color(VisualTheme.PALETTE.stone),
	Enum.Font.Gotham
)
statusLabel.TextTruncate = Enum.TextTruncate.AtEnd

local debugHud = UiKit.panel(root, "DebugHud")
debugHud.Visible = VisualTheme.UI.debugHudDefault
local debugMetrics = UiKit.label(
	debugHud,
	"Metrics",
	"FPS -- · T -- · UI --",
	UiKit.color(VisualTheme.PALETTE.teal),
	Enum.Font.Code
)
debugMetrics.Position = UDim2.fromOffset(8, 0)
debugMetrics.Size = UDim2.new(1, -16, 1, 0)
debugMetrics.TextScaled = false
debugMetrics.TextSize = 11

-- ---------------------------------------------------------------- acoes
setStatus = function(text: string): ()
	statusLabel.Text = text
	statusLabel.TextColor3 = UiKit.color(VisualTheme.PALETTE.stone)
end

local function colorFor(trapId: string): Color3
	local color = GridLayout.colorFor(trapId)
	if color == nil then
		return UiKit.color(VisualTheme.PALETTE.stone)
	end
	return Color3.fromRGB(
		math.floor(color[1] * 255 + 0.5),
		math.floor(color[2] * 255 + 0.5),
		math.floor(color[3] * 255 + 0.5)
	)
end

local function updateModeButtons(): ()
	for id, button in pairs(modeButtons) do
		UiKit.setSelected(button, id == state.mode)
	end
end

local function refreshSelection(): ()
	local trapLabel = nil
	if state.selectedTrap ~= nil then
		trapLabel = GridLayout.labelFor(state.selectedTrap)
	end
	local mode = state.mode
	if mode == "place" then
		selectionLabel.Text = "COLOCAR · " .. (trapLabel or "ESCOLHA UMA ARMADILHA")
	elseif mode == "remove" then
		selectionLabel.Text = "REMOVER · TOQUE NA ARMADILHA"
	else
		selectionLabel.Text = "UPGRADE · TOQUE NA ARMADILHA"
	end
end

local trapCards: { [string]: any } = {}
local updateCardAffordability: () -> ()

local function clearCardHighlight(): ()
	for _, card in pairs(trapCards) do
		UiKit.setSelected(card.frame, false)
	end
end

local function selectTrap(trapId: string): ()
	if not BuildClientState.selectTrap(state, trapId) then
		return
	end
	AudioKit.play("ui_click")
	updateModeButtons()
	clearCardHighlight()
	local card = trapCards[trapId]
	if card ~= nil then
		UiKit.setSelected(card.frame, true)
	end
	refreshSelection()
	updateCardAffordability()
	setStatus("Colocando " .. (GridLayout.labelFor(trapId) or trapId))
end

local function ensureTrapCards(catalog: { any }): ()
	for index, entry in ipairs(catalog) do
		local id = entry.id
		if trapCards[id] == nil then
			local card = UiKit.card(trapRow, id)
			card.frame.LayoutOrder = index
			if currentLayout ~= nil then
				card.frame.Size =
					UDim2.fromOffset(currentLayout.trapButton.w, currentLayout.trapButton.h)
			end
			card.frame.MouseButton1Click:Connect(function()
				selectTrap(id)
			end)
			trapCards[id] = card
		end
	end
end

updateCardAffordability = function(): ()
	local snapshot = state.snapshot
	if snapshot == nil then
		return
	end
	for id, card in pairs(trapCards) do
		local entry = BuildClientState.catalogEntry(state, id)
		local spec = VisualTheme.TRAPS[id]
		if entry ~= nil and spec ~= nil then
			if entry.unlockLeague > snapshot.league then
				card.cost.Text = "LIGA " .. tostring(entry.unlockLeague)
				card.cost.TextColor3 = UiKit.color(VisualTheme.PALETTE.stone)
				card.icon.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.iron)
				card.icon.Glyph.Text = spec.icon
				card.icon.Glyph.TextColor3 = UiKit.color(VisualTheme.PALETTE.stone)
			elseif state.mode == "upgrade" then
				local low, high = BuildClientState.upgradeRange(entry)
				card.cost.Text = string.format("%s/%s", tostring(low), tostring(high))
				card.cost.TextColor3 = UiKit.color(VisualTheme.PALETTE.amberBright)
				card.icon.BackgroundColor3 = UiKit.color(spec.color)
				card.icon.Glyph.Text = spec.icon
				card.icon.Glyph.TextColor3 = UiKit.color(VisualTheme.PALETTE.ink)
			elseif state.mode == "remove" then
				card.cost.Text = "REMOVER"
				card.cost.TextColor3 = UiKit.color(VisualTheme.PALETTE.stone)
				card.icon.BackgroundColor3 = UiKit.color(spec.color)
				card.icon.Glyph.Text = spec.icon
				card.icon.Glyph.TextColor3 = UiKit.color(VisualTheme.PALETTE.ink)
			else
				card.cost.Text = tostring(entry.cost) .. " OURO"
				card.cost.TextColor3 = UiKit.color(VisualTheme.PALETTE.amberBright)
				card.icon.BackgroundColor3 = UiKit.color(spec.color)
				card.icon.Glyph.Text = spec.icon
				card.icon.Glyph.TextColor3 = UiKit.color(VisualTheme.PALETTE.ink)
			end
			card.name.Text = spec.label
		end
	end
end

local function refresh(snapshot: any): ()
	BuildClientState.setSnapshot(state, snapshot)
	goldLabel.Text = tostring(snapshot.gold)
	leagueLabel.Text = "LIGA " .. tostring(snapshot.league)
	versionLabel.Text =
		string.format("v%d · c%d", snapshot.schemaVersion or 2, snapshot.contentVersion or 2)
	ensureTrapCards(snapshot.catalog)
	updateCardAffordability()

	for cell, button in pairs(cellButtons) do
		local data = snapshot.cells[cell]
		local nameLabel = button:FindFirstChild("Name")
		local levelLabel = button:FindFirstChild("Level")
		if data ~= nil then
			local spec = VisualTheme.TRAPS[data.trap]
			button.BackgroundColor3 = colorFor(data.trap)
			UiKit.stroke(button, UiKit.color(VisualTheme.PALETTE.amberBright), 2, 0)
			if nameLabel ~= nil and nameLabel:IsA("TextLabel") then
				nameLabel.Text = spec ~= nil and spec.icon
					or string.upper(string.sub(data.trap, 1, 1))
				nameLabel.TextColor3 = UiKit.color(VisualTheme.PALETTE.ink)
			end
			if levelLabel ~= nil and levelLabel:IsA("TextLabel") then
				levelLabel.Text = "L" .. tostring(data.level)
				levelLabel.TextColor3 = UiKit.color(VisualTheme.PALETTE.ink)
			end
		else
			button.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.stoneDark)
			UiKit.stroke(button, UiKit.color(VisualTheme.PALETTE.iron), 1, 0.25)
			if nameLabel ~= nil and nameLabel:IsA("TextLabel") then
				nameLabel.Text = ""
			end
			if levelLabel ~= nil and levelLabel:IsA("TextLabel") then
				levelLabel.Text = ""
			end
		end
	end
	TrapKit.sync(Workspace, snapshot.cells, Vector3.new(0, 0, 0))

	local wasReady = hud.uiSeconds ~= nil
	local uiSeconds = BuildHud.markReady(hud)
	if not wasReady then
		print(string.format("[build] cliente pronto em %.1fs", uiSeconds))
	end
end

local function positionOfCell(cell: string): Vector3?
	local row, col = GridLayout.parseCell(cell)
	if row == nil or col == nil then
		return nil
	end
	local x, _, z = GridLayout.cellPosition(row, col)
	if x == nil or z == nil then
		return nil
	end
	return Vector3.new(x, 0.6, z)
end

send = function(action: string, trapId: string, cell: string): ()
	local ok, result = pcall(function()
		return buildAction:InvokeServer(action, trapId, cell)
	end)
	if not ok or type(result) ~= "table" then
		AudioKit.play("ui_deny")
		setStatus("Servidor indisponivel")
		return
	end
	if result.ok then
		if action == "place" then
			AudioKit.play("trap_place")
			local position = positionOfCell(cell)
			if position ~= nil then
				Vfx.dust(Workspace, position, 5)
			end
		else
			AudioKit.play("trap_upgrade")
		end
		if result.snapshot ~= nil then
			refresh(result.snapshot)
		end
		local charged = result.result and result.result.cost
		if action == "upgrade" and type(charged) == "number" then
			setStatus(string.format("UPGRADE OK · -%d ouro", charged))
		else
			setStatus("OK")
		end
	else
		AudioKit.play("ui_deny")
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
	leagueLabel.TextSize = layout.topFont
	versionLabel.TextSize = math.max(10, layout.topFont - 2)

	selectionBar.Position = UDim2.fromOffset(layout.hud.x, layout.hud.y)
	selectionBar.Size = UDim2.fromOffset(layout.hud.w, layout.hud.h)
	selectionLabel.TextSize = layout.hudFont

	gridFrame.Position = UDim2.fromOffset(layout.grid.x, layout.grid.y)
	gridFrame.Size = UDim2.fromOffset(layout.grid.w, layout.grid.h)
	gridLayout.CellSize = UDim2.fromOffset(layout.cellSize, layout.cellSize)
	gridLayout.CellPadding = UDim2.fromOffset(layout.cellPadding, layout.cellPadding)
	for _, button in pairs(cellButtons) do
		local nameLabel = button:FindFirstChild("Name")
		local levelLabel = button:FindFirstChild("Level")
		if nameLabel ~= nil and nameLabel:IsA("TextLabel") then
			nameLabel.TextSize = layout.cellFont
		end
		if levelLabel ~= nil and levelLabel:IsA("TextLabel") then
			levelLabel.TextSize = math.max(8, math.floor(layout.cellFont * 0.7))
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
	for _, card in pairs(trapCards) do
		card.frame.Size = UDim2.fromOffset(layout.trapButton.w, layout.trapButton.h)
	end

	statusLabel.Position =
		UDim2.fromOffset(layout.status.x - layout.bottom.x, layout.status.y - layout.bottom.y)
	statusLabel.Size = UDim2.fromOffset(layout.status.w, layout.status.h)
	statusLabel.TextSize = layout.statusFont

	debugHud.Position = UDim2.fromOffset(layout.top.x, layout.top.y + layout.top.h + 4)
	debugHud.Size = UDim2.fromOffset(math.min(240, layout.top.w), 20)
end

root:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyLayout)
task.defer(applyLayout)

-- ---------------------------------------------------------------- ligacoes
for id, button in pairs(modeButtons) do
	button.MouseButton1Click:Connect(function()
		if BuildClientState.setMode(state, id) then
			AudioKit.play("ui_click")
			updateModeButtons()
			clearCardHighlight()
			refreshSelection()
			updateCardAffordability()
		end
	end)
end

local function toggleDebug(): ()
	debugHud.Visible = not debugHud.Visible
end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.F3 then
		toggleDebug()
	end
end)

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

player:GetAttributeChangedSignal("MuralhaGold"):Connect(function()
	if state.snapshot == nil then
		return
	end
	local ok, snapshot = pcall(function()
		return buildSnapshot:InvokeServer()
	end)
	if ok and type(snapshot) == "table" then
		refresh(snapshot)
	end
end)

local hudAccumulator = 0
RunService.RenderStepped:Connect(function(dt: number)
	BuildHud.tick(hud, dt)
	hudAccumulator += dt
	if hudAccumulator >= 0.2 then
		hudAccumulator = 0
		debugMetrics.Text = BuildHud.formatMetrics(hud)
	end
end)
