--!strict
-- Servico de analytics da S7: envelope v1, lote (30 s/100), rate limit de cliente (10/min),
-- idempotencia por event_id e sink Null. Puro Luau (nenhuma API do Roblox): o boot
-- (AnalyticsBoot.server.luau) injeta relogio/UUID/contexto e o contrato roda no CLI
-- (sim/analytics-contract.luau). Nada aqui toca o motor: eventos de batalha sao montados
-- DEPOIS do hash e nao entram no BattleResult.
--
-- Regras da taxonomia v1 (docs/taxonomia-analytics.md):
--   * todo evento e validado antes de entrar no buffer; invalido e descartado;
--   * lote sai a cada 30 s ou 100 eventos, e no leave (best effort, nunca bloqueia gameplay);
--   * cliente tem 10 eventos/min; o excedente vira client_error(code=rate_limited) uma vez;
--   * teto de 200 eventos/sessao; acima disso so funil e monetizacao;
--   * event_id e unico (idempotencia) e player_id e hash de 32 hex, nunca UserId cru.

local AnalyticsService = {}

AnalyticsService.SCHEMA_VERSION = 1
AnalyticsService.FLUSH_INTERVAL_MS = 30000
AnalyticsService.MAX_BATCH = 100
AnalyticsService.MAX_BUFFER = 500
AnalyticsService.MAX_EVENT_ID_MEMORY = 4096
AnalyticsService.CLIENT_WINDOW_MS = 60000
AnalyticsService.MAX_CLIENT_EVENTS_PER_MINUTE = 10
AnalyticsService.MAX_EVENTS_PER_SESSION = 200
AnalyticsService.FIRST_WIN_WINDOW_SECONDS = 60
AnalyticsService.FIRST_WIN_GATE = 0.70

export type Sink = {
	name: string,
	write: (events: { any }) -> (boolean, string?),
}

export type Options = {
	types: any,
	sink: Sink?,
	now: () -> number,
	generateId: () -> string,
	flushIntervalMs: number?,
	maxBatch: number?,
	maxBuffer: number?,
	maxClientEventsPerMinute: number?,
	maxEventsPerSession: number?,
	maxEventIdMemory: number?,
	onError: ((message: string) -> ())?,
	onFlush: ((events: { any }, reason: string) -> ())?,
	onEvent: ((event: any) -> ())?,
}

export type SessionFields = {
	player_id: string,
	session_id: string,
	place_version: string,
	platform: string,
	device_tier: string,
	locale: string,
	is_age_checked: boolean,
	server_id: string,
	experiment: string?,
	is_returning: boolean,
	days_since_last_seen: number,
}

export type Stats = {
	attempts: number,
	accepted: number,
	rejected: number,
	duplicates: number,
	rate_limited: number,
	session_capped: number,
	dropped: number,
	flushed: number,
	batches: number,
	failed_batches: number,
	invalid: number,
	sessions: number,
	buffer: number,
}

export type FirstWinReport = {
	sessions: number,
	new_players: number,
	new_player_first_wins: number,
	new_player_under_60: number,
	first_wins: number,
	rate_under_60: number,
	p50_seconds: number?,
	p95_seconds: number?,
	gate: number,
	passes_gate: boolean,
}

export type Session = {
	player: any,
	player_id: string,
	session_id: string,
	place_version: string,
	platform: string,
	device_tier: string,
	locale: string,
	is_age_checked: boolean,
	server_id: string,
	experiment: string?,
	is_returning: boolean,
	started_at: number,
	event_count: number,
	first_win: boolean,
	first_win_seconds: number?,
	client_times: { number },
	rate_limit_reported_at: number?,
}

export type Controller = {
	beginSession: (player: any, fields: SessionFields) -> (Session?, string?),
	endSession: (player: any, reason: string?) -> (any?, string?),
	emit: (player: any, name: string, props: { [string]: any }?) -> (any?, string?),
	emitClient: (player: any, name: string, props: { [string]: any }?) -> (any?, string?),
	emitEvent: (event: any) -> (any?, string?),
	emitFirstWin: (player: any, battleId: string) -> (any?, string?),
	flush: (reason: string?) -> number,
	tick: () -> number,
	getSession: (player: any) -> Session?,
	getStats: () -> Stats,
	getFirstWinReport: () -> FirstWinReport,
	stop: () -> (),
}

