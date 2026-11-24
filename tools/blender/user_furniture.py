# 사용자가 만든 가구 2개 정리 (2026-11-26, PM 부탁): 레퍼런스/의자랑진열대.glb (텍스처 없음, 메시 2개)
#   Cube.008 = 길고 낮은 유리 진열장 (약 4.7 × 1.1 × 1.4) → 손 작업대 앞에 작게 둠
#   Stool_3  = 손님이 앉을 둥근 의자
# 모양은 사용자 것 그대로, 아늑한 그림체 색만 칠함 (cozy_kit 팔레트 텍스처 한 장, 가게 다른 가구와 같은 나무·크림 톤).
#   면 가운데 위치로 부분을 나눔: 진열장 = 다리(아래) · 받침판 · 틀(가는 막대) · 유리(넓은 면 → 따로 MeshPart) / 의자 = 방석(위) · 다리
#   원점 = 바닥 가운데 (바닥 = z 0). 앞 = Blender -Y (Roblox -Z), 사용자 모델 방향 그대로.
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/user_furniture.py -- <의자랑진열대.glb> <출력 폴더>
# 결과: dalgona_user_furniture.glb (HandCounterShelf, HandCounterShelf_Glass, CustomerStool), *_parts.txt, *_preview.png

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cozy_kit import P, NOTES, part, finish, preview  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = argv[0], os.path.abspath(argv[1])
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)

WOOD = (198, 144, 98)
WOOD_D = (146, 98, 62)
WOOD_L = (222, 176, 122)
CREAM = (246, 234, 212)
GLASS = (214, 236, 238)
PINK = (246, 178, 196)
PINK_D = (226, 150, 170)


def load(name, shift_x=0.0):
    """사용자 메시를 bmesh로: 같은 점 합치고, 바닥 가운데를 원점으로 옮김 (+ 미리 보기용 x 옮김)."""
    o = bpy.data.objects[name]
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bm.transform(o.matrix_world)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    xs = [v.co.x for v in bm.verts]
    ys = [v.co.y for v in bm.verts]
    zs = [v.co.z for v in bm.verts]
    off = Vector(((min(xs) + max(xs)) / 2 - shift_x, (min(ys) + max(ys)) / 2, min(zs)))
    for v in bm.verts:
        v.co -= off
    bm.normal_update()
    return bm, Vector((max(xs) - min(xs), max(ys) - min(ys), max(zs) - min(zs)))


def move_faces(src, faces, dst, rgb):
    """src bmesh의 면들을 dst 부품에 복사하고 색칠."""
    vmap = {}
    for f in faces:
        vs = []
        for v in f.verts:
            if v not in vmap:
                vmap[v] = dst.bm.verts.new(v.co)
            vs.append(vmap[v])
        try:
            nf = dst.bm.faces.new(vs)
            nf[dst.col] = 0
        except ValueError:
            continue
    dst.paint(rgb)


# ── 진열장 ──
shelf_bm, ssize = load("Cube.008", shift_x=-2.2)
sx, sy, sz = ssize
shelf = part("HandCounterShelf", f"사용자 유리 진열장 (나무 틀·크림 받침·짙은 다리), {sx:.2f} × {sz:.2f} × {sy:.2f}. 충돌 켬")
glass = part("HandCounterShelf_Glass", "진열장 유리 (Glass, Transparency 0.6) — 충돌 끔")
bar = 0.08          # 틀 막대 굵기 (사용자 모델 0.06)
groups = {"leg": [], "base": [], "frame": [], "glass": []}
legs_top = None
zs = sorted({round(v.co.z, 3) for v in shelf_bm.verts})
case_z0 = [z for z in zs if z > 0.3][0]          # 유리 상자 바닥 높이 (다리 위)
for f in shelf_bm.faces:
    c = f.calc_center_median()
    ext = [max(v.co[i] for v in f.verts) - min(v.co[i] for v in f.verts) for i in range(3)]
    big = sorted(ext)[-2] > 0.25                  # 면이 두 방향으로 넓음
    if c.z < case_z0 - 0.01:
        groups["leg"].append(f)
    elif abs(c.z - case_z0) < 0.02 and big:
        groups["base"].append(f)                  # 유리 상자 바닥판
    elif big and ext[2] < 0.01 and c.z < case_z0 + 0.1:
        groups["base"].append(f)
    elif big:
        groups["glass"].append(f)
    else:
        groups["frame"].append(f)
move_faces(shelf_bm, groups["leg"], shelf, WOOD_D)
move_faces(shelf_bm, groups["base"], shelf, CREAM)
move_faces(shelf_bm, groups["frame"], shelf, WOOD)
move_faces(shelf_bm, groups["glass"], glass, GLASS)
print("[furniture] 진열장 면:", {k: len(v) for k, v in groups.items()}, "상자 바닥 z", case_z0)

# ── 의자 ──
stool_bm, tsize = load("Stool_3", shift_x=1.6)
stool = part("CustomerStool", f"사용자 둥근 의자 (분홍 방석·나무 다리), 지름 {tsize.x:.2f}, 높이 {tsize.z:.2f}. 원점 = 바닥 가운데")
seat_z = max(v.co.z for v in stool_bm.verts) - 0.21   # 방석 두께 (사용자 모델 0.2)
top, side, legs = [], [], []
for f in stool_bm.faces:
    c = f.calc_center_median()
    if c.z >= seat_z - 0.005:
        (top if f.normal.z > 0.9 else side).append(f)
    else:
        legs.append(f)
move_faces(stool_bm, top, stool, PINK)
move_faces(stool_bm, side, stool, PINK_D)
move_faces(stool_bm, legs, stool, WOOD_D)
print("[furniture] 의자 면: 방석 위", len(top), "옆", len(side), "다리", len(legs), "| 방석 윗면 높이", round(tsize.z, 3))

for o in list(bpy.data.objects):
    bpy.data.objects.remove(o, do_unlink=True)
base = "dalgona_user_furniture"
objs = finish(OUT, base, f"# {base} — tools/blender/user_furniture.py (원점 = 각 물건 바닥 가운데, 미리 보기용으로 진열장 x -2.2·의자 x +1.6 떨어뜨려 놓음)")
preview(OUT, base, objs, {"preview": ((2.5, -6.0, 3.2), (0.0, 0.0, 0.7), 35)}, glass_suffix=("_Glass",))
print("[furniture] done")
