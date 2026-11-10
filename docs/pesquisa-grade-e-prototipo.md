# Pesquisa — Q2 e Q1 (fechadas)

> 09/11/2026 · encomenda do diretor: **decidir com dados e feedback, não com opinião**.
> **Q2 fechada em 09/11/2026:** 5×5 com **N=5 armadilhas ativas** e colocação livre nas 25 células;
> registro no [GDD](gdd-muralha.md) (decisão 1).
> **Q1 fechada em 09/11/2026:** apagar o legado de moedas na P1, preservando `src/shared/sim/`;
> tag `legacy-coins` + stub de 10 linhas + `rojo build` no CI; registro em `.context/REJEITADOS.md`.
> **Executada na S1 (09/11/2026):** tag anotada em `b07b4c5`, `src/` sem o protótipo, `check.sh` verde.
> O experimento da §5 vira o fallback de playtest, não um pré-requisito.
>
> Níveis: **A** = oficial/primário (Roblox, dados de plataforma) · **B** = comunidade estruturada
> (wiki com histórico, guia de fã com método) · **C** = comentário isolado (sinal, não prova).

---

## Resumo

| Pergunta | O que a evidência sustenta | Confiança |
|---|---|---|
| **Q2** — 25 células vs 5 slots | jogos profundos usam **5–10 unidades**; 25 células só se paga como **espaço de posicionamento**, não como 25 armadilhas simultâneas | média-alta |
| **Q1** — apagar `src/**` | apagar na P1, **com tag no git + stub de teste + CI**; o protótipo não tem código reutilizável e embute um padrão já rejeitado | média-alta |
| **O que falta** | teste A/B de 20–30 jogadores para Q2; para Q1, só a decisão | — |

Duas conclusões que mudam a pergunta:

1. **A comparação com o TDS é falsa.** O TDS posiciona torres **ao longo do caminho**, com zonas de
   exclusão; a Muralha posiciona armadilhas **numa base**. O análogo certo é Plants vs. Zombies
   (grade 5×9, uma planta por casa) e os autobattlers (5–10 unidades), não o TDS.
2. **O número que a Q2 precisa fixar não é "células", é "armadilhas ativas".** O GDD fecha 5 tipos
   de armadilha (`gdd-muralha.md:127`) mas nunca diz quantas ficam no tabuleiro ao mesmo tempo.
   Sem esse número, "5×5" e "5 slots" não são alternativas comparáveis.

---

## 1. O que cada pergunta realmente é

| # | Formulação atual | O que está em jogo | O que a pergunta esconde |
|---|---|---|---|
| Q1 | "o protótipo de moedas em `src/**` é descartado na P1?" | custo de manter um segundo jogo no repo × valor de ter uma cena de teste de pipeline | o valor real do protótipo é **só** provar Rojo + servidor autoritativo; isso se substitui por um stub |
| Q2 | "5×5 com 25 células vs 5 slots (1 por lane)?" | profundidade de layout × legibilidade no drop-in de 5s | quantas armadilhas ativas; se 25 células podem receber 25 armadilhas, o jogo vira outro |

### 1.1 O que a Q2 está comparando de fato

| Modelo | O jogador decide | Exemplo | Unidades simultâneas |
|---|---|---|---|
| **Slot por lane** | qual armadilha em cada uma das 5 lanes | Plants vs. Zombies (5 lanes) | até 9 por lane (45 no total) |
| **Grade de base** | **onde** colocar N armadilhas num espaço 2D | Clash of Clans, PvZ (grade 5×9) | N (o número é a decisão) |
| **Posicionamento livre** | coordenada exata ao longo do caminho | BTD6, TDS | 5–40, conforme o mapa |

A Muralha é o segundo modelo. A pergunta boa não é "grade ou slot", é **"N = 5 fixo, N = 25 livre,
ou N que cresce com a muralha?"**.

---

## 2. Q2 — o que o mercado faz (A/B)

### 2.1 Os jogos que definem convenção

