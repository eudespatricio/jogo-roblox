"""Gera os troncos/capuzes/carapacas esculpidos da horda (CMD_runner, CMD_brute, CMD_swarm,
CMD_shieldbearer, CMD_pyromancer, CMD_sapper, CMD_wisp, CMD_drake).

Desenho hibrido articulado: a malha Open Cloud contem APENAS o torso, armadura/manto,
ombros/ombreiras e cabeca/capuz/chifres (sem pernas nem bracos estaticos), para que o
HordeKit.luau articule pernas, bracos, asas, cauda, escudo e satelites a 60 Hz em torno do pivo.

Mapeamento Roblox -> Blender (frente -Z no Studio = -Y no Blender): (x, y, z) -> (-x, z, y).

Uso headless:
  blender -b --factory-startup --python-exit-code 1 --python art/scripts/make_horde.py
Saidas: art/export/horde_<tipo>.glb, art/forge/lote_horde_import.yaml (gerado),
        art/renders/horde/*.png (ignorado no git)
"""

from __future__ import annotations

import math
import os
import sys

sys.dont_write_bytecode = True  # sem __pycache__ em art/scripts
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lowpoly_lib as L  # noqa: E402

LIMITE = 2800
SUAVIZACAO_HORDE = {
    "modo": "hard_surface",
    "angulo_graus": 48,
    "weighted_normals": True,
    "corrective_smooth": False,
}
SCALE = {
    "runner": 0.85,
    "brute": 1.35,
    "swarm": 0.65,
    "shieldbearer": 1.12,
    "pyromancer": 0.95,
    "sapper": 0.88,
    "wisp": 0.72,
    "drake": 1.18,
}  # VisualTheme.ENEMIES[*].scale


class Rb:
    """Constroi em coordenadas Roblox escaladas por scale*1.8 (frente -Z -> Blender -Y)."""

    def __init__(self, kind):
        self.k = SCALE[kind] * 1.8

    def p(self, x, y, z):
        return (-x * self.k, z * self.k, y * self.k)

    def ball(self, diam, pos, color, seg=18, rings=12, squash=(1.0, 1.0, 1.0)):
        return L.ball(
            diam / 2 * self.k,
            self.p(*pos),
            color,
            seg=seg,
            rings=rings,
            squash=(squash[0], squash[2], squash[1]),
        )

    def ico(self, rad, pos, color, squash=(1.0, 1.0, 1.0), subdiv=2):
        return L.ico(
            rad * self.k,
            self.p(*pos),
            color,
            squash=(squash[0], squash[2], squash[1]),
            subdiv=subdiv,
        )

    def cyl(self, r, h, base, color, verts=18, r2=None, rot_z=0.0):
        return L.cyl(
            r * self.k,
            h * self.k,
            self.p(*base),
            color,
            verts=verts,
            r2=None if r2 is None else r2 * self.k,
            rot_z=rot_z,
        )

    def crystal(self, r, h, base, color, tilt=(0.0, 0.0), verts=6, r2=0.0, spin=0.0):
        return L.crystal(
            r * self.k,
            h * self.k,
            self.p(*base),
            color,
            tilt=tilt,
            verts=verts,
            r2=r2 * self.k,
            spin=spin,
        )

    def torus(
        self,
        r_major,
        r_minor,
        pos,
        color,
        major_seg=18,
        minor_seg=8,
        rot=(0.0, 0.0, 0.0),
        squash=(1.0, 1.0, 1.0),
    ):
        return L.torus(
            r_major * self.k,
            r_minor * self.k,
            self.p(*pos),
            color,
            major_seg=major_seg,
            minor_seg=minor_seg,
            rot=rot,
            squash=(squash[0], squash[2], squash[1]),
        )

    def capsule_seg(self, p0, p1, r0, r1, color, verts=14, cap_ends=False):
        return L.capsule_seg(
            self.p(*p0),
            self.p(*p1),
            r0 * self.k,
            r1 * self.k,
            color,
            verts=verts,
            cap_ends=cap_ends,
        )


