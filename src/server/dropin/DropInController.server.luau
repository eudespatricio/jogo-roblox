--!strict
-- S5: cena de abertura com DEFENDER, timeout roteirizado e retry.
-- O estado/tempos sao puros (DropInState); a batalha do press e real (Core, seed 4, muralha
-- pre-montada com catapulta). O visual da cena e local no cliente; o servidor e a verdade.
--
-- Funil: dropin_shown/dropin_pressed passam pelo AnalyticsService (S7), que monta o envelope,
-- valida o contrato v1 e entrega ao sink Null; "[analytics] ..." e o log de debug do servico.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local dropinModules = Shared:WaitForChild("dropin")
local DropInState = require(dropinModules:WaitForChild("DropInState"))
local DropInTelemetry = require(dropinModules:WaitForChild("DropInTelemetry"))
local Core = require(Shared:WaitForChild("sim"):WaitForChild("core"))
local ProfileSchema = require(Shared:WaitForChild("data"):WaitForChild("ProfileSchema"))
local TrapCatalog = require(Shared:WaitForChild("data"):WaitForChild("TrapCatalog"))
local WallService = require(script.Parent.Parent:WaitForChild("walls"):WaitForChild("WallService"))
local ProfileRegistry =
	require(script.Parent.Parent:WaitForChild("data"):WaitForChild("ProfileRegistry"))
local AnalyticsService =
	require(script.Parent.Parent:WaitForChild("analytics"):WaitForChild("AnalyticsService"))

local REMOTES_NAME = "MuralhaRemotes"
local DROPIN_SEED = 4
local RUN_TICKS = 100
local WAVE = { count = 12, spawnEveryTicks = 8 }
local STARTER_GOLD = 40

local function newUuid(): string
	local raw = string.lower(HttpService:GenerateGUID(false))
	if #raw ~= 36 then
		return raw
	end
	return string.sub(raw, 1, 14) .. "4" .. string.sub(raw, 16, 19) .. "8" .. string.sub(raw, 21)
end

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

local actionRemote = ensureRemote("RemoteFunction", "DropInAction") :: RemoteFunction
local snapshotRemote = ensureRemote("RemoteFunction", "DropInSnapshot") :: RemoteFunction

ReplicatedStorage:SetAttribute("DropInEnabled", true)

local sessions: { [Player]: any } = {}

local function nowMs(): number
	return math.floor(workspace:GetServerTimeNow() * 1000)
end

-- Muralha pre-montada do drop-in: 5 traps, uma por lane, com catapulta na lane do meio.
-- A fabrica evita que uma rodada mute a parede da proxima.
local function prebuiltWall(): any
	return {
		level = 1,
		hp = 500,
		traps = {
			{ cell = "r1c3", type = "archer", level = 1, x = 5000, y = 500 },
			{ cell = "r2c3", type = "tar", level = 1, x = 5000, y = 1500 },
			{ cell = "r3c3", type = "catapult", level = 1, x = 5000, y = 2500 },
			{ cell = "r4c3", type = "frost", level = 1, x = 5000, y = 3500 },
			{ cell = "r5c3", type = "cannon", level = 1, x = 5000, y = 4500 },
		},
	}
end

-- Batalha real e deterministica do drop-in: 100 ticks = 5 s de cena. O resultado alimenta o
-- HUD da cena; o jogador nao escolhe loadout nem wave.
local function runDropInBattle(): any
	local battle = Core.Battle.new({
		seed = DROPIN_SEED,
		simVersion = Core.SIM_VERSION,
		wall = prebuiltWall(),
		wave = WAVE,
	})
	for _ = 1, RUN_TICKS do
		if battle:Finished() then
			break
		end
		battle:Step()
	end
	local result = battle:Result()
	return {
		winner = result.winner,
		wallHp = result.wallHp,
		wallPct = result.wallPct,
		killed = result.killed,
		leaked = result.leaked,
		ticks = result.ticks,
		seed = result.seed,
		hash = result.hash,
		simVersion = Core.SIM_VERSION,
	}
end

local function logAnalytics(player: Player, name: string, props: any): ()
	local event, err = AnalyticsService.emit(player, name, props)
	if event == nil then
		if err == "not_started" then
			-- Fallback de QA se o AnalyticsBoot ainda nao subiu; nao substitui o envelope.
			print(DropInTelemetry.format(name, props))
		else
			warn("[dropin] analytics " .. name .. " recusado: " .. tostring(err))
		end
	end
