--!nonstrict
-- Contrato de schema v1 e de sessao do perfil (P0).
-- Roda no Luau CLI: luau sim/profile-contract.luau
-- Cobre: template, validacao, migracao 0->1 com fixture, JSON-safe, StartSessionAsync nil,
-- EndSession no leave, recarga sem duplicar e recusa de versao futura.
local ProfileSchema = require("../src/shared/data/ProfileSchema")
local ProfileService = require("../src/server/data/ProfileService")
local fixtureV0 = require("./fixtures/profile-v0")

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

local function keysOf(value)
	local keys = {}
	for key in pairs(value) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return table.concat(keys, ",")
end

-- ---------------------------------------------------------------- fakes do ProfileStore
-- Store roteirizado: devolve cada item da fila em ordem (perfil, nil, ou funcao que pode
-- lancar). `waits` registra o backoff para o teste nao dormir de verdade.
local function newScriptedStore(queue)
	local store = { calls = 0, waits = {}, keys = {} }
	local index = 0
	function store:StartSessionAsync(key)
		self.calls += 1
		self.keys[self.calls] = key
		index += 1
		local item = queue[index]
		if type(item) == "function" then
			return item(key)
		end
		return item
	end
	return store
end

local function newProfile(data, key)
	local profile = { Data = data or {}, Key = key, saves = 0, ends = 0, reconciles = 0 }
	profile.Reconcile = function()
		profile.reconciles += 1
	end
	profile.Save = function()
		profile.saves += 1
	end
	profile.EndSession = function()
		profile.ends += 1
	end
	profile.AddUserId = function() end
	return profile
end

-- Store com persistencia de mentira: guarda o Data no leave/save e devolve na proxima sessao.
-- E o que permite testar "carrega, salva, nao duplica" sem Studio.
local function newPersistentStore()
	local state = {}
	local store = { calls = 0, saves = 0, ends = 0, state = state, waited = {} }
	function store:StartSessionAsync(key)
		self.calls += 1
		local data = state[key]
		if data == nil then
			data = ProfileSchema.template()
		else
			data = clone(data)
		end
		local profile = newProfile(data, key)
		local save = profile.Save
		local endSession = profile.EndSession
		profile.Save = function()
			save()
			state[key] = clone(profile.Data)
			store.saves += 1
		end
		profile.EndSession = function()
			endSession()
			state[key] = clone(profile.Data)
			store.ends += 1
		end
		return profile
	end
	return store
end

local function newController(store, options)
	options = options or {}
	return ProfileService.new({
		store = store,
		schema = ProfileSchema,
		now = options.now or function()
			return 1762800000
		end,
		wait = function(seconds)
			table.insert(store.waits or store.waited, seconds)
		end,
		attempts = options.attempts,
		retryDelay = options.retryDelay,
		onError = options.onError,
		onStart = options.onStart,
		onEnd = options.onEnd,
	})
end

-- ---------------------------------------------------------------- template e validacao
check("template v1 e JSON-safe", function()
	local profile = ProfileSchema.template()
	assert(profile.schemaVersion == ProfileSchema.SCHEMA_VERSION, "schemaVersion errado")
	assert(profile.wall.gridWidth == 5 and profile.wall.activeTrapLimit == 5, "grade fora do Q2")
	assert(
		type(profile.wall.cells) == "table" and next(profile.wall.cells) == nil,
		"cells nao vazio"
	)
	assert(
		keysOf(profile) == "cosmetics,gold,league,schemaVersion,stats,wall",
		"chaves: " .. keysOf(profile)
	)
	local ok, err = ProfileSchema.validate(profile)
	assert(ok, "template invalido: " .. tostring(err))
	local jsonOk, jsonErr = ProfileSchema.isJsonSafe(profile)
	assert(jsonOk, "template nao e JSON-safe: " .. tostring(jsonErr))
end)

check("template devolve tabela nova a cada chamada", function()
	local a = ProfileSchema.template()
	a.gold = 999
	a.wall.cells.r1c1 = { trap = "archer", level = 1 }
	local b = ProfileSchema.template()
	assert(b.gold == 0 and next(b.wall.cells) == nil, "template compartilhou referencia")
end)

