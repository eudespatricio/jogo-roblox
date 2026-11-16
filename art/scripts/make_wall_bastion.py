"""Gera a Muralha do Bastiao (WALL_) em 5 tiers visuais (L1..L5) com escultura arquitetonica AA.

Modular: segmento (x2), portaria central e torre (x2) por tier, mantendo exatamente os vaos
canonicos (SEG_A=5.9, SEG_B=19.2, TOWER_X=22.0, TOWER_R=2.8, GATE_W=11.8, GATE_D=3.8, GATE_H=10.0),
frente = -Y no Blender (+Z glTF), Z-up, 16.000..17.800 tris com progressao monotonica L1..L5.

Detalhes esculpidos: fiadas de silhares chanfrados nas cortinas e torres, cachorros com arcos de
mata-caes, ameias com capeamentos chanfrados em cumeeira, arco da portaria em multiplas ordens de
aduelas, rastrilho pontiagudo com tambores de guincho e correntes, portoes de carvalho com cintas
de ferro e cravos, seteiras recuadas em esconso, arcobotantes (flying buttresses), braseiros de
ferro forjado, escudos heraldicos e filigrana progressiva em bronze/ouro/arcano L3..L5.

Uso headless:
  FORGE_SKIP_RENDER=1 blender -b --factory-startup --python-exit-code 1 --python art/scripts/make_wall_bastion.py
Saidas: art/src/wall_bastion.blend (quando nao pula render), art/export/wall_bastion_l{1..5}.glb,
        art/forge/lote_muralha_import.yaml (gerado, qualidade: ultra, altura medida),
        art/renders/wall_bastion_l{1..5}.png (ignorado no git)
"""

from __future__ import annotations

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly_lib import (  # noqa: E402
    DEFAULT_DETALHE_ALTO,
    NAMES,
    PAL,
    _assign_poly_uv_cell,
    _collect_and_coalesce_pal_colors,
    build_pbr_zonas,
    extract_pal_colors,
    format_pbr_zonas_yaml,
    make_palette,
)

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LEVELS = (1, 2, 3, 4, 5)
TIER_TRIS_MAX = 17900
LIMITE_LOTE = {lvl: 18000 for lvl in LEVELS}
METROS_POR_STUD = 0.28  # perfil roblox-aa-80 do Forge3D
BUDGET = {"segment": 4200, "gate": 5800, "tower": 4800}

# Layout canonico preservado
SEG_A, SEG_B = 5.9, 19.2
TOWER_X, TOWER_R = 22.0, 2.8
GATE_W, GATE_D, GATE_H = 11.8, 3.8, 10.0

assert len(NAMES) <= 64, "atlas 8x8"
MAT = None

TIER_STYLE = {
    1: {
        "plinth": "stoneDark",
        "wall": "wood",
        "wallAlt": "woodLight",
        "buttress": "stone",
        "trim": "woodDark",
        "relief": "woodLight",
        "cornice": "woodDark",
        "cap": "woodLight",
        "roof": "woodDark",
        "roofRib": "woodLight",
        "iron": "ironDark",
        "gatePier": "stoneDark",
        "archRing": "stoneLight",
        "banner": "crimsonCloth",
        "bannerTrim": "amber",
        "slitGlow": "amberBright",
        "boss": "bronze",
        "shieldFace": "woodDark",
        "shieldRim": "bronze",
        "sconceGlow": "ember",
        "flameCore": "neonAmber",
    },
    2: {
        "plinth": "stoneDark",
        "wall": "stone",
        "wallAlt": "stoneLight",
        "buttress": "stoneDark",
        "trim": "stoneDark",
        "relief": "stoneLight",
        "cornice": "stoneDark",
        "cap": "stoneLight",
        "roof": "roof",
        "roofRib": "stoneLight",
        "iron": "iron",
        "gatePier": "stone",
        "archRing": "stoneLight",
        "banner": "crimsonBright",
        "bannerTrim": "amber",
        "slitGlow": "amberBright",
        "boss": "steel",
        "shieldFace": "crimsonCloth",
        "shieldRim": "iron",
        "sconceGlow": "ember",
        "flameCore": "amberBright",
    },
    3: {
        "plinth": "ironDark",
        "wall": "stoneDark",
        "wallAlt": "iron",
        "buttress": "ironDark",
        "trim": "steel",
        "relief": "stone",
        "cornice": "ironDark",
        "cap": "steel",
        "roof": "iron",
        "roofRib": "brass",
        "iron": "ironDark",
        "gatePier": "stoneDark",
        "archRing": "steel",
        "banner": "danger",
        "bannerTrim": "gold",
        "slitGlow": "amberBright",
        "boss": "gold",
        "shieldFace": "ironDark",
        "shieldRim": "brass",
        "sconceGlow": "emberDeep",
        "flameCore": "neonAmber",
    },
    4: {
        "plinth": "ironDark",
        "wall": "obsidian",
        "wallAlt": "obsidianLight",
        "buttress": "obsidianLight",
        "trim": "arcaneViolet",
        "relief": "obsidianLight",
        "cornice": "obsidianLight",
        "cap": "emberDeep",
        "roof": "obsidian",
        "roofRib": "violet",
        "iron": "ironDark",
        "gatePier": "obsidian",
        "archRing": "obsidianLight",
        "banner": "obsidianLight",
        "bannerTrim": "emberDeep",
        "slitGlow": "ember",
        "boss": "arcaneViolet",
        "shieldFace": "obsidian",
        "shieldRim": "emberDeep",
        "sconceGlow": "emberDeep",
        "flameCore": "ember",
    },
    5: {
        "plinth": "whiteStoneDark",
        "wall": "whiteStone",
        "wallAlt": "whiteStoneDark",
        "buttress": "whiteStoneDark",
        "trim": "gold",
        "relief": "goldBright",
        "cornice": "whiteStoneDark",
        "cap": "gold",
        "roof": "royal",
        "roofRib": "goldBright",
        "iron": "gold",
        "gatePier": "whiteStone",
        "archRing": "gold",
        "banner": "royal",
        "bannerTrim": "goldBright",
        "slitGlow": "neonAmber",
        "boss": "goldBright",
        "shieldFace": "royal",
        "shieldRim": "gold",
        "sconceGlow": "amberBright",
        "flameCore": "neonAmber",
    },
}

for _lvl, _st in TIER_STYLE.items():
    for _k, _c in _st.items():
        assert _c in PAL, f"cor desconhecida em TIER_STYLE[{_lvl}][{_k}]: {_c}"


# ---------------------------------------------------------------- materiais
def make_materials():
    global MAT
    img = make_palette()
    MAT = bpy.data.materials.new("M_wall_palette")
    MAT.use_nodes = True
    nt = MAT.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85


def paint(obj, color: str):
    me = obj.data
    if not me.uv_layers:
        me.uv_layers.new(name="UVMap")
    uv = me.uv_layers.active.data
    # UV nao colapsada (QC G3): cada face abrange [cx/8+0.008, (cx+1)/8-0.008] x [cy/8+0.008, (cy+1)/8-0.008]
    for p in me.polygons:
        _assign_poly_uv_cell(uv, p, color)
    me.materials.clear()
    me.materials.append(MAT)  # 1 material por mesh (QC G5)
    for p in me.polygons:
        p.material_index = 0
    obj["muralha_pal_color"] = color
    obj["muralha_pal_colors"] = [color]
    return obj


# ---------------------------------------------------------------- primitivas bmesh (sem overhead de bpy.ops)
def _active():
    return bpy.context.view_layer.objects.active


def _from_bmesh(bm, name, color, bevel=0.0, bevel_segs=1, xform=None):
    vs = bm.verts
    if vs and bevel > 0.0:
        dx = max(v.co.x for v in vs) - min(v.co.x for v in vs)
        dy = max(v.co.y for v in vs) - min(v.co.y for v in vs)
        dz = max(v.co.z for v in vs) - min(v.co.z for v in vs)
        min_dim = min(dx, dy, dz)
        if min_dim > 0.08:
            w = min(bevel, min_dim * 0.24)
            angle_lim = math.radians(30)
            bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
            edges = [
                e
                for e in bm.edges
                if len(e.link_faces) == 2
                and e.link_faces[0].normal.angle(e.link_faces[1].normal, 0.0) > angle_lim
            ]
            if edges:
                bmesh.ops.bevel(
                    bm,
                    geom=edges,
                    offset=w,
                    offset_type="OFFSET",
                    segments=bevel_segs,
                    profile=0.5,
                    affect="EDGES",
                    clamp_overlap=True,
                )
    if xform is not None:
        bmesh.ops.transform(bm, matrix=xform, verts=list(bm.verts))
    bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=2e-4)
    bmesh.ops.dissolve_degenerate(bm, dist=2e-4, edges=list(bm.edges))
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    return paint(obj, color)


def box(size, center, color, bevel=0.0, rot=(0.0, 0.0, 0.0), bevel_segs=1):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    sx, sy, sz = size
    for v in bm.verts:
        v.co.x *= sx
        v.co.y *= sy
        v.co.z *= sz
    mat = Matrix.Translation(center) @ Euler(rot, "XYZ").to_matrix().to_4x4()
    return _from_bmesh(bm, "box", color, bevel=bevel, bevel_segs=bevel_segs, xform=mat)


def cyl(r, h, base, color, verts=24, r2=None, rot_z=0.0, rot_x=0.0, bevel=0.0):
    bm = bmesh.new()
    rad2 = r if r2 is None else r2
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=verts,
        radius1=r,
        radius2=rad2,
        depth=h,
    )
    loc = (base[0], base[1], base[2] + h / 2)
    mat = Matrix.Translation(loc) @ Euler((rot_x, 0.0, rot_z), "XYZ").to_matrix().to_4x4()
    return _from_bmesh(bm, "cyl", color, bevel=bevel, xform=mat)


