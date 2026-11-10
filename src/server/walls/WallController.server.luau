--!strict
-- Contrato servidor<->cliente da S4: snapshot da muralha e acoes de build.
-- O cliente manda intencao; o servidor valida com WallService (celula, N=5, ouro,
-- desbloqueio, contentVersion) e devolve o snapshot atualizado. Nada de confiar no cliente.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ProfileSchema = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("data"):WaitForChild("ProfileSchema")
)
local TrapCatalog = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("data"):WaitForChild("TrapCatalog")
)
local WallService = require(script.Parent:WaitForChild("WallService"))
local ProfileRegistry =
	require(script.Parent.Parent:WaitForChild("data"):WaitForChild("ProfileRegistry"))
local BuildGrid = require(script.Parent.Parent:WaitForChild("world"):WaitForChild("BuildGrid"))

local REMOTES_NAME = "MuralhaRemotes"

local function ensureRemotes(): Folder
	local existing = ReplicatedStorage:FindFirstChild(REMOTES_NAME)
	if existing ~= nil and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = REMOTES_NAME
	folder.Parent = ReplicatedStorage
	return folder
end

local remotes = ensureRemotes()

local function ensureRemote(className: string, name: string): Instance
	local existing = remotes:FindFirstChild(name)
	if existing ~= nil and existing.ClassName == className then
		return existing
	end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local buildAction = ensureRemote("RemoteFunction", "BuildAction") :: RemoteFunction
local buildSnapshot = ensureRemote("RemoteFunction", "BuildSnapshot") :: RemoteFunction

local function catalogForClient(): { { [string]: any } }
	local catalog: { { [string]: any } } = {}
	for _, trapId in ipairs(TrapCatalog.TRAP_IDS) do
		local def = TrapCatalog.TRAPS[trapId]
		catalog[#catalog + 1] = {
			id = trapId,
			cost = def.cost,
			upgrade = def.upgrade,
			unlockLeague = def.unlockLeague,
		}
	end
	return catalog
end

local function copyCells(cells: { [string]: any }): { [string]: any }
	local copy: { [string]: any } = {}
	for cell, data in pairs(cells) do
		copy[cell] = { trap = data.trap, level = data.level }
	end
	return copy
end

local function snapshotFor(player: Player): { [string]: any }?
	local session = ProfileRegistry.get(player)
	if session == nil then
		return nil
	end
	local data = session.Data
	if type(data) ~= "table" or type(data.wall) ~= "table" then
		return nil
	end
	pcall(BuildGrid.refresh, data.wall.cells)
	return {
		gold = data.gold,
		cells = copyCells(data.wall.cells),
		league = TrapCatalog.leagueOf(data.league.points),
		contentVersion = data.contentVersion,
		catalog = catalogForClient(),
	}
end

local function serviceFor(player: Player): (any?, string?)
	local session = ProfileRegistry.get(player)
	if session == nil then
		return nil, "no_session"
	end
	local ok, service = pcall(function()
		return WallService.new({
			profile = session.Data,
			schema = ProfileSchema,
			catalog = TrapCatalog,
		})
	end)
	if not ok then
		return nil, "service: " .. tostring(service)
	end
	return service, nil
end

local function handleAction(player: Player, action: any, trapId: any, cell: any): { [string]: any }
	if type(action) ~= "string" or type(cell) ~= "string" then
		return { ok = false, err = "bad_request" }
	end
	local service, serviceErr = serviceFor(player)
	if service == nil then
		return { ok = false, err = serviceErr }
	end

	local result: any = nil
	local err: string? = nil
	if action == "place" then
		if type(trapId) ~= "string" or trapId == "" then
			return { ok = false, err = "bad_request" }
		end
		result, err = service.place(trapId, cell)
	elseif action == "remove" then
		result, err = service.remove(cell)
	elseif action == "upgrade" then
		result, err = service.upgrade(cell)
	else
		return { ok = false, err = "bad_action" }
	end
	if result == nil then
		return { ok = false, err = err }
	end

	local session = ProfileRegistry.get(player)
	if session ~= nil then
		pcall(BuildGrid.refresh, session.Data.wall.cells)
	end
	return {
		ok = true,
		err = nil,
		result = result,
		snapshot = snapshotFor(player),
	}
end

buildAction.OnServerInvoke = function(player: Player, action: any, trapId: any, cell: any)
	local ok, result = pcall(handleAction, player, action, trapId, cell)
	if not ok then
		warn("[build] acao falhou: " .. tostring(result))
		return { ok = false, err = "internal" }
	end
	return result
end

buildSnapshot.OnServerInvoke = function(player: Player)
	local ok, snapshot = pcall(snapshotFor, player)
	if not ok then
		warn("[build] snapshot falhou: " .. tostring(snapshot))
		return nil
	end
	return snapshot
end

print("[build] remotes prontos em ReplicatedStorage." .. REMOTES_NAME)
