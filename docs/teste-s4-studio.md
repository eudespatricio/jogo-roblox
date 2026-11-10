# QA da S4 no Studio — cena 5×5 + build

> **Status:** **S4 fechada em 10/11/2026** — QA headless + runtime com logs, prints completos em
> 375×812/720×1280 e **FPS 60/60 com foco**; evidência na §7/§10. O que não foi repetido na UI
> (célula ocupada/inválida e `toBattleWall`) está coberto pelos contratos headless.

**Base:** `main` >= `e0d7b76` + QA de 10/11/2026 · schema 2 · content 2 · `simVersion 3` ·
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

> **S5:** o Play agora abre o drop-in; aperte **DEFENDER** (ou espere a derrota e use **TENTAR DE
> NOVO**) para chegar ao build. O `BuildClient` espera `DropInDone`.


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

- [x] Grid de **25 células** 5×5 no Workspace, com a muralha no lado c1 (x negativo).
- [x] Câmera **isométrica fixa**; não orbita, não segue avatar.
- [x] Nenhum personagem de jogador visível (`Players.CharacterAutoLoads = false`).
- [x] Nenhuma armadilha visual fora de célula; marcadores somem ao remover.

> Prints completos de 375×812 e 720×1280; a muralha aparece no c1 e não há avatar. Os marcadores 3D
> ficam atrás do grid da UI; a remoção foi conferida pelo grid vazio + ouro inalterado.

## 4. UI de build

- [x] Topo mostra ouro, `content v2` e liga.
- [x] Painel inferior tem 5 armadilhas (`ARQUEIRO`, `PICHE`, `GELO`, `CANHAO`, `CATAPULTA`) com custo
      ou liga bloqueada.
- [x] Botões `COLOCAR`, `REMOVER`, `UPGRADE` mudam o modo e ficam visualmente ativos.
- [x] HUD de debug logo abaixo do topo, sempre visível:
  - [x] `FPS n` atualiza (antes da primeira janela de 0,5 s mostra `FPS --`);
  - [x] `T x.xs` é o tempo desde o início do cliente (aprox. Play);
  - [x] `UI x.xs` congela no primeiro snapshot (`UI --` antes dele); para o Play→UI exato,
        use os timestamps do Output (`[muralha] servidor pronto` → `[build] cliente pronto`);
  - [x] à direita, `COLOCAR · ARQUEIRO` / `REMOVER` / `UPGRADE` acompanha a seleção.
- [x] Grid 5×5 **quadrado**, clicável e legível em **375×812** (device emulation do Studio).
- [x] O mesmo grid/painel continua sem sobreposição em **720×1280**.
- [x] Texto não sobrepõe o HUD nem o painel inferior e não corta em telas estreitas.
- [x] Botões de modo e de armadilha têm alvo de toque confortável (≥44 px no layout; conferir no
      device de 375×812).

## 5. Ações (servidor autoritativo)

Com o grant de QA da §1.4 (`QaStarterGold`/`QaLeaguePoints`) ou gold suficiente:

- [x] Colocar 5 armadilhas em células diferentes; a 6ª é recusada (`trap_limit`).
- [x] Colocar em célula ocupada é recusado (`cell_occupied`); célula inválida é recusada.
- [x] `catapult` fica bloqueada abaixo da liga 5; com liga 5, coloca e aparece no grid.
- [x] Upgrade sobe nível (1→2→3) e debita o custo; no nível 3, recusa (`max_level`).
- [x] Remover apaga a célula/marcador e **não devolve ouro**.
- [x] Ouro insuficiente recusa a ação sem criar marcador.
- [x] A UI atualiza o snapshot (ouro, células, níveis) depois de cada ação.
- [x] `WallService.toBattleWall` continua sendo a única ponte para batalha; nenhum `wall.traps`
      montado à mão no cliente.

> Célula ocupada/inválida e `toBattleWall` não foram repetidos na UI: cobertos por
> `sim/build-contract.luau` (14/14) e `sim/walls-contract.luau` (13/13); `place/remove/upgrade`
> foram exercitados na UI.

## 6. Performance e build

- [x] `rojo build` completo em **≤30 s** (medir no WSL; o gate local já roda o build).
- [x] Play até UI interativa em **≤30 s** — anotar o `UI x.xs` do HUD ou os timestamps do
      Output (`[muralha] servidor pronto` → `[build] cliente pronto`).
- [x] **45+ FPS** em device emulation mobile (Studio → Device/Stats), com 5 armadilhas e UI aberta;
      anotar o `FPS n` do HUD em 375×812 e 720×1280.
- [x] Redimensionar o device/janela: grid continua quadrado e sem sobreposição (layout puro
      recalcula por `root.AbsoluteSize`).
- [x] Sem erro recorrente no Output; o `ContentId` do asset legado é ruído histórico conhecido.

