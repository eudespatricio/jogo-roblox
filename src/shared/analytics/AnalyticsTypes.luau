--!strict
-- Contrato de analytics v1: envelope, catalogo de eventos, limites e anti-PII.
-- Fonte de verdade: docs/taxonomia-analytics.md (aprovada em 09/11/2026).
-- Puro Luau (nenhuma API do Roblox): o validador roda no CLI em sim/analytics-contract.luau
-- e no servidor. Analytics nunca entra no estado da simulacao nem no hash: o servidor emite
-- `battle_finished` DEPOIS de calcular o BattleResult.

local AnalyticsTypes = {}

AnalyticsTypes.SCHEMA_VERSION = 1
AnalyticsTypes.MAX_EVENT_NAME = 48
AnalyticsTypes.MAX_FREE_STRING = 256
AnalyticsTypes.MAX_EXPERIMENT = 64
AnalyticsTypes.MAX_PLACE_VERSION = 64
AnalyticsTypes.MAX_EVENTS_PER_SESSION = 200
AnalyticsTypes.MAX_CLIENT_EVENTS_PER_MINUTE = 10
AnalyticsTypes.TICK_MS = 50 -- 20 Hz fixo do motor
AnalyticsTypes.UINT32_MAX = 4294967295

export type PropKind = "integer" | "number" | "string" | "boolean" | "enum"

export type PropSpec = {
	kind: PropKind,
	min: number?,
	max: number?,
	maxLen: number?,
	format: ("uuid" | "hash32" | "locale" | "id")?,
	values: { [string]: boolean }?,
}

export type Prop = { prop: string, spec: PropSpec }

export type CatalogEntry = {
	required: { Prop },
	optional: { Prop },
	allowed: { [string]: boolean }?,
}

local function int(min: number?, max: number?): PropSpec
	return { kind = "integer", min = min, max = max }
end

local function num(min: number?, max: number?): PropSpec
	return { kind = "number", min = min, max = max }
end

local function str(maxLen: number?, format: ("uuid" | "hash32" | "locale" | "id")?): PropSpec
	return { kind = "string", maxLen = maxLen, format = format }
end

local function bool(): PropSpec
	return { kind = "boolean" }
end

local function oneOf(values: { string }): PropSpec
	local set: { [string]: boolean } = {}
	for _, value in ipairs(values) do
		set[value] = true
	end
	return { kind = "enum", values = set }
end

local function prop(name: string, spec: PropSpec): Prop
	return { prop = name, spec = spec }
end

local function catalogEvent(required: { Prop }, optional: { Prop }?): CatalogEntry
	return { required = required, optional = optional or {} }
end

-- Campos proibidos: o validador recusa o evento inteiro. player_id e hash, nunca UserId cru.
AnalyticsTypes.PII_KEYS = {
	address = true,
	age = true,
	birthdate = true,
	birthday = true,
	chat = true,
	cookie = true,
	device_id = true,
	discord = true,
	display_name = true,
	email = true,
	hardware_id = true,
	ip = true,
	message = true,
	name = true,
	password = true,
	phone = true,
	player_name = true,
	token = true,
	user_id = true,
	userid = true,
	username = true,
}

local PLATFORMS = { "mobile", "pc", "console", "vr" }
local DEVICE_TIERS = { "low", "mid", "high" }
local WINNERS = { "defender", "attacker" }

-- Envelope comum (taxonomia §1). A ordem importa: a mensagem de erro e deterministica.
export type EnvelopeField = { field: string, spec: PropSpec, required: boolean }

local ENVELOPE: { EnvelopeField } = {
	{ field = "event_id", spec = str(36, "uuid"), required = true },
	{ field = "event_name", spec = str(AnalyticsTypes.MAX_EVENT_NAME, "id"), required = true },
	{ field = "schema_version", spec = int(0, nil), required = true },
	{ field = "ts", spec = int(1, nil), required = true },
	{ field = "session_id", spec = str(36, "uuid"), required = true },
	{ field = "player_id", spec = str(32, "hash32"), required = true },
	{
		field = "place_version",
		spec = str(AnalyticsTypes.MAX_PLACE_VERSION, "id"),
		required = true,
	},
	{ field = "platform", spec = oneOf(PLATFORMS), required = true },
	{ field = "device_tier", spec = oneOf(DEVICE_TIERS), required = true },
	{ field = "locale", spec = str(5, "locale"), required = true },
	{ field = "is_age_checked", spec = bool(), required = true },
	{ field = "server_id", spec = str(32, "hash32"), required = true },
	{ field = "experiment", spec = str(AnalyticsTypes.MAX_EXPERIMENT, "id"), required = false },
	{ field = "client_ts", spec = int(1, nil), required = false },
}

