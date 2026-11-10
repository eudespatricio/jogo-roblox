--!nonstrict
-- Store separado do BattleLog (S6): DataStore real em produção ou memoria no Studio.
-- Uma chave por battle_id; put e UpdateAsync idempotente (se ja existe, devolve o existente).
-- Nao e o store do perfil: o BattleLog tem seu proprio nome/versao e nunca entra no ProfileStore.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BattleLog =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("raid"):WaitForChild("BattleLog"))

local BattleLogStore = {}

BattleLogStore.STORE_NAME = BattleLog.STORE_NAME

function BattleLogStore.new(options: any): any
	assert(type(options) == "table", "BattleLogStore.new: options ausente")
	local mock = options.mock == true
	local store = options.store
	assert(mock or store ~= nil, "BattleLogStore.new: store ausente fora do Mock")

	local memory: { [string]: any } = {}

	local function get(battleId: any): (any?, string?)
		local key, keyErr = BattleLog.keyFor(battleId)
		if key == nil then
			return nil, keyErr
		end
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
		local valid, validateErr = BattleLog.validate(value)
		if not valid then
			return nil, "registro invalido: " .. tostring(validateErr)
		end
		return value, nil
	end

	local function put(record: any): (any?, boolean, string?)
		local key, keyErr = BattleLog.keyFor(record and record.battleId)
		if key == nil then
			return nil, false, keyErr
		end
		local valid, validateErr = BattleLog.validate(record)
		if not valid then
			return nil, false, validateErr
		end
		if mock then
			local existing = memory[key]
			if existing ~= nil then
				return existing, false, nil
			end
			memory[key] = record
			return record, true, nil
		end
		local created = false
		local ok, value = pcall(store.UpdateAsync, store, key, function(existing: any)
			if existing ~= nil then
				return existing
			end
			created = true
			return record
		end)
		if not ok then
			return nil, false, "datastore: " .. tostring(value)
		end
		return value, created, nil
	end

	local function markRewarded(battleId: any, rewardGold: any): (any?, string?)
		local key, keyErr = BattleLog.keyFor(battleId)
		if key == nil then
			return nil, keyErr
		end
		local function apply(existing: any): (any?, string?)
			if existing == nil then
				return nil, "battle_log ausente"
			end
			if existing.rewarded == true then
				return existing, nil
			end
			return BattleLog.markRewarded(existing, rewardGold)
		end
		if mock then
			local updated, err = apply(memory[key])
			if updated ~= nil then
				memory[key] = updated
			end
			return updated, err
		end
		local updated: any = nil
		local updatedErr: string? = nil
		local ok, value = pcall(store.UpdateAsync, store, key, function(existing: any)
			local result, err = apply(existing)
			if result == nil then
				updatedErr = err
				return nil
			end
			updated = result
			return result
		end)
		if not ok then
			return nil, "datastore: " .. tostring(value)
		end
		if updatedErr ~= nil then
			return nil, updatedErr
		end
		return updated, nil
	end

	return {
		get = get,
		put = put,
		markRewarded = markRewarded,
		isMock = mock,
	}
end

return BattleLogStore
