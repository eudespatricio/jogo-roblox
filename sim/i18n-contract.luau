--!nonstrict
-- Contrato de i18n (S8.2.6): paridade byte-a-byte com assets/i18n/LocalizationTable.csv (77 chaves),
-- resolveLocale, toAnalyticsLocale, placeholders e helpers de armadilha/unidade.
-- Roda no Luau CLI: luau sim/i18n-contract.luau
local I18n = require("../src/shared/i18n/I18n")
local TrapCatalog = require("../src/shared/data/TrapCatalog")

local failures = {}
local checks = 0

local function check(name, fn)
	checks += 1
	local ok, err = pcall(fn)
	if not ok then
		failures[#failures + 1] = name .. " :: " .. tostring(err)
	end
end

-- Espelho exato das 77 linhas de assets/i18n/LocalizationTable.csv (Source=pt, en, es).
local EXPECTED_CSV = {
	game_title = { "A MURALHA", "WALLBREAKER", "LA MURALLA" },
	subtitle_architect = {
		"Arquiteto-Mor da Ordem",
		"Master Siege-Architect",
		"Arquitecto Mayor",
	},
	lang_auto = { "Auto", "Auto", "Auto" },
	lang_pt = { "PT-BR", "PT-BR", "PT-BR" },
	lang_en = { "EN", "EN", "EN" },
	lang_es = { "ES", "ES", "ES" },
	cta_defend = { "DEFENDER", "DEFEND", "DEFENDER" },
	cta_attack = { "ATACAR", "ATTACK", "ATACAR" },
	cta_close = { "FECHAR", "CLOSE", "CERRAR" },
	cta_revenge = { "VINGAR", "REVENGE", "VENGAR" },
	cta_clip_8s = { "CLIPE 8s", "8s CLIP", "CLIP 8s" },
	mode_place = { "COLOCAR", "PLACE", "COLOCAR" },
	mode_upgrade = { "MELHORAR", "UPGRADE", "MEJORAR" },
	mode_remove = { "REMOVER", "REMOVE", "QUITAR" },
	mode_move = { "MOVER", "MOVE", "MOVER" },
	trap_name_archer = { "ARQUEIRO", "ARCHER", "ARQUERO" },
	trap_name_tar = { "PICHE", "TAR", "BREA" },
	trap_name_frost = { "GELO", "FROST", "HIELO" },
	trap_name_cannon = { "CANHÃO", "CANNON", "CAÑÓN" },
	trap_name_catapult = { "CATAPULTA", "CATAPULT", "CATAPULTA" },
	verb_archer = {
		"Disparo rápido em área 360°.",
		"Fast 360° area shot.",
		"Disparo rápido en área 360°.",
	},
	verb_tar = {
		"Retarda a horda no piso.",
		"Slows enemies on the floor.",
		"Ralentiza a la horda en el suelo.",
	},
	verb_frost = {
		"Congela o avanço na frente.",
		"Chills incoming raiders.",
		"Congela el avance en el frente.",
	},
	verb_cannon = {
		"Impacto pesado contra brutos.",
		"Heavy blast vs brutes.",
		"Impacto pesado contra brutos.",
	},
	verb_catapult = {
		"Dano em área em toda a trilha.",
		"Area splash along the lane.",
		"Daño en área por todo el carril.",
	},
	unit_runner = { "Corredor", "Runner", "Corredor" },
	unit_brute = { "Bruto", "Brute", "Bruto" },
	unit_swarm = { "Enxame", "Swarm", "Enjambre" },
	boss_1 = { "Arietão de Ferro", "Iron Ram", "Ariete de Hierro" },
	boss_2 = { "Forjadora de Breu", "Pitchforger", "Forjadora de Brea" },
	boss_3 = { "Colosso Glacial", "Glacial Colossus", "Coloso Glacial" },
	boss_4 = { "Baronesa do Canhão", "Cannoness", "Baronesa del Cañón" },
	boss_5 = { "Soberano da Fenda", "Rift Sovereign", "Soberano de la Grieta" },
	hud_gold = { "%d Ouro", "%d Gold", "%d Oro" },
	hud_league = { "Liga %d · %d pts", "League %d · %d pts", "Liga %d · %d pts" },
	hud_traps = { "%d/%d Armadilhas", "%d/%d Traps", "%d/%d Trampas" },
	toast_starter_40g = {
		"+40 ouro · Defensor pronto!",
		"+40 gold · Bastion ready!",
		"+40 oro · ¡Defensor listo!",
	},
	toast_locked_league = {
		"Desbloqueia na Liga %d",
		"Unlocks at League %d",
		"Desbloquea en Liga %d",
	},
	toast_no_gold = {
		"Ouro insuficiente (%dg)",
		"Not enough gold (%dg)",
		"Oro insuficiente (%dg)",
	},
	toast_max_level = {
		"Nível máximo atingido",
		"Max level reached",
		"Nivel máximo alcanzado",
	},
	toast_victory = { "Muralha intacta! +%dg", "Bastion held! +%dg", "¡Muralla intacta! +%dg" },
	toast_defeat = {
		"Portão rompido na trilha",
		"Gate breached in lane",
		"Portón roto en el carril",
	},
	toast_breach = { "Muralha rompeu! +%dg", "Wall breached! +%dg", "¡Muralla rota! +%dg" },
	toast_partner_offline = {
		"Parceiro offline: setor assumido",
		"Partner offline: sector merged",
		"Socio desconectado: sector unido",
	},
	replay_banner = { "REPLAY %ds · %s", "REPLAY %ds · %s", "REPETICIÓN %ds · %s" },
	diag_brute_lane = {
		"Trilha %d cedeu: use Gelo + Canhão.",
		"Lane %d breached: use Frost + Cannon.",
		"Carril %d roto: usa Hielo + Cañón.",
	},
	diag_swarm_lane = {
		"Enxame passou na %d: use Catapulta.",
		"Swarm passed lane %d: use Catapult.",
		"Enjambre en %d: usa Catapulta.",
	},
	diag_runner_lane = {
		"Corredor na %d: Arqueiro c2 + Piche.",
		"Runner on %d: Archer c2 + Tar.",
		"Corredor en %d: Arquero c2 + Brea.",
	},
	ping_focus = { "Foco aqui!", "Focus here!", "¡Foco aquí!" },
	ping_tar_here = { "Piche aqui!", "Tar here!", "¡Brea aquí!" },
	ping_frost_here = { "Gelo aqui!", "Frost here!", "¡Hielo aquí!" },
	ping_send_gold = { "Preciso de ouro", "Need gold!", "Necesito oro" },
	wall_hud = {
		"MURALHA Nv%d · %d HP · %d/%d",
		"WALL Lv%d · %d HP · %d/%d",
		"MURALLA Nv%d · %d HP · %d/%d",
	},
	wall_max = { "MÁX", "MAX", "MÁX" },
	combo_btn = { "? Combos", "? Combos", "? Combos" },
	combo_title = { "COMBOS DA MURALHA", "WALL COMBOS", "COMBOS DE MURALLA" },
	combo_tar_name = { "Piche Incendiário", "Incendiary Tar", "Brea Incendiaria" },
	combo_tar_desc = {
		"Piche + Canhão/Catapulta (+25% dano)",
		"Tar + Cannon/Catapult (+25% dmg)",
		"Brea + Cañón/Catapulta (+25% daño)",
	},
	combo_frost_name = { "Choque Térmico", "Thermal Shock", "Choque Térmico" },
	combo_frost_desc = {
		"Gelo + Canhão/Catapulta (+20% dano)",
		"Frost + Cannon/Catapult (+20% dmg)",
		"Hielo + Cañón/Catapulta (+20% daño)",
	},
	combo_battery_name = { "Bateria Cruzada", "Cross Battery", "Batería Cruzada" },
	combo_battery_desc = {
		"Arqueiro perto de Arqueiro (-recarga)",
		"Archer near Archer (-cooldown)",
		"Arquero cerca de Arquero (-recarga)",
	},
	unit_shieldbearer = { "Escudeiro", "Shieldbearer", "Escudero" },
	unit_pyromancer = { "Piroforjador", "Pyromancer", "Piroforjador" },
	unit_sapper = { "Sapador", "Sapper", "Zapador" },
	cta_story = { "HISTÓRIA", "STORY", "HISTORIA" },
	cta_play = { "JOGAR", "PLAY", "JUGAR" },
	cta_claim = { "RESGATAR", "CLAIM", "RECLAMAR" },
	story_title = {
		"CRÔNICAS DO BASTIÃO",
		"BASTION CHRONICLES",
		"CRÓNICAS DEL BASTIÓN",
	},
	story_normal = { "NORMAL", "NORMAL", "NORMAL" },
	story_nightmare = { "PESADELO", "NIGHTMARE", "PESADILLA" },
	story_act_fmt = { "ATO %d · %s", "ACT %d · %s", "ACTO %d · %s" },
	story_stars_fmt = { "★ %d/%d", "★ %d/%d", "★ %d/%d" },
	story_locked_nm = {
		"Vença 5-5 Normal p/ Pesadelo",
		"Clear 5-5 Normal for Nightmare",
		"Supera 5-5 Normal p/ Pesadilla",
	},
	boss_telegraph_tag = {
		"ALERTA: GOLPE PESADO!",
		"WARNING: HEAVY SLAM!",
		"¡ALERTA: GOLPE PESADO!",
	},
	boss_vulnerable_tag = {
		"ATORDADO (+30% DANO)",
		"STAGGERED (+30% DMG)",
		"ATURDIDO (+30% DAÑO)",
	},
	boss_enrage_tag = { "FÚRIA DO CHEFE", "BOSS ENRAGED", "FURIA DEL JEFE" },
}

local function extractPlaceholders(text)
	local found = {}
	for token in string.gmatch(text, "%%[0-9%.]*[dfsxX%%]") do
		found[#found + 1] = token
	end
	return table.concat(found, ",")
end

check("LOCALES e DEFAULT_LOCALE definidos", function()
	assert(#I18n.LOCALES == 3, "esperava 3 locales")
	assert(
		I18n.LOCALES[1] == "pt" and I18n.LOCALES[2] == "en" and I18n.LOCALES[3] == "es",
		"ordem de LOCALES"
	)
	assert(I18n.DEFAULT_LOCALE == "pt", "DEFAULT_LOCALE")
end)

check("todas as 77 chaves existem e batem byte-a-byte com o CSV", function()
	local expectedCount = 0
	for key, cols in pairs(EXPECTED_CSV) do
		expectedCount += 1
		local entry = I18n.TABLE[key]
		assert(entry ~= nil, "chave ausente em I18n.TABLE: " .. key)
		assert(
			entry.pt == cols[1],
			string.format("%s [pt]: '%s' != '%s'", key, tostring(entry.pt), cols[1])
		)
		assert(
			entry.en == cols[2],
			string.format("%s [en]: '%s' != '%s'", key, tostring(entry.en), cols[2])
		)
		assert(
			entry.es == cols[3],
			string.format("%s [es]: '%s' != '%s'", key, tostring(entry.es), cols[3])
		)
	end
	assert(expectedCount == 77, "esperava 77 chaves esperadas, achei " .. tostring(expectedCount))

	local actualCount = 0
	for key in pairs(I18n.TABLE) do
		actualCount += 1
		assert(EXPECTED_CSV[key] ~= nil, "chave extra em I18n.TABLE: " .. key)
	end
	assert(actualCount == 77, "esperava 77 chaves em I18n.TABLE, achei " .. tostring(actualCount))
end)

check("placeholders identicos entre pt, en e es", function()
	for key, entry in pairs(I18n.TABLE) do
		local ptFmt = extractPlaceholders(entry.pt)
		local enFmt = extractPlaceholders(entry.en)
		local esFmt = extractPlaceholders(entry.es)
		assert(enFmt == ptFmt, string.format("%s [en]: fmt '%s' != '%s'", key, enFmt, ptFmt))
		assert(esFmt == ptFmt, string.format("%s [es]: fmt '%s' != '%s'", key, esFmt, ptFmt))
	end
end)

check("resolveLocale cobre pt/en/es, es-419 e fallbacks", function()
	local cases = {
		{ "pt", "pt" },
		{ "pt-BR", "pt" },
		{ "pt_pt", "pt" },
		{ "en", "en" },
		{ "en-US", "en" },
		{ "en_GB", "en" },
		{ "EN", "en" },
		{ "es", "es" },
		{ "es-419", "es" },
		{ "es-ES", "es" },
		{ "es-MX", "es" },
		{ "es_ar", "es" },
		{ "  ES-419 ", "es" },
		{ "fr-FR", "pt" },
		{ "", "pt" },
		{ nil, "pt" },
		{ 123, "pt" },
	}
	for _, pairCase in ipairs(cases) do
		local got = I18n.resolveLocale(pairCase[1])
		assert(
			got == pairCase[2],
			string.format("resolveLocale(%s) = %s != %s", tostring(pairCase[1]), got, pairCase[2])
		)
	end
end)

check("toAnalyticsLocale normaliza ll-CC e es-419", function()
	local cases = {
		{ "pt-BR", "pt-BR" },
		{ "pt_br", "pt-BR" },
		{ "pt", "pt-BR" },
		{ "en-US", "en-US" },
		{ "en-GB", "en-GB" },
		{ "en_gb", "en-GB" },
		{ "en", "en-US" },
		{ "es-419", "es-MX" },
		{ "es_419", "es-MX" },
		{ "es", "es-MX" },
		{ "es-ES", "es-ES" },
		{ "es-mx", "es-MX" },
		{ "fr-FR", "fr-FR" },
		{ "fr", "pt-BR" },
		{ "", "pt-BR" },
		{ nil, "pt-BR" },
		{ 42, "pt-BR" },
	}
	for _, pairCase in ipairs(cases) do
		local got = I18n.toAnalyticsLocale(pairCase[1])
		assert(
			got == pairCase[2],
			string.format(
				"toAnalyticsLocale(%s) = %s != %s",
				tostring(pairCase[1]),
				got,
				pairCase[2]
			)
		)
	end
end)

check("I18n.t formata placeholders e resolve locale bruto", function()
	assert(I18n.t("pt", "game_title") == "A MURALHA", "pt game_title")
	assert(I18n.t("en-US", "game_title") == "WALLBREAKER", "en game_title")
	assert(I18n.t("es-419", "game_title") == "LA MURALLA", "es-419 game_title")

	assert(I18n.t("pt", "hud_gold", 40) == "40 Ouro", "pt hud_gold")
	assert(I18n.t("en", "hud_gold", 40) == "40 Gold", "en hud_gold")
	assert(I18n.t("es", "hud_gold", 40) == "40 Oro", "es hud_gold")

	assert(I18n.t("pt", "hud_league", 2, 125) == "Liga 2 · 125 pts", "pt hud_league")
	assert(I18n.t("en", "hud_league", 2, 125) == "League 2 · 125 pts", "en hud_league")
	assert(I18n.t("es", "hud_league", 2, 125) == "Liga 2 · 125 pts", "es hud_league")

	assert(I18n.t("pt", "hud_traps", 3, 5) == "3/5 Armadilhas", "pt hud_traps")
	assert(I18n.t("en", "hud_traps", 3, 5) == "3/5 Traps", "en hud_traps")
	assert(I18n.t("es", "hud_traps", 3, 5) == "3/5 Trampas", "es hud_traps")

	assert(I18n.t("pt", "toast_locked_league", 3) == "Desbloqueia na Liga 3", "pt locked")
	assert(I18n.t("en", "toast_locked_league", 3) == "Unlocks at League 3", "en locked")
	assert(I18n.t("es", "toast_locked_league", 3) == "Desbloquea en Liga 3", "es locked")

	assert(I18n.t("pt", "toast_no_gold", 60) == "Ouro insuficiente (60g)", "pt no_gold")
	assert(I18n.t("en", "toast_no_gold", 60) == "Not enough gold (60g)", "en no_gold")
	assert(I18n.t("es", "toast_no_gold", 60) == "Oro insuficiente (60g)", "es no_gold")

	assert(I18n.t("pt", "toast_victory", 18) == "Muralha intacta! +18g", "pt victory")
	assert(I18n.t("en", "toast_victory", 18) == "Bastion held! +18g", "en victory")
	assert(I18n.t("es", "toast_victory", 18) == "¡Muralla intacta! +18g", "es victory")

	assert(I18n.t("pt", "toast_breach", 25) == "Muralha rompeu! +25g", "pt breach")
	assert(I18n.t("en", "toast_breach", 25) == "Wall breached! +25g", "en breach")
	assert(I18n.t("es", "toast_breach", 25) == "¡Muralla rota! +25g", "es breach")

	assert(I18n.t("pt", "replay_banner", 8, "12s") == "REPLAY 8s · 12s", "pt replay")
	assert(I18n.t("en", "replay_banner", 8, "12s") == "REPLAY 8s · 12s", "en replay")
	assert(I18n.t("es", "replay_banner", 8, "12s") == "REPETICIÓN 8s · 12s", "es replay")

	assert(
		I18n.t("en", "diag_brute_lane", 2) == "Lane 2 breached: use Frost + Cannon.",
		"en diag_brute"
	)
	assert(I18n.t("es", "diag_swarm_lane", 4) == "Enjambre en 4: usa Catapulta.", "es diag_swarm")
	assert(
		I18n.t("pt", "diag_runner_lane", 1) == "Corredor na 1: Arqueiro c2 + Piche.",
		"pt diag_runner"
	)
	assert(I18n.t("pt", "chave_inexistente") == "chave_inexistente", "fallback chave desconhecida")
end)

check("trapName, trapVerb e unitName cobrem todo o catalogo", function()
	for _, trapId in ipairs(TrapCatalog.TRAP_IDS) do
		for _, locale in ipairs(I18n.LOCALES) do
			local name = I18n.trapName(locale, trapId)
			local verb = I18n.trapVerb(locale, trapId)
			assert(
				type(name) == "string" and #name > 0 and name ~= trapId,
				"trapName falhou: " .. trapId .. " " .. locale
			)
			assert(
				type(verb) == "string" and #verb > 0,
				"trapVerb falhou: " .. trapId .. " " .. locale
			)
		end
	end
	for _, unitId in ipairs({ "runner", "brute", "swarm", "shieldbearer", "pyromancer", "sapper" }) do
		for _, locale in ipairs(I18n.LOCALES) do
			local name = I18n.unitName(locale, unitId)
			assert(
				type(name) == "string" and #name > 0 and name ~= unitId,
				"unitName falhou: " .. unitId .. " " .. locale
			)
		end
	end
	assert(I18n.trapName("en", "cannon") == "CANNON", "trapName cannon")
	assert(I18n.trapName("es", "tar") == "BREA", "trapName tar es")
	assert(I18n.unitName("es", "swarm") == "Enjambre", "unitName swarm es")
	assert(I18n.trapName("pt", "unknown_trap") == "unknown_trap", "fallback trapName")
	assert(I18n.trapVerb("pt", "unknown_trap") == "", "fallback trapVerb")
	assert(I18n.unitName("pt", "unknown_unit") == "unknown_unit", "fallback unitName")
end)

print(string.format("contrato de i18n (S8.2): %d checagens, %d falhas", checks, #failures))
if #failures > 0 then
	for _, failure in ipairs(failures) do
		print("  FALHOU: " .. failure)
	end
	error("contrato de i18n quebrado")
end
print("OK: contrato de i18n passou")
