--!strict
-- Catalogo deterministico da Campanha "Cronicas do Bastiao":
-- 5 Atos x 5 Estagios = 25 Fases + Modo Pesadelo + 5 Bosses Multi-Lane + 8 Mutadores.
-- Puro Luau (zero API do Roblox, 100% aritmetica inteira MILLI = 1000).

local bit32 = bit32

export type DifficultyMode = "normal" | "nightmare"
export type UnitKind = "runner" | "brute" | "swarm" | "shieldbearer" | "pyromancer" | "sapper"
export type BossId =
	"iron_ram_colossus"
	| "slag_juggernaut"
	| "rime_matriarch"
	| "powder_baron"
	| "rift_titan"

export type WaveSliceSpec = {
	startTick: number,
	everyTicks: number,
	count: number,
	unit: UnitKind,
	laneMask: number,
	isElite: boolean,
}

export type StarThresholds = {
	minWallHpPctFor2Stars: number,
	maxLeaksFor3Stars: number,
}

export type CampaignStageSpec = {
	stageId: string,
	act: number,
	index: number,
	name: string,
	commanderId: string,
	seedFixed: number,
	wallMaxHpMilli: number,
	hpScaleMilli: number,
	armorMilli: number,
	speedMilli: number,
	bossId: BossId?,
	bossHpScaleMilli: number?,
	mutatorIds: { string },
	nightmareMutators: { string },
	waves: { WaveSliceSpec },
	rewardGoldFirst: number,
	rewardGoldRepeat: number,
	starThresholds: StarThresholds,
	unlockReq: string?,
}

export type ActMilestoneSpec = {
	threshold: number,
	bit: number,
	gold: number,
}

export type BossCatalogSpec = {
	bossId: BossId,
	act: number,
	name: string,
	baseHp: number,
	armorMilli: number,
	speedMilli: number,
	laneSpan: number,
	staggerCapMilli: number,
}

export type CampaignProgressState = {
	highestUnlockedStage: string,
	nightmareUnlocked: boolean,
	starsNormal: { [string]: number },
	starsNightmare: { [string]: number },
	actMilestoneClaims: { [string]: number },
}

local CampaignCatalog = {}

CampaignCatalog.MILLI = 1000
CampaignCatalog.ACT_COUNT = 5
CampaignCatalog.STAGES_PER_ACT = 5
CampaignCatalog.TOTAL_STAGES = 25
CampaignCatalog.NIGHTMARE_HP_SCALE_MILLI = 1650
CampaignCatalog.NIGHTMARE_ARMOR_BONUS_MILLI = 150

CampaignCatalog.ACT_NAMES = table.freeze({
	"Cinzas da Fronteira",
	"Forjas de Escoria",
	"Geada do Desfiladeiro",
	"Polvora e Trincheira",
	"A Fenda Profunda",
})

CampaignCatalog.ACT_COMMANDERS = table.freeze({
	"cmd_vorn",
	"cmd_brasa",
	"cmd_moira",
	"cmd_kael",
	"cmd_sombra",
})

CampaignCatalog.ACT_MILESTONES = table.freeze({
	table.freeze({ threshold = 5, bit = 1, gold = 50 }),
	table.freeze({ threshold = 10, bit = 2, gold = 90 }),
	table.freeze({ threshold = 15, bit = 4, gold = 150 }),
}) :: { ActMilestoneSpec }

CampaignCatalog.BOSS_SPECS = table.freeze({
	iron_ram_colossus = table.freeze({
		bossId = "iron_ram_colossus" :: BossId,
		act = 1,
		name = "Colosso Ariete de Ferro",
		baseHp = 420000,
		armorMilli = 150,
		speedMilli = 800,
		laneSpan = 3,
		staggerCapMilli = 600,
	}),
	slag_juggernaut = table.freeze({
		bossId = "slag_juggernaut" :: BossId,
		act = 2,
		name = "Juggernaut da Caldeira",
		baseHp = 680000,
		armorMilli = 300,
		speedMilli = 700,
		laneSpan = 3,
		staggerCapMilli = 600,
	}),
	rime_matriarch = table.freeze({
		bossId = "rime_matriarch" :: BossId,
		act = 3,
		name = "Matriarca da Geada",
		baseHp = 840000,
		armorMilli = 200,
		speedMilli = 960,
		laneSpan = 3,
		staggerCapMilli = 600,
	}),
	powder_baron = table.freeze({
		bossId = "powder_baron" :: BossId,
		act = 4,
		name = "Barao da Polvora",
		baseHp = 1050000,
		armorMilli = 250,
		speedMilli = 1040,
		laneSpan = 3,
		staggerCapMilli = 600,
	}),
	rift_titan = table.freeze({
		bossId = "rift_titan" :: BossId,
		act = 5,
		name = "Tita da Fenda Turquesa",
		baseHp = 1450000,
		armorMilli = 350,
		speedMilli = 900,
		laneSpan = 3,
		staggerCapMilli = 600,
	}),
}) :: { [string]: BossCatalogSpec }

