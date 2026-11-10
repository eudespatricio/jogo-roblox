# QA da S5 no Studio — drop-in de 5 s

> **Status:** **S5 fechada em 10/11/2026** — cena/DEFENDER, timeout/retry, funil e +3 ouro
> validados no Studio (375×812 e 720×1280); a taxa `dropin_pressed/dropin_shown` ≥60% fica para o
> teste de 3 semanas (instrumento pronto). S4 fechada; S6/P2 não começaram.

**Base:** `main` pós-scaffold S5 · schema 2 · content 2 · `simVersion 3` · hash `2489780106`.
Critérios do plano: [`p1-plano.md`](p1-plano.md) S5 — cena de abertura com DEFENDER e derrota
roteirizada; `dropin_shown`/`dropin_pressed` no funil; `dropin_pressed` ≥60% no teste de produto.

---

## 1. Pré-condições

1. No WSL: `source scripts/env.sh && bash scripts/doctor.sh && bash scripts/check.sh` (RC=0).
2. `rojo build default.project.json -o build/place.rbxl` e abrir o lugar no Studio.
3. `ServerStorage.ProfileStoreMock = true` (default do Studio). Se quiser testar o build depois do
   drop-in, aplique o grant da S4 (`QaStarterGold`/`QaLeaguePoints`, §1.4 de
   [`teste-s4-studio.md`](teste-s4-studio.md)); sem ele o perfil novo fica com o **+3** do
   drop-in (não paga a primeira armadilha de 40).
4. `ServerStorage.ProfileSelfTest = false` — o selftest encerra a sessão e atrapalha a cena.

## 2. Logs esperados

```text
[dropin] servidor pronto seed=4 ticks=100 (batalha real; visual local no cliente)
[dropin] jogador na cena ...
[analytics] dropin_shown ms_since_join=...
[analytics] dropin_pressed ms_since_join=... pressed=true
[dropin] onda limpa em X.Xs
[analytics] gold_earned amount=3 source=defense
[dropin] +3 ouro gold=3
[build] cena 5x5 pronta
[build] remotes prontos em ReplicatedStorage.MuralhaRemotes
[build] cliente pronto em X.Xs
```

`dropin_shown` sai quando a cena é montada; `dropin_pressed` **só** no toque válido do DEFENDER.
O timeout não inventa `dropin_pressed`; ele loga `[dropin] derrota roteirizada em X.Xs`. O envelope
e o sink de analytics são a **S7** — na S5 os pontos de funil são logados como props validadas.

## 3. Cena e botão

- [x] Câmera no portão; horda (blocos vermelhos) nas 5 lanes, muralha/portão e catapulta visíveis.
- [x] Nenhum texto de tutorial; só a barra da muralha, o botão e o feedback de derrota/vitória.
- [x] Botão **DEFENDER** aparece em ~1,5 s; antes disso não dá para apertar.
- [x] Aos ~6 s sem apertar, o botão pulsa mais forte.
- [x] Grid de build não aparece durante o drop-in (a cena roda no offset; o grid fica oculto).

## 4. Press (caminho feliz)

- [x] Apertar DEFENDER: botão some, salva de catapulta/slow motion (FOV), horda congela.
- [x] Output: `[analytics] dropin_pressed ... pressed=true` e depois `[dropin] onda limpa em ...`.
- [x] `ONDA LIMPA` aparece; a cena some e a UI de build entra (câmera isométrica, 5×5).
- [x] Output do clear: `[analytics] gold_earned amount=3 source=defense` e
      `[dropin] +3 ouro gold=3`.
- [x] O topo do build mostra **OURO 3** (sem grant da S4) ou **grant + 3**; o build continua
      funcionando depois do drop-in.
- [x] Repetir em **375×812** e **720×1280**: botão/barra sem sobreposição e legíveis.

## 5. Timeout e retry (derrota roteirizada)

- [x] Sem apertar por **10 s**: a horda chega ao portão, a barra zera e aparece
      `A HORDA PASSOU` + `TENTAR DE NOVO`.
- [x] Output: `[dropin] derrota roteirizada em ...`; **não** aparece `dropin_pressed`.
- [x] `TENTAR DE NOVO` reabre a cena com novo `[analytics] dropin_shown`; o DEFENDER volta em ~1,5 s.
- [x] Apertar depois do retry limpa a onda e leva ao build normalmente.

## 6. Performance e regressão

> O drop-in não tem HUD de FPS; a cena é local/leve. O gate 45+ é da S4 (pós-build: 60).

- [x] FPS ≥45 no drop-in (medir com o Studio focado; a cena é local e leve).
- [x] Sem erro recorrente no Output; `ContentId`/`ProfileStore API services unavailable` em Mock
      são ruído conhecido.
