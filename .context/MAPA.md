# MAPA — onde cada responsabilidade mora

> Teto: 60 linhas. Atualizado: 09/11/2026. Se um caminho não estiver aqui, procure antes de editar.

| Caminho | O que tem | Quando carregar |
|---|---|---|
| `.context/ESTADO.md` | fase, números, congelados | **sempre, primeiro** |
| `.context/MAPA.md` | este mapa | antes de navegar no repo |
| `.context/REJEITADOS.md` | ideias descartadas e quando reabrem | antes de propor arquitetura |
| `docs/gdd-muralha.md` | design: loop, drop-in, modos, economia, fases | decisão de produto |
| `docs/spec-motor-deterministico.md` | contrato do motor, replay, clipe, anti-cheat | mexer em `sim/` |
| `docs/padroes-engenharia.md` | regras de engenharia com fonte oficial | escrever código de produção |
| `docs/pesquisa-jogadores.md` | reclamações/pedidos + 10 regras | priorizar feature |
| `docs/pesquisa-tendencias-2026.md` | mercado e gêneros | decidir escopo |
| `docs/tese-produto-e-economia.md` | economia unitária e cenários | decisão de receita |
| `docs/modelo-financeiro.xlsx` | modelo editável | simular DAU/ARPPU |
| `sim/core.luau` | motor: RNG, mul32, Battle | qualquer mudança de simulação |
| `sim/poc.luau` | benchmark e demo | medir performance/balanço |
| `sim/invariants.luau` | oráculo executável (10 checagens) | **sempre após editar core** |
| `sim/audit-bit32.luau` · `audit-mul32.luau` | evidência dos bugs de aritmética | auditar determinismo |
| `src/**` | protótipo legado de moedas (Rojo) | só como referência; não é o jogo |
| `skills/context-recovery/` | protocolo de auditoria + scanner | início de sessão/revisão |
| `rokit.toml` | versões fixas de ferramentas | setup do ambiente |
| `default.project.json` | mapeamento Rojo (legado) | build do protótipo |

## Armadilhas conhecidas

1. **Não edite `sim/core.luau` sem rodar `sim/invariants.luau`.** Hash e balanço quebram silencioso.
2. **Mudou a matemática? Suba `simVersion`.** Replay antigo não pode pagar recompensa.
3. **`src/**` é legado.** Não use `CoinService` como base do jogo novo.
4. **Doc mais velho que código mente.** Rode a radiografia antes de confiar em README/tese.
5. **`.tools/` não é versionado.** Reinstale com `rokit install` se sumir.
6. **`bit32` só aceita `[0, 2^32)`.** Use `add32`/`mul32`, nunca `band` em double grande.
7. **O PoC não é a arquitetura.** Ele usa 1 armadilha por lane; produção é grade 5×5.
