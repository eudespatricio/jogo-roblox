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

## O que ainda é manual

- Importar e salvar `.rbxm` no Studio (não há automação confiável para isso).
- Validar no device fraco (triângulos, textura, draw calls) — ver orçamentos.
