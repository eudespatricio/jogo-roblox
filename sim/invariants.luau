--!nonstrict
-- Invariantes executaveis da Muralha (matematica v7: posicoes livres, Nv1..Nv5, L1..L5,
-- disparo real, sinergias, 6 tipos de horda, 8 mutadores e 5 Bosses Multi-Lane FSM).
-- Roda no Luau CLI e falha o processo se qualquer regra de negocio for violada:
--   luau sim/invariants.luau
local Core = require("../src/shared/sim/core")

local failures = {}
local checks = 0

local function check(name, fn)
	checks += 1
	local ok, err = pcall(fn)
	if not ok then
		failures[#failures + 1] = name .. " :: " .. tostring(err)
	end
end

-- referencia exata de multiplicacao 32-bit (limbs de 8 bits)
local function mul32Ref(a, b)
	local result = 0
	for i = 0, 3 do
		local ai = bit32.band(bit32.rshift(a, 8 * i), 0xFF)
		for j = 0, 3 do
			local bj = bit32.band(bit32.rshift(b, 8 * j), 0xFF)
			if ai ~= 0 and bj ~= 0 and i + j < 4 then
				result = (result + ai * bj * 2 ^ (8 * (i + j))) % 4294967296
			end
		end
	end
	return result
end

-- I1: multiplicacao 32-bit exata
check("I1 mul32 identidade", function()
	assert(Core.mul32(1, 123456789) == 123456789, "1*x != x")
	assert(Core.mul32(0xFFFFFFFF, 0xFFFFFFFF) == 1, "(-1)*(-1) != 1")
	assert(Core.mul32(0x80000000, 2) == 0, "2^31*2 != 0")
end)

check("I1b mul32 vs referencia (5.000 pares)", function()
	local seed = 7
	local function rnd()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed
	end
	for _ = 1, 5000 do
		local a = rnd() * 2048 % 4294967296
		local b = rnd() * 2048 % 4294967296
		assert(Core.mul32(a, b) == mul32Ref(a, b), "divergiu em " .. a .. " x " .. b)
	end
end)

-- I2: RNG reproduzivel
check("I2 RNG determinista", function()
	local a = Core.RNG.new(12345)
	local b = Core.RNG.new(12345)
	for _ = 1, 500 do
		assert(a:nextU32() == b:nextU32(), "streams divergiram")
	end
	assert(a:nextU32() ~= Core.RNG.new(12346):nextU32(), "seeds diferentes geraram mesma saida")
end)

-- I3: batalha reproduzivel
check("I3 batalha determinista (20 seeds x2)", function()
	for seed = 1, 20 do
		local h1 = Core.Run(seed).hash
		local h2 = Core.Run(seed).hash
		assert(h1 == h2, "hash divergiu para seed " .. seed)
	end
end)

-- I4: estado 100% inteiro durante a batalha
check("I4 estado inteiro", function()
	for seed = 1, 20 do
		local battle = Core.Battle.new({
			seed = seed,
			simVersion = Core.SIM_VERSION,
			wall = Core.defaultWall(),
			wave = { count = 80 },
		})
		while not battle:Finished() do
			battle:Step()
			local ok = battle:CheckIntegers()
			assert(ok, "valor fracionario na seed " .. seed)
		end
	end
end)

-- I5: invariantes de resultado
check("I5 resultado consistente", function()
	for seed = 1, 100 do
		local r = Core.Run(seed)
		assert(r.winner == "defender" or r.winner == "attacker", "vencedor invalido")
		assert(r.wallHp >= 0, "wallHp negativo")
		assert(r.ticks > 0 and r.ticks <= Core.MAX_TICKS, "ticks fora do cap")
		assert(r.spawned <= 70, "spawnou mais que a onda")
		assert(r.traps == 5, "loadout padrao deveria ter 5 ativas")
		assert(r.simVersion == 7, "simVersion deveria ser 7")
		assert(r.hash == math.floor(r.hash), "hash fracionario")
	end
end)

-- I6: cap de 60s e soberano (muralha impossivel de derrubar -> para no cap)
check("I6 cap de 1200 ticks", function()
	local r = Core.Run(42, 500, 100000)
	assert(r.ticks == Core.MAX_TICKS, "nao parou no cap: " .. r.ticks)
end)

-- I7: onda maior nao pode facilitar a vida do defensor
check("I7 monotonicidade de dificuldade", function()
	local small, big = 0, 0
	for seed = 1, 100 do
		if Core.Run(seed, 50).winner == "defender" then
			small += 1
		end
		if Core.Run(seed, 80).winner == "defender" then
			big += 1
		end
	end
	assert(small >= big, "onda de 80 venceu mais que a de 50")
end)

-- I8: faixa de balanceamento (guarda contra quebra catastrofica, nao prova diversao)
check("I8 faixa de vitoria 25-90%", function()
	local wins = 0
	for seed = 1, 200 do
		if Core.Run(seed, 70).winner == "defender" then
			wins += 1
		end
	end
	local pct = wins / 200 * 100
	assert(pct >= 25 and pct <= 90, "fora da faixa: " .. pct .. "%")
end)

-- I9: sem NaN em fuzz
check("I9 sem NaN", function()
	local rng = Core.RNG.new(999)
	for _ = 1, 300 do
		local wave = 30 + rng:int(60)
		local r = Core.Run(rng:int(1000000), wave, 400 + rng:int(200))
		assert(r.wallHp == r.wallHp, "NaN em wallHp")
		assert(r.ticks > 0, "ticks invalido")
	end
end)

-- I10: grade 5x5, N=5 e colocacao livre (5 armadilhas na mesma lane)
check("I10 loadout 5x5 livre", function()
	assert(Core.GRID_WIDTH == 5 and Core.GRID_HEIGHT == 5, "grade != 5x5")
	assert(Core.ACTIVE_TRAP_LIMIT == 5, "N != 5")
	local traps = {}
	for col = 1, Core.GRID_WIDTH do
		traps[#traps + 1] = { cell = "r3c" .. col, type = "archer", level = 1 }
	end
	local wall = { hp = 500, traps = traps }
	local function runBattle()
		return Core.Battle
			.new({
				seed = 42,
				simVersion = Core.SIM_VERSION,
				wall = wall,
				wave = { count = 70 },
			})
			:Run()
	end
	local a = runBattle()
	local b = runBattle()
	assert(a.hash == b.hash, "loadout livre nao reproduziu o hash")
	assert(a.traps == 5, "loadout livre perdeu armadilhas: " .. tostring(a.traps))
	assert(a.ticks > 0 and a.ticks <= Core.MAX_TICKS, "ticks fora do cap")
end)

-- I11: loadout invalido e recusado (celula, N, tipo, nivel e replay antigo)
check("I11 loadout invalido e recusado", function()
	local function rejects(wall, simVersion)
		local ok = pcall(function()
			Core.Battle.new({
				seed = 1,
				simVersion = simVersion or Core.SIM_VERSION,
				wall = wall,
				wave = { count = 70 },
			})
		end)
		assert(not ok, "aceitou loadout invalido")
	end

	rejects({ traps = { { cell = "r6c1", type = "archer" } } })
	rejects({
		traps = {
			{ cell = "r1c1", type = "archer" },
			{ cell = "r1c1", type = "archer" },
		},
	})
	rejects({ traps = { { cell = "r1c6", type = "archer" } } })
	rejects({ traps = { { cell = "r01c1", type = "archer" } } })
	rejects({ traps = { r1c1 = { type = "archer" } } })
	rejects({ traps = { { cell = "r1c1", type = "wizard" } } })
	rejects({ traps = { { cell = "r1c1", type = "archer", level = 6 } } })
	rejects({ traps = {} }, 1)

	local six = { traps = {} }
	for col = 1, 5 do
		six.traps[#six.traps + 1] = { cell = "r1c" .. col, type = "archer" }
	end
	six.traps[#six.traps + 1] = { cell = "r2c1", type = "archer" }
	rejects(six)

	local empty = Core.Battle.new({
		seed = 1,
		simVersion = Core.SIM_VERSION,
		wall = { traps = {} },
		wave = { count = 70 },
	})
	assert(empty:Run().traps == 0, "parede sem armadilhas deveria rodar")
end)

-- I12: disparo real, slow parametrizado/splash e sinergias espaciais
check("I12 disparo real, slow e sinergias espaciais", function()
	Core.setTuning({ powerPct = 50 })
	local ok, err = pcall(function()
		local probe = Core.Battle.new({
			seed = 1,
			simVersion = Core.SIM_VERSION,
			wall = { traps = {} },
			wave = { count = 1, spawnEveryTicks = 1 },
		})
		probe:Step()
		local lane = probe.uLane[1]
		local startHp = probe.uHp[1]
		local baseSpeed = probe.uBaseSpeed[1]

		-- 1) Disparo real: cannon em c1 (x=2000, range=2200 -> uX<=4200) nao gasta cd no vazio
		local smart = Core.Battle.new({
			seed = 1,
			simVersion = Core.SIM_VERSION,
			wall = {
				traps = { { cell = string.format("r%dc1", lane), type = "cannon", level = 1 } },
			},
			wave = { count = 1, spawnEveryTicks = 1 },
		})
		local firedTick = nil
		for _ = 1, 100 do
			smart:Step()
			if smart.traps[1].cd > 0 then
				firedTick = smart.tick
				break
			end
			assert(smart.traps[1].cd == 0, "cannon gastou cd sem alvo")
			assert(smart.uHp[1] == startHp, "dano sem disparo")
		end
		assert(firedTick ~= nil and firedTick > 10, "cannon deveria esperar alvo entrar no alcance")
		assert(smart.traps[1].cd == smart.traps[1].baseCd, "cd nao resetou para baseCd")
		local cannonDmg = startHp - smart.uHp[1]
		assert(cannonDmg > 0, "cannon nao causou dano ao disparar")

		-- 2) Bateria Cruzada: archer ortogonalmente adjacente -1t cd, cap -2t, piso 8t
		local soloArcher = Core.Battle.new({
			seed = 1,
			simVersion = Core.SIM_VERSION,
			wall = { traps = { { cell = "r1c1", type = "archer", level = 1 } } },
			wave = { count = 0 },
		})
		assert(soloArcher.traps[1].baseCd == 10, "archer isolada baseCd != 10")

		local crossBattery = Core.Battle.new({
			seed = 1,
			simVersion = Core.SIM_VERSION,
			wall = {
				traps = {
					{ cell = "r2c2", type = "archer", level = 1 },
					{ cell = "r1c2", type = "archer", level = 1 },
					{ cell = "r3c2", type = "archer", level = 1 },
					{ cell = "r2c1", type = "archer", level = 1 },
					{ cell = "r2c3", type = "archer", level = 1 },
				},
			},
			wave = { count = 0 },
		})
		-- v5: ordem canonica (y, x) -> [1]=r1c2, [2]=r2c1, [3]=r2c2 (centro), [4]=r2c3, [5]=r3c2
		assert(crossBattery.traps[3].baseCd == 8, "centro da cruz deveria bater cap/piso 8t")
		assert(crossBattery.traps[1].baseCd == 9, "vizinho com 1 archer deveria ter baseCd 9t")

		-- 3) Piche Incendiario: tar marca uTarUntil=tick+30; cannon e catapult causam *1250/1000
		local tarOnly = Core.Battle.new({
			seed = 1,
			simVersion = Core.SIM_VERSION,
			wall = { traps = { { cell = string.format("r%dc5", lane), type = "tar", level = 1 } } },
			wave = { count = 1, spawnEveryTicks = 1 },
		})
		while (tarOnly.uTarUntil[1] or 0) == 0 and tarOnly.tick < 50 do
			tarOnly:Step()
		end
		assert(tarOnly.uTarUntil[1] == tarOnly.tick + 30, "tar nao aplicou uTarUntil=tick+30")

		local tarCannon = Core.Battle.new({
			seed = 1,
			simVersion = Core.SIM_VERSION,
			-- v5: ordem canonica (y, x) poe o cannon (c3) antes do tar (c5) -> traps[1]
			wall = {
				traps = {
					{ cell = string.format("r%dc5", lane), type = "tar", level = 1 },
					{ cell = string.format("r%dc3", lane), type = "cannon", level = 1 },
				},
			},
			wave = { count = 1, spawnEveryTicks = 1 },
		})
		local prevHp = startHp
		while tarCannon.traps[1].cd == 0 and tarCannon.tick < 100 do
			prevHp = tarCannon.uHp[1] or startHp
			tarCannon:Step()
		end
		assert(tarCannon.traps[1].cd > 0, "cannon nao disparou com tar")
		assert(tarCannon.tick <= tarCannon.uTarUntil[1], "uTarUntil expirou antes do cannon")
		local tarCannonHit = prevHp - tarCannon.uHp[1]
		assert(
			tarCannonHit == math.floor(cannonDmg * 1250 / 1000),
			"Piche Incendiario (cannon) divergiu: " .. tostring(tarCannonHit)
		)

		local catapultOnly = Core.Battle.new({
			seed = 1,
			simVersion = Core.SIM_VERSION,
			wall = {
				traps = { { cell = string.format("r%dc3", lane), type = "catapult", level = 1 } },
			},
			wave = { count = 1, spawnEveryTicks = 1 },
		})
		while catapultOnly.traps[1].cd == 0 and catapultOnly.tick < 100 do
			catapultOnly:Step()
		end
		local catapultDmg = startHp - catapultOnly.uHp[1]

		local tarCatapult = Core.Battle.new({
			seed = 1,
			simVersion = Core.SIM_VERSION,
			wall = {
				traps = {
					{ cell = string.format("r%dc5", lane), type = "tar", level = 1 },
					{ cell = string.format("r%dc3", lane), type = "catapult", level = 1 },
				},
			},
			wave = { count = 1, spawnEveryTicks = 1 },
		})
		prevHp = startHp
		while tarCatapult.traps[1].cd == 0 and tarCatapult.tick < 100 do
			prevHp = tarCatapult.uHp[1] or startHp
			tarCatapult:Step()
		end
		assert(tarCatapult.traps[1].cd > 0, "catapult nao disparou com tar")
		assert(tarCatapult.tick <= tarCatapult.uTarUntil[1], "uTarUntil expirou antes da catapult")
		local tarCatapultHit = prevHp - tarCatapult.uHp[1]
		assert(
			tarCatapultHit == math.floor(catapultDmg * 1250 / 1000),
			"Piche Incendiario (catapult) divergiu: " .. tostring(tarCatapultHit)
		)

		-- 4) Choque Termico + uSlowPct: frost marca uFrostUntil, cannon causa *1200/1000 sem consumir slow
		local frostCannon = Core.Battle.new({
			seed = 1,
			simVersion = Core.SIM_VERSION,
			wall = {
				traps = {
					{ cell = string.format("r%dc5", lane), type = "frost", level = 1 },
					{ cell = string.format("r%dc4", lane), type = "cannon", level = 1 },
				},
			},
			wave = { count = 1, spawnEveryTicks = 1 },
		})
		frostCannon:Step()
		assert(
			frostCannon.uSlowUntil[1] == 1 + Core.TRAP.frost.slowTicks,
			"frost nao aplicou uSlowUntil"
		)
		assert(frostCannon.uSlowPct[1] == Core.TRAP.frost.slowPct, "frost nao gravou uSlowPct")
		assert(
			frostCannon.uFrostUntil[1] == 1 + Core.TRAP.frost.slowTicks,
			"frost nao gravou uFrostUntil"
		)
		assert(
			frostCannon.uX[1] == 10000 - math.floor(baseSpeed * Core.TRAP.frost.slowPct / 100),
			"velocidade com uSlowPct incorreta"
		)
		prevHp = frostCannon.uHp[1]
		while frostCannon.traps[1].cd == 0 and frostCannon.tick < 100 do
			prevHp = frostCannon.uHp[1]
			frostCannon:Step()
		end
		assert(frostCannon.traps[1].cd > 0, "cannon nao disparou com frost")
		assert(
			frostCannon.uSlowUntil[1] >= frostCannon.tick,
			"slow nao deve ser consumido pelo cannon"
		)
		assert(frostCannon.uFrostUntil[1] >= frostCannon.tick, "uFrostUntil nao deve ser consumido")
		local frostCannonHit = prevHp - frostCannon.uHp[1]
		assert(
			frostCannonHit == math.floor(cannonDmg * 1200 / 1000),
			"Choque Termico divergiu: " .. tostring(frostCannonHit)
		)
	end)
	Core.setTuning({ powerPct = Core.DEFAULT_POWER_PCT })
	assert(ok, err)
end)

