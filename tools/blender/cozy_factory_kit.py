# 달고나 공장 실내 소품 세트 (사용자 그림 2026-11-23: "사진 속 기계와 시설들 3D 제작. 모서리 날카롭지 않게 코지한 느낌 유지")
#   그림: 따뜻한 나무 천장 들보, 크림 벽, 스테인리스 기계, 매단 등, 은색 관, 별 달고나.
#   cozy_factory.py와 같은 도구·그림체: 모든 상자 모서리 둥글게 깎기(3단), 평평한 면은 평평하게(set_sharp_from_angle),
#   팔레트 텍스처 한 장 공용. 글자·상표 없음 (간판 글씨는 게임에서 SurfaceGui).
#
# 소품 (오브젝트 = Roblox MeshPart 하나, 이름 Kit_*): 컨베이어 라인, 벨트 위 달고나, 오븐 + 받침 조리대, 벽 선반 + 병,
#   병 선반장, 설탕 깔때기 기계, 큰 프레스 탑 + 누름 머리, 조작장, 바퀴 쟁반 선반 + 달고나 쟁반, 별 상자(하나·무더기),
#   앞 작업대(별 틀·밀대), 큰 들통, 왼쪽 조리대(볼·저울·도구 통), 매단 등 3개, 천장 관, 간판 판, 포스터, 창문, 천장 들보,
#   Kit_Glass(유리 모음), Kit_Glow(빛 모음).
#
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/cozy_factory_kit.py -- <출력 폴더(절대 경로)>
# 결과: dalgona_factory_kit.glb, factory_kit_preview.png, factory_kit_preview2.png, factory_kit_parts.txt
# 크기 = 게임 stud (사람 키 약 5). 그림과 같은 배치로 내보냄: 원점 = 방 바닥 가운데, 뒷벽 = Blender +Y 6, 왼벽 = Blender X -16.
# 좌표 변환 Blender (x, y, z) → Roblox (-x, z, y).

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
    img = bpy.data.images.new("CozyKitPalette", size, size, alpha=False)
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


P = {n: Part(n) for n in ("Kit_Conveyor", "Kit_ConveyorDalgona", "Kit_OvenCounter", "Kit_Oven", "Kit_WallShelf", "Kit_JarRack", "Kit_Hopper", "Kit_PressTower", "Kit_PressHead", "Kit_ControlCabinet", "Kit_TrayRack", "Kit_TrayDalgona", "Kit_Box", "Kit_BoxStack", "Kit_PrepTable", "Kit_StockPot", "Kit_SideCounter", "Kit_PendantLamps", "Kit_Ducts", "Kit_SignBoard", "Kit_Poster", "Kit_Window", "Kit_CeilingBeams", "Kit_Glass", "Kit_Glow")}


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



# ───────────── 달고나 공장 실내 소품 (사용자 그림 2026-11-23) ─────────────
STEEL = (214, 212, 212)
STEEL_D = (172, 170, 172)
STEEL_L = (234, 232, 230)
GLASSC = (214, 232, 230)
JAR_A = (176, 124, 82)
JAR_B = (216, 190, 146)
JAR_C = (198, 160, 108)
BOX = (224, 178, 118)
BOX_D = (192, 142, 90)
HAZ_Y = (242, 198, 92)
HAZ_D = (96, 84, 76)
GLOW = (255, 214, 150)
SCREEN = (162, 212, 222)
BTN_R = (222, 112, 92)
BTN_G = (132, 192, 142)
BTN_O = (242, 162, 92)
FLOUR = (250, 248, 244)
RUBBER = (96, 90, 90)
BEAM = (214, 160, 104)

MAT_NOTES = {}


def jar(p, c, r, h, fill, lid=WOOD_D, seg=12):
    """유리병: 아래 내용물 + 위 유리 띠 + 뚜껑 (불투명, 가볍게)."""
    c = V(c)
    lathe(p, [(0, 0), (r * 0.92, 0), (r, h * 0.06), (r, h * 0.7), (0, h * 0.7)], fill, seg=seg, c=c)
    lathe(p, [(r, h * 0.7), (r, h * 0.86), (r * 0.8, h * 0.92), (0, h * 0.92)], GLASSC, seg=seg, c=c)
    lathe(p, [(r * 0.84, h * 0.9), (r * 0.86, h), (0, h)], lid, seg=seg, c=c)


def star_medallion(p, c, R, rgb_disc, rgb_star, m=I4):
    """앞(-Y)을 보는 둥근 달고나 메달 + 별."""
    M = m @ rot(x=90)
    rounded_disc(p, c, R, R * 0.18, rgb_disc, seg=24, m=M)
    star_relief(p, V(c) + (M.to_3x3() @ Vector((0, 0, R * 0.17))), R * 0.58, R * 0.06, rgb_star, m=M)


