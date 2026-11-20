# 포장 비닐봉투 (2026-11-20 사용자 그림: 위에서 내려오는 네모 봉투, 아래쪽 입구가 동그랗게 벌어진 모양)
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/bag.py -- <출력 폴더> <저장소 루트>
# 결과:
#   <출력>/dalgona_bag.glb, bag_preview.png  (확인용, 레퍼런스/ 에 둠 — 커밋 안 함)
#   <저장소>/src/client/Making/BagShape.lua  (자동 생성: 게임이 이 정점·삼각형으로 EditableMesh를 만듦)
# 좌표 (Blender): 폭 X(±0.5), 길이 Y(+1 = 막힌 윗끝, -1 = 입구), 두께 Z.
# Lua로 내보낼 때는 Roblox 봉투 기준 틀로 바꿈: (x, y, z)_Blender → (x, z, y)_Roblox  (입구가 -Z = 막대 쪽)
# 부품 두 개: body(봉투 몸통, 많이 투명), trim(입구 테두리 + 윗끝 이음매, 덜 투명해서 모양이 또렷)

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "."
ROOT = argv[1] if len(argv) > 1 else "."
random.seed(11)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

NS, NA = 26, 40  # 길이 방향 고리 수, 둘레 점 수 (Lua 데이터 크기 때문에 적당히)
W = 0.5  # 반폭
MOUTH_T = 0.32  # 입구 반두께 (벌어진 정도)
SEAL_T = 0.02  # 막힌 윗끝 반두께


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def section(t, a):
    """t: 0 = 막힌 윗끝 → 1 = 입구, a: 둘레 각도. 반환 (x, z)"""
    # 폭: 윗끝 모서리만 살짝 좁고 나머지 곧음, 입구는 살짝 벌어짐
    w = W * (0.94 + 0.06 * smooth(t / 0.08)) * (1 + 0.03 * smooth((t - 0.85) / 0.15))
    # 두께: 윗끝은 납작(이음매), 아래로 갈수록 부풀어 입구에서 동그랗게 벌어짐
    th = SEAL_T + (MOUTH_T - SEAL_T) * smooth(t) ** 1.25
    # 단면 모양: 윗끝은 납작한 렌즈, 입구로 갈수록 둥근 타원 (지수 2 = 타원)
    n = 2.0 + 1.6 * (1 - t)
    ca, sa = math.cos(a), math.sin(a)
    x = w * math.copysign(abs(ca) ** (2 / n), ca)
    z = th * math.copysign(abs(sa) ** (2 / n), sa)
    # 비닐 주름: 몸통 가운데쯤 잔물결 (입구·윗끝은 매끈)
    wob = 0.012 * math.sin(6 * a + 9 * t) * math.sin(math.pi * t) + random.uniform(-0.004, 0.004) * math.sin(math.pi * t)
    return x * (1 + wob), z * (1 + 2 * wob)


def build_body():
    bm = bmesh.new()
    rings = []
    for i in range(NS):
        t = i / (NS - 1)
        y = 1 - 2 * t
        ring = []
        for j in range(NA):
            a = j / NA * 2 * math.pi
            x, z = section(t, a)
            ring.append(bm.verts.new((x, y, z)))
        rings.append(ring)
    for i in range(NS - 1):
        for j in range(NA):
            j2 = (j + 1) % NA
            bm.faces.new((rings[i][j], rings[i][j2], rings[i + 1][j2], rings[i + 1][j]))
    # 막힌 윗끝: 가운데 점으로 메움
    c = bm.verts.new((0, 1.0, 0))
    for j in range(NA):
        bm.faces.new((c, rings[0][(j + 1) % NA], rings[0][j]))
    return bm


