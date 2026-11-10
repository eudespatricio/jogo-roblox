--!nonstrict
-- Contrato headless da S5: estado do drop-in, funil (props da taxonomia v1) e a batalha fixa
-- que o servidor roda no press (seed 4, muralha pre-montada com catapulta).
-- Roda no Luau CLI: luau sim/dropin-contract.luau
local DropInState = require("../src/shared/dropin/DropInState")
local DropInTelemetry = require("../src/shared/dropin/DropInTelemetry")
local AnalyticsTypes = require("../src/shared/analytics/AnalyticsTypes")
local Core = require("../src/shared/sim/core")

local failures = {}
local checks = 0

local function check(name, fn)
	checks += 1
	local ok, err = pcall(fn)
	if not ok then
		failures[#failures + 1] = name .. " :: " .. tostring(err)
	end
end

local CTX = {
	event_id = "5f0c1e6a-9b2d-4c3f-8a71-2d4e6f8a0b1c",
	ts = 1762800000,
	session_id = "2b6f1d9c-4a3e-4f7b-9c1d-8e5a0f3b6c42",
	player_id = "3f7a9c1e5b2d4f608a1c3e5b7d9f0a2c",
	place_version = "0.1.0-s5",
	platform = "mobile",
	device_tier = "mid",
	locale = "pt-BR",
	is_age_checked = false,
	server_id = "9d1e2f3a4b5c6d7e8f9012345678abcd",
	experiment = "s5_dropin=on",
}

local function prebuiltWall()
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

local function runDropInBattle()
	local battle = Core.Battle.new({
		seed = 4,
		simVersion = Core.SIM_VERSION,
		wall = prebuiltWall(),
		wave = { count = 12, spawnEveryTicks = 8 },
	})
	for _ = 1, 100 do
		battle:Step()
	end
	return battle:Result()
end

check("estado: press no prazo vira salvo e limpa", function()
	local state = DropInState.new(1000)
	local snap = DropInState.snapshot(state, 1000)
	assert(snap.phase == "shown", "fase inicial")
	assert(snap.buttonVisible == false, "botao apareceu antes de 1,5 s")
	assert(snap.canPress == false, "deixou apertar antes do botao")
	assert(DropInState.tick(state, 1000) == false, "tick sem transicao")
	assert(DropInState.snapshot(state, 2500).canPress == true, "botao deveria liberar")

	local early, earlyErr = DropInState.press(state, 1000)
	assert(not early and earlyErr == "too_early", tostring(earlyErr))
	local ok, err = DropInState.press(state, 3000)
	assert(ok, tostring(err))
	assert(state.phase == "salvo", "fase apos press")
	assert(state.pressedAtMs == 3000, "pressedAt")

	local result = runDropInBattle()
	assert(DropInState.setResult(state, result), "setResult")
	assert(DropInState.tick(state, 4000) == false, "limpou antes de 1,5 s")
	assert(DropInState.tick(state, 4500) == true, "nao limpou")
	local finalPhase = state.phase :: string
	assert(finalPhase == "cleared", "fase final")
	assert(state.outcome == "defender", "outcome")
	assert(state.result ~= nil and state.result.winner == "defender", "resultado")
end)

check("estado: timeout em 10 s vira derrota roteirizada", function()
	local state = DropInState.new(0)
	assert(DropInState.tick(state, 9000) == false, "derrotou cedo")
	assert(DropInState.tick(state, 10000) == true, "nao derrotou no deadline")
	assert(state.phase == "defeated", "fase")
	assert(state.outcome == "attacker", "outcome")
	local ok, err = DropInState.press(state, 10001)
	assert(not ok and err == "not_shown", tostring(err))
end)

check("estado: retry reabre a cena", function()
	local state = DropInState.new(0)
	DropInState.tick(state, 10000)
	local ok, err = DropInState.retry(state, 12000)
	assert(ok, tostring(err))
	assert(state.phase == "shown", "fase")
	assert(state.shownAtMs == 12000, "shownAt")
	assert(state.result == nil and state.outcome == nil, "reset")
	assert(DropInState.retry(state, 13000) == false, "retry fora de defeated")
end)

check("estado: botao/pulso e press atrasado", function()
	local state = DropInState.new(0)
	assert(DropInState.snapshot(state, 1499).buttonVisible == false, "botao cedo")
	assert(DropInState.snapshot(state, 1500).buttonVisible == true, "botao nao apareceu")
	assert(DropInState.snapshot(state, 5999).pulse == false, "pulsou cedo")
	assert(DropInState.snapshot(state, 6000).pulse == true, "nao pulsou")
	local ok, err = DropInState.press(state, 10001)
	assert(not ok and err == "too_late", tostring(err))
end)

check("batalha fixa: seed 4, catapulta e defensor", function()
	local hasCatapult = false
	for _, trap in ipairs(prebuiltWall().traps) do
		if trap.type == "catapult" then
			hasCatapult = true
		end
	end
	assert(hasCatapult, "muralha do drop-in sem catapulta")

	local first = runDropInBattle()
	local second = runDropInBattle()
	assert(first.winner == "defender", "winner: " .. tostring(first.winner))
	assert(first.wallHp > 0, "wallHp: " .. tostring(first.wallHp))
	assert(first.killed > 0, "nenhuma unidade morta")
	assert(first.hash == second.hash, "hash instavel")
	assert(first.seed == 4, "seed")
end)

check("funil: props do dropin validam na taxonomia v1", function()
	local shown, shownErr = DropInTelemetry.shownProps(1830)
	assert(shown ~= nil, tostring(shownErr))
	local shownEvent, err = AnalyticsTypes.newEvent(CTX, "dropin_shown", shown)
	assert(shownEvent ~= nil, tostring(err))
	assert(shownEvent.ms_since_join == 1830, "ms shown")

	local pressed, pressedErr = DropInTelemetry.pressedProps(2410, true)
	assert(pressed ~= nil, tostring(pressedErr))
	local pressedEvent = AnalyticsTypes.newEvent(CTX, "dropin_pressed", pressed)
	assert(pressedEvent ~= nil, "evento pressed")
	assert(pressedEvent.pressed == true, "pressed")

	local badMs = DropInTelemetry.shownProps(-1)
	assert(badMs == nil, "aceitou ms negativo")
	local badPressed = DropInTelemetry.pressedProps(10, "sim")
	assert(badPressed == nil, "aceitou pressed string")
end)

check("funil: ordem do funil inclui os dois eventos", function()
	local found = {}
	for _, name in ipairs(AnalyticsTypes.FUNNEL) do
		found[name] = true
	end
	assert(found.dropin_shown == true and found.dropin_pressed == true, "funil sem dropin")
end)

print(string.format("contrato de drop-in (S5): %d checagens, %d falhas", checks, #failures))
if #failures > 0 then
	for _, failure in ipairs(failures) do
		print("  FALHOU: " .. failure)
	end
	error("contrato de drop-in quebrado")
end
print("OK: contrato de drop-in passou")
