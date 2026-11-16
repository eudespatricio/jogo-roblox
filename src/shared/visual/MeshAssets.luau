--!strict
-- Malhas 3D de armadilhas, horda e portal (Forge3D) publicadas via Open Cloud em 13/11/2026.
-- Puramente visual: nao toca simVersion/schema/content. Sem malha carregada, os kits mantem
-- o fallback procedural em blocos.

local MeshAssets = {}

MeshAssets.FOLDER = "MuralhaAssets"
MeshAssets.PORTAL_MODEL = "PROP_rift_portal"
MeshAssets.PORTAL = 109517791180533
MeshAssets.LOWPOLY_PALETTE_TEXTURE_ID = 132821694339844

MeshAssets.PORTALS = table.freeze({
	rift = 109517791180533, -- PROP_rift_portal
	act1 = 126791113392403, -- PORTAL_act1 (Cinzas da Fronteira)
	act2 = 128996643862236, -- PORTAL_act2 (Forjas de Escoria)
	act3 = 138667848759919, -- PORTAL_act3 (Geada do Desfiladeiro)
	act4 = 123597805510451, -- PORTAL_act4 (Polvora e Trincheira)
	act5 = 115299301395101, -- PORTAL_act5 (A Fenda Profunda)
}) :: { [string]: number }

MeshAssets.TRAPS = table.freeze({
	archer = table.freeze({
		136531088392860, -- TRAP_archer_l1
		127948003041990, -- TRAP_archer_l2
		83428075493522, -- TRAP_archer_l3
		134079627686582, -- TRAP_archer_l4
		107116747084140, -- TRAP_archer_l5
	}),
	tar = table.freeze({
		129134650747475, -- TRAP_tar_l1
		136374643717888, -- TRAP_tar_l2
		105093278832083, -- TRAP_tar_l3
		102634061007344, -- TRAP_tar_l4
		117454116345175, -- TRAP_tar_l5
	}),
	frost = table.freeze({
		97973146456506, -- TRAP_frost_l1
		91023890309611, -- TRAP_frost_l2
		98609249267663, -- TRAP_frost_l3
		81664686909476, -- TRAP_frost_l4
		124785877415722, -- TRAP_frost_l5
	}),
	cannon = table.freeze({
		116997364661572, -- TRAP_cannon_l1
		98932646893638, -- TRAP_cannon_l2
		80307720103187, -- TRAP_cannon_l3
		82932722118375, -- TRAP_cannon_l4
		87409845344282, -- TRAP_cannon_l5
	}),
	catapult = table.freeze({
		139360486270181, -- TRAP_catapult_l1
		108621388470630, -- TRAP_catapult_l2
		137032570894304, -- TRAP_catapult_l3
		131401388418125, -- TRAP_catapult_l4
		94776291697805, -- TRAP_catapult_l5
	}),
}) :: { [string]: { number } }

MeshAssets.HORDE = table.freeze({
	runner = 81670910227032, -- CMD_runner (torso/capuz esculpido para rig articulado)
	brute = 72160988434060, -- CMD_brute (tronco/elmo esculpido para rig articulado)
	swarm = 105470158146133, -- CMD_swarm (cranio espectral esculpido para rig articulado)
	shieldbearer = 138850606688580, -- CMD_shieldbearer (escudeiro blindado para rig articulado)
	pyromancer = 102596546057159, -- CMD_pyromancer (piroforjador com colar runico e nucleo de brasa)
	sapper = 84119220103203, -- CMD_sapper (zapador com oculos e mochila de polvora)
	wisp = 72045870880609, -- CMD_wisp (espirito/orbe da fenda voador com aneis runicos)
	drake = 138236563437040, -- CMD_drake (draconato de escamas e chifres voador)
}) :: { [string]: number }

MeshAssets.BOSSES = table.freeze({
	iron_ram_colossus = 76905850363477, -- BOSS_iron_ram_colossus (Ato 1)
	slag_juggernaut = 133090749471851, -- BOSS_slag_juggernaut (Ato 2)
	rime_matriarch = 118511202989197, -- BOSS_rime_matriarch (Ato 3)
	powder_baron = 110759926607351, -- BOSS_powder_baron (Ato 4)
	rift_titan = 124719274750385, -- BOSS_rift_titan (Ato 5)
}) :: { [string]: number }

export type BossPartIds = {
	torso: number,
	arm_r: number,
	arm_l: number,
	leg_l: number,
	leg_r: number,
}

