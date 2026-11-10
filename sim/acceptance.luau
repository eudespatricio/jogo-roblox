--!nonstrict
-- P1 acceptance (motor v2): 1.000 seeds x 3, hash estavel, performance e balanco.
-- Roda no Luau CLI: luau sim/acceptance.luau
local Core = require("../src/shared/sim/core")

local SEEDS = 1000
local failures = {}
local checks = 0

local function check(name, fn)
	checks += 1
	local ok, err = pcall(fn)
	if not ok then
		failures[#failures + 1] = name .. " :: " .. tostring(err)
	end
end

check("hash de referencia (seed 42, simVersion 3)", function()
	local r = Core.Run(42)
	assert(r.simVersion == 3, "simVersion != 3: " .. tostring(r.simVersion))
	assert(r.hash == 2489780106, "hash mudou: " .. tostring(r.hash))
	print(string.format("  seed 42: hash=%d winner=%s ticks=%d", r.hash, r.winner, r.ticks))
end)

check("1.000 seeds x 3 (hash e resultado identicos)", function()
	local distinct = {}
	local wins = 0
	for seed = 1, SEEDS do
		local a = Core.Run(seed)
		local b = Core.Run(seed)
		local c = Core.Run(seed)
		assert(a.hash == b.hash and b.hash == c.hash, "hash divergiu na seed " .. seed)
		assert(a.simVersion == 3, "simVersion divergente na seed " .. seed)
		assert(
			a.winner == b.winner
				and b.winner == c.winner
				and a.wallHp == b.wallHp
				and b.wallHp == c.wallHp
				and a.leaked == b.leaked
				and b.leaked == c.leaked
				and a.ticks == b.ticks
				and b.ticks == c.ticks,
			"resultado divergiu na seed " .. seed
		)
		distinct[a.hash] = true
		if a.winner == "defender" then
			wins += 1
		end
	end
	local n = 0
	for _ in pairs(distinct) do
		n += 1
	end
	assert(n == SEEDS, "hashes distintas: " .. n .. "/" .. SEEDS)
	local pct = wins / SEEDS * 100
	assert(pct >= 30 and pct <= 70, "balanceamento fora da faixa: " .. pct .. "%")
	print(string.format("  seeds=%d distintas=%d vitorias_defensor=%.1f%%", SEEDS, n, pct))
end)

check("performance: 1.000 batalhas < 5s", function()
	local t0 = os.clock()
	for seed = 1, SEEDS do
		Core.Run(seed)
	end
	local dt = os.clock() - t0
	assert(dt < 5, "lento: " .. string.format("%.3fs", dt))
	print(string.format("  1.000 batalhas em %.3fs (%.3f ms/batalha)", dt, dt))
end)

check("estado inteiro (100 seeds)", function()
	for seed = 1, 100 do
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

check("loadout padrao 5x5/N=5", function()
	local wall = Core.defaultWall()
	assert(#wall.traps == 5, "loadout padrao != 5: " .. tostring(#wall.traps))
	local seen = {}
	for _, trap in ipairs(wall.traps) do
		assert(
			string.match(trap.cell, "^r[1-5]c[1-5]$") ~= nil,
			"celula fora da grade: " .. trap.cell
		)
		assert(not seen[trap.cell], "celula repetida: " .. trap.cell)
		seen[trap.cell] = true
	end
	local r = Core.Run(42)
	assert(r.traps == 5, "resultado nao expos 5 ativas")
end)

print(string.format("P1 acceptance: %d checagens, %d falhas", checks, #failures))
if #failures > 0 then
	for _, f in ipairs(failures) do
		print("  FALHOU: " .. f)
	end
	error("P1 acceptance quebrada")
end
print("OK: P1 acceptance passou")
