--!strict
-- Temas visuais e cinematica de abordagem dos Portais da Campanha (P2).
-- Modulo 100% Luau puro (sem globais do Roblox) para permitir testes em Luau CLI.

local PortalThemes = {}

export type PortalThemeId = "rift" | "act1" | "act2" | "act3" | "act4" | "act5"

export type PortalThemeSpec = {
	id: PortalThemeId,
	label: string,
	framePrimary: { number },
	frameSecondary: { number },
	veilColor: { number },
	accentColor: { number },
	mistColor: { number },
	apronColor: { number },
}

PortalThemes.PORTAL_X = 38.0
PortalThemes.VEIL_X = 37.2
PortalThemes.THROAT_X = 36.8
PortalThemes.ENTRY_X = 21.5
PortalThemes.APPROACH_SECONDS = 0.85
PortalThemes.LEAD_IN_FRAMES = 18
PortalThemes.MIN_SCALE = 0.50
PortalThemes.MAX_SCALE = 1.00

local function freezeTheme(spec: PortalThemeSpec): PortalThemeSpec
	table.freeze(spec.framePrimary)
	table.freeze(spec.frameSecondary)
	table.freeze(spec.veilColor)
	table.freeze(spec.accentColor)
	table.freeze(spec.mistColor)
	table.freeze(spec.apronColor)
	return table.freeze(spec)
end

local RIFT_THEME = freezeTheme({
	id = "rift" :: PortalThemeId,
	label = "Cerco da Fenda",
	framePrimary = { 28, 32, 38 },
	frameSecondary = { 48, 54, 62 },
	veilColor = { 20, 184, 166 },
	accentColor = { 220, 255, 245 },
	mistColor = { 10, 74, 70 },
	apronColor = { 126, 108, 82 },
})

local THEMES: { [string]: PortalThemeSpec } = table.freeze({
	rift = RIFT_THEME,
	act1 = freezeTheme({
		id = "act1" :: PortalThemeId,
		label = "Cinzas da Fronteira",
		framePrimary = { 46, 50, 58 },
		frameSecondary = { 30, 32, 38 },
		veilColor = { 245, 158, 11 },
		accentColor = { 255, 214, 102 },
		mistColor = { 92, 58, 28 },
		apronColor = { 118, 92, 66 },
	}),
	act2 = freezeTheme({
		id = "act2" :: PortalThemeId,
		label = "Forjas de Escoria",
		framePrimary = { 42, 36, 40 },
		frameSecondary = { 68, 44, 42 },
		veilColor = { 228, 87, 46 },
		accentColor = { 255, 178, 80 },
		mistColor = { 52, 30, 28 },
		apronColor = { 108, 82, 68 },
	}),
	act3 = freezeTheme({
		id = "act3" :: PortalThemeId,
		label = "Geada do Desfiladeiro",
		framePrimary = { 72, 92, 114 },
		frameSecondary = { 140, 172, 198 },
		veilColor = { 89, 166, 230 },
		accentColor = { 200, 240, 255 },
		mistColor = { 52, 110, 158 },
		apronColor = { 112, 124, 134 },
	}),
	act4 = freezeTheme({
		id = "act4" :: PortalThemeId,
		label = "Polvora e Trincheira",
		framePrimary = { 58, 63, 70 },
		frameSecondary = { 152, 104, 52 },
		veilColor = { 234, 179, 36 },
		accentColor = { 255, 228, 132 },
		mistColor = { 84, 72, 54 },
		apronColor = { 122, 106, 80 },
	}),
	act5 = freezeTheme({
		id = "act5" :: PortalThemeId,
		label = "A Fenda Profunda",
		framePrimary = { 28, 32, 38 },
		frameSecondary = { 48, 54, 62 },
		veilColor = { 16, 198, 172 },
		accentColor = { 220, 255, 245 },
		mistColor = { 10, 74, 70 },
		apronColor = { 126, 108, 82 },
	}),
})

PortalThemes.THEMES = THEMES

function PortalThemes.resolve(themeOrAct: any): PortalThemeSpec
	if type(themeOrAct) == "number" then
		local act = math.floor(themeOrAct)
		if act >= 1 and act <= 5 then
			local found = THEMES["act" .. tostring(act)]
			if found ~= nil then
				return found
			end
		end
		return RIFT_THEME
	end
	if type(themeOrAct) == "string" then
		local direct = THEMES[themeOrAct]
		if direct ~= nil then
			return direct
		end
	end
	return RIFT_THEME
end

function PortalThemes.fromStageId(stageId: string?): PortalThemeId
	if type(stageId) == "string" then
		local actStr = string.match(stageId, "^(%d+)%-")
		if actStr ~= nil then
			local act = tonumber(actStr)
			if act ~= nil and act >= 1 and act <= 5 then
				return ("act" .. tostring(math.floor(act))) :: PortalThemeId
			end
		end
	end
	return "rift"
end

function PortalThemes.sampleFanPath(lane: number, t: number): (number, number, number)
	local clampedLane = math.clamp(lane, 1, 5)
	local u = math.clamp(t, 0, 1)
	local s = u * u * (3 - 2 * u)

	local xStart = PortalThemes.THROAT_X
	local zStart = (clampedLane - 3) * 0.95
	local xEnd = PortalThemes.ENTRY_X
	local zEnd = (clampedLane - 3) * 8.0

	local x = xStart + (xEnd - xStart) * u
	local z = zStart + (zEnd - zStart) * s

	local dsDu = 6 * u * (1 - u)
	local dxDu = xEnd - xStart
	local dzDu = (zEnd - zStart) * dsDu
	local yaw = math.atan2(dzDu, -dxDu)

	return x, z, yaw
end

function PortalThemes.approachScale(t: number): number
	local u = math.clamp(t, 0, 1)
	local s = u * u * (3 - 2 * u)
	return PortalThemes.MIN_SCALE + (PortalThemes.MAX_SCALE - PortalThemes.MIN_SCALE) * s
end

return table.freeze(PortalThemes)
