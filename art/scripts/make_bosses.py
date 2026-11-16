"""Gera os 5 Bosses esculpidos da campanha (BOSS_iron_ram_colossus, BOSS_slag_juggernaut,
BOSS_rime_matriarch, BOSS_powder_baron, BOSS_rift_titan) e suas 25 sub-malhas articuladas.

Silhuetas AA com curvas suaves (weighted normals), rebitagem/laminas/pistoes/runas e chanfros
precisos para ocupacao multi-lane na arena.
Mapeamento Roblox -> Blender (frente -Z no Studio = -Y no Blender): (x, y, z) -> (-x, z, y).

Uso headless:
  FORGE_SKIP_RENDER=1 blender -b --factory-startup --python-exit-code 1 --python art/scripts/make_bosses.py
Saidas: art/export/boss_<bossId>.glb, art/export/boss_<bossId>_<part>.glb,
        art/forge/lote_bosses_import.yaml (gerado), art/renders/bosses/*.png (ignorado no git)
"""

from __future__ import annotations

import math
import os
import sys

from mathutils import Euler, Matrix, Vector

sys.dont_write_bytecode = True  # sem __pycache__ em art/scripts
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lowpoly_lib as L  # noqa: E402

LIMITE = 17900
LIMITE_TORSO = 5800
LIMITE_ARM = 3700
LIMITE_LEG = 2500

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

    def ball(self, diam, pos, color, seg=24, rings=16, squash=(1.0, 1.0, 1.0)):
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

    def cyl(self, r, h, base, color, verts=24, r2=None, rot_z=0.0, bevel=0.0, bevel_segs=1):
        return L.cyl(
            r * self.k,
            h * self.k,
            self.p(*base),
            color,
            verts=verts,
            r2=None if r2 is None else r2 * self.k,
            bevel=bevel * self.k,
            rot_z=rot_z,
            bevel_segs=bevel_segs,
        )

    def cyl_axis_y(self, r, length, center, color, verts=24, r2=None, tilt=0.0, bevel=0.0, bevel_segs=1):
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
            bevel_segs=bevel_segs,
        )

    def cyl_axis_x(self, r, length, center, color, verts=20, r2=None, tilt=0.0, bevel=0.0, bevel_segs=1):
        return L.cyl_axis(
            r * self.k,
            length * self.k,
            self.p(*center),
            color,
            axis="x",
            verts=verts,
            r2=None if r2 is None else r2 * self.k,
            tilt=tilt,
            bevel=bevel * self.k,
            bevel_segs=bevel_segs,
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

    def box(self, size, center, color, rot=(0.0, 0.0, 0.0), bevel=0.025, bevel_segs=1):
        safe_b = min(bevel, 0.35 * min(size)) if bevel > 0.0 else 0.0
        return L.box(
            (size[0] * self.k, size[2] * self.k, size[1] * self.k),
            self.p(*center),
            color,
            bevel=safe_b * self.k,
            rot=rot,
            bevel_segs=bevel_segs,
        )

    def torus(
        self,
        r_major,
        r_minor,
        pos,
        color,
        major_seg=22,
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

    def capsule_seg(self, p0, p1, r0, r1, color, verts=20, cap_ends=False):
        return L.capsule_seg(
            self.p(*p0),
            self.p(*p1),
            r0 * self.k,
            r1 * self.k,
            color,
            verts=verts,
            cap_ends=cap_ends,
        )


# ==============================================================================
# HELPERS ESCULTURAIS COMPARTILHADOS (AA HARD-SURFACE / ORGANICO)
# ==============================================================================
def _transform_parts(parts, b: Rb, offset_rb=(0.0, 0.0, 0.0), rot_blender=(0.0, 0.0, 0.0)):
    """Posiciona e rotaciona um sub-conjunto de pecas ao redor de (0,0,0) -> offset_rb."""
    m_rot = Euler(rot_blender, "XYZ").to_matrix().to_4x4()
    delta = Vector(b.p(*offset_rb))
    m_trans = Matrix.Translation(delta) @ m_rot
    for o in parts:
        o.matrix_world = m_trans @ o.matrix_world
    return parts


def _curved_siege_horn(
    b: Rb,
    p0: tuple[float, float, float],
    p1: tuple[float, float, float],
    p2: tuple[float, float, float],
    p3: tuple[float, float, float],
    r_base: float,
    col_base: str = "steel",
    col_tip: str = "hornIvory",
    verts: int = 20,
    three_seg: bool = True,
    collar_color: str | None = None,
):
    """Chifre de cerco curvo multi-segmento com colar opcional na base."""
    out = []
    if collar_color:
        v = Vector(b.p(*p1)) - Vector(b.p(*p0))
        if v.length > 1e-5:
            q = v.normalized().to_track_quat("Z", "Y").to_euler("XYZ")
            out.append(
                b.torus(
                    r_base * 1.12,
                    r_base * 0.22,
                    p0,
                    collar_color,
                    major_seg=16,
                    minor_seg=6,
                    rot=tuple(q),
                )
            )
    if not three_seg:
        out += [
            b.capsule_seg(p0, p2, r_base, r_base * 0.45, col_base, verts=verts),
            b.capsule_seg(p2, p3, r_base * 0.43, 0.012, col_tip, verts=verts),
        ]
        return out
    out += [
        b.capsule_seg(p0, p1, r_base, r_base * 0.72, col_base, verts=verts),
        b.capsule_seg(p1, p2, r_base * 0.70, r_base * 0.38, col_base, verts=verts),
        b.capsule_seg(p2, p3, r_base * 0.36, 0.012, col_tip, verts=verts),
    ]
    return out


def _rivet_ring(
    b: Rb,
    center: tuple[float, float, float],
    radius: float,
    count: int,
    stud_size: float,
    color: str,
    plane: str = "xz",
    start: float = 0.0,
    span: float = 2.0 * math.pi,
    bevel: float = 0.0,
):
    """Anel ou arco de rebites/tachas (bevel=0 -> 12 tris/rebite para alta densidade)."""
    cx, cy, cz = center
    out = []
    for k in range(count):
        frac = k / count if abs(span - 2.0 * math.pi) < 1e-4 else (k / max(1, count - 1))
        a = start + span * frac
        if plane == "xz":
            pos = (cx + radius * math.cos(a), cy, cz + radius * math.sin(a))
            rot = (0.0, 0.0, -a)
        elif plane == "xy":
            pos = (cx + radius * math.cos(a), cy + radius * math.sin(a), cz)
            rot = (0.0, a, 0.0)
        else:  # "yz"
            pos = (cx, cy + radius * math.sin(a), cz + radius * math.cos(a))
            rot = (a, 0.0, 0.0)
        out.append(b.box((stud_size, stud_size, stud_size), pos, color, rot=rot, bevel=bevel))
    return out


def _armor_lames(
    b: Rb,
    count: int,
    base_pos: tuple[float, float, float],
    step_pos: tuple[float, float, float],
    base_size: tuple[float, float, float],
    step_size: tuple[float, float, float],
    color: str,
    trim_color: str | None = None,
    rot: tuple[float, float, float] = (0.0, 0.0, 0.0),
    bevel: float = 0.018,
):
    """Pilha articulada de laminas chanfradas (ombreiras, escarcelas, grevas)."""
    out = []
    for i in range(count):
        pos = (
            base_pos[0] + step_pos[0] * i,
            base_pos[1] + step_pos[1] * i,
            base_pos[2] + step_pos[2] * i,
        )
        sz = (
            max(0.04, base_size[0] + step_size[0] * i),
            max(0.04, base_size[1] + step_size[1] * i),
            max(0.04, base_size[2] + step_size[2] * i),
        )
        out.append(b.box(sz, pos, color, rot=rot, bevel=bevel))
        if trim_color:
            out.append(
                b.box(
                    (sz[0] * 0.92, sz[1] * 0.42, sz[2] * 1.06),
                    (pos[0], pos[1] - sz[1] * 0.25, pos[2] - 0.008),
                    trim_color,
                    rot=rot,
                    bevel=0.0,
                )
            )
    return out


def _piston(
    b: Rb,
    p0: tuple[float, float, float],
    p1: tuple[float, float, float],
    r_cyl: float,
    r_rod: float,
    col_cyl: str,
    col_rod: str,
    col_ring: str,
    verts: int = 16,
):
    """Pistao hidraulico telescopico com camisa, haste e colar torus."""
    mid = (
        p0[0] + (p1[0] - p0[0]) * 0.56,
        p0[1] + (p1[1] - p0[1]) * 0.56,
        p0[2] + (p1[2] - p0[2]) * 0.56,
    )
    v = Vector(b.p(*p1)) - Vector(b.p(*p0))
    q = v.normalized().to_track_quat("Z", "Y").to_euler("XYZ") if v.length > 1e-5 else (0.0, 0.0, 0.0)
    return [
        b.capsule_seg(p0, mid, r_cyl, r_cyl, col_cyl, verts=verts),
        b.capsule_seg(p0, p1, r_rod, r_rod, col_rod, verts=max(12, verts - 4)),
        b.torus(r_cyl * 1.15, r_cyl * 0.26, mid, col_ring, major_seg=14, minor_seg=6, rot=tuple(q)),
    ]


def _fluted_gear(
    b: Rb,
    center: tuple[float, float, float],
    r: float,
    thick: float,
    teeth: int,
    color: str,
    hub_color: str | None = None,
    plane: str = "yz",
):
    """Engrenagem mecanica detalhada em coordenadas Rb."""
    cx, cy, cz = center
    out = []
    if plane == "xz":
        out.append(b.cyl(r, thick, (cx, cy - thick * 0.5, cz), color, verts=20))
    elif plane == "xy":
        out.append(b.cyl_axis_y(r, thick, center, color, verts=20))
    else:
        out.append(b.cyl_axis_x(r, thick, center, color, verts=20))
    tw, th = r * 0.34, r * 0.30
    for k in range(teeth):
        a = 2.0 * math.pi * k / teeth
        if plane == "xz":
            pos = (cx + (r + th * 0.25) * math.cos(a), cy, cz + (r + th * 0.25) * math.sin(a))
            out.append(b.box((th, thick * 0.9, tw), pos, color, rot=(0.0, 0.0, -a), bevel=0.0))
        elif plane == "xy":
            pos = (cx + (r + th * 0.25) * math.cos(a), cy + (r + th * 0.25) * math.sin(a), cz)
            out.append(b.box((th, tw, thick * 0.9), pos, color, rot=(0.0, a, 0.0), bevel=0.0))
        else:
            pos = (cx, cy + (r + th * 0.25) * math.sin(a), cz + (r + th * 0.25) * math.cos(a))
            out.append(b.box((thick * 0.9, tw, th), pos, color, rot=(a, 0.0, 0.0), bevel=0.0))
    if hub_color:
        if plane == "xz":
            out.append(b.cyl(r * 0.40, thick * 1.4, (cx, cy - thick * 0.7, cz), hub_color, verts=14))
        elif plane == "xy":
            out.append(b.cyl_axis_y(r * 0.40, thick * 1.4, center, hub_color, verts=14))
        else:
            out.append(b.cyl_axis_x(r * 0.40, thick * 1.4, center, hub_color, verts=14))
    return out


# ==============================================================================
# ACT 1 — IRON RAM COLOSSUS
# ==============================================================================
def iron_ram_colossus_torso():
    """A1 Torso: fornalha blindada, rebites, escarcelas em laminas, espinha dorsal e elmo com chifres."""
    b = Rb("iron_ram_colossus")
    p = [
    # Cintura e cinturao com fivela e anel torus
        b.cyl(0.62, 0.36, (0.0, 0.82, 0.0), "ironDark", verts=24, r2=0.58, bevel=0.015),
        b.torus(0.60, 0.056, (0.0, 0.96, 0.0), "iron", major_seg=20, minor_seg=8),
        b.box((0.36, 0.22, 0.16), (0.0, 0.96, -0.60), "steel", bevel=0.025),
        b.box((0.20, 0.12, 0.08), (0.0, 0.96, -0.66), "amberBright", bevel=0.015),
        # Torso principal e fornalha frontal multi-camadas
        b.ico(0.76, (0.0, 1.48, 0.02), "iron", squash=(1.18, 1.05, 0.86), subdiv=2),
        b.ico(0.42, (0.0, 1.46, -0.44), "ember", squash=(0.95, 1.05, 0.55), subdiv=2),
        b.ico(0.28, (0.0, 1.46, -0.52), "amberBright", squash=(0.85, 0.90, 0.45), subdiv=2),
        b.torus(
            0.38,
            0.058,
            (0.0, 1.46, -0.58),
            "ironDark",
            major_seg=20,
            minor_seg=8,
            rot=(math.pi / 2, 0.0, 0.0),
        ),
        b.box((0.72, 0.11, 0.14), (0.0, 1.46, -0.62), "ironDark", bevel=0.025),
        b.box((0.64, 0.09, 0.12), (0.0, 1.28, -0.60), "ironDark", bevel=0.02),
        b.box((0.64, 0.09, 0.12), (0.0, 1.64, -0.60), "ironDark", bevel=0.02),
        # Gola blindada e elmo de cerco com viseira chanfrada e crista rebitada
        b.torus(0.42, 0.056, (0.0, 1.88, -0.02), "ironDark", major_seg=18, minor_seg=6),
        b.ball(0.62, (0.0, 2.18, -0.12), "ironDark", seg=18, rings=12, squash=(0.98, 0.94, 1.02)),
        b.box((0.52, 0.12, 0.24), (0.0, 2.28, -0.34), "iron", bevel=0.025),
        b.box((0.48, 0.14, 0.24), (0.0, 2.16, -0.42), "amberBright", bevel=0.02),
        b.box((0.42, 0.14, 0.22), (0.0, 1.98, -0.36), "steel", bevel=0.025),
        b.box((0.18, 0.36, 0.38), (0.0, 2.38, -0.10), "iron", bevel=0.03),
    ]
    # Rebites no anel da fornalha e no cinturao
    p += _rivet_ring(b, (0.0, 1.46, -0.62), 0.38, 8, 0.055, "steel", plane="xy")
    p += _rivet_ring(b, (0.0, 0.96, 0.0), 0.62, 10, 0.055, "steel", plane="xz")
    # Rebites na crista do elmo
    for c_i in range(4):
        p.append(b.box((0.08, 0.08, 0.08), (0.0, 2.56 - c_i * 0.04, -0.24 + c_i * 0.11), "steel", bevel=0.0))

    for sx in (-1, 1):
        # Escarcelas laterais em 2 laminas articuladas
        p += _armor_lames(
            b,
            2,
            (sx * 0.56, 1.00, -0.04),
            (sx * 0.02, -0.14, 0.0),
            (0.22, 0.16, 0.44),
            (-0.02, 0.0, -0.04),
            "iron",
            rot=(0.0, sx * 0.14, sx * 0.22),
            bevel=0.018,
        )
        # Barras verticais, placas peitorais e 3 costelas blindadas
        p.append(b.box((0.11, 0.62, 0.14), (sx * 0.16, 1.46, -0.62), "ironDark", bevel=0.025))
        p.append(b.box((0.28, 0.54, 0.18), (sx * 0.48, 1.48, -0.44), "iron", rot=(0.0, sx * 0.28, 0.0), bevel=0.03))
        for r_i in range(3):
            p.append(
                b.box(
                    (0.30, 0.09, 0.14),
                    (sx * 0.44, 1.24 + r_i * 0.20, -0.48),
                    "steel",
                    rot=(0.0, sx * 0.24, sx * 0.18),
                    bevel=0.02,
                )
            )
        p.append(b.box((0.14, 0.14, 0.12), (sx * 0.32, 1.66, -0.58), "amberBright", bevel=0.02))
        p.append(b.box((0.14, 0.14, 0.12), (sx * 0.32, 1.26, -0.58), "amberBright", bevel=0.02))
        # Ombreiras em laminas sobrepostas + chifres curvos 18-seg
        p.append(b.ball(0.76, (sx * 0.82, 1.82, 0.0), "iron", seg=16, rings=10, squash=(1.06, 0.88, 1.02)))
        p += _armor_lames(
            b,
            2,
            (sx * 0.78, 1.98, -0.02),
            (sx * 0.10, -0.12, 0.0),
            (0.46, 0.14, 0.54),
            (-0.04, 0.0, -0.04),
            "ironDark",
            rot=(0.0, 0.0, -sx * 0.26),
            bevel=0.018,
        )
        p.append(b.torus(0.20, 0.036, (sx * 0.88, 2.04, 0.0), "steel", major_seg=14, minor_seg=6, rot=(0.25, 0.0, -sx * 0.45)))
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
            three_seg=True,
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
            three_seg=True,
        )
    # Vertebras dorsais da fornalha + chaminés escapamento
    for v_i in range(4):
        p.append(b.box((0.32, 0.18, 0.24), (0.0, 1.18 + v_i * 0.24, 0.56), "ironDark", bevel=0.025))
        p.append(b.box((0.24, 0.10, 0.18), (0.0, 1.20 + v_i * 0.24, 0.64), "steel", bevel=0.015))
        p.append(b.ico(0.09, (0.0, 1.18 + v_i * 0.24, 0.68), "ember", subdiv=1))
    return p


def iron_ram_colossus_arm_r():
    """A1 Braco Direito: ombro (0,0,0) + manopla-ariete pesada com pistoes, colar rebitado, garras e chifres."""
    b = Rb("iron_ram_colossus")
    p = [
        b.ball(0.38, (0.0, 0.0, 0.0), "ironDark", seg=20, rings=14),
        b.cyl(0.22, 0.52, (0.02, -0.50, -0.06), "ironDark", verts=22, r2=0.24),
        b.torus(0.24, 0.042, (0.02, -0.34, -0.06), "steel", major_seg=20, minor_seg=8),
        b.torus(0.23, 0.036, (0.02, -0.50, -0.10), "iron", major_seg=18, minor_seg=6),
        # Carcaca da manopla-ariete + cintas + placas de reforco
        b.box((0.50, 0.46, 0.80), (0.04, -0.68, -0.44), "iron", rot=(0.32, 0.0, 0.0), bevel=0.04),
        b.box((0.56, 0.20, 0.24), (0.04, -0.56, -0.28), "ironDark", rot=(0.32, 0.0, 0.0), bevel=0.03),
        b.box((0.56, 0.20, 0.24), (0.04, -0.66, -0.56), "ironDark", rot=(0.32, 0.0, 0.0), bevel=0.03),
        b.box((0.30, 0.14, 0.64), (0.04, -0.44, -0.42), "steel", rot=(0.32, 0.0, 0.0), bevel=0.025),
        b.torus(
            0.29,
            0.048,
            (0.04, -0.74, -0.72),
            "ironDark",
            major_seg=20,
            minor_seg=8,
            rot=(math.pi / 2 - 0.32, 0.0, 0.0),
        ),
        b.ico(0.22, (0.04, -0.72, -0.68), "ember", squash=(0.95, 0.85, 0.65), subdiv=2),
        # Ponta ariete escalonada com anel de impacto
        b.cyl_axis_y(0.24, 0.26, (0.04, -0.79, -0.82), "ironDark", verts=22, r2=0.20, tilt=-0.32, bevel=0.02),
        b.cyl_axis_y(0.20, 0.44, (0.04, -0.84, -0.94), "steel", verts=22, r2=0.07, tilt=-0.32, bevel=0.02),
        b.box((0.12, 0.12, 0.54), (0.26, -0.62, -0.46), "amberBright", rot=(0.32, 0.0, 0.0), bevel=0.02),
        b.box((0.12, 0.12, 0.54), (-0.18, -0.62, -0.46), "amberBright", rot=(0.32, 0.0, 0.0), bevel=0.02),
        b.capsule_seg((0.24, -0.58, -0.56), (0.34, -0.74, -0.96), 0.095, 0.015, "hornIvory", verts=18),
        b.capsule_seg((-0.16, -0.58, -0.56), (-0.26, -0.74, -0.96), 0.095, 0.015, "hornIvory", verts=18),
    ]
    # Ombreira em 2 laminas + pistoes telescopicos + rebites do colar frontal + laminas de punho
    p += _armor_lames(
        b,
        2,
        (0.06, -0.10, -0.04),
        (0.04, -0.11, 0.0),
        (0.38, 0.14, 0.38),
        (-0.04, 0.0, -0.04),
        "iron",
        trim_color="steel",
        rot=(0.0, 0.0, -0.22),
        bevel=0.02,
    )
    p += _piston(b, (0.20, -0.18, -0.08), (0.22, -0.54, -0.24), 0.055, 0.032, "iron", "steel", "ironDark")
    p += _piston(b, (-0.14, -0.20, -0.06), (-0.16, -0.56, -0.24), 0.050, 0.028, "iron", "steel", "ironDark")
    p += _rivet_ring(b, (0.04, -0.74, -0.74), 0.29, 8, 0.050, "steel", plane="xy")
    p += _rivet_ring(b, (0.02, -0.34, -0.06), 0.25, 8, 0.048, "ironDark", plane="xz")
    p += _armor_lames(
        b,
        2,
        (0.04, -0.45, -0.52),
        (0.0, -0.05, -0.12),
        (0.42, 0.08, 0.14),
        (-0.02, 0.0, 0.0),
        "steel",
        rot=(0.32, 0.0, 0.0),
        bevel=0.015,
    )
    return p


def iron_ram_colossus_arm_l():
    """A1 Braco Esquerdo: ombro (0,0,0) + escudo-torre rebitado + manopla-ariete e chifre."""
    b = Rb("iron_ram_colossus")
    p = [
        b.ball(0.36, (0.0, 0.0, 0.0), "ironDark", seg=22, rings=14),
        b.cyl(0.21, 0.54, (-0.02, -0.52, -0.06), "ironDark", verts=24, r2=0.23),
        b.torus(0.23, 0.038, (-0.02, -0.35, -0.06), "steel", major_seg=22, minor_seg=10),
        b.torus(0.22, 0.032, (-0.02, -0.50, -0.10), "iron", major_seg=18, minor_seg=6),
        b.box((0.46, 0.44, 0.72), (-0.04, -0.68, -0.38), "iron", rot=(0.26, 0.0, 0.0), bevel=0.04),
        b.box((0.52, 0.18, 0.22), (-0.04, -0.58, -0.26), "ironDark", rot=(0.26, 0.0, 0.0), bevel=0.03),
        b.box((0.52, 0.18, 0.22), (-0.04, -0.66, -0.50), "ironDark", rot=(0.26, 0.0, 0.0), bevel=0.03),
        # Escudo-torre multi-camadas no antebraco externo
        b.box((0.20, 0.64, 0.66), (-0.26, -0.62, -0.36), "ironDark", rot=(0.20, 0.14, 0.0), bevel=0.035),
        b.box((0.14, 0.54, 0.56), (-0.31, -0.62, -0.36), "steel", rot=(0.20, 0.14, 0.0), bevel=0.025),
        b.box((0.10, 0.44, 0.46), (-0.34, -0.62, -0.36), "amberBright", rot=(0.20, 0.14, 0.0), bevel=0.02),
        b.box((0.14, 0.10, 0.62), (-0.33, -0.62, -0.36), "ironDark", rot=(0.20, 0.14, 0.0), bevel=0.015),
        b.box((0.14, 0.58, 0.10), (-0.33, -0.62, -0.36), "ironDark", rot=(0.20, 0.14, 0.0), bevel=0.015),
        b.torus(0.20, 0.036, (-0.36, -0.62, -0.36), "iron", major_seg=22, minor_seg=10, rot=(0.20, 1.42, 0.0)),
        b.ico(0.11, (-0.38, -0.62, -0.36), "steel", subdiv=2),
        b.torus(
            0.25,
            0.044,
            (-0.04, -0.72, -0.64),
            "ironDark",
            major_seg=22,
            minor_seg=10,
            rot=(math.pi / 2 - 0.26, 0.0, 0.0),
        ),
        b.cyl_axis_y(0.19, 0.42, (-0.04, -0.78, -0.80), "steel", verts=22, r2=0.07, tilt=-0.26, bevel=0.02),
        b.capsule_seg((-0.24, -0.54, -0.50), (-0.34, -0.68, -0.86), 0.09, 0.015, "hornIvory", verts=20),
    ]
    p += _armor_lames(
        b,
        3,
        (-0.06, -0.10, -0.04),
        (-0.04, -0.10, 0.0),
        (0.36, 0.13, 0.36),
        (-0.04, 0.0, -0.04),
        "iron",
        trim_color="steel",
        rot=(0.0, 0.0, 0.22),
        bevel=0.02,
    )
    p += _piston(b, (0.14, -0.18, -0.06), (0.16, -0.54, -0.22), 0.052, 0.030, "iron", "steel", "ironDark")
    p += _rivet_ring(b, (-0.36, -0.62, -0.36), 0.23, 8, 0.045, "amberBright", plane="yz")
    p += _rivet_ring(b, (-0.04, -0.72, -0.66), 0.26, 8, 0.045, "steel", plane="xy")
    return p


def iron_ram_colossus_leg(sx: int):
    """A1 Perna: quadril (0,0,0) descendo ate greva de cerco, pistao na panturrilha e sabaton."""
    b = Rb("iron_ram_colossus")
    p = [
        b.ball(0.34, (0.0, 0.0, 0.0), "ironDark", seg=22, rings=14),
        b.cyl(0.28, 0.78, (0.0, -0.78, 0.0), "ironDark", verts=24, r2=0.24),
        b.torus(0.25, 0.042, (0.0, -0.38, -0.02), "iron", major_seg=22, minor_seg=10),
        b.torus(0.26, 0.040, (0.0, -0.64, -0.02), "steel", major_seg=22, minor_seg=8),
        b.box((0.38, 0.28, 0.26), (sx * 0.04, -0.38, -0.14), "iron", bevel=0.035),
        b.box((0.34, 0.46, 0.20), (0.0, -0.58, -0.14), "iron", bevel=0.035),
        b.box((0.18, 0.38, 0.14), (0.0, -0.58, -0.22), "steel", bevel=0.025),
        b.box((0.12, 0.34, 0.16), (sx * 0.18, -0.56, -0.06), "amberBright", bevel=0.02),
        b.capsule_seg((sx * 0.04, -0.36, -0.22), (sx * 0.06, -0.24, -0.52), 0.12, 0.015, "steel", verts=20),
        b.box((0.46, 0.24, 0.64), (0.0, -0.78, -0.10), "iron", bevel=0.035),
        b.box((0.40, 0.14, 0.34), (0.0, -0.72, -0.30), "steel", bevel=0.03),
        b.box((0.36, 0.12, 0.16), (0.0, -0.82, 0.22), "ironDark", bevel=0.02),
        b.crystal(0.11, 0.28, (0.0, -0.82, -0.40), "hornIvory", tilt=(1.48, 0.0), verts=8),
    ]
    p += _piston(b, (0.0, -0.26, 0.22), (0.0, -0.74, 0.20), 0.055, 0.032, "iron", "steel", "ironDark")
    p += _rivet_ring(b, (0.0, -0.64, -0.02), 0.27, 6, 0.045, "ironDark", plane="xz")
    return p


def iron_ram_colossus():
    """Act 1 Showcase: Colosso Ariete unificado (14,800-17,600 tris)."""
    b = Rb("iron_ram_colossus")
    p = iron_ram_colossus_torso()
    p += _transform_parts(iron_ram_colossus_leg(-1), b, (-0.44, 0.88, 0.0))
    p += _transform_parts(iron_ram_colossus_leg(1), b, (0.44, 0.88, 0.0))
    p += _transform_parts(iron_ram_colossus_arm_r(), b, (0.90, 1.70, -0.04), rot_blender=(0.18, 0.0, 0.0))
    p += _transform_parts(iron_ram_colossus_arm_l(), b, (-0.90, 1.70, -0.04), rot_blender=(0.12, 0.0, 0.0))
    return p


# ==============================================================================
# ACT 2 — SLAG JUGGERNAUT
# ==============================================================================
def slag_juggernaut_torso():
    """A2 Torso: caldeirao forjado, grade de magma com rebites, chamines duplas e elmo."""
    j = Rb("slag_juggernaut")
    p = [
        j.cyl(0.86, 0.96, (0.0, 0.72, 0.0), "ironDark", verts=28, r2=0.78),
        j.cyl(0.76, 0.18, (0.0, 0.62, 0.0), "stoneDark", verts=28, r2=0.84),
        j.torus(0.84, 0.075, (0.0, 1.58, 0.0), "stoneDark", major_seg=24, minor_seg=10),
        j.torus(0.82, 0.055, (0.0, 0.92, 0.0), "iron", major_seg=24, minor_seg=8),
        j.ico(0.56, (0.0, 1.24, -0.44), "danger", squash=(1.05, 0.92, 0.58), subdiv=2),
        j.ico(0.38, (0.0, 1.24, -0.58), "amberBright", squash=(0.95, 0.85, 0.45), subdiv=2),
        j.torus(0.46, 0.050, (0.0, 1.24, -0.62), "ironDark", major_seg=22, minor_seg=8, rot=(math.pi / 2, 0.0, 0.0)),
        j.box((0.72, 0.11, 0.14), (0.0, 1.24, -0.66), "ironDark", bevel=0.025),
        j.box((0.62, 0.08, 0.12), (0.0, 1.06, -0.64), "iron", bevel=0.015),
        # Cabeca de fornalha com viseira, mandibula e crista
        j.ico(0.46, (0.0, 1.98, -0.22), "ironDark", squash=(1.05, 0.86, 0.96), subdiv=2),
        j.box((0.48, 0.18, 0.28), (0.0, 1.84, -0.42), "stoneDark", bevel=0.03),
        j.box((0.42, 0.10, 0.16), (0.0, 2.12, -0.38), "iron", bevel=0.02),
        # Duto conector traseiro entre chamines
        j.capsule_seg((-0.44, 1.84, 0.46), (0.44, 1.84, 0.46), 0.10, 0.10, "iron", verts=16),
    ]
    p += _rivet_ring(j, (0.0, 1.58, 0.0), 0.86, 12, 0.06, "amber", plane="xz")
    p += _rivet_ring(j, (0.0, 0.92, 0.0), 0.84, 10, 0.055, "steel", plane="xz")
    p += _rivet_ring(j, (0.0, 1.24, -0.64), 0.46, 8, 0.048, "amberBright", plane="xy")
    for k in range(8):
        a = 2 * math.pi * k / 8
        p.append(j.box((0.10, 0.72, 0.10), (0.82 * math.cos(a), 1.24, 0.82 * math.sin(a)), "iron", rot=(0.0, -a, 0.0), bevel=0.015))
    for sx in (-1, 1):
        p.append(j.box((0.10, 0.68, 0.14), (sx * 0.18, 1.24, -0.66), "ironDark", bevel=0.025))
        p.append(j.ball(0.64, (sx * 0.90, 1.62, 0.0), "stoneDark", seg=18, rings=12))
        p += _armor_lames(
            j,
            2,
            (sx * 0.92, 1.76, -0.02),
            (sx * 0.08, -0.12, 0.0),
            (0.46, 0.16, 0.48),
            (-0.04, 0.0, -0.04),
            "ember",
            trim_color="ironDark",
            rot=(0.0, 0.0, -sx * 0.25),
            bevel=0.02,
        )
        p.append(j.crystal(0.15, 0.48, (sx * 1.04, 1.82, -0.04), "amberBright", tilt=(0.18, -sx * 0.52), verts=6))
        p.append(j.capsule_seg((sx * 0.48, 1.62, 0.36), (sx * 0.58, 2.62, 0.74), 0.22, 0.17, "stoneDark", verts=20))
        p.append(j.torus(0.22, 0.042, (sx * 0.52, 1.96, 0.49), "ironDark", major_seg=20, minor_seg=8, rot=(-0.38, sx * 0.18, 0.0)))
        p.append(j.torus(0.20, 0.042, (sx * 0.57, 2.50, 0.69), "iron", major_seg=20, minor_seg=8, rot=(-0.38, sx * 0.18, 0.0)))
        p.append(j.ico(0.20, (sx * 0.58, 2.68, 0.78), "ember", squash=(1.0, 0.85, 1.0), subdiv=2))
        p.append(j.ico(0.11, (sx * 0.18, 1.98, -0.56), "neonAmber", squash=(1.35, 0.55, 0.55), subdiv=2))
    for k in range(5):
        p.append(
            j.crystal(
                0.14,
                0.56 - k * 0.05,
                (0.0, 2.24 - k * 0.04, -0.18 + k * 0.15),
                "ember" if k % 2 == 0 else "amberBright",
                tilt=(-0.22 - k * 0.22, 0.0),
                verts=6,
            )
        )
    return p


def slag_juggernaut_arm_r():
    """A2 Braco Direito: ombro (0,0,0) + Malho Esmagador de Fundicao com rebites, colares e bigorna dupla."""
    j = Rb("slag_juggernaut")
    p = [
        j.ball(0.38, (0.0, 0.0, 0.0), "stoneDark", seg=22, rings=14),
        j.cyl(0.22, 0.58, (0.02, -0.54, -0.08), "ironDark", verts=24, r2=0.24),
        j.torus(0.24, 0.044, (0.03, -0.44, -0.10), "stoneDark", major_seg=22, minor_seg=10),
        j.ico(0.32, (0.04, -0.62, -0.22), "ember", squash=(1.05, 0.90, 1.05), subdiv=2),
        j.box((0.40, 0.28, 0.36), (0.04, -0.60, -0.26), "stoneDark", rot=(0.32, 0.0, 0.0), bevel=0.035),
        # Haste rebitada com pomo e colares
        j.cyl_axis_y(0.11, 1.04, (0.04, -0.66, -0.54), "ironDark", verts=22, r2=0.12, tilt=-0.38),
        j.box((0.22, 0.22, 0.22), (0.04, -0.50, -0.12), "iron", rot=(0.38, 0.0, 0.0), bevel=0.03),
        j.torus(0.14, 0.034, (0.04, -0.74, -0.74), "iron", major_seg=18, minor_seg=8, rot=(math.pi / 2 - 0.38, 0.0, 0.0)),
        # Cabeca do Malho de Fundicao (dupla bigorna + cintas + nucleo de magma)
        j.box((0.70, 0.44, 0.46), (0.04, -0.82, -0.94), "stoneDark", rot=(0.38, 0.0, 0.0), bevel=0.04),
        j.box((0.76, 0.14, 0.50), (0.04, -0.82, -0.94), "ironDark", rot=(0.38, 0.0, 0.0), bevel=0.03),
        j.box((0.58, 0.48, 0.14), (0.04, -0.82, -0.94), "iron", rot=(0.38, 0.0, 0.0), bevel=0.025),
        j.torus(0.26, 0.048, (0.04, -0.86, -1.04), "iron", major_seg=22, minor_seg=10, rot=(math.pi / 2 + 0.38, 0.0, 0.0)),
        j.torus(0.26, 0.044, (0.04, -0.78, -0.84), "amber", major_seg=20, minor_seg=8, rot=(math.pi / 2 + 0.38, 0.0, 0.0)),
        j.ico(0.28, (0.04, -0.82, -0.96), "danger", squash=(1.28, 0.82, 0.82), subdiv=2),
        j.crystal(0.14, 0.36, (0.04, -0.90, -1.14), "amberBright", tilt=(math.pi / 2 + 0.38, 0.0), verts=6),
    ]
    p += _armor_lames(
        j,
        2,
        (0.06, -0.10, -0.04),
        (0.04, -0.10, 0.0),
        (0.38, 0.14, 0.36),
        (-0.04, 0.0, -0.04),
        "ember",
        trim_color="ironDark",
        rot=(0.0, 0.0, -0.22),
        bevel=0.02,
    )
    p += _piston(j, (0.20, -0.18, -0.08), (0.22, -0.56, -0.22), 0.055, 0.032, "iron", "amber", "ironDark")
    p += _rivet_ring(j, (0.04, -0.86, -1.04), 0.27, 8, 0.050, "amberBright", plane="xy")
    for sx_h in (-1, 1):
        p.append(j.cyl_axis_x(0.18, 0.14, (0.04 + sx_h * 0.38, -0.82, -0.94), "iron", verts=16, bevel=0.02))
        p.append(j.ico(0.11, (0.04 + sx_h * 0.44, -0.82, -0.94), "amberBright", subdiv=1))
    return p


def slag_juggernaut_arm_l():
    """A2 Braco Esquerdo: ombro (0,0,0) + punho esmagador enjaulado com pistoes e garras de forja."""
    j = Rb("slag_juggernaut")
    p = [
        j.ball(0.38, (0.0, 0.0, 0.0), "stoneDark", seg=22, rings=14),
        j.cyl(0.23, 0.58, (-0.02, -0.56, -0.08), "ironDark", verts=24, r2=0.25),
        j.torus(0.25, 0.044, (-0.03, -0.44, -0.10), "stoneDark", major_seg=22, minor_seg=10),
        j.torus(0.27, 0.048, (-0.04, -0.64, -0.22), "iron", major_seg=22, minor_seg=10, rot=(0.45, 0.0, 0.0)),
        j.ico(0.38, (-0.04, -0.72, -0.28), "ember", squash=(1.08, 0.95, 1.12), subdiv=2),
        j.ico(0.28, (-0.04, -0.76, -0.38), "amberBright", squash=(0.95, 0.88, 0.95), subdiv=2),
        j.box((0.46, 0.34, 0.42), (-0.06, -0.70, -0.32), "stoneDark", rot=(0.24, 0.0, 0.0), bevel=0.04),
        j.box((0.50, 0.14, 0.22), (-0.06, -0.64, -0.24), "iron", rot=(0.24, 0.0, 0.0), bevel=0.025),
        j.box((0.14, 0.24, 0.34), (-0.22, -0.78, -0.44), "ironDark", rot=(0.35, 0.0, 0.0), bevel=0.03),
        j.box((0.14, 0.24, 0.34), (0.10, -0.78, -0.44), "ironDark", rot=(0.35, 0.0, 0.0), bevel=0.03),
        j.crystal(0.13, 0.36, (-0.18, -0.82, -0.54), "amberBright", tilt=(1.35, 0.22), verts=6),
        j.crystal(0.13, 0.36, (-0.04, -0.84, -0.56), "ember", tilt=(1.38, 0.0), verts=6),
        j.crystal(0.13, 0.36, (0.08, -0.82, -0.54), "danger", tilt=(1.35, -0.18), verts=6),
    ]
    p += _armor_lames(
        j,
        2,
        (-0.06, -0.10, -0.04),
        (-0.04, -0.10, 0.0),
        (0.38, 0.14, 0.36),
        (-0.04, 0.0, -0.04),
        "ember",
        trim_color="ironDark",
        rot=(0.0, 0.0, 0.22),
        bevel=0.02,
    )
    p += _piston(j, (-0.20, -0.18, -0.06), (-0.22, -0.58, -0.22), 0.055, 0.032, "iron", "amber", "ironDark")
    p += _piston(j, (0.14, -0.18, -0.06), (0.14, -0.56, -0.20), 0.050, 0.028, "iron", "amber", "ironDark")
    p += _rivet_ring(j, (-0.04, -0.64, -0.22), 0.28, 8, 0.048, "amber", plane="xy")
    # Jaula de forja no punho + colar frontal + placas laterais do antebraco
    p.append(j.torus(0.24, 0.040, (-0.04, -0.74, -0.44), "ironDark", major_seg=20, minor_seg=8, rot=(math.pi / 2 - 0.24, 0.0, 0.0)))
    p.append(j.box((0.18, 0.34, 0.26), (-0.26, -0.50, -0.14), "iron", rot=(0.24, 0.10, 0.0), bevel=0.025))
    p.append(j.box((0.18, 0.34, 0.26), (0.18, -0.50, -0.14), "iron", rot=(0.24, -0.10, 0.0), bevel=0.025))
    p.append(j.box((0.42, 0.10, 0.28), (-0.04, -0.82, -0.46), "iron", rot=(0.24, 0.0, 0.0), bevel=0.02))
    p.append(j.box((0.42, 0.10, 0.28), (-0.04, -0.56, -0.34), "ironDark", rot=(0.24, 0.0, 0.0), bevel=0.02))
    return p


def slag_juggernaut_leg(sx: int):
    """A2 Perna: pilar de fundicao desde (0,0,0) com grade de escoria, pistao e greva rebitada."""
    j = Rb("slag_juggernaut")
    p = [
        j.ball(0.36, (0.0, 0.0, 0.0), "stoneDark", seg=22, rings=14),
        j.cyl(0.32, 0.74, (0.0, -0.74, 0.0), "stoneDark", verts=28, r2=0.28),
        j.torus(0.30, 0.044, (0.0, -0.34, 0.0), "ironDark", major_seg=24, minor_seg=10),
        j.torus(0.28, 0.040, (0.0, -0.58, 0.0), "iron", major_seg=22, minor_seg=8),
        j.ico(0.22, (sx * 0.05, -0.38, -0.22), "ember", squash=(0.95, 0.80, 0.65), subdiv=2),
        j.box((0.38, 0.44, 0.22), (0.0, -0.48, -0.16), "ironDark", bevel=0.035),
        j.box((0.42, 0.12, 0.24), (0.0, -0.48, -0.18), "iron", bevel=0.025),
        j.box((0.50, 0.22, 0.62), (0.0, -0.74, -0.08), "ironDark", bevel=0.035),
        j.box((0.36, 0.14, 0.24), (0.0, -0.66, -0.32), "ember", bevel=0.025),
        j.box((0.16, 0.28, 0.24), (sx * 0.22, -0.52, -0.04), "amberBright", bevel=0.025),
    ]
    p += _piston(j, (0.0, -0.24, 0.24), (0.0, -0.70, 0.22), 0.055, 0.032, "iron", "amber", "ironDark")
    p += _rivet_ring(j, (0.0, -0.34, 0.0), 0.31, 6, 0.046, "amber", plane="xz")
    return p


def slag_juggernaut():
    """Act 2 Showcase: Juggernaut de Escoria unificado (14,800-17,600 tris)."""
    j = Rb("slag_juggernaut")
    p = slag_juggernaut_torso()
    p += _transform_parts(slag_juggernaut_leg(-1), j, (-0.52, 0.78, 0.0))
    p += _transform_parts(slag_juggernaut_leg(1), j, (0.52, 0.78, 0.0))
    p += _transform_parts(slag_juggernaut_arm_r(), j, (0.98, 1.58, -0.04), rot_blender=(0.18, 0.0, 0.0))
    p += _transform_parts(slag_juggernaut_arm_l(), j, (-0.98, 1.58, -0.04), rot_blender=(0.12, 0.0, 0.0))
    return p


# ==============================================================================
# ACT 3 — RIME MATRIARCH
# ==============================================================================
def rime_matriarch_torso():
    """A3 Torso: corpete glacial, manto de cristais, coroa chifruda 9 pontas e halo runico duplo."""
    m = Rb("rime_matriarch")
    p = [
        m.cyl(0.48, 0.44, (0.0, 0.94, 0.0), "stoneDark", verts=28, r2=0.38),
        m.cyl(0.56, 0.22, (0.0, 0.88, 0.0), "royal", verts=28, r2=0.44),
        m.torus(0.52, 0.040, (0.0, 0.92, 0.0), "arcaneCyan", major_seg=20, minor_seg=8),
        m.torus(0.45, 0.045, (0.0, 1.16, 0.0), "iceLight", major_seg=24, minor_seg=10),
        m.ico(0.56, (0.0, 1.54, 0.0), "stoneDark", squash=(1.04, 1.18, 0.78), subdiv=2),
        m.ico(0.46, (0.0, 1.58, -0.10), "royal", squash=(0.92, 1.08, 0.72), subdiv=2),
        m.ico(0.22, (0.0, 1.56, -0.36), "arcaneCyan", squash=(0.90, 0.90, 0.65), subdiv=2),
        m.torus(0.24, 0.032, (0.0, 1.56, -0.34), "iceLight", major_seg=18, minor_seg=8, rot=(math.pi / 2, 0.0, 0.0)),
        m.crystal(0.22, 0.52, (0.0, 1.56, -0.40), "iceGlow", tilt=(1.45, 0.0), verts=6),
        m.ball(0.74, (0.0, 2.22, -0.06), "ironDark", seg=22, rings=14, squash=(0.92, 1.08, 0.98)),
        m.torus(0.32, 0.040, (0.0, 2.48, -0.04), "iceLight", major_seg=22, minor_seg=8),
        # Halo torus duplo flutuante nas costas
        m.torus(
            0.66,
            0.048,
            (0.0, 2.38, 0.32),
            "arcaneCyan",
            major_seg=28,
            minor_seg=10,
            rot=(math.pi / 2 - 0.18, 0.0, 0.0),
        ),
        m.torus(
            0.46,
            0.034,
            (0.0, 2.38, 0.34),
            "iceGlow",
            major_seg=24,
            minor_seg=8,
            rot=(math.pi / 2 - 0.18, 0.36, 0.0),
        ),
    ]
    for k in range(8):
        ha = 2 * math.pi * k / 8 + 0.20
        p.append(m.ico(0.085, (0.66 * math.cos(ha), 2.38 + 0.66 * math.sin(ha), 0.32), "iceGlow", subdiv=1))
    p += _rivet_ring(m, (0.0, 1.16, 0.0), 0.47, 10, 0.045, "arcaneCyan", plane="xz")
    for sx in (-1, 1):
        p.append(m.crystal(0.24, 1.05, (sx * 0.62, 1.78, 0.06), "ice", tilt=(-0.22, -sx * 0.62), verts=6))
        p.append(m.crystal(0.18, 0.82, (sx * 0.84, 1.66, 0.16), "iceLight", tilt=(-0.38, -sx * 0.92), verts=6))
        p.append(m.crystal(0.13, 0.56, (sx * 0.48, 1.92, 0.14), "arcaneCyan", tilt=(-0.30, -sx * 0.42), verts=6))
        p.append(m.torus(0.20, 0.032, (sx * 0.56, 1.76, 0.02), "iceLight", major_seg=16, minor_seg=6, rot=(0.2, 0.0, -sx * 0.5)))
        p.append(m.box((0.28, 0.72, 0.10), (sx * 0.28, 1.48, 0.28), "royal", rot=(0.18, sx * 0.20, 0.0), bevel=0.03))
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
            verts=20,
            three_seg=True,
            collar_color="iceLight",
        )
    for k in range(9):
        ang = (k - 4) * 0.25
        p.append(
            m.crystal(
                0.11,
                0.96 - abs(k - 4) * 0.10,
                (math.sin(ang) * 0.28, 2.52, -0.02 + abs(k - 4) * 0.025),
                "iceGlow" if k == 4 else ("arcaneCyan" if k % 2 == 1 else "iceLight"),
                tilt=(-0.12, -ang * 0.65),
                verts=6,
            )
        )
    return p