def cyl_axis(r, length, center, color, axis="x", verts=16, bevel=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=verts,
        radius1=r,
        radius2=r,
        depth=length,
    )
    rot = (0.0, math.pi / 2, 0.0) if axis == "x" else (math.pi / 2, 0.0, 0.0)
    mat = Matrix.Translation(center) @ Euler(rot, "XYZ").to_matrix().to_4x4()
    return _from_bmesh(bm, "cyl_axis", color, bevel=bevel, xform=mat)


def disc_y(r, depth, center, color, verts=18, bevel=0.0, rot_z=0.0):
    bm = bmesh.new()
    bmesh.ops.create_cone(
        bm,
        cap_ends=True,
        cap_tris=False,
        segments=verts,
        radius1=r,
        radius2=r,
        depth=depth,
    )
    mat = Matrix.Translation(center) @ Euler((math.pi / 2, 0.0, rot_z), "XYZ").to_matrix().to_4x4()
    return _from_bmesh(bm, "disc_y", color, bevel=bevel, xform=mat)


def ball(r, center, color, seg=14, rings=8, squash=(1.0, 1.0, 1.0)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    for v in bm.verts:
        v.co.x *= squash[0]
        v.co.y *= squash[1]
        v.co.z *= squash[2]
    mat = Matrix.Translation(center)
    return _from_bmesh(bm, "ball", color, xform=mat)


def torus(r_major, r_minor, center, color, major_seg=18, minor_seg=6, rot=(0.0, 0.0, 0.0)):
    bm = bmesh.new()
    grid = []
    for i in range(major_seg):
        theta = 2.0 * math.pi * i / major_seg
        ct, st_t = math.cos(theta), math.sin(theta)
        ring = []
        for j in range(minor_seg):
            phi = 2.0 * math.pi * j / minor_seg
            cp, sp = math.cos(phi), math.sin(phi)
            rr = r_major + r_minor * cp
            ring.append(bm.verts.new((rr * ct, rr * st_t, r_minor * sp)))
        grid.append(ring)
    for i in range(major_seg):
        i2 = (i + 1) % major_seg
        for j in range(minor_seg):
            j2 = (j + 1) % minor_seg
            bm.faces.new((grid[i][j], grid[i2][j], grid[i2][j2], grid[i][j2]))
    mat = Matrix.Translation(center) @ Euler(rot, "XYZ").to_matrix().to_4x4()
    return _from_bmesh(bm, "torus", color, xform=mat)


def taper_box(w0, d0, w1, d1, h, base_center, color, y_shift_top=0.0, rot_z=0.0, bevel=0.0):
    """Prisma retangular afunilado: base em Z=base_center[2], topo em +h."""
    hw0, hd0 = w0 / 2, d0 / 2
    hw1, hd1 = w1 / 2, d1 / 2
    pts = [
        (-hw0, -hd0, 0.0),
        (hw0, -hd0, 0.0),
        (hw0, hd0, 0.0),
        (-hw0, hd0, 0.0),
        (-hw1, -hd1 + y_shift_top, h),
        (hw1, -hd1 + y_shift_top, h),
        (hw1, hd1 + y_shift_top, h),
        (-hw1, hd1 + y_shift_top, h),
    ]
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in pts]
    for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        bm.faces.new([vs[i] for i in f])
    mat = Matrix.Translation(base_center) @ Matrix.Rotation(rot_z, 4, "Z")
    return _from_bmesh(bm, "taper_box", color, bevel=bevel, xform=mat)


def sloped_buttress(w, d_bot, d_top, h, x, y_back, z0, color, rot_z=0.0, bevel=0.0):
    """Contraforte inclinado ancorado em y_back, projetando-se para -Y (ou rotacionado por rot_z)."""
    hw = w / 2
    pts = [
        (-hw, -d_bot, 0.0),
        (hw, -d_bot, 0.0),
        (hw, 0.0, 0.0),
        (-hw, 0.0, 0.0),
        (-hw * 0.85, -d_top, h),
        (hw * 0.85, -d_top, h),
        (hw * 0.85, 0.0, h),
        (-hw * 0.85, 0.0, h),
    ]
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in pts]
    for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        bm.faces.new([vs[i] for i in f])
    mat = Matrix.Translation((x, y_back, z0)) @ Matrix.Rotation(rot_z, 4, "Z")
    return _from_bmesh(bm, "buttress", color, bevel=bevel, xform=mat)


def ashlar_block(w, d, h, center, color, rot_z=0.0, taper=0.045):
    """Bloco de silhar com face frontal chanfrada (-Y em local), 12 tris manifold."""
    hw0, hh0 = w * 0.5, h * 0.5
    t = min(taper, w * 0.22, h * 0.22)
    hw1, hh1 = hw0 - t, hh0 - t
    hd = d * 0.5
    pts = [
        (-hw0, hd, -hh0),
        (hw0, hd, -hh0),
        (hw0, hd, hh0),
        (-hw0, hd, hh0),
        (-hw1, -hd, -hh1),
        (hw1, -hd, -hh1),
        (hw1, -hd, hh1),
        (-hw1, -hd, hh1),
    ]
    bm = bmesh.new()
    vs = [bm.verts.new(p) for p in pts]
    for f in ((0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)):
        bm.faces.new([vs[i] for i in f])
    mat = Matrix.Translation(center) @ Matrix.Rotation(rot_z, 4, "Z")
    return _from_bmesh(bm, "ashlar", color, xform=mat)


def gabled_cap(w, d, h_eave, h_ridge, base_center, color, rot_z=0.0):
    """Capeamento de ameia em cumeeira chanfrada com pingadeira (20 tris manifold)."""
    hw, hd = w * 0.5, d * 0.5
    hw_e, hd_e = w * 0.54, d * 0.54
    hw_t, hd_t = w * 0.34, d * 0.20
    rings = [
        ((-hw, -hd, 0.0), (hw, -hd, 0.0), (hw, hd, 0.0), (-hw, hd, 0.0)),
        ((-hw_e, -hd_e, h_eave), (hw_e, -hd_e, h_eave), (hw_e, hd_e, h_eave), (-hw_e, hd_e, h_eave)),
        (
            (-hw_t, -hd_t, h_eave + h_ridge),
            (hw_t, -hd_t, h_eave + h_ridge),
            (hw_t, hd_t, h_eave + h_ridge),
            (-hw_t, hd_t, h_eave + h_ridge),
        ),
    ]
    bm = bmesh.new()
    vr = [[bm.verts.new(p) for p in r] for r in rings]
    bm.faces.new((vr[0][0], vr[0][3], vr[0][2], vr[0][1]))
    bm.faces.new((vr[2][0], vr[2][1], vr[2][2], vr[2][3]))
    for r_i in range(2):
        for k in range(4):
            k2 = (k + 1) % 4
            bm.faces.new((vr[r_i][k], vr[r_i][k2], vr[r_i + 1][k2], vr[r_i + 1][k]))
    mat = Matrix.Translation(base_center) @ Matrix.Rotation(rot_z, 4, "Z")
    return _from_bmesh(bm, "gabled_cap", color, xform=mat)


def arch_rib(span, rise, depth, thick, center, color, segs=4, rot_z=0.0):
    """Arco de pedra curvo em local XZ (para mata-caes e galerias)."""
    bm = bmesh.new()
    hd = depth * 0.5
    half_s = span * 0.5
    rings = []
    for k in range(segs + 1):
        ang = math.pi * k / segs
        px = -half_s * math.cos(ang)
        pz = rise * math.sin(ang)
        nx = -math.cos(ang) * thick
        nz = math.sin(ang) * thick
        rings.append(
            [
                bm.verts.new((px, -hd, pz)),
                bm.verts.new((px + nx, -hd, pz + nz)),
                bm.verts.new((px + nx, hd, pz + nz)),
                bm.verts.new((px, hd, pz)),
            ]
        )
    for k in range(segs):
        for j in range(4):
            j2 = (j + 1) % 4
            bm.faces.new((rings[k][j], rings[k + 1][j], rings[k + 1][j2], rings[k][j2]))
    bm.faces.new((rings[0][0], rings[0][3], rings[0][2], rings[0][1]))
    bm.faces.new((rings[-1][0], rings[-1][1], rings[-1][2], rings[-1][3]))
    mat = Matrix.Translation(center) @ Matrix.Rotation(rot_z, 4, "Z")
    return _from_bmesh(bm, "arch_rib", color, xform=mat)


def flyer_arch(y0, z0, y1, z1, width, thick, rise, center_xy, color, segs=4, rot_z=0.0):
    """Arco curvo de arcobotante em local YZ de (y0, z0) ate (y1, z1) com flecha `rise`."""
    bm = bmesh.new()
    hw = width * 0.5
    p0 = Vector((y0, z0))
    p2 = Vector((y1, z1))
    p1 = Vector((y0 + (y1 - y0) * 0.45, max(z0, z1) + rise))
    pts = []
    tans = []
    for k in range(segs + 1):
        t = k / segs
        u = 1.0 - t
        pos = (u * u) * p0 + (2.0 * u * t) * p1 + (t * t) * p2
        tan = (2.0 * u) * (p1 - p0) + (2.0 * t) * (p2 - p1)
        if tan.length < 1e-6:
            tan = p2 - p0
        tan.normalize()
        pts.append(pos)
        tans.append(tan)
    rings = []
    for pos, tan in zip(pts, tans):
        perp = Vector((-tan.y, tan.x))
        if perp.y < 0 and abs(perp.x) < 0.3:
            perp = -perp
        pt_bot = pos - perp * (thick * 0.5)
        pt_top = pos + perp * (thick * 0.5)
        rings.append(
            [
                bm.verts.new((-hw, pt_bot.x, pt_bot.y)),
                bm.verts.new((hw, pt_bot.x, pt_bot.y)),
                bm.verts.new((hw, pt_top.x, pt_top.y)),
                bm.verts.new((-hw, pt_top.x, pt_top.y)),
            ]
        )
    for k in range(segs):
        for j in range(4):
            j2 = (j + 1) % 4
            bm.faces.new((rings[k][j], rings[k][j2], rings[k + 1][j2], rings[k + 1][j]))
    bm.faces.new((rings[0][0], rings[0][3], rings[0][2], rings[0][1]))
    bm.faces.new((rings[-1][0], rings[-1][1], rings[-1][2], rings[-1][3]))
    mat = Matrix.Translation((center_xy[0], center_xy[1], 0.0)) @ Matrix.Rotation(rot_z, 4, "Z")
    return _from_bmesh(bm, "flyer_arch", color, xform=mat)


