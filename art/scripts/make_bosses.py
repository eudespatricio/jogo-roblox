"""Gera os 5 Bosses esculpidos da campanha (BOSS_iron_ram_colossus, BOSS_slag_juggernaut,
BOSS_rime_matriarch, BOSS_powder_baron, BOSS_rift_titan) e suas 25 sub-malhas articuladas.

Silhuetas imponentes com curvas suaves (weighted normals) e chanfros precisos para ocupacao
multi-lane na arena.
Mapeamento Roblox -> Blender (frente -Z no Studio = -Y no Blender): (x, y, z) -> (-x, z, y).

Uso headless:
  blender -b --factory-startup --python-exit-code 1 --python art/scripts/make_bosses.py
Saidas: art/export/boss_<bossId>.glb, art/export/boss_<bossId>_<part>.glb,
        art/forge/lote_bosses_import.yaml (gerado), art/renders/bosses/*.png (ignorado no git)
"""

from __future__ import annotations

import math
import os
import sys

sys.dont_write_bytecode = True  # sem __pycache__ em art/scripts
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lowpoly_lib as L  # noqa: E402

LIMITE = 5200
LIMITE_TORSO = 2800
LIMITE_PART = 1600
SCALE = {
    "iron_ram_colossus": 2.4,
    "slag_juggernaut": 2.5,
    "rime_matriarch": 2.45,
    "powder_baron": 2.4,
    "rift_titan": 2.75,
}


