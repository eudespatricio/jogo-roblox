# MAPA — onde cada responsabilidade mora

> Teto: 60 linhas. Atualizado: 13/11/2026. Se um caminho não estiver aqui, procure antes de editar.

| Caminho | O que tem | Quando carregar |
|---|---|---|
| `.context/ESTADO.md` | fase, números, congelados | **sempre, primeiro** |
| `.context/MAPA.md` | este mapa | antes de navegar no repo |
| `.context/REJEITADOS.md` | ideias descartadas e quando reabrem | antes de propor arquitetura |
| `docs/gdd-muralha.md` · `docs/economia-muralha.md` · `docs/catalogo-itens-e-cosmeticos.md` | design, catálogo P1/P2, custos, cosméticos | decisão de produto/economia |
| `docs/spec-motor-deterministico.md` · `docs/arquitetura-e-fluxos.md` | motor, fluxos, auditoria `AUD-01..12`, anti-cheat | mexer em `sim/`/rede |
| `docs/taxonomia-analytics.md` | eventos, envelope, funil, métricas e sink | **antes de instrumentar/P0** |
| `docs/p1-plano.md` · `docs/plano-playtest-v1.md` · `docs/rfcs-p2-e-fechamento-gaps.md` · `docs/pipeline-expansao.md` · `docs/gaps.md` · `docs/versoes.md` · `docs/rfc-s3.4-conteudo.md` · `docs/expansion-test-2026-11-10.md` · `docs/sistemas-jogo-completo.md` | P1, runbook Playtest V1, RFCs `GAP-004..020`, sistemas completos, pipeline, gate e trial | **início da retomada/expansão** |
| `docs/padroes-engenharia.md` | regras de engenharia com fonte oficial | escrever código de produção |
| `docs/pesquisa-jogadores.md` · `docs/literatura-e-universo.md` · `docs/skills-tiers-e-modos.md` · `docs/campanha-bosses-e-coop-sincrono.md` | regras, lore, skills, ligas, modos, campanha/bosses e co-op síncrono | priorizar feature/design |
| `docs/pesquisa-tendencias-2026.md` | mercado e gêneros | decidir escopo |
| `docs/pesquisa-grade-e-prototipo.md` | evidência e decisão de Q1/Q2 (fechadas) | histórico |
| `docs/pesquisa-monetizacao.md` | preços, benchmarks e canais de receita | **antes de decidir preço/loja** |
| `docs/decisao-monetizacao.md` | premissas base × topo, gate bruto vs líquido | **antes de decidir preço/gate** |
| `docs/revisao-direcao.md` | veredito de rota + teste de 3 semanas | histórico da decisão |
| `docs/ferramentas.md` · `docs/direcao-visual-e-silhuetas.md` · `docs/audio-musica-e-soundscape.md` · `docs/animacoes-fisica-real-e-vfx.md` | toolchain, Blender→Studio, visual/tiers, OST/SFX 3D, animações 60 Hz e física real | **antes de produzir asset/código** |
| `docs/estacao-de-trabalho.md` | manual operacional: inventário, doctor, reconstrução | **ao montar/trocar de máquina** |
| `docs/referencias-tower-defense.md` | jogos e vídeos de referência | antes de decidir game feel |
| `docs/tese-produto-e-economia.md` | economia unitária e cenários | decisão de receita |
| `docs/modelo-financeiro.xlsx` | modelo editável | simular DAU/ARPPU |
| `src/shared/sim/core.luau` | motor v6: Arqueiro 360°, `ARENA`, `WALL_LEVELS`, `tooClose`, RNG/hash | qualquer mudança de simulação |
| `sim/poc.luau` · `sim/acceptance.luau` | benchmark/demo e acceptance P1 (1.000 seeds × 3) | medir performance/validar hash |
| `sim/invariants.luau` | oráculo executável (16 checagens) | **sempre após editar core** |
| `sim/audit-bit32.luau` · `audit-mul32.luau` | evidência dos bugs de aritmética | auditar determinismo |
| `vendor/ProfileStore.luau` | ProfileStore oficial vendorizado (Apache-2.0) + `SOURCE.md` | camada de dados da P0 |
| `src/shared/data/ProfileSchema.luau` · `TrapCatalog.luau` · `sim/profile-contract.luau` | schema v3 + `contentVersion 3` + catálogo (5 tipos/`WALL_LEVELS`); migração 0/1/2→3, JSON-safe | mexer em dado/catálogo |
| `src/server/data/ProfileService.luau` · `src/server/ProfileBoot.server.luau` | sessão (nil/retry, `EndSession`) e ligação com Players/vendor | mexer em sessão/persistência |
| `src/shared/analytics/` · `src/server/analytics/` · `sim/analytics-contract.luau` | contrato v2 (35/35) + sink DataStore/Memory + `es-419→es-MX`; QA `teste-s7-studio.md` | emitir/validar evento |
| `src/shared/i18n/I18n.luau` · `src/shared/raid/BotPhantoms.luau` · `sim/i18n-contract.luau` | 62 chaves PT/EN/ES + 10 bots L1..L5 (`BotPhantoms`) + contratos | mexer em tradução/matchmaking |
| `src/shared/visual/VisualTheme.luau` · `src/client/visual/` · `sim/visual-contract.luau` | P2 visual/áudio: lanes naturais, 75 assets Cloud + VFX combos + contrato 13/13 | mexer na apresentação |
| `src/server/walls/WallService.luau` · `WallController.server.luau` · `sim/walls-contract.luau` · `sim/content-contract.luau` · `sim/build-contract.luau` | S3/S3.4: regras, `toBattleWall`, `contentVersion`; S4: UI pura, remotes + contratos | mexer em muralha/economia/conteúdo/build |
| `sim/fixtures/profile-v0.luau` · `docs/teste-sessao-studio.md` | fixture da migração 0→1 e roteiro do teste de sessão | mudar schema/validar P0 no Studio |
| `src/` | produção: `shared/{sim,data,analytics,build,dropin,raid,i18n}`, `server/{data,walls,world,dropin,raid,ProfileBoot,Main}`, `client/`, `world/` | navegar no código |
| `skills/context-recovery/` | protocolo de auditoria + scanner | início de sessão/revisão |
| `rokit.toml` · `asphalt.toml` · `CREDITS.md` | ferramentas fixadas + sync de assets + licenças | setup/assets |
| `default.project.json` | mapeamento Rojo (produção + vendor + world) | build do lugar |
| `scripts/` · `tools/` | env/check/doctor/fetch-types/check-roblox + trial/gen-sfx/coop-net-sim/check-i18n | rodar/validar |
| `.github/workflows/ci.yml` | CI: check + artefato do place | após push/PR |
| `art/` · `assets/` | calibração/fratura Blender + OGG/UI/models Asphalt + `i18n/LocalizationTable.csv` | produzir asset/i18n |
| `.luaurc` · `.vscode/settings.json` | strict + LSP/sourcemap | editar código |
| `.gitattributes` | LFS de binários | commitar arte/áudio |