def runner():
    """Spectral Stalker Wraith: manto fluido, costelas arcanas, gola runica e capuz pontiagudo."""
    r = Rb("runner")
    p = []

    # Saia conica suave + pontas esfarrapadas + cinto torus runico
    p.append(r.cyl(0.80, 0.88, (0, 0.25, 0), "tealDark", r2=0.48))
    for k in range(8):
        a = 2 * math.pi * k / 8
        p.append(
            r.crystal(
                0.16,
                0.66,
                (0.64 * math.cos(a), 0.56, 0.64 * math.sin(a)),
                "teal" if k % 2 == 0 else "tealDark",
                tilt=(-math.pi + 0.34 * math.sin(a), 0.34 * math.cos(a)),
                verts=5,
            )
        )

    p.append(r.cyl(0.54, 0.22, (0, 0.94, 0), "ironDark", r2=0.50))
    p.append(r.torus(0.53, 0.055, (0, 1.04, 0), "tealSwarm", major_seg=18, minor_seg=6))
    p.append(r.ico(0.56, (0, 1.46, -0.02), "teal", squash=(1.05, 1.15, 0.80)))
    p.append(r.ico(0.45, (0, 1.38, 0.20), "tealDark", squash=(0.88, 1.02, 0.68)))

    # Crista dorsal + costelas espectrais curvadas (capsule_seg)
    for dy, dz, sz in ((1.22, 0.34, 0.42), (1.56, 0.38, 0.50), (1.88, 0.30, 0.38)):
        p.append(r.crystal(0.13, sz, (0, dy, dz), "tealDark", tilt=(-1.05, 0.0), verts=5))
    for idx, ry in enumerate((1.24, 1.46, 1.68)):
        w = 0.36 + idx * 0.05
        for sx in (-1, 1):
            p.append(r.capsule_seg((sx * 0.08, ry, -0.34), (sx * w, ry + 0.06, -0.18), 0.06, 0.04, "tealSwarm", verts=10))

    # Gola torus + capuz pontiagudo de ceifador + visor e chifres curvos
    p.append(r.cyl(0.64, 0.32, (0, 1.82, 0.02), "tealDark", r2=0.45))
    p.append(r.ball(0.94, (0, 2.28, -0.02), "teal", squash=(0.95, 1.05, 1.12)))
    p.append(r.torus(0.36, 0.055, (0, 2.22, -0.28), "tealDark", major_seg=16, minor_seg=6, rot=(math.pi / 2, 0.0, 0.0)))
    p.append(r.crystal(0.40, 0.88, (0, 2.40, 0.16), "tealDark", tilt=(-0.92, 0.0), verts=8))
    p.append(r.ball(0.60, (0, 2.24, -0.28), "ironDark", seg=14, rings=8, squash=(0.92, 0.88, 0.72)))
    for sx in (-1, 1):
        p.append(r.ico(0.12, (sx * 0.16, 2.24, -0.56), "eyeNeon", squash=(1.35, 0.68, 0.72)))
        p.append(r.capsule_seg((sx * 0.22, 2.52, -0.02), (sx * 0.42, 2.84, 0.22), 0.11, 0.06, "iron", verts=10))
        p.append(r.capsule_seg((sx * 0.42, 2.84, 0.22), (sx * 0.56, 3.16, 0.48), 0.06, 0.015, "ironDark", verts=10))

    return p


