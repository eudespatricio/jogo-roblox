--!strict
-- UI de Horda & Cofre de Reliquias (Playtest v1.4).
-- Duas vistas no modal responsivo centralizado (375x812 retrato e desktop):
--   1) Starter Faction Picker (quando not horde.starterChosen)
--   2) Squads & Forge Vault (quando horde.starterChosen == true)

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BuildLayout = require(Shared:WaitForChild("build"):WaitForChild("BuildLayout"))
local DeckCatalog = require(Shared:WaitForChild("raid"):WaitForChild("DeckCatalog")) :: any
local I18n = require(Shared:WaitForChild("i18n"):WaitForChild("I18n"))
local PortalThemes = require(Shared:WaitForChild("visual"):WaitForChild("PortalThemes"))
local VisualTheme = require(Shared:WaitForChild("visual"):WaitForChild("VisualTheme"))

local visual = script.Parent
local AudioKit = require(visual:WaitForChild("AudioKit"))
local UiKit = require(visual:WaitForChild("UiKit"))

export type SquadEntry = {
	cardId: string,
	count: number,
	laneMode: string,
}

export type SaveDeckPayload = {
	squads: { SquadEntry },
	championCardId: string?,
	championLaneMode: string,
}

export type DeckUiOpts = {
	chooseHorde: (action: string, payload: { faction: string }) -> any,
	unlockCard: (action: string, payload: { cardId: string }) -> any,
	saveDeck: (action: string, payload: SaveDeckPayload) -> any,
	onToast: ((msg: string) -> ())?,
}

export type DeckUiHandle = {
	deckButton: TextButton,
	modal: Frame,
	isOpen: () -> boolean,
	openModal: () -> (),
	closeModal: () -> (),
	setButtonsVisible: (visible: boolean) -> (),
	applyLayout: (hudRects: BuildLayout.HudLayout) -> (),
	refreshLocale: () -> (),
	ingestSnapshot: (snapshot: any) -> (),
}

local FACTION_LIST: { string } = { "iron", "slag", "frost", "powder", "rift" }
local LANE_ORDER: { string } = { "center", "flanks", "split", "all" }
local SQUAD_ROLE_KEYS: { string } = {
	"deck_squad_vanguard",
	"deck_squad_pressure",
	"deck_squad_assault",
}
local STAT_KEYS: { { id: string, key: string } } = {
	{ id = "ground", key = "deck_stat_ground" },
	{ id = "air", key = "deck_stat_air" },
	{ id = "armor", key = "deck_stat_armor" },
	{ id = "speed", key = "deck_stat_speed" },
}

local RARITY_COLORS: { [string]: { number } } = {
	common = { 168, 178, 192 },
	rare = { 56, 189, 248 },
	epic = { 168, 85, 247 },
	legendary = { 245, 158, 11 },
	mythic = { 244, 63, 94 },
}

local DEFAULT_CARD_ORDER: { string } = {
	"squad_runner_pack",
	"squad_swarm_brood",
	"squad_brute_guards",
	"squad_iron_vanguard",
	"squad_slag_pyros",
	"squad_sapper_team",
	"squad_rift_wisps",
	"squad_sky_drakes",
	"champ_iron_ram",
	"champ_slag_lord",
	"champ_frost_matriarch",
	"champ_powder_baron",
	"champ_rift_archon",
}

local DeckUi = {}

local function applyRect(obj: GuiObject, r: BuildLayout.Rect): ()
	obj.Position = UDim2.fromOffset(r.x, r.y)
	obj.Size = UDim2.fromOffset(r.w, r.h)
end

local function addTextCap(lbl: TextLabel | TextButton, minSz: number, maxSz: number): ()
	local cap = Instance.new("UITextSizeConstraint")
	cap.MinTextSize = minSz
	cap.MaxTextSize = maxSz
	cap.Parent = lbl
end

local function portalThemeForFaction(factionId: string): PortalThemes.PortalThemeSpec
	local themeKey = "act1"
	if type(DeckCatalog.portalThemeFor) == "function" then
		local ok, res = pcall(DeckCatalog.portalThemeFor, factionId)
		if ok and type(res) == "string" then
			themeKey = res
		end
	else
		local fMap: { [string]: string } = {
			iron = "act1",
			slag = "act2",
			frost = "act3",
			powder = "act4",
			rift = "act5",
		}
		themeKey = fMap[factionId] or "act1"
	end
	return PortalThemes.resolve(themeKey)
end

local function getFactionStat(factionId: string, statId: string): number
	local fTable = if type(DeckCatalog.FACTIONS) == "table"
		then DeckCatalog.FACTIONS[factionId]
		else nil
	if type(fTable) == "table" then
		if type(fTable[statId]) == "number" then
			return math.clamp(math.floor(fTable[statId]), 1, 5)
		end
		if type(fTable.stats) == "table" and type(fTable.stats[statId]) == "number" then
			return math.clamp(math.floor(fTable.stats[statId]), 1, 5)
		end
		if type(fTable.ratings) == "table" and type(fTable.ratings[statId]) == "number" then
			return math.clamp(math.floor(fTable.ratings[statId]), 1, 5)
		end
	end
	return 3
end

local function isChampionCard(cardId: string, cardDef: any): boolean
	if type(cardDef) == "table" then
		if
			cardDef.isChampion == true
			or cardDef.kind == "champion"
			or cardDef.slot == "champion"
		then
			return true
		end
		if cardDef.isChampion == false or cardDef.kind == "squad" or cardDef.slot == "squad" then
			return false
		end
	end
	return string.sub(cardId, 1, 6) == "champ_"
end

local function cardCostGold(cardDef: any): number
	if type(cardDef) ~= "table" then
		return 0
	end
	return tonumber(cardDef.costGold or cardDef.goldCost or cardDef.unlockGold or cardDef.cost) or 0
end

local function cardCostShards(cardDef: any): number
	if type(cardDef) ~= "table" then
		return 0
	end
	return tonumber(
		cardDef.costShards or cardDef.shardCost or cardDef.unlockShards or cardDef.shards
	) or 0
end

local function cardSupply(cardDef: any): number
	if type(cardDef) ~= "table" then
		return 0
	end
	return tonumber(cardDef.supply or cardDef.supplyCost or cardDef.supplyPerPack) or 0
end

local function cardUnits(cardDef: any): number
	if type(cardDef) ~= "table" then
		return 1
	end
	return tonumber(cardDef.unitsPerPack or cardDef.unitCount or cardDef.packSize or cardDef.count)
		or 1
end

local function cloneSquads(src: any): { SquadEntry }
	local out: { SquadEntry } = {}
	if type(src) == "table" then
		for i = 1, 3 do
			local item = src[i]
			if type(item) == "table" then
				out[i] = {
					cardId = tostring(item.cardId or "squad_runner_pack"),
					count = math.max(1, math.floor(tonumber(item.count) or 1)),
					laneMode = tostring(item.laneMode or "center"),
				}
			end
		end
	end
	while #out < 3 do
		out[#out + 1] = {
			cardId = "squad_runner_pack",
			count = 1,
			laneMode = "center",
		}
	end
	return out
end

