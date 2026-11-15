--!strict
-- Schema v6 do perfil da MURALHA: template, validacao, sanitizacao e migracao.
-- Puro Luau (nenhuma API do Roblox): roda no CLI em sim/profile-contract.luau e no servidor.
-- Regras: campo novo entra em newProfile E em sanitizeCurrent; campo desconhecido nunca e salvo
-- (a whitelist roda em todo load); a chave do perfil e UserId, nunca nome; nada de PII no Data.

local ProfileSchema = {}

ProfileSchema.SCHEMA_VERSION = 6
ProfileSchema.STORE_NAME = "MuralhaProfile_v1"
ProfileSchema.SECONDS_PER_DAY = 86400
-- Versao de conteudo padrao do schema v6. O catalogo atual (TrapCatalog.CONTENT_VERSION)
-- manda no gate de conteudo; o schema valida a faixa >= 1.
ProfileSchema.DEFAULT_CONTENT_VERSION = 3

-- Grade base 5x5 e arena de colocacao livre (milli-unidades, paridade com Core.ARENA).
ProfileSchema.GRID_WIDTH = 5
ProfileSchema.MAX_GRID_WIDTH = 7
ProfileSchema.GRID_HEIGHT = 5
ProfileSchema.ACTIVE_TRAP_LIMIT = 5
ProfileSchema.MIN_ACTIVE_TRAP_LIMIT = 5
ProfileSchema.MAX_ACTIVE_TRAP_LIMIT = 7
ProfileSchema.MAX_TRAP_LEVEL = 5
ProfileSchema.MAX_WALL_LEVEL = 5
ProfileSchema.MAX_CELLS = ProfileSchema.MAX_ACTIVE_TRAP_LIMIT
ProfileSchema.MAX_SLOT_LENGTH = 16
ProfileSchema.MAX_COSMETICS = 200
ProfileSchema.MAX_GOLD = 1000000000
ProfileSchema.MAX_COUNTER = 9007199254740991
ProfileSchema.MAX_ID_LENGTH = 48
ProfileSchema.CAMPAIGN_ACTS = 5
ProfileSchema.CAMPAIGN_STAGES_PER_ACT = 5
ProfileSchema.MAX_STAR_MASK = 7
ProfileSchema.MAX_HORDE_CARDS = 64
ProfileSchema.MAX_DECK_SQUADS = 8
ProfileSchema.MAX_SQUAD_UNITS = 200
ProfileSchema.MAX_FTUE_STEP = 6
ProfileSchema.MAX_BATTLE_HISTORY = 12
ProfileSchema.MAX_REVENGE_COOLDOWNS = 32
ProfileSchema.REVENGE_COOLDOWN_SECONDS = ProfileSchema.SECONDS_PER_DAY
ProfileSchema.MAX_BATTLE_ID_LENGTH = 64
ProfileSchema.MAX_LABEL_LENGTH = 32

ProfileSchema.ARENA = table.freeze({
	xMin = 1000,
	xMax = 9000,
	yMin = 500,
	yMax = 4500,
	step = 250,
	minSpacing = 1000,
})

ProfileSchema.COLUMN_X = table.freeze({ 2000, 3500, 5000, 6500, 8000 })

ProfileSchema.EQUIPPED_DEFAULTS = table.freeze({
	theme = "theme_default",
	hordeSkin = "horde_default",
	finisher = "finisher_default",
	commander = "cmd_vorn",
})

export type Cell = { trap: string, level: number, x: number, y: number }

export type Wall = {
	level: number,
	gridWidth: number,
	activeTrapLimit: number,
	cells: { [string]: Cell },
}

export type Equipped = {
	theme: string,
	hordeSkin: string,
	finisher: string,
	commander: string,
}

export type CampaignProgress = {
	highestUnlockedStage: string,
	nightmareUnlocked: boolean,
	starsNormal: { [string]: number },
	starsNightmare: { [string]: number },
	actMilestoneClaims: { [string]: number },
}

export type DeckSquad = {
	cardId: string,
	count: number,
	laneMode: string,
}

export type BossCores = {
	act1: boolean,
	act2: boolean,
	act3: boolean,
	act4: boolean,
	act5: boolean,
}

export type HordeProgress = {
	starterChosen: boolean,
	faction: string,
	unlockedCards: { [string]: boolean },
	shards: number,
	bossCores: BossCores,
	dailyPlunderDayId: number,
	dailyPlunderCount: number,
	squads: { DeckSquad },
	championCardId: string?,
	championLaneMode: string,
}

export type League = { points: number, season: number }

export type Stats = {
	raids: number,
	defenses: number,
	wins: number,
	sessions: number,
	playSeconds: number,
	firstSeenAt: number,
	lastSeenAt: number,
}

export type FtueState = {
	step: number,
	skipped: boolean,
	completedAt: number,
}

export type BattleHistoryTrap = {
	cell: string?,
	type: string,
	level: number,
	x: number?,
	y: number?,
}

export type BattleHistoryWall = {
	level: number,
	hp: number,
	traps: { BattleHistoryTrap },
}

export type BattleHistoryEntry = {
	battleId: string,
	role: string,
	winner: string,
	rivalHash: string,
	rivalLabel: string,
	leagueDelta: number,
	goldDelta: number,
	createdAt: number,
	resultHash: number,
	seed: number,
	isBot: boolean,
	revenged: boolean,
	rivalWall: BattleHistoryWall?,
	waveSpec: { [string]: any }?,
}

export type Profile = {
	schemaVersion: number,
	contentVersion: number,
	wall: Wall,
	gold: number,
	league: League,
	cosmetics: { [string]: boolean },
	equipped: Equipped,
	campaign: CampaignProgress,
	horde: HordeProgress,
	stats: Stats,
	ftue: FtueState,
	revengeCooldowns: { [string]: number },
	battleHistory: { BattleHistoryEntry },
}

-- Campos proibidos: PII nao entra no perfil (o UserId e a chave, nao o dado). A lista tambem
-- protege contra um campo novo que "pareca" dado pessoal entrar por engano.
ProfileSchema.PII_KEYS = {
	address = true,
	age = true,
	birthdate = true,
	birthday = true,
	chat = true,
	cookie = true,
	device_id = true,
	discord = true,
	display_name = true,
	email = true,
	hardware_id = true,
	ip = true,
	message = true,
	name = true,
	password = true,
	phone = true,
	player_name = true,
	token = true,
	user_id = true,
	userid = true,
	username = true,
}

local TOP_FIELDS = {
	"schemaVersion",
	"contentVersion",
	"wall",
	"gold",
	"league",
	"cosmetics",
	"equipped",
	"campaign",
	"horde",
	"stats",
	"ftue",
	"revengeCooldowns",
	"battleHistory",
}
local WALL_FIELDS = { "level", "gridWidth", "activeTrapLimit", "cells" }
local CELL_FIELDS = { "trap", "level", "x", "y" }
local EQUIPPED_FIELDS = { "theme", "hordeSkin", "finisher", "commander" }
local CAMPAIGN_FIELDS = {
	"highestUnlockedStage",
	"nightmareUnlocked",
	"starsNormal",
	"starsNightmare",
	"actMilestoneClaims",
}
local HORDE_FIELDS = {
	"starterChosen",
	"faction",
	"unlockedCards",
	"shards",
	"bossCores",
	"dailyPlunderDayId",
	"dailyPlunderCount",
	"squads",
	"championCardId",
	"championLaneMode",
}
local BOSS_CORE_FIELDS = { "act1", "act2", "act3", "act4", "act5" }
local SQUAD_FIELDS = { "cardId", "count", "laneMode" }
local LEAGUE_FIELDS = { "points", "season" }
local STATS_FIELDS = {
	"raids",
	"defenses",
	"wins",
	"sessions",
	"playSeconds",
	"firstSeenAt",
	"lastSeenAt",
}
local FTUE_FIELDS = { "step", "skipped", "completedAt" }
local HISTORY_ENTRY_FIELDS = {
	"battleId",
	"role",
	"winner",
	"rivalHash",
	"rivalLabel",
	"leagueDelta",
	"goldDelta",
	"createdAt",
	"resultHash",
	"seed",
	"isBot",
	"revenged",
	"rivalWall",
	"waveSpec",
}
local HISTORY_WALL_FIELDS = { "level", "hp", "traps" }
local HISTORY_TRAP_FIELDS = { "cell", "type", "level", "x", "y" }
local WAVE_SPEC_FIELDS = {
	"count",
	"spawnEveryTicks",
	"hpScaleMilli",
	"modeScaleMilli",
	"armorMilli",
	"speedMilli",
	"bossId",
	"bossHpScaleMilli",
	"bossSpawnTick",
	"pool",
	"mutatorIds",
	"slices",
}
local WAVE_SLICE_FIELDS = {
	"startTick",
	"everyTicks",
	"count",
	"unit",
	"laneMask",
	"isElite",
	"isChampion",
}

local function fieldSet(fields: { string }): { [string]: boolean }
	local set: { [string]: boolean } = {}
	for _, field in ipairs(fields) do
		set[field] = true
	end
	return set
end

