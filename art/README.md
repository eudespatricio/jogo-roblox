# Arte — pipeline Blender → Studio → Rojo

> A fonte de verdade da cena é `art/calibration.blend`. O `art/export/calibration.glb` é o arquivo
> que se importa no Studio. Renders e builds não entram no git.

## Arquivos

| Caminho | O que é | Git |
|---|---|---|
| `art/calibration.blend` | cena de calibração: cubo de 1 stud, barra de 4, eixos e seta "FRENTE" | LFS |
| `art/export/calibration.glb` | export glTF para o 3D Importer | LFS |
| `art/export/calibration.fbx` | export FBX (teste alternativo) | LFS |
| `art/scripts/make_calibration.py` | gerador da cena | normal |
| `art/scripts/make_fractured_gate.py` | gera portão central pré-fraturado em 12 blocos (`<=1500` tris) para Física Real | normal |
| `art/src/` | fontes `.blend` dos assets | LFS |
| `art/export/` | `.glb`/`.fbx` exportados | LFS |
| `art/renders/` | previews e thumbnails gerados | ignorado |

## Regras de calibração

1. **1 unidade Blender = 1 stud.** `Scene > Units > Unit System = None`, rotação em graus.
2. Blender é **Z-up**; Studio é **Y-up**. A seta aponta para `-Y` no Blender e deve apontar para
   `-Z` no Studio.
3. Pivô na **base** (`Z=0`), transforms aplicados, sem escala negativa.
4. Nome: `PREFIXO_nome_variante` (`TRAP_`, `WALL_`, `CMD_`, `PROP_`, `VFX_`).
5. Orçamentos (triângulos/textura/partículas): [`../docs/ferramentas.md`](../docs/ferramentas.md) §6.

## Regenerar

```bash
blender4.5 -b --factory-startup --python art/scripts/make_calibration.py
blender4.5 -b --factory-startup --python art/scripts/make_fractured_gate.py
```

Saídas: `art/calibration.blend`, `art/export/calibration.glb`, `art/export/calibration.fbx`,
`art/renders/calibration.png` (ignorado).

## Importar no Studio (manual, uma vez)

1. Studio → **File → Import 3D** → `art/export/calibration.glb`.
2. No importador: **Scale Unit = Studs**, **World Forward = Front**, **World Up = Top**,
   **Anchored = true**, **Insert In Workspace = true**.
3. Conferir:
   - cubo cinza = **1×1×1 stud**;
   - barra vermelha = **4 studs** no eixo X;
   - seta âmbar = aponta para **-Z** (frente do Studio);
   - eixo verde = +Y; eixo azul = +Z.
4. Se a orientação ou a escala estiverem erradas, ajustar `World Forward/Up` e salvar o preset
   `MURALHA_Default` no importador.
5. Salvar o modelo importado em `assets/models/<nome>.rbxm` (LFS). O Rojo mapeia
   `assets/models` para `ReplicatedStorage.Assets` quando o projeto de produção existir.

> **Nota de importação (09/11/2026):** no importador glTF do Studio, os materiais podem chegar
> **cinza** — o `baseColorFactor` sem textura é ignorado — e o texto de face única pode aparecer
> **espelhado**. Nada disso afeta a calibração de escala: o critério é o `Size` das peças e o sinal de
> `Position.Z` da `SETA_FRENTE_TIP`. O glTF em si tem os 9 materiais com as cores corretas.
> Reimportando o `.glb` no Blender, cores e texto aparecem corretos — a perda é só no importador
> do Studio, não no export.

## O que ainda é manual

- Importar e salvar `.rbxm` no Studio (não há automação confiável para isso).
- Validar no device fraco (triângulos, textura, draw calls) — ver orçamentos.

## Esteira (Blender por script → Forge3D 0.9.0 QC & PBR)

Um comando gera **todos** os itens de jogo restantes, passa pelo QC do Forge3D `0.9.0` (`spec@6`/`manifest@6`, perfil `roblox-aa-80`, Gate G1–G11, bake PBR `detalhe_alto`/`pbr_zonas` nos 24 modelos Hero) e monta o lineup. **Nunca faz upload** (nenhum `forge3d upload-*`; a publicação Open Cloud é separada em `tools/publish-v09-opencloud.py`).

```bash
FORGE_JOBS=4 bash tools/art-pipeline.sh  # todos os 8 grupos em paralelo: 97 modelos + 24 Hero PBR
bash tools/art-pipeline.sh --only traps   # um grupo (repetível); FORGE_SKIP_RENDER=1 pula EEVEE em iteração rápida
bash tools/art-pipeline.sh --skip-blender # só Forge3D + lineup sobre os GLB já exportados
python3 art/scripts/make_pbr_atlas.py     # gera o Atlas Mestre PBR 2048x2048 Voronoi/fibra/escamas (4 mapas)
python3 art/scripts/make_vfx_textures.py  # gera 14 texturas RGBA VFX (4 flipbooks 8x8 + 1 4x4 + 9 decals/beams/glow)
```

