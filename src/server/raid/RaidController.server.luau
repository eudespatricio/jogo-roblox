--!nonstrict
-- S6 (scaffold): raid assíncrona contra uma muralha fantasma + BattleLog separado + replay.
-- A parede fantasma e montada por um perfil sintetico e passa por WallService.toBattleWall
-- (unica ponte perfil->motor). O replay roda o MESMO seed/muralha/wave e compara o hash antes
-- de creditar; divergencia vira battle_divergence e nao paga.
--
-- BattleLog: uma chave por battle_id, store separado (DataStore em producao; memoria no Studio).
-- Recompensa: creditGold(..., "raid", battle_id) uma vez; claim idempotente no store.
-- Envelope/sink de analytics continua S7: aqui os pontos saem como [analytics] props validadas.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local raidModules = Shared:WaitForChild("raid")
local BattleLog = require(raidModules:WaitForChild("BattleLog"))
local RaidReplay = require(raidModules:WaitForChild("RaidReplay"))
local RaidTelemetry = require(raidModules:WaitForChild("RaidTelemetry"))
local Core = require(Shared:WaitForChild("sim"):WaitForChild("core"))
local ProfileSchema = require(Shared:WaitForChild("data"):WaitForChild("ProfileSchema"))
local TrapCatalog = require(Shared:WaitForChild("data"):WaitForChild("TrapCatalog"))
local WallService = require(script.Parent.Parent:WaitForChild("walls"):WaitForChild("WallService"))
local ProfileRegistry =
	require(script.Parent.Parent:WaitForChild("data"):WaitForChild("ProfileRegistry"))
local BattleLogStore = require(script.Parent:WaitForChild("BattleLogStore"))

local REMOTES_NAME = "MuralhaRemotes"
local RAID_REWARD_GOLD = 5
local RAID_SPEED = 1

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
local raidStart = remotes:FindFirstChild("RaidStart")
if raidStart == nil or raidStart.ClassName ~= "RemoteFunction" then
	if raidStart ~= nil then
		raidStart:Destroy()
	end
	raidStart = Instance.new("RemoteFunction")
	raidStart.Name = "RaidStart"
	raidStart.Parent = remotes
end

ReplicatedStorage:SetAttribute("RaidEnabled", true)

local useMock = RunService:IsStudio()
local mockOverride = ServerStorage:GetAttribute("BattleLogMock")
if mockOverride ~= nil then
	useMock = mockOverride == true
end
local dataStore = nil
if not useMock then
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(BattleLog.STORE_NAME)
	end)
	if ok then
		dataStore = result
	else
		useMock = true
		warn("[raid] DataStore indisponivel; BattleLog em memoria: " .. tostring(result))
	end
end
local logStore = BattleLogStore.new({ store = dataStore, mock = useMock })
print(
	"[raid] battlelog store="
		.. (useMock and "Mock" or "DataStore")
		.. " name="
		.. BattleLog.STORE_NAME
)

local busy: { [Player]: boolean } = {}

-- Perfil sintetico com o loadout padrao do motor; toBattleWall valida e converte.
local function phantomWall(): any
	local profile = ProfileSchema.template()
	local defaults = Core.defaultWall().traps
	for _, trap in ipairs(defaults) do
		profile.wall.cells[trap.cell] = { trap = trap.type, level = trap.level }
	end
	local contentOk, contentErr = TrapCatalog.ensureProfileContent(profile)
	assert(contentOk, "phantomWall: " .. tostring(contentErr))
	local wall, wallErr = WallService.toBattleWall(profile, ProfileSchema, TrapCatalog, 500)
	assert(wall ~= nil, "phantomWall: " .. tostring(wallErr))
	return wall
end

local function runBattle(seed: number, wall: any): any
	local battle = Core.Battle.new({
		seed = seed,
		simVersion = Core.SIM_VERSION,
		wall = wall,
		wave = { count = 70 },
	})
	return battle:Run()
end

local function logEvent(name: string, props: any): ()
	if props == nil then
		return
	end
	print(RaidTelemetry.format(name, props))
end

local function creditRaid(player: Player, battleId: string, amount: number): (boolean, number?)
	if amount <= 0 then
		return true, 0
	end
	local profileSession = ProfileRegistry.get(player)
	if profileSession == nil or type(profileSession.Data) ~= "table" then
		warn("[raid] sem perfil para creditar " .. tostring(amount))
		return false, nil
	end
	local serviceOk, service = pcall(function()
		return WallService.new({
			profile = profileSession.Data,
			schema = ProfileSchema,
			catalog = TrapCatalog,
			emit = function(name: string, props: { [string]: any })
				logEvent(name, props)
			end,
		})
	end)
	if not serviceOk then
		warn("[raid] creditGold: WallService.new falhou: " .. tostring(service))
		return false, nil
	end
	local result, err = service.creditGold(amount, "raid", battleId)
	if result == nil then
		warn("[raid] creditGold recusado: " .. tostring(err))
		return false, nil
	end
	return true, result.gold
