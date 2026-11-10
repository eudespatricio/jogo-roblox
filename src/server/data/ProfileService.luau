--!strict
-- Wrapper de sessao sobre o ProfileStore vendorizado (server-only; ver vendor/SOURCE.md).
-- Puro Luau e com store injetado: a sessao inteira e testavel no CLI
-- (sim/profile-contract.luau). A ligacao com Players e com o vendor mora em
-- src/server/ProfileBoot.server.luau.
-- Regras: StartSessionAsync pode devolver nil (outro servidor pegou a sessao) -> tentar de novo
-- e, se falhar, recusar o jogador; EndSession no leave, senao o servidor acumula requests;
-- migrar antes de expor Data; nada de logica critica em OnLastSave (pode nao disparar).

local ProfileService = {}

export type Session = any

export type Schema = {
	SCHEMA_VERSION: number,
	migrate: (data: any, fromVersion: number?) -> (any?, string?),
	daysBetween: (nowTs: number, thenTs: number) -> number?,
}

export type Store = {
	StartSessionAsync: (self: any, key: string) -> any,
}

export type StartInfo = {
	key: string,
	daysSinceLastSeen: number?,
	migrated: boolean,
}

export type Options = {
	store: Store,
	schema: Schema,
	now: (() -> number)?,
	wait: ((seconds: number) -> ())?,
	attempts: number?,
	retryDelay: number?,
	onStart: ((session: Session, info: StartInfo) -> ())?,
	onEnd: ((session: Session) -> ())?,
	onError: ((message: string, key: string) -> ())?,
}

export type Controller = {
	startSession: (key: string) -> (Session?, string?),
	endSession: (key: string) -> boolean,
	touch: (key: string) -> (Session?, number?),
	getSession: (key: string) -> Session?,
	getData: (key: string) -> any,
	activeCount: () -> number,
}

local DEFAULT_ATTEMPTS = 3
local DEFAULT_RETRY_DELAY_SECONDS = 0.5
local MAX_ATTEMPTS = 10

