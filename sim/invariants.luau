--!nonstrict
-- Invariantes executaveis da Muralha (fase 3 do context-recovery).
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
		local battle = Core.Battle.new({ seed = seed, waveCount = 80 })
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

print(string.format("invariantes: %d checagens, %d falhas", checks, #failures))
if #failures > 0 then
	for _, f in ipairs(failures) do
		print("  FALHOU: " .. f)
	end
	error("invariantes quebrados")
end
print("OK: todos os invariantes passaram")
