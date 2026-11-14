#!/usr/bin/env python3
"""Sintetizador acustico deterministico de SFX/OST da MURALHA + publicacao Open Cloud.

Pipeline (client-only; nunca toca sim/schema/analytics):
  1. sintetiza cada cue em numpy (seed = crc32(nome), sem dependencia de PYTHONHASHSEED)
     usando modelagem fisica Karplus-Strong, ressonadores modais, metais com brilho
     dinamico, varreduras biquad e reverb Schroeder/FDN (circular para loops BGM);
  2. normaliza ~-14 LUFS SFX / -15.5 LUFS BGM (K-weighting BS.1770) com pico <= -1.2 dBFS;
  3. grava OGG Vorbis 44.1 kHz via ffmpeg (bitexact) em assets/audio/<pasta>/<cue>.ogg;
  4. --publish sobe os OGG pela Assets API (assetType Audio) e le moderationState;
  5. --emit-luau gera src/shared/visual/AudioAssets.luau (cue -> rbxassetid + duracao).

Uso:
  python3 tools/gen-sfx.py --list
  python3 tools/gen-sfx.py --smoke
  python3 tools/gen-sfx.py
  python3 tools/gen-sfx.py --publish --emit-luau
  python3 tools/gen-sfx.py --refresh-moderation --emit-luau
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import subprocess
import sys
import tempfile
import time
import wave
import zlib
from dataclasses import dataclass
from pathlib import Path
from typing import Callable

import numpy as np

SR = 44100
TARGET_LUFS = -14.0
BGM_TARGET_LUFS = -15.5
PEAK_CEIL_DB = -1.2
MAX_DRIVE_DB = 9.0

ROOT = Path(__file__).resolve().parents[1]
AUDIO_ROOT = ROOT / "assets" / "audio"
MANIFEST_PATH = AUDIO_ROOT / "manifest.json"
LUAU_PATH = ROOT / "src" / "shared" / "visual" / "AudioAssets.luau"
SMOKE_DIR = ROOT / "build" / "sfx-smoke"

KEY_PATH = Path.home() / ".config" / "forge3d" / "roblox.key"
CREATOR_USER_ID = "11966727684"
ASSETS_URL = "https://apis.roblox.com/assets/v1/assets"
OPERATIONS_BASE = "https://apis.roblox.com/assets/v1/"

TAU = 2.0 * np.pi


@dataclass(frozen=True)
class Cue:
    name: str
    folder: str
    duration: float
    group: str
    publish: bool = True
    stereo: bool = False
    loop: bool = False


class Ctx:
    def __init__(self, cue: Cue) -> None:
        self.cue = cue
        self.n = int(round(SR * cue.duration))
        self.t = np.arange(self.n, dtype=np.float64) / SR
        self.rng = np.random.default_rng(zlib.crc32(cue.name.encode("utf-8")))

    def noise(self, n: int | None = None) -> np.ndarray:
        return self.rng.standard_normal(self.n if n is None else n)


# --------------------------------------------------------------------------- DSP basico


def unit(x: np.ndarray) -> np.ndarray:
    peak = float(np.max(np.abs(x)))
    return x / peak if peak > 1e-12 else x


def env(ctx: Ctx, tau: float, attack: float = 0.002, start: float = 0.0) -> np.ndarray:
    tt = ctx.t - start
    pos = np.maximum(tt, 0.0)
    rise = np.clip(pos / attack, 0.0, 1.0) if attack > 0 else np.ones_like(pos)
    return np.where(tt >= 0.0, np.exp(-pos / tau) * rise, 0.0)


def glide(ctx: Ctx, f0: float, f1: float, tau: float, start: float = 0.0) -> np.ndarray:
    tt = np.maximum(ctx.t - start, 0.0)
    freq = (f1 + (f0 - f1) * np.exp(-tt / tau)) * (ctx.t >= start)
    return TAU * np.cumsum(freq) / SR


def linear(ctx: Ctx, f0: float, f1: float, span: float, start: float = 0.0) -> np.ndarray:
    tt = np.maximum(ctx.t - start, 0.0)
    freq = (f0 + (f1 - f0) * np.clip(tt / span, 0.0, 1.0)) * (ctx.t >= start)
    return TAU * np.cumsum(freq) / SR


def band(x: np.ndarray, lo: float, hi: float, soft: float = 0.25) -> np.ndarray:
    n = len(x)
    spec = np.fft.rfft(x, 2 * n)
    freqs = np.fft.rfftfreq(2 * n, 1.0 / SR)
    logf = np.log2(np.maximum(freqs, 1.0))
    lo_l, hi_l = np.log2(max(lo, 1.0)), np.log2(hi)
    rise = np.clip((logf - (lo_l - soft)) / soft, 0.0, 1.0)
    fall = np.clip(((hi_l + soft) - logf) / soft, 0.0, 1.0)
    mask = (0.5 - 0.5 * np.cos(np.pi * rise)) * (0.5 - 0.5 * np.cos(np.pi * fall))
    return np.fft.irfft(spec * mask, 2 * n)[:n]


def _biquad_coeffs(
    kind: str, fc: float, q: float = 0.707, gain_db: float = 0.0
) -> tuple[tuple[float, float, float], tuple[float, float, float]]:
    w0 = TAU * np.clip(fc, 15.0, SR * 0.45) / SR
    cw, sw = float(np.cos(w0)), float(np.sin(w0))
    alpha = sw / (2.0 * max(q, 0.1))
    if kind == "lp":
        b = ((1.0 - cw) / 2.0, 1.0 - cw, (1.0 - cw) / 2.0)
        a = (1.0 + alpha, -2.0 * cw, 1.0 - alpha)
    elif kind == "hp":
        b = ((1.0 + cw) / 2.0, -(1.0 + cw), (1.0 + cw) / 2.0)
        a = (1.0 + alpha, -2.0 * cw, 1.0 - alpha)
    elif kind == "bp":
        b = (alpha, 0.0, -alpha)
        a = (1.0 + alpha, -2.0 * cw, 1.0 - alpha)
    elif kind == "peaking":
        big_a = 10.0 ** (gain_db / 40.0)
        b = (1.0 + alpha * big_a, -2.0 * cw, 1.0 - alpha * big_a)
        a = (1.0 + alpha / big_a, -2.0 * cw, 1.0 - alpha / big_a)
    else:  # lowshelf
        big_a = 10.0 ** (gain_db / 40.0)
        sa = 2.0 * np.sqrt(big_a) * alpha
        b = (
            big_a * ((big_a + 1) - (big_a - 1) * cw + sa),
            2 * big_a * ((big_a - 1) - (big_a + 1) * cw),
            big_a * ((big_a + 1) - (big_a - 1) * cw - sa),
        )
        a = (
            (big_a + 1) + (big_a - 1) * cw + sa,
            -2 * ((big_a - 1) + (big_a + 1) * cw),
            (big_a + 1) + (big_a - 1) * cw - sa,
        )
    return b, a


def _biquad_response(b: tuple[float, float, float], a: tuple[float, float, float], w: np.ndarray) -> np.ndarray:
    z = np.exp(-1j * w)
    return (b[0] + b[1] * z + b[2] * z * z) / (a[0] + a[1] * z + a[2] * z * z)


def eq_biquad(
    x: np.ndarray, kind: str, fc: float, q: float = 0.707, gain_db: float = 0.0, circular: bool = False
) -> np.ndarray:
    n = x.shape[0]
    n_fft = n if circular else 2 * n
    b, a = _biquad_coeffs(kind, fc, q, gain_db)
    w = TAU * np.fft.rfftfreq(n_fft, 1.0 / SR) / SR
    resp = _biquad_response(b, a, w)
    if x.ndim == 1:
        return np.fft.irfft(np.fft.rfft(x, n_fft) * resp, n_fft)[:n]
    out = np.empty_like(x)
    for ch in range(x.shape[1]):
        out[:, ch] = np.fft.irfft(np.fft.rfft(x[:, ch], n_fft) * resp, n_fft)[:n]
    return out


def swept_band(x: np.ndarray, t: np.ndarray, f0: float, f1: float, start: float, span: float, q: float = 1.6) -> np.ndarray:
    steps = 7
    out = np.zeros_like(x)
    sig_half = 0.55 * span / (steps - 1)
    gate = ((t >= start - 0.01) & (t <= start + span + 0.04)).astype(np.float64)
    for k in range(steps):
        frac = k / (steps - 1)
        fc = f0 * ((f1 / max(f0, 20.0)) ** frac)
        when = start + frac * span
        w = np.exp(-0.5 * ((t - when) / max(sig_half, 0.005)) ** 2) * gate
        out += eq_biquad(x, "bp", fc, q=q) * w
    return out


def burst(
    ctx: Ctx, start: float, tau: float, lo: float, hi: float, amp: float = 1.0, attack: float = 0.001
) -> np.ndarray:
    return unit(band(ctx.noise(), lo, hi)) * env(ctx, tau, attack, start) * amp


def clicks(
    ctx: Ctx, times: np.ndarray, amps: np.ndarray, lo: float, hi: float, tau: float = 0.004
) -> np.ndarray:
    x = np.zeros(ctx.n)
    length = max(8, int(tau * 8 * SR))
    decay = np.exp(-np.arange(length) / (tau * SR))
    for when, amp in zip(times, amps):
        i = int(when * SR)
        if 0 <= i < ctx.n:
            span = min(length, ctx.n - i)
            x[i : i + span] += amp * ctx.rng.standard_normal(span) * decay[:span]
    return unit(band(x, lo, hi)) * float(np.max(np.abs(amps))) if len(amps) else x


def scatter(ctx: Ctx, count: int, t0: float, span: float, curve: float = 1.6) -> np.ndarray:
    return np.sort(t0 + span * ctx.rng.random(count) ** curve)


def bell(
    ctx: Ctx,
    f: float,
    start: float,
    ratios: tuple[float, ...],
    decays: tuple[float, ...],
    amps: tuple[float, ...],
) -> np.ndarray:
    tt = ctx.t - start
    out = np.zeros(ctx.n)
    for r, d, a in zip(ratios, decays, amps):
        out += a * np.sin(TAU * f * r * np.maximum(tt, 0.0)) * env(ctx, d, 0.001, start)
    return out


def modal_impact(
    ctx: Ctx,
    f0: float,
    start: float,
    ratios: tuple[float, ...],
    decays: tuple[float, ...],
    amps: tuple[float, ...],
    click_lo: float = 1200.0,
    click_hi: float = 6000.0,
    click_amp: float = 0.35,
    click_tau: float = 0.003,
) -> np.ndarray:
    body = bell(ctx, f0, start, ratios, decays, amps)
    if click_amp > 0:
        body += burst(ctx, start, click_tau, click_lo, click_hi, click_amp, attack=0.0005)
    return body


def karplus_strong(
    n_total: int,
    rng: np.random.Generator,
    freq: float,
    start: float,
    dur: float,
    decay: float = 0.992,
    damp: float = 0.32,
    brighten: float = 0.55,
    amp: float = 1.0,
) -> np.ndarray:
    """Corda fisicamente modelada com atraso fracionario e filtro de amortecimento."""
    out = np.zeros(n_total, dtype=np.float64)
    i0 = int(round(start * SR))
    if i0 >= n_total:
        return out
    dur_n = min(n_total - i0, max(16, int(round(dur * SR))))
    raw_period = SR / max(freq, 35.0) - damp
    delay_l = max(5, int(np.floor(raw_period)))
    frac = float(raw_period - delay_l)
    init_n = min(delay_l + 2, dur_n)

    raw_noise = rng.standard_normal(init_n)
    # Mistura excitacao quente (meio-seno) + palheta filtrada
    phase = np.linspace(0.0, np.pi, init_n, endpoint=False)
    pluck_shape = (1.0 - brighten) * np.sin(phase) + brighten * (raw_noise / max(float(np.max(np.abs(raw_noise))), 1e-6))
    pluck_shape -= np.mean(pluck_shape)

    buf = np.zeros(dur_n, dtype=np.float64)
    buf[:init_n] = pluck_shape

    c0 = (1.0 - frac) * (1.0 - damp)
    c1 = frac * (1.0 - damp) + (1.0 - frac) * damp
    c2 = frac * damp
    step = max(1, delay_l - 2)
    pos = delay_l + 2
    while pos < dur_n:
        s = min(step, dur_n - pos)
        buf[pos : pos + s] = decay * (
            c0 * buf[pos - delay_l : pos - delay_l + s]
            + c1 * buf[pos - delay_l - 1 : pos - delay_l - 1 + s]
            + c2 * buf[pos - delay_l - 2 : pos - delay_l - 2 + s]
        )
        pos += s

    fade_out = min(int(0.015 * SR), dur_n)
    if fade_out > 4:
        buf[dur_n - fade_out :] *= np.linspace(1.0, 0.0, fade_out)
    out[i0 : i0 + dur_n] = amp * buf
    return out


def brass_note(
    ctx: Ctx,
    f: float,
    start: float,
    hold: float,
    release: float = 0.20,
    attack: float = 0.04,
    detune_cents: tuple[float, ...] = (-7.5, 0.0, 6.5),
    vibrato: float = 0.005,
    bend: float = 0.0,
    warmth_hz: float = 2400.0,
) -> np.ndarray:
    """Ensemble de metais com abertura dinamica de harmonicos e ataque labial."""
    tt = ctx.t - start
    active = tt >= 0.0
    pos = np.maximum(tt, 0.0)
    shape = np.clip(pos / max(attack, 1e-3), 0.0, 1.0) * np.where(
        pos < hold, 1.0, np.exp(-(pos - hold) / max(release, 1e-3))
    )
    bright_gate = np.clip(pos / (attack * 1.4), 0.15, 1.0) * np.where(
        pos < hold, 1.0, np.exp(-(pos - hold) / (release * 1.1))
    )
    vib = 1.0 + vibrato * np.sin(TAU * 5.2 * pos) * np.clip((pos - 0.12) / 0.22, 0.0, 1.0)
    sig = np.zeros(ctx.n, dtype=np.float64)
    for cents in detune_cents:
        ratio = 2.0 ** (cents / 1200.0)
        freq = f * ratio * vib * (1.0 + bend * pos) * active
        ph = TAU * np.cumsum(freq) / SR
        voice_sig = np.zeros(ctx.n, dtype=np.float64)
        for k in range(1, 10):
            # Harmonicos altos abrem progressivamente com o sopro
            k_weight = (k**-1.08) * (bright_gate ** (0.35 * (k - 1)))
            voice_sig += k_weight * np.sin(k * ph)
        sig += voice_sig / len(detune_cents)
    chiff = burst(ctx, start, 0.014, max(f * 1.5, 450.0), max(f * 4.5, 2200.0), 0.14, attack=0.002)
    out = eq_biquad(sig * shape * active, "lp", warmth_hz, q=0.75) + chiff
    return out


def _schroeder_chan(inp: np.ndarray, rt60: float, damp: float, offset: int = 0) -> np.ndarray:
    n = len(inp)
    combs = (1307 + offset, 1609 + offset * 2, 1931 - offset, 2269 + offset)
    acc = np.zeros(n, dtype=np.float64)
    for d in combs:
        g = 10.0 ** (-3.0 * d / max(rt60 * SR, SR * 0.05))
        buf = np.zeros(n, dtype=np.float64)
        init = min(d + 1, n)
        buf[:init] = inp[:init]
        step = max(1, d - 1)
        pos = d + 1
        while pos < n:
            s = min(step, n - pos)
            buf[pos : pos + s] = inp[pos : pos + s] + g * (
                (1.0 - damp) * buf[pos - d : pos - d + s] + damp * buf[pos - d - 1 : pos - d - 1 + s]
            )
            pos += s
        acc += buf
    acc *= 0.25
    for ap_d, ap_g in ((347 + offset, 0.5), (227 - offset // 2, 0.45)):
        v = np.empty(n, dtype=np.float64)
        init = min(ap_d, n)
        v[:init] = acc[:init]
        pos = ap_d
        while pos < n:
            s = min(ap_d, n - pos)
            v[pos : pos + s] = acc[pos : pos + s] + ap_g * v[pos - ap_d : pos - ap_d + s]
            pos += s
        y = -ap_g * v
        if n > ap_d:
            y[ap_d:] += v[:-ap_d]
        acc = y
    return acc


def reverb(
    x: np.ndarray, rt60: float = 0.55, wet: float = 0.22, predelay_ms: float = 11.0, damp: float = 0.35, loop: bool = False
) -> np.ndarray:
    n = x.shape[0]
    pre = int(round(predelay_ms * 0.001 * SR))
    src = np.concatenate([x, x], axis=0) if loop else x
    m = src.shape[0]

    def _run(ch: np.ndarray, off: int) -> np.ndarray:
        delayed = np.zeros(m, dtype=np.float64)
        if pre < m:
            delayed[pre:] = ch[: m - pre]
        w = _schroeder_chan(delayed, rt60=rt60, damp=damp, offset=off)
        return w[n : 2 * n] if loop else w

    if src.ndim == 1:
        wet_sig = _run(src, 0)
    else:
        wet_sig = np.stack([_run(src[:, 0], 0), _run(src[:, 1], 19)], axis=1)
    return (1.0 - 0.25 * wet) * x + wet * wet_sig


NOTE = {
    "A1": 55.00,
    "Bb1": 58.27,
    "C2": 65.41,
    "D2": 73.42,
    "E2": 82.41,
    "F2": 87.31,
    "G2": 98.00,
    "A2": 110.00,
    "Bb2": 116.54,
    "C3": 130.81,
    "D3": 146.83,
    "E3": 164.81,
    "F3": 174.61,
    "Fs3": 185.00,
    "G3": 196.00,
    "A3": 220.00,
    "Bb3": 233.08,
    "B3": 246.94,
    "C4": 261.63,
    "D4": 293.66,
    "Eb4": 311.13,
    "E4": 329.63,
    "F4": 349.23,
    "Fs4": 369.99,
    "G4": 392.00,
    "Gs4": 415.30,
    "A4": 440.00,
    "Bb4": 466.16,
    "B4": 493.88,
    "C5": 523.25,
    "D5": 587.33,
    "E5": 659.25,
    "F5": 698.46,
    "Fs5": 739.99,
    "G5": 783.99,
    "A5": 880.00,
    "D6": 1174.66,
    "E6": 1318.51,
    "Fs6": 1479.98,
}


# --------------------------------------------------------------------------- UI & Build SFX


def s_ui_click(c: Ctx) -> np.ndarray:
    wood = modal_impact(c, 410.0, 0.0, (1.0, 2.28, 3.84), (0.016, 0.009, 0.005), (1.0, 0.45, 0.18), 1800, 5200, 0.35, 0.002)
    latch = modal_impact(c, 1380.0, 0.004, (1.0, 1.92), (0.012, 0.006), (0.28, 0.12), 2500, 6500, 0.15, 0.0015)
    return eq_biquad(wood + latch, "hp", 140.0)


def s_ui_toggle(c: Ctx) -> np.ndarray:
    a = modal_impact(c, 370.0, 0.0, (1.0, 2.15), (0.022, 0.011), (0.9, 0.4), 1600, 4800, 0.30, 0.002)
    b = modal_impact(c, 585.0, 0.052, (1.0, 2.05, 3.4), (0.028, 0.014, 0.007), (1.0, 0.45, 0.18), 2000, 6000, 0.32, 0.002)
    slide = swept_band(c.noise(), c.t, 600.0, 1400.0, 0.01, 0.045, q=1.2) * 0.22
    return eq_biquad(a + b + slide, "hp", 120.0)


def s_build_place(c: Ctx) -> np.ndarray:
    thud = np.tanh(1.4 * np.sin(glide(c, 150, 56, 0.028)) * env(c, 0.055, 0.001)) * 0.9
    wood = modal_impact(c, 240.0, 0.0, (1.0, 1.85, 2.9), (0.032, 0.018, 0.009), (0.65, 0.4, 0.2), 700, 3200, 0.5, 0.004)
    iron = modal_impact(c, 1320.0, 0.026, (1.0, 1.62, 2.48), (0.045, 0.025, 0.014), (0.35, 0.22, 0.12), 2400, 7500, 0.25, 0.002)
    return reverb(thud + wood + iron, rt60=0.32, wet=0.16, predelay_ms=6.0)


def s_build_move(c: Ctx) -> np.ndarray:
    stone_slide = unit(swept_band(c.noise(), c.t, 260.0, 620.0, 0.0, 0.095, q=1.5)) * env(c, 0.06, 0.006) * 0.55
    settle = modal_impact(c, 290.0, 0.09, (1.0, 1.9, 3.1), (0.028, 0.015, 0.008), (0.8, 0.4, 0.2), 1100, 4200, 0.4, 0.003)
    lock = modal_impact(c, 1520.0, 0.115, (1.0, 1.7), (0.035, 0.018), (0.3, 0.15), 2500, 6800, 0.2, 0.002)
    return reverb(stone_slide + settle + lock, rt60=0.28, wet=0.14, predelay_ms=5.0)


def s_build_remove(c: Ctx) -> np.ndarray:
    unlatch = modal_impact(c, 880.0, 0.0, (1.0, 1.58, 2.3), (0.032, 0.018, 0.01), (0.55, 0.3, 0.18), 1800, 5500, 0.35, 0.003)
    wood_lift = np.sin(glide(c, 220, 105, 0.04, 0.04)) * env(c, 0.055, 0.003, 0.04) * 0.55
    dust = swept_band(c.noise(), c.t, 1200.0, 320.0, 0.03, 0.20, q=1.2) * 0.45
    return reverb(unlatch + wood_lift + dust, rt60=0.35, wet=0.16)


def _upgrade_chime(c: Ctx, notes: tuple[str, ...], gap: float, anvil_f: float, harmonic_decay: float) -> np.ndarray:
    out = modal_impact(c, anvil_f, 0.0, (1.0, 1.62, 2.41, 3.55), (0.07, 0.04, 0.025, 0.015), (0.5, 0.35, 0.2, 0.12), 2000, 7500, 0.28, 0.003)
    for i, name in enumerate(notes):
        t_note = 0.025 + i * gap
        out += karplus_strong(c.n, c.rng, NOTE[name], t_note, c.cue.duration - t_note, decay=0.9965, damp=0.22, brighten=0.65, amp=0.45)
        out += bell(c, NOTE[name], t_note, (1.0, 2.0, 3.01), (harmonic_decay, harmonic_decay * 0.5, harmonic_decay * 0.28), (0.45, 0.18, 0.08))
    return out


def s_build_upgrade_2(c: Ctx) -> np.ndarray:
    raw = _upgrade_chime(c, ("D5", "A5", "D6"), 0.068, 920.0, 0.20)
    return reverb(raw, rt60=0.52, wet=0.22, predelay_ms=10.0)


def s_build_upgrade_3(c: Ctx) -> np.ndarray:
    raw = _upgrade_chime(c, ("D5", "Fs5", "A5", "D6"), 0.062, 1080.0, 0.26)
    raw += burst(c, 0.18, 0.22, 5500, 12000, 0.10, 0.015)
    return reverb(raw, rt60=0.62, wet=0.25, predelay_ms=11.0)


def s_build_upgrade_4(c: Ctx) -> np.ndarray:
    raw = _upgrade_chime(c, ("A4", "D5", "Fs5", "A5", "E6"), 0.056, 1220.0, 0.30)
    raw += brass_note(c, NOTE["D4"], 0.16, 0.22, release=0.24, attack=0.04, detune_cents=(-5.0, 5.0), warmth_hz=2100.0) * 0.38
    return reverb(raw, rt60=0.70, wet=0.28, predelay_ms=12.0)


def s_build_upgrade_5(c: Ctx) -> np.ndarray:
    raw = np.tanh(1.5 * np.sin(glide(c, 130, 58, 0.07)) * env(c, 0.24)) * 0.55
    raw += _upgrade_chime(c, ("D5", "Fs5", "A5", "D6", "Fs6"), 0.052, 1340.0, 0.36)
    for name in ("D4", "A4", "Fs5"):
        raw += brass_note(c, NOTE[name], 0.22, 0.28, release=0.28, attack=0.04, warmth_hz=2600.0) * 0.32
    raw += burst(c, 0.24, 0.28, 6000, 13000, 0.12, 0.02)
    return reverb(raw, rt60=0.78, wet=0.30, predelay_ms=12.0)


def s_build_invalid(c: Ctx) -> np.ndarray:
    a = modal_impact(c, 195.0, 0.0, (1.0, 1.54, 2.2), (0.045, 0.024, 0.012), (0.9, 0.4, 0.18), 400, 1800, 0.22, 0.003)
    b = modal_impact(c, 146.0, 0.09, (1.0, 1.54, 2.2), (0.055, 0.028, 0.014), (1.0, 0.42, 0.2), 350, 1500, 0.22, 0.003)
    return eq_biquad(a + b, "lp", 1600.0, q=0.8)


def s_build_locked(c: Ctx) -> np.ndarray:
    lock1 = modal_impact(c, 740.0, 0.0, (1.0, 1.73, 2.81, 4.12), (0.055, 0.038, 0.025, 0.016), (0.85, 0.55, 0.35, 0.2), 2200, 7500, 0.45, 0.002)
    lock2 = modal_impact(c, 620.0, 0.085, (1.0, 1.82, 3.05), (0.06, 0.035, 0.02), (0.75, 0.45, 0.25), 1800, 6200, 0.35, 0.002)
    thud = np.sin(glide(c, 130, 58, 0.03, 0.08)) * env(c, 0.07, 0.002, 0.08) * 0.55
    return reverb(lock1 + lock2 + thud, rt60=0.40, wet=0.18)


def s_coin_gain(c: Ctx) -> np.ndarray:
    out = burst(c, 0.0, 0.03, 600, 2400, 0.22, 0.004)  # toque de bolsa de couro
    for i, f in enumerate((2350.0, 2780.0, 3120.0, 3640.0)):
        t_i = i * 0.044
        out += modal_impact(c, f, t_i, (1.0, 2.34, 3.82), (0.14, 0.07, 0.04), (0.7, 0.35, 0.16), 4500, 12000, 0.18, 0.001) * (0.85 + 0.06 * i)
    return reverb(out, rt60=0.45, wet=0.20, predelay_ms=8.0)


def s_coin_spend(c: Ctx) -> np.ndarray:
    out = np.zeros(c.n)
    for i, f in enumerate((2650.0, 2240.0, 1880.0)):
        out += modal_impact(c, f, i * 0.042, (1.0, 2.38, 3.9), (0.055, 0.03, 0.015), (0.75, 0.35, 0.15), 3500, 9000, 0.18, 0.001) * (1.0 - 0.12 * i)
    chest_lid = modal_impact(c, 185.0, 0.11, (1.0, 1.9, 3.1), (0.045, 0.022, 0.01), (0.8, 0.4, 0.15), 400, 2200, 0.35, 0.003)
    return reverb(out + chest_lid, rt60=0.32, wet=0.15)


# --------------------------------------------------------------------------- Traps & Sinergias SFX


def s_archer_fire(c: Ctx) -> np.ndarray:
    wood_snap = modal_impact(c, 185.0, 0.0, (1.0, 2.1, 3.4), (0.022, 0.011, 0.006), (0.75, 0.38, 0.16), 1200, 4800, 0.45, 0.002)
    bowstring = karplus_strong(c.n, c.rng, 196.0, 0.002, 0.19, decay=0.976, damp=0.42, brighten=0.65, amp=0.9)
    whoosh = unit(swept_band(c.noise(), c.t, 1400.0, 4600.0, 0.008, 0.11, q=1.5)) * env(c, 0.055, 0.008, 0.008) * 0.52
    return reverb(wood_snap + bowstring + whoosh, rt60=0.25, wet=0.14, predelay_ms=5.0)


def s_archer_impact(c: Ctx) -> np.ndarray:
    bodkin = modal_impact(c, 165.0, 0.0, (1.0, 1.95, 3.3), (0.025, 0.012, 0.006), (0.95, 0.45, 0.2), 1400, 5800, 0.65, 0.002)
    shaft_rattle = karplus_strong(c.n, c.rng, 145.0, 0.006, 0.12, decay=0.955, damp=0.5, brighten=0.35, amp=0.35)
    return reverb(bodkin + shaft_rattle, rt60=0.24, wet=0.12)


def s_tar_fire(c: Ctx) -> np.ndarray:
    splat = unit(swept_band(c.noise(), c.t, 900.0, 260.0, 0.0, 0.12, q=1.1)) * env(c, 0.08, 0.003) * 0.85
    thump = np.sin(glide(c, 155, 58, 0.06)) * env(c, 0.09) * 0.55
    bubbles = np.zeros(c.n)
    for k in range(11):
        st = 0.05 + 0.44 * (k / 10.0) + c.rng.uniform(-0.015, 0.015)
        f0 = c.rng.uniform(170.0, 440.0)
        bubbles += np.sin(linear(c, f0, f0 * 1.95, 0.036, st)) * env(c, 0.022, 0.002, st) * c.rng.uniform(0.22, 0.42)
    return reverb(eq_biquad(splat + thump + bubbles, "lp", 3400.0), rt60=0.38, wet=0.16)


def s_tar_ignite(c: Ctx) -> np.ndarray:
    bloom = np.tanh(1.8 * np.sin(glide(c, 110, 42, 0.09)) * env(c, 0.16, 0.004)) * 0.7
    flame_whoosh = unit(swept_band(c.noise(), c.t, 220.0, 2400.0, 0.02, 0.36, q=1.1)) * env(c, 0.26, 0.04, 0.02) * 0.85
    roar = eq_biquad(burst(c, 0.02, 0.32, 70, 420, 0.55, 0.05), "lp", 380.0)
    embers = clicks(c, scatter(c, 42, 0.08, 0.56, 1.0), c.rng.uniform(0.15, 0.45, 42), 2400, 8800, 0.002)
    return reverb(bloom + flame_whoosh + roar + embers, rt60=0.45, wet=0.20)


def s_frost_fire(c: Ctx) -> np.ndarray:
    chime = bell(c, 1318.5, 0.0, (1.0, 1.50, 2.76, 4.18), (0.24, 0.16, 0.09, 0.05), (0.8, 0.45, 0.3, 0.18))
    chime += bell(c, 1975.5, 0.045, (1.0, 1.50, 2.76), (0.22, 0.13, 0.07), (0.65, 0.35, 0.2))
    chill = unit(swept_band(c.noise(), c.t, 3800.0, 900.0, 0.0, 0.35, q=1.4)) * env(c, 0.22, 0.02) * 0.42
    return reverb(chime + chill, rt60=0.58, wet=0.26, predelay_ms=9.0)


def s_frost_impact(c: Ctx) -> np.ndarray:
    times = scatter(c, 56, 0.01, 0.32, 1.8)
    crackle = clicks(c, times, 0.5 * (1.0 - times / 0.38) * c.rng.uniform(0.3, 1.0, 56), 2800, 10500, 0.002)
    ice = modal_impact(c, 740.0, 0.0, (1.0, 1.88, 3.12, 4.75), (0.09, 0.055, 0.035, 0.02), (0.65, 0.42, 0.28, 0.15), 2500, 9500, 0.45, 0.002)
    return reverb(crackle + ice, rt60=0.42, wet=0.20)


def s_syn_thermal_shock(c: Ctx) -> np.ndarray:
    freeze_snap = unit(swept_band(c.noise(), c.t, 4800.0, 700.0, 0.0, 0.055, q=1.8)) * env(c, 0.04, 0.002) * 0.65
    detonation = np.tanh(2.1 * np.sin(glide(c, 130, 36, 0.09, 0.042)) * env(c, 0.24, 0.002, 0.042)) * 0.95
    shatter_t = scatter(c, 70, 0.045, 0.45, 1.7)
    shards = clicks(c, shatter_t, 0.6 * c.rng.uniform(0.3, 1.0, 70) * (1.0 - shatter_t / 0.55), 2400, 11500, 0.0025)
    crystal = bell(c, 2093.0, 0.045, (1.0, 1.76, 2.91, 4.4), (0.16, 0.10, 0.06, 0.03), (0.55, 0.35, 0.22, 0.12))
    return reverb(freeze_snap + detonation + shards + crystal, rt60=0.62, wet=0.25, predelay_ms=8.0)


def s_cannon_fire(c: Ctx) -> np.ndarray:
    fuse = burst(c, 0.0, 0.018, 2800, 8500, 0.28, 0.002)
    sub = np.tanh(2.1 * np.sin(glide(c, 125, 34, 0.10, 0.018)) * env(c, 0.28, 0.001, 0.018)) * 0.95
    crack = burst(c, 0.018, 0.016, 1200, 8200, 0.85, 0.0005)
    blast = eq_biquad(burst(c, 0.018, 0.18, 45, 1300, 0.9, 0.001), "lp", 1100.0)
    barrel = modal_impact(c, 220.0, 0.018, (1.0, 1.68, 2.55), (0.12, 0.07, 0.04), (0.35, 0.2, 0.1), 800, 2600, 0.0)
    return reverb(fuse + sub + crack + blast + barrel, rt60=0.68, wet=0.26, predelay_ms=11.0)


def s_cannon_impact(c: Ctx) -> np.ndarray:
    sub = np.tanh(1.7 * np.sin(glide(c, 98, 38, 0.07)) * env(c, 0.14)) * 0.8
    blast = burst(c, 0.0, 0.08, 160, 2600, 0.85, 0.001)
    debris_t = scatter(c, 36, 0.04, 0.56)
    debris = clicks(c, debris_t, 0.48 * c.rng.uniform(0.25, 1.0, 36) * (1.0 - debris_t / 0.7), 900, 5200, 0.005)
    return reverb(sub + blast + debris, rt60=0.52, wet=0.22)


def s_catapult_fire(c: Ctx) -> np.ndarray:
    ratchet_t = np.array([0.0, 0.042, 0.082, 0.120, 0.152])
    ratchet = clicks(c, ratchet_t, np.array([0.35, 0.42, 0.48, 0.56, 0.65]), 320, 2100, 0.004)
    torsion = karplus_strong(c.n, c.rng, 92.0, 0.175, 0.36, decay=0.985, damp=0.38, brighten=0.55, amp=0.75)
    arm_thump = modal_impact(c, 165.0, 0.175, (1.0, 1.85, 2.8), (0.065, 0.032, 0.016), (0.85, 0.42, 0.2), 600, 2800, 0.35, 0.003)
    whoosh = unit(swept_band(c.noise(), c.t, 280.0, 1450.0, 0.18, 0.22, q=1.2)) * env(c, 0.12, 0.02, 0.18) * 0.65
    return reverb(ratchet + torsion + arm_thump + whoosh, rt60=0.45, wet=0.20, predelay_ms=9.0)


def s_catapult_impact(c: Ctx) -> np.ndarray:
    seismic = np.tanh(2.2 * np.sin(glide(c, 82, 29, 0.11)) * env(c, 0.26)) * 0.95
    stone_crush = burst(c, 0.0, 0.12, 90, 1800, 0.9, 0.001)
    rubble_t = scatter(c, 32, 0.04, 0.62)
    rubble = clicks(c, rubble_t, 0.48 * c.rng.uniform(0.25, 1.0, 32) * (1.0 - rubble_t / 0.78), 550, 4200, 0.005)
    return reverb(seismic + stone_crush + rubble, rt60=0.64, wet=0.26, predelay_ms=10.0)


# --------------------------------------------------------------------------- Batalha, Horda, Stingers & Fisica


def s_horn(c: Ctx) -> np.ndarray:
    low = brass_note(c, NOTE["D2"], 0.0, 0.72, release=0.35, attack=0.08, detune_cents=(-8.0, 0.0, 8.0), bend=0.014, warmth_hz=1500.0)
    mid = brass_note(c, NOTE["D3"], 0.0, 0.70, release=0.32, attack=0.07, detune_cents=(-6.0, 0.0, 6.0), bend=0.014, warmth_hz=2100.0)
    fifth = brass_note(c, NOTE["A3"], 0.06, 0.62, release=0.30, attack=0.10, detune_cents=(-5.0, 5.0), bend=0.010, warmth_hz=1850.0)
    raw = 0.55 * low + 0.75 * mid + 0.35 * fifth
    return reverb(raw, rt60=0.85, wet=0.34, predelay_ms=16.0)


def s_horde_spawn(c: Ctx) -> np.ndarray:
    tear = unit(swept_band(c.noise(), c.t, 180.0, 3400.0, 0.0, 0.55, q=1.5)) * env(c, 0.36, 0.05) * 0.55
    choir = np.zeros(c.n)
    for f, a in ((73.42, 0.8), (110.0, 0.5), (146.83, 0.4)):
        choir += brass_note(c, f, 0.05, 0.90, release=0.42, attack=0.25, detune_cents=(-10.0, 0.0, 10.0), warmth_hz=950.0) * a
    pulse = np.sin(glide(c, 95, 42, 0.14)) * env(c, 0.30, 0.01) * 0.65
    return reverb(tear + choir + pulse, rt60=0.75, wet=0.30, predelay_ms=12.0)


def s_death_runner(c: Ctx) -> np.ndarray:
    # Exalacao espectral sem apito de senoide
    whisper = unit(swept_band(c.noise(), c.t, 1850.0, 480.0, 0.0, 0.24, q=2.0)) * env(c, 0.11, 0.008) * 0.72
    wisp = bell(c, 440.0, 0.0, (1.0, 1.49, 2.24), (0.09, 0.05, 0.03), (0.28, 0.16, 0.08))
    thump = modal_impact(c, 130.0, 0.09, (1.0, 1.8), (0.04, 0.02), (0.45, 0.2), 300, 1500, 0.2, 0.003)
    return reverb(whisper + wisp + thump, rt60=0.38, wet=0.20)


def s_death_brute(c: Ctx) -> np.ndarray:
    roar = brass_note(c, 82.41, 0.0, 0.26, release=0.22, attack=0.035, detune_cents=(-14.0, 0.0, 13.0), bend=-0.35, warmth_hz=820.0)
    gravel = eq_biquad(burst(c, 0.02, 0.18, 120, 680, 0.45, 0.02), "bp", 310.0, q=1.5)
    cleaver = modal_impact(c, 960.0, 0.26, (1.0, 1.67, 2.72), (0.11, 0.06, 0.03), (0.35, 0.22, 0.12), 2000, 6800, 0.25, 0.002)
    fall = np.tanh(1.9 * np.sin(glide(c, 92, 34, 0.08, 0.30)) * env(c, 0.16, 0.002, 0.30)) * 0.85
    return reverb(np.tanh(1.5 * (roar + gravel)) * 0.7 + cleaver + fall, rt60=0.55, wet=0.22)


def s_death_swarm(c: Ctx) -> np.ndarray:
    orb = modal_impact(c, 1860.0, 0.0, (1.0, 1.86, 2.95), (0.045, 0.025, 0.012), (0.55, 0.32, 0.16), 3200, 10500, 0.55, 0.002)
    fizz = unit(swept_band(c.noise(), c.t, 4200.0, 1800.0, 0.0, 0.12, q=1.6)) * env(c, 0.045, 0.002) * 0.45
    return reverb(orb + fizz, rt60=0.30, wet=0.16)


def s_wall_hit(c: Ctx) -> np.ndarray:
    ram = np.tanh(1.8 * np.sin(glide(c, 108, 44, 0.06)) * env(c, 0.14)) * 0.9
    oak = modal_impact(c, 155.0, 0.0, (1.0, 1.75, 2.8), (0.065, 0.035, 0.018), (0.75, 0.4, 0.2), 450, 2400, 0.5, 0.004)
    gravel = clicks(c, scatter(c, 16, 0.02, 0.32), 0.32 * c.rng.uniform(0.3, 1.0, 16), 850, 4400, 0.004)
    return reverb(ram + oak + gravel, rt60=0.45, wet=0.20)


def s_wall_alarm(c: Ctx) -> np.ndarray:
    ratios = (0.5, 1.0, 1.183, 1.506, 2.0, 2.514)
    decays = (0.48, 0.38, 0.30, 0.22, 0.14, 0.09)
    amps = (0.42, 0.95, 0.50, 0.42, 0.25, 0.14)
    a = modal_impact(c, NOTE["A5"], 0.0, ratios, decays, amps, 2400, 7500, 0.25, 0.002)
    b = modal_impact(c, NOTE["E5"], 0.44, ratios, decays, amps, 2200, 7000, 0.22, 0.002)
    return reverb(a + b, rt60=0.72, wet=0.28, predelay_ms=12.0)


def s_wall_heartbeat(c: Ctx) -> np.ndarray:
    lub = np.tanh(1.4 * np.sin(glide(c, 64, 38, 0.05, 0.03)) * env(c, 0.06, 0.015, 0.03))
    dub = np.tanh(1.3 * np.sin(glide(c, 54, 33, 0.05, 0.26)) * env(c, 0.065, 0.015, 0.26)) * 0.78
    return eq_biquad(lub + dub, "lp", 260.0, q=0.9)


def s_gate_fracture(c: Ctx) -> np.ndarray:
    boom = np.tanh(2.2 * np.sin(glide(c, 84, 28, 0.16)) * env(c, 0.45)) * 0.95
    beams = modal_impact(c, 138.0, 0.0, (1.0, 1.65, 2.48, 3.4), (0.18, 0.11, 0.06, 0.03), (0.8, 0.45, 0.25, 0.12), 400, 4200, 0.85, 0.006)
    iron = modal_impact(c, 480.0, 0.08, (1.0, 1.72, 2.65), (0.14, 0.08, 0.04), (0.45, 0.28, 0.16), 1600, 6500, 0.35, 0.003)
    times = scatter(c, 85, 0.03, 0.95, 1.9)
    debris = clicks(c, times, 0.55 * c.rng.uniform(0.2, 1.0, 85) * (1.0 - times / 1.15), 700, 5600, 0.004)
    return reverb(boom + beams + iron + debris, rt60=0.88, wet=0.30, predelay_ms=14.0)


def s_victory_sting(c: Ctx) -> np.ndarray:
    out = np.zeros(c.n)
    for i, name in enumerate(("D4", "A4", "D5", "Fs5")):
        out += brass_note(c, NOTE[name], i * 0.11, 0.14, release=0.14, attack=0.025, warmth_hz=3000.0) * 0.55
    # Climax em t=0.46s: acorde D maior orquestral + timpano + sino dourado
    for name, amp in (("D3", 0.65), ("A3", 0.55), ("D4", 0.70), ("Fs4", 0.55), ("A4", 0.60), ("D5", 0.55)):
        out += brass_note(c, NOTE[name], 0.46, 0.88, release=0.55, attack=0.045, vibrato=0.007, warmth_hz=2800.0) * amp
    out += np.tanh(1.6 * np.sin(glide(c, 130, 73.42, 0.08, 0.46)) * env(c, 0.38, 0.003, 0.46)) * 0.75
    out += bell(c, NOTE["D6"], 0.46, (1.0, 2.0, 3.0), (0.9, 0.45, 0.2), (0.35, 0.14, 0.06))
    return reverb(out, rt60=0.92, wet=0.32, predelay_ms=15.0)


def s_defeat_sting(c: Ctx) -> np.ndarray:
    out = np.zeros(c.n)
    for i, name in enumerate(("F4", "E4", "D4")):
        out += brass_note(c, NOTE[name], i * 0.24, 0.24, release=0.18, attack=0.04, warmth_hz=1700.0) * 0.6
    for name, amp in (("D2", 0.7), ("A2", 0.55), ("D3", 0.75), ("F3", 0.58), ("A3", 0.5)):
        out += brass_note(c, NOTE[name], 0.74, 0.72, release=0.58, attack=0.05, bend=-0.012, warmth_hz=1450.0) * amp
    out += np.tanh(1.8 * np.sin(glide(c, 105, 48, 0.10, 0.74)) * env(c, 0.42, 0.003, 0.74)) * 0.85
    out += modal_impact(c, NOTE["D4"], 0.74, (0.5, 1.0, 1.48, 2.15), (0.7, 0.55, 0.35, 0.2), (0.3, 0.25, 0.15, 0.08), 800, 3000, 0.15, 0.004)
    return reverb(out, rt60=0.95, wet=0.35, predelay_ms=16.0)


def s_phys_wood_impact(c: Ctx) -> np.ndarray:
    raw = modal_impact(c, 185.0, 0.0, (1.0, 1.85, 2.9), (0.04, 0.02, 0.01), (0.9, 0.45, 0.2), 600, 3200, 0.5, 0.003)
    return reverb(raw, rt60=0.25, wet=0.14)


def s_phys_stone_impact(c: Ctx) -> np.ndarray:
    raw = np.sin(glide(c, 155, 58, 0.04)) * env(c, 0.08) * 0.7 + burst(c, 0, 0.055, 180, 2400, 0.75)
    raw += clicks(c, scatter(c, 14, 0.01, 0.28), 0.32 * c.rng.uniform(0.3, 1.0, 14), 900, 4500, 0.004)
    return reverb(raw, rt60=0.40, wet=0.18)


def s_phys_iron_impact(c: Ctx) -> np.ndarray:
    raw = modal_impact(c, 860.0, 0.0, (1.0, 1.53, 2.40, 3.62), (0.14, 0.09, 0.06, 0.03), (0.55, 0.4, 0.25, 0.12), 2000, 8200, 0.35, 0.002)
    return reverb(raw, rt60=0.42, wet=0.18)


def s_phys_ice_shatter(c: Ctx) -> np.ndarray:
    times = scatter(c, 48, 0.0, 0.26, 1.5)
    raw = clicks(c, times, 0.5 * c.rng.uniform(0.3, 1.0, 48), 3000, 11500, 0.0025)
    raw += modal_impact(c, 2150.0, 0.0, (1.0, 2.76, 4.9), (0.10, 0.06, 0.03), (0.5, 0.3, 0.14), 3500, 11000, 0.25, 0.002)
    return reverb(raw, rt60=0.45, wet=0.20)


# --------------------------------------------------------------------------- OST Stems BGM (Loops perfeitos)


def _loop_drone(n: int, chords: tuple[tuple[int, int, tuple[str, ...]], ...], cutoff: float) -> np.ndarray:
    """Bordao/pad harmonico continuo sem emenda no loop (frequencias alinhadas ao ciclo)."""
    dur = n / SR
    t = np.arange(n, dtype=np.float64) / SR
    num_bars = 8
    bar_n = n // num_bars
    xfade = min(int(0.06 * SR), bar_n // 4)
    out = np.zeros((n, 2), dtype=np.float64)
    for b0, b1, notes in chords:
        s = b0 * bar_n
        e = (b1 * bar_n) if b1 < num_bars else n
        seg = np.zeros(n, dtype=np.float64)
        for idx, name in enumerate(notes):
            f_snap = round(NOTE[name] * dur) / dur
            tone = np.sin(TAU * f_snap * t) + 0.38 * np.sin(2.0 * TAU * f_snap * t) + 0.16 * np.sin(3.0 * TAU * f_snap * t)
            seg += tone * (1.0 if idx == 0 else 0.58)
        w = np.zeros(n, dtype=np.float64)
        w[s:e] = 1.0
        # Crossfade circular por janela dobrada
        win_len = (e - s)
        ramp_in = np.linspace(0.0, 1.0, xfade, endpoint=False)
        ramp_out = np.linspace(1.0, 0.0, xfade, endpoint=False)
        w[s : s + xfade] = ramp_in
        end_fade_start = (s + win_len - xfade) % n
        for k in range(xfade):
            pos = (s - xfade + k) % n
            w[pos] = max(w[pos], ramp_in[k])
        for k in range(xfade):
            pos = (e - xfade + k) % n
            w[pos] *= ramp_out[k]
        # Nota: sobreposicao cruzada simples nos limites de compasso
        seg *= w
        out[:, 0] += seg
        out[:, 1] += seg * (0.96 + 0.04 * np.cos(TAU * t / dur))
    # Remove cliques de borda com passagens suaves de filtro circular
    out[:, 0] = eq_biquad(out[:, 0], "lp", cutoff, q=0.72, circular=True)
    out[:, 1] = eq_biquad(out[:, 1], "lp", cutoff, q=0.72, circular=True)
    return out


def _place_loop_event(buf: np.ndarray, sig_l: np.ndarray, sig_r: np.ndarray, offset: int, n_cycle: int) -> None:
    """Escreve evento nas duas metades (0 e +n_cycle) do buffer 2*N para wrap-around limpo."""
    m = len(sig_l)
    for base in (offset, offset + n_cycle):
        if base < buf.shape[0]:
            span = min(m, buf.shape[0] - base)
            buf[base : base + span, 0] += sig_l[:span]
            buf[base : base + span, 1] += sig_r[:span]


def _drum_hit(rng: np.random.Generator, f0: float, f1: float, dur: float, click_hi: float) -> np.ndarray:
    m = int(round(dur * SR))
    t = np.arange(m, dtype=np.float64) / SR
    ph = TAU * np.cumsum(f1 + (f0 - f1) * np.exp(-t / 0.032)) / SR
    body = np.tanh(1.6 * np.sin(ph) * np.exp(-t / (dur * 0.38)))
    skin = eq_biquad(rng.standard_normal(m), "bp", click_hi, q=1.2) * np.exp(-t / 0.012) * 0.35
    return body + skin


def s_bgm_bastion(c: Ctx) -> np.ndarray:
    # 8 compassos 4/4 a 120 BPM (16.0s): atmosfera medieval calma em D Dorico
    n = c.n
    buf = np.zeros((2 * n, 2), dtype=np.float64)
    beat_sec = c.cue.duration / 32.0  # 0.500s

    # Arpejo de alaude/harpa Karplus-Strong (colcheias = 0.25s)
    patterns = (
        ("D4", "A4", "F4", "A4", "D5", "A4", "F4", "A4"),
        ("D4", "A4", "E5", "A4", "D5", "C5", "A4", "G4"),
        ("C4", "G4", "E4", "G4", "C5", "G4", "E4", "G4"),
        ("C4", "G4", "D5", "G4", "C5", "B4", "G4", "E4"),
        ("Bb3", "F4", "D4", "F4", "Bb4", "F4", "D4", "F4"),
        ("G3", "D4", "Bb4", "D4", "G4", "A4", "Bb4", "C5"),
        ("A3", "E4", "C5", "E4", "A4", "E4", "C5", "E4"),
        ("A3", "E4", "G4", "A4", "C5", "B4", "A4", "G4"),
    )
    for bar, notes in enumerate(patterns):
        for step_idx, name in enumerate(notes):
            t_ev = (bar * 4 + step_idx * 0.5) * beat_sec
            i0 = int(round(t_ev * SR))
            accent = 0.34 if step_idx % 2 == 0 else 0.24
            ks = karplus_strong(int(1.6 * SR), c.rng, NOTE[name], 0.0, 1.55, decay=0.9965, damp=0.28, brighten=0.45, amp=accent)
            pan = 0.38 if step_idx % 2 == 0 else 0.62
            _place_loop_event(buf, ks * (1.0 - pan) * 1.4, ks * pan * 1.4, i0, n)

    # Melodia doce nos tempos fortes (compassos pares/impares)
    melody = ((0.0, "F5", 2.2), (1.5, "E5", 1.8), (2.0, "D5", 2.4), (3.0, "C5", 2.0), (4.0, "D5", 2.5), (5.5, "Bb4", 2.0), (6.0, "A4", 2.6), (7.0, "C5", 2.2))
    for bar_pos, name, dur_b in melody:
        t_ev = bar_pos * 4.0 * beat_sec
        ks = karplus_strong(int(2.2 * SR), c.rng, NOTE[name], 0.0, dur_b * beat_sec, decay=0.9975, damp=0.22, brighten=0.55, amp=0.32)
        _place_loop_event(buf, ks * 0.72, ks * 0.68, int(round(t_ev * SR)), n)

    # Pulso suave de tambor de moldura (tempos 1 e 3.5)
    drum = _drum_hit(c.rng, 95.0, 52.0, 0.24, 320.0) * 0.34
    for bar in range(8):
        _place_loop_event(buf, drum, drum, int(round(bar * 4 * beat_sec * SR)), n)
        _place_loop_event(buf, drum * 0.55, drum * 0.55, int(round((bar * 4 + 2.5) * beat_sec * SR)), n)

    plucks_loop = buf[n : 2 * n]
    chords = (
        (0, 2, ("D2", "A2")),
        (2, 4, ("C2", "G2")),
        (4, 6, ("Bb2", "F3")),
        (6, 8, ("A2", "E3")),
    )
    drone = _loop_drone(n, chords, cutoff=460.0) * 0.42
    mix = drone + plucks_loop
    return reverb(mix, rt60=1.15, wet=0.30, predelay_ms=16.0, damp=0.45, loop=True)


def s_bgm_siege(c: Ctx) -> np.ndarray:
    # 8 compassos 4/4 a ~132 BPM (14.55s): marcha de cerco tatica em D menor
    n = c.n
    buf = np.zeros((2 * n, 2), dtype=np.float64)
    beat_sec = c.cue.duration / 32.0

    taiko = _drum_hit(c.rng, 108.0, 42.0, 0.30, 450.0) * 0.78
    frame = _drum_hit(c.rng, 210.0, 120.0, 0.14, 1400.0) * 0.42
    rim = eq_biquad(c.noise(int(0.05 * SR)), "bp", 1900.0, q=1.8) * np.exp(-np.arange(int(0.05 * SR)) / (0.008 * SR)) * 0.45

    bass_roots = ("D2", "D2", "Bb2", "C3", "D2", "G2", "Bb2", "A2")
    ostinato = (
        ("D3", "A3", "D3", "F3"),
        ("D3", "A3", "E3", "F3"),
        ("Bb2", "F3", "D3", "F3"),
        ("C3", "G3", "E3", "G3"),
        ("D3", "A3", "D3", "F3"),
        ("G2", "D3", "Bb2", "D3"),
        ("Bb2", "F3", "G3", "D4"),
        ("A2", "E3", "A3", "E3"),
    )

    for bar in range(8):
        for b in range(4):
            t_b = (bar * 4 + b) * beat_sec
            i_b = int(round(t_b * SR))
            if b in (0, 2):
                _place_loop_event(buf, taiko, taiko, i_b, n)
            if b in (1, 3):
                _place_loop_event(buf, rim * 0.9, rim * 1.1, i_b, n)
            if b == 3 and bar % 2 == 1:
                _place_loop_event(buf, frame, frame, int(round((t_b + 0.5 * beat_sec) * SR)), n)

        # Baixo pulsante em colcheias (spiccato grave)
        root_f = NOTE[bass_roots[bar]]
        for e_idx in range(8):
            t_e = (bar * 4 + e_idx * 0.5) * beat_sec
            note_name = ostinato[bar][e_idx % 4] if e_idx % 2 == 1 else bass_roots[bar]
            accent = 0.52 if e_idx % 2 == 0 else 0.34
            m = int(0.28 * SR)
            tt = np.arange(m, dtype=np.float64) / SR
            f_use = NOTE[note_name] if e_idx % 2 == 1 else root_f
            str_sig = (np.sin(TAU * f_use * tt) + 0.45 * np.sin(2 * TAU * f_use * tt) + 0.2 * np.sin(3 * TAU * f_use * tt)) * np.exp(-tt / 0.085) * np.clip(tt / 0.005, 0, 1) * accent
            pan = 0.44 if e_idx % 2 == 0 else 0.56
            _place_loop_event(buf, str_sig * (1 - pan) * 1.4, str_sig * pan * 1.4, int(round(t_e * SR)), n)

    drone = _loop_drone(n, ((0, 2, ("D2", "A2")), (2, 4, ("Bb2", "C3")), (4, 6, ("D2", "G2")), (6, 8, ("Bb2", "A2"))), cutoff=680.0) * 0.36
    mix = drone + buf[n : 2 * n]
    return reverb(mix, rt60=0.72, wet=0.22, predelay_ms=12.0, damp=0.35, loop=True)


def s_bgm_danger(c: Ctx) -> np.ndarray:
    # 8 compassos 4/4 sincronizados a `bgm_siege` (14.55s): camada vertical de perigo <30% muralha
    n = c.n
    buf = np.zeros((2 * n, 2), dtype=np.float64)
    beat_sec = c.cue.duration / 32.0

    snare = eq_biquad(c.noise(int(0.08 * SR)), "bp", 2400.0, q=1.3) * np.exp(-np.arange(int(0.08 * SR)) / (0.016 * SR)) * 0.45
    sub_hit = _drum_hit(c.rng, 88.0, 38.0, 0.22, 280.0) * 0.55

    for bar in range(8):
        for s_idx in range(16):  # semicolcheias urgentes
            t_s = (bar * 4 + s_idx * 0.25) * beat_sec
            i_s = int(round(t_s * SR))
            if s_idx % 4 == 0:
                _place_loop_event(buf, sub_hit, sub_hit, i_s, n)
            if s_idx % 2 == 1:
                gain = 0.72 if (s_idx % 4 == 2) else 0.45
                _place_loop_event(buf, snare * gain * 1.05, snare * gain * 0.95, i_s, n)

            # Tremolo tenso nas notasBb4 / A4 / Gs4
            f_tr = NOTE["Bb4"] if (bar % 4 in (2, 3)) else NOTE["A4"]
            m = int(0.14 * SR)
            tt = np.arange(m, dtype=np.float64) / SR
            trem = (np.sin(TAU * f_tr * tt) + 0.35 * np.sin(2 * TAU * f_tr * tt)) * np.exp(-tt / 0.045) * np.clip(tt / 0.004, 0, 1) * 0.22
            pan = 0.35 if s_idx % 2 == 0 else 0.65
            _place_loop_event(buf, trem * (1 - pan) * 1.4, trem * pan * 1.4, i_s, n)

        # Alerta dissonante de metais no inicio dos compassos pares
        if bar % 2 == 1:
            t_h = (bar * 4) * beat_sec
            i_h = int(round(t_h * SR))
            m = int(0.55 * SR)
            tt = np.arange(m, dtype=np.float64) / SR
            env_h = np.clip(tt / 0.04, 0, 1) * np.exp(-tt / 0.22)
            stab = (np.sin(TAU * NOTE["Bb3"] * tt) + 0.6 * np.sin(TAU * NOTE["E4"] * tt)) * env_h * 0.38
            _place_loop_event(buf, stab, stab, i_h, n)

    mix = buf[n : 2 * n]
    return reverb(mix, rt60=0.62, wet=0.20, predelay_ms=10.0, damp=0.35, loop=True)


# --------------------------------------------------------------------------- Catalogo CUES & SYNTH

CUES: tuple[Cue, ...] = (
    # Traps & sinergias
    Cue("archer_fire", "sfx", 0.26, "trap"),
    Cue("archer_impact", "sfx", 0.24, "trap"),
    Cue("tar_fire", "sfx", 0.60, "trap"),
    Cue("tar_ignite", "sfx", 0.75, "trap"),
    Cue("frost_fire", "sfx", 0.58, "trap"),
    Cue("frost_impact", "sfx", 0.48, "trap"),
    Cue("syn_thermal_shock", "sfx", 0.68, "trap"),
    Cue("cannon_fire", "sfx", 0.95, "trap"),
    Cue("cannon_impact", "sfx", 0.78, "trap"),
    Cue("catapult_fire", "sfx", 0.68, "trap"),
    Cue("catapult_impact", "sfx", 0.88, "trap"),
    # Build / economia
    Cue("build_place", "sfx", 0.30, "build"),
    Cue("build_move", "sfx", 0.26, "build"),
    Cue("build_remove", "sfx", 0.32, "build"),
    Cue("build_upgrade_2", "sfx", 0.55, "build"),
    Cue("build_upgrade_3", "sfx", 0.72, "build"),
    Cue("build_upgrade_4", "sfx", 0.82, "build"),
    Cue("build_upgrade_5", "sfx", 0.98, "build"),
    Cue("build_invalid", "sfx", 0.24, "build"),
    Cue("build_locked", "sfx", 0.38, "build"),
    Cue("coin_gain", "sfx", 0.45, "build"),
    Cue("coin_spend", "sfx", 0.34, "build"),
    # Batalha
    Cue("horde_spawn", "sfx", 1.50, "battle"),
    Cue("death_runner", "sfx", 0.36, "battle"),
    Cue("death_brute", "sfx", 0.72, "battle"),
    Cue("death_swarm", "sfx", 0.22, "battle"),
    Cue("wall_hit", "sfx", 0.52, "battle"),
    Cue("wall_alarm", "sfx", 1.10, "battle"),
    Cue("wall_heartbeat", "sfx", 0.75, "battle"),
    Cue("gate_fracture", "sfx", 1.45, "battle"),
    Cue("horn", "sfx", 1.35, "battle"),
    Cue("victory_sting", "stingers", 2.40, "battle"),
    Cue("defeat_sting", "stingers", 2.50, "battle"),
    # UI
    Cue("ui_click", "sfx", 0.08, "ui"),
    Cue("ui_toggle", "sfx", 0.14, "ui"),
    # Fisica F2 (SFX_Physics)
    Cue("phys_wood_impact", "sfx", 0.24, "physics"),
    Cue("phys_stone_impact", "sfx", 0.38, "physics"),
    Cue("phys_iron_impact", "sfx", 0.34, "physics"),
    Cue("phys_ice_shatter", "sfx", 0.40, "physics"),
    # Stems BGM seamless publicados (estereo)
    Cue("bgm_bastion", "bgm", 16.00, "music", publish=True, stereo=True, loop=True),
    Cue("bgm_siege", "bgm", 14.55, "music", publish=True, stereo=True, loop=True),
    Cue("bgm_danger", "bgm", 14.55, "music", publish=True, stereo=True, loop=True),
)

SYNTH: dict[str, Callable[[Ctx], np.ndarray]] = {
    "archer_fire": s_archer_fire,
    "archer_impact": s_archer_impact,
    "tar_fire": s_tar_fire,
    "tar_ignite": s_tar_ignite,
    "frost_fire": s_frost_fire,
    "frost_impact": s_frost_impact,
    "syn_thermal_shock": s_syn_thermal_shock,
    "cannon_fire": s_cannon_fire,
    "cannon_impact": s_cannon_impact,
    "catapult_fire": s_catapult_fire,
    "catapult_impact": s_catapult_impact,
    "build_place": s_build_place,
    "build_move": s_build_move,
    "build_remove": s_build_remove,
    "build_upgrade_2": s_build_upgrade_2,
    "build_upgrade_3": s_build_upgrade_3,
    "build_upgrade_4": s_build_upgrade_4,
    "build_upgrade_5": s_build_upgrade_5,
    "build_invalid": s_build_invalid,
    "build_locked": s_build_locked,
    "coin_gain": s_coin_gain,
    "coin_spend": s_coin_spend,
    "horde_spawn": s_horde_spawn,
    "death_runner": s_death_runner,
    "death_brute": s_death_brute,
    "death_swarm": s_death_swarm,
    "wall_hit": s_wall_hit,
    "wall_alarm": s_wall_alarm,
    "wall_heartbeat": s_wall_heartbeat,
    "gate_fracture": s_gate_fracture,
    "horn": s_horn,
    "victory_sting": s_victory_sting,
    "defeat_sting": s_defeat_sting,
    "ui_click": s_ui_click,
    "ui_toggle": s_ui_toggle,
    "phys_wood_impact": s_phys_wood_impact,
    "phys_stone_impact": s_phys_stone_impact,
    "phys_iron_impact": s_phys_iron_impact,
    "phys_ice_shatter": s_phys_ice_shatter,
    "bgm_bastion": s_bgm_bastion,
    "bgm_siege": s_bgm_siege,
    "bgm_danger": s_bgm_danger,
}

SMOKE_ENCODE = (
    "ui_click",
    "archer_fire",
    "cannon_fire",
    "syn_thermal_shock",
    "victory_sting",
    "bgm_bastion",
)

PUBLISH_PRIORITY = (
    "bgm_bastion",
    "bgm_siege",
    "bgm_danger",
    "victory_sting",
    "defeat_sting",
    "horn",
    "syn_thermal_shock",
    "build_upgrade_4",
    "build_upgrade_5",
    "build_move",
)

# --------------------------------------------------------------------------- loudness


def _k_weighting(n_fft: int) -> np.ndarray:
    w = TAU * np.fft.rfftfreq(n_fft, 1.0 / SR) / SR
    gain, q, fc = 4.0, 1.0 / np.sqrt(2.0), 1500.0
    big_a = 10 ** (gain / 40.0)
    w0 = TAU * fc / SR
    alpha = np.sin(w0) / (2 * q)
    cw, sa = np.cos(w0), 2 * np.sqrt(big_a) * alpha
    shelf_b = (
        big_a * ((big_a + 1) + (big_a - 1) * cw + sa),
        -2 * big_a * ((big_a - 1) + (big_a + 1) * cw),
        big_a * ((big_a + 1) + (big_a - 1) * cw - sa),
    )
    shelf_a = (
        (big_a + 1) - (big_a - 1) * cw + sa,
        2 * ((big_a - 1) - (big_a + 1) * cw),
        (big_a + 1) - (big_a - 1) * cw - sa,
    )
    hp_b, hp_a = _biquad_coeffs("hp", 38.0, q=0.5)
    return _biquad_response(shelf_b, shelf_a, w) * _biquad_response(hp_b, hp_a, w)


def loudness_lufs(x: np.ndarray) -> float:
    chans = [x] if x.ndim == 1 else [x[:, i] for i in range(x.shape[1])]
    n = chans[0].shape[0]
    n_fft = 2 * n
    weight = _k_weighting(n_fft)
    filtered = [np.fft.irfft(np.fft.rfft(ch, n_fft) * weight, n_fft)[:n] for ch in chans]
    block, hop = int(0.4 * SR), int(0.1 * SR)
    if n < block:
        ms = sum(float(np.mean(f * f)) for f in filtered)
        return -0.691 + 10 * np.log10(max(ms, 1e-12))
    powers = []
    for start in range(0, n - block + 1, hop):
        powers.append(sum(float(np.mean(f[start : start + block] ** 2)) for f in filtered))
    p = np.array(powers)
    lk = -0.691 + 10 * np.log10(np.maximum(p, 1e-12))
    gated = p[lk > -70.0]
    if len(gated) == 0:
        return -70.0
    rel = -0.691 + 10 * np.log10(np.mean(gated)) - 10.0
    final = p[(lk > -70.0) & (lk > rel)]
    return float(-0.691 + 10 * np.log10(np.mean(final if len(final) else gated)))


def peak_db(x: np.ndarray) -> float:
    return float(20 * np.log10(max(float(np.max(np.abs(x))), 1e-12)))


def normalize(x: np.ndarray, target_lufs: float = TARGET_LUFS) -> tuple[np.ndarray, float, float]:
    ceil = 10 ** (PEAK_CEIL_DB / 20)
    y = unit(x) * ceil
    level = loudness_lufs(y)
    if level > target_lufs:
        y = y * 10 ** ((target_lufs - level) / 20)
    else:
        drive_left = MAX_DRIVE_DB
        for _ in range(8):
            if level >= target_lufs - 0.4 or drive_left <= 0.05:
                break
            step = min(target_lufs - level, drive_left)
            g = 10 ** (step / 20)
            y = unit(np.tanh(y * g / ceil)) * ceil
            drive_left -= step
            level = loudness_lufs(y)
        if level > target_lufs:
            y = y * 10 ** ((target_lufs - level) / 20)
    return y, loudness_lufs(y), peak_db(y)


def edge_fade(x: np.ndarray) -> np.ndarray:
    n = x.shape[0]
    fi, fo = min(n, int(0.002 * SR)), min(n, int(0.012 * SR))
    ramp = np.ones(n)
    ramp[:fi] = np.linspace(0, 1, fi, endpoint=False)
    ramp[n - fo :] = np.minimum(ramp[n - fo :], np.linspace(1, 0, fo))
    return x * (ramp if x.ndim == 1 else ramp[:, None])


def render(cue: Cue) -> tuple[np.ndarray, float, float]:
    raw = SYNTH[cue.name](Ctx(cue))
    if not np.all(np.isfinite(raw)):
        raise RuntimeError(f"{cue.name}: NaN/Inf na sintese")
    if cue.loop:
        return normalize(raw, target_lufs=BGM_TARGET_LUFS)
    return normalize(edge_fade(raw), target_lufs=TARGET_LUFS)


# --------------------------------------------------------------------------- I/O


def write_ogg(cue: Cue, samples: np.ndarray, dest: Path, tmp: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    wav_path = tmp / f"{cue.name}.wav"
    pcm = np.clip(np.round(samples * 32767.0), -32767, 32767).astype("<i2")
    with wave.open(str(wav_path), "wb") as wf:
        wf.setnchannels(2 if cue.stereo else 1)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(pcm.tobytes())
    quality = "5" if cue.stereo else "6"
    cmd = [
        "ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path),
        "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact",
        "-ar", str(SR), "-ac", "2" if cue.stereo else "1",
        "-c:a", "libvorbis", "-q:a", quality, str(dest),
    ]  # fmt: skip
    subprocess.run(cmd, check=True)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_manifest() -> dict:
    if MANIFEST_PATH.exists():
        return json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    return {"schema": "muralha/sfx-manifest@1", "cues": {}}


def save_manifest(manifest: dict) -> None:
    MANIFEST_PATH.parent.mkdir(parents=True, exist_ok=True)
    manifest["cues"] = dict(sorted(manifest["cues"].items()))
    MANIFEST_PATH.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def generate_all() -> dict:
    manifest = load_manifest()
    manifest.update(
        {
            "schema": "muralha/sfx-manifest@1",
            "generator": "tools/gen-sfx.py",
            "sampleRate": SR,
            "targetLufs": TARGET_LUFS,
            "peakCeilDb": PEAK_CEIL_DB,
        }
    )
    old = manifest.get("cues", {})
    cues: dict[str, dict] = {}
    with tempfile.TemporaryDirectory() as tmp:
        for cue in CUES:
            samples, level, peak = render(cue)
            rel = Path(cue.folder) / f"{cue.name}.ogg"
            dest = AUDIO_ROOT / rel
            write_ogg(cue, samples, dest, Path(tmp))
            digest = sha256(dest)
            entry = {
                "file": rel.as_posix(),
                "group": cue.group,
                "duration": cue.duration,
                "channels": 2 if cue.stereo else 1,
                "loop": cue.loop,
                "lufs": round(level, 2),
                "peakDb": round(peak, 2),
                "sha256": digest,
                "bytes": dest.stat().st_size,
                "publish": cue.publish,
            }
            prev = old.get(cue.name, {})
            if prev.get("assetId") and prev.get("sha256") == digest:
                for key in ("assetId", "moderationState", "publishedAt"):
                    if key in prev:
                        entry[key] = prev[key]
            elif prev.get("assetId"):
                entry["staleAssetId"] = prev["assetId"]
            cues[cue.name] = entry
    manifest["cues"] = cues
    save_manifest(manifest)
    return manifest


# --------------------------------------------------------------------------- Open Cloud


def _session():
    import requests

    key = KEY_PATH.read_text(encoding="utf-8").strip()
    sess = requests.Session()
    sess.headers.update({"x-api-key": key})
    return sess


def _short(text: str, limit: int = 400) -> str:
    return text.replace("\n", " ")[:limit]


def fetch_moderation(sess, asset_id: str) -> str:
    resp = sess.get(f"{ASSETS_URL}/{asset_id}", params={"readMask": "moderationResult"}, timeout=30)
    if resp.status_code != 200:
        return f"HTTP{resp.status_code}"
    return str(resp.json().get("moderationResult", {}).get("moderationState", "Unknown"))


def publish(manifest: dict, only: set[str] | None) -> int:
    sess = _session()
    failures = 0
    prio_rank = {name: i for i, name in enumerate(PUBLISH_PRIORITY)}
    ordered = sorted(manifest["cues"].items(), key=lambda kv: (prio_rank.get(kv[0], 999), kv[0]))
    for name, entry in ordered:
        if not entry.get("publish") or entry.get("assetId"):
            continue
        if only and name not in only:
            continue
        path = AUDIO_ROOT / entry["file"]
        label = "BGM" if entry.get("group") == "music" else "SFX"
        request = {
            "assetType": "Audio",
            "displayName": f"Muralha {label} {name}"[:50],
            "description": f"MURALHA procedural {label} generated by tools/gen-sfx.py",
            "creationContext": {"creator": {"userId": CREATOR_USER_ID}},
        }
        op = None
        for attempt in range(5):
            with path.open("rb") as fh:
                resp = sess.post(
                    ASSETS_URL,
                    files={
                        "request": (None, json.dumps(request), "application/json"),
                        "fileContent": (path.name, fh, "audio/ogg"),
                    },
                    timeout=120,
                )
            if resp.status_code == 429 or resp.status_code >= 500:
                wait = 2.0 * (2**attempt)
                print(f"  {name}: HTTP{resp.status_code} retry em {wait:.0f}s")
                time.sleep(wait)
                continue
            if resp.status_code != 200:
                entry["lastError"] = f"HTTP{resp.status_code} {_short(resp.text)}"
                print(f"PUBLISH_FAIL {name}: {entry['lastError']}")
                failures += 1
                save_manifest(manifest)
                if resp.status_code in (401, 403):
                    return failures + 1000
                break
            op = resp.json()
            break
        if op is None:
            continue
        op_path = str(op.get("path", ""))
        deadline = time.time() + 90
        while not op.get("done") and time.time() < deadline:
            time.sleep(1.5)
            poll = sess.get(OPERATIONS_BASE + op_path, timeout=30)
            if poll.status_code == 200:
                op = poll.json()
        if not op.get("done"):
            entry["operationPath"] = op_path
            entry["lastError"] = "operation pending"
            print(f"PUBLISH_PENDING {name}: {op_path}")
            failures += 1
            save_manifest(manifest)
            continue
        response = op.get("response") or {}
        asset_id = str(response.get("assetId", ""))
        if not asset_id:
            entry["lastError"] = _short(json.dumps(op.get("error") or op))
            print(f"PUBLISH_FAIL {name}: {entry['lastError']}")
            failures += 1
            save_manifest(manifest)
            continue
        entry["assetId"] = asset_id
        entry["publishedAt"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        entry["moderationState"] = fetch_moderation(sess, asset_id)
        entry.pop("lastError", None)
        entry.pop("operationPath", None)
        entry.pop("staleAssetId", None)
        print(f"PUBLISH_OK {name} id={asset_id} moderation={entry['moderationState']}")
        save_manifest(manifest)
        time.sleep(0.8)
    return failures


def refresh_moderation(manifest: dict) -> None:
    sess = _session()
    for name, entry in manifest["cues"].items():
        if entry.get("assetId"):
            entry["moderationState"] = fetch_moderation(sess, entry["assetId"])
            print(f"  {name}: {entry['assetId']} {entry['moderationState']}")
    save_manifest(manifest)


def emit_luau(manifest: dict) -> Path:
    ids, durations = [], []
    for name, entry in sorted(manifest["cues"].items()):
        durations.append(f"\t{name} = {entry['duration']},")
        state = str(entry.get("moderationState", ""))
        asset_id = entry.get("assetId") or entry.get("staleAssetId")
        if asset_id and state not in ("Rejected",) and not state.startswith("HTTP"):
            ids.append(f'\t{name} = "rbxassetid://{asset_id}",')
    lines = [
        "--!strict",
        "-- GERADO por tools/gen-sfx.py --emit-luau a partir de assets/audio/manifest.json. Nao edite a mao.",
        "-- cue -> rbxassetid (Open Cloud, creator userId " + CREATOR_USER_ID + "). Cue sem id (ou cujo",
        "-- carregamento falhar) cai no placeholder offline rbxasset://sounds do AudioKit.",
        "",
        "local AudioAssets = {}",
        "",
        "AudioAssets.IDS = {",
        *ids,
        "} :: { [string]: string }",
        "",
        "-- Duracao em segundos (orcamento de vozes do pool e stems BGM).",
        "AudioAssets.DURATION = {",
        *durations,
        "} :: { [string]: number }",
        "",
        "return AudioAssets",
        "",
    ]
    LUAU_PATH.write_text("\n".join(lines), encoding="utf-8")
    return LUAU_PATH


# --------------------------------------------------------------------------- smoke


def smoke() -> int:
    if set(SYNTH) != {c.name for c in CUES}:
        raise SystemExit("ERRO: SYNTH e CUES divergem")
    problems = []
    for cue in CUES:
        a, level, peak = render(cue)
        b, _, _ = render(cue)
        if not np.array_equal(a, b):
            problems.append(f"{cue.name}: nao deterministico")
        if peak > -0.99:
            problems.append(f"{cue.name}: pico {peak:.2f} dBFS > -1")
        if not (-20.0 <= level <= -12.0):
            problems.append(f"{cue.name}: loudness {level:.1f} LUFS fora de [-20,-12]")
        if cue.loop:
            seam = float(np.max(np.abs(a[0] - a[-1])))
            if seam >= 0.12:
                problems.append(f"{cue.name}: costura do loop {seam:.4f} >= 0.12")
    SMOKE_DIR.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for cue in (c for c in CUES if c.name in SMOKE_ENCODE):
            dest = SMOKE_DIR / f"{cue.name}.ogg"
            write_ogg(cue, render(cue)[0], dest, Path(tmp))
            first = sha256(dest)
            write_ogg(cue, render(cue)[0], dest, Path(tmp))
            if sha256(dest) != first or dest.stat().st_size < 512:
                problems.append(f"{cue.name}: OGG nao bitexact ou vazio")
    if LUAU_PATH.exists():
        text = LUAU_PATH.read_text(encoding="utf-8")
        names = {c.name for c in CUES}
        for line in text.splitlines():
            stripped = line.strip()
            if "=" in stripped and stripped.endswith(",") and not stripped.startswith("--"):
                key = stripped.split("=", 1)[0].strip()
                if key not in names:
                    problems.append(f"AudioAssets.luau: cue desconhecido {key}")
    if problems:
        for p in problems:
            print(f"  FALHOU: {p}")
        return 1
    print(f"SFX_SMOKE_OK cues={len(CUES)} encoded={len(SMOKE_ENCODE)} dir={SMOKE_DIR.relative_to(ROOT)}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="SFX/OST deterministicos da MURALHA (-14 LUFS, OGG) + Open Cloud.")
    parser.add_argument("--list", action="store_true", help="lista os cues")
    parser.add_argument("--smoke", action="store_true", help="sintetiza tudo, checa determinismo/loudness, codifica amostra")
    parser.add_argument("--publish", action="store_true", help="sobe OGGs sem assetId (Assets API, Audio)")
    parser.add_argument("--only", default="", help="lista de cues separada por virgula para --publish")
    parser.add_argument("--refresh-moderation", action="store_true", help="relê moderationState")
    parser.add_argument("--emit-luau", action="store_true", help="regenera src/shared/visual/AudioAssets.luau")
    parser.add_argument("--no-generate", action="store_true", help="nao re-sintetiza antes de publicar/emitir")
    args = parser.parse_args()

    if args.list:
        for c in CUES:
            print(f"{c.folder}/{c.name}.ogg\t{c.duration:.2f}s\t{c.group}\t{'publish' if c.publish else 'local'}")
        return 0
    if not shutil.which("ffmpeg"):
        raise SystemExit("ERRO: ffmpeg nao encontrado no PATH (rode source scripts/env.sh).")
    if args.smoke:
        return smoke()

    only_actions = args.publish or args.refresh_moderation or args.emit_luau
    if args.no_generate or (only_actions and MANIFEST_PATH.exists() and not args.publish):
        manifest = load_manifest()
    else:
        manifest = generate_all()
        print(f"SFX_GEN_OK count={len(manifest['cues'])} dir={AUDIO_ROOT.relative_to(ROOT)}")
    rc = 0
    if args.publish:
        only = {s.strip() for s in args.only.split(",") if s.strip()} or None
        rc = publish(manifest, only)
    if args.refresh_moderation:
        refresh_moderation(manifest)
    if args.publish or args.emit_luau or args.refresh_moderation:
        print(f"LUAU_OK {emit_luau(manifest).relative_to(ROOT)}")
    return 0 if rc == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
