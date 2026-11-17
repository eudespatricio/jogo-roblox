--!strict
-- Cortina de transicao e tela de confronto Card 1 VS Card 2 no estilo Champion Card LoL.
-- Zero CanvasGroup (texto vetorial 100% nitido em mobile), retratos 2D splash pintados
-- publicados no Open Cloud (`UiAssets.CARD_PORTRAITS`), animacao Ken Burns + sheen metalico
-- e divisoria circular de nivel integrada dentro da moldura dourada.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local I18n = require(Shared:WaitForChild("i18n"):WaitForChild("I18n"))
local UiAssets = require(Shared:WaitForChild("visual"):WaitForChild("UiAssets"))
local VisualTheme = require(Shared:WaitForChild("visual"):WaitForChild("VisualTheme"))

local visual = script.Parent
local AudioKit = require(visual:WaitForChild("AudioKit"))
local UiKit = require(visual:WaitForChild("UiKit"))

export type TrapChip = {
	type: string,
	level: number,
	count: number?,
}

export type MatchCard = {
	side: string?,
	role: string?,
	faction: string?,
	isBot: boolean?,
	name: string?,
	league: number?,
	points: number?,
	wallLevel: number?,
	wallHp: number?,
	trapCount: number?,
	trapLimit: number?,
	waveCount: number?,
	wins: number?,
	stageId: string?,
	act: number?,
	difficulty: string?,
	bossId: string?,
	traps: { TrapChip }?,
	unitClasses: { string }?,
}

export type MatchupPayload = {
	card1: MatchCard?,
	card2: MatchCard?,
}

local TransitionKit = {}

local CARD_W = 236
local CARD_H = 352
local CENTER_COL_W = 92
local STAGE_LANDSCAPE_W = CARD_W * 2 + CENTER_COL_W
local STAGE_LANDSCAPE_H = CARD_H
local PORTRAIT_CENTER_H = 54
local STAGE_PORTRAIT_W = 260
local STAGE_PORTRAIT_H = CARD_H * 2 + PORTRAIT_CENTER_H + 12

local PORTRAIT_H = 216
local DIVIDER_Y = 218

local COL_BG = Color3.fromRGB(7, 10, 18)
local COL_CARD_PLATE = Color3.fromRGB(10, 14, 23)
local COL_SLOT_BG = Color3.fromRGB(16, 22, 34)
local COL_GOLD_BRIGHT = Color3.fromRGB(252, 229, 136)
local COL_GOLD_TRIM = Color3.fromRGB(200, 155, 60)
local COL_GOLD_DARK = Color3.fromRGB(98, 66, 22)
local COL_AMBER = UiKit.color(VisualTheme.PALETTE.amber)
local COL_AMBER_BRIGHT = UiKit.color(VisualTheme.PALETTE.amberBright)
local COL_TEAL_BRIGHT = Color3.fromRGB(94, 234, 212)
local COL_DANGER = UiKit.color(VisualTheme.PALETTE.danger)
local COL_PURPLE = Color3.fromRGB(167, 139, 250)
local COL_PARCHMENT = UiKit.color(VisualTheme.PALETTE.parchment)
local COL_SUBTITLE = Color3.fromRGB(176, 188, 206)
local COL_STAT_ATK = Color3.fromRGB(253, 186, 116)
local COL_STAT_HP = Color3.fromRGB(252, 165, 165)
local COL_WHITE = Color3.fromRGB(250, 250, 255)
local COL_INK = Color3.fromRGB(5, 8, 15)

local TEXTS: { [string]: { pt: string, en: string, es: string } } = {
	mode_raid = { pt = "ATAQUE", en = "ASSAULT", es = "ASALTO" },
	mode_defend = { pt = "DEFESA", en = "DEFENSE", es = "DEFENSA" },
	mode_campaign = { pt = "CAMPANHA", en = "CAMPAIGN", es = "CAMPANA" },
	sub_raid = { pt = "Fenda Rival", en = "Rival Bastion", es = "Bastion Rival" },
	sub_defend = { pt = "Cerco", en = "Siege", es = "Asedio" },
	role_attacker = { pt = "ATACANTE", en = "ATTACKER", es = "ATACANTE" },
	role_defender = { pt = "DEFENSOR", en = "DEFENDER", es = "DEFENSOR" },
	role_boss = { pt = "CHEFE DE ATO", en = "ACT BOSS", es = "JEFE DE ACTO" },
	role_horde = { pt = "HORDA", en = "HORDE", es = "HORDA" },
	tag_you = { pt = "VOCE", en = "YOU", es = "TU" },
	tag_rival = { pt = "RIVAL", en = "RIVAL", es = "RIVAL" },
	tag_bot = { pt = "BOT", en = "BOT", es = "BOT" },
	tag_horde = { pt = "HORDA", en = "HORDE", es = "HORDA" },
	tag_boss = { pt = "CHEFE", en = "BOSS", es = "JEFE" },
	stat_traps = { pt = "Armadilhas", en = "Traps", es = "Trampas" },
	stat_wins = { pt = "Vit.", en = "Wins", es = "Vict." },
	stat_wave = { pt = "Onda", en = "Wave", es = "Oleada" },
	diff_normal = { pt = "NORMAL", en = "NORMAL", es = "NORMAL" },
	diff_nightmare = { pt = "PESADELO", en = "NIGHTMARE", es = "PESADILLA" },
	lv_prefix = { pt = "Nv", en = "Lv", es = "Nv" },
	league_prefix = { pt = "LIGA", en = "LEAGUE", es = "LIGA" },
	mobs_unit = { pt = "unid.", en = "units", es = "unid." },
	searching_title = {
		pt = "BUSCANDO...",
		en = "SCOUTING...",
		es = "BUSCANDO...",
	},
	searching_sub = {
		pt = "Pareando liga...",
		en = "Matching tier...",
		es = "Emparejando...",
	},
	tap_to_start = {
		pt = "TOQUE P/ INICIAR",
		en = "TAP TO BEGIN",
		es = "TOCA P/ INICIAR",
	},
	loading_scene = {
		pt = "Carregando arena...",
		en = "Loading arena...",
		es = "Cargando arena...",
	},
	no_traps = {
		pt = "Muralha sem armadilhas",
		en = "Unfortified wall",
		es = "Muralla sin trampas",
	},
	horde_swarm = {
		pt = "Formacao da Fenda",
		en = "Rift Assault Formation",
		es = "Formacion de Grieta",
	},
	act_prefix = { pt = "ATO", en = "ACT", es = "ACTO" },
}

local function tr(key: string): string
	local entry = TEXTS[key]
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

type CardView = {
	root: Frame,
	frameGrad: UIGradient,
	inner: Frame,
	innerTrimStroke: UIStroke,
	portraitMask: Frame,
	portraitImg: ImageLabel,
	portraitGlow: Frame,
	portraitGlowGrad: UIGradient,
	rimStroke: UIStroke,
	sheen: Frame,
	originPill: Frame,
	originText: TextLabel,
	tierPill: Frame,
	tierText: TextLabel,
	levelMedallion: Frame,
	levelMedallionGrad: UIGradient,
	levelMedallionStroke: UIStroke,
	levelText: TextLabel,
	subtitleLabel: TextLabel,
	nameLabel: TextLabel,
	roleMetaLabel: TextLabel,
	leftSlot: Frame,
	leftSlotStroke: UIStroke,
	leftSlotText: TextLabel,
	centerRune: Frame,
	rightSlot: Frame,
	rightSlotStroke: UIStroke,
	rightSlotText: TextLabel,
}

