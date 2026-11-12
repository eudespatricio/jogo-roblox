# Pesquisa — monetização no mercado (nov/2026)

> 09/11/2026 · complementa [`tese-produto-e-economia.md`](tese-produto-e-economia.md) e
> [`modelo-financeiro.xlsx`](modelo-financeiro.xlsx). **Não é decisão de preço**: é o que o mercado
> faz, o que a plataforma permite e onde as premissas do projeto não fecham.
>
> **Decisão (09/11/2026):** base **2% de pagantes/mês × ARPPU US$ 2**; topo **4,5% × US$ 5**;
> gate **ARPDAU líquido ≥ US$ 0,005** (bruto ≈ 0,0225). Registro em
> [`decisao-monetizacao.md`](decisao-monetizacao.md).
>
> Níveis: **A** = oficial/primário · **B** = comunidade estruturada · **C** = estimativa/opinião.
> Neste documento **R$ = Robux** (como no GDD); reais aparecem como **BRL**.
>
> **Atualização regional (12/11/2026):** a pesquisa de ticket/ARPPU **fora do Brasil** está em
> [`pesquisa-monetizacao-regional.md`](pesquisa-monetizacao-regional.md). Este documento continua
> sendo o benchmark **global por jogo**; o novo separa receita/ABPDAU por região, dados do Brasil e
> a lacuna de ARPPU por país (GAP-013).

---

## Resumo

| # | Achado | Confiança |
|---|---|---|
| 1 | Os TDs do topo que examinamos monetizam **poder e sorte**; cosmético é complemento: torres de 168–1.574 R$, passes de sorte 79–699 R$, cosmético com teto de ~200–360 R$. | alta |
| 2 | O modelo financeiro assume **4% de pagantes/mês × US$ 5/mês** — combinação de topo (ARPPU no p95, pagantes acima da mediana). O cenário "Negócio" não é base. | alta |
| 3 | Gate **ARPDAU líquido ≥ US$ 0,005** (bruto ≈ 0,0225), decidido em 09/11/2026. Com 10% elegível, o "Negócio" dá **0,0083 líquido** / **0,0375 bruto**; a base 2% × US$ 2 dá 0,00148 e falha. | alta |
| 4 | Cosmético-only **não tem prova no TD**; tem prova em jogos de identidade (Dress to Impress, ~US$ 820 mil/mês estimados, confiança baixa). Sem avatar, a superfície da Muralha é a própria muralha. | média |
| 5 | O 18+ rende **+42% por dólar elegível**, mas o efeito misto é **+4,2%** (10% do gasto elegível) a **+10,5%** (25%) — não +42% no total. | alta |
| 6 | Canais subaproveitados: **assinatura em moeda local** (100% do repasse a partir do 2º mês), **Roblox Plus** (repasse efetivo 78–88% + 750 R$ por signup) e **regional pricing** automático. | alta |
| 7 | Os preços do GDD estão na faixa do mercado — passe 399–599 (TDS 399–499), skin 149–399 (ASTD 175–200), efeito 99–249 (TDS emote 55–85). Skin individual a 399 é o topo; bundle é o formato que o mercado usa. | média-alta |

---

## 1. Premissas do projeto × evidência

| Premissa | Onde está | O que a evidência diz | Status |
|---|---|---|---|
| **3,8% de jogadores pagam** | `modelo-financeiro.xlsx` B12, tratado como % mensal | GameAnalytics: **3,80% dos jogadores rastreados pagaram algo "across the period"** (ago/2025–jul/2026, 12 meses) | **provável 2–4x otimista como taxa mensal** |
| **ARPPU US$ 5/mês** | B11 | ARPPU mediano US$ 0,70 · p75 US$ 1,25 · p90 US$ 2,33 · **p95 US$ 4,80** · p99 US$ 55,31 | **p95, não mediana** |
| **ARPDAU ≥ US$ 0,02** | `gdd-muralha.md:187` | resolvido: gate **líquido ≥ 0,005**; "Negócio" 0,0083 líquido / 0,0375 bruto | **decidido** |
| **25% do gasto é 18+ US elegível** | B8 | 29% dos DAU *age-checked* globais são 18+; EUA/Canadá ~17% dos DAU (`pesquisa-tendencias-2026.md`) | **provável 2–3x otimista** |
| **DevEx US$ 0,0038 / US$ 0,0054** | B6/B7 | confirmado oficialmente (0,0038 desde 05/09/2025; 18+ 0,0054) | **correto** |
| **Criador fica com 70%** | B5 | confirmado (passes, dev products, assinaturas) | **correto** |
| **Cosmético-only sustenta a receita** | GDD §6 | os TDs do topo examinados cobram por poder; cosmético é complemento barato | **não validado** |

