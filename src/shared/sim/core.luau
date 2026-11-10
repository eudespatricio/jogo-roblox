--!nonstrict
-- Nucleo deterministico da Muralha (matematica v2: grade 5x5, loadout por celula).
-- Regras: zero float no estado, mul32/add32 em toda operacao 32-bit, 1200 ticks = 60s.
-- Sem dependencia de API do Roblox: roda no Luau CLI e no servidor.

local bit32 = bit32

local Core = {}

Core.MILLI = 1000
Core.TICK_HZ = 20
Core.MAX_TICKS = 1200
Core.DEFAULT_POWER_PCT = 460
-- Grade do MVP (Q2, 09/11/2026): 5x5, N=5 ativas, colocacao livre nas 25 celulas.
Core.GRID_WIDTH = 5
Core.GRID_HEIGHT = 5
Core.ACTIVE_TRAP_LIMIT = 5
-- Versao da matematica do motor. Muda SO quando o resultado muda; replay antigo
-- nao paga recompensa. Metadado: nao entra no hash nem no estado.
-- v2 (09/11/2026): loadout por celula e 5 lanes; o hash 668061367 foi aposentado.
Core.SIM_VERSION = 2

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
Core.TRAP_NAMES = TRAP_NAMES

local TUNING = { powerPct = Core.DEFAULT_POWER_PCT, leakScalePct = 100 }
Core.TUNING = TUNING

-- Geometria da grade: a linha e a lane de caminhada; a coluna e a profundidade.
-- c1 fica junto da muralha (x=2000) e c5 junto do spawn (x=8000).
local COLUMN_X = { 2000, 3500, 5000, 6500, 8000 }
local DEFAULT_WALL_TYPES = { "archer", "archer", "frost", "oil", "frost" }

local function parseCell(cell)
	if type(cell) ~= "string" then
		return nil, nil
	end
	local rowText, colText = string.match(cell, "^r(%d+)c(%d+)$")
	if rowText == nil or colText == nil then
		return nil, nil
	end
	local row = tonumber(rowText)
	local col = tonumber(colText)
	if row < 1 or row > Core.GRID_HEIGHT or col < 1 or col > Core.GRID_WIDTH then
		return nil, nil
	end
	-- forma canonica: "r01c1" nao pode virar um segundo alias da mesma celula
	if string.format("r%dc%d", row, col) ~= cell then
		return nil, nil
	end
	return row, col
end

-- nivel 1 = dano base; cada nivel adicional soma 20% (teto 5).
local function trapDamage(trap)
	local def = TRAP[trap.type]
	local levelPct = 100 + 20 * (trap.level - 1)
	return math.floor(def.dmg * TUNING.powerPct * levelPct / 10000)
end

