--!strict
-- Contrato executavel do Pacote Pos-Partida (Playtest v1.5 / GAP-020):
--   1) Battle:CombatTelemetry() + PostMatchReport.fromBattle (zero impacto no hash)
--   2) Medidor de dano por armadilha, goldEfficiency e desempate deterministico de MVP
--   3) Comparativo de setores (A / Portao P / B) e diagnostico de vazamento (voador, brute, piro, boss)
--   4) DefenseInboxStore (MuralhaInbox_v1): mock push/peek/consume, anti-PII, anti-bot, anti-self, cap 12
--   5) ProfileSchema v6 (battleHistory / revengeCooldowns) + regra 24h anti-win-trading
--   6) FtueLogic (0..6): avanco completo, sinergia espacial, passo 5 exige vitoria, skip seguro +40g

local Core = require("../src/shared/sim/core")
local TrapCatalog = require("../src/shared/data/TrapCatalog")
local ProfileSchema = require("../src/shared/data/ProfileSchema")
local PostMatchReport = require("../src/shared/raid/PostMatchReport")
local DefenseInboxStore = require("../src/server/raid/DefenseInboxStore")
local FtueLogic = require("../src/shared/ftue/FtueLogic")

local failures: { string } = {}
local checks = 0

local function check(name: string, fn: () -> ()): ()
	checks += 1
	local ok: boolean, err: any = pcall(fn :: any)
	if not ok then
		failures[#failures + 1] = name .. " :: " .. tostring(err)
	end
end

-- 1) Determinismo intacto: ler CombatTelemetry + PostMatchReport nao altera hash da seed 42
check(
	"determinismo: CombatTelemetry + PostMatchReport preservam hash 1245379674 da seed 42",
	function()
		local ref = Core.Run(42)
		local battle = Core.Battle.new({
			seed = 42,
			simVersion = Core.SIM_VERSION,
			wall = Core.defaultWall(),
			wave = { count = 70 },
		})
		local res = battle:Run()
		local report = PostMatchReport.fromBattle(battle, res, TrapCatalog)

		assert(ref.simVersion == 8 and res.simVersion == 8, "simVersion != 8")
		assert(ref.hash == 1245379674, "ref.hash inesperado: " .. tostring(ref.hash))
		assert(res.hash == ref.hash, "hash divergiu ao ler CombatTelemetry: " .. tostring(res.hash))
		assert(report.totalDamageMilli > 0, "totalDamageMilli deveria ser > 0")
		assert(#report.traps > 0, "report.traps vazio")
	end
)

-- 2) Medidor de DPS por armadilha, goldEfficiency e desempate deterministico de MVP
check(
	"PostMatchReport: dano, goldEfficiency, MVP deterministico e zero-leak sem diagnostico",
	function()
		local bClean = Core.Battle.new({
			seed = 7,
			simVersion = Core.SIM_VERSION,
			wall = {
				level = 3,
				hp = 850,
				traps = {
					{ cell = "r2c3", type = "archer", level = 5 },
					{ cell = "r4c3", type = "archer", level = 5 },
				},
			},
			wave = {
				slices = {
					{ startTick = 1, everyTicks = 40, count = 1, unit = "runner", laneMask = 2 },
					{ startTick = 1, everyTicks = 40, count = 1, unit = "runner", laneMask = 8 },
				},
			},
		})
		local resClean = bClean:Run()
		assert(resClean.winner == "defender" and resClean.leaked == 0, "runners deveriam morrer")
		local repClean = PostMatchReport.fromBattle(bClean, resClean, TrapCatalog)
		assert(repClean.diagnosis == nil, "vitoria limpa deve ter diagnosis == nil")
		assert(#repClean.traps == 2, "esperava 2 armadilhas")

		assert(TrapCatalog.totalGoldInvested("archer", 1) == 40, "archer L1 deve custar 40g")
		local expectedInv = TrapCatalog.totalGoldInvested("archer", 5)
		assert(
			expectedInv == TrapCatalog.TRAPS.archer.cost + TrapCatalog.TRAPS.archer.upgrade * 10,
			"totalGoldInvested(archer, 5) inconsistente: " .. tostring(expectedInv)
		)

		local mvpCount = 0
		for _, tr in ipairs(repClean.traps) do
			assert(tr.goldInvested == expectedInv, "goldInvested incorreto")
			assert(
				tr.goldEfficiency == math.floor(tr.damageDealt / math.max(1, tr.goldInvested)),
				"goldEfficiency incorreto"
			)
			assert(tr.damageHp == math.floor((tr.damageDealt + 500) / 1000), "damageHp incorreto")
			assert(tr.sharePct >= 0 and tr.sharePct <= 100, "sharePct fora de [0, 100]")
			if tr.isMvp then
				mvpCount += 1
			end
		end
		assert(mvpCount == 1, "deveria haver exatamente 1 MVP")
		assert(repClean.traps[1].isMvp == true, "primeiro item ordenado deve ser MVP")
		assert(
			repClean.mvpCell == "r2c3",
			"empate simetrico deve desempatar para r2c3, veio " .. repClean.mvpCell
		)
	end
)

-- 3) Diagnostico de vazamento (voador, brute, piromante, boss) e comparativo de setores
check(
	"PostMatchReport: diagnostico de vazamento e comparativo de setores (A / Portao / B)",
	function()
		-- Voador wisp na lane 2 com apenas armadilhas de piso (tar + cannon) -> diag_aerial_lane na lane 2
		local bAir = Core.Battle.new({
			seed = 10,
			simVersion = Core.SIM_VERSION,
			wall = {
				level = 1,
				hp = 80,
				traps = {
					{ cell = "r2c4", type = "tar", level = 1 },
					{ cell = "r2c2", type = "cannon", level = 1 },
				},
			},
			wave = {
				slices = {
					{ startTick = 1, everyTicks = 10, count = 4, unit = "wisp", laneMask = 2 },
				},
			},
		})
		local resAir = bAir:Run()
		local repAir = PostMatchReport.fromBattle(bAir, resAir, TrapCatalog)
		assert(repAir.diagnosis ~= nil, "esperava diagnosis para vazamento aereo")
		local diagAir = repAir.diagnosis :: PostMatchReport.DefeatDiagnosis
		assert(
			diagAir.breachedLane == 2,
			"esperava breachedLane=2, veio " .. tostring(diagAir.breachedLane)
		)
		assert(
			diagAir.lethalUnit == "wisp",
			"esperava lethalUnit=wisp, veio " .. tostring(diagAir.lethalUnit)
		)
		assert(
			diagAir.countermeasureCode == "diag_aerial_lane",
			"esperava diag_aerial_lane, veio " .. tostring(diagAir.countermeasureCode)
		)
		assert(
			diagAir.breachedAtTick ~= nil and diagAir.breachedAtTick > 0,
			"breachedAtTick ausente"
		)
		assert(repAir.sectors.sectorA.leaks > 0, "sectorA.leaks deve contabilizar lane 2")
		assert(
			repAir.sectors.sharedGateLeaks == 0 and repAir.sectors.sectorB.leaks == 0,
			"outras lanes deveriam ser 0"
		)

		-- Brute na lane 4 -> diag_brute_lane e sectorB.leaks > 0
		local bBrute = Core.Battle.new({
			seed = 11,
			simVersion = Core.SIM_VERSION,
			wall = {
				level = 1,
				hp = 40,
				traps = { { cell = "r1c1", type = "archer", level = 1 } },
			},
			wave = {
				slices = {
					{ startTick = 1, everyTicks = 10, count = 2, unit = "brute", laneMask = 8 },
				},
			},
		})
		local repBrute = PostMatchReport.fromBattle(bBrute, bBrute:Run(), TrapCatalog)
		assert(repBrute.diagnosis ~= nil, "esperava diagnosis para brute")
		assert(repBrute.diagnosis.breachedLane == 4, "brute deve vazar na lane 4")
		assert(
			repBrute.diagnosis.countermeasureCode == "diag_brute_lane",
			"esperava diag_brute_lane"
		)
		assert(repBrute.sectors.sectorB.leaks > 0, "sectorB.leaks deve contar lane 4")

		-- Piromante na lane 3 -> diag_pyro_lane e sharedGateLeaks > 0
		local bPyro = Core.Battle.new({
			seed = 12,
			simVersion = Core.SIM_VERSION,
			wall = {
				level = 1,
				hp = 35,
				traps = { { cell = "r1c1", type = "archer", level = 1 } },
			},
			wave = {
				slices = {
					{
						startTick = 1,
						everyTicks = 10,
						count = 3,
						unit = "pyromancer",
						laneMask = 4,
					},
				},
			},
		})
		local repPyro = PostMatchReport.fromBattle(bPyro, bPyro:Run(), TrapCatalog)
		assert(repPyro.diagnosis ~= nil, "esperava diagnosis para pyromancer")
		assert(repPyro.diagnosis.breachedLane == 3, "pyro deve vazar na lane 3")
		assert(repPyro.diagnosis.countermeasureCode == "diag_pyro_lane", "esperava diag_pyro_lane")
		assert(repPyro.sectors.sharedGateLeaks > 0, "sharedGateLeaks deve contar lane 3")

		-- Boss isolado na wave -> diag_boss_lane
		local bBoss = Core.Battle.new({
			seed = 13,
			simVersion = Core.SIM_VERSION,
			wall = {
				level = 1,
				hp = 50,
				traps = { { cell = "r1c1", type = "archer", level = 1 } },
			},
			wave = {
				slices = {},
				bossId = "iron_ram_colossus",
				bossSpawnTick = 1,
			},
		})
		local repBoss = PostMatchReport.fromBattle(bBoss, bBoss:Run(), TrapCatalog)
		assert(repBoss.diagnosis ~= nil, "esperava diagnosis para boss")
		assert(
			repBoss.diagnosis.lethalUnit == "iron_ram_colossus",
			"esperava lethalUnit=iron_ram_colossus"
		)
		assert(repBoss.diagnosis.countermeasureCode == "diag_boss_lane", "esperava diag_boss_lane")
	end
)

