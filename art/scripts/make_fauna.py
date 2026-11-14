"""Gera 9 malhas de fauna low-poly para o Bastiao (FAUNA_).

Convencoes: Z-up, frente = -Y (bico/focinho), cauda = +Y, <= 1100 tris por malha.
IMPORTANTE: as 4 asas (`wyvern_wing_l/r`, `bird_wing_l/r`) mantem `center_xy=False` e `pivot: origem`
para preservar a origem da articulacao de ombro em (0, 0, 0) e a extensao pura em -X / +X.

Itens (id Forge3D -> objeto):
  1. fauna.wyvern_body.01   -> FAUNA_wyvern_body   (wyvern_body.glb)
  2. fauna.wyvern_wing_l.01 -> FAUNA_wyvern_wing_l (wyvern_wing_l.glb)
  3. fauna.wyvern_wing_r.01 -> FAUNA_wyvern_wing_r (wyvern_wing_r.glb)
  4. fauna.bird_body.01     -> FAUNA_bird_body     (bird_body.glb)
  5. fauna.bird_wing_l.01   -> FAUNA_bird_wing_l   (bird_wing_l.glb)
  6. fauna.bird_wing_r.01   -> FAUNA_bird_wing_r   (bird_wing_r.glb)
  7. fauna.stag.01          -> FAUNA_stag          (stag.glb)
  8. fauna.pack_ox.01       -> FAUNA_pack_ox       (pack_ox.glb)
  9. fauna.ram.01           -> FAUNA_ram           (ram.glb)

Uso headless:
  blender -b --factory-startup --python-exit-code 1 --python art/scripts/make_fauna.py
"""

from __future__ import annotations

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lowpoly_lib as L  # noqa: E402

LIMITE = 1100


def _from_bm(bm, name, color):
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    return L.paint(obj, color)


def _limb_seg(p0, p1, r0, r1, color, verts=6):
    """Segmento cilindrico afilado de p0 ate p1 (manifold)."""
    v0, v1 = Vector(p0), Vector(p1)
    d = v1 - v0
    length = d.length
    mid = (v0 + v1) * 0.5
    rot = d.normalized().to_track_quat("Z", "Y").to_euler("XYZ")
    bpy.ops.mesh.primitive_cone_add(
        vertices=verts, radius1=r0, radius2=r1, depth=length, location=tuple(mid), rotation=tuple(rot)
    )
    o = bpy.context.view_layer.objects.active
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return L.paint(o, color)


def _wing_membrane(ring_pts, hub_pt, thickness, color):
    """Membrana manifold solida com recorte entre pontas, triangulada em leque sem arestas abertas."""
    bm = bmesh.new()
    dz = thickness * 0.5
    vt = [bm.verts.new((px, py, pz + dz)) for px, py, pz in ring_pts]
    vb = [bm.verts.new((px, py, pz - dz)) for px, py, pz in ring_pts]
    ht = bm.verts.new((hub_pt[0], hub_pt[1], hub_pt[2] + dz))
    hb = bm.verts.new((hub_pt[0], hub_pt[1], hub_pt[2] - dz))
    n = len(ring_pts)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((ht, vt[i], vt[j]))
        bm.faces.new((hb, vb[j], vb[i]))
        bm.faces.new((vb[i], vb[j], vt[j], vt[i]))
    return _from_bm(bm, "wing_membrane", color)


