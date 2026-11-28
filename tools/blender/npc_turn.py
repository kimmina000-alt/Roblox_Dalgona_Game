# 손님 NPC glb 돌려 보기 (수정 전후 비교용, 2026-11-28). 서 있는 자세 앞 · 옆 · 뒤 · 반대 옆을 손님마다 한 줄로 찍음.
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/npc_turn.py -- <customers.glb> <출력 png> [id ...]
import math
import os
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
GLB, OUT = os.path.abspath(argv[0]), os.path.abspath(argv[1])
ONLY = set(argv[2:])
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=GLB)
roots = sorted([o for o in scene.objects if o.name.startswith("Customer_") and (not ONLY or o.name[9:] in ONLY)], key=lambda o: o.name)
for o in scene.objects:
    if o.parent is None:
        o.location = (0, 0, 0)
        o.rotation_euler = (0, 0, 0)
        o.rotation_mode = "XYZ"
        o.hide_render = True
for o in scene.objects:
    if o.type == "MESH":
        o.hide_render = True
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.98, 0.94, 0.88, 1)
scene.world = world
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-25))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.type = "ORTHO"
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "BLENDER_EEVEE"
scene.view_settings.view_transform = "Standard"
YAWS = (0, 90, 180, 270)
rows = len(roots)
scene.render.resolution_x, scene.render.resolution_y = 1600, 460 * rows
cam.data.ortho_scale = 4 * 3.4
made = []
for i, r in enumerate(roots):
    kids = [c for c in r.children if c.type == "MESH"]
    for k, yaw in enumerate(YAWS):
        e = bpy.data.objects.new("e", None)
        scene.collection.objects.link(e)
        e.location = ((k - 1.5) * 3.2, 0, -(i - (rows - 1) / 2) * 4.6 - 1.9)
        e.rotation_euler = (0, 0, math.radians(yaw))
        for c in kids:
            c2 = c.copy()
            scene.collection.objects.link(c2)
            c2.parent = e
            c2.matrix_parent_inverse.identity()
            c2.matrix_basis = r.matrix_basis.inverted() @ c.matrix_world if False else c.matrix_local
            c2.hide_render = False
            made.append(c2)
cam.data.ortho_scale = max(4 * 3.2 + 0.6, rows * 4.6)
cam.location = (0, -30, 0)
cam.rotation_euler = (math.radians(90), 0, 0)
scene.render.filepath = OUT
bpy.ops.render.render(write_still=True)
print("[turn] wrote", OUT, [r.name for r in roots])
