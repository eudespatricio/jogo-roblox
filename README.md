# jogo-roblox — MURALHA

[![CI](https://github.com/eudespatricio/jogo-roblox/actions/workflows/ci.yml/badge.svg)](https://github.com/eudespatricio/jogo-roblox/actions/workflows/ci.yml)

Jogo de **tower defense invertido + autobattler assíncrono** para Roblox: você monta a muralha,
outros jogadores atacam enquanto você está offline, e o replay determinístico mostra o que aconteceu.

> **Status: P1 em execução (10/11/2026).** P0 fechada. **S1** concluída: legado de moedas apagado,
> tag anotada `legacy-coins` no commit `b07b4c5`, stub de 10 linhas. **S2** concluída: motor
> determinístico com grade **5×5**, **N=5** ativas e colocação livre; `simVersion 2` e hash de
> referência `2489780106`. **S3** concluída: muralha/economia server-side, catálogo em
> [`docs/economia-muralha.md`](docs/economia-muralha.md). **S3.3** concluída: GAP-006
> (`toBattleWall`) e GAP-007 (gate de versões) fechados. **S3.4** com código verde: schema v2 +
> `contentVersion`, `oil → tar`, 5º tipo `catapult`, `simVersion 3` e hash `2489780106` preservado;
> GAP-001/002/003/010 fechados. **S4 em QA** com cena 5×5, UI de build, remotes e QA headless
> (`GridLayout`/`BuildProtocol`/`BuildClientState`/`BuildHud`/`BuildLayout`); HUD de debug
> (FPS/tempos), layout 375×812/720×1280, grant de QA e contrato de build **14/14**; falta o QA humano de
> FPS/build/feel no Studio ([roteiro](docs/teste-s4-studio.md)). A S3.4 fechou o GAP-009 no Modo B
> real (schema v2, 8/8). O teste de produto de 3 semanas
> roda em paralelo ([plano da P1](docs/p1-plano.md)).

## Comece por aqui

| Arquivo | Para quê |
|---|---|
| [`.context/ESTADO.md`](.context/ESTADO.md) | fase, números atuais, o que está congelado |
| [`.context/MAPA.md`](.context/MAPA.md) | onde cada responsabilidade mora + armadilhas |
| [`.context/REJEITADOS.md`](.context/REJEITADOS.md) | o que já foi descartado e quando reabre |
| [`AGENTS.md`](AGENTS.md) | regras para humanos e agentes |

## Documentação de produto e engenharia

- [`docs/gdd-muralha.md`](docs/gdd-muralha.md) — loop, drop-in de 5s, modos, economia, fases.
- [`docs/spec-motor-deterministico.md`](docs/spec-motor-deterministico.md) — motor, replay, clipe, anti-cheat.
- [`docs/p1-plano.md`](docs/p1-plano.md) — P1: fatias S1–S7, critérios de pronto e riscos.
- [`docs/pipeline-expansao.md`](docs/pipeline-expansao.md) — como expandir conteúdo/features sem quebrar.
- [`docs/gaps.md`](docs/gaps.md) — lacunas conhecidas entre P's/S's, com gatilho para fechar.
- [`docs/versoes.md`](docs/versoes.md) — bloco canônico de versões e gate do CI.
- [`docs/rfc-s3.4-conteudo.md`](docs/rfc-s3.4-conteudo.md) — RFC da fatia de conteúdo e versões.
- [`docs/teste-s4-studio.md`](docs/teste-s4-studio.md) — roteiro de QA da cena/build da S4.
- [`docs/expansion-test-2026-11-10.md`](docs/expansion-test-2026-11-10.md) — trial real de classe/trait/raridade.
- [`tools/expansion-test/`](tools/expansion-test/README.md) — kit reutilizável de trial de expansão.
- [`docs/economia-muralha.md`](docs/economia-muralha.md) — catálogo, custos, desbloqueio e eventos da S3.
- [`docs/padroes-engenharia.md`](docs/padroes-engenharia.md) — regras com fonte oficial.
- [`docs/pesquisa-jogadores.md`](docs/pesquisa-jogadores.md) — reclamações, pedidos, 10 regras.
- [`docs/pesquisa-tendencias-2026.md`](docs/pesquisa-tendencias-2026.md) — mercado e gêneros.
- [`docs/tese-produto-e-economia.md`](docs/tese-produto-e-economia.md) + [`docs/modelo-financeiro.xlsx`](docs/modelo-financeiro.xlsx) — economia unitária.

## Estrutura

```
sim/                     harnesses do motor (Luau puro, roda sem Roblox)
  poc.luau               benchmark e demo do motor v2
  invariants.luau        oráculo executável (12 checagens)
  acceptance.luau        P1: 1.000 seeds × 3 (hash 2489780106)
  profile-contract.luau  contrato do schema v1 e da sessão do perfil
  analytics-contract.luau contrato de analytics v1
  walls-contract.luau    contrato da muralha/economia (S3; 13 checagens, toBattleWall)
  content-contract.luau  contrato de conteúdo/versões (S3.4; 7 checagens)
  build-contract.luau    contrato do grid/build da S4 (14 checagens: protocolo/estado/HUD/layout)
  fixtures/              fixtures da migração 0→1→2 do perfil
src/shared/sim/core.luau motor v3 (RNG, mul32/add32, Battle 5×5/N=5, 5 tipos)
src/shared/build/        GridLayout, BuildProtocol, BuildClientState, BuildHud e BuildLayout (puros)
src/shared/data/         schema v2 do perfil + TrapCatalog (economia/conteúdo)
src/shared/analytics/    contrato de analytics (envelope, catálogo, anti-PII)
src/server/data/         sessão sobre o ProfileStore vendorizado + ProfileRegistry
src/server/walls/        WallService + WallController (remotes snapshot/place/remove/upgrade)
src/server/world/        BuildGrid: 25 células e muralha visual no Workspace
src/server/ProfileBoot.server.luau  ligação com Players + self-test no Studio
src/server/Main.server.luau  stub de entrada do servidor (S1)
src/client/              BuildClient: câmera isométrica fixa + UI de build
src/world/               Baseplate/SpawnLocation da cena
vendor/ProfileStore.luau ProfileStore oficial (Apache-2.0, não editar)
docs/                    GDD, spec, pesquisas, economia, roteiro do Studio
.context/                contexto residente (teto de linhas)
skills/context-recovery/ protocolo de auditoria + scanner + templates
tools/expansion-test/    kit de trial de expansão (branch + patch + relatório)
```

O legado de moedas (`CoinService`, `DataService`, `Config`, `Hud`) **não existe mais**; está
preservado na tag anotada `legacy-coins` (commit `b07b4c5`).

## Comandos

```bash
source scripts/env.sh
bash scripts/doctor.sh                 # estação completa
bash scripts/check.sh                  # gate: versões, build, StyLua, luau-lsp, testes, contexto

luau sim/invariants.luau               # oráculo do motor (12 checagens)
luau sim/acceptance.luau               # P1: 1.000 seeds × 3 (motor v2)
luau sim/profile-contract.luau         # schema v1 + sessão
luau sim/analytics-contract.luau       # contrato de analytics v1
luau sim/walls-contract.luau           # muralha/economia (S3; 13 checagens)
luau sim/content-contract.luau         # conteúdo/versões (S3.4; 7 checagens)
luau sim/build-contract.luau           # grid/build (S4; 14 checagens)
luau sim/poc.luau                      # benchmark e curva de balanço
python3 scripts/check-versions.py      # gate de versões docs x fonte

rojo serve                             # Studio: localhost:34872 (WSL)
```

## Tooling

Versões fixadas em [`rokit.toml`](rokit.toml): Rojo 7.7.1, StyLua 2.6.0, Selene 0.32.0, Luau 0.746.
`rokit install` reproduz o ambiente; `.tools/` não é versionado.

Auditoria completa: [`docs/ferramentas.md`](docs/ferramentas.md). Manual da máquina (inventário,
doctor, reconstrução e troubleshooting): [`docs/estacao-de-trabalho.md`](docs/estacao-de-trabalho.md).
Ferramentas CLI extras (luau-lsp, Lune, Pesde, rbxcloud, git-lfs, oxipng, Blender 4.5) estão em
`~/.local/bin`; `bash scripts/doctor.sh` confere tudo.

## Publicar no GitHub

```bash
git branch -M main                     # opcional (o repo nasceu como master)
git remote add origin git@github.com:<usuario>/jogo-roblox.git
git push -u origin main
```

Antes do push: `git status` limpo, sem `.tools/` (já ignorado) e sem segredos. O workflow de CI
existe em `.github/workflows/ci.yml` e roda `scripts/check.sh`.

## Rodar no WSL

```bash
# uma vez: clonar no ext4 (não no /mnt/c)
git clone git@github.com:<usuario>/jogo-roblox.git ~/jogo-roblox
cd ~/jogo-roblox
bash scripts/setup-wsl.sh
```

O script instala Rokit + ferramentas, valida os invariantes, checa os tetos do contexto e imprime o
IP do WSL. O gate completo (build, StyLua, luau-lsp, invariantes, acceptance, contratos e contexto) é:

```bash
bash scripts/check.sh
```

Para o Studio falar com o Rojo: no WSL rode `rojo serve` (escuta `127.0.0.1:34872`) e no plugin
conecte em `localhost:34872`. **Não use `--address 0.0.0.0`** — o encaminhamento de localhost do WSL
só vale para loopback; firewall não é necessário nesse caminho.

## Regras que não se negociam

1. Servidor é a fonte da verdade; o cliente só manda intenção.
2. Poder só se ganha jogando; Robux compra cosmético.
3. Nenhuma unidade obrigatória (mata gatekeeping).
4. Replay do passado, não gravação do futuro.
5. Contexto residente tem teto; contradição vira teste, não markdown eterno.
