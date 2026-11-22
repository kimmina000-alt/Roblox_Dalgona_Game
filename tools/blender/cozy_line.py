# 아늑한 가게 그림체의 4단계 연속 생산 설비 (사용자 2026-11-23: 새 공장 기계가 5단계면 4단계도 같은 그림체로)
#   cozy_factory.py(5단계 공장 기계)와 같은 그림체·도구: 나무·크림·구리·놋쇠, 주황·크림 줄무늬, 모서리 3단 둥글게 깎기,
#   평평한 면은 평평하게(set_sharp_from_angle), 팔레트 텍스처 한 장. 글자·상표 없음.
#   가게 안 "기계 자리"(바닥 8.6 안)에 놓이는 한 대짜리: 나무 받침장(문짝 없음) 위에
#   구리 솥 + 유리 설탕 통 → 노즐 팔 → 짧은 컨베이어 → 작은 줄무늬 프레스 → 둥근 식힘 덮개(환풍기) → 미끄럼판 → 옆 쟁반,
#   앞 조작판(계기 2개, 시작·정지), 뒤 기둥 2개 + 줄무늬 작은 차양 + 전구 2개.
#
# 부품 이름 = 예전 4단계(dalgona_line.glb) L4_* 이름을 그대로 써서 게임 코드(MachineDisplay LINE_ANIM,
#   FactoryBuilder.style)가 그대로 알아봄: L4_PressHead(press), L4_CoolFan(spin), L4_TowerG(lampRun), L4_TowerR(lampStop),
#   L4_Chute(outlet), L4_Dalgona(window). Studio에서는 ServerStorage.Assets.MachineLine 자리.
#
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/cozy_line.py -- <출력 폴더(절대 경로)>
# 결과: dalgona_cozy_line.glb, cozy_line_preview.png, cozy_line_preview2.png(프레스 내린 모습), cozy_line_parts.txt
# 크기 = 게임 stud. 원점 = 바닥 가운데. 앞 = Blender -Y. 좌표 변환 Blender (x, y, z) → Roblox (-x, z, y).

import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else ".")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(5)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# ───────────── 팔레트 ─────────────
PALETTE, PIDX = [], {}
GRID = 8


def C(rgb):
    key = tuple(int(v) for v in rgb)
    if key not in PIDX:
        PIDX[key] = len(PALETTE)
        PALETTE.append(key)
        assert len(PALETTE) <= GRID * GRID
    return PIDX[key]


def palette_image():
    cell = 16
    size = cell * GRID
    arr = np.ones((size, size, 3))
    for i, rgb in enumerate(PALETTE):
        cx, cy = i % GRID, i // GRID
        arr[cy * cell:(cy + 1) * cell, cx * cell:(cx + 1) * cell] = np.array(rgb) / 255 + rng.normal(0, 0.005, (cell, cell, 1))
    img = bpy.data.images.new("CozyLinePalette", size, size, alpha=False)
    rgba = np.ones((size, size, 4), dtype=np.float32)
    rgba[:, :, :3] = np.clip(arr, 0, 1) ** 2.2
    img.pixels.foreach_set(rgba.ravel())
    img.pack()
    return img


# 사진에서 고른 색
WOOD = (198, 144, 98)  # 카운터 나무
WOOD_D = (146, 98, 62)  # 진한 나무 (테·받침)
WOOD_L = (222, 176, 122)  # 밝은 나무 (윗판)
CREAM = (246, 234, 212)  # 크림 벽·문판
CREAM_D = (230, 212, 184)
ORANGE = (238, 172, 122)  # 차양 주황
AWN_CREAM = (250, 240, 222)
BRASS = (226, 186, 110)
COPPER = (204, 138, 96)
COPPER_D = (172, 110, 74)
BOARD = (56, 58, 56)  # 칠판
BULB = (255, 226, 160)
WIRE = (90, 70, 56)
GLASS = (224, 236, 234)
SUGAR = (252, 250, 244)
DALGONA = (226, 172, 98)
DALGONA_D = (182, 126, 64)
STEEL = (210, 206, 198)
KNOB = (120, 84, 60)

