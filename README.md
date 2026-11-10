# jogo-roblox — MURALHA

[![CI](https://github.com/eudespatricio/jogo-roblox/actions/workflows/ci.yml/badge.svg)](https://github.com/eudespatricio/jogo-roblox/actions/workflows/ci.yml)

Jogo de **tower defense invertido + autobattler assíncrono** para Roblox: você monta a muralha,
outros jogadores atacam enquanto você está offline, e o replay determinístico mostra o que aconteceu.

> **Status: P0 fechada (09/11/2026).** Motor determinístico, schema v1 + wrapper ProfileStore,
> contrato de analytics com gates no CI e teste de sessão no Studio aprovado no Modo A (8/8,
> [roteiro e evidência](docs/teste-sessao-studio.md)). Modo B (DataStore real) é opcional. O
> protótipo de moedas em `src/` segue legado até a P1 (tag `legacy-coins`) — `src/shared/sim/`
> já é produção.

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
- [`docs/padroes-engenharia.md`](docs/padroes-engenharia.md) — regras com fonte oficial.
- [`docs/pesquisa-jogadores.md`](docs/pesquisa-jogadores.md) — reclamações, pedidos, 10 regras.
- [`docs/pesquisa-tendencias-2026.md`](docs/pesquisa-tendencias-2026.md) — mercado e gêneros.
- [`docs/tese-produto-e-economia.md`](docs/tese-produto-e-economia.md) + [`docs/modelo-financeiro.xlsx`](docs/modelo-financeiro.xlsx) — economia unitária.

## Estrutura

```
sim/                     harnesses do motor (Luau puro, roda sem Roblox)
  poc.luau               benchmark e demo
  invariants.luau        oráculo executável (10 checagens)
  acceptance.luau        P0: 1.000 seeds × 3
  profile-contract.luau  contrato do schema v1 e da sessão do perfil
  analytics-contract.luau contrato de analytics v1
  fixtures/              fixture da migração 0→1 do perfil
src/shared/sim/core.luau motor de produção (RNG, mul32/add32, Battle)
src/shared/data/         schema v1 do perfil (template, migração, validação)
src/shared/analytics/    contrato de analytics (envelope, catálogo, anti-PII)
src/server/data/         sessão sobre o ProfileStore vendorizado
src/server/ProfileBoot.server.luau  ligação com Players + self-test no Studio
src/{client,server,shared}/  protótipo legado de moedas — NÃO é o jogo
vendor/ProfileStore.luau ProfileStore oficial (Apache-2.0, não editar)
docs/                    GDD, spec, pesquisas, economia, roteiro do Studio
.context/                contexto residente (teto de linhas)
skills/context-recovery/ protocolo de auditoria + scanner + templates
```

## Comandos

```bash
source scripts/env.sh
bash scripts/doctor.sh                 # estação completa
bash scripts/check.sh                  # gate: build, StyLua, luau-lsp, invariantes, contratos

luau sim/invariants.luau               # oráculo do motor (10 checagens)
luau sim/acceptance.luau               # P0: 1.000 seeds × 3
luau sim/profile-contract.luau         # schema v1 + sessão
luau sim/analytics-contract.luau       # contrato de analytics v1

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

Antes do push: `git status` limpo, sem `.tools/` (já ignorado) e sem segredos (varredura feita em
09/11/2026). O workflow de CI existe em `.github/workflows/ci.yml` e roda `scripts/check.sh`.

## Rodar no WSL

```bash
# uma vez: clonar no ext4 (não no /mnt/c)
git clone git@github.com:<usuario>/jogo-roblox.git ~/jogo-roblox
cd ~/jogo-roblox
bash scripts/setup-wsl.sh
```

O script instala Rokit + ferramentas, valida os 10 invariantes, checa os tetos do contexto e imprime
o IP do WSL. O gate completo (build, StyLua, luau-lsp, invariantes, benchmark e contexto) é:

```bash
bash scripts/check.sh
``` Para o Studio falar com o Rojo: no WSL rode `rojo serve` (escuta `127.0.0.1:34872`) e
no plugin conecte em `localhost:34872`. **Não use `--address 0.0.0.0`** — o encaminhamento de
localhost do WSL só vale para loopback; firewall não é necessário nesse caminho.

## Regras que não se negociam

1. Servidor é a fonte da verdade; o cliente só manda intenção.
2. Poder só se ganha jogando; Robux compra cosmético.
3. Nenhuma unidade obrigatória (mata gatekeeping).
4. Replay do passado, não gravação do futuro.
5. Contexto residente tem teto; contradição vira teste, não markdown eterno.