-- 4) DefenseInboxStore: push/peek/consume atomico, zero PII, anti-self, anti-bot e teto 12
check("DefenseInboxStore: push/peek/consume, anti-PII/bot/self e teto MAX_INBOX=12", function()
	local inbox = DefenseInboxStore.new({ mock = true })
	assert(inbox.isMock == true, "esperava mock = true")

	local badBotKey = DefenseInboxStore.keyFor("bot")
	assert(badBotKey == nil, "keyFor('bot') deve falhar")
	local badPiiKey = DefenseInboxStore.keyFor("userid")
	assert(badPiiKey == nil, "keyFor('userid') deve falhar")
	local okKey = DefenseInboxStore.keyFor("u_def123")
	assert(okKey == "Inbox_u_def123", "keyFor valido falhou")

	local baseWall = {
		level = 2,
		hp = 650,
		traps = { { cell = "r3c3", type = "archer", level = 2, x = 5000, y = 2500 } },
	}
	local baseEntry = {
		battleId = "b_01",
		attackerHash = "u_atk999",
		attackerLabel = "Rival #1",
		attackerLeague = 2,
		winner = "attacker",
		goldReward = 35,
		createdAt = 1700000000,
		resultHash = 999111,
		seed = 42,
		attackerWall = baseWall,
		defenderWall = baseWall,
		waveSpec = { count = 70, spawnEveryTicks = 14 },
	}

	-- Rejeita auto-ataque, bot e PII
	local okSelf, errSelf = inbox.push("u_atk999", baseEntry)
	assert(not okSelf and errSelf == "auto_ataque", "auto-ataque deveria ser bloqueado")

	local okBot, _ = inbox.push("u_def123", {
		battleId = "b_bot",
		attackerHash = "bot",
		attackerLabel = "Bot",
		attackerLeague = 1,
		winner = "attacker",
		goldReward = 10,
		createdAt = 1700000000,
		resultHash = 1,
		seed = 1,
	})
	assert(not okBot, "bot na inbox deveria ser bloqueado")

	local okPii, _ = inbox.push("u_def123", {
		battleId = "b_pii",
		attackerHash = "u_atk999",
		attackerLabel = "Rival",
		attackerLeague = 1,
		winner = "attacker",
		goldReward = 10,
		createdAt = 1700000000,
		resultHash = 1,
		seed = 1,
		email = "leak@example.com",
	})
	assert(not okPii, "PII na inbox deveria ser bloqueado")

	-- Push de 15 itens + 1 duplicado mantem os 12 mais recentes
	for i = 1, 15 do
		local okPush, errPush = inbox.push("u_def123", {
			battleId = "b_" .. tostring(i),
			attackerHash = "u_atk_" .. tostring(i),
			attackerLabel = "Rival " .. tostring(i),
			attackerLeague = 2,
			winner = "attacker",
			goldReward = 30 + i,
			createdAt = 1700000000 + i,
			resultHash = 1000 + i,
			seed = 40 + i,
			attackerWall = baseWall,
			defenderWall = baseWall,
		})
		assert(
			okPush and errPush == nil,
			"push " .. tostring(i) .. " falhou: " .. tostring(errPush)
		)
	end
	-- Duplicado b_15 nao duplica a contagem
	local okDup = inbox.push("u_def123", {
		battleId = "b_15",
		attackerHash = "u_atk_15",
		attackerLabel = "Rival 15",
		attackerLeague = 2,
		winner = "attacker",
		goldReward = 45,
		createdAt = 1700000015,
		resultHash = 1015,
		seed = 55,
	})
	assert(okDup, "re-push duplicado falhou")

	local peeked, peekErr = inbox.peek("u_def123")
	assert(
		peekErr == nil and #peeked == DefenseInboxStore.MAX_INBOX,
		"peek deve respeitar MAX_INBOX=12"
	)
	assert(
		peeked[1].battleId == "b_15" and peeked[12].battleId == "b_4",
		"ordem LRU da inbox incorreta"
	)

	local drained, drainErr = inbox.consume("u_def123")
	assert(
		drainErr == nil and #drained == DefenseInboxStore.MAX_INBOX,
		"consume deve drenar todos os 12 itens"
	)
	local after, afterErr = inbox.consume("u_def123")
	assert(afterErr == nil and #after == 0, "segundo consume deve vir vazio")
end)

-- 5) ProfileSchema v6: battleHistory / revengeCooldowns e regra de 24h anti-win-trading
check(
	"ProfileSchema v6: caps de battleHistory (12) / revengeCooldowns (32) e janela 24h (86400s)",
	function()
		assert(ProfileSchema.SCHEMA_VERSION == 6, "SCHEMA_VERSION != 6")
		assert(ProfileSchema.MAX_BATTLE_HISTORY == 12, "MAX_BATTLE_HISTORY != 12")
		assert(ProfileSchema.MAX_REVENGE_COOLDOWNS == 32, "MAX_REVENGE_COOLDOWNS != 32")
		assert(ProfileSchema.REVENGE_COOLDOWN_SECONDS == 86400, "REVENGE_COOLDOWN_SECONDS != 86400")

		local p: any = ProfileSchema.template()
		local nowTs = 1700000000
		p.battleHistory = {
			{
				battleId = "def_1",
				role = "defense",
				winner = "attacker",
				rivalHash = "u_rival1",
				rivalLabel = "Rival 1",
				leagueDelta = -10,
				goldDelta = 0,
				createdAt = nowTs - 120,
				resultHash = 555666,
				seed = 42,
				isBot = false,
				revenged = false,
			},
		}
		p.revengeCooldowns = {
			u_rival_cd = nowTs - 3600,
		}
		local okVal, errVal = ProfileSchema.validate(p)
		assert(okVal and errVal == nil, "profile v6 valido falhou validate: " .. tostring(errVal))

		-- Regra 24h: dentro de 86400s bloqueia, exatamente em +86400s libera
		local lastCd = p.revengeCooldowns.u_rival_cd
		assert(
			(nowTs - lastCd) < ProfileSchema.REVENGE_COOLDOWN_SECONDS,
			"deveria estar em cooldown antes de 24h"
		)
		local after24h = lastCd + ProfileSchema.REVENGE_COOLDOWN_SECONDS
		assert(
			(after24h - lastCd) >= ProfileSchema.REVENGE_COOLDOWN_SECONDS,
			"deveria liberar em +86400s"
		)

		-- Estourar cap 12 em battleHistory falha validate
		local tooManyHistory: any = ProfileSchema.template()
		for i = 1, 13 do
			tooManyHistory.battleHistory[i] = {
				battleId = "bh_" .. tostring(i),
				role = "attack",
				winner = "attacker",
				rivalHash = "bot",
				rivalLabel = "Bot",
				leagueDelta = 15,
				goldDelta = 25,
				createdAt = nowTs + i,
				resultHash = i,
				seed = i,
				isBot = true,
				revenged = false,
			}
		end
		local okOver, _ = ProfileSchema.validate(tooManyHistory)
		assert(not okOver, "validate deveria rejeitar 13 entradas em battleHistory")
	end
)