type UiState = {
	gui: ScreenGui,
	rootFrame: Frame,
	backdropImg: ImageLabel,
	vignette: Frame,
	curtainCenter: Frame,
	curtainTitle: TextLabel,
	curtainSub: TextLabel,
	curtainBarFill: Frame,
	matchupWrap: Frame,
	stage: Frame,
	stageScale: UIScale,
	centerCol: Frame,
	modePill: Frame,
	modeLabel: TextLabel,
	modeSub: TextLabel,
	vsBadge: Frame,
	vsScale: UIScale,
	footer: Frame,
	footerText: TextLabel,
	footerFill: Frame,
	card1: CardView,
	card2: CardView,
	skipButton: TextButton,
	transitionFlash: Frame,
	activeTween: Tween?,
	activeSession: number,
	skipPressed: boolean,
	preloaded: boolean,
}

local cached: UiState? = nil

local function cancelTween(state: UiState): ()
	if state.activeTween ~= nil then
		state.activeTween:Cancel()
		state.activeTween = nil
	end
end

local function createCornerWing(parent: Frame, name: string, pos: UDim2, anchor: Vector2): Frame
	local wing = Instance.new("Frame")
	wing.Name = name
	wing.AnchorPoint = anchor
	wing.Position = pos
	wing.Size = UDim2.fromOffset(10, 10)
	wing.Rotation = 45
	wing.BackgroundColor3 = COL_GOLD_BRIGHT
	wing.BorderSizePixel = 0
	wing.ZIndex = 18
	wing.Parent = parent
	UiKit.corner(wing, 2)
	UiKit.stroke(wing, COL_INK, 1.5, 0)
	return wing
end

