#!/usr/bin/env python3
"""Gera o Atlas Mestre PBR 2048x2048 (grade 8x8, celulas 256x256) alinhado a `lowpoly_lib.PAL`.

Saidas em `art/renders/pbr_atlas/`:
- `pbr_palette_baseColor.png` (sRGB RGBA)
- `pbr_palette_normal.png`    (Tangent-space OpenGL normal map, borda neutra anti-bleed)
- `pbr_palette_metallic.png`  (Grayscale RGBA)
- `pbr_palette_roughness.png` (Grayscale RGBA)

Orientacao vertical verificada contra `art/renders/_lowpoly_palette.png` (Blender bottom-left -> PNG top-down):
celula (cx = i % 8, cy = i // 8) ocupa x in [cx*256, (cx+1)*256], y_png in [(7-cy)*256, (8-cy)*256].
"""

from __future__ import annotations

import ast
import json
import math
import pathlib
import struct
import subprocess
import zlib

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
LOWPOLY_LIB = ROOT / "art" / "scripts" / "lowpoly_lib.py"
OUT_DIR = ROOT / "art" / "renders" / "pbr_atlas"

ATLAS_SIZE = 2048
CELL_SIZE = 256
BORDER_PAD = 10

FAMILY_PARAMS = {
    "stone": {"pattern": "stone", "grain": 0.10, "bump": 1.65, "met": 0.00, "r_min": 0.72, "r_max": 0.92},
    "wood": {"pattern": "wood", "grain": 0.11, "bump": 1.45, "met": 0.00, "r_min": 0.62, "r_max": 0.84},
    "metal_forged": {"pattern": "metal", "grain": 0.09, "bump": 1.20, "met": 0.88, "r_min": 0.30, "r_max": 0.52},
    "metal_gold": {"pattern": "gold", "grain": 0.08, "bump": 1.10, "met": 0.94, "r_min": 0.22, "r_max": 0.42},
    "crystal": {"pattern": "crystal", "grain": 0.10, "bump": 1.40, "met": 0.05, "r_min": 0.16, "r_max": 0.38},
    "energy": {"pattern": "energy", "grain": 0.07, "bump": 0.75, "met": 0.00, "r_min": 0.18, "r_max": 0.40},
    "cloth": {"pattern": "cloth", "grain": 0.08, "bump": 0.95, "met": 0.00, "r_min": 0.68, "r_max": 0.86},
    "leather": {"pattern": "leather", "grain": 0.09, "bump": 1.15, "met": 0.00, "r_min": 0.52, "r_max": 0.76},
    "scales": {"pattern": "scales", "grain": 0.10, "bump": 1.55, "met": 0.04, "r_min": 0.38, "r_max": 0.64},
    "foliage": {"pattern": "foliage", "grain": 0.11, "bump": 1.35, "met": 0.00, "r_min": 0.65, "r_max": 0.88},
    "obsidian": {"pattern": "crystal", "grain": 0.10, "bump": 1.50, "met": 0.18, "r_min": 0.26, "r_max": 0.48},
}

COLOR_FAMILY = {
    "stone": "stone", "stoneDark": "stone", "stoneLight": "stone", "whiteStone": "stone", "whiteStoneDark": "stone",
    "slateRoof": "stone", "roof": "stone", "ink": "stone",
    "wood": "wood", "woodDark": "wood", "woodLight": "wood", "barkDark": "wood", "straw": "wood",
    "iron": "metal_forged", "ironDark": "metal_forged", "steel": "metal_forged",
    "bronze": "metal_gold", "brass": "metal_gold", "gold": "metal_gold", "goldBright": "metal_gold",
    "amber": "metal_gold", "amberBright": "metal_gold",
    "ice": "crystal", "iceLight": "crystal", "iceGlow": "crystal", "arcaneCyan": "crystal",
    "arcaneViolet": "crystal", "violet": "crystal",
    "obsidian": "obsidian", "obsidianLight": "obsidian",
    "neonAmber": "energy", "eyeNeon": "energy", "ember": "energy", "emberDeep": "energy", "tarGlow": "energy",
    "parchment": "cloth", "white": "cloth", "crimsonCloth": "cloth", "crimsonBright": "cloth", "royal": "cloth",
    "furBrown": "leather", "furTan": "leather", "hornIvory": "leather", "bone": "leather", "tarDeep": "leather",
    "danger": "leather", "catapult": "wood", "archer": "cloth", "archerDark": "cloth",
    "teal": "scales", "tealDark": "scales", "tealBrute": "scales", "tealBruteDark": "scales",
    "tealSwarm": "scales", "tealSwarmDark": "scales", "wyvernScale": "scales", "wyvernWing": "leather",
    "grass": "foliage", "moss": "foliage", "leafDeep": "foliage", "leafMid": "foliage", "leafSun": "foliage",
    "oliveLeaf": "foliage",
}