-- Catalogo da taxonomia §2. `required` e o que o evento precisa carregar; `optional` e
-- permitido mas nao exigido. Campo fora do catalogo e recusado.
local CATALOG: { [string]: CatalogEntry } = {
	-- 2.1 sessao e funil
	session_start = catalogEvent({
		prop("days_since_last_seen", int(-1, nil)),
		prop("is_returning", bool()),
	}),
	session_end = catalogEvent({
		prop("duration_s", num(0, nil)),
		prop("reason", oneOf({ "leave", "crash", "timeout" })),
	}),
	dropin_shown = catalogEvent({
		prop("ms_since_join", int(0, nil)),
	}),
	dropin_pressed = catalogEvent({
		prop("ms_since_join", int(0, nil)),
		prop("pressed", bool()),
	}),
	first_win = catalogEvent({
		prop("seconds_since_join", num(0, nil)),
		prop("battle_id", str(64, "id")),
	}),
	build_complete = catalogEvent({
		prop("traps_placed", int(0, 25)),
		prop("time_s", num(0, nil)),
	}),
	raid_start = catalogEvent({
		prop("battle_id", str(64, "id")),
		prop("mode", str(32, "id")),
		prop("speed", num(0, nil)),
	}),
	raid_end = catalogEvent({
		prop("battle_id", str(64, "id")),
		prop("result", oneOf(WINNERS)),
		prop("duration_s", num(0, nil)),
	}),
	replay_started = catalogEvent({
		prop("battle_id", str(64, "id")),
		prop("replay_length_s", num(0, nil)),
	}),
	replay_watched = catalogEvent({
		prop("battle_id", str(64, "id")),
		prop("watched_s", num(0, nil)),
		prop("pct", num(0, 1)),
	}),
	clip_saved = catalogEvent({
		prop("battle_id", str(64, "id")),
	}),
	-- 2.2 batalha e determinismo
	battle_started = catalogEvent({
		prop("battle_id", str(64, "id")),
		prop("seed", int(0, AnalyticsTypes.UINT32_MAX)),
		prop("sim_version", int(1, nil)),
		prop("grid_width", int(5, 7)),
		-- 0 e valido: raid contra muralha vazia (o motor aceita wall.traps = {}).
		prop("traps_count", int(0, 25)),
	}),
	battle_finished = catalogEvent({
		prop("battle_id", str(64, "id")),
		prop("seed", int(0, AnalyticsTypes.UINT32_MAX)),
		prop("sim_version", int(1, nil)),
		prop("result_hash", int(0, AnalyticsTypes.UINT32_MAX)),
		prop("winner", oneOf(WINNERS)),
		prop("wall_hp", int(0, nil)),
		prop("leaked", int(0, nil)),
		prop("ticks", int(1, 1200)),
		prop("duration_ms", int(1, nil)),
	}),
	battle_divergence = catalogEvent({
		prop("battle_id", str(64, "id")),
		prop("expected_hash", int(0, AnalyticsTypes.UINT32_MAX)),
		prop("actual_hash", int(0, AnalyticsTypes.UINT32_MAX)),
	}),
	-- 2.3 economia e progressao
	gold_earned = catalogEvent({
		prop("amount", int(0, nil)),
		prop("source", oneOf({ "raid", "defense", "daily" })),
	}, {
		prop("battle_id", str(64, "id")),
	}),
	gold_spent = catalogEvent({
		prop("amount", int(0, nil)),
		prop("sink", oneOf({ "trap", "upgrade", "repair" })),
	}),
	trap_placed = catalogEvent({
		prop("trap_id", str(32, "id")),
		prop("cell", str(16, "id")),
		prop("cost", int(0, nil)),
	}),
	upgrade_bought = catalogEvent({
		prop("target", str(64, "id")),
		prop("level", int(1, 5)),
		prop("cost", int(0, nil)),
	}),
	league_changed = catalogEvent({
		prop("from", int(0, nil)),
		prop("to", int(0, nil)),
		prop("delta", int(nil, nil)),
	}),
	blueprint_earned = catalogEvent({
		prop("blueprint_id", str(32, "id")),
		prop("rarity", str(32, "id")),
		prop("source", str(32, "id")),
	}),
	-- 2.4 monetizacao
	offer_shown = catalogEvent({
		prop("offer_id", str(64, "id")),
		prop("price_robux", int(0, nil)),
		prop("placement", str(32, "id")),
	}),
	purchase_start = catalogEvent({
		prop("offer_id", str(64, "id")),
		prop("price_robux", int(0, nil)),
	}),
	purchase_complete = catalogEvent({
		prop("offer_id", str(64, "id")),
		prop("price_robux", int(0, nil)),
		prop("product_type", str(32, "id")),
	}),
	purchase_failed = catalogEvent({
		prop("offer_id", str(64, "id")),
		prop("reason", str(32, "id")),
	}),
	age_check_prompt = catalogEvent({
		prop("origin", oneOf({ "reward", "store", "settings" })),
	}),
	age_check_result = catalogEvent({
		prop("result", oneOf({ "verified", "declined", "unavailable" })),
	}),
	-- 2.5 teste de 3 semanas
	test_offer_choice = catalogEvent({
		prop("offer_id", str(64, "id")),
		prop("choice", bool()),
		prop("reason_code", oneOf({ "colecao", "ranking", "revanche", "preco", "nao_jogaria" })),
	}),
	test_survey_answer = catalogEvent({
		prop("question_id", str(32, "id")),
		prop("answer_code", str(32, "id")),
	}),
	-- 2.6 qualidade
	client_error = catalogEvent({
		prop("code", str(32, "id")),
		prop("context_hash", str(32, "hash32")),
	}),
	server_error = catalogEvent({
		prop("code", str(32, "id")),
		prop("context_hash", str(32, "hash32")),
	}),
	perf_sample = catalogEvent({
		prop("fps_p50", num(0, nil)),
		prop("fps_p95", num(0, nil)),
		prop("memory_mb", num(0, nil)),
		prop("sample_window_s", num(0, nil)),
	}),
}