def build_trim():
    bm = bmesh.new()
    # 입구 테두리: 입구 단면을 따라 도는 가는 관
    TUBE, TN = 0.018, 6  # TN은 아래 Lua 데이터의 TN과 같아야 함
    ring_pts = []
    for j in range(NA):
        a = j / NA * 2 * math.pi
        x, z = section(1.0, a)
        ring_pts.append(Vector((x * 1.01, -1.0, z * 1.03)))
    tubes = []
    for j in range(NA):
        p = ring_pts[j]
        tan = (ring_pts[(j + 1) % NA] - ring_pts[j - 1]).normalized()
        nrm = Vector((p.x, 0, p.z)).normalized() if Vector((p.x, 0, p.z)).length > 1e-6 else Vector((1, 0, 0))
        bi = tan.cross(nrm).normalized()
        circ = []
        for k in range(TN):
            b = k / TN * 2 * math.pi
            circ.append(bm.verts.new(p + nrm * (TUBE * math.cos(b)) + bi * (TUBE * math.sin(b))))
        tubes.append(circ)
    for j in range(NA):
        j2 = (j + 1) % NA
        for k in range(TN):
            k2 = (k + 1) % TN
            bm.faces.new((tubes[j][k], tubes[j2][k], tubes[j2][k2], tubes[j][k2]))
    # 윗끝 이음매: 얇은 띠 (봉투 맨 위 열로 붙인 자리)
    bmesh.ops.create_cube(bm, size=1.0, matrix=Matrix.Translation((0, 0.965, 0)) @ Matrix.Diagonal((W * 1.9, 0.05, 0.03, 1)))
    return bm


def to_object(name, bm, rgba):
    bm.normal_update()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    m = bpy.data.materials.new(name + "Mat")
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = 0.25
    bsdf.inputs["Alpha"].default_value = rgba[3]
    me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = True
    return o


body = to_object("Body", build_body(), (0.97, 0.98, 1.0, 0.35))
trim = to_object("Trim", build_trim(), (1.0, 1.0, 1.0, 0.8))

# ── Lua 데이터 (Roblox 봉투 기준 틀) ──
# 정점만 내보내고 삼각형은 게임이 격자 규칙대로 만듦 (데이터 크기 절반):
#   body: 고리 NS개 × 둘레 NA점 (윗끝 → 입구 순) + 마지막에 윗끝 가운데 점
#   trim: 입구 테두리 관 NA × TN점 + 윗끝 이음매 상자 8점 (상자 삼각형은 따로 적음)
TN = 6


def verts_of(obj):
    out = []
    for v in obj.data.vertices:
        x, y, z = v.co
        out += [round(x, 3), round(z, 3), round(y, 3)]  # (x, y, z)_B → (x, z, y)_R
    return out


def box_tris(obj, first):
    me = obj.data
    me.calc_loop_triangles()
    out = []
    for t in me.loop_triangles:
        a, b, c = t.vertices
        if min(a, b, c) >= first:
            out += [a - first + 1, c - first + 1, b - first + 1]  # 축을 바꿔서 감는 순서도 뒤집음 (1부터, 상자 안 번호)
    return out


def lua_list(nums):
    return ",".join(("%g" % n) for n in nums)


lines = [
    "-- 자동 생성: tools/blender/bag.py (손으로 고치지 말 것)",
    "-- 포장 비닐봉투 (입구가 동그랗게 벌어진 네모 봉투). 좌표: 폭 X ±0.5, 두께 Y, 길이 Z (+1 막힌 윗끝, -1 입구)",
    "-- v = 정점 x,y,z 이어 붙임. 삼각형은 Pack.lua가 격자 규칙(NS·NA·TN)대로 만듦",
    "return {",
    "	NS = %d, NA = %d, TN = %d," % (NS, NA, TN),
    "	body = { %s }," % lua_list(verts_of(body)),
    "	trim = { %s }," % lua_list(verts_of(trim)),
    "	boxTris = { %s }," % lua_list(box_tris(trim, NA * TN)),
    "}",
]
lua_path = os.path.join(ROOT, "src", "client", "Making", "BagShape.lua")
NL = chr(10)
with open(lua_path, "w", encoding="utf-8", newline=NL) as f:
    f.write(NL.join(lines) + NL)
print("wrote", lua_path, "body verts", len(body.data.vertices), "trim verts", len(trim.data.vertices))

# ── 확인용 glb + 미리 보기 ──
os.makedirs(OUT, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "dalgona_bag.glb"), export_format="GLB")

cam_data = bpy.data.cameras.new("Cam")
cam = bpy.data.objects.new("Cam", cam_data)
scene.collection.objects.link(cam)
cam.location = (2.2, -2.6, 1.6)
cam.rotation_euler = (math.radians(66), 0, math.radians(40))
light = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
scene.collection.objects.link(light)
light.rotation_euler = (math.radians(40), math.radians(20), 0)
scene.camera = cam
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.45, 0.32, 0.22, 1)
scene.world = world
scene.render.engine = "BLENDER_EEVEE_NEXT" if "BLENDER_EEVEE_NEXT" in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items.keys() else "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 640, 480
scene.render.filepath = os.path.join(OUT, "bag_preview.png")
bpy.ops.render.render(write_still=True)
print("done")
