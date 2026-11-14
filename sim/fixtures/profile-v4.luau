--!nonstrict
-- Fixture de perfil schema v4 / content v3 (P2 + Campanha, 14/11/2026):
-- muralha livre (x, y), wall.level, equipped e `campaign`, mas SEM o campo `horde`.
-- Serve para provar que a migracao v4 -> v5 preserva parede, ouro, liga, cosmeticos, equipped,
-- campanha e stats sem alterar o hash da muralha.
return {
	schemaVersion = 4,
	contentVersion = 3,
	gold = 420,
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
	campaign = {
		highestUnlockedStage = "2-1",
		nightmareUnlocked = false,
		starsNormal = {
			["1-1"] = 7,
			["1-2"] = 3,
		},
		starsNightmare = {},
		actMilestoneClaims = {
			["1"] = 1,
			["2"] = 0,
			["3"] = 0,
			["4"] = 0,
			["5"] = 0,
		},
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