end

local function logShown(session: any, player: Player, msSinceJoin: number): ()
	local props, err = DropInTelemetry.shownProps(msSinceJoin)
	if props == nil then
		warn("[dropin] shown props invalidas: " .. tostring(err))
		return
	end
	local event, emitErr = AnalyticsService.emit(player, "dropin_shown", props)
	if event ~= nil then
		session.shownLogged = true
	elseif emitErr == "not_started" then
		session.shownLogged = true
		print(DropInTelemetry.format("dropin_shown", props))
	elseif emitErr ~= "no_session" then
		warn("[dropin] analytics dropin_shown recusado: " .. tostring(emitErr))
	end
end

local function logPressed(player: Player, msSinceJoin: number): ()
	local props, err = DropInTelemetry.pressedProps(msSinceJoin, true)
	if props == nil then
		warn("[dropin] pressed props invalidas: " .. tostring(err))
		return
	end
	logAnalytics(player, "dropin_pressed", props)
end

-- Starter grant unico (AUD-05): +40 ouro ao limpar a onda apenas na 1a defesa (defenses == 0),
-- comprando a 1a armadilha (archer). Veteranos (defenses > 0) recebem 0g e seguem para DropInDone.
local function grantReward(player: Player): boolean
	for _ = 1, 100 do
		if player.Parent ~= Players then
			return false
		end
		local profileSession = ProfileRegistry.get(player)
		if profileSession ~= nil and type(profileSession.Data) == "table" then
			local data = profileSession.Data
			if type(data.stats) ~= "table" or type(data.stats.defenses) ~= "number" then
				warn("[dropin] starter grant: profile.stats.defenses invalido")
				return false
			end
			if data.stats.defenses ~= 0 then
				return true
			end
			local serviceOk, service = pcall(function()
				return WallService.new({
					profile = data,
					schema = ProfileSchema,
					catalog = TrapCatalog,
					emit = function(name: string, props: { [string]: any })
						logAnalytics(player, name, props)
					end,
				})
			end)
			if not serviceOk then
				warn("[dropin] reward: WallService.new falhou: " .. tostring(service))
				return false
			end
			data.stats.defenses = 1
			local result, err = service.creditGold(STARTER_GOLD, "defense", nil)
			if result == nil then
				warn("[dropin] starter grant recusado: " .. tostring(err))
				return false
			end
			print(string.format("[dropin] +%d ouro gold=%d", STARTER_GOLD, result.gold))
			return true
		end
		task.wait(0.1)
	end
	warn("[dropin] reward: perfil nao carregou em 10 s")
	return false
end

local function snapshotFor(player: Player, logShownEvent: boolean?): any
	local session = sessions[player]
	if session == nil then
		local joinAt = nowMs()
		session = {
			state = DropInState.new(joinAt),
			joinAtMs = joinAt,
			shownLogged = false,
			defeatedLogged = false,
			battleId = nil,
			battleResult = nil,
		}
		sessions[player] = session
		player:SetAttribute("DropInDone", false)
	end

	local now = nowMs()
	local changed = DropInState.tick(session.state, now)
	local phase = session.state.phase

	if logShownEvent == true and not session.shownLogged and phase == DropInState.PHASE_SHOWN then
		logShown(session, player, now - session.joinAtMs)
	end
	if changed and phase == DropInState.PHASE_CLEARED then
		print(string.format("[dropin] onda limpa em %.1fs", (now - session.joinAtMs) / 1000))
		if
			session.battleId ~= nil
			and session.battleResult ~= nil
			and session.battleResult.winner == "defender"
		then
			local firstWin, firstWinErr = AnalyticsService.emitFirstWin(player, session.battleId)
			if
				firstWin == nil
				and firstWinErr ~= "already_won"
				and firstWinErr ~= "not_started"
			then
				warn("[dropin] first_win recusado: " .. tostring(firstWinErr))
			end
		end
		if not session.rewardStarted then
			session.rewardStarted = true
			task.spawn(function()
				local ok, err = pcall(grantReward, player)
				if not ok then
					warn("[dropin] reward falhou: " .. tostring(err))
				end
				if player.Parent == Players then
					player:SetAttribute("DropInDone", true)
				end
			end)
		end
	elseif changed and phase == DropInState.PHASE_DEFEATED then
		session.defeatedLogged = true
		print(
			string.format("[dropin] derrota roteirizada em %.1fs", (now - session.joinAtMs) / 1000)
		)
	end

	local snapshot: { [string]: any } = DropInState.snapshot(session.state, now) :: any
	snapshot.msSinceJoin = now - session.joinAtMs
	snapshot.joinAtMs = session.joinAtMs
	return snapshot