def _feather(p0, p1, w0, w1, thick, color):
    """Pena achatada manifold de p0 ate p1."""
    v0, v1 = Vector(p0), Vector(p1)
    fwd = (v1 - v0).normalized()
    up = Vector((0, 0, 1))
    side = fwd.cross(up)
    if side.length < 1e-4:
        side = Vector((1, 0, 0))
    side.normalize()
    nrm = side.cross(fwd).normalized()
    hw0, hw1, ht = w0 * 0.5, w1 * 0.5, thick * 0.5
    pts = [
        v0 - side * hw0 - nrm * ht,
        v0 + side * hw0 - nrm * ht,
        v0 + side * hw0 + nrm * ht,
        v0 - side * hw0 + nrm * ht,
        v1 - side * hw1 - nrm * ht,
        v1 + side * hw1 - nrm * ht,
        v1 + side * hw1 + nrm * ht,
        v1 - side * hw1 + nrm * ht,
    ]
    bm = bmesh.new()
    vs = [bm.verts.new(tuple(pt)) for pt in pts]
    for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        bm.faces.new([vs[i] for i in f])
    return _from_bm(bm, "feather", color)


# ---------------------------------------------------------------- 1. Wyvern
def wyvern_body():
    """Corpo do wyvern: peito blindado, cabeca chifruda (-Y), encaixes de ombro +-0.55 e cauda em +Y."""
    p = []

    # Torso arqueado e peitoral blindado
    p.append(L.ball(0.68, (0, 0.0, 1.55), "wyvernScale", seg=8, rings=5, squash=(0.92, 1.38, 0.96)))
    p.append(L.ico(0.54, (0, -0.35, 1.72), "roof", squash=(0.98, 1.05, 0.88)))
    for dy, dz in ((-0.52, 1.32), (-0.18, 1.18), (0.20, 1.24)):
        p.append(L.box((0.86, 0.34, 0.22), (0, dy, dz), "amber", rot=(0.24, 0, 0)))

    # Encaixes de ombro em x = +-0.55
    for sx in (-1, 1):
        p.append(L.ball(0.32, (sx * 0.55, -0.25, 1.78), "wyvernScale", seg=6, rings=4))
        p.append(L.crystal(0.18, 0.42, (sx * 0.62, -0.22, 1.96), "roof", tilt=(0.2, -sx * 0.45), verts=4))

    # Pescoco em S e cabeca draconica para -Y
    p.append(_limb_seg((0, -0.58, 1.72), (0, -1.08, 2.20), 0.36, 0.28, "wyvernScale", verts=7))
    p.append(_limb_seg((0, -1.08, 2.20), (0, -1.35, 2.58), 0.28, 0.24, "roof", verts=7))
    # Cranio, focinho, mandibula, olhos amberBright e chifres hornIvory
    p.append(L.box((0.54, 0.68, 0.44), (0, -1.58, 2.66), "wyvernScale"))
    p.append(L.box((0.36, 0.58, 0.24), (0, -2.05, 2.64), "roof"))
    p.append(L.box((0.30, 0.50, 0.14), (0, -2.00, 2.46), "amber"))
    for sx in (-1, 1):
        p.append(L.box((0.12, 0.16, 0.12), (sx * 0.24, -1.82, 2.74), "amberBright"))
        p.append(L.crystal(0.11, 0.82, (sx * 0.20, -1.35, 2.84), "hornIvory", tilt=(-0.92, -sx * 0.28), verts=5))

    # Pernas traseiras recolhidas com garras
    for sx in (-1, 1):
        p.append(_limb_seg((sx * 0.42, 0.48, 1.38), (sx * 0.52, 0.22, 0.72), 0.26, 0.16, "wyvernScale", verts=6))
        p.append(_limb_seg((sx * 0.52, 0.22, 0.72), (sx * 0.48, 0.58, 0.16), 0.16, 0.12, "roof", verts=6))
        p.append(L.box((0.28, 0.44, 0.16), (sx * 0.48, 0.36, 0.08), "ironDark"))

    # Cauda ondulante com espinhos para +Y
    tail_pts = ((0, 0.75, 1.52), (0, 1.48, 1.48), (0, 2.22, 1.66), (0, 2.95, 1.82), (0, 3.65, 1.68))
    rads = (0.36, 0.26, 0.18, 0.11, 0.05)
    for i in range(len(tail_pts) - 1):
        p.append(_limb_seg(tail_pts[i], tail_pts[i + 1], rads[i], rads[i + 1], "wyvernScale", verts=6))
        mid = ((tail_pts[i][0] + tail_pts[i + 1][0]) * 0.5, (tail_pts[i][1] + tail_pts[i + 1][1]) * 0.5, (tail_pts[i][2] + tail_pts[i + 1][2]) * 0.5 + 0.12)
        p.append(L.crystal(0.08, 0.34 - i * 0.05, mid, "hornIvory", tilt=(-0.55, 0), verts=4))
    p.append(L.crystal(0.18, 0.52, tail_pts[-1], "amber", tilt=(-1.45, 0), verts=4))

    return p


