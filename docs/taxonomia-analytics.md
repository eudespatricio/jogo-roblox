# Taxonomia de analytics v1

> **Status:** **v1 aprovada e implementada em 09/11/2026** (fechamento da P0). O contrato
> executável é `src/shared/analytics/AnalyticsTypes.luau`, validado no CI por
> `sim/analytics-contract.luau`; o sink é P1.
> Não escolhe fornecedor: define nomes, envelope, funil, métricas e regras de emissão.
> Fontes: [spec do motor](spec-motor-deterministico.md) §8, [GDD](gdd-muralha.md) §8,
> [revisão de direção](revisao-direcao.md) §7, [padrões](padroes-engenharia.md) §3 e §8.3.

---

## 0. Decisões propostas

1. **Nomes** em `snake_case`, no padrão `<domínio>_<objeto>_<ação>`. Os nomes já citados na spec §8
   (`session_start`, `dropin_shown`, `first_win`, `raid_start`, `purchase_complete`…) ficam canônicos.
2. **Envelope obrigatório** (§1) em todo evento; campo ausente = evento inválido.
3. **Servidor é a fonte** dos eventos de jogo. Cliente só emite eventos de UI, com rate limit.
4. **`schema_version = 1`**; mudanças só aditivas. Renomear = evento novo + depreciação.
5. **Sink do MVP/teste:** `AnalyticsService` para os funis da plataforma + DataStore em lote para o
   detalhe. Sink externo só na P2, quando o volume justificar.
6. **Sem PII:** nada de nome, chat, idade exata, IP ou device ID. `player_id` é hash com salt do lugar.
7. **Batalha:** eventos carregam `battle_id`, `seed`, `sim_version` e `result_hash`; analytics **nunca**
   entra no hash nem no estado da simulação.
8. **Retenção:** 90 dias de evento bruto no sink próprio; agregados por 13 meses. Exportar e apagar.

---

## 1. Envelope comum

| Campo | Tipo | Obrigatório | Regra |
|---|---|---|---|
| `event_id` | string (UUID v4) | sim | idempotência no ingest |
| `event_name` | string (enum §2) | sim | nome canônico |
| `schema_version` | int | sim | começa em `1` |
| `ts` | int (ms UTC) | sim | relógio do **servidor**; cliente não define métrica |
| `session_id` | string | sim | UUID por sessão; não identifica o jogador |
| `player_id` | string | sim | hash keyed de `UserId + salt` (algoritmo a definir); salt por lugar |
| `place_version` | string | sim | versão publicada do lugar |
| `platform` | enum `mobile`/`pc`/`console`/`vr` | sim | — |
| `device_tier` | enum `low`/`mid`/`high` | sim | derivado de memória/GPU, não do modelo |
| `locale` | string (`pt-BR`, `en-US`…) | sim | — |
| `is_age_checked` | bool | sim | só o booleano; nunca data de nascimento |
| `experiment` | string? | não | ex.: `q2_grid=5x5`, `dropin=button` |
| `server_id` | string | sim | hash do JobId; para diagnostico |
| `client_ts` | int? | não | só para latência; não substitui `ts` |

Campos de batalha (quando aplicável): `battle_id`, `seed`, `sim_version`, `result_hash`.
Limites: `event_name` ≤ 48 chars, `player_id` = 32 hex, `experiment` ≤ 64, strings livres ≤ 256.
O validador rejeita campo desconhecido, PII e string acima do limite.

---

## 2. Catálogo de eventos

### 2.1 Sessão e funil

| Evento | Quando | Propriedades obrigatórias |
|---|---|---|
| `session_start` | primeiro join da sessão | `days_since_last_seen`, `is_returning` |
| `session_end` | leave/crash reconciliado | `duration_s`, `reason` (`leave`/`crash`/`timeout`) |
| `dropin_shown` | cena de abertura montada | `ms_since_join` |
| `dropin_pressed` | toque no botão DEFENDER | `ms_since_join`, `pressed` (bool) |
| `first_win` | primeira vitória do jogador | `seconds_since_join`, `battle_id` |
| `build_complete` | saída da fase de build | `traps_placed`, `time_s` |
| `raid_start` | raid assistida começa | `battle_id`, `mode`, `speed` |
| `raid_end` | raid termina | `battle_id`, `result`, `duration_s` |
| `replay_started` | replay de vingança abre | `battle_id`, `replay_length_s` |
| `replay_watched` | replay fecha | `battle_id`, `watched_s`, `pct` (0–1) |
| `clip_saved` | `PromptSaveCapturesToGallery` conclui | `battle_id` |

