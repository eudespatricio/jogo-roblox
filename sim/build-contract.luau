--!nonstrict
-- Contrato do grid/build da S4: 25 celulas canonicas, posicoes unicas, visual por tipo,
-- protocolo/estado do cliente, HUD de debug e layout responsivo (375x812 e 720x1280).
-- Roda no Luau CLI: luau sim/build-contract.luau
local GridLayout = require("../src/shared/build/GridLayout")
local BuildProtocol = require("../src/shared/build/BuildProtocol")
local BuildClientState = require("../src/shared/build/BuildClientState")
local BuildHud = require("../src/shared/build/BuildHud")
local BuildLayout = require("../src/shared/build/BuildLayout")
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
	expect("remove", nil, "r1c1", "bad_request")
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

	profile.wall.cells.r9c9 = { trap = "archer", level = 1 }
	local filtered = assert(BuildProtocol.snapshot(profile, TrapCatalog, GridLayout))
	assert(filtered.cells.r9c9 == nil, "snapshot expos celula fora da grade")
	profile.wall.cells.r9c9 = nil
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

check("estado do cliente: modo e selecao", function()
	local state = BuildClientState.new()
	assert(state.mode == "place", "modo inicial")
	assert(state.selectedTrap == nil, "trap inicial")
	assert(BuildClientState.catalogEntry(state, "archer") == nil, "catalogo antes do snapshot")

	local ok, err = BuildClientState.setMode(state, "wizard")
	assert(not ok and err == "bad_mode", tostring(err))
	assert(state.mode == "place", "modo mudou com request invalida")

	assert(not BuildClientState.selectTrap(state, ""), "aceitou trap vazia")
	assert(BuildClientState.selectTrap(state, "archer"), "nao selecionou archer")
	assert(state.mode == "place" and state.selectedTrap == "archer", "selecao")
	assert(BuildClientState.setMode(state, "remove"), "nao trocou para remove")
	assert(state.selectedTrap == nil, "troca de modo nao limpou a trap")

	local intent, intentErr = BuildClientState.intent(state, "r1c1", GridLayout)
	assert(intent == nil and intentErr == "no_snapshot", tostring(intentErr))
end)

check("estado do cliente: intencao a partir do snapshot", function()
	local profile = newProfile()
	profile.gold = 1000
	local state = BuildClientState.new()
	BuildClientState.setSnapshot(state, BuildProtocol.snapshot(profile, TrapCatalog, GridLayout))
	local archer = assert(BuildClientState.catalogEntry(state, "archer"))
	assert(archer.cost == 40, "custo do archer")

	local noTrap, noTrapErr = BuildClientState.intent(state, "r2c2", GridLayout)
	assert(noTrap == nil and noTrapErr == "no_trap", tostring(noTrapErr))
	assert(BuildClientState.selectTrap(state, "archer"), "nao selecionou archer")

	local placeIntent = assert(BuildClientState.intent(state, "r2c2", GridLayout))
	assert(placeIntent.action == "place", "acao place")
	assert(placeIntent.trapId == "archer", "trap do place")
	assert(placeIntent.cell == "r2c2", "celula do place")

	local occupied, occupiedErr = BuildClientState.intent(state, "r1c1", GridLayout)
	assert(occupied == nil and occupiedErr == "cell_occupied", tostring(occupiedErr))
	local badCell, badCellErr = BuildClientState.intent(state, "r6c6", GridLayout)
	assert(badCell == nil and badCellErr == "bad_cell", tostring(badCellErr))
	local aliasCell, aliasCellErr = BuildClientState.intent(state, "r01c1", GridLayout)
	assert(aliasCell == nil and aliasCellErr == "bad_cell", tostring(aliasCellErr))

	assert(BuildClientState.setMode(state, "remove"), "nao trocou para remove")
	local removeIntent = assert(BuildClientState.intent(state, "r1c1", GridLayout))
	assert(removeIntent.action == "remove", "acao remove")
	assert(removeIntent.trapId == "", "remove com trap")
	local empty, emptyErr = BuildClientState.intent(state, "r2c2", GridLayout)
	assert(empty == nil and emptyErr == "empty_cell", tostring(emptyErr))

	assert(BuildClientState.setMode(state, "upgrade"), "nao trocou para upgrade")
	local upgradeIntent = assert(BuildClientState.intent(state, "r1c1", GridLayout))
	assert(upgradeIntent.action == "upgrade", "acao upgrade")
	assert(upgradeIntent.trapId == "", "upgrade com trap")
end)

