# QA da S5 no Studio — drop-in de 5 s

> **Status:** **S5 iniciada em 10/11/2026 (scaffold)**; QA humano pendente. A cena, o DEFENDER,
> o timeout/retry e os pontos de funil estão no repo; falta a evidência de Studio. A S5 **não
> fecha** sem logs/screens da §8. S4 está fechada; S6/P2 não começaram.

**Base:** `main` pós-scaffold S5 · schema 2 · content 2 · `simVersion 3` · hash `2489780106`.
Critérios do plano: [`p1-plano.md`](p1-plano.md) S5 — cena de abertura com DEFENDER e derrota
roteirizada; `dropin_shown`/`dropin_pressed` no funil; `dropin_pressed` ≥60% no teste de produto.

---

## 1. Pré-condições

1. No WSL: `source scripts/env.sh && bash scripts/doctor.sh && bash scripts/check.sh` (RC=0).
2. `rojo build default.project.json -o build/place.rbxl` e abrir o lugar no Studio.
3. `ServerStorage.ProfileStoreMock = true` (default do Studio). Se quiser testar o build depois do
   drop-in, aplique o grant da S4 (`QaStarterGold`/`QaLeaguePoints`, §1.4 de
   [`teste-s4-studio.md`](teste-s4-studio.md)); sem ele o perfil novo continua com 0 de ouro.
4. `ServerStorage.ProfileSelfTest = false` — o selftest encerra a sessão e atrapalha a cena.

## 2. Logs esperados

```text
[dropin] servidor pronto seed=4 ticks=100 (batalha real; visual local no cliente)
[dropin] jogador na cena ...
[analytics] dropin_shown ms_since_join=...
[analytics] dropin_pressed ms_since_join=... pressed=true
[dropin] onda limpa em X.Xs
[build] cena 5x5 pronta
[build] remotes prontos em ReplicatedStorage.MuralhaRemotes
[build] cliente pronto em X.Xs
```

`dropin_shown` sai quando a cena é montada; `dropin_pressed` **só** no toque válido do DEFENDER.
O timeout não inventa `dropin_pressed`; ele loga `[dropin] derrota roteirizada em X.Xs`. O envelope
e o sink de analytics são a **S7** — na S5 os pontos de funil são logados como props validadas.

## 3. Cena e botão

- [ ] Câmera no portão; horda (blocos vermelhos) nas 5 lanes, muralha/portão e catapulta visíveis.
- [ ] Nenhum texto de tutorial; só a barra da muralha, o botão e o feedback de derrota/vitória.
- [ ] Botão **DEFENDER** aparece em ~1,5 s; antes disso não dá para apertar.
- [ ] Aos ~6 s sem apertar, o botão pulsa mais forte.
- [ ] Grid de build não aparece durante o drop-in (a cena roda no offset; o grid fica oculto).

## 4. Press (caminho feliz)

- [ ] Apertar DEFENDER: botão some, salva de catapulta/slow motion (FOV), horda congela.
- [ ] Output: `[analytics] dropin_pressed ... pressed=true` e depois `[dropin] onda limpa em ...`.
- [ ] `ONDA LIMPA` aparece; a cena some e a UI de build entra (câmera isométrica, 5×5).
- [ ] O perfil/build continua funcionando depois do drop-in (se o grant da S4 estiver ativo,
      colocar uma armadilha; sem grant, o ouro 0 é esperado).
- [ ] Repetir em **375×812** e **720×1280**: botão/barra sem sobreposição e legíveis.

## 5. Timeout e retry (derrota roteirizada)

- [ ] Sem apertar por **10 s**: a horda chega ao portão, a barra zera e aparece
      `A HORDA PASSOU` + `TENTAR DE NOVO`.
- [ ] Output: `[dropin] derrota roteirizada em ...`; **não** aparece `dropin_pressed`.
- [ ] `TENTAR DE NOVO` reabre a cena com novo `[analytics] dropin_shown`; o DEFENDER volta em ~1,5 s.
- [ ] Apertar depois do retry limpa a onda e leva ao build normalmente.

## 6. Performance e regressão

- [ ] FPS ≥45 no drop-in (medir com o Studio focado; a cena é local e leve).
- [ ] Sem erro recorrente no Output; `ContentId`/`ProfileStore API services unavailable` em Mock
      são ruído conhecido.
- [ ] O caminho S4 continua: após a onda limpa, o build 5×5, o HUD e os remotes funcionam.
- [ ] `rojo build` ≤30 s e sem mudança de `simVersion`/hash/schema/content.

## 7. Funil e telemetria

- [ ] Uma sessão que aperta gera **1** `dropin_shown` e **1** `dropin_pressed` (`pressed=true`).
- [ ] Um timeout gera `dropin_shown` e **nenhum** `dropin_pressed`; o retry gera novo `dropin_shown`.
- [ ] Contar no Output e registrar a taxa `dropin_pressed / dropin_shown` da sessão de teste.
- [ ] O contrato headless valida as mesmas props da taxonomia v1 (`sim/dropin-contract.luau`).

## 8. Evidência para fechar a S5

Colar no handoff/`CONTINUAR.md`:

1. linhas `[dropin]`/`[analytics]` do Output (shown, pressed, limpa/derrota);
2. prints da cena + DEFENDER em **375×812** e **720×1280**;
3. print da tela de derrota + retry (timeout) e do build depois da onda limpa;
4. FPS medido e tempo do `rojo build`/Play;
5. veredito: **S5 fechada** ou **S5 em correção**.

Sem os itens **1–3**, a S5 não fecha. O scaffold e o contrato headless não substituem o Studio.

## 9. Fora do scaffold (não inventar)

- **Recompensa do GDD §2** (`+3 ouro · armadilha desbloqueada`) não entra nesta fatia: a economia/
  taxonomia v1 não define um `source` de starter e o perfil novo nasce com 0. O build pós-drop-in
  usa o grant de QA da S4 até a decisão de economia.
- S6 (raid/replay) e P2 não começam aqui; o `AnalyticsService`/envelope é S7.
- O visual do drop-in é local (horda/blocos); a batalha do press é real (Core, seed 4, muralha
  pré-montada com catapulta). A arte final fica para a janela de cena.

## 10. QA headless executado (10/11/2026)

```bash
source scripts/env.sh
bash scripts/doctor.sh        # RC=0
bash scripts/check.sh         # RC=0; contrato de drop-in 7/7
luau sim/dropin-contract.luau # 7 checagens, 0 falhas
rojo build default.project.json -o build/place.rbxl
```

- `DropInState`: press 1,5–10 s, salvo, clear, timeout, retry.
- Batalha fixa: seed 4, 100 ticks, defensor, catapulta na muralha, hash estável.
- Funil: `dropin_shown`/`dropin_pressed` validam em `AnalyticsTypes` (taxonomia v1).
- **Falta (humano):** itens 1–3 da §8 — logs/prints/FPS da cena e do timeout/retry.
