"""Gera 7 modelos low-poly AA esculpidos para o vale de fundo (BACKDROP_), com Castelos Hero PBR
de alta densidade arquitetonica e props de vila/natureza refinados (Forge3D 0.9.0 Two-Tier PBR).

Modelos (Z-up, frente=-Y, base Z=0, centrados em XY):
  1. backdrop.castle01.01   -> BACKDROP_castle01   (backdrop_castle01.glb,   ~18 studs, Hero PBR, 8.5k-11.5k tris)
  2. backdrop.keep01.01     -> BACKDROP_keep01     (backdrop_keep01.glb,     ~20 studs, Hero PBR, 8.5k-11.5k tris)
  3. backdrop.house01.01    -> BACKDROP_house01    (backdrop_house01.glb,    ~8 studs,  Tier-A,   2.6k-3.6k tris)
  4. backdrop.house02.01    -> BACKDROP_house02    (backdrop_house02.glb,    ~8 studs,  Tier-A,   2.6k-3.6k tris)
  5. backdrop.tower01.01    -> BACKDROP_tower01    (backdrop_tower01.glb,    ~16 studs, Tier-A,   2.6k-3.6k tris)
  6. backdrop.windmill01.01 -> BACKDROP_windmill01 (backdrop_windmill01.glb, ~16 studs, Tier-A,   2.6k-3.6k tris)
  7. backdrop.tree01.01     -> BACKDROP_tree01     (backdrop_tree01.glb,     ~11 studs, Tier-A,   1.5k-1.85k tris)

Uso headless:
  blender -b --factory-startup --python-exit-code 1 --python art/scripts/make_backdrop.py
Saidas: art/export/backdrop_*.glb, art/forge/lote_backdrop_import.yaml, art/renders/backdrop/*.png
"""

from __future__ import annotations

import math
import os
import sys

import bmesh
import bpy

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lowpoly_lib as L  # noqa: E402

LIMITE_HERO = 12000
LIMITE_PROP = 3800
LIMITE_TREE = 2000

NORMALS_BACKDROP = {
    "modo": "hard_surface",
    "angulo_graus": 46,
    "weighted_normals": True,
    "corrective_smooth": False,
}


def _rot(obj, rx=0.0, ry=0.0, rz=0.0):
    obj.rotation_euler = (rx, ry, rz)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    return obj


def _from_bm(bm, name, color):
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    return L.paint(obj, color)


def _pitched_roof(w, d, h, base_center, color, ridge_axis="y"):
    """Prisma triangular manifold (telhado de duas aguas) com base em base_center=(cx, cy, z0)."""
    cx, cy, z0 = base_center
    hw, hd = w * 0.5, d * 0.5
    bm = bmesh.new()
    if ridge_axis == "y":
        v0 = bm.verts.new((cx - hw, cy - hd, z0))
        v1 = bm.verts.new((cx + hw, cy - hd, z0))
        v2 = bm.verts.new((cx, cy - hd, z0 + h))
        v3 = bm.verts.new((cx - hw, cy + hd, z0))
        v4 = bm.verts.new((cx + hw, cy + hd, z0))
        v5 = bm.verts.new((cx, cy + hd, z0 + h))
    else:
        v0 = bm.verts.new((cx - hw, cy - hd, z0))
        v1 = bm.verts.new((cx - hw, cy + hd, z0))
        v2 = bm.verts.new((cx - hw, cy, z0 + h))
        v3 = bm.verts.new((cx + hw, cy - hd, z0))
        v4 = bm.verts.new((cx + hw, cy + hd, z0))
        v5 = bm.verts.new((cx + hw, cy, z0 + h))
    bm.faces.new((v0, v1, v2))
    bm.faces.new((v4, v3, v5))
    bm.faces.new((v0, v3, v4, v1))
    bm.faces.new((v0, v2, v5, v3))
    bm.faces.new((v1, v4, v5, v2))
    return _from_bm(bm, "pitched_roof", color)


def _merlon_ring(cx, cy, z0, r, n, size, color, bevel=0.0):
    """Coroa circular de ameias (merlons) ao redor de uma torre."""
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n
        pts.append(
            L.box(
                size,
                (cx + r * math.cos(a), cy + r * math.sin(a), z0 + size[2] * 0.5),
                color,
                bevel=bevel,
                rot=(0.0, 0.0, a),
            )
        )
    return pts


def _corbel_ring(cx, cy, z0, r, n, size, color, bevel=0.0):
    """Anel de cachorros/matacaes (corbels) sob o parapeito de uma torre."""
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n
        pts.append(
            L.box(
                size,
                (cx + r * math.cos(a), cy + r * math.sin(a), z0),
                color,
                bevel=bevel,
                rot=(0.0, 0.0, a),
            )
        )
    return pts


