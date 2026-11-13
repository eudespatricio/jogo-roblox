# Catálogo de Itens, Unidades e Cosméticos — MURALHA 2.0

> **Status:** documento de referência de catálogo, economia de itens e governança (**P1 em pausa; P2+ bloqueada sem autorização explícita do diretor**).
> Os itens **Ativos (P1)** espelham exatamente [`TrapCatalog.luau`](../src/shared/data/TrapCatalog.luau),
> [`core.luau`](../src/shared/sim/core.luau), [`ProfileSchema.luau`](../src/shared/data/ProfileSchema.luau) e
> [`VisualTheme.luau`](../src/shared/visual/VisualTheme.luau) (`CONTENT_VERSION = 2`, `SIM_VERSION = 3`,
> `SCHEMA_VERSION = 2`). Itens marcados como **Backlog P2/P3** não existem no código e dependem do
> processo de expansão em [`pipeline-expansao.md`](pipeline-expansao.md).

---

## 1. Governança, Versionamento e Regras de Monetização

Todo item do jogo pertence a uma de duas classes de contrato: **Combate/Economia** (afeta perfil persistido e/ou simulação determinística) ou **Cosmético** (afeta apenas apresentação local e posse em `profile.cosmetics`).

### 1.1 Matriz de Impacto e Gates de Expansão

| Regra / Gate | Combate & Economia | Cosméticos | Referência no Código / Docs |
|---|---|---|---|
| **Versão de Conteúdo** | `TrapCatalog.CONTENT_VERSION++` obrigatório | `CONTENT_VERSION++` apenas (sem impacto no `Core`) | [`TrapCatalog.luau`](../src/shared/data/TrapCatalog.luau) |
| **Versão do Motor** | `Core.SIM_VERSION++` + re-ancoragem de `hash` / `acceptance.luau` | **Zero impacto** no `Core.SIM_VERSION` e no `result_hash` | [`core.luau`](../src/shared/sim/core.luau) |
| **Renome / Remoção** | Nunca apagar `id` em uso; mapear em `TRAP_ALIASES` + migração neutra | Deprecar oferta na loja mantendo posse no perfil | `TrapCatalog.ensureProfileContent` |
| **Falha de Versão Futura** | Fail-closed (`content_future`) no boot e no `BattleLog.isReplayable` | Ignora IDs desconhecidos na renderização sem travar replay | [`ProfileSchema.luau`](../src/shared/data/ProfileSchema.luau) |
| **Trial Obrigatório** | Executar `tools/expansion-test/` (branch + patch + relatório) | Validar teto `MAX_COSMETICS = 200` e `MAX_ID_LENGTH = 48` | [`pipeline-expansao.md`](pipeline-expansao.md) |
| **Validação de Schema** | `WallService.validateWall` + `ProfileSchema.validate` | `cosmetics[id] = true` (booleano, JSON-safe, sem PII) | [`ProfileSchema.luau`](../src/shared/data/ProfileSchema.luau) |
| **Formato de IDs** | `snake_case` ASCII, `1..48` chars (`^[%w_%.%-]+$`) | `snake_case` ASCII, `1..48` chars (`^[%w_%.%-]+$`) | `ProfileSchema.isIdString` |

### 1.2 Fluxo Obrigatório para Novo Item de Combate vs. Cosmético

1. **Item de Combate (Armadilha, Estrutura ou Modificador no `Core`):**
   - Definir matemática 100% inteira (`MILLI = 1000`, `add32`/`mul32`, zero `float` no estado);
   - Atualizar `Core.TRAP` / `Core.TRAP_NAMES` (ou `Core.UNIT`) e `TrapCatalog.TRAPS` / `TrapCatalog.TRAP_IDS`;
   - Se houver renomeação de `trap_id`, registrar o mapeamento em `TrapCatalog.TRAP_ALIASES` garantindo migração neutra sem perda de célula ou nível;
   - Subir `TrapCatalog.CONTENT_VERSION` e `Core.SIM_VERSION`, atualizar [`spec-motor-deterministico.md`](spec-motor-deterministico.md), [`economia-muralha.md`](economia-muralha.md) e [`versoes.md`](versoes.md);
   - Rodar `tools/expansion-test/` e todos os contratos (`check.sh`, `invariants.luau`, `acceptance.luau`, `walls-contract.luau`, `content-contract.luau`).
