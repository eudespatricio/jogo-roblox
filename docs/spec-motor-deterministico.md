# Spec técnica — motor determinístico da Muralha

Objetivo: batalha **100% server-authoritative**, replay barato, co-op sem netcode de física e
60 FPS em celular fraco. Este documento é o contrato entre design e código.

---

## 1. Princípio

> O cliente **não simula nada que valha dinheiro**. Ele manda intenções, recebe resultados
> e renderiza uma re-simulação determinística.

Consequências:

- dano, morte, ouro e recompensa só existem no servidor;
- o cliente pode re-simular a batalha porque recebeu a **seed + os dois loadouts**, e o resultado
  é idêntico por construção (mesmo código, mesmo tick, mesmo RNG);
- replay não é vídeo: é seed. Custa bytes, não banda.

---

## 2. Contrato do motor

Módulo puro em `src/shared/sim/`, **sem nenhuma API do Roblox** (roda no Luau CLI nos testes).

```lua
local Battle = require(Shared.sim.Battle)

local battle = Battle.new({
    seed = 123456789,          -- uint32 derivado do battleId
    simVersion = 1,            -- muda quando a matemática muda
    wall = wallSpec,           -- { hp, traps = { {cell, type, level}, ... } }
    wave = waveSpec,           -- { units = { {type, level}, ... }, spawnEvery = 0.7 }
    modifiers = { ... },       -- comandantes, clima, evento
})

while not battle:Finished() do
    battle:Step()              -- 1 tick fixo de 0,05s
end

local result = battle:Result()
-- { winner = "defender"|"attacker", wallHp, ticks, killed, leaked, hash }
```

Regras:

| Regra | Motivo |
|---|---|
| tick fixo de **0,05s** (20 Hz), máx. **1.800 ticks** (90s) | determinismo e orçamento |
| nenhuma chamada a `math.random`, `os.clock`, `tick()`, `workspace` | pureza |
| nenhuma iteração sobre tabela hash dentro do loop | ordem não é garantida |
| arrays paralelos (SoA), sem Instances | memória e velocidade |
| `hash` FNV-1a do estado a cada tick | prova de determinismo |

---

## 3. RNG

xorshift128+ implementado com `bit32` (sem dependência de plataforma):

```lua
function RNG:next() -- retorna [0,1)
    local x, y = self.s0, self.s1
    self.s0 = y
    x = bxor(x, lshift(x, 23))
    x = bxor(x, rshift(x, 17))
    x = bxor(x, y)
    x = bxor(x, rshift(y, 26))
    self.s1 = x
    return band(self.s0 + x, 0xFFFFFFFF) / 4294967296
end
```

Uma única stream, consumida em ordem fixa. Qualquer novo `next()` muda o resultado — por isso
`simVersion` é obrigatório no replay.

---

## 4. Modelo de estado (SoA)

```
unitType[i]   unitX[i]   unitY[i]   unitHp[i]   unitLane[i]   unitTarget[i]
trapType[t]   trapCell[t] trapCd[t]  trapHp[t]
wallHp        gold         t           tick
```

- unidades: até **300** por batalha;
- lanes: 7 colunas × 5 linhas (grid 7×5 = 35 células);
- alvo: busca no mesmo corredor, primeiro à frente dentro do alcance (O(1) por trap);
- colisão: não existe — unidades andam em linha reta por lane (é o que torna barato).

---

## 5. Replay e "Replay de Vingança"

O servidor guarda apenas:

```lua
{ battleId, seed, simVersion, wallSpec, waveSpec, resultHash, createdAt }
```

O cliente re-simula em 20 Hz e renderiza. Para os 8 segundos de vingança:

1. re-simula a batalha inteira em memória (custo ~2–3 ms);
2. guarda snapshots a cada 0,5s;
3. toca os últimos 8s em 4x com câmera no ponto de ruptura;
4. compara `resultHash` com o do servidor; divergência = bug, não trapaça.

**Custo:** ~40 bytes por batalha no DataStore + recomputação local. Nada de vídeo.

---

## 6. Co-op (dupla assíncrona)

Documento da muralha:

```lua
wallDoc = {
    version = 42,
    owners = { userIdA, userIdB },
    cells = { [1] = {trap="cannon", level=2, owner=userIdA}, ... },
    goldPool = 1200,
    contributions = { [userIdA] = 800, [userIdB] = 400 },
}
```

- edição otimista no cliente, confirmação no servidor com **versão** (last-write-wins por célula);
- conflito de célula: vence quem tem versão maior; o outro recebe o estado e um aviso;
- raid em dupla roda **uma** simulação com as duas metades — sem sincronizar física;
- relatório mostra qual lado caiu primeiro (o "culpar o amigo" é dado, não opinião).

Tempo real simultâneo fica fora do MVP: o custo de netcode não se paga antes de validar retenção.

---

## 7. Anti-cheat