check("intencao do cliente -> request -> WallService", function()
	local profile = newProfile()
	profile.gold = 1000
	local service = WallService.new({
		profile = profile,
		schema = ProfileSchema,
		catalog = TrapCatalog,
	})
	local state = BuildClientState.new()
	BuildClientState.setSnapshot(state, BuildProtocol.snapshot(profile, TrapCatalog, GridLayout))
	assert(BuildClientState.selectTrap(state, "archer"), "nao selecionou archer")

	local intent = assert(BuildClientState.intent(state, "r3c3", GridLayout))
	local valid, validationErr =
		BuildProtocol.validateRequest(GridLayout, intent.action, intent.trapId, intent.cell)
	assert(valid, tostring(validationErr))
	local result, applyErr = BuildProtocol.apply(service, intent)
	assert(result ~= nil and result.level == 1, tostring(applyErr))
	assert(profile.wall.cells.r3c3.trap == "archer", "place nao persistiu")

	BuildClientState.setSnapshot(state, BuildProtocol.snapshot(profile, TrapCatalog, GridLayout))
	local again, againErr = BuildClientState.intent(state, "r3c3", GridLayout)
	assert(again == nil and againErr == "cell_occupied", tostring(againErr))

	assert(BuildClientState.setMode(state, "upgrade"), "nao trocou para upgrade")
	local upgradeIntent = assert(BuildClientState.intent(state, "r3c3", GridLayout))
	local upgraded = assert(BuildProtocol.apply(service, upgradeIntent))
	assert(upgraded.level == 2, "upgrade nao subiu")

	assert(BuildClientState.setMode(state, "remove"), "nao trocou para remove")
	local removeIntent = assert(BuildClientState.intent(state, "r3c3", GridLayout))
	local removed = assert(BuildProtocol.apply(service, removeIntent))
	assert(removed.action == "remove" and profile.wall.cells.r3c3 == nil, "remove nao apagou")
end)

check("hud: fps, tempos e selecao", function()
	local h = BuildHud.new(100)
	assert(h.fps == 0 and h.uiSeconds == nil, "hud inicial")
	assert(BuildHud.tick(h, 100) == 0, "dt 0 contou frame")
	for i = 1, 60 do
		BuildHud.tick(h, 100 + i / 60)
	end
	assert(h.fps == 60, "fps 60 medido: " .. tostring(h.fps))

	local h30 = BuildHud.new(0)
	for i = 1, 30 do
		BuildHud.tick(h30, i / 30)
	end
	assert(h30.fps == 30, "fps 30 medido: " .. tostring(h30.fps))

	local ready = BuildHud.markReady(h30, 2.5)
	assert(ready == 2.5, "uiSeconds: " .. tostring(ready))
	assert(BuildHud.markReady(h30, 9) == 2.5, "uiSeconds reescrito")

	local text = BuildHud.formatMetrics(h30, 2.5)
	assert(string.find(text, "FPS 30", 1, true) ~= nil, text)
	assert(string.find(text, "T 2.5s", 1, true) ~= nil, text)
	assert(string.find(text, "UI 2.5s", 1, true) ~= nil, text)
	local pending = BuildHud.formatMetrics(h, 100)
	assert(string.find(pending, "UI --", 1, true) ~= nil, pending)

	assert(BuildHud.formatSelection("place", "ARQUEIRO") == "COLOCAR · ARQUEIRO", "selecao place")
	assert(BuildHud.formatSelection("place", nil) == "COLOCAR", "selecao sem trap")
	assert(BuildHud.formatSelection("remove", "ARQUEIRO") == "REMOVER", "selecao remove")
	assert(BuildHud.formatSelection("upgrade", nil) == "UPGRADE", "selecao upgrade")
end)

local function assertRectInside(layout, rect, label)
	assert(rect.w > 0 and rect.h > 0, label .. " vazio")
	assert(rect.x >= 0 and rect.y >= 0, label .. " negativo")
	assert(rect.x + rect.w <= layout.width + 0.5, label .. " estourou a largura")
	assert(rect.y + rect.h <= layout.height + 0.5, label .. " estourou a altura")