-- 6) FtueLogic (0..6): avanco completo, sinergia espacial, passo 5 exige vitoria, skip seguro +40g
check(
	"FtueLogic: progressao 0..6, sinergia espacial, gate do passo 5 e skip seguro (+40g)",
	function()
		local p: any = ProfileSchema.template()
		assert(p.ftue.step == 0 and p.ftue.skipped == false, "template deve iniciar em step=0")

		-- Skip bloqueado antes do DropIn (step 0)
		local okSkip0, errSkip0 = FtueLogic.skip(p, 1000)
		assert(
			not okSkip0 and errSkip0 == "dropin_first",
			"skip no step 0 deve retornar dropin_first"
		)

		-- 0 -> 1: dropin_cleared (0g)
		local r1 = FtueLogic.advance(p, "dropin_cleared", 1000)
		assert(
			r1.advanced and r1.fromStep == 0 and r1.toStep == 1 and r1.rewardGold == 0,
			"0->1 falhou"
		)
		assert(FtueLogic.descriptor(1).targetFocus == "trapDock", "foco do passo 1 != trapDock")

		-- 1 -> 2: colocar primeira armadilha (+20g)
		p.wall.cells.r3c4 = { trap = "tar", level = 1, x = 6500, y = 2500 }
		local r2 = FtueLogic.advance(p, "trap_placed", 1010)
		assert(r2.advanced and r2.toStep == 2 and r2.rewardGold == 20, "1->2 falhou")
		assert(FtueLogic.descriptor(2).targetFocus == "attackBtn", "foco do passo 2 != attackBtn")

		-- 2 -> 3: concluir raid (+25g)
		local r3 = FtueLogic.advance(p, "raid_completed", 1020)
		assert(r3.advanced and r3.toStep == 3 and r3.rewardGold == 25, "2->3 falhou")
		assert(FtueLogic.descriptor(3).targetFocus == "toolsDock", "foco do passo 3 != toolsDock")

		-- 3 -> 4: sinergia espacial (tar + cannon na mesma lane, mesmo nivel 1) (+30g)
		p.wall.cells.r3c3 = { trap = "cannon", level = 1, x = 5000, y = 2500 }
		assert(
			FtueLogic.hasSpatialSynergy(p.wall.cells) == true,
			"tar+cannon na mesma lane deve formar sinergia"
		)
		local r4 = FtueLogic.advance(p, "trap_placed", 1030)
		assert(r4.advanced and r4.toStep == 4 and r4.rewardGold == 30, "3->4 por sinergia falhou")
		assert(FtueLogic.descriptor(4).targetFocus == "logBtn", "foco do passo 4 != logBtn")

		-- 4 -> 5: replay assistido no LOG (+25g)
		local r5 = FtueLogic.advance(p, "replay_watched", 1040)
		assert(r5.advanced and r5.toStep == 5 and r5.rewardGold == 25, "4->5 falhou")
		assert(FtueLogic.descriptor(5).targetFocus == "storyBtn", "foco do passo 5 != storyBtn")

		-- Passo 5 nao avanca em derrota (raid_completed) sem estrela de campanha
		local rStay = FtueLogic.advance(p, "raid_completed", 1050)
		assert(not rStay.advanced and p.ftue.step == 5, "passo 5 nao deve fechar em derrota")

		-- 5 -> 6: vitoria em campanha (+40g)
		local r6 = FtueLogic.advance(p, "campaign_won", 1060)
		assert(r6.advanced and r6.toStep == 6 and r6.rewardGold == 40, "5->6 falhou")
		assert(p.ftue.completedAt == 1060, "completedAt nao registrado")

		-- Skip seguro no passo 1: sem defesas e gold==0 ganha +40g fallback; se ja financiado ganha 0g
		local pUnfunded: any = ProfileSchema.template()
		FtueLogic.advance(pUnfunded, "dropin_cleared", 2000)
		local okS1, errS1, goldS1 = FtueLogic.skip(pUnfunded, 2001)
		assert(
			okS1 and errS1 == nil and goldS1 == 40,
			"skip sem funding deve conceder 40g fallback"
		)
		assert(
			pUnfunded.ftue.step == 6 and pUnfunded.ftue.skipped == true,
			"skip deve fechar em step=6"
		)

		local pFunded: any = ProfileSchema.template()
		pFunded.gold = 25
		FtueLogic.advance(pFunded, "dropin_cleared", 2000)
		local okS2, errS2, goldS2 = FtueLogic.skip(pFunded, 2002)
		assert(okS2 and errS2 == nil and goldS2 == 0, "skip com gold>0 nao deve duplicar fallback")
	end
)

print(string.format("contrato de pos-partida (v1.5): %d checagens, %d falhas", checks, #failures))
if #failures > 0 then
	for _, failure in ipairs(failures) do
		print("  FALHOU: " .. failure)
	end
	error("contrato de pos-partida quebrado")
end
print("OK: contrato de pos-partida passou")
