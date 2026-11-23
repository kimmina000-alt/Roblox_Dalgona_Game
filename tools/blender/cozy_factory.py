# 아늑한 가게 그림체의 달고나 공장 기계 (사용자 요청 2026-11-23: "공장 기계 만들어 봐")
#   cozy_machine.py(가게 기계)와 같은 그림체·도구: 따뜻한 나무, 크림, 주황·크림 줄무늬, 구리·놋쇠,
#   모든 상자 모서리를 3단으로 둥글게 깎음, 평평한 면은 평평하게(set_sharp_from_angle), 팔레트 텍스처 한 장. 글자·상표 없음.
#
# 생산 라인 (왼쪽 → 오른쪽, 앞 = Blender -Y):
#   ① 설탕 통 탑(나무 다리 + 유리 통 + 놋쇠 관) → ② 구리 솥(크림 받침, 계기) → ③ 컨베이어(크림 틀, 나무 옆판, 롤러)
#   ④ 반죽 노즐대(노즐 3개, 전구) → ⑤ 찍는 프레스(줄무늬 옆판, 별 도장 누름 머리) → ⑥ 둥근 식힘 덮개(둥근 창)
#   ⑦ 미끄럼판 + 나무 상자(다 된 달고나) / ⑧ 앞 조작대(계기 3개, 도안 버튼 6개, 시작·정지, 레버)
#
# 부품(MeshPart): Fac_Body_<sugar|boil|belt|press|inspect|pack>(공정별 몸, 2026-11-23 나눔), Fac_Nozzle, Fac_Drop, Fac_Stirrer, Fac_Lever,
#   Fac_Lamp_<공정>(공정 불빛), Fac_Hanger_<공정>(빈 작업복 걸이), 알바 소품(SugarSack·Paddle·Magnifier·BoxFlat·BoxFolded),
#   Fac_FeedPipe, Fac_Gauge, Fac_HeatBand, Fac_Curtain_1~4, Fac_RejectBin, Fac_CrateLid, 위치 점 Fac_Pt_*(Attachment로 바꿈), Fac_Hopper(유리), Fac_Sugar, Fac_Kettle(구리), Fac_Belt, Fac_Press(오르내림),
#   Fac_Lights(Neon), Fac_BeltDalgona(벨트 위), Fac_Chute(나오는 곳), Fac_Output(상자 속), Fac_Fan(환풍기),
#   Fac_Console(조작대), Fac_StartButton, Fac_StopButton, Fac_Stand_<공정>(알바생 자리 표시, 투명). 게임(FactoryDisplay ANIM)이 이름으로 움직임을 붙임
#
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/cozy_factory.py -- <출력 폴더(절대 경로)>
# 결과: dalgona_cozy_factory.glb, cozy_factory_preview.png, cozy_factory_preview2.png(프레스 내린 모습),
#       cozy_factory_parts.png(공정별 색으로 나눔 보기), cozy_factory_parts.txt
# 크기 = 게임 stud. 원점 = 바닥 (컨베이어 가운데 근처). 좌표 변환 Blender (x, y, z) → Roblox (-x, z, y).

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
    img = bpy.data.images.new("CozyFactoryPalette", size, size, alpha=False)
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


PROC = ("sugar", "boil", "press", "inspect", "pack")  # D30 공정 5곳 (FactoryDisplay STATIONS key와 같음)
P = {n: Part(n) for n in ("Fac_Body_sugar", "Fac_Body_boil", "Fac_Body_belt", "Fac_Body_press", "Fac_Body_inspect", "Fac_Body_pack",
                         "Fac_Nozzle", "Fac_Drop", "Fac_Stirrer", "Fac_Lever", "Fac_Hopper", "Fac_Sugar", "Fac_Kettle", "Fac_Belt", "Fac_Press", "Fac_Fan",
                         "Fac_Lights", "Fac_BeltDalgona", "Fac_Chute", "Fac_Output", "Fac_Console", "Fac_StartButton", "Fac_StopButton",
                         "Fac_FeedPipe", "Fac_SugarSack", "Fac_Gauge", "Fac_HeatBand", "Fac_Paddle",
                         "Fac_Curtain_1", "Fac_Curtain_2", "Fac_Curtain_3", "Fac_Curtain_4", "Fac_Magnifier", "Fac_RejectBin",
                         "Fac_CrateLid", "Fac_BoxFlat", "Fac_BoxFolded",
                         "Fac_Pt_Steam", "Fac_Pt_BeltStart", "Fac_Pt_BeltEnd",
                         *("Fac_Stand_" + k for k in PROC), *("Fac_Lamp_" + k for k in PROC), *("Fac_Hanger_" + k for k in PROC))}


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


# ───────────── 공장 기계 ─────────────
BELT = (112, 92, 82)
GAUGE_FACE = (252, 246, 232)
RED_BTN = (230, 120, 104)
MINT_BTN = (150, 204, 176)
SKY_BTN = (150, 190, 226)
LEMON_BTN = (246, 214, 120)

body = P["Fac_Body_sugar"]  # 공정마다 아래에서 바꿈 (post()도 지금 body에 붙임)
BZ = 2.4  # 컨베이어 윗면 높이
BX0, BX1 = -2.4, 5.6  # 컨베이어 왼쪽·오른쪽 끝
BWID = 1.9


def post(c, h, w=0.3):
    box(body, (c[0], c[1], h / 2), (w, w, h), WOOD_D, bev=0.07)


