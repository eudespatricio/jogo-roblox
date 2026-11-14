"""Biblioteca low-poly compartilhada pela esteira de arte (traps, horda, portal).

Copia os padroes de `make_wall_bastion.py` (que fica intocado): atlas de paleta 256x256,
`paint()` com UV nao colapsada, 1 material por mesh, primitivas box/cyl/ball e export GLB.
Acrescenta o que a esteira precisa para passar no QC do Forge3D sem retrabalho manual:

- jitter deterministico por peca no `join()` (QC G1: nenhum vertice coincidente entre pecas,
  o Forge solda por posicao arredondada a 1e-5);
- `normalize()` poe o pivo na base (Z=0) depois do jitter (QC G2 pivo);
- `g1_check()` replica a solda/arestas do G1 localmente e reprova antes do Forge;
- `write_lote()` gera o lote `rota: import` com `altura_metros` MEDIDA (studs x 0,28);
- renders por item (mesma escala por grupo) para o lineup montado pela esteira.

Convencoes: 1 unidade Blender = 1 stud, Z-up, frente = -Y, export_yup=True, seeds fixas.
"""

from __future__ import annotations

import json
import math
import os
import random
import sys

import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
EXPORT_DIR = os.path.join(ROOT, "art", "export")
RENDER_DIR = os.path.join(ROOT, "art", "renders")
FORGE_DIR = os.path.join(ROOT, "art", "forge")
METROS_POR_STUD = 0.28  # perfil roblox-r15 do Forge3D
SEED_BASE = 20261113

# Paleta canonica (VisualTheme.PALETTE + tons da muralha + cores de faccao/tipo).
PAL = {
    "stone": (92, 96, 102),
    "stoneDark": (52, 56, 62),
    "stoneLight": (154, 147, 134),
    "wood": (139, 90, 43),
    "woodDark": (92, 58, 28),
    "woodLight": (176, 118, 62),
    "iron": (58, 63, 70),
    "ironDark": (32, 35, 40),
    "amber": (245, 158, 11),
    "amberBright": (255, 199, 64),
    "danger": (228, 87, 46),
    "parchment": (245, 230, 200),
    "grass": (70, 94, 55),
    "gold": (201, 162, 39),
    "roof": (168, 52, 38),
    "moss": (88, 112, 62),
    "ink": (18, 20, 24),
    "white": (245, 245, 245),
    "neonAmber": (255, 228, 150),  # chevron L3 (Neon no runtime)
    "bronze": (176, 120, 58),
    "steel": (140, 140, 153),  # VisualTheme.TRAPS.cannon.color
    "archer": (89, 184, 89),  # VisualTheme.TRAPS.archer.color
    "archerDark": (52, 120, 56),
    "tarGlow": (184, 140, 51),  # VisualTheme.TRAPS.tar.color
    "tarDeep": (40, 30, 22),
    "ice": (89, 166, 230),  # VisualTheme.TRAPS.frost.color
    "iceLight": (170, 214, 245),
    "iceGlow": (200, 240, 255),
    "catapult": (204, 89, 77),  # VisualTheme.TRAPS.catapult.color
    "teal": (20, 184, 166),  # ENEMIES.runner
    "tealDark": (10, 74, 70),
    "tealBrute": (13, 148, 136),  # ENEMIES.brute
    "tealBruteDark": (8, 47, 46),
    "tealSwarm": (45, 212, 191),  # ENEMIES.swarm
    "tealSwarmDark": (15, 118, 110),
    "eyeNeon": (220, 255, 245),  # HordeKit.makeVisor (Neon)
    "ember": (255, 178, 80),  # ArenaVisual.buildRiftPortal (coroas/lintel)
    "goldBright": (240, 200, 80),  # filigrana L4/L5
    "leafDeep": (36, 72, 42),
    "leafMid": (56, 102, 54),
    "leafSun": (82, 134, 64),
    "oliveLeaf": (94, 114, 52),
    "barkDark": (68, 46, 28),
    "furBrown": (122, 82, 50),
    "furTan": (174, 132, 86),
    "hornIvory": (224, 214, 192),
    "wyvernScale": (158, 52, 40),
    "wyvernWing": (98, 36, 32),
}
NAMES = list(PAL)
assert len(NAMES) <= 64, "atlas 8x8"
MAT = None
RNG = random.Random(SEED_BASE)


