--!strict
-- Catalogo deterministico de Horda & Deck de Ataque (Playtest v1.4, Core v8):
-- 5 Faccoes (iron, slag, frost, powder, rift), 5 Raridades, 13 Cartas (8 Esquadroes + 5 Campeoes de Ato),
-- 4 Modos de Lane (center, flanks, split, all), caps de Suprimento por Liga (1..7) e MAX_UNITS = 85.
-- Puro Luau (zero API do Roblox): roda no Luau CLI e no servidor/cliente.

export type FactionId = "iron" | "slag" | "frost" | "powder" | "rift"
export type RarityId = "common" | "rare" | "epic" | "legendary" | "mythic"
export type LaneModeId = "center" | "flanks" | "split" | "all"
export type CardKind = "squad" | "champion"
export type UnitKind =
	"runner"
	| "brute"
	| "swarm"
	| "shieldbearer"
	| "pyromancer"
	| "sapper"
	| "wisp"
	| "drake"
export type CoreActId = "act1" | "act2" | "act3" | "act4" | "act5"

export type DeckSquad = {
	cardId: string,
	count: number,
	laneMode: string,
}

export type FactionRatings = {
	ground: number,
	air: number,
	armor: number,
	speed: number,
}

export type FactionSpec = {
	id: FactionId,
	act: number,
	portalTheme: CoreActId,
	nameKey: string,
	descKey: string,
	ground: number,
	air: number,
	armor: number,
	speed: number,
	ratings: FactionRatings,
	stats: FactionRatings,
	accentColor: { number },
	starterUnlockedCards: { string },
	starterSquads: { DeckSquad },
}

export type RaritySpec = {
	id: RarityId,
	order: number,
	nameKey: string,
	color: { number },
}

export type CardSpec = {
	id: string,
	cardId: string,
	nameKey: string,
	descKey: string,
	faction: FactionId,
	rarity: RarityId,
	kind: CardKind,
	slotType: CardKind,
	isChampion: boolean,
	unit: UnitKind,
	flying: boolean,
	isElite: boolean,
	unitsPerPack: number,
	unitCount: number,
	packSize: number,
	supply: number,
	supplyPerPack: number,
	supplyCost: number,
	everyTicks: number,
	minCount: number,
	maxCount: number,
	costGold: number,
	goldCost: number,
	costShards: number,
	shardCost: number,
	requiredCore: CoreActId?,
}

export type StarterDeck = {
	faction: FactionId,
	portalTheme: CoreActId,
	unlockedCards: { [string]: boolean },
	unlockedCardList: { string },
	squads: { DeckSquad },
	championCardId: string?,
	championLaneMode: string,
}

export type DeckStats = {
	supplyUsed: number,
	supplyCap: number,
	totalUnits: number,
	maxUnits: number,
	groundUnits: number,
	airUnits: number,
	flyingUnits: number,
	squadCount: number,
	hasChampion: boolean,
	championCardId: string?,
}

export type WaveSliceSpec = {
	startTick: number,
	everyTicks: number,
	count: number,
	unit: UnitKind,
	laneMask: number,
	isElite: boolean,
	isChampion: boolean,
}

export type WaveSpec = {
	count: number,
	spawnEveryTicks: number,
	slices: { WaveSliceSpec },
}

local DeckCatalog = {}

DeckCatalog.MAX_UNITS = 85
DeckCatalog.MAX_SQUADS = 3
DeckCatalog.MIN_LEAGUE = 1
DeckCatalog.MAX_LEAGUE = 7

local SUPPLY_CAPS_BY_LEAGUE: { number } = table.freeze({
	70, -- Liga 1
	74, -- Liga 2
	78, -- Liga 3
	82, -- Liga 4
	85, -- Liga 5
	88, -- Liga 6
	90, -- Liga 7
})
DeckCatalog.SUPPLY_CAPS_BY_LEAGUE = SUPPLY_CAPS_BY_LEAGUE

local LANE_MASKS: { [string]: number } = table.freeze({
	center = 4, -- lane 3
	flanks = 17, -- lanes 1, 5
	split = 10, -- lanes 2, 4
	all = 31, -- lanes 1, 2, 3, 4, 5
})
DeckCatalog.LANE_MASKS = LANE_MASKS

