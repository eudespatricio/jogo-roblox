--!nonstrict
-- Teste de migracao neutra (GAP-010) — kit de expansao.
-- Compara o hash da parede ANTIGA (representacao congelada antes da migracao) com o hash da
-- parede MIGRADA (perfil migrado + WallService.toBattleWall), na mesma seed/wave.
--
-- Uso: luau tools/expansion-test/neutral-migration.luau
--
-- Estado atual (schema v2): prova a migracao 1 -> 2 + conteudo 1 -> 2 com
-- sim/fixtures/profile-v1.luau (parede com `oil`). No proximo schema:
--   1. congele o perfil v2 em sim/fixtures/profile-v2.luau (ou copie as cells para OLD_WALL);
--   2. troque OLD_PROFILE/OLD_WALL abaixo pelos dados congelados;
--   3. rode antes e depois do merge: o hash da parede antiga tem que ser identico ao da migrada.
-- Qualquer default de migracao com bonus (ex.: +10% de dano) muda o hash e falha aqui.

local Core = require("../../src/shared/sim/core")
local ProfileSchema = require("../../src/shared/data/ProfileSchema")
local TrapCatalog = require("../../src/shared/data/TrapCatalog")
local WallService = require("../../src/server/walls/WallService")
local fixtureV1 = require("../../sim/fixtures/profile-v1")

-- Perfil congelado antes da migracao. No proximo schema, troque por profile-v2.luau.
local OLD_PROFILE = fixtureV1

local SEED = 42
local WAVE = 70
local HP = 500

-- Parede como o perfil antigo a escrevia. Congele aqui ANTES de mudar o schema.
local OLD_WALL = {
	hp = HP,
	traps = {
		{ cell = "r1c1", type = "oil", level = 2 },
	},
}

local migrated, migrateErr = ProfileSchema.migrate(OLD_PROFILE)
assert(migrated ~= nil, "migracao falhou: " .. tostring(migrateErr))
local contentOk, contentErr = TrapCatalog.ensureProfileContent(migrated)
assert(contentOk, "migracao de conteudo falhou: " .. tostring(contentErr))
local migratedWall, wallErr = WallService.toBattleWall(migrated, ProfileSchema, TrapCatalog, HP)
assert(migratedWall ~= nil, "toBattleWall falhou: " .. tostring(wallErr))

local function hashOf(wall)
	local result = Core.Battle
		.new({
			seed = SEED,
			simVersion = Core.SIM_VERSION,
			wall = wall,
			wave = { count = WAVE },
		})
		:Run()
	return result.hash, result
end

-- O motor v3 nao conhece `oil`; injeta o alias so para reproduzir a parede antiga.
Core.TRAP.oil = Core.TRAP.tar
local oldHash, oldResult = hashOf(OLD_WALL)
Core.TRAP.oil = nil
local newHash, newResult = hashOf(migratedWall)

print(string.format("poc neutra: simVersion=%d seed=%d", Core.SIM_VERSION, SEED))
print(
	string.format(
		"  parede antiga : hash=%d winner=%s wallHp=%d",
		oldHash,
		oldResult.winner,
		oldResult.wallHp
	)
)
print(
	string.format(
		"  parede migrada: hash=%d winner=%s wallHp=%d",
		newHash,
		newResult.winner,
		newResult.wallHp
	)
)
assert(
	oldHash == newHash
		and oldResult.winner == newResult.winner
		and oldResult.wallHp == newResult.wallHp,
	"migracao NAO neutra: parede antiga e migrada divergiram"
)
print("OK: migracao neutra (default preserva o comportamento)")
