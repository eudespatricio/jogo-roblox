--!strict
-- Estado puro do cliente de build (S4): modo, armadilha selecionada e intencao de clique.
-- Sem API do Roblox: o BuildClient so desenha, e sim/build-contract.luau prova as regras no CLI.
-- O servidor valida de novo (WallService); aqui so recusamos o obvio antes do round-trip.

local BuildClientState = {}

BuildClientState.MODES = table.freeze({
	place = "place",
	remove = "remove",
	upgrade = "upgrade",
})
BuildClientState.DEFAULT_MODE = "place"

export type Cell = { trap: string, level: number }
export type CatalogEntry = {
	id: string,
	cost: number,
	upgrade: number,
	unlockLeague: number,
}
export type Snapshot = {
	gold: number,
	cells: { [string]: Cell },
	catalog: { CatalogEntry },
	league: number,
	contentVersion: number,
}
export type State = {
	mode: string,
	selectedTrap: string?,
	snapshot: Snapshot?,
}
export type Intent = { action: string, trapId: string, cell: string }
export type Grid = { parseCell: (cell: string) -> (number?, number?) }

function BuildClientState.new(): State
	return { mode = BuildClientState.DEFAULT_MODE, selectedTrap = nil, snapshot = nil }
end

function BuildClientState.isMode(mode: any): boolean
	return type(mode) == "string" and BuildClientState.MODES[mode] == mode
end

-- Trocar de modo limpa a selecao (mesmo comportamento do scaffold: COLOCAR sem trap).
function BuildClientState.setMode(state: State, mode: any): (boolean, string?)
	if not BuildClientState.isMode(mode) then
		return false, "bad_mode"
	end
	state.mode = mode :: string
	state.selectedTrap = nil
	return true, nil
end

-- Escolher uma armadilha volta para o modo place, como no painel inferior.
function BuildClientState.selectTrap(state: State, trapId: any): (boolean, string?)
	if type(trapId) ~= "string" or trapId == "" then
		return false, "bad_trap"
	end
	state.mode = BuildClientState.MODES.place
	state.selectedTrap = trapId :: string
	return true, nil
end

function BuildClientState.setSnapshot(state: State, snapshot: any): ()
	if type(snapshot) ~= "table" or type(snapshot.cells) ~= "table" then
		state.snapshot = nil
		return
	end
	state.snapshot = snapshot :: Snapshot
end

-- Entrada do catalogo para custo/liga na UI; nil enquanto o snapshot nao chegou.
function BuildClientState.catalogEntry(state: State, trapId: string): CatalogEntry?
	local snapshot = state.snapshot
	if snapshot == nil then
		return nil
	end
	for _, entry in ipairs(snapshot.catalog) do
		if entry.id == trapId then
			return entry
		end
	end
	return nil
end

-- Custo do proximo upgrade de uma celula (upgrade base * nivel atual). A UI usa o mesmo
-- numero que o WallService cobra; nil se a celula/snapshot/catalogo ainda nao existe.
function BuildClientState.upgradeCost(state: State, cell: string): number?
	local snapshot = state.snapshot
	if snapshot == nil then
		return nil
	end
	local data = snapshot.cells[cell]
	if data == nil then
		return nil
	end
	local entry = BuildClientState.catalogEntry(state, data.trap)
	if entry == nil or type(entry.upgrade) ~= "number" or type(data.level) ~= "number" then
		return nil
	end
	return entry.upgrade * data.level
end

-- Faixa exibida no cartao no modo UPGRADE: (1->2, 2->3). MAX_LEVEL da P1 e 3.
function BuildClientState.upgradeRange(entry: CatalogEntry?): (number?, number?)
	if entry == nil or type(entry.upgrade) ~= "number" then
		return nil, nil
	end
	return entry.upgrade, entry.upgrade * 2
end

-- Decide a intencao de um clique. Devolve a request (action/trapId/cell) ou o motivo da
-- recusa local. O servidor continua sendo a fonte da verdade para N=5, ouro e liga.
function BuildClientState.intent(state: State, cell: any, grid: Grid): (Intent?, string?)
	local snapshot = state.snapshot
	if snapshot == nil then
		return nil, "no_snapshot"
	end
	if type(cell) ~= "string" then
		return nil, "bad_cell"
	end
	local row, col = grid.parseCell(cell)
	if row == nil or col == nil then
		return nil, "bad_cell"
	end

	if state.mode == BuildClientState.MODES.place then
		local selected = state.selectedTrap
		if selected == nil then
			return nil, "no_trap"
		end
		if snapshot.cells[cell] ~= nil then
			return nil, "cell_occupied"
		end
		return { action = "place", trapId = selected, cell = cell }, nil
	elseif state.mode == BuildClientState.MODES.remove then
		if snapshot.cells[cell] == nil then
			return nil, "empty_cell"
		end
		return { action = "remove", trapId = "", cell = cell }, nil
	elseif state.mode == BuildClientState.MODES.upgrade then
		if snapshot.cells[cell] == nil then
			return nil, "empty_cell"
		end
		return { action = "upgrade", trapId = "", cell = cell }, nil
	end
	return nil, "bad_mode"
end

return BuildClientState
