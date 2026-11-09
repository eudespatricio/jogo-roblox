--!nonstrict
-- Nucleo deterministico da Muralha (v2).
-- Regras: zero float no estado, mul32/add32 em toda operacao 32-bit, 1200 ticks = 60s.
-- Sem dependencia de API do Roblox: roda no Luau CLI e no servidor.

local bit32 = bit32

local Core = {}

Core.MILLI = 1000
Core.TICK_HZ = 20
Core.MAX_TICKS = 1200
Core.DEFAULT_POWER_PCT = 460

-- ---------------------------------------------------------------- aritmetica segura
local function add32(a, b)
	local s = a + b
	if s >= 4294967296 then
		s -= 4294967296
	end
	return s
end

local function mul32(a, b)
	a = bit32.band(a, 0xFFFFFFFF)
	b = bit32.band(b, 0xFFFFFFFF)
	local a0 = bit32.band(a, 0xFFFF)
	local a1 = bit32.rshift(a, 16)
	local b0 = bit32.band(b, 0xFFFF)
	local b1 = bit32.rshift(b, 16)
	-- 65536 * 2^16 = 2^32: so os 16 bits baixos do termo cruzado importam
	local mid = bit32.band(a0 * b1 + a1 * b0, 0xFFFF)
	return add32(a0 * b0, mid * 65536)
end

Core.add32 = add32
Core.mul32 = mul32

-- ---------------------------------------------------------------- RNG uint32
local RNG = {}
RNG.__index = RNG

function RNG.new(seed)
	local s0 = add32(bit32.band(seed, 0xFFFFFFFF), 1)
	local s1 = mul32(bit32.band(seed, 0xFFFFFFFF), 2654435761)
	if s0 == 0 and s1 == 0 then
		s1 = 0x9E3779B9
	end
	return setmetatable({ s0 = s0, s1 = s1 }, RNG)
end

function RNG:nextU32()
	local x, y = self.s0, self.s1
	self.s0 = y
	x = bit32.bxor(x, bit32.lshift(x, 23))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, y)
	x = bit32.bxor(x, bit32.rshift(y, 26))
	self.s1 = x
	return add32(self.s0, x)
end

function RNG:int(n)
	return (self:nextU32() % n) + 1
end

Core.RNG = RNG

-- ---------------------------------------------------------------- tipos
local MILLI = Core.MILLI

local UNIT = {
	runner = { hp = 14 * MILLI, speed = 150, leak = 8 * MILLI },
	brute = { hp = 45 * MILLI, speed = 75, leak = 25 * MILLI },
	swarm = { hp = 7 * MILLI, speed = 210, leak = 3 * MILLI },
}
local UNIT_NAMES = { "runner", "brute", "swarm" }

local TRAP = {
	archer = { dmg = 4 * MILLI, cd = 10, range = 3000 },
	cannon = { dmg = 10 * MILLI, cd = 28, range = 2200 },
	frost = { dmg = 2 * MILLI, cd = 14, range = 2600, slowPct = 55, slowTicks = 20 },
	oil = { dmg = 6 * MILLI, cd = 18, range = 1600 },
}
local TRAP_NAMES = { "archer", "cannon", "frost", "oil" }

Core.UNIT = UNIT
Core.TRAP = TRAP

local TUNING = { powerPct = Core.DEFAULT_POWER_PCT, leakScalePct = 100 }
Core.TUNING = TUNING

-- ---------------------------------------------------------------- batalha
local Battle = {}
Battle.__index = Battle