CampaignCatalog.MUTATOR_IDS = table.freeze({
	"mut_iron_hide",
	"mut_haste_wind",
	"mut_frost_ward",
	"mut_swarm_surge",
	"mut_amber_tax",
	"mut_cracked_gate",
	"mut_volatile_oil",
	"mut_echo_rift",
})

local DEFAULT_THRESHOLDS: StarThresholds = table.freeze({
	minWallHpPctFor2Stars = 70,
	maxLeaksFor3Stars = 0,
})

local function slice(
	startTick: number,
	everyTicks: number,
	count: number,
	unit: UnitKind,
	laneMask: number,
	isElite: boolean?
): WaveSliceSpec
	return table.freeze({
		startTick = startTick,
		everyTicks = everyTicks,
		count = count,
		unit = unit,
		laneMask = laneMask,
		isElite = isElite == true,
	})
end

-- Bitmasks de lanes: r1=1, r2=2, r3=4, r4=8, r5=16, todas=31, centro(r2..r4)=14, bordas(r1,r5)=17
local LANE_R3 = 4
local LANE_MID3 = 14 -- r2, r3, r4
local LANE_FLANKS = 17 -- r1, r5
local LANE_EVEN = 10 -- r2, r4
local LANE_ODD = 21 -- r1, r3, r5
local LANE_ALL = 31