I4 = Matrix.Identity(4)


def rot(x=0, y=0, z=0):
    return Matrix.Rotation(math.radians(z), 4, "Z") @ Matrix.Rotation(math.radians(y), 4, "Y") @ Matrix.Rotation(math.radians(x), 4, "X")


class Part:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.col = self.bm.faces.layers.int.new("col")

    def paint(self, rgb):
        idx = C(rgb) + 1
        for f in self.bm.faces:
            if f[self.col] == 0:
                f[self.col] = idx


P = {n: Part(n) for n in ("L4_Cabinet", "L4_Kettle", "L4_Hopper", "L4_HopperSugar", "L4_Belt", "L4_Dalgona", "L4_PressHead",
                         "L4_CoolFan", "L4_TowerG", "L4_Chute", "L4_Crate", "L4_CrateDalgona", "L4_ControlPanel",
                         "L4_StartButton", "L4_TowerR", "L4_Awning")}


def V(v):
    return Vector(v)


def box(p, c, size, rgb, bev=None, seg=3, m=I4):
    """모서리를 둥글게 깎은 상자. bev 기본 = 가장 짧은 변의 18% (최대 0.12)."""
    if bev is None:
        bev = min(min(size) * 0.18, 0.12)
    res = bmesh.ops.create_cube(p.bm, size=1.0, matrix=Matrix.Translation(V(c)) @ m @ Matrix.Diagonal((*size, 1)))
    if bev > 0:
        vs = res["verts"]
        es = list({e for v in vs for e in v.link_edges})
        bmesh.ops.bevel(p.bm, geom=vs + es, offset=bev, offset_type="OFFSET", segments=seg, profile=0.5, affect="EDGES", clamp_overlap=True)
    p.paint(rgb)


def ball(p, c, r, rgb, seg=(12, 8), m=I4):
    r = (r, r, r) if isinstance(r, (int, float)) else r
    bmesh.ops.create_uvsphere(p.bm, u_segments=seg[0], v_segments=seg[1], radius=1.0,
                              matrix=Matrix.Translation(V(c)) @ m @ Matrix.Diagonal((*r, 1)))
    p.paint(rgb)


def cyl(p, a, b, r0, r1, rgb, seg=12):
    a, b = V(a), V(b)
    d = b - a
    R = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    bmesh.ops.create_cone(p.bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r0, radius2=r1, depth=d.length,
                          matrix=Matrix.Translation((a + b) / 2) @ R)
    p.paint(rgb)


def lathe(p, prof, rgb, seg=16, c=(0, 0, 0), m=I4):
    """prof = [(r, z)...] 아래에서 위로. r = 0 인 끝은 한 점으로 모임."""
    M = Matrix.Translation(V(c)) @ m
    rings = []
    for (r, z) in prof:
        rings.append([p.bm.verts.new(M @ Vector((math.cos(2 * math.pi * k / seg) * r, math.sin(2 * math.pi * k / seg) * r, z))) for k in range(seg)])
    faces = []
    for A, B in zip(rings, rings[1:]):
        for k in range(seg):
            k2 = (k + 1) % seg
            faces.append(p.bm.faces.new((A[k], A[k2], B[k2], B[k])))
    bmesh.ops.remove_doubles(p.bm, verts=[v for r in rings for v in r], dist=1e-5)
    faces = [f for f in faces if f.is_valid]
    bmesh.ops.recalc_face_normals(p.bm, faces=faces)
    p.paint(rgb)


def rounded_disc(p, c, r, h, rgb, seg=20, m=I4):
    """가장자리가 둥근 납작한 원판 (달고나, 돌림판)."""
    e = min(h * 0.45, r * 0.2)
    lathe(p, [(0, 0), (r - e, 0), (r - e * 0.3, e * 0.3), (r, e), (r, h - e), (r - e * 0.3, h - e * 0.3), (r - e, h), (0, h)], rgb, seg=seg, c=c, m=m)