def rime_matriarch_arm_r():
    """A3 Braco Direito: ombro (0,0,0) + Cetro Boreal multi-pontas com duplo anel giroscopico."""
    m = Rb("rime_matriarch")
    p = [
        m.ball(0.30, (0.0, 0.0, 0.0), "ironDark", seg=22, rings=14),
        m.cyl(0.16, 0.56, (0.02, -0.52, -0.10), "ironDark", verts=24, r2=0.12),
        m.torus(0.16, 0.034, (0.03, -0.44, -0.10), "iceLight", major_seg=22, minor_seg=10),
        m.torus(0.18, 0.030, (0.02, -0.22, -0.06), "arcaneCyan", major_seg=20, minor_seg=8),
        m.crystal(0.14, 0.44, (0.06, -0.24, -0.06), "ice", tilt=(-0.25, -0.45), verts=6),
        m.crystal(0.10, 0.34, (0.14, -0.18, 0.02), "iceLight", tilt=(-0.35, -0.65), verts=6),
        # Cetro Boreal
        m.cyl_axis_y(0.08, 1.18, (0.04, -0.62, -0.56), "ironDark", verts=22, r2=0.09, tilt=-0.42),
        m.torus(0.11, 0.024, (0.04, -0.48, -0.22), "arcaneCyan", major_seg=16, minor_seg=6, rot=(0.42, 0.0, 0.0)),
        m.torus(0.11, 0.024, (0.04, -0.58, -0.44), "iceLight", major_seg=16, minor_seg=6, rot=(0.42, 0.0, 0.0)),
        m.torus(0.11, 0.024, (0.04, -0.70, -0.72), "iceLight", major_seg=16, minor_seg=6, rot=(0.42, 0.0, 0.0)),
        m.crystal(0.10, 0.30, (0.04, -0.40, -0.08), "ice", tilt=(-math.pi / 2 + 0.42, 0.0), verts=6),
        m.torus(0.24, 0.038, (0.04, -0.82, -0.96), "arcaneCyan", major_seg=24, minor_seg=10, rot=(0.42, 0.0, 0.0)),
        m.torus(0.19, 0.030, (0.04, -0.82, -0.96), "iceLight", major_seg=20, minor_seg=8, rot=(0.42, 0.65, 0.0)),
        m.ico(0.22, (0.04, -0.82, -0.96), "iceGlow", squash=(0.95, 0.95, 1.15), subdiv=2),
        m.crystal(0.15, 0.56, (0.04, -0.86, -1.02), "iceGlow", tilt=(math.pi / 2 + 0.42, 0.0), verts=6),
        m.crystal(0.11, 0.42, (0.20, -0.76, -0.92), "arcaneCyan", tilt=(1.15, -0.48), verts=6),
        m.crystal(0.11, 0.42, (-0.12, -0.76, -0.92), "arcaneCyan", tilt=(1.15, 0.48), verts=6),
        m.capsule_seg((0.18, -0.74, -0.86), (0.34, -0.88, -1.16), 0.075, 0.012, "iceLight", verts=18),
        m.capsule_seg((-0.10, -0.74, -0.86), (-0.26, -0.88, -1.16), 0.075, 0.012, "iceLight", verts=18),
    ]
    for k in range(6):
        ha = 2 * math.pi * k / 6
        p.append(m.ico(0.055, (0.04 + 0.24 * math.cos(ha), -0.82 + 0.24 * math.sin(ha) * 0.4, -0.96 + 0.24 * math.sin(ha) * 0.9), "iceGlow", subdiv=1))
    return p


