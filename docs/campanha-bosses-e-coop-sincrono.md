# Campanha História, Bosses Multi-Lane e Co-op Síncrono — A MURALHA (`WALLBREAKER`)

> **Versão:** 1.0 · **Alvo de Fase:** P2+ (Campanha/Mutadores/Bosses) & P3 (Co-op Síncrono) · **Status:** Especificação Mestre (P1 congelada em `simVersion = 3`).  
> **Referências:** [`core.luau`](../src/shared/sim/core.luau) · [`literatura-e-universo.md`](literatura-e-universo.md) · [`rfcs-p2-e-fechamento-gaps.md`](rfcs-p2-e-fechamento-gaps.md)

---

## 1. Filosofia Solo + Duo (Assíncrono & Síncrono em Tempo Real)

Todo conteúdo de progressão da campanha **"Crônicas do Bastião"**, desafios com mutadores e chefes é projetado sob a regra **100% Acessível em Três Modalidades**, sem fases exclusivas de grupo e sem bloqueio de recompensa para quem joga sozinho:

| Modalidade | Código de Modo | Como Funciona no Motor | Economia & Progressão |
|---|---|---|---|
| **Solo** | `solo` | Grade `5×5`, `N = 5` armadilhas ativas, `1000 milli` de escala base, controle total das 5 lanes (`r1`–`r5`). | Desbloqueia 100% das 25 fases, Selos 3★ e Pesadelo. |
| **Dupla Assíncrona** | `duo_async` | Jogador acopla a planta de um amigo (*snapshot* salvo no servidor) em metade da grade ou ativa reforço fantasma sem depender de horário comum. | Mesma taxa de estrelas; ideal para janelas curtas mobile. |
| **Dupla Síncrona** | `duo_live` | Sala reservada ao vivo em *lockstep* determinístico (`20 Hz`), `N = 8` armadilhas (`4 + 4`), escalonamento de horda `1750 milli` e comando agendado. | Bônus apenas de sinergia social e *clipes* em dupla; poder máximo idêntico. |

### Matriz de Paridade Técnica entre Modos

| Parâmetro do Motor | Solo (`solo`) | Dupla Assíncrona (`duo_async`) | Dupla Síncrona (`duo_live`) |
|---|---|---|---|
| Armadilhas Ativas (`N`) | `5` (livres em `5×5`) | `5` próprias + `3` fantasma (`8` totais) | `8` (`4` Setor A + `4` Setor B) |
| Escala de Horda (`waveScaleMilli`) | `1000` | `1450` | `1750` (cai para `1000` no *anti-leaver*) |
| Quebra de Postura (`staggerCap`) | `600 milli` | `800 milli` | `1000 milli` |
| Transporte / Replay | Local + validação servidor | Snapshot servidor + `BattleLog` | `CoopCommandRemote` (`tick + 2`) + `BattleLog v2` |

> [!IMPORTANT]
> **Paridade Competitiva:** O núcleo determinístico (`MILLI = 1000`, zero `float` no estado) garante que a vitória dependa de posicionamento na grade `5×5` e economia de onda, nunca de vantagem paga ou obrigação de *party* fixa.

---

## 2. Campanha História: "Crônicas do Bastião" (5 Atos × 5 Estágios = 25 Fases + Pesadelo)

A campanha percorre as cinco regiões do vale ao redor das Cidades-Bastião. Cada Ato possui **4 estágios táticos** de progressão de horda e **1 estágio final de Boss (`X-5`)**, totalizando **25 fases**. Ao concluir o **Ato 5 (`5-5`)**, o jogador desbloqueia o **Modo Pesadelo** para todos os estágios, aplicando mutadores fixos e teto de elite elevado.

### Tabela Mestre dos 5 Atos