# ① 설탕 통 탑 (왼쪽 끝): 나무 다리 4개 + 띠 + 유리 통 + 나무 뚜껑 + 놋쇠 관
hx = -6.1
for sx in (-1, 1):
    for sy in (-1, 1):
        post((hx + sx * 0.75, sy * 0.75), 3.6)
for z in (1.0, 3.45):
    box(body, (hx, -0.75, z), (1.8, 0.16, 0.16), WOOD, bev=0.05)
    box(body, (hx, 0.75, z), (1.8, 0.16, 0.16), WOOD, bev=0.05)
    box(body, (hx - 0.75, 0, z), (0.16, 1.8, 0.16), WOOD, bev=0.05)
    box(body, (hx + 0.75, 0, z), (0.16, 1.8, 0.16), WOOD, bev=0.05)
hc = Vector((hx, 0, 3.2))
lathe(P["Fac_Hopper"], [(0.12, 0), (0.3, 0.2), (1.0, 1.0), (1.05, 1.1), (1.05, 2.6), (0.98, 2.72), (0, 2.72)], GLASS, seg=20, c=hc)
lathe(P["Fac_Sugar"], [(0.1, 0.05), (0.28, 0.24), (0.96, 1.02), (0.98, 1.9), (0.6, 2.05), (0, 2.1)], SUGAR, seg=18, c=hc)
lathe(body, [(0, 2.68), (1.12, 2.68), (1.16, 2.78), (1.1, 2.9), (0.4, 2.98), (0, 3.0)], WOOD_D, seg=20, c=hc)
ball(body, hc + Vector((0, 0, 3.08)), 0.12, BRASS, seg=(10, 6))
cyl(body, hc + Vector((0, 0, 0.05)), hc + Vector((0, 0, -0.35)), 0.14, 0.14, BRASS, seg=10)
for a, b in (((hx, 0, 2.85), (hx + 1.4, 0, 2.85)), ((hx + 1.4, 0, 2.85), (-4.1, 0, 3.55))):
    cyl(P["Fac_FeedPipe"], a, b, 0.1, 0.1, BRASS, seg=10)  # Anim feed: 공급관이 살짝 흔들림
ball(P["Fac_FeedPipe"], (hx + 1.4, 0, 2.85), 0.13, BRASS, seg=(10, 6))
# 설탕 포대 (Fac_SugarSack, 알바 소품: 들어서 탑에 붓기). 탑 옆 바닥에 세워 둠
sk = P["Fac_SugarSack"]
lathe(sk, [(0, 0), (0.36, 0), (0.42, 0.12), (0.44, 0.5), (0.38, 0.78), (0.2, 0.86), (0.12, 0.95), (0, 0.97)], (238, 226, 200), seg=12,
      c=(hx + 1.15, -1.0, 0), m=Matrix.Diagonal((1.0, 0.7, 1.0, 1)))
lathe(sk, [(0.205, 0.83), (0.225, 0.86), (0.205, 0.89)], ORANGE, seg=12, c=(hx + 1.15, -1.0, 0), m=Matrix.Diagonal((1.0, 0.7, 1.0, 1)))

# ② 구리 솥: 크림 받침(나무 테) + 큰 구리 솥 + 놋쇠 띠 + 둥근 계기 + 김 나는 뚜껑
kx = -3.6
body = P["Fac_Body_boil"]
box(body, (kx, 0, 0.6), (2.5, 2.5, 1.2), CREAM_D, bev=0.18)
box(body, (kx, 0, 1.24), (2.7, 2.7, 0.14), WOOD_D, bev=0.05)
for sx in (-1, 1):
    box(body, (kx + sx * 0.7, -1.27, 0.6), (0.5, 0.06, 0.6), WOOD, bev=0.04)  # 불 보는 작은 문
kt = P["Fac_Kettle"]
kc = Vector((kx, 0, 1.3))
lathe(kt, [(0, 0), (0.9, 0), (1.12, 0.2), (1.2, 0.6), (1.2, 1.55), (1.26, 1.62), (1.18, 1.66), (1.1, 1.6), (0, 1.6)], COPPER, seg=24, c=kc)
lathe(kt, [(1.16, 1.62), (0.8, 1.98), (0.3, 2.12), (0, 2.14)], COPPER_D, seg=24, c=kc)
# 젓개 (Fac_Stirrer, Anim stir): 뚜껑 위 놋쇠 축 + 양쪽 나무 손잡이. 좌우 대칭이라 MeshPart 가운데 = 돌림 축 (Roblox Y축으로 돌림)
st = P["Fac_Stirrer"]
cyl(st, kc + Vector((0, 0, 2.05)), kc + Vector((0, 0, 2.55)), 0.07, 0.07, BRASS, seg=10)
cyl(st, kc + Vector((-0.55, 0, 2.5)), kc + Vector((0.55, 0, 2.5)), 0.05, 0.05, BRASS, seg=8)
for sx in (-1, 1):
    cyl(st, kc + Vector((sx * 0.55, 0, 2.5)), kc + Vector((sx * 0.55, 0, 2.78)), 0.08, 0.07, WOOD_D, seg=10)
    ball(st, kc + Vector((sx * 0.55, 0, 2.8)), 0.09, WOOD_D, seg=(10, 6))
ball(st, kc + Vector((0, 0, 2.58)), 0.11, BRASS, seg=(10, 6))
ring_z = (0.55, 1.25)
for z in ring_z:  # 가열 띠 (Fac_HeatBand, Anim heat: 돌 때 빨갛게)
    lathe(P["Fac_HeatBand"], [(1.21, z - 0.06), (1.25, z - 0.03), (1.25, z + 0.03), (1.21, z + 0.06)], BRASS, seg=24, c=kc)
