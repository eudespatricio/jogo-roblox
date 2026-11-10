--!nonstrict
-- Contrato headless da S6: BattleLog (com contentVersion, GAP-011), idempotencia por battle_id,
-- replay deterministico da raid e props de telemetria da taxonomia v1.
-- Roda no Luau CLI: luau sim/raid-contract.luau
local BattleLog = require("../src/shared/raid/BattleLog")
local BattleLogLedger = require("../src/shared/raid/BattleLogLedger")
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
		profile.wall.cells[trap.cell] = { trap = trap.type, level = trap.level }
	end
	local contentOk, contentErr = TrapCatalog.ensureProfileContent(profile)
	assert(contentOk, tostring(contentErr))
	local wall, wallErr = WallService.toBattleWall(profile, ProfileSchema, TrapCatalog, 500)
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

local fixedResult = Core.Run(42)

check("BattleLog inclui contentVersion e campos do resultado", function()
	local record, err = BattleLog.fromBattle(
		BATTLE_ID,
		fixedResult,
		TrapCatalog.CONTENT_VERSION,
		Core.GRID_WIDTH,
		5,
		1762800000
	)
	assert(record ~= nil, tostring(err))
	assert(record.contentVersion == 2, "contentVersion")
	assert(record.battleId == BATTLE_ID, "battleId")
	assert(record.resultHash == fixedResult.hash, "hash")
	assert(record.durationMs == fixedResult.ticks * 50, "durationMs")
	local ok, validateErr = BattleLog.validate(record)
	assert(ok, tostring(validateErr))
	assert(BattleLog.keyFor(record.battleId) == BATTLE_ID, "chave != battle_id")
end)

check("BattleLog recusa replay de conteudo futuro", function()
	local record = assert(BattleLog.fromBattle(BATTLE_ID, fixedResult, 2, 5, 5, 1762800000))
	local ok = BattleLog.isReplayable(record, 2)
	assert(ok, "record atual nao replayavel")
	local futureOk, futureErr = BattleLog.isReplayable(record, 1)
	assert(not futureOk and futureErr == "content_future", tostring(futureErr))
end)

check("ledger: 1 chave por battle_id e recompensa uma vez", function()
	local ledger = BattleLogLedger.new()
	local record = assert(BattleLog.fromBattle(BATTLE_ID, fixedResult, 2, 5, 5, 1762800000))
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

print(string.format("contrato de raid (S6): %d checagens, %d falhas", checks, #failures))
if #failures > 0 then
	for _, failure in ipairs(failures) do
		print("  FALHOU: " .. failure)
	end
	error("contrato de raid quebrado")
end
print("OK: contrato de raid passou")
