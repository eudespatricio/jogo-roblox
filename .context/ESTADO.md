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
| docs / código / testes | 11 docs · 10 arquivos · 2 oráculos |

## Pronto

- Conceito aprovado: `docs/gdd-muralha.md` v1.1 (decisões 1–5 fechadas).
- Economia: `docs/modelo-financeiro.xlsx` + `docs/tese-produto-e-economia.md`.
- Evidência: `docs/pesquisa-tendencias-2026.md`, `docs/pesquisa-jogadores.md`, `docs/pesquisa-grade-e-prototipo.md`.
- Engenharia: `docs/padroes-engenharia.md` (regras com fonte oficial).
- Motor: `sim/core.luau` (módulo) + `sim/poc.luau` (benchmark) + `sim/invariants.luau` (oráculo).
- Tooling: Rokit (4 ferramentas fixadas), GitHub Actions, ProfileStore.
- Contexto: `skills/context-recovery/` (protocolo de auditoria portátil).

## Não pronto

- P0 não iniciado (decisão do diretor).
- `src/` ainda é o protótipo de moedas — legado, não arquitetura final.
- Q1/Q2 aguardam decisão; evidência em `docs/pesquisa-grade-e-prototipo.md`.
- Monetização: premissas de pagantes/ARPPU e gate de ARPDAU a reconciliar — `docs/pesquisa-monetizacao.md`.
- Revisão de direção: teste de produto de 3 semanas antes da P0 — `docs/revisao-direcao.md`.
- Ferramentas: CLI/GUI instaladas; CI + check prontos (run #1 verde); faltam `.luaurc`, `pesde.toml` e pipeline de asset — `docs/ferramentas.md`.
- Sem cena de Studio, sem UI, sem DataStore, sem monetização.

## Congelado

- Decisões do GDD: 5×5 → 7×5 por nível; cercos livres + 3 Grandes Saques; derrota só perde liga;
  `A MURALHA` / `WALLBREAKER`; co-op na P3.
- Servidor autoritativo + replay por seed + `simVersion`.
- Regras dos jogadores: nenhuma unidade obrigatória; poder só por gameplay; sem loot box.

## Próximo passo (quando liberado)

P0: portar `sim/core.luau` para `src/shared/sim/`, criar CI, schema v1 com ProfileStore e cena 5×5.

## Como verificar o estado em 1 minuto

```powershell
.\.tools\luau\luau.exe sim\invariants.luau                       # oráculo
python skills\context-recovery\scan_repo.py --root . --ast .tools\luau\luau-ast.exe
python skills\context-recovery\scan_repo.py --root . --check     # tetos do contexto
```
