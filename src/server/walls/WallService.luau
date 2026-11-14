--!strict
-- Servico puro da muralha: colocacao (grade 5x5 e posicao livre), movimento 0g,
-- remocao, upgrade (Nv1..5), upgrade da muralha (Nv1..5), cosmeticos e conversao para batalha.
-- Sem API do Roblox: testado diretamente em CLI (sim/walls-contract.luau).

local WallService = {}

export type Cell = { trap: string, level: number, x: number, y: number }
export type Equipped = {
	theme: string,
	hordeSkin: string,
	finisher: string,
	commander: string,
}
export type WallLevelDef = { cost: number, unlockLeague: number, hp: number, trapLimit: number }
export type Profile = {
	contentVersion: number,
	wall: {
		level: number,
		gridWidth: number,
		activeTrapLimit: number,
		cells: { [string]: Cell },
	},
	gold: number,
	league: { points: number, season: number },
	cosmetics: { [string]: boolean }?,
	equipped: Equipped?,
}
export type Schema = {
	GRID_WIDTH: number,
	GRID_HEIGHT: number,
	ACTIVE_TRAP_LIMIT: number,
	MAX_TRAP_LEVEL: number,
	MAX_WALL_LEVEL: number?,
	MAX_GOLD: number,
	MAX_ID_LENGTH: number?,
	EQUIPPED_DEFAULTS: Equipped?,
	COLUMN_X: { number }?,
	isValidSlot: ((slot: any) -> boolean)?,
	validatePosition: ((x: any, y: any) -> (boolean, string?))?,
	tooClose: ((ax: number, ay: number, bx: number, by: number) -> boolean)?,
	cellToPos: ((cell: any) -> (number?, number?))?,
	validate: (data: any) -> (boolean, string?),
}
export type TrapDef = { cost: number, upgrade: number, unlockLeague: number }
export type Catalog = {
	CONTENT_VERSION: number,
	POINTS_PER_LEAGUE: number,
	MAX_LEVEL: number,
	MAX_WALL_LEVEL: number?,
	TRAPS: { [string]: TrapDef },
	TRAP_IDS: { string }?,
	TRAP_ALIASES: { [string]: string }?,
	WALL_LEVELS: { WallLevelDef }?,
	GOLD_SOURCES: { [string]: boolean },
	GOLD_SINKS: { [string]: boolean }?,
	upgradeCost: (trapId: string, level: number) -> number?,
	wallUpgradeCost: ((level: number) -> number?)?,
	ensureProfileContent: ((profile: any) -> (boolean, string?, boolean))?,
	leagueOf: (points: number) -> number,
	validate: () -> (boolean, string?),
}
export type EventSpec = { name: string, props: { [string]: any } }
export type Result = {
	action: string,
	cell: string?,
	slot: string?,
	trap: string?,
	level: number?,
	x: number?,
	y: number?,
	cost: number?,
	amount: number?,
	gold: number,
	wallLevel: number?,
	cosmeticId: string?,
	events: { EventSpec },
}
export type Snapshot = {
	gold: number,
	wallLevel: number,
	wallHp: number,
	activeTrapLimit: number,
	cells: { [string]: Cell },
	equipped: Equipped,
}
export type BattleTrap = {
	cell: string?,
	type: string,
	level: number,
	x: number,
	y: number,
}
export type BattleWall = { level: number, hp: number, traps: { BattleTrap } }
export type Controller = {
	place: (trapId: string, cellOrSlot: string, x: number?, y: number?) -> (Result?, string?),
	placeAt: (trapId: string, x: number, y: number, slot: string?) -> (Result?, string?),
	move: (slot: string, x: number, y: number) -> (Result?, string?),
	remove: (slot: string) -> (Result?, string?),
	upgrade: (slot: string) -> (Result?, string?),
	upgradeWall: () -> (Result?, string?),
	equipCosmetic: (slotName: string, cosmeticId: string) -> (Result?, string?),
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
	INVALID_SLOT = "invalid_slot",
	INVALID_POSITION = "invalid_position",
	TOO_CLOSE = "too_close",
	CELL_OCCUPIED = "cell_occupied",
	EMPTY_CELL = "empty_cell",
	TRAP_LIMIT = "trap_limit",
	UNKNOWN_TRAP = "unknown_trap",
	TRAP_LOCKED = "trap_locked",
	INSUFFICIENT_GOLD = "insufficient_gold",
	MAX_LEVEL = "max_level",
	MAX_WALL_LEVEL = "max_wall_level",
	WALL_LOCKED = "wall_locked",
	NOT_OWNED = "not_owned",
	UNKNOWN_COSMETIC = "unknown_cosmetic",
	GOLD_CAP = "gold_cap",
	INVALID_AMOUNT = "invalid_amount",
	INVALID_SOURCE = "invalid_source",
	CONTENT_VERSION = "content_version",
	CONTENT_FUTURE = "content_future",
})

