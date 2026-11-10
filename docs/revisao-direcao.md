# Revisão de direção — 09/11/2026

> Pedido original: *"vamos criar um jogo como se a nossa vida dependesse dessa fonte de renda, não
> vamos entrar pra brincar, vamos entrar pra ganhar de verdade… antes de montar qualquer coisa, temos
> que buscar mais dados que corroborem a nossa direção e depois usar a criatividade, derrepente um
> mix de gêneros em um game só."*
>
> Time: 1 humano + 2 agentes (eu e o Antigravity). Este documento responde a uma pergunta só:
> **estamos no caminho certo?** Ele não decide P0, não muda o GDD e não escolhe preço.
> Neste documento, **R$ = Robux** e **BRL = reais**.

---

## 1. O que o pedido exige (e o que ele não exige)

| Exige | Não exige |
|---|---|
| receita real, não portfólio | gráfico bonito |
| evidência antes de construir | certeza antes de testar |
| criatividade/mix como diferencial | gênero novo por si só |
| execução de time pequeno | escopo grande |
| decisão go/no-go fria | apego ao conceito |

O erro que este documento tenta evitar: **confundir "nós conseguimos construir" com "as pessoas vão
jogar e pagar"**.

---

## 2. O que já foi feito — e o que cada peça prova

| Artefato | Prova | **Não prova** |
|---|---|---|
| GDD v1.1 | clareza de design, decisões fechadas | que alguém quer jogar |
| Motor em `sim/` | determinismo, performance, 10 invariantes | diversão, retenção |
| Pesquisa de mercado | gênero grande, Strategy com teto alto | que a Muralha vence a concorrência |
| Pesquisa Q1/Q2 | grade defensável; protótipo descartável | que 25 células é melhor que 5 slots |
| Pesquisa de monetização | preços e canais do mercado | conversão e ARPPU do **nosso** jogo |
| Modelo financeiro | a matemática da cadeia | as premissas (hoje de topo) |

**Conclusão parcial:** provamos **engenharia** e **coerência de design**. Não provamos **demanda**,
**diversão** nem **disposição de pagar**. O caminho técnico está à frente do caminho de produto.

---

## 3. Onde a direção está apoiada (o que os dados realmente sustentam)

