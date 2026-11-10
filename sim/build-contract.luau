--!nonstrict
-- Contrato do grid/build da S4: 25 celulas canonicas, posicoes unicas e visual por tipo.
-- Roda no Luau CLI: luau sim/build-contract.luau
local GridLayout = require("../src/shared/build/GridLayout")
local TrapCatalog = require("../src/shared/data/TrapCatalog")

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

print(string.format("contrato de build: %d checagens, %d falhas", checks, #failures))
if #failures > 0 then
	for _, failure in ipairs(failures) do
		print("  FALHOU: " .. failure)
	end
	error("contrato de build quebrado")
end
print("OK: contrato de build passou")
