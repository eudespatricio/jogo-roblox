--!strict
-- Maquina de estados pura da interface de construcao (cliente).
-- Decide qual intencao (place/upgrade/remove/move) um clique dispara sem falar com Roblox.
-- Testavel no CLI (sim/build-contract.luau); o servidor valida de verdade via BuildProtocol.

local BuildClientState = {}

BuildClientState.MODES = table.freeze({
	place = "place",
	upgrade = "upgrade",
	remove = "remove",
	move = "move",
})

BuildClientState.DEFAULT_MODE = "place"
BuildClientState.DEFAULT_MAX_LEVEL = 5

export type Cell = { trap: string, level: number, x: number?, y: number? }
export type CatalogEntry = {
	id: string,
	cost: number,
	upgrade: number,
	unlockLeague: number,
	unlocked: boolean,
}
export type Snapshot = {
	gold: number,
	league: number,
	schemaVersion: number?,
	contentVersion: number?,
	wallLevel: number?,
	wallHp: number?,
	activeTrapLimit: number?,
	maxTrapLevel: number?,
	maxWallLevel: number?,
	cells: { [string]: Cell },
	catalog: { CatalogEntry },
}
export type State = {
	mode: string,
	selectedTrap: string?,
	snapshot: Snapshot?,
}
export type Intent = {
	action: string,
	trapId: string,
	cell: string,
	slot: string?,
	x: number?,
	y: number?,
}
export type Grid = {
	parseCell: (cell: string) -> (number?, number?),
	validateArenaPos: ((x: any, y: any) -> (boolean, string?))?,
	isValidSlot: ((slot: any) -> boolean)?,
}

function BuildClientState.new(): State
	return { mode = BuildClientState.DEFAULT_MODE, selectedTrap = nil, snapshot = nil }
end

function BuildClientState.isMode(mode: any): boolean
	return type(mode) == "string" and BuildClientState.MODES[mode] ~= nil
end

function BuildClientState.setMode(state: State, mode: any): (boolean, string?)
	if not BuildClientState.isMode(mode) then
		return false, "bad_mode"
	end
	state.mode = mode :: string
	state.selectedTrap = nil
	return true, nil
end

function BuildClientState.selectTrap(state: State, trapId: any): (boolean, string?)
	if type(trapId) ~= "string" or #trapId == 0 then
		return false, "bad_trap"
	end
	if state.snapshot ~= nil and BuildClientState.catalogEntry(state, trapId) == nil then
		return false, "unknown_trap"
	end
	state.selectedTrap = trapId :: string
	state.mode = "place"
	return true, nil
end

function BuildClientState.setSnapshot(state: State, snapshot: any): ()
	if type(snapshot) ~= "table" then
		return
	end
	state.snapshot = snapshot :: Snapshot
end

function BuildClientState.catalogEntry(state: State, trapId: string): CatalogEntry?
	if state.snapshot == nil or type(state.snapshot.catalog) ~= "table" then
		return nil
	end
	for _, entry in ipairs(state.snapshot.catalog) do
		if entry.id == trapId then
			return entry
		end
	end
	return nil
end

function BuildClientState.upgradeCost(state: State, cell: string): number?
	if state.snapshot == nil or type(state.snapshot.cells) ~= "table" then
		return nil
	end
	local current = state.snapshot.cells[cell]
	if current == nil then
		return nil
	end
	local maxLevel = state.snapshot.maxTrapLevel or BuildClientState.DEFAULT_MAX_LEVEL
	if current.level >= maxLevel then
		return nil
	end
	local entry = BuildClientState.catalogEntry(state, current.trap)
	if entry == nil then
		return nil
	end
	return entry.upgrade * current.level
end

function BuildClientState.upgradeRange(entry: CatalogEntry?, maxLevel: number?): (number?, number?)
	if entry == nil then
		return nil, nil
	end
	local cap = maxLevel or BuildClientState.DEFAULT_MAX_LEVEL
	if cap < 2 then
		return entry.upgrade, entry.upgrade
	end
	return entry.upgrade, entry.upgrade * (cap - 1)
end

function BuildClientState.intent(state: State, cell: any, grid: Grid): (Intent?, string?)
	if type(cell) ~= "string" then
		return nil, "bad_cell"
	end
	local row, col = grid.parseCell(cell)
	if row == nil or col == nil then
		return nil, "bad_cell"
	end
	if state.snapshot == nil then
		return nil, "no_snapshot"
	end
	local cells = state.snapshot.cells or {}
	local occupied = cells[cell] ~= nil

	if state.mode == "place" then
		if occupied then
			return nil, "cell_occupied"
		end
		if state.selectedTrap == nil or state.selectedTrap == "" then
			return nil, "no_trap"
		end
		return { action = "place", trapId = state.selectedTrap, cell = cell, slot = cell }, nil
	end

	if not occupied then
		return nil, "empty_cell"
	end
	if state.mode == "move" then
		return { action = "move", trapId = "", cell = cell, slot = cell }, nil
	end
	return { action = state.mode, trapId = "", cell = cell, slot = cell }, nil
end

function BuildClientState.intentAt(
	state: State,
	x: any,
	y: any,
	grid: Grid,
	slot: string?
): (Intent?, string?)
	if state.snapshot == nil then
		return nil, "no_snapshot"
	end
	if grid.validateArenaPos ~= nil then
		local ok, err = grid.validateArenaPos(x, y)
		if not ok then
			return nil, err or "invalid_position"
		end
	elseif type(x) ~= "number" or type(y) ~= "number" then
		return nil, "invalid_position"
	end

	if state.mode == "move" then
		if type(slot) ~= "string" or slot == "" then
			return nil, "invalid_slot"
		end
		local cells = state.snapshot.cells or {}
		if cells[slot] == nil then
			return nil, "empty_cell"
		end
		return { action = "move", trapId = "", cell = slot, slot = slot, x = x, y = y }, nil
	end

	if state.selectedTrap == nil or state.selectedTrap == "" then
		return nil, "no_trap"
	end
	local resolvedSlot = slot or ""
	return {
		action = "place",
		trapId = state.selectedTrap,
		cell = resolvedSlot,
		slot = resolvedSlot,
		x = x,
		y = y,
	},
		nil
end

function BuildClientState.intentMove(
	state: State,
	slot: any,
	x: any,
	y: any,
	grid: Grid
): (Intent?, string?)
	if state.snapshot == nil then
		return nil, "no_snapshot"
	end
	if type(slot) ~= "string" or slot == "" then
		return nil, "invalid_slot"
	end
	if grid.isValidSlot ~= nil and not grid.isValidSlot(slot) then
		return nil, "invalid_slot"
	end
	local cells = state.snapshot.cells or {}
	if cells[slot] == nil then
		return nil, "empty_cell"
	end
	if grid.validateArenaPos ~= nil then
		local ok, err = grid.validateArenaPos(x, y)
		if not ok then
			return nil, err or "invalid_position"
		end
	elseif type(x) ~= "number" or type(y) ~= "number" then
		return nil, "invalid_position"
	end
	return { action = "move", trapId = "", cell = slot, slot = slot, x = x, y = y }, nil
end

return BuildClientState
