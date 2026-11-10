# ESTADO — jogo-roblox

> Regra: este arquivo é **sobrescrito**, nunca append-only. Teto: 80 linhas. Atualizado: 10/11/2026.

## O que é

**MURALHA**: tower defense invertido + autobattler assíncrono, mobile-first, sem avatar visível
(habilita DevEx 18+ e corta custo de arte). Público 13–34, monetização cosmética.

## Fase

**P1 em execução (autorizada em 09/11/2026).** S1–S3.3 fechadas; **S3.4 com código verde e GAP-009
pendente no Studio**; **S4 iniciada** (cena 5×5/UI de build, scaffold sem validação no Studio). Plano
em `docs/p1-plano.md`, teste de 3 semanas em paralelo.

## Números atuais (10/11/2026)

| Métrica | Valor |
|---|---|
| tick / cap | 0,05s · 1.200 ticks (60s) |
| estado | 100% inteiro (MILLI = 1000) |
| custo por batalha | ~1,4 ms (~710 batalhas/s) |
| determinismo | hash `2489780106` (seed 42, 3 execuções) · `simVersion 3` |
| acceptance P1 | 1.000 seeds × 3 · 1.000 hashes · 68,7% defensor · 1,4s/1.000 |
| invariantes | 12/12 (`sim/invariants.luau`) |
| contratos | perfil 20/20 · analytics 16/16 · muralha 13/13 · conteúdo 7/7 · build 6/6 |
| versões | schema 2 · content 2 · sim 3 · hash `2489780106` (`docs/versoes.md`, gate no `check.sh`) |
| perfil | schema v2 · `contentVersion` · store `MuralhaProfile_v1` · migração 0→2/1→2 com fixtures |
| analytics | contrato v1 · 31 eventos · envelope + anti-PII |
| teste de sessão | Modo A (Mock) 8/8 + Modo B (DataStore real) 8/8 · 09/11/2026 |

## Pronto

- Conceito aprovado: `docs/gdd-muralha.md` v1.1 (decisões 1–5; Q2 na decisão 1).
- Economia: `docs/modelo-financeiro.xlsx` + `docs/tese-produto-e-economia.md`.
- Evidência: `docs/pesquisa-tendencias-2026.md`, `docs/pesquisa-jogadores.md`,
  `docs/pesquisa-grade-e-prototipo.md`.
- Engenharia: `docs/padroes-engenharia.md` (regras com fonte oficial).
- Motor: `src/shared/sim/core.luau` (v3, loadout 5×5/N=5, 5 tipos) + harnesses em `sim/`.
- Muralha: `TrapCatalog.luau` (5 tipos, aliases) + `WallService.luau` (`toBattleWall`) +
  `sim/walls-contract.luau`/`content-contract.luau` (13/13 e 7/7); custos em `docs/economia-muralha.md`.
- Dados: `ProfileSchema.luau` (v2/contentVersion) + `ProfileService.luau` +
  `ProfileBoot.server.luau` (migração de conteúdo) + `sim/profile-contract.luau` (20/20).
- Analytics: `src/shared/analytics/AnalyticsTypes.luau` + `sim/analytics-contract.luau`;
  taxonomia v1 aprovada (`docs/taxonomia-analytics.md`).
- Tooling: Rokit + CLI/GUI; CI ativo; doctor; gate de versões (`docs/versoes.md`); ProfileStore vendorizado.
- Monetização: base 2% × US$ 2; topo 4,5% × US$ 5; gate ARPDAU líquido US$ 0,005.
- Contexto: `skills/context-recovery/` (protocolo de auditoria portátil).
- Trial S3.2: classe/trait/raridade executado e revertido; kit inclui `neutral-migration.luau` (GAP-010).

## Não pronto

- **P1** (2–3 semanas): S4 cena 5×5/build em andamento → S5 drop-in → S6 raid/replay → S7 telemetria.
  Saída: 70% de primeira vitória < 60s. Fora: liga/meta/loja (P2), co-op (P3), 7×5.
- S4: cena/UI/remote scaffold prontos; falta validar no Studio (FPS mobile, build ≤30s, feel).
  O sink `AnalyticsService` é S7.
- GAPs abertos: GAP-004/005/008/009/011 (001/002/003/010 fechados; 009 depende do Modo B); ver `docs/gaps.md`.
- Teste de produto de 3 semanas: roda em paralelo (decisão do diretor em 09/11/2026).

## Congelado

- Decisões do GDD: 5×5 → 7×5 por nível; cercos livres + 3 Grandes Saques; derrota só perde liga;
  `A MURALHA` / `WALLBREAKER`; co-op na P3.
- Servidor autoritativo + replay por seed + `simVersion`; hash só muda com `simVersion` novo.
- Regras dos jogadores: nenhuma unidade obrigatória; poder só por gameplay; sem loot box.
- Schema v1 + taxonomia v1: mudança só aditiva, com migração/`schema_version`.

## Próximo passo

1. GAP-009: rodar o Modo B do schema v2 no Studio e registrar a evidência.
2. S4: validar cena/UI no Studio; depois S5–S7 (`docs/p1-plano.md`); GAP-011 entra na S6.

## Como verificar o estado em 1 minuto

```bash
source scripts/env.sh
bash scripts/doctor.sh     # estação completa
bash scripts/check.sh      # build, StyLua, luau-lsp, versões, invariantes, contratos, contexto
```
