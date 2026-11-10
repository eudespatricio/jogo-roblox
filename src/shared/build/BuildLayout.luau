--!strict
-- Layout responsivo da UI de build da S4 (puro Luau, sem API do Roblox).
-- Recebe a area util em px (root.AbsoluteSize) e devolve retangulos absolutos para topo,
-- HUD, grid e painel inferior. O grid e sempre quadrado: UIGridLayout com CellSize em
-- escala distorcia as celulas em telas nao quadradas (bug do scaffold da S4).
-- O BuildClient so aplica os retangulos; sim/build-contract.luau prova 375x812, 720x1280,
-- landscape e telas pequenas (sem sobreposicao e com alvo de toque >= 44 px).

local BuildLayout = {}

export type Rect = { x: number, y: number, w: number, h: number }
export type Button = { w: number, h: number, gap: number, font: number }

export type Layout = {
	width: number,
	height: number,
	padding: number,
	gap: number,
	innerPadding: number,
	top: Rect,
	topFont: number,
	hud: Rect,
	hudFont: number,
	grid: Rect,
	cellSize: number,
	cellPadding: number,
	cellFont: number,
	bottom: Rect,
	modes: Rect,
	modeButton: Button,
	traps: Rect,
	trapButton: Button,
	status: Rect,
	statusFont: number,
}

local function round(value: number): number
	return math.floor(value + 0.5)
end

local function clamp(value: number, minimum: number, maximum: number): number
	if value < minimum then
		return minimum
	end
	if value > maximum then
		return maximum
	end
	return value
end

local function rect(x: number, y: number, w: number, h: number): Rect
	return { x = round(x), y = round(y), w = round(w), h = round(h) }
end

-- `nil` quando a tela e pequena demais para desenhar topo + HUD + grid + painel sem sobrepor.
-- O cliente trata nil mantendo o status de carregamento (nao existe device alvo abaixo disso).
function BuildLayout.compute(width: number, height: number): Layout?
	if type(width) ~= "number" or type(height) ~= "number" then
		return nil
	end
	if width ~= width or height ~= height then
		return nil
	end
	if width < 240 or height < 300 then
		return nil
	end

	local base = math.min(width, height)
	local padding = clamp(round(base * 0.03), 10, 20)
	local gap = clamp(round(base * 0.012), 4, 10)
	local innerPadding = clamp(round(padding * 0.75), 8, 16)

	local topHeight = clamp(round(base * 0.11), 40, 64)
	local hudHeight = clamp(round(topHeight * 0.5), 18, 30)
	local modeHeight = clamp(round(base * 0.12), 44, 56)
	local trapHeight = clamp(round(base * 0.15), 52, 96)
	local statusHeight = clamp(round(base * 0.05), 18, 30)
	local bottomHeight = innerPadding
		+ modeHeight
		+ gap
		+ trapHeight
		+ gap
		+ statusHeight
		+ innerPadding

	local top = rect(padding, padding, width - 2 * padding, topHeight)
	local hud = rect(padding, top.y + top.h + 4, width - 2 * padding, hudHeight)
	local bottom = rect(padding, height - padding - bottomHeight, width - 2 * padding, bottomHeight)

	local hudBottom = hud.y + hud.h
	local available = bottom.y - hudBottom
	local maxSide = math.min(width - 2 * padding, available - 2 * gap)
	if maxSide < 60 then
		return nil
	end

	local cellPadding = clamp(round(maxSide * 0.012), 3, 8)
	local cellSize = math.floor((maxSide - cellPadding * 4) / 5)
	local gridSide = cellSize * 5 + cellPadding * 4
	local grid = rect(
		padding + (width - 2 * padding - gridSide) / 2,
		hudBottom + gap + (available - 2 * gap - gridSide) / 2,
		gridSide,
		gridSide
	)

	local modes = rect(
		bottom.x + innerPadding,
		bottom.y + innerPadding,
		bottom.w - 2 * innerPadding,
		modeHeight
	)
	local traps = rect(modes.x, modes.y + modeHeight + gap, modes.w, trapHeight)
	local status =
		rect(modes.x, bottom.y + bottom.h - innerPadding - statusHeight, modes.w, statusHeight)

	local layout: Layout = {
		width = width,
		height = height,
		padding = padding,
		gap = gap,
		innerPadding = innerPadding,
		top = top,
		topFont = clamp(round(base * 0.04), 13, 24),
		hud = hud,
		hudFont = clamp(round(base * 0.035), 11, 16),
		grid = grid,
		cellSize = cellSize,
		cellPadding = cellPadding,
		cellFont = clamp(round(cellSize * 0.26), 10, 20),
		bottom = bottom,
		modes = modes,
		modeButton = {
			w = (modes.w - gap * 2) / 3,
			h = modeHeight,
			gap = gap,
			font = clamp(round(modeHeight * 0.34), 12, 20),
		},
		traps = traps,
		trapButton = {
			w = (traps.w - gap * 4) / 5,
			h = trapHeight,
			gap = gap,
			font = clamp(round(trapHeight * 0.26), 10, 18),
		},
		status = status,
		statusFont = clamp(round(statusHeight * 0.62), 11, 16),
	}
	return layout
end

return BuildLayout