local TOP_SET = fieldSet(TOP_FIELDS)
local WALL_SET = fieldSet(WALL_FIELDS)
local CELL_SET = fieldSet(CELL_FIELDS)
local EQUIPPED_SET = fieldSet(EQUIPPED_FIELDS)
local CAMPAIGN_SET = fieldSet(CAMPAIGN_FIELDS)
local HORDE_SET = fieldSet(HORDE_FIELDS)
local BOSS_CORE_SET = fieldSet(BOSS_CORE_FIELDS)
local SQUAD_SET = fieldSet(SQUAD_FIELDS)
local LEAGUE_SET = fieldSet(LEAGUE_FIELDS)
local STATS_SET = fieldSet(STATS_FIELDS)
local FTUE_SET = fieldSet(FTUE_FIELDS)
local HISTORY_ENTRY_SET = fieldSet(HISTORY_ENTRY_FIELDS)
local HISTORY_WALL_SET = fieldSet(HISTORY_WALL_FIELDS)
local HISTORY_TRAP_SET = fieldSet(HISTORY_TRAP_FIELDS)
local WAVE_SPEC_SET = fieldSet(WAVE_SPEC_FIELDS)
local WAVE_SLICE_SET = fieldSet(WAVE_SLICE_FIELDS)

local HISTORY_ROLES: { [string]: boolean } = {
	attack = true,
	defense = true,
	revenge = true,
}

local HISTORY_WINNERS: { [string]: boolean } = {
	attacker = true,
	defender = true,
}

local WAVE_SPEC_INT_FIELDS = {
	"count",
	"spawnEveryTicks",
	"hpScaleMilli",
	"modeScaleMilli",
	"armorMilli",
	"speedMilli",
	"bossHpScaleMilli",
	"bossSpawnTick",
}

local HORDE_FACTIONS: { [string]: boolean } = {
	iron = true,
	slag = true,
	frost = true,
	powder = true,
	rift = true,
}

local LANE_MODES: { [string]: boolean } = {
	center = true,
	flanks = true,
	split = true,
	all = true,
}

local IRON_STARTER_UNLOCKED: { string } = {
	"squad_runner_pack",
	"squad_brute_guards",
	"squad_iron_vanguard",
}

local IRON_STARTER_SQUADS: { DeckSquad } = {
	{ cardId = "squad_iron_vanguard", count = 2, laneMode = "center" },
	{ cardId = "squad_runner_pack", count = 2, laneMode = "flanks" },
	{ cardId = "squad_brute_guards", count = 2, laneMode = "split" },
}

local function newEquipped(): Equipped
	return {
		theme = ProfileSchema.EQUIPPED_DEFAULTS.theme,
		hordeSkin = ProfileSchema.EQUIPPED_DEFAULTS.hordeSkin,
		finisher = ProfileSchema.EQUIPPED_DEFAULTS.finisher,
		commander = ProfileSchema.EQUIPPED_DEFAULTS.commander,
	}
end

local function newCampaign(): CampaignProgress
	return {
		highestUnlockedStage = "1-1",
		nightmareUnlocked = false,
		starsNormal = {},
		starsNightmare = {},
		actMilestoneClaims = {
			["1"] = 0,
			["2"] = 0,
			["3"] = 0,
			["4"] = 0,
			["5"] = 0,
		},
	}
end

local function newHorde(): HordeProgress
	local unlockedCards: { [string]: boolean } = {}
	for _, cardId in ipairs(IRON_STARTER_UNLOCKED) do
		unlockedCards[cardId] = true
	end
	local squads: { DeckSquad } = {}
	for index, sq in ipairs(IRON_STARTER_SQUADS) do
		squads[index] = {
			cardId = sq.cardId,
			count = sq.count,
			laneMode = sq.laneMode,
		}
	end
	return {
		starterChosen = false,
		faction = "iron",
		unlockedCards = unlockedCards,
		shards = 0,
		bossCores = {
			act1 = false,
			act2 = false,
			act3 = false,
			act4 = false,
			act5 = false,
		},
		dailyPlunderDayId = 0,
		dailyPlunderCount = 0,
		squads = squads,
		championCardId = nil,
		championLaneMode = "center",
	}
end

local function newProfile(): Profile
	return {
		schemaVersion = ProfileSchema.SCHEMA_VERSION,
		contentVersion = ProfileSchema.DEFAULT_CONTENT_VERSION,
		wall = {
			level = 1,
			gridWidth = ProfileSchema.GRID_WIDTH,
			activeTrapLimit = ProfileSchema.ACTIVE_TRAP_LIMIT,
			cells = {},
		},
		gold = 0,
		league = { points = 0, season = 1 },
		cosmetics = {},
		equipped = newEquipped(),
		campaign = newCampaign(),
		horde = newHorde(),
		stats = {
			raids = 0,
			defenses = 0,
			wins = 0,
			sessions = 0,
			playSeconds = 0,
			firstSeenAt = 0,
			lastSeenAt = 0,
		},
		ftue = {
			step = 0,
			skipped = false,
			completedAt = 0,
		},
		revengeCooldowns = {},
		battleHistory = {},
	}
end

-- Template do ProfileStore: todo perfil nasce completo e JSON-safe. Devolve tabela nova a
-- cada chamada (o Reconcile muta o template; nao compartilhar referencia).
function ProfileSchema.template(): Profile
	return newProfile()
end

-- ---------------------------------------------------------------- validacao
local function isFiniteInteger(value: any): boolean
	if type(value) ~= "number" then
		return false
	end
	local n = value :: number
	return n == n and n ~= math.huge and n ~= -math.huge and n % 1 == 0
end

local function clampInt(value: number, min: number, max: number): number
	if value < min then
		return min
	end
	if value > max then
		return max
	end
	return value
end

local function isIdString(value: any, maxLen: number): boolean
	if type(value) ~= "string" then
		return false
	end
	local s = value :: string
	if #s == 0 or #s > maxLen then
		return false
	end
	return string.match(s, "^[%w_%.%-]+$") ~= nil
end

local function isBattleId(value: any): boolean
	if type(value) ~= "string" then
		return false
	end
	local s = value :: string
	if #s == 0 or #s > ProfileSchema.MAX_BATTLE_ID_LENGTH then
		return false
	end
	return string.match(s, "^[%w_%.%-:]+$") ~= nil
end

local function isSafeLabel(value: any): boolean
	if type(value) ~= "string" then
		return false
	end
	local s = value :: string
	if #s == 0 or #s > ProfileSchema.MAX_LABEL_LENGTH then
		return false
	end
	return string.find(s, "[%c]") == nil
end

local function checkDenseArray(value: any, maxLen: number, path: string): (boolean, string?)
	if type(value) ~= "table" then
		return false, path .. " ausente"
	end
	local count = 0
	for k in pairs(value) do
		count += 1
		if not isFiniteInteger(k) or (k :: number) < 1 then
			return false, path .. ": chave nao-indice"
		end
	end
	if count ~= #value or #value > maxLen then
		return false, path .. ": formato ou tamanho invalido"
	end
	return true, nil
end

function ProfileSchema.isValidStageId(stageId: any): boolean
	if type(stageId) ~= "string" then
		return false
	end
	local text = stageId :: string
	local actText, idxText = string.match(text, "^(%d+)%-(%d+)$")
	if actText == nil or idxText == nil then
		return false
	end
	local act = tonumber(actText) :: number
	local idx = tonumber(idxText) :: number
	if
		act < 1
		or act > ProfileSchema.CAMPAIGN_ACTS
		or idx < 1
		or idx > ProfileSchema.CAMPAIGN_STAGES_PER_ACT
	then
		return false
	end
	return string.format("%d-%d", act, idx) == text
end

function ProfileSchema.isValidActKey(actKey: any): boolean
	if type(actKey) ~= "string" then
		return false
	end
	local text = actKey :: string
	local act = tonumber(text)
	if act == nil or act % 1 ~= 0 or act < 1 or act > ProfileSchema.CAMPAIGN_ACTS then
		return false
	end
	return tostring(act) == text
end

function ProfileSchema.isValidSlot(slot: any): boolean
	if type(slot) ~= "string" then
		return false
	end
	local s = slot :: string
	if #s == 0 or #s > ProfileSchema.MAX_SLOT_LENGTH then
		return false
	end
	if string.match(s, "^r%d+c%d+$") ~= nil then
		local r, c = string.match(s, "^r(%d+)c(%d+)$")
		local rn = tonumber(r) :: number
		local cn = tonumber(c) :: number
		return rn >= 1
			and rn <= ProfileSchema.GRID_HEIGHT
			and cn >= 1
			and cn <= ProfileSchema.MAX_GRID_WIDTH
			and string.format("r%dc%d", rn, cn) == s
	end
	return string.match(s, "^[a-z0-9_]+$") ~= nil
end

function ProfileSchema.validatePosition(x: any, y: any): (boolean, string?)
	if not isFiniteInteger(x) or not isFiniteInteger(y) then
		return false, "posicao nao e inteira"
	end
	local nx = x :: number
	local ny = y :: number
	if
		nx < ProfileSchema.ARENA.xMin
		or nx > ProfileSchema.ARENA.xMax
		or ny < ProfileSchema.ARENA.yMin
		or ny > ProfileSchema.ARENA.yMax
	then
		return false, "posicao fora da arena"
	end
	if nx % ProfileSchema.ARENA.step ~= 0 or ny % ProfileSchema.ARENA.step ~= 0 then
		return false, "posicao fora da grade de " .. tostring(ProfileSchema.ARENA.step)
	end
	return true, nil
end

function ProfileSchema.tooClose(ax: number, ay: number, bx: number, by: number): boolean
	return math.abs(ax - bx) < ProfileSchema.ARENA.minSpacing
		and math.abs(ay - by) < ProfileSchema.ARENA.minSpacing
end

