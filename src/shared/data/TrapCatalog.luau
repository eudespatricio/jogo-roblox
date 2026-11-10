--!strict
-- Catalogo economico das armadilhas (S3.4). Fonte unica de custo, upgrade, desbloqueio,
-- liga, nivel maximo e migracao de conteudo. O motor (Core.TRAP) e a simulacao.
-- Adicionar um tipo aqui NAO basta: ele precisa existir em Core.TRAP e no teste de paridade
-- (sim/walls-contract.luau). Ver "Como expandir" em docs/economia-muralha.md.
-- Politica de versao (GAP-003): tipo novo/renomeado exige CONTENT_VERSION++ e, se aparece
-- em batalha, SIM_VERSION++ + re-ancoragem de hash/acceptance; o contrato pina a lista.

local TrapCatalog = {}

TrapCatalog.CONTENT_VERSION = 2
TrapCatalog.POINTS_PER_LEAGUE = 100
TrapCatalog.MAX_LEVEL = 3

export type TrapDef = { cost: number, upgrade: number, unlockLeague: number }
export type Catalog = { [string]: TrapDef }

local TRAPS: Catalog = {
	archer = { cost = 40, upgrade = 30, unlockLeague = 1 },
	tar = { cost = 60, upgrade = 45, unlockLeague = 2 },
	frost = { cost = 90, upgrade = 65, unlockLeague = 3 },
	cannon = { cost = 140, upgrade = 100, unlockLeague = 4 },
	catapult = { cost = 180, upgrade = 130, unlockLeague = 5 },
}

TrapCatalog.TRAPS = table.freeze(TRAPS)
TrapCatalog.TRAP_IDS = table.freeze({ "archer", "tar", "frost", "cannon", "catapult" })

-- Renomes/remocoes de conteudo: id antigo -> id novo. Um perfil v1 com `oil` vira `tar`.
-- Remocao sem substituto nao apaga dado: o perfil falha fechado e exige alias explicito.
TrapCatalog.TRAP_ALIASES = table.freeze({
	oil = "tar",
})
TrapCatalog.GOLD_SOURCES = table.freeze({ raid = true, defense = true, daily = true })
TrapCatalog.GOLD_SINKS = table.freeze({ trap = true, upgrade = true })

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

function TrapCatalog.leagueOf(points: number): number
	if points < 0 then
		return 1
	end
	return 1 + math.floor(points / TrapCatalog.POINTS_PER_LEAGUE)
end

-- Migra/valida o conteudo de um perfil antes de expor `Data`: resolve aliases de trap_id,
-- sobe `contentVersion` e falha fechado se o perfil veio de um catalogo futuro ou tem id
-- desconhecido (nao apaga celula sem decisao explicita). Devolve (ok, erro, mudou).
function TrapCatalog.ensureProfileContent(profile: any): (boolean, string?, boolean)
	if
		type(profile) ~= "table"
		or type(profile.wall) ~= "table"
		or type(profile.wall.cells) ~= "table"
	then
		return false, "perfil sem wall.cells", false
	end
	local version = profile.contentVersion
	if not isInteger(version) or (version :: number) < 1 then
		return false, "contentVersion invalido", false
	end
	version = version :: number
	if version > TrapCatalog.CONTENT_VERSION then
		return false, "content_future", false
	end

	local keys: { string } = {}
	local changes: { [string]: string } = {}
	for cell, data in pairs(profile.wall.cells) do
		if type(cell) ~= "string" or type(data) ~= "table" or type(data.trap) ~= "string" then
			return false, "cell invalida", false
		end
		keys[#keys + 1] = cell
		local trapId = data.trap :: string
		local alias = TrapCatalog.TRAP_ALIASES[trapId]
		if alias ~= nil then
			changes[cell] = alias
		elseif TrapCatalog.TRAPS[trapId] == nil then
			return false, "trap desconhecida: " .. trapId .. " (" .. cell .. ")", false
		end
	end
	table.sort(keys)

	local changed = false
	for _, cell in ipairs(keys) do
		local alias = changes[cell]
		if alias ~= nil then
			profile.wall.cells[cell].trap = alias
			changed = true
		end
	end
	if version < TrapCatalog.CONTENT_VERSION then
		profile.contentVersion = TrapCatalog.CONTENT_VERSION
		changed = true
	end
	return true, nil, changed
end

-- Valida o proprio catalogo antes de qualquer uso: evita custo/desbloqueio invalido e
-- divergencia entre TRAP_IDS e TRAPS. Nao valida o motor (a paridade e teste).
function TrapCatalog.validate(): (boolean, string?)
	if not isInteger(TrapCatalog.CONTENT_VERSION) or TrapCatalog.CONTENT_VERSION < 1 then
		return false, "CONTENT_VERSION invalida"
	end
	if not isInteger(TrapCatalog.POINTS_PER_LEAGUE) or TrapCatalog.POINTS_PER_LEAGUE < 1 then
		return false, "POINTS_PER_LEAGUE invalido"
	end
	if not isInteger(TrapCatalog.MAX_LEVEL) or TrapCatalog.MAX_LEVEL < 1 then
		return false, "MAX_LEVEL invalido"
	end

	local seen: { [string]: boolean } = {}
	for _, trapId in ipairs(TrapCatalog.TRAP_IDS) do
		if type(trapId) ~= "string" or trapId == "" then
			return false, "TRAP_IDS com id invalido"
		end
		if seen[trapId] then
			return false, "TRAP_IDS duplicado: " .. trapId
		end
		seen[trapId] = true
		local def = TrapCatalog.TRAPS[trapId]
		if def == nil then
			return false, "TRAP_IDS sem definicao: " .. trapId
		end
		if not isInteger(def.cost) or def.cost < 1 then
			return false, "custo invalido: " .. trapId
		end
		if not isInteger(def.upgrade) or def.upgrade < 1 then
			return false, "upgrade invalido: " .. trapId
		end
		if not isInteger(def.unlockLeague) or def.unlockLeague < 1 then
			return false, "unlockLeague invalido: " .. trapId
		end
	end

	for trapId in pairs(TrapCatalog.TRAPS) do
		if not seen[trapId] then
			return false, "TRAPS fora de TRAP_IDS: " .. trapId
		end
	end
	for oldId, newId in pairs(TrapCatalog.TRAP_ALIASES) do
		if TrapCatalog.TRAPS[oldId] ~= nil then
			return false, "TRAP_ALIASES colide com trap atual: " .. oldId
		end
		if TrapCatalog.TRAPS[newId] == nil then
			return false, "TRAP_ALIASES sem destino: " .. oldId
		end
	end
	for _, source in ipairs({ "raid", "defense", "daily" }) do
		if TrapCatalog.GOLD_SOURCES[source] ~= true then
			return false, "GOLD_SOURCES sem " .. source
		end
	end
	for _, sink in ipairs({ "trap", "upgrade" }) do
		if TrapCatalog.GOLD_SINKS[sink] ~= true then
			return false, "GOLD_SINKS sem " .. sink
		end
	end
	return true, nil
end

return TrapCatalog