| Ato | Região / Tema | Comandante do Ato | ID / Elenco Relacionado | Fases | Boss (`X-5`) | Pressão Dominante da Horda | Marco / Recompensa Principal |
|---|---|---|---|---|---|---|---|
| **Ato 1** | **Cinzas da Fronteira** | **Vorn** | `cmd_vorn` (Liga da Bigorna) | `1-1` a `1-5` | `iron_ram_colossus` | `runner` + primeiros `brute` na lane central | Desbloqueia slot extra de *Blueprint* + Selo Cinzas |
| **Ato 2** | **Forjas de Escória** | **Brasa** | `cmd_brasa` (Oficina da Caldeira) | `2-1` a `2-5` | `slag_juggernaut` | `brute` blindados (`armorMilli`) + pressão contínua | Libera receita/maestria de `tar` & `cannon` |
| **Ato 3** | **Geada do Desfiladeiro** | **Moira** | `cmd_moira` *(Torre Boreal / `cmd_astrid`)* | `3-1` a `3-5` | `rime_matriarch` | `swarm` veloz + resistência a *slow* em sub-ondas | Libera moldura Boreal + maestria de `frost` |
| **Ato 4** | **Pólvora e Trincheira** | **Kael** | `cmd_kael` (Pacto Turquesa) | `4-1` a `4-5` | `powder_baron` | Combos mistos `runner` + `swarm` + quebra de linha | Libera estandarte do Pacto + maestria `catapult` |
| **Ato 5** | **A Fenda Profunda** | **Sombra** | `cmd_sombra` *(Fenda / `cmd_cerbero`)* | `5-1` a `5-5` | `rift_titan` | Todas as classes + elites + dupla pressão de fenda | Desbloqueia **Modo Pesadelo** (25 fases rejogáveis) |

### Cadência Interna dos Estágios (`X-1` a `X-5`)

| Slot do Ato | Papel Tático | Duração Alvo (`20 Hz`) | Composição Típica |
|---|---|---|---|
| `X-1` | Apresentação do bioma e ritmo base | `900`–`1000` ticks (`45–50s`) | `runner` + introdução da mecânica do Ato |
| `X-2` | Teste de contra-unidade | `1000`–`1100` ticks (`50–55s`) | Pico de `brute` ou `swarm` em 2 lanes focais |
| `X-3` | Pressão multi-lane alternada | `1100`–`1200` ticks (`55–60s`) | Spawns cruzados em `r1/r5` e `r2/r4` |
| `X-4` | Ensaio de elite antes do chefe | `1200` ticks (`60s`) | Unidades elite (`<= 85/60s`) + teste de economia |
| `X-5` | Confronto contra o Boss do Ato | `1200` ticks (`60s`) | Boss `laneSpan = 3` + escolta determinística |

### Regras do Modo Pesadelo (`nightmareUnlocked`)

1. **Acesso:** Liberado globalmente após vencer `5-5` no modo Normal (ou por Ato em eventos sazonais com teste em `tools/expansion-test/`).
2. **Modificadores:** Aplica multiplicador inteiro de HP (`1650 milli`), `armorMilli` mínimo de `+150`, e **2 Mutadores determinísticos** pré-definidos por estágio.
3. **Progresso:** Concede um segundo conjunto de selos (**Selos Pesadelo**, `starsMask` separado) e títulos cosméticos para o **Livro de Pedra**.

### Especificação de Dados (`CampaignStageSpec` em Luau `--!strict`)

