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
| tick fixo de **0,05s** (20 Hz), **1.200 ticks** (60s) | determinismo e orçamento |
| **zero float no estado**: posição/HP/dano em milésimos inteiros, tempo em ticks | evita divergência por arredondamento e FMA entre x86_64 e ARM64 |
| toda multiplicação 32-bit por `mul32`; toda soma 32-bit por `add32` | nunca estourar 2^53 nem passar >2^32 para `bit32` |
| nenhuma chamada a `math.random`, `os.clock`, `tick()`, `workspace` | pureza |
| nenhuma iteração sobre tabela hash dentro do loop | ordem não é garantida |
| arrays paralelos (SoA), sem Instances | memória e velocidade |
| `hash` FNV-1a 32-bit do estado a cada tick | prova de determinismo |

> `bit32` recebe **apenas** inteiros na faixa `[0, 2^32)`. Teste no runtime: `bit32.band(7.2e16)`
> retorna `1473511424` e `bit32.band(1.14e19)` retorna `0` — ou seja, entrada fora de faixa é
> lixo silencioso, não módulo. Ver seção 13.

---

## 3. RNG

xorshift128+ implementado com `bit32`, **sem float e sem soma fora de faixa**:

```lua
local function add32(a, b)
    local s = a + b
    if s >= 4294967296 then s -= 4294967296 end   -- reduz antes de tocar em bit32
    return s
end

local function mul32(a, b)                        -- (a*b) mod 2^32 sem estourar 2^53
    a = band(a, 0xFFFFFFFF); b = band(b, 0xFFFFFFFF)
    local a0, a1 = band(a, 0xFFFF), rshift(a, 16)
    local b0, b1 = band(b, 0xFFFF), rshift(b, 16)
    -- 65536 * 2^16 = 2^32, então só os 16 bits baixos do termo cruzado importam
    local mid = band(a0 * b1 + a1 * b0, 0xFFFF)
    return add32(a0 * b0, mid * 65536)            -- nenhuma etapa passa de 2^32
end

function RNG:nextU32()
    local x, y = self.s0, self.s1
    self.s0 = y
    x = bxor(x, lshift(x, 23))
    x = bxor(x, rshift(x, 17))
    x = bxor(x, y)
    x = bxor(x, rshift(y, 26))
    self.s1 = x
    return add32(self.s0, x)                      -- devolve uint32, nunca double
end

function RNG:int(n)
    return (self:nextU32() % n) + 1               -- inteiro puro, sem [0,1)
end
```

Uma única stream, consumida em ordem fixa. Qualquer novo `nextU32()` muda o resultado — por isso
`simVersion` é obrigatório no replay.

---

## 4. Modelo de estado (SoA)

```
unitType[i]   unitX[i]   unitY[i]   unitHp[i]   unitLane[i]   unitTarget[i]
trapType[t]   trapCell[t] trapCd[t]  trapHp[t]
wallHp        gold         t           tick
```

- unidades: até **300** por batalha;
- lanes: **5 colunas × 5 linhas** no MVP (expansível para 7×5 no nível 5; `gridWidth` no save);
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

### 5.1 "Gravar clipe": a lacuna da Video Captures API que a gente fecha

A `CaptureService` só grava **para frente** (máx. 30s). O pedido mais repetido no DevForum é
"grave os últimos 30 segundos". Como o nosso replay é uma re-simulação do passado, o fluxo fica:

```
1. jogador aperta "GRAVAR CLIPE" no replay de vingança
2. CaptureService:StartVideoCaptureAsync(onReady)   -- começa a gravar a tela
3. pré-roll de ~0,5s (a captura precisa "aquecer"; sem isso o começo se perde)
4. toca a re-simulação de 8s em câmera lenta no ponto de ruptura
5. CaptureService:StopVideoCapture()
6. PromptSaveCapturesToGallery({videoCapture})      -- o jogador decide salvar
```

Cuidados (todos documentados pela Roblox):

| Cuidado | Motivo |
|---|---|
| `StartVideoCaptureAsync` é assíncrono e pode falhar | checar `Enum.VideoCaptureStartedResult` e cair no fallback |
| captura ainda não está em 100% dos usuários | fallback: replay in-game + "copiar ID da batalha" |
| UI e nomes são removidos da captura | o replay não pode depender de HUD para fazer sentido |
| voz não é gravada; parte da música é removida | não desenhar a experiência em cima de áudio licenciado |
| 30s de limite | 8–12s de replay cabem com folga |
| salvar é consentido pelo jogador | nunca publicar automaticamente |

