--!nonstrict
-- Nucleo deterministico da Muralha (matematica v5: colocacao livre em posicoes inteiras,
-- alvo por distancia/alcance, muralha Nv1..Nv5, armadilhas L1..L5, sinergias espaciais).
-- Regras: zero float no estado, mul32/add32 em toda operacao 32-bit, 1200 ticks = 60s.
-- Sem dependencia de API do Roblox: roda no Luau CLI e no servidor.

local bit32 = bit32

local Core = {}

Core.MILLI = 1000
Core.TICK_HZ = 20
Core.MAX_TICKS = 1200
Core.DEFAULT_POWER_PCT = 270
-- Grade legada (Q2, 09/11/2026): 5x5. Na v5 a celula `rXcY` e so um atalho para o centro dela
-- (Core.cellToPos); a colocacao e livre em posicoes inteiras (Core.ARENA).
Core.GRID_WIDTH = 5
Core.GRID_HEIGHT = 5
-- Limite ativo do Nv1 (compat P1). O limite real vem de Core.WALL_LEVELS[wall.level].
Core.ACTIVE_TRAP_LIMIT = 5
Core.MAX_TRAP_LEVEL = 5
Core.MAX_WALL_LEVEL = 5
-- Versao da matematica do motor. Muda SO quando o resultado muda; replay antigo
-- nao paga recompensa. Metadado: nao entra no hash nem no estado.
-- v2 (09/11/2026): loadout por celula e 5 lanes; o hash 668061367 foi aposentado.
-- v3 (10/11/2026): 5o tipo (catapult, splash) e oil -> tar; a parede padrao nao muda de
-- comportamento, entao o hash de referencia 2489780106 continua valido.
-- v4 (13/11/2026): disparo real de armadilha, uSlowPct/splash slow, sinergias espaciais
-- (Piche Incendiario, Choque Termico, Bateria Cruzada) e tabelas congeladas.
-- v5 (13/11/2026, P2): posicoes livres (x, y) em milli, alvo por alcance lateral (LANE_REACH),
-- Bateria Cruzada por losango de distancia, muralha Nv1..Nv5 (hp/limite) e armadilhas L4/L5.
-- v6 (13/11/2026): archer com mira circular 360 graus (omni=true, range=2500, dmg=1400).
Core.SIM_VERSION = 6

local function deepFreeze(tbl)
	for _, value in pairs(tbl) do
		if type(value) == "table" and not table.isfrozen(value) then
			deepFreeze(value)
		end
	end
	if not table.isfrozen(tbl) then
		table.freeze(tbl)
	end
	return tbl
end

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

local UNIT = deepFreeze({
	runner = { hp = 14 * MILLI, speed = 150, leak = 8 * MILLI },
	brute = { hp = 45 * MILLI, speed = 75, leak = 25 * MILLI },
	swarm = { hp = 7 * MILLI, speed = 210, leak = 3 * MILLI },
})
local UNIT_NAMES = deepFreeze({ "runner", "brute", "swarm" })

local TRAP = deepFreeze({
	archer = { dmg = 1400, cd = 10, range = 2500, omni = true },
	cannon = { dmg = 10 * MILLI, cd = 28, range = 2200 },
	catapult = { dmg = 9 * MILLI, cd = 40, range = 3000, splash = true },
	frost = { dmg = 2 * MILLI, cd = 14, range = 2600, slowPct = 55, slowTicks = 20 },
	tar = { dmg = 6 * MILLI, cd = 18, range = 1600 },
})
local TRAP_NAMES = deepFreeze({ "archer", "cannon", "catapult", "frost", "tar" })

-- Nivel da armadilha (L1..L5): % de dano e reducao de cooldown em ticks. L1..L3 sao identicos
-- a v4 (100/120/140, sem bonus de cd); L4/L5 nasceram na P2.
local LEVEL_DMG_PCT = deepFreeze({ 100, 120, 140, 165, 200 })
local LEVEL_CD_BONUS = deepFreeze({ 0, 0, 0, 1, 2 })
local MIN_TRAP_CD = 8

