--!strict
-- Tema visual da S8 (diorama de guerra de brinquedo). Puro Luau: o cliente converte as cores
-- para Color3/Material; o contrato `sim/visual-contract.luau` pina a paleta do GDD, a paridade
-- com GridLayout e os orcamentos de pecas/VFX. Nenhum numero aqui altera gameplay, schema ou sim.

local VisualTheme = {}

VisualTheme.NAME = "diorama-guerra-brinquedo"
VisualTheme.VERSION = 1

-- Paleta do GDD §7: defensores em ambar/ferro; atacantes em verde-agua frio.
VisualTheme.PALETTE = table.freeze({
	amber = { 245, 158, 11 },
	amberBright = { 255, 199, 64 },
	iron = { 58, 63, 70 },
	ironDark = { 32, 35, 40 },
	teal = { 20, 184, 166 },
	tealDark = { 10, 74, 70 },
	wood = { 139, 90, 43 },
	woodDark = { 92, 58, 28 },
	parchment = { 245, 230, 200 },
	ink = { 18, 20, 24 },
	danger = { 228, 87, 46 },
	grass = { 70, 94, 55 },
	stone = { 92, 96, 102 },
	stoneDark = { 52, 56, 62 },
	white = { 245, 245, 245 },
})

VisualTheme.HEX = table.freeze({
	amber = "#F59E0B",
	teal = "#14B8A6",
	iron = "#3A3F46",
	wood = "#8B5A2B",
	parchment = "#F5E6C8",
	danger = "#E4572E",
})

-- Uma entrada por trap do catalogo (5 tipos). `icon` e uma letra/forma de fallback para a UI
-- desenhada com Frames; quando houver upload de icones, o id entra em `iconAsset`.
VisualTheme.TRAPS = table.freeze({
	archer = {
		label = "ARQUEIRO",
		icon = "A",
		color = { 89, 184, 89 },
		accent = { 245, 158, 11 },
		parts = 9,
		height = 5.2,
	},
	tar = {
		label = "PICHE",
		icon = "P",
		color = { 184, 140, 51 },
		accent = { 52, 56, 62 },
		parts = 5,
		height = 1.2,
	},
	frost = {
		label = "GELO",
		icon = "G",
		color = { 89, 166, 230 },
		accent = { 180, 235, 255 },
		parts = 7,
		height = 4.4,
	},
	cannon = {
		label = "CANHAO",
		icon = "C",
		color = { 140, 140, 153 },
		accent = { 228, 87, 46 },
		parts = 8,
		height = 3.2,
	},
	catapult = {
		label = "CATAPULTA",
		icon = "K",
		color = { 204, 89, 77 },
		accent = { 245, 158, 11 },
		parts = 11,
		height = 4.8,
	},
})

-- Tipos cosmeticos de horda. O motor nao tem classe: o cliente escolhe por lane/indice e
-- anima localmente; o resultado deterministico continua sendo o do servidor.
VisualTheme.ENEMIES = table.freeze({
	runner = {
		label = "CORREDOR",
		color = { 20, 184, 166 },
		dark = { 10, 74, 70 },
		scale = 0.85,
		parts = 6,
	},
	brute = {
		label = "BRUTO",
		color = { 13, 148, 136 },
		dark = { 8, 47, 46 },
		scale = 1.35,
		parts = 8,
	},
	swarm = {
		label = "ENXAME",
		color = { 45, 212, 191 },
		dark = { 15, 118, 110 },
		scale = 0.65,
		parts = 5,
	},
})

VisualTheme.MOTION = table.freeze({
	hitFlash = 0.08,
	death = 0.35,
	projectileMin = 0.18,
	projectileMax = 0.55,
	shakeSmall = 0.12,
	shakeLarge = 0.24,
	pulseSeconds = 1.2,
	bobAmplitude = 0.12,
	bobSpeed = 7,
})

VisualTheme.VFX = table.freeze({
	maxParticlesPerEmitter = 40,
	maxEmittersPerTrap = 2,
	maxConcurrentProjectiles = 12,
	maxImpactParts = 8,
	maxDustParts = 10,
	impactLifetime = 0.55,
})

VisualTheme.UI = table.freeze({
	minTouch = 44,
	debugHudDefault = false,
	panelCorner = 10,
	buttonCorner = 8,
	barCorner = 6,
	fontDisplay = "GothamBlack",
	fontBody = "Gotham",
	fontMono = "Code",
})

VisualTheme.AUDIO = table.freeze({
	group = "MuralhaSFX",
	cues = table.freeze({
		"ui_click",
		"ui_deny",
		"trap_place",
		"trap_upgrade",
		"projectile",
		"impact",
		"gate_hit",
		"victory",
		"defeat",
		"horn",
	}),
})

VisualTheme.BUDGET = table.freeze({
	trapParts = 12,
	unitParts = 8,
	arenaParts = 160,
	maxUnits = 150,
	drawCalls = 500,
})

-- Utilitario puro para o cliente: tom mais escuro/claro sem depender de Color3.
function VisualTheme.shade(color: { number }, factor: number): { number }
	local result = {}
	for index = 1, 3 do
		local value = color[index] * factor
		if value < 0 then
			value = 0
		elseif value > 255 then
			value = 255
		end
		result[index] = math.floor(value + 0.5)
	end
	return result
end

function VisualTheme.trapIds(): { string }
	local ids = {}
	for id in pairs(VisualTheme.TRAPS) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	return ids
end

function VisualTheme.enemyIds(): { string }
	local ids = {}
	for id in pairs(VisualTheme.ENEMIES) do
		ids[#ids + 1] = id
	end
	table.sort(ids)
	return ids
end

return VisualTheme
