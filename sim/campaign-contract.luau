--!nonstrict
-- Contrato executavel da Campanha ("Cronicas do Bastiao", 5 Atos x 5 Estagios = 25 fases,
-- 5 Bosses Multi-Lane, 8 Mutadores, selos 3 estrelas, marcos por Ato e ProfileSchema v4).
-- Roda no Luau CLI: luau sim/campaign-contract.luau

local bit32 = bit32
local Core = require("../src/shared/sim/core")
local CampaignCatalog = require("../src/shared/campaign/CampaignCatalog")
local ProfileSchema = require("../src/shared/data/ProfileSchema")
local fixtureV3 = require("./fixtures/profile-v3")

local failures = {}
local checks = 0

local function check(name, fn)
	checks += 1
	local ok, err = pcall(fn)
	if not ok then
		failures[#failures + 1] = name .. " :: " .. tostring(err)
	end
end

-- C1: 5 Atos x 5 Estagios = 25 fases, comandantes, bosses em X-5 e 6 tipos de unidades nas ondas
check("C1 25 estagios (1-1 a 5-5), 5 Atos, 5 Bosses em X-5 e 6 tipos de horda", function()
	local ids = CampaignCatalog.allStageIds()
	assert(#ids == 25, "esperava 25 fases, achou " .. tostring(#ids))
	assert(#CampaignCatalog.ACT_NAMES == 5, "ACT_NAMES != 5")

	local expectedBossByAct = {
		[1] = "iron_ram_colossus",
		[2] = "slag_juggernaut",
		[3] = "rime_matriarch",
		[4] = "powder_baron",
		[5] = "rift_titan",
	}
	local unitSeen = {}

	for act = 1, 5 do
		local actStages = CampaignCatalog.getAct(act)
		assert(#actStages == 5, "Ato " .. act .. " nao tem 5 fases")
		for idx = 1, 5 do
			local expectedId = string.format("%d-%d", act, idx)
			local stage = CampaignCatalog.getStage(expectedId)
			assert(stage ~= nil and stage.stageId == expectedId, "fase ausente: " .. expectedId)
			assert(
				stage.act == act and stage.index == idx,
				"act/index incorretos em " .. expectedId
			)
			assert(
				stage.commanderId == CampaignCatalog.ACT_COMMANDERS[act],
				"commanderId incorreto em " .. expectedId
			)
			assert(#stage.nightmareMutators == 2, "nightmareMutators != 2 em " .. expectedId)
			for _, mutId in ipairs(stage.nightmareMutators) do
				assert(Core.MUTATORS[mutId] ~= nil, "mutator invalido: " .. tostring(mutId))
			end
			if idx == 5 then
				assert(
					stage.bossId == expectedBossByAct[act],
					"bossId incorreto em " .. expectedId .. ": " .. tostring(stage.bossId)
				)
				assert(
					CampaignCatalog.BOSS_SPECS[stage.bossId] ~= nil,
					"BOSS_SPECS ausente para " .. tostring(stage.bossId)
				)
			else
				assert(stage.bossId == nil, "fase comum nao deve ter boss: " .. expectedId)
			end
			assert(#stage.waves >= 1, "waves vazio em " .. expectedId)
			for _, w in ipairs(stage.waves) do
				assert(Core.UNIT[w.unit] ~= nil, "unidade desconhecida: " .. tostring(w.unit))
				unitSeen[w.unit] = true
			end
		end
	end

	for _, unitName in ipairs(Core.ALL_UNIT_NAMES) do
		assert(unitSeen[unitName] == true, "unidade nao usada na campanha: " .. unitName)
	end
end)

-- C2: Desbloqueio progressivo (1-1 inicial, sequencia ate 5-5 e liberacao do Modo Pesadelo)
check("C2 progressao de desbloqueio e liberacao do Modo Pesadelo apos 5-5", function()
	local p = ProfileSchema.template()
	assert(CampaignCatalog.isUnlocked(p.campaign, "1-1", "normal") == true, "1-1 bloqueada")
	assert(CampaignCatalog.isUnlocked(p.campaign, "1-2", "normal") == false, "1-2 liberada cedo")
	assert(
		CampaignCatalog.isUnlocked(p.campaign, "1-1", "nightmare") == false,
		"nightmare liberado antes de 5-5"
	)

	p.campaign.starsNormal["1-1"] = 1
	p.campaign.highestUnlockedStage = "1-2"
	assert(CampaignCatalog.isUnlocked(p.campaign, "1-2", "normal") == true, "1-2 nao liberou")
	assert(CampaignCatalog.isUnlocked(p.campaign, "1-3", "normal") == false, "1-3 liberou cedo")

	p.campaign.starsNormal["5-5"] = 7
	p.campaign.highestUnlockedStage = "5-5"
	p.campaign.nightmareUnlocked = true
	assert(
		CampaignCatalog.isUnlocked(p.campaign, "1-1", "nightmare") == true,
		"nightmare 1-1 deveria liberar"
	)
	assert(
		CampaignCatalog.isUnlocked(p.campaign, "5-5", "nightmare") == true,
		"nightmare 5-5 deveria liberar"
	)
end)

-- C3: Avaliacao de Selos 3 Estrelas (bitmask 1=vitoria, 2=wallHp>=70%, 4=leaks==0) e Marcos por Ato
check("C3 selos de 3 estrelas (bitmask 1/2/4) e marcos de Ato (5*, 10*, 15*)", function()
	local stage = assert(CampaignCatalog.getStage("1-1"))

	local m0, s0 =
		CampaignCatalog.evaluateStars(stage, { winner = "attacker", wallPct = 0, leaked = 5 })
	assert(m0 == 0 and s0 == 0, "derrota nao deve dar estrelas")

	local m1, s1 =
		CampaignCatalog.evaluateStars(stage, { winner = "defender", wallPct = 0.50, leaked = 2 })
	assert(m1 == 1 and s1 == 1, "vitoria <70% c/ leak deveria dar mask=1 (1*)")

	local m2, s2 =
		CampaignCatalog.evaluateStars(stage, { winner = "defender", wallPct = 0.75, leaked = 1 })
	assert(m2 == 3 and s2 == 2, "vitoria >=70% c/ leak deveria dar mask=3 (2*)")

	local m3, s3 =
		CampaignCatalog.evaluateStars(stage, { winner = "defender", wallPct = 0.50, leaked = 0 })
	assert(m3 == 5 and s3 == 2, "vitoria <70% s/ leak deveria dar mask=5 (2*)")

	-- Soma cumulativa por bit32.bor: tentativa 1 (mask 3) + tentativa 2 (mask 5) = mask 7 (3*)
	local combined = bit32.bor(m2, m3)
	assert(combined == 7 and CampaignCatalog.starsFromMask(combined) == 3, "bor 3|5 != 7 (3*)")

	local mFull, sFull =
		CampaignCatalog.evaluateStars(stage, { winner = "defender", wallPct = 1.0, leaked = 0 })
	assert(mFull == 7 and sFull == 3, "vitoria perfeita != mask 7 (3*)")

	-- Marcos do Ato: 5* (bit 1, 50g), 10* (bit 2, 90g), 15* (bit 4, 150g)
	local ms = CampaignCatalog.ACT_MILESTONES
	assert(#ms == 3, "ACT_MILESTONES != 3")
	assert(ms[1].threshold == 5 and ms[1].bit == 1 and ms[1].gold == 50, "marco 5*")
	assert(ms[2].threshold == 10 and ms[2].bit == 2 and ms[2].gold == 90, "marco 10*")
	assert(ms[3].threshold == 15 and ms[3].bit == 4 and ms[3].gold == 150, "marco 15*")

	local prog = ProfileSchema.template().campaign
	for i = 1, 5 do
		prog.starsNormal["1-" .. i] = 7
	end
	assert(CampaignCatalog.actStarCount(prog, 1, "normal") == 15, "actStarCount Ato 1 != 15")
end)

-- C4: Calibragem do Ato 1 ("1-1".."1-5" incluindo Boss 1) vencivel com muralha L1/L2 (3..5 traps)
check("C4 calibragem Ato 1 (1-1 a 1-5 + Boss 1) vencivel com muralha L1/L2", function()
	local starterWall = {
		level = 2,
		hp = 650,
		traps = {
			{ cell = "r2c3", type = "archer", level = 2 },
			{ cell = "r3c4", type = "tar", level = 2 },
			{ cell = "r3c3", type = "cannon", level = 2 },
			{ cell = "r4c3", type = "frost", level = 2 },
			{ cell = "r3c2", type = "archer", level = 1 },
		},
	}

	for idx = 1, 5 do
		local stageId = "1-" .. tostring(idx)
		local stage = assert(CampaignCatalog.getStage(stageId))
		local waveSpec = CampaignCatalog.toWaveSpec(stage, "normal")
		local wallCopy = {
			level = starterWall.level,
			hp = math.max(starterWall.hp, math.floor(stage.wallMaxHpMilli / Core.MILLI)),
			traps = starterWall.traps,
		}
		local battle = Core.Battle.new({
			seed = stage.seedFixed,
			simVersion = Core.SIM_VERSION,
			wall = wallCopy,
			wave = waveSpec,
		})
		local res = battle:Run()
		assert(res.winner == "defender", "Ato 1 fase " .. stageId .. " falhou para muralha L1/L2")
		local mask, stars = CampaignCatalog.evaluateStars(stage, res)
		assert(mask >= 1 and stars >= 1, "sem estrelas em " .. stageId)
		if idx == 5 then
			assert(
				res.boss ~= nil and res.boss.alive == false and res.boss.hp == 0,
				"Boss 1 (iron_ram_colossus) nao foi derrotado em 1-5"
			)
		end
	end
end)

-- C5: Calibragem do Ato 5 ("5-1".."5-5" incluindo Boss 5 rift_titan) vencivel com muralha L4/L5
check("C5 calibragem Ato 5 (5-1 a 5-5 + Boss 5) vencivel com muralha L4/L5", function()
	local endgameWall = {
		level = 5,
		hp = 1250,
		traps = {
			{ cell = "r1c3", type = "archer", level = 5 },
			{ cell = "r2c4", type = "frost", level = 5 },
			{ cell = "r2c3", type = "cannon", level = 5 },
			{ cell = "r3c4", type = "tar", level = 5 },
			{ cell = "r3c3", type = "catapult", level = 5 },
			{ cell = "r4c3", type = "cannon", level = 5 },
			{ cell = "r5c3", type = "archer", level = 4 },
		},
	}

	for idx = 1, 5 do
		local stageId = "5-" .. tostring(idx)
		local stage = assert(CampaignCatalog.getStage(stageId))
		local waveSpec = CampaignCatalog.toWaveSpec(stage, "normal")
		local wallCopy = {
			level = endgameWall.level,
			hp = math.max(endgameWall.hp, math.floor(stage.wallMaxHpMilli / Core.MILLI)),
			traps = endgameWall.traps,
		}
		local battle = Core.Battle.new({
			seed = stage.seedFixed,
			simVersion = Core.SIM_VERSION,
			wall = wallCopy,
			wave = waveSpec,
		})
		local res = battle:Run()
		assert(res.winner == "defender", "Ato 5 fase " .. stageId .. " falhou para muralha L4/L5")
		if idx == 5 then
			assert(
				res.boss ~= nil and res.boss.alive == false and res.boss.hp == 0,
				"Boss 5 (rift_titan) nao foi derrotado em 5-5"
			)
		end
	end
end)

-- C6: ProfileSchema v4 JSON safety com chaves string ("1".."5" e "1-1".."5-5") e migracao v3->v4
check("C6 ProfileSchema v4 JSON safety e migracao v3->v4", function()
	local migrated, err = ProfileSchema.migrate(fixtureV3)
	assert(migrated ~= nil, "migracao v3->v4 falhou: " .. tostring(err))
	assert(migrated.schemaVersion == 4, "schemaVersion != 4")
	migrated.campaign.starsNormal["1-1"] = 7
	migrated.campaign.starsNightmare["1-1"] = 3
	migrated.campaign.actMilestoneClaims["1"] = 7
	local valid, validErr = ProfileSchema.validate(migrated)
	assert(valid, "validate v4 falhou: " .. tostring(validErr))
	local jsonOk, jsonErr = ProfileSchema.isJsonSafe(migrated)
	assert(jsonOk, "isJsonSafe v4 falhou: " .. tostring(jsonErr))
end)

print(string.format("contrato de campanha: %d checagens, %d falhas", checks, #failures))
if #failures > 0 then
	for _, f in ipairs(failures) do
		print("  FALHOU: " .. f)
	end
	error("contrato de campanha quebrado")
end
print("OK: contrato de campanha passou")
