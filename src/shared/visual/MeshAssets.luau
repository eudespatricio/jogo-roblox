--!strict
-- Malhas 3D de armadilhas, horda e portal (Forge3D) publicadas via Open Cloud em 13/11/2026.
-- Puramente visual: nao toca simVersion/schema/content. Sem malha carregada, os kits mantem
-- o fallback procedural em blocos.

local MeshAssets = {}

MeshAssets.FOLDER = "MuralhaAssets"
MeshAssets.PORTAL_MODEL = "PROP_rift_portal"
MeshAssets.PORTAL = 124705842110804
MeshAssets.LOWPOLY_PALETTE_TEXTURE_ID = 87757376846021

MeshAssets.PORTALS = table.freeze({
	rift = 124705842110804, -- PROP_rift_portal
	act1 = 80457558833517, -- PORTAL_act1
	act2 = 130006104127963, -- PORTAL_act2
	act3 = 92413708179170, -- PORTAL_act3
	act4 = 113494595591202, -- PORTAL_act4
	act5 = 140239593735227, -- PORTAL_act5
}) :: { [string]: number }

MeshAssets.TRAPS = table.freeze({
	archer = table.freeze({
		74898920509737, -- TRAP_archer_l1
		107034619319568, -- TRAP_archer_l2
		71594213565838, -- TRAP_archer_l3
		71233522965926, -- TRAP_archer_l4
		99928560680039, -- TRAP_archer_l5
	}),
	tar = table.freeze({
		112747041692494, -- TRAP_tar_l1
		74142165009322, -- TRAP_tar_l2
		76097922544609, -- TRAP_tar_l3
		80078124738613, -- TRAP_tar_l4
		111936049397621, -- TRAP_tar_l5
	}),
	frost = table.freeze({
		75599638124392, -- TRAP_frost_l1
		86151546861269, -- TRAP_frost_l2
		101914720011590, -- TRAP_frost_l3
		109168500595198, -- TRAP_frost_l4
		121197989695612, -- TRAP_frost_l5
	}),
	cannon = table.freeze({
		126408629929681, -- TRAP_cannon_l1
		98052647295794, -- TRAP_cannon_l2
		131506467672707, -- TRAP_cannon_l3
		82347357559408, -- TRAP_cannon_l4
		75043667056813, -- TRAP_cannon_l5
	}),
	catapult = table.freeze({
		91148892276169, -- TRAP_catapult_l1
		89061317902158, -- TRAP_catapult_l2
		131023354001872, -- TRAP_catapult_l3
		100007095385951, -- TRAP_catapult_l4
		78937648158384, -- TRAP_catapult_l5
	}),
}) :: { [string]: { number } }

MeshAssets.HORDE = table.freeze({
	runner = 114012956006249, -- CMD_runner
	brute = 125456882362546, -- CMD_brute
	swarm = 96726732030645, -- CMD_swarm
	shieldbearer = 90627963664824, -- CMD_shieldbearer
	pyromancer = 71089087203831, -- CMD_pyromancer
	sapper = 75545622801039, -- CMD_sapper
	wisp = 110195715070633, -- CMD_wisp
	drake = 121819060090792, -- CMD_drake
}) :: { [string]: number }

MeshAssets.BOSSES = table.freeze({
	iron_ram_colossus = 86795118354505, -- BOSS_iron_ram_colossus
	slag_juggernaut = 134327654444729, -- BOSS_slag_juggernaut
	rime_matriarch = 104952636888242, -- BOSS_rime_matriarch
	powder_baron = 134089511245938, -- BOSS_powder_baron
	rift_titan = 108755027838008, -- BOSS_rift_titan
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
		torso = 86666150998704, -- BOSS_iron_ram_colossus_torso
		arm_r = 135233841690477, -- BOSS_iron_ram_colossus_arm_r
		arm_l = 102226955879826, -- BOSS_iron_ram_colossus_arm_l
		leg_l = 136332810965816, -- BOSS_iron_ram_colossus_leg_l
		leg_r = 88779565477560, -- BOSS_iron_ram_colossus_leg_r
	}),
	slag_juggernaut = table.freeze({
		torso = 139914667268602, -- BOSS_slag_juggernaut_torso
		arm_r = 134151318810112, -- BOSS_slag_juggernaut_arm_r
		arm_l = 86212244482186, -- BOSS_slag_juggernaut_arm_l
		leg_l = 123017803819462, -- BOSS_slag_juggernaut_leg_l
		leg_r = 135691014121164, -- BOSS_slag_juggernaut_leg_r
	}),
	rime_matriarch = table.freeze({
		torso = 100603676077410, -- BOSS_rime_matriarch_torso
		arm_r = 121525083568567, -- BOSS_rime_matriarch_arm_r
		arm_l = 137836383146557, -- BOSS_rime_matriarch_arm_l
		leg_l = 81520029765551, -- BOSS_rime_matriarch_leg_l
		leg_r = 128741192982654, -- BOSS_rime_matriarch_leg_r
	}),
	powder_baron = table.freeze({
		torso = 90945665921121, -- BOSS_powder_baron_torso
		arm_r = 110462783821965, -- BOSS_powder_baron_arm_r
		arm_l = 112521140013872, -- BOSS_powder_baron_arm_l
		leg_l = 126283860231619, -- BOSS_powder_baron_leg_l
		leg_r = 106438766521619, -- BOSS_powder_baron_leg_r
	}),
	rift_titan = table.freeze({
		torso = 97243497009509, -- BOSS_rift_titan_torso
		arm_r = 94239567275767, -- BOSS_rift_titan_arm_r
		arm_l = 83377586608476, -- BOSS_rift_titan_arm_l
		leg_l = 107156735138397, -- BOSS_rift_titan_leg_l
		leg_r = 91818216518100, -- BOSS_rift_titan_leg_r
	}),
}) :: { [string]: BossPartIds }

MeshAssets.PROPS = table.freeze({
	tree_pine = 140126555659068, -- PROP_tree_pine
	tree_oak = 75735839562524, -- PROP_tree_oak
	rock_cluster = 121015134136611, -- PROP_rock_cluster
	siege_supply = 76636286828540, -- PROP_siege_supply
	iron_brazier = 126739804470209, -- PROP_iron_brazier
	rift_obelisk = 110394747853844, -- PROP_rift_obelisk
	bastion_warden = 111077596874674, -- PROP_bastion_warden
}) :: { [string]: number }

MeshAssets.FAUNA = table.freeze({
	wyvern_body = 112600701149211, -- FAUNA_wyvern_body
	wyvern_wing_l = 78807559858605, -- FAUNA_wyvern_wing_l
	wyvern_wing_r = 76669071902767, -- FAUNA_wyvern_wing_r
	bird_body = 105638593150093, -- FAUNA_bird_body
	bird_wing_l = 83275101075739, -- FAUNA_bird_wing_l
	bird_wing_r = 79661038536872, -- FAUNA_bird_wing_r
	stag = 110402349655640, -- FAUNA_stag
	pack_ox = 123210153825057, -- FAUNA_pack_ox
	ram = 134701337948694, -- FAUNA_ram
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
