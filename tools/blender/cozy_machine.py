# 아늑한 가게 그림체의 새 달고나 기계 한 대 (사용자 요청 2026-11-23)
#   참고: 사용자 가게 사진(따뜻한 나무 카운터, 크림 벽, 주황·크림 줄무늬 차양, 전구 줄, 칠판 메뉴, 유리병)과
#   사용자 Blender 블록아웃 store.glb (단순한 상자 + 모서리를 작게 깎음, 가게 전체 삼각형 약 2천).
#   "모서리가 너무 각지지 않게 면을 나눠 부드럽게" → 모든 상자 모서리를 3단으로 둥글게 깎고(bevel), 평평한 면은 평평하게,
#   깎인 모서리만 부드럽게 보이도록 각도 기준으로 매끈 처리(set_sharp_from_angle).
#
# 기계 구성 (앞 = Blender -Y = 플레이어 쪽):
#   나무 받침장(크림 문판 2개 + 놋쇠 손잡이) / 밝은 나무 윗판 / 뒤 세움판(크림 판 + 글씨 없는 칠판) /
#   주황·크림 줄무늬 차양 + 둥근 끝단 / 차양 밑 전구 줄 / 오른쪽 기둥 등불 /
#   왼쪽: 작은 크림 화구 + 구리 냄비(설탕 녹이기) / 가운데: 돌림판(틀 4칸, 달고나) + 위에서 누르는 손잡이 /
#   오른쪽 뒤: 유리 설탕 병 / 오른쪽 앞: 나무 쟁반(다 된 달고나 3개)
#
# 부품 = 움직이거나 재질이 다른 것끼리 나눔 (MeshPart 하나씩):
#   Cozy_Body(나무·크림 몸, 화구, 쟁반), Cozy_Awning(차양), Cozy_Lights(전구·등불 유리 → Neon),
#   Cozy_Kettle(냄비), Cozy_Jar(유리병 → 반투명), Cozy_Sugar(병 속 설탕), Cozy_Plate(돌림판 + 틀 속 달고나, Y축으로 돎),
#   Cozy_Press(누름 손잡이, 뒤 경첩에서 위아래로 돎), Cozy_Output(쟁반 위 달고나)
# 색 = 팔레트 텍스처 한 장 공용 (customers.py, alley.py와 같은 방식). 글자·상표 없음.
#
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/cozy_machine.py -- <출력 폴더(절대 경로)>
# 결과: dalgona_cozy_machine.glb, cozy_preview.png, cozy_preview2.png(누름 손잡이 내린 모습), cozy_parts.txt
# 크기 = 게임 stud. 원점 = 바닥 가운데. 좌표 변환 Blender (x, y, z) → Roblox (-x, z, y).

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
    img = bpy.data.images.new("CozyPalette", size, size, alpha=False)
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


P = {n: Part(n) for n in ("Cozy_Body", "Cozy_Awning", "Cozy_Lights", "Cozy_Kettle", "Cozy_Jar", "Cozy_Sugar",
                         "Cozy_Plate", "Cozy_Press", "Cozy_Output")}


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


# ───────────── 기계 ─────────────
W, D = 6.2, 3.0
H0 = 3.0  # 받침장 높이
TOP = H0 + 0.24  # 윗판 윗면
body = P["Cozy_Body"]

# 받침장: 나무 몸 + 진한 굽 + 크림 문판 2개(나무 테) + 놋쇠 손잡이
box(body, (0, 0, 0.12), (W - 0.1, D - 0.1, 0.24), WOOD_D)
box(body, (0, 0, 0.24 + (H0 - 0.24) / 2), (W, D, H0 - 0.24), WOOD, bev=0.12)
for sx in (-1, 1):
    fc = Vector((sx * W / 4, -D / 2 - 0.02, 0.24 + (H0 - 0.24) / 2))
    box(body, fc, (W / 2 - 0.5, 0.08, H0 - 0.8), WOOD_D, bev=0.04)
    box(body, fc + Vector((0, -0.04, 0)), (W / 2 - 0.75, 0.06, H0 - 1.05), CREAM, bev=0.05)
    ball(body, fc + Vector((-sx * (W / 4 - 0.55), -0.1, 0.15)), 0.08, BRASS, seg=(10, 6))