# ---------------------------------------------------------------- cena e materiais
def reset_scene():
    for o in list(bpy.data.objects):  # --factory-startup traz Cube/Camera/Light
        bpy.data.objects.remove(o, do_unlink=True)
    make_materials()


def make_palette():
    size, cell = 256, 32
    img = bpy.data.images.new("lowpoly_palette", size, size, alpha=False)
    px = [0.0] * (size * size * 4)
    for i, name in enumerate(NAMES):
        r, g, b = PAL[name]
        cx, cy = i % 8, i // 8
        for y in range(cy * cell, (cy + 1) * cell):
            for x in range(cx * cell, (cx + 1) * cell):
                k = (y * size + x) * 4
                px[k : k + 4] = [r / 255, g / 255, b / 255, 1.0]
    img.pixels = px
    os.makedirs(RENDER_DIR, exist_ok=True)
    path = os.path.join(RENDER_DIR, "_lowpoly_palette.png")  # art/renders/ e ignorado no git
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    img.pack()
    return img


def make_materials():
    global MAT
    img = make_palette()
    MAT = bpy.data.materials.new("M_lowpoly_palette")
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
    # UV nao colapsada (QC G3): cada face vira um poligono pequeno dentro da celula
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


def _finish(obj, color, bevel=0.0):
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if bevel > 0:
        mod = obj.modifiers.new("bv", "BEVEL")
        mod.width = bevel
        mod.segments = 1
        mod.limit_method = "ANGLE"
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return paint(obj, color)


def box(size, center, color, bevel=0.0, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center, rotation=rot)
    o = _active()
    o.scale = size
    return _finish(o, color, bevel)


def cyl(r, h, base, color, verts=10, r2=None, bevel=0.0, rot_z=0.0):
    """Cilindro/cone vertical com a base em `base`. r2=0 vira cone com apice unico."""
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


def cyl_axis(r, length, center, color, axis="x", verts=10, r2=None, tilt=0.0):
    """Cilindro deitado: axis 'x' (rodas, eixos) ou 'y' (canos, frente/tras).

    `tilt` inclina em torno de X (canos apontando para -Y e subindo)."""
    # Rx(90 - tilt) leva +Z para -Y subindo: a ponta estreita (r2) fica na frente.
    rot = (0, math.pi / 2, 0) if axis == "x" else (math.pi / 2 - tilt, 0, 0)
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(
            vertices=verts, radius=r, depth=length, location=center, rotation=rot
        )
    else:
        bpy.ops.mesh.primitive_cone_add(
            vertices=verts, radius1=r, radius2=r2, depth=length, location=center, rotation=rot
        )
    return _finish(_active(), color, 0.0)


def ball(r, center, color, seg=8, rings=5, squash=(1.0, 1.0, 1.0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=r, location=center)
    o = _active()
    o.scale = squash
    return _finish(o, color, 0.0)


def ico(r, center, color, squash=(1.0, 1.0, 1.0)):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=r, location=center)
    o = _active()
    o.scale = squash
    return _finish(o, color, 0.0)


def spike(r, h, base, color, verts=4, rot_z=math.pi / 4):
    """Cone de apice unico (cristais, ameias coroadas, pontas de telhado)."""
    return cyl(r, h, base, color, verts=verts, r2=0.0, rot_z=rot_z)


def crystal(r, h, base, color, tilt=(0.0, 0.0), verts=5, r2=0.0, spin=0.0):
    """Prisma/cone inclinado a partir da base: tilt=(rot X, rot Y) em radianos."""
    from mathutils import Euler

    eul = Euler((tilt[0], tilt[1], spin), "XYZ")
    off = Vector((0, 0, h / 2))
    off.rotate(eul)
    loc = Vector(base) + off
    bpy.ops.mesh.primitive_cone_add(
        vertices=verts, radius1=r, radius2=r2, depth=h, location=loc, rotation=eul
    )
    return _finish(_active(), color, 0.0)


def chevron(center, color, width=0.7, arm=0.13, depth=0.14, angle=0.6):
    """Chevron frontal em V invertido (^), voltado para -Y. Largura total >= 0,6 stud."""
    cx, cy, cz = center
    half = width / 2
    length = half / math.cos(angle) + arm * 0.5
    dz = math.tan(angle) * half / 2
    return [
        box((length, depth, arm), (cx - half / 2, cy, cz - dz), color, rot=(0, -angle, 0)),
        box((length, depth, arm), (cx + half / 2, cy, cz - dz), color, rot=(0, angle, 0)),
    ]


