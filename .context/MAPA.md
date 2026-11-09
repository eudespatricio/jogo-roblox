# MAPA — onde cada responsabilidade mora

> Teto: 60 linhas. Atualizado: 09/11/2026. Se um caminho não estiver aqui, procure antes de editar.

| Caminho | O que tem | Quando carregar |
|---|---|---|
| `.context/ESTADO.md` | fase, números, congelados | **sempre, primeiro** |
| `.context/MAPA.md` | este mapa | antes de navegar no repo |
| `.context/REJEITADOS.md` | ideias descartadas e quando reabrem | antes de propor arquitetura |
| `docs/gdd-muralha.md` | design: loop, drop-in, modos, economia, fases | decisão de produto |
| `docs/spec-motor-deterministico.md` | contrato do motor, replay, clipe, anti-cheat | mexer em `sim/` |
| `docs/taxonomia-analytics.md` | eventos, envelope, funil, métricas e sink | **antes de instrumentar/P0** |
| `docs/padroes-engenharia.md` | regras de engenharia com fonte oficial | escrever código de produção |
| `docs/pesquisa-jogadores.md` | reclamações/pedidos + 10 regras | priorizar feature |
| `docs/pesquisa-tendencias-2026.md` | mercado e gêneros | decidir escopo |
| `docs/pesquisa-grade-e-prototipo.md` | evidência de Q1 (protótipo legado) e Q2 (fechada) | **antes de decidir Q1** |
| `docs/pesquisa-monetizacao.md` | preços, benchmarks e canais de receita | **antes de decidir preço/loja** |
| `docs/decisao-monetizacao.md` | premissas base × topo, gate bruto vs líquido, correção do modelo | **antes de decidir preço/gate** |
| `docs/revisao-direcao.md` | veredito de rota + teste de 3 semanas antes da P1 | histórico da decisão |
| `docs/ferramentas.md` | auditoria do toolchain, pipeline Blender→Studio e orçamentos | **antes de produzir asset/código** |
| `docs/estacao-de-trabalho.md` | manual operacional: inventário, doctor, reconstrução e troubleshooting | **ao montar/trocar de máquina** |
| `docs/referencias-tower-defense.md` | jogos e vídeos de referência | antes de decidir game feel |
| `docs/tese-produto-e-economia.md` | economia unitária e cenários | decisão de receita |
| `docs/modelo-financeiro.xlsx` | modelo editável | simular DAU/ARPPU |
| `src/shared/sim/core.luau` | motor de produção: RNG, mul32, Battle | qualquer mudança de simulação |
| `sim/poc.luau` · `sim/acceptance.luau` | benchmark/demo e aceitação P0 (1.000 seeds × 3) | medir performance/validar hash |
| `sim/invariants.luau` | oráculo executável (10 checagens) | **sempre após editar core** |
| `sim/audit-bit32.luau` · `audit-mul32.luau` | evidência dos bugs de aritmética | auditar determinismo |
| `vendor/ProfileStore.luau` | ProfileStore oficial vendorizado (Apache-2.0) + `SOURCE.md` | camada de dados da P0 |
| `src/**` | protótipo legado de moedas (Rojo) + `src/shared/sim/` (motor de produção) | legado: só referência; sim: produção |
| `skills/context-recovery/` | protocolo de auditoria + scanner | início de sessão/revisão |
| `rokit.toml` | versões fixas de ferramentas | setup do ambiente |
| `default.project.json` | mapeamento Rojo (legado + vendor + sim) | build do protótipo |
| `scripts/` | env.sh, check.sh, doctor.sh, install-tools.sh | rodar/validar ambiente |
| `.github/workflows/ci.yml` | CI: check + artefato do place | após push/PR |
| `art/` | calibração Blender + pipeline 3D | produzir asset |
| `.luaurc` · `.vscode/settings.json` | strict + LSP/sourcemap | editar código |
| `.gitattributes` | LFS de binários | commitar arte/áudio |

## Armadilhas conhecidas

1. **Não edite `src/shared/sim/core.luau` sem rodar `sim/invariants.luau` e `sim/acceptance.luau`.**
   Hash e balanço quebram silencioso.
2. **Mudou a matemática? Suba `simVersion`.** Replay antigo não pode pagar recompensa.
3. **`src/**` é legado, exceto `src/shared/sim/`.** Não use `CoinService` como base do jogo novo.
4. **Doc mais velho que código mente.** Rode a radiografia antes de confiar em README/tese.
5. **`.tools/` não é versionado.** Reinstale com `rokit install` se sumir.
6. **`bit32` só aceita `[0, 2^32)`.** Use `add32`/`mul32`, nunca `band` em double grande.
7. **O PoC não é a arquitetura.** Ele usa 1 armadilha por lane; produção é 5×5 com N=5 ativas e colocação livre.
8. **Binários de arte são LFS.** `git add` sem `source scripts/env.sh` falha (git-lfs not found).
9. **Selene 0.32 não entende `+=`.** Use `luau-lsp analyze`; Selene fora do CI.
