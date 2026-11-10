--!nonstrict
-- S7: liga o AnalyticsService ao servidor. O servico e puro; aqui ficam o relogio, o UUID,
-- o contexto do jogador (player_id com salt, nunca UserId cru), o sink e o ciclo de sessao
-- (join/leave/shutdown). O envelope e validado pelo contrato v1 antes de entrar no lote.
--
-- Sink (GAP-012): producao usa DataStore em lote (`MuralhaAnalytics_v1`); Studio usa Memory
-- por padrao. ServerStorage.AnalyticsSink = "DataStore" | "Memory" | "Null" forca o modo.
-- Debug: no Studio (ou com ServerStorage.AnalyticsDebug=true) cada evento aceito sai como
-- "[analytics] <nome> <props>" e cada lote como "[analytics] lote ...".

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local AnalyticsTypes = require(Shared:WaitForChild("analytics"):WaitForChild("AnalyticsTypes"))
local ProfileSchema = require(Shared:WaitForChild("data"):WaitForChild("ProfileSchema"))

local ProfileRegistry =
	require(script.Parent.Parent:WaitForChild("data"):WaitForChild("ProfileRegistry"))
local AnalyticsService = require(script.Parent:WaitForChild("AnalyticsService"))
local AnalyticsDataStoreSink = require(script.Parent:WaitForChild("AnalyticsDataStoreSink"))

local DEBUG = RunService:IsStudio() or ServerStorage:GetAttribute("AnalyticsDebug") == true
local SALT =
	tostring(ServerStorage:GetAttribute("AnalyticsSalt") or ("Muralha:" .. tostring(game.PlaceId)))
local EXPERIMENT = ServerStorage:GetAttribute("AnalyticsExperiment")

local PLATFORMS = { mobile = true, pc = true, console = true, vr = true }
local DEVICE_TIERS = { low = true, mid = true, high = true }

