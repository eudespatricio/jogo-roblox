#!/usr/bin/env python3
"""Gerador/normalizador offline de placeholders SFX & stem BGM (-14 LUFS OGG).

Zero dependencias externas alem de Python 3 stdlib + ffmpeg.
Uso:
  python3 tools/gen-sfx.py --list
  python3 tools/gen-sfx.py --smoke
  python3 tools/gen-sfx.py --out assets/audio
"""

from __future__ import annotations

import argparse
import math
import os
import random
import shutil
import struct
import subprocess
import tempfile
import wave
from dataclasses import dataclass
from pathlib import Path

SAMPLE_RATE = 44100


@dataclass(frozen=True)
class CueSpec:
    cue: str
    folder: str
    duration: float
    kind: str
    stereo: bool = False


CUES: tuple[CueSpec, ...] = (
    # UI & Build
    CueSpec("ui_click", "sfx", 0.08, "ui_click"),
    CueSpec("ui_deny", "sfx", 0.18, "ui_deny"),
    CueSpec("trap_place", "sfx", 0.24, "wood_thud"),
    CueSpec("trap_upgrade", "sfx", 0.42, "chime_up"),
    # P1 / P2 Combate
    CueSpec("archer_fire", "sfx", 0.14, "twang"),
    CueSpec("cannon_fire", "sfx", 0.48, "boom"),
    CueSpec("frost_burst", "sfx", 0.36, "crystal"),
    CueSpec("tar_splash", "sfx", 0.30, "squelch"),
    CueSpec("catapult_launch", "sfx", 0.45, "catapult"),
    CueSpec("gate_hit", "sfx", 0.28, "heavy_wood"),
    CueSpec("wall_heartbeat", "sfx", 0.72, "heartbeat"),
    # Fisica Real Hibrida
    CueSpec("phys_wood_hit", "sfx", 0.22, "wood_thud"),
    CueSpec("phys_stone_crash", "sfx", 0.38, "stone_crash"),
    CueSpec("phys_iron_clang", "sfx", 0.34, "iron_clang"),
    CueSpec("phys_ice_shatter", "sfx", 0.35, "crystal"),
    # Bosses & Co-op & Stingers
    CueSpec("boss_telegraph_horn", "sfx", 0.95, "horn"),
    CueSpec("boss_slam", "sfx", 0.60, "boom"),
    CueSpec("coop_ping_defend", "sfx", 0.25, "ping_high"),
    CueSpec("coop_gold_sent", "sfx", 0.32, "coin"),
    CueSpec("finisher_subdrop", "stingers", 0.90, "subdrop"),
    CueSpec("victory_stinger", "stingers", 1.40, "fanfare_up"),
    CueSpec("defeat_stinger", "stingers", 1.40, "fanfare_down"),
    # Stem BGM adaptativo (4 compassos a 120 BPM = 8.000s exatos)
    CueSpec("stem_bastion_120bpm", "bgm", 8.00, "bgm_loop", stereo=True),
)

SMOKE_CUES = ("ui_click", "cannon_fire", "phys_ice_shatter", "boss_telegraph_horn", "stem_bastion_120bpm")


def clamp16(val: float) -> int:
    return max(-32767, min(32767, int(val * 32767.0)))