2. **Item Cosmético (Temas, Skins, VFX, Banners, Títulos, Molduras):**
   - Cadastrar ID canônico (`<= 48` chars) no catálogo de loja/inventário;
   - Subir apenas `CONTENT_VERSION` (zero alteração em `Core`, `SIM_VERSION`, `result_hash` ou `acceptance.luau`);
   - Validar teto `ProfileSchema.MAX_COSMETICS = 200` e fallback visual quando um cliente receber ID não reconhecido.

### 1.3 Políticas Invioláveis de Monetização e Preço Regional

1. **Zero Pay-to-Win (P2W):** nenhum Robux compra dano, HP de muralha, redução de cooldown, ouro (`GOLD_SOURCES = { raid, defense, daily }`) ou unidades de combate.
2. **Zero Loot Boxes / Paid Random Items:** proibida qualquer recompensa aleatória paga com Robux ou moeda comprável com Robux; odds ocultas e timers de ansiedade são vetados ([`gdd-muralha.md`](gdd-muralha.md) §6).
3. **Zero Robux → Ouro:** ouro é ganho exclusivamente jogando (`raid`, `defense`, `daily`) e gasto exclusivamente em `trap` e `upgrade` (`GOLD_SINKS`). Remover armadilha reposiciona o layout sem devolução de ouro.
4. **Preços Dinâmicos na UI (GAP-013):** todo preço em Robux exibido ao jogador **DEVE** ser consultado dinamicamente em runtime via `MarketplaceService:GetProductInfo()` (ou Dynamic Price Check). Sob o **Managed Regional Pricing** da Roblox (desconto automático entre **30% e 100%** do preço-base, piso de 30%), **nunca** faça hardcode de valores `R$` na interface; os valores em `R$` deste documento são apenas âncoras-base para o Creator Dashboard ([`pesquisa-monetizacao-regional.md`](pesquisa-monetizacao-regional.md) §2.5).

---

## 2. Catálogo A — Armadilhas Ativas na P1 (`Core.TRAP` / `TrapCatalog`)

Parâmetros globais do motor determinístico vigente em [`core.luau`](../src/shared/sim/core.luau) e [`TrapCatalog.luau`](../src/shared/data/TrapCatalog.luau):

- **Versões vigentes:** `CONTENT_VERSION = 2` | `SIM_VERSION = 3` | `SCHEMA_VERSION = 2`.
- **Escala e tempo:** `MILLI = 1000`, `TICK_HZ = 20` (1 tick = `0.05 s`), `MAX_TICKS = 1200` (`60 s`), `DEFAULT_POWER_PCT = 460`.
- **Grade e posicionamento:** 5×5 (`r1c1`..`r5c5`), `ACTIVE_TRAP_LIMIT = 5`, colunas `c1..c5` em `x = { 2000, 3500, 5000, 6500, 8000 }` (muralha em `x = 0`, spawn em `x = 10000`).
- **Fórmula de dano efetivo:** `floor(dmg_raw * 460 * (100 + 20 * (level - 1)) / 10000)`.
- **Fórmula de custo de upgrade:** `upgrade_base * level_atual` (`TrapCatalog.MAX_LEVEL = 3` na P1; `ProfileSchema.MAX_TRAP_LEVEL = 5` e `Core` já suportam projeção até Nv. 5 para P2+).

### 2.1 Tabela Principal — Custos, Desbloqueio e Atributos de Combate (P1)

| ID (`trap_id`) | Liga (`POINTS_PER_LEAGUE = 100`) | Custo Base | Upgrade Base | Nível 2 | Nível 3 | Total Nv. 3 | Proj. Nv. 4 / Nv. 5 | Dano Bruto (`MILLI`) | Dano Efetivo Nv. 1 | Cooldown | Alcance (`MILLI`) | Efeito / Alvo |
|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---|
| `archer` | 1 (`0` pts) | 40 | 30 | 30 | 60 | 130 | 90 / 120 | 4000 | 18400 | `10t` (`0.5s`) | 3000 | Alvo único mais à frente na lane |
| `tar` | 2 (`100` pts) | 60 | 45 | 45 | 90 | 195 | 135 / 180 | 6000 | 27600 | `18t` (`0.9s`) | 1600 | Alias de `oil`; dano pesado de curto alcance na lane |
| `frost` | 3 (`200` pts) | 90 | 65 | 65 | 130 | 285 | 195 / 260 | 2000 | 9200 | `14t` (`0.7s`) | 2600 | Reduz velocidade para `55%` por `20` ticks (`1.0s`) |
| `cannon` | 4 (`300` pts) | 140 | 100 | 100 | 200 | 440 | 300 / 400 | 10000 | 46000 | `28t` (`1.4s`) | 2200 | Quebra-tanque pesado de alvo único |
| `catapult` | 5 (`400` pts) | 180 | 130 | 130 | 260 | 570 | 390 / 520 | 9000 | 41400 | `40t` (`2.0s`) | 3000 | Dano em área (`splash = true`) em toda a lane no alcance |