# 윗판 (밝은 나무, 앞으로 조금 나옴) + 아래 진한 띠
box(body, (0, -0.05, H0 + 0.12), (W + 0.3, D + 0.25, 0.24), WOOD_L, bev=0.08)
box(body, (0, -0.05, H0 - 0.02), (W + 0.1, D + 0.15, 0.08), WOOD_D, bev=0.03)
# 뒤 세움판: 나무 테 + 크림 판 + 글씨 없는 칠판(나무 테)
BY = D / 2 - 0.2
box(body, (0, BY, TOP + 1.6), (W, 0.36, 3.2), WOOD, bev=0.1)
box(body, (0, BY - 0.2, TOP + 1.55), (W - 0.5, 0.06, 2.7), CREAM, bev=0.05)
box(body, (0, BY - 0.25, TOP + 1.75), (2.4, 0.08, 1.6), WOOD_D, bev=0.05)
box(body, (0, BY - 0.3, TOP + 1.75), (2.15, 0.05, 1.35), BOARD, bev=0.03)
# 오른쪽 기둥 + 등불
px = W / 2 - 0.15
box(body, (px, -D / 2 + 0.3, TOP + 1.45), (0.24, 0.24, 2.9), WOOD_D, bev=0.06)
lc = Vector((px - 0.55, -D / 2 + 0.3, TOP + 2.2))
box(body, (px - 0.28, -D / 2 + 0.3, TOP + 2.75), (0.6, 0.08, 0.08), WOOD_D, bev=0.02)
box(body, lc + Vector((0, 0, 0.42)), (0.42, 0.42, 0.1), WOOD_D, bev=0.03)
box(body, lc + Vector((0, 0, -0.42)), (0.42, 0.42, 0.1), WOOD_D, bev=0.03)
for sx in (-1, 1):
    for sy in (-1, 1):
        box(body, lc + Vector((sx * 0.17, sy * 0.17, 0)), (0.05, 0.05, 0.75), WOOD_D, bev=0.015, seg=1)
box(P["Cozy_Lights"], lc, (0.3, 0.3, 0.72), BULB, bev=0.05)
cyl(body, lc + Vector((0, 0, 0.47)), lc + Vector((0, 0, 0.55)), 0.06, 0.06, BRASS, seg=8)

# 왼쪽: 크림 화구 + 구리 냄비
sx0 = -W / 2 + 1.15
box(body, (sx0, -0.25, TOP + 0.3), (1.6, 1.5, 0.6), CREAM_D, bev=0.1)
lathe(body, [(0, 0), (0.55, 0), (0.55, 0.04), (0.42, 0.06), (0, 0.06)], STEEL, seg=16, c=(sx0, -0.25, TOP + 0.6))
cyl(body, (sx0 - 0.5, -1.0, TOP + 0.3), (sx0 - 0.5, -1.1, TOP + 0.3), 0.1, 0.1, KNOB, seg=10)
cyl(body, (sx0 + 0.5, -1.0, TOP + 0.3), (sx0 + 0.5, -1.1, TOP + 0.3), 0.1, 0.1, KNOB, seg=10)
kt = P["Cozy_Kettle"]
kc = Vector((sx0, -0.25, TOP + 0.66))
lathe(kt, [(0, 0), (0.48, 0), (0.56, 0.08), (0.6, 0.35), (0.6, 0.55), (0.62, 0.6), (0.58, 0.62), (0.54, 0.58), (0.5, 0.3), (0, 0.3)], COPPER, seg=20, c=kc)
lathe(kt, [(0.56, 0.62), (0.3, 0.72), (0.1, 0.75), (0, 0.76)], COPPER_D, seg=20, c=kc)  # 뚜껑
ball(kt, kc + Vector((0, 0, 0.82)), (0.08, 0.08, 0.06), WOOD_D, seg=(10, 6))
cyl(kt, kc + Vector((0.58, 0, 0.45)), kc + Vector((1.05, 0, 0.55)), 0.05, 0.05, WOOD_D, seg=8)  # 손잡이
ball(kt, kc + Vector((1.06, 0, 0.55)), 0.06, WOOD_D, seg=(8, 6))

# 가운데: 돌림판 + 틀 4칸 + 달고나
pl = P["Cozy_Plate"]
pc = Vector((0.25, -0.35, TOP))
cyl(body, pc, pc + Vector((0, 0, 0.12)), 0.35, 0.35, BRASS, seg=14)  # 받침 축
rounded_disc(pl, pc + Vector((0, 0, 0.12)), 1.05, 0.16, STEEL, seg=28)
for k in range(4):
    a = -math.pi / 2 + k * math.pi / 2  # 앞·오른쪽·뒤·왼쪽
    q = pc + Vector((math.cos(a) * 0.62, math.sin(a) * 0.62, 0.28))
    lathe(pl, [(0.36, 0), (0.4, 0.04), (0.38, 0.06), (0.33, 0.02), (0, 0.02)], (186, 182, 176), seg=16, c=q)  # 틀 테
    dalgona(pl, q + Vector((0, 0, 0.02)), r=0.32, h=0.05, star=(k % 2 == 0))