local RAW_STAGES: { CampaignStageSpec } = {
	-- =========================================================================
	-- ATO 1: Cinzas da Fronteira (Comandante Vorn, calibrado para L1/L2 3..5 traps)
	-- =========================================================================
	{
		stageId = "1-1",
		act = 1,
		index = 1,
		name = "Patrulha das Cinzas",
		commanderId = "cmd_vorn",
		seedFixed = 10101,
		wallMaxHpMilli = 500000,
		hpScaleMilli = 550,
		armorMilli = 0,
		speedMilli = 880,
		bossId = nil,
		bossHpScaleMilli = nil,
		mutatorIds = {},
		nightmareMutators = { "mut_haste_wind", "mut_echo_rift" },
		waves = {
			slice(10, 28, 6, "runner", LANE_MID3, false),
			slice(190, 26, 6, "swarm", LANE_R3, false),
		},
		rewardGoldFirst = 45,
		rewardGoldRepeat = 15,
		starThresholds = DEFAULT_THRESHOLDS,
		unlockReq = nil,
	},
	{
		stageId = "1-2",
		act = 1,
		index = 2,
		name = "Batedores de Escoria",
		commanderId = "cmd_vorn",
		seedFixed = 10102,
		wallMaxHpMilli = 500000,
		hpScaleMilli = 580,
		armorMilli = 0,
		speedMilli = 900,
		bossId = nil,
		bossHpScaleMilli = nil,
		mutatorIds = {},
		nightmareMutators = { "mut_swarm_surge", "mut_cracked_gate" },
		waves = {
			slice(10, 26, 6, "runner", LANE_MID3, false),
			slice(160, 40, 2, "shieldbearer", LANE_R3, false),
			slice(250, 24, 6, "swarm", LANE_MID3, false),
		},
		rewardGoldFirst = 50,
		rewardGoldRepeat = 16,
		starThresholds = DEFAULT_THRESHOLDS,
		unlockReq = "1-1",
	},
	{
		stageId = "1-3",
		act = 1,
		index = 3,
		name = "Cerco Cruzado",
		commanderId = "cmd_vorn",
		seedFixed = 10103,
		wallMaxHpMilli = 500000,
		hpScaleMilli = 600,
		armorMilli = 0,
		speedMilli = 900,
		bossId = nil,
		bossHpScaleMilli = nil,
		mutatorIds = {},
		nightmareMutators = { "mut_iron_hide", "mut_echo_rift" },
		waves = {
			slice(10, 28, 6, "runner", LANE_EVEN, false),
			slice(150, 36, 3, "pyromancer", LANE_R3, false),
			slice(270, 26, 6, "sapper", LANE_MID3, false),
		},
		rewardGoldFirst = 55,
		rewardGoldRepeat = 18,
		starThresholds = DEFAULT_THRESHOLDS,
		unlockReq = "1-2",
	},
	{
		stageId = "1-4",
		act = 1,
		index = 4,
		name = "Vanguarda Blindada",
		commanderId = "cmd_vorn",
		seedFixed = 10104,
		wallMaxHpMilli = 500000,
		hpScaleMilli = 620,
		armorMilli = 0,
		speedMilli = 920,
		bossId = nil,
		bossHpScaleMilli = nil,
		mutatorIds = {},
		nightmareMutators = { "mut_iron_hide", "mut_amber_tax" },
		waves = {
			slice(10, 30, 5, "runner", LANE_MID3, false),
			slice(140, 45, 2, "brute", LANE_R3, false),
			slice(240, 38, 2, "shieldbearer", LANE_EVEN, true),
			slice(320, 25, 6, "swarm", LANE_MID3, false),
		},
		rewardGoldFirst = 65,
		rewardGoldRepeat = 20,
		starThresholds = DEFAULT_THRESHOLDS,
		unlockReq = "1-3",
	},
	{
		stageId = "1-5",
		act = 1,
		index = 5,
		name = "O Colosso Ariete",
		commanderId = "cmd_vorn",
		seedFixed = 10105,
		wallMaxHpMilli = 550000,
		hpScaleMilli = 520,
		armorMilli = 0,
		speedMilli = 850,
		bossId = "iron_ram_colossus",
		bossHpScaleMilli = 120,
		mutatorIds = {},
		nightmareMutators = { "mut_volatile_oil", "mut_iron_hide" },
		waves = {
			slice(12, 34, 4, "runner", LANE_EVEN, false),
			slice(180, 40, 3, "swarm", LANE_R3, false),
		},
		rewardGoldFirst = 110,
		rewardGoldRepeat = 35,
		starThresholds = DEFAULT_THRESHOLDS,
		unlockReq = "1-4",
	},

	-- =========================================================================
	-- ATO 2: Forjas de Escoria (Comandante Brasa)
	-- =========================================================================
	{
		stageId = "2-1",
		act = 2,
		index = 1,
		name = "Valas Incandescentes",
		commanderId = "cmd_brasa",
		seedFixed = 20201,
		wallMaxHpMilli = 650000,
		hpScaleMilli = 750,
		armorMilli = 50,
		speedMilli = 950,
		bossId = nil,
		bossHpScaleMilli = nil,
		mutatorIds = {},
		nightmareMutators = { "mut_iron_hide", "mut_haste_wind" },
		waves = {
			slice(10, 24, 8, "runner", LANE_ODD, false),
			slice(160, 36, 4, "pyromancer", LANE_MID3, false),
			slice(290, 40, 3, "shieldbearer", LANE_R3, false),
		},
		rewardGoldFirst = 70,
		rewardGoldRepeat = 22,
		starThresholds = DEFAULT_THRESHOLDS,
		unlockReq = "1-5",
	},
	{
		stageId = "2-2",
		act = 2,
		index = 2,
		name = "Marcha dos Escudeiros",
		commanderId = "cmd_brasa",
		seedFixed = 20202,
		wallMaxHpMilli = 650000,
		hpScaleMilli = 780,
		armorMilli = 60,
		speedMilli = 960,
		bossId = nil,
		bossHpScaleMilli = nil,
		mutatorIds = {},
		nightmareMutators = { "mut_iron_hide", "mut_amber_tax" },
		waves = {
			slice(10, 32, 5, "shieldbearer", LANE_MID3, false),
			slice(170, 26, 8, "runner", LANE_ALL, false),
			slice(320, 38, 3, "brute", LANE_EVEN, false),
		},
		rewardGoldFirst = 75,
		rewardGoldRepeat = 24,
		starThresholds = DEFAULT_THRESHOLDS,
		unlockReq = "2-1",
	},
	{
		stageId = "2-3",
		act = 2,
		index = 3,
		name = "Fole da Caldeira",
		commanderId = "cmd_brasa",
		seedFixed = 20203,
		wallMaxHpMilli = 650000,
		hpScaleMilli = 820,
		armorMilli = 75,
		speedMilli = 980,
		bossId = nil,
		bossHpScaleMilli = nil,
		mutatorIds = {},
		nightmareMutators = { "mut_frost_ward", "mut_swarm_surge" },
		waves = {
			slice(10, 24, 8, "pyromancer", LANE_ODD, false),
			slice(180, 22, 8, "sapper", LANE_FLANKS, false),
			slice(330, 34, 4, "shieldbearer", LANE_MID3, true),
		},
		rewardGoldFirst = 80,
		rewardGoldRepeat = 25,
		starThresholds = DEFAULT_THRESHOLDS,
		unlockReq = "2-2",
	},
	{
		stageId = "2-4",
		act = 2,
		index = 4,
		name = "Comboio de Ferro Fundido",
		commanderId = "cmd_brasa",
		seedFixed = 20204,
		wallMaxHpMilli = 650000,
		hpScaleMilli = 850,
		armorMilli = 90,
		speedMilli = 1000,
		bossId = nil,
		bossHpScaleMilli = nil,
		mutatorIds = {},
		nightmareMutators = { "mut_cracked_gate", "mut_iron_hide" },
		waves = {
			slice(10, 30, 5, "brute", LANE_MID3, false),
			slice(160, 25, 8, "pyromancer", LANE_EVEN, true),
			slice(310, 20, 10, "swarm", LANE_ALL, false),
		},
		rewardGoldFirst = 85,
		rewardGoldRepeat = 28,
		starThresholds = DEFAULT_THRESHOLDS,
		unlockReq = "2-3",
	},
	{
		stageId = "2-5",
		act = 2,
		index = 5,
		name = "Juggernaut da Caldeira",
		commanderId = "cmd_brasa",
		seedFixed = 20205,
		wallMaxHpMilli = 700000,
		hpScaleMilli = 760,
		armorMilli = 60,
		speedMilli = 920,
		bossId = "slag_juggernaut",
		bossHpScaleMilli = 150,
		mutatorIds = {},
		nightmareMutators = { "mut_volatile_oil", "mut_iron_hide" },
		waves = {
			slice(15, 32, 5, "pyromancer", LANE_MID3, false),
			slice(190, 36, 4, "shieldbearer", LANE_EVEN, false),
		},
		rewardGoldFirst = 140,
		rewardGoldRepeat = 45,
		starThresholds = DEFAULT_THRESHOLDS,
		unlockReq = "2-4",
	},

	-- =========================================================================
	-- ATO 3: Geada do Desfiladeiro (Comandante Moira)
	-- =========================================================================
	{
		stageId = "3-1",
		act = 3,
		index = 1,
		name = "Trilha do Gelo Seco",
		commanderId = "cmd_moira",
		seedFixed = 30301,
		wallMaxHpMilli = 800000,
		hpScaleMilli = 880,
		armorMilli = 80,
		speedMilli = 1020,
		bossId = nil,
		bossHpScaleMilli = nil,
		mutatorIds = {},
		nightmareMutators = { "mut_frost_ward", "mut_haste_wind" },
		waves = {
			slice(10, 20, 10, "swarm", LANE_ALL, false),
			slice(170, 28, 6, "pyromancer", LANE_MID3, false),
			slice(310, 26, 6, "runner", LANE_FLANKS, false),
		},
		rewardGoldFirst = 90,
		rewardGoldRepeat = 30,
		starThresholds = DEFAULT_THRESHOLDS,
		unlockReq = "2-5",
	},
	{
		stageId = "3-2",
		act = 3,
		index = 2,
		name = "avalanches de Estilhacos",
		commanderId = "cmd_moira",
		seedFixed = 30302,
		wallMaxHpMilli = 800000,
		hpScaleMilli = 910,
		armorMilli = 90,
		speedMilli = 1040,
		bossId = nil,
		bossHpScaleMilli = nil,
		mutatorIds = {},
		nightmareMutators = { "mut_swarm_surge", "mut_frost_ward" },
		waves = {
			slice(10, 18, 12, "swarm", LANE_ODD, false),
			slice(180, 30, 5, "shieldbearer", LANE_MID3, false),
			slice(320, 24, 6, "sapper", LANE_EVEN, false),
		},
		rewardGoldFirst = 95,
		rewardGoldRepeat = 32,
		starThresholds = DEFAULT_THRESHOLDS,
		unlockReq = "3-1",
	},
	{
		stageId = "3-3",
		act = 3,
		index = 3,
		name = "Corredor Boreal",
		commanderId = "cmd_moira",
		seedFixed = 30303,
		wallMaxHpMilli = 800000,
		hpScaleMilli = 940,
		armorMilli = 100,
		speedMilli = 1050,
		bossId = nil,
		bossHpScaleMilli = nil,
		mutatorIds = {},
		nightmareMutators = { "mut_echo_rift", "mut_frost_ward" },
		waves = {
			slice(10, 24, 8, "runner", LANE_FLANKS, false),
			slice(160, 28, 6, "pyromancer", LANE_MID3, true),
			slice(300, 20, 10, "swarm", LANE_ALL, false),
		},
		rewardGoldFirst = 100,
		rewardGoldRepeat = 34,
		starThresholds = DEFAULT_THRESHOLDS,
		unlockReq = "3-2",
	},
	{
		stageId = "3-4",
		act = 3,
		index = 4,
		name = "Guarda da Coroa Gélida",
		commanderId = "cmd_moira",
		seedFixed = 30304,
		wallMaxHpMilli = 800000,
		hpScaleMilli = 970,
		armorMilli = 110,
		speedMilli = 1060,
		bossId = nil,
		bossHpScaleMilli = nil,
		mutatorIds = {},
		nightmareMutators = { "mut_amber_tax", "mut_frost_ward" },
		waves = {
			slice(10, 28, 6, "shieldbearer", LANE_MID3, true),
			slice(160, 24, 8, "pyromancer", LANE_ODD, false),
			slice(310, 22, 8, "sapper", LANE_FLANKS, false),
		},
		rewardGoldFirst = 110,
		rewardGoldRepeat = 36,
		starThresholds = DEFAULT_THRESHOLDS,
		unlockReq = "3-3",
	},
	{
		stageId = "3-5",
		act = 3,
		index = 5,
		name = "A Matriarca da Geada",
		commanderId = "cmd_moira",
		seedFixed = 30305,
		wallMaxHpMilli = 850000,
		hpScaleMilli = 860,
		armorMilli = 80,
		speedMilli = 960,
		bossId = "rime_matriarch",
		bossHpScaleMilli = 175,
		mutatorIds = {},
		nightmareMutators = { "mut_frost_ward", "mut_volatile_oil" },
		waves = {
			slice(15, 24, 6, "swarm", LANE_FLANKS, false),
			slice(180, 30, 4, "pyromancer", LANE_MID3, false),
		},
		rewardGoldFirst = 175,
		rewardGoldRepeat = 55,
		starThresholds = DEFAULT_THRESHOLDS,
		unlockReq = "3-4",
	},

	-- =========================================================================
	-- ATO 4: Polvora e Trincheira (Comandante Kael)
	-- =========================================================================
	{
		stageId = "4-1",
		act = 4,
		index = 1,
		name = "Bateria de Trincheira",
		commanderId = "cmd_kael",
		seedFixed = 40401,
		wallMaxHpMilli = 1000000,
		hpScaleMilli = 1000,
		armorMilli = 110,
		speedMilli = 1060,
		bossId = nil,
		bossHpScaleMilli = nil,
		mutatorIds = {},
		nightmareMutators = { "mut_haste_wind", "mut_cracked_gate" },
		waves = {
			slice(10, 22, 8, "sapper", LANE_MID3, false),
			slice(160, 24, 8, "runner", LANE_ALL, false),
			slice(310, 32, 4, "shieldbearer", LANE_EVEN, false),
		},
		rewardGoldFirst = 115,
		rewardGoldRepeat = 38,
		starThresholds = DEFAULT_THRESHOLDS,
		unlockReq = "3-5",
	},
	{
		stageId = "4-2",
		act = 4,
		index = 2,
		name = "Pavio Curto",
		commanderId = "cmd_kael",
		seedFixed = 40402,
		wallMaxHpMilli = 1000000,
		hpScaleMilli = 1030,
		armorMilli = 120,
		speedMilli = 1080,
		bossId = nil,
		bossHpScaleMilli = nil,
		mutatorIds = {},
		nightmareMutators = { "mut_echo_rift", "mut_haste_wind" },
		waves = {
			slice(10, 20, 10, "sapper", LANE_FLANKS, true),
			slice(170, 26, 6, "pyromancer", LANE_MID3, false),
			slice(300, 34, 4, "brute", LANE_R3, false),
		},
		rewardGoldFirst = 120,
		rewardGoldRepeat = 40,
		starThresholds = DEFAULT_THRESHOLDS,
		unlockReq = "4-1",
	},
	{
		stageId = "4-3",
		act = 4,
		index = 3,
		name = "Salva Cruzada",
		commanderId = "cmd_kael",
		seedFixed = 40403,
		wallMaxHpMilli = 1000000,
		hpScaleMilli = 1060,
		armorMilli = 130,
		speedMilli = 1080,
		bossId = nil,
		bossHpScaleMilli = nil,
		mutatorIds = {},
		nightmareMutators = { "mut_swarm_surge", "mut_amber_tax" },
		waves = {
			slice(10, 18, 10, "swarm", LANE_ALL, false),
			slice(150, 22, 8, "sapper", LANE_ODD, false),
			slice(290, 30, 5, "shieldbearer", LANE_MID3, true),
		},
		rewardGoldFirst = 125,
		rewardGoldRepeat = 42,
		starThresholds = DEFAULT_THRESHOLDS,
		unlockReq = "4-2",
	},
	{
		stageId = "4-4",
		act = 4,
		index = 4,
		name = " Comboio de Demolicao",
		commanderId = "cmd_kael",
		seedFixed = 40404,
		wallMaxHpMilli = 1000000,
		hpScaleMilli = 1080,
		armorMilli = 140,
		speedMilli = 1100,
		bossId = nil,
		bossHpScaleMilli = nil,
		mutatorIds = {},
		nightmareMutators = { "mut_cracked_gate", "mut_echo_rift" },
		waves = {
			slice(10, 24, 8, "sapper", LANE_MID3, true),
			slice(160, 28, 6, "brute", LANE_EVEN, false),
			slice(300, 22, 8, "pyromancer", LANE_ALL, false),
		},
		rewardGoldFirst = 135,
		rewardGoldRepeat = 45,
		starThresholds = DEFAULT_THRESHOLDS,
		unlockReq = "4-3",
	},
	{
		stageId = "4-5",
		act = 4,
		index = 5,
		name = "O Barao da Polvora",
		commanderId = "cmd_kael",
		seedFixed = 40405,
		wallMaxHpMilli = 1050000,
		hpScaleMilli = 920,
		armorMilli = 100,
		speedMilli = 980,
		bossId = "powder_baron",
		bossHpScaleMilli = 185,
		mutatorIds = {},
		nightmareMutators = { "mut_volatile_oil", "mut_cracked_gate" },
		waves = {
			slice(15, 28, 5, "sapper", LANE_FLANKS, false),
			slice(180, 30, 4, "runner", LANE_MID3, false),
		},
		rewardGoldFirst = 210,
		rewardGoldRepeat = 65,
		starThresholds = DEFAULT_THRESHOLDS,
		unlockReq = "4-4",
	},

	-- =========================================================================
	-- ATO 5: A Fenda Profunda (Comandante Sombra, calibrado para L4/L5 wall)
	-- =========================================================================
	{
		stageId = "5-1",
		act = 5,
		index = 1,
		name = "Limiar de Obsidiana",
		commanderId = "cmd_sombra",
		seedFixed = 50501,
		wallMaxHpMilli = 1250000,
		hpScaleMilli = 1050,
		armorMilli = 120,
		speedMilli = 1020,
		bossId = nil,
		bossHpScaleMilli = nil,
		mutatorIds = {},
		nightmareMutators = { "mut_echo_rift", "mut_iron_hide" },
		waves = {
			slice(10, 26, 6, "shieldbearer", LANE_MID3, false),
			slice(150, 24, 8, "pyromancer", LANE_EVEN, false),
			slice(290, 24, 6, "sapper", LANE_FLANKS, false),
		},
		rewardGoldFirst = 145,
		rewardGoldRepeat = 48,
		starThresholds = DEFAULT_THRESHOLDS,
		unlockReq = "4-5",
	},
	{
		stageId = "5-2",
		act = 5,
		index = 2,
		name = "Ressonancia Turquesa",
		commanderId = "cmd_sombra",
		seedFixed = 50502,
		wallMaxHpMilli = 1250000,
		hpScaleMilli = 1080,
		armorMilli = 130,
		speedMilli = 1040,
		bossId = nil,
		bossHpScaleMilli = nil,
		mutatorIds = {},
		nightmareMutators = { "mut_swarm_surge", "mut_haste_wind" },
		waves = {
			slice(10, 22, 8, "runner", LANE_ALL, true),
			slice(160, 28, 6, "pyromancer", LANE_MID3, false),
			slice(300, 20, 10, "swarm", LANE_ODD, false),
		},
		rewardGoldFirst = 155,
		rewardGoldRepeat = 50,
		starThresholds = DEFAULT_THRESHOLDS,
		unlockReq = "5-1",
	},
	{
		stageId = "5-3",
		act = 5,
		index = 3,
		name = "Fenda Convergente",
		commanderId = "cmd_sombra",
		seedFixed = 50503,
		wallMaxHpMilli = 1250000,
		hpScaleMilli = 1100,
		armorMilli = 140,
		speedMilli = 1050,
		bossId = nil,
		bossHpScaleMilli = nil,
		mutatorIds = {},
		nightmareMutators = { "mut_frost_ward", "mut_amber_tax" },
		waves = {
			slice(10, 28, 5, "brute", LANE_MID3, false),
			slice(150, 26, 6, "sapper", LANE_EVEN, true),
			slice(290, 28, 5, "shieldbearer", LANE_R3, false),
		},
		rewardGoldFirst = 165,
		rewardGoldRepeat = 55,
		starThresholds = DEFAULT_THRESHOLDS,
		unlockReq = "5-2",
	},
	{
		stageId = "5-4",
		act = 5,
		index = 4,
		name = "Guarda do Abismo",
		commanderId = "cmd_sombra",
		seedFixed = 50504,
		wallMaxHpMilli = 1250000,
		hpScaleMilli = 1120,
		armorMilli = 150,
		speedMilli = 1060,
		bossId = nil,
		bossHpScaleMilli = nil,
		mutatorIds = {},
		nightmareMutators = { "mut_iron_hide", "mut_cracked_gate" },
		waves = {
			slice(10, 28, 6, "shieldbearer", LANE_MID3, true),
			slice(160, 26, 6, "pyromancer", LANE_ODD, true),
			slice(300, 24, 6, "sapper", LANE_FLANKS, false),
		},
		rewardGoldFirst = 180,
		rewardGoldRepeat = 60,
		starThresholds = DEFAULT_THRESHOLDS,
		unlockReq = "5-3",
	},
	{
		stageId = "5-5",
		act = 5,
		index = 5,
		name = "O Tita da Fenda",
		commanderId = "cmd_sombra",
		seedFixed = 50505,
		wallMaxHpMilli = 1250000,
		hpScaleMilli = 950,
		armorMilli = 100,
		speedMilli = 940,
		bossId = "rift_titan",
		bossHpScaleMilli = 160,
		mutatorIds = {},
		nightmareMutators = { "mut_volatile_oil", "mut_echo_rift" },
		waves = {
			slice(15, 32, 4, "shieldbearer", LANE_MID3, false),
			slice(180, 30, 4, "pyromancer", LANE_EVEN, false),
		},
		rewardGoldFirst = 300,
		rewardGoldRepeat = 90,
		starThresholds = DEFAULT_THRESHOLDS,
		unlockReq = "5-4",
	},
}

