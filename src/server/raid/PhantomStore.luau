--!nonstrict
-- Fantasma real (S6.1): snapshot da ultima muralha publicada, em store separado.
-- Nao e a parede padrao do motor: hp/traps vem de um perfil real via toBattleWall.
-- Em producao e DataStore; no Studio e memoria (PhantomStoreMock, default true).

local PhantomStore = {}

PhantomStore.STORE_NAME = "MuralhaPhantom_v1"
PhantomStore.KEY = "latest"

local function isInteger(value: any): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value % 1 == 0
end

local function validate(snapshot: any): (boolean, string?)
	if type(snapshot) ~= "table" then
		return false, "snapshot invalido"
	end
	if not isInteger(snapshot.ownerId) or snapshot.ownerId <= 0 then
		return false, "ownerId invalido"
	end
	if
		type(snapshot.ownerName) ~= "string"
		or #snapshot.ownerName == 0
		or #snapshot.ownerName > 64
	then
		return false, "ownerName invalido"
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
	if count ~= #snapshot.traps or count > 5 then
		return false, "traps invalido"
	end
	for index, trap in ipairs(snapshot.traps) do
		if type(trap) ~= "table" or type(trap.cell) ~= "string" or type(trap.type) ~= "string" then
			return false, "trap invalido " .. index
		end
		if not isInteger(trap.level) or trap.level < 1 or trap.level > 5 then
			return false, "trap level invalido " .. index
		end
	end
	return true, nil
end

function PhantomStore.new(options: any): any
	assert(type(options) == "table", "PhantomStore.new: options ausente")
	local mock = options.mock == true
	local store = options.store
	assert(mock or store ~= nil, "PhantomStore.new: store ausente fora do Mock")
	local memory: any? = nil

	local function get(): (any?, string?)
		if mock then
			return memory, nil
		end
		local ok, value = pcall(store.GetAsync, store, PhantomStore.KEY)
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
		return value, nil
	end

	local function put(snapshot: any): (boolean, string?)
		local valid, err = validate(snapshot)
		if not valid then
			return false, err
		end
		if mock then
			memory = snapshot
			return true, nil
		end
		local ok, result = pcall(store.UpdateAsync, store, PhantomStore.KEY, function()
			return snapshot
		end)
		if not ok then
			return false, "datastore: " .. tostring(result)
		end
		return true, nil
	end

	return {
		get = get,
		put = put,
		isMock = mock,
		validate = validate,
	}
end

return PhantomStore