local function createLoRCardView(parent: Frame, name: string): CardView
	local root = Instance.new("Frame")
	root.Name = name
	root.Size = UDim2.fromOffset(CARD_W, CARD_H)
	root.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	root.BorderSizePixel = 0
	root.ClipsDescendants = false
	root.Parent = parent
	UiKit.corner(root, 8)
	UiKit.stroke(root, COL_INK, 2.2, 0.05)

	local frameGrad = Instance.new("UIGradient")
	frameGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, COL_GOLD_BRIGHT),
		ColorSequenceKeypoint.new(0.42, COL_GOLD_TRIM),
		ColorSequenceKeypoint.new(0.78, COL_GOLD_DARK),
		ColorSequenceKeypoint.new(1, COL_GOLD_TRIM),
	})
	frameGrad.Rotation = 135
	frameGrad.Parent = root

	-- Ornamentos discretos nos cantos superiores (asas estilo LoL)
	createCornerWing(root, "WingTopLeft", UDim2.fromOffset(4, 4), Vector2.new(0.5, 0.5))
	createCornerWing(root, "WingTopRight", UDim2.new(1, -4, 0, 4), Vector2.new(0.5, 0.5))

	local inner = Instance.new("Frame")
	inner.Name = "CardBody"
	inner.Position = UDim2.fromOffset(4, 4)
	inner.Size = UDim2.new(1, -8, 1, -8)
	inner.BackgroundColor3 = COL_CARD_PLATE
	inner.BorderSizePixel = 0
	inner.ClipsDescendants = true
	inner.ZIndex = 2
	inner.Parent = root
	UiKit.corner(inner, 6)
	local innerTrimStroke = UiKit.stroke(inner, COL_GOLD_TRIM, 1, 0.25)

	-- Área da Splash Art (~63% da altura da carta)
	local portraitMask = Instance.new("Frame")
	portraitMask.Name = "PortraitMask"
	portraitMask.Position = UDim2.fromOffset(0, 0)
	portraitMask.Size = UDim2.new(1, 0, 0, PORTRAIT_H)
	portraitMask.BackgroundColor3 = COL_CARD_PLATE
	portraitMask.BorderSizePixel = 0
	portraitMask.ClipsDescendants = true
	portraitMask.ZIndex = 3
	portraitMask.Parent = inner

	local portraitGlow = Instance.new("Frame")
	portraitGlow.Name = "PortraitBackdrop"
	portraitGlow.Size = UDim2.fromScale(1, 1)
	portraitGlow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	portraitGlow.BorderSizePixel = 0
	portraitGlow.ZIndex = 3
	portraitGlow.Parent = portraitMask

	local portraitGlowGrad = Instance.new("UIGradient")
	portraitGlowGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(14, 22, 38)),
		ColorSequenceKeypoint.new(0.65, Color3.fromRGB(38, 28, 18)),
		ColorSequenceKeypoint.new(1, COL_CARD_PLATE),
	})
	portraitGlowGrad.Rotation = 90
	portraitGlowGrad.Parent = portraitGlow

	local rimStroke = UiKit.stroke(portraitMask, COL_GOLD_TRIM, 1, 0.6)

	local portraitImg = Instance.new("ImageLabel")
	portraitImg.Name = "SplashPortrait"
	portraitImg.AnchorPoint = Vector2.new(0.5, 0.42)
	portraitImg.Position = UDim2.fromScale(0.5, 0.45)
	portraitImg.Size = UDim2.fromScale(1.06, 1.06)
	portraitImg.BackgroundTransparency = 1
	portraitImg.Image = UiAssets.CARD_PORTRAITS.bastion_warden
	portraitImg.ScaleType = Enum.ScaleType.Crop
	portraitImg.ZIndex = 4
	portraitImg.Parent = portraitMask

	-- Reflexo metalico diagonal animado sobre o splash art
	local sheen = Instance.new("Frame")
	sheen.Name = "SpecularSheen"
	sheen.AnchorPoint = Vector2.new(0.5, 0.5)
	sheen.Position = UDim2.fromScale(-0.35, 0.48)
	sheen.Size = UDim2.fromOffset(58, 360)
	sheen.Rotation = 26
	sheen.BackgroundColor3 = COL_WHITE
	sheen.BackgroundTransparency = 0.86
	sheen.BorderSizePixel = 0
	sheen.ZIndex = 5
	sheen.Parent = portraitMask
	local sheenGrad = Instance.new("UIGradient")
	sheenGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.45, 0.55),
		NumberSequenceKeypoint.new(0.5, 0.30),
		NumberSequenceKeypoint.new(0.55, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	sheenGrad.Parent = sheen

	-- Degrade suave na base da imagem para fundir na placa escura (efeito LoL)
	local portraitFade = Instance.new("Frame")
	portraitFade.Name = "PortraitBottomFade"
	portraitFade.AnchorPoint = Vector2.new(0, 1)
	portraitFade.Position = UDim2.new(0, 0, 1, 0)
	portraitFade.Size = UDim2.new(1, 0, 0, 72)
	portraitFade.BackgroundColor3 = COL_CARD_PLATE
	portraitFade.BorderSizePixel = 0
	portraitFade.ZIndex = 6
	portraitFade.Parent = portraitMask
	local fadeGrad = Instance.new("UIGradient")
	fadeGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 0.58),
		NumberSequenceKeypoint.new(0.82, 0.14),
		NumberSequenceKeypoint.new(1, 0),
	})
	fadeGrad.Rotation = 90
	fadeGrad.Parent = portraitFade

	-- Tags discretas alinhadas no topo interno (sem tampar rosto!)
	local originPill = Instance.new("Frame")
	originPill.Name = "OriginTag"
	originPill.Position = UDim2.fromOffset(7, 7)
	originPill.Size = UDim2.fromOffset(78, 19)
	originPill.BackgroundColor3 = COL_INK
	originPill.BackgroundTransparency = 0.28
	originPill.BorderSizePixel = 0
	originPill.ZIndex = 8
	originPill.Parent = portraitMask
	UiKit.corner(originPill, 4)
	UiKit.stroke(originPill, COL_GOLD_TRIM, 1, 0.3)

	local originText =
		UiKit.label(originPill, "Text", "VOCE", COL_GOLD_BRIGHT, Enum.Font.GothamBlack)
	originText.Size = UDim2.fromScale(1, 1)
	originText.TextXAlignment = Enum.TextXAlignment.Center
	originText.TextScaled = false
	originText.TextSize = 12
	originText.ZIndex = 9

	local tierPill = Instance.new("Frame")
	tierPill.Name = "TierBadge"
	tierPill.AnchorPoint = Vector2.new(1, 0)
	tierPill.Position = UDim2.new(1, -7, 0, 7)
	tierPill.Size = UDim2.fromOffset(42, 19)
	tierPill.BackgroundColor3 = COL_INK
	tierPill.BackgroundTransparency = 0.28
	tierPill.BorderSizePixel = 0
	tierPill.ZIndex = 8
	tierPill.Parent = portraitMask
	UiKit.corner(tierPill, 4)
	UiKit.stroke(tierPill, COL_GOLD_TRIM, 1, 0.3)

	local tierText = UiKit.label(tierPill, "Text", "L1", COL_PARCHMENT, Enum.Font.GothamBlack)
	tierText.Size = UDim2.fromScale(1, 1)
	tierText.TextXAlignment = Enum.TextXAlignment.Center
	tierText.TextScaled = false
	tierText.TextSize = 12
	tierText.ZIndex = 9

	-- Placa inferior escura (#0A0E17)
	local plateBg = Instance.new("Frame")
	plateBg.Name = "CardPlate"
	plateBg.Position = UDim2.fromOffset(0, DIVIDER_Y)
	plateBg.Size = UDim2.new(1, 0, 1, -DIVIDER_Y)
	plateBg.BackgroundColor3 = COL_CARD_PLATE
	plateBg.BorderSizePixel = 0
	plateBg.ZIndex = 6
	plateBg.Parent = inner

	-- Divisor dourado horizontal com medalhao circular de nivel no centro (assinatura LoL)
	local dividerBar = Instance.new("Frame")
	dividerBar.Name = "GoldDivider"
	dividerBar.AnchorPoint = Vector2.new(0, 0.5)
	dividerBar.Position = UDim2.fromOffset(0, DIVIDER_Y)
	dividerBar.Size = UDim2.new(1, 0, 0, 2)
	dividerBar.BackgroundColor3 = COL_GOLD_TRIM
	dividerBar.BorderSizePixel = 0
	dividerBar.ZIndex = 11
	dividerBar.Parent = inner
	local divGrad = Instance.new("UIGradient")
	divGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.65),
		NumberSequenceKeypoint.new(0.25, 0),
		NumberSequenceKeypoint.new(0.75, 0),
		NumberSequenceKeypoint.new(1, 0.65),
	})
	divGrad.Parent = dividerBar

	local levelMedallion = Instance.new("Frame")
	levelMedallion.Name = "LevelMedallion"
	levelMedallion.AnchorPoint = Vector2.new(0.5, 0.5)
	levelMedallion.Position = UDim2.new(0.5, 0, 0, DIVIDER_Y)
	levelMedallion.Size = UDim2.fromOffset(36, 36)
	levelMedallion.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	levelMedallion.BorderSizePixel = 0
	levelMedallion.ZIndex = 15
	levelMedallion.Parent = inner
	UiKit.corner(levelMedallion, 18)
	local levelMedallionStroke = UiKit.stroke(levelMedallion, COL_GOLD_BRIGHT, 2, 0)

	local levelMedallionGrad = Instance.new("UIGradient")
	levelMedallionGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(54, 72, 108)),
		ColorSequenceKeypoint.new(0.65, Color3.fromRGB(22, 32, 54)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(8, 12, 22)),
	})
	levelMedallionGrad.Rotation = 135
	levelMedallionGrad.Parent = levelMedallion

	local levelText =
		UiKit.label(levelMedallion, "Val", "1", COL_GOLD_BRIGHT, Enum.Font.GothamBlack)
	levelText.Size = UDim2.fromScale(1, 1)
	levelText.TextXAlignment = Enum.TextXAlignment.Center
	levelText.TextScaled = false
	levelText.TextSize = 16
	levelText.ZIndex = 16
	UiKit.stroke(levelText, COL_INK, 1.8, 0)

	-- Tipografia enxuta e centralizada abaixo do medalhao
	local subtitleLabel =
		UiKit.label(inner, "SubtitleMeta", "LIGA 1 · VOCE", COL_SUBTITLE, Enum.Font.GothamBold)
	subtitleLabel.Position = UDim2.fromOffset(10, 240)
	subtitleLabel.Size = UDim2.new(1, -20, 0, 15)
	subtitleLabel.TextXAlignment = Enum.TextXAlignment.Center
	subtitleLabel.TextScaled = false
	subtitleLabel.TextSize = 12
	subtitleLabel.ZIndex = 10

	local nameLabel = UiKit.label(inner, "ChampionName", "PLAYER", COL_WHITE, Enum.Font.GothamBlack)
	nameLabel.Position = UDim2.fromOffset(10, 256)
	nameLabel.Size = UDim2.new(1, -20, 0, 24)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextScaled = true
	nameLabel.TextWrapped = false
	nameLabel.ZIndex = 10
	UiKit.stroke(nameLabel, COL_INK, 2, 0)
	local nameCap = Instance.new("UITextSizeConstraint")
	nameCap.MinTextSize = 13
	nameCap.MaxTextSize = 19
	nameCap.Parent = nameLabel

	local roleMetaLabel =
		UiKit.label(inner, "RoleFormation", "-", COL_GOLD_BRIGHT, Enum.Font.GothamBold)
	roleMetaLabel.Position = UDim2.fromOffset(10, 281)
	roleMetaLabel.Size = UDim2.new(1, -20, 0, 20)
	roleMetaLabel.TextXAlignment = Enum.TextXAlignment.Center
	roleMetaLabel.TextScaled = true
	roleMetaLabel.TextWrapped = false
	roleMetaLabel.RichText = true
	roleMetaLabel.ZIndex = 10
	local roleCap = Instance.new("UITextSizeConstraint")
	roleCap.MinTextSize = 12
	roleCap.MaxTextSize = 13
	roleCap.Parent = roleMetaLabel

	-- Barra inferior integrada (sem caixas saltando para fora!)
	local footerRule = Instance.new("Frame")
	footerRule.Name = "FooterRule"
	footerRule.Position = UDim2.fromOffset(12, 304)
	footerRule.Size = UDim2.new(1, -24, 0, 1)
	footerRule.BackgroundColor3 = COL_GOLD_DARK
	footerRule.BackgroundTransparency = 0.25
	footerRule.BorderSizePixel = 0
	footerRule.ZIndex = 10
	footerRule.Parent = inner

	local leftSlot = Instance.new("Frame")
	leftSlot.Name = "LeftStatSlot"
	leftSlot.Position = UDim2.fromOffset(10, 310)
	leftSlot.Size = UDim2.new(0.42, -4, 0, 26)
	leftSlot.BackgroundColor3 = COL_SLOT_BG
	leftSlot.BorderSizePixel = 0
	leftSlot.ZIndex = 10
	leftSlot.Parent = inner
	UiKit.corner(leftSlot, 5)
	local leftSlotStroke = UiKit.stroke(leftSlot, COL_GOLD_DARK, 1.2, 0.15)

	local leftSlotText = UiKit.label(leftSlot, "Val", "⚔ 0", COL_STAT_ATK, Enum.Font.GothamBlack)
	leftSlotText.Size = UDim2.fromScale(1, 1)
	leftSlotText.TextXAlignment = Enum.TextXAlignment.Center
	leftSlotText.TextScaled = false
	leftSlotText.TextSize = 13
	leftSlotText.ZIndex = 11

	local centerRune = Instance.new("Frame")
	centerRune.Name = "FactionGem"
	centerRune.AnchorPoint = Vector2.new(0.5, 0.5)
	centerRune.Position = UDim2.new(0.5, 0, 0, 323)
	centerRune.Size = UDim2.fromOffset(14, 14)
	centerRune.Rotation = 45
	centerRune.BackgroundColor3 = COL_AMBER
	centerRune.BorderSizePixel = 0
	centerRune.ZIndex = 12
	centerRune.Parent = inner
	UiKit.corner(centerRune, 3)
	UiKit.stroke(centerRune, COL_GOLD_BRIGHT, 1.5, 0)

	local rightSlot = Instance.new("Frame")
	rightSlot.Name = "RightStatSlot"
	rightSlot.AnchorPoint = Vector2.new(1, 0)
	rightSlot.Position = UDim2.new(1, -10, 0, 310)
	rightSlot.Size = UDim2.new(0.42, -4, 0, 26)
	rightSlot.BackgroundColor3 = COL_SLOT_BG
	rightSlot.BorderSizePixel = 0
	rightSlot.ZIndex = 10
	rightSlot.Parent = inner
	UiKit.corner(rightSlot, 5)
	local rightSlotStroke = UiKit.stroke(rightSlot, COL_GOLD_DARK, 1.2, 0.15)

	local rightSlotText =
		UiKit.label(rightSlot, "Val", "♥ 500", COL_STAT_HP, Enum.Font.GothamBlack)
	rightSlotText.Size = UDim2.fromScale(1, 1)
	rightSlotText.TextXAlignment = Enum.TextXAlignment.Center
	rightSlotText.TextScaled = false
	rightSlotText.TextSize = 13
	rightSlotText.ZIndex = 11

	return {
		root = root,
		frameGrad = frameGrad,
		inner = inner,
		innerTrimStroke = innerTrimStroke,
		portraitMask = portraitMask,
		portraitImg = portraitImg,
		portraitGlow = portraitGlow,
		portraitGlowGrad = portraitGlowGrad,
		rimStroke = rimStroke,
		sheen = sheen,
		originPill = originPill,
		originText = originText,
		tierPill = tierPill,
		tierText = tierText,
		levelMedallion = levelMedallion,
		levelMedallionGrad = levelMedallionGrad,
		levelMedallionStroke = levelMedallionStroke,
		levelText = levelText,
		subtitleLabel = subtitleLabel,
		nameLabel = nameLabel,
		roleMetaLabel = roleMetaLabel,
		leftSlot = leftSlot,
		leftSlotStroke = leftSlotStroke,
		leftSlotText = leftSlotText,
		centerRune = centerRune,
		rightSlot = rightSlot,
		rightSlotStroke = rightSlotStroke,
		rightSlotText = rightSlotText,
	}
