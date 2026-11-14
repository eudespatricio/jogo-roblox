--!strict
-- Cortina de transicao e tela de confronto Card 1 VS Card 2 no estilo Legends of Runeterra Champion Card.
-- Zero CanvasGroup (texto vetorial 100% nitido em mobile), retratos 3D ao vivo dos personagens
-- do jogo (Guardiao do Bastiao + Armadilha, Horda CMD_* e Bosses BOSS_*), fontes grandes e toque para pular.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local I18n = require(Shared:WaitForChild("i18n"):WaitForChild("I18n"))
local MeshAssets = require(Shared:WaitForChild("visual"):WaitForChild("MeshAssets"))
local UiAssets = require(Shared:WaitForChild("visual"):WaitForChild("UiAssets"))
local VisualTheme = require(Shared:WaitForChild("visual"):WaitForChild("VisualTheme"))

local visual = script.Parent
local AudioKit = require(visual:WaitForChild("AudioKit"))
local HordeKit = require(visual:WaitForChild("HordeKit"))
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

local CARD_W = 244
local CARD_H = 342
local CENTER_COL_W = 92
local STAGE_LANDSCAPE_W = CARD_W * 2 + CENTER_COL_W
local STAGE_LANDSCAPE_H = CARD_H
local PORTRAIT_CENTER_H = 54
local STAGE_PORTRAIT_W = 264
local STAGE_PORTRAIT_H = CARD_H * 2 + PORTRAIT_CENTER_H + 12

local COL_BG = Color3.fromRGB(9, 13, 22)
local COL_CARD_BODY = Color3.fromRGB(17, 22, 34)
local COL_PILL_BG = Color3.fromRGB(26, 33, 50)
local COL_GOLD_BRIGHT = Color3.fromRGB(253, 224, 71)
local COL_GOLD_MID = Color3.fromRGB(217, 119, 6)
local COL_GOLD_DARK = Color3.fromRGB(120, 53, 15)
local COL_AMBER = UiKit.color(VisualTheme.PALETTE.amber)
local COL_AMBER_BRIGHT = UiKit.color(VisualTheme.PALETTE.amberBright)
local COL_TEAL_BRIGHT = Color3.fromRGB(94, 234, 212)
local COL_DANGER = UiKit.color(VisualTheme.PALETTE.danger)
local COL_PURPLE = Color3.fromRGB(167, 139, 250)
local COL_PARCHMENT = UiKit.color(VisualTheme.PALETTE.parchment)
local COL_WHITE = Color3.fromRGB(255, 255, 255)
local COL_INK = Color3.fromRGB(5, 8, 15)