def star_relief(p, c, R, h, rgb, m=I4):
    """달고나 윗면에 찍힌 별 (얕게 솟은 납작한 별)."""
    M = Matrix.Translation(V(c)) @ m
    pts = []
    for k in range(10):
        a = math.pi / 2 + k * math.pi / 5
        rr = R if k % 2 == 0 else R * 0.45
        pts.append((math.cos(a) * rr, math.sin(a) * rr))
    top = [p.bm.verts.new(M @ Vector((x, y, h))) for x, y in pts]
    bot = [p.bm.verts.new(M @ Vector((x, y, 0))) for x, y in pts]
    ct = p.bm.verts.new(M @ Vector((0, 0, h)))
    faces = []
    for k in range(10):
        k2 = (k + 1) % 10
        faces.append(p.bm.faces.new((ct, top[k], top[k2])))
        faces.append(p.bm.faces.new((bot[k], bot[k2], top[k2], top[k])))
    bmesh.ops.recalc_face_normals(p.bm, faces=faces)
    p.paint(rgb)


def dalgona(p, c, r=0.42, h=0.07, star=True, m=I4):
    rounded_disc(p, c, r, h, DALGONA, seg=18, m=m)
    if star:
        star_relief(p, V(c) + (m.to_3x3() @ Vector((0, 0, h - 0.005))), r * 0.55, 0.02, DALGONA_D, m=m)



# ───────────── 4단계 연속 생산 설비 (가게 안 기계 자리, 바닥 8.6 안) ─────────────
GAUGE_FACE = (252, 246, 232)
RED_BTN = (230, 120, 104)
MINT_BTN = (150, 204, 176)
BELT = (112, 92, 82)

cab = P["L4_Cabinet"]
LW, LD, LH = 7.8, 2.6, 2.3  # 받침장
TOPZ = LH + 0.2

# 나무 받침장 + 굽 + 밝은 나무 윗판 (문짝은 사용자 요청으로 뺌)
box(cab, (0, 0, 0.1), (LW - 0.1, LD - 0.1, 0.2), WOOD_D)
box(cab, (0, 0, 0.2 + (LH - 0.2) / 2), (LW, LD, LH - 0.2), WOOD, bev=0.12)
box(cab, (0, -0.05, LH + 0.1), (LW + 0.25, LD + 0.2, 0.2), WOOD_L, bev=0.07)

# 왼쪽: 구리 솥 + 위 유리 설탕 통(놋쇠 받침 고리) + 솥에서 벨트 위로 나오는 노즐 팔
kx = -2.9
kc = Vector((kx, 0.1, TOPZ))
lathe(P["L4_Kettle"], [(0, 0), (0.6, 0), (0.72, 0.12), (0.76, 0.45), (0.76, 0.95), (0.8, 1.0), (0.74, 1.04), (0.62, 1.08), (0.3, 1.14), (0, 1.15)], COPPER, seg=20, c=kc)
for z in (0.35, 0.8):
    lathe(P["L4_Kettle"], [(0.77, z - 0.04), (0.8, z - 0.02), (0.8, z + 0.02), (0.77, z + 0.04)], BRASS, seg=20, c=kc)
gc = kc + Vector((0, -0.78, 0.6))
cyl(cab, gc + Vector((0, 0.05, 0)), gc + Vector((0, -0.06, 0)), 0.22, 0.22, BRASS, seg=14)
cyl(cab, gc + Vector((0, -0.05, 0)), gc + Vector((0, -0.08, 0)), 0.18, 0.18, GAUGE_FACE, seg=14)
box(cab, gc + Vector((0.05, -0.09, 0.04)), (0.03, 0.015, 0.16), RED_BTN, bev=0.006, seg=1, m=rot(y=-35))
hc = kc + Vector((0, 0, 1.15))
for a in range(3):  # 받침 다리
    t = math.radians(a * 120 + 90)
    cyl(cab, hc + Vector((math.cos(t) * 0.45, math.sin(t) * 0.45, -0.05)), hc + Vector((math.cos(t) * 0.5, math.sin(t) * 0.5, 0.45)), 0.04, 0.04, BRASS, seg=6)