def leg(p, c, h, w=0.22, rgb=STEEL_D):
    box(p, (c[0], c[1], h / 2), (w, w, h), rgb, bev=0.05, seg=2)


# 1) 컨베이어 라인 (가운데): 스테인리스 상판·홈 줄, 아래 문 달린 장 2개, 들통 3개, 다리
P_conv = P["Kit_Conveyor"]
CX, CY, CL, CD, CH = 0.5, 0.0, 18.0, 2.6, 3.2
x0, x1 = CX - CL / 2, CX + CL / 2
box(P_conv, (CX, CY, CH - 0.15), (CL, CD, 0.3), STEEL, bev=0.1)
box(P_conv, (CX, CY, CH + 0.02), (CL - 0.6, CD - 0.5, 0.06), RUBBER, bev=0.02, seg=2)
for k in range(int(CL / 1.2)):  # 벨트 홈 줄
    x = x0 + 0.6 + k * 1.2
    box(P_conv, (x, CY, CH + 0.06), (0.05, CD - 0.55, 0.03), STEEL_D)
for sy in (-1, 1):
    box(P_conv, (CX, CY + sy * (CD / 2 - 0.08), CH + 0.18), (CL, 0.14, 0.35), STEEL_L, bev=0.05)
box(P_conv, (CX, CY, 0.9), (CL - 0.6, CD - 0.4, 0.12), STEEL_D, bev=0.04)  # 아래 선반
for x in (x0 + 0.3, x0 + 6, x0 + 12, x1 - 0.3):
    for sy in (-1, 1):
        leg(P_conv, (x, CY + sy * (CD / 2 - 0.3)), CH - 0.3)
for cx_ in (CX + 2.8, CX + 6.8):  # 문 달린 장
    box(P_conv, (cx_, CY, 1.6), (2.4, CD - 0.3, 2.6), STEEL, bev=0.12)
    box(P_conv, (cx_, CY - CD / 2 + 0.1, 1.6), (1.9, 0.06, 2.0), STEEL_L, bev=0.05)
    box(P_conv, (cx_ + 0.65, CY - CD / 2 + 0.04, 1.8), (0.08, 0.08, 0.5), STEEL_D, bev=0.02, seg=1)
for k, x in enumerate((x0 + 3.2, x0 + 4.6, x0 + 6.0)):  # 들통 3개
    lathe(P_conv, [(0, 0), (0.55, 0), (0.6, 0.05), (0.6, 0.95), (0.64, 1.0), (0.56, 1.02), (0, 1.0)], STEEL_L, seg=16, c=(x, CY, 0.96))
for k in range(7):  # 벨트 위 별 달고나
    x = x0 + 1.6 + k * 2.2
    dalgona(P["Kit_ConveyorDalgona"], (x, CY, CH + 0.06), r=0.55, h=0.08)

# 2) 오븐 + 오븐 받침 조리대 (왼쪽)
oc = P["Kit_OvenCounter"]
OX, OY = -11.6, 1.6
box(oc, (OX, OY, CH - 0.15), (6.4, 3.0, 0.3), STEEL, bev=0.1)
box(oc, (OX, OY, 0.9), (6.0, 2.6, 0.12), STEEL_D, bev=0.04)
for sx in (-1, 1):
    for sy in (-1, 1):
        leg(oc, (OX + sx * 2.95, OY + sy * 1.25), CH - 0.3)
for k in range(3):  # 아래 선반 위 달고나 상자
    box(oc, (OX - 1.8 + k * 1.6, OY - 0.2, 1.3), (1.3, 1.6, 0.6), BOX, bev=0.08)
ov = P["Kit_Oven"]
ovc = Vector((-10.4, 2.3, CH))
box(ov, ovc + Vector((0, 0, 1.35)), (4.2, 2.6, 2.7), STEEL, bev=0.22, seg=3)
for dz, sz_ in ((2.27, (3.0, 0.12, 0.22)), (0.33, (3.0, 0.12, 0.22))):  # 문 테 (위·아래)
    box(ov, ovc + Vector((-0.4, -1.32, dz)), sz_, STEEL_D, bev=0.05, seg=2)
for dx in (-1.8, 1.0):  # 문 테 (옆)
    box(ov, ovc + Vector((dx, -1.32, 1.3)), (0.22, 0.12, 2.16), STEEL_D, bev=0.05, seg=2)
