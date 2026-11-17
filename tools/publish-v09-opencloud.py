#!/usr/bin/env python3
"""Publicador Open Cloud v1.8 (Forge3D 0.9.0 / spec@6 / roblox-aa-80).

Publica os 211 assets visuais da MURALHA na Open Cloud (`creator_id=11966727684`, `user`)
com checkpoint idempotente em `art/renders/_logs/opencloud_v09_ledger.json`, backoff
exponencial e `strip_embedded_textures=True` nos 97 GLBs, atualizando os catálogos Luau em
`src/shared/visual/{Wall,Mesh,Backdrop,Pbr,Vfx}Assets.luau`.

Uso:
  python3 tools/publish-v09-opencloud.py --dry-run
  python3 tools/publish-v09-opencloud.py
"""

from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
import os
import pathlib
import re
import subprocess
import sys
import threading
import time
from dataclasses import dataclass

FORGE_SITE = pathlib.Path.home() / ".local/share/uv/tools/forge3d/lib/python3.12/site-packages"
if str(FORGE_SITE) not in sys.path:
    sys.path.insert(0, str(FORGE_SITE))

from forge3d import upload as forge_upload  # noqa: E402
from forge3d.errors import ForgeError  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parents[1]
SAIDA_DIR = pathlib.Path.home() / ".local/state/forge3d/saida"
LEDGER_PATH = ROOT / "art/renders/_logs/opencloud_v09_ledger.json"

CREATOR_ID = "11966727684"
CREATOR_TYPE = "user"

TRAPS = ("archer", "tar", "frost", "cannon", "catapult")
HORDE = ("runner", "brute", "swarm", "shieldbearer", "pyromancer", "sapper", "wisp", "drake")
BOSSES = ("iron_ram_colossus", "slag_juggernaut", "rime_matriarch", "powder_baron", "rift_titan")
BOSS_PARTS = ("torso", "arm_r", "arm_l", "leg_l", "leg_r")
PORTALS = (
    ("rift", "prop_rift_portal.glb", "prop.rift_portal.01", "PROP_rift_portal"),
    ("act1", "portal_act1_iron.glb", "portal.act1_iron.01", "PORTAL_act1"),
    ("act2", "portal_act2_slag.glb", "portal.act2_slag.01", "PORTAL_act2"),
    ("act3", "portal_act3_frost.glb", "portal.act3_frost.01", "PORTAL_act3"),
    ("act4", "portal_act4_powder.glb", "portal.act4_powder.01", "PORTAL_act4"),
    ("act5", "portal_act5_rift.glb", "portal.act5_rift.01", "PORTAL_act5"),
)
PROPS = ("tree_pine", "tree_oak", "rock_cluster", "siege_supply", "iron_brazier", "rift_obelisk", "bastion_warden")
FAUNA = ("wyvern_body", "wyvern_wing_l", "wyvern_wing_r", "bird_body", "bird_wing_l", "bird_wing_r", "stag", "pack_ox", "ram")
BACKDROP_KEYS = ("castle01", "house01", "house02", "tower01", "windmill01", "keep01", "tree01")

VFX_SPECS = (
    ("explosionFlipbook", "vfx_flipbook_explosion_8x8.png"),
    ("frostShatterFlipbook", "vfx_flipbook_frost_shatter_8x8.png"),
    ("arcaneRiftFlipbook", "vfx_flipbook_arcane_rift_8x8.png"),
    ("fireLoopFlipbook", "vfx_flipbook_fire_loop_8x8.png"),
    ("slashSparkFlipbook", "vfx_flipbook_slash_spark_4x4.png"),
    ("shockwaveRing", "vfx_shockwave_ring.png"),
    ("softGlowFlare", "vfx_soft_glow_flare.png"),
    ("smokeWispy", "vfx_smoke_wispy.png"),
    ("scorchCraterDecal", "vfx_scorch_crater_decal.png"),
    ("beamEnergyTrail", "vfx_beam_energy_trail.png"),
    ("tarPuddleDecal", "vfx_tar_puddle_decal.png"),
    ("frostGroundDecal", "vfx_frost_ground_decal.png"),
    ("bossRuneDecal", "vfx_boss_rune_decal.png"),
    ("lightningArcBeam", "vfx_lightning_arc_beam.png"),
)
VFX_MAP = VFX_SPECS

