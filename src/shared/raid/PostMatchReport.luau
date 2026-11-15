--!strict
-- Relatorio Pos-Partida (GAP-020): Medidor de Dano por Armadilha (DPS/Eficiencia/MVP),
-- Comparativo de Setores e Diagnostico Automatico de Vazamento.
-- Puro Luau: zero dependencia de Roblox API e zero impacto no hash da simulacao.

local PostMatchReport = {}

export type TrapCombatReport = {
	cell: string,
	trapId: string,
	level: number,
	x: number,
	y: number,
	damageDealt: number,
	damageHp: number,
	kills: number,
	synergyDamage: number,
	controlTicks: number,
	crossBattery: number,
	goldInvested: number,
	goldEfficiency: number,
	sharePct: number,
	isMvp: boolean,
}

export type SectorSummary = {
	damage: number,
	leaks: number,
	breachedAtTick: number?,
}

export type SectorComparison = {
	sectorA: SectorSummary,
	sectorB: SectorSummary,
	sharedGateLeaks: number,
}

export type DefeatDiagnosis = {
	breachedLane: number,
	lethalUnit: string,
	countermeasureCode: string,
	leakDamageMilli: number,
	breachedAtTick: number?,
}

export type PostMatchReportData = {
	totalDamageMilli: number,
	totalDamageHp: number,
	totalKills: number,
	mvpTrap: string,
	mvpCell: string,
	traps: { TrapCombatReport },
	sectors: SectorComparison,
	diagnosis: DefeatDiagnosis?,
}

export type RevengeUiSpec = {
	visible: boolean,
	canRevenge: boolean,
	labelKey: string,
	toastKey: string?,
	cooldownHours: number?,
}

local UNIT_TO_DIAG: { [string]: string } = {
	wisp = "diag_aerial_lane",
	drake = "diag_aerial_lane",
	brute = "diag_brute_lane",
	shieldbearer = "diag_brute_lane",
	swarm = "diag_swarm_lane",
	runner = "diag_runner_lane",
	sapper = "diag_runner_lane",
	pyromancer = "diag_pyro_lane",
	iron_ram_colossus = "diag_boss_lane",
	slag_juggernaut = "diag_boss_lane",
	rime_matriarch = "diag_boss_lane",
	powder_baron = "diag_boss_lane",
	rift_titan = "diag_boss_lane",
}

local function minTick(a: number?, b: number?): number?
	if a == nil then
		return b
	end
	if b == nil then
		return a
	end
	return math.min(a, b)
end

function PostMatchReport.countermeasureFor(unitKey: string): string
	return UNIT_TO_DIAG[unitKey] or "diag_runner_lane"
end

