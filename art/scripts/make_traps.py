"""Gera as 5 armadilhas (TRAP_) em L1..L5 com escultura AA densa por nivel (Forge3D 0.9.0 spec@6).

Fonte das formas: docs/direcao-visual-e-silhuetas.md §2.1 (regra por tipo), TrapKit.luau
(cotas), VisualTheme.TRAPS (altura por tipo, cor). Pegada <= 5.1 x 5.1 studs, pivot=base (Z=0).
Patente: mastro + 1/2/3 chevrons (ou chevron fusionado L4/L5) no canto frontal-esquerdo; no piche
(~1.3 stud de altura) os chevrons vao numa placa frontal para preservar a classe de altura baixa.

Orcamento AA: 4.500..5.500 tris por modelo (LIMITE = 5600), estritamente monotono L1 < L2 < L3 < L4 < L5,
qualidade="hero", hero_pbr=False (preserva GPU Instancing no MASTER_ATLAS), quantidade_cena=1.

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
from mathutils import Euler, Vector

sys.dont_write_bytecode = True  # sem __pycache__ em art/scripts
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lowpoly_lib as L  # noqa: E402

LIMITE = 5600  # teto Forge3D 0.9.0 hero; alvo esculpido 4500..5500 tris por armadilha
BASE_TOP = 0.32
LEVELS = (1, 2, 3, 4, 5)


# ---------------------------------------------------------------- primitivas AA manifold
def _new_bmesh_obj(bm: bmesh.types.BMesh, name: str, center, color: str, rot=(0.0, 0.0, 0.0), bevel: float = 0.0):
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    obj.location = center
    obj.rotation_euler = rot
    bpy.context.collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    return L._finish(obj, color, bevel=bevel)


def _axis_rot(axis: str = "z", tilt: float = 0.0, rot_z: float = 0.0):
    if axis == "x":
        return (rot_z, math.pi / 2.0, 0.0)
    if axis == "y":
        return (math.pi / 2.0 - tilt, 0.0, rot_z)
    return (tilt, 0.0, rot_z)


def _taper_box(w0, d0, w1, d1, h, base_center, color, y_shift_top=0.0, rot_z=0.0, bevel=0.0):
    """Prisma retangular afunilado com base em Z=base_center[2] e topo em +h."""
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
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in pts]
    for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        bm.faces.new([vs[i] for i in f])
    return _new_bmesh_obj(bm, "taper_box", base_center, color, rot=(0.0, 0.0, rot_z), bevel=bevel)


def _hollow_cyl(r_out, r_in, h, center, color, verts=16, axis="z", tilt=0.0, rot_z=0.0, r_out2=None, r_in2=None):
    """Tubo/anel oco 100% quad-manifold (8*verts tris): aros, canos raiados, trilhos, cintas."""
    ro2 = r_out if r_out2 is None else r_out2
    ri2 = r_in if r_in2 is None else r_in2
    hz = h * 0.5
    bm = bmesh.new()
    rings = []
    for rad, zc in ((r_in, -hz), (r_out, -hz), (ro2, hz), (ri2, hz)):
        ring = [
            bm.verts.new((rad * math.cos(2.0 * math.pi * k / verts), rad * math.sin(2.0 * math.pi * k / verts), zc))
            for k in range(verts)
        ]
        rings.append(ring)
    for r_idx in range(4):
        r_a = rings[r_idx]
        r_b = rings[(r_idx + 1) % 4]
        for k in range(verts):
            kn = (k + 1) % verts
            bm.faces.new((r_a[k], r_b[k], r_b[kn], r_a[kn]))
    return _new_bmesh_obj(bm, "hollow_cyl", center, color, rot=_axis_rot(axis, tilt, rot_z))


def _lathe(profile_rz, center, color, segs=18, axis="z", tilt=0.0, rot_z=0.0):
    """Revolucao fechada 2-manifold com tampas em leque triangular (zero N-gons degenerados)."""
    bm = bmesh.new()
    rings = []
    for r, zc in profile_rz:
        rad = max(0.0, float(r))
        if rad < 1e-4:
            rings.append([bm.verts.new((0.0, 0.0, float(zc)))])
        else:
            rings.append(
                [
                    bm.verts.new(
                        (rad * math.cos(2.0 * math.pi * k / segs), rad * math.sin(2.0 * math.pi * k / segs), float(zc))
                    )
                    for k in range(segs)
                ]
            )
    if len(rings[0]) > 1:
        v_bot = bm.verts.new((0.0, 0.0, float(profile_rz[0][1])))
        r0 = rings[0]
        for k in range(segs):
            bm.faces.new((v_bot, r0[(k + 1) % segs], r0[k]))
    for idx in range(len(rings) - 1):
        ra, rb = rings[idx], rings[idx + 1]
        if len(ra) == 1 and len(rb) > 1:
            for k in range(segs):
                bm.faces.new((ra[0], rb[(k + 1) % segs], rb[k]))
        elif len(ra) > 1 and len(rb) == 1:
            for k in range(segs):
                bm.faces.new((ra[k], ra[(k + 1) % segs], rb[0]))
        elif len(ra) > 1 and len(rb) > 1:
            for k in range(segs):
                kn = (k + 1) % segs
                bm.faces.new((ra[k], ra[kn], rb[kn], rb[k]))
    if len(rings[-1]) > 1:
        v_top = bm.verts.new((0.0, 0.0, float(profile_rz[-1][1])))
        rl = rings[-1]
        for k in range(segs):
            bm.faces.new((rl[k], rl[(k + 1) % segs], v_top))
    return _new_bmesh_obj(bm, "lathe_aa", center, color, rot=_axis_rot(axis, tilt, rot_z))


def _gear_hd(r_pitch, thick, center, color, teeth=6, axis="x", hub_color=None, bore_ratio=0.44, rot_z=0.0):
    """Engrenagem involuta esculpida em malha unica quad-manifold (32*teeth tris) + cubo opcional."""
    m = teeth * 4
    r_root = r_pitch * 0.86
    r_tip = r_pitch * 1.14
    r_bore = max(0.04, r_pitch * bore_ratio)
    hz = thick * 0.5
    bm = bmesh.new()
    radii = []
    angles = []
    for t in range(teeth):
        base_a = 2.0 * math.pi * t / teeth
        step = 2.0 * math.pi / teeth
        for frac, rad in ((0.00, r_root), (0.20, r_root), (0.32, r_tip), (0.68, r_tip)):
            angles.append(base_a + frac * step)
            radii.append(rad)
    rings = []
    for use_outer, zc in ((False, -hz), (True, -hz), (True, hz), (False, hz)):
        ring = []
        for k in range(m):
            rad = radii[k] if use_outer else r_bore
            ang = angles[k]
            ring.append(bm.verts.new((rad * math.cos(ang), rad * math.sin(ang), zc)))
        rings.append(ring)
    for r_idx in range(4):
        ra = rings[r_idx]
        rb = rings[(r_idx + 1) % 4]
        for k in range(m):
            kn = (k + 1) % m
            bm.faces.new((ra[k], rb[k], rb[kn], ra[kn]))
    parts = [_new_bmesh_obj(bm, "gear_hd", center, color, rot=_axis_rot(axis, 0.0, rot_z))]
    if hub_color:
        if axis == "z":
            parts.append(L.cyl(r_bore * 1.06, thick * 1.36, (center[0], center[1], center[2] - thick * 0.68), hub_color, verts=10))
        else:
            parts.append(L.cyl_axis(r_bore * 1.06, thick * 1.36, center, hub_color, axis=axis, verts=10))
    return parts


def _helical_coil(
    r_helix,
    r_wire,
    pitch,
    turns,
    center,
    color,
    axis="z",
    segs_per_turn=9,
    wire_segs=5,
    tilt=0.0,
    rot_z=0.0,
):
    """Espiral 3D fechada 2-manifold: cordas de torcao, serpentinas condensadoras e roscas."""
    steps = max(6, int(round(turns * segs_per_turn)))
    total_h = pitch * turns
    z_start = -total_h * 0.5
    bm = bmesh.new()
    rings = []
    centers_3d = []
    for i in range(steps + 1):
        u = i / steps
        ang = u * turns * 2.0 * math.pi
        zc = z_start + u * total_h
        pc = Vector((r_helix * math.cos(ang), r_helix * math.sin(ang), zc))
        centers_3d.append(pc)
        tang = Vector((-r_helix * 2.0 * math.pi * turns * math.sin(ang), r_helix * 2.0 * math.pi * turns * math.cos(ang), total_h)).normalized()
        n_vec = Vector((math.cos(ang), math.sin(ang), 0.0))
        b_vec = tang.cross(n_vec).normalized()
        ring = []
        for k in range(wire_segs):
            wa = 2.0 * math.pi * k / wire_segs
            pt = pc + n_vec * (r_wire * math.cos(wa)) + b_vec * (r_wire * math.sin(wa))
            ring.append(bm.verts.new((pt.x, pt.y, pt.z)))
        rings.append(ring)
    v_start = bm.verts.new(tuple(centers_3d[0]))
    for k in range(wire_segs):
        bm.faces.new((v_start, rings[0][(k + 1) % wire_segs], rings[0][k]))
    for i in range(steps):
        ra, rb = rings[i], rings[i + 1]
        for k in range(wire_segs):
            kn = (k + 1) % wire_segs
            bm.faces.new((ra[k], ra[kn], rb[kn], rb[k]))
    v_end = bm.verts.new(tuple(centers_3d[-1]))
    for k in range(wire_segs):
        bm.faces.new((rings[-1][k], rings[-1][(k + 1) % wire_segs], v_end))
    return _new_bmesh_obj(bm, "helical_coil", center, color, rot=_axis_rot(axis, tilt, rot_z))


def _curved_tube(pts, radii, color, wire_segs=6):
    """Tubo curvo fechado por transporte paralelo ao longo de `pts` (laminas de arco, tubos, alcas)."""
    vecs = [Vector(p) for p in pts]
    n_pts = len(vecs)
    tangs = []
    for i in range(n_pts):
        if i == 0:
            t = vecs[1] - vecs[0]
        elif i == n_pts - 1:
            t = vecs[-1] - vecs[-2]
        else:
            t = vecs[i + 1] - vecs[i - 1]
        tangs.append(t.normalized())
    up = Vector((0.0, 0.0, 1.0)) if abs(tangs[0].z) < 0.85 else Vector((1.0, 0.0, 0.0))
    n_vec = tangs[0].cross(up).normalized()
    bm = bmesh.new()
    rings = []
    mid = sum(vecs, Vector((0.0, 0.0, 0.0))) / n_pts
    for i in range(n_pts):
        if i > 0:
            rot_q = tangs[i - 1].rotation_difference(tangs[i])
            n_vec = (rot_q @ n_vec).normalized()
        b_vec = tangs[i].cross(n_vec).normalized()
        n_vec = b_vec.cross(tangs[i]).normalized()
        rad = max(0.016, float(radii[i] if isinstance(radii, (list, tuple)) else radii))
        ring = []
        for k in range(wire_segs):
            wa = 2.0 * math.pi * k / wire_segs
            pt = (vecs[i] - mid) + n_vec * (rad * math.cos(wa)) + b_vec * (rad * math.sin(wa))
            ring.append(bm.verts.new((pt.x, pt.y, pt.z)))
        rings.append(ring)
    v0 = bm.verts.new(tuple(vecs[0] - mid))
    for k in range(wire_segs):
        bm.faces.new((v0, rings[0][(k + 1) % wire_segs], rings[0][k]))
    for i in range(n_pts - 1):
        ra, rb = rings[i], rings[i + 1]
        for k in range(wire_segs):
            kn = (k + 1) % wire_segs
            bm.faces.new((ra[k], ra[kn], rb[kn], rb[k]))
    v1 = bm.verts.new(tuple(vecs[-1] - mid))
    for k in range(wire_segs):
        bm.faces.new((rings[-1][k], rings[-1][(k + 1) % wire_segs], v1))
    return _new_bmesh_obj(bm, "curved_tube", tuple(mid), color)


def _faceted_crystal(r_base, h, base_pos, color, sides=8, tilt=(0.0, 0.0), spin=0.0, waist=0.66):
    """Cristal criogenico multifacetado (base chanfrada, prisma, cintura lapidada e coroa aguda)."""
    profile = (
        (r_base * 0.78, 0.0),
        (r_base * 1.04, h * 0.12),
        (r_base * 0.92, h * 0.44),
        (r_base * waist, h * 0.76),
        (r_base * 0.34, h * 0.91),
        (0.0, h),
    )
    bm = bmesh.new()
    rings = []
    for r, zc in profile:
        if r < 1e-4:
            rings.append([bm.verts.new((0.0, 0.0, zc))])
        else:
            rings.append(
                [
                    bm.verts.new((r * math.cos(2.0 * math.pi * k / sides), r * math.sin(2.0 * math.pi * k / sides), zc))
                    for k in range(sides)
                ]
            )
    v_bot = bm.verts.new((0.0, 0.0, 0.0))
    for k in range(sides):
        bm.faces.new((v_bot, rings[0][(k + 1) % sides], rings[0][k]))
    for idx in range(len(rings) - 1):
        ra, rb = rings[idx], rings[idx + 1]
        if len(rb) == 1:
            for k in range(sides):
                bm.faces.new((ra[k], ra[(k + 1) % sides], rb[0]))
        else:
            for k in range(sides):
                kn = (k + 1) % sides
                bm.faces.new((ra[k], ra[kn], rb[kn], rb[k]))
    eul = Euler((tilt[0], tilt[1], spin), "XYZ")
    return _new_bmesh_obj(bm, "faceted_crystal", base_pos, color, rot=tuple(eul))


def _rivet(center, color="ironDark", r=0.052, h=0.042, verts=6):
    return L.cyl(r, h, (center[0], center[1], center[2] - h * 0.5), color, verts=verts, r2=r * 0.62)


def _spoked_wheel_hd(r, thick, center, tire_color, felly_color, hub_color, spokes=8, spoke_color="woodDark", axis="x", verts=12):
    """Roda de artilharia/guincho AA: aro metalico oco, pina de madeira, cubo torneado e raios."""
    cx, cy, cz = center
    parts = [
        _hollow_cyl(r, r * 0.87, thick * 1.04, center, tire_color, verts=verts, axis=axis),
        _hollow_cyl(r * 0.87, r * 0.72, thick * 0.88, center, felly_color, verts=verts, axis=axis),
        L.cyl_axis(r * 0.28, thick * 1.32, center, hub_color, axis=axis, verts=10),
        L.cyl_axis(r * 0.15, thick * 1.56, center, tire_color, axis=axis, verts=8),
    ]
    n_pairs = max(3, spokes // 2)
    spoke_len = r * 1.50
    for k in range(n_pairs):
        ang = math.pi * k / n_pairs
        rot = (ang, 0.0, 0.0) if axis == "x" else (0.0, 0.0, ang)
        sz = (thick * 0.42, 0.085, spoke_len) if axis == "x" else (0.085, spoke_len, thick * 0.42)
        parts.append(L.box(sz, (cx, cy, cz), spoke_color, rot=rot))
    return parts


# ---------------------------------------------------------------- plinto compartilhado (~1180..1490 tris)
def base(lvl: int):
    """Plinto escalonado de cantaria chanfrada, cantoneiras de ferro rebitadas e canais runicos."""
    upper_stone = "stoneDark" if lvl < 3 else "stoneLight"
    bracket_col = "ironDark" if lvl == 1 else ("iron" if lvl == 2 else ("brass" if lvl == 3 else "gold"))
    riv_col = "iron" if lvl < 3 else ("brass" if lvl == 3 else "goldBright")
    rune_col = "amber" if lvl == 1 else ("amberBright" if lvl <= 3 else "neonAmber")

    p = [
        L.box((4.54, 4.54, 0.16), (0.0, 0.0, 0.08), "stone", bevel=0.032),
        L.box((4.18, 4.18, 0.15), (0.0, 0.0, 0.225), upper_stone, bevel=0.028),
        # Canal runico rebaixado: moldura escura + circuito runico incrustado no degrau superior
        _hollow_cyl(1.78, 1.58, 0.05, (0.0, 0.0, BASE_TOP - 0.01), "ink", verts=12),
        _hollow_cyl(1.73, 1.63, 0.055, (0.0, 0.0, BASE_TOP - 0.004), rune_col, verts=12),
    ]

    # Silhares chanfrados de cantaria ao longo das 4 faces do plinto (8 blocos chanfrados = 352 tris)
    block_offsets = (-0.76, 0.76)
    for sy in (-1, 1):
        for bx in block_offsets:
            p.append(L.box((1.06, 0.22, 0.15), (bx, sy * 2.18, 0.115), "stoneLight" if (bx > 0) ^ (sy > 0) else "stone", bevel=0.022))
    for sx in (-1, 1):
        for by in block_offsets:
            p.append(L.box((0.22, 1.06, 0.15), (sx * 2.18, by, 0.115), "stone" if (by > 0) ^ (sx > 0) else "stoneLight", bevel=0.022))

    # Canais runicos cardeais rebaixados nas 4 bordas superiores
    for sy in (-1, 1):
        p.append(L.box((2.46, 0.15, 0.06), (0.0, sy * 1.94, BASE_TOP - 0.01), "ink"))
        p.append(L.box((2.34, 0.08, 0.065), (0.0, sy * 1.94, BASE_TOP - 0.004), rune_col))
    for sx in (-1, 1):
        p.append(L.box((0.15, 2.46, 0.06), (sx * 1.94, 0.0, BASE_TOP - 0.01), "ink"))
        p.append(L.box((0.08, 2.34, 0.065), (sx * 1.94, 0.0, BASE_TOP - 0.004), rune_col))

    # 4 cantoneiras de ferro/bronze/ouro com abas laterais e rebites abaulados
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = sx * 1.92, sy * 1.92
            p.append(_taper_box(0.60, 0.60, 0.50, 0.50, 0.35, (cx, cy, 0.0), bracket_col, bevel=0.022))
            p.append(L.box((0.54, 0.14, 0.22), (cx - sx * 0.20, cy + sy * 0.26, 0.14), bracket_col))
            p.append(L.box((0.14, 0.54, 0.22), (cx + sx * 0.26, cy - sy * 0.20, 0.14), bracket_col))
            p.append(_rivet((cx - sx * 0.12, cy - sy * 0.12, 0.37), riv_col))
            p.append(_rivet((cx + sx * 0.12, cy - sy * 0.12, 0.37), riv_col))

    # Progressao monotona do plinto L2..L5
    if lvl >= 2:
        for sy in (-1, 1):
            p.append(L.box((2.76, 0.13, 0.13), (0.0, sy * 2.24, 0.16), "iron" if lvl == 2 else "brass", bevel=0.02))
    if lvl >= 3:
        for sx in (-1, 1):
            p.append(L.box((0.13, 2.76, 0.13), (sx * 2.24, 0.0, 0.16), "brass" if lvl == 3 else "gold", bevel=0.02))
    if lvl >= 4:
        for k in range(4):
            ang = math.pi * 0.25 + k * math.pi * 0.5
            p.append(L.ico(0.085, (1.68 * math.cos(ang), 1.68 * math.sin(ang), BASE_TOP + 0.04), "goldBright", subdiv=0))
    if lvl >= 5:
        for sx in (-1, 1):
            for sy in (-1, 1):
                p.append(L.spike(0.14, 0.26, (sx * 1.92, sy * 1.92, 0.35), "goldBright", verts=6))
    return p


# ---------------------------------------------------------------- arqueiro (~5.20..5.50 studs)
def archer(lvl: int):
    p = base(lvl)
    post_h = 3.30 if lvl < 3 else 2.74
    top = BASE_TOP + post_h
    pillar_col = "wood" if lvl < 4 else "woodDark"
    trim_col = "iron" if lvl < 3 else ("brass" if lvl == 3 else "gold")

    # 4 pilares afunilados com sapatas de ferro, colares intermediarios e maos-francesas
    for sx in (-1, 1):
        for sy in (-1, 1):
            px, py = sx * 1.04, sy * 1.04
            p.append(_taper_box(0.40, 0.40, 0.32, 0.32, post_h, (px, py, BASE_TOP), pillar_col, bevel=0.022))
            p.append(L.box((0.48, 0.48, 0.20), (px, py, BASE_TOP + 0.10), "ironDark", bevel=0.02))
            p.append(L.box((0.38, 0.38, 0.14), (px, py, BASE_TOP + post_h * 0.52), trim_col))
            p.append(L.box((0.16, 0.56, 0.18), (px, py * 1.18, top - 0.18), "woodDark", rot=(sy * 0.55, 0.0, 0.0)))
            p.append(L.box((0.56, 0.16, 0.18), (px * 1.18, py, top - 0.18), "woodDark", rot=(0.0, -sx * 0.55, 0.0)))

    # Contraventamento em X nas 3 faces abertas + chapas centrais rebitadas
    for sy in (-1.06, 1.06):
        for ang in (0.60, -0.60):
            p.append(L.box((2.30, 0.12, 0.17), (0.0, sy, BASE_TOP + post_h * 0.44), "woodDark", rot=(0.0, ang, 0.0)))
        p.append(L.box((0.28, 0.18, 0.28), (0.0, sy, BASE_TOP + post_h * 0.44), trim_col, bevel=0.02))
    for ang in (0.60, -0.60):
        p.append(L.box((0.12, 2.30, 0.17), (-1.06, 0.0, BASE_TOP + post_h * 0.44), "woodDark", rot=(ang, 0.0, 0.0)))

    # Roda raiada de armar + trem de engrenagens acoplado na lateral direita da torre
    winch_z = BASE_TOP + post_h * 0.48
    p.append(L.cyl_axis(0.11, 2.42, (0.0, 0.18, winch_z), "ironDark", axis="x", verts=8))
    p += _spoked_wheel_hd(0.62, 0.18, (1.32, 0.18, winch_z), "ironDark", "wood", trim_col, spokes=8, axis="x", verts=10)
    p += _gear_hd(0.35, 0.12, (1.14, -0.34, winch_z + 0.34), trim_col, teeth=5, axis="x", hub_color="brass")
    p += _gear_hd(0.24, 0.12, (1.14, 0.18, winch_z), "steel", teeth=6, axis="x", hub_color="ironDark")

    # Plataforma de tiro entabulada + parapeito ameado
    p.append(L.box((3.04, 3.04, 0.24), (0.0, 0.0, top + 0.12), "woodLight", bevel=0.03))
    deck = top + 0.24
    for px in (-1.12, -0.56, 0.0, 0.56, 1.12):
        p.append(L.box((0.48, 2.94, 0.06), (px, 0.0, deck + 0.02), "wood"))

    for sy in (-1.40, 1.40):
        p.append(L.box((2.98, 0.18, 0.58), (0.0, sy, deck + 0.29), "wood", bevel=0.02))
    for sx in (-1.40, 1.40):
        p.append(L.box((0.18, 2.98, 0.58), (sx, 0.0, deck + 0.29), "wood", bevel=0.02))
    for mx in (-1.10, 0.0, 1.10):
        p.append(L.box((0.48, 0.22, 0.24), (mx, -1.40, deck + 0.68), "woodDark", bevel=0.02))

    # Besta pesada de torcao no parapeito frontal: bobinas de corda, laminas compostas, carregador e mira de latao
    bx, by, bz = -0.38, -1.36, deck + 0.78
    p.append(L.box((0.24, 1.24, 0.20), (bx, by, bz), "woodDark", bevel=0.022))
    p.append(L.box((0.36, 0.26, 0.22), (bx, by - 0.52, bz + 0.02), "brass", bevel=0.02))
    p += _spoked_wheel_hd(0.28, 0.10, (bx, by + 0.58, bz + 0.02), "brass", "woodDark", "ironDark", spokes=6, axis="x", verts=10)

    # Bobinas helicoidais de corda de torcao + laminas de arco composto em camadas
    for sx in (-1, 1):
        p.append(
            _helical_coil(
                0.13,
                0.032,
                0.095,
                2.0,
                (bx + sx * 0.28, by - 0.50, bz + 0.02),
                "straw",
                axis="z",
                segs_per_turn=8,
                wire_segs=5,
            )
        )
        p.append(L.cyl(0.16, 0.06, (bx + sx * 0.28, by - 0.50, bz + 0.16), "brass", verts=8))
        limb_pts = (
            (bx + sx * 0.22, by - 0.52, bz + 0.04),
            (bx + sx * 0.58, by - 0.44, bz + 0.06),
            (bx + sx * 0.86, by - 0.26, bz + 0.05),
            (bx + sx * 1.02, by - 0.18, bz + 0.03),
        )
        p.append(_curved_tube(limb_pts, (0.055, 0.048, 0.036, 0.024), "steel", wire_segs=6))
        inner_pts = (
            (bx + sx * 0.22, by - 0.47, bz + 0.08),
            (bx + sx * 0.54, by - 0.39, bz + 0.09),
            (bx + sx * 0.78, by - 0.23, bz + 0.08),
        )
        p.append(_curved_tube(inner_pts, (0.042, 0.034, 0.022), "woodDark", wire_segs=5))
        p.append(L.capsule_seg((bx + sx * 1.00, by - 0.18, bz + 0.03), (bx, by + 0.28, bz + 0.08), 0.018, 0.018, "parchment", verts=5))

    # Carregador superior de virotes (bolt magazine) + mira dioptrica de latao
    p.append(L.box((0.22, 0.58, 0.28), (bx, by - 0.06, bz + 0.22), "woodDark", bevel=0.018))
    p.append(L.box((0.25, 0.60, 0.06), (bx, by - 0.06, bz + 0.36), "brass"))
    for vz in (0.14, 0.21, 0.28):
        p.append(L.capsule_seg((bx, by + 0.22, bz + vz), (bx, by - 0.68, bz + vz), 0.022, 0.018, "woodLight", verts=5))
        p.append(L.spike(0.042, 0.14, (bx, by - 0.66, bz + vz), "steel", verts=4))
    p.append(L.box((0.06, 0.06, 0.22), (bx, by - 0.48, bz + 0.22), "brass"))
    p.append(_hollow_cyl(0.12, 0.085, 0.045, (bx, by - 0.48, bz + 0.38), "gold", verts=10, axis="y"))

    # Rack lateral de aljavas / virotes emplumados no parapeito direito
    p.append(L.box((0.36, 0.76, 0.42), (1.12, -0.82, deck + 0.22), "woodDark", bevel=0.02))
    p.append(L.box((0.40, 0.80, 0.07), (1.12, -0.82, deck + 0.38), "ironDark"))
    for qx in (1.02, 1.20):
        for qy in (-1.04, -0.82, -0.60):
            p.append(L.capsule_seg((qx, qy, deck + 0.28), (qx + 0.03, qy - 0.04, deck + 0.86), 0.022, 0.020, "parchment", verts=5))
            p.append(L.box((0.05, 0.08, 0.10), (qx + 0.03, qy - 0.04, deck + 0.82), "danger"))

    # Arqueiro vigia esculpido com tunica, manto e capuz
    ax, ay = 0.34, 0.36
    p.append(L.cyl(0.28, 0.66, (ax, ay, deck), "archer", verts=10, r2=0.21))
    p.append(L.cyl(0.34, 0.42, (ax, ay + 0.06, deck + 0.32), "archerDark", verts=10, r2=0.18))
    p.append(L.ball(0.22, (ax, ay, deck + 0.90), "parchment", seg=10, rings=6))
    p.append(L.cyl(0.29, 0.36, (ax, ay + 0.03, deck + 0.88), "archerDark", verts=10, r2=0.08))

    # Progressao monotona L2..L5 (~+175..+380 tris por nivel)
    if lvl >= 2:
        for sx in (-0.96, 0.96):
            p.append(L.box((0.62, 0.13, 0.50), (sx, -1.52, deck + 0.32), "iron", bevel=0.02))
            p.append(_rivet((sx, -1.60, deck + 0.44), "brass"))
        p.append(L.box((0.13, 0.72, 0.50), (-1.52, 0.0, deck + 0.32), "iron"))

    if lvl >= 3:
        roof_z = deck + 1.24
        for sx in (-1.28, 1.28):
            for sy in (-1.28, 1.28):
                p.append(L.box((0.15, 0.15, roof_z - deck), (sx, sy, deck + (roof_z - deck) * 0.5), "woodDark"))
        p.append(
            _lathe(
                ((2.08, 0.0), (1.88, 0.14), (1.28, 0.44), (0.54, 0.68), (0.0, 0.92)),
                (0.0, 0.0, roof_z),
                "roof",
                segs=10,
            )
        )
        p.append(L.box((0.08, 0.82, 0.98), (-1.58, 0.48, deck + 0.96), "danger"))

    if lvl >= 4:
        p += _gear_hd(0.34, 0.11, (-1.16, 0.0, winch_z + 0.20), "gold", teeth=4, axis="x")

    if lvl >= 5:
        p.append(_hollow_cyl(0.54, 0.45, 0.08, (1.00, 1.00, deck + 0.60), "goldBright", verts=8))
        p.append(L.spike(0.46, 0.54, (1.00, 1.00, deck + 0.64), "roof", verts=8))

    return p + L.rank_mast(lvl)


# ---------------------------------------------------------------- piche (~1.25..1.48 studs)
def tar(lvl: int):
    p = base(lvl)
    rim_col = "ironDark" if lvl == 1 else ("iron" if lvl == 2 else ("brass" if lvl == 3 else "gold"))

    # Fornalha-caldeirao rebitada torneada com base de braseiro e borda boleada
    cx, cy = -0.18, 0.06
    cauldron_prof = (
        (1.66, 0.0),
        (1.74, 0.12),
        (1.58, 0.22),
        (1.80, 0.40),
        (1.86, 0.58),
        (1.96, 0.68),
        (1.82, 0.75),
        (1.68, 0.64),
        (1.64, 0.52),
    )
    p.append(_lathe(cauldron_prof, (cx, cy, BASE_TOP), "ironDark" if lvl == 1 else "iron", segs=24))
    p.append(_hollow_cyl(1.97, 1.79, 0.10, (cx, cy, BASE_TOP + 0.70), rim_col, verts=24))

    # Portinholas incandescentes da fornalha + anel de 16 rebites ao redor do bojo
    for k in range(8):
        ang = 2.0 * math.pi * k / 8.0 + 0.20
        vx, vy = cx + 1.66 * math.cos(ang), cy + 1.66 * math.sin(ang)
        p.append(L.box((0.14, 0.24, 0.12), (vx, vy, BASE_TOP + 0.14), "ember" if k % 2 == 0 else "danger", rot=(0.0, 0.0, ang)))
    for k in range(16):
        ang = 2.0 * math.pi * k / 16.0
        rx, ry = cx + 1.86 * math.cos(ang), cy + 1.86 * math.sin(ang)
        p.append(L.ico(0.052, (rx, ry, BASE_TOP + 0.52), "brass" if lvl >= 2 else "iron", subdiv=0))

    # Superficie de piche fervente + grelha submersa + coroa de respingos e bolhas viscosas
    p.append(L.cyl(1.68, 0.08, (cx, cy, BASE_TOP + 0.56), "ink", verts=22))
    p.append(_hollow_cyl(1.18, 1.06, 0.05, (cx, cy, BASE_TOP + 0.63), "tarGlow", verts=20))
    p.append(_hollow_cyl(0.66, 0.56, 0.05, (cx, cy, BASE_TOP + 0.64), "tarDeep", verts=16))
    for gx in (-0.84, -0.28, 0.28, 0.84):
        p.append(L.box((0.07, 2.75, 0.05), (cx + gx, cy, BASE_TOP + 0.61), "ironDark"))

    # Coroa de ebulicao e bolhas de piche
    bubbles = (
        (-0.56, -0.28, 0.24, "tarGlow"),
        (0.42, 0.30, 0.22, "tarGlow"),
        (-0.08, 0.62, 0.19, "amber"),
        (-0.62, 0.42, 0.16, "tarDeep"),
        (0.52, -0.34, 0.17, "tarGlow"),
        (0.08, -0.68, 0.15, "tarDeep"),
    )
    for bx, by, br, bcol in bubbles:
        p.append(L.ico(br, (cx + bx, cy + by, BASE_TOP + 0.64), bcol, squash=(1.0, 1.0, 0.68), subdiv=1))
    for k in range(10):
        ang = 2.0 * math.pi * k / 10.0 + 0.12
        sx, sy = cx - 0.56 + 0.34 * math.cos(ang), cy - 0.28 + 0.34 * math.sin(ang)
        p.append(L.crystal(0.055, 0.19, (sx, sy, BASE_TOP + 0.63), "tarGlow", tilt=(-0.42 * math.sin(ang), 0.42 * math.cos(ang)), verts=5))

    # Tanque auxiliar cintado de ferro (traseira-direita, baixo para manter classe <= 1.5 stud)
    tx, ty, tz = 1.46, 1.18, BASE_TOP + 0.36
    p.append(L.cyl_axis(0.36, 1.02, (tx, ty, tz), "woodDark", axis="y", verts=16))
    for hy in (-0.36, 0.0, 0.36):
        p.append(_hollow_cyl(0.39, 0.34, 0.07, (tx, ty + hy, tz), rim_col, verts=16, axis="y"))

    # Tubulacao de pressao + serpentina helicoidal + manometro de latao
    pipe_pts = ((tx, ty - 0.48, tz + 0.10), (tx - 0.12, ty - 0.84, tz + 0.34), (cx + 1.46, cy + 0.32, BASE_TOP + 0.68))
    p.append(_curved_tube(pipe_pts, (0.062, 0.058, 0.055), "brass", wire_segs=8))
    p.append(
        _helical_coil(
            0.14,
            0.028,
            0.075,
            3.0,
            (tx - 0.38, ty - 0.18, tz + 0.18),
            "bronze",
            axis="z",
            segs_per_turn=11,
            wire_segs=6,
        )
    )
    p.append(_hollow_cyl(0.18, 0.13, 0.07, (tx - 0.12, ty - 0.84, tz + 0.54), "brass", verts=14, axis="y"))
    p.append(L.cyl_axis(0.14, 0.04, (tx - 0.12, ty - 0.85, tz + 0.54), "parchment", axis="y", verts=12))
    p.append(L.box((0.03, 0.03, 0.11), (tx - 0.10, ty - 0.88, tz + 0.56), "danger", rot=(0.0, 0.52, 0.0)))

    # Bicas esculpidas em carranca de gargula despejando piche viscoso
    def _gargoyle_spout(gx, gy, rot_z_ang):
        c_g, s_g = math.cos(rot_z_ang), math.sin(rot_z_ang)
        fx, fy = -s_g, -c_g
        spout = [
            L.box((0.36, 0.34, 0.28), (gx, gy, BASE_TOP + 0.56), "stoneDark" if lvl < 4 else "brass", bevel=0.025, rot=(0.0, 0.0, rot_z_ang)),
            L.box((0.26, 0.26, 0.16), (gx + fx * 0.18, gy + fy * 0.18, BASE_TOP + 0.48), "ironDark", rot=(0.0, 0.0, rot_z_ang)),
            _hollow_cyl(0.12, 0.075, 0.20, (gx + fx * 0.24, gy + fy * 0.24, BASE_TOP + 0.46), "ink", verts=10, axis="y", rot_z=rot_z_ang),
            L.capsule_seg(
                (gx + fx * 0.26, gy + fy * 0.26, BASE_TOP + 0.44),
                (gx + fx * 0.32, gy + fy * 0.32, BASE_TOP + 0.12),
                0.065,
                0.095,
                "tarGlow",
                verts=8,
            ),
        ]
        for hs in (-1, 1):
            hx = gx + hs * 0.16 * c_g
            hy = gy + hs * 0.16 * s_g
            spout.append(L.crystal(0.05, 0.20, (hx, hy, BASE_TOP + 0.66), rim_col, tilt=(-0.35 * fy, 0.35 * fx), verts=5))
        return spout

    p += _gargoyle_spout(cx - 0.82, cy - 1.62, 0.46)
    p += _gargoyle_spout(cx + 0.86, cy - 1.58, -0.48)

    # Duas conchas de fundidor (ladles) apoiadas na borda do caldeirao
    p.append(
        _lathe(
            ((0.0, 0.0), (0.19, 0.04), (0.23, 0.14), (0.19, 0.16), (0.15, 0.06), (0.0, 0.05)),
            (cx - 0.92, cy + 0.72, BASE_TOP + 0.62),
            "iron",
            segs=14,
        )
    )
    ladle_handle = ((cx - 0.92, cy + 0.88, BASE_TOP + 0.74), (cx - 1.48, cy + 1.42, BASE_TOP + 0.90), (cx - 1.68, cy + 1.56, BASE_TOP + 0.82))
    p.append(_curved_tube(ladle_handle, (0.032, 0.030, 0.036), "ironDark", wire_segs=6))
    p.append(
        _lathe(
            ((0.0, 0.0), (0.15, 0.04), (0.18, 0.12), (0.14, 0.13), (0.0, 0.04)),
            (cx + 0.96, cy + 0.94, BASE_TOP + 0.62),
            "bronze",
            segs=10,
        )
    )

    # Placa frontal baixa para chevrons de patente (preserva classe ~1.4 stud)
    p.append(L.box((2.58, 0.26, 0.48), (0.0, -2.06, BASE_TOP + 0.24), "woodDark", bevel=0.028))
    p.append(L.box((2.66, 0.09, 0.09), (0.0, -2.18, BASE_TOP + 0.47), rim_col))

    # Progressao monotona L2..L5
    if lvl >= 2:
        p.append(_hollow_cyl(0.22, 0.16, 0.06, (tx + 0.40, ty, tz + 0.12), "brass", verts=10, axis="x"))
        p.append(L.box((0.06, 0.36, 0.05), (tx + 0.40, ty, tz + 0.12), "brass"))

    if lvl >= 3:
        p += _gear_hd(0.56, 0.08, (cx, cy, BASE_TOP + 0.67), "brass", teeth=4, axis="z")

    if lvl >= 4:
        p += _gear_hd(0.32, 0.08, (cx + 0.76, cy + 0.24, BASE_TOP + 0.69), "gold", teeth=4, axis="z")

    if lvl >= 5:
        p.append(_hollow_cyl(1.42, 1.32, 0.06, (cx, cy, BASE_TOP + 0.68), "goldBright", verts=8))

    return p + L.rank_row(lvl, y=-2.26, z=BASE_TOP + 0.28)


# ---------------------------------------------------------------- gelo (~4.45..4.78 studs)
def frost(lvl: int):
    # GDD HSV: Defensor NUNCA usa 160..195 deg -> usar estritamente ice/iceLight/iceGlow/royal/obsidian/gold.
    p = base(lvl)
    trim_col = "iron" if lvl < 3 else ("brass" if lvl == 3 else "gold")

    # Estrado octogonal escalonado com canais runicos glaciais e garras de obsidiana
    p.append(L.cyl(1.96, 0.14, (0.0, 0.0, BASE_TOP), "whiteStoneDark", verts=8, r2=1.84, rot_z=math.pi / 8))
    p.append(L.cyl(1.62, 0.18, (0.0, 0.0, BASE_TOP + 0.14), "obsidian" if lvl >= 2 else "stoneDark", verts=8, r2=1.46, rot_z=math.pi / 8))
    p.append(L.cyl(1.22, 0.22, (0.0, 0.0, BASE_TOP + 0.32), "obsidianLight", verts=8, r2=1.04, rot_z=math.pi / 8))
    p.append(_hollow_cyl(1.52, 1.38, 0.06, (0.0, 0.0, BASE_TOP + 0.33), "iceGlow", verts=16))

    for k in range(8):
        ang = 2.0 * math.pi * k / 8.0
        p.append(L.box((0.12, 0.64, 0.06), (1.42 * math.cos(ang), 1.42 * math.sin(ang), BASE_TOP + 0.16), "iceGlow" if k % 2 == 0 else "royal", rot=(0.0, 0.0, ang + math.pi * 0.5)))
        p.append(
            _taper_box(
                0.28,
                0.44,
                0.18,
                0.22,
                0.46,
                (1.26 * math.cos(ang), 1.26 * math.sin(ang), BASE_TOP + 0.10),
                "ironDark" if lvl < 3 else "steel",
                rot_z=ang + math.pi * 0.5,
            )
        )

    # 4 bobinas condensadoras helicoidais de latao com tubos coletores
    for k in range(4):
        ang = math.pi * 0.25 + k * math.pi * 0.5
        cx, cy = 1.38 * math.cos(ang), 1.38 * math.sin(ang)
        p.append(L.cyl(0.11, 0.86, (cx, cy, BASE_TOP + 0.18), "iceGlow", verts=10))
        p.append(
            _helical_coil(
                0.16,
                0.030,
                0.15,
                3.5,
                (cx, cy, BASE_TOP + 0.62),
                "brass",
                axis="z",
                segs_per_turn=9,
                wire_segs=5,
            )
        )
        p.append(L.cyl(0.19, 0.08, (cx, cy, BASE_TOP + 1.00), trim_col, verts=12))
        cond_pts = ((cx, cy, BASE_TOP + 1.06), (cx * 0.72, cy * 0.72, BASE_TOP + 1.24), (cx * 0.38, cy * 0.38, BASE_TOP + 1.12))
        p.append(_curved_tube(cond_pts, (0.042, 0.038, 0.036), "bronze", wire_segs=6))

    # Aglomerado de cristais criogenicos multifacetados
    z0 = BASE_TOP + 0.52
    p.append(_faceted_crystal(0.64, 3.62, (0.0, 0.0, z0), "ice", sides=8, spin=math.pi / 8, waist=0.58))
    p.append(_faceted_crystal(0.34, 0.74, (0.0, 0.0, z0 + 3.18), "iceGlow", sides=8, spin=0.0, waist=0.48))

    cluster_specs = (
        (0.0, 0.78, 0.34, 2.10, "iceLight", 0.26),
        (2.09, 0.78, 0.34, 2.04, "ice", 0.26),
        (4.19, 0.78, 0.34, 2.12, "iceLight", 0.26),
        (1.05, 0.92, 0.24, 1.42, "royal", 0.34),
        (3.14, 0.92, 0.24, 1.46, "iceGlow", 0.34),
        (5.23, 0.92, 0.24, 1.38, "royal", 0.34),
        (0.52, 1.08, 0.18, 0.92, "iceLight", 0.40),
        (3.66, 1.08, 0.18, 0.92, "iceGlow", 0.40),
    )
    for ang, dist, cr, ch, col, tilt_m in cluster_specs:
        px, py = dist * math.cos(ang), dist * math.sin(ang)
        p.append(_faceted_crystal(cr, ch, (px, py, z0 - 0.04), col, sides=8, tilt=(-tilt_m * math.sin(ang), tilt_m * math.cos(ang)), spin=ang))

    # Aneis orbitais flutuantes de geada com nodos cristalinos
    p.append(_hollow_cyl(1.18, 1.05, 0.08, (0.0, 0.0, z0 + 1.45), "iceLight", verts=22, tilt=0.34))
    p.append(_hollow_cyl(0.86, 0.75, 0.07, (0.0, 0.0, z0 + 2.28), trim_col, verts=18, tilt=-0.28))
    for k in range(4):
        ang = k * math.pi * 0.5
        gx = 1.16 * math.cos(ang)
        gy = 1.16 * math.sin(ang) * math.cos(0.34)
        gz = z0 + 1.45 + 1.16 * math.sin(ang) * math.sin(0.34)
        p.append(L.ico(0.11, (gx, gy, gz), "iceGlow", subdiv=1))

    # Progressao monotona L2..L5
    if lvl >= 2:
        for sx in (-1, 1):
            p.append(_faceted_crystal(0.28, 2.25, (sx * 1.02, -0.20, z0 - 0.04), "iceLight", sides=5, tilt=(0.10, sx * 0.28)))

    if lvl >= 3:
        p.append(_hollow_cyl(1.26, 1.14, 0.075, (0.0, 0.0, z0 + 1.86), "royal", verts=12, axis="z", tilt=-0.42, rot_z=0.65))

    if lvl >= 4:
        p.append(_hollow_cyl(0.96, 0.85, 0.065, (0.0, 0.0, z0 + 0.88), "gold", verts=14))

    if lvl >= 5:
        for k in range(2):
            ang = k * math.pi + 0.45
            p.append(_faceted_crystal(0.15, 0.68, (0.48 * math.cos(ang), 0.48 * math.sin(ang), z0 + 2.66), "goldBright", sides=5, tilt=(-0.44 * math.sin(ang), 0.44 * math.cos(ang))))

    return p + L.rank_mast(lvl)


# ---------------------------------------------------------------- canhao (~3.05..3.35 studs)
def cannon(lvl: int):
    p = base(lvl)
    barrel_col = "iron" if lvl == 1 else "steel"
    band_col = "ironDark" if lvl == 1 else ("brass" if lvl < 4 else "gold")

    # Trilho circular giratorio parafusado no plinto + base da carreta
    p.append(_hollow_cyl(1.58, 1.38, 0.09, (0.0, 0.08, BASE_TOP + 0.045), "ironDark", verts=12))
    p.append(_taper_box(1.56, 2.76, 1.38, 2.42, 0.50, (0.0, 0.14, BASE_TOP + 0.12), "wood", bevel=0.025))
    p.append(L.box((1.62, 0.36, 0.24), (0.0, -1.08, BASE_TOP + 0.52), "ironDark", bevel=0.02))

    # Carreta escalonada de artilharia + chapas de munhao (trunnion cheek plates) + 4 rodas raiadas
    for sx in (-1, 1):
        p.append(L.box((0.26, 2.18, 0.56), (sx * 0.64, 0.22, BASE_TOP + 0.96), "woodDark", bevel=0.022))
        p.append(L.box((0.26, 1.46, 0.44), (sx * 0.64, -0.10, BASE_TOP + 1.44), "wood", bevel=0.02))
        p.append(L.box((0.09, 1.36, 0.58), (sx * 0.79, -0.06, BASE_TOP + 1.38), band_col))
        p.append(_hollow_cyl(0.24, 0.14, 0.30, (sx * 0.64, -0.24, BASE_TOP + 1.78), "ironDark", verts=10, axis="x"))
        for ry in (-0.56, -0.06, 0.44):
            p.append(_rivet((sx * 0.85, ry, BASE_TOP + 1.44), "brass" if lvl >= 2 else "iron", r=0.045))
        p += _spoked_wheel_hd(0.66, 0.22, (sx * 1.04, -0.52, BASE_TOP + 0.66), "ironDark", "wood", band_col, spokes=8, axis="x", verts=10)
        p += _spoked_wheel_hd(0.42, 0.18, (sx * 0.98, 1.04, BASE_TOP + 0.44), "ironDark", "woodDark", "iron", spokes=6, axis="x", verts=10)

    # Cano pesado de bombarda multi-cintado + alma raiada (rifling)
    tilt = 0.21
    c = (0.0, -0.24, BASE_TOP + 1.90)
    d = (0.0, -math.cos(tilt), math.sin(tilt))

    def along(t):
        return (c[0] + d[0] * t, c[1] + d[1] * t, c[2] + d[2] * t)

    bombard_prof = (
        (0.0, -1.56),
        (0.20, -1.48),
        (0.13, -1.34),
        (0.42, -1.18),
        (0.48, -0.78),
        (0.44, -0.10),
        (0.40, 0.56),
        (0.36, 1.12),
        (0.50, 1.34),
        (0.48, 1.46),
        (0.30, 1.46),
        (0.28, 0.92),
        (0.0, 0.90),
    )
    p.append(_lathe(bombard_prof, c, barrel_col, segs=16, axis="y", tilt=tilt))
    p.append(L.cyl_axis(0.14, 1.56, along(-0.02), "ironDark", axis="x", verts=10))

    # Cintas de reforco forjadas ao longo do cano + estrias internas de raiamento na boca
    for t_band, r_b in ((-1.02, 0.50), (-0.54, 0.49), (0.04, 0.46), (0.62, 0.42), (1.18, 0.40)):
        p.append(_hollow_cyl(r_b, r_b - 0.06, 0.11, along(t_band), band_col, verts=12, axis="y", tilt=tilt))
    muzzle_c = along(1.24)
    for k in range(6):
        ra = 2.0 * math.pi * k / 6.0
        ox, oz = 0.27 * math.cos(ra), 0.27 * math.sin(ra)
        p.append(
            L.box(
                (0.045, 0.42, 0.045),
                (muzzle_c[0] + ox, muzzle_c[1], muzzle_c[2] + oz * math.cos(tilt)),
                "ironDark",
                rot=(-tilt, 0.0, 0.0),
            )
        )

    # Alcas superiores (golfinhos de bronze) + ouvido de disparo com pavio aceso
    for sx in (-0.14, 0.14):
        dh_pts = (
            (sx, c[1] + 0.18, c[2] + 0.40),
            (sx, c[1] - 0.04, c[2] + 0.58),
            (sx, c[1] - 0.26, c[2] + 0.45),
        )
        p.append(_curved_tube(dh_pts, 0.032, "brass", wire_segs=6))
    fuse_b = along(-0.96)
    p.append(_curved_tube(((fuse_b[0], fuse_b[1], fuse_b[2] + 0.44), (fuse_b[0] + 0.12, fuse_b[1] + 0.14, fuse_b[2] + 0.66), (fuse_b[0] + 0.20, fuse_b[1] + 0.24, fuse_b[2] + 0.72)), 0.025, "straw", wire_segs=5))
    p.append(L.ico(0.085, (fuse_b[0] + 0.21, fuse_b[1] + 0.25, fuse_b[2] + 0.73), "amberBright", subdiv=0))

    # Fuso roscado de elevacao (elevation screw) sob a culatra + volante estrelado
    screw_pos = (0.0, 0.88, BASE_TOP + 1.02)
    p.append(L.cyl(0.065, 0.92, (screw_pos[0], screw_pos[1], BASE_TOP + 0.56), "steel", verts=8))
    p.append(_helical_coil(0.085, 0.024, 0.11, 3.5, screw_pos, "brass", axis="z", segs_per_turn=9, wire_segs=5))
    p.append(_hollow_cyl(0.28, 0.21, 0.06, (0.0, 0.88, BASE_TOP + 0.76), "brass", verts=12))
    for k in range(2):
        p.append(L.box((0.54, 0.05, 0.05), (0.0, 0.88, BASE_TOP + 0.76), "brass", rot=(0.0, 0.0, k * math.pi * 0.5)))

    # Piramides empilhadas de balas de canhao em bandejas de madeira/ferro
    p.append(L.box((0.76, 0.76, 0.10), (-1.32, -1.46, BASE_TOP + 0.05), "woodDark", bevel=0.02))
    for bx in (-0.15, 0.15):
        for by in (-0.15, 0.15):
            p.append(L.ball(0.15, (-1.32 + bx, -1.46 + by, BASE_TOP + 0.22), "ironDark", seg=8, rings=3))
    p.append(L.ball(0.15, (-1.32, -1.46, BASE_TOP + 0.43), "steel" if lvl >= 3 else "ironDark", seg=8, rings=3))

    # Progressao monotona L2..L5
    if lvl >= 2:
        p.append(L.box((0.74, 0.74, 0.10), (1.32, -1.46, BASE_TOP + 0.05), "woodDark"))
        for bx, by in ((-0.15, -0.15), (0.15, -0.15), (-0.15, 0.15), (0.15, 0.15)):
            p.append(L.ico(0.15, (1.32 + bx, -1.46 + by, BASE_TOP + 0.22), "ironDark", subdiv=0))
        p.append(L.ico(0.15, (1.32, -1.46, BASE_TOP + 0.43), "steel", subdiv=0))

    if lvl >= 3:
        kx, ky = 1.26, 1.38
        p.append(L.cyl(0.28, 0.62, (kx, ky, BASE_TOP), "wood", verts=10))
        p.append(L.box((0.07, 0.07, 0.28), (0.0, c[1] + 0.34, c[2] + 0.44), "bronze"))
        p.append(_hollow_cyl(0.13, 0.09, 0.05, (0.0, c[1] + 0.34, c[2] + 0.62), "gold", verts=8, axis="y", tilt=tilt))

    if lvl >= 4:
        p += _gear_hd(0.36, 0.10, (-0.88, 0.62, BASE_TOP + 1.18), "gold", teeth=4, axis="x")

    if lvl >= 5:
        p.append(_hollow_cyl(0.55, 0.47, 0.11, along(1.38), "goldBright", verts=8, axis="y", tilt=tilt))

    return p + L.rank_mast(lvl)


# ---------------------------------------------------------------- catapulta (~4.80..5.15 studs)
def catapult(lvl: int):
    p = base(lvl)
    trim_col = "ironDark" if lvl == 1 else ("iron" if lvl == 2 else ("brass" if lvl == 3 else "gold"))

    # Chassi pesado de vigas de carvalho com travessas encaixadas e sapatas rebitadas
    for sx in (-1, 1):
        p.append(L.box((0.34, 3.68, 0.40), (sx * 1.04, 0.0, BASE_TOP + 0.68), "wood", bevel=0.025))
        p.append(L.box((0.40, 0.52, 0.46), (sx * 1.04, -1.10, BASE_TOP + 0.68), trim_col, bevel=0.02))
        p.append(L.box((0.40, 0.48, 0.46), (sx * 1.04, 1.16, BASE_TOP + 0.68), trim_col, bevel=0.02))
    for sy in (-1.56, 0.0, 1.56):
        p.append(L.box((2.42, 0.32, 0.34), (0.0, sy, BASE_TOP + 0.70), "woodDark", bevel=0.02))

    # 4 rodas raiadas de cerco
    for sx in (-1, 1):
        p += _spoked_wheel_hd(0.58, 0.22, (sx * 1.36, -1.08, BASE_TOP + 0.58), "ironDark", "wood", trim_col, spokes=8, axis="x", verts=10)
        p += _spoked_wheel_hd(0.52, 0.20, (sx * 1.36, 1.14, BASE_TOP + 0.52), "ironDark", "woodDark", "iron", spokes=6, axis="x", verts=10)

    # Cavalete em A contraventado + eixo mestre de torcao com bobinas helicoidais
    pivot = (0.0, -0.32, BASE_TOP + 2.02)
    for sx in (-1, 1):
        p.append(_taper_box(0.36, 0.38, 0.28, 0.28, 1.48, (sx * 0.82, pivot[1], BASE_TOP + 0.62), "wood", bevel=0.02))
        p.append(L.box((0.20, 1.42, 0.20), (sx * 0.82, pivot[1] + 0.52, BASE_TOP + 1.38), "woodDark", rot=(0.76, 0.0, 0.0)))
        p.append(L.box((0.20, 1.24, 0.20), (sx * 0.82, pivot[1] - 0.48, BASE_TOP + 1.34), "woodDark", rot=(-0.82, 0.0, 0.0)))
    p.append(L.cyl_axis(0.13, 2.02, pivot, "iron", axis="x", verts=10))
    for sx in (-0.46, 0.46):
        p.append(_helical_coil(0.20, 0.042, 0.12, 2.2, (sx, pivot[1], pivot[2]), "straw", axis="x", segs_per_turn=9, wire_segs=5))

    # Tambores de catraca de bronze (bronze ratchet drums) + guincho traseiro de corda
    winch = (0.0, 1.16, BASE_TOP + 0.98)
    p.append(L.cyl_axis(0.18, 1.88, winch, "woodDark", axis="x", verts=10))
    p.append(_helical_coil(0.21, 0.034, 0.125, 2.4, (0.0, winch[1], winch[2]), "straw", axis="x", segs_per_turn=9, wire_segs=5))
    p += _gear_hd(0.34, 0.12, (-0.78, winch[1], winch[2]), "bronze", teeth=5, axis="x", hub_color="brass")
    p += _gear_hd(0.34, 0.12, (0.78, winch[1], winch[2]), "bronze", teeth=5, axis="x", hub_color="brass")
    for sx in (-0.78, 0.78):
        p.append(L.box((0.10, 0.42, 0.10), (sx, winch[1] + 0.28, winch[2] + 0.24), "ironDark", rot=(-0.48, 0.0, 0.0)))

    # Braco lancador ferrado com colher concava torneada (spoon arm)
    a = math.radians(54)
    d = (0.0, math.cos(a), math.sin(a))
    arm_len = 2.86
    mid = (0.0, pivot[1] + d[1] * (arm_len * 0.5 - 0.36), pivot[2] + d[2] * (arm_len * 0.5 - 0.36))
    p.append(L.box((0.30, arm_len, 0.28), mid, "wood", bevel=0.022, rot=(a, 0.0, 0.0)))
    for bt in (0.35, 1.05, 1.75):
        bp = (0.0, pivot[1] + d[1] * bt, pivot[2] + d[2] * bt)
        p.append(L.box((0.35, 0.14, 0.33), bp, trim_col, rot=(a, 0.0, 0.0)))
    p.append(L.box((0.08, 0.48, 0.28), (0.0, pivot[1] + d[1] * 2.02, pivot[2] + d[2] * 2.02 - 0.28), "catapult"))

    # Concha/colher esculpida + rocha de magma incandescente em gaiola de ferro
    tip = (0.0, pivot[1] + d[1] * 2.34, pivot[2] + d[2] * 2.34)
    spoon_prof = ((0.0, 0.0), (0.42, 0.04), (0.58, 0.26), (0.54, 0.34), (0.42, 0.16), (0.0, 0.10))
    p.append(_lathe(spoon_prof, (tip[0], tip[1], tip[2] - 0.06), "woodDark", segs=14))
    p.append(_hollow_cyl(0.60, 0.51, 0.08, (tip[0], tip[1], tip[2] + 0.24), trim_col, verts=14))

    boulder_c = (tip[0], tip[1], tip[2] + 0.40)
    p.append(L.ico(0.34, boulder_c, "obsidian", subdiv=1))
    p.append(L.ico(0.24, (boulder_c[0] - 0.11, boulder_c[1] - 0.10, boulder_c[2] + 0.08), "ember", subdiv=1))
    p.append(L.ico(0.20, (boulder_c[0] + 0.12, boulder_c[1] + 0.09, boulder_c[2] + 0.06), "danger", subdiv=1))
    p.append(L.ico(0.14, (boulder_c[0], boulder_c[1] - 0.06, boulder_c[2] + 0.22), "amberBright", subdiv=0))
    p.append(_hollow_cyl(0.39, 0.34, 0.07, boulder_c, "ironDark", verts=10, axis="z"))
    p.append(_hollow_cyl(0.39, 0.34, 0.07, boulder_c, "ironDark", verts=10, axis="x"))
    p.append(_hollow_cyl(0.39, 0.34, 0.07, boulder_c, "ironDark", verts=10, axis="y"))

    # Contrapeso dianteiro articulado
    cw_pos = (0.0, pivot[1] - 0.44, pivot[2] - 0.68)
    p.append(_taper_box(0.86, 0.72, 0.68, 0.58, 0.66, (cw_pos[0], cw_pos[1], cw_pos[2] - 0.32), "stoneDark", bevel=0.025))
    p.append(L.box((0.90, 0.14, 0.68), cw_pos, "ironDark"))

    # Progressao monotona L2..L5
    if lvl >= 2:
        for sx in (-1, 1):
            p.append(L.box((0.36, 0.54, 0.56), (sx * 0.52, cw_pos[1], cw_pos[2]), "iron", bevel=0.02))

    if lvl >= 3:
        for sx in (-1, 1):
            p.append(L.box((0.24, 0.24, 2.08), (sx * 0.94, -1.68, BASE_TOP + 1.86), "woodDark"))
        p.append(L.box((2.24, 0.28, 0.28), (0.0, -1.68, BASE_TOP + 2.88), "ironDark", bevel=0.02))
        for x_sp in (-0.66, 0.0, 0.66):
            p.append(L.spike(0.13, 0.38 if x_sp == 0.0 else 0.28, (x_sp, -1.68, BASE_TOP + 3.02), "gold", verts=6))

    if lvl >= 4:
        p += _gear_hd(0.40, 0.11, (1.06, pivot[1], pivot[2]), "gold", teeth=4, axis="x")

    if lvl >= 5:
        for sx in (-1, 1):
            p.append(L.box((0.10, 3.50, 0.09), (sx * 1.24, 0.0, BASE_TOP + 0.72), "goldBright"))
        p.append(L.ico(0.16, (boulder_c[0], boulder_c[1], boulder_c[2] + 0.18), "neonAmber", subdiv=0))

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
                    "qualidade": "hero",
                    "hero_pbr": False,
                    "quantidade_cena": 1,
                    "tags": ["muralha", "trap", kind, f"l{lvl}"],
                    "seed": seed,
                    "build": (lambda f=fn, n=lvl: f(n)),
                }
            )
    return out


L.run_group("traps", specs(), "armadilhas L1-L5 AA (art/scripts/make_traps.py)", hero_pbr=False)
