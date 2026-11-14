--!nonstrict
-- Nucleo deterministico da Muralha (matematica v7: colocacao livre em posicoes inteiras,
-- alvo por distancia/alcance, muralha Nv1..Nv5, armadilhas L1..L5, sinergias espaciais,
-- 6 arquétipos de horda, 8 mutadores, WaveSliceSpec e 5 Bosses Multi-Lane FSM).
-- Regras: zero float no estado, mul32/add32 em toda operacao 32-bit, 1200 ticks = 60s.
-- Sem dependencia de API do Roblox: roda no Luau CLI e no servidor.

local bit32 = bit32

local Core = {}

Core.MILLI = 1000
Core.TICK_HZ = 20
Core.MAX_TICKS = 1200
Core.DEFAULT_POWER_PCT = 270
Core.MAX_ELITES_PER_BATTLE = 85
Core.MAX_ARMOR_MILLI = 600
Core.MAX_SPEED_MILLI = 2400
-- Grade legada (Q2, 09/11/2026): 5x5. Na v5+ a celula `rXcY` e so um atalho para o centro dela
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
-- v7 (14/11/2026): 6 tipos de unidade (+shieldbearer, pyromancer, sapper), WaveSliceSpec,
-- 8 mutadores deterministicos e 5 Bosses Multi-Lane (laneSpan=3, shotId dedup, stagger/FSM).
-- Preserva 100% o caminho P1 (Core.Run(42) hash == 1245379674).
Core.SIM_VERSION = 7

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

local function clampInt(v, lo, hi)
	if v < lo then
		return lo
	end
	if v > hi then
		return hi
	end
	return v
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
	shieldbearer = { hp = 34 * MILLI, speed = 95, leak = 15 * MILLI, armorMilli = 250 },
	pyromancer = {
		hp = 18 * MILLI,
		speed = 135,
		leak = 10 * MILLI,
		armorMilli = 50,
		frostResistMilli = 350,
	},
	sapper = { hp = 16 * MILLI, speed = 175, leak = 22 * MILLI, armorMilli = 0 },
})
local UNIT_NAMES = deepFreeze({ "runner", "brute", "swarm" })
local ALL_UNIT_NAMES = deepFreeze({
	"runner",
	"brute",
	"swarm",
	"shieldbearer",
	"pyromancer",
	"sapper",
})

local TRAP = deepFreeze({
	archer = { dmg = 1400, cd = 10, range = 2500, omni = true },
	cannon = { dmg = 10 * MILLI, cd = 28, range = 2200, staggerMilli = 150 },
	catapult = { dmg = 9 * MILLI, cd = 40, range = 3000, splash = true, staggerMilli = 120 },
	frost = {
		dmg = 2 * MILLI,
		cd = 14,
		range = 2600,
		slowPct = 55,
		slowTicks = 20,
		staggerMilli = 90,
	},
	tar = { dmg = 6 * MILLI, cd = 18, range = 1600 },
})
local TRAP_NAMES = deepFreeze({ "archer", "cannon", "catapult", "frost", "tar" })

local BOSS_SPECS = deepFreeze({
	iron_ram_colossus = {
		bossId = "iron_ram_colossus",
		act = 1,
		hp = 420 * MILLI,
		armorMilli = 150,
		speedMilli = 800,
		laneCenter = 3,
		laneSpan = 3,
		staggerCapMilli = 600,
		abilityCdTicks = 240,
	},
	slag_juggernaut = {
		bossId = "slag_juggernaut",
		act = 2,
		hp = 680 * MILLI,
		armorMilli = 300,
		speedMilli = 700,
		laneCenter = 3,
		laneSpan = 3,
		staggerCapMilli = 600,
		abilityCdTicks = 220,
	},
	rime_matriarch = {
		bossId = "rime_matriarch",
		act = 3,
		hp = 840 * MILLI,
		armorMilli = 200,
		speedMilli = 960,
		laneCenter = 3,
		laneSpan = 3,
		staggerCapMilli = 600,
		abilityCdTicks = 200,
	},
	powder_baron = {
		bossId = "powder_baron",
		act = 4,
		hp = 1050 * MILLI,
		armorMilli = 250,
		speedMilli = 1040,
		laneCenter = 3,
		laneSpan = 3,
		staggerCapMilli = 600,
		abilityCdTicks = 200,
	},
	rift_titan = {
		bossId = "rift_titan",
		act = 5,
		hp = 1450 * MILLI,
		armorMilli = 350,
		speedMilli = 900,
		laneCenter = 3,
		laneSpan = 3,
		staggerCapMilli = 600,
		abilityCdTicks = 180,
	},
})
local BOSS_IDS = deepFreeze({
	"iron_ram_colossus",
	"slag_juggernaut",
	"rime_matriarch",
	"powder_baron",
	"rift_titan",
})

