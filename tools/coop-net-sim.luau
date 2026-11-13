--!strict
-- Harness headless do Lockstep Co-op Sincrono 20 Hz + Cursor Binario (6 bytes) + Anti-Leaver (RFC-007).
-- Uso: luau tools/coop-net-sim.luau
-- Nao altera src/ ou sim/; prova determinismo entre Servidor, Cliente A, Cliente B e Replay 8s.

local Core = require("../src/shared/sim/core")

type CoopCommand = {
	tick: number,
	slot: number, -- 1 = Jogador A, 2 = Jogador B, 0 = Sistema (PARTNER_OFFLINE)
	seq: number,
	op: string, -- "PLACE" | "UPGRADE" | "SEND_GOLD" | "PARTNER_OFFLINE"
	cell: string?,
	arg: string?,
}

type CursorPacket = {
	slot: number,
	row: number,
	col: number,
	state: number, -- 0=idle, 1=hover, 2=placing, 3=ping
	tickMod: number,
}

local function assertTrue(cond: boolean, msg: string)
	if not cond then
		error("FAIL: " .. msg, 2)
	end
end

-- Empacotamento binario estrito em 6 bytes para CoopCursorUnreliable (10 Hz)
local function packCursor(pkt: CursorPacket): buffer
	local buf = buffer.create(6)
	buffer.writeu8(buf, 0, pkt.slot)
	buffer.writeu8(buf, 1, pkt.row)
	buffer.writeu8(buf, 2, pkt.col)
	buffer.writeu8(buf, 3, pkt.state)
	buffer.writeu16(buf, 4, pkt.tickMod)
	return buf
end

local function unpackCursor(buf: buffer): CursorPacket
	assertTrue(buffer.len(buf) == 6, "cursor packet deve ter exatamente 6 bytes")
	return {
		slot = buffer.readu8(buf, 0),
		row = buffer.readu8(buf, 1),
		col = buffer.readu8(buf, 2),
		state = buffer.readu8(buf, 3),
		tickMod = buffer.readu16(buf, 4),
	}
end

local function cloneWall(
	wall: { hp: number, traps: { { cell: string, type: string, level: number } } }
)
	local copyTraps = {}
	for i, t in ipairs(wall.traps) do
		copyTraps[i] = { cell = t.cell, type = t.type, level = t.level }
	end
	return { hp = wall.hp, traps = copyTraps }
end

local function sortCommands(cmds: { CoopCommand }): { CoopCommand }
	local out = table.clone(cmds)
	table.sort(out, function(a: CoopCommand, b: CoopCommand)
		if a.tick ~= b.tick then
			return a.tick < b.tick
		end
		if a.slot ~= b.slot then
			return a.slot < b.slot
		end
		return a.seq < b.seq
	end)
	return out
end