# 24 Hero assets: (model_name, saida_group, forge_id)
HERO_ITEMS = (
    [(f"WALL_bastion_l{lvl}", "muralha_import", f"wall.bastion.l{lvl}.01") for lvl in range(1, 6)]
    + [(f"BOSS_{b}", "muralha_bosses", f"boss.{b}.01") for b in BOSSES]
    + [(f"BOSS_{b}_torso", "muralha_bosses", f"boss.{b}.torso.01") for b in BOSSES]
    + [(model_name, "muralha_portal", forge_id) for _k, _glb, forge_id, model_name in PORTALS]
    + [
        ("PROP_bastion_warden", "muralha_props", "prop.bastion_warden.01"),
        ("BACKDROP_castle01", "muralha_backdrop", "backdrop.castle01.01"),
        ("BACKDROP_keep01", "muralha_backdrop", "backdrop.keep01.01"),
    ]
)

PBR_CHANNELS = (
    ("colorMap", "baseColor"),
    ("normalMap", "normal"),
    ("metalnessMap", "metallic"),
    ("roughnessMap", "roughness"),
)


@dataclass(frozen=True)
class UploadJob:
    logical_key: str
    asset_type: str  # "Image" | "Model"
    path: pathlib.Path
    display_name: str
    description: str
    strip_textures: bool = False


