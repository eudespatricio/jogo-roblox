--!strict
-- HUD de debug da S4: FPS (janela de 0.5 s), tempo desde o Play e tempo ate a UI interativa.
-- Puro Luau: o BuildClient passa os.clock(); sim/build-contract.luau prova a matematica.
-- O HUD e de QA (S4 §6): "UI x.xs" e o numero do criterio "Play ate UI interativa <= 30 s".

local BuildHud = {}

BuildHud.FPS_WINDOW = 0.5

export type Hud = {
	startedAt: number,
	lastAt: number,
	frames: number,
	window: number,
	fps: number,
	uiSeconds: number?,
}

local function round(value: number): number
	return math.floor(value + 0.5)
end

function BuildHud.new(now: number): Hud
	assert(type(now) == "number" and now == now, "BuildHud.new: now invalido")
	return { startedAt = now, lastAt = now, frames = 0, window = 0, fps = 0, uiSeconds = nil }
end

-- Amostra um frame. `now` e absoluto (os.clock); dt <= 0 e ignorado (primeiro frame/pausa).
function BuildHud.tick(hud: Hud, now: number): number
	local dt = now - hud.lastAt
	hud.lastAt = now
	if dt <= 0 then
		return hud.fps
	end
	hud.frames += 1
	hud.window += dt
	if hud.window >= BuildHud.FPS_WINDOW then
		hud.fps = round(hud.frames / hud.window)
		hud.frames = 0
		hud.window = 0
	end
	return hud.fps
end

function BuildHud.elapsed(hud: Hud, now: number): number
	return math.max(0, now - hud.startedAt)
end

-- Marca o instante em que a UI ficou interativa (primeiro snapshot). Idempotente: o segundo
-- snapshot nao reescreve o numero que o QA anota.
function BuildHud.markReady(hud: Hud, now: number): number
	if hud.uiSeconds == nil then
		hud.uiSeconds = BuildHud.elapsed(hud, now)
	end
	return hud.uiSeconds :: number
end

local function formatSeconds(value: number?): string
	if value == nil then
		return "--"
	end
	return string.format("%.1fs", math.max(0, value))
end

-- "FPS 60 · T 12.3s · UI 2.1s"; antes do primeiro frame/snapshot vira "FPS --" / "UI --".
function BuildHud.formatMetrics(hud: Hud, now: number): string
	local fps = "FPS --"
	if hud.fps > 0 then
		fps = string.format("FPS %d", hud.fps)
	end
	return string.format(
		"%s · T %s · UI %s",
		fps,
		formatSeconds(BuildHud.elapsed(hud, now)),
		formatSeconds(hud.uiSeconds)
	)
end

BuildHud.MODE_LABELS = table.freeze({
	place = "COLOCAR",
	remove = "REMOVER",
	upgrade = "UPGRADE",
})

-- "COLOCAR · ARQUEIRO" ou "REMOVER"; trapLabel nil/"" cai no modo puro.
function BuildHud.formatSelection(mode: string, trapLabel: string?): string
	local label = BuildHud.MODE_LABELS[mode] or mode
	if mode == "place" and type(trapLabel) == "string" and trapLabel ~= "" then
		return label .. " · " .. trapLabel
	end
	return label
end

return BuildHud
