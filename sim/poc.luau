--!nonstrict
-- Demo/benchmark do nucleo deterministico (sim/core.luau).
-- Roda no Luau CLI:  luau sim/poc.luau
local Core = require("./core")
local Battle = Core.Battle
local RNG = Core.RNG
local TUNING = Core.TUNING
local run = Core.Run

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
		if not b:CheckIntegers() then
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
TUNING.powerPct = Core.DEFAULT_POWER_PCT
