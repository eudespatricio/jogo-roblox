# QA da S4 no Studio — cena 5×5 + build

> **Status:** roteiro pronto; **S4 ainda não validada em runtime**. A cena/UI/remotes são scaffold
> (`GridLayout`, `BuildProtocol`, `BuildGrid`, `WallController`, `BuildClient`). Este documento é o
> contrato de QA humano; o agente não consegue medir FPS/feel sem Studio.

**Base:** `main` >= `44f4cf8` · schema 2 · content 2 · `simVersion 3` · hash `2489780106`.
Critérios do plano: [`p1-plano.md`](p1-plano.md) S4 — build ≤30 s; nenhuma armadilha fora da célula;
45+ FPS mobile; UI ligada ao `WallService`.

---

## 1. Pré-condições

1. No WSL: `source scripts/env.sh && bash scripts/doctor.sh && bash scripts/check.sh` (RC=0).
2. `rojo build default.project.json -o build/place.rbxl` (ou `rojo serve` + plugin).
3. Abrir o lugar no Studio e dar Play. Para QA local, `ProfileStoreMock = true` (default do Studio)
   evita depender de DataStore; o schema v2 já foi provado no Modo B em 10/11/2026.
4. Se for testar o fluxo real de perfil, `ServerStorage.ProfileSelfTest = true` é opcional e só roda
   em Studio.

## 2. Logs esperados no servidor

```text
[build] cena 5x5 pronta
[build] remotes prontos em ReplicatedStorage.MuralhaRemotes
[perfil] store=MuralhaProfile_v1 modo=Mock
[perfil] carregado key=User_... schema=v2 content=v2 migrado=false
```

O cliente deve carregar `MuralhaRemotes/BuildSnapshot` e `BuildAction` sem erro no Output.

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
- [ ] Grid 5×5 clicável, legível em 375×812 e 720×1280 (device emulation do Studio).
- [ ] Texto não sobrepõe o painel inferior nem corta em telas estreitas.

## 5. Ações (servidor autoritativo)

Com um perfil novo (ou gold suficiente):

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

- [ ] `rojo build` completo em **≤30 s** (medir no WSL).
- [ ] Play até UI interativa em **≤30 s** (medir com o HUD de debug ou cronômetro).
- [ ] **45+ FPS** em device emulation mobile (Studio → Device/Stats), com 5 armadilhas e UI aberta.
- [ ] Sem erro recorrente no Output; o `ContentId` do asset legado é ruído histórico conhecido.

## 7. Evidência para fechar a S4

Cole no handoff/`CONTINUAR.md`:

1. linhas `[build]`/`[perfil]`/`[selftest]` do Output;
2. print da cena + UI em 375×812 e 720×1280;
3. FPS medido e tempo de `rojo build`/Play;
4. lista de bugs encontrados (com célula/ação) e se foram corrigidos;
5. veredito: **S4 fechada** ou **S4 em correção**.

Sem os itens 1–3, a S4 **não fecha**; o scaffold não substitui o QA.

## 8. Correções que o agente pode fazer sem Studio

- layout responsivo da UI (sem sobreposição);
- HUD de FPS/tempo de build no cliente;
- testes headless de protocolo/estado do build em `sim/build-contract.luau`;
- logs de diagnóstico e tratamento de erro nos remotes;
- docs/handoff/CI.

Tudo que depender de “como parece/feel” fica para o QA humano.
