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
local CameraFraming = require("../src/shared/visual/CameraFraming")
local PortalThemes = require("../src/shared/visual/PortalThemes")
local HeadlessMock = require("../src/shared/visual/HeadlessRobloxMock")
local cliRequire: any = require
local HordeKit = cliRequire("../src/client/visual/HordeKit")
local Vfx = cliRequire("../src/client/visual/Vfx")

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

check("horda: 8 silhuetas cosmeticas distintas (6 terrestres + wisp + drake)", function()
	local ids = VisualTheme.enemyIds()
	assert(#ids == 8, "esperava 8 tipos de horda, achei " .. tostring(#ids))
	local labels = {}
	for _, id in ipairs(ids) do
		local spec = VisualTheme.ENEMIES[id]
		assert(spec ~= nil, "enemy sem spec: " .. id)
		assert(spec.label ~= nil and #spec.label > 0, "rotulo ausente: " .. id)
		assert(spec.parts >= 4 and spec.parts <= 12, "pecas: " .. id)
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
	assert(VisualTheme.BUDGET.flyingUnitParts <= 12, "flyingUnitParts")
	assert(VisualTheme.BUDGET.arenaParts <= 185, "arenaParts")
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

check("horda: orcamento unitParts <= 8 (terrestres/wisp) e <= 12 (drake voador)", function()
	for id, spec in pairs(VisualTheme.ENEMIES) do
		local maxParts = if id == "drake"
			then VisualTheme.BUDGET.flyingUnitParts
			else VisualTheme.BUDGET.unitParts
		assert(
			spec.parts <= maxParts,
			string.format("%s excede orcamento de partes: %d > %d", id, spec.parts, maxParts)
		)
	end
end)

check("horda aerea e campeao: wisp/drake flying, hover +3.2 studs e crista 1.28x", function()
	local wisp = VisualTheme.ENEMIES.wisp
	local drake = VisualTheme.ENEMIES.drake
	assert(wisp ~= nil and wisp.flying == true, "wisp deve ter flying=true")
	assert(drake ~= nil and drake.flying == true, "drake deve ter flying=true")
	assert(wisp.parts <= VisualTheme.AERIAL.wispMaxParts, "wisp acima de 8 partes")
	assert(drake.parts <= VisualTheme.AERIAL.drakeMaxParts, "drake acima de 12 partes")

	for _, groundId in ipairs({ "runner", "brute", "swarm", "shieldbearer", "pyromancer", "sapper" }) do
		local spec = VisualTheme.ENEMIES[groundId]
		assert(spec ~= nil and spec.flying ~= true, groundId .. " nao deveria voar")
	end

	assert(close(VisualTheme.AERIAL.hoverY, 3.2), "hoverY esperado 3.2")
	assert(
		close(
			VisualTheme.aerialHoverOffset(false, 0, PortalThemes.THROAT_X, PortalThemes.ENTRY_X),
			0
		),
		"terrestre nao deve ter hover"
	)
	assert(
		close(
			VisualTheme.aerialHoverOffset(
				true,
				PortalThemes.THROAT_X,
				PortalThemes.THROAT_X,
				PortalThemes.ENTRY_X
			),
			0
		),
		"hover na garganta do portal deve ser 0"
	)
	assert(
		close(
			VisualTheme.aerialHoverOffset(
				true,
				PortalThemes.ENTRY_X,
				PortalThemes.THROAT_X,
				PortalThemes.ENTRY_X
			),
			3.2
		),
		"hover em ENTRY_X deve ser +3.2"
	)
	assert(
		close(
			VisualTheme.aerialHoverOffset(true, -10, PortalThemes.THROAT_X, PortalThemes.ENTRY_X),
			3.2
		),
		"hover na arena deve permanecer +3.2"
	)
	local prevHover = 0
	for step = 1, 10 do
		local x = PortalThemes.THROAT_X
			+ (PortalThemes.ENTRY_X - PortalThemes.THROAT_X) * (step / 10)
		local h =
			VisualTheme.aerialHoverOffset(true, x, PortalThemes.THROAT_X, PortalThemes.ENTRY_X)
		assert(h >= prevHover, "rampa de hover nao monotona")
		prevHover = h
	end

	assert(close(VisualTheme.CHAMPION.scale, 1.28), "escala de Campeao esperada 1.28")
	assert(VisualTheme.CHAMPION.crestParts >= 1, "Champion crestParts ausente")
	assert(#VisualTheme.CHAMPION.haloColor == 3, "haloColor RGB")
	assert(#VisualTheme.CHAMPION.accentColor == 3, "accentColor RGB")
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
	local tally = {
		island = 19,
		fanManifold = 17,
		wall = 43,
		portal = 8,
		props = 44,
		tiles = 25,
		ui = 2,
		dropIn = 1,
	}
	local total = 0
	for _, count in pairs(tally) do
		total += count
	end
	assert(total <= 175, "arena estoura 175 partes: " .. tostring(total))
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
		assert(
			hud.combatBossPill.h <= 48 and hud.combatBossPill.y == hud.combatTopPill.y,
			string.format("%dx%d combatBossPill fora da faixa superior", vp.w, vp.h)
		)
		assert(hud.logBtn.h >= VisualTheme.UI.minTouch, "logBtn < minTouch")
		assert(hud.camBtn.h >= VisualTheme.UI.minTouch, "camBtn < minTouch")
		assert(hud.muteBtn.h >= VisualTheme.UI.minTouch, "muteBtn < minTouch")
		assert(hud.comboBtn.h >= VisualTheme.UI.minTouch, "comboBtn < minTouch")
		assert(hud.localeBtn.h >= VisualTheme.UI.minTouch, "localeBtn < minTouch")
		assert(hud.combatCamBtn.h >= VisualTheme.UI.minTouch, "combatCamBtn < minTouch")
		assert(hud.combatSpeedBtn.h >= VisualTheme.UI.minTouch, "combatSpeedBtn < minTouch")
		assert(hud.combatCloseBtn.h >= VisualTheme.UI.minTouch, "combatCloseBtn < minTouch")
	end
end)

check("camera multiplataforma: 10 viewports x 3 modos x 3 angulos no corredor util", function()
	local viewports = {
		{ 852, 393 },
		{ 812, 375 },
		{ 667, 375 },
		{ 1024, 768 },
		{ 1108, 768 },
		{ 1194, 834 },
		{ 1366, 768 },
		{ 1920, 1080 },
		{ 1440, 900 },
		{ 390, 844 },
	}
	local modes = { "build", "raid", "dropin" }
	local angles = { "diagonal", "corridor", "wall" }

	for _, vp in ipairs(viewports) do
		local w, h = vp[1], vp[2]
		local hud = BuildLayout.computeHud(w, h)
		for _, mode in ipairs(modes) do
			local topHudBottom = if mode == "build"
				then math.max(
					hud.goldPill.y + hud.goldPill.h,
					hud.utilityCluster.y + hud.utilityCluster.h
				)
				else hud.combatTopPill.y + hud.combatTopPill.h
			local botHudTop = if mode == "build" then hud.trapDock.y else (h - 52)
			local minV = math.min(0.25, topHudBottom / h)
			local maxV = math.max(0.75, botHudTop / h)

			for _, angle in ipairs(angles) do
				local isMobile = CameraFraming.isCompactMobile(w, h)
				local spec = CameraFraming.compute(w, h, mode, angle)
				assert(spec.fov >= 38 and spec.fov <= 78, "fov fora da faixa")
				assert(spec.zoom >= 1.0 and spec.zoom <= 2.15, "zoom fora da faixa")
				if isMobile and w > h then
					local dx = spec.eye.x - spec.target.x
					local dy = spec.eye.y - spec.target.y
					local dz = spec.eye.z - spec.target.z
					local dist = math.sqrt(dx * dx + dy * dy + dz * dz)
					local maxDist = if mode == "build" then 76.0 else 73.0
					assert(
						dist <= maxDist,
						string.format(
							"%dx%d %s/%s mobile distante demais: dist=%.1f > %.1f",
							w,
							h,
							mode,
							angle,
							dist,
							maxDist
						)
					)
				end
				local anchors = CameraFraming.anchorsForViewport(w, h, angle)
				assert(#anchors >= 16, "ancoras insuficientes para " .. angle)
				local vLo = if isMobile and w > h then 0.03 else (minV - 0.02)
				local vHi = if isMobile and w > h then 0.96 else (maxV + 0.02)
				for idx, pt in ipairs(anchors) do
					local u, v, depth = CameraFraming.projectPoint(spec, w, h, pt)
					assert(
						depth > 1.0,
						string.format(
							"%dx%d %s/%s anchor %d depth=%.2f",
							w,
							h,
							mode,
							angle,
							idx,
							depth
						)
					)
					assert(
						u >= 0.02 and u <= 0.98,
						string.format("%dx%d %s/%s anchor %d u=%.3f", w, h, mode, angle, idx, u)
					)
					assert(
						v >= vLo and v <= vHi,
						string.format(
							"%dx%d %s/%s anchor %d v=%.3f fora de [%.3f..%.3f]",
							w,
							h,
							mode,
							angle,
							idx,
							v,
							vLo,
							vHi
						)
					)
				end
			end
		end
	end
end)

check(
	"portal fan manifold: garganta em X>=36, continuidade nas 5 lanes e escala 0.50->1.00",
	function()
		assert(close(PortalThemes.PORTAL_X, 38.0), "PORTAL_X != 38")
		assert(close(PortalThemes.ENTRY_X, 21.5), "ENTRY_X != 21.5")
		assert(close(PortalThemes.MIN_SCALE, 0.50), "MIN_SCALE != 0.50")
		assert(close(PortalThemes.MAX_SCALE, 1.00), "MAX_SCALE != 1.00")

		for lane = 1, 5 do
			local x0, z0, yaw0 = PortalThemes.sampleFanPath(lane, 0)
			assert(x0 >= 36.0, "garganta X < 36 na lane " .. tostring(lane))
			assert(math.abs(z0) <= 2.5, "garganta |Z| > 2.5 na lane " .. tostring(lane))
			assert(close(yaw0, 0), "yaw inicial != 0 na lane " .. tostring(lane))

			local x1, z1, yaw1 = PortalThemes.sampleFanPath(lane, 1)
			local expectedZ1 = -16 + (lane - 1) * 8
			assert(close(x1, 21.5), "entrada X != 21.5 na lane " .. tostring(lane))
			assert(close(z1, expectedZ1), "entrada Z divergente na lane " .. tostring(lane))
			assert(close(yaw1, 0), "yaw final != 0 na lane " .. tostring(lane))
		end

		assert(close(PortalThemes.approachScale(0), 0.50), "approachScale(0) != 0.50")
		assert(close(PortalThemes.approachScale(1), 1.00), "approachScale(1) != 1.00")
		local prevScale = PortalThemes.approachScale(0)
		for step = 1, 20 do
			local curScale = PortalThemes.approachScale(step / 20)
			assert(curScale >= prevScale, "approachScale nao monotono no passo " .. tostring(step))
			prevScale = curScale
		end
	end
)

check("open cloud: 5 portais de campanha + rift e paleta low-poly publicados", function()
	assert(
		type(MeshAssets.LOWPOLY_PALETTE_TEXTURE_ID) == "number"
			and MeshAssets.LOWPOLY_PALETTE_TEXTURE_ID > 0,
		"LOWPOLY_PALETTE_TEXTURE_ID nao publicado"
	)
	local keys = { "rift", "act1", "act2", "act3", "act4", "act5" }
	local seenIds = {}
	local seenLabels = {}
	for _, key in ipairs(keys) do
		local spec = PortalThemes.THEMES[key]
		assert(spec ~= nil, "PortalThemes sem spec: " .. key)
		assert(spec.id == key, "spec.id divergente: " .. key)
		assert(type(spec.label) == "string" and #spec.label > 0, "label vazio: " .. key)
		assert(not seenLabels[spec.label], "label duplicado em PortalThemes: " .. spec.label)
		seenLabels[spec.label] = true
		assert(
			#spec.framePrimary == 3 and #spec.veilColor == 3 and #spec.accentColor == 3,
			"cores RGB: " .. key
		)

		local assetId = MeshAssets.PORTALS[key]
		assert(type(assetId) == "number" and assetId > 0, "portal nao publicado: " .. key)
		assert(not seenIds[assetId], "assetId de portal duplicado: " .. key)
		seenIds[assetId] = true
	end
	for act = 1, 5 do
		local key = "act" .. tostring(act)
		assert(PortalThemes.resolve(act).id == key, "resolve(act) falhou: " .. key)
		assert(
			PortalThemes.fromStageId(tostring(act) .. "-3") == key,
			"fromStageId falhou: " .. key
		)
		assert(
			MeshAssets.portalModelName(key) == "PORTAL_" .. key,
			"portalModelName falhou: " .. key
		)
	end
	assert(MeshAssets.portalModelName("rift") == "PROP_rift_portal", "portalModelName(rift)")
end)

check(
	"orcamento detalhado da arena: fanManifold (17) + portal monumental dentro de 185 partes",
	function()
		local tally = {
			island = 19,
			fanManifold = 17,
			wall = 43,
			portal = 8,
			props = 44,
			tiles = 25,
			ui = 2,
			dropIn = 1,
		}
		local total = 0
		for _, count in pairs(tally) do
			total += count
		end
		assert(total == 159, "esperava 159 partes procedurais na arena, achei " .. tostring(total))
		assert(VisualTheme.BUDGET.arenaParts == 185, "BUDGET.arenaParts != 185")
		assert(total <= VisualTheme.BUDGET.arenaParts, "arena excede BUDGET.arenaParts")
	end
)

check("open cloud: 5 bosses x 5 partes articuladas (25 slots) em MeshAssets.BOSS_PARTS", function()
	local bosses = {
		"iron_ram_colossus",
		"slag_juggernaut",
		"rime_matriarch",
		"powder_baron",
		"rift_titan",
	}
	local partKeys = { "torso", "arm_r", "arm_l", "leg_l", "leg_r" }
	local seenIds = {}
	local count = 0
	for _, bossId in ipairs(bosses) do
		local parts = MeshAssets.BOSS_PARTS[bossId]
		assert(parts ~= nil, "MeshAssets.BOSS_PARTS ausente para " .. bossId)
		for _, partKey in ipairs(partKeys) do
			local assetId = (parts :: any)[partKey]
			assert(
				type(assetId) == "number" and assetId > 0 and assetId == math.floor(assetId),
				string.format("assetId invalido em BOSS_PARTS.%s.%s", bossId, partKey)
			)
			assert(
				not seenIds[assetId],
				string.format("assetId duplicado em BOSS_PARTS.%s.%s", bossId, partKey)
			)
			seenIds[assetId] = true
			assert(
				MeshAssets.bossPartModelName(bossId, partKey) == "BOSS_" .. bossId .. "_" .. partKey,
				string.format("bossPartModelName divergente: %s/%s", bossId, partKey)
			)
			count += 1
		end
	end
	assert(count == 25, "esperava 25 sub-malhas em BOSS_PARTS, achei " .. tostring(count))
end)

check(
	"HordeKit boss rig: 5 slots, DYING, VULNERABLE sem afundar e hitSquashBoss axial sem distorcao",
	function()
		local bosses = {
			"iron_ram_colossus",
			"slag_juggernaut",
			"rime_matriarch",
			"powder_baron",
			"rift_titan",
		}
		local slotKeys = { "torso", "armR", "armL", "legL", "legR" }
		for _, bossId in ipairs(bosses) do
			local scene = HeadlessMock.Instance.new("Folder")
			HeadlessMock.setTime(100.0)
			HeadlessMock.clearDelays()
			local boss = HordeKit.createBoss(bossId, scene, HeadlessMock.CFrame.identity)
			assert(boss ~= nil and boss.model ~= nil, "createBoss falhou: " .. bossId)
			assert(boss.model.PrimaryPart == boss.rootPart, "PrimaryPart != rootPart: " .. bossId)
			for _, sk in ipairs(slotKeys) do
				assert(
					type(boss.slots[sk]) == "table" and #boss.slots[sk] >= 1,
					string.format("slot %s vazio em %s", sk, bossId)
				)
				assert(
					boss.mountedSlots[sk] == false,
					string.format("mountedSlots.%s deveria iniciar false em %s", sk, bossId)
				)
			end

			-- Estado MARCH em repouso: salva posicoes e tamanhos base
			HordeKit.stepBoss(boss, 100.0, "MARCH", false)
			assert(boss.deathStartAt == nil, "deathStartAt nao deveria existir em MARCH")
			local restRootPos = boss.rootPart.CFrame.Position
			local baseSizes = {}
			for _, sk in ipairs(slotKeys) do
				baseSizes[sk] = {}
				for i, entry in ipairs(boss.slots[sk]) do
					baseSizes[sk][i] = entry.part.Size
				end
			end

			-- VULNERABLE: stagger aterrado, sem afundamento -0.78 no subsolo
			HordeKit.stepBoss(boss, 101.0, "VULNERABLE", false)
			for _, legSlot in ipairs({ "legL", "legR" }) do
				for _, entry in ipairs(boss.slots[legSlot]) do
					assert(
						entry.part.Position.Y >= 0.4,
						string.format(
							"%s %s afundou em VULNERABLE: Y=%.3f",
							bossId,
							legSlot,
							entry.part.Position.Y
						)
					)
				end
			end
			for _, entry in ipairs(boss.slots.torso) do
				assert(
					entry.part.Position.Y > boss.rigMetrics.hipY - 0.5,
					string.format(
						"%s torso afundou em VULNERABLE: Y=%.3f",
						bossId,
						entry.part.Position.Y
					)
				)
			end

			-- hitSquashBoss: knockback axial e preservacao uniforme de tamanhos (sem rubber sxz/sy)
			HeadlessMock.setTime(102.0)
			HordeKit.stepBoss(boss, 102.0, "MARCH", false)
			HordeKit.hitSquashBoss(boss)
			assert(boss.squashed == true, "hitSquashBoss nao ativou squashed: " .. bossId)
			local knockedPos = boss.rootPart.CFrame.Position
			local knockDist = (knockedPos - restRootPos).Magnitude
			assert(
				knockDist >= 0.25,
				string.format("%s hitSquashBoss sem knockback axial: %.3f", bossId, knockDist)
			)
			for _, sk in ipairs(slotKeys) do
				for i, entry in ipairs(boss.slots[sk]) do
					local diff = (entry.part.Size - baseSizes[sk][i]).Magnitude
					assert(
						diff < 1e-4,
						string.format(
							"%s.%s sofreu distorcao nao uniforme no hitSquashBoss: %.4f",
							bossId,
							sk,
							diff
						)
					)
				end
			end

			-- DYING: registra deathStartAt e desliga stateHighlight
			HordeKit.stepBoss(boss, 103.0, "DYING", false)
			assert(boss.lastState == "DYING", "lastState != DYING: " .. bossId)
			assert(boss.deathStartAt == 103.0, "deathStartAt nao registrado: " .. bossId)
			assert(
				boss.stateHighlight.Enabled == false,
				"stateHighlight ativo em DYING: " .. bossId
			)
			HordeKit.stepBoss(boss, 103.6, "DYING", false)
			assert(boss.deathStartAt == 103.0, "deathStartAt sobrescrito no stepBoss: " .. bossId)
		end
	end
)

check(
	"Vfx helpers: championDeath, bossTelegraph, bossSlamImpact, bossDeathSequence com CanQuery=false e CanTouch=false",
	function()
		assert(type(Vfx.championDeath) == "function", "Vfx.championDeath ausente")
		assert(type(Vfx.bossTelegraph) == "function", "Vfx.bossTelegraph ausente")
		assert(type(Vfx.bossSlamImpact) == "function", "Vfx.bossSlamImpact ausente")
		assert(type(Vfx.bossDeathSequence) == "function", "Vfx.bossDeathSequence ausente")

		local scene = HeadlessMock.Instance.new("Folder")
		HeadlessMock.setTime(200.0)
		HeadlessMock.clearDelays()

		local origin = HeadlessMock.Vector3.new(10, 0, 0)
		local primary = HeadlessMock.Color3.fromRGB(100, 120, 140)
		local accent = HeadlessMock.Color3.fromRGB(245, 158, 11)

		Vfx.championDeath(scene, origin, accent, primary)
		Vfx.bossTelegraph(scene, origin, accent, 0.5)
		Vfx.bossSlamImpact(scene, origin, accent)
		for _, bossId in ipairs({
			"iron_ram_colossus",
			"slag_juggernaut",
			"rime_matriarch",
			"powder_baron",
			"rift_titan",
		}) do
			Vfx.bossDeathSequence(scene, bossId, origin, primary, accent)
		end
		HeadlessMock.flushDelays()

		local checkedParts = 0
		for _, desc in ipairs(scene:GetDescendants()) do
			if desc:IsA("BasePart") then
				checkedParts += 1
				assert(desc.CanQuery == false, "VFX vazou CanQuery=true em " .. tostring(desc.Name))
				assert(desc.CanTouch == false, "VFX vazou CanTouch=true em " .. tostring(desc.Name))
				if string.sub(tostring(desc.Name), 1, 3) ~= "F2_" then
					assert(
						desc.CanCollide == false,
						"VFX nao-F2 vazou CanCollide=true em " .. tostring(desc.Name)
					)
				end
			end
		end
		assert(
			checkedParts >= 40,
			"esperava >= 40 partes VFX/debris inspecionadas, achei " .. tostring(checkedParts)
		)
	end
)

print(string.format("contrato visual (S8): %d checagens, %d falhas", checks, #failures))
if #failures > 0 then
	for _, failure in ipairs(failures) do
		print("  FALHOU: " .. failure)
	end
	error("contrato visual quebrado")
end
print("OK: contrato visual passou")
