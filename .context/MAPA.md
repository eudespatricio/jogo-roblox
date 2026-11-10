# MAPA — onde cada responsabilidade mora

> Teto: 60 linhas. Atualizado: 09/11/2026. Se um caminho não estiver aqui, procure antes de editar.

| Caminho | O que tem | Quando carregar |
|---|---|---|
| `.context/ESTADO.md` | fase, números, congelados | **sempre, primeiro** |
| `.context/MAPA.md` | este mapa | antes de navegar no repo |
| `.context/REJEITADOS.md` | ideias descartadas e quando reabrem | antes de propor arquitetura |
| `docs/gdd-muralha.md` · `docs/economia-muralha.md` | design, catálogo, custos e desbloqueio | decisão de produto/economia |
| `docs/spec-motor-deterministico.md` | contrato do motor, replay, clipe, anti-cheat | mexer em `sim/` |
| `docs/taxonomia-analytics.md` | eventos, envelope, funil, métricas e sink | **antes de instrumentar/P0** |
| `docs/p1-plano.md` · `docs/pipeline-expansao.md` · `docs/gaps.md` · `docs/versoes.md` · `docs/expansion-test-2026-11-10.md` | P1 + pipeline + gaps + gate de versões + trial real | **início da P1/expansão** |
| `docs/padroes-engenharia.md` | regras de engenharia com fonte oficial | escrever código de produção |
| `docs/pesquisa-jogadores.md` | reclamações/pedidos + 10 regras | priorizar feature |
| `docs/pesquisa-tendencias-2026.md` | mercado e gêneros | decidir escopo |
| `docs/pesquisa-grade-e-prototipo.md` | evidência e decisão de Q1/Q2 (fechadas) | histórico |
| `docs/pesquisa-monetizacao.md` | preços, benchmarks e canais de receita | **antes de decidir preço/loja** |
| `docs/decisao-monetizacao.md` | premissas base × topo, gate bruto vs líquido | **antes de decidir preço/gate** |
| `docs/revisao-direcao.md` | veredito de rota + teste de 3 semanas | histórico da decisão |
| `docs/ferramentas.md` | auditoria do toolchain, pipeline Blender→Studio | **antes de produzir asset/código** |
| `docs/estacao-de-trabalho.md` | manual operacional: inventário, doctor, reconstrução | **ao montar/trocar de máquina** |
| `docs/referencias-tower-defense.md` | jogos e vídeos de referência | antes de decidir game feel |
| `docs/tese-produto-e-economia.md` | economia unitária e cenários | decisão de receita |
| `docs/modelo-financeiro.xlsx` | modelo editável | simular DAU/ARPPU |
| `src/shared/sim/core.luau` | motor v2: grade 5×5, N=5, armadilha por célula, RNG/hash | qualquer mudança de simulação |
| `sim/poc.luau` · `sim/acceptance.luau` | benchmark/demo e acceptance P1 (1.000 seeds × 3) | medir performance/validar hash |
| `sim/invariants.luau` | oráculo executável (12 checagens) | **sempre após editar core** |
| `sim/audit-bit32.luau` · `audit-mul32.luau` | evidência dos bugs de aritmética | auditar determinismo |
| `vendor/ProfileStore.luau` | ProfileStore oficial vendorizado (Apache-2.0) + `SOURCE.md` | camada de dados da P0 |
| `src/shared/data/ProfileSchema.luau` · `TrapCatalog.luau` · `sim/profile-contract.luau` | schema v1 + catálogo econômico; migração 0→1, JSON-safe | mexer em dado/catálogo |
| `src/server/data/ProfileService.luau` · `src/server/ProfileBoot.server.luau` | sessão (nil/retry, `EndSession`) e ligação com Players/vendor | mexer em sessão/persistência |
| `src/shared/analytics/AnalyticsTypes.luau` · `sim/analytics-contract.luau` | contrato de analytics v1: envelope, catálogo, anti-PII | emitir/validar evento |
| `src/server/walls/WallService.luau` · `sim/walls-contract.luau` | S3: colocar/remover/upgrade, ouro, desbloqueio, `toBattleWall` + contrato | mexer em muralha/economia |
| `sim/fixtures/profile-v0.luau` · `docs/teste-sessao-studio.md` | fixture da migração 0→1 e roteiro do teste de sessão | mudar schema/validar P0 no Studio |
| `src/` | produção: `shared/{sim,data,analytics}`, `server/{data,walls,ProfileBoot,Main stub}`, `world/` | navegar no código |
| `skills/context-recovery/` | protocolo de auditoria + scanner | início de sessão/revisão |
| `rokit.toml` | versões fixas de ferramentas | setup do ambiente |
| `default.project.json` | mapeamento Rojo (produção + vendor + world) | build do lugar |
| `scripts/` · `tools/expansion-test/` | env/check/doctor/check-versions + kit de trial (migração neutra) | rodar/validar/expandir |
| `.github/workflows/ci.yml` | CI: check + artefato do place | após push/PR |
| `art/` | calibração Blender + pipeline 3D | produzir asset |
| `.luaurc` · `.vscode/settings.json` | strict + LSP/sourcemap | editar código |
| `.gitattributes` | LFS de binários | commitar arte/áudio |

## Armadilhas conhecidas

1. **Não edite `src/shared/sim/core.luau` sem rodar `sim/invariants.luau` e `sim/acceptance.luau`.**
2. **Mudou a matemática? Suba `simVersion` e atualize `docs/versoes.md`.** Atual = **2**; replay v1 não roda no motor v2.
3. **`src/` é produção**; o legado de moedas foi apagado na S1 e vive na tag anotada `legacy-coins`.
4. **Doc mais velho que código mente.** Rode a radiografia antes de confiar em README/tese.
5. **`.tools/` não é versionado.** Reinstale com `rokit install` se sumir.
6. **`bit32` só aceita `[0, 2^32)`.** Use `add32`/`mul32`, nunca `band` em double grande.
7. **Célula é `rXcY`: linha = lane; coluna = profundidade (c1 muralha, c5 spawn).** N=5 ativas no
   total; colocação livre permite várias armadilhas na mesma lane. S4/S6 usam `toBattleWall`.
8. **Binários de arte são LFS.** `git add` sem `source scripts/env.sh` falha (git-lfs not found).
9. **Selene 0.32 não entende `+=`.** Use `luau-lsp analyze`; Selene fora do CI.
10. **ProfileStore é server-only e `StartSessionAsync` pode devolver nil.** O wrapper trata; não
    mova `ProfileService`/`ProfileBoot` para `shared` nem edite `vendor/ProfileStore.luau`.
