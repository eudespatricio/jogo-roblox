# CONTINUAR — handoff de sessão

**Data:** 09/11/2026 · **Status:** P1 em execução — **S1, S2 e S3 fechadas**; próxima fatia é a S4 ·
base `main`. Este arquivo é autossuficiente: a conversa pode ser fechada.

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

## Onde paramos (09/11/2026)

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
  - `src/server/walls/WallService.luau`: colocar/remover/upgrade com validação server-side de
    célula, N=5, ouro e desbloqueio por liga; muta `Profile.Data.wall.cells`/`gold`.
  - catálogo de 4 tipos (espelha o motor v2) em `docs/economia-muralha.md`; upgrade até 3 níveis;
    remover não devolve ouro (taxonomia v1); eventos devolvidos como `{name, props}`.
  - `sim/walls-contract.luau` **11/11**: catálogo, célula, N=5, ouro, desbloqueio, upgrade,
    remove, `creditGold`, snapshot e eventos válidos.
- Gate atual: `bash scripts/check.sh` passa; contexto em **ESTADO 75/80 · MAPA 59/60 ·
  REJEITADOS 19/40**.

---

## Fatos atuais

| Métrica | Valor |
|---|---|
| tick / cap | 0,05 s · 1.200 ticks (60 s) |
| estado | 100% inteiro (`MILLI = 1000`) |
| custo por batalha | ~1,4 ms (~710 batalhas/s) |
| simVersion | **2** |
| determinismo | hash `2489780106` (seed 42, 3 execuções) |
| acceptance P1 | 1.000 seeds × 3 · 1.000 hashes · 68,7% defensor · 1,4 s/1.000 |
| invariantes | **12/12** (`sim/invariants.luau`) |
| contratos | perfil 19/19 · analytics 16/16 · muralha 11/11 (`sim/*-contract.luau`) |
| muralha/economia | catálogo 4 tipos · N=5 · sem refund · `docs/economia-muralha.md` |
| perfil | schema v1 · store `MuralhaProfile_v1` · migração 0→1 com fixture |
| analytics | contrato v1 · 31 eventos · envelope + anti-PII |
| teste de sessão | Modo A (Mock) 8/8 + Modo B (DataStore real) 8/8 · 09/11/2026 |
| contexto | ESTADO 75/80 · MAPA 59/60 · REJEITADOS 19/40 |

---

## Decisões herdadas (não reabrir)

| # | Decisão | Registro |
|---|---|---|
| **Q2** | Grade 5×5, **N=5 armadilhas ativas**, colocação livre nas 25 células | GDD, decisão 1 |
| **Q1** | Apagar o legado de moedas na P1, preservando `src/shared/sim/`; tag `legacy-coins` + stub + `rojo build` no CI | `.context/REJEITADOS.md` (executado na S1) |
| **Dados** | Store `MuralhaProfile_v1`; schema v1 com migração 0→1; whitelist/anti-PII em todo load | `src/shared/data/ProfileSchema.luau` |
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
| S4 | Cena 5×5 + build | build ≤ 30 s; 45+ FPS mobile | **próximo** |
| S5 | Drop-in de 5 s | `dropin_pressed` ≥ 60% | pendente |
| S6 | Raid + replay 8 s | `result_hash` igual ao servidor; recompensa idempotente por `battle_id` | pendente |
| S7 | Telemetria | contrato v1 valida 100%; nenhum evento altera `BattleResult` | pendente |

Saída da P1 (GDD §10): **70% de primeira vitória em menos de 60 s**, medido com
`first_win_seconds` da S7.

**Próximo passo:** S4 — cena 5×5 no Workspace, câmera fixa e UI de build (colocar 5 em 25), com
build ≤ 30 s e 45+ FPS mobile. Depois S5–S7 na ordem do plano.

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
- **Gate:** `scripts/check.sh` (build, StyLua, luau-lsp, invariantes, acceptance, contratos,
  sourcemap, tetos do contexto). CI em `.github/workflows/ci.yml`.
- **Atenção:** shell não-login não acha `rojo`/`blender`/`git-lfs` — use `source scripts/env.sh`.
  Selene 0.32 não entende `+=`; o lint do CI é `luau-lsp`. ProfileStore é server-only.

---

## Regras invioláveis

1. **P1 autorizada em 09/11/2026; P2+ só com autorização explícita do diretor.**
2. **`src/` é produção.** O legado de moedas está na tag anotada `legacy-coins` (`b07b4c5`); não
   ressuscite `CoinService`/`DataService`/`Config`.
3. Depois de editar `src/shared/sim/core.luau`, rode `sim/invariants.luau` e `sim/acceptance.luau`.
4. Mudou a matemática → subir `simVersion` e registrar na spec (`simVersion` atual = **2**).
5. `bit32` só recebe `[0, 2^32)`: usar `add32`/`mul32`.
6. Contexto residente tem teto (80/60/40); `scan_repo.py --check` falha se estourar.
7. Invariante não vira markdown: vira teste ou vira pergunta.
8. Não reabrir `REJEITADOS.md` sem a condição objetiva listada.
9. Custo/desbloqueio da muralha: fonte em `docs/economia-muralha.md`; mudança exige contrato.

---

## Três avisos que a próxima janela não pode perder

1. **Tag antes da deleção.** A `legacy-coins` é anotada e aponta para `b07b4c5` — o último commit com
   o protótipo. Se algum dia recriar a tag, faça no HEAD **antes** de apagar qualquer arquivo.
2. **A S2 mudou a matemática de propósito.** O hash `668061367` **não é mais o alvo**; o novo é
   `2489780106`, com `simVersion 2`. Não "ajustar" o hash antigo nem os thresholds sem registro.
3. **Contexto tem teto.** ESTADO está em 75/80, MAPA em 59/60, REJEITADOS em 19/40. Enxugue uma
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

---

## Como retomar

Cole na nova sessão:

> Você está no repositório `jogo-roblox` (MURALHA — P1 em execução; S1, S2 e S3 fechadas; S4 é a
> próxima). Leia `AGENTS.md`, `.context/ESTADO.md`, `.context/MAPA.md`, `CONTINUAR.md` e
> `docs/p1-plano.md`. No WSL: `source scripts/env.sh`, `bash scripts/doctor.sh` e
> `bash scripts/check.sh` (devem passar). Não edite `vendor/ProfileStore.luau`; Q2 = 5×5, N=5,
> colocação livre; taxonomia v1 congelada. O motor está em `simVersion 2`, hash de referência
> `2489780106` (seed 42) — o `668061367` da v1 está aposentado. A muralha/economia está em
> `src/server/walls/WallService.luau` + `docs/economia-muralha.md` (sem refund). O teste de produto
> de 3 semanas roda em paralelo. Comece pela S4 (cena/build) e mantenha o contexto dentro do teto.