-- I13: imutabilidade de tabelas estaticas e Core.setTuning
check("I13 tabelas congeladas e Core.setTuning", function()
	assert(table.isfrozen(Core.UNIT), "Core.UNIT nao congelada")
	assert(table.isfrozen(Core.UNIT.runner), "Core.UNIT.runner nao congelada")
	assert(table.isfrozen(Core.ALL_UNIT_NAMES), "Core.ALL_UNIT_NAMES nao congelada")
	assert(table.isfrozen(Core.TRAP), "Core.TRAP nao congelada")
	assert(table.isfrozen(Core.TRAP.archer), "Core.TRAP.archer nao congelada")
	assert(table.isfrozen(Core.TRAP_NAMES), "Core.TRAP_NAMES nao congelada")
	assert(table.isfrozen(Core.TUNING), "Core.TUNING nao congelada")

	assert(not pcall(function()
		Core.TRAP.oil = Core.TRAP.tar
	end), "permitiu mutar Core.TRAP")
	assert(not pcall(function()
		Core.TRAP.archer.dmg = 1
	end), "permitiu mutar Core.TRAP.archer")
	assert(not pcall(function()
		Core.TUNING.powerPct = 1
	end), "permitiu mutar Core.TUNING")

	local baseHash = Core.Run(42).hash
	local updated = Core.setTuning({ powerPct = 150 })
	assert(updated.powerPct == 150 and Core.TUNING.powerPct == 150, "setTuning nao atualizou")
	assert(table.isfrozen(Core.TUNING), "novo Core.TUNING nao congelado")
	local tunedHash = Core.Run(42).hash
	assert(tunedHash ~= baseHash, "setTuning nao refletiu ao vivo no motor")

	Core.setTuning({ powerPct = Core.DEFAULT_POWER_PCT })
	assert(Core.Run(42).hash == baseHash, "restaurar DEFAULT_POWER_PCT mudou hash")

	assert(not pcall(Core.setTuning, { powerPct = 0 }), "aceitou powerPct=0")
	assert(not pcall(Core.setTuning, { powerPct = 1.5 }), "aceitou powerPct fracionario")
	assert(not pcall(Core.setTuning, { leakScalePct = -1 }), "aceitou leakScalePct negativo")
end)