def wyvern_wing(side):
    """Asa de dragao a partir do ombro (0, 0, 0) para side*X (~4.8 studs), 3 dedos + membrana recortada."""
    # side = -1 para esquerda (-X), +1 para direita (+X)
    s = side
    p = []

    # Cubo/junta de ombro em (0, 0, 0.18) -> base em Z=0, origem de pivot (0, 0, 0) preservada
    sh = (0.0, 0.0, 0.18)
    elbow = (s * 1.45, -0.34, 0.68)
    wrist = (s * 2.55, -0.52, 1.12)
    f1 = (s * 4.78, -0.18, 1.48)
    f2 = (s * 4.15, 0.88, 1.10)
    f3 = (s * 2.75, 1.52, 0.68)
    flank = (s * 0.28, 1.05, 0.16)

    p.append(L.ball(0.18, sh, "wyvernScale", seg=6, rings=4))
    p.append(_limb_seg(sh, elbow, 0.15, 0.12, "wyvernScale", verts=6))
    p.append(_limb_seg(elbow, wrist, 0.13, 0.11, "roof", verts=6))
    p.append(L.crystal(0.09, 0.42, (wrist[0], wrist[1] - 0.06, wrist[2] + 0.05), "hornIvory", tilt=(0.75, 0), verts=4))

    # 3 dedos ossudos + membrana recortada em bays
    for tip, r0 in ((f1, 0.095), (f2, 0.08), (f3, 0.07)):
        p.append(_limb_seg(wrist, tip, r0, 0.03, "wyvernScale", verts=5))

    bay12 = (s * 3.85, 0.34, 1.02)
    bay23 = (s * 3.05, 0.92, 0.72)
    bay3f = (s * 1.45, 0.95, 0.34)
    ring = [sh, elbow, wrist, f1, bay12, f2, bay23, f3, bay3f, flank]
    hub = (s * 2.05, 0.35, 0.74)
    p.append(_wing_membrane(ring, hub, 0.055, "wyvernWing"))

    return p


# ---------------------------------------------------------------- 2. Bird (Falcao / Corvo de Vigia)
def bird_body():
    """Corpo aerodinamico de falcao/corvo de vigia: bico ambar (-Y), cauda em leque (+Y)."""
    p = []

    p.append(L.ball(0.46, (0, 0.0, 0.96), "ironDark", seg=8, rings=5, squash=(0.82, 1.42, 0.88)))
    p.append(L.ball(0.38, (0, -0.18, 0.88), "stoneDark", seg=7, rings=4, squash=(0.76, 1.10, 0.72)))
    for sx in (-1, 1):
        p.append(L.ball(0.16, (sx * 0.32, -0.08, 1.08), "iron", seg=6, rings=3))

    # Cabeca e bico ganchoso em -Y
    p.append(L.ball(0.28, (0, -0.58, 1.24), "ironDark", seg=8, rings=4, squash=(0.90, 1.08, 0.92)))
    p.append(_limb_seg((0, -0.78, 1.24), (0, -1.14, 1.16), 0.11, 0.02, "amber", verts=5))
    p.append(L.crystal(0.05, 0.14, (0, -1.10, 1.15), "amber", tilt=(2.35, 0), verts=4))
    for sx in (-1, 1):
        p.append(L.box((0.07, 0.09, 0.07), (sx * 0.16, -0.70, 1.29), "amberBright"))

    # Garras recolhidas
    for sx in (-1, 1):
        p.append(_limb_seg((sx * 0.16, 0.05, 0.62), (sx * 0.18, -0.05, 0.16), 0.07, 0.04, "amber", verts=5))
        p.append(L.box((0.14, 0.24, 0.08), (sx * 0.18, -0.08, 0.08), "ironDark"))

    # Leque de 5 penas na cauda (+Y)
    for k in range(-2, 3):
        ang = k * 0.18
        tip = (0.45 * math.sin(ang), 1.45 * math.cos(ang), 0.92 + abs(k) * 0.02)
        p.append(_feather((0, 0.45, 0.92), tip, 0.20, 0.28, 0.045, "stoneDark" if k % 2 == 0 else "ironDark"))

    return p