local LANE_MODES: { [string]: { number } } = table.freeze({
	center = table.freeze({ 3 }),
	flanks = table.freeze({ 1, 5 }),
	split = table.freeze({ 2, 4 }),
	all = table.freeze({ 1, 2, 3, 4, 5 }),
})
DeckCatalog.LANE_MODES = LANE_MODES

local LANE_MODE_ORDER: { LaneModeId } = table.freeze({
	"center" :: LaneModeId,
	"flanks" :: LaneModeId,
	"split" :: LaneModeId,
	"all" :: LaneModeId,
})
DeckCatalog.LANE_MODE_ORDER = LANE_MODE_ORDER

local RARITIES: { [string]: RaritySpec } = table.freeze({
	common = table.freeze({
		id = "common" :: RarityId,
		order = 1,
		nameKey = "deck_rarity_common",
		color = table.freeze({ 148, 163, 184 }),
	}),
	rare = table.freeze({
		id = "rare" :: RarityId,
		order = 2,
		nameKey = "deck_rarity_rare",
		color = table.freeze({ 56, 189, 248 }),
	}),
	epic = table.freeze({
		id = "epic" :: RarityId,
		order = 3,
		nameKey = "deck_rarity_epic",
		color = table.freeze({ 168, 85, 247 }),
	}),
	legendary = table.freeze({
		id = "legendary" :: RarityId,
		order = 4,
		nameKey = "deck_rarity_legendary",
		color = table.freeze({ 245, 158, 11 }),
	}),
	mythic = table.freeze({
		id = "mythic" :: RarityId,
		order = 5,
		nameKey = "deck_rarity_mythic",
		color = table.freeze({ 20, 184, 166 }),
	}),
})
DeckCatalog.RARITIES = RARITIES

local RARITY_ORDER: { RarityId } = table.freeze({
	"common" :: RarityId,
	"rare" :: RarityId,
	"epic" :: RarityId,
	"legendary" :: RarityId,
	"mythic" :: RarityId,
})
DeckCatalog.RARITY_ORDER = RARITY_ORDER

local function makeFaction(
	id: FactionId,
	act: number,
	portalTheme: CoreActId,
	ground: number,
	air: number,
	armor: number,
	speed: number,
	accentColor: { number },
	starterUnlockedCards: { string },
	starterSquads: { DeckSquad }
): FactionSpec
	local ratings: FactionRatings = table.freeze({
		ground = ground,
		air = air,
		armor = armor,
		speed = speed,
	})
	for _, sq in ipairs(starterSquads) do
		table.freeze(sq)
	end
	return table.freeze({
		id = id,
		act = act,
		portalTheme = portalTheme,
		nameKey = "deck_faction_" .. id,
		descKey = "deck_faction_" .. id .. "_desc",
		ground = ground,
		air = air,
		armor = armor,
		speed = speed,
		ratings = ratings,
		stats = ratings,
		accentColor = table.freeze(accentColor),
		starterUnlockedCards = table.freeze(starterUnlockedCards),
		starterSquads = table.freeze(starterSquads),
	})
end