local STAGES_BY_ID: { [string]: CampaignStageSpec } = {}
local STAGE_ORDER: { string } = {}
local STAGE_INDEX_MAP: { [string]: number } = {}
local ACTS: { [number]: { CampaignStageSpec } } = {
	[1] = {},
	[2] = {},
	[3] = {},
	[4] = {},
	[5] = {},
}

for orderIdx, stage in ipairs(RAW_STAGES) do
	table.freeze(stage.mutatorIds)
	table.freeze(stage.nightmareMutators)
	table.freeze(stage.waves)
	table.freeze(stage)
	STAGES_BY_ID[stage.stageId] = stage
	STAGE_ORDER[orderIdx] = stage.stageId
	STAGE_INDEX_MAP[stage.stageId] = orderIdx
	table.insert(ACTS[stage.act], stage)
end

for act = 1, CampaignCatalog.ACT_COUNT do
	table.freeze(ACTS[act])
end
table.freeze(STAGES_BY_ID)
table.freeze(STAGE_ORDER)
table.freeze(STAGE_INDEX_MAP)

CampaignCatalog.STAGES = STAGES_BY_ID
CampaignCatalog.STAGE_ORDER = STAGE_ORDER

function CampaignCatalog.allStageIds(): { string }
	local list: { string } = {}
	for i, id in ipairs(STAGE_ORDER) do
		list[i] = id
	end
	return list