local TEXTS: { [string]: { pt: string, en: string, es: string } } = {
	mode_raid = { pt = "ATAQUE", en = "ASSAULT", es = "ASALTO" },
	mode_defend = { pt = "DEFESA", en = "DEFENSE", es = "DEFENSA" },
	mode_campaign = { pt = "CAMPANHA", en = "CAMPAIGN", es = "CAMPANA" },
	sub_raid = { pt = "Fenda Rival", en = "Rival Bastion", es = "Bastion Rival" },
	sub_defend = { pt = "Cerco", en = "Siege", es = "Asedio" },
	role_attacker = { pt = "⚔ ATACANTE", en = "⚔ ATTACKER", es = "⚔ ATACANTE" },
	role_defender = { pt = "🛡 DEFENSOR", en = "🛡 DEFENDER", es = "🛡 DEFENSOR" },
	role_boss = { pt = "💀 CHEFE", en = "💀 BOSS", es = "💀 JEFE" },
	role_horde = { pt = "⚡ HORDA", en = "⚡ HORDE", es = "⚡ HORDA" },
	tag_you = { pt = "VOCE", en = "YOU", es = "TU" },
	tag_rival = { pt = "RIVAL", en = "RIVAL", es = "RIVAL" },
	tag_bot = { pt = "BOT", en = "BOT", es = "BOT" },
	tag_horde = { pt = "HORDA", en = "HORDE", es = "HORDA" },
	tag_boss = { pt = "CHEFE", en = "BOSS", es = "JEFE" },
	stat_traps = { pt = "Armadilhas", en = "Traps", es = "Trampas" },
	stat_wins = { pt = "Vit.", en = "Wins", es = "Vict." },
	stat_wave = { pt = "Onda", en = "Wave", es = "Oleada" },
	diff_normal = { pt = "Normal", en = "Normal", es = "Normal" },
	diff_nightmare = { pt = "Pesadelo", en = "Nightmare", es = "Pesadilla" },
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

type PortraitCameraRig = {
	cam: Camera,
	basePos: Vector3,
	lookTarget: Vector3,
}

type CardView = {
	root: Frame,
	frameGrad: UIGradient,
	inner: Frame,
	portraitGlow: Frame,
	portraitGlowGrad: UIGradient,
	viewport: ViewportFrame,
	worldModel: WorldModel,
	vpCamera: Camera,
	camRig: PortraitCameraRig?,
	levelGem: Frame,
	levelGemGrad: UIGradient,
	levelText: TextLabel,
	originPill: Frame,
	originText: TextLabel,
	tierPill: Frame,
	tierText: TextLabel,
	nameLabel: TextLabel,
	keywordPill: Frame,
	keywordStroke: UIStroke,
	keywordText: TextLabel,
	line1Label: TextLabel,
	dividerText: TextLabel,
	line2Label: TextLabel,
	leftBadge: Frame,
	leftBadgeText: TextLabel,
	rightBadge: Frame,
	rightBadgeText: TextLabel,
	centerRune: Frame,
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

local function makeBoxPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape ~= nil then
		p.Shape = shape
	end
	p.CFrame = cf
	p.Parent = parent
	return p
end

local function sanitizePortraitModel(model: Instance): ()
	for _, desc in ipairs(model:GetDescendants()) do
		if desc:IsA("Highlight") or desc:IsA("BillboardGui") or desc:IsA("Trail") then
			desc:Destroy()
		elseif desc:IsA("ParticleEmitter") then
			desc.Enabled = false
		elseif desc:IsA("BasePart") then
			desc.Anchored = true
			desc.CanCollide = false
			desc.CanQuery = false
			desc.CanTouch = false
			desc.CastShadow = false
			if desc.Name == "RootPart" then
				desc.Transparency = 1
			end
		end
	end
end

local function bastionArmorPalette(wallLevel: number): (Color3, Color3, Color3)
	if wallLevel >= 5 then
		-- Ouro Negro / Campeao da Muralha
		return Color3.fromRGB(36, 40, 52), COL_GOLD_BRIGHT, Color3.fromRGB(251, 146, 60)
	elseif wallLevel == 4 then
		-- Aco Runico
		return Color3.fromRGB(48, 68, 96), COL_TEAL_BRIGHT, Color3.fromRGB(56, 189, 248)
	elseif wallLevel == 3 then
		-- Bastião Dourado
		return Color3.fromRGB(72, 82, 98), COL_AMBER_BRIGHT, COL_GOLD_BRIGHT
	elseif wallLevel == 2 then
		-- Aço Rebitado
		return Color3.fromRGB(84, 92, 106), Color3.fromRGB(217, 119, 6), COL_AMBER
	end
	return Color3.fromRGB(92, 96, 104), Color3.fromRGB(180, 125, 58), COL_AMBER_BRIGHT
end

local function buildBastionWardenModel(
	parent: Instance,
	wallLevel: number,
	facingSignZ: number,
	topTrap: TrapChip?
): Model
	-- Guardiao da Muralha: frente em -X (igual aos personagens HordeKit/CMD_*), escala heroica ~6.4 studs.
	local armorCol, trimCol, glowCol = bastionArmorPalette(wallLevel)
	local clothCol = Color3.fromRGB(122, 24, 34)
	local hero = Instance.new("Model")
	hero.Name = "BastionWarden"
	hero.Parent = parent

	local root =
		makeBoxPart(hero, "RootPart", Vector3.new(0.2, 0.2, 0.2), CFrame.new(0, 3.0, 0), armorCol)
	root.Transparency = 1
	hero.PrimaryPart = root

	-- Torso blindado + faixa peitoral
	makeBoxPart(
		hero,
		"Chestplate",
		Vector3.new(1.5, 2.35, 2.45),
		CFrame.new(0, 3.05, 0),
		armorCol,
		Enum.Material.Metal
	)
	makeBoxPart(
		hero,
		"ChestPlateTrim",
		Vector3.new(1.62, 0.45, 2.55),
		CFrame.new(-0.04, 3.72, 0),
		trimCol,
		Enum.Material.Metal
	)
	makeBoxPart(
		hero,
		"ChestCrest",
		Vector3.new(0.26, 0.68, 0.68),
		CFrame.new(-0.78, 3.25, 0) * CFrame.Angles(math.rad(45), 0, 0),
		glowCol,
		Enum.Material.Neon
	)
	makeBoxPart(
		hero,
		"Belt",
		Vector3.new(1.58, 0.40, 2.50),
		CFrame.new(0, 1.92, 0),
		trimCol,
		Enum.Material.Metal
	)

	-- Manto real nas costas (+X)
	makeBoxPart(
		hero,
		"Cape",
		Vector3.new(0.22, 3.4, 2.7),
		CFrame.new(0.95, 2.65, 0) * CFrame.Angles(0, 0, math.rad(-10)),
		clothCol,
		Enum.Material.Fabric
	)

	-- Ombreiras duplas estilizadas (silhueta forte de campeao)
	for _, sz in ipairs({ -1, 1 }) do
		makeBoxPart(
			hero,
			"Pauldron_" .. tostring(sz),
			Vector3.new(1.72, 1.15, 1.32),
			CFrame.new(0, 4.18, sz * 1.48) * CFrame.Angles(sz * math.rad(16), 0, 0),
			armorCol,
			Enum.Material.Metal
		)
		makeBoxPart(
			hero,
			"PauldronRim_" .. tostring(sz),
			Vector3.new(1.80, 0.24, 1.38),
			CFrame.new(0, 4.62, sz * 1.46) * CFrame.Angles(sz * math.rad(16), 0, 0),
			trimCol,
			Enum.Material.Metal
		)
		if wallLevel >= 3 then
			makeBoxPart(
				hero,
				"PauldronHorn_" .. tostring(sz),
				Vector3.new(0.32, 0.72, 0.32),
				CFrame.new(-0.08, 4.98, sz * 1.62) * CFrame.Angles(sz * math.rad(28), 0, 0),
				trimCol,
				Enum.Material.Metal
			)
		end
	end

	-- Elmo com visor brilhante voltado para -X
	makeBoxPart(
		hero,
		"HelmBase",
		Vector3.new(1.42, 1.48, 1.36),
		CFrame.new(-0.06, 5.05, 0),
		armorCol,
		Enum.Material.Metal
	)
	makeBoxPart(
		hero,
		"HelmVisorBar",
		Vector3.new(0.28, 0.26, 1.05),
		CFrame.new(-0.76, 5.08, 0),
		glowCol,
		Enum.Material.Neon
	)
	makeBoxPart(
		hero,
		"HelmVisorSplit",
		Vector3.new(0.34, 0.62, 0.16),
		CFrame.new(-0.77, 4.88, 0),
		trimCol,
		Enum.Material.Metal
	)
	makeBoxPart(
		hero,
		"HelmCrest",
		Vector3.new(1.48, 0.42, 0.26),
		CFrame.new(0.05, 5.95, 0),
		trimCol,
		Enum.Material.Metal
	)
	if wallLevel >= 2 then
		makeBoxPart(
			hero,
			"HelmPlume",
			Vector3.new(1.65, 0.52, 0.24),
			CFrame.new(0.45, 6.18, 0) * CFrame.Angles(0, 0, math.rad(-14)),
			clothCol,
			Enum.Material.Fabric
		)
	end

	-- Escudo Torre no braco voltado para fora da cena + Martelo de Guerra no outro braco
	local shieldSideZ = facingSignZ
	local weaponSideZ = -facingSignZ

	makeBoxPart(
		hero,
		"ShieldArm",
		Vector3.new(0.75, 1.65, 0.75),
		CFrame.new(-0.22, 3.15, shieldSideZ * 1.62) * CFrame.Angles(math.rad(14), 0, 0),
		armorCol,
		Enum.Material.Metal
	)
	local shieldCF = CFrame.new(-0.98, 3.05, shieldSideZ * 1.45)
		* CFrame.Angles(0, shieldSideZ * math.rad(18), 0)
	makeBoxPart(
		hero,
		"TowerShieldBody",
		Vector3.new(0.28, 2.95, 1.85),
		shieldCF,
		armorCol,
		Enum.Material.Metal
	)
	makeBoxPart(
		hero,
		"TowerShieldFrame",
		Vector3.new(0.32, 3.10, 2.02),
		shieldCF * CFrame.new(0.03, 0, 0),
		trimCol,
		Enum.Material.Metal
	)
	makeBoxPart(
		hero,
		"TowerShieldCore",
		Vector3.new(0.36, 0.85, 0.85),
		shieldCF * CFrame.Angles(math.rad(45), 0, 0),
		glowCol,
		Enum.Material.Neon
	)

	makeBoxPart(
		hero,
		"HammerArm",
		Vector3.new(0.72, 1.72, 0.72),
		CFrame.new(-0.18, 3.30, weaponSideZ * 1.60) * CFrame.Angles(math.rad(-18), 0, math.rad(18)),
		armorCol,
		Enum.Material.Metal
	)
	makeBoxPart(
		hero,
		"HammerShaft",
		Vector3.new(0.22, 3.15, 0.22),
		CFrame.new(-0.62, 4.05, weaponSideZ * 1.86) * CFrame.Angles(0, 0, math.rad(14)),
		trimCol,
		Enum.Material.Metal
	)
	makeBoxPart(
		hero,
		"HammerHead",
		Vector3.new(0.95, 0.78, 1.25),
		CFrame.new(-0.98, 5.45, weaponSideZ * 1.86) * CFrame.Angles(0, 0, math.rad(14)),
		armorCol,
		Enum.Material.Metal
	)
	makeBoxPart(
		hero,
		"HammerEdge",
		Vector3.new(0.22, 0.82, 1.32),
		CFrame.new(-1.42, 5.56, weaponSideZ * 1.86) * CFrame.Angles(0, 0, math.rad(14)),
		glowCol,
		Enum.Material.Neon
	)

	-- Armadilha assinatura do jogador (Open Cloud 3D model TRAP_* quando carregada) ao lado do ombro
	if topTrap ~= nil then
		local assetsFolder = ReplicatedStorage:FindFirstChild(MeshAssets.FOLDER)
		local trapName = MeshAssets.trapModelName(topTrap.type, math.max(1, topTrap.level))
		local template = if assetsFolder ~= nil then assetsFolder:FindFirstChild(trapName) else nil
		if template ~= nil then
			local trapClone = template:Clone()
			trapClone.Name = "SignatureTrap"
			sanitizePortraitModel(trapClone)
			trapClone.Parent = hero
			local offsetPos = Vector3.new(1.15, 2.25, weaponSideZ * 2.15)
			if trapClone:IsA("Model") then
				local _, rawSz = trapClone:GetBoundingBox()
				if rawSz.Y > 0.05 then
					trapClone:ScaleTo(trapClone:GetScale() * (2.35 / rawSz.Y))
				end
				trapClone:PivotTo(CFrame.new(offsetPos) * CFrame.Angles(0, math.rad(90), 0))
			elseif trapClone:IsA("BasePart") then
				local rawY = trapClone.Size.Y
				if rawY > 0.05 then
					trapClone.Size = trapClone.Size * (2.35 / rawY)
				end
				trapClone.CFrame = CFrame.new(offsetPos) * CFrame.Angles(0, math.rad(90), 0)
			end
		end
	end

	return hero
end

local function pickShowcaseHordeKind(card: MatchCard): string
	if type(card.unitClasses) == "table" and #card.unitClasses > 0 then
		local priority = { "sapper", "pyromancer", "shieldbearer", "brute", "runner", "swarm" }
		for _, cand in ipairs(priority) do
			for _, u in ipairs(card.unitClasses) do
				if u == cand then
					return cand
				end
			end
		end
		return card.unitClasses[1]
	end
	local lvl = tonumber(card.league) or 1
	if lvl >= 5 then
		return "sapper"
	elseif lvl == 4 then
		return "pyromancer"
	elseif lvl == 3 then
		return "shieldbearer"
	elseif lvl == 2 then
		return "brute"
	end
	return "runner"
end

local function frameCameraForPortrait(
	model: Model,
	cam: Camera,
	isLeftCard: boolean,
	upperFocusBias: number,
	zoomFactor: number
): PortraitCameraRig
	local bbCf, bbSize = model:GetBoundingBox()
	local maxSpan = math.max(bbSize.Y * 0.85, bbSize.X, bbSize.Z, 2.4)
	local dist = maxSpan * zoomFactor
	local sideSign = if isLeftCard then -1 else 1
	local lookTarget =
		Vector3.new(bbCf.Position.X, bbCf.Position.Y + bbSize.Y * upperFocusBias, bbCf.Position.Z)
	local camPos = Vector3.new(
		lookTarget.X - dist,
		lookTarget.Y + bbSize.Y * 0.08,
		lookTarget.Z + sideSign * dist * 0.28
	)
	cam.FieldOfView = 30
	cam.CFrame = CFrame.lookAt(camPos, lookTarget)
	return {
		cam = cam,
		basePos = camPos,
		lookTarget = lookTarget,
	}
end

local function populateCardPortrait(view: CardView, card: MatchCard, isLeftCard: boolean): ()
	for _, child in ipairs(view.worldModel:GetChildren()) do
		child:Destroy()
	end
	view.camRig = nil

	if type(card.bossId) == "string" and card.bossId ~= "" then
		local bossUnit = HordeKit.createBoss(card.bossId, view.worldModel, CFrame.identity)
		sanitizePortraitModel(bossUnit.model)
		view.camRig = frameCameraForPortrait(bossUnit.model, view.vpCamera, isLeftCard, 0.16, 1.38)
	elseif card.role == "attacker" or card.faction == "horde" or card.faction == "raider" then
		local kind = pickShowcaseHordeKind(card)
		local unit =
			HordeKit.create(kind, view.worldModel, CFrame.identity, if isLeftCard then 1 else 2)
		sanitizePortraitModel(unit.model)
		view.camRig = frameCameraForPortrait(unit.model, view.vpCamera, isLeftCard, 0.14, 1.36)
	else
		local topTrap: TrapChip? = nil
		if type(card.traps) == "table" and #card.traps > 0 then
			topTrap = card.traps[1]
		end
		local wallLvl = math.clamp(math.floor(tonumber(card.wallLevel) or 1), 1, 5)
		local facingSign = if isLeftCard then -1 else 1
		local warden = buildBastionWardenModel(view.worldModel, wallLvl, facingSign, topTrap)
		view.camRig = frameCameraForPortrait(warden, view.vpCamera, isLeftCard, 0.16, 1.28)
	end
end

local function createLoRCardView(parent: Frame, name: string): CardView
	local root = Instance.new("Frame")
	root.Name = name
	root.Size = UDim2.fromOffset(CARD_W, CARD_H)
	root.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	root.BorderSizePixel = 0
	root.ClipsDescendants = false
	root.Parent = parent
	UiKit.corner(root, 10)
	UiKit.stroke(root, COL_INK, 2, 0.1)

	local frameGrad = Instance.new("UIGradient")
	frameGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, COL_GOLD_BRIGHT),
		ColorSequenceKeypoint.new(0.45, COL_GOLD_MID),
		ColorSequenceKeypoint.new(1, COL_GOLD_DARK),
	})
	frameGrad.Rotation = 135
	frameGrad.Parent = root

	local inner = Instance.new("Frame")
	inner.Name = "CardBody"
	inner.Position = UDim2.fromOffset(5, 5)
	inner.Size = UDim2.new(1, -10, 1, -10)
	inner.BackgroundColor3 = COL_CARD_BODY
	inner.BorderSizePixel = 0
	inner.ClipsDescendants = true
	inner.ZIndex = 2
	inner.Parent = root
	UiKit.corner(inner, 7)
	UiKit.stroke(inner, COL_INK, 1.5, 0)

	-- Terco superior (~56%): Retrato 3D do personagem do jogo
	local portraitBg = Instance.new("Frame")
	portraitBg.Name = "PortraitBackdrop"
	portraitBg.Position = UDim2.fromOffset(0, 0)
	portraitBg.Size = UDim2.new(1, 0, 0, 192)
	portraitBg.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	portraitBg.BorderSizePixel = 0
	portraitBg.ZIndex = 3
	portraitBg.Parent = inner

	local portraitGlowGrad = Instance.new("UIGradient")
	portraitGlowGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(24, 34, 56)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(58, 42, 22)),
		ColorSequenceKeypoint.new(1, COL_CARD_BODY),
	})
	portraitGlowGrad.Rotation = 90
	portraitGlowGrad.Parent = portraitBg

	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "CharacterPortrait"
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(165, 178, 200)
	viewport.LightColor = Color3.fromRGB(255, 244, 224)
	viewport.LightDirection = Vector3.new(-0.7, -0.5, 0.45)
	viewport.ZIndex = 4
	viewport.Parent = portraitBg

	local vpCamera = Instance.new("Camera")
	vpCamera.FieldOfView = 30
	vpCamera.Parent = viewport
	viewport.CurrentCamera = vpCamera

	local worldModel = Instance.new("WorldModel")
	worldModel.Name = "PortraitWorld"
	worldModel.Parent = viewport

	-- Vinheta escura na base do retrato para legibilidade absoluta do nome
	local portraitFade = Instance.new("Frame")
	portraitFade.Name = "PortraitBottomFade"
	portraitFade.AnchorPoint = Vector2.new(0, 1)
	portraitFade.Position = UDim2.new(0, 0, 1, 0)
	portraitFade.Size = UDim2.new(1, 0, 0, 82)
	portraitFade.BackgroundColor3 = COL_CARD_BODY
	portraitFade.BorderSizePixel = 0
	portraitFade.ZIndex = 6
	portraitFade.Parent = portraitBg
	local fadeGrad = Instance.new("UIGradient")
	fadeGrad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.45, 0.45),
		NumberSequenceKeypoint.new(1, 0),
	})
	fadeGrad.Rotation = 90
	fadeGrad.Parent = portraitFade

	-- Nome em caixa alta sobre a base do retrato
	local nameLabel = UiKit.label(inner, "ChampionName", "PLAYER", COL_WHITE, Enum.Font.GothamBlack)
	nameLabel.Position = UDim2.fromOffset(8, 146)
	nameLabel.Size = UDim2.new(1, -16, 0, 28)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Center
	nameLabel.TextScaled = true
	nameLabel.TextWrapped = false
	nameLabel.ZIndex = 10
	UiKit.stroke(nameLabel, COL_INK, 2.2, 0)
	local nameCap = Instance.new("UITextSizeConstraint")
	nameCap.MinTextSize = 14
	nameCap.MaxTextSize = 20
	nameCap.Parent = nameLabel

	-- Keyword pill com borda dourada (padrao LoR: FEARSOME / QUICK ATTACK -> DEFENSOR / ATACANTE)
	local keywordPill = Instance.new("Frame")
	keywordPill.Name = "KeywordPill"
	keywordPill.AnchorPoint = Vector2.new(0.5, 0)
	keywordPill.Position = UDim2.new(0.5, 0, 0, 178)
	keywordPill.Size = UDim2.fromOffset(162, 24)
	keywordPill.BackgroundColor3 = COL_PILL_BG
	keywordPill.BorderSizePixel = 0
	keywordPill.ZIndex = 10
	keywordPill.Parent = inner
	UiKit.corner(keywordPill, 5)
	local keywordStroke = UiKit.stroke(keywordPill, COL_GOLD_MID, 1.5, 0)

	local keywordText =
		UiKit.label(keywordPill, "Text", "🛡 DEFENSOR", COL_GOLD_BRIGHT, Enum.Font.GothamBlack)
	keywordText.Size = UDim2.fromScale(1, 1)
	keywordText.TextXAlignment = Enum.TextXAlignment.Center
	keywordText.TextScaled = false
	keywordText.TextSize = 12
	keywordText.ZIndex = 11

	-- Linha 1: arsenal ou formacao de onda (sem chips minusculos!)
	local line1Label = UiKit.label(inner, "ArsenalLine", "-", COL_PARCHMENT, Enum.Font.GothamBold)
	line1Label.Position = UDim2.fromOffset(10, 206)
	line1Label.Size = UDim2.new(1, -20, 0, 34)
	line1Label.TextXAlignment = Enum.TextXAlignment.Center
	line1Label.TextYAlignment = Enum.TextYAlignment.Center
	line1Label.TextScaled = false
	line1Label.TextSize = 12
	line1Label.TextWrapped = true
	line1Label.RichText = true
	line1Label.ZIndex = 10

	-- Divisor dourado "LIGA X" (como "LEVEL UP" nas cartas LoR)
	local divRow = Instance.new("Frame")
	divRow.Name = "LeagueDivider"
	divRow.Position = UDim2.fromOffset(10, 242)
	divRow.Size = UDim2.new(1, -20, 0, 16)
	divRow.BackgroundTransparency = 1
	divRow.ZIndex = 10
	divRow.Parent = inner

	local ruleL = Instance.new("Frame")
	ruleL.AnchorPoint = Vector2.new(0, 0.5)
	ruleL.Position = UDim2.new(0, 0, 0.5, 0)
	ruleL.Size = UDim2.new(0.22, 0, 0, 1)
	ruleL.BackgroundColor3 = COL_GOLD_MID
	ruleL.BorderSizePixel = 0
	ruleL.ZIndex = 10
	ruleL.Parent = divRow

	local ruleR = Instance.new("Frame")
	ruleR.AnchorPoint = Vector2.new(1, 0.5)
	ruleR.Position = UDim2.new(1, 0, 0.5, 0)
	ruleR.Size = UDim2.new(0.22, 0, 0, 1)
	ruleR.BackgroundColor3 = COL_GOLD_MID
	ruleR.BorderSizePixel = 0
	ruleR.ZIndex = 10
	ruleR.Parent = divRow

	local dividerText =
		UiKit.label(divRow, "Text", "LIGA 1", COL_AMBER_BRIGHT, Enum.Font.GothamBlack)
	dividerText.Size = UDim2.fromScale(1, 1)
	dividerText.TextXAlignment = Enum.TextXAlignment.Center
	dividerText.TextScaled = false
	dividerText.TextSize = 10
	dividerText.ZIndex = 11

	-- Linha 2: resumo de vitorias / armadilhas / onda
	local line2Label = UiKit.label(
		inner,
		"SummaryLine",
		"-",
		Color3.fromRGB(203, 213, 225),
		Enum.Font.GothamMedium
	)
	line2Label.Position = UDim2.fromOffset(10, 260)
	line2Label.Size = UDim2.new(1, -20, 0, 28)
	line2Label.TextXAlignment = Enum.TextXAlignment.Center
	line2Label.TextYAlignment = Enum.TextYAlignment.Top
	line2Label.TextScaled = false
	line2Label.TextSize = 12
	line2Label.TextWrapped = true
	line2Label.ZIndex = 10

	-- Ornamentos sobre a borda da carta (overhang nitido padrao LoR)
	-- 1. Esfera circular superior esquerda (Nivel da Muralha / Ato)
	local levelGem = Instance.new("Frame")
	levelGem.Name = "LevelGem"
	levelGem.Position = UDim2.fromOffset(-7, -7)
	levelGem.Size = UDim2.fromOffset(48, 48)
	levelGem.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	levelGem.BorderSizePixel = 0
	levelGem.ZIndex = 16
	levelGem.Parent = root
	UiKit.corner(levelGem, 24)
	UiKit.stroke(levelGem, COL_GOLD_BRIGHT, 2.5, 0)

	local levelGemGrad = Instance.new("UIGradient")
	levelGemGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(56, 189, 248)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(2, 132, 199)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 74, 110)),
	})
	levelGemGrad.Rotation = 135
	levelGemGrad.Parent = levelGem

	local levelText = UiKit.label(levelGem, "Val", "1", COL_WHITE, Enum.Font.GothamBlack)
	levelText.Size = UDim2.fromScale(1, 1)
	levelText.TextXAlignment = Enum.TextXAlignment.Center
	levelText.TextScaled = false
	levelText.TextSize = 23
	levelText.ZIndex = 17
	UiKit.stroke(levelText, COL_INK, 2.2, 0)

	-- 2. Tag superior central (VOCE / RIVAL / HORDA / CHEFE)
	local originPill = Instance.new("Frame")
	originPill.Name = "OriginTag"
	originPill.AnchorPoint = Vector2.new(0.5, 0)
	originPill.Position = UDim2.new(0.5, 0, 0, -5)
	originPill.Size = UDim2.fromOffset(92, 20)
	originPill.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
	originPill.BorderSizePixel = 0
	originPill.ZIndex = 16
	originPill.Parent = root
	UiKit.corner(originPill, 5)
	UiKit.stroke(originPill, COL_GOLD_MID, 1.5, 0)

	local originText =
		UiKit.label(originPill, "Text", "VOCE", COL_GOLD_BRIGHT, Enum.Font.GothamBlack)
	originText.Size = UDim2.fromScale(1, 1)
	originText.TextXAlignment = Enum.TextXAlignment.Center
	originText.TextScaled = false
	originText.TextSize = 11
	originText.ZIndex = 17

	-- 3. Crest superior direito (L1..L5)
	local tierPill = Instance.new("Frame")
	tierPill.Name = "TierBadge"
	tierPill.AnchorPoint = Vector2.new(1, 0)
	tierPill.Position = UDim2.new(1, 4, 0, 4)
	tierPill.Size = UDim2.fromOffset(42, 22)
	tierPill.BackgroundColor3 = Color3.fromRGB(15, 23, 42)
	tierPill.BorderSizePixel = 0
	tierPill.ZIndex = 16
	tierPill.Parent = root
	UiKit.corner(tierPill, 5)
	UiKit.stroke(tierPill, COL_GOLD_MID, 1.5, 0)

	local tierText = UiKit.label(tierPill, "Text", "L1", COL_PARCHMENT, Enum.Font.GothamBlack)
	tierText.Size = UDim2.fromScale(1, 1)
	tierText.TextXAlignment = Enum.TextXAlignment.Center
	tierText.TextScaled = false
	tierText.TextSize = 12
	tierText.ZIndex = 17

	-- 4. Caixa laranja inferior esquerda (Ataque / Onda / Armadilhas)
	local leftBadge = Instance.new("Frame")
	leftBadge.Name = "LeftStatBox"
	leftBadge.AnchorPoint = Vector2.new(0, 1)
	leftBadge.Position = UDim2.new(0, -4, 1, 4)
	leftBadge.Size = UDim2.fromOffset(84, 34)
	leftBadge.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	leftBadge.BorderSizePixel = 0
	leftBadge.ZIndex = 16
	leftBadge.Parent = root
	UiKit.corner(leftBadge, 7)
	UiKit.stroke(leftBadge, COL_GOLD_BRIGHT, 2, 0)

	local leftGrad = Instance.new("UIGradient")
	leftGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(251, 146, 60)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(154, 52, 18)),
	})
	leftGrad.Rotation = 90
	leftGrad.Parent = leftBadge

	local leftBadgeText = UiKit.label(leftBadge, "Val", "⚔ 0", COL_WHITE, Enum.Font.GothamBlack)
	leftBadgeText.Size = UDim2.fromScale(1, 1)
	leftBadgeText.TextXAlignment = Enum.TextXAlignment.Center
	leftBadgeText.TextScaled = false
	leftBadgeText.TextSize = 16
	leftBadgeText.ZIndex = 17
	UiKit.stroke(leftBadgeText, COL_INK, 2, 0)

	-- 5. Gema de faccao central inferior
	local centerRune = Instance.new("Frame")
	centerRune.Name = "FactionGem"
	centerRune.AnchorPoint = Vector2.new(0.5, 1)
	centerRune.Position = UDim2.new(0.5, 0, 1, -4)
	centerRune.Size = UDim2.fromOffset(20, 20)
	centerRune.Rotation = 45
	centerRune.BackgroundColor3 = COL_AMBER
	centerRune.BorderSizePixel = 0
	centerRune.ZIndex = 16
	centerRune.Parent = root
	UiKit.corner(centerRune, 4)
	UiKit.stroke(centerRune, COL_GOLD_BRIGHT, 1.5, 0)

	-- 6. Caixa vermelha inferior direita (Vida da Muralha / Classe)
	local rightBadge = Instance.new("Frame")
	rightBadge.Name = "RightStatBox"
	rightBadge.AnchorPoint = Vector2.new(1, 1)
	rightBadge.Position = UDim2.new(1, 4, 1, 4)
	rightBadge.Size = UDim2.fromOffset(88, 34)
	rightBadge.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	rightBadge.BorderSizePixel = 0
	rightBadge.ZIndex = 16
	rightBadge.Parent = root
	UiKit.corner(rightBadge, 7)
	UiKit.stroke(rightBadge, COL_GOLD_BRIGHT, 2, 0)

	local rightGrad = Instance.new("UIGradient")
	rightGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(248, 113, 113)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(127, 29, 29)),
	})
	rightGrad.Rotation = 90
	rightGrad.Parent = rightBadge

	local rightBadgeText =
		UiKit.label(rightBadge, "Val", "♥ 500", COL_WHITE, Enum.Font.GothamBlack)
	rightBadgeText.Size = UDim2.fromScale(1, 1)
	rightBadgeText.TextXAlignment = Enum.TextXAlignment.Center
	rightBadgeText.TextScaled = false
	rightBadgeText.TextSize = 16
	rightBadgeText.ZIndex = 17
	UiKit.stroke(rightBadgeText, COL_INK, 2, 0)

	return {
		root = root,
		frameGrad = frameGrad,
		inner = inner,
		portraitGlow = portraitBg,
		portraitGlowGrad = portraitGlowGrad,
		viewport = viewport,
		worldModel = worldModel,
		vpCamera = vpCamera,
		camRig = nil,
		levelGem = levelGem,
		levelGemGrad = levelGemGrad,
		levelText = levelText,
		originPill = originPill,
		originText = originText,
		tierPill = tierPill,
		tierText = tierText,
		nameLabel = nameLabel,
		keywordPill = keywordPill,
		keywordStroke = keywordStroke,
		keywordText = keywordText,
		line1Label = line1Label,
		dividerText = dividerText,
		line2Label = line2Label,
		leftBadge = leftBadge,
		leftBadgeText = leftBadgeText,
		rightBadge = rightBadge,
		rightBadgeText = rightBadgeText,
		centerRune = centerRune,
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
			0.68,
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
			0.72,
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
	backdropImg.ImageTransparency = 0.22
	backdropImg.ZIndex = 1
	backdropImg.Parent = rootFrame

	local vignette = Instance.new("Frame")
	vignette.Name = "ContrastVignette"
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundColor3 = COL_BG
	vignette.BackgroundTransparency = 0.42
	vignette.BorderSizePixel = 0
	vignette.ZIndex = 2
	vignette.Parent = rootFrame

	-- Cortina simples (retorno ao Build / saida do DropIn)
	local curtainCenter = Instance.new("Frame")
	curtainCenter.Name = "QuickCurtain"
	curtainCenter.AnchorPoint = Vector2.new(0.5, 0.5)
	curtainCenter.Position = UDim2.fromScale(0.5, 0.5)
	curtainCenter.Size = UDim2.fromOffset(320, 122)
	curtainCenter.BackgroundColor3 = COL_CARD_BODY
	curtainCenter.BackgroundTransparency = 0.08
	curtainCenter.BorderSizePixel = 0
	curtainCenter.Visible = false
	curtainCenter.ZIndex = 10
	curtainCenter.Parent = rootFrame
	UiKit.corner(curtainCenter, 14)
	UiKit.stroke(curtainCenter, COL_GOLD_MID, 2, 0)

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
	modePill.BackgroundColor3 = COL_CARD_BODY
	modePill.BackgroundTransparency = 0.08
	modePill.BorderSizePixel = 0
	modePill.ZIndex = 11
	modePill.Parent = centerCol
	UiKit.corner(modePill, 8)
	UiKit.stroke(modePill, COL_GOLD_MID, 1.5, 0)

	local modeLabel =
		UiKit.label(modePill, "ModeTitle", "ATAQUE", COL_GOLD_BRIGHT, Enum.Font.GothamBlack)
	modeLabel.Position = UDim2.fromOffset(4, 5)
	modeLabel.Size = UDim2.new(1, -8, 0, 20)
	modeLabel.TextXAlignment = Enum.TextXAlignment.Center
	modeLabel.TextScaled = true
	modeLabel.ZIndex = 12
	local modeCap = Instance.new("UITextSizeConstraint")
	modeCap.MinTextSize = 10
	modeCap.MaxTextSize = 14
	modeCap.Parent = modeLabel

	local modeSub = UiKit.label(modePill, "ModeSub", "", COL_PARCHMENT, Enum.Font.GothamBold)
	modeSub.Position = UDim2.fromOffset(4, 26)
	modeSub.Size = UDim2.new(1, -8, 0, 20)
	modeSub.TextXAlignment = Enum.TextXAlignment.Center
	modeSub.TextScaled = true
	modeSub.TextWrapped = false
	modeSub.ZIndex = 12
	local subCap = Instance.new("UITextSizeConstraint")
	subCap.MinTextSize = 9
	subCap.MaxTextSize = 12
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

	local vsDiamond = Instance.new("Frame")
	vsDiamond.Name = "Diamond"
	vsDiamond.AnchorPoint = Vector2.new(0.5, 0.5)
	vsDiamond.Position = UDim2.fromScale(0.5, 0.5)
	vsDiamond.Size = UDim2.fromOffset(54, 54)
	vsDiamond.Rotation = 45
	vsDiamond.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	vsDiamond.BorderSizePixel = 0
	vsDiamond.ZIndex = 12
	vsDiamond.Parent = vsBadge
	UiKit.corner(vsDiamond, 10)
	UiKit.stroke(vsDiamond, COL_GOLD_BRIGHT, 2.5, 0)

	local vsGrad = Instance.new("UIGradient")
	vsGrad.Color = ColorSequence.new(COL_AMBER, COL_DANGER)
	vsGrad.Rotation = 45
	vsGrad.Parent = vsDiamond

	local vsText = UiKit.label(vsBadge, "VsText", "VS", COL_WHITE, Enum.Font.GothamBlack)
	vsText.AnchorPoint = Vector2.new(0.5, 0.5)
	vsText.Position = UDim2.fromScale(0.5, 0.5)
	vsText.Size = UDim2.fromOffset(58, 36)
	vsText.TextXAlignment = Enum.TextXAlignment.Center
	vsText.TextScaled = false
	vsText.TextSize = 24
	vsText.ZIndex = 14
	UiKit.stroke(vsText, COL_INK, 2.5, 0)

	local footer = Instance.new("Frame")
	footer.Name = "FooterStatus"
	footer.Size = UDim2.fromOffset(88, 50)
	footer.BackgroundColor3 = COL_CARD_BODY
	footer.BackgroundTransparency = 0.1
	footer.BorderSizePixel = 0
	footer.ZIndex = 11
	footer.Parent = centerCol
	UiKit.corner(footer, 8)
	UiKit.stroke(footer, COL_GOLD_DARK, 1.5, 0)

	local footerText =
		UiKit.label(footer, "StatusText", tr("tap_to_start"), COL_PARCHMENT, Enum.Font.GothamBlack)
	footerText.Position = UDim2.fromOffset(4, 4)
	footerText.Size = UDim2.new(1, -8, 0, 28)
	footerText.TextXAlignment = Enum.TextXAlignment.Center
	footerText.TextScaled = true
	footerText.TextWrapped = true
	footerText.ZIndex = 12
	local footerCap = Instance.new("UITextSizeConstraint")
	footerCap.MinTextSize = 9
	footerCap.MaxTextSize = 11
	footerCap.Parent = footerText

	local footerTrack = Instance.new("Frame")
	footerTrack.Name = "Track"
	footerTrack.Position = UDim2.fromOffset(8, 36)
	footerTrack.Size = UDim2.new(1, -16, 0, 6)
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
		pcall(function()
			ContentProvider:PreloadAsync({ UiAssets.TRANSITION_BG })
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

	if isBoss then
		primaryAccent = COL_DANGER
		gemTop = Color3.fromRGB(251, 113, 133)
		gemMid = Color3.fromRGB(225, 29, 72)
		gemDark = Color3.fromRGB(76, 5, 25)
		glowTop = Color3.fromRGB(48, 12, 24)
		glowMid = Color3.fromRGB(108, 22, 36)
	elseif isHorde then
		primaryAccent = COL_TEAL_BRIGHT
		gemTop = Color3.fromRGB(94, 234, 212)
		gemMid = Color3.fromRGB(13, 148, 136)
		gemDark = Color3.fromRGB(19, 78, 74)
		glowTop = Color3.fromRGB(14, 34, 48)
		glowMid = Color3.fromRGB(19, 78, 86)
	elseif isAttacker then
		primaryAccent = COL_TEAL_BRIGHT
		gemTop = Color3.fromRGB(56, 189, 248)
		gemMid = Color3.fromRGB(2, 132, 199)
		gemDark = Color3.fromRGB(12, 74, 110)
		glowTop = Color3.fromRGB(16, 30, 56)
		glowMid = Color3.fromRGB(24, 68, 92)
	else
		primaryAccent = COL_AMBER_BRIGHT
		gemTop = Color3.fromRGB(96, 165, 250)
		gemMid = Color3.fromRGB(37, 99, 235)
		gemDark = Color3.fromRGB(30, 58, 138)
		glowTop = Color3.fromRGB(22, 32, 54)
		glowMid = Color3.fromRGB(82, 52, 20)
	end

	view.levelGemGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, gemTop),
		ColorSequenceKeypoint.new(0.6, gemMid),
		ColorSequenceKeypoint.new(1, gemDark),
	})
	view.portraitGlowGrad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, glowTop),
		ColorSequenceKeypoint.new(0.58, glowMid),
		ColorSequenceKeypoint.new(1, COL_CARD_BODY),
	})
	view.keywordStroke.Color = primaryAccent
	view.centerRune.BackgroundColor3 = primaryAccent