local FACTIONS: { [string]: FactionSpec } = table.freeze({
	iron = makeFaction(
		"iron",
		1,
		"act1",
		5,
		2,
		5,
		2,
		{ 245, 158, 11 },
		{ "squad_runner_pack", "squad_brute_guards", "squad_iron_vanguard" },
		{
			{ cardId = "squad_iron_vanguard", count = 2, laneMode = "center" },
			{ cardId = "squad_runner_pack", count = 2, laneMode = "flanks" },
			{ cardId = "squad_brute_guards", count = 2, laneMode = "split" },
		}
	),
	slag = makeFaction(
		"slag",
		2,
		"act2",
		4,
		3,
		3,
		3,
		{ 228, 87, 46 },
		{ "squad_runner_pack", "squad_brute_guards", "squad_slag_pyros" },
		{
			{ cardId = "squad_brute_guards", count = 2, laneMode = "center" },
			{ cardId = "squad_slag_pyros", count = 2, laneMode = "split" },
			{ cardId = "squad_runner_pack", count = 2, laneMode = "flanks" },
		}
	),
	frost = makeFaction(
		"frost",
		3,
		"act3",
		3,
		4,
		4,
		2,
		{ 89, 166, 230 },
		{ "squad_runner_pack", "squad_iron_vanguard", "squad_rift_wisps" },
		{
			{ cardId = "squad_iron_vanguard", count = 2, laneMode = "center" },
			{ cardId = "squad_rift_wisps", count = 2, laneMode = "flanks" },
			{ cardId = "squad_runner_pack", count = 2, laneMode = "split" },
		}
	),
	powder = makeFaction(
		"powder",
		4,
		"act4",
		4,
		2,
		2,
		5,
		{ 234, 179, 36 },
		{ "squad_runner_pack", "squad_swarm_brood", "squad_sapper_team" },
		{
			{ cardId = "squad_swarm_brood", count = 3, laneMode = "all" },
			{ cardId = "squad_sapper_team", count = 2, laneMode = "center" },
			{ cardId = "squad_runner_pack", count = 1, laneMode = "flanks" },
		}
	),
	rift = makeFaction(
		"rift",
		5,
		"act5",
		3,
		5,
		3,
		4,
		{ 16, 198, 172 },
		{ "squad_swarm_brood", "squad_slag_pyros", "squad_rift_wisps" },
		{
			{ cardId = "squad_rift_wisps", count = 2, laneMode = "flanks" },
			{ cardId = "squad_slag_pyros", count = 2, laneMode = "split" },
			{ cardId = "squad_swarm_brood", count = 2, laneMode = "center" },
		}
	),
})
DeckCatalog.FACTIONS = FACTIONS

local FACTION_ORDER: { FactionId } = table.freeze({
	"iron" :: FactionId,
	"slag" :: FactionId,
	"frost" :: FactionId,
	"powder" :: FactionId,
	"rift" :: FactionId,
})
DeckCatalog.FACTION_ORDER = FACTION_ORDER

local function makeCard(spec: {
	id: string,
	faction: FactionId,
	rarity: RarityId,
	kind: CardKind,
	unit: UnitKind,
	flying: boolean,
	isElite: boolean,
	unitsPerPack: number,
	supply: number,
	everyTicks: number,
	maxCount: number,
	costGold: number,
	costShards: number,
	requiredCore: CoreActId?,
}): CardSpec
	local isChampion = spec.kind == "champion"
	return table.freeze({
		id = spec.id,
		cardId = spec.id,
		nameKey = "deck_card_" .. spec.id,
		descKey = "deck_card_" .. spec.id .. "_desc",
		faction = spec.faction,
		rarity = spec.rarity,
		kind = spec.kind,
		slotType = spec.kind,
		isChampion = isChampion,
		unit = spec.unit,
		flying = spec.flying,
		isElite = spec.isElite,
		unitsPerPack = spec.unitsPerPack,
		unitCount = spec.unitsPerPack,
		packSize = spec.unitsPerPack,
		supply = spec.supply,
		supplyPerPack = spec.supply,
		supplyCost = spec.supply,
		everyTicks = spec.everyTicks,
		minCount = 1,
		maxCount = spec.maxCount,
		costGold = spec.costGold,
		goldCost = spec.costGold,
		costShards = spec.costShards,
		shardCost = spec.costShards,
		requiredCore = spec.requiredCore,
	})
end

