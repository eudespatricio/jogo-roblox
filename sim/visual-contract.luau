--!nonstrict
-- Contrato visual da S8: paleta do GDD, paridade com GridLayout, cobertura das 5 traps, dos
-- 6 tipos cosmeticos de horda e dos 5 bosses, orcamentos de pecas/VFX e layout mobile. Puro Luau, roda no CLI:
-- luau sim/visual-contract.luau
local VisualTheme = require("../src/shared/visual/VisualTheme")
local GridLayout = require("../src/shared/build/GridLayout")
local BuildLayout = require("../src/shared/build/BuildLayout")
local WallAssets = require("../src/shared/visual/WallAssets")
local MeshAssets = require("../src/shared/visual/MeshAssets")
local BackdropAssets = require("../src/shared/visual/BackdropAssets")
local UiAssets = require("../src/shared/visual/UiAssets")
local AudioAssets = require("../src/shared/visual/AudioAssets")

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

check("horda: 6 silhuetas cosmeticas distintas", function()
	local ids = VisualTheme.enemyIds()
	assert(#ids == 6, "esperava 6 tipos de horda, achei " .. tostring(#ids))
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

check("horda: orcamento unitParts <= 8 em todas as silhuetas", function()
	for id, spec in pairs(VisualTheme.ENEMIES) do
		assert(
			spec.parts <= VisualTheme.BUDGET.unitParts,
			string.format(
				"%s excede unitParts: %d > %d",
				id,
				spec.parts,
				VisualTheme.BUDGET.unitParts
			)
		)
	end
end)

check("tiles 3D e chevron: 25 tiles e chevron >= 0.6", function()
	assert(VisualTheme.GRID_TILES.count == 25, "esperava 25 cell tiles")
	assert(#VisualTheme.GRID_TILES.size == 3, "tamanho de cell tile")
	assert(VisualTheme.CHEVRON.size[1] >= 0.6, "chevron abaixo de 0.6")
end)

check("VFX e toque: cap de projeteis e toque >= 44px", function()
	assert(VisualTheme.VFX.maxConcurrentProjectiles == 12, "maxConcurrentProjectiles != 12")
	assert(VisualTheme.TOUCH.minTargetPx >= 44, "minTargetPx < 44")
	assert(VisualTheme.TOUCH.slopPx >= 8, "slopPx muito pequeno")
end)

check("fisica F2: debris sem raycast/touch e tier Low <= 6", function()
	assert(VisualTheme.PHYSICS_F2.debrisCanQuery == false, "debrisCanQuery deveria ser false")
	assert(VisualTheme.PHYSICS_F2.debrisCanTouch == false, "debrisCanTouch deveria ser false")
	assert(VisualTheme.PHYSICS_F2.tiers.Low <= 6, "tier Low acima de 6")
	assert(VisualTheme.PHYSICS_F2.gateChunks == 12, "gateChunks != 12")
end)

check("lanes: 5 trilhas em X (linha = lane), slots dentro da lane, sem xadrez", function()
	-- Espelha ArenaVisual: LANE_VERGE = 1.8, topo da lane 0.33, maior base de trap 5.2.
	local laneVerge = 1.8
	local laneWidth = GridLayout.CELL_SIZE - laneVerge
	assert(laneWidth >= 5.2 + 0.6, "lane estreita demais para a base de trap")
	-- Luz de colocacao (sem grade em repouso): disco hint 0.62 e selecionado 0.8 do tile.
	local tile = VisualTheme.GRID_TILES.size[3]
	assert(0.62 * tile <= laneWidth, "disco de dica vaza a lane")
	assert(
		0.8 * tile <= laneWidth and 0.8 * tile > 5.2,
		"anel selecionado: dentro da lane e > base"
	)
	local seenZ = {}
	for row = 1, GridLayout.HEIGHT do
		local _, _, z0 = GridLayout.cellPosition(row, 1)
		assert(z0 ~= nil and not seenZ[z0], "lane sem Z unico: " .. tostring(row))
		seenZ[z0] = true
		local prevX = -math.huge
		for col = 1, GridLayout.WIDTH do
			local x, _, z = GridLayout.cellPosition(row, col)
			assert(z == z0, "celula fora da lane: r" .. tostring(row) .. "c" .. tostring(col))
			assert(x > prevX, "lane nao corre em +X")
			prevX = x
		end
		local firstX = GridLayout.cellPosition(row, 1)
		assert(
			GridLayout.WALL_X < firstX - GridLayout.CELL_SIZE * 0.5,
			"muralha deve ficar a -X das celulas"
		)
	end
	-- Orcamento da arena (contagem espelhada de ArenaVisual.build, dropIn incluso).
	local tally = { island = 19, wall = 43, portal = 8, props = 44, tiles = 25, ui = 1, dropIn = 1 }
	local total = 0
	for _, count in pairs(tally) do
		total += count
	end
	assert(total <= 150, "arena estoura 150 partes: " .. tostring(total))
	assert(total <= VisualTheme.BUDGET.arenaParts, "arena estoura BUDGET.arenaParts")
end)

check("open cloud: muralha L1..L5, 6 props, 9 fauna e vale continuo publicados", function()
	assert(#WallAssets.ASSET_IDS == 5, "esperava 5 tiers de muralha")
	for tier, assetId in ipairs(WallAssets.ASSET_IDS) do
		assert(type(assetId) == "number" and assetId > 0, "WallAssets tier " .. tostring(tier))
		assert(
			WallAssets.modelName(tier) == "WALL_bastion_l" .. tostring(tier),
			"WallAssets modelName tier " .. tostring(tier)
		)
	end

	local requiredProps = {
		"tree_pine",
		"tree_oak",
		"rock_cluster",
		"siege_supply",
		"iron_brazier",
		"rift_obelisk",
	}
	for _, key in ipairs(requiredProps) do
		local id = MeshAssets.PROPS[key]
		assert(type(id) == "number" and id > 0, "prop nao publicado: " .. key)
	end

	local requiredFauna = {
		"wyvern_body",
		"wyvern_wing_l",
		"wyvern_wing_r",
		"bird_body",
		"bird_wing_l",
		"bird_wing_r",
		"stag",
		"pack_ox",
		"ram",
	}
	for _, key in ipairs(requiredFauna) do
		local id = MeshAssets.FAUNA[key]
		assert(type(id) == "number" and id > 0, "fauna nao publicada: " .. key)
	end

	assert(close(BackdropAssets.SHORE_Y, -0.20), "SHORE_Y esperado -0.20")
	assert(#BackdropAssets.ROAD_WAYPOINTS >= 4, "estrada da cidadela incompleta")
	assert(#BackdropAssets.LAYOUT >= 35, "layout de cenario reduzido")
	assert(BackdropAssets.anyPublished() == true, "BackdropAssets nao publicado")
	for _, asset in ipairs(BackdropAssets.ASSETS) do
		if asset.assetId > 0 then
			assert(
				type(asset.textureId) == "number" and asset.textureId > 0,
				"textura de backdrop nao publicada: " .. asset.key
			)
		end
	end
end)

check("open cloud: 6 classes de horda e 5 bosses publicados com specs no VisualTheme", function()
	local requiredHorde = { "runner", "brute", "swarm", "shieldbearer", "pyromancer", "sapper" }
	for _, kind in ipairs(requiredHorde) do
		local id = MeshAssets.HORDE[kind]
		assert(type(id) == "number" and id > 0, "horda nao publicada: " .. kind)
		assert(
			MeshAssets.hordeModelName(kind) == "CMD_" .. kind,
			"hordeModelName invalido: " .. kind
		)
	end

	local requiredBosses = {
		"iron_ram_colossus",
		"slag_juggernaut",
		"rime_matriarch",
		"powder_baron",
		"rift_titan",
	}
	local bossLabels = {}
	local bossIds = VisualTheme.bossIds()
	assert(#bossIds == 5, "esperava 5 bosses no VisualTheme.BOSSES, achei " .. tostring(#bossIds))
	for _, bossId in ipairs(requiredBosses) do
		local id = MeshAssets.BOSSES[bossId]
		assert(type(id) == "number" and id > 0, "boss nao publicado: " .. bossId)
		assert(
			MeshAssets.bossModelName(bossId) == "BOSS_" .. bossId,
			"bossModelName invalido: " .. bossId
		)
		local spec = VisualTheme.BOSSES[bossId]
		assert(spec ~= nil, "VisualTheme.BOSSES sem spec: " .. bossId)
		assert(type(spec.label) == "string" and #spec.label > 0, "boss sem label: " .. bossId)
		assert(not bossLabels[spec.label], "label de boss duplicado: " .. spec.label)
		bossLabels[spec.label] = true
		assert(spec.scale > 0 and spec.height > 0, "dimensoes invalidas no boss: " .. bossId)
		assert(#spec.color == 3 and #spec.accent == 3, "cores invalidas no boss: " .. bossId)
	end
end)

check("open cloud: UI thumbnail, icone e backdrop de transicao publicados", function()
	local assets = {
		{ name = "TRANSITION_BG", id = UiAssets.TRANSITION_BG_ID, url = UiAssets.TRANSITION_BG },
		{ name = "GAME_THUMBNAIL", id = UiAssets.GAME_THUMBNAIL_ID, url = UiAssets.GAME_THUMBNAIL },
		{ name = "GAME_ICON", id = UiAssets.GAME_ICON_ID, url = UiAssets.GAME_ICON },
	}
	for _, item in ipairs(assets) do
		assert(type(item.id) == "number" and item.id > 0, "UiAssets id invalido: " .. item.name)
		assert(
			type(item.url) == "string" and string.match(item.url, "^rbxassetid://%d+$") ~= nil,
			"UiAssets contentId invalido: " .. item.name
		)
	end
end)

check(
	"open cloud: AudioAssets cobre todos os cues com IDS, APPROVED_FALLBACKS e DURATION",
	function()
		local count = 0
		for cue, dur in pairs(AudioAssets.DURATION) do
			count += 1
			assert(type(dur) == "number" and dur > 0, "duracao invalida: " .. cue)
			local id = AudioAssets.IDS[cue]
			assert(
				type(id) == "string" and string.match(id, "^rbxassetid://%d+$") ~= nil,
				"AudioAssets.IDS invalido: " .. cue
			)
			local fb = AudioAssets.APPROVED_FALLBACKS[cue]
			assert(
				type(fb) == "string" and string.match(fb, "^rbxassetid://%d+$") ~= nil,
				"AudioAssets.APPROVED_FALLBACKS invalido: " .. cue
			)
		end
		assert(count == 87, "esperava 87 cues em AudioAssets, achei " .. tostring(count))
	end
)

check("hud periferico mobile: minTouch >= 44, arena livre e combatTopPill compacto", function()
	local viewports = {
		{ w = 667, h = 375, minRatio = 0.75 },
		{ w = 812, h = 375, minRatio = 0.80 },
	}
	for _, vp in ipairs(viewports) do
		local hud = BuildLayout.computeHud(vp.w, vp.h)
		assert(
			hud.clearArenaRatio >= vp.minRatio,
			string.format("%dx%d arena livre baixa", vp.w, vp.h)
		)
		assert(
			hud.clearCenterHeight >= 250,
			string.format("%dx%d corredor central < 250", vp.w, vp.h)
		)
		assert(
			hud.combatTopPill.h <= 48,
			string.format("%dx%d combatTopPill alto demais", vp.w, vp.h)
		)
		assert(hud.camBtn.h >= VisualTheme.UI.minTouch, "camBtn < minTouch")
		assert(hud.muteBtn.h >= VisualTheme.UI.minTouch, "muteBtn < minTouch")
		assert(hud.comboBtn.h >= VisualTheme.UI.minTouch, "comboBtn < minTouch")
		assert(hud.localeBtn.h >= VisualTheme.UI.minTouch, "localeBtn < minTouch")
		assert(hud.combatCamBtn.h >= VisualTheme.UI.minTouch, "combatCamBtn < minTouch")
		assert(hud.combatSpeedBtn.h >= VisualTheme.UI.minTouch, "combatSpeedBtn < minTouch")
		assert(hud.combatCloseBtn.h >= VisualTheme.UI.minTouch, "combatCloseBtn < minTouch")
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
