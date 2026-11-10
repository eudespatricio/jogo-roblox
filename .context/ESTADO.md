# ESTADO — jogo-roblox

> Regra: este arquivo é **sobrescrito**, nunca append-only. Teto: 80 linhas. Atualizado: 09/11/2026.

## O que é

**MURALHA**: tower defense invertido + autobattler assíncrono, mobile-first, sem avatar visível
(habilita DevEx 18+ e corta custo de arte). Público 13–34, monetização cosmética.

## Fase

**P1 autorizada (09/11/2026) para a próxima janela.** P0 fechada: motor, schema v1 + ProfileStore,
contrato de analytics e teste de sessão no Studio (Modos A e B, 8/8). O primeiro item é a **Q1**
(apagar o legado de moedas, tag `legacy-coins`); plano em `docs/p1-plano.md`.

## Números atuais (09/11/2026)

| Métrica | Valor |
|---|---|
| tick / cap | 0,05s · 1.200 ticks (60s) |
| estado | 100% inteiro (MILLI = 1000) |
| custo por batalha | ~1,5 ms (~650 batalhas/s) |
| determinismo | hash `668061367` (seed 42, 3 execuções) — muda na S2 (`simVersion 2`) |
| P0 acceptance | 1.000 seeds × 3 · 1.000 hashes · 64,9% defensor · 1,5s/1.000 |
| invariantes | 10/10 passando (`sim/invariants.luau`) |
| contratos P0 | perfil 19/19 · analytics 16/16 (`sim/*-contract.luau`) |
| perfil | schema v1 · store `MuralhaProfile_v1` · migração 0→1 com fixture |
| analytics | contrato v1 · 31 eventos · envelope + anti-PII |
| teste de sessão | Modo A (Mock) 8/8 + Modo B (DataStore real) 8/8 · 09/11/2026 |

## Pronto

- Conceito aprovado: `docs/gdd-muralha.md` v1.1 (decisões 1–5; Q2 na decisão 1).
- Economia: `docs/modelo-financeiro.xlsx` + `docs/tese-produto-e-economia.md`.
- Evidência: `docs/pesquisa-tendencias-2026.md`, `docs/pesquisa-jogadores.md`,
  `docs/pesquisa-grade-e-prototipo.md`.
- Engenharia: `docs/padroes-engenharia.md` (regras com fonte oficial).
- Motor: `src/shared/sim/core.luau` + `sim/poc.luau` + `sim/invariants.luau` + `sim/acceptance.luau`.
- Dados: `src/shared/data/ProfileSchema.luau` + `src/server/data/ProfileService.luau` +
  `src/server/ProfileBoot.server.luau` + `sim/profile-contract.luau`.
- Analytics: `src/shared/analytics/AnalyticsTypes.luau` + `sim/analytics-contract.luau`;
  taxonomia v1 aprovada (`docs/taxonomia-analytics.md`).
- Tooling: Rokit + CLI/GUI; CI ativo (run #14 verde); doctor; ProfileStore vendorizado.
- Monetização: base 2% × US$ 2; topo 4,5% × US$ 5; gate ARPDAU líquido US$ 0,005.
- Contexto: `skills/context-recovery/` (protocolo de auditoria portátil).

## Não pronto

- **P1** (2–3 semanas): Q1 → cena 5×5, build, drop-in, raid, replay. Saída: 70% de primeira vitória
  < 60s. Fora: liga/meta/loja (P2), co-op (P3), 7×5.
- O motor atual é o recorte do PoC (1 armadilha por lane, tipo sorteado): loadout 5×5/N=5 é mudança
  de matemática → `simVersion 2` + hash novo (fatia S2 do plano).
- `src/` ainda tem o protótipo de moedas (Q1 apaga); sink `AnalyticsService` é P1.
- Sem cena, sem UI, sem loja. Teste de produto de 3 semanas: recomendado, roda em paralelo (decisão
  do diretor em 09/11/2026).

## Congelado

- Decisões do GDD: 5×5 → 7×5 por nível; cercos livres + 3 Grandes Saques; derrota só perde liga;
  `A MURALHA` / `WALLBREAKER`; co-op na P3.
- Servidor autoritativo + replay por seed + `simVersion`; hash só muda com `simVersion` novo.
- Regras dos jogadores: nenhuma unidade obrigatória; poder só por gameplay; sem loot box.
- Schema v1 + taxonomia v1: mudança só aditiva, com migração/`schema_version`.

## Próximo passo

1. S1/Q1: tag `legacy-coins`, apagar `CoinService`/`DataService`/`Main`/`Config`/`Hud`, stub e CI.
2. S2: motor com loadout 5×5/N=5 → `simVersion 2`, re-ancorar invariants/acceptance/spec.
3. S3–S7: muralha/economia, cena+build, drop-in, raid/replay, telemetria (`docs/p1-plano.md`).

## Como verificar o estado em 1 minuto

```bash
source scripts/env.sh
bash scripts/doctor.sh     # estação completa
bash scripts/check.sh      # build, StyLua, luau-lsp, invariantes, acceptance, contratos, contexto
```
