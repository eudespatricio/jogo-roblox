--!strict
-- Muralha e economia (S3): colocar, remover e evoluir armadilhas com validacao server-side.
-- Puro Luau (nenhuma API do Roblox) e com schema/catalogo injetados: o contrato roda no CLI
-- (sim/walls-contract.luau) e o servidor usa o mesmo modulo.
-- Persiste mutando Profile.Data.wall.cells e Profile.Data.gold; o ProfileStore autosalva.
-- Eventos saem como { name, props }; o sink (S7) monta o envelope. Nada aqui toca o motor.
--
-- Regras da S3:
--   * grade 5x5, celula rXcY, N=5 ativas, colocacao livre (o schema e a fonte da grade);
--   * catalogo injetado (src/shared/data/TrapCatalog.luau): custo, upgrade, liga e nivel;
--   * remover nao devolve ouro (a taxonomia v1 nao tem source de refund);
--   * upgrade vai ate catalog.MAX_LEVEL e custa upgrade * nivel atual;
--   * gold_earned so aceita as sources do catalogo (hoje raid/defense/daily).

local WallService = {}

export type Cell = { trap: string, level: number }
export type Profile = {
	wall: { gridWidth: number, activeTrapLimit: number, cells: { [string]: Cell } },
	gold: number,
	league: { points: number, season: number },
}
export type Schema = {
	GRID_WIDTH: number,
	GRID_HEIGHT: number,
	ACTIVE_TRAP_LIMIT: number,
	MAX_TRAP_LEVEL: number,
	MAX_GOLD: number,
	validate: (data: any) -> (boolean, string?),
}
export type TrapDef = { cost: number, upgrade: number, unlockLeague: number }
export type Catalog = {
	CONTENT_VERSION: number,
	POINTS_PER_LEAGUE: number,
	MAX_LEVEL: number,
	TRAP_IDS: { string },
	TRAPS: { [string]: TrapDef },
	GOLD_SOURCES: { [string]: boolean },
	GOLD_SINKS: { [string]: boolean },
	leagueOf: (points: number) -> number,
	validate: () -> (boolean, string?),
}
export type EventSpec = { name: string, props: { [string]: any } }
export type Result = {
	action: string,
	cell: string?,
	trap: string?,
	level: number?,
	cost: number?,
	amount: number?,
	gold: number,
	events: { EventSpec },
}
export type Snapshot = { gold: number, cells: { [string]: Cell } }
export type Controller = {
	place: (trapId: string, cell: string) -> (Result?, string?),
	remove: (cell: string) -> (Result?, string?),
	upgrade: (cell: string) -> (Result?, string?),
	creditGold: (amount: number, source: string, battleId: string?) -> (Result?, string?),
	snapshot: () -> Snapshot,
	league: () -> number,
}
export type Options = {
	profile: Profile,
	schema: Schema,
	catalog: Catalog,
	emit: ((name: string, props: { [string]: any }) -> ())?,
}

WallService.ERRORS = table.freeze({
	INVALID_CELL = "invalid_cell",
	CELL_OCCUPIED = "cell_occupied",
	EMPTY_CELL = "empty_cell",
	TRAP_LIMIT = "trap_limit",
	UNKNOWN_TRAP = "unknown_trap",
	TRAP_LOCKED = "trap_locked",
	INSUFFICIENT_GOLD = "insufficient_gold",
	MAX_LEVEL = "max_level",
	GOLD_CAP = "gold_cap",
	INVALID_AMOUNT = "invalid_amount",
	INVALID_SOURCE = "invalid_source",
})
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

local function isValidCell(cell: any, gridWidth: number, gridHeight: number): boolean
	if type(cell) ~= "string" then
		return false
	end
	local text = cell :: string
	local rowText, colText = string.match(text, "^r(%d+)c(%d+)$")
	if rowText == nil or colText == nil then
		return false
	end
	local row = tonumber(rowText)
	local col = tonumber(colText)
	if row == nil or col == nil then
		return false
	end
	if row < 1 or row > gridHeight or col < 1 or col > gridWidth then
		return false
	end
	-- forma canonica: "r01c1" nao pode virar um segundo alias da mesma celula
	return string.format("r%dc%d", row, col) == text
end

local function countCells(cells: { [string]: Cell }): number
	local count = 0
	for _ in pairs(cells) do
		count += 1
	end
	return count
end

local function copyCells(cells: { [string]: Cell }): { [string]: Cell }
	local copy: { [string]: Cell } = {}
	for key, cell in pairs(cells) do
		copy[key] = { trap = cell.trap, level = cell.level }
	end
	return copy
end

local function event(name: string, props: { [string]: any }): EventSpec
	return { name = name, props = props }
end

