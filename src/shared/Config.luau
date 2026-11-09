--!strict
-- Configuracao central do jogo. Tudo que e "numero magico" deve morar aqui.
local Config = {}

Config.Coins = {
	Count = 30,
	Value = 1,
	RespawnSeconds = 8,
	AreaSize = 96, -- lado da area quadrada onde as moedas nascem
	Height = 2.2,
}

Config.Data = {
	StoreName = "PlayerData_v1",
	Version = 1,
}

Config.Hud = {
	Accent = Color3.fromRGB(255, 199, 44),
	Panel = Color3.fromRGB(18, 20, 26),
	Text = Color3.fromRGB(245, 245, 245),
}

return table.freeze(Config)
