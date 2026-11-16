"""Gera as 5 armadilhas (TRAP_) em L1..L5 com silhueta estrutural AA por nivel (Forge3D 0.9.0 spec@6).

Fonte das formas: docs/direcao-visual-e-silhuetas.md §2.1 (regra por tipo), TrapKit.luau
(cotas), VisualTheme.TRAPS (altura por tipo, cor). Pegada <= 4.8 x 4.8 studs, base 4.52 x 0.3.
Patente: mastro + 1/2/3 chevrons (>= 0,6 stud) no canto frontal-esquerdo; no piche (1,2 stud
de altura) os chevrons vao numa placa frontal para nao romper a classe de altura.

Uso headless (a esteira chama assim):
  blender -b --factory-startup --python-exit-code 1 --python art/scripts/make_traps.py
Saidas: art/export/trap_<tipo>_l<n>.glb, art/forge/lote_traps_import.yaml (gerado),
        art/renders/traps/*.png (ignorado no git)
"""

from __future__ import annotations

import math
import os
import sys

import bmesh
import bpy

sys.dont_write_bytecode = True  # sem __pycache__ em art/scripts
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lowpoly_lib as L  # noqa: E402

LIMITE = 2600  # teto Forge3D 0.9.0; alvo esculpido 1300..2400 tris por armadilha
BASE_TOP = 0.30
LEVELS = (1, 2, 3, 4, 5)