> **Nota de migração (`oil` → `tar`):** `TrapCatalog.TRAP_ALIASES = { oil = "tar" }` converte automaticamente perfis `contentVersion = 1` em `ensureProfileContent`, preservando célula e nível sem perda de ouro ou progresso.

### 2.2 Escala de Dano Efetivo por Nível (`powerPct = 460`)

| ID | Nv. 1 (`100%`) | Nv. 2 (`120%`) | Nv. 3 (`140%` — Cap P1) | Proj. Nv. 4 (`160%`) | Proj. Nv. 5 (`180%`) |
|---|---:|---:|---:|---:|---:|
| `archer` | 18400 | 22080 | 25760 | 29440 | 33120 |
| `tar` | 27600 | 33120 | 38640 | 44160 | 49680 |
| `frost` | 9200 | 11040 | 12880 | 14720 | 16560 |
| `cannon` | 46000 | 55200 | 64400 | 73600 | 82800 |
| `catapult` | 41400 | 49680 | 57960 | 66240 | 74520 |

### 2.3 Papel Tático, Counterplay e Orçamento 3D (P1)

Orçamento estrito por modelo de armadilha em [`VisualTheme.luau`](../src/shared/visual/VisualTheme.luau) e [`ferramentas.md`](ferramentas.md): **≤ 11 partes** no kit, **≤ 1.500 triângulos**, **textura ≤ 512×512**, pivô na base (`Z=0`) e **≤ 3 emitters / ≤ 150 partículas**.

| ID | Papel Tático na Grade 5×5 | Fraqueza / Counterplay | Peças (`VisualTheme`) | Orçamento 3D / Textura |
|---|---|---|---|---|
| `archer` | Sustentação barata de DPS contínuo; cobre até 2 colunas à frente (`3000`). | Satura contra grupos `swarm` e demora contra `brute`. | `9` partes (`altura 5.2`) | ≤ 11 partes · ≤ 1.500 tris · ≤ 512×512 |
| `tar` | Âncora de curto alcance (`1600`) em `c1`/`c2` para punir quem passa do meio. | Alcance curto: desperdiça cooldown se posicionada em `c5` isolada. | `5` partes (`altura 1.2`) | ≤ 11 partes · ≤ 1.500 tris · ≤ 512×512 |
| `frost` | Multiplicador de tempo de morte; dobra o valor de `tar`/`cannon` na lane. | Dano próprio baixo (`9200` efetivo); ineficiente sem DPS de apoio. | `7` partes (`altura 4.4`) | ≤ 11 partes · ≤ 1.500 tris · ≤ 512×512 |
| `cannon` | Executor de alvos de alto HP (`brute`), limpando ameaças antes do portão. | Cooldown longo (`28t`): perde eficiência extrema contra enxames rápidos. | `8` partes (`altura 3.2`) | ≤ 11 partes · ≤ 1.500 tris · ≤ 512×512 |
| `catapult` | Controle de onda densa em lane única; resolve gargalos de múltiplos `swarm`. | Cadência lenta (`40t`) e custo alto (`180` ouro); exige proteção frontal. | `11` partes (`altura 4.8`) | ≤ 11 partes · ≤ 1.500 tris · ≤ 512×512 |

### 2.4 Alcance Geométrico na Grade 5×5 (`COLUMN_X`)

No motor [`core.luau`](../src/shared/sim/core.luau), cada armadilha ataca apenas unidades na **mesma lane (`row`)** com deslocamento positivo à frente (`0 < unit.x - trap.x <= range`). Como `COLUMN_X = { 2000, 3500, 5000, 6500, 8000 }` (espaçamento de `1500` milli por coluna):

