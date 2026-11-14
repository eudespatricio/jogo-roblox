--!strict
-- Fantasma real shardado por liga (AUD-01 / AUD-06): 8 slots por liga L1..L5, zero PII.
-- Nao guarda ownerId nem ownerName; usa ownerHash (8 hex com salt) e chaves L<1..5>_S<1..8>.
-- Em producao usa DataStore; no Studio ou CLI usa memoria (mock = true).

local bit32 = bit32

local PhantomStore = {}

PhantomStore.STORE_NAME = "MuralhaPhantom_v1"
PhantomStore.SLOTS_PER_LEAGUE = 8
PhantomStore.MIN_LEAGUE = 1
PhantomStore.MAX_LEAGUE = 5

local HASH_SALT = 0xA5A55A5A
local UINT32_MOD = 4294967296

export type BattleTrap = {
	cell: string?,
	type: string,
	level: number,
	x: number?,
	y: number?,
}

export type Snapshot = {
	ownerHash: string,
	league: number,
	level: number?,
	hp: number,
	traps: { BattleTrap },
	contentVersion: number,
	updatedAt: number,
}

export type StoreHandle = {
	put: (snapshot: any, slot: number?) -> (boolean, string?),
	getForLeague: (league: number, excludeHash: string?, seed: number?) -> (Snapshot?, string?),
	isMock: boolean,
	validate: (snapshot: any) -> (boolean, string?),
}

local function isInteger(value: any): boolean
	if type(value) ~= "number" then
		return false
	end
	local numberValue = value :: number
	return numberValue == numberValue
		and numberValue ~= math.huge
		and numberValue ~= -math.huge
		and numberValue % 1 == 0
end

local function isHex8(value: any): boolean
	if type(value) ~= "string" then
		return false
	end
	local text = value :: string
	return #text == 8 and string.match(text, "^[0-9a-f]+$") ~= nil
end

function PhantomStore.hashOwner(userId: number): string
	local numeric = if type(userId) == "number" and userId == userId
		then math.floor(math.abs(userId))
		else 0
	local low = numeric % UINT32_MOD
	local high = math.floor(numeric / UINT32_MOD) % UINT32_MOD
	local mixed = bit32.bxor(low, high)
	return string.format("%08x", bit32.bxor(mixed, HASH_SALT))
end

function PhantomStore.slotKey(league: number, slot: number): string
	local clampedLeague =
		math.clamp(math.floor(league), PhantomStore.MIN_LEAGUE, PhantomStore.MAX_LEAGUE)
	local normalizedSlot = ((math.floor(slot) - 1) % PhantomStore.SLOTS_PER_LEAGUE) + 1
	return string.format("L%d_S%d", clampedLeague, normalizedSlot)
end

local function isValidArenaPos(x: any, y: any): boolean
	if not isInteger(x) or not isInteger(y) then
		return false
	end
	local nx = x :: number
	local ny = y :: number
	return nx >= 1000
		and nx <= 9000
		and ny >= 500
		and ny <= 4500
		and nx % 250 == 0
		and ny % 250 == 0
end

