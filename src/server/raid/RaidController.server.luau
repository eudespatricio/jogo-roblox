--!nonstrict
-- S6/S8.1: raid assincrona contra fantasma shardado por liga + BotPhantoms + BattleLog em
-- escrita unica + replay deterministico + lock busy durante RaidReplay.SECONDS.
-- A parede fantasma passa por WallService.toBattleWall (unica ponte perfil->motor).
-- O replay roda o MESMO seed/muralha/wave e compara o hash antes de creditar; divergencia
-- vira battle_divergence e nao paga.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local raidModules = Shared:WaitForChild("raid")
local BattleLog = require(raidModules:WaitForChild("BattleLog"))
local BotPhantoms = require(raidModules:WaitForChild("BotPhantoms"))
local RaidReplay = require(raidModules:WaitForChild("RaidReplay"))
local RaidTelemetry = require(raidModules:WaitForChild("RaidTelemetry"))
local Core = require(Shared:WaitForChild("sim"):WaitForChild("core"))
local ProfileSchema = require(Shared:WaitForChild("data"):WaitForChild("ProfileSchema"))
local TrapCatalog = require(Shared:WaitForChild("data"):WaitForChild("TrapCatalog"))
local WallService = require(script.Parent.Parent:WaitForChild("walls"):WaitForChild("WallService"))
local ProfileRegistry =
	require(script.Parent.Parent:WaitForChild("data"):WaitForChild("ProfileRegistry"))
local BattleLogStore = require(script.Parent:WaitForChild("BattleLogStore"))
local PhantomStore = require(script.Parent:WaitForChild("PhantomStore"))
local AnalyticsService =
	require(script.Parent.Parent:WaitForChild("analytics"):WaitForChild("AnalyticsService"))

local REMOTES_NAME = "MuralhaRemotes"
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

local raidEvent = remotes:FindFirstChild("RaidEvent")
if raidEvent == nil or raidEvent.ClassName ~= "RemoteEvent" then
	if raidEvent ~= nil then
		raidEvent:Destroy()
	end
	raidEvent = Instance.new("RemoteEvent")
	raidEvent.Name = "RaidEvent"
	raidEvent.Parent = remotes
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

local phantomMock = RunService:IsStudio()
local phantomOverride = ServerStorage:GetAttribute("PhantomStoreMock")
if phantomOverride ~= nil then
	phantomMock = phantomOverride == true
end
local phantomDataStore = nil
if not phantomMock then
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(PhantomStore.STORE_NAME)
	end)
	if ok then
		phantomDataStore = result
	else
		phantomMock = true
		warn("[raid] DataStore do fantasma indisponivel; usando Mock: " .. tostring(result))
	end
end
local phantomStore = PhantomStore.new({ store = phantomDataStore, mock = phantomMock })
print(
	"[raid] phantom store="
		.. (phantomMock and "Mock" or "DataStore")
		.. " name="
		.. PhantomStore.STORE_NAME
)

type ActiveRaid = {
	battleId: string,
	token: number,
	divergenceReported: boolean,
}

local busy: { [Player]: boolean } = {}
local activeRaid: { [Player]: ActiveRaid } = {}
local raidToken = 0

-- Snapshot real sem PII: a muralha do perfil passa por toBattleWall e guarda apenas
-- ownerHash (8 hex), league, level, hp e traps.
local function snapshotFromProfile(profile: any, ownerHash: string, league: number): (any?, string?)
	local wall, wallErr = WallService.toBattleWall(profile, ProfileSchema, TrapCatalog)
	if wall == nil then
		return nil, wallErr
	end
	local traps = {}
	for index, trap in ipairs(wall.traps) do
		traps[index] = {
			cell = trap.cell,
			type = trap.type,
			level = trap.level,
			x = trap.x,
			y = trap.y,
		}
	end
	return {
		ownerHash = ownerHash,
		league = league,
		level = wall.level,
		hp = wall.hp,
		traps = traps,
		contentVersion = TrapCatalog.CONTENT_VERSION,
		updatedAt = os.time(),
	},
		nil
end

