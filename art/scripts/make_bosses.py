"""Gera os 5 Bosses esculpidos da campanha (BOSS_iron_ram_colossus, BOSS_slag_juggernaut,
BOSS_rime_matriarch, BOSS_powder_baron, BOSS_rift_titan).

Silhuetas imponentes (<= 2200 tris cada) para ocupacao multi-lane na arena.
Mapeamento Roblox -> Blender (frente -Z no Studio = -Y no Blender): (x, y, z) -> (-x, z, y).

Uso headless:
  blender -b --factory-startup --python-exit-code 1 --python art/scripts/make_bosses.py
Saidas: art/export/boss_<bossId>.glb, art/forge/lote_bosses_import.yaml (gerado),
        art/renders/bosses/*.png (ignorado no git)
"""

from __future__ import annotations

import math
import os
import sys

sys.dont_write_bytecode = True  # sem __pycache__ em art/scripts
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lowpoly_lib as L  # noqa: E402

LIMITE = 2200
LIMITE_PART = 900
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

    def ball(self, diam, pos, color, seg=8, rings=5, squash=(1.0, 1.0, 1.0)):
        return L.ball(
            diam / 2 * self.k,
            self.p(*pos),
            color,
            seg=seg,
            rings=rings,
            squash=(squash[0], squash[2], squash[1]),
        )

    def ico(self, rad, pos, color, squash=(1.0, 1.0, 1.0)):
        return L.ico(
            rad * self.k,
            self.p(*pos),
            color,
            squash=(squash[0], squash[2], squash[1]),
        )

    def cyl(self, r, h, base, color, verts=8, r2=None, rot_z=0.0):
        return L.cyl(
            r * self.k,
            h * self.k,
            self.p(*base),
            color,
            verts=verts,
            r2=None if r2 is None else r2 * self.k,
            rot_z=rot_z,
        )

    def cyl_axis_y(self, r, length, center, color, verts=8, r2=None, tilt=0.0):
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

    def box(self, size, center, color, rot=(0.0, 0.0, 0.0)):
        return L.box(
            (size[0] * self.k, size[2] * self.k, size[1] * self.k),
            self.p(*center),
            color,
            rot=rot,
        )


def iron_ram_colossus():
    """Act 1: Colosso Ariete com manoplas-ariete de ferro chifrudas e nucleo de fornalha."""
    b = Rb("iron_ram_colossus")
    p = []

    # Pernas de cerco macicas + joelheiras com espigoes
    for sx in (-1, 1):
        p.append(b.cyl(0.32, 0.88, (sx * 0.44, 0.0, 0.0), "ironDark", verts=8, r2=0.26))
        p.append(b.box((0.46, 0.24, 0.64), (sx * 0.44, 0.12, -0.10), "iron"))
        p.append(b.crystal(0.14, 0.36, (sx * 0.44, 0.54, -0.26), "steel", tilt=(1.2, 0.0), verts=4))

    # Cintura e torso blindado + grade de fornalha incandescente (-Z)
    p.append(b.cyl(0.62, 0.34, (0, 0.82, 0.0), "ironDark", verts=8, r2=0.58))
    p.append(b.ico(0.76, (0, 1.48, 0.02), "iron", squash=(1.18, 1.05, 0.86)))
    p.append(b.ico(0.38, (0, 1.46, -0.46), "ember", squash=(0.95, 1.05, 0.55)))
    for sx in (-1, 1):
        p.append(b.box((0.12, 0.62, 0.14), (sx * 0.16, 1.46, -0.62), "ironDark"))
    p.append(b.box((0.72, 0.12, 0.14), (0, 1.46, -0.62), "ironDark"))

    # Bastiões de ombro com chifres de ferro curvos
    for sx in (-1, 1):
        p.append(b.ball(0.76, (sx * 0.82, 1.82, 0.0), "iron", seg=8, rings=5, squash=(1.06, 0.88, 1.02)))
        p.append(b.crystal(0.18, 0.72, (sx * 0.88, 2.08, -0.02), "steel", tilt=(0.28, -sx * 0.55), verts=5))

    # Bracos e manoplas-ariete de ferro chifrudas apontadas para frente (-Z)
    for sx in (-1, 1):
        p.append(b.cyl(0.24, 0.78, (sx * 0.94, 0.96, -0.18), "ironDark", verts=8, r2=0.22))
        p.append(b.box((0.52, 0.48, 0.86), (sx * 0.92, 0.92, -0.62), "iron"))
        p.append(b.crystal(0.22, 0.54, (sx * 0.92, 0.94, -1.04), "steel", tilt=(math.pi / 2, 0.0), verts=4))
        p.append(b.crystal(0.10, 0.44, (sx * 1.12, 1.16, -0.84), "amberBright", tilt=(0.8, -sx * 0.4), verts=4))

    # Elmo de cerco com viseira de fornalha e chifres frontais
    p.append(b.ico(0.46, (0, 2.18, -0.14), "ironDark", squash=(0.98, 0.92, 1.02)))
    p.append(b.ico(0.22, (0, 2.16, -0.48), "amberBright", squash=(1.65, 0.38, 0.40)))
    for sx in (-1, 1):
        p.append(b.crystal(0.15, 0.78, (sx * 0.30, 2.34, -0.10), "steel", tilt=(0.65, -sx * 0.65), verts=5))

    return p


def slag_juggernaut():
    """Act 2: Juggernaut de Escoria com caldeirao fundido, chamines e crista de magma."""
    j = Rb("slag_juggernaut")
    p = []

    # Pernas grossas de fundicao
    for sx in (-1, 1):
        p.append(b_leg := j.cyl(0.36, 0.78, (sx * 0.52, 0.0, 0.0), "stoneDark", verts=8, r2=0.30))
        p.append(j.box((0.52, 0.22, 0.64), (sx * 0.52, 0.11, -0.08), "ironDark"))

    # Torso caldeirao bojudissimo com magma incandescente
    p.append(j.cyl(0.86, 0.96, (0, 0.72, 0.0), "ironDark", verts=10, r2=0.78))
    p.append(j.ico(0.56, (0, 1.24, -0.44), "danger", squash=(1.05, 0.92, 0.58)))
    p.append(j.ico(0.36, (0, 1.24, -0.58), "amberBright", squash=(0.95, 0.85, 0.45)))
    p.append(j.cyl(0.88, 0.18, (0, 1.56, 0.0), "stoneDark", verts=10, r2=0.88))

    # Chamines de fundicao duplas nas costas (+Z Roblox / +Y Blender)
    for sx in (-1, 1):
        p.append(j.crystal(0.22, 1.15, (sx * 0.52, 1.66, 0.42), "stoneDark", tilt=(-0.38, -sx * 0.18), verts=8, r2=0.18))
        p.append(j.ico(0.20, (sx * 0.58, 2.66, 0.78), "ember", squash=(1.0, 0.8, 1.0)))

    # Bracos e punhos martelo de escoria
    for sx in (-1, 1):
        p.append(j.ball(0.68, (sx * 0.94, 1.62, 0.0), "stoneDark", seg=8, rings=5))
        p.append(j.cyl(0.24, 0.82, (sx * 1.02, 0.82, -0.14), "ironDark", verts=8, r2=0.22))
        p.append(j.ico(0.42, (sx * 1.04, 0.76, -0.34), "ember", squash=(1.05, 0.95, 1.15)))

    # Cabeca funda com crista de magma brilhante
    p.append(j.ico(0.46, (0, 1.98, -0.22), "ironDark", squash=(1.05, 0.86, 0.96)))
    for sx in (-1, 1):
        p.append(j.ico(0.11, (sx * 0.18, 1.98, -0.56), "neonAmber", squash=(1.35, 0.55, 0.55)))
    for k in range(4):
        p.append(
            j.crystal(
                0.15,
                0.56 - k * 0.06,
                (0, 2.24 - k * 0.05, -0.16 + k * 0.18),
                "ember" if k % 2 == 0 else "amberBright",
                tilt=(-0.25 - k * 0.25, 0.0),
                verts=4,
            )
        )

    return p


