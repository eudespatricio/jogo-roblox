# QA da S4 no Studio — cena 5×5 + build

> **Status:** **QA headless + evidência parcial 375×812 (10/11/2026)**; **S4 ainda não validada em runtime**.
> HUD de debug, layout responsivo (375×812 e 720×1280) e contrato de build **14/14** estão no repo;
> falta a evidência de Studio (itens **1–3** da §7). Este documento é o contrato de QA humano; o
> agente não consegue medir FPS/feel sem Studio. Enquanto a §7 não estiver preenchida, a S4
> permanece **aberta** (não é "S4 fechada" por scaffold nem por teste headless).

**Base:** `main` >= `17ed32b` + QA headless de 10/11/2026 · schema 2 · content 2 · `simVersion 3` ·
hash `2489780106`.
Critérios do plano: [`p1-plano.md`](p1-plano.md) S4 — build ≤30 s; nenhuma armadilha fora da célula;
45+ FPS mobile; UI ligada ao `WallService`.

---

## 1. Pré-condições

1. No WSL: `source scripts/env.sh && bash scripts/doctor.sh && bash scripts/check.sh` (RC=0).
2. `rojo build default.project.json -o build/place.rbxl` (ou `rojo serve` + plugin).
3. Abrir o lugar no Studio e dar Play. Para QA local, `ProfileStoreMock = true` (default do Studio)
   evita depender de DataStore; o schema v2 já foi provado no Modo B em 10/11/2026.
4. Para o QA de **ações** (colocar/remover/upgrade e catapulta), defina antes do Play, em
   `ServerStorage`, os atributos numéricos `QaStarterGold = 2000` e `QaLeaguePoints = 400`
   (400 pontos = liga 5). O grant é **só Studio + Mock**, só em perfil zerado, e loga
   `[qa] grant gold=... liga=...`. Sem ele, perfil novo nasce com `gold = 0` e todo `place` volta
   `insufficient_gold`; a catapulta fica `trap_locked` até a liga 5.
5. Se for testar o fluxo real de perfil, `ServerStorage.ProfileSelfTest = true` é opcional e só roda
   em Studio.

## 2. Logs esperados no servidor/cliente

```text
[build] cena 5x5 pronta
[build] remotes prontos em ReplicatedStorage.MuralhaRemotes
[build] cliente pronto em 1.2s
[perfil] store=MuralhaProfile_v1 modo=Mock
[perfil] carregado key=User_... schema=v2 content=v2 migrado=false
[qa] grant gold=2000 liga=5 (Studio/Mock; QaStarterGold/QaLeaguePoints)
```

`[build] cliente pronto em X s` é o mesmo número do HUD (`UI x.xs`): tempo do Play até o primeiro
snapshot/UI interativa. O cliente deve carregar `MuralhaRemotes/BuildSnapshot` e `BuildAction` sem
erro no Output.

## 3. Cena e câmera

- [ ] Grid de **25 células** 5×5 no Workspace, com a muralha no lado c1 (x negativo).
- [ ] Câmera **isométrica fixa**; não orbita, não segue avatar.
- [ ] Nenhum personagem de jogador visível (`Players.CharacterAutoLoads = false`).
- [ ] Nenhuma armadilha visual fora de célula; marcadores somem ao remover.

## 4. UI de build

- [ ] Topo mostra ouro, `content v2` e liga.
- [ ] Painel inferior tem 5 armadilhas (`ARQUEIRO`, `PICHE`, `GELO`, `CANHAO`, `CATAPULTA`) com custo
      ou liga bloqueada.
- [ ] Botões `COLOCAR`, `REMOVER`, `UPGRADE` mudam o modo e ficam visualmente ativos.
- [ ] HUD de debug logo abaixo do topo, sempre visível:
  - [ ] `FPS n` atualiza (antes da primeira janela de 0,5 s mostra `FPS --`);
  - [ ] `T x.xs` é o tempo desde o início do cliente (aprox. Play);
  - [ ] `UI x.xs` congela no primeiro snapshot (`UI --` antes dele); para o Play→UI exato,
        use os timestamps do Output (`[muralha] servidor pronto` → `[build] cliente pronto`);
  - [ ] à direita, `COLOCAR · ARQUEIRO` / `REMOVER` / `UPGRADE` acompanha a seleção.
