# P1 — plano de execução

> **Status:** **autorizado pelo diretor em 09/11/2026** para a janela seguinte. A P0 fechou no mesmo
> dia: motor determinístico, schema v1 + wrapper ProfileStore, contrato de analytics e teste de
> sessão nos Modos A (Mock) e B (DataStore real), 8/8 nas duas execuções.
> Este plano é o contrato da fase: ordem, critério de pronto por fatia e o que **não** entra.
> **Execução (10/11/2026):** S1–S3.3 fechadas; **S3.4 (conteúdo e versões) fechada** — schema 2,
> content 2, `simVersion 3`, hash `2489780106` (seed 42), Modo B real 8/8; GAP-001/002/003/009/010
> fechados. **S4 fechada** em 10/11/2026 (QA headless + runtime: FPS 60/60, Play→UI 1,9 s,
> prints 375×812/720×1280); S5 fechada; S6 iniciada (raid/BattleLog/replay; QA pendente);
> S7 pendente.
> **GAP:** GAP-004/005/008 — classe/taxonomia v2 e P2; GAP-011 fechado no `BattleLog` da S6.
> Ver [`gaps.md`](gaps.md) e [`pipeline-expansao.md`](pipeline-expansao.md).
> **Trial S3.2:** classe/trait/raridade executado e revertido; relatório em
> [`expansion-test-2026-11-10.md`](expansion-test-2026-11-10.md).

---

## 1. Objetivo e critério de saída

Do GDD §10: a P1 entrega **drop-in, build, raid e replay** em 2–3 semanas, com critério de saída
**70% de primeira vitória em menos de 60 s** ([`gdd-muralha.md`](gdd-muralha.md) §9–§10).

Como medir: `first_win_seconds = first_win.ts − session_start.ts` por jogador novo, com a telemetria
da S7 (contrato v1 já validado no CI). Sem número, a fase não fecha.

## 2. Ordem de trabalho (fatias)

| # | Fatia | Entrega | Critério de pronto |
|---|---|---|---|
| S1 | **Q1 — apagar o legado** | tag anotada `legacy-coins` **antes** de qualquer deleção; remover `src/server/{CoinService,DataService,Main}`, `src/shared/Config.luau`, `src/client/Hud.client.luau`; stub de 10 linhas no lugar do `Main` (o lugar continua construindo); `.styluaignore` sem `src/` | `check.sh` + CI verdes; `src/shared/{sim,data,analytics}` e `src/server/{data,ProfileBoot.server}` intactos; README/MAPA/REJEITADOS/ESTADO atualizados |
| S2 | **Motor com loadout 5×5/N=5** | `Battle.new({ seed, simVersion, wall, wave })` com armadilhas por célula (N=5 ativas, colocação livre nas 25), 5 lanes; `Core.Run(seed)` continua como atalho de loadout padrão para os harnesses | `simVersion` = **2** e registrada na spec; hash de referência novo; `sim/invariants.luau` e `sim/acceptance.luau` re-ancorados (1.000 seeds × 3 estáveis); `sim/analytics-contract.luau` continua verde |
| S3 | **Muralha e economia** — **feito 09/11/2026** | `src/shared/data/TrapCatalog.luau` + `src/server/walls/WallService.luau` (colocar/remover/upgrade com validação server-side: célula, N=5, ouro, desbloqueio; perfil incompatível é recusado); custos em [`economia-muralha.md`](economia-muralha.md), persistindo em `Profile.Data.wall.cells` / `gold` | célula inválida, 6ª armadilha e ouro insuficiente recusados; eventos `trap_placed`/`gold_spent`/`gold_earned` válidos — **12/12 na S3** (13/13 após a S3.3) |
| S3.3 | **Gaps antes da S4** — **feito 10/11/2026** | `WallService.toBattleWall` (valida/ordena) + `scripts/check-versions.py`/`docs/versoes.md` | helper 13/13; gate falha na divergência; GAP-010 preparado |
| S3.4 | **Conteúdo e versões** — **feito 10/11/2026** | `contentVersion` no schema v2, `oil → tar`, `catapult` (5º tipo), `SIM_VERSION 3`, migração neutra e Modo B | contratos 20/13/7/6; GAP-001/002/003/009/010 fechados; Modo B schema v2 8/8 |
| S4 | **Cena 5×5 + build** — **feito 10/11/2026** | grid 5×5 no Workspace, câmera fixa, UI de build (colocar 5 em 25), HUD de FPS/tempos, layout 375×812/720×1280; `GridLayout`/`BuildProtocol`/`BuildClientState`/`BuildHud`/`BuildLayout`/`BuildGrid`/`WallController`/`BuildClient`; QA em [`teste-s4-studio.md`](teste-s4-studio.md) | build ≤30 s; nenhuma armadilha fora da célula; 45+ FPS; evidência §7 (FPS 60/60, Play→UI 1,9 s) |
| S5 | **Drop-in de 5 s** — **feito 10/11/2026** | cena de abertura com DEFENDER, derrota roteirizada e retry; `DropInState`/`DropInController`/`DropInClient`/`sim/dropin-contract.luau`; +3 ouro no clear; QA em [`teste-s5-studio.md`](teste-s5-studio.md) | `dropin_shown`/`dropin_pressed` no funil; `dropin_pressed` ≥ 60% no teste de produto |
| S6 | **Raid assíncrona + replay** — **S6.1 fechada em 10/11/2026 (fantasma real + replay 3D)** | batalha contra fantasma, `BattleLog` (store separado, 1 chave por `battle_id`, `contentVersion`), replay por seed de 8 s; `BattleLog`/`RaidReplay`/`RaidController`/`RaidClient`; QA em [`teste-s6-studio.md`](teste-s6-studio.md) | `battle_finished.result_hash` igual ao replay; recompensa idempotente por `battle_id`; divergência vira `battle_divergence`; GAP-011 fechado |
| S7 | **Telemetria** | `src/server/analytics/AnalyticsService.luau`: `emit`, lote (30 s/100), rate limit de cliente (10/min), idempotência, sink `Null` | contrato v1 valida 100% dos eventos; nenhum evento altera `BattleResult`; sem PII |

