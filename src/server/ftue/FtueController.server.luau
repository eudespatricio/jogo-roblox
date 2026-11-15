--!strict
-- Controller de FTUE (GAP-020): expoe MuralhaRemotes.FtueAction ("state" / "skip").
-- Rate-limit de 1.0s e regras de progressao moram em FtueService / FtueLogic.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FtueService = require(script.Parent:WaitForChild("FtueService"))

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

local function ensureRemoteFunction(parent: Folder, name: string): RemoteFunction
	local existing = parent:FindFirstChild(name)
	if existing == nil or existing.ClassName ~= "RemoteFunction" then
		if existing ~= nil then
			existing:Destroy()
		end
		local rf = Instance.new("RemoteFunction")
		rf.Name = name
		rf.Parent = parent
		return rf
	end
	return existing :: RemoteFunction
end

local remotes = ensureRemotes()
local ftueActionRemote = ensureRemoteFunction(remotes, "FtueAction")

ftueActionRemote.OnServerInvoke = function(player: Player, action: any)
	local ok, result = pcall(function(): { [string]: any }
		if action == "state" then
			local state = FtueService.stateFor(player)
			if state == nil then
				return { ok = false, err = "no_session" }
			end
			return { ok = true, ftue = state, gold = state.gold }
		elseif action == "skip" then
			return FtueService.skip(player)
		end
		return { ok = false, err = "bad_action" }
	end)
	if not ok then
		warn("[ftue] acao falhou: " .. tostring(result))
		return { ok = false, err = "internal" }
	end
	return result
end

print("[ftue] FtueAction pronto em ReplicatedStorage." .. REMOTES_NAME)
