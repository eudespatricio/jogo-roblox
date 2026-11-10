--!nonstrict
-- Contrato da muralha e economia (S3): validacao server-side de celula, N=5, ouro e
-- desbloqueio; persistencia em Profile.Data; eventos da taxonomia v1.
-- Roda no Luau CLI: luau sim/walls-contract.luau

local ProfileSchema = require("../src/shared/data/ProfileSchema")
local WallService = require("../src/server/walls/WallService")
local Analytics = require("../src/shared/analytics/AnalyticsTypes")
local Core = require("../src/shared/sim/core")

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
local SESSION_ID = "11111111-1111-4111-8111-111111111111"
local PLAYER_ID = "3f7a9c1e5b2d4f608a1c3e5b7d9f0a2c"
local SERVER_ID = "9d1e2f3a4b5c6d7e8f9012345678abcd"

local eventCounter = 0
local function nextCtx()
	eventCounter += 1
	return {
		event_id = string.format("00000000-0000-4000-8000-%012x", eventCounter),
		ts = 1762800000,
		session_id = SESSION_ID,
		player_id = PLAYER_ID,
		place_version = "0.1.0-p1",
		platform = "mobile",
		device_tier = "mid",
		locale = "pt-BR",
		is_age_checked = false,
		server_id = SERVER_ID,
	}
end

local function validateEvents(specs)
	for _, spec in ipairs(specs) do
		local event, err = Analytics.newEvent(nextCtx(), spec.name, spec.props)
		assert(event ~= nil, spec.name .. ": " .. tostring(err))
		local ok, validateErr = Analytics.validate(event)
		assert(ok, spec.name .. ": " .. tostring(validateErr))
	end
end

local function newHarness()
	local profile = ProfileSchema.template()
	local emitted = {}
	local service = WallService.new({
		profile = profile,
		schema = ProfileSchema,
		emit = function(name, props)
			table.insert(emitted, { name = name, props = props })
		end,
	})
	return service, profile, emitted
end

local function seedGold(service, amount)
	local result, err = service.creditGold(amount, "raid", BATTLE_ID)
	assert(result ~= nil, tostring(err))
	validateEvents(result.events)
end