local function wallFromSnapshot(snapshot: any): any
	local traps = {}
	for index, trap in ipairs(snapshot.traps) do
		traps[index] = {
			cell = trap.cell,
			type = trap.type,
			level = trap.level,
			x = trap.x,
			y = trap.y,
		}
	end
	return { level = snapshot.level, hp = snapshot.hp, traps = traps }
end

local function runBattle(seed: number, wall: any, waveSpec: BotPhantoms.WaveSpec): any
	local battle = Core.Battle.new({
		seed = seed,
		simVersion = Core.SIM_VERSION,
		wall = wall,
		wave = waveSpec,
	})
	return battle:Run()
end

local function logEvent(player: Player, name: string, props: any): ()
	if props == nil then
		return
	end
	local event, err = AnalyticsService.emit(player, name, props)
	if event == nil then
		if err == "not_started" then
			-- Fallback de QA se o AnalyticsBoot ainda nao subiu; nao substitui o envelope.
			print(RaidTelemetry.format(name, props))
		else
			warn("[raid] analytics " .. name .. " recusado: " .. tostring(err))
		end
	end
end

local function creditRaid(
	player: Player,
	battleId: string,
	amount: number,
	source: string?
): (boolean, number?)
	if amount <= 0 then
		return true, nil
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
				logEvent(player, name, props)
			end,
		})
	end)
	if not serviceOk then
		warn("[raid] creditGold: WallService.new falhou: " .. tostring(service))
		return false, nil
	end
	local result, err = service.creditGold(amount, source or "raid", battleId)
	if result == nil then
		warn("[raid] creditGold recusado: " .. tostring(err))
		return false, nil
	end
	return true, result.gold
end

local function clearBusy(player: Player): ()
	activeRaid[player] = nil
	busy[player] = nil
end