def heater_plate(w, h, depth, center, color, rot_z=0.0):
    """Placa heraldica pontiaguda de escudo medieval (8 vertices em XZ, extrudida em Y)."""
    hw, hh = w * 0.5, h * 0.5
    hd = depth * 0.5
    profile = [
        (-hw, hh * 0.86),
        (0.0, hh),
        (hw, hh * 0.86),
        (hw * 0.96, hh * 0.08),
        (hw * 0.62, -hh * 0.54),
        (0.0, -hh),
        (-hw * 0.62, -hh * 0.54),
        (-hw * 0.96, hh * 0.08),
    ]
    bm = bmesh.new()
    vf = [bm.verts.new((px, -hd, pz)) for px, pz in profile]
    vb = [bm.verts.new((px, hd, pz)) for px, pz in profile]
    bm.faces.new(vf)
    bm.faces.new(list(reversed(vb)))
    n = len(profile)
    for k in range(n):
        k2 = (k + 1) % n
        bm.faces.new((vf[k], vb[k], vb[k2], vf[k2]))
    mat = Matrix.Translation(center) @ Matrix.Rotation(rot_z, 4, "Z")
    return _from_bmesh(bm, "heater_plate", color, xform=mat)


def arch_spandrel(width, radius, spring_z, top_z, depth, cy, color, segs=16):
    """Bloco manifold do timpano acima do arco semicircular (top_z > spring_z + radius)."""
    hw = width / 2
    top_z = max(top_z, spring_z + radius + 0.25)
    y0, y1 = cy - depth / 2, cy + depth / 2

    arc = [
        (radius * math.cos(math.pi * k / segs), spring_z + radius * math.sin(math.pi * k / segs))
        for k in range(segs + 1)
    ]
    if hw > radius + 1e-4:
        arc = [(hw, spring_z)] + arc + [(-hw, spring_z)]

    bm = bmesh.new()
    vf_bot = [bm.verts.new((px, y0, pz)) for px, pz in arc]
    vf_top = [bm.verts.new((px, y0, top_z)) for px, _ in arc]
    vb_bot = [bm.verts.new((px, y1, pz)) for px, pz in arc]
    vb_top = [bm.verts.new((px, y1, top_z)) for px, _ in arc]

    m = len(arc) - 1
    for i in range(m):
        bm.faces.new((vf_bot[i], vf_top[i], vf_top[i + 1], vf_bot[i + 1]))
        bm.faces.new((vb_bot[i + 1], vb_top[i + 1], vb_top[i], vb_bot[i]))
        bm.faces.new((vf_top[i], vb_top[i], vb_top[i + 1], vf_top[i + 1]))
        bm.faces.new((vb_bot[i], vf_bot[i], vf_bot[i + 1], vb_bot[i + 1]))
    bm.faces.new((vf_bot[0], vb_bot[0], vb_top[0], vf_top[0]))
    bm.faces.new((vf_top[m], vb_top[m], vb_bot[m], vf_bot[m]))
    return _from_bmesh(bm, "arch_spandrel", color)


def join(objs, name, seed):
    """Junta pecas com jitter deterministico 3e-3..10e-3 studs antes de fundir (QC G1)."""
    seed_counts: dict[str, int] = {}
    for o in objs:
        n_polys = max(1, len(o.data.polygons)) if getattr(o, "data", None) is not None else 1
        c = o.get("muralha_pal_color")
        if isinstance(c, str) and c in PAL:
            seed_counts[c] = seed_counts.get(c, 0) + n_polys
        for sub_c in o.get("muralha_pal_colors") or ():
            if isinstance(sub_c, str) and sub_c in PAL:
                seed_counts.setdefault(sub_c, 1)
    rng = random.Random(seed)
    for o in objs:
        o.location = (
            o.location[0] + rng.choice((-1, 1)) * rng.uniform(0.003, 0.010),
            o.location[1] + rng.choice((-1, 1)) * rng.uniform(0.003, 0.010),
            o.location[2] + rng.choice((-1, 1)) * rng.uniform(0.003, 0.010),
        )
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = _active()
    o.name = name
    o.data.name = name
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    _collect_and_coalesce_pal_colors(o, seed_counts=seed_counts, max_colors=16)
    return o


def tris(obj) -> int:
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def g1_check(obj) -> dict:
    """Espelha o QC G1 do Forge3D (solda a 1e-5 m, nao-manifold, degeneradas)."""
    me = obj.data
    me.calc_loop_triangles()
    key = {}
    weld = []
    for v in me.vertices:
        c = (obj.matrix_world @ v.co) * METROS_POR_STUD
        k = (round(c.x, 5), round(c.y, 5), round(c.z, 5))
        weld.append(key.setdefault(k, len(key)))
    edges = {}
    degen = 0
    for t in me.loop_triangles:
        a, b, c = (weld[i] for i in t.vertices)
        if a == b or b == c or a == c or t.area < 1e-10:
            degen += 1
            continue
        for e in ((a, b), (b, c), (c, a)):
            e = (min(e), max(e))
            edges[e] = edges.get(e, 0) + 1
    return {"nao_manifold": sum(1 for n in edges.values() if n != 2), "degeneradas": degen}


def check_tier_union_g1(mods) -> dict:
    """Simula a juncao dos 5 modulos feita pelo Forge3D e checa G1."""
    key = {}
    edges = {}
    degen = 0
    for _, obj in mods:
        me = obj.data
        me.calc_loop_triangles()
        weld = []
        for v in me.vertices:
            c = (obj.matrix_world @ v.co) * METROS_POR_STUD
            k = (round(c.x, 5), round(c.y, 5), round(c.z, 5))
            weld.append(key.setdefault(k, len(key)))
        for t in me.loop_triangles:
            a, b, c = (weld[i] for i in t.vertices)
            if a == b or b == c or a == c or t.area < 1e-10:
                degen += 1
                continue
            for e in ((a, b), (b, c), (c, a)):
                e = (min(e), max(e))
                edges[e] = edges.get(e, 0) + 1
    return {"nao_manifold": sum(1 for n in edges.values() if n != 2), "degeneradas": degen}


def set_origin(obj, x):
    bpy.context.scene.cursor.location = (x, 0, 0)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.origin_set(type="ORIGIN_CURSOR")


# ---------------------------------------------------------------- ornamentos AA
def _pt_rot(x, y, z, lx, ly, lz, rot_z):
    c, s = math.cos(rot_z), math.sin(rot_z)
    return (x + lx * c - ly * s, y + lx * s + ly * c, z + lz)


def shield_crest(x, y, z, r, st, boss_col=None, rot_z=0.0):
    """Escudo heraldico pontiagudo com borda metalica, faixa heraldica e umbo."""
    bcol = boss_col or st["boss"]
    w, h = r * 1.85, r * 2.25
    return [
        heater_plate(w, h, 0.14, _pt_rot(x, y, z, 0.0, 0.0, 0.0, rot_z), st["shieldRim"], rot_z=rot_z),
        heater_plate(
            w * 0.78, h * 0.80, 0.16, _pt_rot(x, y, z, 0.0, -0.04, 0.01, rot_z), st["shieldFace"], rot_z=rot_z
        ),
        box(
            (w * 0.68, 0.09, h * 0.14),
            _pt_rot(x, y, z, 0.0, -0.10, h * 0.10, rot_z),
            st["bannerTrim"],
            rot=(0.0, 0.0, rot_z),
        ),
        ashlar_block(
            r * 0.42, 0.14, r * 0.42, _pt_rot(x, y, z, 0.0, -0.12, h * 0.08, rot_z), bcol, rot_z=rot_z, taper=0.06
        ),
    ]