lathe(cab, [(0.5, 0.42), (0.56, 0.45), (0.56, 0.5), (0.5, 0.52)], BRASS, seg=16, c=hc)
lathe(P["L4_Hopper"], [(0.1, 0.15), (0.25, 0.3), (0.55, 0.62), (0.58, 0.7), (0.58, 1.5), (0.52, 1.58), (0, 1.58)], GLASS, seg=18, c=hc)
lathe(P["L4_HopperSugar"], [(0.08, 0.2), (0.24, 0.34), (0.52, 0.65), (0.53, 1.15), (0.3, 1.24), (0, 1.26)], SUGAR, seg=16, c=hc)
lathe(cab, [(0, 1.55), (0.62, 1.55), (0.64, 1.62), (0.58, 1.7), (0, 1.72)], WOOD_D, seg=18, c=hc)
ball(cab, hc + Vector((0, 0, 1.78)), 0.08, BRASS, seg=(8, 6))
arm0 = kc + Vector((0.6, 0, 0.85))
cyl(cab, arm0, (-1.75, 0.0, TOPZ + 1.25), 0.08, 0.08, BRASS, seg=10)
ball(cab, (-1.75, 0.0, TOPZ + 1.25), 0.1, BRASS, seg=(8, 6))
cyl(cab, (-1.75, 0.0, TOPZ + 1.25), (-1.75, 0.0, TOPZ + 0.62), 0.1, 0.04, BRASS, seg=10)

# 가운데·오른쪽: 컨베이어 (크림 틀 + 나무 옆판 + 벨트), 짧은 다리 없음(받침장 위)
BX0, BX1 = -2.1, 3.3
BZ = TOPZ + 0.42
blen = BX1 - BX0
bx = (BX0 + BX1) / 2
box(cab, (bx, 0, TOPZ + 0.2), (blen, 1.4, 0.36), CREAM, bev=0.1)
for sy in (-1, 1):
    box(cab, (bx, sy * 0.74, TOPZ + 0.24), (blen + 0.1, 0.1, 0.46), WOOD, bev=0.04)
for x in (BX0 + 0.12, BX1 - 0.12):
    cyl(cab, (x, -0.66, BZ - 0.13), (x, 0.66, BZ - 0.13), 0.15, 0.15, BRASS, seg=12)
box(P["L4_Belt"], (bx, 0, BZ - 0.03), (blen - 0.25, 1.2, 0.06), BELT, bev=0.025, seg=2)
for x in (-1.3, -0.4):
    dalgona(P["L4_Dalgona"], (x, 0, BZ), r=0.3, h=0.05, star=False)
for x in (1.6, 2.6):
    dalgona(P["L4_Dalgona"], (x, 0, BZ), r=0.3, h=0.05)

# 작은 프레스: 줄무늬 옆판 + 크림 지붕 + 놋쇠 실린더 + 움직이는 머리(별 도장)
px = 0.55
for sy in (-1, 1):
    box(cab, (px, sy * 0.88, BZ + 0.8), (0.8, 0.2, 1.7), WOOD_D, bev=0.07)
    for k in range(3):
        box(cab, (px, sy * 1.0, BZ + 0.35 + k * 0.45), (0.66, 0.05, 0.45), ORANGE if k % 2 == 0 else AWN_CREAM, bev=0.02, seg=2)
box(cab, (px, 0, BZ + 1.75), (1.05, 2.05, 0.42), CREAM, bev=0.16)
box(cab, (px, 0, BZ + 2.0), (1.15, 2.15, 0.1), WOOD_D, bev=0.04)
cyl(cab, (px, 0, BZ + 1.55), (px, 0, BZ + 1.15), 0.16, 0.16, BRASS, seg=12)
ph = P["L4_PressHead"]
cyl(ph, (px, 0, BZ + 1.2), (px, 0, BZ + 0.62), 0.08, 0.08, STEEL, seg=10)
box(ph, (px, 0, BZ + 0.5), (0.7, 0.9, 0.22), BRASS, bev=0.07)
star_relief(ph, (px, 0, BZ + 0.39), 0.2, 0.03, COPPER_D, m=rot(x=180))

