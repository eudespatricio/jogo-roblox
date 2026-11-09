--!nonstrict
-- Prova de conceito do motor determinístico da Muralha.
-- Luau puro: roda no CLI, sem Roblox. Objetivo: provar determinismo, custo e balanceamento.
local bit32 = bit32

-- ---------------------------------------------------------------- RNG
local RNG = {}
RNG.__index = RNG

function RNG.new(seed)
	local s0 = bit32.band(seed, 0xFFFFFFFF)
	local s1 = bit32.band(seed * 2654435761, 0xFFFFFFFF)
	if s0 == 0 and s1 == 0 then
		s1 = 0x9E3779B9
	end
	return setmetatable({ s0 = s0, s1 = s1 }, RNG)
end

function RNG:next()
	local x, y = self.s0, self.s1
	self.s0 = y
	x = bit32.bxor(x, bit32.lshift(x, 23))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, y)
	x = bit32.bxor(x, bit32.rshift(y, 26))
	self.s1 = x
	return bit32.band(self.s0 + x, 0xFFFFFFFF) / 4294967296
end

function RNG:int(n)
	return math.floor(self:next() * n) + 1
end

-- ---------------------------------------------------------------- tipos
local UNIT = {
	runner = { hp = 14, speed = 3.0, leak = 8, dps = 0 },
	brute = { hp = 45, speed = 1.5, leak = 25, dps = 0 },
	swarm = { hp = 7, speed = 4.2, leak = 3, dps = 0 },
}
local UNIT_NAMES = { "runner", "brute", "swarm" }

local TRAP = {
	archer = { dmg = 4, cd = 0.50, range = 3.0 },
	cannon = { dmg = 10, cd = 1.40, range = 2.2 },
	frost = { dmg = 2, cd = 0.70, range = 2.6, slow = 0.45 },
	oil = { dmg = 6, cd = 0.90, range = 1.6 },
}
local TRAP_NAMES = { "archer", "cannon", "frost", "oil" }

local DT = 0.05
local MAX_TICKS = 1800

-- botoes de calibragem (usados na varredura de balanco)
local TUNING = { trapPower = 3.8, leakScale = 1.0 }

-- ---------------------------------------------------------------- batalha
local Battle = {}
Battle.__index = Battle

