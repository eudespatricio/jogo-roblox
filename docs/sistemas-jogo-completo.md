# Sistemas Completos do Jogo Comercial — MURALHA / WALLBREAKER (`RFC-009`)

> **Status:** Especificação mestre de sistemas comerciais (pós-P1 / roadmap P2–P4). **P1 em pausa; P2+ bloqueada** sem autorização explícita do diretor (`.context/ESTADO.md`). Nenhum código `.luau`, `sim/`, `vendor/` ou `docs/versoes.md` foi alterado.
> **Governança de Dados:** Novas estruturas persistidas destinam-se ao **`ProfileSchema v3+` (`RFC-009`)** em `MuralhaProfile_v1`, estendendo o v3 de [`rfcs-p2-e-fechamento-gaps.md`](rfcs-p2-e-fechamento-gaps.md) com whitelist estrita (`TOP_FIELDS`), zero `PII_KEYS`, chave `User_<UserId>`, IDs `<= 48` chars (`MAX_ID_LENGTH`), inteiros `<= MAX_COUNTER` e `cosmetics <= 200`. **Monetização Ética:** zero loot box, zero poder pago, zero Robux→Ouro, preço dinâmico via `GetProductInfo()` (`RFC-006`).

```lua
--!strict
-- Extensao ProfileSchema v3+ (RFC-009): adicionar a TOP_FIELDS, newProfile() e sanitizeCurrent().
-- Regra de migracao neutra: contas migradas de v2/v3 recebem defaults seguros sem alterar Wall/Core.
export type FtueState = {
	step: number,        -- inteiro 0..6 (6 = concluido)
	skipped: boolean,    -- true se usou skip seguro
	completedAt: number, -- os.time() inteiro (>= 0)
}

export type ContractSlot = {
	id: string,          -- <= 48 chars, deterministico (ex: "d_place_5_20400")
	metric: string,      -- "wins" | "raids" | "traps_placed" | "synergies" | "upgrades"
	target: number,      -- inteiro > 0
	progress: number,    -- inteiro 0..target
	rewardGold: number,  -- source = "daily"
	rewardXp: number,    -- XP do Passe de Temporada
	claimed: boolean,
}

export type ContractsState = {
	dayId: number,       -- math.floor(os.time() / 86400)
	weekId: number,      -- math.floor((os.time() - 1794182400) / 604800)
	rerollDayId: number, -- ultimo dayId em que usou o 1 reroll gratis
	daily: { ContractSlot },  -- max 3
	weekly: { ContractSlot }, -- max 3
}

export type SeasonPassState = {
	seasonId: number,
	xp: number,
	premiumOwned: boolean,
	claimedFree: { [string]: boolean }, -- chave "t1".."t30"
	claimedPaid: { [string]: boolean }, -- 100% cosmeticos
}

export type StreakState = {
	count: number,        -- 0..7 (ciclo semanal continuo)
	lastDayId: number,    -- ultimo dayId resgatado
	freezeTokens: number, -- 0..2 (obtidos por gameplay/semanal, nunca por Robux)
}

export type CommercialProfileExt = {
	ftue: FtueState,
	contracts: ContractsState,
	pass: SeasonPassState,
	streak: StreakState,
	orderId: string?,               -- <= 48 chars; nil quando sem cla ("Ordem")
	settings: ProfileSettings,
	processedReceipts: { string },  -- ledger circular FIFO (max 100 PurchaseIds)
}

-- Whitelist e invariantes obrigatorias em ProfileSchema.luau (RFC-009):
-- 1) TOP_FIELDS += { "ftue", "contracts", "pass", "streak", "orderId", "settings", "processedReceipts" }
-- 2) checkForeignKeys recusa qualquer campo fora de TOP_FIELDS e qualquer chave em PII_KEYS.
-- 3) processedReceipts valida #lista <= 100 e cada PurchaseId <= 48 chars ASCII (isIdString).
-- 4) MIGRATIONS[3+] inicializa defaults neutros sem tocar wall.cells nem alterar hash 2489780106.
```

---