def brute():
    """Horned Rift Juggernaut: cintura blindada, peitoral de obsidiana, ombreiras torus e chifres."""
    b = Rb("brute")
    p = []

    # Cintura blindada + anel torus + placa ventral + saiote
    p.append(b.cyl(0.66, 0.36, (0, 0.70, 0), "tealBruteDark", r2=0.60))
    p.append(b.torus(0.64, 0.075, (0, 0.86, 0), "iron", major_seg=18, minor_seg=6))
    p.append(b.ico(0.26, (0, 0.88, -0.58), "tealSwarm", squash=(0.95, 0.85, 0.48)))
    for sx in (-1, 1):
        p.append(b.crystal(0.24, 0.62, (sx * 0.56, 0.84, 0.0), "ironDark", tilt=(-math.pi, -sx * 0.28), verts=5))

    # Tronco musculoso + peitoral de obsidiana + nucleo da fenda com colar torus
    p.append(b.ico(0.76, (0, 1.38, 0.0), "tealBrute", squash=(1.18, 1.06, 0.84)))
    p.append(b.ico(0.50, (0, 1.56, 0.22), "tealBruteDark", squash=(1.05, 0.84, 0.72)))
    for sx in (-1, 1):
        p.append(b.ico(0.38, (sx * 0.34, 1.52, -0.34), "ironDark", squash=(0.92, 0.82, 0.54)))
    p.append(b.torus(0.24, 0.045, (0, 1.38, -0.46), "ironDark", major_seg=14, minor_seg=6, rot=(math.pi / 2, 0.0, 0.0)))
    p.append(b.crystal(0.18, 0.52, (0, 1.34, -0.54), "eyeNeon", tilt=(1.40, 0.0), verts=6))
    for k in range(3):
        p.append(b.crystal(0.14, 0.44, (0, 1.18 + k * 0.28, 0.48), "ironDark", tilt=(-1.05, 0.0), verts=5))

    # Ombreiras curvadas com friso torus e presas
    for sx in (-1, 1):
        p.append(b.ball(0.74, (sx * 0.78, 1.72, -0.02), "iron", seg=16, rings=10, squash=(1.05, 0.78, 1.02)))
        p.append(b.torus(0.38, 0.055, (sx * 0.78, 1.66, -0.02), "ironDark", major_seg=16, minor_seg=6, rot=(0.0, sx * 0.4, 0.0)))
        p.append(b.capsule_seg((sx * 0.80, 1.92, 0.0), (sx * 1.06, 2.38, 0.06), 0.12, 0.02, "steel", verts=10))
        p.append(b.crystal(0.11, 0.46, (sx * 0.96, 1.74, 0.14), "ironDark", tilt=(-0.38, -sx * 0.78), verts=5))

    # Elmo/cranio + mandibula + chifres curvos
    p.append(b.ico(0.46, (0, 2.12, -0.18), "tealBruteDark", squash=(0.96, 0.94, 1.04)))
    p.append(b.ico(0.34, (0, 1.92, -0.30), "ironDark", squash=(0.88, 0.58, 0.78)))
    for sx in (-1, 1):
        p.append(b.ico(0.105, (sx * 0.16, 2.15, -0.52), "eyeNeon", squash=(1.35, 0.65, 0.65)))
        p.append(b.crystal(0.06, 0.24, (sx * 0.14, 1.92, -0.50), "steel", tilt=(0.35, -sx * 0.14), verts=5))
        p.append(b.capsule_seg((sx * 0.26, 2.24, -0.14), (sx * 0.54, 2.46, -0.28), 0.13, 0.08, "ironDark", verts=10))
        p.append(b.capsule_seg((sx * 0.54, 2.46, -0.28), (sx * 0.68, 2.74, -0.52), 0.08, 0.02, "hornIvory", verts=10))

    return p


def swarm():
    """Phantom Skull Wisp: cranio espectral suave, halo torus, chifres e fios de ectoplasma."""
    w = Rb("swarm")
    p = []

    # Cranio suave + maxilar + orbita escura + olhos neon
    p.append(w.ball(0.84, (0, 1.38, -0.02), "tealSwarm", squash=(0.98, 1.04, 0.98)))
    p.append(w.ico(0.48, (0, 1.02, -0.14), "tealSwarmDark", squash=(0.84, 0.76, 0.84)))
    p.append(w.ball(0.64, (0, 1.38, -0.40), "ironDark", seg=14, rings=8, squash=(0.96, 0.68, 0.66)))
    p.append(w.torus(0.64, 0.055, (0, 1.02, 0.06), "tealDark", major_seg=18, minor_seg=6, rot=(0.24, 0.0, 0.0)))
    for sx in (-1, 1):
        p.append(w.ico(0.145, (sx * 0.22, 1.40, -0.66), "eyeNeon", squash=(1.25, 0.72, 0.68)))
        p.append(w.capsule_seg((sx * 0.30, 1.66, 0.0), (sx * 0.56, 2.02, 0.18), 0.13, 0.07, "tealDark", verts=10))
        p.append(w.capsule_seg((sx * 0.56, 2.02, 0.18), (sx * 0.72, 2.34, 0.40), 0.07, 0.015, "eyeNeon", verts=10))

    # Crista dorsal + 6 fios de ectoplasma curvados
    for k in range(3):
        p.append(
            w.crystal(
                0.13,
                0.50 - k * 0.08,
                (0, 1.80 - k * 0.28, 0.28 + k * 0.18),
                "eyeNeon" if k == 0 else "tealSwarm",
                tilt=(-0.72 - k * 0.22, 0.0),
                verts=5,
            )
        )
    for k in range(6):
        a = 2 * math.pi * k / 6
        px, pz = 0.34 * math.cos(a), 0.34 * math.sin(a)
        p.append(w.capsule_seg((px, 0.86, pz), (px * 1.35, 0.36, pz * 1.35 + 0.18), 0.10, 0.02, "tealSwarmDark", verts=8))

    return p


