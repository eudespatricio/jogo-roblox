# QA da S6 no Studio — raid + BattleLog + replay

> **Status:** **S6 iniciada em 10/11/2026 (scaffold); núcleo validado, replay visual pendente** —
> raid, vitória/derrota, hash, reward 5, barra de 8 s, `BattleLog content=v2` e o loop de ouro
> (archer + upgrade) já vistos em 375×812/720×1280. O `OURO` stale foi corrigido e confirmado
> (`creditou 5 ouro gold=...`). A S6 **não fecha** como feature completa: replay 3D e fantasma de
> outro jogador ficam fora do scaffold. S5 fechada; S7/P2 não começaram.

**Base:** `main` pós-scaffold S6 · schema 2 · content 2 · `simVersion 3` · hash `2489780106`.
Critérios do plano: [`p1-plano.md`](p1-plano.md) S6 — `battle_finished.result_hash` igual ao
replay; recompensa idempotente por `battle_id`; divergência vira `battle_divergence`; GAP-011
(`contentVersion` no `BattleLog`).

---

## 1. Pré-condições

1. No WSL: `source scripts/env.sh && bash scripts/doctor.sh && bash scripts/check.sh` (RC=0).
2. `rojo build default.project.json -o build/place.rbxl` e abrir o lugar no Studio.
3. `ServerStorage.ProfileStoreMock = true` (default do Studio). O BattleLog tem store próprio:
   `ServerStorage.BattleLogMock` (default Studio = Mock; `false` tenta DataStore real).
4. Para ter ouro/armadilhas no build, o grant da S4 (`QaStarterGold`/`QaLeaguePoints`) é opcional;
   a raid funciona com o perfil zerado (a recompensa é creditada no fim).
5. `ProfileSelfTest = false`.

## 2. Logs esperados

```text
[raid] battlelog store=Mock name=MuralhaBattleLog_v1
[raid] servidor pronto store=Mock reward=5 sim=3
[analytics] battle_started battle_id=... grid_width=5 seed=... sim_version=3 traps_count=5
[analytics] battle_finished battle_id=... duration_ms=... result_hash=... winner=...
[analytics] raid_end battle_id=... duration_s=... result=...
[analytics] gold_earned amount=5 source=raid battle_id=...
[raid] battlelog battle_id=... content=v2 reward=5 hash=...
[raid] creditou 5 ouro gold=8
```

`battle_finished` sai **depois** do hash; `battle_divergence` só aparece se o replay não bater.
O `BattleLog` fica em `MuralhaBattleLog_v1`, separado do perfil.

## 3. Raid no cliente

- [ ] Botão **ATACAR** aparece no canto superior esquerdo, abaixo do HUD, depois do drop-in/build.
- [ ] Ao clicar, modal **RAID** abre com `ATACANDO...`, depois `VITORIA`/`DERROTA`, `battle_id`,
      `hash`, muralha/vazados e recompensa.
- [ ] Barra de replay percorre **8 s** e termina em `REPLAY CONCLUIDO · 8s`.
- [ ] `FECHAR` volta ao build; o botão ATACAR reaparece.
- [ ] Layout sem sobreposição em **375×812** e **720×1280**; o botão não cobre o grid.

## 4. Servidor autoritativo e recompensa

- [ ] A raid usa `WallService.toBattleWall` para a parede fantasma (perfil sintético) e
      `Core.Battle` com seed/wave registrados.
- [ ] O replay roda o mesmo seed/muralha/wave; `result_hash` do `battle_finished` é o mesmo que o
      cliente mostra.
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
- [ ] O cliente nunca decide recompensa/hash; só mostra o retorno do servidor.

## 6. Performance / limites do scaffold

- [ ] FPS ≥45 no build/raid (o modal é 2D; medir no Studio focado).
- [ ] Sem erro recorrente no Output; `ContentId` e `ProfileStore API services unavailable` em Mock
      são ruído conhecido.
- [ ] `rojo build` ≤30 s; sem mudança de `simVersion`/hash/schema/content.
- [ ] **Scaffold:** a parede fantasma é o loadout padrão do motor (5 tipos) e a recompensa de raid
      é **5 ouro provisório** para o teste de idempotência; não é economia final. O replay visual
      é a barra de 8 s (o replay 3D da raid fica para a janela de cena/replay).

## 7. Evidência para fechar a S6

1. linhas `[raid]` + `[analytics] battle_started/battle_finished/raid_end/gold_earned` do Output;
2. print do modal com `VITORIA`/`DERROTA`, hash e barra de replay em **375×812** e **720×1280**;
3. print/Output do `BattleLog` com `contentVersion=2` e `battle_id` único;
4. FPS medido e tempo do `rojo build`/Play;
5. veredito: **S6 fechada** ou **S6 em correção**.

Sem os itens **1–3**, a S6 não fecha. Contrato headless + CI não substituem o Studio.

## 8. Fora do scaffold (não inventar)

- S7 (AnalyticsService/envelope) e P2/live ops não começam aqui.
- A parede fantasma de outro jogador e o replay 3D de 8 s não entram neste scaffold; usamos o
  loadout padrão do motor e a barra de replay.
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
- **Falta (humano):** re-testar após `MuralhaGold`/log `[raid] battlelog` — topo OURO 8 e
  `content=v2`; prints finais 375×812/720×1280 e veredito.

## 10. Evidência parcial — 10/11/2026

- **375×812:** raid DERROTA (hash 965886648, muralha 178 HP, vazados 27, reward 0) e VITORIA
  (hash 1193837270, muralha 0 HP, vazados 31, reward 5); barra de replay de 8 s.
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
- **Ainda falta para fechar a S6 como feature completa:** replay visual 3D e fantasma de outro
  jogador (o scaffold usa loadout padrão + barra de 8 s); idempotência/divergência no Studio têm
  prova headless no contrato. S6 continua **aberta**.

### Correção do OURO stale (10/11/2026)

O raid creditava o ouro no perfil (`gold_earned` no Output), mas o topo do build continuava em
`OURO 3`: o `BuildClient` não reabria o snapshot. Agora o servidor publica `MuralhaGold` e o cliente
refaz `BuildSnapshot`; o log `[raid] creditou 5 ouro gold=8` prova o valor. Re-testar e esperar
**OURO 8** no topo do build depois da vitória (3 + 5).

### Leitura do gold no teste

O salto `gold=8 → 13 → ...` é o reward de 5 por vitória; quando o jogador gasta 40 (archer) + 5
(upgrade), o topo cai para **OURO 13** e o archer L2 aparece. Em Mock o perfil não persiste entre
sessões (`ProfileStore API services unavailable`); persistência real é o Modo B/DataStore, não o
teste local. O reward 5 continua provisório.
