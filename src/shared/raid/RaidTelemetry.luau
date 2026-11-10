--!strict
-- Props de telemetria da raid (taxonomia v1). O envelope/sink roda no AnalyticsService (S7);
-- aqui ficam as props validadas no contrato e no servidor.

local RaidTelemetry = {}

RaidTelemetry.TICK_MS = 50
RaidTelemetry.MAX_ID = 64

local function isInteger(value: any): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value % 1 == 0
end

local function isId(value: any): boolean
	return type(value) == "string" and #value > 0 and #value <= RaidTelemetry.MAX_ID
end

local function isHash(value: any): boolean
	return isInteger(value) and value >= 0 and value <= 4294967295
end

function RaidTelemetry.startedProps(
	battleId: any,
	seed: any,
	simVersion: any,
	gridWidth: any,
	trapsCount: any
): (any?, string?)
	if not isId(battleId) then
		return nil, "battle_id invalido"
	end
	if not isInteger(seed) or seed < 0 then
		return nil, "seed invalido"
	end
	if not isInteger(simVersion) or simVersion < 1 then
		return nil, "sim_version invalido"
	end
	if not isInteger(gridWidth) or gridWidth < 1 then
		return nil, "grid_width invalido"
	end
	if not isInteger(trapsCount) or trapsCount < 0 then
		return nil, "traps_count invalido"
	end
	return {
		battle_id = battleId,
		seed = seed,
		sim_version = simVersion,
		grid_width = gridWidth,
		traps_count = trapsCount,
	},
		nil
end

function RaidTelemetry.finishedProps(battleId: any, result: any): (any?, string?)
	if not isId(battleId) or type(result) ~= "table" then
		return nil, "result invalido"
	end
	if not isHash(result.hash) then
		return nil, "result_hash invalido"
	end
	if result.winner ~= "defender" and result.winner ~= "attacker" then
		return nil, "winner invalido"
	end
	if not isInteger(result.ticks) or result.ticks < 0 then
		return nil, "ticks invalido"
	end
	return {
		battle_id = battleId,
		seed = result.seed,
		sim_version = result.simVersion,
		result_hash = result.hash,
		winner = result.winner,
		wall_hp = result.wallHp,
		leaked = result.leaked,
		ticks = result.ticks,
		duration_ms = result.ticks * RaidTelemetry.TICK_MS,
	},
		nil
end

function RaidTelemetry.divergenceProps(
	battleId: any,
	expectedHash: any,
	actualHash: any
): (any?, string?)
	if not isId(battleId) then
		return nil, "battle_id invalido"
	end
	if not isHash(expectedHash) or not isHash(actualHash) then
		return nil, "hash invalido"
	end
	return {
		battle_id = battleId,
		expected_hash = expectedHash,
		actual_hash = actualHash,
	},
		nil
end

function RaidTelemetry.format(name: string, props: any): string
	local parts = { "[analytics]", name }
	if type(props) == "table" then
		local keys = {}
		for key in pairs(props) do
			keys[#keys + 1] = key
		end
		table.sort(keys)
		for _, key in ipairs(keys) do
			parts[#parts + 1] = string.format("%s=%s", key, tostring(props[key]))
		end
	end
	return table.concat(parts, " ")
end

return RaidTelemetry
