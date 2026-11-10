# QA da S6 no Studio — raid + BattleLog + replay

> **Status:** **S6.1 implementada; QA visual inicial feito em 10/11/2026 11:15–11:20.** O
> `ViewportFrame` 3D renderizou, o hash local bateu com o servidor (sem `DIVERGENCIA`), o fantasma
> passou de `traps=0` para `traps=1` após o archer e o OURO subiu. O QA achou o enquadramento
> pequeno e os detalhes cortados; câmera/UI foram ajustadas — **re-testar** antes de fechar a S6.
> S5 fechada; S7/P2 não começaram.

**Base:** `main` pós-S6.1 · schema 2 · content 2 · `simVersion 3` · hash `2489780106`.
Critérios do plano: [`p1-plano.md`](p1-plano.md) S6 — `battle_finished.result_hash` igual ao
replay; recompensa idempotente por `battle_id`; divergência vira `battle_divergence`; GAP-011
(`contentVersion` no `BattleLog`).

---

## 1. Pré-condições

1. No WSL: `source scripts/env.sh && bash scripts/doctor.sh && bash scripts/check.sh` (RC=0).
2. `rojo build default.project.json -o build/place.rbxl` e abrir o lugar no Studio.
3. `ServerStorage.ProfileStoreMock = true` (default do Studio). BattleLog e fantasma têm stores
   próprios: `ServerStorage.BattleLogMock` e `ServerStorage.PhantomStoreMock` (default Studio =
   Mock; `false` tenta DataStore real).
4. Para ter ouro/armadilhas no build, o grant da S4 (`QaStarterGold`/`QaLeaguePoints`) é opcional;
   a raid funciona com o perfil zerado (a recompensa é creditada no fim).
5. `ProfileSelfTest = false`.

## 2. Logs esperados

```text
[raid] battlelog store=Mock name=MuralhaBattleLog_v1
[raid] phantom store=Mock name=MuralhaPhantom_v1
[raid] servidor pronto store=Mock reward=5 sim=3
[raid] phantom owner=Eudesspatricio traps=1 hp=500 content=v2 store=Mock
[analytics] battle_started battle_id=... grid_width=5 seed=... sim_version=3 traps_count=5
[analytics] battle_finished battle_id=... duration_ms=... result_hash=... winner=...
[analytics] raid_end battle_id=... duration_s=... result=...
[analytics] gold_earned amount=5 source=raid battle_id=...
[raid] battlelog battle_id=... content=v2 reward=5 hash=...
[raid] creditou 5 ouro gold=8
```

`battle_finished` sai **depois** do hash; `battle_divergence` só aparece se o replay não bater.
O `BattleLog` fica em `MuralhaBattleLog_v1` e a muralha real em `MuralhaPhantom_v1`, separados do
perfil.

## 3. Raid no cliente

- [ ] Botão **ATACAR** aparece no canto superior esquerdo, abaixo do HUD, depois do drop-in/build.
- [ ] Ao clicar, modal **RAID** abre com `ATACANDO...`, depois `VITORIA`/`DERROTA`, `battle_id`,
      `hash`, **fantasma**, muralha/vazados, recompensa e um **ViewportFrame 3D**.
- [ ] O replay 3D mostra lanes, traps da muralha fantasma, blocos da horda e a muralha perdendo HP
      por **8 s**; termina em `REPLAY CONCLUIDO · 8s`.
- [ ] O hash do replay local bate com o `resultHash` do servidor; se não bater, mostra
      `DIVERGENCIA` e não finge sucesso.
- [ ] `FECHAR` volta ao build; o botão ATACAR reaparece.
- [ ] Layout sem sobreposição em **375×812** e **720×1280**; o botão não cobre o grid.

## 4. Servidor autoritativo e recompensa

- [ ] A raid usa um snapshot real de muralha (`MuralhaPhantom_v1`, via `toBattleWall`) e
      `Core.Battle` com seed/wave registrados. O `BattleLog` guarda `wall` (hp + traps) para replay.
- [ ] O servidor roda o mesmo seed/muralha/wave e compara o hash; o cliente roda o mesmo
      `Core.Battle`, compara de novo e só então exibe o 3D.
- [ ] Se o atacante vence, `gold_earned amount=5 source=raid` e o ouro do perfil sobe **uma vez**
      por `battle_id`; se perde, recompensa 0.
- [ ] O topo do build atualiza o OURO após a raid (atributo `MuralhaGold` → snapshot). Ex.: 3 +
      5 = **OURO 8**; antes da correção o topo ficava em 3.