box(ov, ovc + Vector((-0.4, -1.36, 2.45)), (2.4, 0.12, 0.14), STEEL_L, bev=0.05, seg=2)  # 손잡이
for k, col in enumerate((BTN_O, BTN_R, BTN_G)):
    cyl(ov, ovc + Vector((1.6, -1.3, 2.1 - k * 0.55)), ovc + Vector((1.6, -1.42, 2.1 - k * 0.55)), 0.16, 0.14, col, seg=12)
box(ov, ovc + Vector((1.6, -1.31, 0.45)), (0.6, 0.04, 0.3), SCREEN, bev=0.03, seg=2)
box(P["Kit_Glass"], ovc + Vector((-0.4, -1.36, 1.25)), (2.5, 0.04, 1.55), GLASSC, bev=0.05, seg=2)
box(P["Kit_Glow"], ovc + Vector((-0.4, -1.27, 1.25)), (2.55, 0.04, 1.7), GLOW, bev=0.02, seg=1)  # 오븐 속 불빛 (유리 바로 뒤)
box(ov, ovc + Vector((-0.4, -1.31, 0.85)), (2.5, 0.12, 0.05), STEEL_L, bev=0.0)  # 속 선반
for x in (-0.9, 0.1):
    dalgona(ov, ovc + Vector((x - 0.4, -1.33, 0.88)), r=0.32, h=0.06, m=rot(x=-60))

# 3) 오븐 위 벽 선반 + 병 5개
ws = P["Kit_WallShelf"]
wc = Vector((-10.4, 5.4, 7.6))
box(ws, wc, (5.6, 1.2, 0.2), WOOD, bev=0.06)
for sx in (-1, 1):
    box(ws, wc + Vector((sx * 2.2, 0.35, -0.45)), (0.16, 0.5, 0.7), WOOD_D, bev=0.04, m=rot(x=0))
for k, fill in enumerate((JAR_C, JAR_A, JAR_B, JAR_A, JAR_C)):
    jar(ws, wc + Vector((-2.2 + k * 1.1, 0, 0.1)), 0.42, 1.3, fill)

# 4) 병 선반장 (나무 3단, 병·상자)
jr = P["Kit_JarRack"]
JX, JY = -3.6, 4.9
for sx in (-1, 1):
    box(jr, (JX + sx * 2.1, JY, 3.9), (0.2, 1.4, 4.6), WOOD_D, bev=0.06)
for k, z in enumerate((3.3, 4.9, 6.5)):
    box(jr, (JX, JY, z), (4.4, 1.4, 0.18), WOOD, bev=0.05)
fills = [JAR_A, JAR_B, JAR_C, JAR_B, JAR_A]
for k in range(4):
    jar(jr, (JX - 1.5 + k * 1.0, JY - 0.1, 3.4), 0.36, 1.2, fills[k])
for k in range(5):
    jar(jr, (JX - 1.6 + k * 0.8, JY - 0.1, 5.0), 0.3, 1.0, fills[(k + 2) % 5])
for k in range(4):
    jar(jr, (JX - 1.5 + k * 1.0, JY - 0.1, 6.6), 0.4, 1.4, fills[(k + 1) % 5])

