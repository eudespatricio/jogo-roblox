-- Compara mul32 atual, mul32 proposto e referencia exata (limbos de 8 bits).
local bit32 = bit32

local function add32(a, b)
	local s = a + b
	if s >= 4294967296 then
		s -= 4294967296
	end
	return s
end

local function mul32Atual(a, b)
	a = bit32.band(a, 0xFFFFFFFF)
	b = bit32.band(b, 0xFFFFFFFF)
	local a0 = bit32.band(a, 0xFFFF)
	local a1 = bit32.rshift(a, 16)
	local b0 = bit32.band(b, 0xFFFF)
	local b1 = bit32.rshift(b, 16)
	return bit32.band(a0 * b0 + (a0 * b1 + a1 * b0) * 65536, 0xFFFFFFFF)
end

local function mul32Novo(a, b)
	a = bit32.band(a, 0xFFFFFFFF)
	b = bit32.band(b, 0xFFFFFFFF)
	local a0 = bit32.band(a, 0xFFFF)
	local a1 = bit32.rshift(a, 16)
	local b0 = bit32.band(b, 0xFFFF)
	local b1 = bit32.rshift(b, 16)
	local mid = bit32.band(a0 * b1 + a1 * b0, 0xFFFF)
	return add32(a0 * b0, mid * 65536)
end

-- referencia exata: soma de produtos de limbs de 8 bits, reduzindo a cada passo
local function mul32Ref(a, b)
	local result = 0
	for i = 0, 3 do
		local ai = bit32.band(bit32.rshift(a, 8 * i), 0xFF)
		if ai ~= 0 then
			for j = 0, 3 do
				local bj = bit32.band(bit32.rshift(b, 8 * j), 0xFF)
				if bj ~= 0 and i + j < 4 then
					result = (result + ai * bj * 2 ^ (8 * (i + j))) % 4294967296
				end
			end
		end
	end
	return result
end

-- vetores conhecidos
local casos = {
	{ 0xFFFFFFFF, 0xFFFFFFFF, 1 },
	{ 0x80000000, 2, 0 },
	{ 1, 16777619, 16777619 },
	{ 2654435761, 42, nil },
}
print("== vetores ==")
for _, c in ipairs(casos) do
	local a, b, esperado = c[1], c[2], c[3]
	local ref = mul32Ref(a, b)
	local atual = mul32Atual(a, b)
	local novo = mul32Novo(a, b)
	print(
		string.format(
			"  %10d x %10d -> ref=%10d atual=%10d novo=%10d %s",
			a,
			b,
			ref,
			atual,
			novo,
			(ref == novo and (esperado == nil or ref == esperado)) and "OK" or "DIVERGE"
		)
	)
end

-- varredura aleatoria
local seed = 12345
local function rnd()
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed
end

local n = 200000
local badAtual, badNovo = 0, 0
for _ = 1, n do
	local a = rnd() * 2048 % 4294967296
	local b = rnd() * 2048 % 4294967296
	local ref = mul32Ref(a, b)
	if mul32Atual(a, b) ~= ref then
		badAtual += 1
	end
	if mul32Novo(a, b) ~= ref then
		badNovo += 1
	end
end
print(string.format("\n== %d pares aleatorios ==", n))
print(string.format("  mul32 atual divergiu: %d", badAtual))
print(string.format("  mul32 novo  divergiu: %d", badNovo))