# ---------------------------------------------------------------- 1. Castle01 (~18 studs, Hero PBR)
def castle01():
    """Grand Citadel Castle (~18 studs, 8.5k-11.5k tris): cidadela multi-torres com 5 torres
    principais, 2 guaritas suspensas (bartizans), muralhas chanfradas com contrafortes e arcadas,
    matacaes/cachorros, ameias densas, portao fortificado com barbacã, portcullis, brasao e salao."""
    p = []

    # 1. Zocalo rochoso escalonado e base chanfrada da cidadela
    p.append(L.cyl(6.80, 1.10, (0.0, 0.0, 0.0), "stoneDark", verts=24, r2=6.35))
    p.append(L.cyl(6.25, 0.45, (0.0, 0.0, 0.85), "stone", verts=24, r2=6.05))
    p.append(L.box((9.20, 6.80, 6.60), (0.0, 0.20, 1.10 + 3.30), "stone", bevel=0.06))
    p.append(L.box((9.42, 7.02, 0.36), (0.0, 0.20, 4.35), "stoneDark", bevel=0.03))
    p.append(L.box((9.50, 7.10, 0.55), (0.0, 0.20, 7.75), "stoneLight", bevel=0.04))

    # 2. Contrafortes com pingadeiras nas muralhas frontal, traseira e laterais
    for sx in (-2.65, -1.65, 1.65, 2.65):
        for sy, y_pos in ((-1, -3.22), (1, 3.62)):
            p.append(L.box((0.54, 0.48, 6.15), (sx, y_pos, 4.15), "stoneDark"))
            p.append(L.box((0.62, 0.58, 1.85), (sx, y_pos + sy * 0.06, 2.02), "stoneDark"))
            p.append(L.box((0.58, 0.52, 0.28), (sx, y_pos, 7.32), "stoneLight"))
    for sy in (-1.20, 0.20, 1.60):
        for sx in (-1, 1):
            x_pos = sx * 4.62
            p.append(L.box((0.48, 0.54, 6.10), (x_pos, sy, 4.15), "stoneDark"))
            p.append(L.box((0.52, 0.58, 0.28), (x_pos, sy, 7.32), "stoneLight"))

    # 3. Galeria de arcadas cegas e seteiras na muralha de cortina frontal
    for sx in (-3.15, -2.15, 2.15, 3.15):
        p.append(L.box((0.46, 0.16, 1.65), (sx, -3.21, 5.65), "ink"))
        p.append(L.torus(0.26, 0.07, (sx, -3.25, 6.45), "stoneLight", major_seg=12, minor_seg=4, rot=(math.pi / 2, 0.0, 0.0)))
        p.append(L.box((0.58, 0.22, 0.16), (sx, -3.25, 4.78), "stoneLight"))

    # 4. Cachorros (machicolations) e ameias densas com capas nas 4 faces da cortina
    for k in range(13):
        xk = -3.90 + k * 0.65
        if abs(xk) > 1.35:
            p.append(L.box((0.24, 0.36, 0.48), (xk, -3.28, 7.42), "stoneDark"))
        p.append(L.box((0.24, 0.36, 0.48), (xk, 3.68, 7.42), "stoneDark"))
    for k in range(9):
        yk = -2.20 + k * 0.60
        for sx in (-1, 1):
            p.append(L.box((0.36, 0.24, 0.48), (sx * 4.68, yk, 7.42), "stoneDark"))

    for sx in (-3.75, -3.05, -2.35, -1.65, 1.65, 2.35, 3.05, 3.75):
        for y_m in (-3.12, 3.52):
            p.append(L.box((0.48, 0.44, 0.64), (sx, y_m, 8.28), "stoneLight"))
            p.append(L.box((0.54, 0.50, 0.14), (sx, y_m, 8.64), "stoneDark"))
    for sy in (-2.10, -1.30, -0.50, 0.30, 1.10, 1.90, 2.70):
        for sx in (-1, 1):
            p.append(L.box((0.44, 0.48, 0.64), (sx * 4.52, sy, 8.28), "stoneLight"))
            p.append(L.box((0.50, 0.54, 0.14), (sx * 4.52, sy, 8.64), "stoneDark"))

    # 5. Salao Real interno (Great Hall) entre a cortina e a torre mestra
    p.append(L.box((5.60, 3.80, 3.40), (0.0, 0.55, 7.75 + 1.70), "stone", bevel=0.05))
    p.append(_pitched_roof(6.00, 4.10, 2.35, (0.0, 0.55, 9.35), "slateRoof", ridge_axis="x"))
    p.append(L.capsule_seg((-3.05, 0.55, 11.72), (3.05, 0.55, 11.72), 0.14, 0.14, "gold", verts=12))
    for sx in (-1.65, -0.55, 0.55, 1.65):
        p.append(L.box((0.42, 0.22, 1.25), (sx, -1.36, 8.65), "amberBright"))
        p.append(L.box((0.54, 0.18, 1.38), (sx, -1.32, 8.65), "stoneLight"))

    # 6. Portao fortificado monumental (Gatehouse Barbican) na frente (-Y)
    p.append(L.box((3.50, 1.75, 6.35), (0.0, -3.15, 1.10 + 3.175), "stoneLight", bevel=0.05))
    for sx in (-1.56, 1.56):
        p.append(L.cyl(0.58, 6.85, (sx, -3.65, 1.10), "stoneDark", verts=16, r2=0.52))
        p.append(L.torus(0.56, 0.08, (sx, -3.65, 5.20), "stoneLight", major_seg=16, minor_seg=4))
        p.append(L.cyl(0.64, 0.55, (sx, -3.65, 7.80), "stoneLight", verts=16, r2=0.68))
        p.append(L.cyl(0.68, 1.65, (sx, -3.65, 8.32), "slateRoof", verts=16, r2=0.0))
        p.append(L.ball(0.12, (sx, -3.65, 9.98), "gold", seg=10, rings=6))
        # Estandartes reais crimsonCloth + haste dourada
        p.append(L.box((0.46, 0.12, 0.10), (sx, -4.24, 6.38), "gold"))
        p.append(L.capsule_seg((sx, -4.26, 6.32), (sx, -4.30, 4.05), 0.18, 0.12, "crimsonCloth", verts=10))
        p.append(L.capsule_seg((sx, -4.29, 4.10), (sx, -4.32, 3.62), 0.12, 0.04, "gold", verts=8))

    # Brasao heráldico real + telhado do portao + arco duplo + portcullis completa
    p.append(L.box((0.92, 0.22, 1.08), (0.0, -4.04, 6.05), "royal", bevel=0.03))
    p.append(L.cyl_axis(0.38, 0.26, (0.0, -4.08, 6.05), "gold", axis="y", verts=12))
    p.append(_pitched_roof(3.75, 1.95, 1.55, (0.0, -3.15, 7.40), "slateRoof", ridge_axis="y"))
    for sx in (-0.95, -0.32, 0.32, 0.95):
        p.append(L.box((0.36, 0.38, 0.48), (sx, -3.98, 7.65), "stoneLight"))
    p.append(L.cyl_axis(1.08, 1.78, (0.0, -3.18, 3.45), "ink", axis="y", verts=18))
    p.append(L.box((2.16, 1.76, 2.35), (0.0, -3.18, 2.28), "ink"))
    p.append(L.torus(1.16, 0.15, (0.0, -3.98, 3.45), "stoneDark", major_seg=18, minor_seg=5, rot=(math.pi / 2, 0.0, 0.0)))
    p.append(L.torus(1.04, 0.10, (0.0, -4.02, 3.45), "stoneLight", major_seg=18, minor_seg=4, rot=(math.pi / 2, 0.0, 0.0)))
    for gx in (-0.75, -0.45, -0.15, 0.15, 0.45, 0.75):
        p.append(L.cyl(0.055, 3.15, (gx, -3.92, 1.15), "ironDark", verts=8))
    for gz in (1.65, 2.35, 3.05):
        p.append(L.box((1.82, 0.09, 0.09), (0.0, -3.92, gz), "ironDark"))

    # 7. 5 Torres redondas de alta densidade (2 frontais, 2 traseiras, 1 Torre Mestra central)
    towers = (
        (-4.25, -1.55, 2.05, 10.20, 4.10, False, 20),
        (4.25, -1.55, 2.05, 10.20, 4.10, False, 20),
        (-3.95, 2.65, 1.62, 9.40, 3.55, False, 18),
        (3.95, 2.65, 1.62, 9.40, 3.55, False, 18),
        (0.0, 1.55, 2.55, 12.10, 4.35, True, 24),
    )
    for tx, ty, rad, th, spire_h, is_main, segs in towers:
        z_base = 1.05
        p.append(L.cyl(rad * 1.15, 1.65, (tx, ty, z_base), "stoneDark", verts=segs, r2=rad * 1.02))
        p.append(L.cyl(rad, th - 1.60, (tx, ty, z_base + 1.60), "stone", verts=segs, r2=rad * 0.94))
        p.append(L.torus(rad * 0.99, 0.11, (tx, ty, z_base + th * 0.56), "stoneLight", major_seg=segs, minor_seg=4))
        z_top = z_base + th
        p += _corbel_ring(tx, ty, z_top - 0.42, rad * 0.98, 12 if is_main else 8, (0.26, 0.36, 0.52), "stoneDark")
        p.append(L.torus(rad * 0.98, 0.14, (tx, ty, z_top - 0.32), "stoneLight", major_seg=segs, minor_seg=5))
        p.append(L.cyl(rad * 1.08, 0.65, (tx, ty, z_top - 0.20), "stoneLight", verts=segs, r2=rad * 1.12))
        p += _merlon_ring(
            tx,
            ty,
            z_top + 0.42,
            rad * 1.04,
            12 if is_main else 8,
            (0.44, 0.34, 0.48),
            "stoneLight",
        )
        # Corucheu conico em slateRoof + lucarnas
        p.append(L.cyl(rad * 1.18, spire_h, (tx, ty, z_top + 0.38), "slateRoof", verts=segs, r2=0.0))
        dormer_angles = (-math.pi * 0.5, -math.pi * 0.22, math.pi * 0.22) if is_main else (-math.pi * 0.5, 0.0)
        for da in dormer_angles:
            dx = tx + rad * 0.76 * math.cos(da)
            dy = ty + rad * 0.76 * math.sin(da)
            p.append(L.box((0.52, 0.48, 0.72), (dx, dy, z_top + 1.25), "stoneLight", rot=(0.0, 0.0, da + math.pi * 0.5)))
            p.append(L.box((0.32, 0.52, 0.48), (dx, dy, z_top + 1.22), "amberBright", rot=(0.0, 0.0, da + math.pi * 0.5)))
        fin_z = z_top + 0.38 + spire_h
        p.append(L.ball(0.24 if is_main else 0.18, (tx, ty, fin_z - 0.08), "gold", seg=12, rings=6))
        # Janelas iluminadas amberBright com moldura na face -Y
        p.append(L.box((0.58, 0.22, 1.32), (tx, ty - rad * 0.91, z_base + th * 0.52), "stoneLight"))
        p.append(L.box((0.40, 0.26, 1.10), (tx, ty - rad * 0.95, z_base + th * 0.52), "amberBright"))
        if is_main:
            for sx in (-1.15, 1.15):
                p.append(L.box((0.56, 0.22, 1.38), (tx + sx, ty - rad * 0.84, z_base + th * 0.72), "stoneLight"))
                p.append(L.box((0.42, 0.26, 1.18), (tx + sx, ty - rad * 0.88, z_base + th * 0.72), "amberBright"))

    # 8. 2 Guaritas suspensas (bartizan turrets) flanqueando a torre mestra
    for sx in (-2.45, 2.45):
        bx, by, bz = sx, -0.35, 8.60
        p.append(L.cyl(0.22, 1.15, (bx, by, bz), "stoneDark", verts=14, r2=0.88))
        p.append(L.cyl(0.88, 2.45, (bx, by, bz + 1.15), "stoneLight", verts=14, r2=0.84))
        p.append(L.torus(0.88, 0.07, (bx, by, bz + 2.35), "gold", major_seg=14, minor_seg=4))
        p.append(L.cyl(0.98, 1.85, (bx, by, bz + 3.58), "slateRoof", verts=14, r2=0.0))
        p.append(L.ball(0.12, (bx, by, bz + 5.42), "gold", seg=10, rings=6))

    return p


