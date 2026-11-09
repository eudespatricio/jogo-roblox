# GDD — MURALHA 2.0

Versão 1.0 · novembro/2026 · decisões fechadas em 09/11/2026
Gênero: tower defense invertido + autobattler assíncrono + co-op de dupla
Público: 13–34, com foco de monetização em 18+ verificado (DevEx US$ 0,54 / 100 R$)
Plataforma: Roblox (mobile-first, PC parity)

---

## 0. Pitch em uma frase

**Você não controla um herói. Você controla a muralha.**
Monte a fortaleza, veja o exército de outro jogador quebrá-la enquanto você dorme,
e volte para assistir ao replay de 8 segundos e se vingar.

---

## 1. Fantasia central e câmera

| Elemento | Decisão |
|---|---|
| Câmera | isométrica fixa, sem livre-orbitar (barato, legível no celular, vira clipe) |
| Avatar | **nenhum personagem de jogador visível** (habilita DevEx 18+ e corta ~70% do custo de arte) |
| Escala | diorama de guerra: muralha de madeira/ferro, engenhocas, hordas em silhueta |
| Tom | cômico-macabro, físico, exagerado — "Tom & Jerry com catapultas" |
| Referência emocional | a tensão de ver seu castelo cair + a risada de ver o do amigo cair |

---

## 2. Drop-in de 5 segundos (a mutação que blinda o 61–180s)

O sinal de bounce do algoritmo mede quem sai entre 61 e 180 segundos. Tutorial de estratégia
tradicional morre exatamente aí. Então o jogo **começa no meio de uma batalha**.

Roteiro, segundo a segundo:

| t | O que acontece | Por quê |
|---|---|---|
| 0,0s | câmera já no portão; horda aparece no horizonte; barra da muralha pulsa | contexto em 1 frame |
| 0,5s | horda corre; som de impacto; terra tremendo | tensão sem texto |
| 1,5s | **um único botão gigante**: "DEFENDER" | zero escolha = zero paralisia |
| 3,0s | ao apertar: salva de catapulta, slow motion de 0,3s, corpos voando | dopamina física |
| 5,0s | onda limpa; "+3 moedas · armadilha desbloqueada"; UI de build entra | recompensa antes do menu |
| 8,0s | segunda onda, mais fraca; jogador coloca a primeira armadilha | primeira decisão com contexto |
| 25s | vitória; tela de build completa | jogador já entendeu o loop |

Regras de implementação:

- a cena de abertura é **uma batalha real do motor**, com seed fixa e muralha pré-montada;
- o botão "DEFENDER" dispara um evento pré-autorizado (não é fake): a catapulta existe e causa dano;
- nenhum texto de tutorial: ícones, setas e números;
- se o jogador não apertar em 6s, o botão pulsa mais forte; em 10s, a horda quebra o portão
  (derrota roteirizada) e o jogo oferece "tentar de novo" — perder também ensina.

**Meta:** 70% dos novos jogadores completam a primeira vitória em menos de 60 segundos.

---

## 3. Loop principal

```
LOGIN
  └─ Replay de vingança (8s, fast-forward da última defesa)
       ├─ "quebraram sua muralha" → CTA: VINGAR (ataca a muralha daquele jogador)
       └─ "seguraram"            → CTA: MELHORAR (upgrade no ponto mais danificado)
  └─ Cercos do dia (livres) + 3 Grandes Saques
       ├─ FASE DE BUILD   (2–4 min) posicionar armadilhas, escolher comandante, montar onda
       ├─ FASE DE RAID    (60–90s) simulação assistida 1x/4x contra muralha fantasma
       └─ RESULTADO       ouro + XP + fragmento de blueprint (Grande Saque)
  └─ Invasão Global do Dia (1 tentativa, mesma seed para todos)
  └─ Liga semanal (clã/dupla)
```

### Tempos alvo

| Etapa | Duração | Métrica que alimenta |
|---|---|---|
| Replay + coleta | 20–40s | D2 retorno |
| Build | 2–4 min | sessão média ≥ 8 min |
| Raid assistida | 60–90s | tempo de sessão, clipe |
| Sessão completa | 6–10 min | 1,56 sessões/dia de mercado |
| Cercos por dia | livres | **sem timer duro** (não corta sessão) |

