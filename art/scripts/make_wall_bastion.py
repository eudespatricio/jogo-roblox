"""Gera a Muralha do Bastiao (WALL_) em 5 tiers visuais (L1..L5) com silhueta arquitetonica esculpida.

Modular: segmento (x2), portaria central e torre (x2) por tier, mantendo exatamente os vaos
canonicos (SEG_A=5.9, SEG_B=19.2, TOWER_X=22.0, TOWER_R=2.8, GATE_W=11.8, GATE_D=3.8, GATE_H=10.0),
frente = -Y no Blender (+Z glTF), Z-up e <= 5800 tris por tier GLB.

Usa a paleta unificada 512x512 de 64 cores (`lowpoly_lib.PAL` / `NAMES` / `make_palette`),
primitivas curvas de 24 lados (torres, telhados conicos, aneis de cachorros), blocos e contrafortes
chanfrados (`bevel=0.04` com `clamp_overlap`), aduelas esculpidas no arco, barras cilindricas no
rastrilho e escudos/brasoes arredondados.

Uso headless:
  blender -b --factory-startup --python-exit-code 1 --python art/scripts/make_wall_bastion.py
Saidas: art/src/wall_bastion.blend, art/export/wall_bastion_l{1..5}.glb,
        art/forge/lote_muralha_import.yaml (gerado, altura medida),
        art/renders/wall_bastion_l{1..5}.png (ignorado no git)
"""

from __future__ import annotations

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from lowpoly_lib import NAMES, PAL, make_palette  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LEVELS = (1, 2, 3, 4, 5)
TIER_TRIS_MAX = 5800
LIMITE_LOTE = {lvl: 6000 for lvl in LEVELS}
METROS_POR_STUD = 0.28  # perfil roblox-r15 do Forge3D
BUDGET = {"segment": 1350, "gate": 2500, "tower": 2400}

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
    i = NAMES.index(color)
    u, v = ((i % 8) + 0.5) / 8, ((i // 8) + 0.5) / 8
    uv = me.uv_layers.active.data
    # UV nao colapsada (QC G3 do Forge3D)
    for p in me.polygons:
        n = p.loop_total
        for k, li in enumerate(p.loop_indices):
            a = 2 * math.pi * k / n
            uv[li].uv = (u + 0.03 * math.cos(a), v + 0.03 * math.sin(a))
    me.materials.clear()
    me.materials.append(MAT)  # 1 material por mesh (QC G5)
    for p in me.polygons:
        p.material_index = 0
    return obj


# ---------------------------------------------------------------- primitivas
def _active():
    return bpy.context.view_layer.objects.active


def _finish(obj, color, bevel=0.0, bevel_segs=1):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    vs = obj.data.vertices
    if vs:
        dx = max(v.co.x for v in vs) - min(v.co.x for v in vs)
        dy = max(v.co.y for v in vs) - min(v.co.y for v in vs)
        dz = max(v.co.z for v in vs) - min(v.co.z for v in vs)
        min_dim = min(dx, dy, dz)
    else:
        min_dim = 0.0
    if bevel > 0 and min_dim > 0.08:
        mod = obj.modifiers.new("bv", "BEVEL")
        mod.width = min(bevel, min_dim * 0.26)
        mod.segments = bevel_segs
        mod.limit_method = "ANGLE"
        mod.angle_limit = math.radians(30)
        mod.use_clamp_overlap = True
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
        bmesh.ops.dissolve_degenerate(bm, dist=5e-5, edges=bm.edges)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(obj.data)
        bm.free()
        obj.data.update()
    return paint(obj, color)


def box(size, center, color, bevel=0.0, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center, rotation=rot)
    o = _active()
    o.scale = size
    return _finish(o, color, bevel)


def cyl(r, h, base, color, verts=24, r2=None, rot_z=0.0, bevel=0.0):
    loc = (base[0], base[1], base[2] + h / 2)
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=verts, radius=r, depth=h, location=loc, rotation=(0, 0, rot_z)
        )
    else:
        bpy.ops.mesh.primitive_cone_add(
            vertices=verts, radius1=r, radius2=r2, depth=h, location=loc, rotation=(0, 0, rot_z)
        )
    return _finish(_active(), color, bevel)


def cyl_axis(r, length, center, color, axis="x", verts=16):
    rot = (0, math.pi / 2, 0) if axis == "x" else (math.pi / 2, 0, 0)
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts, radius=r, depth=length, location=center, rotation=rot
    )
    return _finish(_active(), color, 0.0)


