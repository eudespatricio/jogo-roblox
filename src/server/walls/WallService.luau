--!strict
-- Muralha e economia (S3): colocar, remover e evoluir armadilhas com validacao server-side.
-- Puro Luau (nenhuma API do Roblox) e com schema injetado: o contrato roda no CLI
-- (sim/walls-contract.luau) e o servidor usa o mesmo modulo.
-- Persiste mutando Profile.Data.wall.cells e Profile.Data.gold; o ProfileStore autosalva.
-- Eventos saem como { name, props }; o sink (S7) monta o envelope. Nada aqui toca o motor.
--
-- Regras da S3:
--   * grade 5x5, celula rXcY, N=5 ativas, colocacao livre (o schema e a fonte da grade);
--   * desbloqueio por liga: 100 pontos por liga; a tabela CATALOG define o minimo;
--   * remover nao devolve ouro (a taxonomia v1 nao tem source de refund);
--   * upgrade vai ate MAX_LEVEL (3 niveis; GDD secao 5) e custa upgrade * nivel atual;
--   * gold_earned so aceita raid/defense/daily (enums da taxonomia v1).

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
	emit: ((name: string, props: { [string]: any }) -> ())?,
}

WallService.POINTS_PER_LEAGUE = 100
WallService.MAX_LEVEL = 3

WallService.TRAP_IDS = table.freeze({ "archer", "oil", "frost", "cannon" })
-- Catalogo economico dos 4 tipos que o motor v2 simula. O 5o tipo do GDD so entra
-- quando o motor souber simula-lo; nao inventar tipo aqui.

WallService.CATALOG = table.freeze({
	archer = table.freeze({ cost = 40, upgrade = 30, unlockLeague = 1 }),
	oil = table.freeze({ cost = 60, upgrade = 45, unlockLeague = 2 }),
	frost = table.freeze({ cost = 90, upgrade = 65, unlockLeague = 3 }),
	cannon = table.freeze({ cost = 140, upgrade = 100, unlockLeague = 4 }),
}) :: { [string]: TrapDef }

WallService.GOLD_SOURCES = table.freeze({ raid = true, defense = true, daily = true })

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

function WallService.leagueOf(points: number): number
	if points < 0 then
		return 1
	end
	return 1 + math.floor(points / WallService.POINTS_PER_LEAGUE)
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

-- Cria o controlador de uma muralha. `profile` e o Profile.Data vivo: as operacoes mutam
-- `wall.cells` e `gold`; o chamador decide quando salvar (o ProfileStore autosalva).
-- API no estilo do ProfileService: chame com ponto (`service.place(...)`), nao com dois-pontos.
function WallService.new(options: Options): Controller
	assert(type(options) == "table", "WallService.new: options ausente")
	local profile = options.profile
	local schema = options.schema
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
		schema.MAX_TRAP_LEVEL >= WallService.MAX_LEVEL,
		"WallService.new: schema.MAX_TRAP_LEVEL abaixo de MAX_LEVEL"
	)
	local okProfile, profileErr = schema.validate(profile)
	assert(okProfile, "WallService.new: perfil invalido: " .. tostring(profileErr))

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
		local ok, err = schema.validate(profile)
		assert(ok, "WallService: perfil invalido apos " .. action .. ": " .. tostring(err))
	end

	local function place(trapId: string, cell: string): (Result?, string?)
		local def = WallService.CATALOG[trapId]
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
		if WallService.leagueOf(profile.league.points) < def.unlockLeague then
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
		if existing.level >= WallService.MAX_LEVEL then
			return nil, WallService.ERRORS.MAX_LEVEL
		end
		local def = WallService.CATALOG[existing.trap]
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
		if WallService.GOLD_SOURCES[source] ~= true then
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
			return WallService.leagueOf(profile.league.points)
		end,
	}
end

return WallService
