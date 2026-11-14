--!strict
-- UI da Campanha "Cronicas do Bastiao" + HUD de Boss multi-lane.
-- Fica em src/client/visual/ para manter src/client/ raiz apenas com *.client.luau.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local bit32 = bit32

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildLayout = require(Shared:WaitForChild("build"):WaitForChild("BuildLayout"))
local CampaignCatalog = require(Shared:WaitForChild("campaign"):WaitForChild("CampaignCatalog"))
local I18n = require(Shared:WaitForChild("i18n"):WaitForChild("I18n"))
local VisualTheme = require(Shared:WaitForChild("visual"):WaitForChild("VisualTheme"))

local visual = script.Parent
local AudioKit = require(visual:WaitForChild("AudioKit"))
local UiKit = require(visual:WaitForChild("UiKit"))

export type CampaignUiOpts = {
	fetchState: () -> any,
	claimMilestone: (act: number) -> any,
	onLaunchStage: (stageId: string, difficulty: CampaignCatalog.DifficultyMode) -> (),
}

export type CampaignUiHandle = {
	storyButton: TextButton,
	bossHud: Frame,
	applyLayout: (hudRects: BuildLayout.HudLayout) -> (),
	refreshLocale: () -> (),
	setButtonsVisible: (visible: boolean) -> (),
	closeModal: () -> (),
	ingestCampaignSnapshot: (campaignTable: any) -> (),
	updateBossHud: (bossSnap: any?) -> (),
	hideBossHud: () -> (),
	showBossQuote: (bossId: string, eventKind: string, headWorldPos: Vector3?) -> (),
	stepBossBubble: (camera: Camera?, headWorldPos: Vector3?) -> (),
}

local BOSS_QUOTES: { [string]: { pt: string, en: string, es: string } } = {
	iron_ram_colossus_intro = {
		pt = "Pedra e madeira? Meu aríete vai reduzir sua muralha a pó!",
		en = "Stone and timber? My battering ram will smash your wall to dust!",
		es = "¿Piedra y madera? ¡Mi ariete reducirá tu muralla a polvo!",
	},
	iron_ram_colossus_enrage = {
		pt = "Ferro em carga máxima! Derrubem esse portão!",
		en = "Full iron charge! Tear down that gate!",
		es = "¡Carga máxima de hierro! ¡Derriben ese portón!",
	},
	slag_juggernaut_intro = {
		pt = "A forja ferve! Vou derreter cada bloco desse bastião!",
		en = "The furnace boils! I will melt every stone of this bastion!",
		es = "¡La forja arde! ¡Derretiré cada bloque de este bastión!",
	},
	slag_juggernaut_enrage = {
		pt = "Pressão no limite! Queimem sob a escória!",
		en = "Maximum pressure! Burn beneath the molten slag!",
		es = "¡Presión al límite! ¡Ardan bajo la escoria!",
	},
	rime_matriarch_intro = {
		pt = "Ajoelhem-se no gelo... o inverno veio calar suas torres!",
		en = "Kneel before the frost... winter has come to silence your towers!",
		es = "Arrodíllense ante el hielo... ¡el invierno vino a silenciar sus torres!",
	},
	rime_matriarch_enrage = {
		pt = "Nevasca eterna! Congelem até a alma!",
		en = "Eternal blizzard! Freeze to the very soul!",
		es = "¡Ventisca eterna! ¡Congélense hasta el alma!",
	},
	powder_baron_intro = {
		pt = "Acendam os pavios! Hoje essa fortaleza sobe pelos ares!",
		en = "Light the fuses! Tonight this fortress blows sky high!",
		es = "¡Enciendan las mechas! ¡Hoy esta fortaleza vuela por los aires!",
	},
	powder_baron_enrage = {
		pt = "Dobrem a pólvora! Fogo em todas as linhas!",
		en = "Double the powder! Fire across every lane!",
		es = "¡Doblen la pólvora! ¡Fuego en todas las líneas!",
	},
	rift_titan_intro = {
		pt = "Eu sou o abismo da Fenda... nenhuma muralha resiste ao meu despertar!",
		en = "I am the abyss of the Rift... no bastion survives my awakening!",
		es = "Soy el abismo de la Grieta... ¡ninguna muralla resiste mi despertar!",
	},
	rift_titan_enrage = {
		pt = "A Fenda se abre! Tudo será devorado!",
		en = "The Rift tears open! Everything will be devoured!",
		es = "¡La Grieta se abre! ¡Todo será devorado!",
	},
}

local CampaignUi = {}

local function applyRect(obj: GuiObject, r: BuildLayout.Rect): ()
	obj.Position = UDim2.fromOffset(r.x, r.y)
	obj.Size = UDim2.fromOffset(r.w, r.h)
end

local function makeStarString(count: number): string
	local filled = math.clamp(math.floor(count), 0, 3)
	return string.rep("★", filled) .. string.rep("☆", 3 - filled)
end