def collect_jobs() -> list[UploadJob]:
    jobs: list[UploadJob] = []

    # 1. Master PBR Atlas (4 Images)
    for field, suffix in PBR_CHANNELS:
        jobs.append(
            UploadJob(
                logical_key=f"atlas.{field}",
                asset_type="Image",
                path=ROOT / "art/renders/pbr_atlas" / f"pbr_palette_{suffix}.png",
                display_name=f"Muralha_Atlas_{suffix}",
                description=f"Muralha AA 2048x2048 Master PBR Palette ({suffix})",
            )
        )

    # 2. VFX Textures (14 Images)
    for key, fname in VFX_SPECS:
        jobs.append(
            UploadJob(
                logical_key=f"vfx.{key}",
                asset_type="Image",
                path=ROOT / "art/renders/vfx" / fname,
                display_name=f"Muralha_VFX_{key}",
                description=f"Muralha AA VFX Texture ({key})",
            )
        )

    # 3. 24 Hero PBR Surfaces x 4 Channels = 96 Images
    for model_name, group_dir, forge_id in HERO_ITEMS:
        for field, suffix in PBR_CHANNELS:
            jobs.append(
                UploadJob(
                    logical_key=f"hero.{model_name}.{field}",
                    asset_type="Image",
                    path=SAIDA_DIR / group_dir / f"{forge_id}_{suffix}.png",
                    display_name=f"{model_name}_{suffix}",
                    description=f"Muralha AA Hero SurfaceAppearance {suffix} ({model_name})",
                )
            )

    # 4. 97 GLB 3D Models (strip_embedded_textures=True)
    for lvl in range(1, 6):
        jobs.append(
            UploadJob(
                logical_key=f"model.WALL_bastion_l{lvl}",
                asset_type="Model",
                path=ROOT / f"art/export/wall_bastion_l{lvl}.glb",
                display_name=f"WALL_bastion_l{lvl}_v18",
                description=f"Muralha Bastion Wall Tier {lvl} (Forge3D 0.9.0 roblox-aa-80)",
                strip_textures=True,
            )
        )
    for t in TRAPS:
        for lvl in range(1, 6):
            jobs.append(
                UploadJob(
                    logical_key=f"model.TRAP_{t}_l{lvl}",
                    asset_type="Model",
                    path=ROOT / f"art/export/trap_{t}_l{lvl}.glb",
                    display_name=f"TRAP_{t}_l{lvl}_v18",
                    description=f"Muralha Trap {t} L{lvl} (Forge3D 0.9.0 roblox-aa-80)",
                    strip_textures=True,
                )
            )
    for kind in HORDE:
        jobs.append(
            UploadJob(
                logical_key=f"model.CMD_{kind}",
                asset_type="Model",
                path=ROOT / f"art/export/horde_{kind}.glb",
                display_name=f"CMD_{kind}_v18",
                description=f"Muralha Horde {kind} (Forge3D 0.9.0 roblox-aa-80)",
                strip_textures=True,
            )
        )
    for b in BOSSES:
        jobs.append(
            UploadJob(
                logical_key=f"model.BOSS_{b}",
                asset_type="Model",
                path=ROOT / f"art/export/boss_{b}.glb",
                display_name=f"BOSS_{b}_v18",
                description=f"Muralha Boss {b} Showcase (Forge3D 0.9.0 roblox-aa-80)",
                strip_textures=True,
            )
        )
        for pk in BOSS_PARTS:
            jobs.append(
                UploadJob(
                    logical_key=f"model.BOSS_{b}_{pk}",
                    asset_type="Model",
                    path=ROOT / f"art/export/boss_{b}_{pk}.glb",
                    display_name=f"BOSS_{b}_{pk}_v18",
                    description=f"Muralha Boss {b} {pk} (Forge3D 0.9.0 roblox-aa-80)",
                    strip_textures=True,
                )
            )
    for pkey, glb_name, _fid, model_name in PORTALS:
        jobs.append(
            UploadJob(
                logical_key=f"model.PORTAL_{pkey}",
                asset_type="Model",
                path=ROOT / "art/export" / glb_name,
                display_name=f"{model_name}_v18",
                description=f"Muralha Portal {pkey} (Forge3D 0.9.0 roblox-aa-80)",
                strip_textures=True,
            )
        )
    for pk in PROPS:
        jobs.append(
            UploadJob(
                logical_key=f"model.PROP_{pk}",
                asset_type="Model",
                path=ROOT / f"art/export/{pk}.glb",
                display_name=f"PROP_{pk}_v18",
                description=f"Muralha Prop {pk} (Forge3D 0.9.0 roblox-aa-80)",
                strip_textures=True,
            )
        )
    for fk in FAUNA:
        jobs.append(
            UploadJob(
                logical_key=f"model.FAUNA_{fk}",
                asset_type="Model",
                path=ROOT / f"art/export/{fk}.glb",
                display_name=f"FAUNA_{fk}_v18",
                description=f"Muralha Fauna {fk} (Forge3D 0.9.0 roblox-aa-80)",
                strip_textures=True,
            )
        )
    for bk in BACKDROP_KEYS:
        jobs.append(
            UploadJob(
                logical_key=f"model.BACKDROP_{bk}",
                asset_type="Model",
                path=ROOT / f"art/export/backdrop_{bk}.glb",
                display_name=f"BACKDROP_{bk}_v18",
                description=f"Muralha Backdrop {bk} (Forge3D 0.9.0 roblox-aa-80)",
                strip_textures=True,
            )
        )
    return jobs


def compute_digest(job: UploadJob) -> str:
    data = job.path.read_bytes()
    h = hashlib.sha256(data)
    h.update(b"|strip=1" if job.strip_textures else b"|strip=0")
    return h.hexdigest()


def load_ledger() -> dict[str, dict]:
    if LEDGER_PATH.is_file():
        return json.loads(LEDGER_PATH.read_text(encoding="utf-8"))
    return {}


