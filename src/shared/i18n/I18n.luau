--!strict
-- Localizacao trilingue nativa (PT-BR, EN, ES) sincronizada com assets/i18n/LocalizationTable.csv.
-- Puro Luau (sem servicos Roblox): roda no CLI (sim/i18n-contract.luau), servidor e cliente.

local I18n = {}

export type Locale = "pt" | "en" | "es"
export type Entry = { pt: string, en: string, es: string }

local LOCALES: { Locale } = { "pt", "en", "es" }
I18n.LOCALES = table.freeze(LOCALES)
I18n.DEFAULT_LOCALE = "pt" :: Locale

local function row(pt: string, en: string, es: string): Entry
	return table.freeze({ pt = pt, en = en, es = es })
end

local TABLE: { [string]: Entry } = {
	game_title = row("A MURALHA", "WALLBREAKER", "LA MURALLA"),
	subtitle_architect = row(
		"Arquiteto-Mor da Ordem",
		"Master Siege-Architect",
		"Arquitecto Mayor"
	),
	lang_auto = row("Auto", "Auto", "Auto"),
	lang_pt = row("PT-BR", "PT-BR", "PT-BR"),
	lang_en = row("EN", "EN", "EN"),
	lang_es = row("ES", "ES", "ES"),
	cta_defend = row("DEFENDER", "DEFEND", "DEFENDER"),
	cta_attack = row("ATACAR", "ATTACK", "ATACAR"),
	cta_close = row("FECHAR", "CLOSE", "CERRAR"),
	cta_revenge = row("VINGAR", "REVENGE", "VENGAR"),
	cta_clip_8s = row("CLIPE 8s", "8s CLIP", "CLIP 8s"),
	mode_place = row("COLOCAR", "PLACE", "COLOCAR"),
	mode_upgrade = row("MELHORAR", "UPGRADE", "MEJORAR"),
	mode_remove = row("REMOVER", "REMOVE", "QUITAR"),
	mode_move = row("MOVER", "MOVE", "MOVER"),
	trap_name_archer = row("ARQUEIRO", "ARCHER", "ARQUERO"),
	trap_name_tar = row("PICHE", "TAR", "BREA"),
	trap_name_frost = row("GELO", "FROST", "HIELO"),
	trap_name_cannon = row("CANHÃO", "CANNON", "CAÑÓN"),
	trap_name_catapult = row("CATAPULTA", "CATAPULT", "CATAPULTA"),
	verb_archer = row(
		"Disparo rápido em área 360°.",
		"Fast 360° area shot.",
		"Disparo rápido en área 360°."
	),
	verb_tar = row(
		"Retarda a horda no piso.",
		"Slows enemies on the floor.",
		"Ralentiza a la horda en el suelo."
	),
	verb_frost = row(
		"Congela o avanço na frente.",
		"Chills incoming raiders.",
		"Congela el avance en el frente."
	),
	verb_cannon = row(
		"Impacto pesado contra brutos.",
		"Heavy blast vs brutes.",
		"Impacto pesado contra brutos."
	),
	verb_catapult = row(
		"Dano em área em toda a trilha.",
		"Area splash along the lane.",
		"Daño en área por todo el carril."
	),
	unit_runner = row("Corredor", "Runner", "Corredor"),
	unit_brute = row("Bruto", "Brute", "Bruto"),
	unit_swarm = row("Enxame", "Swarm", "Enjambre"),
	boss_1 = row("Arietão de Ferro", "Iron Ram", "Ariete de Hierro"),
	boss_2 = row("Forjadora de Breu", "Pitchforger", "Forjadora de Brea"),
	boss_3 = row("Colosso Glacial", "Glacial Colossus", "Coloso Glacial"),
	boss_4 = row("Baronesa do Canhão", "Cannoness", "Baronesa del Cañón"),
	boss_5 = row("Soberano da Fenda", "Rift Sovereign", "Soberano de la Grieta"),
	hud_gold = row("%d Ouro", "%d Gold", "%d Oro"),
	hud_league = row("Liga %d · %d pts", "League %d · %d pts", "Liga %d · %d pts"),
	hud_traps = row("%d/%d Armadilhas", "%d/%d Traps", "%d/%d Trampas"),
	toast_starter_40g = row(
		"+40 ouro · Defensor pronto!",
		"+40 gold · Bastion ready!",
		"+40 oro · ¡Defensor listo!"
	),
	toast_locked_league = row(
		"Desbloqueia na Liga %d",
		"Unlocks at League %d",
		"Desbloquea en Liga %d"
	),
	toast_no_gold = row(
		"Ouro insuficiente (%dg)",
		"Not enough gold (%dg)",
		"Oro insuficiente (%dg)"
	),
	toast_max_level = row(
		"Nível máximo atingido",
		"Max level reached",
		"Nivel máximo alcanzado"
	),
	toast_victory = row("Muralha intacta! +%dg", "Bastion held! +%dg", "¡Muralla intacta! +%dg"),
	toast_defeat = row(
		"Portão rompido na trilha",
		"Gate breached in lane",
		"Portón roto en el carril"
	),
	toast_breach = row("Muralha rompeu! +%dg", "Wall breached! +%dg", "¡Muralla rota! +%dg"),
	toast_partner_offline = row(
		"Parceiro offline: setor assumido",
		"Partner offline: sector merged",
		"Socio desconectado: sector unido"
	),
	replay_banner = row("REPLAY %ds · %s", "REPLAY %ds · %s", "REPETICIÓN %ds · %s"),
	diag_brute_lane = row(
		"Trilha %d cedeu: use Gelo + Canhão.",
		"Lane %d breached: use Frost + Cannon.",
		"Carril %d roto: usa Hielo + Cañón."
	),
	diag_swarm_lane = row(
		"Enxame passou na %d: use Catapulta.",
		"Swarm passed lane %d: use Catapult.",
		"Enjambre en %d: usa Catapulta."
	),
	diag_runner_lane = row(
		"Corredor na %d: Arqueiro c2 + Piche.",
		"Runner on %d: Archer c2 + Tar.",
		"Corredor en %d: Arquero c2 + Brea."
	),
	ping_focus = row("Foco aqui!", "Focus here!", "¡Foco aquí!"),
	ping_tar_here = row("Piche aqui!", "Tar here!", "¡Brea aquí!"),
	ping_frost_here = row("Gelo aqui!", "Frost here!", "¡Hielo aquí!"),
	ping_send_gold = row("Preciso de ouro", "Need gold!", "Necesito oro"),
	wall_hud = row(
		"MURALHA Nv%d · %d HP · %d/%d",
		"WALL Lv%d · %d HP · %d/%d",
		"MURALLA Nv%d · %d HP · %d/%d"
	),
	wall_max = row("MÁX", "MAX", "MÁX"),
	combo_btn = row("? Combos", "? Combos", "? Combos"),
	combo_title = row("COMBOS DA MURALHA", "WALL COMBOS", "COMBOS DE MURALLA"),
	combo_tar_name = row("Piche Incendiário", "Incendiary Tar", "Brea Incendiaria"),
	combo_tar_desc = row(
		"Piche + Canhão/Catapulta (+25% dano)",
		"Tar + Cannon/Catapult (+25% dmg)",
		"Brea + Cañón/Catapulta (+25% daño)"
	),
	combo_frost_name = row("Choque Térmico", "Thermal Shock", "Choque Térmico"),
	combo_frost_desc = row(
		"Gelo + Canhão/Catapulta (+20% dano)",
		"Frost + Cannon/Catapult (+20% dmg)",
		"Hielo + Cañón/Catapulta (+20% daño)"
	),
	combo_battery_name = row("Bateria Cruzada", "Cross Battery", "Batería Cruzada"),
	combo_battery_desc = row(
		"Arqueiro perto de Arqueiro (-recarga)",
		"Archer near Archer (-cooldown)",
		"Arquero cerca de Arquero (-recarga)"
	),
	unit_shieldbearer = row("Escudeiro", "Shieldbearer", "Escudero"),
	unit_pyromancer = row("Piroforjador", "Pyromancer", "Piroforjador"),
	unit_sapper = row("Sapador", "Sapper", "Zapador"),
	cta_story = row("HISTÓRIA", "STORY", "HISTORIA"),
	cta_play = row("JOGAR", "PLAY", "JUGAR"),
	cta_claim = row("RESGATAR", "CLAIM", "RECLAMAR"),
	story_title = row("CRÔNICAS DO BASTIÃO", "BASTION CHRONICLES", "CRÓNICAS DEL BASTIÓN"),
	story_normal = row("NORMAL", "NORMAL", "NORMAL"),
	story_nightmare = row("PESADELO", "NIGHTMARE", "PESADILLA"),
	story_act_fmt = row("ATO %d · %s", "ACT %d · %s", "ACTO %d · %s"),
	story_stars_fmt = row("★ %d/%d", "★ %d/%d", "★ %d/%d"),
	story_locked_nm = row(
		"Vença 5-5 Normal p/ Pesadelo",
		"Clear 5-5 Normal for Nightmare",
		"Supera 5-5 Normal p/ Pesadilla"
	),
	boss_telegraph_tag = row(
		"ALERTA: GOLPE PESADO!",
		"WARNING: HEAVY SLAM!",
		"¡ALERTA: GOLPE PESADO!"
	),
	boss_vulnerable_tag = row(
		"ATORDADO (+30% DANO)",
		"STAGGERED (+30% DMG)",
		"ATURDIDO (+30% DAÑO)"
	),
	boss_enrage_tag = row("FÚRIA DO CHEFE", "BOSS ENRAGED", "FURIA DEL JEFE"),
}