| Coluna | Posição `X` (`MILLI`) | Proximidade | Armadilhas Recomendadas pela Geometria |
|---|---:|---|---|
| `c1` | `2000` | Junto ao portão (`x = 0`) | `tar` (`1600`, cobre até `x=3600` / `c2`) e `cannon` (`2200`, cobre até `x=4200`) |
| `c2` | `3500` | Retaguarda interna | `cannon` (`2200`, até `x=5700` / além de `c3`) e `frost` (`2600`, até `x=6100`) |
| `c3` | `5000` | Centro padrão (`defaultWall`) | `archer` e `catapult` (`3000`, cobrem até `x=8000` / `c5`); `frost` (`2600`) |
| `c4` | `6500` | Vanguarda avançada | `frost` (`2600`, cobre até `x=9100`) para retardar logo após o spawn |
| `c5` | `8000` | Boca do spawn (`x = 10000`) | `archer` / `catapult` (`3000`, cobrem até `x=11000`, pegando desde o spawn) |

---

## 3. Catálogo B — Backlog Horizontal P2/P3 (Não Implementado na P1)

As 7 armadilhas e estruturas abaixo formam o backlog de **expansão horizontal** para **P2/P3** (novas decisões espaciais e sinergias sem power creep linear sobre o quinteto da P1). **Nenhuma delas está ativa em `Core.TRAP` ou `TrapCatalog.TRAPS` hoje.** Toda adição exige matemática inteira em `MILLI`, `CONTENT_VERSION++`, `SIM_VERSION++` e trial em `tools/expansion-test/`.

### 3.1 Tabela de Especificação Inteira (Backlog P2/P3)

| ID Proposto | Categoria | Liga | Custo (Ouro) | Dano (`MILLI`) | Cooldown (`ticks`) | Alcance (`MILLI`) | Mecânica Inteira & Tradeoff |
|---|---|---:|---:|---:|---:|---:|---|
| `ballista` | Armadilha Linear | 5 | 160 | 11000 | `34t` (`1.7s`) | 4500 | Perfura até **2 alvos** na lane em linha reta. **Forte vs `brute`** em fila; **fraca vs `swarm`** disperso pela cadência lenta. |
| `dynamo` | Armadilha Arco | 4 | 120 | 3000 | `12t` (`0.6s`) | 2000 | Encadeia raio em até **3 alvos** na mesma lane. **Forte vs `swarm`** agrupado; **fraca vs `brute`** pelo baixo dano unitário. |
| `cauldron` | Zona de Chão | 3 | 80 | 1500/tick (10 ticks) | `24t` (`1.2s`) | 1200 | Cria zona de dano contínuo por `10t` (`15000` bruto teórico se permanecer). **Forte em `c1`/`c2` + `frost`**; **fraca em `c5`** onde inimigos cruzam rápido. |
| `spring_ram` | Controle Físico | 4 | 110 | 2500 | `36t` (`1.8s`) | 1500 | Aplica knockback determinístico de **`+1500` milli em `X`** (afasta do portão). **Trava anti-loop: máx. `2×` por unidade** para impedir stall infinito em `1200` ticks. |
| `war_drum` | Estrutura de Suporte | 3 | 100 | 0 | Passivo | Adjac. ortogonal | Reduz `cd_ticks` em **`-15%`** (piso rígido de **`4t`**) das armadilhas ortogonalmente adjacentes (`N/S/L/O`). **Consome 1 slot de `N` ativas** e causa 0 de dano direto. |
| `barricade` | Estrutura de Contenção | 2 | 50 | 0 | Contínuo | Célula local | Bloqueio físico com **HP local de `35000` milli**; detém o avanço da lane na célula até ser destruída pelos atacantes. |
| `decoy_bell` | Estrutura Espacial | 5 | 130 | 0 | `80t` (`4.0s`) | Mesma faixa `X` | **1 uso/batalha:** puxa até **3 unidades** de `\|uLane - row\| == 1` dentro de `\|uX - trap.x\| <= 2500` para `uLane = row` (mantém `uX`). |

#### Regras Determinísticas Exatas do Backlog P2/P3 (Desempate & Limites `MILLI`)

