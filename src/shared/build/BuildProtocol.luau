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
	choose_horde = "choose_horde",
	unlock_card = "unlock_card",
	save_deck = "save_deck",
})

local EQUIPPED_SLOTS: { [string]: boolean } = {
	theme = true,
	hordeSkin = true,
	finisher = true,
	commander = true,
}

local HORDE_FACTIONS: { [string]: boolean } = {
	iron = true,
	slag = true,
	frost = true,
	powder = true,
	rift = true,
}

local LANE_MODES: { [string]: boolean } = {
	center = true,
	flanks = true,
	split = true,
	all = true,
}

local MAX_DECK_SQUADS = 8
local MAX_SQUAD_UNITS = 200

export type Grid = {
	parseCell: (cell: string) -> (number?, number?),
	isValidSlot: ((slot: any) -> boolean)?,
	validateArenaPos: ((x: any, y: any) -> (boolean, string?))?,
	cellToArenaPos: ((cell: string) -> (number?, number?))?,
}
export type DeckSquadPayload = {
	cardId: string,
	count: number,
	laneMode: string,
}
export type Request = {
	action: string,
	trapId: string,
	cell: string,
	slot: string?,
	x: number?,
	y: number?,
	cosmeticId: string?,
	faction: string?,
	cardId: string?,
	squads: { DeckSquadPayload }?,
	championCardId: string?,
	championLaneMode: string?,
}
export type SaveDeckPayload = {
	squads: { DeckSquadPayload },
	championCardId: string?,
	championLaneMode: string?,
}
export type Service = {
	place: (trapId: string, cellOrSlot: string, x: number?, y: number?) -> (any?, string?),
	placeAt: ((trapId: string, x: number, y: number, slot: string?) -> (any?, string?))?,
	move: ((slot: string, x: number, y: number) -> (any?, string?))?,
	remove: (slot: string) -> (any?, string?),
	upgrade: (slot: string) -> (any?, string?),
	upgradeWall: (() -> (any?, string?))?,
	equipCosmetic: ((slotName: string, cosmeticId: string) -> (any?, string?))?,
	chooseHorde: ((faction: string) -> (any?, string?))?,
	unlockCard: ((cardId: string) -> (any?, string?))?,
	saveDeck: ((payload: SaveDeckPayload) -> (any?, string?))?,
}

local cachedDeckCatalog: any = nil

local function resolveDeckCatalog(explicit: any?): any?
	if type(explicit) == "table" then
		return explicit
	end
	if cachedDeckCatalog ~= nil then
		return cachedDeckCatalog
	end
	local okGame, rep = pcall(function(): any
		return game:GetService("ReplicatedStorage")
	end)
	if okGame and rep ~= nil then
		local sharedFolder = rep:FindFirstChild("Shared")
		local raidFolder = if sharedFolder ~= nil then sharedFolder:FindFirstChild("raid") else nil
		local mod = if raidFolder ~= nil then raidFolder:FindFirstChild("DeckCatalog") else nil
		if mod ~= nil then
			local req: any = require
			local okReq, loaded = pcall(req, mod)
			if okReq and type(loaded) == "table" then
				cachedDeckCatalog = loaded
				return loaded
			end
		end
	end
	local req: any = require
	local cliPath = "../raid/" .. "DeckCatalog"
	local okCli, cliLoaded = pcall(req, cliPath)
	if okCli and type(cliLoaded) == "table" then
		cachedDeckCatalog = cliLoaded
		return cliLoaded
	end
	return nil
end

local function isIdString(value: any): boolean
	return type(value) == "string"
		and #value > 0
		and #value <= 48
		and string.match(value, "^[%w_%.%-]+$") ~= nil
end

local function isFiniteInt(value: any): boolean
	if type(value) ~= "number" then
		return false
	end
	local n = value :: number
	return n == n and n ~= math.huge and n ~= -math.huge and n % 1 == 0
