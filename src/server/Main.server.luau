--!strict
-- Ponto de entrada do servidor: liga persistencia, leaderstats e moedas.
local Players = game:GetService("Players")

local DataService = require(script.Parent:WaitForChild("DataService"))
local CoinService = require(script.Parent:WaitForChild("CoinService"))

local function setupPlayer(player: Player)
	local data = DataService:Load(player)

	if player.Parent ~= Players then
		return
	end

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = data.coins
	coins.Parent = leaderstats

	leaderstats.Parent = player
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(setupPlayer, player)
end)

Players.PlayerRemoving:Connect(function(player)
	DataService:Save(player)
end)

-- fecha o servidor sem perder progresso (publicacao / shutdown)
game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		task.spawn(DataService.Save, DataService, player)
	end
	task.wait(2)
end)

-- jogadores que ja estavam no servidor (Play Solo no Studio)
for _, player in Players:GetPlayers() do
	task.spawn(setupPlayer, player)
end

CoinService:Start()
