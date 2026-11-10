# QA da S7 no Studio — telemetria

> **Status:** **S7 fechada em 10/11/2026.** O `AnalyticsService` monta o envelope v1, valida 100%
> dos eventos, faz lote (30 s/100), rate limit de cliente (10/min), idempotência por `event_id` e
> entrega ao sink persistente (`DataStore` em produção, `Memory` no Studio; `Null` por override);
> `AnalyticsBoot` liga a sessão ao perfil e `first_win_seconds` é medido. O contrato está em
> **34/34**. **GAP-012 fechado:** a série persiste para o teste de 3 semanas; a taxa de 70% é medida
> lá, não aqui. Sem mudança de schema/conteúdo/simulação; a única mudança de contrato é **aditiva**:
> `battle_started.traps_count` passou a aceitar `0` (muralha vazia), estado que o motor já produz.

**Base:** `main` pós-S7 · schema 2 · content 2 · `simVersion 3` · hash `2489780106`.
Critérios do plano: [`p1-plano.md`](p1-plano.md) S7 — contrato v1 valida 100% dos eventos; nenhum
evento altera `BattleResult`; sem PII.

---

## 1. Pré-condições

1. No WSL: `source scripts/env.sh && bash scripts/doctor.sh && bash scripts/check.sh` (RC=0).
2. `rojo build default.project.json -o build/place.rbxl` e abrir o lugar no Studio.
3. `ServerStorage.ProfileStoreMock = true` (default do Studio).
4. `ProfileSelfTest = false` (o selftest encerra a sessão e atrapalha o drop-in).
5. **Sink:** produção usa `DataStore` (`MuralhaAnalytics_v1`); Studio usa `Memory`. Para forçar,
   `ServerStorage.AnalyticsSink = "DataStore" | "Memory" | "Null"`.
6. Para o QA de ouro/armadilha, use o grant da S4 (`QaStarterGold`/`QaLeaguePoints`) ou jogue a
   raid da S6; o grant não é necessário para a telemetria.

## 2. Logs esperados

```text
[analytics] servico pronto sink=Memory name=- flush=30s/100 rate=10/min debug=true  # Studio; producao=DataStore
[analytics] sessao iniciada returning=false sink=Memory (player_id hash32)
[analytics] session_start days_since_last_seen=-1 is_returning=false
[analytics] dropin_shown ms_since_join=...
[analytics] dropin_pressed ms_since_join=... pressed=true
[analytics] battle_started battle_id=... grid_width=5 seed=4 sim_version=3 traps_count=5
[analytics] battle_finished battle_id=... duration_ms=5000 result_hash=... winner=defender ...
[analytics] first_win seconds_since_join=... battle_id=...
[analytics] gold_earned amount=3 source=defense
[analytics] lote reason=size n=... 
[analytics] lote reason=leave n=...
[analytics] session_end duration_s=... reason=leave
[analytics] first_win_seconds novas=1 ganhos=1 <60s=1 taxa=100.0% p50=... p95=... (amostra deste servidor; sink persistente)
```

- `session_start` sai quando o perfil carrega; `dropin_shown`/`dropin_pressed` já vão com envelope
  (o log `[analytics]` mostra só as props; `player_id`/`session_id` não aparecem no Output).
- O lote sai a cada 30 s, a cada 100 eventos e no leave; `reason=size`, `interval`, `leave` ou
  `shutdown`.
- Em produção (`AnalyticsDebug=false`) o sink persiste sem imprimir cada evento; as linhas de sessão
  e o relatório de `first_win_seconds` continuam.

## 3. Contrato headless (prova principal)

```bash
luau sim/analytics-contract.luau   # 34 checagens, 0 falhas
```

Cobre:

- os **31 eventos** do catálogo passam por `AnalyticsService` e pelo sink (100% validados);
- lote de 100 e flush por 30 s (`tick`);
- rate limit 10/min + `client_error(code=rate_limited)` uma vez por janela; evento de servidor via
  `emitClient` é recusado (`server_only`);
- idempotência: o mesmo `event_id` não chega duas vezes ao sink; props não sobrescrevem campos do
  envelope (`ts`/`event_id`/`session_id`);
- teto de 200/sessão: funil/monetização passam, economia é recusada;
- `session_end` no leave com `duration_s` e flush;
- `first_win` uma vez por sessão e `first_win_seconds = first_win.ts − session_start.ts`;
- coorte **sintética** de 10 jogadores novos: 7/10 = 70% <60 s, gate `0.70` (prova da aritmética;
  **não** é medição de produto);