I18n.TABLE = table.freeze(TABLE)

function I18n.resolveLocale(raw: any): Locale
	if type(raw) ~= "string" then
		return "pt"
	end
	local trimmed = string.match(string.lower(raw), "^%s*(.-)%s*$") or ""
	local prefix = string.sub(trimmed, 1, 2)
	if prefix == "en" then
		return "en"
	elseif prefix == "es" then
		return "es"
	end
	return "pt"
end

function I18n.toAnalyticsLocale(raw: any): string
	if type(raw) == "string" then
		local trimmed = string.match(string.lower(raw), "^%s*(.-)%s*$") or ""
		local language, region = string.match(trimmed, "^(%a%a)[-_](%a%a)$")
		if language ~= nil and region ~= nil then
			return language .. "-" .. string.upper(region)
		end
		local prefix = string.sub(trimmed, 1, 2)
		if trimmed == "es-419" or prefix == "es" then
			return "es-MX"
		elseif prefix == "en" then
			return "en-US"
		elseif prefix == "pt" then
			return "pt-BR"
		end
	end
	return "pt-BR"
end

function I18n.t(locale: any, key: string, ...: any): string
	local entry = TABLE[key]
	if entry == nil then
		return key
	end
	local resolved = I18n.resolveLocale(locale)
	local template = (entry :: { [string]: string })[resolved] or entry.pt
	if select("#", ...) > 0 then
		local ok, formatted = pcall(string.format, template, ...)
		if ok then
			return formatted
		end
	end
	return template
end

function I18n.trapName(locale: any, trapId: string): string
	local key = "trap_name_" .. tostring(trapId)
	if TABLE[key] ~= nil then
		return I18n.t(locale, key)
	end
	return tostring(trapId)
end

function I18n.trapVerb(locale: any, trapId: string): string
	local key = "verb_" .. tostring(trapId)
	if TABLE[key] ~= nil then
		return I18n.t(locale, key)
	end
	return ""
end

function I18n.unitName(locale: any, unitId: string): string
	local key = "unit_" .. tostring(unitId)
	if TABLE[key] ~= nil then
		return I18n.t(locale, key)
	end
	return tostring(unitId)
end

return I18n