## 1. Jornada Completa dos Primeiros 30 Minutos (FTUE `ftueStep 0..6`)

O fluxo remove fricção no join (`CharacterAutoLoads = false`) e conduz o jogador da ação imediata ao meta de retenção sem tutoriais bloqueantes de texto.

| `ftueStep` | Janela | Marco & Ação do Jogador | Gatilho / Validação Autoritativa | Recompensa / Saída |
|---|---|---|---|---|
| **0 → 1** | `0–60 s` | **Drop-in 5s → 1ª Vitória:** botão `DEFENDER` aciona catapulta em `r3c3` (`seed = 4`); libera câmera e HUD de build. | `DropInAction("press")` conclui `PHASE_CLEARED` + `emitFirstWin` (`first_win_seconds`). | `+3g` + subsídio único `+40g` se `stats.defenses == 0` (`defense`). |
| **1 → 2** | `Min 1–3` | **1º Build, Upgrade & Raid Fantasma:** coloca `archer` (`40g`), faz 1º upgrade (`30g`) após 1ª raid e ataca fantasma L1. | `WallService.place`/`upgrade` + `RaidStart` (`ownerHash ~= myHash` ou bot L1). | `+18g` (`raid`) + desbloqueio da aba **Campanha**. |
| **2 → 3** | `Min 3–8` | **Campanha 1-1 & 1ª Sinergia:** enfrenta onda determinística `1-1` e posiciona par na mesma lane (`tar` + `archer`/`cannon`). | `CampaignStart("c1_1")` valida `synergyCount >= 1` no `Core.normalizeTraps`. | `+35g` + desbloqueio de `tar` / `Gambit` inicial. |
| **3 → 4** | `Min 8–15` | **Opcional Co-op / Replay 8s:** assiste replay 3D de 8s (botão `Clipe 8s`) ou entra em Dupla Assíncrona / Vingança. | `RaidReplay` verificado (`final.hash == resultHash`) ou `PartyAction("join"\|"solo_optout")`. | `+25g` + 1º Fragmento de Blueprint (sem punição se pular co-op). |
| **4 → 5** | `Min 15–25` | **Contratos Diários & Upgrade L2–L3:** completa 1 contrato diário simples (`traps_placed` ou `wins`) e sobe armadilha. | `ContractAction("claim", "daily", slot)` verifica progresso inteiro no servidor. | `+40g` + XP do Passe de Temporada (`+120 XP`). |
| **5 → 6** | `Min 25–30` | **Boss 1-5 (Cerco do Aríete):** defende onda temática com `brute`/`siege_ram` e encerra FTUE com selo de Arquiteto. | `CampaignStart("c1_5")` retorna `winner == "defender"`. | Título `Arquiteto de Ferro` + Badge `BDG-01` + `ftueStep = 6`. |

### Skip Seguro & Contrato de Rede (`FtueAction`)
- **Regra de Skip Seguro:** disponível a partir de `ftueStep >= 1` (após 1º clear de drop-in ou via botão `"Pular Guia"` no menu de opções). Ao acionar `FtueAction("skip")`, o servidor:
  1. Define `ftue.step = 6`, `ftue.skipped = true`, `ftue.completedAt = os.time()`.
  2. Credita **apenas** o subsídio único pendente (`+40g`, `source = "defense"`) se `stats.defenses == 0` e `gold == 0`, evitando o deadlock econômico da P1 sem criar farm duplicado.
  3. **Não** altera `first_win_seconds` e **não** concede recompensas da Campanha `1-1..1-5` (as fases continuam abertas e premiáveis normalmente na aba Campanha).
- **Remote & Guard:** `ReplicatedStorage.MuralhaRemotes.FtueAction` (`RemoteFunction`, cooldown `1.0 s`). Servidor rejeita regressão (`nextStep <= currentStep`), bloqueia `skip` quando `step == 6` (`"ftue_done"`), valida `step` inteiro em `0..6` e emite evento de telemetria (`ftue_step` / `ftue_skip`).

---

## 2. Relatório Pós-Partida, DPS Meter & Diagnóstico de Derrota