local MUTATORS = deepFreeze({
	mut_iron_hide = { id = "mut_iron_hide", bruteArmorBonusMilli = 200, bossArmorBonusMilli = 200 },
	mut_haste_wind = { id = "mut_haste_wind", speedBonusMilli = 180 },
	mut_frost_ward = { id = "mut_frost_ward", slowDurationScaleMilli = 600 },
	mut_swarm_surge = { id = "mut_swarm_surge", swarmCountScaleMilli = 1350 },
	mut_amber_tax = { id = "mut_amber_tax", trapCdScaleMilli = 1150 },
	mut_cracked_gate = { id = "mut_cracked_gate", wallHpScaleMilli = 750 },
	mut_volatile_oil = { id = "mut_volatile_oil", staggerBonusMilli = 150 },
	mut_echo_rift = { id = "mut_echo_rift", everyRunnerCount = 4 },
})
local MUTATOR_IDS = deepFreeze({
	"mut_iron_hide",
	"mut_haste_wind",
	"mut_frost_ward",
	"mut_swarm_surge",
	"mut_amber_tax",
	"mut_cracked_gate",
	"mut_volatile_oil",
	"mut_echo_rift",
})

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
Core.UNIT_NAMES = UNIT_NAMES
Core.ALL_UNIT_NAMES = ALL_UNIT_NAMES
Core.TRAP = TRAP
Core.TRAP_NAMES = TRAP_NAMES
Core.BOSS_SPECS = BOSS_SPECS
Core.BOSS_IDS = BOSS_IDS
Core.MUTATORS = MUTATORS
Core.MUTATOR_IDS = MUTATOR_IDS

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
			jamUntil = 0,
			frostSlowUntil = 0,
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

