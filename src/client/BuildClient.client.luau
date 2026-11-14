--!strict
-- S8: cliente de build. Camera isometrica, arena de diorama, traps 3D e UI de cartoes.
-- O servidor continua autoritativo (WallService/BuildProtocol); aqui so desenhamos e mandamos
-- intencao. O HUD de debug da S4 vive atras de F3 e nasce oculto.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local sharedBuild = Shared:WaitForChild("build")
local GridLayout = require(sharedBuild:WaitForChild("GridLayout"))
local BuildClientState = require(sharedBuild:WaitForChild("BuildClientState"))
local BuildHud = require(sharedBuild:WaitForChild("BuildHud"))
local BuildLayout = require(sharedBuild:WaitForChild("BuildLayout"))
local I18n = require(Shared:WaitForChild("i18n"):WaitForChild("I18n"))
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

local camera: Camera = if Workspace.CurrentCamera ~= nil
	then Workspace.CurrentCamera
	else Workspace:WaitForChild("Camera") :: Camera
local function refreshBuildCamera(): ()
	if Players.LocalPlayer and Players.LocalPlayer:GetAttribute("MuralhaInRaid") == true then
		return
	end
	local vp = camera.ViewportSize
	local cf, fov = UiKit.computeArenaCamera(Vector3.zero, vp.X, vp.Y, "build")
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = cf
	camera.FieldOfView = fov
end
refreshBuildCamera()
camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshBuildCamera)

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
ArenaVisual.build(Workspace, Vector3.new(0, 0, 0), { wallTier = 1 })
AudioKit.setMode("build")

local state = BuildClientState.new()
local hud = BuildHud.new(time())
local currentHudLayout: BuildLayout.HudLayout? = nil
local currentVersionText = "v3 · c3"
local selectedWorldSlot: string? = nil

local STATUS_I18N: { [string]: { pt: string, en: string, es: string } } = {
	no_snapshot = {
		pt = "Aguarde o perfil carregar",
		en = "Waiting for profile",
		es = "Esperando el perfil",
	},
	no_trap = {
		pt = "Escolha uma armadilha",
		en = "Select a trap",
		es = "Elige una trampa",
	},
	bad_cell = {
		pt = "Celula invalida",
		en = "Invalid cell",
		es = "Celda invalida",
	},
	cell_occupied = {
		pt = "Celula ocupada",
		en = "Cell occupied",
		es = "Celda ocupada",
	},
	empty_cell = {
		pt = "Celula vazia",
		en = "Empty cell",
		es = "Celda vacia",
	},
	bad_mode = {
		pt = "Modo invalido",
		en = "Invalid mode",
		es = "Modo invalido",
	},
	gold_cap = {
		pt = "Ouro no teto",
		en = "Gold at cap",
		es = "Oro al maximo",
	},
	trap_limit = {
		pt = "Limite de armadilhas atingido",
		en = "Trap limit reached",
		es = "Limite de trampas alcanzado",
	},
	too_close = {
		pt = "Muito perto de outra armadilha",
		en = "Too close to another trap",
		es = "Muy cerca de otra trampa",
	},
	invalid_position = {
		pt = "Posicao fora da arena",
		en = "Position outside arena",
		es = "Posicion fuera de la arena",
	},
	invalid_slot = {
		pt = "Slot invalido",
		en = "Invalid slot",
		es = "Ranura invalida",
	},
	max_wall_level = {
		pt = "Muralha no nivel maximo",
		en = "Wall at max level",
		es = "Muralla al nivel maximo",
	},
	wall_locked = {
		pt = "Muralha bloqueada por liga",
		en = "Wall locked by league",
		es = "Muralla bloqueada por liga",
	},
	unknown_trap = {
		pt = "Armadilha desconhecida",
		en = "Unknown trap",
		es = "Trampa desconocida",
	},
	content_version = {
		pt = "Conteudo desatualizado",
		en = "Outdated content",
		es = "Contenido desactualizado",
	},
	content_future = {
		pt = "Conteudo futuro",
		en = "Future content",
		es = "Contenido futuro",
	},
	loading_profile = {
		pt = "carregando perfil...",
		en = "loading profile...",
		es = "cargando perfil...",
	},
	waiting_profile = {
		pt = "Aguardando perfil...",
		en = "Waiting for profile...",
		es = "Esperando perfil...",
	},
	profile_timeout = {
		pt = "Perfil nao carregou em 30s",
		en = "Profile failed to load in 30s",
		es = "El perfil no cargo en 30s",
	},
	wall_loaded = {
		pt = "Muralha carregada",
		en = "Bastion loaded",
		es = "Muralla cargada",
	},
	server_unavailable = {
		pt = "Servidor indisponivel",
		en = "Server unavailable",
		es = "Servidor no disponible",
	},
	refused = {
		pt = "Recusado: ",
		en = "Refused: ",
		es = "Rechazado: ",
	},
	cam_diagonal = {
		pt = "Camera: Diagonal (1/3)",
		en = "Camera: Diagonal (1/3)",
		es = "Camara: Diagonal (1/3)",
	},
	cam_corridor = {
		pt = "Camera: Corredor (2/3)",
		en = "Camera: Corridor (2/3)",
		es = "Camara: Corredor (2/3)",
	},
	cam_wall = {
		pt = "Camera: Muralha (3/3)",
		en = "Camera: Wall Top (3/3)",
		es = "Camara: Muralla (3/3)",
	},
}

local function msgFor(key: string): string
	local entry = STATUS_I18N[key]
	if entry == nil then
		return key
	end
	local loc = UiKit.getLocale()
	if loc == "en" then
		return entry.en
	elseif loc == "es" then
		return entry.es
	end
	return entry.pt
end

local function nextWallSpec(snapshot: any): any
	if type(snapshot) ~= "table" or type(snapshot.wallLevels) ~= "table" then
		return nil
	end
	local wallLevel = snapshot.wallLevel or 1
	return snapshot.wallLevels[wallLevel + 1]
end