gc = kc + Vector((0, -1.24, 0.9))
cyl(body, gc + Vector((0, 0.05, 0)), gc + Vector((0, -0.08, 0)), 0.32, 0.32, BRASS, seg=16)
cyl(body, gc + Vector((0, -0.07, 0)), gc + Vector((0, -0.1, 0)), 0.27, 0.27, GAUGE_FACE, seg=16)
# 계기 바늘 (Fac_Gauge, Anim gauge): 가운데 축 양쪽으로 뻗어(꼬리 포함) MeshPart 가운데 = 축. 계기 면 쪽(Roblox Z축)으로 돌림
gn = P["Fac_Gauge"]
box(gn, gc + Vector((0, -0.11, 0)), (0.04, 0.02, 0.4), RED_BTN, bev=0.008, seg=1, m=rot(y=-35))
cyl(gn, gc + Vector((0, -0.1, 0)), gc + Vector((0, -0.13, 0)), 0.04, 0.04, BRASS, seg=8)
# 김 나는 구멍 + 김 위치 점 (Fac_Pt_Steam: 코드가 Attachment로 바꾸고 부품은 지움)
cyl(body, kc + Vector((0.55, 0.45, 1.9)), kc + Vector((0.55, 0.45, 2.12)), 0.08, 0.07, BRASS, seg=8)
box(P["Fac_Pt_Steam"], kc + Vector((0.55, 0.45, 2.2)), (0.1, 0.1, 0.1), MINT_BTN, bev=0)
# 큰 주걱 (Fac_Paddle, 알바 소품: 솥 젓기). 솥 받침에 기대 둠
pd = P["Fac_Paddle"]
pq = Matrix.Translation(Vector((kx - 1.45, -0.9, 0))) @ rot(x=-12, y=8)
cyl(pd, pq @ Vector((0, 0, 0.55)), pq @ Vector((0, 0, 2.6)), 0.05, 0.05, WOOD_L, seg=8)
box(pd, pq @ Vector((0, 0, 0.32)), (0.32, 0.06, 0.6), WOOD_L, bev=0.025, seg=2, m=rot(x=-12, y=8))
for a, b in (((kx + 1.1, 0, 2.2), (-1.6, 0, 2.2)), ((-1.6, 0, 2.2), (-1.6, 0, 4.3)), ((-1.6, 0, 4.3), (-1.2, 0, 4.3))):
    cyl(body, a, b, 0.11, 0.11, BRASS, seg=10)
for q in ((-1.6, 0, 2.2), (-1.6, 0, 4.3)):
    ball(body, q, 0.14, BRASS, seg=(10, 6))

# ③ 컨베이어: 크림 틀 + 나무 옆판 + 벨트 + 다리 + 끝 롤러 (여러 공정이 같이 쓰는 몸 → Fac_Body_belt)
body = P["Fac_Body_belt"]
L = BX1 - BX0
cx = (BX0 + BX1) / 2
box(body, (cx, 0, BZ - 0.25), (L, BWID, 0.4), CREAM, bev=0.12)
for sy in (-1, 1):
    box(body, (cx, sy * (BWID / 2 + 0.06), BZ - 0.2), (L + 0.1, 0.12, 0.55), WOOD, bev=0.05)
box(P["Fac_Belt"], (cx, 0, BZ - 0.02), (L - 0.3, BWID - 0.25, 0.08), BELT, bev=0.03, seg=2)
for x in (BX0 + 0.5, cx, BX1 - 0.5):
    for sy in (-1, 1):
        post((x, sy * (BWID / 2 - 0.2)), BZ - 0.45, w=0.28)
for x in (BX0 + 0.15, BX1 - 0.15):
    cyl(body, (x, -BWID / 2 + 0.05, BZ - 0.15), (x, BWID / 2 - 0.05, BZ - 0.15), 0.2, 0.2, BRASS, seg=14)

# 벨트 위 길 시작·끝 점 (코드가 Attachment로 바꾸고 달고나 6~8개를 그 사이로 옮김, 부품은 지움)
box(P["Fac_Pt_BeltStart"], (-1.2, 0, BZ + 0.05), (0.1, 0.1, 0.1), MINT_BTN, bev=0)
box(P["Fac_Pt_BeltEnd"], (BX1 - 0.15, 0, BZ + 0.05), (0.1, 0.1, 0.1), MINT_BTN, bev=0)

# ④ 반죽 노즐대: 나무 문 모양 틀 + 크림 판 + 놋쇠 노즐 3개 + 꼭대기 전구 2개
nx = -1.2
body = P["Fac_Body_press"]  # ③ 붓기·찍기 = 노즐대 + 프레스
for sy in (-1, 1):
    box(body, (nx, sy * 1.15, (BZ + 2.3) / 2), (0.32, 0.32, BZ + 2.3), WOOD_D, bev=0.08)
box(body, (nx, 0, BZ + 2.1), (0.7, 2.7, 0.6), CREAM, bev=0.16)
box(body, (nx, 0, BZ + 2.45), (0.8, 2.8, 0.14), WOOD_D, bev=0.05)
for sy in (-0.55, 0, 0.55):
    cyl(P["Fac_Nozzle"], (nx, sy, BZ + 1.8), (nx, sy, BZ + 0.75), 0.13, 0.05, BRASS, seg=10)  # Anim nozzle: 붓는 순간 살짝 내려옴
    ball(P["Fac_Drop"], (nx, sy, BZ + 0.55), (0.09, 0.09, 0.13), DALGONA, seg=(10, 6))  # Anim drip: 노즐 끝 → 벨트로 떨어짐
