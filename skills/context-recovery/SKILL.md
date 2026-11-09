---
name: context-recovery
description: Auditoria determinística de repositório que transforma caos documental em testes executáveis e contexto residente enxuto. Use ao iniciar trabalho em projeto existente, ao assumir repositório herdado ou quando docs e código divergirem.
---

# context-recovery

Protocolo portátil para revisar um projeto antes de executar. A lente é sempre a mesma;
a implementação muda com a linguagem (aqui: Luau/Roblox).

## Princípio

> Markdown de auditoria é **artefato de transição**, não memória permanente.
> Contradição vira commit. Invariante vira teste. Só o contexto residente mínimo fica.

Memória passiva em `.md` no contexto do agente custa tokens, gera dupla verificação e apodrece.
O valor está em **compilar** a intenção em algo que o CI cobra sozinho.

## Camadas

| Camada | Portátil? | Destino |
|---|---|---|
| Protocolo (este arquivo + `scan_repo.py` + templates) | sim | pasta global de skills |
| Artefatos de transição (`CONTRADICOES.md`) | não | morre ao fechar as linhas |
| Contexto residente (`ESTADO`, `MAPA`, `REJEITADOS`) | template fixo, conteúdo local | `.context/`, com teto de linhas |

## Fase 1 — Radiografia (zero LLM, custo zero)

```bash
python scan_repo.py --root . --ast <caminho-do-luau-ast> \
  --out .context/radiografia.md --json .context/radiografia.json
```

Coleta: topografia de código e docs, idade por último commit, símbolos (AST do Luau), órfãos de
teste, configs, alertas (monolitos, docs defasados, zero oráculos). Nenhuma inferência.

## Fase 2 — Triangulação (a IA entra)

Hierarquia de autoridade: **decisão humana > código + teste > documento por data**.

1. Compare cada doc com o que a radiografia provou (constantes, fluxos, assinaturas).
2. Escreva a tabela `CONTRADICOES.md`: onde, o que diz, o que o código faz, gravidade.
3. Entreviste o autor com no máximo 5 perguntas — o agente **não adivinha** intenção.
4. Separe o que é contradição de doc (resolve sozinho) do que é decisão de produto (pergunta).

## Fase 3 — Compilação (texto vira código)

- Cada linha de `CONTRADICOES.md` vira patch e é apagada.
- Cada invariante vira teste executável (aqui: `sim/invariants.luau`, roda no Luau CLI).
- Regra que não dá para testar vira **pergunta**, não parágrafo.
- Teste que falha por estar errado também é achado: conserte o teste, não a regra.

## Fase 4 — Contexto residente

| Arquivo | Teto | Regra |
|---|---|---|
| `ESTADO.md` | 80 linhas | sobrescrito, nunca append |
| `MAPA.md` | 60 linhas | 1 linha por responsabilidade + armadilhas |
| `REJEITADOS.md` | 40 linhas | toda linha tem "reabre se" |

Mais `AGENTS.md` na raiz apontando para eles. Nada além disso.

## Adaptação para Luau/Roblox

- `luau-ast` dá símbolos reais (funções, requires) sem executar código.
- `luau` roda testes headless sem Studio — use isso como oráculo de CI.
- Regras de Roblox que viram teste: `bit32` só recebe `[0, 2^32)`, estado inteiro, cap de ticks,
  resultado dentro da faixa, `simVersion` obrigatório no replay.
- Regras que **não** viram teste unitário (DataStore, sessão, exploit) viram checklist de PR citando
  a doc oficial, não markdown solto.

## Critérios de saída

1. `CONTRADICOES.md` vazio ou inexistente.
2. `invariants` verde no CI.
3. `--check` dos tetos verde.
4. Radiografia sem "doc defasado" inexplicado.
5. `REJEITADOS.md` com decisões datadas e condição de reabertura.

## Anti-padrões

- Manter `INVARIANTES.md` permanente: vira dupla verificação e custa contexto.
- Listar contradição sem dono/decisão: vira arquivo morto.
- Auditar sem scanner: opinião disfarçada de fato.
- Reescrever o mundo: a saída é o mínimo viável de contexto, não um manual.
