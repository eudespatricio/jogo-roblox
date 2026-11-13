# RFCs de Evolução (P2) & Fechamento de Gaps — MURALHA

> **Status:** Especificação de engenharia aprovada em documentação (**13/11/2026**). **P1 em pausa; P2 bloqueada** sem autorização explícita do diretor (`AGENTS.md`). Nenhum código `.luau`, fixture em `sim/`, `vendor/` ou `docs/versoes.md` foi alterado.
> **Referências:** [`pipeline-expansao.md`](pipeline-expansao.md) §5–§6 · [`gaps.md`](gaps.md) · [`arquitetura-e-fluxos.md`](arquitetura-e-fluxos.md) §3–§4 · [`versoes.md`](versoes.md)

---

## 1. Matriz de Mapeamento de Gaps (`GAP-004` .. `GAP-020`)

| Gap | RFC / Runbook | Status Atual | Versões (`schema / content / sim / taxonomia`) | Gatilho Objetivo de Fechamento |
|---|---|---|---|---|
| **GAP-014** | [RFC-001](#2-rfc-001--integridade-s61s7--polimento-s8ci-pré-tráfego-p1-gap-014--gap-017) | RFC pronta; runtime aguarda retomada da P1 | `2 / 2 / 3 / v1` (zero bump) | `AUD-01..05` corrigidos e `check.sh` + Studio verdes antes do teste de 3 semanas |
| **GAP-017** | [RFC-001](#2-rfc-001--integridade-s61s7--polimento-s8ci-pré-tráfego-p1-gap-014--gap-017) | RFC pronta; runtime aguarda retomada da P1 | `2 / 2 / 3 / v1` (zero bump) | Botões `>=44px`, replay por `id`, `runner <=8` partes e `luau-lsp` em `src/client/**` no `check.sh` |
| **GAP-004** | [RFC-002](#3-rfc-002--profileschema-v3-battlelog-estendido--core-v4-gap-004--gap-016) | RFC pronta; código aguarda autorização P2 | `2→3 / 2→3 / 3→4 / v1` | `ProfileSchema v3`, `MIGRATIONS[2]` neutra e `neutral-migration.luau` com hash `2489780106` |
| **GAP-016** | [RFC-002](#3-rfc-002--profileschema-v3-battlelog-estendido--core-v4-gap-004--gap-016) | RFC pronta; código aguarda autorização P2 | `2→3 / 2→3 / 3→4 / v1` | `equipped`/`inbox` em v3, `BattleLog v2` e `Core v4` (`GRID_WIDTH 5..7`, `slowPct`, `table.freeze`) |
| **GAP-008** | [RFC-003](#4-rfc-003--taxonomia-de-analytics-v2-gap-008) | RFC pronta; código aguarda autorização P2 | `3 / 3 / 4 / v1→v2` | `AnalyticsTypes` v2 + `sim/analytics-contract.luau` validando props de variante e eventos de loja/social |
| **GAP-005** | [RFC-004](#5-rfc-004--live-ops-feature-flags--calendário-sazonal-gap-005) | RFC pronta; código aguarda autorização P2 | `3 / 3 / 4 / v2` | `LiveConfigService` com `MemoryStoreHashMap`, fallback UTC semanal e kill-switch testado |
| **GAP-015** | [RFC-005](#6-rfc-005--sharding-muralhaphantom_v2-memorystoresortedmap-sem-colisão--gdpr-gap-015) | RFC pronta; código aguarda autorização P2 | `3 / 3 / 4 / v2` | `MuralhaPhantom_v2` em 32 shards/liga, chave única sem colisão e runbook GDPR validado |
| **GAP-013** | [RFC-006](#7-rfc-006--precificação-regional-dinâmica--auditoria-creator-analytics-gap-013) | RFC pronta; operação aguarda pré-loja P2 | `3 / 3 / 4 / v2` | `GetProductInfo` dinâmico em 100% da UI + export Creator Analytics por 4 macrorregiões |
| **GAP-018** | [RFC-007](#8-rfc-007--co-op-síncrono-lockstep-campanha-soloduo--bosses-gap-018) | Desbloqueado (13/11); aguarda P2+/V1.5 | `3→4 / 3→4 / 4→5 / v2` | Lockstep `20 Hz` (`commands[]`), `ReserveServer`, anti-leaver 90s e 5 Bosses multi-lane verdes |
| **GAP-019** | [RFC-008](#9-rfc-008--soundscapeost-adaptativa-animações-60-hz--física-real-híbrida-gap-019) | Desbloqueado (13/11); client S8.2 / Core P2+ | `2 / 2 / 3` (client) · `3→4` (`F1`) | `AudioMixer` (`MuralhaMaster`/`BGM_Bus`), animações 60 Hz, ragdoll/fratura isolados e `FPS >= 60` |
| **GAP-020** | [RFC-009](#10-rfc-009--sistemas-comerciais-de-jogo-completo-processreceipt--policyservice-gap-020) | RFC pronta; código aguarda P2+ comercial | `4 / 4 / 5 / v2→v3` | FTUE `0..6`, Pós-Partida DPS, Contratos/Passe/12 Badges, `ProfileSettings` e `ProcessReceipt` 100% verdes |

---

## 2. RFC-001 — Integridade S6.1/S7 & Polimento S8/CI Pré-Tráfego P1 (`GAP-014` & `GAP-017`)

- **Data / responsável:** 13/11/2026 · engenharia P1 (pré-tráfego)
- **Tipo:** correção de fluxo/telemetria/UX/CI (sem mudança de gameplay)
- **Versões:** `schema 2 → 2 · content 2 → 2 · sim 3 → 3 · taxonomia 1 → 1` (hash `2489780106` intacto)
- **Jogador:** elimina auto-raid exclusivo (`AUD-01`), corrige alvos de toque mobile `>= 44 px` e impede troca visual de silhueta durante o replay 3D de 8 s (`AUD-08`).
- **Economia:** bloqueia farm em parede própria e duplo crédito em drop-in de veterano (`AUD-05`); preserva `+3` ouro (1ª vez, `defense`) e `+5` ouro (`raid`).
- **Replay:** consolida `BattleLogStore` em escrita única (`AUD-04`); `RaidClient` reporta `battle_divergence` via remote ao detectar `final.hash ~= resultHash`.
- **Migração:** nenhuma (schema e catálogo congelados).

### Especificação Cirúrgica (`AUD-01..05`, `AUD-08`, `AUD-11`)
1. **`WallController.server.luau` (`AUD-02`, `AUD-05`):** injetar `emit = function(name, props) AnalyticsService.emit(player, name, props) end` em `WallService.new`, aplicar cooldown por jogador (`>= 150 ms`) em `BuildAction` e emitir `build_complete` quando `count(cells) == 5` pela primeira vez na sessão.
2. **`DropInController.server.luau` (`AUD-03`, `AUD-05`):** em `logShown`, só gravar `session.shownLogged = true` quando `AnalyticsService.emit` retornar evento não-`nil`; em `grantReward`, travar `+3` ouro se `profile.stats.sessions > 1` ou `profile.stats.defenses > 0`.
3. **`RaidController.server.luau` (`AUD-01`, `AUD-04`, `AUD-05`):** antes de `PhantomStore.put(currentSnapshot)`, buscar alvo com `ownerId ~= player.UserId` (fallback determinístico de bot P1 se store vazio/self); gravar `BattleLog` já com `rewarded`/`rewardGold` finais em **1 único `UpdateAsync`** (removendo `markRewarded` separado e o cooldown de 6 s); manter `busy[player]` travado por `RaidReplay.SECONDS` (`8 s`) ou ACK de fechamento.
4. **UI Mobile, Replay & CI (`GAP-017` / `AUD-08`, `AUD-11`):**
   - `RaidClient.client.luau`: subir `ATACAR` (`34 px → 44 px`) e `FECHAR` (`36 px → 44 px`), respeitando `VisualTheme` (`minTouch = 44`), e indexar `HordeKit` por `unitId` estável em `buildFrames` em vez de compactar array denso.
   - `HordeKit.luau` & `BuildGrid.luau`: reduzir `runner` de 9 para `<= 8` partes (`unitParts = 8`) e isolar preview de grid por cliente para eliminar churn multi-jogador em `MuralhaGrid`.
   - `scripts/check.sh`: gerar `rojo sourcemap` **antes** de `luau-lsp analyze` e incluir `src/client/**` mais `ProfileBoot`, `AnalyticsBoot`, `WallController`, `DropInController`, `RaidController`, `PhantomStore`, `BattleLogStore` e `BuildGrid`.

> [!NOTE]
> **Rastreabilidade de execução:** o passo a passo completo com coordenadas, snippets e casos de teste está em [`plano-playtest-v1.md`](plano-playtest-v1.md) (§2 para Fatia S8.1 / `GAP-014` e §3 para Fatia S8.2 / `GAP-017`), complementado por [`p1-plano.md`](p1-plano.md) §1–§2, [`arquitetura-e-fluxos.md`](arquitetura-e-fluxos.md) §4 (`AUD-01..05, AUD-08, AUD-11`), [`direcao-visual-e-silhuetas.md`](direcao-visual-e-silhuetas.md) §4.2 e [`teste-s8-studio.md`](teste-s8-studio.md).

### Verificação & Rollback
| Suite / Comando | Escopo Provado | Critério de Aprovação |
|---|---|---|
| `luau sim/dropin-contract.luau` | Retry, +3 ouro veterano bloqueado, `dropin_shown` sem corrida | `8/8` + casos novos verdes |
| `luau sim/raid-contract.luau` | Alvo `~= attacker`, escrita única no `BattleLogStore`, `busy` | `6/6` + regressão self-raid |
| `luau sim/visual-contract.luau` | `minTouch >= 44`, `runner <= 8` partes, replay por `unitId` | `8/8` + prints `375×812` / `720×1280` |
| `luau sim/analytics-contract.luau` | `WallController` emitindo `trap_placed`/`upgrade_bought`/`gold_spent` | `34/34` sem PII |
| `bash scripts/check.sh` | `rojo sourcemap` antes de `luau-lsp` cobrindo client/controllers | `RC=0` |

- **Rollout / rollback:** publicar place após aprovação no QA mobile; rollback = `git revert` do commit P1, sem impacto em DataStores (schema 2 preservado).
- **GAP:** fecha `GAP-014` (pré-teste 3 semanas) e `GAP-017` (QA visual S8 + CI).

---

## 3. RFC-002 — `ProfileSchema v3`, `BattleLog` Estendido & `Core v4` (`GAP-004` & `GAP-016`)

- **Data / responsável:** 13/11/2026 · P2 (bloqueada até autorização)
- **Tipo:** schema + conteúdo + motor
- **Versões:** `schema 2 → 3 · content 2 → 3 · sim 3 → 4`
- **Jogador:** habilita classes/traits horizontais nas armadilhas, slots cosméticos equipados, relatório de entrada *"Muralha Fumegando"* ([`literatura-e-universo.md`](literatura-e-universo.md) §5.2) e expansão `5×5 → 7×5` em ligas altas.
- **Economia:** zero venda de dano; traits são desbloqueados por gameplay/Blueprints; cosméticos `equipped` não alteram `Core.Battle`.
- **Replay:** `BattleLog` sobe para `SCHEMA_VERSION = 2` com `waveSpec`, `attackerEquipped` e `defenderEquipped` fora do hash; `Core v4` recusa replay `simVersion ~= 4`.

### Estrutura Exata do `ProfileSchema v3` (Luau `--!strict`)
```lua
export type Cell = {
	trap: string,
	level: number,
	class: string?, -- default neutro na migracao: "artillery"
	trait: string?, -- default neutro na migracao: "none"
}
export type Equipped = {
	theme: string,     -- default "theme_default"
	hordeSkin: string, -- default "horde_default"
	finisher: string,  -- default "finisher_default"
	commander: string, -- default "cmd_vorn"
}
export type Inbox = {
	unreadDefenses: number, -- default 0
	lastBreachSec: number,  -- default 0
}
-- TOP_FIELDS += { "equipped", "inbox" }; CELL_FIELDS += { "class", "trait" }
-- DEFAULT_CONTENT_VERSION = 3; cellKeyOk exige string.format("r%dc%d", row, col) == key (AUD-10)
```

### Migração `MIGRATIONS[2]` (`v2 -> v3`) e Garantia Neutra (`GAP-010`)
```lua
-- MIGRATIONS[2]: 2 -> 3 (template §6 de pipeline-expansao.md)
-- 1) Preservar gold, wall.gridWidth, wall.activeTrapLimit, league, cosmetics e stats
-- 2) Preencher defaults neutros em toda cell v2: class = "artillery", trait = "none" (100%)
-- 3) Inicializar equipped = { theme="theme_default", hordeSkin="horde_default", finisher="finisher_default", commander="cmd_vorn" }
-- 4) Inicializar inbox = { unreadDefenses = 0, lastBreachSec = 0 }
-- 5) Rodar sanitizeCurrent(copy) + ProfileSchema.validate(profile)
-- 6) Congelar perfil v2 em sim/fixtures/profile-v2.luau e testar ida/volta em sim/profile-contract.luau
MIGRATIONS[2] = function(data: any): any
	local copy = deepCopyTable(data)
	for _, cell in pairs((copy.wall and copy.wall.cells) or {}) do
		if cell.class == nil then cell.class = "artillery" end
		if cell.trait == nil then cell.trait = "none" end
	end
	copy.equipped = copy.equipped or {
		theme = "theme_default", hordeSkin = "horde_default",
		finisher = "finisher_default", commander = "cmd_vorn",
	}
	copy.inbox = copy.inbox or { unreadDefenses = 0, lastBreachSec = 0 }
	copy.schemaVersion = 3
	return copy
end
```
- **Prova neutra obrigatória:** congelar perfil v2 em `sim/fixtures/profile-v2.luau` e atualizar `tools/expansion-test/neutral-migration.luau`; o hash da parede v2 migrada para v3 **deve permanecer `2489780106`** na seed `42` (`artillery` + `trait = "none"` = `100%` dano/cd/alcance).

### Extensão `BattleLog v2` e `Core v4`
- **`BattleLog.luau` (`SCHEMA_VERSION = 2`):**
  ```lua
  export type WaveSpec = { count: number, spawnEveryTicks: number, unitMix: { string }?, mutatorId: string? }
  -- Record v2 adiciona: waveSpec: WaveSpec, attackerEquipped: Equipped, defenderEquipped: Equipped
  -- Invariante: os 3 campos sao metadados visuais/de onda fora do resultHash; isReplayable checa contentVersion
  -- BattleLog.keyFor(battleId): exigir #battleId >= 1 and #battleId <= 50 (limite Roblox DataStore; fecha AUD-10)
  ```
- **`Core.luau` (`SIM_VERSION = 4`):**
  1. **Suporte `GRID_WIDTH` `5..7`:** `Core.WALL_X = 0` (paridade com `GridLayout.WALL_X`), `COLUMN_X = { 2000, 3500, 5000, 6500, 8000, 9500, 11000 }` e `spawnX = gridWidth * 1500 + 2500` (`10000` em 5 cols; `13000` em 7 cols).
  2. **`slowPct` parametrizado e `cd` fiel (`AUD-09`):** remover `55` hardcoded em `Battle:Step` lendo `uSlowPct[i]` gravado a partir de `def.slowPct`; aplicar slow no ramo `if def.splash` quando `def.slowPct ~= nil`; só resetar `trap.cd = def.cd` quando `applyTrap` atingir ao menos 1 alvo.
  3. **Imutabilidade e parada antecipada (`AUD-09`):** aplicar `deepFreeze` recursivo em `UNIT`, `TRAP` e `TUNING`; em `Battle:Finished()`, retornar `true` quando `self.wallHp <= 0 or self.tick >= Core.MAX_TICKS or (self.spawned == self.toSpawn and self.killed + self.leaked >= self.toSpawn)`.
- **Testes:** `invariants.luau` (12/12 + 7×5), `acceptance.luau` (1.000 seeds × 3 re-ancorado), `profile-contract.luau`, `raid-contract.luau`, `neutral-migration.luau` e Modo B real no Studio.
- **Rollout / rollback:** publicar `Core v4` + `ProfileSchema v3` juntos; servidores antigos recusam `schema_future` e `content_future` sem sobrescrever. Rollback = reverter servidor.
- **GAP:** fecha `GAP-004` e `GAP-016`.

---

## 4. RFC-003 — Taxonomia de Analytics v2 (`GAP-008`)

- **Data / responsável:** 13/11/2026 · P2 (bloqueada até autorização)
- **Tipo:** taxonomia / telemetria
- **Versões:** `schema 3 → 3 · content 3 → 3 · sim 4 → 4 · AnalyticsTypes.SCHEMA_VERSION 1 → 2`
- **Jogador / Economia / Replay:** zero impacto em runtime ou hash; habilita funil por classe/trait/raridade, interações sociais e receita líquida por país.

### Especificação de Catálogo (`AnalyticsTypes.luau`)
- **Props opcionais em eventos existentes:**
  - `trap_placed` e `upgrade_bought`: `optional = { prop("class", str(24, "id")), prop("trait", str(24, "id")), prop("rarity", str(24, "id")) }`.
  - `blueprint_earned` (já possui `rarity` obrigatório): `optional = { prop("class", str(24, "id")), prop("trait", str(24, "id")) }`.
- **Novos eventos v2:**
  1. `cosmetic_equipped` (`server_only`): `required = { prop("slot", oneOf({"theme","hordeSkin","finisher","commander"})), prop("cosmetic_id", str(48,"id")) }`, `optional = { prop("rarity", str(24,"id")) }`.
  2. `quickchat_sent` (`CLIENT_EVENTS`): `required = { prop("code", oneOf({"qc_nice_wall","qc_revenge_coming","qc_lane_oops","qc_close_call","qc_your_side","qc_upgrade_now","qc_great_clip","qc_gg_architect"})), prop("context", oneOf({"replay","revenge","coop"})) }`.
  3. `store_purchase` (`server_only`): `required = { prop("offer_id", str(64,"id")), prop("product_type", str(32,"id")), prop("effective_price_robux", int(0,nil)), prop("country_code", str(3,"id")) }`, `optional = { prop("base_price_robux", int(0,nil)) }`. `country_code` é obtido via `pcall(LocalizationService.GetCountryRegionForPlayerAsync, LocalizationService, player)`, normalizado em 2–3 maiúsculas (`"ZZ"` em falha; zero IP/PII).
- **Checklist de migração de contrato (`AnalyticsTypes` + `sim/analytics-contract.luau`):**
  1. Subir `AnalyticsTypes.SCHEMA_VERSION = 2` e registrar os 34 eventos (`31 v1 + 3 v2`) em `CATALOG` + `buildAllowed`.
  2. Incluir `quickchat_sent = true` em `CLIENT_EVENTS` (`AnalyticsService.luau`); manter `cosmetic_equipped` e `store_purchase` estritamente `server_only`.
  3. Validar `country_code` com `maxLen = 3` (`^[A-Z][A-Z0-9]?[A-Z0-9]?$`), recusando qualquer chave da tabela `PII_KEYS` (`ip`, `name`, `user_id`, etc.).
  4. Estender `sim/analytics-contract.luau`: provar que `trap_placed` aceita payload v1 (sem `class`/`trait`/`rarity`) e v2 (com variantes), que `store_purchase` falha via `emitClient`, e que nenhum evento muta `BattleResult`.
  5. Atualizar [`taxonomia-analytics.md`](taxonomia-analytics.md) preservando compatibilidade com eventos v1 no coletor durante a janela de rollout.
- **Rollout / rollback:** coletor externo deve aceitar `schema_version = 1` e `2` durante deploy; rollback = desligar emissão dos 3 eventos novos ou voltar `SCHEMA_VERSION = 1`.
- **GAP:** fecha `GAP-008`.

---

## 5. RFC-004 — Live Ops, Feature Flags & Calendário Sazonal (`GAP-005`)

- **Data / responsável:** 13/11/2026 · P2 (bloqueada até autorização)
- **Tipo:** infraestrutura / evento
- **Versões:** `schema 3 → 3 · content 3 → 3 · sim 4 → 4 · taxonomia 2 → 2` (mutadores de batalha entram em `BattleLog.waveSpec.mutatorId`)
- **Jogador / Economia:** ativa mutadores semanais e kill-switch de trap com bug sem deploy ou restart.

### Arquitetura do `LiveConfigService.luau` (server-only)
1. **Leitura e Cache (`60 s` TTL, *stale-while-revalidate*):** lê `MemoryStoreService:GetHashMap("MuralhaLiveConfig_v1"):GetAsync("active")`; se `now - cachedAt >= 60`, retorna o cache atual imediatamente e agenda refresh assíncrono em `task.spawn`.
2. **Validação JSON pré-troca (atomic swap):** `HttpService:JSONDecode` dentro de `pcall`; só substitui o snapshot ativo após validar o schema:
   ```json
   {
     "schemaVersion": 1,
     "seasonId": 2,
     "disabledTraps": { "catapult": false },
     "weeklyMutator": { "id": "dense_fog", "rangeDelta": -200, "speedPct": 100, "leakScalePct": 100 }
   }
   ```
   Qualquer chave fora do schema ou `trap_id` desconhecido em `TrapCatalog.TRAPS` aborta a troca e preserva o último snapshot válido.
3. **Fallback Offline Determinístico UTC:** quando o HashMap falhar ou estiver vazio, calcula a semana UTC fixa e seleciona da rotação congelada em inteiros (`100` = neutro):
   ```lua
   local weekId = math.floor((os.time() - 1794182400) / 604800)
   local WEEKLY_ROTATION = {
     { id = "standard", rangeDelta = 0, speedPct = 100, leakScalePct = 100 },
     { id = "dense_fog", rangeDelta = -200, speedPct = 100, leakScalePct = 100 },
     { id = "swift_rift", rangeDelta = 0, speedPct = 115, leakScalePct = 100 },
     { id = "heavy_breach", rangeDelta = 0, speedPct = 100, leakScalePct = 120 },
   }
   local mutator = WEEKLY_ROTATION[(weekId % #WEEKLY_ROTATION) + 1]
   ```
4. **Kill-switch de Armadilhas:** `WallService.place` consulta `LiveConfigService.isTrapDisabled(trapId)` e retorna `nil, "trap_disabled"`; células já persistidas permanecem válidas no `Core` e no `BattleLog` para preservar replays antigos.
- **Testes / Rollout / Rollback:** contrato headless com mock de HashMap, JSON malformado e simulação de `weekId`; rollback = limpar `"active"` no HashMap (retorna à rotação UTC em ≤60 s).
- **GAP:** fecha `GAP-005`.

---

## 6. RFC-005 — Sharding `MuralhaPhantom_v2`, `MemoryStoreSortedMap` Sem Colisão & GDPR (`GAP-015`)

- **Data / responsável:** 13/11/2026 · P2 (bloqueada até autorização)
- **Tipo:** persistência / matchmaking / compliance
- **Versões:** `schema 3 → 3 · content 3 → 3 · sim 4 → 4`
- **Jogador / Economia:** elimina throttling na chave global `"latest"` e garante pareamento justo por liga sem expor PII.
- **Correção Crítica sobre [`arquitetura-e-fluxos.md`](arquitetura-e-fluxos.md) §3:** em `MemoryStoreSortedMap` (`"MuralhaMatchPool_v1"`, TTL `86400 s`), o `sortKey` é `points`, mas **a chave do item NUNCA pode ser `points`** porque empates sobrescreveriam entradas. Chave obrigatória sem colisão:
  ```lua
  local mapKey = string.format("%08d_%d", math.clamp(points, 0, 99999999), userId)
  ```
- **Sharding (`MuralhaPhantom_v2`):**
  - 32 shards por liga (`L<1..7>_S<01..32>`, ligas definidas em [`skills-tiers-e-modos.md`](skills-tiers-e-modos.md) §2.2).
  - **Payload sanitizado (`PhantomEntry`, máx. 16 entradas/shard):**
    ```lua
    export type PhantomEntry = {
      ownerHash: string, points: number, hp: number, gridWidth: number,
      contentVersion: number, traps: { { cell: string, type: string, level: number, class: string?, trait: string? } },
      defenderEquipped: Equipped, updatedAt: number,
    }
    ```
  - **Escrita:** publica no shard `(hash32(userId) % 32) + 1` (cooldown mínimo `60 s` por jogador).
  - **Leitura:** consulta `MemoryStoreSortedMap:GetRangeAsync` na janela `[points - 150, points + 150]` ou lê **2 shards aleatórios** da liga do atacante filtrando `entry.ownerHash ~= attackerHash`; se vazio ou *throttled*, usa **bot determinístico por liga**.
- **PII & Runbook GDPR (*Right-to-Erasure*):**
  1. **Zero `ownerName`:** remover `ownerName` do payload do fantasma e do `BattleLog` (UI mostra Comandante + `Arquiteto #<4 hex de ownerHash>`).
  2. **Tagging obrigatório:** manter `session:AddUserId(player.UserId)` no `ProfileStore` e gravar `MuralhaPhantom_v2` / `MuralhaBattleLog_v1` com `{ player.UserId }` e `DataStoreSetOptions:SetMetadata({ league = league, schema = 2 })`.
  3. **Execução de Exclusão (`Right-to-Erasure(userId)`):** (a) `ProfileStore:RemoveAsync("User_" .. userId)` em `MuralhaProfile_v1`; (b) calcular `shard = string.format("L%d_S%02d", league, (hash32(userId) % 32) + 1)` e evictar entradas com `ownerHash == hash32(userId)` via `UpdateAsync`; (c) remover `string.format("%08d_%d", *, userId)` do `MemoryStoreSortedMap`.
- **Rollout / Rollback:** operar `MuralhaPhantom_v2` em shadow write antes de virar a leitura; rollback = flag `usePhantomV2 = false` com fallback determinístico de bot.
- **GAP:** fecha `GAP-015`.

---

## 7. RFC-006 — Precificação Regional Dinâmica & Auditoria Creator Analytics (`GAP-013`)

- **Data / responsável:** 13/11/2026 · pré-abertura de loja P2
- **Tipo:** monetização / analytics operacional
- **Versões:** `schema 3 → 3 · content 3 → 3 · sim 4 → 4 · taxonomia 2 → 2`
- **Jogador / Economia:** aplica Roblox Managed Regional Pricing (piso `30%`, teto `100%` do preço nominal) sem vender poder e elimina discrepância entre UI e checkout.

### Regras Obrigatórias de Runtime & Auditoria
1. **Consulta dinâmica obrigatória (nunca hardcodar Robux):**
   ```lua
   local ok, info = pcall(MarketplaceService.GetProductInfo, MarketplaceService, productId, infoType)
   local displayRobux = if ok and type(info) == "table" and info.PriceInRobux then info.PriceInRobux else nil
   ```
   Toda vitrine/botão exibe `displayRobux` em runtime e oculta compra caso `displayRobux == nil`.
2. **Telemetria de preço efetivo:** no `ProcessReceipt` / confirmação server-side, emitir `store_purchase` (RFC-003) com `effective_price_robux = receiptInfo.CurrencySpent`, `base_price_robux` e `country_code` (`<= 3` chars).
3. **Checklist Creator Analytics (Gate pré-loja P2):**
   - Habilitar *Managed Regional Pricing* nos passes/SKUs cosméticos iniciais.
   - Exportar *Sales Data* (CSV) no Creator Dashboard e segmentar **4 macrorregiões** (`US+CA`, `EU`, `APAC`, `ROW/BR`).
   - Calcular por região: `ARPPU = Revenue / PayingUsers`, `Conversão = PayingUsers / DAU`, `AOV = Revenue / Transactions` e `ARPDAU líquido` (validando gate `>= US$ 0,005` de [`decisao-monetizacao.md`](decisao-monetizacao.md), ponderando DevEx 18+ EUA `US$ 0,0054/R$` vs base `US$ 0,0038/R$`).
   - Executar teste controlado em 3 faixas (`30%`, `60%`, `100%`) em 1 SKU cosmético antes da abertura completa da loja P2 ([`pesquisa-monetizacao-regional.md`](pesquisa-monetizacao-regional.md) §7.3).
- **Rollout / rollback:** desativar Regional Pricing no Creator Dashboard restaura `100%` do preço nominal imediatamente sem deploy.
- **GAP:** fecha `GAP-013`.

---

## 8. RFC-007 — Co-op Síncrono Lockstep, Campanha Solo/Duo & Bosses (`GAP-018`)

- **Data / responsável:** 13/11/2026 · V1.5/P2+ (desbloqueado pelo diretor em `.context/REJEITADOS.md`)
- **Tipo:** modo de jogo + netcode autoritativo + extensão do motor (`Core v4/v5`)
- **Especificação detalhada:** [`campanha-bosses-e-coop-sincrono.md`](campanha-bosses-e-coop-sincrono.md)
- **Resumo técnico:**
  1. **Campanha *Crônicas do Bastião*:** 5 Atos × 5 estágios (`X-1..X-5`), jogáveis Solo, Duo Assíncrono ou Duo Síncrono, com `CampaignStageSpec`, escalonamento 100% inteiro (`MILLI=1000`, `speed <= 2400`), selos `starsMask (1|2|4)` e 8 mutadores determinísticos.
  2. **Bosses multi-lane no `Core`:** `laneCenter` + `laneSpan=3`, deduplicação de AoE por `shotId`, máquina inteira `MARCH -> TELEGRAPH 40t -> ABILITY -> VULNERABLE 30t (+30%) -> ENRAGE <40%` e barra de `staggerMilli`.
  3. **Co-op Síncrono Lockstep (`20 Hz`):** `TeleportService:ReserveServer` via `MemoryStoreHashMap` (`TTL 120s`), grade Setor A (`r1–r2`) / Portão (`r3`) / Setor B (`r4–r5`, `N=8`), fila `CoopCommandRemote` agendada em `currentTick + 2`, cursor `UnreliableRemoteEvent` `10 Hz` (`6 bytes`) e `BattleLog v2` gravando `commands[]` para preservar `resultHash` no Clipe de 8s.
  4. **Anti-Leaver 3 camadas:** reserva de reconexão `90s` (`MuralhaRejoin_v1`), comando `PARTNER_OFFLINE` em `10s` transferindo células/ouro e re-escalonamento inteiro das ondas seguintes (`1750 → 1000` milli).
- **Verificação / Rollback:** contrato headless de lockstep/desync (`0` divergências em 1.000 runs com `commands[]` aleatórios) + feature flag `LiveConfig.flags.syncCoopEnabled`; re-congela se divergência `> 0,1%` ou abandono líquido `> 25%`.
- **GAP:** fecha `GAP-018`.

---

## 9. RFC-008 — Soundscape/OST Adaptativa, Animações 60 Hz & Física Real Híbrida (`GAP-019`)

- **Data / responsável:** 13/11/2026 · Camada client na S8.2 (sem bump) · Camada `F1` no `Core v4+`
- **Tipo:** apresentação audiovisual + solver físico isolado + telemetria física (`StepEvents`)
- **Especificação detalhada:** [`audio-musica-e-soundscape.md`](audio-musica-e-soundscape.md) · [`animacoes-fisica-real-e-vfx.md`](animacoes-fisica-real-e-vfx.md)
- **Resumo técnico:**
  1. **Áudio (`AudioMixer`):** hierarquia sob `MuralhaMaster` (`CompressorSoundEffect`) mantendo `MuralhaSFX` (`sim/visual-contract.luau` 8/8 preservado) + `BGM_Bus` (4 stems verticais travados por `TimePosition` + 5 temas horizontais + ducking `-4,5 dB`), 36 cues SFX 3D em pool de 24 `Attachments` e normalização `-14 LUFS`.
  2. **Animações 60 Hz & VFX:** máquinas `Deploy Pop → Idle → Wind-up → Fire/Recoil → Reload → Upgrade` e overlays de horda/Boss dentro de `VisualTheme.BUDGETS` (`<=40` partículas, `<=500` draw calls).
  3. **Física Real Híbrida:** `Camada F1` (`uImpulseX`/`StepEvents` no `Core`) + `Camada F2` (clones cliente com `BallSocketConstraint` ragdoll, shatter cristalino e fratura do portão em 12 blocos aos `0%`) isolados em `CollisionGroups` `RagdollBody`/`FractureDebris` com `CanQuery = false` e `CanTouch = false`, sob governor adaptativo (`Low <=6`, `Mid <=18`, `High <=36`, downgrade se `FPS < 48` por `2s`).
- **Verificação / Rollback:** `sim/visual-contract.luau` + soak mobile `375×812` (`FPS >= 60`); kill-switch client `physicsTier = "Low"` desabilita ragdoll se p10 `< 45 FPS`.
- **GAP:** fecha `GAP-019`.

---

## 10. RFC-009 — Sistemas Comerciais de Jogo Completo, `ProcessReceipt` & `PolicyService` (`GAP-020`)

- **Data / responsável:** 13/11/2026 · P2+ comercial (aguarda autorização do diretor)
- **Tipo:** schema `v4` + economia/loja compliance + UX multiplataforma + Live-Ops
- **Especificação detalhada:** [`sistemas-jogo-completo.md`](sistemas-jogo-completo.md)
- **Resumo técnico:**
  1. **Progressão & Pós-Partida:** `ftueStep 0..6` (Primeiros 30 min), `TrapCombatReport` por célula (DPS Meter + selo MVP + Diagnóstico Automático de Derrota), Contratos Diários/Semanais determinísticos, Passe Cosmético ético, Login Streak com *Grace Freeze* e 12 Conquistas `BadgeService`.
  2. **Social & Acessibilidade:** Códigos Base32 de Blueprint (`MRL-XXXX`), Ordens (`<=30` membros), 4 Leaderboards `OrderedDataStore`, `ProfileSettings` persistentes (3 sliders de áudio, tier físico, 3 modos de daltonismo, mapeamento Mobile/PC/Console Gamepad e `LocalizationTable` PT-BR/EN-US/ES-LATAM).
  3. **Segurança & Operação:** `MarketplaceService.ProcessReceipt` idempotente com ledger `processedReceipts[100]` salvo no `ProfileStore` antes de `PurchaseGranted`, guardas `PolicyService:GetPolicyInfoForPlayerAsync`, `BindToClose`/Drain migratório e comandos Staff `/inspect`, `/toggle_flag`, `/drain_server`.
- **Verificação / Rollback:** suíte de contrato para `ProcessReceipt` duplicado, `PolicyService` restrito e migração neutra de `ProfileSchema v4`; rollback via `LiveConfig` mantendo `ProfileStore` retrocompatível.
- **GAP:** fecha `GAP-020`.
