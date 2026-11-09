# AGENTS — instruções para qualquer agente neste repo

Leia nesta ordem, antes de qualquer ação:

1. `.context/ESTADO.md` — fase, números, o que está congelado.
2. `.context/MAPA.md` — onde cada responsabilidade mora e as armadilhas.
3. `.context/REJEITADOS.md` — o que já foi descartado (não reproponha sem "reabre se").
4. `CONTINUAR.md` — **se esta é uma sessão nova**: histórico, decisões e próximos passos.

## Regras duras

- **P1 não começa sem autorização explícita do diretor.** A P0 está em andamento (autorizada em
  09/11/2026); o port do motor e a aceitação de 1.000 batalhas já passaram.
- **`src/**` é legado** (protótipo de moedas), exceto **`src/shared/sim/`**, que é o motor de
  produção. Não use o legado como base do jogo novo.
- Depois de editar `src/shared/sim/core.luau`, rode `sim/invariants.luau` e `sim/acceptance.luau`.
  Se quebrar, conserte antes de seguir.
- Mudou a matemática da simulação? Suba `simVersion` e registre em `docs/spec-motor-deterministico.md`.
- `bit32` só recebe `[0, 2^32)`: use `add32`/`mul32`, nunca `band` em double grande.
- Contexto residente tem teto: ESTADO 80, MAPA 60, REJEITADOS 40 linhas. Rode `--check`.

## Comandos

```powershell
.\.tools\luau\luau.exe sim\invariants.luau          # oráculo (10 checagens)
.\.tools\luau\luau.exe sim\acceptance.luau        # P0: 1.000 seeds × 3
.\.tools\luau\luau.exe sim\poc.luau                 # benchmark do motor
python skills\context-recovery\scan_repo.py --root . --ast .tools\luau\luau-ast.exe
python skills\context-recovery\scan_repo.py --root . --check
bash scripts/check.sh                               # gate completo no WSL (build, StyLua, tipos, invariantes)
```

## Fonte de verdade

Decisão humana > código + teste > documento por data. Documento mais velho que o código mente:
rode a radiografia antes de confiar em README, tese ou pesquisa.
