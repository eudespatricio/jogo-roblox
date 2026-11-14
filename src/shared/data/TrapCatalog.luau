--!strict
-- Catalogo economico das armadilhas (S3.4). Fonte unica de custo, upgrade, desbloqueio,
-- liga, nivel maximo e migracao de conteudo. O motor (Core.TRAP) e a simulacao.
-- Adicionar um tipo aqui NAO basta: ele precisa existir em Core.TRAP e no teste de paridade
-- (sim/walls-contract.luau). Ver "Como expandir" em docs/economia-muralha.md.
-- Politica de versao (GAP-003): tipo novo/renomeado exige CONTENT_VERSION++ e, se aparece
-- em batalha, SIM_VERSION++ + re-ancoragem de hash/acceptance; o contrato pina a lista.

local TrapCatalog = {}

-- v3 (13/11/2026, P2): MAX_LEVEL 3 -> 5, tiers da muralha Nv1..Nv5 (WALL_LEVELS) e sink "wall".
TrapCatalog.CONTENT_VERSION = 3
TrapCatalog.POINTS_PER_LEAGUE = 100
TrapCatalog.MAX_LEVEL = 5
TrapCatalog.MAX_WALL_LEVEL = 5

export type TrapDef = { cost: number, upgrade: number, unlockLeague: number }
export type Catalog = { [string]: TrapDef }
-- Tier da muralha: custo em ouro para CHEGAR neste nivel (Nv1 = 0) e liga minima.
-- hp/limite ativo moram em Core.WALL_LEVELS (matematica da batalha); o contrato prova paridade.
export type WallLevelDef = { cost: number, unlockLeague: number, hp: number, trapLimit: number }

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
TrapCatalog.GOLD_SINKS = table.freeze({ trap = true, upgrade = true, wall = true })

-- Tiers estruturais (docs/skills-tiers-e-modos.md §2.3; custo em docs/economia-muralha.md).
local WALL_LEVELS: { WallLevelDef } = {
	table.freeze({ cost = 0, unlockLeague = 1, hp = 500, trapLimit = 5 }),
	table.freeze({ cost = 150, unlockLeague = 1, hp = 650, trapLimit = 5 }),
	table.freeze({ cost = 350, unlockLeague = 3, hp = 800, trapLimit = 6 }),
	table.freeze({ cost = 700, unlockLeague = 4, hp = 1000, trapLimit = 6 }),
	table.freeze({ cost = 1200, unlockLeague = 5, hp = 1250, trapLimit = 7 }),
}
TrapCatalog.WALL_LEVELS = table.freeze(WALL_LEVELS)

-- Custo do upgrade de armadilha do nivel `level` para `level + 1` (upgrade * nivel atual).
function TrapCatalog.upgradeCost(trapId: string, level: number): number?
	local def = TrapCatalog.TRAPS[trapId]
	if def == nil or level < 1 or level >= TrapCatalog.MAX_LEVEL then
		return nil
	end
	return def.upgrade * level
end

-- Custo para subir a muralha do nivel `level` para `level + 1` (nil se ja esta no teto).
function TrapCatalog.wallUpgradeCost(level: number): number?
	local nextDef = TrapCatalog.WALL_LEVELS[level + 1]
	if level < 1 or nextDef == nil then
		return nil
	end
	return nextDef.cost
end

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
	-- schema v3: wall.traps (id -> {trap, level, x, y}); schema <= 2: wall.cells (rXcY -> cell).
	local container = nil
	if type(profile) == "table" and type(profile.wall) == "table" then
		container = profile.wall.traps
		if type(container) ~= "table" then
			container = profile.wall.cells
		end
	end
	if type(container) ~= "table" then
		return false, "perfil sem wall.traps/wall.cells", false
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
	for cell, data in pairs(container) do
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
			container[cell].trap = alias
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
	if #TrapCatalog.WALL_LEVELS ~= TrapCatalog.MAX_WALL_LEVEL then
		return false, "WALL_LEVELS != MAX_WALL_LEVEL"
	end
	for index, wallDef in ipairs(TrapCatalog.WALL_LEVELS) do
		if
			not isInteger(wallDef.cost)
			or wallDef.cost < 0
			or (index > 1 and wallDef.cost < 1)
			or not isInteger(wallDef.unlockLeague)
			or wallDef.unlockLeague < 1
			or not isInteger(wallDef.hp)
			or wallDef.hp < 1
			or not isInteger(wallDef.trapLimit)
			or wallDef.trapLimit < 1
		then
			return false, "WALL_LEVELS[" .. index .. "] invalido"
		end
	end
	for _, sink in ipairs({ "trap", "upgrade", "wall" }) do
		if TrapCatalog.GOLD_SINKS[sink] ~= true then
			return false, "GOLD_SINKS sem " .. sink
		end
	end
	return true, nil
end

return TrapCatalog