function Battle.new(spec)
	local self = setmetatable({}, Battle)
	self.rng = RNG.new(spec.seed)
	self.seed = spec.seed
	self.wallHp = (spec.wallHp or 500) * MILLI
	self.wallMax = self.wallHp
	self.tick = 0
	self.spawnEvery = spec.spawnEveryTicks or 14
	self.spawnTimer = 0
	self.toSpawn = spec.waveCount or 70
	self.spawned = 0
	self.killed = 0
	self.leaked = 0
	self.hash = 2166136261

	self.uCount = 0
	self.uHp = {}
	self.uX = {}
	self.uLane = {}
	self.uBaseSpeed = {}
	self.uSlowUntil = {}
	self.uLeak = {}

	self.traps = {}
	for lane = 1, 5 do
		self.traps[lane] = { type = TRAP_NAMES[self.rng:int(#TRAP_NAMES)], cd = 0, x = 4000 }
	end

	return self
end

function Battle:spawnUnit()
	local lane = self.rng:int(5)
	local tname = UNIT_NAMES[self.rng:int(#UNIT_NAMES)]
	local variancePct = 90 + self.rng:int(21)
	local def = UNIT[tname]
	self.uCount += 1
	local i = self.uCount
	self.uHp[i] = math.floor(def.hp * variancePct / 100)
	self.uX[i] = 10000
	self.uLane[i] = lane
	self.uBaseSpeed[i] = def.speed
	self.uSlowUntil[i] = 0
	self.uLeak[i] = def.leak
end

function Battle:applyTrap(lane)
	local trap = self.traps[lane]
	local def = TRAP[trap.type]
	local best, bestX = nil, math.huge
	for i = 1, self.uCount do
		if self.uHp[i] > 0 and self.uLane[i] == lane then
			local dx = self.uX[i] - trap.x
			if dx > 0 and dx <= def.range and self.uX[i] < bestX then
				best, bestX = i, self.uX[i]
			end
		end
	end
	if not best then
		return
	end
	self.uHp[best] -= math.floor(def.dmg * TUNING.powerPct / 100)
	if def.slowPct then
		self.uSlowUntil[best] = self.tick + def.slowTicks
	end
	if self.uHp[best] <= 0 then
		self.uHp[best] = 0
		self.killed += 1
	end
end

function Battle:Step()
	self.tick += 1

	if self.spawned < self.toSpawn then
		self.spawnTimer += 1
		if self.spawnTimer >= self.spawnEvery then
			self.spawnTimer = 0
			self:spawnUnit()
			self.spawned += 1
		end
	end

	for lane = 1, 5 do
		local trap = self.traps[lane]
		trap.cd -= 1
		if trap.cd <= 0 then
			trap.cd = TRAP[trap.type].cd
			self:applyTrap(lane)
		end
	end

	for i = 1, self.uCount do
		if self.uHp[i] > 0 then
			local speed = self.uBaseSpeed[i]
			if self.tick <= self.uSlowUntil[i] then
				speed = math.floor(speed * 55 / 100)
			end
			self.uX[i] -= speed
			if self.uX[i] <= 0 then
				self.uHp[i] = 0
				self.leaked += 1
				self.wallHp -= math.floor(self.uLeak[i] * TUNING.leakScalePct / 100)
			end
		end
	end

	local acc = bit32.band(math.floor(self.wallHp / MILLI), 0xFFFFFFFF)
	acc = bit32.bxor(acc, bit32.band(self.uCount, 0xFFFF))
	acc = bit32.bxor(acc, bit32.band(self.killed, 0xFFFF))
	acc = bit32.bxor(acc, bit32.band(self.leaked, 0xFFFF))
	self.hash = mul32(bit32.bxor(self.hash, acc), 16777619)
end

function Battle:Finished()
	return self.wallHp <= 0 or self.tick >= Core.MAX_TICKS
end

function Battle:Result()
	return {
		winner = self.wallHp > 0 and "defender" or "attacker",
		wallHp = math.floor(math.max(0, self.wallHp) / MILLI),
		wallPct = math.max(0, self.wallHp) / self.wallMax,
		ticks = self.tick,
		killed = self.killed,
		leaked = self.leaked,
		spawned = self.spawned,
		hash = self.hash,
	}
end

function Battle:Run()
	while not self:Finished() do
		self:Step()
	end
	return self:Result()
end

function Battle:CheckIntegers()
	for i = 1, self.uCount do
		for _, v in ipairs({ self.uHp[i], self.uX[i], self.uBaseSpeed[i], self.uSlowUntil[i] }) do
			if v ~= math.floor(v) then
				return false, i
			end
		end
	end
	for lane = 1, 5 do
		if self.traps[lane].cd ~= math.floor(self.traps[lane].cd) then
			return false, -lane
		end
	end
	return true, 0
end

Core.Battle = Battle

function Core.Run(seed, waveCount, wallHp)
	local b = Battle.new({ seed = seed, waveCount = waveCount or 70, wallHp = wallHp or 500 })
	return b:Run()
end

return Core
