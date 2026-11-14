--!nonstrict
-- Contrato executavel do sistema de Horda & Deck (Playtest v1.4, Core v8):
-- 5 Faccoes, 13 Cartas (8 Esquadroes + 5 Campeoes de Ato), caps de Suprimento por Liga (1..7),
-- MAX_UNITS = 85, regras anti-aereas (wisp/drake) e estados de Campeao (survived/killed).
-- Roda no Luau CLI:
--   luau sim/deck-contract.luau

local Core = require("../src/shared/sim/core")
local DeckCatalog = require("../src/shared/raid/DeckCatalog")

local failures = {}
local checks = 0

local function check(name, fn)
	checks += 1
	local ok, err = pcall(fn)
	if not ok then
		failures[#failures + 1] = name .. " :: " .. tostring(err)
	end
end

-- 1) 5 Faccoes, ratings taticos e temas de Portal (act1..act5)
check("5 Faccoes, ratings taticos (ground/air/armor/speed) e portalThemeFor", function()
	local expected = {
		iron = { act = 1, theme = "act1", g = 5, a = 2, ar = 5, s = 2 },
		slag = { act = 2, theme = "act2", g = 4, a = 3, ar = 3, s = 3 },
		frost = { act = 3, theme = "act3", g = 3, a = 4, ar = 4, s = 2 },
		powder = { act = 4, theme = "act4", g = 4, a = 2, ar = 2, s = 5 },
		rift = { act = 5, theme = "act5", g = 3, a = 5, ar = 3, s = 4 },
	}
	assert(#DeckCatalog.FACTION_ORDER == 5, "FACTION_ORDER != 5")
	for _, factionId in ipairs(DeckCatalog.FACTION_ORDER) do
		local f = DeckCatalog.FACTIONS[factionId]
		local exp = expected[factionId]
		assert(f ~= nil and exp ~= nil, "faccao ausente: " .. tostring(factionId))
		assert(f.act == exp.act and f.portalTheme == exp.theme, "act/theme de " .. factionId)
		assert(
			f.ground == exp.g and f.air == exp.a and f.armor == exp.ar and f.speed == exp.s,
			"ratings de " .. factionId
		)
		assert(
			DeckCatalog.portalThemeFor(factionId) == exp.theme,
			"portalThemeFor(" .. factionId .. ")"
		)
	end
	assert(DeckCatalog.portalThemeFor("unknown") == "act1", "fallback portalThemeFor != act1")
end)

-- 2) 5 Starter Decks validos na Liga 1 (<=70 supply, <=85 unidades, 3 cartas, 3 squads)
check("5 Starter Decks (3 cartas desbloqueadas, 3 squads, <=70 supply, <=85 units)", function()
	for _, factionId in ipairs(DeckCatalog.FACTION_ORDER) do
		local starter = DeckCatalog.starterForFaction(factionId)
		assert(starter.faction == factionId, "starter.faction != " .. factionId)
		assert(starter.championCardId == nil, "starter nao deve vir com Campeao")
		assert(starter.championLaneMode == "center", "starter championLaneMode != center")
		assert(#starter.squads == 3, "starter deve ter 3 squads")
		local unlockedCount = 0
		for cardId, flag in pairs(starter.unlockedCards) do
			if flag == true then
				unlockedCount += 1
				local card = DeckCatalog.CARDS[cardId]
				assert(
					card ~= nil and card.kind == "squad",
					"starter desbloqueou carta invalida: " .. tostring(cardId)
				)
			end
		end
		assert(unlockedCount == 3, "starter deve ter 3 cartas desbloqueadas: " .. factionId)

		local ok, err, stats = DeckCatalog.validateDeck(starter, 1, true)
		assert(ok, "starter invalido para " .. factionId .. ": " .. tostring(err))
		assert(
			stats ~= nil and stats.supplyUsed > 0 and stats.supplyUsed <= 70,
			"supplyUsed fora de (0, 70]"
		)
		assert(
			stats.totalUnits > 0 and stats.totalUnits <= DeckCatalog.MAX_UNITS,
			"totalUnits fora de (0, 85]"
		)
	end
end)

-- 3) 13 Cartas (8 Esquadroes + 5 Campeoes Miticos), 5 Raridades e 4 Lane Modes
check("13 Cartas (8 squads + 5 champions), 5 raridades e 4 modos de lane", function()
	assert(#DeckCatalog.CARD_ORDER == 13, "CARD_ORDER != 13")
	local squadCount = 0
	local champCount = 0
	local flyingCards = {
		squad_rift_wisps = true,
		squad_sky_drakes = true,
		champ_frost_matriarch = true,
		champ_rift_archon = true,
	}
	local requiredCores = {
		squad_sky_drakes = "act3",
		champ_iron_ram = "act1",
		champ_slag_lord = "act2",
		champ_frost_matriarch = "act3",
		champ_powder_baron = "act4",
		champ_rift_archon = "act5",
	}
	for _, cardId in ipairs(DeckCatalog.CARD_ORDER) do
		local c = DeckCatalog.CARDS[cardId]
		assert(c ~= nil and c.id == cardId, "carta ausente: " .. tostring(cardId))
		assert(DeckCatalog.RARITIES[c.rarity] ~= nil, "raridade invalida em " .. cardId)
		assert(Core.UNIT[c.unit] ~= nil, "unidade desconhecida no Core: " .. tostring(c.unit))
		assert(c.flying == (flyingCards[cardId] == true), "flying divergente em " .. cardId)
		assert(c.requiredCore == requiredCores[cardId], "requiredCore divergente em " .. cardId)
		if c.isChampion then
			champCount += 1
			assert(c.kind == "champion" and c.rarity == "mythic", "campeao deve ser mythic")
		else
			squadCount += 1
			assert(c.kind == "squad", "esquadrao deve ter kind=squad")
		end
	end
	assert(squadCount == 8 and champCount == 5, "contagem 8 squads + 5 champions divergiu")

	local expectedLanes = {
		center = { 3 },
		flanks = { 1, 5 },
		split = { 2, 4 },
		all = { 1, 2, 3, 4, 5 },
	}
	for mode, lanes in pairs(expectedLanes) do
		local got = DeckCatalog.LANE_MODES[mode]
		assert(type(got) == "table" and #got == #lanes, "lane mode invalido: " .. mode)
		for i, laneNum in ipairs(lanes) do
			assert(got[i] == laneNum, "lane divergente em " .. mode)
		end
	end
end)

-- 4) Caps de Suprimento por Liga (1..7: 70..90), MAX_UNITS=85 e canUnlockCard
check("Supply caps por Liga (70..90), MAX_UNITS=85 e canUnlockCard", function()
	local expectedCaps = { 70, 74, 78, 82, 85, 88, 90 }
	for leagueId, cap in ipairs(expectedCaps) do
		assert(
			DeckCatalog.supplyCapForLeague(leagueId) == cap,
			"cap da liga " .. leagueId .. " != " .. cap
		)
	end
	assert(DeckCatalog.MAX_UNITS == 85, "MAX_UNITS != 85")

	-- Validacao de excesso de supply na Liga 1 (cap 70), mas valido na Liga 7 (cap 90)
	local deck76 = DeckCatalog.starterForFaction("iron")
	deck76.squads = {
		{ cardId = "squad_iron_vanguard", count = 3, laneMode = "center" }, -- 30 supply, 12 units
		{ cardId = "squad_brute_guards", count = 3, laneMode = "split" }, -- 30 supply, 9 units
		{ cardId = "squad_runner_pack", count = 2, laneMode = "flanks" }, -- 16 supply, 12 units
	}
	local okL1, errL1 = DeckCatalog.validateDeck(deck76, 1, true)
	assert(not okL1 and errL1 == "supply_cap_exceeded", "deveria recusar 76 supply na Liga 1")
	local okL3, errL3 = DeckCatalog.validateDeck(deck76, 3, true) -- Liga 3 cap = 78
	assert(okL3 and errL3 == nil, "deveria aceitar 76 supply na Liga 3: " .. tostring(errL3))

	-- Validacao de excesso de MAX_UNITS=85 (11 packs de swarm = 88 unidades, 88 supply <= 90 na Liga 7)
	local deckOverUnits = DeckCatalog.starterForFaction("powder")
	deckOverUnits.squads = {
		{ cardId = "squad_swarm_brood", count = 8, laneMode = "all" }, -- 64 units, 64 supply
		{ cardId = "squad_runner_pack", count = 4, laneMode = "flanks" }, -- 24 units, 32 supply -> test with 26 supply
	}
	-- Ajusta para 88 unidades e 88 supply (dentro do cap 90 da Liga 7, mas acima de MAX_UNITS=85):
	deckOverUnits.unlockedCards.squad_swarm_brood = true
	deckOverUnits.squads = {
		{ cardId = "squad_swarm_brood", count = 5, laneMode = "all" }, -- 40 units, 40 supply
		{ cardId = "squad_swarm_brood", count = 4, laneMode = "flanks" }, -- 32 units, 32 supply
		{ cardId = "squad_runner_pack", count = 3, laneMode = "center" }, -- 18 units, 24 supply -> 96 supply
	}
	-- Com 11 packs de swarm (5 + 4 + 2 = 11 packs -> 88 units, 88 supply <= 90 na Liga 7):
	deckOverUnits.squads = {
		{ cardId = "squad_swarm_brood", count = 5, laneMode = "all" },
		{ cardId = "squad_swarm_brood", count = 4, laneMode = "flanks" },
		{ cardId = "squad_swarm_brood", count = 2, laneMode = "center" },
	}
	local okUnits, errUnits = DeckCatalog.validateDeck(deckOverUnits, 7, true)
	assert(
		not okUnits and errUnits == "max_units_exceeded",
		"deveria recusar 88 unidades (> MAX_UNITS=85): " .. tostring(errUnits)
	)

	-- canUnlockCard: requer ouro, fragmentos e Boss Core do Ato quando aplicavel
	local horde = {
		unlockedCards = { squad_runner_pack = true },
		shards = 2,
		bossCores = { act1 = true, act3 = false },
	}
	local okAlready, errAlready = DeckCatalog.canUnlockCard(horde, 9999, "squad_runner_pack")
	assert(not okAlready and errAlready == "already_unlocked", "already_unlocked")

	local okNoCore, errNoCore = DeckCatalog.canUnlockCard(horde, 9999, "squad_sky_drakes")
	assert(not okNoCore and errNoCore == "missing_boss_core", "missing_boss_core")

	horde.bossCores.act3 = true
	local okNoShards, errNoShards = DeckCatalog.canUnlockCard(horde, 9999, "squad_sky_drakes")
	assert(not okNoShards and errNoShards == "insufficient_shards", "insufficient_shards")

	horde.shards = 10
	local okNoGold, errNoGold = DeckCatalog.canUnlockCard(horde, 50, "squad_sky_drakes")
	assert(not okNoGold and errNoGold == "insufficient_gold", "insufficient_gold")

	local okUnlock, errUnlock = DeckCatalog.canUnlockCard(horde, 500, "squad_sky_drakes")
	assert(okUnlock and errUnlock == nil, "deveria liberar squad_sky_drakes")
end)

-- 5) Core v8 + toWaveSpec: regras aereas e estados de Campeao (survived vs hunted/killed)
check("toWaveSpec + Core v8: voadores e Campeao (championSurvived vs championKilled)", function()
	-- Deck com Campeao terreo sem armadilhas -> Campeao sobrevive e vaza no portao
	local hordeWin = DeckCatalog.starterForFaction("iron")
	hordeWin.unlockedCards.champ_iron_ram = true
	hordeWin.championCardId = "champ_iron_ram"
	hordeWin.championLaneMode = "center"
	local okWin, errWin = DeckCatalog.validateDeck(hordeWin, 1, true)
	assert(okWin, "deck com champ_iron_ram deveria ser valido na Liga 1: " .. tostring(errWin))

	local waveWin = DeckCatalog.toWaveSpec(hordeWin, 1)
	assert(waveWin.count <= DeckCatalog.MAX_UNITS, "toWaveSpec excedeu MAX_UNITS")
	local bWin = Core.Battle.new({
		seed = 301,
		simVersion = Core.SIM_VERSION,
		wall = { level = 1, hp = 500, traps = {} },
		wave = waveWin,
	})
	local resWin = bWin:Run()
	assert(resWin.championSpawned == 1, "championSpawned != 1")
	assert(resWin.championKilled == 0, "championKilled != 0 sem traps")
	assert(resWin.championSurvived == true, "championSurvived deveria ser true")

	-- Campeao voador (wisp) contra bateria de archers L5 em r3 -> Campeao abatido (championKilled == 1)
	local bKill = Core.Battle.new({
		seed = 302,
		simVersion = Core.SIM_VERSION,
		wall = {
			level = 5,
			hp = 1250,
			traps = {
				{ cell = "r3c5", type = "archer", level = 5 },
				{ cell = "r3c4", type = "archer", level = 5 },
				{ cell = "r3c3", type = "archer", level = 5 },
				{ cell = "r3c2", type = "archer", level = 5 },
				{ cell = "r3c1", type = "archer", level = 5 },
				{ cell = "r2c4", type = "archer", level = 5 },
				{ cell = "r4c4", type = "archer", level = 5 },
			},
		},
		wave = {
			slices = {
				{
					startTick = 1,
					everyTicks = 20,
					count = 1,
					unit = "wisp",
					laneMask = 4,
					isElite = false,
					isChampion = true,
				},
			},
		},
	})
	local resKill = bKill:Run()
	assert(resKill.championSpawned == 1, "championSpawned != 1 em bKill")
	assert(resKill.championKilled == 1, "championKilled != 1 contra 7 archers L5")
	assert(resKill.championBreached == 0, "championBreached != 0")
	assert(resKill.championSurvived == false, "championSurvived deveria ser false quando abatido")
end)

print(string.format("deck-contract: %d checagens, %d falhas", checks, #failures))
if #failures > 0 then
	for _, f in ipairs(failures) do
		print("  FALHOU: " .. f)
	end
	error("deck-contract quebrado")
end
print("OK: deck-contract passou")
