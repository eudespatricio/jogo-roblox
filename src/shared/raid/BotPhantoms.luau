--!strict
-- Muralhas sinteticas por liga para fallback quando PhantomStore nao tem phantom humano
-- na liga pedida (P2: niveis de muralha 1..5, ate 7 armadilhas com x/y e niveis 1..5).
-- L1 garante primeira vitoria >= 70% em <60s (1-2 armadilhas fracas Nv1).

local BotPhantoms = {}

export type BotTrap = {
	cell: string,
	type: string,
	level: number,
	x: number,
	y: number,
}

export type BotWall = {
	level: number,
	hp: number,
	traps: { BotTrap },
}

export type WaveSpec = {
	count: number,
	spawnEveryTicks: number,
}

BotPhantoms.MIN_LEAGUE = 1
BotPhantoms.MAX_LEAGUE = 5

local COLUMN_X = { 2000, 3500, 5000, 6500, 8000 }

local function cellTrap(cell: string, trapType: string, level: number): BotTrap
	local rowText, colText = string.match(cell, "^r(%d+)c(%d+)$")
	local row = tonumber(rowText) :: number
	local col = tonumber(colText) :: number
	return table.freeze({
		cell = cell,
		type = trapType,
		level = level,
		x = COLUMN_X[col],
		y = row * 1000 - 500,
	}) :: any
end

local POOLS: { [number]: { BotWall } } = {
	[1] = {
		{
			level = 1,
			hp = 500,
			traps = {
				cellTrap("r3c2", "archer", 1),
			},
		},
		{
			level = 1,
			hp = 500,
			traps = {
				cellTrap("r2c3", "archer", 1),
				cellTrap("r4c2", "archer", 1),
			},
		},
	},
	[2] = {
		{
			level = 2,
			hp = 650,
			traps = {
				cellTrap("r2c2", "archer", 1),
				cellTrap("r4c3", "tar", 1),
			},
		},
		{
			level = 2,
			hp = 650,
			traps = {
				cellTrap("r1c3", "tar", 1),
				cellTrap("r3c2", "archer", 2),
				cellTrap("r5c4", "archer", 1),
			},
		},
	},
	[3] = {
		{
			level = 3,
			hp = 800,
			traps = {
				cellTrap("r2c2", "archer", 2),
				cellTrap("r3c4", "tar", 1),
				cellTrap("r4c3", "frost", 1),
			},
		},
		{
			level = 3,
			hp = 800,
			traps = {
				cellTrap("r1c3", "tar", 2),
				cellTrap("r3c2", "archer", 2),
				cellTrap("r4c4", "frost", 1),
				cellTrap("r5c2", "archer", 1),
			},
		},
	},
	[4] = {
		{
			level = 4,
			hp = 1000,
			traps = {
				cellTrap("r2c2", "cannon", 2),
				cellTrap("r3c3", "frost", 2),
				cellTrap("r4c4", "tar", 2),
				cellTrap("r5c2", "archer", 2),
			},
		},
		{
			level = 4,
			hp = 1000,
			traps = {
				cellTrap("r1c3", "archer", 2),
				cellTrap("r2c4", "cannon", 1),
				cellTrap("r3c2", "frost", 1),
				cellTrap("r4c4", "tar", 1),
				cellTrap("r5c3", "archer", 1),
			},
		},
	},
	[5] = {
		{
			level = 5,
			hp = 1250,
			traps = {
				cellTrap("r1c3", "catapult", 2),
				cellTrap("r2c2", "cannon", 2),
				cellTrap("r3c4", "frost", 2),
				cellTrap("r4c3", "tar", 2),
				cellTrap("r5c2", "archer", 2),
			},
		},
		{
			level = 5,
			hp = 1250,
			traps = {
				cellTrap("r1c2", "cannon", 2),
				cellTrap("r2c4", "catapult", 2),
				cellTrap("r4c3", "tar", 2),
				cellTrap("r5c2", "archer", 3),
			},
		},
	},
}

BotPhantoms.POOLS = POOLS

local RAID_WAVES: { [number]: WaveSpec } = {
	[1] = { count = 70, spawnEveryTicks = 14 },
	[2] = { count = 76, spawnEveryTicks = 12 },
	[3] = { count = 94, spawnEveryTicks = 10 },
	[4] = { count = 124, spawnEveryTicks = 7 },
	[5] = { count = 140, spawnEveryTicks = 6 },
}

-- Pareamento justo por poder real da muralha (evita jogar Lv1 recem-chegado em L3..L5).
function BotPhantoms.matchLeague(
	shardLeague: number,
	myWallLevel: number,
	myTrapCount: number
): number
	local lvl = math.clamp(math.floor(myWallLevel), BotPhantoms.MIN_LEAGUE, BotPhantoms.MAX_LEAGUE)
	local traps = math.max(0, math.floor(myTrapCount))
	local maxAllowed = if traps >= 4 then math.min(BotPhantoms.MAX_LEAGUE, lvl + 1) else lvl
	return math.clamp(
		math.min(math.floor(shardLeague), maxAllowed),
		BotPhantoms.MIN_LEAGUE,
		BotPhantoms.MAX_LEAGUE
	)
end

function BotPhantoms.waveFor(
	league: number,
	isDefend: boolean?,
	trapCount: number?,
	wallLevel: number?
): WaveSpec
	if isDefend == true then
		local traps = math.max(0, math.floor(trapCount or 0))
		local lvl = math.clamp(math.floor(wallLevel or 1), 1, 5)
		if traps <= 0 then
			return { count = 56, spawnEveryTicks = 13 }
		end
		local count = math.clamp(26 + traps * 7 + (lvl - 1) * 12, 32, 120)
		local spawnEvery = math.clamp(15 - lvl - math.floor(traps / 3), 8, 14)
		return { count = count, spawnEveryTicks = spawnEvery }
	end
	local clamped = math.clamp(math.floor(league), BotPhantoms.MIN_LEAGUE, BotPhantoms.MAX_LEAGUE)
	local spec = RAID_WAVES[clamped]
	return { count = spec.count, spawnEveryTicks = spec.spawnEveryTicks }
end

local function copyWall(template: BotWall): BotWall
	local trapsCopy: { BotTrap } = {}
	for index, trap in ipairs(template.traps) do
		trapsCopy[index] = {
			cell = trap.cell,
			type = trap.type,
			level = trap.level,
			x = trap.x,
			y = trap.y,
		}
	end
	return {
		level = template.level,
		hp = template.hp,
		traps = trapsCopy,
	}
end

function BotPhantoms.pick(league: number, seed: number): BotWall
	local clampedLeague =
		math.clamp(math.floor(league), BotPhantoms.MIN_LEAGUE, BotPhantoms.MAX_LEAGUE)
	local pool = POOLS[clampedLeague]
	local numericSeed = if type(seed) == "number" and seed == seed
		then math.floor(math.abs(seed))
		else 1
	local index = (numericSeed % #pool) + 1
	return copyWall(pool[index])
end

return BotPhantoms
