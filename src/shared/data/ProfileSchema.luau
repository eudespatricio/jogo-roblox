--!strict
-- Schema v1 do perfil da MURALHA: template, validacao, sanitizacao e migracao.
-- Puro Luau (nenhuma API do Roblox): roda no CLI em sim/profile-contract.luau e no servidor.
-- Regras: campo novo entra em newProfile E em sanitizeV1; campo desconhecido nunca e salvo
-- (a whitelist roda em todo load); a chave do perfil e UserId, nunca nome; nada de PII no Data.

local ProfileSchema = {}

ProfileSchema.SCHEMA_VERSION = 1
ProfileSchema.STORE_NAME = "MuralhaProfile_v1"
ProfileSchema.SECONDS_PER_DAY = 86400

-- Grade do MVP (Q2, 09/11/2026): 5x5, N=5 ativas, colocacao livre. 7 colunas e expansao por
-- nivel, entao e dado do perfil, nao codigo.
ProfileSchema.GRID_WIDTH = 5
ProfileSchema.MAX_GRID_WIDTH = 7
ProfileSchema.GRID_HEIGHT = 5
ProfileSchema.ACTIVE_TRAP_LIMIT = 5
ProfileSchema.MAX_ACTIVE_TRAP_LIMIT = 25
ProfileSchema.MAX_TRAP_LEVEL = 5
ProfileSchema.MAX_CELLS = ProfileSchema.MAX_ACTIVE_TRAP_LIMIT
ProfileSchema.MAX_COSMETICS = 200
ProfileSchema.MAX_GOLD = 1000000000
ProfileSchema.MAX_COUNTER = 9007199254740991
ProfileSchema.MAX_ID_LENGTH = 48

export type Cell = { trap: string, level: number }

export type Wall = {
	gridWidth: number,
	activeTrapLimit: number,
	cells: { [string]: Cell },
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

export type Profile = {
	schemaVersion: number,
	wall: Wall,
	gold: number,
	league: League,
	cosmetics: { [string]: boolean },
	stats: Stats,
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

local TOP_FIELDS = { "schemaVersion", "wall", "gold", "league", "cosmetics", "stats" }
local WALL_FIELDS = { "gridWidth", "activeTrapLimit", "cells" }
local CELL_FIELDS = { "trap", "level" }
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
local LEAGUE_SET = fieldSet(LEAGUE_FIELDS)
local STATS_SET = fieldSet(STATS_FIELDS)

local function newProfile(): Profile
	return {
		schemaVersion = ProfileSchema.SCHEMA_VERSION,
		wall = {
			gridWidth = ProfileSchema.GRID_WIDTH,
			activeTrapLimit = ProfileSchema.ACTIVE_TRAP_LIMIT,
			cells = {},
		},
		gold = 0,
		league = { points = 0, season = 1 },
		cosmetics = {},
		stats = {
			raids = 0,
			defenses = 0,
			wins = 0,
			sessions = 0,
			playSeconds = 0,
			firstSeenAt = 0,
			lastSeenAt = 0,
		},
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

local function cellKeyOk(key: any, gridWidth: number): boolean
	if type(key) ~= "string" then
		return false
	end
	local rowText, colText = string.match(key :: string, "^r(%d+)c(%d+)$")
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
	return true
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
	if limit < 1 or limit > ProfileSchema.MAX_ACTIVE_TRAP_LIMIT then
		return false, "wall.activeTrapLimit fora de [1,25]"
	end
	if type(wall.cells) ~= "table" then
		return false, "wall.cells ausente"
	end
	local count = 0
	for key, cell in pairs(wall.cells) do
		count += 1
		if count > ProfileSchema.MAX_CELLS then
			return false, "wall.cells acima de " .. tostring(ProfileSchema.MAX_CELLS)
		end
		if not cellKeyOk(key, gridWidth) then
			return false, "wall.cells: chave invalida (" .. tostring(key) .. ")"
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

-- Valida o perfil inteiro contra o schema v1. Retorna (ok, erro) em vez de lancar: o chamador
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
	local okStats, errStats = validateStats(data.stats)
	if not okStats then
		return false, errStats
	end
	return true, nil
end

-- ---------------------------------------------------------------- saneamento e migracao
local function sanitizeCell(key: string, cell: any, gridWidth: number): Cell?
	if not cellKeyOk(key, gridWidth) or type(cell) ~= "table" then
		return nil
	end
	if not isIdString(cell.trap, ProfileSchema.MAX_ID_LENGTH) then
		return nil
	end
	if not isFiniteInteger(cell.level) then
		return nil
	end
	local level = clampInt(cell.level :: number, 1, ProfileSchema.MAX_TRAP_LEVEL)
	return { trap = cell.trap :: string, level = level }
end

-- Reconstroi um perfil v1 valido a partir de qualquer tabela: so entra o que o schema
-- reconhece e cabe na faixa. E o que roda em todo load, entao lixo/PII nunca e persistido.
local function sanitizeV1(data: any): Profile
	local profile = newProfile()
	if type(data) ~= "table" then
		return profile
	end

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
			profile.wall.activeTrapLimit =
				clampInt(wall.activeTrapLimit :: number, 1, ProfileSchema.MAX_ACTIVE_TRAP_LIMIT)
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
			for _, key in ipairs(keys) do
				if copiedCells >= ProfileSchema.MAX_CELLS then
					break
				end
				local cell = sanitizeCell(key, cells[key], profile.wall.gridWidth)
				if cell ~= nil then
					profile.wall.cells[key] = cell
					copiedCells += 1
				end
			end
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

	profile.schemaVersion = ProfileSchema.SCHEMA_VERSION
	return profile
end

-- Passos de migracao: MIGRATIONS[n] leva um perfil da versao n para n+1.
local MIGRATIONS: { [number]: (data: any) -> any } = {}

-- 0 -> 1: dados escreveram antes do schemaVersion existir. Copia so o que o v1 reconhece;
-- campos do prototipo (`coins`, `hackAttempt`, PII) ficam de fora. Grade do MVP e do template.
MIGRATIONS[0] = function(data: any): any
	return sanitizeV1(data)
end

-- Migra e devolve um perfil v1 valido. Versao futura (build mais novo) e recusada: nao
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
	local profile = sanitizeV1(current)
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
