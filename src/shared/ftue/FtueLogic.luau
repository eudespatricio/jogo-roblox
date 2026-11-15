--!strict
-- Logica pura do FTUE guiado (ftueStep 0..6, GAP-020).
-- Sem dependencia de Roblox API: roda no servidor e no contrato CLI (sim/postmatch-contract.luau).

local FtueLogic = {}

FtueLogic.MAX_STEP = 6
FtueLogic.SKIP_MIN_STEP = 1
FtueLogic.COOLDOWN_SECONDS = 1.0
FtueLogic.SKIP_FALLBACK_GOLD = 40

export type StepReward = {
	gold: number,
	source: string,
}

export type AdvanceResult = {
	advanced: boolean,
	fromStep: number,
	toStep: number,
	rewardGold: number,
	rewardSource: string,
}

export type StepDescriptor = {
	step: number,
	hintKey: string,
	targetFocus: string,
}

local STEP_REWARDS: { [number]: StepReward } = {
	[1] = { gold = 0, source = "defense" },
	[2] = { gold = 20, source = "defense" },
	[3] = { gold = 25, source = "raid" },
	[4] = { gold = 30, source = "defense" },
	[5] = { gold = 25, source = "defense" },
	[6] = { gold = 40, source = "daily" },
}

local DESCRIPTORS: { [number]: StepDescriptor } = {
	[0] = { step = 0, hintKey = "ftue_step_1", targetFocus = "none" },
	[1] = { step = 1, hintKey = "ftue_step_1", targetFocus = "trapDock" },
	[2] = { step = 2, hintKey = "ftue_step_2", targetFocus = "attackBtn" },
	[3] = { step = 3, hintKey = "ftue_step_3", targetFocus = "toolsDock" },
	[4] = { step = 4, hintKey = "ftue_step_4", targetFocus = "logBtn" },
	[5] = { step = 5, hintKey = "ftue_step_5", targetFocus = "storyBtn" },
	[6] = { step = 6, hintKey = "ftue_done_toast", targetFocus = "none" },
}

local COLUMN_X = { 2000, 3500, 5000, 6500, 8000 }
local SYN_DX = 1500
local SYN_DY = 1000
local LANE_REACH = 750

local function resolvePos(slot: string, cell: any): (number?, number?)
	if type(cell.x) == "number" and type(cell.y) == "number" then
		return cell.x, cell.y
	end
	local rStr, cStr = string.match(slot, "^r(%d+)c(%d+)$")
	if rStr ~= nil and cStr ~= nil then
		local r = tonumber(rStr)
		local c = tonumber(cStr)
		if r ~= nil and c ~= nil and r >= 1 and r <= 5 and c >= 1 and c <= 5 then
			return COLUMN_X[c], (r - 1) * 1000 + 500
		end
	end
	return nil, nil
end