# ---------------------------------------------------------------- 2. Keep01 (~20 studs, Hero PBR)
def keep01():
    """Crowned Royal Keep / Bastion Donjon (~20 studs, 8.5k-11.5k tris): donjon real em whiteStone
    com base abaluartada e escadaria cerimonial, contrafortes escalonados com pinaculos, 4 torretas
    de canto ricamente esculpidas, rosacea real, tambor com colunata e cupula dourada nervurada."""
    p = []

    # 1. Base escalonada abaluartada de pedra chanfrada + escadaria monumental frontal (-Y)
    p.append(L.box((8.80, 8.80, 1.30), (0.0, 0.0, 0.65), "stoneDark", bevel=0.06))
    p.append(L.box((8.25, 8.25, 0.55), (0.0, 0.0, 1.42), "stone", bevel=0.04))
    p.append(L.box((7.80, 7.80, 1.10), (0.0, 0.0, 1.85), "whiteStoneDark", bevel=0.05))
    for st in range(5):
        sy = -4.52 + st * 0.24
        sz = 0.16 + st * 0.22
        sw = 3.10 - st * 0.12
        p.append(L.box((sw, 0.42, 0.28), (0.0, sy, sz), "whiteStone" if st % 2 else "stoneDark"))
    for sx in (-1.62, 1.62):
        p.append(L.box((0.42, 1.35, 1.35), (sx, -4.12, 0.68), "whiteStoneDark", bevel=0.035))
        p.append(L.cyl(0.24, 0.42, (sx, -4.45, 1.32), "gold", verts=12, r2=0.18))
        p.append(L.ball(0.20, (sx, -4.45, 1.82), "amberBright", seg=10, rings=6))

    # 2. Corpo principal do Donjon em whiteStone + cintas de ouro + contrafortes escalonados
    p.append(L.box((6.40, 6.40, 10.60), (0.0, 0.0, 2.40 + 5.30), "whiteStone", bevel=0.06))
    for z_belt, col in ((4.85, "whiteStoneDark"), (7.85, "gold"), (10.85, "gold")):
        p.append(L.box((6.68, 6.68, 0.28), (0.0, 0.0, z_belt), col, bevel=0.025))

    # Contrafortes escalonados nas 4 faces com pingadeiras e pinaculos dourados no topo
    for s1 in (-1, 1):
        for s2 in (-1.65, 1.65):
            p.append(L.box((0.68, 0.78, 9.80), (s2, s1 * 3.32, 2.40 + 4.90), "whiteStoneDark", bevel=0.04))
            p.append(L.box((0.78, 0.92, 3.60), (s2, s1 * 3.42, 2.40 + 1.80), "stone", bevel=0.03))
            p.append(L.cyl(0.28, 1.15, (s2, s1 * 3.38, 12.20), "gold", verts=8, r2=0.0))
            p.append(L.box((0.78, 0.68, 9.80), (s1 * 3.32, s2, 2.40 + 4.90), "whiteStoneDark", bevel=0.04))
            p.append(L.box((0.92, 0.78, 3.60), (s1 * 3.42, s2, 2.40 + 1.80), "stone", bevel=0.03))
            p.append(L.cyl(0.28, 1.15, (s1 * 3.38, s2, 12.20), "gold", verts=8, r2=0.0))

    # 3. Cornija superior + cachorros + ameias reais nas 4 faces
    for k in (-2.4, -1.6, -0.8, 0.0, 0.8, 1.6, 2.4):
        for s_face in (-1, 1):
            p.append(L.box((0.26, 0.38, 0.52), (k, s_face * 3.36, 12.72), "whiteStoneDark"))
            p.append(L.box((0.38, 0.26, 0.52), (s_face * 3.36, k, 12.72), "whiteStoneDark"))
    p.append(L.box((7.10, 7.10, 0.75), (0.0, 0.0, 13.15), "whiteStoneDark", bevel=0.04))
    p.append(L.box((7.30, 7.30, 0.32), (0.0, 0.0, 13.68), "gold", bevel=0.025))
    for k in (-2.1, -1.26, -0.42, 0.42, 1.26, 2.1):
        for s_face in (-1, 1):
            p.append(L.box((0.48, 0.38, 0.56), (k, s_face * 3.48, 14.10), "whiteStone"))
            p.append(L.box((0.54, 0.44, 0.12), (k, s_face * 3.48, 14.42), "gold"))
            p.append(L.box((0.38, 0.48, 0.56), (s_face * 3.48, k, 14.10), "whiteStone"))
            p.append(L.box((0.44, 0.54, 0.12), (s_face * 3.48, k, 14.42), "gold"))

    # 4. 4 Torretas cilindricas de canto (20 segs) com aneis, cachorros, lucarnas e agulhas slateRoof/gold
    for sx in (-1, 1):
        for sy in (-1, 1):
            tx, ty = sx * 3.15, sy * 3.15
            p.append(L.cyl(1.34, 1.85, (tx, ty, 1.80), "whiteStoneDark", verts=20, r2=1.20))
            p.append(L.cyl(1.18, 12.20, (tx, ty, 1.80), "whiteStone", verts=20, r2=1.08))
            for tz, tcol in ((7.85, "gold"), (13.85, "gold")):
                p.append(L.torus(1.16, 0.09, (tx, ty, tz), tcol, major_seg=20, minor_seg=4))
            p += _corbel_ring(tx, ty, 13.45, 1.12, 8, (0.22, 0.30, 0.42), "whiteStoneDark")
            p += _merlon_ring(tx, ty, 13.95, 1.14, 8, (0.36, 0.28, 0.40), "whiteStone")
            p.append(L.cyl(1.32, 3.20, (tx, ty, 14.00), "slateRoof", verts=20, r2=0.0))
            p.append(L.box((0.42, 0.44, 0.62), (tx, ty + sy * 0.88, 14.75), "whiteStone"))
            p.append(L.box((0.26, 0.48, 0.42), (tx, ty + sy * 0.90, 14.75), "amberBright"))
            p.append(L.ball(0.20, (tx, ty, 17.16), "gold", seg=12, rings=6))

    # 5. Tambor cilindrico central com colunata de 12 pilastras + Cupula Dourada Nervurada ate ~20.0 studs
    p.append(L.cyl(2.55, 0.65, (0.0, 0.0, 13.40), "whiteStoneDark", verts=24, r2=2.40))
    p.append(L.cyl(2.35, 3.10, (0.0, 0.0, 13.50), "whiteStone", verts=24, r2=2.15))
    for k in range(12):
        a = 2 * math.pi * k / 12
        ca, sa = math.cos(a), math.sin(a)
        p.append(L.cyl(0.14, 2.85, (2.28 * ca, 2.28 * sa, 13.62), "gold", verts=10))
        if k % 2 == 1:
            p.append(
                L.box(
                    (0.22, 0.36, 1.35),
                    (2.22 * ca, 2.22 * sa, 15.05),
                    "amberBright",
                    rot=(0.0, 0.0, a),
                )
            )
    p.append(L.torus(2.24, 0.15, (0.0, 0.0, 16.55), "gold", major_seg=24, minor_seg=6))
    p.append(L.ball(2.12, (0.0, 0.0, 16.65), "gold", seg=24, rings=12, squash=(1.0, 1.0, 0.92)))
    for k in range(4):
        a = k * math.pi / 4
        p.append(
            L.torus(
                2.06,
                0.07,
                (0.0, 0.0, 16.65),
                "goldBright",
                major_seg=20,
                minor_seg=4,
                rot=(math.pi * 0.5, 0.0, a),
                squash=(1.0, 0.92, 1.0),
            )
        )
    p.append(L.torus(0.68, 0.09, (0.0, 0.0, 18.32), "goldBright", major_seg=16, minor_seg=5))
    p.append(L.cyl(0.55, 1.35, (0.0, 0.0, 18.35), "royal", verts=16, r2=0.14))
    p.append(L.ball(0.28, (0.0, 0.0, 19.72), "goldBright", seg=14, rings=8))

    # 6. Fachada real (-Y) e laterais: estandartes crimsonCloth, rosacea, vitrais e portico real
    for sx in (-1.65, 1.65):
        p.append(L.box((0.68, 0.16, 0.14), (sx, -3.42, 11.92), "gold"))
        p.append(L.capsule_seg((sx, -3.38, 11.80), (sx, -3.44, 6.20), 0.34, 0.24, "crimsonCloth", verts=12))
        p.append(L.capsule_seg((sx, -3.42, 6.30), (sx, -3.45, 5.45), 0.24, 0.06, "gold", verts=8))
    # Rosacea gótica e vitral central na fachada -Y
    p.append(L.torus(0.76, 0.11, (0.0, -3.26, 11.45), "gold", major_seg=18, minor_seg=5, rot=(math.pi / 2, 0.0, 0.0)))
    p.append(L.cyl_axis(0.66, 0.22, (0.0, -3.24, 11.45), "amberBright", axis="y", verts=16))
    p.append(L.box((1.06, 0.24, 2.76), (0.0, -3.22, 8.85), "gold", bevel=0.02))
    p.append(L.box((0.74, 0.28, 2.42), (0.0, -3.26, 8.85), "amberBright"))
    # Vitrais laterais (-X, +X, +Y)
    for s_side in (-1, 1):
        p.append(L.box((0.24, 0.96, 2.45), (s_side * 3.22, 0.0, 9.10), "gold", bevel=0.02))
        p.append(L.box((0.28, 0.68, 2.15), (s_side * 3.26, 0.0, 9.10), "amberBright"))
    p.append(L.box((0.96, 0.24, 2.45), (0.0, 3.22, 9.10), "gold", bevel=0.02))
    p.append(L.box((0.68, 0.28, 2.15), (0.0, 3.26, 9.10), "amberBright"))

    # Portico real (-Y) com arquivoltas e colunas
    for sx in (-1.05, 1.05):
        p.append(L.cyl(0.22, 2.45, (sx, -3.55, 2.40), "whiteStone", verts=12))
        p.append(L.torus(0.25, 0.06, (sx, -3.55, 4.78), "gold", major_seg=12, minor_seg=4))
    p.append(L.torus(1.06, 0.14, (0.0, -3.48, 4.20), "gold", major_seg=18, minor_seg=5, rot=(math.pi / 2, 0.0, 0.0)))
    p.append(L.cyl_axis(0.98, 0.72, (0.0, -3.28, 4.15), "gold", axis="y", verts=16))
    p.append(L.cyl_axis(0.84, 0.76, (0.0, -3.30, 4.10), "royal", axis="y", verts=16))
    p.append(L.box((1.76, 0.62, 1.75), (0.0, -3.22, 3.22), "ironDark", bevel=0.02))

    return p


