# ESTADO — jogo-roblox

> Regra: este arquivo é **sobrescrito**, nunca append-only. Teto: 80 linhas. Atualizado: 09/11/2026.

## O que é

**MURALHA**: tower defense invertido + autobattler assíncrono, mobile-first, sem avatar visível
(habilita DevEx 18+ e corta custo de arte). Público 13–34, monetização cosmética.

## Fase

**P0 fechada em código (09/11/2026).** Falta só o teste de sessão no Studio — roteiro pronto em
`docs/teste-sessao-studio.md`. P1 não autorizada. O protótipo de moedas em `src/` segue legado.

## Números atuais (09/11/2026)

| Métrica | Valor |
|---|---|
| tick / cap | 0,05s · 1.200 ticks (60s) |
| estado | 100% inteiro (MILLI = 1000) |
| custo por batalha | ~1,5 ms (~650 batalhas/s) |
| determinismo | hash `668061367` (seed 42, 3 execuções) |
| 500 seeds | 500 hashes distintos · 64,8% vitória do defensor |
| P0 acceptance | 1.000 seeds × 3 · 1.000 hashes · 64,9% defensor · 1,5s/1.000 |
| invariantes | 10/10 passando (`sim/invariants.luau`) |
| contratos P0 | perfil 19/19 · analytics 16/16 (`sim/*-contract.luau`) |
| perfil | schema v1 · store `MuralhaProfile_v1` · migração 0→1 com fixture |
| analytics | contrato v1 · 31 eventos · envelope + anti-PII |
| docs / código | 15 .md + xlsx · 18 módulos Luau · 5 oráculos |

## Pronto

- Conceito aprovado: `docs/gdd-muralha.md` v1.1 (decisões 1–5; Q2 na decisão 1).
- Economia: `docs/modelo-financeiro.xlsx` + `docs/tese-produto-e-economia.md`.
- Evidência: `docs/pesquisa-tendencias-2026.md`, `docs/pesquisa-jogadores.md`,
  `docs/pesquisa-grade-e-prototipo.md`.
- Engenharia: `docs/padroes-engenharia.md` (regras com fonte oficial).
- Motor: `src/shared/sim/core.luau` + `sim/poc.luau` + `sim/invariants.luau` + `sim/acceptance.luau`.
- Dados: `src/shared/data/ProfileSchema.luau` (schema v1) + `src/server/data/ProfileService.luau`
  (sessão, store injetado) + `src/server/ProfileBoot.server.luau` + `sim/profile-contract.luau`.
- Analytics: `src/shared/analytics/AnalyticsTypes.luau` + `sim/analytics-contract.luau`;
  taxonomia v1 aprovada (`docs/taxonomia-analytics.md`).
- Tooling: Rokit + CLI/GUI; CI ativo; estação calibrada (doctor); ProfileStore vendorizado.
- Monetização: base 2% × US$ 2; topo 4,5% × US$ 5; gate ARPDAU líquido US$ 0,005.
- Contexto: `skills/context-recovery/` (protocolo de auditoria portátil).

## Não pronto

- Teste de sessão no Studio (manual, último item da P0): `docs/teste-sessao-studio.md`.
- `src/` ainda tem o protótipo de moedas; `src/shared/sim/` já é produção. Q1 = apagar na P1
  (tag `legacy-coins`, stub, CI), preservando `src/shared/sim/`.
- Revisão de direção: teste de produto de 3 semanas antes da P1 — `docs/revisao-direcao.md`.
- Analytics: falta o sink (`AnalyticsService`) e a instrumentação de gameplay — P1.
- Sem cena, sem UI, sem loja; DataStore real só no teste manual do Studio.

## Congelado

- Decisões do GDD: 5×5 → 7×5 por nível; cercos livres + 3 Grandes Saques; derrota só perde liga;
  `A MURALHA` / `WALLBREAKER`; co-op na P3.
- Servidor autoritativo + replay por seed + `simVersion` (segue 1; sem mudança de matemática).
- Regras dos jogadores: nenhuma unidade obrigatória; poder só por gameplay; sem loot box.
- Schema v1 + taxonomia v1: mudança só aditiva, com migração/`schema_version`.

## Próximo passo

1. Rodar `docs/teste-sessao-studio.md` (Modo A Mock; Modo B opcional) e colar a evidência.
2. Só depois: autorização para a P1; o teste de produto de 3 semanas continua antes dela.

## Como verificar o estado em 1 minuto

```bash
source scripts/env.sh
bash scripts/doctor.sh     # estação completa
bash scripts/check.sh      # build, StyLua, luau-lsp, invariantes, acceptance, contratos, contexto
```