def bird_wing(side):
    """Asa emplumada pontiaguda a partir do ombro (0, 0, 0) para side*X (~3.2 studs)."""
    s = side
    p = []

    sh = (0.0, 0.0, 0.14)
    wrist = (s * 1.45, -0.22, 0.62)
    tip = (s * 3.15, 0.24, 0.98)

    p.append(L.ball(0.14, sh, "ironDark", seg=6, rings=3))
    p.append(_limb_seg(sh, wrist, 0.13, 0.10, "ironDark", verts=6))
    p.append(_limb_seg(wrist, tip, 0.10, 0.03, "stoneDark", verts=5))

    # Cobertura superior + 6 penas primarias/secundarias escalonadas
    p.append(_wing_membrane([sh, wrist, tip, (s * 1.95, 0.48, 0.56), (s * 0.35, 0.58, 0.18)], (s * 1.35, 0.16, 0.48), 0.05, "iron"))
    feathers = (
        ((s * 2.10, -0.02, 0.72), (s * 3.20, 0.42, 0.96), 0.22, 0.10, "ironDark"),
        ((s * 1.75, 0.08, 0.62), (s * 2.82, 0.72, 0.80), 0.24, 0.12, "stoneDark"),
        ((s * 1.40, 0.14, 0.52), (s * 2.38, 0.95, 0.64), 0.24, 0.14, "ironDark"),
        ((s * 1.05, 0.20, 0.42), (s * 1.85, 1.06, 0.48), 0.26, 0.16, "stone"),
        ((s * 0.70, 0.25, 0.32), (s * 1.32, 1.08, 0.36), 0.26, 0.18, "stoneDark"),
        ((s * 0.36, 0.28, 0.22), (s * 0.78, 1.00, 0.24), 0.26, 0.18, "ironDark"),
    )
    for p0, p1, w0, w1, col in feathers:
        p.append(_feather(p0, p1, w0, w1, 0.04, col))

    return p


