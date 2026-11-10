# ESTADO — jogo-roblox

> Regra: este arquivo é **sobrescrito**, nunca append-only. Teto: 80 linhas. Atualizado: 10/11/2026.

## O que é
**MURALHA**: tower defense invertido + autobattler assíncrono, mobile-first, sem avatar visível
(habilita DevEx 18+ e corta custo de arte). Público 13–34, monetização cosmética.

## Fase
**P1 em execução (autorizada em 09/11/2026).** S1–S3.4 fechadas (Modo B 8/8); **S4 fechada**
(FPS 60/60); **S5 fechada** (drop-in/+3 ouro); **S6.1 fechada** (fantasma real + replay 3D); **S7
fechada** (telemetria com sink persistente); **S8 fechada** (apresentação visual: diorama, traps/
horda 3D e UI). A saída da P1 (70% de primeira vitória <60 s) está instrumentada por
`first_win_seconds`; a série persiste e será medida no teste de 3 semanas. P2 bloqueada.

## Números atuais (10/11/2026)
| Métrica | Valor |
|---|---|
| tick / cap | 0,05s · 1.200 ticks (60s) |
| estado | 100% inteiro (MILLI = 1000) |
| custo por batalha | ~1,4 ms (~710 batalhas/s) |
| determinismo | hash `2489780106` (seed 42, 3 execuções) · `simVersion 3` |
| acceptance P1 | 1.000 seeds × 3 · 1.000 hashes · 68,7% defensor · 1,4s/1.000 |
| invariantes | 12/12 (`sim/invariants.luau`) |
| contratos | perfil 20/20 · analytics 34/34 · muralha 13/13 · conteúdo 7/7 · build 14/14 · visual 8/8 · drop-in 8/8 · raid 6/6 |
| versões | schema 2 · content 2 · sim 3 · hash `2489780106` (`docs/versoes.md`, gate no `check.sh`) |
| perfil | schema v2 · `contentVersion` · store `MuralhaProfile_v1` · migração 0→2/1→2 com fixtures |
| analytics | contrato v1 · 31 eventos · envelope + anti-PII · serviço S7 (lote 30s/100, 10/min) · sink DataStore/Memory |
| teste de sessão | Modo A 8/8 + Modo B schema v1 8/8 (09/11) · Modo B schema v2 8/8 (10/11) |

## Pronto

- Conceito aprovado: `docs/gdd-muralha.md` v1.1 (decisões 1–5; Q2 na decisão 1).
- Economia: `docs/modelo-financeiro.xlsx` + `docs/tese-produto-e-economia.md`.
- Evidência: `docs/pesquisa-tendencias-2026.md`, `docs/pesquisa-jogadores.md`,
  `docs/pesquisa-grade-e-prototipo.md`.
- Engenharia: `docs/padroes-engenharia.md`; S4/S5 fechadas; S6.1 fantasma real + replay 3D (6/6).
- Motor: `src/shared/sim/core.luau` (v3, loadout 5×5/N=5, 5 tipos) + harnesses em `sim/`.
- Muralha: `TrapCatalog.luau` (5 tipos, aliases) + `WallService.luau` (`toBattleWall`) +
  `sim/walls-contract.luau`/`content-contract.luau` (13/13 e 7/7); custos em `docs/economia-muralha.md`.
- Dados: `ProfileSchema.luau` (v2/contentVersion) + `ProfileService.luau` +
  `ProfileBoot.server.luau` (migração de conteúdo) + `sim/profile-contract.luau` (20/20); Modo B
  schema v2 8/8 em 10/11/2026 (`docs/teste-sessao-studio.md` §9).
- Analytics: `AnalyticsTypes.luau` + `AnalyticsService.luau` + `AnalyticsDataStoreSink.luau` +
  `AnalyticsBoot.server.luau` (emit/lote/rate limit/idempotência; DataStore/Memory) + contrato 34/34;
  `first_win_seconds` em `docs/teste-s7-studio.md`.
- Visual S8: `VisualTheme.luau` + `ArenaVisual`/`TrapKit`/`HordeKit`/`Vfx`/`AudioKit`/`UiKit` (diorama,
  5 traps, 3 silhuetas, UI de cartões) + `sim/visual-contract.luau` (8/8); QA em `docs/teste-s8-studio.md`.
- Tooling: Rokit + CLI/GUI; CI ativo; doctor; gate de versões (`docs/versoes.md`); ProfileStore vendorizado.
- Monetização: base 2% × US$ 2; topo 4,5% × US$ 5; gate ARPDAU líquido US$ 0,005.
- Contexto: `skills/context-recovery/` (protocolo de auditoria portátil).
- Trial S3.2: classe/trait/raridade executado e revertido; kit inclui `neutral-migration.luau` (GAP-010).

## Não pronto

- **P1**: falta medir a saída (70% de primeira vitória <60s) no teste de 3 semanas; instrumento e
  série persistida prontos. Fora: liga/meta/loja (P2), co-op (P3), 7×5.
- P2 bloqueada; GAP-004/005/008 abertos; ver `docs/gaps.md`.
- Teste de produto de 3 semanas: roda em paralelo (decisão do diretor em 09/11/2026).

## Congelado

- Decisões do GDD: 5×5 → 7×5 por nível; cercos livres + 3 Grandes Saques; derrota só perde liga;
  `A MURALHA` / `WALLBREAKER`; co-op na P3.
- Servidor autoritativo + replay por seed + `simVersion`; hash só muda com `simVersion` novo.
- Regras dos jogadores: nenhuma unidade obrigatória; poder só por gameplay; sem loot box.
- Schema v2 (com `contentVersion`) + taxonomia v1: mudança só aditiva, com migração/`schema_version`.

## Próximo passo

1. Rodar o teste de 3 semanas com o sink persistente e medir a saída da P1 (70% <60s).
2. P2 não começa sem autorização.

## Como verificar o estado em 1 minuto

```bash
source scripts/env.sh
bash scripts/doctor.sh     # estação completa
bash scripts/check.sh      # build, StyLua, luau-lsp, versões, invariantes, contratos, contexto
```