local function cellKeyOk(key: any, gridWidth: number): boolean
	if type(key) ~= "string" then
		return false
	end
	local text = key :: string
	local rowText, colText = string.match(text, "^r(%d+)c(%d+)$")
	if rowText == nil or colText == nil then
		return false
	end
	local row = tonumber(rowText) :: number
	local col = tonumber(colText) :: number
	if row < 1 or row > ProfileSchema.GRID_HEIGHT then
		return false
	end
	if col < 1 or col > gridWidth then
		return false
	end
	return string.format("r%dc%d", row, col) == text
end

function ProfileSchema.cellToPos(cell: any): (number?, number?)
	if type(cell) ~= "string" then
		return nil, nil
	end
	local text = cell :: string
	local rowText, colText = string.match(text, "^r(%d+)c(%d+)$")
	if rowText == nil or colText == nil then
		return nil, nil
	end
	local row = tonumber(rowText) :: number
	local col = tonumber(colText) :: number
	if row < 1 or row > ProfileSchema.GRID_HEIGHT or col < 1 or col > ProfileSchema.GRID_WIDTH then
		return nil, nil
	end
	if string.format("r%dc%d", row, col) ~= text then
		return nil, nil
	end
	return ProfileSchema.COLUMN_X[col], row * 1000 - 500
end

local function checkForeignKeys(
	value: { [any]: any },
	allowed: { [string]: boolean },
	path: string
): (boolean, string?)
	for key in pairs(value) do
		if type(key) ~= "string" then
			return false, path .. ": chave nao-string"
		end
		local name = key :: string
		if ProfileSchema.PII_KEYS[string.lower(name)] then
			return false, path .. ": campo PII proibido (" .. name .. ")"
		end
		if allowed[name] ~= true then
			return false, path .. ": campo desconhecido (" .. name .. ")"
		end
	end
	return true, nil
end