CHEVRON_COLOR = {1: "amber", 2: "amberBright", 3: "neonAmber"}


def gear(r, thick, center, color, axis="z", teeth=8, hub=None):
    """Engrenagem low-poly: disco de 12 lados + `teeth` dentes; axis 'z' (deitada) ou 'x'."""
    from mathutils import Euler, Matrix

    cx, cy, cz = center
    parts = []
    if axis == "z":
        parts.append(cyl(r, thick, (cx, cy, cz - thick / 2), color, verts=12))
    else:
        parts.append(cyl_axis(r, thick, center, color, axis="x", verts=12))
    tooth = (r * 0.36, r * 0.34, thick * 0.9)
    for k in range(teeth):
        a = 2 * math.pi * (k + 0.5) / teeth
        if axis == "z":
            pos = (cx + (r + tooth[1] * 0.3) * math.cos(a), cy + (r + tooth[1] * 0.3) * math.sin(a), cz)
            rot = (0, 0, a)
            size = (tooth[1], tooth[0], tooth[2])
        else:
            pos = (cx, cy + (r + tooth[1] * 0.3) * math.cos(a), cz + (r + tooth[1] * 0.3) * math.sin(a))
            rot = (a, 0, 0)
            size = (tooth[2], tooth[1], tooth[0])
        parts.append(box(size, pos, color, rot=rot))
    if hub:
        if axis == "z":
            parts.append(cyl(r * 0.35, thick * 1.4, (cx, cy, cz - thick * 0.7), hub, verts=8))
        else:
            parts.append(cyl_axis(r * 0.35, thick * 1.4, center, hub, axis="x", verts=8))
    return parts


def ring(r, center, color, n=12, tilt=(0.0, 0.0), seg=(0.12, 0.12)):
    """Anel de `n` segmentos (giroscopio, filigrana). tilt=(rot X, rot Y) do plano do anel."""
    from mathutils import Euler

    base = Euler((tilt[0], tilt[1], 0.0), "XYZ").to_matrix()
    length = 2 * math.pi * r / n * 1.08
    parts = []
    for k in range(n):
        a = 2 * math.pi * (k + 0.5) / n
        local = Vector((r * math.cos(a), r * math.sin(a), 0.0))
        pos = base @ local + Vector(center)
        rot = (base @ Euler((0, 0, a + math.pi / 2), "XYZ").to_matrix()).to_euler("XYZ")
        parts.append(box((length, seg[0], seg[1]), tuple(pos), color, rot=tuple(rot)))
    return parts


def fused_chevron(center, lvl):
    """Patente L4/L5 (doc §2.1): chevron fusionado dourado; L5 ganha nucleo energizado."""
    cx, cy, cz = center
    parts = chevron((cx, cy, cz), "gold", width=0.86, arm=0.22, depth=0.16, angle=0.62)
    parts += chevron((cx, cy - 0.02, cz - 0.24), "goldBright", width=0.7, arm=0.12, depth=0.16, angle=0.62)
    if lvl >= 5:
        parts.append(ico(0.13, (cx, cy, cz + 0.32), "neonAmber"))
    return parts


def rank_mast(lvl, corner=(-1.95, -2.1), z0=0.15, mast_h=1.8, z_first=1.4, step=0.42):
    """Mastro de patente (TrapKit.addRankChevrons): mastro ironDark + `lvl` chevrons.

    X=-1,95 (nao -2,1) para os chevrons de 0,7 caberem na pegada de 4,8 studs.

    Canto frontal-esquerdo no Blender = canto voltado a camera do BuildClient quando a frente
    (-Y) aponta para o portal (ver art/README.md, secao Esteira)."""
    x, y = corner
    parts = [box((0.16, 0.16, mast_h), (x, y, z0 + mast_h / 2), "ironDark")]
    if lvl >= 4:  # mastro dourado + chevron fusionado (+ nucleo no L5)
        parts.append(box((0.24, 0.24, 0.12), (x, y, z0 + mast_h + 0.06), "gold"))
        return parts + fused_chevron((x, y - 0.12, z_first + step), lvl)
    for n in range(lvl):
        parts += chevron((x, y - 0.16, z_first + n * step), CHEVRON_COLOR[lvl])
    return parts


