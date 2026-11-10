# CONTINUAR — handoff de sessão

**Data:** 10/11/2026 · **Status:** P1 em execução — **S1–S3.4 fechadas** (S3.4 com Modo B real);
**S4 fechada** (QA runtime: FPS 60/60, Play→UI 1,9 s); **S5 fechada** (drop-in, funil e +3 ouro);
**S6.1 fechada** (raid, fantasma real e replay 3D); **S7 fechada** (telemetria, contrato 30/30 e
`first_win_seconds`); GAP-011 fechado na S6; GAP-004/005/008/012 abertos · base `main` @ `6d48d43`,
CI verde. Este arquivo é autossuficiente: a conversa pode ser fechada.

> **GAP (10/11/2026):** GAP-001/002/003/009/010 fechados na S3.4; **GAP-011 fechado na S6**
> (`contentVersion` no `BattleLog` + contrato); **GAP-012 aberto na S7** (sink Null não persiste a
> série de `first_win_seconds`). Restam GAP-004/005/008/012 em `docs/gaps.md`.

GAP: GAP-004, GAP-005, GAP-008, GAP-012 · classes/taxonomia v2, live ops e persistência do sink ainda abertos · risco alto para a 1ª expansão real/P2 e para medir a saída da P1 · fechar antes de classe/P2 e antes do teste de 3 semanas · ver docs/gaps.md

> **Transição de janela:** S1–S7 fechadas em 10/11/2026. A próxima sessão fecha o **GAP-012**
> (sink persistente/export) e mede a saída da P1 no teste de 3 semanas. Não reabra S6.1/S6/S7 e não
> inicie P2.

---

## O que é este projeto

**MURALHA** — tower defense invertido + autobattler assíncrono para Roblox, mobile-first, sem avatar
visível (habilita DevEx 18+ e corta custo de arte). O jogador monta a muralha, outros atacam
enquanto ele está offline, e um replay determinístico de 8s mostra o que aconteceu — com botão de
gravar clipe via `CaptureService`.

Equipe: 1 humano (direção, cena, game feel, QA) + 2 agentes (motor/CI e sistemas/economia).
A P0 fechou em 09/11/2026. A **P1 foi autorizada** na mesma data; o plano está em
[`docs/p1-plano.md`](docs/p1-plano.md) (S1–S7).

---

## Onde paramos (10/11/2026)

- **P0 fechada:** motor determinístico, schema v1 + wrapper ProfileStore, contrato de analytics e
  teste de sessão nos Modos A (Mock) e B (DataStore real), 8/8 nas duas execuções.
- **S1 fechada — Q1, legado apagado:**
  - tag anotada `legacy-coins` no HEAD `b07b4c5`, criada **antes** de qualquer deleção; publicada
    no `origin`. A tag leve que já existia apontava para `1f241b0` (4 commits atrás) e foi refeita
    como anotada no HEAD.
  - removidos `src/server/{CoinService,DataService}.luau`, `src/shared/Config.luau` e
    `src/client/Hud.client.luau`; `src/server/Main.server.luau` virou um **stub de 10 linhas**.
  - preservados `src/shared/{sim,data,analytics}` e `src/server/{data,ProfileBoot.server}`.
  - `.styluaignore` sem `src/`; `default.project.json` sem `StarterPlayer` (não há mais client);
    `check.sh` roda StyLua em `sim src` e luau-lsp também em `src/server/data` + `Main`.
- **S2 fechada — motor 5×5/N=5:**
  - `Battle.new({ seed, simVersion, wall, wave })`; `wall.traps` é uma lista de até 5
    `{ cell = "rXcY", type, level }`, com **linha = lane** e **coluna = profundidade** (c1 junto da
    muralha, c5 junto do spawn). Colocação livre: várias armadilhas na mesma lane.
  - `Core.defaultWall()` / `Core.Run(seed)` são o atalho de loadout de referência (5 na coluna 3).
  - `simVersion = 2`; replay com versão diferente é recusado pelo motor.
  - **hash novo `2489780106`** (seed 42); o `668061367` da v1 está aposentado.
  - `sim/invariants.luau` re-ancorado em **12/12** (inclui loadout livre e recusa de loadout
    inválido); `sim/acceptance.luau` em 1.000 seeds × 3: 1.000 hashes distintos, **68,7%** de vitória
    do defensor, ~1,4 ms/batalha; `sim/analytics-contract.luau` verde com hash e `sim_version 2`;
    `sim/profile-contract.luau` segue 19/19.
