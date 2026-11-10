--!nonstrict
-- Contrato de analytics v1 (P0): envelope, catalogo, limites, anti-PII e integracao com o motor.
-- Roda no Luau CLI: luau sim/analytics-contract.luau
-- Regra dura: nenhum evento altera o BattleResult nem o hash (o servidor emite depois do hash).
local Core = require("../src/shared/sim/core")
local Analytics = require("../src/shared/analytics/AnalyticsTypes")
local AnalyticsService = require("../src/server/analytics/AnalyticsService")

local failures = {}
local checks = 0

local function check(name, fn)
	checks += 1
	local ok, err = pcall(fn)
	if not ok then
		failures[#failures + 1] = name .. " :: " .. tostring(err)
	end
end

local function clone(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, item in pairs(value) do
		copy[key] = clone(item)
	end
	return copy
end

local function countKeys(value)
	local count = 0
	for _ in pairs(value) do
		count += 1
	end
	return count
end

local function sortedKeys(value)
	local keys = {}
	for key in pairs(value) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return table.concat(keys, ",")
end

-- ---------------------------------------------------------------- contexto e fixtures
local BATTLE_ID = "b7e2c9d4-1a3f-4c58-9e6b-0d2f4a6c8e10"
local BATTLE_HASH = 2489780106
local HASH32 = "3f7a9c1e5b2d4f608a1c3e5b7d9f0a2c"
local CODE_HASH = "9d1e2f3a4b5c6d7e8f9012345678abcd"
local EVENT_ID = "5f0c1e6a-9b2d-4c3f-8a71-2d4e6f8a0b1c"
local SESSION_ID = "2b6f1d9c-4a3e-4f7b-9c1d-8e5a0f3b6c42"

local CTX = {
	event_id = EVENT_ID,
	ts = 1762800000,
	session_id = SESSION_ID,
	player_id = HASH32,
	place_version = "0.1.0-p0",
	platform = "mobile",
	device_tier = "mid",
	locale = "pt-BR",
	is_age_checked = false,
	server_id = CODE_HASH,
	experiment = "q2_grid=5x5",
}

-- Um fixture por evento do catalogo (taxonomia §2). Propriedades obrigatorias completas.
local PROPS = {
	-- 2.1 sessao e funil
	session_start = { days_since_last_seen = -1, is_returning = false },
	session_end = { duration_s = 412.5, reason = "leave" },
	dropin_shown = { ms_since_join = 1830 },
	dropin_pressed = { ms_since_join = 2410, pressed = true },
	first_win = { seconds_since_join = 42.5, battle_id = BATTLE_ID },
	build_complete = { traps_placed = 5, time_s = 37.5 },
	raid_start = { battle_id = BATTLE_ID, mode = "revenge", speed = 4 },
	raid_end = { battle_id = BATTLE_ID, result = "defender", duration_s = 12.5 },
	replay_started = { battle_id = BATTLE_ID, replay_length_s = 8 },
	replay_watched = { battle_id = BATTLE_ID, watched_s = 6.2, pct = 0.775 },
	clip_saved = { battle_id = BATTLE_ID },
	-- 2.2 batalha
	battle_started = {
		battle_id = BATTLE_ID,
		seed = 42,
		sim_version = 3,
		grid_width = 5,
		traps_count = 5,
	},
	battle_finished = {
		battle_id = BATTLE_ID,
		seed = 42,
		sim_version = 3,
		result_hash = BATTLE_HASH,
		winner = "defender",
		wall_hp = 45,
		leaked = 26,
		ticks = 1200,
		duration_ms = 60000,
	},
	battle_divergence = { battle_id = BATTLE_ID, expected_hash = BATTLE_HASH, actual_hash = 12345 },
	-- 2.3 economia
	gold_earned = { amount = 120, source = "raid", battle_id = BATTLE_ID },
	gold_spent = { amount = 80, sink = "trap" },
	trap_placed = { trap_id = "cannon", cell = "r1c3", cost = 40 },
	upgrade_bought = { target = "wall_segment_2", level = 2, cost = 150 },
	league_changed = { ["from"] = 10, to = 7, delta = -3 },
	blueprint_earned = { blueprint_id = "frost_blueprint", rarity = "rare", source = "raid" },
	-- 2.4 monetizacao
	offer_shown = { offer_id = "starter_pack", price_robux = 399, placement = "store" },
	purchase_start = { offer_id = "starter_pack", price_robux = 399 },
	purchase_complete = {
		offer_id = "starter_pack",
		price_robux = 399,
		product_type = "gamepass",
	},
	purchase_failed = { offer_id = "starter_pack", reason = "cancelled" },
	age_check_prompt = { origin = "reward" },
	age_check_result = { result = "verified" },
	-- 2.5 teste de 3 semanas
	test_offer_choice = { offer_id = "starter_pack", choice = true, reason_code = "colecao" },
	test_survey_answer = { question_id = "q_entendimento", answer_code = "sim" },
	-- 2.6 qualidade
	client_error = { code = "render_fail", context_hash = CODE_HASH },
	server_error = { code = "datastore_timeout", context_hash = CODE_HASH },
	perf_sample = { fps_p50 = 58.5, fps_p95 = 44, memory_mb = 320.5, sample_window_s = 60 },
}

local FIXTURES = {}
local fixtureErrors = {}
for name, props in pairs(PROPS) do
	local event, err = Analytics.newEvent(CTX, name, props)
	if event ~= nil then
		FIXTURES[name] = event
	else
		fixtureErrors[#fixtureErrors + 1] = name .. ": " .. tostring(err)
	end
end

local function validEvent(name)
	local event = FIXTURES[name]
	assert(event ~= nil, "fixture ausente: " .. name)
	return clone(event)
end

-- ---------------------------------------------------------------- catalogo
check("catalogo: schema 1 e 31 eventos da taxonomia", function()
	assert(Analytics.SCHEMA_VERSION == 1, "schema_version deveria ser 1")
	local names = Analytics.eventNames()
	assert(#names == 31, "esperava 31 eventos: " .. tostring(#names))
	assert(#fixtureErrors == 0, "fixtures invalidas: " .. table.concat(fixtureErrors, " | "))
	assert(countKeys(FIXTURES) == 31, "fixtures: " .. tostring(countKeys(FIXTURES)))
	assert(Analytics.MAX_EVENTS_PER_SESSION == 200, "teto de eventos/sessao")
	assert(Analytics.MAX_CLIENT_EVENTS_PER_MINUTE == 10, "rate limit de cliente")
	assert(Analytics.MAX_FREE_STRING == 256, "limite de string livre")
	assert(Analytics.TICK_MS == 50, "tick de 50 ms")
end)

check("cada evento tem fixture e cada fixture tem evento", function()
	local fromCatalog = sortedKeys(Analytics.CATALOG)
	local fromFixtures = sortedKeys(PROPS)
	assert(
		fromCatalog == fromFixtures,
		"catalogo x fixture divergiram:\n" .. fromCatalog .. "\n" .. fromFixtures
	)
end)

check("funil canonico existe no catalogo", function()
	for _, name in ipairs(Analytics.FUNNEL) do
		assert(Analytics.CATALOG[name] ~= nil, "passo do funil fora do catalogo: " .. name)
		assert(FIXTURES[name] ~= nil, "passo do funil sem fixture: " .. name)
	end
end)

check("fixtures viram eventos validos", function()
	for name, event in pairs(FIXTURES) do
		local ok, err = Analytics.validate(event)
		assert(ok, name .. " invalido: " .. tostring(err))
	end
end)

-- ---------------------------------------------------------------- propriedades
check("toda propriedade obrigatoria e exigida", function()
	for name, entry in pairs(Analytics.CATALOG) do
		local base = FIXTURES[name]
		assert(base ~= nil, "sem fixture: " .. name)
		for _, item in ipairs(entry.required) do
			local broken = clone(base)
			broken[item.prop] = nil
			local ok, err = Analytics.validate(broken)
			assert(not ok, name .. " aceitou sem " .. item.prop)
			assert(
				string.find(tostring(err), item.prop, 1, true) ~= nil,
				name .. ": erro nao cita " .. item.prop .. ": " .. tostring(err)
			)
		end
	end
end)

check("propriedade com tipo errado e recusada", function()
	for name, entry in pairs(Analytics.CATALOG) do
		local base = FIXTURES[name]
		assert(base ~= nil, "sem fixture: " .. name)
		for _, item in ipairs(entry.required) do
			local broken = clone(base)
			broken[item.prop] = {}
			assert(not Analytics.validate(broken), name .. " aceitou tabela em " .. item.prop)
		end
	end
end)

check("campo desconhecido e recusado, inclusive propriedade de outro evento", function()
	local unknown = validEvent("session_start")
	unknown.extra = 1
	assert(not Analytics.validate(unknown), "aceitou campo desconhecido")

	local crossEvent = validEvent("session_start")
	crossEvent.battle_id = BATTLE_ID
	assert(not Analytics.validate(crossEvent), "aceitou propriedade de outro evento")
	assert(
		string.find(tostring(select(2, Analytics.validate(crossEvent))), "desconhecido", 1, true)
	)
end)

check("todo campo PII e recusado", function()
	local base = validEvent("purchase_complete")
	local count = 0
	for key in pairs(Analytics.PII_KEYS) do
		count += 1
		local dirty = clone(base)
		dirty[key] = "x"
		local ok, err = Analytics.validate(dirty)
		assert(not ok, "aceitou PII: " .. key)
		assert(
			string.find(tostring(err), "PII", 1, true) ~= nil,
			"erro de PII nao citou PII em " .. key .. ": " .. tostring(err)
		)
	end
	assert(count >= 10, "lista de PII pequena: " .. tostring(count))
end)

check("envelope: campo obrigatorio ausente e recusado", function()
	for _, item in ipairs(Analytics.ENVELOPE) do
		if item.required then
			local broken = validEvent("session_start")
			broken[item.field] = nil
			local ok, err = Analytics.validate(broken)
			assert(not ok, "aceitou sem " .. item.field)
			assert(
				string.find(tostring(err), item.field, 1, true) ~= nil,
				"erro nao cita " .. item.field .. ": " .. tostring(err)
			)
		end
	end
end)

check("envelope: enums, formatos e limites", function()
	local broken = {
		{ "platform", "xbox" },
		{ "device_tier", "ultra" },
		{ "locale", "pt_BR" },
		{ "player_id", "nao-hex" },
		{ "player_id", string.rep("a", 31) },
		{ "event_id", "nao-e-uuid" },
		{ "session_id", "123" },
		{ "server_id", "xyz" },
		{ "place_version", string.rep("a", 65) },
		{ "is_age_checked", "false" },
		{ "schema_version", 2 },
		{ "ts", 0 },
		{ "experiment", string.rep("a", 65) },
	}
	for _, case in ipairs(broken) do
		local event = validEvent("session_start")
		event[case[1]] = case[2]
		assert(not Analytics.validate(event), "aceitou " .. case[1] .. "=" .. tostring(case[2]))
	end
	local event = validEvent("session_start")
	event.schema_version = 0
	assert(not Analytics.validate(event), "aceitou schema_version 0")
end)

check("limites numericos e strings longas", function()
	local cases = {
		{ "session_start", "days_since_last_seen", -2 },
		{ "battle_finished", "seed", 4294967296 },
		{ "battle_finished", "seed", 42.5 },
		{ "battle_finished", "ticks", 0 },
		{ "battle_finished", "ticks", 1201 },
		{ "replay_watched", "pct", 1.1 },
		{ "gold_earned", "amount", 0 / 0 },
		{ "perf_sample", "fps_p50", math.huge },
		{ "offer_shown", "offer_id", string.rep("a", 65) },
		{ "purchase_failed", "reason", "" },
	}
	for _, case in ipairs(cases) do
		local event = validEvent(case[1])
		event[case[2]] = case[3]
		assert(not Analytics.validate(event), "aceitou " .. case[1] .. "." .. case[2])
	end
	local negativeDelta = validEvent("league_changed")
	assert(negativeDelta.delta == -3, "delta negativo deveria ser valido")
	assert(Analytics.validate(negativeDelta), "delta negativo recusado")
end)

check("lote: validateAll aponta o indice do invalido", function()
	local batch = {}
	for index = 1, 10 do
		batch[index] = clone(FIXTURES.session_start)
	end
	local ok, badIndex, badErr = Analytics.validateAll(batch)
	assert(ok and badIndex == nil and badErr == nil, "lote valido recusado")
	batch[3].is_returning = "sim"
	local okBad, badIndex2, badErr2 = Analytics.validateAll(batch)
	assert(not okBad, "lote invalido aceito")
	assert(badIndex2 == 3, "indice errado: " .. tostring(badIndex2))
	assert(type(badErr2) == "string", "erro do lote vazio")
end)

-- ---------------------------------------------------------------- motor
check("BattleResult expoe seed e simVersion 3 com o hash novo", function()
	local result = Core.Run(42)
	assert(result.hash == 2489780106, "hash mudou: " .. tostring(result.hash))
	assert(result.seed == 42, "seed ausente no resultado: " .. tostring(result.seed))
	assert(result.simVersion == Core.SIM_VERSION, "simVersion divergente")
	assert(Core.SIM_VERSION == 3, "simVersion deveria ser 3 (5 tipos)")

	local event, err = Analytics.battleFinished(CTX, BATTLE_ID, result)
	assert(event ~= nil, "evento de batalha invalido: " .. tostring(err))
	assert(event.battle_id == BATTLE_ID, "battle_id perdido")
	assert(event.seed == 42, "seed nao foi para o evento")
	assert(event.sim_version == Core.SIM_VERSION, "sim_version nao foi para o evento")
	assert(event.result_hash == 2489780106, "hash nao foi para o evento")
	assert(event.duration_ms == result.ticks * 50, "duracao derivada errada")
	assert(event.winner == result.winner and event.ticks == result.ticks, "resultado nao copiado")
end)

check("analytics nao altera o resultado da batalha", function()
	local before = Core.Run(42)
	local event = assert(Analytics.battleFinished(CTX, BATTLE_ID, before))
	assert(Analytics.validate(event), "evento invalido")
	local after = Core.Run(42)
	assert(before.hash == after.hash, "hash mudou depois do evento")
	assert(before.hash == 2489780106, "hash de referencia mudou")
	assert(before.winner == after.winner, "vencedor mudou")
	assert(before.ticks == after.ticks and before.leaked == after.leaked, "estado mudou")
	assert(before.wallHp == after.wallHp, "wallHp mudou")
	assert(
		select("#", Analytics.battleFinished(CTX, BATTLE_ID, before)) == 2,
		"contrato de retorno"
	)
end)

check("battle_started aceita muralha vazia (0 traps)", function()
	local event, err = Analytics.battleStarted(CTX, BATTLE_ID, 42, 3, 5, 0)
	assert(event ~= nil, "muralha vazia recusada: " .. tostring(err))
	assert(event.traps_count == 0, "traps_count")
	local empty = Core.Battle
		.new({
			seed = 42,
			simVersion = Core.SIM_VERSION,
			wall = { hp = 500, traps = {} },
			wave = { count = 70 },
		})
		:Run()
	assert(empty.ticks > 0 and empty.hash > 0, "batalha vazia invalida")
end)

check("eventos de batalha: started e divergence", function()
	local started, startErr = Analytics.battleStarted(CTX, BATTLE_ID, 42, Core.SIM_VERSION, 5, 5)
	assert(started ~= nil, "battle_started invalido: " .. tostring(startErr))
	assert(
		started.seed == 42 and started.grid_width == 5 and started.traps_count == 5,
		"props erradas"
	)

	local divergence, divergenceErr = Analytics.battleDivergence(CTX, BATTLE_ID, BATTLE_HASH, 7)
	assert(divergence ~= nil, "battle_divergence invalido: " .. tostring(divergenceErr))
	assert(
		divergence.expected_hash == BATTLE_HASH and divergence.actual_hash == 7,
		"hashes errados"
	)

	local wrongSeed, wrongSeedErr = Analytics.battleStarted(CTX, BATTLE_ID, -1, 1, 5, 5)
	assert(wrongSeed == nil and wrongSeedErr ~= nil, "aceitou seed negativa")
end)

check("newEvent recusa evento fora do catalogo", function()
	local event, err = Analytics.newEvent(CTX, "evento_inventado", {})
	assert(event == nil, "criou evento fora do catalogo")
	assert(err ~= nil and string.find(tostring(err), "desconhecido", 1, true) ~= nil, tostring(err))
end)

-- ---------------------------------------------------------------- servico da S7
local SERVICE_SALT = "test-salt-s7"
local PLAYER_ID = HASH32
local SERVER_ID = CODE_HASH

local function deepEqual(a, b)
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	for key, value in pairs(a) do
		if not deepEqual(value, b[key]) then
			return false
		end
	end
	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end
	return true
end

local function newClock(start)
	local value = start or 1762800000000
	return {
		now = function()
			return value
		end,
		advance = function(ms)
			value += ms
		end,
	}
end

local function newUuidFactory()
	local counter = 0
	return function()
		counter += 1
		return string.format("00000000-0000-4000-8000-%012d", counter)
	end
end

local function sessionFields(overrides)
	local fields = {
		player_id = PLAYER_ID,
		session_id = SESSION_ID,
		place_version = "0.1.0-s7",
		platform = "mobile",
		device_tier = "mid",
		locale = "pt-BR",
		is_age_checked = false,
		server_id = SERVER_ID,
		experiment = "s7=test",
		is_returning = false,
		days_since_last_seen = -1,
	}
	for key, value in pairs(overrides or {}) do
		fields[key] = value
	end
	return fields
end

local function newRecorder()
	local record = { batches = {}, events = {}, errors = {} }
	local sink = {
		name = "Recorder",
		write = function(events)
			for _, event in ipairs(events) do
				local ok, err = Analytics.validate(event)
				assert(ok, "sink recebeu evento invalido: " .. tostring(err))
				record.events[#record.events + 1] = event
			end
			record.batches[#record.batches + 1] = #events
			return true, nil
		end,
	}
	return sink, record
end

local function newService(options)
	options = options or {}
	local clock = options.clock or newClock()
	local sink, record = newRecorder()
	local service = AnalyticsService.new({
		types = Analytics,
		sink = options.sink or sink,
		now = clock.now,
		generateId = options.generateId or newUuidFactory(),
		flushIntervalMs = options.flushIntervalMs or 30000,
		maxBatch = options.maxBatch or 100,
		maxBuffer = options.maxBuffer or 500,
		maxClientEventsPerMinute = options.maxClientEventsPerMinute or 10,
		maxEventsPerSession = options.maxEventsPerSession or 200,
		onError = function(message)
			record.errors[#record.errors + 1] = message
		end,
	})
	return service, record, clock
end

check("servico: os 31 eventos do catalogo validam e chegam ao sink", function()
	local service, record = newService()
	local session, beginErr = service.beginSession(1, sessionFields())
	assert(session ~= nil, tostring(beginErr))
	local accepted = 0
	for _, name in ipairs(Analytics.eventNames()) do
		local event, err = service.emit(1, name, PROPS[name])
		assert(event ~= nil, name .. ": " .. tostring(err))
		accepted += 1
	end
	local flushed = service.flush("test")
	assert(flushed == accepted + 1, "flush deveria levar session_start + 31 eventos")
	assert(#record.events == accepted + 1, "sink recebeu " .. tostring(#record.events))
	for _, event in ipairs(record.events) do
		local ok, err = Analytics.validate(event)
		assert(ok, "evento invalido no sink: " .. tostring(err))
	end
	local stats = service.getStats()
	assert(stats.accepted == accepted + 1, "accepted=" .. tostring(stats.accepted))
	assert(stats.flushed == accepted + 1, "flushed=" .. tostring(stats.flushed))
	assert(stats.rejected == 0, "rejected=" .. tostring(stats.rejected))
	assert(stats.invalid == 0, "invalid=" .. tostring(stats.invalid))
	assert(#record.errors == 0, table.concat(record.errors, " | "))
end)

check("sink Null valida e descarta sem quebrar o fluxo", function()
	local service, record = newService({ sink = AnalyticsService.NullSink(Analytics) })
	assert(service.beginSession(1, sessionFields()) ~= nil, "beginSession")
	assert(service.emit(1, "dropin_shown", { ms_since_join = 10 }) ~= nil, "emit")
	assert(service.flush("test") == 2, "flush")
	local stats = service.getStats()
	assert(stats.flushed == 2 and stats.failed_batches == 0, "stats do sink Null")
	assert(#record.events == 0, "recorder nao deveria ser usado")
	local null = AnalyticsService.NullSink(Analytics)
	local ok, err = null.write({ { event_name = "evento_inventado" } })
	assert(not ok and err ~= nil, "Null aceitou evento invalido")
end)

check("lote: 100 eventos e 30 s disparam flush", function()
	local service, record, clock = newService()
	assert(service.beginSession(1, sessionFields()) ~= nil, "beginSession")
	for index = 1, 98 do
		assert(service.emit(1, "dropin_shown", { ms_since_join = index }) ~= nil, "emit 98")
	end
	assert(#record.events == 0, "flush antes de 100")
	assert(service.emit(1, "dropin_shown", { ms_since_join = 99 }) ~= nil, "emit 99")
	assert(#record.events == 100, "lote de 100")
	assert(record.batches[1] == 100, "batch=" .. tostring(record.batches[1]))
	clock.advance(30000)
	assert(service.emit(1, "dropin_shown", { ms_since_join = 100 }) ~= nil, "emit pos-lote")
	assert(#record.events == 100, "flush por tempo antes do tick")
	assert(service.tick() == 1, "tick deveria levar 1")
	assert(#record.events == 101, "evento do tick")
	assert(record.batches[2] == 1, "segundo batch")
end)

check("rate limit de cliente: 10/min e client_error uma vez", function()
	local service, record, clock = newService()
	assert(service.beginSession(1, sessionFields()) ~= nil, "beginSession")
	for index = 1, 10 do
		local event, err = service.emitClient(1, "client_error", {
			code = "ui_error",
			context_hash = CODE_HASH,
		})
		assert(event ~= nil, "client_error " .. tostring(index) .. ": " .. tostring(err))
	end
	local dropped, droppedErr = service.emitClient(1, "client_error", {
		code = "ui_error",
		context_hash = CODE_HASH,
	})
	assert(dropped == nil and droppedErr == "rate_limited", tostring(droppedErr))
	assert(service.getStats().rate_limited == 1, "rate_limited")
	local serverOnly, serverOnlyErr =
		service.emitClient(1, "battle_finished", PROPS.battle_finished)
	assert(serverOnly == nil and serverOnlyErr == "server_only", tostring(serverOnlyErr))
	assert(service.flush("test") > 0, "flush")
	local reports = 0
	for _, event in ipairs(record.events) do
		if event.event_name == "client_error" and event.code == "rate_limited" then
			reports += 1
		end
	end
	assert(reports == 1, "client_error(rate_limited)=" .. tostring(reports))
	clock.advance(60001)
	local again, againErr = service.emitClient(1, "client_error", {
		code = "ui_error",
		context_hash = CODE_HASH,
	})
	assert(again ~= nil, "janela nao reabriu: " .. tostring(againErr))
end)

check("idempotencia: event_id repetido nao duplica no sink", function()
	local service, record = newService()
	local event = assert(Analytics.newEvent(CTX, "session_start", PROPS.session_start))
	assert(service.emitEvent(event) ~= nil, "primeiro event_id")
	local duplicate, err = service.emitEvent(event)
	assert(duplicate == nil and err == "duplicate", tostring(err))
	service.flush("test")
	assert(#record.events == 1, "sink recebeu " .. tostring(#record.events))
	assert(service.getStats().duplicates == 1, "duplicates")
end)

check("teto de 200: funil/monetizacao passam, economia nao", function()
	local service = newService()
	assert(service.beginSession(1, sessionFields()) ~= nil, "beginSession")
	for _ = 1, 199 do
		assert(service.emit(1, "trap_placed", { trap_id = "archer", cell = "r1c3", cost = 40 }))
	end
	assert(service.getStats().accepted == 200, "accepted=" .. tostring(service.getStats().accepted))
	local blocked, blockedErr =
		service.emit(1, "trap_placed", { trap_id = "archer", cell = "r1c3", cost = 40 })
	assert(blocked == nil and blockedErr == "session_cap", tostring(blockedErr))
	local priority = service.emit(1, "purchase_complete", PROPS.purchase_complete)
	assert(priority ~= nil, "monetizacao deveria passar acima do teto")
	assert(service.getStats().session_capped == 1, "session_capped")
	local closing = service.endSession(1, "leave")
	assert(closing ~= nil, "session_end deveria passar acima do teto")
end)

check("session_end no leave: duration_s e flush", function()
	local service, record, clock = newService()
	assert(
		service.beginSession(1, sessionFields({ is_returning = true, days_since_last_seen = 1 }))
			~= nil,
		"beginSession"
	)
	clock.advance(12500)
	local event = assert(service.endSession(1, "leave"))
	assert(event.duration_s == 12.5, "duration_s=" .. tostring(event.duration_s))
	assert(service.getSession(1) == nil, "sessao deveria sumir")
	assert(#record.events == 2, "sink deveria ter start+end, tem " .. tostring(#record.events))
	assert(record.events[1].event_name == "session_start", "ordem start/end")
	assert(record.events[2].event_name == "session_end", "ordem start/end")
	local startEvent = record.events[1]
	assert(
		startEvent.is_returning == true and startEvent.days_since_last_seen == 1,
		"props do start"
	)
end)

check("first_win: uma vez por sessao e first_win_seconds medido", function()
	local service, record, clock = newService()
	assert(service.beginSession(1, sessionFields()) ~= nil, "beginSession")
	clock.advance(42500)
	local event = assert(service.emitFirstWin(1, BATTLE_ID))
	assert(event.seconds_since_join == 42.5, "seconds=" .. tostring(event.seconds_since_join))
	local duplicate, err = service.emitFirstWin(1, BATTLE_ID)
	assert(duplicate == nil and err == "already_won", tostring(err))
	service.flush("test")
	local firstWin, sessionStart = nil, nil
	for _, item in ipairs(record.events) do
		if item.event_name == "first_win" then
			firstWin = item
		elseif item.event_name == "session_start" then
			sessionStart = item
		end
	end
	assert(firstWin ~= nil and sessionStart ~= nil, "eventos start/first_win")
	assert(firstWin.ts - sessionStart.ts == 42500, "first_win_seconds != delta de ts")
	local report = service.getFirstWinReport()
	assert(report.new_players == 1, "new_players")
	assert(report.new_player_first_wins == 1, "new_player_first_wins")
	assert(report.new_player_under_60 == 1, "new_player_under_60")
	assert(report.rate_under_60 == 1, "rate")
	assert(report.passes_gate == true and report.gate == 0.70, "gate")
end)

check("P1: coorte sintetica de 10 novos mede 7/10 = 70%", function()
	local service, _record, clock = newService()
	for index = 1, 10 do
		local sessionId = string.format("10000000-0000-4000-8000-%012d", index)
		local session, beginErr = service.beginSession(
			index,
			sessionFields({
				session_id = sessionId,
				player_id = AnalyticsService.hashId("user-" .. tostring(index), SERVICE_SALT),
			})
		)
		assert(session ~= nil, tostring(beginErr))
		if index <= 7 then
			clock.advance(index * 7000)
			local win, winErr = service.emitFirstWin(index, string.format("battle-%d", index))
			assert(win ~= nil, tostring(winErr))
			assert(win.seconds_since_join == index * 7, "segundos inesperados")
		else
			clock.advance(70000)
		end
	end
	local report = service.getFirstWinReport()
	assert(report.new_players == 10, "new_players=" .. tostring(report.new_players))
	assert(report.new_player_first_wins == 7, "ganhos=" .. tostring(report.new_player_first_wins))
	assert(report.new_player_under_60 == 7, "under60=" .. tostring(report.new_player_under_60))
	assert(math.abs(report.rate_under_60 - 0.70) < 1e-9, "taxa=" .. tostring(report.rate_under_60))
	assert(report.passes_gate == true, "gate deveria passar com 70%")
	assert(report.p50_seconds ~= nil and report.p95_seconds ~= nil, "percentis")
	print(
		string.format(
			"[analytics] P1 coorte sintetica: %d/%d = %.0f%% <60s (gate %.0f%%); nao e medicao de produto",
			report.new_player_under_60,
			report.new_players,
			report.rate_under_60 * 100,
			report.gate * 100
		)
	)
end)

check("props nao podem sobrescrever o envelope", function()
	local service = newService()
	assert(service.beginSession(1, sessionFields()) ~= nil, "beginSession")
	local event, err = service.emit(1, "purchase_complete", {
		offer_id = "starter_pack",
		price_robux = 399,
		product_type = "gamepass",
		ts = 1,
	})
	assert(event == nil and string.find(tostring(err), "envelope", 1, true) ~= nil, tostring(err))
	assert(service.getStats().rejected == 1, "rejected")
end)

check("sem PII: player_id e hash32 e campo PII e recusado", function()
	local hash = AnalyticsService.hashId("123456", SERVICE_SALT)
	assert(#hash == 32, "hash deveria ter 32 hex: " .. tostring(#hash))
	assert(string.match(hash, "^[0-9a-f]+$") ~= nil, "hash fora do alfabeto hex")
	assert(hash ~= "123456", "UserId cru vazou")
	assert(AnalyticsService.hashId("123456", "outro-sal") ~= hash, "salt nao muda o hash")
	local service, record = newService()
	assert(service.beginSession(1, sessionFields({ player_id = hash })) ~= nil, "beginSession")
	local event, err = service.emit(1, "purchase_complete", {
		offer_id = "starter_pack",
		price_robux = 399,
		product_type = "gamepass",
		user_id = 123456,
	})
	assert(event == nil and string.find(tostring(err), "PII", 1, true) ~= nil, tostring(err))
	service.flush("test")
	assert(#record.events == 1, "sink deveria ter so session_start")
	assert(record.events[1].player_id == hash, "player_id do envelope")
	for key in pairs(Analytics.PII_KEYS) do
		assert(record.events[1][key] == nil, "PII no envelope: " .. tostring(key))
	end
end)

check("analytics nao altera BattleResult nem o hash", function()
	local before = Core.Run(42)
	local snapshot = clone(before)
	local service = newService()
	assert(service.beginSession(1, sessionFields()) ~= nil, "beginSession")
	assert(service.emit(1, "battle_started", PROPS.battle_started) ~= nil, "battle_started")
	assert(service.emit(1, "battle_finished", {
		battle_id = BATTLE_ID,
		seed = before.seed,
		sim_version = before.simVersion,
		result_hash = before.hash,
		winner = before.winner,
		wall_hp = before.wallHp,
		leaked = before.leaked,
		ticks = before.ticks,
		duration_ms = before.ticks * 50,
	}) ~= nil, "battle_finished")
	service.flush("test")
	assert(deepEqual(before, snapshot), "o servico mutou o BattleResult")
	local after = Core.Run(42)
	assert(deepEqual(before, after), "hash/resultado mudou depois do evento")
	assert(after.hash == 2489780106, "hash de referencia mudou")
end)

check("servico sem boot recusa sem quebrar", function()
	local event, err = AnalyticsService.emit("jogador", "session_start", PROPS.session_start)
	assert(event == nil and err == "not_started", tostring(err))
	assert(AnalyticsService.flush("test") == 0, "flush sem servico")
	assert(AnalyticsService.getStats() == nil, "stats sem servico")
end)

print(string.format("contrato de analytics: %d checagens, %d falhas", checks, #failures))
if #failures > 0 then
	for _, failure in ipairs(failures) do
		print("  FALHOU: " .. failure)
	end
	error("contrato de analytics quebrado")
end
print("OK: contrato de analytics passou")