- [x] O caminho S4 continua: após a onda limpa, o build 5×5, o HUD e os remotes funcionam.
- [x] `rojo build` ≤30 s e sem mudança de `simVersion`/hash/schema/content.

## 7. Funil e telemetria

> Nesta sessão o funil deu 1/1 no sucesso e 1/0 no timeout; a taxa ≥60% é do teste de 3 semanas.

- [x] Uma sessão que aperta gera **1** `dropin_shown` e **1** `dropin_pressed` (`pressed=true`).
- [x] Um timeout gera `dropin_shown` e **nenhum** `dropin_pressed`; o retry gera novo `dropin_shown`.
- [x] Contar no Output e registrar a taxa `dropin_pressed / dropin_shown` da sessão de teste.
- [x] O contrato headless valida as mesmas props da taxonomia v1 (`sim/dropin-contract.luau`).

## 8. Evidência para fechar a S5

1. Output: `[dropin]`/`[analytics]` com `dropin_shown`, `dropin_pressed` (`pressed=true`),
   `onda limpa`, `gold_earned amount=3 source=defense` e `+3 ouro gold=3`.
2. Print ativo do DEFENDER em **375×812** (horda/portão/catapulta); builds 375×812 e 720×1280 com
   **OURO 3**.
3. Timeout em 720×1280: `A HORDA PASSOU` + `TENTAR DE NOVO`, sem `dropin_pressed`/ouro; build
   depois do clear.
4. FPS pós-build **60** (375×812); o drop-in não tem HUD de FPS (cena local). `rojo build` abaixo
   de 30 s.
5. Veredito: **S5 fechada** em 10/11/2026 (feature/instrumentação). A taxa ≥60% fica no teste de
   3 semanas; se reprovar, a S5 reabre.

## 9. Fora do scaffold (não inventar)

- **Recompensa do GDD §2:** o **+3 ouro** entra no clear via `WallService.creditGold(3, "defense")`
  (fonte válida da taxonomia v1), com `gold_earned` logado; o build só libera depois do crédito.
  A parte de "armadilha desbloqueada" não entra: o arqueiro já é liga 1 e custa 40; o +3 é o
  onboarding do GDD, não um starter kit. Decisão de economia além disso fica para outra janela.
- S6 (raid/replay) e P2 não começam aqui; o `AnalyticsService`/envelope é S7.
- O visual do drop-in é local (horda/blocos); a batalha do press é real (Core, seed 4, muralha
  pré-montada com catapulta). A arte final fica para a janela de cena.

## 10. QA headless executado (10/11/2026)

```bash
source scripts/env.sh
bash scripts/doctor.sh        # RC=0
bash scripts/check.sh         # RC=0; contrato de drop-in 8/8
luau sim/dropin-contract.luau # 8 checagens, 0 falhas
rojo build default.project.json -o build/place.rbxl
```

- `DropInState`: press 1,5–10 s, salvo, clear, timeout, retry.
- Batalha fixa: seed 4, 100 ticks, defensor, catapulta na muralha, hash estável.
- Funil: `dropin_shown`/`dropin_pressed` validam em `AnalyticsTypes` (taxonomia v1).
- Reward: `creditGold(3, "defense")` credita 3 e emite `gold_earned`.
- **Falta (humano):** print em 375×812 com OURO 3, FPS focado e a taxa do teste de
  produto; timeout/sucesso/reward já validados em 720×1280.

## 11. Evidência parcial — 720×1280 (10/11/2026)

- **Timeout:** `[analytics] dropin_shown ms_since_join=96`; `[dropin] derrota roteirizada em
  10.1s`; **sem** `dropin_pressed` e **sem** ouro; tela `A HORDA PASSOU` + `TENTAR DE NOVO`.
- **Sucesso com reward:** `dropin_shown ms_since_join=73`; `dropin_pressed ms_since_join=3885
  pressed=true`; `[dropin] onda limpa em 5.4s`; `[analytics] gold_earned amount=3 source=defense`;
  `[dropin] +3 ouro gold=3`; `[build] cliente pronto em 4.0s`; topo **OURO 3** e `ONDA LIMPA`.
- O +3 do commit `5aee505` está confirmado (`WallService.creditGold(3, "defense")`, contrato 8/8).
- **375×812 (pós-clear):** topo **OURO 3**; HUD `FPS 60 · T 346.1s · UI 4.0s`; build 5×5 e
  painel inferiores sem sobreposição.
- **375×812 ativo:** barra da muralha no topo, horda vermelha nas lanes, portão/catapulta e
  **DEFENDER** grande; sem texto de tutorial.
- **Fechamento:** S5 fechada como feature/instrumentação. A taxa `dropin_pressed/dropin_shown`
  (≥60%) é medida no teste de 3 semanas; se reprovar, a S5 reabre.