def rime_matriarch_arm_l():
    """A3 Braco Esquerdo: ombro (0,0,0) + manopla de gelo e escudo runico cristalino."""
    m = Rb("rime_matriarch")
    p = [
        m.ball(0.30, (0.0, 0.0, 0.0), "ironDark", seg=22, rings=14),
        m.cyl(0.16, 0.58, (-0.02, -0.54, -0.10), "ironDark", verts=24, r2=0.12),
        m.torus(0.16, 0.034, (-0.02, -0.38, -0.08), "iceLight", major_seg=22, minor_seg=8),
        m.torus(0.18, 0.030, (-0.02, -0.22, -0.06), "arcaneCyan", major_seg=20, minor_seg=8),
        m.torus(0.19, 0.032, (-0.04, -0.52, -0.16), "ice", major_seg=20, minor_seg=8, rot=(0.35, 0.0, 0.0)),
        m.crystal(0.12, 0.36, (-0.12, -0.20, 0.02), "iceLight", tilt=(-0.25, 0.48), verts=6),
        m.box((0.26, 0.24, 0.44), (-0.06, -0.58, -0.24), "royal", rot=(0.28, 0.0, 0.0), bevel=0.03),
        m.box((0.16, 0.40, 0.46), (-0.18, -0.54, -0.24), "ice", rot=(0.24, 0.22, 0.0), bevel=0.03),
        m.box((0.12, 0.30, 0.36), (-0.22, -0.54, -0.24), "iceLight", rot=(0.24, 0.22, 0.0), bevel=0.025),
        m.torus(0.22, 0.038, (-0.14, -0.56, -0.26), "arcaneCyan", major_seg=24, minor_seg=10, rot=(0.35, 0.45, 0.0)),
        m.torus(0.24, 0.030, (-0.24, -0.54, -0.24), "ice", major_seg=20, minor_seg=8, rot=(0.24, 1.35, 0.0)),
        m.torus(0.14, 0.026, (-0.20, -0.54, -0.24), "iceGlow", major_seg=18, minor_seg=6, rot=(0.24, 1.35, 0.0)),
        m.ico(0.16, (-0.08, -0.62, -0.28), "iceGlow", subdiv=2),
        m.crystal(0.18, 0.56, (-0.16, -0.48, -0.22), "ice", tilt=(0.35, 0.42), verts=6),
        m.capsule_seg((-0.02, -0.64, -0.28), (-0.02, -0.84, -0.64), 0.08, 0.012, "iceGlow", verts=18),
        m.capsule_seg((-0.12, -0.64, -0.26), (-0.16, -0.82, -0.60), 0.075, 0.012, "arcaneCyan", verts=18),
        m.capsule_seg((0.06, -0.64, -0.26), (0.10, -0.82, -0.60), 0.075, 0.012, "iceLight", verts=18),
        m.capsule_seg((-0.20, -0.58, -0.22), (-0.28, -0.74, -0.52), 0.065, 0.012, "ice", verts=16),
    ]
    p += _rivet_ring(m, (-0.22, -0.54, -0.24), 0.16, 6, 0.042, "iceGlow", plane="yz")
    return p