local CLIENT_EVENTS: { [string]: boolean } = {
	client_error = true,
	clip_saved = true,
	offer_shown = true,
	purchase_start = true,
	replay_started = true,
	replay_watched = true,
}

local MONETIZATION_EVENTS: { [string]: boolean } = {
	age_check_prompt = true,
	age_check_result = true,
	offer_shown = true,
	purchase_complete = true,
	purchase_failed = true,
	purchase_start = true,
}

local FUNNEL_SET: { [string]: boolean } = {}

AnalyticsService.ENVELOPE_FIELDS = {
	event_id = true,
	event_name = true,
	schema_version = true,
	ts = true,
	session_id = true,
	player_id = true,
	place_version = true,
	platform = true,
	device_tier = true,
	locale = true,
	is_age_checked = true,
	server_id = true,
	experiment = true,
	client_ts = true,
} :: { [string]: boolean }

-- 128 bits em 4 rodadas de FNV-1a de 32 bits; player_id/server_id nunca sao o UserId/JobId cru.
local function add32(a: number, b: number): number
	local sum = a + b
	if sum >= 4294967296 then
		sum -= 4294967296
	end
	return sum
end

local function mul32(a: number, b: number): number
	a = bit32.band(a, 0xFFFFFFFF)
	b = bit32.band(b, 0xFFFFFFFF)
	local a0 = bit32.band(a, 0xFFFF)
	local a1 = bit32.rshift(a, 16)
	local b0 = bit32.band(b, 0xFFFF)
	local b1 = bit32.rshift(b, 16)
	local mid = bit32.band(a0 * b1 + a1 * b0, 0xFFFF)
	return add32(a0 * b0, mid * 65536)
end

local function hash32(text: string, seed: number): number
	local value = bit32.band(seed, 0xFFFFFFFF)
	for index = 1, #text do
		value = bit32.bxor(value, string.byte(text, index) or 0)
		value = mul32(value, 16777619)
	end
	value = bit32.bxor(value, bit32.rshift(value, 16))
	value = mul32(value, 2246822507)
	value = bit32.bxor(value, bit32.rshift(value, 13))
	value = mul32(value, 3266489909)
	value = bit32.bxor(value, bit32.rshift(value, 16))
	return value
end

-- Hash estavel de 32 hex (aceito pelo envelope como player_id/server_id/context_hash).
function AnalyticsService.hashId(value: string, salt: string?): string
	local key = tostring(salt or "muralha")
	local text = key .. "|" .. tostring(value)
	local parts = {}
	for round = 1, 4 do
		local seed = add32(2166136261, ((round - 1) * 2654435761) % 4294967296)
		parts[round] = string.format("%08x", hash32(text .. "|" .. tostring(round), seed))
	end
	return table.concat(parts)
end

-- Sink Null: valida o lote de novo (defesa em profundidade) e descarta. Nada persiste.
function AnalyticsService.NullSink(types: any): Sink
	return {
		name = "Null",
		write = function(events: { any }): (boolean, string?)
			local ok, index, err = types.validateAll(events)
			if not ok then
				return false, "lote invalido em " .. tostring(index) .. ": " .. tostring(err)
			end
			return true, nil
		end,
	}
end

