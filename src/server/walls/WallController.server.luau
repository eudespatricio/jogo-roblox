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
local GridLayout = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("build"):WaitForChild("GridLayout")
)
local BuildProtocol = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("build"):WaitForChild("BuildProtocol")
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

local function snapshotFor(player: Player): { [string]: any }?
	local session = ProfileRegistry.get(player)
	if session == nil then
		return nil
	end
	local data = session.Data
	if type(data) ~= "table" or type(data.wall) ~= "table" then
		return nil
	end
	local snapshot = BuildProtocol.snapshot(data, TrapCatalog, GridLayout)
	if snapshot ~= nil then
		pcall(BuildGrid.refresh, data.wall.cells)
	end
	return snapshot
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
	local valid, validationErr = BuildProtocol.validateRequest(GridLayout, action, trapId, cell)
	if not valid then
		return { ok = false, err = validationErr }
	end
	local service, serviceErr = serviceFor(player)
	if service == nil then
		return { ok = false, err = serviceErr }
	end

	local request: BuildProtocol.Request = {
		action = action :: string,
		trapId = trapId :: string,
		cell = cell :: string,
	}
	local result, err = BuildProtocol.apply(service, request)
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