def rime_matriarch_leg(sx: int):
    """A3 Perna: saia/vestido glacial em camadas com bainha de cristais desde (0,0,0)."""
    m = Rb("rime_matriarch")
    p = [
        m.ball(0.32, (0.0, 0.0, 0.0), "stoneDark", seg=22, rings=14),
        m.cyl(0.34, 0.44, (0.0, -0.42, 0.0), "royal", verts=26, r2=0.24),
        m.cyl(0.38, 0.46, (0.0, -0.74, 0.0), "stoneDark", verts=26, r2=0.20),
        m.torus(0.30, 0.036, (0.0, -0.34, 0.0), "iceLight", major_seg=24, minor_seg=8),
        m.torus(0.34, 0.040, (0.0, -0.64, 0.0), "arcaneCyan", major_seg=24, minor_seg=10),
        m.box((0.24, 0.56, 0.14), (sx * 0.16, -0.48, -0.10), "ice", rot=(0.12, 0.0, -sx * 0.18), bevel=0.03),
        m.box((0.22, 0.52, 0.14), (-sx * 0.12, -0.52, 0.10), "iceLight", rot=(-0.12, 0.0, sx * 0.16), bevel=0.03),
        m.box((0.18, 0.48, 0.12), (0.0, -0.46, -0.18), "royal", rot=(0.08, 0.0, 0.0), bevel=0.02),
        m.crystal(0.22, 0.68, (sx * 0.14, -0.72, -0.10), "ice", tilt=(-0.18, -sx * 0.24), verts=6),
        m.crystal(0.18, 0.58, (-sx * 0.10, -0.76, 0.12), "iceLight", tilt=(0.16, sx * 0.20), verts=6),
        m.crystal(0.16, 0.44, (0.0, -0.52, -0.18), "iceGlow", tilt=(math.pi, 0.0), verts=6),
    ]
    p += _rivet_ring(m, (0.0, -0.64, 0.0), 0.36, 8, 0.045, "iceGlow", plane="xz")
    p += _rivet_ring(m, (0.0, -0.34, 0.0), 0.31, 6, 0.042, "iceLight", plane="xz")
    return p