function CampaignUi.create(root: Frame, opts: CampaignUiOpts): CampaignUiHandle
	local selectedAct = 1
	local selectedDiff: CampaignCatalog.DifficultyMode = "normal"
	local latestCampaign: any = {
		highestUnlockedStage = "1-1",
		nightmareUnlocked = false,
		starsNormal = {},
		starsNightmare = {},
		actMilestoneClaims = { ["1"] = 0, ["2"] = 0, ["3"] = 0, ["4"] = 0, ["5"] = 0 },
	}
	local lockHintText = ""

	-- Botao CTA HISTORIA no Build HUD
	local storyButton = UiKit.button(root, "Story", "")
	storyButton.AnchorPoint = Vector2.zero
	storyButton.Position = UDim2.new(1, -130, 1, -154)
	storyButton.Size = UDim2.fromOffset(116, 44)
	storyButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	storyButton.Text = ""
	UiKit.corner(storyButton, 12)
	UiKit.stroke(storyButton, UiKit.color(VisualTheme.PALETTE.amberBright), 2, 0)

	local storyGradient = storyButton:FindFirstChildOfClass("UIGradient")
	if storyGradient ~= nil then
		storyGradient.Color =
			ColorSequence.new(Color3.fromRGB(109, 40, 217), Color3.fromRGB(217, 119, 6))
		storyGradient.Rotation = 18
	end
	local storyPad = storyButton:FindFirstChildOfClass("UIPadding")
	if storyPad ~= nil then
		storyPad.PaddingLeft = UDim.new(0, 0)
		storyPad.PaddingRight = UDim.new(0, 0)
		storyPad.PaddingTop = UDim.new(0, 0)
		storyPad.PaddingBottom = UDim.new(0, 0)
	end

	local storyIcon = Instance.new("Frame")
	storyIcon.Name = "Icon"
	storyIcon.AnchorPoint = Vector2.new(0, 0.5)
	storyIcon.Position = UDim2.new(0, 6, 0.5, 0)
	storyIcon.Size = UDim2.fromOffset(18, 18)
	storyIcon.BackgroundTransparency = 1
	storyIcon.Parent = storyButton

	local crownBase = Instance.new("Frame")
	crownBase.Name = "CrownBase"
	crownBase.AnchorPoint = Vector2.new(0.5, 0.5)
	crownBase.Position = UDim2.fromScale(0.5, 0.62)
	crownBase.Size = UDim2.fromScale(0.82, 0.44)
	crownBase.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.amberBright)
	crownBase.BorderSizePixel = 0
	crownBase.Parent = storyIcon
	UiKit.corner(crownBase, 3)

	for idx, px in ipairs({ 0.22, 0.50, 0.78 }) do
		local tip = Instance.new("Frame")
		tip.Name = "CrownTip_" .. tostring(idx)
		tip.AnchorPoint = Vector2.new(0.5, 0.5)
		tip.Position = UDim2.fromScale(px, 0.32)
		tip.Size = UDim2.fromScale(0.22, 0.34)
		tip.Rotation = 45
		tip.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.white)
		tip.BorderSizePixel = 0
		tip.Parent = storyIcon
		UiKit.corner(tip, 2)
	end

	local storyLabel = UiKit.label(
		storyButton,
		"Label",
		I18n.t(UiKit.getLocale(), "cta_story"),
		UiKit.color(VisualTheme.PALETTE.white),
		Enum.Font.GothamBlack
	)
	storyLabel.Position = UDim2.new(0, 26, 0, 4)
	storyLabel.Size = UDim2.new(1, -30, 1, -8)
	storyLabel.TextXAlignment = Enum.TextXAlignment.Center
	storyLabel.TextScaled = true
	storyLabel.TextWrapped = false
	local storyTextCap = Instance.new("UITextSizeConstraint")
	storyTextCap.MinTextSize = 10
	storyTextCap.MaxTextSize = 16
	storyTextCap.Parent = storyLabel
	UiKit.stroke(storyLabel, UiKit.color(VisualTheme.PALETTE.ink), 1.5, 0.25)

	-- Modal responsivo da Campanha (5 Atos x 5 Estagios)
	local modal = UiKit.panel(root, "CampaignModal")
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.Size = UDim2.fromOffset(520, 326)
	modal.Visible = false
	modal.ZIndex = 24
	UiKit.corner(modal, 14)
	UiKit.stroke(modal, UiKit.color(VisualTheme.PALETTE.amber), 2, 0.1)

	local headerTitle = UiKit.label(
		modal,
		"Title",
		I18n.t(UiKit.getLocale(), "story_title"),
		UiKit.color(VisualTheme.PALETTE.amberBright),
		Enum.Font.GothamBlack
	)
	headerTitle.Position = UDim2.fromOffset(12, 8)
	headerTitle.Size = UDim2.new(0.52, -12, 0, 28)
	headerTitle.TextScaled = true
	headerTitle.TextWrapped = false
	headerTitle.TextTruncate = Enum.TextTruncate.AtEnd
	headerTitle.ZIndex = 25

	local diffNormalBtn =
		UiKit.button(modal, "DiffNormal", I18n.t(UiKit.getLocale(), "story_normal"))
	diffNormalBtn.AnchorPoint = Vector2.zero
	diffNormalBtn.Position = UDim2.new(1, -216, 0, 6)
	diffNormalBtn.Size = UDim2.fromOffset(80, 36)
	diffNormalBtn.ZIndex = 25
	UiKit.corner(diffNormalBtn, 8)

	local diffNmBtn =
		UiKit.button(modal, "DiffNightmare", I18n.t(UiKit.getLocale(), "story_nightmare"))
	diffNmBtn.AnchorPoint = Vector2.zero
	diffNmBtn.Position = UDim2.new(1, -132, 0, 6)
	diffNmBtn.Size = UDim2.fromOffset(82, 36)
	diffNmBtn.ZIndex = 25
	UiKit.corner(diffNmBtn, 8)

	local modalCloseBtn = UiKit.button(modal, "ModalClose", "X")
	modalCloseBtn.AnchorPoint = Vector2.zero
	modalCloseBtn.Position = UDim2.new(1, -46, 0, 4)
	modalCloseBtn.Size = UDim2.fromOffset(44, 44)
	modalCloseBtn.ZIndex = 25
	UiKit.corner(modalCloseBtn, 10)

	local actTabRow = Instance.new("Frame")
	actTabRow.Name = "ActTabs"
	actTabRow.Position = UDim2.fromOffset(12, 46)
	actTabRow.Size = UDim2.new(1, -24, 0, 36)
	actTabRow.BackgroundTransparency = 1
	actTabRow.ZIndex = 25
	actTabRow.Parent = modal

	local actTabLayout = Instance.new("UIListLayout")
	actTabLayout.FillDirection = Enum.FillDirection.Horizontal
	actTabLayout.Padding = UDim.new(0, 4)
	actTabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	actTabLayout.Parent = actTabRow

	local actButtons: { TextButton } = {}
	for actIdx = 1, CampaignCatalog.ACT_COUNT do
		local tabBtn = UiKit.button(actTabRow, "Act_" .. tostring(actIdx), "A" .. tostring(actIdx))
		tabBtn.Size = UDim2.new(0.2, -4, 0, 34)
		tabBtn.ZIndex = 26
		UiKit.corner(tabBtn, 8)
		actButtons[actIdx] = tabBtn
	end

	local actMetaRow = Instance.new("Frame")
	actMetaRow.Name = "ActMeta"
	actMetaRow.Position = UDim2.fromOffset(12, 84)
	actMetaRow.Size = UDim2.new(1, -24, 0, 34)
	actMetaRow.BackgroundTransparency = 1
	actMetaRow.ZIndex = 25
	actMetaRow.Parent = modal

	local actTitleLbl = UiKit.label(
		actMetaRow,
		"ActName",
		"",
		UiKit.color(VisualTheme.PALETTE.parchment),
		Enum.Font.GothamBold
	)
	actTitleLbl.Position = UDim2.fromOffset(0, 0)
	actTitleLbl.Size = UDim2.new(0.56, 0, 1, 0)
	actTitleLbl.TextScaled = true
	actTitleLbl.TextWrapped = false
	actTitleLbl.TextTruncate = Enum.TextTruncate.AtEnd
	actTitleLbl.ZIndex = 25

	local actStarsLbl = UiKit.label(
		actMetaRow,
		"ActStars",
		"",
		UiKit.color(VisualTheme.PALETTE.amberBright),
		Enum.Font.GothamBlack
	)
	actStarsLbl.Position = UDim2.new(0.56, 4, 0, 0)
	actStarsLbl.Size = UDim2.new(0.18, 0, 1, 0)
	actStarsLbl.TextXAlignment = Enum.TextXAlignment.Center
	actStarsLbl.TextScaled = true
	actStarsLbl.ZIndex = 25

	local claimBtn = UiKit.button(actMetaRow, "ClaimMilestone", "")
	claimBtn.AnchorPoint = Vector2.new(1, 0.5)
	claimBtn.Position = UDim2.fromScale(1, 0.5)
	claimBtn.Size = UDim2.new(0.24, 0, 0, 32)
	claimBtn.ZIndex = 26
	UiKit.corner(claimBtn, 8)
	local claimCap = Instance.new("UITextSizeConstraint")
	claimCap.MinTextSize = 9
	claimCap.MaxTextSize = 13
	claimCap.Parent = claimBtn

	local stageList = Instance.new("ScrollingFrame")
	stageList.Name = "StageList"
	stageList.Position = UDim2.fromOffset(12, 120)
	stageList.Size = UDim2.new(1, -24, 1, -138)
	stageList.BackgroundTransparency = 1
	stageList.BorderSizePixel = 0
	stageList.ScrollBarThickness = 5
	stageList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	stageList.CanvasSize = UDim2.new(0, 0, 0, 0)
	stageList.ZIndex = 25
	stageList.Parent = modal

	local stageListLayout = Instance.new("UIListLayout")
	stageListLayout.Padding = UDim.new(0, 5)
	stageListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	stageListLayout.Parent = stageList

	local hintLabel = UiKit.label(
		modal,
		"Hint",
		"",
		UiKit.color(VisualTheme.PALETTE.amberBright),
		Enum.Font.GothamBold
	)
	hintLabel.Position = UDim2.new(0, 12, 1, -18)
	hintLabel.Size = UDim2.new(1, -24, 0, 16)
	hintLabel.TextXAlignment = Enum.TextXAlignment.Center
	hintLabel.TextScaled = true
	hintLabel.ZIndex = 25

	type StageRow = {
		frame: Frame,
		nameLbl: TextLabel,
		metaLbl: TextLabel,
		playBtn: TextButton,
	}
	local stageRows: { StageRow } = {}
	for rowIdx = 1, CampaignCatalog.STAGES_PER_ACT do
		local rowFrame = Instance.new("Frame")
		rowFrame.Name = "Stage_" .. tostring(rowIdx)
		rowFrame.LayoutOrder = rowIdx
		rowFrame.Size = UDim2.new(1, -6, 0, 48)
		rowFrame.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.ironDark)
		rowFrame.BorderSizePixel = 0
		rowFrame.ZIndex = 26
		rowFrame.Parent = stageList
		UiKit.corner(rowFrame, 8)

		local sName = UiKit.label(
			rowFrame,
			"Name",
			"",
			UiKit.color(VisualTheme.PALETTE.parchment),
			Enum.Font.GothamBlack
		)
		sName.Position = UDim2.fromOffset(8, 3)
		sName.Size = UDim2.new(0.68, -8, 0, 21)
		sName.TextScaled = true
		sName.TextWrapped = false
		sName.TextTruncate = Enum.TextTruncate.AtEnd
		sName.ZIndex = 27

		local sMeta = UiKit.label(
			rowFrame,
			"Meta",
			"",
			UiKit.color(VisualTheme.PALETTE.amberBright),
			Enum.Font.GothamBold
		)
		sMeta.Position = UDim2.fromOffset(8, 25)
		sMeta.Size = UDim2.new(0.68, -8, 0, 19)
		sMeta.TextScaled = true
		sMeta.TextWrapped = false
		sMeta.TextTruncate = Enum.TextTruncate.AtEnd
		sMeta.ZIndex = 27

		local playBtn = UiKit.button(rowFrame, "Play", "")
		playBtn.AnchorPoint = Vector2.new(1, 0.5)
		playBtn.Position = UDim2.new(1, -4, 0.5, 0)
		playBtn.Size = UDim2.new(0.28, -4, 0, 44)
		playBtn.ZIndex = 27
		UiKit.corner(playBtn, 8)
		local pCap = Instance.new("UITextSizeConstraint")
		pCap.MinTextSize = 10
		pCap.MaxTextSize = 14
		pCap.Parent = playBtn

		stageRows[rowIdx] = {
			frame = rowFrame,
			nameLbl = sName,
			metaLbl = sMeta,
			playBtn = playBtn,
		}
	end

	-- HUD do Boss ao vivo em combate
	local bossHud = UiKit.panel(root, "BossHud")
	bossHud.AnchorPoint = Vector2.zero
	bossHud.Position = UDim2.fromOffset(192, 54)
	bossHud.Size = UDim2.fromOffset(280, 44)
	bossHud.BackgroundTransparency = 0.14
	bossHud.Visible = false
	bossHud.ZIndex = 17
	UiKit.corner(bossHud, 10)
	UiKit.stroke(bossHud, UiKit.color(VisualTheme.PALETTE.danger), 1.5, 0.15)

	local bossNameLbl = UiKit.label(
		bossHud,
		"BossName",
		"BOSS",
		UiKit.color(VisualTheme.PALETTE.white),
		Enum.Font.GothamBlack
	)
	bossNameLbl.Position = UDim2.fromOffset(8, 2)
	bossNameLbl.Size = UDim2.new(0.60, -8, 0, 16)
	bossNameLbl.TextScaled = true
	bossNameLbl.TextWrapped = false
	bossNameLbl.TextTruncate = Enum.TextTruncate.AtEnd
	bossNameLbl.ZIndex = 18
	local bossNameCap = Instance.new("UITextSizeConstraint")
	bossNameCap.MinTextSize = 9
	bossNameCap.MaxTextSize = 13
	bossNameCap.Parent = bossNameLbl

	local bossStateLbl = UiKit.label(
		bossHud,
		"BossState",
		"",
		UiKit.color(VisualTheme.PALETTE.amberBright),
		Enum.Font.GothamBlack
	)
	bossStateLbl.Position = UDim2.new(0.60, 0, 0, 2)
	bossStateLbl.Size = UDim2.new(0.40, -8, 0, 16)
	bossStateLbl.TextXAlignment = Enum.TextXAlignment.Right
	bossStateLbl.TextScaled = true
	bossStateLbl.TextWrapped = false
	bossStateLbl.TextTruncate = Enum.TextTruncate.AtEnd
	bossStateLbl.ZIndex = 18
	local bossStateCap = Instance.new("UITextSizeConstraint")
	bossStateCap.MinTextSize = 9
	bossStateCap.MaxTextSize = 11
	bossStateCap.Parent = bossStateLbl

	local bossHpBar = UiKit.progress(bossHud, "BossHp", UiKit.color(VisualTheme.PALETTE.danger))
	bossHpBar.frame.Position = UDim2.fromOffset(8, 21)
	bossHpBar.frame.Size = UDim2.new(1, -16, 0, 9)
	bossHpBar.frame.ZIndex = 18
	bossHpBar.fill.ZIndex = 18

	local bossStaggerBar =
		UiKit.progress(bossHud, "BossStagger", UiKit.color(VisualTheme.PALETTE.teal))
	bossStaggerBar.frame.Position = UDim2.fromOffset(8, 33)
	bossStaggerBar.frame.Size = UDim2.new(1, -16, 0, 6)
	bossStaggerBar.frame.ZIndex = 18
	bossStaggerBar.fill.ZIndex = 18

	local quoteToken = 0
	local latestHudRects: BuildLayout.HudLayout? = nil
	local lastHeadWorldPos: Vector3? = nil
	local quoteStreamConn: RBXScriptConnection? = nil

	local bossBubble = Instance.new("Frame")
	bossBubble.Name = "BossSpeechBubble"
	bossBubble.AnchorPoint = Vector2.zero
	bossBubble.Position = UDim2.fromOffset(0, 0)
	bossBubble.Size = UDim2.fromOffset(188, 36)
	bossBubble.BackgroundColor3 = Color3.fromRGB(14, 19, 32)
	bossBubble.BackgroundTransparency = 0.12
	bossBubble.BorderSizePixel = 0
	bossBubble.Active = false
	bossBubble.ClipsDescendants = false
	bossBubble.Visible = false
	bossBubble.ZIndex = 16
	bossBubble.Parent = root
	UiKit.corner(bossBubble, 8)
	local bossBubbleStroke =
		UiKit.stroke(bossBubble, UiKit.color(VisualTheme.PALETTE.amberBright), 1.5, 0.08)
	local bossBubbleScale = Instance.new("UIScale")
	bossBubbleScale.Scale = 1
	bossBubbleScale.Parent = bossBubble

	local bossBubbleTail = Instance.new("Frame")
	bossBubbleTail.Name = "Tail"
	bossBubbleTail.AnchorPoint = Vector2.new(0.5, 0.5)
	bossBubbleTail.Position = UDim2.fromOffset(94, 36)
	bossBubbleTail.Size = UDim2.fromOffset(7, 7)
	bossBubbleTail.Rotation = 45
	bossBubbleTail.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.amberBright)
	bossBubbleTail.BackgroundTransparency = 0.08
	bossBubbleTail.BorderSizePixel = 0
	bossBubbleTail.Active = false
	bossBubbleTail.ZIndex = 15
	bossBubbleTail.Parent = bossBubble

	local bossQuoteLbl = UiKit.label(
		bossBubble,
		"QuoteText",
		"",
		UiKit.color(VisualTheme.PALETTE.parchment),
		Enum.Font.GothamBold
	)
	bossQuoteLbl.Position = UDim2.fromOffset(8, 4)
	bossQuoteLbl.Size = UDim2.new(1, -16, 1, -9)
	bossQuoteLbl.TextXAlignment = Enum.TextXAlignment.Left
	bossQuoteLbl.TextYAlignment = Enum.TextYAlignment.Center
	bossQuoteLbl.TextScaled = false
	bossQuoteLbl.TextSize = 11
	bossQuoteLbl.TextWrapped = true
	bossQuoteLbl.TextTruncate = Enum.TextTruncate.None
	bossQuoteLbl.RichText = false
	bossQuoteLbl.Active = false
	bossQuoteLbl.ZIndex = 17

	local function stopQuoteStream(): ()
		if quoteStreamConn ~= nil then
			quoteStreamConn:Disconnect()
			quoteStreamConn = nil
		end
	end

	local function computeBubbleSize(quote: string): (number, number, number)
		local isDesktop = if latestHudRects ~= nil then latestHudRects.isDesktop else false
		local isPortrait = if latestHudRects ~= nil then latestHudRects.isPortrait else false
		local bubbleW = if isDesktop then 224 elseif isPortrait then 196 else 188
		local fontSize = if isDesktop then 12 else 11
		local ok, bounds = pcall(function()
			return TextService:GetTextSize(
				quote,
				fontSize,
				Enum.Font.GothamBold,
				Vector2.new(bubbleW - 16, 120)
			)
		end)
		local textH = if ok and typeof(bounds) == "Vector2" then math.ceil(bounds.Y) else 26
		local bubbleH = math.clamp(textH + 10, 28, 58)
		return bubbleW, bubbleH, fontSize
	end

	local function positionBossBubble(camera: Camera?, headWorldPos: Vector3?): ()
		local worldPos = headWorldPos or lastHeadWorldPos
		if worldPos == nil then
			return
		end
		local cam = camera or Workspace.CurrentCamera
		if cam == nil then
			return
		end
		local vpPt, onScreen = cam:WorldToViewportPoint(worldPos)
		if not onScreen and vpPt.Z <= 0 then
			return
		end
		local rootPos = root.AbsolutePosition
		local rootSize = root.AbsoluteSize
		if rootSize.X <= 0 or rootSize.Y <= 0 then
			return
		end
		local localX = vpPt.X - rootPos.X
		local localY = vpPt.Y - rootPos.Y
		local bw = bossBubble.Size.X.Offset
		local bh = bossBubble.Size.Y.Offset
		local minTopY = 56
		if latestHudRects ~= nil then
			local topBottom = math.max(
				latestHudRects.combatTopPill.y + latestHudRects.combatTopPill.h,
				if bossHud.Visible
					then latestHudRects.combatBossPill.y + latestHudRects.combatBossPill.h
					else 0
			)
			minTopY = topBottom + 6
		end
		local maxBottomY = math.max(minTopY, rootSize.Y - 56 - bh)
		local bx = math.clamp(math.floor(localX - bw * 0.5), 8, math.max(8, rootSize.X - bw - 8))
		local by = math.clamp(math.floor(localY - bh - 10), minTopY, maxBottomY)
		local tailX = math.clamp(math.floor(localX - bx), 14, math.max(14, bw - 14))
		bossBubble.Position = UDim2.fromOffset(bx, by)
		bossBubbleTail.Position = UDim2.fromOffset(tailX, bh)
	end

	local function claimableGoldForAct(actIdx: number): number
		local claims = latestCampaign.actMilestoneClaims
		local claimedMask = if type(claims) == "table"
			then (tonumber(claims[tostring(actIdx)]) or 0)
			else 0
		local actTotal = CampaignCatalog.actStarCount(latestCampaign, actIdx, "normal")
			+ CampaignCatalog.actStarCount(latestCampaign, actIdx, "nightmare")
		local totalGold = 0
		for _, m in ipairs(CampaignCatalog.ACT_MILESTONES) do
			if actTotal >= m.threshold and bit32.band(claimedMask, m.bit) == 0 then
				totalGold += m.gold
			end
		end
		return totalGold
	end

	local rowStageIds: { [number]: string } = {}

	local function renderModal(): ()
		local loc = UiKit.getLocale()
		storyLabel.Text = I18n.t(loc, "cta_story")
		headerTitle.Text = I18n.t(loc, "story_title")
		diffNormalBtn.Text = I18n.t(loc, "story_normal")
		diffNmBtn.Text = I18n.t(loc, "story_nightmare")

		UiKit.setSelected(diffNormalBtn, selectedDiff == "normal")
		UiKit.setSelected(diffNmBtn, selectedDiff == "nightmare")
		local nmUnlocked = type(latestCampaign) == "table"
			and latestCampaign.nightmareUnlocked == true
		diffNmBtn.BackgroundTransparency = if nmUnlocked then 0 else 0.45

		for idx, btn in ipairs(actButtons) do
			UiKit.setSelected(btn, idx == selectedAct)
		end

		local actName = CampaignCatalog.ACT_NAMES[selectedAct] or ""
		actTitleLbl.Text = I18n.t(loc, "story_act_fmt", selectedAct, actName)
		local actStars = CampaignCatalog.actStarCount(latestCampaign, selectedAct, selectedDiff)
		actStarsLbl.Text = I18n.t(loc, "story_stars_fmt", actStars, 15)

		local claimGold = claimableGoldForAct(selectedAct)
		if claimGold > 0 then
			claimBtn.Visible = true
			claimBtn.Active = true
			claimBtn.Text = string.format("%s +%dg", I18n.t(loc, "cta_claim"), claimGold)
		else
			claimBtn.Visible = false
			claimBtn.Active = false
		end

		local stages = CampaignCatalog.getAct(selectedAct)
		local starsMap = if selectedDiff == "nightmare"
			then (latestCampaign.starsNightmare or {})
			else (latestCampaign.starsNormal or {})
		for idx, row in ipairs(stageRows) do
			local st = stages[idx]
			if st == nil then
				row.frame.Visible = false
				rowStageIds[idx] = ""
			else
				row.frame.Visible = true
				rowStageIds[idx] = st.stageId
				local bossTag = if st.bossId ~= nil then " · BOSS" else ""
				row.nameLbl.Text = string.format("%s · %s%s", st.stageId, st.name, bossTag)
				local mask = tonumber(starsMap[st.stageId]) or 0
				local stars = CampaignCatalog.starsFromMask(mask)
				local goldReward = if mask == 0 then st.rewardGoldFirst else st.rewardGoldRepeat
				if selectedDiff == "nightmare" then
					goldReward = math.floor(goldReward * 1.5)
				end
				row.metaLbl.Text = string.format("%s  ·  +%dg", makeStarString(stars), goldReward)

				local unlocked =
					CampaignCatalog.isUnlocked(latestCampaign, st.stageId, selectedDiff)
				row.playBtn.Active = unlocked
				row.playBtn.BackgroundTransparency = if unlocked then 0 else 0.5
				row.playBtn.Text = if unlocked then I18n.t(loc, "cta_play") else "LOCK"
			end
		end
		hintLabel.Text = lockHintText
	end

	for idx, row in ipairs(stageRows) do
		row.playBtn.MouseButton1Click:Connect(function()
			local stageId = rowStageIds[idx]
			if stageId == nil or stageId == "" then
				return
			end
			local unlocked = CampaignCatalog.isUnlocked(latestCampaign, stageId, selectedDiff)
			if not unlocked then
				AudioKit.play("build_locked")
				return
			end
			AudioKit.play("campaign_select")
			modal.Visible = false
			opts.onLaunchStage(stageId, selectedDiff)
		end)
	end

	for idx, btn in ipairs(actButtons) do
		btn.MouseButton1Click:Connect(function()
			selectedAct = idx
			lockHintText = ""
			AudioKit.play("campaign_select")
			renderModal()
		end)
	end

	diffNormalBtn.MouseButton1Click:Connect(function()
		selectedDiff = "normal"
		lockHintText = ""
		AudioKit.play("campaign_select")
		renderModal()
	end)

	diffNmBtn.MouseButton1Click:Connect(function()
		local nmUnlocked = type(latestCampaign) == "table"
			and latestCampaign.nightmareUnlocked == true
		if not nmUnlocked then
			AudioKit.play("build_locked")
			lockHintText = I18n.t(UiKit.getLocale(), "story_locked_nm")
			renderModal()
			return
		end
		selectedDiff = "nightmare"
		lockHintText = ""
		AudioKit.play("campaign_select")
		renderModal()
	end)

	claimBtn.MouseButton1Click:Connect(function()
		local res = opts.claimMilestone(selectedAct)
		if type(res) == "table" and res.ok == true then
			if type(res.campaign) == "table" then
				latestCampaign = res.campaign
			end
			AudioKit.play("campaign_act_clear")
			AudioKit.play("coin_gain")
			renderModal()
		else
			AudioKit.play("build_invalid")
		end
	end)

	modalCloseBtn.MouseButton1Click:Connect(function()
		AudioKit.play("ui_click")
		modal.Visible = false
	end)

	storyButton.MouseButton1Click:Connect(function()
		AudioKit.play("ui_click")
		lockHintText = ""
		local res = opts.fetchState()
		if type(res) == "table" and res.ok == true and type(res.campaign) == "table" then
			latestCampaign = res.campaign
		end
		modal.Visible = not modal.Visible
		if modal.Visible then
			renderModal()
		end
	end)

	return {
		storyButton = storyButton,
		bossHud = bossHud,
		applyLayout = function(hudRects: BuildLayout.HudLayout): ()
			latestHudRects = hudRects
			applyRect(storyButton, hudRects.storyBtn)
			applyRect(bossHud, hudRects.combatBossPill)
			if bossBubble.Visible and bossQuoteLbl.Text ~= "" then
				local bw, bh, fontSize = computeBubbleSize(bossQuoteLbl.Text)
				bossQuoteLbl.TextSize = fontSize
				bossBubble.Size = UDim2.fromOffset(bw, bh)
				positionBossBubble(nil, nil)
			end
			local mw = math.clamp(hudRects.width - 20, 304, 560)
			local mh = math.clamp(hudRects.height - 20, 256, 348)
			modal.Size = UDim2.fromOffset(mw, mh)
		end,
		refreshLocale = function(): ()
			renderModal()
		end,
		setButtonsVisible = function(visible: boolean): ()
			storyButton.Visible = visible
		end,
		closeModal = function(): ()
			modal.Visible = false
		end,
		ingestCampaignSnapshot = function(campaignTable: any): ()
			if type(campaignTable) == "table" then
				latestCampaign = campaignTable
				if modal.Visible then
					renderModal()
				end
			end
		end,
		updateBossHud = function(bossSnap: any?): ()
			if type(bossSnap) ~= "table" or bossSnap.alive ~= true then
				bossHud.Visible = false
				return
			end
			local loc = UiKit.getLocale()
			local bSpec = CampaignCatalog.BOSS_SPECS[tostring(bossSnap.bossId)]
			local bossAct = if bSpec ~= nil then bSpec.act else 1
			bossNameLbl.Text = I18n.t(loc, "boss_" .. tostring(bossAct))

			local maxHp = math.max(1, tonumber(bossSnap.maxHp) or 1)
			local hp = math.max(0, tonumber(bossSnap.hp) or 0)
			bossHpBar.set(math.clamp(hp / maxHp, 0, 1))

			local stagCap = math.max(1, tonumber(bossSnap.staggerCapMilli) or 1)
			local stag = math.max(0, tonumber(bossSnap.staggerMilli) or 0)
			bossStaggerBar.set(math.clamp(stag / stagCap, 0, 1))

			local bState = tostring(bossSnap.state or "MARCH")
			if bState == "TELEGRAPH" then
				bossStateLbl.Text = I18n.t(loc, "boss_telegraph_tag")
				bossStateLbl.TextColor3 = UiKit.color(VisualTheme.PALETTE.danger)
			elseif bState == "VULNERABLE" then
				bossStateLbl.Text = I18n.t(loc, "boss_vulnerable_tag")
				bossStateLbl.TextColor3 = UiKit.color(VisualTheme.PALETTE.teal)
			elseif bossSnap.enraged == true then
				bossStateLbl.Text = I18n.t(loc, "boss_enrage_tag")
				bossStateLbl.TextColor3 = UiKit.color(VisualTheme.PALETTE.danger)
			else
				bossStateLbl.Text = ""
			end
			bossHud.Visible = true
		end,
		hideBossHud = function(): ()
			bossHud.Visible = false
			quoteToken += 1
			stopQuoteStream()
			bossBubble.Visible = false
		end,
		stepBossBubble = function(camera: Camera?, headWorldPos: Vector3?): ()
			if headWorldPos ~= nil then
				lastHeadWorldPos = headWorldPos
			end
			if bossBubble.Visible then
				positionBossBubble(camera, headWorldPos)
			end
		end,
		showBossQuote = function(bossId: string, eventKind: string, headWorldPos: Vector3?): ()
			local key = bossId .. (if eventKind == "enrage" then "_enrage" else "_intro")
			local entry = BOSS_QUOTES[key]
			if entry == nil then
				return
			end
			local loc = UiKit.getLocale()
			local quote = if loc == "en" then entry.en elseif loc == "es" then entry.es else entry.pt
			stopQuoteStream()
			quoteToken += 1
			local myToken = quoteToken
			if headWorldPos ~= nil then
				lastHeadWorldPos = headWorldPos
			end

			local isEnrage = eventKind == "enrage"
			local accent = UiKit.color(
				if isEnrage then VisualTheme.PALETTE.danger else VisualTheme.PALETTE.amberBright
			)
			bossBubbleStroke.Color = accent
			bossBubbleTail.BackgroundColor3 = accent
			bossBubble.BackgroundTransparency = 0.12
			bossBubbleStroke.Transparency = 0.08
			bossBubbleTail.BackgroundTransparency = 0.08
			bossQuoteLbl.TextTransparency = 0

			local bw, bh, fontSize = computeBubbleSize(quote)
			bossQuoteLbl.TextSize = fontSize
			bossQuoteLbl.Text = quote
			local totalGraphemes = utf8.len(quote) or #quote
			bossQuoteLbl.MaxVisibleGraphemes = 0
			bossBubble.Size = UDim2.fromOffset(bw, bh)
			positionBossBubble(Workspace.CurrentCamera, headWorldPos)

			bossBubbleScale.Scale = 0.86
			bossBubble.Visible = true
			TweenService:Create(
				bossBubbleScale,
				TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			):Play()

			local startedAt = time()
			local streamDuration = totalGraphemes / 36
			local holdUntil = startedAt + streamDuration + 1.85
			local fadeDuration = 0.22
			quoteStreamConn = RunService.Heartbeat:Connect(function()
				if quoteToken ~= myToken or not bossBubble.Visible or bossBubble.Parent == nil then
					stopQuoteStream()
					return
				end
				local now = time()
				local elapsed = now - startedAt
				local shown = math.clamp(math.floor(elapsed * 36), 1, totalGraphemes)
				bossQuoteLbl.MaxVisibleGraphemes = shown
				if now >= holdUntil then
					local alpha = math.clamp((now - holdUntil) / fadeDuration, 0, 1)
					bossBubble.BackgroundTransparency = 0.12 + 0.88 * alpha
					bossBubbleStroke.Transparency = 0.08 + 0.92 * alpha
					bossBubbleTail.BackgroundTransparency = 0.08 + 0.92 * alpha
					bossQuoteLbl.TextTransparency = alpha
					if alpha >= 1 then
						stopQuoteStream()
						bossBubble.Visible = false
						bossQuoteLbl.MaxVisibleGraphemes = -1
					end
				end
			end)
		end,
	}
end

return CampaignUi