-- I15 (v5): colocacao livre — posicao/grade/espacamento, ordem canonica e alcance lateral
check("I15 colocacao livre (posicao, espacamento, ordem, alcance lateral)", function()
	local function battle(traps, count)
		return Core.Battle.new({
			seed = 7,
			simVersion = Core.SIM_VERSION,
			wall = { traps = traps },
			wave = { count = count or 0 },
		})
	end
	-- celula legada == centro da celula
	local cx, cy = Core.cellToPos("r2c3")
	assert(cx == 5000 and cy == 1500, "cellToPos r2c3 != (5000,1500)")
	assert(Core.posToCell(5000, 1500) == "r2c3", "posToCell nao inverte")
	assert(Core.posToCell(5250, 1500) == nil, "posToCell aceitou fora do centro")
	local byCell = Core.Run(42).hash
	local posWall = Core.defaultWall()
	for _, trap in ipairs(posWall.traps) do
		trap.cell = nil
	end
	local byPos = Core.Battle
		.new({ seed = 42, simVersion = Core.SIM_VERSION, wall = posWall, wave = { count = 70 } })
		:Run().hash
	assert(byPos == byCell, "posicao do centro divergiu da celula legada")
	-- ordem de entrada nao muda o replay
	local shuffled = Core.defaultWall()
	local rev = {}
	for i = #shuffled.traps, 1, -1 do
		rev[#rev + 1] = shuffled.traps[i]
	end
	shuffled.traps = rev
	local byRev = Core.Battle
		.new({ seed = 42, simVersion = Core.SIM_VERSION, wall = shuffled, wave = { count = 70 } })
		:Run().hash
	assert(byRev == byCell, "ordem de entrada mudou o hash")
	-- validacao: limites, grade, espacamento, cell x posicao
	assert(not pcall(battle, { { type = "archer", x = 900, y = 500 } }), "aceitou x < xMin")
	assert(not pcall(battle, { { type = "archer", x = 9250, y = 500 } }), "aceitou x > xMax")
	assert(not pcall(battle, { { type = "archer", x = 5000, y = 4750 } }), "aceitou y > yMax")
	assert(not pcall(battle, { { type = "archer", x = 5100, y = 500 } }), "aceitou fora da grade")
	assert(not pcall(battle, { { type = "archer", x = 5000.5, y = 500 } }), "aceitou float")
	assert(
		not pcall(
			battle,
			{ { type = "archer", x = 5000, y = 500 }, { type = "frost", x = 5750, y = 1250 } }
		),
		"aceitou espacamento < minSpacing"
	)
	assert(
		pcall(
			battle,
			{ { type = "archer", x = 5000, y = 500 }, { type = "frost", x = 6000, y = 1250 } }
		),
		"recusou espacamento == minSpacing"
	)
	assert(
		not pcall(battle, { { cell = "r1c1", type = "archer", x = 3500, y = 500 } }),
		"aceitou cell e posicao divergentes"
	)
	-- alcance lateral: centro da lane alcanca so a lane; divisa alcanca as duas
	local center = battle({ { type = "cannon", x = 2000, y = 1500 } })
	local border = battle({ { type = "cannon", x = 2000, y = 1000 } })
	for _, b in ipairs({ center, border }) do
		b.uCount = 2
		for i, lane in ipairs({ 1, 2 }) do
			b.uHp[i] = 1000 * Core.MILLI
			b.uX[i] = 3500
			b.uY[i] = Core.laneY(lane)
			b.uLane[i] = lane
			b.uBaseSpeed[i] = 0
			b.uSlowUntil[i], b.uSlowPct[i], b.uTarUntil[i], b.uFrostUntil[i] = 0, 100, 0, 0
			b.uLeak[i] = 0
		end
	end
	assert(center:applyTrap(center.traps[1]), "centro nao disparou")
	assert(
		center.uHp[1] == 1000 * Core.MILLI and center.uHp[2] < 1000 * Core.MILLI,
		"centro errou a lane"
	)
	-- v6: archer atinge area circular 360 graus (omni), inclusive em lane vizinha e atras
	local omni = battle({ { type = "archer", x = 5000, y = 2500 } })
	omni.uCount = 2
	omni.uHp[1], omni.uX[1], omni.uY[1], omni.uLane[1] = 1000 * Core.MILLI, 2000, 500, 1
	omni.uHp[2], omni.uX[2], omni.uY[2], omni.uLane[2] = 1000 * Core.MILLI, 3500, 1500, 2
	for i = 1, 2 do
		omni.uBaseSpeed[i] = 0
		omni.uSlowUntil[i], omni.uSlowPct[i], omni.uTarUntil[i], omni.uFrostUntil[i] = 0, 100, 0, 0
		omni.uLeak[i] = 0
	end
	assert(omni:applyTrap(omni.traps[1]), "archer omni nao disparou em area 360")
	assert(
		omni.uHp[1] == 1000 * Core.MILLI and omni.uHp[2] < 1000 * Core.MILLI,
		"archer omni deveria atingir unidade dentro do raio 360 e ignorar fora do raio"
	)
	local splash = battle({ { type = "catapult", x = 2000, y = 1000 } })
	splash.uCount = 2
	for i, lane in ipairs({ 1, 2 }) do
		splash.uHp[i] = 1000 * Core.MILLI
		splash.uX[i] = 4000
		splash.uY[i] = Core.laneY(lane)
		splash.uLane[i] = lane
		splash.uTarUntil[i], splash.uFrostUntil[i], splash.uSlowUntil[i], splash.uSlowPct[i] =
			0, 0, 0, 100
	end
	assert(splash:applyTrap(splash.traps[1]), "catapult na divisa nao disparou")
	assert(
		splash.uHp[1] < 1000 * Core.MILLI and splash.uHp[2] < 1000 * Core.MILLI,
		"catapult na divisa deveria alcancar as duas lanes"
	)
	local ok, idx = border:CheckIntegers()
	assert(ok, "inteiros quebrados " .. tostring(idx))
end)

-- I16 (v5): muralha Nv1..Nv5 (hp/limite) e armadilhas L1..L5
check("I16 muralha Nv1..Nv5 e armadilhas L4/L5", function()
	local expected = { { 500, 5 }, { 650, 5 }, { 800, 6 }, { 1000, 6 }, { 1250, 7 } }
	assert(#Core.WALL_LEVELS == 5 and table.isfrozen(Core.WALL_LEVELS), "WALL_LEVELS")
	for lvl, pair in ipairs(expected) do
		local def = Core.WALL_LEVELS[lvl]
		assert(def.hp == pair[1] and def.trapLimit == pair[2], "Nv" .. lvl .. " divergiu")
		local b = Core.Battle.new({
			seed = 1,
			simVersion = Core.SIM_VERSION,
			wall = { level = lvl, traps = {} },
			wave = { count = 0 },
		})
		assert(b.wallHp == pair[1] * Core.MILLI, "hp do Nv" .. lvl .. " nao aplicado")
	end
	local function traps(n)
		local list = {}
		for i = 1, n do
			list[i] = { type = "archer", x = 1000 + (i - 1) * 1000, y = 500 }
		end
		return list
	end
	local function build(level, n)
		return Core.Battle.new({
			seed = 1,
			simVersion = Core.SIM_VERSION,
			wall = { level = level, traps = traps(n) },
			wave = { count = 0 },
		})
	end
	assert(pcall(build, 1, 5) and not pcall(build, 1, 6), "Nv1 limite 5")
	assert(pcall(build, 3, 6) and not pcall(build, 3, 7), "Nv3 limite 6")
	assert(pcall(build, 5, 7) and not pcall(build, 5, 8), "Nv5 limite 7")
	assert(not pcall(build, 6, 1) and not pcall(build, 0, 1), "aceitou Nv fora de [1,5]")
	-- L1..L3 iguais a v4 (100/120/140, sem bonus de cd); L4/L5 novos
	local function trapAt(level)
		return Core.Battle.new({
			seed = 1,
			simVersion = Core.SIM_VERSION,
			wall = { traps = { { type = "cannon", level = level, x = 5000, y = 500 } } },
			wave = { count = 0 },
		}).traps[1]
	end
	assert(
		trapAt(3).baseCd == 28 and trapAt(4).baseCd == 27 and trapAt(5).baseCd == 26,
		"cd L3..L5"
	)
	assert(not pcall(trapAt, 6), "aceitou L6")
	local pct = Core.LEVEL_DMG_PCT
	assert(pct[1] == 100 and pct[2] == 120 and pct[3] == 140, "L1..L3 mudaram")
	assert(pct[4] > pct[3] and pct[5] > pct[4], "L4/L5 nao escalam")
	assert(Core.validateWall(Core.defaultWall()), "validateWall recusou defaultWall")
	assert(not Core.validateWall({ level = 1, traps = traps(6) }), "validateWall aceitou 6 no Nv1")
end)

-- I17 (v7): 6 arquetipos de unidade, armorMilli, frostResistMilli e WaveSliceSpec
check("I17 6 arquetipos de unidade, mitigacao de armadura e WaveSliceSpec", function()
	assert(#Core.UNIT_NAMES == 3, "UNIT_NAMES padrao P1 deve continuar com 3 tipos")
	assert(#Core.ALL_UNIT_NAMES == 6, "ALL_UNIT_NAMES deve ter 6 tipos")
	assert(Core.UNIT.shieldbearer.armorMilli == 250, "shieldbearer armor != 250")
	assert(Core.UNIT.pyromancer.frostResistMilli == 350, "pyromancer frostResist != 350")
	assert(Core.UNIT.sapper.leak == 22000, "sapper leak != 22000")

	local b = Core.Battle.new({
		seed = 101,
		simVersion = Core.SIM_VERSION,
		wall = {
			traps = {
				{ cell = "r3c4", type = "frost", level = 1 },
				{ cell = "r3c3", type = "cannon", level = 1 },
			},
		},
		wave = {
			slices = {
				{
					startTick = 1,
					everyTicks = 5,
					count = 1,
					unit = "shieldbearer",
					laneMask = 4,
					isElite = false,
				},
				{
					startTick = 2,
					everyTicks = 5,
					count = 1,
					unit = "pyromancer",
					laneMask = 4,
					isElite = false,
				},
				{
					startTick = 3,
					everyTicks = 5,
					count = 1,
					unit = "sapper",
					laneMask = 4,
					isElite = true,
				},
			},
		},
	})
	b:Step() -- tick 1: spawna shieldbearer e frost atira
	assert(b.uType[1] == "shieldbearer", "uType[1] != shieldbearer")
	assert(b.uArmorMilli[1] == 250, "uArmorMilli[1] != 250")
	b:Step() -- tick 2: spawna pyromancer
	assert(b.uType[2] == "pyromancer", "uType[2] != pyromancer")
	assert(b.uFrostResistMilli[2] == 350, "uFrostResistMilli[2] != 350")
	b:Step() -- tick 3: spawna sapper elite
	assert(b.uType[3] == "sapper" and b.uIsElite[3] == true, "sapper elite")
	local ok = b:CheckIntegers()
	assert(ok, "CheckIntegers falhou em WaveSliceSpec")
end)

-- I18 (v7): Boss Multi-Lane (laneSpan=3), AoE shotId dedup, Stagger -> VULNERABLE e ENRAGE
check("I18 Boss Multi-Lane, shotId dedup estrito, Stagger/VULNERABLE e ENRAGE", function()
	local b = Core.Battle.new({
		seed = 55,
		simVersion = Core.SIM_VERSION,
		wall = {
			traps = {
				{ cell = "r3c3", type = "catapult", level = 1 },
				{ cell = "r2c3", type = "cannon", level = 1 },
			},
		},
		wave = {
			count = 0,
			bossId = "iron_ram_colossus",
			bossSpawnTick = 1,
		},
	})
	assert(b.boss ~= nil and b.boss.laneSpan == 3 and b.boss.laneCenter == 3, "boss init")
	b.boss.x = 6500
	local startHp = b.boss.hp

	-- Disparo de catapult c/ shotId=777: mesmo cobrindo multiplas lanes, so aplica dano 1 vez
	local hit1 = b:applyTrap(b.traps[2], 777) -- catapult em r3c3
	assert(hit1 == true, "catapult nao acertou o boss")
	local dmgOnce = startHp - b.boss.hp
	assert(dmgOnce > 0, "catapult causou 0 de dano no boss")
	local hitDuplicate = b:applyTrap(b.traps[2], 777) -- mesmo shotId deve ser ignorado
	assert(hitDuplicate == false and b.boss.hp == startHp - dmgOnce, "shotId duplicou dano no boss")

	-- Acumula stagger ate quebrar postura -> VULNERABLE (30 ticks, dano * 1300 / 1000)
	local preVulnHp = b.boss.hp
	b:applyTrap(b.traps[1], 778) -- cannon em r2c3 (alcanca lane 2 do boss laneCenter=3)
	local normalCannonDmg = preVulnHp - b.boss.hp
	assert(normalCannonDmg > 0, "cannon em lane adjacente nao atingiu boss laneSpan=3")

	while b.boss.state ~= "VULNERABLE" do
		b.nextShotId += 1
		b:applyTrap(b.traps[1], b.nextShotId)
	end
	assert(b.boss.state == "VULNERABLE" and b.boss.stateTicksLeft == 30, "nao entrou em VULNERABLE")

	local hpBeforeVulnHit = b.boss.hp
	b.nextShotId += 1
	b:applyTrap(b.traps[1], b.nextShotId)
	local vulnCannonDmg = hpBeforeVulnHit - b.boss.hp
	assert(
		vulnCannonDmg == math.floor(normalCannonDmg * 1300 / 1000),
		"dano em VULNERABLE != *1300/1000"
	)

	-- ENRAGE abaixo de 40% HP
	b.boss.hp = math.floor(b.boss.maxHp * 390 / 1000)
	b:Step()
	assert(b.boss.enraged == true, "boss nao entrou em ENRAGE abaixo de 40% HP")
end)

-- I19 (v7): determinismo dos 5 Bosses e 8 Mutadores
check("I19 determinismo dos 5 Bosses e 8 Mutadores", function()
	assert(#Core.BOSS_IDS == 5 and #Core.MUTATOR_IDS == 8, "contagem de bosses/mutators")
	for idx, bossId in ipairs(Core.BOSS_IDS) do
		local mutA = Core.MUTATOR_IDS[((idx - 1) * 2 % #Core.MUTATOR_IDS) + 1]
		local mutB = Core.MUTATOR_IDS[((idx * 2) % #Core.MUTATOR_IDS) + 1]
		local function runBossSim()
			local b = Core.Battle.new({
				seed = 900 + idx,
				simVersion = Core.SIM_VERSION,
				wall = Core.defaultWall(),
				wave = {
					count = 12,
					spawnEveryTicks = 20,
					pool = Core.ALL_UNIT_NAMES,
					bossId = bossId,
					bossHpScaleMilli = 200,
					bossSpawnTick = 10,
					mutatorIds = { mutA, mutB },
				},
			})
			while not b:Finished() do
				b:Step()
				local okInt = b:CheckIntegers()
				assert(okInt, "float detectado em boss " .. bossId)
			end
			return b:Result()
		end
		local r1 = runBossSim()
		local r2 = runBossSim()
		assert(r1.hash == r2.hash and r1.ticks == r2.ticks, "divergencia em boss " .. bossId)
	end
end)

print(string.format("invariantes: %d checagens, %d falhas", checks, #failures))
if #failures > 0 then
	for _, f in ipairs(failures) do
		print("  FALHOU: " .. f)
	end
	error("invariantes quebrados")
end
print("OK: todos os invariantes passaram")
