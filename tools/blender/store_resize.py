# 가게 3D(store_lowcoil.glb) 고치기 (사용자 2026-11-25):
#   1) "매장 너비 넓히기" — 앞 가게 방(셔터 벽 ↔ 뒷벽, 4단계 기계 쪽)이 좁아서, 앞 가게 방 뒷벽을 뒤(공장 방 쪽)로 DEPTH만큼 밂.
#      뒷벽·뒷벽 앞 튀어나온 칸·바닥·앞 지붕의 그 부분 정점만 옮김 → 가게 방은 깊어지고, 공장 가는 복도는 그만큼 짧아짐.
#      공장 방·건물 전체 길이·폭은 그대로라 옆 가게와 안 겹침 (G.Plots.spacing 그대로).
#   2) "창문 내리면서 벽에 난 구멍도 내려야 함" — 공장 방 양쪽 창 구멍을 WIN_DROP만큼 내림 (Studio에서 창문을 4칸 내렸음).
# 좌표: 이 glb는 Studio에서 1.5배. Studio 4칸 = glb 4/1.5.
#   Studio X = -99.97 + 1.5(x-8.51), Y = 12.30 + 1.5(z-7.93), Z = -92.51 - 1.5(y-22.04)  (Plot1 틀 기준)
# 내보냄: ShopWall_New(벽), ShopFloor_New(바닥), FrontRoof_New(앞 지붕), Ref_FactoryRoof(안 바뀐 공장 방 지붕 = Studio 맞춤 기준, 맞춘 뒤 지움)
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/store_resize.py -- <store_lowcoil.glb> <출력 폴더>
# 결과: store_resized.glb, store_resize_plan.png(위에서 본 전/후), store_resize_side.png

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = argv[0], os.path.abspath(argv[1])
os.makedirs(OUT, exist_ok=True)

DEPTH = 3.0            # glb 단위 (Studio 4.5칸). 앞 가게 방 깊이 15.9 → 18.9 (Studio 23.9 → 28.4)
WIN_DROP = 4.0 / 1.5   # Studio 4칸
BACK_Y = (12.0, 15.3)  # 앞 가게 방 뒷벽·튀어나온 칸 정점 y 범위 (그다음 벽은 공장 방 앞벽 y 20.6)
WIN_Y = (28.8, 39.3)   # 공장 방 창 구멍 y 범위
WIN_Z = (6.0, 14.5)    # 창 구멍 높이 범위

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
objs = {o.name: o for o in bpy.data.objects if o.type == "MESH"}


def edit(name, new_name, fn):
    src = objs[name]
    bm = bmesh.new()
    bm.from_mesh(src.data)
    bm.transform(src.matrix_world)
    n = fn(bm)
    me = bpy.data.meshes.new(new_name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(new_name, me)
    bpy.context.scene.collection.objects.link(o)
    print(f"[store] {new_name}: 정점 {n} 옮김")
    return o


def push_back(bm):
    n = 0
    for v in bm.verts:
        if BACK_Y[0] <= v.co.y <= BACK_Y[1]:
            v.co.y += DEPTH
            n += 1
    return n


def wall(bm):
    n = push_back(bm)
    for v in bm.verts:
        if WIN_Y[0] <= v.co.y <= WIN_Y[1] and WIN_Z[0] <= v.co.z <= WIN_Z[1]:
            v.co.z -= WIN_DROP
            n += 1
    return n


def roof(bm):
    n = 0
    for v in bm.verts:
        if v.co.y >= BACK_Y[0]:
            v.co.y += DEPTH
            n += 1
    return n


for nm in ("Plane", "ShopFloor", "Cube.014"):
    print(f"[store] {nm} y 값: {sorted(set(round((objs[nm].matrix_world @ v.co).y, 2) for v in objs[nm].data.vertices))}")

new = [
    edit("Plane", "ShopWall_New", wall),
    edit("ShopFloor", "ShopFloor_New", push_back),
    edit("Cube.014", "FrontRoof_New", roof),
    edit("Cube.024", "Ref_FactoryRoof", lambda bm: 0),
]
for o in new:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "store_resized.glb"), export_format="GLB", use_selection=True)

# ── 미리 보기: 위에서 본 전(왼쪽)·후(오른쪽), 옆에서 본 창 구멍 ──
keep = {"Plane", "ShopFloor", "Cube.001", "Cube.004", "Cube.019", "Cube.022", "Cube.020", "Cube.021"}
for o in list(bpy.data.objects):
    if o.type == "MESH" and o not in new and o.name not in keep:
        bpy.data.objects.remove(o, do_unlink=True)
bpy.data.objects.remove(bpy.data.objects["Ref_FactoryRoof"], do_unlink=True)
bpy.data.objects.remove(bpy.data.objects["FrontRoof_New"], do_unlink=True)
for o in new[:2]:
    o.location.x += 34
for nm in ("Cube.019", "Cube.022", "Cube.020", "Cube.021"):   # 창문은 Studio에서 내리는 값 그대로 보여 줌
    c = bpy.data.objects[nm].copy()
    c.data = bpy.data.objects[nm].data
    c.location.x += 34
    c.location.z -= WIN_DROP
    bpy.context.scene.collection.objects.link(c)
sc = bpy.context.scene
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.type = "ORTHO"
cam.data.ortho_scale = 70
cam.location = (25.5, 22, 80)
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.rotation_euler = (math.radians(30), math.radians(20), 0)
sc.collection.objects.link(sun)
sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x, sc.render.resolution_y = 1100, 1000
sc.render.filepath = os.path.join(OUT, "store_resize_plan.png")
bpy.ops.render.render(write_still=True)
cam.data.type = "PERSP"
cam.location = (34 + 45, 34, 9)
cam.rotation_euler = (Vector((34 + 8, 34, 8)) - cam.location).to_track_quat("-Z", "Y").to_euler()
sc.render.resolution_x, sc.render.resolution_y = 1200, 700
sc.render.filepath = os.path.join(OUT, "store_resize_side.png")
bpy.ops.render.render(write_still=True)
print("[store] done")