class Rb:
    """Constroi em coordenadas Roblox escaladas por scale*1.8 (frente -Z -> Blender -Y)."""

    def __init__(self, boss_id: str):
        self.k = SCALE[boss_id] * 1.8

    def p(self, x: float, y: float, z: float):
        return (-x * self.k, z * self.k, y * self.k)

    def ball(self, diam, pos, color, seg=20, rings=14, squash=(1.0, 1.0, 1.0)):
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

    def cyl(self, r, h, base, color, verts=20, r2=None, rot_z=0.0, bevel=0.0):
        return L.cyl(
            r * self.k,
            h * self.k,
            self.p(*base),
            color,
            verts=verts,
            r2=None if r2 is None else r2 * self.k,
            bevel=bevel * self.k,
            rot_z=rot_z,
        )

    def cyl_axis_y(self, r, length, center, color, verts=20, r2=None, tilt=0.0, bevel=0.0):
        # Em Blender, axis='y' com tilt positivo inclina -Y (frente) para cima (+Z).
        return L.cyl_axis(
            r * self.k,
            length * self.k,
            self.p(*center),
            color,
            axis="y",
            verts=verts,
            r2=None if r2 is None else r2 * self.k,
            tilt=tilt,
            bevel=bevel * self.k,
        )

    def crystal(self, r, h, base, color, tilt=(0.0, 0.0), verts=5, r2=0.0, spin=0.0):
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

    def box(self, size, center, color, rot=(0.0, 0.0, 0.0), bevel=0.03, bevel_segs=1):
        return L.box(
            (size[0] * self.k, size[2] * self.k, size[1] * self.k),
            self.p(*center),
            color,
            bevel=bevel * self.k,
            rot=rot,
            bevel_segs=bevel_segs,
        )

    def torus(
        self,
        r_major,
        r_minor,
        pos,
        color,
        major_seg=20,
        minor_seg=10,
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

    def capsule_seg(self, p0, p1, r0, r1, color, verts=18, cap_ends=False):
        return L.capsule_seg(
            self.p(*p0),
            self.p(*p1),
            r0 * self.k,
            r1 * self.k,
            color,
            verts=verts,
            cap_ends=cap_ends,
        )


def _curved_siege_horn(
    b: Rb,
    p0: tuple[float, float, float],
    p1: tuple[float, float, float],
    p2: tuple[float, float, float],
    p3: tuple[float, float, float],
    r_base: float,
    col_base: str = "steel",
    col_tip: str = "hornIvory",
    verts: int = 18,
    three_seg: bool = True,
):
    """Chifre de cerco curvo em segmentos suaves (18 lados)."""
    if not three_seg:
        return [
            b.capsule_seg(p0, p2, r_base, r_base * 0.45, col_base, verts=verts),
            b.capsule_seg(p2, p3, r_base * 0.43, 0.012, col_tip, verts=verts),
        ]
    return [
        b.capsule_seg(p0, p1, r_base, r_base * 0.72, col_base, verts=verts),
        b.capsule_seg(p1, p2, r_base * 0.70, r_base * 0.38, col_base, verts=verts),
        b.capsule_seg(p2, p3, r_base * 0.36, 0.012, col_tip, verts=verts),
    ]


# ==============================================================================
# ACT 1 — IRON RAM COLOSSUS
# ==============================================================================
def iron_ram_colossus():
    """Act 1: Colosso Ariete com grevas chanfradas, fornalha com anel torus, chifres curvos 18-seg e manoplas-ariete."""
    b = Rb("iron_ram_colossus")
    p = []

    # 1. Grevas chanfradas de cerco + espigoes de joelho
    for sx in (-1, 1):
        lx = sx * 0.44
        p.append(b.cyl(0.32, 0.88, (lx, 0.0, 0.0), "ironDark", verts=18, r2=0.26))
        p.append(b.box((0.46, 0.24, 0.64), (lx, 0.12, -0.10), "iron", bevel=0.035))
        p.append(b.box((0.36, 0.48, 0.18), (lx, 0.44, -0.18), "iron", bevel=0.03))
        p.append(b.box((0.38, 0.24, 0.24), (lx, 0.54, -0.14), "steel", bevel=0.03))
        p.append(
            b.capsule_seg(
                (lx, 0.54, -0.22),
                (lx, 0.66, -0.52),
                0.12,
                0.015,
                "steel",
                verts=18,
            )
        )

    # 2. Cintura e torso blindado + grade de fornalha com anel torus e rebites
    p.append(b.cyl(0.62, 0.36, (0.0, 0.82, 0.0), "ironDark", verts=20, r2=0.58))
    p.append(b.torus(0.60, 0.055, (0.0, 0.96, 0.0), "iron", major_seg=18, minor_seg=8))
    p.append(b.ico(0.76, (0.0, 1.48, 0.02), "iron", squash=(1.18, 1.05, 0.86), subdiv=2))
    p.append(b.ico(0.40, (0.0, 1.46, -0.44), "ember", squash=(0.95, 1.05, 0.55), subdiv=2))
    p.append(b.ico(0.28, (0.0, 1.46, -0.52), "amberBright", squash=(0.85, 0.90, 0.45), subdiv=2))
    p.append(
        b.torus(
            0.38,
            0.055,
            (0.0, 1.46, -0.58),
            "ironDark",
            major_seg=18,
            minor_seg=8,
            rot=(math.pi / 2, 0.0, 0.0),
        )
    )
    for sx in (-1, 1):
        p.append(b.box((0.11, 0.62, 0.14), (sx * 0.16, 1.46, -0.62), "ironDark", bevel=0.025))
        p.append(b.box((0.28, 0.52, 0.18), (sx * 0.48, 1.48, -0.44), "iron", rot=(0.0, sx * 0.28, 0.0), bevel=0.03))
    p.append(b.box((0.72, 0.11, 0.14), (0.0, 1.46, -0.62), "ironDark", bevel=0.025))

    # 3. Ombreiras de cerco com chifres curvos de 18 segmentos
    for sx in (-1, 1):
        p.append(b.ball(0.76, (sx * 0.82, 1.82, 0.0), "iron", seg=16, rings=10, squash=(1.06, 0.88, 1.02)))
        p.append(b.box((0.52, 0.20, 0.56), (sx * 0.86, 1.92, -0.02), "ironDark", rot=(0.0, 0.0, -sx * 0.22), bevel=0.03))
        p += _curved_siege_horn(
            b,
            (sx * 0.86, 2.02, 0.02),
            (sx * 1.12, 2.22, -0.06),
            (sx * 1.24, 2.48, -0.26),
            (sx * 1.14, 2.72, -0.52),
            0.16,
            col_base="steel",
            col_tip="hornIvory",
            verts=18,
        )

    # 4. Bracos e manoplas-ariete pesadas com cintas de ferro e runas ambar
    for sx in (-1, 1):
        p.append(b.cyl(0.24, 0.78, (sx * 0.94, 0.96, -0.18), "ironDark", verts=16, r2=0.22))
        p.append(b.box((0.52, 0.48, 0.86), (sx * 0.92, 0.92, -0.62), "iron", bevel=0.035))
        p.append(b.box((0.56, 0.16, 0.22), (sx * 0.92, 0.96, -0.46), "ironDark", bevel=0.03))
        p.append(b.box((0.56, 0.16, 0.22), (sx * 0.92, 0.94, -0.78), "ironDark", bevel=0.03))
        p.append(b.box((0.12, 0.14, 0.58), (sx * 1.16, 0.96, -0.62), "amberBright", bevel=0.02))
        p.append(b.cyl_axis_y(0.22, 0.46, (sx * 0.92, 0.92, -1.12), "steel", verts=18, r2=0.08, tilt=0.0))

    # 5. Elmo de cerco com viseira de fornalha e chifres frontais curvos 18-seg
    p.append(b.ball(0.62, (0.0, 2.18, -0.12), "ironDark", seg=16, rings=10, squash=(0.98, 0.94, 1.02)))
    p.append(b.box((0.46, 0.14, 0.24), (0.0, 2.16, -0.42), "amberBright", bevel=0.02))
    for sx in (-1, 1):
        p += _curved_siege_horn(
            b,
            (sx * 0.26, 2.30, -0.08),
            (sx * 0.48, 2.48, -0.22),
            (sx * 0.56, 2.72, -0.46),
            (sx * 0.44, 2.94, -0.72),
            0.14,
            col_base="steel",
            col_tip="hornIvory",
            verts=18,
        )

    return p


def iron_ram_colossus_torso():
    """A1 Torso: cintura blindada, peitoral com grade de fornalha + anel torus/rebites, ombreiras e elmo com chifres 18-seg."""
    b = Rb("iron_ram_colossus")
    p = [
        b.cyl(0.62, 0.36, (0.0, 0.82, 0.0), "ironDark", verts=20, r2=0.58),
        b.torus(0.60, 0.055, (0.0, 0.96, 0.0), "iron", major_seg=16, minor_seg=6),
        b.ico(0.76, (0.0, 1.48, 0.02), "iron", squash=(1.18, 1.05, 0.86), subdiv=2),
        b.ico(0.42, (0.0, 1.46, -0.44), "ember", squash=(0.95, 1.05, 0.55), subdiv=2),
        b.ico(0.28, (0.0, 1.46, -0.52), "amberBright", squash=(0.85, 0.90, 0.45), subdiv=1),
        b.torus(
            0.38,
            0.055,
            (0.0, 1.46, -0.58),
            "ironDark",
            major_seg=16,
            minor_seg=6,
            rot=(math.pi / 2, 0.0, 0.0),
        ),
        b.box((0.72, 0.11, 0.14), (0.0, 1.46, -0.62), "ironDark", bevel=0.025),
        b.box((0.64, 0.09, 0.12), (0.0, 1.28, -0.60), "ironDark", bevel=0.0),
        b.box((0.64, 0.09, 0.12), (0.0, 1.64, -0.60), "ironDark", bevel=0.0),
        b.ball(0.62, (0.0, 2.18, -0.12), "ironDark", seg=14, rings=8, squash=(0.98, 0.94, 1.02)),
        b.box((0.48, 0.14, 0.24), (0.0, 2.16, -0.42), "amberBright", bevel=0.02),
        b.box((0.18, 0.36, 0.34), (0.0, 2.38, -0.10), "iron", bevel=0.03),
    ]
    for sx in (-1, 1):
        p.append(b.box((0.11, 0.62, 0.14), (sx * 0.16, 1.46, -0.62), "ironDark", bevel=0.025))
        p.append(b.box((0.28, 0.52, 0.18), (sx * 0.48, 1.48, -0.44), "iron", rot=(0.0, sx * 0.28, 0.0), bevel=0.03))
        p.append(b.box((0.14, 0.14, 0.12), (sx * 0.32, 1.66, -0.58), "amberBright", bevel=0.0))
        p.append(b.box((0.14, 0.14, 0.12), (sx * 0.32, 1.26, -0.58), "amberBright", bevel=0.0))
        p.append(b.ball(0.76, (sx * 0.82, 1.82, 0.0), "iron", seg=14, rings=8, squash=(1.06, 0.88, 1.02)))
        p.append(
            b.box(
                (0.52, 0.20, 0.56),
                (sx * 0.86, 1.92, -0.02),
                "ironDark",
                rot=(0.0, 0.0, -sx * 0.22),
                bevel=0.03,
            )
        )
        p += _curved_siege_horn(
            b,
            (sx * 0.86, 2.02, 0.02),
            (sx * 1.12, 2.22, -0.06),
            (sx * 1.24, 2.48, -0.26),
            (sx * 1.14, 2.72, -0.52),
            0.16,
            col_base="steel",
            col_tip="hornIvory",
            verts=18,
            three_seg=False,
        )
        p += _curved_siege_horn(
            b,
            (sx * 0.26, 2.30, -0.08),
            (sx * 0.48, 2.48, -0.22),
            (sx * 0.56, 2.72, -0.46),
            (sx * 0.44, 2.94, -0.72),
            0.14,
            col_base="steel",
            col_tip="hornIvory",
            verts=18,
            three_seg=False,
        )
    return p


def iron_ram_colossus_arm_r():
    """A1 Braco Direito: ombro em (0,0,0) + manopla-ariete pesada com cintas de ferro e runas ambar."""
    b = Rb("iron_ram_colossus")
    p = [
        b.ball(0.38, (0.0, 0.0, 0.0), "ironDark", seg=20, rings=14),
        b.box((0.36, 0.22, 0.34), (0.06, -0.14, -0.04), "iron", rot=(0.0, 0.0, -0.22), bevel=0.03),
        b.cyl(0.22, 0.52, (0.02, -0.50, -0.06), "ironDark", verts=20, r2=0.24),
        b.box((0.50, 0.46, 0.80), (0.04, -0.68, -0.44), "iron", rot=(0.32, 0.0, 0.0), bevel=0.04),
        b.box((0.56, 0.20, 0.24), (0.04, -0.56, -0.28), "ironDark", rot=(0.32, 0.0, 0.0), bevel=0.03),
        b.box((0.56, 0.20, 0.24), (0.04, -0.66, -0.56), "ironDark", rot=(0.32, 0.0, 0.0), bevel=0.03),
        b.torus(
            0.28,
            0.045,
            (0.04, -0.74, -0.72),
            "ironDark",
            major_seg=18,
            minor_seg=8,
            rot=(math.pi / 2 - 0.32, 0.0, 0.0),
        ),
        b.ico(0.22, (0.04, -0.72, -0.68), "ember", squash=(0.95, 0.85, 0.65), subdiv=2),
        b.cyl_axis_y(0.22, 0.46, (0.04, -0.82, -0.92), "steel", verts=18, r2=0.08, tilt=-0.32),
        b.box((0.12, 0.12, 0.54), (0.26, -0.62, -0.46), "amberBright", rot=(0.32, 0.0, 0.0), bevel=0.02),
        b.box((0.12, 0.12, 0.54), (-0.18, -0.62, -0.46), "amberBright", rot=(0.32, 0.0, 0.0), bevel=0.02),
        b.capsule_seg((0.24, -0.58, -0.56), (0.34, -0.74, -0.96), 0.09, 0.015, "hornIvory", verts=18),
        b.capsule_seg((-0.16, -0.58, -0.56), (-0.26, -0.74, -0.96), 0.09, 0.015, "hornIvory", verts=18),
    ]
    return p


def iron_ram_colossus_arm_l():
    """A1 Braco Esquerdo: ombro em (0,0,0) + escudo-manopla-ariete com cintas de ferro e runas ambar."""
    b = Rb("iron_ram_colossus")
    return [
        b.ball(0.36, (0.0, 0.0, 0.0), "ironDark", seg=20, rings=14),
        b.box((0.34, 0.20, 0.32), (-0.06, -0.14, -0.04), "iron", rot=(0.0, 0.0, 0.22), bevel=0.03),
        b.cyl(0.21, 0.54, (-0.02, -0.52, -0.06), "ironDark", verts=20, r2=0.23),
        b.box((0.46, 0.44, 0.72), (-0.04, -0.68, -0.38), "iron", rot=(0.26, 0.0, 0.0), bevel=0.04),
        b.box((0.52, 0.18, 0.22), (-0.04, -0.58, -0.26), "ironDark", rot=(0.26, 0.0, 0.0), bevel=0.03),
        b.box((0.20, 0.60, 0.62), (-0.26, -0.62, -0.36), "ironDark", rot=(0.20, 0.14, 0.0), bevel=0.035),
        b.box((0.10, 0.44, 0.46), (-0.34, -0.62, -0.36), "amberBright", rot=(0.20, 0.14, 0.0), bevel=0.02),
        b.torus(
            0.25,
            0.042,
            (-0.04, -0.72, -0.64),
            "ironDark",
            major_seg=18,
            minor_seg=8,
            rot=(math.pi / 2 - 0.26, 0.0, 0.0),
        ),
        b.cyl_axis_y(0.19, 0.42, (-0.04, -0.78, -0.80), "steel", verts=18, r2=0.07, tilt=-0.26),
        b.capsule_seg((-0.24, -0.54, -0.50), (-0.34, -0.68, -0.86), 0.085, 0.015, "hornIvory", verts=18),
    ]


def iron_ram_colossus_leg(sx: int):
    """A1 Perna: quadril em (0,0,0) descendo ate greva de cerco chanfrada com espigao de joelho."""
    b = Rb("iron_ram_colossus")
    return [
        b.ball(0.34, (0.0, 0.0, 0.0), "ironDark", seg=20, rings=14),
        b.cyl(0.28, 0.78, (0.0, -0.78, 0.0), "ironDark", verts=20, r2=0.24),
        b.torus(0.25, 0.04, (0.0, -0.38, -0.02), "iron", major_seg=18, minor_seg=8),
        b.box((0.38, 0.28, 0.26), (sx * 0.04, -0.38, -0.14), "iron", bevel=0.035),
        b.box((0.34, 0.46, 0.20), (0.0, -0.58, -0.14), "iron", bevel=0.035),
        b.box((0.12, 0.34, 0.16), (sx * 0.18, -0.56, -0.06), "amberBright", bevel=0.02),
        b.capsule_seg(
            (sx * 0.04, -0.36, -0.22),
            (sx * 0.06, -0.24, -0.52),
            0.12,
            0.015,
            "steel",
            verts=18,
        ),
        b.box((0.46, 0.24, 0.64), (0.0, -0.78, -0.10), "iron", bevel=0.035),
        b.box((0.40, 0.14, 0.32), (0.0, -0.72, -0.30), "steel", bevel=0.03),
        b.crystal(0.11, 0.28, (0.0, -0.82, -0.40), "hornIvory", tilt=(1.48, 0.0), verts=6),
    ]


# ==============================================================================
# ACT 2 — SLAG JUGGERNAUT
# ==============================================================================
def slag_juggernaut():
    """Act 2: Juggernaut de Escoria com caldeirao de 24 seg, rebites, chamines com colares torus e punhos esmagadores."""
    j = Rb("slag_juggernaut")
    p = []

    # 1. Grevas de escoria e pilares de fundicao
    for sx in (-1, 1):
        lx = sx * 0.52
        p.append(j.cyl(0.36, 0.78, (lx, 0.0, 0.0), "stoneDark", verts=20, r2=0.30))
        p.append(j.box((0.52, 0.22, 0.64), (lx, 0.11, -0.08), "ironDark", bevel=0.035))
        p.append(j.box((0.38, 0.42, 0.22), (lx, 0.42, -0.16), "ironDark", bevel=0.03))
        p.append(j.ico(0.18, (lx, 0.44, -0.26), "ember", squash=(0.95, 0.80, 0.65), subdiv=2))

    # 2. Caldeirao forjado de 24 segmentos com nucleo de escoria derretida e rebites no aro
    p.append(j.cyl(0.86, 0.96, (0.0, 0.72, 0.0), "ironDark", verts=24, r2=0.78))
    p.append(j.torus(0.84, 0.072, (0.0, 1.58, 0.0), "stoneDark", major_seg=24, minor_seg=10))
    p.append(j.torus(0.82, 0.052, (0.0, 0.92, 0.0), "iron", major_seg=24, minor_seg=8))
    p.append(j.ico(0.56, (0.0, 1.24, -0.44), "danger", squash=(1.05, 0.92, 0.58), subdiv=2))
    p.append(j.ico(0.38, (0.0, 1.24, -0.58), "amberBright", squash=(0.95, 0.85, 0.45), subdiv=2))
    for k in range(8):
        a = 2 * math.pi * k / 8
        p.append(j.box((0.12, 0.12, 0.12), (0.86 * math.cos(a), 1.58, 0.86 * math.sin(a)), "amber", bevel=0.02))

    # 3. Chamines dorsais duplas fumegantes com colares torus
    for sx in (-1, 1):
        p.append(
            j.capsule_seg(
                (sx * 0.48, 1.62, 0.36),
                (sx * 0.58, 2.62, 0.74),
                0.22,
                0.17,
                "stoneDark",
                verts=20,
            )
        )
        p.append(
            j.torus(
                0.21,
                0.04,
                (sx * 0.56, 2.48, 0.68),
                "iron",
                major_seg=16,
                minor_seg=8,
                rot=(-0.38, sx * 0.18, 0.0),
            )
        )
        p.append(j.ico(0.20, (sx * 0.58, 2.68, 0.78), "ember", squash=(1.0, 0.85, 1.0), subdiv=2))

    # 4. Ombreiras de magma e punhos esmagadores de fundicao
    for sx in (-1, 1):
        p.append(j.ball(0.68, (sx * 0.94, 1.62, 0.0), "stoneDark", seg=16, rings=10))
        p.append(j.box((0.46, 0.24, 0.48), (sx * 0.98, 1.74, -0.02), "ember", rot=(0.0, 0.0, -sx * 0.25), bevel=0.03))
        p.append(j.cyl(0.24, 0.82, (sx * 1.02, 0.82, -0.14), "ironDark", verts=18, r2=0.22))
        p.append(j.ico(0.42, (sx * 1.04, 0.76, -0.36), "ember", squash=(1.05, 0.95, 1.15), subdiv=2))
        p.append(j.box((0.48, 0.36, 0.44), (sx * 1.04, 0.74, -0.44), "stoneDark", bevel=0.035))

    # 5. Cabeca de fornalha com crista de magma
    p.append(j.ico(0.46, (0.0, 1.98, -0.22), "ironDark", squash=(1.05, 0.86, 0.96), subdiv=2))
    p.append(j.box((0.48, 0.18, 0.28), (0.0, 1.84, -0.42), "stoneDark", bevel=0.03))
    for sx in (-1, 1):
        p.append(j.ico(0.11, (sx * 0.18, 1.98, -0.56), "neonAmber", squash=(1.35, 0.55, 0.55), subdiv=2))
    for k in range(4):
        p.append(
            j.crystal(
                0.15,
                0.56 - k * 0.06,
                (0.0, 2.24 - k * 0.05, -0.16 + k * 0.18),
                "ember" if k % 2 == 0 else "amberBright",
                tilt=(-0.25 - k * 0.25, 0.0),
                verts=6,
            )
        )

    return p


def slag_juggernaut_torso():
    """A2 Torso: caldeirao forjado de 24 seg, nucleo de escoria e rebites, chamines duplas com colares torus e ombreiras de magma."""
    j = Rb("slag_juggernaut")
    p = [
        j.cyl(0.86, 0.96, (0.0, 0.72, 0.0), "ironDark", verts=24, r2=0.78),
        j.cyl(0.76, 0.18, (0.0, 0.62, 0.0), "stoneDark", verts=24, r2=0.84),
        j.torus(0.84, 0.072, (0.0, 1.58, 0.0), "stoneDark", major_seg=20, minor_seg=6),
        j.torus(0.82, 0.052, (0.0, 0.92, 0.0), "iron", major_seg=20, minor_seg=6),
        j.ico(0.56, (0.0, 1.24, -0.44), "danger", squash=(1.05, 0.92, 0.58), subdiv=2),
        j.ico(0.38, (0.0, 1.24, -0.58), "amberBright", squash=(0.95, 0.85, 0.45), subdiv=2),
        j.box((0.68, 0.11, 0.14), (0.0, 1.24, -0.66), "ironDark", bevel=0.025),
        j.ico(0.46, (0.0, 1.98, -0.22), "ironDark", squash=(1.05, 0.86, 0.96), subdiv=2),
        j.box((0.48, 0.18, 0.28), (0.0, 1.84, -0.42), "stoneDark", bevel=0.03),
    ]
    for k in range(8):
        a = 2 * math.pi * k / 8
        p.append(j.box((0.12, 0.12, 0.12), (0.86 * math.cos(a), 1.58, 0.86 * math.sin(a)), "amber", bevel=0.0))
    for sx in (-1, 1):
        p.append(j.ball(0.64, (sx * 0.90, 1.62, 0.0), "stoneDark", seg=14, rings=8))
        p.append(
            j.box(
                (0.46, 0.22, 0.48),
                (sx * 0.94, 1.74, -0.02),
                "ember",
                rot=(0.0, 0.0, -sx * 0.25),
                bevel=0.03,
            )
        )
        p.append(j.crystal(0.15, 0.48, (sx * 1.04, 1.82, -0.04), "amberBright", tilt=(0.18, -sx * 0.52), verts=6))
        p.append(
            j.capsule_seg(
                (sx * 0.48, 1.62, 0.36),
                (sx * 0.58, 2.62, 0.74),
                0.22,
                0.17,
                "stoneDark",
                verts=18,
            )
        )
        p.append(
            j.torus(
                0.22,
                0.04,
                (sx * 0.52, 1.96, 0.49),
                "ironDark",
                major_seg=14,
                minor_seg=6,
                rot=(-0.38, sx * 0.18, 0.0),
            )
        )
        p.append(
            j.torus(
                0.20,
                0.04,
                (sx * 0.57, 2.50, 0.69),
                "iron",
                major_seg=14,
                minor_seg=6,
                rot=(-0.38, sx * 0.18, 0.0),
            )
        )
        p.append(j.ico(0.20, (sx * 0.58, 2.68, 0.78), "ember", squash=(1.0, 0.85, 1.0), subdiv=1))
        p.append(j.ico(0.11, (sx * 0.18, 1.98, -0.56), "neonAmber", squash=(1.35, 0.55, 0.55), subdiv=1))
    for k in range(4):
        p.append(
            j.crystal(
                0.15,
                0.56 - k * 0.06,
                (0.0, 2.24 - k * 0.05, -0.16 + k * 0.18),
                "ember" if k % 2 == 0 else "amberBright",
                tilt=(-0.25 - k * 0.25, 0.0),
                verts=6,
            )
        )
    return p


def slag_juggernaut_arm_r():
    """A2 Braco Direito: ombro em (0,0,0) + punho esmagador de fundicao e malho de escoria."""
    j = Rb("slag_juggernaut")
    return [
        j.ball(0.38, (0.0, 0.0, 0.0), "stoneDark", seg=16, rings=10),
        j.box((0.36, 0.20, 0.34), (0.06, -0.14, -0.04), "ember", rot=(0.0, 0.0, -0.22), bevel=0.03),
        j.cyl(0.22, 0.58, (0.02, -0.54, -0.08), "ironDark", verts=20, r2=0.24),
        j.torus(0.24, 0.042, (0.03, -0.44, -0.10), "stoneDark", major_seg=18, minor_seg=8),
        j.ico(0.32, (0.04, -0.62, -0.22), "ember", squash=(1.05, 0.90, 1.05), subdiv=2),
        j.box((0.40, 0.28, 0.36), (0.04, -0.60, -0.26), "stoneDark", rot=(0.32, 0.0, 0.0), bevel=0.035),
        # Haste e cabeca do Malho Esmagador de Fundicao
        j.cyl_axis_y(0.11, 0.98, (0.04, -0.66, -0.54), "ironDark", verts=20, r2=0.12, tilt=-0.38),
        j.box((0.68, 0.42, 0.44), (0.04, -0.82, -0.94), "stoneDark", rot=(0.38, 0.0, 0.0), bevel=0.04),
        j.torus(
            0.25,
            0.045,
            (0.04, -0.86, -1.04),
            "iron",
            major_seg=18,
            minor_seg=8,
            rot=(math.pi / 2 + 0.38, 0.0, 0.0),
        ),
        j.ico(0.28, (0.04, -0.82, -0.96), "danger", squash=(1.28, 0.82, 0.82), subdiv=2),
        j.crystal(0.14, 0.36, (0.04, -0.90, -1.14), "amberBright", tilt=(math.pi / 2 + 0.38, 0.0), verts=6),
    ]


def slag_juggernaut_arm_l():
    """A2 Braco Esquerdo: ombro em (0,0,0) + pesado punho esmagador de fundicao."""
    j = Rb("slag_juggernaut")
    return [
        j.ball(0.38, (0.0, 0.0, 0.0), "stoneDark", seg=16, rings=10),
        j.box((0.36, 0.20, 0.34), (-0.06, -0.14, -0.04), "ember", rot=(0.0, 0.0, 0.22), bevel=0.03),
        j.cyl(0.23, 0.58, (-0.02, -0.56, -0.08), "ironDark", verts=20, r2=0.25),
        j.torus(0.25, 0.042, (-0.03, -0.44, -0.10), "stoneDark", major_seg=18, minor_seg=8),
        j.torus(
            0.27,
            0.045,
            (-0.04, -0.64, -0.22),
            "iron",
            major_seg=18,
            minor_seg=8,
            rot=(0.45, 0.0, 0.0),
        ),
        j.ico(0.38, (-0.04, -0.72, -0.28), "ember", squash=(1.08, 0.95, 1.12), subdiv=2),
        j.ico(0.28, (-0.04, -0.76, -0.38), "amberBright", squash=(0.95, 0.88, 0.95), subdiv=2),
        j.box((0.46, 0.34, 0.42), (-0.06, -0.70, -0.32), "stoneDark", rot=(0.24, 0.0, 0.0), bevel=0.04),
        j.box((0.14, 0.24, 0.32), (-0.22, -0.78, -0.44), "ironDark", rot=(0.35, 0.0, 0.0), bevel=0.03),
        j.box((0.14, 0.24, 0.32), (0.10, -0.78, -0.44), "ironDark", rot=(0.35, 0.0, 0.0), bevel=0.03),
        j.crystal(0.13, 0.34, (-0.16, -0.82, -0.52), "amberBright", tilt=(1.35, 0.22), verts=6),
        j.crystal(0.13, 0.34, (0.08, -0.82, -0.52), "danger", tilt=(1.35, -0.18), verts=6),
    ]


def slag_juggernaut_leg(sx: int):
    """A2 Perna: pilar de fundicao e greva de escoria a partir do quadril (0,0,0)."""
    j = Rb("slag_juggernaut")
    return [
        j.ball(0.36, (0.0, 0.0, 0.0), "stoneDark", seg=16, rings=10),
        j.cyl(0.32, 0.74, (0.0, -0.74, 0.0), "stoneDark", verts=24, r2=0.28),
        j.torus(0.30, 0.042, (0.0, -0.34, 0.0), "ironDark", major_seg=20, minor_seg=8),
        j.torus(0.28, 0.038, (0.0, -0.58, 0.0), "iron", major_seg=18, minor_seg=8),
        j.ico(0.22, (sx * 0.05, -0.38, -0.22), "ember", squash=(0.95, 0.80, 0.65), subdiv=2),
        j.box((0.38, 0.44, 0.22), (0.0, -0.48, -0.16), "ironDark", bevel=0.035),
        j.box((0.50, 0.22, 0.62), (0.0, -0.74, -0.08), "ironDark", bevel=0.035),
        j.box((0.36, 0.14, 0.24), (0.0, -0.66, -0.32), "ember", bevel=0.025),
        j.box((0.16, 0.28, 0.24), (sx * 0.22, -0.52, -0.04), "amberBright", bevel=0.025),
    ]


# ==============================================================================
# ACT 3 — RIME MATRIARCH
# ==============================================================================
def rime_matriarch():
    """Act 3: Matriarca Boreal com vestido glacial em camadas, coroa de gelo chifruda, halo torus de runas e Cetro Boreal."""
    m = Rb("rime_matriarch")
    p = []

    # 1. Vestido/saia glacial esculpida em camadas + cristais perifericos
    p.append(m.cyl(0.88, 0.76, (0.0, 0.0, 0.0), "stoneDark", verts=24, r2=0.62))
    p.append(m.cyl(0.66, 0.62, (0.0, 0.64, 0.0), "royal", verts=24, r2=0.44))
    p.append(m.torus(0.64, 0.045, (0.0, 0.68, 0.0), "arcaneCyan", major_seg=20, minor_seg=8))
    p.append(m.torus(0.46, 0.040, (0.0, 1.18, 0.0), "iceLight", major_seg=20, minor_seg=8))
    for k in range(8):
        a = 2 * math.pi * k / 8
        p.append(
            m.crystal(
                0.22,
                0.94,
                (0.70 * math.cos(a), 0.10, 0.70 * math.sin(a)),
                "ice" if k % 2 == 0 else "iceLight",
                tilt=(-0.22 * math.sin(a), -0.22 * math.cos(a)),
                verts=6,
            )
        )

    # 2. Corpete da Rainha do Gelo + nucleo crio no peito
    p.append(m.ico(0.56, (0.0, 1.54, 0.0), "stoneDark", squash=(1.04, 1.18, 0.78), subdiv=2))
    p.append(m.ico(0.46, (0.0, 1.58, -0.10), "royal", squash=(0.92, 1.08, 0.72), subdiv=2))
    p.append(m.ico(0.22, (0.0, 1.56, -0.36), "arcaneCyan", squash=(0.90, 0.90, 0.65), subdiv=2))
    p.append(m.crystal(0.22, 0.52, (0.0, 1.56, -0.40), "iceGlow", tilt=(1.45, 0.0), verts=6))

    # 3. Manto cristalino, Cetro Boreal multi-pontas (dir) e manopla de gelo (esq)
    for sx in (-1, 1):
        p.append(m.crystal(0.24, 1.05, (sx * 0.62, 1.78, 0.06), "ice", tilt=(-0.22, -sx * 0.62), verts=6))
        p.append(m.crystal(0.18, 0.82, (sx * 0.84, 1.66, 0.16), "iceLight", tilt=(-0.38, -sx * 0.92), verts=6))
        p.append(m.cyl(0.16, 0.82, (sx * 0.76, 1.04, -0.22), "ironDark", verts=16, r2=0.12))

    # Cetro Boreal na mao direita (sx=1)
    p.append(m.cyl_axis_y(0.075, 1.16, (0.78, 1.02, -0.62), "ironDark", verts=16, r2=0.085, tilt=-0.35))
    p.append(
        m.torus(
            0.24,
            0.035,
            (0.78, 0.84, -1.04),
            "arcaneCyan",
            major_seg=18,
            minor_seg=8,
            rot=(0.35, 0.0, 0.0),
        )
    )
    p.append(m.crystal(0.15, 0.52, (0.78, 0.82, -1.08), "iceGlow", tilt=(math.pi / 2 + 0.35, 0.0), verts=6))
    p.append(m.crystal(0.10, 0.38, (0.94, 0.86, -1.00), "arcaneCyan", tilt=(1.15, -0.48), verts=6))
    p.append(m.crystal(0.10, 0.38, (0.62, 0.86, -1.00), "iceLight", tilt=(1.15, 0.48), verts=6))

    # Manopla cristalina na mao esquerda (sx=-1)
    p.append(m.box((0.26, 0.24, 0.42), (-0.76, 1.02, -0.46), "ice", bevel=0.03))
    p.append(m.crystal(0.13, 0.48, (-0.76, 1.00, -0.68), "iceGlow", tilt=(1.38, 0.0), verts=6))

    # 4. Elmo soberano, coroa de gelo chifruda e halo torus flutuante de runas
    p.append(m.ball(0.74, (0.0, 2.22, -0.06), "ironDark", seg=18, rings=12, squash=(0.92, 1.08, 0.98)))
    p.append(
        m.torus(
            0.66,
            0.045,
            (0.0, 2.38, 0.32),
            "arcaneCyan",
            major_seg=22,
            minor_seg=8,
            rot=(math.pi / 2 - 0.18, 0.0, 0.0),
        )
    )
    p.append(
        m.torus(
            0.46,
            0.032,
            (0.0, 2.38, 0.34),
            "iceGlow",
            major_seg=18,
            minor_seg=8,
            rot=(math.pi / 2 - 0.18, 0.36, 0.0),
        )
    )
    for sx in (-1, 1):
        p.append(m.ico(0.10, (sx * 0.14, 2.22, -0.40), "iceGlow", squash=(1.4, 0.55, 0.55), subdiv=2))
        p += _curved_siege_horn(
            m,
            (sx * 0.24, 2.44, -0.04),
            (sx * 0.44, 2.66, 0.02),
            (sx * 0.52, 2.92, 0.10),
            (sx * 0.42, 3.16, 0.18),
            0.11,
            col_base="ice",
            col_tip="iceGlow",
            verts=16,
        )
    for k in range(5):
        ang = (k - 2) * 0.42
        p.append(
            m.crystal(
                0.12,
                0.96 - abs(k - 2) * 0.16,
                (math.sin(ang) * 0.24, 2.52, -0.02 + abs(k - 2) * 0.04),
                "iceGlow" if k == 2 else ("arcaneCyan" if k % 2 == 1 else "iceLight"),
                tilt=(-0.12, -ang * 0.65),
                verts=6,
            )
        )

    return p


def rime_matriarch_torso():
    """A3 Torso: corpete da Rainha do Gelo, manto cristalino, coroa chifruda e halo torus flutuante arcaneCyan/iceGlow."""
    m = Rb("rime_matriarch")
    p = [
        m.cyl(0.48, 0.44, (0.0, 0.94, 0.0), "stoneDark", verts=20, r2=0.38),
        m.cyl(0.56, 0.22, (0.0, 0.88, 0.0), "royal", verts=20, r2=0.44),
        m.torus(0.44, 0.042, (0.0, 1.16, 0.0), "iceLight", major_seg=18, minor_seg=6),
        m.ico(0.56, (0.0, 1.54, 0.0), "stoneDark", squash=(1.04, 1.18, 0.78), subdiv=2),
        m.ico(0.46, (0.0, 1.58, -0.10), "royal", squash=(0.92, 1.08, 0.72), subdiv=2),
        m.ico(0.22, (0.0, 1.56, -0.36), "arcaneCyan", squash=(0.90, 0.90, 0.65), subdiv=2),
        m.crystal(0.22, 0.52, (0.0, 1.56, -0.40), "iceGlow", tilt=(1.45, 0.0), verts=6),
        m.ball(0.74, (0.0, 2.22, -0.06), "ironDark", seg=16, rings=10, squash=(0.92, 1.08, 0.98)),
        m.torus(0.32, 0.038, (0.0, 2.48, -0.04), "iceLight", major_seg=16, minor_seg=6),
        # Halo torus de runas flutuante nas costas
        m.torus(
            0.66,
            0.045,
            (0.0, 2.38, 0.32),
            "arcaneCyan",
            major_seg=20,
            minor_seg=6,
            rot=(math.pi / 2 - 0.18, 0.0, 0.0),
        ),
        m.torus(
            0.46,
            0.032,
            (0.0, 2.38, 0.34),
            "iceGlow",
            major_seg=16,
            minor_seg=6,
            rot=(math.pi / 2 - 0.18, 0.36, 0.0),
        ),
    ]
    for sx in (-1, 1):
        p.append(m.crystal(0.24, 1.05, (sx * 0.62, 1.78, 0.06), "ice", tilt=(-0.22, -sx * 0.62), verts=6))
        p.append(m.crystal(0.18, 0.82, (sx * 0.84, 1.66, 0.16), "iceLight", tilt=(-0.38, -sx * 0.92), verts=6))
        p.append(m.box((0.28, 0.72, 0.10), (sx * 0.28, 1.48, 0.28), "royal", rot=(0.18, sx * 0.20, 0.0), bevel=0.03))
        p.append(m.ico(0.10, (sx * 0.14, 2.22, -0.40), "iceGlow", squash=(1.4, 0.55, 0.55), subdiv=1))
        p += _curved_siege_horn(
            m,
            (sx * 0.24, 2.44, -0.04),
            (sx * 0.44, 2.66, 0.02),
            (sx * 0.52, 2.92, 0.10),
            (sx * 0.42, 3.16, 0.18),
            0.11,
            col_base="ice",
            col_tip="iceGlow",
            verts=16,
            three_seg=False,
        )
    for k in range(5):
        ang = (k - 2) * 0.42
        p.append(
            m.crystal(
                0.12,
                0.96 - abs(k - 2) * 0.16,
                (math.sin(ang) * 0.24, 2.52, -0.02 + abs(k - 2) * 0.04),
                "iceGlow" if k == 2 else ("arcaneCyan" if k % 2 == 1 else "iceLight"),
                tilt=(-0.12, -ang * 0.65),
                verts=6,
            )
        )
    return p


def rime_matriarch_arm_r():
    """A3 Braco Direito: ombro em (0,0,0) + Cetro Boreal multi-pontas com anel torus de runas."""
    m = Rb("rime_matriarch")
    return [
        m.ball(0.30, (0.0, 0.0, 0.0), "ironDark", seg=16, rings=10),
        m.cyl(0.16, 0.56, (0.02, -0.52, -0.10), "ironDark", verts=20, r2=0.12),
        m.torus(0.16, 0.032, (0.03, -0.44, -0.10), "iceLight", major_seg=18, minor_seg=8),
        m.crystal(0.14, 0.42, (0.06, -0.24, -0.06), "ice", tilt=(-0.25, -0.45), verts=6),
        # Cetro Boreal multi-pontas estendido para frente (-Z) e baixo (-Y)
        m.cyl_axis_y(0.08, 1.14, (0.04, -0.62, -0.56), "ironDark", verts=20, r2=0.09, tilt=-0.42),
        m.torus(
            0.24,
            0.036,
            (0.04, -0.82, -0.96),
            "arcaneCyan",
            major_seg=18,
            minor_seg=8,
            rot=(0.42, 0.0, 0.0),
        ),
        m.ico(0.22, (0.04, -0.82, -0.96), "iceGlow", squash=(0.95, 0.95, 1.15), subdiv=2),
        m.crystal(0.15, 0.56, (0.04, -0.86, -1.02), "iceGlow", tilt=(math.pi / 2 + 0.42, 0.0), verts=6),
        m.crystal(0.11, 0.42, (0.20, -0.76, -0.92), "arcaneCyan", tilt=(1.15, -0.48), verts=6),
        m.crystal(0.11, 0.42, (-0.12, -0.76, -0.92), "arcaneCyan", tilt=(1.15, 0.48), verts=6),
        m.capsule_seg((0.18, -0.74, -0.86), (0.34, -0.88, -1.16), 0.075, 0.012, "iceLight", verts=16),
        m.capsule_seg((-0.10, -0.74, -0.86), (-0.26, -0.88, -1.16), 0.075, 0.012, "iceLight", verts=16),
    ]


def rime_matriarch_arm_l():
    """A3 Braco Esquerdo: ombro em (0,0,0) + manopla de gelo cristalina e escudo de runas."""
    m = Rb("rime_matriarch")
    return [
        m.ball(0.30, (0.0, 0.0, 0.0), "ironDark", seg=20, rings=14),
        m.cyl(0.16, 0.58, (-0.02, -0.54, -0.10), "ironDark", verts=20, r2=0.12),
        m.box((0.26, 0.24, 0.44), (-0.06, -0.58, -0.24), "royal", rot=(0.28, 0.0, 0.0), bevel=0.03),
        m.box((0.16, 0.36, 0.42), (-0.18, -0.54, -0.24), "ice", rot=(0.24, 0.22, 0.0), bevel=0.03),
        m.torus(
            0.22,
            0.035,
            (-0.14, -0.56, -0.26),
            "arcaneCyan",
            major_seg=18,
            minor_seg=8,
            rot=(0.35, 0.45, 0.0),
        ),
        m.ico(0.16, (-0.08, -0.62, -0.28), "iceGlow", subdiv=2),
        m.crystal(0.18, 0.56, (-0.16, -0.48, -0.22), "ice", tilt=(0.35, 0.42), verts=6),
        m.capsule_seg((-0.02, -0.64, -0.28), (-0.02, -0.84, -0.64), 0.08, 0.012, "iceGlow", verts=14),
        m.capsule_seg((-0.12, -0.64, -0.26), (-0.16, -0.82, -0.60), 0.075, 0.012, "arcaneCyan", verts=14),
        m.capsule_seg((0.06, -0.64, -0.26), (0.10, -0.82, -0.60), 0.075, 0.012, "iceLight", verts=14),
    ]


def rime_matriarch_leg(sx: int):
    """A3 Perna: saia/vestido glacial esculpido em camadas e pinaculo crio a partir do quadril (0,0,0)."""
    m = Rb("rime_matriarch")
    return [
        m.ball(0.32, (0.0, 0.0, 0.0), "stoneDark", seg=20, rings=14),
        m.cyl(0.34, 0.44, (0.0, -0.42, 0.0), "royal", verts=20, r2=0.24),
        m.cyl(0.38, 0.46, (0.0, -0.74, 0.0), "stoneDark", verts=20, r2=0.20),
        m.torus(0.34, 0.036, (0.0, -0.64, 0.0), "arcaneCyan", major_seg=18, minor_seg=8),
        m.box((0.24, 0.56, 0.14), (sx * 0.16, -0.48, -0.10), "ice", rot=(0.12, 0.0, -sx * 0.18), bevel=0.03),
        m.box((0.22, 0.52, 0.14), (-sx * 0.12, -0.52, 0.10), "iceLight", rot=(-0.12, 0.0, sx * 0.16), bevel=0.03),
        m.crystal(0.22, 0.68, (sx * 0.14, -0.72, -0.10), "ice", tilt=(-0.18, -sx * 0.24), verts=6),
        m.crystal(0.18, 0.58, (-sx * 0.10, -0.76, 0.12), "iceLight", tilt=(0.16, sx * 0.20), verts=6),
        m.crystal(0.16, 0.44, (0.0, -0.52, -0.18), "iceGlow", tilt=(math.pi, 0.0), verts=6),
    ]


# ==============================================================================
# ACT 4 — POWDER BARON
# ==============================================================================
def powder_baron():
    """Act 4: Baronesa da Polvora com sobretudo blindado, granadas, caldeiras duplas, tricornio com oculos de latao e canhao rotativo 6 canos."""
    pb = Rb("powder_baron")
    p = []

    # 1. Botas blindadas + abas do sobretudo de cerco
    for sx in (-1, 1):
        p.append(pb.cyl(0.28, 0.86, (sx * 0.38, 0.0, 0.0), "ironDark", verts=18, r2=0.24))
        p.append(pb.torus(0.29, 0.04, (sx * 0.38, 0.68, 0.0), "brass", major_seg=16, minor_seg=8))
        p.append(pb.box((0.36, 0.20, 0.52), (sx * 0.38, 0.10, -0.08), "ironDark", bevel=0.03))
    p.append(pb.cyl(0.68, 0.56, (0.0, 0.68, 0.0), "crimsonCloth", verts=20, r2=0.52))
    p.append(pb.torus(0.55, 0.05, (0.0, 1.16, 0.0), "brass", major_seg=18, minor_seg=8))

    # 2. Couraca com bandoleiras de granadas e caldeiras a vapor nas costas
    p.append(pb.ico(0.64, (0.0, 1.44, 0.0), "ironDark", squash=(1.12, 1.06, 0.82), subdiv=2))
    p.append(pb.ico(0.26, (0.0, 1.46, -0.46), "goldBright", squash=(1.0, 1.0, 0.55), subdiv=2))
    for sx in (-1, 1):
        p.append(pb.box((0.14, 0.72, 0.16), (sx * 0.26, 1.44, -0.42), "bronze", rot=(0.0, 0.0, sx * 0.42), bevel=0.025))
        p.append(pb.cyl(0.11, 0.20, (sx * 0.30, 1.54, -0.48), "ironDark", verts=12))
        p.append(pb.cyl(0.11, 0.20, (sx * 0.18, 1.30, -0.50), "danger", verts=12))
        # Caldeiras a vapor duplas com anel torus nas costas
        p.append(pb.cyl(0.24, 0.68, (sx * 0.34, 1.32, 0.38), "brass", verts=18, r2=0.22))
        p.append(pb.torus(0.24, 0.036, (sx * 0.34, 1.56, 0.38), "ironDark", major_seg=16, minor_seg=8))
        p.append(pb.ball(0.60, (sx * 0.76, 1.72, 0.0), "bronze", seg=16, rings=10))
        p.append(pb.cyl_axis_y(0.22, 1.08, (sx * 0.78, 2.02, -0.22), "ironDark", verts=16, r2=0.26, tilt=0.45))
        p.append(pb.cyl_axis_y(0.27, 0.16, (sx * 0.78, 2.22, -0.64), "gold", verts=16, r2=0.27, tilt=0.45))

    # 3. Canhao rotativo de 6 canos (dir) e manopla garra/escudo (esq)
    p.append(pb.cyl(0.20, 0.72, (0.84, 0.96, -0.18), "ironDark", verts=16, r2=0.18))
    for k in range(6):
        a = 2 * math.pi * k / 6
        p.append(
            pb.cyl_axis_y(
                0.048,
                0.78,
                (0.84 + 0.12 * math.cos(a), 0.90 + 0.12 * math.sin(a), -0.68),
                "ironDark",
                verts=12,
                tilt=-0.18,
            )
        )
    p.append(
        pb.torus(
            0.18,
            0.035,
            (0.84, 0.86, -0.92),
            "brass",
            major_seg=16,
            minor_seg=8,
            rot=(math.pi / 2 - 0.18, 0.0, 0.0),
        )
    )
    p.append(pb.cyl(0.20, 0.72, (-0.84, 0.96, -0.18), "ironDark", verts=16, r2=0.18))
    p.append(pb.box((0.20, 0.48, 0.52), (-0.98, 0.92, -0.44), "brass", bevel=0.03))
    p.append(pb.box((0.32, 0.28, 0.44), (-0.84, 0.90, -0.48), "ironDark", bevel=0.03))

    # 4. Cabeca e chapeu tricornio/bicornio com oculos de latao
    p.append(pb.ball(0.72, (0.0, 2.12, -0.06), "ironDark", seg=16, rings=10))
    for sx in (-1, 1):
        p.append(
            pb.torus(
                0.11,
                0.028,
                (sx * 0.15, 2.13, -0.38),
                "brass",
                major_seg=14,
                minor_seg=8,
                rot=(math.pi / 2, sx * 0.18, 0.0),
            )
        )
        p.append(pb.ico(0.09, (sx * 0.15, 2.13, -0.40), "amberBright", squash=(1.2, 0.55, 0.55), subdiv=1))
    p.append(pb.cyl(0.80, 0.14, (0.0, 2.34, -0.04), "ironDark", verts=18, r2=0.72))
    p.append(pb.cyl(0.48, 0.36, (0.0, 2.44, -0.02), "gold", verts=18, r2=0.38))
    p.append(pb.crystal(0.16, 0.68, (0.28, 2.66, 0.12), "crimsonBright", tilt=(-0.68, -0.35), verts=6))

    return p


def powder_baron_torso():
    """A4 Torso: sobretudo blindado, bandoleira de granadas, caldeiras duplas com engrenagem/torus e tricornio com oculos de latao."""
    pb = Rb("powder_baron")
    p = [
        pb.cyl(0.64, 0.44, (0.0, 0.84, 0.0), "crimsonCloth", verts=18, r2=0.52),
        pb.torus(0.55, 0.05, (0.0, 1.18, 0.0), "brass", major_seg=16, minor_seg=6),
        pb.ico(0.64, (0.0, 1.44, 0.0), "ironDark", squash=(1.12, 1.06, 0.82), subdiv=2),
        pb.ico(0.26, (0.0, 1.46, -0.46), "goldBright", squash=(1.0, 1.0, 0.55), subdiv=1),
        pb.ball(0.72, (0.0, 2.12, -0.06), "ironDark", seg=14, rings=8),
        pb.cyl(0.80, 0.14, (0.0, 2.34, -0.04), "ironDark", verts=16, r2=0.72),
        pb.cyl(0.48, 0.36, (0.0, 2.44, -0.02), "gold", verts=16, r2=0.38),
        pb.crystal(0.16, 0.68, (0.28, 2.66, 0.12), "crimsonBright", tilt=(-0.68, -0.35), verts=6),
    ]
    for sx in (-1, 1):
        p.append(
            pb.box(
                (0.14, 0.72, 0.16),
                (sx * 0.26, 1.44, -0.42),
                "bronze",
                rot=(0.0, 0.0, sx * 0.42),
                bevel=0.025,
            )
        )
        p.append(pb.cyl(0.11, 0.20, (sx * 0.30, 1.54, -0.48), "ironDark", verts=10))
        p.append(pb.cyl(0.11, 0.20, (sx * 0.18, 1.30, -0.50), "danger", verts=10))
        # Caldeiras a vapor duplas nas costas com colar torus
        p.append(pb.cyl(0.24, 0.68, (sx * 0.34, 1.32, 0.38), "brass", verts=16, r2=0.22))
        p.append(pb.torus(0.24, 0.038, (sx * 0.34, 1.56, 0.38), "ironDark", major_seg=14, minor_seg=6))
        p.append(pb.ball(0.60, (sx * 0.76, 1.72, 0.0), "bronze", seg=12, rings=8))
        p.append(pb.cyl_axis_y(0.24, 1.12, (sx * 0.78, 2.02, -0.22), "ironDark", verts=14, r2=0.28, tilt=0.45))
        p.append(pb.cyl_axis_y(0.29, 0.18, (sx * 0.78, 2.24, -0.68), "gold", verts=14, r2=0.29, tilt=0.45))
        p.append(pb.ico(0.14, (sx * 0.78, 2.16, 0.34), "danger", subdiv=1))
        # Oculos de latao no elmo bicornio/tricornio
        p.append(
            pb.torus(
                0.11,
                0.028,
                (sx * 0.15, 2.13, -0.38),
                "brass",
                major_seg=12,
                minor_seg=6,
                rot=(math.pi / 2, sx * 0.18, 0.0),
            )
        )
        p.append(pb.ico(0.09, (sx * 0.15, 2.13, -0.40), "amberBright", squash=(1.2, 0.55, 0.55), subdiv=1))
        p.append(pb.box((0.20, 0.18, 0.58), (sx * 0.46, 2.44, -0.04), "obsidian", rot=(0.0, 0.0, -sx * 0.38), bevel=0.03))
    return p


def powder_baron_arm_r():
    """A4 Braco Direito: ombro em (0,0,0) + Canhao de Cerco Rotativo de 6 Canos com cintas torus."""
    pb = Rb("powder_baron")
    tilt = -0.28
    p = [
        pb.ball(0.34, (0.0, 0.0, 0.0), "bronze", seg=16, rings=10),
        pb.cyl(0.19, 0.52, (0.02, -0.48, -0.08), "ironDark", verts=18, r2=0.21),
        pb.cyl_axis_y(0.25, 0.30, (0.04, -0.56, -0.32), "brass", verts=18, r2=0.25, tilt=tilt),
        pb.cyl_axis_y(0.065, 0.90, (0.04, -0.68, -0.66), "steel", verts=12, tilt=tilt),
        pb.torus(
            0.20,
            0.036,
            (0.04, -0.62, -0.50),
            "brass",
            major_seg=16,
            minor_seg=6,
            rot=(math.pi / 2 - tilt, 0.0, 0.0),
        ),
        pb.torus(
            0.20,
            0.038,
            (0.04, -0.75, -0.92),
            "gold",
            major_seg=16,
            minor_seg=6,
            rot=(math.pi / 2 - tilt, 0.0, 0.0),
        ),
        pb.box((0.12, 0.18, 0.46), (0.04, -0.46, -0.54), "bronze", rot=(-tilt, 0.0, 0.0), bevel=0.025),
        pb.ico(0.14, (0.04, -0.52, -0.18), "danger", subdiv=1),
    ]
    for k in range(6):
        a = 2 * math.pi * k / 6
        rx = 0.04 + 0.135 * math.cos(a)
        ry = -0.68 + 0.135 * math.sin(a) * math.cos(tilt)
        rz = -0.66 - 0.135 * math.sin(a) * math.sin(tilt)
        p.append(pb.cyl_axis_y(0.052, 0.86, (rx, ry, rz), "ironDark", verts=12, tilt=tilt))
    return p


def powder_baron_arm_l():
    """A4 Braco Esquerdo: ombro em (0,0,0) + manopla articulada de garra de ferro e escudo."""
    pb = Rb("powder_baron")
    return [
        pb.ball(0.34, (0.0, 0.0, 0.0), "bronze", seg=20, rings=14),
        pb.cyl(0.19, 0.54, (-0.02, -0.50, -0.08), "ironDark", verts=20, r2=0.21),
        pb.ico(0.24, (-0.04, -0.60, -0.24), "bronze", subdiv=2),
        # Escudo de pulso + anel de latao
        pb.box((0.18, 0.50, 0.54), (-0.22, -0.58, -0.32), "ironDark", rot=(0.24, 0.16, 0.0), bevel=0.035),
        pb.box((0.12, 0.40, 0.42), (-0.28, -0.58, -0.32), "brass", rot=(0.24, 0.16, 0.0), bevel=0.025),
        pb.torus(
            0.20,
            0.034,
            (-0.26, -0.58, -0.32),
            "gold",
            major_seg=18,
            minor_seg=8,
            rot=(0.24, 1.25, 0.0),
        ),
        pb.cyl_axis_y(0.16, 0.46, (-0.06, -0.66, -0.44), "ironDark", verts=18, r2=0.18, tilt=-0.32),
        # Garras de ferro articuladas
        pb.capsule_seg((-0.14, -0.68, -0.54), (-0.18, -0.82, -0.82), 0.065, 0.015, "steel", verts=14),
        pb.capsule_seg((0.02, -0.68, -0.54), (0.06, -0.82, -0.82), 0.065, 0.015, "steel", verts=14),
        pb.capsule_seg((-0.06, -0.58, -0.54), (-0.06, -0.70, -0.84), 0.065, 0.015, "brass", verts=14),
    ]


def powder_baron_leg(sx: int):
    """A4 Perna: bota blindada de cerco com cano de latao e aba do sobretudo desde (0,0,0)."""
    pb = Rb("powder_baron")
    return [
        pb.ball(0.32, (0.0, 0.0, 0.0), "crimsonCloth", seg=20, rings=14),
        pb.cyl(0.26, 0.76, (0.0, -0.76, 0.0), "ironDark", verts=20, r2=0.22),
        pb.cyl(0.30, 0.16, (0.0, -0.28, 0.0), "bronze", verts=20, r2=0.30),
        pb.torus(0.27, 0.038, (0.0, -0.30, 0.0), "brass", major_seg=18, minor_seg=8),
        pb.box((0.16, 0.46, 0.36), (sx * 0.18, -0.26, 0.02), "crimsonCloth", rot=(0.0, 0.0, -sx * 0.18), bevel=0.03),
        pb.box((0.26, 0.38, 0.18), (0.0, -0.52, -0.14), "brass", bevel=0.03),
        pb.box((0.38, 0.20, 0.54), (0.0, -0.76, -0.08), "ironDark", bevel=0.035),
        pb.box((0.30, 0.14, 0.24), (0.0, -0.74, -0.28), "brass", bevel=0.025),
        pb.ico(0.11, (0.0, -0.68, -0.34), "gold", subdiv=2),
    ]


# ==============================================================================
# ACT 5 — RIFT TITAN
# ==============================================================================
def rift_titan():
    """Act 5: Tita Soberano da Fenda — placa de obsidiana/violeta, nucleo de singularidade com 2 aneis torus, grande elmo coroado e Lamina-Obelisco empunhada no alto."""
    t = Rb("rift_titan")
    p = []

    # 1. Grevas blindadas de obsidiana e violeta
    for sx in (-1, 1):
        z_leg = -0.10 if sx == 1 else 0.06
        lx = sx * 0.36
        p.append(t.box((0.28, 0.20, 0.40), (lx, 0.10, z_leg - 0.05), "obsidian", bevel=0.03))
        p.append(t.crystal(0.14, 0.32, (lx, 0.09, z_leg - 0.20), "steel", tilt=(1.42, 0.0), verts=6))
        p.append(t.cyl(0.20, 0.60, (lx, 0.18, z_leg), "obsidian", verts=16, r2=0.24))
        p.append(t.box((0.16, 0.50, 0.14), (lx, 0.45, z_leg - 0.20), "violet", rot=(0.06, 0.0, 0.0), bevel=0.025))
        p.append(t.crystal(0.16, 0.38, (lx, 0.68, z_leg - 0.18), "tealSwarm", tilt=(0.48, 0.0), verts=6))
        p.append(t.cyl(0.25, 0.48, (sx * 0.34, 0.76, z_leg * 0.5), "obsidianLight", verts=16, r2=0.27))

    # 2. Cinturao soberano e escarcelas
    p.append(t.cyl(0.45, 0.28, (0.0, 1.12, -0.02), "obsidian", verts=18, r2=0.42))
    p.append(t.torus(0.45, 0.042, (0.0, 1.28, -0.02), "gold", major_seg=18, minor_seg=8))
    p.append(t.crystal(0.13, 0.22, (0.0, 1.18, -0.44), "arcaneViolet", verts=6, r2=0.13, spin=math.pi / 4))
    p.append(t.crystal(0.07, 0.14, (0.0, 1.22, -0.47), "eyeNeon", verts=6, r2=0.07, spin=math.pi / 4))
    for sx in (-1, 1):
        p.append(t.box((0.22, 0.44, 0.36), (sx * 0.48, 1.04, -0.02), "obsidianLight", rot=(0.0, sx * 0.24, 0.0), bevel=0.03))
    p.append(t.box((0.26, 0.76, 0.07), (0.0, 0.86, -0.36), "violet", rot=(-0.05, 0.0, 0.0), bevel=0.02))

    # 3. Torso em placas de obsidiana/violeta + Nucleo de Singularidade + 2 aneis torus inclinados
    p.append(t.cyl(0.42, 0.38, (0.0, 1.36, -0.04), "obsidian", verts=18, r2=0.52))
    p.append(t.ico(0.60, (0.0, 1.84, -0.08), "obsidian", squash=(1.22, 0.96, 0.58), subdiv=2))
    p.append(t.ico(0.38, (0.0, 1.82, -0.26), "ink", squash=(0.90, 0.92, 0.45), subdiv=2))
    p.append(t.ico(0.26, (0.0, 1.84, -0.39), "arcaneViolet", squash=(0.82, 1.08, 0.40), subdiv=2))
    p.append(t.ico(0.16, (0.0, 1.84, -0.44), "eyeNeon", squash=(0.68, 1.02, 0.38), subdiv=2))
    p.append(
        t.torus(
            0.34,
            0.032,
            (0.0, 1.84, -0.38),
            "arcaneViolet",
            major_seg=18,
            minor_seg=8,
            rot=(math.pi / 2 - 0.15, 0.48, 0.0),
        )
    )
    p.append(
        t.torus(
            0.28,
            0.026,
            (0.0, 1.84, -0.40),
            "eyeNeon",
            major_seg=18,
            minor_seg=8,
            rot=(math.pi / 2 + 0.15, -0.52, 0.0),
        )
    )
    for sx in (-1, 1):
        for i in range(3):
            rib_col = "goldBright" if i == 1 else "violet"
            p.append(
                t.box(
                    (0.26, 0.08, 0.11),
                    (sx * 0.28, 1.66 + i * 0.14, -0.37),
                    rib_col,
                    rot=(0.0, 0.0, sx * 0.26),
                    bevel=0.02,
                )
            )
    p.append(t.cyl(0.38, 0.22, (0.0, 2.08, -0.02), "obsidian", verts=16, r2=0.44))

    # 4. Manto soberano e ombreiras do vazio
    p.append(t.box((1.22, 0.22, 0.28), (0.0, 2.08, 0.26), "obsidianLight", rot=(0.20, 0.0, 0.0), bevel=0.03))
    for idx in (-2, -1, 0, 1, 2):
        u = idx / 2.0
        col = "obsidian" if idx % 2 == 0 else "violet"
        p.append(
            t.box(
                (0.28, 1.36, 0.08),
                (u * 0.54, 1.36, 0.48 - (1.0 - abs(u)) * 0.04),
                col,
                rot=(0.18, u * 0.18, u * 0.05),
                bevel=0.025,
            )
        )
    for sx in (-1, 1):
        p.append(t.ball(0.56, (sx * 0.68, 2.04, -0.02), "obsidian", seg=14, rings=10, squash=(1.15, 0.95, 1.05)))
        p.append(t.box((0.46, 0.18, 0.56), (sx * 0.80, 2.14, 0.02), "obsidianLight", rot=(0.08, sx * 0.34, 0.0), bevel=0.03))
        p.append(t.box((0.42, 0.08, 0.44), (sx * 0.78, 2.23, -0.02), "goldBright", rot=(0.08, sx * 0.32, 0.0), bevel=0.02))
        p.append(t.crystal(0.14, 0.66, (sx * 0.84, 2.10, 0.04), "arcaneViolet", tilt=(-0.22, -sx * 0.62), verts=6))

    # 5. Grande elmo do vazio coroado com chifres varridos
    p.append(t.ico(0.38, (0.0, 2.40, -0.05), "obsidian", squash=(0.92, 1.08, 0.98), subdiv=2))
    p.append(t.torus(0.28, 0.032, (0.0, 2.52, -0.05), "goldBright", major_seg=16, minor_seg=8))
    p.append(t.crystal(0.09, 0.42, (0.0, 2.58, -0.10), "goldBright", tilt=(-0.24, 0.0), verts=6))
    for sx in (-1, 1):
        p.append(t.box((0.17, 0.06, 0.09), (sx * 0.11, 2.40, -0.37), "eyeNeon", rot=(0.0, 0.0, -sx * 0.28), bevel=0.015))
        p += _curved_siege_horn(
            t,
            (sx * 0.24, 2.46, -0.04),
            (sx * 0.52, 2.62, -0.08),
            (sx * 0.64, 2.92, -0.12),
            (sx * 0.56, 3.20, -0.18),
            0.12,
            col_base="obsidianLight",
            col_tip="eyeNeon",
            verts=14,
        )

    # 6. Garra do Vazio no braco esquerdo
    p.append(t.cyl(0.16, 0.48, (-0.74, 1.54, -0.04), "obsidian", verts=14, r2=0.19))
    p.append(t.cyl_axis_y(0.17, 0.50, (-0.78, 1.30, -0.18), "obsidianLight", verts=14, r2=0.14, tilt=-0.85))
    p.append(t.ico(0.16, (-0.80, 1.06, -0.32), "arcaneViolet", subdiv=2))
    p.append(t.crystal(0.10, 0.44, (-0.88, 1.18, -0.26), "eyeNeon", tilt=(2.35, 0.15), verts=6))

    # 7. Braco direito + Lamina-Obelisco chanfrada empunhada em guarda (~35 graus, NUNCA no chao!)
    pitch = 0.62
    p.append(t.cyl(0.17, 0.38, (0.76, 1.70, -0.06), "obsidian", verts=14, r2=0.19))
    p.append(t.cyl_axis_y(0.16, 0.38, (0.78, 1.64, -0.20), "obsidianLight", verts=14, r2=0.14, tilt=-0.42))
    p.append(t.ico(0.16, (0.80, 1.58, -0.34), "gold", subdiv=2))
    p.append(t.cyl_axis_y(0.075, 0.48, (0.80, 1.62, -0.28), "ink", verts=14, r2=0.085, tilt=-pitch))
    p.append(t.box((0.42, 0.14, 0.18), (0.80, 1.48, -0.48), "goldBright", rot=(pitch, 0.0, 0.0), bevel=0.03))
    p.append(t.box((0.24, 0.095, 1.16), (0.80, 1.16, -0.94), "obsidian", rot=(pitch, 0.0, 0.0), bevel=0.03))
    p.append(t.box((0.12, 0.115, 1.06), (0.80, 1.17, -0.92), "arcaneViolet", rot=(pitch, 0.0, 0.0), bevel=0.02))
    p.append(t.box((0.065, 0.13, 1.00), (0.80, 1.18, -0.90), "eyeNeon", rot=(pitch, 0.0, 0.0), bevel=0.015))
    p.append(t.crystal(0.15, 0.42, (0.80, 0.88, -1.34), "steel", tilt=(math.pi / 2 + pitch, 0.0), verts=6))

    return p


def rift_titan_torso():
    """A5 Torso: placas de obsidiana e violeta, nucleo de singularidade eyeNeon/arcaneViolet + 2 aneis torus inclinados e grande elmo chifrudo."""
    t = Rb("rift_titan")
    p = [
        # Cinturao soberano e escarcelas altas (base do torso em y ~ 0.88)
        t.cyl(0.45, 0.28, (0.0, 1.12, -0.02), "obsidian", verts=18, r2=0.42),
        t.torus(0.45, 0.044, (0.0, 1.28, -0.02), "gold", major_seg=18, minor_seg=6),
        t.crystal(0.13, 0.22, (0.0, 1.18, -0.44), "arcaneViolet", verts=6, r2=0.13, spin=math.pi / 4),
        t.crystal(0.07, 0.14, (0.0, 1.22, -0.47), "eyeNeon", verts=6, r2=0.07, spin=math.pi / 4),
        # Couraca em camadas obsidiana/violeta + Nucleo de Singularidade + 2 aneis torus inclinados
        t.cyl(0.42, 0.38, (0.0, 1.36, -0.04), "obsidian", verts=18, r2=0.52),
        t.ico(0.60, (0.0, 1.84, -0.08), "obsidian", squash=(1.22, 0.96, 0.58), subdiv=2),
        t.ico(0.38, (0.0, 1.82, -0.26), "ink", squash=(0.90, 0.92, 0.45), subdiv=1),
        t.ico(0.26, (0.0, 1.84, -0.39), "arcaneViolet", squash=(0.82, 1.08, 0.40), subdiv=2),
        t.ico(0.16, (0.0, 1.84, -0.44), "eyeNeon", squash=(0.68, 1.02, 0.38), subdiv=1),
        t.torus(
            0.34,
            0.034,
            (0.0, 1.84, -0.38),
            "arcaneViolet",
            major_seg=18,
            minor_seg=6,
            rot=(math.pi / 2 - 0.15, 0.48, 0.0),
        ),
        t.torus(
            0.28,
            0.028,
            (0.0, 1.84, -0.40),
            "eyeNeon",
            major_seg=16,
            minor_seg=6,
            rot=(math.pi / 2 + 0.15, -0.52, 0.0),
        ),
        t.cyl(0.38, 0.22, (0.0, 2.08, -0.02), "obsidian", verts=16, r2=0.44),
        # Manto soberano pregueado nas costas (terminando na cintura para preservar pivo do torso)
        t.box((1.22, 0.22, 0.28), (0.0, 2.08, 0.26), "obsidianLight", rot=(0.20, 0.0, 0.0), bevel=0.03),
    ]
    for sx in (-1, 1):
        p.append(t.box((0.22, 0.38, 0.34), (sx * 0.46, 1.10, -0.02), "obsidianLight", rot=(0.0, sx * 0.24, 0.0), bevel=0.03))
        for i in range(3):
            rib_col = "goldBright" if i == 1 else "violet"
            p.append(
                t.box(
                    (0.26, 0.08, 0.11),
                    (sx * 0.28, 1.66 + i * 0.14, -0.37),
                    rib_col,
                    rot=(0.0, 0.0, sx * 0.26),
                    bevel=0.0,
                )
            )
        # Ombreiras do Vazio
        p.append(t.ball(0.56, (sx * 0.68, 2.04, -0.02), "obsidian", seg=12, rings=8, squash=(1.15, 0.95, 1.05)))
        p.append(t.box((0.46, 0.18, 0.56), (sx * 0.80, 2.14, 0.02), "obsidianLight", rot=(0.08, sx * 0.34, 0.0), bevel=0.03))
        p.append(t.box((0.42, 0.08, 0.44), (sx * 0.78, 2.23, -0.02), "goldBright", rot=(0.08, sx * 0.32, 0.0), bevel=0.0))
        p.append(t.crystal(0.14, 0.66, (sx * 0.84, 2.10, 0.04), "arcaneViolet", tilt=(-0.22, -sx * 0.62), verts=6))
        p.append(t.crystal(0.10, 0.40, (sx * 0.82, 2.00, -0.22), "steel", tilt=(0.68, -sx * 0.46), verts=6))

    for idx in (-1, 0, 1):
        u = float(idx)
        col = "obsidian" if idx % 2 == 0 else "violet"
        p.append(
            t.box(
                (0.34, 1.06, 0.08),
                (u * 0.46, 1.52, 0.44 - (1.0 - abs(u)) * 0.04),
                col,
                rot=(0.18, u * 0.18, u * 0.05),
                bevel=0.025,
            )
        )

    # Grande elmo coroado do Vazio com chifres varridos
    p.append(t.ico(0.38, (0.0, 2.40, -0.05), "obsidian", squash=(0.90, 1.08, 0.98), subdiv=2))
    p.append(t.torus(0.28, 0.032, (0.0, 2.52, -0.05), "goldBright", major_seg=16, minor_seg=6))
    for sx in (-1, 1):
        p.append(t.box((0.12, 0.28, 0.22), (sx * 0.18, 2.32, -0.24), "obsidianLight", rot=(0.08, 0.0, -sx * 0.14), bevel=0.02))
        p.append(t.box((0.17, 0.06, 0.09), (sx * 0.11, 2.40, -0.37), "eyeNeon", rot=(0.0, 0.0, -sx * 0.28), bevel=0.0))
        p += _curved_siege_horn(
            t,
            (sx * 0.24, 2.46, -0.04),
            (sx * 0.52, 2.62, -0.08),
            (sx * 0.64, 2.92, -0.12),
            (sx * 0.56, 3.20, -0.18),
            0.12,
            col_base="obsidianLight",
            col_tip="eyeNeon",
            verts=14,
            three_seg=False,
        )
    p.append(t.crystal(0.09, 0.42, (0.0, 2.58, -0.10), "goldBright", tilt=(-0.24, 0.0), verts=6))
    for k in range(5):
        ang = -0.8 + 0.4 * k
        pos_h = (0.62 * math.sin(ang), 2.74 + (1 - abs(k - 2) * 0.3) * 0.22, 0.26)
        p.append(
            t.crystal(
                0.08,
                0.38,
                pos_h,
                "eyeNeon" if k % 2 == 0 else "arcaneViolet",
                tilt=(-0.15, -ang * 0.35),
                verts=6,
            )
        )
    return p


def rift_titan_arm_r():
    """A5 Braco Direito: ombro em (0,0,0) + Lamina-Obelisco chanfrada (pomo, guarda, fuller, runas) em guarda (~35 graus, nunca no chao)."""
    t = Rb("rift_titan")
    pitch = 0.62
    return [
        # Ombro em (0,0,0) e braco blindado
        t.ball(0.32, (0.0, 0.0, 0.0), "obsidian", seg=16, rings=10),
        t.box((0.30, 0.18, 0.30), (0.05, -0.12, -0.04), "violet", rot=(0.0, 0.0, -0.22), bevel=0.025),
        t.cyl(0.17, 0.38, (0.02, -0.34, -0.06), "obsidian", verts=16, r2=0.19),
        t.cyl_axis_y(0.16, 0.38, (0.04, -0.40, -0.20), "obsidianLight", verts=16, r2=0.14, tilt=-0.42),
        t.ico(0.16, (0.06, -0.46, -0.34), "gold", subdiv=2),
        # Pomo coroado e empunhadura com anel torus
        t.crystal(0.09, 0.22, (0.06, -0.24, -0.06), "eyeNeon", tilt=(-0.95, 0.0), verts=6),
        t.cyl_axis_y(0.075, 0.48, (0.06, -0.42, -0.28), "ink", verts=16, r2=0.085, tilt=-pitch),
        t.torus(
            0.09,
            0.022,
            (0.06, -0.34, -0.16),
            "gold",
            major_seg=14,
            minor_seg=6,
            rot=(math.pi / 2 - pitch, 0.0, 0.0),
        ),
        # Guarda-cruz Bastiao-Fenda com anel de contencao torus
        t.box((0.42, 0.15, 0.18), (0.06, -0.56, -0.48), "goldBright", rot=(pitch, 0.0, 0.0), bevel=0.03),
        t.torus(
            0.16,
            0.026,
            (0.06, -0.56, -0.48),
            "arcaneViolet",
            major_seg=16,
            minor_seg=6,
            rot=(pitch, 0.0, 0.0),
        ),
        t.ico(0.11, (0.06, -0.56, -0.48), "eyeNeon", squash=(0.95, 0.95, 1.35), subdiv=1),
        t.crystal(0.10, 0.38, (0.22, -0.56, -0.48), "arcaneViolet", tilt=(pitch, -1.15), verts=6),
        t.crystal(0.10, 0.38, (-0.10, -0.56, -0.48), "arcaneViolet", tilt=(pitch, 1.15), verts=6),
        # Lamina-Obelisco chanfrada, fuller e runas brilhantes da Fenda
        t.box((0.24, 0.095, 1.18), (0.06, -0.88, -0.94), "obsidian", rot=(pitch, 0.0, 0.0), bevel=0.03),
        t.box((0.30, 0.055, 1.10), (0.06, -0.88, -0.94), "steel", rot=(pitch, 0.0, 0.0), bevel=0.02),
        t.box((0.12, 0.115, 1.06), (0.06, -0.87, -0.92), "arcaneViolet", rot=(pitch, 0.0, 0.0), bevel=0.02),
        t.box((0.065, 0.13, 1.00), (0.06, -0.86, -0.90), "eyeNeon", rot=(pitch, 0.0, 0.0), bevel=0.0),
        t.crystal(0.09, 0.32, (0.20, -0.74, -0.74), "tealSwarm", tilt=(pitch + 0.35, -0.85), verts=6),
        t.crystal(0.09, 0.32, (-0.08, -0.74, -0.74), "tealSwarm", tilt=(pitch + 0.35, 0.85), verts=6),
        # Ponta de obelisco na extremidade frontal
        t.crystal(0.15, 0.42, (0.06, -1.16, -1.34), "steel", tilt=(math.pi / 2 + pitch, 0.0), verts=6),
    ]


def rift_titan_arm_l():
    """A5 Braco Esquerdo: ombro em (0,0,0) + garra do vazio com anel torus arcaneViolet."""
    t = Rb("rift_titan")
    return [
        t.ball(0.32, (0.0, 0.0, 0.0), "obsidian", seg=20, rings=14),
        t.box((0.28, 0.18, 0.28), (-0.05, -0.12, -0.04), "violet", rot=(0.0, 0.0, 0.22), bevel=0.025),
        t.cyl(0.16, 0.46, (-0.02, -0.44, -0.04), "obsidian", verts=20, r2=0.19),
        t.cyl_axis_y(0.17, 0.46, (-0.05, -0.62, -0.18), "obsidianLight", verts=20, r2=0.14, tilt=-0.78),
        t.box((0.26, 0.22, 0.38), (-0.06, -0.64, -0.22), "obsidian", rot=(0.68, 0.0, 0.0), bevel=0.03),
        t.torus(
            0.21,
            0.032,
            (-0.05, -0.66, -0.22),
            "arcaneViolet",
            major_seg=18,
            minor_seg=8,
            rot=(math.pi / 2 - 0.78, 0.0, 0.0),
        ),
        t.ico(0.16, (-0.06, -0.76, -0.32), "eyeNeon", subdiv=2),
        t.capsule_seg((-0.14, -0.74, -0.32), (-0.18, -0.96, -0.62), 0.065, 0.012, "tealSwarm", verts=14),
        t.capsule_seg((-0.05, -0.76, -0.34), (-0.06, -1.00, -0.66), 0.070, 0.012, "eyeNeon", verts=14),
        t.capsule_seg((0.04, -0.74, -0.32), (0.08, -0.96, -0.62), 0.065, 0.012, "arcaneViolet", verts=14),
    ]


def rift_titan_leg(sx: int):
    """A5 Perna: greva blindada de obsidiana e violeta, anel de joelho e cristal da Fenda desde (0,0,0)."""
    t = Rb("rift_titan")
    return [
        t.ball(0.32, (0.0, 0.0, 0.0), "obsidian", seg=20, rings=14),
        t.cyl(0.24, 0.44, (0.0, -0.42, 0.0), "obsidianLight", verts=20, r2=0.26),
        t.box((0.22, 0.36, 0.24), (sx * 0.08, -0.24, -0.06), "violet", bevel=0.03),
        t.torus(0.22, 0.035, (0.0, -0.44, -0.02), "gold", major_seg=18, minor_seg=8),
        t.crystal(0.15, 0.38, (sx * 0.03, -0.44, -0.16), "tealSwarm", tilt=(0.52, -sx * 0.08), verts=6),
        t.cyl(0.20, 0.52, (0.0, -0.86, 0.0), "obsidian", verts=20, r2=0.23),
        t.box((0.18, 0.46, 0.14), (0.0, -0.64, -0.18), "steel", rot=(0.06, 0.0, 0.0), bevel=0.03),
        t.box((0.12, 0.38, 0.16), (sx * 0.14, -0.64, -0.06), "arcaneViolet", bevel=0.025),
        t.box((0.30, 0.20, 0.44), (0.0, -0.86, -0.06), "obsidian", bevel=0.035),
        t.crystal(0.13, 0.32, (0.0, -0.88, -0.24), "steel", tilt=(1.42, 0.0), verts=6),
    ]


BOSS_KIT_BUILDERS = {
    "iron_ram_colossus": {
        "torso": iron_ram_colossus_torso,
        "arm_r": iron_ram_colossus_arm_r,
        "arm_l": iron_ram_colossus_arm_l,
        "leg_l": lambda: iron_ram_colossus_leg(-1),
        "leg_r": lambda: iron_ram_colossus_leg(1),
    },
    "slag_juggernaut": {
        "torso": slag_juggernaut_torso,
        "arm_r": slag_juggernaut_arm_r,
        "arm_l": slag_juggernaut_arm_l,
        "leg_l": lambda: slag_juggernaut_leg(-1),
        "leg_r": lambda: slag_juggernaut_leg(1),
    },
    "rime_matriarch": {
        "torso": rime_matriarch_torso,
        "arm_r": rime_matriarch_arm_r,
        "arm_l": rime_matriarch_arm_l,
        "leg_l": lambda: rime_matriarch_leg(-1),
        "leg_r": lambda: rime_matriarch_leg(1),
    },
    "powder_baron": {
        "torso": powder_baron_torso,
        "arm_r": powder_baron_arm_r,
        "arm_l": powder_baron_arm_l,
        "leg_l": lambda: powder_baron_leg(-1),
        "leg_r": lambda: powder_baron_leg(1),
    },
    "rift_titan": {
        "torso": rift_titan_torso,
        "arm_r": rift_titan_arm_r,
        "arm_l": rift_titan_arm_l,
        "leg_l": lambda: rift_titan_leg(-1),
        "leg_r": lambda: rift_titan_leg(1),
    },
}


def _suavizacao_for(boss_id: str) -> dict:
    return {
        "modo": "hard_surface",
        "angulo_graus": 50 if boss_id == "rime_matriarch" else 46,
        "weighted_normals": True,
        "corrective_smooth": False,
    }


def specs():
    out = []
    for boss_idx, (boss_id, fn) in enumerate(
        (
            ("iron_ram_colossus", iron_ram_colossus),
            ("slag_juggernaut", slag_juggernaut),
            ("rime_matriarch", rime_matriarch),
            ("powder_baron", powder_baron),
            ("rift_titan", rift_titan),
        )
    ):
        sn = _suavizacao_for(boss_id)
        out.append(
            {
                "id": f"boss.{boss_id}.01",
                "name": f"BOSS_{boss_id}",
                "glb": f"boss_{boss_id}.glb",
                "tipo": "prop_estatico",
                "limite": LIMITE,
                "suavizacao_normais": sn,
                "tags": ["muralha", "boss", boss_id],
                "seed": L.SEED_BASE + boss_idx * 101,
                "build": fn,
            }
        )
        kit = BOSS_KIT_BUILDERS[boss_id]
        for part_idx, part in enumerate(("torso", "arm_r", "arm_l", "leg_l", "leg_r")):
            is_torso = part == "torso"
            out.append(
                {
                    "id": f"boss.{boss_id}.{part}.01",
                    "name": f"BOSS_{boss_id}_{part}",
                    "glb": f"boss_{boss_id}_{part}.glb",
                    "tipo": "prop_estatico",
                    "pivot": "base" if is_torso else "origem",
                    "center_xy": is_torso,
                    "limite": LIMITE_TORSO if is_torso else LIMITE_PART,
                    "suavizacao_normais": sn,
                    "tags": ["muralha", "boss", boss_id, part],
                    "seed": L.SEED_BASE + 9000 + len(out) * 37 + part_idx,
                    "build": kit[part],
                }
            )
    return out


L.run_group("bosses", specs(), "5 bosses esculpidos + 25 sub-malhas articuladas da campanha (art/scripts/make_bosses.py)")