Para eliminar qualquer ambiguidade na implementação futura em `Core.Battle`:
- **`ballista`:** ordena alvos válidos na lane (`0 < uX - trap.x <= 4500`) por menor `uX` (desempate por menor índice `i`); aplica `100%` (`11000` milli) no 1º alvo e `75%` (`math.floor(11000 * 750 / 1000) = 8250` milli) no 2º alvo.
- **`dynamo`:** atinge o alvo primário mais próximo (`uX` menor, `100%` = `3000` milli) e encadeia até 2 saltos com distância de Manhattan `\|uX_a - uX_b\| + \|uLane_a - uLane_b\| * 1500 <= 2500`, com decaimento `100% -> 70% -> 50%` (`3000 -> 2100 -> 1500` milli, desempate menor `uX` depois menor `i`, sem repetir alvo no mesmo disparo).
- **`cauldron`:** cria zona centrada em `COLUMN_X[col]` (`raio = 1200` milli, duração `10t`, dano `1500` milli/tick). Zonas sobrepostas na mesma lane **não acumulam** dano (reinicia apenas duração da unidade na faixa).
- **`spring_ram`:** empurra até 3 alvos mais próximos no alcance (`1500` milli) para `math.min(SPAWN_X, uX + 1800)` e aplica imunidade `uPushImmuneUntil[i] = tick + 20` (além da trava máx. `2×/unidade`), impedindo *stunlock*.
- **`war_drum`:** reduz `cd` base das armadilhas ortogonalmente adjacentes (`\|dr\| + \|dc\| == 1`) para `math.max(4, math.floor(cd * 850 / 1000))`; efeito **não cumulativo** entre múltiplos tambores adjacentes.
- **`barricade`:** entra na célula com `barricadeHp = 35000`. Unidades na mesma lane com `\|uX - trap.x\| <= 400` pausam o deslocamento (`speed = 0`) enquanto `barricadeHp > 0` e causam dano por tick proporcional ao `leak` (`runner 300/t`, `brute 800/t`, `swarm 100/t` milli) até destruir o bloqueio.
- **`decoy_bell`:** dispara uma vez ao detectar `>= 2` unidades em lanes adjacentes (`\|uLane - row\| == 1`) dentro de `\|uX - trap.x\| <= 2500`; puxa até 3 alvos (menor `uX`, depois menor `i`) definindo `uLane[i] = row` sem alterar `uX`.

### 3.2 Sinergias e Riscos de Design a Validar no Trial (`tools/expansion-test/`)

- **Combo `frost` + `cauldron` / `tar`:** validar que a redução de velocidade (`55%`) não torne a combinação `c1`/`c2` estritamente dominante sobre layouts de `cannon`/`ballista`.
- **Trava do `spring_ram` (`max 2x/unit`):** garante que o knockback (`+1500` milli) jamais prenda um `brute` em loop infinito contra `MAX_TICKS = 1200`, preservando o orçamento determinístico da batalha.
- **Custo de oportunidade de `war_drum` e `barricade`:** como `ACTIVE_TRAP_LIMIT = 5` no MVP (expandindo apenas na P2), estruturas sem dano direto competem diretamente por slots de `N` ativas.

---

## 4. Catálogo C — Unidades da Horda (`Core.UNIT` & Expansão P2)

### 4.1 Unidades Ativas na P1 (`Core.UNIT`)

Todas as unidades nascem em `x = 10000` (`MILLI`), em lane aleatória `1..5` determinada pela seed `uint32`, com variação de HP de **`91%` a `111%`** (`90 + rng:int(21)` em `Battle:spawnUnit()`).

| ID (`unit_id`) | Status | HP Base (`MILLI`) | Variação de Spawn | Velocidade (`MILLI`/tick) | Dano de Vazamento (`leak`) | Peças (`VisualTheme`) | Papel na Onda |
|---|---|---:|---|---:|---:|---:|---|
| `runner` | **P1 Ativo** | 14000 | 91%–111% | 150 (`3.0 u/s`) | 8000 (`8` HP muralha) | `6` partes (`escala 0.85`) | Pressão padrão equilibrada; pune lanes descobertas |
| `brute` | **P1 Ativo** | 45000 | 91%–111% | 75 (`1.5 u/s`) | 25000 (`25` HP muralha) | `8` partes (`escala 1.35`) | Esponja de dano; exige `cannon`/`tar` ou desaceleração |
| `swarm` | **P1 Ativo** | 7000 | 91%–111% | 210 (`4.2 u/s`) | 3000 (`3` HP muralha) | `5` partes (`escala 0.65`) | Velocista de baixo HP; satura armadilhas de alvo único |