# ---------------------------------------------------------------- 3. House01 (~8 studs, Tier-A)
def house01():
    """Half-timbered cottage (~8 studs, 2.8k-3.4k tris): fundacao chanfrada com cunhais, enxaimel
    woodDark rico nas 4 faces e oitões, telhado de barro com ripas e caibros, chamine de pedra com
    cursos e chaminés de barro, alpendre, venezianas, floreiras e barril."""
    p = []

    # Fundacao de pedra chanfrada + degraus de entrada (-Y)
    p.append(L.box((5.60, 4.60, 1.15), (0.0, 0.0, 0.575), "stoneDark", bevel=0.05))
    p.append(L.box((1.78, 0.78, 0.26), (0.0, -2.58, 0.13), "stoneDark", bevel=0.025))
    p.append(L.box((1.55, 0.58, 0.42), (0.0, -2.44, 0.28), "stone", bevel=0.03))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(L.box((0.46, 0.46, 1.18), (sx * 2.66, sy * 2.16, 0.59), "stone", bevel=0.03))

    # Paredes whiteStone (z = 1.15 .. 4.55)
    w, d, h = 5.30, 4.30, 3.40
    z0 = 1.15
    p.append(L.box((w, d, h), (0.0, 0.0, z0 + h * 0.5), "whiteStone", bevel=0.04))

    # Vigas de enxaimel (woodDark) horizontais, verticais e maos-francesas diagonais nas 4 faces
    for zv in (z0 + 0.08, z0 + h * 0.52, z0 + h - 0.08):
        p.append(L.box((w + 0.18, d + 0.18, 0.20), (0.0, 0.0, zv), "woodDark", bevel=0.025))
    for sx in (-1, -0.36, 0.36, 1):
        for sy in (-1, 1):
            p.append(L.box((0.18, 0.18, h + 0.10), (sx * (w * 0.48), sy * (d * 0.48), z0 + h * 0.5), "woodDark"))
    for sy in (-0.35, 0.35):
        for sx in (-1, 1):
            p.append(L.box((0.18, 0.18, h + 0.08), (sx * (w * 0.48), sy * d, z0 + h * 0.5), "woodDark"))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(
                L.box(
                    (0.16, 0.16, 1.75),
                    (sx * 1.85, sy * (d * 0.5 + 0.04), z0 + 2.55),
                    "woodDark",
                    rot=(0.0, sx * 0.62, 0.0),
                    bevel=0.02,
                )
            )
            # Tesouras diagonais nos oitões (-Y e +Y)
            p.append(
                L.box(
                    (0.16, 0.18, 2.25),
                    (sx * 0.92, sy * 2.18, 5.55),
                    "woodDark",
                    rot=(0.0, -sx * 0.68, 0.0),
                    bevel=0.02,
                )
            )

    # Telhado de telha de barro em duas aguas + cumeeira + ripas + caibros sob o beiral
    p.append(_pitched_roof(6.10, 5.10, 3.10, (0.0, 0.0, 4.45), "roof", ridge_axis="y"))
    p.append(L.capsule_seg((0.0, -2.68, 7.52), (0.0, 2.68, 7.52), 0.16, 0.16, "woodDark", verts=14))
    p.append(_pitched_roof(5.26, 4.26, 2.82, (0.0, 0.0, 4.50), "whiteStone", ridge_axis="y"))
    for rk in (0.28, 0.58, 0.84):
        for sx in (-1, 1):
            rx = sx * (2.95 * (1.0 - rk * 0.82))
            rz = 4.55 + rk * 2.85
            p.append(L.box((0.18, 5.16, 0.14), (rx, 0.0, rz), "roof", rot=(0.0, -sx * 0.78, 0.0), bevel=0.02))
    for yk in (-2.1, -1.15, -0.25, 0.65, 1.55, 2.1):
        for sx in (-1, 1):
            p.append(L.box((0.36, 0.16, 0.18), (sx * 2.92, yk, 4.42), "woodDark"))

    # Chamine de pedra lateral escalonada chegando a ~8.0 studs
    p.append(L.box((1.04, 1.04, 2.60), (2.15, 0.65, 1.15 + 1.30), "stoneDark", bevel=0.04))
    p.append(L.box((0.92, 0.92, 6.40), (2.15, 0.65, 1.15 + 3.20), "stone", bevel=0.04))
    p.append(L.box((1.02, 1.02, 0.24), (2.15, 0.65, 5.85), "stoneLight", bevel=0.025))
    p.append(L.box((1.08, 1.08, 0.34), (2.15, 0.65, 7.52), "stoneLight", bevel=0.03))
    p.append(L.cyl(0.28, 0.42, (2.15, 0.65, 7.60), "stoneDark", verts=14, r2=0.24))
    p.append(L.torus(0.26, 0.05, (2.15, 0.65, 7.96), "roof", major_seg=14, minor_seg=4))

    # Porta arqueada frontal (-Y) com alpendre, lanterna de ferro, janelas com venezianas e floreiras
    p.append(L.box((1.05, 0.24, 1.95), (0.0, -2.18, 2.12), "wood", bevel=0.025))
    p.append(L.cyl_axis(0.52, 0.26, (0.0, -2.18, 3.08), "woodDark", axis="y", verts=14))
    p.append(L.box((1.48, 0.62, 0.14), (0.0, -2.42, 3.48), "roof", rot=(0.24, 0.0, 0.0), bevel=0.02))
    p.append(L.box((0.20, 0.22, 0.28), (0.72, -2.28, 3.12), "amberBright", bevel=0.02))
    for sx in (-1.55, 1.55):
        p.append(L.box((0.86, 0.22, 0.96), (sx, -2.18, 2.95), "amberBright"))
        p.append(L.box((0.92, 0.25, 0.08), (sx, -2.20, 2.95), "woodDark"))
        for sh in (-0.54, 0.54):
            p.append(L.box((0.22, 0.18, 0.98), (sx + sh, -2.22, 2.95), "wood", bevel=0.02))
        p.append(L.box((0.98, 0.32, 0.16), (sx, -2.26, 2.40), "woodDark", bevel=0.02))
        p.append(L.ball(0.24, (sx - 0.18, -2.32, 2.56), "leafMid", seg=10, rings=6, squash=(1.3, 0.8, 0.7)))
        p.append(L.ball(0.22, (sx + 0.18, -2.32, 2.56), "leafSun", seg=10, rings=6, squash=(1.3, 0.8, 0.7)))
    p.append(L.box((0.68, 0.24, 0.78), (0.0, -2.18, 5.55), "amberBright"))
    p.append(L.box((0.76, 0.20, 0.86), (0.0, -2.15, 5.55), "woodDark"))

    # Barril de chuva frontal-esquerdo (-X, -Y)
    bx, by = -2.38, -2.32
    p.append(L.cyl(0.42, 1.12, (bx, by, 0.0), "wood", verts=14, r2=0.44))
    p.append(L.torus(0.44, 0.04, (bx, by, 0.28), "ironDark", major_seg=14, minor_seg=4))
    p.append(L.torus(0.44, 0.04, (bx, by, 0.86), "ironDark", major_seg=14, minor_seg=4))

    return p