function FtueLogic.hasSpatialSynergy(cells: any): boolean
	if type(cells) ~= "table" then
		return false
	end
	local list: { { trap: string, x: number, y: number } } = {}
	for slot, data in pairs(cells) do
		if type(slot) == "string" and type(data) == "table" and type(data.trap) == "string" then
			local x, y = resolvePos(slot, data)
			if x ~= nil and y ~= nil then
				list[#list + 1] = { trap = data.trap, x = x, y = y }
			end
		end
	end
	for i = 1, #list do
		local a = list[i]
		for j = i + 1, #list do
			local b = list[j]
			if a.trap == "archer" and b.trap == "archer" then
				local dx = math.abs(a.x - b.x)
				local dy = math.abs(a.y - b.y)
				if dx * SYN_DY + dy * SYN_DX <= SYN_DX * SYN_DY then
					return true
				end
			end
			if math.abs(a.y - b.y) <= LANE_REACH then
				if
					(a.trap == "tar" and (b.trap == "cannon" or b.trap == "catapult"))
					or (b.trap == "tar" and (a.trap == "cannon" or a.trap == "catapult"))
				then
					return true
				end
				if
					(a.trap == "frost" and b.trap == "cannon")
					or (b.trap == "frost" and a.trap == "cannon")
				then
					return true
				end
			end
		end
	end
	return false
end

local function countTraps(cells: any): number
	if type(cells) ~= "table" then
		return 0
	end
	local count = 0
	for _ in pairs(cells) do
		count += 1
	end
	return count
end

local function hasUpgradeOrSynergy(profile: any): boolean
	local wall = if type(profile) == "table" then profile.wall else nil
	if type(wall) ~= "table" then
		return false
	end
	if (tonumber(wall.level) or 1) >= 2 then
		return true
	end
	if type(wall.cells) == "table" then
		for _, cell in pairs(wall.cells) do
			if type(cell) == "table" and (tonumber(cell.level) or 1) >= 2 then
				return true
			end
		end
		if FtueLogic.hasSpatialSynergy(wall.cells) then
			return true
		end
	end
	return false
end

local function hasAnyCampaignStar(profile: any): boolean
	local campaign = if type(profile) == "table" then profile.campaign else nil
	if type(campaign) ~= "table" then
		return false
	end
	for _, mapName in ipairs({ "starsNormal", "starsNightmare" }) do
		local starsMap = campaign[mapName]
		if type(starsMap) == "table" then
			for _, mask in pairs(starsMap) do
				if (tonumber(mask) or 0) > 0 then
					return true
				end
			end
		end
	end
	return false
end

local function ensureFtueTable(
	profile: any
): { step: number, skipped: boolean, completedAt: number }
	if type(profile.ftue) ~= "table" then
		profile.ftue = { step = 0, skipped = false, completedAt = 0 }
	end
	local ftue = profile.ftue
	ftue.step = math.clamp(math.floor(tonumber(ftue.step) or 0), 0, FtueLogic.MAX_STEP)
	ftue.skipped = ftue.skipped == true
	ftue.completedAt = math.max(0, math.floor(tonumber(ftue.completedAt) or 0))
	return ftue
end

function FtueLogic.descriptor(step: number): StepDescriptor
	local clamped = math.clamp(math.floor(tonumber(step) or 0), 0, FtueLogic.MAX_STEP)
	return DESCRIPTORS[clamped] or DESCRIPTORS[6]
end

function FtueLogic.advance(profile: any, eventName: string?, nowUtc: number?): AdvanceResult
	local ftue = ensureFtueTable(profile)
	local fromStep = ftue.step
	if fromStep >= FtueLogic.MAX_STEP then
		return {
			advanced = false,
			fromStep = fromStep,
			toStep = fromStep,
			rewardGold = 0,
			rewardSource = "defense",
		}
	end

	local stats = if type(profile.stats) == "table" then profile.stats else {}
	local wall = if type(profile.wall) == "table" then profile.wall else {}
	local cells = wall.cells
	local ev = tostring(eventName or "")
	local totalReward = 0
	local rewardSource = "defense"

	while ftue.step < FtueLogic.MAX_STEP do
		local cur = ftue.step
		local satisfied = false
		if cur == 0 then
			satisfied = ev == "dropin_cleared" or (tonumber(stats.defenses) or 0) > 0
		elseif cur == 1 then
			satisfied = countTraps(cells) >= 1
		elseif cur == 2 then
			satisfied = ev == "raid_completed"
				or ev == "raid_won"
				or ev == "revenge"
				or ev == "revenge_won"
				or (tonumber(stats.raids) or 0) > 0
		elseif cur == 3 then
			satisfied = hasUpgradeOrSynergy(profile)
		elseif cur == 4 then
			satisfied = ev == "replay_watched"
				or ev == "revenge"
				or ev == "revenge_won"
				or ev == "log_opened"
				or ev == "defend"
		elseif cur == 5 then
			satisfied = ev == "campaign_won"
				or ev == "raid_won"
				or ev == "revenge_won"
				or hasAnyCampaignStar(profile)
		end

		if not satisfied then
			break
		end

		local nextStep = cur + 1
		ftue.step = nextStep
		local rewardDef = STEP_REWARDS[nextStep]
		if rewardDef ~= nil and rewardDef.gold > 0 then
			totalReward += rewardDef.gold
			rewardSource = rewardDef.source
		end
	end

	if ftue.step == FtueLogic.MAX_STEP and ftue.completedAt == 0 then
		ftue.completedAt = math.max(0, math.floor(tonumber(nowUtc) or 0))
	end

	return {
		advanced = ftue.step > fromStep,
		fromStep = fromStep,
		toStep = ftue.step,
		rewardGold = totalReward,
		rewardSource = rewardSource,
	}
end

function FtueLogic.skip(profile: any, nowUtc: number?): (boolean, string?, number)
	if type(profile) ~= "table" then
		return false, "bad_profile", 0
	end
	local ftue = ensureFtueTable(profile)
	if ftue.step >= FtueLogic.MAX_STEP then
		return false, "ftue_done", 0
	end
	if ftue.step < FtueLogic.SKIP_MIN_STEP then
		return false, "dropin_first", 0
	end

	local stats = if type(profile.stats) == "table" then profile.stats else {}
	local defenses = tonumber(stats.defenses) or 0
	local gold = tonumber(profile.gold) or 0
	local grantGold = if defenses == 0 and gold == 0 then FtueLogic.SKIP_FALLBACK_GOLD else 0

	ftue.step = FtueLogic.MAX_STEP
	ftue.skipped = true
	ftue.completedAt = math.max(0, math.floor(tonumber(nowUtc) or 0))
	return true, nil, grantGold
end

return FtueLogic