def shieldbearer():
    """Escudeiro: elmo com viseira neon, gorjal torus, ombreiras e escudo-torre chanfrado."""
    s = Rb("shieldbearer")
    p = []

    p.append(s.cyl(0.64, 0.34, (0, 0.68, 0), "ironDark", r2=0.58))
    p.append(s.torus(0.62, 0.06, (0, 0.84, 0), "steel", major_seg=18, minor_seg=6))
    p.append(s.ico(0.24, (0, 0.86, -0.52), "teal", squash=(1.1, 0.8, 0.45)))
    for sx in (-1, 1):
        p.append(s.crystal(0.20, 0.56, (sx * 0.52, 0.80, 0.0), "iron", tilt=(-math.pi, -sx * 0.25), verts=5))

    # Peitoral + gorjal torus + crista dorsal
    p.append(s.ico(0.68, (0, 1.36, 0.02), "iron", squash=(1.12, 1.05, 0.82)))
    p.append(s.ico(0.56, (0, 1.44, -0.22), "steel", squash=(1.02, 0.88, 0.55)))
    p.append(s.torus(0.46, 0.065, (0, 1.82, -0.02), "ironDark", major_seg=18, minor_seg=6))
    p.append(s.crystal(0.16, 0.44, (0, 1.32, -0.56), "teal", tilt=(1.42, 0.0), verts=5))
    for k in range(3):
        p.append(s.crystal(0.11, 0.36, (0, 1.18 + k * 0.26, 0.44), "ironDark", tilt=(-1.05, 0.0), verts=5))

    # Motivo de escudo-torre chanfrado com umbo torus e runa
    p.append(L.box((0.92 * s.k, 0.16 * s.k, 1.28 * s.k), s.p(0.22, 1.24, -0.58), "ironDark", bevel=0.04))
    p.append(L.box((1.02 * s.k, 0.10 * s.k, 1.38 * s.k), s.p(0.22, 1.24, -0.54), "steel", bevel=0.03))
    p.append(s.torus(0.24, 0.045, (0.22, 1.24, -0.66), "teal", major_seg=16, minor_seg=6, rot=(math.pi / 2, 0.0, 0.0)))
    p.append(s.crystal(0.14, 0.32, (0.22, 1.24, -0.68), "tealSwarm", tilt=(1.55, 0.0), verts=6))

    # Ombreiras blindadas com aro torus
    for sx in (-1, 1):
        p.append(s.ball(0.68, (sx * 0.72, 1.66, 0.0), "iron", seg=14, rings=9, squash=(1.08, 0.82, 0.98)))
        p.append(s.torus(0.32, 0.05, (sx * 0.74, 1.60, 0.0), "steel", major_seg=14, minor_seg=5, rot=(0.0, sx * 0.35, 0.0)))
        p.append(s.crystal(0.11, 0.44, (sx * 0.80, 1.88, 0.02), "steel", tilt=(0.0, -sx * 0.55), verts=5))

    # Elmo fechado com viseira luminosa e crista alta
    p.append(s.ball(0.86, (0, 2.16, -0.06), "iron", squash=(0.96, 1.02, 1.06)))
    p.append(s.ico(0.38, (0, 2.12, -0.34), "ironDark", squash=(1.05, 0.55, 0.48)))
    p.append(s.ico(0.18, (0, 2.14, -0.48), "eyeNeon", squash=(1.85, 0.36, 0.35)))
    for k in range(4):
        p.append(
            s.crystal(
                0.11,
                0.48 - k * 0.05,
                (0, 2.52 - k * 0.08, -0.10 + k * 0.18),
                "teal" if k % 2 == 0 else "steel",
                tilt=(-0.35 - k * 0.30, 0.0),
                verts=5,
            )
        )

    return p