end

local function assertSeparated(a, b, label)
	local separated = a.x + a.w <= b.x + 0.01
		or b.x + b.w <= a.x + 0.01
		or a.y + a.h <= b.y + 0.01
		or b.y + b.h <= a.y + 0.01
	assert(separated, label)
end

local function assertLayout(width, height, minCell)
	local layout = BuildLayout.compute(width, height)
	assert(layout ~= nil, string.format("layout nil em %dx%d", width, height))
	assert(layout.width == width and layout.height == height, "dimensoes do layout")

	assertRectInside(layout, layout.top, "topo")
	assertRectInside(layout, layout.hud, "hud")
	assertRectInside(layout, layout.grid, "grid")
	assertRectInside(layout, layout.bottom, "painel inferior")
	assertRectInside(layout, layout.modes, "modos")
	assertRectInside(layout, layout.traps, "armadilhas")
	assertRectInside(layout, layout.status, "status")

	assertSeparated(layout.top, layout.hud, "topo x hud")
	assertSeparated(layout.hud, layout.grid, "hud x grid")
	assertSeparated(layout.grid, layout.bottom, "grid x painel inferior")
	assertSeparated(layout.modes, layout.traps, "modos x armadilhas")
	assertSeparated(layout.traps, layout.status, "armadilhas x status")

	assert(layout.grid.w == layout.grid.h, "grid nao e quadrado")
	assert(layout.grid.w >= 100, "grid pequeno: " .. tostring(layout.grid.w))
	assert(layout.cellSize >= minCell, "celula pequena: " .. tostring(layout.cellSize))
	assert(
		layout.cellSize * 5 + layout.cellPadding * 4 == layout.grid.w,
		"celulas nao preenchem o grid"
	)
	assert(layout.modeButton.h >= 44, "botao de modo baixo: " .. tostring(layout.modeButton.h))
	assert(layout.trapButton.h >= 44, "botao de trap baixo: " .. tostring(layout.trapButton.h))
	assert(layout.trapButton.w >= 44, "botao de trap estreito: " .. tostring(layout.trapButton.w))
	assert(
		layout.modeButton.w * 3 + layout.gap * 2 <= layout.modes.w + 0.01,
		"botoes de modo nao cabem"
	)
	assert(
		layout.trapButton.w * 5 + layout.gap * 4 <= layout.traps.w + 0.01,
		"botoes de trap nao cabem"
	)

	assert(layout.topFont >= 13 and layout.topFont <= 24, "fonte do topo")
	assert(layout.hudFont >= 11 and layout.hudFont <= 16, "fonte do hud")
	assert(layout.cellFont >= 10 and layout.cellFont <= 20, "fonte da celula")
	assert(layout.statusFont >= 11 and layout.statusFont <= 16, "fonte do status")
	return layout
end

check("layout 375x812 (mobile) sem sobreposicao", function()
	local layout = assertLayout(375, 812, 44)
	assert(layout.grid.y > layout.hud.y + layout.hud.h, "grid colado no hud")
	assert(layout.bottom.y > layout.grid.y + layout.grid.h, "painel em cima do grid")
	assert(layout.bottom.y + layout.bottom.h + layout.padding == 812, "painel nao fecha embaixo")
end)

check("layout 720x1280 (tablet) sem sobreposicao", function()
	local layout = assertLayout(720, 1280, 80)
	assert(layout.cellSize >= 100, "celula de tablet: " .. tostring(layout.cellSize))
	assert(layout.trapButton.h >= 80, "trap de tablet baixa")
end)

check("layout landscape e tela pequena nao estouram", function()
	assertLayout(812, 375, 20)
	assertLayout(320, 568, 44)
	assertLayout(1920, 1080, 80)
end)

check("layout recusa tela impossivel", function()
	assert(BuildLayout.compute(200, 200) == nil, "aceitou 200x200")
	assert(BuildLayout.compute(0, 800) == nil, "aceitou largura 0")
	assert(BuildLayout.compute(375, 200) == nil, "aceitou altura < 300")
end)

print(string.format("contrato de build: %d checagens, %d falhas", checks, #failures))
if #failures > 0 then
	for _, failure in ipairs(failures) do
		print("  FALHOU: " .. failure)
	end
	error("contrato de build quebrado")
end
print("OK: contrato de build passou")