for sy in (-1, 1):
    cyl(body, (nx, sy * 1.15, BZ + 2.52), (nx, sy * 1.15, BZ + 2.7), 0.06, 0.06, BRASS, seg=8)
    ball(P["Fac_Lights"], (nx, sy * 1.15, BZ + 2.85), 0.16, BULB, seg=(12, 8))

# ⑤ 찍는 프레스: 나무 기둥 + 주황·크림 줄무늬 옆판 + 지붕 + 놋쇠 실린더 + 움직이는 누름 머리
px = 2.0
for sy in (-1, 1):
    box(body, (px, sy * 1.2, (BZ + 2.6) / 2), (1.2, 0.3, BZ + 2.6), WOOD_D, bev=0.1)
    for k in range(4):  # 줄무늬 옆판
        z = BZ + 0.45 + k * 0.5
        box(body, (px, sy * 1.37, z), (1.0, 0.06, 0.5), ORANGE if k % 2 == 0 else AWN_CREAM, bev=0.02, seg=2)
box(body, (px, 0, BZ + 2.45), (1.5, 2.9, 0.55), CREAM, bev=0.2)
box(body, (px, 0, BZ + 2.8), (1.7, 3.1, 0.16), WOOD_D, bev=0.06)
cyl(body, (px, 0, BZ + 2.2), (px, 0, BZ + 1.6), 0.24, 0.24, BRASS, seg=14)
pr = P["Fac_Press"]
cyl(pr, (px, 0, BZ + 1.7), (px, 0, BZ + 0.95), 0.12, 0.12, STEEL, seg=12)
box(pr, (px, 0, BZ + 0.8), (1.0, 1.5, 0.3), BRASS, bev=0.1)
for sy in (-0.4, 0.4):  # 아래에 별 도장
    star_relief(pr, (px, sy, BZ + 0.65), 0.22, 0.04, COPPER_D, m=rot(x=180))

# ⑥ 식히는 덮개: 둥근 크림 덮개 + 둥근 창 2개(놋쇠 테) + 위 환풍구
cx6 = 4.25
body = P["Fac_Body_inspect"]
box(body, (cx6, 0, BZ + 0.75), (2.0, 2.2, 1.4), CREAM, bev=0.5, seg=4)
box(body, (cx6, 0, BZ + 0.06), (2.1, 2.3, 0.12), WOOD_D, bev=0.04)
for dx in (-0.45, 0.45):
    q = Vector((cx6 + dx, -1.1, BZ + 0.85))
    cyl(body, q + Vector((0, 0.04, 0)), q + Vector((0, -0.06, 0)), 0.3, 0.3, BRASS, seg=16)
    cyl(P["Fac_Lights"], q + Vector((0, -0.04, 0)), q + Vector((0, -0.08, 0)), 0.23, 0.23, (255, 210, 170), seg=16)
lathe(body, [(0.46, 0), (0.5, 0.05), (0.5, 0.16), (0.44, 0.18), (0.44, 0.05), (0.0, 0.05)], BRASS, seg=16, c=(cx6, 0.2, BZ + 1.4))  # 환풍구 테
fan = P["Fac_Fan"]
fc = Vector((cx6, 0.2, BZ + 1.55))
cyl(fan, fc + Vector((0, 0, -0.03)), fc + Vector((0, 0, 0.03)), 0.09, 0.09, WOOD_D, seg=10)
for k in range(4):  # 날개 4장 (납작해서 세로축으로 돎)
    box(fan, fc + rot(z=k * 90).to_3x3() @ Vector((0.22, 0, 0)), (0.3, 0.12, 0.03), CREAM_D, bev=0.012, seg=2, m=rot(z=k * 90) @ rot(x=18))

# 비닐 커튼: 덮개 들어가는·나오는 입구에 어두운 구멍 + 줄 4조각 (Fac_Curtain_<n>, Anim curtain: 윗변을 경첩으로 흔들림)
CURTAIN = (215, 232, 236)
n = 0
for sx in (-1, 1):
    xx = cx6 + sx * 1.02
    box(body, (xx, 0, BZ + 0.5), (0.03, 1.7, 0.85), (70, 58, 52), bev=0.01, seg=1)
    for half in (-1, 1):
        n += 1
        cp = P[f"Fac_Curtain_{n}"]
        for k in range(3):
            y = half * (0.15 + k * 0.27)
            box(cp, (xx + sx * 0.04, y, BZ + 0.52), (0.02, 0.24, 0.8), CURTAIN, bev=0.008, seg=1)
# 돋보기 (Fac_Magnifier, 알바 소품): 덮개 앞 턱에 놓음
mg = P["Fac_Magnifier"]
mq = Vector((cx6 - 0.35, -1.25, BZ + 0.16))
lathe(mg, [(0.17, -0.025), (0.21, -0.02), (0.21, 0.02), (0.17, 0.025), (0.17, -0.025)], BRASS, seg=14, c=mq)
cyl(mg, mq + Vector((0, 0, -0.005)), mq + Vector((0, 0, 0.005)), 0.17, 0.17, (200, 228, 236), seg=14)
cyl(mg, mq + Vector((0.2, -0.02, 0)), mq + Vector((0.55, -0.12, 0)), 0.04, 0.035, WOOD_D, seg=8)
# 불량 넣는 작은 통 (Fac_RejectBin): 컨베이어 앞, 검사 자리 옆
rb = P["Fac_RejectBin"]
lathe(rb, [(0, 0), (0.28, 0), (0.33, 0.05), (0.36, 0.5), (0.39, 0.53), (0.33, 0.53), (0.3, 0.08), (0, 0.08)], (176, 196, 210), seg=14,
      c=(cx6 - 0.75, -1.45, 0))