def _taper_box(w0, d0, w1, d1, h, base_center, color, y_shift_top=0.0, rot_z=0.0, bevel=0.0):
    """Prisma retangular afunilado com base em Z=base_center[2] e topo em +h."""
    cx, cy, z0 = base_center
    hw0, hd0 = w0 / 2.0, d0 / 2.0
    hw1, hd1 = w1 / 2.0, d1 / 2.0
    pts = (
        (-hw0, -hd0, 0.0),
        (hw0, -hd0, 0.0),
        (hw0, hd0, 0.0),
        (-hw0, hd0, 0.0),
        (-hw1, -hd1 + y_shift_top, h),
        (hw1, -hd1 + y_shift_top, h),
        (hw1, hd1 + y_shift_top, h),
        (-hw1, hd1 + y_shift_top, h),
    )
    c, s = math.cos(rot_z), math.sin(rot_z)
    bm = bmesh.new()
    vs = [bm.verts.new((cx + px * c - py * s, cy + px * s + py * c, z0 + pz)) for px, py, pz in pts]
    for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        bm.faces.new([vs[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    me = bpy.data.meshes.new("taper_box")
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new("taper_box", me)
    bpy.context.collection.objects.link(obj)
    if bevel > 0.0:
        return L._finish(obj, color, bevel=bevel)
    return L.paint(obj, color)


def _rivet(center, color="ironDark", size=0.085, h=0.045):
    return L.box((size, size, h), center, color)


def _gear_aa(r, thick, center, color, axis="z", teeth=6, hub=None, rim_color=None):
    """Engrenagem AA (~210 tris) com aro, dentes chanfrados e cubo central."""
    cx, cy, cz = center
    parts = []
    if axis == "z":
        parts.append(L.cyl(r, thick, (cx, cy, cz - thick / 2), color, verts=16))
        if rim_color:
            parts.append(L.torus(r * 0.70, thick * 0.30, center, rim_color, major_seg=14, minor_seg=4))
    else:
        parts.append(L.cyl_axis(r, thick, center, color, axis="x", verts=16))
        if rim_color:
            parts.append(
                L.torus(r * 0.70, thick * 0.30, center, rim_color, major_seg=14, minor_seg=4, rot=(0.0, math.pi / 2, 0.0))
            )
    tooth = (r * 0.32, r * 0.28, thick * 0.88)
    for k in range(teeth):
        a = 2 * math.pi * (k + 0.5) / teeth
        if axis == "z":
            pos = (cx + (r + tooth[1] * 0.28) * math.cos(a), cy + (r + tooth[1] * 0.28) * math.sin(a), cz)
            rot = (0.0, 0.0, a)
            size = (tooth[1], tooth[0], tooth[2])
        else:
            pos = (cx, cy + (r + tooth[1] * 0.28) * math.cos(a), cz + (r + tooth[1] * 0.28) * math.sin(a))
            rot = (a, 0.0, 0.0)
            size = (tooth[2], tooth[1], tooth[0])
        parts.append(L.box(size, pos, color, rot=rot))
    if hub:
        if axis == "z":
            parts.append(L.cyl(r * 0.34, thick * 1.45, (cx, cy, cz - thick * 0.72), hub, verts=10))
        else:
            parts.append(L.cyl_axis(r * 0.34, thick * 1.45, center, hub, axis="x", verts=10))
    return parts


def _spoked_wheel_aa(r, thick, center, tire_color, hub_color, spokes=6, rim_color="woodDark"):
    """Roda raiada AA (~200 tris): aro em torus 16x4, cubo escalonado e raios diagonais."""
    cx, cy, cz = center
    rot_y = (0.0, math.pi / 2, 0.0)
    parts = [
        L.torus(r - 0.085, 0.085, center, tire_color, major_seg=16, minor_seg=4, rot=rot_y),
        L.cyl_axis(r * 0.27, thick * 1.18, center, hub_color, axis="x", verts=10),
        L.cyl_axis(r * 0.14, thick * 1.38, center, tire_color, axis="x", verts=8),
    ]
    n_pairs = max(2, spokes // 2)
    spoke_len = (r - 0.13) * 2.0
    for k in range(n_pairs):
        ang = math.pi * k / n_pairs
        parts.append(L.box((thick * 0.44, 0.085, spoke_len), (cx, cy, cz), rim_color, rot=(ang, 0.0, 0.0)))
    return parts


def base(lvl):
    """Plinto chanfrado de dois degraus com cantoneiras, rebites e frisos (pegada <= 4.74)."""
    p = [
        L.box((4.52, 4.52, 0.18), (0.0, 0.0, 0.09), "stone", bevel=0.04),
        L.box((4.24, 4.24, 0.14), (0.0, 0.0, 0.23), "stoneDark" if lvl < 3 else "stoneLight"),
    ]
    cap_col = "woodDark" if lvl == 1 else ("iron" if lvl == 2 else ("brass" if lvl == 3 else "gold"))
    riv_col = "ironDark" if lvl < 4 else "goldBright"
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = sx * 1.90, sy * 1.90
            p.append(_taper_box(0.62, 0.62, 0.54, 0.54, 0.36, (cx, cy, 0.0), cap_col))
            p.append(_rivet((cx - sx * 0.14, cy - sy * 0.14, 0.37), riv_col, size=0.085, h=0.04))
    if lvl >= 2:
        p.append(L.box((2.8, 0.10, 0.12), (0.0, -2.21, 0.15), "iron" if lvl == 2 else "gold"))
    if lvl >= 3:
        p.append(L.box((2.3, 0.12, 0.14), (0.30, -2.23, 0.18), "gold"))
        p.append(L.box((0.10, 3.1, 0.12), (2.19, 0.0, 0.17), "brass"))
    if lvl >= 4:
        p.append(L.box((0.10, 3.1, 0.13), (-2.19, 0.0, 0.17), "goldBright"))
        p.append(L.box((3.1, 0.10, 0.11), (0.0, 2.20, 0.17), "gold"))
    if lvl >= 5:
        for sx in (-1, 1):
            for sy in (-1, 1):
                p.append(L.spike(0.14, 0.24, (sx * 1.90, sy * 1.90, 0.36), "goldBright", verts=6))
    return p


# ---------------------------------------------------------------- arqueiro (~5.2..5.5)
def archer(lvl):
    p = base(lvl)
    post_h = 3.28 if lvl < 3 else 2.75
    top = BASE_TOP + post_h
    pillar_col = "wood" if lvl < 4 else "woodDark"
    trim_col = "iron" if lvl < 4 else "gold"

    for sx in (-1, 1):
        for sy in (-1, 1):
            px, py = sx * 1.00, sy * 1.00
            p.append(_taper_box(0.40, 0.40, 0.32, 0.32, post_h, (px, py, BASE_TOP), pillar_col))
            p.append(L.box((0.46, 0.46, 0.20), (px, py, BASE_TOP + 0.10), "ironDark"))
            p.append(L.box((0.16, 0.56, 0.18), (px, py * 1.18, top - 0.18), "woodDark", rot=(sy * 0.55, 0.0, 0.0)))
    for sy in (-1.08, 1.08):
        for ang in (0.62, -0.62):
            p.append(L.box((2.32, 0.12, 0.18), (0.0, sy, BASE_TOP + post_h * 0.42), "woodDark", rot=(0.0, ang, 0.0)))
        p.append(L.box((0.26, 0.18, 0.26), (0.0, sy, BASE_TOP + post_h * 0.42), trim_col))

    p.append(L.box((3.02, 3.02, 0.28), (0.0, 0.0, top + 0.14), "woodLight", bevel=0.04))
    deck = top + 0.28

    if lvl == 1:
        for sy in (-1.38, 1.38):
            p.append(L.box((2.92, 0.14, 0.14), (0.0, sy, deck + 0.54), "woodDark"))
            p.append(L.box((2.92, 0.10, 0.12), (0.0, sy, deck + 0.26), "wood"))
        for sx in (-1.38, 1.38):
            p.append(L.box((0.14, 2.92, 0.14), (sx, 0.0, deck + 0.54), "woodDark"))
        for sx in (-1.38, 1.38):
            for sy in (-1.38, 1.38):
                p.append(L.box((0.18, 0.18, 0.62), (sx, sy, deck + 0.31), "wood"))
    else:
        for sy in (-1.40, 1.40):
            p.append(L.box((2.96, 0.18, 0.62), (0.0, sy, deck + 0.31), "wood"))
        for sx in (-1.40, 1.40):
            p.append(L.box((0.18, 2.96, 0.62), (sx, 0.0, deck + 0.31), "wood"))
        for x in (-0.80, 0.80):
            p.append(L.box((0.64, 0.11, 0.52), (x, -1.50, deck + 0.32), "iron"))
            p.append(_rivet((x, -1.56, deck + 0.44), "brass", size=0.075, h=0.04))
        p.append(L.box((0.11, 0.64, 0.52), (-1.50, 0.0, deck + 0.32), "iron"))
        if lvl >= 3:
            p.append(L.box((3.06, 0.12, 0.12), (0.0, -1.50, deck + 0.64), "ironDark"))
            p.append(L.box((0.12, 3.06, 0.12), (-1.50, 0.0, deck + 0.64), "ironDark"))

    # Arqueiro AA: tunica, cinto, manto, aljava com flechas emplumadas, capuz e arco recurvo
    p.append(L.cyl(0.30, 0.68, (0.0, 0.15, deck), "archer", verts=12, r2=0.22))
    p.append(L.cyl(0.29, 0.12, (0.0, 0.15, deck + 0.28), "woodDark", verts=12, r2=0.28))
    p.append(L.box((0.12, 0.08, 0.12), (0.0, -0.14, deck + 0.34), "gold"))
    p.append(L.cyl(0.36, 0.44, (0.0, 0.24, deck + 0.32), "archerDark", verts=10, r2=0.18))
    p.append(L.cyl(0.095, 0.52, (0.24, 0.36, deck + 0.34), "woodDark", verts=8))
    for afx, afy in ((0.20, 0.34), (0.27, 0.38)):
        p.append(L.capsule_seg((afx, afy, deck + 0.72), (afx + 0.03, afy + 0.04, deck + 1.04), 0.025, 0.02, "parchment", verts=6))
        p.append(L.box((0.06, 0.04, 0.10), (afx + 0.03, afy + 0.04, deck + 1.02), "danger"))
    p.append(L.ball(0.24, (0.0, 0.15, deck + 0.94), "parchment", seg=10, rings=6))
    p.append(L.cyl(0.31, 0.38, (0.0, 0.18, deck + 0.92), "archerDark", verts=10, r2=0.08))
    p.append(L.crystal(0.13, 0.30, (0.0, 0.28, deck + 1.18), "archerDark", tilt=(-0.72, 0.0), verts=6))
    p.append(L.capsule_seg((0.40, -0.18, deck + 0.78), (0.44, -0.02, deck + 1.24), 0.045, 0.03, "woodDark", verts=6))
    p.append(L.capsule_seg((0.40, -0.18, deck + 0.78), (0.44, -0.02, deck + 0.32), 0.045, 0.03, "woodDark", verts=6))
    p.append(L.capsule_seg((0.42, -0.18, deck + 0.78), (0.32, -0.60, deck + 0.80), 0.024, 0.018, "gold", verts=6))

    # Besta de torcao no parapeito frontal com virote emplumado
    bx = -0.68
    p.append(L.box((0.20, 0.94, 0.18), (bx, -1.55, deck + 0.74), "woodDark"))
    p.append(L.box((0.26, 0.20, 0.14), (bx, -1.94, deck + 0.74), "brass"))
    for sx in (-1, 1):
        p.append(L.capsule_seg((bx + sx * 0.08, -1.94, deck + 0.78), (bx + sx * 0.44, -1.82, deck + 0.79), 0.055, 0.042, "iron", verts=6))
        p.append(L.capsule_seg((bx + sx * 0.44, -1.82, deck + 0.79), (bx + sx * 0.64, -1.58, deck + 0.78), 0.042, 0.026, "steel", verts=6))
        p.append(L.capsule_seg((bx + sx * 0.64, -1.58, deck + 0.78), (bx, -1.32, deck + 0.80), 0.02, 0.02, "parchment", verts=6))
    p.append(L.capsule_seg((bx, -1.36, deck + 0.84), (bx, -2.14, deck + 0.84), 0.025, 0.02, "woodLight", verts=6))
    p.append(L.crystal(0.052, 0.16, (bx, -2.12, deck + 0.84), "steel", tilt=(math.pi / 2, 0.0), verts=4))
    p.append(L.box((0.11, 0.12, 0.04), (bx, -1.44, deck + 0.84), "danger"))

    if lvl >= 3:
        roof_z = deck + 1.22
        for sx in (-1.30, 1.30):
            for sy in (-1.30, 1.30):
                p.append(L.box((0.14, 0.14, roof_z - deck), (sx, sy, deck + (roof_z - deck) / 2), "woodDark"))
        p.append(L.cyl(2.22, 0.68, (0.0, 0.0, roof_z), "roof", verts=18, r2=0.0))
        p.append(
            L.torus(
                1.98,
                0.08,
                (0.0, 0.0, roof_z + 0.04),
                "gold" if lvl >= 4 else "woodDark",
                major_seg=18,
                minor_seg=4,
            )
        )
        p.append(L.ball(0.14, (0.0, 0.0, roof_z + 0.70), "gold", seg=8, rings=4))
        p.append(L.cyl(0.058, 2.25, (-1.62, 0.90, deck - 0.52), "ironDark", verts=8))
        p.append(L.box((0.08, 0.90, 1.10), (-1.62, 0.42, deck + 1.10), "danger"))
        p.append(L.box((0.10, 0.40, 0.40), (-1.65, 0.42, deck + 1.10), "gold", rot=(math.pi / 4, 0.0, 0.0)))
    else:
        p.append(L.torus(1.48, 0.06, (0.0, 0.0, BASE_TOP + 0.06), "iron" if lvl == 2 else "woodDark", major_seg=18, minor_seg=4))
        p.append(L.cyl(0.055, 1.05, (1.38, 1.38, deck + 0.20), "ironDark", verts=8))
        p.append(L.box((0.06, 0.54, 0.34), (1.38, 1.10, deck + 1.08), "archer"))

    if lvl >= 4:
        p.append(L.box((3.02, 0.13, 0.56), (0.0, -1.52, deck + 0.32), "iron"))
        p += _gear_aa(
            0.44,
            0.12,
            (1.22, 0.0, BASE_TOP + 1.90),
            "iron" if lvl == 4 else "gold",
            axis="x",
            teeth=6,
            hub="gold" if lvl == 4 else "neonAmber",
            rim_color="brass",
        )
        p.append(L.spike(0.12, 0.32, (0.0, 0.0, deck + 1.90), "gold", verts=6))

    if lvl >= 5:
        p.append(L.box((0.92, 0.92, 0.70), (1.02, 1.02, deck + 0.35), "iron"))
        p.append(L.cyl(0.75, 0.52, (1.02, 1.02, deck + 0.70), "roof", verts=12, r2=0.0))
        p.append(L.torus(0.70, 0.055, (1.02, 1.02, deck + 0.70), "goldBright", major_seg=12, minor_seg=4))
        for sy in (-1.60, 1.60):
            p.append(L.box((3.16, 0.09, 0.11), (0.0, sy, deck + 1.26), "goldBright"))
    return p + L.rank_mast(lvl)


# ---------------------------------------------------------------- piche (~1.05..1.24)
def tar(lvl):
    p = base(lvl)
    p.append(L.cyl(2.02, 0.50, (0.0, 0.0, BASE_TOP), "stoneDark", verts=22, r2=2.10))
    p.append(L.cyl(1.86, 0.08, (0.0, 0.0, BASE_TOP + 0.48), "ink", verts=22))
    rim = "stoneDark" if lvl == 1 else ("iron" if lvl < 4 else "brass")
    p.append(L.torus(1.96, 0.135, (0.0, 0.0, BASE_TOP + 0.54), rim, major_seg=22, minor_seg=5))

    p.append(L.cyl(2.12, 0.15, (0.0, 0.0, BASE_TOP + 0.17), "iron" if lvl >= 2 else "stone", verts=22))
    for k in range(8):
        a = 2 * math.pi * k / 8 + 0.2
        p.append(L.spike(0.085, 0.10, (2.13 * math.cos(a), 2.13 * math.sin(a), BASE_TOP + 0.22), "ironDark", verts=5))

    # Grelha de ferro fundido + aro interno
    p.append(L.torus(1.22, 0.042, (0.0, 0.0, BASE_TOP + 0.53), "ironDark", major_seg=16, minor_seg=4))
    for gx in (-0.92, -0.32, 0.32, 0.92):
        bar_len = 2.0 * math.sqrt(max(0.4, 1.80 * 1.80 - gx * gx))
        p.append(L.box((0.08, bar_len, 0.06), (gx, 0.0, BASE_TOP + 0.53), "ironDark"))
    p.append(L.box((3.50, 0.10, 0.07), (0.0, 0.0, BASE_TOP + 0.54), "iron"))

    # Bolhas de piche + anel de estalo
    bubbles = ((-0.66, -0.34, 0.25), (0.58, 0.36, 0.24), (0.04, 0.74, 0.20), (-0.42, 0.52, 0.16))
    for idx, (x, y, br) in enumerate(bubbles):
        p.append(L.ball(br, (x, y, BASE_TOP + 0.55), "tarGlow" if idx < 3 else "tarDeep", seg=12, rings=5, squash=(1.0, 1.0, 0.72)))
    p.append(L.torus(0.36, 0.032, (-0.66, -0.34, BASE_TOP + 0.55), "tarGlow", major_seg=12, minor_seg=4))

    # Valvula lateral de escoamento
    p.append(L.cyl_axis(0.16, 0.34, (2.02, 0.0, BASE_TOP + 0.34), "iron", axis="x", verts=10))
    p.append(L.torus(0.18, 0.04, (2.18, 0.0, BASE_TOP + 0.34), "brass" if lvl >= 2 else "ironDark", major_seg=10, minor_seg=4, rot=(0.0, math.pi / 2, 0.0)))

    if lvl >= 3:
        p += _gear_aa(
            0.88,
            0.08,
            (0.0, 0.0, BASE_TOP + 0.57),
            "ironDark" if lvl < 5 else "gold",
            teeth=6,
            hub="gold" if lvl < 5 else "neonAmber",
            rim_color="brass",
        )
        p.append(L.torus(2.14, 0.055, (0.0, 0.0, BASE_TOP + 0.38), "goldBright" if lvl >= 5 else "gold", major_seg=18, minor_seg=4))
    if lvl >= 4:
        for k in range(6):
            a = 2 * math.pi * k / 6 + 0.26
            p.append(L.spike(0.12, 0.24, (1.94 * math.cos(a), 1.94 * math.sin(a), BASE_TOP + 0.65), "gold", verts=6))
    if lvl >= 5:
        p.append(L.torus(1.48, 0.048, (0.0, 0.0, BASE_TOP + 0.57), "goldBright", major_seg=16, minor_seg=4))

    p.append(L.box((2.60, 0.28, 0.50), (0.0, -2.06, BASE_TOP + 0.25), "woodDark", bevel=0.03))
    p.append(L.box((2.68, 0.08, 0.08), (0.0, -2.18, BASE_TOP + 0.49), "brass" if lvl >= 2 else "iron"))
    return p + L.rank_row(lvl, y=-2.28, z=BASE_TOP + 0.30)


# ---------------------------------------------------------------- gelo (~4.35..4.55)
def frost(lvl):
    p = base(lvl)
    # GDD HSV: Defensor NUNCA usa 160..195 deg (usar ice/iceLight/iceGlow/royal > 195 deg).
    p.append(L.box((4.00, 4.00, 0.11), (0.0, 0.0, BASE_TOP + 0.055), "iceLight", bevel=0.035))
    p.append(L.cyl(1.40, 0.24, (0.0, 0.0, BASE_TOP + 0.08), "stoneDark", verts=18, r2=1.20))
    p.append(L.cyl(1.00, 0.24, (0.0, 0.0, BASE_TOP + 0.30), "obsidian" if lvl >= 3 else "iron", verts=18, r2=0.84))
    p.append(L.torus(1.20, 0.065, (0.0, 0.0, BASE_TOP + 0.30), "iron" if lvl < 4 else "gold", major_seg=18, minor_seg=5))

    for k in range(4):
        ang = math.pi / 4 + k * math.pi / 2
        p.append(
            _taper_box(
                0.32,
                0.50,
                0.20,
                0.24,
                0.58,
                (1.14 * math.cos(ang), 1.14 * math.sin(ang), BASE_TOP + 0.08),
                "ironDark" if lvl < 3 else "steel",
                rot_z=ang + math.pi / 2,
            )
        )
        p.append(L.ico(0.11, (1.44 * math.cos(ang), 1.44 * math.sin(ang), BASE_TOP + 0.22), "iceGlow", subdiv=1))
    for k in range(8):
        a = 2 * math.pi * k / 8
        col = "iceGlow" if k % 2 == 0 else "royal"
        p.append(L.crystal(0.12, 0.32, (1.32 * math.cos(a), 1.32 * math.sin(a), BASE_TOP + 0.18), col, tilt=(-0.36 * math.sin(a), 0.36 * math.cos(a)), verts=6))

    z0 = BASE_TOP + 0.50
    p.append(L.crystal(0.60, 2.98, (0.0, 0.0, z0), "ice", verts=6, r2=0.33, spin=math.pi / 6))
    p.append(L.crystal(0.34, 0.80, (0.0, 0.0, z0 + 2.96), "iceLight", verts=6, spin=math.pi / 6))
    p.append(L.torus(0.58, 0.068, (0.0, 0.0, z0 + 0.65), "iron" if lvl < 4 else "brass", major_seg=18, minor_seg=5))
    p.append(L.torus(0.52, 0.055, (0.0, 0.0, z0 + 1.36), "royal" if lvl >= 2 else "iceGlow", major_seg=16, minor_seg=4))
    p.append(L.torus(0.76, 0.045, (0.0, 0.0, z0 + 0.14), "iceLight", major_seg=16, minor_seg=4))
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.4
        px, py = 0.78 * math.cos(a), 0.78 * math.sin(a)
        p.append(
            L.crystal(
                0.31,
                1.76,
                (px, py, z0 - 0.06),
                "ice",
                tilt=(-0.22 * math.sin(a), 0.22 * math.cos(a)),
                verts=6,
            )
        )
        p.append(L.ico(0.14, (px * 1.16, py * 1.16, z0 + 0.22), "iceLight", subdiv=1))
        p.append(L.crystal(0.14, 0.56, (-px * 1.10, -py * 1.10, z0 - 0.04), "iceGlow", tilt=(0.35 * math.sin(a), -0.35 * math.cos(a)), verts=5))

    if lvl >= 2:
        for sx in (-1, 1):
            p.append(L.crystal(0.32, 2.08, (sx * 1.04, -0.18, z0 - 0.05), "iceLight", tilt=(0.12, sx * 0.28), verts=6))
        p.append(L.cyl(0.66, 0.22, (0.0, 0.0, z0 + 1.18), "iron", verts=16))

    if lvl >= 3:
        p.append(L.torus(1.16, 0.075, (0.0, 0.0, z0 + 1.66), "iceGlow", major_seg=18, minor_seg=5, rot=(0.44, 0.0, 0.0)))
        for ang in (0.0, math.pi / 2, math.pi, 3 * math.pi / 2):
            gx = 1.16 * math.cos(ang)
            gy = 1.16 * math.sin(ang) * math.cos(0.44)
            gz = z0 + 1.66 + 1.16 * math.sin(ang) * math.sin(0.44)
            p.append(L.ico(0.12, (gx, gy, gz), "royal", subdiv=1))
        for k in range(4):
            a = 2 * math.pi * k / 4 + 0.35
            p.append(
                L.crystal(
                    0.13,
                    0.72,
                    (0.46 * math.cos(a), 0.46 * math.sin(a), z0 + 2.38),
                    "iceGlow",
                    tilt=(-0.44 * math.sin(a), 0.44 * math.cos(a)),
                    verts=6,
                )
            )

    if lvl >= 4:
        p.append(L.torus(1.02, 0.07, (0.0, 0.0, z0 + 1.88), "gold", major_seg=16, minor_seg=4, rot=(0.0, -0.52, 0.0)))
        p.append(L.ico(0.13, (0.0, -1.04, z0 + 1.50), "iceGlow", subdiv=1))
        p.append(L.ico(0.13, (0.0, 1.04, z0 + 1.84), "iceLight", subdiv=1))

    if lvl >= 5:
        p.append(L.torus(1.38, 0.055, (0.0, 0.0, z0 + 0.44), "goldBright", major_seg=16, minor_seg=4))
        p.append(L.torus(0.48, 0.042, (0.0, 0.0, z0 + 2.94), "goldBright", major_seg=12, minor_seg=4))

    return p + L.rank_mast(lvl)


# ---------------------------------------------------------------- canhao (~3.05..3.30)
def cannon(lvl):
    p = base(lvl)
    p.append(_taper_box(1.56, 2.95, 1.38, 2.55, 0.50, (0.0, 0.16, BASE_TOP + 0.36), "wood"))
    p.append(L.box((1.58, 0.38, 0.24), (0.0, -1.16, BASE_TOP + 0.56), "ironDark"))
    for sx in (-1, 1):
        p.append(L.box((0.26, 2.24, 0.56), (sx * 0.64, 0.26, BASE_TOP + 1.02), "woodDark"))
        p.append(L.box((0.26, 1.48, 0.42), (sx * 0.64, -0.10, BASE_TOP + 1.46), "wood"))
        p.append(L.box((0.30, 0.36, 0.18), (sx * 0.64, -0.26, BASE_TOP + 1.72), "ironDark"))
        p.append(_rivet((sx * 0.64, -0.36, BASE_TOP + 1.82), "brass", size=0.075, h=0.04))
        p += _spoked_wheel_aa(0.68, 0.26, (sx * 1.04, -0.55, BASE_TOP + 0.68), "ironDark", "iron", spokes=6)
        p.append(L.cyl_axis(0.40, 0.24, (sx * 0.96, 1.14, BASE_TOP + 0.40), "ironDark", axis="x", verts=10))
        p.append(L.cyl_axis(0.28, 0.28, (sx * 0.96, 1.14, BASE_TOP + 0.40), "woodDark", axis="x", verts=8))

    tilt = 0.22
    c = (0.0, -0.28, BASE_TOP + 1.96)
    d = (0.0, -math.cos(tilt), math.sin(tilt))
    barrel_rot = (math.pi / 2 - tilt, 0.0, 0.0)

    def along(t):
        return (c[0] + d[0] * t, c[1] + d[1] * t, c[2] + d[2] * t)

    barrel = "iron" if lvl == 1 else "steel"
    p.append(L.cyl_axis(0.45, 2.86, c, barrel, axis="y", verts=18, r2=0.35, tilt=tilt))
    p.append(L.cyl_axis(0.36, 0.34, along(1.32), "ironDark", axis="y", verts=18, r2=0.50, tilt=tilt))
    p.append(L.cyl_axis(0.14, 1.48, along(-0.02), "ironDark", axis="x", verts=8))
    p.append(L.ball(0.43, along(-1.44), barrel, seg=10, rings=4))
    p.append(L.ball(0.20, along(-1.88), "ironDark" if lvl < 4 else "gold", seg=8, rings=4))
    for t_ring, r_ring, col_ring in ((-0.36, 0.44, "ironDark"), (0.48, 0.40, "brass" if lvl >= 2 else "ironDark"), (1.16, 0.37, "ironDark")):
        p.append(L.torus(r_ring, 0.055, along(t_ring), col_ring, major_seg=12, minor_seg=4, rot=barrel_rot))

    fuse_base = along(-1.12)
    p.append(L.cyl(0.08, 0.14, (fuse_base[0], fuse_base[1], fuse_base[2] + 0.36), "brass", verts=6))
    p.append(L.capsule_seg((fuse_base[0], fuse_base[1], fuse_base[2] + 0.48), (fuse_base[0] + 0.14, fuse_base[1] + 0.18, fuse_base[2] + 0.72), 0.028, 0.022, "woodDark", verts=6))
    p.append(L.ico(0.09, (fuse_base[0] + 0.15, fuse_base[1] + 0.20, fuse_base[2] + 0.74), "amberBright", subdiv=0))

    if lvl >= 2:
        for sx in (-1, 1):
            p.append(L.box((0.08, 1.44, 0.56), (sx * 0.78, 0.0, BASE_TOP + 1.22), "iron"))
            p.append(_rivet((sx * 0.83, -0.45, BASE_TOP + 1.36), "brass", size=0.07, h=0.035))
        p.append(L.box((0.76, 0.46, 0.12), (0.0, -1.52, BASE_TOP + 0.06), "woodDark"))
        for bx in (-0.18, 0.18):
            p.append(L.ball(0.16, (bx, -1.52, BASE_TOP + 0.24), "ironDark", seg=8, rings=4))
        p.append(L.ball(0.16, (0.0, -1.52, BASE_TOP + 0.46), "ironDark", seg=8, rings=4))

    if lvl >= 3:
        p.append(L.box((1.00, 0.70, 0.14), (0.86, 1.38, BASE_TOP + 0.07), "woodDark"))
        for dx in (-0.25, 0.25):
            kx, ky = 0.86 + dx, 1.38
            p.append(L.cyl(0.21, 0.56, (kx, ky, BASE_TOP + 0.14), "wood", verts=8))
            p.append(L.cyl(0.22, 0.06, (kx, ky, BASE_TOP + 0.26), "ironDark", verts=8))
            p.append(L.cyl(0.22, 0.06, (kx, ky, BASE_TOP + 0.56), "ironDark", verts=8))
        sight = along(-0.56)
        p.append(L.box((0.10, 0.10, 0.58), (sight[0], sight[1], sight[2] + 0.58), "bronze"))
        p.append(L.torus(0.14, 0.035, (sight[0], sight[1], sight[2] + 0.94), "gold", major_seg=8, minor_seg=4, rot=(math.pi / 2, 0.0, 0.0)))

    if lvl >= 4:
        p += _gear_aa(
            0.38,
            0.10,
            (-0.82, 0.94, BASE_TOP + 1.34),
            "iron" if lvl == 4 else "gold",
            axis="x",
            teeth=5,
            hub="gold" if lvl == 4 else "neonAmber",
        )

    if lvl >= 5:
        p.append(L.cyl_axis(0.51, 0.14, along(1.42), "goldBright", axis="y", verts=12, tilt=tilt))
        p.append(L.cyl_axis(0.47, 0.12, along(-1.04), "goldBright", axis="y", verts=12, tilt=tilt))

    return p + L.rank_mast(lvl)


# ---------------------------------------------------------------- catapulta (~4.75..5.05)
def catapult(lvl):
    p = base(lvl)
    for sx in (-1, 1):
        p.append(L.box((0.36, 3.80, 0.44), (sx * 1.05, 0.0, BASE_TOP + 0.78), "wood"))
        p.append(L.box((0.40, 0.52, 0.48), (sx * 1.05, -1.15, BASE_TOP + 0.78), "ironDark"))
    for sy in (-1.60, 1.60):
        p.append(L.box((2.50, 0.36, 0.38), (0.0, sy, BASE_TOP + 0.80), "woodDark"))

    for sx in (-1, 1):
        p += _spoked_wheel_aa(0.60, 0.26, (sx * 1.38, -1.15, BASE_TOP + 0.60), "ironDark", "iron", spokes=6)
        p.append(L.torus(0.50, 0.075, (sx * 1.38, 1.15, BASE_TOP + 0.57), "ironDark", major_seg=10, minor_seg=4, rot=(0.0, math.pi / 2, 0.0)))
        p.append(L.cyl_axis(0.46, 0.24, (sx * 1.38, 1.15, BASE_TOP + 0.57), "woodDark", axis="x", verts=10))

    pivot = (0.0, -0.30, BASE_TOP + 2.08)
    for sx in (-1, 1):
        p.append(_taper_box(0.38, 0.38, 0.28, 0.28, 1.54, (sx * 0.82, pivot[1], BASE_TOP + 0.60), "wood"))
        p.append(L.box((0.22, 1.42, 0.22), (sx * 0.82, pivot[1] + 0.42, BASE_TOP + 1.45), "woodDark", rot=(0.80, 0.0, 0.0)))
    p.append(L.cyl_axis(0.13, 1.98, pivot, "iron", axis="x", verts=8))

    for sx, tilt_x in ((-0.42, 0.35), (0.42, -0.35)):
        p.append(L.torus(0.26, 0.08, (sx, pivot[1], pivot[2]), "straw", major_seg=10, minor_seg=4, rot=(tilt_x, math.pi / 2, 0.0)))
        p.append(L.torus(0.28, 0.045, (sx * 1.45, pivot[1], pivot[2]), "ironDark", major_seg=8, minor_seg=4, rot=(0.0, math.pi / 2, 0.0)))

    a = math.radians(55)
    d = (0.0, math.cos(a), math.sin(a))
    arm_len = 2.85
    mid = (0.0, pivot[1] + d[1] * (arm_len / 2 - 0.35), pivot[2] + d[2] * (arm_len / 2 - 0.35))
    p.append(L.box((0.30, arm_len, 0.28), mid, "wood", rot=(a, 0.0, 0.0)))
    for bt in (0.45, 1.35):
        bp = (0.0, pivot[1] + d[1] * bt, pivot[2] + d[2] * bt)
        p.append(L.box((0.34, 0.14, 0.32), bp, "ironDark", rot=(a, 0.0, 0.0)))

    tip = (0.0, pivot[1] + d[1] * 2.35, pivot[2] + d[2] * 2.35)
    p.append(L.cyl(0.46, 0.38, (tip[0], tip[1], tip[2] - 0.05), "woodDark", verts=10, r2=0.58))
    p.append(L.torus(0.56, 0.065, (tip[0], tip[1], tip[2] + 0.30), "iron", major_seg=10, minor_seg=4))
    p.append(L.ico(0.32, (tip[0], tip[1], tip[2] + 0.34), "stoneLight", subdiv=1))
    p.append(L.ico(0.19, (tip[0] - 0.14, tip[1] - 0.12, tip[2] + 0.44), "ember", subdiv=1))
    p.append(L.ico(0.14, (tip[0] + 0.14, tip[1] + 0.10, tip[2] + 0.40), "danger", subdiv=0))

    cw_z = pivot[2] - 0.64
    if lvl == 1:
        p.append(_taper_box(0.84, 0.84, 0.68, 0.68, 0.68, (0.0, pivot[1] - 0.32, cw_z - 0.34), "stoneDark"))
    else:
        for sx in (-1, 1):
            p.append(L.box((0.56, 0.72, 0.70), (sx * 0.36, pivot[1] - 0.32, cw_z), "ironDark"))
        for sx in (-1, 1):
            for sy in (-1.60, 1.60):
                p.append(L.box((0.44, 0.44, 0.52), (sx * 1.05, sy, BASE_TOP + 0.82), "iron"))
    p.append(L.box((0.08, 0.50, 0.30), (0.0, tip[1] - 0.25, tip[2] - 0.35), "catapult"))

    p.append(L.cyl_axis(0.20, 1.78, (0.0, 1.10, BASE_TOP + 1.02), "woodDark", axis="x", verts=8))
    for rx in (-0.28, 0.0, 0.28):
        p.append(L.cyl_axis(0.23, 0.14, (rx, 1.10, BASE_TOP + 1.02), "straw", axis="x", verts=8))

    if lvl >= 3:
        for sx in (-1, 1):
            p.append(L.box((0.26, 0.26, 2.20), (sx * 0.95, -1.75, BASE_TOP + 1.95), "woodDark"))
        p.append(L.box((2.32, 0.30, 0.30), (0.0, -1.75, BASE_TOP + 3.00), "ironDark"))
        for x in (-0.70, 0.0, 0.70):
            p.append(L.spike(0.15, 0.45 if x == 0 else 0.32, (x, -1.75, BASE_TOP + 3.12), "gold", verts=6))
        p += _gear_aa(0.32, 0.09, (-1.18, 1.10, BASE_TOP + 1.02), "iron", axis="x", teeth=5, hub="brass")

    if lvl >= 4:
        p += _gear_aa(
            0.50,
            0.12,
            (1.06, pivot[1], pivot[2]),
            "iron" if lvl == 4 else "gold",
            axis="x",
            teeth=5,
            hub="gold" if lvl == 4 else "neonAmber",
        )

    if lvl >= 5:
        for sx in (-1, 1):
            p.append(L.box((0.11, 3.60, 0.09), (sx * 1.05, 0.0, BASE_TOP + 1.05), "goldBright"))
        p.append(L.ico(0.16, (tip[0], tip[1], tip[2] + 0.56), "neonAmber", subdiv=0))

    return p + L.rank_mast(lvl)


BUILDERS = {"archer": archer, "tar": tar, "frost": frost, "cannon": cannon, "catapult": catapult}


def specs():
    out = []
    for k, (kind, fn) in enumerate(BUILDERS.items()):
        for lvl in LEVELS:
            seed = L.SEED_BASE + (k * 3 + lvl - 1) * 101 if lvl <= 3 else L.SEED_BASE + 5000 + k * 10 + lvl
            out.append(
                {
                    "id": f"trap.{kind}.l{lvl}.01",
                    "name": f"TRAP_{kind}_l{lvl}",
                    "glb": f"trap_{kind}_l{lvl}.glb",
                    "tipo": "prop_estatico",
                    "limite": LIMITE,
                    "hero_pbr": False,
                    "quantidade_cena": 4,
                    "tags": ["muralha", "trap", kind, f"l{lvl}"],
                    "seed": seed,
                    "build": (lambda f=fn, n=lvl: f(n)),
                }
            )
    return out


L.run_group("traps", specs(), "armadilhas L1-L5 AA (art/scripts/make_traps.py)", hero_pbr=False)