-- Funil canonico (taxonomia §3). O contrato garante que todo passo existe no catalogo.
AnalyticsTypes.FUNNEL = {
	"session_start",
	"dropin_shown",
	"dropin_pressed",
	"first_win",
	"build_complete",
	"raid_start",
	"raid_end",
	"replay_watched",
}

local ENVELOPE_SET: { [string]: boolean } = {}
for _, item in ipairs(ENVELOPE) do
	ENVELOPE_SET[item.field] = true
end

local function buildAllowed(entry: CatalogEntry): { [string]: boolean }
	local allowed: { [string]: boolean } = {}
	for field in pairs(ENVELOPE_SET) do
		allowed[field] = true
	end
	for _, item in ipairs(entry.required) do
		allowed[item.prop] = true
	end
	for _, item in ipairs(entry.optional) do
		allowed[item.prop] = true
	end
	entry.allowed = allowed
	return allowed
end

for _, entry in pairs(CATALOG) do
	buildAllowed(entry)
end

AnalyticsTypes.CATALOG = CATALOG
AnalyticsTypes.ENVELOPE = ENVELOPE

-- ---------------------------------------------------------------- formatos
local function isHexRun(value: string, from: number, to: number): boolean
	for index = from, to do
		local byte = string.byte(value, index)
		local digit = byte ~= nil and byte >= 48 and byte <= 57
		local lower = byte ~= nil and byte >= 97 and byte <= 102
		local upper = byte ~= nil and byte >= 65 and byte <= 70
		if not (digit or lower or upper) then
			return false
		end
	end
	return true
end

local function isUuid(value: string): boolean
	if #value ~= 36 then
		return false
	end
	if
		string.sub(value, 9, 9) ~= "-"
		or string.sub(value, 14, 14) ~= "-"
		or string.sub(value, 19, 19) ~= "-"
		or string.sub(value, 24, 24) ~= "-"
	then
		return false
	end
	if not isHexRun(value, 1, 8) or not isHexRun(value, 10, 13) or not isHexRun(value, 15, 18) then
		return false
	end
	if not isHexRun(value, 20, 23) or not isHexRun(value, 25, 36) then
		return false
	end
	if string.sub(value, 15, 15) ~= "4" then
		return false
	end
	local variant = string.lower(string.sub(value, 20, 20))
	return variant == "8" or variant == "9" or variant == "a" or variant == "b"
end

local function isHash32(value: string): boolean
	if #value ~= 32 then
		return false
	end
	for index = 1, 32 do
		local byte = string.byte(value, index)
		local digit = byte ~= nil and byte >= 48 and byte <= 57
		local letter = byte ~= nil and byte >= 97 and byte <= 102
		if not (digit or letter) then
			return false
		end
	end
	return true
end