function AnalyticsService.new(options: Options): Controller
	assert(type(options) == "table", "AnalyticsService.new: options ausente")
	assert(options.types ~= nil, "AnalyticsService.new: types ausente")
	assert(type(options.now) == "function", "AnalyticsService.new: now ausente")
	assert(type(options.generateId) == "function", "AnalyticsService.new: generateId ausente")

	local types = options.types
	local sink = options.sink
	local now = options.now
	local generateId = options.generateId
	local flushIntervalMs = options.flushIntervalMs or AnalyticsService.FLUSH_INTERVAL_MS
	local maxBatch = options.maxBatch or AnalyticsService.MAX_BATCH
	local maxBuffer = options.maxBuffer or AnalyticsService.MAX_BUFFER
	local maxClient = options.maxClientEventsPerMinute
		or types.MAX_CLIENT_EVENTS_PER_MINUTE
		or AnalyticsService.MAX_CLIENT_EVENTS_PER_MINUTE
	local maxEvents = options.maxEventsPerSession
		or types.MAX_EVENTS_PER_SESSION
		or AnalyticsService.MAX_EVENTS_PER_SESSION
	local maxEventIdMemory = options.maxEventIdMemory or AnalyticsService.MAX_EVENT_ID_MEMORY
	local onError = options.onError
	local onFlush = options.onFlush
	local onEvent = options.onEvent

	if flushIntervalMs < 1 then
		flushIntervalMs = AnalyticsService.FLUSH_INTERVAL_MS
	end
	if maxBatch < 1 then
		maxBatch = AnalyticsService.MAX_BATCH
	end
	if maxBuffer < maxBatch then
		maxBuffer = maxBatch
	end
	if maxClient < 1 then
		maxClient = AnalyticsService.MAX_CLIENT_EVENTS_PER_MINUTE
	end
	if maxEvents < 1 then
		maxEvents = AnalyticsService.MAX_EVENTS_PER_SESSION
	end
	if maxEventIdMemory < 1 then
		maxEventIdMemory = AnalyticsService.MAX_EVENT_ID_MEMORY
	end

	for _, name in ipairs(types.FUNNEL or {}) do
		FUNNEL_SET[name] = true
	end

	local sessions: { [any]: Session } = {}
	local sessionsById: { [string]: Session } = {}
	local buffer: { any } = {}
	local seenIds: { [string]: boolean } = {}
	local seenOrder: { string } = {}
	local stopped = false
	local lastFlushAt = now()

	local stats: Stats = {
		attempts = 0,
		accepted = 0,
		rejected = 0,
		duplicates = 0,
		rate_limited = 0,
		session_capped = 0,
		dropped = 0,
		flushed = 0,
		batches = 0,
		failed_batches = 0,
		invalid = 0,
		sessions = 0,
		buffer = 0,
	}

	local metrics = {
		sessions = 0,
		new_players = 0,
		first_wins = 0,
		new_player_first_wins = 0,
		new_player_under_60 = 0,
		seconds = {},
	}

	local function reportError(message: string): ()
		if onError ~= nil then
			local ok, err = pcall(function()
				onError(message)
				return nil
			end)
			if not ok then
				print("[analytics] onError falhou: " .. tostring(err))
			end
		end
	end

	local function remember(eventId: string): boolean
		if seenIds[eventId] == true then
			return false
		end
		seenIds[eventId] = true
		seenOrder[#seenOrder + 1] = eventId
		if #seenOrder > maxEventIdMemory then
			local oldest = table.remove(seenOrder, 1)
			if oldest ~= nil then
				seenIds[oldest] = nil
			end
		end
		return true
	end

	local function isPriority(name: string): boolean
		if FUNNEL_SET[name] == true then
			return true
		end
		-- session_end e o fecho da sessao: mesmo acima do teto, a duracao nao pode sumir.
		if name == "session_end" then
			return true
		end
		return MONETIZATION_EVENTS[name] == true
	end

	local function guardProps(props: { [string]: any }?): (boolean, string?)
		if props == nil then
			return true, nil
		end
		for key in pairs(props) do
			if type(key) ~= "string" then
				return false, "chave nao-string em props"
			end
			if AnalyticsService.ENVELOPE_FIELDS[key] == true then
				return false, "prop de envelope: " .. key
			end
		end
		return true, nil
	end

	local function contextFor(session: Session, ts: number): any
		return {
			event_id = generateId(),
			ts = ts,
			session_id = session.session_id,
			player_id = session.player_id,
			place_version = session.place_version,
			platform = session.platform,
			device_tier = session.device_tier,
			locale = session.locale,
			is_age_checked = session.is_age_checked,
			server_id = session.server_id,
			experiment = session.experiment,
		}
	end

	local function notifyEvent(event: any): ()
		if onEvent ~= nil then
			local ok, err = pcall(function()
				onEvent(event)
				return nil
			end)
			if not ok then
				reportError("onEvent falhou: " .. tostring(err))
			end
		end
	end

	local function notifyFlush(events: { any }, reason: string): ()
		if onFlush ~= nil and #events > 0 then
			local ok, err = pcall(function()
				onFlush(events, reason)
				return nil
			end)
			if not ok then
				reportError("onFlush falhou: " .. tostring(err))
			end
		end
	end

	local flush: (string?) -> number = function(_reason: string?): number
		return 0
	end

	local function enqueue(event: any): ()
		buffer[#buffer + 1] = event
		if #buffer > maxBuffer then
			table.remove(buffer, 1)
			stats.dropped += 1
		end
		stats.buffer = #buffer
		if #buffer >= maxBatch then
			flush("size")
		end
	end

	local function emitEvent(event: any): (any?, string?)
		if stopped then
			return nil, "stopped"
		end
		local ok, err = types.validate(event)
		if not ok then
			stats.rejected += 1
			stats.invalid += 1
			reportError("evento invalido: " .. tostring(err))
			return nil, err
		end
		local eventId = event.event_id
		if type(eventId) ~= "string" then
			stats.rejected += 1
			return nil, "event_id ausente"
		end
		if seenIds[eventId] == true then
			stats.duplicates += 1
			return nil, "duplicate"
		end
		local session = sessionsById[event.session_id]
		if
			session ~= nil
			and session.event_count >= maxEvents
			and not isPriority(event.event_name)
		then
			stats.session_capped += 1
			return nil, "session_cap"
		end
		if not remember(eventId) then
			stats.duplicates += 1
			return nil, "duplicate"
		end
		if session ~= nil then
			session.event_count += 1
		end
		stats.accepted += 1
		notifyEvent(event)
		enqueue(event)
		return event, nil
	end

	flush = function(reason: string?): number
		local label = reason or "manual"
		if #buffer == 0 then
			lastFlushAt = now()
			stats.buffer = 0
			return 0
		end
		local total = 0
		while #buffer > 0 do
			local count = #buffer
			if count > maxBatch then
				count = maxBatch
			end
			local batch = {}
			for index = 1, count do
				batch[index] = buffer[index]
			end
			local rest = {}
			for index = count + 1, #buffer do
				rest[#rest + 1] = buffer[index]
			end
			buffer = rest
			stats.buffer = #buffer

			local valid, index, validateErr = types.validateAll(batch)
			if not valid then
				stats.invalid += #batch
				stats.rejected += #batch
				reportError(
					"lote invalido em "
						.. tostring(index)
						.. " ("
						.. label
						.. "): "
						.. tostring(validateErr)
				)
			elseif sink ~= nil then
				local ok, okWrite, writeErr = pcall(sink.write, batch)
				if not ok then
					stats.failed_batches += 1
					reportError("sink lancou: " .. tostring(okWrite))
				elseif okWrite == false then
					stats.failed_batches += 1
					reportError("sink recusou o lote: " .. tostring(writeErr))
				else
					stats.batches += 1
					stats.flushed += #batch
					notifyFlush(batch, label)
				end
			else
				stats.batches += 1
				stats.flushed += #batch
				notifyFlush(batch, label)
			end
			total += #batch
		end
		lastFlushAt = now()
		return total
	end

	local controller: Controller

	local function beginSession(player: any, fields: SessionFields): (Session?, string?)
		if stopped then
			return nil, "stopped"
		end
		if sessions[player] ~= nil then
			return nil, "session_exists"
		end
		local startedAt = now()
		local session: Session = {
			player = player,
			player_id = fields.player_id,
			session_id = fields.session_id,
			place_version = fields.place_version,
			platform = fields.platform,
			device_tier = fields.device_tier,
			locale = fields.locale,
			is_age_checked = fields.is_age_checked,
			server_id = fields.server_id,
			experiment = fields.experiment,
			is_returning = fields.is_returning == true,
			started_at = startedAt,
			event_count = 0,
			first_win = false,
			first_win_seconds = nil,
			client_times = {},
			rate_limit_reported_at = nil,
		}
		local event, err = types.newEvent(contextFor(session, startedAt), "session_start", {
			days_since_last_seen = fields.days_since_last_seen,
			is_returning = fields.is_returning == true,
		})
		if event == nil then
			stats.rejected += 1
			return nil, err
		end
		sessions[player] = session
		sessionsById[session.session_id] = session
		local accepted, emitErr = emitEvent(event)
		if accepted == nil then
			sessions[player] = nil
			sessionsById[session.session_id] = nil
			return nil, emitErr
		end
		metrics.sessions += 1
		stats.sessions = metrics.sessions
		if not session.is_returning then
			metrics.new_players += 1
		end
		return session, nil
	end

	local function endSession(player: any, reason: string?): (any?, string?)
		local session = sessions[player]
		if session == nil then
			return nil, "no_session"
		end
		local label = reason or "leave"
		if label ~= "leave" and label ~= "crash" and label ~= "timeout" then
			label = "leave"
		end
		local duration = (now() - session.started_at) / 1000
		if duration < 0 then
			duration = 0
		end
		local event, err = types.newEvent(contextFor(session, now()), "session_end", {
			duration_s = duration,
			reason = label,
		})
		if event ~= nil then
			emitEvent(event)
		else
			stats.rejected += 1
			reportError("session_end invalido: " .. tostring(err))
		end
		sessions[player] = nil
		sessionsById[session.session_id] = nil
		flush("leave")
		return event, nil
	end

	local function emit(player: any, name: string, props: { [string]: any }?): (any?, string?)
		stats.attempts += 1
		local session = sessions[player]
		if session == nil then
			stats.rejected += 1
			return nil, "no_session"
		end
		local safe, safeErr = guardProps(props)
		if not safe then
			stats.rejected += 1
			return nil, safeErr
		end
		local event, err = types.newEvent(contextFor(session, now()), name, props)
		if event == nil then
			stats.rejected += 1
			reportError("evento " .. tostring(name) .. " invalido: " .. tostring(err))
			return nil, err
		end
		return emitEvent(event)
	end

	local function emitClient(player: any, name: string, props: { [string]: any }?): (any?, string?)
		stats.attempts += 1
		local session = sessions[player]
		if session == nil then
			stats.rejected += 1
			return nil, "no_session"
		end
		if CLIENT_EVENTS[name] ~= true then
			stats.rejected += 1
			return nil, "server_only"
		end
		local current = now()
		local windowStart = current - AnalyticsService.CLIENT_WINDOW_MS
		local kept = {}
		for _, stamp in ipairs(session.client_times) do
			if stamp > windowStart then
				kept[#kept + 1] = stamp
			end
		end
		session.client_times = kept
		if #kept >= maxClient then
			stats.rate_limited += 1
			local reportedAt = session.rate_limit_reported_at
			if reportedAt == nil or current - reportedAt >= AnalyticsService.CLIENT_WINDOW_MS then
				session.rate_limit_reported_at = current
				local report, reportErr = emit(player, "client_error", {
					code = "rate_limited",
					context_hash = AnalyticsService.hashId(
						"client_rate_limited",
						session.server_id
					),
				})
				if report == nil then
					reportError("client_error(rate_limited): " .. tostring(reportErr))
				end
			end
			return nil, "rate_limited"
		end
		kept[#kept + 1] = current
		local safe, safeErr = guardProps(props)
		if not safe then
			stats.rejected += 1
			return nil, safeErr
		end
		local event, err = types.newEvent(contextFor(session, current), name, props)
		if event == nil then
			stats.rejected += 1
			reportError("evento de cliente " .. tostring(name) .. " invalido: " .. tostring(err))
			return nil, err
		end
		return emitEvent(event)
	end

	local function emitFirstWin(player: any, battleId: string): (any?, string?)
		stats.attempts += 1
		local session = sessions[player]
		if session == nil then
			stats.rejected += 1
			return nil, "no_session"
		end
		if session.first_win then
			return nil, "already_won"
		end
		local current = now()
		local seconds = (current - session.started_at) / 1000
		if seconds < 0 then
			seconds = 0
		end
		seconds = math.floor(seconds * 1000 + 0.5) / 1000
		local event, err = types.newEvent(contextFor(session, current), "first_win", {
			seconds_since_join = seconds,
			battle_id = battleId,
		})
		if event == nil then
			stats.rejected += 1
			reportError("first_win invalido: " .. tostring(err))
			return nil, err
		end
		local accepted, emitErr = emitEvent(event)
		if accepted == nil then
			return nil, emitErr
		end
		session.first_win = true
		local deltaMs = accepted.ts - session.started_at
		local measured = deltaMs / 1000
		session.first_win_seconds = measured
		metrics.first_wins += 1
		if not session.is_returning then
			metrics.new_player_first_wins += 1
			metrics.seconds[#metrics.seconds + 1] = measured
			if measured < AnalyticsService.FIRST_WIN_WINDOW_SECONDS then
				metrics.new_player_under_60 += 1
			end
		end
		return accepted, nil
	end

	local function sortedSeconds(): { number }
		local copy = {}
		for index, value in ipairs(metrics.seconds) do
			copy[index] = value
		end
		table.sort(copy)
		return copy
	end

	local function percentile(values: { number }, p: number): number?
		if #values == 0 then
			return nil
		end
		local index = math.ceil(p * #values)
		if index < 1 then
			index = 1
		elseif index > #values then
			index = #values
		end
		return values[index]
	end

	local function getStats(): Stats
		local copy: Stats = {
			attempts = stats.attempts,
			accepted = stats.accepted,
			rejected = stats.rejected,
			duplicates = stats.duplicates,
			rate_limited = stats.rate_limited,
			session_capped = stats.session_capped,
			dropped = stats.dropped,
			flushed = stats.flushed,
			batches = stats.batches,
			failed_batches = stats.failed_batches,
			invalid = stats.invalid,
			sessions = stats.sessions,
			buffer = #buffer,
		}
		return copy
	end

	local function getFirstWinReport(): FirstWinReport
		local values = sortedSeconds()
		local rate = 0
		if metrics.new_players > 0 then
			rate = metrics.new_player_under_60 / metrics.new_players
		end
		return {
			sessions = metrics.sessions,
			new_players = metrics.new_players,
			new_player_first_wins = metrics.new_player_first_wins,
			new_player_under_60 = metrics.new_player_under_60,
			first_wins = metrics.first_wins,
			rate_under_60 = rate,
			p50_seconds = percentile(values, 0.5),
			p95_seconds = percentile(values, 0.95),
			gate = AnalyticsService.FIRST_WIN_GATE,
			passes_gate = rate >= AnalyticsService.FIRST_WIN_GATE,
		}
	end

	controller = {
		beginSession = beginSession,
		endSession = endSession,
		emit = emit,
		emitClient = emitClient,
		emitEvent = emitEvent,
		emitFirstWin = emitFirstWin,
		flush = flush,
		tick = function(): number
			if stopped then
				return 0
			end
			if #buffer > 0 and now() - lastFlushAt >= flushIntervalMs then
				return flush("interval")
			end
			return 0
		end,
		getSession = function(player: any): Session?
			return sessions[player]
		end,
		getStats = getStats,
		getFirstWinReport = getFirstWinReport,
		stop = function(): ()
			if stopped then
				return
			end
			flush("stop")
			stopped = true
		end,
	}
	return controller
end

-- ---------------------------------------------------------------- singleton do servidor
-- O boot chama `start`; controllers usam os atalhos abaixo. Sem servico iniciado, o evento e
-- descartado com "not_started" e o gameplay segue (telemetria nunca bloqueia).
local active: Controller? = nil
local pendingStart: { [string]: any } = {}

function AnalyticsService.start(service: Controller): Controller
	active = service
	return service
end

function AnalyticsService.get(): Controller?
	return active
end

function AnalyticsService.stop(): ()
	if active ~= nil then
		active.stop()
	end
	active = nil
end

function AnalyticsService.noteProfileStart(key: string, info: any): ()
	if type(key) ~= "string" or type(info) ~= "table" then
		return
	end
	pendingStart[key] = {
		daysSinceLastSeen = info.daysSinceLastSeen,
		isReturning = info.daysSinceLastSeen ~= nil,
	}
end

function AnalyticsService.takeProfileStart(key: string): any?
	local info = pendingStart[key]
	pendingStart[key] = nil
	return info
end

function AnalyticsService.beginSession(player: any, fields: SessionFields): (Session?, string?)
	if active == nil then
		return nil, "not_started"
	end
	return active.beginSession(player, fields)
end

function AnalyticsService.endSession(player: any, reason: string?): (any?, string?)
	if active == nil then
		return nil, "not_started"
	end
	return active.endSession(player, reason)
end

function AnalyticsService.emit(
	player: any,
	name: string,
	props: { [string]: any }?
): (any?, string?)
	if active == nil then
		return nil, "not_started"
	end
	return active.emit(player, name, props)
end

function AnalyticsService.emitClient(
	player: any,
	name: string,
	props: { [string]: any }?
): (any?, string?)
	if active == nil then
		return nil, "not_started"
	end
	return active.emitClient(player, name, props)
end

function AnalyticsService.emitEvent(event: any): (any?, string?)
	if active == nil then
		return nil, "not_started"
	end
	return active.emitEvent(event)
end

function AnalyticsService.emitFirstWin(player: any, battleId: string): (any?, string?)
	if active == nil then
		return nil, "not_started"
	end
	return active.emitFirstWin(player, battleId)
end

function AnalyticsService.flush(reason: string?): number
	if active == nil then
		return 0
	end
	return active.flush(reason)
end

function AnalyticsService.tick(): number
	if active == nil then
		return 0
	end
	return active.tick()
end

function AnalyticsService.getStats(): Stats?
	if active == nil then
		return nil
	end
	return active.getStats()
end

function AnalyticsService.getFirstWinReport(): FirstWinReport?
	if active == nil then
		return nil
	end
	return active.getFirstWinReport()
end

return AnalyticsService
