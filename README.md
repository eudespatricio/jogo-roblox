# jogo-roblox — MURALHA

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

## Regras que não se negociam

1. Servidor é a fonte da verdade; o cliente só manda intenção.
2. Poder só se ganha jogando; Robux compra cosmético.
3. Nenhuma unidade obrigatória (mata gatekeeping).
4. Replay do passado, não gravação do futuro.
5. Contexto residente tem teto; contradição vira teste, não markdown eterno.