end

local function startRaid(player: Player): any
	if busy[player] == true then
		return { ok = false, err = "busy" }
	end
	busy[player] = true
	local ok, response = pcall(function()
		local battleId = string.lower(HttpService:GenerateGUID(false))
		local battleKey = BattleLog.keyFor(battleId)
		if battleKey == nil then
			battleId = string.format("raid_%d_%d", player.UserId, os.time())
		end
		local seed = math.random(1, 2147483647)
		local wall = phantomWall()
		local startedProps = RaidTelemetry.startedProps(
			battleId,
			seed,
			Core.SIM_VERSION,
			Core.GRID_WIDTH,
			#wall.traps
		)
		logEvent("battle_started", startedProps)
		logEvent("raid_start", { battle_id = battleId, mode = "phantom", speed = RAID_SPEED })

		local result = runBattle(seed, wall)
		local replay = runBattle(seed, phantomWall())
		local replayOk, replayErr, expectedHash, actualHash = RaidReplay.verify(result, replay)
		if not replayOk then
			local divergence = RaidTelemetry.divergenceProps(battleId, expectedHash, actualHash)
			logEvent("battle_divergence", divergence)
			return {
				ok = false,
				err = replayErr or "divergence",
				battleId = battleId,
				expectedHash = expectedHash,
				actualHash = actualHash,
			}
		end

		local finishedProps = RaidTelemetry.finishedProps(battleId, result)
		logEvent("battle_finished", finishedProps)
		logEvent("raid_end", {
			battle_id = battleId,
			result = result.winner,
			duration_s = result.ticks * 0.05,
		})

		local record, recordErr = BattleLog.fromBattle(
			battleId,
			result,
			TrapCatalog.CONTENT_VERSION,
			Core.GRID_WIDTH,
			#wall.traps,
			os.time()
		)
		if record == nil then
			return { ok = false, err = "battlelog: " .. tostring(recordErr) }
		end
		local replayable, replayErrLog = BattleLog.isReplayable(record, TrapCatalog.CONTENT_VERSION)
		if not replayable then
			return { ok = false, err = "battlelog: " .. tostring(replayErrLog) }
		end

		local stored, created, putErr = logStore.put(record)
		if stored == nil then
			return { ok = false, err = "battlelog: " .. tostring(putErr) }
		end
		if not created then
			return {
				ok = true,
				duplicate = true,
				battleId = battleId,
				record = stored,
				replaySeconds = RaidReplay.SECONDS,
				rewardGold = stored.rewardGold,
			}
		end

		local rewardGold = 0
		if result.winner == "attacker" then
			rewardGold = RAID_REWARD_GOLD
		end
		local rewarded = true
		local creditedGold = 0
		if rewardGold > 0 then
			rewarded = creditRaid(player, battleId, rewardGold)
			if rewarded then
				creditedGold = rewardGold
			end
		end
		local finalLog = stored
		if rewarded then
			local marked, markErr = logStore.markRewarded(battleId, creditedGold)
			if marked == nil then
				warn("[raid] nao marcou recompensa: " .. tostring(markErr))
			else
				finalLog = marked
			end
		end

		return {
			ok = true,
			battleId = battleId,
			seed = seed,
			resultHash = result.hash,
			winner = result.winner,
			wallHp = result.wallHp,
			leaked = result.leaked,
			ticks = result.ticks,
			durationMs = result.ticks * BattleLog.TICK_MS,
			rewardGold = creditedGold,
			replaySeconds = RaidReplay.SECONDS,
			record = finalLog,
		}
	end)
	busy[player] = nil
	if not ok then
		warn("[raid] start falhou: " .. tostring(response))
		return { ok = false, err = "internal" }
	end
	return response
end

raidStart.OnServerInvoke = function(player: Player)
	return startRaid(player)
end

Players.PlayerRemoving:Connect(function(player: Player)
	busy[player] = nil
end)

print(
	string.format(
		"[raid] servidor pronto store=%s reward=%d sim=%d",
		useMock and "Mock" or "DataStore",
		RAID_REWARD_GOLD,
		Core.SIM_VERSION
	)
)