Parâmetros padrão de onda na P1 (`Core.Battle.new`): `wall.hp = 500` (`500000` milli), `spawnEveryTicks = 14` (`0.7 s` entre spawns), `wave.count = 70` unidades e teto `MAX_TICKS = 1200` (`60 s`). Sob slow de `frost`, a velocidade cai de `speed` para `floor(speed * 55 / 100)` (`runner → 82`, `brute → 41`, `swarm → 115` milli/tick).

#### Tempo de Travessia e Resposta de Armadilhas (P1)

| Unidade | Sem Slow (`ticks` de `x=10000` a `x=0`) | Com `frost` Contínuo (`55%`) | Armadilhas Mais Eficientes (P1) | Armadilhas Menos Eficientes (P1) |
|---|---:|---:|---|---|
| `runner` (`150` / tick) | `67t` (`3.35s`) | `122t` (`6.10s`) | `archer`, `tar` | `catapult` isolada |
| `brute` (`75` / tick) | `134t` (`6.70s`) | `244t` (`12.20s`) | `cannon` + `frost`, `tar` | `archer` sozinha |
| `swarm` (`210` / tick) | `48t` (`2.40s`) | `87t` (`4.35s`) | `catapult`, `frost` + `tar` | `cannon` (`28t` cd) |

### 4.2 Expansão P2 — "Montar Onda" (Backlog, Cap ≤ 85 Unidades)

Na P2, o atacante personaliza a composição de onda dentro do **orçamento máximo de `≤ 85` unidades por batalha** (regra de teto de `60 s` em [`gdd-muralha.md`](gdd-muralha.md) §5). Novas unidades escalam em papel tático, nunca por contagem acima do cap:

| ID Proposto | Status | Atributos / Papel | Regra Determinística Prevista (`MILLI`) |
|---|---|---|---|
| `shieldbearer` | Backlog P2 | Tanque anti-burst | Nasce com `uShieldActive = true`: **zera integralmente (`dmg = 0`)** o **1º golpe efetivo `> 20000` milli** e consome o escudo; golpes `<= 20000` entram normalmente sem quebrar o escudo. |
| `sapper` | Backlog P2 | Sabotador rápido (`spd = 190`) | **1× por unidade:** ao entrar em `\|uX - trap.x\| <= 500` na sua lane, escolhe a armadilha ativa de menor `col` (mais próxima do portão) e define `trap.disabledUntil = tick + 15`. |
| `siege_ram` | Backlog P2 | Aríete pesado (`HP = 70000`, `spd = 55`) | Imunidade parcial a controle: aplica metade da redução de velocidade (ex.: slow `55%` vira `77%` via `100 - math.floor((100 - slowPct) / 2)`). |
| `rift_herald` | Backlog P2 | Suporte de horda | Concede `+20%` de velocidade (`math.floor(speed * 1200 / 1000)`) a unidades `swarm` com `\|uLane - heraldLane\| <= 1` e `\|uX - heraldX\| <= 2000`; aura **não cumulativa** entre múltiplos arautos. |

---

## 5. Catálogo D — Progressão Meta e Conveniência (Não P2W)

| Item / Recurso | Status | Forma de Obtenção | Limite / Regra | Preço Base Ref. (`R$`) |
|---|---|---|---|---:|
| **Fragmentos de Blueprint** | Backlog P2 | **3 Grandes Saques/dia** (gratuitos), **Ligas Semanais** e **Trilha Gratuita do Passe** | Nunca vendido diretamente por Robux; desbloqueia receitas e progressão de coleção | Grátis (gameplay) |
| **Slot de Blueprint de Muralha** | Backlog P2 | **3 slots gratuitos** na conta base | Hard cap de **10 slots** salvos por jogador; apenas conveniência de organização/troca rápida | `149–199 R$` / slot |
| **Grande Saque Extra** | Backlog P2 | Opcional na loja diária | Limite estrito de **máx. +1/dia** além dos 3 gratuitos (nunca ilimitado; evita grinding pago infinito) | `25–50 R$` |

---

## 6. Catálogo E — Cosméticos e Passe de Temporada (Zero Impacto no Motor)