- **S3 fechada — muralha/economia:**
  - `src/shared/data/TrapCatalog.luau` (fonte única de custo/upgrade/liga) +
    `src/server/walls/WallService.luau`: colocar/remover/upgrade com validação server-side de
    célula, N=5, ouro, desbloqueio e perfil compatível; muta `Profile.Data.wall.cells`/`gold`.
  - upgrade até 3 níveis; remover não devolve ouro (taxonomia v1); eventos devolvidos como
    `{name, props}`; perfil com trap desconhecida/fora da grade/acima de N falha fechado.
  - `sim/walls-contract.luau` **12/12 na S3** (13/13 após a S3.3): catálogo x motor, fontes/sinks, perfil, célula,
    N=5, ouro, desbloqueio, upgrade, remove, `creditGold`, snapshot e eventos válidos.
- **S3.3 fechada — gaps antes da S4 (10/11/2026):**
  - `WallService.toBattleWall(profile, schema, catalog, hp)` roda `validateWall`, converte `cells` em
    `wall.traps` ordenado por (linha, coluna) e devolve `nil + erro` para perfil inválido; o contrato
    da muralha foi a **13/13** (ordem determinística e mesmo hash).
  - `scripts/check-versions.py` + `docs/versoes.md`: o `check.sh` compara `SCHEMA_VERSION`,
    `CONTENT_VERSION`, `SIM_VERSION` e o hash com o bloco documentado; labels saem da fonte.
  - GAP-010 preparado: `tools/expansion-test/neutral-migration.luau` compara o hash da parede antiga
    x migrada e roda no `check.sh` (0→1); falta o primeiro schema v2 para fechar.
- **S3.4 fechada — conteúdo e versões (10/11/2026):**
  - schema v2 com `contentVersion` (migração 1→2); `TrapCatalog.ensureProfileContent` roda no boot,
    repara `oil → tar` e recusa `content_future`; o `WallService` exige a versão do catálogo.
  - conteúdo v2: `oil` virou `tar` (alias) e entrou `catapult` (5º tipo, splash); `simVersion 3` e
    hash `2489780106` preservado na parede padrão.
  - contratos: perfil **20/20**, muralha **13/13**, conteúdo **7/7**, analytics **16/16 na S3.4** (hoje 30/30), build **6/6** (hoje 14/14 após o QA da S4);
    GAP-001/002/003/009/010 fechados; GAP-011 (`BattleLog`) fechado na S6.
  - **Modo B real (10/11/2026):** `modo=DataStore`, `datastore=Access`, `schema=v2 content=v2`,
    `sessions 11 → 12`, `[selftest] PASSOU (8/8)`; `STORE_NAME=MuralhaProfile_v1` com schema v2.
    Evidência em [`docs/teste-sessao-studio.md`](docs/teste-sessao-studio.md) §9.
- **S4 fechada — cena 5×5 + build (10/11/2026, QA headless + runtime):**
  - `GridLayout`/`BuildProtocol` + `BuildClientState`/`BuildHud`/`BuildLayout` (estado, HUD e layout
    puros) + `sim/build-contract.luau` **14/14** (protocolo, intenção→`WallService`, HUD e layout).
  - `BuildGrid` cria as 25 células/muralha; `WallController.server` expõe snapshot/place/remove/upgrade
    via RemoteFunction, sempre validando no `WallService`.
  - `BuildClient` tem câmera isométrica fixa, UI 5×5, painel de armadilhas, **HUD de debug**
    (`FPS n · T x.xs · UI x.xs · COLOCAR · ARQUEIRO`, com `dt` de parede do RenderStepped) e layout
    responsivo 375×812/720×1280; `ProfileRegistry` compartilha a sessão com `WallController`.
  - **Grant de QA** em `ProfileBoot`: `ServerStorage.QaStarterGold`/`QaLeaguePoints` (só Studio/Mock,
    só perfil zerado) liberam o §5 sem Command Bar; log `[qa] grant gold=... liga=...`.
  - O scaffold logava cena/remotes, mas o `CellSize` em escala distorcia o grid e não havia número
    de FPS/UI; o QA corrigiu os dois. Runtime: **FPS 60/60 focado** em 375×812/720×1280,
    **Play→UI 1,9 s**, prints completos e `trap_limit`/`max_level`; evidência na §7 de
    `docs/teste-s4-studio.md`.