end

local function updateResponsiveLayout(state: UiState): ()
	local cam = Workspace.CurrentCamera
	local vp = if cam ~= nil then cam.ViewportSize else Vector2.new(1280, 720)
	local w = math.max(320, vp.X)
	local h = math.max(320, vp.Y)
	local isPortrait = w < h * 1.08

	if isPortrait then
		state.stage.Size = UDim2.fromOffset(STAGE_PORTRAIT_W, STAGE_PORTRAIT_H)

		state.card1.root.AnchorPoint = Vector2.new(0.5, 0)
		state.card1.root.Position = UDim2.new(0.5, 0, 0, 0)

		state.centerCol.AnchorPoint = Vector2.new(0.5, 0)
		state.centerCol.Position = UDim2.new(0.5, 0, 0, CARD_H + 6)
		state.centerCol.Size = UDim2.fromOffset(STAGE_PORTRAIT_W, PORTRAIT_CENTER_H)

		state.modePill.AnchorPoint = Vector2.new(0, 0.5)
		state.modePill.Position = UDim2.new(0, 0, 0.5, 0)
		state.modePill.Size = UDim2.fromOffset(92, 46)

		state.vsBadge.AnchorPoint = Vector2.new(0.5, 0.5)
		state.vsBadge.Position = UDim2.fromScale(0.5, 0.5)
		state.vsBadge.Size = UDim2.fromOffset(54, 54)

		state.footer.AnchorPoint = Vector2.new(1, 0.5)
		state.footer.Position = UDim2.new(1, 0, 0.5, 0)
		state.footer.Size = UDim2.fromOffset(92, 46)

		state.card2.root.AnchorPoint = Vector2.new(0.5, 0)
		state.card2.root.Position = UDim2.new(0.5, 0, 0, CARD_H + PORTRAIT_CENTER_H + 12)

		local s = math.clamp(
			math.min((w - 20) / STAGE_PORTRAIT_W, (h - 24) / STAGE_PORTRAIT_H),
			0.66,
			1.36
		)
		state.stageScale.Scale = s
	else
		state.stage.Size = UDim2.fromOffset(STAGE_LANDSCAPE_W, STAGE_LANDSCAPE_H)

		state.card1.root.AnchorPoint = Vector2.new(0, 0.5)
		state.card1.root.Position = UDim2.new(0, 0, 0.5, 0)

		state.centerCol.AnchorPoint = Vector2.new(0, 0.5)
		state.centerCol.Position = UDim2.new(0, CARD_W, 0.5, 0)
		state.centerCol.Size = UDim2.fromOffset(CENTER_COL_W, CARD_H)

		state.modePill.AnchorPoint = Vector2.new(0.5, 0)
		state.modePill.Position = UDim2.new(0.5, 0, 0, 14)
		state.modePill.Size = UDim2.fromOffset(88, 52)

		state.vsBadge.AnchorPoint = Vector2.new(0.5, 0.5)
		state.vsBadge.Position = UDim2.fromScale(0.5, 0.5)
		state.vsBadge.Size = UDim2.fromOffset(68, 68)

		state.footer.AnchorPoint = Vector2.new(0.5, 1)
		state.footer.Position = UDim2.new(0.5, 0, 1, -14)
		state.footer.Size = UDim2.fromOffset(88, 50)

		state.card2.root.AnchorPoint = Vector2.new(1, 0.5)
		state.card2.root.Position = UDim2.new(1, 0, 0.5, 0)

		local s = math.clamp(
			math.min((w - 24) / (STAGE_LANDSCAPE_W + 16), (h - 14) / (STAGE_LANDSCAPE_H + 14)),
			0.70,
			1.36
		)
		state.stageScale.Scale = s
	end
end