end

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

	if action == "choose_horde" then
		local rawFaction = if type(arg1) == "table" then arg1.faction else arg1
		if type(rawFaction) ~= "string" then
			return nil, "bad_request"
		end
		if HORDE_FACTIONS[rawFaction] ~= true then
			return nil, "invalid_faction"
		end
		return {
			action = "choose_horde",
			trapId = "",
			cell = "",
			slot = "",
			faction = rawFaction,
		},
			nil
	end

	if action == "unlock_card" then
		local rawCardId = if type(arg1) == "table" then arg1.cardId else arg1
		if type(rawCardId) ~= "string" then
			return nil, "bad_request"
		end
		if not isIdString(rawCardId) then
			return nil, "unknown_card"
		end
		return {
			action = "unlock_card",
			trapId = "",
			cell = "",
			slot = "",
			cardId = rawCardId,
		},
			nil
	end

	if action == "save_deck" then
		if type(arg1) ~= "table" or type(arg1.squads) ~= "table" then
			return nil, "bad_request"
		end
		local rawSquads = arg1.squads :: { any }
		local rawKeys = 0
		for k in pairs(rawSquads) do
			if not isFiniteInt(k) or (k :: number) < 1 then
				return nil, "invalid_squads"
			end
			rawKeys += 1
		end
		if rawKeys ~= #rawSquads or #rawSquads < 1 or #rawSquads > MAX_DECK_SQUADS then
			return nil, "invalid_squads"
		end
		local squadsOut: { DeckSquadPayload } = {}
		for _, sq in ipairs(rawSquads) do
			if type(sq) ~= "table" or not isIdString(sq.cardId) then
				return nil, "invalid_squad_card"
			end
			if not isFiniteInt(sq.count) or sq.count < 1 or sq.count > MAX_SQUAD_UNITS then
				return nil, "invalid_squad_count"
			end
			if type(sq.laneMode) ~= "string" or LANE_MODES[sq.laneMode] ~= true then
				return nil, "invalid_lane_mode"
			end
			table.insert(squadsOut, {
				cardId = sq.cardId :: string,
				count = sq.count :: number,
				laneMode = sq.laneMode :: string,
			})
		end
		local champIdOut: string? = nil
		if arg1.championCardId ~= nil and arg1.championCardId ~= "" then
			if not isIdString(arg1.championCardId) then
				return nil, "invalid_champion_card"
			end
			champIdOut = arg1.championCardId :: string
		end
		local champLaneOut = "center"
		if arg1.championLaneMode ~= nil then
			if
				type(arg1.championLaneMode) ~= "string"
				or LANE_MODES[arg1.championLaneMode] ~= true
			then
				return nil, "invalid_lane_mode"
			end
			champLaneOut = arg1.championLaneMode :: string
		end
		return {
			action = "save_deck",
			trapId = "",
			cell = "",
			slot = "",
			squads = squadsOut,
			championCardId = champIdOut,
			championLaneMode = champLaneOut,
		},
			nil
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
function BuildProtocol.snapshot(
	profile: any,
	catalog: any,
	grid: Grid,
	deckCatalog: any?
): { [string]: any }?
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

	local dc = resolveDeckCatalog(deckCatalog)
	local srcHorde = if type(profile.horde) == "table" then profile.horde else nil
	local faction = if srcHorde ~= nil
			and type(srcHorde.faction) == "string"
			and HORDE_FACTIONS[srcHorde.faction] == true
		then srcHorde.faction
		else "iron"
	local unlockedOut: { [string]: boolean } = {}
	if srcHorde ~= nil and type(srcHorde.unlockedCards) == "table" then
		for cardId, flag in pairs(srcHorde.unlockedCards) do
			if type(cardId) == "string" and type(flag) == "boolean" then
				unlockedOut[cardId] = flag
			end
		end
	elseif dc ~= nil and type(dc.starterForFaction) == "function" then
		local starter = dc.starterForFaction(faction)
		if type(starter) == "table" and type(starter.unlockedCards) == "table" then
			for cardId, flag in pairs(starter.unlockedCards) do
				if flag == true then
					unlockedOut[cardId] = true
				end
			end
		end
	else
		unlockedOut.squad_runner_pack = true
		unlockedOut.squad_brute_guards = true
		unlockedOut.squad_iron_vanguard = true
	end
	local coresSrc = if srcHorde ~= nil and type(srcHorde.bossCores) == "table"
		then srcHorde.bossCores
		else {}
	local bossCoresOut = {
		act1 = coresSrc.act1 == true,
		act2 = coresSrc.act2 == true,
		act3 = coresSrc.act3 == true,
		act4 = coresSrc.act4 == true,
		act5 = coresSrc.act5 == true,
	}
	local squadsOut: { DeckSquadPayload } = {}
	if srcHorde ~= nil and type(srcHorde.squads) == "table" then
		for _, sq in ipairs(srcHorde.squads) do
			if
				type(sq) == "table"
				and type(sq.cardId) == "string"
				and type(sq.count) == "number"
			then
				table.insert(squadsOut, {
					cardId = sq.cardId,
					count = sq.count,
					laneMode = if type(sq.laneMode) == "string"
							and LANE_MODES[sq.laneMode] == true
						then sq.laneMode
						else "center",
				})
			end
		end
	elseif dc ~= nil and type(dc.starterForFaction) == "function" then
		local starter = dc.starterForFaction(faction)
		if type(starter) == "table" and type(starter.squads) == "table" then
			for _, sq in ipairs(starter.squads) do
				table.insert(squadsOut, {
					cardId = sq.cardId,
					count = sq.count,
					laneMode = sq.laneMode,
				})
			end
		end
	end
	local champCardId = if srcHorde ~= nil
			and type(srcHorde.championCardId) == "string"
			and srcHorde.championCardId ~= ""
		then srcHorde.championCardId
		else nil
	local champLaneMode = if srcHorde ~= nil
			and type(srcHorde.championLaneMode) == "string"
			and LANE_MODES[srcHorde.championLaneMode] == true
		then srcHorde.championLaneMode
		else "center"
	local hordeOut: { [string]: any } = {
		starterChosen = srcHorde ~= nil and srcHorde.starterChosen == true,
		faction = faction,
		unlockedCards = unlockedOut,
		shards = if srcHorde ~= nil and type(srcHorde.shards) == "number"
			then math.max(0, math.floor(srcHorde.shards))
			else 0,
		bossCores = bossCoresOut,
		dailyPlunderDayId = if srcHorde ~= nil
				and type(srcHorde.dailyPlunderDayId) == "number"
			then math.max(0, math.floor(srcHorde.dailyPlunderDayId))
			else 0,
		dailyPlunderCount = if srcHorde ~= nil
				and type(srcHorde.dailyPlunderCount) == "number"
			then math.max(0, math.floor(srcHorde.dailyPlunderCount))
			else 0,
		squads = squadsOut,
		championCardId = champCardId,
		championLaneMode = champLaneMode,
	}
	if dc ~= nil then
		if type(dc.portalThemeFor) == "function" then
			hordeOut.portalTheme = dc.portalThemeFor(faction)
		end
		if type(dc.computeStats) == "function" then
			hordeOut.stats = dc.computeStats(hordeOut, league)
		end
	end

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
		horde = hordeOut,
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
	elseif request.action == "choose_horde" then
		if service.chooseHorde == nil then
			return nil, "bad_action"
		end
		return service.chooseHorde(request.faction or "")
	elseif request.action == "unlock_card" then
		if service.unlockCard == nil then
			return nil, "bad_action"
		end
		return service.unlockCard(request.cardId or "")
	elseif request.action == "save_deck" then
		if service.saveDeck == nil then
			return nil, "bad_action"
		end
		return service.saveDeck({
			squads = request.squads or {},
			championCardId = request.championCardId,
			championLaneMode = request.championLaneMode,
		})
	end
	return nil, "bad_action"
end

return BuildProtocol