### 2.2 Batalha e determinismo

| Evento | Quando | Propriedades obrigatórias |
|---|---|---|
| `battle_started` | servidor inicia a simulação | `battle_id`, `seed`, `sim_version`, `grid_width`, `traps_count` |
| `battle_finished` | hash calculado | `battle_id`, `seed`, `sim_version`, `result_hash`, `winner`, `wall_hp`, `leaked`, `ticks`, `duration_ms` |
| `battle_divergence` | replay não bate o hash | `battle_id`, `expected_hash`, `actual_hash` |

Regra: `battle_finished` é emitido **depois** do hash; o evento não pode alterar o resultado. O motor
devolve um `BattleResult` imutável e o servidor emite — nada de sink dentro de `src/shared/sim/core.luau`.

### 2.3 Economia e progressão

| Evento | Quando | Propriedades obrigatórias |
|---|---|---|
| `gold_earned` | recompensa creditada | `amount`, `source` (`raid`/`defense`/`daily`), `battle_id?` |
| `gold_spent` | gasto confirmado | `amount`, `sink` (`trap`/`upgrade`/`repair`) |
| `trap_placed` | armadilha posicionada | `trap_id`, `cell`, `cost` |
| `upgrade_bought` | upgrade confirmado | `target`, `level`, `cost` |
| `league_changed` | elo muda | `from`, `to`, `delta` |
| `blueprint_earned` | blueprint creditado | `blueprint_id`, `rarity`, `source` |

### 2.4 Monetização

| Evento | Quando | Propriedades obrigatórias |
|---|---|---|
| `offer_shown` | oferta visível | `offer_id`, `price_robux`, `placement` |
| `purchase_start` | `PromptProductPurchase`/`PromptGamePassPurchase` | `offer_id`, `price_robux` |
| `purchase_complete` | recibo validado no servidor | `offer_id`, `price_robux`, `product_type` |
| `purchase_failed` | recibo inválido/cancelado | `offer_id`, `reason` |
| `age_check_prompt` | `PromptAgeCheck` chamado | `origin` (`reward`/`store`/`settings`) |
| `age_check_result` | callback | `result` (`verified`/`declined`/`unavailable`) |

### 2.5 Teste de 3 semanas (§7)

| Evento | Quando | Propriedades obrigatórias |
|---|---|---|
| `test_offer_choice` | pergunta "qual você compraria?" | `offer_id`, `choice` (bool), `reason_code` |
| `test_survey_answer` | resposta codificada pelo pesquisador | `question_id`, `answer_code` |

`reason_code` e `answer_code` são enums fechados (ex.: `colecao`, `ranking`, `revanche`, `preco`,
`nao_jogaria`). Texto livre não vai para o analytics; fica na planilha de playtest.

### 2.6 Qualidade

| Evento | Quando | Propriedades obrigatórias |
|---|---|---|
| `client_error` | erro no cliente | `code`, `context_hash` |
| `server_error` | erro no servidor | `code`, `context_hash` |
| `perf_sample` | 1×/min, amostrado | `fps_p50`, `fps_p95`, `memory_mb`, `sample_window_s` |

---

## 3. Funil e métricas

**Funil canônico:** `session_start → dropin_shown → dropin_pressed → first_win → build_complete →
raid_start → raid_end → replay_watched`.

| Métrica | Fórmula | Uso |
|---|---|---|
| `first_win_seconds` | `first_win.ts − session_start.ts` | gate 70% < 60s |
| `bounce_180s` | sessões com `duration_s < 180` ÷ sessões | gate ≤ 40% |
| `D1` / `D7` | coorte do dia 0 que volta no dia +1/+7 (UTC, via `lastSeenAt`) | gates 15% / 3% |
| `session_length` | `session_end.ts − session_start.ts`, cap 2h | gate ≥ 8 min |
| `replay_rate` | retornos com `replay_watched.pct ≥ 0,5` ÷ retornos | gate ≥ 50% |
| `clip_rate` | `clip_saved` ÷ sessões | gate ≥ 5/100 |
| `payer_conversion_30d` | pagantes únicos em 30 dias ÷ MAU | gate ≥ 2% |
| `ARPPU` | receita líquida ÷ pagantes | premissa de monetização |
| `ARPDAU_gross` | Robux gasto ÷ DAU ÷ dias | reportar sempre |
| `ARPDAU_net` | USD líquido ÷ DAU ÷ dias | **gate principal** |
| `offer_choice_rate` | jogadores que escolhem oferta ÷ jogadores expostos | teste §7 |
| `understanding` | respostas corretas ÷ respondentes (codificado) | teste §7 |