| Grupo | Script | Itens (id Forge3D → objeto) | Orçamento v1.9 (`roblox-aa-80`) |
|---|---|---|---|
| `wall` | `art/scripts/make_wall_bastion.py` | `wall.bastion.l<n>.01` → `WALL_bastion_l<n>` (L1–L5, UV triplanar no Atlas Voronoi `2048²`, `28°` `ultra`) | `16.196–17.776` (teto `18.000` tris/tier) |
| `traps` | `art/scripts/make_traps.py` | `trap.<tipo>.l<n>.01` → `TRAP_<tipo>_l<n>` (archer, tar, frost, cannon, catapult × L1–L5, 25 modelos) | `4.536–5.496` (teto `5.600` tris, pegada ≤ 4,8) |
| `horde` | `art/scripts/make_horde.py` | `horde.<tipo>.01` → `CMD_<tipo>` (swarm `1.650`, runner/wisp `3.118–3.256`, elites/drake `4.016–4.628`) | ≤ `2.000 / 3.600 / 5.000` tris |
| `bosses` | `art/scripts/make_bosses.py` | `boss.<tipo>.01` (`ultra` Hero `16.096–17.068`) + `boss.<tipo>.<part>.01` (`torso` `5.316–5.546` + braços `3.152–3.512` + pernas `1.966–2.198`) | `15.776–16.596` soma 5 partes (teto `17.900`) |
| `portal` | `art/scripts/make_portal.py` | `prop.rift_portal.01` + `portal.act<1..5>_<tema>.01` (6 Hero PBR) | `10.762–11.488` (teto `12.000` tris) |
| `props` | `art/scripts/make_props.py` | `prop.<tipo>.01` (`bastion_warden` Hero `9.780`, 6 props `2.748–3.144`) | `11.000` Hero / `3.600` props |
| `fauna` | `art/scripts/make_fauna.py` | `fauna.<tipo>.01` (wyvern `8.876`, quadrúpedes `4.300–4.714`, aves enxutas `1.786`) | `5.000/2.600` · `5.000` · `1.200/650` |
| `backdrop` | `art/scripts/make_backdrop.py` | `backdrop.<tipo>.01` (`castle01` `10.214` / `keep01` `9.760` Hero, vila `2.992–3.460`, `tree01` `1.668`) | `12.000` Castelos / `3.800` / `2.000` |

Etapas: Blender headless (grupos em paralelo, `--python-exit-code 1`) → `forge3d validate` →
`forge3d run` (até `FORGE_JOBS=4` grupos em paralelo) → `forge3d verify ~/.local/state/forge3d/saida/muralha_<grupo>` (`manifest@6` + Gate G1–G11) → sync do GLB pós-processado (`saida/` → `art/export/` com paridade SHA-256) → `montage`.
Logs e relatórios JSON em `art/renders/_logs/`; renders por item em `art/renders/<grupo>/`;
lineups em `art/renders/lineup_<grupo>.png` e `lineup_all.png` (tudo ignorado no git).

- **Helpers compartilhados & PBR em 2 Tiers:** `art/scripts/lowpoly_lib.py` (paleta `PAL` 63 cores, UVs espaciais anti-bleed por célula, `PAL_PBR_META`, `build_pbr_zonas` ≤ 16 zonas + `detalhe_alto` `subdiv_niveis=0`). Os `78` modelos instanciados (`muralhas` com UV triplanar ping-pong + `traps`/`horde`/`fauna`/props) compartilham o Atlas Mestre PBR Voronoi `2048×2048` (`PbrAssets.MASTER_ATLAS`, `colorMap = 123373171413605`), enquanto os `19` modelos Hero recebem mapas Cycles dedicados (`PbrAssets.HERO_SURFACES`) via `SurfaceAppearances.model.json` pré-bakeado pelo Rojo; os 97 GLBs são publicados com `strip_embedded_textures=true` (`191` assets Open Cloud).
- **Lotes gerados:** `art/forge/lote_{muralha,traps,horde,bosses,portal,props,fauna,backdrop}_import.yaml` são escritos
  pelo script com `altura_metros` = altura **medida** do GLB × 0,28. Não editar à mão; regenerar.
- **QC e suavização de normais (v1.8):** jitter determinístico de 3–12 milésimos de stud por peça no `join()` (G1:
  sem arestas coincidentes após a solda do Forge), pivô normalizado em Z=0 e gate de orientação sem rotação residual/`det>0` + `suavizacao_normais: { ativo: true, angulo_graus: 46..52, weighted_normals: true, corrective_smooth: false }` (`spec@6`, G2/G11 no Forge3D 0.9.0), UV espalhada na
  célula da paleta (G3), 1 material (G5). O `g1_check()` local reprova antes do Forge. As asas de
  `fauna` e os membros de `bosses` usam `center_xy=False` e `pivot: origem` para manter o encaixe de articulação.
- **Patente (L1–L3):** mastro + 1/2/3 chevrons ≥ 0,6 stud (`amber` / `amberBright` /
  `neonAmber`) no canto frontal-esquerdo (−1,95; −2,1). Esse é o canto que a câmera do
  `BuildClient` vê quando a frente (−Y Blender = −Z Studio) aponta para o portal (+X). No piche
  os chevrons ficam em fila numa placa frontal para não romper a classe de altura de 1,2 stud.
- **Horda:** escala final `VisualTheme.ENEMIES[*].scale × 1,8` já aplicada no mesh; o
  `ScaleTo` do `HordeKit` precisa ser 1 se o MeshPart substituir as Parts.
- **Pendente (manual):** importar no Studio, conferir orientação real do importador e salvar
  `.rbxm`; tiers cosméticos (Raro+) ainda não entram na esteira.