local function validateWall(wall: any): (boolean, string?)
	if type(wall) ~= "table" then
		return false, "wall ausente"
	end
	local okKeys, errKeys = checkForeignKeys(wall, WALL_SET, "wall")
	if not okKeys then
		return false, errKeys
	end
	if not isFiniteInteger(wall.level) then
		return false, "wall.level nao e inteiro"
	end
	local wallLevel = wall.level :: number
	if wallLevel < 1 or wallLevel > ProfileSchema.MAX_WALL_LEVEL then
		return false, "wall.level fora de [1," .. tostring(ProfileSchema.MAX_WALL_LEVEL) .. "]"
	end
	if not isFiniteInteger(wall.gridWidth) then
		return false, "wall.gridWidth nao e inteiro"
	end
	local gridWidth = wall.gridWidth :: number
	if gridWidth < ProfileSchema.GRID_WIDTH or gridWidth > ProfileSchema.MAX_GRID_WIDTH then
		return false, "wall.gridWidth fora de [" .. ProfileSchema.GRID_WIDTH .. ",7]"
	end
	if not isFiniteInteger(wall.activeTrapLimit) then
		return false, "wall.activeTrapLimit nao e inteiro"
	end
	local limit = wall.activeTrapLimit :: number
	if
		limit < ProfileSchema.MIN_ACTIVE_TRAP_LIMIT
		or limit > ProfileSchema.MAX_ACTIVE_TRAP_LIMIT
	then
		return false,
			string.format(
				"wall.activeTrapLimit fora de [%d,%d]",
				ProfileSchema.MIN_ACTIVE_TRAP_LIMIT,
				ProfileSchema.MAX_ACTIVE_TRAP_LIMIT
			)
	end
	if type(wall.cells) ~= "table" then
		return false, "wall.cells ausente"
	end
	local count = 0
	local placed: { { slot: string, x: number, y: number } } = {}
	for key, cell in pairs(wall.cells) do
		count += 1
		if count > limit then
			return false, "wall.cells acima de " .. tostring(limit)
		end
		if not ProfileSchema.isValidSlot(key) then
			return false, "wall.cells: slot invalido (" .. tostring(key) .. ")"
		end
		if type(cell) ~= "table" then
			return false, "wall.cells." .. tostring(key) .. " nao e tabela"
		end
		local okCell, errCell = checkForeignKeys(cell, CELL_SET, "wall.cells." .. tostring(key))
		if not okCell then
			return false, errCell
		end
		if not isIdString(cell.trap, ProfileSchema.MAX_ID_LENGTH) then
			return false, "wall.cells." .. tostring(key) .. ".trap invalido"
		end
		if not isFiniteInteger(cell.level) then
			return false, "wall.cells." .. tostring(key) .. ".level nao e inteiro"
		end
		local level = cell.level :: number
		if level < 1 or level > ProfileSchema.MAX_TRAP_LEVEL then
			return false, "wall.cells." .. tostring(key) .. ".level fora de [1,5]"
		end
		local okPos, errPos = ProfileSchema.validatePosition(cell.x, cell.y)
		if not okPos then
			return false, "wall.cells." .. tostring(key) .. ": " .. tostring(errPos)
		end
		local cx = cell.x :: number
		local cy = cell.y :: number
		for _, other in ipairs(placed) do
			if ProfileSchema.tooClose(cx, cy, other.x, other.y) then
				return false,
					string.format(
						"wall.cells.%s muito perto de %s (%d,%d)",
						tostring(key),
						other.slot,
						cx,
						cy
					)
			end
		end
		placed[#placed + 1] = { slot = key :: string, x = cx, y = cy }
	end
	return true, nil
end

local function validateEquipped(equipped: any): (boolean, string?)
	if type(equipped) ~= "table" then
		return false, "equipped ausente"
	end
	local okKeys, errKeys = checkForeignKeys(equipped, EQUIPPED_SET, "equipped")
	if not okKeys then
		return false, errKeys
	end
	for _, field in ipairs(EQUIPPED_FIELDS) do
		if not isIdString(equipped[field], ProfileSchema.MAX_ID_LENGTH) then
			return false, "equipped." .. field .. " invalido"
		end
	end
	return true, nil
end

local function validateStarsMap(map: any, label: string): (boolean, string?)
	if type(map) ~= "table" then
		return false, label .. " ausente"
	end
	for key, mask in pairs(map) do
		if not ProfileSchema.isValidStageId(key) then
			return false, label .. ": stageId invalido (" .. tostring(key) .. ")"
		end
		if not isFiniteInteger(mask) then
			return false, label .. "." .. tostring(key) .. " nao e inteiro"
		end
		local m = mask :: number
		if m < 0 or m > ProfileSchema.MAX_STAR_MASK then
			return false, label .. "." .. tostring(key) .. " fora de [0,7]"
		end
	end
	return true, nil
end

local function validateCampaign(campaign: any): (boolean, string?)
	if type(campaign) ~= "table" then
		return false, "campaign ausente"
	end
	local okKeys, errKeys = checkForeignKeys(campaign, CAMPAIGN_SET, "campaign")
	if not okKeys then
		return false, errKeys
	end
	if not ProfileSchema.isValidStageId(campaign.highestUnlockedStage) then
		return false, "campaign.highestUnlockedStage invalido"
	end
	if type(campaign.nightmareUnlocked) ~= "boolean" then
		return false, "campaign.nightmareUnlocked nao e boolean"
	end
	local okNorm, errNorm = validateStarsMap(campaign.starsNormal, "campaign.starsNormal")
	if not okNorm then
		return false, errNorm
	end
	local okNight, errNight = validateStarsMap(campaign.starsNightmare, "campaign.starsNightmare")
	if not okNight then
		return false, errNight
	end
	if type(campaign.actMilestoneClaims) ~= "table" then
		return false, "campaign.actMilestoneClaims ausente"
	end
	for key, mask in pairs(campaign.actMilestoneClaims) do
		if not ProfileSchema.isValidActKey(key) then
			return false, "campaign.actMilestoneClaims: chave invalida (" .. tostring(key) .. ")"
		end
		if not isFiniteInteger(mask) then
			return false, "campaign.actMilestoneClaims." .. tostring(key) .. " nao e inteiro"
		end
		local m = mask :: number
		if m < 0 or m > ProfileSchema.MAX_STAR_MASK then
			return false, "campaign.actMilestoneClaims." .. tostring(key) .. " fora de [0,7]"
		end
	end
	return true, nil
end

local function validateHorde(horde: any): (boolean, string?)
	if type(horde) ~= "table" then
		return false, "horde ausente"
	end
	local okKeys, errKeys = checkForeignKeys(horde, HORDE_SET, "horde")
	if not okKeys then
		return false, errKeys
	end
	if type(horde.starterChosen) ~= "boolean" then
		return false, "horde.starterChosen nao e boolean"
	end
	if type(horde.faction) ~= "string" or HORDE_FACTIONS[horde.faction] ~= true then
		return false, "horde.faction invalido"
	end
	if type(horde.unlockedCards) ~= "table" then
		return false, "horde.unlockedCards ausente"
	end
	local cardCount = 0
	for cardId, unlocked in pairs(horde.unlockedCards) do
		cardCount += 1
		if cardCount > ProfileSchema.MAX_HORDE_CARDS then
			return false, "horde.unlockedCards acima de " .. tostring(ProfileSchema.MAX_HORDE_CARDS)
		end
		if not isIdString(cardId, ProfileSchema.MAX_ID_LENGTH) then
			return false, "horde.unlockedCards: chave invalida (" .. tostring(cardId) .. ")"
		end
		if type(unlocked) ~= "boolean" then
			return false, "horde.unlockedCards." .. tostring(cardId) .. " nao e boolean"
		end
	end
	if not isFiniteInteger(horde.shards) or (horde.shards :: number) < 0 then
		return false, "horde.shards invalido"
	end
	if type(horde.bossCores) ~= "table" then
		return false, "horde.bossCores ausente"
	end
	local okCores, errCores = checkForeignKeys(horde.bossCores, BOSS_CORE_SET, "horde.bossCores")
	if not okCores then
		return false, errCores
	end
	for _, coreKey in ipairs(BOSS_CORE_FIELDS) do
		if type(horde.bossCores[coreKey]) ~= "boolean" then
			return false, "horde.bossCores." .. coreKey .. " nao e boolean"
		end
	end
	if not isFiniteInteger(horde.dailyPlunderDayId) or (horde.dailyPlunderDayId :: number) < 0 then
		return false, "horde.dailyPlunderDayId invalido"
	end
	if not isFiniteInteger(horde.dailyPlunderCount) or (horde.dailyPlunderCount :: number) < 0 then
		return false, "horde.dailyPlunderCount invalido"
	end
	if type(horde.squads) ~= "table" then
		return false, "horde.squads ausente"
	end
	local rawSquadCount = 0
	for k in pairs(horde.squads) do
		rawSquadCount += 1
		if not isFiniteInteger(k) or (k :: number) < 1 then
			return false, "horde.squads: chave invalida"
		end
	end
	if rawSquadCount ~= #horde.squads or #horde.squads > ProfileSchema.MAX_DECK_SQUADS then
		return false, "horde.squads formato ou tamanho invalido"
	end
	for index, squad in ipairs(horde.squads) do
		if type(squad) ~= "table" then
			return false, "horde.squads[" .. tostring(index) .. "] nao e tabela"
		end
		local okSquad, errSquad =
			checkForeignKeys(squad, SQUAD_SET, "horde.squads[" .. tostring(index) .. "]")
		if not okSquad then
			return false, errSquad
		end
		if not isIdString(squad.cardId, ProfileSchema.MAX_ID_LENGTH) then
			return false, "horde.squads[" .. tostring(index) .. "].cardId invalido"
		end
		if
			not isFiniteInteger(squad.count)
			or (squad.count :: number) < 0
			or (squad.count :: number) > ProfileSchema.MAX_SQUAD_UNITS
		then
			return false, "horde.squads[" .. tostring(index) .. "].count invalido"
		end
		if type(squad.laneMode) ~= "string" or LANE_MODES[squad.laneMode] ~= true then
			return false, "horde.squads[" .. tostring(index) .. "].laneMode invalido"
		end
	end
	if
		horde.championCardId ~= nil
		and not isIdString(horde.championCardId, ProfileSchema.MAX_ID_LENGTH)
	then
		return false, "horde.championCardId invalido"
	end
	if type(horde.championLaneMode) ~= "string" or LANE_MODES[horde.championLaneMode] ~= true then
		return false, "horde.championLaneMode invalido"
	end
	return true, nil
end

local function validateLeague(league: any): (boolean, string?)
	if type(league) ~= "table" then
		return false, "league ausente"
	end
	local okKeys, errKeys = checkForeignKeys(league, LEAGUE_SET, "league")
	if not okKeys then
		return false, errKeys
	end
	if not isFiniteInteger(league.points) or league.points < 0 then
		return false, "league.points invalido"
	end
	if not isFiniteInteger(league.season) or league.season < 1 then
		return false, "league.season invalido"
	end
	return true, nil
end

local function validateCosmetics(cosmetics: any): (boolean, string?)
	if type(cosmetics) ~= "table" then
		return false, "cosmetics ausente"
	end
	local count = 0
	for key, owned in pairs(cosmetics) do
		count += 1
		if count > ProfileSchema.MAX_COSMETICS then
			return false, "cosmetics acima de " .. tostring(ProfileSchema.MAX_COSMETICS)
		end
		if not isIdString(key, ProfileSchema.MAX_ID_LENGTH) then
			return false, "cosmetics: chave invalida (" .. tostring(key) .. ")"
		end
		if type(owned) ~= "boolean" then
			return false, "cosmetics." .. tostring(key) .. " nao e boolean"
		end
	end
	return true, nil
end

local function validateStats(stats: any): (boolean, string?)
	if type(stats) ~= "table" then
		return false, "stats ausente"
	end
	local okKeys, errKeys = checkForeignKeys(stats, STATS_SET, "stats")
	if not okKeys then
		return false, errKeys
	end
	for _, field in ipairs(STATS_FIELDS) do
		local value = stats[field]
		if not isFiniteInteger(value) then
			return false, "stats." .. field .. " nao e inteiro"
		end
		if (value :: number) < 0 then
			return false, "stats." .. field .. " negativo"
		end
	end
	return true, nil
end

local function validateFtue(ftue: any): (boolean, string?)
	if type(ftue) ~= "table" then
		return false, "ftue ausente"
	end
	local okKeys, errKeys = checkForeignKeys(ftue, FTUE_SET, "ftue")
	if not okKeys then
		return false, errKeys
	end
	if
		not isFiniteInteger(ftue.step)
		or (ftue.step :: number) < 0
		or (ftue.step :: number) > ProfileSchema.MAX_FTUE_STEP
	then
		return false, "ftue.step fora de [0," .. tostring(ProfileSchema.MAX_FTUE_STEP) .. "]"
	end
	if type(ftue.skipped) ~= "boolean" then
		return false, "ftue.skipped nao e boolean"
	end
	if not isFiniteInteger(ftue.completedAt) or (ftue.completedAt :: number) < 0 then
		return false, "ftue.completedAt invalido"
	end
	return true, nil
end

local function validateRevengeCooldowns(cooldowns: any): (boolean, string?)
	if type(cooldowns) ~= "table" then
		return false, "revengeCooldowns ausente"
	end
	local count = 0
	for rivalHash, ts in pairs(cooldowns) do
		count += 1
		if count > ProfileSchema.MAX_REVENGE_COOLDOWNS then
			return false,
				"revengeCooldowns acima de " .. tostring(ProfileSchema.MAX_REVENGE_COOLDOWNS)
		end
		if
			not isIdString(rivalHash, ProfileSchema.MAX_ID_LENGTH)
			or ProfileSchema.PII_KEYS[string.lower(rivalHash :: string)]
		then
			return false, "revengeCooldowns: chave invalida (" .. tostring(rivalHash) .. ")"
		end
		if not isFiniteInteger(ts) or (ts :: number) < 0 then
			return false, "revengeCooldowns." .. tostring(rivalHash) .. " invalido"
		end
	end
	return true, nil
end

local function validateHistoryWall(wall: any, path: string): (boolean, string?)
	if type(wall) ~= "table" then
		return false, path .. " nao e tabela"
	end
	local okKeys, errKeys = checkForeignKeys(wall, HISTORY_WALL_SET, path)
	if not okKeys then
		return false, errKeys
	end
	if
		not isFiniteInteger(wall.level)
		or (wall.level :: number) < 1
		or (wall.level :: number) > ProfileSchema.MAX_WALL_LEVEL
	then
		return false, path .. ".level invalido"
	end
	if not isFiniteInteger(wall.hp) or (wall.hp :: number) < 1 then
		return false, path .. ".hp invalido"
	end
	local okTraps, errTraps = checkDenseArray(wall.traps, ProfileSchema.MAX_CELLS, path .. ".traps")
	if not okTraps then
		return false, errTraps
	end
	for idx, trap in ipairs(wall.traps) do
		local tPath = path .. ".traps[" .. tostring(idx) .. "]"
		if type(trap) ~= "table" then
			return false, tPath .. " nao e tabela"
		end
		local okTrapKeys, errTrapKeys = checkForeignKeys(trap, HISTORY_TRAP_SET, tPath)
		if not okTrapKeys then
			return false, errTrapKeys
		end
		if not isIdString(trap.type, ProfileSchema.MAX_ID_LENGTH) then
			return false, tPath .. ".type invalido"
		end
		if
			not isFiniteInteger(trap.level)
			or (trap.level :: number) < 1
			or (trap.level :: number) > ProfileSchema.MAX_TRAP_LEVEL
		then
			return false, tPath .. ".level invalido"
		end
		local hasPos = trap.x ~= nil or trap.y ~= nil
		if hasPos then
			local okPos, errPos = ProfileSchema.validatePosition(trap.x, trap.y)
			if not okPos then
				return false, tPath .. ": " .. tostring(errPos)
			end
		elseif not ProfileSchema.isValidSlot(trap.cell) then
			return false, tPath .. ".cell ausente/invalido"
		end
		if trap.cell ~= nil and not ProfileSchema.isValidSlot(trap.cell) then
			return false, tPath .. ".cell invalido"
		end
	end
	return true, nil
end

local function validateWaveSpec(waveSpec: any, path: string): (boolean, string?)
	if type(waveSpec) ~= "table" then
		return false, path .. " nao e tabela"
	end
	local okKeys, errKeys = checkForeignKeys(waveSpec, WAVE_SPEC_SET, path)
	if not okKeys then
		return false, errKeys
	end
	for _, field in ipairs(WAVE_SPEC_INT_FIELDS) do
		local v = waveSpec[field]
		if v ~= nil and (not isFiniteInteger(v) or (v :: number) < 0) then
			return false, path .. "." .. field .. " invalido"
		end
	end
	if waveSpec.bossId ~= nil and not isIdString(waveSpec.bossId, ProfileSchema.MAX_ID_LENGTH) then
		return false, path .. ".bossId invalido"
	end
	for _, listField in ipairs({ "pool", "mutatorIds" }) do
		local list = waveSpec[listField]
		if list ~= nil then
			local okArr, errArr = checkDenseArray(list, 32, path .. "." .. listField)
			if not okArr then
				return false, errArr
			end
			for i, item in ipairs(list) do
				if not isIdString(item, ProfileSchema.MAX_ID_LENGTH) then
					return false, path .. "." .. listField .. "[" .. tostring(i) .. "] invalido"
				end
			end
		end
	end
	if waveSpec.slices ~= nil then
		local okSlices, errSlices = checkDenseArray(waveSpec.slices, 16, path .. ".slices")
		if not okSlices then
			return false, errSlices
		end
		for idx, slice in ipairs(waveSpec.slices) do
			local sPath = path .. ".slices[" .. tostring(idx) .. "]"
			if type(slice) ~= "table" then
				return false, sPath .. " nao e tabela"
			end
			local okSKeys, errSKeys = checkForeignKeys(slice, WAVE_SLICE_SET, sPath)
			if not okSKeys then
				return false, errSKeys
			end
			for _, sf in ipairs({ "startTick", "everyTicks", "count" }) do
				if not isFiniteInteger(slice[sf]) or (slice[sf] :: number) < 0 then
					return false, sPath .. "." .. sf .. " invalido"
				end
			end
			if not isIdString(slice.unit, ProfileSchema.MAX_ID_LENGTH) then
				return false, sPath .. ".unit invalido"
			end
			if
				slice.laneMask ~= nil
				and (not isFiniteInteger(slice.laneMask) or (slice.laneMask :: number) < 0)
			then
				return false, sPath .. ".laneMask invalido"
			end
			if slice.isElite ~= nil and type(slice.isElite) ~= "boolean" then
				return false, sPath .. ".isElite invalido"
			end
			if slice.isChampion ~= nil and type(slice.isChampion) ~= "boolean" then
				return false, sPath .. ".isChampion invalido"
			end
		end
	end
	return true, nil
end

local function validateBattleHistory(history: any): (boolean, string?)
	local okArr, errArr =
		checkDenseArray(history, ProfileSchema.MAX_BATTLE_HISTORY, "battleHistory")
	if not okArr then
		return false, errArr
	end
	for idx, entry in ipairs(history) do
		local path = "battleHistory[" .. tostring(idx) .. "]"
		if type(entry) ~= "table" then
			return false, path .. " nao e tabela"
		end
		local okKeys, errKeys = checkForeignKeys(entry, HISTORY_ENTRY_SET, path)
		if not okKeys then
			return false, errKeys
		end
		if not isBattleId(entry.battleId) then
			return false, path .. ".battleId invalido"
		end
		if type(entry.role) ~= "string" or HISTORY_ROLES[entry.role] ~= true then
			return false, path .. ".role invalido"
		end
		if type(entry.winner) ~= "string" or HISTORY_WINNERS[entry.winner] ~= true then
			return false, path .. ".winner invalido"
		end
		if not isIdString(entry.rivalHash, ProfileSchema.MAX_ID_LENGTH) then
			return false, path .. ".rivalHash invalido"
		end
		if not isSafeLabel(entry.rivalLabel) then
			return false, path .. ".rivalLabel invalido"
		end
		if
			not isFiniteInteger(entry.leagueDelta)
			or (entry.leagueDelta :: number) < -1000
			or (entry.leagueDelta :: number) > 1000
		then
			return false, path .. ".leagueDelta invalido"
		end
		if
			not isFiniteInteger(entry.goldDelta)
			or (entry.goldDelta :: number) < -ProfileSchema.MAX_GOLD
			or (entry.goldDelta :: number) > ProfileSchema.MAX_GOLD
		then
			return false, path .. ".goldDelta invalido"
		end
		for _, intField in ipairs({ "createdAt", "resultHash", "seed" }) do
			if not isFiniteInteger(entry[intField]) or (entry[intField] :: number) < 0 then
				return false, path .. "." .. intField .. " invalido"
			end
		end
		if type(entry.isBot) ~= "boolean" or type(entry.revenged) ~= "boolean" then
			return false, path .. ".flags boolean invalidas"
		end
		if entry.rivalWall ~= nil then
			local okWall, errWall = validateHistoryWall(entry.rivalWall, path .. ".rivalWall")
			if not okWall then
				return false, errWall
			end
		end
		if entry.waveSpec ~= nil then
			local okWave, errWave = validateWaveSpec(entry.waveSpec, path .. ".waveSpec")
			if not okWave then
				return false, errWave
			end
		end
	end
	return true, nil
end

-- Valida o perfil inteiro contra o schema v6. Retorna (ok, erro) em vez de lancar: o chamador
-- decide entre migrar, descartar ou recusar a sessao.
function ProfileSchema.validate(data: any): (boolean, string?)
	if type(data) ~= "table" then
		return false, "perfil nao e tabela"
	end
	local okKeys, errKeys = checkForeignKeys(data, TOP_SET, "perfil")
	if not okKeys then
		return false, errKeys
	end
	if not isFiniteInteger(data.schemaVersion) then
		return false, "schemaVersion nao e inteiro"
	end
	if data.schemaVersion ~= ProfileSchema.SCHEMA_VERSION then
		return false,
			"schemaVersion " .. tostring(data.schemaVersion) .. " != " .. tostring(
				ProfileSchema.SCHEMA_VERSION
			)
	end
	if not isFiniteInteger(data.contentVersion) then
		return false, "contentVersion nao e inteiro"
	end
	if (data.contentVersion :: number) < 1 then
		return false, "contentVersion fora de [1,inf)"
	end
	local okWall, errWall = validateWall(data.wall)
	if not okWall then
		return false, errWall
	end
	if not isFiniteInteger(data.gold) then
		return false, "gold nao e inteiro"
	end
	if (data.gold :: number) < 0 or (data.gold :: number) > ProfileSchema.MAX_GOLD then
		return false, "gold fora de [0," .. tostring(ProfileSchema.MAX_GOLD) .. "]"
	end
	local okLeague, errLeague = validateLeague(data.league)
	if not okLeague then
		return false, errLeague
	end
	local okCosmetics, errCosmetics = validateCosmetics(data.cosmetics)
	if not okCosmetics then
		return false, errCosmetics
	end
	local okEquipped, errEquipped = validateEquipped(data.equipped)
	if not okEquipped then
		return false, errEquipped
	end
	local okCampaign, errCampaign = validateCampaign(data.campaign)
	if not okCampaign then
		return false, errCampaign
	end
	local okHorde, errHorde = validateHorde(data.horde)
	if not okHorde then
		return false, errHorde
	end
	local okStats, errStats = validateStats(data.stats)
	if not okStats then
		return false, errStats
	end
	local okFtue, errFtue = validateFtue(data.ftue)
	if not okFtue then
		return false, errFtue
	end
	local okCd, errCd = validateRevengeCooldowns(data.revengeCooldowns)
	if not okCd then
		return false, errCd
	end
	local okHistory, errHistory = validateBattleHistory(data.battleHistory)
	if not okHistory then
		return false, errHistory
	end
	return true, nil
end

-- ---------------------------------------------------------------- saneamento e migracao
local function sanitizeCell(slot: string, cell: any): Cell?
	if not ProfileSchema.isValidSlot(slot) or type(cell) ~= "table" then
		return nil
	end
	if not isIdString(cell.trap, ProfileSchema.MAX_ID_LENGTH) then
		return nil
	end
	if not isFiniteInteger(cell.level) then
		return nil
	end
	if not ProfileSchema.validatePosition(cell.x, cell.y) then
		return nil
	end
	local level = clampInt(cell.level :: number, 1, ProfileSchema.MAX_TRAP_LEVEL)
	return {
		trap = cell.trap :: string,
		level = level,
		x = cell.x :: number,
		y = cell.y :: number,
	}
end

local function sanitizeCommonScalars(profile: any, data: any): ()
	if isFiniteInteger(data.gold) then
		profile.gold = clampInt(data.gold :: number, 0, ProfileSchema.MAX_GOLD)
	end

	local league = data.league
	if type(league) == "table" then
		if isFiniteInteger(league.points) then
			profile.league.points = clampInt(league.points :: number, 0, ProfileSchema.MAX_COUNTER)
		end
		if isFiniteInteger(league.season) then
			profile.league.season = clampInt(league.season :: number, 1, ProfileSchema.MAX_COUNTER)
		end
	end

	local stats = data.stats
	if type(stats) == "table" then
		if isFiniteInteger(stats.raids) then
			profile.stats.raids = clampInt(stats.raids :: number, 0, ProfileSchema.MAX_COUNTER)
		end
		if isFiniteInteger(stats.defenses) then
			profile.stats.defenses =
				clampInt(stats.defenses :: number, 0, ProfileSchema.MAX_COUNTER)
		end
		if isFiniteInteger(stats.wins) then
			profile.stats.wins = clampInt(stats.wins :: number, 0, ProfileSchema.MAX_COUNTER)
		end
		if isFiniteInteger(stats.sessions) then
			profile.stats.sessions =
				clampInt(stats.sessions :: number, 0, ProfileSchema.MAX_COUNTER)
		end
		if isFiniteInteger(stats.playSeconds) then
			profile.stats.playSeconds =
				clampInt(stats.playSeconds :: number, 0, ProfileSchema.MAX_COUNTER)
		end
		if isFiniteInteger(stats.firstSeenAt) then
			profile.stats.firstSeenAt =
				clampInt(stats.firstSeenAt :: number, 0, ProfileSchema.MAX_COUNTER)
		end
		if isFiniteInteger(stats.lastSeenAt) then
			profile.stats.lastSeenAt =
				clampInt(stats.lastSeenAt :: number, 0, ProfileSchema.MAX_COUNTER)
		end
	end

	local cosmetics = data.cosmetics
	if type(cosmetics) == "table" then
		local keys: { string } = {}
		for key in pairs(cosmetics) do
			if type(key) == "string" then
				table.insert(keys, key :: string)
			end
		end
		table.sort(keys)
		local copied = 0
		for _, key in ipairs(keys) do
			if copied >= ProfileSchema.MAX_COSMETICS then
				break
			end
			if
				isIdString(key, ProfileSchema.MAX_ID_LENGTH)
				and type(cosmetics[key]) == "boolean"
			then
				profile.cosmetics[key] = cosmetics[key] :: boolean
				copied += 1
			end
		end
	end
end

local function sanitizeStarsMap(raw: any): { [string]: number }
	local out: { [string]: number } = {}
	if type(raw) ~= "table" then
		return out
	end
	for key, mask in pairs(raw) do
		if ProfileSchema.isValidStageId(key) and isFiniteInteger(mask) then
			out[key :: string] = clampInt(mask :: number, 0, ProfileSchema.MAX_STAR_MASK)
		end
	end
	return out
end

-- Reconstroi um perfil v6 valido a partir de qualquer tabela: so entra o que o schema
-- reconhece e cabe na faixa. E o que roda em todo load, entao lixo/PII nunca e persistido.
local function sanitizeHistoryWall(rawWall: any): BattleHistoryWall?
	if type(rawWall) ~= "table" then
		return nil
	end
	if not isFiniteInteger(rawWall.hp) or (rawWall.hp :: number) < 1 then
		return nil
	end
	if type(rawWall.traps) ~= "table" then
		return nil
	end
	local rawLevel = if isFiniteInteger(rawWall.level) then rawWall.level :: number else 1
	local cleanTraps: { BattleHistoryTrap } = {}
	for _, trap in ipairs(rawWall.traps) do
		if #cleanTraps >= ProfileSchema.MAX_CELLS then
			break
		end
		if
			type(trap) == "table"
			and isIdString(trap.type, ProfileSchema.MAX_ID_LENGTH)
			and isFiniteInteger(trap.level)
		then
			local hasPos = trap.x ~= nil or trap.y ~= nil
			local posOk = if hasPos then ProfileSchema.validatePosition(trap.x, trap.y) else false
			local cellOk = ProfileSchema.isValidSlot(trap.cell)
			if posOk or (not hasPos and cellOk) then
				local entry: BattleHistoryTrap = {
					type = trap.type :: string,
					level = clampInt(trap.level :: number, 1, ProfileSchema.MAX_TRAP_LEVEL),
				}
				if cellOk then
					entry.cell = trap.cell :: string
				end
				if posOk then
					entry.x = trap.x :: number
					entry.y = trap.y :: number
				end
				table.insert(cleanTraps, entry)
			end
		end
	end
	return {
		level = clampInt(rawLevel, 1, ProfileSchema.MAX_WALL_LEVEL),
		hp = clampInt(rawWall.hp :: number, 1, ProfileSchema.MAX_COUNTER),
		traps = cleanTraps,
	}
end

local function sanitizeStringArray(raw: any, maxLen: number): { string }?
	if type(raw) ~= "table" then
		return nil
	end
	local out: { string } = {}
	for _, item in ipairs(raw) do
		if #out >= maxLen then
			break
		end
		if isIdString(item, ProfileSchema.MAX_ID_LENGTH) then
			table.insert(out, item :: string)
		end
	end
	return out
end

local function sanitizeWaveSpec(rawWave: any): { [string]: any }?
	if type(rawWave) ~= "table" then
		return nil
	end
	local out: { [string]: any } = {}
	for _, field in ipairs(WAVE_SPEC_INT_FIELDS) do
		local val = rawWave[field]
		if isFiniteInteger(val) then
			out[field] = clampInt(val :: number, 0, ProfileSchema.MAX_COUNTER)
		end
	end
	if isIdString(rawWave.bossId, ProfileSchema.MAX_ID_LENGTH) then
		out.bossId = rawWave.bossId :: string
	end
	if type(rawWave.pool) == "table" then
		out.pool = sanitizeStringArray(rawWave.pool, 32)
	end
	if type(rawWave.mutatorIds) == "table" then
		out.mutatorIds = sanitizeStringArray(rawWave.mutatorIds, 32)
	end
	if type(rawWave.slices) == "table" then
		local cleanSlices: { { [string]: any } } = {}
		for _, slice in ipairs(rawWave.slices) do
			if #cleanSlices >= 16 then
				break
			end
			if
				type(slice) == "table"
				and isFiniteInteger(slice.startTick)
				and isFiniteInteger(slice.everyTicks)
				and isFiniteInteger(slice.count)
				and isIdString(slice.unit, ProfileSchema.MAX_ID_LENGTH)
			then
				local item: { [string]: any } = {
					startTick = clampInt(slice.startTick :: number, 0, ProfileSchema.MAX_COUNTER),
					everyTicks = clampInt(slice.everyTicks :: number, 0, ProfileSchema.MAX_COUNTER),
					count = clampInt(slice.count :: number, 0, ProfileSchema.MAX_COUNTER),
					unit = slice.unit :: string,
				}
				if isFiniteInteger(slice.laneMask) then
					item.laneMask = clampInt(slice.laneMask :: number, 0, ProfileSchema.MAX_COUNTER)
				end
				if type(slice.isElite) == "boolean" then
					item.isElite = slice.isElite
				end
				if type(slice.isChampion) == "boolean" then
					item.isChampion = slice.isChampion
				end
				table.insert(cleanSlices, item)
			end
		end
		out.slices = cleanSlices
	end
	return out
end

local function sanitizeCurrent(data: any): Profile
	local profile = newProfile()
	if type(data) ~= "table" then
		return profile
	end

	sanitizeCommonScalars(profile, data)

	local equipped = data.equipped
	if type(equipped) == "table" then
		for _, field in ipairs(EQUIPPED_FIELDS) do
			if isIdString(equipped[field], ProfileSchema.MAX_ID_LENGTH) then
				(profile.equipped :: any)[field] = equipped[field] :: string
			end
		end
	end

	local rawCampaign = data.campaign
	if type(rawCampaign) == "table" then
		if ProfileSchema.isValidStageId(rawCampaign.highestUnlockedStage) then
			profile.campaign.highestUnlockedStage = rawCampaign.highestUnlockedStage :: string
		end
		if type(rawCampaign.nightmareUnlocked) == "boolean" then
			profile.campaign.nightmareUnlocked = rawCampaign.nightmareUnlocked
		end
		profile.campaign.starsNormal = sanitizeStarsMap(rawCampaign.starsNormal)
		profile.campaign.starsNightmare = sanitizeStarsMap(rawCampaign.starsNightmare)
		local rawClaims = rawCampaign.actMilestoneClaims
		if type(rawClaims) == "table" then
			for act = 1, ProfileSchema.CAMPAIGN_ACTS do
				local strKey = tostring(act)
				local val = rawClaims[strKey]
				if val == nil then
					val = rawClaims[act]
				end
				if isFiniteInteger(val) then
					profile.campaign.actMilestoneClaims[strKey] =
						clampInt(val :: number, 0, ProfileSchema.MAX_STAR_MASK)
				end
			end
		end
	end

	local rawHorde = data.horde
	if type(rawHorde) == "table" then
		if type(rawHorde.starterChosen) == "boolean" then
			profile.horde.starterChosen = rawHorde.starterChosen
		end
		if type(rawHorde.faction) == "string" and HORDE_FACTIONS[rawHorde.faction] == true then
			profile.horde.faction = rawHorde.faction
		end
		if type(rawHorde.unlockedCards) == "table" then
			local cardKeys: { string } = {}
			for key in pairs(rawHorde.unlockedCards) do
				if type(key) == "string" then
					table.insert(cardKeys, key :: string)
				end
			end
			table.sort(cardKeys)
			local nextUnlocked: { [string]: boolean } = {}
			local copiedCards = 0
			for _, cardId in ipairs(cardKeys) do
				if copiedCards >= ProfileSchema.MAX_HORDE_CARDS then
					break
				end
				if
					isIdString(cardId, ProfileSchema.MAX_ID_LENGTH)
					and type(rawHorde.unlockedCards[cardId]) == "boolean"
				then
					nextUnlocked[cardId] = rawHorde.unlockedCards[cardId] :: boolean
					copiedCards += 1
				end
			end
			profile.horde.unlockedCards = nextUnlocked
		end
		if isFiniteInteger(rawHorde.shards) then
			profile.horde.shards = clampInt(rawHorde.shards :: number, 0, ProfileSchema.MAX_COUNTER)
		end
		if type(rawHorde.bossCores) == "table" then
			for _, coreKey in ipairs(BOSS_CORE_FIELDS) do
				if type(rawHorde.bossCores[coreKey]) == "boolean" then
					(profile.horde.bossCores :: any)[coreKey] =
						rawHorde.bossCores[coreKey] :: boolean
				end
			end
		end
		if isFiniteInteger(rawHorde.dailyPlunderDayId) then
			profile.horde.dailyPlunderDayId =
				clampInt(rawHorde.dailyPlunderDayId :: number, 0, ProfileSchema.MAX_COUNTER)
		end
		if isFiniteInteger(rawHorde.dailyPlunderCount) then
			profile.horde.dailyPlunderCount =
				clampInt(rawHorde.dailyPlunderCount :: number, 0, ProfileSchema.MAX_COUNTER)
		end
		if type(rawHorde.squads) == "table" then
			local sanitizedSquads: { DeckSquad } = {}
			for _, sq in ipairs(rawHorde.squads) do
				if #sanitizedSquads >= ProfileSchema.MAX_DECK_SQUADS then
					break
				end
				if
					type(sq) == "table"
					and isIdString(sq.cardId, ProfileSchema.MAX_ID_LENGTH)
					and isFiniteInteger(sq.count)
					and type(sq.laneMode) == "string"
					and LANE_MODES[sq.laneMode] == true
				then
					table.insert(sanitizedSquads, {
						cardId = sq.cardId :: string,
						count = clampInt(sq.count :: number, 0, ProfileSchema.MAX_SQUAD_UNITS),
						laneMode = sq.laneMode :: string,
					})
				end
			end
			profile.horde.squads = sanitizedSquads
		end
		if
			rawHorde.championCardId ~= nil
			and isIdString(rawHorde.championCardId, ProfileSchema.MAX_ID_LENGTH)
		then
			profile.horde.championCardId = rawHorde.championCardId :: string
		end
		if
			type(rawHorde.championLaneMode) == "string"
			and LANE_MODES[rawHorde.championLaneMode] == true
		then
			profile.horde.championLaneMode = rawHorde.championLaneMode :: string
		end
	end

	local wall = data.wall
	if type(wall) == "table" then
		if isFiniteInteger(wall.level) then
			profile.wall.level = clampInt(wall.level :: number, 1, ProfileSchema.MAX_WALL_LEVEL)
		end
		if isFiniteInteger(wall.gridWidth) then
			profile.wall.gridWidth = clampInt(
				wall.gridWidth :: number,
				ProfileSchema.GRID_WIDTH,
				ProfileSchema.MAX_GRID_WIDTH
			)
		end
		if isFiniteInteger(wall.activeTrapLimit) then
			profile.wall.activeTrapLimit = clampInt(
				wall.activeTrapLimit :: number,
				ProfileSchema.MIN_ACTIVE_TRAP_LIMIT,
				ProfileSchema.MAX_ACTIVE_TRAP_LIMIT
			)
		end
		local cells = wall.cells
		if type(cells) == "table" then
			-- ordem deterministica: o resultado da migracao nao pode depender da hash
			local keys: { string } = {}
			for key in pairs(cells) do
				if type(key) == "string" then
					table.insert(keys, key :: string)
				end
			end
			table.sort(keys)
			local copiedCells = 0
			local placed: { { x: number, y: number } } = {}
			for _, key in ipairs(keys) do
				if copiedCells >= profile.wall.activeTrapLimit then
					break
				end
				local cell = sanitizeCell(key, cells[key])
				if cell ~= nil then
					local overlaps = false
					for _, other in ipairs(placed) do
						if ProfileSchema.tooClose(cell.x, cell.y, other.x, other.y) then
							overlaps = true
							break
						end
					end
					if not overlaps then
						profile.wall.cells[key] = cell
						placed[#placed + 1] = { x = cell.x, y = cell.y }
						copiedCells += 1
					end
				end
			end
		end
	end

	if isFiniteInteger(data.contentVersion) then
		profile.contentVersion =
			clampInt(data.contentVersion :: number, 1, ProfileSchema.MAX_COUNTER)
	end

	local rawFtue = data.ftue
	if type(rawFtue) == "table" then
		if isFiniteInteger(rawFtue.step) then
			profile.ftue.step = clampInt(rawFtue.step :: number, 0, ProfileSchema.MAX_FTUE_STEP)
		end
		if type(rawFtue.skipped) == "boolean" then
			profile.ftue.skipped = rawFtue.skipped
		end
		if isFiniteInteger(rawFtue.completedAt) then
			profile.ftue.completedAt =
				clampInt(rawFtue.completedAt :: number, 0, ProfileSchema.MAX_COUNTER)
		end
	end

	local rawCd = data.revengeCooldowns
	if type(rawCd) == "table" then
		local keys: { string } = {}
		for key in pairs(rawCd) do
			if type(key) == "string" then
				table.insert(keys, key :: string)
			end
		end
		table.sort(keys)
		local copiedCd = 0
		for _, rivalHash in ipairs(keys) do
			if copiedCd >= ProfileSchema.MAX_REVENGE_COOLDOWNS then
				break
			end
			if
				isIdString(rivalHash, ProfileSchema.MAX_ID_LENGTH)
				and not ProfileSchema.PII_KEYS[string.lower(rivalHash)]
				and isFiniteInteger(rawCd[rivalHash])
			then
				profile.revengeCooldowns[rivalHash] =
					clampInt(rawCd[rivalHash] :: number, 0, ProfileSchema.MAX_COUNTER)
				copiedCd += 1
			end
		end
	end

	local rawHistory = data.battleHistory
	if type(rawHistory) == "table" then
		local cleanHistory: { BattleHistoryEntry } = {}
		for _, item in ipairs(rawHistory) do
			if #cleanHistory >= ProfileSchema.MAX_BATTLE_HISTORY then
				break
			end
			if
				type(item) == "table"
				and isBattleId(item.battleId)
				and type(item.role) == "string"
				and HISTORY_ROLES[item.role] == true
				and type(item.winner) == "string"
				and HISTORY_WINNERS[item.winner] == true
				and isIdString(item.rivalHash, ProfileSchema.MAX_ID_LENGTH)
				and isSafeLabel(item.rivalLabel)
				and isFiniteInteger(item.leagueDelta)
				and isFiniteInteger(item.goldDelta)
				and isFiniteInteger(item.createdAt)
				and isFiniteInteger(item.resultHash)
				and isFiniteInteger(item.seed)
				and type(item.isBot) == "boolean"
				and type(item.revenged) == "boolean"
			then
				local entry: BattleHistoryEntry = {
					battleId = item.battleId :: string,
					role = item.role :: string,
					winner = item.winner :: string,
					rivalHash = item.rivalHash :: string,
					rivalLabel = item.rivalLabel :: string,
					leagueDelta = clampInt(item.leagueDelta :: number, -1000, 1000),
					goldDelta = clampInt(
						item.goldDelta :: number,
						-ProfileSchema.MAX_GOLD,
						ProfileSchema.MAX_GOLD
					),
					createdAt = clampInt(item.createdAt :: number, 0, ProfileSchema.MAX_COUNTER),
					resultHash = clampInt(item.resultHash :: number, 0, ProfileSchema.MAX_COUNTER),
					seed = clampInt(item.seed :: number, 0, ProfileSchema.MAX_COUNTER),
					isBot = item.isBot :: boolean,
					revenged = item.revenged :: boolean,
				}
				if item.rivalWall ~= nil then
					entry.rivalWall = sanitizeHistoryWall(item.rivalWall)
				end
				if item.waveSpec ~= nil then
					entry.waveSpec = sanitizeWaveSpec(item.waveSpec)
				end
				table.insert(cleanHistory, entry)
			end
		end
		profile.battleHistory = cleanHistory
	end

	profile.schemaVersion = ProfileSchema.SCHEMA_VERSION
	return profile
end

-- Forma v1 (sem contentVersion, cells rXcY) usada apenas pela migracao 0 -> 1.
local function sanitizeV1(data: any): any
	local profile: any = newProfile()
	profile.schemaVersion = 1
	profile.contentVersion = nil
	profile.equipped = nil
	profile.campaign = nil
	profile.horde = nil
	profile.ftue = nil
	profile.revengeCooldowns = nil
	profile.battleHistory = nil
	profile.wall = {
		gridWidth = ProfileSchema.GRID_WIDTH,
		activeTrapLimit = ProfileSchema.ACTIVE_TRAP_LIMIT,
		cells = {},
	}
	if type(data) ~= "table" then
		return profile
	end
	sanitizeCommonScalars(profile, data)
	local wall = data.wall
	if type(wall) == "table" then
		if isFiniteInteger(wall.gridWidth) then
			profile.wall.gridWidth = clampInt(
				wall.gridWidth :: number,
				ProfileSchema.GRID_WIDTH,
				ProfileSchema.MAX_GRID_WIDTH
			)
		end
		if isFiniteInteger(wall.activeTrapLimit) then
			profile.wall.activeTrapLimit = clampInt(wall.activeTrapLimit :: number, 1, 25)
		end
		local cells = wall.cells
		if type(cells) == "table" then
			local keys: { string } = {}
			for key in pairs(cells) do
				if type(key) == "string" then
					table.insert(keys, key :: string)
				end
			end
			table.sort(keys)
			local copied = 0
			for _, key in ipairs(keys) do
				if copied >= 25 then
					break
				end
				local rawCell = cells[key]
				if
					cellKeyOk(key, profile.wall.gridWidth)
					and type(rawCell) == "table"
					and isIdString(rawCell.trap, ProfileSchema.MAX_ID_LENGTH)
					and isFiniteInteger(rawCell.level)
				then
					profile.wall.cells[key] = {
						trap = rawCell.trap :: string,
						level = clampInt(rawCell.level :: number, 1, ProfileSchema.MAX_TRAP_LEVEL),
					}
					copied += 1
				end
			end
		end
	end
	return profile
end

-- Passos de migracao: MIGRATIONS[n] leva um perfil da versao n para n+1.
local MIGRATIONS: { [number]: (data: any) -> any } = {}

-- 0 -> 1: dados escreveram antes do schemaVersion existir. Copia so o que o v1 reconhece;
-- campos do prototipo (`coins`, `hackAttempt`, PII) ficam de fora.
MIGRATIONS[0] = function(data: any): any
	return sanitizeV1(data)
end

-- 1 -> 2: adiciona `contentVersion = 1` (conteudo legado). A migracao de conteudo real
-- (aliases/reparos) roda depois, no boot, com o catalogo injetado (TrapCatalog).
MIGRATIONS[1] = function(data: any): any
	local copy: any = {}
	if type(data) == "table" then
		for key, value in pairs(data) do
			copy[key] = value
		end
	end
	copy.schemaVersion = 2
	copy.contentVersion = 1
	return copy
end

-- 2 -> 3: P2 muralha livre (x, y), tiers de muralha (level 1..5), limite 5..7, equipped e contentVersion=3.
-- Preserva os campos existentes; mapeia rXcY -> (COLUMN_X[col], row*1000-500).
MIGRATIONS[2] = function(data: any): any
	local copy: any = {}
	if type(data) == "table" then
		for key, value in pairs(data) do
			copy[key] = value
		end
	end

	local oldWall = if type(copy.wall) == "table" then copy.wall else {}
	local newCells: { [string]: Cell } = {}
	local count = 0
	if type(oldWall.cells) == "table" then
		local keys: { string } = {}
		for key in pairs(oldWall.cells) do
			if type(key) == "string" then
				table.insert(keys, key :: string)
			end
		end
		table.sort(keys)
		for _, key in ipairs(keys) do
			local raw = oldWall.cells[key]
			if type(raw) == "table" and isIdString(raw.trap, ProfileSchema.MAX_ID_LENGTH) then
				local level = if isFiniteInteger(raw.level)
					then clampInt(raw.level :: number, 1, ProfileSchema.MAX_TRAP_LEVEL)
					else 1
				local cx, cy = ProfileSchema.cellToPos(key)
				if cx ~= nil and cy ~= nil then
					newCells[key] = { trap = raw.trap :: string, level = level, x = cx, y = cy }
					count += 1
				elseif
					ProfileSchema.isValidSlot(key)
					and ProfileSchema.validatePosition(raw.x, raw.y)
				then
					newCells[key] = {
						trap = raw.trap :: string,
						level = level,
						x = raw.x :: number,
						y = raw.y :: number,
					}
					count += 1
				end
			end
		end
	end

	local limit = clampInt(
		math.max(ProfileSchema.MIN_ACTIVE_TRAP_LIMIT, count),
		ProfileSchema.MIN_ACTIVE_TRAP_LIMIT,
		ProfileSchema.MAX_ACTIVE_TRAP_LIMIT
	)
	local gridWidth = if isFiniteInteger(oldWall.gridWidth)
		then clampInt(
			oldWall.gridWidth :: number,
			ProfileSchema.GRID_WIDTH,
			ProfileSchema.MAX_GRID_WIDTH
		)
		else ProfileSchema.GRID_WIDTH

	copy.wall = {
		level = if isFiniteInteger(oldWall.level)
			then clampInt(oldWall.level :: number, 1, ProfileSchema.MAX_WALL_LEVEL)
			else 1,
		gridWidth = gridWidth,
		activeTrapLimit = limit,
		cells = newCells,
	}
	copy.contentVersion = ProfileSchema.DEFAULT_CONTENT_VERSION
	if type(copy.equipped) ~= "table" then
		copy.equipped = newEquipped()
	end
	copy.schemaVersion = 3
	return copy
end

-- 3 -> 4: adiciona progresso de campanha ("Cronicas do Bastiao") de forma neutra e aditiva.
-- Preserva 100% wall, gold, league, cosmetics, equipped e stats sem alterar o hash da muralha.
MIGRATIONS[3] = function(data: any): any
	local copy: any = {}
	if type(data) == "table" then
		for key, value in pairs(data) do
			copy[key] = value
		end
	end
	if type(copy.campaign) ~= "table" then
		copy.campaign = newCampaign()
	end
	copy.schemaVersion = 4
	return copy
end

-- 4 -> 5: adiciona progresso de horda e deck ("5 Hordas") de forma neutra e aditiva.
-- Preserva 100% wall, gold, league, cosmetics, equipped, campaign e stats sem alterar o hash da muralha.
MIGRATIONS[4] = function(data: any): any
	local copy: any = {}
	if type(data) == "table" then
		for key, value in pairs(data) do
			copy[key] = value
		end
	end
	if type(copy.horde) ~= "table" then
		copy.horde = newHorde()
	end
	copy.schemaVersion = 5
	return copy
end

-- 5 -> 6: adiciona FTUE guiado (ftueStep 0..6), cooldown de vinganca (24h) e historico BattleLog (GAP-020).
-- Preserva 100% wall, gold, league, cosmetics, equipped, campaign, horde e stats sem alterar o hash da muralha.
MIGRATIONS[5] = function(data: any): any
	local copy: any = {}
	if type(data) == "table" then
		for key, value in pairs(data) do
			copy[key] = value
		end
	end
	if type(copy.ftue) ~= "table" then
		local stats = if type(copy.stats) == "table" then copy.stats else {}
		local raids = if isFiniteInteger(stats.raids) then stats.raids :: number else 0
		local wins = if isFiniteInteger(stats.wins) then stats.wins :: number else 0
		local defenses = if isFiniteInteger(stats.defenses) then stats.defenses :: number else 0
		local inferredStep = if raids > 0 or wins > 0
			then ProfileSchema.MAX_FTUE_STEP
			elseif defenses > 0 then 1
			else 0
		copy.ftue = {
			step = inferredStep,
			skipped = false,
			completedAt = 0,
		}
	end
	if type(copy.revengeCooldowns) ~= "table" then
		copy.revengeCooldowns = {}
	end
	if type(copy.battleHistory) ~= "table" then
		copy.battleHistory = {}
	end
	copy.schemaVersion = 6
	return copy
end

-- Migra e devolve um perfil v6 valido. Versao futura (build mais novo) e recusada: nao
-- sobrescrever dado que este servidor nao entende. Nunca muta a tabela recebida.
function ProfileSchema.migrate(data: any, fromVersion: number?): (Profile?, string?)
	local version: number
	if fromVersion ~= nil then
		version = fromVersion
	elseif type(data) == "table" and type(data.schemaVersion) == "number" then
		version = data.schemaVersion :: number
	else
		version = 0
	end
	if not isFiniteInteger(version) then
		return nil, "schemaVersion nao e inteiro"
	end
	if version < 0 then
		return nil, "schemaVersion negativo"
	end
	if version > ProfileSchema.SCHEMA_VERSION then
		return nil, "schema_future"
	end
	local current: any = data
	local step = version
	while step < ProfileSchema.SCHEMA_VERSION do
		local migration = MIGRATIONS[step]
		if migration == nil then
			return nil, "sem migracao a partir de " .. tostring(step)
		end
		current = migration(current)
		step += 1
	end
	local profile = sanitizeCurrent(current)
	local ok, err = ProfileSchema.validate(profile)
	if not ok then
		return nil, err
	end
	return profile, nil
end

-- ---------------------------------------------------------------- JSON e chaves
-- ProfileStore so aceita JSONAcceptable: string/number/boolean/buffer e tabelas com chaves
-- homogeneas. DataStore serializa numero e string, nunca Instance/Vector3/CFrame/funcao.
function ProfileSchema.isJsonSafe(value: any): (boolean, string?)
	local seen: { [any]: boolean } = {}

	local function walk(item: any, path: string, depth: number): (boolean, string?)
		local kind = type(item)
		if kind == "nil" then
			return false, path .. ": nil nao e serializavel"
		end
		if kind == "boolean" or kind == "string" then
			return true, nil
		end
		if kind == "number" then
			local n = item :: number
			if n ~= n then
				return false, path .. ": NaN"
			end
			if n == math.huge or n == -math.huge then
				return false, path .. ": infinito"
			end
			return true, nil
		end
		if kind ~= "table" then
			return false, path .. ": tipo nao serializavel (" .. kind .. ")"
		end
		if depth > 8 then
			return false, path .. ": profundidade acima de 8"
		end
		if seen[item] then
			return false, path .. ": referencia repetida ou ciclo"
		end
		seen[item] = true
		local hasString, hasNumber, count = false, false, 0
		for key in pairs(item) do
			count += 1
			local keyKind = type(key)
			if keyKind == "string" then
				hasString = true
			elseif keyKind == "number" then
				hasNumber = true
			else
				return false, path .. ": chave " .. keyKind .. " nao serializavel"
			end
		end
		if hasString and hasNumber then
			return false, path .. ": chave mista (string + numero)"
		end
		if hasNumber then
			for index = 1, count do
				if item[index] == nil then
					return false, path .. ": array com buraco"
				end
			end
			for key in pairs(item) do
				local index = key :: number
				if index % 1 ~= 0 or index < 1 or index > count then
					return false, path .. ": indice de array invalido"
				end
			end
		end
		for key, child in pairs(item) do
			local okChild, errChild = walk(child, path .. "." .. tostring(key), depth + 1)
			if not okChild then
				return false, errChild
			end
		end
		return true, nil
	end

	return walk(value, "perfil", 0)
end

-- Chave do DataStore: 1 key por jogador, padrao estatico, nunca display name.
function ProfileSchema.keyFor(userId: number): string
	return string.format("User_%d", math.floor(userId))
end

-- Dias UTC entre dois carimbos do servidor. nil = nunca visto antes (primeira sessao).
function ProfileSchema.daysBetween(nowTs: number, thenTs: number): number?
	if thenTs <= 0 or nowTs < 0 then
		return nil
	end
	local delta = nowTs - thenTs
	if delta <= 0 then
		return 0
	end
	return math.floor(delta / ProfileSchema.SECONDS_PER_DAY)
end

return ProfileSchema