check("catalogo espelha o motor e desbloqueia por liga", function()
	local names = {}
	for trapId in pairs(WallService.CATALOG) do
		names[#names + 1] = trapId
	end
	table.sort(names)
	local coreNames = {}
	for _, trapId in ipairs(Core.TRAP_NAMES) do
		coreNames[#coreNames + 1] = trapId
	end
	table.sort(coreNames)
	assert(table.concat(names, ",") == table.concat(coreNames, ","), "catalogo != motor")
	assert(WallService.MAX_LEVEL == 3, "MAX_LEVEL")
	assert(WallService.POINTS_PER_LEAGUE == 100, "POINTS_PER_LEAGUE")
	assert(WallService.leagueOf(0) == 1, "liga 0")
	assert(WallService.leagueOf(99) == 1, "liga 99")
	assert(WallService.leagueOf(100) == 2, "liga 100")
	assert(WallService.leagueOf(250) == 3, "liga 250")
	for _, def in pairs(WallService.CATALOG) do
		assert(def.cost > 0 and def.cost % 1 == 0, "custo invalido")
		assert(def.upgrade > 0 and def.upgrade % 1 == 0, "upgrade invalido")
		assert(def.unlockLeague >= 1 and def.unlockLeague <= 4, "unlock invalido")
	end
end)

check("place valido persiste celula, debita ouro e emite eventos", function()
	local service, profile, emitted = newHarness()
	seedGold(service, 500)
	local beforeEvents = #emitted
	local result, err = service.place("archer", "r1c1")
	assert(result ~= nil, tostring(err))
	assert(result.action == "place", "acao")
	assert(result.cell == "r1c1" and result.trap == "archer" and result.level == 1, "resultado")
	assert(result.cost == 40 and result.gold == 460, "custo/gold")
	assert(profile.gold == 460, "gold nao debitado")
	assert(profile.wall.cells["r1c1"].trap == "archer", "celula nao persistiu")
	assert(profile.wall.cells["r1c1"].level == 1, "nivel inicial")
	assert(#result.events == 2, "eventos")
	assert(result.events[1].name == "trap_placed", "ordem trap_placed")
	assert(result.events[2].name == "gold_spent", "ordem gold_spent")
	assert(#emitted == beforeEvents + 2, "emit nao chamado")
	validateEvents(result.events)
	local ok, profileErr = ProfileSchema.validate(profile)
	assert(ok, tostring(profileErr))
	local jsonOk, jsonErr = ProfileSchema.isJsonSafe(profile)
	assert(jsonOk, tostring(jsonErr))
end)

check("celula invalida e recusada sem mutar estado", function()
	local service, profile, emitted = newHarness()
	seedGold(service, 500)
	local goldBefore = profile.gold
	local eventsBefore = #emitted
	for _, cell in ipairs({ "r0c1", "r6c1", "r1c0", "r1c6", "r1c01", "lixo", "" }) do
		local result, err = service.place("archer", cell)
		assert(result == nil, "aceitou " .. cell)
		assert(err == "invalid_cell", "erro de " .. cell .. ": " .. tostring(err))
	end
	assert(profile.gold == goldBefore, "gold mudou")
	assert(next(profile.wall.cells) == nil, "celula foi criada")
	assert(#emitted == eventsBefore, "evento emitido")
end)

check("celula ocupada e recusada", function()
	local service, profile = newHarness()
	seedGold(service, 500)
	local placed = assert(service.place("archer", "r1c1"))
	assert(profile.gold == 460, "gold inicial")
	local result, err = service.place("archer", "r1c1")
	assert(result == nil and err == "cell_occupied", tostring(err))
	assert(profile.gold == 460, "gold mudou")
	assert(profile.wall.cells["r1c1"].level == 1, "celula mudou")
	assert(#placed.events == 2, "eventos do primeiro place")
end)

check("sexta armadilha e recusada (N=5)", function()
	local service, profile = newHarness()
	seedGold(service, 500)
	for col = 1, 5 do
		local result, err = service.place("archer", "r1c" .. col)
		assert(result ~= nil, tostring(err))
	end
	local goldAfterFive = profile.gold
	assert(goldAfterFive == 300, "custo de 5 arqueiros")
	local result, err = service.place("archer", "r2c1")
	assert(result == nil and err == "trap_limit", tostring(err))
	assert(profile.gold == goldAfterFive, "gold mudou na sexta")
	local count = 0
	for _ in pairs(profile.wall.cells) do
		count += 1
	end
	assert(count == 5, "celulas: " .. count)
end)

check("ouro insuficiente e recusado sem evento", function()
	local service, profile, emitted = newHarness()
	local result, err = service.place("archer", "r1c1")
	assert(result == nil and err == "insufficient_gold", tostring(err))
	assert(next(profile.wall.cells) == nil, "celula criada")
	assert(#emitted == 0, "evento emitido")
end)

check("desbloqueio por liga e recusado antes do limiar", function()
	local service, profile = newHarness()
	seedGold(service, 1000)
	local result, err = service.place("oil", "r1c1")
	assert(result == nil and err == "trap_locked", tostring(err))
	assert(next(profile.wall.cells) == nil, "celula criada")

	profile.league.points = 100
	result, err = service.place("oil", "r1c1")
	assert(result ~= nil, tostring(err))
	profile.league.points = 200
	result, err = service.place("frost", "r1c2")
	assert(result ~= nil, tostring(err))
	profile.league.points = 300
	result, err = service.place("cannon", "r1c3")
	assert(result ~= nil, tostring(err))
	assert(profile.wall.cells["r1c3"].trap == "cannon", "cannon nao persistiu")
end)

check("upgrade debita ouro, sobe nivel e emite eventos", function()
	local service, profile = newHarness()
	seedGold(service, 500)
	assert(service.place("archer", "r1c1"))
	local goldAfterPlace = profile.gold
	local result, err = service.upgrade("r1c1")
	assert(result ~= nil, tostring(err))
	assert(result.level == 2 and result.cost == 30, "upgrade 1->2")
	assert(profile.gold == goldAfterPlace - 30, "gold do upgrade")
	assert(profile.wall.cells["r1c1"].level == 2, "nivel persistiu")
	assert(#result.events == 2, "eventos")
	assert(result.events[1].name == "upgrade_bought", "upgrade_bought")
	assert(result.events[1].props.level == 2, "nivel do evento")
	assert(result.events[2].props.sink == "upgrade", "sink do upgrade")
	validateEvents(result.events)

	local second = assert(service.upgrade("r1c1"))
	assert(second.level == 3 and second.cost == 60, "upgrade 2->3")
	local goldAtMax = profile.gold
	local third, maxErr = service.upgrade("r1c1")
	assert(third == nil and maxErr == "max_level", tostring(maxErr))
	assert(profile.gold == goldAtMax, "gold mudou no max")
end)

check("remove apaga a celula e nao devolve ouro", function()
	local service, profile = newHarness()
	seedGold(service, 500)
	assert(service.place("archer", "r1c1"))
	local goldAfterPlace = profile.gold
	local result, err = service.remove("r1c1")
	assert(result ~= nil, tostring(err))
	assert(result.action == "remove" and result.trap == "archer", "resultado")
	assert(profile.wall.cells["r1c1"] == nil, "celula nao removida")
	assert(profile.gold == goldAfterPlace, "ouro devolvido")
	assert(#result.events == 0, "evento no remove")
	local again, emptyErr = service.remove("r1c1")
	assert(again == nil and emptyErr == "empty_cell", tostring(emptyErr))
end)

check("creditGold valida fonte, valor e teto", function()
	local service, profile = newHarness()
	local result, err = service.creditGold(120, "raid", BATTLE_ID)
	assert(result ~= nil, tostring(err))
	assert(profile.gold == 120, "gold raid")
	assert(result.events[1].props.battle_id == BATTLE_ID, "battle_id")
	validateEvents(result.events)

	assert(service.creditGold(80, "defense"))
	assert(service.creditGold(40, "daily"))
	assert(profile.gold == 240, "gold acumulado")

	for _, amount in ipairs({ 0, -1, 1.5 }) do
		local invalid, amountErr = service.creditGold(amount, "raid")
		assert(invalid == nil and amountErr == "invalid_amount", tostring(amountErr))
	end
	local invalidSource, sourceErr = service.creditGold(10, "refund")
	assert(invalidSource == nil and sourceErr == "invalid_source", tostring(sourceErr))

	profile.gold = ProfileSchema.MAX_GOLD - 5
	local overCap, capErr = service.creditGold(10, "raid")
	assert(overCap == nil and capErr == "gold_cap", tostring(capErr))
	assert(profile.gold == ProfileSchema.MAX_GOLD - 5, "gold mudou no teto")
end)

check("snapshot e copia defensiva; liga acompanha os pontos", function()
	local service, profile = newHarness()
	seedGold(service, 500)
	assert(service.place("archer", "r1c1"))
	local snapshot = service.snapshot()
	assert(snapshot.gold == profile.gold, "gold do snapshot")
	assert(snapshot.cells["r1c1"].trap == "archer", "celula do snapshot")
	snapshot.cells["r1c1"].level = 99
	assert(profile.wall.cells["r1c1"].level == 1, "snapshot vazou referencia")
	profile.league.points = 200
	assert(service.league() == 3, "liga do controlador")
end)

print(string.format("contrato de muralha: %d checagens, %d falhas", checks, #failures))
if #failures > 0 then
	for _, failure in ipairs(failures) do
		print("  FALHOU: " .. failure)
	end
	error("contrato de muralha quebrado")
end
print("OK: contrato de muralha passou")