function Battle.new(spec)
	local self = setmetatable({}, Battle)
	self.rng = RNG.new(spec.seed)
	self.seed = spec.seed
	self.wallHp = spec.wallHp or 500
	self.wallMax = self.wallHp
	self.tick = 0
	self.time = 0
	self.spawnTimer = 0
	self.spawnEvery = spec.spawnEvery or 0.7
	self.toSpawn = spec.waveCount or 70
	self.spawned = 0
	self.killed = 0
	self.leaked = 0
	self.hash = 2166136261

	-- SoA
	self.uCount = 0
	self.uType = {}
	self.uHp = {}
	self.uX = {}
	self.uLane = {}
	self.uSpeed = {}

	-- armadilhas: uma por lane (1..5)
	self.traps = {}
	for lane = 1, 5 do
		local t = TRAP_NAMES[self.rng:int(#TRAP_NAMES)]
		self.traps[lane] = { type = t, cd = 0, x = 4 }
	end

	return self
end

function Battle:spawnUnit()
	local lane = self.rng:int(5)
	local tname = UNIT_NAMES[self.rng:int(#UNIT_NAMES)]
	-- variacao leve por seed (mantem determinismo)
	local variance = 0.9 + self.rng:next() * 0.2
	local def = UNIT[tname]
	self.uCount += 1
	local i = self.uCount
	self.uType[i] = tname
	self.uHp[i] = def.hp * variance
	self.uX[i] = 10
	self.uLane[i] = lane
	self.uSpeed[i] = def.speed
end

function Battle:applyTrap(lane)
	local trap = self.traps[lane]
	local def = TRAP[trap.type]
	local trapX = trap.x
	local best, bestX = nil, math.huge
	for i = 1, self.uCount do
		if self.uHp[i] > 0 and self.uLane[i] == lane then
			local dx = self.uX[i] - trapX
			if dx > 0 and dx <= def.range and self.uX[i] < bestX then
				best, bestX = i, self.uX[i]
			end
		end
	end
	if not best then
		return
	end
	self.uHp[best] -= def.dmg * TUNING.trapPower
	if def.slow then
		self.uSpeed[best] *= (1 - def.slow)
	end
	if self.uHp[best] <= 0 then
		self.uHp[best] = 0
		self.killed += 1
	end
end

function Battle:Step()
	self.tick += 1
	self.time += DT

	-- spawn
	self.spawnTimer -= DT
	if self.spawnTimer <= 0 and self.spawned < self.toSpawn then
		self:spawnUnit()
		self.spawned += 1
		self.spawnTimer = self.spawnEvery
	end

	-- armadilhas
	for lane = 1, 5 do
		local trap = self.traps[lane]
		trap.cd -= DT
		if trap.cd <= 0 then
			trap.cd = TRAP[trap.type].cd
			self:applyTrap(lane)
		end
	end

	-- movimento e vazamento
	for i = 1, self.uCount do
		if self.uHp[i] > 0 then
			self.uX[i] -= self.uSpeed[i] * DT
			if self.uX[i] <= 0 then
				self.uHp[i] = 0
				self.leaked += 1
				self.wallHp -= UNIT[self.uType[i]].leak * TUNING.leakScale
			end
		end
	end

	-- hash FNV-1a do estado (prova de determinismo)
	local acc = bit32.band(math.floor(self.wallHp * 10), 0xFFFFFFFF)
	acc = bit32.bxor(acc, bit32.band(self.uCount, 0xFFFF))
	acc = bit32.bxor(acc, bit32.band(self.killed, 0xFFFF))
	acc = bit32.bxor(acc, bit32.band(self.leaked, 0xFFFF))
	self.hash = bit32.band(bit32.bxor(self.hash, acc) * 16777619, 0xFFFFFFFF)
end

function Battle:Finished()
	return self.wallHp <= 0 or self.time >= 60
end

function Battle:Result()
	return {
		winner = self.wallHp > 0 and "defender" or "attacker",
		wallHp = math.max(0, math.floor(self.wallHp)),
		wallPct = math.max(0, self.wallHp / self.wallMax),
		ticks = self.tick,
		killed = self.killed,
		leaked = self.leaked,
		spawned = self.spawned,
		hash = self.hash,
	}
end

function Battle:Run()
	while not self:Finished() and self.tick < MAX_TICKS do
		self:Step()
	end
	return self:Result()
end

-- ---------------------------------------------------------------- testes
local function run(seed, waveCount, wallHp)
	local b = Battle.new({ seed = seed, waveCount = waveCount or 70, wallHp = wallHp or 500 })
	return b:Run()
end

print("=== 1. DETERMINISMO ===")
local hashes = {}
for i = 1, 3 do
	local r = run(42)
	hashes[i] = r.hash
	print(string.format("  run %d: hash=%d winner=%s wall=%d leaked=%d ticks=%d",
		i, r.hash, r.winner, r.wallHp, r.leaked, r.ticks))
end
local deterministic = hashes[1] == hashes[2] and hashes[2] == hashes[3]
print("  -> " .. (deterministic and "OK: hash identico" or "FALHOU: divergiu"))

print("\n=== 2. VARIACAO POR SEED ===")
local seen = {}
local wins, total, leakedSum = 0, 0, 0
for seed = 1, 500 do
	local r = run(seed)
	seen[r.hash] = true
	total += 1
	leakedSum += r.leaked
	if r.winner == "defender" then
		wins += 1
	end
end
local distinct = 0
for _ in pairs(seen) do
	distinct += 1
end
print(string.format("  seeds=500 distintas=%d vitorias_defensor=%.1f%% vazados_medio=%.1f",
	distinct, wins / total * 100, leakedSum / total))

print("\n=== 3. PERFORMANCE (1000 batalhas) ===")
local t0 = os.clock()
for seed = 1, 1000 do
	run(seed)
end
local elapsed = os.clock() - t0
print(string.format("  tempo total=%.3fs  por batalha=%.3fms  batalhas/s=%.0f",
	elapsed, elapsed / 1000 * 1000, 1000 / elapsed))

print("\n=== 4. SENSIBILIDADE DE BALANCO ===")
for _, waveCount in ipairs({ 50, 70, 90 }) do
	local w, spawned = 0, 0
	for seed = 1, 200 do
		local r = run(seed, waveCount)
		spawned += r.spawned
		if r.winner == "defender" then
			w += 1
		end
	end
	print(string.format("  wave=%d  vitorias_defensor=%.0f%%  spawnados_medio=%.1f",
		waveCount, w / 200 * 100, spawned / 200))
end

print("\n=== 5. FUZZ (500 seeds, wave aleatoria) ===")
local ok = true
local rng = RNG.new(999)
for _ = 1, 500 do
	local wave = 30 + rng:int(60)
	local r = run(rng:int(1000000), wave, 400 + rng:int(200))
	if r.wallHp ~= r.wallHp or r.ticks <= 0 then
		ok = false
	end
end
print("  -> " .. (ok and "OK: nenhum NaN/loop" or "FALHOU"))

print("\n=== 6. VARREDURA DE CALIBRAGEM (vitoria do defensor %) ===")
local waves = { 60, 75, 90 }
local powers = { 1.0, 2.2, 3.0, 3.8, 4.4 }
local header = string.format("  %-13s", "power \\ wave")
for _, w in ipairs(waves) do
	header ..= string.format("%6d", w)
end
print(header)
for _, p in ipairs(powers) do
	TUNING.trapPower = p
	TUNING.leakScale = 1.0
	local line = string.format("  %-13.1f", p)
	for _, w in ipairs(waves) do
		local wins = 0
		for seed = 1, 200 do
			if run(seed, w).winner == "defender" then
				wins += 1
			end
		end
		line ..= string.format("%5.0f%%", wins / 200 * 100)
	end
	print(line)
end
TUNING.trapPower = 3.8
TUNING.leakScale = 1.0