local function cloneHorde(raw: any): { [string]: any }
	if type(raw) ~= "table" then
		local fallbackStarter = if type(DeckCatalog.starterForFaction) == "function"
			then DeckCatalog.starterForFaction("iron")
			else nil
		return {
			starterChosen = false,
			faction = "iron",
			unlockedCards = if type(fallbackStarter) == "table"
					and type(fallbackStarter.unlockedCards) == "table"
				then table.clone(fallbackStarter.unlockedCards)
				else {
					squad_runner_pack = true,
					squad_brute_guards = true,
					squad_iron_vanguard = true,
				},
			shards = 0,
			bossCores = {
				act1 = false,
				act2 = false,
				act3 = false,
				act4 = false,
				act5 = false,
			},
			squads = cloneSquads(
				if type(fallbackStarter) == "table" then fallbackStarter.squads else nil
			),
			championCardId = nil,
			championLaneMode = "center",
		}
	end

	local unlocked: { [string]: boolean } = {}
	if type(raw.unlockedCards) == "table" then
		for k, v in pairs(raw.unlockedCards) do
			if v == true then
				unlocked[tostring(k)] = true
			end
		end
	end

	local cores: { [string]: boolean } = {
		act1 = false,
		act2 = false,
		act3 = false,
		act4 = false,
		act5 = false,
	}
	if type(raw.bossCores) == "table" then
		for i = 1, 5 do
			local key = "act" .. tostring(i)
			cores[key] = raw.bossCores[key] == true
		end
	end

	return {
		starterChosen = raw.starterChosen == true,
		faction = if type(raw.faction) == "string" and raw.faction ~= ""
			then raw.faction
			else "iron",
		unlockedCards = unlocked,
		shards = math.max(0, math.floor(tonumber(raw.shards) or 0)),
		bossCores = cores,
		squads = cloneSquads(raw.squads),
		championCardId = if type(raw.championCardId) == "string"
				and raw.championCardId ~= ""
			then raw.championCardId
			else nil,
		championLaneMode = if type(raw.championLaneMode) == "string"
				and raw.championLaneMode ~= ""
			then raw.championLaneMode
			else "center",
	}
end

local function computeHordeStats(
	hordeState: { [string]: any },
	leagueId: number
): (number, number, number)
	if type(DeckCatalog.computeStats) == "function" then
		local ok, stats = pcall(DeckCatalog.computeStats, hordeState, leagueId)
		if ok and type(stats) == "table" then
			local used = tonumber(stats.supplyUsed or stats.supply) or 0
			local cap = tonumber(stats.supplyCap or stats.cap)
				or (
					if type(DeckCatalog.supplyCapForLeague) == "function"
						then DeckCatalog.supplyCapForLeague(leagueId)
						else 70
				)
			local units = tonumber(stats.totalUnits or stats.units or stats.unitCount) or 0
			return used, cap, units
		end
	end
	local cap = if type(DeckCatalog.supplyCapForLeague) == "function"
		then DeckCatalog.supplyCapForLeague(leagueId)
		else 70
	return 0, cap, 0
end

