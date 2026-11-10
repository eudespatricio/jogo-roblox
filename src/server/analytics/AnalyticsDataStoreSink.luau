--!strict
-- Sink persistente do AnalyticsService (GAP-012). O servico da S7 entrega lotes validados;
-- aqui cada lote vira uma chave de DataStore. Puro Luau com store injetado: o boot escolhe
-- DataStore em producao e Memory no Studio, e o contrato roda no CLI.
--
-- Chave: `A_<event_id do primeiro evento do lote>` (idempotente em retry do mesmo lote).
-- Valor: { version = 1, writtenAt = ms, events = { ... } }.
-- Uma chave por lote; 100 eventos/lote no maximo (o servico ja limita). Nao e o store do perfil:
-- analytics tem store proprio e nunca entra no ProfileStore.

local AnalyticsDataStoreSink = {}

AnalyticsDataStoreSink.STORE_NAME = "MuralhaAnalytics_v1"
AnalyticsDataStoreSink.KEY_PREFIX = "A"
AnalyticsDataStoreSink.MAX_KEY_LENGTH = 50
AnalyticsDataStoreSink.VALUE_VERSION = 1
AnalyticsDataStoreSink.DEFAULT_MAX_EVENTS = 100

export type Store = {
	SetAsync: (self: any, key: string, value: any) -> (),
	GetAsync: (self: any, key: string) -> any,
	RemoveAsync: ((self: any, key: string) -> any)?,
	ListKeysAsync: ((self: any, prefix: string?, pageSize: number?) -> any)?,
}

export type Options = {
	types: any,
	store: Store?,
	mock: boolean?,
	now: () -> number,
	keyPrefix: string?,
	maxEventsPerKey: number?,
}

export type Record = {
	version: number,
	writtenAt: number,
	events: { any },
}

export type Sink = {
	name: string,
	write: (events: { any }) -> (boolean, string?),
	get: (key: string) -> (any?, string?),
	keyFor: (events: { any }) -> (string?, string?),
	count: () -> number,
	isMock: boolean,
	keys: () -> { string },
}

local function copyList(events: { any }): { any }
	local copy = {}
	for index, event in ipairs(events) do
		copy[index] = event
	end
	return copy
end

function AnalyticsDataStoreSink.new(options: Options): Sink
	assert(type(options) == "table", "AnalyticsDataStoreSink.new: options ausente")
	assert(options.types ~= nil, "AnalyticsDataStoreSink.new: types ausente")
	assert(type(options.now) == "function", "AnalyticsDataStoreSink.new: now ausente")

	local types = options.types
	local mock = options.mock == true
	local store = options.store
	local now = options.now
	local keyPrefix = options.keyPrefix or AnalyticsDataStoreSink.KEY_PREFIX
	local maxEvents = options.maxEventsPerKey or AnalyticsDataStoreSink.DEFAULT_MAX_EVENTS
	if maxEvents < 1 then
		maxEvents = AnalyticsDataStoreSink.DEFAULT_MAX_EVENTS
	end
	assert(mock or store ~= nil, "AnalyticsDataStoreSink.new: store ausente fora do Mock")

	local memory: { [string]: any } = {}
	local memoryOrder: { string } = {}
	local writes = 0

	local function keyFor(events: { any }): (string?, string?)
		if type(events) ~= "table" or #events == 0 then
			return nil, "lote vazio"
		end
		local first = events[1]
		if type(first) ~= "table" or type(first.event_id) ~= "string" then
			return nil, "primeiro evento sem event_id"
		end
		local key = keyPrefix .. "_" .. string.lower(first.event_id)
		if #key > AnalyticsDataStoreSink.MAX_KEY_LENGTH then
			return nil, "chave acima de " .. tostring(AnalyticsDataStoreSink.MAX_KEY_LENGTH)
		end
		return key, nil
	end

	local function writeChunk(chunk: { any }): (boolean, string?)
		local key, keyErr = keyFor(chunk)
		if key == nil then
			return false, keyErr
		end
		local record: Record = {
			version = AnalyticsDataStoreSink.VALUE_VERSION,
			writtenAt = now(),
			events = copyList(chunk),
		}
		if mock then
			if memory[key] == nil then
				memoryOrder[#memoryOrder + 1] = key
			end
			memory[key] = record
			writes += 1
			return true, nil
		end
		local storeAt = store :: Store
		local ok, err = pcall(function()
			storeAt.SetAsync(storeAt, key, record)
			return nil
		end)
		if not ok then
			return false, "datastore: " .. tostring(err)
		end
		writes += 1
		return true, nil
	end

	local function write(events: { any }): (boolean, string?)
		if type(events) ~= "table" then
			return false, "lote nao e tabela"
		end
		if #events == 0 then
			return true, nil
		end
		local valid, index, err = types.validateAll(events)
		if not valid then
			return false, "lote invalido em " .. tostring(index) .. ": " .. tostring(err)
		end
		local offset = 1
		while offset <= #events do
			local chunk = {}
			local last = math.min(offset + maxEvents - 1, #events)
			for indexEvent = offset, last do
				chunk[#chunk + 1] = events[indexEvent]
			end
			local ok, writeErr = writeChunk(chunk)
			if not ok then
				return false, writeErr
			end
			offset = last + 1
		end
		return true, nil
	end

	local function get(key: string): (any?, string?)
		if type(key) ~= "string" or #key == 0 then
			return nil, "chave invalida"
		end
		if mock then
			local record = memory[key]
			if record == nil then
				return nil, nil
			end
			return record, nil
		end
		local storeAt = store :: Store
		local ok, value = pcall(storeAt.GetAsync, storeAt, key)
		if not ok then
			return nil, "datastore: " .. tostring(value)
		end
		return value, nil
	end

	local function keys(): { string }
		local output = {}
		if mock then
			for _, key in ipairs(memoryOrder) do
				output[#output + 1] = key
			end
		end
		return output
	end

	return {
		name = mock and "Memory" or "DataStore",
		write = write,
		get = get,
		keyFor = keyFor,
		count = function(): number
			if mock then
				return #memoryOrder
			end
			return writes
		end,
		isMock = mock,
		keys = keys,
	}
end

return AnalyticsDataStoreSink