# ---------------------------------------------------------------- 3. Stag (Cervo Real)
def stag():
    """Cervo nobre da floresta: corpo furBrown/furTan, pernas esguias e galhada ramificada."""
    p = []

    # Torso, peito claro e cauda branca
    p.append(L.ball(0.62, (0, 0.05, 1.52), "furBrown", seg=8, rings=5, squash=(0.76, 1.48, 0.86)))
    p.append(L.ball(0.50, (0, -0.52, 1.54), "furTan", seg=7, rings=4, squash=(0.74, 0.92, 0.88)))
    p.append(L.crystal(0.14, 0.34, (0, 0.92, 1.62), "white", tilt=(-0.95, 0), verts=5))

    # 4 pernas esguias + cascos
    legs = (
        (-0.24, -0.54, 1.32, -0.58),
        (0.24, -0.54, 1.32, -0.58),
        (-0.24, 0.62, 1.34, 0.66),
        (0.24, 0.62, 1.34, 0.66),
    )
    for lx, ly, lz, fy in legs:
        knee_y = (ly + fy) * 0.5 - 0.04
        p.append(_limb_seg((lx, ly, lz), (lx, knee_y, 0.68), 0.14, 0.085, "furBrown", verts=6))
        p.append(_limb_seg((lx, knee_y, 0.68), (lx, fy, 0.12), 0.08, 0.06, "furTan", verts=6))
        p.append(L.cyl(0.085, 0.12, (lx, fy, 0.0), "ironDark", verts=6))

    # Pescoco erguido + cabeca (-Y) + orelhas
    p.append(_limb_seg((0, -0.64, 1.68), (0, -1.04, 2.48), 0.28, 0.19, "furBrown", verts=7))
    p.append(L.box((0.36, 0.52, 0.34), (0, -1.16, 2.60), "furBrown"))
    p.append(L.box((0.22, 0.36, 0.22), (0, -1.52, 2.52), "furTan"))
    p.append(L.box((0.14, 0.10, 0.12), (0, -1.70, 2.54), "ink"))
    for sx in (-1, 1):
        p.append(L.box((0.08, 0.10, 0.08), (sx * 0.18, -1.28, 2.66), "ink"))
        p.append(L.crystal(0.08, 0.32, (sx * 0.22, -1.02, 2.72), "furTan", tilt=(-0.45, -sx * 0.85), verts=4))

        # Galhada ramificada em hornIvory / amber
        b0 = (sx * 0.14, -1.06, 2.78)
        b1 = (sx * 0.42, -0.82, 3.30)
        b2 = (sx * 0.68, -0.52, 3.82)
        p.append(_limb_seg(b0, b1, 0.06, 0.048, "hornIvory", verts=5))
        p.append(_limb_seg(b1, b2, 0.048, 0.032, "hornIvory", verts=5))
        p.append(_limb_seg(b0, (sx * 0.28, -1.42, 3.16), 0.04, 0.015, "amber", verts=4))
        p.append(_limb_seg(b1, (sx * 0.54, -1.08, 3.72), 0.038, 0.014, "hornIvory", verts=4))
        p.append(_limb_seg(b2, (sx * 0.62, -0.35, 4.18), 0.032, 0.012, "amber", verts=4))

    return p


# ---------------------------------------------------------------- 4. Pack Ox (Boi de Carga)
def pack_ox():
    """Boi de carga robusto do Bastiao: canga de madeira e alforges laterais transbordando cristais ambar."""
    p = []

    # Tronco pesado, cupim nos ombros e focinho largo (-Y)
    p.append(L.ball(0.82, (0, 0.15, 1.38), "furBrown", seg=8, rings=5, squash=(0.94, 1.46, 0.92)))
    p.append(L.ball(0.76, (0, -0.55, 1.48), "woodDark", seg=8, rings=5, squash=(0.98, 0.96, 1.02)))
    p.append(L.box((0.56, 0.56, 0.52), (0, -1.18, 1.42), "furBrown"))
    p.append(L.box((0.46, 0.34, 0.34), (0, -1.52, 1.28), "furTan"))
    p.append(L.box((0.18, 0.14, 0.14), (0, -1.70, 1.24), "ink"))
    p.append(L.cyl(0.14, 0.18, (0, -1.70, 1.08), "gold", verts=8))  # argola no focinho
    for sx in (-1, 1):
        p.append(L.box((0.10, 0.10, 0.10), (sx * 0.28, -1.30, 1.50), "ink"))
        # Chifres curvos em hornIvory
        c0 = (sx * 0.24, -1.16, 1.66)
        c1 = (sx * 0.64, -1.24, 1.82)
        c2 = (sx * 0.72, -1.48, 2.08)
        p.append(_limb_seg(c0, c1, 0.10, 0.075, "hornIvory", verts=6))
        p.append(_limb_seg(c1, c2, 0.075, 0.025, "hornIvory", verts=5))

    # 4 pernas robustas + cascos
    for sx in (-1, 1):
        for sy, fy in ((-0.62, -0.66), (0.68, 0.72)):
            p.append(_limb_seg((sx * 0.44, sy, 1.05), (sx * 0.44, fy, 0.16), 0.19, 0.14, "woodDark", verts=6))
            p.append(L.cyl(0.16, 0.16, (sx * 0.44, fy, 0.0), "ironDark", verts=6))

    # Cauda
    p.append(_limb_seg((0, 1.18, 1.48), (0, 1.42, 0.78), 0.07, 0.04, "woodDark", verts=5))

    # Canga de madeira sobre a cernelha
    p.append(L.box((1.58, 0.34, 0.26), (0, -0.68, 2.10), "wood"))
    for sx in (-1, 1):
        p.append(L.box((0.14, 0.26, 0.56), (sx * 0.62, -0.68, 1.82), "woodLight"))

    # Dois alforges laterais cheios de cristais ambar brilhantes
    p.append(L.box((1.38, 0.28, 0.16), (0, 0.18, 2.06), "woodDark"))
    for sx in (-1, 1):
        bx = sx * 0.96
        p.append(L.box((0.58, 1.15, 0.78), (bx, 0.18, 1.56), "woodDark"))
        p.append(L.box((0.62, 1.18, 0.16), (bx, 0.18, 1.94), "wood"))
        for dy, col, h, tilt in ((-0.28, "amber", 0.54, (0.2, -sx * 0.25)), (0.04, "amberBright", 0.66, (0.0, -sx * 0.18)), (0.32, "amber", 0.48, (-0.25, -sx * 0.30))):
            p.append(L.crystal(0.14, h, (bx + sx * 0.04, 0.18 + dy, 1.98), col, tilt=tilt, verts=5))

    return p


