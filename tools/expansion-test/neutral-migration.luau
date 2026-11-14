--!nonstrict
-- Teste de migracao neutra (GAP-010) — kit de expansao.
-- Compara o hash da parede ANTIGA (representacao congelada antes da migracao) com o hash da
-- parede MIGRADA (perfil migrado + WallService.toBattleWall), na mesma seed/wave, para
-- todos os passos 0 -> 4, 1 -> 4, 2 -> 4 e 3 -> 4.
--
-- Uso: luau tools/expansion-test/neutral-migration.luau

local Core = require("../../src/shared/sim/core")
local ProfileSchema = require("../../src/shared/data/ProfileSchema")
local TrapCatalog = require("../../src/shared/data/TrapCatalog")
local WallService = require("../../src/server/walls/WallService")
local fixtureV0 = require("../../sim/fixtures/profile-v0")
local fixtureV1 = require("../../sim/fixtures/profile-v1")
local fixtureV2 = require("../../sim/fixtures/profile-v2")
local fixtureV3 = require("../../sim/fixtures/profile-v3")

local SEED = 42
local WAVE = 70
local HP = 500

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

local function verifyMigration(label, rawFixture, expectedOldWall)
	local migrated, migrateErr = ProfileSchema.migrate(rawFixture)
	assert(migrated ~= nil, label .. ": migracao falhou: " .. tostring(migrateErr))
	assert(migrated.schemaVersion == 4, label .. ": schemaVersion != 4")
	local contentOk, contentErr = TrapCatalog.ensureProfileContent(migrated)
	assert(contentOk, label .. ": migracao de conteudo falhou: " .. tostring(contentErr))
	local migratedWall, wallErr = WallService.toBattleWall(migrated, ProfileSchema, TrapCatalog, HP)
	assert(migratedWall ~= nil, label .. ": toBattleWall falhou: " .. tostring(wallErr))

	local aliasedOldWall = {
		hp = expectedOldWall.hp,
		level = expectedOldWall.level or 1,
		traps = {},
	}
	for _, trap in ipairs(expectedOldWall.traps) do
		aliasedOldWall.traps[#aliasedOldWall.traps + 1] = {
			cell = trap.cell,
			type = TrapCatalog.TRAP_ALIASES[trap.type] or trap.type,
			level = trap.level,
			x = trap.x,
			y = trap.y,
		}
	end

	local oldHash, oldResult = hashOf(aliasedOldWall)
	local newHash, newResult = hashOf(migratedWall)
	assert(
		oldHash == newHash
			and oldResult.winner == newResult.winner
			and oldResult.wallHp == newResult.wallHp,
		label .. ": migracao NAO neutra: parede antiga e migrada divergiram"
	)
	return oldHash, oldResult
end

assert(table.isfrozen(Core.TRAP), "Core.TRAP deveria estar congelada")

verifyMigration("0->4", fixtureV0, {
	hp = HP,
	level = 1,
	traps = {
		{ cell = "r1c1", type = "cannon", level = 2 },
	},
})

verifyMigration("1->4", fixtureV1, {
	hp = HP,
	level = 1,
	traps = {
		{ cell = "r1c1", type = "oil", level = 2 },
	},
})

verifyMigration("2->4", fixtureV2, {
	hp = HP,
	level = 1,
	traps = {
		{ cell = "r1c1", type = "tar", level = 2 },
		{ cell = "r3c3", type = "archer", level = 1 },
	},
})

local oldHash, oldResult = verifyMigration("3->4", fixtureV3, {
	hp = HP,
	level = 2,
	traps = {
		{ cell = "r1c1", type = "tar", level = 2, x = 2000, y = 500 },
		{ cell = "r3c3", type = "archer", level = 1, x = 5000, y = 2500 },
	},
})

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
		oldHash,
		oldResult.winner,
		oldResult.wallHp
	)
)
print("OK: migracao neutra (0->4, 1->4, 2->4 e 3->4 preservam o comportamento)")