-- Tiers estruturais da muralha (docs/skills-tiers-e-modos.md §2.3). Custo em ouro mora no
-- TrapCatalog.WALL_UPGRADES; aqui so o que muda a batalha.
local WALL_LEVELS = deepFreeze({
	{ hp = 500, trapLimit = 5 },
	{ hp = 650, trapLimit = 5 },
	{ hp = 800, trapLimit = 6 },
	{ hp = 1000, trapLimit = 6 },
	{ hp = 1250, trapLimit = 7 },
})

-- Arena da colocacao livre (milli). x = profundidade (muralha em 0, spawn em SPAWN_X);
-- y = largura (lane L no centro y = L*1000 - 500). Posicao valida: dentro dos limites, multipla
-- de STEP (grade de 1/4) e a MIN_SPACING (Chebyshev) de qualquer outra armadilha.
-- LANE_REACH: uma armadilha alcanca unidades com |dy| <= LANE_REACH; no centro da lane so a
-- propria lane, na divisa entre duas lanes as duas.
local ARENA = deepFreeze({
	xMin = 1000,
	xMax = 9000,
	yMin = 500,
	yMax = 4500,
	step = 250,
	minSpacing = 1000,
	laneReach = 500,
	laneWidth = 1000,
	spawnX = 10000,
})
-- Bateria Cruzada (losango): |dx|*SYN_DY + |dy|*SYN_DX <= SYN_DX*SYN_DY (centros ortogonais
-- vizinhos da grade legada ficam exatamente na borda; diagonais ficam fora).
local SYN_DX = 1500
local SYN_DY = 1000

