--!nonstrict
-- Fixture de perfil pre-schema (v0): escrito antes de existir `schemaVersion`.
-- Carrega de proposito campos que o schema v1 NAO conhece (coins do prototipo, lixo e PII)
-- para provar que a migracao 0 -> 1 so deixa passar o que o schema reconhece.
return {
	gold = 120,
	wall = {
		gridWidth = 5,
		activeTrapLimit = 5,
		cells = { r1c1 = { trap = "cannon", level = 2 } },
		legacyNote = "nao deveria persistir",
	},
	league = { points = 34, season = 1 },
	stats = { raids = 3, defenses = 1, lastSeenAt = 1762800000 },
	cosmetics = { banner_default = true },
	coins = 500,
	hackAttempt = true,
	player_name = "Fulano de Tal",
}