# 5) 설탕 깔때기 기계 (계기판 장 + 깔때기)
hp = P["Kit_Hopper"]
HX, HY = 3.0, 3.6
box(hp, (HX, HY, 2.0), (2.6, 2.2, 4.0), STEEL, bev=0.18, seg=3)
box(hp, (HX, HY - 1.11, 2.6), (2.0, 0.06, 1.6), STEEL_L, bev=0.06)
box(hp, (HX - 0.5, HY - 1.16, 3.05), (0.7, 0.04, 0.45), SCREEN, bev=0.03, seg=2)
for k, col in enumerate((BTN_G, BTN_R, BTN_O, BTN_G, BTN_O, BTN_R)):
    x = HX - 0.6 + (k % 3) * 0.55
    z = 2.45 - (k // 3) * 0.45
    cyl(hp, (x, HY - 1.12, z), (x, HY - 1.22, z), 0.13, 0.12, col, seg=10)
lathe(hp, [(0.25, 0), (0.25, 0.6), (0.4, 0.7), (1.3, 1.9), (1.35, 2.5), (1.3, 2.6), (1.22, 2.55), (1.2, 2.0), (0.3, 0.8), (0, 0.8)], STEEL_L, seg=20, c=(HX, HY, 4.0))
cyl(hp, (HX, HY, 4.0), (HX, HY, 3.6), 0.3, 0.3, STEEL_D, seg=12)
cyl(hp, (HX + 1.0, HY, 3.4), (HX + 1.0, HY - 1.6, 3.4), 0.18, 0.18, STEEL_D, seg=10)  # 라인으로 가는 관

# 6) 큰 프레스 탑 (가운데 오른쪽): 받침 틀 + 유리 창 + 위험 줄무늬 띠 + 큰 통(별 메달) + 위 뚜껑·관
pt = P["Kit_PressTower"]
PX, PY = 8.6, 1.4
for sx in (-1, 1):
    for sy in (-1, 1):
        box(pt, (PX + sx * 2.2, PY + sy * 1.2, 4.9), (0.5, 0.5, 3.4), STEEL, bev=0.12)
box(pt, (PX, PY, 3.35), (5.0, 3.0, 0.3), STEEL_D, bev=0.1)
box(P["Kit_Glass"], (PX, PY - 1.25, 4.9), (3.9, 0.05, 2.9), GLASSC, bev=0.05, seg=2)
for k in range(16):  # 위험 줄무늬 띠: 통에 붙은 노랑·진회색 판 16장
    a0 = 2 * math.pi * (k + 0.5) / 16
    col = HAZ_Y if k % 2 == 0 else HAZ_D
    q = Vector((PX + math.cos(a0) * 2.98, PY + math.sin(a0) * 2.98, 6.95))
    box(pt, q, (1.2, 0.1, 0.55), col, bev=0.03, seg=2, m=rot(z=math.degrees(a0) + 90))
lathe(pt, [(0, 6.6), (2.9, 6.6), (2.95, 6.7), (2.95, 7.25), (3.05, 7.3), (3.1, 7.45), (3.1, 10.2), (3.0, 10.4), (2.4, 10.6), (1.6, 10.7), (0, 10.7)], STEEL, seg=32, c=(PX, PY, 0))
lathe(pt, [(0, 10.6), (1.5, 10.6), (1.5, 11.7), (1.6, 11.8), (1.0, 12.0), (1.0, 12.8), (0.9, 12.9), (0, 12.9)], STEEL_L, seg=24, c=(PX, PY, 0))
star_medallion(pt, (PX, PY - 3.12, 8.8), 1.05, DALGONA, DALGONA_D)
cyl(pt, (PX + 3.1, PY, 9.0), (PX + 4.2, PY, 9.0), 0.4, 0.4, STEEL_D, seg=14)  # 옆 관
cyl(pt, (PX + 4.2, PY, 9.0), (PX + 4.2, PY, 3.4), 0.3, 0.3, STEEL_D, seg=12)
cyl(pt, (PX, PY, 12.9), (PX, PY, 16.5), 0.55, 0.55, STEEL_L, seg=16)  # 위로 올라가는 관
# 누름 머리 (오르내림) + 그 아래 빛나는 달고나
ph = P["Kit_PressHead"]
cyl(ph, (PX, PY, 6.5), (PX, PY, 5.3), 0.35, 0.35, STEEL_L, seg=14)
rounded_disc(ph, (PX, PY, 4.75), 1.3, 0.55, STEEL, seg=28)
star_relief(ph, (PX, PY, 4.73), 0.8, 0.06, STEEL_D, m=rot(x=180))
rounded_disc(P["Kit_Glow"], (PX, PY, 3.5), 1.2, 0.12, GLOW, seg=24)
dalgona(P["Kit_Glow"], (PX, PY, 3.62), r=0.95, h=0.1)

# 7) 오른쪽 조작장 (키 큰 스테인리스 장 + 화면 + 버튼)
cc = P["Kit_ControlCabinet"]
KX, KY = 13.0, 3.8
box(cc, (KX, KY, 3.6), (2.2, 1.6, 7.2), STEEL, bev=0.16, seg=3)
box(cc, (KX, KY - 0.81, 5.6), (1.2, 0.05, 0.8), SCREEN, bev=0.05, seg=2)
for k, col in enumerate((BTN_R, BTN_O)):
    cyl(cc, (KX - 0.3 + k * 0.6, KY - 0.8, 4.6), (KX - 0.3 + k * 0.6, KY - 0.92, 4.6), 0.14, 0.13, col, seg=10)
box(cc, (KX, KY - 0.81, 2.2), (1.6, 0.05, 2.6), STEEL_L, bev=0.06)

# 8) 바퀴 달린 쟁반 선반 (맨 오른쪽, 8단, 달고나 쟁반)
tr = P["Kit_TrayRack"]
RX, RY = 16.4, 2.2
for sx in (-1, 1):
    for sy in (-1, 1):
        box(tr, (RX + sx * 1.6, RY + sy * 1.1, 4.9), (0.16, 0.16, 9.2), STEEL, bev=0.04, seg=2)
        ball(tr, (RX + sx * 1.6, RY + sy * 1.1, 0.18), 0.18, RUBBER, seg=(10, 6))
for k in range(8):
    z = 1.2 + k * 1.05
    box(tr, (RX, RY, z), (3.3, 2.3, 0.08), STEEL_L, bev=0.03, seg=2)
    for j in range(3):
        box(P["Kit_TrayDalgona"], (RX - 1.0 + j * 1.0, RY - 0.1, z + 0.14), (0.8, 1.7, 0.2), DALGONA, bev=0.07, seg=2)

# 9) 상자 (별 그림): 하나짜리 + 쌓은 무더기
def box_star(p, c, s, ry=0):
    m = rot(z=ry)
    box(p, c, s, BOX, bev=0.12, m=m)
    box(p, V(c) + m.to_3x3() @ Vector((0, 0, s[2] / 2 - 0.01)), (s[0] * 0.96, 0.12, 0.03), BOX_D, bev=0.0, m=m)  # 테이프
    star_relief(p, V(c) + m.to_3x3() @ Vector((0, -s[1] / 2 - 0.005, 0)), min(s[0], s[2]) * 0.26, 0.02, BOX_D, m=m @ rot(x=90))

bx = P["Kit_Box"]
box_star(bx, (19.5, -6.0, 0.9), (2.0, 1.8, 1.8))
bs = P["Kit_BoxStack"]
for (dx, dy, dz, ry) in ((0, 0, 0.9, 0), (2.1, 0.2, 0.9, 6), (0.9, 0.1, 2.7, -8), (1.1, -2.1, 0.9, 3)):
    box_star(bs, (13.5 + dx, -5.0 + dy, dz), (2.0, 1.8, 1.8), ry)

# 10) 앞 작업대 (스테인리스, 별 틀 쟁반·밀대·설탕 가루) + 들통
pp = P["Kit_PrepTable"]
TX, TY = -4.5, -6.2
box(pp, (TX, TY, CH - 0.15), (8.5, 3.8, 0.3), STEEL, bev=0.12)
box(pp, (TX, TY, 0.9), (8.0, 3.3, 0.12), STEEL_D, bev=0.04)
for sx in (-1, 1):
    for sy in (-1, 1):
        leg(pp, (TX + sx * 4.0, TY + sy * 1.65), CH - 0.3)
box(pp, (TX - 0.5, TY + 0.1, CH + 0.06), (2.8, 1.8, 0.1), STEEL_L, bev=0.04, seg=2)  # 쟁반
for k, (dx, dy) in enumerate(((-1.0, -0.4), (-0.1, -0.4), (0.8, -0.4), (-0.6, 0.45), (0.4, 0.45))):
    lathe(pp, [(0.32, 0), (0.36, 0.04), (0.36, 0.2), (0.32, 0.22), (0.3, 0.04), (0, 0.04)], STEEL_D, seg=10, c=(TX - 0.5 + dx, TY + 0.1 + dy, CH + 0.11))
cyl(pp, (TX + 1.4, TY - 0.6, CH + 0.2), (TX + 3.2, TY + 0.1, CH + 0.2), 0.18, 0.18, WOOD, seg=12)  # 밀대
lathe(pp, [(0, 0), (0.55, 0), (0.3, 0.06), (0, 0.08)], FLOUR, seg=12, c=(TX + 2.2, TY - 1.0, CH))
sp = P["Kit_StockPot"]
lathe(sp, [(0, 0), (1.0, 0), (1.08, 0.08), (1.08, 1.7), (1.14, 1.76), (1.04, 1.8), (0, 1.7)], STEEL_L, seg=24, c=(-11.6, -6.4, CH))
cyl(sp, (-11.6, -6.4, CH + 1.6), (-11.0, -6.6, CH + 3.0), 0.07, 0.07, STEEL_D, seg=8)  # 국자 자루

# 11) 왼쪽 벽 조리대 (볼·저울·조리도구 통)
sc = P["Kit_SideCounter"]
SX, SY = -15.0, -3.4
box(sc, (SX, SY, CH - 0.15), (2.6, 6.0, 0.3), STEEL, bev=0.1)
box(sc, (SX, SY, (CH - 0.3) / 2), (2.4, 5.8, CH - 0.3), CREAM, bev=0.12)
lathe(sc, [(0, 0), (0.5, 0), (0.95, 0.35), (1.1, 0.6), (1.04, 0.62), (0.9, 0.38), (0, 0.1)], STEEL_L, seg=24, c=(SX + 0.1, SY - 1.6, CH))  # 볼
box(sc, (SX, SY + 0.6, CH + 0.3), (1.0, 1.0, 0.6), CREAM, bev=0.14)  # 저울
cyl(sc, (SX, SY + 0.6, CH + 0.62), (SX, SY + 0.6, CH + 0.68), 0.55, 0.6, STEEL_L, seg=16)
cyl(sc, (SX - 0.52, SY + 0.6, CH + 0.35), (SX - 0.56, SY + 0.6, CH + 0.35), 0.25, 0.25, BTN_R, seg=12)
cyl(sc, (SX, SY + 2.2, CH), (SX, SY + 2.2, CH + 1.0), 0.32, 0.34, STEEL_L, seg=14)  # 조리도구 통
for k in range(4):
    a = k * 1.4
    cyl(sc, (SX + math.cos(a) * 0.12, SY + 2.2 + math.sin(a) * 0.12, CH + 0.6), (SX + math.cos(a) * 0.3, SY + 2.2 + math.sin(a) * 0.3, CH + 1.9), 0.05, 0.05, WOOD, seg=6)
    ball(sc, (SX + math.cos(a) * 0.32, SY + 2.2 + math.sin(a) * 0.32, CH + 1.95), (0.1, 0.1, 0.14), WOOD, seg=(8, 6))

# 12) 매단 등 3개 (갓 + 줄) / 전구는 Kit_Glow
lp = P["Kit_PendantLamps"]
for x in (-8.0, 1.0, 10.0):
    q = Vector((x, -0.5, 13.0))
    cyl(lp, q + Vector((0, 0, 0.6)), q + Vector((0, 0, 4.0)), 0.05, 0.05, RUBBER, seg=6)
    lathe(lp, [(1.7, -0.1), (1.72, 0), (1.3, 0.45), (0.5, 0.75), (0.2, 0.8), (0, 0.82)], (196, 170, 150), seg=24, c=q)
    lathe(lp, [(0, -0.05), (1.65, -0.05), (1.7, -0.02)], STEEL_L, seg=24, c=q)
    ball(P["Kit_Glow"], q + Vector((0, 0, -0.2)), 0.45, GLOW, seg=(14, 8))

# 13) 천장 따라 가는 은색 관 (곧은 관 + 꺾인 곳)
du = P["Kit_Ducts"]
DZ = 13.8
cyl(du, (-12.0, 5.2, DZ), (14.0, 5.2, DZ), 0.75, 0.75, STEEL_L, seg=18)
for x in (-6.0, 0.0, 6.0, 12.0):
    cyl(du, (x - 0.12, 5.2, DZ), (x + 0.12, 5.2, DZ), 0.84, 0.84, STEEL, seg=18)  # 이음 띠
for x0_, z1 in ((-7.6, 9.0),):
    cyl(du, (x0_, 5.2, DZ), (x0_, 5.2, z1), 0.6, 0.6, STEEL_L, seg=16)
    ball(du, (x0_, 5.2, DZ), 0.76, STEEL_L, seg=(16, 10))
    cyl(du, (x0_, 5.2, z1), (x0_ + 1.5, 5.2, z1), 0.6, 0.6, STEEL_L, seg=16)
    ball(du, (x0_, 5.2, z1), 0.6, STEEL_L, seg=(16, 10))
cyl(du, (14.0, 5.2, DZ), (14.0, -1.0, DZ), 0.75, 0.75, STEEL_L, seg=18)
ball(du, (14.0, 5.2, DZ), 0.76, STEEL_L, seg=(16, 10))

# 14) 간판 판(글씨 없음, 별 메달) + 별 포스터 + 창문 + 천장 들보
sg = P["Kit_SignBoard"]
GX, GY, GZ = 0.0, 5.75, 10.2
box(sg, (GX, GY, GZ), (10.0, 0.25, 3.0), WOOD_D, bev=0.12)
box(sg, (GX, GY - 0.12, GZ), (9.5, 0.1, 2.6), CREAM, bev=0.08)
star_medallion(sg, (GX - 3.4, GY - 0.2, GZ), 1.05, DALGONA, DALGONA_D)
for sx in (-1, 1):
    ball(sg, (GX + sx * 4.6, GY - 0.2, GZ + 1.2), 0.1, BRASS, seg=(8, 6))
ps = P["Kit_Poster"]
box(ps, (-15.9, 1.8, 7.4), (0.08, 3.0, 4.0), CREAM, bev=0.03, seg=2)
star_medallion(ps, (-15.82, 1.8, 7.6), 1.1, DALGONA, DALGONA_D, m=rot(z=90))
for k, (dy, dz) in enumerate(((-1.0, 5.8), (1.0, 5.8), (-1.1, 9.0), (1.1, 9.1))):
    star_relief(ps, (-15.84, 1.8 + dy, dz), 0.16, 0.02, (232, 150, 140), m=rot(z=90) @ rot(x=90))
wn = P["Kit_Window"]
WX, WYc, WZ = -15.95, -4.0, 6.0
for dz in (-2.65, 2.65):  # 창틀 (위·아래·옆 4개)
    box(wn, (WX, WYc, WZ + dz), (0.3, 5.6, 0.3), WOOD, bev=0.08)
for dy in (-2.65, 2.65):
    box(wn, (WX, WYc + dy, WZ), (0.3, 0.3, 5.6), WOOD, bev=0.08)
box(P["Kit_Glass"], (WX + 0.02, WYc, WZ), (0.12, 5.0, 5.0), (220, 236, 244), bev=0.02, seg=1)
for k in (-1, 1):
    box(wn, (WX - 0.05, WYc + k * 0.85, WZ), (0.34, 0.14, 5.0), WOOD, bev=0.03, seg=2)
for z in (WZ - 0.9, WZ + 0.9):
    box(wn, (WX - 0.05, WYc, z), (0.34, 5.0, 0.14), WOOD, bev=0.03, seg=2)
box(wn, (WX + 0.4, WYc, WZ - 2.9), (0.9, 6.0, 0.2), WOOD, bev=0.06)  # 창턱
bm_ = P["Kit_CeilingBeams"]
for x in (-12.0, -4.0, 4.0, 12.0):
    box(bm_, (x, -2.0, 17.5), (0.7, 16.0, 0.9), BEAM, bev=0.12)
box(bm_, (0, 5.6, 16.9), (34.0, 0.6, 0.7), BEAM, bev=0.1)
box(bm_, (0, -2.0, 16.9), (34.0, 0.6, 0.7), BEAM, bev=0.1)


# ───────────── 오브젝트 + 팔레트 재질 ─────────────
IMG = palette_image()
MAT = bpy.data.materials.new("CozyKitPalette")
MAT.use_nodes = True
nt = MAT.node_tree
bsdf = nt.nodes["Principled BSDF"]
bsdf.inputs["Roughness"].default_value = 0.55
tex = nt.nodes.new("ShaderNodeTexImage")
tex.image = IMG
tex.interpolation = "Closest"
nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])

