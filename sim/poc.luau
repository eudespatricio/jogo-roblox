--!nonstrict
-- Muralha — motor deterministico v2 (aritmetica inteira, zero float no loop).
-- Luau puro: roda no CLI, sem Roblox. Roda no servidor x86_64 e no celular ARM64 com o mesmo hash.
--
-- Regras de ouro (v1.0 da spec):
--   1. nenhum float dentro do tick: posicao/hp/dano em milesimos, tempo em ticks
--   2. toda multiplicacao 32-bit passa por mul32 (sem estourar 53 bits)
--   3. toda soma 32-bit passa por add32 (nunca > 2^32 na entrada de bit32)
--   4. batalha = 1200 ticks (60s a 20 Hz)

local bit32 = bit32

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
	-- (a0 + a1*2^16)(b0 + b1*2^16) mod 2^32; o termo a1*b1*2^32 cai fora.
	-- mid so entra com 16 bits: 65536*2^16 = 2^32, entao os bits altos nao importam.
	local mid = bit32.band(a0 * b1 + a1 * b0, 0xFFFF)
	return add32(a0 * b0, mid * 65536) -- nenhuma etapa passa de 2^32
end

-- ---------------------------------------------------------------- RNG (uint32 puro)
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

-- ---------------------------------------------------------------- unidades (milesimos)
local MILLI = 1000
local TICK_HZ = 20
local MAX_TICKS = 1200 -- 60s

local UNIT = {
	runner = { hp = 14 * MILLI, speed = 150, leak = 8 * MILLI },  -- 3,0 studs/s / 20 = 150 mili/tick
	brute = { hp = 45 * MILLI, speed = 75, leak = 25 * MILLI },   -- 1,5 studs/s
	swarm = { hp = 7 * MILLI, speed = 210, leak = 3 * MILLI },    -- 4,2 studs/s
}
local UNIT_NAMES = { "runner", "brute", "swarm" }

-- dano/cd/alcance em unidades inteiras
local TRAP = {
	archer = { dmg = 4 * MILLI, cd = 10, range = 3000 },
	cannon = { dmg = 10 * MILLI, cd = 28, range = 2200 },
	frost = { dmg = 2 * MILLI, cd = 14, range = 2600, slowPct = 55, slowTicks = 20 },
	oil = { dmg = 6 * MILLI, cd = 18, range = 1600 },
}
local TRAP_NAMES = { "archer", "cannon", "frost", "oil" }

-- calibragem em porcentagem inteira (sem float)
local TUNING = { powerPct = 460, leakScalePct = 100 }

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

	-- SoA inteiro
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
	local variancePct = 90 + self.rng:int(21) -- 90..110
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

	-- spawn em ticks
	if self.spawned < self.toSpawn then
		self.spawnTimer += 1
		if self.spawnTimer >= self.spawnEvery then
			self.spawnTimer = 0
			self:spawnUnit()
			self.spawned += 1
		end
	end

	-- armadilhas
	for lane = 1, 5 do
		local trap = self.traps[lane]
		trap.cd -= 1
		if trap.cd <= 0 then
			trap.cd = TRAP[trap.type].cd
			self:applyTrap(lane)
		end
	end

	-- movimento inteiro e vazamento
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

	-- hash FNV-1a 32-bit exato
	local acc = bit32.band(math.floor(self.wallHp / MILLI), 0xFFFFFFFF)
	acc = bit32.bxor(acc, bit32.band(self.uCount, 0xFFFF))
	acc = bit32.bxor(acc, bit32.band(self.killed, 0xFFFF))
	acc = bit32.bxor(acc, bit32.band(self.leaked, 0xFFFF))
	self.hash = mul32(bit32.bxor(self.hash, acc), 16777619)
end

function Battle:Finished()
	return self.wallHp <= 0 or self.tick >= MAX_TICKS
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

-- invariantes: nenhum valor fracionario pode existir no estado
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
local seen, wins, total, leakedSum = {}, 0, 0, 0
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
	elapsed, elapsed, 1000 / elapsed))

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

print("\n=== 5. INVARIANTES INTEIROS (sem float no estado) ===")
local okInt = true
for seed = 1, 100 do
	local b = Battle.new({ seed = seed, waveCount = 80 })
	for _ = 1, 400 do
		b:Step()
		local ok = b:CheckIntegers()
		if not ok then
			okInt = false
			break
		end
		if b:Finished() then
			break
		end
	end
end
print("  -> " .. (okInt and "OK: todo o estado e inteiro" or "FALHOU: apareceu fracionario"))

print("\n=== 6. FUZZ (500 seeds, wave aleatoria) ===")
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

print("\n=== 7. VARREDURA DE CALIBRAGEM (vitoria do defensor %) ===")
local waves = { 60, 75, 90 }
local powers = { 200, 300, 380, 460, 540 }
local header = string.format("  %-13s", "power% \\ wave")
for _, w in ipairs(waves) do
	header ..= string.format("%6d", w)
end
print(header)
for _, p in ipairs(powers) do
	TUNING.powerPct = p
	local line = string.format("  %-13d", p)
	for _, w in ipairs(waves) do
		local w2 = 0
		for seed = 1, 200 do
			if run(seed, w).winner == "defender" then
				w2 += 1
			end
		end
		line ..= string.format("%5.0f%%", w2 / 200 * 100)
	end
	print(line)
end
TUNING.powerPct = 460