- **S5 fechada — drop-in de 5 s (10/11/2026, feature/instrumentação):**
  - `DropInState`/`DropInTelemetry` puros + `sim/dropin-contract.luau` **8/8**: fases, press
    1,5–10 s, timeout, retry, props do funil e +3 ouro via `WallService.creditGold`.
  - `DropInController.server`: remotes `DropInAction`/`DropInSnapshot`, batalha **real** fixa
    (seed 4, 100 ticks, muralha com catapulta), derrota roteirizada em 10 s e novo `shown` no retry.
  - `DropInClient`: cena local (portão/horda/catapulta), DEFENDER em 1,5 s, pulso em 6 s,
    `A HORDA PASSOU` + `TENTAR DE NOVO`; `BuildClient` espera `DropInDone`.
  - Funil: `[analytics] dropin_shown/dropin_pressed` como props validadas; envelope/sink é a S7.
    O clear credita **+3 ouro** (`WallService.creditGold(3, "defense")`) antes de liberar o build.
  - Runtime validado em 375×812/720×1280: timeout 10,1 s (sem pressed/ouro), sucesso com
    `pressed=true`/`onda limpa`/`+3 ouro`/`OURO 3`, DEFENDER ativo com horda/portão e FPS 60 no
    pós-build. A taxa ≥60% fica no teste de 3 semanas; se reprovar, a S5 reabre.
- **S6.1 fechada — raid + fantasma real + replay 3D (10/11/2026):**
  - `BattleLog`/`BattleLogLedger`/`RaidReplay`/`RaidTelemetry` puros + `sim/raid-contract.luau`
    **6/6**: `contentVersion` (GAP-011), 1 chave por `battle_id`, claim/recompensa idempotente,
    replay/hash e `battle_divergence`; o log guarda `wall` (hp + traps).
  - `BattleLogStore` (`MuralhaBattleLog_v1`) e `PhantomStore` (`MuralhaPhantom_v1`) separados,
    DataStore em produção e Mock no Studio; `RaidController` ataca a última muralha publicada via
    `toBattleWall`; `RaidClient` roda o mesmo `Core.Battle`, confere o hash e anima 8 s em um
    `ViewportFrame` 3D (lanes, traps, horda, HP).
  - Recompensa **5 ouro provisória**; QA validou vitória/derrota/hash/reward, **OURO 13**
    com archer L2 + upgrade, `BattleLog content=v2`, fantasma `traps=0→1`, replay 3D e
    `REPLAY CONCLUIDO · 8s` com `FECHAR` em 375×812; hash local = servidor, sem `DIVERGENCIA`.
    Limites do MVP: fantasma = última muralha publicada, replay local em `ViewportFrame`, reward
    provisório. Evidência em docs/teste-s6-studio.md.
- **S7 fechada — telemetria (10/11/2026):**
  - `src/server/analytics/AnalyticsService.luau` puro (tipos injetados): `emit`, lote **30 s/100**,
    rate limit de cliente **10/min**, idempotência por `event_id`, teto de 200/sessão e sink **Null**;
    `AnalyticsBoot.server.luau` liga ao perfil (`days_since_last_seen` capturado no `onStart` do
    `ProfileBoot`), gera `player_id` hash32 com salt e mantém `session_start`/`session_end`.
  - Contrato `sim/analytics-contract.luau` **30/30**: 31 eventos validados, Null, lote, rate limit,
    idempotência, teto, PII, `first_win_seconds` e prova de que o `BattleResult`/hash não mudam. A
    única mudança de contrato foi aditiva: `battle_started.traps_count` aceita `0` (muralha vazia).
  - `first_win_seconds = first_win.ts − session_start.ts`, relatório com denominador de jogadores
    novos (`is_returning=false`); `first_win` sai no clear do drop-in e em vitória de raid, uma vez
    por sessão. Coorte sintética 7/10 = 70% (aritmética; não é medição de produto).
  - Integração: `DropInController`/`RaidController` passam `battle_*`, `raid_*`, `gold_earned` e
    `first_win` pelo serviço; o log `[analytics]` continua no Studio via `onEvent` (envelope não
    aparece no Output). **GAP-012:** sink Null não persiste a série; a taxa de 70% fica para o teste
    de 3 semanas. QA em [`docs/teste-s7-studio.md`](docs/teste-s7-studio.md).
- Gate atual: `bash scripts/check.sh` passa; CI verde no workflow `ci`; contexto em **ESTADO 80/80 ·
  MAPA 59/60 · REJEITADOS 19/40**.