def pyromancer():
    """Piroforjador: manto fluido, fornalha peitoral com gaiola de ferro, halo runico torus e chifres."""
    y = Rb("pyromancer")
    p = []

    p.append(y.cyl(0.74, 0.84, (0, 0.28, 0), "stoneDark", r2=0.46))
    p.append(y.torus(0.50, 0.055, (0, 1.04, 0), "ember", major_seg=18, minor_seg=6))
    for k in range(6):
        a = 2 * math.pi * k / 6
        p.append(
            y.crystal(
                0.16,
                0.56,
                (0.58 * math.cos(a), 0.54, 0.58 * math.sin(a)),
                "tealDark" if k % 2 == 0 else "ironDark",
                tilt=(-math.pi + 0.30 * math.sin(a), 0.30 * math.cos(a)),
                verts=5,
            )
        )

    # Torso + nucleo incandescente cercado por anel torus e barras de ferro
    p.append(y.cyl(0.48, 0.20, (0, 0.96, 0), "ironDark", r2=0.46))
    p.append(y.ico(0.54, (0, 1.44, 0.02), "stoneDark", squash=(1.05, 1.12, 0.82)))
    p.append(y.ball(0.44, (0, 1.44, -0.30), "amberBright", seg=14, rings=8, squash=(0.95, 1.10, 0.65)))
    p.append(y.torus(0.28, 0.045, (0, 1.44, -0.36), "ironDark", major_seg=16, minor_seg=6, rot=(math.pi / 2, 0.0, 0.0)))
    for sx in (-1, 1):
        p.append(y.capsule_seg((sx * 0.24, 1.24, -0.34), (sx * 0.18, 1.64, -0.36), 0.045, 0.035, "ironDark", verts=8))

    # Colar runico flutuante torus + cristais orbitais
    p.append(y.torus(0.70, 0.04, (0, 1.88, 0.02), "amberBright", major_seg=18, minor_seg=6, rot=(0.15, 0.0, 0.0)))
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.3
        p.append(
            y.crystal(
                0.095,
                0.38,
                (0.70 * math.cos(a), 1.88 + 0.05 * (k % 2), 0.62 * math.sin(a)),
                "amberBright" if k % 2 == 0 else "tealSwarm",
                tilt=(-0.28 * math.sin(a), -0.28 * math.cos(a)),
                verts=5,
            )
        )

    # Gola alta + capuz de brasa + chifres curvos
    p.append(y.cyl(0.58, 0.28, (0, 1.80, 0.04), "ironDark", r2=0.44))
    p.append(y.ball(0.88, (0, 2.24, -0.02), "stoneDark", squash=(0.96, 1.04, 1.12)))
    p.append(y.crystal(0.38, 0.84, (0, 2.38, 0.14), "ember", tilt=(-0.88, 0.0), verts=8))
    p.append(y.ball(0.56, (0, 2.20, -0.28), "ironDark", seg=12, rings=8, squash=(0.92, 0.86, 0.72)))
    for sx in (-1, 1):
        p.append(y.ico(0.11, (sx * 0.15, 2.22, -0.54), "amberBright", squash=(1.3, 0.65, 0.68)))
        p.append(y.capsule_seg((sx * 0.22, 2.48, -0.02), (sx * 0.42, 2.80, 0.18), 0.10, 0.055, "danger", verts=10))
        p.append(y.capsule_seg((sx * 0.42, 2.80, 0.18), (sx * 0.54, 3.10, 0.42), 0.055, 0.015, "amberBright", verts=10))

    return p


