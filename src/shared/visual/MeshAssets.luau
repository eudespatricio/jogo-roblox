--!strict
-- Malhas 3D de armadilhas, horda e portal (Forge3D) publicadas via Open Cloud em 13/11/2026.
-- Puramente visual: nao toca simVersion/schema/content. Sem malha carregada, os kits mantem
-- o fallback procedural em blocos.

local MeshAssets = {}

MeshAssets.FOLDER = "MuralhaAssets"
MeshAssets.PORTAL_MODEL = "PROP_rift_portal"
MeshAssets.PORTAL = 95521023281390
MeshAssets.LOWPOLY_PALETTE_TEXTURE_ID = 123373171413605

MeshAssets.PORTALS = table.freeze({
	rift = 95521023281390, -- PROP_rift_portal
	act1 = 112717143653722, -- PORTAL_act1
	act2 = 98554366071177, -- PORTAL_act2
	act3 = 125513265457788, -- PORTAL_act3
	act4 = 71893072829758, -- PORTAL_act4
	act5 = 106299884329845, -- PORTAL_act5
}) :: { [string]: number }

MeshAssets.TRAPS = table.freeze({
	archer = table.freeze({
		122407733862032, -- TRAP_archer_l1
		131965889579484, -- TRAP_archer_l2
		71924056655763, -- TRAP_archer_l3
		129825838770347, -- TRAP_archer_l4
		115861753568686, -- TRAP_archer_l5
	}),
	tar = table.freeze({
		88964407803966, -- TRAP_tar_l1
		75334103785989, -- TRAP_tar_l2
		120760875824478, -- TRAP_tar_l3
		139516269761986, -- TRAP_tar_l4
		134861078976776, -- TRAP_tar_l5
	}),
	frost = table.freeze({
		80695116458856, -- TRAP_frost_l1
		131064232920308, -- TRAP_frost_l2
		93664239876720, -- TRAP_frost_l3
		98239047263464, -- TRAP_frost_l4
		116683368631768, -- TRAP_frost_l5
	}),
	cannon = table.freeze({
		99627116735480, -- TRAP_cannon_l1
		81827162498548, -- TRAP_cannon_l2
		92397858941257, -- TRAP_cannon_l3
		122307170274708, -- TRAP_cannon_l4
		125204441358308, -- TRAP_cannon_l5
	}),
	catapult = table.freeze({
		72303212252264, -- TRAP_catapult_l1
		115229101995392, -- TRAP_catapult_l2
		105490733468039, -- TRAP_catapult_l3
		91068707499778, -- TRAP_catapult_l4
		122355480961275, -- TRAP_catapult_l5
	}),
}) :: { [string]: { number } }

MeshAssets.HORDE = table.freeze({
	runner = 93372767682723, -- CMD_runner
	brute = 140138410273485, -- CMD_brute
	swarm = 112514600905312, -- CMD_swarm
	shieldbearer = 99825054467819, -- CMD_shieldbearer
	pyromancer = 135901363153074, -- CMD_pyromancer
	sapper = 80219276829977, -- CMD_sapper
	wisp = 73810768640788, -- CMD_wisp
	drake = 123615820497507, -- CMD_drake
}) :: { [string]: number }

MeshAssets.BOSSES = table.freeze({
	iron_ram_colossus = 129790147217059, -- BOSS_iron_ram_colossus
	slag_juggernaut = 131423621908485, -- BOSS_slag_juggernaut
	rime_matriarch = 105062175472693, -- BOSS_rime_matriarch
	powder_baron = 137551550578254, -- BOSS_powder_baron
	rift_titan = 94769920995206, -- BOSS_rift_titan
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
		torso = 122710710502493, -- BOSS_iron_ram_colossus_torso
		arm_r = 100915980660373, -- BOSS_iron_ram_colossus_arm_r
		arm_l = 113422865898119, -- BOSS_iron_ram_colossus_arm_l
		leg_l = 79669642766212, -- BOSS_iron_ram_colossus_leg_l
		leg_r = 102877570788026, -- BOSS_iron_ram_colossus_leg_r
	}),
	slag_juggernaut = table.freeze({
		torso = 88469210977725, -- BOSS_slag_juggernaut_torso
		arm_r = 73844668032521, -- BOSS_slag_juggernaut_arm_r
		arm_l = 92938715942494, -- BOSS_slag_juggernaut_arm_l
		leg_l = 117952935680762, -- BOSS_slag_juggernaut_leg_l
		leg_r = 106656675966744, -- BOSS_slag_juggernaut_leg_r
	}),
	rime_matriarch = table.freeze({
		torso = 86613322196478, -- BOSS_rime_matriarch_torso
		arm_r = 118072223782162, -- BOSS_rime_matriarch_arm_r
		arm_l = 93901487854185, -- BOSS_rime_matriarch_arm_l
		leg_l = 104198442303157, -- BOSS_rime_matriarch_leg_l
		leg_r = 135835116046402, -- BOSS_rime_matriarch_leg_r
	}),
	powder_baron = table.freeze({
		torso = 112069304589299, -- BOSS_powder_baron_torso
		arm_r = 128406628386798, -- BOSS_powder_baron_arm_r
		arm_l = 74288203168566, -- BOSS_powder_baron_arm_l
		leg_l = 74676252343335, -- BOSS_powder_baron_leg_l
		leg_r = 76818158041756, -- BOSS_powder_baron_leg_r
	}),
	rift_titan = table.freeze({
		torso = 140082663007005, -- BOSS_rift_titan_torso
		arm_r = 137733984913269, -- BOSS_rift_titan_arm_r
		arm_l = 137341591481710, -- BOSS_rift_titan_arm_l
		leg_l = 100519823366999, -- BOSS_rift_titan_leg_l
		leg_r = 105156665863275, -- BOSS_rift_titan_leg_r
	}),
}) :: { [string]: BossPartIds }

MeshAssets.PROPS = table.freeze({
	tree_pine = 138180445727944, -- PROP_tree_pine
	tree_oak = 84585265974533, -- PROP_tree_oak
	rock_cluster = 78147604310588, -- PROP_rock_cluster
	siege_supply = 101111209991225, -- PROP_siege_supply
	iron_brazier = 99112792938584, -- PROP_iron_brazier
	rift_obelisk = 86677809659740, -- PROP_rift_obelisk
	bastion_warden = 97530885126227, -- PROP_bastion_warden
}) :: { [string]: number }

MeshAssets.FAUNA = table.freeze({
	wyvern_body = 114238541797512, -- FAUNA_wyvern_body
	wyvern_wing_l = 138878971965361, -- FAUNA_wyvern_wing_l
	wyvern_wing_r = 114558679998401, -- FAUNA_wyvern_wing_r
	bird_body = 124146605695796, -- FAUNA_bird_body
	bird_wing_l = 125998730304049, -- FAUNA_bird_wing_l
	bird_wing_r = 129879052098297, -- FAUNA_bird_wing_r
	stag = 130894505127243, -- FAUNA_stag
	pack_ox = 83409942894929, -- FAUNA_pack_ox
	ram = 106058025029704, -- FAUNA_ram
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