---

## Fatos atuais

| Métrica | Valor |
|---|---|
| tick / cap | 0,05 s · 1.200 ticks (60 s) |
| estado | 100% inteiro (`MILLI = 1000`) |
| custo por batalha | ~1,4 ms (~710 batalhas/s) |
| simVersion | **3** |
| determinismo | hash `2489780106` (seed 42, 3 execuções) |
| acceptance P1 | 1.000 seeds × 3 · 1.000 hashes · 68,7% defensor · 1,4 s/1.000 |
| invariantes | **12/12** (`sim/invariants.luau`) |
| contratos | perfil 20/20 · analytics 30/30 · muralha 13/13 · conteúdo 7/7 · build 14/14 · drop-in 8/8 · raid 6/6 (`sim/*-contract.luau`) |
| versões | schema 2 · content 2 · sim 3 · hash `2489780106` (`docs/versoes.md`) |
| muralha/economia | catálogo 5 tipos · N=5 · sem refund · `toBattleWall` · `docs/economia-muralha.md` |
| perfil | schema v2 · contentVersion · store `MuralhaProfile_v1` · migração 0→2/1→2 com fixtures |
| analytics | contrato v1 · 31 eventos · envelope + anti-PII · serviço S7 (lote 30 s/100, 10/min, Null) · `first_win_seconds` |
| teste de sessão | Modo A (Mock) 8/8 + Modo B schema v1 8/8 (09/11/2026) · Modo B schema v2 8/8 (10/11/2026) |
| contexto | ESTADO 80/80 · MAPA 59/60 · REJEITADOS 19/40 |

---

## Decisões herdadas (não reabrir)

| # | Decisão | Registro |
|---|---|---|
| **Q2** | Grade 5×5, **N=5 armadilhas ativas**, colocação livre nas 25 células | GDD, decisão 1 |
| **Q1** | Apagar o legado de moedas na P1, preservando `src/shared/sim/`; tag `legacy-coins` + stub + `rojo build` no CI | `.context/REJEITADOS.md` (executado na S1) |
| **Dados** | Store `MuralhaProfile_v1`; schema v2 com `contentVersion` e migração 0→2/1→2; whitelist/anti-PII em todo load | `src/shared/data/ProfileSchema.luau` |
| **Analytics** | Taxonomia v1 congelada (`schema_version = 1`); 31 eventos; sem PII | `docs/taxonomia-analytics.md` |
| **ProfileStore** | Vendorizado (Apache-2.0), server-only, **não editar** | `vendor/ProfileStore.luau` |
| **Monetização** | Base 2% × US$ 2; topo 4,5% × US$ 5; gate ARPDAU líquido US$ 0,005 | `docs/decisao-monetizacao.md` |
| **Motor** | Servidor autoritativo + replay por seed + `simVersion`; hash só muda com versão nova | `docs/spec-motor-deterministico.md` |

---

## P1 — fatias e próximo passo

| # | Fatia | Critério de pronto | Status |
|---|---|---|---|
| S1 | Q1 — apagar o legado | tag antes; `check.sh`/CI verdes; produção intacta; docs atualizados | **feito 09/11/2026** |
| S2 | Motor 5×5/N=5 | `simVersion 2` + hash novo + invariants/acceptance re-ancorados | **feito 09/11/2026** |
| S3 | Muralha e economia | célula/6ª armadilha/ouro insuficiente recusados; perfil persistido; eventos válidos | **feito 09/11/2026** |
| S3.3 | Gaps antes da S4 | GAP-006/007 fechados; GAP-010 preparado | **feito 10/11/2026** |
| S3.4 | Conteúdo e versões | schema v2/contentVersion, 5º tipo, alias, migração neutra e Modo B | **feito 10/11/2026** |
| S4 | Cena 5×5 + build | build ≤ 30 s; 45+ FPS mobile | **feito 10/11/2026 (FPS 60/60 · Play→UI 1,9 s)** |
| S5 | Drop-in de 5 s | cena DEFENDER + derrota roteirizada; `dropin_pressed` ≥ 60% | **feito 10/11/2026 (feature; taxa no teste)** |
| S6 | Raid + replay 8 s | `result_hash` igual ao servidor; recompensa idempotente por `battle_id` | **feito 10/11/2026 (S6.1: fantasma real + replay 3D)** |
| S7 | Telemetria | contrato v1 valida 100%; nenhum evento altera `BattleResult` | **feito 10/11/2026 (30/30; sink Null; GAP-012)** |

