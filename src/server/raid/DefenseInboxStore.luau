--!strict
-- Inbox assincrona de defesas sofridas (GAP-020 / MuralhaInbox_v1).
-- Puro Luau: roda em CLI (mock) e no DataStoreService do servidor. Zero PII armazenado.

local DefenseInboxStore = {}

DefenseInboxStore.STORE_NAME = "MuralhaInbox_v1"
DefenseInboxStore.MAX_INBOX = 12

export type WallTrap = {
	cell: string?,
	type: string,
	level: number,
	x: number?,
	y: number?,
}

export type WallSnapshot = {
	level: number,
	hp: number,
	traps: { WallTrap },
}

export type InboxEntry = {
	battleId: string,
	attackerHash: string,
	attackerLabel: string,
	attackerLeague: number,
	winner: string,
	goldReward: number,
	createdAt: number,
	resultHash: number,
	seed: number,
	attackerWall: WallSnapshot?,
	defenderWall: WallSnapshot?,
	waveSpec: { [string]: any }?,
}

export type StoreHandle = {
	push: (defenderHash: string, entry: any) -> (boolean, string?),
	consume: (defenderHash: string) -> ({ InboxEntry }, string?),
	peek: (defenderHash: string) -> ({ InboxEntry }, string?),
	isMock: boolean,
}

local PII_KEYS: { [string]: boolean } = {
	name = true,
	display_name = true,
	player_name = true,
	username = true,
	userid = true,
	user_id = true,
	ip = true,
	email = true,
	chat = true,
	message = true,
	token = true,
}

local function isFiniteInt(value: any): boolean
	if type(value) ~= "number" then
		return false
	end
	local n = value :: number
	return n == n and n ~= math.huge and n ~= -math.huge and n % 1 == 0
end

local function isIdString(value: any, maxLen: number): boolean
	if type(value) ~= "string" then
		return false
	end
	local s = value :: string
	return #s > 0 and #s <= maxLen and string.match(s, "^[%w_%.%-]+$") ~= nil
end

local function isBattleId(value: any): boolean
	if type(value) ~= "string" then
		return false
	end
	local s = value :: string
	return #s > 0 and #s <= 64 and string.match(s, "^[%w_%.%-:]+$") ~= nil
end

local function isSafeLabel(value: any): boolean
	if type(value) ~= "string" then
		return false
	end
	local s = value :: string
	return #s > 0 and #s <= 32 and string.find(s, "[%c]") == nil
end

local function hasPiiKey(tbl: any, depth: number): boolean
	if type(tbl) ~= "table" or depth > 6 then
		return false
	end
	for key, child in pairs(tbl) do
		if type(key) == "string" and PII_KEYS[string.lower(key :: string)] then
			return true
		end
		if type(child) == "table" and hasPiiKey(child, depth + 1) then
			return true
		end
	end
	return false
end