```lua
--!strict
export type DifficultyMode = "normal" | "nightmare"
export type UnitKind = "runner" | "brute" | "swarm"
export type BossId =
	"iron_ram_colossus"
	| "slag_juggernaut"
	| "rime_matriarch"
	| "powder_baron"
	| "rift_titan"

export type WaveSliceSpec = {
	startTick: number,      -- tick inicial (20 Hz, 0..1200)
	everyTicks: number,     -- intervalo entre spawns
	count: number,          -- total de unidades na fatia
	unit: UnitKind,
	laneMask: number,       -- bitmask 1..31 (r1=1, r2=2, r3=4, r4=8, r5=16)
	isElite: boolean,
}

export type CampaignStageSpec = {
	stageId: string,        -- ex.: "1-1", "3-5"
	act: number,            -- 1..5
	index: number,          -- 1..5 (5 = estagio de Boss)
	commanderId: string,    -- "cmd_vorn" | "cmd_brasa" | "cmd_moira" | "cmd_kael" | "cmd_sombra"
	seedFixed: number,      -- seed deterministica base da fase
	wallMaxHpMilli: number, -- ex.: 100000 (100 * MILLI)
	hpScaleMilli: number,   -- escala de HP (MILLI = 1000)
	armorMilli: number,     -- reducao plana/percentual inteira (0..600)
	speedMilli: number,     -- escala de velocidade <= 2400 milli/s
	bossId: BossId?,        -- preenchido quando index == 5
	mutatorIds: { string }, -- vazio no Normal (exceto eventos); 2 fixos no Pesadelo
	waves: { WaveSliceSpec },
	starThresholds: {
		minWallHpPctFor2Stars: number, -- ex.: 70 (bit 2)
		maxLeaksFor3Stars: number,     -- ex.: 0 (bit 4)
	},
	unlockReq: string?,     -- stageId previo obrigatorio (nil apenas em "1-1")
}

export type CampaignProgressState = {
	highestUnlockedStage: string,              -- ex.: "2-4"
	nightmareUnlocked: boolean,                -- true apos vitoria em "5-5"
	starsNormal: { [string]: number },         -- stageId -> bitmask 0..7
	starsNightmare: { [string]: number },      -- stageId -> bitmask 0..7
	actMilestoneClaims: { [number]: number },  -- act (1..5) -> bitmask (1=5*, 2=10*, 4=15*)
}
```

---

## 3. Escalonamento Matemático (`MILLI = 1000`), Selos 3 Estrelas e 8 Mutadores

Toda aritmética de progressão executa exclusivamente com inteiros (`math.floor`), preservando determinismo entre Luau CLI, servidor Roblox e clientes móveis:

$$\text{unitHp} = \left\lfloor \frac{\text{baseHp} \times \text{hpScaleMilli} \times \text{modeScaleMilli}}{\text{MILLI}^2} \right\rfloor$$

$$\text{effectiveDmg} = \max\left(1, \left\lfloor \frac{\text{rawDmg} \times (\text{MILLI} - \text{armorMilli})}{\text{MILLI}} \right\rfloor\right)$$

$$\text{unitSpeedTick} = \min\left(\text{SPEED\_CAP\_TICK}, \left\lfloor \frac{\text{baseSpeedTick} \times \text{speedScaleMilli}}{\text{MILLI}} \right\rfloor\right)$$

### Tetos Rígidos de Segurança (`Core` v4+)

| Parâmetro | Fórmula / Limite Inteiro | Justificativa Técnica e Mobile |
|---|---|---|
| `MILLI` | `1000` (constante imutável) | Zero `float` no estado; hash reprodutível em qualquer CPU. |
| `armorMilli` | `clamp(armor, 0, 600)` | Máximo de 60% de mitigação; dano mínimo garantido `>= 1` milli. |
| **Teto de Elites** | `<= 85` unidades / `60s` (`1200 ticks`) | Evita saturação de instâncias 3D e queda abaixo de 60 FPS no mobile. |
| **Teto de Velocidade** | `<= 2400 milli/s` (`<= 120 milli/tick` a `20 Hz`) | Mantém leitura visual das 5 lanes e impede salto através de `range` em 1 tick. |

### Selos de 3 Estrelas (`starsMask`) e Marcos por Ato

Cada estágio persiste um inteiro `starsMask` de 3 bits (`0..7`), permitindo conquistar estrelas em tentativas independentes via operação `bit32.bor`:

- **Bit `1` (`0b001` — ★ Vitória):** Portão sobrevive aos `1200` ticks (ou Boss derrotado antes do estouro).
- **Bit `2` (`0b010` — ★★ Muralha Firme):** Vitória com `wallHp >= 70%` do máximo da fase.
- **Bit `4` (`0b100` — ★★★ Engenharia Perfeita):** Vitória com `leaked == 0` (nenhum construto atravessou `X <= 0`).

Os marcos acumulativos de estrelas por Ato (`5 fases × 3★ = 15★` por Ato; `75★` no Normal e `75★` no Pesadelo):

| Marco no Ato | Bit de Claim | Recompensa Determinística | Regra Anti-P2W |
|---|---|---|---|
| **`5★`** | `1` (`0b001`) | Pacote de Ouro de Oficina + Materiais de Upgrade | Acessível mesmo com `1★` por fase em todo o Ato. |
| **`10★`** | `2` (`0b010`) | Fragmento garantido de *Blueprint* / Efeito de Clipe 8s | Premia domínio parcial (`2★` em média por fase). |
| **`15★`** | `4` (`0b100`) | Selo Dourado do Ato + Moldura do Comandante | Puramente prestígio e cosmético; zero stat extra. |

**Exemplo de Cálculo Inteiro (`core.luau`):** Para um `brute` (`baseHp = 45000`) no Ato 2 (`hpScaleMilli = 1350`) em Pesadelo (`modeScaleMilli = 1650`), o HP efetivo é `math.floor(45000 * 1350 * 1650 / 1000000) = 100237` milli. Contra um `cannon` (`10000` milli) e `armorMilli = 300`, o dano líquido é `math.floor(10000 * (1000 - 300) / 1000) = 7000` milli.

### Os 8 Mutadores Determinísticos

| ID | Nome | Regra Inteira Aplicada no `Core` | Contramedida na Grade `5×5` |
|---|---|---|---|
| `mut_iron_hide` | **Casco Blindado** | `+200 armorMilli` em `brute` e Bosses. | Priorizar `cannon` (dano alto por disparo) e janela `VULNERABLE`. |
| `mut_haste_wind` | **Vento da Fenda** | `+180` no `speedMilli` (respeitando teto `<= 2400 milli/s`). | `tar` em `c4`–`c5` e `frost` em `c2` para segurar corredores. |
| `mut_frost_ward` | **Manto Glacial** | `slowTicks` reduzido em `40%` (`math.floor(ticks * 600 / 1000)`). | Trocar excesso de `frost` por dano bruto (`archer`/`catapult`). |
| `mut_swarm_surge` | **Maré de Estilhaços** | `+35%` de contagem em `swarm`, respeitando teto `<= 85` unid./`60s`. | Posicionar `catapult` com splash na lane de maior vazão. |
| `mut_amber_tax` | **Taxa de Veio** | Custos de upgrade/colocação em partida `+150 milli` (`+15%` inteiro). | Focar 3 células fortes antes de preencher as 5 ativas. |
| `mut_cracked_gate` | **Portão Trincado** | `wallMaxHpMilli` começa em `750 milli` (`75%` do normal). | Combater na frente (`c4`–`c5`) e evitar `leak` de `brute`. |
| `mut_volatile_oil` | **Breu Instável** | Projéteis de `cannon` e `catapult` causam `+150 milli` de *stagger*. | Acelerar quebras de postura em fases `X-5` e Pesadelo. |
| `mut_echo_rift` | **Eco Duplo** | A cada 4º spawn de `runner`, gera +1 `swarm` no mesmo `tick` e `lane`. | Garantir cobertura mínima em todas as 5 lanes (`r1`–`r5`). |

---

## 4. Arquitetura Determinística dos 5 Bosses no Core (`SIM_VERSION = 4/5`)

Para suportar chefes sem quebrar a grade `5×5` nem duplicar dano de área, o motor estende o `Core` (`SIM_VERSION = 4` para entidades multi-lane + `5` para eventos de co-op) com quatro garantias determinísticas:

### 4.1 Multi-Lane, `shotId` e Máquina de Estados Inteira