local CARDS: { [string]: CardSpec } = table.freeze({
	squad_runner_pack = makeCard({
		id = "squad_runner_pack",
		faction = "iron",
		rarity = "common",
		kind = "squad",
		unit = "runner",
		flying = false,
		isElite = false,
		unitsPerPack = 6,
		supply = 8,
		everyTicks = 12,
		maxCount = 8,
		costGold = 60,
		costShards = 0,
		requiredCore = nil,
	}),
	squad_swarm_brood = makeCard({
		id = "squad_swarm_brood",
		faction = "powder",
		rarity = "common",
		kind = "squad",
		unit = "swarm",
		flying = false,
		isElite = false,
		unitsPerPack = 8,
		supply = 8,
		everyTicks = 9,
		maxCount = 8,
		costGold = 60,
		costShards = 0,
		requiredCore = nil,
	}),
	squad_brute_guards = makeCard({
		id = "squad_brute_guards",
		faction = "iron",
		rarity = "rare",
		kind = "squad",
		unit = "brute",
		flying = false,
		isElite = false,
		unitsPerPack = 3,
		supply = 10,
		everyTicks = 18,
		maxCount = 8,
		costGold = 110,
		costShards = 1,
		requiredCore = nil,
	}),
	squad_iron_vanguard = makeCard({
		id = "squad_iron_vanguard",
		faction = "iron",
		rarity = "rare",
		kind = "squad",
		unit = "shieldbearer",
		flying = false,
		isElite = false,
		unitsPerPack = 4,
		supply = 10,
		everyTicks = 16,
		maxCount = 8,
		costGold = 120,
		costShards = 1,
		requiredCore = nil,
	}),
	squad_slag_pyros = makeCard({
		id = "squad_slag_pyros",
		faction = "slag",
		rarity = "epic",
		kind = "squad",
		unit = "pyromancer",
		flying = false,
		isElite = false,
		unitsPerPack = 5,
		supply = 10,
		everyTicks = 14,
		maxCount = 8,
		costGold = 160,
		costShards = 2,
		requiredCore = nil,
	}),
	squad_sapper_team = makeCard({
		id = "squad_sapper_team",
		faction = "powder",
		rarity = "epic",
		kind = "squad",
		unit = "sapper",
		flying = false,
		isElite = false,
		unitsPerPack = 4,
		supply = 10,
		everyTicks = 14,
		maxCount = 8,
		costGold = 180,
		costShards = 2,
		requiredCore = nil,
	}),
	squad_rift_wisps = makeCard({
		id = "squad_rift_wisps",
		faction = "rift",
		rarity = "epic",
		kind = "squad",
		unit = "wisp",
		flying = true,
		isElite = false,
		unitsPerPack = 4,
		supply = 10,
		everyTicks = 14,
		maxCount = 8,
		costGold = 200,
		costShards = 2,
		requiredCore = nil,
	}),
	squad_sky_drakes = makeCard({
		id = "squad_sky_drakes",
		faction = "frost",
		rarity = "legendary",
		kind = "squad",
		unit = "drake",
		flying = true,
		isElite = false,
		unitsPerPack = 2,
		supply = 14,
		everyTicks = 22,
		maxCount = 6,
		costGold = 320,
		costShards = 4,
		requiredCore = "act3",
	}),
	champ_iron_ram = makeCard({
		id = "champ_iron_ram",
		faction = "iron",
		rarity = "mythic",
		kind = "champion",
		unit = "shieldbearer",
		flying = false,
		isElite = false,
		unitsPerPack = 1,
		supply = 10,
		everyTicks = 20,
		maxCount = 1,
		costGold = 400,
		costShards = 5,
		requiredCore = "act1",
	}),
	champ_slag_lord = makeCard({
		id = "champ_slag_lord",
		faction = "slag",
		rarity = "mythic",
		kind = "champion",
		unit = "brute",
		flying = false,
		isElite = false,
		unitsPerPack = 1,
		supply = 10,
		everyTicks = 20,
		maxCount = 1,
		costGold = 450,
		costShards = 5,
		requiredCore = "act2",
	}),
	champ_frost_matriarch = makeCard({
		id = "champ_frost_matriarch",
		faction = "frost",
		rarity = "mythic",
		kind = "champion",
		unit = "drake",
		flying = true,
		isElite = false,
		unitsPerPack = 1,
		supply = 12,
		everyTicks = 20,
		maxCount = 1,
		costGold = 500,
		costShards = 6,
		requiredCore = "act3",
	}),
	champ_powder_baron = makeCard({
		id = "champ_powder_baron",
		faction = "powder",
		rarity = "mythic",
		kind = "champion",
		unit = "sapper",
		flying = false,
		isElite = false,
		unitsPerPack = 1,
		supply = 10,
		everyTicks = 20,
		maxCount = 1,
		costGold = 550,
		costShards = 6,
		requiredCore = "act4",
	}),
	champ_rift_archon = makeCard({
		id = "champ_rift_archon",
		faction = "rift",
		rarity = "mythic",
		kind = "champion",
		unit = "wisp",
		flying = true,
		isElite = false,
		unitsPerPack = 1,
		supply = 12,
		everyTicks = 20,
		maxCount = 1,
		costGold = 600,
		costShards = 8,
		requiredCore = "act5",
	}),
})
DeckCatalog.CARDS = CARDS

