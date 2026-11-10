# S8 — plano da apresentação visual (P1)

> **Status:** **implementação fechada em 10/11/2026.** O graybox de engenharia virou um diorama
> jogável: arena 5×5, muralha/portão, portal, 5 armadilhas 3D, 3 silhuetas de horda, UI de cartões,
> VFX, áudio de protótipo e replay no mesmo kit. O smoke de runtime no Studio passou para todos os
> módulos; o QA visual (prints/FPS) é manual e está em [`teste-s8-studio.md`](teste-s8-studio.md).
> **Não é P2**: nenhuma mudança de schema/content/sim, economia, taxonomia ou gameplay.

## 1. Objetivo

Fazer o loop drop-in → build → raid/replay parecer um jogo mínimo atraente, não um graybox, antes do
teste de 3 semanas. O critério não é “arte final”; é **leitura, intenção e game feel**:

- a pessoa entende em 3 segundos que a horda ataca uma muralha;
- o DEFENDER dá resposta física (câmera, projétil, impacto, som, slow motion);
- a UI parece jogo (cartões, moeda, liga, estados), não painel de debug;
- build e replay usam o mesmo vocabulário visual.

## 2. Direção de arte

**Diorama de guerra de brinquedo**, low-poly, peças grandes, madeira/ferro e silhuetas exageradas.

| Elemento | Decisão |
|---|---|
| Paleta | âmbar `#F59E0B` + ferro para o defensor; verde-água `#14B8A6` para a horda; madeira, pergaminho e perigo |
| Câmera | isométrica fixa; drop-in mais baixa/perto do portão |
| Silhueta | cada trap/inimigo legível a 200 px; sem BillboardGui de texto no mundo |
| UI | chapa de ferro + pergaminho, cartões com ícone/custo, tipografia pesada |
| Áudio | 10 cues de protótipo com sons embutidos; troca por SFX originais é polimento |
| Performance | 60 FPS alvo; ≤500 draw calls; trap ≤1.500 tris; partículas limitadas |

## 3. O que foi implementado

| Camada | Arquivo | Papel |
|---|---|---|
| Tema | `src/shared/visual/VisualTheme.luau` | paleta, traps, 3 hordas, UI, áudio, budgets |
| Contrato | `sim/visual-contract.luau` | 8 checagens: paleta GDD, paridade GridLayout, cobertura, layout, budgets |
| Arena | `src/client/visual/ArenaVisual.luau` | plataforma, 5 lanes, muralha/portão, portal, tochas, pedras |
| Traps | `src/client/visual/TrapKit.luau` | 5 modelos de peças + pips de nível; sync por célula |
| Horda | `src/client/visual/HordeKit.luau` | runner/bruto/enxame + bob/step |
| VFX | `src/client/visual/Vfx.luau` | impacto, poeira, morte, projétil, anel, shake |
| Áudio | `src/client/visual/AudioKit.luau` | 10 cues, SoundGroup, placeholder `rbxasset://` |
| UI | `src/client/visual/UiKit.luau` | painéis, botões, moeda, progresso, cartões |
| Setup | `src/client/visual/VisualSetup.luau` | luz quente/fria, Atmosphere, ColorCorrection, Bloom |
| Build | `src/client/BuildClient.client.luau` | arena, traps, cartões, HUD de debug em F3 |
| Drop-in | `src/client/DropInClient.client.luau` | horda 3D, DEFENDER, projéteis, vitória/derrota |
| Replay | `src/client/RaidClient.client.luau` | diorama no ViewportFrame, traps/horda e HP |
| Grade | `src/server/world/BuildGrid.luau` | células invisíveis; servidor segue autoritativo |

## 4. Fases executadas

1. **Tema e contrato** — paleta/IDs/budgets antes de desenhar.
2. **Arena e luz** — composição, lanes, muralha, portal, atmosfera.
3. **Kit** — traps e horda em peças; servidor/telemetria intocados.
4. **Game feel** — projéteis, impactos, shake, áudio.
5. **UI** — cartões, moeda, liga, modos, status; debug atrás de F3.
6. **Integração** — BuildClient/DropInClient/RaidClient no mesmo vocabulário.
7. **QA** — build/contratos/check; Studio manual documentado.

## 5. Critérios de aceite

- leitura em 3 s de um print 375×812;
- thumbnail a 200 px ainda distingue muralha âmbar × horda verde-água;
- nenhum cubo cinza/BillboardGui de trap/HUD de debug por padrão;
- DEFENDER responde em <0,3 s com câmera + VFX + SFX;
- vitória e derrota inconfundíveis;
- 60 FPS alvo e ≤500 draw calls no Studio focado;
- S4/S5/S6/S7 verdes; hash `2489780106` e `simVersion 3` intactos;
- prints 375×812/720×1280 + FPS/draw calls registrados.

## 6. Fora do S8

P2, liga/loja/live ops, novos mapas, chefes, co-op, classes/raridade, schema/content/sim, arte final
realista, ragdoll e captura cinematográfica.

## 7. Limitações conhecidas

- **Áudio:** cues embutidos da Roblox como placeholder; a troca por OGG original exige upload manual
  de asset e IDs em `AudioKit.SOUNDS`.
- **QA visual:** screenshots/FPS dependem do Studio; o agente não renderiza o cliente. O roteiro está
  em [`teste-s8-studio.md`](teste-s8-studio.md).
- **Modelos:** kit de peças, não assets Blender finais; o pipeline `art/` segue para a próxima
  janela de arte.