local function statusFor(err: string?, cell: string?, action: string?): string
	local loc = UiKit.getLocale()
	if err == "max_level" or err == "max_wall_level" then
		return I18n.t(loc, "toast_max_level")
	elseif err == "trap_limit" and state.snapshot ~= nil then
		local limit = (state.snapshot :: any).activeTrapLimit or 5
		if loc == "en" then
			return string.format("Limit of %d traps", limit)
		elseif loc == "es" then
			return string.format("Limite de %d trampas", limit)
		end
		return string.format("Limite de %d armadilhas", limit)
	elseif err == "insufficient_gold" then
		local cost = 0
		if action == "upgrade_wall" and state.snapshot ~= nil then
			local nxt = nextWallSpec(state.snapshot)
			if type(nxt) == "table" and type(nxt.cost) == "number" then
				cost = nxt.cost
			end
		elseif state.mode == "place" and state.selectedTrap ~= nil then
			local entry = BuildClientState.catalogEntry(state, state.selectedTrap)
			if entry ~= nil then
				cost = entry.cost
			end
		elseif state.mode == "upgrade" and cell ~= nil then
			cost = BuildClientState.upgradeCost(state, cell) or 0
		end
		return I18n.t(loc, "toast_no_gold", cost)
	elseif err == "wall_locked" and state.snapshot ~= nil then
		local nxt = nextWallSpec(state.snapshot)
		local unlockLeague = if type(nxt) == "table" and type(nxt.unlockLeague) == "number"
			then nxt.unlockLeague
			else 2
		return I18n.t(loc, "toast_locked_league", unlockLeague)
	elseif err == "trap_locked" then
		local unlockLeague = 2
		if state.selectedTrap ~= nil then
			local entry = BuildClientState.catalogEntry(state, state.selectedTrap)
			if entry ~= nil then
				unlockLeague = entry.unlockLeague
			end
		end
		return I18n.t(loc, "toast_locked_league", unlockLeague)
	end
	if err ~= nil and STATUS_I18N[err] ~= nil then
		return msgFor(err)
	end
	return msgFor("refused") .. tostring(err)
end

-- ---------------------------------------------------------------- UI
local gui = Instance.new("ScreenGui")
gui.Name = "BuildGui"
gui.ResetOnSpawn = false
gui.DisplayOrder = 10
UiKit.applySafeScreenGui(gui)
gui.Parent = playerGui

local root = Instance.new("Frame")
root.Name = "Root"
root.Size = UDim2.fromScale(1, 1)
root.BackgroundTransparency = 1
root.Parent = gui

local goldPill = UiKit.panel(root, "GoldPill")
goldPill.Active = true
UiKit.corner(goldPill, 12)
local coin = UiKit.iconCoin(goldPill, 20)
coin.AnchorPoint = Vector2.new(0, 0.5)
coin.Position = UDim2.new(0, 8, 0.5, 0)

local goldLabel = UiKit.label(
	goldPill,
	"Gold",
	"0",
	UiKit.color(VisualTheme.PALETTE.amberBright),
	Enum.Font.GothamBlack
)
goldLabel.Position = UDim2.new(0, 32, 0, 0)
goldLabel.Size = UDim2.new(1, -38, 1, 0)
goldLabel.TextXAlignment = Enum.TextXAlignment.Left
goldLabel.TextScaled = true
goldLabel.TextWrapped = false
local goldCap = Instance.new("UITextSizeConstraint")
goldCap.MinTextSize = 11
goldCap.MaxTextSize = 18
goldCap.Parent = goldLabel

local wallUpgradeBtn = UiKit.button(root, "WallUpgrade", "L1 · Nv1 (500) · 0/5")
wallUpgradeBtn.Font = Enum.Font.GothamBold
wallUpgradeBtn.TextScaled = true
wallUpgradeBtn.TextWrapped = false
wallUpgradeBtn.TextTruncate = Enum.TextTruncate.AtEnd
UiKit.corner(wallUpgradeBtn, 12)
local wallUpgradeCap = Instance.new("UITextSizeConstraint")
wallUpgradeCap.MinTextSize = 10
wallUpgradeCap.MaxTextSize = 14
wallUpgradeCap.Parent = wallUpgradeBtn

local camBtn = UiKit.button(root, "CamBtn", "CAM 1")
camBtn.Font = Enum.Font.GothamBold
camBtn.TextScaled = true
camBtn.TextWrapped = false
UiKit.corner(camBtn, 12)
local camBtnCap = Instance.new("UITextSizeConstraint")
camBtnCap.MinTextSize = 10
camBtnCap.MaxTextSize = 13
camBtnCap.Parent = camBtn

local muteBtn = UiKit.button(root, "MuteBtn", "SFX")
muteBtn.Font = Enum.Font.GothamBold
muteBtn.TextScaled = true
muteBtn.TextWrapped = false
UiKit.corner(muteBtn, 12)
local muteBtnCap = Instance.new("UITextSizeConstraint")
muteBtnCap.MinTextSize = 10
muteBtnCap.MaxTextSize = 13
muteBtnCap.Parent = muteBtn

local comboBtn = UiKit.button(root, "ComboGuideBtn", "?")
comboBtn.Font = Enum.Font.GothamBold
comboBtn.TextScaled = true
comboBtn.TextWrapped = false
UiKit.corner(comboBtn, 12)
local comboBtnCap = Instance.new("UITextSizeConstraint")
comboBtnCap.MinTextSize = 10
comboBtnCap.MaxTextSize = 14
comboBtnCap.Parent = comboBtn

local localePill = UiKit.createLocalePill(root)
local compactLocalePill = UiKit.createCompactLocalePill(root)

local comboModal = UiKit.panel(root, "ComboModal")
comboModal.Visible = false
comboModal.ZIndex = 20
comboModal.AnchorPoint = Vector2.new(0.5, 0.5)
comboModal.Position = UDim2.fromScale(0.5, 0.48)
comboModal.Size = UDim2.fromOffset(336, 232)
UiKit.corner(comboModal, 12)
UiKit.stroke(comboModal, UiKit.color(VisualTheme.PALETTE.amber), 2, 0.15)

local comboTitleLabel = UiKit.label(
	comboModal,
	"ComboTitle",
	I18n.t(UiKit.getLocale(), "combo_title"),
	UiKit.color(VisualTheme.PALETTE.amberBright),
	Enum.Font.GothamBlack
)
comboTitleLabel.Position = UDim2.fromOffset(14, 8)
comboTitleLabel.Size = UDim2.new(1, -64, 0, 32)
comboTitleLabel.TextScaled = true
comboTitleLabel.ZIndex = 21
local comboTitleCap = Instance.new("UITextSizeConstraint")
comboTitleCap.MinTextSize = 12
comboTitleCap.MaxTextSize = 16
comboTitleCap.Parent = comboTitleLabel

local comboCloseBtn = UiKit.button(comboModal, "CloseCombos", "X")
comboCloseBtn.AnchorPoint = Vector2.new(1, 0)
comboCloseBtn.Position = UDim2.new(1, -6, 0, 4)
comboCloseBtn.Size = UDim2.fromOffset(44, 44)
comboCloseBtn.ZIndex = 22