def rime_matriarch():
    """Act 3: Matriarca Boreal com coroa de gelo, manto pontiagudo e nucleo crio."""
    m = Rb("rime_matriarch")
    p = []

    # Saia glacial alta com cristais periféricos
    p.append(m.cyl(0.86, 1.24, (0, 0.0, 0.0), "stoneDark", verts=8, r2=0.48))
    for k in range(8):
        a = 2 * math.pi * k / 8
        p.append(
            m.crystal(
                0.22,
                0.92,
                (0.70 * math.cos(a), 0.12, 0.70 * math.sin(a)),
                "ice" if k % 2 == 0 else "iceLight",
                tilt=(-0.22 * math.sin(a), -0.22 * math.cos(a)),
                verts=4,
            )
        )

    # Corpete esguio e nucleo crio brilhante no peito (-Z)
    p.append(m.ico(0.56, (0, 1.54, 0.0), "stoneDark", squash=(1.04, 1.18, 0.78)))
    p.append(m.crystal(0.22, 0.52, (0, 1.56, -0.40), "iceGlow", tilt=(1.45, 0.0), verts=5))

    # Manto pontiagudo de ombreiras cristalinas
    for sx in (-1, 1):
        p.append(m.crystal(0.24, 1.05, (sx * 0.62, 1.78, 0.06), "ice", tilt=(-0.22, -sx * 0.62), verts=4))
        p.append(m.crystal(0.18, 0.82, (sx * 0.84, 1.66, 0.16), "iceLight", tilt=(-0.38, -sx * 0.92), verts=4))
        # Bracos com garras de gelo
        p.append(m.cyl(0.16, 0.86, (sx * 0.76, 1.04, -0.22), "ironDark", verts=6, r2=0.12))
        p.append(m.crystal(0.12, 0.52, (sx * 0.76, 1.02, -0.64), "iceGlow", tilt=(1.35, 0.0), verts=4))

    # Elmo soberano + coroa multi-pontas de gelo
    p.append(m.ball(0.76, (0, 2.22, -0.06), "ironDark", seg=8, rings=5, squash=(0.92, 1.08, 0.98)))
    for sx in (-1, 1):
        p.append(m.ico(0.10, (sx * 0.14, 2.22, -0.40), "iceGlow", squash=(1.4, 0.55, 0.55)))
    for k in range(5):
        ang = (k - 2) * 0.42
        p.append(
            m.crystal(
                0.12,
                0.96 - abs(k - 2) * 0.16,
                (math.sin(ang) * 0.24, 2.52, -0.02 + abs(k - 2) * 0.04),
                "iceGlow" if k == 2 else "iceLight",
                tilt=(-0.12, -ang * 0.65),
                verts=4,
            )
        )

    return p


def powder_baron():
    """Act 4: Baronesa da Polvora com morteiros duplos nos ombros, tricornio e frisos de latao."""
    pb = Rb("powder_baron")
    p = []

    # Botas blindadas + casaco de cerco
    for sx in (-1, 1):
        p.append(pb.cyl(0.28, 0.86, (sx * 0.38, 0.0, 0.0), "ironDark", verts=8, r2=0.24))
        p.append(pb.cyl(0.32, 0.16, (sx * 0.38, 0.70, 0.0), "bronze", verts=8, r2=0.32))
    p.append(pb.cyl(0.68, 0.56, (0, 0.68, 0.0), "roof", verts=8, r2=0.52))

    # Couraca com bandoleiras cruzadas e fivela dourada
    p.append(pb.ico(0.64, (0, 1.44, 0.0), "ironDark", squash=(1.12, 1.06, 0.82)))
    p.append(pb.ico(0.26, (0, 1.46, -0.46), "goldBright", squash=(1.0, 1.0, 0.55)))
    for sx in (-1, 1):
        p.append(pb.box((0.14, 0.72, 0.16), (sx * 0.26, 1.44, -0.42), "bronze", rot=(0, 0, sx * 0.42)))

    # Morteiros duplos de ombro inclinados para frente (-Z Roblox / -Y Blender)
    for sx in (-1, 1):
        p.append(pb.ball(0.62, (sx * 0.76, 1.72, 0.0), "bronze", seg=8, rings=5))
        p.append(pb.cyl_axis_y(0.24, 1.15, (sx * 0.78, 2.02, -0.22), "ironDark", verts=10, r2=0.28, tilt=0.45))
        p.append(pb.cyl_axis_y(0.29, 0.18, (sx * 0.78, 2.24, -0.68), "gold", verts=10, r2=0.29, tilt=0.45))
        p.append(pb.ico(0.14, (sx * 0.78, 2.16, 0.34), "danger"))
        # Manoplas frontais
        p.append(pb.cyl(0.20, 0.76, (sx * 0.84, 0.94, -0.18), "ironDark", verts=8, r2=0.18))
        p.append(pb.ico(0.26, (sx * 0.84, 0.92, -0.46), "bronze"))

    # Cabeca e chapeu tricornio de cerco com pluma e visor
    p.append(pb.ball(0.76, (0, 2.12, -0.06), "ironDark", seg=8, rings=5))
    for sx in (-1, 1):
        p.append(pb.ico(0.10, (sx * 0.14, 2.12, -0.40), "amberBright", squash=(1.35, 0.55, 0.55)))
    p.append(pb.cyl(0.78, 0.14, (0, 2.34, -0.04), "ironDark", verts=6, r2=0.72))
    p.append(pb.cyl(0.48, 0.36, (0, 2.44, -0.02), "gold", verts=6, r2=0.38))
    p.append(pb.crystal(0.16, 0.68, (0.28, 2.66, 0.12), "roof", tilt=(-0.68, -0.35), verts=4))

    return p