def sapper():
    """Zapador: colete tatico, bandoleira de cargas, caldeira de polvora torus e oculos de demolicao."""
    z = Rb("sapper")
    p = []

    p.append(z.cyl(0.56, 0.28, (0, 0.74, 0), "ironDark", r2=0.52))
    p.append(z.torus(0.54, 0.055, (0, 0.88, 0), "bronze", major_seg=18, minor_seg=5))
    p.append(z.ico(0.56, (0, 1.32, 0.0), "tealDark", squash=(1.04, 1.06, 0.82)))
    p.append(z.ico(0.46, (0, 1.36, -0.20), "iron", squash=(0.94, 0.92, 0.56)))

    # Bandoleira diagonal de granadas cilindricas
    for k in range(4):
        t = (k - 1.5) / 1.5
        px, py, pz = t * 0.34, 1.38 - t * 0.24, -0.44
        p.append(z.capsule_seg((px - 0.04, py - 0.06, pz), (px + 0.04, py + 0.08, pz), 0.085, 0.085, "bronze" if k % 2 == 0 else "danger", verts=10))

    # Caldeira/barril de polvora nas costas (+Z Roblox / +Y Blender) com aros torus de bronze
    p.append(z.cyl(0.42, 0.86, (0, 1.02, 0.50), "woodDark", r2=0.40))
    p.append(z.torus(0.43, 0.055, (0, 1.22, 0.50), "bronze", major_seg=16, minor_seg=5))
    p.append(z.torus(0.43, 0.055, (0, 1.62, 0.50), "bronze", major_seg=16, minor_seg=5))
    p.append(z.capsule_seg((0, 1.86, 0.50), (0, 2.18, 0.60), 0.05, 0.03, "ironDark", verts=8))
    p.append(z.ico(0.11, (0, 2.22, 0.62), "amberBright"))

    for sx in (-1, 1):
        p.append(z.ico(0.32, (sx * 0.62, 1.62, 0.0), "ironDark", squash=(0.95, 0.75, 0.92)))

    # Capuz justo + oculos de bronze torus com lentes neon
    p.append(z.ball(0.84, (0, 2.08, -0.04), "tealDark", squash=(0.96, 1.0, 1.02)))
    p.append(z.ball(0.56, (0, 2.04, -0.26), "ironDark", seg=10, rings=6, squash=(0.94, 0.82, 0.72)))
    for sx in (-1, 1):
        p.append(z.torus(0.14, 0.04, (sx * 0.18, 2.08, -0.49), "bronze", major_seg=14, minor_seg=5, rot=(math.pi / 2, 0.0, 0.0)))
        p.append(z.ico(0.11, (sx * 0.18, 2.08, -0.54), "eyeNeon", squash=(0.95, 0.95, 0.55)))
        p.append(z.crystal(0.08, 0.36, (sx * 0.34, 2.34, 0.06), "iron", tilt=(-0.45, -sx * 0.60), verts=5))

    return p


def wisp():
    """Arcane Wisp: nucleo aninhado arcaneCyan/eyeNeon, 2 aneis runicos torus, cristais e cauda espectral (+Y)."""
    w = Rb("wisp")
    p = []

    # Esferas de energia aninhadas (frente em -Y Blender / -Z Roblox)
    p.append(w.ball(1.10, (0, 1.38, -0.04), "arcaneCyan", squash=(0.95, 1.08, 1.02)))
    p.append(w.ball(0.72, (0, 1.38, -0.14), "eyeNeon", seg=16, rings=10, squash=(0.92, 1.04, 0.95)))
    p.append(w.ico(0.42, (0, 1.36, -0.34), "tealDark", squash=(1.05, 0.78, 0.48)))
    for sx in (-1, 1):
        p.append(w.ico(0.11, (sx * 0.16, 1.40, -0.58), "iceGlow", squash=(1.35, 0.72, 0.68)))

    # 2 aneis runicos torus inclinados e cruzados
    p.append(w.torus(0.92, 0.055, (0, 1.38, 0.0), "goldBright", major_seg=20, minor_seg=6, rot=(0.55, 0.45, 0.0)))
    p.append(w.torus(0.82, 0.05, (0, 1.38, 0.0), "arcaneCyan", major_seg=20, minor_seg=6, rot=(-0.60, -0.40, 0.30)))

    # Cristais arcanos flutuantes
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.4
        p.append(
            w.crystal(
                0.12,
                0.42,
                (0.76 * math.cos(a), 1.38 + 0.24 * math.sin(2 * a), 0.76 * math.sin(a)),
                "iceGlow" if k % 2 == 0 else "arcaneCyan",
                tilt=(-0.25 * math.sin(a), 0.25 * math.cos(a)),
                verts=6,
            )
        )

    # Cauda espectral giratoria apontando para tras (+Z Roblox / +Y Blender), frente em -Y
    p.append(w.capsule_seg((0, 1.32, 0.18), (0, 1.16, 0.72), 0.32, 0.18, "teal", verts=12))
    p.append(w.capsule_seg((0, 1.16, 0.72), (0, 1.26, 1.28), 0.18, 0.03, "arcaneCyan", verts=12))
    for sx in (-1, 1):
        p.append(w.capsule_seg((sx * 0.22, 1.10, 0.22), (sx * 0.42, 0.84, 0.76), 0.16, 0.08, "tealDark", verts=10))
        p.append(w.capsule_seg((sx * 0.42, 0.84, 0.76), (sx * 0.18, 0.62, 1.18), 0.08, 0.015, "eyeNeon", verts=10))
    # Gota inferior para ancora da base (altura ~2.4 studs no pivo)
    p.append(w.capsule_seg((0, 0.88, 0.02), (0, 0.42, 0.28), 0.18, 0.03, "tealDark", verts=10))

    return p