# 식힘 덮개: 둥근 크림 덮개 + 둥근 창 + 위 환풍기(돎)
cx = 2.3
box(cab, (cx, 0, BZ + 0.55), (1.3, 1.6, 1.0), CREAM, bev=0.35, seg=4)
q = Vector((cx, -0.8, BZ + 0.6))
cyl(cab, q + Vector((0, 0.04, 0)), q + Vector((0, -0.05, 0)), 0.24, 0.24, BRASS, seg=14)
cyl(P["L4_TowerG"], q + Vector((0, -0.03, 0)), q + Vector((0, -0.07, 0)), 0.18, 0.18, (255, 210, 170), seg=14)
lathe(cab, [(0.36, 0), (0.4, 0.04), (0.4, 0.13), (0.34, 0.15), (0.34, 0.04), (0, 0.04)], BRASS, seg=14, c=(cx, 0.1, BZ + 1.02))
fan = P["L4_CoolFan"]
fc = Vector((cx, 0.1, BZ + 1.12))
cyl(fan, fc + Vector((0, 0, -0.025)), fc + Vector((0, 0, 0.025)), 0.07, 0.07, WOOD_D, seg=8)
for k in range(4):
    box(fan, fc + rot(z=k * 90).to_3x3() @ Vector((0.17, 0, 0)), (0.24, 0.1, 0.025), CREAM_D, bev=0.01, seg=2, m=rot(z=k * 90) @ rot(x=18))

# 오른쪽 끝: 미끄럼판(나오는 곳) + 옆에 매단 나무 쟁반 서랍 + 다 된 달고나
ch = P["L4_Chute"]
box(ch, (BX1 + 0.35, 0, BZ - 0.3), (0.8, 1.0, 0.08), WOOD_L, bev=0.03, m=rot(y=35))
for sy in (-1, 1):
    box(ch, (BX1 + 0.35, sy * 0.52, BZ - 0.24), (0.8, 0.05, 0.18), WOOD_D, bev=0.02, seg=2, m=rot(y=35))
tx = LW / 2 - 0.1
box(P["L4_Crate"], (tx, 0, TOPZ - 0.05), (1.0, 1.4, 0.1), WOOD_L, bev=0.03)
for sy in (-1, 1):
    box(P["L4_Crate"], (tx, sy * 0.68, TOPZ + 0.05), (1.0, 0.06, 0.18), WOOD_D, bev=0.02, seg=2)
box(P["L4_Crate"], (tx + 0.48, 0, TOPZ + 0.05), (0.06, 1.4, 0.18), WOOD_D, bev=0.02, seg=2)
for k, (dx, dy, dz) in enumerate(((-0.15, -0.3, 0.02), (0.15, 0.25, 0.02), (0.0, 0.0, 0.08))):
    dalgona(P["L4_CrateDalgona"], (tx + dx, dy, TOPZ + dz), r=0.26, h=0.05, m=rot(z=k * 30))

# 앞 조작판 (받침장 앞, 왼쪽 위): 크림 판 + 계기 2개 + 시작·정지 버튼
cp = Vector((-1.6, -LD / 2 - 0.08, LH - 0.45))
box(P["L4_ControlPanel"], cp, (1.6, 0.12, 0.55), WOOD_D, bev=0.05)
box(P["L4_ControlPanel"], cp + Vector((0, -0.06, 0)), (1.45, 0.05, 0.42), CREAM, bev=0.03)
for x in (-0.45, -0.05):
    q = cp + Vector((x, -0.08, 0))
    cyl(P["L4_ControlPanel"], q, q + Vector((0, -0.04, 0)), 0.15, 0.15, BRASS, seg=12)
    cyl(P["L4_ControlPanel"], q + Vector((0, -0.03, 0)), q + Vector((0, -0.05, 0)), 0.12, 0.12, GAUGE_FACE, seg=12)
