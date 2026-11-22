# 사용자 가게 3D(store.glb)의 2단계 기계 화구 코일 단순화 (사용자 2026-11-23: "코일 단순화해")
#   원본: 오브젝트 Cube.015 (메시 Cube.021) — 화구 2개마다 납작한 나선 판 2장(위·아래), 삼각형 3,520개 (기계 전체 3,912).
#   바꿈: 나선 판을 지우고, 화구마다 어두운 원판 1장 + 동심원 고리 3개(낮은 면 수)로 다시 만듦. 재질 "Coil" 그대로.
#   원본 store.glb·store.blend는 건드리지 않음. 결과:
#     <출력>/store_machine2_lowcoil.glb  — 이 기계 하나만 (Studio에서 같은 자리 부품을 바꿔 끼움)
#     <출력>/store_lowcoil.glb           — 가게 전체 (코일만 바뀜)
#     <출력>/store_coil_before_after.png — 바꾸기 전·후 비교
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/store_coil_fix.py -- <store.glb> <출력 폴더>

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = argv[0], os.path.abspath(argv[1])
os.makedirs(OUT, exist_ok=True)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
sc = bpy.context.scene
o = sc.objects["Cube.015"]
me = o.data
coil_idx = [i for i, m in enumerate(me.materials) if m and m.name == "Coil"][0]
before = sum(len(p.vertices) - 2 for p in me.polygons)

bm = bmesh.new()
bm.from_mesh(me)
coil_faces = [f for f in bm.faces if f.material_index == coil_idx]
# 화구 가운데·반지름·높이 (나선 판 두 장의 범위에서, 로컬 좌표)
pts = [v.co.copy() for f in coil_faces for v in f.verts]
xs = sorted(p.x for p in pts)
midx = (xs[0] + xs[-1]) / 2
groups = [[p for p in pts if p.x < midx], [p for p in pts if p.x >= midx]]
burners = []
for g in groups:
    lo = Vector([min(p[i] for p in g) for i in range(3)])
    hi = Vector([max(p[i] for p in g) for i in range(3)])
    c = (lo + hi) / 2
    r = max(hi.x - lo.x, hi.y - lo.y) / 2
    burners.append((c, r, lo, hi))
bmesh.ops.delete(bm, geom=list({v for f in coil_faces for v in f.verts}), context="VERTS")

# 위 방향 = 나선 판이 납작한 축 (가장 얇은 축)
c0, r0, lo0, hi0 = burners[0]
ext = hi0 - lo0
up_axis = min(range(3), key=lambda i: ext[i])
UP = Vector([1.0 if i == up_axis else 0.0 for i in range(3)])
R3 = Vector((0, 0, 1)).rotation_difference(UP).to_matrix().to_4x4()


def tag(new_faces):
    for f in new_faces:
        f.material_index = coil_idx
        f.smooth = True


for c, r, lo, hi in burners:
    base = c - UP * (ext[up_axis] / 2)
    # 어두운 원판 (두께 아주 얇게)
    res = bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=20, radius1=r * 0.98, radius2=r * 0.98,
                                depth=0.02, matrix=Matrix.Translation(base + UP * 0.01) @ R3)
    tag({f for v in res["verts"] for f in v.link_faces})
    # 동심원 고리 3개 (튜브 단면 4각, 둘레 16·20·24칸)
    for k, (rr, useg) in enumerate(((r * 0.3, 14), (r * 0.58, 18), (r * 0.86, 22))):
        tube = 0.035
        M = Matrix.Translation(base + UP * (0.02 + tube)) @ R3
        rings = []
        for i in range(useg):
            u = 2 * math.pi * i / useg
            ring = []
            for j in range(4):
                w = 2 * math.pi * j / 4 + math.pi / 4
                rad = rr + tube * math.cos(w)
                ring.append(bm.verts.new(M @ Vector((rad * math.cos(u), rad * math.sin(u), tube * math.sin(w)))))
            rings.append(ring)
        nf = []
        for i in range(useg):
            A, B = rings[i], rings[(i + 1) % useg]
            for j in range(4):
                j2 = (j + 1) % 4
                nf.append(bm.faces.new((A[j], B[j], B[j2], A[j2])))
        bmesh.ops.recalc_face_normals(bm, faces=nf)
        tag(nf)
bm.to_mesh(me)
bm.free()
after = sum(len(p.vertices) - 2 for p in me.polygons)
print(f"[coil] {o.name} (mesh {me.name}) tris {before} -> {after}, burners at {[tuple(round(x, 2) for x in b[0]) for b in burners]}")

bpy.ops.object.select_all(action="DESELECT")
for ob in sc.objects:
    ob.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "store_lowcoil.glb"), export_format="GLB", use_selection=True)
bpy.ops.object.select_all(action="DESELECT")
o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "store_machine2_lowcoil.glb"), export_format="GLB", use_selection=True)

# 비교 그림: 원본(왼쪽) · 단순화(오른쪽)
had = set(sc.objects)
bpy.ops.import_scene.gltf(filepath=SRC)
new = [ob for ob in sc.objects if ob not in had]
orig = [ob for ob in new if ob.type == "MESH" and len(ob.data.polygons) == before][0]  # 원본 기계 (면 수로 찾음)
for ob in new:
    if ob != orig:
        bpy.data.objects.remove(ob, do_unlink=True)
for ob in list(sc.objects):
    if ob not in (o, orig) and ob.type == "MESH":
        bpy.data.objects.remove(ob, do_unlink=True)
orig.location.x -= 6.0
mat = bpy.data.materials.new("Body")
mat.use_nodes = True
mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.62, 0.62, 0.64, 1)
for ob in (o, orig):
    for i, m in enumerate(ob.data.materials):
        if m is None:
            ob.data.materials[i] = mat
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
sc.collection.objects.link(cam)
sc.camera = cam
ctr = (o.matrix_world @ Vector(c0) + orig.matrix_world @ Vector(c0)) / 2
cam.location = ctr + Vector((0, -7.5, 7.5))
cam.rotation_euler = (ctr - cam.location).to_track_quat("-Z", "Y").to_euler()
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.5
sun.rotation_euler = (0.6, 0.2, 0.4)
sc.collection.objects.link(sun)
w = bpy.data.worlds.new("W")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
sc.world = w
sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x, sc.render.resolution_y = 1600, 900
sc.view_settings.view_transform = "Standard"
sc.render.filepath = os.path.join(OUT, "store_coil_before_after.png")
bpy.ops.render.render(write_still=True)
print("[coil] done")