def load_pal_from_lowpoly_lib() -> dict[str, tuple[int, int, int]]:
    tree = ast.parse(LOWPOLY_LIB.read_text(encoding="utf-8"))
    for node in tree.body:
        if isinstance(node, ast.Assign):
            for target in node.targets:
                if isinstance(target, ast.Name) and target.id == "PAL":
                    return ast.literal_eval(node.value)
    raise RuntimeError("PAL dict nao encontrado em lowpoly_lib.py")


def save_rgba_png(path: pathlib.Path, rgba: np.ndarray) -> None:
    h, w, c = rgba.shape
    assert c == 4 and rgba.dtype == np.uint8
    raw = np.concatenate([np.zeros((h, 1), dtype=np.uint8), rgba.reshape(h, w * 4)], axis=1)
    compressed = zlib.compress(raw.tobytes(), level=6)

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", compressed) + chunk(b"IEND", b""))


def optimize_png(path: pathlib.Path) -> None:
    try:
        subprocess.run(["oxipng", "-o", "2", "-q", str(path)], check=False)
    except FileNotFoundError:
        pass


def _hash2(ix: np.ndarray, iy: np.ndarray, seed: int) -> np.ndarray:
    n = (ix.astype(np.int64) * 374761393 + iy.astype(np.int64) * 668265263 + seed * 1442695041) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    n = n ^ (n >> 16)
    return (n & 0xFFFF).astype(np.float32) / 65535.0


def periodic_noise(u: np.ndarray, v: np.ndarray, period: int, seed: int) -> np.ndarray:
    x = u * period
    y = v * period
    ix = np.floor(x).astype(np.int64) % period
    iy = np.floor(y).astype(np.int64) % period
    ix1 = (ix + 1) % period
    iy1 = (iy + 1) % period
    fx = x - np.floor(x)
    fy = y - np.floor(y)
    ux = fx * fx * (3.0 - 2.0 * fx)
    uy = fy * fy * (3.0 - 2.0 * fy)
    v00 = _hash2(ix, iy, seed)
    v10 = _hash2(ix1, iy, seed)
    v01 = _hash2(ix, iy1, seed)
    v11 = _hash2(ix1, iy1, seed)
    return (v00 * (1.0 - ux) + v10 * ux) * (1.0 - uy) + (v01 * (1.0 - ux) + v11 * ux) * uy


def periodic_fbm(u: np.ndarray, v: np.ndarray, base_period: int, seed: int, octaves: int = 4) -> np.ndarray:
    acc = np.zeros_like(u, dtype=np.float32)
    amp = 0.5
    norm = 0.0
    p = base_period
    for o in range(octaves):
        acc += amp * periodic_noise(u, v, p, seed + o * 131)
        norm += amp
        amp *= 0.5
        p *= 2
    return acc / max(norm, 1e-6)


