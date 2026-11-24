# 고등어 아저씨 — 사용자가 직접 다듬은 모델(레퍼런스/NPC1.glb, 삼각형 12,064개, T자)에 색 칠하기 (2026-11-25)
#   그 glb의 텍스처는 투영이 어긋나(얼굴·셔츠에 초록 얼룩) 새로 칠함: 사용자 참고 그림 = 회색 고등어 줄무늬 고양이,
#   노란 반쯤 감은 눈, 분홍 코·귀 안, 흰 콧수염·턱수염, 흰 민소매, 초록 운동복 바지(흰 허리끈·옆줄 2개), 줄무늬 꼬리.
#   방법: 새 UV를 펴고, UV 칸마다 3D 위치·면 방향으로 색을 정해 1024 텍스처에 직접 그림 (부위 = 높이·좌우·앞뒤 규칙).
#   결과 = 레퍼런스/customers_ai/Godeungeo_low.glb (손님 AI판과 같은 자리) → customers_ai.py가 부품으로 나눔.
#
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/npc1_paint.py -- <레퍼런스/NPC1.glb> <레퍼런스/customers_ai>
# 좌표 (칠하기 규칙): 키 3.79 stud, 원점 = 두 발 가운데 바닥, 앞 = -Y, 왼쪽 = +X (customers_ai와 같음).

import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = argv[0], argv[1]
HEIGHT, RES = 3.79, 1024

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=SRC)
o = [x for x in scene.objects if x.type == "MESH"][0]
for x in list(scene.objects):
    if x is not o:
        bpy.data.objects.remove(x, do_unlink=True)
me = o.data
me.transform(o.matrix_world)
o.matrix_world = Matrix.Identity(4)
o.name = me.name = "Godeungeo"
# 키·원점 맞추기 (발바닥 가운데)
co = np.array([v.co[:] for v in me.vertices])
lo = co[:, 2].min()
feet = co[co[:, 2] < lo + 0.04 * (co[:, 2].max() - lo)]
cx, cy = (feet[:, 0].min() + feet[:, 0].max()) / 2, (feet[:, 1].min() + feet[:, 1].max()) / 2
k = HEIGHT / (co[:, 2].max() - lo)
me.transform(Matrix.Diagonal((k, k, k, 1)) @ Matrix.Translation((-cx, -cy, -lo)))
# 혼자 떨어진 점 지우기 + 새 UV
bm = bmesh.new()
bm.from_mesh(me)
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bm.to_mesh(me)
bm.free()
while me.uv_layers:
    me.uv_layers.remove(me.uv_layers[0])
me.uv_layers.new(name="UVMap")
bpy.context.view_layer.objects.active = o
o.select_set(True)
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.006)
bpy.ops.uv.pack_islands(margin=0.006)
bpy.ops.object.mode_set(mode="OBJECT")

# ───────────── 색 ─────────────
C = {k_: np.array(v, dtype=np.float32) / 255 for k_, v in dict(
    FUR=(158, 158, 166), DARK=(98, 98, 110), LIGHT=(206, 206, 212), WHITE=(246, 244, 238), GREEN=(58, 142, 74),
    PINK=(240, 160, 170), YELLOW=(240, 204, 72), PUPIL=(34, 28, 30), LID=(120, 120, 130), SOLE=(132, 132, 140)).items()}


def colors(P, N):
    """P, N = (n, 3) 위치·면 방향 → (n, 3) 색 (0~1). 아래 규칙은 위에서 아래 순서로 덮어씀."""
    x, y, z = P[:, 0], P[:, 1], P[:, 2]
    nx, ny, nz = N[:, 0], N[:, 1], N[:, 2]
    ax = np.abs(x)
    col = np.tile(C["FUR"], (len(P), 1))

    def put(mask, c):
        col[mask] = C[c]

    # 발 (발바닥은 조금 어둡게)
    put(z < 0.24, "FUR")
    put((z < 0.06) & (nz < -0.5), "SOLE")
    # 초록 바지 + 옆 흰 줄 2개 + 허리끈
    pants = (z >= 0.24) & (z < 1.32) & ~((y > 0.55) & (z > 0.95))
    put(pants, "GREEN")
    side = pants & (np.sign(x) * nx > 0.45) & (z < 1.22)
    put(side & (np.abs(y + 0.0) < 0.05), "WHITE")
    put(side & (np.abs(y - 0.14) < 0.035), "WHITE")
    put((z > 0.85) & (z < 1.25) & (ax < 0.3) & (y < -0.68), "WHITE")
    # 꼬리 (뒤로 뻗음): 줄무늬 고리
    tail = (y > 0.55) & (z > 0.95) & (z < 1.45)
    put(tail, "FUR")
    put(tail & (np.mod(y, 0.36) < 0.13), "DARK")
    # 흰 민소매: 어깨로 갈수록 좁아지는 끈, 앞 목 파임
    tank = (z >= 1.32) & (z < 2.2) & (ax < 0.74 - np.clip(z - 1.75, 0, None) * 0.95)
    put(tank, "WHITE")
    # 팔: 털 + 줄무늬 (팔 길이 방향 띠), 손끝 밝게
    arm = (ax >= 0.74) & (z > 1.68) & (z < 2.32)
    put(arm, "FUR")
    put(arm & (np.mod(ax, 0.26) < 0.08) & (ax < 1.35) & (nz > -0.3), "DARK")
    put(arm & (ax > 1.42), "LIGHT")
    # 머리
    head = z >= 2.2
    put(head & (z > 2.6) & (ny > 0.25) & (np.mod(z - 2.6, 0.3) < 0.07) & (ax < 0.55), "DARK")  # 뒷머리 줄 3개
    put(head & (z > 3.02) & (z < 3.45) & (nz > -0.2) & (ny < 0.3)
        & ((np.abs(x) < 0.04) | (np.abs(np.abs(x) - 0.2) < 0.04)), "DARK")  # 이마 줄 3개
    put(head & (ax > 0.7) & (np.abs(z - 2.62) < 0.035), "DARK")  # 볼 줄
    put(head & (ax > 0.66) & (np.abs(z - 2.78) < 0.035), "DARK")
    # 귀 안 분홍
    put((z > 3.38) & (ax > 0.36) & (ax < 0.7) & (ny < -0.25), "PINK")
    # 흰 콧수염·턱수염 (앞으로 나온 주둥이)
    put((z >= 2.1) & ((x / 0.38) ** 2 + ((z - 2.36) / 0.24) ** 2 < 1) & (y < -0.5), "WHITE")  # 둥근 수염 덩어리
    # 분홍 코
    put((z > 2.57) & (z < 2.68) & (ax < 0.075 - (z - 2.57) * 0.0) & (y < -0.85), "PINK")
    # 눈: 반쯤 감은 노란 눈 + 세로 동공 + 위 눈꺼풀 선 + 찡그린 눈썹
    face = head & (ny < -0.3)
    for sx in (1, -1):
        ex, ez = 0.39 * sx, 2.88
        dx, dz = (x - ex) / 0.17, (z - ez) / 0.11
        eye = face & (dx * dx + dz * dz < 1)
        put(eye & (dz < 0.25), "YELLOW")
        put(eye & (dz >= 0.25), "LID")
        put(eye & (np.abs(dz - 0.25) < 0.16), "PUPIL")
        put(eye & (dz < 0.25) & (((x - (ex - sx * 0.03)) / 0.035) ** 2 + ((z - (ez - 0.01)) / 0.07) ** 2 < 1), "PUPIL")
        bx = x - (ex - sx * 0.05)
        put(face & (np.abs(z - (ez + 0.2 - sx * bx * 0.45)) < 0.022) & (np.abs(bx) < 0.16), "PUPIL")
    return col


