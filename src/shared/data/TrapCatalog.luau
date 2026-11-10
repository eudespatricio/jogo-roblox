--!strict
-- Catalogo economico das armadilhas (S3). Fonte unica de custo, upgrade, desbloqueio,
-- liga e nivel maximo. O motor (Core.TRAP) e a simulacao; este modulo e a economia.
-- Adicionar um tipo aqui NAO basta: ele precisa existir em Core.TRAP e no teste de paridade
-- (sim/walls-contract.luau). Ver "Como expandir" em docs/economia-muralha.md.

local TrapCatalog = {}

TrapCatalog.CONTENT_VERSION = 1
TrapCatalog.POINTS_PER_LEAGUE = 100
TrapCatalog.MAX_LEVEL = 3

export type TrapDef = { cost: number, upgrade: number, unlockLeague: number }
export type Catalog = { [string]: TrapDef }

local TRAPS: Catalog = {
	archer = { cost = 40, upgrade = 30, unlockLeague = 1 },
	oil = { cost = 60, upgrade = 45, unlockLeague = 2 },
	frost = { cost = 90, upgrade = 65, unlockLeague = 3 },
	cannon = { cost = 140, upgrade = 100, unlockLeague = 4 },
}

TrapCatalog.TRAPS = table.freeze(TRAPS)
TrapCatalog.TRAP_IDS = table.freeze({ "archer", "oil", "frost", "cannon" })
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
