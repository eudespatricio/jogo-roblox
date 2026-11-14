--!nonstrict
-- S6/S8.1 + Campanha ("Cronicas do Bastiao"): raid assincrona contra fantasma shardado por liga +
-- BotPhantoms + Campanha 25 fases (Normal/Pesadelo + 5 Bosses Multi-Lane + marcos por Ato) +
-- BattleLog em escrita unica + replay deterministico + lock busy durante RaidReplay.SECONDS.
-- A parede passa por WallService.toBattleWall (unica ponte perfil->motor).
-- O replay roda o MESMO seed/muralha/wave e compara o hash antes de creditar; divergencia
-- vira battle_divergence e nao paga.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local bit32 = bit32

local Shared = ReplicatedStorage:WaitForChild("Shared")
local raidModules = Shared:WaitForChild("raid")
local BattleLog = require(raidModules:WaitForChild("BattleLog"))
local BotPhantoms = require(raidModules:WaitForChild("BotPhantoms"))
local RaidReplay = require(raidModules:WaitForChild("RaidReplay"))
local RaidTelemetry = require(raidModules:WaitForChild("RaidTelemetry"))
local CampaignCatalog = require(Shared:WaitForChild("campaign"):WaitForChild("CampaignCatalog"))
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
local raidStart = ensureRemoteFunction(remotes, "RaidStart")
local campaignStateRemote = ensureRemoteFunction(remotes, "CampaignState")
local campaignClaimRemote = ensureRemoteFunction(remotes, "CampaignClaim")

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