local function buildUi(): UiState
	if cached ~= nil and cached.gui.Parent ~= nil then
		return cached
	end

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "MuralhaTransitionGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 65
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Enabled = false
	gui.Parent = playerGui

	local rootFrame = Instance.new("Frame")
	rootFrame.Name = "RootFrame"
	rootFrame.Size = UDim2.fromScale(1, 1)
	rootFrame.BackgroundColor3 = COL_BG
	rootFrame.BackgroundTransparency = 0
	rootFrame.BorderSizePixel = 0
	rootFrame.Parent = gui

	local backdropImg = Instance.new("ImageLabel")
	backdropImg.Name = "KeyArtBackdrop"
	backdropImg.Size = UDim2.fromScale(1, 1)
	backdropImg.BackgroundTransparency = 1
	backdropImg.Image = UiAssets.TRANSITION_BG
	backdropImg.ScaleType = Enum.ScaleType.Crop
	backdropImg.ImageTransparency = 0.24
	backdropImg.ZIndex = 1
	backdropImg.Parent = rootFrame

	local vignette = Instance.new("Frame")
	vignette.Name = "ContrastVignette"
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundColor3 = COL_BG
	vignette.BackgroundTransparency = 0.36
	vignette.BorderSizePixel = 0
	vignette.ZIndex = 2
	vignette.Parent = rootFrame

	-- Cortina simples (retorno ao Build / saida do DropIn)
	local curtainCenter = Instance.new("Frame")
	curtainCenter.Name = "QuickCurtain"
	curtainCenter.AnchorPoint = Vector2.new(0.5, 0.5)
	curtainCenter.Position = UDim2.fromScale(0.5, 0.5)
	curtainCenter.Size = UDim2.fromOffset(320, 122)
	curtainCenter.BackgroundColor3 = COL_CARD_PLATE
	curtainCenter.BackgroundTransparency = 0.16
	curtainCenter.BorderSizePixel = 0
	curtainCenter.Visible = false
	curtainCenter.ZIndex = 10
	curtainCenter.Parent = rootFrame
	UiKit.corner(curtainCenter, 12)
	UiKit.stroke(curtainCenter, COL_GOLD_TRIM, 2, 0)

	local curtainTitle = UiKit.label(
		curtainCenter,
		"CurtainTitle",
		I18n.t(UiKit.getLocale(), "game_title"),
		COL_GOLD_BRIGHT,
		Enum.Font.GothamBlack
	)
	curtainTitle.Position = UDim2.fromOffset(18, 16)
	curtainTitle.Size = UDim2.new(1, -36, 0, 34)
	curtainTitle.TextXAlignment = Enum.TextXAlignment.Center
	curtainTitle.TextScaled = false
	curtainTitle.TextSize = 24
	curtainTitle.ZIndex = 11

	local curtainSub = UiKit.label(
		curtainCenter,
		"CurtainSub",
		tr("loading_scene"),
		COL_PARCHMENT,
		Enum.Font.GothamBold
	)
	curtainSub.Position = UDim2.fromOffset(18, 54)
	curtainSub.Size = UDim2.new(1, -36, 0, 22)
	curtainSub.TextXAlignment = Enum.TextXAlignment.Center
	curtainSub.TextScaled = false
	curtainSub.TextSize = 14
	curtainSub.ZIndex = 11

	local curtainTrack = Instance.new("Frame")
	curtainTrack.Name = "CurtainTrack"
	curtainTrack.Position = UDim2.fromOffset(26, 88)
	curtainTrack.Size = UDim2.new(1, -52, 0, 8)
	curtainTrack.BackgroundColor3 = COL_INK
	curtainTrack.BorderSizePixel = 0
	curtainTrack.ZIndex = 11
	curtainTrack.Parent = curtainCenter
	UiKit.corner(curtainTrack, 4)

	local curtainBarFill = Instance.new("Frame")
	curtainBarFill.Name = "Fill"
	curtainBarFill.Size = UDim2.fromScale(0.35, 1)
	curtainBarFill.BackgroundColor3 = COL_AMBER
	curtainBarFill.BorderSizePixel = 0
	curtainBarFill.ZIndex = 12
	curtainBarFill.Parent = curtainTrack
	UiKit.corner(curtainBarFill, 4)

	-- Matchup Container
	local matchupWrap = Instance.new("Frame")
	matchupWrap.Name = "MatchupContainer"
	matchupWrap.Size = UDim2.fromScale(1, 1)
	matchupWrap.BackgroundTransparency = 1
	matchupWrap.ZIndex = 5
	matchupWrap.Parent = rootFrame

	local stage = Instance.new("Frame")
	stage.Name = "CardsStage"
	stage.AnchorPoint = Vector2.new(0.5, 0.5)
	stage.Position = UDim2.fromScale(0.5, 0.5)
	stage.Size = UDim2.fromOffset(STAGE_LANDSCAPE_W, STAGE_LANDSCAPE_H)
	stage.BackgroundTransparency = 1
	stage.ZIndex = 5
	stage.Parent = matchupWrap

	local stageScale = Instance.new("UIScale")
	stageScale.Scale = 1
	stageScale.Parent = stage

	local card1 = createLoRCardView(stage, "Card1")
	local card2 = createLoRCardView(stage, "Card2")

	local centerCol = Instance.new("Frame")
	centerCol.Name = "CenterVSColumn"
	centerCol.Position = UDim2.fromOffset(CARD_W, 0)
	centerCol.Size = UDim2.fromOffset(CENTER_COL_W, CARD_H)
	centerCol.BackgroundTransparency = 1
	centerCol.ZIndex = 10
	centerCol.Parent = stage

	local modePill = Instance.new("Frame")
	modePill.Name = "ModeBanner"
	modePill.Size = UDim2.fromOffset(88, 52)
	modePill.BackgroundColor3 = COL_CARD_PLATE
	modePill.BackgroundTransparency = 0.14
	modePill.BorderSizePixel = 0
	modePill.ZIndex = 11
	modePill.Parent = centerCol
	UiKit.corner(modePill, 7)
	UiKit.stroke(modePill, COL_GOLD_TRIM, 1.5, 0.1)

	local modeLabel =
		UiKit.label(modePill, "ModeTitle", "ATAQUE", COL_GOLD_BRIGHT, Enum.Font.GothamBlack)
	modeLabel.Position = UDim2.fromOffset(4, 5)
	modeLabel.Size = UDim2.new(1, -8, 0, 20)
	modeLabel.TextXAlignment = Enum.TextXAlignment.Center
	modeLabel.TextScaled = true
	modeLabel.ZIndex = 12
	local modeCap = Instance.new("UITextSizeConstraint")
	modeCap.MinTextSize = 12
	modeCap.MaxTextSize = 15
	modeCap.Parent = modeLabel

	local modeSub = UiKit.label(modePill, "ModeSub", "", COL_PARCHMENT, Enum.Font.GothamBold)
	modeSub.Position = UDim2.fromOffset(4, 26)
	modeSub.Size = UDim2.new(1, -8, 0, 20)
	modeSub.TextXAlignment = Enum.TextXAlignment.Center
	modeSub.TextScaled = true
	modeSub.TextWrapped = false
	modeSub.ZIndex = 12
	local subCap = Instance.new("UITextSizeConstraint")
	subCap.MinTextSize = 12
	subCap.MaxTextSize = 14
	subCap.Parent = modeSub

	local vsBadge = Instance.new("Frame")
	vsBadge.Name = "VsCrest"
	vsBadge.Size = UDim2.fromOffset(68, 68)
	vsBadge.BackgroundTransparency = 1
	vsBadge.ZIndex = 12
	vsBadge.Parent = centerCol

	local vsScale = Instance.new("UIScale")
	vsScale.Scale = 1
	vsScale.Parent = vsBadge

	local vsWingL = Instance.new("Frame")
	vsWingL.Name = "WingL"
	vsWingL.AnchorPoint = Vector2.new(1, 0.5)
	vsWingL.Position = UDim2.new(0.5, -26, 0.5, 0)
	vsWingL.Size = UDim2.fromOffset(14, 2)
	vsWingL.BackgroundColor3 = COL_GOLD_TRIM
	vsWingL.BorderSizePixel = 0
	vsWingL.ZIndex = 11
	vsWingL.Parent = vsBadge

	local vsWingR = Instance.new("Frame")
	vsWingR.Name = "WingR"
	vsWingR.AnchorPoint = Vector2.new(0, 0.5)
	vsWingR.Position = UDim2.new(0.5, 26, 0.5, 0)
	vsWingR.Size = UDim2.fromOffset(14, 2)
	vsWingR.BackgroundColor3 = COL_GOLD_TRIM
	vsWingR.BorderSizePixel = 0
	vsWingR.ZIndex = 11
	vsWingR.Parent = vsBadge

	local vsDiamond = Instance.new("Frame")
	vsDiamond.Name = "Diamond"
	vsDiamond.AnchorPoint = Vector2.new(0.5, 0.5)
	vsDiamond.Position = UDim2.fromScale(0.5, 0.5)
	vsDiamond.Size = UDim2.fromOffset(46, 46)
	vsDiamond.Rotation = 45
	vsDiamond.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	vsDiamond.BorderSizePixel = 0
	vsDiamond.ZIndex = 12
	vsDiamond.Parent = vsBadge
	UiKit.corner(vsDiamond, 7)
	UiKit.stroke(vsDiamond, COL_GOLD_BRIGHT, 2, 0)

	local vsGrad = Instance.new("UIGradient")
	vsGrad.Color = ColorSequence.new(Color3.fromRGB(48, 28, 18), Color3.fromRGB(16, 12, 22))
	vsGrad.Rotation = 45
	vsGrad.Parent = vsDiamond

	local vsText = UiKit.label(vsBadge, "VsText", "VS", COL_GOLD_BRIGHT, Enum.Font.GothamBlack)
	vsText.AnchorPoint = Vector2.new(0.5, 0.5)
	vsText.Position = UDim2.fromScale(0.5, 0.5)
	vsText.Size = UDim2.fromOffset(52, 34)
	vsText.TextXAlignment = Enum.TextXAlignment.Center
	vsText.TextScaled = false
	vsText.TextSize = 21
	vsText.ZIndex = 14
	UiKit.stroke(vsText, COL_INK, 2.2, 0)

	local footer = Instance.new("Frame")
	footer.Name = "FooterStatus"
	footer.Size = UDim2.fromOffset(88, 50)
	footer.BackgroundColor3 = COL_CARD_PLATE
	footer.BackgroundTransparency = 0.14
	footer.BorderSizePixel = 0
	footer.ZIndex = 11
	footer.Parent = centerCol
	UiKit.corner(footer, 7)
	UiKit.stroke(footer, COL_GOLD_DARK, 1.5, 0.1)

	local footerText =
		UiKit.label(footer, "StatusText", tr("tap_to_start"), COL_PARCHMENT, Enum.Font.GothamBlack)
	footerText.Position = UDim2.fromOffset(4, 4)
	footerText.Size = UDim2.new(1, -8, 0, 28)
	footerText.TextXAlignment = Enum.TextXAlignment.Center
	footerText.TextScaled = true
	footerText.TextWrapped = true
	footerText.ZIndex = 12
	local footerCap = Instance.new("UITextSizeConstraint")
	footerCap.MinTextSize = 12
	footerCap.MaxTextSize = 14
	footerCap.Parent = footerText

	local footerTrack = Instance.new("Frame")
	footerTrack.Name = "Track"
	footerTrack.Position = UDim2.fromOffset(8, 36)
	footerTrack.Size = UDim2.new(1, -16, 0, 5)
	footerTrack.BackgroundColor3 = COL_INK
	footerTrack.BorderSizePixel = 0
	footerTrack.ZIndex = 12
	footerTrack.Parent = footer
	UiKit.corner(footerTrack, 3)

	local footerFill = Instance.new("Frame")
	footerFill.Name = "Fill"
	footerFill.Size = UDim2.fromScale(0.3, 1)
	footerFill.BackgroundColor3 = COL_GOLD_BRIGHT
	footerFill.BorderSizePixel = 0
	footerFill.ZIndex = 13
	footerFill.Parent = footerTrack
	UiKit.corner(footerFill, 3)

	local skipButton = Instance.new("TextButton")
	skipButton.Name = "SkipTouchOverlay"
	skipButton.Size = UDim2.fromScale(1, 1)
	skipButton.BackgroundTransparency = 1
	skipButton.Text = ""
	skipButton.AutoButtonColor = false
	skipButton.ZIndex = 50
	skipButton.Parent = rootFrame

	local transitionFlash = Instance.new("Frame")
	transitionFlash.Name = "TransitionFlash"
	transitionFlash.Size = UDim2.fromScale(1, 1)
	transitionFlash.BackgroundColor3 = COL_BG
	transitionFlash.BackgroundTransparency = 1
	transitionFlash.BorderSizePixel = 0
	transitionFlash.Visible = false
	transitionFlash.ZIndex = 95
	transitionFlash.Parent = gui

	local state: UiState = {
		gui = gui,
		rootFrame = rootFrame,
		backdropImg = backdropImg,
		vignette = vignette,
		curtainCenter = curtainCenter,
		curtainTitle = curtainTitle,
		curtainSub = curtainSub,
		curtainBarFill = curtainBarFill,
		matchupWrap = matchupWrap,
		stage = stage,
		stageScale = stageScale,
		centerCol = centerCol,
		modePill = modePill,
		modeLabel = modeLabel,
		modeSub = modeSub,
		vsBadge = vsBadge,
		vsScale = vsScale,
		footer = footer,
		footerText = footerText,
		footerFill = footerFill,
		card1 = card1,
		card2 = card2,
		skipButton = skipButton,
		transitionFlash = transitionFlash,
		activeTween = nil,
		activeSession = 0,
		skipPressed = false,
		preloaded = false,
	}

	skipButton.Activated:Connect(function()
		state.skipPressed = true
	end)

	local cam = Workspace.CurrentCamera
	if cam ~= nil then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			updateResponsiveLayout(state)
		end)
	end
	updateResponsiveLayout(state)

	task.spawn(function()
		local assetsToPreload: { string } = { UiAssets.TRANSITION_BG }
		for _, url in pairs(UiAssets.CARD_PORTRAITS) do
			assetsToPreload[#assetsToPreload + 1] = url
		end
		pcall(function()
			ContentProvider:PreloadAsync(assetsToPreload)
		end)
		state.preloaded = true
	end)

	cached = state
	return state
end

local function applyFactionStyle(view: CardView, card: MatchCard): ()
	local isBoss = card.role == "boss" or (type(card.bossId) == "string" and card.bossId ~= "")
	local isHorde = card.faction == "horde"
	local isAttacker = card.role == "attacker"

	local primaryAccent: Color3
	local gemTop: Color3
	local gemMid: Color3
	local gemDark: Color3
	local glowTop: Color3
	local glowMid: Color3
	local frameHi: Color3
	local frameMid: Color3
	local frameDark: Color3

	if isBoss then
		primaryAccent = COL_DANGER
		gemTop = Color3.fromRGB(190, 24, 93)
		gemMid = Color3.fromRGB(110, 14, 42)
		gemDark = Color3.fromRGB(36, 6, 16)
		glowTop = Color3.fromRGB(48, 12, 24)
		glowMid = Color3.fromRGB(108, 22, 36)
		frameHi = Color3.fromRGB(254, 202, 138)
		frameMid = Color3.fromRGB(194, 88, 48)
		frameDark = Color3.fromRGB(92, 24, 28)
	elseif isHorde then
		primaryAccent = COL_TEAL_BRIGHT
		gemTop = Color3.fromRGB(20, 148, 136)
		gemMid = Color3.fromRGB(15, 78, 86)
		gemDark = Color3.fromRGB(8, 32, 38)
		glowTop = Color3.fromRGB(10, 28, 42)
		glowMid = Color3.fromRGB(18, 68, 78)
		frameHi = Color3.fromRGB(210, 232, 212)
		frameMid = Color3.fromRGB(108, 166, 152)
		frameDark = Color3.fromRGB(36, 74, 72)
	elseif isAttacker then
		primaryAccent = Color3.fromRGB(56, 189, 248)
		gemTop = Color3.fromRGB(30, 122, 184)
		gemMid = Color3.fromRGB(16, 64, 108)
		gemDark = Color3.fromRGB(8, 26, 48)
		glowTop = Color3.fromRGB(14, 28, 52)
		glowMid = Color3.fromRGB(22, 62, 88)
		frameHi = Color3.fromRGB(244, 216, 144)
		frameMid = Color3.fromRGB(142, 162, 186)
		frameDark = Color3.fromRGB(48, 64, 92)
	else
		primaryAccent = COL_GOLD_BRIGHT
		gemTop = Color3.fromRGB(184, 134, 48)
		gemMid = Color3.fromRGB(84, 56, 20)
		gemDark = Color3.fromRGB(24, 18, 12)
		glowTop = Color3.fromRGB(22, 32, 54)
		glowMid = Color3.fromRGB(82, 52, 20)
		frameHi = COL_GOLD_BRIGHT
		frameMid = COL_GOLD_TRIM
		frameDark = COL_GOLD_DARK
	end

	view.frameGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, frameHi),
		ColorSequenceKeypoint.new(0.45, frameMid),
		ColorSequenceKeypoint.new(0.8, frameDark),
		ColorSequenceKeypoint.new(1, frameMid),
	})
	view.levelMedallionGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, gemTop),
		ColorSequenceKeypoint.new(0.65, gemMid),
		ColorSequenceKeypoint.new(1, gemDark),
	})
	view.levelMedallionStroke.Color = primaryAccent
	view.innerTrimStroke.Color = frameMid
	view.rimStroke.Color = primaryAccent
	view.portraitGlowGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, glowTop),
		ColorSequenceKeypoint.new(0.6, glowMid),
		ColorSequenceKeypoint.new(1, COL_CARD_PLATE),
	})
	view.leftSlotStroke.Color = frameDark
	view.rightSlotStroke.Color = frameDark
	view.centerRune.BackgroundColor3 = primaryAccent
