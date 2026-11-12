# Ticket médio e ARPPU fora do Brasil — pesquisa

> **Status:** pesquisa documental feita em **12/11/2026**; **não é decisão de preço**. O projeto
> estava em pausa e esta pesquisa foi adicionada para responder se o ticket médio/ARPPU fora do
> Brasil já tinha sido analisado.
>
> **Resposta curta:** **não havia análise por país.** O que existia era benchmark **global** de
> ARPPU por jogo, regras de **regional pricing** e o diferencial de DevEx **18+ EUA**. Esta pesquisa
> acrescenta a camada regional oficial da Roblox (receita e ABPDAU por região), separa o que é dado
> do que é proxy e registra a lacuna que continua aberta.

---

## 1. Definições — para não misturar as métricas

| Métrica | Definição | O que ela responde | Cuidado |
|---|---|---|---|
| **ARPPU por jogo** | Receita do jogo ÷ pagantes do jogo, no período | Quanto cada pagante gasta **naquele jogo** | Não é mensal; não é o mesmo que ARPPU da plataforma |
| **ABPDAU** | Bookings ÷ DAU, no período | Intensidade de monetização **por usuário ativo** | Bookings/DAU ≠ ticket por pagante; depende da conversão |
| **ABPPU / ABMUP** | Bookings ÷ pagantes únicos mensais | Gasto médio do pagante **na plataforma inteira** | Inclui todos os jogos; não serve como ticket de um jogo |
| **AOV / ticket por compra** | Bookings ÷ número de transações | Valor médio de **uma compra** | Não há fonte pública; só telemetria própria |
| **ARPPU regional** | ARPPU do jogo em um país/região | Ticket do pagante naquele mercado | É a métrica que falta para preço internacional |

A confusão mais comum é usar o **ABPPU da plataforma** (≈US$ 18,69/mês no Q3 FY26) como se fosse o
ARPPU de um jogo. Não é: um pagante da Roblox pode gastar em vários jogos; o ARPPU por jogo é muito
menor (mediana de US$ 0,70 na amostra GameAnalytics).

---

## 2. O que a Roblox divulga oficialmente

### 2.1 Receita por região (10-K 2025)