def synth_samples(spec: CueSpec) -> list[int]:
    n = int(SAMPLE_RATE * spec.duration)
    rng = random.Random(hash(spec.cue) & 0xFFFFFFFF)
    out: list[int] = []
    phase = 0.0
    phase2 = 0.0

    for i in range(n):
        t = i / SAMPLE_RATE
        u = t / spec.duration
        env = math.exp(-5.0 * u) * min(1.0, t / 0.004)
        l_val = 0.0
        r_val = 0.0

        if spec.kind == "ui_click":
            f = 920.0 - 320.0 * u
            phase += 2.0 * math.pi * f / SAMPLE_RATE
            l_val = math.sin(phase) * math.exp(-26.0 * u) * 0.7
        elif spec.kind == "ui_deny":
            f = 240.0 if int(t * 24) % 2 == 0 else 175.0
            phase += 2.0 * math.pi * f / SAMPLE_RATE
            l_val = (1.0 if math.sin(phase) >= 0 else -1.0) * 0.35 * env
        elif spec.kind in ("wood_thud", "heavy_wood"):
            f = (165.0 if spec.kind == "wood_thud" else 115.0) * math.exp(-7.0 * u) + 52.0
            phase += 2.0 * math.pi * f / SAMPLE_RATE
            noise = (rng.random() * 2.0 - 1.0) * math.exp(-22.0 * u) * 0.4
            l_val = (math.sin(phase) * 0.8 + noise) * math.exp(-9.0 * u)
        elif spec.kind in ("chime_up", "coin"):
            notes = (523.25, 659.25, 783.99, 1046.5) if spec.kind == "chime_up" else (987.77, 1318.51)
            f = notes[min(len(notes) - 1, int(u * len(notes)))]
            phase += 2.0 * math.pi * f / SAMPLE_RATE
            l_val = (math.sin(phase) + 0.3 * math.sin(phase * 2.0)) * env * 0.65
        elif spec.kind == "twang":
            f = 380.0 + 180.0 * math.exp(-15.0 * u)
            phase += 2.0 * math.pi * f / SAMPLE_RATE
            l_val = (math.sin(phase) + 0.4 * math.sin(phase * 3.0)) * math.exp(-12.0 * u) * 0.65
        elif spec.kind in ("boom", "subdrop"):
            f0 = 135.0 if spec.kind == "boom" else 110.0
            f = f0 * math.exp(-4.5 * u) + 34.0
            phase += 2.0 * math.pi * f / SAMPLE_RATE
            noise = (rng.random() * 2.0 - 1.0) * math.exp(-8.0 * u) * (0.45 if spec.kind == "boom" else 0.15)
            l_val = math.tanh((math.sin(phase) * 1.3 + noise) * math.exp(-3.2 * u)) * 0.85
        elif spec.kind == "crystal":
            f = 1480.0 + 620.0 * (i % 7) / 7.0
            phase += 2.0 * math.pi * f / SAMPLE_RATE
            noise = (rng.random() * 2.0 - 1.0) * math.exp(-11.0 * u) * 0.55
            l_val = (math.sin(phase) * 0.5 + noise) * math.exp(-7.5 * u)
        elif spec.kind in ("squelch", "stone_crash"):
            f = 220.0 * math.exp(-3.5 * u) + 60.0
            phase += 2.0 * math.pi * f / SAMPLE_RATE
            noise = (rng.random() * 2.0 - 1.0) * 0.7
            l_val = (math.sin(phase) * 0.45 + noise) * math.exp(-6.0 * u)
        elif spec.kind == "catapult":
            f = 140.0 + 280.0 * u
            phase += 2.0 * math.pi * f / SAMPLE_RATE
            l_val = math.sin(phase) * math.sin(math.pi * u) * 0.75
        elif spec.kind == "heartbeat":
            beat1 = math.exp(-((t - 0.08) / 0.045) ** 2)
            beat2 = math.exp(-((t - 0.30) / 0.055) ** 2) * 0.8
            l_val = math.sin(2.0 * math.pi * 58.0 * t) * (beat1 + beat2) * 0.9
        elif spec.kind == "iron_clang":
            l_val = (
                math.sin(2.0 * math.pi * 880.0 * t) * 0.45
                + math.sin(2.0 * math.pi * 1347.0 * t) * 0.35
                + math.sin(2.0 * math.pi * 2110.0 * t) * 0.20
            ) * math.exp(-8.5 * u)
        elif spec.kind == "horn":
            f = 146.83 * (1.0 - 0.04 * u)
            phase += 2.0 * math.pi * f / SAMPLE_RATE
            l_val = math.tanh((math.sin(phase) + 0.5 * math.sin(phase * 2.0) + 0.25 * math.sin(phase * 3.0)) * 1.1) * 0.7 * min(1.0, t / 0.05) * (1.0 - max(0.0, (u - 0.8) / 0.2))
        elif spec.kind == "ping_high":
            phase += 2.0 * math.pi * 1174.66 / SAMPLE_RATE
            l_val = math.sin(phase) * math.exp(-10.0 * u) * 0.75
        elif spec.kind in ("fanfare_up", "fanfare_down"):
            seq = (293.66, 369.99, 440.00, 587.33) if spec.kind == "fanfare_up" else (392.00, 349.23, 311.13, 261.63)
            f = seq[min(3, int(u * 4))]
            phase += 2.0 * math.pi * f / SAMPLE_RATE
            l_val = (math.sin(phase) + 0.35 * math.sin(phase * 2.0)) * 0.65 * min(1.0, t / 0.02) * (1.0 - u * 0.6)
        elif spec.kind == "bgm_loop":
            # Loop exatamente em 120 BPM (0.5s/beat): D minor arpeggio + pulso grave
            beat = t / 0.5
            step = int(beat * 2) % 8
            arp = (293.66, 349.23, 440.0, 349.23, 261.63, 329.63, 392.0, 440.0)[step]
            bass = 73.42 if (int(beat) % 4) < 2 else 65.41
            phase += 2.0 * math.pi * arp / SAMPLE_RATE
            phase2 += 2.0 * math.pi * bass / SAMPLE_RATE
            pulse = math.exp(-6.0 * (beat - math.floor(beat)))
            pad = math.sin(phase2) * 0.45 * (0.4 + 0.6 * pulse)
            pluck = math.sin(phase) * 0.30 * math.exp(-5.0 * ((beat * 2) - math.floor(beat * 2)))
            fade_edge = min(1.0, t / 0.01, (spec.duration - t) / 0.01)
            l_val = (pad + pluck) * fade_edge
            r_val = (pad + math.sin(phase * 1.003) * 0.28 * math.exp(-5.0 * ((beat * 2) - math.floor(beat * 2)))) * fade_edge

        if spec.stereo:
            out.append(clamp16(l_val))
            out.append(clamp16(r_val))
        else:
            out.append(clamp16(l_val))

    return out


