--!nonstrict
-- Contrato de schema v4 e de sessao do perfil (P2+ Campanha).
-- Roda no Luau CLI: luau sim/profile-contract.luau
-- Cobre: template v4, validacao, migracao 0->4 / 1->4 / 2->4 / 3->4 com fixtures, JSON-safe,
-- StartSessionAsync nil, EndSession no leave, recarga sem duplicar e recusa de versao futura.
local ProfileSchema = require("../src/shared/data/ProfileSchema")
local ProfileService = require("../src/server/data/ProfileService")
local fixtureV0 = require("./fixtures/profile-v0")
local fixtureV1 = require("./fixtures/profile-v1")
local fixtureV2 = require("./fixtures/profile-v2")
local fixtureV3 = require("./fixtures/profile-v3")

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
check("template v4 e JSON-safe", function()
	local profile = ProfileSchema.template()
	assert(profile.schemaVersion == ProfileSchema.SCHEMA_VERSION, "schemaVersion errado")
	assert(profile.schemaVersion == 4, "SCHEMA_VERSION != 4")
	assert(profile.contentVersion == ProfileSchema.DEFAULT_CONTENT_VERSION, "contentVersion errado")
	assert(profile.wall.level == 1, "wall.level inicial != 1")
	assert(profile.wall.gridWidth == 5 and profile.wall.activeTrapLimit == 5, "grade fora do P2")
	assert(
		profile.equipped.theme == "theme_default"
			and profile.equipped.hordeSkin == "horde_default"
			and profile.equipped.finisher == "finisher_default"
			and profile.equipped.commander == "cmd_vorn",
		"equipped defaults errados"
	)
	assert(
		type(profile.campaign) == "table"
			and profile.campaign.highestUnlockedStage == "1-1"
			and profile.campaign.nightmareUnlocked == false
			and profile.campaign.actMilestoneClaims["1"] == 0
			and profile.campaign.actMilestoneClaims["5"] == 0,
		"campaign defaults errados"
	)
	assert(
		type(profile.wall.cells) == "table" and next(profile.wall.cells) == nil,
		"cells nao vazio"
	)
	assert(
		keysOf(profile)
			== "campaign,contentVersion,cosmetics,equipped,gold,league,schemaVersion,stats,wall",
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
	a.wall.cells.r1c1 = { trap = "archer", level = 1, x = 2000, y = 500 }
	a.campaign.highestUnlockedStage = "3-2"
	local b = ProfileSchema.template()
	assert(
		b.gold == 0 and next(b.wall.cells) == nil and b.campaign.highestUnlockedStage == "1-1",
		"template compartilhou referencia"
	)
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
				p.wall.cells.r9c1 = { trap = "archer", level = 1, x = 2000, y = 500 }
				return p
			end,
		},
		{
			"cell level 0",
			function()
				local p = ProfileSchema.template()
				p.wall.cells.r1c1 = { trap = "archer", level = 0, x = 2000, y = 500 }
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
		{
			"contentVersion 0",
			function()
				local p = ProfileSchema.template()
				p.contentVersion = 0
				return p
			end,
		},
		{
			"contentVersion ausente",
			function()
				local p = ProfileSchema.template()
				p.contentVersion = nil
				return p
			end,
		},
		{
			"campaign stageId invalido",
			function()
				local p = ProfileSchema.template()
				p.campaign.highestUnlockedStage = "6-1"
				return p
			end,
		},
		{
			"campaign starsMask fora de [0,7]",
			function()
				local p = ProfileSchema.template()
				p.campaign.starsNormal["1-1"] = 8
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
	mixed.wall.cells = { r1c1 = { trap = "archer", level = 1, x = 2000, y = 500 }, [1] = true }
	assert(not ProfileSchema.isJsonSafe(mixed), "aceitou chave mista")

	local sparse = ProfileSchema.template()
	sparse.cosmetics = { [1] = true, [3] = true }
	assert(not ProfileSchema.isJsonSafe(sparse), "aceitou array com buraco")
end)

-- ---------------------------------------------------------------- migracoes 0 -> 4, 1 -> 4, 2 -> 4, 3 -> 4
check("migracao 0->4 com fixture preserva o valido e descarta o resto", function()
	local original = clone(fixtureV0)
	local profile, err = ProfileSchema.migrate(fixtureV0)
	assert(profile ~= nil, "migracao falhou: " .. tostring(err))
	assert(profile.schemaVersion == 4, "schemaVersion nao subiu")
	assert(profile.contentVersion == 3, "contentVersion nao subiu")
	assert(profile.gold == 120, "gold perdido")
	assert(profile.league.points == 34, "league.points perdido")
	assert(profile.wall.level == 1, "wall.level perdido")
	assert(profile.wall.cells.r1c1 ~= nil, "cell valida perdida")
	assert(profile.wall.cells.r1c1.trap == "cannon", "trap da cell errada")
	assert(profile.wall.cells.r1c1.x == 2000 and profile.wall.cells.r1c1.y == 500, "x/y de r1c1")
	assert(profile.stats.lastSeenAt == 1762800000, "lastSeenAt perdido")
	assert(profile.stats.firstSeenAt == 0, "firstSeenAt deveria nascer zerado")
	assert(profile.cosmetics.banner_default == true, "cosmetico perdido")
	assert(profile.equipped.commander == "cmd_vorn", "equipped default ausente")
	assert(profile.campaign.highestUnlockedStage == "1-1", "campaign default ausente")
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

check("migracao 1->4 adiciona contentVersion/x/y/equipped/campaign sem perder a parede", function()
	local profile, err = ProfileSchema.migrate(fixtureV1)
	assert(profile ~= nil, "migracao falhou: " .. tostring(err))
	assert(profile.schemaVersion == 4, "schemaVersion nao subiu")
	assert(profile.contentVersion == 3, "contentVersion nao subiu")
	assert(profile.gold == 120, "gold perdido")
	assert(profile.wall.cells.r1c1 ~= nil, "cell valida perdida")
	assert(profile.wall.cells.r1c1.trap == "oil", "trap antiga deveria sobreviver ao schema")
	assert(profile.wall.cells.r1c1.x == 2000 and profile.wall.cells.r1c1.y == 500, "x/y de r1c1")
	assert(profile.campaign.highestUnlockedStage == "1-1", "campaign default")
	local ok, validateErr = ProfileSchema.validate(profile)
	assert(ok, "perfil v4 invalido: " .. tostring(validateErr))
end)

check("migracao 2->4 mapeia rXcY para x/y e adiciona wall.level + equipped + campaign", function()
	local original = clone(fixtureV2)
	local profile, err = ProfileSchema.migrate(fixtureV2)
	assert(profile ~= nil, "migracao falhou: " .. tostring(err))
	assert(profile.schemaVersion == 4, "schemaVersion != 4")
	assert(profile.contentVersion == 3, "contentVersion != 3")
	assert(profile.gold == 260, "gold perdido")
	assert(profile.league.points == 134, "league perdido")
	assert(profile.wall.level == 1, "wall.level != 1")
	assert(profile.wall.activeTrapLimit == 5, "activeTrapLimit != 5")
	assert(profile.wall.cells.r1c1.x == 2000 and profile.wall.cells.r1c1.y == 500, "r1c1 pos")
	assert(profile.wall.cells.r3c3.x == 5000 and profile.wall.cells.r3c3.y == 2500, "r3c3 pos")
	assert(profile.equipped.theme == "theme_default", "equipped.theme")
	assert(profile.campaign.highestUnlockedStage == "1-1", "campaign.highestUnlockedStage")
	assert(keysOf(fixtureV2) == keysOf(original), "fixture v2 mutado")
	local ok, validateErr = ProfileSchema.validate(profile)
	assert(ok, "perfil migrado v4 invalido: " .. tostring(validateErr))
end)

check("migracao 3->4 adiciona campaign aditivo e preserva wall.level/equipped/x/y", function()
	local original = clone(fixtureV3)
	local profile, err = ProfileSchema.migrate(fixtureV3)
	assert(profile ~= nil, "migracao falhou: " .. tostring(err))
	assert(profile.schemaVersion == 4, "schemaVersion != 4")
	assert(profile.contentVersion == 3, "contentVersion != 3")
	assert(profile.gold == 340, "gold perdido")
	assert(profile.wall.level == 2, "wall.level != 2")
	assert(profile.wall.cells.r1c1.x == 2000 and profile.wall.cells.r1c1.y == 500, "r1c1 pos")
	assert(profile.wall.cells.r3c3.x == 5000 and profile.wall.cells.r3c3.y == 2500, "r3c3 pos")
	assert(profile.campaign.highestUnlockedStage == "1-1", "campaign.highestUnlockedStage")
	assert(profile.campaign.nightmareUnlocked == false, "campaign.nightmareUnlocked")
	assert(profile.campaign.actMilestoneClaims["1"] == 0, "actMilestoneClaims[1]")
	assert(keysOf(fixtureV3) == keysOf(original), "fixture v3 mutado")
	local ok, validateErr = ProfileSchema.validate(profile)
	assert(ok, "perfil migrado v4 invalido: " .. tostring(validateErr))
	local jsonOk, jsonErr = ProfileSchema.isJsonSafe(profile)
	assert(jsonOk, "perfil migrado v4 nao e JSON-safe: " .. tostring(jsonErr))
end)

check("migracao de v0 vazio devolve o template", function()
	local profile, err = ProfileSchema.migrate({}, 0)
	assert(profile ~= nil, "migracao falhou: " .. tostring(err))
	assert(
		profile.schemaVersion == 4 and profile.contentVersion == 3 and profile.gold == 0,
		"template esperado"
	)
	assert(ProfileSchema.validate(profile), "v0 vazio gerou perfil invalido")
end)

check("validacao v4: slot, coordenadas step 250, tooClose, wall.level e campaign", function()
	local p = ProfileSchema.template()
	p.wall.level = 5
	p.wall.activeTrapLimit = 7
	p.wall.cells.slot_a = { trap = "archer", level = 5, x = 1000, y = 500 }
	p.wall.cells.slot_b = { trap = "tar", level = 1, x = 2000, y = 500 }
	p.campaign.highestUnlockedStage = "2-3"
	p.campaign.starsNormal["1-1"] = 7
	p.campaign.actMilestoneClaims["1"] = 3
	local ok, err = ProfileSchema.validate(p)
	assert(ok, "perfil v4 valido recusado: " .. tostring(err))
	local jsonOk, jsonErr = ProfileSchema.isJsonSafe(p)
	assert(jsonOk, "perfil v4 com stars nao e JSON-safe: " .. tostring(jsonErr))

	local badSlot = clone(p)
	badSlot.wall.cells["BAD!"] = { trap = "archer", level = 1, x = 5000, y = 2500 }
	assert(not ProfileSchema.validate(badSlot), "aceitou slot invalido")

	local badStep = clone(p)
	badStep.wall.cells.slot_a.x = 1100
	assert(not ProfileSchema.validate(badStep), "aceitou x fora de step 250")

	local badBounds = clone(p)
	badBounds.wall.cells.slot_a.y = 4750
	assert(not ProfileSchema.validate(badBounds), "aceitou y fora da arena")

	local close = clone(p)
	close.wall.cells.slot_b = { trap = "tar", level = 1, x = 1750, y = 1250 }
	assert(not ProfileSchema.validate(close), "aceitou armadilhas tooClose")
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
	assert(session.Data.schemaVersion == 4, "nao migrou")
	assert(profile.saves == 1, "migracao nao foi salva: " .. tostring(profile.saves))
	assert(profile.reconciles == 1, "Reconcile nao rodou")
	assert(infos[1].migrated == true, "info.migrated deveria ser true")
	assert(session.Data.stats.sessions == 1, "sessions deveria comecar em 1")
	assert(session.Data.stats.lastSeenAt == 1762800000, "lastSeenAt nao atualizado")
	assert(session.Data.stats.firstSeenAt == 1762800000, "firstSeenAt nao preenchido")
	assert(session.Data.coins == nil, "PII/lixo sobreviveu a migracao em sessao")
end)

check("perfil atual nao e salvo a toa no load", function()
	local profile = newProfile(ProfileSchema.template(), "User_4")
	local store = newScriptedStore({ profile })
	local infos = {}
	local controller = newController(store, {
		onStart = function(_, info)
			table.insert(infos, info)
		end,
	})
	assert(controller.startSession("User_4") ~= nil, "nao abriu")
	assert(profile.saves == 0, "salvou perfil atual sem migracao")
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