def rime_matriarch():
    """Act 3 Showcase: Matriarca Boreal com vestido glacial completo (14,800-17,600 tris)."""
    m = Rb("rime_matriarch")
    p = rime_matriarch_torso()
    # Vestido glacial em 3 camadas + 12 cristais perifericos (preserva silhueta iconica)
    p += [
        m.cyl(0.90, 0.78, (0.0, 0.0, 0.0), "stoneDark", verts=28, r2=0.62),
        m.cyl(0.68, 0.62, (0.0, 0.64, 0.0), "royal", verts=28, r2=0.44),
        m.torus(0.88, 0.048, (0.0, 0.12, 0.0), "ice", major_seg=24, minor_seg=8),
        m.torus(0.65, 0.046, (0.0, 0.68, 0.0), "arcaneCyan", major_seg=22, minor_seg=8),
        m.torus(0.47, 0.040, (0.0, 1.18, 0.0), "iceLight", major_seg=20, minor_seg=6),
    ]
    for k in range(10):
        a = 2 * math.pi * k / 10
        p.append(
            m.crystal(
                0.20,
                0.96 if k % 2 == 0 else 0.76,
                (0.72 * math.cos(a), 0.10, 0.72 * math.sin(a)),
                "ice" if k % 2 == 0 else "iceLight",
                tilt=(-0.22 * math.sin(a), -0.22 * math.cos(a)),
                verts=6,
            )
        )
    p += _transform_parts(rime_matriarch_leg(-1), m, (-0.34, 0.90, 0.0))
    p += _transform_parts(rime_matriarch_leg(1), m, (0.34, 0.90, 0.0))
    p += _transform_parts(rime_matriarch_arm_r(), m, (0.76, 1.66, -0.06), rot_blender=(0.14, 0.0, 0.0))
    p += _transform_parts(rime_matriarch_arm_l(), m, (-0.76, 1.66, -0.06), rot_blender=(0.10, 0.0, 0.0))
    return p