local function validate(snapshot: any): (boolean, string?)
	if type(snapshot) ~= "table" then
		return false, "snapshot invalido"
	end
	if snapshot.ownerId ~= nil or snapshot.ownerName ~= nil then
		return false, "pii proibido"
	end
	if not isHex8(snapshot.ownerHash) then
		return false, "ownerHash invalido"
	end
	if
		not isInteger(snapshot.league)
		or snapshot.league < PhantomStore.MIN_LEAGUE
		or snapshot.league > PhantomStore.MAX_LEAGUE
	then
		return false, "league invalida"
	end
	if
		snapshot.level ~= nil
		and (not isInteger(snapshot.level) or snapshot.level < 1 or snapshot.level > 5)
	then
		return false, "level invalido"
	end
	if not isInteger(snapshot.hp) or snapshot.hp <= 0 then
		return false, "hp invalido"
	end
	if not isInteger(snapshot.contentVersion) or snapshot.contentVersion < 1 then
		return false, "contentVersion invalido"
	end
	if not isInteger(snapshot.updatedAt) or snapshot.updatedAt < 0 then
		return false, "updatedAt invalido"
	end
	if type(snapshot.traps) ~= "table" then
		return false, "traps invalido"
	end
	local count = 0
	for _ in pairs(snapshot.traps) do
		count += 1
	end
	if count ~= #snapshot.traps or count > 7 then
		return false, "traps invalido"
	end
	for index, trap in ipairs(snapshot.traps) do
		if type(trap) ~= "table" or type(trap.type) ~= "string" then
			return false, "trap invalido " .. tostring(index)
		end
		local hasPos = trap.x ~= nil or trap.y ~= nil
		if hasPos then
			if not isValidArenaPos(trap.x, trap.y) then
				return false, "trap posicao invalida " .. tostring(index)
			end
			if trap.cell ~= nil and type(trap.cell) ~= "string" then
				return false, "trap invalido " .. tostring(index)
			end
		elseif type(trap.cell) ~= "string" then
			return false, "trap invalido " .. tostring(index)
		end
		if not isInteger(trap.level) or trap.level < 1 or trap.level > 5 then
			return false, "trap level invalido " .. tostring(index)
		end
	end
	return true, nil
end

PhantomStore.validate = validate

function PhantomStore.new(options: any): StoreHandle
	assert(type(options) == "table", "PhantomStore.new: options ausente")
	local mock = options.mock == true
	local store = options.store
	assert(mock or store ~= nil, "PhantomStore.new: store ausente fora do Mock")
	local memory: { [string]: Snapshot } = {}

	local function readSlot(key: string): (Snapshot?, string?)
		if mock then
			return memory[key], nil
		end
		local ok, value = pcall(store.GetAsync, store, key)
		if not ok then
			return nil, "datastore: " .. tostring(value)
		end
		if value == nil then
			return nil, nil
		end
		local valid, err = validate(value)
		if not valid then
			return nil, "snapshot invalido: " .. tostring(err)
		end
		return value :: Snapshot, nil
	end

	local function put(snapshot: any, slot: number?): (boolean, string?)
		local valid, err = validate(snapshot)
		if not valid then
			return false, err
		end
		local snap = snapshot :: Snapshot
		local resolvedSlot = slot
		if resolvedSlot == nil then
			local hashNumber = tonumber(snap.ownerHash, 16) or 0
			resolvedSlot = (hashNumber % PhantomStore.SLOTS_PER_LEAGUE) + 1
		end
		local key = PhantomStore.slotKey(snap.league, resolvedSlot :: number)
		if mock then
			memory[key] = snap
			return true, nil
		end
		local ok, result = pcall(store.UpdateAsync, store, key, function()
			return snap
		end)
		if not ok then
			return false, "datastore: " .. tostring(result)
		end
		return true, nil
	end

	local function getForLeague(
		league: number,
		excludeHash: string?,
		seed: number?
	): (Snapshot?, string?)
		local clampedLeague =
			math.clamp(math.floor(league), PhantomStore.MIN_LEAGUE, PhantomStore.MAX_LEAGUE)
		local base = if type(seed) == "number"
			then math.floor(math.abs(seed))
			else math.random(0, 2147483647)
		local slot1 = (base % PhantomStore.SLOTS_PER_LEAGUE) + 1
		local step = (
			math.floor(base / PhantomStore.SLOTS_PER_LEAGUE)
			% (PhantomStore.SLOTS_PER_LEAGUE - 1)
		) + 1
		local slot2 = ((slot1 - 1 + step) % PhantomStore.SLOTS_PER_LEAGUE) + 1

		local lastErr: string? = nil
		for _, slot in ipairs({ slot1, slot2 }) do
			local key = PhantomStore.slotKey(clampedLeague, slot)
			local value, err = readSlot(key)
			if err ~= nil then
				lastErr = err
			elseif value ~= nil then
				if excludeHash == nil or value.ownerHash ~= excludeHash then
					return value, nil
				end
			end
		end
		return nil, lastErr
	end

	return {
		put = put,
		getForLeague = getForLeague,
		isMock = mock,
		validate = validate,
	}
end

return PhantomStore