def sconce(x, y, z, st, tripod=False, scale=1.0):
    """Braseiro de ferro forjado com cesto nervurado, aro e chamas duplas."""
    parts = []
    if tripod:
        bx, by, bz = x, y, z
        parts.append(cyl(0.42 * scale, 0.14 * scale, (bx, by, bz), st["iron"], verts=6))
        for k in range(3):
            ang = 2 * math.pi * k / 3 + 0.3
            lx = bx + math.cos(ang) * 0.24 * scale
            ly = by + math.sin(ang) * 0.24 * scale
            parts.append(
                box(
                    (0.10 * scale, 0.10 * scale, 0.70 * scale),
                    (lx, ly, bz + 0.35 * scale),
                    st["iron"],
                    rot=(0.24 * math.sin(ang), -0.24 * math.cos(ang), ang),
                )
            )
        bowl_z = bz + 0.62 * scale
    else:
        bx, by, bz = x, y - 0.50 * scale, z
        parts.append(box((0.20 * scale, 0.58 * scale, 0.18 * scale), (x, y - 0.28 * scale, z), st["iron"]))
        parts.append(
            box(
                (0.14 * scale, 0.50 * scale, 0.14 * scale),
                (x, y - 0.26 * scale, z - 0.22 * scale),
                st["iron"],
                rot=(0.68, 0.0, 0.0),
            )
        )
        bowl_z = bz + 0.08 * scale

    parts.append(cyl(0.24 * scale, 0.28 * scale, (bx, by, bowl_z), st["iron"], verts=8, r2=0.38 * scale))
    parts.append(cyl(0.40 * scale, 0.10 * scale, (bx, by, bowl_z + 0.24 * scale), st["boss"], verts=8, r2=0.41 * scale))
    for k in range(3):
        ang = 2 * math.pi * k / 3 + 0.5
        rx = bx + math.cos(ang) * 0.34 * scale
        ry = by + math.sin(ang) * 0.34 * scale
        parts.append(box((0.08 * scale, 0.08 * scale, 0.30 * scale), (rx, ry, bowl_z + 0.20 * scale), st["iron"]))
    parts.append(cyl(0.25 * scale, 0.52 * scale, (bx, by, bowl_z + 0.32 * scale), st["sconceGlow"], verts=6, r2=0.0))
    parts.append(
        cyl(0.13 * scale, 0.36 * scale, (bx, by - 0.02 * scale, bowl_z + 0.38 * scale), st["flameCore"], verts=5, r2=0.0)
    )
    return parts


def banner(x, y, z_top, w, h, st):
    return [
        cyl_axis(0.08, w + 0.48, (x, y - 0.06, z_top), st["iron"], axis="x", verts=8),
        cyl(0.11, 0.20, (x - w / 2 - 0.24, y - 0.06, z_top - 0.10), st["boss"], verts=6, r2=0.04),
        cyl(0.11, 0.20, (x + w / 2 + 0.24, y - 0.06, z_top - 0.10), st["boss"], verts=6, r2=0.04),
        box((w, 0.10, h), (x, y - 0.09, z_top - h / 2 - 0.08), st["banner"]),
        box((w * 1.03, 0.12, 0.24), (x, y - 0.11, z_top - h - 0.06), st["bannerTrim"]),
        box((0.52, 0.13, 0.52), (x, y - 0.13, z_top - h * 0.42), st["bannerTrim"], rot=(0, math.pi / 4, 0)),
    ]


def arrow_slit(x, y, z, h, st, rot_z=0.0, cross=True):
    """Seteira recuada em esconso com ombreiras inclinadas, fenda cruciforme 'ink' e lintel chanfrado."""
    parts = [
        box(
            (0.20, 0.22, h + 0.12),
            _pt_rot(x, y, z, -0.24, -0.05, 0.0, rot_z),
            st["wallAlt"],
            rot=(0, 0, rot_z + 0.22),
        ),
        box(
            (0.20, 0.22, h + 0.12),
            _pt_rot(x, y, z, 0.24, -0.05, 0.0, rot_z),
            st["wallAlt"],
            rot=(0, 0, rot_z - 0.22),
        ),
        box((0.20, 0.16, h), _pt_rot(x, y, z, 0.0, -0.09, 0.0, rot_z), "ink", rot=(0, 0, rot_z)),
        box((0.74, 0.26, 0.18), _pt_rot(x, y, z, 0.0, -0.10, -h / 2 - 0.10, rot_z), st["relief"], rot=(0, 0, rot_z)),
        box((0.76, 0.28, 0.22), _pt_rot(x, y, z, 0.0, -0.10, h / 2 + 0.11, rot_z), st["relief"], rot=(0, 0, rot_z)),
    ]
    if cross:
        parts.append(box((0.52, 0.16, 0.18), _pt_rot(x, y, z, 0.0, -0.09, h * 0.14, rot_z), "ink", rot=(0, 0, rot_z)))
    return parts


def machicolation_row(x_center, y_face, z_top, span_total, n_bays, st):
    """Linha de cachorros escalonados com arcos de mata-caes e vaos 'ink' sob a cornija."""
    parts = []
    step = span_total / n_bays
    x0 = x_center - span_total * 0.5
    for k in range(n_bays + 1):
        kx = x0 + k * step
        parts.append(sloped_buttress(0.40, 0.42, 0.14, 0.46, kx, y_face, z_top - 0.86, st["trim"]))
        parts.append(sloped_buttress(0.46, 0.54, 0.20, 0.42, kx, y_face, z_top - 0.42, st["cornice"]))
    for k in range(n_bays):
        mx = x0 + (k + 0.5) * step
        parts.append(arch_rib(step - 0.22, 0.30, 0.34, 0.16, (mx, y_face - 0.28, z_top - 0.42), st["wallAlt"], segs=4))
        parts.append(box((step - 0.42, 0.36, 0.18), (mx, y_face - 0.20, z_top - 0.08), "ink"))
    return parts


def merlon_unit(x, y, z, w, d, h, st, rot_z=0.0, loophole=False, finial=False):
    """Ameia chanfrada com capeamento em cumeeira e seteira opcional."""
    parts = [
        taper_box(w, d, w * 0.88, d * 0.90, h, (x, y, z), st["wall"], rot_z=rot_z, bevel=0.04),
        gabled_cap(w * 1.04, d * 1.04, 0.16, 0.26, (x, y, z + h), st["cap"], rot_z=rot_z),
    ]
    if loophole:
        parts.append(box((0.18, d + 0.08, h * 0.52), (x, y, z + h * 0.52), "ink", rot=(0, 0, rot_z)))
        parts.append(box((0.40, d + 0.04, 0.14), (x, y, z + h * 0.80), st["relief"], rot=(0, 0, rot_z)))
    if finial:
        parts.append(cyl(0.14, 0.36, (x, y, z + h + 0.40), st["boss"], verts=6, r2=0.0))
    return parts


def flying_buttress_pier(x, y_wall, z_base, reach, h_pier, st, rot_z=0.0, lvl=1):
    """Contraforte externo com pinaculo e arcobotante curvo lancado contra a cortina."""
    parts = [
        sloped_buttress(0.92, 0.78, 0.28, h_pier + 0.55, x, y_wall, z_base, st["buttress"], rot_z=rot_z, bevel=0.04)
    ]
    px, py, _ = _pt_rot(x, y_wall, z_base, 0.0, -reach, 0.0, rot_z)
    pier_h = h_pier * 0.72
    parts.append(taper_box(0.84, 0.88, 0.72, 0.76, 1.05, (px, py, z_base), st["plinth"], rot_z=rot_z))
    parts.append(
        box((0.68, 0.72, pier_h), (px, py, z_base + 1.05 + pier_h * 0.5), st["buttress"], rot=(0, 0, rot_z), bevel=0.04)
    )
    pin_z = z_base + 1.05 + pier_h
    parts.append(gabled_cap(0.76, 0.80, 0.16, 0.44, (px, py, pin_z), st["cap"], rot_z=rot_z))

    parts.append(
        flyer_arch(
            -reach + 0.12,
            pin_z - 0.35,
            -0.25,
            z_base + h_pier + 0.15,
            0.40,
            0.28,
            0.46,
            (x, y_wall),
            st["wallAlt"],
            segs=4,
            rot_z=rot_z,
        )
    )
    mid_pt = _pt_rot(x, y_wall, 0.0, 0.0, -reach * 0.5, pin_z + 0.18, rot_z)
    parts.append(box((0.36, reach * 0.96, 0.20), mid_pt, st["trim"], rot=(-0.48, 0.0, rot_z)))

    if lvl >= 3:
        parts.append(cyl(0.15, 0.56, (px, py, pin_z + 0.56), st["boss"], verts=5, r2=0.0))
    if lvl >= 4:
        parts.append(cyl(0.18, 0.42, (px, py, pin_z + 0.24), st["roofRib"], verts=5, r2=0.0))
    return parts


def windlass_drum(x, y, z, st):
    """Tambor de guincho com rodas dentadas, manivela e corrente descendente para o rastrilho."""
    parts = [
        box((0.16, 0.48, 0.72), (x - 0.54, y, z), st["iron"]),
        box((0.16, 0.48, 0.72), (x + 0.54, y, z), st["iron"]),
        cyl_axis(0.24, 1.00, (x, y, z), "woodDark", axis="x", verts=8),
        cyl_axis(0.38, 0.14, (x - 0.40, y, z), st["boss"], axis="x", verts=8),
        cyl_axis(0.38, 0.14, (x + 0.40, y, z), st["boss"], axis="x", verts=8),
    ]
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.35
        parts.append(
            box(
                (0.12, 0.12, 0.14),
                (x + 0.40, y + 0.38 * math.cos(a), z + 0.38 * math.sin(a)),
                st["iron"],
                rot=(a, 0.0, 0.0),
            )
        )
    for k in range(3):
        cz = z - 0.34 - k * 0.32
        rot = (0.0, math.pi / 2, 0.0) if k % 2 == 0 else (0.0, 0.0, 0.0)
        parts.append(torus(0.12, 0.04, (x, y, cz), st["iron"], major_seg=6, minor_seg=4, rot=rot))
    return parts