Saída da P1 (GDD §10): **70% de primeira vitória em menos de 60 s**, medido com
`first_win_seconds` da S7.

**Próximo passo:** **GAP-012** — sink persistente/export para medir a saída da P1 no teste de 3
semanas. S7/S6.1/S5 fechadas; P2 não começa sem autorização.

## Pipeline de expansão e gaps

- Processo reproduzível: [`docs/pipeline-expansao.md`](docs/pipeline-expansao.md) — três versões
  (`schemaVersion`, `CONTENT_VERSION`, `simVersion`), matriz de decisão, passo a passo, RFC e migração.
- Registro: [`docs/gaps.md`](docs/gaps.md) — GAP-004/005/008/011, cada um com gatilho objetivo.
- Gate de versões: [`docs/versoes.md`](docs/versoes.md) + `scripts/check-versions.py` no `check.sh`.
- Fechamento: toda P/S termina com uma linha `GAP:`; sem linha, a fatia não fecha.
- Trial 09/11/2026: classe/trait/raridade na branch `7d53327` (apagada); relatório em
  `docs/expansion-test-2026-11-10.md`; patch/kit em `tools/expansion-test/`.

---

## Handover — S7 fechada + saída da P1 (próxima)

**Estado:** S3.4 **fechada** (schema 2, content 2, sim 3, Modo B real 8/8); **S4 fechada** (QA
runtime); **S5 fechada** (drop-in/funil/+3 ouro); **S6.1 fechada** (raid/fantasma real/replay 3D);
**S7 fechada** (telemetria/contrato 30/30/`first_win_seconds`). GAP-001/002/003/009/010/011
fechados; GAP-004/005/008/012 abertos. **Base:** `main` pós-S7; hash `2489780106`; RFC em
[`docs/rfc-s3.4-conteudo.md`](docs/rfc-s3.4-conteudo.md).

- **Modo B fechado:** [`docs/teste-sessao-studio.md`](docs/teste-sessao-studio.md) §9 registra
  `modo=DataStore`, `datastore=Access`, `schema=v2 content=v2`, `sessions 11→12` e `PASSOU (8/8)`.
  Não repetir sem mudar schema; perfil futuro (`schema_future`/`content_future`) continua recusado.
- **S4 fechada:** `GridLayout`/`BuildProtocol` + `BuildClientState`/`BuildHud`/`BuildLayout` +
  `sim/build-contract.luau` **14/14**; `BuildGrid` cria 25 células/muralha; `WallController` expõe
  snapshot/place/remove/upgrade; `BuildClient` tem câmera fixa, UI 5×5, HUD e layout responsivo.
  Runtime: FPS 60/60, Play→UI 1,9 s, prints com painel e `trap_limit`/`max_level`; §7 preenchida.
- **S5 fechada:** `DropInState`/`DropInTelemetry` + `sim/dropin-contract.luau` **8/8**;
  `DropInController.server` remotes/estado/batalha fixa/retry; `DropInClient` cena local + DEFENDER;
  `BuildClient` espera `DropInDone`; +3 ouro no clear. Runtime validado; o envelope de analytics
  entrou na S7.
- **S6.1 fechada:** `PhantomStore` (`MuralhaPhantom_v1`) + `BattleLog.wall` + replay 3D
  (`ViewportFrame`, 8 s) + `MuralhaGold`; contrato de raid **6/6**; QA em 375×812 com
  `REPLAY CONCLUIDO`/`FECHAR`. Limites: fantasma é a última muralha publicada; replay local sem
  câmera cinematográfica; reward 5 provisório.
- **S7 fechada:** `AnalyticsService` puro + `AnalyticsBoot`; contrato **30/30**. `session_start`
  usa `days_since_last_seen` capturado no `onStart` do `ProfileBoot`; `player_id` é hash32 com salt
  (sem PII). Drop-in/raid passam o funil, batalha, ouro e `first_win` pelo serviço. O sink é `Null`
  (lote 30 s/100, rate limit 10/min, idempotência); `first_win_seconds` deriva de
  `first_win.ts − session_start.ts` e o relatório usa jogadores novos. **GAP-012:** sem persistência,
  a taxa de 70% não vira série; QA em [`docs/teste-s7-studio.md`](docs/teste-s7-studio.md).