type ComboRowUi = {
	nameKey: string,
	descKey: string,
	nameLabel: TextLabel,
	descLabel: TextLabel,
}
local comboRows: { ComboRowUi } = {}
local COMBO_SPECS = {
	{ nameKey = "combo_tar_name", descKey = "combo_tar_desc", color = VisualTheme.PALETTE.amber },
	{
		nameKey = "combo_frost_name",
		descKey = "combo_frost_desc",
		color = VisualTheme.PALETTE.teal,
	},
	{
		nameKey = "combo_battery_name",
		descKey = "combo_battery_desc",
		color = VisualTheme.PALETTE.amberBright,
	},
}
for index, spec in ipairs(COMBO_SPECS) do
	local rowFrame = Instance.new("Frame")
	rowFrame.Name = "ComboRow" .. tostring(index)
	rowFrame.Position = UDim2.fromOffset(12, 48 + (index - 1) * 58)
	rowFrame.Size = UDim2.new(1, -24, 0, 52)
	rowFrame.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.stoneDark)
	rowFrame.BackgroundTransparency = 0.25
	rowFrame.BorderSizePixel = 0
	rowFrame.ZIndex = 21
	rowFrame.Parent = comboModal
	UiKit.corner(rowFrame, 8)

	local stripe = Instance.new("Frame")
	stripe.Name = "Stripe"
	stripe.Size = UDim2.new(0, 4, 1, -8)
	stripe.Position = UDim2.fromOffset(4, 4)
	stripe.BackgroundColor3 = UiKit.color(spec.color)
	stripe.BorderSizePixel = 0
	stripe.ZIndex = 22
	stripe.Parent = rowFrame
	UiKit.corner(stripe, 2)

	local nameLbl = UiKit.label(
		rowFrame,
		"Name",
		I18n.t(UiKit.getLocale(), spec.nameKey),
		UiKit.color(spec.color),
		Enum.Font.GothamBlack
	)
	nameLbl.Position = UDim2.fromOffset(14, 4)
	nameLbl.Size = UDim2.new(1, -20, 0, 20)
	nameLbl.TextScaled = true
	nameLbl.ZIndex = 22
	local nameCap = Instance.new("UITextSizeConstraint")
	nameCap.MinTextSize = 10
	nameCap.MaxTextSize = 14
	nameCap.Parent = nameLbl

	local descLbl = UiKit.label(
		rowFrame,
		"Desc",
		I18n.t(UiKit.getLocale(), spec.descKey),
		UiKit.color(VisualTheme.PALETTE.parchment),
		Enum.Font.Gotham
	)
	descLbl.Position = UDim2.fromOffset(14, 24)
	descLbl.Size = UDim2.new(1, -20, 0, 24)
	descLbl.TextScaled = true
	descLbl.ZIndex = 22
	local descCap = Instance.new("UITextSizeConstraint")
	descCap.MinTextSize = 9
	descCap.MaxTextSize = 12
	descCap.Parent = descLbl

	comboRows[#comboRows + 1] = {
		nameKey = spec.nameKey,
		descKey = spec.descKey,
		nameLabel = nameLbl,
		descLabel = descLbl,
	}
end

local gridFrame = Instance.new("Frame")
gridFrame.Name = "Grid"
gridFrame.BackgroundTransparency = 1
gridFrame.Visible = false
gridFrame.Parent = root

local gridLayout = Instance.new("UIGridLayout")
gridLayout.FillDirection = Enum.FillDirection.Horizontal
gridLayout.FillDirectionMaxCells = GridLayout.WIDTH
gridLayout.CellSize = UDim2.fromOffset(48, 48)
gridLayout.CellPadding = UDim2.fromOffset(5, 5)
gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
gridLayout.Parent = gridFrame

local cellButtons: { [string]: TextButton } = {}