Calculado no servidor **em paralelo** à finalização de `Core.Battle` (ou em passo pós-batalha somente leitura no cliente ao verificar `resultHash`), sem alterar RNG, `BattleResult.hash` ou `SIM_VERSION`.

```lua
--!strict
export type TrapCombatReport = {
	cell: string,           -- "r1c1".."r7c5"
	trapId: string,         -- "archer" | "tar" | "frost" | "cannon" | "catapult" | ...
	damageDealt: number,    -- dano efetivo inteiro em MILLI acumulado na partida
	kills: number,          -- abates finais creditados a celula
	synergyDamage: number,  -- parcela de damageDealt gerada por Camada A/B/C
	controlTicks: number,   -- ticks de slow/stun/knockback aplicados
	goldEfficiency: number, -- math.floor(damageDealt / math.max(1, totalGoldInvested))
}

export type SectorComparison = {
	sectorA: { damage: number, leaks: number, breachedAtTick: number? }, -- Lanes 1-2
	sectorB: { damage: number, leaks: number, breachedAtTick: number? }, -- Lanes 4-5
	sharedGateLeaks: number,                                             -- Lane 3
}

export type DefeatDiagnosis = {
	breachedLane: number,        -- 1..5 (lane com maior dano de vazamento)
	lethalUnit: string,          -- "runner" | "brute" | "swarm" | ...
	countermeasureCode: string,  -- chave LocalizationTable: "diag_brute_lane", etc.
}
```

| Componente da Tela Pós-Partida | Regra de Cálculo & Exibição Mobile (`375×812`) | Regra de UX / Anti-Toxicidade |
|---|---|---|
| **DPS Meter & Selo `MVP`** | Lista ordenada por `damageDealt` desc. (desempate: `kills`, depois `cell` canônico). A célula #1 recebe o selo **`MVP`** (ícone coroa âmbar + `%` do dano total). | Exibe eficiência por ouro (`goldEfficiency`) para ensinar valor de `archer`/`tar` vs `catapult` cara. |
| **Comparativo Setor A vs Setor B (Co-op)** | No modo Dupla Assíncrona (`P3`), compara **Setor A (`r1–r2`)**, **Portão Partilhado (`r3`)** e **Setor B (`r4–r5`)**, apontando exatamente **quem cedeu primeiro** (`breachedAtTick`). | Foco factual em ticks e lane (sem notas punitivas ou culpa pessoal entre parceiros). |
| **Diagnóstico Automático de Derrota** | Quando `winner == "attacker"`: identifica `breachedLane` (maior soma de `leak`) + `lethalUnit` (tipo que causou maior dano ao portão nessa lane) e mapeia 1 contramedida acionável. | Ex.: `brute` na Lane 3 → `"Lane 3 cedeu: use Gelo + Canhão."`; `swarm` → `"Enxame passou: use Catapulta."` |
| **CTAs Pós-Partida** | **3 botões `>= 44 px`:** `JOGAR DE NOVO` (replay/nova raid), `VINGAR` (ataca `ownerHash` do rival, trava anti-win-trading `24 h` por par) e `CLIPE 8s` (`CaptureService:StartVideoCaptureAsync` pré-roll `0.5 s` + `8 s`). | `VINGAR` desabilitado se alvo for bot ou se o par `(attacker, defender)` estiver em cooldown de `24 h`. |

---

## 3. Metagame de Retenção Ética

### 3.1 Contratos Diários/Semanais Determinísticos, Passe de Temporada & Login Streak
- **Contratos Determinísticos (`dayId` / `weekId`):** `dayId = math.floor(os.time() / 86400)`, `weekId = math.floor((os.time() - 1794182400) / 604800)`. A pool é gerada por hash determinístico de `(dayId, slotIndex)` ou `(weekId, slotIndex)` garantindo paridade entre servidores sem DataStore global extra.
  - Cada conta mantém **3 Contratos Diários** e **3 Contratos Semanais** + **1 reroll gratuito por `dayId`** (`rerollDayId ~= dayId`; proibido reroll pago).
  - Ao detectar troca de `dayId` ou `weekId`, o servidor reseta apenas os slots expirados mantendo os demais intactos.
