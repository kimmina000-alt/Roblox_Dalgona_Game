# 사용자가 만든 2·3단계 기계 (2026-11-26, 레퍼런스/store-2.glb): 2단계 = 빨간 철제 달고나 기계, 3단계 = 분홍 달고나 판매기(자판기)
#   store-2.glb에는 예전 가게 장면 전체가 같이 들어 있음 → 기계 두 대의 오브젝트만 씀.
#   사용자 말: "메테리얼에 사용한 이미지 여러 장인데 메모리 아낄 수 있는 효율적인 방법으로 정돈해"
#   → 이미지 7장(1254² ×3, 1244², 1136×586, 850², 190×298 ×2)을 1024×1024 아틀라스 한 장에 모으고 UV를 그 칸으로 옮김.
#     Roblox는 어차피 텍스처를 1024로 줄이므로 7장(최대 7 × 1024²) → 1장(1024²): 텍스처 메모리 약 1/6, 메시도 기계마다 MeshPart 1개(드로콜 감소).
#     1-2(위판)는 위쪽 1/4만 쓰여서 그 부분만 잘라 넣음. 색만 있는 재질(Coil 검정·Aluminum 회색)은 아틀라스 작은 색 칸.
#   기계마다 바닥 가운데 = 원점, 앞(그림 있는 면) = Blender -Y (Roblox -Z). 2단계는 x −4, 3단계는 x +4에 놓아 내보냄.
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/stage23_user.py -- <store-2.glb> <출력 폴더>
# 결과: dalgona_stage23_user.glb (Stage2Machine, Stage3Machine, 텍스처 = 아틀라스 1장), stage23_atlas.png, stage23_user_preview.png, stage23_user_parts.txt

import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = argv[0], os.path.abspath(argv[1])
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)

STAGE2 = ["Cube.032", "Cube.033", "Cube.034", "Cube.035", "Cube.036", "Cube.090", "Cylinder.006", "Cylinder.007", "Cylinder.008", "Cylinder.011"]
STAGE3 = ["Cube.026", "Cube.027", "Cube.028", "Cube.029", "Cube.030", "Cube.031", "Cylinder.003", "Cylinder.004", "Cylinder.005"]
FRONT_MAT = {"Stage2Machine": "Material.009", "Stage3Machine": "Material"}   # 그림 있는 앞면 재질 (1-1 / 2-1)

A = 1024
# 아틀라스 칸: 이미지 이름 → (x, y, w, h) 픽셀(왼쪽 위 원점), crop = 원본 v 범위(아래 원점)
RECT = {
    "1-1": (0, 0, 512, 512, None),          # 2단계 앞면 (달고나 그림)
    "2-1": (512, 0, 512, 264, None),        # 3단계 앞 그림판
    "1-2": (512, 264, 512, 128, (0.75, 1.0)),  # 2단계 위판 (위쪽 1/4만 씀)
    "1-3": (512, 392, 256, 256, None),      # 2단계 옆·뒤 (빨간 철판)
    "2-4": (768, 392, 256, 256, None),      # 3단계 몸통 (분홍)
    "2-2": (0, 512, 128, 200, None),        # 동전 넣는 판
    "1-4": (128, 512, 128, 200, None),      # 민판
}
SWATCH = {"Coil": ((256, 512, 32, 32), (30, 28, 26)), "Aluminum": ((288, 512, 32, 32), (178, 180, 176)), "Aluminum.001": ((288, 512, 32, 32), (178, 180, 176))}


def mat_image(m):
    if m and m.use_nodes:
        for n in m.node_tree.nodes:
            if n.type == "TEX_IMAGE" and n.image:
                return n.image
    return None


# ── 아틀라스 그림 ──
atlas = np.zeros((A, A, 4), dtype=np.float32)
atlas[:, :, 3] = 1
atlas[:, :, :3] = 0.5
for im in bpy.data.images:
    if im.name not in RECT:
        continue
    x, y, w, h, crop = RECT[im.name]
    src = im.copy()
    if crop:
        W0, H0 = src.size
        px = np.array(src.pixels[:], dtype=np.float32).reshape(H0, W0, 4)
        y0, y1 = int(crop[0] * H0), int(crop[1] * H0)
        sub = px[y0:y1]
        src = bpy.data.images.new(im.name + "_crop", W0, y1 - y0, alpha=True)
        src.pixels.foreach_set(sub.ravel())
    src.scale(w, h)
    px = np.array(src.pixels[:], dtype=np.float32).reshape(h, w, 4)   # 아래 원점
    atlas[A - y - h:A - y, x:x + w] = px
for _, ((x, y, w, h), rgb) in SWATCH.items():
    atlas[A - y - h:A - y, x:x + w, :3] = (np.array(rgb) / 255.0) ** 2.2
img = bpy.data.images.new("Stage23Atlas", A, A, alpha=False)
img.pixels.foreach_set(atlas.ravel())
img.filepath_raw = os.path.join(OUT, "stage23_atlas.png")
img.file_format = "PNG"
img.save()
img.pack()

mat = bpy.data.materials.new("Stage23Atlas")
mat.use_nodes = True
bsdf = mat.node_tree.nodes["Principled BSDF"]
bsdf.inputs["Roughness"].default_value = 0.6
tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
tex.image = img
mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])