# ---------------------------------------------------------------- 5. Ram (Carneiro da Montanha)
def ram():
    """Carneiro de montanha: corpo lanoso stoneLight/furTan, cascos escuros e chifres espiralados."""
    p = []

    # Corpo lanoso + juba peitoral
    p.append(L.ball(0.62, (0, 0.10, 1.12), "stoneLight", seg=8, rings=5, squash=(0.88, 1.34, 0.92)))
    p.append(L.ball(0.54, (0, -0.45, 1.18), "furTan", seg=7, rings=4, squash=(0.86, 0.96, 0.96)))
    p.append(L.ball(0.22, (0, 0.88, 1.24), "stoneLight", seg=6, rings=4))

    # 4 pernas firmes + cascos
    for sx in (-1, 1):
        for sy, fy in ((-0.46, -0.50), (0.56, 0.60)):
            p.append(_limb_seg((sx * 0.32, sy, 0.88), (sx * 0.32, fy, 0.14), 0.14, 0.10, "furBrown", verts=6))
            p.append(L.cyl(0.12, 0.14, (sx * 0.32, fy, 0.0), "ironDark", verts=6))

    # Cabeca forte (-Y) + chifres espiralados em hornIvory
    p.append(L.box((0.42, 0.56, 0.38), (0, -0.92, 1.44), "furBrown"))
    p.append(L.box((0.28, 0.34, 0.24), (0, -1.24, 1.34), "furTan"))
    for sx in (-1, 1):
        p.append(L.box((0.08, 0.10, 0.08), (sx * 0.21, -1.08, 1.50), "amberBright"))
        # Espiral de 5 segmentos ao redor da lateral do cranio
        pts = (
            (sx * 0.16, -0.82, 1.62),
            (sx * 0.40, -0.62, 1.72),
            (sx * 0.54, -0.56, 1.46),
            (sx * 0.52, -0.82, 1.24),
            (sx * 0.46, -1.08, 1.32),
            (sx * 0.52, -1.16, 1.48),
        )
        rads = (0.14, 0.12, 0.10, 0.08, 0.055, 0.025)
        for i in range(len(pts) - 1):
            p.append(_limb_seg(pts[i], pts[i + 1], rads[i], rads[i + 1], "hornIvory", verts=6))

    return p


