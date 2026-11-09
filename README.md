# jogo-roblox — MURALHA

[![CI](https://github.com/eudespatricio/jogo-roblox/actions/workflows/ci.yml/badge.svg)](https://github.com/eudespatricio/jogo-roblox/actions/workflows/ci.yml)

Jogo de **tower defense invertido + autobattler assíncrono** para Roblox: você monta a muralha,
outros jogadores atacam enquanto você está offline, e o replay determinístico mostra o que aconteceu.

> **Status: pré-P0.** Conceito e motor provados; **nenhum código de produção do jogo ainda**.
> O `src/` atual é o protótipo legado de coleta de moedas, usado só para validar o pipeline Rojo.

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
sim/                 motor determinístico (Luau puro, roda sem Roblox)
  core.luau          RNG, mul32/add32, Battle
  poc.luau           benchmark e demo
  invariants.luau    oráculo executável (10 checagens)
  audit-*.luau       evidência das auditorias de aritmética
src/                 protótipo legado de moedas (Rojo) — não é o jogo
docs/                GDD, spec, pesquisas, economia
.context/            contexto residente (teto de linhas)
skills/context-recovery/  protocolo de auditoria + scanner + templates
```

## Comandos

```powershell
# oráculo do motor (falha o processo se uma regra quebrar)
.\.tools\luau\luau.exe sim\invariants.luau

# benchmark (determinismo, performance, balanço)
.\.tools\luau\luau.exe sim\poc.luau

# radiografia determinística do repositório
python skills\context-recovery\scan_repo.py --root . --ast .tools\luau\luau-ast.exe

# tetos do contexto residente
python skills\context-recovery\scan_repo.py --root . --check

# protótipo legado no Studio
.\.tools\rojo.exe serve
```

## Tooling

Versões fixadas em [`rokit.toml`](rokit.toml): Rojo 7.7.1, StyLua 2.6.0, Selene 0.32.0, Luau 0.746.
`rokit install` reproduz o ambiente; `.tools/` não é versionado.

Auditoria completa (o que existe, o que falta e o pipeline Blender→Studio):
[`docs/ferramentas.md`](docs/ferramentas.md). Ferramentas CLI extras (luau-lsp, Lune, Pesde,
rbxcloud, git-lfs, oxipng, Blender 4.5) já estão instaladas em `~/.local/bin`.

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
