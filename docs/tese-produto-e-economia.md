# Tese de produto e economia — novembro de 2026

Complemento ao [`pesquisa-tendencias-2026.md`](pesquisa-tendencias-2026.md). Aqui o objetivo não é
listar gênero: é decidir **o que construir para virar receita**, com matemática explícita.

---

## 1. O que mudou desde a primeira pesquisa (e muda a estratégia)

Três movimentos da Roblox em 2026, todos na mesma direção:

| Mudança | O que é | Consequência para nós |
|---|---|---|
| **DevEx 18+ US** | Jogo elegível recebe **US$ 0,54 por 100 Robux ganhos** em gasto de jogador 18+ verificado nos EUA, contra US$ 0,38 (+42%) | receita ~42% maior no segmento que mais gasta |
| **Standout Games** | vitrine curada na Home para "novel games": mecânicas novas, visual distinto ou **gênero sub-representado** | exposição sem depender de sorte no algoritmo |
| **Age Check API** | `Player:PromptAgeCheck()` + `Player.AgeChecked` (out/2026) | podemos converter jogador em "18+ elegível" dentro do jogo |

Elegibilidade do DevEx 18+ (confirmada no anúncio oficial):

- avatares **sempre R15**; **ou** rig customizado human-form com 15+ juntas; **ou** rig não-humano;
- **ou nenhum personagem de jogador visível** — puzzles, estratégia e card games se qualificam;
- sem candidatura: é automático se o jogo cumpre o requisito;
- vale para passes, developer products, assinaturas e servidores privados.