# ---------------------------------------------------------------- 4. House02 (~8 studs, Tier-A)
def house02():
    """Stone farmhouse (~8 studs, 2.8k-3.4k tris): paredes de pedra chanfradas com cunhais,
    chamine escalonada, telhado arredondado de palha (straw) com feixes e amarras, mansarda frontal,
    alpendre sobre colunas, lenha empilhada e barris."""
    p = []

    # Base e paredes rusticas de pedra chanfradas (z = 0.0 .. 4.20)
    p.append(L.box((6.20, 4.80, 1.05), (0.0, 0.0, 0.525), "stoneDark", bevel=0.05))
    p.append(L.box((5.70, 4.30, 3.20), (0.0, 0.0, 1.05 + 1.60), "stone", bevel=0.05))
    p.append(L.box((5.86, 4.46, 0.22), (0.0, 0.0, 2.65), "stoneDark", bevel=0.02))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(L.box((0.58, 0.58, 3.30), (sx * 2.78, sy * 2.08, 1.05 + 1.65), "stoneLight", bevel=0.04))
            p.append(L.box((0.64, 0.64, 1.10), (sx * 2.78, sy * 2.08, 1.60), "stoneDark", bevel=0.03))

    # Chamine rustica lateral de pedra com cursos e pote de barro
    p.append(L.box((1.08, 1.08, 2.80), (2.45, 0.55, 1.05 + 1.40), "stoneDark", bevel=0.04))
    p.append(L.box((0.95, 0.95, 6.25), (2.45, 0.55, 1.05 + 3.125), "stoneDark", bevel=0.04))
    p.append(L.box((1.06, 1.06, 0.24), (2.45, 0.55, 5.65), "stoneLight", bevel=0.025))
    p.append(L.box((1.12, 1.12, 0.30), (2.45, 0.55, 7.38), "stoneLight", bevel=0.03))
    p.append(L.cyl(0.28, 0.44, (2.45, 0.55, 7.48), "stone", verts=14, r2=0.24))
    p.append(L.torus(0.26, 0.05, (2.45, 0.55, 7.86), "stoneDark", major_seg=14, minor_seg=4))

    # Telhado de palha (straw) arredondado esculpido com feixes organicos ate ~8.0 studs
    p.append(_pitched_roof(6.40, 5.10, 3.35, (0.0, 0.0, 4.15), "straw", ridge_axis="x"))
    thatch_rolls = (
        ((-2.95, 0.0, 7.42), (2.95, 0.0, 7.42), 0.58, "straw"),
        ((-3.00, -0.52, 6.88), (3.00, -0.52, 6.88), 0.54, "woodLight"),
        ((-3.00, 0.52, 6.88), (3.00, 0.52, 6.88), 0.54, "woodLight"),
        ((-3.05, -1.15, 6.12), (3.05, -1.15, 6.12), 0.50, "straw"),
        ((-3.05, 1.15, 6.12), (3.05, 1.15, 6.12), 0.50, "straw"),
        ((-3.12, -1.85, 5.15), (3.12, -1.85, 5.15), 0.46, "woodLight"),
        ((-3.12, 1.85, 5.15), (3.12, 1.85, 5.15), 0.46, "woodLight"),
    )
    for p0, p1, rad, col in thatch_rolls:
        p.append(L.capsule_seg(p0, p1, rad, rad, col, verts=14))
    for xk in (-2.1, -1.05, 0.0, 1.05, 2.1):
        p.append(L.torus(0.46, 0.09, (xk, 0.0, 7.46), "woodDark", major_seg=14, minor_seg=5, rot=(0.0, math.pi / 2, 0.0)))

    # Janela mansarda (dormer) frontal (-Y) + empena de madeira + feixe de palha
    p.append(L.box((1.55, 1.45, 1.35), (0.0, -1.75, 5.45), "woodDark", bevel=0.03))
    p.append(_pitched_roof(1.85, 1.65, 0.95, (0.0, -1.78, 6.08), "straw", ridge_axis="y"))
    p.append(L.capsule_seg((0.0, -2.62, 6.98), (0.0, -1.02, 6.98), 0.22, 0.22, "woodLight", verts=12))
    p.append(L.box((0.78, 0.22, 0.78), (0.0, -2.48, 5.52), "amberBright"))
    p.append(L.box((0.86, 0.25, 0.08), (0.0, -2.50, 5.52), "woodDark"))

    # Porta de tabuas com alpendre sobre colunas (-Y), janelas molduradas, barris e lenha empilhada
    p.append(L.box((1.12, 0.24, 2.05), (-0.75, -2.18, 2.08), "woodDark", bevel=0.025))
    p.append(L.box((1.65, 0.82, 0.18), (-0.75, -2.46, 3.25), "wood", rot=(0.24, 0.0, 0.0), bevel=0.02))
    for px_off in (-1.38, -0.12):
        p.append(L.cyl(0.10, 2.15, (px_off, -2.68, 1.02), "woodDark", verts=10))
    p.append(L.box((1.55, 0.58, 0.28), (-0.75, -2.52, 0.14), "stoneLight", bevel=0.025))
    p.append(L.box((1.35, 0.20, 1.15), (1.25, -2.14, 2.68), "woodDark", bevel=0.025))
    p.append(L.box((1.12, 0.24, 0.92), (1.25, -2.19, 2.68), "amberBright"))
    for sh in (-0.68, 0.68):
        p.append(L.box((0.24, 0.18, 1.12), (1.25 + sh, -2.20, 2.68), "wood", bevel=0.02))

    # Barris duplos e pilha densa de lenha na frente
    for bx, by, sc in ((-2.35, -2.42, 1.0), (-1.68, -2.52, 0.78)):
        p.append(L.cyl(0.46 * sc, 1.25 * sc, (bx, by, 0.0), "wood", verts=14, r2=0.48 * sc))
        p.append(L.torus(0.48 * sc, 0.04 * sc, (bx, by, 0.30 * sc), "ironDark", major_seg=14, minor_seg=4))
        p.append(L.torus(0.48 * sc, 0.04 * sc, (bx, by, 0.95 * sc), "ironDark", major_seg=14, minor_seg=4))
    for lx, lz in ((1.92, 0.18), (2.22, 0.18), (2.52, 0.18), (2.06, 0.44), (2.38, 0.44), (2.22, 0.70)):
        p.append(L.cyl_axis(0.15, 0.88, (lx, -2.36, lz), "woodDark", axis="y", verts=10))

    return p