local CARD_ORDER: { string } = table.freeze({
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
})
DeckCatalog.CARD_ORDER = CARD_ORDER

local function isFiniteInt(value: any): boolean
	if type(value) ~= "number" then
		return false
	end
	local n = value :: number
	return n == n and n ~= math.huge and n ~= -math.huge and n % 1 == 0
end

local function resolveLeagueIndex(leagueId: any): number
	local raw: any = leagueId
	if type(raw) == "table" then
		if type(raw.id) == "number" then
			raw = raw.id
		elseif type(raw.league) == "number" then
			raw = raw.league
		elseif type(raw.points) == "number" then
			local pts = math.max(0, math.floor(raw.points))
			raw = math.clamp(1 + math.floor(pts / 200), 1, 7)
		end
	end
	local num = tonumber(raw)
	if num == nil or num ~= num then
		return 1
	end
	return math.clamp(math.floor(num), DeckCatalog.MIN_LEAGUE, DeckCatalog.MAX_LEAGUE)
end

function DeckCatalog.supplyCapForLeague(leagueId: any): number
	local idx = resolveLeagueIndex(leagueId)
	return SUPPLY_CAPS_BY_LEAGUE[idx] or 70
end

function DeckCatalog.portalThemeFor(factionId: any): CoreActId
	if type(factionId) == "string" then
		local f = FACTIONS[factionId]
		if f ~= nil then
			return f.portalTheme
		end
		if
			factionId == "act1"
			or factionId == "act2"
			or factionId == "act3"
			or factionId == "act4"
			or factionId == "act5"
		then
			return factionId :: CoreActId
		end
	end
	return "act1"
end

function DeckCatalog.laneMaskFor(laneMode: any): number
	if type(laneMode) == "string" and LANE_MASKS[laneMode] ~= nil then
		return LANE_MASKS[laneMode]
	end
	return LANE_MASKS.center
end

function DeckCatalog.starterForFaction(factionId: any): StarterDeck
	local f: FactionSpec = if type(factionId) == "string" and FACTIONS[factionId] ~= nil
		then FACTIONS[factionId]
		else FACTIONS.iron
	local unlockedMap: { [string]: boolean } = {}
	local unlockedList: { string } = {}
	for i, cardId in ipairs(f.starterUnlockedCards) do
		unlockedMap[cardId] = true
		unlockedList[i] = cardId
	end
	local squads: { DeckSquad } = {}
	for i, sq in ipairs(f.starterSquads) do
		squads[i] = {
			cardId = sq.cardId,
			count = sq.count,
			laneMode = sq.laneMode,
		}
	end
	return {
		faction = f.id,
		portalTheme = f.portalTheme,
		unlockedCards = unlockedMap,
		unlockedCardList = unlockedList,
		squads = squads,
		championCardId = nil,
		championLaneMode = "center",
	}
end

function DeckCatalog.computeStats(horde: any, leagueId: any?): DeckStats
	local supplyCap = DeckCatalog.supplyCapForLeague(leagueId)
	local supplyUsed = 0
	local totalUnits = 0
	local groundUnits = 0
	local airUnits = 0
	local squadCount = 0
	local hasChampion = false
	local resolvedChampId: string? = nil

	if type(horde) == "table" then
		local squads = horde.squads
		if type(squads) == "table" then
			for _, sq in ipairs(squads) do
				if type(sq) == "table" and type(sq.cardId) == "string" then
					local card = CARDS[sq.cardId]
					local count = tonumber(sq.count)
					if card ~= nil and card.kind == "squad" and count ~= nil and count > 0 then
						local packs = math.floor(count)
						if packs > 0 then
							squadCount += 1
							supplyUsed += packs * card.supply
							local units = packs * card.unitsPerPack
							totalUnits += units
							if card.flying then
								airUnits += units
							else
								groundUnits += units
							end
						end
					end
				end
			end
		end

		local champId = horde.championCardId
		if type(champId) == "string" and champId ~= "" then
			local champCard = CARDS[champId]
			if champCard ~= nil and champCard.isChampion then
				hasChampion = true
				resolvedChampId = champCard.id
				supplyUsed += champCard.supply
				totalUnits += champCard.unitsPerPack
				if champCard.flying then
					airUnits += champCard.unitsPerPack
				else
					groundUnits += champCard.unitsPerPack
				end
			end
		end
	end

	return {
		supplyUsed = supplyUsed,
		supplyCap = supplyCap,
		totalUnits = totalUnits,
		maxUnits = DeckCatalog.MAX_UNITS,
		groundUnits = groundUnits,
		airUnits = airUnits,
		flyingUnits = airUnits,
		squadCount = squadCount,
		hasChampion = hasChampion,
		championCardId = resolvedChampId,
	}
