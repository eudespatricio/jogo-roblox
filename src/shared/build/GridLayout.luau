--!strict
-- Geometria e contrato visual do grid 5x5 da S4 (cena/build).
-- Puro Luau: o cliente converte as posicoes para Vector3/Color3; o contrato headless
-- (sim/build-contract.luau) garante 25 celulas canonicas e uma cor/rotulo por tipo.
-- Linha = lane; coluna = profundidade (c1 junto da muralha, c5 junto do spawn).

local GridLayout = {}

GridLayout.WIDTH = 5
GridLayout.HEIGHT = 5
GridLayout.CELL_SIZE = 8
GridLayout.CELL_Y = 0.6
GridLayout.MAX_ACTIVE = 5
GridLayout.WALL_X = -24

GridLayout.TRAP_COLORS = table.freeze({
	archer = { 0.35, 0.72, 0.35 },
	tar = { 0.72, 0.55, 0.2 },
	frost = { 0.35, 0.65, 0.9 },
	cannon = { 0.55, 0.55, 0.6 },
	catapult = { 0.8, 0.35, 0.3 },
})

GridLayout.TRAP_LABELS = table.freeze({
	archer = "ARQUEIRO",
	tar = "PICHE",
	frost = "GELO",
	cannon = "CANHAO",
	catapult = "CATAPULTA",
})

function GridLayout.cellName(row: number, col: number): string?
	if row % 1 ~= 0 or col % 1 ~= 0 then
		return nil
	end
	if row < 1 or row > GridLayout.HEIGHT or col < 1 or col > GridLayout.WIDTH then
		return nil
	end
	return string.format("r%dc%d", row, col)
end

function GridLayout.parseCell(cell: string): (number?, number?)
	if type(cell) ~= "string" then
		return nil, nil
	end
	local rowText, colText = string.match(cell, "^r(%d+)c(%d+)$")
	if rowText == nil or colText == nil then
		return nil, nil
	end
	local row = tonumber(rowText)
	local col = tonumber(colText)
	if row == nil or col == nil then
		return nil, nil
	end
	if GridLayout.cellName(row, col) ~= cell then
		return nil, nil
	end
	return row, col
end

-- Posicao no mundo (studs). X = profundidade (c1 muralha, c5 spawn); Z = lane.
function GridLayout.cellPosition(row: number, col: number): (number?, number?, number?)
	if GridLayout.cellName(row, col) == nil then
		return nil, nil, nil
	end
	local x = (col - (GridLayout.WIDTH + 1) / 2) * GridLayout.CELL_SIZE
	local z = (row - (GridLayout.HEIGHT + 1) / 2) * GridLayout.CELL_SIZE
	return x, GridLayout.CELL_Y, z
end

function GridLayout.cellCenter(cell: string): (number?, number?, number?)
	local row, col = GridLayout.parseCell(cell)
	if row == nil or col == nil then
		return nil, nil, nil
	end
	return GridLayout.cellPosition(row, col)
end

function GridLayout.allCells(): { string }
	local cells: { string } = {}
	for row = 1, GridLayout.HEIGHT do
		for col = 1, GridLayout.WIDTH do
			local cell = GridLayout.cellName(row, col)
			assert(cell ~= nil)
			cells[#cells + 1] = cell :: string
		end
	end
	return cells
end

function GridLayout.colorFor(trapId: string): { number }?
	return GridLayout.TRAP_COLORS[trapId]
end

function GridLayout.labelFor(trapId: string): string?
	return GridLayout.TRAP_LABELS[trapId]
end

return GridLayout
