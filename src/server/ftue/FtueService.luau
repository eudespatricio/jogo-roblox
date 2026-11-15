--!strict
-- Servico de FTUE guiado no servidor (ftueStep 0..6, GAP-020).
-- Atualiza o perfil autoritativo via FtueLogic, credita recompensas em WallService,
-- sincroniza atributos para a HUD e emite eventos ftue_step / ftue_skip.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local FtueLogic = require(Shared:WaitForChild("ftue"):WaitForChild("FtueLogic"))
local ProfileSchema = require(Shared:WaitForChild("data"):WaitForChild("ProfileSchema"))
local TrapCatalog = require(Shared:WaitForChild("data"):WaitForChild("TrapCatalog"))

local ProfileRegistry =
	require(script.Parent.Parent:WaitForChild("data"):WaitForChild("ProfileRegistry"))
local WallService = require(script.Parent.Parent:WaitForChild("walls"):WaitForChild("WallService"))
local AnalyticsService =
	require(script.Parent.Parent:WaitForChild("analytics"):WaitForChild("AnalyticsService"))

local FtueService = {}

local lastSkipAt: { [Player]: number } = {}

Players.PlayerRemoving:Connect(function(player: Player)
	lastSkipAt[player] = nil
end)

local function sanitizeTrigger(eventName: string?): string
	local raw = tostring(eventName or "boot")
	if #raw > 32 then
		raw = string.sub(raw, 1, 32)
	end
	if string.match(raw, "^[%w_%.%-]+$") == nil then
		return "event"
	end
	return raw
end

local function emitAnalytics(player: Player, name: string, props: { [string]: any }): ()
	local _, err = AnalyticsService.emit(player, name, props)
	if err ~= nil and err ~= "not_started" and err ~= "no_session" then
		warn("[ftue] analytics " .. name .. " recusado: " .. tostring(err))
	end
end

local function creditFtueGold(
	player: Player,
	profile: any,
	amount: number,
	source: string,
	battleId: string
): boolean
	if amount <= 0 then
		return true
	end
	local ok, service = pcall(function()
		return WallService.new({
			profile = profile,
			schema = ProfileSchema,
			catalog = TrapCatalog,
			emit = function(name: string, props: { [string]: any })
				emitAnalytics(player, name, props)
			end,
		})
	end)
	if not ok or service == nil then
		warn("[ftue] WallService.new falhou: " .. tostring(service))
		return false
	end
	local res, err = service.creditGold(amount, source, battleId)
	if res == nil then
		warn("[ftue] creditGold recusado (" .. source .. "): " .. tostring(err))
		return false
	end
	player:SetAttribute("MuralhaGold", res.gold)
	return true
end

function FtueService.syncAttributes(player: Player, profile: any): ()
	if player.Parent ~= Players or type(profile) ~= "table" then
		return
	end
	local ftue = if type(profile.ftue) == "table" then profile.ftue else nil
	local step = if ftue ~= nil
		then math.clamp(math.floor(tonumber(ftue.step) or 0), 0, FtueLogic.MAX_STEP)
		else 0
	local skipped = ftue ~= nil and ftue.skipped == true
	player:SetAttribute("MuralhaFtueStep", step)
	player:SetAttribute("MuralhaFtueSkipped", skipped)
	if type(profile.gold) == "number" then
		player:SetAttribute("MuralhaGold", math.max(0, math.floor(profile.gold)))
	end
end

function FtueService.stateFor(player: Player): any
	local session = ProfileRegistry.get(player)
	if session == nil or type(session.Data) ~= "table" then
		return nil
	end
	local data = session.Data
	local ftue = if type(data.ftue) == "table"
		then data.ftue
		else { step = 0, skipped = false, completedAt = 0 }
	local step = math.clamp(math.floor(tonumber(ftue.step) or 0), 0, FtueLogic.MAX_STEP)
	return {
		step = step,
		skipped = ftue.skipped == true,
		completedAt = math.max(0, math.floor(tonumber(ftue.completedAt) or 0)),
		descriptor = FtueLogic.descriptor(step),
		gold = math.max(0, math.floor(tonumber(data.gold) or 0)),
	}
end

function FtueService.notify(player: Player, eventName: string?): any
	local session = ProfileRegistry.get(player)
	if session == nil or type(session.Data) ~= "table" then
		return nil
	end
	local data = session.Data
	local res = FtueLogic.advance(data, eventName, os.time())
	if res.advanced then
		if res.rewardGold > 0 then
			creditFtueGold(
				player,
				data,
				res.rewardGold,
				res.rewardSource,
				"ftue_step_" .. tostring(res.toStep)
			)
		end
		FtueService.syncAttributes(player, data)
		emitAnalytics(player, "ftue_step", {
			from_step = res.fromStep,
			to_step = res.toStep,
			trigger = sanitizeTrigger(eventName),
			reward_gold = res.rewardGold,
		})
	else
		FtueService.syncAttributes(player, data)
	end
	return {
		step = res.toStep,
		advanced = res.advanced,
		rewardGold = res.rewardGold,
		descriptor = FtueLogic.descriptor(res.toStep),
		gold = math.max(0, math.floor(tonumber(data.gold) or 0)),
	}
end

function FtueService.skip(player: Player): any
	local now = os.clock()
	local prev = lastSkipAt[player]
	if prev ~= nil and (now - prev) < FtueLogic.COOLDOWN_SECONDS then
		return { ok = false, err = "rate_limit" }
	end
	lastSkipAt[player] = now

	local session = ProfileRegistry.get(player)
	if session == nil or type(session.Data) ~= "table" then
		return { ok = false, err = "no_session" }
	end
	local data = session.Data
	local beforeStep = if type(data.ftue) == "table"
		then math.clamp(math.floor(tonumber(data.ftue.step) or 0), 0, FtueLogic.MAX_STEP)
		else 0

	local ok, err, fallbackGold = FtueLogic.skip(data, os.time())
	if not ok then
		return { ok = false, err = err or "skip_rejected", ftue = FtueService.stateFor(player) }
	end

	if fallbackGold > 0 then
		if type(data.stats) == "table" then
			data.stats.defenses = math.max(1, math.floor(tonumber(data.stats.defenses) or 0))
		end
		creditFtueGold(player, data, fallbackGold, "defense", "ftue_skip_starter")
	end

	FtueService.syncAttributes(player, data)
	if player.Parent == Players then
		player:SetAttribute("DropInDone", true)
	end
	emitAnalytics(player, "ftue_skip", {
		at_step = beforeStep,
		fallback_gold = fallbackGold,
	})
	return {
		ok = true,
		fallbackGold = fallbackGold,
		ftue = FtueService.stateFor(player),
		gold = math.max(0, math.floor(tonumber(data.gold) or 0)),
	}
end

return FtueService
