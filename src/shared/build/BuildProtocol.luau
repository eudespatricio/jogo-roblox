--!strict
-- Contrato puro do RemoteFunction BuildAction e do snapshot replicado para BuildClient.
-- Zero dependencia de Roblox: validado em CLI (sim/build-contract.luau) e usado pelo servidor.

local BuildProtocol = {}

BuildProtocol.ACTIONS = table.freeze({
	place = "place",
	remove = "remove",
	upgrade = "upgrade",
	move = "move",
	upgrade_wall = "upgrade_wall",
	equip_cosmetic = "equip_cosmetic",
})

local EQUIPPED_SLOTS: { [string]: boolean } = {
	theme = true,
	hordeSkin = true,
	finisher = true,
	commander = true,
}

export type Grid = {
	parseCell: (cell: string) -> (number?, number?),
	isValidSlot: ((slot: any) -> boolean)?,
	validateArenaPos: ((x: any, y: any) -> (boolean, string?))?,
	cellToArenaPos: ((cell: string) -> (number?, number?))?,
}
export type Request = {
	action: string,
	trapId: string,
	cell: string,
	slot: string?,
	x: number?,
	y: number?,
	cosmeticId: string?,
}
export type Service = {
	place: (trapId: string, cellOrSlot: string, x: number?, y: number?) -> (any?, string?),
	placeAt: ((trapId: string, x: number, y: number, slot: string?) -> (any?, string?))?,
	move: ((slot: string, x: number, y: number) -> (any?, string?))?,
	remove: (slot: string) -> (any?, string?),
	upgrade: (slot: string) -> (any?, string?),
	upgradeWall: (() -> (any?, string?))?,
	equipCosmetic: ((slotName: string, cosmeticId: string) -> (any?, string?))?,
}

local function checkSlot(grid: Grid, slot: any): boolean
	if type(slot) ~= "string" then
		return false
	end
	local s = slot :: string
	if string.match(s, "^r%d+c%d+$") ~= nil then
		local row, col = grid.parseCell(s)
		return row ~= nil and col ~= nil
	end
	if grid.isValidSlot ~= nil then
		return grid.isValidSlot(s)
	end
	return #s > 0 and #s <= 16 and string.match(s, "^[a-z0-9_]+$") ~= nil
end

local function checkArenaPos(grid: Grid, x: any, y: any): boolean
	if grid.validateArenaPos ~= nil then
		local ok = grid.validateArenaPos(x, y)
		return ok
	end
	if type(x) ~= "number" or type(y) ~= "number" then
		return false
	end
	local nx = x :: number
	local ny = y :: number
	if nx % 1 ~= 0 or ny % 1 ~= 0 then
		return false
	end
	return nx >= 1000
		and nx <= 9000
		and ny >= 500
		and ny <= 4500
		and nx % 250 == 0
		and ny % 250 == 0
end

function BuildProtocol.validateRequest(
	grid: Grid,
	action: any,
	arg1: any,
	arg2: any,
	x: any?,
	y: any?
): (Request?, string?)
	if type(action) ~= "string" or BuildProtocol.ACTIONS[action] == nil then
		return nil, "bad_action"
	end

	if action == "upgrade_wall" then
		return {
			action = "upgrade_wall",
			trapId = "",
			cell = "",
			slot = "",
		}, nil
	end

	if action == "equip_cosmetic" then
		if type(arg1) ~= "string" or EQUIPPED_SLOTS[arg1] ~= true then
			return nil, "invalid_slot"
		end
		if
			type(arg2) ~= "string"
			or #arg2 == 0
			or #arg2 > 48
			or string.match(arg2, "^[%w_%.%-]+$") == nil
		then
			return nil, "unknown_cosmetic"
		end
		return {
			action = "equip_cosmetic",
			trapId = arg1,
			cell = arg2,
			slot = arg1,
			cosmeticId = arg2,
		},
			nil
	end

	if action == "move" then
		if type(arg2) ~= "string" then
			return nil, "bad_request"
		end
		if not checkSlot(grid, arg2) then
			if string.match(arg2, "^r%d+c%d+$") ~= nil then
				return nil, "invalid_cell"
			end
			return nil, "invalid_slot"
		end
		if not checkArenaPos(grid, x, y) then
			return nil, "invalid_position"
		end
		return {
			action = "move",
			trapId = "",
			cell = arg2,
			slot = arg2,
			x = x :: number,
			y = y :: number,
		},
			nil
	end

	if action == "place" then
		if type(arg1) ~= "string" or #arg1 == 0 or #arg1 > 48 then
			return nil, "bad_request"
		end
		if x == nil and y == nil then
			if type(arg2) ~= "string" then
				return nil, "bad_request"
			end
			local row, col = grid.parseCell(arg2)
			if row == nil or col == nil then
				return nil, "invalid_cell"
			end
			return {
				action = "place",
				trapId = arg1,
				cell = arg2,
				slot = arg2,
			},
				nil
		end
		if not checkArenaPos(grid, x, y) then
			return nil, "invalid_position"
		end
		local slotStr: string
		if arg2 == nil then
			slotStr = ""
		elseif type(arg2) == "string" then
			slotStr = arg2
		else
			return nil, "bad_request"
		end
		if slotStr ~= "" and not checkSlot(grid, slotStr) then
			return nil, "invalid_slot"
		end
		local req: Request = {
			action = "place",
			trapId = arg1,
			cell = slotStr :: string,
			slot = slotStr :: string,
			x = x :: number,
			y = y :: number,
		}
		return req, nil
	end

	-- remove | upgrade
	if type(arg1) ~= "string" or type(arg2) ~= "string" then
		return nil, "bad_request"
	end
	if not checkSlot(grid, arg2) then
		if string.match(arg2, "^r%d+c%d+$") ~= nil then
			return nil, "invalid_cell"
		end
		return nil, "invalid_cell"
	end
	return {
		action = action,
		trapId = "",
		cell = arg2,
		slot = arg2,
	}, nil
