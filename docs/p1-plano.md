# P1 — plano de execução

> **Status:** **autorizado pelo diretor em 09/11/2026** para a janela seguinte. A P0 fechou no mesmo
> dia: motor determinístico, schema v1 + wrapper ProfileStore, contrato de analytics e teste de
> sessão nos Modos A (Mock) e B (DataStore real), 8/8 nas duas execuções.
> Este plano é o contrato da fase: ordem, critério de pronto por fatia e o que **não** entra.
> **Execução (09/11/2026):** S1 e S2 fechadas; `simVersion = 2`, hash de referência
> `2489780106` (seed 42). S3 é a próxima fatia; S4–S7 pendentes.

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
| S3 | **Muralha e economia** | `src/server/walls/` (colocar/remover/upgrade com validação server-side: célula, N=5, ouro, desbloqueio) persistindo em `Profile.Data.wall.cells` / `gold` | célula inválida, 6ª armadilha e ouro insuficiente recusados; eventos `trap_placed`/`gold_spent`/`gold_earned` válidos |
| S4 | **Cena 5×5 + build** | grid 5×5 no Workspace, câmera fixa, UI de build (colocar 5 em 25) | build completo em ≤ 30 s; nenhuma armadilha fora da célula; 45+ FPS em mobile |
| S5 | **Drop-in de 5 s** | cena de abertura com botão DEFENDER e derrota roteirizada se demorar | `dropin_shown`/`dropin_pressed` no funil; `dropin_pressed` ≥ 60% |
| S6 | **Raid assíncrona + replay** | batalha contra fantasma, `BattleLog` (store separado, 1 chave por `battle_id`), replay por seed de 8 s | `battle_finished.result_hash` igual ao replay; recompensa idempotente por `battle_id`; divergência vira `battle_divergence` |
| S7 | **Telemetria** | `src/server/analytics/AnalyticsService.luau`: `emit`, lote (30 s/100), rate limit de cliente (10/min), idempotência, sink `Null` | contrato v1 valida 100% dos eventos; nenhum evento altera `BattleResult`; sem PII |

Regras de sequência:

- **S1 antes de tudo** — o legado ocupava `src/` e confundia a árvore; a tag preserva a referência.
- **S2 antes de S3–S6** — sem loadout não há o que colocar nem raid que use a muralha do jogador.
- S7 pode nascer junto de S5 (o funil é o instrumento do critério de saída), mas não substitui S6.

## 3. Decisões herdadas (não reabrir)

Q2 = 5×5, N=5, colocação livre · Q1 = apagar o legado com tag `legacy-coins` · store do perfil =
`MuralhaProfile_v1` (schema v1, migração 0→1) · taxonomia v1 congelada (`schema_version = 1`) ·
ProfileStore vendorizado, server-only, sem editar · monetização base 2% × US$ 2, gate ARPDAU líquido
US$ 0,005 · servidor autoritativo + replay por seed.

## 4. Riscos e armadilhas

1. **O motor da P0 era o recorte do PoC** — a S2 trocou por loadout por célula (5×5/N=5), com
   `simVersion 2` e hash `2489780106`. Não "ajustar" o hash antigo (`668061367`) nem thresholds
   sem registro; replay v1 é recusado.
2. **Analytics fora do hash**: `battle_finished` é montado do `BattleResult` **depois** do hash;
   `sim_version` do evento acompanha o motor.
3. **Idempotência de recompensa** por `battle_id` (chave do `BattleLog`); cliente nunca decide
   recompensa.
4. **Perf mobile**: pool de 150 modelos, LOD billboard; nunca reduzir a lógica.
5. **ProfileStore**: `EndSession` no leave, `StartSessionAsync` pode ser nil, migração só aditiva.
6. **Contexto residente tem teto** (80/60/40): atualizar ESTADO/MAPA sem estourar; ESTADO está
   próximo do limite — enxugar antes de acrescentar.

## 5. Fora da P1

Liga/meta/loja (P2), co-op (P3), grade 7×5, chat, segundo mapa, chefes, temporada paga, UGC de
blueprint, física real de ragdoll.

## 6. Teste de produto de 3 semanas

A [revisão de direção](revisao-direcao.md) recomendou o teste **antes** da P1. O diretor decidiu
seguir com a P1 em 09/11/2026; o teste continua recomendado e pode rodar em paralelo. Se reprovar, a
P1 para e o escopo é revisto — motor e camada de dados continuam válidos para qualquer versão.