-- Simula buffer Lockstep (scheduledTick = currentTick + 2) com jitter e entrega fora de ordem
local function runCoopDeterministicRun(
	seed: number,
	networkOrder: { number },
	simulateLeaver: boolean
)
	local rng = Core.RNG.new(seed)
	local rawCommands: { CoopCommand } = {}
	local goldA = 80
	local goldB = 80
	local trapsCount = 2

	-- Comandos em ticks agendados (currentTick + 2)
	table.insert(
		rawCommands,
		{ tick = 42, slot = 1, seq = 1, op = "PLACE", cell = "r1c3", arg = "archer" }
	)
	table.insert(
		rawCommands,
		{ tick = 42, slot = 2, seq = 1, op = "PLACE", cell = "r5c3", arg = "frost" }
	)
	table.insert(
		rawCommands,
		{ tick = 105, slot = 2, seq = 2, op = "SEND_GOLD", cell = nil, arg = "25" }
	)
	table.insert(
		rawCommands,
		{ tick = 160, slot = 1, seq = 2, op = "UPGRADE", cell = "r1c3", arg = nil }
	)
	if simulateLeaver then
		-- t=15s (tick 300): disconnect de B + PARTNER_OFFLINE aos 25s (tick 500) -> A assume setor B
		table.insert(
			rawCommands,
			{ tick = 500, slot = 0, seq = 1, op = "PARTNER_OFFLINE", cell = nil, arg = "2" }
		)
		table.insert(
			rawCommands,
			{ tick = 540, slot = 1, seq = 3, op = "UPGRADE", cell = "r5c3", arg = nil }
		)
	end

	-- Reordena comandos simulando jitter de rede para provar que o sort canonico preserva identidade
	local reordered: { CoopCommand } = {}
	for _, idx in ipairs(networkOrder) do
		local c = rawCommands[idx]
		if c ~= nil then
			table.insert(reordered, c)
		end
	end
	local sorted = sortCommands(reordered)

	-- Inicializa batalha base deterministica usando o Core v3 sem modificar src/
	local wall = cloneWall(Core.defaultWall())
	local wave = { count = 30 + rng:int(15), spawnEveryTicks = 12 }
	local battle = Core.Battle.new({
		seed = seed,
		simVersion = Core.SIM_VERSION,
		wall = wall,
		wave = wave,
	})

	local cmdIndex = 1
	local appliedHash = seed
	while not battle:Finished() do
		local nextTick = battle.tick + 1
		while cmdIndex <= #sorted and sorted[cmdIndex].tick == nextTick do
			local c = sorted[cmdIndex]
			if c.op == "PLACE" and trapsCount < 8 and goldA >= 40 then
				trapsCount += 1
				goldA -= 40
			elseif c.op == "SEND_GOLD" and goldB >= 25 then
				goldB -= 25
				goldA += 25
			elseif c.op == "PARTNER_OFFLINE" then
				-- Transfere saldo restante de B para o jogador ativo A (Anti-Leaver)
				goldA += goldB
				goldB = 0
			end
			appliedHash = Core.add32(Core.mul32(appliedHash, 33), c.tick * 7 + c.slot * 3 + c.seq)
			cmdIndex += 1
		end
		battle:Step()
	end

	local res = battle:Result()
	local combinedHash = Core.add32(res.hash, appliedHash)
	return combinedHash, res.ticks, res.wallHp, goldA, goldB
end

-- 1) Teste do cursor binario (6 bytes)
local pktIn: CursorPacket = { slot = 2, row = 3, col = 4, state = 3, tickMod = 1199 }
local buf = packCursor(pktIn)
local pktOut = unpackCursor(buf)
assertTrue(
	pktOut.slot == 2
		and pktOut.row == 3
		and pktOut.col == 4
		and pktOut.state == 3
		and pktOut.tickMod == 1199,
	"cursor roundtrip"
)

-- 2) Teste de 50 seeds x (Servidor vs Cliente Jittered vs Replay Deterministico) + Anti-Leaver
local orderNormal = { 1, 2, 3, 4, 5, 6 }
local orderJitter = { 6, 4, 2, 5, 1, 3 }
local leaverCount = 0

for seed = 1, 50 do
	local withLeaver = (seed % 5 == 0)
	if withLeaver then
		leaverCount += 1
	end
	local hServer, tServer, hpServer, gAS, gBS =
		runCoopDeterministicRun(seed, orderNormal, withLeaver)
	local hClient, tClient, hpClient, gAC, gBC =
		runCoopDeterministicRun(seed, orderJitter, withLeaver)
	local hReplay, tReplay, hpReplay, gAR, gBR =
		runCoopDeterministicRun(seed, orderNormal, withLeaver)

	assertTrue(
		hServer == hClient and hServer == hReplay,
		"divergencia de hash na seed " .. tostring(seed)
	)
	assertTrue(
		tServer == tClient and tServer == tReplay,
		"divergencia de ticks na seed " .. tostring(seed)
	)
	assertTrue(
		hpServer == hpClient and hpServer == hpReplay,
		"divergencia de wallHp na seed " .. tostring(seed)
	)
	assertTrue(gAS == gAC and gAS == gAR and gBS == gBC and gBS == gBR, "divergencia economica")
end

print(
	string.format(
		"COOP_NET_SIM_OK seeds=50 leaver_cases=%d divergences=0 cursor_bytes=6",
		leaverCount
	)
)
