--!nonstrict
-- Contrato visual da S8: paleta do GDD, paridade com GridLayout, cobertura das 5 traps e dos
-- 3 tipos cosmeticos de horda, orcamentos de pecas/VFX e layout mobile. Puro Luau, roda no CLI:
-- luau sim/visual-contract.luau
local VisualTheme = require("../src/shared/visual/VisualTheme")
local GridLayout = require("../src/shared/build/GridLayout")
local BuildLayout = require("../src/shared/build/BuildLayout")

local failures = {}
local checks = 0

local function check(name, fn)
	checks += 1
	local ok, err = pcall(fn)
	if not ok then
		failures[#failures + 1] = name .. " :: " .. tostring(err)
	end
end

local function close(a, b)
	return math.abs(a - b) <= 0.02
end

check("paleta: ambar e verde-agua do GDD e canais 0..255", function()
	assert(VisualTheme.HEX.amber == "#F59E0B", "ambar do GDD")
	assert(VisualTheme.HEX.teal == "#14B8A6", "verde-agua do GDD")
	for name, color in pairs(VisualTheme.PALETTE) do
		assert(#color == 3, name .. " sem 3 canais")
		for index = 1, 3 do
			local value = color[index]
			assert(
				value == math.floor(value),
				name .. " canal " .. tostring(index) .. " nao inteiro"
			)
			assert(value >= 0 and value <= 255, name .. " canal fora de 0..255")
		end
	end
end)

check("trap: 5 tipos com paridade de cor e rotulo com GridLayout", function()
	local ids = VisualTheme.trapIds()
	assert(#ids == 5, "esperava 5 traps, achei " .. tostring(#ids))
	for _, id in ipairs(ids) do
		local spec = VisualTheme.TRAPS[id]
		assert(spec ~= nil, "trap sem spec: " .. id)
		assert(spec.label == GridLayout.labelFor(id), "rotulo divergente: " .. id)
		local gridColor = GridLayout.colorFor(id)
		assert(gridColor ~= nil, "GridLayout sem cor: " .. id)
		for channel = 1, 3 do
			assert(
				close(spec.color[channel] / 255, gridColor[channel]),
				string.format(
					"%s canal %d: tema=%d grid=%.3f",
					id,
					channel,
					spec.color[channel],
					gridColor[channel]
				)
			)
		end
		assert(type(spec.icon) == "string" and #spec.icon > 0, "icone ausente: " .. id)
		assert(spec.parts >= 4 and spec.parts <= 16, "orcamento de pecas: " .. id)
		assert(spec.height > 0, "altura invalida: " .. id)
	end
end)

check("horda: 3 silhuetas cosmeticas distintas", function()
	local ids = VisualTheme.enemyIds()
	assert(#ids == 3, "esperava 3 tipos de horda, achei " .. tostring(#ids))
	local labels = {}
	for _, id in ipairs(ids) do
		local spec = VisualTheme.ENEMIES[id]
		assert(spec ~= nil, "enemy sem spec: " .. id)
		assert(spec.label ~= nil and #spec.label > 0, "rotulo ausente: " .. id)
		assert(spec.parts >= 4 and spec.parts <= 10, "pecas: " .. id)
		assert(spec.scale > 0, "escala: " .. id)
		assert(not labels[spec.label], "rotulo duplicado: " .. spec.label)
		labels[spec.label] = true
	end
end)

check("UI: debug oculto por padrao, toque minimo e fontes", function()
	assert(VisualTheme.UI.debugHudDefault == false, "HUD de debug deveria nascer oculto")
	assert(VisualTheme.UI.minTouch >= 44, "alvo de toque abaixo de 44 px")
	assert(VisualTheme.UI.panelCorner >= 6, "canto de painel")
	assert(VisualTheme.UI.fontDisplay == "GothamBlack", "fonte display")
	assert(VisualTheme.UI.fontBody == "Gotham", "fonte body")
end)

check("audio: 10 cues unicos", function()
	local seen = {}
	local count = 0
	for _, cue in ipairs(VisualTheme.AUDIO.cues) do
		assert(not seen[cue], "cue duplicado: " .. cue)
		seen[cue] = true
		count += 1
	end
	assert(count == 10, "esperava 10 cues, achei " .. tostring(count))
	assert(VisualTheme.AUDIO.group == "MuralhaSFX", "SoundGroup")
end)

check("orcamentos: traps/unidades/arena/VFX", function()
	assert(VisualTheme.BUDGET.trapParts <= 12, "trapParts")
	assert(VisualTheme.BUDGET.unitParts <= 8, "unitParts")
	assert(VisualTheme.BUDGET.arenaParts <= 160, "arenaParts")
	assert(VisualTheme.BUDGET.maxUnits <= 150, "maxUnits")
	assert(VisualTheme.BUDGET.drawCalls <= 500, "drawCalls")
	assert(VisualTheme.VFX.maxParticlesPerEmitter <= 40, "particulas")
	assert(VisualTheme.VFX.maxImpactParts <= 8, "impacto")
end)

check("layout 375x812 e 720x1280 continua valido", function()
	local targets = {
		{ 375, 812 },
		{ 720, 1280 },
	}
	for _, target in ipairs(targets) do
		local layout = BuildLayout.compute(target[1], target[2])
		assert(layout ~= nil, "layout nil em " .. tostring(target[1]) .. "x" .. tostring(target[2]))
		assert(layout.cellSize >= 32, "celula pequena")
		assert(layout.modeButton.h >= 44, "botao de modo menor que 44")
		assert(layout.trapButton.h >= 44, "botao de trap menor que 44")
		assert(layout.grid.x >= 0 and layout.grid.y >= 0, "grid negativo")
		assert(layout.grid.x + layout.grid.w <= target[1], "grid estoura a largura")
	end
end)

check("materiais e tons: shade nao estoura a faixa", function()
	local lighter = VisualTheme.shade(VisualTheme.PALETTE.iron, 1.5)
	local darker = VisualTheme.shade(VisualTheme.PALETTE.iron, 0.2)
	for index = 1, 3 do
		assert(lighter[index] >= 0 and lighter[index] <= 255, "shade claro")
		assert(darker[index] >= 0 and darker[index] <= 255, "shade escuro")
	end
end)

print(string.format("contrato visual (S8): %d checagens, %d falhas", checks, #failures))
if #failures > 0 then
	for _, failure in ipairs(failures) do
		print("  FALHOU: " .. failure)
	end
	error("contrato visual quebrado")
end
print("OK: contrato visual passou")