local FALLBACK_COLUMN_X = { 2000, 3500, 5000, 6500, 8000 }
local FALLBACK_WALL_LEVELS: { WallLevelDef } = {
	{ cost = 0, unlockLeague = 1, hp = 500, trapLimit = 5 },
	{ cost = 150, unlockLeague = 1, hp = 650, trapLimit = 5 },
	{ cost = 350, unlockLeague = 3, hp = 800, trapLimit = 6 },
	{ cost = 700, unlockLeague = 4, hp = 1000, trapLimit = 6 },
	{ cost = 1200, unlockLeague = 5, hp = 1250, trapLimit = 7 },
}
local FALLBACK_EQUIPPED: Equipped = {
	theme = "theme_default",
	hordeSkin = "horde_default",
	finisher = "finisher_default",
	commander = "cmd_vorn",
}

local function isInteger(value: any): boolean
	if type(value) ~= "number" then
		return false
	end
	local n = value :: number
	return n == n and n ~= math.huge and n ~= -math.huge and n % 1 == 0
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
	local row = tonumber(rowText) :: number
	local col = tonumber(colText) :: number
	if row < 1 or row > gridHeight or col < 1 or col > gridWidth then
		return false
	end
	return string.format("r%dc%d", row, col) == text
end

local function isValidSlot(slot: any, schema: Schema): boolean
	if schema.isValidSlot ~= nil then
		return schema.isValidSlot(slot)
	end
	if type(slot) ~= "string" then
		return false
	end
	local s = slot :: string
	return #s > 0 and #s <= 16 and string.match(s, "^[a-z0-9_]+$") ~= nil
end

local function validatePosition(x: any, y: any, schema: Schema): boolean
	if schema.validatePosition ~= nil then
		local ok = schema.validatePosition(x, y)
		return ok
	end
	if not isInteger(x) or not isInteger(y) then
		return false
	end
	local nx = x :: number
	local ny = y :: number
	return nx >= 1000
		and nx <= 9000
		and ny >= 500
		and ny <= 4500
		and nx % 250 == 0
		and ny % 250 == 0
end

local function positionsTooClose(
	ax: number,
	ay: number,
	bx: number,
	by: number,
	schema: Schema
): boolean
	if schema.tooClose ~= nil then
		return schema.tooClose(ax, ay, bx, by)
	end
	return math.abs(ax - bx) < 1000 and math.abs(ay - by) < 1000
end

local function cellToPos(cell: string, schema: Schema): (number?, number?)
	if schema.cellToPos ~= nil then
		return schema.cellToPos(cell)
	end
	local rowText, colText = string.match(cell, "^r(%d+)c(%d+)$")
	if rowText == nil or colText == nil then
		return nil, nil
	end
	local row = tonumber(rowText) :: number
	local col = tonumber(colText) :: number
	local cx = FALLBACK_COLUMN_X[col]
	if cx == nil or row < 1 or row > 5 then
		return nil, nil
	end
	return cx, row * 1000 - 500
