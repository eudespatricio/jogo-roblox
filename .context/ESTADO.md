# ESTADO — jogo-roblox

> Regra: este arquivo é **sobrescrito**, nunca append-only. Teto: 80 linhas. Atualizado: 09/11/2026.

## O que é

**MURALHA**: tower defense invertido + autobattler assíncrono, mobile-first, sem avatar visível
(habilita DevEx 18+ e corta custo de arte). Público 13–34, monetização cosmética.

## Fase

**P0 em andamento.** Motor determinístico portado para `src/shared/sim/` e aceito (1.000 seeds × 3);
nenhuma cena, UI ou loja. O protótipo de moedas em `src/` segue legado.

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
| docs / código / testes | 14 docs · 11 arquivos · 3 oráculos |

## Pronto

- Conceito aprovado: `docs/gdd-muralha.md` v1.1 (decisões 1–5 fechadas; Q2 incluída na decisão 1).
- Economia: `docs/modelo-financeiro.xlsx` + `docs/tese-produto-e-economia.md`.
- Evidência: `docs/pesquisa-tendencias-2026.md`, `docs/pesquisa-jogadores.md`, `docs/pesquisa-grade-e-prototipo.md`.
- Engenharia: `docs/padroes-engenharia.md` (regras com fonte oficial).
- Motor: `src/shared/sim/core.luau` (produção) + `sim/poc.luau` (benchmark) + `sim/invariants.luau`
  (oráculo) + `sim/acceptance.luau` (P0: 1.000 seeds × 3).
- Tooling: Rokit + CLI/GUI; CI ativo; estação calibrada (doctor); ProfileStore vendorizado
  (wrapper/schema na P0).
- Monetização: base 2% × US$ 2; topo 4,5% × US$ 5; gate ARPDAU líquido US$ 0,005 — `docs/decisao-monetizacao.md`.
- Contexto: `skills/context-recovery/` (protocolo de auditoria portátil).

## Não pronto

- P0 em andamento: faltam schema v1 + ProfileStore, contrato de analytics e teste de sessão no Studio.
- `src/` ainda tem o protótipo de moedas; `src/shared/sim/` já é produção.
- Q1 aguarda decisão (apagar o legado na P1); Q2 fechada — `docs/gdd-muralha.md` decisão 1.
- Revisão de direção: teste de produto de 3 semanas antes da P1 — `docs/revisao-direcao.md`.
- Analytics: taxonomia v1 escrita; instrumentação no motor é P0 — `docs/taxonomia-analytics.md`.
- Ferramentas: estação completa (doctor), CI verde, `.luaurc` strict e calibração Blender; ProfileStore vendorizado; `pesde.toml` adiado — `docs/estacao-de-trabalho.md`.
- Sem cena de Studio, sem UI, sem DataStore, sem loja implementada.

## Congelado

- Decisões do GDD: 5×5 → 7×5 por nível; cercos livres + 3 Grandes Saques; derrota só perde liga;
  `A MURALHA` / `WALLBREAKER`; co-op na P3.
- Servidor autoritativo + replay por seed + `simVersion`.
- Regras dos jogadores: nenhuma unidade obrigatória; poder só por gameplay; sem loot box.

## Próximo passo

Concluir a P0: schema v1 + ProfileStore, contrato de analytics e teste de sessão no Studio. Em
paralelo, o teste de produto de 3 semanas continua antes da P1.

## Como verificar o estado em 1 minuto

```bash
source scripts/env.sh
bash scripts/doctor.sh     # estação completa
bash scripts/check.sh      # build, StyLua, luau-lsp, invariantes, P0 acceptance, contexto
```