# ---------------------------------------------------------------- modulos
def build_segment(side, lvl):
    st = TIER_STYLE[lvl]
    a, b = SEG_A, SEG_B
    length = b - a
    cx = side * (a + b) / 2
    parts = []

    # 1. Base em talude com fundacao em silhares escalonados + musgo
    parts.append(taper_box(length + 0.18, 4.10, length + 0.04, 2.75, 1.70, (cx, 0.0, 0.0), st["plinth"]))
    parts.append(box((length + 0.06, 2.86, 0.24), (cx, 0.0, 1.70), st["trim"], bevel=0.04))
    for kx in (-5.2, -3.2, -1.2, 1.2, 3.2, 5.2):
        parts.append(ashlar_block(1.60, 0.42, 0.62, (cx + side * kx, -1.74, 0.42), st["plinth"], taper=0.05))
    parts.append(box((1.22, 0.48, 0.38), (cx + side * 3.1, -1.78, 0.90), "moss"))
    parts.append(box((1.05, 0.42, 0.34), (cx - side * 4.2, -1.76, 0.88), "moss"))

    # 2. Corpo da cortina chanfrado
    wall_h = 6.25 if lvl != 4 else 6.45
    wall_d = 2.45
    parts.append(box((length, wall_d, wall_h), (cx, 0.0, 1.70 + wall_h / 2), st["wall"], bevel=0.04))

    # 3. 3 arcobotantes frontais (-Y) dentro do envelope de 3.95 studs
    for frac in (-0.34, 0.0, 0.34):
        bx = cx + frac * length
        parts += flying_buttress_pier(bx, -wall_d / 2, 1.70, 1.66, wall_h - 0.85, st, rot_z=0.0, lvl=lvl)

    # 4. Fiadas de alvenaria em silhares (frontais + traseiras) e seteiras recuadas
    parts.append(box((length - 0.08, 0.30, 0.32), (cx, -wall_d / 2 - 0.12, 4.65), st["trim"], bevel=0.04))
    bay_centers = (-length * 0.17, length * 0.17)
    outer_bays = (-length * 0.44, length * 0.44)

    for row_z, xs in (
        (2.40, (-5.6, -3.2, -1.3, 1.3, 3.2, 5.6)),
        (3.25, (-5.2, -2.6, -1.1, 1.1, 2.6, 5.2)),
        (4.05, (-5.7, -3.1, -1.4, 1.4, 3.1, 5.7)),
    ):
        for idx_k, kx in enumerate(xs):
            col = st["relief"] if idx_k % 2 == 0 else st["wallAlt"]
            parts.append(ashlar_block(1.38, 0.24, 0.56, (cx + kx, -wall_d / 2 - 0.08, row_z), col))

    for row_z, xs in (
        (2.65, (-4.8, -1.8, 1.8, 4.8)),
        (3.85, (-3.6, 0.0, 3.6)),
    ):
        for kx in xs:
            parts.append(
                ashlar_block(1.52, 0.22, 0.54, (cx + kx, wall_d / 2 + 0.08, row_z), st["wallAlt"], rot_z=math.pi)
            )

    for bx_off in bay_centers:
        parts += arrow_slit(cx + bx_off, -wall_d / 2, 5.75, 1.25, st, cross=(lvl >= 2))

    # Progressao L1 (madeira) -> L2 (silhares completos) -> L3 (bronze/ouro) -> L4 (arcano) -> L5 (ouro real)
    if lvl == 1:
        for kx in (-5.7, -2.9, -1.6, 1.6, 2.9, 5.7):
            parts.append(box((0.26, 0.22, 1.65), (cx + kx, -wall_d / 2 - 0.12, 5.75), st["trim"]))
    else:
        for row_z, xs in (
            (5.45, (-5.7, -3.5, -1.1, 1.1, 3.5, 5.7)),
            (6.45, (-5.4, -3.2, -1.3, 1.3, 3.2, 5.4)),
        ):
            for idx_k, kx in enumerate(xs):
                col = st["wallAlt"] if idx_k % 2 == 0 else st["relief"]
                parts.append(ashlar_block(1.22, 0.24, 0.54, (cx + kx, -wall_d / 2 - 0.08, row_z), col))

    if lvl >= 3:
        parts.append(box((length - 0.24, 0.24, 0.22), (cx, -wall_d / 2 - 0.14, 7.15), st["boss"]))
        for kx in (-3.6, 3.6):
            parts.append(
                box((0.34, 0.24, 0.34), (cx + kx, -wall_d / 2 - 0.16, 4.65), st["boss"], rot=(0, math.pi / 4, 0))
            )
    if lvl >= 4:
        for kx in (-length * 0.34, 0.0, length * 0.34):
            parts.append(box((0.30, 0.22, 1.15), (cx + kx, -wall_d / 2 - 0.18, 3.40), st["slitGlow"]))
    if lvl >= 5:
        parts.append(box((length - 0.30, 0.22, 0.18), (cx, -wall_d / 2 - 0.16, 2.02), st["boss"]))

    # 5. Cornija saliente + cachorros com arcos de mata-caes + 4 ameias com cumeeira
    walk_z = 1.70 + wall_h
    parts += machicolation_row(cx, -wall_d / 2, walk_z, length - 0.60, 6, st)
    parts.append(box((length + 0.12, 3.08, 0.46), (cx, -0.10, walk_z + 0.23), st["cornice"], bevel=0.04))

    m = 4
    for j in range(m):
        mx = side * (a + (j + 0.5) * length / m)
        parts += merlon_unit(
            mx,
            -1.05,
            walk_z + 0.46,
            1.44,
            0.94,
            1.22,
            st,
            loophole=(j in (0, 3)),
            finial=(lvl >= 5),
        )

    # 6. Escudos heraldicos + Braseiros de ferro na muralha
    for kx in bay_centers:
        parts += shield_crest(cx + kx, -wall_d / 2 - 0.20, walk_z - 1.05, 0.54, st)
    for kx in outer_bays:
        parts += sconce(cx + kx, -wall_d / 2 - 0.08, 5.20, st, scale=0.72)

    # 7. Passadico traseiro (rear catwalk) com maos-francesas, arcos de suporte, montantes e cunhais
    cat_z = walk_z - 1.05
    parts.append(box((length - 0.1, 1.45, 0.30), (cx, wall_d / 2 + 0.72, cat_z), st["trim"], bevel=0.03))
    parts.append(box((length - 0.1, 0.24, 0.78), (cx, wall_d / 2 + 1.38, cat_z + 0.52), st["wallAlt"], bevel=0.03))
    for kx in (-length * 0.34, 0.0, length * 0.34):
        parts.append(
            box((0.30, 1.32, 0.30), (cx + kx, wall_d / 2 + 0.55, cat_z - 0.55), st["trim"], rot=(0.68, 0, 0))
        )
        parts.append(box((0.28, 0.28, 1.05), (cx + kx, wall_d / 2 + 1.38, cat_z + 0.65), st["cap"]))
    for kx in (-length * 0.17, length * 0.17):
        parts.append(
            arch_rib(length * 0.30, 0.45, 0.28, 0.16, (cx + kx, wall_d / 2 + 0.65, cat_z - 0.62), st["buttress"], segs=4)
        )
    for qz in (2.30, 4.10):
        for sx in (-1, 1):
            parts.append(ashlar_block(0.85, 0.22, 0.56, (cx + sx * (length * 0.47), -wall_d / 2 - 0.06, qz), st["plinth"]))

    return parts