- **Fonte da parede:** use só `WallService.toBattleWall(profile, ProfileSchema, TrapCatalog, hp)` para
  qualquer batalha; nunca monte `wall.traps` à mão. Perfil inválido devolve `nil + erro` e não entra no
  `Battle.new`; o boot já rodou `TrapCatalog.ensureProfileContent`.
- **Versões:** S4 não deve mudar `simVersion`/hash; se mudar, siga `docs/pipeline-expansao.md`,
  atualize `docs/versoes.md` e re-ancore acceptance. `contentVersion` novo é schema v3 + RFC.
- **Critério de pronto (p1-plano S4):** build ≤30 s; nenhuma armadilha fora da célula; 45+ FPS
  mobile; UI ligada ao `WallService`. **Atendido:** 60/60 FPS focado, Play→UI 1,9 s, 5 armadilhas
  em células distintas e 6ª recusada; evidência na §7.
- **Próxima janela:** fechar **GAP-012** (sink persistente/export) e medir a saída da P1 no teste
  de 3 semanas (70% de primeira vitória <60 s). **Fora:** P2, GAP-004/008 (classe/taxonomia v2) e
  GAP-005 (P2). **Não iniciar P2.** O trial/teste de 3 semanas segue em paralelo; a taxa ≥60% da S5
  é medida nele.
- **Saída:** `doctor.sh` + `check.sh` RC=0; docs atualizados; CI verde; uma linha `GAP:` no handoff.

---

## Teste de produto de 3 semanas

A revisão de direção recomendou o teste **antes** da P1; o diretor decidiu seguir com a P1 em
09/11/2026. O teste continua recomendado e **roda em paralelo**; se reprovar, a P1 para e o escopo é
revisto. Motor e camada de dados continuam válidos para qualquer versão.

---

## WSL e rede (resolvido)

- Repo: **https://github.com/eudespatricio/jogo-roblox** (branch `main`).
- No WSL: `source scripts/env.sh`; `bash scripts/doctor.sh`; `bash scripts/check.sh`.
- Rojo no WSL escuta `127.0.0.1:34872`; o Windows alcança `localhost:34872` pelo encaminhamento de
  localhost. **Não use `--address 0.0.0.0`** (quebra o encaminhamento); firewall não é necessário.
- `.tools/` é binário Windows e não é versionado; no WSL as ferramentas vêm do `rokit install`.
- Se a pasta no WSL estiver vazia, o repo ainda não foi clonado — clone antes de ler o resto.

---

## Ferramentas

- **Existe:** Studio + plugin Rojo; Rokit (Rojo/StyLua/Selene/Luau); Blender 4.5.15 LTS e 4.2 com
  Cycles CUDA (RTX 3060); WSLg; Python 3.14.
- **CLI extras:** git-lfs 3.8.1, luau-lsp 1.70.1, Lune 0.11.1, Pesde 0.7.4, rbxcloud 0.17.0,
  oxipng, ffmpeg 7.0.2, Krita/Inkscape/Audacity/ImageMagick/pngquant/optipng/OBS.
- **Gate:** `scripts/check.sh` (build, StyLua, luau-lsp, versões docs x fonte, invariantes,
  acceptance, contratos, migração neutra, sourcemap, tetos do contexto). CI em
  `.github/workflows/ci.yml`.
- **Atenção:** shell não-login não acha `rojo`/`blender`/`git-lfs` — use `source scripts/env.sh`.
  Selene 0.32 não entende `+=`; o lint do CI é `luau-lsp`. ProfileStore é server-only.

---

## Regras invioláveis

1. **P1 autorizada em 09/11/2026; P2+ só com autorização explícita do diretor.**
2. **`src/` é produção.** O legado de moedas está na tag anotada `legacy-coins` (`b07b4c5`); não
   ressuscite `CoinService`/`DataService`/`Config`.
3. Depois de editar `src/shared/sim/core.luau`, rode `sim/invariants.luau` e `sim/acceptance.luau`.
4. Mudou a matemática → subir `simVersion`, registrar na spec e em `docs/versoes.md` (`simVersion` atual = **3**).
5. `bit32` só recebe `[0, 2^32)`: usar `add32`/`mul32`.
6. Contexto residente tem teto (80/60/40); `scan_repo.py --check` falha se estourar.
7. Invariante não vira markdown: vira teste ou vira pergunta.
8. Não reabrir `REJEITADOS.md` sem a condição objetiva listada.
9. Custo/desbloqueio: fonte em `src/shared/data/TrapCatalog.luau`; mudança exige docs + contrato.
10. Expansão segue `docs/pipeline-expansao.md`; toda P/S fecha com `GAP:` e atualiza `docs/gaps.md`.

