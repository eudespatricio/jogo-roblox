--!strict
-- Inicializa a cena 5x5 no Workspace. O WallController atualiza os marcadores a cada acao.
local BuildGrid = require(script.Parent:WaitForChild("BuildGrid"))

BuildGrid.init()
print("[build] cena 5x5 pronta")