ball(P["L4_StartButton"], cp + Vector((0.35, -0.1, 0)), (0.1, 0.06, 0.1), MINT_BTN, seg=(10, 6))
ball(P["L4_TowerR"], cp + Vector((0.6, -0.1, 0)), (0.1, 0.06, 0.1), RED_BTN, seg=(10, 6))

# 위: 뒤 기둥 2개 + 가게와 같은 주황·크림 줄무늬 작은 차양 + 전구 2개(돌 때 켜짐)
aw = P["L4_Awning"]
for sx in (-1, 1):
    box(cab, (sx * (LW / 2 - 0.25), LD / 2 - 0.25, TOPZ + 2.0), (0.18, 0.18, 4.0), WOOD_D, bev=0.05)
NS = 8
AZ = TOPZ + 3.95
for k in range(NS):
    x = -LW / 2 + (k + 0.5) * LW / NS
    col = ORANGE if k % 2 == 0 else AWN_CREAM
    box(aw, (x, 0.0, AZ), (LW / NS + 0.002, 2.4, 0.07), col, bev=0.025, seg=2, m=rot(x=-14))
    lip = Vector((x, -1.17, AZ - 0.32))
    cyl(aw, lip + Vector((-LW / NS / 2, 0, 0)), lip + Vector((LW / NS / 2, 0, 0)), 0.14, 0.14, col, seg=10)
for x in (-1.6, 1.6):
    cyl(cab, (x, -0.6, AZ - 0.18), (x, -0.6, AZ - 0.35), 0.03, 0.03, WIRE, seg=5)
    ball(P["L4_TowerG"], (x, -0.6, AZ - 0.45), (0.11, 0.11, 0.13), BULB, seg=(10, 6))


# ───────────── 오브젝트 + 팔레트 재질 ─────────────
IMG = palette_image()
MAT = bpy.data.materials.new("CozyPalette")
MAT.use_nodes = True
nt = MAT.node_tree
bsdf = nt.nodes["Principled BSDF"]
bsdf.inputs["Roughness"].default_value = 0.7
tex = nt.nodes.new("ShaderNodeTexImage")
tex.image = IMG
tex.interpolation = "Closest"
nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])

NOTES = {
    "L4_Cabinet": "나무 받침장·윗판·노즐 팔·컨베이어 틀·프레스 틀·식힘 덮개·기둥",
    "L4_Kettle": "구리 솥",
    "L4_Hopper": "유리 설탕 통 (게임 스타일: Glass)",
    "L4_HopperSugar": "통 속 설탕",
    "L4_Belt": "벨트",
    "L4_Dalgona": "벨트 위 달고나 (Anim window)",
    "L4_PressHead": "누름 머리 + 별 도장 (Anim press)",
    "L4_CoolFan": "식힘 덮개 위 환풍기 (Anim spin, 얇은 축 = 세로)",
    "L4_TowerG": "전구 2개 + 식힘 창 (Anim lampRun)",
    "L4_Chute": "미끄럼판 (Anim outlet)",
    "L4_Crate": "옆 나무 쟁반",
    "L4_CrateDalgona": "쟁반 위 달고나",
    "L4_ControlPanel": "앞 조작판 (계기 2개)",
    "L4_StartButton": "시작 버튼",
    "L4_TowerR": "정지 버튼 (Anim lampStop)",
    "L4_Awning": "주황·크림 줄무늬 작은 차양",
}
rows = []
objs = []
total = 0
for p in P.values():
    bm = p.bm
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        i = max(f[p.col] - 1, 0)
        u, v = ((i % GRID) + 0.5) / GRID, ((i // GRID) + 0.5) / GRID
        for l in f.loops:
            l[uv].uv = (u, v)
    bm.normal_update()
    me = bpy.data.meshes.new(p.name)
    bm.to_mesh(me)
    bm.free()
    me.shade_smooth()
    me.set_sharp_from_angle(angle=math.radians(35))
    me.materials.append(MAT)
    o = bpy.data.objects.new(p.name, me)
    scene.collection.objects.link(o)
    objs.append(o)
    tris = sum(len(f.vertices) - 2 for f in me.polygons)
    total += tris
    lo = Vector([min(v.co[i] for v in me.vertices) for i in range(3)])
    hi = Vector([max(v.co[i] for v in me.vertices) for i in range(3)])
    c, s = (lo + hi) / 2, hi - lo
    rows.append(f"{p.name}\ttris={tris}\tsize=({s.x:.2f}, {s.z:.2f}, {s.y:.2f})\tcenter=({-c.x:.2f}, {c.z:.2f}, {c.y:.2f})\t{NOTES[p.name]}")
rows.append(f"# 합계 삼각형 {total}. center = 기계 원점(바닥 가운데)에서 MeshPart 가운데까지 (Roblox 좌표).")
rows.append(f"# 벨트 윗면 높이 {BZ:.2f}, 벨트 Roblox X {-BX1:.2f} ~ {-BX0:.2f} (달고나는 Roblox -X 쪽으로 흐름)")
with open(os.path.join(OUT, "cozy_line_parts.txt"), "w", encoding="utf-8") as f:
    f.write("\n".join(rows) + "\n")
print("\n".join(rows))

for o in objs:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "dalgona_cozy_line.glb"), export_format="GLB", use_selection=True, export_apply=True)