- **Ocupação Multi-Lane:** Cada Boss possui `laneCenter` (`2..4`) e `laneSpan = 3`, ocupando simultaneamente `[laneCenter - 1, laneCenter + 1]`. Armadilhas em qualquer uma dessas 3 linhas acertam o Boss.
- **Deduplicação de AoE por `shotId`:** Todo disparo de área (`catapult` ou habilidade em arco) recebe um inteiro monotônico `shotId`. O Boss mantém `lastHitByShotId[shotId] = true` (ou `lastShotId` por armadilha no tick), garantindo **exatamente 1 aplicação de dano por disparo** mesmo ocupando 3 lanes.
- **Máquina de Estados do Boss (`20 Hz`, ticks inteiros):**

```
MARCH ──(cooldown == 0)──> TELEGRAPH (40 ticks = 2,0s) ──> ABILITY ──> MARCH
  │                              ▲
  └──(staggerMilli >= staggerCap)┴──> VULNERABLE (30 ticks = 1,5s, dano recebido * 1300 / 1000)
  │
  └──(hp * 1000 < maxHp * 400)──> ENRAGE (permanente: speed +200 milli, cdAbility -25%)
```

- **Barra de Postura (`staggerMilli`):**
  - Limiar de quebra: **`600` (Solo)** e **`1000` (Co-op `duo_live`)**, escalados internamente por `MILLI`.
  - Acertos de `cannon`, `catapult` e `frost` somam pontos inteiros de `staggerMilli`. Ao atingir o limiar, o Boss interrompe `MARCH` ou `TELEGRAPH`, entra em `VULNERABLE` por **`30 ticks`** (`+30%` de dano = `1300 / 1000`), e zera `staggerMilli` ao sair do estado.

```lua
--!strict
export type BossFSMState = "MARCH" | "TELEGRAPH" | "ABILITY" | "VULNERABLE"

export type BossRuntimeState = {
	bossId: string,
	hp: number,
	maxHp: number,
	x: number,
	laneCenter: number,             -- 2..4
	laneSpan: number,               -- fixo 3 -> ocupa [laneCenter-1 .. laneCenter+1]
	armorMilli: number,             -- 0..600
	staggerMilli: number,           -- 0..staggerCapMilli
	staggerCapMilli: number,        -- 600 (Solo) | 1000 (Co-op)
	state: BossFSMState,
	stateTicksLeft: number,         -- TELEGRAPH=40, VULNERABLE=30
	abilityCooldownTicks: number,
	enraged: boolean,               -- true quando hp * 1000 < maxHp * 400
	lastHitByShotId: { [number]: boolean }, -- dedup estrito de AoE por shotId
}
```

### 4.2 Ficha Técnica dos 5 Bosses

| Boss ID | Ato | HP Base (`×MILLI`) | `armorMilli` | Velocidade (`milli/s`) | `laneSpan` | Habilidade (`TELEGRAPH 40t` → `ABILITY`) | Gatilho `ENRAGE (<40% HP)` |
|---|---|---|---|---|---|---|---|
| `iron_ram_colossus` | 1 | `420 * 1000` | `150` | `800` (`40/tick`) | `3` | **Aríete de Vigia:** avança `+600` X e aplica `120` ticks de *jam* na célula `c1` da `laneCenter`. | Dobra ganho de avanço no Aríete e reduz recarga de `240t` para `180t`. |
| `slag_juggernaut` | 2 | `680 * 1000` | `300` | `700` (`35/tick`) | `3` | **Banho de Escória:** libera escudo temporário (`+200 armorMilli` por `80t`) e invoca 2 `brute`. | Escória também aquece a lane, reduzindo `slowTicks` pela metade. |
| `rime_matriarch` | 3 | `840 * 1000` | `200` | `960` (`48/tick`) | `3` | **Sopro Boreal:** congela a cadência de 2 armadilhas aleatórias (RNG determinístico) por `60t` (`+50% cd`). | Sopro atinge 3 armadilhas e invoca 4 `swarm` na borda `r1`/`r5`. |
| `powder_baron` | 4 | `1050 * 1000` | `250` | `1040` (`52/tick`) | `3` | **Salva de Barris:** lança barris em `c3`–`c4` empurrando status e atordoando armadilhas por `50t`. | Cada disparo de barragem gera 1 `runner` na lane oposta. |
| `rift_titan` | 5 | `1450 * 1000` | `350` | `900` (`45/tick`) | `3` | **Cisão Turquesa:** alterna `laneCenter` entre `2` e `4` e abre sub-portal em `X = 6500` por `100t`. | Alterna lane a cada `140t` e aplica aura de `+150` velocidade em aliados. |

