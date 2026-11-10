--!strict
-- BattleLog da S6: um registro imutavel por battle_id, com a versao do conteudo (GAP-011).
-- O store e separado do perfil; a chave e o proprio battle_id. Puro Luau para o contrato CLI.

local BattleLog = {}

BattleLog.SCHEMA_VERSION = 1
BattleLog.STORE_NAME = "MuralhaBattleLog_v1"
BattleLog.TICK_MS = 50

export type Record = {
	schemaVersion: number,
	battleId: string,
	seed: number,
	simVersion: number,
	contentVersion: number,
	gridWidth: number,
	trapsCount: number,
	resultHash: number,
	winner: string,
	wallHp: number,
	leaked: number,
	ticks: number,
	durationMs: number,
	createdAt: number,
	rewarded: boolean,
	rewardGold: number,
}

export type BattleResult = {
	seed: number,
	simVersion: number,
	hash: number,
	winner: string,
	wallHp: number,
	leaked: number,
	ticks: number,
}

local function isInteger(value: any): boolean
	if type(value) ~= "number" then
		return false
	end
	local numberValue = value :: number
	return numberValue == numberValue
		and numberValue ~= math.huge
		and numberValue ~= -math.huge
		and numberValue % 1 == 0
end

local function isId(value: any): boolean
	if type(value) ~= "string" then
		return false
	end
	local text = value :: string
	if #text == 0 or #text > 64 then
		return false
	end
	for index = 1, #text do
		local byte = string.byte(text, index) or 0
		local ok = (byte >= 48 and byte <= 57)
			or (byte >= 65 and byte <= 90)
			or (byte >= 97 and byte <= 122)
			or byte == 95
			or byte == 45
			or byte == 46
			or byte == 58
		if not ok then
			return false
		end
	end
	return true
end

local function isWinner(value: any): boolean
	return value == "defender" or value == "attacker"
end

function BattleLog.keyFor(battleId: any): (string?, string?)
	if not isId(battleId) then
		return nil, "battle_id invalido"
	end
	return battleId :: string, nil
end

function BattleLog.validate(record: any): (boolean, string?)
	if type(record) ~= "table" then
		return false, "record nao e tabela"
	end
	if record.schemaVersion ~= BattleLog.SCHEMA_VERSION then
		return false, "schemaVersion != " .. tostring(BattleLog.SCHEMA_VERSION)
	end
	if not isId(record.battleId) then
		return false, "battleId invalido"
	end
	if not isInteger(record.seed) or record.seed < 0 then
		return false, "seed invalido"
	end
	if not isInteger(record.simVersion) or record.simVersion < 1 then
		return false, "simVersion invalido"
	end
	if not isInteger(record.contentVersion) or record.contentVersion < 1 then
		return false, "contentVersion invalido"
	end
	if not isInteger(record.gridWidth) or record.gridWidth < 1 then
		return false, "gridWidth invalido"
	end
	if not isInteger(record.trapsCount) or record.trapsCount < 0 then
		return false, "trapsCount invalido"
	end
	if not isInteger(record.resultHash) or record.resultHash < 0 then
		return false, "resultHash invalido"
	end
	if not isWinner(record.winner) then
		return false, "winner invalido"
	end
	if not isInteger(record.wallHp) or record.wallHp < 0 then
		return false, "wallHp invalido"
	end
	if not isInteger(record.leaked) or record.leaked < 0 then
		return false, "leaked invalido"
	end
	if not isInteger(record.ticks) or record.ticks < 0 then
		return false, "ticks invalido"
	end
	if not isInteger(record.durationMs) or record.durationMs < 0 then
		return false, "durationMs invalido"
	end
	if not isInteger(record.createdAt) or record.createdAt < 0 then
		return false, "createdAt invalido"
	end
	if type(record.rewarded) ~= "boolean" then
		return false, "rewarded invalido"
	end
	if not isInteger(record.rewardGold) or record.rewardGold < 0 then
		return false, "rewardGold invalido"
	end
	return true, nil
end

-- Monta o log a partir do BattleResult. O contentVersion entra aqui (GAP-011) e nunca
-- e derivado do hash: o log e a prova de qual catalogo gerou aquele replay.
function BattleLog.fromBattle(
	battleId: string,
	result: BattleResult,
	contentVersion: number,
	gridWidth: number,
	trapsCount: number,
	createdAt: number
): (Record?, string?)
	if type(result) ~= "table" then
		return nil, "result invalido"
	end
	local record: Record = {
		schemaVersion = BattleLog.SCHEMA_VERSION,
		battleId = battleId,
		seed = result.seed,
		simVersion = result.simVersion,
		contentVersion = contentVersion,
		gridWidth = gridWidth,
		trapsCount = trapsCount,
		resultHash = result.hash,
		winner = result.winner,
		wallHp = result.wallHp,
		leaked = result.leaked,
		ticks = result.ticks,
		durationMs = result.ticks * BattleLog.TICK_MS,
		createdAt = createdAt,
		rewarded = false,
		rewardGold = 0,
	}
	local ok, err = BattleLog.validate(record)
	if not ok then
		return nil, err
	end
	return record, nil
end

-- O replay so roda se o log nao veio de um catalogo futuro (GAP-011).
function BattleLog.isReplayable(record: Record, currentContentVersion: number): (boolean, string?)
	if record.contentVersion > currentContentVersion then
		return false, "content_future"
	end
	return true, nil
end

-- Fecha a recompensa de forma imutavel: devolve uma copia com rewarded/rewardGold.
function BattleLog.markRewarded(record: Record, rewardGold: number): (Record?, string?)
	if type(rewardGold) ~= "number" or rewardGold < 0 or rewardGold % 1 ~= 0 then
		return nil, "rewardGold invalido"
	end
	local copy: Record = {
		schemaVersion = record.schemaVersion,
		battleId = record.battleId,
		seed = record.seed,
		simVersion = record.simVersion,
		contentVersion = record.contentVersion,
		gridWidth = record.gridWidth,
		trapsCount = record.trapsCount,
		resultHash = record.resultHash,
		winner = record.winner,
		wallHp = record.wallHp,
		leaked = record.leaked,
		ticks = record.ticks,
		durationMs = record.durationMs,
		createdAt = record.createdAt,
		rewarded = true,
		rewardGold = rewardGold,
	}
	local ok, err = BattleLog.validate(copy)
	if not ok then
		return nil, err
	end
	return copy, nil
end

return BattleLog
