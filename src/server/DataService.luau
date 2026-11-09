--!strict
-- Persistencia simples e segura o bastante para um primeiro jogo.
-- Para producao com muitos jogadores, troque por ProfileStore (session locking de verdade).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

export type PlayerData = {
	coins: number,
	version: number,
}

local store = DataStoreService:GetDataStore(Config.Data.StoreName)

local DataService = {}
local cache: { [Player]: PlayerData } = {}

local function dataKey(player: Player): string
	return "Player_" .. tostring(player.UserId)
end

local function defaultData(): PlayerData
	return {
		coins = 0,
		version = Config.Data.Version,
	}
end

-- tenta algumas vezes; DataStore falha de forma transitoria com frequencia
local function retry<T>(fn: () -> T, attempts: number): (boolean, T?)
	local lastError: string? = nil
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastError = tostring(result)
		task.wait(attempt * 0.5)
	end
	warn("[DataService] falhou apos " .. attempts .. " tentativas: " .. tostring(lastError))
	return false, nil
end

function DataService:Load(player: Player): PlayerData
	local ok, result = retry(function()
		return store:GetAsync(dataKey(player))
	end, 3)

	local data = defaultData()

	if ok and type(result) == "table" then
		local saved = result :: any
		if typeof(saved.coins) == "number" then
			data.coins = math.max(0, math.floor(saved.coins))
		end
	end

	cache[player] = data
	return data
end

function DataService:Get(player: Player): PlayerData?
	return cache[player]
end

function DataService:Save(player: Player)
	local data = cache[player]
	if not data then
		return
	end

	-- o valor ao vivo manda: o jogador pode ter ganhado moedas desde o load
	local leaderstats = player:FindFirstChild("leaderstats")
	local coinsValue = leaderstats and leaderstats:FindFirstChild("Coins")
	if coinsValue and coinsValue:IsA("IntValue") then
		data.coins = coinsValue.Value
	end

	retry(function()
		store:UpdateAsync(dataKey(player), function()
			return {
				coins = data.coins,
				version = Config.Data.Version,
				updatedAt = os.time(),
			}
		end)
	end, 3)

	cache[player] = nil
end

return DataService