def write_and_normalize(spec: CueSpec, out_root: Path, tmp_dir: Path) -> Path:
    dest_dir = out_root / spec.folder
    dest_dir.mkdir(parents=True, exist_ok=True)
    wav_path = tmp_dir / f"{spec.cue}.wav"
    ogg_path = dest_dir / f"{spec.cue}.ogg"

    samples = synth_samples(spec)
    channels = 2 if spec.stereo else 1
    with wave.open(str(wav_path), "wb") as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(struct.pack(f"<{len(samples)}h", *samples))

    cmd = [
        "ffmpeg",
        "-y",
        "-loglevel",
        "error",
        "-i",
        str(wav_path),
        "-af",
        "loudnorm=I=-14:TP=-1.0:LRA=11",
        "-ar",
        str(SAMPLE_RATE),
        "-ac",
        str(channels),
        "-c:a",
        "libvorbis",
        "-q:a",
        "5" if not spec.stereo else "4",
        str(ogg_path),
    ]
    subprocess.run(cmd, check=True)
    return ogg_path


def main() -> int:
    parser = argparse.ArgumentParser(description="Sintetizador e normalizador OGG (-14 LUFS) para MURALHA.")
    parser.add_argument("--list", action="store_true", help="Lista todos os cues configurados")
    parser.add_argument("--smoke", action="store_true", help="Gera 5 cues representativos em build/sfx-smoke/")
    parser.add_argument("--out", default="build/sfx-generated", help="Diretorio destino dos .ogg")
    args = parser.parse_args()

    if args.list:
        for c in CUES:
            ch = "stereo" if c.stereo else "mono"
            print(f"{c.folder}/{c.cue}.ogg\t{c.duration:.2f}s\t{ch}")
        return 0

    if not shutil.which("ffmpeg"):
        raise SystemExit("ERRO: ffmpeg nao encontrado no PATH (rode source scripts/env.sh).")

    target_dir = Path("build/sfx-smoke" if args.smoke else args.out)
    selected = [c for c in CUES if not args.smoke or c.cue in SMOKE_CUES]

    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        generated = [write_and_normalize(spec, target_dir, tmp_path) for spec in selected]

    print(f"SFX_GEN_OK count={len(generated)} dir={target_dir}")
    for p in generated:
        print(f"  {p} ({p.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