def rift_titan():
    """Act 5: Tita Soberano da Fenda Turquesa — elmo chifrudo, manto soberano, ombreiras de draco e Lamina-Obelisco fincada."""
    t = Rb("rift_titan")
    p = []

    # 1. Sabatons, grevas, joelheiras da Fenda e coxotes em postura heroica (y = 0.0 .. 1.26)
    for sx in (-1, 1):
        z_leg = -0.10 if sx == 1 else 0.06
        lx = sx * 0.36
        p.append(t.box((0.28, 0.20, 0.40), (lx, 0.10, z_leg - 0.05), "ironDark"))
        p.append(t.crystal(0.14, 0.32, (lx, 0.09, z_leg - 0.20), "iron", tilt=(1.42, 0.0), verts=4))
        p.append(t.cyl(0.20, 0.60, (lx, 0.18, z_leg), "ironDark", verts=6, r2=0.24))
        p.append(t.box((0.13, 0.50, 0.10), (lx, 0.45, z_leg - 0.20), "iron", rot=(0.06, 0.0, 0.0)))
        p.append(
            t.crystal(
                0.16,
                0.38,
                (lx, 0.68, z_leg - 0.18),
                "tealSwarm",
                tilt=(0.48, 0.0),
                verts=4,
            )
        )
        p.append(t.cyl(0.25, 0.48, (sx * 0.34, 0.76, z_leg * 0.5), "stoneDark", verts=6, r2=0.27))

    # 2. Cinturao soberano, escarcelas laterais e estandarte frontal bipartido (y = 0.36 .. 1.38)
    p.append(t.cyl(0.45, 0.28, (0.0, 1.12, -0.02), "ironDark", verts=8, r2=0.42))
    p.append(t.cyl(0.44, 0.11, (0.0, 1.28, -0.02), "gold", verts=8, r2=0.44))
    p.append(
        t.crystal(
            0.13,
            0.22,
            (0.0, 1.18, -0.44),
            "tealSwarm",
            verts=4,
            r2=0.13,
            spin=math.pi / 4,
        )
    )
    p.append(
        t.crystal(
            0.07,
            0.14,
            (0.0, 1.22, -0.47),
            "eyeNeon",
            verts=4,
            r2=0.07,
            spin=math.pi / 4,
        )
    )
    for sx in (-1, 1):
        p.append(
            t.box(
                (0.22, 0.44, 0.36),
                (sx * 0.48, 1.04, -0.02),
                "iron",
                rot=(0.0, sx * 0.24, 0.0),
            )
        )
        p.append(
            t.box(
                (0.20, 0.08, 0.38),
                (sx * 0.52, 0.84, -0.02),
                "goldBright",
                rot=(0.0, sx * 0.24, 0.0),
            )
        )
    p.append(t.box((0.26, 0.80, 0.06), (0.0, 0.84, -0.36), "tealDark", rot=(-0.05, 0.0, 0.0)))
    p.append(t.box((0.08, 0.72, 0.075), (0.0, 0.86, -0.37), "tealSwarm", rot=(-0.05, 0.0, 0.0)))
    p.append(
        t.crystal(
            0.14,
            0.24,
            (0.0, 0.45, -0.38),
            "goldBright",
            tilt=(math.pi, 0.0),
            verts=4,
        )
    )

    # 3. Couraca soberana e Coracao da Fenda pulsante (-Z) (y = 1.36 .. 2.30)
    p.append(t.cyl(0.42, 0.38, (0.0, 1.36, -0.04), "ironDark", verts=8, r2=0.52))
    p.append(t.ico(0.60, (0.0, 1.84, -0.08), "iron", squash=(1.22, 0.96, 0.58)))
    p.append(t.ico(0.38, (0.0, 1.82, -0.26), "ink", squash=(0.90, 0.92, 0.45)))
    p.append(t.ico(0.26, (0.0, 1.84, -0.39), "tealSwarm", squash=(0.82, 1.08, 0.40)))
    p.append(t.ico(0.16, (0.0, 1.84, -0.44), "eyeNeon", squash=(0.68, 1.02, 0.38)))
    for sx in (-1, 1):
        for i in range(3):
            rib_col = "goldBright" if i == 1 else "tealSwarm"
            p.append(
                t.box(
                    (0.26, 0.075, 0.11),
                    (sx * 0.28, 1.66 + i * 0.14, -0.37),
                    rib_col,
                    rot=(0.0, 0.0, sx * 0.26),
                )
            )
    p.append(t.cyl(0.38, 0.22, (0.0, 2.08, -0.02), "ironDark", verts=8, r2=0.44))

    # 4. Manto soberano pregueado caindo para tras (+Z Roblox / +Y Blender)
    p.append(t.box((1.26, 0.22, 0.30), (0.0, 2.08, 0.26), "tealBruteDark", rot=(0.20, 0.0, 0.0)))
    for idx in range(-3, 4):
        u = idx / 3.0
        cx = u * 0.62
        cy = 1.06
        cz = 0.56 - (1.0 - abs(u)) * 0.04
        col = "stoneDark" if idx % 2 == 0 else ("tealBruteDark" if abs(idx) == 1 else "ink")
        p.append(
            t.box(
                (0.30, 1.96, 0.07 + (idx % 2) * 0.02),
                (cx, cy, cz),
                col,
                rot=(0.20, u * 0.22, u * 0.06),
            )
        )
        if idx in (-2, 0, 2):
            p.append(
                t.crystal(
                    0.11,
                    0.34,
                    (u * 0.78, 0.24, 0.72),
                    "teal",
                    tilt=(math.pi - 0.20, u * 0.22),
                    verts=4,
                )
            )

    # 5. Ombreiras de draco da Fenda (y = 1.94 .. 2.68)
    for sx in (-1, 1):
        p.append(
            t.ball(
                0.58,
                (sx * 0.68, 2.04, -0.02),
                "ironDark",
                seg=8,
                rings=5,
                squash=(1.15, 0.95, 1.05),
            )
        )
        p.append(
            t.box(
                (0.46, 0.18, 0.56),
                (sx * 0.80, 2.14, 0.02),
                "iron",
                rot=(0.08, sx * 0.34, 0.0),
            )
        )
        p.append(
            t.box(
                (0.42, 0.075, 0.44),
                (sx * 0.78, 2.23, -0.02),
                "goldBright",
                rot=(0.08, sx * 0.32, 0.0),
            )
        )
        p.append(
            t.crystal(
                0.14,
                0.66,
                (sx * 0.84, 2.10, 0.04),
                "tealSwarm",
                tilt=(-0.22, -sx * 0.62),
                verts=5,
            )
        )
        p.append(
            t.crystal(
                0.10,
                0.40,
                (sx * 0.82, 2.00, -0.22),
                "steel",
                tilt=(0.68, -sx * 0.46),
                verts=4,
            )
        )

    # 6. Elmo soberano chifrudo e halo arcano flutuante (y = 2.22 .. 3.24)
    p.append(t.ico(0.36, (0.0, 2.40, -0.05), "ironDark", squash=(0.90, 1.08, 0.98)))
    for sx in (-1, 1):
        p.append(
            t.box(
                (0.12, 0.28, 0.22),
                (sx * 0.18, 2.32, -0.24),
                "iron",
                rot=(0.08, 0.0, -sx * 0.14),
            )
        )
        p.append(
            t.box(
                (0.17, 0.055, 0.08),
                (sx * 0.11, 2.40, -0.37),
                "eyeNeon",
                rot=(0.0, 0.0, -sx * 0.28),
            )
        )
        p.append(
            t.crystal(
                0.12,
                0.36,
                (sx * 0.24, 2.46, -0.04),
                "ironDark",
                tilt=(0.10, -sx * 1.05),
                verts=5,
                r2=0.09,
            )
        )
        p.append(
            t.crystal(
                0.09,
                0.38,
                (sx * 0.54, 2.60, -0.08),
                "teal",
                tilt=(0.18, -sx * 0.28),
                verts=5,
                r2=0.055,
            )
        )
        p.append(
            t.crystal(
                0.055,
                0.34,
                (sx * 0.64, 2.95, -0.14),
                "eyeNeon",
                tilt=(0.24, sx * 0.22),
                verts=4,
                r2=0.0,
            )
        )
    p.append(t.crystal(0.09, 0.42, (0.0, 2.58, -0.10), "goldBright", tilt=(-0.24, 0.0), verts=4))
    for k in range(5):
        ang = -0.8 + 0.4 * k
        pos_h = (0.62 * math.sin(ang), 2.74 + (1 - abs(k - 2) * 0.3) * 0.22, 0.26)
        p.append(
            t.crystal(
                0.08,
                0.38,
                pos_h,
                "eyeNeon" if k % 2 == 0 else "tealSwarm",
                tilt=(-0.15, -ang * 0.35),
                verts=4,
            )
        )

    # 7. Bracos assimetricos e colossal Lamina-Obelisco da Fenda fincada ao chao (y = 0.02 .. 2.82)
    # Braco esquerdo (garra e lamina de pulso)
    p.append(t.cyl(0.16, 0.48, (-0.74, 1.54, -0.04), "ironDark", verts=6, r2=0.19))
    p.append(t.cyl_axis_y(0.17, 0.50, (-0.78, 1.30, -0.18), "iron", verts=6, r2=0.14, tilt=-0.85))
    p.append(t.ico(0.16, (-0.80, 1.06, -0.32), "ironDark"))
    p.append(
        t.crystal(
            0.09,
            0.40,
            (-0.88, 1.18, -0.26),
            "tealSwarm",
            tilt=(2.35, 0.15),
            verts=4,
        )
    )

    # Braco direito erguido segurando a empunhadura
    sx_w, sz_w = 0.90, -0.48
    p.append(t.cyl_axis_y(0.17, 0.50, (0.76, 1.98, -0.18), "ironDark", verts=6, r2=0.15, tilt=0.22))
    p.append(t.cyl_axis_y(0.16, 0.52, (0.85, 2.08, -0.35), "iron", verts=6, r2=0.14, tilt=0.45))
    p.append(t.ico(0.16, (sx_w, 2.18, sz_w), "gold"))

    # Lamina-Obelisco da Fenda fincada em (sx_w, sz_w)
    p.append(
        t.crystal(
            0.16,
            0.44,
            (sx_w, 0.46, sz_w),
            "steel",
            tilt=(math.pi, 0.0),
            verts=4,
            spin=0.0,
        )
    )
    for q in (-1, 1):
        p.append(
            t.box(
                (0.085, 1.40, 0.048),
                (sx_w + q * 0.11, 1.15, sz_w),
                "steel",
                rot=(0.0, 0.0, math.pi / 4),
            )
        )
        p.append(
            t.crystal(
                0.09,
                0.32,
                (sx_w + q * 0.15, 1.58, sz_w),
                "tealSwarm",
                tilt=(0.0, -q * 0.95),
                verts=4,
            )
        )
    p.append(t.box((0.20, 1.44, 0.075), (sx_w, 1.15, sz_w), "ironDark"))
    p.append(t.box((0.065, 1.36, 0.098), (sx_w, 1.16, sz_w), "eyeNeon"))

    # Guarda-cruz Bastiao-Fenda
    p.append(t.box((0.32, 0.14, 0.16), (sx_w, 1.86, sz_w), "goldBright"))
    p.append(t.ico(0.10, (sx_w, 1.86, sz_w), "eyeNeon", squash=(0.95, 0.95, 1.35)))
    for q in (-1, 1):
        p.append(
            t.crystal(
                0.10,
                0.42,
                (sx_w + q * 0.12, 1.86, sz_w),
                "ironDark",
                tilt=(-0.10, -q * 1.22),
                verts=4,
            )
        )
        p.append(
            t.crystal(
                0.065,
                0.22,
                (sx_w + q * 0.42, 1.94, sz_w),
                "goldBright",
                tilt=(-0.12, -q * 0.75),
                verts=4,
            )
        )

    # Empunhadura longa e pomo coroado
    p.append(t.cyl(0.072, 0.54, (sx_w, 1.94, sz_w), "ink", verts=6, r2=0.082))
    for yr in (2.04, 2.32):
        p.append(t.cyl(0.092, 0.05, (sx_w, yr, sz_w), "gold", verts=6, r2=0.092))
    p.append(t.cyl(0.125, 0.12, (sx_w, 2.48, sz_w), "goldBright", verts=6, r2=0.095))
    p.append(t.crystal(0.085, 0.22, (sx_w, 2.58, sz_w), "eyeNeon", verts=4))

    return p