-- Cria um controlador de sessoes. `store` e o ProfileStore (ou o Mock, ou um fake nos testes).
-- `wait` e injetado para o teste nao dormir; no Roblox o boot passa task.wait.
function ProfileService.new(options: Options): Controller
	assert(type(options) == "table", "ProfileService.new: options ausente")
	assert(options.store ~= nil, "ProfileService.new: store ausente")
	assert(options.schema ~= nil, "ProfileService.new: schema ausente")

	local now: () -> number = options.now or function(): number
		return os.time()
	end
	local wait = options.wait or function(_seconds: number) end
	local attempts = options.attempts or DEFAULT_ATTEMPTS
	local retryDelay = options.retryDelay or DEFAULT_RETRY_DELAY_SECONDS
	if attempts < 1 then
		attempts = 1
	elseif attempts > MAX_ATTEMPTS then
		attempts = MAX_ATTEMPTS
	end

	local sessions: { [string]: Session } = {}
	local startedAt: { [string]: number } = {}

	local function reportError(message: string, key: string)
		if options.onError ~= nil then
			options.onError(message, key)
		end
	end

	-- Devolve o lock mesmo quando o perfil e recusado: sessao pendurada trava o jogador.
	local function releaseSession(session: Session, key: string)
		local ok, err = pcall(function()
			if type(session.EndSession) == "function" then
				session:EndSession()
			end
		end)
		if not ok then
			reportError("EndSession falhou: " .. tostring(err), key)
		end
	end

	local function noteSeen(session: Session, nowSeconds: number): number
		local stats = session.Data.stats
		local previousLastSeen = 0
		if type(stats) ~= "table" then
			return previousLastSeen
		end
		if type(stats.lastSeenAt) == "number" then
			previousLastSeen = stats.lastSeenAt :: number
		end
		if type(stats.firstSeenAt) ~= "number" or stats.firstSeenAt == 0 then
			stats.firstSeenAt = nowSeconds
		end
		stats.lastSeenAt = nowSeconds
		return previousLastSeen
	end

	local function prepare(key: string, session: Session): (Session?, string?)
		local data = session.Data
		local fromVersion = 0
		if type(data) == "table" and type(data.schemaVersion) == "number" then
			fromVersion = data.schemaVersion :: number
		end
		local migrated, err = options.schema.migrate(data, fromVersion)
		if migrated == nil then
			releaseSession(session, key)
			return nil, "schema: " .. tostring(err)
		end
		local migratedNow = fromVersion ~= options.schema.SCHEMA_VERSION
		session.Data = migrated
		local okReconcile, errReconcile = pcall(function()
			if type(session.Reconcile) == "function" then
				session:Reconcile()
			end
		end)
		if not okReconcile then
			reportError("Reconcile falhou: " .. tostring(errReconcile), key)
		end
		-- Migracao precisa ser persistida agora: se o servidor cair antes do autosave, o
		-- perfil antigo volta e a migracao roda de novo sem perda.
		if migratedNow and type(session.Save) == "function" then
			local okSave, errSave = pcall(function()
				session:Save()
			end)
			if not okSave then
				reportError("Save pos-migracao falhou: " .. tostring(errSave), key)
			end
		end
		local nowSeconds = now()
		local previousLastSeen = noteSeen(session, nowSeconds)
		local stats = session.Data.stats
		if type(stats) == "table" then
			stats.sessions = (stats.sessions or 0) + 1
		end
		startedAt[key] = nowSeconds
		sessions[key] = session
		if options.onStart ~= nil then
			options.onStart(session, {
				key = key,
				daysSinceLastSeen = options.schema.daysBetween(nowSeconds, previousLastSeen),
				migrated = migratedNow,
			})
		end
		return session, nil
	end

	local function startSession(key: string): (Session?, string?)
		local existing = sessions[key]
		if existing ~= nil then
			return existing, nil
		end
		for attempt = 1, attempts do
			local ok, result = pcall(options.store.StartSessionAsync, options.store, key)
			if not ok then
				reportError("StartSessionAsync lancou: " .. tostring(result), key)
			elseif result ~= nil then
				return prepare(key, result)
			end
			if attempt < attempts then
				wait(retryDelay * 2 ^ (attempt - 1))
			end
		end
		return nil, "start_session_nil"
	end

	local function endSession(key: string): boolean
		local session = sessions[key]
		if session == nil then
			return false
		end
		sessions[key] = nil
		local nowSeconds = now()
		local stats = session.Data.stats
		if type(stats) == "table" then
			if type(stats.lastSeenAt) ~= "number" or stats.lastSeenAt < nowSeconds then
				stats.lastSeenAt = nowSeconds
			end
			local started = startedAt[key]
			if started ~= nil and nowSeconds > started then
				stats.playSeconds = (stats.playSeconds or 0) + (nowSeconds - started)
			end
		end
		startedAt[key] = nil
		if options.onEnd ~= nil then
			options.onEnd(session)
		end
		releaseSession(session, key)
		return true
	end

	local function touch(key: string): (Session?, number?)
		local session = sessions[key]
		if session == nil then
			return nil, nil
		end
		local nowSeconds = now()
		local previousLastSeen = noteSeen(session, nowSeconds)
		return session, options.schema.daysBetween(nowSeconds, previousLastSeen)
	end

	return {
		startSession = startSession,
		endSession = endSession,
		touch = touch,
		getSession = function(key: string): Session?
			return sessions[key]
		end,
		getData = function(key: string): any
			local session = sessions[key]
			if session == nil then
				return nil
			end
			return session.Data
		end,
		activeCount = function(): number
			local count = 0
			for _ in pairs(sessions) do
				count += 1
			end
			return count
		end,
	}
end

return ProfileService