-- Valida a parede que veio do perfil antes de qualquer operacao (e antes de S4/S6
-- converterem cells em wall.traps). Falha fechado: trap desconhecida, celula fora da
-- grade, N acima do limite ou nivel acima do cap economico nunca chegam ao motor.
function WallService.validateWall(
	profile: Profile,
	schema: Schema,
	catalog: Catalog
): (boolean, string?)
	local okProfile, profileErr = schema.validate(profile)
	if not okProfile then
		return false, "perfil: " .. tostring(profileErr)
	end
	local okCatalog, catalogErr = catalog.validate()
	if not okCatalog then
		return false, "catalogo: " .. tostring(catalogErr)
	end

	local gridWidth = math.min(profile.wall.gridWidth, schema.GRID_WIDTH)
	local gridHeight = schema.GRID_HEIGHT
	local trapLimit = math.min(profile.wall.activeTrapLimit, schema.ACTIVE_TRAP_LIMIT)

	local total = countCells(profile.wall.cells)
	if total > trapLimit then
		return false, string.format("wall.cells com %d ativas (limite %d)", total, trapLimit)
	end
	for cell, data in pairs(profile.wall.cells) do
		if not isValidCell(cell, gridWidth, gridHeight) then
			return false, "wall.cells com celula invalida: " .. tostring(cell)
		end
		if catalog.TRAPS[data.trap] == nil then
			return false,
				"wall.cells[" .. tostring(cell) .. "] com trap desconhecida: " .. tostring(
					data.trap
				)
		end
		if not isInteger(data.level) or data.level < 1 or data.level > catalog.MAX_LEVEL then
			return false,
				"wall.cells[" .. tostring(cell) .. "] com level fora de [1," .. tostring(
					catalog.MAX_LEVEL
				) .. "]"
		end
	end
	return true, nil
end

