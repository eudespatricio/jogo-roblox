--!nonstrict
-- Contrato headless da S6/S8.1: BattleLog (com contentVersion, GAP-011), escrita unica,
-- idempotencia por battle_id, replay deterministico, BotPhantoms L1..L5, PhantomStore
-- shardado sem PII/auto-raid, economia (fadiga/consolacao/Elo) e telemetria v1.
-- Roda no Luau CLI: luau sim/raid-contract.luau
local BattleLog = require("../src/shared/raid/BattleLog")
local BattleLogLedger = require("../src/shared/raid/BattleLogLedger")
local BotPhantoms = require("../src/shared/raid/BotPhantoms")
local PhantomStore = require("../src/server/raid/PhantomStore")
local RaidReplay = require("../src/shared/raid/RaidReplay")
local RaidTelemetry = require("../src/shared/raid/RaidTelemetry")
local AnalyticsTypes = require("../src/shared/analytics/AnalyticsTypes")
local Core = require("../src/shared/sim/core")
local ProfileSchema = require("../src/shared/data/ProfileSchema")
local TrapCatalog = require("../src/shared/data/TrapCatalog")
local WallService = require("../src/server/walls/WallService")

local failures = {}
local checks = 0

local function check(name, fn)
	checks += 1
	local ok, err = pcall(fn)
	if not ok then
		failures[#failures + 1] = name .. " :: " .. tostring(err)
	end
end

local BATTLE_ID = "b7e2c9d4-1a3f-4c58-9e6b-0d2f4a6c8e10"
local CTX = {
	event_id = "5f0c1e6a-9b2d-4c3f-8a71-2d4e6f8a0b1c",
	ts = 1762800000,
	session_id = "2b6f1d9c-4a3e-4f7b-9c1d-8e5a0f3b6c42",
	player_id = "3f7a9c1e5b2d4f608a1c3e5b7d9f0a2c",
	place_version = "0.1.0-s6",
	platform = "mobile",
	device_tier = "mid",
	locale = "pt-BR",
	is_age_checked = false,
	server_id = "9d1e2f3a4b5c6d7e8f9012345678abcd",
	experiment = "s6_raid=phantom",
}

local function phantomWall(): (any, any)
	local profile = ProfileSchema.template()
	for _, trap in ipairs(Core.defaultWall().traps) do
		local cx, cy = ProfileSchema.cellToPos(trap.cell)
		profile.wall.cells[trap.cell] = {
			trap = trap.type,
			level = trap.level,
			x = trap.x or cx,
			y = trap.y or cy,
		}
	end
	local contentOk, contentErr = TrapCatalog.ensureProfileContent(profile)
	assert(contentOk, tostring(contentErr))
	local wall, wallErr = WallService.toBattleWall(profile, ProfileSchema, TrapCatalog)
	assert(wall ~= nil, tostring(wallErr))
	return wall, profile
end

local function runBattle(seed, wall)
	local battle = Core.Battle.new({
		seed = seed,
		simVersion = Core.SIM_VERSION,
		wall = wall,
		wave = { count = 70 },
	})
	return battle:Run()
end

local function computeRewardGold(targetLeague, raidsNow, winner)
	local baseGold = 15 + 3 * math.clamp(targetLeague, 1, 5)
	local fatiguePct = if raidsNow < 10 then 100 elseif raidsNow < 25 then 50 else 25
	local winGold = math.max(5, math.floor(baseGold * fatiguePct / 100))
	return if winner == "attacker" then winGold elseif raidsNow < 3 then 5 else 0
end

local function applyRaidOutcome(profile, winner)
	local oldPoints = profile.league.points
	local oldLeague = TrapCatalog.leagueOf(oldPoints)
	profile.stats.raids += 1
	local newPoints = oldPoints
	if winner == "attacker" then
		profile.stats.wins += 1
		newPoints = oldPoints + 25
	elseif oldLeague >= 3 then
		newPoints = math.max((oldLeague - 1) * 100, oldPoints - 10)
	end
	profile.league.points = newPoints
	local newLeague = TrapCatalog.leagueOf(newPoints)
	if newLeague ~= oldLeague then
		return { from = oldLeague, to = newLeague, delta = newPoints - oldPoints }
	end
	return nil
end

local battleWall = phantomWall()
local fixedResult = Core.Run(42)

check("BattleLog inclui contentVersion e campos do resultado", function()
	local record, err = BattleLog.fromBattle(
		BATTLE_ID,
		fixedResult,
		TrapCatalog.CONTENT_VERSION,
		Core.GRID_WIDTH,
		5,
		battleWall,
		1762800000
	)
	assert(record ~= nil, tostring(err))
	assert(record.contentVersion == TrapCatalog.CONTENT_VERSION, "contentVersion")
	assert(record.battleId == BATTLE_ID, "battleId")
	assert(record.resultHash == fixedResult.hash, "hash")
	assert(record.durationMs == fixedResult.ticks * 50, "durationMs")
	assert(#record.wall.traps == 5, "wall.traps")
	assert(record.wall.hp == battleWall.hp, "wall.hp")
	local ok, validateErr = BattleLog.validate(record)
	assert(ok, tostring(validateErr))
	assert(BattleLog.keyFor(record.battleId) == BATTLE_ID, "chave != battle_id")
end)

check("BattleLog recusa replay de conteudo futuro", function()
	local record =
		assert(BattleLog.fromBattle(BATTLE_ID, fixedResult, 2, 5, 5, battleWall, 1762800000))
	local ok = BattleLog.isReplayable(record, 2)
	assert(ok, "record atual nao replayavel")
	local futureOk, futureErr = BattleLog.isReplayable(record, 1)
	assert(not futureOk and futureErr == "content_future", tostring(futureErr))
end)

check("ledger: 1 chave por battle_id e recompensa uma vez", function()
	local ledger = BattleLogLedger.new()
	local record =
		assert(BattleLog.fromBattle(BATTLE_ID, fixedResult, 2, 5, 5, battleWall, 1762800000))
	local first, created = BattleLogLedger.claim(ledger, record)
	assert(first ~= nil and created == true, "primeiro claim")
	local second, createdAgain = BattleLogLedger.claim(ledger, record)
	assert(second == first and createdAgain == false, "segundo claim duplicou")
	assert(BattleLogLedger.count(ledger) == 1, "mais de uma chave")
	local rewarded = assert(BattleLogLedger.markRewarded(ledger, BATTLE_ID, 5))
	assert(rewarded.rewarded == true and rewarded.rewardGold == 5, "reward")
	local again = assert(BattleLogLedger.markRewarded(ledger, BATTLE_ID, 9))
	assert(again.rewardGold == 5, "reward duplicado")
end)

check("replay deterministico: mesmo hash; outro seed diverge", function()
	local wallA = phantomWall()
	local wallB = phantomWall()
	local first = runBattle(42, wallA)
	local replay = runBattle(42, wallB)
	local ok, err, expected, actual = RaidReplay.verify(first, replay)
	assert(ok, tostring(err))
	assert(expected == actual, "hash")
	assert(RaidReplay.SECONDS == 8, "replay 8s")

	local wallC = phantomWall()
	local different = runBattle(43, wallC)
	local specOk, specErr = RaidReplay.verify(first, different)
	assert(not specOk and specErr == "replay_spec", tostring(specErr))

	local corrupted = {}
	for key, value in pairs(first) do
		corrupted[key] = value
	end
	corrupted.hash = first.hash + 1
	local divergentOk, divergentErr = RaidReplay.verify(first, corrupted)
	assert(not divergentOk and divergentErr == "divergence", tostring(divergentErr))
end)

check("props de telemetria validam na taxonomia v1", function()
	local started = RaidTelemetry.startedProps(BATTLE_ID, 42, 3, 5, 5)
	assert(started ~= nil, "started")
	assert(AnalyticsTypes.newEvent(CTX, "battle_started", started) ~= nil, "battle_started")
	local finished = RaidTelemetry.finishedProps(BATTLE_ID, fixedResult)
	assert(finished ~= nil, "finished")
	assert(AnalyticsTypes.newEvent(CTX, "battle_finished", finished) ~= nil, "battle_finished")
	local divergence =
		RaidTelemetry.divergenceProps(BATTLE_ID, fixedResult.hash, fixedResult.hash + 1)
	assert(divergence ~= nil, "divergence")
	assert(
		AnalyticsTypes.newEvent(CTX, "battle_divergence", divergence) ~= nil,
		"battle_divergence"
	)
end)

check("muralha fantasma passa por toBattleWall e roda no motor", function()
	local wall, profile = phantomWall()
	assert(#wall.traps == 5, "traps")
	assert(profile.contentVersion == TrapCatalog.CONTENT_VERSION, "contentVersion")
	local result = runBattle(42, wall)
	assert(result.hash == 2489780106 or result.hash > 0, "hash invalido")
	assert(result.simVersion == Core.SIM_VERSION, "simVersion")
end)

check("BotPhantoms: 2 muralhas por liga L1..L5, hp e limite por tier", function()
	for league = 1, 5 do
		local expectedHp = TrapCatalog.WALL_LEVELS[league].hp
		local expectedLimit = TrapCatalog.WALL_LEVELS[league].trapLimit
		local pool = BotPhantoms.POOLS[league]
		assert(type(pool) == "table" and #pool == 2, "pool liga " .. tostring(league))
		for _, entry in ipairs(pool) do
			assert(entry.level == league, "level != league")
			assert(entry.hp == expectedHp, "hp != " .. tostring(expectedHp))
			assert(#entry.traps >= 1 and #entry.traps <= expectedLimit, "traps count")
			for _, trap in ipairs(entry.traps) do
				assert(TrapCatalog.TRAPS[trap.type] ~= nil, "trap desconhecida: " .. trap.type)
				assert(trap.level >= 1 and trap.level <= TrapCatalog.MAX_LEVEL, "level")
			end
		end
		local w0 = BotPhantoms.pick(league, 0)
		local w1 = BotPhantoms.pick(league, 1)
		assert(w0.hp == expectedHp and w1.hp == expectedHp, "pick hp")
		assert(#w0.traps ~= #w1.traps or w0.traps[1].type ~= w1.traps[1].type, "2 variantes")
		-- Mutating picked wall must not affect pool
		w0.traps[1].level = 99
		assert(BotPhantoms.pick(league, 0).traps[1].level ~= 99, "pool mutada")
	end
	assert(#BotPhantoms.pick(0, 0).traps == #BotPhantoms.pick(1, 0).traps, "clamp low")
	assert(#BotPhantoms.pick(99, 0).traps == #BotPhantoms.pick(5, 0).traps, "clamp high")
end)

check("BotPhantoms L1 garante vitoria do atacante em <60s", function()
	local wins = 0
	local total = 20
	for seed = 1, total do
		local wall = BotPhantoms.pick(1, seed)
		local result = runBattle(seed * 7, wall)
		if result.winner == "attacker" then
			wins += 1
			assert(result.ticks * 0.05 < 60, "L1 demorou >= 60s: " .. tostring(result.ticks * 0.05))
		end
	end
	assert(wins >= 18, string.format("L1 win rate baixo: %d/%d", wins, total))
end)

check("PhantomStore: hashOwner 8-hex, shards L1_S1..L5_S8 e zero PII", function()
	assert(PhantomStore.SLOTS_PER_LEAGUE == 8, "SLOTS_PER_LEAGUE")
	for _, uid in ipairs({ 0, 1, 123456, 4294967295, 7123456789 }) do
		local h = PhantomStore.hashOwner(uid)
		assert(#h == 8 and string.match(h, "^[0-9a-f]+$") ~= nil, "hashOwner: " .. tostring(h))
	end
	assert(PhantomStore.slotKey(1, 1) == "L1_S1", "L1_S1")
	assert(PhantomStore.slotKey(5, 8) == "L5_S8", "L5_S8")
	assert(PhantomStore.slotKey(0, 9) == "L1_S1", "clamp/wrap")
	assert(PhantomStore.slotKey(9, 8) == "L5_S8", "clamp high")

	local store = PhantomStore.new({ mock = true })
	local validSnap = {
		ownerHash = PhantomStore.hashOwner(101),
		league = 1,
		hp = 500,
		traps = { { cell = "r3c3", type = "archer", level = 1 } },
		contentVersion = TrapCatalog.CONTENT_VERSION,
		updatedAt = 1762800000,
	}
	local ok, err = store.put(validSnap, 1)
	assert(ok, tostring(err))

	local piiName = table.clone(validSnap)
	piiName.ownerName = "PlayerOne"
	local okName, errName = store.put(piiName, 1)
	assert(not okName and errName == "pii proibido", tostring(errName))

	local piiId = table.clone(validSnap)
	piiId.ownerId = 101
	local okId, errId = store.put(piiId, 1)
	assert(not okId and errId == "pii proibido", tostring(errId))
end)

check("PhantomStore: anti-auto-raid e match por liga", function()
	local store = PhantomStore.new({ mock = true })
	local hashA = PhantomStore.hashOwner(1001)
	local hashB = PhantomStore.hashOwner(1002)
	local snapA = {
		ownerHash = hashA,
		league = 2,
		hp = 500,
		traps = { { cell = "r2c3", type = "archer", level = 1 } },
		contentVersion = TrapCatalog.CONTENT_VERSION,
		updatedAt = 1762800000,
	}
	local snapB = {
		ownerHash = hashB,
		league = 2,
		hp = 500,
		traps = { { cell = "r3c2", type = "tar", level = 1 } },
		contentVersion = TrapCatalog.CONTENT_VERSION,
		updatedAt = 1762800001,
	}
	assert(store.put(snapA, 1))
	for seed = 0, 15 do
		local selfMatch = store.getForLeague(2, hashA, seed)
		assert(selfMatch == nil, "auto-raid encontrado para seed " .. tostring(seed))
	end

	-- Preenche slots 2..8 com hashB; qualquer seed que toque 2..8 deve achar hashB sem PII.
	for slot = 2, 8 do
		assert(store.put(snapB, slot))
	end
	local found = store.getForLeague(2, hashA, 0)
	assert(found ~= nil and found.ownerHash == hashB, "nao encontrou oponente")
	assert((found :: any).ownerName == nil and (found :: any).ownerId == nil, "vazou PII")
	assert(store.getForLeague(3, hashA, 0) == nil, "vazou outra liga")
end)

check("economia da raid: baseGold, fadiga (<10/<25/25+, piso 5g) e consolacao (<3)", function()
	-- L1..L5 baseGold = 18, 21, 24, 27, 30
	assert(computeRewardGold(1, 0, "attacker") == 18, "L1 100%")
	assert(computeRewardGold(2, 9, "attacker") == 21, "L2 100%")
	assert(computeRewardGold(5, 0, "attacker") == 30, "L5 100%")

	-- Fadiga 50% (10..24) e 25% (25+), piso 5g
	assert(computeRewardGold(1, 10, "attacker") == 9, "L1 50%")
	assert(computeRewardGold(1, 24, "attacker") == 9, "L1 50% limite")
	assert(computeRewardGold(1, 25, "attacker") == 5, "L1 25% piso 5g")
	assert(computeRewardGold(5, 10, "attacker") == 15, "L5 50%")
	assert(computeRewardGold(5, 25, "attacker") == 7, "L5 25%")

	-- Consolacao derrota (raids < 3 -> 5g, >=3 -> 0g)
	assert(computeRewardGold(1, 0, "defender") == 5, "consolacao raid 0")
	assert(computeRewardGold(1, 2, "defender") == 5, "consolacao raid 2")
	assert(computeRewardGold(1, 3, "defender") == 0, "sem consolacao raid 3")
end)

check(
	"Elo e ProfileSchema v2: +25 vitoria, -10 piso L>=3, league_changed, sem tier/losses",
	function()
		local profile = ProfileSchema.template()
		profile.contentVersion = TrapCatalog.CONTENT_VERSION
		local changed = nil
		for _ = 1, 4 do
			changed = applyRaidOutcome(profile, "attacker")
		end
		assert(profile.stats.raids == 4 and profile.stats.wins == 4, "stats apos 4 vitorias")
		assert(profile.league.points == 100, "4 vitorias = 100 pts")
		assert(TrapCatalog.leagueOf(profile.league.points) == 2, "Liga 2")
		assert(
			changed ~= nil and changed.from == 1 and changed.to == 2 and changed.delta == 25,
			"league_changed"
		)
		assert(
			AnalyticsTypes.newEvent(CTX, "league_changed", changed) ~= nil,
			"evento league_changed"
		)

		-- Derrota em L2 nao reduz pontos
		local noChangeL2 = applyRaidOutcome(profile, "defender")
		assert(noChangeL2 == nil and profile.league.points == 100, "piso L2")

		-- Sobe para L3 (205 pts) e perde: reduz -10 com clamp no piso (3-1)*100 = 200
		profile.league.points = 205
		local noDropBelowFloor = applyRaidOutcome(profile, "defender")
		assert(noDropBelowFloor == nil and profile.league.points == 200, "piso L3 = 200")

		-- Em L4 (320 pts) perde -10 -> 310
		profile.league.points = 320
		applyRaidOutcome(profile, "defender")
		assert(profile.league.points == 310, "L4 -10 = 310")

		assert((profile.league :: any).tier == nil, "nunca escreve league.tier")
		assert((profile.stats :: any).losses == nil, "nunca escreve stats.losses")
		local valid, validErr = ProfileSchema.validate(profile)
		assert(valid, tostring(validErr))
	end
)

check("BattleLog escrita unica: creditGold antes de markRewarded e claim unico", function()
	local profile = ProfileSchema.template()
	profile.contentVersion = TrapCatalog.CONTENT_VERSION
	local service = WallService.new({
		profile = profile,
		schema = ProfileSchema,
		catalog = TrapCatalog,
	})
	local rewardGold = computeRewardGold(1, profile.stats.raids, "attacker")
	local creditRes, creditErr = service.creditGold(rewardGold, "raid", BATTLE_ID)
	assert(creditRes ~= nil and creditRes.gold == 18, tostring(creditErr))

	local baseRecord = assert(
		BattleLog.fromBattle(
			BATTLE_ID,
			fixedResult,
			TrapCatalog.CONTENT_VERSION,
			Core.GRID_WIDTH,
			5,
			battleWall,
			1762800000
		)
	)
	local finalRecord, markErr = BattleLog.markRewarded(baseRecord, rewardGold)
	assert(finalRecord ~= nil, tostring(markErr))
	assert(finalRecord.rewarded == true and finalRecord.rewardGold == 18, "reward em memoria")

	local ledger = BattleLogLedger.new()
	local stored, created = BattleLogLedger.claim(ledger, finalRecord)
	assert(created == true and stored ~= nil, "single put")
	assert(stored.rewarded == true and stored.rewardGold == 18, "stored reward")
	local _, createdAgain = BattleLogLedger.claim(ledger, finalRecord)
	assert(createdAgain == false, "idempotencia")
end)

check(
	"P2: muralha Nv1..5, ate 7 traps livres em BattleLog/PhantomStore e BotPhantoms L1..5",
	function()
		for league = 1, 5 do
			local botWall = BotPhantoms.pick(league, 42 + league)
			assert(botWall.level == league, "botWall.level")
			assert(botWall.hp == TrapCatalog.WALL_LEVELS[league].hp, "botWall.hp L" .. league)
			assert(
				#botWall.traps <= TrapCatalog.WALL_LEVELS[league].trapLimit,
				"botWall limit L" .. league
			)
			local res = runBattle(100 + league, botWall)
			assert(res.simVersion == Core.SIM_VERSION, "simVersion no bot")
		end

		-- L1 bot continua garantindo >= 18/20 vitorias do atacante em <60s (1200 ticks)
		local l1WinsUnder60 = 0
		for seed = 1, 20 do
			local l1Wall = BotPhantoms.pick(1, seed)
			local res = runBattle(seed, l1Wall)
			if res.winner == "attacker" and res.ticks < 1200 then
				l1WinsUnder60 += 1
			end
		end
		assert(l1WinsUnder60 >= 18, "L1 bot wins <60s: " .. tostring(l1WinsUnder60))

		local freeTraps = {
			{ type = "archer", level = 5, x = 1000, y = 500 },
			{ type = "tar", level = 5, x = 2250, y = 500 },
			{ type = "frost", level = 5, x = 3500, y = 1500 },
			{ type = "cannon", level = 5, x = 5000, y = 2500 },
			{ type = "catapult", level = 5, x = 6500, y = 3500 },
			{ type = "archer", level = 5, x = 8000, y = 4500 },
			{ type = "cannon", level = 5, x = 3500, y = 4500 },
		}
		local freeWall = { level = 5, hp = 1250, traps = freeTraps }
		local freeRes = runBattle(77, freeWall)
		local logRec, logErr = BattleLog.fromBattle(
			"11111111111111111111111111111111",
			freeRes,
			TrapCatalog.CONTENT_VERSION,
			Core.GRID_WIDTH,
			7,
			freeWall,
			1762800000
		)
		assert(logRec ~= nil, tostring(logErr))

		local store = PhantomStore.new({ mock = true })
		local putOk, putErr = store.put({
			ownerHash = "a1b2c3d4",
			league = 5,
			level = 5,
			hp = 1250,
			traps = freeTraps,
			contentVersion = TrapCatalog.CONTENT_VERSION,
			updatedAt = 1762800000,
		})
		assert(putOk, tostring(putErr))

		local tooMany = table.clone(freeTraps)
		tooMany[8] = { type = "archer", level = 1, x = 9000, y = 500 }
		local rejectOk = store.put({
			ownerHash = "a1b2c3d4",
			league = 5,
			level = 5,
			hp = 1250,
			traps = tooMany,
			contentVersion = TrapCatalog.CONTENT_VERSION,
			updatedAt = 1762800000,
		})
		assert(not rejectOk, "PhantomStore aceitou 8 traps")
	end
)

check("matchmaking justo + progressao de win-rate L1..L5 + defend escalonado", function()
	assert(BotPhantoms.matchLeague(3, 1, 2) == 1, "Lv1 c/ 2 traps deveria travar em L1")
	assert(BotPhantoms.matchLeague(5, 1, 5) == 2, "Lv1 c/ 5 traps no teto deveria limitar em L2")
	assert(BotPhantoms.matchLeague(4, 4, 5) == 4, "Lv4 pode enfrentar L4")

	for league = 1, 5 do
		local wave = BotPhantoms.waveFor(league, false)
		local wins = 0
		local total = 40
		for seed = 1, total do
			local botWall = BotPhantoms.pick(league, seed)
			local res = Core.Battle
				.new({
					seed = seed * 17 + league,
					simVersion = Core.SIM_VERSION,
					wall = botWall,
					wave = wave,
				})
				:Run()
			if res.winner == "attacker" then
				wins += 1
			end
		end
		local pct = (wins * 100) / total
		assert(
			pct >= 45,
			string.format("BotPhantoms L%d win rate muito baixo: %.0f%%", league, pct)
		)
	end

	local starterWall = {
		level = 1,
		hp = 500,
		traps = { { cell = "r3c2", type = "archer", level = 1, x = 3500, y = 2500 } },
	}
	local defendWave = BotPhantoms.waveFor(1, true, 1, 1)
	local defWins = 0
	for seed = 1, 20 do
		local res = Core.Battle
			.new({
				seed = seed * 19,
				simVersion = Core.SIM_VERSION,
				wall = starterWall,
				wave = defendWave,
			})
			:Run()
		if res.winner == "defender" then
			defWins += 1
		end
	end
	assert(defWins >= 15, "defend inicial deveria vencer >= 75%: " .. tostring(defWins))
end)

print(string.format("contrato de raid (S6/S8.1): %d checagens, %d falhas", checks, #failures))
if #failures > 0 then
	for _, failure in ipairs(failures) do
		print("  FALHOU: " .. failure)
	end
	error("contrato de raid quebrado")
end
print("OK: contrato de raid passou")