end

local function formatRoleFormation(card: MatchCard, loc: I18n.Locale, roleLabel: string): string
	if type(card.traps) == "table" and #card.traps > 0 and card.faction ~= "horde" then
		local parts: { string } = {}
		for i, trap in ipairs(card.traps) do
			if i > 2 then
				break
			end
			local nameShort = I18n.trapName(loc, trap.type)
			local lvl = math.max(1, tonumber(trap.level) or 1)
			local cnt = tonumber(trap.count) or 1
			if cnt > 1 then
				parts[#parts + 1] =
					string.format("%s %s%d×%d", nameShort, tr("lv_prefix"), lvl, cnt)
			else
				parts[#parts + 1] = string.format("%s %s%d", nameShort, tr("lv_prefix"), lvl)
			end
		end
		return string.format(
			'%s · <font color="#E2E8F0">%s</font>',
			roleLabel,
			table.concat(parts, " · ")
		)
	end

	if type(card.unitClasses) == "table" and #card.unitClasses > 0 then
		local parts: { string } = {}
		for i, kind in ipairs(card.unitClasses) do
			if i > 3 then
				break
			end
			parts[#parts + 1] = I18n.unitName(loc, kind)
		end
		return string.format(
			'%s · <font color="#E2E8F0">%s</font>',
			roleLabel,
			table.concat(parts, " · ")
		)
	end

	local fallback = if card.faction == "horde" then tr("horde_swarm") else tr("no_traps")
	return string.format('%s · <font color="#CBD5E1">%s</font>', roleLabel, fallback)
end

local function populateCard(
	view: CardView,
	data: MatchCard,
	isLocalPlayer: boolean,
	_isLeftCard: boolean
): ()
	local rawLoc = UiKit.getLocale()
	local loc: I18n.Locale = if rawLoc == "en" then "en" elseif rawLoc == "es" then "es" else "pt"
	applyFactionStyle(view, data)

	local isBoss = data.role == "boss" or (type(data.bossId) == "string" and data.bossId ~= "")
	local isHorde = data.faction == "horde" or isBoss
	local wallLvl = math.clamp(math.floor(tonumber(data.wallLevel) or 1), 1, 5)
	local actNum = math.clamp(math.floor(tonumber(data.act) or 1), 1, 5)
	local leagueNum = math.max(1, math.floor(tonumber(data.league) or 1))

	-- Medalhao central de nivel (Ato ou Nivel da Muralha)
	view.levelText.Text = tostring(if type(data.act) == "number" then actNum else wallLvl)

	-- Tag de origem no canto superior esquerdo
	if isLocalPlayer then
		view.originText.Text = tr("tag_you")
	elseif isBoss then
		view.originText.Text = tr("tag_boss")
	elseif isHorde then
		view.originText.Text = tr("tag_horde")
	elseif data.isBot == true then
		view.originText.Text = tr("tag_bot")
	else
		view.originText.Text = tr("tag_rival")
	end

	-- Tier discreto no canto superior direito
	if data.difficulty == "nightmare" then
		view.tierText.Text = "★ " .. tr("act_prefix"):sub(1, 1) .. tostring(actNum)
		view.tierText.TextColor3 = COL_DANGER
	else
		view.tierText.Text = "L" .. tostring(leagueNum)
		view.tierText.TextColor3 = COL_PARCHMENT
	end

	-- Linha de subtitulo (Liga/Ato + Pontos/Stage) no estilo "SUMMONER NAME"
	if type(data.stageId) == "string" and type(data.act) == "number" then
		local diffKey = if data.difficulty == "nightmare" then "diff_nightmare" else "diff_normal"
		view.subtitleLabel.Text =
			string.format("%s %d · %s", tr("act_prefix"), actNum, tr(diffKey))
	elseif type(data.points) == "number" then
		view.subtitleLabel.Text =
			string.format("%s %d · %d PTS", tr("league_prefix"), leagueNum, data.points)
	elseif isBoss then
		view.subtitleLabel.Text =
			string.format("%s %d · %s", tr("act_prefix"), actNum, tr("tag_boss"))
	else
		view.subtitleLabel.Text =
			string.format("%s %d · %s", tr("league_prefix"), leagueNum, view.originText.Text)
	end

	-- Nome em caixa alta (Titulo LoL)
	local displayName = if type(data.name) == "string" and data.name ~= ""
		then data.name
		else "BASTIAO"
	view.nameLabel.Text = string.upper(displayName)

	-- Linha concisa de papel + armadilhas / classes
	local roleKey = if isBoss
		then "role_boss"
		elseif data.faction == "horde" then "role_horde"
		elseif data.role == "attacker" then "role_attacker"
		else "role_defender"
	view.roleMetaLabel.Text = formatRoleFormation(data, loc, tr(roleKey))

	-- Slots integrados de combate na base interna da carta
	if isHorde then
		local waveCnt = tonumber(data.waveCount) or 70
		view.leftSlotText.Text = "⚔ " .. tostring(waveCnt) .. " " .. tr("mobs_unit")
		if isBoss then
			view.rightSlotText.Text = tr("act_prefix") .. " " .. tostring(actNum)
		elseif type(data.stageId) == "string" then
			view.rightSlotText.Text = tostring(data.stageId)
		else
			view.rightSlotText.Text = "L" .. tostring(leagueNum)
		end
	elseif data.role == "attacker" then
		local waveCnt = tonumber(data.waveCount) or 70
		local wallHp = tonumber(data.wallHp) or 500
		view.leftSlotText.Text = "⚔ " .. tostring(waveCnt)
		view.rightSlotText.Text = "♥ " .. tostring(wallHp)
	else
		local tCnt = tonumber(data.trapCount) or 0
		local tLim = tonumber(data.trapLimit) or 5
		local wallHp = tonumber(data.wallHp) or 500
		view.leftSlotText.Text = string.format("⚙ %d/%d", tCnt, tLim)
		view.rightSlotText.Text = "♥ " .. tostring(wallHp)
	end

	-- Splash Art 2D de alta definicao publicada no Open Cloud
	view.portraitImg.Image = UiAssets.portraitForCard(data)
	view.portraitImg.Size = UDim2.fromScale(1.06, 1.06)
	view.portraitImg.Position = UDim2.fromScale(0.5, 0.45)
	view.sheen.Position = UDim2.fromScale(-0.35, 0.48)
end

local function animateCardSplash(view: CardView, delaySec: number): ()
	view.portraitImg.Size = UDim2.fromScale(1.05, 1.05)
	view.sheen.Position = UDim2.fromScale(-0.4, 0.48)

	TweenService
		:Create(
			view.portraitImg,
			TweenInfo.new(3.2, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
			{
				Size = UDim2.fromScale(1.13, 1.13),
				Position = UDim2.fromScale(0.5, 0.42),
			}
		)
		:Play()

	task.delay(delaySec, function()
		if view.sheen.Parent == nil then
			return
		end
		TweenService:Create(
			view.sheen,
			TweenInfo.new(0.95, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ Position = UDim2.fromScale(1.45, 0.52) }
		):Play()
	end)
end

local function configureModeHeader(state: UiState, mode: string, card2: MatchCard?): ()
	if mode == "campaign" then
		local actNum = if card2 ~= nil and type(card2.act) == "number" then card2.act else 1
		state.modeLabel.Text = tr("mode_campaign")
		state.modeLabel.TextColor3 = COL_PURPLE
		state.modeSub.Text = if card2 ~= nil and type(card2.stageId) == "string"
			then string.format("%s %d · %s", tr("act_prefix"), actNum, card2.stageId)
			else string.format("%s %d", tr("act_prefix"), actNum)
	elseif mode == "defend" then
		state.modeLabel.Text = tr("mode_defend")
		state.modeLabel.TextColor3 = COL_AMBER_BRIGHT
		state.modeSub.Text = tr("sub_defend")
	else
		state.modeLabel.Text = tr("mode_raid")
		state.modeLabel.TextColor3 = COL_TEAL_BRIGHT
		state.modeSub.Text = tr("sub_raid")
	end
end

local function prepareScreenVisible(state: UiState): ()
	state.rootFrame.BackgroundTransparency = 0
	state.backdropImg.Visible = true
	state.vignette.Visible = true
	state.transitionFlash.Visible = false
	state.transitionFlash.BackgroundTransparency = 1
	state.gui.Enabled = true
end

function TransitionKit.beginBattleTransition(
	mode: string,
	playerName: string,
	extraOpts: { [string]: any }?
): ()
	local state = buildUi()
	cancelTween(state)
	state.activeSession += 1
	state.skipPressed = false

	local player = Players.LocalPlayer
	local myLeague = tonumber(player:GetAttribute("MuralhaLeague")) or 1
	local myWallTier = tonumber(player:GetAttribute("MuralhaWallTier")) or 1
	local myWallHp = tonumber(player:GetAttribute("MuralhaWallHp")) or 500
	local myTrapCount = tonumber(player:GetAttribute("MuralhaTrapCount")) or 0
	local myTrapLimit = tonumber(player:GetAttribute("MuralhaTrapLimit")) or 5

	local isRaid = mode == "raid"
	local localCard: MatchCard = {
		side = "left",
		role = if isRaid then "attacker" else "defender",
		faction = if isRaid then "raider" else "bastion",
		name = playerName,
		league = myLeague,
		wallLevel = myWallTier,
		wallHp = myWallHp,
		trapCount = myTrapCount,
		trapLimit = myTrapLimit,
	}

	local previewCard2: MatchCard = {
		side = "right",
		role = if isRaid then "defender" else "attacker",
		faction = if isRaid then "bastion" else "horde",
		isBot = true,
		name = tr("searching_title"),
		league = myLeague,
		stageId = if type(extraOpts) == "table" and type(extraOpts.stageId) == "string"
			then extraOpts.stageId
			else nil,
		difficulty = if type(extraOpts) == "table"
				and type(extraOpts.difficulty) == "string"
			then extraOpts.difficulty
			else nil,
		waveCount = if isRaid then nil else 50,
	}

	configureModeHeader(state, mode, previewCard2)
	populateCard(state.card1, localCard, true, true)
	populateCard(state.card2, previewCard2, false, false)
	state.card2.subtitleLabel.Text = tr("searching_sub")

	state.curtainCenter.Visible = false
	state.matchupWrap.Visible = true
	state.footerText.Text = tr("searching_title")
	state.footerFill.Size = UDim2.fromScale(0.28, 1)

	prepareScreenVisible(state)
	updateResponsiveLayout(state)

	TweenService:Create(
		state.footerFill,
		TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(0.62, 1) }
	):Play()
end

function TransitionKit.revealMatchupAndWait(
	matchup: MatchupPayload?,
	mode: string,
	holdSeconds: number?
): ()
	local state = buildUi()
	local session = state.activeSession
	state.skipPressed = false
	state.curtainCenter.Visible = false
	state.matchupWrap.Visible = true
	prepareScreenVisible(state)
	updateResponsiveLayout(state)

	local c1 = if type(matchup) == "table" and type(matchup.card1) == "table"
		then matchup.card1 :: MatchCard
		else { name = Players.LocalPlayer.Name, role = "defender", faction = "bastion" }
	local c2 = if type(matchup) == "table" and type(matchup.card2) == "table"
		then matchup.card2 :: MatchCard
		else { name = "Rival", role = "defender", faction = "horde" }

	configureModeHeader(state, mode, c2)
	populateCard(state.card1, c1, true, true)
	populateCard(state.card2, c2, false, false)

	animateCardSplash(state.card1, 0.14)
	animateCardSplash(state.card2, 0.30)

	state.footerText.Text = tr("tap_to_start")
	TweenService:Create(
		state.footerFill,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(1, 1) }
	):Play()

	state.vsScale.Scale = 1.48
	TweenService:Create(
		state.vsScale,
		TweenInfo.new(0.36, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	):Play()

	pcall(function()
		AudioKit.play("ui_toggle")
	end)

	local totalHold = math.max(0.8, holdSeconds or 2.8)
	local minLocked = 0.5
	local started = time()
	while state.activeSession == session and (time() - started) < totalHold do
		local elapsed = time() - started
		if elapsed >= minLocked and state.skipPressed then
			break
		end
		if elapsed >= minLocked and UserInputService:IsKeyDown(Enum.KeyCode.Space) then
			break
		end
		task.wait(0.03)
	end
end

function TransitionKit.fadeOut(duration: number?): ()
	local state = cached
	if state == nil or not state.gui.Enabled then
		return
	end
	cancelTween(state)
	local totalSec = math.max(0.16, duration or 0.28)
	local halfSec = totalSec * 0.45

	state.transitionFlash.BackgroundTransparency = 1
	state.transitionFlash.Visible = true

	local fadeIn = TweenService:Create(
		state.transitionFlash,
		TweenInfo.new(halfSec, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0 }
	)
	state.activeTween = fadeIn
	fadeIn.Completed:Once(function(playbackState)
		if playbackState ~= Enum.PlaybackState.Completed or state.activeTween ~= fadeIn then
			return
		end
		state.rootFrame.BackgroundTransparency = 1
		state.backdropImg.Visible = false
		state.vignette.Visible = false
		state.matchupWrap.Visible = false
		state.curtainCenter.Visible = false

		local fadeReveal = TweenService:Create(
			state.transitionFlash,
			TweenInfo.new(totalSec * 0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ BackgroundTransparency = 1 }
		)
		state.activeTween = fadeReveal
		fadeReveal.Completed:Once(function(revealState)
			if revealState == Enum.PlaybackState.Completed and state.activeTween == fadeReveal then
				state.activeTween = nil
				state.transitionFlash.Visible = false
				state.gui.Enabled = false
				state.rootFrame.BackgroundTransparency = 0
				state.backdropImg.Visible = true
				state.vignette.Visible = true
			end
		end)
		fadeReveal:Play()
	end)
	fadeIn:Play()
end

function TransitionKit.quickCurtain(workFn: () -> (), holdSeconds: number?): ()
	local state = buildUi()
	cancelTween(state)
	state.activeSession += 1

	state.matchupWrap.Visible = false
	state.curtainCenter.Visible = true
	state.curtainTitle.Text = I18n.t(UiKit.getLocale(), "game_title")
	state.curtainSub.Text = tr("loading_scene")
	state.curtainBarFill.Size = UDim2.fromScale(0.35, 1)
	prepareScreenVisible(state)

	TweenService:Create(
		state.curtainBarFill,
		TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(1, 1) }
	):Play()

	local ok, err: any = pcall(workFn :: any)
	if not ok then
		warn("[TransitionKit] quickCurtain work error: " .. tostring(err))
	end

	local waitSec = holdSeconds or 0.2
	if waitSec > 0 then
		task.wait(waitSec)
	end
	TransitionKit.fadeOut(0.24)
end

return TransitionKit