# ---------------------------------------------------------------- kits articulados de 5 partes (torso, arm_r, arm_l, leg_l, leg_r)
def iron_ram_colossus_torso():
    """A1 Torso: cintura blindada, peitoral com grade de fornalha, ombreiras chifrudas e elmo de cerco."""
    b = Rb("iron_ram_colossus")
    p = [
        b.cyl(0.62, 0.34, (0.0, 0.82, 0.0), "ironDark", verts=8, r2=0.58),
        b.ico(0.76, (0.0, 1.48, 0.02), "iron", squash=(1.18, 1.05, 0.86)),
        b.ico(0.38, (0.0, 1.46, -0.46), "ember", squash=(0.95, 1.05, 0.55)),
        b.box((0.72, 0.12, 0.14), (0.0, 1.46, -0.62), "ironDark"),
        b.ico(0.46, (0.0, 2.18, -0.14), "ironDark", squash=(0.98, 0.92, 1.02)),
        b.ico(0.22, (0.0, 2.16, -0.48), "amberBright", squash=(1.65, 0.38, 0.40)),
    ]
    for sx in (-1, 1):
        p.append(b.box((0.12, 0.62, 0.14), (sx * 0.16, 1.46, -0.62), "ironDark"))
        p.append(b.ball(0.76, (sx * 0.82, 1.82, 0.0), "iron", seg=8, rings=5, squash=(1.06, 0.88, 1.02)))
        p.append(b.crystal(0.18, 0.72, (sx * 0.88, 2.08, -0.02), "steel", tilt=(0.28, -sx * 0.55), verts=5))
        p.append(b.crystal(0.15, 0.78, (sx * 0.30, 2.34, -0.10), "steel", tilt=(0.65, -sx * 0.65), verts=5))
    return p


def iron_ram_colossus_arm_r():
    """A1 Braco Direito: ombro em (0,0,0) + manopla-ariete de cerco chifruda apontada para frente-baixo."""
    b = Rb("iron_ram_colossus")
    return [
        b.ball(0.38, (0.0, 0.0, 0.0), "ironDark", seg=8, rings=4),
        b.cyl(0.22, 0.52, (0.02, -0.50, -0.06), "ironDark", verts=8, r2=0.24),
        b.box((0.48, 0.44, 0.78), (0.04, -0.68, -0.44), "iron", rot=(0.32, 0.0, 0.0)),
        b.box((0.54, 0.18, 0.30), (0.04, -0.56, -0.36), "ironDark", rot=(0.32, 0.0, 0.0)),
        b.ico(0.20, (0.04, -0.72, -0.68), "ember", squash=(0.95, 0.85, 0.65)),
        b.crystal(0.22, 0.56, (0.04, -0.78, -0.82), "steel", tilt=(math.pi / 2 + 0.32, 0.0), verts=4),
        b.crystal(0.11, 0.44, (0.24, -0.58, -0.64), "amberBright", tilt=(0.95, -0.38), verts=4),
        b.crystal(0.11, 0.44, (-0.16, -0.58, -0.64), "amberBright", tilt=(0.95, 0.38), verts=4),
    ]