---

## Três avisos que a próxima janela não pode perder

1. **Tag antes da deleção.** A `legacy-coins` é anotada e aponta para `b07b4c5` — o último commit com
   o protótipo. Se algum dia recriar a tag, faça no HEAD **antes** de apagar qualquer arquivo.
2. **A S2 mudou a matemática de propósito.** O hash `668061367` **não é mais o alvo**; o novo é
   `2489780106`, agora com `simVersion 3` (o hash da parede padrão não mudou na S3.4). Não "ajustar"
   o hash antigo nem os thresholds sem registro. Mudou `schemaVersion`/`CONTENT_VERSION`/`SIM_VERSION`?
   Atualize `docs/versoes.md`; o `check.sh` falha se fonte e docs divergirem.
3. **Contexto tem teto.** ESTADO está em 79/80, MAPA em 59/60, REJEITADOS em 19/40. Enxugue uma
   linha antes de acrescentar outra.

---

## Achados que não podem se perder

1. **`bit32.band` com double > 2^32 retorna lixo** (`band(7,2e16) = 1473511424`), não módulo.
2. **Aftman está arquivado** (último push 2025-07-09); Rokit é o sucessor ativo.
3. **ProfileStore** cobre crash de servidor, `Mock` e roubo de sessão — não escrever o nosso.
4. **A Video Captures API só grava para frente** (30s); o pedido do jogador é o passado — nosso
   replay por seed é a vantagem competitiva.
5. **O `mul32` antigo não errava resultado neste build**; era violação de faixa (risco de
   portabilidade). Corrigido como endurecimento, não como bugfix.
6. **O invariante I6 falhou primeiro porque o teste estava errado** (muralha morria antes do cap),
   não o código. Consertamos o teste.
7. **O README descrevia o jogo de moedas** — doc mais velho que código mente; a radiografia pegou.
8. **`#` em tabela de chave string não conta itens.** O teto de `cells`/`cosmetics` da migração
   nunca disparava; quem pegou foi o `luau-lsp`.
9. **`EndSession` só solta o lock depois do save.** Reabrir sessão no mesmo servidor logo depois
   exige espera/retry; senão `StartSessionAsync` lança "already loaded in this session".
10. **`ProfileStore.Mock` não persiste entre servidores.** Persistência real precisa de lugar
    publicado + API Services (Modo B do roteiro).
11. **O motor da P0 era o recorte do PoC** (1 armadilha por lane, tipo sorteado). A S2 trocou por
    loadout por célula (5×5/N=5); o hash antigo e os números da P0 são histórico.
12. **A tag `legacy-coins` pré-existente era leve e apontava para `1f241b0`.** Foi refeita como
    anotada no HEAD `b07b4c5` e publicada antes da deleção; o commit antigo continua no histórico.
13. **Remover armadilha não devolve ouro.** A taxonomia v1 não tem source de refund;
    `gold_earned` só aceita raid/defense/daily. Reembolso exigiria taxonomia v2.
14. **Economia hardcoded não era reproduzível.** A S3.1 extraiu `TrapCatalog`, pinou listas/custos
    e fez perfil inválido falhar fechado; o processo está em `docs/pipeline-expansao.md`.
15. **O trial classe/trait/raridade funcionou, mas expôs 4 gaps:** docs drift (GAP-007),
    analytics sem variantes (GAP-008), ProfileStore real (GAP-009) e default neutro (GAP-010).
16. **`toBattleWall` é a única ponte perfil→motor.** Valida, ordena por (linha, coluna) e devolve
    `nil + erro`; S4/S6 não montam `wall.traps` à mão.
17. **O gate de versões fecha o buraco do trial.** `scripts/check-versions.py` compara 4 valores com
    `docs/versoes.md`; labels do `check.sh` saem da fonte; divergência simulada falhou o gate.
18. **GAP-010 fechou no primeiro schema v2.** `sim/content-contract.luau` e
    `neutral-migration.luau` comparam o hash da parede antiga (`oil`) com a migrada (`tar`) e rodam
    no `check.sh`.