end

local function formatLine1(card: MatchCard, loc: I18n.Locale): string
	if type(card.traps) == "table" and #card.traps > 0 and card.faction ~= "horde" then
		local parts: { string } = {}
		for i, trap in ipairs(card.traps) do
			if i > 3 then
				break
			end
			local nameShort = I18n.trapName(loc, trap.type)
			local lvl = math.max(1, tonumber(trap.level) or 1)
			local cnt = tonumber(trap.count) or 1
			if cnt > 1 then
				parts[#parts + 1] = string.format(
					'%s <font color="#FDE68A">%s%d×%d</font>',
					nameShort,
					tr("lv_prefix"),
					lvl,
					cnt
				)
			else
				parts[#parts + 1] = string.format(
					'%s <font color="#FDE68A">%s%d</font>',
					nameShort,
					tr("lv_prefix"),
					lvl
				)
			end
		end
		return table.concat(parts, " · ")
	end

	if type(card.unitClasses) == "table" and #card.unitClasses > 0 then
		local parts: { string } = {}
		for i, kind in ipairs(card.unitClasses) do
			if i > 3 then
				break
			end
			parts[#parts + 1] = I18n.unitName(loc, kind)
		end
		return table.concat(parts, " · ")
	end

	return if card.faction == "horde" then tr("horde_swarm") else tr("no_traps")
end

local function populateCard(
	view: CardView,
	data: MatchCard,
	isLocalPlayer: boolean,
	isLeftCard: boolean
): ()
	local rawLoc = UiKit.getLocale()
	local loc: I18n.Locale = if rawLoc == "en" then "en" elseif rawLoc == "es" then "es" else "pt"
	applyFactionStyle(view, data)

	local isBoss = data.role == "boss" or (type(data.bossId) == "string" and data.bossId ~= "")
	local isHorde = data.faction == "horde" or isBoss
	local wallLvl = math.clamp(math.floor(tonumber(data.wallLevel) or 1), 1, 5)
	local actNum = math.clamp(math.floor(tonumber(data.act) or 1), 1, 5)
	local leagueNum = math.max(1, math.floor(tonumber(data.league) or 1))

	-- Esfera superior esquerda: Nivel da Muralha ou Ato da Campanha
	view.levelText.Text = tostring(if type(data.act) == "number" then actNum else wallLvl)

	-- Tag superior central
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

	-- Tag superior direita: L1..L5 ou ★ Pesadelo
	if data.difficulty == "nightmare" then
		view.tierText.Text = "★ " .. tr("act_prefix"):sub(1, 1) .. tostring(actNum)
		view.tierText.TextColor3 = COL_DANGER
	else
		view.tierText.Text = "L" .. tostring(leagueNum)
		view.tierText.TextColor3 = COL_PARCHMENT
	end

	-- Nome em caixa alta
	local displayName = if type(data.name) == "string" and data.name ~= ""
		then data.name
		else "BASTIAO"
	view.nameLabel.Text = string.upper(displayName)

	-- Pill dourada de palavra-chave
	local roleKey = if isBoss
		then "role_boss"
		elseif data.faction == "horde" then "role_horde"
		elseif data.role == "attacker" then "role_attacker"
		else "role_defender"
	view.keywordText.Text = tr(roleKey)

	-- Descricao concisa + divisor Liga/Ato
	view.line1Label.Text = formatLine1(data, loc)

	if type(data.stageId) == "string" and type(data.act) == "number" then
		local diffKey = if data.difficulty == "nightmare" then "diff_nightmare" else "diff_normal"
		view.dividerText.Text =
			string.format("%s %d · %s", tr("act_prefix"), actNum, string.upper(tr(diffKey)))
	elseif type(data.points) == "number" then
		view.dividerText.Text =
			string.format("%s %d · %d PTS", tr("league_prefix"), leagueNum, data.points)
	else
		view.dividerText.Text = string.format("%s %d", tr("league_prefix"), leagueNum)
	end

	if isHorde then
		local waveCnt = tonumber(data.waveCount) or 70
		if type(data.stageId) == "string" then
			view.line2Label.Text = string.format(
				"%s: %d %s · %s",
				tr("stat_wave"),
				waveCnt,
				tr("mobs_unit"),
				data.stageId
			)
		else
			view.line2Label.Text =
				string.format("%s: %d %s", tr("stat_wave"), waveCnt, tr("mobs_unit"))
		end
	else
		local tCnt = tonumber(data.trapCount) or 0
		local tLim = tonumber(data.trapLimit) or 5
		if data.role == "attacker" and type(data.waveCount) == "number" then
			view.line2Label.Text = string.format(
				"%s %d/%d · %s %d",
				tr("stat_traps"),
				tCnt,
				tLim,
				tr("stat_wave"),
				data.waveCount
			)
		elseif type(data.wins) == "number" then
			view.line2Label.Text = string.format(
				"%s %d/%d · %d %s",
				tr("stat_traps"),
				tCnt,
				tLim,
				data.wins,
				tr("stat_wins")
			)
		else
			view.line2Label.Text = string.format(
				"%s %d/%d · %s%d",
				tr("stat_traps"),
				tCnt,
				tLim,
				tr("lv_prefix"),
				wallLvl
			)
		end
	end

	-- Caixas de combate nos cantos inferiores (estilo LoR Laranja Esq / Vermelho Dir)
	if isHorde then
		local waveCnt = tonumber(data.waveCount) or 70
		view.leftBadgeText.Text = "⚔ " .. tostring(waveCnt)
		if isBoss then
			view.rightBadgeText.Text = tr("act_prefix") .. " " .. tostring(actNum)
		else
			view.rightBadgeText.Text = "L" .. tostring(leagueNum)
		end
	elseif data.role == "attacker" then
		local waveCnt = tonumber(data.waveCount) or 70
		local wallHp = tonumber(data.wallHp) or 500
		view.leftBadgeText.Text = "⚔ " .. tostring(waveCnt)
		view.rightBadgeText.Text = "♥ " .. tostring(wallHp)
	else
		local tCnt = tonumber(data.trapCount) or 0
		local tLim = tonumber(data.trapLimit) or 5
		local wallHp = tonumber(data.wallHp) or 500
		view.leftBadgeText.Text = string.format("⚙ %d/%d", tCnt, tLim)
		view.rightBadgeText.Text = "♥ " .. tostring(wallHp)
	end

	populateCardPortrait(view, data, isLeftCard)
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
	state.card2.line1Label.Text = tr("searching_sub")

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
		for _, rig in ipairs({ state.card1.camRig, state.card2.camRig }) do
			if rig ~= nil then
				local sway = math.sin(elapsed * 2.1) * 0.14
				local bob = math.cos(elapsed * 2.8) * 0.06
				rig.cam.CFrame =
					CFrame.lookAt(rig.basePos + Vector3.new(0, bob, sway), rig.lookTarget)
			end
		end
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