# 누름 손잡이: 뒤 놋쇠 기둥 + 경첩, 나무 팔, 누름 머리
hinge = Vector((0.25, 0.75, TOP + 1.25))
box(body, (hinge.x, hinge.y + 0.05, TOP + 0.62), (0.28, 0.28, 1.24), BRASS, bev=0.06)
pr = P["Cozy_Press"]
cyl(pr, hinge + Vector((-0.2, 0, 0)), hinge + Vector((0.2, 0, 0)), 0.11, 0.11, BRASS, seg=12)
box(pr, hinge + Vector((0, -1.05, 0)), (0.22, 2.3, 0.2), WOOD, bev=0.06)  # 나무 팔 (경첩 → 앞)
head = Vector((pc.x, pc.y - 0.62, hinge.z))  # 돌림판 앞 칸 바로 위
cyl(pr, head + Vector((0, 0, -0.05)), head + Vector((0, 0, -0.45)), 0.07, 0.07, BRASS, seg=10)
rounded_disc(pr, head + Vector((0, 0, -0.62)), 0.34, 0.16, BRASS, seg=18)
cyl(pr, hinge + Vector((0, -2.05, 0.05)), hinge + Vector((0, -2.05, 0.4)), 0.09, 0.08, WOOD_D, seg=10)  # 손잡이 끝
ball(pr, hinge + Vector((0, -2.05, 0.46)), 0.11, WOOD_D, seg=(10, 6))

# 오른쪽 뒤: 유리 설탕 병 (나무 뚜껑) / 오른쪽 앞: 나무 쟁반 + 달고나 3개
jc = Vector((1.85, 0.55, TOP))
lathe(P["Cozy_Jar"], [(0, 0), (0.42, 0), (0.48, 0.08), (0.48, 1.0), (0.38, 1.12), (0.34, 1.18), (0, 1.18)], GLASS, seg=18, c=jc)
lathe(P["Cozy_Sugar"], [(0, 0.03), (0.44, 0.03), (0.44, 0.6), (0.3, 0.66), (0, 0.68)], SUGAR, seg=16, c=jc)
lathe(body, [(0, 1.16), (0.4, 1.16), (0.42, 1.22), (0.4, 1.3), (0, 1.3)], WOOD_D, seg=18, c=jc)
tc = Vector((1.75, -0.85, TOP))
box(body, tc + Vector((0, 0, 0.05)), (1.7, 1.0, 0.1), WOOD_L, bev=0.04)
for sx in (-1, 1):
    box(body, tc + Vector((sx * 0.83, 0, 0.12)), (0.06, 1.0, 0.16), WOOD_D, bev=0.02, seg=2)
for sy in (-1, 1):
    box(body, tc + Vector((0, sy * 0.48, 0.12)), (1.7, 0.06, 0.16), WOOD_D, bev=0.02, seg=2)
for k, x in enumerate((-0.5, 0.0, 0.5)):
    dalgona(P["Cozy_Output"], tc + Vector((x, 0.05 * (k - 1), 0.1)), r=0.24, h=0.05)

# 차양: 주황·크림 줄무늬 (기울어진 판) + 둥근 끝단, 받침 까치발
aw = P["Cozy_Awning"]
NS = 8
AZ = TOP + 3.35
for k in range(NS):
    x = -W / 2 - 0.2 + (k + 0.5) * (W + 0.4) / NS
    col = ORANGE if k % 2 == 0 else AWN_CREAM
    box(aw, (x, -0.15, AZ), ((W + 0.4) / NS + 0.002, 2.1, 0.08), col, bev=0.03, seg=2, m=rot(x=-24))
    lip = Vector((x, -1.12, AZ - 0.48))
    cyl(aw, lip + Vector((-(W + 0.4) / NS / 2, 0, 0)), lip + Vector(((W + 0.4) / NS / 2, 0, 0)), 0.17, 0.17, col, seg=12)  # 둥근 끝단
for sx in (-1, 1):
    box(body, (sx * (W / 2 - 0.3), BY - 0.6, AZ - 0.35), (0.12, 1.1, 0.12), WOOD_D, bev=0.03, m=rot(x=-35))