---

## 5. Co-op Síncrono em Tempo Real (Lobby, Lockstep 20 Hz, Anti-Leaver & Replay 8s)

O modo **`duo_live`** conecta dois jogadores em uma sessão privada de baixa latência mantendo 100% do determinismo do `Livro de Pedra`:

### 5.1 Fluxo de Matchmaking, Reserva e Partida

```mermaid
flowchart LR
    P["Party / SocialService / MemoryStoreQueue"] -->|"Par encontrado (2 Players)"| R["TeleportService:ReserveServer"]
    P -->|"Grava Ticket (squadId, stageId, seed)"| M["MemoryStoreHashMap (TTL 120s)"]
    R -->|"Teleporta Jogador A e B"| S["Servidor Privado: Bastiao Partilhado (20 Hz)"]
    M -->|"Valida Entrada + Anti-Rejoin"| S
    S -->|"Comandos Agendados (tick + 2)"| L["BattleLog v2 (~120-300B) + resultHash"]
    L -->|"Encerramento / Destruicao"| C["Clipe 8s & Livro de Pedra"]
```

### 5.2 Divisão Territorial, `N = 8` e Economia Compartilhada

- **Divisão da Grade `5×5`:**
  - **Setor A (`r1`–`r2`):** propriedade exclusiva de construção/upgrade do **Jogador A** (`4` slots ativos).
  - **Portão (`r3`):** lane central partilhada onde ambos os setores convergem e podem coordenar controle/dano em área (Bosses cruzam `r3` com frequência).
  - **Setor B (`r4`–`r5`):** propriedade exclusiva de construção/upgrade do **Jogador B** (`4` slots ativos).
- **Limite Ativo (`N = 8`):** `4 + 4` armadilhas simultâneas em campo.
- **Economia:** Cada jogador mantém sua própria carteira de ouro (ganho por abates no seu setor e ondas), com botão tático **Enviar `+25 Ouro`** (*cooldown* inteiro de `5s` = `100 ticks`), validado pelo servidor e registrado como comando determinístico.

### 5.3 Rede Lockstep, Presença Efêmera (6 Bytes) e `BattleLog v2`

| Canal / Remote | Tipo | Frequência / Payload | Função e Determinismo |
|---|---|---|---|
| `CoopCommandRemote` | `RemoteEvent` (Confiável) | Sob demanda; `{ playerSlot, cmdType, cellOrTarget, scheduledTick }` | Toda ação (`place`, `upgrade`, `sell`, `send_gold`, `ability`) é validada no servidor e agendada para `scheduledTick = currentTick + 2` (`+100 ms`), garantindo execução idêntica nos dois clientes e no servidor. |
| `BattleLog v2` | Buffer compacto (`~120–300 B`) | `seed`, `simVersion`, `stageId`, lista delta de `{ tick, slot, op, arg }`, `resultHash` | Registra apenas os comandos agendados. Permite reconstruir a partida completa e gerar o **Clipe de 8s** sem gravar vídeo nem posições por frame. |
| `CoopCursorUnreliable` | `UnreliableRemoteEvent` | `10 Hz`; **`buffer` de 6 bytes** (`u8 slotAndFlags`, `u8 cellIdx`, `u16 normX`, `u16 normY`) | Exibe cursor fantasma do parceiro e **4 Pings táticos** (`Defenda aqui`, `Reforçar lane`, `Boss/Perigo`, `Ouro pronto`), com *rate limit* server-side de **4 pings a cada 8s**. |