def disc_y(r, depth, center, color, verts=18, bevel=0.0):
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=verts, radius=r, depth=depth, location=center, rotation=(math.pi / 2, 0, 0)
    )
    return _finish(_active(), color, bevel)


def ball(r, center, color, seg=14, rings=8, squash=(1.0, 1.0, 1.0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=r, location=center)
    o = _active()
    o.scale = squash
    return _finish(o, color, 0.0)


def torus(r_major, r_minor, center, color, major_seg=24, minor_seg=6, rot=(0.0, 0.0, 0.0)):
    bpy.ops.mesh.primitive_torus_add(
        major_radius=r_major,
        minor_radius=r_minor,
        major_segments=major_seg,
        minor_segments=minor_seg,
        location=center,
    )
    o = _active()
    o.rotation_euler = rot
    return _finish(o, color, 0.0)


def _from_bmesh(bm, name, color, bevel=0.0):
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(obj)
    if bevel > 0:
        return _finish(obj, color, bevel)
    return paint(obj, color)


def taper_box(w0, d0, w1, d1, h, base_center, color, y_shift_top=0.0, rot_z=0.0, bevel=0.0):
    """Prisma retangular afunilado: base em Z=base_center[2], topo em +h."""
    cx, cy, z0 = base_center
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
    c, s = math.cos(rot_z), math.sin(rot_z)
    bm = bmesh.new()
    vs = [bm.verts.new((cx + px * c - py * s, cy + px * s + py * c, z0 + pz)) for px, py, pz in pts]
    faces = (
        (0, 3, 2, 1),
        (4, 5, 6, 7),
        (0, 1, 5, 4),
        (1, 2, 6, 5),
        (2, 3, 7, 6),
        (3, 0, 4, 7),
    )
    for f in faces:
        bm.faces.new([vs[i] for i in f])
    return _from_bmesh(bm, "taper_box", color, bevel=bevel)


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
    c, s = math.cos(rot_z), math.sin(rot_z)
    bm = bmesh.new()
    vs = [bm.verts.new((x + px * c - py * s, y_back + px * s + py * c, z0 + pz)) for px, py, pz in pts]
    for f in ((0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
        bm.faces.new([vs[i] for i in f])
    return _from_bmesh(bm, "buttress", color, bevel=bevel)


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


# ---------------------------------------------------------------- ornamentos
def shield_crest(x, y, z, r, st, boss_col=None, verts=10):
    """Escudo redondo esculpido com borda metalica, campo heraldico e umbo abaulado."""
    bcol = boss_col or st["boss"]
    return [
        disc_y(r, 0.15, (x, y, z), st["shieldRim"], verts=verts),
        disc_y(r * 0.74, 0.19, (x, y - 0.03, z), st["shieldFace"], verts=verts),
        disc_y(r * 0.30, 0.24, (x, y - 0.07, z), bcol, verts=8),
    ]


def sconce(x, y, z, st):
    """Arandela de ferro forjado com taça curva e chama dupla."""
    return [
        box((0.20, 0.58, 0.18), (x, y - 0.28, z), st["iron"]),
        cyl(0.24, 0.24, (x, y - 0.52, z + 0.08), st["iron"], verts=10, r2=0.35),
        cyl(0.22, 0.48, (x, y - 0.52, z + 0.30), st["sconceGlow"], verts=6, r2=0.0),
        cyl(0.12, 0.34, (x, y - 0.54, z + 0.36), st["flameCore"], verts=5, r2=0.0),
    ]


def banner(x, y, z_top, w, h, st):
    return [
        cyl_axis(0.08, w + 0.44, (x, y - 0.06, z_top), st["iron"], axis="x", verts=8),
        box((w, 0.10, h), (x, y - 0.09, z_top - h / 2 - 0.08), st["banner"]),
        box((w * 1.03, 0.12, 0.24), (x, y - 0.11, z_top - h - 0.06), st["bannerTrim"]),
        box((0.50, 0.13, 0.50), (x, y - 0.13, z_top - h * 0.42), st["bannerTrim"], rot=(0, math.pi / 4, 0)),
    ]


def arrow_slit(x, y, z, h, st, rot_z=0.0):
    """Seteira recuada com moldura profunda em 'ink', ombreira, peitoril e verga."""
    c, s = math.cos(rot_z), math.sin(rot_z)

    def _pt(lx, ly, lz):
        return (x + lx * c - ly * s, y + lx * s + ly * c, z + lz)

    return [
        box((0.58, 0.16, h + 0.12), _pt(0.0, -0.04, 0.0), st["wallAlt"], rot=(0, 0, rot_z)),
        box((0.22, 0.16, h), _pt(0.0, -0.09, 0.0), "ink", rot=(0, 0, rot_z)),
        box((0.68, 0.24, 0.18), _pt(0.0, -0.10, -h / 2 - 0.10), st["relief"], rot=(0, 0, rot_z)),
        box((0.68, 0.24, 0.20), _pt(0.0, -0.10, h / 2 + 0.10), st["relief"], rot=(0, 0, rot_z)),
    ]


# ---------------------------------------------------------------- modulos
def build_segment(side, lvl):
    st = TIER_STYLE[lvl]
    a, b = SEG_A, SEG_B
    length = b - a
    cx = side * (a + b) / 2
    parts = []

    # 1. Base em talude (sloped stone batter base) + blocos de fundacao com musgo
    parts.append(taper_box(length + 0.18, 4.10, length + 0.04, 2.75, 1.70, (cx, 0.0, 0.0), st["plinth"]))
    parts.append(box((1.60, 0.54, 0.70), (cx + side * 3.1, -1.74, 0.38), st["relief"]))
    parts.append(box((1.22, 0.48, 0.38), (cx + side * 3.1, -1.76, 0.80), "moss"))
    parts.append(box((1.35, 0.48, 0.56), (cx - side * 3.4, -1.72, 0.32), st["wallAlt"]))

    # 2. Corpo da cortina chanfrado
    wall_h = 6.25 if lvl != 4 else 6.45
    wall_d = 2.45
    parts.append(box((length, wall_d, wall_h), (cx, 0.0, 1.70 + wall_h / 2), st["wall"], bevel=0.04))

    # 3. 3 contrafortes inclinados chanfrados projetados 0.85 stud na face frontal (-Y)
    for frac in (-0.33, 0.0, 0.33):
        bx = cx + frac * length
        parts.append(
            sloped_buttress(1.08, 0.88, 0.32, wall_h - 0.35, bx, -wall_d / 2, 1.70, st["buttress"], bevel=0.04)
        )
        parts.append(
            taper_box(
                1.16,
                0.44,
                0.92,
                0.24,
                0.46,
                (bx, -wall_d / 2 - 0.15, 1.70 + wall_h - 0.35),
                st["cap"],
            )
        )

    # 4. Relevo de alvenaria escalonada + friso horizontal moldado chanfrado
    parts.append(box((length - 0.08, 0.30, 0.32), (cx, -wall_d / 2 - 0.12, 4.65), st["trim"], bevel=0.04))
    for kx, kz, w in ((-4.3, 2.9, 1.55), (4.3, 3.2, 1.55), (-2.1, 5.30, 1.38)):
        parts.append(box((w, 0.28, 0.58), (cx + kx, -wall_d / 2 - 0.12, kz), st["relief"]))

    # 5. Cornija saliente chanfrada + cachorros + 3 ameias + 2 escudos redondos
    walk_z = 1.70 + wall_h
    parts.append(box((length + 0.12, 3.08, 0.46), (cx, -0.10, walk_z + 0.23), st["cornice"], bevel=0.04))
    for kx in (-length * 0.24, 0.0, length * 0.24):
        parts.append(sloped_buttress(0.46, 0.48, 0.14, 0.58, cx + kx, -wall_d / 2, walk_z - 0.56, st["trim"]))

    m = 3
    for j in range(m):
        mx = side * (a + (j + 0.5) * length / m)
        parts.append(
            taper_box(1.58, 0.96, 1.36, 0.86, 1.25, (mx, -1.05, walk_z + 0.46), st["wall"])
        )
        parts.append(
            box((1.70, 1.08, 0.28), (mx, -1.05, walk_z + 1.85), st["cap"])
        )

    for kx in (-length * 0.17, length * 0.17):
        parts += shield_crest(cx + kx, -wall_d / 2 - 0.16, walk_z - 1.22, 0.58, st, verts=10)

    # 6. Passadico traseiro (rear catwalk) com maos-francesas
    cat_z = walk_z - 1.05
    parts.append(box((length - 0.1, 1.45, 0.30), (cx, wall_d / 2 + 0.72, cat_z), st["trim"]))
    parts.append(box((length - 0.1, 0.22, 0.76), (cx, wall_d / 2 + 1.38, cat_z + 0.52), st["wallAlt"]))
    for kx in (-length * 0.30, length * 0.30):
        parts.append(box((0.28, 1.30, 0.28), (cx + kx, wall_d / 2 + 0.55, cat_z - 0.55), st["trim"], rot=(0.68, 0, 0)))

    return parts


def build_tower(side, lvl):
    st = TIER_STYLE[lvl]
    x = side * TOWER_X
    r = TOWER_R + (0.28 if lvl == 4 else 0.0)
    parts = []

    # 1. Talus cilindrico suave alargado na base (verts=24) + corpo cilindrico (verts=24)
    parts.append(cyl(r + 1.15, 2.35, (x, 0, 0.0), st["plinth"], verts=24, r2=r + 0.08))
    parts.append(cyl(r, 8.75, (x, 0, 2.35), st["wall"], verts=24))

    # 2. 4 nervuras de contraforte chanfradas (-Y, +X, -X, +Y)
    for ang in (-math.pi / 2, 0.0, math.pi, math.pi / 2):
        rot_z = ang + math.pi / 2
        px = x + (r - 0.12) * math.cos(ang)
        py = (r - 0.12) * math.sin(ang)
        parts.append(
            sloped_buttress(0.74, 0.76, 0.34, 8.40, px, py, 2.15, st["buttress"], rot_z=rot_z, bevel=0.04)
        )

    # 3. Friso horizontal suave (verts=24)
    parts.append(cyl(r + 0.18, 0.32, (x, 0, 5.65), st["trim"], verts=24))

    # 4. Seteiras recuadas nas faces frontais laterais (-Y +- pi/5)
    for ang_off in (-math.pi / 5, math.pi / 5):
        ang = -math.pi / 2 + ang_off
        sx = x + (r - 0.04) * math.cos(ang)
        sy = (r - 0.04) * math.sin(ang)
        parts += arrow_slit(sx, sy, 7.3, 1.25, st, rot_z=ang + math.pi / 2)

    # 5. Galeria de mata-caes com anel arredondado de cachorros (rounded corbel ring, verts=24)
    gal_z = 11.10
    parts.append(cyl(r + 0.06, 0.56, (x, 0, gal_z - 0.56), st["trim"], verts=24, r2=r + 0.44))
    for k in range(5):
        ang = -math.pi / 2 + 2 * math.pi * k / 5
        rot_z = ang + math.pi / 2
        cxk = x + (r - 0.05) * math.cos(ang)
        cyk = (r - 0.05) * math.sin(ang)
        parts.append(sloped_buttress(0.42, 0.62, 0.16, 0.68, cxk, cyk, gal_z - 0.68, st["trim"], rot_z=rot_z))

    parts.append(cyl(r + 0.20, 0.92, (x, 0, gal_z), st["cornice"], verts=24, r2=r + 0.68))

    # 6. 5 ameias com capeamento na galeria
    for k in range(5):
        ang = -math.pi / 2 + 2 * math.pi * k / 5
        mx = x + (r + 0.50) * math.cos(ang)
        my = (r + 0.50) * math.sin(ang)
        parts.append(
            taper_box(
                1.12, 0.64, 0.98, 0.56, 1.08, (mx, my, gal_z + 0.92), st["wall"], rot_z=ang + math.pi / 2
            )
        )
        parts.append(box((1.18, 0.70, 0.22), (mx, my, gal_z + 2.08), st["cap"], rot=(0, 0, ang + math.pi / 2)))

    # 7. Telhado conico suave (verts=24) + nervuras + lucarna frontal + flecha conica (verts=24)
    roof_z = gal_z + 1.00
    roof_r = r + 0.90
    roof_h = 4.65
    parts.append(cyl(roof_r, roof_h, (x, 0, roof_z), st["roof"], verts=24, r2=0.0))

    peak = Vector((x, 0.0, roof_z + roof_h))
    for k in range(5):
        ang = -math.pi / 2 + 2 * math.pi * k / 5
        eave = Vector((x + roof_r * math.cos(ang), roof_r * math.sin(ang), roof_z + 0.06))
        mid = (eave + peak) * 0.5
        dvec = peak - eave
        rot_eul = dvec.normalized().to_track_quat("Z", "Y").to_euler("XYZ")
        parts.append(box((0.16, 0.18, dvec.length * 0.96), tuple(mid), st["roofRib"], rot=tuple(rot_eul)))

    # Lucarna frontal (-Y)
    parts.append(taper_box(1.12, 1.15, 0.20, 1.15, 1.35, (x, -r * 0.72, roof_z + 0.85), st["roofRib"]))
    parts.append(box((0.32, 0.16, 0.62), (x, -r * 0.72 - 0.56, roof_z + 1.25), "ink"))

    # Flecha conica (verts=24) + flâmula no topo
    spire_z = roof_z + roof_h - 0.15
    parts.append(cyl(0.34, 1.20, (x, 0, spire_z), st["trim"], verts=24, r2=0.0))
    parts.append(box((1.35, 0.08, 0.72), (x + side * 0.68, 0, spire_z + 1.10), st["banner"]))

    # 8. Estandarte heraldico frontal
    parts += banner(x, -r - 0.24, 10.45, 1.35, 2.85, st)

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
            box((pier_w, GATE_D + 0.85, GATE_H - 1.85), (px, -0.35, 1.85 + (GATE_H - 1.85) / 2), st["gatePier"], bevel=0.04)
        )
        parts.append(box((pier_w + 0.26, GATE_D + 1.06, 0.34), (px, -0.35, 5.20), st["trim"]))
        parts.append(
            sloped_buttress(0.72, 0.56, 0.22, 6.20, px + sx * 0.45, -GATE_D / 2 - 0.75, 1.85, st["buttress"], bevel=0.04)
        )
        parts += shield_crest(px - sx * 0.35, -GATE_D / 2 - 0.82, 7.15, 0.52, st, verts=10)

    # 2. Timpano suave do arco (segs=12) + parede superior
    parts.append(arch_spandrel(arch_r * 2, arch_r, spring_z, arch_top, GATE_D, 0.0, st["wall"], segs=12))
    parts.append(
        box((arch_r * 2, GATE_D, GATE_H - arch_top), (0.0, 0.0, arch_top + (GATE_H - arch_top) / 2), st["wall"])
    )

    # 3. Arco em pedra profunda com 7 aduelas chanfradas (voussoirs) + pedra-chave esculpida + Brasao da Ordem Ambar
    n_voussoirs = 7
    for k in range(n_voussoirs):
        ang = 0.14 + (math.pi - 0.28) * k / (n_voussoirs - 1)
        is_key = k == n_voussoirs // 2
        vr = arch_r + (0.34 if is_key else 0.28)
        vx = vr * math.cos(ang)
        vz = spring_z + vr * math.sin(ang)
        col = st["trim"] if is_key else (st["archRing"] if k % 2 == 0 else st["wallAlt"])
        vw = 1.12 if is_key else 0.96
        vh = 0.86 if is_key else 0.68
        vd = 0.64 if is_key else 0.54
        parts.append(
            box((vw, vd, vh), (vx, -GATE_D / 2 - 0.14, vz), col, bevel=0.04, rot=(0, -ang + math.pi / 2, 0))
        )

    # Brasao esculpido da Ordem Ambar acima da pedra-chave central
    parts.append(
        box((1.52, 0.28, 1.52), (0.0, -GATE_D / 2 - 0.26, 8.68), st["trim"], bevel=0.04, rot=(0, math.pi / 4, 0))
    )
    parts += shield_crest(0.0, -GATE_D / 2 - 0.36, 8.68, 0.66, st, boss_col="amberBright", verts=12)

    # 4. Portao duplo em carvalho encaixilhado com ferragens
    parts.append(box((arch_r * 2, 0.42, arch_top - 0.1), (0.0, 0.42, (arch_top - 0.1) / 2), "woodDark"))
    parts.append(box((0.28, 0.56, arch_top - 0.4), (0.0, 0.32, (arch_top - 0.4) / 2), "wood"))
    for px in (-2.05, -0.75, 0.75, 2.05):
        h_plank = spring_z + math.sqrt(max(0.0, arch_r**2 - px**2)) - 0.25
        parts.append(box((0.88, 0.16, h_plank), (px, 0.18, h_plank / 2), "woodLight" if abs(px) > 1.0 else "wood"))
    for z in (1.25, 3.25):
        parts.append(box((arch_r * 1.92, 0.20, 0.34), (0.0, 0.12, z), st["iron"]))

    # 5. Grade de rastrilho (portcullis) com barras de ferro cilindricas arredondadas e pontas conicas
    port_y = -1.18
    for px in (-2.2, -1.1, 0.0, 1.1, 2.2):
        top_z = spring_z + math.sqrt(max(0.0, (arch_r - 0.1) ** 2 - px**2)) - 0.15
        bar_h = top_z - 0.62
        parts.append(cyl(0.11, bar_h, (px, port_y, 0.62), st["iron"], verts=8))
        sp = cyl(0.15, 0.48, (px, port_y, 0.14), st["iron"], verts=8, r2=0.0)
        sp.rotation_euler = (math.pi, 0, 0)
        bpy.context.view_layer.objects.active = sp
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
        parts.append(sp)
    for z in (1.95, 3.85):
        parts.append(cyl_axis(0.12, 5.25, (0.0, port_y, z), st["iron"], axis="x", verts=8))

    # 6. Camara de Alavancas superior em balanco (-Y) chanfrada com fendas brilhantes + coroamento
    cam_z = GATE_H
    for kx in (-3.8, 0.0, 3.8):
        parts.append(sloped_buttress(0.46, 0.90, 0.16, 0.85, kx, -GATE_D / 2, cam_z - 0.85, st["trim"]))

    cam_w, cam_d, cam_h = GATE_W + 0.65, GATE_D + 1.35, 2.25
    parts.append(box((cam_w, cam_d, cam_h), (0.0, -0.45, cam_z + cam_h / 2), st["wallAlt"], bevel=0.04))
    for kx in (-5.6, 5.6):
        parts.append(
            box((0.38, 0.28, cam_h + 0.1), (kx, -0.45 - cam_d / 2 - 0.08, cam_z + cam_h / 2), st["trim"])
        )
    parts.append(box((cam_w + 0.48, cam_d + 0.42, 0.38), (0.0, -0.45, cam_z + cam_h + 0.19), st["cornice"], bevel=0.04))

    # 3 fendas de vigia brilhantes com moldura ink
    parts.append(box((8.8, 0.16, 0.88), (0.0, -0.45 - cam_d / 2 - 0.04, cam_z + 1.15), "ink"))
    for sx in (-3.8, 0.0, 3.8):
        parts.append(box((0.68, 0.20, 0.56), (sx, -0.45 - cam_d / 2 - 0.08, cam_z + 1.15), st["slitGlow"]))

    # Remate superior ornamentado (ameias + telhado + flecha conica verts=24)
    top_base = cam_z + cam_h + 0.38
    for mx in (-4.8, -2.4, 2.4, 4.8):
        parts.append(
            taper_box(1.34, 0.90, 1.16, 0.80, 1.15, (mx, -0.45 - cam_d / 2 + 0.44, top_base), st["wall"])
        )
        parts.append(box((1.42, 0.96, 0.22), (mx, -0.45 - cam_d / 2 + 0.44, top_base + 1.26), st["cap"]))
    parts.append(taper_box(5.8, cam_d + 0.2, 2.2, 0.55, 2.15, (0.0, -0.45, top_base), st["roof"]))
    parts.append(cyl(0.36, 1.10, (0.0, -0.45, top_base + 2.15), st["trim"], verts=24, r2=0.0))

    # 7. Arandelas de ferro forjado na face frontal dos flancos
    for sx in (-4.9, 4.9):
        parts += sconce(sx, -GATE_D / 2 - 0.78, 4.4, st)

    return parts


# ---------------------------------------------------------------- lote Forge3D
def write_lote(levels):
    lines = [
        "# Forge3D 0.8.0 — rota `import`: muralha modelada por script (art/scripts/make_wall_bastion.py)",
        "# entra no mesmo QC (escala, pivo, LOD, colisao, manifesto, indice). Saida no sandbox.",
        "#   forge3d run art/forge/lote_muralha_import.yaml --json   (ou: bash tools/art-pipeline.sh --only wall)",
        "# GERADO pelo script: altura_metros = altura medida em studs x 0,28 (perfil roblox-r15).",
        "schema: forge3d/spec@5",
        "",
        "projeto: muralha",
        "perfil: roblox-r15",
        "destino_exportacao: ~/.local/state/forge3d/saida/muralha_import",
        "estilo_global: lowpoly_lit",
        "",
        "politica:",
        "  falha: continuar",
        "  custo_max_min: 5",
        "  seed_base: 20261113",
        "",
        "lote:",
    ]
    for lvl, (_coll, mods) in levels.items():
        top = max((o.matrix_world @ v.co).z for _, o in mods for v in o.data.vertices)
        h = round(top, 4)
        lines += [
            f"  - id: wall.bastion.l{lvl}.01",
            "    tipo: modulo_cenario",
            "    rota: import",
            f"    origem: art/export/wall_bastion_l{lvl}.glb",
            f"    altura_metros: {round(h * METROS_POR_STUD, 4)}   # {h} studs",
            "    pivot: base",
            f"    limite_triangulos: {LIMITE_LOTE[lvl]}",
            "    material: opaque",
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

    # Garante pivo Z >= 0 em todo o tier apos o jitter
    min_z = min((o.matrix_world @ v.co).z for _, o in mods for v in o.data.vertices)
    for _, o in mods:
        for v in o.data.vertices:
            v.co.z -= min_z
        o.data.update()

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
        union_g1 = check_tier_union_g1(mods)
        min_z = min((o.matrix_world @ v.co).z for _, o in mods for v in o.data.vertices)
        if total > TIER_TRIS_MAX or union_g1["nao_manifold"] != 0 or union_g1["degeneradas"] != 0 or min_z < -1e-6:
            failures.append(f"L{lvl}:total={total},union_g1={union_g1},min_z={min_z}")
        report.append(f"L{lvl} total: {total}/{TIER_TRIS_MAX} tris union_g1={union_g1} min_z={round(min_z, 5)}")

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
