"""Gera 6 props de cenario low-poly esculpidos para o Bastiao (PROP_).

Props (Z-up, frente=-Y, base Z=0, centrados em XY):
  - prop.tree_pine.01    -> PROP_tree_pine    (tree_pine.glb,    <= 1400 tris)
  - prop.tree_oak.01     -> PROP_tree_oak     (tree_oak.glb,     <= 1400 tris)
  - prop.rock_cluster.01 -> PROP_rock_cluster (rock_cluster.glb, <= 900 tris)
  - prop.siege_supply.01 -> PROP_siege_supply (siege_supply.glb, <= 1300 tris)
  - prop.iron_brazier.01 -> PROP_iron_brazier (iron_brazier.glb, <= 1100 tris)
  - prop.rift_obelisk.01 -> PROP_rift_obelisk (rift_obelisk.glb, <= 1200 tris)

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


def _barrel(center, r_end, r_mid, h, color, verts=10):
    """Barril curvo em 3 aneis de aduelas + aros metalicos redondos (zero cubos)."""
    cx, cy, z0 = center
    bm = bmesh.new()
    rings = []
    profile = ((0.0, r_end), (h * 0.28, r_mid * 0.96), (h * 0.50, r_mid), (h * 0.72, r_mid * 0.96), (h, r_end))
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
    # Aros de ferro cilindricos
    for dz, rad in ((h * 0.16, r_end + (r_mid - r_end) * 0.52), (h * 0.84, r_end + (r_mid - r_end) * 0.52)):
        parts.append(L.cyl(rad + 0.045, 0.11, (cx, cy, z0 + dz - 0.055), "ironDark", verts=verts))
    parts.append(L.cyl(r_end * 0.82, 0.08, (cx, cy, z0 + h - 0.04), "woodLight", verts=verts))
    return parts


def tree_pine():
    """Pinheiro alpino esculpido: raizes abertas, tronco curvo e 22+ cachos conicos/ico (zero cubos)."""
    p = []

    # 1. Raizes abertas + tronco curvo em 4 segmentos
    for k in range(5):
        a = 2 * math.pi * k / 5 + 0.2
        p.append(L.crystal(0.32, 1.35, (0.28 * math.cos(a), 0.28 * math.sin(a), 0.0), "barkDark", tilt=(-0.92 * math.sin(a), 0.92 * math.cos(a)), verts=5))

    trunk_pts = [
        (0.0, 0.0, 0.0, 0.52, 0.42, 2.2, (0.04, 0.03)),
        (0.08, 0.05, 2.0, 0.42, 0.32, 2.2, (-0.05, 0.04)),
        (0.02, -0.04, 4.0, 0.32, 0.20, 2.4, (0.04, -0.05)),
        (0.10, -0.10, 6.2, 0.20, 0.06, 2.4, (0.0, 0.0)),
    ]
    for tx, ty, tz, r1, r2, h, (rx, ry) in trunk_pts:
        p.append(L.crystal(r1, h, (tx, ty, tz), "barkDark", tilt=(rx, ry), verts=7, r2=r2))

    # 2. 6 camadas de galhos/agulhas conicas + 18+ cachos sobrepostos (ico + cones multi-facetados)
    # Mistura leafDeep, leafMid, leafSun e moss sem nenhum cubo.
    tiers = (
        (2.4, 2.25, 2.15, "leafDeep", 5),
        (3.6, 1.95, 1.95, "leafMid", 5),
        (4.8, 1.65, 1.85, "leafDeep", 4),
        (6.0, 1.35, 1.70, "leafMid", 4),
        (7.1, 1.02, 1.55, "leafSun", 3),
    )
    for idx, (zt, rad, ht, col, nb) in enumerate(tiers):
        ox = 0.06 * math.cos(idx * 1.4)
        oy = 0.06 * math.sin(idx * 1.4)
        p.append(L.cyl(rad, ht, (ox, oy, zt), col, verts=7, r2=rad * 0.14, rot_z=idx * 0.45))
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
                    verts=6,
                    r2=0.05,
                )
            )
    # 4 tufos ico no miolo/copa para volume organico e topo em agulha
    for cx, cy, cz, cr, ccol in (
        (-0.55, -0.45, 3.1, 0.72, "moss"),
        (0.58, 0.40, 4.3, 0.68, "leafSun"),
        (-0.40, 0.48, 5.5, 0.58, "leafMid"),
        (0.32, -0.35, 6.7, 0.48, "leafSun"),
    ):
        p.append(_rot(L.ico(cr, (cx, cy, cz), ccol, squash=(1.12, 1.05, 0.76)), 0.18, -0.15, cz))
    p.append(L.cyl(0.66, 1.65, (0.08, -0.08, 8.25), "leafSun", verts=7, r2=0.0))

    return p


def tree_oak():
    """Carvalho antigo retorcido: tronco nodoso, 3 galhos bifurcados e copa assimetrica de 14+ ico."""
    p = []

    # 1. Raizes e tronco retorcido em 3 segmentos
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.35
        p.append(L.crystal(0.38, 1.45, (0.36 * math.cos(a), 0.36 * math.sin(a), 0.0), "barkDark", tilt=(-0.95 * math.sin(a), 0.95 * math.cos(a)), verts=5))

    p.append(L.crystal(0.68, 1.85, (0.0, 0.0, 0.0), "barkDark", tilt=(0.06, -0.05), verts=7, r2=0.52))
    p.append(L.crystal(0.54, 1.80, (-0.08, 0.10, 1.65), "barkDark", tilt=(-0.08, 0.10), verts=7, r2=0.42))
    p.append(L.crystal(0.42, 1.40, (0.06, 0.0, 3.20), "barkDark", tilt=(0.05, -0.06), verts=6, r2=0.28))

    # 2. 3 galhos bifurcados principais + ramos secundarios
    limbs = (
        (-0.08, -0.12, 3.70, 0.28, 2.45, (0.62, -0.45)),
        (0.12, 0.08, 3.90, 0.26, 2.35, (-0.42, 0.68)),
        (0.02, 0.14, 4.15, 0.24, 2.15, (-0.65, -0.25)),
    )
    for lx, ly, lz, r1, lh, (rx, ry) in limbs:
        p.append(L.crystal(r1, lh, (lx, ly, lz), "barkDark", tilt=(rx, ry), verts=5, r2=r1 * 0.40))

    # 3. Copa assimetrica com 14 tufos ico sobrepostos (leafDeep/leafMid/leafSun/oliveLeaf)
    tufts = (
        (0.05, -0.10, 5.85, 1.45, (1.18, 1.12, 0.84), "leafMid"),
        (-1.45, -1.05, 5.10, 1.22, (1.10, 1.05, 0.80), "leafDeep"),
        (1.55, -0.75, 5.35, 1.18, (1.12, 1.00, 0.82), "leafSun"),
        (-0.95, 1.35, 5.30, 1.25, (1.08, 1.16, 0.78), "oliveLeaf"),
        (1.25, 1.15, 5.15, 1.15, (1.15, 1.05, 0.82), "leafDeep"),
        (-1.95, 0.25, 4.65, 0.98, (1.05, 1.10, 0.80), "oliveLeaf"),
        (1.90, 0.35, 4.85, 0.96, (1.05, 1.02, 0.78), "leafMid"),
        (0.0, -1.55, 4.95, 1.06, (1.15, 0.96, 0.82), "leafSun"),
        (0.15, 1.60, 4.80, 1.02, (1.10, 1.00, 0.78), "leafDeep"),
        (-0.75, -0.45, 6.55, 1.05, (1.06, 1.04, 0.82), "leafSun"),
        (0.85, 0.35, 6.65, 1.02, (1.08, 1.02, 0.80), "oliveLeaf"),
        (0.10, 0.20, 7.15, 0.96, (1.12, 1.08, 0.78), "leafSun"),
        (-1.25, -0.65, 6.05, 0.88, (1.04, 1.06, 0.84), "leafMid"),
        (1.10, -0.35, 6.15, 0.86, (1.06, 1.02, 0.82), "leafSun"),
    )
    for idx, (cx, cy, cz, rad, sq, col) in enumerate(tufts):
        p.append(_rot(L.ico(rad, (cx, cy, cz), col, squash=sq), 0.14 * math.sin(idx), 0.18 * math.cos(idx), idx * 0.5))

    return p


def rock_cluster():
    """Afloramento de 5 rochas angulosas, almofadas de musgo e veio de quartzo ambar."""
    p = []

    boulders = (
        ((0.0, 0.10, 0.95), 1.45, (1.22, 0.96, 1.05), "stoneDark", (0.22, -0.18, 0.40)),
        ((-1.15, -0.55, 0.62), 1.02, (1.15, 0.90, 0.82), "stone", (-0.30, 0.25, 1.15)),
        ((1.10, -0.30, 0.58), 0.95, (1.05, 1.18, 0.78), "stoneLight", (0.18, 0.34, 2.10)),
        ((-0.45, 0.95, 0.52), 0.88, (1.10, 0.88, 0.75), "stone", (0.40, -0.12, 0.85)),
        ((0.65, 0.85, 0.44), 0.76, (1.18, 0.92, 0.68), "stoneDark", (-0.18, 0.32, 1.65)),
    )
    for pos, rad, sq, col, (rx, ry, rz) in boulders:
        p.append(_rot(L.ico(rad, pos, col, squash=sq), rx, ry, rz))

    # Almofadas de musgo
    for pos, rad, sq, rot_z in (
        ((-0.25, -0.20, 1.88), 0.62, (1.28, 1.10, 0.45), 0.4),
        ((-1.25, -0.60, 1.15), 0.48, (1.18, 1.05, 0.44), 1.3),
        ((0.95, -0.35, 1.05), 0.44, (1.15, 0.95, 0.42), 2.1),
    ):
        p.append(_rot(L.ico(rad, pos, "moss", squash=sq), 0.1, -0.1, rot_z))

    # Pequeno veio de quartzo ambar brotando da fenda frontal
    for pos, r, h, col, tilt in (
        ((0.28, -0.78, 0.45), 0.18, 0.88, "amber", (0.48, 0.22)),
        ((0.52, -0.72, 0.38), 0.14, 0.68, "amberBright", (0.58, 0.42)),
        ((0.08, -0.84, 0.36), 0.13, 0.62, "amber", (0.62, -0.18)),
        ((0.38, -0.62, 0.55), 0.12, 0.56, "amberBright", (0.28, 0.32)),
    ):
        p.append(L.crystal(r, h, pos, col, tilt=tilt, verts=5))

    return p


def siege_supply():
    """Suprimentos de cerco: palete, 2 barris arqueados com aros redondos, caixote e balas de canhao."""
    p = []

    # 1. Palete de madeira
    for sy in (-1.35, 0.0, 1.35):
        p.append(L.box((4.10, 0.28, 0.20), (0.0, sy, 0.10), "woodDark"))
    for k in range(5):
        sx = -1.75 + k * 0.875
        p.append(L.box((0.55, 3.20, 0.12), (sx, 0.0, 0.26), "wood"))

    # 2. Dois barris de carvalho com aduelas curvas e aros redondos (zero cubos!)
    p += _barrel((-1.15, -0.65, 0.32), 0.58, 0.72, 1.65, "wood", verts=10)
    p += _barrel((-0.95, 0.82, 0.32), 0.54, 0.68, 1.55, "woodLight", verts=10)

    # 3. Caixote de municao com travamentos diagonais em madeira e cantoneiras de ferro
    cx, cy, cz = 1.05, 0.62, 0.32
    cw, cd, ch = 1.65, 1.45, 1.25
    p.append(L.box((cw, cd, ch), (cx, cy, cz + ch / 2), "woodDark"))
    for sx in (-1, 1):
        for sy in (-1, 1):
            p.append(L.box((0.18, 0.18, ch + 0.06), (cx + sx * (cw / 2 - 0.05), cy + sy * (cd / 2 - 0.05), cz + ch / 2), "woodLight"))
    for sy in (-1, 1):
        p.append(L.box((cw + 0.06, 0.14, 0.16), (cx, cy + sy * (cd / 2 - 0.02), cz + ch - 0.04), "wood"))
        p.append(L.box((cw * 0.95, 0.12, 0.14), (cx, cy + sy * (cd / 2 + 0.02), cz + ch / 2), "woodLight", rot=(0, 0.58 * sy, 0)))
    for sx in (-1, 1):
        p.append(L.box((0.14, cd + 0.06, 0.16), (cx + sx * (cw / 2 - 0.02), cy, cz + ch - 0.04), "wood"))
        p.append(L.box((0.14, cd + 0.08, 0.14), (cx + sx * (cw / 2 - 0.02), cy, cz + 0.25), "ironDark"))

    # 4. Piramide de balas de canhao na bandeja frontal
    tx, ty, tz = 0.92, -0.82, 0.32
    for dx in (-0.65, 0.65):
        p.append(L.box((0.14, 1.28, 0.20), (tx + dx, ty, tz + 0.10), "woodDark"))
    for dy in (-0.57, 0.57):
        p.append(L.box((1.38, 0.14, 0.20), (tx, ty + dy, tz + 0.10), "woodDark"))
    r_ball = 0.27
    for dx in (-0.27, 0.27):
        for dy in (-0.27, 0.27):
            p.append(L.ball(r_ball, (tx + dx, ty + dy, tz + r_ball + 0.04), "ironDark", seg=8, rings=5))
    p.append(L.ball(r_ball, (tx, ty, tz + r_ball + 0.42), "iron", seg=8, rings=5))

    return p


def iron_brazier():
    """Braseiro de ferro: pedestal octogonal escalonado, 3 pes em garra, bojo rebitado e brasas."""
    p = []

    # 1. Pedestal octogonal escalonado em stoneDark
    p.append(L.cyl(1.45, 0.34, (0, 0, 0.0), "stoneDark", verts=8))
    p.append(L.cyl(1.18, 0.30, (0, 0, 0.34), "stone", verts=8))
    p.append(L.cyl(0.95, 0.24, (0, 0, 0.64), "stoneDark", verts=8))

    # 2. 3 pernas em garra de ferro forjado a 120 graus
    for k in range(3):
        a = 2 * math.pi * k / 3 - math.pi / 2
        ca, sa = math.cos(a), math.sin(a)
        p.append(L.box((0.28, 0.42, 0.22), (0.88 * ca, 0.88 * sa, 0.98), "ironDark", rot=(0, 0, a + math.pi / 2)))
        p.append(L.box((0.22, 0.24, 0.85), (0.98 * ca, 0.98 * sa, 1.38), "iron", rot=(-0.34 * sa, 0.34 * ca, a + math.pi / 2)))
        p.append(L.box((0.24, 0.24, 0.72), (1.06 * ca, 1.06 * sa, 2.02), "ironDark", rot=(0.24 * sa, -0.24 * ca, a + math.pi / 2)))
        p.append(L.box((0.26, 0.30, 0.24), (1.16 * ca, 1.16 * sa, 2.38), "iron", rot=(0, 0, a + math.pi / 2)))

    # 3. Bojo afunilado e borda rebitada
    p.append(L.cyl(0.55, 0.35, (0, 0, 1.85), "ironDark", verts=10, r2=0.92))
    p.append(L.cyl(0.92, 0.56, (0, 0, 2.20), "iron", verts=10, r2=1.28))
    p.append(L.cyl(1.32, 0.22, (0, 0, 2.72), "ironDark", verts=10, r2=1.34))
    for k in range(8):
        a = 2 * math.pi * k / 8
        p.append(L.ball(0.08, (1.28 * math.cos(a), 1.28 * math.sin(a), 2.80), "steel", seg=6, rings=3))

    # 4. Monte de brasas e linguas de fogo
    p.append(_rot(L.ico(0.88, (0, 0, 2.86), "danger", squash=(1.05, 1.05, 0.52)), 0.1, 0.2, 0.5))
    for k, (rad, h, col, tilt) in enumerate(
        (
            (0.28, 0.95, "amberBright", (0.10, -0.08)),
            (0.24, 0.82, "ember", (-0.28, 0.22)),
            (0.22, 0.74, "amberBright", (0.30, 0.26)),
            (0.20, 0.68, "danger", (-0.22, -0.30)),
            (0.18, 0.64, "ember", (0.18, -0.28)),
        )
    ):
        a = 2 * math.pi * k / 5
        d = 0.0 if k == 0 else 0.38
        p.append(L.crystal(rad, h, (d * math.cos(a), d * math.sin(a), 2.94), col, tilt=tilt, verts=4))

    return p


def rift_obelisk():
    """Obelisco da fenda: base em obsidiana, fuste torcido com colar de ferro e cristais da fenda."""
    p = []

    # 1. Base escalonada de obsidiana + 4 garras laterais
    p.append(L.cyl(1.75, 0.42, (0, 0, 0.0), "ironDark", verts=8, r2=1.55))
    p.append(L.cyl(1.42, 0.36, (0, 0, 0.42), "stoneDark", verts=8, r2=1.22))
    p.append(L.cyl(1.12, 0.32, (0, 0, 0.78), "ink", verts=8, r2=0.95))
    for k in range(4):
        a = math.pi / 4 + k * math.pi / 2
        p.append(L.crystal(0.32, 1.25, (1.18 * math.cos(a), 1.18 * math.sin(a), 0.25), "ironDark", tilt=(0.35 * math.sin(a), -0.35 * math.cos(a)), verts=4))

    # 2. Obelisco facetado torcido em 4 segmentos + ponta piramidal
    segs = (
        (1.08, 0.82, 0.70, 1.25, 0.0, "ink"),
        (2.25, 0.72, 0.62, 1.25, 0.22, "ironDark"),
        (3.42, 0.64, 0.54, 1.25, 0.44, "ink"),
        (4.58, 0.56, 0.44, 1.20, 0.66, "ironDark"),
    )
    for z0, r1, r2, h, rz, col in segs:
        p.append(L.cyl(r1, h, (0, 0, z0), col, verts=4, r2=r2, rot_z=math.pi / 4 + rz))
    p.append(L.cyl(0.46, 1.15, (0, 0, 5.75), "ink", verts=4, r2=0.0, rot_z=math.pi / 4 + 0.88))

    # 3. Colar de contencao em ferro com rebites
    p.append(L.cyl(0.84, 0.44, (0, 0, 3.15), "iron", verts=8, r2=0.80))
    for k in range(4):
        a = k * math.pi / 2 + 0.33
        p.append(L.box((0.28, 0.34, 0.56), (0.78 * math.cos(a), 0.78 * math.sin(a), 3.37), "steel", rot=(0, 0, a)))

    # 4. Cristais da fenda brotando da base, colar e topo
    shards = (
        ((-0.78, -0.62, 0.75), 0.22, 1.25, "teal", (0.38, 0.28)),
        ((0.82, -0.45, 0.72), 0.20, 1.15, "tealSwarm", (0.32, -0.38)),
        ((-0.45, 0.85, 0.70), 0.18, 1.05, "eyeNeon", (-0.42, 0.22)),
        ((0.68, 0.72, 0.74), 0.20, 1.20, "teal", (-0.36, -0.34)),
        ((0.0, -0.64, 3.35), 0.17, 1.05, "eyeNeon", (0.72, 0.0)),
        ((-0.58, 0.25, 3.45), 0.16, 0.95, "tealSwarm", (-0.28, 0.65)),
        ((0.55, 0.28, 3.40), 0.16, 0.92, "teal", (-0.25, -0.68)),
        ((0.18, -0.45, 4.95), 0.14, 0.88, "eyeNeon", (0.55, -0.25)),
    )
    for pos, r, h, col, tilt in shards:
        p.append(L.crystal(r, h, pos, col, tilt=tilt, verts=5))
    p.append(_rot(L.ico(0.28, (0.0, 0.0, 7.22), "eyeNeon", squash=(0.75, 0.75, 1.45)), 0.1, 0.15, 0.4))

    return p


SPECS = [
    {
        "id": "prop.tree_pine.01",
        "name": "PROP_tree_pine",
        "glb": "tree_pine.glb",
        "tipo": "prop_estatico",
        "limite": 1400,
        "center_xy": True,
        "tags": ["muralha", "prop", "nature", "tree_pine"],
        "seed": L.SEED_BASE + 7101,
        "build": tree_pine,
    },
    {
        "id": "prop.tree_oak.01",
        "name": "PROP_tree_oak",
        "glb": "tree_oak.glb",
        "tipo": "prop_estatico",
        "limite": 1400,
        "center_xy": True,
        "tags": ["muralha", "prop", "nature", "tree_oak"],
        "seed": L.SEED_BASE + 7202,
        "build": tree_oak,
    },
    {
        "id": "prop.rock_cluster.01",
        "name": "PROP_rock_cluster",
        "glb": "rock_cluster.glb",
        "tipo": "prop_estatico",
        "limite": 900,
        "center_xy": True,
        "tags": ["muralha", "prop", "nature", "rock"],
        "seed": L.SEED_BASE + 7303,
        "build": rock_cluster,
    },
    {
        "id": "prop.siege_supply.01",
        "name": "PROP_siege_supply",
        "glb": "siege_supply.glb",
        "tipo": "prop_estatico",
        "limite": 1300,
        "center_xy": True,
        "tags": ["muralha", "prop", "siege", "supply"],
        "seed": L.SEED_BASE + 7404,
        "build": siege_supply,
    },
    {
        "id": "prop.iron_brazier.01",
        "name": "PROP_iron_brazier",
        "glb": "iron_brazier.glb",
        "tipo": "prop_estatico",
        "limite": 1100,
        "center_xy": True,
        "tags": ["muralha", "prop", "brazier", "light"],
        "seed": L.SEED_BASE + 7505,
        "build": iron_brazier,
    },
    {
        "id": "prop.rift_obelisk.01",
        "name": "PROP_rift_obelisk",
        "glb": "rift_obelisk.glb",
        "tipo": "prop_estatico",
        "limite": 1200,
        "center_xy": True,
        "tags": ["muralha", "prop", "rift", "obelisk"],
        "seed": L.SEED_BASE + 7606,
        "build": rift_obelisk,
    },
]

L.run_group("props", SPECS, "props de cenario e natureza esculpidos (art/scripts/make_props.py)")