local send: (action: string, trapId: string, slot: string, x: number?, y: number?) -> ()
local setStatus: (text: string) -> ()
local movingSlot: string? = nil

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
			AudioKit.play(if err == "trap_locked" then "build_locked" else "build_invalid")
			setStatus(statusFor(err, cell))
			return
		end
		if intent.action == "upgrade" then
			local cost = BuildClientState.upgradeCost(state, cell)
			local data = state.snapshot and state.snapshot.cells[cell]
			if cost ~= nil and data ~= nil then
				local loc = UiKit.getLocale()
				local label = I18n.trapName(loc, data.trap)
				setStatus(
					string.format(
						"%s %s L%d→L%d · %s",
						I18n.t(loc, "mode_upgrade"),
						label,
						data.level,
						data.level + 1,
						I18n.t(loc, "hud_gold", cost)
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

local toolsDock = UiKit.panel(root, "ToolsDock")
UiKit.corner(toolsDock, 12)

local modeLayout = Instance.new("UIListLayout")
modeLayout.FillDirection = Enum.FillDirection.Horizontal
modeLayout.Padding = UDim.new(0, 4)
modeLayout.SortOrder = Enum.SortOrder.LayoutOrder
modeLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
modeLayout.VerticalAlignment = Enum.VerticalAlignment.Center
modeLayout.Parent = toolsDock

local modeButtons: { [string]: TextButton } = {}
local function makeMode(order: number, id: string, text: string): TextButton
	local button = UiKit.button(toolsDock, id, text)
	button.LayoutOrder = order
	button.Size = UDim2.fromOffset(44, 44)
	UiKit.corner(button, 10)
	local textCap = Instance.new("UITextSizeConstraint")
	textCap.MaxTextSize = 16
	textCap.MinTextSize = 10
	textCap.Parent = button
	modeButtons[id] = button
	return button
end

makeMode(1, "upgrade", "▲")
makeMode(2, "move", "MV")
makeMode(3, "remove", "✕")

local trapDock = UiKit.panel(root, "TrapDock")
UiKit.corner(trapDock, 12)

local trapRow = Instance.new("Frame")
trapRow.Name = "Traps"
trapRow.Position = UDim2.fromOffset(4, 0)
trapRow.Size = UDim2.new(1, -8, 1, 0)
trapRow.BackgroundTransparency = 1
trapRow.Parent = trapDock

local trapLayout = Instance.new("UIListLayout")
trapLayout.FillDirection = Enum.FillDirection.Horizontal
trapLayout.Padding = UDim.new(0, 4)
trapLayout.SortOrder = Enum.SortOrder.LayoutOrder
trapLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
trapLayout.VerticalAlignment = Enum.VerticalAlignment.Center
trapLayout.Parent = trapRow

local contextTrapBar = UiKit.panel(root, "ContextTrapBar")
contextTrapBar.Visible = false
contextTrapBar.Size = UDim2.fromOffset(148, 48)
contextTrapBar.ZIndex = 12
UiKit.corner(contextTrapBar, 12)
UiKit.stroke(contextTrapBar, UiKit.color(VisualTheme.PALETTE.amber), 1.5, 0.15)
local ctxLayout = Instance.new("UIListLayout")
ctxLayout.FillDirection = Enum.FillDirection.Horizontal
ctxLayout.Padding = UDim.new(0, 4)
ctxLayout.SortOrder = Enum.SortOrder.LayoutOrder
ctxLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
ctxLayout.VerticalAlignment = Enum.VerticalAlignment.Center
ctxLayout.Parent = contextTrapBar

local function makeContextBtn(
	order: number,
	name: string,
	label: string,
	paletteColor: { number }?
): TextButton
	local b = UiKit.button(contextTrapBar, name, label)
	b.LayoutOrder = order
	b.Size = UDim2.fromOffset(44, 42)
	b.ZIndex = 13
	UiKit.corner(b, 10)
	if paletteColor ~= nil then
		UiKit.stroke(b, UiKit.color(paletteColor), 1.5, 0.15)
	end
	local cap = Instance.new("UITextSizeConstraint")
	cap.MinTextSize = 11
	cap.MaxTextSize = 16
	cap.Parent = b
	return b
end

local ctxUpgradeBtn = makeContextBtn(1, "CtxUpgrade", "▲", VisualTheme.PALETTE.amber)
local ctxMoveBtn = makeContextBtn(2, "CtxMove", "MV", VisualTheme.PALETTE.teal)
local ctxRemoveBtn = makeContextBtn(3, "CtxRemove", "✕", VisualTheme.PALETTE.danger)

local toastBanner = UiKit.panel(root, "ToastBanner")
toastBanner.Visible = false
toastBanner.ZIndex = 6
UiKit.corner(toastBanner, 10)
UiKit.stroke(toastBanner, UiKit.color(VisualTheme.PALETTE.amber), 1, 0.25)
local toastPad = toastBanner:FindFirstChildOfClass("UIPadding")
if toastPad ~= nil then
	toastPad.PaddingLeft = UDim.new(0, 12)
	toastPad.PaddingRight = UDim.new(0, 12)
	toastPad.PaddingTop = UDim.new(0, 4)
	toastPad.PaddingBottom = UDim.new(0, 4)
end
local toastLabel = UiKit.label(
	toastBanner,
	"ToastText",
	"",
	UiKit.color(VisualTheme.PALETTE.parchment),
	Enum.Font.GothamBold
)
toastLabel.Size = UDim2.fromScale(1, 1)
toastLabel.TextXAlignment = Enum.TextXAlignment.Center
toastLabel.TextScaled = true
toastLabel.ZIndex = 7
local toastTextCap = Instance.new("UITextSizeConstraint")
toastTextCap.MaxTextSize = 14
toastTextCap.Parent = toastLabel

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
local toastToken = 0
setStatus = function(text: string): ()
	if text == "" then
		toastBanner.Visible = false
		return
	end

	toastToken += 1
	local myToken = toastToken
	toastLabel.Text = text
	toastLabel.TextTransparency = 0
	toastBanner.BackgroundTransparency = 0.08
	toastBanner.Visible = true
	UiKit.stroke(toastBanner, UiKit.color(VisualTheme.PALETTE.amber), 1, 0.2)

	task.delay(2.6, function()
		if toastToken ~= myToken then
			return
		end
		local fadeInfo = TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(toastBanner, fadeInfo, { BackgroundTransparency = 1 }):Play()
		local textTween = TweenService:Create(toastLabel, fadeInfo, { TextTransparency = 1 })
		textTween.Completed:Connect(function()
			if toastToken == myToken then
				toastBanner.Visible = false
			end
		end)
		textTween:Play()
	end)
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

local function refreshCamButton(): ()
	local compact = currentHudLayout == nil or not currentHudLayout.isDesktop
	camBtn.Text = UiKit.cameraButtonLabel(UiKit.getCameraAngle(), compact)
	UiKit.stroke(camBtn, UiKit.color(VisualTheme.PALETTE.amber), 1.5, 0.25)
end

local function refreshMuteButton(): ()
	local muted = AudioKit.isMuted()
	muteBtn.Text = if muted then "MUTE" else "SFX"
	UiKit.setSelected(muteBtn, not muted)
	if muted then
		muteBtn.TextColor3 = UiKit.color(VisualTheme.PALETTE.danger)
		UiKit.stroke(muteBtn, UiKit.color(VisualTheme.PALETTE.danger), 1.5, 0.2)
	else
		UiKit.stroke(muteBtn, UiKit.color(VisualTheme.PALETTE.teal), 1.5, 0.2)
	end
end

local function updateModeButtons(): ()
	for id, button in pairs(modeButtons) do
		UiKit.setSelected(button, id == state.mode)
	end
end

local function refreshSelection(): ()
	-- Selection feedback uses active trap card border, tool toggle highlight, and transient toast.
end

local function refreshComboModal(): ()
	local loc = UiKit.getLocale()
	comboBtn.Text = if currentHudLayout == nil or not currentHudLayout.isDesktop
		then "?"
		else I18n.t(loc, "combo_btn")
	comboTitleLabel.Text = I18n.t(loc, "combo_title")
	for _, item in ipairs(comboRows) do
		item.nameLabel.Text = I18n.t(loc, item.nameKey)
		item.descLabel.Text = I18n.t(loc, item.descKey)
	end
end

local function refreshWallButton(snapshot: any): ()
	local loc = UiKit.getLocale()
	if snapshot == nil then
		wallUpgradeBtn.Text = "L1 · Nv1 (500) · 0/5"
		UiKit.stroke(wallUpgradeBtn, UiKit.color(VisualTheme.PALETTE.iron), 1, 0.25)
		return
	end
	local used = 0
	if type(snapshot.cells) == "table" then
		for _ in pairs(snapshot.cells) do
			used += 1
		end
	end
	local league = snapshot.league or 1
	local wallLevel = snapshot.wallLevel or 1
	local wallHp = snapshot.wallHp or 500
	local limit = snapshot.activeTrapLimit or 5
	local compact = currentHudLayout == nil or not currentHudLayout.isDesktop
	local baseText = if compact
		then string.format("L%d · Nv%d (%d) · %d/%d", league, wallLevel, wallHp, used, limit)
		else string.format(
			"L%d · %s",
			league,
			I18n.t(loc, "wall_hud", wallLevel, wallHp, used, limit)
		)
	local nxt = nextWallSpec(snapshot)
	if type(nxt) == "table" then
		local gold = snapshot.gold or 0
		if league < nxt.unlockLeague then
			wallUpgradeBtn.Text = string.format("%s · L%d", baseText, nxt.unlockLeague)
			wallUpgradeBtn.TextColor3 = UiKit.color(VisualTheme.PALETTE.stone)
			UiKit.stroke(wallUpgradeBtn, UiKit.color(VisualTheme.PALETTE.iron), 1, 0.35)
		elseif gold >= nxt.cost then
			wallUpgradeBtn.Text = string.format("%s · ▲%dg", baseText, nxt.cost)
			wallUpgradeBtn.TextColor3 = UiKit.color(VisualTheme.PALETTE.amberBright)
			UiKit.stroke(wallUpgradeBtn, UiKit.color(VisualTheme.PALETTE.amber), 2, 0.1)
		else
			wallUpgradeBtn.Text = string.format("%s · ▲%dg", baseText, nxt.cost)
			wallUpgradeBtn.TextColor3 = UiKit.color(VisualTheme.PALETTE.parchment)
			UiKit.stroke(wallUpgradeBtn, UiKit.color(VisualTheme.PALETTE.iron), 1, 0.2)
		end
	else
		wallUpgradeBtn.Text = string.format("%s · %s", baseText, I18n.t(loc, "wall_max"))
		wallUpgradeBtn.TextColor3 = UiKit.color(VisualTheme.PALETTE.teal)
		UiKit.stroke(wallUpgradeBtn, UiKit.color(VisualTheme.PALETTE.teal), 1.5, 0.2)
	end
end

local trapCards: { [string]: UiKit.TrapCard } = {}
local updateCardAffordability: () -> ()

local function clearCardHighlight(): ()
	for _, card in pairs(trapCards) do
		UiKit.setSelected(card.frame, false)
	end
end

local function closeContextBar(): ()
	selectedWorldSlot = nil
	contextTrapBar.Visible = false
end

local function selectTrap(trapId: string): ()
	if not BuildClientState.selectTrap(state, trapId) then
		return
	end
	movingSlot = nil
	closeContextBar()
	ArenaVisual.setPlacementDisc(Workspace, nil, false)
	AudioKit.play("ui_click")
	updateModeButtons()
	clearCardHighlight()
	local card = trapCards[trapId]
	if card ~= nil then
		UiKit.setSelected(card.frame, true)
	end
	refreshSelection()
	updateCardAffordability()
	local loc = UiKit.getLocale()
	local verb = I18n.trapVerb(loc, trapId)
	local name = I18n.trapName(loc, trapId)
	setStatus(if verb ~= "" then (name .. " · " .. verb) else name)
end

local function ensureTrapCards(catalog: { BuildClientState.CatalogEntry }): ()
	for index, entry in ipairs(catalog) do
		local id = entry.id
		if trapCards[id] == nil then
			local card = UiKit.card(trapRow, id)
			card.frame.LayoutOrder = index
			if currentHudLayout ~= nil then
				card.frame.Size =
					UDim2.fromOffset(currentHudLayout.trapCardW, currentHudLayout.trapCardH)
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
	local loc = UiKit.getLocale()
	for id, card in pairs(trapCards) do
		local entry = BuildClientState.catalogEntry(state, id)
		local spec = ((VisualTheme.TRAPS :: any)[id]) :: UiKit.TrapSpec?
		if entry ~= nil and spec ~= nil then
			local locked = entry.unlockLeague > snapshot.league
			local selected = state.mode == "place" and state.selectedTrap == id
			local affordable = if locked
				then false
				elseif state.mode == "place" then snapshot.gold >= entry.cost
				else true
			UiKit.setCard(card, spec, selected, id, locked, affordable)
			if locked then
				card.cost.Text = "L" .. tostring(entry.unlockLeague)
			elseif state.mode == "upgrade" then
				local low, high = BuildClientState.upgradeRange(entry)
				card.cost.Text = string.format("%s/%s", tostring(low or 0), tostring(high or 0))
			elseif state.mode == "remove" then
				card.cost.Text = I18n.t(loc, "mode_remove")
			elseif state.mode == "move" then
				card.cost.Text = "0g"
			else
				card.cost.Text = string.format("%dg", entry.cost)
			end
			card.name.Text = I18n.trapName(loc, id)
		end
	end
end

local function refreshHeaderLabels(snapshot: any): ()
	if snapshot == nil then
		goldLabel.Text = "0"
		refreshWallButton(nil)
		return
	end
	goldLabel.Text = tostring(snapshot.gold or 0)
	refreshWallButton(snapshot)
	local wallTier = snapshot.wallLevel or 1
	if Players.LocalPlayer:GetAttribute("MuralhaWallTier") ~= wallTier then
		Players.LocalPlayer:SetAttribute("MuralhaWallTier", wallTier)
		ArenaVisual.setWallTier(Workspace, wallTier)
	end
end

local lastGold: number? = nil

-- SFX de economia: delta de ouro entre snapshots (gasto ao colocar/upgrade, ganho no reembolso).
local function playGoldDelta(snapshot: any): ()
	local gold = if type(snapshot) == "table" then snapshot.gold else nil
	if type(gold) ~= "number" then
		return
	end
	if lastGold ~= nil then
		AudioKit.coin(gold - (lastGold :: number))
	end
end

local function refresh(snapshot: any): ()
	BuildClientState.setSnapshot(state, snapshot)
	if
		movingSlot ~= nil and (type(snapshot.cells) ~= "table" or snapshot.cells[movingSlot] == nil)
	then
		movingSlot = nil
	end
	if type(snapshot.gold) == "number" then
		lastGold = snapshot.gold
	end
	refreshHeaderLabels(snapshot)
	currentVersionText =
		string.format("v%d · c%d", snapshot.schemaVersion or 2, snapshot.contentVersion or 2)
	if
		selectedWorldSlot ~= nil
		and (type(snapshot.cells) ~= "table" or snapshot.cells[selectedWorldSlot] == nil)
	then
		closeContextBar()
	end
	ensureTrapCards(snapshot.catalog)
	updateModeButtons()
	refreshSelection()
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
	TrapKit.sync(Workspace, snapshot.cells, Vector3.new(0, 0, 0), { floorTopY = 0.33 })

	local wasReady = hud.uiSeconds ~= nil
	local uiSeconds = BuildHud.markReady(hud)
	if not wasReady then
		print(string.format("[build] cliente pronto em %.1fs", uiSeconds))
	end
end

local function positionOfPlacement(slot: string, x: number?, y: number?): Vector3?
	if type(x) == "number" and type(y) == "number" then
		local wx, _, wz = GridLayout.arenaPosToWorld(x, y)
		return Vector3.new(wx, 0.6, wz)
	end
	local wx, _, wz = GridLayout.cellToWorld(slot)
	if wx == nil or wz == nil then
		return nil
	end
	return Vector3.new(wx, 0.6, wz)
end

send = function(action: string, trapId: string, slot: string, x: number?, y: number?): ()
	local ok, result = pcall(function()
		if x ~= nil and y ~= nil then
			return buildAction:InvokeServer(action, trapId, slot, x, y)
		end
		return buildAction:InvokeServer(action, trapId, slot)
	end)
	if not ok or type(result) ~= "table" then
		AudioKit.play("build_invalid")
		setStatus(msgFor("server_unavailable"))
		return
	end
	if result.ok then
		if action == "place" then
			AudioKit.play("build_place")
			local position = positionOfPlacement(slot, x, y)
			if position ~= nil then
				Vfx.dust(Workspace, position, 5)
			end
		elseif action == "move" then
			AudioKit.play("build_move")
			local position = positionOfPlacement(slot, x, y)
			if position ~= nil then
				Vfx.dust(Workspace, position, 4)
			end
		elseif action == "remove" then
			AudioKit.play("build_remove")
		elseif action == "upgrade_wall" then
			local newLvl = if type(result.snapshot) == "table"
				then result.snapshot.wallLevel
				else nil
			AudioKit.upgrade(if type(newLvl) == "number" then newLvl else nil)
			Vfx.dust(Workspace, Vector3.new(GridLayout.WALL_X, 1, 0), 6)
		else
			local cells = result.snapshot and result.snapshot.cells
			local data = if type(cells) == "table" then cells[slot] else nil
			AudioKit.upgrade(if type(data) == "table" then data.level else nil)
		end
		if result.snapshot ~= nil then
			playGoldDelta(result.snapshot)
			refresh(result.snapshot)
		end
		local charged = result.result and result.result.cost
		if (action == "upgrade" or action == "upgrade_wall") and type(charged) == "number" then
			local loc = UiKit.getLocale()
			setStatus(
				string.format(
					"%s · -%s",
					I18n.t(loc, "mode_upgrade"),
					I18n.t(loc, "hud_gold", charged)
				)
			)
		else
			setStatus("OK")
		end
	else
		AudioKit.play(
			if result.err == "trap_locked" or result.err == "wall_locked"
				then "build_locked"
				else "build_invalid"
		)
		setStatus(statusFor(tostring(result.err), slot, action))
	end
end

-- ---------------------------------------------------------------- layout
local function positionContextBar(): ()
	if selectedWorldSlot == nil or not contextTrapBar.Visible then
		return
	end
	local worldPos = positionOfPlacement(selectedWorldSlot)
	if worldPos == nil then
		closeContextBar()
		return
	end
	local vpPt, onScreen = camera:WorldToViewportPoint(worldPos + Vector3.new(0, 3.8, 0))
	if not onScreen then
		closeContextBar()
		return
	end
	local size = root.AbsoluteSize
	local pos = root.AbsolutePosition
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local localX = vpPt.X - pos.X
	local localY = vpPt.Y - pos.Y
	local bw = contextTrapBar.Size.X.Offset
	local bh = contextTrapBar.Size.Y.Offset
	local x = math.clamp(math.floor(localX - bw * 0.5), 6, math.max(6, size.X - bw - 6))
	local y = math.clamp(math.floor(localY - bh - 6), 56, math.max(56, size.Y - bh - 6))
	contextTrapBar.Position = UDim2.fromOffset(x, y)
end

local function applyRect(obj: GuiObject, r: BuildLayout.Rect): ()
	obj.Position = UDim2.fromOffset(r.x, r.y)
	obj.Size = UDim2.fromOffset(r.w, r.h)
end

local function applyLayout(): ()
	local size = root.AbsoluteSize
	if size.X <= 0 or size.Y <= 0 then
		return
	end
	local hudRects = BuildLayout.computeHud(size.X, size.Y, UiKit.safeTopbarInsets(root))
	currentHudLayout = hudRects

	applyRect(goldPill, hudRects.goldPill)
	applyRect(wallUpgradeBtn, hudRects.wallPill)
	applyRect(camBtn, hudRects.camBtn)
	applyRect(muteBtn, hudRects.muteBtn)
	applyRect(comboBtn, hudRects.comboBtn)

	localePill.Visible = hudRects.isDesktop
	compactLocalePill.Visible = not hudRects.isDesktop
	applyRect(localePill, hudRects.localeBtn)
	applyRect(compactLocalePill, hudRects.localeBtn)

	refreshComboModal()
	refreshWallButton(state.snapshot)
	refreshCamButton()
	refreshMuteButton()
	comboModal.Size = UDim2.fromOffset(math.min(344, size.X - 24), math.min(232, size.Y - 40))

	debugHud.Position =
		UDim2.fromOffset(hudRects.goldPill.x, hudRects.goldPill.y + hudRects.goldPill.h + 4)
	debugHud.Size = UDim2.fromOffset(math.min(240, size.X - 16), 20)

	applyRect(toolsDock, hudRects.toolsDock)
	applyRect(trapDock, hudRects.trapDock)
	applyRect(toastBanner, hudRects.toastBanner)

	trapLayout.Padding = UDim.new(0, hudRects.trapCardGap)
	for _, card in pairs(trapCards) do
		card.frame.Size = UDim2.fromOffset(hudRects.trapCardW, hudRects.trapCardH)
	end

	positionContextBar()
end

root:GetPropertyChangedSignal("AbsoluteSize"):Connect(applyLayout)
root:GetPropertyChangedSignal("AbsolutePosition"):Connect(applyLayout)
GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(applyLayout)
task.defer(applyLayout)

-- ---------------------------------------------------------------- ligacoes
for id, button in pairs(modeButtons) do
	button.MouseButton1Click:Connect(function()
		local targetMode = if state.mode == id then "place" else id
		if BuildClientState.setMode(state, targetMode) then
			movingSlot = nil
			closeContextBar()
			ArenaVisual.setPlacementDisc(Workspace, nil, false)
			AudioKit.play("ui_toggle")
			updateModeButtons()
			clearCardHighlight()
			refreshSelection()
			updateCardAffordability()
			if targetMode ~= "place" then
				setStatus(I18n.t(UiKit.getLocale(), "mode_" .. targetMode))
			end
		end
	end)
end

camBtn.MouseButton1Click:Connect(function()
	local nextAngle = UiKit.cycleCameraAngle()
	AudioKit.play("ui_toggle")
	refreshCamButton()
	refreshBuildCamera()
	positionContextBar()
	setStatus(msgFor("cam_" .. nextAngle))
end)

muteBtn.MouseButton1Click:Connect(function()
	AudioKit.setMuted(not AudioKit.isMuted())
	refreshMuteButton()
	AudioKit.play("ui_toggle")
end)

ctxUpgradeBtn.MouseButton1Click:Connect(function()
	if selectedWorldSlot == nil then
		closeContextBar()
		return
	end
	send("upgrade", "", selectedWorldSlot)
end)

ctxMoveBtn.MouseButton1Click:Connect(function()
	local targetSlot = selectedWorldSlot
	if
		targetSlot == nil
		or state.snapshot == nil
		or type(state.snapshot.cells) ~= "table"
		or state.snapshot.cells[targetSlot] == nil
	then
		closeContextBar()
		return
	end
	closeContextBar()
	if BuildClientState.setMode(state, "move") then
		movingSlot = targetSlot
		ArenaVisual.setPlacementDisc(Workspace, nil, false)
		AudioKit.play("ui_toggle")
		updateModeButtons()
		clearCardHighlight()
		updateCardAffordability()
		setStatus(I18n.t(UiKit.getLocale(), "mode_move"))
	end
end)

ctxRemoveBtn.MouseButton1Click:Connect(function()
	local targetSlot = selectedWorldSlot
	closeContextBar()
	if targetSlot ~= nil then
		send("remove", "", targetSlot)
	end
end)

wallUpgradeBtn.MouseButton1Click:Connect(function()
	closeContextBar()
	if state.snapshot == nil then
		AudioKit.play("build_invalid")
		setStatus(msgFor("no_snapshot"))
		return
	end
	send("upgrade_wall", "", "")
end)

comboBtn.MouseButton1Click:Connect(function()
	closeContextBar()
	comboModal.Visible = not comboModal.Visible
	AudioKit.play("ui_toggle")
end)

comboCloseBtn.MouseButton1Click:Connect(function()
	comboModal.Visible = false
	AudioKit.play("ui_click")
end)

local function toggleDebug(): ()
	debugHud.Visible = not debugHud.Visible
end

local longPressToken = 0
goldPill.InputBegan:Connect(function(input: InputObject)
	if
		input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseButton1
	then
		longPressToken += 1
		local myToken = longPressToken
		task.delay(1.5, function()
			if longPressToken == myToken then
				toggleDebug()
			end
		end)
	end
end)
goldPill.InputEnded:Connect(function(input: InputObject)
	if
		input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseButton1
	then
		longPressToken += 1
	end
end)

-- ---------------------------------------------------------------- 3D tap-to-build
local TOUCH_SLOP_PX = 12
local touchOrigin: Vector2? = nil
local floorRayParams = RaycastParams.new()
floorRayParams.FilterType = Enum.RaycastFilterType.Include
local trapRayParams = RaycastParams.new()
trapRayParams.FilterType = Enum.RaycastFilterType.Include

local function updateRayTargets(): ()
	local floorTargets: { Instance } = {}
	local arena = Workspace:FindFirstChild("MuralhaArena")
	if arena ~= nil then
		for _, child in ipairs(arena:GetChildren()) do
			if
				child:IsA("BasePart")
				and (
					child.Name == "CourtyardFrame"
					or string.sub(child.Name, 1, 5) == "Lane_"
					or string.sub(child.Name, 1, 9) == "LaneVerge"
				)
			then
				floorTargets[#floorTargets + 1] = child
			end
		end
	end
	floorRayParams.FilterDescendantsInstances = floorTargets

	local trapTargets: { Instance } = {}
	local trapModels = Workspace:FindFirstChild("MuralhaTraps")
	if trapModels ~= nil then
		trapTargets[#trapTargets + 1] = trapModels
	end
	trapRayParams.FilterDescendantsInstances = trapTargets
end

local function slotFromHit(inst: Instance?): string?
	local cur: Instance? = inst
	while cur ~= nil do
		local slotAttr = cur:GetAttribute("Slot")
		if type(slotAttr) == "string" and slotAttr ~= "" then
			return slotAttr
		end
		local cellAttr = cur:GetAttribute("Cell")
		if type(cellAttr) == "string" and cellAttr ~= "" then
			return cellAttr
		end
		if cur:IsA("Model") and string.sub(cur.Name, 1, 5) == "Trap_" then
			return string.sub(cur.Name, 6)
		end
		cur = cur.Parent
	end
	return nil
end

local function raycastFloor(screenPos: Vector2): Vector3?
	updateRayTargets()
	if #floorRayParams.FilterDescendantsInstances == 0 then
		return nil
	end
	local ray = camera:ScreenPointToRay(screenPos.X, screenPos.Y)
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, floorRayParams)
	return if result ~= nil then result.Position else nil
end

local function nearestTrapSlotAt(worldPos: Vector3, maxStuds: number): string?
	if state.snapshot == nil or type(state.snapshot.cells) ~= "table" then
		return nil
	end
	local bestSlot: string? = nil
	local bestDist = maxStuds
	for slot, data in pairs(state.snapshot.cells) do
		local wx: number? = nil
		local wz: number? = nil
		if type(data.x) == "number" and type(data.y) == "number" then
			local ax, _, az = GridLayout.arenaPosToWorld(data.x, data.y)
			wx, wz = ax, az
		else
			local cx, _, cz = GridLayout.cellToWorld(slot)
			wx, wz = cx, cz
		end
		if wx ~= nil and wz ~= nil then
			local dx = worldPos.X - wx
			local dz = worldPos.Z - wz
			local dist = math.sqrt(dx * dx + dz * dz)
			if dist <= bestDist then
				bestDist = dist
				bestSlot = slot
			end
		end
	end
	return bestSlot
end

local function raycastTrapSlot(screenPos: Vector2): string?
	updateRayTargets()
	if #trapRayParams.FilterDescendantsInstances > 0 then
		local ray = camera:ScreenPointToRay(screenPos.X, screenPos.Y)
		local result = Workspace:Raycast(ray.Origin, ray.Direction * 500, trapRayParams)
		if result ~= nil then
			local hitSlot = slotFromHit(result.Instance)
			if hitSlot ~= nil then
				return hitSlot
			end
		end
	end
	local floorPos = raycastFloor(screenPos)
	if floorPos ~= nil then
		return nearestTrapSlotAt(floorPos, 3.2)
	end
	return nil
end

local function isPlacementValid(ax: number, ay: number, ignoreSlot: string?): boolean
	local okPos = GridLayout.validateArenaPos(ax, ay)
	if not okPos then
		return false
	end
	if state.snapshot == nil or type(state.snapshot.cells) ~= "table" then
		return true
	end
	for slot, data in pairs(state.snapshot.cells) do
		if slot ~= ignoreSlot then
			local bx: number? = nil
			local by: number? = nil
			if type(data.x) == "number" and type(data.y) == "number" then
				bx, by = data.x, data.y
			else
				bx, by = GridLayout.cellToArenaPos(slot)
			end
			if bx ~= nil and by ~= nil and GridLayout.tooClose(ax, ay, bx, by) then
				return false
			end
		end
	end
	return true
end

local function activeDiscTrapId(): string?
	if state.mode == "place" then
		return state.selectedTrap
	elseif state.mode == "move" and movingSlot ~= nil and state.snapshot ~= nil then
		local cell = if type(state.snapshot.cells) == "table"
			then state.snapshot.cells[movingSlot]
			else nil
		if type(cell) == "table" and type(cell.trap) == "string" then
			return cell.trap
		end
	end
	return nil
end

local function setPlacementDiscFromScreen(screenPos: Vector2?): ()
	if screenPos == nil or comboModal.Visible then
		ArenaVisual.setPlacementDisc(Workspace, nil, false, nil)
		return
	end
	local showForPlace = state.mode == "place"
		and state.selectedTrap ~= nil
		and state.selectedTrap ~= ""
	local showForMove = state.mode == "move" and movingSlot ~= nil
	if not showForPlace and not showForMove then
		ArenaVisual.setPlacementDisc(Workspace, nil, false, nil)
		return
	end
	local hitPos = raycastFloor(screenPos)
	if hitPos == nil then
		ArenaVisual.setPlacementDisc(Workspace, nil, false, nil)
		return
	end
	local ax, ay = GridLayout.worldToArenaPos(hitPos)
	local wx, _, wz = GridLayout.arenaPosToWorld(ax, ay)
	local ignoreSlot = if state.mode == "move" then movingSlot else nil
	local valid = isPlacementValid(ax, ay, ignoreSlot)
	ArenaVisual.setPlacementDisc(Workspace, Vector3.new(wx, 0.34, wz), valid, activeDiscTrapId())
end

local function switchToPlaceMode(): ()
	movingSlot = nil
	ArenaVisual.setPlacementDisc(Workspace, nil, false, nil)
	BuildClientState.setMode(state, "place")
	updateModeButtons()
	refreshSelection()
	updateCardAffordability()
end

local function onTap3D(screenPos: Vector2): ()
	if comboModal.Visible then
		return
	end
	if state.mode == "place" then
		local tappedSlot = raycastTrapSlot(screenPos)
		if
			tappedSlot ~= nil
			and state.snapshot ~= nil
			and type(state.snapshot.cells) == "table"
			and state.snapshot.cells[tappedSlot] ~= nil
		then
			if selectedWorldSlot == tappedSlot and contextTrapBar.Visible then
				closeContextBar()
			else
				selectedWorldSlot = tappedSlot
				contextTrapBar.Visible = true
				positionContextBar()
				ArenaVisual.setPlacementDisc(Workspace, nil, false, nil)
				AudioKit.play("ui_click")
				local data = state.snapshot.cells[tappedSlot]
				local upgradeCost = BuildClientState.upgradeCost(state, tappedSlot)
				local loc = UiKit.getLocale()
				if type(upgradeCost) == "number" and type(data) == "table" then
					setStatus(
						string.format(
							"%s L%d · ▲%dg",
							I18n.trapName(loc, data.trap),
							data.level or 1,
							upgradeCost
						)
					)
				elseif type(data) == "table" then
					setStatus(
						string.format("%s L%d", I18n.trapName(loc, data.trap), data.level or 1)
					)
				end
			end
			return
		end
		if contextTrapBar.Visible then
			closeContextBar()
			return
		end
		local hitPos = raycastFloor(screenPos)
		if hitPos == nil then
			ArenaVisual.setPlacementDisc(Workspace, nil, false, nil)
			return
		end
		local ax, ay = GridLayout.worldToArenaPos(hitPos)
		local wx, _, wz = GridLayout.arenaPosToWorld(ax, ay)
		local valid = isPlacementValid(ax, ay, nil)
		ArenaVisual.setPlacementDisc(
			Workspace,
			Vector3.new(wx, 0.34, wz),
			valid,
			activeDiscTrapId()
		)

		local intent, err = BuildClientState.intentAt(state, ax, ay, GridLayout)
		if intent == nil then
			AudioKit.play(if err == "trap_locked" then "build_locked" else "build_invalid")
			setStatus(statusFor(err, nil, "place"))
			return
		end
		send("place", intent.trapId, intent.slot or "", ax, ay)
		ArenaVisual.setPlacementDisc(Workspace, nil, false, nil)
	elseif state.mode == "move" then
		if movingSlot == nil then
			local slot = raycastTrapSlot(screenPos)
			if
				slot ~= nil
				and state.snapshot ~= nil
				and type(state.snapshot.cells) == "table"
				and state.snapshot.cells[slot] ~= nil
			then
				movingSlot = slot
				AudioKit.play("ui_click")
				refreshSelection()
			else
				switchToPlaceMode()
			end
		else
			local hitPos = raycastFloor(screenPos)
			if hitPos == nil then
				movingSlot = nil
				ArenaVisual.setPlacementDisc(Workspace, nil, false)
				refreshSelection()
				return
			end
			local ax, ay = GridLayout.worldToArenaPos(hitPos)
			local intent, err = BuildClientState.intentMove(state, movingSlot, ax, ay, GridLayout)
			if intent == nil then
				AudioKit.play("build_invalid")
				setStatus(statusFor(err, movingSlot, "move"))
				return
			end
			local targetSlot = movingSlot :: string
			movingSlot = nil
			ArenaVisual.setPlacementDisc(Workspace, nil, false)
			refreshSelection()
			send("move", "", targetSlot, ax, ay)
		end
	elseif state.mode == "upgrade" or state.mode == "remove" then
		local slot = raycastTrapSlot(screenPos)
		if slot == nil then
			switchToPlaceMode()
			return
		end
		if state.snapshot == nil then
			AudioKit.play("build_invalid")
			setStatus(msgFor("no_snapshot"))
			return
		end
		if type(state.snapshot.cells) ~= "table" or state.snapshot.cells[slot] == nil then
			AudioKit.play("build_invalid")
			setStatus(statusFor("empty_cell", slot, state.mode))
			return
		end
		send(state.mode, "", slot)
	end
end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed or player:GetAttribute("MuralhaInRaid") == true then
		return
	end
	if input.KeyCode == Enum.KeyCode.F3 then
		toggleDebug()
	elseif
		input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseButton1
	then
		touchOrigin = Vector2.new(input.Position.X, input.Position.Y)
		setPlacementDiscFromScreen(touchOrigin)
	end
end)

UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
	if processed or player:GetAttribute("MuralhaInRaid") == true then
		return
	end
	if
		input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch
	then
		setPlacementDiscFromScreen(Vector2.new(input.Position.X, input.Position.Y))
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject, processed: boolean)
	if processed or touchOrigin == nil then
		return
	end
	if player:GetAttribute("MuralhaInRaid") == true then
		touchOrigin = nil
		ArenaVisual.setPlacementDisc(Workspace, nil, false)
		return
	end
	if
		input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseButton1
	then
		local endPos = Vector2.new(input.Position.X, input.Position.Y)
		local delta = (endPos - touchOrigin).Magnitude
		touchOrigin = nil
		if delta <= TOUCH_SLOP_PX then
			onTap3D(endPos)
		elseif input.UserInputType == Enum.UserInputType.Touch then
			ArenaVisual.setPlacementDisc(Workspace, nil, false)
		end
	end
end)