local function startRaid(player: Player, rawOpts: any): any
	if busy[player] == true then
		return { ok = false, err = "busy" }
	end
	busy[player] = true
	local isDefend = type(rawOpts) == "table" and rawOpts.mode == "defend"
	local ok, response = pcall(function()
		local battleId = string.lower(HttpService:GenerateGUID(false))
		local battleKey = BattleLog.keyFor(battleId)
		if battleKey == nil then
			battleId = string.format("raid_%d_%d", player.UserId, os.time())
		end
		local seed = math.random(1, 2147483647)
		local profileSession = ProfileRegistry.get(player)
		if profileSession == nil or type(profileSession.Data) ~= "table" then
			return { ok = false, err = "profile" }
		end
		local profile = profileSession.Data
		local myLeague = TrapCatalog.leagueOf(profile.league.points)
		local shardLeague = math.clamp(myLeague, PhantomStore.MIN_LEAGUE, PhantomStore.MAX_LEAGUE)
		local myHash = PhantomStore.hashOwner(player.UserId)
		local mySlot = (math.floor(math.abs(player.UserId)) % PhantomStore.SLOTS_PER_LEAGUE) + 1

		local currentSnapshot, currentErr = snapshotFromProfile(profile, myHash, shardLeague)
		if currentSnapshot == nil then
			return { ok = false, err = "phantom: " .. tostring(currentErr) }
		end

		if #currentSnapshot.traps > 0 then
			local storedPhantom, phantomStoreErr = phantomStore.put(currentSnapshot, mySlot)
			if not storedPhantom then
				warn("[raid] nao publicou fantasma: " .. tostring(phantomStoreErr))
			end
		end

		local target: any
		local isBot = false
		local targetLeague: number
		local phantomLabel: string
		local myWallLevel = tonumber(currentSnapshot.level) or 1
		local myTrapCount = #currentSnapshot.traps
		if isDefend then
			target = currentSnapshot
			targetLeague = shardLeague
			phantomLabel = string.format("Lv%d", myWallLevel)
		else
			local matchLeague = BotPhantoms.matchLeague(shardLeague, myWallLevel, myTrapCount)
			local matched, matchErr = phantomStore.getForLeague(matchLeague, myHash, seed)
			if matchErr ~= nil then
				warn("[raid] busca fantasma falhou: " .. tostring(matchErr))
			end

			if matched ~= nil then
				local rivalLevel = tonumber(matched.level) or matchLeague
				local rivalTrapCap = math.max(2, myTrapCount + 1)
				if
					matched.ownerHash == myHash
					or rivalLevel > matchLeague
					or #matched.traps > rivalTrapCap
				then
					matched = nil
				end
			end

			target = matched
			if target == nil then
				isBot = true
				local botWall = BotPhantoms.pick(matchLeague, seed)
				target = {
					ownerHash = "bot",
					league = matchLeague,
					level = botWall.level,
					hp = botWall.hp,
					traps = botWall.traps,
				}
			end

			targetLeague = math.clamp(
				tonumber(target.league) or matchLeague,
				PhantomStore.MIN_LEAGUE,
				PhantomStore.MAX_LEAGUE
			)
			phantomLabel = if isBot
				then string.format("Bot L%d", targetLeague)
				else string.format(
					"L%d#%s",
					targetLeague,
					string.sub(tostring(target.ownerHash), 1, 4)
				)
		end

		local wall = wallFromSnapshot(target)
		local waveSpec =
			BotPhantoms.waveFor(targetLeague, isDefend, #wall.traps, tonumber(wall.level) or 1)
		print(
			string.format(
				"[raid] %s hash=%s league=%d traps=%d hp=%d wave=%d bot=%s store=%s",
				if isDefend then "defend" else "phantom",
				tostring(target.ownerHash),
				targetLeague,
				#wall.traps,
				target.hp,
				waveSpec.count,
				tostring(isBot),
				phantomMock and "Mock" or "DataStore"
			)
		)
		local startedProps = RaidTelemetry.startedProps(
			battleId,
			seed,
			Core.SIM_VERSION,
			Core.GRID_WIDTH,
			#wall.traps
		)
		logEvent(player, "battle_started", startedProps)
		logEvent(player, "raid_start", {
			battle_id = battleId,
			mode = if isDefend then "defense" else "phantom",
			speed = RAID_SPEED,
		})

		local result = runBattle(seed, wall, waveSpec)
		local replay = runBattle(seed, wallFromSnapshot(target), waveSpec)
		local replayOk, replayErr, expectedHash, actualHash = RaidReplay.verify(result, replay)
		if not replayOk then
			local divergence = RaidTelemetry.divergenceProps(battleId, expectedHash, actualHash)
			logEvent(player, "battle_divergence", divergence)
			return {
				ok = false,
				err = replayErr or "divergence",
				battleId = battleId,
				expectedHash = expectedHash,
				actualHash = actualHash,
			}
		end

		local finishedProps = RaidTelemetry.finishedProps(battleId, result)
		logEvent(player, "battle_finished", finishedProps)
		logEvent(
			player,
			"raid_end",
			{ battle_id = battleId, result = result.winner, duration_s = result.ticks * 0.05 }
		)
		local playerWon = if isDefend
			then result.winner == "defender"
			else result.winner == "attacker"
		if playerWon then
			local firstWin, firstWinErr = AnalyticsService.emitFirstWin(player, battleId)
			if
				firstWin == nil
				and firstWinErr ~= "already_won"
				and firstWinErr ~= "not_started"
			then
				warn("[raid] first_win recusado: " .. tostring(firstWinErr))
			end
		end

		local baseGold = 15 + 3 * targetLeague
		local raidsNow = profile.stats.raids
		local fatiguePct = if raidsNow < 10 then 100 elseif raidsNow < 25 then 50 else 25
		local winGold = math.max(5, math.floor(baseGold * fatiguePct / 100))
		local rewardGold = if playerWon then winGold elseif raidsNow < 3 then 5 else 0

		local oldPoints = profile.league.points
		local oldLeague = TrapCatalog.leagueOf(oldPoints)
		profile.stats.raids += 1
		local newPoints = oldPoints
		if playerWon then
			profile.stats.wins += 1
			newPoints = oldPoints + (if isDefend then 15 else 25)
		elseif not isDefend and oldLeague >= 3 then
			newPoints = math.max((oldLeague - 1) * 100, oldPoints - 10)
		end
		profile.league.points = newPoints
		local newLeague = TrapCatalog.leagueOf(newPoints)
		if newLeague ~= oldLeague then
			logEvent(player, "league_changed", {
				from = oldLeague,
				to = newLeague,
				delta = newPoints - oldPoints,
			})
		end

		local rewarded = true
		local creditedGold = 0
		local goldAfter: number? = nil
		if rewardGold > 0 then
			rewarded, goldAfter =
				creditRaid(player, battleId, rewardGold, if isDefend then "defense" else "raid")
			if rewarded then
				creditedGold = rewardGold
			end
		end

		local record, recordErr = BattleLog.fromBattle(
			battleId,
			result,
			TrapCatalog.CONTENT_VERSION,
			Core.GRID_WIDTH,
			#wall.traps,
			wall,
			os.time()
		)
		if record == nil then
			return { ok = false, err = "battlelog: " .. tostring(recordErr) }
		end
		if rewarded then
			local markedRecord, markErr = BattleLog.markRewarded(record, creditedGold)
			if markedRecord == nil then
				warn("[raid] nao montou reward no BattleLog: " .. tostring(markErr))
			else
				record = markedRecord
			end
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

		print(
			string.format(
				"[raid] battlelog battle_id=%s content=v%d reward=%d hash=%d",
				stored.battleId,
				stored.contentVersion,
				stored.rewardGold,
				stored.resultHash
			)
		)
		-- S6: espelha o ouro no atributo para a UI de build reabrir o snapshot (o modal de raid
		-- nao e dono do topo do build).
		if goldAfter ~= nil then
			print(string.format("[raid] creditou %d ouro gold=%d", creditedGold, goldAfter))
			player:SetAttribute("MuralhaGold", goldAfter)
		end

		return {
			ok = true,
			mode = if isDefend then "defend" else "raid",
			playerWon = playerWon,
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
			wall = wall,
			phantomName = phantomLabel,
			waveCount = waveSpec.count,
			spawnEveryTicks = waveSpec.spawnEveryTicks,
			simVersion = Core.SIM_VERSION,
			record = stored,
		}
	end)

	if not ok or type(response) ~= "table" or response.ok ~= true then
		clearBusy(player)
		if not ok then
			warn("[raid] start falhou: " .. tostring(response))
			return { ok = false, err = "internal" }
		end
		return response
	end

	raidToken += 1
	local token = raidToken
	activeRaid[player] = {
		battleId = tostring(response.battleId or ""),
		token = token,
		divergenceReported = false,
	}
	task.delay(math.max(RaidReplay.SECONDS, 75), function()
		local current = activeRaid[player]
		if current ~= nil and current.token == token then
			clearBusy(player)
		end
	end)

	return response
end

raidStart.OnServerInvoke = function(player: Player, opts: any)
	return startRaid(player, opts)
end

(raidEvent :: RemoteEvent).OnServerEvent:Connect(function(player: Player, action: any, payload: any)
	if type(action) ~= "string" then
		return
	end
	if action == "close" then
		local current = activeRaid[player]
		if current == nil then
			busy[player] = nil
			return
		end
		if
			type(payload) ~= "table"
			or payload.battleId == nil
			or payload.battleId == current.battleId
		then
			clearBusy(player)
		end
		return
	end
	if action == "divergence" then
		local current = activeRaid[player]
		if current == nil or current.divergenceReported then
			return
		end
		if type(payload) ~= "table" then
			return
		end
		local battleId = if type(payload.battleId) == "string"
			then payload.battleId
			else current.battleId
		if battleId ~= current.battleId then
			return
		end
		local expectedHash = if payload.expectedHash ~= nil
			then payload.expectedHash
			else payload.expected_hash
		local actualHash = if payload.actualHash ~= nil
			then payload.actualHash
			else payload.actual_hash
		local props, propsErr = RaidTelemetry.divergenceProps(battleId, expectedHash, actualHash)
		if props == nil then
			warn("[raid] divergence payload invalido: " .. tostring(propsErr))
			return
		end
		current.divergenceReported = true
		logEvent(player, "battle_divergence", props)
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	clearBusy(player)
end)

print(
	string.format(
		"[raid] servidor pronto store=%s phantomSlots=%d sim=%d",
		useMock and "Mock" or "DataStore",
		PhantomStore.SLOTS_PER_LEAGUE,
		Core.SIM_VERSION
	)
)