- **Passe de Temporada (`399–599 R$` base, dinâmico via `GetProductInfo`):**
  - **Trilha Gratuita:** concentra **100%** dos itens funcionais (Ouro, Fragmentos de Blueprint, desbloqueios de traits/doutrinas).
  - **Trilha Cosmética (`DevProduct` / `GamePass` sazonal):** **100% cosmética** (Temas de Diorama, Skins Épicas/Míticas, Skins de Horda, Finalizadores `8 s`, Banners/Títulos). Zero XP booster pago ou compra de dano.
- **Login Streak com Grace Freeze:** recompensa ciclos contínuos de **7 dias** (Ouro + Fragmentos + Cosmético comum no dia 7). Se `dayId - lastDayId == 2` e `freezeTokens > 0`, o servidor consome `1` *Grace Freeze* automaticamente (teto `2` tokens, ganhos por contrato semanal) preservando `streak.count`; se `> 2` dias sem token, reinicia para `1` sem punir liga ou ouro.

| Remote (`MuralhaRemotes`) | Payload Aceito | Guardas Server-Side Obrigatórias |
|---|---|---|
| `ContractAction` | `{ action: "reroll"\|"claim", scope: "daily"\|"weekly", slot: 1..3 }` | `reroll`: exige `scope == "daily"`, `claimed == false`, `rerollDayId ~= dayId`; `claim`: exige `progress >= target` e `claimed == false`. |
| `PassAction` | `{ action: "claim", tier: 1..30, track: "free"\|"paid" }` | Verifica `xp >= tierXp(tier)`, `claimed[key] ~= true`; se `track == "paid"`, exige `pass.premiumOwned == true`. |
| `StreakAction` | `{ action: "claim" }` | Exige `lastDayId < currentDayId`; aplica lógica atômica de *Grace Freeze* antes de creditar recompensa do dia. |

### 3.2 Tabela dos 12 Roblox Badges (`BadgeService` com Retry Idempotente)
Todo badge dispara via fila assíncrona server-side com cache em memória `awardedCache[userId][badgeKey]` + `UserHasBadgeAsync` antes de `AwardBadge` (evitando erro repetido e respeitando rate limit de `BadgeService` com até 3 tentativas exponenciais `1 s, 2 s, 4 s`).

| Código | Nome do Badge (PT-BR / EN) | Critério Determinístico de Disparo (Server-Only) |
|---|---|---|
| `BDG-01` | **Primeiro Portão** / *First Gate* | Concluir Drop-in 5s ou atingir `ftueStep == 6`. |
| `BDG-02` | **Mão na Massa** / *Builder's Mark* | Construir `5` armadilhas ativas simultâneas na grade (`build_complete`). |
| `BDG-03` | **Mestre da Forja** / *Forge Master* | Evoluir qualquer armadilha para o nível `3` (`MAX_LEVEL` P1). |
| `BDG-04` | **Química Letal** / *Tactical Synergy* | Vencer batalha com ao menos `2` sinergias de Camada A ativas. |
| `BDG-05` | **Sobrevivente a 1 HP** / *One HP Stand* | Vencer defesa com `wallHp == 1000` (`1 HP`) ou ativação de `gambit_iron_brace`. |
| `BDG-06` | **Vingança Servida** / *Cold Revenge* | Vencer revanche iniciada pelo botão `VINGAR` de um `BattleLog`. |
| `BDG-07` | **Cineasta de Cerco** / *Siege Director* | Acionar exportação de clipe `8 s` (`CaptureService`) pós-batalha. |
| `BDG-08` | **Arquiteto de Âmbar** / *Amber Architect* | Alcançar a Liga **L5 — Âmbar** (`400+` pontos Elo). |
| `BDG-09` | **Bastião Eterno** / *Eternal Bastion* | Alcançar a Liga **L7 — Bastião Eterno** (`900+` pontos Elo). |
| `BDG-10` | **Pacto de Ferro** / *Iron Pact* | Concluir `10` raids ou defesas válidas em Dupla Assíncrona ou Ordem. |
| `BDG-11` | **Vigília Inabalável** / *Unbroken Watch* | Completar um ciclo de Login Streak de `7` dias. |
| `BDG-12` | **Lenda da Fenda** / *Rift Legend* | Participar de marco global da Fenda Cooperativa ou Top 10% da Invasão do Dia. |