NOTES = {
    "Kit_Conveyor": "스테인리스 컨베이어 라인 (아래 장 2개·들통 3개) — Metal",
    "Kit_ConveyorDalgona": "벨트 위 별 달고나 7개 (벨트 방향으로 옮기면 흐름)",
    "Kit_OvenCounter": "오븐 받침 조리대 + 아래 달고나 상자",
    "Kit_Oven": "오븐 (문·손잡이·다이얼 3개·작은 화면) — Metal",
    "Kit_WallShelf": "오븐 위 벽 선반 + 병 5개",
    "Kit_JarRack": "나무 3단 병 선반장",
    "Kit_Hopper": "설탕 깔때기 기계 (계기판 장 + 깔때기 + 관) — Metal",
    "Kit_PressTower": "큰 프레스 탑 (기둥 틀·위험 줄무늬 띠·별 메달 큰 통·관) — Metal",
    "Kit_PressHead": "프레스 누름 머리 (위아래로 움직임)",
    "Kit_ControlCabinet": "키 큰 조작장 (화면·버튼) — Metal",
    "Kit_TrayRack": "바퀴 달린 8단 쟁반 선반 — Metal",
    "Kit_TrayDalgona": "선반 위 달고나 쟁반 24개",
    "Kit_Box": "별 그림 상자 하나 (복제해서 씀)",
    "Kit_BoxStack": "상자 무더기 4개",
    "Kit_PrepTable": "앞 스테인리스 작업대 (별 틀 쟁반·밀대·설탕 가루) — Metal",
    "Kit_StockPot": "큰 들통 + 국자",
    "Kit_SideCounter": "왼쪽 벽 조리대 (볼·저울·조리도구 통)",
    "Kit_PendantLamps": "매단 등 3개 갓·줄 (전구는 Kit_Glow)",
    "Kit_Ducts": "천장 은색 관",
    "Kit_SignBoard": "간판 판 (글씨 없음 — 게임에서 SurfaceGui로 '달고나 공장')",
    "Kit_Poster": "별 달고나 포스터 (왼쪽 벽)",
    "Kit_Window": "나무 창틀 + 창턱 (유리는 Kit_Glass)",
    "Kit_CeilingBeams": "천장 나무 들보",
    "Kit_Glass": "오븐 문 유리·프레스 창·창문 유리 (Glass, Transparency 0.5)",
    "Kit_Glow": "오븐 속 불빛·프레스 속 빛나는 달고나·등 전구 (Neon, PointLight 자리)",
}
rows = []
objs = []
total = 0
for p in P.values():
    bm = p.bm
    if not bm.faces:
        continue
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
    rows.append(f"{p.name}\ttris={tris}\tsize=({s.x:.2f}, {s.z:.2f}, {s.y:.2f})\tcenter=({-c.x:.2f}, {c.z:.2f}, {c.y:.2f})\t{NOTES.get(p.name, '')}")