Todos os cosméticos usam `profile.cosmetics[id] = true`, respeitando `MAX_COSMETICS = 200` e `MAX_ID_LENGTH = 48` (`^[%w_%.%-]+$`). **Zero impacto em `Core.Battle`, `result_hash` ou `SIM_VERSION`.**

### 6.1 Temas de Muralha / Diorama (`149–249 R$` avulso · `300–360 R$` pacote)

| ID Canônico (`<= 48` chars) | Nome de Exibição (PT-BR) | Conceito Visual (Muralha, Chão e Portão) | Faixa Base (`R$`) |
|---|---|---|---:|
| `theme_iron_bastion` | Bastião de Ferro | Chapas rebitadas, aço escovado e tochas âmbar industriais | `149–249` |
| `theme_ember_forge` | Forja de Brasa | Basalto vulcânico, grades incandescentes e bigorna no portão | `149–249` |
| `theme_frost_ruin` | Ruína Glacial | Pedra rúnica congelada, estalactites e lanternas azul-frio | `149–249` |
| `theme_clockwork_guild` | Guilda de Engrenagens | Madeira envernizada, engrenagens de latão e vapor nas bordas | `149–249` |
| `theme_obsidian_crown` | Coroa de Obsidiana | Muralha negra facetada com filetes dourados e portão real | `149–249` |

> **Bundles de Diorama:** pacotes temáticos (2 a 3 temas ou tema + finalizador) são precificados na faixa-base de **`300–360 R$`**, com exibição dinâmica obrigatória via `MarketplaceService:GetProductInfo()`.

### 6.2 Skins de Armadilha por Tier Cosmético

| Tier Cosmético | Faixa Base (`R$`) | Regra de Obtenção / Escopo Visual |
|---|---:|---|
| **Comum** | Grátis (Maestria) | Recolor de paleta da armadilha desbloqueado por marcos de uso/maestria |
| **Raro** | `79–99 R$` | Troca de material/acabamento e pequenos adereços dentro do teto `≤ 11` partes |
| **Épico** | `149 R$` | Modelo estilizado completo (`≤ 1.500` tris e silhueta legível a 200 px) + projétil customizado |
| **Lendário** | `249 R$` | Modelo completo + VFX de disparo/impacto exclusivo (`≤ 3` emitters / `≤ 150` partículas) + SFX próprio |
| **Mítico** | Passe / Maestria Máx. | Recompensa exclusiva de fim de temporada ou maestria máxima da armadilha (não vendido avulso) |

### 6.3 Skins de Horda, Finalizadores de Clipe (`8 s`) e Identidade

- **Skins de Horda (`149–249 R$`):** alteram o visual das tropas enviadas pelo atacante (`runner`, `brute`, `swarm`). O ID cosmético é **serializado nos metadados do `BattleLog`** para que o defensor assista às tropas com a skin correta durante o **replay de 8 segundos**, sem alterar a simulação nem o `result_hash`.
- **Finalizadores de Clipe de 8 s (`99–149 R$`):** VFX dramático no momento de ruptura ou sustentação do portão (projetado para o botão **GRAVAR CLIPE** via `CaptureService`):

| ID Canônico (`<= 48` chars) | Trigger no Replay (`8 s`) | Efeito Visual (`VFX_`) | Faixa Base (`R$`) |
|---|---|---|---:|
| `vfx_breach_meteor` | Ruptura do portão (`attacker` vence) | Impacto de meteoro quebrando o portão com estilhaços | `99–149` |
| `vfx_breach_kraken_teal` | Ruptura do portão (`attacker` vence) | Tentáculos verde-água (`#14B8A6`) emergindo no colapso | `99–149` |
| `vfx_defend_golden_anvil` | Sustentação (`defender` vence) | Selo dourado de bigorna selando a vitória defensiva | `99–149` |
| `vfx_defend_fireworks` | Sustentação (`defender` vence) | Salva de fogos festivos sobre as torres aos `1200` ticks | `99–149` |

- **Identidade e Social:**
  - **Banners & Títulos de Cartão de Batalha:** exibidos na tela de abertura da raid e no relatório de vingança;
  - **Molduras de Replay (`Replay Frames`):** bordas estilizadas aplicadas ao `ViewportFrame` / clipe exportado;
  - **Selo Verificado 18+ (`badge_verified_18plus`):** cosmético opcional oferecido após `PromptAgeCheck()` no momento de recompensa (nunca no spawn e nunca bloqueando conteúdo para console/VR).

