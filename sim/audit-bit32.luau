-- Testa o comportamento de bit32 com doubles fora da faixa e a exatidao do FNV atual.
local function mul32(a: number, b: number): number
	a = bit32.band(a, 0xFFFFFFFF)
	b = bit32.band(b, 0xFFFFFFFF)
	local a0 = bit32.band(a, 0xFFFF)
	local a1 = bit32.rshift(a, 16)
	local b0 = bit32.band(b, 0xFFFF)
	local b1 = bit32.rshift(b, 16)
	local lo = a0 * b0
	local mid = a0 * b1 + a1 * b0
	return bit32.band(lo + mid * 65536, 0xFFFFFFFF)
end

print("== bit32 com entrada > 2^32 ==")
local casos = { 2 ^ 32, 2 ^ 33, 7.2e16, 1.14e19, -1 }
for _, v in ipairs(casos) do
	local ok, r = pcall(function()
		return bit32.band(v, 0xFFFFFFFF)
	end)
	print(string.format("  band(%.3e) -> %s", v, ok and tostring(r) or ("ERRO: " .. tostring(r))))
end

print("\n== FNV atual (multiplicacao em double) vs mul32 exato ==")
local h = 4000000000
local atual = bit32.band(h * 16777619, 0xFFFFFFFF)
local exato = mul32(h, 16777619)
print(string.format("  h=%d", h))
print(string.format("  atual = %d", atual))
print(string.format("  exato = %d", exato))
print(string.format("  iguais? %s", atual == exato and "SIM" or "NAO -> bug confirmado"))

local h2 = 123456789
print(
	string.format(
		"  h=%d atual=%d exato=%d iguais=%s",
		h2,
		bit32.band(h2 * 16777619, 0xFFFFFFFF),
		mul32(h2, 16777619),
		tostring(bit32.band(h2 * 16777619, 0xFFFFFFFF) == mul32(h2, 16777619))
	)
)

print("\n== seed * 2654435761 ==")
for _, seed in ipairs({ 42, 123456789, 4000000000 }) do
	local prod = seed * 2654435761
	local viaBand = bit32.band(prod, 0xFFFFFFFF)
	local exatoLoop = mul32(seed, 2654435761)
	print(
		string.format(
			"  seed=%-12d prod=%.3e  band=%d  mul32=%d  iguais=%s",
			seed,
			prod,
			viaBand,
			exatoLoop,
			tostring(viaBand == exatoLoop)
		)
	)
end

print("\n== soma do xorshift (s0 + x) ==")
local s = 0xFFFFFFFF + 0xFFFFFFFF
print(string.format("  soma=%.3e  band=%d", s, bit32.band(s, 0xFFFFFFFF)))