Regras de sequência:

- **S1 antes de tudo** — o legado ocupava `src/` e confundia a árvore; a tag preserva a referência.
- **S2 antes de S3–S6** — sem loadout não há o que colocar nem raid que use a muralha do jogador.
- S7 pode nascer junto de S5 (o funil é o instrumento do critério de saída), mas não substitui S6.

## 3. Decisões herdadas (não reabrir)

Q2 = 5×5, N=5, colocação livre · Q1 = apagar o legado com tag `legacy-coins` · store do perfil =
`MuralhaProfile_v1` (schema v2 com `contentVersion`, migração 0→2/1→2) · taxonomia v1 congelada (`schema_version = 1`) ·
ProfileStore vendorizado, server-only, sem editar · monetização base 2% × US$ 2, gate ARPDAU líquido
US$ 0,005 · servidor autoritativo + replay por seed.

## 4. Riscos e armadilhas

1. **O motor da P0 era o recorte do PoC** — a S2 trocou por loadout por célula (5×5/N=5), com
   `simVersion 2`; a S3.4 subiu para `simVersion 3` (5º tipo) e manteve o hash `2489780106`. Não
   "ajustar" o hash antigo (`668061367`) nem thresholds sem registro; replay v1/v2 é recusado.
2. **Analytics fora do hash**: `battle_finished` é montado do `BattleResult` **depois** do hash;
   `sim_version` do evento acompanha o motor.
3. **Idempotência de recompensa** por `battle_id` (chave do `BattleLog`); cliente nunca decide
   recompensa.
4. **Perf mobile**: pool de 150 modelos, LOD billboard; nunca reduzir a lógica.
5. **ProfileStore**: `EndSession` no leave, `StartSessionAsync` pode ser nil, migração só aditiva.
6. **Contexto residente tem teto** (80/60/40): atualizar ESTADO/MAPA sem estourar; ESTADO está
   próximo do limite — enxugar antes de acrescentar.
7. **Economia da S3** — remover não devolve ouro (taxonomia v1 não tem source de refund); custos
   e desbloqueio em [`economia-muralha.md`](economia-muralha.md). Não inventar `gold_earned` com
   source fora do enum.

## 5. Fora da P1

Liga/meta/loja (P2), co-op (P3), grade 7×5, chat, segundo mapa, chefes, temporada paga, UGC de
blueprint, física real de ragdoll.

## 6. Teste de produto de 3 semanas

A [revisão de direção](revisao-direcao.md) recomendou o teste **antes** da P1. O diretor decidiu
seguir com a P1 em 09/11/2026; o teste continua recomendado e pode rodar em paralelo. Se reprovar, a
P1 para e o escopo é revisto — motor e camada de dados continuam válidos para qualquer versão.

## 7. Expansão (conteúdo e features)

Toda expansão segue [`pipeline-expansao.md`](pipeline-expansao.md) (versões, matriz de decisão, RFC,
migração e rollback). Cada P/S fecha com uma linha `GAP:`; gaps abertos ficam em
[`gaps.md`](gaps.md), cada um com gatilho objetivo.