---

## 4. Modos

### 4.1 Solo (MVP)
Você é o defensor e o atacante da sua própria progressão: monta muralha, ataca fantasmas de
jogadores do seu elo, recebe relatório de quem te atacou.

### 4.2 Dupla / Muralha de Clã (fase 2)
Dois jogadores compartilham **a mesma muralha**: metade esquerda de um, direita do outro,
ouro compartilhado com contribuição registrada. A onda de ataque é combinada.

- assíncrono primeiro: os dois editam quando quiserem; o servidor versão-a-versão;
- o relatório mostra **qual lado caiu primeiro** — a fonte do "culpar o amigo";
- raid em dupla: os dois assistem juntos e podem gastar "cartas de emergência".
- tempo real simultâneo só depois de validar retenção (custo de netcode não se paga no MVP).

### 4.3 Invasão Global do Dia
Uma muralha da IA com seed pública, igual para todos, uma tentativa por dia.
Ranking por muralha restante + tempo. Recompensa: fragmento cosmético.
Custo real: pipeline de seed + leaderboard + tela. **Não são 50 linhas** — 1 a 2 semanas.

---

## 5. Progressão e economia

| Camada | O que sobe | Como sobe | Limite |
|---|---|---|---|
| Conta | nível de muralha (HP, slots) | XP de raid | soft cap diário |
| Coleção | armadilhas (5 tipos × 3 níveis) | ouro + blueprints | desbloqueio por liga |
| Comandante | passiva única (ex.: +10% dano de fogo) | temporada | 1 equipado |
| Liga | elo semanal | pontos de defesa/ataque | reset semanal |

**Ouro:** ganho em raids e defesas; nunca comprado diretamente com Robux.
**Blueprint:** receita de layout; pode ser compartilhado com amigo (viral).

### Curva alvo (primeiros 7 dias)
- Dia 1: 3 raids, desbloqueia 2ª armadilha.
- Dia 2: primeira defesa bem-sucedida (replay), desbloqueia comandante.
- Dia 3: primeira derrota dura → motivo para upgrade.
- Dia 7: liga semanal + primeira meta de blueprint raro.

**Regra de balanceamento (medida na PoC):** ondas escalam por **força** (HP, resistência,
velocidade), nunca por contagem — o cap de 60s trunca ondas acima de ~85 unidades.

---

## 6. Monetização ética

| Item | Preço alvo (R$) | Tipo | Vende poder? |
|---|---|---|---|
| Passe de temporada | 399–599 | progressão cosmética + desafios | não |
| Skin de muralha | 149–399 | cosmético | não |
| Efeito de destruição | 99–249 | cosmético (clipe!) | não |
| Comandante cosmético | 199–349 | visual + voz | não |
| Slot de blueprint | 199 | conveniência (cap 10) | não |
| Grande Saque extra | 25–50 | 1 por dia, além dos 3 grátis | limite, não poder |

Proibido: loot box, venda de dano/HP, odds escondidas, timer de ansiedade.
O gatilho de conversão é **orgulho e clipe**, não frustração.

Gancho 18+: `PromptAgeCheck()` oferecido no momento de recompensa (nunca no spawn, nunca
bloqueando conteúdo — console/VR não suportam). Selo cosmético "verificado" opcional.

---

## 7. Direção de arte e áudio

