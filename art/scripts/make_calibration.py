"""Gera a cena de calibracao do pipeline Blender -> Studio.

Uso:
  blender4.5 -b --factory-startup --python art/scripts/make_calibration.py

Saidas:
  art/calibration.blend
  art/export/calibration.glb
  art/export/calibration.fbx
  art/renders/calibration.png (ignorado pelo git)
"""

import math
import os

import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ART = os.path.join(ROOT, "art")
EXPORT = os.path.join(ART, "export")
RENDERS = os.path.join(ART, "renders")
os.makedirs(EXPORT, exist_ok=True)
os.makedirs(RENDERS, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.unit_settings.system = "NONE"
scene.unit_settings.scale_length = 1.0
try:
    scene.unit_settings.rotation_units = "DEGREES"
except Exception:
    pass


def material(name, color):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = 0.6
    return mat


def apply(obj):
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    obj.select_set(False)


def box(name, location, scale, color):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    apply(obj)
    obj.data.materials.append(material(name + "_MAT", color))
    return obj


def text(name, body, location, size=0.35):
    bpy.ops.object.text_add(location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.body = body
    obj.data.size = size
    obj.data.extrude = 0.02
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.object
    obj.data.materials.append(material(name + "_MAT", (0.95, 0.93, 0.85)))
    return obj


# 1 stud: cubo de referencia
box("CUBO_1_STUD", (0, 0, 0.5), (1, 1, 1), (0.55, 0.55, 0.6))
text("TXT_1_STUD", "1 stud", (0, 1.1, 0.05), 0.25)

# 4 studs no eixo X (vermelho)
box("BARRA_4_STUDS_X", (2, 0, 0.15), (4, 0.2, 0.2), (0.85, 0.2, 0.2))
text("TXT_4_STUDS", "4 studs", (2, 0.45, 0.05), 0.28)

# eixos Y (verde) e Z (azul)
box("EIXO_Y", (0, 0.9, 0.1), (0.2, 1.6, 0.2), (0.2, 0.75, 0.3))
box("EIXO_Z", (0, 0, 1.2), (0.2, 0.2, 2.2), (0.2, 0.4, 0.9))

# seta apontando para -Y = frente no Blender
bpy.ops.mesh.primitive_cylinder_add(radius=0.07, depth=1.4, location=(0, -1.55, 0.1), rotation=(math.radians(90), 0, 0))
shaft = bpy.context.object
shaft.name = "SETA_FRENTE_SHAFT"
shaft.data.materials.append(material("SETA_MAT", (0.95, 0.75, 0.2)))

bpy.ops.mesh.primitive_cone_add(radius1=0.28, depth=0.7, location=(0, -2.55, 0.1), rotation=(math.radians(-90), 0, 0))
tip = bpy.context.object
tip.name = "SETA_FRENTE_TIP"
tip.data.materials.append(material("SETA_TIP_MAT", (0.95, 0.75, 0.2)))

text("TXT_FRENTE", "FRENTE (-Y)", (0, -3.3, 0.05), 0.3)

# camera e luz para o render de conferencia
bpy.ops.object.camera_add(location=(8, -8, 6))
cam = bpy.context.object
cam.name = "CAMERA_CALIBRACAO"
direction = Vector((1.0, 0.0, 0.5)) - cam.location
cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
scene.camera = cam

bpy.ops.object.light_add(type="SUN", location=(4, -6, 8))
sun = bpy.context.object
sun.name = "SUN_CALIBRACAO"
sun.data.energy = 3.0

scene.render.engine = "BLENDER_WORKBENCH"
scene.render.resolution_x = 960
scene.render.resolution_y = 640
scene.render.filepath = os.path.join(RENDERS, "calibration.png")
bpy.ops.render.render(write_still=True)

blend = os.path.join(ART, "calibration.blend")
bpy.ops.wm.save_as_mainfile(filepath=blend)

glb = os.path.join(EXPORT, "calibration.glb")
bpy.ops.export_scene.gltf(
    filepath=glb,
    export_format="GLB",
    export_apply=True,
    export_cameras=False,
    export_lights=False,
)

fbx = os.path.join(EXPORT, "calibration.fbx")
bpy.ops.export_scene.fbx(
    filepath=fbx,
    use_selection=False,
    apply_scale_options="FBX_SCALE_NONE",
    bake_space_transform=False,
)

bar = bpy.data.objects.get("BARRA_4_STUDS_X")
cube = bpy.data.objects.get("CUBO_1_STUD")
print("CALIBRACAO_OK")
print("blend", blend)
print("glb", glb)
print("fbx", fbx)
if bar:
    print("barra dimensoes", tuple(round(v, 3) for v in bar.dimensions))
if cube:
    print("cubo dimensoes", tuple(round(v, 3) for v in cube.dimensions))