def build_tower(side, lvl):
    st = TIER_STYLE[lvl]
    x = side * TOWER_X
    r = TOWER_R + (0.28 if lvl == 4 else 0.0)
    parts = []

    # 1. Talus octogonal escalonado + base cilindrica suave (verts=24) + corpo da torre
    parts.append(cyl(r + 1.12, 0.85, (x, 0, 0.0), st["plinth"], verts=8, rot_z=math.pi / 8))
    parts.append(cyl(r + 1.06, 1.55, (x, 0, 0.80), st["plinth"], verts=24, r2=r + 0.10))
    parts.append(cyl(r, 8.75, (x, 0, 2.35), st["wall"], verts=24))
    parts.append(cyl(r + 0.24, 0.36, (x, 0, 2.20), st["trim"], verts=8, rot_z=math.pi / 8))

    # 2. 4 nervuras de contraforte chanfradas (-Y, +X, -X, +Y) + pinaculos
    for ang in (-math.pi / 2, 0.0, math.pi, math.pi / 2):
        rot_z = ang + math.pi / 2
        px = x + (r - 0.12) * math.cos(ang)
        py = (r - 0.12) * math.sin(ang)
        parts.append(
            sloped_buttress(0.74, 0.76, 0.34, 8.40, px, py, 2.15, st["buttress"], rot_z=rot_z, bevel=0.04)
        )
        parts.append(
            gabled_cap(
                0.68, 0.44, 0.12, 0.32, (x + (r + 0.12) * math.cos(ang), (r + 0.12) * math.sin(ang), 10.50), st["cap"], rot_z=rot_z
            )
        )

    # 3. Frisos horizontais + fiadas radiais de silhares chanfrados ao redor da torre
    parts.append(cyl(r + 0.18, 0.32, (x, 0, 5.65), st["trim"], verts=24))
    parts.append(cyl(r + 0.14, 0.26, (x, 0, 3.85), st["wallAlt"], verts=24))
    if lvl >= 3:
        parts.append(cyl(r + 0.18, 0.24, (x, 0, 8.85), st["boss"], verts=12))

    course_z = (2.95, 4.45, 6.25, 8.20, 9.55)
    for c_idx, z_q in enumerate(course_z):
        for q_i in range(4):
            base_ang = -math.pi / 2 + q_i * (math.pi / 2)
            for sub in (0.28, 0.68):
                ang_q = base_ang + sub * (math.pi / 2) + (0.08 if c_idx % 2 == 1 else -0.08)
                if 6.1 <= z_q <= 8.3 and abs(math.sin(ang_q + math.pi / 2)) > 0.75 and math.sin(ang_q) < -0.5:
                    continue
                qx = x + (r + 0.02) * math.cos(ang_q)
                qy = (r + 0.02) * math.sin(ang_q)
                col = st["relief"] if (c_idx + q_i) % 2 == 0 else st["wallAlt"]
                parts.append(ashlar_block(0.86, 0.22, 0.50, (qx, qy, z_q), col, rot_z=ang_q + math.pi / 2))
    if lvl >= 2:
        for q_i in range(4):
            ang_q = -math.pi / 2 + (q_i + 0.5) * (math.pi / 2)
            qx = x + (r + 0.02) * math.cos(ang_q)
            qy = (r + 0.02) * math.sin(ang_q)
            parts.append(ashlar_block(0.90, 0.22, 0.50, (qx, qy, 5.15), st["relief"], rot_z=ang_q + math.pi / 2))

    # 4. Seteiras recuadas em esconso nas faces frontais laterais (-Y +- pi/5) e flanco externo
    for ang_off in (-math.pi / 5, math.pi / 5, side * math.pi / 2.25):
        ang = -math.pi / 2 + ang_off
        sx = x + (r - 0.04) * math.cos(ang)
        sy = (r - 0.04) * math.sin(ang)
        parts += arrow_slit(sx, sy, 7.30, 1.30, st, rot_z=ang + math.pi / 2, cross=(lvl >= 2))

    # 5. Galeria de mata-caes com anel de cachorros + arcos entre cachorros
    gal_z = 11.10
    parts.append(cyl(r + 0.06, 0.56, (x, 0, gal_z - 0.56), st["trim"], verts=24, r2=r + 0.44))
    n_corb = 6
    for k in range(n_corb):
        ang = -math.pi / 2 + 2 * math.pi * k / n_corb
        rot_z = ang + math.pi / 2
        cxk = x + (r - 0.05) * math.cos(ang)
        cyk = (r - 0.05) * math.sin(ang)
        parts.append(sloped_buttress(0.40, 0.62, 0.16, 0.68, cxk, cyk, gal_z - 0.68, st["trim"], rot_z=rot_z))
        ang_mid = ang + math.pi / n_corb
        amx = x + (r + 0.22) * math.cos(ang_mid)
        amy = (r + 0.22) * math.sin(ang_mid)
        chord = 2 * (r + 0.22) * math.sin(math.pi / n_corb) - 0.28
        parts.append(
            arch_rib(chord, 0.28, 0.30, 0.14, (amx, amy, gal_z - 0.34), st["wallAlt"], segs=4, rot_z=ang_mid + math.pi / 2)
        )

    parts.append(cyl(r + 0.20, 0.92, (x, 0, gal_z), st["cornice"], verts=24, r2=r + 0.68))

    # 6. 6 ameias chanfradas com capeamento em cumeeira na galeria
    for k in range(n_corb):
        ang = -math.pi / 2 + 2 * math.pi * k / n_corb
        mx = x + (r + 0.50) * math.cos(ang)
        my = (r + 0.50) * math.sin(ang)
        parts += merlon_unit(
            mx,
            my,
            gal_z + 0.92,
            1.14,
            0.64,
            1.08,
            st,
            rot_z=ang + math.pi / 2,
            loophole=(k % 2 == 0),
            finial=(lvl >= 5),
        )

    # 7. Telhado conico suave (verts=24) + nervuras + lucarna frontal + flecha conica
    roof_z = gal_z + 1.00
    roof_r = r + 0.90
    roof_h = 4.65
    parts.append(cyl(roof_r, roof_h, (x, 0, roof_z), st["roof"], verts=24, r2=0.0))
    parts.append(cyl(roof_r + 0.06, 0.22, (x, 0, roof_z), st["trim"], verts=24, r2=roof_r - 0.08))

    peak = Vector((x, 0.0, roof_z + roof_h))
    for k in range(n_corb):
        ang = -math.pi / 2 + 2 * math.pi * k / n_corb
        eave = Vector((x + roof_r * math.cos(ang), roof_r * math.sin(ang), roof_z + 0.06))
        mid = (eave + peak) * 0.5
        dvec = peak - eave
        rot_eul = dvec.normalized().to_track_quat("Z", "Y").to_euler("XYZ")
        parts.append(box((0.18, 0.20, dvec.length * 0.96), tuple(mid), st["roofRib"], rot=tuple(rot_eul)))

    parts.append(taper_box(1.12, 1.15, 0.20, 1.15, 1.35, (x, -r * 0.72, roof_z + 0.85), st["roofRib"]))
    parts.append(box((0.32, 0.16, 0.62), (x, -r * 0.72 - 0.56, roof_z + 1.25), "ink"))
    parts.append(box((0.52, 0.20, 0.14), (x, -r * 0.72 - 0.56, roof_z + 0.92), st["cap"]))

    spire_z = roof_z + roof_h - 0.15
    parts.append(cyl(0.36, 1.20, (x, 0, spire_z), st["trim"], verts=24, r2=0.0))
    parts.append(box((1.35, 0.08, 0.72), (x + side * 0.68, 0, spire_z + 1.10), st["banner"]))
    if lvl >= 3:
        parts.append(torus(0.46, 0.08, (x, 0, spire_z + 0.20), st["boss"], major_seg=8, minor_seg=4))
    if lvl >= 4:
        for k in range(4):
            ang = math.pi * k / 2 + math.pi / 4
            parts.append(
                cyl(
                    0.16,
                    0.72,
                    (x + (r + 0.25) * math.cos(ang), (r + 0.25) * math.sin(ang), roof_z + 0.45),
                    st["boss"],
                    verts=5,
                    r2=0.0,
                )
            )
            parts.append(
                box(
                    (0.24, 0.22, 1.25),
                    (x + (r + 0.08) * math.cos(ang - math.pi / 4), (r + 0.08) * math.sin(ang - math.pi / 4), 4.85),
                    st["slitGlow"],
                    rot=(0, 0, ang - math.pi / 4),
                )
            )
    if lvl >= 5:
        parts.append(ball(0.24, (x, 0, spire_z + 1.35), st["flameCore"], seg=6, rings=3))

    # 8. Estandarte heraldico frontal + escudo na galeria da torre
    parts += banner(x, -r - 0.38, 10.05, 1.35, 2.75, st)
    parts += shield_crest(x, -r - 0.62, gal_z + 0.45, 0.52, st)

    return parts