1. **Strategy tem o teto mais alto da plataforma.** 14,8% das experiências de Strategy passam de
   1.000 CCU, contra 8,9% de Simulation e 4,3% de Obby ([ROLearn](https://intelligence.rolearn.dev/reports/roblox-genre-ccu-benchmarks-2026)).
2. **TD é gênero provado.** 30 jogos, 22,9 bi de visitas, 93% de like médio, 88 mil jogando
   ([rblxdb](https://rblxdb.com/best-roblox-games/tower-defense)).
3. **A dor que a Muralha ataca é real.** Leaver, gatekeeping e dependência de time estão
   documentados no TDS; solo-first + assíncrono resolve isso ([pesquisa-jogadores.md](pesquisa-jogadores.md)).
4. **Replay do passado é diferencial de verdade.** O motor determinístico entrega o clipe que a
   Video Captures API não entrega; isso é prova técnica e argumento de marketing.
5. **Sem avatar = custo de arte baixo + elegibilidade ao DevEx 18+.** O bônus é real, mas menor do
   que parece: +4,2% de receita com 10% do gasto elegível ([pesquisa-monetizacao.md](pesquisa-monetizacao.md) §5.1).

---

## 4. As seis apostas que ainda não foram testadas

| # | Aposta | Evidência hoje | Como testar | Custo |
|---|---|---|---|---|
| 1 | O loop assíncrono é **divertido** | PoC prova determinismo, não fun | greybox com 20–30 jogadores | 1 semana |
| 2 | O jogador **entende** "TD invertido" em 5s | nenhum teste; a diferenciação é difícil de explicar | 3 thumbnails/títulos + ads | US$ 150–300 |
| 3 | **Cosmético-only paga** | o gênero cobra poder; DTI é identidade/avatar | teste de oferta com 3 preços | 1 semana |
| 4 | **Fantasma/liquidez** funciona no início | nenhum teste; async defense no Roblox é nicho | pool com bots + pergunta "volto amanhã?" | 1 semana |
| 5 | **25 mil DAU** é alcançável | top 3 do TD = 54% dos jogadores | ads + D1 | 2 semanas |
| 6 | O time entrega em **12 semanas** | engine pronto; UI/arte não começaram | primeiro milestone da P0 | contínuo |

Nenhuma dessas apostas se resolve com mais documento. Todas se resolvem com **jogo na mão de
jogador**.

---

## 5. A matemática da vida (o teste mais duro)

Premissas do modelo: 70% de repasse, DevEx misto 0,2352 por dólar gasto, câmbio 5,4.

| Cenário | Pagantes/mês | ARPPU | Líquido/DAU/mês | DAU para BRL 10 mil | para BRL 20 mil | para BRL 50 mil |
|---|---:|---:|---:|---:|---:|---:|
| **Base realista** | 2% | US$ 2 | US$ 0,047 | **39,4 mil** | **78,7 mil** | **196,8 mil** |
| **Topo do mercado** | 4,5% | US$ 5 | US$ 0,265 | **7,0 mil** | **14,0 mil** | **35,0 mil** |

> **Atualização (09/11/2026):** a decisão fixou 10% de gasto 18+ elegível (22,2% líquido). Com isso,
> os DAUs sobem ~6%: BRL 10 mil exige ~41,8 mil DAU na base e ~7,4 mil no topo. Ver
> [decisao-monetizacao.md](decisao-monetizacao.md).

Leituras:

1. O cenário "Negócio" do modelo (25 mil DAU, BRL 35,7 mil) **não exige escala de topo** — é um TD
   de porte médio, abaixo dos três primeiros. Mas exige **monetização de topo** (4,5% pagantes × US$ 5).
2. É a combinação mais difícil: **jogo médio com monetização de hit**. Ou o jogo é muito mais
   viciante que a média, ou a monetização é mais agressiva — e o GDD proíbe a segunda.
3. Com premissas base, BRL 50 mil/mês exige **~197 mil DAU** — escala de top-100 da plataforma.
   BRL 10 mil/mês exige ~39 mil DAU. Nenhum dos dois é impossível; ambos são **planos de escala**,
   não de lançamento.

**O buraco:** o plano atual não escolhe entre "volume" e "monetização de topo". Ele assume os dois.

---

## 6. Veredito

| Dimensão | Nota | Por quê |
|---|---|---|
| **Engenharia** | **caminho certo** | motor determinístico, invariantes, custo por batalha baixo |
| **Design** | **caminho certo** | loop coerente, escopo enxuto, decisões documentadas |
| **Produto** | **não provado** | ninguém jogou; entendimento e diversão são hipóteses |
| **Receita** | **aposta, não plano** | cosmético-only sem prova no gênero; modelo de topo |
| **Escala** | **não provada** | TD concentrado; aquisição é o gargalo, não o código |

**Resposta curta:** estamos no caminho certo **de construção**, mas ainda não no caminho certo **de
negócio**. A P0 mecânica (portar o motor para `src/shared/sim/` + CI) é baixo risco e pode andar em
paralelo; o que não pode começar é a **P1 de conteúdo/loja** antes do teste — seria otimizar a coisa
errada: mais jogo para um produto cuja demanda e monetização não foram testadas.

**Não é hora de pivotar.** Pivotar sem dados é tão irresponsável quanto construir sem dados. É hora
de um **teste de produto de 3 semanas**, barato, que possa matar ou confirmar as apostas 1–5.

---

## 7. O experimento de 3 semanas (antes da P1)

Orçamento: **US$ 300–500** (ads + incentivo para playtesters). Nada de arte final, nada de loja real.

### Semana 1 — greybox jogável
- 5 armadilhas, 1 raid, replay de 8s, 1 upgrade, 1 tela de resultado.
- Reaproveitar `src/shared/sim/core.luau` para a batalha; UI mínima.
- 3 criativos: (a) "defenda sua muralha", (b) "ataque a muralha dos outros", (c) "veja o replay do
  ataque que você perdeu".
- Meta: um jogador consegue jogar sem instrução em **≤ 60s**.

### Semana 2 — aquisição e entendimento
- US$ 150–300 em anúncio no Roblox, 3 criativos, público amplo.
- Medir: CTR, bounce < 60s, primeira vitória, D1 (24h), "o que você faz neste jogo?" em 1 frase.

### Semana 3 — diversão e disposição de pagar
- 20–30 sessões observadas (Discord/comunidade), 10–15 min cada.
- Mostrar 3 ofertas hipotéticas: passe 499 R$, skin 199 R$, bundle de efeitos 299 R$; perguntar
  "qual você compraria?" e "por quê?".
- Sondar o mix: "o que faria você voltar amanhã?" (coleção? ranking? revanche?).

### Critérios (definidos antes, não depois)

| Métrica | Aprova | Reprovada | Se reprovar |
|---|---:|---:|---|
| Entendimento em 1 frase | ≥ 70% | < 50% | reposicionar título/thumbnail/tutorial |
| Primeira vitória < 60s | ≥ 70% | < 50% | simplificar o primeiro cerco |
| "Jogaria de novo" | ≥ 60% | < 40% | mudar o loop (coleção/identidade) |
| Escolhe uma oferta | ≥ 25% | < 10% | repensar monetização (conveniência/assinatura) |
| D1 (24h) | ≥ 10% (sinal; gate da P2 é 15%) | < 5% | onboarding e motivo diário |
| CTR do melhor criativo | melhor que a mediana dos 3 | empate | a fantasia não vende; reposicionar |

**Regra de ouro:** não confundir "não vendeu" com "não é divertido". Cada falha tem um conserto
diferente; o experimento separa as duas.

---

## 8. Onde a criatividade entra (o mix que falta)

A Muralha já é um mix (TD + autobattler + assíncrono). O que falta não é **outro** gênero — é a
**perna de identidade/coleção** que faz o Roblox reter e monetizar:

| Mix candidato | O que adiciona | Custo de arte | Evidência |
|---|---|---|---|
| **A. Muralha + coleção de blueprints** | cartas de layout, troca, raridade | baixo (cards 2D) | coleção/trading é o motor do Roblox (Adopt Me, Pet Sim, Grow a Garden) |
| **B. Muralha + assalto** | tensão de atacar, loot, clipe | médio (avatares) | extraction/heist é a onda "friendslop" |
| **C. Muralha + base cozy** | decoração, cenário, skins | baixo-médio | Garden TD: 98% de like, público mais amplo |

**Não escolher agora.** O experimento da §7 diz se o loop base passa. Só depois vale testar o mix —
e o critério deve ser o mesmo: retenção e disposição de pagar, não gosto pessoal.

O candidato **A** é o mais barato e o mais alinhado ao Roblox, porque transforma o layout em
**coleção**, dá motivo de troca e cria uma superfície cosmética que não depende de avatar.

---

## 9. O que não fazer agora

- P1 completo, 25 armadilhas, 7×5, co-op, lore, avatar.
- Loja real e preço final antes do teste de oferta.
- Mais uma rodada de pesquisa de mesa sem jogador.
- Pivotar o conceito por ansiedade.

---

## 10. O que mudaria o veredito (falsificadores)

| Se… | Então… |
|---|---|
| o greybox passar nos critérios da §7 | P0 autorizada, com escopo travado |
| entendimento < 50% e diversão alta | reposicionar a fantasia (título/thumbnail/tutorial), não o jogo |
| diversão < 40% e entendimento alto | mudar o loop (coleção/identidade) antes da P0 |
| oferta < 10% | monetização por conveniência/assinatura, não cosmético puro |
| D1 < 5% | o problema é retenção, não aquisição; não gastar mais em ads |
| CTR baixo nos 3 criativos | a fantasia não vende; repensar o pitch antes de qualquer código |

---

## 11. Fontes

- [ROLearn — Genre CCU Benchmarks 2026](https://intelligence.rolearn.dev/reports/roblox-genre-ccu-benchmarks-2026) (out/2026)
- [rblxdb — Tower Defense](https://rblxdb.com/best-roblox-games/tower-defense) (09/11/2026)
- [GameAnalytics — 2026 Roblox Benchmark Report](https://www.gameanalytics.com/reports/2026-roblox-report) (set/2026)
- [Roblox Q3 2026 earnings](https://www.fool.com/earnings/call-transcripts/2026/10/30/roblox-rblx-q3-2026-earnings-call-transcript/) (30/10/2026)
- [pesquisa-jogadores.md](pesquisa-jogadores.md) · [pesquisa-grade-e-prototipo.md](pesquisa-grade-e-prototipo.md) ·
  [pesquisa-monetizacao.md](pesquisa-monetizacao.md) · [tese-produto-e-economia.md](tese-produto-e-economia.md)
- [GDD](gdd-muralha.md) · [modelo-financeiro.xlsx](modelo-financeiro.xlsx) · [spec do motor](spec-motor-deterministico.md)

### Nota sobre estimativas de receita de terceiros

O [RoWatcher estima o TDS](https://rowatcher.com/games/1176784616/tower-defense-simulator) em
**US$ 2.916/mês** com 20 mil CCU e 4,6 bi de visitas — o que é implausível (a mesma fonte estima
[Steal a Brainrot](https://rowatcher.com/games/7709344486/steal-a-brainrot) em US$ 1,4 mi/mês com
205 mil CCU). Estimativas de terceiros não servem para calibrar receita; só o Creator Analytics do
próprio jogo serve.

---

## 12. Decisão do diretor (09/11/2026)

O veredito da §7 recomendava o teste de produto **antes** da P1. Em 09/11/2026 o diretor decidiu
seguir com a **P1 autorizada** em paralelo ao teste; o plano está em [`p1-plano.md`](p1-plano.md) §6.
Esta nota registra a decisão humana sobre a recomendação — não a apaga.