function PostMatchReport.fromBattle(battle: any, result: any, trapCatalog: any): PostMatchReportData
	local telemetry = if battle ~= nil and type(battle.CombatTelemetry) == "function"
		then battle:CombatTelemetry()
		else { traps = {}, lanes = {} }

	local rawTraps = if type(telemetry.traps) == "table" then telemetry.traps else {}
	local rawLanes = if type(telemetry.lanes) == "table" then telemetry.lanes else {}

	local totalDamageMilli = 0
	local totalKills = 0
	for _, entry in ipairs(rawTraps) do
		totalDamageMilli += math.max(0, math.floor(tonumber(entry.damageDealt) or 0))
		totalKills += math.max(0, math.floor(tonumber(entry.kills) or 0))
	end

	local reports: { TrapCombatReport } = {}
	for _, entry in ipairs(rawTraps) do
		local trapId = tostring(entry.type or "archer")
		local level = math.max(1, math.floor(tonumber(entry.level) or 1))
		local dmg = math.max(0, math.floor(tonumber(entry.damageDealt) or 0))
		local syn = math.max(0, math.floor(tonumber(entry.synergyDamage) or 0))
		local kills = math.max(0, math.floor(tonumber(entry.kills) or 0))
		local ctrl = math.max(0, math.floor(tonumber(entry.controlTicks) or 0))
		local cross = math.max(0, math.floor(tonumber(entry.crossBattery) or 0))
		local goldInvested = if trapCatalog ~= nil
				and type(trapCatalog.totalGoldInvested) == "function"
			then trapCatalog.totalGoldInvested(trapId, level)
			else 0
		local eff = math.floor(dmg / math.max(1, goldInvested))
		local sharePct = if totalDamageMilli > 0
			then math.clamp(math.floor(dmg * 100 / totalDamageMilli + 0.5), 0, 100)
			else 0

		reports[#reports + 1] = {
			cell = tostring(entry.cell or "r3c3"),
			trapId = trapId,
			level = level,
			x = math.floor(tonumber(entry.x) or 0),
			y = math.floor(tonumber(entry.y) or 0),
			damageDealt = dmg,
			damageHp = math.floor((dmg + 500) / 1000),
			kills = kills,
			synergyDamage = syn,
			controlTicks = ctrl,
			crossBattery = cross,
			goldInvested = goldInvested,
			goldEfficiency = eff,
			sharePct = sharePct,
			isMvp = false,
		}
	end

	table.sort(reports, function(a, b)
		if a.damageDealt ~= b.damageDealt then
			return a.damageDealt > b.damageDealt
		end
		if a.kills ~= b.kills then
			return a.kills > b.kills
		end
		if a.cell ~= b.cell then
			return a.cell < b.cell
		end
		if a.x ~= b.x then
			return a.x < b.x
		end
		return a.y < b.y
	end)

	local mvpTrap = ""
	local mvpCell = ""
	if #reports >= 1 then
		reports[1].isMvp = true
		mvpTrap = reports[1].trapId
		mvpCell = reports[1].cell
	end

	local function laneAt(idx: number): any
		return rawLanes[idx] or { lane = idx, leaks = 0, damageMilli = 0, breachedAtTick = nil }
	end

	local l1, l2, l3, l4, l5 = laneAt(1), laneAt(2), laneAt(3), laneAt(4), laneAt(5)
	local sectors: SectorComparison = {
		sectorA = {
			damage = (l1.damageMilli or 0) + (l2.damageMilli or 0),
			leaks = (l1.leaks or 0) + (l2.leaks or 0),
			breachedAtTick = minTick(l1.breachedAtTick, l2.breachedAtTick),
		},
		sectorB = {
			damage = (l4.damageMilli or 0) + (l5.damageMilli or 0),
			leaks = (l4.leaks or 0) + (l5.leaks or 0),
			breachedAtTick = minTick(l4.breachedAtTick, l5.breachedAtTick),
		},
		sharedGateLeaks = l3.leaks or 0,
	}

	local diagnosis: DefeatDiagnosis? = nil
	local totalLeaked = 0
	for lane = 1, 5 do
		totalLeaked += (laneAt(lane).leaks or 0)
	end
	if (type(result) == "table" and (tonumber(result.leaked) or 0) > 0) or totalLeaked > 0 then
		local bestLane = 0
		local bestDmg = -1
		local bestLeaks = -1
		local bestTick = math.huge
		for lane = 1, 5 do
			local info = laneAt(lane)
			local leaks = tonumber(info.leaks) or 0
			local dmg = tonumber(info.damageMilli) or 0
			local tick = tonumber(info.breachedAtTick) or math.huge
			if leaks > 0 or dmg > 0 then
				local better = false
				if dmg ~= bestDmg then
					better = dmg > bestDmg
				elseif leaks ~= bestLeaks then
					better = leaks > bestLeaks
				elseif tick ~= bestTick then
					better = tick < bestTick
				elseif bestLane == 0 or lane < bestLane then
					better = true
				end
				if better then
					bestLane = lane
					bestDmg = dmg
					bestLeaks = leaks
					bestTick = tick
				end
			end
		end

		if bestLane > 0 then
			local laneInfo = laneAt(bestLane)
			local byMilli = if type(laneInfo.byUnitMilli) == "table"
				then laneInfo.byUnitMilli
				else {}
			local byCount = if type(laneInfo.byUnitCount) == "table"
				then laneInfo.byUnitCount
				else {}
			local lethalUnit = "runner"
			local topUnitDmg = -1
			local topUnitCount = -1
			for unitKey, unitDmg in pairs(byMilli) do
				local uDmg = tonumber(unitDmg) or 0
				local uCnt = tonumber(byCount[unitKey]) or 0
				local pick = false
				if uDmg ~= topUnitDmg then
					pick = uDmg > topUnitDmg
				elseif uCnt ~= topUnitCount then
					pick = uCnt > topUnitCount
				else
					pick = tostring(unitKey) < lethalUnit
				end
				if pick then
					lethalUnit = tostring(unitKey)
					topUnitDmg = uDmg
					topUnitCount = uCnt
				end
			end
			diagnosis = {
				breachedLane = bestLane,
				lethalUnit = lethalUnit,
				countermeasureCode = PostMatchReport.countermeasureFor(lethalUnit),
				leakDamageMilli = math.max(0, math.floor(bestDmg)),
				breachedAtTick = if bestTick < math.huge then bestTick else nil,
			}
		end
	end

	return {
		totalDamageMilli = totalDamageMilli,
		totalDamageHp = math.floor((totalDamageMilli + 500) / 1000),
		totalKills = totalKills,
		mvpTrap = mvpTrap,
		mvpCell = mvpCell,
		traps = reports,
		sectors = sectors,
		diagnosis = diagnosis,
	}
end

function PostMatchReport.resolveRevengeUi(entry: any): RevengeUiSpec
	if type(entry) ~= "table" or entry.role ~= "defense" then
		return {
			visible = false,
			canRevenge = false,
			labelKey = "",
			toastKey = nil,
			cooldownHours = nil,
		}
	end
	if entry.canRevenge == true then
		return {
			visible = true,
			canRevenge = true,
			labelKey = "cta_revenge",
			toastKey = nil,
			cooldownHours = nil,
		}
	end
	local reason = tostring(entry.revengeReason or "")
	if
		reason == "revenge_bot"
		or reason == "bot"
		or reason == "revenge_no_target"
		or reason == "revenge_self"
		or entry.isBot == true
		or entry.rivalHash == "bot"
	then
		return {
			visible = true,
			canRevenge = false,
			labelKey = "ui_log_bot",
			toastKey = "toast_revenge_bot",
			cooldownHours = nil,
		}
	end
	if reason == "revenge_used" or reason == "already_revenged" or entry.revenged == true then
		return {
			visible = true,
			canRevenge = false,
			labelKey = "ui_log_revenged",
			toastKey = "toast_revenge_used",
			cooldownHours = nil,
		}
	end
	local hours = math.max(1, math.ceil((tonumber(entry.cooldownLeftSec) or 3600) / 3600))
	return {
		visible = true,
		canRevenge = false,
		labelKey = "ui_log_cd",
		toastKey = "toast_revenge_cd",
		cooldownHours = hours,
	}
end

return PostMatchReport