def build_gate(lvl):
    st = TIER_STYLE[lvl]
    parts = []
    hw = GATE_W / 2  # 5.9
    arch_r = 3.05
    spring_z = 4.45
    arch_top = spring_z + arch_r + 0.35  # 7.85

    # 1. Contrafortes/torreoes avancados chanfrados dos flancos da portaria (-Y)
    pier_w = hw - arch_r  # 2.85
    for sx in (-1, 1):
        px = sx * (arch_r + pier_w / 2)
        parts.append(
            taper_box(
                pier_w + 0.35, GATE_D + 1.50, pier_w + 0.06, GATE_D + 0.85, 1.85, (px, -0.35, 0.0), st["plinth"]
            )
        )
        parts.append(
            box(
                (pier_w, GATE_D + 0.85, GATE_H - 1.85),
                (px, -0.35, 1.85 + (GATE_H - 1.85) / 2),
                st["gatePier"],
                bevel=0.04,
            )
        )
        parts.append(box((pier_w + 0.26, GATE_D + 1.06, 0.34), (px, -0.35, 5.20), st["trim"], bevel=0.04))

        # Arcobotante nos flancos externos dentro de |Y| <= 3.85 (livre do braseiro em x=+-4.9)
        parts += flying_buttress_pier(
            sx * 5.54, -GATE_D / 2 - 0.55, 1.85, 0.90, 5.45, st, rot_z=0.0, lvl=lvl
        )

        # Fiadas de silhares nos flancos
        for qz_idx, qz in enumerate((2.50, 3.45, 4.45, 6.05, 8.20)):
            qx = px + sx * (pier_w * 0.34 if qz_idx % 2 == 0 else -pier_w * 0.28)
            parts.append(ashlar_block(0.86, 0.24, 0.54, (qx, -GATE_D / 2 - 0.78, qz), st["relief"]))
            if lvl >= 2 and qz_idx < 2:
                parts.append(
                    ashlar_block(0.72, 0.22, 0.48, (px - sx * 0.42, -GATE_D / 2 - 0.78, qz), st["wallAlt"])
                )

        # Frades/balizadores de pedra na entrada do arco + contraventamento do rastrilho
        parts.append(taper_box(0.54, 0.54, 0.38, 0.38, 1.05, (sx * (arch_r - 0.16), -GATE_D / 2 + 0.24, 0.0), st["plinth"]))
        parts.append(box((0.95, 0.16, 0.16), (sx * 1.95, -1.18, 5.45), st["iron"], rot=(0, sx * 0.65, 0)))

        # Seteiras recuadas nos torreoes + escudos heraldicos
        parts += arrow_slit(px - sx * 0.58, -GATE_D / 2 - 0.74, 3.55, 1.15, st, cross=(lvl >= 2))
        parts += shield_crest(px - sx * 0.35, -GATE_D / 2 - 0.84, 7.25, 0.52, st)

        # Coluneta de ombreira do arco + capitel (imposta)
        jamb_x = sx * (arch_r + 0.16)
        parts.append(cyl(0.24, spring_z - 0.30, (jamb_x, -GATE_D / 2 - 0.10, 0.15), st["wallAlt"], verts=10))
        parts.append(box((0.68, 0.68, 0.34), (jamb_x, -GATE_D / 2 - 0.10, spring_z - 0.10), st["trim"], bevel=0.04))

    # 2. Timpano suave do arco (segs=16) + parede superior
    parts.append(arch_spandrel(arch_r * 2, arch_r, spring_z, arch_top, GATE_D, 0.0, st["wall"], segs=16))
    parts.append(
        box((arch_r * 2, GATE_D, GATE_H - arch_top), (0.0, 0.0, arch_top + (GATE_H - arch_top) / 2), st["wall"])
    )

    # 3. Arco em pedra de multiplas ordens: ordem interna recuada + ordem externa chanfrada + guarda-po
    n_inner = 9
    for k in range(n_inner):
        ang = 0.12 + (math.pi - 0.24) * k / (n_inner - 1)
        vr = arch_r - 0.02
        vx = vr * math.cos(ang)
        vz = spring_z + vr * math.sin(ang)
        col = st["wallAlt"] if k % 2 == 0 else st["gatePier"]
        parts.append(box((0.84, 0.50, 0.52), (vx, -GATE_D / 2 + 0.12, vz), col, rot=(0, -ang + math.pi / 2, 0)))

    n_outer = 9
    for k in range(n_outer):
        ang = 0.14 + (math.pi - 0.28) * k / (n_outer - 1)
        is_key = k == n_outer // 2
        vr = arch_r + (0.42 if is_key else 0.34)
        vx = vr * math.cos(ang)
        vz = spring_z + vr * math.sin(ang)
        col = st["trim"] if is_key else (st["archRing"] if k % 2 == 0 else st["wallAlt"])
        vw = 1.08 if is_key else 0.92
        vh = 0.88 if is_key else 0.66
        vd = 0.64 if is_key else 0.52
        parts.append(
            box((vw, vd, vh), (vx, -GATE_D / 2 - 0.18, vz), col, bevel=0.04, rot=(0, -ang + math.pi / 2, 0))
        )
        if lvl >= 3 and k in (2, 6):
            parts.append(ashlar_block(0.24, 0.16, 0.24, (vx, -GATE_D / 2 - 0.48, vz), st["boss"]))

    for k in range(7):
        ang = 0.18 + (math.pi - 0.36) * k / 6
        hr = arch_r + 0.80
        parts.append(
            box(
                (1.18, 0.30, 0.22),
                (hr * math.cos(ang), -GATE_D / 2 - 0.16, spring_z + hr * math.sin(ang)),
                st["trim"],
                rot=(0, -ang + math.pi / 2, 0),
            )
        )

    # Brasao esculpido da Ordem Ambar acima da pedra-chave central
    parts.append(
        box((1.56, 0.30, 1.56), (0.0, -GATE_D / 2 - 0.28, 8.76), st["trim"], bevel=0.04, rot=(0, math.pi / 4, 0))
    )
    parts += shield_crest(0.0, -GATE_D / 2 - 0.40, 8.76, 0.64, st, boss_col="amberBright")

    # Tambores de guincho com correntes visiveis flanqueando o brasao central
    for sx in (-1, 1):
        parts += windlass_drum(sx * 2.05, -GATE_D / 2 - 0.28, 8.70, st)

    # 4. Portao duplo em carvalho com 8 tabuas chanfradas, cintas de ferro, cravos e aldravas
    parts.append(box((arch_r * 2, 0.42, arch_top - 0.1), (0.0, 0.42, (arch_top - 0.1) / 2), "woodDark"))
    parts.append(box((0.30, 0.56, arch_top - 0.4), (0.0, 0.32, (arch_top - 0.4) / 2), "wood"))
    plank_xs = (-2.36, -1.68, -1.00, -0.34, 0.34, 1.00, 1.68, 2.36)
    for idx_p, px in enumerate(plank_xs):
        h_plank = spring_z + math.sqrt(max(0.0, arch_r**2 - px**2)) - 0.28
        col = "woodLight" if idx_p % 2 == 0 else "wood"
        parts.append(ashlar_block(0.62, 0.18, h_plank, (px, 0.18, h_plank / 2), col, taper=0.03))
    for sx in (-1, 1):
        parts.append(box((2.15, 0.18, 0.24), (sx * 1.42, 0.14, 2.25), "woodDark", rot=(0, sx * 0.46, 0)))
        parts.append(ashlar_block(0.40, 0.12, 0.44, (sx * 0.72, 0.04, 2.55), st["boss"]))
        parts.append(
            torus(0.20, 0.055, (sx * 0.72, -0.04, 2.35), st["iron"], major_seg=8, minor_seg=4, rot=(math.pi / 2, 0, 0))
        )

    for z in (1.15, 2.75, 4.15):
        span_w = arch_r * (1.92 if z < 3.5 else 1.72)
        parts.append(box((span_w, 0.20, 0.30), (0.0, 0.10, z), st["iron"]))
        stud_xs = (-2.45, -1.65, -0.85, 0.85, 1.65, 2.45) if z < 3.5 else (-2.05, -1.15, 1.15, 2.05)
        for hx in stud_xs:
            parts.append(ashlar_block(0.20, 0.14, 0.20, (hx, -0.02, z), st["boss"]))

    # 5. Grade de rastrilho (portcullis) com 7 barras, pontas forjadas e rebites
    port_y = -1.18
    bar_xs = (-2.4, -1.6, -0.8, 0.0, 0.8, 1.6, 2.4)
    for px in bar_xs:
        top_z = spring_z + math.sqrt(max(0.0, (arch_r - 0.08) ** 2 - px**2)) - 0.12
        bar_h = top_z - 0.62
        parts.append(cyl(0.10, bar_h, (px, port_y, 0.62), st["iron"], verts=6))
        parts.append(cyl(0.15, 0.48, (px, port_y, 0.14), st["iron"], verts=6, r2=0.0, rot_x=math.pi))
        parts.append(box((0.26, 0.26, 0.14), (px, port_y, 0.64), st["boss"]))

    for z in (1.95, 3.85):
        parts.append(cyl_axis(0.11, 5.45, (0.0, port_y, z), st["iron"], axis="x", verts=6))
        for px in bar_xs:
            parts.append(box((0.26, 0.26, 0.26), (px, port_y, z), st["trim"]))
            parts.append(ashlar_block(0.18, 0.14, 0.18, (px, port_y - 0.12, z), st["boss"]))

    # 6. Camara de Alavancas superior em balanco (-Y) com cachorros com arcos + 3 fendas + ameias
    cam_z = GATE_H
    cam_w, cam_d, cam_h = GATE_W + 0.65, GATE_D + 1.35, 2.25
    parts += machicolation_row(0.0, -GATE_D / 2, cam_z, GATE_W - 0.80, 5, st)

    parts.append(box((cam_w, cam_d, cam_h), (0.0, -0.45, cam_z + cam_h / 2), st["wallAlt"], bevel=0.04))
    for kx in (-5.6, -2.1, 2.1, 5.6):
        parts.append(
            box((0.38, 0.28, cam_h + 0.1), (kx, -0.45 - cam_d / 2 - 0.08, cam_z + cam_h / 2), st["trim"])
        )
    parts.append(
        box((cam_w + 0.48, cam_d + 0.42, 0.38), (0.0, -0.45, cam_z + cam_h + 0.19), st["cornice"], bevel=0.04)
    )

    parts.append(box((8.8, 0.16, 0.88), (0.0, -0.45 - cam_d / 2 - 0.04, cam_z + 1.15), "ink"))
    for sx in (-3.8, 0.0, 3.8):
        parts.append(box((0.68, 0.20, 0.56), (sx, -0.45 - cam_d / 2 - 0.08, cam_z + 1.15), st["slitGlow"]))
        parts.append(box((0.92, 0.24, 0.16), (sx, -0.45 - cam_d / 2 - 0.08, cam_z + 1.54), st["relief"]))

    # Soleira chanfrada da entrada + verga interna do rastrilho
    parts.append(box((arch_r * 2.1, 0.95, 0.14), (0.0, -0.35, 0.07), st["plinth"], bevel=0.03))
    parts.append(box((arch_r * 1.9, 0.34, 0.28), (0.0, -1.18, 6.20), st["trim"], bevel=0.03))

    top_base = cam_z + cam_h + 0.38
    for mx in (-4.8, -2.4, 2.4, 4.8):
        parts += merlon_unit(
            mx,
            -0.45 - cam_d / 2 + 0.44,
            top_base,
            1.34,
            0.90,
            1.15,
            st,
            loophole=(abs(mx) > 4.0),
            finial=(lvl >= 3 and abs(mx) > 4.0),
        )
    parts.append(taper_box(5.8, cam_d + 0.2, 2.2, 0.55, 2.15, (0.0, -0.45, top_base), st["roof"]))
    parts.append(cyl(0.36, 1.10, (0.0, -0.45, top_base + 2.15), st["trim"], verts=24, r2=0.0))

    if lvl >= 3:
        for sx in (-1, 1):
            parts.append(cyl(0.22, 0.58, (sx * 5.65, -0.45 - cam_d / 2 + 0.50, top_base), st["boss"], verts=6, r2=0.0))
    if lvl >= 4:
        for sx in (-1, 1):
            parts.append(cyl(0.24, 0.92, (sx * 2.85, -0.45 - cam_d / 2 + 0.35, top_base), st["roofRib"], verts=5, r2=0.0))
            parts.append(box((0.28, 0.22, 1.35), (sx * 4.80, -GATE_D / 2 - 0.86, 5.60), st["slitGlow"]))
            parts.append(cyl(0.18, 0.68, (sx * 1.15, -GATE_D / 2 - 0.34, 8.95), st["boss"], verts=5, r2=0.0))
    if lvl >= 5:
        for k in range(5):
            ang = 0.26 + (math.pi - 0.52) * k / 4
            parts.append(
                box(
                    (0.14, 0.14, 0.62),
                    (1.18 * math.cos(ang), -GATE_D / 2 - 0.32, 8.76 + 1.18 * math.sin(ang)),
                    st["boss"],
                    rot=(0, -ang + math.pi / 2, 0),
                )
            )
        parts.append(ball(0.28, (0.0, -0.45, top_base + 3.40), st["flameCore"], seg=6, rings=3))
        for sx in (-1, 1):
            parts.append(box((0.26, 0.26, 0.26), (sx * 3.60, -GATE_D / 2 - 0.84, 5.20), st["boss"], rot=(0, math.pi / 4, 0)))

    # 7. Braseiros de ferro forjado na face frontal dos flancos (alinhados com ArenaVisual WallTorchFxL/R)
    for sx in (-4.9, 4.9):
        parts += sconce(sx, -GATE_D / 2 - 0.78, 4.4, st, tripod=False, scale=1.0)

    return parts