rows.append(f"# 합계 삼각형 {total}. 그림처럼 배치된 자리 그대로 내보냄 (원점 = 방 바닥 가운데, 뒷벽 = Roblox +Z 6, 왼벽 = Roblox X +16).")
with open(os.path.join(OUT, "factory_kit_parts.txt"), "w", encoding="utf-8") as f:
    f.write("\n".join(rows) + "\n")
print("\n".join(rows))

for o in objs:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "dalgona_factory_kit.glb"), export_format="GLB", use_selection=True, export_apply=True)

# ───────────── 미리 보기 (방: 바닥 타일·벽·천장 — 내보내지 않음) ─────────────
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (1.0, 0.85, 0.7, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.45
scene.world = world


def plane(name, loc, scale, rotx, roty, rgb):
    bpy.ops.mesh.primitive_plane_add(size=1, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    o.rotation_euler = (math.radians(rotx), math.radians(roty), 0)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*[(c / 255) ** 2.2 for c in rgb], 1)
    o.data.materials.append(m)


plane("Floor", (0, -2, 0), (34, 18, 1), 0, 0, (236, 206, 186))
plane("BackWall", (0, 6.1, 9), (34, 18, 1), 90, 0, (242, 222, 200))
plane("LeftWall", (-16.1, -2, 9), (18, 16, 1), 0, 90, (240, 220, 198))
plane("Ceiling", (0, -2, 18.2), (34, 18, 1), 180, 0, (226, 176, 120))
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 1.6
sun.data.angle = math.radians(30)
sun.data.color = (1.0, 0.9, 0.78)
sun.rotation_euler = (math.radians(60), math.radians(15), math.radians(-35))
scene.collection.objects.link(sun)
for x in (-8.0, 1.0, 10.0):
    pt_ = bpy.data.objects.new("Pt", bpy.data.lights.new("Pt", "POINT"))
    pt_.data.energy = 900
    pt_.data.color = (1.0, 0.8, 0.55)
    pt_.data.shadow_soft_size = 1.2
    pt_.location = (x, -0.5, 12.2)
    scene.collection.objects.link(pt_)
for q in ((-10.8, 1.0, CH + 1.3), (PX, PY - 1.6, 4.2)):
    pt_ = bpy.data.objects.new("Pt", bpy.data.lights.new("Pt", "POINT"))
    pt_.data.energy = 120
    pt_.data.color = (1.0, 0.75, 0.45)
    pt_.location = q
    scene.collection.objects.link(pt_)
emit = bpy.data.materials.new("Glow")
emit.use_nodes = True
eb = emit.node_tree.nodes["Principled BSDF"]
eb.inputs["Base Color"].default_value = (1, 0.85, 0.6, 1)
eb.inputs["Emission Color"].default_value = (1, 0.8, 0.5, 1)
eb.inputs["Emission Strength"].default_value = 5
scene.objects["Kit_Glow"].data.materials[0] = emit
glass = bpy.data.materials.new("GlassPrev")
glass.use_nodes = True
gb = glass.node_tree.nodes["Principled BSDF"]
gb.inputs["Base Color"].default_value = (0.85, 0.95, 0.97, 1)
gb.inputs["Alpha"].default_value = 0.25
glass.surface_render_method = "BLENDED"
scene.objects["Kit_Glass"].data.materials[0] = glass
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.lens = 24
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


shoot((1.0, -24.0, 8.0), (1.0, 2.0, 6.5), "factory_kit_preview.png")
shoot((-12.0, -14.0, 9.0), (6.0, 3.0, 5.0), "factory_kit_preview2.png")
shoot((-4.0, -9.0, 7.0), (-11.5, 2.0, 4.5), "factory_kit_preview3.png")
print("[factory_kit] done")