- [ ] Repetir ATACAR cria outro `battle_id`/log (não reaproveita chave).
- [ ] `BattleLog` tem `contentVersion = 2` (GAP-011) e os campos do resultado; o store é
      `MuralhaBattleLog_v1`, não o `MuralhaProfile_v1`.

## 5. Idempotência e divergência

- [ ] O contrato headless prova: `claim` duas vezes no mesmo `battle_id` cria uma chave só e
      `markRewarded` não duplica o ouro (`sim/raid-contract.luau`).
- [ ] `BattleLog.isReplayable` recusa `contentVersion` futuro (`content_future`).
- [ ] Divergência: o contrato corrompe o hash e `RaidReplay.verify` devolve `divergence`; no
      servidor isso vira `[analytics] battle_divergence` e **não** credita. Não é fácil forçar no
      Studio; a prova headless fica na §7.
- [ ] O cliente nunca decide recompensa; ele recalcula o hash localmente e apenas exibe o
      resultado do servidor. Divergência local vira `DIVERGENCIA` na tela.

## 6. Performance / limites do scaffold

- [ ] FPS ≥45 no build/raid com o `ViewportFrame` 3D ativo (medir no Studio focado).
- [ ] Sem erro recorrente no Output; `ContentId` e `ProfileStore API services unavailable` em Mock
      são ruído conhecido.
- [ ] `rojo build` ≤30 s; sem mudança de `simVersion`/hash/schema/content.
- [ ] **Scaffold:** o fantasma é a **última muralha publicada** (uma por servidor no store `latest`);
      em produção multi-jogador isso evolui para seleção por liga. A recompensa de raid é **5 ouro
      provisório** para o teste de idempotência; não é economia final.

## 7. Evidência para fechar a S6

1. linhas `[raid]` + `[analytics] battle_started/battle_finished/raid_end/gold_earned` do Output;
2. print do modal com `VITORIA`/`DERROTA`, hash e **replay 3D** em **375×812** e **720×1280**;
3. print/Output do `BattleLog` com `contentVersion=2` e `battle_id` único;
4. FPS medido e tempo do `rojo build`/Play;
5. veredito: **S6 fechada** ou **S6 em correção**.

Sem os itens **1–3**, a S6 não fecha. Contrato headless + CI não substituem o Studio.

## 8. Fora do scaffold (não inventar)

- S7 (AnalyticsService/envelope) e P2/live ops não começam aqui.
- O fantasma é a última muralha publicada; seleção por liga/amigo e replay com câmera cinematográfica
  ficam para a janela de cena/replay.
- A recompensa de raid é provisória (5); o valor final é decisão de economia do teste de 3 semanas.

## 9. QA headless executado (10/11/2026)

```bash
source scripts/env.sh
bash scripts/doctor.sh        # RC=0
bash scripts/check.sh         # RC=0; contrato de raid 6/6
luau sim/raid-contract.luau   # 6 checagens, 0 falhas
rojo build default.project.json -o build/place.rbxl
```

- BattleLog com `contentVersion` + chave única + `isReplayable`.
- Replay determinístico: mesmo seed/hash; hash corrompido vira `divergence`.
- Ledger: claim/markRewarded idempotentes; `gold_earned` da taxonomia validado.
- **Falta (humano):** QA do replay 3D com fantasma real (ViewportFrame, lanes/horda/HP) e
  prints 375×812/720×1280; o topo OURO 8 e `content=v2` já foram confirmados.

## 10. Evidência parcial — 10/11/2026

- **S6.0 (pré-3D) — 375×812:** raid DERROTA (hash 965886648, muralha 178 HP, vazados 27,
  reward 0) e VITORIA (hash 1193837270, muralha 0 HP, vazados 31, reward 5); barra de 8 s
  (pré-3D).
- **720×1280:** modal RAID VITORIA com battle_id/hash/reward; build 5×5 atrás.
- **Output:** `[raid] battlelog store=Mock name=MuralhaBattleLog_v1`; `battle_started`;
  `battle_finished` com hash/winner/wall_hp/ticks; `raid_end`; `gold_earned amount=5 source=raid`
  nas vitórias. Derrotas não creditam. Battle_ids distintos por raid.
- **Bug encontrado/corrigido:** o topo do build continuava `OURO 3` após o reward 5; o servidor
  agora publica `MuralhaGold` e o `BuildClient` reabre o snapshot. Re-testar para ver `OURO 8`.