# ---------------------------------------------------------------- lote Forge3D
def write_lote(levels):
    lines = [
        "# Forge3D 0.9.0 — rota `import`: muralha modelada por script (art/scripts/make_wall_bastion.py)",
        "# entra no mesmo QC (escala, pivo, LOD, colisao, manifesto, indice, Gate G11). Saida no sandbox.",
        "#   forge3d run art/forge/lote_muralha_import.yaml --json   (ou: bash tools/art-pipeline.sh --only wall)",
        "# GERADO pelo script: altura_metros = altura medida em studs x 0,28 (perfil roblox-aa-80).",
        "schema: forge3d/spec@6",
        "",
        "projeto: muralha",
        "perfil: roblox-aa-80",
        "destino_exportacao: ~/.local/state/forge3d/saida/muralha_import",
        "estilo_global: stylized_pbr",
        "",
        "orcamento_cena:",
        "  triangulos_max: 400000",
        "  draw_calls_max: 400",
        "  vram_mb_max: 200",
        "",
        "roblox_render:",
        "  lighting_technology: Future",
        "  render_fidelity_padrao: Precise",
        "  surface_appearance: true",
        "  strip_embedded_textures_glb: true",
        "",
        "politica:",
        "  falha: continuar",
        "  custo_max_min: 30",
        "  seed_base: 20261113",
        "",
        "lote:",
    ]
    det = DEFAULT_DETALHE_ALTO
    for lvl, (_coll, mods) in levels.items():
        top = max((o.matrix_world @ v.co).z for _, o in mods for v in o.data.vertices)
        h = round(top, 4)
        pal_colors = extract_pal_colors(mods, max_colors=16)
        zonas = build_pbr_zonas(pal_colors, max_zones=16)
        lines += [
            f"  - id: wall.bastion.l{lvl}.01",
            "    tipo: modulo_cenario",
            "    rota: import",
            f"    origem: art/export/wall_bastion_l{lvl}.glb",
            f"    altura_metros: {round(h * METROS_POR_STUD, 4)}   # {h} studs",
            "    pivot: base",
            f"    limite_triangulos: {LIMITE_LOTE[lvl]}",
            "    material: pbr",
            "    qualidade: ultra",
            f"    quantidade_cena: {1 if lvl == 5 else 0}",
            "    render_fidelity_roblox: Precise",
            "    detalhe_alto:",
            f"      ativo: {'true' if det.get('ativo', True) else 'false'}",
            f"      subdiv_niveis: {int(det.get('subdiv_niveis', 0))}",
            f"      chanfro_bevel_m: {float(det.get('chanfro_bevel_m', 0.008))}",
            f"      crease_angulo_graus: {int(det.get('crease_angulo_graus', 40))}",
            f"      ao_cavidade_forca: {float(det.get('ao_cavidade_forca', 0.42))}",
        ]
        lines += format_pbr_zonas_yaml(zonas, indent="    ")
        lines += [
            "    suavizacao_normais:",
            "      modo: hard_surface",
            "      angulo_graus: 46",
            "      weighted_normals: true",
            "      corrective_smooth: false",
            "    colisao: box",
            "    seed: 20261113",
            "    lod: [100]",
            f"    tags: [muralha, wall, bastion, l{lvl}]",
            "",
        ]
    path = os.path.join(ROOT, "art", "forge", "lote_muralha_import.yaml")
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines).rstrip() + "\n")


# ---------------------------------------------------------------- cena
def build_level(lvl):
    coll = bpy.data.collections.new(f"WALL_bastion_l{lvl}")
    bpy.context.scene.collection.children.link(coll)
    layer = bpy.context.view_layer.layer_collection.children[coll.name]
    bpy.context.view_layer.active_layer_collection = layer
    mods = []
    seed_base = 20261113 + lvl * 1000
    for idx, (side, tag) in enumerate(((-1, "l"), (1, "r"))):
        o = join(build_segment(side, lvl), f"WALL_bastion_segment{tag}_l{lvl}", seed_base + idx * 101)
        set_origin(o, side * (SEG_A + SEG_B) / 2)
        mods.append(("segment", o))
        t = join(build_tower(side, lvl), f"WALL_bastion_tower{tag}_l{lvl}", seed_base + 300 + idx * 101)
        set_origin(t, side * TOWER_X)
        mods.append(("tower", t))
    g = join(build_gate(lvl), f"WALL_bastion_gate_l{lvl}", seed_base + 600)
    set_origin(g, 0)
    mods.append(("gate", g))

    # Garante pivo Z >= 0 em todo o tier apos o jitter e coalescencia <=16 cores PBR
    min_z = min((o.matrix_world @ v.co).z for _, o in mods for v in o.data.vertices)
    for _, o in mods:
        for v in o.data.vertices:
            v.co.z -= min_z
        o.data.update()
    extract_pal_colors(mods, max_colors=16)

    return coll, mods


def setup_render():
    scene = bpy.context.scene
    bpy.context.view_layer.active_layer_collection = bpy.context.view_layer.layer_collection
    ground = box((140, 90, 0.4), (0, 10, -0.2), "grass")
    ground.name = "RENDER_ground"
    road = box((14, 30, 0.1), (0, -16, 0.02), "stoneLight")
    road.name = "RENDER_road"
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    cam.location = (30, -52, 26)
    cam.data.lens = 38
    target = bpy.data.objects.new("target", None)
    target.location = (0, 0, 5.5)
    scene.collection.objects.link(target)
    tc = cam.constraints.new("TRACK_TO")
    tc.target = target
    tc.track_axis = "TRACK_NEGATIVE_Z"
    tc.up_axis = "UP_Y"
    scene.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 4.0
    sun.data.angle = math.radians(6)
    sun.rotation_euler = (math.radians(52), 0, math.radians(-38))
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.62, 0.74, 0.92, 1)
    bg.inputs[1].default_value = 0.9
    scene.world = world
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    scene.eevee.taa_render_samples = 16
    return [ground, road]


def main():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)
    make_materials()
    report = []
    levels = {}
    failures = []
    totals = {}
    for lvl in LEVELS:
        coll, mods = build_level(lvl)
        levels[lvl] = (coll, mods)
        for kind, o in mods:
            n = tris(o)
            g1 = g1_check(o)
            ok_m = n <= BUDGET[kind] and g1["nao_manifold"] == 0 and g1["degeneradas"] == 0
            if not ok_m:
                failures.append(f"{o.name}:tris={n},g1={g1}")
            report.append(f"{o.name}: {n} tris (budget {BUDGET[kind]}) g1={g1}")
        total = sum(tris(o) for _, o in mods)
        totals[lvl] = total
        union_g1 = check_tier_union_g1(mods)
        min_z = min((o.matrix_world @ v.co).z for _, o in mods for v in o.data.vertices)
        max_x = max(abs((o.matrix_world @ v.co).x) for _, o in mods for v in o.data.vertices)
        max_y = max(abs((o.matrix_world @ v.co).y) for _, o in mods for v in o.data.vertices)
        if (
            total < 16000
            or total > TIER_TRIS_MAX
            or union_g1["nao_manifold"] != 0
            or union_g1["degeneradas"] != 0
            or min_z < -1e-6
        ):
            failures.append(f"L{lvl}:total={total},union_g1={union_g1},min_z={min_z}")
        report.append(
            f"L{lvl} total: {total}/{TIER_TRIS_MAX} tris union_g1={union_g1} "
            f"min_z={round(min_z, 5)} max_xy=({round(max_x, 3)}, {round(max_y, 3)})"
        )

    for a, b in zip(LEVELS, LEVELS[1:]):
        if not totals[a] < totals[b]:
            failures.append(f"monotonic:L{a}={totals[a]}>=L{b}={totals[b]}")

    os.makedirs(os.path.join(ROOT, "art", "export"), exist_ok=True)
    for lvl, (_coll, mods) in levels.items():
        bpy.ops.object.select_all(action="DESELECT")
        for _, o in mods:
            o.select_set(True)
        bpy.ops.export_scene.gltf(
            filepath=os.path.join(ROOT, "art", "export", f"wall_bastion_l{lvl}.glb"),
            export_format="GLB",
            use_selection=True,
            export_yup=True,
            export_apply=True,
        )

    write_lote(levels)
    if os.environ.get("FORGE_SKIP_RENDER") != "1":
        setup_render()
        renders = os.path.join(ROOT, "art", "renders")
        os.makedirs(renders, exist_ok=True)
        for lvl in LEVELS:
            for other, (coll, _) in levels.items():
                coll.hide_render = other != lvl
            bpy.context.scene.render.filepath = os.path.join(renders, f"wall_bastion_l{lvl}.png")
            bpy.ops.render.render(write_still=True)

        for lvl, (coll, _) in levels.items():
            coll.hide_render = False
            coll.hide_viewport = lvl != 1
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art", "src", "wall_bastion.blend"))
    print("WALL_REPORT\n" + "\n".join(report))
    if failures:
        raise SystemExit(f"[wall] reprovado localmente: {failures}")


main()