---

## 4. Social, Party Co-op, Blueprint Codes (`MRL-XXXX`), Clãs ("Ordens") & 4 Leaderboards

- **Party Co-op (Dupla Assíncrona & Lobby):** convites via `SocialService:PromptGameInvite` ou código de sala; na Dupla Assíncrona (`P3`), `Jogador A` controla `r1–r2`, `Jogador B` controla `r4–r5` e ambos compartilham `r3` sob *lock* otimista (`rev++`), debitando ouro do próprio saldo sem janela de corrida. Comunicação exclusivamente via os **8 códigos de Quick-Chat curado** (`QuickChatEvent`, 3 msgs / 10 s, `CanUsersChatAsync`).
- **Blueprint Codes (`MRL-XXXX`):** formato compartilhável `MRL-<BASE32_8CHARS>` (ou `MRL-<4>-<4>`, máx. 14 chars, validado por checksum CRC-8/XOR determinístico). Codifica apenas `(gridWidth, cells: { cell, trap, level, class, trait }, gambitId)` — **zero `UserId`/nome/PII**.
  - **Remote `BlueprintAction(action: "export"\|"import", code?)`:** na importação, o servidor valida assinatura, verifica se todos os `trap_id` estão desbloqueados na liga do jogador e aplica **somente dentro do saldo de ouro disponível** (ou projeta células pendentes como fantasma local para construção manual).
- **Clãs ("Ordens", `<= 30` membros):** persistidos em DataStore dedicado `MuralhaOrders_v1` (chave `Order_<orderId>`, limite `<= 30` membros ativos validado atomicamente em `UpdateAsync`). Cargos: `Leader`, `Officer`, `Member`.
  - **Remote `OrderAction(action: "create"\|"join"\|"leave"\|"kick"\|"claim_chest", payload)`:** nome e lema passam por `TextService:FilterStringAsync` na criação; atividade soma Pontos de Ordem para o Baú Semanal da Ordem (Ouro/Fragmentos/Molduras, zero bônus de combate).

```lua
--!strict
export type OrderRecord = {
	orderId: string,       -- <= 48 chars
	name: string,          -- filtrado via TextService (<= 24 chars)
	seasonId: number,
	weeklyPoints: number,  -- soma limitada por teto diario por membro
	members: { [string]: { role: "Leader" | "Officer" | "Member", joinedAt: number, contrib: number } }, -- max 30
}
```

### Os 4 Leaderboards (`OrderedDataStore` Cached & Sharded)
Leitura em cache no servidor (`TTL = 120 s`, `GetSortedAsync` paginado top 50) + escrita agrupada no flush de saída/fim de batalha (`cooldown >= 60 s`/jogador) para proteger quotas do Roblox.

| Leaderboard | Store (`OrderedDataStore`) | Chave / Sharding | Métrica Inteira & Regra de Exibição |
|---|---|---|---|
| **1. Elo de Liga (Sazonal)** | `MuralhaLB_Elo_S<season>` | Sharded por `seasonId` (`UserId` como key) | `profile.league.points` (`0..999999`). Reset suave entre temporadas. |
| **2. Vitórias Totais** | `MuralhaLB_Wins_v1` | Global (`UserId` como key) | `profile.stats.wins`. Desempate por ordem de gravação; exibe apenas `DisplayName` em runtime. |
| **3. Invasão Global do Dia** | `MuralhaLB_Daily_<dayId>` | Rotação automática diária (`dayId`) | Score composto inteiro: `wallHp * 10000 + (1200 - ticks)` (maior HP restante e menor tempo). |
| **4. Ranking de Ordens** | `MuralhaLB_Orders_S<season>` | Sharded por `seasonId` (`orderId` como key) | Soma semanal de pontos das `<= 30` contas da Ordem (teto diário por membro anti-bot). |