local function isLocale(value: string): boolean
	if #value ~= 5 or string.sub(value, 3, 3) ~= "-" then
		return false
	end
	for index = 1, 2 do
		local byte = string.byte(value, index)
		if byte == nil or byte < 97 or byte > 122 then
			return false
		end
	end
	for index = 4, 5 do
		local byte = string.byte(value, index)
		if byte == nil or byte < 65 or byte > 90 then
			return false
		end
	end
	return true
end

-- Ids sao ASCII: letra, numero, `_ . : = , -`. Byte a byte para nao depender de pattern.
local function isId(value: string): boolean
	if #value == 0 then
		return false
	end
	for index = 1, #value do
		local byte = string.byte(value, index) or 0
		local alnum = (byte >= 48 and byte <= 57)
			or (byte >= 65 and byte <= 90)
			or (byte >= 97 and byte <= 122)
		local allowed = alnum
			or byte == 95 -- _
			or byte == 46 -- .
			or byte == 58 -- :
			or byte == 61 -- =
			or byte == 44 -- ,
			or byte == 45 -- -
		if not allowed then
			return false
		end
	end
	return true
end

-- ---------------------------------------------------------------- validacao
local function checkSpec(value: any, spec: PropSpec, path: string): (boolean, string?)
	if spec.kind == "boolean" then
		if type(value) ~= "boolean" then
			return false, path .. ": esperava boolean"
		end
		return true, nil
	end
	if spec.kind == "integer" or spec.kind == "number" then
		if type(value) ~= "number" then
			return false, path .. ": esperava number"
		end
		local amount = value :: number
		if amount ~= amount then
			return false, path .. ": NaN"
		end
		if amount == math.huge or amount == -math.huge then
			return false, path .. ": infinito"
		end
		if spec.kind == "integer" and amount % 1 ~= 0 then
			return false, path .. ": esperava inteiro"
		end
		if spec.min ~= nil and amount < (spec.min :: number) then
			return false, path .. ": abaixo do minimo " .. tostring(spec.min)
		end
		if spec.max ~= nil and amount > (spec.max :: number) then
			return false, path .. ": acima do maximo " .. tostring(spec.max)
		end
		return true, nil
	end
	if type(value) ~= "string" then
		return false, path .. ": esperava string"
	end
	local text = value :: string
	local maxLen = spec.maxLen or AnalyticsTypes.MAX_FREE_STRING
	if #text == 0 then
		return false, path .. ": string vazia"
	end
	if #text > maxLen then
		return false, path .. ": acima de " .. tostring(maxLen) .. " caracteres"
	end
	if spec.kind == "enum" then
		local values = spec.values
		if values == nil or values[text] ~= true then
			return false, path .. ": valor fora do enum"
		end
		return true, nil
	end
	if spec.format == "uuid" and not isUuid(text) then
		return false, path .. ": UUID v4 invalido"
	end
	if spec.format == "hash32" and not isHash32(text) then
		return false, path .. ": hash de 32 hex esperado"
	end
	if spec.format == "locale" and not isLocale(text) then
		return false, path .. ": locale invalido (ex.: pt-BR)"
	end
	if spec.format == "id" and not isId(text) then
		return false, path .. ": id com caractere invalido"
	end
	return true, nil
end

-- Valida um evento inteiro. Retorna (ok, erro) em vez de lancar: o sink decide o que fazer.
function AnalyticsTypes.validate(event: any): (boolean, string?)
	if type(event) ~= "table" then
		return false, "evento nao e tabela"
	end
	local name = event.event_name
	if type(name) ~= "string" then
		return false, "envelope: falta event_name"
	end
	local entry = CATALOG[name :: string]
	if entry == nil then
		return false, "event_name desconhecido: " .. tostring(name)
	end
	-- PII antes de campo desconhecido: a mensagem tem que dizer que o problema e PII
	for key in pairs(event) do
		if type(key) == "string" and AnalyticsTypes.PII_KEYS[string.lower(key :: string)] then
			return false, "campo PII proibido: " .. tostring(key)
		end
	end
	for _, item in ipairs(ENVELOPE) do
		local value = event[item.field]
		if value == nil then
			if item.required then
				return false, "envelope: falta " .. item.field
			end
		else
			local ok, err = checkSpec(value, item.spec, item.field)
			if not ok then
				return false, err
			end
		end
	end
	if event.schema_version ~= AnalyticsTypes.SCHEMA_VERSION then
		return false, "schema_version != " .. tostring(AnalyticsTypes.SCHEMA_VERSION)
	end
	for _, item in ipairs(entry.required) do
		local value = event[item.prop]
		if value == nil then
			return false, "propriedade obrigatoria ausente: " .. item.prop
		end
		local ok, err = checkSpec(value, item.spec, item.prop)
		if not ok then
			return false, err
		end
	end
	for _, item in ipairs(entry.optional) do
		local value = event[item.prop]
		if value ~= nil then
			local ok, err = checkSpec(value, item.spec, item.prop)
			if not ok then
				return false, err
			end
		end
	end
	local allowed = entry.allowed :: { [string]: boolean }
	for key in pairs(event) do
		if type(key) ~= "string" then
			return false, "chave nao-string no evento"
		end
		if allowed[key :: string] ~= true then
			return false, "campo desconhecido: " .. tostring(key)
		end
	end
	return true, nil