# ---------------------------------------------------------------- 5. Tower01 (~16 studs, Tier-A)
def tower01():
    """Tall stone watchtower (~16 studs, 2.6k-3.6k tris): fuste de pedra afunilado 20-seg, cachorros
    e ameias na galeria, lucarna frontal, corucheu slateRoof e braseiro de sinalizacao engaiolado."""
    p = []

    # Base alargada de pedra (20 segs) + contrafortes chanfrados
    p.append(L.cyl(2.45, 1.80, (0.0, 0.0, 0.0), "stoneDark", verts=20, r2=2.05))
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        p.append(
            L.box(
                (0.58, 0.85, 2.80),
                (1.92 * math.cos(a), 1.92 * math.sin(a), 1.40),
                "stoneDark",
                rot=(0.0, 0.0, a),
                bevel=0.04,
            )
        )

    # Fuste cilindrico de pedra (z = 1.80 .. 10.60) com cintas torus e seteiras molduradas
    p.append(L.cyl(2.02, 4.40, (0.0, 0.0, 1.80), "stone", verts=20, r2=1.78))
    p.append(L.torus(1.90, 0.10, (0.0, 0.0, 4.00), "stoneDark", major_seg=20, minor_seg=5))
    p.append(L.torus(1.82, 0.12, (0.0, 0.0, 6.20), "stoneLight", major_seg=20, minor_seg=6))
    p.append(L.cyl(1.78, 4.40, (0.0, 0.0, 6.20), "stoneLight", verts=20, r2=1.64))
    p.append(L.torus(1.72, 0.09, (0.0, 0.0, 8.65), "stoneDark", major_seg=20, minor_seg=5))

    # Cachorros de pedra (corbels) + Galeria de vigia alargada com ameias em z = 10.60 .. 12.20
    p += _corbel_ring(0.0, 0.0, 10.55, 1.82, 8, (0.26, 0.40, 0.72), "stoneDark", bevel=0.025)
    p.append(L.cyl(1.68, 0.65, (0.0, 0.0, 10.45), "stoneDark", verts=20, r2=2.22))
    p.append(L.cyl(2.24, 1.15, (0.0, 0.0, 11.10), "woodDark", verts=20, r2=2.20))
    p += _merlon_ring(0.0, 0.0, 11.15, 2.22, 8, (0.42, 0.28, 0.44), "stoneLight", bevel=0.02)
    p.append(L.torus(2.24, 0.10, (0.0, 0.0, 11.12), "wood", major_seg=20, minor_seg=5))
    p.append(L.torus(2.22, 0.09, (0.0, 0.0, 12.18), "wood", major_seg=20, minor_seg=5))
    for k in range(8):
        a = 2 * math.pi * k / 8
        p.append(L.cyl(0.14, 1.25, (1.92 * math.cos(a), 1.92 * math.sin(a), 12.20), "woodDark", verts=10))
    p.append(L.cyl(2.48, 2.35, (0.0, 0.0, 13.35), "slateRoof", verts=20, r2=0.0))
    p.append(L.box((0.54, 0.52, 0.68), (0.0, -1.68, 14.05), "stoneLight", bevel=0.02))
    p.append(L.box((0.34, 0.56, 0.46), (0.0, -1.72, 14.05), "amberBright"))
    p.append(L.ball(0.22, (0.0, 0.0, 15.78), "gold", seg=12, rings=6))

    # Porta terrea (-Y) com arco de pedra, janelas iluminadas + Braseiro de sinalizacao suspenso
    p.append(L.box((0.92, 0.28, 1.75), (0.0, -2.18, 0.88), "woodDark", bevel=0.025))
    p.append(L.torus(0.52, 0.10, (0.0, -2.18, 1.75), "stoneLight", major_seg=14, minor_seg=4, rot=(math.pi / 2, 0.0, 0.0)))
    p.append(L.box((0.56, 0.20, 1.28), (0.0, -1.74, 8.20), "stoneDark"))
    p.append(L.box((0.44, 0.24, 1.15), (0.0, -1.78, 8.20), "amberBright"))
    p.append(L.box((0.36, 0.24, 0.95), (1.35, -1.35, 5.10), "amberBright", rot=(0, 0, -0.78)))
    p.append(L.capsule_seg((-1.55, -1.25, 10.85), (-2.55, -1.95, 11.15), 0.12, 0.10, "ironDark", verts=10))
    p.append(L.capsule_seg((-1.62, -1.30, 10.15), (-2.22, -1.72, 10.95), 0.08, 0.07, "iron", verts=8))
    p.append(L.cyl(0.42, 0.36, (-2.55, -1.95, 10.65), "ironDark", verts=16, r2=0.58))
    p.append(L.torus(0.58, 0.05, (-2.55, -1.95, 11.02), "iron", major_seg=16, minor_seg=5))
    p.append(L.ball(0.42, (-2.55, -1.95, 11.08), "ember", seg=12, rings=8, squash=(1.0, 1.0, 0.65)))
    p.append(L.crystal(0.28, 0.78, (-2.55, -1.95, 11.18), "amberBright", tilt=(0.12, -0.15), verts=8))

    return p


