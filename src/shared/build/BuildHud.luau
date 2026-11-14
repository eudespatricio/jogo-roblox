--!strict
-- HUD de debug da S4: FPS, tempo desde o Play e tempo ate a UI interativa.
-- Tempo de PAREDE: o RenderStepped entrega dt em segundos. Nao use os.clock() aqui — no Roblox
-- ele mede CPU time (docs oficiais), entao FPS/T/UI sairiam distorcidos. Puro Luau: o BuildClient
-- passa dt; sim/build-contract.luau prova a matematica.

local BuildHud = {}

BuildHud.FPS_WINDOW = 0.5

local I18n: any = nil
do
	if typeof(script) == "Instance" then
		local parent = (script :: any).Parent
		local sharedRoot = if parent ~= nil then parent.Parent else nil
		local i18nDir = if sharedRoot ~= nil then sharedRoot:FindFirstChild("i18n") else nil
		local mod = if i18nDir ~= nil then i18nDir:FindFirstChild("I18n") else nil
		if mod ~= nil then
			local ok, loaded = pcall(require :: any, mod)
			if ok then
				I18n = loaded
			end
		end
	else
		local ok, loaded = pcall(require :: any, "../i18n/I18n")
		if ok then
			I18n = loaded
		end
	end
end

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
	move = "MOVER",
})

local MODE_KEYS: { [string]: string } = {
	place = "mode_place",
	remove = "mode_remove",
	upgrade = "mode_upgrade",
	move = "mode_move",
}

-- "COLOCAR · ARQUEIRO" ou "REMOVER"; trapLabel nil/"" cai no modo puro.
-- Quando locale == nil, preserva MODE_LABELS ("UPGRADE") para sim/build-contract.luau.
function BuildHud.formatSelection(mode: string, trapLabel: string?, locale: string?): string
	local label: string
	if locale ~= nil and I18n ~= nil and MODE_KEYS[mode] ~= nil then
		label = I18n.t(locale, MODE_KEYS[mode])
	else
		label = BuildHud.MODE_LABELS[mode] or mode
	end
	if (mode == "place" or mode == "move") and type(trapLabel) == "string" and trapLabel ~= "" then
		return label .. " · " .. trapLabel
	end
	return label
end

function BuildHud.formatHeader(gold: number, league: number, locale: string?): string
	if I18n ~= nil then
		local loc = I18n.resolveLocale(locale)
		return string.format(
			"%s · %s · L%d",
			I18n.t(loc, "game_title"),
			I18n.t(loc, "hud_gold", gold),
			league
		)
	end
	return string.format("%d · L%d", gold, league)
end

return BuildHud