| Jogo | Modelo | Números | Mobile | Nível |
|---|---|---|---|---|
| **Tower Defense Simulator** | posicionamento livre em zonas, com raio vermelho de exclusão | 40 torres solo · 30 duo · 25 trio · 20 quad; **5 slots de loadout** (6 em evento); mobile exige **duplo toque** | sim | B |
| **Plants vs. Zombies** | grade **5 linhas × 9 colunas**, uma planta por casa | 45 casas; 5 lanes | sim (port mobile) | B |
| **Kingdom Rush** | **tiles fixos** de construção | guia do jogo: fases são desenhadas para **4–6 torres** | sim | B |
| **Super Auto Pets** | **5 slots** de time + 3 de comida | "five-slot team" | sim | B |
| **Mechabellum** | tabuleiro de deployment; posicionamento é a habilidade | "placement determines whether your expensive units generate value or die before firing" | PC | C |
| **Build Defense** (Roblox) | base construída + ondas | 71,4M visitas, 93% like, mas **652 CCU** e −31% em ~2 meses; sessão média 0,6 min | sim | A |
| **Mutant Plants: Base Defense** (Roblox) | base + ondas | 2.514 CCU, 98% like (nov/2026) | sim | A |

Fontes: [TDS Wiki — How to Play](https://tds.fandom.com/wiki/How_to_Play) (B) ·
[PvZ Wiki — Lawn](https://plantsvszombies.fandom.com/wiki/Lawn) (B) ·
[Kingdom Rush — towers](https://kingdomrush.org/guides/towers) (B) ·
[Roguelike Radar — Super Auto Pets](https://roguelikeradar.com/games/super-auto-pets/) (B) ·
[FinalBoss — Mechabellum](https://finalboss.io/mechabellum-beginner-guide-to-unit-roles-deployment-and) (C) ·
[rblxdb — Tower Defense](https://rblxdb.com/best-roblox-games/tower-defense) (A).

### 2.2 O que os jogadores reclamam (o que realmente irrita)

| Reclamação | Trecho | Leitura | Nível |
|---|---|---|---|
| **Precisão de posicionamento no PC** | "spent 10 minutes trying to find the one … viable coordinate to replace it" (profanidade removida) — e, no mesmo tópico, "Grids are awful in their own right"; outro jogador: "if you sell a tower that was in among others its really hard to put a new one down" | o ódio é à **fricção de encaixe**, não ao tamanho do tabuleiro; um jogador rejeita grade, outro pede snap — os dois querem menos erro de toque | C |
| **Limite de posicionamento** | tópico do fórum do TDS: "why is the whole game surrounded with placement limits" | jogador percebe restrição de espaço como punição, mesmo quando é design | C |
| **Falta de slot** | "Sixth tower slot?" (fórum do TDS) | onde há slot fixo, o pedido é **mais** opção — sinal de que 5 é apertado para alguns | C |
| **Time pequeno parece raso** | "The clean interface and tiny team can look strategically slight before interactions become familiar" (Super Auto Pets) | 5 slots **funciona**, mas a primeira impressão pode ser de pouca profundidade | B |
| **Posicionamento > upgrade** | "Placement is worth more than any single upgrade in the game" (Kingdom Rush) | mesmo com 4–6 torres, o espaço é a decisão principal | B |

### 2.3 Números do gênero

| Métrica | Valor | Fonte |
|---|---|---|
| Jogos de TD ranqueados no Roblox | **30** · 88,1 mil jogando · **22,9 bi de visitas** · 93% de like médio | rblxdb, 09/11/2026 |
| Concentração | top 3 (Cameraman, TDS, Toilet) = ~47,3 mil dos 88,1 mil jogando (~54%) | rblxdb |
| Gênero **Strategy** (onde TD se encaixa) | 256 experiências · mediana 66 CCU · top 10% **1.879** · **14,8%** acima de 1.000 | ROLearn, out/2026 |
| Gênero **Simulation** (onde o protótipo de moedas se encaixa) | **5.865** experiências (37%) · 42% dos jogadores · mediana **40** · top 10% 850 · 8,9% acima de 1.000 | ROLearn, out/2026 |
| Retenção mediana de jogos grandes | D1 **10,3%** · D7 **1,6%** · D30 **0,5%** | GameAnalytics, set/2026 |
| Sessão mediana | **7,28 min** | GameAnalytics |
| Dispositivos | 44% mobile+PC · **40,76% só PC** · 11,55% só mobile | GameAnalytics |

**Leitura:** o gênero é grande e provado (22,9 bi de visitas; 93% de like), mas concentrado. Strategy
tem o **teto mais alto** da plataforma (14,8% dos jogos acima de 1.000 CCU, contra 8,9% em
Simulation) — argumento a favor da Muralha e contra qualquer ideia de pivotar para o jogo de moedas.

**O detalhe incômodo:** o TD do Roblox é co-op por convenção — a rblxdb diz que os modos difíceis
"não são realisticamente soloáveis". A Muralha nasce solo-first, o que é diferenciação real e,
ao mesmo tempo, um risco de produto: o jogador do gênero chega esperando time.

### 2.4 Leitura da Q2 (com confiança)

1. **Profundidade não vem do número de células.** Os jogos citados como profundos usam 4–6 torres
   (Kingdom Rush), 5 slots (SAP) ou 7–10 unidades (autobattlers). 25 células não é requisito.
   *Confiança alta.*
2. **25 células como espaço, com 5 armadilhas ativas, já é muito profundo.** C(25,5) = **53.130
   layouts** distintos, contra 1 layout no modelo de 5 slots fixos. O tabuleiro dá profundidade sem
   inflar o número de unidades. *Confiança alta (matemática).*
3. **25 armadilhas simultâneas seria fora da curva.** Está acima do que autobattlers usam (5–10) e
   do que cabe num drop-in de 5s no celular; TDS só chega a 20–40 porque é co-op e ao longo do
   caminho. *Confiança média-alta.*
4. **O risco do modelo 5 slots é de percepção, não de design.** SAP prova que 5 slots sustenta
   estudo sério; a resenha registra que "parece raso" até o jogador entender as interações.
   *Confiança média.*
5. **O que o jogador pune é fricção de encaixe.** Precisão de pixel no PC e zonas de exclusão
   confusas geram reclamação; grade com snap e destaque de célula tende a reduzir erro no toque.
   *Confiança média-alta.*
6. **Não existe evidência pública de "5×5 vs 5 slots" para o nosso caso.** Nenhuma fonte mede
   preferência por 25 células num TD de base mobile. Qualquer decisão sem teste é aposta.
   *Confiança alta.*

### 2.5 Sinal contrário que não pode ser ignorado

TD de **base construída** no Roblox existe e não é fenômeno: Build Defense tem 71M de visitas mas
652 CCU e sessão de 0,6 min; Mutant Plants: Base Defense tem 2,5 mil CCU e 98% de like. O topo do
gênero é TD cooperativo de **coleção de unidades** (Cameraman 27,4 mil; TDS 12,7 mil). Isso não
condena a grade — condena a ideia de que a grade sozinha diferencia. A diferenciação da Muralha tem
de ser o loop assíncrono + replay, como o GDD já diz.

---

## 3. Q1 — o protótipo de moedas

### 3.1 O que ele é, em números

| Arquivo | Linhas | Papel |
|---|---:|---|
| `src/server/CoinService.luau` | 172 | cria moedas no servidor, valida toque por distância (12 studs), tween, respawn |
| `src/server/DataService.luau` | 94 | DataStore **caseiro** com retry e cache; o próprio comentário manda trocar por ProfileStore |
| `src/server/Main.server.luau` | 47 | leaderstats, load/save, BindToClose |
| `src/client/Hud.client.luau` | 105 | HUD de moedas |
| `src/shared/Config.luau` | 24 | configuração |
| **Total Luau** | **442** | + 2 modelos JSON (`Baseplate`, `SpawnLocation`) |

### 3.2 Sobreposição com a Muralha

| Sistema da Muralha | Existe no protótipo? |
|---|---|
| ondas, lanes, caminhada de inimigos | não |
| armadilhas, posicionamento, grade | não |
| simulação determinística, seed, hash, replay | não |
| raid assíncrona, fantasma, liga | não |
| persistência de progresso | sim — mas com o padrão **rejeitado** (DataStore caseiro, não ProfileStore) |
| Rojo `default.project.json` | sim — e é o único valor real que sobra |

### 3.3 Mercado do gênero que o protótipo representa

O protótipo é um **simulator** de coletar moedas. Em out/2026 a ROLearn rastreava **5.865**
experiências de Simulation (37% do total), com mediana de **40 CCU**; o volume é carregado por
poucos gigantes (Grow a Garden, Pet Simulator, Steal a Brainrot). Contra isso, Strategy tem
mediana 66 e top 10% em 1.879. **Manter o protótipo não é uma tese de produto** — é higiene de repo.

### 3.4 Prática de separação protótipo/produção

- A Roblox separa **Save to Roblox** (rascunho) de **Publish** (jogador vê). Test place é um lugar
  separado, prática comum no DevForum ([exemplo](https://devforum.roblox.com/t/how-to-make-a-testdevelopment-place/4063999/3), B).
- Não há padrão oficial de staging de código: a resposta literal de um tópico do DevForum sobre o
  assunto é **"Not really."** ([tópico](https://devforum.roblox.com/t/seeking-the-best-way-to-stage-code-before-publishing/2180321), B).
- Protótipo é descartável por definição; o git guarda o histórico. O repo já tem a regra
  "doc mais velho que código mente" — um segundo jogo no `src/` é a mesma armadilha em forma de código.

### 3.5 Prova local: o pipeline não depende do protótipo

Rodei os dois builds no WSL, com o toolchain do repo:

| Build | Entrada | Saída |
|---|---|---|
| atual | `default.project.json` + `src/**` | `jogo-atual.rbxl` — **8,6 KB** |
| stub | 10 linhas de JSON (`DataModel` + 3 serviços vazios) | `stub.rbxl` — **440 B** |

Ou seja: apagar `src/**` **não quebra** `rojo build`. Um stub de 10 linhas + `rojo build` no CI
prova o pipeline em cada commit. O valor de teste do protótipo é substituível a custo ~zero.

### 3.6 Custo × benefício

| Apagar na P1 (a) | Manter como cena de teste (b) |
|---|---|
| perde o exemplo de servidor autoritativo (12 studs) — mas a lição já está na spec | mantém um exemplo executável de Rojo + DataStore |
| obriga a criar stub + CI (10 linhas, 1 job) | mantém 442 linhas de um jogo que não é o produto |
| elimina a ambiguidade "qual é o jogo?" | mantém a ambiguidade — e o risco de alguém reusar o DataStore caseiro |
| histórico continua no git (tag/commit) | precisa de dono e de manutenção a cada mudança de toolchain |

### 3.7 Leitura da Q1 (com confiança)

**A evidência sustenta (a) — apagar na P1 — com três condições:** tag/commit antes, stub de teste
com `rojo build` no CI, e registrar na spec a única lição aproveitável (validação de distância no
servidor, que já existe no GDD/spec). *Confiança média-alta.* A opção (b) só se justifica se o
protótipo for **de fato usado** como cena de teste nos próximos 30 dias — não há evidência de uso.

**Decisão (09/11/2026):** (a) — apagar na P1, preservando `src/shared/sim/`, com tag `legacy-coins`,
stub de 10 linhas e `rojo build` no CI. Reabre se o protótipo for usado como harness em 30 dias ou se
o stub não construir.

---

## 4. O que mudaria a resposta (falsificadores)

| Se… | Então… |
|---|---|
| no teste, 5×5 derrubar a primeira vitória < 60s de 70% para < 50% | cortar para 5 slots no MVP; grade vira expansão |
| no teste, jogadores descreverem 5 slots como "raso" (> 40% das respostas) | manter 25 células com 5 armadilhas ativas |
| 25 células exigirem explicar o tabuleiro (tempo até 1ª colocação > 20s) | reduzir para 15 células (5×3) antes de reduzir para 5 slots |
| o protótipo for usado como harness de Studio em 30 dias | reabrir Q1(b); hoje não é usado |
| `rojo build` no CI falhar sem `src/**` | a premissa 3.5 cai; manter stub passa a ser obrigatório (não o jogo de moedas) |

---

## 5. Experimento que fecharia a Q2 (barato, pré-P0)

> **Atualização (09/11/2026):** Q2 foi fechada com N=5 e colocação livre; este experimento vira o fallback de playtest.

Dois greyboxes jogáveis, mesma arte, mesma economia, 20–30 jogadores do público 13–34 (não a equipe):

| Métrica | Como medir | Critério |
|---|---|---|
| primeira vitória | cronômetro na sessão | ≥ 70% em < 60s |
| tempo até a 1ª colocação | telemetria do protótipo | ≤ 20s |
| erro/desfazer de posicionamento | contagem por sessão | ≤ 1 por sessão |
| "parece profundo?" | escala 1–5 depois de 3 ondas | média ≥ 4 |
| "jogaria de novo?" | binário | ≥ 60% sim |

Se 5×5 bater os cinco, mantém 25 células **com um limite de armadilhas ativas definido junto**. O MVP
do GDD diz "5 armadilhas", mas isso são **5 tipos** (linha 127); quantas ficam no tabuleiro ao mesmo
tempo é a decisão que falta — e ela precisa ser tomada antes da P1, não herdada do PoC. Se falhar em
dois ou mais, 5 slots no MVP e grade como desbloqueio — a decisão 1 do GDD lida ao contrário
(expansão em vez de base).

---

## 6. Limites desta pesquisa

- Busca web não é census: os números de CCU são **snapshot de 09/11/2026**, não média.
- Comentários de jogador do Roblox não são raspáveis em escala; as falas citadas vêm de Steam
  (público PC), fóruns do Fandom e resenhas — não do jogador mobile brasileiro de 13–17.
- O corpo do tópico do Fandom do TDS ("placement limits") não carregou; usei o título, não o texto.
- Steam/BTD6 é PC-first; os quotes mostram fricção de mouse, que no celular é pior — direção, não
  magnitude.
- Não há dado público de retenção por layout de TD; a única forma de saber é o experimento da §5.

---

## 7. Fontes

| Nível | Fonte | Data | Uso |
|---|---|---|---|
| A | [GameAnalytics — 2026 Roblox Benchmark Report](https://www.gameanalytics.com/reports/2026-roblox-report) | set/2026 | retenção 10,3/1,6/0,5 · sessão 7,28 min · dispositivos |
| A | [ROLearn — Genre CCU Benchmarks 2026](https://intelligence.rolearn.dev/reports/roblox-genre-ccu-benchmarks-2026) | 24/10/2026 | Strategy vs Simulation · medianas e top 10% |
| A | [rblxdb — Best Roblox Tower Defense](https://rblxdb.com/best-roblox-games/tower-defense) | 09/11/2026 | 30 jogos · 22,9 bi de visitas · 93% like |
| A | [rblxdb — Build Defense](https://rblxdb.com/games/build-defense-5678463488) | 09/11/2026 | base TD: 652 CCU, −31%, sessão 0,6 min |
| A | [rblxdb — Mutant Plants: Base Defense](https://rblxdb.com/games/mutant-plants-base-defense-world-boss-10531477636) | 09/11/2026 | base TD: 2.514 CCU, 98% like |
| B | [TDS Wiki — How to Play](https://tds.fandom.com/wiki/How_to_Play) | 2026 | 40/30/25/20 torres · 5 slots · duplo toque mobile |
| B | [PvZ Wiki — Lawn](https://plantsvszombies.fandom.com/wiki/Lawn) | 2026 | grade 5×9, uma por casa |
| B | [Kingdom Rush — towers](https://kingdomrush.org/guides/towers) | 2026 | 4–6 torres · posicionamento > upgrade |
| B | [Roguelike Radar — Super Auto Pets](https://roguelikeradar.com/games/super-auto-pets/) | 08/2026 | 5 slots · "tiny team can look strategically slight" |
| B | [DevForum — staging de código](https://devforum.roblox.com/t/seeking-the-best-way-to-stage-code-before-publishing/2180321) | 02/2023 | "Not really", ausência de padrão oficial |
| B | [DevForum — test/development place](https://devforum.roblox.com/t/how-to-make-a-testdevelopment-place/4063999/3) | 11/2025 | prática de place separado |
| C | [Steam — BTD6 snap placement](https://steamcommunity.com/app/960090/discussions/0/3280317523017565472) | 04/2022 | fricção de posicionamento · "grids are awful" |
| C | [Fandom TDS — placement limits](https://tds.fandom.com/f/p/4400000000000315360) | 2026 | título: restrição percebida como punição |
| C | [FinalBoss — Mechabellum](https://finalboss.io/mechabellum-beginner-guide-to-unit-roles-deployment-and) | 07/2026 | posicionamento como habilidade |
