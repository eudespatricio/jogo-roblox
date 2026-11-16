"""Gera 9 malhas de fauna low-poly esculpidas para o Bastiao (FAUNA_).

Convencoes: Z-up, frente = -Y (bico/focinho), cauda = +Y, <= 2200 tris por malha (alvo 900..1900).
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

LIMITE = 2200
NORMALS_FAUNA = {
    "modo": "hard_surface",
    "angulo_graus": 52,
    "weighted_normals": False,
    "corrective_smooth": False,
}


def _from_bm(bm, name, color):
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    return L.paint(obj, color)


def _limb_seg(p0, p1, r0, r1, color, verts=14):
    """Segmento cilindrico afilado de p0 ate p1 (manifold)."""
    v0, v1 = Vector(p0), Vector(p1)
    d = v1 - v0
    length = max(d.length, 1e-4)
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

    # Torso arqueado e peitoral blindado suave
    p.append(L.ball(0.68, (0, 0.0, 1.55), "wyvernScale", seg=18, rings=12, squash=(0.92, 1.38, 0.96)))
    p.append(L.ico(0.55, (0, -0.35, 1.72), "roof", squash=(0.98, 1.05, 0.88), subdiv=2))
    for dy, dz in ((-0.52, 1.32), (-0.18, 1.18), (0.20, 1.24)):
        p.append(L.ball(0.32, (0, dy, dz), "amber", seg=8, rings=4, squash=(1.35, 0.58, 0.42)))

    # Encaixes de ombro em x = +-0.55
    for sx in (-1, 1):
        p.append(L.ball(0.32, (sx * 0.55, -0.25, 1.78), "wyvernScale", seg=10, rings=5))
        p.append(L.crystal(0.18, 0.44, (sx * 0.62, -0.22, 1.96), "roof", tilt=(0.2, -sx * 0.45), verts=6))

    # Pescoco em S e cabeca draconica esculpida para -Y
    p.append(_limb_seg((0, -0.58, 1.72), (0, -1.08, 2.20), 0.36, 0.28, "wyvernScale", verts=12))
    p.append(_limb_seg((0, -1.08, 2.20), (0, -1.38, 2.58), 0.28, 0.24, "roof", verts=12))
    # Cranio, focinho, mandibula, olhos amberBright e chifres curvos em hornIvory
    p.append(L.ball(0.36, (0, -1.58, 2.66), "wyvernScale", seg=10, rings=5, squash=(0.82, 1.08, 0.72)))
    p.append(_limb_seg((0, -1.68, 2.65), (0, -2.28, 2.60), 0.24, 0.12, "roof", verts=10))
    p.append(_limb_seg((0, -1.66, 2.50), (0, -2.18, 2.46), 0.18, 0.09, "amber", verts=8))
    for sx in (-1, 1):
        p.append(L.ball(0.08, (sx * 0.22, -1.80, 2.73), "amberBright", seg=6, rings=4))
        # Chifres curvos em 2 segmentos suaves
        h0 = (sx * 0.18, -1.42, 2.80)
        h1 = (sx * 0.34, -1.02, 3.12)
        h2 = (sx * 0.44, -0.58, 3.38)
        p.append(_limb_seg(h0, h1, 0.11, 0.07, "hornIvory", verts=8))
        p.append(_limb_seg(h1, h2, 0.07, 0.02, "hornIvory", verts=8))

    # Pernas traseiras recolhidas com garras
    for sx in (-1, 1):
        p.append(_limb_seg((sx * 0.42, 0.48, 1.38), (sx * 0.52, 0.22, 0.72), 0.26, 0.16, "wyvernScale", verts=10))
        p.append(_limb_seg((sx * 0.52, 0.22, 0.72), (sx * 0.48, 0.58, 0.16), 0.16, 0.12, "roof", verts=10))
        p.append(_limb_seg((sx * 0.48, 0.56, 0.14), (sx * 0.48, 0.14, 0.08), 0.14, 0.08, "ironDark", verts=8))

    # Cauda ondulante com espinhos para +Y
    tail_pts = ((0, 0.75, 1.52), (0, 1.48, 1.48), (0, 2.22, 1.66), (0, 2.95, 1.82), (0, 3.65, 1.68))
    rads = (0.36, 0.26, 0.18, 0.11, 0.05)
    for i in range(len(tail_pts) - 1):
        p.append(_limb_seg(tail_pts[i], tail_pts[i + 1], rads[i], rads[i + 1], "wyvernScale", verts=10))
        mid = (
            (tail_pts[i][0] + tail_pts[i + 1][0]) * 0.5,
            (tail_pts[i][1] + tail_pts[i + 1][1]) * 0.5,
            (tail_pts[i][2] + tail_pts[i + 1][2]) * 0.5 + 0.12,
        )
        p.append(L.crystal(0.08, 0.34 - i * 0.05, mid, "hornIvory", tilt=(-0.55, 0), verts=6))
    p.append(L.crystal(0.18, 0.54, tail_pts[-1], "amber", tilt=(-1.45, 0), verts=8))

    return p


def wyvern_wing(side):
    """Asa de dragao a partir do ombro (0, 0, 0) para side*X (~4.8 studs), dedos curvos + membrana."""
    # side = -1 para esquerda (-X), +1 para direita (+X)
    s = side
    p = []

    # Junta de ombro em (0, 0, 0.18) -> base em Z=0, origem de pivot (0, 0, 0) preservada
    sh = (0.0, 0.0, 0.18)
    elbow = (s * 1.45, -0.34, 0.68)
    wrist = (s * 2.55, -0.52, 1.12)
    f1_mid = (s * 3.72, -0.38, 1.34)
    f1 = (s * 4.78, -0.18, 1.48)
    f2_mid = (s * 3.42, 0.22, 1.14)
    f2 = (s * 4.15, 0.88, 1.10)
    f3_mid = (s * 2.68, 0.54, 0.92)
    f3 = (s * 2.75, 1.52, 0.68)
    f4 = (s * 1.58, 1.28, 0.44)
    flank = (s * 0.28, 1.05, 0.16)

    p.append(L.ball(0.18, sh, "wyvernScale", seg=18, rings=12))
    p.append(L.ball(0.14, elbow, "wyvernScale", seg=14, rings=8))
    p.append(L.ball(0.13, wrist, "roof", seg=14, rings=8))
    p.append(_limb_seg(sh, elbow, 0.15, 0.12, "wyvernScale", verts=14))
    p.append(_limb_seg(elbow, wrist, 0.13, 0.11, "roof", verts=14))
    p.append(L.crystal(0.09, 0.44, (wrist[0], wrist[1] - 0.06, wrist[2] + 0.05), "hornIvory", tilt=(0.75, 0), verts=8))

    # Dedos ossudos articulados em 2 falanges suaves (verts=14)
    for m_pt, tip, r0, r_mid in (
        (f1_mid, f1, 0.095, 0.062),
        (f2_mid, f2, 0.082, 0.054),
        (f3_mid, f3, 0.072, 0.048),
    ):
        p.append(_limb_seg(wrist, m_pt, r0, r_mid, "wyvernScale", verts=14))
        p.append(_limb_seg(m_pt, tip, r_mid, 0.026, "roof", verts=14))
    p.append(_limb_seg(elbow, f4, 0.068, 0.025, "wyvernScale", verts=12))

    # Membrana recortada em arcos suaves
    bay1a = (s * 4.42, 0.12, 1.24)
    bay12 = (s * 3.85, 0.34, 1.02)
    bay1b = (s * 4.02, 0.62, 1.06)
    bay2a = (s * 3.58, 0.90, 0.88)
    bay23 = (s * 3.05, 0.92, 0.72)
    bay3a = (s * 2.22, 1.22, 0.52)
    bay3f = (s * 0.95, 1.08, 0.28)
    ring = [sh, elbow, wrist, f1_mid, f1, bay1a, bay12, bay1b, f2, bay2a, bay23, f3, bay3a, f4, bay3f, flank]
    hub = (s * 2.05, 0.35, 0.74)
    p.append(_wing_membrane(ring, hub, 0.055, "wyvernWing"))

    return p


# ---------------------------------------------------------------- 2. Bird (Falcao / Corvo de Vigia)
def bird_body():
    """Corpo aerodinamico de falcao/corvo de vigia: bico ambar (-Y), cauda em leque (+Y)."""
    p = []

    p.append(L.ball(0.46, (0, 0.0, 0.96), "ironDark", seg=18, rings=12, squash=(0.82, 1.42, 0.88)))
    p.append(L.ball(0.38, (0, -0.18, 0.88), "stoneDark", seg=14, rings=8, squash=(0.76, 1.10, 0.72)))
    for sx in (-1, 1):
        p.append(L.ball(0.16, (sx * 0.32, -0.08, 1.08), "iron", seg=10, rings=6))

    # Cabeca e bico ganchoso curvo em -Y
    p.append(L.ball(0.28, (0, -0.58, 1.24), "ironDark", seg=14, rings=8, squash=(0.90, 1.08, 0.92)))
    p.append(_limb_seg((0, -0.76, 1.25), (0, -1.04, 1.20), 0.11, 0.065, "amber", verts=12))
    p.append(_limb_seg((0, -1.02, 1.20), (0, -1.18, 1.06), 0.065, 0.018, "amberBright", verts=10))
    for sx in (-1, 1):
        p.append(L.ball(0.055, (sx * 0.16, -0.70, 1.29), "amberBright", seg=6, rings=4))

    # Penacho nucal
    for k, dz in enumerate((1.38, 1.30)):
        p.append(_limb_seg((0, -0.46, dz), (0, -0.16, dz + 0.08 - k * 0.03), 0.06, 0.02, "ironDark", verts=8))

    # Garras recolhidas
    for sx in (-1, 1):
        p.append(_limb_seg((sx * 0.16, 0.05, 0.62), (sx * 0.18, -0.05, 0.16), 0.075, 0.045, "amber", verts=10))
        p.append(_limb_seg((sx * 0.18, 0.06, 0.10), (sx * 0.18, -0.20, 0.06), 0.055, 0.03, "ironDark", verts=8))

    # Leque de 7 penas na cauda (+Y) com hastes cilindricas suaves
    for k in range(-3, 4):
        ang = k * 0.15
        tip = (0.52 * math.sin(ang), 1.48 * math.cos(ang), 0.92 + abs(k) * 0.02)
        col = "stoneDark" if k % 2 == 0 else "ironDark"
        p.append(_feather((0, 0.45, 0.92), tip, 0.18, 0.26, 0.045, col))
        p.append(_limb_seg((0, 0.45, 0.94), tip, 0.035, 0.015, col, verts=8))

    return p


def bird_wing(side):
    """Asa emplumada pontiaguda a partir do ombro (0, 0, 0) para side*X (~3.2 studs)."""
    s = side
    p = []

    sh = (0.0, 0.0, 0.14)
    wrist = (s * 1.45, -0.22, 0.62)
    tip = (s * 3.15, 0.24, 0.98)

    p.append(L.ball(0.14, sh, "ironDark", seg=18, rings=12))
    p.append(L.ball(0.11, wrist, "iron", seg=16, rings=10))
    p.append(_limb_seg(sh, wrist, 0.13, 0.10, "ironDark", verts=14))
    p.append(_limb_seg(wrist, tip, 0.10, 0.03, "stoneDark", verts=14))

    # Cobertura superior + 8 penas primarias/secundarias escalonadas com hastes cilindricas suaves
    p.append(
        _wing_membrane(
            [sh, wrist, tip, (s * 2.45, 0.56, 0.72), (s * 1.55, 0.66, 0.48), (s * 0.35, 0.58, 0.18)],
            (s * 1.35, 0.16, 0.48),
            0.05,
            "iron",
        )
    )
    feathers = (
        ((s * 2.25, -0.04, 0.76), (s * 3.22, 0.38, 0.96), 0.20, 0.09, "ironDark"),
        ((s * 1.96, 0.02, 0.68), (s * 2.98, 0.58, 0.86), 0.22, 0.10, "stoneDark"),
        ((s * 1.68, 0.08, 0.60), (s * 2.68, 0.78, 0.76), 0.23, 0.11, "ironDark"),
        ((s * 1.40, 0.14, 0.52), (s * 2.34, 0.94, 0.64), 0.24, 0.13, "stone"),
        ((s * 1.12, 0.18, 0.44), (s * 1.96, 1.04, 0.52), 0.25, 0.14, "stoneDark"),
        ((s * 0.84, 0.22, 0.36), (s * 1.56, 1.08, 0.42), 0.25, 0.16, "ironDark"),
        ((s * 0.58, 0.26, 0.28), (s * 1.16, 1.06, 0.32), 0.26, 0.17, "stone"),
        ((s * 0.34, 0.28, 0.22), (s * 0.76, 0.98, 0.24), 0.26, 0.18, "ironDark"),
    )
    for p0, p1, w0, w1, col in feathers:
        p.append(_feather(p0, p1, w0, w1, 0.04, col))
        p.append(_limb_seg(p0, p1, 0.042, 0.016, col, verts=12))

    return p


# ---------------------------------------------------------------- 3. Stag (Cervo Real)
def stag():
    """Cervo nobre da floresta: corpo furBrown/furTan, pernas esguias e galhada ramificada."""
    p = []

    # Torso, peito claro e cauda branca suaves (seg=18, rings=12)
    p.append(L.ball(0.62, (0, 0.05, 1.52), "furBrown", seg=18, rings=12, squash=(0.76, 1.48, 0.86)))
    p.append(L.ball(0.50, (0, -0.52, 1.54), "furTan", seg=12, rings=7, squash=(0.74, 0.92, 0.88)))
    p.append(L.crystal(0.14, 0.36, (0, 0.92, 1.62), "white", tilt=(-0.95, 0), verts=8))

    # 4 pernas esguias + cascos
    legs = (
        (-0.24, -0.54, 1.32, -0.58),
        (0.24, -0.54, 1.32, -0.58),
        (-0.24, 0.62, 1.34, 0.66),
        (0.24, 0.62, 1.34, 0.66),
    )
    for lx, ly, lz, fy in legs:
        knee_y = (ly + fy) * 0.5 - 0.04
        p.append(_limb_seg((lx, ly, lz), (lx, knee_y, 0.68), 0.14, 0.085, "furBrown", verts=10))
        p.append(_limb_seg((lx, knee_y, 0.68), (lx, fy, 0.12), 0.08, 0.06, "furTan", verts=10))
        p.append(L.cyl(0.085, 0.12, (lx, fy, 0.0), "ironDark", verts=8))

    # Pescoco erguido + cabeca esculpida (-Y) + orelhas
    p.append(_limb_seg((0, -0.64, 1.68), (0, -1.04, 2.48), 0.28, 0.19, "furBrown", verts=12))
    p.append(L.ball(0.24, (0, -1.16, 2.60), "furBrown", seg=10, rings=6, squash=(0.82, 1.15, 0.78)))
    p.append(_limb_seg((0, -1.24, 2.58), (0, -1.66, 2.50), 0.16, 0.09, "furTan", verts=10))
    p.append(L.ball(0.075, (0, -1.70, 2.52), "ink", seg=6, rings=4))
    for sx in (-1, 1):
        p.append(L.ball(0.05, (sx * 0.17, -1.28, 2.65), "ink", seg=6, rings=4))
        p.append(L.crystal(0.08, 0.34, (sx * 0.22, -1.02, 2.72), "furTan", tilt=(-0.45, -sx * 0.85), verts=6))

        # Galhada real ramificada em arcos suaves (hornIvory / amber)
        b0 = (sx * 0.14, -1.06, 2.76)
        b1 = (sx * 0.38, -0.88, 3.22)
        b2 = (sx * 0.62, -0.64, 3.68)
        b3 = (sx * 0.72, -0.38, 4.10)
        p.append(_limb_seg(b0, b1, 0.062, 0.050, "hornIvory", verts=8))
        p.append(_limb_seg(b1, b2, 0.050, 0.038, "hornIvory", verts=8))
        p.append(_limb_seg(b2, b3, 0.038, 0.018, "amber", verts=8))
        p.append(_limb_seg(b0, (sx * 0.28, -1.42, 3.16), 0.042, 0.016, "amber", verts=8))
        p.append(_limb_seg(b1, (sx * 0.54, -1.12, 3.66), 0.038, 0.015, "hornIvory", verts=8))
        p.append(_limb_seg(b2, (sx * 0.52, -0.28, 4.02), 0.032, 0.014, "amber", verts=8))

    return p


# ---------------------------------------------------------------- 4. Pack Ox (Boi de Carga)
def pack_ox():
    """Boi de carga robusto do Bastiao: canga de madeira e alforges laterais transbordando cristais ambar."""
    p = []

    # Tronco pesado, cupim nos ombros e focinho largo (-Y)
    p.append(L.ball(0.82, (0, 0.15, 1.38), "furBrown", seg=18, rings=12, squash=(0.94, 1.46, 0.92)))
    p.append(L.ball(0.76, (0, -0.55, 1.48), "woodDark", seg=14, rings=8, squash=(0.98, 0.96, 1.02)))
    p.append(L.ball(0.36, (0, -1.18, 1.42), "furBrown", seg=10, rings=6, squash=(0.92, 0.96, 0.86)))
    p.append(_limb_seg((0, -1.24, 1.38), (0, -1.66, 1.26), 0.28, 0.20, "furTan", verts=10))
    p.append(L.torus(0.11, 0.03, (0, -1.72, 1.14), "gold", major_seg=10, minor_seg=4, rot=(0.35, 0, 0)))
    for sx in (-1, 1):
        p.append(L.ball(0.06, (sx * 0.27, -1.30, 1.50), "ink", seg=6, rings=4))
        # Chifres curvos em 3 segmentos suaves (hornIvory)
        c0 = (sx * 0.24, -1.16, 1.64)
        c1 = (sx * 0.56, -1.20, 1.76)
        c2 = (sx * 0.74, -1.38, 1.98)
        c3 = (sx * 0.68, -1.56, 2.18)
        p.append(_limb_seg(c0, c1, 0.105, 0.082, "hornIvory", verts=10))
        p.append(_limb_seg(c1, c2, 0.082, 0.052, "hornIvory", verts=8))
        p.append(_limb_seg(c2, c3, 0.052, 0.020, "amber", verts=8))

    # 4 pernas robustas + cascos
    for sx in (-1, 1):
        for sy, fy in ((-0.62, -0.66), (0.68, 0.72)):
            p.append(_limb_seg((sx * 0.44, sy, 1.05), (sx * 0.44, fy, 0.16), 0.19, 0.14, "woodDark", verts=10))
            p.append(L.cyl(0.16, 0.16, (sx * 0.44, fy, 0.0), "ironDark", verts=8))

    # Cauda
    p.append(_limb_seg((0, 1.18, 1.48), (0, 1.42, 0.78), 0.075, 0.04, "woodDark", verts=8))

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
        for dy, col, h, tilt in (
            (-0.28, "amber", 0.56, (0.2, -sx * 0.25)),
            (0.04, "amberBright", 0.68, (0.0, -sx * 0.18)),
            (0.32, "amber", 0.50, (-0.25, -sx * 0.30)),
        ):
            p.append(L.crystal(0.14, h, (bx + sx * 0.04, 0.18 + dy, 1.98), col, tilt=tilt, verts=7))

    return p


# ---------------------------------------------------------------- 5. Ram (Carneiro da Montanha)
def ram():
    """Carneiro de montanha: corpo lanoso stoneLight/furTan, cascos escuros e chifres espiralados."""
    p = []

    # Corpo lanoso + juba peitoral suaves (seg=18, rings=12)
    p.append(L.ball(0.62, (0, 0.10, 1.12), "stoneLight", seg=18, rings=12, squash=(0.88, 1.34, 0.92)))
    p.append(L.ball(0.54, (0, -0.45, 1.18), "furTan", seg=14, rings=8, squash=(0.86, 0.96, 0.96)))
    p.append(L.ball(0.22, (0, 0.88, 1.24), "stoneLight", seg=10, rings=6))

    # 4 pernas firmes + cascos
    for sx in (-1, 1):
        for sy, fy in ((-0.46, -0.50), (0.56, 0.60)):
            p.append(_limb_seg((sx * 0.32, sy, 0.88), (sx * 0.32, fy, 0.14), 0.14, 0.10, "furBrown", verts=10))
            p.append(L.cyl(0.12, 0.14, (sx * 0.32, fy, 0.0), "ironDark", verts=8))

    # Cabeca forte esculpida (-Y) + chifres espiralados suaves em hornIvory
    p.append(L.ball(0.28, (0, -0.92, 1.44), "furBrown", seg=10, rings=6, squash=(0.86, 1.12, 0.80)))
    p.append(_limb_seg((0, -1.00, 1.40), (0, -1.36, 1.32), 0.19, 0.12, "furTan", verts=10))
    for sx in (-1, 1):
        p.append(L.ball(0.055, (sx * 0.21, -1.06, 1.50), "amberBright", seg=6, rings=4))
        # Espiral suave de 6 segmentos ao redor da lateral do cranio
        pts = (
            (sx * 0.16, -0.82, 1.62),
            (sx * 0.38, -0.62, 1.74),
            (sx * 0.54, -0.54, 1.50),
            (sx * 0.54, -0.78, 1.24),
            (sx * 0.46, -1.04, 1.28),
            (sx * 0.50, -1.16, 1.44),
            (sx * 0.58, -1.10, 1.56),
        )
        rads = (0.145, 0.125, 0.105, 0.086, 0.066, 0.044, 0.022)
        for i in range(len(pts) - 1):
            p.append(_limb_seg(pts[i], pts[i + 1], rads[i], rads[i + 1], "hornIvory", verts=10))

    return p


SPECS = [
    {
        "id": "fauna.wyvern_body.01",
        "name": "FAUNA_wyvern_body",
        "glb": "wyvern_body.glb",
        "tipo": "prop_estatico",
        "limite": LIMITE,
        "center_xy": True,
        "suavizacao_normais": NORMALS_FAUNA,
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
        "suavizacao_normais": NORMALS_FAUNA,
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
        "suavizacao_normais": NORMALS_FAUNA,
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
        "suavizacao_normais": NORMALS_FAUNA,
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
        "suavizacao_normais": NORMALS_FAUNA,
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
        "suavizacao_normais": NORMALS_FAUNA,
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
        "suavizacao_normais": NORMALS_FAUNA,
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
        "suavizacao_normais": NORMALS_FAUNA,
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
        "suavizacao_normais": NORMALS_FAUNA,
        "tags": ["muralha", "fauna", "ram"],
        "seed": L.SEED_BASE + 8501,
        "build": ram,
    },
]

L.run_group("fauna", SPECS, "fauna articulada e silvestre do Bastiao (art/scripts/make_fauna.py)")