# ───────────── UV에 그리기 ─────────────
me.calc_loop_triangles()
uvd = me.uv_layers.active.data
img = np.zeros((RES, RES, 3), dtype=np.float32)
filled = np.zeros((RES, RES), dtype=bool)
verts = np.array([v.co[:] for v in me.vertices])
for tri in me.loop_triangles:
    uv = np.array([uvd[l].uv[:] for l in tri.loops]) * RES - 0.5
    pv = verts[list(tri.vertices)]
    x0, y0 = np.floor(uv.min(0)).astype(int) - 1
    x1, y1 = np.ceil(uv.max(0)).astype(int) + 1
    x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, RES - 1), min(y1, RES - 1)
    if x1 < x0 or y1 < y0:
        continue
    gx, gy = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
    q = np.stack([gx.ravel(), gy.ravel()], 1).astype(np.float64)
    a, b, c = uv
    d = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
    if abs(d) < 1e-12:
        continue
    w0 = ((b[1] - c[1]) * (q[:, 0] - c[0]) + (c[0] - b[0]) * (q[:, 1] - c[1])) / d
    w1 = ((c[1] - a[1]) * (q[:, 0] - c[0]) + (a[0] - c[0]) * (q[:, 1] - c[1])) / d
    w2 = 1 - w0 - w1
    tol = -0.6 / max(np.ptp(uv[:, 0]), np.ptp(uv[:, 1]), 1)  # 경계 픽셀도 칠함
    inside = (w0 >= tol) & (w1 >= tol) & (w2 >= tol)
    if not inside.any():
        continue
    W = np.stack([w0, w1, w2], 1)[inside]
    P = W @ pv
    N = np.tile(np.array(tri.normal[:]), (len(P), 1))
    px = q[inside].astype(int)
    img[px[:, 1], px[:, 0]] = colors(P, N)
    filled[px[:, 1], px[:, 0]] = True
# 섬 바깥 8픽셀 채우기 (이음새 번짐 방지)
for _ in range(8):
    s = np.zeros_like(img)
    c = np.zeros(filled.shape, dtype=np.float32)
    for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        s += np.roll(img * filled[..., None], (dy, dx), (0, 1))
        c += np.roll(filled.astype(np.float32), (dy, dx), (0, 1))
    grow = ~filled & (c > 0)
    img[grow] = s[grow] / c[grow][:, None]
    filled |= grow
# 펠트 결 (아주 약한 잡음)
rng = np.random.default_rng(3)
img = np.clip(img + rng.normal(0, 0.012, img.shape).astype(np.float32), 0, 1)

im = bpy.data.images.new("Godeungeo_color", RES, RES, alpha=False)
rgba = np.ones((RES, RES, 4), dtype=np.float32)
rgba[..., :3] = img ** 2.2
im.pixels.foreach_set(rgba.ravel())
im.pack()
mat = bpy.data.materials.new("Godeungeo")
mat.use_nodes = True
nt = mat.node_tree
bsdf = nt.nodes["Principled BSDF"]
bsdf.inputs["Roughness"].default_value = 0.85
tn = nt.nodes.new("ShaderNodeTexImage")
tn.image = im
nt.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
me.materials.clear()
me.materials.append(mat)
for p in me.polygons:
    p.use_smooth = True
os.makedirs(OUT, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "Godeungeo_low.glb"), export_format="GLB", use_selection=True,
                          export_image_format="JPEG", export_jpeg_quality=92)
print("[npc1_paint] done", len(me.polygons), "faces")