def iron_ram_colossus_arm_l():
    """A1 Braco Esquerdo: ombro em (0,0,0) + escudo-manopla de ferro com espigao frontal."""
    b = Rb("iron_ram_colossus")
    return [
        b.ball(0.36, (0.0, 0.0, 0.0), "ironDark", seg=8, rings=4),
        b.cyl(0.21, 0.54, (-0.02, -0.52, -0.06), "ironDark", verts=8, r2=0.23),
        b.box((0.44, 0.42, 0.68), (-0.04, -0.68, -0.36), "iron", rot=(0.26, 0.0, 0.0)),
        b.box((0.18, 0.56, 0.58), (-0.24, -0.62, -0.34), "ironDark", rot=(0.20, 0.14, 0.0)),
        b.crystal(0.18, 0.46, (-0.04, -0.74, -0.68), "steel", tilt=(math.pi / 2 + 0.26, 0.0), verts=4),
        b.crystal(0.10, 0.38, (-0.22, -0.54, -0.54), "amberBright", tilt=(0.82, 0.36), verts=4),
    ]


def iron_ram_colossus_leg(sx: int):
    """A1 Perna: quadril em (0,0,0) descendo ate a bota de cerco com joelheira chifruda."""
    b = Rb("iron_ram_colossus")
    return [
        b.ball(0.34, (0.0, 0.0, 0.0), "ironDark", seg=6, rings=4),
        b.cyl(0.28, 0.78, (0.0, -0.78, 0.0), "ironDark", verts=8, r2=0.24),
        b.box((0.36, 0.26, 0.24), (sx * 0.04, -0.38, -0.14), "iron"),
        b.crystal(0.14, 0.36, (sx * 0.04, -0.36, -0.24), "steel", tilt=(1.22, -sx * 0.12), verts=4),
        b.box((0.44, 0.24, 0.62), (0.0, -0.78, -0.10), "iron"),
        b.crystal(0.11, 0.26, (0.0, -0.82, -0.38), "steel", tilt=(1.48, 0.0), verts=4),
    ]


def slag_juggernaut_torso():
    """A2 Torso: caldeirao fundido, magma incandescente, chamines duplas e cabeca com crista."""
    j = Rb("slag_juggernaut")
    p = [
        j.cyl(0.86, 0.96, (0.0, 0.72, 0.0), "ironDark", verts=10, r2=0.78),
        j.ico(0.56, (0.0, 1.24, -0.44), "danger", squash=(1.05, 0.92, 0.58)),
        j.ico(0.36, (0.0, 1.24, -0.58), "amberBright", squash=(0.95, 0.85, 0.45)),
        j.cyl(0.88, 0.18, (0.0, 1.56, 0.0), "stoneDark", verts=10, r2=0.88),
        j.ico(0.46, (0.0, 1.98, -0.22), "ironDark", squash=(1.05, 0.86, 0.96)),
    ]
    for sx in (-1, 1):
        p.append(j.ball(0.64, (sx * 0.90, 1.62, 0.0), "stoneDark", seg=8, rings=5))
        p.append(
            j.crystal(
                0.22,
                1.15,
                (sx * 0.52, 1.66, 0.42),
                "stoneDark",
                tilt=(-0.38, -sx * 0.18),
                verts=8,
                r2=0.18,
            )
        )
        p.append(j.ico(0.20, (sx * 0.58, 2.66, 0.78), "ember", squash=(1.0, 0.8, 1.0)))
        p.append(j.ico(0.11, (sx * 0.18, 1.98, -0.56), "neonAmber", squash=(1.35, 0.55, 0.55)))
    for k in range(4):
        p.append(
            j.crystal(
                0.15,
                0.56 - k * 0.06,
                (0.0, 2.24 - k * 0.05, -0.16 + k * 0.18),
                "ember" if k % 2 == 0 else "amberBright",
                tilt=(-0.25 - k * 0.25, 0.0),
                verts=4,
            )
        )
    return p


def slag_juggernaut_arm_r():
    """A2 Braco Direito: ombro em (0,0,0) + martelo de guerra de escoria fundida."""
    j = Rb("slag_juggernaut")
    return [
        j.ball(0.38, (0.0, 0.0, 0.0), "stoneDark", seg=8, rings=4),
        j.cyl(0.22, 0.58, (0.02, -0.54, -0.08), "ironDark", verts=8, r2=0.24),
        j.ico(0.30, (0.04, -0.62, -0.22), "ember", squash=(1.05, 0.90, 1.05)),
        # Haste e cabeca do Martelo de Escoria inclinadas para frente (-Z) e baixo (-Y)
        j.cyl_axis_y(0.11, 0.98, (0.04, -0.66, -0.54), "ironDark", verts=8, r2=0.12, tilt=-0.38),
        j.box((0.64, 0.40, 0.42), (0.04, -0.82, -0.94), "stoneDark", rot=(0.38, 0.0, 0.0)),
        j.ico(0.28, (0.04, -0.82, -0.96), "danger", squash=(1.28, 0.82, 0.82)),
        j.crystal(0.14, 0.36, (0.04, -0.90, -1.12), "amberBright", tilt=(math.pi / 2 + 0.38, 0.0), verts=4),
    ]


def slag_juggernaut_arm_l():
    """A2 Braco Esquerdo: ombro em (0,0,0) + garra/punho esmagador de cadinho."""
    j = Rb("slag_juggernaut")
    return [
        j.ball(0.38, (0.0, 0.0, 0.0), "stoneDark", seg=8, rings=4),
        j.cyl(0.23, 0.58, (-0.02, -0.56, -0.08), "ironDark", verts=8, r2=0.25),
        j.ico(0.38, (-0.04, -0.72, -0.28), "ember", squash=(1.08, 0.95, 1.12)),
        j.box((0.40, 0.32, 0.38), (-0.06, -0.70, -0.32), "stoneDark", rot=(0.24, 0.0, 0.0)),
        j.crystal(0.13, 0.34, (-0.14, -0.80, -0.48), "amberBright", tilt=(1.35, 0.22), verts=4),
        j.crystal(0.13, 0.34, (0.06, -0.80, -0.48), "danger", tilt=(1.35, -0.18), verts=4),
    ]


def slag_juggernaut_leg(sx: int):
    """A2 Perna: pilar de fundicao a partir do quadril (0,0,0) com ventilacao de brasa."""
    j = Rb("slag_juggernaut")
    return [
        j.ball(0.36, (0.0, 0.0, 0.0), "stoneDark", seg=6, rings=4),
        j.cyl(0.32, 0.74, (0.0, -0.74, 0.0), "stoneDark", verts=8, r2=0.28),
        j.ico(0.20, (sx * 0.05, -0.38, -0.22), "ember", squash=(0.95, 0.80, 0.65)),
        j.box((0.48, 0.22, 0.60), (0.0, -0.74, -0.08), "ironDark"),
        j.box((0.36, 0.12, 0.22), (0.0, -0.66, -0.32), "ember"),
    ]