def remap(u, v, m):
    """원래 이미지 UV → 아틀라스 UV."""
    im = mat_image(m)
    if im is None or im.name not in RECT:
        (x, y, w, h), _ = SWATCH.get(m.name if m else "", SWATCH["Aluminum"])
        return ((x + w / 2) / A, 1 - (y + h / 2) / A)
    x, y, w, h, crop = RECT[im.name]
    u = min(max(u, 0.0), 1.0)
    v = min(max(v, 0.0), 1.0)
    if crop:
        v = (v - crop[0]) / (crop[1] - crop[0])
        v = min(max(v, 0.0), 1.0)
    pad = 0.5
    uu = (x + pad + u * (w - 2 * pad)) / A
    vv = 1 - (y + pad + (1 - v) * (h - 2 * pad)) / A
    return (uu, vv)


def build(name, objs, place_x):
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    front_n = Vector((0, 0, 0))
    front_a = [0.0]
    for on in objs:
        o = bpy.data.objects[on]
        me = o.data
        tmp = bmesh.new()
        tmp.from_mesh(me)
        tmp.transform(o.matrix_world)
        src_uv = tmp.loops.layers.uv.active
        for f in tmp.faces:
            m = me.materials[f.material_index] if me.materials else None
            for l in f.loops:
                l[src_uv].uv = remap(l[src_uv].uv.x, l[src_uv].uv.y, m)
            if m and m.name == FRONT_MAT[name]:
                front_n += f.calc_center_median() * f.calc_area()   # 앞 그림 면들의 무게 중심 (얇은 판은 법선이 양쪽이라 위치로 봄)
                front_a[0] += f.calc_area()
        tmp.normal_update()
        t = bpy.data.meshes.new("t")
        tmp.to_mesh(t)
        tmp.free()
        bm.from_mesh(t)
        bpy.data.meshes.remove(t)
    # 앞 방향 = 기계 가운데 → 앞 그림 면 무게 중심 (수평), 그걸 -Y로 돌림
    xs0 = [v.co.x for v in bm.verts]
    ys0 = [v.co.y for v in bm.verts]
    mid = Vector(((min(xs0) + max(xs0)) / 2, (min(ys0) + max(ys0)) / 2, 0))
    fc = front_n / front_a[0]
    fn = Vector((fc.x - mid.x, fc.y - mid.y, 0)).normalized()
    ang = math.atan2(fn.x, -fn.y)          # fn을 (0,-1)로 보내는 z축 회전 = -ang
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(ang, 3, "Z"))
    xs = [v.co.x for v in bm.verts]
    ys = [v.co.y for v in bm.verts]
    zs = [v.co.z for v in bm.verts]
    off = Vector(((min(xs) + max(xs)) / 2 - place_x, (min(ys) + max(ys)) / 2, min(zs)))
    for v in bm.verts:
        v.co -= off
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.materials.append(mat)
    o = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(o)
    size = Vector((max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)))
    rsize = Matrix.Rotation(ang, 3, "Z") @ size
    print(f"[stage23] {name}: 앞 방향 {tuple(round(c, 2) for c in fn)} → -Y (z {math.degrees(ang):.0f}°), 삼각형 {sum(len(p.vertices) - 2 for p in me.polygons)}")
    return o


s2 = build("Stage2Machine", STAGE2, -4.0)
s3 = build("Stage3Machine", STAGE3, 4.0)
for o in list(bpy.data.objects):
    if o not in (s2, s3):
        bpy.data.objects.remove(o, do_unlink=True)
rows = []
for o in (s2, s3):
    vs = [v.co for v in o.data.vertices]
    lo = Vector([min(v[i] for v in vs) for i in range(3)])
    hi = Vector([max(v[i] for v in vs) for i in range(3)])
    s, c = hi - lo, (lo + hi) / 2
    rows.append(f"{o.name}\ttris={sum(len(p.vertices) - 2 for p in o.data.polygons)}\tsize(Roblox x,y,z)=({s.x:.2f}, {s.z:.2f}, {s.y:.2f})\tcenter=({-c.x:.2f}, {c.z:.2f}, {c.y:.2f})")
open(os.path.join(OUT, "stage23_user_parts.txt"), "w", encoding="utf-8").write("\n".join(rows) + "\n# 원점 기준, 앞 = Roblox -Z, 바닥 = y 0. 텍스처 = stage23_atlas.png 한 장 공용\n")
print("\n".join(rows))
s2.select_set(True)
s3.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "dalgona_stage23_user.glb"), export_format="GLB", use_selection=True)

# 미리 보기
sc = bpy.context.scene
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.lens = 35
cam.location = (3.0, -16.0, 6.5)
cam.rotation_euler = (Vector((0, 0, 2.6)) - cam.location).to_track_quat("-Z", "Y").to_euler()
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3
sun.rotation_euler = (math.radians(50), 0, math.radians(-25))
sc.collection.objects.link(sun)
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
sc.world = world
sc.render.engine = "BLENDER_EEVEE"
sc.render.resolution_x, sc.render.resolution_y = 1200, 800
sc.view_settings.view_transform = "Standard"
sc.render.filepath = os.path.join(OUT, "stage23_user_preview.png")
bpy.ops.render.render(write_still=True)
print("[stage23] done")
