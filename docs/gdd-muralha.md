# GDD — MURALHA 2.0

Versão 1.2 · novembro/2026 · decisões fechadas em 09/11/2026 (enriquecida em 13/11/2026 — Co-op Síncrono, Física Real Híbrida e 3 Pilares desbloqueados)
Gênero: tower defense invertido + autobattler (assíncrono e co-op síncrono) + campanha com bosses
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
| 5,0s | onda limpa; "+3 de ouro · armadilha desbloqueada"; UI de build entra | recompensa antes do menu |
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

### 4.2 Dupla / Muralha de Clã (Assíncrono + Co-op Síncrono desbloqueado em 13/11/2026)
Dois jogadores compartilham **a mesma muralha**: Setor A (`r1–r2`) de um, Setor B (`r4–r5`) do outro, e a Lane 3 como Portão Partilhado (`N = 8` armadilhas: `4 + 4`).

- **Dupla Assíncrona:** os dois editam quando quiserem sob controle otimista de revisão (`rev++`), sem depender de presença simultânea;
- **Co-op Síncrono em Tempo Real (desbloqueado pelo diretor em 13/11/2026):** ambos defendem ao vivo em servidor reservado (`TeleportService:ReserveServer`) sob *lockstep* server-authoritative de `20 Hz` (`scheduledTick = currentTick + 2`), cursor etéreo `10 Hz`, 4 Pings Táticos 3D, carteiras separadas com botão **Enviar +25 Ouro** e protocolo anti-leaver em 3 camadas (rejoin `90s` + transferência em `10s` + re-escalonamento de HP). O `BattleLog v2` grava `commands[]` para preservar 100% o replay de 8s;
- o relatório pós-batalha mostra **qual lado caiu primeiro** — a fonte do "culpar o amigo".

### 4.5 Campanha História "Crônicas do Bastião" & Bosses (Solo / Duo)
5 Atos × 5 estágios (`25` fases + Modo Pesadelo), 100% completáveis **Solo**, em **Dupla Assíncrona** ou em **Dupla Síncrona**, culminando nos **5 Bosses de Cerco** multi-lane (`iron_ram_colossus`, `slag_juggernaut`, `rime_matriarch`, `powder_baron`, `rift_titan`) com selos de 3★ e 8 mutadores determinísticos. Ver [`campanha-bosses-e-coop-sincrono.md`](campanha-bosses-e-coop-sincrono.md).

### 4.3 Invasão Global do Dia
Uma muralha da IA com seed pública, igual para todos, uma tentativa por dia.
Ranking por muralha restante + tempo. Recompensa: fragmento cosmético.
Custo real: pipeline de seed + leaderboard + tela. **Não são 50 linhas** — 1 a 2 semanas.

### 4.4 Clipe de Vingança (a lacuna da plataforma virando feature)

A `CaptureService` da Roblox só grava **para frente** — o pedido mais repetido no DevForum é
"grave os últimos 30 segundos". Nosso replay é re-simulação do passado, então:

1. botão **GRAVAR CLIPE** aparece no replay de vingança;
2. `StartVideoCaptureAsync()` começa a gravar a tela;
3. pré-roll de ~0,5s (aquecimento da captura);
4. replay de 8s em câmera lenta no momento da ruptura;
5. `StopVideoCapture()` e `PromptSaveCapturesToGallery()` — o jogador decide salvar.