def rime_matriarch_torso():
    """A3 Torso: corpete glacial, nucleo crio no peito, manto de cristais e coroa boreal."""
    m = Rb("rime_matriarch")
    p = [
        m.cyl(0.46, 0.42, (0.0, 0.96, 0.0), "stoneDark", verts=8, r2=0.38),
        m.ico(0.56, (0.0, 1.54, 0.0), "stoneDark", squash=(1.04, 1.18, 0.78)),
        m.crystal(0.22, 0.52, (0.0, 1.56, -0.40), "iceGlow", tilt=(1.45, 0.0), verts=5),
        m.ball(0.76, (0.0, 2.22, -0.06), "ironDark", seg=8, rings=5, squash=(0.92, 1.08, 0.98)),
    ]
    for sx in (-1, 1):
        p.append(m.crystal(0.24, 1.05, (sx * 0.62, 1.78, 0.06), "ice", tilt=(-0.22, -sx * 0.62), verts=4))
        p.append(m.crystal(0.18, 0.82, (sx * 0.84, 1.66, 0.16), "iceLight", tilt=(-0.38, -sx * 0.92), verts=4))
        p.append(m.ico(0.10, (sx * 0.14, 2.22, -0.40), "iceGlow", squash=(1.4, 0.55, 0.55)))
    for k in range(5):
        ang = (k - 2) * 0.42
        p.append(
            m.crystal(
                0.12,
                0.96 - abs(k - 2) * 0.16,
                (math.sin(ang) * 0.24, 2.52, -0.02 + abs(k - 2) * 0.04),
                "iceGlow" if k == 2 else "iceLight",
                tilt=(-0.12, -ang * 0.65),
                verts=4,
            )
        )
    return p


def rime_matriarch_arm_r():
    """A3 Braco Direito: ombro em (0,0,0) + Cetro de Cristal Crio Boreal apontado para frente-baixo."""
    m = Rb("rime_matriarch")
    return [
        m.ball(0.28, (0.0, 0.0, 0.0), "ironDark", seg=6, rings=4),
        m.cyl(0.15, 0.56, (0.02, -0.52, -0.10), "ironDark", verts=6, r2=0.12),
        m.crystal(0.14, 0.42, (0.06, -0.24, -0.06), "ice", tilt=(-0.25, -0.45), verts=4),
        # Cetro Crio estendido para frente (-Z) e baixo (-Y)
        m.cyl_axis_y(0.08, 1.12, (0.04, -0.62, -0.56), "ironDark", verts=6, r2=0.09, tilt=-0.42),
        m.ico(0.22, (0.04, -0.82, -0.96), "iceGlow", squash=(0.95, 0.95, 1.15)),
        m.crystal(0.15, 0.54, (0.04, -0.86, -1.02), "iceGlow", tilt=(math.pi / 2 + 0.42, 0.0), verts=5),
        m.crystal(0.10, 0.38, (0.20, -0.76, -0.92), "iceLight", tilt=(1.15, -0.48), verts=4),
        m.crystal(0.10, 0.38, (-0.12, -0.76, -0.92), "ice", tilt=(1.15, 0.48), verts=4),
    ]


def rime_matriarch_arm_l():
    """A3 Braco Esquerdo: ombro em (0,0,0) + garras de gelo e escudo cristalino."""
    m = Rb("rime_matriarch")
    return [
        m.ball(0.28, (0.0, 0.0, 0.0), "ironDark", seg=6, rings=4),
        m.cyl(0.15, 0.58, (-0.02, -0.54, -0.10), "ironDark", verts=6, r2=0.12),
        m.crystal(0.18, 0.56, (-0.16, -0.48, -0.22), "ice", tilt=(0.35, 0.42), verts=4),
        m.crystal(0.13, 0.48, (-0.04, -0.64, -0.26), "iceGlow", tilt=(1.38, 0.0), verts=4),
        m.crystal(0.10, 0.38, (-0.16, -0.66, -0.24), "iceLight", tilt=(1.32, 0.28), verts=4),
    ]


def rime_matriarch_leg(sx: int):
    """A3 Perna: pinaculo de cristal glacial flutuante descendo do quadril (0,0,0)."""
    m = Rb("rime_matriarch")
    return [
        m.ball(0.30, (0.0, 0.0, 0.0), "stoneDark", seg=6, rings=4),
        m.cyl(0.32, 0.72, (0.0, -0.68, 0.0), "stoneDark", verts=6, r2=0.16),
        m.crystal(0.22, 0.68, (sx * 0.14, -0.72, -0.10), "ice", tilt=(-0.18, -sx * 0.24), verts=4),
        m.crystal(0.18, 0.58, (-sx * 0.10, -0.76, 0.12), "iceLight", tilt=(0.16, sx * 0.20), verts=4),
        m.crystal(0.16, 0.42, (0.0, -0.52, -0.18), "iceGlow", tilt=(math.pi, 0.0), verts=5),
    ]


def powder_baron_torso():
    """A4 Torso: casaco de cerco, couraca com bandoleiras, morteiros de ombro e tricornio."""
    pb = Rb("powder_baron")
    p = [
        pb.cyl(0.64, 0.42, (0.0, 0.84, 0.0), "roof", verts=8, r2=0.52),
        pb.ico(0.64, (0.0, 1.44, 0.0), "ironDark", squash=(1.12, 1.06, 0.82)),
        pb.ico(0.26, (0.0, 1.46, -0.46), "goldBright", squash=(1.0, 1.0, 0.55)),
        pb.ball(0.76, (0.0, 2.12, -0.06), "ironDark", seg=8, rings=5),
        pb.cyl(0.78, 0.14, (0.0, 2.34, -0.04), "ironDark", verts=6, r2=0.72),
        pb.cyl(0.48, 0.36, (0.0, 2.44, -0.02), "gold", verts=6, r2=0.38),
        pb.crystal(0.16, 0.68, (0.28, 2.66, 0.12), "roof", tilt=(-0.68, -0.35), verts=4),
    ]
    for sx in (-1, 1):
        p.append(pb.box((0.14, 0.72, 0.16), (sx * 0.26, 1.44, -0.42), "bronze", rot=(0.0, 0.0, sx * 0.42)))
        p.append(pb.ball(0.62, (sx * 0.76, 1.72, 0.0), "bronze", seg=8, rings=5))
        p.append(pb.cyl_axis_y(0.24, 1.15, (sx * 0.78, 2.02, -0.22), "ironDark", verts=10, r2=0.28, tilt=0.45))
        p.append(pb.cyl_axis_y(0.29, 0.18, (sx * 0.78, 2.24, -0.68), "gold", verts=10, r2=0.29, tilt=0.45))
        p.append(pb.ico(0.14, (sx * 0.78, 2.16, 0.34), "danger"))
        p.append(pb.ico(0.10, (sx * 0.14, 2.12, -0.40), "amberBright", squash=(1.35, 0.55, 0.55)))
    return p