local function cloneTable(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = cloneTable(v)
	end
	return out
end

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

local function wallTrapLimit(wallLevel: number): number
	local lvl = math.clamp(math.floor(wallLevel), 1, TrapCatalog.MAX_WALL_LEVEL)
	local def = TrapCatalog.WALL_LEVELS[lvl] or TrapCatalog.WALL_LEVELS[1]
	return def.trapLimit
end

local function summarizeTraps(traps: { any }?): { { type: string, level: number, count: number } }
	if type(traps) ~= "table" then
		return {}
	end
	local counts: { [string]: { type: string, level: number, count: number } } = {}
	local order: { { type: string, level: number, count: number } } = {}
	for _, trap in ipairs(traps) do
		if type(trap) == "table" and type(trap.type) == "string" then
			local lvl = math.max(1, tonumber(trap.level) or 1)
			local key = trap.type .. ":" .. tostring(lvl)
			local entry = counts[key]
			if entry == nil then
				entry = { type = trap.type, level = lvl, count = 0 }
				counts[key] = entry
				order[#order + 1] = entry
			end
			entry.count += 1
		end
	end
	table.sort(order, function(a, b)
		if a.level ~= b.level then
			return a.level > b.level
		end
		if a.count ~= b.count then
			return a.count > b.count
		end
		return a.type < b.type
	end)
	local out = {}
	for i = 1, math.min(4, #order) do
		out[i] = order[i]
	end
	return out
end

local function summarizeWaveClasses(waveSpec: any): { string }
	local seen: { [string]: boolean } = {}
	local out: { string } = {}
	local function addKind(kind: any)
		if type(kind) == "string" and kind ~= "" and not seen[kind] and #out < 4 then
			seen[kind] = true
			out[#out + 1] = kind
		end
	end
	if type(waveSpec) == "table" then
		if type(waveSpec.slices) == "table" and #waveSpec.slices > 0 then
			for _, slice in ipairs(waveSpec.slices) do
				if type(slice) == "table" then
					addKind(slice.unit)
				end
			end
		elseif type(waveSpec.pool) == "table" and #waveSpec.pool > 0 then
			for _, kind in ipairs(waveSpec.pool) do
				addKind(kind)
			end
		end
	end
	if #out == 0 then
		return { "runner", "brute", "swarm" }
	end
	return out
end

local function playerDisplayName(player: Player): string
	if type(player.DisplayName) == "string" and player.DisplayName ~= "" then
		return player.DisplayName
	end
	return player.Name
end

local function runBattle(seed: number, wall: any, waveSpec: any): any
	local battle = Core.Battle.new({
		seed = seed,
		simVersion = Core.SIM_VERSION,
		wall = wall,
		wave = waveSpec,
	})
	return battle:Run()
end

local function runBattleWithTimeline(seed: number, wall: any, waveSpec: any): (any, { any })
	local battle = Core.Battle.new({
		seed = seed,
		simVersion = Core.SIM_VERSION,
		wall = wall,
		wave = waveSpec,
	})
	local timeline = {}
	local function captureSnapshot()
		local units = {}
		for index = 1, battle.uCount do
			if battle.uHp[index] > 0 then
				units[#units + 1] = {
					id = index,
					kind = battle.uType[index] or "runner",
					lane = battle.uLane[index],
					x = battle.uX[index],
					y = battle.uY[index],
					hp = battle.uHp[index],
					isElite = battle.uIsElite[index] == true,
				}
			end
		end
		local frame: { [string]: any } = {
			tick = battle.tick,
			wallHp = math.floor(math.max(0, battle.wallHp) / Core.MILLI),
			wallPct = math.clamp(battle.wallHp / battle.wallMax, 0, 1),
			units = units,
		}
		if battle.boss ~= nil then
			frame.boss = battle:BossSnapshot()
		end
		timeline[#timeline + 1] = frame
	end
	captureSnapshot()
	while not battle:Finished() do
		battle:Step()
		if battle.tick % 2 == 0 or battle:Finished() then
			captureSnapshot()
		end
	end
	return battle:Result(), timeline
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

local function ensureProfileCampaign(profile: any): any
	if type(profile.campaign) ~= "table" then
		profile.campaign = ProfileSchema.template().campaign
	end
	if type(profile.campaign.starsNormal) ~= "table" then
		profile.campaign.starsNormal = {}
	end
	if type(profile.campaign.starsNightmare) ~= "table" then
		profile.campaign.starsNightmare = {}
	end
	if type(profile.campaign.actMilestoneClaims) ~= "table" then
		profile.campaign.actMilestoneClaims = {
			["1"] = 0,
			["2"] = 0,
			["3"] = 0,
			["4"] = 0,
			["5"] = 0,
		}
	end
	return profile.campaign
end

local function buildCampaignSnapshot(profile: any): any
	local campaign = ensureProfileCampaign(profile)
	local actStarsNormal = {}
	local actStarsNightmare = {}
	local totalStarsNormal = 0
	local totalStarsNightmare = 0
	for act = 1, CampaignCatalog.ACT_COUNT do
		local nStars = CampaignCatalog.actStarCount(campaign, act, "normal")
		local nmStars = CampaignCatalog.actStarCount(campaign, act, "nightmare")
		actStarsNormal[act] = nStars
		actStarsNightmare[act] = nmStars
		totalStarsNormal += nStars
		totalStarsNightmare += nmStars
	end
	return {
		ok = true,
		campaign = cloneTable(campaign),
		actStarsNormal = actStarsNormal,
		actStarsNightmare = actStarsNightmare,
		totalStarsNormal = totalStarsNormal,
		totalStarsNightmare = totalStarsNightmare,
		gold = profile.gold,
	}
end

local function clearBusy(player: Player): ()
	activeRaid[player] = nil
	busy[player] = nil
end

local function startCampaignBattle(
	player: Player,
	profile: any,
	battleId: string,
	rawOpts: any
): any
	local stageId = if type(rawOpts.stageId) == "string" then rawOpts.stageId else "1-1"
	local difficulty: CampaignCatalog.DifficultyMode = if rawOpts.difficulty == "nightmare"
		then "nightmare"
		else "normal"
	local campaign = ensureProfileCampaign(profile)
	local stageSpec = CampaignCatalog.getStage(stageId)
	if stageSpec == nil then
		return { ok = false, err = "invalid_stage" }
	end
	local unlocked, unlockErr = CampaignCatalog.isUnlocked(campaign, stageId, difficulty)
	if not unlocked then
		return { ok = false, err = unlockErr or "stage_locked" }
	end

	local wall, wallErr = WallService.toBattleWall(profile, ProfileSchema, TrapCatalog)
	if wall == nil then
		return { ok = false, err = "wall: " .. tostring(wallErr) }
	end
	local stageWallHp = math.max(1, math.floor(stageSpec.wallMaxHpMilli / Core.MILLI))
	wall.hp = math.max(wall.hp or stageWallHp, stageWallHp)

	local waveSpec = CampaignCatalog.toWaveSpec(stageSpec, difficulty)
	local seed = stageSpec.seedFixed + (if difficulty == "nightmare" then 10007 else 0)

	local startedProps =
		RaidTelemetry.startedProps(battleId, seed, Core.SIM_VERSION, Core.GRID_WIDTH, #wall.traps)
	logEvent(player, "battle_started", startedProps)
	logEvent(player, "raid_start", {
		battle_id = battleId,
		mode = "defense",
		speed = RAID_SPEED,
	})

	local result, timeline = runBattleWithTimeline(seed, cloneTable(wall), cloneTable(waveSpec))
	local replay = runBattle(seed, cloneTable(wall), cloneTable(waveSpec))
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

	local playerWon = result.winner == "defender"
	if playerWon then
		local firstWin, firstWinErr = AnalyticsService.emitFirstWin(player, battleId)
		if firstWin == nil and firstWinErr ~= "already_won" and firstWinErr ~= "not_started" then
			warn("[raid] first_win recusado: " .. tostring(firstWinErr))
		end
	end

	local earnedMask, starsEarned = CampaignCatalog.evaluateStars(stageSpec, result)
	local starsTable = if difficulty == "nightmare"
		then campaign.starsNightmare
		else campaign.starsNormal
	local prevMask = tonumber(starsTable[stageId]) or 0
	local isFirstClear = (prevMask == 0) and playerWon
	local newMask = bit32.bor(prevMask, earnedMask)
	if playerWon then
		starsTable[stageId] = newMask
		local nextStage = CampaignCatalog.nextStageId(stageId)
		if nextStage ~= nil then
			local curIdx = CampaignCatalog.stageOrderIndex(campaign.highestUnlockedStage) or 1
			local nextIdx = CampaignCatalog.stageOrderIndex(nextStage) or 1
			if nextIdx > curIdx then
				campaign.highestUnlockedStage = nextStage
			end
		end
		if stageId == "5-5" then
			campaign.nightmareUnlocked = true
		end
	end

	profile.stats.defenses += 1
	local rewardGold = 0
	if playerWon then
		profile.stats.wins += 1
		rewardGold = if isFirstClear then stageSpec.rewardGoldFirst else stageSpec.rewardGoldRepeat
		if difficulty == "nightmare" then
			rewardGold = math.floor(rewardGold * 1500 / 1000)
		end
	end

	local rewarded = true
	local creditedGold = 0
	local goldAfter: number? = nil
	if rewardGold > 0 then
		rewarded, goldAfter = creditRaid(player, battleId, rewardGold, "defense")
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
		if markedRecord ~= nil then
			record = markedRecord
		else
			warn("[raid] nao montou reward no BattleLog: " .. tostring(markErr))
		end
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

	if goldAfter ~= nil then
		player:SetAttribute("MuralhaGold", goldAfter)
	end

	local campaignSnap = cloneTable(campaign)
	local myLeague = TrapCatalog.leagueOf(profile.league.points)
	local myWallLvl = tonumber(wall.level) or 1
	local responsePayload = {
		ok = true,
		mode = "campaign",
		stageId = stageId,
		difficulty = difficulty,
		bossId = stageSpec.bossId,
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
		starsEarned = starsEarned,
		starsMask = newMask,
		campaign = campaignSnap,
		timeline = timeline,
		waveSpec = waveSpec,
		replaySeconds = RaidReplay.SECONDS,
		wall = wall,
		phantomName = stageSpec.name,
		waveCount = waveSpec.count,
		spawnEveryTicks = waveSpec.spawnEveryTicks,
		simVersion = Core.SIM_VERSION,
		record = stored,
		matchup = {
			card1 = {
				side = "left",
				role = "defender",
				faction = "bastion",
				name = playerDisplayName(player),
				league = myLeague,
				points = tonumber(profile.league.points) or 0,
				wallLevel = myWallLvl,
				wallHp = tonumber(wall.hp) or 500,
				trapCount = #wall.traps,
				trapLimit = wallTrapLimit(myWallLvl),
				wins = tonumber(profile.stats.wins) or 0,
				traps = summarizeTraps(wall.traps),
			},
			card2 = {
				side = "right",
				role = if stageSpec.bossId ~= nil then "boss" else "attacker",
				faction = "horde",
				isBot = true,
				name = stageSpec.name,
				stageId = stageId,
				act = stageSpec.act,
				difficulty = difficulty,
				bossId = stageSpec.bossId,
				waveCount = waveSpec.count,
				unitClasses = summarizeWaveClasses(waveSpec),
			},
		},
	}

	pcall(function()
		(raidEvent :: RemoteEvent):FireClient(player, "campaign_result", {
			battleId = battleId,
			stageId = stageId,
			difficulty = difficulty,
			bossId = stageSpec.bossId,
			starsEarned = starsEarned,
			starsMask = newMask,
			campaign = campaignSnap,
			timeline = timeline,
		})
	end)

	return responsePayload
end

local function startRaid(player: Player, rawOpts: any): any
	if busy[player] == true then
		return { ok = false, err = "busy" }
	end
	busy[player] = true
	local isCampaign = type(rawOpts) == "table" and rawOpts.mode == "campaign"
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
		if isCampaign then
			return startCampaignBattle(player, profile, battleId, rawOpts)
		end

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

		local matchup = if isDefend
			then {
				card1 = {
					side = "left",
					role = "defender",
					faction = "bastion",
					name = playerDisplayName(player),
					league = shardLeague,
					points = newPoints,
					wallLevel = myWallLevel,
					wallHp = tonumber(currentSnapshot.hp) or 500,
					trapCount = myTrapCount,
					trapLimit = wallTrapLimit(myWallLevel),
					wins = profile.stats.wins,
					traps = summarizeTraps(currentSnapshot.traps),
				},
				card2 = {
					side = "right",
					role = "attacker",
					faction = "horde",
					isBot = true,
					name = string.format("Horda L%d", targetLeague),
					league = targetLeague,
					waveCount = waveSpec.count,
					unitClasses = summarizeWaveClasses(waveSpec),
				},
			}
			else {
				card1 = {
					side = "left",
					role = "attacker",
					faction = "raider",
					name = playerDisplayName(player),
					league = shardLeague,
					points = newPoints,
					wallLevel = myWallLevel,
					wallHp = tonumber(currentSnapshot.hp) or 500,
					trapCount = myTrapCount,
					trapLimit = wallTrapLimit(myWallLevel),
					waveCount = waveSpec.count,
					wins = profile.stats.wins,
					unitClasses = summarizeWaveClasses(waveSpec),
					traps = summarizeTraps(currentSnapshot.traps),
				},
				card2 = {
					side = "right",
					role = "defender",
					faction = "bastion",
					isBot = isBot,
					name = phantomLabel,
					league = targetLeague,
					wallLevel = tonumber(wall.level) or 1,
					wallHp = tonumber(wall.hp) or 500,
					trapCount = #wall.traps,
					trapLimit = wallTrapLimit(tonumber(wall.level) or 1),
					traps = summarizeTraps(wall.traps),
				},
			}

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
			waveSpec = waveSpec,
			simVersion = Core.SIM_VERSION,
			record = stored,
			matchup = matchup,
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

campaignStateRemote.OnServerInvoke = function(player: Player)
	local profileSession = ProfileRegistry.get(player)
	if profileSession == nil or type(profileSession.Data) ~= "table" then
		return { ok = false, err = "profile" }
	end
	return buildCampaignSnapshot(profileSession.Data)
end

campaignClaimRemote.OnServerInvoke = function(player: Player, rawAct: any, rawTierBit: any)
	local profileSession = ProfileRegistry.get(player)
	if profileSession == nil or type(profileSession.Data) ~= "table" then
		return { ok = false, err = "profile" }
	end
	local profile = profileSession.Data
	local campaign = ensureProfileCampaign(profile)
	local act = rawAct
	local tierBit = rawTierBit
	if type(rawAct) == "table" then
		act = rawAct.act
		tierBit = rawAct.tierBit or rawAct.bit
	end
	act = tonumber(act)
	if act == nil or act % 1 ~= 0 or act < 1 or act > CampaignCatalog.ACT_COUNT then
		return { ok = false, err = "invalid_act" }
	end
	local actKey = tostring(act)
	local currentMask = tonumber(campaign.actMilestoneClaims[actKey]) or 0
	local actStars = CampaignCatalog.actStarCount(campaign, act, "normal")
		+ CampaignCatalog.actStarCount(campaign, act, "nightmare")

	local bitsToClaim = 0
	local goldToCredit = 0
	for _, m in ipairs(CampaignCatalog.ACT_MILESTONES) do
		if tierBit == nil or tonumber(tierBit) == m.bit then
			if actStars >= m.threshold and bit32.band(currentMask, m.bit) == 0 then
				bitsToClaim = bit32.bor(bitsToClaim, m.bit)
				goldToCredit += m.gold
			end
		end
	end
	if bitsToClaim == 0 then
		return {
			ok = false,
			err = "nothing_to_claim",
			claimedMask = currentMask,
			campaign = cloneTable(campaign),
		}
	end

	local newMask = bit32.bor(currentMask, bitsToClaim)
	campaign.actMilestoneClaims[actKey] = newMask

	local claimId = string.lower(HttpService:GenerateGUID(false))
	local rewarded, goldAfter = creditRaid(player, claimId, goldToCredit, "defense")
	if not rewarded then
		campaign.actMilestoneClaims[actKey] = currentMask
		return { ok = false, err = "credit_failed" }
	end
	if goldAfter ~= nil then
		player:SetAttribute("MuralhaGold", goldAfter)
	end

	return {
		ok = true,
		act = act,
		claimedMask = newMask,
		rewardGold = goldToCredit,
		gold = profile.gold,
		campaign = cloneTable(campaign),
	}
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