local function normalizeTraps(traps)
	if traps == nil then
		return {}
	end
	assert(type(traps) == "table", "wall.traps invalida")
	local count = 0
	for key in pairs(traps) do
		assert(type(key) == "number", "wall.traps deve ser uma lista (array)")
		count += 1
	end
	assert(count == #traps, "wall.traps deve ser uma lista densa (sem buracos)")
	local normalized = {}
	local seen = {}
	for index, trap in ipairs(traps) do
		assert(type(trap) == "table", "wall.traps[" .. index .. "] invalida")
		assert(
			#normalized < Core.ACTIVE_TRAP_LIMIT,
			"wall.traps acima de " .. tostring(Core.ACTIVE_TRAP_LIMIT) .. " ativas"
		)
		local row, col = parseCell(trap.cell)
		assert(
			row ~= nil,
			"wall.traps[" .. index .. "].cell invalida (" .. tostring(trap.cell) .. ")"
		)
		assert(not seen[trap.cell], "wall.traps: celula repetida (" .. tostring(trap.cell) .. ")")
		seen[trap.cell] = true
		assert(
			TRAP[trap.type] ~= nil,
			"wall.traps[" .. index .. "].type invalido (" .. tostring(trap.type) .. ")"
		)
		local level = trap.level or 1
		assert(
			type(level) == "number" and level % 1 == 0 and level >= 1 and level <= 5,
			"wall.traps[" .. index .. "].level fora de [1,5]"
		)
		normalized[#normalized + 1] = {
			type = trap.type,
			level = level,
			cell = trap.cell,
			row = row,
			col = col,
			x = COLUMN_X[col],
			cd = 0,
		}
	end
	return normalized
end

-- ---------------------------------------------------------------- batalha
local Battle = {}
Battle.__index = Battle

function Battle.new(spec)
	assert(type(spec) == "table", "Battle.new: spec ausente")
	assert(type(spec.seed) == "number", "Battle.new: seed ausente")
	assert(spec.simVersion ~= nil, "Battle.new: simVersion ausente")
	local simVersion = spec.simVersion
	if simVersion ~= Core.SIM_VERSION then
		error(
			string.format(
				"Battle.new: simVersion %s != %d (replay antigo nao roda no motor novo)",
				tostring(simVersion),
				Core.SIM_VERSION
			),
			2
		)
	end
	assert(spec.wall ~= nil, "Battle.new: wall ausente")
	local wall = spec.wall
	assert(type(wall) == "table", "Battle.new: wall invalida")
	assert(spec.wave ~= nil, "Battle.new: wave ausente")
	local wave = spec.wave
	assert(type(wave) == "table", "Battle.new: wave invalida")

	local self = setmetatable({}, Battle)
	self.simVersion = simVersion
	self.rng = RNG.new(spec.seed)
	self.seed = spec.seed
	local hp = wall.hp or 500
	assert(type(hp) == "number" and hp > 0 and hp % 1 == 0, "Battle.new: wall.hp invalido")
	local spawnEvery = wave.spawnEveryTicks or 14
	assert(
		type(spawnEvery) == "number" and spawnEvery % 1 == 0 and spawnEvery >= 1,
		"Battle.new: wave.spawnEveryTicks invalido"
	)
	local count = wave.count or 70
	assert(
		type(count) == "number" and count % 1 == 0 and count >= 0,
		"Battle.new: wave.count invalido"
	)

	self.wallHp = hp * MILLI
	self.wallMax = self.wallHp
	self.tick = 0
	self.spawnEvery = spawnEvery
	self.spawnTimer = 0
	self.toSpawn = count
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

	self.traps = normalizeTraps(wall.traps)

	return self
end

function Battle:spawnUnit()
	local lane = self.rng:int(Core.GRID_HEIGHT)
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

function Battle:applyTrap(trap)
	local def = TRAP[trap.type]
	local best, bestX = nil, math.huge
	for i = 1, self.uCount do
		if self.uHp[i] > 0 and self.uLane[i] == trap.row then
			local dx = self.uX[i] - trap.x
			if dx > 0 and dx <= def.range and self.uX[i] < bestX then
				best, bestX = i, self.uX[i]
			end
		end
	end
	if not best then
		return
	end
	self.uHp[best] -= trapDamage(trap)
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

	for _, trap in ipairs(self.traps) do
		trap.cd -= 1
		if trap.cd <= 0 then
			trap.cd = TRAP[trap.type].cd
			self:applyTrap(trap)
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
		traps = #self.traps,
		seed = self.seed,
		simVersion = self.simVersion,
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
	for index = 1, #self.traps do
		if self.traps[index].cd ~= math.floor(self.traps[index].cd) then
			return false, -index
		end
	end
	return true, 0
end

Core.Battle = Battle

-- Loadout padrao dos harnesses: uma armadilha por lane na coluna central (5 ativas).
function Core.defaultWall()
	local traps = {}
	for row = 1, Core.GRID_HEIGHT do
		traps[#traps + 1] = {
			cell = string.format("r%dc3", row),
			type = DEFAULT_WALL_TYPES[row],
			level = 1,
		}
	end
	return { hp = 500, traps = traps }
end

-- Atalho de loadout padrao para os harnesses/testes. O jogo usa Battle.new com a parede
-- do jogador (a S3 liga o perfil a este contrato).
function Core.Run(seed, waveCount, wallHp)
	local wall = Core.defaultWall()
	if wallHp ~= nil then
		wall.hp = wallHp
	end
	local battle = Battle.new({
		seed = seed,
		simVersion = Core.SIM_VERSION,
		wall = wall,
		wave = { count = waveCount or 70 },
	})
	return battle:Run()
end

return Core
