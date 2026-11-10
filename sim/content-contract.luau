--!nonstrict
-- Contrato de conteudo (S3.4): CONTENT_VERSION persistido, aliases/repair e gate no WallService.
-- Roda no Luau CLI: luau sim/content-contract.luau
local ProfileSchema = require("../src/shared/data/ProfileSchema")
local TrapCatalog = require("../src/shared/data/TrapCatalog")
local WallService = require("../src/server/walls/WallService")
local Core = require("../src/shared/sim/core")
local fixtureV1 = require("./fixtures/profile-v1")

local failures = {}
local checks = 0

local function check(name, fn)
	checks += 1
	local ok, err = pcall(fn)
	if not ok then
		failures[#failures + 1] = name .. " :: " .. tostring(err)
	end
end

local function migrated()
	local profile, err = ProfileSchema.migrate(fixtureV1)
	assert(profile ~= nil, "migracao de schema falhou: " .. tostring(err))
	assert(profile.schemaVersion == 2, "schemaVersion != 2")
	assert(profile.contentVersion == 1, "contentVersion legado != 1")
	return profile
end

check("catalogo v2, 5 tipos e politica de simVersion", function()
	assert(TrapCatalog.CONTENT_VERSION == 2, "CONTENT_VERSION != 2")
	assert(Core.SIM_VERSION == 3, "SIM_VERSION != 3")
	assert(#TrapCatalog.TRAP_IDS == 5, "esperava 5 tipos: " .. #TrapCatalog.TRAP_IDS)
	assert(TrapCatalog.TRAPS.tar ~= nil, "tar ausente")
	assert(TrapCatalog.TRAPS.oil == nil, "oil deveria ter sido renomeada")
	assert(TrapCatalog.TRAP_ALIASES.oil == "tar", "alias oil -> tar ausente")
	assert(TrapCatalog.TRAPS.catapult ~= nil, "catapult ausente")

	local names = {}
	for _, trapId in ipairs(Core.TRAP_NAMES) do
		names[trapId] = true
	end
	for _, trapId in ipairs(TrapCatalog.TRAP_IDS) do
		assert(names[trapId], "catalogo sem tipo no motor: " .. trapId)
	end
	local coreCount = 0
	for _ in pairs(Core.TRAP) do
		coreCount += 1
	end
	assert(coreCount == #TrapCatalog.TRAP_IDS, "Core.TRAP != TRAP_IDS")
end)

check("ensureProfileContent repara oil -> tar e sobe a versao", function()
	local profile = migrated()
	local ok, err, changed = TrapCatalog.ensureProfileContent(profile)
	assert(ok, tostring(err))
	assert(changed == true, "deveria ter mudado")
	assert(profile.contentVersion == 2, "contentVersion nao subiu")
	assert(profile.wall.cells.r1c1.trap == "tar", "oil nao virou tar")
	assert(profile.wall.cells.r1c1.level == 2, "level perdido no repair")

	local okAgain, errAgain, changedAgain = TrapCatalog.ensureProfileContent(profile)
	assert(okAgain, tostring(errAgain))
	assert(changedAgain == false, "segunda migracao deveria ser no-op")
	assert(profile.contentVersion == 2, "versao mudou no no-op")
end)

check("contentVersion futura e recusada sem mutar", function()
	local profile = migrated()
	profile.contentVersion = 3
	local ok, err, changed = TrapCatalog.ensureProfileContent(profile)
	assert(not ok and err == "content_future", tostring(err))
	assert(changed == false, "mutou perfil futuro")
	assert(profile.contentVersion == 3, "versao futura foi alterada")
	assert(profile.wall.cells.r1c1.trap == "oil", "reparou perfil futuro")
end)

check("contentVersion invalida e recusada", function()
	local profile: any = migrated()
	local values: { any } = { 0, -1, 1.5, "2" }
	for _, value in ipairs(values) do
		profile.contentVersion = value
		local ok, err = TrapCatalog.ensureProfileContent(profile)
		assert(not ok and err == "contentVersion invalido", tostring(err))
	end
	profile.contentVersion = nil
	local ok, err = TrapCatalog.ensureProfileContent(profile)
	assert(not ok and err == "contentVersion invalido", tostring(err))
end)

check("trap desconhecida falha fechado e nao muta", function()
	local profile = migrated()
	profile.wall.cells.r2c1 = { trap = "tesla", level = 1 }
	local ok, err, changed = TrapCatalog.ensureProfileContent(profile)
	assert(not ok, "aceitou trap desconhecida")
	assert(string.find(tostring(err), "tesla", 1, true) ~= nil, tostring(err))
	assert(changed == false, "mutou perfil invalido")
	assert(profile.contentVersion == 1, "versao mudou no invalido")
	assert(profile.wall.cells.r1c1.trap == "oil", "reparou antes de validar")
end)

check("WallService exige contentVersion do catalogo", function()
	local profile = migrated()
	local ok, err = WallService.validateWall(profile, ProfileSchema, TrapCatalog)
	assert(not ok and err == "content_version", tostring(err))

	local fixedOk, fixedErr = TrapCatalog.ensureProfileContent(profile)
	assert(fixedOk, tostring(fixedErr))
	local wallOk, wallErr = WallService.validateWall(profile, ProfileSchema, TrapCatalog)
	assert(wallOk, tostring(wallErr))
end)

check("migracao 1->2 + conteudo preserva o hash da parede", function()
	local profile = migrated()
	local ok, err = TrapCatalog.ensureProfileContent(profile)
	assert(ok, tostring(err))
	local newWall, wallErr = WallService.toBattleWall(profile, ProfileSchema, TrapCatalog, 500)
	assert(newWall ~= nil, tostring(wallErr))
	local oldWall = { hp = 500, traps = { { cell = "r1c1", type = "oil", level = 2 } } }

	local function hashOf(wall)
		return Core.Battle
			.new({
				seed = 42,
				simVersion = Core.SIM_VERSION,
				wall = wall,
				wave = { count = 70 },
			})
			:Run().hash
	end

	-- O motor v3 nao conhece mais `oil`; injeta o alias so no teste para simular a
	-- parede antiga (mesmas estatisticas de `tar`) e limpa em seguida.
	Core.TRAP.oil = Core.TRAP.tar
	local oldOk, oldHash = pcall(hashOf, oldWall)
	Core.TRAP.oil = nil
	assert(oldOk, tostring(oldHash))
	assert(oldHash == hashOf(newWall), "migracao mudou o hash da parede")
end)

print(string.format("contrato de conteudo: %d checagens, %d falhas", checks, #failures))
if #failures > 0 then
	for _, failure in ipairs(failures) do
		print("  FALHOU: " .. failure)
	end
	error("contrato de conteudo quebrado")
end
print("OK: contrato de conteudo passou")