def powder_baron_arm_r():
    """A4 Braco Direito: ombro em (0,0,0) + Bombarda de Latao de pulso apontada para frente-baixo."""
    pb = Rb("powder_baron")
    return [
        pb.ball(0.34, (0.0, 0.0, 0.0), "bronze", seg=8, rings=4),
        pb.cyl(0.19, 0.52, (0.02, -0.48, -0.08), "ironDark", verts=8, r2=0.21),
        pb.ico(0.24, (0.04, -0.56, -0.24), "bronze"),
        # Cano da Bombarda de Latao estendido para frente (-Z) e levemente abaixo (-Y)
        pb.cyl_axis_y(0.22, 0.88, (0.04, -0.66, -0.58), "ironDark", verts=10, r2=0.26, tilt=-0.28),
        pb.cyl_axis_y(0.27, 0.16, (0.04, -0.76, -0.96), "gold", verts=10, r2=0.28, tilt=-0.28),
        pb.box((0.12, 0.18, 0.42), (0.04, -0.48, -0.56), "bronze", rot=(0.28, 0.0, 0.0)),
        pb.ico(0.14, (0.04, -0.52, -0.18), "danger"),
    ]


def powder_baron_arm_l():
    """A4 Braco Esquerdo: ombro em (0,0,0) + manopla de morteiro/polvora."""
    pb = Rb("powder_baron")
    return [
        pb.ball(0.34, (0.0, 0.0, 0.0), "bronze", seg=8, rings=4),
        pb.cyl(0.19, 0.54, (-0.02, -0.50, -0.08), "ironDark", verts=8, r2=0.21),
        pb.ico(0.26, (-0.04, -0.62, -0.28), "bronze"),
        pb.cyl_axis_y(0.18, 0.52, (-0.06, -0.68, -0.48), "ironDark", verts=8, r2=0.20, tilt=-0.32),
        pb.cyl_axis_y(0.21, 0.12, (-0.06, -0.74, -0.70), "gold", verts=8, r2=0.21, tilt=-0.32),
        pb.ico(0.12, (-0.18, -0.54, -0.34), "amberBright"),
    ]


def powder_baron_leg(sx: int):
    """A4 Perna: bota blindada de cerco com cano de latao a partir do quadril (0,0,0)."""
    pb = Rb("powder_baron")
    return [
        pb.ball(0.32, (0.0, 0.0, 0.0), "roof", seg=6, rings=4),
        pb.cyl(0.26, 0.76, (0.0, -0.76, 0.0), "ironDark", verts=8, r2=0.22),
        pb.cyl(0.30, 0.16, (0.0, -0.28, 0.0), "bronze", verts=8, r2=0.30),
        pb.box((0.14, 0.42, 0.34), (sx * 0.18, -0.26, 0.02), "roof", rot=(0.0, 0.0, -sx * 0.18)),
        pb.box((0.36, 0.20, 0.52), (0.0, -0.76, -0.08), "ironDark"),
        pb.ico(0.10, (0.0, -0.68, -0.32), "gold"),
    ]


def rift_titan_torso():
    """A5 Torso: cinturao soberano, Couraca com Coracao da Fenda, manto alto, ombreiras de draco e elmo chifrudo."""
    t = Rb("rift_titan")
    p = [
        # Cinturao soberano e escarcelas altas (base do torso em y ~ 0.88)
        t.cyl(0.45, 0.28, (0.0, 1.12, -0.02), "ironDark", verts=8, r2=0.42),
        t.cyl(0.44, 0.11, (0.0, 1.28, -0.02), "gold", verts=8, r2=0.44),
        t.crystal(0.13, 0.22, (0.0, 1.18, -0.44), "tealSwarm", verts=4, r2=0.13, spin=math.pi / 4),
        t.crystal(0.07, 0.14, (0.0, 1.22, -0.47), "eyeNeon", verts=4, r2=0.07, spin=math.pi / 4),
        # Couraca soberana e Coracao da Fenda pulsante (-Z)
        t.cyl(0.42, 0.38, (0.0, 1.36, -0.04), "ironDark", verts=8, r2=0.52),
        t.ico(0.60, (0.0, 1.84, -0.08), "iron", squash=(1.22, 0.96, 0.58)),
        t.ico(0.38, (0.0, 1.82, -0.26), "ink", squash=(0.90, 0.92, 0.45)),
        t.ico(0.26, (0.0, 1.84, -0.39), "tealSwarm", squash=(0.82, 1.08, 0.40)),
        t.ico(0.16, (0.0, 1.84, -0.44), "eyeNeon", squash=(0.68, 1.02, 0.38)),
        t.cyl(0.38, 0.22, (0.0, 2.08, -0.02), "ironDark", verts=8, r2=0.44),
        # Manto soberano pregueado nas costas (terminando na cintura para preservar pivo do torso)
        t.box((1.22, 0.22, 0.28), (0.0, 2.08, 0.26), "tealBruteDark", rot=(0.20, 0.0, 0.0)),
    ]
    for sx in (-1, 1):
        p.append(t.box((0.22, 0.38, 0.34), (sx * 0.46, 1.10, -0.02), "iron", rot=(0.0, sx * 0.24, 0.0)))
        for i in range(3):
            rib_col = "goldBright" if i == 1 else "tealSwarm"
            p.append(
                t.box(
                    (0.26, 0.075, 0.11),
                    (sx * 0.28, 1.66 + i * 0.14, -0.37),
                    rib_col,
                    rot=(0.0, 0.0, sx * 0.26),
                )
            )
        # Ombreiras de draco da Fenda
        p.append(t.ball(0.58, (sx * 0.68, 2.04, -0.02), "ironDark", seg=8, rings=5, squash=(1.15, 0.95, 1.05)))
        p.append(t.box((0.46, 0.18, 0.56), (sx * 0.80, 2.14, 0.02), "iron", rot=(0.08, sx * 0.34, 0.0)))
        p.append(t.box((0.42, 0.075, 0.44), (sx * 0.78, 2.23, -0.02), "goldBright", rot=(0.08, sx * 0.32, 0.0)))
        p.append(t.crystal(0.14, 0.66, (sx * 0.84, 2.10, 0.04), "tealSwarm", tilt=(-0.22, -sx * 0.62), verts=5))
        p.append(t.crystal(0.10, 0.40, (sx * 0.82, 2.00, -0.22), "steel", tilt=(0.68, -sx * 0.46), verts=4))

    for idx in (-2, -1, 0, 1, 2):
        u = idx / 2.0
        col = "stoneDark" if idx % 2 == 0 else "tealBruteDark"
        p.append(
            t.box(
                (0.28, 1.06, 0.08),
                (u * 0.52, 1.52, 0.44 - (1.0 - abs(u)) * 0.04),
                col,
                rot=(0.18, u * 0.18, u * 0.05),
            )
        )

    # Elmo soberano chifrudo e halo arcano
    p.append(t.ico(0.36, (0.0, 2.40, -0.05), "ironDark", squash=(0.90, 1.08, 0.98)))
    for sx in (-1, 1):
        p.append(t.box((0.12, 0.28, 0.22), (sx * 0.18, 2.32, -0.24), "iron", rot=(0.08, 0.0, -sx * 0.14)))
        p.append(t.box((0.17, 0.055, 0.08), (sx * 0.11, 2.40, -0.37), "eyeNeon", rot=(0.0, 0.0, -sx * 0.28)))
        p.append(
            t.crystal(0.12, 0.36, (sx * 0.24, 2.46, -0.04), "ironDark", tilt=(0.10, -sx * 1.05), verts=5, r2=0.09)
        )
        p.append(t.crystal(0.09, 0.38, (sx * 0.54, 2.60, -0.08), "teal", tilt=(0.18, -sx * 0.28), verts=5, r2=0.055))
        p.append(t.crystal(0.055, 0.34, (sx * 0.64, 2.95, -0.14), "eyeNeon", tilt=(0.24, sx * 0.22), verts=4, r2=0.0))
    p.append(t.crystal(0.09, 0.42, (0.0, 2.58, -0.10), "goldBright", tilt=(-0.24, 0.0), verts=4))
    for k in range(5):
        ang = -0.8 + 0.4 * k
        pos_h = (0.62 * math.sin(ang), 2.74 + (1 - abs(k - 2) * 0.3) * 0.22, 0.26)
        p.append(
            t.crystal(
                0.08,
                0.38,
                pos_h,
                "eyeNeon" if k % 2 == 0 else "tealSwarm",
                tilt=(-0.15, -ang * 0.35),
                verts=4,
            )
        )
    return p