end

local function handleAction(player: Player, action: any): any
	if type(action) ~= "string" then
		return { ok = false, err = "bad_action" }
	end
	local session = sessions[player]
	if session == nil then
		snapshotFor(player, false)
		session = sessions[player]
	end
	if session == nil then
		return { ok = false, err = "no_session" }
	end

	local now = nowMs()
	if action == "press" then
		local ok, err = DropInState.press(session.state, now)
		if not ok then
			return { ok = false, err = err, snapshot = snapshotFor(player, true) }
		end
		local battleId = newUuid()
		local started, startedErr = AnalyticsService.emit(player, "battle_started", {
			battle_id = battleId,
			seed = DROPIN_SEED,
			sim_version = Core.SIM_VERSION,
			grid_width = Core.GRID_WIDTH,
			traps_count = #prebuiltWall().traps,
		})
		if started == nil and startedErr ~= "not_started" then
			warn("[dropin] battle_started recusado: " .. tostring(startedErr))
		end
		local result = runDropInBattle()
		local finished, finishedErr = AnalyticsService.emit(player, "battle_finished", {
			battle_id = battleId,
			seed = result.seed,
			sim_version = result.simVersion,
			result_hash = result.hash,
			winner = result.winner,
			wall_hp = result.wallHp,
			leaked = result.leaked,
			ticks = result.ticks,
			duration_ms = result.ticks * 50,
		})
		if finished == nil and finishedErr ~= "not_started" then
			warn("[dropin] battle_finished recusado: " .. tostring(finishedErr))
		end
		session.battleId = battleId
		session.battleResult = result
		local resultOk, resultErr = DropInState.setResult(session.state, result)
		if not resultOk then
			warn("[dropin] resultado invalido: " .. tostring(resultErr))
		end
		logPressed(player, now - session.joinAtMs)
		return { ok = true, snapshot = snapshotFor(player, true) }
	elseif action == "retry" then
		local ok, err = DropInState.retry(session.state, now)
		if not ok then
			return { ok = false, err = err, snapshot = snapshotFor(player, true) }
		end
		session.shownLogged = false
		session.defeatedLogged = false
		player:SetAttribute("DropInDone", false)
		print("[dropin] retry; cena reaberta")
		return { ok = true, snapshot = snapshotFor(player, true) }
	end
	return { ok = false, err = "bad_action" }
end

actionRemote.OnServerInvoke = function(player: Player, action: any)
	local ok, result = pcall(handleAction, player, action)
	if not ok then
		warn("[dropin] acao falhou: " .. tostring(result))
		return { ok = false, err = "internal" }
	end
	return result
end

snapshotRemote.OnServerInvoke = function(player: Player)
	local ok, snapshot = pcall(snapshotFor, player, true)
	if not ok then
		warn("[dropin] snapshot falhou: " .. tostring(snapshot))
		return nil
	end
	return snapshot
end

Players.PlayerAdded:Connect(function(player: Player)
	if snapshotFor(player, false) ~= nil then
		print("[dropin] jogador na cena " .. tostring(player.Name))
	end
end)

Players.PlayerRemoving:Connect(function(player: Player)
	sessions[player] = nil
end)

-- Heartbeat do timeout: sem isso, quem nao clica nunca sai da cena de abertura.
task.spawn(function()
	while true do
		task.wait(0.1)
		for player in pairs(sessions) do
			if player.Parent == Players then
				snapshotFor(player, false)
			else
				sessions[player] = nil
			end
		end
	end
end)

-- Play Solo: jogador ja pode estar no servidor antes do script rodar.
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(snapshotFor, player, false)
end

print(
	string.format(
		"[dropin] servidor pronto seed=%d ticks=%d (batalha real; visual local no cliente)",
		DROPIN_SEED,
		RUN_TICKS
	)
)