# ---------------------------------------------------------------- 6. Windmill01 (~16 studs, Tier-A)
def windmill01():
    """Tapered stone windmill tower (~16 studs, 2.6k-3.6k tris): torre conica de pedra de 20 segs,
    varanda com maos-francesas e guarda-corpo, cupula de madeira arredondada e 4 pas em trelica."""
    p = []

    # Base de pedra escura + degrau frontal + torre afunilada de 20 segmentos
    p.append(L.cyl(2.85, 1.65, (0.0, 0.0, 0.0), "stoneDark", verts=20, r2=2.62))
    p.append(L.box((1.55, 0.65, 0.38), (0.0, -2.85, 0.19), "stone", bevel=0.03))
    p.append(L.cyl(2.60, 4.80, (0.0, 0.0, 1.65), "whiteStoneDark", verts=20, r2=2.15))
    p.append(L.torus(2.18, 0.11, (0.0, 0.0, 6.45), "stone", major_seg=20, minor_seg=6))
    p.append(L.cyl(2.14, 4.65, (0.0, 0.0, 6.45), "whiteStone", verts=20, r2=1.72))
    p.append(L.torus(1.76, 0.11, (0.0, 0.0, 11.10), "woodDark", major_seg=20, minor_seg=6))

    # Varanda circular de madeira no meio da torre com balaustres e maos-francesas
    p.append(L.cyl(2.85, 0.22, (0.0, 0.0, 5.20), "wood", verts=20))
    p.append(L.torus(2.82, 0.08, (0.0, 0.0, 5.85), "woodDark", major_seg=20, minor_seg=5))
    for k in range(12):
        a = 2 * math.pi * k / 12
        p.append(L.cyl(0.065, 0.65, (2.78 * math.cos(a), 2.78 * math.sin(a), 5.22), "woodDark", verts=8))
        if k % 2 == 0:
            p.append(
                L.box(
                    (0.16, 0.52, 0.58),
                    (2.42 * math.cos(a), 2.42 * math.sin(a), 4.88),
                    "woodDark",
                    rot=(0.0, 0.0, a),
                )
            )

    # Cupula de madeira arredondada (domed wooden cap) + mansarda de eixo + pinaculo
    p.append(L.cyl(1.82, 1.15, (0.0, 0.0, 11.10), "woodDark", verts=20, r2=1.68))
    p.append(L.ball(1.72, (0.0, 0.0, 12.25), "wood", seg=20, rings=10, squash=(1.0, 1.08, 1.05)))
    p.append(L.box((0.95, 0.95, 0.85), (0.0, -1.45, 11.65), "woodDark", bevel=0.03))
    p.append(L.cyl(0.18, 1.10, (0.0, 0.0, 13.85), "gold", verts=12, r2=0.04))

    # Porta arqueada e janelas frontais (-Y)
    p.append(L.box((1.10, 0.28, 2.10), (0.0, -2.56, 1.05), "woodDark", bevel=0.025))
    p.append(L.cyl_axis(0.55, 0.28, (0.0, -2.56, 2.10), "stoneLight", axis="y", verts=12))
    p.append(L.box((0.82, 0.20, 1.06), (0.0, -1.98, 8.20), "woodDark"))
    p.append(L.box((0.68, 0.24, 0.92), (0.0, -2.02, 8.20), "amberBright"))

    # Eixo do rotor projetado para -Y (z = 11.55) + 4 pas em trelica (atingindo ~16.3 studs no topo)
    hub_y, hub_z = -2.35, 11.55
    p.append(L.cyl_axis(0.34, 1.55, (0.0, -1.75, hub_z), "woodDark", axis="y", verts=16))
    p.append(L.torus(0.38, 0.06, (0.0, -2.05, hub_z), "ironDark", major_seg=14, minor_seg=5, rot=(math.pi / 2, 0, 0)))
    p.append(L.ball(0.42, (0.0, hub_y, hub_z), "ironDark", seg=14, rings=8))

    sail_len = 6.10
    for k in range(4):
        ang = math.pi / 4 + k * math.pi / 2
        ca, sa = math.cos(ang), math.sin(ang)
        tip = (sail_len * ca, hub_y - 0.12, hub_z + sail_len * sa)
        p.append(L.capsule_seg((0.0, hub_y, hub_z), tip, 0.13, 0.08, "woodDark", verts=10))
        mid_r = sail_len * 0.58
        px, pz = mid_r * ca, hub_z + mid_r * sa
        off_x, off_z = -0.52 * sa, 0.52 * ca
        p.append(
            L.box(
                (sail_len * 0.74, 0.08, 0.92),
                (px + off_x, hub_y - 0.16, pz + off_z),
                "parchment" if k % 2 == 0 else "straw",
                rot=(0.0, -ang, 0.0),
                bevel=0.015,
            )
        )
        for frac in (0.28, 0.46, 0.64, 0.80, 0.94):
            rx, rz = (sail_len * frac) * ca, hub_z + (sail_len * frac) * sa
            p.append(
                L.capsule_seg(
                    (rx - off_x * 0.25, hub_y - 0.14, rz - off_z * 0.25),
                    (rx + off_x * 1.85, hub_y - 0.18, rz + off_z * 1.85),
                    0.055,
                    0.045,
                    "wood",
                    verts=8,
                )
            )

    return p