end

local function posToCell(x: number, y: number, schema: Schema): string?
	local cols = schema.COLUMN_X or FALLBACK_COLUMN_X
	if (y + 500) % 1000 ~= 0 then
		return nil
	end
	local row = (y + 500) / 1000
	if row < 1 or row > schema.GRID_HEIGHT or row % 1 ~= 0 then
		return nil
	end
	for col = 1, math.min(#cols, schema.GRID_WIDTH) do
		if cols[col] == x then
			return string.format("r%dc%d", row, col)
		end
	end
	return nil
end

local function getWallLevelDef(catalog: Catalog, level: number): WallLevelDef
	if catalog.WALL_LEVELS ~= nil and catalog.WALL_LEVELS[level] ~= nil then
		return catalog.WALL_LEVELS[level]
	end
	return FALLBACK_WALL_LEVELS[level] or FALLBACK_WALL_LEVELS[1]
end

local function getMaxWallLevel(schema: Schema, catalog: Catalog): number
	local cMax = catalog.MAX_WALL_LEVEL or #FALLBACK_WALL_LEVELS
	local sMax = schema.MAX_WALL_LEVEL or cMax
	return math.min(cMax, sMax)
end

local function getEquippedDefaults(schema: Schema): Equipped
	return schema.EQUIPPED_DEFAULTS or FALLBACK_EQUIPPED
end

local function copyEquipped(equipped: Equipped?, schema: Schema): Equipped
	local defaults = getEquippedDefaults(schema)
	local src: { [string]: any } = (equipped :: any) or {}
	return {
		theme = if type(src.theme) == "string" then src.theme else defaults.theme,
		hordeSkin = if type(src.hordeSkin) == "string" then src.hordeSkin else defaults.hordeSkin,
		finisher = if type(src.finisher) == "string" then src.finisher else defaults.finisher,
		commander = if type(src.commander) == "string" then src.commander else defaults.commander,
	}
end

local function countCells(cells: { [string]: Cell }): number
	local total = 0
	for _ in pairs(cells) do
		total += 1
	end
	return total
end

local function copyCells(cells: { [string]: Cell }): { [string]: Cell }
	local out: { [string]: Cell } = {}
	for slot, cell in pairs(cells) do
		out[slot] = { trap = cell.trap, level = cell.level, x = cell.x, y = cell.y }
	end
	return out
end

local function event(name: string, props: { [string]: any }): EventSpec
	return { name = name, props = props }
end

local function hasConflictWithOther(
	cells: { [string]: Cell },
	x: number,
	y: number,
	ignoreSlot: string?,
	schema: Schema
): boolean
	for slot, data in pairs(cells) do
		if slot ~= ignoreSlot and positionsTooClose(x, y, data.x, data.y, schema) then
			return true
		end
	end
	return false
end

local function nextAutoSlot(cells: { [string]: Cell }): string
	local idx = 1
	while true do
		local candidate = "t" .. tostring(idx)
		if cells[candidate] == nil then
			return candidate
		end
		idx += 1
	end
end

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
	if
		not isInteger(profile.contentVersion)
		or profile.contentVersion < catalog.CONTENT_VERSION
	then
		return false, WallService.ERRORS.CONTENT_VERSION
	end
	if profile.contentVersion > catalog.CONTENT_VERSION then
		return false, WallService.ERRORS.CONTENT_FUTURE
	end

	local maxWallLevel = getMaxWallLevel(schema, catalog)
	local wallLevel = profile.wall.level or 1
	if not isInteger(wallLevel) or wallLevel < 1 or wallLevel > maxWallLevel then
		return false, WallService.ERRORS.MAX_WALL_LEVEL
	end
	local wallDef = getWallLevelDef(catalog, wallLevel)
	if profile.wall.activeTrapLimit > wallDef.trapLimit then
		return false, WallService.ERRORS.TRAP_LIMIT
	end

	local maxTrapLevel = math.min(catalog.MAX_LEVEL, schema.MAX_TRAP_LEVEL)
	local placed = {}
	local count = 0
	for slot, cell in pairs(profile.wall.cells) do
		count += 1
		if not isValidSlot(slot, schema) then
			return false, WallService.ERRORS.INVALID_SLOT
		end
		if catalog.TRAPS[cell.trap] == nil then
			return false, WallService.ERRORS.UNKNOWN_TRAP .. ": " .. tostring(cell.trap)
		end
		if not isInteger(cell.level) or cell.level < 1 or cell.level > maxTrapLevel then
			return false, WallService.ERRORS.MAX_LEVEL .. ": " .. tostring(slot)
		end
		if not validatePosition(cell.x, cell.y, schema) then
			return false, WallService.ERRORS.INVALID_POSITION .. ": " .. tostring(slot)
		end
		for _, prev in ipairs(placed) do
			if positionsTooClose(cell.x, cell.y, prev.x, prev.y, schema) then
				return false, WallService.ERRORS.TOO_CLOSE .. ": " .. tostring(slot)
			end
		end
		placed[#placed + 1] = cell
	end
	if count > profile.wall.activeTrapLimit then
		return false, WallService.ERRORS.TRAP_LIMIT
	end
	return true, nil
end

-- Ordenacao deterministica por (y, x), desempate por slot: a batalha nao depende de hash order.
function WallService.toBattleWall(
	profile: Profile,
	schema: Schema,
	catalog: Catalog,
	hp: number?
): (BattleWall?, string?)
	local ok, err = WallService.validateWall(profile, schema, catalog)
	if not ok then
		return nil, err
	end
	local wallLevel = profile.wall.level or 1
	local resolvedHp = if hp ~= nil then hp else getWallLevelDef(catalog, wallLevel).hp
	assert(
		isInteger(resolvedHp) and resolvedHp > 0,
		"toBattleWall: hp invalido (" .. tostring(resolvedHp) .. ")"
	)

	local ordered: { { slot: string, trap: Cell } } = {}
	for slot, data in pairs(profile.wall.cells) do
		ordered[#ordered + 1] = { slot = slot, trap = data }
	end
	table.sort(ordered, function(a, b)
		if a.trap.y ~= b.trap.y then
			return a.trap.y < b.trap.y
		end
		if a.trap.x ~= b.trap.x then
			return a.trap.x < b.trap.x
		end
		return a.slot < b.slot
	end)

	local traps: { BattleTrap } = {}
	for _, entry in ipairs(ordered) do
		local exactCell = posToCell(entry.trap.x, entry.trap.y, schema)
		traps[#traps + 1] = {
			cell = exactCell,
			type = entry.trap.trap,
			level = entry.trap.level,
			x = entry.trap.x,
			y = entry.trap.y,
		}
	end
	return { level = wallLevel, hp = resolvedHp, traps = traps }, nil
end

function WallService.new(options: Options): Controller
	local profile = options.profile
	local schema = options.schema
	local catalog = options.catalog
	local emit = options.emit

	local okWall, wallErr = WallService.validateWall(profile, schema, catalog)
	assert(okWall, "WallService.new: perfil invalido: " .. tostring(wallErr))

	if profile.equipped == nil then
		profile.equipped = copyEquipped(nil, schema)
	end

	local function currentLeague(): number
		return catalog.leagueOf(profile.league.points)
	end

	local function currentWallLevel(): number
		return profile.wall.level or 1
	end

	local function currentTrapLimit(): number
		local wallDef = getWallLevelDef(catalog, currentWallLevel())
		return math.min(profile.wall.activeTrapLimit, wallDef.trapLimit)
	end

	local function emitAll(events: { EventSpec })
		if emit == nil then
			return
		end
		for _, item in ipairs(events) do
			emit(item.name, item.props)
		end
	end

	local function fail(code: string): (Result?, string?)
		return nil, code
	end

	local function placeInternal(
		trapId: string,
		slotArg: string,
		px: number,
		py: number
	): (Result?, string?)
		local cells = profile.wall.cells
		local slot = slotArg
		if slot == "" then
			slot = nextAutoSlot(cells)
		else
			if not isValidSlot(slot, schema) then
				return fail(WallService.ERRORS.INVALID_SLOT)
			end
			if cells[slot] ~= nil then
				return fail(WallService.ERRORS.CELL_OCCUPIED)
			end
		end

		if not validatePosition(px, py, schema) then
			return fail(WallService.ERRORS.INVALID_POSITION)
		end
		if hasConflictWithOther(cells, px, py, nil, schema) then
			return fail(WallService.ERRORS.TOO_CLOSE)
		end
		if countCells(cells) >= currentTrapLimit() then
			return fail(WallService.ERRORS.TRAP_LIMIT)
		end

		local def = if type(trapId) == "string" then catalog.TRAPS[trapId] else nil
		if def == nil then
			return fail(WallService.ERRORS.UNKNOWN_TRAP)
		end
		if currentLeague() < def.unlockLeague then
			return fail(WallService.ERRORS.TRAP_LOCKED)
		end
		if profile.gold < def.cost then
			return fail(WallService.ERRORS.INSUFFICIENT_GOLD)
		end

		profile.gold -= def.cost
		cells[slot] = { trap = trapId, level = 1, x = px, y = py }

		local exactCell = posToCell(px, py, schema)
		local placeProps: { [string]: any } = {
			trap_id = trapId,
			cost = def.cost,
			x = px,
			y = py,
			level = 1,
			slot = slot,
		}
		if exactCell ~= nil then
			placeProps.cell = exactCell
		end

		local events = {
			event("trap_placed", placeProps),
			event("gold_spent", { amount = def.cost, sink = "trap" }),
		}
		emitAll(events)
		return {
			action = "place",
			cell = exactCell,
			slot = slot,
			trap = trapId,
			level = 1,
			x = px,
			y = py,
			cost = def.cost,
			gold = profile.gold,
			events = events,
		},
			nil
	end

	local function resolveExistingSlotError(slot: any): string
		if type(slot) ~= "string" then
			return WallService.ERRORS.INVALID_SLOT
		end
		local text = slot :: string
		if string.match(text, "^r%d+c%d+$") ~= nil then
			if not isValidCell(text, schema.GRID_WIDTH, schema.GRID_HEIGHT) then
				return WallService.ERRORS.INVALID_CELL
			end
		elseif not isValidSlot(text, schema) then
			return WallService.ERRORS.INVALID_SLOT
		end
		return WallService.ERRORS.EMPTY_CELL
	end

	local controller: Controller = {
		place = function(
			trapId: string,
			cellOrSlot: string,
			x: number?,
			y: number?
		): (Result?, string?)
			if x == nil and y == nil then
				if not isValidCell(cellOrSlot, schema.GRID_WIDTH, schema.GRID_HEIGHT) then
					return fail(WallService.ERRORS.INVALID_CELL)
				end
				if profile.wall.cells[cellOrSlot] ~= nil then
					return fail(WallService.ERRORS.CELL_OCCUPIED)
				end
				local cx, cy = cellToPos(cellOrSlot, schema)
				if cx == nil or cy == nil then
					return fail(WallService.ERRORS.INVALID_CELL)
				end
				return placeInternal(trapId, cellOrSlot, cx, cy)
			end
			if x == nil or y == nil then
				return fail(WallService.ERRORS.INVALID_POSITION)
			end
			if type(cellOrSlot) ~= "string" then
				return fail(WallService.ERRORS.INVALID_SLOT)
			end
			return placeInternal(trapId, cellOrSlot, x, y)
		end,

		placeAt = function(trapId: string, x: number, y: number, slot: string?): (Result?, string?)
			return placeInternal(trapId, slot or "", x, y)
		end,

		move = function(slot: string, x: number, y: number): (Result?, string?)
			if not isValidSlot(slot, schema) then
				return fail(WallService.ERRORS.INVALID_SLOT)
			end
			local existing = profile.wall.cells[slot]
			if existing == nil then
				return fail(resolveExistingSlotError(slot))
			end
			if not validatePosition(x, y, schema) then
				return fail(WallService.ERRORS.INVALID_POSITION)
			end
			if hasConflictWithOther(profile.wall.cells, x, y, slot, schema) then
				return fail(WallService.ERRORS.TOO_CLOSE)
			end

			local oldX, oldY = existing.x, existing.y
			existing.x = x
			existing.y = y

			local events = {
				event("trap_moved", {
					slot = slot,
					trap_id = existing.trap,
					level = existing.level,
					from_x = oldX,
					from_y = oldY,
					x = x,
					y = y,
				}),
			}
			emitAll(events)
			return {
				action = "move",
				slot = slot,
				cell = posToCell(x, y, schema),
				trap = existing.trap,
				level = existing.level,
				x = x,
				y = y,
				cost = 0,
				gold = profile.gold,
				events = events,
			},
				nil
		end,

		remove = function(slot: string): (Result?, string?)
			if type(slot) ~= "string" then
				return fail(WallService.ERRORS.INVALID_SLOT)
			end
			local existing = profile.wall.cells[slot]
			if existing == nil then
				return fail(resolveExistingSlotError(slot))
			end
			profile.wall.cells[slot] = nil
			return {
				action = "remove",
				slot = slot,
				cell = posToCell(existing.x, existing.y, schema),
				trap = existing.trap,
				level = existing.level,
				x = existing.x,
				y = existing.y,
				gold = profile.gold,
				events = {},
			},
				nil
		end,

		upgrade = function(slot: string): (Result?, string?)
			if type(slot) ~= "string" then
				return fail(WallService.ERRORS.INVALID_SLOT)
			end
			local existing = profile.wall.cells[slot]
			if existing == nil then
				return fail(resolveExistingSlotError(slot))
			end
			local maxLevel = math.min(catalog.MAX_LEVEL, schema.MAX_TRAP_LEVEL)
			if existing.level >= maxLevel then
				return fail(WallService.ERRORS.MAX_LEVEL)
			end
			local cost = catalog.upgradeCost(existing.trap, existing.level)
			if cost == nil then
				return fail(WallService.ERRORS.MAX_LEVEL)
			end
			if profile.gold < cost then
				return fail(WallService.ERRORS.INSUFFICIENT_GOLD)
			end

			profile.gold -= cost
			existing.level += 1
			local events = {
				event("upgrade_bought", {
					target = slot,
					level = existing.level,
					cost = cost,
					trap_id = existing.trap,
					x = existing.x,
					y = existing.y,
				}),
				event("gold_spent", { amount = cost, sink = "upgrade" }),
			}
			emitAll(events)
			return {
				action = "upgrade",
				slot = slot,
				cell = posToCell(existing.x, existing.y, schema),
				trap = existing.trap,
				level = existing.level,
				x = existing.x,
				y = existing.y,
				cost = cost,
				gold = profile.gold,
				events = events,
			},
				nil
		end,

		upgradeWall = function(): (Result?, string?)
			local level = currentWallLevel()
			local maxWallLevel = getMaxWallLevel(schema, catalog)
			if level >= maxWallLevel then
				return fail(WallService.ERRORS.MAX_WALL_LEVEL)
			end
			local nextLevel = level + 1
			local nextDef = getWallLevelDef(catalog, nextLevel)
			if currentLeague() < nextDef.unlockLeague then
				return fail(WallService.ERRORS.WALL_LOCKED)
			end
			local cost = if catalog.wallUpgradeCost ~= nil
				then catalog.wallUpgradeCost(level)
				else nextDef.cost
			if cost == nil then
				return fail(WallService.ERRORS.MAX_WALL_LEVEL)
			end
			if profile.gold < cost then
				return fail(WallService.ERRORS.INSUFFICIENT_GOLD)
			end

			profile.gold -= cost
			profile.wall.level = nextLevel
			profile.wall.activeTrapLimit = math.max(profile.wall.activeTrapLimit, nextDef.trapLimit)

			local events = {
				event("wall_upgraded", {
					from_level = level,
					level = nextLevel,
					cost = cost,
				}),
				event("gold_spent", { amount = cost, sink = "wall" }),
			}
			emitAll(events)
			return {
				action = "upgrade_wall",
				level = nextLevel,
				wallLevel = nextLevel,
				cost = cost,
				gold = profile.gold,
				events = events,
			},
				nil
		end,

		equipCosmetic = function(slotName: string, cosmeticId: string): (Result?, string?)
			local defaults = getEquippedDefaults(schema) :: { [string]: string }
			if type(slotName) ~= "string" or defaults[slotName] == nil then
				return fail(WallService.ERRORS.INVALID_SLOT)
			end
			local maxIdLen = schema.MAX_ID_LENGTH or 48
			if
				type(cosmeticId) ~= "string"
				or #cosmeticId == 0
				or #cosmeticId > maxIdLen
				or string.match(cosmeticId, "^[%w_%.%-]+$") == nil
			then
				return fail(WallService.ERRORS.UNKNOWN_COSMETIC)
			end

			local owned = cosmeticId == defaults[slotName]
				or (profile.cosmetics ~= nil and profile.cosmetics[cosmeticId] == true)
			if not owned then
				return fail(WallService.ERRORS.NOT_OWNED)
			end

			local equipped = copyEquipped(profile.equipped, schema) :: { [string]: string }
			equipped[slotName] = cosmeticId
			profile.equipped = equipped :: Equipped

			local events = {
				event("cosmetic_equipped", {
					slot = slotName,
					cosmetic_id = cosmeticId,
				}),
			}
			emitAll(events)
			return {
				action = "equip_cosmetic",
				slot = slotName,
				cosmeticId = cosmeticId,
				gold = profile.gold,
				events = events,
			},
				nil
		end,

		creditGold = function(
			amount: number,
			source: string,
			battleId: string?
		): (Result?, string?)
			if not isInteger(amount) or amount < 1 then
				return fail(WallService.ERRORS.INVALID_AMOUNT)
			end
			if type(source) ~= "string" or catalog.GOLD_SOURCES[source] ~= true then
				return fail(WallService.ERRORS.INVALID_SOURCE)
			end
			if profile.gold + amount > schema.MAX_GOLD then
				return fail(WallService.ERRORS.GOLD_CAP)
			end
			profile.gold += amount

			local props: { [string]: any } = { amount = amount, source = source }
			if type(battleId) == "string" and battleId ~= "" then
				props.battle_id = battleId
			end
			local events = { event("gold_earned", props) }
			emitAll(events)
			return {
				action = "credit_gold",
				amount = amount,
				gold = profile.gold,
				events = events,
			},
				nil
		end,

		snapshot = function(): Snapshot
			local level = currentWallLevel()
			local def = getWallLevelDef(catalog, level)
			return {
				gold = profile.gold,
				wallLevel = level,
				wallHp = def.hp,
				activeTrapLimit = currentTrapLimit(),
				cells = copyCells(profile.wall.cells),
				equipped = copyEquipped(profile.equipped, schema),
			}
		end,

		league = currentLeague,
	}

	return controller
end

return WallService