-- Cria o controlador de uma muralha. `profile` e o Profile.Data vivo: as operacoes mutam
-- `wall.cells` e `gold`; o chamador decide quando salvar (o ProfileStore autosalva).
-- API no estilo do ProfileService: chame com ponto (`service.place(...)`), nao com dois-pontos.
function WallService.new(options: Options): Controller
	assert(type(options) == "table", "WallService.new: options ausente")
	local profile = options.profile
	local schema = options.schema
	local catalog = options.catalog
	assert(type(profile) == "table", "WallService.new: profile ausente")
	assert(type(profile.wall) == "table", "WallService.new: profile.wall ausente")
	assert(type(profile.wall.cells) == "table", "WallService.new: profile.wall.cells ausente")
	assert(type(profile.league) == "table", "WallService.new: profile.league ausente")
	assert(
		isInteger(profile.league.points) and profile.league.points >= 0,
		"WallService.new: league.points invalido"
	)
	assert(isInteger(profile.gold) and profile.gold >= 0, "WallService.new: gold invalido")
	assert(
		type(schema) == "table"
			and isInteger(schema.GRID_WIDTH)
			and isInteger(schema.GRID_HEIGHT)
			and isInteger(schema.ACTIVE_TRAP_LIMIT)
			and isInteger(schema.MAX_TRAP_LEVEL)
			and isInteger(schema.MAX_GOLD),
		"WallService.new: schema incompleto"
	)
	assert(
		type(catalog) == "table"
			and type(catalog.TRAPS) == "table"
			and type(catalog.TRAP_IDS) == "table"
			and type(catalog.GOLD_SOURCES) == "table"
			and type(catalog.GOLD_SINKS) == "table"
			and type(catalog.leagueOf) == "function"
			and type(catalog.validate) == "function"
			and isInteger(catalog.MAX_LEVEL)
			and isInteger(catalog.POINTS_PER_LEAGUE),
		"WallService.new: catalogo incompleto"
	)
	local okCatalog, catalogErr = catalog.validate()
	assert(okCatalog, "WallService.new: catalogo invalido: " .. tostring(catalogErr))
	assert(
		schema.MAX_TRAP_LEVEL >= catalog.MAX_LEVEL,
		"WallService.new: schema.MAX_TRAP_LEVEL abaixo de catalog.MAX_LEVEL"
	)

	local okWall, wallErr = WallService.validateWall(profile, schema, catalog)
	assert(okWall, "WallService.new: " .. tostring(wallErr))

	-- A grade da P1 e 5x5 e N=5; o perfil pode carregar um limite maior no futuro,
	-- mas a S3 nunca passa do que o motor v2 simula.
	local gridWidth = math.min(profile.wall.gridWidth, schema.GRID_WIDTH)
	local gridHeight = schema.GRID_HEIGHT
	local trapLimit = math.min(profile.wall.activeTrapLimit, schema.ACTIVE_TRAP_LIMIT)

	local emit = options.emit
	assert(emit == nil or type(emit) == "function", "WallService.new: emit invalido")

	local function publish(events: { EventSpec })
		if emit == nil then
			return
		end
		for _, spec in ipairs(events) do
			emit(spec.name, spec.props)
		end
	end

	local function validateAfter(action: string)
		local ok, err = WallService.validateWall(profile, schema, catalog)
		assert(ok, "WallService: perfil invalido apos " .. action .. ": " .. tostring(err))
	end

	local function place(trapId: string, cell: string): (Result?, string?)
		local def = catalog.TRAPS[trapId]
		if def == nil then
			return nil, WallService.ERRORS.UNKNOWN_TRAP
		end
		if not isValidCell(cell, gridWidth, gridHeight) then
			return nil, WallService.ERRORS.INVALID_CELL
		end
		if profile.wall.cells[cell] ~= nil then
			return nil, WallService.ERRORS.CELL_OCCUPIED
		end
		if countCells(profile.wall.cells) >= trapLimit then
			return nil, WallService.ERRORS.TRAP_LIMIT
		end
		if catalog.leagueOf(profile.league.points) < def.unlockLeague then
			return nil, WallService.ERRORS.TRAP_LOCKED
		end
		if profile.gold < def.cost then
			return nil, WallService.ERRORS.INSUFFICIENT_GOLD
		end

		local events = {
			event("trap_placed", { trap_id = trapId, cell = cell, cost = def.cost }),
			event("gold_spent", { amount = def.cost, sink = "trap" }),
		}
		profile.gold -= def.cost
		profile.wall.cells[cell] = { trap = trapId, level = 1 }
		validateAfter("place")
		publish(events)

		local result: Result = {
			action = "place",
			cell = cell,
			trap = trapId,
			level = 1,
			cost = def.cost,
			gold = profile.gold,
			events = events,
		}
		return result, nil
	end

	local function remove(cell: string): (Result?, string?)
		if not isValidCell(cell, gridWidth, gridHeight) then
			return nil, WallService.ERRORS.INVALID_CELL
		end
		local existing = profile.wall.cells[cell]
		if existing == nil then
			return nil, WallService.ERRORS.EMPTY_CELL
		end

		profile.wall.cells[cell] = nil
		validateAfter("remove")
		local result: Result = {
			action = "remove",
			cell = cell,
			trap = existing.trap,
			level = existing.level,
			gold = profile.gold,
			events = {},
		}
		return result, nil
	end

	local function upgrade(cell: string): (Result?, string?)
		if not isValidCell(cell, gridWidth, gridHeight) then
			return nil, WallService.ERRORS.INVALID_CELL
		end
		local existing = profile.wall.cells[cell]
		if existing == nil then
			return nil, WallService.ERRORS.EMPTY_CELL
		end
		if existing.level >= catalog.MAX_LEVEL then
			return nil, WallService.ERRORS.MAX_LEVEL
		end
		local def = catalog.TRAPS[existing.trap]
		if def == nil then
			return nil, WallService.ERRORS.UNKNOWN_TRAP
		end

		local cost = def.upgrade * existing.level
		if profile.gold < cost then
			return nil, WallService.ERRORS.INSUFFICIENT_GOLD
		end
		local newLevel = existing.level + 1
		local events = {
			event("upgrade_bought", { target = cell, level = newLevel, cost = cost }),
			event("gold_spent", { amount = cost, sink = "upgrade" }),
		}
		profile.gold -= cost
		existing.level = newLevel
		validateAfter("upgrade")
		publish(events)

		local result: Result = {
			action = "upgrade",
			cell = cell,
			trap = existing.trap,
			level = newLevel,
			cost = cost,
			gold = profile.gold,
			events = events,
		}
		return result, nil
	end

	local function creditGold(amount: number, source: string, battleId: string?): (Result?, string?)
		if not isInteger(amount) or amount <= 0 then
			return nil, WallService.ERRORS.INVALID_AMOUNT
		end
		if catalog.GOLD_SOURCES[source] ~= true then
			return nil, WallService.ERRORS.INVALID_SOURCE
		end
		if profile.gold + amount > schema.MAX_GOLD then
			return nil, WallService.ERRORS.GOLD_CAP
		end

		local props: { [string]: any } = { amount = amount, source = source }
		if battleId ~= nil then
			props.battle_id = battleId
		end
		local events = { event("gold_earned", props) }
		profile.gold += amount
		validateAfter("creditGold")
		publish(events)

		local result: Result = {
			action = "credit_gold",
			amount = amount,
			gold = profile.gold,
			events = events,
		}
		return result, nil
	end

	return {
		place = place,
		remove = remove,
		upgrade = upgrade,
		creditGold = creditGold,
		snapshot = function(): Snapshot
			return { gold = profile.gold, cells = copyCells(profile.wall.cells) }
		end,
		league = function(): number
			return catalog.leagueOf(profile.league.points)
		end,
	}
end

return WallService
