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

export type HudInsets = {
	unibarLeftW: number?,
	topRightW: number?,
	unibarH: number?,
	safeLeft: number?,
	safeRight: number?,
	safeTop: number?,
	safeBottom: number?,
}

export type HudLayout = {
	width: number,
	height: number,
	isPortrait: boolean,
	isDesktop: boolean,
	unibarReservedW: number,
	goldPill: Rect,
	wallPill: Rect,
	camBtn: Rect,
	muteBtn: Rect,
	comboBtn: Rect,
	localeBtn: Rect,
	utilityCluster: Rect,
	toolsDock: Rect,
	trapDock: Rect,
	trapCardW: number,
	trapCardH: number,
	trapCardGap: number,
	storyBtn: Rect,
	defendBtn: Rect,
	attackBtn: Rect,
	toastBanner: Rect,
	combatTopPill: Rect,
	combatBossPill: Rect,
	combatCamBtn: Rect,
	combatSpeedBtn: Rect,
	combatCloseBtn: Rect,
	combatResultCard: Rect,
	clearCenterHeight: number,
	clearArenaRatio: number,
}

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

function BuildLayout.computeHud(width: number, height: number, insets: HudInsets?): HudLayout
	local w = math.max(320, round(width))
	local h = math.max(320, round(height))
	local safeLeft = if insets and insets.safeLeft then math.max(0, round(insets.safeLeft)) else 0
	local safeRight = if insets and insets.safeRight
		then math.max(0, round(insets.safeRight))
		else 0
	local safeTop = if insets and insets.safeTop then math.max(0, round(insets.safeTop)) else 0
	local safeBottom = if insets and insets.safeBottom
		then math.max(0, round(insets.safeBottom))
		else 0
	local unibarLeftW = if insets and insets.unibarLeftW
		then math.max(0, round(insets.unibarLeftW))
		else 180
	local topRightW = if insets and insets.topRightW
		then math.max(0, round(insets.topRightW))
		else 0
	local unibarH = if insets and insets.unibarH then math.max(36, round(insets.unibarH)) else 44

	local isPortrait = h > w
	local isDesktop = w >= 1024 and h >= 620
	local padX = clamp(round(w * 0.012), 6, 14)
	local padY = clamp(round(h * 0.016), 6, 12)
	local gap = if w < 900 or h < 500 then 6 else 8
	local uGap = 4

	local minX = safeLeft + padX
	local maxX = w - safeRight - padX
	local minY = safeTop + padY
	local maxY = h - safeBottom - padY
	local usableW = math.max(240, maxX - minX)

	local pillH = 44
	local unibarEnd = safeLeft + unibarLeftW
	local row1MinX = math.max(minX, unibarEnd + if unibarLeftW > 0 then gap else 0)
	local topRightStart = w - safeRight - topRightW - if topRightW > 0 then gap else 0
	local row1MaxX = math.min(maxX, topRightStart)
	local row1AvailW = math.max(0, row1MaxX - row1MinX)

	local camW = if isDesktop then 68 else 44
	local muteW = 44
	local comboW = if isDesktop then 96 else 44
	local localeW = if isDesktop then 128 else 48
	local utilW = camW + uGap + muteW + uGap + comboW + uGap + localeW

	local utilX: number
	local utilY: number
	if row1AvailW >= utilW then
		utilX = row1MaxX - utilW
		utilY = minY
	else
		utilX = math.max(minX, maxX - utilW)
		utilY = math.max(minY + pillH + gap, safeTop + unibarH + 4)
	end

	local utilityCluster = rect(utilX, utilY, utilW, pillH)
	local camBtn = rect(utilX, utilY, camW, pillH)
	local muteBtn = rect(camBtn.x + camW + uGap, utilY, muteW, pillH)
	local comboBtn = rect(muteBtn.x + muteW + uGap, utilY, comboW, pillH)
	local localeBtn = rect(comboBtn.x + comboW + uGap, utilY, localeW, pillH)

	local goldDesiredW = clamp(round(w * 0.13), 88, 120)
	local wallDesiredW =
		clamp(round(w * (if h <= 420 then 0.23 else 0.27)), 148, if h <= 420 then 200 else 260)
	local wallMinW = 140
	local row1LeftFree = math.max(0, (utilX - gap) - row1MinX)

	local goldPill: Rect
	local wallPill: Rect
	if utilY == minY and row1LeftFree >= (goldDesiredW + gap + wallMinW) then
		local goldW = goldDesiredW
		local wallW = clamp(row1LeftFree - goldW - gap, wallMinW, wallDesiredW)
		goldPill = rect(row1MinX, minY, goldW, pillH)
		wallPill = rect(row1MinX + goldW + gap, minY, wallW, pillH)
	else
		local infoY = if utilY == minY
			then math.max(minY + pillH + gap, safeTop + unibarH + 4)
			else utilY + pillH + gap
		local goldW = clamp(round(usableW * 0.27), 86, 118)
		local wallW = math.max(120, usableW - goldW - gap)
		goldPill = rect(minX, infoY, goldW, pillH)
		wallPill = rect(minX + goldW + gap, infoY, wallW, pillH)
	end

	local topChromeBottom = math.max(
		goldPill.y + goldPill.h,
		math.max(wallPill.y + wallPill.h, utilityCluster.y + utilityCluster.h)
	)

	-- Bottom Build HUD: left tools (3x44), center trap dock (5 cards), right CTAs (Story + Defend + Attack)
	local toolCount = 3
	local toolBtn = 44
	local toolsW = toolBtn * toolCount + uGap * (toolCount - 1)
	local cardGap = 4
	local dockPadX = 4
	local cardH = if h <= 420 then 50 else 58

	local toolsDock: Rect
	local trapDock: Rect
	local storyBtn: Rect
	local defendBtn: Rect
	local attackBtn: Rect
	local cardW: number

	if usableW >= 600 then
		-- Single peripheral bottom band (Landscape phones + tablets + desktop)
		local ctaW = clamp(round(w * 0.135), 96, 128)
		local ctaH = 44
		local ctaGap = 5
		local maxDockCenterW = usableW - toolsW - ctaW - gap * 2
		local rawCardW = math.floor((maxDockCenterW - dockPadX * 2 - cardGap * 4) / 5)
		cardW = clamp(rawCardW, 48, if h <= 420 then 62 else 72)
		local dockW = cardW * 5 + cardGap * 4 + dockPadX * 2
		local dockY = maxY - cardH
		local dockCenterSpace = (maxX - ctaW - gap) - (minX + toolsW + gap)
		local dockX = minX + toolsW + gap + math.max(0, math.floor((dockCenterSpace - dockW) * 0.5))

		toolsDock = rect(minX, maxY - toolBtn, toolsW, toolBtn)
		trapDock = rect(dockX, dockY, dockW, cardH)
		storyBtn = rect(maxX - ctaW, maxY - (ctaH * 3 + ctaGap * 2), ctaW, ctaH)
		defendBtn = rect(maxX - ctaW, maxY - (ctaH * 2 + ctaGap), ctaW, ctaH)
		attackBtn = rect(maxX - ctaW, maxY - ctaH, ctaW, ctaH)
	else
		-- Narrow portrait stack: bottom trap row + compact action row + story row just above
		local maxCardW = math.floor((usableW - dockPadX * 2 - cardGap * 4) / 5)
		cardW = clamp(maxCardW, 46, 68)
		local dockW = cardW * 5 + cardGap * 4 + dockPadX * 2
		local dockY = maxY - cardH
		local dockX = minX + math.max(0, math.floor((usableW - dockW) * 0.5))

		local actionRowY = dockY - gap - 44
		local ctaAreaW = usableW - toolsW - gap
		local ctaGap = 4
		local ctaW = clamp(math.floor((ctaAreaW - ctaGap) / 2), 68, 120)
		local ctasLeft = maxX - (ctaW * 2 + ctaGap)

		toolsDock = rect(minX, actionRowY, toolsW, toolBtn)
		storyBtn = rect(ctasLeft, actionRowY - gap - 44, ctaW * 2 + ctaGap, 44)
		defendBtn = rect(ctasLeft, actionRowY, ctaW, 44)
		attackBtn = rect(ctasLeft + ctaW + ctaGap, actionRowY, ctaW, 44)
		trapDock = rect(dockX, dockY, dockW, cardH)
	end

	local bottomCenterTop = if usableW >= 600
		then trapDock.y
		else math.min(trapDock.y, math.min(defendBtn.y, storyBtn.y))
	local clearCenterHeight = math.max(0, bottomCenterTop - topChromeBottom)

	local toastW = clamp(usableW - 40, 220, 420)
	local toastH = 34
	local toastBanner = rect(
		minX + math.floor((usableW - toastW) * 0.5),
		math.max(topChromeBottom + 6, bottomCenterTop - toastH - 8),
		toastW,
		toastH
	)

	-- Combat & DropIn peripheral rectangles
	local combatReserveRight = if utilY == minY then localeW + gap else 0
	local combatTopAvail = math.max(0, row1MaxX - combatReserveRight - row1MinX)
	local combatTopW = clamp(round(w * 0.44), 200, 380)
	local combatTopPill: Rect
	if combatTopAvail >= 200 then
		local fitW = math.min(combatTopW, combatTopAvail)
		local freeCenterX = row1MinX + math.floor((combatTopAvail - fitW) * 0.5)
		combatTopPill = rect(freeCenterX, minY, fitW, pillH)
	else
		local fitW = clamp(usableW, 200, 380)
		local pillY = math.max(minY + pillH + gap, safeTop + unibarH + 4)
		combatTopPill = rect(minX + math.floor((usableW - fitW) * 0.5), pillY, fitW, pillH)
	end
	local combatBossPill =
		rect(combatTopPill.x, combatTopPill.y + combatTopPill.h + 4, combatTopPill.w, 44)

	local closeW = if w < 420 then 84 else 96
	local speedW = 54
	local combatCamW = 52
	local combatCloseBtn = rect(maxX - closeW, maxY - 44, closeW, 44)
	local combatSpeedBtn = rect(combatCloseBtn.x - gap - speedW, maxY - 44, speedW, 44)
	local combatCamBtn = rect(combatSpeedBtn.x - gap - combatCamW, maxY - 44, combatCamW, 44)

	local resW = clamp(usableW - 24, 280, 420)
	local resH = clamp(h - safeTop - safeBottom - 40, 180, 236)
	local combatResultCard = rect(round((w - resW) * 0.5), round((h - resH) * 0.5), resW, resH)

	local hudArea = goldPill.w * goldPill.h
		+ wallPill.w * wallPill.h
		+ utilityCluster.w * utilityCluster.h
		+ toolsDock.w * toolsDock.h
		+ trapDock.w * trapDock.h
		+ storyBtn.w * storyBtn.h
		+ defendBtn.w * defendBtn.h
		+ attackBtn.w * attackBtn.h
	local clearArenaRatio = clamp(1 - (hudArea / (w * h)), 0, 1)

	return {
		width = w,
		height = h,
		isPortrait = isPortrait,
		isDesktop = isDesktop,
		unibarReservedW = unibarLeftW,
		goldPill = goldPill,
		wallPill = wallPill,
		camBtn = camBtn,
		muteBtn = muteBtn,
		comboBtn = comboBtn,
		localeBtn = localeBtn,
		utilityCluster = utilityCluster,
		toolsDock = toolsDock,
		trapDock = trapDock,
		trapCardW = cardW,
		trapCardH = cardH,
		trapCardGap = cardGap,
		storyBtn = storyBtn,
		defendBtn = defendBtn,
		attackBtn = attackBtn,
		toastBanner = toastBanner,
		combatTopPill = combatTopPill,
		combatBossPill = combatBossPill,
		combatCamBtn = combatCamBtn,
		combatSpeedBtn = combatSpeedBtn,
		combatCloseBtn = combatCloseBtn,
		combatResultCard = combatResultCard,
		clearCenterHeight = clearCenterHeight,
		clearArenaRatio = clearArenaRatio,
	}
end

return BuildLayout
