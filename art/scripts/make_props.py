"""Gera 7 props de cenario e heroi low-poly esculpidos para o Bastiao (PROP_).

Props (Z-up, frente=-Y, base Z=0, centrados em XY):
  - prop.tree_pine.01      -> PROP_tree_pine      (tree_pine.glb,      <= 2800 tris, Tier-A)
  - prop.tree_oak.01       -> PROP_tree_oak       (tree_oak.glb,       <= 2800 tris, Tier-A)
  - prop.rock_cluster.01   -> PROP_rock_cluster   (rock_cluster.glb,   <= 2800 tris, Tier-A)
  - prop.siege_supply.01   -> PROP_siege_supply   (siege_supply.glb,   <= 2800 tris, Tier-A)
  - prop.iron_brazier.01   -> PROP_iron_brazier   (iron_brazier.glb,   <= 2800 tris, Tier-A)
  - prop.rift_obelisk.01   -> PROP_rift_obelisk   (rift_obelisk.glb,   <= 2800 tris, Tier-A)
  - prop.bastion_warden.01 -> PROP_bastion_warden (bastion_warden.glb, <= 3600 tris, Hero PBR)

Uso headless:
  blender -b --factory-startup --python-exit-code 1 --python art/scripts/make_props.py
Saidas: art/export/<glb>, art/forge/lote_props_import.yaml (gerado), art/renders/props/*.png
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

NORMALS_PROPS = {
    "modo": "hard_surface",
    "angulo_graus": 48,
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


def _barrel(center, r_end, r_mid, h, color, verts=20):
    """Barril curvo em 20 segmentos de aduelas arqueadas + aros torus de ferro."""
    cx, cy, z0 = center
    bm = bmesh.new()
    rings = []
    profile = (
        (0.0, r_end),
        (h * 0.22, r_mid * 0.94),
        (h * 0.50, r_mid),
        (h * 0.78, r_mid * 0.94),
        (h, r_end),
    )
    for dz, rad in profile:
        ring = []
        for k in range(verts):
            a = 2 * math.pi * k / verts
            ring.append(bm.verts.new((cx + rad * math.cos(a), cy + rad * math.sin(a), z0 + dz)))
        rings.append(ring)
    for r_idx in range(len(rings) - 1):
        r0, r1 = rings[r_idx], rings[r_idx + 1]
        for k in range(verts):
            nk = (k + 1) % verts
            bm.faces.new((r0[k], r0[nk], r1[nk], r1[k]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    parts = [_from_bm(bm, "barrel_staves", color)]
    # Aros de ferro em torus (20 segs)
    for dz, rad in (
        (h * 0.18, r_end + (r_mid - r_end) * 0.56),
        (h * 0.82, r_end + (r_mid - r_end) * 0.56),
    ):
        parts.append(
            L.torus(
                rad + 0.015,
                0.048,
                (cx, cy, z0 + dz),
                "ironDark",
                major_seg=verts,
                minor_seg=4,
                squash=(1.0, 1.0, 1.25),
            )
        )
    parts.append(L.cyl(r_end * 0.84, 0.08, (cx, cy, z0 + h - 0.04), "woodLight", verts=verts))
    parts.append(L.cyl(0.07, 0.09, (cx + r_end * 0.35, cy - r_end * 0.35, z0 + h - 0.02), "woodDark", verts=10))
    return parts


def tree_pine():
    """Pinheiro alpino esculpido: raizes e tronco em capsule_seg + 5 camadas conicas + copas ico subdiv=2."""
    p = []

    # 1. Raizes abertas + tronco curvo organico em capsule_seg
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.2
        p0 = (0.18 * math.cos(a), 0.18 * math.sin(a), 0.55)
        p1 = (0.98 * math.cos(a), 0.98 * math.sin(a), 0.04)
        p.append(L.capsule_seg(p0, p1, 0.28, 0.10, "barkDark", verts=12))

    trunk_nodes = (
        ((0.0, 0.0, 0.0), (0.08, 0.05, 2.15), 0.54, 0.42),
        ((0.08, 0.05, 2.05), (0.02, -0.04, 4.20), 0.42, 0.31),
        ((0.02, -0.04, 4.10), (0.09, -0.08, 6.35), 0.31, 0.19),
        ((0.09, -0.08, 6.25), (0.08, -0.08, 8.35), 0.19, 0.06),
    )
    for p0, p1, r0, r1 in trunk_nodes:
        p.append(L.capsule_seg(p0, p1, r0, r1, "barkDark", verts=14))

    # Galhos estruturais internos em capsule_seg
    for idx, (bz, br, ang) in enumerate(((2.55, 1.35, 0.4), (3.85, 1.15, 1.9), (5.10, 0.92, 3.5), (6.30, 0.68, 5.0))):
        p.append(
            L.capsule_seg(
                (0.05, -0.02, bz),
                (br * math.cos(ang), br * math.sin(ang), bz - 0.22),
                0.15 - idx * 0.02,
                0.05,
                "barkDark",
                verts=10,
            )
        )

    # 2. 5 camadas de saias conicas multi-segmentadas + tufos organicos subdiv=2
    tiers = (
        (2.35, 2.28, 2.15, "leafDeep", 5),
        (3.55, 1.96, 1.95, "leafMid", 5),
        (4.75, 1.66, 1.85, "leafDeep", 4),
        (5.95, 1.36, 1.70, "leafMid", 4),
        (7.05, 1.04, 1.55, "leafSun", 3),
    )
    for idx, (zt, rad, ht, col, nb) in enumerate(tiers):
        ox = 0.06 * math.cos(idx * 1.4)
        oy = 0.06 * math.sin(idx * 1.4)
        p.append(L.cyl(rad, ht, (ox, oy, zt), col, verts=14, r2=rad * 0.14, rot_z=idx * 0.45))
        for k in range(nb):
            a = 2 * math.pi * k / nb + idx * 0.62
            dist = rad * 0.58
            bx = ox + dist * math.cos(a)
            by = oy + dist * math.sin(a)
            bcol = ("leafDeep", "leafMid", "leafSun", "moss")[(idx + k) % 4]
            p.append(
                L.crystal(
                    rad * 0.42,
                    ht * 0.68,
                    (bx, by, zt + 0.18),
                    bcol,
                    tilt=(-0.42 * math.sin(a), 0.42 * math.cos(a)),
                    verts=8,
                    r2=0.05,
                )
            )

    # 4 tufos ico subdiv=2 no miolo/copa para volume organico suave + pinhas + topo em agulha
    for cx, cy, cz, cr, ccol in (
        (-0.55, -0.45, 3.10, 0.76, "moss"),
        (0.58, 0.40, 4.30, 0.72, "leafSun"),
        (-0.40, 0.48, 5.50, 0.62, "leafMid"),
        (0.32, -0.35, 6.70, 0.52, "leafSun"),
        (0.45, -0.52, 3.65, 0.58, "leafMid"),
        (-0.48, 0.36, 4.85, 0.54, "moss"),
    ):
        p.append(_rot(L.ico(cr, (cx, cy, cz), ccol, squash=(1.14, 1.06, 0.78), subdiv=2), 0.18, -0.15, cz))
    # Nos de casca e pinhas pendentes sob a saia inferior
    for k in range(4):
        ang = 0.4 + k * math.pi / 2
        p.append(L.ball(0.16, (1.18 * math.cos(ang), 1.18 * math.sin(ang), 2.28), "woodDark", seg=8, rings=5, squash=(0.85, 0.85, 1.35)))
    p.append(L.cyl(0.68, 1.65, (0.08, -0.08, 8.25), "leafSun", verts=16, r2=0.0))

    return p


def tree_oak():
    """Carvalho antigo retorcido: raizes/tronco/galhos em capsule_seg e copa organica subdiv=2."""
    p = []

    # 1. Raizes abertas, almofadas de musgo na base e tronco retorcido em capsule_seg
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.35
        p.append(
            L.capsule_seg(
                (0.24 * math.cos(a), 0.24 * math.sin(a), 0.62),
                (1.18 * math.cos(a), 1.18 * math.sin(a), 0.04),
                0.34,
                0.12,
                "barkDark",
                verts=14,
            )
        )
        if k % 2 == 0:
            p.append(_rot(L.ico(0.36, (0.76 * math.cos(a + 0.3), 0.76 * math.sin(a + 0.3), 0.22), "moss", squash=(1.2, 1.0, 0.55), subdiv=1), 0.1, 0.1, a))

    trunk_segs = (
        ((0.0, 0.0, 0.0), (-0.08, 0.10, 1.80), 0.68, 0.54),
        ((-0.08, 0.10, 1.68), (0.06, 0.0, 3.35), 0.54, 0.42),
        ((0.06, 0.0, 3.22), (0.02, -0.04, 4.55), 0.42, 0.28),
    )
    for p0, p1, r0, r1 in trunk_segs:
        p.append(L.capsule_seg(p0, p1, r0, r1, "barkDark", verts=16))
    # No de casca esculpido no tronco frontal (-Y)
    p.append(L.torus(0.18, 0.06, (0.04, -0.44, 2.35), "woodDark", major_seg=10, minor_seg=4, rot=(math.pi / 2 - 0.12, 0.0, 0.0)))

    # 2. Galhos bifurcados principais e secundarios em capsule_seg
    limbs = (
        ((-0.04, 0.02, 3.65), (-1.28, -0.92, 5.05), 0.28, 0.13),
        ((0.06, 0.02, 3.80), (1.35, -0.68, 5.20), 0.26, 0.12),
        ((-0.02, 0.08, 3.95), (-0.88, 1.18, 5.18), 0.25, 0.12),
        ((0.08, 0.06, 4.05), (1.12, 1.05, 5.10), 0.24, 0.11),
        ((-0.95, -0.68, 4.68), (-1.75, 0.18, 4.78), 0.15, 0.07),
        ((1.02, -0.48, 4.82), (1.72, 0.30, 4.92), 0.14, 0.07),
    )
    for p0, p1, r0, r1 in limbs:
        p.append(L.capsule_seg(p0, p1, r0, r1, "barkDark", verts=12))

    # 3. Copa assimetrica com 6 domos principais subdiv=2 + 8 tufos de detalhe
    main_domes = (
        (0.05, -0.10, 5.85, 1.50, (1.18, 1.12, 0.84), "leafMid"),
        (-1.42, -1.02, 5.12, 1.26, (1.12, 1.06, 0.80), "leafDeep"),
        (1.52, -0.74, 5.36, 1.22, (1.12, 1.02, 0.82), "leafSun"),
        (-0.94, 1.32, 5.30, 1.28, (1.08, 1.16, 0.78), "oliveLeaf"),
        (1.24, 1.14, 5.16, 1.18, (1.15, 1.05, 0.82), "leafDeep"),
        (0.10, 0.18, 7.05, 1.08, (1.14, 1.10, 0.80), "leafSun"),
    )
    for idx, (cx, cy, cz, rad, sq, col) in enumerate(main_domes):
        p.append(_rot(L.ico(rad, (cx, cy, cz), col, squash=sq, subdiv=2), 0.14 * math.sin(idx), 0.18 * math.cos(idx), idx * 0.5))

    accent_tufts = (
        (-1.92, 0.25, 4.68, 1.02, (1.06, 1.10, 0.80), "oliveLeaf", 2),
        (1.88, 0.35, 4.86, 1.00, (1.05, 1.02, 0.78), "leafMid", 2),
        (0.0, -1.52, 4.98, 1.08, (1.15, 0.96, 0.82), "leafSun", 2),
        (0.15, 1.58, 4.82, 1.04, (1.10, 1.00, 0.78), "leafDeep", 1),
        (-0.78, -0.48, 6.52, 1.06, (1.06, 1.04, 0.82), "leafSun", 2),
        (0.84, 0.34, 6.62, 1.04, (1.08, 1.02, 0.80), "oliveLeaf", 1),
        (-0.62, -1.28, 5.75, 0.86, (1.08, 1.02, 0.78), "moss", 1),
        (0.72, -1.16, 5.82, 0.84, (1.06, 1.04, 0.78), "leafSun", 1),
    )
    for idx, (cx, cy, cz, rad, sq, col, sdiv) in enumerate(accent_tufts):
        p.append(_rot(L.ico(rad, (cx, cy, cz), col, squash=sq, subdiv=sdiv), 0.16 * math.cos(idx), 0.15 * math.sin(idx), idx * 0.7))

    return p


def rock_cluster():
    """Afloramento de rochas estratificadas chanfradas, almofadas de musgo e drusa de quartzo ambar."""
    p = []

    boulders = (
        ((0.0, 0.10, 0.95), 1.46, (1.22, 0.96, 1.05), "stoneDark", (0.22, -0.18, 0.40), 3),
        ((-1.15, -0.55, 0.62), 1.04, (1.15, 0.90, 0.82), "stone", (-0.30, 0.25, 1.15), 3),
        ((1.10, -0.30, 0.58), 0.96, (1.05, 1.18, 0.78), "stoneLight", (0.18, 0.34, 2.10), 2),
        ((-0.45, 0.95, 0.52), 0.90, (1.10, 0.88, 0.75), "stone", (0.40, -0.12, 0.85), 2),
        ((0.65, 0.85, 0.44), 0.78, (1.18, 0.92, 0.68), "stoneDark", (-0.18, 0.32, 1.65), 2),
    )
    for pos, rad, sq, col, (rx, ry, rz), sdiv in boulders:
        p.append(_rot(L.ico(rad, pos, col, squash=sq, subdiv=sdiv), rx, ry, rz))

    # Lajes de xisto chanfradas nos degraus geologicos
    for sz, pos, col, rot in (
        ((1.55, 1.15, 0.34), (-0.75, -0.82, 0.20), "stoneDark", (0.08, -0.10, 0.28)),
        ((1.35, 1.05, 0.30), (0.88, -0.78, 0.18), "stone", (-0.06, 0.12, -0.35)),
        ((1.18, 0.92, 0.28), (0.15, 1.12, 0.16), "stoneLight", (0.10, 0.05, 0.18)),
    ):
        p.append(L.box(sz, pos, col, bevel=0.05, rot=rot))

    # Almofadas de musgo organicas
    for pos, rad, sq, rot_z in (
        ((-0.25, -0.20, 1.88), 0.64, (1.28, 1.10, 0.45), 0.4),
        ((-1.25, -0.60, 1.15), 0.50, (1.18, 1.05, 0.44), 1.3),
        ((0.95, -0.35, 1.05), 0.46, (1.15, 0.95, 0.42), 2.1),
        ((0.35, 0.78, 0.82), 0.42, (1.12, 0.96, 0.40), 0.9),
    ):
        p.append(_rot(L.ico(rad, pos, "moss", squash=sq, subdiv=2), 0.1, -0.1, rot_z))

    # Drusa rica de quartzo ambar brotando da fenda frontal (-Y)
    for pos, r, h, col, tilt in (
        ((0.28, -0.78, 0.45), 0.20, 0.96, "amber", (0.48, 0.22)),
        ((0.52, -0.72, 0.38), 0.16, 0.76, "amberBright", (0.58, 0.42)),
        ((0.08, -0.84, 0.36), 0.15, 0.70, "amber", (0.62, -0.18)),
        ((0.38, -0.62, 0.55), 0.14, 0.62, "amberBright", (0.28, 0.32)),
        ((-0.12, -0.76, 0.42), 0.13, 0.56, "neonAmber", (0.52, -0.34)),
        ((0.68, -0.58, 0.44), 0.12, 0.50, "goldBright", (0.44, 0.52)),
        ((-0.28, -0.82, 0.32), 0.11, 0.46, "amber", (0.66, -0.42)),
    ):
        p.append(L.crystal(r, h, pos, col, tilt=tilt, verts=8))

    return p


def siege_supply():
    """Suprimentos de cerco: palete, 2 barris de 20 segs, caixote ferrado chanfrado, rolo de corda e balas."""
    p = []

    # 1. Palete de madeira
    for sy in (-1.35, 0.0, 1.35):
        p.append(L.box((4.10, 0.28, 0.20), (0.0, sy, 0.10), "woodDark"))
    for k in range(5):
        sx = -1.75 + k * 0.875
        p.append(L.box((0.55, 3.20, 0.12), (sx, 0.0, 0.26), "wood"))

    # 2. Dois barris de carvalho com aduelas curvas (20 segs), aros torus e rolo de corda no topo
    p += _barrel((-1.15, -0.65, 0.32), 0.58, 0.73, 1.65, "wood", verts=20)
    p += _barrel((-0.95, 0.82, 0.32), 0.54, 0.69, 1.55, "woodLight", verts=20)
    p.append(L.torus(0.28, 0.065, (-0.95, 0.82, 1.92), "straw", major_seg=12, minor_seg=4))
    p.append(L.torus(0.19, 0.055, (-0.95, 0.82, 1.98), "straw", major_seg=10, minor_seg=4))

    # 3. Caixote de municao chanfrado com travamentos diagonais em madeira e cantoneiras de ferro
    cx, cy, cz = 1.05, 0.62, 0.32
    cw, cd, ch = 1.65, 1.45, 1.25
    p.append(L.box((cw, cd, ch), (cx, cy, cz + ch / 2), "woodDark", bevel=0.03))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(L.box((0.18, 0.18, ch + 0.06), (cx + sx * (cw / 2 - 0.05), cy + sy * (cd / 2 - 0.05), cz + ch / 2), "woodLight"))
            p.append(L.box((0.24, 0.24, 0.22), (cx + sx * (cw / 2 - 0.02), cy + sy * (cd / 2 - 0.02), cz + ch - 0.06), "ironDark"))
    for sy in (-1, 1):
        p.append(L.box((cw + 0.06, 0.14, 0.16), (cx, cy + sy * (cd / 2 - 0.02), cz + ch - 0.04), "wood"))
        p.append(L.box((cw * 0.95, 0.12, 0.14), (cx, cy + sy * (cd / 2 + 0.02), cz + ch / 2), "woodLight", rot=(0, 0.58 * sy, 0)))
    for sx in (-1, 1):
        p.append(L.box((0.14, cd + 0.06, 0.16), (cx + sx * (cw / 2 - 0.02), cy, cz + ch - 0.04), "wood"))
        p.append(L.box((0.14, cd + 0.08, 0.14), (cx + sx * (cw / 2 - 0.02), cy, cz + 0.25), "ironDark"))

    # 4. Piramide de balas de canhao esfericas suaves (seg=16) na bandeja frontal ferrada
    tx, ty, tz = 0.92, -0.82, 0.32
    for dx in (-0.65, 0.65):
        p.append(L.box((0.14, 1.28, 0.20), (tx + dx, ty, tz + 0.10), "woodDark"))
    for dy in (-0.57, 0.57):
        p.append(L.box((1.38, 0.14, 0.20), (tx, ty + dy, tz + 0.10), "woodDark"))
    r_ball = 0.27
    for dx in (-0.27, 0.27):
        for dy in (-0.27, 0.27):
            p.append(L.ball(r_ball, (tx + dx, ty + dy, tz + r_ball + 0.04), "ironDark", seg=16, rings=6))
    p.append(L.ball(r_ball, (tx, ty, tz + r_ball + 0.42), "steel", seg=16, rings=6))

    return p


def iron_brazier():
    """Braseiro de ferro forjado 22-seg: pedestal com anel de bronze, garras curvas, pontas e chama."""
    p = []

    # 1. Pedestal escalonado 14-seg em stoneDark / stone com anel de bronze
    p.append(L.cyl(1.46, 0.34, (0, 0, 0.0), "stoneDark", verts=14, r2=1.38))
    p.append(L.cyl(1.20, 0.30, (0, 0, 0.34), "stone", verts=14, r2=1.12))
    p.append(L.cyl(0.96, 0.24, (0, 0, 0.64), "stoneDark", verts=14, r2=0.88))
    p.append(L.torus(0.90, 0.045, (0, 0, 0.88), "bronze", major_seg=16, minor_seg=4))

    # 2. 3 pernas curvas de ferro forjado a 120 graus + anel torus estrutural
    p.append(L.torus(0.94, 0.075, (0, 0, 1.52), "ironDark", major_seg=22, minor_seg=5))
    for k in range(3):
        a = 2 * math.pi * k / 3 - math.pi / 2
        ca, sa = math.cos(a), math.sin(a)
        p.append(L.capsule_seg((0.76 * ca, 0.76 * sa, 0.88), (1.02 * ca, 1.02 * sa, 0.96), 0.16, 0.11, "ironDark", verts=8))
        p.append(L.capsule_seg((0.88 * ca, 0.88 * sa, 0.96), (1.04 * ca, 1.04 * sa, 1.68), 0.14, 0.12, "iron", verts=8))
        p.append(L.capsule_seg((1.04 * ca, 1.04 * sa, 1.64), (1.18 * ca, 1.18 * sa, 2.42), 0.13, 0.15, "ironDark", verts=8))
        p.append(L.torus(0.18, 0.045, (1.24 * ca, 1.24 * sa, 2.34), "bronze", major_seg=10, minor_seg=4, rot=(math.pi / 2, 0.0, a)))

    # 3. Bojo afunilado de 22 segmentos + borda torus com rebites e pontas de bronze
    p.append(L.cyl(0.56, 0.36, (0, 0, 1.84), "ironDark", verts=22, r2=0.94))
    p.append(L.cyl(0.94, 0.56, (0, 0, 2.20), "iron", verts=22, r2=1.30))
    p.append(L.cyl(1.32, 0.22, (0, 0, 2.72), "ironDark", verts=22, r2=1.36))
    p.append(L.torus(1.34, 0.085, (0, 0, 2.82), "iron", major_seg=22, minor_seg=5))
    for k in range(8):
        a = 2 * math.pi * k / 8
        p.append(L.ball(0.085, (1.36 * math.cos(a), 1.36 * math.sin(a), 2.84), "steel", seg=6, rings=4))
        if k % 2 == 0:
            p.append(L.crystal(0.09, 0.28, (1.35 * math.cos(a), 1.35 * math.sin(a), 2.90), "bronze", tilt=(-0.18 * math.sin(a), 0.18 * math.cos(a)), verts=5))

    # 4. Leito de brasas subdiv=2, carvoes incandescentes e chama multi-lingua esculpida
    p.append(_rot(L.ico(0.90, (0, 0, 2.86), "danger", squash=(1.06, 1.06, 0.50), subdiv=2), 0.1, 0.2, 0.5))
    for k in range(4):
        ca, sa = math.cos(k * 1.57 + 0.4), math.sin(k * 1.57 + 0.4)
        p.append(L.ico(0.22, (0.58 * ca, 0.58 * sa, 2.98), "ember", squash=(1.1, 0.9, 0.65), subdiv=1))
    p.append(L.capsule_seg((0.0, 0.0, 2.88), (0.06, -0.05, 3.45), 0.34, 0.20, "emberDeep", verts=8))
    p.append(L.capsule_seg((0.06, -0.05, 3.40), (-0.04, 0.04, 3.85), 0.20, 0.09, "amberBright", verts=8))
    p.append(L.crystal(0.10, 0.38, (-0.04, 0.04, 3.80), "neonAmber", tilt=(0.08, -0.10), verts=6))
    tongues = (
        (0.0, 0.38, 0.24, 0.86, "amberBright", "neonAmber", (0.18, -0.22)),
        (1.26, 0.42, 0.22, 0.78, "ember", "amberBright", (-0.26, 0.18)),
        (2.51, 0.36, 0.21, 0.74, "danger", "ember", (0.28, 0.24)),
        (3.77, 0.40, 0.23, 0.80, "emberDeep", "amberBright", (-0.22, -0.28)),
        (5.03, 0.38, 0.20, 0.70, "amber", "neonAmber", (0.20, -0.24)),
    )
    for ang, dist, rad, h, col1, col2, tilt in tongues:
        bx, by = dist * math.cos(ang), dist * math.sin(ang)
        mx, my = (dist * 0.72) * math.cos(ang + 0.28), (dist * 0.72) * math.sin(ang + 0.28)
        p.append(L.capsule_seg((bx, by, 2.92), (mx, my, 2.92 + h * 0.55), rad, rad * 0.52, col1, verts=8))
        p.append(L.crystal(rad * 0.54, h * 0.58, (mx, my, 2.90 + h * 0.52), col2, tilt=tilt, verts=6))

    return p


def rift_obelisk():
    """Obelisco da fenda: base em obsidiana com runas, fuste torcido runico, giroscopio triplo e cristais."""
    p = []

    # 1. Base escalonada de obsidiana (14 segs) + 4 garras laterais + runas no degrau
    p.append(L.cyl(1.76, 0.42, (0, 0, 0.0), "ironDark", verts=14, r2=1.56))
    p.append(L.cyl(1.44, 0.36, (0, 0, 0.42), "obsidian", verts=14, r2=1.24))
    p.append(L.cyl(1.14, 0.32, (0, 0, 0.78), "ink", verts=14, r2=0.96))
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        p.append(
            L.crystal(
                0.34,
                1.28,
                (1.18 * math.cos(a), 1.18 * math.sin(a), 0.24),
                "ironDark",
                tilt=(0.35 * math.sin(a), -0.35 * math.cos(a)),
                verts=6,
            )
        )
        ra = k * math.pi / 2
        p.append(L.box((0.46, 0.16, 0.14), (1.36 * math.cos(ra), 1.36 * math.sin(ra), 0.60), "arcaneCyan", rot=(0, 0, ra + math.pi / 2)))

    # 2. Obelisco facetado torcido em 4 segmentos (verts=8) + entalhes runicos luminosos + ponta piramidal
    segs = (
        (1.08, 0.84, 0.72, 1.25, 0.0, "ink"),
        (2.25, 0.74, 0.64, 1.25, 0.22, "obsidian"),
        (3.42, 0.66, 0.56, 1.25, 0.44, "ink"),
        (4.58, 0.58, 0.46, 1.20, 0.66, "obsidianLight"),
    )
    for z0, r1, r2, h, rz, col in segs:
        p.append(L.cyl(r1, h, (0, 0, z0), col, verts=8, r2=r2, rot_z=math.pi / 8 + rz))
    for k in range(4):
        a = k * math.pi / 2
        p.append(L.box((0.14, 0.12, 0.76), (0.68 * math.cos(a + 0.11), 0.68 * math.sin(a + 0.11), 2.18), "tealSwarm", rot=(0, 0, a + 0.11)))
        p.append(L.box((0.12, 0.10, 0.68), (0.52 * math.cos(a + 0.55), 0.52 * math.sin(a + 0.55), 4.55), "eyeNeon", rot=(0, 0, a + 0.55)))
    p.append(L.cyl(0.48, 1.18, (0, 0, 5.75), "ink", verts=8, r2=0.0, rot_z=math.pi / 8 + 0.88))

    # 3. Colar de contencao com aneis torus de ferro e giroscopio triplo arcano
    p.append(L.cyl(0.84, 0.44, (0, 0, 3.15), "iron", verts=14, r2=0.80))
    p.append(L.torus(0.88, 0.095, (0, 0, 3.37), "steel", major_seg=20, minor_seg=6))
    p.append(L.torus(0.98, 0.075, (0, 0, 1.12), "ironDark", major_seg=20, minor_seg=5))
    p.append(L.torus(1.08, 0.055, (0, 0, 3.37), "teal", major_seg=20, minor_seg=6, rot=(0.32, -0.24, 0.0)))
    p.append(L.torus(0.86, 0.050, (0, 0, 4.92), "arcaneCyan", major_seg=18, minor_seg=5, rot=(-0.28, 0.30, 0.4)))
    p.append(L.torus(0.62, 0.042, (0, 0, 6.22), "tealSwarm", major_seg=16, minor_seg=5, rot=(0.34, 0.22, -0.3)))
    for k in range(4):
        a = k * math.pi / 2 + 0.33
        p.append(L.box((0.26, 0.32, 0.52), (0.82 * math.cos(a), 0.82 * math.sin(a), 3.37), "steel", rot=(0, 0, a)))

    # 4. Cristais da fenda brotando da base, colar e topo + nucleo subdiv=2
    shards = (
        ((-0.78, -0.62, 0.75), 0.22, 1.25, "teal", (0.38, 0.28)),
        ((0.82, -0.45, 0.72), 0.20, 1.15, "tealSwarm", (0.32, -0.38)),
        ((-0.45, 0.85, 0.70), 0.18, 1.05, "eyeNeon", (-0.42, 0.22)),
        ((0.68, 0.72, 0.74), 0.20, 1.20, "teal", (-0.36, -0.34)),
        ((0.0, -0.64, 3.35), 0.17, 1.05, "eyeNeon", (0.72, 0.0)),
        ((-0.58, 0.25, 3.45), 0.16, 0.95, "tealSwarm", (-0.28, 0.65)),
        ((0.55, 0.28, 3.40), 0.16, 0.92, "teal", (-0.25, -0.68)),
        ((0.18, -0.45, 4.95), 0.15, 0.88, "eyeNeon", (0.55, -0.25)),
        ((-0.24, 0.42, 5.02), 0.14, 0.82, "arcaneCyan", (-0.52, 0.28)),
    )
    for pos, r, h, col, tilt in shards:
        p.append(L.crystal(r, h, pos, col, tilt=tilt, verts=7))
    p.append(_rot(L.ico(0.30, (0.0, 0.0, 7.22), "eyeNeon", squash=(0.76, 0.76, 1.44), subdiv=2), 0.1, 0.15, 0.4))

    return p


def bastion_warden():
    """Hero PBR: Paladino Guardiao do Bastiao (~6.2 studs, frente -Y): greathelm emplumado coroado com visor T
    amberBright, gorget e ombreiras em camadas douradas, manto crimsonCloth pregueado, peitoral com
    brasao solar, grevas, escudo-torre heráldico (-X) e martelo runico de guerra (+X)."""
    p = []

    # 1. Botas blindadas (sabatons), grevas, joelheiras e coxotes (z = 0.0 .. 2.30)
    for sx in (-1, 1):
        lx = sx * 0.46
        p.append(L.cyl(0.28, 0.22, (lx, -0.06, 0.0), "ironDark", verts=8, r2=0.26))
        p.append(L.ball(0.26, (lx, -0.24, 0.18), "steel", seg=8, rings=4, squash=(0.92, 1.38, 0.68)))
        p.append(L.cyl(0.22, 0.10, (lx, -0.10, 0.22), "gold", verts=8))
        p.append(L.capsule_seg((lx, -0.04, 0.26), (lx, -0.06, 1.18), 0.24, 0.27, "royal", verts=8))
        p.append(L.capsule_seg((lx, -0.12, 0.34), (lx, -0.14, 1.12), 0.18, 0.20, "steel", verts=6))
        p.append(L.ball(0.27, (lx, -0.14, 1.24), "gold", seg=8, rings=4, squash=(0.95, 1.05, 0.90)))
        p.append(L.capsule_seg((lx, -0.04, 1.28), (lx, 0.0, 2.22), 0.28, 0.33, "steel", verts=8))
        p.append(
            _rot(
                L.ball(0.34, (sx * 0.68, -0.04, 2.08), "royal", seg=8, rings=4, squash=(0.38, 0.95, 1.18)),
                0.0,
                sx * 0.24,
                0.0,
            )
        )
        p.append(
            _rot(
                L.ball(0.35, (sx * 0.70, -0.04, 1.82), "gold", seg=8, rings=3, squash=(0.36, 0.92, 0.38)),
                0.0,
                sx * 0.24,
                0.0,
            )
        )

    # 2. Cinturao dourado em torus, fivela chanfrada e tabardo frontal em crimsonCloth
    p.append(L.cyl(0.62, 0.42, (0, 0.0, 2.05), "ironDark", verts=10, r2=0.66))
    p.append(L.torus(0.66, 0.09, (0, -0.02, 2.38), "gold", major_seg=12, minor_seg=4, squash=(1.08, 0.88, 1.0)))
    p.append(L.box((0.36, 0.16, 0.34), (0, -0.62, 2.38), "gold", bevel=0.03))
    p.append(L.ball(0.11, (0, -0.69, 2.38), "amberBright", seg=6, rings=4))
    p.append(L.capsule_seg((0, -0.52, 2.28), (0, -0.58, 0.88), 0.26, 0.18, "crimsonCloth", verts=6))
    p.append(L.capsule_seg((0, -0.55, 0.92), (0, -0.58, 0.72), 0.19, 0.08, "gold", verts=6))

    # 3. Peitoral blindado canelado (royal/steel) + gorget dourado + brasao solar amberBright
    p.append(L.cyl(0.68, 1.65, (0, 0.0, 2.42), "royal", verts=12, r2=0.84))
    p.append(L.ball(0.76, (0, -0.10, 3.42), "steel", seg=10, rings=5, squash=(1.08, 0.82, 1.05)))
    p.append(L.ball(0.72, (0, -0.16, 3.46), "royal", seg=10, rings=4, squash=(0.96, 0.78, 0.94)))
    p.append(L.cyl(0.66, 0.24, (0, -0.04, 4.02), "steel", verts=10, r2=0.58))
    p.append(L.torus(0.60, 0.085, (0, -0.04, 4.18), "gold", major_seg=12, minor_seg=4, squash=(1.12, 0.92, 1.0)))
    # Brasao solar e nervuras do peito (-Y)
    p.append(L.cyl_axis(0.28, 0.14, (0, -0.72, 3.48), "gold", axis="y", verts=10))
    p.append(L.ball(0.17, (0, -0.78, 3.48), "amberBright", seg=8, rings=4, squash=(1.0, 0.55, 1.25)))
    for sx in (-1, 1):
        p.append(L.capsule_seg((sx * 0.12, -0.74, 3.44), (sx * 0.44, -0.68, 3.70), 0.08, 0.04, "goldBright", verts=6))
        p.append(L.capsule_seg((sx * 0.14, -0.72, 3.36), (sx * 0.38, -0.66, 3.16), 0.065, 0.035, "gold", verts=6))

    # 4. Ombreiras curvas em camadas com aro torus dourado e crista alada
    for sx in (-1, 1):
        px = sx * 1.08
        p.append(
            _rot(
                L.ball(0.56, (px, -0.02, 3.98), "royal", seg=8, rings=4, squash=(1.12, 0.96, 0.82)),
                0.0,
                sx * 0.32,
                0.0,
            )
        )
        p.append(
            _rot(
                L.ball(0.48, (px * 1.04, -0.02, 4.22), "steel", seg=8, rings=4, squash=(1.05, 0.90, 0.72)),
                0.0,
                sx * 0.26,
                0.0,
            )
        )
        p.append(
            L.torus(
                0.54,
                0.075,
                (px * 1.02, -0.02, 3.92),
                "gold",
                major_seg=10,
                minor_seg=4,
                rot=(0.0, sx * 0.42, 0.0),
                squash=(1.05, 0.92, 1.0),
            )
        )
        p.append(L.crystal(0.15, 0.68, (px * 1.05, 0.04, 4.34), "gold", tilt=(-0.18, sx * 0.42), verts=5))

    # 5. Manto esvoacante (crimsonCloth) nas costas (+Y) com broches dourados
    for sx in (-1, 1):
        p.append(L.cyl_axis(0.18, 0.14, (sx * 0.62, -0.42, 4.08), "gold", axis="y", verts=8))
    cape_folds = (
        (0.0, 0.52, 4.12, 0.0, 0.96, 0.42, 0.42, 0.56, "crimsonCloth"),
        (-0.38, 0.48, 4.08, -0.62, 0.92, 0.44, 0.34, 0.44, "crimsonBright"),
        (0.38, 0.48, 4.08, 0.62, 0.92, 0.44, 0.34, 0.44, "crimsonBright"),
        (-0.68, 0.42, 4.00, -1.02, 0.84, 0.50, 0.26, 0.34, "crimsonCloth"),
        (0.68, 0.42, 4.00, 1.02, 0.84, 0.50, 0.26, 0.34, "crimsonCloth"),
    )
    for x0, y0, z0, x1, y1, z1, r0, r1, col in cape_folds:
        p.append(L.capsule_seg((x0, y0, z0), (x1, y1, z1), r0, r1, col, verts=6))
    p.append(L.capsule_seg((-0.98, 0.88, 0.46), (0.98, 0.88, 0.46), 0.14, 0.14, "gold", verts=6))

    # 6. Greathelm emplumado coroado (royal/steel/gold) + visor T amberBright
    p.append(L.cyl(0.48, 0.88, (0, -0.04, 4.28), "steel", verts=12, r2=0.45))
    p.append(L.ball(0.47, (0, -0.04, 5.14), "royal", seg=10, rings=5, squash=(0.96, 1.04, 0.72)))
    p.append(L.torus(0.47, 0.06, (0, -0.04, 5.06), "gold", major_seg=12, minor_seg=4))
    for k in range(5):
        ang = -0.9 + k * 0.45
        p.append(L.crystal(0.065, 0.24, (0.45 * math.sin(ang), -0.04 - 0.45 * math.cos(ang), 5.10), "goldBright", verts=5))
    # Visor em T brilhante (amberBright) na face -Y
    p.append(L.capsule_seg((-0.30, -0.49, 4.86), (0.30, -0.49, 4.86), 0.075, 0.075, "amberBright", verts=6))
    p.append(L.capsule_seg((0.0, -0.50, 4.88), (0.0, -0.48, 4.42), 0.068, 0.052, "amberBright", verts=6))
    for sx in (-1, 1):
        p.append(L.capsule_seg((sx * 0.24, -0.44, 4.72), (sx * 0.16, -0.44, 4.36), 0.12, 0.09, "gold", verts=6))
    # Crista dourada e pluma heroica curvada ate ~6.2 studs
    p.append(L.capsule_seg((0, -0.28, 5.38), (0, 0.34, 5.56), 0.11, 0.13, "gold", verts=6))
    p.append(L.capsule_seg((0, -0.18, 5.52), (0, 0.22, 6.04), 0.18, 0.24, "crimsonBright", verts=6))
    p.append(L.capsule_seg((0, 0.18, 6.02), (0, 0.78, 5.72), 0.24, 0.16, "crimsonCloth", verts=6))
    p.append(L.capsule_seg((0, 0.72, 5.74), (0, 1.15, 5.18), 0.16, 0.07, "crimsonBright", verts=6))

    # 7. Braco esquerdo (-X) + Escudo-Torre ornamentado (royal + gold + rebites)
    p.append(L.capsule_seg((-1.02, -0.04, 3.82), (-1.18, -0.32, 3.05), 0.22, 0.19, "steel", verts=8))
    p.append(L.ball(0.20, (-1.20, -0.34, 3.02), "gold", seg=6, rings=3))
    p.append(L.capsule_seg((-1.20, -0.36, 2.98), (-1.12, -0.68, 2.68), 0.20, 0.18, "royal", verts=8))
    sh_x, sh_y, sh_z = -1.24, -0.82, 2.68
    p.append(
        _rot(
            L.ball(1.42, (sh_x, sh_y, sh_z), "royal", seg=10, rings=5, squash=(0.68, 0.18, 1.08)),
            0.0,
            0.0,
            -0.32,
        )
    )
    p.append(
        _rot(
            L.torus(0.92, 0.085, (sh_x - 0.06, sh_y - 0.12, sh_z), "gold", major_seg=12, minor_seg=4, rot=(math.pi / 2, 0.0, -0.32), squash=(0.86, 1.42, 1.0)),
            0.0,
            0.0,
            0.0,
        )
    )
    p.append(L.capsule_seg((sh_x - 0.10, sh_y - 0.22, sh_z - 1.18), (sh_x - 0.10, sh_y - 0.22, sh_z + 1.18), 0.08, 0.08, "gold", verts=6))
    p.append(L.capsule_seg((sh_x - 0.38, sh_y - 0.08, sh_z), (sh_x + 0.18, sh_y - 0.36, sh_z), 0.08, 0.08, "gold", verts=6))
    p.append(L.ball(0.22, (sh_x - 0.12, sh_y - 0.26, sh_z + 0.08), "amberBright", seg=6, rings=4))
    for dz in (-0.75, 0.75):
        p.append(L.ball(0.08, (sh_x - 0.36, sh_y - 0.08, sh_z + dz), "goldBright", seg=6, rings=3))
        p.append(L.ball(0.08, (sh_x + 0.16, sh_y - 0.34, sh_z + dz), "goldBright", seg=6, rings=3))

    # 8. Braco direito (+X) + Martelo de Guerra do Forjador de Runas
    p.append(L.capsule_seg((1.02, -0.04, 3.82), (1.20, -0.34, 3.08), 0.22, 0.19, "steel", verts=8))
    p.append(L.ball(0.20, (1.22, -0.36, 3.04), "gold", seg=6, rings=3))
    p.append(L.capsule_seg((1.22, -0.38, 3.00), (1.26, -0.78, 2.86), 0.20, 0.19, "royal", verts=8))
    p.append(L.ball(0.21, (1.28, -0.86, 2.84), "gold", seg=6, rings=3))
    h_bot = (1.24, -0.62, 1.42)
    h_top = (1.32, -1.08, 4.48)
    p.append(L.capsule_seg(h_bot, h_top, 0.10, 0.11, "woodDark", verts=8))
    p.append(L.ball(0.16, h_bot, "gold", seg=6, rings=3))
    p.append(L.torus(0.14, 0.045, (1.30, -1.00, 3.92), "gold", major_seg=8, minor_seg=3))
    hm_c = (1.32, -1.06, 4.28)
    p.append(L.cyl_axis(0.36, 1.12, hm_c, "steel", axis="y", verts=10))
    p.append(L.cyl_axis(0.40, 0.26, (hm_c[0], hm_c[1] - 0.46, hm_c[2]), "ironDark", axis="y", verts=10))
    p.append(L.torus(0.38, 0.055, (hm_c[0], hm_c[1] - 0.30, hm_c[2]), "gold", major_seg=10, minor_seg=3, rot=(math.pi / 2, 0, 0)))
    p.append(L.torus(0.38, 0.055, (hm_c[0], hm_c[1] + 0.30, hm_c[2]), "gold", major_seg=10, minor_seg=3, rot=(math.pi / 2, 0, 0)))
    p.append(L.crystal(0.22, 0.58, (hm_c[0], hm_c[1] + 0.52, hm_c[2]), "gold", tilt=(-math.pi / 2, 0.0), verts=6))
    p.append(L.ball(0.19, (hm_c[0], hm_c[1] - 0.58, hm_c[2]), "amberBright", seg=6, rings=3, squash=(0.95, 0.45, 0.95)))
    for sx in (-1, 1):
        p.append(L.ball(0.14, (hm_c[0] + sx * 0.34, hm_c[1], hm_c[2]), "neonAmber", seg=6, rings=3, squash=(0.45, 1.15, 0.95)))

    return p


SPECS = [
    {
        "id": "prop.tree_pine.01",
        "name": "PROP_tree_pine",
        "glb": "tree_pine.glb",
        "tipo": "prop_estatico",
        "limite": 2800,
        "hero_pbr": False,
        "quantidade_cena": 2,
        "center_xy": True,
        "pivot": "base",
        "suavizacao_normais": NORMALS_PROPS,
        "tags": ["muralha", "prop", "nature", "tree_pine"],
        "seed": L.SEED_BASE + 7101,
        "build": tree_pine,
    },
    {
        "id": "prop.tree_oak.01",
        "name": "PROP_tree_oak",
        "glb": "tree_oak.glb",
        "tipo": "prop_estatico",
        "limite": 2800,
        "hero_pbr": False,
        "quantidade_cena": 2,
        "center_xy": True,
        "pivot": "base",
        "suavizacao_normais": NORMALS_PROPS,
        "tags": ["muralha", "prop", "nature", "tree_oak"],
        "seed": L.SEED_BASE + 7202,
        "build": tree_oak,
    },
    {
        "id": "prop.rock_cluster.01",
        "name": "PROP_rock_cluster",
        "glb": "rock_cluster.glb",
        "tipo": "prop_estatico",
        "limite": 2800,
        "hero_pbr": False,
        "quantidade_cena": 2,
        "center_xy": True,
        "pivot": "base",
        "suavizacao_normais": NORMALS_PROPS,
        "tags": ["muralha", "prop", "nature", "rock"],
        "seed": L.SEED_BASE + 7303,
        "build": rock_cluster,
    },
    {
        "id": "prop.siege_supply.01",
        "name": "PROP_siege_supply",
        "glb": "siege_supply.glb",
        "tipo": "prop_estatico",
        "limite": 2800,
        "hero_pbr": False,
        "quantidade_cena": 2,
        "center_xy": True,
        "pivot": "base",
        "suavizacao_normais": NORMALS_PROPS,
        "tags": ["muralha", "prop", "siege", "supply"],
        "seed": L.SEED_BASE + 7404,
        "build": siege_supply,
    },
    {
        "id": "prop.iron_brazier.01",
        "name": "PROP_iron_brazier",
        "glb": "iron_brazier.glb",
        "tipo": "prop_estatico",
        "limite": 2800,
        "hero_pbr": False,
        "quantidade_cena": 2,
        "center_xy": True,
        "pivot": "base",
        "suavizacao_normais": NORMALS_PROPS,
        "tags": ["muralha", "prop", "brazier", "light"],
        "seed": L.SEED_BASE + 7505,
        "build": iron_brazier,
    },
    {
        "id": "prop.rift_obelisk.01",
        "name": "PROP_rift_obelisk",
        "glb": "rift_obelisk.glb",
        "tipo": "prop_estatico",
        "limite": 2800,
        "hero_pbr": False,
        "quantidade_cena": 2,
        "center_xy": True,
        "pivot": "base",
        "suavizacao_normais": NORMALS_PROPS,
        "tags": ["muralha", "prop", "rift", "obelisk"],
        "seed": L.SEED_BASE + 7606,
        "build": rift_obelisk,
    },
    {
        "id": "prop.bastion_warden.01",
        "name": "PROP_bastion_warden",
        "glb": "bastion_warden.glb",
        "tipo": "prop_estatico",
        "limite": 3600,
        "hero_pbr": True,
        "quantidade_cena": 2,
        "center_xy": True,
        "pivot": "base",
        "suavizacao_normais": NORMALS_PROPS,
        "tags": ["muralha", "prop", "hero", "bastion_warden"],
        "seed": L.SEED_BASE + 7707,
        "build": bastion_warden,
    },
]

L.run_group("props", SPECS, "props de cenario, natureza e guardiao esculpidos (art/scripts/make_props.py)", hero_pbr=False)