19. **`contentVersion` separa schema de conteúdo.** Schema 2 adiciona a versão de conteúdo, não
    classe; `oil → tar` e `catapult` são conteúdo. Classe/trait/raridade exigem schema v3 +
    taxonomia v2 (GAP-004/008).
20. **O gate do `WallService` é por igualdade de `contentVersion`.** O boot repara e salva; o
    serviço recusa perfil não migrado (`content_version`) ou futuro (`content_future`).
21. **GAP-009 fechou com ProfileStore real.** Modo B em 10/11/2026: `datastore=Access`,
    `schema=v2 content=v2`, sessions 11→12, selftest 8/8; `STORE_NAME=MuralhaProfile_v1` com schema
    v2. O `ContentId` do asset legado é ruído histórico.
22. **`CellSize` em escala distorce o grid.** O scaffold da S4 usava `UDim2.fromScale` no
    `UIGridLayout`; em 375×812 as células viravam retângulos e o grid invadia o painel. O layout
    agora calcula pixels puros e é provado em 375×812/720×1280 (`BuildLayout`).
23. **HUD de debug transforma "feel" em número.** `UI x.xs` é o Play até a UI interativa e `FPS n`
    é a janela de 0,5 s; sem isso o critério de 30 s/45 FPS do QA vira achismo. O HUD não substitui
    o Studio: só mede.
24. **`os.clock()` mede CPU time no Roblox.** O primeiro HUD usava `os.clock` para FPS/T/UI e o
    print de 375×812 mostrou `FPS 15`/`UI 1.6s` distorcidos; o HUD agora soma `time()` (tempo antes
    do primeiro frame) + `dt` de parede do `RenderStepped`, e o contrato prova 60/30 FPS. `UI`/`T`
    são desde o início do cliente; para Play→UI exato, use os timestamps do Output.
25. **Perfil novo não tem ouro para o QA.** O template nasce `gold=0` e não há fonte antes da S6;
    o grant de Studio (`QaStarterGold`/`QaLeaguePoints`) liberou o §5 sem mudar produção.
26. **FPS 15/21 era print sem foco.** Com o viewport focado, 375×812 e 720×1280 deram 60/60; o
    número baixo era throttle do Studio ao abrir a ferramenta de captura, não performance do jogo.
27. **S5 usa batalha real e visual local.** O servidor roda `Core` com seed 4/muralha com catapulta
    no press; a cena (horda/blocos) é local no cliente para não replicar 10 partes. O funil sai como
    `[analytics] ...` validado pela taxonomia v1 até o sink/envelope da S7.

---

## Goal da próxima janela — fechar GAP-012 e medir a saída da P1

**Objective:** fechar o GAP-012 (sink persistente/export da telemetria) e medir a saída da P1 —
**70% de primeira vitória em <60 s** — no teste de 3 semanas, sem mudar schema/content/sim nem a
taxonomia v1. S7 fechada; P2 bloqueada.

**Status:** S7 fechada em 10/11/2026; GAP-012 **aberto** (sink Null não persiste a série).

**Prompt para disparar:**

> Você está no repositório `jogo-roblox` (MURALHA — P1; S1–S7 fechadas; P2 bloqueada; GAP-012
> aberto). Leia `AGENTS.md`, `.context/ESTADO.md`, `.context/MAPA.md`, `CONTINUAR.md`,
> `docs/p1-plano.md`, `docs/teste-s7-studio.md`, `docs/versoes.md` e `docs/gaps.md`. No WSL:
> `source scripts/env.sh`, `bash scripts/doctor.sh` e `bash scripts/check.sh` (devem passar). Não
> edite `vendor/ProfileStore.luau`; Q2 = 5×5, N=5, colocação livre; taxonomia v1 congelada.
>
> **Objetivo:** fechar o GAP-012 com sink persistente/export do `AnalyticsService` (sem mudar
> schema/content/sim/taxonomia) e medir a saída da P1 (70% de primeira vitória <60 s) no teste de
> 3 semanas; registrar a série e o veredito no handoff.
>
> **Fora:** P2, classe/taxonomia v2, mudança de schema/content/sim. Se precisar mudar versão, pare
> e registre em `docs/gaps.md`; não invente produto. **Não iniciar P2.**
>
> **Saída:** `doctor.sh` + `check.sh` RC=0; CI verde; GAP-012 fechado com teste; docs e linha `GAP:`
> atualizados.

**Checkpoint:** S7 fechada com contrato 30/30 e `first_win_seconds`; a próxima janela começa no
GAP-012 e na medição da saída da P1.
