--!strict
-- HUD de debug da S4: FPS, tempo desde o Play e tempo ate a UI interativa.
-- Tempo de PAREDE: o RenderStepped entrega dt em segundos. Nao use os.clock() aqui — no Roblox
-- ele mede CPU time (docs oficiais), entao FPS/T/UI sairiam distorcidos. Puro Luau: o BuildClient
-- passa dt; sim/build-contract.luau prova a matematica.

local BuildHud = {}

BuildHud.FPS_WINDOW = 0.5

export type Hud = {
	frames: number,
	window: number,
	fps: number,
	elapsed: number,
	uiSeconds: number?,
}

-- `initialElapsed` cobre o tempo antes do primeiro frame (o BuildClient passa `time()`), para
-- `T`/`UI` nao comecarem em 0.0 s quando o primeiro RenderStepped chega tarde.
function BuildHud.new(initialElapsed: number?): Hud
	local elapsed = 0
	if
		type(initialElapsed) == "number"
		and initialElapsed == initialElapsed
		and initialElapsed > 0
	then
		elapsed = initialElapsed
	end
	return { frames = 0, window = 0, fps = 0, elapsed = elapsed, uiSeconds = nil }
end

-- Amostra um frame com o delta de parede (RenderStepped). dt <= 0 / NaN e ignorado.
function BuildHud.tick(hud: Hud, dt: number): number
	if type(dt) ~= "number" or dt ~= dt or dt <= 0 then
		return hud.fps
	end
	hud.elapsed += dt
	hud.frames += 1
	hud.window += dt
	if hud.window >= BuildHud.FPS_WINDOW then
		hud.fps = math.floor(hud.frames / hud.window + 0.5)
		hud.frames = 0
		hud.window = 0
	end
	return hud.fps
end

-- Marca o instante em que a UI ficou interativa (primeiro snapshot). Idempotente: o segundo
-- snapshot nao reescreve o numero que o QA anota.
function BuildHud.markReady(hud: Hud): number
	if hud.uiSeconds == nil then
		hud.uiSeconds = hud.elapsed
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
function BuildHud.formatMetrics(hud: Hud): string
	local fps = "FPS --"
	if hud.fps > 0 then
		fps = string.format("FPS %d", hud.fps)
	end
	return string.format(
		"%s · T %s · UI %s",
		fps,
		formatSeconds(hud.elapsed),
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