### 1.1 O que o número de pagantes realmente significa

O relatório da GameAnalytics mede "pagou algo **no período**" — 12 meses. O modelo usa o número
como se fosse **mensal**. Se a taxa mensal real for 1–2%, o modelo superestima pagantes em 2–4x.
Não há benchmark público de conversão mensal por jogo no Roblox; a única forma de saber é
instrumentar o próprio jogo (ver §8).

### 1.2 O que o ARPPU realmente significa

O relatório não explicita a unidade do ARPPU por jogo. Há duas leituras:

- **mensal**: US$ 0,70 mediano, US$ 4,80 no p95 → o modelo (US$ 5) está no p95;
- **acumulado em 12 meses**: o mensal seria ~US$ 0,06–0,40 → o modelo estaria 12–80x acima.

Em qualquer leitura, **US$ 5/mês é cenário de topo**, não base. O texto do relatório mistura
"across the period" (jogador) com ARPPU por jogo sem período — é uma ambiguidade da fonte, não
nossa; por isso o documento trata US$ 5 como **teto**, não como meta.

---

## 2. O que o mercado vende (e a que preço)

| Jogo | CCU | Like | O que vende | Faixa de preço (R$) | Modelo |
|---|---:|---:|---|---|---|
| **Tower Defense Simulator** | 12,7 mil | 94% | torres (poder), VIP, skins, emotes, passe, skip de nível | torres **168–1.574** · VIP 300 · skins (bundle 6–7) **300–360** · emotes 55–85 · passe **399–499** · skip total ~3.280–4.024 | poder + cosmético barato |
| **Toilet Tower Defense** | 7,1 mil | 86% | moeda, storage, sorte, VIP, clã, traits | **79–699**, todos poder/sorte | poder + sorte |
| **All Star Tower Defense** | 3,1 mil | 92% | displays cosméticos, VIP, velocidade, sorte | displays **175–200** · VIP 300 · speed **799** · shiny **1.200** | cosmético barato + poder caro |
| **Build Defense** | 652 | 93% | packs de construção, armas, coils | **99–999**; sessão média 0,6 min | base-building + packs |
| **Dress to Impress** | 156 mil | 90,5% | cosmético/identidade | não listado; receita estimada **US$ 820 mil/mês** (C) | cosmético puro |

