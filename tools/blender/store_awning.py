# 가게 3D 차양(Plane.003)을 물결 한 칸씩 번갈아 두 메시로 나눔 (사용자 2026-11-24: "천막 한 칸 걸러 한 칸은 아이보리색으로")
#   Studio 차양 = PlotLayout.ShopModel["Plane.003_Node"]["Plane.003"] (MeshPart 하나 → 색 하나라 칸마다 색을 못 나눔).
#   물결(스캘럽) 13칸, 한 칸 폭 = 전체 폭 / 13. 면 가운데 X로 칸 번호를 정해 짝수 칸 = Awning_A(살구색), 홀수 칸 = Awning_B(아이보리).
#   같이 원본 통째 Awning_Ref도 내보냄 → Studio에서 Ref를 예전 Plane.003에 맞추는 변환으로 A·B를 같은 자리에 놓고 Ref는 지움.
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/store_awning.py -- <store_lowcoil.glb> <출력 폴더>
# 결과: <출력>/store_awning_split.glb (Awning_A, Awning_B, Awning_Ref), store_awning_preview.png

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = argv[0], os.path.abspath(argv[1])
os.makedirs(OUT, exist_ok=True)
N = 13  # 물결 칸 수

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
src = next(o for o in bpy.data.objects if o.type == "MESH" and o.name == "Plane.003")
mw = src.matrix_world.copy()
xs = [(mw @ v.co).x for v in src.data.vertices]
x0, x1 = min(xs), max(xs)
step = (x1 - x0) / N
print(f"[awning] x {x0:.3f}..{x1:.3f}, 칸 폭 {step:.4f}")


def make(name, keep):
    bm = bmesh.new()
    bm.from_mesh(src.data)
    bm.transform(mw)
    bad = []
    for f in bm.faces:
        cx = f.calc_center_median().x
        k = min(int((cx - x0) / step), N - 1)
        if keep is not None and (k % 2) != keep:
            bad.append(f)
    bmesh.ops.delete(bm, geom=bad, context="FACES")
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    return o


a = make("Awning_A", 0)
b = make("Awning_B", 1)
ref = make("Awning_Ref", None)
for o in list(bpy.data.objects):
    if o not in (a, b, ref):
        bpy.data.objects.remove(o, do_unlink=True)
for o, col in ((a, (0.85, 0.42, 0.2, 1)), (b, (0.95, 0.9, 0.8, 1)), (ref, (1, 1, 1, 1))):
    m = bpy.data.materials.new(o.name)
    m.diffuse_color = col
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = col
    o.data.materials.append(m)
    o.select_set(True)
print(f"[awning] A {len(a.data.polygons)} / B {len(b.data.polygons)} / Ref {len(ref.data.polygons)} faces")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "store_awning_split.glb"), export_format="GLB", use_selection=True)

ref.hide_render = True
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
bpy.context.scene.collection.objects.link(cam)
bpy.context.scene.camera = cam
c = (Vector((x0, 0, 0)) + Vector((x1, 0, 0))) / 2
cam.location = Vector((c.x, -30, 14))
cam.rotation_euler = (Vector((c.x, -5, 9.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.rotation_euler = (math.radians(50), 0, math.radians(-20))
bpy.context.scene.collection.objects.link(sun)
sc = bpy.context.scene
sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x, sc.render.resolution_y = 1400, 500
sc.render.filepath = os.path.join(OUT, "store_awning_preview.png")
bpy.ops.render.render(write_still=True)
print("[awning] done")