check("validacao recusa perfil invalido", function()
	local cases = {
		{
			"campo desconhecido",
			function()
				local p = ProfileSchema.template()
				p.hackAttempt = true
				return p
			end,
		},
		{
			"PII",
			function()
				local p = ProfileSchema.template()
				p.player_name = "Fulano"
				return p
			end,
		},
		{
			"gold negativo",
			function()
				local p = ProfileSchema.template()
				p.gold = -1
				return p
			end,
		},
		{
			"gold fracionario",
			function()
				local p = ProfileSchema.template()
				p.gold = 1.5
				return p
			end,
		},
		{
			"gold NaN",
			function()
				local p = ProfileSchema.template()
				p.gold = 0 / 0
				return p
			end,
		},
		{
			"stats desconhecido",
			function()
				local p = ProfileSchema.template()
				p.stats.extra = 1
				return p
			end,
		},
		{
			"cell fora da grade",
			function()
				local p = ProfileSchema.template()
				p.wall.cells.r9c1 = { trap = "archer", level = 1 }
				return p
			end,
		},
		{
			"cell level 0",
			function()
				local p = ProfileSchema.template()
				p.wall.cells.r1c1 = { trap = "archer", level = 0 }
				return p
			end,
		},
		{
			"gridWidth 4",
			function()
				local p = ProfileSchema.template()
				p.wall.gridWidth = 4
				return p
			end,
		},
		{
			"wall ausente",
			function()
				local p = ProfileSchema.template()
				p.wall = nil
				return p
			end,
		},
		{
			"schemaVersion 0",
			function()
				local p = ProfileSchema.template()
				p.schemaVersion = 0
				return p
			end,
		},
	}
	for _, case in ipairs(cases) do
		local ok, err = ProfileSchema.validate(case[2]())
		assert(not ok, "aceitou perfil invalido: " .. case[1])
		assert(type(err) == "string" and #err > 0, "erro vazio em " .. case[1])
	end
end)

check("isJsonSafe recusa o que o DataStore nao serializa", function()
	local ok = ProfileSchema.isJsonSafe(ProfileSchema.template())
	assert(ok, "template deveria ser JSON-safe")

	local function withField(value)
		local p = ProfileSchema.template()
		p.league.points = value
		return p
	end
	assert(not ProfileSchema.isJsonSafe(withField(0 / 0)), "aceitou NaN")
	assert(not ProfileSchema.isJsonSafe(withField(math.huge)), "aceitou infinito")
	assert(not ProfileSchema.isJsonSafe(withField(function() end)), "aceitou funcao")

	local cyclic = ProfileSchema.template()
	cyclic.league.self = cyclic
	assert(not ProfileSchema.isJsonSafe(cyclic), "aceitou ciclo")

	local mixed = ProfileSchema.template()
	mixed.wall.cells = { r1c1 = { trap = "archer", level = 1 }, [1] = true }
	assert(not ProfileSchema.isJsonSafe(mixed), "aceitou chave mista")

	local sparse = ProfileSchema.template()
	sparse.cosmetics = { [1] = true, [3] = true }
	assert(not ProfileSchema.isJsonSafe(sparse), "aceitou array com buraco")
end)

-- ---------------------------------------------------------------- migracao 0 -> 1
check("migracao 0->1 com fixture preserva o valido e descarta o resto", function()
	local original = clone(fixtureV0)
	local profile, err = ProfileSchema.migrate(fixtureV0)
	assert(profile ~= nil, "migracao falhou: " .. tostring(err))
	assert(profile.schemaVersion == 1, "schemaVersion nao subiu")
	assert(profile.gold == 120, "gold perdido")
	assert(profile.league.points == 34, "league.points perdido")
	assert(profile.wall.cells.r1c1 ~= nil, "cell valida perdida")
	assert(profile.wall.cells.r1c1.trap == "cannon", "trap da cell errada")
	assert(profile.stats.lastSeenAt == 1762800000, "lastSeenAt perdido")
	assert(profile.stats.firstSeenAt == 0, "firstSeenAt deveria nascer zerado")
	assert(profile.cosmetics.banner_default == true, "cosmetico perdido")
	assert(profile.coins == nil, "campo do prototipo (coins) sobreviveu")
	assert(profile.hackAttempt == nil, "campo desconhecido sobreviveu")
	assert(profile.player_name == nil, "PII sobreviveu")
	assert(profile.wall.legacyNote == nil, "campo desconhecido dentro de wall sobreviveu")
	local ok, validateErr = ProfileSchema.validate(profile)
	assert(ok, "perfil migrado invalido: " .. tostring(validateErr))
	local jsonOk, jsonErr = ProfileSchema.isJsonSafe(profile)
	assert(jsonOk, "perfil migrado nao e JSON-safe: " .. tostring(jsonErr))
	assert(keysOf(fixtureV0) == keysOf(original), "migracao mutou o fixture")
	assert(fixtureV0.gold == 120 and fixtureV0.stats.lastSeenAt == 1762800000, "fixture mutado")
end)

check("migracao de v0 vazio devolve o template", function()
	local profile, err = ProfileSchema.migrate({}, 0)
	assert(profile ~= nil, "migracao falhou: " .. tostring(err))
	assert(profile.schemaVersion == 1 and profile.gold == 0, "template esperado")
	assert(ProfileSchema.validate(profile), "v0 vazio gerou perfil invalido")
end)

check("migracao e idempotente", function()
	local once = assert(ProfileSchema.migrate(fixtureV0))
	local twice = assert(ProfileSchema.migrate(once))
	assert(
		once.gold == twice.gold and once.league.points == twice.league.points,
		"mudou no 2o passo"
	)
	assert(once.stats.lastSeenAt == twice.stats.lastSeenAt, "lastSeenAt mudou no 2o passo")
	assert(keysOf(once.wall.cells) == keysOf(twice.wall.cells), "cells mudaram no 2o passo")
end)

check("versao futura e recusada", function()
	local profile, err = ProfileSchema.migrate(fixtureV0, 99)
	assert(profile == nil, "migrou versao futura")
	assert(err == "schema_future", "erro: " .. tostring(err))
	local negative, negativeErr = ProfileSchema.migrate(fixtureV0, -1)
	assert(negative == nil and negativeErr ~= nil, "aceitou versao negativa")
end)

check("dias entre sessoes e chave do perfil", function()
	assert(ProfileSchema.daysBetween(1762800000, 0) == nil, "0 deveria ser nil (nunca visto)")
	local threeDays = ProfileSchema.daysBetween(1762800000 + 3 * 86400 + 17, 1762800000)
	assert(threeDays == 3, "esperava 3 dias: " .. tostring(threeDays))
	assert(ProfileSchema.daysBetween(1000, 5000) == 0, "futuro deveria dar 0")
	assert(ProfileSchema.keyFor(12345) == "User_12345", "chave do perfil errada")
end)

-- ---------------------------------------------------------------- sessao
check("StartSessionAsync nil e tratado com backoff", function()
	local session = newProfile(ProfileSchema.template(), "User_1")
	local store = newScriptedStore({ nil, nil, session })
	local controller = newController(store)
	local started, err = controller.startSession("User_1")
	assert(started ~= nil, "nao abriu sessao: " .. tostring(err))
	assert(store.calls == 3, "esperava 3 tentativas: " .. tostring(store.calls))
	assert(#store.waits == 2, "esperava 2 esperas: " .. tostring(#store.waits))
	assert(store.waits[1] == 0.5 and store.waits[2] == 1, "backoff errado")
	assert(controller.activeCount() == 1, "sessao nao registrada")
end)

check("StartSessionAsync sempre nil recusa o jogador", function()
	local store = newScriptedStore({ nil, nil, nil })
	local controller = newController(store)
	local started, err = controller.startSession("User_1")
	assert(started == nil, "deveria recusar")
	assert(err == "start_session_nil", "erro: " .. tostring(err))
	assert(store.calls == 3, "esperava 3 tentativas")
	assert(controller.getData("User_1") == nil, "sessao fantasma com dado")
	assert(controller.getSession("User_1") == nil, "sessao fantasma")
end)

check("erro no StartSessionAsync nao derruba a sessao", function()
	local reported = 0
	local session = newProfile(ProfileSchema.template(), "User_2")
	local store = newScriptedStore({
		function()
			error("DataStore fora do ar")
		end,
		session,
	})
	local controller = newController(store, {
		onError = function()
			reported += 1
		end,
	})
	local started = controller.startSession("User_2")
	assert(started ~= nil, "nao recuperou depois do erro")
	assert(reported == 1, "onError nao foi chamado: " .. tostring(reported))
end)

check("migra no load e persiste a migracao", function()
	local profile = newProfile(clone(fixtureV0), "User_3")
	local store = newScriptedStore({ profile })
	local infos = {}
	local controller = newController(store, {
		onStart = function(_, info)
			table.insert(infos, info)
		end,
	})
	local session = assert(controller.startSession("User_3"))
	assert(session.Data.schemaVersion == 1, "nao migrou")
	assert(profile.saves == 1, "migracao nao foi salva: " .. tostring(profile.saves))
	assert(profile.reconciles == 1, "Reconcile nao rodou")
	assert(infos[1].migrated == true, "info.migrated deveria ser true")
	assert(session.Data.stats.sessions == 1, "sessions deveria comecar em 1")
	assert(session.Data.stats.lastSeenAt == 1762800000, "lastSeenAt nao atualizado")
	assert(session.Data.stats.firstSeenAt == 1762800000, "firstSeenAt nao preenchido")
	assert(session.Data.coins == nil, "PII/lixo sobreviveu a migracao em sessao")
end)

check("perfil v1 nao e salvo a toa no load", function()
	local profile = newProfile(ProfileSchema.template(), "User_4")
	local store = newScriptedStore({ profile })
	local infos = {}
	local controller = newController(store, {
		onStart = function(_, info)
			table.insert(infos, info)
		end,
	})
	assert(controller.startSession("User_4") ~= nil, "nao abriu")
	assert(profile.saves == 0, "salvou perfil v1 sem migracao")
	assert(infos[1].migrated == false, "info.migrated deveria ser false")
end)

check("versao futura recusa a sessao e devolve o lock", function()
	local profile = newProfile({ schemaVersion = 99, gold = 10 }, "User_5")
	local store = newScriptedStore({ profile })
	local controller = newController(store)
	local session, err = controller.startSession("User_5")
	assert(session == nil, "aceitou perfil de versao futura")
	assert(string.find(tostring(err), "schema", 1, true) ~= nil, "erro: " .. tostring(err))
	assert(profile.ends == 1, "nao devolveu o lock (EndSession)")
	assert(controller.activeCount() == 0, "sessao fantasma")
end)

check("endSession salva no leave e e idempotente", function()
	local now = 1762800000
	local profile = newProfile(clone(fixtureV0), "User_6")
	local store = newScriptedStore({ profile })
	local controller = newController(store, {
		now = function()
			return now
		end,
	})
	assert(controller.startSession("User_6") ~= nil, "nao abriu")
	now += 90
	assert(controller.endSession("User_6") == true, "endSession falhou")
	assert(profile.ends == 1, "EndSession nao chamado")
	assert(profile.Data.stats.lastSeenAt == now, "lastSeenAt do leave nao gravado")
	assert(
		profile.Data.stats.playSeconds == 90,
		"playSeconds errado: " .. tostring(profile.Data.stats.playSeconds)
	)
	assert(controller.endSession("User_6") == false, "segundo endSession deveria ser false")
	assert(profile.ends == 1, "EndSession chamado duas vezes")
	assert(controller.activeCount() == 0, "sobrou sessao")
end)

check("carrega, salva e recarrega sem duplicar", function()
	local now = 1762800000
	local store = newPersistentStore()
	local controller = newController(store, {
		now = function()
			return now
		end,
	})
	local first = assert(controller.startSession("User_7"))
	first.Data.gold = 500
	local sessionsBefore = first.Data.stats.sessions
	local seenBefore = first.Data.stats.lastSeenAt
	now += 120
	assert(controller.endSession("User_7") == true, "leave falhou")
	assert(controller.activeCount() == 0, "sessao nao liberada")
	now += 33
	local second = assert(controller.startSession("User_7"))
	assert(second.Data.gold == 500, "gold nao persistiu")
	assert(second.Data.stats.sessions == sessionsBefore + 1, "sessions nao incrementou")
	assert(second.Data.stats.lastSeenAt > seenBefore, "lastSeenAt nao avancou")
	assert(second.Data.stats.playSeconds == 120, "playSeconds nao acumulou")
	assert(controller.activeCount() == 1, "sessao duplicada")
	local ok, err = ProfileSchema.validate(second.Data)
	assert(ok, "perfil salvo invalido: " .. tostring(err))
	assert(store.state["User_7"] ~= nil, "store nao guardou o perfil")
	assert(store.ends == 1, "EndSession nao chegou ao store")
	assert(second.Data.player_name == nil and second.Data.coins == nil, "PII no perfil salvo")
end)

check("startSession duas vezes nao bate no store de novo", function()
	local store = newPersistentStore()
	local controller = newController(store)
	assert(controller.startSession("User_8") ~= nil, "nao abriu")
	assert(controller.startSession("User_8") ~= nil, "nao devolveu a mesma sessao")
	assert(store.calls == 1, "chamou o store " .. tostring(store.calls) .. " vezes")
	assert(controller.activeCount() == 1, "sessao duplicada")
end)

check("getData devolve nil para chave desconhecida", function()
	local store = newPersistentStore()
	local controller = newController(store)
	assert(controller.getData("User_404") == nil, "devolveu dado de sessao inexistente")
	assert(controller.getSession("User_404") == nil, "devolveu sessao inexistente")
end)

print(string.format("contrato de perfil: %d checagens, %d falhas", checks, #failures))
if #failures > 0 then
	for _, failure in ipairs(failures) do
		print("  FALHOU: " .. failure)
	end
	error("contrato de perfil quebrado")
end
print("OK: contrato de perfil passou")
