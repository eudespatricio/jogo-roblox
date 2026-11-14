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
	assert(snapshot.contentVersion == 3, "contentVersion")
	assert(snapshot.wallLevel == 1 and snapshot.wallHp == 500, "wallLevel/wallHp")
	assert(snapshot.activeTrapLimit == 5 and snapshot.maxTrapLevel == 5, "limits")
	assert(snapshot.equipped.theme == "theme_default", "equipped")
	assert(#snapshot.wallLevels == 5, "wallLevels")
	assert(snapshot.cells.r1c1.trap == "tar", "tar")
	assert(snapshot.cells.r1c1.level == 2, "level")
	assert(snapshot.cells.r1c1.x == 2000 and snapshot.cells.r1c1.y == 500, "r1c1 x/y")
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
	assert(upgraded.cost == 30, "custo 1->2")
	BuildClientState.setSnapshot(state, BuildProtocol.snapshot(profile, TrapCatalog, GridLayout))
	assert(BuildClientState.upgradeCost(state, "r3c3") == 60, "UI deveria exibir 60 no L2")
	local low, high = BuildClientState.upgradeRange(BuildClientState.catalogEntry(state, "archer"))
	assert(low == 30 and high == 120, "faixa 30/120")

	assert(BuildClientState.setMode(state, "remove"), "nao trocou para remove")
	local removeIntent = assert(BuildClientState.intent(state, "r3c3", GridLayout))
	local removed = assert(BuildProtocol.apply(service, removeIntent))
	assert(removed.action == "remove" and profile.wall.cells.r3c3 == nil, "remove nao apagou")
end)