É o único jeito de o jogador sair com o clipe **do que já aconteceu**, sem OBS e sem prever o futuro.
Detalhes técnicos e limitações em [`spec-motor-deterministico.md`](spec-motor-deterministico.md#51-gravar-clipe).

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
> Custos, desbloqueio e eventos da P1: [`economia-muralha.md`](economia-muralha.md).

### Curva alvo (primeiros 7 dias)
- Dia 1: primeira sessão rende 3 raids e desbloqueia a 2ª armadilha.
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

## 7. Direção de arte, física real híbrida e áudio

- **Paleta:** defensores em âmbar (#F59E0B) e ferro; atacantes em verde-água frio (#14B8A6).
- **Silhueta:** cada unidade legível a 200px de distância (teste do thumbnail).
- **Física Real Híbrida (desbloqueada em 13/11/2026):** gameplay autoritativo usa impulsos determinísticos inteiros (`MILLI=1000` em `Core`) combinados à **física real do Roblox no cliente** (`BallSocketConstraint` ragdolls, estilhaçamento elemental, colapso de ameias `<70%`, vigas com `HingeConstraint` `<30%` e fratura do portão em 12 blocos aos `0%`) isolada em `CollisionGroups` (`CanQuery=false`) com governor mobile (`Low <=6`, `Mid <=18`, `High <=36`). Ver [`animacoes-fisica-real-e-vfx.md`](animacoes-fisica-real-e-vfx.md).
- **Animações 60 Hz & VFX:** máquinas de estado para traps, horda e 5 Bosses com hit-squash, telégrafos no chão (`2.0s`) e `<=40` partículas/emitter.
- **Áudio & OST Adaptativa:** `SoundGroup MuralhaMaster` + `BGM_Bus` (4 stems verticais + 5 Atos em 120/132 BPM), `wall_heartbeat` abaixo de 30% HP, 36 SFX 3D normalizados a `-14 LUFS` e stinger de finisher para o clipe de 8s. Ver [`audio-musica-e-soundscape.md`](audio-musica-e-soundscape.md).
- **Vídeo de 6s/8s:** a peça de marketing é a muralha explodindo — gravar sempre que possível.

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
| Clipes salvos | ≥ 5 por 100 sessões | CaptureService + telemetria |
| Pagantes | ≥ 2% | monetização |
| ARPDAU **líquido** | ≥ US$ 0,005 (bruto ≈ 0,0225; ~BRL 20 mil/mês a 25 mil DAU) | monetização |

Premissas de planejamento (09/11/2026): **2% de pagantes/mês sobre a MAU × ARPPU US$ 2** (base);
**4,5% × US$ 5** é o cenário de topo que passa o gate. Ver
[`decisao-monetizacao.md`](decisao-monetizacao.md).

Se dois gates falharem na semana 13: **pivô ou morte**, sem apego.

---

## 9. Escopo do MVP (30 dias) e não-objetivos

**Entra:**
- 1 muralha (grid **5×5**, **N=5 armadilhas ativas**), 5 tipos de armadilha, 3 unidades inimigas,
  1 comandante;
- drop-in de 5s;
- cercos livres + 3 Grandes Saques/dia;
- raid assíncrona contra fantasma;
- replay de defesa de 8s;
- telemetria completa do funil.

**Não entra no núcleo P1 fechado (`S1–S8`, até o gate de 3 semanas):**
- grade 7×5 (entra no nível 5 da muralha na P2+);
- clã, leaderboard global, UGC de blueprint;
- segundo mapa e temporada paga.

**Desbloqueado pelo diretor em 13/11/2026 (roadmap V1.5/P2+, especificado com zero brechas):**
- **Co-op Síncrono em tempo real** (lockstep 20 Hz + `commands[]` no replay 8s + anti-leaver 90s);
- **Física Real Híbrida** (camada cliente isolada em S8.2/V1; impulsos `Core` na P2+);
- **Campanha Solo/Duo *Crônicas do Bastião* + 5 Bosses** e **Sistemas Comerciais Completos** (`RFC-007..009`).

---

## 10. Fases (donos definidos só depois do GDD fechado)

| Fase | Semanas | Entrega | Critério de saída |
|---|---|---|---|
| P0 | 1 | motor determinístico + testes headless | 1.000 batalhas com hash estável |
| P1 | 2–3 | drop-in, build, raid, replay | 70% de primeira vitória < 60s |
| P2 | 4–6 | meta, liga, sink HTTP externo (telemetria base entregue antecipadamente na P1/S7), loja | D1 ≥ 15% (300–500 jogadores) |
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
| 1 | **Grade 5×5 no MVP, com N=5 armadilhas ativas e colocação livre nas 25 células**, expandindo para 7×5 no nível 5 | N=5 é o orçamento simultâneo (não o nº de células nem de tipos); layouts salvos por índice de célula; 7×5 adiciona espaço, não N; migração de save trivial |
| 2 | **Cercos livres**, com **3 Grandes Saques/dia** (blueprints) | sem timer duro; economia controlada pelo loot, não pela porta |
| 3 | **Derrota perde só pontos de liga** + muralha fumegando no login + conserto grátis | nunca destrói nível de armadilha; o gatilho é emocional, não punitivo |
| 4 | **Nome localizado**: `A MURALHA` (PT-BR) · `WALLBREAKER` (EN) · `LA MURALLA` (ES) | título/descrição por locale no Creator Dashboard + `assets/i18n/LocalizationTable.csv` |
| 5 | **Co-op na P3 → Desbloqueado em 13/11/2026** | MVP P1 100% solo + fantasma assíncrono + replay 8s; Dupla Assíncrona e Co-op Síncrono Lockstep desbloqueados para V1.5/P2+ (`RFC-007`) |

Ponto de atenção na decisão 1: a grade 5×5 fixa no código; a expansão é **dado**, não código novo
(`gridWidth` no save). Se o jogador voltar de 7×5 para 5×5 (não previsto), células fora da grade
ficam dormentes, não são apagadas.

**Q2 fechada (09/11/2026):** a grade é 5×5 com armadilhas por célula e 5 lanes; **N = 5 armadilhas
ativas simultâneas** no MVP, com **colocação livre entre as 25 células** — C(25,5) = 53.130 layouts.
O modelo de “5 slots” (1 por lane) é um caso particular (N=5 com restrição), não a arquitetura de
produção. Crescer N é progressão (P2), não reabre Q2. Fallback de playtest: se a primeira vitória
ficar < 50% ou a 1ª colocação > 20s, testar 15 células (5×3) antes de voltar para 5 slots.

---

## Documentos Complementares Detalhados (13/11/2026)

- [`literatura-e-universo.md`](literatura-e-universo.md) — lore diegético zero-avatar (*Ordem do Âmbar* vs *Fendas Mercenárias*), comandantes, micro-literatura e quick-chat.
- [`catalogo-itens-e-cosmeticos.md`](catalogo-itens-e-cosmeticos.md) — catálogo P1 + backlog horizontal P2/P3, unidades da horda, plantas, cosméticos e passe regionalizado.
- [`skills-tiers-e-modos.md`](skills-tiers-e-modos.md) — sinergias espaciais, *Gambits* determinísticos, traits horizontais, calibração do Dia 1, 7 ligas, tiers e 7 modos.
- [`direcao-visual-e-silhuetas.md`](direcao-visual-e-silhuetas.md) — lei cromática, matriz L1–L5 × Tier Cosmético, estados de destruição da muralha, UX mobile e pipeline 3D/áudio.
- [`arquitetura-e-fluxos.md`](arquitetura-e-fluxos.md) — topologia em 4 camadas, 5 fluxos end-to-end, arquitetura P2 de DataStores e auditoria `AUD-01..12`.
- [`plano-playtest-v1.md`](plano-playtest-v1.md) — runbook zero-brechas para entregar o **Playtest V1** (Fatias S8.1 `GAP-014`, S8.2 `GAP-017`/client `GAP-019` e S8.3 opcional `SIM_VERSION = 4`).
- [`rfcs-p2-e-fechamento-gaps.md`](rfcs-p2-e-fechamento-gaps.md) — compêndio completo de RFCs (`RFC-001..009`) estruturando o fechamento de `GAP-004..GAP-020`.
- [`audio-musica-e-soundscape.md`](audio-musica-e-soundscape.md) — Pilar 1: hierarquia `SoundService`, OST adaptativa (4 stems verticais + 5 Atos), 36 SFX 3D e pipeline `-14 LUFS`.
- [`campanha-bosses-e-coop-sincrono.md`](campanha-bosses-e-coop-sincrono.md) — Pilar 2 & Co-op Síncrono: Campanha 5 Atos (Solo/Duo), 5 Bosses multi-lane no `Core` e lockstep `20 Hz` + anti-leaver `90s`.
- [`animacoes-fisica-real-e-vfx.md`](animacoes-fisica-real-e-vfx.md) — Pilar 3: Física Real Híbrida (`CollisionGroups` isolados, `BallSocketConstraint` ragdoll, fratura de portão, governor mobile), animações 60 Hz e VFX.
- [`sistemas-jogo-completo.md`](sistemas-jogo-completo.md) — FTUE 30 min, Pós-Partida/DPS Meter, Contratos/Passe/12 Badges, Ordens/Blueprints, Acessibilidade/Gamepad/i18n e Loja `ProcessReceipt` + `PolicyService`.