Core.LEVEL_DMG_PCT = LEVEL_DMG_PCT
Core.LEVEL_CD_BONUS = LEVEL_CD_BONUS
Core.WALL_LEVELS = WALL_LEVELS
Core.ARENA = ARENA
Core.MAX_ACTIVE_TRAP_LIMIT = WALL_LEVELS[#WALL_LEVELS].trapLimit

Core.UNIT = UNIT
Core.TRAP = TRAP
Core.TRAP_NAMES = TRAP_NAMES

Core.TUNING = deepFreeze({ powerPct = Core.DEFAULT_POWER_PCT, leakScalePct = 100 })

function Core.setTuning(patch)
	assert(type(patch) == "table", "Core.setTuning: patch invalido")
	local current = Core.TUNING
	local powerPct = patch.powerPct
	if powerPct == nil then
		powerPct = current.powerPct
	end
	local leakScalePct = patch.leakScalePct
	if leakScalePct == nil then
		leakScalePct = current.leakScalePct
	end
	assert(
		type(powerPct) == "number" and powerPct > 0 and powerPct % 1 == 0,
		"Core.setTuning: powerPct invalido"
	)
	assert(
		type(leakScalePct) == "number" and leakScalePct >= 0 and leakScalePct % 1 == 0,
		"Core.setTuning: leakScalePct invalido"
	)
	local nextTuning = deepFreeze({
		powerPct = powerPct,
		leakScalePct = leakScalePct,
	})
	Core.TUNING = nextTuning
	return nextTuning
end

-- Geometria da grade: a linha e a lane de caminhada; a coluna e a profundidade.
-- c1 fica junto da muralha (x=2000) e c5 junto do spawn (x=8000).
local COLUMN_X = deepFreeze({ 2000, 3500, 5000, 6500, 8000 })
local DEFAULT_WALL_TYPES = deepFreeze({ "archer", "archer", "frost", "tar", "frost" })

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

local function isInt(value)
	return type(value) == "number" and value == value and value % 1 == 0
end

function Core.laneY(lane)
	return lane * ARENA.laneWidth - ARENA.laneWidth // 2
end

-- Centro da celula legada rXcY -> (x, y). nil se a celula nao e canonica.
function Core.cellToPos(cell)
	local row, col = parseCell(cell)
	if row == nil then
		return nil, nil
	end
	return COLUMN_X[col], Core.laneY(row)
end

-- Inverso: so devolve a celula quando (x, y) e exatamente o centro de uma celula 5x5.
function Core.posToCell(x, y)
	for col, cx in ipairs(COLUMN_X) do
		if cx == x then
			for row = 1, Core.GRID_HEIGHT do
				if Core.laneY(row) == y then
					return string.format("r%dc%d", row, col)
				end
			end
		end
	end
	return nil
end

-- Valida uma posicao isolada (limites + grade). Devolve (ok, erro).
function Core.validatePosition(x, y)
	if not isInt(x) or not isInt(y) then
		return false, "posicao nao inteira"
	end
	if x < ARENA.xMin or x > ARENA.xMax or y < ARENA.yMin or y > ARENA.yMax then
		return false, "posicao fora da arena"
	end
	if x % ARENA.step ~= 0 or y % ARENA.step ~= 0 then
		return false, "posicao fora da grade de " .. ARENA.step
	end
	return true, nil
end

-- true quando duas posicoes violam o espacamento minimo.
function Core.tooClose(ax, ay, bx, by)
	return math.abs(ax - bx) < ARENA.minSpacing and math.abs(ay - by) < ARENA.minSpacing
end

function Core.wallLevelDef(level)
	local lvl = level or 1
	assert(isInt(lvl) and WALL_LEVELS[lvl] ~= nil, "wall.level fora de [1," .. #WALL_LEVELS .. "]")
	return WALL_LEVELS[lvl]
end

local function trapDamage(trap)
	local def = TRAP[trap.type]
	local levelPct = LEVEL_DMG_PCT[trap.level]
	return math.floor(def.dmg * Core.TUNING.powerPct * levelPct / 10000)
end

local function normalizeTraps(traps, trapLimit)
	if traps == nil then
		return {}
	end
	assert(type(traps) == "table", "wall.traps invalida")
	local limit = trapLimit or Core.ACTIVE_TRAP_LIMIT
	local count = 0
	for key in pairs(traps) do
		assert(type(key) == "number", "wall.traps deve ser uma lista (array)")
		count += 1
	end
	assert(count == #traps, "wall.traps deve ser uma lista densa (sem buracos)")
	local normalized = {}
	for index, trap in ipairs(traps) do
		local label = "wall.traps[" .. index .. "]"
		assert(type(trap) == "table", label .. " invalida")
		assert(#normalized < limit, "wall.traps acima de " .. tostring(limit) .. " ativas")
		local x, y = trap.x, trap.y
		if trap.cell ~= nil then
			local cx, cy = Core.cellToPos(trap.cell)
			assert(cx ~= nil, label .. ".cell invalida (" .. tostring(trap.cell) .. ")")
			if x == nil and y == nil then
				x, y = cx, cy
			else
				assert(x == cx and y == cy, label .. ": cell e posicao divergentes")
			end
		end
		local okPos, errPos = Core.validatePosition(x, y)
		assert(okPos, label .. ": " .. tostring(errPos))
		for _, other in ipairs(normalized) do
			assert(
				not Core.tooClose(x, y, other.x, other.y),
				label .. ": espacamento minimo violado (" .. x .. "," .. y .. ")"
			)
		end
		assert(TRAP[trap.type] ~= nil, label .. ".type invalido (" .. tostring(trap.type) .. ")")
		local level = trap.level or 1
		assert(
			isInt(level) and level >= 1 and level <= Core.MAX_TRAP_LEVEL,
			label .. ".level fora de [1," .. Core.MAX_TRAP_LEVEL .. "]"
		)
		normalized[#normalized + 1] = {
			type = trap.type,
			level = level,
			x = x,
			y = y,
			yLo = y - ARENA.laneReach,
			yHi = y + ARENA.laneReach,
			cd = 0,
			baseCd = math.max(MIN_TRAP_CD, TRAP[trap.type].cd - LEVEL_CD_BONUS[level]),
		}
	end
	-- Ordem canonica (y, x): a ordem de entrada nunca muda o replay (igual a (linha, coluna) v2).
	table.sort(normalized, function(a, b)
		if a.y ~= b.y then
			return a.y < b.y
		end
		return a.x < b.x
	end)
	-- Bateria Cruzada: cada archer vizinho (losango SYN_DX x SYN_DY) reduz baseCd em -1t
	-- (cap -2t, piso 8t). Calculado sobre o cd original do tipo para nao depender da ordem.
	local reductions = {}
	for i, trap in ipairs(normalized) do
		reductions[i] = 0
		if trap.type == "archer" then
			local adjArchers = 0
			for j, other in ipairs(normalized) do
				if i ~= j and other.type == "archer" then
					local dx = math.abs(trap.x - other.x)
					local dy = math.abs(trap.y - other.y)
					if dx * SYN_DY + dy * SYN_DX <= SYN_DX * SYN_DY then
						adjArchers += 1
					end
				end
			end
			reductions[i] = math.min(2, adjArchers)
		end
	end
	for i, trap in ipairs(normalized) do
		trap.baseCd = math.max(MIN_TRAP_CD, trap.baseCd - reductions[i])
	end
	return normalized
end

-- Valida uma parede inteira sem rodar a batalha (servidor/contratos). Devolve (ok, erro).
function Core.validateWall(wall)
	if type(wall) ~= "table" then
		return false, "wall invalida"
	end
	local ok, err = pcall(function()
		local def = Core.wallLevelDef(wall.level)
		normalizeTraps(wall.traps, def.trapLimit)
	end)
	if not ok then
		return false, tostring(err)
	end
	return true, nil
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
	local levelDef = Core.wallLevelDef(wall.level)
	local hp = wall.hp or levelDef.hp
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
	-- Menor indice possivelmente vivo (so pula mortos: otimizacao pura, nao muda resultado).
	self.aliveLo = 1
	self.uHp = {}
	self.uX = {}
	self.uY = {}
	self.uLane = {} -- lane de spawn (1..5): metadado de apresentacao (RaidClient); o alvo usa uY
	self.uBaseSpeed = {}
	self.uSlowUntil = {}
	self.uSlowPct = {}
	self.uTarUntil = {}
	self.uFrostUntil = {}
	self.uLeak = {}

	self.wallLevel = wall.level or 1
	self.traps = normalizeTraps(wall.traps, levelDef.trapLimit)

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
	self.uX[i] = ARENA.spawnX
	self.uY[i] = Core.laneY(lane)
	self.uLane[i] = lane
	self.uBaseSpeed[i] = def.speed
	self.uSlowUntil[i] = 0
	self.uSlowPct[i] = 100
	self.uTarUntil[i] = 0
	self.uFrostUntil[i] = 0
	self.uLeak[i] = def.leak
end

local function hitDamage(self, trap, baseDamage, unitIndex)
	local dmg = baseDamage
	if
		(trap.type == "cannon" or trap.type == "catapult")
		and self.tick <= self.uTarUntil[unitIndex]
	then
		dmg = math.floor(dmg * 1250 / 1000)
	end
	if trap.type == "cannon" and self.tick <= self.uFrostUntil[unitIndex] then
		dmg = math.floor(dmg * 1200 / 1000)
	end
	return dmg
end

local function applyStatus(self, trap, def, unitIndex)
	if def.slowPct then
		self.uSlowUntil[unitIndex] = self.tick + def.slowTicks
		self.uSlowPct[unitIndex] = def.slowPct
		if trap.type == "frost" then
			self.uFrostUntil[unitIndex] = self.tick + def.slowTicks
		end
	end
	if trap.type == "tar" then
		self.uTarUntil[unitIndex] = self.tick + 30
	end
end

function Battle:applyTrap(trap)
	local def = TRAP[trap.type]
	local damage = trapDamage(trap)
	-- faixa lateral pre-calculada no normalize (|uY - y| <= LANE_REACH, sem chamada no laco)
	local yLo, yHi = trap.yLo, trap.yHi
	-- Catapult atinge todas as unidades no alcance (frente + faixa lateral); os outros tipos
	-- miram a unidade mais a frente (uma por cooldown).
	if def.splash then
		local hitAny = false
		for i = self.aliveLo, self.uCount do
			if self.uHp[i] > 0 and self.uY[i] >= yLo and self.uY[i] <= yHi then
				local dx = self.uX[i] - trap.x
				if dx > 0 and dx <= def.range then
					hitAny = true
					self.uHp[i] -= hitDamage(self, trap, damage, i)
					applyStatus(self, trap, def, i)
					if self.uHp[i] <= 0 then
						self.uHp[i] = 0
						self.killed += 1
					end
				end
			end
		end
		return hitAny
	end
	local best, bestX = nil, math.huge
	if def.omni then
		local r2 = def.range * def.range
		for i = self.aliveLo, self.uCount do
			if self.uHp[i] > 0 then
				local dx = self.uX[i] - trap.x
				local dy = self.uY[i] - trap.y
				if dx * dx + dy * dy <= r2 and self.uX[i] < bestX then
					best, bestX = i, self.uX[i]
				end
			end
		end
	else
		for i = self.aliveLo, self.uCount do
			if self.uHp[i] > 0 and self.uY[i] >= yLo and self.uY[i] <= yHi then
				local dx = self.uX[i] - trap.x
				if dx > 0 and dx <= def.range and self.uX[i] < bestX then
					best, bestX = i, self.uX[i]
				end
			end
		end
	end
	if not best then
		return false
	end
	self.uHp[best] -= hitDamage(self, trap, damage, best)
	applyStatus(self, trap, def, best)
	if self.uHp[best] <= 0 then
		self.uHp[best] = 0
		self.killed += 1
	end
	return true
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
		if trap.cd > 0 then
			trap.cd -= 1
		end
		if trap.cd <= 0 then
			if self:applyTrap(trap) then
				trap.cd = trap.baseCd
			end
		end
	end

	local leakScalePct = Core.TUNING.leakScalePct
	for i = self.aliveLo, self.uCount do
		if self.uHp[i] > 0 then
			local speed = self.uBaseSpeed[i]
			if self.tick <= self.uSlowUntil[i] then
				speed = math.floor(speed * self.uSlowPct[i] / 100)
			end
			self.uX[i] -= speed
			if self.uX[i] <= 0 then
				self.uHp[i] = 0
				self.leaked += 1
				self.wallHp -= math.floor(self.uLeak[i] * leakScalePct / 100)
			end
		end
	end

	local lo = self.aliveLo
	while lo <= self.uCount and self.uHp[lo] <= 0 do
		lo += 1
	end
	self.aliveLo = lo

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
		for _, v in ipairs({
			self.uHp[i],
			self.uX[i],
			self.uY[i],
			self.uBaseSpeed[i],
			self.uSlowUntil[i],
			self.uSlowPct[i],
			self.uTarUntil[i],
			self.uFrostUntil[i],
		}) do
			if v ~= math.floor(v) then
				return false, i
			end
		end
	end
	for index = 1, #self.traps do
		local trap = self.traps[index]
		if
			trap.cd ~= math.floor(trap.cd)
			or trap.baseCd ~= math.floor(trap.baseCd)
			or trap.x ~= math.floor(trap.x)
			or trap.y ~= math.floor(trap.y)
		then
			return false, -index
		end
	end
	return true, 0
end

Core.Battle = Battle

-- Loadout padrao dos harnesses: uma armadilha por lane na coluna central (5 ativas, Nv1).
-- `cell` e mantido como atalho legado; (x, y) e a fonte da v5.
function Core.defaultWall()
	local traps = {}
	for row = 1, Core.GRID_HEIGHT do
		traps[#traps + 1] = {
			cell = string.format("r%dc3", row),
			x = COLUMN_X[3],
			y = Core.laneY(row),
			type = DEFAULT_WALL_TYPES[row],
			level = 1,
		}
	end
	return { hp = WALL_LEVELS[1].hp, level = 1, traps = traps }
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