# ⑦ 나오는 곳: 나무 미끄럼판 + 나무 상자 + 다 된 달고나
ch = P["Fac_Chute"]
box(ch, (BX1 + 0.55, 0, BZ - 0.55), (1.3, 1.2, 0.1), WOOD_L, bev=0.03, m=rot(y=35))
for sy in (-1, 1):
    box(ch, (BX1 + 0.55, sy * 0.62, BZ - 0.45), (1.3, 0.06, 0.25), WOOD_D, bev=0.02, seg=2, m=rot(y=35))
ox = BX1 + 1.45
body = P["Fac_Body_pack"]
box(body, (ox, 0, 0.55), (1.6, 1.6, 1.1), WOOD, bev=0.1)
box(body, (ox, 0, 1.08), (1.4, 1.4, 0.06), WOOD_D, bev=0.02)
for sy in (-1, 1):
    box(body, (ox, sy * 0.81, 0.55), (1.2, 0.04, 0.2), WOOD_D, bev=0.02, seg=2)  # 상자 손잡이 홈
out = P["Fac_Output"]
for k, (dx, dy, dz, ry) in enumerate(((-0.35, -0.3, 1.12, 0), (0.3, -0.25, 1.12, 20), (-0.25, 0.35, 1.12, -15),
                                      (0.35, 0.3, 1.12, 40), (0.0, 0.0, 1.2, 12), (0.05, -0.05, 1.28, -25))):
    dalgona(out, (ox + dx, dy, dz), r=0.34, h=0.06, m=rot(z=ry))

# 상자 뚜껑 (Fac_CrateLid, Anim lid): 열린 채 뒤로 세워 둠. 경첩 = 상자 윗면 뒤 모서리 (parts.txt LID_HINGE)
LID_HINGE = Vector((ox, 0.8, 1.1))
box(P["Fac_CrateLid"], LID_HINGE + Vector((0, 0.05, 0.75)), (1.6, 0.1, 1.5), WOOD, bev=0.04, m=rot(x=-8))
box(P["Fac_CrateLid"], LID_HINGE + Vector((0, 0.12, 0.75)), (1.2, 0.04, 0.2), WOOD_D, bev=0.015, seg=1, m=rot(x=-8))
# 포장 상자 두 모양 (알바 소품: 펼친 것 → 접은 것). 상자 오른쪽 작은 받침 위
KRAFT = (214, 172, 120)
box(body, (ox + 1.25, -0.2, 0.35), (0.8, 1.3, 0.7), WOOD_D, bev=0.06)
bf = P["Fac_BoxFlat"]
for k, (w, d) in enumerate(((0.7, 0.24), (0.24, 0.7))):  # 십자 모양 펼친 판
    box(bf, (ox + 1.25, 0.15, 0.72 + k * 0.004), (w, d, 0.015), KRAFT, bev=0.004, seg=1)
bo = P["Fac_BoxFolded"]
box(bo, (ox + 1.25, -0.5, 0.86), (0.36, 0.36, 0.3), KRAFT, bev=0.03, seg=2)
star_relief(bo, (ox + 1.25, -0.5, 1.01), 0.1, 0.01, ORANGE)

# 벨트 위 달고나: 노즐 아래 반죽(별 없음) → 프레스 지나서 별
bd = P["Fac_BeltDalgona"]
for x in (-0.6, 0.4, 1.2):
    dalgona(bd, (x, 0, BZ + 0.03), r=0.38, h=0.05, star=False)
for x in (3.0, 5.2):
    dalgona(bd, (x, 0, BZ + 0.03), r=0.38, h=0.05)

# ⑧ 앞 조작대 (기울어진 판이 앞쪽 = 플레이어를 봄, 2026-11-23 사용자: 등을 보이는 것 같아 돌림): 나무 책상 + 기울어진 크림 판(계기 3개, 도안 버튼 6개, 큰 시작·정지 버튼, 레버)
dx0, dy0 = 0.6, -2.35
con = P["Fac_Console"]
box(con, (dx0, dy0, 0.55), (2.4, 1.0, 1.1), WOOD, bev=0.1)
box(con, (dx0, dy0 - 0.52, 0.55), (2.0, 0.06, 0.75), CREAM, bev=0.04)
panel = Matrix.Translation(Vector((dx0, dy0, 1.32))) @ rot(x=35)
box(con, (dx0, dy0, 1.3), (2.6, 1.1, 0.24), WOOD_D, bev=0.08, m=rot(x=35))
box(con, panel @ Vector((0, 0, 0.13)), (2.35, 0.9, 0.06), CREAM, bev=0.03, m=rot(x=35))
for k, x in enumerate((-0.75, 0.0, 0.75)):  # 계기
    q = panel @ Vector((x, 0.18, 0.17))
    cyl(con, q, q + rot(x=35).to_3x3() @ Vector((0, 0, 0.05)), 0.2, 0.2, BRASS, seg=14)
    cyl(con, q + rot(x=35).to_3x3() @ Vector((0, 0, 0.04)), q + rot(x=35).to_3x3() @ Vector((0, 0, 0.07)), 0.16, 0.16, GAUGE_FACE, seg=14)