MeshAssets.BOSS_PARTS = table.freeze({
	iron_ram_colossus = table.freeze({
		torso = 134332134615397, -- BOSS_iron_ram_colossus_torso
		arm_r = 78773563075186, -- BOSS_iron_ram_colossus_arm_r
		arm_l = 72153503880148, -- BOSS_iron_ram_colossus_arm_l
		leg_l = 139339557717623, -- BOSS_iron_ram_colossus_leg_l
		leg_r = 139456813723375, -- BOSS_iron_ram_colossus_leg_r
	}),
	slag_juggernaut = table.freeze({
		torso = 121524227605867, -- BOSS_slag_juggernaut_torso
		arm_r = 90730724546300, -- BOSS_slag_juggernaut_arm_r
		arm_l = 127482817808748, -- BOSS_slag_juggernaut_arm_l
		leg_l = 71300753472335, -- BOSS_slag_juggernaut_leg_l
		leg_r = 74132035848331, -- BOSS_slag_juggernaut_leg_r
	}),
	rime_matriarch = table.freeze({
		torso = 136005112915949, -- BOSS_rime_matriarch_torso
		arm_r = 99445375369618, -- BOSS_rime_matriarch_arm_r
		arm_l = 91803842414531, -- BOSS_rime_matriarch_arm_l
		leg_l = 90381887140827, -- BOSS_rime_matriarch_leg_l
		leg_r = 133459152908658, -- BOSS_rime_matriarch_leg_r
	}),
	powder_baron = table.freeze({
		torso = 75788028052832, -- BOSS_powder_baron_torso
		arm_r = 104373460151905, -- BOSS_powder_baron_arm_r
		arm_l = 104510035468644, -- BOSS_powder_baron_arm_l
		leg_l = 132333247764159, -- BOSS_powder_baron_leg_l
		leg_r = 95272822540855, -- BOSS_powder_baron_leg_r
	}),
	rift_titan = table.freeze({
		torso = 95302020534985, -- BOSS_rift_titan_torso
		arm_r = 89029129457057, -- BOSS_rift_titan_arm_r
		arm_l = 113420522768988, -- BOSS_rift_titan_arm_l
		leg_l = 92246728751919, -- BOSS_rift_titan_leg_l
		leg_r = 126925364264734, -- BOSS_rift_titan_leg_r
	}),
}) :: { [string]: BossPartIds }

MeshAssets.PROPS = table.freeze({
	tree_pine = 77916499643587, -- PROP_tree_pine (pinheiro detalhado do bastiao)
	tree_oak = 93478874574140, -- PROP_tree_oak (carvalho detalhado da arena)
	rock_cluster = 130272757429108, -- PROP_rock_cluster (aglomerado rochoso natural)
	siege_supply = 92663727424492, -- PROP_siege_supply (barris e caixotes de cerco)
	iron_brazier = 99775577424134, -- PROP_iron_brazier (braseiro forjado do bastiao)
	rift_obelisk = 127947024172283, -- PROP_rift_obelisk (obelisco cristalino da fenda)
	bastion_warden = 137295126478774, -- PROP_bastion_warden (guardiao heroico da muralha)
}) :: { [string]: number }

MeshAssets.FAUNA = table.freeze({
	wyvern_body = 81558330911939, -- FAUNA_wyvern_body (corpo de dragao/wyvern)
	wyvern_wing_l = 137140544010877, -- FAUNA_wyvern_wing_l (asa esquerda wyvern)
	wyvern_wing_r = 107742988986514, -- FAUNA_wyvern_wing_r (asa direita wyvern)
	bird_body = 94882977563939, -- FAUNA_bird_body (corpo ave rapina/passaro)
	bird_wing_l = 126856562308771, -- FAUNA_bird_wing_l (asa esquerda passaro)
	bird_wing_r = 126501636552175, -- FAUNA_bird_wing_r (asa direita passaro)
	stag = 120599200799522, -- FAUNA_stag (cervo do vale)
	pack_ox = 131365608762000, -- FAUNA_pack_ox (boi de carga com ambar)
	ram = 131997464517349, -- FAUNA_ram (carneiro das colinas)
}) :: { [string]: number }

function MeshAssets.trapModelName(id: string, lvl: number): string
	return string.format("TRAP_%s_l%d", id, math.clamp(math.floor(lvl), 1, 5))
end

function MeshAssets.hordeModelName(kind: string): string
	return string.format("CMD_%s", kind)
end

function MeshAssets.bossModelName(bossId: string): string
	return string.format("BOSS_%s", bossId)
end

function MeshAssets.bossPartModelName(bossId: string, partKey: string): string
	return "BOSS_" .. bossId .. "_" .. partKey
end

function MeshAssets.propModelName(key: string): string
	return string.format("PROP_%s", key)
end

function MeshAssets.faunaModelName(key: string): string
	return string.format("FAUNA_%s", key)
end

function MeshAssets.portalModelName(themeKey: string?): string
	if
		themeKey == "act1"
		or themeKey == "act2"
		or themeKey == "act3"
		or themeKey == "act4"
		or themeKey == "act5"
	then
		return string.format("PORTAL_%s", themeKey)
	end
	return MeshAssets.PORTAL_MODEL
end

return table.freeze(MeshAssets)