local function nextInCycle(list: { string }, current: string): string
	if #list == 0 then
		return current
	end
	for idx, val in ipairs(list) do
		if val == current then
			local nextIdx = (idx % #list) + 1
			return list[nextIdx]
		end
	end
	return list[1]
end

function DeckUi.create(root: Frame, opts: DeckUiOpts): DeckUiHandle
	local currentGold = 0
	local currentLeague = 1
	local selectedStarterFaction = "iron"
	local currentHorde = cloneHorde(nil)
	local draftSquads: { SquadEntry } = cloneSquads(currentHorde.squads)
	local draftChampionId: string? = currentHorde.championCardId
	local draftChampionLane: string = currentHorde.championLaneMode

	-- Botao CTA HORDA no Build HUD
	local deckButton = UiKit.button(root, "Horde", "")
	deckButton.AnchorPoint = Vector2.zero
	deckButton.Position = UDim2.new(1, -130, 1, -198)
	deckButton.Size = UDim2.fromOffset(116, 44)
	deckButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	deckButton.Text = ""
	UiKit.corner(deckButton, 12)
	UiKit.stroke(deckButton, UiKit.color(VisualTheme.PALETTE.teal), 2, 0)

	local deckGradient = deckButton:FindFirstChildOfClass("UIGradient")
	if deckGradient ~= nil then
		deckGradient.Color =
			ColorSequence.new(Color3.fromRGB(15, 118, 110), Color3.fromRGB(30, 64, 175))
		deckGradient.Rotation = 18
	end
	local deckPad = deckButton:FindFirstChildOfClass("UIPadding")
	if deckPad ~= nil then
		deckPad.PaddingLeft = UDim.new(0, 0)
		deckPad.PaddingRight = UDim.new(0, 0)
		deckPad.PaddingTop = UDim.new(0, 0)
		deckPad.PaddingBottom = UDim.new(0, 0)
	end

	local deckIcon = Instance.new("Frame")
	deckIcon.Name = "Icon"
	deckIcon.AnchorPoint = Vector2.new(0, 0.5)
	deckIcon.Position = UDim2.new(0, 6, 0.5, 0)
	deckIcon.Size = UDim2.fromOffset(18, 18)
	deckIcon.BackgroundTransparency = 1
	deckIcon.Parent = deckButton

	local portalOuter = Instance.new("Frame")
	portalOuter.Name = "PortalRing"
	portalOuter.AnchorPoint = Vector2.new(0.5, 0.5)
	portalOuter.Position = UDim2.fromScale(0.5, 0.5)
	portalOuter.Size = UDim2.fromScale(0.84, 0.84)
	portalOuter.Rotation = 45
	portalOuter.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.teal)
	portalOuter.BorderSizePixel = 0
	portalOuter.Parent = deckIcon
	UiKit.corner(portalOuter, 3)

	local portalCore = Instance.new("Frame")
	portalCore.Name = "PortalCore"
	portalCore.AnchorPoint = Vector2.new(0.5, 0.5)
	portalCore.Position = UDim2.fromScale(0.5, 0.5)
	portalCore.Size = UDim2.fromScale(0.42, 0.42)
	portalCore.Rotation = 45
	portalCore.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.white)
	portalCore.BorderSizePixel = 0
	portalCore.Parent = deckIcon
	UiKit.corner(portalCore, 2)

	local deckBtnLabel = UiKit.label(
		deckButton,
		"Label",
		I18n.t(UiKit.getLocale(), "cta_horde"),
		UiKit.color(VisualTheme.PALETTE.white),
		Enum.Font.GothamBlack
	)
	deckBtnLabel.Position = UDim2.new(0, 26, 0, 4)
	deckBtnLabel.Size = UDim2.new(1, -30, 1, -8)
	deckBtnLabel.TextXAlignment = Enum.TextXAlignment.Center
	deckBtnLabel.TextScaled = true
	deckBtnLabel.TextWrapped = false
	addTextCap(deckBtnLabel, 11, 16)
	UiKit.stroke(deckBtnLabel, UiKit.color(VisualTheme.PALETTE.ink), 1.5, 0.25)

	-- Modal centralizado responsivo
	local modal = UiKit.panel(root, "DeckModal")
	modal.AnchorPoint = Vector2.new(0.5, 0.5)
	modal.Position = UDim2.fromScale(0.5, 0.5)
	modal.Size = UDim2.fromOffset(540, 344)
	modal.BackgroundTransparency = 0.18
	modal.Visible = false
	modal.ZIndex = 28
	UiKit.corner(modal, 14)
	UiKit.stroke(modal, UiKit.color(VisualTheme.PALETTE.teal), 2, 0.1)

	local headerTitle = UiKit.label(
		modal,
		"Title",
		I18n.t(UiKit.getLocale(), "deck_title"),
		UiKit.color(VisualTheme.PALETTE.amberBright),
		Enum.Font.GothamBlack
	)
	headerTitle.Position = UDim2.fromOffset(12, 6)
	headerTitle.Size = UDim2.new(1, -64, 0, 24)
	headerTitle.TextScaled = true
	headerTitle.TextWrapped = false
	headerTitle.ZIndex = 29
	addTextCap(headerTitle, 12, 16)

	local modalCloseBtn = UiKit.button(modal, "ModalClose", "X")
	modalCloseBtn.AnchorPoint = Vector2.zero
	modalCloseBtn.Position = UDim2.new(1, -48, 0, 4)
	modalCloseBtn.Size = UDim2.fromOffset(44, 44)
	modalCloseBtn.ZIndex = 30
	UiKit.corner(modalCloseBtn, 10)

	-- ================================================================
	-- VIEW 1: Starter Faction Picker
	-- ================================================================
	local starterView = Instance.new("Frame")
	starterView.Name = "StarterView"
	starterView.Position = UDim2.fromOffset(10, 34)
	starterView.Size = UDim2.new(1, -20, 1, -42)
	starterView.BackgroundTransparency = 1
	starterView.Visible = false
	starterView.ZIndex = 29
	starterView.Parent = modal

	local starterSubLbl = UiKit.label(
		starterView,
		"Subtitle",
		I18n.t(UiKit.getLocale(), "deck_choose_faction"),
		UiKit.color(VisualTheme.PALETTE.parchment),
		Enum.Font.GothamBold
	)
	starterSubLbl.Position = UDim2.fromOffset(0, 0)
	starterSubLbl.Size = UDim2.new(1, -44, 0, 18)
	starterSubLbl.TextScaled = true
	starterSubLbl.ZIndex = 29
	addTextCap(starterSubLbl, 11, 14)

	local factionTabRow = Instance.new("Frame")
	factionTabRow.Name = "FactionTabs"
	factionTabRow.Position = UDim2.fromOffset(0, 20)
	factionTabRow.Size = UDim2.new(1, 0, 0, 36)
	factionTabRow.BackgroundTransparency = 1
	factionTabRow.ZIndex = 29
	factionTabRow.Parent = starterView

	local factionTabLayout = Instance.new("UIListLayout")
	factionTabLayout.FillDirection = Enum.FillDirection.Horizontal
	factionTabLayout.Padding = UDim.new(0, 4)
	factionTabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	factionTabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	factionTabLayout.Parent = factionTabRow

	local factionButtons: { [string]: TextButton? } = {}
	for idx, fId in ipairs(FACTION_LIST) do
		local btn = UiKit.button(factionTabRow, "Faction_" .. fId, "")
		btn.LayoutOrder = idx
		btn.Size = UDim2.new(0.2, -4, 0, 34)
		btn.ZIndex = 30
		UiKit.corner(btn, 8)
		addTextCap(btn, 11, 14)
		factionButtons[fId] = btn
	end

	local starterDetailFrame = Instance.new("Frame")
	starterDetailFrame.Name = "StarterDetails"
	starterDetailFrame.Position = UDim2.fromOffset(0, 60)
	starterDetailFrame.Size = UDim2.new(1, 0, 1, -110)
	starterDetailFrame.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.ironDark)
	starterDetailFrame.BackgroundTransparency = 0.20
	starterDetailFrame.BorderSizePixel = 0
	starterDetailFrame.ZIndex = 29
	starterDetailFrame.Parent = starterView
	UiKit.corner(starterDetailFrame, 10)
	local starterDetailStroke =
		UiKit.stroke(starterDetailFrame, UiKit.color(VisualTheme.PALETTE.amber), 1.5, 0.2)

	-- Left column: 4 tactical rating bars
	local statsCol = Instance.new("Frame")
	statsCol.Name = "StatsCol"
	statsCol.Position = UDim2.fromOffset(8, 8)
	statsCol.Size = UDim2.new(0.48, -10, 1, -16)
	statsCol.BackgroundTransparency = 1
	statsCol.ZIndex = 30
	statsCol.Parent = starterDetailFrame

	type StatRowUi = {
		key: string,
		id: string,
		label: TextLabel,
		bar: UiKit.ProgressBar,
		valLabel: TextLabel,
	}
	local statRows: { StatRowUi } = {}
	for idx, spec in ipairs(STAT_KEYS) do
		local rowY = (idx - 1) * 0.24
		local rowFrame = Instance.new("Frame")
		rowFrame.Name = "Stat_" .. spec.id
		rowFrame.Position = UDim2.fromScale(0, rowY)
		rowFrame.Size = UDim2.fromScale(1, 0.22)
		rowFrame.BackgroundTransparency = 1
		rowFrame.ZIndex = 30
		rowFrame.Parent = statsCol

		local sLbl = UiKit.label(
			rowFrame,
			"Name",
			"",
			UiKit.color(VisualTheme.PALETTE.parchment),
			Enum.Font.GothamBold
		)
		sLbl.Position = UDim2.fromScale(0, 0)
		sLbl.Size = UDim2.fromScale(0.42, 1)
		sLbl.TextScaled = true
		sLbl.ZIndex = 31
		addTextCap(sLbl, 11, 14)

		local pBar = UiKit.progress(rowFrame, "Bar", UiKit.color(VisualTheme.PALETTE.amber))
		pBar.frame.AnchorPoint = Vector2.new(0, 0.5)
		pBar.frame.Position = UDim2.fromScale(0.44, 0.5)
		pBar.frame.Size = UDim2.new(0.40, 0, 0, 10)
		pBar.frame.ZIndex = 31
		pBar.fill.ZIndex = 32

		local vLbl = UiKit.label(
			rowFrame,
			"Val",
			"3/5",
			UiKit.color(VisualTheme.PALETTE.amberBright),
			Enum.Font.GothamBlack
		)
		vLbl.Position = UDim2.fromScale(0.86, 0)
		vLbl.Size = UDim2.fromScale(0.14, 1)
		vLbl.TextXAlignment = Enum.TextXAlignment.Right
		vLbl.TextScaled = true
		vLbl.ZIndex = 31
		addTextCap(vLbl, 11, 14)

		statRows[idx] = {
			key = spec.key,
			id = spec.id,
			label = sLbl,
			bar = pBar,
			valLabel = vLbl,
		}
	end

	-- Right column: Starter pack preview
	local previewCol = Instance.new("Frame")
	previewCol.Name = "PreviewCol"
	previewCol.Position = UDim2.new(0.50, 4, 0, 8)
	previewCol.Size = UDim2.new(0.50, -12, 1, -16)
	previewCol.BackgroundTransparency = 1
	previewCol.ZIndex = 30
	previewCol.Parent = starterDetailFrame

	local previewHeader = UiKit.label(
		previewCol,
		"PreviewTitle",
		"",
		UiKit.color(VisualTheme.PALETTE.amberBright),
		Enum.Font.GothamBlack
	)
	previewHeader.Size = UDim2.new(1, 0, 0, 18)
	previewHeader.TextScaled = true
	previewHeader.ZIndex = 31
	addTextCap(previewHeader, 11, 14)

	local previewSquadLabels: { TextLabel } = {}
	for i = 1, 3 do
		local pRow = UiKit.label(
			previewCol,
			"Pack_" .. tostring(i),
			"",
			UiKit.color(VisualTheme.PALETTE.parchment),
			Enum.Font.GothamBold
		)
		pRow.Position = UDim2.new(0, 0, 0, 20 + (i - 1) * 24)
		pRow.Size = UDim2.new(1, 0, 0, 22)
		pRow.TextScaled = true
		pRow.ZIndex = 31
		addTextCap(pRow, 11, 14)
		previewSquadLabels[i] = pRow
	end

	local confirmFactionBtn = UiKit.button(
		starterView,
		"ConfirmFaction",
		I18n.t(UiKit.getLocale(), "deck_confirm_faction")
	)
	confirmFactionBtn.AnchorPoint = Vector2.new(0.5, 1)
	confirmFactionBtn.Position = UDim2.new(0.5, 0, 1, 0)
	confirmFactionBtn.Size = UDim2.new(1, 0, 0, 44)
	confirmFactionBtn.ZIndex = 30
	UiKit.corner(confirmFactionBtn, 10)
	UiKit.setSelected(confirmFactionBtn, true)
	addTextCap(confirmFactionBtn, 12, 16)

	-- ================================================================
	-- VIEW 2: Squads & Forge Vault
	-- ================================================================
	local vaultView = Instance.new("Frame")
	vaultView.Name = "VaultView"
	vaultView.Position = UDim2.fromOffset(10, 34)
	vaultView.Size = UDim2.new(1, -20, 1, -42)
	vaultView.BackgroundTransparency = 1
	vaultView.Visible = false
	vaultView.ZIndex = 29
	vaultView.Parent = modal

	-- Top Header Status Strip (Faction Badge, Supply, Shards, 5 Core Pips, Gold)
	local statusStrip = Instance.new("Frame")
	statusStrip.Name = "StatusStrip"
	statusStrip.Position = UDim2.fromOffset(0, 0)
	statusStrip.Size = UDim2.new(1, -46, 0, 28)
	statusStrip.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.ironDark)
	statusStrip.BackgroundTransparency = 0.20
	statusStrip.BorderSizePixel = 0
	statusStrip.ZIndex = 29
	statusStrip.Parent = vaultView
	UiKit.corner(statusStrip, 8)

	local factionBadge = Instance.new("Frame")
	factionBadge.Name = "FactionBadge"
	factionBadge.Position = UDim2.fromOffset(4, 3)
	factionBadge.Size = UDim2.new(0.18, -4, 1, -6)
	factionBadge.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.amber)
	factionBadge.BorderSizePixel = 0
	factionBadge.ZIndex = 30
	factionBadge.Parent = statusStrip
	UiKit.corner(factionBadge, 6)

	local factionBadgeLbl = UiKit.label(
		factionBadge,
		"Text",
		"",
		UiKit.color(VisualTheme.PALETTE.ink),
		Enum.Font.GothamBlack
	)
	factionBadgeLbl.Size = UDim2.fromScale(1, 1)
	factionBadgeLbl.TextXAlignment = Enum.TextXAlignment.Center
	factionBadgeLbl.TextScaled = true
	factionBadgeLbl.ZIndex = 31
	addTextCap(factionBadgeLbl, 10, 13)

	local supplyLbl = UiKit.label(
		statusStrip,
		"Supply",
		"",
		UiKit.color(VisualTheme.PALETTE.parchment),
		Enum.Font.GothamBlack
	)
	supplyLbl.Position = UDim2.new(0.19, 2, 0, 2)
	supplyLbl.Size = UDim2.new(0.27, -2, 1, -4)
	supplyLbl.TextXAlignment = Enum.TextXAlignment.Center
	supplyLbl.TextScaled = true
	supplyLbl.ZIndex = 30
	addTextCap(supplyLbl, 10, 13)

	local shardsLbl = UiKit.label(
		statusStrip,
		"Shards",
		"",
		UiKit.color(VisualTheme.PALETTE.teal),
		Enum.Font.GothamBlack
	)
	shardsLbl.Position = UDim2.new(0.46, 2, 0, 2)
	shardsLbl.Size = UDim2.new(0.20, -2, 1, -4)
	shardsLbl.TextXAlignment = Enum.TextXAlignment.Center
	shardsLbl.TextScaled = true
	shardsLbl.ZIndex = 30
	addTextCap(shardsLbl, 10, 13)

	local corePipsHolder = Instance.new("Frame")
	corePipsHolder.Name = "CorePips"
	corePipsHolder.Position = UDim2.new(0.66, 2, 0, 4)
	corePipsHolder.Size = UDim2.new(0.18, -2, 1, -8)
	corePipsHolder.BackgroundTransparency = 1
	corePipsHolder.ZIndex = 30
	corePipsHolder.Parent = statusStrip

	local corePipsLayout = Instance.new("UIListLayout")
	corePipsLayout.FillDirection = Enum.FillDirection.Horizontal
	corePipsLayout.Padding = UDim.new(0, 2)
	corePipsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	corePipsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	corePipsLayout.Parent = corePipsHolder

	local corePips: { Frame } = {}
	for actIdx = 1, 5 do
		local pip = Instance.new("Frame")
		pip.Name = "Core_act" .. tostring(actIdx)
		pip.LayoutOrder = actIdx
		pip.Size = UDim2.fromOffset(13, 16)
		pip.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.stoneDark)
		pip.BorderSizePixel = 0
		pip.ZIndex = 31
		pip.Parent = corePipsHolder
		UiKit.corner(pip, 4)
		local pTxt = UiKit.label(
			pip,
			"Num",
			tostring(actIdx),
			UiKit.color(VisualTheme.PALETTE.parchment),
			Enum.Font.GothamBlack
		)
		pTxt.Size = UDim2.fromScale(1, 1)
		pTxt.TextXAlignment = Enum.TextXAlignment.Center
		pTxt.TextScaled = true
		pTxt.ZIndex = 32
		corePips[actIdx] = pip
	end

	local headerGoldLbl = UiKit.label(
		statusStrip,
		"Gold",
		"",
		UiKit.color(VisualTheme.PALETTE.amberBright),
		Enum.Font.GothamBlack
	)
	headerGoldLbl.Position = UDim2.new(0.84, 2, 0, 2)
	headerGoldLbl.Size = UDim2.new(0.16, -6, 1, -4)
	headerGoldLbl.TextXAlignment = Enum.TextXAlignment.Right
	headerGoldLbl.TextScaled = true
	headerGoldLbl.ZIndex = 30
	addTextCap(headerGoldLbl, 10, 13)

	-- Scrollable Body for Squads + Champion + 13-Card Relic Forge
	local bodyScroll = Instance.new("ScrollingFrame")
	bodyScroll.Name = "VaultScroll"
	bodyScroll.Position = UDim2.fromOffset(0, 32)
	bodyScroll.Size = UDim2.new(1, 0, 1, -80)
	bodyScroll.BackgroundTransparency = 1
	bodyScroll.BorderSizePixel = 0
	bodyScroll.ScrollBarThickness = 5
	bodyScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	bodyScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	bodyScroll.ZIndex = 29
	bodyScroll.Parent = vaultView

	local bodyLayout = Instance.new("UIListLayout")
	bodyLayout.Padding = UDim.new(0, 5)
	bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	bodyLayout.Parent = bodyScroll

	local squadsHeaderLbl = UiKit.label(
		bodyScroll,
		"SquadsHeader",
		"",
		UiKit.color(VisualTheme.PALETTE.amberBright),
		Enum.Font.GothamBlack
	)
	squadsHeaderLbl.LayoutOrder = 1
	squadsHeaderLbl.Size = UDim2.new(1, -8, 0, 20)
	squadsHeaderLbl.TextScaled = true
	squadsHeaderLbl.ZIndex = 30
	addTextCap(squadsHeaderLbl, 11, 14)

	type SquadRowUi = {
		frame: Frame,
		roleLbl: TextLabel,
		cardBtn: TextButton,
		minusBtn: TextButton,
		countLbl: TextLabel,
		plusBtn: TextButton,
		laneBtn: TextButton,
	}
	local squadRowUis: { SquadRowUi } = {}
	for i = 1, 3 do
		local row = Instance.new("Frame")
		row.Name = "SquadRow_" .. tostring(i)
		row.LayoutOrder = 1 + i
		row.Size = UDim2.new(1, -8, 0, 44)
		row.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.ironDark)
		row.BackgroundTransparency = 0.20
		row.BorderSizePixel = 0
		row.ZIndex = 30
		row.Parent = bodyScroll
		UiKit.corner(row, 8)
		UiKit.stroke(row, UiKit.color(VisualTheme.PALETTE.iron), 1, 0.3)

		local roleLbl = UiKit.label(
			row,
			"Role",
			"",
			UiKit.color(VisualTheme.PALETTE.amberBright),
			Enum.Font.GothamBlack
		)
		roleLbl.Position = UDim2.fromOffset(6, 2)
		roleLbl.Size = UDim2.new(0.18, -6, 1, -4)
		roleLbl.TextScaled = true
		roleLbl.ZIndex = 31
		addTextCap(roleLbl, 10, 13)

		local cardBtn = UiKit.button(row, "CardSelect", "")
		cardBtn.Position = UDim2.new(0.18, 2, 0, 3)
		cardBtn.Size = UDim2.new(0.36, -4, 1, -6)
		cardBtn.ZIndex = 31
		UiKit.corner(cardBtn, 7)
		addTextCap(cardBtn, 11, 14)

		local minusBtn = UiKit.button(row, "Minus", "-")
		minusBtn.Position = UDim2.new(0.54, 2, 0, 3)
		minusBtn.Size = UDim2.new(0.08, -2, 1, -6)
		minusBtn.ZIndex = 31
		UiKit.corner(minusBtn, 7)
		addTextCap(minusBtn, 12, 16)

		local countLbl = UiKit.label(
			row,
			"Count",
			"x1",
			UiKit.color(VisualTheme.PALETTE.white),
			Enum.Font.GothamBlack
		)
		countLbl.Position = UDim2.new(0.62, 0, 0, 2)
		countLbl.Size = UDim2.new(0.09, 0, 1, -4)
		countLbl.TextXAlignment = Enum.TextXAlignment.Center
		countLbl.TextScaled = true
		countLbl.ZIndex = 31
		addTextCap(countLbl, 11, 14)

		local plusBtn = UiKit.button(row, "Plus", "+")
		plusBtn.Position = UDim2.new(0.71, 0, 0, 3)
		plusBtn.Size = UDim2.new(0.08, -2, 1, -6)
		plusBtn.ZIndex = 31
		UiKit.corner(plusBtn, 7)
		addTextCap(plusBtn, 12, 16)

		local laneBtn = UiKit.button(row, "LaneMode", "")
		laneBtn.Position = UDim2.new(0.79, 2, 0, 3)
		laneBtn.Size = UDim2.new(0.21, -6, 1, -6)
		laneBtn.ZIndex = 31
		UiKit.corner(laneBtn, 7)
		addTextCap(laneBtn, 10, 13)

		squadRowUis[i] = {
			frame = row,
			roleLbl = roleLbl,
			cardBtn = cardBtn,
			minusBtn = minusBtn,
			countLbl = countLbl,
			plusBtn = plusBtn,
			laneBtn = laneBtn,
		}
	end

	-- Mythic Champion Row
	local champRow = Instance.new("Frame")
	champRow.Name = "ChampionRow"
	champRow.LayoutOrder = 5
	champRow.Size = UDim2.new(1, -8, 0, 50)
	champRow.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.ironDark)
	champRow.BackgroundTransparency = 0.20
	champRow.BorderSizePixel = 0
	champRow.ZIndex = 30
	champRow.Parent = bodyScroll
	UiKit.corner(champRow, 8)
	UiKit.stroke(champRow, UiKit.color(RARITY_COLORS.mythic), 1.5, 0.15)

	local champTitleLbl = UiKit.label(
		champRow,
		"ChampTitle",
		"",
		UiKit.color(RARITY_COLORS.mythic),
		Enum.Font.GothamBlack
	)
	champTitleLbl.Position = UDim2.fromOffset(6, 2)
	champTitleLbl.Size = UDim2.new(0.36, -6, 0, 20)
	champTitleLbl.TextScaled = true
	champTitleLbl.ZIndex = 31
	addTextCap(champTitleLbl, 11, 14)

	local champHintLbl = UiKit.label(
		champRow,
		"ChampHint",
		"",
		UiKit.color(VisualTheme.PALETTE.amberBright),
		Enum.Font.GothamBold
	)
	champHintLbl.Position = UDim2.fromOffset(6, 23)
	champHintLbl.Size = UDim2.new(0.36, -6, 0, 24)
	champHintLbl.TextScaled = true
	champHintLbl.TextWrapped = true
	champHintLbl.ZIndex = 31
	addTextCap(champHintLbl, 10, 13)

	local champSelectBtn = UiKit.button(champRow, "ChampSelect", "--")
	champSelectBtn.Position = UDim2.new(0.37, 2, 0, 4)
	champSelectBtn.Size = UDim2.new(0.41, -4, 1, -8)
	champSelectBtn.ZIndex = 31
	UiKit.corner(champSelectBtn, 7)
	addTextCap(champSelectBtn, 11, 14)

	local champLaneBtn = UiKit.button(champRow, "ChampLane", "")
	champLaneBtn.Position = UDim2.new(0.78, 2, 0, 4)
	champLaneBtn.Size = UDim2.new(0.22, -6, 1, -8)
	champLaneBtn.ZIndex = 31
	UiKit.corner(champLaneBtn, 7)
	addTextCap(champLaneBtn, 10, 13)

	-- 13-Card Relic Forge Section
	local forgeHeaderLbl = UiKit.label(
		bodyScroll,
		"ForgeHeader",
		"",
		UiKit.color(VisualTheme.PALETTE.teal),
		Enum.Font.GothamBlack
	)
	forgeHeaderLbl.LayoutOrder = 6
	forgeHeaderLbl.Size = UDim2.new(1, -8, 0, 20)
	forgeHeaderLbl.TextScaled = true
	forgeHeaderLbl.ZIndex = 30
	addTextCap(forgeHeaderLbl, 11, 14)

	local forgeGridFrame = Instance.new("Frame")
	forgeGridFrame.Name = "ForgeGrid"
	forgeGridFrame.LayoutOrder = 7
	forgeGridFrame.Size = UDim2.new(1, -8, 0, 0)
	forgeGridFrame.AutomaticSize = Enum.AutomaticSize.Y
	forgeGridFrame.BackgroundTransparency = 1
	forgeGridFrame.ZIndex = 30
	forgeGridFrame.Parent = bodyScroll

	local forgeListLayout = Instance.new("UIListLayout")
	forgeListLayout.Padding = UDim.new(0, 4)
	forgeListLayout.SortOrder = Enum.SortOrder.LayoutOrder
	forgeListLayout.Parent = forgeGridFrame

	type ForgeCardUi = {
		cardId: string,
		frame: Frame,
		stroke: UIStroke,
		rarityStripe: Frame,
		nameLbl: TextLabel,
		metaLbl: TextLabel,
		reqLbl: TextLabel,
		actionBtn: TextButton,
	}
	local forgeCardUis: { ForgeCardUi } = {}
	local cardOrder: { string } = if type(DeckCatalog.CARD_ORDER) == "table"
			and #DeckCatalog.CARD_ORDER > 0
		then DeckCatalog.CARD_ORDER
		else DEFAULT_CARD_ORDER

	for idx, cardId in ipairs(cardOrder) do
		local cFrame = Instance.new("Frame")
		cFrame.Name = "Forge_" .. cardId
		cFrame.LayoutOrder = idx
		cFrame.Size = UDim2.new(1, 0, 0, 46)
		cFrame.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.ironDark)
		cFrame.BackgroundTransparency = 0.20
		cFrame.BorderSizePixel = 0
		cFrame.ZIndex = 30
		cFrame.Parent = forgeGridFrame
		UiKit.corner(cFrame, 8)
		local cStroke = UiKit.stroke(cFrame, UiKit.color(VisualTheme.PALETTE.iron), 1.5, 0.2)

		local stripe = Instance.new("Frame")
		stripe.Name = "RarityStripe"
		stripe.Position = UDim2.fromOffset(4, 4)
		stripe.Size = UDim2.new(0, 4, 1, -8)
		stripe.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.stone)
		stripe.BorderSizePixel = 0
		stripe.ZIndex = 31
		stripe.Parent = cFrame
		UiKit.corner(stripe, 2)

		local nameLbl = UiKit.label(
			cFrame,
			"Name",
			cardId,
			UiKit.color(VisualTheme.PALETTE.parchment),
			Enum.Font.GothamBlack
		)
		nameLbl.Position = UDim2.fromOffset(14, 2)
		nameLbl.Size = UDim2.new(0.42, -14, 0, 21)
		nameLbl.TextScaled = true
		nameLbl.ZIndex = 31
		addTextCap(nameLbl, 11, 14)

		local metaLbl = UiKit.label(
			cFrame,
			"Meta",
			"",
			UiKit.color(VisualTheme.PALETTE.stone),
			Enum.Font.GothamBold
		)
		metaLbl.Position = UDim2.fromOffset(14, 23)
		metaLbl.Size = UDim2.new(0.42, -14, 0, 19)
		metaLbl.TextScaled = true
		metaLbl.ZIndex = 31
		addTextCap(metaLbl, 10, 13)

		local reqLbl = UiKit.label(
			cFrame,
			"Req",
			"",
			UiKit.color(VisualTheme.PALETTE.amberBright),
			Enum.Font.GothamBold
		)
		reqLbl.Position = UDim2.new(0.42, 4, 0, 4)
		reqLbl.Size = UDim2.new(0.30, -8, 1, -8)
		reqLbl.TextXAlignment = Enum.TextXAlignment.Right
		reqLbl.TextScaled = true
		reqLbl.TextWrapped = true
		reqLbl.ZIndex = 31
		addTextCap(reqLbl, 10, 13)

		local actionBtn = UiKit.button(cFrame, "Action", "")
		actionBtn.AnchorPoint = Vector2.new(1, 0.5)
		actionBtn.Position = UDim2.new(1, -4, 0.5, 0)
		actionBtn.Size = UDim2.new(0.28, -4, 0, 38)
		actionBtn.ZIndex = 31
		UiKit.corner(actionBtn, 7)
		addTextCap(actionBtn, 11, 14)

		forgeCardUis[idx] = {
			cardId = cardId,
			frame = cFrame,
			stroke = cStroke,
			rarityStripe = stripe,
			nameLbl = nameLbl,
			metaLbl = metaLbl,
			reqLbl = reqLbl,
			actionBtn = actionBtn,
		}
	end

	-- Footer Row: Save & Close buttons
	local footerRow = Instance.new("Frame")
	footerRow.Name = "Footer"
	footerRow.AnchorPoint = Vector2.new(0, 1)
	footerRow.Position = UDim2.new(0, 0, 1, 0)
	footerRow.Size = UDim2.new(1, 0, 0, 44)
	footerRow.BackgroundTransparency = 1
	footerRow.ZIndex = 30
	footerRow.Parent = vaultView

	local saveBtn = UiKit.button(footerRow, "SaveDeck", I18n.t(UiKit.getLocale(), "deck_save_btn"))
	saveBtn.Position = UDim2.fromScale(0, 0)
	saveBtn.Size = UDim2.new(0.68, -4, 1, 0)
	saveBtn.ZIndex = 31
	UiKit.corner(saveBtn, 10)
	UiKit.setSelected(saveBtn, true)
	addTextCap(saveBtn, 12, 16)

	local closeFooterBtn =
		UiKit.button(footerRow, "CloseDeck", I18n.t(UiKit.getLocale(), "cta_close"))
	closeFooterBtn.Position = UDim2.new(0.68, 4, 0, 0)
	closeFooterBtn.Size = UDim2.new(0.32, -4, 1, 0)
	closeFooterBtn.ZIndex = 31
	UiKit.corner(closeFooterBtn, 10)
	addTextCap(closeFooterBtn, 11, 15)

	-- ================================================================
	-- State Helpers & Rendering
	-- ================================================================
	local function buildDraftHorde(): { [string]: any }
		local copy = cloneHorde(currentHorde)
		copy.squads = cloneSquads(draftSquads)
		copy.championCardId = draftChampionId
		copy.championLaneMode = draftChampionLane
		return copy
	end

	local function getUnlockedSquadCardIds(): { string }
		local list: { string } = {}
		local cardsMap = if type(DeckCatalog.CARDS) == "table" then DeckCatalog.CARDS else {}
		for _, cId in ipairs(cardOrder) do
			local def = cardsMap[cId]
			if currentHorde.unlockedCards[cId] == true and not isChampionCard(cId, def) then
				list[#list + 1] = cId
			end
		end
		if #list == 0 then
			list[1] = "squad_runner_pack"
		end
		return list
	end

	local function getUnlockedChampionCardIds(): { string }
		local list: { string } = {}
		local cardsMap = if type(DeckCatalog.CARDS) == "table" then DeckCatalog.CARDS else {}
		for _, cId in ipairs(cardOrder) do
			local def = cardsMap[cId]
			if currentHorde.unlockedCards[cId] == true and isChampionCard(cId, def) then
				list[#list + 1] = cId
			end
		end
		return list
	end

	local function canApplyDraft(candidateSquads: { SquadEntry }, candidateChamp: string?): boolean
		local maxUnits = tonumber(DeckCatalog.MAX_UNITS) or 85
		local candidate = buildDraftHorde()
		candidate.squads = candidateSquads
		candidate.championCardId = candidateChamp
		if type(DeckCatalog.validateDeck) == "function" then
			local ok, valid = pcall(DeckCatalog.validateDeck, candidate, currentLeague, false)
			if ok then
				return valid == true
			end
		end
		local used, cap, units = computeHordeStats(candidate, currentLeague)
		return used <= cap and units <= maxUnits
	end

	local function renderModal(): ()
		local loc = UiKit.getLocale()
		deckBtnLabel.Text = I18n.t(loc, "cta_horde")
		headerTitle.Text = I18n.t(loc, "deck_title")

		local starterChosen = currentHorde.starterChosen == true
		starterView.Visible = not starterChosen
		vaultView.Visible = starterChosen

		if not starterChosen then
			starterSubLbl.Text = I18n.t(loc, "deck_choose_faction")
			confirmFactionBtn.Text = I18n.t(loc, "deck_confirm_faction")

			for _, fId in ipairs(FACTION_LIST) do
				local btn = factionButtons[fId]
				if btn ~= nil then
					btn.Text = I18n.t(loc, "deck_faction_" .. fId)
					local pTheme = portalThemeForFaction(fId)
					local isSel = fId == selectedStarterFaction
					if isSel then
						btn.BackgroundColor3 = UiKit.color(pTheme.veilColor)
						btn.TextColor3 = UiKit.color(VisualTheme.PALETTE.ink)
						UiKit.stroke(btn, UiKit.color(pTheme.accentColor), 2, 0)
					else
						btn.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.iron)
						btn.TextColor3 = UiKit.color(VisualTheme.PALETTE.parchment)
						UiKit.stroke(btn, UiKit.color(pTheme.veilColor), 1, 0.35)
					end
				end
			end

			local selTheme = portalThemeForFaction(selectedStarterFaction)
			starterDetailStroke.Color = UiKit.color(selTheme.veilColor)

			for _, sRow in ipairs(statRows) do
				sRow.label.Text = I18n.t(loc, sRow.key)
				local rating = getFactionStat(selectedStarterFaction, sRow.id)
				sRow.bar.set(rating / 5)
				sRow.bar.fill.BackgroundColor3 = UiKit.color(selTheme.veilColor)
				sRow.valLabel.Text = string.format("%d/5", rating)
				sRow.valLabel.TextColor3 = UiKit.color(selTheme.accentColor)
			end

			previewHeader.Text = I18n.t(loc, "deck_squads_title")
				.. " · "
				.. I18n.t(loc, "deck_faction_" .. selectedStarterFaction)
			previewHeader.TextColor3 = UiKit.color(selTheme.accentColor)

			local starterSpec = if type(DeckCatalog.starterForFaction) == "function"
				then DeckCatalog.starterForFaction(selectedStarterFaction)
				else nil
			local starterSquads =
				cloneSquads(if type(starterSpec) == "table" then starterSpec.squads else nil)
			for i = 1, 3 do
				local sq = starterSquads[i]
				local cardName = I18n.t(loc, "deck_card_" .. sq.cardId)
				local laneName = I18n.t(loc, "deck_lane_" .. sq.laneMode)
				previewSquadLabels[i].Text =
					string.format("%d. %s ×%d (%s)", i, cardName, sq.count, laneName)
			end
			return
		end

		-- View 2: Squads & Forge Vault
		local facId = currentHorde.faction
		local pTheme = portalThemeForFaction(facId)
		factionBadge.BackgroundColor3 = UiKit.color(pTheme.veilColor)
		UiKit.stroke(factionBadge, UiKit.color(pTheme.accentColor), 1.5, 0.1)
		factionBadgeLbl.Text = I18n.t(loc, "deck_faction_" .. facId)

		local draftHorde = buildDraftHorde()
		local supplyUsed, supplyCap, totalUnits = computeHordeStats(draftHorde, currentLeague)
		local maxUnits = tonumber(DeckCatalog.MAX_UNITS) or 85
		supplyLbl.Text = string.format(
			"%s (%d/%d)",
			I18n.t(loc, "deck_supply_label", supplyUsed, supplyCap),
			totalUnits,
			maxUnits
		)
		supplyLbl.TextColor3 = if supplyUsed > supplyCap or totalUnits > maxUnits
			then UiKit.color(VisualTheme.PALETTE.danger)
			else UiKit.color(VisualTheme.PALETTE.parchment)

		shardsLbl.Text = I18n.t(loc, "deck_shards_label", currentHorde.shards)
		headerGoldLbl.Text = I18n.t(loc, "hud_gold", currentGold)

		for actIdx = 1, 5 do
			local pip = corePips[actIdx]
			local hasCore = currentHorde.bossCores["act" .. tostring(actIdx)] == true
			local actTheme = PortalThemes.resolve(actIdx)
			if hasCore then
				pip.BackgroundColor3 = UiKit.color(actTheme.veilColor)
				UiKit.stroke(pip, UiKit.color(actTheme.accentColor), 1.5, 0)
			else
				pip.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.stoneDark)
				UiKit.stroke(pip, UiKit.color(VisualTheme.PALETTE.iron), 1, 0.4)
			end
		end

		squadsHeaderLbl.Text = I18n.t(loc, "deck_squads_title")
		for i = 1, 3 do
			local ui = squadRowUis[i]
			local sq = draftSquads[i]
			ui.roleLbl.Text = I18n.t(loc, SQUAD_ROLE_KEYS[i])
			ui.cardBtn.Text = I18n.t(loc, "deck_card_" .. sq.cardId)
			ui.countLbl.Text = "x" .. tostring(sq.count)
			ui.laneBtn.Text = I18n.t(loc, "deck_lane_" .. sq.laneMode)
		end

		champTitleLbl.Text = I18n.t(loc, "deck_champion_row")
		champHintLbl.Text = I18n.t(loc, "deck_champion_hint")
		if draftChampionId ~= nil and draftChampionId ~= "" then
			champSelectBtn.Text = I18n.t(loc, "deck_card_" .. draftChampionId)
			UiKit.setSelected(champSelectBtn, true)
		else
			champSelectBtn.Text = "--"
			UiKit.setSelected(champSelectBtn, false)
		end
		champLaneBtn.Text = I18n.t(loc, "deck_lane_" .. draftChampionLane)

		forgeHeaderLbl.Text = I18n.t(loc, "deck_forge_vault")
		local cardsMap = if type(DeckCatalog.CARDS) == "table" then DeckCatalog.CARDS else {}
		for _, fUi in ipairs(forgeCardUis) do
			local cId = fUi.cardId
			local def = cardsMap[cId]
			local rarity = if type(def) == "table" and type(def.rarity) == "string"
				then def.rarity
				else "common"
			local rColor = RARITY_COLORS[rarity] or RARITY_COLORS.common
			fUi.rarityStripe.BackgroundColor3 = UiKit.color(rColor)
			fUi.stroke.Color = UiKit.color(rColor)

			fUi.nameLbl.Text = I18n.t(loc, "deck_card_" .. cId)
			fUi.nameLbl.TextColor3 = UiKit.color(rColor)

			local sup = cardSupply(def)
			local uCount = cardUnits(def)
			local airTag = if type(def) == "table" and def.flying == true
				then (" · " .. I18n.t(loc, "deck_stat_air"))
				else ""
			fUi.metaLbl.Text = string.format(
				"%s · %d sup · x%d%s",
				I18n.t(loc, "deck_rarity_" .. rarity),
				sup,
				uCount,
				airTag
			)

			local isUnlocked = currentHorde.unlockedCards[cId] == true
			if isUnlocked then
				fUi.reqLbl.Text = ""
				fUi.actionBtn.Text = I18n.t(loc, "deck_unlocked_badge")
				fUi.actionBtn.BackgroundColor3 = UiKit.color(VisualTheme.PALETTE.teal)
				fUi.actionBtn.TextColor3 = UiKit.color(VisualTheme.PALETTE.ink)
				UiKit.stroke(fUi.actionBtn, UiKit.color(VisualTheme.PALETTE.white), 1, 0.2)
			else
				local cGold = cardCostGold(def)
				local cShards = cardCostShards(def)
				local costLine = I18n.t(loc, "deck_cost_fmt", cGold, cShards)
				local reqCore = if type(def) == "table"
						and type(def.requiredCore) == "string"
					then def.requiredCore
					else nil
				if reqCore ~= nil and reqCore ~= "" then
					local actNum = tonumber(string.match(reqCore, "%d+")) or 1
					costLine = costLine .. "\n" .. I18n.t(loc, "deck_requires_core", actNum)
				end
				fUi.reqLbl.Text = costLine

				local canUnlock = false
				if type(DeckCatalog.canUnlockCard) == "function" then
					local ok, allowed =
						pcall(DeckCatalog.canUnlockCard, currentHorde, currentGold, cId)
					canUnlock = ok and allowed == true
				end
				fUi.reqLbl.TextColor3 = if canUnlock
					then UiKit.color(VisualTheme.PALETTE.amberBright)
					else UiKit.color(VisualTheme.PALETTE.stone)

				fUi.actionBtn.Text = I18n.t(loc, "deck_unlock_btn")
				UiKit.setSelected(fUi.actionBtn, canUnlock)
				fUi.actionBtn.BackgroundTransparency = if canUnlock then 0 else 0.35
			end
		end

		saveBtn.Text = I18n.t(loc, "deck_save_btn")
		closeFooterBtn.Text = I18n.t(loc, "cta_close")
	end

	local function syncDraftFromHorde(): ()
		draftSquads = cloneSquads(currentHorde.squads)
		draftChampionId = currentHorde.championCardId
		draftChampionLane = currentHorde.championLaneMode
	end

	local function ingestSnapshot(snapshot: any): ()
		if type(snapshot) ~= "table" then
			return
		end
		if type(snapshot.gold) == "number" then
			currentGold = snapshot.gold
		end
		if type(snapshot.league) == "number" then
			currentLeague = snapshot.league
		end
		if type(snapshot.horde) == "table" then
			currentHorde = cloneHorde(snapshot.horde)
			selectedStarterFaction = currentHorde.faction
			syncDraftFromHorde()
		end
		if modal.Visible then
			renderModal()
		end
	end

	-- ================================================================
	-- Interactive Connections
	-- ================================================================
	for _, fId in ipairs(FACTION_LIST) do
		local btn = factionButtons[fId]
		if btn ~= nil then
			btn.MouseButton1Click:Connect(function()
				selectedStarterFaction = fId
				AudioKit.play("ui_click")
				renderModal()
			end)
		end
	end

	confirmFactionBtn.MouseButton1Click:Connect(function()
		local res = opts.chooseHorde("choose_horde", { faction = selectedStarterFaction })
		if type(res) == "table" and res.ok == true then
			AudioKit.play("campaign_act_clear")
			if type(res.snapshot) == "table" then
				ingestSnapshot(res.snapshot)
			else
				currentHorde.starterChosen = true
				currentHorde.faction = selectedStarterFaction
				syncDraftFromHorde()
				renderModal()
			end
		else
			AudioKit.play("build_invalid")
		end
	end)

	for i = 1, 3 do
		local ui = squadRowUis[i]
		ui.cardBtn.MouseButton1Click:Connect(function()
			local unlockedList = getUnlockedSquadCardIds()
			if #unlockedList <= 1 then
				AudioKit.play("ui_click")
				return
			end
			local curId = draftSquads[i].cardId
			local idxFound = 1
			for idx, id in ipairs(unlockedList) do
				if id == curId then
					idxFound = idx
					break
				end
			end
			for step = 1, #unlockedList do
				local candidateId = unlockedList[((idxFound + step - 1) % #unlockedList) + 1]
				local nextSquads = cloneSquads(draftSquads)
				nextSquads[i].cardId = candidateId
				if not canApplyDraft(nextSquads, draftChampionId) then
					nextSquads[i].count = 1
				end
				if canApplyDraft(nextSquads, draftChampionId) then
					draftSquads = nextSquads
					AudioKit.play("ui_click")
					renderModal()
					return
				end
			end
			AudioKit.play("build_invalid")
		end)

		ui.minusBtn.MouseButton1Click:Connect(function()
			if draftSquads[i].count <= 1 then
				AudioKit.play("build_invalid")
				return
			end
			draftSquads[i].count -= 1
			AudioKit.play("ui_click")
			renderModal()
		end)

		ui.plusBtn.MouseButton1Click:Connect(function()
			local nextSquads = cloneSquads(draftSquads)
			nextSquads[i].count += 1
			if not canApplyDraft(nextSquads, draftChampionId) then
				AudioKit.play("build_invalid")
				return
			end
			draftSquads = nextSquads
			AudioKit.play("ui_click")
			renderModal()
		end)

		ui.laneBtn.MouseButton1Click:Connect(function()
			draftSquads[i].laneMode = nextInCycle(LANE_ORDER, draftSquads[i].laneMode)
			AudioKit.play("ui_toggle")
			renderModal()
		end)
	end

	champSelectBtn.MouseButton1Click:Connect(function()
		local unlockedChamps = getUnlockedChampionCardIds()
		if #unlockedChamps == 0 then
			AudioKit.play("build_locked")
			return
		end
		local options: { string } = { "" }
		for _, cId in ipairs(unlockedChamps) do
			options[#options + 1] = cId
		end
		local cur = draftChampionId or ""
		local startIdx = 1
		for idx, val in ipairs(options) do
			if val == cur then
				startIdx = idx
				break
			end
		end
		for step = 1, #options do
			local nextVal = options[((startIdx + step - 1) % #options) + 1]
			local candidateChamp: string? = if nextVal == "" then nil else nextVal
			if canApplyDraft(draftSquads, candidateChamp) then
				draftChampionId = candidateChamp
				AudioKit.play("ui_click")
				renderModal()
				return
			end
		end
		AudioKit.play("build_invalid")
	end)

	champLaneBtn.MouseButton1Click:Connect(function()
		draftChampionLane = nextInCycle(LANE_ORDER, draftChampionLane)
		AudioKit.play("ui_toggle")
		renderModal()
	end)

	for _, fUi in ipairs(forgeCardUis) do
		local cId = fUi.cardId
		fUi.actionBtn.MouseButton1Click:Connect(function()
			if currentHorde.unlockedCards[cId] == true then
				-- Quick-equip unlocked card if it fits
				local cardsMap = if type(DeckCatalog.CARDS) == "table"
					then DeckCatalog.CARDS
					else {}
				local def = cardsMap[cId]
				if isChampionCard(cId, def) then
					local targetChamp: string? = if draftChampionId == cId then nil else cId
					if canApplyDraft(draftSquads, targetChamp) then
						draftChampionId = targetChamp
						AudioKit.play("ui_click")
						renderModal()
					else
						AudioKit.play("build_invalid")
					end
				else
					AudioKit.play("ui_click")
				end
				return
			end

			local res = opts.unlockCard("unlock_card", { cardId = cId })
			if type(res) == "table" and res.ok == true then
				AudioKit.play("campaign_act_clear")
				AudioKit.play("coin_spend")
				if type(res.snapshot) == "table" then
					ingestSnapshot(res.snapshot)
				else
					currentHorde.unlockedCards[cId] = true
					renderModal()
				end
			else
				AudioKit.play("build_locked")
			end
		end)
	end

	saveBtn.MouseButton1Click:Connect(function()
		local res = opts.saveDeck("save_deck", {
			squads = cloneSquads(draftSquads),
			championCardId = draftChampionId,
			championLaneMode = draftChampionLane,
		})
		if type(res) == "table" and res.ok == true then
			AudioKit.play("ui_click")
			if type(res.snapshot) == "table" then
				ingestSnapshot(res.snapshot)
			end
			if opts.onToast ~= nil then
				opts.onToast(I18n.t(UiKit.getLocale(), "deck_saved_toast"))
			end
			modal.Visible = false
		else
			AudioKit.play("build_invalid")
		end
	end)

	local function closeModal(): ()
		modal.Visible = false
	end

	local function openModal(): ()
		syncDraftFromHorde()
		modal.Visible = true
		renderModal()
	end

	modalCloseBtn.MouseButton1Click:Connect(function()
		AudioKit.play("ui_click")
		closeModal()
	end)

	closeFooterBtn.MouseButton1Click:Connect(function()
		AudioKit.play("ui_click")
		closeModal()
	end)

	deckButton.MouseButton1Click:Connect(function()
		AudioKit.play("ui_click")
		if modal.Visible then
			closeModal()
		else
			openModal()
		end
	end)

	return {
		deckButton = deckButton,
		modal = modal,
		isOpen = function(): boolean
			return modal.Visible
		end,
		openModal = openModal,
		closeModal = closeModal,
		setButtonsVisible = function(visible: boolean): ()
			deckButton.Visible = visible
		end,
		applyLayout = function(hudRects: BuildLayout.HudLayout): ()
			applyRect(deckButton, hudRects.deckBtn)
			local mw = math.clamp(hudRects.width - 16, 312, 580)
			local mh = math.clamp(hudRects.height - 16, 268, 396)
			modal.Size = UDim2.fromOffset(mw, mh)
		end,
		refreshLocale = function(): ()
			renderModal()
		end,
		ingestSnapshot = ingestSnapshot,
	}
end

return DeckUi