Fontes: [TDS Gamepasses](https://tds.fandom.com/wiki/Gamepasses) · [TDS Passes](https://tds.fandom.com/wiki/Passes) ·
[rblxdb Toilet TD](https://rblxdb.com/games/changes-toilet-tower-defense-4778845442) ·
[rblxdb ASTD](https://rblxdb.com/games/og-all-star-tower-defense-1720936166) ·
[rblxdb Build Defense](https://rblxdb.com/games/build-defense-5678463488) ·
[RoWatcher DTI](https://rowatcher.com/games/5203828273/dress-to-impress).

### 2.1 O padrão de preço do gênero

| Categoria | Faixa observada | Quem cobra |
|---|---|---|
| **Poder** (torre, speed, sorte) | **79–1.574** (topo: 799–1.574) | Toilet, TDS, ASTD |
| **Passe de temporada** | **399–599** | TDS (399 na promoção, 499 cheio) |
| **Cosmético unitário/bundle** | **55–360** | TDS, ASTD |
| **Conveniência** (storage, slot) | **149–199** | Toilet, TDS |

**Leitura:** o mercado tem um **teto implícito para cosmético** (~200–360 R$) e um **piso alto para
poder** (~800 R$). A Muralha quer viver no primeiro andar — é possível, mas o volume tem de ser
muito maior, ou o item tem de ser percebido como identidade, não como enfeite.

### 2.2 O que o passe do TDS ensina

O Surf & Turf Battle Pass (jul–set/2025) tinha 40 níveis, trilha grátis e premium a **399 R$**
(499 sem promoção), com skins, emotes, nametags, crates e consumíveis. O skip individual somava
**~3.280–4.024 R$** — ou seja, o passe é barato e a **impaciência** é o produto caro.

Para a Muralha, isso sugere: passe a 399–499 é preço de mercado; **vender skip/catch-up** é onde o
gênero extrai receita de whale — e é exatamente o tipo de item que o GDD precisa decidir se aceita
(hoje não há skip).

---

## 3. Benchmarks de receita (GameAnalytics 2026)

Base: 500+ jogos com 1M+ MAU, ago/2025–jul/2026 ([relatório](https://www.gameanalytics.com/reports/2026-roblox-report)).

| Métrica | Valor | Leitura |
|---|---|---|
| Jogadores que pagaram algo no período | **3,80%** | janela de 12 meses, não mensal |
| ARPPU mediano | **US$ 0,70** | a maioria dos pagantes gasta pouco |
| ARPPU p75 / p90 / p95 | 1,25 / 2,33 / **4,80** | topo do mercado |
| ARPPU p99 | **55,31** | blockbusters; não é meta |
| Top 1% dos pagantes | **US$ 86,36** | concentração extrema |
| Sessão média por jogo | 9,8 min | compatível com raid de 5–8 min |

**Leitura:** o modelo do projeto usa, ao mesmo tempo, **pagantes acima da mediana** e **ARPPU no
p95**. Isso não é proibido — é uma escolha de cenário. Mas deve ser rotulado como cenário de topo,
não como "meta realista de 12 meses".

---

## 4. A conta do modelo, reconciliada

Cadeia do dinheiro (premissas atuais):

```
jogador gasta US$ 1 → 80 R$ → criador fica com 56 R$ (70%)
  → DevEx base 0,0038: US$ 0,2128
  → 18+ 0,0054:        US$ 0,3024
  → misto 25% elegível: US$ 0,2352   (23,5% do gasto)
  → misto 10% elegível: US$ 0,2218   (22,2% do gasto)
```

### 4.1 Quanto sobra por item

| Preço (R$) | Jogador paga (US$) | Estúdio recebe (25% elegível) | (10% elegível) |
|---:|---:|---:|---:|
| 99 | 1,24 | **0,29** | 0,28 |
| 149 | 1,86 | **0,44** | 0,41 |
| 199 | 2,49 | **0,59** | 0,55 |
| 249 | 3,11 | **0,73** | 0,69 |
| 299 | 3,74 | **0,88** | 0,83 |
| 399 | 4,99 | **1,17** | 1,11 |
| 499 | 6,24 | **1,47** | 1,39 |
| 599 | 7,49 | **1,76** | 1,66 |
| 799 | 9,99 | **2,35** | 2,22 |
| 1.200 | 15,00 | **3,53** | 3,33 |
| 1.574 | 19,68 | **4,63** | 4,37 |

**O número que importa:** um passe de 499 R$ deixa **~US$ 1,47** no estúdio. Para BRL 5 mil/mês
(~US$ 926 líquidos) são **~630 passes/mês**, sem contar outros itens.

### 4.2 Cenários a 25 mil DAU (125 mil MAU)

| Pagantes/mês | ARPPU | Bruto/mês | Líquido/mês | BRL/mês | ARPDAU líquido | ARPDAU bruto |
|---:|---:|---:|---:|---:|---:|---:|
| 1% | US$ 1 | 1.250 | 277 | 1.497 | 0,00037 | 0,0017 |
| 2% | US$ 2 | 5.000 | 1.109 | 5.988 | 0,00148 | 0,0067 |
| 2% | US$ 5 | 12.500 | 2.772 | 14.969 | 0,00370 | 0,0167 |
| **4,5%** | **US$ 5** | **28.125** | **6.237** | **33.680** | **0,00832** | **0,0375** |

### 4.3 O gate do ARPDAU (resolvido em 09/11/2026)

| Se o gate US$ 0,02 for… | ARPPU necessário a 2% | a 4,5% | Leitura |
|---|---:|---:|---|
| **líquido** (receita do estúdio) | US$ 127,55 | US$ 56,69 | p99; inatingível para cosmético |
| **bruto** (gasto do jogador) | US$ 6,00 | US$ 2,67 | plausível, mas o gate mede outra coisa |

**Decisão:** o gate passou a ser **ARPDAU líquido ≥ US$ 0,005** (≈ BRL 20,2 mil/mês a 25 mil DAU;
bruto ≈ 0,0225) e é reportado junto com o bruto. O "Negócio" passa com 0,0083 líquido; a base
2% × US$ 2 (0,00148) falha por 3,4×. Ver [`decisao-monetizacao.md`](decisao-monetizacao.md).

---

## 5. Mecânicas da plataforma que mudam a conta

| Mecânica | Regra | Efeito para a Muralha | Nível |
|---|---|---|---|
| **Regional pricing** | automático em passes/assinaturas; preço entre 30% e 100% do base; nunca acima | jogador BR paga menos; volume sobe, ARPPU por país cai | A |
| **Price optimization** | exige **60 mil transações/30 dias**; teste automático a cada 90 dias; não vale para assinaturas | só depois de tração; precificação inicial é manual | A |
| **Roblox Plus** | assinante tem 10–20% de desconto **pago pela Roblox**; repasse efetivo **78–88%**; assinantes gastam **7x** | aumenta receita por compra e traz público de maior gasto | A |
| **Comissão Plus** | **250 R$/mês por 3 meses** por signup feito no jogo (até 750 R$), retenção de 60 dias | canal extra: ~US$ 2,85 por signup | A |
| **Assinatura em R$** | ≥ 49 R$/mês; repasse 70%; regional pricing obrigatório | passe recorrente, mas sem o bônus da linha seguinte | A |
| **Assinatura em moeda local** | tiers US$ 2,99–14,99; **70% no 1º mês e 100% depois**; exige conta verificada | melhor repasse para receita recorrente; Brasil disponível | A |
| **Passe vendido como assinatura** | permitido pela política de assinaturas | transforma o passe de temporada em receita mensal | A |
| **Paid random items** | odds numéricas obrigatórias; `PolicyService` por região | loot box segue proibida no GDD; se um dia houver, custo de compliance alto | A |
| **DevEx** | mínimo **30 mil R$**; 0,0038; 18+ 0,0054; avatar items não elegíveis | saque só depois de ~US$ 114 acumulados | A |

Fontes: [Regional pricing](https://create.roblox.com/docs/production/monetization/regional-pricing) ·
[Price optimization](https://create.roblox.com/docs/production/monetization/price-optimization) ·
[Roblox Plus](https://create.roblox.com/docs/en-us/production/monetization/roblox-plus) ·
[Subscriptions](https://create.roblox.com/docs/production/monetization/subscriptions) ·
[Paid random items](https://create.roblox.com/docs/en-us/production/monetization/paid-random-items) ·
[DevEx](https://create.roblox.com/docs/en-us/production/monetization/developer-exchange) ·
[18+ rate](https://create.roblox.com/docs/en-us/production/monetization/18-plus-devex-rate).

### 5.1 O 18+ rende menos do que parece

| Gasto elegível 18+ US | Repasse misto por US$ | Ganho vs base | Líquido/mês a 25k DAU (US$) |
|---:|---:|---:|---:|
| 0% | 0,2128 | — | — |
| **10%** | **0,2218** | **+4,2%** | 6.239 |
| **25%** | **0,2352** | **+10,5%** | 6.615 |

O +42% é real **por dólar elegível**, mas o bônus misto é pequeno: com 10% de gasto elegível, a
receita sobe ~4%; com 25%, ~10,5%. A hipótese de 25% é o teto otimista; o dado de Q3/2026 diz que
29% dos DAU *age-checked* globais são 18+ e que o 18+ monetiza ~50% mais que o under-18 — o que sugere algo
mais perto de **10% do gasto global**, não 25%.

---

## 6. O que os jogadores reclamam (e o que isso custa)

A pesquisa anterior ([`pesquisa-jogadores.md`](pesquisa-jogadores.md)) já documentou os clusters do
TDS: **pay-to-win percebido**, **grind**, **nerf destrutivo**, **gatekeeping**. A monetização do
gênero é a causa direta de dois deles:

- o TDS vende torres com descrição literal "**chegue ao nível 75 ou compre o Mortar**" — é venda de
  progressão, não de cosmético ([Gamepasses](https://tds.fandom.com/wiki/Gamepasses));
- o Toilet TD vende "Lucky" e "Shiny Hunter" (odds pagas) — o tipo de item que a política de
  `paid random items` obriga a divulgar odds ([rblxdb](https://rblxdb.com/games/changes-toilet-tower-defense-4778845442)).

**A consequência estratégica:** o GDD proíbe exatamente o que financia o gênero. Isso não é um
detalhe de ética — é uma **desvantagem de receita** que precisa ser compensada por retenção,
volume, 18+ e canais melhores (assinatura/Plus). Se a conversão ficar abaixo de 1% no P2, a
pergunta deixa de ser "qual skin vender" e passa a ser "qual conveniência honesta vender".

---

## 7. Leitura para a Muralha (decidida em 09/11/2026)

1. **Preço do passe:** 399–499 está alinhado ao TDS; 599 é o topo da faixa. Se virar assinatura em
   moeda local, o repasse de 100% a partir do 2º mês muda a conta mais que qualquer ajuste de preço.
2. **Skin individual:** 149–249 é o que o mercado sustenta por item único; 399 só se for bundle ou
   edição limitada. O mercado vende **bundle** (TDS 6–7 skins por 300–360), não skin solta.
3. **Efeito de destruição:** 99–149 é coerente com emote do TDS (55–85) e com o valor de clipe; 249
   é o teto.
4. **Comandante:** 199–299; acima disso compete com VIP (300) que entrega várias coisas.
5. **ARPPU de planejamento:** US$ 2/mês (base); **US$ 5 é upside**, não orçamento.
6. **Pagantes:** 2% mensais é a base; 3,8% é taxa de 12 meses, não mensal.
7. **Gate:** **ARPDAU líquido ≥ US$ 0,005** (bruto ≈ 0,0225; ~BRL 20 mil/mês a 25 mil DAU).
8. **Cosmético sem avatar:** a identidade tem de morar na muralha (skin de muralha, efeito, moldura
   de replay, cenário da base). É a analogia do "scenery" do Clash of Clans, não do avatar do DTI.
9. **Canais:** (a) assinatura local do passe; (b) prompt de Plus (750 R$ por signup); (c) regional
   pricing ligado; (d) nenhum loot box.
10. **Decisão registrada em 09/11/2026** em [`decisao-monetizacao.md`](decisao-monetizacao.md).

---

## 8. O que medir antes de decidir preço

| Métrica | Como | Por quê |
|---|---|---|
| conversão de pagantes (30 dias) | telemetria própria | substitui o 3,8% de 12 meses |
| ARPPU mensal | receita ÷ pagantes do mês | separa mediana de topo |
| ARPDAU **bruto** e **líquido** | dois números separados | resolve o gate |
| receita por canal | passe, skin, conveniência, Plus | mostra o que sustenta |
| % de gasto 18+ US | Creator Analytics (linha separada) | valida a hipótese de 25% |
| recompra | % de pagantes com 2+ compras | mede se o item é recorrente |
| refund/chargeback | dashboard | cosmético com arrependimento mata margem |

Teste de preço inicial (manual, porque price optimization exige 60 mil transações/30 dias):
passe a 399 vs 499; skin a 149 vs 199; bundle vs unitário. Medir receita por DAU, não preço.

---

## 9. Limites desta pesquisa

- A GameAnalytics não publica receita por jogo; os números são distribuições, não casos.
- O ARPPU do relatório não tem período explícito — a ambiguidade está registrada, não resolvida.
- Preços de comps são **base** (regional pricing e Plus mudam o que cada jogador vê).
- A estimativa de receita do Dress to Impress vem de terceiro, com confiança declarada de 0,61.
- Não há dado público de conversão mensal por jogo no Roblox; a única fonte será o próprio jogo.
- Tentativa de ler threads de jogadores (Reddit/Fandom) foi bloqueada; a seção 6 se apoia na
  pesquisa anterior e nas descrições de produto dos concorrentes, não em falas novas.

---

## 10. Fontes

| Nível | Fonte | Data | Uso |
|---|---|---|---|
| A | [GameAnalytics — 2026 Roblox Benchmark Report](https://www.gameanalytics.com/reports/2026-roblox-report) | set/2026 | 3,8% pagantes · ARPPU · sessão |
| A | [Roblox — DevEx](https://create.roblox.com/docs/en-us/production/monetization/developer-exchange) | 2026 | 0,0038 · mínimo 30 mil R$ |
| A | [Roblox — 18+ rate](https://create.roblox.com/docs/en-us/production/monetization/18-plus-devex-rate) | 2026 | 0,0054 · elegibilidade |
| A | [Roblox — Roblox Plus](https://create.roblox.com/docs/en-us/production/monetization/roblox-plus) | 2026 | 78–88% · 750 R$ por signup |
| A | [Roblox — Subscriptions](https://create.roblox.com/docs/production/monetization/subscriptions) | 2026 | 70% → 100% em moeda local |
| A | [Roblox — Regional pricing](https://create.roblox.com/docs/production/monetization/regional-pricing) | 2026 | 30–100% do base |
| A | [Roblox — Price optimization](https://create.roblox.com/docs/production/monetization/price-optimization) | 2026 | 60 mil transações/30 dias |
| A | [Roblox — Paid random items](https://create.roblox.com/docs/en-us/production/monetization/paid-random-items) | 2026 | odds · PolicyService |
| A | [DevForum — US 18+ DevEx Rate](https://devforum.roblox.com/t/introducing-the-us-18-devex-rate-earn-42-more-on-spend-from-18-us-players/4607091) | abr–out/2026 | +42% · Age Check API |
| A | [Motley Fool — Q3 2026 earnings](https://www.fool.com/earnings/call-transcripts/2026/10/30/roblox-rblx-q3-2026-earnings-call-transcript/) | 30/10/2026 | 29% dos DAU age-checked 18+ · Plus 7x |
| B | [TDS Wiki — Gamepasses](https://tds.fandom.com/wiki/Gamepasses) | 2026 | preços de torres/skins/VIP |
| B | [TDS Wiki — Surf & Turf Battle Pass](https://tds.fandom.com/wiki/Surf_%26_Turf_Battle_Pass) | 2025 | passe 399/499 · skip ~4 mil |
| A | [rblxdb — Toilet TD](https://rblxdb.com/games/changes-toilet-tower-defense-4778845442) | 09/11/2026 | passes 79–699 |
| A | [rblxdb — ASTD](https://rblxdb.com/games/og-all-star-tower-defense-1720936166) | 09/11/2026 | displays 175–200 · poder 799–1.200 |
| A | [rblxdb — Build Defense](https://rblxdb.com/games/build-defense-5678463488) | 09/11/2026 | packs 99–999 · sessão 0,6 min |
| C | [RoWatcher — Dress to Impress](https://rowatcher.com/games/5203828273/dress-to-impress) | 09/11/2026 | receita estimada US$ 820 mil/mês |

---

## 9. Atualização — ticket regional (12/11/2026)

A pergunta “quanto é o ticket médio fora do Brasil?” não tinha resposta no projeto. O que existe
agora, documentado em [`pesquisa-monetizacao-regional.md`](pesquisa-monetizacao-regional.md):

- receita 2025 por região: EUA+Canadá **61%**, Europa **19%**, APAC **11%**, ROW **9%** (Brasil
  dentro do ROW, sem abertura);
- ABPDAU Q3 FY26: EUA+Canadá **US$ 38,52**, Europa **US$ 11,20**, APAC **US$ 5,37**, ROW
  **US$ 5,07** — bookings por DAU, não ARPPU;
- ARPPU por país e ticket por compra (AOV) **não medidos**; o benchmark GameAnalytics (p50 US$ 0,70;
  p90 US$ 2,33; p95 US$ 4,80) é global e por jogo;
- GAP-013 registra a lacuna; o próprio Creator Analytics permite medir ARPPU/conversão por país e
  exportar sales data quando o jogo tiver loja.
