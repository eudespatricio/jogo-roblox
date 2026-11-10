--!nonstrict
-- S5: cena de abertura com DEFENDER, timeout roteirizado e retry.
-- O estado/tempos sao puros (DropInState); a batalha do press e real (Core, seed 4, muralha
-- pre-montada com catapulta). O visual da cena e local no cliente; o servidor e a verdade.
--
-- Funil: dropin_shown/dropin_pressed saem como props validadas da taxonomia v1 e sao logados
-- com "[analytics] ...". O envelope/sink e a S7 (AnalyticsService); a S5 nao cria um sink falso.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local dropinModules = Shared:WaitForChild("dropin")
local DropInState = require(dropinModules:WaitForChild("DropInState"))
local DropInTelemetry = require(dropinModules:WaitForChild("DropInTelemetry"))
local Core = require(Shared:WaitForChild("sim"):WaitForChild("core"))

local REMOTES_NAME = "MuralhaRemotes"
local DROPIN_SEED = 4
local RUN_TICKS = 100
local WAVE = { count = 12, spawnEveryTicks = 8 }

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
		hp = 500,
		traps = {
			{ cell = "r1c3", type = "archer", level = 1 },
			{ cell = "r2c3", type = "tar", level = 1 },
			{ cell = "r3c3", type = "catapult", level = 1 },
			{ cell = "r4c3", type = "frost", level = 1 },
			{ cell = "r5c3", type = "cannon", level = 1 },
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
	}
end

local function logShown(session: any, msSinceJoin: number): ()
	local props, err = DropInTelemetry.shownProps(msSinceJoin)
	if props == nil then
		warn("[dropin] shown props invalidas: " .. tostring(err))
		return
	end
	session.shownLogged = true
	print(DropInTelemetry.format("dropin_shown", props))
end

local function logPressed(session: any, msSinceJoin: number): ()
	local props, err = DropInTelemetry.pressedProps(msSinceJoin, true)
	if props == nil then
		warn("[dropin] pressed props invalidas: " .. tostring(err))
		return
	end
	print(DropInTelemetry.format("dropin_pressed", props))
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
		}
		sessions[player] = session
		player:SetAttribute("DropInDone", false)
	end

	local now = nowMs()
	local changed = DropInState.tick(session.state, now)
	local phase = session.state.phase

	if logShownEvent == true and not session.shownLogged and phase == DropInState.PHASE_SHOWN then
		logShown(session, now - session.joinAtMs)
	end
	if changed and phase == DropInState.PHASE_CLEARED then
		player:SetAttribute("DropInDone", true)
		print(string.format("[dropin] onda limpa em %.1fs", (now - session.joinAtMs) / 1000))
	elseif changed and phase == DropInState.PHASE_DEFEATED then
		session.defeatedLogged = true
		print(
			string.format("[dropin] derrota roteirizada em %.1fs", (now - session.joinAtMs) / 1000)
		)
	end

	local snapshot = DropInState.snapshot(session.state, now)
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
		local result = runDropInBattle()
		local resultOk, resultErr = DropInState.setResult(session.state, result)
		if not resultOk then
			warn("[dropin] resultado invalido: " .. tostring(resultErr))
		end
		logPressed(session, now - session.joinAtMs)
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