for k, col in enumerate((ORANGE, MINT_BTN, SKY_BTN, LEMON_BTN, (210, 170, 220), (250, 190, 200))):  # 도안 버튼
    q = panel @ Vector((-0.9 + k * 0.36, -0.22, 0.17))
    cyl(con, q, q + rot(x=35).to_3x3() @ Vector((0, 0, 0.06)), 0.1, 0.09, col, seg=10)
q = Vector((dx0 + 1.45, dy0 - 0.1, 1.15))
box(con, q, (0.5, 0.8, 0.3), WOOD_D, bev=0.06)
ball(P["Fac_StartButton"], q + Vector((0, -0.18, 0.2)), (0.14, 0.14, 0.08), MINT_BTN, seg=(12, 6))  # 시작 (돌 때 켜짐)
ball(P["Fac_StopButton"], q + Vector((0, 0.18, 0.2)), (0.14, 0.14, 0.08), RED_BTN, seg=(12, 6))  # 정지 (멈추면 깜빡)
# 레버 (Fac_Lever, Anim lever): 시작할 때 앞으로 당김. 경첩 = 아래 끝 (Roblox 좌표는 parts.txt LEVER_HINGE)
LEVER_HINGE = Vector((dx0 - 1.35, dy0, 1.0))
box(con, LEVER_HINGE + Vector((0, 0, -0.04)), (0.22, 0.3, 0.12), WOOD_D, bev=0.04)
cyl(P["Fac_Lever"], LEVER_HINGE, LEVER_HINGE + Vector((0, -0.25, 0.55)), 0.05, 0.04, BRASS, seg=8)
ball(P["Fac_Lever"], LEVER_HINGE + Vector((0, -0.27, 0.6)), 0.1, RED_BTN, seg=(10, 6))

# ⑨ 공정 알바생이 설 자리 표시 (게임에서 안 보이게 함). 바닥에 놓인 얇은 원판, 라인 앞 통로.
#    FactoryDisplay가 이 부품 바닥 가운데에 미니미를 세우고, 부품 -LookVector(= 기계 안쪽, Roblox +Z) 쪽을 보게 함.
STANDS = {"sugar": (hx, -1.75), "boil": (kx, -1.95), "press": (px + 0.75, -1.65), "inspect": (cx6, -1.75), "pack": (ox, -1.5)}
for key, (x, y) in STANDS.items():
    cyl(P["Fac_Stand_" + key], (x, y, 0.0), (x, y, 0.02), 0.4, 0.4, MINT_BTN, seg=8)

# ⑩ 공정 불빛 Fac_Lamp_<공정> (Anim stationLamp): 공정마다 앞쪽에 작은 등. 알바생을 고용하면 켜짐(Neon), 안 하면 어둡게.
#    놋쇠 받침은 그 공정 몸에, 유리 알만 이 부품.
LAMPS = {"sugar": (hx, -0.95, 3.75, "Fac_Body_sugar"), "boil": (kx - 0.95, -1.38, 1.45, "Fac_Body_boil"),
         "press": (px, -1.62, BZ + 2.95, "Fac_Body_press"), "inspect": (cx6 + 0.8, -1.2, BZ + 1.45, "Fac_Body_inspect"),
         "pack": (ox + 0.6, -0.85, 1.25, "Fac_Body_pack")}
for key, (x, y, z, owner) in LAMPS.items():
    cyl(P[owner], (x, y, z - 0.12), (x, y, z - 0.02), 0.13, 0.11, BRASS, seg=10)
    ball(P["Fac_Lamp_" + key], (x, y, z + 0.08), 0.12, BULB, seg=(10, 6))