# ==============================================================================
# ACT 4 — POWDER BARON
# ==============================================================================
def powder_baron_torso():
    """A4 Torso: sobretudo blindado, bandoleira de 6 granadas, caldeiras duplas, morteiros e tricornio."""
    pb = Rb("powder_baron")
    p = [
        pb.cyl(0.64, 0.44, (0.0, 0.84, 0.0), "crimsonCloth", verts=24, r2=0.52),
        pb.torus(0.55, 0.052, (0.0, 1.18, 0.0), "brass", major_seg=24, minor_seg=8),
        pb.box((0.28, 0.18, 0.14), (0.0, 1.18, -0.56), "gold", bevel=0.02),
        pb.ico(0.64, (0.0, 1.44, 0.0), "ironDark", squash=(1.12, 1.06, 0.82), subdiv=2),
        pb.ico(0.26, (0.0, 1.46, -0.46), "goldBright", squash=(1.0, 1.0, 0.55), subdiv=2),
        pb.capsule_seg((-0.34, 1.72, 0.42), (0.34, 1.72, 0.42), 0.075, 0.075, "bronze", verts=12),
        pb.ball(0.72, (0.0, 2.12, -0.06), "ironDark", seg=18, rings=10),
        pb.cyl(0.80, 0.14, (0.0, 2.34, -0.04), "ironDark", verts=20, r2=0.72),
        pb.cyl(0.48, 0.36, (0.0, 2.44, -0.02), "gold", verts=20, r2=0.38),
        pb.torus(0.50, 0.036, (0.0, 2.44, -0.02), "brass", major_seg=20, minor_seg=6),
        pb.crystal(0.16, 0.68, (0.28, 2.66, 0.12), "crimsonBright", tilt=(-0.68, -0.35), verts=6),
        pb.crystal(0.11, 0.48, (0.22, 2.62, 0.16), "goldBright", tilt=(-0.55, -0.25), verts=6),
    ]
    p += _rivet_ring(pb, (0.0, 1.18, 0.0), 0.56, 8, 0.046, "gold", plane="xz")
    for sx in (-1, 1):
        p.append(pb.box((0.14, 0.72, 0.16), (sx * 0.26, 1.44, -0.42), "bronze", rot=(0.0, 0.0, sx * 0.42), bevel=0.025))
        # 3 granadas por bandoleira com aro de latao
        for g_i in range(3):
            gx = sx * (0.32 - g_i * 0.07)
            gy = 1.56 - g_i * 0.14
            gz = -0.46 - g_i * 0.02
            p.append(pb.cyl(0.10, 0.18, (gx, gy, gz), "danger" if g_i == 1 else "ironDark", verts=12))
            p.append(pb.cyl(0.108, 0.04, (gx, gy + 0.09, gz), "brass", verts=12))
        # Caldeiras a vapor duplas nas costas com colares torus e manometro
        p.append(pb.cyl(0.24, 0.68, (sx * 0.34, 1.32, 0.38), "brass", verts=18, r2=0.22))
        p.append(pb.torus(0.24, 0.040, (sx * 0.34, 1.56, 0.38), "ironDark", major_seg=20, minor_seg=8))
        p.append(pb.torus(0.23, 0.036, (sx * 0.34, 1.82, 0.38), "ironDark", major_seg=18, minor_seg=6))
        p.append(pb.cyl_axis_y(0.09, 0.10, (sx * 0.34, 1.68, 0.60), "gold", verts=12))
        p.append(pb.ball(0.60, (sx * 0.76, 1.72, 0.0), "bronze", seg=16, rings=10))
        p.append(pb.cyl_axis_y(0.24, 1.12, (sx * 0.78, 2.02, -0.22), "ironDark", verts=18, r2=0.28, tilt=0.45))
        p.append(pb.torus(0.26, 0.038, (sx * 0.78, 2.12, -0.42), "brass", major_seg=20, minor_seg=8, rot=(math.pi / 2 - 0.45, 0.0, 0.0)))
        p.append(pb.cyl_axis_y(0.29, 0.18, (sx * 0.78, 2.24, -0.68), "gold", verts=18, r2=0.29, tilt=0.45))
        p.append(pb.ico(0.14, (sx * 0.78, 2.16, 0.34), "danger", subdiv=1))
        # Oculos de latao
        p.append(pb.torus(0.11, 0.030, (sx * 0.15, 2.13, -0.38), "brass", major_seg=16, minor_seg=6, rot=(math.pi / 2, sx * 0.18, 0.0)))
        p.append(pb.ico(0.09, (sx * 0.15, 2.13, -0.40), "amberBright", squash=(1.2, 0.55, 0.55), subdiv=1))
        p.append(pb.box((0.20, 0.18, 0.58), (sx * 0.46, 2.44, -0.04), "obsidian", rot=(0.0, 0.0, -sx * 0.38), bevel=0.03))
    return p


def powder_baron_arm_r():
    """A4 Braco Direito: ombro (0,0,0) + Canhao Rotativo 6 canos com bocais, engrenagem e mira."""
    pb = Rb("powder_baron")
    tilt = -0.28
    p = [
        pb.ball(0.34, (0.0, 0.0, 0.0), "bronze", seg=20, rings=14),
        pb.cyl(0.19, 0.52, (0.02, -0.48, -0.08), "ironDark", verts=20, r2=0.21),
        pb.cyl_axis_y(0.25, 0.30, (0.04, -0.56, -0.32), "brass", verts=20, r2=0.25, tilt=tilt, bevel=0.02),
        pb.torus(0.26, 0.036, (0.04, -0.54, -0.26), "ironDark", major_seg=18, minor_seg=6, rot=(math.pi / 2 - tilt, 0.0, 0.0)),
        pb.cyl_axis_y(0.065, 0.90, (0.04, -0.68, -0.66), "steel", verts=14, tilt=tilt),
        pb.torus(0.20, 0.038, (0.04, -0.62, -0.50), "brass", major_seg=18, minor_seg=6, rot=(math.pi / 2 - tilt, 0.0, 0.0)),
        pb.torus(0.20, 0.036, (0.04, -0.69, -0.72), "ironDark", major_seg=18, minor_seg=6, rot=(math.pi / 2 - tilt, 0.0, 0.0)),
        pb.torus(0.20, 0.040, (0.04, -0.75, -0.92), "gold", major_seg=18, minor_seg=6, rot=(math.pi / 2 - tilt, 0.0, 0.0)),
        # Trilho de mira superior com luneta + caixa de municao
        pb.box((0.12, 0.18, 0.46), (0.04, -0.46, -0.54), "bronze", rot=(-tilt, 0.0, 0.0), bevel=0.025),
        pb.cyl_axis_y(0.06, 0.34, (0.04, -0.34, -0.54), "gold", verts=14, r2=0.075, tilt=tilt),
        pb.box((0.20, 0.24, 0.26), (0.24, -0.54, -0.34), "brass", rot=(-tilt, 0.0, 0.0), bevel=0.02),
        pb.ico(0.14, (0.04, -0.52, -0.18), "danger", subdiv=2),
    ]
    p += _fluted_gear(pb, (0.24, -0.48, -0.16), 0.16, 0.06, 8, "brass", hub_color="gold", plane="yz")
    p += _piston(pb, (-0.12, -0.18, -0.06), (-0.12, -0.54, -0.26), 0.048, 0.028, "bronze", "steel", "ironDark")
    p += _rivet_ring(pb, (0.04, -0.54, -0.26), 0.26, 8, 0.042, "gold", plane="xy")
    for k in range(6):
        a = 2 * math.pi * k / 6
        rx = 0.04 + 0.135 * math.cos(a)
        ry = -0.68 + 0.135 * math.sin(a) * math.cos(tilt)
        rz = -0.66 - 0.135 * math.sin(a) * math.sin(tilt)
        p.append(pb.cyl_axis_y(0.052, 0.86, (rx, ry, rz), "ironDark", verts=16, tilt=tilt))
        # Bocal reforçado na ponta de cada cano
        mx = 0.04 + 0.135 * math.cos(a)
        my = -0.79 + 0.135 * math.sin(a) * math.cos(tilt)
        mz = -1.04 - 0.135 * math.sin(a) * math.sin(tilt)
        p.append(pb.cyl_axis_y(0.064, 0.10, (mx, my, mz), "brass", verts=14, tilt=tilt))
    return p


def powder_baron_arm_l():
    """A4 Braco Esquerdo: ombro (0,0,0) + escudo de explosao rebitado e garra mecanica articulada."""
    pb = Rb("powder_baron")
    p = [
        pb.ball(0.34, (0.0, 0.0, 0.0), "bronze", seg=22, rings=14),
        pb.cyl(0.19, 0.54, (-0.02, -0.50, -0.08), "ironDark", verts=22, r2=0.21),
        pb.torus(0.20, 0.036, (-0.02, -0.34, -0.08), "brass", major_seg=20, minor_seg=8),
        pb.ico(0.24, (-0.04, -0.60, -0.24), "bronze", subdiv=2),
        # Escudo de pulso com boss e rebites
        pb.box((0.18, 0.52, 0.56), (-0.22, -0.58, -0.32), "ironDark", rot=(0.24, 0.16, 0.0), bevel=0.035),
        pb.box((0.12, 0.40, 0.42), (-0.28, -0.58, -0.32), "brass", rot=(0.24, 0.16, 0.0), bevel=0.025),
        pb.torus(0.21, 0.038, (-0.26, -0.58, -0.32), "gold", major_seg=22, minor_seg=10, rot=(0.24, 1.25, 0.0)),
        pb.ico(0.10, (-0.31, -0.58, -0.32), "goldBright", subdiv=2),
        pb.cyl_axis_y(0.16, 0.46, (-0.06, -0.66, -0.44), "ironDark", verts=20, r2=0.18, tilt=-0.32),
        pb.torus(0.18, 0.032, (-0.06, -0.68, -0.52), "brass", major_seg=18, minor_seg=8, rot=(math.pi / 2 - 0.32, 0.0, 0.0)),
        # Garras articuladas
        pb.capsule_seg((-0.14, -0.68, -0.54), (-0.18, -0.82, -0.82), 0.065, 0.015, "steel", verts=18),
        pb.capsule_seg((0.02, -0.68, -0.54), (0.06, -0.82, -0.82), 0.065, 0.015, "steel", verts=18),
        pb.capsule_seg((-0.06, -0.58, -0.54), (-0.06, -0.70, -0.84), 0.065, 0.015, "brass", verts=18),
        pb.capsule_seg((0.10, -0.62, -0.48), (0.18, -0.74, -0.74), 0.055, 0.015, "gold", verts=16),
    ]
    p += _piston(pb, (0.10, -0.28, -0.10), (0.06, -0.62, -0.42), 0.052, 0.030, "bronze", "steel", "brass")
    p += _piston(pb, (-0.14, -0.24, -0.06), (-0.16, -0.54, -0.32), 0.048, 0.026, "ironDark", "steel", "brass")
    p += _rivet_ring(pb, (-0.28, -0.58, -0.32), 0.22, 8, 0.042, "gold", plane="yz")
    p += _fluted_gear(pb, (-0.18, -0.42, -0.16), 0.14, 0.05, 8, "brass", hub_color="ironDark", plane="yz")
    return p


