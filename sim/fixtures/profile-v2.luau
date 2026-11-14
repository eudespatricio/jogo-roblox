--!nonstrict
-- Fixture de perfil schema v2 / content v2 (P1 congelado, 13/11/2026):
-- cells sem x/y explicito, sem wall.level e sem equipped.
-- Serve para provar que a migracao v2 -> v3 preserva parede, ouro, liga, cosmeticos e stats.
return {
	schemaVersion = 2,
	contentVersion = 2,
	gold = 260,
	wall = {
		gridWidth = 5,
		activeTrapLimit = 5,
		cells = {
			r1c1 = { trap = "tar", level = 2 },
			r3c3 = { trap = "archer", level = 1 },
		},
	},
	league = { points = 134, season = 1 },
	cosmetics = { banner_default = true },
	stats = {
		raids = 5,
		defenses = 2,
		wins = 4,
		sessions = 3,
		playSeconds = 360,
		firstSeenAt = 1762799000,
		lastSeenAt = 1762850000,
	},
}