end

function CampaignCatalog.getStage(stageId: string): CampaignStageSpec?
	if type(stageId) ~= "string" then
		return nil
	end
	return STAGES_BY_ID[stageId]
end

function CampaignCatalog.getAct(act: number): { CampaignStageSpec }
	if type(act) ~= "number" or act < 1 or act > CampaignCatalog.ACT_COUNT or act % 1 ~= 0 then
		return {}
	end
	return ACTS[act]
end

function CampaignCatalog.stageOrderIndex(stageId: string): number?
	if type(stageId) ~= "string" then
		return nil
	end
	return STAGE_INDEX_MAP[stageId]
end

function CampaignCatalog.nextStageId(stageId: string): string?
	local idx = STAGE_INDEX_MAP[stageId]
	if idx == nil then
		return nil
	end
	return STAGE_ORDER[idx + 1]
end

function CampaignCatalog.starsFromMask(mask: number): number
	if type(mask) ~= "number" or mask <= 0 then
		return 0
	end
	local m = math.floor(mask)
	local count = 0
	if bit32.band(m, 1) ~= 0 then
		count += 1
	end
	if bit32.band(m, 2) ~= 0 then
		count += 1
	end
	if bit32.band(m, 4) ~= 0 then
		count += 1
	end
	return count
end