def powder_baron_leg(sx: int):
    """A4 Perna: bota blindada de cerco com fivelas de latao, aba e engrenagem lateral desde (0,0,0)."""
    pb = Rb("powder_baron")
    p = [
        pb.ball(0.32, (0.0, 0.0, 0.0), "crimsonCloth", seg=22, rings=14),
        pb.cyl(0.26, 0.76, (0.0, -0.76, 0.0), "ironDark", verts=24, r2=0.22),
        pb.cyl(0.30, 0.16, (0.0, -0.28, 0.0), "bronze", verts=24, r2=0.30),
        pb.torus(0.27, 0.040, (0.0, -0.30, 0.0), "brass", major_seg=22, minor_seg=10),
        pb.torus(0.25, 0.036, (0.0, -0.54, 0.0), "brass", major_seg=20, minor_seg=8),
        pb.box((0.16, 0.46, 0.36), (sx * 0.18, -0.26, 0.02), "crimsonCloth", rot=(0.0, 0.0, -sx * 0.18), bevel=0.03),
        pb.box((0.26, 0.38, 0.18), (0.0, -0.52, -0.14), "brass", bevel=0.03),
        pb.box((0.38, 0.20, 0.54), (0.0, -0.76, -0.08), "ironDark", bevel=0.035),
        pb.box((0.30, 0.14, 0.24), (0.0, -0.74, -0.28), "brass", bevel=0.025),
        pb.ico(0.11, (0.0, -0.68, -0.34), "gold", subdiv=2),
    ]
    p += _fluted_gear(pb, (sx * 0.24, -0.50, 0.0), 0.13, 0.05, 6, "brass", hub_color="gold", plane="yz")
    p += _rivet_ring(pb, (0.0, -0.30, 0.0), 0.29, 6, 0.042, "gold", plane="xz")
    return p


def powder_baron():
    """Act 4 Showcase: Baronesa da Polvora unificada (14,800-17,600 tris)."""
    pb = Rb("powder_baron")
    p = powder_baron_torso()
    p += [
        pb.cyl(0.70, 0.56, (0.0, 0.66, 0.0), "crimsonCloth", verts=28, r2=0.52),
        pb.torus(0.68, 0.038, (0.0, 0.68, 0.0), "brass", major_seg=24, minor_seg=8),
    ]
    p += _transform_parts(powder_baron_leg(-1), pb, (-0.38, 0.86, 0.0))
    p += _transform_parts(powder_baron_leg(1), pb, (0.38, 0.86, 0.0))
    p += _transform_parts(powder_baron_arm_r(), pb, (0.84, 1.62, -0.06), rot_blender=(0.12, 0.0, 0.0))
    p += _transform_parts(powder_baron_arm_l(), pb, (-0.84, 1.62, -0.06), rot_blender=(0.12, 0.0, 0.0))
    return p


# ==============================================================================
# ACT 5 — RIFT TITAN
# ==============================================================================
def rift_titan_torso():
    """A5 Torso: placas de obsidiana/violeta, nucleo de singularidade, manto, monolitos e elmo coroado."""
    t = Rb("rift_titan")
    p = [
        t.cyl(0.45, 0.28, (0.0, 1.12, -0.02), "obsidian", verts=22, r2=0.42),
        t.torus(0.45, 0.046, (0.0, 1.28, -0.02), "gold", major_seg=22, minor_seg=8),
        t.crystal(0.13, 0.22, (0.0, 1.18, -0.44), "arcaneViolet", verts=6, r2=0.13, spin=math.pi / 4),
        t.crystal(0.07, 0.14, (0.0, 1.22, -0.47), "eyeNeon", verts=6, r2=0.07, spin=math.pi / 4),
        t.cyl(0.42, 0.38, (0.0, 1.36, -0.04), "obsidian", verts=22, r2=0.52),
        t.ico(0.60, (0.0, 1.84, -0.08), "obsidian", squash=(1.22, 0.96, 0.58), subdiv=2),
        t.ico(0.38, (0.0, 1.82, -0.26), "ink", squash=(0.90, 0.92, 0.45), subdiv=2),
        t.ico(0.26, (0.0, 1.84, -0.39), "arcaneViolet", squash=(0.82, 1.08, 0.40), subdiv=2),
        t.ico(0.16, (0.0, 1.84, -0.44), "eyeNeon", squash=(0.68, 1.02, 0.38), subdiv=2),
        t.torus(0.34, 0.036, (0.0, 1.84, -0.38), "arcaneViolet", major_seg=24, minor_seg=10, rot=(math.pi / 2 - 0.15, 0.48, 0.0)),
        t.torus(0.28, 0.030, (0.0, 1.84, -0.40), "eyeNeon", major_seg=22, minor_seg=8, rot=(math.pi / 2 + 0.15, -0.52, 0.0)),
        t.cyl(0.38, 0.22, (0.0, 2.08, -0.02), "obsidian", verts=20, r2=0.44),
        t.box((1.22, 0.22, 0.28), (0.0, 2.08, 0.26), "obsidianLight", rot=(0.20, 0.0, 0.0), bevel=0.03),
        # Grande elmo coroado do Vazio
        t.ico(0.38, (0.0, 2.40, -0.05), "obsidian", squash=(0.90, 1.08, 0.98), subdiv=2),
        t.torus(0.28, 0.036, (0.0, 2.52, -0.05), "goldBright", major_seg=22, minor_seg=8),
        t.crystal(0.09, 0.42, (0.0, 2.58, -0.10), "goldBright", tilt=(-0.24, 0.0), verts=6),
    ]
    p += _rivet_ring(t, (0.0, 1.28, -0.02), 0.46, 8, 0.044, "goldBright", plane="xz")
    p += _rivet_ring(t, (0.0, 1.84, -0.42), 0.35, 6, 0.040, "eyeNeon", plane="xy")
    for sx in (-1, 1):
        p += _armor_lames(
            t,
            2,
            (sx * 0.46, 1.14, -0.02),
            (sx * 0.02, -0.14, 0.0),
            (0.24, 0.18, 0.34),
            (-0.02, 0.0, -0.04),
            "obsidianLight",
            trim_color="goldBright",
            rot=(0.0, sx * 0.24, 0.0),
            bevel=0.02,
        )
        for i in range(3):
            rib_col = "goldBright" if i == 1 else "violet"
            p.append(t.box((0.26, 0.08, 0.11), (sx * 0.28, 1.66 + i * 0.14, -0.37), rib_col, rot=(0.0, 0.0, sx * 0.26), bevel=0.02))
        p.append(t.ball(0.56, (sx * 0.68, 2.04, -0.02), "obsidian", seg=20, rings=12, squash=(1.15, 0.95, 1.05)))
        p.append(t.box((0.46, 0.18, 0.56), (sx * 0.80, 2.14, 0.02), "obsidianLight", rot=(0.08, sx * 0.34, 0.0), bevel=0.03))
        p.append(t.box((0.42, 0.08, 0.44), (sx * 0.78, 2.23, -0.02), "goldBright", rot=(0.08, sx * 0.32, 0.0), bevel=0.02))
        p.append(t.crystal(0.14, 0.66, (sx * 0.84, 2.10, 0.04), "arcaneViolet", tilt=(-0.22, -sx * 0.62), verts=6))
        p.append(t.crystal(0.10, 0.40, (sx * 0.82, 2.00, -0.22), "steel", tilt=(0.68, -sx * 0.46), verts=6))
        p.append(t.box((0.22, 0.72, 0.18), (sx * 0.62, 2.34, 0.42), "obsidian", rot=(-0.18, 0.0, -sx * 0.22), bevel=0.025))
        p.append(t.torus(0.14, 0.026, (sx * 0.62, 2.34, 0.42), "gold", major_seg=14, minor_seg=6, rot=(math.pi / 2 - 0.18, 0.0, -sx * 0.22)))
        p.append(t.crystal(0.11, 0.28, (sx * 0.68, 2.66, 0.48), "eyeNeon", tilt=(-0.18, -sx * 0.22), verts=4, spin=math.pi / 4))
        p.append(t.box((0.12, 0.28, 0.22), (sx * 0.18, 2.32, -0.24), "obsidianLight", rot=(0.08, 0.0, -sx * 0.14), bevel=0.02))
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
            verts=18,
            three_seg=True,
        )
    for idx in (-2, -1, 0, 1, 2):
        u = idx / 2.0
        col = "obsidian" if idx % 2 == 0 else "violet"
        p.append(t.box((0.26, 1.06, 0.08), (u * 0.50, 1.52, 0.46 - (1.0 - abs(u)) * 0.04), col, rot=(0.18, u * 0.18, u * 0.05), bevel=0.025))
    for k in range(5):
        ang = -0.8 + 0.4 * k
        pos_h = (0.62 * math.sin(ang), 2.74 + (1 - abs(k - 2) * 0.3) * 0.22, 0.26)
        p.append(t.crystal(0.08, 0.38, pos_h, "eyeNeon" if k % 2 == 0 else "arcaneViolet", tilt=(-0.15, -ang * 0.35), verts=6))
    return p