- [ ] Grid 5×5 **quadrado**, clicável e legível em **375×812** (device emulation do Studio).
- [ ] O mesmo grid/painel continua sem sobreposição em **720×1280**.
- [ ] Texto não sobrepõe o HUD nem o painel inferior e não corta em telas estreitas.
- [ ] Botões de modo e de armadilha têm alvo de toque confortável (≥44 px no layout; conferir no
      device de 375×812).

## 5. Ações (servidor autoritativo)

Com o grant de QA da §1.4 (`QaStarterGold`/`QaLeaguePoints`) ou gold suficiente:

- [ ] Colocar 5 armadilhas em células diferentes; a 6ª é recusada (`trap_limit`).
- [ ] Colocar em célula ocupada é recusado (`cell_occupied`); célula inválida é recusada.
- [ ] `catapult` fica bloqueada abaixo da liga 5; com liga 5, coloca e aparece no grid.
- [ ] Upgrade sobe nível (1→2→3) e debita o custo; no nível 3, recusa (`max_level`).
- [ ] Remover apaga a célula/marcador e **não devolve ouro**.
- [ ] Ouro insuficiente recusa a ação sem criar marcador.
- [ ] A UI atualiza o snapshot (ouro, células, níveis) depois de cada ação.
- [ ] `WallService.toBattleWall` continua sendo a única ponte para batalha; nenhum `wall.traps`
      montado à mão no cliente.

## 6. Performance e build

- [ ] `rojo build` completo em **≤30 s** (medir no WSL; o gate local já roda o build).
- [ ] Play até UI interativa em **≤30 s** — anotar o `UI x.xs` do HUD ou os timestamps do
      Output (`[muralha] servidor pronto` → `[build] cliente pronto`).
- [ ] **45+ FPS** em device emulation mobile (Studio → Device/Stats), com 5 armadilhas e UI aberta;
      anotar o `FPS n` do HUD em 375×812 e 720×1280.
- [ ] Redimensionar o device/janela: grid continua quadrado e sem sobreposição (layout puro
      recalcula por `root.AbsoluteSize`).
- [ ] Sem erro recorrente no Output; o `ContentId` do asset legado é ruído histórico conhecido.

## 7. Evidência para fechar a S4

Colar no handoff/`CONTINUAR.md`:

1. linhas `[build]`/`[perfil]`/`[selftest]`/`[qa]` do Output (inclui `[build] cliente pronto em Xs`);
2. print da cena + UI + HUD em **375×812** e **720×1280**;
3. FPS medido (HUD) e tempo de `rojo build`/Play (HUD `UI x.xs`);
4. lista de bugs encontrados (com célula/ação) e se foram corrigidos;
5. veredito: **S4 fechada** ou **S4 em correção**.

Sem os itens **1–3**, a S4 **não fecha**; o scaffold, o HUD e o contrato headless não substituem o
QA humano.

## 8. Correções que o agente pode fazer sem Studio (feitas em 10/11/2026)

- **HUD de debug** em `BuildClient` (`src/shared/build/BuildHud.luau`): FPS, `T` desde o Play,
  `UI` até o primeiro snapshot e modo/armadilha. Usa o `dt` do `RenderStepped` (tempo de parede);
  `os.clock()` no Roblox mede CPU time e distorcia FPS/T/UI.
- **Grant de QA** em `ProfileBoot` (`QaStarterGold`/`QaLeaguePoints`, só Studio/Mock) para o §5
  rodar com perfil zerado; log `[qa] grant ...` no Output.
- **Layout responsivo** em `src/shared/build/BuildLayout.luau`: grid quadrado por pixels (o
  `CellSize` em escala do scaffold distorcia as células), topo/HUD/grid/painel sem sobreposição em
  375×812 e 720×1280, fallback para landscape/tela pequena.
- **Estado puro do cliente** em `src/shared/build/BuildClientState.luau`: modo, trap selecionada e
  intenção de clique; recusas locais (`cell_occupied`, `empty_cell`, `bad_cell`, ...).
- **Testes headless** em `sim/build-contract.luau`: protocolo, snapshot defensivo, intenção →
  `WallService`, HUD e layout — **14/14**.
