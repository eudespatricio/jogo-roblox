--!strict
-- Replay determinístico da raid: roda o mesmo seed/muralha/wave de novo e compara o hash.
-- O servidor faz a verificacao antes de creditar/recompensar; o cliente mostra os 8 s.

local RaidReplay = {}

RaidReplay.SECONDS = 8

local function hashOf(result: any): number?
	if type(result) ~= "table" or type(result.hash) ~= "number" then
		return nil
	end
	return result.hash
end

-- (ok, erro, expectedHash, actualHash). Erro "divergence" quando o hash muda.
function RaidReplay.verify(expected: any, actual: any): (boolean, string?, number?, number?)
	local expectedHash = hashOf(expected)
	local actualHash = hashOf(actual)
	if expectedHash == nil or actualHash == nil then
		return false, "result_invalido", expectedHash, actualHash
	end
	if expected.seed ~= actual.seed or expected.simVersion ~= actual.simVersion then
		return false, "replay_spec", expectedHash, actualHash
	end
	if expectedHash ~= actualHash then
		return false, "divergence", expectedHash, actualHash
	end
	if expected.winner ~= actual.winner or expected.ticks ~= actual.ticks then
		return false, "divergence", expectedHash, actualHash
	end
	return true, nil, expectedHash, actualHash
end

return RaidReplay