def rift_titan_arm_r():
    """A5 Braco Direito: ombro (0,0,0) + Lamina-Obelisco chanfrada com guarda-cruz, runas e fuller."""
    t = Rb("rift_titan")
    pitch = 0.62
    p = [
        t.ball(0.32, (0.0, 0.0, 0.0), "obsidian", seg=22, rings=14),
        t.cyl(0.17, 0.38, (0.02, -0.34, -0.06), "obsidian", verts=22, r2=0.19),
        t.torus(0.18, 0.032, (0.03, -0.26, -0.06), "gold", major_seg=20, minor_seg=8),
        t.cyl_axis_y(0.16, 0.38, (0.04, -0.40, -0.20), "obsidianLight", verts=22, r2=0.14, tilt=-0.42),
        t.torus(0.16, 0.028, (0.04, -0.40, -0.20), "arcaneViolet", major_seg=22, minor_seg=10, rot=(math.pi / 2 - 0.42, 0.0, 0.0)),
        t.ico(0.16, (0.06, -0.46, -0.34), "gold", subdiv=2),
        t.crystal(0.09, 0.22, (0.06, -0.24, -0.06), "eyeNeon", tilt=(-0.95, 0.0), verts=6),
        t.cyl_axis_y(0.075, 0.48, (0.06, -0.42, -0.28), "ink", verts=18, r2=0.085, tilt=-pitch),
        t.torus(0.095, 0.024, (0.06, -0.34, -0.16), "gold", major_seg=18, minor_seg=8, rot=(math.pi / 2 - pitch, 0.0, 0.0)),
        t.torus(0.095, 0.022, (0.06, -0.48, -0.38), "gold", major_seg=18, minor_seg=6, rot=(math.pi / 2 - pitch, 0.0, 0.0)),
        # Guarda-cruz Bastiao-Fenda
        t.box((0.44, 0.16, 0.18), (0.06, -0.56, -0.48), "goldBright", rot=(pitch, 0.0, 0.0), bevel=0.03),
        t.torus(0.17, 0.030, (0.06, -0.56, -0.48), "arcaneViolet", major_seg=24, minor_seg=10, rot=(pitch, 0.0, 0.0)),
        t.ico(0.11, (0.06, -0.56, -0.48), "eyeNeon", squash=(0.95, 0.95, 1.35), subdiv=2),
        t.crystal(0.10, 0.38, (0.22, -0.56, -0.48), "arcaneViolet", tilt=(pitch, -1.15), verts=6),
        t.crystal(0.10, 0.38, (-0.10, -0.56, -0.48), "arcaneViolet", tilt=(pitch, 1.15), verts=6),
        # Lamina-Obelisco multi-camadas
        t.box((0.24, 0.095, 1.18), (0.06, -0.88, -0.94), "obsidian", rot=(pitch, 0.0, 0.0), bevel=0.03),
        t.box((0.30, 0.055, 1.10), (0.06, -0.88, -0.94), "steel", rot=(pitch, 0.0, 0.0), bevel=0.02),
        t.box((0.12, 0.115, 1.06), (0.06, -0.87, -0.92), "arcaneViolet", rot=(pitch, 0.0, 0.0), bevel=0.02),
        t.box((0.065, 0.13, 1.00), (0.06, -0.86, -0.90), "eyeNeon", rot=(pitch, 0.0, 0.0), bevel=0.015),
        t.crystal(0.09, 0.32, (0.20, -0.74, -0.74), "tealSwarm", tilt=(pitch + 0.35, -0.85), verts=6),
        t.crystal(0.09, 0.32, (-0.08, -0.74, -0.74), "tealSwarm", tilt=(pitch + 0.35, 0.85), verts=6),
        t.crystal(0.08, 0.28, (0.20, -0.96, -1.04), "arcaneViolet", tilt=(pitch + 0.35, -0.85), verts=6),
        t.crystal(0.08, 0.28, (-0.08, -0.96, -1.04), "arcaneViolet", tilt=(pitch + 0.35, 0.85), verts=6),
        t.crystal(0.15, 0.42, (0.06, -1.16, -1.34), "steel", tilt=(math.pi / 2 + pitch, 0.0), verts=6),
    ]
    p += _armor_lames(
        t,
        3,
        (0.05, -0.10, -0.04),
        (0.04, -0.09, 0.0),
        (0.32, 0.12, 0.32),
        (-0.04, 0.0, -0.03),
        "violet",
        trim_color="goldBright",
        rot=(0.0, 0.0, -0.22),
        bevel=0.02,
    )
    # 3 barras runicas transversais ao longo da lamina
    for b_i in range(3):
        frac = 0.22 + b_i * 0.24
        p.append(
            t.box(
                (0.32 - b_i * 0.03, 0.14, 0.06),
                (0.06, -0.68 - frac * 0.44, -0.66 - frac * 0.62),
                "goldBright",
                rot=(pitch, 0.0, 0.0),
                bevel=0.015,
            )
        )
    p += _rivet_ring(t, (0.06, -0.56, -0.48), 0.18, 6, 0.036, "goldBright", plane="xy")
    return p


def rift_titan_arm_l():
    """A5 Braco Esquerdo: ombro (0,0,0) + garra do vazio com duplo anel e 4 garras articuladas."""
    t = Rb("rift_titan")
    p = [
        t.ball(0.32, (0.0, 0.0, 0.0), "obsidian", seg=22, rings=14),
        t.cyl(0.16, 0.46, (-0.02, -0.44, -0.04), "obsidian", verts=24, r2=0.19),
        t.torus(0.18, 0.032, (-0.02, -0.32, -0.04), "gold", major_seg=20, minor_seg=8),
        t.cyl_axis_y(0.17, 0.46, (-0.05, -0.62, -0.18), "obsidianLight", verts=24, r2=0.14, tilt=-0.78),
        t.box((0.26, 0.22, 0.38), (-0.06, -0.64, -0.22), "obsidian", rot=(0.68, 0.0, 0.0), bevel=0.03),
        t.box((0.14, 0.26, 0.34), (-0.18, -0.62, -0.22), "violet", rot=(0.68, 0.15, 0.0), bevel=0.025),
        t.box((0.10, 0.32, 0.36), (-0.24, -0.60, -0.22), "steel", rot=(0.68, 0.15, 0.0), bevel=0.02),
        t.box((0.12, 0.24, 0.28), (-0.28, -0.60, -0.22), "goldBright", rot=(0.68, 0.15, 0.0), bevel=0.015),
        t.torus(0.19, 0.030, (-0.04, -0.50, -0.10), "tealSwarm", major_seg=24, minor_seg=8, rot=(math.pi / 2 - 0.50, 0.0, 0.0)),
        t.torus(0.21, 0.034, (-0.05, -0.66, -0.22), "arcaneViolet", major_seg=24, minor_seg=10, rot=(math.pi / 2 - 0.78, 0.0, 0.0)),
        t.torus(0.17, 0.028, (-0.06, -0.72, -0.30), "goldBright", major_seg=20, minor_seg=8, rot=(math.pi / 2 - 0.78, 0.0, 0.0)),
        t.torus(0.15, 0.024, (-0.06, -0.78, -0.36), "tealSwarm", major_seg=18, minor_seg=6, rot=(math.pi / 2 - 0.78, 0.0, 0.0)),
        t.ico(0.16, (-0.06, -0.76, -0.32), "eyeNeon", subdiv=2),
        t.capsule_seg((-0.14, -0.74, -0.32), (-0.18, -0.96, -0.62), 0.065, 0.012, "tealSwarm", verts=18),
        t.capsule_seg((-0.05, -0.76, -0.34), (-0.06, -1.00, -0.66), 0.070, 0.012, "eyeNeon", verts=18),
        t.capsule_seg((0.04, -0.74, -0.32), (0.08, -0.96, -0.62), 0.065, 0.012, "arcaneViolet", verts=18),
        t.capsule_seg((0.12, -0.68, -0.28), (0.20, -0.86, -0.52), 0.055, 0.012, "goldBright", verts=16),
    ]
    p += _armor_lames(
        t,
        3,
        (-0.05, -0.10, -0.04),
        (-0.04, -0.09, 0.0),
        (0.30, 0.12, 0.30),
        (-0.04, 0.0, -0.03),
        "violet",
        trim_color="goldBright",
        rot=(0.0, 0.0, 0.22),
        bevel=0.02,
    )
    p += _rivet_ring(t, (-0.05, -0.66, -0.22), 0.22, 6, 0.038, "eyeNeon", plane="xy")
    return p


def rift_titan_leg(sx: int):
    """A5 Perna: greva blindada de obsidiana/violeta com anel de joelho e sabaton desde (0,0,0)."""
    t = Rb("rift_titan")
    p = [
        t.ball(0.32, (0.0, 0.0, 0.0), "obsidian", seg=22, rings=14),
        t.cyl(0.24, 0.44, (0.0, -0.42, 0.0), "obsidianLight", verts=24, r2=0.26),
        t.box((0.22, 0.36, 0.24), (sx * 0.08, -0.24, -0.06), "violet", bevel=0.03),
        t.torus(0.22, 0.038, (0.0, -0.44, -0.02), "gold", major_seg=22, minor_seg=8),
        t.torus(0.21, 0.032, (0.0, -0.68, -0.02), "arcaneViolet", major_seg=20, minor_seg=8),
        t.crystal(0.15, 0.38, (sx * 0.03, -0.44, -0.16), "tealSwarm", tilt=(0.52, -sx * 0.08), verts=6),
        t.cyl(0.20, 0.52, (0.0, -0.86, 0.0), "obsidian", verts=24, r2=0.23),
        t.box((0.18, 0.46, 0.14), (0.0, -0.64, -0.18), "steel", rot=(0.06, 0.0, 0.0), bevel=0.03),
        t.box((0.12, 0.38, 0.16), (sx * 0.14, -0.64, -0.06), "arcaneViolet", bevel=0.025),
        t.box((0.30, 0.20, 0.44), (0.0, -0.86, -0.06), "obsidian", bevel=0.035),
        t.crystal(0.13, 0.32, (0.0, -0.88, -0.24), "steel", tilt=(1.42, 0.0), verts=6),
    ]
    p += _armor_lames(
        t,
        2,
        (sx * 0.10, -0.16, -0.08),
        (0.0, -0.14, -0.02),
        (0.22, 0.12, 0.24),
        (-0.02, 0.0, -0.02),
        "obsidianLight",
        trim_color="goldBright",
        bevel=0.015,
    )
    p += _piston(t, (0.0, -0.24, 0.20), (0.0, -0.76, 0.18), 0.048, 0.028, "obsidian", "arcaneViolet", "gold")
    p += _rivet_ring(t, (0.0, -0.44, -0.02), 0.23, 6, 0.038, "goldBright", plane="xz")
    return p


def rift_titan():
    """Act 5 Showcase: Tita Soberano da Fenda unificado (14,800-17,600 tris)."""
    t = Rb("rift_titan")
    p = rift_titan_torso()
    p += _transform_parts(rift_titan_leg(-1), t, (-0.36, 0.94, 0.06))
    p += _transform_parts(rift_titan_leg(1), t, (0.36, 0.94, -0.10))
    p += _transform_parts(rift_titan_arm_r(), t, (0.74, 2.04, -0.02), rot_blender=(-0.18, 0.0, 0.0))
    p += _transform_parts(rift_titan_arm_l(), t, (-0.74, 1.98, -0.04), rot_blender=(0.12, 0.0, 0.0))
    return p


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
                "qualidade": "ultra",
                "hero_pbr": True,
                "quantidade_cena": 0,
                "suavizacao_normais": sn,
                "tags": ["muralha", "boss", boss_id],
                "seed": L.SEED_BASE + boss_idx * 101,
                "build": fn,
            }
        )
        kit = BOSS_KIT_BUILDERS[boss_id]
        for part_idx, part in enumerate(("torso", "arm_r", "arm_l", "leg_l", "leg_r")):
            is_torso = part == "torso"
            is_arm = part in ("arm_r", "arm_l")
            out.append(
                {
                    "id": f"boss.{boss_id}.{part}.01",
                    "name": f"BOSS_{boss_id}_{part}",
                    "glb": f"boss_{boss_id}_{part}.glb",
                    "tipo": "prop_estatico",
                    "pivot": "base" if is_torso else "origem",
                    "center_xy": is_torso,
                    "limite": LIMITE_TORSO if is_torso else (LIMITE_ARM if is_arm else LIMITE_LEG),
                    "qualidade": "hero",
                    "hero_pbr": is_torso,
                    "quantidade_cena": 1,
                    "suavizacao_normais": sn,
                    "tags": ["muralha", "boss", boss_id, part],
                    "seed": L.SEED_BASE + 9000 + len(out) * 37 + part_idx,
                    "build": kit[part],
                }
            )
    return out


L.run_group("bosses", specs(), "5 bosses esculpidos + 25 sub-malhas articuladas da campanha (art/scripts/make_bosses.py)", hero_pbr=False)