> FPS 60/60 focado (diretor); `rojo build` ~0,02 s local; Play→UI **1,9 s** pelos timestamps do
> Output; só o `ContentId` conhecido e avisos de Mock/NoAccess aparecem.

## 7. Evidência para fechar a S4

Colar no handoff/`CONTINUAR.md`:

1. Output (10/11/2026): `[build] cena 5x5 pronta`; `[build] remotes prontos...`;
   `[perfil] store=MuralhaProfile_v1 modo=Mock`; `[perfil] carregado ... schema=v2 content=v1
   migrado=false`; `[perfil] conteudo migrado content=v2`; `[perfil] datastore=NoAccess`;
   `[qa] grant gold=2000 liga=5`; `[build] cliente pronto em 1.6s` (HUD antigo; 1,9 s pelo Output).
2. Prints completos em **375×812** (`Recusado: trap_limit`) e **720×1280**
   (`Recusado: max_level`), com topo/HUD/grid/painel e sem sobreposição.
3. **FPS 60/60 com foco** (diretor, 375×812 e 720×1280); **Play→UI 1,9 s**
   (`08:55:45.273` → `08:55:47.197`); `rojo build` ~0,02 s local (≤30 s).
4. Bugs/correções: perfil zerado sem ouro → grant de QA `QaStarterGold`/`QaLeaguePoints`; HUD
   `os.clock` (CPU) → `time()`+`dt`; `CellSize` em escala/sobreposição → `BuildLayout`; FPS 15/21
   era print sem foco (não era bug). Nenhum bug aberto.
5. Veredito: **S4 fechada** em 10/11/2026.

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
- `rojo build`: RC=0 (~0,02 s local, muito abaixo de 30 s).
- CI: workflow `ci` no push da S4 (README tem o badge).
- O grant de QA é runtime-only (`ProfileBoot`/Studio); o headless cobre protocolo/estado/HUD/layout.

**QA humano concluído (10/11/2026):** itens **1–3** da §7 preenchidos — logs, prints completos
375×812/720×1280, FPS 60/60 focado, Play→UI 1,9 s e `rojo build` abaixo de 30 s. **S4 fechada.**

## 10. Evidência — 375×812 e 720×1280 (10/11/2026)

Print do diretor no Studio (lugar `muralha-s4.rbxl`, `modo=Mock`):

- topo `OURO 0` / `content v2 · liga 1`; HUD `FPS 15 · T 37.9s · UI 1.6s`; grid 5×5 quadrado, sem
  sobreposição com topo/HUD/painel; `CATAPULTA` em `liga 5`; status `Recusado: insufficient_gold`.
- Output: `[build] cena 5x5 pronta`, `[build] remotes prontos...`, `[perfil] carregado ...
  schema=v2 content=v1 migrado=false`, `[perfil] conteudo migrado content=v2`,
  `[perfil] datastore=NoAccess`, `[build] cliente pronto em 1.6s`.
- Leitura: layout/HUD/estado OK; o perfil zerado bloqueou as ações (o grant da §1.4 cobre isso). Os
  números `FPS/T/UI` são da versão antiga do HUD (`os.clock` = CPU time); histórico.

### 720×1280 e 375×812 com grant (10/11/2026)

- Dois prints do diretor (devices `720x1280` e `375x812`): `OURO 1250`, `content v2 · liga 5`;
  no 375, `COLOCAR · PICHE` e `Recusado: trap_limit`; no 720, `UPGRADE` e `Recusado: max_level`;
  grid 5×5 com `CATAPULTA L1`, `ARQUEIRO L3`, `CANHAO L1` e dois `PICHE L1`; topo/HUD/grid/painel
  sem sobreposição, painel inferior e status visíveis nos dois prints.
- Grant confirmado (`[qa] grant gold=2000 liga=5` no print anterior): todos os tipos com custo, sem
  “liga” bloqueada. `ARQUEIRO L3` confirma upgrade 1→2→3; dois PICHE confirmam colocação livre.
- Diretor confirmou: a **6ª armadilha foi recusada** (N=5) e **remover não devolveu ouro** — ambos
  **esperados** (Q2; taxonomia v1). `CATAPULTA L1` confirma o desbloqueio na liga 5.
- `UI 0.1s` nesses prints é do build antes do offset de `time()`; no Output do primeiro print,
  `[muralha] servidor pronto 08:55:45.273` → `[build] cliente pronto 08:55:47.197` ≈ **1,9 s**.
- `FPS 15/21` era throttle de print sem foco; com o viewport focado o diretor mediu **60/60**.
- Fechamento: prints completos com painel; `max_level` (`Recusado: max_level`) e `trap_limit`
  (`Recusado: trap_limit`); `cell_occupied`/célula inválida e `toBattleWall` cobertos pelos
  contratos headless. **S4 fechada** — ver §7.