check("hud: fps, tempos e selecao (dt de parede)", function()
	local h = BuildHud.new()
	assert(h.fps == 0 and h.uiSeconds == nil and h.elapsed == 0, "hud inicial")
	assert(BuildHud.tick(h, 0) == 0, "dt 0 contou frame")
	assert(BuildHud.tick(h, -1) == 0, "dt negativo contou frame")
	for _ = 1, 60 do
		BuildHud.tick(h, 1 / 60)
	end
	assert(h.fps == 60, "fps 60 medido: " .. tostring(h.fps))
	assert(math.abs(h.elapsed - 1) < 0.001, "elapsed: " .. tostring(h.elapsed))

	local h30 = BuildHud.new()
	for _ = 1, 30 do
		BuildHud.tick(h30, 1 / 30)
	end
	assert(h30.fps == 30, "fps 30 medido: " .. tostring(h30.fps))

	local withOffset = BuildHud.new(42)
	assert(withOffset.elapsed == 42, "offset inicial: " .. tostring(withOffset.elapsed))
	BuildHud.tick(withOffset, 1)
	assert(withOffset.elapsed == 43, "offset + dt: " .. tostring(withOffset.elapsed))
	assert(BuildHud.markReady(withOffset) == 43, "offset + ready")

	local ready = BuildHud.new()
	BuildHud.tick(ready, 2.5)
	local uiSeconds = BuildHud.markReady(ready)
	assert(uiSeconds == 2.5, "uiSeconds: " .. tostring(uiSeconds))
	assert(BuildHud.markReady(ready) == 2.5, "uiSeconds reescrito")

	local text = BuildHud.formatMetrics(h30)
	assert(string.find(text, "FPS 30", 1, true) ~= nil, text)
	assert(string.find(text, "T 1.0s", 1, true) ~= nil, text)
	local readyText = BuildHud.formatMetrics(ready)
	assert(string.find(readyText, "UI 2.5s", 1, true) ~= nil, readyText)
	local pending = BuildHud.formatMetrics(h)
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

check(
	"arenaPosToWorld e worldToArenaPos fazem ida-e-volta nos 25 centros e quantizam step 250",
	function()
		for _, cell in ipairs(GridLayout.allCells()) do
			local ax, ay = GridLayout.cellToArenaPos(cell)
			local wx, wy, wz = GridLayout.arenaPosToWorld(ax :: number, ay :: number)
			local cx, cy, cz = GridLayout.cellToWorld(cell)
			assert(wx == cx and wy == cy and wz == cz, "divergencia mundo em " .. cell)
			local rx, ry = GridLayout.worldToArenaPos({ X = wx, Y = wy, Z = wz })
			assert(rx == ax and ry == ay, "roundtrip falhou em " .. cell)
		end
		local qx, qy = GridLayout.worldToArenaPos(0.5, 0.2)
		assert(qx % 250 == 0 and qy % 250 == 0, "nao quantizou para 250")
		local cx1, cy1 = GridLayout.worldToArenaPos(-999, 999)
		assert(cx1 == 1000 and cy1 == 4500, "nao clampou na arena")
	end
)

check("protocolo P2: place livre, move, upgrade_wall e equip_cosmetic", function()
	local profile = ProfileSchema.template()
	profile.contentVersion = TrapCatalog.CONTENT_VERSION
	profile.gold = 1000
	profile.cosmetics.theme_obsidian = true
	local service =
		WallService.new({ profile = profile, schema = ProfileSchema, catalog = TrapCatalog })

	local placeReq =
		assert(BuildProtocol.validateRequest(GridLayout, "place", "archer", "", 1250, 750))
	local placed, placeErr = BuildProtocol.apply(service, placeReq)
	assert(placed ~= nil, tostring(placeErr))
	assert(placed.slot == "t1" and profile.wall.cells.t1.x == 1250, "placeAt via protocol")

	local moveReq = assert(BuildProtocol.validateRequest(GridLayout, "move", "", "t1", 2500, 1500))
	local moved, moveErr = BuildProtocol.apply(service, moveReq)
	assert(moved ~= nil, tostring(moveErr))
	assert(profile.wall.cells.t1.x == 2500 and profile.wall.cells.t1.y == 1500, "move via protocol")

	local wallReq = assert(BuildProtocol.validateRequest(GridLayout, "upgrade_wall", nil, nil))
	local upWall, upErr = BuildProtocol.apply(service, wallReq)
	assert(upWall ~= nil, tostring(upErr))
	assert(profile.wall.level == 2, "upgrade_wall via protocol")

	local eqReq = assert(
		BuildProtocol.validateRequest(GridLayout, "equip_cosmetic", "theme", "theme_obsidian")
	)
	local eqRes, eqErr = BuildProtocol.apply(service, eqReq)
	assert(eqRes ~= nil, tostring(eqErr))
	assert(profile.equipped.theme == "theme_obsidian", "equip_cosmetic via protocol")

	local state = BuildClientState.new()
	BuildClientState.setSnapshot(state, BuildProtocol.snapshot(profile, TrapCatalog, GridLayout))
	BuildClientState.selectTrap(state, "archer")
	local intentAt = assert(BuildClientState.intentAt(state, 5000, 2500, GridLayout))
	assert(intentAt.action == "place" and intentAt.x == 5000 and intentAt.y == 2500, "intentAt")
	local intentMove = assert(BuildClientState.intentMove(state, "t1", 3500, 2500, GridLayout))
	assert(intentMove.action == "move" and intentMove.slot == "t1", "intentMove")
end)

check("hud periferico mobile + safe insets: 9 viewports sem sobreposicao", function()
	local function overlapsRect(a, b)
		if a.w <= 0 or a.h <= 0 or b.w <= 0 or b.h <= 0 then
			return false
		end
		return a.x < (b.x + b.w) and (a.x + a.w) > b.x and a.y < (b.y + b.h) and (a.y + a.h) > b.y
	end
	local function insideViewport(r, w, h)
		return r.x >= 0 and r.y >= 0 and (r.x + r.w) <= w and (r.y + r.h) <= h
	end

	local cases = {
		{ w = 667, h = 375 },
		{ w = 800, h = 360 },
		{ w = 812, h = 375 },
		{ w = 734, h = 372 },
		{ w = 375, h = 812 },
		{ w = 320, h = 568 },
		{ w = 720, h = 1280 },
		{ w = 1280, h = 720 },
		{ w = 1920, h = 1080 },
		{ w = 667, h = 375, insets = { unibarLeftW = 148, topRightW = 56, unibarH = 44 } },
	}

	for _, c in ipairs(cases) do
		local label = string.format("%dx%d", c.w, c.h)
		local hud = BuildLayout.computeHud(c.w, c.h, c.insets)
		local unibarW = if c.insets and c.insets.unibarLeftW then c.insets.unibarLeftW else 180
		local topRightW = if c.insets and c.insets.topRightW then c.insets.topRightW else 0
		local unibarH = if c.insets and c.insets.unibarH then c.insets.unibarH else 44
		local unibarRect = { x = 0, y = 0, w = unibarW, h = unibarH }
		local topRightRect = { x = c.w - topRightW, y = 0, w = topRightW, h = unibarH }

		assert(
			hud.goldPill.w <= 124,
			label .. " goldPill larga demais: " .. tostring(hud.goldPill.w)
		)
		assert(hud.trapCardW >= 44 and hud.trapCardH >= 44, label .. " trapCard < 44")

		local allInteractive = {
			{ "goldPill", hud.goldPill },
			{ "wallPill", hud.wallPill },
			{ "camBtn", hud.camBtn },
			{ "muteBtn", hud.muteBtn },
			{ "comboBtn", hud.comboBtn },
			{ "localeBtn", hud.localeBtn },
			{ "toolsDock", hud.toolsDock },
			{ "trapDock", hud.trapDock },
			{ "storyBtn", hud.storyBtn },
			{ "defendBtn", hud.defendBtn },
			{ "attackBtn", hud.attackBtn },
			{ "combatTopPill", hud.combatTopPill },
			{ "combatBossPill", hud.combatBossPill },
			{ "combatCamBtn", hud.combatCamBtn },
			{ "combatSpeedBtn", hud.combatSpeedBtn },
			{ "combatCloseBtn", hud.combatCloseBtn },
			{ "combatResultCard", hud.combatResultCard },
		}
		for _, pair in ipairs(allInteractive) do
			local name, r = pair[1], pair[2]
			assert(r.h >= 44 and r.w >= 44, label .. " " .. name .. " < 44")
			assert(insideViewport(r, c.w, c.h), label .. " " .. name .. " fora da tela")
		end

		local buildSet = {
			{ "unibar", unibarRect },
			{ "topRight", topRightRect },
			{ "goldPill", hud.goldPill },
			{ "wallPill", hud.wallPill },
			{ "utilityCluster", hud.utilityCluster },
			{ "toolsDock", hud.toolsDock },
			{ "trapDock", hud.trapDock },
			{ "storyBtn", hud.storyBtn },
			{ "defendBtn", hud.defendBtn },
			{ "attackBtn", hud.attackBtn },
		}
		for i = 1, #buildSet - 1 do
			for j = i + 1, #buildSet do
				assert(
					not overlapsRect(buildSet[i][2], buildSet[j][2]),
					label .. " build overlap " .. buildSet[i][1] .. " vs " .. buildSet[j][1]
				)
			end
		end

		local combatSet = {
			{ "unibar", unibarRect },
			{ "topRight", topRightRect },
			{ "combatTopPill", hud.combatTopPill },
			{ "combatBossPill", hud.combatBossPill },
			{ "combatCamBtn", hud.combatCamBtn },
			{ "combatSpeedBtn", hud.combatSpeedBtn },
			{ "combatCloseBtn", hud.combatCloseBtn },
		}
		for i = 1, #combatSet - 1 do
			for j = i + 1, #combatSet do
				assert(
					not overlapsRect(combatSet[i][2], combatSet[j][2]),
					label .. " combat overlap " .. combatSet[i][1] .. " vs " .. combatSet[j][1]
				)
			end
		end
	end

	local iphoneSE = BuildLayout.computeHud(667, 375)
	assert(iphoneSE.clearArenaRatio >= 0.75, "667x375 clearArenaRatio < 0.75")
	assert(iphoneSE.clearCenterHeight >= 250, "667x375 clearCenterHeight < 250")

	local iphoneX = BuildLayout.computeHud(812, 375)
	assert(iphoneX.clearArenaRatio >= 0.80, "812x375 clearArenaRatio < 0.80")
	assert(iphoneX.clearCenterHeight >= 250, "812x375 clearCenterHeight < 250")
end)

print(string.format("contrato de build: %d checagens, %d falhas", checks, #failures))
if #failures > 0 then
	for _, failure in ipairs(failures) do
		print("  FALHOU: " .. failure)
	end
	error("contrato de build quebrado")
end
print("OK: contrato de build passou")