---

## 5. Configurações Persistentes, Controles Multi-Plataforma, Acessibilidade & Localização (PT/EN/ES)

```lua
--!strict
export type ProfileSettings = {
	audioMaster: number,   -- 0..100 (default 80)
	audioSfx: number,      -- 0..100 (default 80)
	audioAmbience: number, -- 0..100 (default 60)
	physicsTier: string,   -- "auto" | "low" | "mid" | "high" (orçamento VFX/partes cliente)
	screenShakePct: number,-- 0 | 50 | 100 (default 100; respeitado em MOTION.shakeSmall/Large)
	antiFlash: boolean,    -- reduz hitFlash/claroes de finisher e strobe (default false)
	handedness: string,    -- "right" | "left" (espelha HUD lateral / botoes de acao)
	uiScalePct: number,    -- 85..125 (step 5; mantendo minTouch >= 44 px absoluto)
	colorblindMode: string,-- "none" | "protanopia" | "deuteranopia" | "tritanopia"
	localeOverride: string,-- "auto" | "pt-br" | "en-us" | "es-419"
}
-- Remote: SettingsAction(patch: ProfileSettings) — servidor valida enum/range exato antes de gravar no perfil.
```

- **Acessibilidade Visual & Daltonismo:** além de ajustar paletas em `VisualTheme` (contraste mínimo `4.5:1`), os **3 modos de daltonismo** ativam **formas geométricas e ícones distintos** sobre defensores (círculo/escudo Âmbar) vs. horda (losango/seta Turquesa) e nos cartões de armadilha, impedindo dependência exclusiva de cor. `antiFlash = true` substitui flashes brancos (`hitFlash`) por mudança de borda opaca e suprime partículas de alto brilho.

### Matriz de Controles Multi-Plataforma
| Plataforma | Navegação / Seleção de Célula (`r1c1..r5c5`) | Ações Principais & Atalhos | Feedback Tátil / UX |
|---|---|---|---|
| **Mobile (Touch)** | Tap direto 3D com `Raycast` nas placas (`TOUCH_SLOP_PX = 12` para diferenciar tap de pan/pinch). | Deck inferior (`h >= 44 px`), `ATACAR` (`>= 104×44 px`), toque longo `1.5 s` na versão abre `DebugHud`. | `HapticService:SetMotor` pulso leve em `place`/`upgrade`, pulso duplo em ruptura (`gamepad`/mobile suportado). |
| **PC (Teclado + Mouse)** | Hover `SelectionBox` via mouse + clique esquerdo executa intenção ativa; clique direito cancela. | `1..5` seleciona trap; `E` coloca/upgrade; `R` remove; `Q` alterna modo; `Space` inicia Raid / avança FTUE; `Tab` abre DPS/Placar; `F3` `DebugHud`. | Tooltip de alcance (`range`) e prévia de sinergia na lane ao pairar mouse. |
| **Gamepad / Console** | `DPad` e `Thumbstick1` com **snap magnético** discreto nas células `rXcY` do grid (zona morta `0.25`). | `ButtonA` confirma (`place`/`upgrade`), `ButtonX` remove, `ButtonY` inicia `Raid`/`ATACAR`, `R1`/`L1` ciclam deck `1..5`. | Cursor 3D destacado em âmbar + guia de ícones de botão automática ao detectar `LastInputType == Gamepad1`. |

### `LocalizationTable` (PT-BR / EN-US / ES-LATAM)
Fonte canônica em [`../assets/i18n/LocalizationTable.csv`](../assets/i18n/LocalizationTable.csv) validada no CI via [`../tools/check-i18n.py`](../tools/check-i18n.py) (envelope Analytics normaliza `es-419` → `"es-MX"` para respeitar `str(5, "locale")`). Orçamento estrito de caracteres mobile (`CTA <= 12`, `Modo <= 10`, `Toast <= 36`, `Verbo <= 38`, `Diag <= 44` chars):