def drake():
    """Armored Rift Wyvern/Drake: peitoral crimsonCloth/obsidian, colar brass torus, pescoco S e cranio."""
    d = Rb("drake")
    p = []

    # Torso draconico + peitoral escamado crimsonCloth/obsidian (sem asas, cauda ou pernas)
    p.append(d.ball(1.16, (0, 1.14, 0.04), "obsidian", seg=16, rings=10, squash=(0.94, 0.90, 1.32)))
    for idx, (py, pz, rad) in enumerate(((0.86, -0.34, 0.34), (1.16, -0.44, 0.40), (1.44, -0.46, 0.36))):
        col = "crimsonCloth" if idx % 2 == 0 else "crimsonBright"
        p.append(d.ico(rad, (0, py, pz), col, squash=(1.05, 0.72, 0.64)))
    for sx in (-1, 1):
        p.append(d.ico(0.32, (sx * 0.48, 1.42, 0.08), "obsidianLight", squash=(0.75, 0.90, 1.10)))

    # Colar torus de latao (brass) na base do pescoco
    p.append(d.torus(0.44, 0.07, (0, 1.58, -0.34), "brass", major_seg=18, minor_seg=6, rot=(0.62, 0.0, 0.0)))

    # Pescoco sinuoso em S para a frente (-Z Roblox / -Y Blender) e cima
    p.append(d.capsule_seg((0, 1.46, -0.24), (0, 1.86, -0.46), 0.36, 0.28, "obsidian", verts=14))
    p.append(d.capsule_seg((0, 1.86, -0.46), (0, 2.22, -0.58), 0.28, 0.24, "crimsonCloth", verts=14))

    # Cranio draconico voltado para -Y Blender (-Z Roblox) com focinho, mandibula, boca/olhos brasa e chifres
    p.append(d.ball(0.68, (0, 2.30, -0.74), "obsidian", seg=14, rings=8, squash=(0.88, 0.80, 1.14)))
    p.append(d.capsule_seg((0, 2.30, -0.84), (0, 2.24, -1.36), 0.23, 0.12, "crimsonCloth", verts=10))
    p.append(d.capsule_seg((0, 2.12, -0.82), (0, 2.10, -1.26), 0.18, 0.09, "obsidianLight", verts=10))
    p.append(d.ico(0.14, (0, 2.20, -1.04), "ember", squash=(0.85, 0.45, 1.25)))
    for sx in (-1, 1):
        p.append(d.ico(0.09, (sx * 0.20, 2.36, -0.96), "emberDeep", squash=(1.2, 0.7, 0.8)))
        p.append(d.capsule_seg((sx * 0.20, 2.46, -0.66), (sx * 0.36, 2.74, -0.32), 0.10, 0.055, "obsidianLight", verts=10))
        p.append(d.capsule_seg((sx * 0.36, 2.74, -0.32), (sx * 0.46, 2.98, 0.04), 0.055, 0.015, "hornIvory", verts=10))
        p.append(d.crystal(0.075, 0.28, (sx * 0.26, 2.24, -0.64), "brass", tilt=(-0.6, -sx * 0.65), verts=5))

    # Crista dorsal de espinhos ao longo das costas e pescoco
    for sy, sz, h in ((1.06, 0.56, 0.36), (1.36, 0.36, 0.40), (1.72, -0.06, 0.36), (2.06, -0.34, 0.32), (2.42, -0.54, 0.28)):
        p.append(d.crystal(0.09, h, (0, sy, sz), "brass", tilt=(-0.82, 0.0), verts=5))

    return p


def specs():
    out = []
    for kind, fn in (
        ("runner", runner),
        ("brute", brute),
        ("swarm", swarm),
        ("shieldbearer", shieldbearer),
        ("pyromancer", pyromancer),
        ("sapper", sapper),
        ("wisp", wisp),
        ("drake", drake),
    ):
        out.append(
            {
                "id": f"horde.{kind}.01",
                "name": f"CMD_{kind}",
                "glb": f"horde_{kind}.glb",
                "tipo": "prop_estatico",
                "limite": LIMITE,
                "suavizacao_normais": SUAVIZACAO_HORDE,
                "tags": ["muralha", "horde", kind],
                "build": fn,
            }
        )
    return out


L.run_group("horde", specs(), "torso/capuz esculpido da horda hibrida (art/scripts/make_horde.py)")
