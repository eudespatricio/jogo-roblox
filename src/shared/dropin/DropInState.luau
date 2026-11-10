--!strict
-- Estado puro do drop-in da S5: cena de abertura, botao DEFENDER, timeout e retry.
-- Sem API do Roblox: o DropInController passa o relogio de parede do servidor; o contrato
-- sim/dropin-contract.luau prova as fases. A batalha fixa (resultado real) fica no servidor.

local DropInState = {}

-- Tempos do GDD §2: botao entra em 1,5 s; pulsa em 6 s; a horda quebra o portao em 10 s.
DropInState.BUTTON_AT_MS = 1500
DropInState.PULSE_AT_MS = 6000
DropInState.PRESS_DEADLINE_MS = 10000
DropInState.SALVO_MS = 900
DropInState.CLEAR_MS = 1500

DropInState.PHASE_SHOWN = "shown"
DropInState.PHASE_SALVO = "salvo"
DropInState.PHASE_CLEARED = "cleared"
DropInState.PHASE_DEFEATED = "defeated"

DropInState.OUTCOME_DEFENDER = "defender"
DropInState.OUTCOME_ATTACKER = "attacker"

export type Result = {
	winner: string,
	wallHp: number,
	wallPct: number,
	killed: number,
	leaked: number,
	ticks: number,
	seed: number,
	hash: number,
}

export type State = {
	phase: string,
	shownAtMs: number,
	pressedAtMs: number?,
	clearedAtMs: number?,
	outcome: string?,
	result: Result?,
}

export type Snapshot = {
	phase: string,
	elapsedMs: number,
	pressRemainingMs: number,
	buttonVisible: boolean,
	pulse: boolean,
	canPress: boolean,
	outcome: string?,
	result: Result?,
}

local function isValidTime(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function elapsedSince(state: State, nowMs: number): number
	return math.max(0, nowMs - state.shownAtMs)
end

function DropInState.new(nowMs: number): State
	assert(isValidTime(nowMs), "DropInState.new: nowMs invalido")
	return {
		phase = DropInState.PHASE_SHOWN,
		shownAtMs = nowMs,
		pressedAtMs = nil,
		clearedAtMs = nil,
		outcome = nil,
		result = nil,
	}
end

-- Aperta DEFENDER. Antes do botao aparecer ou depois do deadline nao vale.
function DropInState.press(state: State, nowMs: number): (boolean, string?)
	if state.phase ~= DropInState.PHASE_SHOWN then
		return false, "not_shown"
	end
	local elapsed = nowMs - state.shownAtMs
	if elapsed < 0 then
		return false, "bad_time"
	end
	if elapsed < DropInState.BUTTON_AT_MS then
		return false, "too_early"
	end
	if elapsed > DropInState.PRESS_DEADLINE_MS then
		return false, "too_late"
	end
	state.phase = DropInState.PHASE_SALVO
	state.pressedAtMs = nowMs
	state.outcome = DropInState.OUTCOME_DEFENDER
	return true, nil
end

-- Avanca o relogio. Devolve true quando a fase mudou (o servidor loga/atualiza a UI).
function DropInState.tick(state: State, nowMs: number): boolean
	if state.phase == DropInState.PHASE_SHOWN then
		if elapsedSince(state, nowMs) >= DropInState.PRESS_DEADLINE_MS then
			state.phase = DropInState.PHASE_DEFEATED
			state.outcome = DropInState.OUTCOME_ATTACKER
			return true
		end
	elseif state.phase == DropInState.PHASE_SALVO then
		local pressedAt = state.pressedAtMs
		if pressedAt ~= nil and nowMs - pressedAt >= DropInState.CLEAR_MS then
			state.phase = DropInState.PHASE_CLEARED
			state.clearedAtMs = nowMs
			state.outcome = DropInState.OUTCOME_DEFENDER
			return true
		end
	end
	return false
end

-- "Tentar de novo" na tela de derrota: reabre a cena com um novo shownAt.
function DropInState.retry(state: State, nowMs: number): (boolean, string?)
	if state.phase ~= DropInState.PHASE_DEFEATED then
		return false, "not_defeated"
	end
	state.phase = DropInState.PHASE_SHOWN
	state.shownAtMs = nowMs
	state.pressedAtMs = nil
	state.clearedAtMs = nil
	state.outcome = nil
	state.result = nil
	return true, nil
end

-- Resultado da batalha fixa, calculado no servidor no momento do press.
function DropInState.setResult(state: State, result: Result): (boolean, string?)
	if state.phase ~= DropInState.PHASE_SALVO then
		return false, "not_salvo"
	end
	if type(result) ~= "table" or type(result.winner) ~= "string" then
		return false, "bad_result"
	end
	state.result = result
	return true, nil
end

function DropInState.snapshot(state: State, nowMs: number): Snapshot
	local elapsed = elapsedSince(state, nowMs)
	local shown = state.phase == DropInState.PHASE_SHOWN
	local remaining = 0
	if shown then
		remaining = math.max(0, DropInState.PRESS_DEADLINE_MS - elapsed)
	end
	return {
		phase = state.phase,
		elapsedMs = elapsed,
		pressRemainingMs = remaining,
		buttonVisible = shown and elapsed >= DropInState.BUTTON_AT_MS,
		pulse = shown and elapsed >= DropInState.PULSE_AT_MS,
		canPress = shown
			and elapsed >= DropInState.BUTTON_AT_MS
			and elapsed <= DropInState.PRESS_DEADLINE_MS,
		outcome = state.outcome,
		result = state.result,
	}
end

return DropInState
