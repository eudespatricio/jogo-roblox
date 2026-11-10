# ESTADO — jogo-roblox

> Regra: este arquivo é **sobrescrito**, nunca append-only. Teto: 80 linhas. Atualizado: 09/11/2026.

## O que é

**MURALHA**: tower defense invertido + autobattler assíncrono, mobile-first, sem avatar visível
(habilita DevEx 18+ e corta custo de arte). Público 13–34, monetização cosmética.

## Fase

**P1 em execução (autorizada em 09/11/2026).** S1 fechada (legado apagado, tag `legacy-coins`),
S2 fechada (motor 5×5/N=5, `simVersion 2`) e S3 fechada (muralha/economia server-side). Próxima
fatia: S4 (cena 5×5 + build). Plano em `docs/p1-plano.md`; teste de 3 semanas em paralelo.

## Números atuais (09/11/2026)

| Métrica | Valor |
|---|---|
| tick / cap | 0,05s · 1.200 ticks (60s) |
| estado | 100% inteiro (MILLI = 1000) |
| custo por batalha | ~1,4 ms (~710 batalhas/s) |
| determinismo | hash `2489780106` (seed 42, 3 execuções) · `simVersion 2` |
| acceptance P1 | 1.000 seeds × 3 · 1.000 hashes · 68,7% defensor · 1,4s/1.000 |
| invariantes | 12/12 (`sim/invariants.luau`) |
| contratos | perfil 19/19 · analytics 16/16 · muralha 12/12 (`sim/*-contract.luau`) |
| perfil | schema v1 · store `MuralhaProfile_v1` · migração 0→1 com fixture |
| analytics | contrato v1 · 31 eventos · envelope + anti-PII |
| teste de sessão | Modo A (Mock) 8/8 + Modo B (DataStore real) 8/8 · 09/11/2026 |

## Pronto

- Conceito aprovado: `docs/gdd-muralha.md` v1.1 (decisões 1–5; Q2 na decisão 1).
- Economia: `docs/modelo-financeiro.xlsx` + `docs/tese-produto-e-economia.md`.
- Evidência: `docs/pesquisa-tendencias-2026.md`, `docs/pesquisa-jogadores.md`,
  `docs/pesquisa-grade-e-prototipo.md`.
- Engenharia: `docs/padroes-engenharia.md` (regras com fonte oficial).
- Motor: `src/shared/sim/core.luau` (v2, loadout 5×5/N=5) + harnesses em `sim/`.
- Muralha: `src/shared/data/TrapCatalog.luau` + `src/server/walls/WallService.luau` +
  `sim/walls-contract.luau` (S3); custos/desbloqueio em `docs/economia-muralha.md`.
- Dados: `src/shared/data/ProfileSchema.luau` + `src/server/data/ProfileService.luau` +
  `src/server/ProfileBoot.server.luau` + `sim/profile-contract.luau`.
- Analytics: `src/shared/analytics/AnalyticsTypes.luau` + `sim/analytics-contract.luau`;
  taxonomia v1 aprovada (`docs/taxonomia-analytics.md`).
- Tooling: Rokit + CLI/GUI; CI ativo; doctor; ProfileStore vendorizado.
- Monetização: base 2% × US$ 2; topo 4,5% × US$ 5; gate ARPDAU líquido US$ 0,005.
- Contexto: `skills/context-recovery/` (protocolo de auditoria portátil).

## Não pronto

- **P1** (2–3 semanas): S4 cena 5×5/build → S5 drop-in → S6 raid/replay → S7 telemetria. Saída:
  70% de primeira vitória < 60s. Fora: liga/meta/loja (P2), co-op (P3), 7×5.
- Cena, UI e loja ainda não existem; o sink `AnalyticsService` é S7.
- Teste de produto de 3 semanas: roda em paralelo (decisão do diretor em 09/11/2026).

## Congelado

- Decisões do GDD: 5×5 → 7×5 por nível; cercos livres + 3 Grandes Saques; derrota só perde liga;
  `A MURALHA` / `WALLBREAKER`; co-op na P3.
- Servidor autoritativo + replay por seed + `simVersion`; hash só muda com `simVersion` novo.
- Regras dos jogadores: nenhuma unidade obrigatória; poder só por gameplay; sem loot box.
- Schema v1 + taxonomia v1: mudança só aditiva, com migração/`schema_version`.

## Próximo passo

1. S4: cena 5×5 no Workspace, câmera fixa e UI de build (colocar 5 em 25) — `docs/p1-plano.md`.
2. S5–S7: drop-in, raid/replay e telemetria.

## Como verificar o estado em 1 minuto

```bash
source scripts/env.sh
bash scripts/doctor.sh     # estação completa
bash scripts/check.sh      # build, StyLua, luau-lsp, invariantes, acceptance, contratos, contexto
```