def rank_row(lvl, y, z, spacing=0.8):
    """Chevrons lado a lado numa face frontal (armadilhas baixas, ex.: piche)."""
    if lvl >= 4:
        return fused_chevron((0.0, y + 0.08, z + 0.08), lvl)
    parts = []
    for n in range(lvl):
        x = (n - (lvl - 1) / 2) * spacing
        parts += chevron((x, y, z), CHEVRON_COLOR[lvl], width=0.66)
    return parts


# ---------------------------------------------------------------- montagem
def join(objs, name, seed):
    """Junta as pecas num mesh. Antes, desloca cada peca por um jitter deterministico de
    3-12 milesimos de stud em X/Y/Z: invisivel, mas garante que nenhuma aresta de pecas
    diferentes coincida apos a solda por posicao do Forge (QC G1)."""
    rng = random.Random(seed)
    for o in objs:
        o.location = (
            o.location[0] + rng.choice((-1, 1)) * rng.uniform(0.003, 0.012),
            o.location[1] + rng.choice((-1, 1)) * rng.uniform(0.003, 0.012),
            o.location[2] + rng.choice((-1, 1)) * rng.uniform(0.003, 0.012),
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


def normalize(obj, center_xy=False):
    """Pivo na base: menor Z vira 0 (QC G2 `pivot: base`). Origem do objeto em (0,0,0)."""
    vs = obj.data.vertices
    min_z = min(v.co.z for v in vs)
    dx = dy = 0.0
    if center_xy:
        dx = -(min(v.co.x for v in vs) + max(v.co.x for v in vs)) / 2
        dy = -(min(v.co.y for v in vs) + max(v.co.y for v in vs)) / 2
    for v in vs:
        v.co.x += dx
        v.co.y += dy
        v.co.z -= min_z
    obj.data.update()
    return obj


def tris(obj) -> int:
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def bbox(obj):
    vs = obj.data.vertices
    mn = [min(v.co[i] for v in vs) for i in range(3)]
    mx = [max(v.co[i] for v in vs) for i in range(3)]
    return mn, mx


def g1_check(obj) -> dict:
    """Replica o G1 do Forge3D (solda por posicao a 1e-5 m, arestas != 2 faces, degeneradas)."""
    me = obj.data
    me.calc_loop_triangles()
    key = {}
    weld = []
    for v in me.vertices:
        c = v.co * METROS_POR_STUD
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


def export_glb(obj, filename):
    os.makedirs(EXPORT_DIR, exist_ok=True)
    path = os.path.join(EXPORT_DIR, filename)
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_apply=True,
    )
    return path


# ---------------------------------------------------------------- lote Forge3D
def write_lote(group, items, header_note):
    """Gera art/forge/lote_<group>_import.yaml com altura MEDIDA (G2: studs x 0,28)."""
    lines = [
        f"# Forge3D 0.6.1 — rota `import`: {header_note}",
        "# GERADO por art/scripts/lowpoly_lib.py (tools/art-pipeline.sh). Nao editar a mao:",
        "# altura_metros = altura exportada em studs x 0,28 (perfil roblox-r15).",
        "schema: forge3d/spec@4",
        "",
        "projeto: muralha",
        "perfil: roblox-r15",
        f"destino_exportacao: ~/.local/state/forge3d/saida/muralha_{group}",
        "estilo_global: lowpoly_lit",
        "",
        "politica:",
        "  falha: continuar",
        "  custo_max_min: 5",
        f"  seed_base: {SEED_BASE}",
        "",
        "lote:",
    ]
    for it in items:
        lines += [
            f"  - id: {it['id']}",
            f"    tipo: {it['tipo']}",
            "    rota: import",
            f"    origem: {it['glb_path']}",
            f"    altura_metros: {it['altura_metros']}   # {it['altura_studs']} studs",
            f"    pivot: {it.get('pivot', 'base')}",
            f"    limite_triangulos: {it['limite']}",
            "    material: opaque",
            "    colisao: box",
            f"    seed: {SEED_BASE}",
            "    lod: [100]",
            f"    tags: [{', '.join(it['tags'])}]",
            "",
        ]
    path = os.path.join(FORGE_DIR, f"lote_{group}_import.yaml")
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines).rstrip() + "\n")
    return path


