"""Gera o Portao Central pre-fraturado em 12 blocos rigidos (Fisica Real Hibrida).

Uso headless:
  blender4.5 -b --factory-startup --python art/scripts/make_fractured_gate.py
  blender4.5 -b --factory-startup --python art/scripts/make_fractured_gate.py -- --export-lfs
"""

from __future__ import annotations

import argparse
import os
import sys

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Dimensoes do Gate no ArenaVisual (Studio Y-up -> Blender Z-up: X=3.1, Y=8.0, Z=6.6)
GATE_X = 3.1
GATE_Y = 8.0
GATE_Z = 6.6
ROWS = 3
COLS = 4
MAX_TRIS = 1500


def make_material(name: str, rgba: tuple[float, float, float, float]):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = rgba
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = rgba
        bsdf.inputs["Roughness"].default_value = 0.72
    return mat


def create_chunk(index: int, row: int, col: int, mat_wood, mat_iron) -> bpy.types.Object:
    chunk_y = GATE_Y / COLS
    chunk_z = GATE_Z / ROWS
    cx = 0.0
    cy = -GATE_Y * 0.5 + (col + 0.5) * chunk_y
    cz = (row + 0.5) * chunk_z

    # Pequena variacao organica sem alterar o volume util do portao
    jitter_y = ((index % 3) - 1) * 0.05
    jitter_z = (((index * 7) % 3) - 1) * 0.04
    sx = GATE_X * (0.94 if (row + col) % 2 == 0 else 0.90)
    sy = chunk_y * 0.94
    sz = chunk_z * 0.94

    mesh = bpy.data.meshes.new(f"WALL_gate_chunk_{index:02d}_Mesh")
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector((sx, sy, sz)), verts=bm.verts)
    bm.to_mesh(mesh)
    bm.free()

    obj = bpy.data.objects.new(f"WALL_gate_chunk_{index:02d}", mesh)
    obj.location = Vector((cx, cy + jitter_y, cz + jitter_z))
    obj.data.materials.append(mat_iron if (index == 5 or index == 8) else mat_wood)
    bpy.context.collection.objects.link(obj)
    return obj


def main() -> int:
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", default=os.path.join(ROOT, "build", "art-preview"))
    parser.add_argument("--export-lfs", action="store_true", help="Salva tambem em art/export/gate_fractured.glb")
    args = parser.parse_args(argv)

    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "NONE"
    scene.unit_settings.scale_length = 1.0

    mat_wood = make_material("MAT_GateWood", (0.42, 0.26, 0.14, 1.0))
    mat_iron = make_material("MAT_GateIron", (0.18, 0.21, 0.25, 1.0))

    chunks = []
    idx = 0
    for r in range(ROWS):
        for c in range(COLS):
            idx += 1
            chunks.append(create_chunk(idx, r, c, mat_wood, mat_iron))

    total_tris = sum(sum(max(1, len(p.vertices) - 2) for p in obj.data.polygons) for obj in chunks)
    if len(chunks) != 12 or total_tris > MAX_TRIS:
        raise RuntimeError(f"Orcamento violado: chunks={len(chunks)} tris={total_tris} max={MAX_TRIS}")

    out_dir = os.path.join(ROOT, "art", "export") if args.export_lfs else args.out
    os.makedirs(out_dir, exist_ok=True)
    glb_path = os.path.join(out_dir, "gate_fractured.glb")

    bpy.ops.export_scene.gltf(
        filepath=glb_path,
        export_format="GLB",
        export_apply=True,
        export_cameras=False,
        export_lights=False,
    )
    print(f"FRACTURE_GATE_OK chunks={len(chunks)} tris={total_tris} out={glb_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