end

-- Valida um lote (buffer do sink) e devolve o indice do primeiro invalido.
function AnalyticsTypes.validateAll(events: { any }): (boolean, number?, string?)
	for index, event in ipairs(events) do
		local ok, err = AnalyticsTypes.validate(event)
		if not ok then
			return false, index, err
		end
	end
	return true, nil, nil
end

-- ---------------------------------------------------------------- construcao de eventos
export type Ctx = {
	event_id: string,
	ts: number,
	session_id: string,
	player_id: string,
	place_version: string,
	platform: string,
	device_tier: string,
	locale: string,
	is_age_checked: boolean,
	server_id: string,
	experiment: string?,
	client_ts: number?,
}

export type BattleResult = {
	seed: number,
	simVersion: number,
	hash: number,
	winner: string,
	wallHp: number,
	leaked: number,
	ticks: number,
}

-- Monta o envelope + propriedades e valida. `event_id`, `ts` e `session_id` vem do chamador
-- (servidor) para o teste ser deterministico. Devolve (evento, nil) ou (nil, erro).
function AnalyticsTypes.newEvent(
	ctx: Ctx,
	eventName: string,
	props: { [string]: any }?
): (any?, string?)
	local event: { [string]: any } = {
		event_id = ctx.event_id,
		event_name = eventName,
		schema_version = AnalyticsTypes.SCHEMA_VERSION,
		ts = ctx.ts,
		session_id = ctx.session_id,
		player_id = ctx.player_id,
		place_version = ctx.place_version,
		platform = ctx.platform,
		device_tier = ctx.device_tier,
		locale = ctx.locale,
		is_age_checked = ctx.is_age_checked,
		server_id = ctx.server_id,
	}
	if ctx.experiment ~= nil then
		event.experiment = ctx.experiment
	end
	if ctx.client_ts ~= nil then
		event.client_ts = ctx.client_ts
	end
	if props ~= nil then
		for key, value in pairs(props) do
			event[key] = value
		end
	end
	local ok, err = AnalyticsTypes.validate(event)
	if not ok then
		return nil, err
	end
	return event, nil
end

function AnalyticsTypes.battleStarted(
	ctx: Ctx,
	battleId: string,
	seed: number,
	simVersion: number,
	gridWidth: number,
	trapsCount: number
): (any?, string?)
	return AnalyticsTypes.newEvent(ctx, "battle_started", {
		battle_id = battleId,
		seed = seed,
		sim_version = simVersion,
		grid_width = gridWidth,
		traps_count = trapsCount,
	})
end

-- Emitido DEPOIS do hash. Lê o resultado e nao toca nele: o hash nao pode mudar.
function AnalyticsTypes.battleFinished(
	ctx: Ctx,
	battleId: string,
	result: BattleResult
): (any?, string?)
	return AnalyticsTypes.newEvent(ctx, "battle_finished", {
		battle_id = battleId,
		seed = result.seed,
		sim_version = result.simVersion,
		result_hash = result.hash,
		winner = result.winner,
		wall_hp = result.wallHp,
		leaked = result.leaked,
		ticks = result.ticks,
		duration_ms = result.ticks * AnalyticsTypes.TICK_MS,
	})
end

function AnalyticsTypes.battleDivergence(
	ctx: Ctx,
	battleId: string,
	expectedHash: number,
	actualHash: number
): (any?, string?)
	return AnalyticsTypes.newEvent(ctx, "battle_divergence", {
		battle_id = battleId,
		expected_hash = expectedHash,
		actual_hash = actualHash,
	})
end

-- Nomes do catalogo em ordem alfabetica: teste de paridade com a taxonomia e com os fixtures.
function AnalyticsTypes.eventNames(): { string }
	local names: { string } = {}
	for name in pairs(CATALOG) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

return AnalyticsTypes