# ⑪ 빈 작업복 걸이 Fac_Hanger_<공정>: 알바생이 없을 때 보이고, 고용하면 코드가 숨김. 옷 색 = 공정 옷
CLOTH = {"sugar": (250, 250, 246), "boil": (220, 96, 84), "press": (246, 206, 90), "inspect": (160, 206, 236), "pack": (110, 150, 214)}
for key, (x, y) in STANDS.items():
    hg = P["Fac_Hanger_" + key]
    q = Vector((x + 0.85, y - 0.35, 0))
    cyl(hg, q, q + Vector((0, 0, 0.06)), 0.28, 0.26, WOOD_D, seg=12)
    cyl(hg, q, q + Vector((0, 0, 2.9)), 0.05, 0.05, WOOD_D, seg=8)
    ball(hg, q + Vector((0, 0, 2.95)), 0.08, BRASS, seg=(8, 6))
    cyl(hg, q + Vector((-0.3, 0, 2.55)), q + Vector((0.3, 0, 2.55)), 0.025, 0.025, BRASS, seg=6)  # 옷걸이
    box(hg, q + Vector((0, -0.07, 2.05)), (0.62, 0.06, 0.9), CLOTH[key], bev=0.04, seg=2)  # 앞치마·작업복
    box(hg, q + Vector((0, -0.1, 1.85)), (0.3, 0.03, 0.2), tuple(int(c * 0.85) for c in CLOTH[key]), bev=0.02, seg=1)  # 주머니

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
    "Fac_Body_sugar": "① 설탕 넣기 몸: 설탕 탑 나무 다리·띠·뚜껑·놋쇠 관 (Wood)",
    "Fac_Body_boil": "② 끓이기 몸: 솥 크림 받침·불 문·계기·놋쇠 관 (SmoothPlastic)",
    "Fac_Body_belt": "컨베이어 틀·옆판·다리·롤러 (공정 공용, SmoothPlastic)",
    "Fac_Body_press": "③ 붓기·찍기 몸: 노즐대 틀·전구 받침·프레스 기둥·줄무늬 옆판·지붕·실린더 (Wood)",
    "Fac_Body_inspect": "④ 식히기·검사 몸: 둥근 식힘 덮개·창 테·환풍구 테 (SmoothPlastic)",
    "Fac_Body_pack": "⑤ 포장 몸: 나무 상자 (Wood)",
    "Fac_Nozzle": "노즐 3개 (Anim nozzle: 붓는 순간 Roblox Y로 0.1 내려왔다 올라감)",
    "Fac_Drop": "노즐 끝 반죽 방울 3개 (Anim drip: Roblox Y로 0.4 떨어지며 작아지고 사라짐, 다시 노즐 끝에서 생김)",
    "Fac_Stirrer": "솥 뚜껑 위 젓개 (Anim stir: 가운데 = 돌림 축, Roblox Y축으로 천천히 돎)",
    "Fac_Lever": "조작대 레버 (Anim lever: 시작할 때 경첩 LEVER_HINGE 기준 Roblox X축으로 약 40° 앞으로 당김)",
    "Fac_FeedPipe": "① 설탕 공급관 (Anim feed: 돌 때 살짝 흔들림)",
    "Fac_SugarSack": "① 알바 소품 설탕 포대 (들어서 탑에 붓기, 바닥에 세워 둠)",
    "Fac_Gauge": "② 계기 바늘 (Anim gauge: 가운데 = 축, 계기 면에 수직인 Roblox Z축으로 돌림, 끓을수록 오름)",
    "Fac_HeatBand": "② 솥 가열 띠 2줄 (Anim heat: 돌 때 빨갛게, 멈추면 놋쇠색)",
    "Fac_Paddle": "② 알바 소품 큰 주걱 (솥 받침에 기대 둠)",
    **{f"Fac_Curtain_{i}": "④ 식힘 덮개 입구 비닐 커튼 3줄 (Anim curtain: 윗변 경첩으로 흔들림, 1·2 = 들어가는 쪽, 3·4 = 나오는 쪽)" for i in range(1, 5)},
    "Fac_Magnifier": "④ 알바 소품 돋보기 (덮개 앞 턱에 놓음)",
    "Fac_RejectBin": "④ 불량 넣는 작은 통 (검사 알바가 집어낸 달고나를 여기로)",
    "Fac_CrateLid": "⑤ 상자 뚜껑, 열린 모습 (Anim lid: 경첩 LID_HINGE 기준 Roblox X축으로 닫힘·열림)",
    "Fac_BoxFlat": "⑤ 알바 소품 펼친 포장 상자",
    "Fac_BoxFolded": "⑤ 알바 소품 접은 포장 상자 (포장 알바가 있을 때만)",
    "Fac_Pt_Steam": "위치 점: 솥 김 (코드가 Attachment로 바꾸고 부품은 지움)",
    "Fac_Pt_BeltStart": "위치 점: 벨트 위 달고나 길 시작 = 노즐 아래 (Attachment로 바꿈)",
    "Fac_Pt_BeltEnd": "위치 점: 벨트 위 달고나 길 끝 = 미끄럼판 앞 (Attachment로 바꿈)",
    **{"Fac_Hanger_" + k: f"빈 작업복 걸이 {n} (알바 없을 때 보임, 고용하면 숨김)" for k, n in
       zip(PROC, ("① 설탕 넣기", "② 끓이기", "③ 붓기·찍기", "④ 식히기·검사", "⑤ 포장"))},
    **{"Fac_Lamp_" + k: f"공정 불빛 {n} (Anim stationLamp: 그 공정 알바생 고용 = Neon, 아니면 어둡게)" for k, n in
       zip(PROC, ("① 설탕 넣기", "② 끓이기", "③ 붓기·찍기", "④ 식히기·검사", "⑤ 포장"))},
    "Fac_Hopper": "유리 설탕 통 (Glass, Transparency 0.5)",
    "Fac_Sugar": "통 속 설탕 (Anim hopper)",
    "Fac_Kettle": "구리 솥 (Anim kettle, Metal)",
    "Fac_Belt": "컨베이어 벨트 (움직임은 위 달고나를 옮겨서 표현)",
    "Fac_Fan": "식힘 덮개 위 환풍기 날개 (Anim spin: 가장 얇은 축 = 세로축으로 돎)",
    "Fac_Press": "누름 머리 (Anim press, Roblox Y로 약 0.55 내리면 벨트 위 달고나에 닿음)",
    "Fac_Lights": "전구·식힘 덮개 창 (Anim lampRun: 돌 때 Neon)",
    "Fac_BeltDalgona": "벨트 위 달고나 (Anim belt: 부품 -X로 흐름)",
    "Fac_Chute": "나무 미끄럼판 (Anim outlet: 다 된 달고나가 나오는 곳)",
    "Fac_Output": "상자 속 다 된 달고나",
    "Fac_Console": "앞 조작대 (제어대 ProximityPrompt를 붙일 부품)",
    "Fac_StartButton": "시작 버튼 (Anim lampRun)",
    "Fac_StopButton": "정지 버튼 (Anim lampStop)",
    "Fac_Stand_sugar": "알바생 자리 표시: 설탕 넣기 (게임에서 투명)",
    "Fac_Stand_boil": "알바생 자리 표시: 끓이기 (게임에서 투명)",
    "Fac_Stand_press": "알바생 자리 표시: 붓기·찍기 (게임에서 투명)",
    "Fac_Stand_inspect": "알바생 자리 표시: 식히기·검사 (게임에서 투명)",
    "Fac_Stand_pack": "알바생 자리 표시: 포장 (게임에서 투명)",
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
rows.append(f"# 합계 삼각형 {total}. center = 기계 원점(바닥 가운데)에서 MeshPart 가운데까지 (Roblox 좌표). 원점 = 컨베이어 아래 바닥 가운데쯤.")
rows.append(f"# LID_HINGE (Roblox) = ({-LID_HINGE.x:.2f}, {LID_HINGE.z:.2f}, {LID_HINGE.y:.2f})")
rows.append(f"# LEVER_HINGE (Roblox) = ({-LEVER_HINGE.x:.2f}, {LEVER_HINGE.z:.2f}, {LEVER_HINGE.y:.2f})")
rows.append("# 예전 Fac_Body 하나 → Fac_Body_<공정> 6개로 나눔 (2026-11-23). 나머지 예전 이름은 그대로.")
rows.append(f"# 컨베이어 윗면 높이 {BZ}, 벨트 Roblox X {-BX1:.2f} ~ {-BX0:.2f} (달고나는 Roblox -X 쪽으로 흐름: 노즐 → 프레스 → 식힘 → 상자)")
with open(os.path.join(OUT, "cozy_factory_parts.txt"), "w", encoding="utf-8") as f:
    f.write("\n".join(rows) + "\n")