- Logs de diagnóstico (`[build] cliente pronto em Xs`), retry de 30 s para o perfil e tratamento de
  erro nos remotes.

Tudo que depender de "como parece/feel" (FPS real, toque, contraste, câmera) fica para o QA humano.

## 9. QA headless executado (10/11/2026)

Comandos e resultado local (WSL):

```bash
source scripts/env.sh
bash scripts/doctor.sh        # RC=0, estação completa
bash scripts/check.sh         # RC=0 (build, StyLua, luau-lsp, versões, invariantes, contratos)
rojo build default.project.json -o build/place.rbxl
luau sim/build-contract.luau  # 14 checagens, 0 falhas
```

- `doctor.sh`: todos os obrigatórios presentes (Studio, plugin Rojo, luau-lsp, git-lfs, GPU).
- `check.sh`: verde; contrato de build passou de **6/6** para **14/14** sem mudar
  `simVersion`/hash/schema/content.
- `rojo build`: RC=0 (bem abaixo de 30 s nesta estação; medir de novo no QA).
- CI: workflow `ci` no push da S4 (README tem o badge).
- O grant de QA é runtime-only (`ProfileBoot`/Studio); o headless cobre protocolo/estado/HUD/layout.

**O que ainda falta (humano):** itens **1–3** da §7 — logs, prints 375×812/720×1280 e FPS/build
medidos. Sem isso a S4 fica em **correção**, e a próxima janela não pode iniciar S5.

## 10. Evidência parcial — 375×812 (10/11/2026)

Print do diretor no Studio (lugar `muralha-s4.rbxl`, `modo=Mock`):

- topo `OURO 0` / `content v2 · liga 1`; HUD `FPS 15 · T 37.9s · UI 1.6s`; grid 5×5 quadrado, sem
  sobreposição com topo/HUD/painel; `CATAPULTA` em `liga 5`; status `Recusado: insufficient_gold`.
- Output: `[build] cena 5x5 pronta`, `[build] remotes prontos...`, `[perfil] carregado ...
  schema=v2 content=v1 migrado=false`, `[perfil] conteudo migrado content=v2`,
  `[perfil] datastore=NoAccess`, `[build] cliente pronto em 1.6s`.
- Leitura: layout/HUD/estado OK; o perfil zerado bloqueou as ações (o grant da §1.4 cobre isso). Os
  números `FPS/T/UI` são da versão antiga do HUD (`os.clock` = CPU time); re-medir com a versão de
  `dt` de parede. **Falta:** 720×1280, FPS com foco e ações com grant. S4 continua **aberta**.

### 720×1280 e 375×812 com grant (10/11/2026)

- Dois prints do diretor (devices `720x1280` e `375x812`): `OURO 1250`, `content v2 · liga 5`,
  `COLOCAR · PICHE`; grid 5×5 com `CATAPULTA L1`, `ARQUEIRO L3`, `CANHAO L1` e dois `PICHE L1`;
  topo/HUD/grid sem sobreposição na parte visível; print corta o painel inferior.
- Grant confirmado (`[qa] grant gold=2000 liga=5` no print anterior): todos os tipos com custo, sem
  “liga” bloqueada. `ARQUEIRO L3` confirma upgrade 1→2→3; dois PICHE confirmam colocação livre.
- Diretor confirmou: a **6ª armadilha foi recusada** (N=5) e **remover não devolveu ouro** — ambos
  **esperados** (Q2; taxonomia v1). `CATAPULTA L1` confirma o desbloqueio na liga 5.
- `UI 0.1s` nesses prints é do build antes do offset de `time()`; no Output do primeiro print,
  `[muralha] servidor pronto 08:55:45.273` → `[build] cliente pronto 08:55:47.197` ≈ **1,9 s**.
- `FPS 15/21`: prints tirados com a janela provavelmente sem foco (throttle); **re-medir com o
  viewport focado** e anotar o número antes de printar. Os prints atuais cortam o painel inferior;
  falta o print inteiro em 720×1280 e 375×812.
- Ainda faltam: `cell_occupied`/célula inválida, `max_level` e ouro insuficiente no build com grant;
  FPS focado; print completo do painel inferior. S4 continua **aberta**.