- **Bug encontrado/corrigido:** faltava logar o `BattleLog`; agora sai
  `[raid] battlelog battle_id=... content=v2 reward=5 hash=...`; `[raid] creditou 5 ouro
  gold=8`; topo do build **OURO 8**.
- **Confirmado no re-teste (10/11/2026):** `[raid] battlelog ... content=v2 reward=5` e
  `[raid] creditou 5 ouro gold=8/13/...`; o topo passou a **OURO 13** e o jogador colocou um
  **archer L2 + upgrade** (o loop de ouro da raid funciona). Derrotas continuam sem crédito.
- **S6.1 implementada em 10/11/2026:** `MuralhaPhantom_v1` (snapshot real via `toBattleWall`),
  `BattleLog.wall`, replay 3D em `ViewportFrame` e comparação de hash no cliente. Falta o QA
  humano do 3D/fantasma; S6 continua **aberta**.

### S6.1 — replay 3D + fantasma real (implementação, 10/11/2026)

- `PhantomStore` separado (`MuralhaPhantom_v1`; `PhantomStoreMock` no Studio) guarda a última
  muralha publicada; `RaidController` escolhe essa snapshot e roda `toBattleWall`.
- `BattleLog` ganhou `wall` (hp + traps) para o replay; o servidor devolve `wall`, `seed`,
  `simVersion`, `phantomName` e `replaySeconds=8` no retorno.
- `RaidClient` roda o mesmo `Core.Battle` no cliente, compara o hash e anima um `ViewportFrame` 3D
  (lanes, traps, horda, HP) por 8 s. Se o hash local divergir, mostra `DIVERGENCIA`.
- Ainda falta o QA visual em 375×812/720×1280; o `rojo build` e os contratos já passam.

### Correção do OURO stale (10/11/2026)

O raid creditava o ouro no perfil (`gold_earned` no Output), mas o topo do build continuava em
`OURO 3`: o `BuildClient` não reabria o snapshot. Agora o servidor publica `MuralhaGold` e o cliente
refaz `BuildSnapshot`; o log `[raid] creditou 5 ouro gold=8` prova o valor. Confirmado com
**OURO 13** e archer L2 após o gasto.

### Leitura do gold no teste

O salto `gold=8 → 13 → ...` é o reward de 5 por vitória; quando o jogador gasta 40 (archer) + 5
(upgrade), o topo cai para **OURO 13** e o archer L2 aparece. Em Mock o perfil não persiste entre
sessões (`ProfileStore API services unavailable`); persistência real é o Modo B/DataStore, não o
teste local. O reward 5 continua provisório.

### QA visual inicial — 10/11/2026 11:15–11:20

- O replay 3D renderizou no `ViewportFrame`; o cliente rodou o mesmo `Core.Battle` e **não** mostrou
  `DIVERGENCIA` (hash local = hash do servidor).
- `[raid] phantom owner=Eudesspatricio traps=0 ...` nas primeiras raids e `traps=1` depois do
  archer: o fantasma real está lendo a última muralha publicada.
- `VITORIA`/`REPLAY CONCLUIDO · 8s`, OURO 8 → 33 → 13 após o gasto; `creditou 5 ouro` e
  `BattleLog content=v2` confirmados.
- **Achado/correção:** o board 3D aparecia muito pequeno e a linha de reward era cortada. A câmera
  foi para a frente (`(20,30,50)` olhando `(20,2,0)`), o FOV para 55, traps/horda/gate ficaram
  maiores e o modal/detalhes cresceram. **Re-testar** 375×812/720×1280.

### Re-teste de enquadramento — 10/11/2026 11:26

- O board 3D já aparece com lanes/traps/horda no `ViewportFrame`; `HP 0 · vazados · +5 ouro` e o
  `fantasma` agora cabem nos detalhes.
- O fantasma real refletiu `traps=0` (muralha vazia), depois `traps=1` e `traps=2` conforme o
  archer/piche foram colocados; o hash local continuou batendo.
- Ainda falta o print final 375×812/720×1280 **depois** de `REPLAY CONCLUIDO · 8s` (com FECHAR) e
  o veredito. S6.1 aberta.

### Ajuste para tela larga (10/11/2026 11:31)

No desktop a modal ficava muito larga e o `ViewportFrame` virava uma faixa; o board 3D continuava
pequeno. A modal agora tem `UISizeConstraint` (máx. 440×620), o viewport ocupa 38% da altura e a
câmera foi para `(20,22,38)` olhando `(20,1,0)`. Re-testar em 375×812/720×1280 e no desktop; o
`FECHAR` só aparece depois de `REPLAY CONCLUIDO · 8s`.