end

function DeckCatalog.canUnlockCard(
	horde: any,
	gold: any,
	cardId: any
): (boolean, string?, CardSpec?)
	local resolvedHorde = horde
	local resolvedGold = gold
	local resolvedCardId = cardId
	if resolvedCardId == nil and type(gold) == "string" then
		resolvedCardId = gold
		if type(horde) == "table" then
			resolvedGold = horde.gold
			if type(horde.horde) == "table" then
				resolvedHorde = horde.horde
			end
		end
	elseif type(horde) == "table" and type(horde.horde) == "table" then
		if resolvedGold == nil then
			resolvedGold = horde.gold
		end
		resolvedHorde = horde.horde
	end

	if type(resolvedCardId) ~= "string" then
		return false, "unknown_card", nil
	end
	local card = CARDS[resolvedCardId]
	if card == nil then
		return false, "unknown_card", nil
	end
	if type(resolvedHorde) ~= "table" then
		return false, "invalid_horde", card
	end
	local unlocked = resolvedHorde.unlockedCards
	if type(unlocked) == "table" and unlocked[card.id] == true then
		return false, "already_unlocked", card
	end
	if card.requiredCore ~= nil then
		local cores = resolvedHorde.bossCores
		if type(cores) ~= "table" or cores[card.requiredCore] ~= true then
			return false, "missing_boss_core", card
		end
	end
	local shards = if type(resolvedHorde.shards) == "number" then resolvedHorde.shards else 0
	if shards < card.costShards then
		return false, "insufficient_shards", card
	end
	local goldAmount = if type(resolvedGold) == "number" then resolvedGold else 0
	if goldAmount < card.costGold then
		return false, "insufficient_gold", card
	end
	return true, nil, card
end

function DeckCatalog.validateDeck(
	horde: any,
	leagueId: any?,
	enforceUnlocked: boolean?
): (boolean, string?, DeckStats?)
	if type(horde) ~= "table" then
		return false, "invalid_horde", nil
	end
	local squads = horde.squads
	if type(squads) ~= "table" then
		return false, "invalid_squads", nil
	end
	local keyCount = 0
	for k in pairs(squads) do
		if type(k) ~= "number" then
			return false, "invalid_squads", nil
		end
		keyCount += 1
	end
	if keyCount ~= #squads or #squads < 1 or #squads > DeckCatalog.MAX_SQUADS then
		return false, "invalid_squads", nil
	end

	local checkUnlocked = enforceUnlocked == true
	local unlocked: { [string]: boolean } = if type(horde.unlockedCards) == "table"
		then horde.unlockedCards
		else {}

	for _, sq in ipairs(squads) do
		if type(sq) ~= "table" or type(sq.cardId) ~= "string" then
			return false, "invalid_squad_card", nil
		end
		local card = CARDS[sq.cardId]
		if card == nil or card.kind ~= "squad" or card.isChampion then
			return false, "invalid_squad_card", nil
		end
		if checkUnlocked and unlocked[card.id] ~= true then
			return false, "card_locked", nil
		end
		if not isFiniteInt(sq.count) or sq.count < card.minCount or sq.count > card.maxCount then
			return false, "invalid_squad_count", nil
		end
		if type(sq.laneMode) ~= "string" or LANE_MODES[sq.laneMode] == nil then
			return false, "invalid_lane_mode", nil
		end
	end

	local champId = horde.championCardId
	if champId ~= nil and champId ~= "" then
		if type(champId) ~= "string" then
			return false, "invalid_champion_card", nil
		end
		local champCard = CARDS[champId]
		if champCard == nil or not champCard.isChampion or champCard.kind ~= "champion" then
			return false, "invalid_champion_card", nil
		end
		if checkUnlocked and unlocked[champCard.id] ~= true then
			return false, "champion_locked", nil
		end
		local champLane = if horde.championLaneMode ~= nil then horde.championLaneMode else "center"
		if type(champLane) ~= "string" or LANE_MODES[champLane] == nil then
			return false, "invalid_lane_mode", nil
		end
	elseif horde.championLaneMode ~= nil then
		if
			type(horde.championLaneMode) ~= "string"
			or LANE_MODES[horde.championLaneMode] == nil
		then
			return false, "invalid_lane_mode", nil
		end
	end

	local stats = DeckCatalog.computeStats(horde, leagueId)
	if stats.supplyUsed <= 0 or stats.totalUnits <= 0 then
		return false, "empty_deck", stats
	end
	if stats.supplyUsed > stats.supplyCap then
		return false, "supply_cap_exceeded", stats
	end
	if stats.totalUnits > DeckCatalog.MAX_UNITS then
		return false, "max_units_exceeded", stats
	end

	return true, nil, stats