local function extractLanesFromMask(laneMask)
	if not isInt(laneMask) or laneMask <= 0 then
		return { 1, 2, 3, 4, 5 }
	end
	local lanes = {}
	for lane = 1, Core.GRID_HEIGHT do
		if bit32.band(laneMask, bit32.lshift(1, lane - 1)) ~= 0 then
			lanes[#lanes + 1] = lane
		end
	end
	if #lanes == 0 then
		return { 1, 2, 3, 4, 5 }
	end
	return lanes
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
	self.nextShotId = 0
	self.eliteSpawned = 0
	self.runnerSpawnCount = 0

	self.uCount = 0
	-- Menor indice possivelmente vivo (so pula mortos: otimizacao pura, nao muda resultado).
	self.aliveLo = 1
	self.uHp = {}
	self.uX = {}
	self.uY = {}
	self.uLane = {} -- lane de spawn (1..5): metadado de apresentacao (RaidClient); o alvo usa uY
	self.uType = {}
	self.uIsElite = {}
	self.uArmorMilli = {}
	self.uFrostResistMilli = {}
	self.uBaseSpeed = {}
	self.uSlowUntil = {}
	self.uSlowPct = {}
	self.uTarUntil = {}
	self.uFrostUntil = {}
	self.uLeak = {}

	self.wallLevel = wall.level or 1
	self.traps = normalizeTraps(wall.traps, levelDef.trapLimit)

	local hasExtensions = wave.slices ~= nil
		or wave.pool ~= nil
		or wave.bossId ~= nil
		or wave.hpScaleMilli ~= nil
		or wave.modeScaleMilli ~= nil
		or wave.armorMilli ~= nil
		or wave.speedMilli ~= nil
		or wave.mutatorIds ~= nil
	self.hasWaveExtensions = hasExtensions
	self.boss = nil

	if hasExtensions then
		local hpScaleMilli = wave.hpScaleMilli or MILLI
		assert(
			isInt(hpScaleMilli) and hpScaleMilli >= 100,
			"Battle.new: wave.hpScaleMilli invalido"
		)
		local modeScaleMilli = wave.modeScaleMilli or MILLI
		assert(
			isInt(modeScaleMilli) and modeScaleMilli >= 100,
			"Battle.new: wave.modeScaleMilli invalido"
		)
		local armorMilli = wave.armorMilli or 0
		assert(isInt(armorMilli), "Battle.new: wave.armorMilli invalido")
		armorMilli = clampInt(armorMilli, 0, Core.MAX_ARMOR_MILLI)

		local speedMilli = wave.speedMilli or MILLI
		assert(isInt(speedMilli) and speedMilli >= 100, "Battle.new: wave.speedMilli invalido")
		speedMilli = clampInt(speedMilli, 100, Core.MAX_SPEED_MILLI)

		local mutators = {}
		if wave.mutatorIds ~= nil then
			assert(type(wave.mutatorIds) == "table", "Battle.new: wave.mutatorIds invalido")
			for _, mutId in ipairs(wave.mutatorIds) do
				assert(
					type(mutId) == "string" and MUTATORS[mutId] ~= nil,
					"Battle.new: mutator desconhecido (" .. tostring(mutId) .. ")"
				)
				mutators[mutId] = true
			end
		end
		self.mutators = mutators

		if mutators.mut_haste_wind then
			speedMilli = clampInt(speedMilli + 180, 100, Core.MAX_SPEED_MILLI)
		end
		if mutators.mut_cracked_gate then
			self.wallHp = math.floor(self.wallMax * 750 / MILLI)
		end
		if mutators.mut_amber_tax then
			for _, trap in ipairs(self.traps) do
				trap.baseCd = math.max(MIN_TRAP_CD, math.floor(trap.baseCd * 1150 / MILLI))
			end
		end

		self.hpScaleMilli = hpScaleMilli
		self.modeScaleMilli = modeScaleMilli
		self.waveArmorMilli = armorMilli
		self.speedScaleMilli = speedMilli

		if wave.pool ~= nil then
			assert(type(wave.pool) == "table" and #wave.pool >= 1, "Battle.new: wave.pool invalido")
			local pool = {}
			for idx, unitName in ipairs(wave.pool) do
				assert(
					type(unitName) == "string" and UNIT[unitName] ~= nil,
					"Battle.new: wave.pool[" .. idx .. "] invalido"
				)
				pool[idx] = unitName
			end
			self.unitPool = pool
		else
			self.unitPool = UNIT_NAMES
		end

		if wave.slices ~= nil then
			assert(type(wave.slices) == "table", "Battle.new: wave.slices invalido")
			local slices = {}
			local totalToSpawn = 0
			for idx, rawSlice in ipairs(wave.slices) do
				assert(type(rawSlice) == "table", "Battle.new: wave.slices[" .. idx .. "] invalido")
				assert(
					type(rawSlice.unit) == "string" and UNIT[rawSlice.unit] ~= nil,
					"Battle.new: slice.unit invalido (" .. tostring(rawSlice.unit) .. ")"
				)
				local startTick = math.max(1, math.floor(tonumber(rawSlice.startTick) or 1))
				local everyTicks = math.max(1, math.floor(tonumber(rawSlice.everyTicks) or 10))
				local sliceCount = math.max(0, math.floor(tonumber(rawSlice.count) or 0))
				if mutators.mut_swarm_surge and rawSlice.unit == "swarm" and sliceCount > 0 then
					sliceCount = math.min(85, math.max(1, math.floor(sliceCount * 1350 / MILLI)))
				end
				local lanes = extractLanesFromMask(rawSlice.laneMask)
				slices[#slices + 1] = {
					startTick = startTick,
					everyTicks = everyTicks,
					count = sliceCount,
					spawned = 0,
					unit = rawSlice.unit,
					lanes = lanes,
					isElite = rawSlice.isElite == true,
				}
				totalToSpawn += sliceCount
			end
			self.slices = slices
			self.toSpawn = totalToSpawn
		elseif mutators.mut_swarm_surge and self.toSpawn > 0 then
			self.toSpawn = math.min(85, math.floor(self.toSpawn * 1150 / MILLI))
		end

		if wave.bossId ~= nil then
			local bossSpec = BOSS_SPECS[wave.bossId]
			assert(bossSpec ~= nil, "Battle.new: bossId invalido (" .. tostring(wave.bossId) .. ")")
			local bossHpScale = wave.bossHpScaleMilli or hpScaleMilli
			assert(
				isInt(bossHpScale) and bossHpScale >= 50,
				"Battle.new: wave.bossHpScaleMilli invalido"
			)
			local maxHp = math.max(
				1000,
				math.floor(math.floor(bossSpec.hp * bossHpScale / MILLI) * modeScaleMilli / MILLI)
			)
			local baseArmor = clampInt(
				bossSpec.armorMilli + armorMilli + (if mutators.mut_iron_hide then 200 else 0),
				0,
				Core.MAX_ARMOR_MILLI
			)
			local staggerCap = wave.staggerCapMilli or bossSpec.staggerCapMilli
			assert(isInt(staggerCap) and staggerCap >= 100, "Battle.new: staggerCapMilli invalido")
			local spawnTick = if wave.bossSpawnTick ~= nil then wave.bossSpawnTick else 60
			assert(isInt(spawnTick) and spawnTick >= 0, "Battle.new: bossSpawnTick invalido")
			self.boss = {
				bossId = bossSpec.bossId,
				hp = maxHp,
				maxHp = maxHp,
				x = ARENA.spawnX,
				laneCenter = bossSpec.laneCenter,
				laneSpan = 3,
				armorMilli = baseArmor,
				baseArmorMilli = baseArmor,
				tempArmorBonusMilli = 0,
				tempArmorTicksLeft = 0,
				staggerMilli = 0,
				staggerCapMilli = staggerCap,
				state = "MARCH",
				stateTicksLeft = 0,
				abilityCooldownTicks = bossSpec.abilityCdTicks,
				baseAbilityCdTicks = bossSpec.abilityCdTicks,
				speedMilli = bossSpec.speedMilli,
				enraged = false,
				alive = true,
				spawnTick = spawnTick,
				subportalTicksLeft = 0,
				slowUntil = 0,
				slowPct = 100,
				tarUntil = 0,
				frostUntil = 0,
				lastHitByShotId = {},
			}
		end
	end

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
	self.uType[i] = tname
	self.uIsElite[i] = false
	self.uArmorMilli[i] = 0
	self.uFrostResistMilli[i] = 0
	self.uBaseSpeed[i] = def.speed
	self.uSlowUntil[i] = 0
	self.uSlowPct[i] = 100
	self.uTarUntil[i] = 0
	self.uFrostUntil[i] = 0
	self.uLeak[i] = def.leak
end

function Battle:spawnConfiguredUnit(tname, lane, isElite, customX, useVariance)
	local def = UNIT[tname]
	local elite = false
	if isElite and self.eliteSpawned < Core.MAX_ELITES_PER_BATTLE then
		elite = true
		self.eliteSpawned += 1
	end
	local baseHp = def.hp
	if useVariance then
		local variancePct = 90 + self.rng:int(21)
		baseHp = math.floor(baseHp * variancePct / 100)
	end
	local hp = math.max(
		1,
		math.floor(math.floor(baseHp * self.hpScaleMilli / MILLI) * self.modeScaleMilli / MILLI)
	)
	if elite then
		hp = math.floor(hp * 1350 / MILLI)
	end

	local unitArmor = (def.armorMilli or 0) + self.waveArmorMilli
	if self.mutators.mut_iron_hide and (tname == "brute" or tname == "shieldbearer") then
		unitArmor += 200
	end
	if elite then
		unitArmor += 100
	end
	unitArmor = clampInt(unitArmor, 0, Core.MAX_ARMOR_MILLI)

	local speedTick = math.max(10, math.floor(def.speed * self.speedScaleMilli / MILLI))
	if speedTick > 240 then
		speedTick = 240
	end

	self.uCount += 1
	local i = self.uCount
	self.uHp[i] = hp
	self.uX[i] = customX or ARENA.spawnX
	self.uY[i] = Core.laneY(lane)
	self.uLane[i] = lane
	self.uType[i] = tname
	self.uIsElite[i] = elite
	self.uArmorMilli[i] = unitArmor
	self.uFrostResistMilli[i] = def.frostResistMilli or 0
	self.uBaseSpeed[i] = speedTick
	self.uSlowUntil[i] = 0
	self.uSlowPct[i] = 100
	self.uTarUntil[i] = 0
	self.uFrostUntil[i] = 0
	self.uLeak[i] = def.leak

	if tname == "runner" and self.mutators.mut_echo_rift then
		self.runnerSpawnCount += 1
		if self.runnerSpawnCount % 4 == 0 then
			self:spawnConfiguredUnit("swarm", lane, false, customX, false)
		end
	end
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
	local armor = self.uArmorMilli[unitIndex] or 0
	if armor > 0 then
		dmg = math.max(1, math.floor(dmg * (MILLI - armor) / MILLI))
	end
	return dmg
end

local function applyStatus(self, trap, def, unitIndex)
	if def.slowPct then
		local slowTicks = def.slowTicks
		if self.hasWaveExtensions then
			local resist = self.uFrostResistMilli[unitIndex] or 0
			if resist > 0 then
				slowTicks = math.floor(slowTicks * (MILLI - resist) / MILLI)
			end
			if self.mutators and self.mutators.mut_frost_ward then
				slowTicks = math.floor(slowTicks * 600 / MILLI)
			end
		end
		if slowTicks > 0 then
			self.uSlowUntil[unitIndex] = self.tick + slowTicks
			self.uSlowPct[unitIndex] = def.slowPct
			if trap.type == "frost" then
				self.uFrostUntil[unitIndex] = self.tick + slowTicks
			end
		end
	end
	if trap.type == "tar" then
		self.uTarUntil[unitIndex] = self.tick + 30
	end
end

local function bossInTrapRange(trap, def, boss)
	if boss == nil or not boss.alive or boss.hp <= 0 then
		return false
	end
	local laneLo = math.max(1, boss.laneCenter - 1)
	local laneHi = math.min(Core.GRID_HEIGHT, boss.laneCenter + 1)
	if def.omni then
		local r = def.range + 1000
		local r2 = r * r
		local dx = boss.x - trap.x
		for lane = laneLo, laneHi do
			local dy = Core.laneY(lane) - trap.y
			if dx * dx + dy * dy <= r2 then
				return true
			end
		end
		return false
	end
	local bossYLo = Core.laneY(laneLo)
	local bossYHi = Core.laneY(laneHi)
	if trap.yHi < bossYLo or trap.yLo > bossYHi then
		return false
	end
	local dx = boss.x - trap.x
	return dx >= -2000 and dx <= def.range + 1000
end

local function hitBossWithShot(self, trap, def, baseDamage, shotId)
	local boss = self.boss
	if boss == nil or not boss.alive or boss.hp <= 0 then
		return false
	end
	if boss.lastHitByShotId[shotId] then
		return false
	end
	boss.lastHitByShotId[shotId] = true

	local dmg = baseDamage
	if (trap.type == "cannon" or trap.type == "catapult") and self.tick <= boss.tarUntil then
		dmg = math.floor(dmg * 1250 / MILLI)
	end
	if trap.type == "cannon" and self.tick <= boss.frostUntil then
		dmg = math.floor(dmg * 1200 / MILLI)
	end
	if boss.armorMilli > 0 then
		dmg = math.max(1, math.floor(dmg * (MILLI - boss.armorMilli) / MILLI))
	end
	if boss.state == "VULNERABLE" then
		dmg = math.max(1, math.floor(dmg * 1300 / MILLI))
	end

	boss.hp -= dmg

	if def.slowPct then
		local slowTicks = def.slowTicks
		if self.mutators and self.mutators.mut_frost_ward then
			slowTicks = math.floor(slowTicks * 600 / MILLI)
		end
		if boss.bossId == "slag_juggernaut" and boss.enraged then
			slowTicks = math.floor(slowTicks * 500 / MILLI)
		end
		if slowTicks > 0 then
			boss.slowUntil = self.tick + slowTicks
			boss.slowPct = def.slowPct
			if trap.type == "frost" then
				boss.frostUntil = self.tick + slowTicks
			end
		end
	end
	if trap.type == "tar" then
		boss.tarUntil = self.tick + 30
	end

	local staggerAdd = def.staggerMilli or 0
	if
		staggerAdd > 0
		and self.mutators
		and self.mutators.mut_volatile_oil
		and (trap.type == "cannon" or trap.type == "catapult")
	then
		staggerAdd += 150
	end
	if staggerAdd > 0 and boss.state ~= "VULNERABLE" and boss.hp > 0 then
		boss.staggerMilli += staggerAdd
		if boss.staggerMilli >= boss.staggerCapMilli then
			boss.staggerMilli = boss.staggerCapMilli
			boss.state = "VULNERABLE"
			boss.stateTicksLeft = 30
		end
	end

	if boss.hp > 0 and not boss.enraged and boss.hp * 1000 < boss.maxHp * 400 then
		boss.enraged = true
		boss.abilityCooldownTicks = math.floor(boss.abilityCooldownTicks * 750 / 1000)
	end

	if boss.hp <= 0 then
		boss.hp = 0
		boss.alive = false
		self.killed += 1
	end
	return true
end

function Battle:applyTrap(trap, shotId)
	local def = TRAP[trap.type]
	local damage = trapDamage(trap)
	-- faixa lateral pre-calculada no normalize (|uY - y| <= LANE_REACH, sem chamada no laco)
	local yLo, yHi = trap.yLo, trap.yHi
	local currentShotId = shotId
	if currentShotId == nil then
		self.nextShotId += 1
		currentShotId = self.nextShotId
	end
	local boss = self.boss
	local canHitBoss = boss ~= nil and bossInTrapRange(trap, def, boss)

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
		if canHitBoss then
			-- Passa pelas 3 lanes ocupadas pelo Boss, mas deduplica por shotId para garantir
			-- exatamente 1 aplicacao de dano por disparo de AoE!
			local laneLo = math.max(1, boss.laneCenter - 1)
			local laneHi = math.min(Core.GRID_HEIGHT, boss.laneCenter + 1)
			for lane = laneLo, laneHi do
				local ly = Core.laneY(lane)
				if ly >= yLo and ly <= yHi then
					if hitBossWithShot(self, trap, def, damage, currentShotId) then
						hitAny = true
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

	if canHitBoss then
		if best == nil or boss.state == "VULNERABLE" or boss.x <= bestX then
			return hitBossWithShot(self, trap, def, damage, currentShotId)
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

function Battle:executeBossAbility()
	local boss = self.boss
	if boss == nil or not boss.alive then
		return
	end
	local id = boss.bossId
	if id == "iron_ram_colossus" then
		local advance = if boss.enraged then 1200 else 600
		boss.x = math.max(0, boss.x - advance)
		local centerY = Core.laneY(boss.laneCenter)
		for _, trap in ipairs(self.traps) do
			if trap.x <= 2500 and math.abs(trap.y - centerY) <= ARENA.laneReach then
				trap.jamUntil = math.max(trap.jamUntil or 0, self.tick + 120)
			end
		end
		if boss.x <= 0 then
			self.leaked += 1
			self.wallHp = 0
		end
	elseif id == "slag_juggernaut" then
		boss.tempArmorBonusMilli = 200
		boss.tempArmorTicksLeft = 80
		boss.armorMilli =
			clampInt(boss.baseArmorMilli + boss.tempArmorBonusMilli, 0, Core.MAX_ARMOR_MILLI)
		local spawnX = math.min(ARENA.spawnX, math.max(1500, boss.x + 400))
		self:spawnConfiguredUnit("brute", math.max(1, boss.laneCenter - 1), false, spawnX, false)
		self:spawnConfiguredUnit(
			"brute",
			math.min(Core.GRID_HEIGHT, boss.laneCenter + 1),
			false,
			spawnX,
			false
		)
	elseif id == "rime_matriarch" then
		local freezeCount = if boss.enraged then 3 else 2
		local nTraps = #self.traps
		if nTraps > 0 then
			local startIdx = self.rng:int(nTraps)
			for k = 0, math.min(freezeCount, nTraps) - 1 do
				local idx = ((startIdx + k - 1) % nTraps) + 1
				local trap = self.traps[idx]
				trap.frostSlowUntil = math.max(trap.frostSlowUntil or 0, self.tick + 60)
			end
		end
		local swarmPairs = if boss.enraged then 2 else 1
		for _ = 1, swarmPairs do
			self:spawnConfiguredUnit("swarm", 1, false, ARENA.spawnX, false)
			self:spawnConfiguredUnit("swarm", Core.GRID_HEIGHT, false, ARENA.spawnX, false)
		end
	elseif id == "powder_baron" then
		for _, trap in ipairs(self.traps) do
			if trap.x >= 4500 and trap.x <= 7000 then
				trap.jamUntil = math.max(trap.jamUntil or 0, self.tick + 50)
			end
		end
		local oppLane = clampInt(6 - boss.laneCenter, 1, Core.GRID_HEIGHT)
		self:spawnConfiguredUnit("runner", oppLane, false, ARENA.spawnX, false)
		if boss.enraged then
			self:spawnConfiguredUnit("runner", 1, false, ARENA.spawnX, false)
			self:spawnConfiguredUnit("runner", Core.GRID_HEIGHT, false, ARENA.spawnX, false)
		end
	elseif id == "rift_titan" then
		boss.laneCenter = if boss.laneCenter == 2 then 4 else 2
		boss.subportalTicksLeft = 100
		self:spawnConfiguredUnit("swarm", boss.laneCenter, false, 6500, false)
		self:spawnConfiguredUnit("runner", math.max(1, boss.laneCenter - 1), false, 6500, false)
	end
end

function Battle:stepBoss()
	local boss = self.boss
	if boss == nil or not boss.alive or boss.hp <= 0 then
		return
	end
	if self.tick < boss.spawnTick and boss.x >= ARENA.spawnX then
		return
	end

	if boss.tempArmorTicksLeft > 0 then
		boss.tempArmorTicksLeft -= 1
		if boss.tempArmorTicksLeft <= 0 then
			boss.tempArmorBonusMilli = 0
		end
	end
	boss.armorMilli =
		clampInt(boss.baseArmorMilli + boss.tempArmorBonusMilli, 0, Core.MAX_ARMOR_MILLI)

	if boss.subportalTicksLeft > 0 then
		boss.subportalTicksLeft -= 1
		if boss.subportalTicksLeft > 0 and boss.subportalTicksLeft % 25 == 0 then
			self:spawnConfiguredUnit("swarm", boss.laneCenter, false, 6500, false)
		end
	end

	if not boss.enraged and boss.hp * 1000 < boss.maxHp * 400 then
		boss.enraged = true
	end

	if boss.state == "VULNERABLE" then
		boss.stateTicksLeft -= 1
		if boss.stateTicksLeft <= 0 then
			boss.staggerMilli = 0
			boss.state = "MARCH"
			boss.stateTicksLeft = 0
		end
		return
	end

	if boss.state == "TELEGRAPH" then
		boss.stateTicksLeft -= 1
		if boss.stateTicksLeft <= 0 then
			boss.state = "ABILITY"
			boss.stateTicksLeft = 1
			self:executeBossAbility()
		end
		return
	end

	if boss.state == "ABILITY" then
		boss.stateTicksLeft -= 1
		if boss.stateTicksLeft <= 0 then
			boss.state = "MARCH"
			boss.stateTicksLeft = 0
			local cd = boss.baseAbilityCdTicks
			if boss.enraged then
				cd = math.floor(cd * 750 / 1000)
			end
			boss.abilityCooldownTicks = math.max(30, cd)
		end
		return
	end

	-- Estado MARCH
	if boss.abilityCooldownTicks > 0 then
		boss.abilityCooldownTicks -= 1
	end
	if boss.abilityCooldownTicks <= 0 then
		boss.state = "TELEGRAPH"
		boss.stateTicksLeft = 40
		return
	end

	local effSpeedMilli = boss.speedMilli + (if boss.enraged then 200 else 0)
	effSpeedMilli = clampInt(
		math.floor(effSpeedMilli * self.speedScaleMilli / MILLI),
		100,
		Core.MAX_SPEED_MILLI
	)
	local speedTick = math.max(5, math.floor(effSpeedMilli / Core.TICK_HZ))
	if self.tick <= boss.slowUntil then
		speedTick = math.max(3, math.floor(speedTick * boss.slowPct / 100))
	end
	boss.x -= speedTick
	if boss.x <= 0 then
		boss.x = 0
		self.leaked += 1
		self.wallHp = 0
	end
end

function Battle:BossSnapshot()
	local b = self.boss
	if b == nil then
		return nil
	end
	return {
		bossId = b.bossId,
		hp = b.hp,
		maxHp = b.maxHp,
		x = b.x,
		laneCenter = b.laneCenter,
		laneSpan = b.laneSpan,
		armorMilli = b.armorMilli,
		staggerMilli = b.staggerMilli,
		staggerCapMilli = b.staggerCapMilli,
		state = b.state,
		stateTicksLeft = b.stateTicksLeft,
		enraged = b.enraged,
		alive = b.alive,
	}
end

function Battle:Step()
	self.tick += 1

	if not self.hasWaveExtensions then
		-- Caminho P1/P2 padrao 100% preservado (hash seed 42 == 1245379674)
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
		return
	end

	-- Caminho estendido v7 (Campanha, WaveSliceSpec, Mutadores, Pool e Bosses)
	if self.slices ~= nil then
		for _, slice in ipairs(self.slices) do
			if slice.spawned < slice.count and self.tick >= slice.startTick then
				local elapsed = self.tick - slice.startTick
				if elapsed % slice.everyTicks == 0 then
					slice.spawned += 1
					self.spawned += 1
					local lane = slice.lanes[((slice.spawned - 1) % #slice.lanes) + 1]
					self:spawnConfiguredUnit(slice.unit, lane, slice.isElite, ARENA.spawnX, false)
				end
			end
		end
	else
		if self.spawned < self.toSpawn then
			self.spawnTimer += 1
			if self.spawnTimer >= self.spawnEvery then
				self.spawnTimer = 0
				local lane = self.rng:int(Core.GRID_HEIGHT)
				local pool = self.unitPool or UNIT_NAMES
				local tname = pool[self.rng:int(#pool)]
				self:spawnConfiguredUnit(tname, lane, false, ARENA.spawnX, true)
				self.spawned += 1
			end
		end
	end

	for _, trap in ipairs(self.traps) do
		local jammed = trap.jamUntil ~= nil and self.tick <= trap.jamUntil
		if not jammed then
			if trap.cd > 0 then
				trap.cd -= 1
			end
			if trap.cd <= 0 then
				self.nextShotId += 1
				if self:applyTrap(trap, self.nextShotId) then
					local cd = trap.baseCd
					if trap.frostSlowUntil ~= nil and self.tick <= trap.frostSlowUntil then
						cd = math.floor(cd * 1400 / MILLI)
					end
					trap.cd = cd
				end
			end
		end
	end

	self:stepBoss()

	local leakScalePct = Core.TUNING.leakScalePct
	local riftEnrageAura = self.boss ~= nil
		and self.boss.alive
		and self.boss.bossId == "rift_titan"
		and self.boss.enraged
	for i = self.aliveLo, self.uCount do
		if self.uHp[i] > 0 then
			local speed = self.uBaseSpeed[i]
			if riftEnrageAura then
				speed = math.min(240, speed + 8)
			end
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

	local acc = bit32.band(math.floor(math.max(0, self.wallHp) / MILLI), 0xFFFFFFFF)
	acc = bit32.bxor(acc, bit32.band(self.uCount, 0xFFFF))
	acc = bit32.bxor(acc, bit32.band(self.killed, 0xFFFF))
	acc = bit32.bxor(acc, bit32.band(self.leaked, 0xFFFF))
	if self.boss ~= nil then
		acc = bit32.bxor(acc, bit32.band(math.floor(self.boss.hp / MILLI), 0xFFFF))
		acc = bit32.bxor(acc, bit32.band(self.boss.x, 0xFFFF))
		acc = bit32.bxor(acc, bit32.band(self.boss.staggerMilli, 0xFFFF))
	end
	self.hash = mul32(bit32.bxor(self.hash, acc), 16777619)
end

function Battle:Finished()
	if self.wallHp <= 0 or self.tick >= Core.MAX_TICKS then
		return true
	end
	if self.boss ~= nil then
		if
			not self.boss.alive
			and self.boss.hp <= 0
			and self.spawned >= self.toSpawn
			and self.aliveLo > self.uCount
		then
			return true
		end
	elseif self.slices ~= nil then
		if self.tick > 1 and self.spawned >= self.toSpawn and self.aliveLo > self.uCount then
			return true
		end
	end
	return false
end

function Battle:Result()
	local defenderWon = self.wallHp > 0
	if self.boss ~= nil and (self.boss.alive or self.boss.hp > 0) then
		defenderWon = false
	end
	local res = {
		winner = defenderWon and "defender" or "attacker",
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
	if self.boss ~= nil then
		res.boss = self:BossSnapshot()
	end
	return res
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
			self.uArmorMilli[i] or 0,
			self.uFrostResistMilli[i] or 0,
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
	if self.boss ~= nil then
		local b = self.boss
		for _, v in ipairs({
			b.hp,
			b.maxHp,
			b.x,
			b.laneCenter,
			b.laneSpan,
			b.armorMilli,
			b.staggerMilli,
			b.staggerCapMilli,
			b.stateTicksLeft,
			b.abilityCooldownTicks,
		}) do
			if v ~= math.floor(v) then
				return false, -999
			end
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
