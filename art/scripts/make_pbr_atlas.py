#!/usr/bin/env python3
"""Gera o Atlas Mestre PBR 2048x2048 AA (grade 8x8, celulas 256x256) alinhado a `lowpoly_lib.PAL`.

Saidas em `art/renders/pbr_atlas/`:
- `pbr_palette_baseColor.png` (sRGB RGBA com cavidade AO, veios, chanfros e micro-grao)
- `pbr_palette_normal.png`    (Tangent-space OpenGL normal map, borda neutra anti-bleed)
- `pbr_palette_metallic.png`  (Grayscale RGBA com micro-desgaste de borda)
- `pbr_palette_roughness.png` (Grayscale RGBA com contraste cavidade/crista/glint)

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
    "stone": {"pattern": "stone", "grain": 0.14, "bump": 2.15, "met": 0.00, "r_min": 0.68, "r_max": 0.95},
    "wood": {"pattern": "wood", "grain": 0.14, "bump": 1.85, "met": 0.00, "r_min": 0.56, "r_max": 0.88},
    "metal_forged": {"pattern": "metal", "grain": 0.12, "bump": 1.55, "met": 0.90, "r_min": 0.24, "r_max": 0.56},
    "metal_gold": {"pattern": "gold", "grain": 0.11, "bump": 1.35, "met": 0.96, "r_min": 0.16, "r_max": 0.44},
    "crystal": {"pattern": "crystal", "grain": 0.15, "bump": 1.95, "met": 0.08, "r_min": 0.10, "r_max": 0.38},
    "energy": {"pattern": "energy", "grain": 0.12, "bump": 1.05, "met": 0.00, "r_min": 0.12, "r_max": 0.36},
    "cloth": {"pattern": "cloth", "grain": 0.11, "bump": 1.30, "met": 0.00, "r_min": 0.66, "r_max": 0.90},
    "leather": {"pattern": "leather", "grain": 0.12, "bump": 1.50, "met": 0.00, "r_min": 0.46, "r_max": 0.78},
    "scales": {"pattern": "scales", "grain": 0.15, "bump": 2.10, "met": 0.08, "r_min": 0.30, "r_max": 0.68},
    "foliage": {"pattern": "foliage", "grain": 0.14, "bump": 1.70, "met": 0.00, "r_min": 0.58, "r_max": 0.88},
    "obsidian": {"pattern": "obsidian", "grain": 0.15, "bump": 2.05, "met": 0.22, "r_min": 0.18, "r_max": 0.50},
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


def smoothstep(e0: float, e1: float, x: np.ndarray | float) -> np.ndarray:
    t = np.clip((x - e0) / (e1 - e0 + 1e-9), 0.0, 1.0)
    return (t * t * (3.0 - 2.0 * t)).astype(np.float32)


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


def periodic_voronoi(
    u: np.ndarray,
    v: np.ndarray,
    period: int,
    seed: int,
    jitter: float = 0.82,
    aniso_x: float = 1.0,
    aniso_y: float = 1.0,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """Retorna (f1, f2, border_dist = f2 - f1, cell_hash) periodicos em [0, 1]^2."""
    x = u * period
    y = v * period
    ix = np.floor(x).astype(np.int64)
    iy = np.floor(y).astype(np.int64)
    fx = x - ix
    fy = y - iy

    f1 = np.full_like(u, 1e9, dtype=np.float32)
    f2 = np.full_like(u, 1e9, dtype=np.float32)
    cell_id = np.zeros_like(u, dtype=np.float32)

    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            nx = (ix + dx) % period
            ny = (iy + dy) % period
            jx = (_hash2(nx, ny, seed) - 0.5) * jitter
            jy = (_hash2(nx, ny, seed + 59) - 0.5) * jitter
            cid = _hash2(nx, ny, seed + 113)
            ox = (dx + 0.5 + jx - fx) * aniso_x
            oy = (dy + 0.5 + jy - fy) * aniso_y
            d = np.sqrt(ox * ox + oy * oy)
            closer = d < f1
            f2 = np.where(closer, f1, np.minimum(f2, d))
            f1 = np.where(closer, d, f1)
            cell_id = np.where(closer, cid, cell_id)

    border = np.clip(f2 - f1, 0.0, 1.0)
    return f1, f2, border, cell_id


def synthesize_surface(
    u: np.ndarray,
    v: np.ndarray,
    pattern: str,
    seed: int,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """Sintetiza (height, ao, glint, wear) em [0, 1] para cada familia de material AA."""
    n4 = periodic_fbm(u, v, 4, seed, 4)
    n8 = periodic_fbm(u, v, 8, seed + 19, 4)
    n16 = periodic_fbm(u, v, 16, seed + 37, 3)

    if pattern == "stone":
        # Periodic Voronoi cellular ashlar masonry + mortar cracks + cavity AO
        courses_y = 4.0
        row = np.floor(v * courses_y)
        stagger = (row % 2.0) * 0.5
        uw = (u + stagger + (n4 - 0.5) * 0.05) % 1.0
        vw = (v + (n8 - 0.5) * 0.035) % 1.0

        gx = np.abs(((uw * 3.0) % 1.0) - 0.5) * 2.0
        gy = np.abs(((vw * courses_y) % 1.0) - 0.5) * 2.0
        ashlar_edge = np.minimum(1.0 - gx, 1.0 - gy)
        ashlar_mortar = smoothstep(0.03, 0.14, ashlar_edge)

        _f1, _f2, v_border, v_cid = periodic_voronoi(u + (n4 - 0.5) * 0.06, v + (n4 - 0.5) * 0.06, 5, seed + 71, 0.78)
        voronoi_mortar = smoothstep(0.02, 0.13, v_border)
        fine_cracks = smoothstep(0.008, 0.045, periodic_voronoi(u, v, 9, seed + 149, 0.90)[2])

        block_var = 0.82 + 0.18 * v_cid
        blocks = np.minimum(ashlar_mortar, 0.35 + 0.65 * voronoi_mortar) * (0.75 + 0.25 * fine_cracks)
        height = np.clip(blocks * (0.58 * block_var + 0.27 * n8 + 0.15 * n16), 0.0, 1.0)
        ao = np.clip(0.50 + 0.50 * blocks * fine_cracks, 0.35, 1.0)
        bevel_ridge = smoothstep(0.10, 0.20, v_border) * (1.0 - smoothstep(0.20, 0.34, v_border))
        glint = np.clip(bevel_ridge * 0.35, 0.0, 1.0)
        wear = np.clip(bevel_ridge * 0.55 + (height - 0.6) * 0.4, 0.0, 1.0)
        return height, ao, glint, wear

    if pattern == "scales":
        # Periodic Voronoi curved overlapping scales + central keel ridge + under-scale AO
        rows = 6.0
        cols = 6.0
        sv = v * rows
        row_idx = np.floor(sv)
        su = u * cols + (row_idx % 2.0) * 0.5 + (n4 - 0.5) * 0.12
        fu = (su - np.floor(su)) - 0.5
        fv = sv - row_idx  # 0 at top of cell, 1 at bottom tip

        # Overlapping curved shield profile
        arch = fv - 0.55 * (fu * fu)
        in_scale = smoothstep(0.02, 0.14, arch) * (1.0 - smoothstep(0.84, 0.98, arch))
        rim_overlap = smoothstep(0.72, 0.88, arch) * (1.0 - smoothstep(0.88, 0.99, arch))
        keel = np.exp(-((fu * 3.6) ** 2)) * smoothstep(0.15, 0.75, fv) * 0.28
        dome = np.clip(1.0 - (fu * fu * 2.2 + ((fv - 0.45) ** 2) * 1.6), 0.0, 1.0)

        vf1, _vf2, v_edge, v_cid = periodic_voronoi(u, v, 6, seed + 83, 0.45)
        voronoi_curve = smoothstep(0.03, 0.18, v_edge) * (1.0 - 0.35 * vf1)

        height = np.clip(
            (0.52 * dome + keel + 0.24 * voronoi_curve + 0.14 * n16 + 0.10 * v_cid) * in_scale,
            0.0,
            1.0,
        )
        ao = np.clip(0.38 + 0.62 * in_scale * smoothstep(0.02, 0.15, v_edge), 0.32, 1.0)
        glint = np.clip(rim_overlap * 0.65 + keel * 0.85, 0.0, 1.0)
        wear = np.clip(glint * 0.7, 0.0, 1.0)
        return height, ao, glint, wear

    if pattern in ("crystal", "obsidian"):
        # Sharp crystalline facets + bevel glint
        f1_a, f2_a, edge_a, cid_a = periodic_voronoi(u, v, 5, seed + 97, 0.88)
        f1_b, _f2_b, edge_b, cid_b = periodic_voronoi(u, v, 10, seed + 193, 0.85)

        bevel_a = smoothstep(0.015, 0.09, edge_a)
        bevel_b = smoothstep(0.015, 0.08, edge_b)
        # Planar tilted facet interior
        tilt_angle = cid_a * math.pi * 2.0
        cleavage = 0.5 + 0.35 * np.cos((u * np.cos(tilt_angle) + v * np.sin(tilt_angle)) * math.pi * 6.0 + cid_b * 3.0)
        ridge_peak = 1.0 - np.clip(f1_a * 0.95, 0.0, 1.0)

        height = np.clip(
            bevel_a * (0.48 * ridge_peak + 0.32 * cleavage + 0.20 * bevel_b * (1.0 - f1_b)),
            0.0,
            1.0,
        )
        # Razor bevel glint along facet ridges
        ridge_glint = smoothstep(0.02, 0.07, edge_a) * (1.0 - smoothstep(0.07, 0.16, edge_a))
        sub_glint = smoothstep(0.02, 0.06, edge_b) * (1.0 - smoothstep(0.06, 0.13, edge_b))
        glint = np.clip(ridge_glint * 0.95 + sub_glint * 0.45 + smoothstep(0.75, 0.95, height) * 0.35, 0.0, 1.0)
        ao = np.clip(0.45 + 0.55 * bevel_a * (0.7 + 0.3 * bevel_b), 0.40, 1.0)
        wear = glint
        return height, ao, glint, wear

    if pattern == "wood":
        # Planked timber seams + knot rings + grain fibers
        planks = 4.0
        pu = u * planks
        plank_id = np.floor(pu) % planks
        plank_frac = np.abs((pu - np.floor(pu)) - 0.5) * 2.0
        plank_seam = smoothstep(0.94, 0.82, plank_frac)

        butt_joint_v = ((v + plank_id * 0.37) % 1.0)
        butt_dist = np.minimum(butt_joint_v, 1.0 - butt_joint_v)
        butt_seam = smoothstep(0.008, 0.028, butt_dist)
        seam_mask = plank_seam * (0.35 + 0.65 * butt_seam)

        # Elliptical knot distortion
        kx = 0.35 + 0.30 * (plank_id / planks)
        ky = (0.48 + 0.25 * np.sin(plank_id * 2.1)) % 1.0
        dx = (u - kx) * 5.5
        dy = (v - ky) * 2.2
        knot_r = np.sqrt(dx * dx + dy * dy)
        knot_push = 0.28 * np.exp(-knot_r * knot_r * 2.8)
        knot_core = np.exp(-knot_r * knot_r * 6.5)

        ring_phase = (u * 10.0 + knot_push * 5.0 + n4 * 1.6 + plank_id * 0.7) * math.pi * 2.0
        rings = 0.5 + 0.5 * np.sin(ring_phase)
        rings = rings ** 0.75
        fibers = periodic_fbm(u * 4.0, v * 0.5, 16, seed + 29, 3)

        height = np.clip(seam_mask * (0.44 * rings + 0.34 * fibers + 0.14 * n16 + 0.08 * (1.0 - knot_core)), 0.0, 1.0)
        ao = np.clip(0.35 + 0.65 * seam_mask * (1.0 - 0.25 * knot_core), 0.30, 1.0)
        glint = np.clip(smoothstep(0.72, 0.92, rings) * 0.22 * seam_mask, 0.0, 1.0)
        wear = np.clip((1.0 - plank_seam) * 0.35 + glint, 0.0, 1.0)
        return height, ao, glint, wear

    if pattern in ("metal", "gold"):
        # Anisotropic brush streaks + hammer micro-dents + edge wear
        brush_u = periodic_fbm(u * 3.0, v * 0.5, 16, seed + 41, 4)
        brush_diag = periodic_fbm((u + v * 0.25) * 2.0, (v - u * 0.25) * 0.5, 12, seed + 53, 3)
        brushed = 0.65 * brush_u + 0.35 * brush_diag

        f1_dent, _f2_dent, edge_dent, _cid_dent = periodic_voronoi(u, v, 7, seed + 109, 0.75)
        hammer_dents = smoothstep(0.0, 0.62, f1_dent)
        dent_rim = smoothstep(0.02, 0.12, edge_dent) * (1.0 - smoothstep(0.12, 0.26, edge_dent))

        scratches = smoothstep(0.46, 0.50, np.abs(n16 - 0.5) * 2.0)
        height = np.clip(0.42 * hammer_dents + 0.36 * brushed + 0.14 * dent_rim + 0.08 * (1.0 - scratches), 0.0, 1.0)
        wear = np.clip(dent_rim * 0.75 + smoothstep(0.68, 0.88, brushed) * 0.45 + scratches * 0.40, 0.0, 1.0)
        glint = np.clip(wear * (0.85 if pattern == "gold" else 0.65), 0.0, 1.0)
        ao = np.clip(0.62 + 0.38 * hammer_dents, 0.55, 1.0)
        return height, ao, glint, wear

    if pattern == "cloth":
        # Cross-hatch twill weave + micro-thread relief + soft folds
        freq = 32.0
        tu = u * freq * math.pi * 2.0
        tv = v * freq * math.pi * 2.0
        warp = 0.5 + 0.5 * np.sin(tu + 0.35 * np.sin(tv))
        weft = 0.5 + 0.5 * np.sin(tv + 0.35 * np.sin(tu))
        twill_diag = 0.5 + 0.5 * np.cos((u + v) * freq * math.pi)
        weave = np.where(twill_diag > 0.5, warp * 0.75 + weft * 0.25, weft * 0.75 + warp * 0.25)
        folds = 0.5 + 0.5 * np.sin((u * 2.0 - v * 1.0 + n4 * 0.6) * math.pi * 2.0)

        height = np.clip(0.55 * weave + 0.28 * folds + 0.17 * n16, 0.0, 1.0)
        ao = np.clip(0.65 + 0.35 * weave, 0.60, 1.0)
        glint = np.clip(smoothstep(0.78, 0.96, weave) * 0.18, 0.0, 1.0)
        wear = glint
        return height, ao, glint, wear

    if pattern == "leather":
        # Periodic Voronoi grainy pebble pores + creases
        f1_p, _f2_p, edge_p, cid_p = periodic_voronoi(u, v, 12, seed + 127, 0.85)
        pebble = np.clip(1.0 - f1_p * 1.25, 0.0, 1.0)
        creases = smoothstep(0.015, 0.09, edge_p)
        stipple = smoothstep(0.22, 0.55, n16)

        height = np.clip(creases * (0.48 * pebble + 0.32 * n8 + 0.20 * stipple * (0.8 + 0.2 * cid_p)), 0.0, 1.0)
        ao = np.clip(0.48 + 0.52 * creases * stipple, 0.42, 1.0)
        glint = np.clip(smoothstep(0.65, 0.90, pebble) * creases * 0.32, 0.0, 1.0)
        wear = np.clip(glint + smoothstep(0.68, 0.88, n4) * 0.25, 0.0, 1.0)
        return height, ao, glint, wear

    if pattern == "energy":
        # Luminous plasma filaments + Voronoi energy cells
        _f1_e, _f2_e, edge_e, _cid_e = periodic_voronoi(u + (n4 - 0.5) * 0.15, v - (n4 - 0.5) * 0.15, 5, seed + 163, 0.85)
        filament = 1.0 - smoothstep(0.0, 0.18, edge_e)
        swirl = 0.5 + 0.5 * np.sin((u * 3.0 + v * 3.0 + n4 * 2.2) * math.pi * 2.0)
        height = np.clip(0.50 * swirl + 0.35 * filament + 0.15 * n16, 0.0, 1.0)
        ao = np.ones_like(height)
        glint = np.clip(filament * 0.85 + smoothstep(0.65, 0.95, swirl) * 0.45, 0.0, 1.0)
        wear = glint
        return height, ao, glint, wear

    # foliage: layered leaf veins (midrib + branching secondary veins + cellular blade)
    leaf_u = ((u * 2.0) % 1.0) - 0.5
    leaf_v = (v * 2.0) % 1.0
    midrib = np.exp(-((leaf_u * 14.0) ** 2))
    sec_phase = (leaf_v * 6.0 - np.abs(leaf_u) * 5.0 + (n8 - 0.5) * 0.45) * math.pi * 2.0
    sec_vein = (np.maximum(0.0, np.cos(sec_phase)) ** 8.0) * smoothstep(0.48, 0.04, np.abs(leaf_u))
    _f1_f, _f2_f, edge_f, _cid_f = periodic_voronoi(u, v, 14, seed + 181, 0.80)
    micro_vein = 1.0 - smoothstep(0.01, 0.07, edge_f)

    veins = np.clip(0.55 * midrib + 0.45 * sec_vein + 0.25 * micro_vein, 0.0, 1.0)
    height = np.clip(0.45 * veins + 0.35 * n8 + 0.20 * n16, 0.0, 1.0)
    ao = np.clip(0.58 + 0.42 * (1.0 - 0.35 * micro_vein), 0.50, 1.0)
    glint = np.clip(veins * 0.35, 0.0, 1.0)
    wear = glint
    return height, ao, glint, wear


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
        h, ao, glint, wear = synthesize_surface(uu, vv, cfg["pattern"], 202611 + i * 73)

        # BaseColor: preserva matiz fiel ao GDD com micro-relevo, AO de cavidade e glint especular de chanfro
        ao_term = (ao - 1.0) * 0.28
        grain_term = (h - 0.5) * 2.0 * cfg["grain"]
        mod = 1.0 + (grain_term + ao_term) * edge_mask
        spec_lift = glint * 18.0 * edge_mask

        bc_cell = np.empty((CELL_SIZE, CELL_SIZE, 4), dtype=np.uint8)
        bc_cell[..., 0] = np.clip(np.round(r0 * mod + spec_lift), 0, 255).astype(np.uint8)
        bc_cell[..., 1] = np.clip(np.round(g0 * mod + spec_lift), 0, 255).astype(np.uint8)
        bc_cell[..., 2] = np.clip(np.round(b0 * mod + spec_lift), 0, 255).astype(np.uint8)
        bc_cell[..., 3] = 255
        bc_atlas[y0:y1, x0:x1] = bc_cell

        # Normal map OpenGL tangent-space (+X right, +Y up) com borda neutra (128, 128, 255)
        h_masked = (h - 0.5) * edge_mask
        dh_dy, dh_dx = np.gradient(h_masked)
        strength = cfg["bump"] * 13.5
        nx = -dh_dx * strength * edge_mask
        ny = dh_dy * strength * edge_mask  # top-down image: dy cresce para baixo, +Y OpenGL aponta para cima
        nz = np.ones_like(nx)
        inv_len = 1.0 / np.sqrt(nx * nx + ny * ny + nz * nz)
        nm_cell = np.empty((CELL_SIZE, CELL_SIZE, 4), dtype=np.uint8)
        nm_cell[..., 0] = np.clip(np.round((nx * inv_len * 0.5 + 0.5) * 255.0), 0, 255).astype(np.uint8)
        nm_cell[..., 1] = np.clip(np.round((ny * inv_len * 0.5 + 0.5) * 255.0), 0, 255).astype(np.uint8)
        nm_cell[..., 2] = np.clip(np.round((nz * inv_len * 0.5 + 0.5) * 255.0), 0, 255).astype(np.uint8)
        nm_cell[..., 3] = 255
        nm_atlas[y0:y1, x0:x1] = nm_cell

        # Metallic com realce em bordas desgastadas/facetas
        is_metal = 1.0 if cfg["met"] > 0.05 else 0.0
        met_val = np.clip(
            cfg["met"] + ((h - 0.5) * 0.06 + wear * 0.08) * is_metal * edge_mask,
            0.0,
            1.0,
        )
        met_u8 = np.clip(np.round(met_val * 255.0), 0, 255).astype(np.uint8)
        mt_atlas[y0:y1, x0:x1, :3] = met_u8[..., None]
        mt_atlas[y0:y1, x0:x1, 3] = 255

        # Roughness (cavidades/argamassa mais asperas, cristas/facetas/glint mais polidas)
        r_span = cfg["r_max"] - cfg["r_min"]
        rough_base = cfg["r_max"] - (0.65 * h + 0.35 * glint) * r_span + (1.0 - ao) * 0.12
        rough_val = np.clip(rough_base, cfg["r_min"], cfg["r_max"])
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