end

function DeckCatalog.toWaveSpec(horde: any, leagueId: any?): WaveSpec
	local sourceHorde = horde
	if
		type(sourceHorde) ~= "table"
		or type(sourceHorde.squads) ~= "table"
		or #sourceHorde.squads == 0
	then
		local fallbackFaction = if type(sourceHorde) == "table" then sourceHorde.faction else "iron"
		sourceHorde = DeckCatalog.starterForFaction(fallbackFaction)
	end
	local _ = leagueId

	local slices: { WaveSliceSpec } = {}
	local totalCount = 0

	local champId = sourceHorde.championCardId
	local reserveForChamp = 0
	local champCard: CardSpec? = nil
	if type(champId) == "string" and champId ~= "" then
		local found = CARDS[champId]
		if found ~= nil and found.isChampion then
			champCard = found
			reserveForChamp = 1
		end
	end

	local maxSquadUnits = DeckCatalog.MAX_UNITS - reserveForChamp
	local startTicks = { 1, 18, 36 }
	for idx, sq in ipairs(sourceHorde.squads) do
		if
			idx <= DeckCatalog.MAX_SQUADS
			and type(sq) == "table"
			and type(sq.cardId) == "string"
		then
			local card = CARDS[sq.cardId]
			local rawPacks = tonumber(sq.count)
			if card ~= nil and card.kind == "squad" and rawPacks ~= nil and rawPacks > 0 then
				local packs = math.clamp(math.floor(rawPacks), 1, card.maxCount)
				local wantUnits = packs * card.unitsPerPack
				local remaining = maxSquadUnits - totalCount
				local sliceCount = math.min(wantUnits, math.max(0, remaining))
				if sliceCount > 0 then
					totalCount += sliceCount
					slices[#slices + 1] = {
						startTick = startTicks[idx] or (1 + (idx - 1) * 18),
						everyTicks = card.everyTicks,
						count = sliceCount,
						unit = card.unit,
						laneMask = DeckCatalog.laneMaskFor(sq.laneMode),
						isElite = card.isElite,
						isChampion = false,
					}
				end
			end
		end
	end

	if champCard ~= nil and totalCount < DeckCatalog.MAX_UNITS then
		totalCount += 1
		slices[#slices + 1] = {
			startTick = 24,
			everyTicks = champCard.everyTicks,
			count = 1,
			unit = champCard.unit,
			laneMask = DeckCatalog.laneMaskFor(sourceHorde.championLaneMode or "center"),
			isElite = false,
			isChampion = true,
		}
	end

	if #slices == 0 then
		local fallback = DeckCatalog.starterForFaction("iron")
		return DeckCatalog.toWaveSpec(fallback, leagueId)
	end

	return {
		count = totalCount,
		spawnEveryTicks = 12,
		slices = slices,
	}
end

return table.freeze(DeckCatalog)
