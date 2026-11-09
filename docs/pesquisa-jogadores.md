# O que os jogadores reclamam (e pedem) — evidência, não opinião

Objetivo: extrair regras de design de reclamações reais e de pedidos feitos pelos próprios jogadores,
antes de escrever uma linha do jogo. Nada aqui é "achismo de criador": cada linha tem fonte e nível.

## Como ler os níveis de evidência

| Nível | O que é | Peso |
|---|---|---|
| **A** | documentação oficial da Roblox, política da plataforma, dados primários da empresa | alta |
| **B** | comunidade estruturada: wiki colaborativa com histórico, thread do DevForum com dezenas de respostas | média |
| **C** | comentário isolado, review individual | baixo — sinal, não prova |

---

## 1. Os clusters de reclamação (nível B — Tower Defense Simulator)

Fonte: [NamuWiki — Tower Defense Simulator/Problemas](https://en.namu.wiki/w/Tower%20Defense%20Simulator/%EB%AC%B8%EC%A0%9C%EC%A0%90)
(página colaborativa, atualizada em out/2026, com histórico; é o caso mais documentado do gênero que
a gente vai atacar).

| # | Reclamação | O que acontece na prática | Causa raiz |
|---|---|---|---|
| 1 | **Abandono no meio da partida** | jogador sai e o time fica sem DPS e com limite de torres reduzido; não há punição nem rejoin confiável | co-op depende de presença; sistema de rejoin bugado |
| 2 | **Gatekeeping de novato** | "deck check", "level check", expulsão de quem não tem a torre meta | uma torre vira **obrigatória** e o novato não tem |
| 3 | **Pay-to-win percebido** | torres essenciais custam grind enorme (Minigunner ~8.000, Ranger ~12.000 moedas; torres de hardcore exigem modos extremos) | poder vendido/destravado por grind; evento desenhado para exigir a torre |
| 4 | **Grind** | "rodar Molten 10 vezes" para comprar a torre que torna o jogo divertido | recompensa concentrada no fim, não na sessão |
| 5 | **Nerf destrutivo** | update derruba uma torre da tier 1 para o lixo; quem investiu perde | balanceamento sem temporada nem compensação |
| 6 | **Bugs e matchmaking** | bugs frequentes; matchmaking escolhe mapa aleatório; rejoin falha | falta de instrumentação e de versionamento |
| 7 | **Mobile / aparelho fraco** | lag em celular e PC antigo; "velas por frame" em evento | física e densidade visual altas |
| 8 | **Conteúdo travado atrás de torre** | evento impossível sem a torre de hardcore | progressão por poder, não por skill |
| 9 | **Chat tóxico** | novatos x veteranos, insultos, discriminação | chat livre sem ferramenta de convivência |

### Leitura

Nenhuma dessas nove reclamações é sobre "falta de conteúdo". Todas são sobre **estrutura social,
economia e confiabilidade**. É exatamente onde um jogo assíncrono e determinístico tem vantagem.

---

## 2. O que os jogadores pedem espontaneamente (nível A/B)

| Pedido | Evidência | Implicação |
|---|---|---|
| **"Gravar os últimos 30 segundos", não os próximos** | [DevForum — Moments](https://devforum.roblox.com/t/roblox-moments-a-new-era-of-user-generated-discovery-for-experiences-and-gameplay-is-here/3919813) e [Video Captures API](https://devforum.roblox.com/t/beta-video-captures-api-bring-your-gameplay-moments-to-life/3823116): vários pedidos explícitos; "a maioria dos softwares de clipe serve para o que já aconteceu" | replay do passado é desejo não atendido — nosso motor determinístico entrega isso de graça |
| **Sistema de replay / espectador** | comentários no mesmo thread: "achei que seria um replay system" | demanda real; nossa arquitetura já nasce com isso |
| **Modo solo viável** | TDS: jogadores pedem solo e servidor privado; o jogo só virou solitário depois de rebalancear | solo precisa ser primeira classe, não fallback |
| **Matchmaking melhor** | TDS: matchmaking aleatório de mapa; elo ausente | elo + fantasma assíncrono |
| **Onboarding menos punitivo** | TDS: torres iniciais buffadas depois de anos de reclamação | primeira vitória em < 60s, sem parede de poder |
| **Menos pay-to-win** | TDS: percepção de que sem a torre paga não se joga | monetização cosmética, sem venda de poder |
| **Transparência de odds** | política oficial de [paid random items](https://create.roblox.com/docs/production/monetization/paid-random-items): odds numéricas obrigatórias | se um dia houver aleatoriedade paga, ela precisa ser explicável — melhor não ter |

Dados oficiais que sustentam o potencial de clipe (nível A): a Roblox reporta **930 milhões de
screenshots** e **240 milhões de vídeos** capturados em poucas semanas após o lançamento da API,
e **1 trilhão de views** de conteúdo Roblox no YouTube.

**Como a Muralha fecha essa lacuna:** o replay é re-simulação do passado, então o botão "GRAVAR
CLIPE" grava exatamente o que já aconteceu — o oposto da API da plataforma. Fluxo em
[`gdd-muralha.md`](gdd-muralha.md) §4.4 e [`spec-motor-deterministico.md`](spec-motor-deterministico.md) §5.1.

---

## 3. O que isso significa para a Muralha — 10 regras não negociáveis

| # | Regra | Por quê (evidência) |
|---|---|---|
| 1 | **Nenhuma unidade obrigatória.** Toda unidade tem contra-jogo e nenhuma é "a torre que resolve" | gatekeeping e P2W do TDS nascem de torre obrigatória |
| 2 | **Poder só se ganha jogando; Robux só compra cosmético** | reclamação 3 e 8; política de odds evita tentação |
| 3 | **Solo é o modo principal; dupla é bônus** | TDS só melhorou quando o solo ficou viável |
| 4 | **Ninguém depende de presença de outro jogador para jogar** | reclamação 1: leaver destrói co-op; nosso raid é assíncrono |
| 5 | **Replay do passado, não gravação do futuro** | pedido explícito no DevForum; nosso motor já entrega |
| 6 | **Toda derrota explica o porquê** (relatório de batalha) | reclamação 5 e 6: jogador não entende nerf/bug |
| 7 | **Balanceamento por temporada, com compensação** | nerf destrutivo é a reclamação mais citada de balance |
| 8 | **Mobile é o alvo, não a versão reduzida** | reclamação 7: lag em aparelho fraco |
| 9 | **Chat curado (quick chat) no MVP; chat livre só com moderação** | reclamação 9 e política de segurança |
| 10 | **Nenhuma recompensa depende de sorte paga** | política de paid random items + percepção de P2W |

### Onde a Muralha é estruturalmente superior ao TDS

| Problema do TDS | Por que não nos atinge |
|---|---|
| Leaver arruína a partida | a raid é assíncrona; ninguém espera ninguém |
| Novato é expulso | não há lobby para expulsar; o fantasma é sempre compatível |
| Torre obrigatória | o contra-jogo é por composição, não por unidade única |
| Grind de 10–17 runs | 3 Grandes Saques/dia com meta diária e pity |
| Bug difícil de reproduzir | batalha = seed + loadout; replay reproduz o bug em 1 clique |

---

## 4. O que ainda não sabemos (e precisa de teste, não de opinião)

| Pergunta | Como testar | Custo |
|---|---|---|
| Jogador de 13–17 entende autobattler sem tutorial de texto? | protótipo com 20 jogadores, medir primeira vitória < 60s | baixo |
| 5×5 é suficiente ou parece "pequeno"? | teste A/B de thumbnail + sessão | baixo |
| Replay de 8s aumenta D2? | cohort com e sem replay no login | médio |
| Quanto o público 18+ aceita pagar por cosmético? | teste de preço em 3 faixas | médio |
| A Invasão Global diária retém ou frustra? | medir D7 com e sem o modo | médio |

Nenhuma dessas perguntas se resolve com debate. Todas se resolvem com 300–500 jogadores e telemetria.

---

## 5. Fontes

- [NamuWiki — TDS/Problemas](https://en.namu.wiki/w/Tower%20Defense%20Simulator/%EB%AC%B8%EC%A0%9C%EC%A0%90) (B, out/2026)
- [DevForum — Roblox Moments](https://devforum.roblox.com/t/roblox-moments-a-new-era-of-user-generated-discovery-for-experiences-and-gameplay-is-here/3919813) (A, set/2025)
- [DevForum — Video Captures API](https://devforum.roblox.com/t/beta-video-captures-api-bring-your-gameplay-moments-to-life/3823116) (A, jul/2025)
- [Roblox — Paid random items policy](https://create.roblox.com/docs/production/monetization/paid-random-items) (A)
- [GameAnalytics — 2026 Roblox Benchmark Report](https://www.gameanalytics.com/reports/2026-roblox-report) (A, set/2026)