SPECS = [
    {
        "id": "fauna.wyvern_body.01",
        "name": "FAUNA_wyvern_body",
        "glb": "wyvern_body.glb",
        "tipo": "prop_estatico",
        "limite": LIMITE,
        "center_xy": True,
        "tags": ["muralha", "fauna", "wyvern", "body"],
        "seed": L.SEED_BASE + 8101,
        "build": wyvern_body,
    },
    {
        "id": "fauna.wyvern_wing_l.01",
        "name": "FAUNA_wyvern_wing_l",
        "glb": "wyvern_wing_l.glb",
        "tipo": "prop_estatico",
        "pivot": "origem",
        "center_xy": False,
        "limite": LIMITE,
        "tags": ["muralha", "fauna", "wyvern", "wing_l"],
        "seed": L.SEED_BASE + 8102,
        "build": (lambda: wyvern_wing(-1)),
    },
    {
        "id": "fauna.wyvern_wing_r.01",
        "name": "FAUNA_wyvern_wing_r",
        "glb": "wyvern_wing_r.glb",
        "tipo": "prop_estatico",
        "pivot": "origem",
        "center_xy": False,
        "limite": LIMITE,
        "tags": ["muralha", "fauna", "wyvern", "wing_r"],
        "seed": L.SEED_BASE + 8103,
        "build": (lambda: wyvern_wing(1)),
    },
    {
        "id": "fauna.bird_body.01",
        "name": "FAUNA_bird_body",
        "glb": "bird_body.glb",
        "tipo": "prop_estatico",
        "limite": LIMITE,
        "center_xy": True,
        "tags": ["muralha", "fauna", "bird", "body"],
        "seed": L.SEED_BASE + 8201,
        "build": bird_body,
    },
    {
        "id": "fauna.bird_wing_l.01",
        "name": "FAUNA_bird_wing_l",
        "glb": "bird_wing_l.glb",
        "tipo": "prop_estatico",
        "pivot": "origem",
        "center_xy": False,
        "limite": LIMITE,
        "tags": ["muralha", "fauna", "bird", "wing_l"],
        "seed": L.SEED_BASE + 8202,
        "build": (lambda: bird_wing(-1)),
    },
    {
        "id": "fauna.bird_wing_r.01",
        "name": "FAUNA_bird_wing_r",
        "glb": "bird_wing_r.glb",
        "tipo": "prop_estatico",
        "pivot": "origem",
        "center_xy": False,
        "limite": LIMITE,
        "tags": ["muralha", "fauna", "bird", "wing_r"],
        "seed": L.SEED_BASE + 8203,
        "build": (lambda: bird_wing(1)),
    },
    {
        "id": "fauna.stag.01",
        "name": "FAUNA_stag",
        "glb": "stag.glb",
        "tipo": "prop_estatico",
        "limite": LIMITE,
        "center_xy": True,
        "tags": ["muralha", "fauna", "stag"],
        "seed": L.SEED_BASE + 8301,
        "build": stag,
    },
    {
        "id": "fauna.pack_ox.01",
        "name": "FAUNA_pack_ox",
        "glb": "pack_ox.glb",
        "tipo": "prop_estatico",
        "limite": LIMITE,
        "center_xy": True,
        "tags": ["muralha", "fauna", "pack_ox"],
        "seed": L.SEED_BASE + 8401,
        "build": pack_ox,
    },
    {
        "id": "fauna.ram.01",
        "name": "FAUNA_ram",
        "glb": "ram.glb",
        "tipo": "prop_estatico",
        "limite": LIMITE,
        "center_xy": True,
        "tags": ["muralha", "fauna", "ram"],
        "seed": L.SEED_BASE + 8501,
        "build": ram,
    },
]

L.run_group("fauna", SPECS, "fauna articulada e silvestre do Bastiao (art/scripts/make_fauna.py)")