def synthesize_height(u: np.ndarray, v: np.ndarray, pattern: str, seed: int) -> np.ndarray:
    n4 = periodic_fbm(u, v, 4, seed, 4)
    n12 = periodic_fbm(u, v, 12, seed + 17, 3)
    if pattern == "stone":
        mortar_x = np.abs(np.sin(u * math.pi * 4.0 + (n4 - 0.5) * 0.25)) ** 0.35
        mortar_y = np.abs(np.sin(v * math.pi * 4.0 + (n4 - 0.5) * 0.25)) ** 0.35
        blocks = np.minimum(mortar_x, mortar_y)
        return np.clip(0.35 * blocks + 0.45 * n4 + 0.20 * n12, 0.0, 1.0)
    if pattern == "wood":
        rings = 0.5 + 0.5 * np.sin((u * 6.0 + n4 * 1.8) * math.pi * 2.0)
        fibers = periodic_fbm(u * 2.0, v * 0.5, 8, seed + 29, 3)
        return np.clip(0.45 * rings + 0.35 * fibers + 0.20 * n12, 0.0, 1.0)
    if pattern in ("metal", "gold"):
        brushed = periodic_fbm(u * 1.5, v * 0.5, 10, seed + 41, 3)
        hammer = 0.5 + 0.5 * np.cos(u * math.pi * 8.0 + n4 * 1.5) * np.cos(v * math.pi * 8.0 - n4 * 1.5)
        return np.clip(0.45 * hammer + 0.35 * brushed + 0.20 * n12, 0.0, 1.0)
    if pattern == "crystal":
        facet_a = np.abs(np.sin((u * 4.0 + v * 3.0 + n4 * 0.7) * math.pi))
        facet_b = np.abs(np.cos((u * 3.0 - v * 4.0 - n4 * 0.7) * math.pi))
        return np.clip(0.55 * np.minimum(facet_a, facet_b) + 0.25 * n4 + 0.20 * n12, 0.0, 1.0)
    if pattern == "scales":
        row = np.floor(v * 6.0)
        su = u * 6.0 + 0.5 * (row % 2.0)
        sv = v * 6.0
        du = (su - np.floor(su)) - 0.5
        dv = (sv - np.floor(sv)) - 0.5
        dome = np.clip(1.0 - (du * du + dv * dv) * 3.2, 0.0, 1.0)
        return np.clip(0.65 * dome + 0.20 * n4 + 0.15 * n12, 0.0, 1.0)
    if pattern == "cloth":
        weave = 0.5 + 0.25 * np.sin(u * math.pi * 48.0) + 0.25 * np.sin(v * math.pi * 48.0)
        return np.clip(0.55 * weave + 0.30 * n4 + 0.15 * n12, 0.0, 1.0)
    if pattern == "leather":
        pores = np.clip(1.0 - np.abs(n12 - 0.5) * 3.2, 0.0, 1.0)
        return np.clip(0.55 * n4 + 0.25 * pores + 0.20 * n12, 0.0, 1.0)
    if pattern == "energy":
        swirl = 0.5 + 0.5 * np.sin((u * 3.0 + v * 3.0 + n4 * 2.0) * math.pi * 2.0)
        return np.clip(0.60 * swirl + 0.40 * n12, 0.0, 1.0)
    # foliage
    return np.clip(0.50 * n4 + 0.50 * n12, 0.0, 1.0)


