--!strict
-- Grade base 5x5 e mapeamento continuo arena <-> mundo 3D para construcao (P2).
-- Puro Luau: sem dependencias de Roblox, compila no CLI e no Studio.
-- Coordenadas do mundo em torno da origem: X = coluna, Z = pista/row (muralha em X = WALL_X).
-- No motor (Core.ARENA): x in [1000,9000] (colunas 2000..8000), y in [500,4500] (pistas 500..4500).

local GridLayout = {}

GridLayout.WIDTH = 5
GridLayout.HEIGHT = 5
GridLayout.CELL_SIZE = 8
GridLayout.CELL_Y = 0.6
GridLayout.MAX_ACTIVE = 5
GridLayout.MAX_ACTIVE_LIMIT = 7
GridLayout.WALL_X = -24

GridLayout.ARENA = table.freeze({
	xMin = 1000,
	xMax = 9000,
	yMin = 500,
	yMax = 4500,
	step = 250,
	minSpacing = 1000,
})
GridLayout.COLUMN_X = table.freeze({ 2000, 3500, 5000, 6500, 8000 })
GridLayout.MAX_SLOT_LENGTH = 16

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

local function isFiniteInteger(value: any): boolean
	if type(value) ~= "number" then
		return false
	end
	local n = value :: number
	return n == n and n ~= math.huge and n ~= -math.huge and n % 1 == 0
end

local function clamp(n: number, lo: number, hi: number): number
	if n < lo then
		return lo
	end
	if n > hi then
		return hi
	end
	return n
end

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
	if row < 1 or row > GridLayout.HEIGHT or col < 1 or col > GridLayout.WIDTH then
		return nil, nil
	end
	if string.format("r%dc%d", row, col) ~= cell then
		return nil, nil
	end
	return row, col
end

function GridLayout.cellPosition(row: number, col: number): (number?, number?, number?)
	if row < 1 or row > GridLayout.HEIGHT or col < 1 or col > GridLayout.WIDTH then
		return nil, nil, nil
	end
	local halfCol = (GridLayout.WIDTH + 1) / 2
	local halfRow = (GridLayout.HEIGHT + 1) / 2
	return (col - halfCol) * GridLayout.CELL_SIZE,
		GridLayout.CELL_Y,
		(row - halfRow) * GridLayout.CELL_SIZE
end

function GridLayout.cellCenter(cell: string): (number?, number?, number?)
	local row, col = GridLayout.parseCell(cell)
	if row == nil or col == nil then
		return nil, nil, nil
	end
	return GridLayout.cellPosition(row, col)
end

function GridLayout.cellToWorld(cell: string): (number?, number?, number?)
	return GridLayout.cellCenter(cell)
end

function GridLayout.cellToArenaPos(cell: string): (number?, number?)
	local row, col = GridLayout.parseCell(cell)
	if row == nil or col == nil then
		return nil, nil
	end
	return GridLayout.COLUMN_X[col], row * 1000 - 500
end

function GridLayout.arenaPosToCell(x: number, y: number): string?
	if not isFiniteInteger(x) or not isFiniteInteger(y) then
		return nil
	end
	if (y + 500) % 1000 ~= 0 then
		return nil
	end
	local row = (y + 500) / 1000
	if row < 1 or row > GridLayout.HEIGHT then
		return nil
	end
	for col = 1, GridLayout.WIDTH do
		if GridLayout.COLUMN_X[col] == x then
			return string.format("r%dc%d", row, col)
		end
	end
	return nil
end

function GridLayout.arenaPosToWorld(x: number, y: number): (number, number, number)
	local wx = (x - 5000) * GridLayout.CELL_SIZE / 1500
	local wz = (y - 2500) * GridLayout.CELL_SIZE / 1000
	return wx, GridLayout.CELL_Y, wz
end

function GridLayout.worldToArenaPos(vecOrX: any, maybeZ: number?): (number, number)
	local wx: number
	local wz: number
	if type(vecOrX) == "number" then
		wx = vecOrX
		wz = maybeZ or 0
	elseif type(vecOrX) == "table" or typeof(vecOrX) == "Vector3" then
		local v: any = vecOrX
		wx = v.X or v.x or 0
		wz = v.Z or v.z or maybeZ or 0
	else
		wx = 0
		wz = 0
	end
	local rawX = 5000 + wx * 1500 / GridLayout.CELL_SIZE
	local rawY = 2500 + wz * 1000 / GridLayout.CELL_SIZE
	local step = GridLayout.ARENA.step
	local qx = math.floor(rawX / step + 0.5) * step
	local qy = math.floor(rawY / step + 0.5) * step
	return clamp(qx, GridLayout.ARENA.xMin, GridLayout.ARENA.xMax),
		clamp(qy, GridLayout.ARENA.yMin, GridLayout.ARENA.yMax)
end

function GridLayout.isValidSlot(slot: any): boolean
	if type(slot) ~= "string" then
		return false
	end
	local s = slot :: string
	if #s == 0 or #s > GridLayout.MAX_SLOT_LENGTH then
		return false
	end
	if string.match(s, "^r%d+c%d+$") ~= nil then
		local row, col = GridLayout.parseCell(s)
		return row ~= nil and col ~= nil
	end
	return string.match(s, "^[a-z0-9_]+$") ~= nil
end

function GridLayout.validateArenaPos(x: any, y: any): (boolean, string?)
	if not isFiniteInteger(x) or not isFiniteInteger(y) then
		return false, "invalid_position"
	end
	local nx = x :: number
	local ny = y :: number
	if
		nx < GridLayout.ARENA.xMin
		or nx > GridLayout.ARENA.xMax
		or ny < GridLayout.ARENA.yMin
		or ny > GridLayout.ARENA.yMax
	then
		return false, "invalid_position"
	end
	if nx % GridLayout.ARENA.step ~= 0 or ny % GridLayout.ARENA.step ~= 0 then
		return false, "invalid_position"
	end
	return true, nil
end

function GridLayout.tooClose(ax: number, ay: number, bx: number, by: number): boolean
	return math.abs(ax - bx) < GridLayout.ARENA.minSpacing
		and math.abs(ay - by) < GridLayout.ARENA.minSpacing
end

function GridLayout.allCells(): { string }
	local out = {}
	for row = 1, GridLayout.HEIGHT do
		for col = 1, GridLayout.WIDTH do
			out[#out + 1] = string.format("r%dc%d", row, col)
		end
	end
	return out
end

function GridLayout.colorFor(trapId: string): { number }?
	return GridLayout.TRAP_COLORS[trapId]
end

function GridLayout.labelFor(trapId: string): string?
	return GridLayout.TRAP_LABELS[trapId]
end

return GridLayout