# ---------------------------------------------------------------- 7. Tree01 (~11 studs, Tier-A)
def tree01():
    """Lush valley tree (~11 studs, 1.5k-1.85k tris): raizes abertas com musgo, tronco curvo em
    capsule_seg e copa multi-tom subdiv=2 (leafDeep/leafMid/leafSun/oliveLeaf)."""
    p = []

    # 1. 5 Raizes abertas em capsule_seg + almofadas de musgo
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.25
        p.append(
            L.capsule_seg(
                (0.28 * math.cos(a), 0.28 * math.sin(a), 0.85),
                (1.55 * math.cos(a), 1.55 * math.sin(a), 0.05),
                0.42,
                0.15,
                "barkDark",
                verts=14,
            )
        )
        if k % 2 == 0:
            p.append(_rot(L.ico(0.44, (0.98 * math.cos(a + 0.3), 0.98 * math.sin(a + 0.3), 0.25), "moss", squash=(1.25, 1.05, 0.52), subdiv=1), 0.1, 0.1, a))

    # 2. Tronco curvo em 3 segmentos + 4 galhos principais + 2 galhos secundarios em capsule_seg
    trunk = (
        ((0.0, 0.0, 0.0), (-0.12, 0.08, 2.45), 0.82, 0.64),
        ((-0.12, 0.08, 2.30), (0.10, -0.06, 4.65), 0.64, 0.48),
        ((0.10, -0.06, 4.50), (0.04, 0.02, 6.45), 0.48, 0.30),
    )
    for p0, p1, r0, r1 in trunk:
        p.append(L.capsule_seg(p0, p1, r0, r1, "barkDark", verts=18))

    branches = (
        ((0.02, 0.0, 4.85), (-1.85, -1.15, 6.85), 0.34, 0.15),
        ((0.08, -0.04, 5.10), (1.92, -0.88, 7.05), 0.32, 0.14),
        ((-0.04, 0.06, 5.35), (-1.25, 1.65, 7.15), 0.30, 0.14),
        ((0.06, 0.06, 5.50), (1.55, 1.42, 6.95), 0.28, 0.13),
        ((-1.25, -0.78, 6.25), (-2.35, 0.28, 6.50), 0.18, 0.09),
        ((1.30, -0.58, 6.38), (2.32, 0.38, 6.62), 0.18, 0.09),
    )
    for p0, p1, r0, r1 in branches:
        p.append(L.capsule_seg(p0, p1, r0, r1, "barkDark", verts=12))

    # 3. Copa frondosa multi-tom subdiv=2 chegando a ~11.0 studs
    canopy_main = (
        (0.0, -0.08, 8.15, 2.05, (1.18, 1.12, 0.86), "leafMid"),
        (-1.95, -1.18, 7.15, 1.65, (1.14, 1.06, 0.82), "leafDeep"),
        (2.05, -0.92, 7.35, 1.62, (1.12, 1.04, 0.82), "leafSun"),
        (-1.35, 1.68, 7.30, 1.68, (1.08, 1.16, 0.80), "oliveLeaf"),
        (1.65, 1.48, 7.18, 1.58, (1.14, 1.06, 0.82), "leafDeep"),
        (0.08, 0.12, 9.68, 1.52, (1.16, 1.12, 0.86), "leafSun"),
    )
    for idx, (cx, cy, cz, rad, sq, col) in enumerate(canopy_main):
        p.append(_rot(L.ico(rad, (cx, cy, cz), col, squash=sq, subdiv=2), 0.12 * math.sin(idx), 0.15 * math.cos(idx), idx * 0.6))

    canopy_sub = (
        (-2.45, 0.32, 6.55, 1.28, (1.08, 1.12, 0.78), "oliveLeaf", 2),
        (2.42, 0.42, 6.68, 1.25, (1.06, 1.04, 0.78), "leafMid", 2),
        (0.0, -2.12, 6.85, 1.35, (1.16, 0.96, 0.80), "leafSun", 2),
        (0.18, 2.15, 6.72, 1.32, (1.12, 1.02, 0.78), "leafDeep", 1),
        (-1.05, -0.58, 8.95, 1.36, (1.08, 1.06, 0.82), "leafSun", 2),
        (1.12, 0.48, 9.05, 1.32, (1.10, 1.04, 0.80), "oliveLeaf", 1),
        (-0.85, -1.68, 7.82, 1.12, (1.08, 1.02, 0.78), "moss", 1),
        (0.95, -1.55, 7.90, 1.10, (1.06, 1.04, 0.78), "leafSun", 1),
    )
    for idx, (cx, cy, cz, rad, sq, col, sdiv) in enumerate(canopy_sub):
        p.append(_rot(L.ico(rad, (cx, cy, cz), col, squash=sq, subdiv=sdiv), 0.14 * math.cos(idx), 0.12 * math.sin(idx), idx * 0.8))

    return p


SPECS = [
    {
        "id": "backdrop.castle01.01",
        "name": "BACKDROP_castle01",
        "glb": "backdrop_castle01.glb",
        "tipo": "modulo_cenario",
        "qualidade": "hero",
        "limite": LIMITE_HERO,
        "hero_pbr": True,
        "quantidade_cena": 1,
        "center_xy": True,
        "pivot": "base",
        "suavizacao_normais": NORMALS_BACKDROP,
        "tags": ["muralha", "backdrop", "castle01"],
        "seed": L.SEED_BASE + 9101,
        "build": castle01,
    },
    {
        "id": "backdrop.keep01.01",
        "name": "BACKDROP_keep01",
        "glb": "backdrop_keep01.glb",
        "tipo": "modulo_cenario",
        "qualidade": "hero",
        "limite": LIMITE_HERO,
        "hero_pbr": True,
        "quantidade_cena": 2,
        "center_xy": True,
        "pivot": "base",
        "suavizacao_normais": NORMALS_BACKDROP,
        "tags": ["muralha", "backdrop", "keep01"],
        "seed": L.SEED_BASE + 9202,
        "build": keep01,
    },
    {
        "id": "backdrop.house01.01",
        "name": "BACKDROP_house01",
        "glb": "backdrop_house01.glb",
        "tipo": "prop_estatico",
        "qualidade": "standard",
        "limite": LIMITE_PROP,
        "hero_pbr": False,
        "quantidade_cena": 2,
        "center_xy": True,
        "pivot": "base",
        "suavizacao_normais": NORMALS_BACKDROP,
        "tags": ["muralha", "backdrop", "house01"],
        "seed": L.SEED_BASE + 9303,
        "build": house01,
    },
    {
        "id": "backdrop.house02.01",
        "name": "BACKDROP_house02",
        "glb": "backdrop_house02.glb",
        "tipo": "prop_estatico",
        "qualidade": "standard",
        "limite": LIMITE_PROP,
        "hero_pbr": False,
        "quantidade_cena": 2,
        "center_xy": True,
        "pivot": "base",
        "suavizacao_normais": NORMALS_BACKDROP,
        "tags": ["muralha", "backdrop", "house02"],
        "seed": L.SEED_BASE + 9404,
        "build": house02,
    },
    {
        "id": "backdrop.tower01.01",
        "name": "BACKDROP_tower01",
        "glb": "backdrop_tower01.glb",
        "tipo": "prop_estatico",
        "qualidade": "standard",
        "limite": LIMITE_PROP,
        "hero_pbr": False,
        "quantidade_cena": 2,
        "center_xy": True,
        "pivot": "base",
        "suavizacao_normais": NORMALS_BACKDROP,
        "tags": ["muralha", "backdrop", "tower01"],
        "seed": L.SEED_BASE + 9505,
        "build": tower01,
    },
    {
        "id": "backdrop.windmill01.01",
        "name": "BACKDROP_windmill01",
        "glb": "backdrop_windmill01.glb",
        "tipo": "prop_estatico",
        "qualidade": "standard",
        "limite": LIMITE_PROP,
        "hero_pbr": False,
        "quantidade_cena": 2,
        "center_xy": True,
        "pivot": "base",
        "suavizacao_normais": NORMALS_BACKDROP,
        "tags": ["muralha", "backdrop", "windmill01"],
        "seed": L.SEED_BASE + 9606,
        "build": windmill01,
    },
    {
        "id": "backdrop.tree01.01",
        "name": "BACKDROP_tree01",
        "glb": "backdrop_tree01.glb",
        "tipo": "prop_estatico",
        "qualidade": "standard",
        "limite": LIMITE_TREE,
        "hero_pbr": False,
        "quantidade_cena": 4,
        "center_xy": True,
        "pivot": "base",
        "suavizacao_normais": NORMALS_BACKDROP,
        "tags": ["muralha", "backdrop", "tree01"],
        "seed": L.SEED_BASE + 9707,
        "build": tree01,
    },
]

L.run_group("backdrop", SPECS, "arquitetura e natureza do vale alem da muralha (art/scripts/make_backdrop.py)", hero_pbr=False)