def rift_titan_arm_r():
    """A5 Braco Direito: ombro em (0,0,0) + Lamina-Obelisco da Fenda em guarda (~35 graus frente-baixo, nunca no chao)."""
    t = Rb("rift_titan")
    # Angulo de guarda ~35 graus (0.61 rad) inclinando de tras-cima para frente (-Z) e baixo (-Y)
    pitch = 0.62
    return [
        # Ombro e braco blindado descendo ate a empunhadura em (0.06, -0.46, -0.32)
        t.ball(0.32, (0.0, 0.0, 0.0), "ironDark", seg=6, rings=4),
        t.cyl(0.17, 0.38, (0.02, -0.34, -0.06), "ironDark", verts=6, r2=0.19),
        t.cyl_axis_y(0.16, 0.38, (0.04, -0.40, -0.20), "iron", verts=6, r2=0.14, tilt=-0.42),
        t.ico(0.16, (0.06, -0.46, -0.34), "gold"),
        # Pomo coroado e empunhadura da Lamina-Obelisco
        t.crystal(0.085, 0.20, (0.06, -0.24, -0.06), "eyeNeon", tilt=(-0.95, 0.0), verts=4),
        t.cyl_axis_y(0.075, 0.48, (0.06, -0.42, -0.28), "ink", verts=6, r2=0.085, tilt=-pitch),
        # Guarda-cruz Bastiao-Fenda em (0.06, -0.56, -0.48)
        t.box((0.36, 0.14, 0.16), (0.06, -0.56, -0.48), "goldBright", rot=(pitch, 0.0, 0.0)),
        t.ico(0.11, (0.06, -0.56, -0.48), "eyeNeon", squash=(0.95, 0.95, 1.35)),
        t.crystal(0.10, 0.36, (0.20, -0.56, -0.48), "tealSwarm", tilt=(pitch, -1.15), verts=4),
        t.crystal(0.10, 0.36, (-0.08, -0.56, -0.48), "tealSwarm", tilt=(pitch, 1.15), verts=4),
        # Lamina-Obelisco colossal projetada para frente (-Z) e baixo (-Y) a ~35 graus
        t.box((0.22, 0.09, 1.16), (0.06, -0.88, -0.94), "ironDark", rot=(pitch, 0.0, 0.0)),
        t.box((0.12, 0.11, 1.08), (0.06, -0.87, -0.92), "steel", rot=(pitch, 0.0, 0.0)),
        t.box((0.065, 0.125, 1.02), (0.06, -0.86, -0.90), "eyeNeon", rot=(pitch, 0.0, 0.0)),
        t.crystal(0.09, 0.30, (0.19, -0.74, -0.74), "tealSwarm", tilt=(pitch + 0.35, -0.85), verts=4),
        t.crystal(0.09, 0.30, (-0.07, -0.74, -0.74), "tealSwarm", tilt=(pitch + 0.35, 0.85), verts=4),
        # Ponta de obelisco na extremidade frontal
        t.crystal(0.15, 0.42, (0.06, -1.16, -1.34), "steel", tilt=(math.pi / 2 + pitch, 0.0), verts=4),
    ]


def rift_titan_arm_l():
    """A5 Braco Esquerdo: ombro em (0,0,0) + garra do vazio e katar de pulso turquesa."""
    t = Rb("rift_titan")
    return [
        t.ball(0.30, (0.0, 0.0, 0.0), "ironDark", seg=6, rings=4),
        t.cyl(0.16, 0.46, (-0.02, -0.44, -0.04), "ironDark", verts=6, r2=0.19),
        t.cyl_axis_y(0.17, 0.46, (-0.05, -0.62, -0.18), "iron", verts=6, r2=0.14, tilt=-0.78),
        t.ico(0.16, (-0.06, -0.78, -0.32), "ironDark"),
        t.crystal(0.11, 0.46, (-0.12, -0.72, -0.30), "tealSwarm", tilt=(2.15, 0.16), verts=4),
        t.crystal(0.08, 0.36, (-0.02, -0.76, -0.36), "eyeNeon", tilt=(2.05, -0.08), verts=4),
    ]


def rift_titan_leg(sx: int):
    """A5 Perna: coxote soberano, joelheira de cristal turquesa e greva/sabaton chifrudo desde (0,0,0)."""
    t = Rb("rift_titan")
    return [
        t.ball(0.30, (0.0, 0.0, 0.0), "stoneDark", seg=6, rings=4),
        t.cyl(0.24, 0.44, (0.0, -0.42, 0.0), "stoneDark", verts=6, r2=0.26),
        t.crystal(0.15, 0.36, (sx * 0.03, -0.44, -0.16), "tealSwarm", tilt=(0.52, -sx * 0.08), verts=4),
        t.cyl(0.20, 0.52, (0.0, -0.86, 0.0), "ironDark", verts=6, r2=0.23),
        t.box((0.13, 0.44, 0.10), (0.0, -0.64, -0.18), "iron", rot=(0.06, 0.0, 0.0)),
        t.box((0.28, 0.20, 0.40), (0.0, -0.86, -0.06), "ironDark"),
        t.crystal(0.13, 0.30, (0.0, -0.88, -0.22), "iron", tilt=(1.42, 0.0), verts=4),
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
        out.append(
            {
                "id": f"boss.{boss_id}.01",
                "name": f"BOSS_{boss_id}",
                "glb": f"boss_{boss_id}.glb",
                "tipo": "prop_estatico",
                "limite": LIMITE,
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
                    "limite": LIMITE_PART,
                    "tags": ["muralha", "boss", boss_id, part],
                    "seed": L.SEED_BASE + 9000 + len(out) * 37 + part_idx,
                    "build": kit[part],
                }
            )
    return out


L.run_group("bosses", specs(), "5 bosses esculpidos + 25 sub-malhas articuladas da campanha (art/scripts/make_bosses.py)")
