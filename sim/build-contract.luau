--!nonstrict
-- Contrato do grid/build da S4: 25 celulas canonicas, posicoes unicas e visual por tipo.
-- Roda no Luau CLI: luau sim/build-contract.luau
local GridLayout = require("../src/shared/build/GridLayout")
local BuildProtocol = require("../src/shared/build/BuildProtocol")
local TrapCatalog = require("../src/shared/data/TrapCatalog")
local ProfileSchema = require("../src/shared/data/ProfileSchema")
local WallService = require("../src/server/walls/WallService")
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

check("grid 5x5 com 25 celulas canonicas", function()
	assert(GridLayout.WIDTH == 5 and GridLayout.HEIGHT == 5, "grid != 5x5")
	assert(GridLayout.CELL_SIZE == 8, "CELL_SIZE")
	assert(GridLayout.MAX_ACTIVE == 5, "MAX_ACTIVE")
	local cells = GridLayout.allCells()
	assert(#cells == 25, "celulas: " .. #cells)
	local seen = {}
	for _, cell in ipairs(cells) do
		assert(not seen[cell], "celula repetida: " .. cell)
		seen[cell] = true
		local row, col = GridLayout.parseCell(cell)
		assert(row ~= nil and col ~= nil, "parse falhou: " .. cell)
		assert(GridLayout.cellName(row, col) == cell, "ida e volta falhou: " .. cell)
	end
	assert(GridLayout.parseCell("r01c1") == nil, "aceitou alias r01c1")
	assert(GridLayout.parseCell("r6c1") == nil, "aceitou r6c1")
	assert(GridLayout.cellName(0, 1) == nil, "aceitou linha 0")
end)

check("posicoes unicas e simetricas", function()
	local seen = {}
	for _, cell in ipairs(GridLayout.allCells()) do
		local x, y, z = GridLayout.cellCenter(cell)
		assert(x ~= nil and y ~= nil and z ~= nil, "posicao nil: " .. cell)
		assert(y == GridLayout.CELL_Y, "altura: " .. cell)
		assert(x >= -16 and x <= 16 and z >= -16 and z <= 16, "fora do grid: " .. cell)
		local key = string.format("%.1f:%.1f", x, z)
		assert(not seen[key], "posicao repetida: " .. key)
		seen[key] = true
	end
	local x1 = GridLayout.cellCenter("r1c1")
	local x5 = GridLayout.cellCenter("r5c5")
	assert(x1 == -16 and x5 == 16, "extremos do grid")
	assert(GridLayout.cellPosition(3, 3) == 0, "centro deveria ser 0 em X")
end)

check("cada tipo do catalogo tem cor e rotulo", function()
	local labels = {}
	for _, trapId in ipairs(TrapCatalog.TRAP_IDS) do
		local color = GridLayout.colorFor(trapId)
		assert(color ~= nil and #color == 3, "cor ausente: " .. trapId)
		local label = GridLayout.labelFor(trapId)
		assert(type(label) == "string" and #label > 0, "rotulo ausente: " .. trapId)
		assert(not labels[label], "rotulo repetido: " .. label)
		labels[label] = true
	end
	assert(GridLayout.colorFor("wizard") == nil, "aceitou tipo desconhecido")
	assert(GridLayout.labelFor("wizard") == nil, "aceitou label desconhecido")
end)

local function newProfile()
	local profile = assert(ProfileSchema.migrate(fixtureV1))
	local ok, err = TrapCatalog.ensureProfileContent(profile)
	assert(ok, tostring(err))
	return profile
end

check("protocolo valida request", function()
	local function valid(action, trapId, cell)
		return BuildProtocol.validateRequest(GridLayout, action, trapId, cell)
	end
	assert(valid("place", "archer", "r1c1"))
	assert(valid("remove", "", "r1c1"))
	assert(valid("upgrade", "", "r1c1"))
	local function expect(action, trapId, cell, expected)
		local ok, err = valid(action, trapId, cell)
		assert(not ok and err == expected, tostring(err))
	end
	expect("wizard", "", "r1c1", "bad_action")
	expect("place", "", "r1c1", "bad_request")
	expect("place", "archer", "r01c1", "invalid_cell")
	expect("place", "archer", nil, "bad_request")
	expect("place", nil, "r1c1", "bad_request")
end)

check("snapshot do protocolo e defensivo", function()
	local profile = newProfile()
	profile.gold = 500
	local snapshot = BuildProtocol.snapshot(profile, TrapCatalog, GridLayout)
	assert(snapshot ~= nil, "snapshot nil")
	assert(snapshot.gold == 500, "gold")
	assert(snapshot.contentVersion == 2, "contentVersion")
	assert(snapshot.cells.r1c1.trap == "tar", "tar")
	assert(snapshot.cells.r1c1.level == 2, "level")
	assert(snapshot.league == 1, "liga")
	assert(#snapshot.catalog == 5, "catalogo: " .. #snapshot.catalog)
	local catapult = nil
	for _, entry in ipairs(snapshot.catalog) do
		if entry.id == "catapult" then
			catapult = entry
		end
	end
	assert(catapult ~= nil and catapult.cost == 180 and catapult.unlockLeague == 5, "catapult")
	snapshot.cells.r1c1.trap = "wizard"
	assert(profile.wall.cells.r1c1.trap == "tar", "snapshot vazou referencia")
	assert(BuildProtocol.snapshot(nil, TrapCatalog, GridLayout) == nil, "aceitou perfil nil")
end)

check("apply executa place/remove/upgrade", function()
	local profile = newProfile()
	profile.gold = 1000
	local service = WallService.new({
		profile = profile,
		schema = ProfileSchema,
		catalog = TrapCatalog,
	})
	local placed, placeErr = BuildProtocol.apply(service, {
		action = "place",
		trapId = "archer",
		cell = "r2c2",
	})
	assert(placed ~= nil and placed.action == "place", tostring(placeErr))
	assert(profile.wall.cells.r2c2.trap == "archer", "place nao persistiu")
	local upgraded, upgradeErr = BuildProtocol.apply(service, {
		action = "upgrade",
		trapId = "",
		cell = "r2c2",
	})
	assert(upgraded ~= nil and upgraded.level == 2, tostring(upgradeErr))
	local removed, removeErr = BuildProtocol.apply(service, {
		action = "remove",
		trapId = "",
		cell = "r2c2",
	})
	assert(removed ~= nil and removed.action == "remove", tostring(removeErr))
	assert(profile.wall.cells.r2c2 == nil, "remove nao apagou")
	local bad, badErr = BuildProtocol.apply(service, {
		action = "wizard",
		trapId = "",
		cell = "r2c2",
	})
	assert(bad == nil and badErr == "bad_action", tostring(badErr))
end)

print(string.format("contrato de build: %d checagens, %d falhas", checks, #failures))
if #failures > 0 then
	for _, failure in ipairs(failures) do
		print("  FALHOU: " .. failure)
	end
	error("contrato de build quebrado")
end
print("OK: contrato de build passou")