### Empacotamento Binário (`6 Bytes`) e Pings Táticos

| Byte Offset | Tipo (`buffer`) | Campos / Bitmask | Semântica |
|---|---|---|---|
| `0` | `u8` | `bits 0..1: slot`, `bits 2..4: pingId (0..4)`, `bit 5: isActive` | Identifica remetente + ping (`1=Defenda`, `2=Reforcar`, `3=Perigo`, `4=Ouro`). |
| `1` | `u8` | `cellIndex` (`1..25`, `0` se fora da grade) | Célula `rXcY` sob o cursor do parceiro para destaque visual. |
| `2..3` | `u16` | `normX` (`0..65535`) | Posição horizontal normalizada sobre o diorama. |
| `4..5` | `u16` | `normY` (`0..65535`) | Posição vertical normalizada sobre o diorama. |

```lua
--!strict
export type CoopOp = "place" | "upgrade" | "sell" | "send_gold" | "partner_offline"

export type CoopCommand = {
	tick: number,           -- scheduledTick = currentTick + 2
	slot: number,           -- 1 = Jogador A (r1-r2), 2 = Jogador B (r4-r5)
	op: CoopOp,
	cellOrAmount: number,   -- cellIdx (1..25) ou +25 ouro (cd 100 ticks)
	trapId: string?,        -- preenchido em "place"
}

export type BattleLogV2 = {
	seed: number,
	simVersion: number,     -- 5 para co-op sincrono
	stageId: string,
	commands: { CoopCommand }, -- delta compacto (~120-300 B serializado)
	resultHash: number,
}
```

### 5.4 Protocolo Anti-Leaver em 3 Camadas

Para impedir que quedas de conexão mobile arruínem a partida ou corrompam o `resultHash`:

1. **Camada 1 — Janela de Reconexão (`90s`):** Ao desconectar, o registro `MuralhaRejoin_v1` (`MemoryStoreHashMap`, TTL `90s`) guarda `reservedServerAccessCode` e `battleId`. Se o jogador retornar dentro de `90s`, recebe o `BattleLog v2` acumulado até o tick atual para *fast-forward* determinístico e reassume seu setor.
2. **Camada 2 — Transferência `PARTNER_OFFLINE` (`10s`):** Após `10s` (`200 ticks`) sem *heartbeat* do parceiro, o servidor injeta um comando determinístico `PARTNER_OFFLINE` no `BattleLog v2` (`scheduledTick = currentTick + 2`), transferindo imediatamente as células do setor ausente (`r1–r2` ou `r4–r5`) e o ouro restante para o jogador conectado.
3. **Camada 3 — Re-escalonamento Dinâmico de Ondas:** Caso o parceiro não retorne (ou após a transição de controle), os *spawns* futuros passam de **`1750 milli`** (escala Dupla) para **`1000 milli`** (escala Solo) a partir do próximo `scheduledTick`, preservando o `resultHash` validável no replay e sem punir quem permaneceu na defesa.

---

## 6. Checklist de Invariantes para Implementação Futura (P2/P3)

- [ ] Subir `SIM_VERSION` (`3 -> 4` para campanha/bosses; `4 -> 5` para comandos co-op) e atualizar `docs/versoes.md` + `scripts/check-versions.py`.
- [ ] Garantir zero uso de `float` em `hpScaleMilli`, `armorMilli`, `staggerMilli` e posições `X` (`add32`/`mul32` no RNG).
- [ ] Validar `dedup` por `shotId` em `sim/invariants.luau` para Bosses com `laneSpan = 3`.
- [ ] Testar captura e replay de `BattleLog v2` (`~120–300 B`) com injeção simulada de `PARTNER_OFFLINE` garantindo `hash_a == hash_b`.