Fonte: [DevForum — US 18+ DevEx Rate](https://devforum.roblox.com/t/introducing-the-us-18-devex-rate-earn-42-more-on-spend-from-18-us-players/4607091)

> **A brecha:** um jogo de estratégia/puzzle sem avatar visível qualifica para o rate maior **e**
> é justamente o tipo de jogo que a Roblox está promovendo — e que custa menos arte para produzir.

---

## 2. O que os dados dizem sobre dificuldade (GameAnalytics 2026)

Base: 500+ jogos com 1M+ MAU, ago/2025 a jul/2026 ([relatório](https://www.gameanalytics.com/reports/2026-roblox-report)).

| Métrica | Mediana | p90 | Leitura |
|---|---|---|---|
| Retenção D1 | **10,3%** | — | 9 em 10 nunca voltam no dia seguinte |
| Retenção D7 | 1,6% | — | |
| Retenção D30 | 0,5% | — | |
| Sessão média | 9,8 min | 14,7 min | |
| Sessões/jogador/dia | 1,56 | 3,22 | jogo diário tem vantagem estrutural |
| Jogadores que pagam | **3,8%** | — | |
| Receita por pagante | US$ 0,70 | US$ 2,33 (p90) · US$ 55,31 (p99) | monetização é concentrada |

**Isso não é motivo para desistir — é a régua.** A meta não é bater a mediana; é bater o p99 em
retenção (onde o algoritmo e a receita vivem).

Outro dado do mesmo relatório: desde agosto/2026 a descoberta premia **retenção e monetização
juntas**, não uma ou outra. Jogo que só retém não escala; jogo que só monetiza é enterrado.

---

## 3. A matemática do dinheiro

O caminho do dinheiro no Roblox:

```
jogador gasta US$ 1  →  80 Robux  →  criador ganha 70% (56 R$)  →  DevEx
                                                        base: US$ 0,0038/R$ = US$ 0,213
                                                        18+ US: US$ 0,0054/R$ = US$ 0,302
```

Com 25% do gasto vindo de 18+ verificado nos EUA, a **receita líquida é ~23,5% do que o jogador
gasta**. O resto é taxa da plataforma, custo do Robux e imposto cambial.

### Quanto precisa para viver disso

Premissas: ARPPU US$ 5/mês, 4% de pagantes, DAU/MAU 0,20, câmbio R$ 5,40.

| Meta mensal | Gasto bruto necessário | Pagantes | MAU | DAU |
|---|---|---|---|---|
| R$ 3.000 | US$ 2.362 | 472 | 11.810 | **2.362** |
| R$ 5.000 | US$ 3.937 | 787 | 19.684 | **3.937** |
| R$ 10.000 | US$ 7.874 | 1.575 | 39.368 | **7.874** |
| R$ 20.000 | US$ 15.747 | 3.149 | 78.736 | **15.747** |
| R$ 50.000 | US$ 39.368 | 7.874 | 196.840 | **39.368** |

**Leitura dura:** R$ 10 mil/mês exige ~8 mil jogadores ativos por dia — com retenção e monetização
acima da mediana. Não é um fim de semana de trabalho; é um produto com live ops.

### Cenários

| Cenário | DAU | % pagantes | ARPPU | Receita/mês (BRL) | Leitura |
|---|---|---|---|---|---|
| Hobby validado | 2.000 | 2% | US$ 2 | ~R$ 508 | prova o loop, não paga contas |
| Pé de meia | 8.000 | 3% | US$ 3,50 | ~R$ 5.334 | primeiro salário parcial |
| **Negócio** | **25.000** | **4,5%** | **US$ 5** | **~R$ 35.721** | meta realista de 12 meses |
| Escala | 80.000 | 6% | US$ 8 | ~R$ 243.855 | top 200 da plataforma |
| Outlier | 300.000 | 9% | US$ 15 | ~R$ 2,57 mi | top 10; loteria, não plano |

Modelo editável: [`modelo-financeiro.xlsx`](modelo-financeiro.xlsx) — abas Premissas, Cenários,
Metas e Sensibilidade (DAU × ARPPU).

---

## 4. A brecha: onde a Roblox quer que a gente entre

Critérios oficiais do [Standout Games](https://github.com/roblox/creator-docs/blob/031a0e3f6a63691e74e2e88e74a5565e3c22ae26/content/en-us/creator-programs/standout-games.md):

> "RPG, estratégia, puzzle e shooter são **fortemente sub-representados** apesar da demanda forte
> de faixas etárias mais velhas. Procuramos jogos ousados nesses gêneros, além de **mash-ups
> inesperados** e projetos que misturam mecânicas tradicionais com avatares, social e cross-platform."

E o que **não** passa: "jogos que parecem cópia ou reskin de um jogo popular do Roblox são difícil venda".

Ou seja, a plataforma está literalmente pedindo o que o nosso perfil (3 agentes, pouca arte,
muito sistema) consegue fazer melhor: **estratégia densa com visual próprio**, não mais um
simulador 3D de brainrot.

---

## 5. Evidência de que hibridização funciona

| Jogo | Mundo A | Mundo B | Resultado |
|---|---|---|---|
| Steal a Brainrot | tycoon | PvP de roubo | 74,4B visitas |
| Grow a Garden | idle/grow | trading social | 36B visitas |
| 99 Nights in the Forest | survival | coop de grupo | 30,5B visitas |
| Dead Rails | extraction | horror | 6,6B visitas |
| Fisch | pesca | coleção/RPG | 5,1B visitas |
| Dress to Impress | moda | rodadas + votação | 11,3B visitas |
| BedWars | PvP | construção de base | 11,8B visitas |
| Illegal Soccer | futebol | caos/física | ~150M plays em poucas semanas |

**Padrão:** o híbrido não soma dois gêneros — ele usa um gênero como **linguagem** (todo mundo
entende futebol, torre, tiro) e o outro como **profundidade** (estratégia, construção, economia).
A linguagem traz o clique; a profundidade traz o dia 8.

---

## 6. Critérios de design derivados dos dados

1. **Entendível em 6 segundos de vídeo** — vídeo na Home deu +39% de playtime ([DevForum](https://devforum.roblox.com/t/how-we-are-improving-home-this-year/4502571)).
2. **Primeiro objetivo em < 30s** — o sinal de bounce mede 61–180s.
3. **Motivo diário explícito** — sessões medianas 1,56/dia; o jogo precisa caber em 3 check-ins.
4. **Meta de 7 dias** — o algoritmo mede "sessões qualificadas em 7 dias".
5. **Melhor com amigo** — coop é sinal medido; mas não obrigatório no MVP.
6. **Monetização no caminho, não em popup** — retenção e receita contam juntas desde ago/2026.
7. **Sem avatar visível ou R15** — habilita +42% de DevEx no gasto 18+ US.
8. **Visual que faça pensar "isso é Roblox?"** — critério explícito de curadoria.

---

## 7. Quatro conceitos (fórmula: mundo A + mundo B)

### A. MURALHA — tower defense invertido + autobattler assíncrono

- **Fórmula:** TD (linguagem universal no Roblox) + estratégia assíncrona (profundidade).
- **Loop:** você monta a muralha, as armadilhas e a onda de ataque; outros jogadores atacam sua
  muralha enquanto você está offline. Ao voltar, vê o relatório da batalha e ajusta.
- **Sessão:** cercos livres de 5–8 min + 3 Grandes Saques/dia.
- **Monetização:** passe de temporada, cosméticos de muralha, slots de esquadrão, "revanche".
- **Por que encaixa:** sem avatar visível (qualifica 18+), câmera isométrica barata de produzir,
  clipe de 6s perfeito (muralha explodindo), retenção por timer/assíncrono.
- **Risco:** confundirem com TD comum — a diferenciação é o PvP assíncrono e o relatório de batalha.

### B. A FORJA — roguelike deckbuilder + autobattler com seed diária

- **Fórmula:** Slay the Spire (run) + TFT (composição) + Wordle (mesma seed para todos).
- **Loop:** run diária de 10 min com seed global; ranking de quem foi mais longe; coleção persistente.
- **Monetização:** personagens, cartas cosméticas, passe, runs extras.
- **Por que encaixa:** retenção Diária quase artificial, social por comparação, custo de arte baixo.
- **Risco:** D1 mais fraco (autobattler exige entender), TAM menor no Roblox jovem.

### C. O GOLPE — heist coop 2–4 (extraction + puzzle)

- **Fórmula:** extraction (risco/perda) + puzzle cooperativo (comunicação).
- **Loop:** 12 min para invadir, resolver, pegar e extrair; fracasso perde o loot.
- **Monetização:** ferramentas, cosméticos, passe.
- **Por que encaixa:** friendslop é a onda externa mais forte; clipe fácil; retenção alta.
- **Risco:** precisa de avatar (R15), arte, áudio e netcode — o mais caro dos quatro.

### D. A COLÔNIA — colony sim + survival assíncrono

- **Fórmula:** RimWorld-lite (gestão) + ataques de outros jogadores offline.
- **Loop:** gerir colônia, sobreviver a inverno/ataques, expandir.
- **Monetização:** aceleração, cosméticos, slots.
- **Por que encaixa:** profundidade máxima, sem avatar, retenção D30 altíssima.
- **Risco:** D1 ruim (planilha não converte clique) e UI complexa para mobile.

### Score ponderado

Pesos: retenção 30%, novidade 20%, monetização 20%, custo 20%, viral 10%. Notas 1–5.

| Conceito | Novidade | Retenção | Monetização | Custo | Viral | **Score** |
|---|---|---|---|---|---|---|
| **A. Muralha** | 4 | 5 | 5 | 4 | 4 | **4,50** |
| B. A Forja | 5 | 5 | 4 | 4 | 3 | 4,40 |
| D. A Colônia | 5 | 5 | 4 | 3 | 2 | 4,10 |
| C. O Golpe | 4 | 4 | 4 | 2 | 5 | 3,70 |

---

## 8. Recomendação

**Construir A MURALHA, com a seed diária de B como segundo modo (a partir do mês 3).**

Racional em uma frase: é o único conceito que combina **linguagem de massa** (torre/defesa),
**profundidade de estratégia** (o gênero que a Roblox quer promover), **custo de arte baixo**
(sem avatar, câmera fixa) e **elegibilidade ao DevEx 18+** — e ainda gera clipe de 6 segundos.

O modo diário da Forja entra depois como camada de retenção, não no MVP. Escopo é o inimigo.

### MVP — 30 dias, um modo

1. Muralha editável (grid 5×5, expansível a 7×5), 6 armadilhas, 4 unidades.
2. Uma onda de ataque controlada por IA + "fantasma" de outro jogador (assíncrono).
3. Relatório de batalha (o momento de "voltar amanhã").
4. Loop de cercos livres + 3 Grandes Saques/dia (sem timer).
5. Tutorial de 25 segundos, sem texto (ícones + setas).
6. Analytics desde o primeiro build: D1, sessão, bounce, funil de 60s/180s.

### Gates para continuar (medir com 300–500 jogadores via anúncio de US$ 100)

| Métrica | Gate | Se não bater |
|---|---|---|
| D1 | ≥ 15% | refazer onboarding e primeiro cerco |
| D7 | ≥ 3% | adicionar meta semanal e recompensa de retorno |
| Bounce < 3 min | ≤ 40% | encurtar tutorial, dar vitória rápida |
| Sessão média | ≥ 8 min | reduzir fricção de UI mobile |
| Pagantes | ≥ 2% | reposicionar loja (cosmético antes de poder) |

### 90 dias

- **Semanas 1–4:** MVP acima + build público não listado.
- **Semanas 5–8:** meta (coleção, upgrades), liga semanal, localização PT/EN/ES.
- **Semanas 9–12:** monetização (passe, cosméticos), vídeo de gameplay, aplicação ao Standout,
  `PromptAgeCheck()` no momento de recompensa, campanha de criadores.
- **Semana 13:** decisão go/no-go com os gates acima — sem apego.

### Divisão dos três agentes

| Agente | Papel |
|---|---|
| Você | direção, design, QA de diversão, comunidade, decisões de corte |
| Eu | arquitetura, sistemas, servidor autoritativo, analytics, economia |
| Antigravity | implementação paralela, refactor, testes, ferramentas de build |

---

## 9. O que pode matar o projeto

| Risco | Probabilidade | Mitigação |
|---|---|---|
| Público jovem não entender estratégia | média | tutorial sem texto + primeira vitória em 60s |
| Confundirem com TD genérico | alta | PvP assíncrono como herói do vídeo/ícone |
| Economia/anti-cheat do assíncrono | média | servidor autoritativo desde o dia 1, sem confiar no cliente |
| DevEx 18+ exigir revisão de elegibilidade | baixa | conferir no verificador oficial antes do lançamento |
| Custo de aquisição comer a margem | média | crescer por criador/clipe, não só por anúncio |
| Escopo inflar | alta | um modo, 6 armadilhas, 4 unidades. Nada além. |

---

## 10. Fontes

- [DevForum — US 18+ DevEx Rate](https://devforum.roblox.com/t/introducing-the-us-18-devex-rate-earn-42-more-on-spend-from-18-us-players/4607091) (abr–out/2026)
- [GameAnalytics — 2026 Roblox Benchmark Report](https://www.gameanalytics.com/reports/2026-roblox-report) (set/2026)
- [Roblox Creator Docs — Standout Games](https://github.com/roblox/creator-docs/blob/031a0e3f6a63691e74e2e88e74a5565e3c22ae26/content/en-us/creator-programs/standout-games.md)
- [DevForum — How we are improving Home this year](https://devforum.roblox.com/t/how-we-are-improving-home-this-year/4502571) (mar–jul/2026)
- [Tubefilter — Roblox hikes developer earnings by 42%](https://www.tubefilter.com/2026/05/01/roblox-hikes-developer-earnings-by-42-but-only-if-they-make-games-aimed-at-adults/amp/)
- [GamesHub — Roblox's six 18+ games](https://www.gameshub.com/news/article/roblox-18-plus-games-drifters-bungie-co-founder-2885233/) (jun/2026)
- [Newzoo — Top Roblox experiences of 2025](https://newzoo.com/articles/top-roblox-experiences-2025)
- [4Gamer — RDC 2026: algoritmo e Brookhaven](https://www.4gamer.net/games/612/G061218/20261021046/)
- [Pesquisa de monetização](pesquisa-monetizacao.md) (nov/2026) — preços, benchmarks e canais
