--!nonstrict
-- Fixture de perfil schema v1 (09/11/2026): ainda nao tem `contentVersion` e usa `oil`.
-- Serve para provar que a migracao 1 -> 2 preserva a parede e o ouro; a troca de conteudo
-- (oil -> tar) e testada em sim/content-contract.luau.
return {
	schemaVersion = 1,
	gold = 120,
	wall = {
		gridWidth = 5,
		activeTrapLimit = 5,
		cells = { r1c1 = { trap = "oil", level = 2 } },
	},
	league = { points = 34, season = 1 },
	cosmetics = { banner_default = true },
	stats = {
		raids = 3,
		defenses = 1,
		wins = 1,
		sessions = 2,
		playSeconds = 120,
		firstSeenAt = 1762799000,
		lastSeenAt = 1762800000,
	},
}