end

-- Whitelist defensiva: o cliente recebe estado da muralha, catalogo e configuracao publica;
-- nunca schema inteiro nem chaves internas nao declaradas.
function BuildProtocol.snapshot(profile: any, catalog: any, grid: Grid): { [string]: any }?
	if
		type(profile) ~= "table"
		or type(profile.wall) ~= "table"
		or type(profile.league) ~= "table"
	then
		return nil
	end
	local league = if catalog.leagueOf ~= nil
		then catalog.leagueOf(profile.league.points or 0)
		elseif catalog.leagueForPoints ~= nil then catalog.leagueForPoints(
			profile.league.points or 0
		)
		else 1 + math.floor((profile.league.points or 0) / (catalog.POINTS_PER_LEAGUE or 100))
	local wallLevel = profile.wall.level or 1
	local wallLevelsOut = {}
	local wallHp = 500
	local wallTrapLimit = profile.wall.activeTrapLimit or 5
	if type(catalog.WALL_LEVELS) == "table" then
		for idx, def in ipairs(catalog.WALL_LEVELS) do
			wallLevelsOut[idx] = {
				level = idx,
				cost = def.cost,
				unlockLeague = def.unlockLeague,
				hp = def.hp,
				trapLimit = def.trapLimit,
			}
		end
		local currentDef = catalog.WALL_LEVELS[wallLevel]
		if currentDef ~= nil then
			wallHp = currentDef.hp
			wallTrapLimit = math.min(wallTrapLimit, currentDef.trapLimit)
		end
	end

	local cells = {}
	for slot, cellData in pairs(profile.wall.cells or {}) do
		if checkSlot(grid, slot) and type(cellData) == "table" then
			local cx = cellData.x
			local cy = cellData.y
			if (cx == nil or cy == nil) and grid.cellToArenaPos ~= nil then
				cx, cy = grid.cellToArenaPos(slot)
			end
			cells[slot] = {
				trap = cellData.trap,
				level = cellData.level,
				x = cx,
				y = cy,
			}
		end
	end

	local catalogOut = {}
	for _, id in ipairs(catalog.TRAP_IDS) do
		local def = catalog.TRAPS[id]
		if def ~= nil then
			catalogOut[#catalogOut + 1] = {
				id = id,
				cost = def.cost,
				upgrade = def.upgrade,
				unlockLeague = def.unlockLeague,
				unlocked = league >= def.unlockLeague,
			}
		end
	end

	local srcEq = if type(profile.equipped) == "table" then profile.equipped else {}
	local equipped = {
		theme = if type(srcEq.theme) == "string" then srcEq.theme else "theme_default",
		hordeSkin = if type(srcEq.hordeSkin) == "string" then srcEq.hordeSkin else "horde_default",
		finisher = if type(srcEq.finisher) == "string" then srcEq.finisher else "finisher_default",
		commander = if type(srcEq.commander) == "string" then srcEq.commander else "cmd_vorn",
	}

	return {
		gold = profile.gold or 0,
		schemaVersion = profile.schemaVersion,
		contentVersion = profile.contentVersion,
		league = league,
		wallLevel = wallLevel,
		wallHp = wallHp,
		activeTrapLimit = wallTrapLimit,
		maxTrapLevel = catalog.MAX_LEVEL or 5,
		maxWallLevel = catalog.MAX_WALL_LEVEL or 5,
		wallLevels = wallLevelsOut,
		equipped = equipped,
		cells = cells,
		catalog = catalogOut,
	}
end

function BuildProtocol.apply(service: Service, request: Request): (any?, string?)
	if request.action == "place" then
		if request.x ~= nil and request.y ~= nil then
			local slot = request.slot or request.cell or ""
			if slot == "" and service.placeAt ~= nil then
				return service.placeAt(request.trapId, request.x, request.y)
			end
			return service.place(request.trapId, slot, request.x, request.y)
		end
		return service.place(request.trapId, request.cell)
	elseif request.action == "move" then
		if service.move == nil then
			return nil, "bad_action"
		end
		return service.move(request.slot or request.cell, request.x :: number, request.y :: number)
	elseif request.action == "remove" then
		return service.remove(request.slot or request.cell)
	elseif request.action == "upgrade" then
		return service.upgrade(request.slot or request.cell)
	elseif request.action == "upgrade_wall" then
		if service.upgradeWall == nil then
			return nil, "bad_action"
		end
		return service.upgradeWall()
	elseif request.action == "equip_cosmetic" then
		if service.equipCosmetic == nil then
			return nil, "bad_action"
		end
		return service.equipCosmetic(
			request.slot or request.trapId,
			request.cosmeticId or request.cell
		)
	end
	return nil, "bad_action"
end

return BuildProtocol
