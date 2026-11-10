# QA da S8 no Studio — apresentação visual

> **Status:** **S8 implementada em 10/11/2026.** O build, o contrato visual **8/8**, o `check.sh` e o
> **smoke de runtime no Studio** (`tools/s8-smoke.luau` via `run-in-roblox`: arena, 5 traps, 3 hordas,
> UI, VFX e áudio) passaram. A validação **visual** (prints/FPS) é manual e ainda não foi executada por
> um humano; este roteiro fecha essa evidência. Sem mudança de schema/content/sim/taxonomia.

**Base:** `main` pós-S8 · schema 2 · content 2 · `simVersion 3` · hash `2489780106`.
Plano: [`s8-plano-visual.md`](s8-plano-visual.md).

---

## 1. Pré-condições

1. No WSL: `source scripts/env.sh && bash scripts/doctor.sh && bash scripts/check.sh` (RC=0).
2. `rojo build default.project.json -o build/place.rbxl` e abrir no Studio.
3. `ServerStorage.ProfileStoreMock = true` (default do Studio).
4. `ProfileSelfTest = false`.
5. Para testar raid/build com ouro: `QaStarterGold`/`QaLeaguePoints` (S4) ou jogue a raid.
6. `ServerStorage.AnalyticsSink` pode ficar no default (`Memory` no Studio).

## 2. Cena de build — 375×812 e 720×1280

- [ ] A baseplate não aparece como grama chapada: o diorama tem plataforma de pedra, madeira, 5 lanes,
      muralha/portão à esquerda e portal verde-água à direita.
- [ ] A câmera isométrica enquadra o grid inteiro sem cortar a muralha nem o portal.
- [ ] As 25 células são legíveis (placas escuras), sem cubos cinza translúcidos.
- [ ] A UI tem barra superior com moeda/ouro, liga e versão; barra de seleção; cartões de armadilha no
      rodapé; status legível.
- [ ] Os 5 cartões cabem em 375 px, com ícone, nome e custo; seleção fica âmbar.
- [ ] O HUD de debug **não** aparece ao entrar; `F3` alterna `FPS/T/UI`.
- [ ] Colocar uma armadilha mostra o modelo 3D no lugar da célula (torre/piche/gelo/canhão/catapulta),
      com pips de nível; a célula da UI muda de cor e mostra `L1`.
- [ ] Upgrade muda o nível/pips; remover volta a célula ao estado vazio.
- [ ] Sem BillboardGui “ARQUEIRO L1” flutuando sobre a peça.
- [ ] `ATACAR` (RaidClient) fica no espaço livre abaixo da barra de seleção, sem cobrir o grid em
      375×812/720×1280.

## 3. Drop-in — primeira impressão

- [ ] Entrar no jogo mostra a arena no offset (200,0,0), com horda 3D nas 5 lanes, portão e catapulta.
- [ ] A câmera está baixa o suficiente para ler a muralha e a horda; não há baseplate verde no fundo.
- [ ] O som de horn toca; a horda faz bob/movimento; a barra MURALHA está no topo.
- [ ] DEFENDER aparece em ~1,5 s, com anel/âmbar e pulso em ~6 s.
- [ ] Ao apertar: projéteis de catapulta saem da muralha, impactos/poeira, FOV/slow motion, shake e som.
- [ ] `ONDA LIMPA` aparece; a horda some; o build entra logo depois.
- [ ] Sem apertar: em ~10 s a horda chega, `A HORDA PASSOU` + `TENTAR DE NOVO`; sem crédito de ouro.
- [ ] Retry reabre a cena com novo `dropin_shown` no Output.

## 4. Raid/replay

- [ ] `ATACAR` abre a modal de raid com título/status e detalhes.
- [ ] O replay 3D mostra o diorama, traps da muralha fantasma, horda em 3 silhuetas e a barra de HP por 8 s.
- [ ] `REPLAY CONCLUIDO · 8s` e `FECHAR` aparecem; o hash local continua igual ao servidor; sem
      `DIVERGENCIA`.
- [ ] Vitória e derrota têm cor/som diferentes; o OURO do build atualiza.
- [ ] Em 375×812 e 720×1280 a modal não corta o `FECHAR` nem o viewport.

## 5. Performance e regressão

- [ ] FPS ≥45 no Studio focado (alvo 60) em build/drop-in/replay; registrar o número.
- [ ] Draw calls ≤500 e sem erro recorrente no Output.
- [ ] `luau sim/visual-contract.luau` → 8/8.
- [ ] `luau sim/analytics-contract.luau` → 34/34.
- [ ] `bash scripts/check.sh` → RC=0.
- [ ] Nenhuma mudança de `simVersion`/hash/schema/content; S4/S5/S6/S7 continuam passando.

## 6. Smoke de runtime executado (Studio, 10/11/2026)

`tools/s8-smoke.luau` foi executado dentro do Studio com `run-in-roblox` sobre `build/place.rbxl`:

```text
[analytics] servico pronto sink=Memory flush=30s/100 rate=10/min debug=true
[s8-smoke] OK visual setup
[s8-smoke] OK arena
[s8-smoke] OK trap kit
[s8-smoke] OK horde kit
[s8-smoke] OK vfx
[s8-smoke] OK ui kit
[s8-smoke] OK audio
[s8-smoke] PASSOU traps=5 hordas=3
```

O runner emite um erro de `require` do próprio plugin **depois** do smoke e um `ContentId` legado
(`rbxassetid://203785492`, ruído histórico da P0); nenhum dos dois vem do S8. O smoke prova que as
APIs/peças/Enum/propriedades usadas existem no Studio real; **não** prova render/beleza. Prints e FPS
continuam sendo o item manual abaixo.

## 7. Evidência para fechar o QA visual

1. Print do build 375×812 e 720×1280 com a arena, grid, cartões e OURO.
2. Print do drop-in antes/depois do DEFENDER (horda, projéteis, ONDA LIMPA).
3. Print da modal/replay 3D com `REPLAY CONCLUIDO` e FECHAR.
4. FPS/draw calls medidos e tempo do `rojo build`.
5. Veredito: **S8 aprovada visualmente** ou lista de ajustes.

Sem os itens 1–3 o QA visual não fecha. O contrato headless + CI não substituem o Studio.

## 8. Áudio (placeholder)

`AudioKit.SOUNDS` usa sons embutidos (`rbxasset://`) para o protótipo não ficar mudo:

| Cue | Fonte provisória |
|---|---|
| `ui_click`, `trap_upgrade`, `victory` | `electronicpingshort.wav` |
| `trap_place`, `projectile` | `snap.mp3` |
| `impact` | `impact_water.mp3` |
| `gate_hit`, `horn` | `bass.wav` |
| `ui_deny`, `defeat` | `uuhhh.mp3` |

Para trocar por SFX originais: gerar/editar OGG, subir no Creator Dashboard, substituir os IDs em
`AudioKit.SOUNDS` e registrar licença em `CREDITS.md`. Sem upload, o jogo continua funcional.
