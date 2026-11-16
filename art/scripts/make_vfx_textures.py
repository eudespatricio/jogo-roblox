#!/usr/bin/env python3
"""Gera 14 texturas RGBA anti-aliased de VFX (4 flipbooks 8x8 1024x1024, 1 flipbook 4x4 1024x1024 e 9 mapas/decals/beams) para Open Cloud.

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
        subprocess.run(["oxipng", "-o", "2", "-q", str(path)], check=False)
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


def value_noise(
    x: np.ndarray,
    y: np.ndarray,
    seed: int,
    period_x: int | None = None,
    period_y: int | None = None,
) -> np.ndarray:
    ix = np.floor(x).astype(np.int64)
    iy = np.floor(y).astype(np.int64)
    fx = x - ix
    fy = y - iy
    ux = fx * fx * (3.0 - 2.0 * fx)
    uy = fy * fy * (3.0 - 2.0 * fy)
    ix1 = ix + 1
    iy1 = iy + 1
    if period_x is not None:
        ix = np.mod(ix, period_x)
        ix1 = np.mod(ix1, period_x)
    if period_y is not None:
        iy = np.mod(iy, period_y)
        iy1 = np.mod(iy1, period_y)
    v00 = _hash2(ix, iy, seed)
    v10 = _hash2(ix1, iy, seed)
    v01 = _hash2(ix, iy1, seed)
    v11 = _hash2(ix1, iy1, seed)
    return (v00 * (1.0 - ux) + v10 * ux) * (1.0 - uy) + (v01 * (1.0 - ux) + v11 * ux) * uy


def fbm(
    x: np.ndarray,
    y: np.ndarray,
    seed: int,
    octaves: int = 4,
    period: int | None = None,
    period_y: int | None = None,
) -> np.ndarray:
    acc = np.zeros_like(x, dtype=np.float32)
    amp = 0.5
    norm = 0.0
    freq = 1.0
    for o in range(octaves):
        px = int(period * freq) if period is not None else None
        py = int(period_y * freq) if period_y is not None else None
        acc += amp * value_noise(x * freq, y * freq, seed + o * 97, period_x=px, period_y=py)
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


def render_flipbook(tile_fn, grid_n: int = 8, size: int = 1024, loop: bool = False) -> np.ndarray:
    tile = size // grid_n
    total = grid_n * grid_n
    denom = float(total if loop else max(total - 1, 1))
    atlas = np.zeros((size, size, 4), dtype=np.uint8)
    xx, yy, rr, ang = grid_coords(tile)
    cell_mask = smoothstep(0.96, 0.78, rr)
    for f in range(total):
        r, c = divmod(f, grid_n)
        rgb, a = tile_fn(f, f / denom, xx, yy, rr, ang)
        atlas[r * tile : (r + 1) * tile, c * tile : (c + 1) * tile] = to_rgba_uint8(rgb, a * cell_mask)
    return atlas


def tile_explosion(f: int, t: float, x: np.ndarray, y: np.ndarray, r: np.ndarray, ang: np.ndarray):
    warp_x = fbm(x * 2.8 + t * 1.3, y * 2.8 - t * 0.9, 101, 4) - 0.5
    warp_y = fbm(x * 2.8 - t * 0.8, y * 2.8 + t * 1.4, 202, 4) - 0.5
    n_core = fbm((x + warp_x * 0.48) * 4.0, (y + warp_y * 0.48 - t * 0.5) * 4.0, 303 + (f // 2), 4)
    n_lobe = fbm(x * 5.5 - t * 0.7, y * 5.5 + t * 0.7, 404, 3)
    r_w = r + (n_core - 0.5) * (0.26 + 0.28 * t) + (n_lobe - 0.5) * 0.12

    radius = 0.20 + 0.68 * (t ** 0.52)
    body = smoothstep(radius + 0.14, radius * 0.40, r_w)
    shock_ring = np.exp(-((r - (0.18 + 0.74 * (t ** 0.65))) ** 2) * 180.0) * smoothstep(0.02, 0.16, t) * (1.0 - t)
    smoke_fade = 1.0 - 0.88 * smoothstep(0.58, 1.0, t)
    flash = math.exp(-((t / 0.14) ** 2)) * np.exp(-r * r * 11.0)

    heat = np.clip((1.0 - r_w / (radius + 1e-4)) * 0.95 + n_core * 0.58 - t * 0.74, 0.0, 1.0)
    # Paleta quente pyroclastica: soot -> danger (#E4572E) -> amber (#F59E0B) -> white-gold
    c_soot = np.array([0.16, 0.12, 0.12], dtype=np.float32)
    c_red = np.array([0.92, 0.30, 0.12], dtype=np.float32)
    c_amb = np.array([1.00, 0.74, 0.20], dtype=np.float32)
    c_hot = np.array([1.00, 0.98, 0.88], dtype=np.float32)

    rgb = np.where(heat[..., None] < 0.35, c_soot + (c_red - c_soot) * (heat[..., None] / 0.35), c_red)
    mid = np.clip((heat - 0.35) / 0.35, 0.0, 1.0)[..., None]
    rgb = np.where((heat >= 0.35)[..., None], c_red + (c_amb - c_red) * mid, rgb)
    hi = np.clip((heat - 0.70) / 0.30, 0.0, 1.0)[..., None]
    rgb = np.where((heat >= 0.70)[..., None], c_amb + (c_hot - c_amb) * hi, rgb)
    rgb = np.clip(rgb + (flash + shock_ring * 0.75)[..., None] * c_hot, 0.0, 1.0)

    sparks = np.zeros_like(r)
    rng = np.random.default_rng(7700)
    for _ in range(16):
        sa = rng.uniform(-math.pi, math.pi)
        sr = (0.12 + 0.75 * t) * rng.uniform(0.72, 1.15)
        sx, sy = sr * math.cos(sa), sr * math.sin(sa)
        d2 = (x - sx) ** 2 + (y - sy) ** 2
        sparks += np.exp(-d2 * 560.0) * smoothstep(0.04, 0.18, t) * smoothstep(1.0, 0.58, t)
    rgb = np.clip(rgb + sparks[..., None] * c_hot, 0.0, 1.0)
    alpha = np.clip(np.maximum(body * smoke_fade, np.maximum(flash, np.maximum(sparks * 0.92, shock_ring * 0.8))), 0.0, 1.0)
    return rgb, alpha


def tile_frost(f: int, t: float, x: np.ndarray, y: np.ndarray, r: np.ndarray, ang: np.ndarray):
    n = fbm(x * 4.8 + t * 0.4, y * 4.8 - t * 0.4, 505, 4)
    hex_arm = np.abs(np.cos(ang * 3.0 + n * 0.22)) ** 11.0
    sub_arm = np.abs(np.cos(ang * 6.0 + 0.52)) ** 18.0
    reach = 0.20 + 0.70 * (t ** 0.50)

    star = np.exp(-r * 6.2 / max(reach, 0.18)) * (0.48 + 0.78 * hex_arm + 0.38 * sub_arm)
    shards = np.zeros_like(r)
    for k in range(10):
        ka = k * (math.pi / 5.0) + (0.16 if k % 2 else -0.09)
        ca, sa = math.cos(ka), math.sin(ka)
        dist_r = 0.09 + 0.68 * (t ** 0.68)
        px = x - ca * dist_r
        py = y - sa * dist_r
        along = px * ca + py * sa
        perp = -px * sa + py * ca
        diamond = np.abs(along) * 1.1 + np.abs(perp) * 3.1
        shards += smoothstep(0.11, 0.025, diamond) * smoothstep(0.04, 0.16, t) * smoothstep(1.0, 0.62, t)

    ring = np.exp(-((r - reach * 0.86) ** 2) * 155.0) * smoothstep(0.0, 0.22, t) * (1.0 - t)
    mist = smoothstep(reach + 0.14, 0.10, r + (n - 0.5) * 0.24) * (0.38 * n) * (1.0 - 0.78 * t)

    c_deep = np.array([0.18, 0.54, 0.96], dtype=np.float32)
    c_ice = np.array([0.74, 0.94, 1.00], dtype=np.float32)
    c_white = np.array([0.97, 0.99, 1.00], dtype=np.float32)

    lum = np.clip(star + shards * 1.15 + ring * 0.95, 0.0, 1.0)
    rgb = c_deep + (c_ice - c_deep) * np.clip(lum * 1.25, 0.0, 1.0)[..., None]
    rgb = np.where((lum > 0.62)[..., None], rgb + (c_white - rgb) * ((lum - 0.62) / 0.38)[..., None], rgb)
    alpha = np.clip(np.maximum(star, np.maximum(shards, np.maximum(ring, mist))) * 1.28 * (1.0 - 0.68 * smoothstep(0.68, 1.0, t)), 0.0, 1.0)
    return rgb, alpha


def tile_arcane(f: int, t: float, x: np.ndarray, y: np.ndarray, r: np.ndarray, ang: np.ndarray):
    spin = t * math.pi * 2.6
    n = fbm(x * 3.8 + t * 1.1, y * 3.8 - t * 1.1, 808, 4)
    spiral = 0.5 + 0.5 * np.cos(3.0 * ang - r * 10.0 + spin + (n - 0.5) * 2.5)
    spiral = (spiral ** 3.0) * smoothstep(0.90, 0.14, r)

    rune_r = 0.40 + 0.28 * math.sin(t * math.pi)
    rune_ring = np.exp(-((r - rune_r) ** 2) * 280.0) * (0.45 + 0.55 * (np.cos(ang * 8.0 - spin * 1.5) > 0.0))
    outer_ring = np.exp(-((r - (rune_r * 1.32)) ** 2) * 320.0) * (0.4 + 0.6 * (np.sin(ang * 12.0 + spin) > 0.0))
    core = np.exp(-r * r * 18.0) * (0.72 + 0.28 * math.sin(t * math.pi))

    envelope = smoothstep(0.0, 0.16, t) * smoothstep(1.0, 0.72, t) + 0.35 * math.exp(-t * 5.0)
    envelope = min(1.0, envelope)

    c_violet = np.array([0.66, 0.33, 0.97], dtype=np.float32)
    c_teal = np.array([0.08, 0.80, 0.78], dtype=np.float32)
    c_cyan = np.array([0.88, 1.00, 0.97], dtype=np.float32)

    mix_v = np.clip(r * 1.15, 0.0, 1.0)[..., None]
    rgb = c_teal * (1.0 - mix_v) + c_violet * mix_v
    hi = np.clip(core + rune_ring * 0.85 + outer_ring * 0.6 + spiral * 0.55, 0.0, 1.0)[..., None]
    rgb = rgb * (1.0 - hi * 0.78) + c_cyan * (hi * 0.78)
    alpha = np.clip((spiral * 0.78 + rune_ring * 0.95 + outer_ring * 0.65 + core) * envelope, 0.0, 1.0)
    return rgb, alpha


def tile_fire_loop(f: int, t: float, x: np.ndarray, y: np.ndarray, r: np.ndarray, ang: np.ndarray):
    """Seamless 64-frame burning fire loop: periodic in t in [0, 1)."""
    theta = t * math.pi * 2.0
    # Advect vertically with exact integer period 4 along y so t=0 and t=1 match seamlessly
    adv_y = y * 2.0 + t * 4.0
    sway = 0.16 * np.sin(theta + y * 3.2) * smoothstep(0.8, -0.8, y)
    xw = x + sway

    n1 = fbm(xw * 2.5 + 0.35 * math.cos(theta), adv_y, 610, octaves=4, period=4, period_y=4)
    n2 = fbm(xw * 5.0 - 0.35 * math.sin(theta), adv_y * 2.0, 620, octaves=3, period=8, period_y=8)
    turb = 0.65 * n1 + 0.35 * n2

    # Teardrop flame silhouette: wider near bottom (y > 0 in top-down PNG), tapering toward top (y < 0)
    height_norm = np.clip((0.78 - y) / 1.56, 0.0, 1.0)  # 0 at base, 1 at tip
    width_profile = 0.52 * (1.0 - 0.68 * (height_norm ** 1.25)) + 0.06
    flame_dist = np.abs(xw + (turb - 0.5) * (0.24 + 0.35 * height_norm)) / np.maximum(width_profile, 0.08)

    vertical_env = smoothstep(0.92, 0.55, y) * smoothstep(1.02, 0.15, height_norm - (turb - 0.45) * 0.42)
    flame = smoothstep(1.15, 0.22, flame_dist) * vertical_env

    # Rising periodic embers (4 ember streams looping every cycle)
    embers = np.zeros_like(r)
    for k in range(6):
        phase = (t + k / 6.0) % 1.0
        ey = 0.55 - phase * 1.35
        ex = 0.28 * math.sin(k * 2.1 + phase * math.pi * 2.0)
        d2 = (x - ex) ** 2 + (y - ey) ** 2
        embers += np.exp(-d2 * 380.0) * math.sin(phase * math.pi)

    heat = np.clip(flame * (1.12 - 0.52 * height_norm) + turb * 0.25 + embers * 0.85, 0.0, 1.0)
    c_crimson = np.array([0.82, 0.18, 0.06], dtype=np.float32)
    c_orange = np.array([0.96, 0.44, 0.10], dtype=np.float32)
    c_amber = np.array([1.00, 0.78, 0.22], dtype=np.float32)
    c_core = np.array([1.00, 0.98, 0.86], dtype=np.float32)

    rgb = np.where(heat[..., None] < 0.35, c_crimson + (c_orange - c_crimson) * (heat[..., None] / 0.35), c_orange)
    mid = np.clip((heat - 0.35) / 0.35, 0.0, 1.0)[..., None]
    rgb = np.where((heat >= 0.35)[..., None], c_orange + (c_amber - c_orange) * mid, rgb)
    hi = np.clip((heat - 0.70) / 0.30, 0.0, 1.0)[..., None]
    rgb = np.where((heat >= 0.70)[..., None], c_amber + (c_core - c_amber) * hi, rgb)

    alpha = np.clip(np.maximum(flame * 1.15, embers * 0.95), 0.0, 1.0)
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


def make_tar_puddle_decal(size: int = 512) -> np.ndarray:
    """Viscous pitch/tar puddle decal with glossy concentric ripples and bubbling blisters."""
    x, y, r, ang = grid_coords(size)
    n_lobe = fbm(x * 3.0, y * 3.0, 5101, 4)
    n_fine = fbm(x * 7.5, y * 7.5, 5102, 3)
    tendrils = 0.08 * np.sin(ang * 7.0 + n_lobe * 3.5) + 0.05 * np.cos(ang * 13.0 - n_lobe * 2.0)
    r_eff = r + (n_lobe - 0.5) * 0.26 + tendrils

    puddle_mask = smoothstep(0.86, 0.68, r_eff)
    rim_lip = smoothstep(0.60, 0.74, r_eff) * smoothstep(0.86, 0.74, r_eff)
    ripples = (0.5 + 0.5 * np.sin(r_eff * 28.0 - n_lobe * 4.0)) ** 4.0 * smoothstep(0.75, 0.10, r_eff)

    # Glossy tar bubbles
    bubbles = np.zeros_like(r)
    bubble_rim = np.zeros_like(r)
    rng = np.random.default_rng(5150)
    for _ in range(18):
        ba = rng.uniform(-math.pi, math.pi)
        br = rng.uniform(0.08, 0.58)
        bx, by = br * math.cos(ba), br * math.sin(ba)
        rad = rng.uniform(0.045, 0.095)
        dist = np.sqrt((x - bx) ** 2 + (y - by) ** 2)
        bubbles += smoothstep(rad, rad * 0.3, dist)
        bubble_rim += np.exp(-((dist - rad * 0.78) ** 2) / ((rad * 0.18) ** 2))

    spec = np.clip(rim_lip * 0.65 + ripples * 0.35 + bubble_rim * 0.75 + (n_fine - 0.5) * 0.12, 0.0, 1.0)
    c_tar_deep = np.array([0.08, 0.06, 0.05], dtype=np.float32)
    c_tar_brown = np.array([0.22, 0.15, 0.10], dtype=np.float32)
    c_amber_spec = np.array([0.85, 0.55, 0.22], dtype=np.float32)

    rgb = c_tar_deep + (c_tar_brown - c_tar_deep) * np.clip(n_lobe * 0.8 + bubbles * 0.3, 0.0, 1.0)[..., None]
    rgb = np.clip(rgb + spec[..., None] * c_amber_spec * 0.65, 0.0, 1.0)
    alpha = np.clip(puddle_mask * (0.92 + 0.08 * rim_lip) * smoothstep(0.96, 0.82, r), 0.0, 1.0)
    return to_rgba_uint8(rgb, alpha)


def make_frost_ground_decal(size: int = 512) -> np.ndarray:
    """Glacial rime ground patch with 6-fold dendritic frost fern crystals and fractured ice plates."""
    x, y, r, ang = grid_coords(size)
    n_base = fbm(x * 4.0, y * 4.0, 6201, 4)
    n_cryst = fbm(x * 10.0, y * 10.0, 6202, 4)

    star6 = 0.5 + 0.5 * np.cos(ang * 6.0 + (n_base - 0.5) * 1.4)
    dendrite = (np.abs(np.cos(ang * 6.0 + np.sin(r * 18.0 + n_base * 3.0) * 0.45)) ** 6.0) * smoothstep(0.90, 0.12, r)
    plates = smoothstep(0.08, 0.02, np.abs(np.sin(x * 9.0 + n_base * 3.5) * np.cos(y * 9.0 - n_base * 3.5)))

    patch_radius = 0.72 + 0.14 * star6 + (n_base - 0.5) * 0.16
    body = smoothstep(patch_radius + 0.08, patch_radius - 0.18, r)
    rim = np.exp(-((r - patch_radius * 0.88) ** 2) * 110.0)

    frost_val = np.clip(body * (0.45 + 0.35 * n_cryst) + dendrite * 0.55 + plates * body * 0.45 + rim * 0.50, 0.0, 1.0)
    c_glacier = np.array([0.28, 0.66, 0.96], dtype=np.float32)
    c_rime = np.array([0.78, 0.94, 1.00], dtype=np.float32)
    c_white = np.array([0.98, 1.00, 1.00], dtype=np.float32)

    rgb = c_glacier + (c_rime - c_glacier) * np.clip(frost_val * 1.2, 0.0, 1.0)[..., None]
    hi = np.clip((frost_val - 0.58) / 0.42, 0.0, 1.0)[..., None]
    rgb = rgb + (c_white - rgb) * hi
    alpha = np.clip((body * 0.78 + dendrite * 0.65 + rim * 0.55) * smoothstep(0.96, 0.80, r), 0.0, 1.0)
    return to_rgba_uint8(rgb, alpha)


def make_boss_rune_decal(size: int = 512) -> np.ndarray:
    """Ornate concentric boss telegraph rune sigil with octagram geometry and radial ticks."""
    x, y, r, ang = grid_coords(size)
    outer_ring = np.exp(-((r - 0.84) ** 2) / (0.024 ** 2))
    inner_ring = np.exp(-((r - 0.68) ** 2) / (0.018 ** 2))
    core_ring = np.exp(-((r - 0.32) ** 2) / (0.020 ** 2))

    # Radial degree ticks between inner and outer ring
    in_band = smoothstep(0.68, 0.71, r) * smoothstep(0.84, 0.81, r)
    rune_glyphs = in_band * (np.abs(np.cos(ang * 16.0)) ** 6.0) * (0.5 + 0.5 * (np.sin(r * 64.0 + ang * 8.0) > 0.0))

    # Octagram star lines
    star_8 = np.zeros_like(r)
    for k in range(8):
        ka = k * (math.pi / 4.0)
        ca, sa = math.cos(ka), math.sin(ka)
        along = x * ca + y * sa
        perp = np.abs(-x * sa + y * ca)
        spoke = np.exp(-((perp / 0.016) ** 2)) * smoothstep(0.18, 0.26, along) * smoothstep(0.84, 0.72, along)
        chord = np.exp(-(((along - 0.48) / 0.016) ** 2)) * smoothstep(0.52, 0.44, perp)
        star_8 = np.maximum(star_8, np.maximum(spoke, chord * 0.85))

    center_eye = np.exp(-r * r * 28.0) * 0.85
    fill_glow = smoothstep(0.86, 0.0, r) * 0.22
    intensity = np.clip(outer_ring + inner_ring * 0.9 + core_ring * 0.95 + rune_glyphs * 0.9 + star_8 * 0.85 + center_eye, 0.0, 1.0)

    c_warn = np.array([1.00, 0.52, 0.16], dtype=np.float32)
    c_hot = np.array([1.00, 0.96, 0.84], dtype=np.float32)
    rgb = c_warn + (c_hot - c_warn) * (intensity ** 1.2)[..., None]
    alpha = np.clip((intensity + fill_glow) * smoothstep(0.96, 0.86, r), 0.0, 1.0)
    return to_rgba_uint8(rgb, alpha)


def make_lightning_arc_beam(w: int = 512, h: int = 256) -> np.ndarray:
    """Horizontally tileable jagged lightning bolt + forked secondary arcs + corona glow."""
    u = np.linspace(0.0, 1.0, w, endpoint=False, dtype=np.float32)
    v = np.linspace(-1.0, 1.0, h, dtype=np.float32)
    uu, vv = np.meshgrid(u, v)

    # Periodic 1D/2D displacement along U so u=0 and u=1 tile seamlessly in Beam Wrap/Stretch
    d1 = fbm(uu * 6.0, np.zeros_like(vv) + 0.25, 7301, octaves=4, period=6) - 0.5
    d2 = fbm(uu * 18.0, np.zeros_like(vv) + 0.75, 7302, octaves=3, period=18) - 0.5
    main_path = d1 * 0.52 + d2 * 0.22
    dist_main = np.abs(vv - main_path)

    # Secondary braided/forked arc
    b1 = fbm(uu * 8.0, np.zeros_like(vv) + 1.35, 7303, octaves=4, period=8) - 0.5
    branch_path = main_path * 0.45 + b1 * 0.65 + 0.14 * np.sin(uu * math.pi * 4.0)
    dist_branch = np.abs(vv - branch_path)
    branch_env = 0.5 + 0.5 * np.cos(uu * math.pi * 6.0 + 0.8)

    core = np.exp(-((dist_main / 0.032) ** 2))
    inner_glow = 0.75 * np.exp(-((dist_main / 0.11) ** 2))
    outer_corona = 0.35 * np.exp(-((dist_main / 0.32) ** 2))
    branch_arc = (0.75 * np.exp(-((dist_branch / 0.022) ** 2)) + 0.35 * np.exp(-((dist_branch / 0.08) ** 2))) * branch_env

    flicker = 0.78 + 0.22 * fbm(uu * 12.0, vv * 4.0, 7304, octaves=3, period=12)
    lum = np.clip((core + inner_glow + outer_corona + branch_arc) * flicker, 0.0, 1.0)
    edge_fade = smoothstep(0.98, 0.70, np.abs(vv))

    c_aura = np.array([0.38, 0.82, 1.00], dtype=np.float32)
    c_white = np.array([1.00, 1.00, 1.00], dtype=np.float32)
    rgb = c_aura + (c_white - c_aura) * np.clip(core + branch_arc * 0.7, 0.0, 1.0)[..., None]
    alpha = np.clip(lum * edge_fade, 0.0, 1.0)
    return to_rgba_uint8(rgb, alpha)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    # Remove legacy 4x4 files that were upgraded to 8x8 so art/renders/vfx stays clean
    for legacy in (
        "vfx_flipbook_explosion_4x4.png",
        "vfx_flipbook_frost_shatter_4x4.png",
        "vfx_flipbook_arcane_rift_4x4.png",
    ):
        legacy_path = OUT_DIR / legacy
        if legacy_path.is_file():
            legacy_path.unlink()

    outputs = {
        "vfx_flipbook_explosion_8x8.png": render_flipbook(tile_explosion, grid_n=8, size=1024, loop=False),
        "vfx_flipbook_frost_shatter_8x8.png": render_flipbook(tile_frost, grid_n=8, size=1024, loop=False),
        "vfx_flipbook_arcane_rift_8x8.png": render_flipbook(tile_arcane, grid_n=8, size=1024, loop=False),
        "vfx_flipbook_fire_loop_8x8.png": render_flipbook(tile_fire_loop, grid_n=8, size=1024, loop=True),
        "vfx_flipbook_slash_spark_4x4.png": render_flipbook(tile_slash, grid_n=4, size=1024, loop=False),
        "vfx_shockwave_ring.png": make_shockwave_ring(512),
        "vfx_soft_glow_flare.png": make_soft_glow_flare(512),
        "vfx_smoke_wispy.png": make_smoke_wispy(512),
        "vfx_scorch_crater_decal.png": make_scorch_crater_decal(512),
        "vfx_beam_energy_trail.png": make_beam_energy_trail(512, 256),
        "vfx_tar_puddle_decal.png": make_tar_puddle_decal(512),
        "vfx_frost_ground_decal.png": make_frost_ground_decal(512),
        "vfx_boss_rune_decal.png": make_boss_rune_decal(512),
        "vfx_lightning_arc_beam.png": make_lightning_arc_beam(512, 256),
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