Tabela do 10-K de 2025, receita por região com base no país de cobrança
([SEC accession 0001315098-26-000024](https://www.sec.gov/Archives/edgar/data/1315098/000131509826000024/)):

| Região | Receita 2025 (US$ mil) | % da receita | Receita 2024 (US$ mil) | % 2024 |
|---|---:|---:|---:|---:|
| EUA + Canadá | 2.969.150 | **61%** | 2.281.319 | 63% |
| Europa | 944.226 | **19%** | 659.593 | 18% |
| Ásia-Pacífico (inclui Austrália/NZ) | 541.532 | **11%** | 379.027 | 11% |
| Resto do mundo (ROW) | 435.643 | **9%** | 282.040 | 8% |
| **Total** | **4.890.551** | **100%** | **3.601.979** | **100%** |

### 2.1b Receita e bookings por região no Q3 FY26

O data sheet mais recente permite ver o mix atual (Q3 FY26, US$ milhões):

| Região | Receita | % receita | Bookings | % bookings |
|---|---:|---:|---:|---:|
| EUA + Canadá | 895 | 56,9% | 907 | 53,4% |
| Europa | 325 | 20,7% | 360 | 21,2% |
| Ásia-Pacífico | 191 | 12,1% | 226 | 13,3% |
| Resto do mundo (inclui Brasil) | 161 | 10,2% | 204 | 12,0% |
| **Total** | **1.572** | **100%** | **1.697** | **100%** |

O mix de **bookings** é um pouco menos concentrado que a receita: EUA/Canadá caem de 61% (2025) para
**53,4%** no Q3 FY26, enquanto ROW sobe para **12,0%**. Ainda assim, EUA/Canadá geram ~4,4× o
bookings do ROW com uma base de DAU muito menor.

Fatos importantes do mesmo 10-K:

- os **EUA sozinhos** foram **57%** da receita consolidada em 2025;
- **nenhum outro país** passou de **10%** da receita — o Brasil não é aberto separadamente;
- **82% dos DAU** estavam **fora de EUA/Canadá**, mas só **39% da receita** vinha de fora dessa
  região; a monetização por usuário é muito mais concentrada em EUA/Canadá.

### 2.2 ABPDAU por região (bookings por DAU)

Dados do **Q3 FY26 Investor Data Sheet** (reprodução pública; valores em US$ por DAU no trimestre).
ABPDAU é bookings ÷ DAU; **não é ARPPU**.

| Região | Q3 FY24 | Q3 FY25 | Q3 FY26 | Q3 FY26 vs ROW |
|---|---:|---:|---:|---:|
| EUA + Canadá | 35,51 | 40,18 | **38,52** | **7,60×** |
| Europa | 9,90 | 12,04 | **11,20** | **2,21×** |
| Ásia-Pacífico | 5,21 | 5,27 | **5,37** | **1,06×** |
| Resto do mundo (inclui Brasil) | 3,84 | 4,90 | **5,07** | 1,00× |
| **Total global** | **12,70** | **12,68** | **12,29** | **2,42×** |

Leitura: em Q3 FY26, EUA/Canadá geravam **7,6×** mais bookings por DAU que o ROW; Europa **2,2×**;
APAC estava praticamente empatada com o ROW. O Brasil está **dentro do ROW**, então não é possível
separar Brasil de América Latina/África/Oriente Médio nessa tabela.

### 2.3 Pagantes e ABPPU da plataforma

Ainda no Q3 FY26 Investor Data Sheet:

| Métrica | Q1 FY26 | Q2 FY26 | Q3 FY26 |
|---|---:|---:|---:|
| Pagantes únicos mensais médios | 30,7M | 27,0M | **30,3M** |
| Bookings por pagante único mensal | US$ 18,78 | US$ 19,25 | **US$ 18,69** |

Conferência: Q3 FY26 teve **US$ 1.697M** de bookings; dividido por 3 meses = **US$ 565,7M/mês**;
dividido por 30,3M de pagantes mensais = **US$ 18,67** — o data sheet arredonda para **US$ 18,69**.
É, portanto, uma média **mensal por pagante da plataforma**, não por jogo e não por transação.

Este **US$ 18,69 é plataforma inteira, por mês**, não um jogo. Não deve entrar no modelo da Muralha
como ARPPU. Ele serve para mostrar que o pagante da Roblox gasta em vários jogos e que o ticket
por jogo é uma fração disso.

### 2.4 DevEx 18+ EUA

- DevEx base: **US$ 0,0038 por Robux** ganho.
- DevEx 18+ EUA: **US$ 0,0054 por Robux** ganho — **+42% por dólar elegível**.
- O efeito no total depende da fração do gasto vinda de 18+ verificado nos EUA: ~**+4,2%** com 10%
  do gasto elegível; ~**+10,5%** com 25%.
- Isso **não** é um ticket maior fora do Brasil; é um **take rate** maior apenas para o gasto
  elegível de jogadores 18+ nos EUA.

Fonte: [DevForum — US 18+ DevEx Rate](https://devforum.roblox.com/t/introducing-the-us-18-devex-rate-earn-42-more-on-spend-from-18-us-players/4607091)
e [`tese-produto-e-economia.md`](tese-produto-e-economia.md).

### 2.5 Regional pricing

A Roblox aplica **Managed Pricing** automático em passes e assinaturas em Robux:

- o preço regional fica entre **30% e 100%** do preço default;
- nunca é acima do default;
- o piso é **30%** (desconto máximo de 70%);
- a localização econômica não é necessariamente a localização da conta (VPN, histórico de cobrança
  e histórico da conta entram no cálculo);
- se o preço estiver **hardcoded** na UI, o jogador é cobrado pelo preço regional, mas a UI mostra o
  valor antigo; a própria Roblox recomenda usar `MarketplaceService` e o Dynamic Price Check.

Fonte: [Roblox — Regional pricing](https://create.roblox.com/docs/en-us/production/monetization/regional-pricing).

Consequência: comparar “ticket em Robux” entre Brasil e exterior é enganoso. O mesmo item pode ser
vendido por 30–100% do preço; o ticket em dólar e o ARPPU por país mudam sem mudar o catálogo.

### 2.6 O que o Creator Analytics permite medir no próprio jogo

A dashboard de monetização da Roblox expõe:

- **Revenue**, **conversion rate**, **paying users**, **ARPPU** e **ARPDAU**;
- filtros de **país**, idade, gênero, língua, fonte, status de pagante etc.;
- download dos **sales data** para análise própria.

Fonte: [Roblox — Monetization analytics](https://create.roblox.com/docs/production/analytics/monetization)
e [Analytics dashboard](https://create.roblox.com/docs/production/analytics/analytics-dashboard).

Ou seja: o dado que falta **pode ser medido no jogo**, mas ainda não foi — e a telemetria própria
atual não tem campo de país (só `locale` e `price_robux`).

---

## 3. Benchmark global por jogo (GameAnalytics 2026)

O relatório da GameAnalytics cobre **500+ jogos com 1M+ MAU**, de ago/2025 a jul/2026. A distribuição
de **ARPPU por jogo** é:

| Percentil | ARPPU por jogo |
|---|---:|
| p25 | US$ 0,32 |
| **p50** | **US$ 0,70** |
| p75 | US$ 1,25 |
| p90 | US$ 2,33 |
| p95 | US$ 4,80 |
| p99 | US$ 55,31 |

Fonte: [GameAnalytics — 2026 Roblox Benchmark Report](https://www.gameanalytics.com/reports/2026-roblox-report).

O relatório é **global**: não publica recorte por país nem por região. A leitura correta é “o jogo
mediano de grande porte arrecada US$ 0,70 por pagante no período”, não “o pagante brasileiro gasta
US$ 0,70/mês”.

O projeto já usava essa distribuição para decidir **2% × US$ 2** como base e **4,5% × US$ 5** como
topo; US$ 2 fica entre p75 e p90; US$ 5 fica no p95. Isso continua válido como premissa **global por
jogo**, mas não como ticket por país.

---

## 4. Brasil: o que se sabe (e o que não se sabe)

A Bloomberg Línea (15/10/2026) reporta:

- o Brasil é o **segundo maior mercado da Roblox em número de usuários**, atrás só dos EUA;
- a base de DAU no Brasil **multiplicou por 4,7 em cinco anos** (+371%);
- no último ano fiscal, o crescimento de DAU no Brasil foi **+42% ano a ano**;
- cerca de **1.500 desenvolvedores locais** ganharam dinheiro real na plataforma no último ano
  fiscal, **+61%**;
- a Roblox distribuiu **US$ 1,6 bilhão** para criadores globalmente nos 12 meses até jun/2026;
- a empresa investiu em data center em São Paulo, time regional e **Pix** como meio de pagamento.

Fonte: [Bloomberg Línea — Por que o Brasil se tornou prioridade global](https://bloomberglinea-bloomberg-linea-brasil-prod.web.arc-cdn.net/tech/por-que-o-brasil-se-tornou-a-prioridade-global-da-roblox-depois-dos-estados-unidos/).

**O artigo não informa receita, ARPPU, ticket médio nem conversão de pagantes no Brasil.** Ele mede
usuários, criadores e infraestrutura. É útil para prioridade de mercado, não para preço.

O 10-K também não abre o Brasil: ele está no ROW (9% da receita em 2025) e nenhum país além dos EUA
passa de 10%. Portanto, **não existe, nas fontes oficiais usadas, um ARPPU Brasil separado**.

---

## 5. Síntese: o que sabemos sobre ticket fora do Brasil

| Mercado | Receita 2025 | ABPDAU Q3 FY26 | Leitura de ticket | Dado de ARPPU por país? |
|---|---:|---:|---|---|
| EUA + Canadá | 61% | US$ 38,52 | mercado de **alto ticket** e maior poder de compra; preço cheio | **não** |
| Europa | 19% | US$ 11,20 | ticket intermediário; preço cheio/regional | **não** |
| Ásia-Pacífico | 11% | US$ 5,37 | mistura de Japão/Coreia (alto) com Sudeste Asiático/Índia (baixo); ticket médio baixo | **não** |
| ROW (inclui Brasil) | 9% | US$ 5,07 | alto volume, baixo bookings/DAU; regional pricing agressivo | **não** |
| Global por jogo | — | — | ARPPU mediano US$ 0,70; p90 US$ 2,33; p95 US$ 4,80 | **não** |

### O que é dado e o que é inferência

- **Dado:** receita por região, ABPDAU por região, ABPPU global, ARPPU global por jogo, regra de
  regional pricing, crescimento de DAU no Brasil.
- **Inferência:** EUA/Canadá têm ticket por pagante mais alto; ROW/Brasil têm ticket menor e mais
  sensível a preço; Europa fica no meio; APAC é heterogêneo.
- **Não medido:** ARPPU por país, conversão de pagantes por país, AOV por transação e elasticidade
  de preço no Brasil.

### O erro que não devemos cometer

Usar **ABPDAU** como se fosse **ARPPU**. ABPDAU é bookings por DAU; se a conversão de pagantes for
diferente entre regiões, o ranking de ABPDAU não se traduz 1:1 em ranking de ticket por pagante.
Também não devemos usar o **ABPPU da plataforma** (US$ 18,69/mês) como ticket da Muralha.

---

## 6. Implicações para a MURALHA

1. **A premissa global 2% × US$ 2 continua sendo a base do modelo**, mas é uma média global de
   jogo, não um ticket brasileiro. Para um público majoritariamente brasileiro, o ARPPU realizado
   tende a ficar **abaixo** de US$ 2; para um público EUA/Canadá relevante, pode ficar acima.
2. **O crescimento de usuários no Brasil não é crescimento de receita por usuário.** O país é
   segundo maior em usuários, mas está no ROW de 9% da receita; a monetização por DAU é ~7,6× menor
   que EUA/Canadá.
3. **Regional pricing vai reduzir o ticket em BRL/Robux no Brasil** (piso de 30%). O modelo precisa
   pensar em **receita líquida por DAU**, não em preço nominal do item.
4. **18+ EUA não resolve ticket fora do Brasil.** O +42% é só sobre gasto elegível de 18+ nos EUA.
5. **Para P2/loja**, não lançar preço internacional com um único ARPPU. A decisão precisa de:
   - ARPPU e conversão por país no próprio jogo;
   - AOV por transação;
   - elasticidade de preço no Brasil (30%, 50%, 70%, 100%);
   - mix de 18+ EUA.

---

## 7. Como medir no próprio jogo (sem inventar número)

### 7.1 Creator Analytics

- Enroller a dashboard de monetização; usar o filtro de **país**;
- exportar **sales data** e calcular, por país:
  - `ARPPU = revenue / paying_users`;
  - `conversion = paying_users / DAU`;
  - `AOV = revenue / transactions` (se o export tiver transações; senão, instrumentar);
  - `ARPDAU = revenue / DAU`.
- Comparar Brasil, EUA/Canadá, Europa, APAC e ROW.

### 7.2 Telemetria própria (taxonomia v1 congelada)

Hoje o envelope tem `locale` e os eventos de compra têm `price_robux`; **não há país/região**. Para
não abrir taxonomia v2 agora:

- usar `locale` como **proxy grosseiro** (não é país; `pt-BR` não é Brasil);
- registrar o **preço efetivamente cobrado** na compra (não o preço hardcoded do catálogo);
- cruzar `purchase_complete` com o sales export por país.

Se a decisão de P2 exigir segmentação confiável, aí sim taxonomia v2 com `region`/`country` e
migração — decisão separada, não agora.

### 7.3 Teste de preço

Antes de P2, um teste pequeno com 3 faixas (ex.: 30%, 60%, 100% do preço default) em uma oferta
cosmética, medindo receita líquida por DAU e não só conversão. O piso de 30% é regra da plataforma;
o teste decide o ponto econômico, não a regra.

---

## 8. Lacuna registrada

Esta pesquisa fecha o **benchmark regional**, mas não fecha o **ticket por país**. O gap é:

- **GAP-013:** ARPPU/AOV por país não medido; Brasil dentro do ROW; benchmark global e ABPDAU
  regional não substituem ticket por pagante;
- **gatilho:** antes de P2/loja/precificação internacional;
- **como fechar:** Creator Analytics (ARPPU/conversão por país + sales export) e telemetria própria
  com preço efetivo; se necessário, taxonomia v2 com região.

Ver [`gaps.md`](gaps.md).

---

## 9. Fontes

| Nível | Fonte | Data | Uso |
|---|---|---|---|
| A | [Roblox 10-K 2025 — SEC](https://www.sec.gov/Archives/edgar/data/1315098/000131509826000024/) | 11/02/2026 | receita por região, 82% DAU/39% receita fora de EUA/Canadá, nenhum país >10% |
| A | [Roblox Q3 FY26 Investor Data Sheet](https://sa.marketscreener.com/news/roblox-third-quarter-2026-investor-data-sheet-ce785fdadc88f222) | 29/10/2026 | ABPDAU por região, pagantes e ABPPU |
| A | [Roblox — Regional pricing](https://create.roblox.com/docs/en-us/production/monetization/regional-pricing) | 2026 | piso 30%, teto 100%, economic location, preço hardcoded |
| A | [Roblox — Monetization analytics](https://create.roblox.com/docs/production/analytics/monetization) | 2026 | ARPPU/ARPDAU/conversão por país e sales export |
| A | [GameAnalytics — 2026 Roblox Benchmark Report](https://www.gameanalytics.com/reports/2026-roblox-report) | 2026 | ARPPU global por jogo (p50 0,70; p90 2,33; p95 4,80) |
| A | [DevForum — US 18+ DevEx Rate](https://devforum.roblox.com/t/introducing-the-us-18-devex-rate-earn-42-more-on-spend-from-18-us-players/4607091) | abr–out/2026 | +42% por dólar 18+ EUA |
| B | [Bloomberg Línea — Brasil prioridade global](https://bloomberglinea-bloomberg-linea-brasil-prod.web.arc-cdn.net/tech/por-que-o-brasil-se-tornou-a-prioridade-global-da-roblox-depois-dos-estados-unidos/) | 15/10/2026 | Brasil 2º mercado em usuários, DAU +42% a/a, 1.500 devs |
| B | [`pesquisa-monetizacao.md`](pesquisa-monetizacao.md) | 09/11/2026 | benchmark e preços de itens já usados no projeto |

> **Nota de método:** o data sheet é uma reprodução pública do material oficial; os números foram
> conferidos contra as tabelas do 10-K quando havia sobreposição. Onde a fonte não abre o Brasil,
> o documento diz “não medido” em vez de estimar.