# ───────────── 미리 보기 ─────────────
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (1.0, 0.86, 0.7, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.55
scene.world = world
bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
fl = bpy.context.active_object
fm = bpy.data.materials.new("Floor")
fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.55, 0.5, 0.46, 1)
fl.data.materials.append(fm)
bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 3.0, 6))
wall = bpy.context.active_object
wall.scale = (40, 1, 12)
wall.rotation_euler = (math.radians(90), 0, 0)
wm = bpy.data.materials.new("Wall")
wm.use_nodes = True
wm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.86, 0.74, 0.58, 1)
wall.data.materials.append(wm)
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 2.6
sun.data.angle = math.radians(25)
sun.data.color = (1.0, 0.92, 0.8)
sun.rotation_euler = (math.radians(55), math.radians(8), math.radians(-30))
scene.collection.objects.link(sun)
for q in ((0, -1.2, AZ - 0.8), (cx, -1.6, BZ + 0.8)):
    pt = bpy.data.objects.new("Pt", bpy.data.lights.new("Pt", "POINT"))
    pt.data.energy = 80
    pt.data.color = (1.0, 0.8, 0.55)
    pt.location = q
    scene.collection.objects.link(pt)
emit = bpy.data.materials.new("Glow")
emit.use_nodes = True
eb = emit.node_tree.nodes["Principled BSDF"]
eb.inputs["Base Color"].default_value = (1, 0.85, 0.6, 1)
eb.inputs["Emission Color"].default_value = (1, 0.8, 0.5, 1)
eb.inputs["Emission Strength"].default_value = 4
scene.objects["L4_TowerG"].data.materials[0] = emit
glass = bpy.data.materials.new("GlassPrev")
glass.use_nodes = True
gb = glass.node_tree.nodes["Principled BSDF"]
gb.inputs["Base Color"].default_value = (0.85, 0.95, 0.95, 1)
gb.inputs["Alpha"].default_value = 0.35
glass.surface_render_method = "BLENDED"
scene.objects["L4_Hopper"].data.materials[0] = glass
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.lens = 35
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 1800, 1000
scene.view_settings.view_transform = "Standard"


def shoot(loc, tgt, name):
    cam.location = loc
    cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)


shoot((3.5, -13.5, 7.0), (0, 0, 2.8), "cozy_line_preview.png")
press = scene.objects["L4_PressHead"]
press.location.z -= 0.35
shoot((-7.0, -8.0, 6.5), (0.3, 0, 3.0), "cozy_line_preview2.png")
print("[cozy_line] done")
