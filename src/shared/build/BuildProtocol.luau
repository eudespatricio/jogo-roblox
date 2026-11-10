--!strict
-- Protocolo puro da S4 (request/response do build), com dependencias injetadas.
-- `grid` (GridLayout) valida celulas; `catalog` (TrapCatalog) define liga/custos; o servico
-- (WallService) executa a acao. Assim o mesmo contrato roda no CLI e no servidor, sem require
-- interno entre modulos shared (que o Rojo nao resolve por string).

local BuildProtocol = {}

BuildProtocol.ACTIONS = table.freeze({
	place = "place",
	remove = "remove",
	upgrade = "upgrade",
})

export type Grid = {
	parseCell: (cell: string) -> (number?, number?),
}

export type Request = {
	action: string,
	trapId: string,
	cell: string,
}

export type Service = {
	place: (trapId: string, cell: string) -> (any?, string?),
	remove: (cell: string) -> (any?, string?),
	upgrade: (cell: string) -> (any?, string?),
}

-- Valida a intencao antes de chamar o servico. Remove/upgrade ignoram trapId, mas o cliente
-- sempre manda string (""), porque argumento nil no meio de um RemoteFunction se perde.
function BuildProtocol.validateRequest(
	grid: Grid,
	action: any,
	trapId: any,
	cell: any
): (boolean, string?)
	if type(action) ~= "string" or BuildProtocol.ACTIONS[action] == nil then
		return false, "bad_action"
	end
	if type(cell) ~= "string" then
		return false, "bad_request"
	end
	local row, col = grid.parseCell(cell)
	if row == nil or col == nil then
		return false, "invalid_cell"
	end
	if action == "place" and (type(trapId) ~= "string" or trapId == "") then
		return false, "bad_request"
	end
	if type(trapId) ~= "string" then
		return false, "bad_request"
	end
	return true, nil
end

-- Snapshot imutavel para o cliente: copia `cells` e monta o catalogo na ordem de TRAP_IDS.
function BuildProtocol.snapshot(profile: any, catalog: any, grid: Grid): { [string]: any }?
	if
		type(profile) ~= "table"
		or type(profile.wall) ~= "table"
		or type(profile.wall.cells) ~= "table"
		or type(profile.league) ~= "table"
		or type(profile.league.points) ~= "number"
	then
		return nil
	end
	local cells: { [string]: any } = {}
	for cell, data in pairs(profile.wall.cells) do
		local row, col = grid.parseCell(cell)
		if row ~= nil and col ~= nil and type(data) == "table" then
			cells[cell] = { trap = data.trap, level = data.level }
		end
	end

	local catalogForClient: { { [string]: any } } = {}
	for _, trapId in ipairs(catalog.TRAP_IDS) do
		local def = catalog.TRAPS[trapId]
		catalogForClient[#catalogForClient + 1] = {
			id = trapId,
			cost = def.cost,
			upgrade = def.upgrade,
			unlockLeague = def.unlockLeague,
		}
	end

	return {
		gold = profile.gold,
		cells = cells,
		league = catalog.leagueOf(profile.league.points),
		contentVersion = profile.contentVersion,
		catalog = catalogForClient,
	}
end

-- Executa a intencao ja validada. Devolve (resultado, erro) igual ao WallService.
function BuildProtocol.apply(service: Service, request: Request): (any?, string?)
	if request.action == "place" then
		return service.place(request.trapId, request.cell)
	elseif request.action == "remove" then
		return service.remove(request.cell)
	elseif request.action == "upgrade" then
		return service.upgrade(request.cell)
	end
	return nil, "bad_action"
end

return BuildProtocol