local function formatEvent(event: any): string
	local parts = { "[analytics]", tostring(event.event_name) }
	local keys = {}
	for key in pairs(event) do
		if AnalyticsService.ENVELOPE_FIELDS[key] ~= true then
			keys[#keys + 1] = key
		end
	end
	table.sort(keys)
	for _, key in ipairs(keys) do
		parts[#parts + 1] = string.format("%s=%s", key, tostring(event[key]))
	end
	return table.concat(parts, " ")
end

local function formatSeconds(value: any): string
	if type(value) ~= "number" then
		return "-"
	end
	return string.format("%.1f", value)
end

-- UUID v4 canonico: uma GUI gerada pelo Roblox pode nao ter a versao/variante que o contrato exige.
local function newUuid(): string
	local raw = string.lower(HttpService:GenerateGUID(false))
	if #raw ~= 36 then
		return raw
	end
	return string.sub(raw, 1, 14) .. "4" .. string.sub(raw, 16, 19) .. "8" .. string.sub(raw, 21)
end

local function normalizeLocale(raw: any): string
	if type(raw) == "string" then
		local language, region = string.match(string.lower(raw), "^(%a%a)[-_](%a%a)$")
		if language ~= nil and region ~= nil then
			return language .. "-" .. string.upper(region)
		end
	end
	return "pt-BR"
end

local function platformFor(player: Player): string
	local value = player:GetAttribute("MuralhaPlatform")
	if type(value) == "string" and PLATFORMS[value] == true then
		return value
	end
	if RunService:IsStudio() then
		return "pc"
	end
	return "mobile"
end

local function deviceTierFor(player: Player): string
	local value = player:GetAttribute("MuralhaDeviceTier")
	if type(value) == "string" and DEVICE_TIERS[value] == true then
		return value
	end
	return "mid"
end

local function nowMs(): number
	return DateTime.now().UnixTimestampMillis
end

local function resolveSink(): (any, string)
	local requested = ServerStorage:GetAttribute("AnalyticsSink")
	if requested == "Null" then
		return AnalyticsService.NullSink(AnalyticsTypes), "Null"
	end
	local wantDataStore = requested == "DataStore"
		or (requested == nil and not RunService:IsStudio())
	if wantDataStore then
		local ok, dataStore = pcall(function()
			return DataStoreService:GetDataStore(AnalyticsDataStoreSink.STORE_NAME)
		end)
		if ok and dataStore ~= nil then
			return AnalyticsDataStoreSink.new({
				types = AnalyticsTypes,
				store = dataStore,
				now = nowMs,
			}),
				"DataStore"
		end
		warn("[analytics] DataStore indisponivel; caindo para Memory: " .. tostring(dataStore))
	end
	local memory = AnalyticsDataStoreSink.new({
		types = AnalyticsTypes,
		mock = true,
		now = nowMs,
	})
	return memory, "Memory"
end

local sink, sinkName = resolveSink()

local service = AnalyticsService.new({
	types = AnalyticsTypes,
	sink = sink,
	now = nowMs,
	generateId = newUuid,
	onError = function(message: string)
		warn("[analytics] " .. message)
	end,
	onEvent = function(event: any)
		if DEBUG then
			print(formatEvent(event))
		end
	end,
	onFlush = function(events: { any }, reason: string)
		if DEBUG then
			print(string.format("[analytics] lote reason=%s n=%d", reason, #events))
		end
	end,
})

AnalyticsService.start(service)
print(
	string.format(
		"[analytics] sink=%s name=%s",
		sinkName,
		sinkName == "DataStore" and AnalyticsDataStoreSink.STORE_NAME or "-"
	)
)

local function waitForProfile(player: Player): any?
	for _ = 1, 100 do
		if player.Parent ~= Players then
			return nil
		end
		local profileSession = ProfileRegistry.get(player)
		if profileSession ~= nil and type(profileSession.Data) == "table" then
			return profileSession
		end
		task.wait(0.1)
	end
	return nil
end

local function startSession(player: Player): ()
	local profileSession = waitForProfile(player)
	if profileSession == nil then
		warn("[analytics] perfil nao carregou; sessao de telemetria nao iniciada")
		return
	end
	local key = ProfileSchema.keyFor(player.UserId)
	local info = AnalyticsService.takeProfileStart(key)
	local returning = type(info) == "table" and info.daysSinceLastSeen ~= nil
	local event, err = service.beginSession(player, {
		player_id = AnalyticsService.hashId(tostring(player.UserId), SALT),
		session_id = newUuid(),
		place_version = "v" .. tostring(game.PlaceVersion),
		platform = platformFor(player),
		device_tier = deviceTierFor(player),
		locale = normalizeLocale(player.LocaleId),
		is_age_checked = player:GetAttribute("MuralhaAgeChecked") == true,
		server_id = AnalyticsService.hashId(tostring(game.JobId), SALT),
		experiment = type(EXPERIMENT) == "string" and EXPERIMENT or nil,
		is_returning = returning,
		days_since_last_seen = returning and (info.daysSinceLastSeen :: number) or -1,
	})
	if event == nil then
		if err ~= "session_exists" then
			warn("[analytics] session_start recusado: " .. tostring(err))
		end
		return
	end
	print(
		string.format(
			"[analytics] sessao iniciada returning=%s sink=%s (player_id hash32)",
			tostring(returning),
			sinkName
		)
	)
end

local function finishSession(player: Player): ()
	local event, err = service.endSession(player, "leave")
	if event == nil and err ~= "no_session" then
		warn("[analytics] session_end recusado: " .. tostring(err))
	end
	local report = service.getFirstWinReport()
	print(
		string.format(
			"[analytics] first_win_seconds novas=%d ganhos=%d <60s=%d taxa=%.1f%% p50=%ss p95=%ss (amostra deste servidor; sink %s)",
			report.new_players,
			report.new_player_first_wins,
			report.new_player_under_60,
			report.rate_under_60 * 100,
			formatSeconds(report.p50_seconds),
			formatSeconds(report.p95_seconds),
			sinkName
		)
	)
end

Players.PlayerAdded:Connect(function(player: Player)
	task.spawn(startSession, player)
end)

Players.PlayerRemoving:Connect(finishSession)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		service.endSession(player, "leave")
	end
	service.flush("shutdown")
end)

task.spawn(function()
	while true do
		task.wait(1)
		service.tick()
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(startSession, player)
end

print(
	string.format(
		"[analytics] servico pronto sink=%s flush=%ds/%d rate=%d/min debug=%s",
		sinkName,
		AnalyticsService.FLUSH_INTERVAL_MS / 1000,
		AnalyticsService.MAX_BATCH,
		AnalyticsService.MAX_CLIENT_EVENTS_PER_MINUTE,
		tostring(DEBUG)
	)
)