# ---------------------------------------------------------------- render
def setup_render(res=480):
    scene = bpy.context.scene
    bpy.context.view_layer.active_layer_collection = bpy.context.view_layer.layer_collection
    ground = box((400, 400, 0.2), (0, 0, -0.11), "grass")
    ground.name = "RENDER_ground"
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    scene.collection.objects.link(cam)
    scene.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 4.0
    sun.data.angle = math.radians(6)
    sun.rotation_euler = (math.radians(50), 0, math.radians(-35))
    scene.collection.objects.link(sun)
    world = bpy.data.worlds.new("w")
    world.use_nodes = True
    bg = world.node_tree.nodes["Background"]
    bg.inputs[0].default_value = (0.62, 0.74, 0.92, 1)
    bg.inputs[1].default_value = 0.9
    scene.world = world
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.view_settings.view_transform = "Standard"
    scene.render.resolution_x = scene.render.resolution_y = res
    scene.render.film_transparent = False
    scene.eevee.taa_render_samples = 16  # preview: 16 amostras bastam e cortam ~4x o tempo
    return cam, ground


# Camera de leitura: frente-esquerda elevada (mesma face que a camera do BuildClient ve).
VIEW_DIR = Vector((-0.55, -1.0, 0.75)).normalized()


def render_items(group, objs, scale_pad=1.25):
    """Um PNG por item, mesma escala ortografica no grupo (tamanhos comparaveis no lineup)."""
    cam, _ = setup_render()
    size = 0.0
    for o in objs:
        mn, mx = bbox(o)
        size = max(size, max(mx[0] - mn[0], mx[1] - mn[1], mx[2] - mn[2]))
    cam.data.ortho_scale = size * scale_pad * 1.35
    paths = []
    os.makedirs(os.path.join(RENDER_DIR, group), exist_ok=True)
    for o in objs:
        for other in objs:
            other.hide_render = other is not o
        mn, mx = bbox(o)
        target = Vector(((mn[0] + mx[0]) / 2, (mn[1] + mx[1]) / 2, (mx[2]) * 0.45 + size * 0.1))
        cam.location = target + VIEW_DIR * (size * 6 + 20)
        cam.rotation_euler = (-VIEW_DIR).to_track_quat("-Z", "Y").to_euler()
        path = os.path.join(RENDER_DIR, group, f"{o.name}.png")
        bpy.context.scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        paths.append(path)
    for o in objs:
        o.hide_render = False
    return paths


# ---------------------------------------------------------------- orquestracao
def run_group(group, specs, header_note):
    """specs: dicts {id, name, glb, tipo, limite, tags, build: fn(seed)->list[parts]}.

    Constroi, junta, normaliza, checa G1/orcamento localmente, exporta, gera o lote e
    renderiza. Sai com codigo != 0 (via --python-exit-code) se algum item reprovar."""
    reset_scene()
    objs, items, report, failures = [], [], [], []
    for i, s in enumerate(specs):
        seed = s.get("seed", SEED_BASE + i * 101)
        RNG.seed(seed)
        o = join(s["build"](), s["name"], seed)
        normalize(o, center_xy=s.get("center_xy", False))
        n = tris(o)
        mn, mx = bbox(o)
        h = round(mx[2] - mn[2], 4)
        g1 = g1_check(o)
        ok = n <= s["limite"] and g1["nao_manifold"] == 0 and g1["degeneradas"] == 0
        if not ok:
            failures.append(s["id"])
        glb = export_glb(o, s["glb"])
        items.append(
            {
                **s,
                "glb_path": glb,
                "altura_studs": h,
                "altura_metros": round(h * METROS_POR_STUD, 4),
            }
        )
        report.append(
            {
                "id": s["id"],
                "obj": o.name,
                "tris": n,
                "limite": s["limite"],
                "altura_studs": h,
                "footprint": [round(mx[0] - mn[0], 2), round(mx[1] - mn[1], 2)],
                **g1,
                "ok": ok,
            }
        )
        objs.append(o)
    lote = write_lote(group, items, header_note)
    renders = render_items(group, objs)
    print("ART_REPORT " + json.dumps({"group": group, "lote": lote, "items": report, "renders": renders}))
    if failures:
        raise SystemExit(f"[{group}] reprovado localmente: {failures}")
    return objs
