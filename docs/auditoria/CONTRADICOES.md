# CONTRADICÕES — diagnóstico temporário (fase 2)

> Este arquivo **deve desaparecer**. Cada linha vira commit de correção ou pergunta respondida.
> Gerado em 09/11/2026 a partir da radiografia (`.context/radiografia.md`).

## Resolvidas nesta rodada

| # | Onde | Contradição | Resolução |
|---|---|---|---|
| C1 | `README.md` | descrevia o jogo de moedas como se fosse o produto | README reescrito para a Muralha; protótipo marcado como legado |
| C2 | `docs/tese-produto-e-economia.md:152,210` | "3 cercos/dia" e "timer" | alinhado a cercos livres + 3 Grandes Saques |
| C3 | `docs/gdd-muralha.md:218` | fase P2 listava "energia" | trocado por "loja"; energia segue rejeitada |
| C4 | `docs/tese-produto-e-economia.md:207` | "grid 9×9" | alinhado a 5×5 (expansível a 7×5) |
| C5 | `docs/gdd-muralha.md:43` | "+3 moedas" no drop-in | trocado por "ouro" |
| C6 | `docs/padroes-engenharia.md:120` | schema com `coins` | trocado por `gold` |
| C7 | `docs/spec...:263` vs GDD | PoC com 1 armadilha/lane vs grade 5×5 | nota de recorte: PoC prova o motor, não é a arquitetura |

## Abertas — precisam de decisão humana

| # | Pergunta | Evidência | Opções |
|---|---|---|---|
| Q1 | O protótipo de moedas em `src/**` é descartado na P1? | `src/server/CoinService.luau` (172 linhas) não tem relação com a Muralha · evidência: [pesquisa §3](../pesquisa-grade-e-prototipo.md) | (a) apagar na P1 · (b) manter como cena de teste de pipeline |
| Q2 | A grade de produção é 5 colunas × 5 linhas com armadilhas **por célula**, e 5 lanes de caminhada (várias armadilhas por lane)? | spec §4 diz 5×5; PoC usa 1 por lane · evidência: [pesquisa §2](../pesquisa-grade-e-prototipo.md) | (a) confirmar 25 células · (b) manter 5 slots (1 por lane) no MVP |

## Regra de saída

Quando Q1 e Q2 forem respondidas: aplicar a correção, apagar este arquivo e registrar a decisão em
`docs/gdd-muralha.md` (se for design) ou `.context/REJEITADOS.md` (se for descarte).
