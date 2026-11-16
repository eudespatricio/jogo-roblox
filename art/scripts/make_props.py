"""Gera 7 props de cenario e heroi low-poly AA esculpidos para o Bastiao (PROP_).

Props (Z-up, frente=-Y, base Z=0, centrados em XY):
  - prop.tree_pine.01      -> PROP_tree_pine      (tree_pine.glb,      2400..3400 tris, Tier-A)
  - prop.tree_oak.01       -> PROP_tree_oak       (tree_oak.glb,       2400..3400 tris, Tier-A)
  - prop.rock_cluster.01   -> PROP_rock_cluster   (rock_cluster.glb,   2400..3400 tris, Tier-A)
  - prop.siege_supply.01   -> PROP_siege_supply   (siege_supply.glb,   2400..3400 tris, Tier-A)
  - prop.iron_brazier.01   -> PROP_iron_brazier   (iron_brazier.glb,   2400..3400 tris, Tier-A)
  - prop.rift_obelisk.01   -> PROP_rift_obelisk   (rift_obelisk.glb,   2400..3400 tris, Tier-A)
  - prop.bastion_warden.01 -> PROP_bastion_warden (bastion_warden.glb, 8000..10500 tris, Hero PBR)

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
    """Barril curvo em segmentos de aduelas arqueadas + aros torus de ferro."""
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
    # Aros de ferro em torus
    for dz, rad in (
        (h * 0.16, r_end + (r_mid - r_end) * 0.52),
        (h * 0.50, r_mid),
        (h * 0.84, r_end + (r_mid - r_end) * 0.52),
    ):
        parts.append(
            L.torus(
                rad + 0.015,
                0.044,
                (cx, cy, z0 + dz),
                "ironDark",
                major_seg=verts,
                minor_seg=4,
                squash=(1.0, 1.0, 1.22),
            )
        )
    parts.append(L.cyl(r_end * 0.84, 0.08, (cx, cy, z0 + h - 0.04), "woodLight", verts=verts))
    parts.append(L.cyl(0.07, 0.09, (cx + r_end * 0.35, cy - r_end * 0.35, z0 + h - 0.02), "woodDark", verts=10))
    return parts


def tree_pine():
    """Pinheiro alpino AA (2400..3400 tris): raizes, almofadas de musgo, tronco esculpido,
    galhos estruturais, 5 camadas conicas com pontas e tufos ico subdiv=2 + pinhas."""
    p = []

    # 1. Raizes abertas + almofadas de musgo e tronco curvo organico em capsule_seg
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.2
        p0 = (0.18 * math.cos(a), 0.18 * math.sin(a), 0.58)
        p1 = (1.02 * math.cos(a), 1.02 * math.sin(a), 0.04)
        p.append(L.capsule_seg(p0, p1, 0.28, 0.10, "barkDark", verts=12))
    for k in range(3):
        ma = 0.45 + k * 2 * math.pi / 3
        p.append(
            _rot(
                L.ico(0.32, (0.72 * math.cos(ma), 0.72 * math.sin(ma), 0.18), "moss", squash=(1.22, 1.04, 0.52), subdiv=2),
                0.12,
                -0.10,
                ma,
            )
        )

    trunk_nodes = (
        ((0.0, 0.0, 0.0), (0.08, 0.05, 2.15), 0.54, 0.42),
        ((0.08, 0.05, 2.05), (0.02, -0.04, 4.20), 0.42, 0.31),
        ((0.02, -0.04, 4.10), (0.09, -0.08, 6.35), 0.31, 0.19),
        ((0.09, -0.08, 6.25), (0.08, -0.08, 8.35), 0.19, 0.06),
    )
    for p0, p1, r0, r1 in trunk_nodes:
        p.append(L.capsule_seg(p0, p1, r0, r1, "barkDark", verts=14))

    # Galhos estruturais internos em capsule_seg
    for idx, (bz, br, ang) in enumerate(
        (
            (2.05, 0.90, -0.9),
            (2.55, 1.35, 0.4),
            (3.40, 1.22, -2.1),
            (3.85, 1.15, 1.9),
            (5.10, 0.92, 3.5),
            (6.30, 0.68, 5.0),
        )
    ):
        p.append(
            L.capsule_seg(
                (0.05, -0.02, bz),
                (br * math.cos(ang), br * math.sin(ang), bz - 0.22),
                max(0.08, 0.15 - idx * 0.015),
                0.05,
                "barkDark",
                verts=10,
            )
        )

    # 2. 5 camadas de saias conicas multi-segmentadas + pontas de folhagem
    tiers = (
        (2.35, 2.28, 2.15, "leafDeep", 5),
        (3.55, 1.96, 1.95, "leafMid", 5),
        (4.75, 1.66, 1.85, "leafDeep", 5),
        (5.95, 1.36, 1.70, "leafMid", 4),
        (7.05, 1.04, 1.55, "leafSun", 4),
    )
    for idx, (zt, rad, ht, col, nb) in enumerate(tiers):
        ox = 0.06 * math.cos(idx * 1.4)
        oy = 0.06 * math.sin(idx * 1.4)
        p.append(L.cyl(rad, ht, (ox, oy, zt), col, verts=16, r2=rad * 0.14, rot_z=idx * 0.45))
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

    # 7 tufos ico subdiv=2 no miolo/copa para volume organico suave + pinhas + topo em agulha
    for cx, cy, cz, cr, ccol in (
        (-0.55, -0.45, 3.10, 0.76, "moss"),
        (0.58, 0.40, 4.30, 0.72, "leafSun"),
        (-0.40, 0.48, 5.50, 0.62, "leafMid"),
        (0.32, -0.35, 6.70, 0.52, "leafSun"),
        (0.45, -0.52, 3.65, 0.58, "leafMid"),
        (-0.48, 0.36, 4.85, 0.54, "moss"),
        (-0.32, -0.36, 6.05, 0.50, "leafDeep"),
    ):
        p.append(_rot(L.ico(cr, (cx, cy, cz), ccol, squash=(1.14, 1.06, 0.78), subdiv=2), 0.18, -0.15, cz))

    # Pinhas pendentes sob a saia inferior
    for k in range(5):
        ang = 0.4 + k * 2 * math.pi / 5
        p.append(L.ball(0.16, (1.18 * math.cos(ang), 1.18 * math.sin(ang), 2.28), "woodDark", seg=8, rings=5, squash=(0.85, 0.85, 1.35)))
    p.append(L.cyl(0.68, 1.65, (0.08, -0.08, 8.25), "leafSun", verts=16, r2=0.0))

    return p


def tree_oak():
    """Carvalho antigo retorcido AA (2400..3400 tris): raizes densas, musgo, tronco com ocos e
    fungos, galhos bifurcados e copa volumosa com domos subdiv=2/3."""
    p = []

    # 1. Raizes primarias, almofadas de musgo na base e tronco retorcido
    for k in range(6):
        a = 2 * math.pi * k / 6 + 0.35
        p.append(
            L.capsule_seg(
                (0.24 * math.cos(a), 0.24 * math.sin(a), 0.64),
                (1.20 * math.cos(a), 1.20 * math.sin(a), 0.04),
                0.34,
                0.12,
                "barkDark",
                verts=14,
            )
        )
        if k < 3:
            p.append(
                _rot(
                    L.ico(
                        0.36,
                        (0.78 * math.cos(a + 0.3), 0.78 * math.sin(a + 0.3), 0.22),
                        "moss",
                        squash=(1.22, 1.02, 0.55),
                        subdiv=2,
                    ),
                    0.1,
                    0.1,
                    a,
                )
            )

    trunk_segs = (
        ((0.0, 0.0, 0.0), (-0.08, 0.10, 1.80), 0.68, 0.54),
        ((-0.08, 0.10, 1.68), (0.06, 0.0, 3.35), 0.54, 0.42),
        ((0.06, 0.0, 3.22), (0.02, -0.04, 4.55), 0.42, 0.28),
    )
    for p0, p1, r0, r1 in trunk_segs:
        p.append(L.capsule_seg(p0, p1, r0, r1, "barkDark", verts=16))

    # Nos de casca esculpidos e cogumelos orelha-de-pau no tronco
    p.append(L.torus(0.19, 0.065, (0.04, -0.45, 2.35), "woodDark", major_seg=12, minor_seg=4, rot=(math.pi / 2 - 0.12, 0.0, 0.0)))
    for fx, fy, fz, fr in ((0.44, -0.22, 1.35, 0.20), (-0.42, -0.28, 2.05, 0.18)):
        p.append(L.ball(fr, (fx, fy, fz), "amber", seg=8, rings=5, squash=(1.2, 0.9, 0.32)))

    # 2. Galhos bifurcados principais e secundarios
    limbs = (
        ((-0.04, 0.02, 3.65), (-1.28, -0.92, 5.05), 0.28, 0.13),
        ((0.06, 0.02, 3.80), (1.35, -0.68, 5.20), 0.26, 0.12),
        ((-0.02, 0.08, 3.95), (-0.88, 1.18, 5.18), 0.25, 0.12),
        ((0.08, 0.06, 4.05), (1.12, 1.05, 5.10), 0.24, 0.11),
        ((-0.95, -0.68, 4.68), (-1.75, 0.18, 4.78), 0.15, 0.07),
        ((1.02, -0.48, 4.82), (1.72, 0.30, 4.92), 0.14, 0.07),
        ((-0.65, 0.88, 4.85), (-1.38, 1.48, 5.12), 0.14, 0.06),
        ((0.82, 0.78, 4.80), (1.48, 1.36, 5.08), 0.14, 0.06),
    )
    for p0, p1, r0, r1 in limbs:
        p.append(L.capsule_seg(p0, p1, r0, r1, "barkDark", verts=12))

    # 3. Copa assimetrica com domo central subdiv=3 + 5 domos subdiv=2 + 9 tufos subdiv=2
    main_domes = (
        (0.05, -0.10, 5.85, 1.50, (1.18, 1.12, 0.84), "leafMid", 3),
        (-1.42, -1.02, 5.12, 1.26, (1.12, 1.06, 0.80), "leafDeep", 2),
        (1.52, -0.74, 5.36, 1.22, (1.12, 1.02, 0.82), "leafSun", 2),
        (-0.94, 1.32, 5.30, 1.28, (1.08, 1.16, 0.78), "oliveLeaf", 2),
        (1.24, 1.14, 5.16, 1.18, (1.15, 1.05, 0.82), "leafDeep", 2),
        (0.10, 0.18, 7.05, 1.08, (1.14, 1.10, 0.80), "leafSun", 2),
    )
    for idx, (cx, cy, cz, rad, sq, col, sdiv) in enumerate(main_domes):
        p.append(_rot(L.ico(rad, (cx, cy, cz), col, squash=sq, subdiv=sdiv), 0.14 * math.sin(idx), 0.18 * math.cos(idx), idx * 0.5))

    accent_tufts = (
        (-1.92, 0.25, 4.68, 1.02, (1.06, 1.10, 0.80), "oliveLeaf", 2),
        (1.88, 0.35, 4.86, 1.00, (1.05, 1.02, 0.78), "leafMid", 2),
        (0.0, -1.52, 4.98, 1.08, (1.15, 0.96, 0.82), "leafSun", 2),
        (0.15, 1.58, 4.82, 1.04, (1.10, 1.00, 0.78), "leafDeep", 2),
        (-0.78, -0.48, 6.52, 1.06, (1.06, 1.04, 0.82), "leafSun", 2),
        (0.84, 0.34, 6.62, 1.04, (1.08, 1.02, 0.80), "oliveLeaf", 2),
        (-0.62, -1.28, 5.75, 0.86, (1.08, 1.02, 0.78), "moss", 2),
        (0.72, -1.16, 5.82, 0.84, (1.06, 1.04, 0.78), "leafSun", 2),
        (-1.35, 0.65, 5.95, 0.88, (1.10, 1.02, 0.76), "leafMid", 2),
    )
    for idx, (cx, cy, cz, rad, sq, col, sdiv) in enumerate(accent_tufts):
        p.append(_rot(L.ico(rad, (cx, cy, cz), col, squash=sq, subdiv=sdiv), 0.16 * math.cos(idx), 0.15 * math.sin(idx), idx * 0.7))

    return p


def rock_cluster():
    """Afloramento de rochas estratificadas AA (2400..3400 tris): matacoes subdiv=3, lajes de xisto,
    almofadas de musgo e rica drusa de quartzo ambar."""
    p = []

    boulders = (
        ((0.0, 0.10, 0.95), 1.46, (1.22, 0.96, 1.05), "stoneDark", (0.22, -0.18, 0.40), 3),
        ((-1.15, -0.55, 0.62), 1.04, (1.15, 0.90, 0.82), "stone", (-0.30, 0.25, 1.15), 3),
        ((1.10, -0.30, 0.58), 0.96, (1.05, 1.18, 0.78), "stoneLight", (0.18, 0.34, 2.10), 3),
        ((-0.45, 0.95, 0.52), 0.90, (1.10, 0.88, 0.75), "stone", (0.40, -0.12, 0.85), 3),
        ((0.65, 0.85, 0.44), 0.78, (1.18, 0.92, 0.68), "stoneDark", (-0.18, 0.32, 1.65), 3),
        ((-0.82, 0.28, 0.72), 0.74, (1.12, 0.94, 0.80), "stoneLight", (0.26, 0.18, -0.65), 2),
        ((0.78, 0.22, 0.68), 0.70, (1.08, 1.04, 0.76), "stone", (-0.22, -0.24, 0.92), 2),
        ((-1.42, 0.18, 0.32), 0.52, (1.20, 0.92, 0.62), "stoneDark", (0.15, -0.28, 1.40), 2),
        ((1.38, 0.34, 0.30), 0.48, (1.15, 0.96, 0.60), "stone", (-0.25, 0.16, 2.30), 2),
    )
    for pos, rad, sq, col, (rx, ry, rz), sdiv in boulders:
        p.append(_rot(L.ico(rad, pos, col, squash=sq, subdiv=sdiv), rx, ry, rz))

    # Lajes de xisto chanfradas nos degraus geologicos
    for sz, pos, col, rot in (
        ((1.55, 1.15, 0.34), (-0.75, -0.82, 0.20), "stoneDark", (0.08, -0.10, 0.28)),
        ((1.35, 1.05, 0.30), (0.88, -0.78, 0.18), "stone", (-0.06, 0.12, -0.35)),
        ((1.18, 0.92, 0.28), (0.15, 1.12, 0.16), "stoneLight", (0.10, 0.05, 0.18)),
        ((1.10, 0.84, 0.26), (-1.05, 0.72, 0.15), "stoneDark", (-0.08, -0.06, 0.52)),
        ((0.96, 0.78, 0.24), (0.98, 0.76, 0.14), "stone", (0.07, 0.09, -0.44)),
    ):
        p.append(L.box(sz, pos, col, bevel=0.05, rot=rot))

    # Almofadas de musgo organicas
    for pos, rad, sq, rot_z in (
        ((-0.25, -0.20, 1.88), 0.64, (1.28, 1.10, 0.45), 0.4),
        ((-1.25, -0.60, 1.15), 0.50, (1.18, 1.05, 0.44), 1.3),
        ((0.95, -0.35, 1.05), 0.46, (1.15, 0.95, 0.42), 2.1),
        ((0.35, 0.78, 0.82), 0.42, (1.12, 0.96, 0.40), 0.9),
        ((-0.55, 0.88, 0.92), 0.40, (1.16, 0.92, 0.42), 1.7),
        ((0.12, 0.28, 1.52), 0.48, (1.20, 1.02, 0.42), 2.6),
    ):
        p.append(_rot(L.ico(rad, pos, "moss", squash=sq, subdiv=2), 0.1, -0.1, rot_z))

    # Drusa rica de quartzo ambar brotando da fenda frontal (-Y) e lateral
    for pos, r, h, col, tilt in (
        ((0.28, -0.78, 0.45), 0.20, 0.96, "amber", (0.48, 0.22)),
        ((0.52, -0.72, 0.38), 0.16, 0.76, "amberBright", (0.58, 0.42)),
        ((0.08, -0.84, 0.36), 0.15, 0.70, "amber", (0.62, -0.18)),
        ((0.38, -0.62, 0.55), 0.14, 0.62, "amberBright", (0.28, 0.32)),
        ((-0.12, -0.76, 0.42), 0.13, 0.56, "neonAmber", (0.52, -0.34)),
        ((0.68, -0.58, 0.44), 0.12, 0.50, "goldBright", (0.44, 0.52)),
        ((-0.28, -0.82, 0.32), 0.11, 0.46, "amber", (0.66, -0.42)),
        ((0.18, -0.94, 0.26), 0.12, 0.52, "neonAmber", (0.72, 0.08)),
        ((0.46, -0.88, 0.28), 0.11, 0.48, "amber", (0.68, 0.30)),
        ((-0.78, -0.95, 0.34), 0.15, 0.64, "amber", (0.54, -0.38)),
        ((-0.96, -0.86, 0.30), 0.12, 0.52, "amberBright", (0.60, -0.52)),
        ((-0.64, -0.88, 0.38), 0.11, 0.46, "neonAmber", (0.46, -0.22)),
    ):
        p.append(L.crystal(r, h, pos, col, tilt=tilt, verts=10))

    return p


def siege_supply():
    """Suprimentos de cerco AA (2400..3400 tris): palete, 2 barris ferrados, caixote com rebites
    e alcas, pergaminho de cerco com lacre e piramide de balas de canhao."""
    p = []

    # 1. Palete de madeira
    for sy in (-1.35, 0.0, 1.35):
        p.append(L.box((4.10, 0.28, 0.20), (0.0, sy, 0.10), "woodDark"))
    for k in range(5):
        sx = -1.75 + k * 0.875
        p.append(L.box((0.55, 3.20, 0.12), (sx, 0.0, 0.26), "wood"))

    # 2. Dois barris de carvalho com aduelas curvas (18 segs), 3 aros torus e rolo de corda no topo
    p += _barrel((-1.15, -0.65, 0.32), 0.58, 0.73, 1.65, "wood", verts=18)
    p += _barrel((-0.95, 0.82, 0.32), 0.54, 0.69, 1.55, "woodLight", verts=18)
    p.append(L.torus(0.28, 0.065, (-0.95, 0.82, 1.92), "straw", major_seg=12, minor_seg=4))
    p.append(L.torus(0.19, 0.055, (-0.95, 0.82, 1.98), "straw", major_seg=10, minor_seg=4))

    # 3. Caixote de municao chanfrado com travamentos diagonais, cantoneiras, rebites e pergaminho
    cx, cy, cz = 1.05, 0.62, 0.32
    cw, cd, ch = 1.65, 1.45, 1.25
    p.append(L.box((cw, cd, ch), (cx, cy, cz + ch / 2), "woodDark", bevel=0.03))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(L.box((0.18, 0.18, ch + 0.06), (cx + sx * (cw / 2 - 0.05), cy + sy * (cd / 2 - 0.05), cz + ch / 2), "woodLight"))
            p.append(L.box((0.24, 0.24, 0.22), (cx + sx * (cw / 2 - 0.02), cy + sy * (cd / 2 - 0.02), cz + ch - 0.06), "ironDark"))
            p.append(L.box((0.24, 0.24, 0.20), (cx + sx * (cw / 2 - 0.02), cy + sy * (cd / 2 - 0.02), cz + 0.12), "ironDark"))
            p.append(L.ball(0.055, (cx + sx * (cw / 2 + 0.08), cy + sy * (cd / 2 + 0.08), cz + ch - 0.04), "steel", seg=6, rings=4))
    for sy in (-1, 1):
        p.append(L.box((cw + 0.06, 0.14, 0.16), (cx, cy + sy * (cd / 2 - 0.02), cz + ch - 0.04), "wood"))
        p.append(L.box((cw * 0.95, 0.12, 0.14), (cx, cy + sy * (cd / 2 + 0.02), cz + ch / 2), "woodLight", rot=(0, 0.58 * sy, 0)))
    for sx in (-1, 1):
        p.append(L.box((0.14, cd + 0.06, 0.16), (cx + sx * (cw / 2 - 0.02), cy, cz + ch - 0.04), "wood"))
        p.append(L.box((0.14, cd + 0.08, 0.14), (cx + sx * (cw / 2 - 0.02), cy, cz + 0.25), "ironDark"))
    # Pergaminho de cerco enrolado com lacre carmesim sobre o caixote
    p.append(L.cyl_axis(0.11, 0.78, (cx - 0.12, cy - 0.15, cz + ch + 0.10), "parchment", axis="x", verts=12))
    p.append(L.torus(0.12, 0.028, (cx - 0.12, cy - 0.15, cz + ch + 0.10), "gold", major_seg=10, minor_seg=4, rot=(0.0, math.pi / 2, 0.0)))
    p.append(L.ball(0.065, (cx - 0.12, cy - 0.26, cz + ch + 0.08), "crimsonBright", seg=8, rings=4))

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
    """Braseiro de ferro forjado AA (2400..3400 tris): pedestal canelado com aneis de bronze,
    pernas com volutas duplas, bojo rebitado e chamas vivas."""
    p = []

    # 1. Pedestal escalonado 16-seg em stoneDark / stone com aneis de bronze
    p.append(L.cyl(1.46, 0.34, (0, 0, 0.0), "stoneDark", verts=16, r2=1.38))
    p.append(L.cyl(1.20, 0.30, (0, 0, 0.34), "stone", verts=16, r2=1.12))
    p.append(L.cyl(0.96, 0.24, (0, 0, 0.64), "stoneDark", verts=16, r2=0.88))
    p.append(L.torus(1.16, 0.042, (0, 0, 0.35), "bronze", major_seg=16, minor_seg=4))
    p.append(L.torus(0.90, 0.048, (0, 0, 0.88), "bronze", major_seg=16, minor_seg=4))

    # 2. 3 pernas curvas de ferro forjado a 120 graus + volutas duplas + anel torus estrutural
    p.append(L.torus(0.94, 0.075, (0, 0, 1.52), "ironDark", major_seg=22, minor_seg=5))
    for k in range(3):
        a = 2 * math.pi * k / 3 - math.pi / 2
        ca, sa = math.cos(a), math.sin(a)
        p.append(L.capsule_seg((0.76 * ca, 0.76 * sa, 0.88), (1.02 * ca, 1.02 * sa, 0.96), 0.16, 0.11, "ironDark", verts=9))
        p.append(L.capsule_seg((0.88 * ca, 0.88 * sa, 0.96), (1.04 * ca, 1.04 * sa, 1.68), 0.14, 0.12, "iron", verts=9))
        p.append(L.capsule_seg((1.04 * ca, 1.04 * sa, 1.64), (1.18 * ca, 1.18 * sa, 2.42), 0.13, 0.15, "ironDark", verts=9))
        p.append(L.torus(0.18, 0.045, (1.24 * ca, 1.24 * sa, 2.34), "bronze", major_seg=10, minor_seg=4, rot=(math.pi / 2, 0.0, a)))
        p.append(L.torus(0.15, 0.040, (1.08 * ca, 1.08 * sa, 1.06), "bronze", major_seg=10, minor_seg=4, rot=(math.pi / 2, 0.0, a)))

    # 3. Bojo afunilado de 22 segmentos + borda torus com 10 rebites e 5 pontas de bronze
    p.append(L.cyl(0.56, 0.36, (0, 0, 1.84), "ironDark", verts=22, r2=0.94))
    p.append(L.cyl(0.94, 0.56, (0, 0, 2.20), "iron", verts=22, r2=1.30))
    p.append(L.cyl(1.32, 0.22, (0, 0, 2.72), "ironDark", verts=22, r2=1.36))
    p.append(L.torus(1.34, 0.085, (0, 0, 2.82), "iron", major_seg=22, minor_seg=5))
    for k in range(10):
        a = 2 * math.pi * k / 10
        p.append(L.ball(0.082, (1.36 * math.cos(a), 1.36 * math.sin(a), 2.84), "steel", seg=6, rings=4))
        if k % 2 == 0:
            p.append(L.crystal(0.09, 0.28, (1.35 * math.cos(a), 1.35 * math.sin(a), 2.90), "bronze", tilt=(-0.18 * math.sin(a), 0.18 * math.cos(a)), verts=6))

    # 4. Leito de brasas subdiv=2, carvoes incandescentes subdiv=2/1 e chama multi-lingua esculpida
    p.append(_rot(L.ico(0.90, (0, 0, 2.86), "danger", squash=(1.06, 1.06, 0.50), subdiv=2), 0.1, 0.2, 0.5))
    for k in range(5):
        ang_c = k * 2 * math.pi / 5 + 0.35
        ca, sa = math.cos(ang_c), math.sin(ang_c)
        p.append(_rot(L.ico(0.22, (0.58 * ca, 0.58 * sa, 2.98), "ember", squash=(1.12, 0.92, 0.65), subdiv=2 if k < 3 else 1), 0.15, -0.12, ang_c))
    p.append(L.capsule_seg((0.0, 0.0, 2.88), (0.06, -0.05, 3.45), 0.34, 0.20, "emberDeep", verts=9))
    p.append(L.capsule_seg((0.06, -0.05, 3.40), (-0.04, 0.04, 3.85), 0.20, 0.09, "amberBright", verts=9))
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
        p.append(L.capsule_seg((bx, by, 2.92), (mx, my, 2.92 + h * 0.55), rad, rad * 0.52, col1, verts=9))
        p.append(L.crystal(rad * 0.54, h * 0.58, (mx, my, 2.90 + h * 0.52), col2, tilt=tilt, verts=6))

    return p


def rift_obelisk():
    """Obelisco da fenda AA (2400..3400 tris): base de obsidiana com garras e aneis de contencao,
    fuste torcido runico, giroscopio quadruplo com nos arcanos e drusa de cristais."""
    p = []

    # 1. Base escalonada de obsidiana (18 segs) + 8 garras laterais + runas no degrau
    p.append(L.cyl(1.76, 0.42, (0, 0, 0.0), "ironDark", verts=18, r2=1.56))
    p.append(L.cyl(1.44, 0.36, (0, 0, 0.42), "obsidian", verts=18, r2=1.24))
    p.append(L.cyl(1.14, 0.32, (0, 0, 0.78), "ink", verts=18, r2=0.96))
    p.append(L.torus(1.48, 0.055, (0, 0, 0.42), "steel", major_seg=20, minor_seg=5))
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        p.append(
            L.crystal(
                0.34,
                1.28,
                (1.18 * math.cos(a), 1.18 * math.sin(a), 0.24),
                "ironDark",
                tilt=(0.35 * math.sin(a), -0.35 * math.cos(a)),
                verts=8,
            )
        )
        ra = k * math.pi / 2
        p.append(
            L.crystal(
                0.24,
                0.92,
                (1.32 * math.cos(ra), 1.32 * math.sin(ra), 0.18),
                "obsidianLight",
                tilt=(0.42 * math.sin(ra), -0.42 * math.cos(ra)),
                verts=6,
            )
        )
        p.append(L.box((0.46, 0.16, 0.14), (1.36 * math.cos(ra), 1.36 * math.sin(ra), 0.60), "arcaneCyan", rot=(0, 0, ra + math.pi / 2)))

    # 2. Obelisco facetado torcido em 5 segmentos (verts=10) + entalhes runicos luminosos + ponta piramidal
    segs = (
        (1.08, 0.84, 0.74, 1.02, 0.0, "ink"),
        (2.04, 0.76, 0.67, 1.02, 0.18, "obsidian"),
        (3.00, 0.69, 0.60, 1.02, 0.36, "ink"),
        (3.96, 0.62, 0.53, 1.02, 0.54, "obsidian"),
        (4.92, 0.55, 0.45, 0.96, 0.72, "obsidianLight"),
    )
    for z0, r1, r2, h, rz, col in segs:
        p.append(L.cyl(r1, h, (0, 0, z0), col, verts=10, r2=r2, rot_z=math.pi / 10 + rz))
    for k in range(4):
        a = k * math.pi / 2
        p.append(L.box((0.14, 0.12, 0.76), (0.68 * math.cos(a + 0.11), 0.68 * math.sin(a + 0.11), 2.18), "tealSwarm", rot=(0, 0, a + 0.11)))
        p.append(L.box((0.13, 0.11, 0.70), (0.58 * math.cos(a + 0.33), 0.58 * math.sin(a + 0.33), 3.62), "arcaneCyan", rot=(0, 0, a + 0.33)))
        p.append(L.box((0.12, 0.10, 0.66), (0.50 * math.cos(a + 0.55), 0.50 * math.sin(a + 0.55), 4.82), "eyeNeon", rot=(0, 0, a + 0.55)))
    p.append(L.cyl(0.47, 1.18, (0, 0, 5.82), "ink", verts=10, r2=0.0, rot_z=math.pi / 10 + 0.90))

    # 3. Colar de contencao com aneis torus de ferro e giroscopio quadruplo arcano
    p.append(L.cyl(0.84, 0.44, (0, 0, 3.15), "iron", verts=18, r2=0.80))
    p.append(L.torus(0.88, 0.095, (0, 0, 3.37), "steel", major_seg=22, minor_seg=6))
    p.append(L.torus(0.98, 0.075, (0, 0, 1.12), "ironDark", major_seg=22, minor_seg=5))
    p.append(L.torus(1.12, 0.058, (0, 0, 3.37), "teal", major_seg=22, minor_seg=6, rot=(0.32, -0.24, 0.0)))
    p.append(L.torus(1.06, 0.052, (0, 0, 3.37), "arcaneCyan", major_seg=22, minor_seg=5, rot=(-0.30, 0.28, 0.8)))
    p.append(L.torus(0.88, 0.050, (0, 0, 4.92), "arcaneCyan", major_seg=20, minor_seg=5, rot=(-0.28, 0.30, 0.4)))
    p.append(L.torus(0.62, 0.042, (0, 0, 6.22), "tealSwarm", major_seg=18, minor_seg=5, rot=(0.34, 0.22, -0.3)))
    for k in range(4):
        a = k * math.pi / 2 + 0.33
        p.append(L.box((0.26, 0.32, 0.52), (0.82 * math.cos(a), 0.82 * math.sin(a), 3.37), "steel", rot=(0, 0, a)))
        p.append(L.ball(0.11, (0.96 * math.cos(a), 0.96 * math.sin(a), 3.37), "eyeNeon", seg=8, rings=5))

    # 4. Cristais da fenda brotando da base, colar e topo + nucleo subdiv=3
    shards = (
        ((-0.78, -0.62, 0.75), 0.22, 1.25, "teal", (0.38, 0.28)),
        ((0.82, -0.45, 0.72), 0.20, 1.15, "tealSwarm", (0.32, -0.38)),
        ((-0.45, 0.85, 0.70), 0.18, 1.05, "eyeNeon", (-0.42, 0.22)),
        ((0.68, 0.72, 0.74), 0.20, 1.20, "teal", (-0.36, -0.34)),
        ((0.0, -0.92, 0.68), 0.18, 1.02, "arcaneCyan", (0.48, 0.05)),
        ((-0.94, 0.12, 0.68), 0.17, 0.96, "tealSwarm", (0.08, 0.46)),
        ((0.94, 0.14, 0.68), 0.17, 0.96, "teal", (-0.08, -0.46)),
        ((0.0, -0.64, 3.35), 0.17, 1.05, "eyeNeon", (0.72, 0.0)),
        ((-0.58, 0.25, 3.45), 0.16, 0.95, "tealSwarm", (-0.28, 0.65)),
        ((0.55, 0.28, 3.40), 0.16, 0.92, "teal", (-0.25, -0.68)),
        ((0.0, 0.62, 3.38), 0.16, 0.94, "arcaneCyan", (-0.68, 0.0)),
        ((0.18, -0.45, 4.95), 0.15, 0.88, "eyeNeon", (0.55, -0.25)),
        ((-0.24, 0.42, 5.02), 0.14, 0.82, "arcaneCyan", (-0.52, 0.28)),
        ((-0.38, -0.28, 4.98), 0.14, 0.80, "tealSwarm", (0.38, 0.42)),
        ((0.36, 0.30, 5.00), 0.14, 0.80, "teal", (-0.38, -0.42)),
    )
    for pos, r, h, col, tilt in shards:
        p.append(L.crystal(r, h, pos, col, tilt=tilt, verts=8))
    p.append(_rot(L.ico(0.30, (0.0, 0.0, 7.22), "eyeNeon", squash=(0.76, 0.76, 1.44), subdiv=3), 0.1, 0.15, 0.4))

    return p


def bastion_warden():
    """Hero PBR AA (8000..10500 tris): Paladino Guardiao do Bastiao (~6.2 studs, frente -Y):
    armadura completa em placas caneladas (sabatons articulados, grevas nervuradas, poleyns alados,
    coxotes e escarcelas em camadas, peitoral canelado com brasao solar radiante e gorget triplo),
    ombreiras em 3 camadas com cristas aladas, manto pregueado com broches e corrente dourada,
    greathelm coroado emplumado com visor T luminoso, escudo-torre heraldico (-X) e alabarda-martelo
    runico de guerra (+X)."""
    p = []

    # 1. Sabatons articulados, grevas caneladas, joelheiras aladas (poleyns), coxotes e escarcelas (z = 0.0 .. 2.32)
    for sx in (-1, 1):
        lx = sx * 0.46
        # Sola blindada + biqueira em 2 lames sobrepostos + espora traseira
        p.append(L.cyl(0.28, 0.20, (lx, -0.06, 0.0), "ironDark", verts=10, r2=0.26))
        p.append(L.ball(0.26, (lx, -0.25, 0.16), "steel", seg=10, rings=5, squash=(0.94, 1.38, 0.66)))
        p.append(L.ball(0.23, (lx, -0.34, 0.14), "royal", seg=8, rings=4, squash=(0.88, 1.15, 0.58)))
        p.append(L.torus(0.23, 0.042, (lx, -0.18, 0.20), "gold", major_seg=10, minor_seg=4, squash=(0.95, 1.25, 0.85)))
        p.append(L.torus(0.23, 0.045, (lx, -0.08, 0.28), "gold", major_seg=10, minor_seg=4))
        p.append(L.crystal(0.055, 0.22, (lx, 0.22, 0.16), "gold", tilt=(1.35, 0.0), verts=5))

        # Grevas anatomicas com 3 nervuras caneladas e aros dourados
        p.append(L.capsule_seg((lx, -0.04, 0.26), (lx, -0.06, 1.18), 0.24, 0.27, "royal", verts=10))
        p.append(L.capsule_seg((lx, -0.12, 0.34), (lx, -0.14, 1.12), 0.19, 0.21, "steel", verts=8))
        for k_flute in (-1, 0, 1):
            fa = k_flute * 0.48
            fx = lx + 0.22 * math.sin(fa)
            fy = -0.08 - 0.22 * math.cos(fa)
            p.append(L.capsule_seg((fx, fy, 0.36), (fx, fy - 0.02, 1.10), 0.036, 0.040, "gold" if k_flute == 0 else "steel", verts=6))
        p.append(L.torus(0.26, 0.042, (lx, -0.06, 0.68), "gold", major_seg=10, minor_seg=4))
        p.append(L.torus(0.28, 0.045, (lx, -0.06, 1.12), "gold", major_seg=10, minor_seg=4))

        # Joelheira (poleyn) com aba lateral alada e rebite solar
        p.append(L.ball(0.27, (lx, -0.15, 1.24), "gold", seg=10, rings=5, squash=(0.95, 1.08, 0.92)))
        p.append(L.torus(0.24, 0.042, (lx, -0.18, 1.24), "goldBright", major_seg=10, minor_seg=4, rot=(math.pi / 2, 0.0, 0.0)))
        p.append(L.ball(0.08, (lx, -0.40, 1.24), "amberBright", seg=6, rings=4))
        p.append(
            _rot(
                L.ball(0.18, (lx + sx * 0.24, -0.10, 1.26), "royal", seg=8, rings=4, squash=(0.35, 0.95, 1.15)),
                0.0,
                sx * 0.28,
                0.0,
            )
        )
        p.append(L.crystal(0.07, 0.26, (lx + sx * 0.26, -0.08, 1.30), "gold", tilt=(-0.15, sx * 0.45), verts=5))

        # Coxotes (cuisses) segmentados + escarcelas (tassets) em 3 placas sobrepostas
        p.append(L.capsule_seg((lx, -0.04, 1.28), (lx, 0.0, 2.22), 0.28, 0.33, "steel", verts=10))
        for kz in (1.58, 1.92):
            p.append(L.torus(0.30, 0.038, (lx, -0.02, kz), "gold", major_seg=10, minor_seg=4))
        for t_idx, (tz, tr, tcol) in enumerate(((2.14, 0.35, "royal"), (1.92, 0.34, "steel"), (1.70, 0.32, "gold"))):
            p.append(
                _rot(
                    L.ball(tr, (sx * (0.66 + t_idx * 0.02), -0.06, tz), tcol, seg=8, rings=4, squash=(0.36, 0.95, 0.62)),
                    0.0,
                    sx * 0.24,
                    0.0,
                )
            )
            p.append(
                L.torus(
                    tr * 0.88,
                    0.032,
                    (sx * (0.68 + t_idx * 0.02), -0.06, tz),
                    "goldBright",
                    major_seg=8,
                    minor_seg=3,
                    rot=(0.0, math.pi / 2 - sx * 0.24, 0.0),
                    squash=(0.65, 0.95, 1.0),
                )
            )

    # 2. Cinturao real em torus duplo, fivela solar e tabardo pregueado em crimsonCloth
    p.append(L.cyl(0.62, 0.44, (0, 0.0, 2.04), "ironDark", verts=12, r2=0.66))
    p.append(L.torus(0.65, 0.055, (0, -0.01, 2.20), "steel", major_seg=12, minor_seg=4, squash=(1.08, 0.88, 1.0)))
    p.append(L.torus(0.67, 0.090, (0, -0.02, 2.38), "gold", major_seg=14, minor_seg=4, squash=(1.08, 0.88, 1.0)))
    p.append(L.cyl_axis(0.24, 0.16, (0, -0.62, 2.38), "gold", axis="y", verts=10))
    p.append(L.torus(0.22, 0.042, (0, -0.68, 2.38), "goldBright", major_seg=10, minor_seg=4, rot=(math.pi / 2, 0.0, 0.0)))
    p.append(L.ball(0.12, (0, -0.71, 2.38), "amberBright", seg=8, rings=4))
    for k_stud in (-2, -1, 1, 2):
        sa = k_stud * 0.42
        p.append(L.ball(0.065, (0.70 * math.sin(sa), -0.60 * math.cos(sa), 2.38), "goldBright", seg=6, rings=3))

    # Tabardo frontal com 3 pregas verticais e borda dourada
    for tx_off, tr0, tr1, tcol in (
        (0.0, 0.22, 0.15, "crimsonCloth"),
        (-0.16, 0.15, 0.11, "crimsonBright"),
        (0.16, 0.15, 0.11, "crimsonBright"),
    ):
        p.append(L.capsule_seg((tx_off, -0.50, 2.28), (tx_off * 1.15, -0.56, 0.86), tr0, tr1, tcol, verts=8))
    p.append(L.capsule_seg((-0.24, -0.55, 0.90), (0.0, -0.58, 0.68), 0.08, 0.07, "gold", verts=6))
    p.append(L.capsule_seg((0.24, -0.55, 0.90), (0.0, -0.58, 0.68), 0.08, 0.07, "gold", verts=6))
    p.append(L.ball(0.09, (0.0, -0.59, 0.68), "amberBright", seg=6, rings=4))

    # 3. Peitoral blindado canelado (royal/steel) + gorget triplo + brasao solar radiante (-Y)
    p.append(L.cyl(0.68, 1.65, (0, 0.0, 2.42), "royal", verts=14, r2=0.84))
    p.append(L.ball(0.76, (0, -0.10, 3.42), "steel", seg=12, rings=6, squash=(1.08, 0.82, 1.05)))
    p.append(L.ball(0.72, (0, -0.16, 3.46), "royal", seg=12, rings=6, squash=(0.96, 0.78, 0.94)))
    p.append(L.torus(0.74, 0.055, (0, -0.06, 2.95), "gold", major_seg=12, minor_seg=4, squash=(1.06, 0.86, 1.0)))
    # Gorget triplo escalonado
    p.append(L.cyl(0.66, 0.26, (0, -0.04, 4.02), "steel", verts=12, r2=0.58))
    p.append(L.torus(0.64, 0.065, (0, -0.04, 4.06), "gold", major_seg=12, minor_seg=4, squash=(1.12, 0.92, 1.0)))
    p.append(L.torus(0.58, 0.075, (0, -0.04, 4.20), "goldBright", major_seg=12, minor_seg=4, squash=(1.10, 0.90, 1.0)))

    # Brasao solar em alto-relevo e nervuras caneladas do peito (-Y)
    p.append(L.cyl_axis(0.30, 0.14, (0, -0.72, 3.48), "gold", axis="y", verts=12))
    p.append(L.torus(0.28, 0.045, (0, -0.76, 3.48), "goldBright", major_seg=12, minor_seg=4, rot=(math.pi / 2, 0.0, 0.0)))
    p.append(L.ball(0.17, (0, -0.79, 3.48), "amberBright", seg=8, rings=5, squash=(1.0, 0.55, 1.25)))
    for k_ray in range(8):
        ra = 2 * math.pi * k_ray / 8
        rx0, rz0 = 0.22 * math.cos(ra), 3.48 + 0.22 * math.sin(ra)
        rx1, rz1 = 0.44 * math.cos(ra), 3.48 + 0.40 * math.sin(ra)
        p.append(L.capsule_seg((rx0, -0.74, rz0), (rx1, -0.68, rz1), 0.055, 0.025, "goldBright", verts=6))
    for sx in (-1, 1):
        for r_idx, (z0, z1) in enumerate(((3.18, 3.00), (3.36, 3.16), (3.58, 3.82))):
            p.append(
                L.capsule_seg(
                    (sx * (0.18 + r_idx * 0.04), -0.70, z0),
                    (sx * (0.52 + r_idx * 0.04), -0.56, z1),
                    0.06,
                    0.035,
                    "gold" if r_idx % 2 == 0 else "steel",
                    verts=6,
                )
            )

    # 4. Ombreiras curvas em 3 camadas com aros torus dourados, medalhao lateral e crista alada tripla
    for sx in (-1, 1):
        px = sx * 1.08
        for l_idx, (pr, pz, pcol, psq) in enumerate(
            (
                (0.58, 3.88, "steel", (1.14, 0.98, 0.78)),
                (0.54, 4.06, "royal", (1.10, 0.94, 0.76)),
                (0.46, 4.24, "steel", (1.02, 0.88, 0.70)),
            )
        ):
            p.append(_rot(L.ball(pr, (px * (1.0 + l_idx * 0.02), -0.02, pz), pcol, seg=10, rings=5, squash=psq), 0.0, sx * (0.34 - l_idx * 0.04), 0.0))
            p.append(
                L.torus(
                    pr * 0.94,
                    0.058,
                    (px * (1.0 + l_idx * 0.02), -0.02, pz - 0.06),
                    "gold",
                    major_seg=12,
                    minor_seg=4,
                    rot=(0.0, sx * (0.40 - l_idx * 0.04), 0.0),
                    squash=(1.05, 0.92, 1.0),
                )
            )
        # Guarda-pescoco vertical (haute-piece) + crista alada em 3 penas douradas
        p.append(L.torus(0.34, 0.052, (sx * 0.82, -0.02, 4.32), "goldBright", major_seg=10, minor_seg=4, rot=(0.0, math.pi / 2 - sx * 0.25, 0.0)))
        for w_idx, (wy, wz, wh, wtilt) in enumerate(((-0.08, 4.36, 0.72, -0.12), (0.06, 4.38, 0.64, -0.26), (0.20, 4.32, 0.52, -0.40))):
            p.append(
                L.crystal(
                    0.14 - w_idx * 0.02,
                    wh,
                    (px * 1.05, wy, wz),
                    "goldBright" if w_idx == 0 else "gold",
                    tilt=(wtilt, sx * 0.42),
                    verts=5,
                )
            )
        p.append(L.ball(0.12, (sx * 1.48, -0.14, 4.02), "amberBright", seg=8, rings=4))

    # 5. Manto esvoacante esculpido (crimsonCloth/crimsonBright) nas costas (+Y) com broches e corrente dourada
    for sx in (-1, 1):
        p.append(L.cyl_axis(0.20, 0.14, (sx * 0.62, -0.42, 4.08), "gold", axis="y", verts=10))
        p.append(L.torus(0.19, 0.042, (sx * 0.62, -0.46, 4.08), "goldBright", major_seg=10, minor_seg=4, rot=(math.pi / 2, 0.0, 0.0)))
        p.append(L.ball(0.10, (sx * 0.62, -0.50, 4.08), "amberBright", seg=6, rings=4))
    for k_link in range(-2, 3):
        lx_c = k_link * 0.22
        lz_c = 3.92 + 0.03 * (k_link * k_link)
        p.append(L.torus(0.085, 0.026, (lx_c, -0.56, lz_c), "goldBright", major_seg=8, minor_seg=3, rot=(0.4, 0.2 * k_link, 0.0)))

    cape_folds = (
        (0.0, 0.50, 4.12, 0.0, 0.76, 2.25, 0.0, 0.98, 0.40, 0.36, 0.44, 0.54, "crimsonCloth"),
        (-0.22, 0.49, 4.10, -0.34, 0.75, 2.26, -0.44, 0.96, 0.41, 0.30, 0.36, 0.44, "crimsonBright"),
        (0.22, 0.49, 4.10, 0.34, 0.75, 2.26, 0.44, 0.96, 0.41, 0.30, 0.36, 0.44, "crimsonBright"),
        (-0.44, 0.47, 4.06, -0.64, 0.72, 2.28, -0.82, 0.92, 0.44, 0.28, 0.34, 0.40, "crimsonCloth"),
        (0.44, 0.47, 4.06, 0.64, 0.72, 2.28, 0.82, 0.92, 0.44, 0.28, 0.34, 0.40, "crimsonCloth"),
        (-0.68, 0.42, 4.00, -0.90, 0.66, 2.32, -1.12, 0.84, 0.50, 0.24, 0.30, 0.34, "crimsonBright"),
        (0.68, 0.42, 4.00, 0.90, 0.66, 2.32, 1.12, 0.84, 0.50, 0.24, 0.30, 0.34, "crimsonBright"),
    )
    for x0, y0, z0, xm, ym, zm, x1, y1, z1, r0, rm, r1, col in cape_folds:
        p.append(L.capsule_seg((x0, y0, z0), (xm, ym, zm), r0, rm, col, verts=8))
        p.append(L.capsule_seg((xm, ym, zm), (x1, y1, z1), rm, r1, col, verts=8))
    p.append(L.capsule_seg((-1.08, 0.86, 0.46), (0.0, 0.98, 0.38), 0.13, 0.14, "gold", verts=8))
    p.append(L.capsule_seg((0.0, 0.98, 0.38), (1.08, 0.86, 0.46), 0.14, 0.13, "gold", verts=8))

    # 6. Greathelm emplumado coroado (royal/steel/gold) + visor T amberBright (~6.2 studs)
    p.append(L.cyl(0.48, 0.88, (0, -0.04, 4.28), "steel", verts=14, r2=0.45))
    p.append(L.ball(0.47, (0, -0.04, 5.14), "royal", seg=12, rings=6, squash=(0.96, 1.04, 0.72)))
    p.append(L.torus(0.49, 0.052, (0, -0.04, 4.38), "gold", major_seg=14, minor_seg=4))
    p.append(L.torus(0.47, 0.065, (0, -0.04, 5.06), "gold", major_seg=14, minor_seg=4))
    for k in range(7):
        ang = -1.14 + k * 0.38
        cx_k = 0.46 * math.sin(ang)
        cy_k = -0.04 - 0.46 * math.cos(ang)
        p.append(L.crystal(0.068, 0.25, (cx_k, cy_k, 5.10), "goldBright", verts=5))
        if k % 2 == 1:
            p.append(L.ball(0.055, (cx_k * 1.04, cy_k * 1.04, 5.06), "amberBright", seg=6, rings=3))

    # Visor em T brilhante (amberBright/neonAmber) e guardas faciais douradas (-Y)
    p.append(L.capsule_seg((-0.30, -0.49, 4.86), (0.30, -0.49, 4.86), 0.075, 0.075, "amberBright", verts=8))
    p.append(L.capsule_seg((0.0, -0.50, 4.88), (0.0, -0.48, 4.42), 0.068, 0.052, "neonAmber", verts=8))
    p.append(L.capsule_seg((-0.32, -0.46, 4.96), (0.32, -0.46, 4.96), 0.055, 0.055, "goldBright", verts=6))
    for sx in (-1, 1):
        p.append(L.capsule_seg((sx * 0.24, -0.44, 4.76), (sx * 0.14, -0.44, 4.34), 0.12, 0.09, "gold", verts=8))
        p.append(L.capsule_seg((sx * 0.36, -0.34, 4.74), (sx * 0.28, -0.36, 4.36), 0.10, 0.08, "steel", verts=6))

    # Crista dourada e pluma heroica multi-camada curvada ate ~6.2 studs
    p.append(L.capsule_seg((0, -0.28, 5.38), (0, 0.34, 5.56), 0.11, 0.13, "gold", verts=8))
    p.append(L.capsule_seg((0, -0.18, 5.52), (0, 0.22, 6.04), 0.18, 0.24, "crimsonBright", verts=8))
    p.append(L.capsule_seg((0, 0.18, 6.02), (0, 0.78, 5.72), 0.24, 0.16, "crimsonCloth", verts=8))
    p.append(L.capsule_seg((0, 0.72, 5.74), (0, 1.15, 5.18), 0.16, 0.07, "crimsonBright", verts=8))
    for sx in (-1, 1):
        p.append(L.capsule_seg((sx * 0.10, -0.10, 5.48), (sx * 0.18, 0.32, 5.92), 0.12, 0.16, "crimsonCloth", verts=8))
        p.append(L.capsule_seg((sx * 0.18, 0.28, 5.90), (sx * 0.22, 0.88, 5.42), 0.15, 0.06, "crimsonBright", verts=8))

    # 7. Braco esquerdo articulado (-X) + Escudo-Torre Heraldico (royal + gold + cruz em relevo + rebites)
    p.append(L.capsule_seg((-1.02, -0.04, 3.82), (-1.18, -0.32, 3.05), 0.22, 0.19, "steel", verts=8))
    p.append(L.ball(0.21, (-1.20, -0.34, 3.02), "gold", seg=8, rings=4))
    p.append(L.torus(0.20, 0.042, (-1.20, -0.34, 3.02), "goldBright", major_seg=8, minor_seg=3, rot=(0.4, 0.8, 0.0)))
    p.append(L.capsule_seg((-1.20, -0.36, 2.98), (-1.12, -0.68, 2.68), 0.20, 0.18, "royal", verts=8))

    sh_x, sh_y, sh_z = -1.24, -0.82, 2.68
    p.append(_rot(L.ball(1.42, (sh_x, sh_y, sh_z), "royal", seg=12, rings=6, squash=(0.68, 0.18, 1.08)), 0.0, 0.0, -0.32))
    p.append(_rot(L.ball(1.26, (sh_x - 0.03, sh_y - 0.05, sh_z), "steel", seg=10, rings=5, squash=(0.62, 0.16, 0.98)), 0.0, 0.0, -0.32))
    p.append(
        L.torus(
            0.92,
            0.088,
            (sh_x - 0.06, sh_y - 0.12, sh_z),
            "gold",
            major_seg=14,
            minor_seg=4,
            rot=(math.pi / 2, 0.0, -0.32),
            squash=(0.86, 1.42, 1.0),
        )
    )
    p.append(
        L.torus(
            0.78,
            0.052,
            (sh_x - 0.08, sh_y - 0.15, sh_z),
            "goldBright",
            major_seg=12,
            minor_seg=4,
            rot=(math.pi / 2, 0.0, -0.32),
            squash=(0.82, 1.36, 1.0),
        )
    )
    # Cruz heraldica em relevo + umbo solar + 8 rebites perimetrais
    p.append(L.capsule_seg((sh_x - 0.10, sh_y - 0.22, sh_z - 1.18), (sh_x - 0.10, sh_y - 0.22, sh_z + 1.18), 0.085, 0.085, "gold", verts=8))
    p.append(L.capsule_seg((sh_x - 0.40, sh_y - 0.08, sh_z), (sh_x + 0.20, sh_y - 0.36, sh_z), 0.085, 0.085, "gold", verts=8))
    p.append(L.torus(0.26, 0.048, (sh_x - 0.11, sh_y - 0.24, sh_z + 0.06), "goldBright", major_seg=10, minor_seg=4, rot=(math.pi / 2, 0.0, -0.32)))
    p.append(L.ball(0.22, (sh_x - 0.12, sh_y - 0.26, sh_z + 0.06), "amberBright", seg=8, rings=5))
    for dz in (-0.85, -0.45, 0.45, 0.85):
        p.append(L.ball(0.075, (sh_x - 0.38, sh_y - 0.08, sh_z + dz), "goldBright", seg=6, rings=3))
        p.append(L.ball(0.075, (sh_x + 0.18, sh_y - 0.34, sh_z + dz), "goldBright", seg=6, rings=3))

    # 8. Braco direito articulado (+X) + Alabarda-Martelo de Guerra do Forjador de Runas
    p.append(L.capsule_seg((1.02, -0.04, 3.82), (1.20, -0.34, 3.08), 0.22, 0.19, "steel", verts=8))
    p.append(L.ball(0.21, (1.22, -0.36, 3.04), "gold", seg=8, rings=4))
    p.append(L.torus(0.20, 0.042, (1.22, -0.36, 3.04), "goldBright", major_seg=8, minor_seg=3, rot=(0.4, -0.8, 0.0)))
    p.append(L.capsule_seg((1.22, -0.38, 3.00), (1.26, -0.78, 2.86), 0.20, 0.19, "royal", verts=8))
    p.append(L.ball(0.22, (1.28, -0.86, 2.84), "gold", seg=8, rings=4))

    h_bot = (1.24, -0.62, 1.38)
    h_top = (1.32, -1.08, 4.52)
    p.append(L.capsule_seg(h_bot, h_top, 0.10, 0.11, "woodDark", verts=10))
    p.append(L.ball(0.17, h_bot, "gold", seg=8, rings=4))
    p.append(L.crystal(0.09, 0.28, (h_bot[0], h_bot[1] + 0.03, h_bot[2] - 0.02), "goldBright", tilt=(2.98, 0.0), verts=5))
    for k_ring in range(4):
        ft = 0.22 + k_ring * 0.20
        rx = h_bot[0] + (h_top[0] - h_bot[0]) * ft
        ry = h_bot[1] + (h_top[1] - h_bot[1]) * ft
        rz = h_bot[2] + (h_top[2] - h_bot[2]) * ft
        p.append(L.torus(0.13, 0.040, (rx, ry, rz), "gold", major_seg=8, minor_seg=3, rot=(0.15, 0.0, 0.0)))

    hm_c = (1.32, -1.06, 4.28)
    p.append(L.cyl_axis(0.36, 1.16, hm_c, "steel", axis="y", verts=12))
    p.append(L.cyl_axis(0.42, 0.28, (hm_c[0], hm_c[1] - 0.48, hm_c[2]), "ironDark", axis="y", verts=12))
    p.append(L.torus(0.39, 0.058, (hm_c[0], hm_c[1] - 0.30, hm_c[2]), "gold", major_seg=12, minor_seg=4, rot=(math.pi / 2, 0, 0)))
    p.append(L.torus(0.39, 0.058, (hm_c[0], hm_c[1] + 0.30, hm_c[2]), "gold", major_seg=12, minor_seg=4, rot=(math.pi / 2, 0, 0)))
    p.append(L.torus(0.34, 0.048, hm_c, "goldBright", major_seg=12, minor_seg=4, rot=(math.pi / 2, 0, 0)))
    p.append(L.crystal(0.24, 0.64, (hm_c[0], hm_c[1] + 0.54, hm_c[2]), "gold", tilt=(-math.pi / 2, 0.0), verts=6))
    p.append(L.crystal(0.18, 0.72, (hm_c[0], hm_c[1] - 0.02, hm_c[2] + 0.32), "steel", tilt=(-0.15, 0.0), verts=6))
    p.append(L.ball(0.20, (hm_c[0], hm_c[1] - 0.60, hm_c[2]), "amberBright", seg=8, rings=4, squash=(0.95, 0.45, 0.95)))
    for sx in (-1, 1):
        p.append(L.ball(0.15, (hm_c[0] + sx * 0.35, hm_c[1], hm_c[2]), "neonAmber", seg=8, rings=4, squash=(0.45, 1.15, 0.95)))
        p.append(L.ball(0.11, (hm_c[0] + sx * 0.32, hm_c[1] - 0.22, hm_c[2]), "amberBright", seg=6, rings=3, squash=(0.45, 0.95, 0.85)))

    return p


SPECS = [
    {
        "id": "prop.tree_pine.01",
        "name": "PROP_tree_pine",
        "glb": "tree_pine.glb",
        "tipo": "prop_estatico",
        "qualidade": "standard",
        "limite": 3600,
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
        "qualidade": "standard",
        "limite": 3600,
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
        "qualidade": "standard",
        "limite": 3600,
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
        "qualidade": "standard",
        "limite": 3600,
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
        "qualidade": "standard",
        "limite": 3600,
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
        "qualidade": "standard",
        "limite": 3600,
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
        "qualidade": "hero",
        "limite": 11000,
        "hero_pbr": True,
        "quantidade_cena": 1,
        "center_xy": True,
        "pivot": "base",
        "suavizacao_normais": NORMALS_PROPS,
        "tags": ["muralha", "prop", "hero", "bastion_warden"],
        "seed": L.SEED_BASE + 7707,
        "build": bastion_warden,
    },
]

L.run_group("props", SPECS, "props de cenario, natureza e guardiao esculpidos (art/scripts/make_props.py)", hero_pbr=False)