local function sanitizeWall(rawWall: any): WallSnapshot?
	if type(rawWall) ~= "table" then
		return nil
	end
	if not isFiniteInt(rawWall.hp) or (rawWall.hp :: number) <= 0 then
		return nil
	end
	if type(rawWall.traps) ~= "table" then
		return nil
	end
	local traps: { WallTrap } = {}
	for _, trap in ipairs(rawWall.traps) do
		if #traps >= 7 then
			break
		end
		if
			type(trap) == "table"
			and isIdString(trap.type, 48)
			and isFiniteInt(trap.level)
			and (trap.level :: number) >= 1
			and (trap.level :: number) <= 5
		then
			local entry: WallTrap = {
				type = trap.type :: string,
				level = trap.level :: number,
			}
			if type(trap.cell) == "string" and #trap.cell <= 16 then
				entry.cell = trap.cell :: string
			end
			if isFiniteInt(trap.x) and isFiniteInt(trap.y) then
				entry.x = trap.x :: number
				entry.y = trap.y :: number
			end
			traps[#traps + 1] = entry
		end
	end
	local level = if isFiniteInt(rawWall.level)
		then math.clamp(rawWall.level :: number, 1, 5)
		else 1
	return {
		level = level,
		hp = math.floor(rawWall.hp :: number),
		traps = traps,
	}
end

local function cloneJsonSafeTable(raw: any, depth: number): any
	if depth > 6 then
		return nil
	end
	local kind = type(raw)
	if kind == "boolean" or kind == "string" then
		return raw
	end
	if kind == "number" then
		local n = raw :: number
		if n == n and n ~= math.huge and n ~= -math.huge then
			return n
		end
		return nil
	end
	if kind ~= "table" then
		return nil
	end
	local out: { [any]: any } = {}
	for k, v in pairs(raw) do
		if type(k) == "string" then
			if not PII_KEYS[string.lower(k :: string)] then
				local cloned = cloneJsonSafeTable(v, depth + 1)
				if cloned ~= nil then
					out[k] = cloned
				end
			end
		elseif isFiniteInt(k) then
			local cloned = cloneJsonSafeTable(v, depth + 1)
			if cloned ~= nil then
				out[k] = cloned
			end
		end
	end
	return out
end

function DefenseInboxStore.keyFor(defenderHash: any): (string?, string?)
	if not isIdString(defenderHash, 48) then
		return nil, "defenderHash invalido"
	end
	local hash = defenderHash :: string
	if hash == "bot" or PII_KEYS[string.lower(hash)] then
		return nil, "defenderHash proibido"
	end
	return "Inbox_" .. hash, nil
end

function DefenseInboxStore.sanitizeEntry(raw: any): (InboxEntry?, string?)
	if type(raw) ~= "table" then
		return nil, "entry nao e tabela"
	end
	if hasPiiKey(raw, 0) then
		return nil, "PII proibido na inbox"
	end
	if not isBattleId(raw.battleId) then
		return nil, "battleId invalido"
	end
	if
		not isIdString(raw.attackerHash, 48)
		or raw.attackerHash == "bot"
		or PII_KEYS[string.lower(raw.attackerHash :: string)]
	then
		return nil, "attackerHash invalido"
	end
	if not isSafeLabel(raw.attackerLabel) then
		return nil, "attackerLabel invalido"
	end
	if not isFiniteInt(raw.attackerLeague) then
		return nil, "attackerLeague invalido"
	end
	if raw.winner ~= "attacker" and raw.winner ~= "defender" then
		return nil, "winner invalido"
	end
	for _, field in ipairs({ "goldReward", "createdAt", "resultHash", "seed" }) do
		if not isFiniteInt(raw[field]) or (raw[field] :: number) < 0 then
			return nil, field .. " invalido"
		end
	end
	local entry: InboxEntry = {
		battleId = raw.battleId :: string,
		attackerHash = raw.attackerHash :: string,
		attackerLabel = raw.attackerLabel :: string,
		attackerLeague = math.clamp(raw.attackerLeague :: number, 1, 7),
		winner = raw.winner :: string,
		goldReward = math.floor(raw.goldReward :: number),
		createdAt = math.floor(raw.createdAt :: number),
		resultHash = math.floor(raw.resultHash :: number),
		seed = math.floor(raw.seed :: number),
	}
	if raw.attackerWall ~= nil then
		entry.attackerWall = sanitizeWall(raw.attackerWall)
	end
	if raw.defenderWall ~= nil then
		entry.defenderWall = sanitizeWall(raw.defenderWall)
	end
	if type(raw.waveSpec) == "table" then
		entry.waveSpec = cloneJsonSafeTable(raw.waveSpec, 0)
	end
	return entry, nil
end

local function sanitizeList(rawList: any): { InboxEntry }
	local out: { InboxEntry } = {}
	if type(rawList) ~= "table" then
		return out
	end
	for _, raw in ipairs(rawList) do
		if #out >= DefenseInboxStore.MAX_INBOX then
			break
		end
		local entry = DefenseInboxStore.sanitizeEntry(raw)
		if entry ~= nil then
			out[#out + 1] = entry
		end
	end
	return out
end

function DefenseInboxStore.new(options: any): StoreHandle
	assert(type(options) == "table", "DefenseInboxStore.new: options ausente")
	local mock = options.mock == true
	local store = options.store
	assert(mock or store ~= nil, "DefenseInboxStore.new: store ausente fora do Mock")

	local memory: { [string]: { InboxEntry } } = {}

	local function push(defenderHash: string, rawEntry: any): (boolean, string?)
		local key, keyErr = DefenseInboxStore.keyFor(defenderHash)
		if key == nil then
			return false, keyErr
		end
		local entry, entryErr = DefenseInboxStore.sanitizeEntry(rawEntry)
		if entry == nil then
			return false, entryErr
		end
		if entry.attackerHash == defenderHash then
			return false, "auto_ataque"
		end
		if mock then
			local nextList: { InboxEntry } = { entry }
			local cur = memory[key]
			if cur ~= nil then
				for _, existing in ipairs(cur) do
					if #nextList >= DefenseInboxStore.MAX_INBOX then
						break
					end
					if existing.battleId ~= entry.battleId then
						nextList[#nextList + 1] = existing
					end
				end
			end
			memory[key] = nextList
			return true, nil
		end
		local ok, err = pcall(store.UpdateAsync, store, key, function(existing: any): any
			local nextList: { InboxEntry } = { entry }
			for _, item in ipairs(sanitizeList(existing)) do
				if #nextList >= DefenseInboxStore.MAX_INBOX then
					break
				end
				if item.battleId ~= entry.battleId then
					nextList[#nextList + 1] = item
				end
			end
			return nextList
		end)
		if not ok then
			return false, "datastore: " .. tostring(err)
		end
		return true, nil
	end

	local function consume(defenderHash: string): ({ InboxEntry }, string?)
		local key, keyErr = DefenseInboxStore.keyFor(defenderHash)
		if key == nil then
			return {}, keyErr
		end
		if mock then
			local list = memory[key] or {}
			memory[key] = {}
			return list, nil
		end
		local drained: { InboxEntry } = {}
		local ok, err = pcall(store.UpdateAsync, store, key, function(existing: any): any
			drained = sanitizeList(existing)
			if #drained == 0 then
				return nil
			end
			return {}
		end)
		if not ok then
			return {}, "datastore: " .. tostring(err)
		end
		return drained, nil
	end

	local function peek(defenderHash: string): ({ InboxEntry }, string?)
		local key, keyErr = DefenseInboxStore.keyFor(defenderHash)
		if key == nil then
			return {}, keyErr
		end
		if mock then
			return memory[key] or {}, nil
		end
		local ok, value = pcall(store.GetAsync, store, key)
		if not ok then
			return {}, "datastore: " .. tostring(value)
		end
		return sanitizeList(value), nil
	end

	return {
		push = push,
		consume = consume,
		peek = peek,
		isMock = mock,
	}
end

return DefenseInboxStore