| Chave (`LocalizationTable`) | `pt-br` (Fonte) | `en-us` | `es-419` |
|---|---|---|---|
| `game_title` | `A MURALHA` | `WALLBREAKER` | `LA MURALLA` |
| `cta_defend` | `DEFENDER` | `DEFEND` | `DEFENDER` |
| `cta_attack` | `ATACAR` | `ATTACK` | `ATACAR` |
| `cta_revenge` | `VINGAR` | `REVENGE` | `VENGAR` |
| `cta_clip_8s` | `CLIPE 8s` | `8s CLIP` | `CLIP 8s` |
| `mode_place` | `COLOCAR` | `PLACE` | `COLOCAR` |
| `mode_upgrade` | `MELHORAR` | `UPGRADE` | `MEJORAR` |
| `mode_remove` | `REMOVER` | `REMOVE` | `QUITAR` |
| `diag_brute_lane` | `Lane %d cedeu: use Gelo + Canhão.` | `Lane %d breached: use Frost + Cannon.` | `Carril %d roto: usa Hielo + Cañón.` |

---

## 6. Loja Idempotente (`ProcessReceipt`), `PolicyService` & Live-Ops / Anti-Exploit / Admin

### 6.1 `ProcessReceipt` Idempotente & `PolicyService`
```lua
--!strict
-- Contrato do Ledger Circular no ProfileStore (server-only, antes de PurchaseGranted):
local MAX_PROCESSED_RECEIPTS = 100
local function recordPurchaseAndSave(profile: any, session: any, receiptInfo: any): boolean
	for _, id in ipairs(profile.processedReceipts) do
		if id == receiptInfo.PurchaseId then return true end -- ja processado: idempotente
	end
	if not grantSkuToProfile(profile, receiptInfo.ProductId) then return false end
	table.insert(profile.processedReceipts, receiptInfo.PurchaseId)
	if #profile.processedReceipts > MAX_PROCESSED_RECEIPTS then
		table.remove(profile.processedReceipts, 1) -- FIFO circular
	end
	local ok = pcall(function() session:Save() end)
	return ok -- so retorna PurchaseGranted ao MarketplaceService se ok == true
end
```
- **Fluxo `MarketplaceService.ProcessReceipt`:** se jogador offline ou perfil ainda em boot, retorna `Enum.ProductPurchaseDecision.NotProcessedYet`. Após `recordPurchaseAndSave == true`, emite `store_purchase` (`RFC-003` + `RFC-006` com `effective_price_robux = receiptInfo.CurrencySpent` e `country_code`) e retorna `Enum.ProductPurchaseDecision.PurchaseGranted`.
- **`PolicyService:GetPolicyInfoForPlayerAsync(player)`:** chamado 1× no `ProfileBoot` (`pcall`, fail-safe restritivo em erro) guardando flags efêmeras de sessão:
  - `ArePaidRandomItemsRestricted`: reforço de compliance (jogo já proíbe loot boxes por princípio).
  - `IsPaidItemTradingAllowed`: trava qualquer feature de troca futura para regiões restritas.
  - `AllowedExternalLinkReferences`: oculta avisos/links externos (Discord/redes) se ausente na política.
  - Preços sempre lidos via `MarketplaceService:GetProductInfo(id, infoType)` (`RFC-006`), ocultando botão de compra se `PriceInRobux == nil`.

