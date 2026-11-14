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

## Esteira (Blender por script → Forge3D QC)

Um comando gera **todos** os itens de jogo restantes, passa pelo QC do Forge3D 0.6.0 (rota
`import`, mesma da muralha) e monta o lineup. **Nunca faz upload** (nenhum `forge3d upload-*`).

```bash
bash tools/art-pipeline.sh                 # todos os grupos: wall, traps, horde, portal, props, fauna (exit 0 = tudo publicado, 0 reprovados)
bash tools/art-pipeline.sh --only traps    # um grupo (repetível)
bash tools/art-pipeline.sh --skip-blender  # só Forge3D + lineup sobre os GLB já exportados
```

| Grupo | Script | Itens (id Forge3D → objeto) | Orçamento |
|---|---|---|---|
| `wall` | `art/scripts/make_wall_bastion.py` | `wall.bastion.l<n>.01` → `WALL_bastion_{segmentl,segmentr,towerl,towerr,gate}_l<n>` (L1–L5) | ≤ 2950 tris/tier (`LIMITE_LOTE` 3000) |
| `traps` | `art/scripts/make_traps.py` | `trap.<tipo>.l<n>.01` → `TRAP_<tipo>_l<n>` (archer, tar, frost, cannon, catapult × L1–L5) | ≤ 1500 tris, pegada ≤ 4,8 × 4,8 |
| `horde` | `art/scripts/make_horde.py` | `horde.<tipo>.01` → `CMD_<tipo>` (runner, brute, swarm) | ≤ 1500 tris |
| `portal` | `art/scripts/make_portal.py` | `prop.rift_portal.01` → `PROP_rift_portal` | ≤ 2000 tris |
| `props` | `art/scripts/make_props.py` | `prop.<tipo>.01` → `PROP_<tipo>` (`tree_pine`, `tree_oak`, `rock_cluster`, `siege_supply`, `iron_brazier`, `rift_obelisk`) | ≤ 900–1400 tris |
| `fauna` | `art/scripts/make_fauna.py` | `fauna.<tipo>.01` → `FAUNA_<tipo>` (`wyvern_body`/`wing_l`/`wing_r`, `bird_body`/`wing_l`/`wing_r`, `stag`, `pack_ox`, `ram`) | ≤ 1100 tris |

Etapas: Blender headless (grupos em paralelo, `--python-exit-code 1`) → `forge3d validate` →
`forge3d run` → `forge3d verify ~/.local/state/forge3d/saida/muralha_<grupo>` → `montage`.
Logs e relatórios JSON em `art/renders/_logs/`; renders por item em `art/renders/<grupo>/`;
lineups em `art/renders/lineup_<grupo>.png` e `lineup_all.png` (tudo ignorado no git).

- **Helpers compartilhados:** `art/scripts/lowpoly_lib.py` (atlas de paleta 256², `paint()`,
  primitivas, chevrons de patente). `make_wall_bastion.py` tem paleta estendida própria (inclui `ink`).
- **Lotes gerados:** `art/forge/lote_{muralha,traps,horde,portal,props,fauna}_import.yaml` são escritos
  pelo script com `altura_metros` = altura **medida** do GLB × 0,28. Não editar à mão; regenerar.
- **QC já embutido:** jitter determinístico de 3–12 milésimos de stud por peça no `join()` (G1:
  sem arestas coincidentes após a solda do Forge), pivô normalizado em Z=0 (G2), UV espalhada na
  célula da paleta (G3), 1 material (G5). O `g1_check()` local reprova antes do Forge. As asas de
  `fauna` usam `center_xy=False` e `pivot: origem` para manter o encaixe de ombro em `(0, 0, 0)`.
- **Patente (L1–L3):** mastro + 1/2/3 chevrons ≥ 0,6 stud (`amber` / `amberBright` /
  `neonAmber`) no canto frontal-esquerdo (−1,95; −2,1). Esse é o canto que a câmera do
  `BuildClient` vê quando a frente (−Y Blender = −Z Studio) aponta para o portal (+X). No piche
  os chevrons ficam em fila numa placa frontal para não romper a classe de altura de 1,2 stud.
- **Horda:** escala final `VisualTheme.ENEMIES[*].scale × 1,8` já aplicada no mesh; o
  `ScaleTo` do `HordeKit` precisa ser 1 se o MeshPart substituir as Parts.
- **Pendente (manual):** importar no Studio, conferir orientação real do importador e salvar
  `.rbxm`; tiers cosméticos (Raro+) ainda não entram na esteira.
