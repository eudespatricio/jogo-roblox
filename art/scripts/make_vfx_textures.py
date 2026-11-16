#!/usr/bin/env python3
"""Gera 9 texturas RGBA anti-aliased de VFX (4 flipbooks 4x4 1024x1024 + 5 mapas) para Open Cloud.

Saidas em `art/renders/vfx/` (ignoradas no git, publicadas via Open Cloud em `VfxAssets.luau`).
"""

from __future__ import annotations

import json
import math
import pathlib
import struct
import subprocess
import zlib

import numpy as np

ROOT = pathlib.Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "art" / "renders" / "vfx"


def save_rgba_png(path: pathlib.Path, rgba: np.ndarray) -> None:
    h, w, c = rgba.shape
    assert c == 4 and rgba.dtype == np.uint8
    raw = np.concatenate([np.zeros((h, 1), dtype=np.uint8), rgba.reshape(h, w * 4)], axis=1)
    compressed = zlib.compress(raw.tobytes(), level=9)

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", compressed) + chunk(b"IEND", b"")
    path.write_bytes(png)


def optimize_png(path: pathlib.Path) -> None:
    try:
        subprocess.run(["oxipng", "-o", "3", "-q", str(path)], check=False)
    except FileNotFoundError:
        pass


def smoothstep(e0: float, e1: float, x: np.ndarray | float) -> np.ndarray | float:
    t = np.clip((x - e0) / (e1 - e0 + 1e-9), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def _hash2(ix: np.ndarray, iy: np.ndarray, seed: int) -> np.ndarray:
    n = (ix.astype(np.int64) * 374761393 + iy.astype(np.int64) * 668265263 + seed * 1442695041) & 0xFFFFFFFF
    n = (n ^ (n >> 13)) * 1274126177 & 0xFFFFFFFF
    n = n ^ (n >> 16)
    return (n & 0xFFFF).astype(np.float32) / 65535.0


def value_noise(x: np.ndarray, y: np.ndarray, seed: int, period: int | None = None) -> np.ndarray:
    ix = np.floor(x).astype(np.int64)
    iy = np.floor(y).astype(np.int64)
    fx = x - ix
    fy = y - iy
    ux = fx * fx * (3.0 - 2.0 * fx)
    uy = fy * fy * (3.0 - 2.0 * fy)
    ix1 = ix + 1
    iy1 = iy + 1
    if period is not None:
        ix = np.mod(ix, period)
        ix1 = np.mod(ix1, period)
    v00 = _hash2(ix, iy, seed)
    v10 = _hash2(ix1, iy, seed)
    v01 = _hash2(ix, iy1, seed)
    v11 = _hash2(ix1, iy1, seed)
    return (v00 * (1.0 - ux) + v10 * ux) * (1.0 - uy) + (v01 * (1.0 - ux) + v11 * ux) * uy


def fbm(x: np.ndarray, y: np.ndarray, seed: int, octaves: int = 4, period: int | None = None) -> np.ndarray:
    acc = np.zeros_like(x, dtype=np.float32)
    amp = 0.5
    norm = 0.0
    freq = 1.0
    for o in range(octaves):
        p = int(period * freq) if period is not None else None
        acc += amp * value_noise(x * freq, y * freq, seed + o * 97, period=p)
        norm += amp
        amp *= 0.5
        freq *= 2.0
    return acc / max(norm, 1e-6)


def grid_coords(n: int) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    lin = np.linspace(-1.0, 1.0, n, dtype=np.float32)
    xx, yy = np.meshgrid(lin, lin)
    rr = np.sqrt(xx * xx + yy * yy)
    ang = np.arctan2(yy, xx)
    return xx, yy, rr, ang


def to_rgba_uint8(rgb: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    rgb_c = np.clip(rgb, 0.0, 1.0)
    a_c = np.clip(alpha, 0.0, 1.0)
    out = np.empty(rgb_c.shape[:2] + (4,), dtype=np.uint8)
    out[..., :3] = np.round(rgb_c * 255.0).astype(np.uint8)
    out[..., 3] = np.round(a_c * 255.0).astype(np.uint8)
    return out


def render_flipbook(tile_fn, size: int = 1024) -> np.ndarray:
    tile = size // 4
    atlas = np.zeros((size, size, 4), dtype=np.uint8)
    xx, yy, rr, ang = grid_coords(tile)
    cell_mask = smoothstep(0.95, 0.78, rr)
    for f in range(16):
        r, c = divmod(f, 4)
        rgb, a = tile_fn(f, f / 15.0, xx, yy, rr, ang)
        atlas[r * tile : (r + 1) * tile, c * tile : (c + 1) * tile] = to_rgba_uint8(rgb, a * cell_mask)
    return atlas


def tile_explosion(f: int, t: float, x: np.ndarray, y: np.ndarray, r: np.ndarray, ang: np.ndarray):
    warp_x = fbm(x * 2.6 + t * 1.1, y * 2.6 - t * 0.7, 101, 4) - 0.5
    warp_y = fbm(x * 2.6 - t * 0.6, y * 2.6 + t * 1.2, 202, 4) - 0.5
    n_core = fbm((x + warp_x * 0.45) * 3.8, (y + warp_y * 0.45 - t * 0.4) * 3.8, 303 + f * 3, 4)
    r_w = r + (n_core - 0.5) * (0.28 + 0.25 * t)

    radius = 0.24 + 0.64 * (t ** 0.55)
    body = smoothstep(radius + 0.14, radius * 0.45, r_w)
    smoke_fade = 1.0 - 0.85 * smoothstep(0.55, 1.0, t)
    flash = math.exp(-((t / 0.16) ** 2)) * np.exp(-r * r * 10.0)

    heat = np.clip((1.0 - r_w / (radius + 1e-4)) * 0.9 + n_core * 0.55 - t * 0.72, 0.0, 1.0)
    # Paleta quente pyroclastica: soot -> danger (#E4572E) -> amber (#F59E0B) -> white-gold
    c_soot = np.array([0.18, 0.14, 0.14], dtype=np.float32)
    c_red = np.array([0.92, 0.30, 0.12], dtype=np.float32)
    c_amb = np.array([1.00, 0.74, 0.20], dtype=np.float32)
    c_hot = np.array([1.00, 0.98, 0.88], dtype=np.float32)

    rgb = np.where(heat[..., None] < 0.35, c_soot + (c_red - c_soot) * (heat[..., None] / 0.35), c_red)
    mid = np.clip((heat - 0.35) / 0.35, 0.0, 1.0)[..., None]
    rgb = np.where((heat >= 0.35)[..., None], c_red + (c_amb - c_red) * mid, rgb)
    hi = np.clip((heat - 0.70) / 0.30, 0.0, 1.0)[..., None]
    rgb = np.where((heat >= 0.70)[..., None], c_amb + (c_hot - c_amb) * hi, rgb)
    rgb = np.clip(rgb + flash[..., None] * c_hot, 0.0, 1.0)

    # Faiscas orbitais nos frames 2..13
    sparks = np.zeros_like(r)
    rng = np.random.default_rng(7700)
    for k in range(14):
        sa = rng.uniform(-math.pi, math.pi)
        sr = (0.14 + 0.72 * t) * rng.uniform(0.75, 1.15)
        sx, sy = sr * math.cos(sa), sr * math.sin(sa)
        d2 = (x - sx) ** 2 + (y - sy) ** 2
        sparks += np.exp(-d2 * 520.0) * smoothstep(0.05, 0.2, t) * smoothstep(1.0, 0.6, t)
    rgb = np.clip(rgb + sparks[..., None] * c_hot, 0.0, 1.0)
    alpha = np.clip(np.maximum(body * smoke_fade, np.maximum(flash, sparks * 0.9)), 0.0, 1.0)
    return rgb, alpha


def tile_frost(f: int, t: float, x: np.ndarray, y: np.ndarray, r: np.ndarray, ang: np.ndarray):
    n = fbm(x * 4.5, y * 4.5, 505, 4)
    # 6 pontas hexagonais + 6 secundarias
    hex_arm = np.abs(np.cos(ang * 3.0 + n * 0.25)) ** 10.0
    sub_arm = np.abs(np.cos(ang * 6.0 + 0.5)) ** 18.0
    reach = 0.22 + 0.68 * (t ** 0.52)

    star = np.exp(-r * 6.5 / max(reach, 0.2)) * (0.45 + 0.75 * hex_arm + 0.35 * sub_arm)
    # Estilhacos discretos que se expandem
    shards = np.zeros_like(r)
    for k in range(8):
        ka = k * (math.pi / 4.0) + (0.18 if k % 2 else -0.1)
        ca, sa = math.cos(ka), math.sin(ka)
        dist_r = 0.10 + 0.65 * (t ** 0.7)
        px = x - ca * dist_r
        py = y - sa * dist_r
        along = px * ca + py * sa
        perp = -px * sa + py * ca
        diamond = np.abs(along) * 1.1 + np.abs(perp) * 3.0
        shards += smoothstep(0.11, 0.03, diamond) * smoothstep(0.05, 0.18, t) * smoothstep(1.0, 0.65, t)

    ring = np.exp(-((r - reach * 0.85) ** 2) * 140.0) * smoothstep(0.0, 0.25, t) * (1.0 - t)
    mist = smoothstep(reach + 0.12, 0.12, r + (n - 0.5) * 0.22) * (0.35 * n) * (1.0 - 0.75 * t)

    c_deep = np.array([0.20, 0.56, 0.95], dtype=np.float32)
    c_ice = np.array([0.74, 0.93, 1.00], dtype=np.float32)
    c_white = np.array([0.96, 0.99, 1.00], dtype=np.float32)

    lum = np.clip(star + shards * 1.1 + ring * 0.9, 0.0, 1.0)
    rgb = c_deep + (c_ice - c_deep) * np.clip(lum * 1.2, 0.0, 1.0)[..., None]
    rgb = np.where((lum > 0.65)[..., None], rgb + (c_white - rgb) * ((lum - 0.65) / 0.35)[..., None], rgb)
    alpha = np.clip(np.maximum(star, np.maximum(shards, np.maximum(ring, mist))) * 1.25 * (1.0 - 0.65 * smoothstep(0.65, 1.0, t)), 0.0, 1.0)
    return rgb, alpha


def tile_arcane(f: int, t: float, x: np.ndarray, y: np.ndarray, r: np.ndarray, ang: np.ndarray):
    spin = t * math.pi * 2.2
    n = fbm(x * 3.5 + t, y * 3.5 - t, 808, 4)
    spiral = 0.5 + 0.5 * np.cos(3.0 * ang - r * 9.5 + spin + (n - 0.5) * 2.4)
    spiral = (spiral ** 3.0) * smoothstep(0.88, 0.15, r)

    rune_r = 0.42 + 0.26 * math.sin(t * math.pi)
    rune_ring = np.exp(-((r - rune_r) ** 2) * 260.0) * (0.45 + 0.55 * (np.cos(ang * 8.0 - spin * 1.5) > 0.0))
    core = np.exp(-r * r * 18.0) * (0.7 + 0.3 * math.sin(t * math.pi))

    envelope = smoothstep(0.0, 0.18, t) * smoothstep(1.0, 0.72, t) + 0.35 * math.exp(-t * 5.0)
    envelope = min(1.0, envelope)

    c_violet = np.array([0.66, 0.33, 0.97], dtype=np.float32)
    c_teal = np.array([0.08, 0.80, 0.78], dtype=np.float32)
    c_cyan = np.array([0.86, 1.00, 0.96], dtype=np.float32)

    mix_v = np.clip(r * 1.15, 0.0, 1.0)[..., None]
    rgb = c_teal * (1.0 - mix_v) + c_violet * mix_v
    hi = np.clip(core + rune_ring * 0.8 + spiral * 0.5, 0.0, 1.0)[..., None]
    rgb = rgb * (1.0 - hi * 0.75) + c_cyan * (hi * 0.75)
    alpha = np.clip((spiral * 0.75 + rune_ring * 0.95 + core) * envelope, 0.0, 1.0)
    return rgb, alpha


def tile_slash(f: int, t: float, x: np.ndarray, y: np.ndarray, r: np.ndarray, ang: np.ndarray):
    head_ang = -2.1 + 3.8 * (t ** 0.72)
    diff = np.arctan2(np.sin(ang - head_ang), np.cos(ang - head_ang))
    trail = smoothstep(-2.0, -0.05, diff) * smoothstep(0.32, 0.0, diff)
    arc_r = 0.58 + 0.12 * t
    thickness = 0.11 * smoothstep(-2.0, 0.0, diff) + 0.015
    arc = np.exp(-(((r - arc_r) / thickness) ** 2)) * trail

    sparks = np.zeros_like(r)
    rng = np.random.default_rng(9100)
    for _ in range(12):
        sa = rng.uniform(-1.8, 1.4) + 0.5 * t
        sr = 0.45 + 0.42 * t * rng.uniform(0.7, 1.1)
        sx, sy = sr * math.cos(sa), sr * math.sin(sa)
        sparks += np.exp(-((x - sx) ** 2 + (y - sy) ** 2) * 420.0)

    fade = smoothstep(1.0, 0.62, t)
    c_gold = np.array([1.00, 0.80, 0.25], dtype=np.float32)
    c_white = np.array([1.00, 0.99, 0.94], dtype=np.float32)
    intensity = np.clip(arc + sparks * 0.9, 0.0, 1.0)
    rgb = c_gold + (c_white - c_gold) * (intensity ** 1.4)[..., None]
    return rgb, np.clip(intensity * fade, 0.0, 1.0)


def make_shockwave_ring(size: int = 512) -> np.ndarray:
    x, y, r, ang = grid_coords(size)
    n = fbm(x * 5.0, y * 5.0, 1111, 3)
    outer = np.exp(-((r - 0.72) ** 2) / (0.062 ** 2))
    inner = 0.62 * np.exp(-((r - 0.46) ** 2) / (0.048 ** 2))
    ticks = np.exp(-((r - 0.72) ** 2) / (0.11 ** 2)) * (np.maximum(0.0, np.cos(ang * 12.0)) ** 10.0) * 0.45
    alpha = (outer + inner + ticks) * (0.85 + 0.15 * n) * smoothstep(0.96, 0.84, r)
    rgb = np.ones((size, size, 3), dtype=np.float32)
    return to_rgba_uint8(rgb, alpha)


def make_soft_glow_flare(size: int = 512) -> np.ndarray:
    x, y, r, _ = grid_coords(size)
    core = np.exp(-r * r * 8.5)
    halo = 0.42 * np.exp(-r * r * 2.8)
    star_x = np.exp(-np.abs(y) * 26.0) * np.exp(-np.abs(x) * 3.8)
    star_y = np.exp(-np.abs(x) * 26.0) * np.exp(-np.abs(y) * 3.8)
    alpha = (core + halo + 0.55 * (star_x + star_y)) * smoothstep(0.98, 0.72, r)
    rgb = np.ones((size, size, 3), dtype=np.float32)
    return to_rgba_uint8(rgb, alpha)


def make_smoke_wispy(size: int = 512) -> np.ndarray:
    x, y, r, _ = grid_coords(size)
    wx = fbm(x * 2.5, y * 2.5, 2222, 4) - 0.5
    wy = fbm(x * 2.5 + 4.2, y * 2.5 - 3.1, 2223, 4) - 0.5
    n = fbm((x + wx * 0.45) * 3.2, (y + wy * 0.45) * 3.2, 2224, 5)
    alpha = smoothstep(0.92, 0.25, r + (n - 0.5) * 0.35) * (0.45 + 0.55 * n)
    shade = np.clip(0.84 + 0.14 * n - 0.08 * y, 0.75, 1.0)[..., None]
    rgb = np.repeat(shade, 3, axis=2)
    return to_rgba_uint8(rgb, alpha)


def make_scorch_crater_decal(size: int = 512) -> np.ndarray:
    x, y, r, ang = grid_coords(size)
    n = fbm(x * 4.2, y * 4.2, 3333, 5)
    char = smoothstep(0.82, 0.12, r + (n - 0.5) * 0.28)
    cracks = (np.abs(np.sin(ang * 5.5 + n * 4.5)) < 0.12).astype(np.float32)
    cracks *= smoothstep(0.92, 0.18, r) * smoothstep(0.05, 0.22, r)
    ember = np.exp(-r * r * 14.0) * cracks * 0.55

    c_ash = np.array([0.09, 0.08, 0.08], dtype=np.float32)
    c_rim = np.array([0.20, 0.17, 0.15], dtype=np.float32)
    c_ember = np.array([0.96, 0.42, 0.12], dtype=np.float32)
    rgb = c_ash + (c_rim - c_ash) * np.clip(r, 0.0, 1.0)[..., None]
    rgb = rgb + ember[..., None] * c_ember
    alpha = np.clip(np.maximum(char * 0.85, cracks * 0.75) * smoothstep(0.95, 0.75, r), 0.0, 1.0)
    return to_rgba_uint8(rgb, alpha)


def make_beam_energy_trail(w: int = 512, h: int = 256) -> np.ndarray:
    u = np.linspace(0.0, 1.0, w, endpoint=False, dtype=np.float32)
    v = np.linspace(-1.0, 1.0, h, dtype=np.float32)
    uu, vv = np.meshgrid(u, v)
    n = fbm(uu * 8.0, vv * 3.0, 4444, 4, period=8)
    core = np.exp(-((vv + (n - 0.5) * 0.18) ** 2) / (0.24 ** 2))
    streak = 0.55 + 0.45 * fbm(uu * 16.0, vv * 2.0, 4445, 3, period=16)
    alpha = core * streak * smoothstep(0.96, 0.65, np.abs(vv))
    rgb = np.ones((h, w, 3), dtype=np.float32)
    return to_rgba_uint8(rgb, alpha)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    outputs = {
        "vfx_flipbook_explosion_4x4.png": render_flipbook(tile_explosion, 1024),
        "vfx_flipbook_frost_shatter_4x4.png": render_flipbook(tile_frost, 1024),
        "vfx_flipbook_arcane_rift_4x4.png": render_flipbook(tile_arcane, 1024),
        "vfx_flipbook_slash_spark_4x4.png": render_flipbook(tile_slash, 1024),
        "vfx_shockwave_ring.png": make_shockwave_ring(512),
        "vfx_soft_glow_flare.png": make_soft_glow_flare(512),
        "vfx_smoke_wispy.png": make_smoke_wispy(512),
        "vfx_scorch_crater_decal.png": make_scorch_crater_decal(512),
        "vfx_beam_energy_trail.png": make_beam_energy_trail(512, 256),
    }
    summary = []
    for name, rgba in outputs.items():
        path = OUT_DIR / name
        save_rgba_png(path, rgba)
        optimize_png(path)
        nz = float(np.mean(rgba[..., 3] > 8) * 100.0)
        summary.append(
            {
                "file": name,
                "width": int(rgba.shape[1]),
                "height": int(rgba.shape[0]),
                "bytes": path.stat().st_size,
                "non_empty_alpha_pct": round(nz, 2),
            }
        )
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