player:GetAttributeChangedSignal("MuralhaInRaid"):Connect(function()
	local inRaid = player:GetAttribute("MuralhaInRaid") == true
	gui.Enabled = not inRaid
	if inRaid then
		touchOrigin = nil
		movingSlot = nil
		closeContextBar()
		comboModal.Visible = false
		ArenaVisual.setPlacementDisc(Workspace, nil, false)
	else
		refreshBuildCamera()
	end
end)

UiKit.onCameraAngleChanged(function()
	refreshCamButton()
	refreshBuildCamera()
	positionContextBar()
end)

UiKit.onLocaleChanged(function()
	refreshHeaderLabels(state.snapshot)
	refreshComboModal()
	updateModeButtons()
	refreshSelection()
	updateCardAffordability()
	if state.snapshot == nil then
		setStatus(msgFor("loading_profile"))
	end
end)

refreshHeaderLabels(state.snapshot)
updateModeButtons()
refreshSelection()
setStatus(msgFor("loading_profile"))

task.spawn(function()
	for attempt = 1, 60 do
		local ok, snapshot = pcall(function()
			return buildSnapshot:InvokeServer()
		end)
		if ok and type(snapshot) == "table" then
			refresh(snapshot)
			setStatus(msgFor("wall_loaded"))
			return
		end
		if attempt == 1 then
			setStatus(msgFor("waiting_profile"))
		end
		task.wait(0.5)
	end
	setStatus(msgFor("profile_timeout"))
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
	TrapKit.step(dt)
	hudAccumulator += dt
	if hudAccumulator >= 0.2 then
		hudAccumulator = 0
		debugMetrics.Text = BuildHud.formatMetrics(hud) .. " · " .. currentVersionText
	end
	if contextTrapBar.Visible then
		positionContextBar()
	end
end)