function CampaignCatalog.isUnlocked(
	progress: any,
	stageId: string,
	difficulty: DifficultyMode?
): (boolean, string?)
	local stage = CampaignCatalog.getStage(stageId)
	if stage == nil then
		return false, "invalid_stage"
	end
	local mode: DifficultyMode = if difficulty == "nightmare" then "nightmare" else "normal"
	if mode == "nightmare" then
		if type(progress) ~= "table" or progress.nightmareUnlocked ~= true then
			return false, "nightmare_locked"
		end
	end
	if stage.unlockReq == nil then
		return true, nil
	end
	if type(progress) ~= "table" then
		return false, "stage_locked"
	end
	local starsNormal = if type(progress.starsNormal) == "table" then progress.starsNormal else {}
	local reqMask = tonumber(starsNormal[stage.unlockReq]) or 0
	if reqMask > 0 then
		return true, nil
	end
	local highestIdx = STAGE_INDEX_MAP[tostring(progress.highestUnlockedStage or "1-1")] or 1
	local targetIdx = STAGE_INDEX_MAP[stageId] or 999
	if targetIdx <= highestIdx then
		return true, nil
	end
	return false, "stage_locked"
end

function CampaignCatalog.evaluateStars(stageOrId: any, battleResult: any): (number, number)
	local stage: CampaignStageSpec? = if type(stageOrId) == "string"
		then CampaignCatalog.getStage(stageOrId)
		elseif type(stageOrId) == "table" then stageOrId
		else nil
	if stage == nil or type(battleResult) ~= "table" then
		return 0, 0
	end
	if battleResult.winner ~= "defender" then
		return 0, 0
	end
	local mask = 1
	local thresholds = stage.starThresholds or DEFAULT_THRESHOLDS
	local wallPctInt = 0
	if type(battleResult.wallPct) == "number" then
		wallPctInt = math.floor(battleResult.wallPct * 100 + 0.0001)
	elseif type(battleResult.wallHp) == "number" and stage.wallMaxHpMilli > 0 then
		wallPctInt = math.floor(battleResult.wallHp * 100 * 1000 / stage.wallMaxHpMilli)
	end
	if wallPctInt >= thresholds.minWallHpPctFor2Stars then
		mask = bit32.bor(mask, 2)
	end
	local leaked = tonumber(battleResult.leaked) or 0
	if leaked <= thresholds.maxLeaksFor3Stars then
		mask = bit32.bor(mask, 4)
	end
	return mask, CampaignCatalog.starsFromMask(mask)