### 6.2 Matriz Anti-Exploit por Remote (`ReplicatedStorage.MuralhaRemotes`)
| Remote (Cliente → Servidor) | Rate Limit / Lock | Validação Server-Side Obrigatória | Rejeição & Telemetria |
|---|---|---|---|
| `BuildAction` / `DropInAction` | `>= 150 ms` cooldown/jogador | `BuildProtocol.validateRequest`, `TrapCatalog`, liga, `gold`, revisão (`rev`) em Co-op. | Retorna `{ ok = false, reason }`; descarta strings > 48 chars. |
| `RaidStart` / `CampaignStart` | Lock `busy[player]` (`8 s` ou ACK) | `target.ownerHash ~= myHash`; `Core.Battle` roda **apenas** no servidor; client só anima. | Emite `battle_divergence` se client reportar mismatch de hash. |
| `FtueAction` / `ContractAction` / `PassAction` / `StreakAction` | `1.0 s` cooldown/jogador | Progresso inteiro validado no servidor; `dayId`/`weekId` server UTC; `claimed == false`. | Log de anomalia se tentativa repetida de claim já resgatado. |
| `BlueprintAction` / `OrderAction` | `2.0 s` cooldown (`UpdateAsync >= 6 s` p/ Ordem) | Checksum `MRL-XXXX`, zero PII, `FilterStringAsync` para nome de Ordem, `#members <= 30`. | Recusa nomes filtrados ou códigos inválidos (`"bad_code"`). |
| `QuickChatEvent` / `SettingsAction` / `CosmeticAction` | `QuickChat`: `3 / 10 s` (`2 s` min); demais `0.5 s` | Whitelist estrita (`8` códigos `qc_*`), `CanUsersChatAsync`, enums/ranges em `Settings`, posse em `cosmetics`. | Descarta silenciosamente payload fora da whitelist. |

### 6.3 `BindToClose`, Server Drain Migratório & Console Staff
- **Server Drain & `BindToClose`:** ao receber sinal de drain (flag `drainServer = true` no `LiveConfigService` ou `game:BindToClose`):
  1. Servidor marca `draining = true`, bloqueia novas `RaidStart` / `CampaignStart` / `OrderAction` retornando `"server_draining"` e exibe banner não bloqueante `"Atualizando servidor — migrando partida..."`.
  2. Consolida flushes pendentes (`AnalyticsService.flush("shutdown")` + `session:EndSession()` no `ProfileStore` aguardando salvamento).
  3. Em drain gracioso (pré-fechamento programado), reserva servidor destino (`TeleportService:ReserveServer` ou `TeleportAsync` para lobby limpo) e migra os jogadores conectados em lotes **após** `EndSession()` liberar os session locks do `ProfileStore` (evitando lock fantasma na chegada).
- **Console Staff (`/inspect`, `/toggle_flag`, `/drain_server`):**
  - **Autorização:** `TextChatCommand` / `StaffCommand` (`RemoteEvent`) aceita **exclusivamente** `player.UserId` na allowlist de Staff ou `player:GetRankInGroupAsync(GROUP_ID) >= STAFF_MIN_RANK` (validado **no servidor**; zero comando de spawn de ouro/poder em produção).
  - **`/inspect <userId>`:** retorna resumo **sanitizado** de sessão (versões `schema/content/sim`, `gold`, `league.points`, `ftueStep`, últimos erros de `BattleLog` — **zero PII**).
  - **`/toggle_flag <flag> <bool>`:** altera flag efêmera ou publica override no `LiveConfigService` (`MemoryStoreHashMap`, ex.: `disabledTraps.catapult = true`) com registro em log de auditoria `{ actorHash, flag, value, utc }`.
  - **`/drain_server`:** aciona o fluxo de **Server Drain Migratório** acima de forma controlada em instâncias obsoletas.

### 6.4 Gate de Validação Comercial (`RFC-009`)
| Domínio | Contrato / Teste Executável | Critério de Aprovação |
|---|---|---|
| **Schema & Migração** | `sim/profile-contract.luau` + `neutral-migration.luau` | Roundtrip `v2 -> v3+` sem perda; `checkForeignKeys` e `PII_KEYS` verdes; hash neutro preservado. |
| **Loja & Compliance** | Teste Studio `MarketplaceService` Mock + `PolicyService` | Duplo callback com mesmo `PurchaseId` credita **1×**; `PriceInRobux` dinâmico; zero loot box. |
| **Controles & A11y** | QA Mobile (`375×812`), PC e Gamepad | `minTouch >= 44 px`, `TOUCH_SLOP_PX = 12`, daltonismo com ícones distintos, `antiFlash` funcional. |
| **Localização & Rede** | Auditoria `LocalizationTable` + Fuzzing Remotes | Zero truncamento `> 12` chars em CTAs; 100% dos Remotes rejeitam payload malformado/burst. |