def main() -> None:
    pal = load_pal_from_lowpoly_lib()
    names = list(pal.keys())
    assert len(names) <= 64

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    bc_atlas = np.zeros((ATLAS_SIZE, ATLAS_SIZE, 4), dtype=np.uint8)
    nm_atlas = np.zeros((ATLAS_SIZE, ATLAS_SIZE, 4), dtype=np.uint8)
    nm_atlas[..., 0] = 128
    nm_atlas[..., 1] = 128
    nm_atlas[..., 2] = 255
    nm_atlas[..., 3] = 255
    mt_atlas = np.zeros((ATLAS_SIZE, ATLAS_SIZE, 4), dtype=np.uint8)
    mt_atlas[..., 3] = 255
    rg_atlas = np.zeros((ATLAS_SIZE, ATLAS_SIZE, 4), dtype=np.uint8)
    rg_atlas[..., :3] = 200
    rg_atlas[..., 3] = 255

    lin = np.linspace(0.0, 1.0, CELL_SIZE, endpoint=False, dtype=np.float32)
    uu, vv = np.meshgrid(lin, lin)

    # Fade suave das normais/micro-relevo nas bordas de cada celula para zero bleed em mipmaps
    idx_px = np.arange(CELL_SIZE, dtype=np.float32)
    dist_edge = np.minimum(np.minimum(idx_px, CELL_SIZE - 1 - idx_px), BORDER_PAD) / float(BORDER_PAD)
    edge_mask = (dist_edge[:, None] * dist_edge[None, :]).astype(np.float32)

    for i, name in enumerate(names):
        r0, g0, b0 = pal[name]
        cx, cy = i % 8, i // 8
        x0, x1 = cx * CELL_SIZE, (cx + 1) * CELL_SIZE
        # Blender (0,0) = bottom-left -> PNG top-down row = (7 - cy)
        y0, y1 = (7 - cy) * CELL_SIZE, (8 - cy) * CELL_SIZE

        fam_key = COLOR_FAMILY.get(name, "stone")
        cfg = FAMILY_PARAMS[fam_key]
        h = synthesize_height(uu, vv, cfg["pattern"], 202611 + i * 73)

        # BaseColor: mantem matiz fiel ao GDD com micro-variacao de cavidade/grao
        mod = 1.0 + (h - 0.5) * 2.0 * cfg["grain"] * edge_mask
        bc_cell = np.empty((CELL_SIZE, CELL_SIZE, 4), dtype=np.uint8)
        bc_cell[..., 0] = np.clip(np.round(r0 * mod), 0, 255).astype(np.uint8)
        bc_cell[..., 1] = np.clip(np.round(g0 * mod), 0, 255).astype(np.uint8)
        bc_cell[..., 2] = np.clip(np.round(b0 * mod), 0, 255).astype(np.uint8)
        bc_cell[..., 3] = 255
        bc_atlas[y0:y1, x0:x1] = bc_cell

        # Normal map OpenGL tangent-space (+X right, +Y up)
        dh_dy, dh_dx = np.gradient(h * edge_mask)
        strength = cfg["bump"] * 12.0
        nx = -dh_dx * strength
        ny = dh_dy * strength  # top-down image: dy cresce para baixo, +Y OpenGL aponta para cima
        nz = np.ones_like(nx)
        inv_len = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz)
        nm_cell = np.empty((CELL_SIZE, CELL_SIZE, 4), dtype=np.uint8)
        nm_cell[..., 0] = np.clip(np.round((nx * inv_len * 0.5 + 0.5) * 255.0), 0, 255).astype(np.uint8)
        nm_cell[..., 1] = np.clip(np.round((ny * inv_len * 0.5 + 0.5) * 255.0), 0, 255).astype(np.uint8)
        nm_cell[..., 2] = np.clip(np.round((nz * inv_len * 0.5 + 0.5) * 255.0), 0, 255).astype(np.uint8)
        nm_cell[..., 3] = 255
        nm_atlas[y0:y1, x0:x1] = nm_cell

        # Metallic
        met_val = np.clip(cfg["met"] + (h - 0.5) * 0.06 * (1.0 if cfg["met"] > 0.1 else 0.0), 0.0, 1.0)
        met_u8 = np.clip(np.round(met_val * 255.0), 0, 255).astype(np.uint8)
        mt_atlas[y0:y1, x0:x1, :3] = met_u8[..., None]
        mt_atlas[y0:y1, x0:x1, 3] = 255

        # Roughness (cavidades ligeiramente mais asperas, cristas mais polidas)
        r_span = cfg["r_max"] - cfg["r_min"]
        rough_val = cfg["r_max"] - h * r_span
        rough_u8 = np.clip(np.round(rough_val * 255.0), 0, 255).astype(np.uint8)
        rg_atlas[y0:y1, x0:x1, :3] = rough_u8[..., None]
        rg_atlas[y0:y1, x0:x1, 3] = 255

    files = {
        "baseColor": (OUT_DIR / "pbr_palette_baseColor.png", bc_atlas),
        "normal": (OUT_DIR / "pbr_palette_normal.png", nm_atlas),
        "metallic": (OUT_DIR / "pbr_palette_metallic.png", mt_atlas),
        "roughness": (OUT_DIR / "pbr_palette_roughness.png", rg_atlas),
    }
    report = {"colors": len(names), "size": ATLAS_SIZE, "files": {}}
    for key, (path, arr) in files.items():
        save_rgba_png(path, arr)
        optimize_png(path)
        report["files"][key] = {"path": str(path.relative_to(ROOT)), "bytes": path.stat().st_size}
    bl_px = bc_atlas[ATLAS_SIZE - 16, 16, :3].tolist()
    report["bottom_left_stone_sample"] = bl_px
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