Isso transforma uma limitação da plataforma em feature de marketing: o clipe nasce **do que já
aconteceu**, sem OBS e sem prever o futuro.

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

| Teste | Resultado (motor v2, inteiro) |
|---|---|
| Determinismo (seed 42, 3 execuções) | hash `668061367` idêntico nas três |
| 500 seeds | 500 hashes distintos, 64,8% de vitória do defensor |
| Performance | **1,28 ms por batalha** → 782 batalhas/s |
| Invariantes inteiros | **todo o estado é inteiro** (nenhum fracionário em 100 batalhas) |
| Fuzz (500 batalhas aleatórias) | sem NaN, sem loop infinito |
| Curva de dificuldade | onda 50 → 96% · onda 70 → 64% · onda 90 → 49% |
| Cap de 60s | onda 90 spawna só **78,4** unidades em média (truncada) |

### O que isso prova

1. **Determinismo é barato.** O hash bateu nas três execuções; replay por seed é viável.
2. **O servidor não é o gargalo.** 20 batalhas simultâneas custam ~27 ms/s — 2,7% de um core.
   O gargalo real é render no cliente e design de onda.
3. **O cap de 60s truncou a onda de 90.** Ondas grandes têm que escalar por **força**
   (HP, resistência, velocidade), não por quantidade. Isso já está no GDD.
4. **Balanceamento é calibragem, não opinião.** `powerPct` 380 deixa a curva em 53%/22%/20% e
   460 em 83%/54%/49% — dá para escolher a curva com número, não com achismo.

---

## 13. Auditoria de determinismo (09/11/2026) — corrigido na v2

Auditoria externa apontou dois riscos matemáticos. Reproduzidos no runtime antes de aceitar:

| Verificação | Resultado medido |
|---|---|
| `bit32.band(7,2e16)` | `1473511424` (lixo, não módulo) |
| `bit32.band(1,14e19)` | `0` |
| `band(2^32)` / `band(2^33)` | `0` / `0` |
| FNV com multiplicação em double | **0,34% dos hashes** divergem do valor exato (67 em 20.000) |
| Seed `s * 2654435761` | **99,54% divergem** (9.954 em 10.000) |

**Nuance técnica:** multiplicação IEEE-754 é determinística; o que quebra não é "a CPU fazer
diferente", é (a) perda de bits baixos acima de 2^53, tornando o hash falso, e (b) passar double
> 2^32 para `bit32`, cuja conversão é indefinida — nesse build retorna 0 ou lixo. O terceiro risco
real é **contração FMA** em expressões `x -= speed * dt`, que pode diferir entre o binário do
servidor e o do celular. Todos os três desaparecem com aritmética inteira.

### Correções aplicadas (v2)

1. `mul32` e `add32` em toda operação 32-bit (hash, seed, soma do xorshift).
2. Estado 100% inteiro: HP, dano e posição em milésimos; cooldown e tempo em ticks.
3. RNG devolve `uint32`; `int(n)` usa módulo, não `[0,1)`.
4. Cap único de **1.200 ticks** (60s) — a inconsistência 1.800/1.200 foi eliminada.
5. Slow passou a ser temporal (20 ticks), não multiplicativo permanente — a versão anterior
   congelava a unidade para sempre e inflava a defesa.
6. Teste de invariante: `CheckIntegers()` falha se qualquer valor do estado for fracionário.
7. `mul32` endurecido: a versão anterior passava ~5,6×10^14 para `bit32.band`, fora da faixa
   documentada (regra 3 violada por dentro). A nova forma reduz o termo cruzado a 16 bits antes de
   deslocar: `mid = band(a0*b1 + a1*b0, 0xFFFF); add32(a0*b0, mid*65536)`. Nenhuma etapa passa de 2^32.

### Evidência do ajuste de `mul32`

| Teste | Resultado |
|---|---|
| 4 vetores conhecidos (0xFFFFFFFF², 2^31×2, 1×16777619, seed×42) | idênticos à referência exata |
| 200.000 pares aleatórios vs. referência de limbs de 8 bits | **0 divergências** nas duas versões |
| Hash da seed 42 antes/depois do ajuste | **668061367 em ambos** |

Ou seja: o ajuste **não corrigiu um resultado errado** — corrigiu uma violação da própria regra de
faixa, que poderia divergir em outra arquitetura. É endurecimento, não bugfix. Registrado assim para
não inflar o histórico com um "bug" que não existiu.