| Ameaça | Defesa |
|---|---|
| cliente manda dano/recompensa | servidor ignora; só calcula |
| duplicar recompensa | `battleId` como chave de idempotência no DataStore |
| colocar armadilha sem ouro | validação server-side de ouro, slot, desbloqueio |
| spam de batalha | rate limit: 1 batalha a cada 3s por jogador |
| replay adulterado | `resultHash` comparado; divergência não paga |
| farm de conta | recompensa por cerco limitada a 3/dia + detecção de padrão |

Nenhum valor vindo do cliente é usado em cálculo. Ponto.

---

## 8. Telemetria (desde o primeiro build)

| Evento | Propriedades |
|---|---|
| `session_start` | device, fps inicial, país |
| `dropin_shown` / `dropin_pressed` | ms desde o join |
| `first_win` | segundos desde o join |
| `build_complete` | traps colocadas, tempo |
| `raid_start` / `raid_end` | resultado, duração, velocidade assistida |
| `replay_watched` | duração, % do replay |
| `return_d1` / `return_d7` | via `lastSeenAt` |
| `purchase_start` / `purchase_complete` | produto, preço |
| `age_check_prompt` / `age_check_result` | origem do prompt |

O funil é a bússola: `join → dropin_shown → dropin_pressed → first_win → build_complete → raid_start`.
Se `dropin_pressed` < 60%, o problema é o botão. Se `first_win` < 70%, é a dificuldade.

---

## 9. Orçamento de performance

| Item | Alvo | Limite |
|---|---|---|
| Simulação de batalha (servidor) | ≤ 3 ms | 8 ms |
| Batalhas simultâneas por servidor | 20 em fila | 40 |
| Unidades renderizadas (cliente) | 150 modelos em pool | 200 |
| FPS mobile médio | 60 | 45 |
| Payload de batalha | ≤ 2 KB | 8 KB |

Se estourar: reduzir unidades visíveis (LOD billboard), nunca a lógica.

---

## 10. Testes (headless, no CI)

1. **Determinismo:** 1.000 seeds, 3 execuções cada → hash idêntico.
2. **Balanceamento:** distribuição de vitória entre 30–70% para loadouts equivalentes.
3. **Performance:** 1.000 batalhas em < 5s no Luau CLI.
4. **Fuzz:** placements aleatórios não quebram (sem NaN, sem loop infinito).
5. **Regressão de versão:** `simVersion` antiga não é aceita em reward.

---

## 11. O que foi ajustado do parecer original

| Proposta | Veredito | Ajuste |
|---|---|---|
| Drop-in de 5s | **aceito** | botão único; derrota roteirizada se demorar |
| Co-op de dupla | **aceito, faseado** | assíncrono no MVP+1; tempo real só depois |
| Simulação determinística | **aceito** | mas o ganho não é "60 FPS": é auditoria e replay barato |
| Replay de vingança | **aceito** | re-simulação, não gravação; hash valida |
| "50 linhas" para Invasão Global | **rejeitado** | é um modo com seed, ranking e tela: 1–2 semanas |
| Física real nas engenhocas | **ajustado** | impulsos determinísticos; ragdoll só cosmético no cliente |

---

## 12. Prova de conceito executada (09/11/2026)

Arquivo: [`../sim/poc.luau`](../sim/poc.luau) — Luau puro, roda no CLI, sem Roblox.
Modelo: 5 lanes, 5 armadilhas (uma por lane), 4 tipos de armadilha, 3 tipos de unidade,
tick de 0,05s, cap de 60s, RNG xorshift128+, hash FNV-1a por tick.

| Teste | Resultado |
|---|---|
| Determinismo (seed 42, 3 execuções) | hash `447733464` idêntico nas três |
| 500 seeds | 500 hashes distintos, 57,2% de vitória do defensor |
| Performance | **1,18 ms por batalha** → 851 batalhas/s |
| Fuzz (500 batalhas aleatórias) | sem NaN, sem loop infinito |
| Curva de dificuldade | onda 50 → 98% · onda 70 → 52% · onda 90 → 38% |
| Cap de 60s | onda 90 spawna só **77,5** unidades em média (truncada) |

### O que isso prova

1. **Determinismo é barato.** O hash bateu nas três execuções; replay por seed é viável.
2. **O servidor não é o gargalo.** 20 batalhas simultâneas custam ~24 ms/s — 2,4% de um core.
   O gargalo real é render no cliente e design de onda.
3. **O cap de 60s truncou a onda de 90.** Ondas grandes têm que escalar por **força**
   (HP, resistência, velocidade), não por quantidade. Isso já está no GDD.
4. **Balanceamento é calibragem, não opinião.** A varredura mostrou que `trapPower` 3,0 deixa a
   curva em 50%/16%/11% e 3,8 em 82%/42%/38% — dá para escolher a curva com número, não com achismo.