D1/D7 usam **dia UTC** e `lastSeenAt` do servidor; sessão que cruza meia-noite conta no dia de início.
`bounce` é independente de vitória; `first_win` é por jogador, não por sessão.

---

## 4. Regras de emissão

1. **Servidor autoritativo.** `purchase_complete`, `battle_finished`, `gold_earned` só saem após
   validação server-side. Evento de cliente é sinal de UI, nunca fonte de recompensa.
2. **Rate limit de cliente:** 10 eventos/min por jogador; excedente é descartado e conta em
   `client_error(code=rate_limited)`.
3. **Lote:** flush a cada 30s ou 100 eventos; flush no `PlayerRemoving`; best effort.
4. **Nunca bloquear gameplay:** falha de sink é logada e o buffer local (máx. 500) é descartado do
   mais antigo para o mais novo.
5. **Idempotência:** `event_id` único; `battle_id` único por batalha; ingest deduplica.
6. **Amostragem:** `perf_sample` 1/min por servidor; o resto 100%.
7. **Teto:** 200 eventos/sessão; acima disso, só funil e monetização.
8. **Relógio:** `ts` do servidor; `client_ts` só para medir latência de UI.
9. **Sem PII:** validador rejeita campos proibidos; `context_hash` é hash, não mensagem.

---

## 5. Sink, volume e escala

| Fase | Sink | Por quê |
|---|---|---|
| MVP/teste (300–500 jogadores) | `AnalyticsService` + DataStore em lote | barato, sem infra; exportar com `rbxcloud` e apagar |
| P2 (25 mil DAU) | sink externo via `HttpService` | DataStore não é banco analítico: 4 MB/chave e cooldown de escrita |
| P3+ | warehouse (BigQuery/Postgres/ClickHouse) + schema registry | consulta, coorte e dashboard |

Ordem de grandeza: ~40 eventos/sessão × 1,56 sessões/dia × 25 mil DAU ≈ **1,5 milhão de
eventos/dia** — inviável em DataStore. O DataStore serve ao teste, não à operação.

**Privacidade:** salt por lugar, rotação anual; retenção 90 dias bruto; exportação agregada;
nada de texto livre; `PolicyService`/idade só como booleano.

---

## 6. Implementação (P0)

| Artefato | Papel | Status (09/11/2026) |
|---|---|---|
| `src/shared/analytics/AnalyticsTypes.luau` | envelope, catálogo tipado, enums, limites, anti-PII, `newEvent`/batalha | **feito** |
| `sim/analytics-contract.luau` | validador headless: campos, enums, limites, PII, integração com o motor | **feito** |
| `src/server/analytics/AnalyticsService.luau` | `emit`, sinks, lote, rate limit, idempotência | **P1** (não entra na P0) |
| `src/shared/sim/core.luau` | motor v2 (5×5/N=5); `BattleResult` carrega `seed`, `simVersion` e `hash` | **feito** |
| CI | `check.sh` roda o contrato junto dos invariantes; hash `2489780106` e `sim_version 2` obrigatórios | **feito** |

Teste de aceitação: 1.000 batalhas com hash estável **e** todos os eventos de batalha validados;
nenhum evento altera `result_hash`; sink `Null` não quebra o fluxo.

---

## 7. Lacunas e decisões abertas

1. **Atribuição dos 3 criativos.** Anúncio do Roblox não carrega ID do criativo no join. Opções:
   3 lugares/experiências separados, campanhas sequenciais, ou `launchData` em links de compartilhar.
   Decidir **antes da semana 2** do teste.
2. **Limites do `AnalyticsService`** (nomes, campos, volume) precisam ser conferidos na doc oficial
   antes do sink (P1). O contrato v1 não depende da API: ele valida no servidor e entrega o
   evento pronto — o sink só decide para onde mandar.
3. **DataStore como sink** só vale para o teste; a decisão do sink externo é da P2.
4. **Feature flags/experimentos** continuam abertos em [padrões](padroes-engenharia.md) §8.3.
5. **Nomes congelados na v1** (09/11/2026): renomear evento quebra série histórica; mudança só
   aditiva, com novo `schema_version` e evento antigo depreciado.
