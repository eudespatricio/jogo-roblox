# AGENTS — instruções para qualquer agente neste repo

Leia nesta ordem, antes de qualquer ação:

1. `.context/ESTADO.md` — fase, números, o que está congelado.
2. `.context/MAPA.md` — onde cada responsabilidade mora e as armadilhas.
3. `.context/REJEITADOS.md` — o que já foi descartado (não reproponha sem "reabre se").
4. `CONTINUAR.md` — **se esta é uma sessão nova**: histórico, decisões e próximos passos.

## Regras duras

- **P2+ não começa sem autorização explícita do diretor.** A P1 foi autorizada em 09/11/2026 e está
  em execução (S1–S6.1 fechadas; S7 pendente); o plano está em
  `docs/p1-plano.md` (S1–S7, critérios de pronto).
- **`src/` é produção.** O legado de moedas foi apagado na S1 (09/11/2026) e está preservado na
  tag anotada `legacy-coins` (commit `b07b4c5`). Não ressuscite `CoinService`/`DataService`/`Config`.
- Depois de editar `src/shared/sim/core.luau`, rode `sim/invariants.luau` e `sim/acceptance.luau`.
  Se quebrar, conserte antes de seguir.
- Mudou a matemática da simulação? Suba `simVersion` e registre em `docs/spec-motor-deterministico.md`
  e em `docs/versoes.md` (o `check.sh` falha se fonte e docs divergirem).
- Mudou custo/desbloqueio/`trap_id` da muralha? Atualize `TrapCatalog.luau`, `docs/economia-muralha.md`, `sim/walls-contract.luau` e `sim/content-contract.luau`.
- Expansão de conteúdo/feature segue `docs/pipeline-expansao.md`; toda P/S fecha com uma linha
  `GAP:` e o gap aberto entra em `docs/gaps.md`. Antes de mergear conteúdo, rode o trial kit
  `tools/expansion-test/` (branch temporária + patch + relatório).
- `bit32` só recebe `[0, 2^32)`: use `add32`/`mul32`, nunca `band` em double grande.
- Contexto residente tem teto: ESTADO 80, MAPA 60, REJEITADOS 40 linhas. Rode `--check`.

## Comandos

```bash
source scripts/env.sh
bash scripts/doctor.sh                  # estação completa
bash scripts/check.sh                   # gate: build, StyLua, luau-lsp, versões, invariantes, contratos, contexto

luau sim/invariants.luau                # oráculo (12 checagens)
luau sim/acceptance.luau                # P1: 1.000 seeds × 3
luau sim/profile-contract.luau          # schema v2 + contentVersion + sessão
luau sim/analytics-contract.luau        # contrato de analytics v1
luau sim/walls-contract.luau            # muralha/economia (S3)
luau sim/content-contract.luau          # conteúdo/versões (S3.4)
luau sim/build-contract.luau            # grid/build (S4)
luau sim/dropin-contract.luau           # drop-in (S5)
luau sim/raid-contract.luau             # raid/BattleLog/replay (S6)
luau sim/poc.luau                       # benchmark do motor

python3 scripts/check-versions.py       # versões docs x fonte
python3 skills/context-recovery/scan_repo.py --root . --check   # tetos do contexto
```

## Fonte de verdade

Decisão humana > código + teste > documento por data. Documento mais velho que o código mente:
rode a radiografia antes de confiar em README, tese ou pesquisa.
