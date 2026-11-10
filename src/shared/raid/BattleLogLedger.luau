--!strict
-- Ledger puro do BattleLog: modela "1 chave por battle_id" e a recompensa idempotente.
-- O servidor usa a mesma semantica sobre DataStore; o contrato CLI prova claim/markRewarded.
-- Nao requer BattleLog de proposito (modulo shared roda no CLI e no Roblox sem require interno).

local BattleLogLedger = {}

export type Ledger = {
	records: { [string]: any },
}

function BattleLogLedger.new(): Ledger
	return { records = {} }
end

function BattleLogLedger.get(ledger: Ledger, battleId: any): any?
	if type(battleId) ~= "string" or battleId == "" then
		return nil
	end
	return ledger.records[battleId]
end

-- Primeiro claim cria; os seguintes devolvem o registro existente e created=false.
function BattleLogLedger.claim(ledger: Ledger, record: any): (any?, boolean, string?)
	if type(record) ~= "table" or type(record.battleId) ~= "string" or record.battleId == "" then
		return nil, false, "record invalido"
	end
	local existing = ledger.records[record.battleId]
	if existing ~= nil then
		return existing, false, nil
	end
	ledger.records[record.battleId] = record
	return record, true, nil
end

-- Marca a recompensa uma vez. Repetir devolve o mesmo registro sem debitar de novo.
function BattleLogLedger.markRewarded(
	ledger: Ledger,
	battleId: any,
	rewardGold: any
): (any?, string?)
	if type(battleId) ~= "string" or battleId == "" then
		return nil, "battle_id invalido"
	end
	local existing = ledger.records[battleId]
	if existing == nil then
		return nil, "battle_log ausente"
	end
	if existing.rewarded == true then
		return existing, nil
	end
	if type(rewardGold) ~= "number" or rewardGold < 0 or rewardGold % 1 ~= 0 then
		return nil, "rewardGold invalido"
	end
	local copy = {}
	for key, value in pairs(existing) do
		copy[key] = value
	end
	copy.rewarded = true
	copy.rewardGold = rewardGold
	ledger.records[battleId] = copy
	return copy, nil
end

function BattleLogLedger.count(ledger: Ledger): number
	local total = 0
	for _ in pairs(ledger.records) do
		total += 1
	end
	return total
end

return BattleLogLedger