### 6.4 Passe de Temporada (`Season Pass`)

- **Preço-base de referência:** **`399–499 R$`** (ou assinatura em moeda local da Roblox com modelo **`70%` no 1º mês → `100%` a partir do 2º mês**).
- **Separação estrita das trilhas:**
  - **Trilha Gratuita:** concentra **100% dos itens com impacto de progressão/gameplay** (Ouro, Fragmentos de Blueprint, desbloqueios sazonais);
  - **Trilha Paga:** **100% cosmética** (Temas de Diorama, Skins de Armadilha Épica/Mítica, Skins de Horda, Finalizadores de Clipe `8 s`, Banners, Títulos e Molduras de Replay).

---

## 7. Checklist de Implementação de Loja, Telemetria e Preço Regional

Antes de habilitar qualquer SKU cosmético ou de conveniência na **P2+**, validar obrigatoriamente:

1. **Consulta dinâmica de preço:** toda vitrine/botão de compra chama `MarketplaceService:GetProductInfo(id, InfoType)` e exibe `PriceInRobux` retornado pela API (nunca string fixa no cliente).
2. **Alinhamento de DevEx & Regional Pricing (`GAP-013`):** acompanhar no Creator Analytics o ARPPU e a conversão por país (EUA/Canadá vs. Europa vs. APAC vs. ROW/Brasil), registrando o preço efetivo pago na telemetria (sem PII; nunca usar `UserId` ou nomes dentro do payload de perfil).
3. **Contrato de inventário (`ProfileSchema`):**
   - Na **P1 (`schema v2`)**, `cosmetics` armazena apenas posse `{ [id: string]: boolean }` com `#cosmetics <= 200` (`MAX_COSMETICS`) e `isIdString(id, 48)`; não há tabela `equipped` no `schema v2` (`checkForeignKeys` recusa campos extras).
   - Na **P2 (`schema v3`, [`rfcs-p2-e-fechamento-gaps.md`](rfcs-p2-e-fechamento-gaps.md#3-rfc-002--profileschema-v3-battlelog-estendido--core-v4-gap-004--gap-016))**, entram os slots `profile.equipped = { theme, hordeSkin, finisher, commander }` e a `RemoteFunction` `CosmeticAction(action: "equip" | "unequip", slot, cosmeticId)` validando no servidor contra `not_owned`, `invalid_slot` e `unknown_cosmetic` e emitindo `cosmetic_equipped` (taxonomia v2, `RFC-003`).
   - Nenhuma chave de PII (`PII_KEYS`) ou campo fora da whitelist (`TOP_FIELDS`) entra em `Profile.Data`.
4. **Contrato de replay (`BattleLog`):** skins de horda, tema de muralha e finalizadores de `8 s` são metadados puramente visuais; o servidor re-simula `Core.Battle` apenas com `seed`, `simVersion`, `contentVersion`, `wall` e `wave`, garantindo `result_hash` idêntico independente dos cosméticos equipados.

### 7.1 Limites Rígidos Consolidados do Schema & Motor

| Constante | Valor Atual | Fonte Executável |
|---|---:|---|
| `TrapCatalog.CONTENT_VERSION` | `2` | [`TrapCatalog.luau`](../src/shared/data/TrapCatalog.luau) |
| `Core.SIM_VERSION` | `3` | [`core.luau`](../src/shared/sim/core.luau) |
| `ProfileSchema.SCHEMA_VERSION` | `2` | [`ProfileSchema.luau`](../src/shared/data/ProfileSchema.luau) |
| `ProfileSchema.MAX_COSMETICS` | `200` | [`ProfileSchema.luau`](../src/shared/data/ProfileSchema.luau) |
| `ProfileSchema.MAX_ID_LENGTH` | `48` | [`ProfileSchema.luau`](../src/shared/data/ProfileSchema.luau) |
| `ProfileSchema.MAX_GOLD` | `1.000.000.000` | [`ProfileSchema.luau`](../src/shared/data/ProfileSchema.luau) |
| `Core.ACTIVE_TRAP_LIMIT` (P1) | `5` (schema cap `25`) | [`core.luau`](../src/shared/sim/core.luau) |


