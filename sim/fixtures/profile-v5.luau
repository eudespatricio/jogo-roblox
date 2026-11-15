--!nonstrict
-- Fixture de perfil schema v5 / content v3 (Playtest v1.4, 14/11/2026):
-- possui `horde` completo, mas SEM `ftue`, `revengeCooldowns` e `battleHistory`.
-- Serve para provar que a migracao v5 -> v6 preserva parede, ouro, liga, cosmeticos,
-- equipped, campanha, horde e stats sem alterar o hash da muralha.
return {
	schemaVersion = 5,
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
	horde = {
		starterChosen = true,
		faction = "iron",
		unlockedCards = {
			squad_runner_pack = true,
			squad_brute_guards = true,
			squad_iron_vanguard = true,
		},
		shards = 5,
		bossCores = {
			act1 = false,
			act2 = false,
			act3 = false,
			act4 = false,
			act5 = false,
		},
		dailyPlunderDayId = 0,
		dailyPlunderCount = 0,
		squads = {
			{ cardId = "squad_iron_vanguard", count = 2, laneMode = "center" },
			{ cardId = "squad_runner_pack", count = 2, laneMode = "flanks" },
			{ cardId = "squad_brute_guards", count = 2, laneMode = "split" },
		},
		championCardId = nil,
		championLaneMode = "center",
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