## Armadilhas conhecidas

1. **Não edite `src/shared/sim/core.luau` sem rodar `sim/invariants.luau` e `sim/acceptance.luau`.**
2. **Mudou a matemática? Suba `simVersion` e atualize `docs/versoes.md`.** Atual = **6**; replay v1..v5 não roda no motor v6.
3. **`src/` é produção**; o legado de moedas foi apagado na S1 e vive na tag anotada `legacy-coins`.
4. **Doc mais velho que código mente.** Rode a radiografia antes de confiar em README/tese.
5. **`.tools/` não é versionado.** Reinstale com `rokit install` se sumir.
6. **`bit32` só aceita `[0, 2^32)`.** Use `add32`/`mul32`, nunca `band` em double grande.
7. **Célula `rXcY` (linha=lane, coluna=profundidade; c1 muralha, c5 spawn).** N=5 livre; S4/S6 usam `toBattleWall`.
8. **Binários de arte são LFS.** `git add` sem `source scripts/env.sh` falha (git-lfs not found).
9. **Selene 0.32 não entende `+=`.** Use `luau-lsp analyze`; Selene fora do CI.
10. **ProfileStore é server-only e `StartSessionAsync` pode devolver nil.** O wrapper trata; nunca edite `vendor/ProfileStore.luau`.
