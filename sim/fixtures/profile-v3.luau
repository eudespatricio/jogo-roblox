--!nonstrict
-- Fixture de perfil schema v3 / content v3 (P2 congelado, 13/11/2026):
-- muralha livre (x, y), wall.level e equipped, mas SEM o campo `campaign`.
-- Serve para provar que a migracao v3 -> v4 preserva parede, ouro, liga, cosmeticos, equipped e stats.
return {
	schemaVersion = 3,
	contentVersion = 3,
	gold = 340,
	wall = {
		level = 2,
		gridWidth = 5,
		activeTrapLimit = 5,
		cells = {
			r1c1 = { trap = "tar", level = 2, x = 2000, y = 500 },
			r3c3 = { trap = "archer", level = 1, x = 5000, y = 2500 },
		},
	},
	league = { points = 134, season = 1 },
	cosmetics = { banner_default = true },
	equipped = {
		theme = "theme_default",
		hordeSkin = "horde_default",
		finisher = "finisher_default",
		commander = "cmd_vorn",
	},
	stats = {
		raids = 8,
		defenses = 3,
		wins = 6,
		sessions = 4,
		playSeconds = 540,
		firstSeenAt = 1762799000,
		lastSeenAt = 1762860000,
	},
}