# 전구 줄 (차양 밑, 처지는 곡선)
li = P["Cozy_Lights"]
NB = 7
prev = None
for k in range(NB):
    t = k / (NB - 1)
    x = -W / 2 + 0.4 + t * (W - 0.8)
    z = AZ - 0.75 - 0.18 * math.sin(math.pi * t)
    q = Vector((x, -0.95, z))
    ball(li, q + Vector((0, 0, -0.12)), (0.09, 0.09, 0.11), BULB, seg=(10, 6))
    cyl(body, q, q + Vector((0, 0, -0.05)), 0.04, 0.04, WIRE, seg=6)
    if prev is not None:
        cyl(body, prev, q, 0.015, 0.015, WIRE, seg=4)
    prev = q

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
    "Cozy_Body": "나무·크림 몸 (SmoothPlastic 또는 Wood)",
    "Cozy_Awning": "차양 (Fabric)",
    "Cozy_Lights": "전구·등불 유리 (Neon 또는 PointLight를 넣을 자리)",
    "Cozy_Kettle": "구리 냄비 (Metal)",
    "Cozy_Jar": "유리병 (Glass, Transparency 0.5)",
    "Cozy_Sugar": "병 속 설탕",
    "Cozy_Plate": "돌림판 + 틀 속 달고나 (가운데 축을 중심으로 Y축 회전)",
    "Cozy_Press": "누름 손잡이 (경첩에서 앞쪽이 내려가게 X축으로 약 12° 돌리면 누름 머리가 달고나에 닿음)",
    "Cozy_Output": "쟁반 위 다 된 달고나 3개",
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
    me.set_sharp_from_angle(angle=math.radians(35))  # 평평한 면은 평평, 깎은 모서리·둥근 면만 부드럽게
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
rows.append(f"# 경첩(누름 손잡이 회전축) = ({-hinge.x:.2f}, {hinge.z:.2f}, {hinge.y:.2f}), 돌림판 축 = ({-pc.x:.2f}, {pc.z:.2f}, {pc.y:.2f})")
with open(os.path.join(OUT, "cozy_parts.txt"), "w", encoding="utf-8") as f:
    f.write("\n".join(rows) + "\n")
print("\n".join(rows))

for o in objs:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "dalgona_cozy_machine.glb"), export_format="GLB", use_selection=True, export_apply=True)

# ───────────── 미리 보기 ─────────────
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (1.0, 0.86, 0.7, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.55
scene.world = world
bpy.ops.mesh.primitive_plane_add(size=40, location=(0, 0, 0))
fl = bpy.context.active_object
fm = bpy.data.materials.new("Floor")
fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.55, 0.5, 0.46, 1)
fl.data.materials.append(fm)
bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 2.2, 5))
wall = bpy.context.active_object
wall.scale = (30, 1, 10)
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
for q in (lc, Vector((0, -0.95, AZ - 0.9))):
    pt = bpy.data.objects.new("Pt", bpy.data.lights.new("Pt", "POINT"))
    pt.data.energy = 60
    pt.data.color = (1.0, 0.8, 0.55)
    pt.location = q
    scene.collection.objects.link(pt)
emit = bpy.data.materials.new("Glow")
emit.use_nodes = True
eb = emit.node_tree.nodes["Principled BSDF"]
eb.inputs["Base Color"].default_value = (1, 0.85, 0.6, 1)
eb.inputs["Emission Color"].default_value = (1, 0.8, 0.5, 1)
eb.inputs["Emission Strength"].default_value = 4
scene.objects["Cozy_Lights"].data.materials[0] = emit
glass = bpy.data.materials.new("GlassPrev")
glass.use_nodes = True
gb = glass.node_tree.nodes["Principled BSDF"]
gb.inputs["Base Color"].default_value = (0.85, 0.95, 0.95, 1)
gb.inputs["Alpha"].default_value = 0.35
glass.surface_render_method = "BLENDED"
scene.objects["Cozy_Jar"].data.materials[0] = glass
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.lens = 40
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 1500, 1100
scene.view_settings.view_transform = "Standard"


def shoot(loc, tgt, name):
    cam.location = loc
    cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)


shoot((5.5, -11.5, 6.5), (0, 0, 3.4), "cozy_preview.png")
# 누름 손잡이 내림 + 돌림판 조금 돌린 모습
press = scene.objects["Cozy_Press"]
press.matrix_world = Matrix.Translation(hinge) @ rot(x=12) @ Matrix.Translation(-hinge) @ press.matrix_world
plate = scene.objects["Cozy_Plate"]
plate.matrix_world = Matrix.Translation(pc) @ rot(z=30) @ Matrix.Translation(-pc) @ plate.matrix_world
shoot((-6.5, -8.5, 7.5), (0.3, -0.2, 3.6), "cozy_preview2.png")
print("[cozy] done")