print("\n".join(rows))

for o in objs:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "dalgona_cozy_factory.glb"), export_format="GLB", use_selection=True, export_apply=True)

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
for q in ((nx, 0, BZ + 3.2), (cx6, -1.6, BZ + 1.0)):
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
scene.objects["Fac_Lights"].data.materials[0] = emit
for k in PROC:
    scene.objects["Fac_Lamp_" + k].data.materials[0] = emit
glass = bpy.data.materials.new("GlassPrev")
glass.use_nodes = True
gb = glass.node_tree.nodes["Principled BSDF"]
gb.inputs["Base Color"].default_value = (0.85, 0.95, 0.95, 1)
gb.inputs["Alpha"].default_value = 0.35
glass.surface_render_method = "BLENDED"
scene.objects["Fac_Hopper"].data.materials[0] = glass
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


for o in scene.objects:
    if o.name.startswith("Fac_Stand_") or o.name.startswith("Fac_Pt_"):
        o.hide_render = True  # 알바생 자리 표시는 게임에서도 투명
shoot((3.0, -19.0, 9.0), (0.3, 0, 2.6), "cozy_factory_preview.png")
press = scene.objects["Fac_Press"]
press.location.z -= 0.55
shoot((-9.5, -10.5, 7.0), (0.5, 0, 2.8), "cozy_factory_preview2.png")
press.location.z += 0.55

# 부품 나눔 보기: 공정마다 한 색, 움직이는 부품은 진한 색
GROUP = {"sugar": (0.95, 0.95, 0.95), "boil": (0.95, 0.55, 0.35), "press": (0.98, 0.82, 0.3), "inspect": (0.55, 0.78, 0.95),
         "pack": (0.45, 0.72, 0.5), "belt": (0.6, 0.55, 0.52)}
MOVING = {"Fac_Sugar": "sugar", "Fac_Hopper": "sugar", "Fac_Kettle": "boil", "Fac_Stirrer": "boil", "Fac_Nozzle": "press", "Fac_Drop": "press",
          "Fac_Press": "press", "Fac_Fan": "inspect", "Fac_Chute": "pack", "Fac_Output": "pack", "Fac_Belt": "belt", "Fac_BeltDalgona": "belt",
          "Fac_Lights": "press", "Fac_FeedPipe": "sugar", "Fac_SugarSack": "sugar", "Fac_Gauge": "boil", "Fac_HeatBand": "boil",
          "Fac_Paddle": "boil", "Fac_Magnifier": "inspect", "Fac_RejectBin": "inspect", "Fac_CrateLid": "pack", "Fac_BoxFlat": "pack",
          "Fac_BoxFolded": "pack", **{f"Fac_Curtain_{i}": "inspect" for i in range(1, 5)}, "Fac_Console": "belt", "Fac_StartButton": "belt", "Fac_StopButton": "belt", "Fac_Lever": "belt"}
mats = {}
for o in scene.objects:
    if not o.name.startswith("Fac_") or o.name.startswith("Fac_Stand_") or o.name.startswith("Fac_Pt_"):
        continue
    if o.name.startswith("Fac_Body_"):
        g, dark = o.name[9:], False
    elif o.name.startswith("Fac_Lamp_") or o.name.startswith("Fac_Hanger_"):
        g, dark = o.name.rsplit("_", 1)[1], True
    else:
        g, dark = MOVING[o.name], True
    key = (g, dark)
    if key not in mats:
        m = bpy.data.materials.new(f"G_{g}_{dark}")
        m.use_nodes = True
        col = GROUP[g] if not dark else tuple(c * 0.55 for c in GROUP[g])
        m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*col, 1)
        mats[key] = m
    o.data.materials[0] = mats[key]
shoot((3.0, -19.0, 9.0), (0.3, 0, 2.6), "cozy_factory_parts.png")
print("[cozy_factory] done")
