--!strict
-- Malhas 3D de armadilhas, horda e portal (Forge3D) publicadas via Open Cloud em 13/11/2026.
-- Puramente visual: nao toca simVersion/schema/content. Sem malha carregada, os kits mantem
-- o fallback procedural em blocos.

local MeshAssets = {}

MeshAssets.FOLDER = "MuralhaAssets"
MeshAssets.PORTAL_MODEL = "PROP_rift_portal"
MeshAssets.PORTAL = 74985506027399

MeshAssets.TRAPS = table.freeze({
	archer = table.freeze({
		128417014620904, -- TRAP_archer_l1
		78426133148342, -- TRAP_archer_l2
		94808887316817, -- TRAP_archer_l3
		94357885594115, -- TRAP_archer_l4
		131659414599766, -- TRAP_archer_l5
	}),
	tar = table.freeze({
		74332973650265, -- TRAP_tar_l1
		130221071195616, -- TRAP_tar_l2
		103359988718546, -- TRAP_tar_l3
		114999535742749, -- TRAP_tar_l4
		137723258080156, -- TRAP_tar_l5
	}),
	frost = table.freeze({
		104444119315280, -- TRAP_frost_l1
		124182503399119, -- TRAP_frost_l2
		72063979149401, -- TRAP_frost_l3
		90382309277305, -- TRAP_frost_l4
		129479745091544, -- TRAP_frost_l5
	}),
	cannon = table.freeze({
		87098631609290, -- TRAP_cannon_l1
		131646162700232, -- TRAP_cannon_l2
		124402182834789, -- TRAP_cannon_l3
		87769683741031, -- TRAP_cannon_l4
		86224294693731, -- TRAP_cannon_l5
	}),
	catapult = table.freeze({
		79698934339532, -- TRAP_catapult_l1
		109668083985131, -- TRAP_catapult_l2
		71551457569059, -- TRAP_catapult_l3
		75139674182457, -- TRAP_catapult_l4
		134401384193867, -- TRAP_catapult_l5
	}),
}) :: { [string]: { number } }

MeshAssets.HORDE = table.freeze({
	runner = 114724683678861, -- CMD_runner (torso/capuz esculpido para rig articulado)
	brute = 110869433426900, -- CMD_brute (tronco/elmo esculpido para rig articulado)
	swarm = 70616350386022, -- CMD_swarm (cranio espectral esculpido para rig articulado)
}) :: { [string]: number }

MeshAssets.PROPS = table.freeze({
	tree_pine = 87273754036948, -- PROP_tree_pine (pinheiro detalhado do bastiao)
	tree_oak = 112395604388749, -- PROP_tree_oak (carvalho detalhado da arena)
	rock_cluster = 117707347104208, -- PROP_rock_cluster (aglomerado rochoso natural)
	siege_supply = 79342657671156, -- PROP_siege_supply (barris e caixotes de cerco)
	iron_brazier = 98617508960127, -- PROP_iron_brazier (braseiro forjado do bastiao)
	rift_obelisk = 116200842885689, -- PROP_rift_obelisk (obelisco cristalino da fenda)
}) :: { [string]: number }

MeshAssets.FAUNA = table.freeze({
	wyvern_body = 138843897158338, -- FAUNA_wyvern_body (corpo de dragao/wyvern)
	wyvern_wing_l = 72371610107575, -- FAUNA_wyvern_wing_l (asa esquerda wyvern)
	wyvern_wing_r = 114096456377497, -- FAUNA_wyvern_wing_r (asa direita wyvern)
	bird_body = 87534356681724, -- FAUNA_bird_body (corpo ave rapina/passaro)
	bird_wing_l = 101642992428047, -- FAUNA_bird_wing_l (asa esquerda passaro)
	bird_wing_r = 110026582717104, -- FAUNA_bird_wing_r (asa direita passaro)
	stag = 110958453256916, -- FAUNA_stag (cervo do vale)
	pack_ox = 76978225243603, -- FAUNA_pack_ox (boi de carga com ambar)
	ram = 134425921266175, -- FAUNA_ram (carneiro das colinas)
}) :: { [string]: number }

function MeshAssets.trapModelName(id: string, lvl: number): string
	return string.format("TRAP_%s_l%d", id, math.clamp(math.floor(lvl), 1, 5))
end

function MeshAssets.hordeModelName(kind: string): string
	return string.format("CMD_%s", kind)
end

function MeshAssets.propModelName(key: string): string
	return string.format("PROP_%s", key)
end

function MeshAssets.faunaModelName(key: string): string
	return string.format("FAUNA_%s", key)
end

return table.freeze(MeshAssets)
