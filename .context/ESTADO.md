# ESTADO — jogo-roblox

> Regra: este arquivo é **sobrescrito**, nunca append-only. Teto: 80 linhas. Atualizado: 09/11/2026.

## O que é

**MURALHA**: tower defense invertido + autobattler assíncrono, mobile-first, sem avatar visível
(habilita DevEx 18+ e corta custo de arte). Público 13–34, monetização cosmética.

## Fase

**Pré-P0.** Nenhum código de produção do jogo. O que existe é o motor provado em `sim/` e o
protótipo legado de moedas em `src/`.

## Números atuais (09/11/2026)

| Métrica | Valor |
|---|---|
| tick / cap | 0,05s · 1.200 ticks (60s) |
| estado | 100% inteiro (MILLI = 1000) |
| custo por batalha | 1,28 ms (~780 batalhas/s) |
| determinismo | hash `668061367` (seed 42, 3 execuções) |
| 500 seeds | 500 hashes distintos · 64,8% vitória do defensor |
| invariantes | 10/10 passando (`sim/invariants.luau`) |
| docs / código / testes | 12 docs · 10 arquivos · 2 oráculos |

## Pronto

- Conceito aprovado: `docs/gdd-muralha.md` v1.1 (decisões 1–5 fechadas).
- Economia: `docs/modelo-financeiro.xlsx` + `docs/tese-produto-e-economia.md`.
- Evidência: `docs/pesquisa-tendencias-2026.md`, `docs/pesquisa-jogadores.md`, `docs/pesquisa-grade-e-prototipo.md`.
- Engenharia: `docs/padroes-engenharia.md` (regras com fonte oficial).
- Motor: `sim/core.luau` (módulo) + `sim/poc.luau` (benchmark) + `sim/invariants.luau` (oráculo).
- Tooling: Rokit + CLI/GUI; CI ativo; estação calibrada (doctor); ProfileStore vendorizado
  (wrapper/schema na P0).
- Monetização: base 2% × US$ 2; topo 4,5% × US$ 5; gate ARPDAU líquido US$ 0,005 — `docs/decisao-monetizacao.md`.
- Contexto: `skills/context-recovery/` (protocolo de auditoria portátil).

## Não pronto

- P0 não iniciado (decisão do diretor).
- `src/` ainda é o protótipo de moedas — legado, não arquitetura final.
- Q1/Q2 aguardam decisão; evidência em `docs/pesquisa-grade-e-prototipo.md`.
- Revisão de direção: teste de produto de 3 semanas antes da P0 — `docs/revisao-direcao.md`.
- Analytics: taxonomia v1 escrita; instrumentação no motor é P0 — `docs/taxonomia-analytics.md`.
- Ferramentas: estação completa (doctor), CI verde, `.luaurc` strict e calibração Blender; ProfileStore vendorizado; `pesde.toml` adiado — `docs/estacao-de-trabalho.md`.
- Sem cena de Studio, sem UI, sem DataStore, sem monetização.

## Congelado

- Decisões do GDD: 5×5 → 7×5 por nível; cercos livres + 3 Grandes Saques; derrota só perde liga;
  `A MURALHA` / `WALLBREAKER`; co-op na P3.
- Servidor autoritativo + replay por seed + `simVersion`.
- Regras dos jogadores: nenhuma unidade obrigatória; poder só por gameplay; sem loot box.

## Próximo passo (quando liberado)

Teste de produto de 3 semanas (`docs/revisao-direcao.md` §7). Só depois: P0 (portar `sim/core.luau`
para `src/shared/sim/`, schema v1 com ProfileStore e cena 5×5).

## Como verificar o estado em 1 minuto

```bash
source scripts/env.sh
bash scripts/doctor.sh     # estação completa
bash scripts/check.sh      # build, StyLua, luau-lsp, invariantes, contexto
```