- **Paleta:** defensores em âmbar (#F59E0B) e ferro; atacantes em verde-água frio (#14B8A6).
- **Silhueta:** cada unidade legível a 200px de distância (teste do thumbnail).
- **Destruição:** partículas baratas (madeira, faísca, fumaça) + ragdoll **cosmético** no cliente.
- **Física:** gameplay usa impulsos determinísticos (curvas), não física do Roblox.
- **Áudio:** impacto seco, madeira rangendo, "batimento" da muralha quando HP < 30%.
- **Vídeo de 6s:** a peça de marketing é a muralha explodindo — gravar sempre que possível.

---

## 8. KPIs e gates

| Métrica | Gate para continuar | Onde medir |
|---|---|---|
| Primeira vitória < 60s | ≥ 70% | telemetria de funil |
| Bounce < 180s | ≤ 40% | Creator Analytics + interno |
| D1 | ≥ 15% | retenção |
| D7 | ≥ 3% | retenção |
| Sessão média | ≥ 8 min | sessão |
| Replay assistido | ≥ 50% dos retornos | telemetria interna |
| Pagantes | ≥ 2% | monetização |
| ARPDAU | ≥ US$ 0,02 | monetização |

Se dois gates falharem na semana 13: **pivô ou morte**, sem apego.

---

## 9. Escopo do MVP (30 dias) e não-objetivos

**Entra:**
- 1 muralha (grid **5×5**), 5 armadilhas, 3 unidades inimigas, 1 comandante;
- drop-in de 5s;
- cercos livres + 3 Grandes Saques/dia;
- raid assíncrona contra fantasma;
- replay de defesa de 8s;
- telemetria completa do funil.

**Não entra:**
- co-op em tempo real (só dupla assíncrona na fase 2);
- grade 7×5 (entra no nível 5 da muralha);
- clã, chat, UGC de blueprint;
- segundo mapa, chefes, temporada paga;
- física real de ragdoll no gameplay.

---

## 10. Fases (donos definidos só depois do GDD fechado)

| Fase | Semanas | Entrega | Critério de saída |
|---|---|---|---|
| P0 | 1 | motor determinístico + testes headless | 1.000 batalhas com hash estável |
| P1 | 2–3 | drop-in, build, raid, replay | 70% de primeira vitória < 60s |
| P2 | 4–6 | meta, energia, liga, telemetria | D1 ≥ 15% (300–500 jogadores) |
| P3 | 7–9 | dupla assíncrona, loja, localização | pagantes ≥ 2% |
| P4 | 10–12 | Invasão Global, temporada, candidatura Standout | D7 ≥ 3% e D30 ≥ 0,8% |

Regra: **cada fase só começa se a anterior bateu o critério.** Sem exceção.

### Regras herdadas da pesquisa de jogadores

Levantamento em [`pesquisa-jogadores.md`](pesquisa-jogadores.md) — 9 clusters de reclamação do
gênero e pedidos explícitos dos jogadores. As que entram no design:

1. nenhuma unidade obrigatória (mata o gatekeeping);
2. poder só se ganha jogando; Robux só compra cosmético;
3. solo é o modo principal, dupla é bônus;
4. ninguém depende da presença de outro jogador para jogar;
5. replay do passado, não gravação do futuro — o motor determinístico entrega o que o
   Video Captures API não entrega (o clipe do que já aconteceu);
6. toda derrota tem relatório de batalha explicando o porquê;
7. balanceamento por temporada, com compensação;
8. mobile é o alvo, não a versão reduzida;
9. chat curado no MVP (quick chat), sem chat livre;
10. nenhuma recompensa depende de sorte paga (política de paid random items).

---

## 11. Decisões fechadas (09/11/2026)

| # | Decisão | Consequência técnica |
|---|---|---|
| 1 | **Grade 5×5 no MVP**, expandindo para 7×5 no nível 5 da muralha | layouts salvos por índice de célula; expansão adiciona colunas à direita, células antigas mantêm coordenada; migração de save trivial |
| 2 | **Cercos livres**, com **3 Grandes Saques/dia** (blueprints) | sem timer duro; economia controlada pelo loot, não pela porta |
| 3 | **Derrota perde só pontos de liga** + muralha fumegando no login + conserto grátis | nunca destrói nível de armadilha; o gatilho é emocional, não punitivo |
| 4 | **Nome localizado**: `A MURALHA` (PT-BR) · `WALLBREAKER` (EN) | título/descrição por locale no Creator Dashboard |
| 5 | **Co-op na P3** | MVP 100% solo + fantasma assíncrono + replay de 8s |

Ponto de atenção na decisão 1: a grade 5×5 fixa no código; a expansão é **dado**, não código novo
(`gridWidth` no save). Se o jogador voltar de 7×5 para 5×5 (não previsto), células fora da grade
ficam dormentes, não são apagadas.