def save_ledger(ledger: dict[str, dict]) -> None:
    LEDGER_PATH.parent.mkdir(parents=True, exist_ok=True)
    tmp = LEDGER_PATH.with_suffix(".tmp")
    tmp.write_text(json.dumps(ledger, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp.replace(LEDGER_PATH)


def upload_one(job: UploadJob, api_key: str | None, ledger: dict[str, dict], lock: threading.Lock, dry_run: bool) -> tuple[str, int, str]:
    digest = compute_digest(job)
    with lock:
        prev = ledger.get(job.logical_key)
        if prev and prev.get("sha256") == digest and int(prev.get("asset_id") or 0) > 0:
            return job.logical_key, int(prev["asset_id"]), "cache_hit"

    if dry_run:
        res = forge_upload.executar(
            job.path,
            asset_type=job.asset_type,
            nome=job.display_name,
            descricao=job.description,
            creator_id=CREATOR_ID,
            creator_type=CREATOR_TYPE,
            key=api_key,
            dry_run=True,
            strip_embedded_textures=job.strip_textures,
        )
        assert res["ok"] and res["key_presente"]
        return job.logical_key, 0, "dry_run_ok"

    delays = (2.0, 5.0, 12.0, 25.0, 45.0)
    last_err: Exception | None = None
    for attempt in range(len(delays) + 1):
        try:
            res = forge_upload.executar(
                job.path,
                asset_type=job.asset_type,
                nome=job.display_name,
                descricao=job.description,
                creator_id=CREATOR_ID,
                creator_type=CREATOR_TYPE,
                key=api_key,
                dry_run=False,
                intervalo=2.0,
                max_espera=300.0,
                strip_embedded_textures=job.strip_textures,
            )
            asset_id = int(res["asset_id"])
            with lock:
                ledger[job.logical_key] = {
                    "asset_id": asset_id,
                    "sha256": digest,
                    "asset_type": job.asset_type,
                    "display_name": job.display_name,
                    "file": str(job.path),
                    "bytes": int(res.get("bytes") or 0),
                    "moderation": res.get("moderation"),
                    "ts": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
                }
                save_ledger(ledger)
            return job.logical_key, asset_id, "uploaded"
        except ForgeError as exc:
            msg = str(exc).lower()
            if "moderacao" in msg or "401" in msg or "403" in msg or "unauthorized" in msg:
                raise
            last_err = exc
        except Exception as exc:  # noqa: BLE001
            last_err = exc
        if attempt < len(delays):
            time.sleep(delays[attempt])
    raise RuntimeError(f"Falha definitiva em {job.logical_key} ({job.path}): {last_err}")


def _extract_surface_ids(ids_or_surfaces: dict, key: str) -> dict[str, int]:
    if key in ids_or_surfaces and isinstance(ids_or_surfaces[key], dict):
        surf = ids_or_surfaces[key]
        return {
            "colorMap": int(surf["colorMap"]),
            "normalMap": int(surf["normalMap"]),
            "metalnessMap": int(surf["metalnessMap"]),
            "roughnessMap": int(surf["roughnessMap"]),
        }
    prefix = "atlas" if key == "MASTER_ATLAS" else f"hero.{key}"
    return {
        "colorMap": int(ids_or_surfaces[f"{prefix}.colorMap"]),
        "normalMap": int(ids_or_surfaces[f"{prefix}.normalMap"]),
        "metalnessMap": int(ids_or_surfaces[f"{prefix}.metalnessMap"]),
        "roughnessMap": int(ids_or_surfaces[f"{prefix}.roughnessMap"]),
    }


def write_surface_appearances_model_json(ids_or_surfaces: dict) -> pathlib.Path:
    hero_names = sorted(model_name for model_name, _g, _fid in HERO_ITEMS)
    ordered_keys = ["MASTER_ATLAS", *hero_names]
    children = []
    for name in ordered_keys:
        surf = _extract_surface_ids(ids_or_surfaces, name)
        children.append(
            {
                "Name": name,
                "ClassName": "SurfaceAppearance",
                "Properties": {
                    "AlphaMode": "Overlay",
                    "ColorMap": f"rbxassetid://{surf['colorMap']}",
                    "NormalMap": f"rbxassetid://{surf['normalMap']}",
                    "MetalnessMap": f"rbxassetid://{surf['metalnessMap']}",
                    "RoughnessMap": f"rbxassetid://{surf['roughnessMap']}",
                },
            }
        )
    doc = {
        "ClassName": "Folder",
        "Children": children,
    }
    sa_path = ROOT / "src/shared/visual/SurfaceAppearances.model.json"
    sa_path.write_text(json.dumps(doc, indent=2) + "\n", encoding="utf-8")
    return sa_path


def patch_luau_catalogs(ids: dict[str, int]) -> None:
    atlas_color = ids["atlas.colorMap"]

    # 1. WallAssets.luau
    wall_p = ROOT / "src/shared/visual/WallAssets.luau"
    wall_txt = wall_p.read_text(encoding="utf-8")
    wall_block = "WallAssets.ASSET_IDS = table.freeze({\n" + "\n".join(
        f"\t{ids[f'model.WALL_bastion_l{lvl}']}, -- WALL_bastion_l{lvl}" for lvl in range(1, 6)
    ) + "\n})"
    wall_txt, n = re.subn(r"WallAssets\.ASSET_IDS = table\.freeze\(\{.*?\}\)", wall_block, wall_txt, count=1, flags=re.S)
    assert n == 1, "Falha ao atualizar WallAssets.ASSET_IDS"
    wall_p.write_text(wall_txt, encoding="utf-8")

    # 2. BackdropAssets.luau
    bd_p = ROOT / "src/shared/visual/BackdropAssets.luau"
    bd_txt = bd_p.read_text(encoding="utf-8")
    bd_entries = "\n".join(
        f'\ttable.freeze({{ key = "{k}", assetId = {ids[f"model.BACKDROP_{k}"]}, textureId = {atlas_color} }}),'
        for k in BACKDROP_KEYS
    )
    bd_block = f"BackdropAssets.ASSETS = table.freeze({{\n{bd_entries}\n}} :: {{ Asset }})"
    bd_txt, n = re.subn(r"BackdropAssets\.ASSETS = table\.freeze\(\{.*?\}\s*::\s*\{\s*Asset\s*\}\)", bd_block, bd_txt, count=1, flags=re.S)
    assert n == 1, "Falha ao atualizar BackdropAssets.ASSETS"
    bd_p.write_text(bd_txt, encoding="utf-8")

    # 3. MeshAssets.luau
    mesh_p = ROOT / "src/shared/visual/MeshAssets.luau"
    mesh_txt = mesh_p.read_text(encoding="utf-8")
    mesh_txt = re.sub(r"MeshAssets\.PORTAL = \d+", f"MeshAssets.PORTAL = {ids['model.PORTAL_rift']}", mesh_txt, count=1)
    mesh_txt = re.sub(
        r"MeshAssets\.LOWPOLY_PALETTE_TEXTURE_ID = \d+",
        f"MeshAssets.LOWPOLY_PALETTE_TEXTURE_ID = {atlas_color}",
        mesh_txt,
        count=1,
    )
    portals_block = "MeshAssets.PORTALS = table.freeze({\n" + "\n".join(
        f"\t{pkey} = {ids[f'model.PORTAL_{pkey}']}, -- {mname}" for pkey, _g, _f, mname in PORTALS
    ) + "\n}) :: { [string]: number }"
    mesh_txt, n = re.subn(r"MeshAssets\.PORTALS = table\.freeze\(\{.*?\}\)\s*::\s*\{\s*\[string\]:\s*number\s*\}", portals_block, mesh_txt, count=1, flags=re.S)
    assert n == 1, "PORTALS"

    traps_lines = ["MeshAssets.TRAPS = table.freeze({"]
    for t in TRAPS:
        traps_lines.append(f"\t{t} = table.freeze({{")
        for lvl in range(1, 6):
            traps_lines.append(f"\t\t{ids[f'model.TRAP_{t}_l{lvl}']}, -- TRAP_{t}_l{lvl}")
        traps_lines.append("\t}),")
    traps_lines.append("}) :: { [string]: { number } }")
    mesh_txt, n = re.subn(r"MeshAssets\.TRAPS = table\.freeze\(\{.*?\}\)\s*::\s*\{\s*\[string\]:\s*\{\s*number\s*\}\s*\}", "\n".join(traps_lines), mesh_txt, count=1, flags=re.S)
    assert n == 1, "TRAPS"

    horde_block = "MeshAssets.HORDE = table.freeze({\n" + "\n".join(
        f"\t{k} = {ids[f'model.CMD_{k}']}, -- CMD_{k}" for k in HORDE
    ) + "\n}) :: { [string]: number }"
    mesh_txt, n = re.subn(r"MeshAssets\.HORDE = table\.freeze\(\{.*?\}\)\s*::\s*\{\s*\[string\]:\s*number\s*\}", horde_block, mesh_txt, count=1, flags=re.S)
    assert n == 1, "HORDE"

    bosses_block = "MeshAssets.BOSSES = table.freeze({\n" + "\n".join(
        f"\t{b} = {ids[f'model.BOSS_{b}']}, -- BOSS_{b}" for b in BOSSES
    ) + "\n}) :: { [string]: number }"
    mesh_txt, n = re.subn(r"MeshAssets\.BOSSES = table\.freeze\(\{.*?\}\)\s*::\s*\{\s*\[string\]:\s*number\s*\}", bosses_block, mesh_txt, count=1, flags=re.S)
    assert n == 1, "BOSSES"

    bparts_lines = ["MeshAssets.BOSS_PARTS = table.freeze({"]
    for b in BOSSES:
        bparts_lines.append(f"\t{b} = table.freeze({{")
        for pk in BOSS_PARTS:
            bparts_lines.append(f"\t\t{pk} = {ids[f'model.BOSS_{b}_{pk}']}, -- BOSS_{b}_{pk}")
        bparts_lines.append("\t}),")
    bparts_lines.append("}) :: { [string]: BossPartIds }")
    mesh_txt, n = re.subn(r"MeshAssets\.BOSS_PARTS = table\.freeze\(\{.*?\}\)\s*::\s*\{\s*\[string\]:\s*BossPartIds\s*\}", "\n".join(bparts_lines), mesh_txt, count=1, flags=re.S)
    assert n == 1, "BOSS_PARTS"

    props_block = "MeshAssets.PROPS = table.freeze({\n" + "\n".join(
        f"\t{k} = {ids[f'model.PROP_{k}']}, -- PROP_{k}" for k in PROPS
    ) + "\n}) :: { [string]: number }"
    mesh_txt, n = re.subn(r"MeshAssets\.PROPS = table\.freeze\(\{.*?\}\)\s*::\s*\{\s*\[string\]:\s*number\s*\}", props_block, mesh_txt, count=1, flags=re.S)
    assert n == 1, "PROPS"

    fauna_block = "MeshAssets.FAUNA = table.freeze({\n" + "\n".join(
        f"\t{k} = {ids[f'model.FAUNA_{k}']}, -- FAUNA_{k}" for k in FAUNA
    ) + "\n}) :: { [string]: number }"
    mesh_txt, n = re.subn(r"MeshAssets\.FAUNA = table\.freeze\(\{.*?\}\)\s*::\s*\{\s*\[string\]:\s*number\s*\}", fauna_block, mesh_txt, count=1, flags=re.S)
    assert n == 1, "FAUNA"
    mesh_p.write_text(mesh_txt, encoding="utf-8")

    # 4. PbrAssets.luau
    pbr_p = ROOT / "src/shared/visual/PbrAssets.luau"
    pbr_txt = pbr_p.read_text(encoding="utf-8")
    atlas_block = (
        "PbrAssets.MASTER_ATLAS = table.freeze({\n"
        f"\tcolorMap = {ids['atlas.colorMap']},\n"
        f"\tnormalMap = {ids['atlas.normalMap']},\n"
        f"\tmetalnessMap = {ids['atlas.metalnessMap']},\n"
        f"\troughnessMap = {ids['atlas.roughnessMap']},\n"
        "})"
    )
    pbr_txt, n = re.subn(r"PbrAssets\.MASTER_ATLAS = table\.freeze\(\{.*?\}\)", atlas_block, pbr_txt, count=1, flags=re.S)
    assert n == 1, "MASTER_ATLAS"

    hero_lines = ["PbrAssets.HERO_SURFACES = {"]
    for model_name, _g, _fid in HERO_ITEMS:
        cm = ids[f"hero.{model_name}.colorMap"]
        nm = ids[f"hero.{model_name}.normalMap"]
        mm = ids[f"hero.{model_name}.metalnessMap"]
        rm = ids[f"hero.{model_name}.roughnessMap"]
        hero_lines.append(
            f"\t{model_name} = table.freeze({{ colorMap = {cm}, normalMap = {nm}, metalnessMap = {mm}, roughnessMap = {rm} }}),"
        )
    hero_lines.append("} :: { [string]: Surface }")
    pbr_txt, n = re.subn(r"PbrAssets\.HERO_SURFACES = \{.*?\}\s*::\s*\{\s*\[string\]:\s*Surface\s*\}", "\n".join(hero_lines), pbr_txt, count=1, flags=re.S)
    assert n == 1, "HERO_SURFACES"
    pbr_p.write_text(pbr_txt, encoding="utf-8")
    write_surface_appearances_model_json(ids)

    # 5. VfxAssets.luau
    vfx_p = ROOT / "src/shared/visual/VfxAssets.luau"
    vfx_txt = vfx_p.read_text(encoding="utf-8")
    vfx_block = "VfxAssets.IDS = {\n" + "\n".join(
        f"\t{k} = {ids[f'vfx.{k}']}," for k, _f in VFX_SPECS
    ) + "\n} :: { [string]: number }"
    vfx_txt, n = re.subn(r"VfxAssets\.IDS = \{.*?\}\s*::\s*\{\s*\[string\]:\s*number\s*\}", vfx_block, vfx_txt, count=1, flags=re.S)
    assert n == 1, "VfxAssets.IDS"
    vfx_p.write_text(vfx_txt, encoding="utf-8")

    subprocess.run(
        ["stylua", str(wall_p), str(bd_p), str(mesh_p), str(pbr_p), str(vfx_p)],
        check=True,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--workers", type=int, default=6)
    args = parser.parse_args()

    jobs = collect_jobs()
    assert len(jobs) == 211, f"Esperava 211 jobs, achei {len(jobs)}"
    missing = [str(j.path) for j in jobs if not j.path.is_file()]
    if missing:
        raise SystemExit(f"Arquivos ausentes ({len(missing)}):\n" + "\n".join(missing[:20]))

    api_key = forge_upload.chave_api(exigir=not args.dry_run)
    ledger = load_ledger()
    lock = threading.Lock()

    ids: dict[str, int] = {}
    counts = {"uploaded": 0, "cache_hit": 0, "dry_run_ok": 0}
    with concurrent.futures.ThreadPoolExecutor(max_workers=max(1, args.workers)) as pool:
        futs = {pool.submit(upload_one, j, api_key, ledger, lock, args.dry_run): j for j in jobs}
        done = 0
        for fut in concurrent.futures.as_completed(futs):
            k, aid, status = fut.result()
            ids[k] = aid
            counts[status] = counts.get(status, 0) + 1
            done += 1
            if done % 20 == 0 or done == len(jobs):
                print(f"[publish] {done}/{len(jobs)} ({status}: {k}={aid})", flush=True)

    if not args.dry_run:
        unique_ids = set(ids.values())
        assert 0 not in unique_ids, "assetId 0 detectado apos upload"
        assert len(unique_ids) == len(jobs), f"IDs duplicados: {len(unique_ids)} != {len(jobs)}"
        patch_luau_catalogs(ids)

    print(json.dumps({"ok": True, "total": len(jobs), "dry_run": args.dry_run, "counts": counts}, indent=2))


if __name__ == "__main__":
    main()