- `player_id` é hash32 com salt, PII é recusada e o `BattleResult`/hash não mudam;
- serviço sem boot devolve `not_started` sem quebrar o fluxo.

## 4. `first_win_seconds` no Studio

1. Execute o drop-in normal e aperte **DEFENDER**.
2. O `battle_started`/`battle_finished` saem no press; no clear (`ONDA LIMPA`) sai `first_win` com
   `seconds_since_join` (tipicamente ~5–8 s no fluxo roteirizado).
3. Ao sair do Play, o servidor imprime o relatório `first_win_seconds` **deste servidor**. Com um
   jogador novo, a amostra é `novas=1`; a taxa de 100% dessa amostra não é o gate.
4. No fluxo roteirizado, o clear acontece `DropInState.CLEAR_MS = 1,5 s` após o press e o press
   válido vai até `PRESS_DEADLINE_MS = 10 s`; o `first_win_seconds` do fluxo fica em ~≤11,5 s, bem
   abaixo de 60 s. O que decide o gate é a fração de **jogadores novos** que aperta DEFENDER e vence,
   medida no teste de 3 semanas.
5. O gate da P1 é `70%` de jogadores **novos** (`is_returning=false`) com `first_win < 60 s`, medido
   no teste de 3 semanas sobre uma série persistida no DataStore. O sink Null continua como override de
   QA, mas o default de produção é persistente; a série é exportada do DataStore.

## 5. Privacidade e determinismo

- `player_id` é `hash32` de `UserId` com salt do lugar; `server_id` é hash do `JobId`; nunca há
  nome, `UserId` cru, chat, IP ou device id no envelope.
- O validador recusa PII antes de qualquer campo e o sink valida o lote de novo.
- Analytics é emitido **depois** do hash e não recebe o `BattleResult` mutável; o contrato compara
  o resultado antes/depois dos eventos.
- O cliente só pode emitir a whitelist de UI (`client_error`, `clip_saved`, `offer_shown`,
  `purchase_start`, `replay_started`, `replay_watched`); confirmações de compra/batalha são do
  servidor.

## 6. Evidência headless (10/11/2026)

```bash
source scripts/env.sh
bash scripts/doctor.sh        # RC=0
bash scripts/check.sh         # RC=0; contrato de analytics 34/34
luau sim/analytics-contract.luau
rojo build default.project.json -o build/place.rbxl
```

- `doctor.sh`: estação completa (RC=0).
- `check.sh`: build, StyLua, luau-lsp (inclui `AnalyticsService.luau`), invariantes, acceptance e
  contratos verdes; contexto 80/60/40 respeitado.
- Saída do contrato: `[analytics] P1 coorte sintetica: 7/10 = 70% <60s (gate 70%); nao e medicao de
  produto` e `34 checagens, 0 falhas`.
- **Veredito:** S7 fechada em 10/11/2026 como feature/instrumentação. A saída da P1 continua
  pendente do teste de 3 semanas; GAP-012 registra a persistência necessária.

## 7. Fora do scaffold (não inventar)

- O sink da S7 é `DataStore`/`Memory`; `Null` continua como override de QA. Sink externo/warehouse
  continua fora do escopo (P2).
- P2/live ops, classe/taxonomia v2 e mudanças de schema/content/sim não começam aqui.
- Atribuição fina de `platform`/`device_tier` ainda é default do servidor (`pc` no Studio, `mobile`
  em produção) ou atributo de QA (`MuralhaPlatform`/`MuralhaDeviceTier`); o refinamento é do sink/
  P2, sem PII.

## 8. Sink persistente e export (GAP-012 fechado)

- **Store:** `MuralhaAnalytics_v1` (`AnalyticsDataStoreSink`), separado de perfil/BattleLog.
- **Chave:** `A_<event_id do primeiro evento do lote>`; retry do mesmo lote reescreve a mesma chave.
- **Valor:** `{ version = 1, writtenAt = ms, events = { ... } }`; lote máximo de 100 eventos.
- **Modos:** `DataStore` em produção; `Memory` no Studio; `Null` por `ServerStorage.AnalyticsSink`.
- **Export:** usar `rbxcloud`/DataStore API para listar `A_*` e baixar JSON; retenção bruta de 90
  dias, agregados de 13 meses (taxonomia §0/§5). O contrato headless cobre gravação, idempotência,
  lote inválido, chunk e integração com o `AnalyticsService` (**34/34**).