end

function CampaignCatalog.actStarCount(
	progress: any,
	act: number,
	difficulty: DifficultyMode?
): number
	if type(progress) ~= "table" then
		return 0
	end
	local stages = CampaignCatalog.getAct(act)
	if #stages == 0 then
		return 0
	end
	local tableStars = if difficulty == "nightmare"
		then progress.starsNightmare
		else progress.starsNormal
	if type(tableStars) ~= "table" then
		return 0
	end
	local total = 0
	for _, stage in ipairs(stages) do
		local mask = tonumber(tableStars[stage.stageId]) or 0
		total += CampaignCatalog.starsFromMask(mask)
	end
	return total
end

function CampaignCatalog.toWaveSpec(stageOrId: any, difficulty: DifficultyMode?): any
	local stage: CampaignStageSpec? = if type(stageOrId) == "string"
		then CampaignCatalog.getStage(stageOrId)
		elseif type(stageOrId) == "table" then stageOrId
		else nil
	assert(stage ~= nil, "CampaignCatalog.toWaveSpec: estagio invalido")
	local isNightmare = difficulty == "nightmare"
	local hpScaleMilli = stage.hpScaleMilli
	local modeScaleMilli = if isNightmare
		then CampaignCatalog.NIGHTMARE_HP_SCALE_MILLI
		else CampaignCatalog.MILLI
	local armorMilli = stage.armorMilli
		+ (if isNightmare then CampaignCatalog.NIGHTMARE_ARMOR_BONUS_MILLI else 0)
	if armorMilli > 600 then
		armorMilli = 600
	end
	local speedMilli = stage.speedMilli + (if isNightmare then 80 else 0)
	if speedMilli > 2400 then
		speedMilli = 2400
	end
	local mutatorIds: { string } = {}
	local srcMutators = if isNightmare then stage.nightmareMutators else stage.mutatorIds
	for i, m in ipairs(srcMutators) do
		mutatorIds[i] = m
	end
	local slices: { WaveSliceSpec } = {}
	local totalUnits = 0
	for i, s in ipairs(stage.waves) do
		slices[i] = {
			startTick = s.startTick,
			everyTicks = s.everyTicks,
			count = s.count,
			unit = s.unit,
			laneMask = s.laneMask,
			isElite = s.isElite or isNightmare,
		}
		totalUnits += s.count
	end
	return {
		count = totalUnits,
		spawnEveryTicks = 14,
		hpScaleMilli = hpScaleMilli,
		modeScaleMilli = modeScaleMilli,
		armorMilli = armorMilli,
		speedMilli = speedMilli,
		bossId = stage.bossId,
		bossHpScaleMilli = stage.bossHpScaleMilli,
		bossSpawnTick = 60,
		mutatorIds = mutatorIds,
		slices = slices,
	}
end

return table.freeze(CampaignCatalog)
