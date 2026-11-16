"""Gera 7 modelos low-poly esculpidos para o vale de fundo (BACKDROP_), substituindo malhas
TripoSR e adicionando `keep01`.

Modelos (Z-up, frente=-Y, base Z=0, centrados em XY, <= 2800 tris):
  1. backdrop.castle01.01   -> BACKDROP_castle01   (backdrop_castle01.glb,   ~18 studs)
  2. backdrop.keep01.01     -> BACKDROP_keep01     (backdrop_keep01.glb,     ~20 studs)
  3. backdrop.house01.01    -> BACKDROP_house01    (backdrop_house01.glb,    ~8 studs)
  4. backdrop.house02.01    -> BACKDROP_house02    (backdrop_house02.glb,    ~8 studs)
  5. backdrop.tower01.01    -> BACKDROP_tower01    (backdrop_tower01.glb,    ~16 studs)
  6. backdrop.windmill01.01 -> BACKDROP_windmill01 (backdrop_windmill01.glb, ~16 studs)
  7. backdrop.tree01.01     -> BACKDROP_tree01     (backdrop_tree01.glb,     ~11 studs)

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

LIMITE = 2800
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


def _merlon_ring(cx, cy, z0, r, n, size, color):
    """Coroa circular de ameias (merlons) ao redor de uma torre."""
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n
        pts.append(
            L.box(
                size,
                (cx + r * math.cos(a), cy + r * math.sin(a), z0 + size[2] * 0.5),
                color,
                rot=(0.0, 0.0, a),
            )
        )
    return pts


# ---------------------------------------------------------------- 1. Castle01 (~18 studs)
def castle01():
    """Grand Citadel Castle (~18 studs): 3 torres redondas de 20 segs, coruchéus conicos slateRoof,
    muralhas de cortina, ameias e portao arqueado voltado para -Y."""
    p = []

    # Zocalo rochoso e base da cidadela
    p.append(L.cyl(6.80, 1.10, (0.0, 0.0, 0.0), "stoneDark", verts=20, r2=6.35))
    p.append(L.box((9.20, 6.80, 6.60), (0.0, 0.20, 1.10 + 3.30), "stone"))
    p.append(L.box((9.50, 7.10, 0.55), (0.0, 0.20, 7.75), "stoneLight"))

    # Ameias da muralha de cortina frontal e traseira
    for sx in (-3.6, -2.4, -1.2, 1.2, 2.4, 3.6):
        p.append(L.box((0.68, 0.48, 0.65), (sx, -3.12, 8.28), "stoneLight"))
        p.append(L.box((0.68, 0.48, 0.65), (sx, 3.52, 8.28), "stoneLight"))

    # Portao fortificado em arco na frente (-Y) + grade portcullis + brasoes
    p.append(L.box((3.40, 1.65, 6.20), (0.0, -3.15, 1.10 + 3.10), "stoneLight"))
    p.append(_pitched_roof(3.70, 1.85, 1.45, (0.0, -3.15, 7.30), "slateRoof", ridge_axis="y"))
    p.append(L.cyl_axis(1.08, 1.72, (0.0, -3.18, 3.45), "ink", axis="y", verts=16))
    p.append(L.box((2.16, 1.70, 2.35), (0.0, -3.18, 2.28), "ink"))
    p.append(L.torus(1.14, 0.14, (0.0, -3.98, 3.45), "stoneDark", major_seg=18, minor_seg=4, rot=(math.pi / 2, 0.0, 0.0)))
    for gx in (-0.64, -0.22, 0.22, 0.64):
        p.append(L.cyl(0.06, 3.10, (gx, -3.92, 1.15), "ironDark", verts=8))

    # 3 Torres redondas de 20 segmentos (2 frontais/laterais + 1 torre mestra central alta)
    towers = (
        (-4.25, -1.55, 2.05, 10.20, 4.10, False),
        (4.25, -1.55, 2.05, 10.20, 4.10, False),
        (0.0, 1.55, 2.55, 12.10, 4.35, True),
    )
    for tx, ty, rad, th, spire_h, is_main in towers:
        z_base = 1.05
        p.append(L.cyl(rad * 1.12, 1.60, (tx, ty, z_base), "stoneDark", verts=20, r2=rad))
        p.append(L.cyl(rad, th - 1.60, (tx, ty, z_base + 1.60), "stone", verts=20, r2=rad * 0.94))
        z_top = z_base + th
        p.append(L.torus(rad * 0.98, 0.14, (tx, ty, z_top - 0.35), "stoneLight", major_seg=20, minor_seg=4))
        p.append(L.cyl(rad * 1.08, 0.65, (tx, ty, z_top - 0.20), "stoneLight", verts=20, r2=rad * 1.12))
        p += _merlon_ring(tx, ty, z_top + 0.42, rad * 1.04, 8, (0.48, 0.36, 0.48), "stoneLight")
        # Coruchéu conico de 20 segmentos em slateRoof
        p.append(L.cyl(rad * 1.18, spire_h, (tx, ty, z_top + 0.38), "slateRoof", verts=20, r2=0.0))
        # Pinaculo dourado (na torre mestra chega a ~18.0 studs)
        fin_z = z_top + 0.38 + spire_h
        p.append(L.ball(0.24 if is_main else 0.18, (tx, ty, fin_z - 0.08), "gold", seg=12, rings=6))
        # Janelas iluminadas amberBright na face -Y
        p.append(L.box((0.42, 0.24, 1.15), (tx, ty - rad * 0.94, z_base + th * 0.62), "amberBright"))
        if is_main:
            p.append(L.box((0.46, 0.24, 1.25), (tx - 1.15, ty - rad * 0.86, z_base + th * 0.72), "amberBright"))
            p.append(L.box((0.46, 0.24, 1.25), (tx + 1.15, ty - rad * 0.86, z_base + th * 0.72), "amberBright"))

    return p


# ---------------------------------------------------------------- 2. Keep01 (~20 studs)
def keep01():
    """Crowned Royal Keep / Bastion Donjon (~20 studs): paredes whiteStone com contrafortes,
    4 torretas de canto, cupula dourada real e estandartes crimsonCloth."""
    p = []

    # Base escalonada de pedra
    p.append(L.box((8.80, 8.80, 1.30), (0.0, 0.0, 0.65), "stoneDark"))
    p.append(L.box((7.80, 7.80, 1.10), (0.0, 0.0, 1.85), "whiteStoneDark"))

    # Corpo principal do Donjon em whiteStone + contrafortes
    p.append(L.box((6.40, 6.40, 10.60), (0.0, 0.0, 2.40 + 5.30), "whiteStone"))
    for s1 in (-1, 1):
        for s2 in (-1.65, 1.65):
            p.append(L.box((0.68, 0.78, 9.80), (s2, s1 * 3.32, 2.40 + 4.90), "whiteStoneDark"))
            p.append(L.box((0.78, 0.68, 9.80), (s1 * 3.32, s2, 2.40 + 4.90), "whiteStoneDark"))

    # Cornija superior + ameias reais
    p.append(L.box((7.10, 7.10, 0.75), (0.0, 0.0, 13.15), "whiteStoneDark"))
    p.append(L.box((7.30, 7.30, 0.32), (0.0, 0.0, 13.68), "gold"))

    # 4 Torretas cilindricas de canto (16 segs) com agulhas slateRoof/gold
    for sx in (-1, 1):
        for sy in (-1, 1):
            tx, ty = sx * 3.15, sy * 3.15
            p.append(L.cyl(1.18, 12.20, (tx, ty, 1.80), "whiteStone", verts=16, r2=1.08))
            p.append(L.torus(1.14, 0.10, (tx, ty, 13.85), "gold", major_seg=16, minor_seg=5))
            p.append(L.cyl(1.30, 3.20, (tx, ty, 14.00), "slateRoof", verts=16, r2=0.0))
            p.append(L.ball(0.18, (tx, ty, 17.16), "gold", seg=10, rings=6))

    # Tambor octogonal/cilindrico central + Cupola Dourada Coroada ate ~20.0 studs
    p.append(L.cyl(2.35, 3.10, (0.0, 0.0, 13.50), "whiteStone", verts=18, r2=2.15))
    p.append(L.torus(2.22, 0.14, (0.0, 0.0, 16.55), "gold", major_seg=18, minor_seg=6))
    p.append(L.ball(2.12, (0.0, 0.0, 16.65), "gold", seg=18, rings=10, squash=(1.0, 1.0, 0.92)))
    p.append(L.cyl(0.55, 1.35, (0.0, 0.0, 18.35), "royal", verts=14, r2=0.12))
    p.append(L.ball(0.28, (0.0, 0.0, 19.72), "goldBright", seg=12, rings=8))

    # Estandartes reais crimsonCloth na fachada frontal (-Y) e laterais + janelas amberBright
    for sx in (-1.65, 1.65):
        p.append(L.capsule_seg((sx, -3.38, 11.80), (sx, -3.44, 6.20), 0.34, 0.24, "crimsonCloth", verts=10))
        p.append(L.capsule_seg((sx, -3.42, 6.30), (sx, -3.45, 5.45), 0.24, 0.06, "gold", verts=8))
    p.append(L.box((0.72, 0.26, 2.40), (0.0, -3.26, 9.60), "amberBright"))
    p.append(L.cyl_axis(0.88, 0.65, (0.0, -3.22, 4.10), "royal", axis="y", verts=14))
    p.append(L.box((1.76, 0.62, 1.75), (0.0, -3.22, 3.22), "ironDark"))

    return p


# ---------------------------------------------------------------- 3. House01 (~8 studs)
def house01():
    """Half-timbered cottage (~8 studs): paredes whiteStone, enxaimel woodDark, telhado de barro
    inclinado (roof), chamine de pedra e janelas amberBright."""
    p = []

    # Fundacao de pedra (z = 0.0 .. 1.15)
    p.append(L.box((5.60, 4.60, 1.15), (0.0, 0.0, 0.575), "stoneDark"))

    # Paredes whiteStone (z = 1.15 .. 4.55)
    w, d, h = 5.30, 4.30, 3.40
    z0 = 1.15
    p.append(L.box((w, d, h), (0.0, 0.0, z0 + h * 0.5), "whiteStone"))

    # Vigas de enxaimel (woodDark) horizontais, verticais e mãos-francesas diagonais
    for zv in (z0 + 0.08, z0 + h * 0.52, z0 + h - 0.08):
        p.append(L.box((w + 0.18, d + 0.18, 0.20), (0.0, 0.0, zv), "woodDark"))
    for sx in (-1, 0, 1):
        for sy in (-1, 1):
            p.append(L.box((0.20, 0.20, h + 0.10), (sx * (w * 0.48), sy * (d * 0.48), z0 + h * 0.5), "woodDark"))
    for sx in (-1, 1):
        p.append(
            L.box(
                (0.16, 0.16, 1.75),
                (sx * 1.85, -d * 0.5 - 0.04, z0 + 2.55),
                "woodDark",
                rot=(0.0, sx * 0.62, 0.0),
            )
        )

    # Telhado de telha de barro em duas aguas (z = 4.45 .. 7.55) + cumeeira de madeira
    p.append(_pitched_roof(6.10, 5.10, 3.10, (0.0, 0.0, 4.45), "roof", ridge_axis="y"))
    p.append(L.capsule_seg((0.0, -2.68, 7.52), (0.0, 2.68, 7.52), 0.16, 0.16, "woodDark", verts=12))
    # Oitão frontal e traseiro em whiteStone com travejamento
    p.append(_pitched_roof(5.26, 4.26, 2.82, (0.0, 0.0, 4.50), "whiteStone", ridge_axis="y"))

    # Chamine de pedra lateral chegando a ~8.0 studs
    p.append(L.box((0.92, 0.92, 6.40), (2.15, 0.65, 1.15 + 3.20), "stone"))
    p.append(L.box((1.08, 1.08, 0.34), (2.15, 0.65, 7.52), "stoneLight"))
    p.append(L.cyl(0.28, 0.42, (2.15, 0.65, 7.60), "stoneDark", verts=14, r2=0.24))

    # Porta arqueada frontal (-Y), janelas amberBright e floreiras
    p.append(L.box((1.05, 0.24, 1.95), (0.0, -2.18, 2.12), "wood"))
    p.append(L.cyl_axis(0.52, 0.26, (0.0, -2.18, 3.08), "woodDark", axis="y", verts=12))
    for sx in (-1.55, 1.55):
        p.append(L.box((0.86, 0.22, 0.96), (sx, -2.18, 2.95), "amberBright"))
        p.append(L.box((0.98, 0.32, 0.16), (sx, -2.26, 2.40), "woodDark"))
        p.append(L.ball(0.24, (sx, -2.32, 2.56), "leafMid", seg=10, rings=6, squash=(1.6, 0.8, 0.7)))
    p.append(L.box((0.68, 0.24, 0.78), (0.0, -2.18, 5.55), "amberBright"))

    return p


# ---------------------------------------------------------------- 4. House02 (~8 studs)
def house02():
    """Stone farmhouse (~8 studs): paredes de pedra com contrafortes, telhado arredondado de
    palha (straw), mansarda (dormer) frontal e barril de madeira."""
    p = []

    # Base e paredes rusticas de pedra (z = 0.0 .. 4.20)
    p.append(L.box((6.20, 4.80, 1.05), (0.0, 0.0, 0.525), "stoneDark"))
    p.append(L.box((5.70, 4.30, 3.20), (0.0, 0.0, 1.05 + 1.60), "stone"))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(L.box((0.58, 0.58, 3.30), (sx * 2.78, sy * 2.08, 1.05 + 1.65), "stoneLight"))

    # Telhado de palha (straw) arredondado esculpido com feixes organicos ate ~8.0 studs
    p.append(_pitched_roof(6.40, 5.10, 3.35, (0.0, 0.0, 4.15), "straw", ridge_axis="x"))
    # Camadas curvas de colmo (capsule_seg) dando silhueta macia e arredondada ao telhado
    thatch_rolls = (
        ((-2.95, 0.0, 7.42), (2.95, 0.0, 7.42), 0.58, "straw"),
        ((-3.05, -0.95, 6.35), (3.05, -0.95, 6.35), 0.52, "straw"),
        ((-3.05, 0.95, 6.35), (3.05, 0.95, 6.35), 0.52, "straw"),
        ((-3.12, -1.85, 5.15), (3.12, -1.85, 5.15), 0.46, "woodLight"),
        ((-3.12, 1.85, 5.15), (3.12, 1.85, 5.15), 0.46, "woodLight"),
    )
    for p0, p1, rad, col in thatch_rolls:
        p.append(L.capsule_seg(p0, p1, rad, rad, col, verts=14))
    # Feixes cruzados de cumeeira chegando a ~8.0 studs
    for xk in (-1.8, -0.6, 0.6, 1.8):
        p.append(L.torus(0.46, 0.09, (xk, 0.0, 7.46), "woodDark", major_seg=14, minor_seg=5, rot=(0.0, math.pi / 2, 0.0)))

    # Janela mansarda (dormer) frontal (-Y) + empena de madeira
    p.append(L.box((1.55, 1.45, 1.35), (0.0, -1.75, 5.45), "woodDark"))
    p.append(_pitched_roof(1.85, 1.65, 0.95, (0.0, -1.78, 6.08), "straw", ridge_axis="y"))
    p.append(L.box((0.78, 0.22, 0.78), (0.0, -2.48, 5.52), "amberBright"))

    # Porta de tabuas e janela terrea (-Y) + barril suave ao lado
    p.append(L.box((1.12, 0.24, 2.05), (-0.75, -2.18, 2.08), "woodDark"))
    p.append(L.box((1.15, 0.22, 0.95), (1.25, -2.18, 2.68), "amberBright"))
    # Barril de 16 segmentos junto a entrada
    bx, by, bz = -2.35, -2.42, 0.0
    p.append(L.cyl(0.46, 1.25, (bx, by, bz), "wood", verts=16, r2=0.48))
    p.append(L.torus(0.48, 0.04, (bx, by, bz + 0.30), "ironDark", major_seg=16, minor_seg=5))
    p.append(L.torus(0.48, 0.04, (bx, by, bz + 0.95), "ironDark", major_seg=16, minor_seg=5))

    return p


# ---------------------------------------------------------------- 5. Tower01 (~16 studs)
def tower01():
    """Tall stone watchtower (~16 studs): fuste de pedra afunilado 18-seg, galeria em balanco,
    coruchéu slateRoof e braseiro de sinalizacao aceso."""
    p = []

    # Base alargada de pedra (18 segs) + contrafortes
    p.append(L.cyl(2.45, 1.80, (0.0, 0.0, 0.0), "stoneDark", verts=18, r2=2.05))
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        p.append(
            L.box(
                (0.58, 0.85, 2.80),
                (1.92 * math.cos(a), 1.92 * math.sin(a), 1.40),
                "stoneDark",
                rot=(0.0, 0.0, a),
            )
        )

    # Fuste cilindrico de pedra (z = 1.80 .. 10.60) com cintas torus
    p.append(L.cyl(2.02, 4.40, (0.0, 0.0, 1.80), "stone", verts=18, r2=1.78))
    p.append(L.torus(1.82, 0.12, (0.0, 0.0, 6.20), "stoneLight", major_seg=18, minor_seg=6))
    p.append(L.cyl(1.78, 4.40, (0.0, 0.0, 6.20), "stoneLight", verts=18, r2=1.64))

    # Galeria de vigia alargada (machicolations + madeira) em z = 10.60 .. 12.20
    p.append(L.cyl(1.68, 0.65, (0.0, 0.0, 10.45), "stoneDark", verts=18, r2=2.22))
    p.append(L.cyl(2.24, 1.15, (0.0, 0.0, 11.10), "woodDark", verts=18, r2=2.20))
    p.append(L.torus(2.24, 0.10, (0.0, 0.0, 11.12), "wood", major_seg=18, minor_seg=5))
    # Colunas da galeria + coruchéu conico slateRoof ate ~16.0 studs
    for k in range(6):
        a = 2 * math.pi * k / 6
        p.append(L.cyl(0.14, 1.25, (1.92 * math.cos(a), 1.92 * math.sin(a), 12.20), "woodDark", verts=10))
    p.append(L.cyl(2.48, 2.35, (0.0, 0.0, 13.35), "slateRoof", verts=18, r2=0.0))
    p.append(L.ball(0.22, (0.0, 0.0, 15.78), "gold", seg=12, rings=6))

    # Janelas iluminadas + Braseiro de sinalizacao suspenso na frente-esquerda (-Y/-X)
    p.append(L.box((0.44, 0.24, 1.15), (0.0, -1.78, 8.20), "amberBright"))
    p.append(L.capsule_seg((-1.55, -1.25, 10.85), (-2.55, -1.95, 11.15), 0.12, 0.10, "ironDark", verts=10))
    p.append(L.cyl(0.42, 0.36, (-2.55, -1.95, 10.65), "ironDark", verts=14, r2=0.58))
    p.append(L.ball(0.42, (-2.55, -1.95, 11.08), "ember", seg=12, rings=8, squash=(1.0, 1.0, 0.65)))
    p.append(L.crystal(0.28, 0.78, (-2.55, -1.95, 11.18), "amberBright", tilt=(0.12, -0.15), verts=8))

    return p


# ---------------------------------------------------------------- 6. Windmill01 (~16 studs)
def windmill01():
    """Tapered 20-seg stone windmill tower (~16 studs): torre conica de pedra de 20 segmentos,
    cupula de madeira arredondada e 4 pas em trelica voltadas para -Y."""
    p = []

    # Base de pedra escura + torre afunilada de 20 segmentos
    p.append(L.cyl(2.85, 1.65, (0.0, 0.0, 0.0), "stoneDark", verts=20, r2=2.62))
    p.append(L.cyl(2.60, 4.80, (0.0, 0.0, 1.65), "whiteStoneDark", verts=20, r2=2.15))
    p.append(L.torus(2.18, 0.11, (0.0, 0.0, 6.45), "stone", major_seg=20, minor_seg=6))
    p.append(L.cyl(2.14, 4.65, (0.0, 0.0, 6.45), "whiteStone", verts=20, r2=1.72))
    p.append(L.torus(1.76, 0.11, (0.0, 0.0, 11.10), "woodDark", major_seg=20, minor_seg=6))

    # Varanda circular de madeira no meio da torre
    p.append(L.cyl(2.85, 0.22, (0.0, 0.0, 5.20), "wood", verts=20))
    p.append(L.torus(2.82, 0.08, (0.0, 0.0, 5.85), "woodDark", major_seg=20, minor_seg=5))

    # Cupula de madeira arredondada (domed wooden cap) + pinaculo
    p.append(L.cyl(1.82, 1.15, (0.0, 0.0, 11.10), "woodDark", verts=20, r2=1.68))
    p.append(L.ball(1.72, (0.0, 0.0, 12.25), "wood", seg=20, rings=10, squash=(1.0, 1.08, 1.05)))
    p.append(L.cyl(0.18, 1.10, (0.0, 0.0, 13.85), "gold", verts=12, r2=0.04))

    # Porta arqueada e janela frontal (-Y)
    p.append(L.box((1.10, 0.28, 2.10), (0.0, -2.56, 1.05), "woodDark"))
    p.append(L.box((0.68, 0.24, 0.92), (0.0, -2.02, 8.20), "amberBright"))

    # Eixo do rotor projetado para -Y (z = 11.65) + 4 pas em trelica (atingindo ~16.0 studs no topo)
    hub_y, hub_z = -2.35, 11.55
    p.append(L.cyl_axis(0.34, 1.55, (0.0, -1.75, hub_z), "woodDark", axis="y", verts=16))
    p.append(L.ball(0.42, (0.0, hub_y, hub_z), "ironDark", seg=14, rings=8))

    # 4 pas a 45 graus (para silhueta em X classica e altura controlada ~16.0 studs)
    sail_len = 6.10
    for k in range(4):
        ang = math.pi / 4 + k * math.pi / 2
        ca, sa = math.cos(ang), math.sin(ang)
        tip = (sail_len * ca, hub_y - 0.12, hub_z + sail_len * sa)
        # Haste principal da pa
        p.append(L.capsule_seg((0.0, hub_y, hub_z), tip, 0.13, 0.08, "woodDark", verts=10))
        # Vela de lona (parchment/straw) e travessas de trelica
        mid_r = sail_len * 0.58
        px, pz = mid_r * ca, hub_z + mid_r * sa
        off_x, off_z = -0.52 * sa, 0.52 * ca
        p.append(
            L.box(
                (sail_len * 0.74, 0.08, 0.92),
                (px + off_x, hub_y - 0.16, pz + off_z),
                "parchment" if k % 2 == 0 else "straw",
                rot=(0.0, -ang, 0.0),
            )
        )
        for frac in (0.28, 0.52, 0.76, 0.94):
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


# ---------------------------------------------------------------- 7. Tree01 (~11 studs)
def tree01():
    """Lush valley tree (~11 studs): raizes abertas, tronco curvo em capsule_seg e copa
    multi-tom subdiv=2 (leafDeep/leafMid/leafSun/oliveLeaf)."""
    p = []

    # 1. 5 Raizes abertas em capsule_seg
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.25
        p.append(
            L.capsule_seg(
                (0.28 * math.cos(a), 0.28 * math.sin(a), 0.85),
                (1.55 * math.cos(a), 1.55 * math.sin(a), 0.05),
                0.42,
                0.15,
                "barkDark",
                verts=12,
            )
        )

    # 2. Tronco curvo em 3 segmentos + 4 galhos principais em capsule_seg
    trunk = (
        ((0.0, 0.0, 0.0), (-0.12, 0.08, 2.45), 0.82, 0.64),
        ((-0.12, 0.08, 2.30), (0.10, -0.06, 4.65), 0.64, 0.48),
        ((0.10, -0.06, 4.50), (0.04, 0.02, 6.45), 0.48, 0.30),
    )
    for p0, p1, r0, r1 in trunk:
        p.append(L.capsule_seg(p0, p1, r0, r1, "barkDark", verts=16))

    branches = (
        ((0.02, 0.0, 4.85), (-1.85, -1.15, 6.85), 0.34, 0.15),
        ((0.08, -0.04, 5.10), (1.92, -0.88, 7.05), 0.32, 0.14),
        ((-0.04, 0.06, 5.35), (-1.25, 1.65, 7.15), 0.30, 0.14),
        ((0.06, 0.06, 5.50), (1.55, 1.42, 6.95), 0.28, 0.13),
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
        (-2.45, 0.32, 6.55, 1.28, (1.08, 1.12, 0.78), "oliveLeaf"),
        (2.42, 0.42, 6.68, 1.25, (1.06, 1.04, 0.78), "leafMid"),
        (0.0, -2.12, 6.85, 1.35, (1.16, 0.96, 0.80), "leafSun"),
        (0.18, 2.15, 6.72, 1.32, (1.12, 1.02, 0.78), "leafDeep"),
        (-1.05, -0.58, 8.95, 1.36, (1.08, 1.06, 0.82), "leafSun"),
        (1.12, 0.48, 9.05, 1.32, (1.10, 1.04, 0.80), "oliveLeaf"),
    )
    for idx, (cx, cy, cz, rad, sq, col) in enumerate(canopy_sub):
        p.append(_rot(L.ico(rad, (cx, cy, cz), col, squash=sq, subdiv=1), 0.14 * math.cos(idx), 0.12 * math.sin(idx), idx * 0.8))

    return p


SPECS = [
    {
        "id": "backdrop.castle01.01",
        "name": "BACKDROP_castle01",
        "glb": "backdrop_castle01.glb",
        "tipo": "prop_estatico",
        "limite": LIMITE,
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
        "tipo": "prop_estatico",
        "limite": LIMITE,
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
        "limite": LIMITE,
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
        "limite": LIMITE,
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
        "limite": LIMITE,
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
        "limite": LIMITE,
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
        "limite": LIMITE,
        "center_xy": True,
        "pivot": "base",
        "suavizacao_normais": NORMALS_BACKDROP,
        "tags": ["muralha", "backdrop", "tree01"],
        "seed": L.SEED_BASE + 9707,
        "build": tree01,
    },
]

L.run_group("backdrop", SPECS, "arquitetura e natureza do vale alem da muralha (art/scripts/make_backdrop.py)")
