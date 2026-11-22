# 21번 레트로 골목 맵 배경 소품 12종 (제작 세션 요청 2026-11-23)
#   UtilityPole 전봇대, StreetLamp 갓 가로등(전봇대 팔), Bicycle 바구니 자전거, BriquetteStack 연탄 더미,
#   PotBasin 고무 대야 화분, PlasticCrate 빈 병 플라스틱 상자, Pyeongsang 나무 평상, AcUnit 벽걸이 실외기,
#   GasTank 가스통, TrashBin 둥근 철 쓰레기통, Mailbox 빨간 우편함, ShopShutterSign 빈 간판 판
# 그림체: 가게(벽돌 + 분홍·크림 차양)·파스텔 사탕 공장에 맞춘 낮은 채도의 따뜻한 파스텔, 둥근 모서리. 글자·상표 없음.
# 예산: 소품 하나 삼각형 600 이하 (전봇대·자전거 1,000 이하). 실행 끝에 표로 확인.
#
# 색 = 팔레트 텍스처 한 장 (손님 NPC customers.py와 같은 방식). 소품 하나 = MeshPart 하나.
#   glb의 재질 색(여러 재질)은 Roblox로 가져오면 MeshPart 하나에 색 하나만 남아서, 칸마다 색을 칠한 작은 텍스처를 모두 같이 쓴다.
#
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/alley.py -- <출력 폴더(절대 경로)>
# 결과: <출력>/dalgona_alley.glb (오브젝트 이름 = 소품 이름), alley_preview.png, alley_parts.txt
# 크기 = 게임 stud. 앞 = Blender -Y (Roblox -Z), 위 = Blender +Z (Roblox +Y).
# 원점(놓는 기준점) = 바닥 가운데. 예외: StreetLamp = 전봇대에 붙는 쪽 끝(팔이 -Y로 뻗음), AcUnit = 벽에 닿는 뒷면 가운데,
#   ShopShutterSign = 판 가운데. Roblox MeshPart는 경계 상자 가운데가 기준이라 alley_parts.txt에 "가운데 → 기준점" 거리를 적는다.
# 자전거는 옆모습이 앞(-Y)을 보도록 X 방향으로 길다 (앞바퀴 = -X).

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
rng = np.random.default_rng(23)

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
        arr[cy * cell:(cy + 1) * cell, cx * cell:(cx + 1) * cell] = np.array(rgb) / 255 + rng.normal(0, 0.006, (cell, cell, 1))
    img = bpy.data.images.new("AlleyPalette", size, size, alpha=False)
    rgba = np.ones((size, size, 4), dtype=np.float32)
    rgba[:, :, :3] = np.clip(arr, 0, 1) ** 2.2
    img.pixels.foreach_set(rgba.ravel())
    img.pack()
    return img


# 색 (따뜻한 파스텔, 낮은 채도)
CONCRETE = (214, 206, 194)
CONCRETE_D = (176, 168, 158)
ARM = (150, 146, 138)
PORCELAIN = (246, 242, 232)
TRANS = (176, 186, 178)
LAMP = (122, 150, 136)
BULB = (255, 236, 176)
MINT = (150, 204, 186)
TIRE = (78, 74, 76)
SEAT = (150, 104, 82)
WICKER = (214, 178, 124)
METAL = (196, 196, 190)
COAL = (78, 74, 76)
COAL_BURNT = (214, 204, 192)
HOLE = (36, 34, 36)
BASIN = (206, 104, 92)
SOIL = (120, 88, 66)
LEAF = (146, 192, 112)
LEAF_D = (112, 164, 96)
PEPPER = (222, 86, 74)
CRATE = (232, 204, 118)
CRATE_D = (204, 176, 96)
WOOD = (216, 178, 130)
WOOD_D = (180, 140, 98)
CREAM = (238, 232, 216)
GRILLE = (120, 118, 116)
GAS = (156, 176, 198)
GAS_D = (120, 140, 166)
BIN = (184, 188, 182)
BIN_D = (150, 154, 150)
POST_RED = (208, 86, 78)
SIGN = (240, 224, 192)
SIGN_RIM = (196, 132, 112)
DARK = (60, 56, 58)

I4 = Matrix.Identity(4)


def rot(x=0, y=0, z=0):
    return Matrix.Rotation(math.radians(z), 4, "Z") @ Matrix.Rotation(math.radians(y), 4, "Y") @ Matrix.Rotation(math.radians(x), 4, "X")


class Prop:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.col = self.bm.faces.layers.int.new("col")

    def paint(self, rgb):
        idx = C(rgb) + 1
        for f in self.bm.faces:
            if f[self.col] == 0:
                f[self.col] = idx


def V(v):
    return Vector(v)


def ball(p, c, r, rgb, seg=(8, 5), m=I4):
    r = (r, r, r) if isinstance(r, (int, float)) else r
    bmesh.ops.create_uvsphere(p.bm, u_segments=seg[0], v_segments=seg[1], radius=1.0,
                              matrix=Matrix.Translation(V(c)) @ m @ Matrix.Diagonal((*r, 1)))
    p.paint(rgb)


def cyl(p, a, b, r0, r1, rgb, seg=8):
    a, b = V(a), V(b)
    d = b - a
    R = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    bmesh.ops.create_cone(p.bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r0, radius2=r1, depth=d.length,
                          matrix=Matrix.Translation((a + b) / 2) @ R)
    p.paint(rgb)


def box(p, c, size, rgb, bev=0.0, seg=2, m=I4):
    res = bmesh.ops.create_cube(p.bm, size=1.0, matrix=Matrix.Translation(V(c)) @ m @ Matrix.Diagonal((*size, 1)))
    if bev > 0:
        vs = res["verts"]
        es = list({e for v in vs for e in v.link_edges})
        bmesh.ops.bevel(p.bm, geom=vs + es, offset=bev, offset_type="OFFSET", segments=seg, profile=0.5, affect="EDGES", clamp_overlap=True)
    p.paint(rgb)


def lathe(p, prof, rgb, seg=12, c=(0, 0, 0), cap_top=False, cap_bottom=False):
    """prof = [(r, z)...] 아래에서 위로. 닫힌 모양이면 처음·끝 반지름 0."""
    c = V(c)
    rings = []
    for (r, z) in prof:
        rings.append([p.bm.verts.new(c + Vector((math.cos(2 * math.pi * k / seg) * r, math.sin(2 * math.pi * k / seg) * r, z))) for k in range(seg)])
    faces = []
    for A, B in zip(rings, rings[1:]):
        for k in range(seg):
            k2 = (k + 1) % seg
            faces.append(p.bm.faces.new((A[k], A[k2], B[k2], B[k])))
    if cap_bottom:
        faces.append(p.bm.faces.new(list(reversed(rings[0]))))
    if cap_top:
        faces.append(p.bm.faces.new(rings[-1]))
    bmesh.ops.remove_doubles(p.bm, verts=[v for r in rings for v in r], dist=1e-5)
    faces = [f for f in faces if f.is_valid]
    bmesh.ops.recalc_face_normals(p.bm, faces=faces)
    p.paint(rgb)


def ring(p, c, R, r, rgb, useg=14, vseg=4, m=I4):
    """XY 면에 누운 고리 (m으로 세움)."""
    M = Matrix.Translation(V(c)) @ m
    rings = []
    for i in range(useg):
        u = 2 * math.pi * i / useg
        rings.append([p.bm.verts.new(M @ Vector(((R + r * math.cos(2 * math.pi * j / vseg)) * math.cos(u),
                                                  (R + r * math.cos(2 * math.pi * j / vseg)) * math.sin(u),
                                                  r * math.sin(2 * math.pi * j / vseg)))) for j in range(vseg)])
    faces = []
    for i in range(useg):
        A, B = rings[i], rings[(i + 1) % useg]
        for j in range(vseg):
            j2 = (j + 1) % vseg
            faces.append(p.bm.faces.new((A[j], B[j], B[j2], A[j2])))
    bmesh.ops.recalc_face_normals(p.bm, faces=faces)
    p.paint(rgb)


# ───────────── 소품 ─────────────
def utility_pole():
    p = Prop("UtilityPole")
    cyl(p, (0, 0, 0), (0, 0, 22), 0.55, 0.38, CONCRETE, seg=10)
    cyl(p, (0, 0, 0), (0, 0, 1.2), 0.6, 0.58, CONCRETE_D, seg=10)  # 아래 때 묻은 띠
    for z, w in ((20.2, 5.0), (18.4, 3.6)):  # 가로대 + 애자
        box(p, (0, 0, z), (w, 0.32, 0.32), ARM, bev=0.06, seg=1)
        for k in range(3 if w > 4 else 2):
            x = (-w / 2 + 0.4) + k * ((w - 0.8) / (2 if w > 4 else 1))
            cyl(p, (x, 0, z + 0.16), (x, 0, z + 0.5), 0.12, 0.09, PORCELAIN, seg=6)
            ball(p, (x, 0, z + 0.55), 0.11, PORCELAIN, seg=(6, 4))
        cyl(p, (-w * 0.3, 0, z - 0.1), (0, 0, z - 1.0), 0.05, 0.05, ARM, seg=4)  # 버팀대
        cyl(p, (w * 0.3, 0, z - 0.1), (0, 0, z - 1.0), 0.05, 0.05, ARM, seg=4)
    # 작은 변압기 통 + 받침
    tc = Vector((0.95, 0, 15.2))
    lathe(p, [(0, -0.75), (0.55, -0.75), (0.58, -0.6), (0.58, 0.6), (0.5, 0.75), (0, 0.85)], TRANS, seg=10, c=tc)
    box(p, (0.5, 0, 14.4), (0.7, 0.3, 0.12), ARM)
    for k in (-1, 1):
        cyl(p, tc + Vector((k * 0.2, 0, 0.8)), tc + Vector((k * 0.2, 0, 1.05)), 0.07, 0.05, PORCELAIN, seg=5)
    # 발판 못 (사다리처럼)
    for k in range(6):
        z = 7 + k * 1.1
        a = math.radians(90 if k % 2 else 270)
        cyl(p, (0, 0, z), (math.cos(a) * 0.75, math.sin(a) * 0.75, z), 0.04, 0.04, ARM, seg=4)
    return p


def street_lamp():
    p = Prop("StreetLamp")
    box(p, (0, 0.04, 0), (0.4, 0.08, 0.7), LAMP, bev=0.03, seg=1)  # 붙이는 판
    cyl(p, (0, 0, 0.15), (0, -2.6, 0.75), 0.08, 0.07, LAMP, seg=6)  # 팔
    cyl(p, (0, 0, -0.25), (0, -1.2, 0.45), 0.05, 0.05, LAMP, seg=5)  # 버팀
    cyl(p, (0, -2.6, 0.75), (0, -3.35, 0.65), 0.07, 0.07, LAMP, seg=6)
    lc = Vector((0, -3.4, 0.35))
    lathe(p, [(0.82, 0.0), (0.78, 0.06), (0.5, 0.22), (0.15, 0.32), (0.0, 0.36)], LAMP, seg=12, c=lc, cap_bottom=False)  # 갓 (위)
    lathe(p, [(0.0, -0.02), (0.82, -0.02), (0.82, 0.0)], PORCELAIN, seg=12, c=lc)  # 갓 안쪽 흰 면
    ball(p, lc + Vector((0, 0, -0.12)), 0.22, BULB, seg=(8, 5))
    return p


def bicycle():
    p = Prop("Bicycle")
    R = 1.05
    fw, rw = Vector((-1.95, 0, R)), Vector((1.95, 0, R))
    for w in (fw, rw):
        ring(p, w, R - 0.08, 0.09, TIRE, useg=18, vseg=4, m=rot(x=90))
        cyl(p, w + Vector((0, -0.12, 0)), w + Vector((0, 0.12, 0)), 0.09, 0.09, METAL, seg=6)
        for k in range(4):  # 바큇살 4줄
            a = math.pi * k / 4
            d = Vector((math.cos(a), 0, math.sin(a))) * (R - 0.24)
            cyl(p, w - d, w + d, 0.012, 0.012, METAL, seg=3)
    bb = Vector((0.15, 0, 0.75))  # 크랭크
    st = Vector((0.55, 0, 2.05))  # 안장 기둥 위
    hd = Vector((-1.45, 0, 2.15))  # 핸들 기둥 위
    for a, b in ((bb, st), (bb, hd + Vector((0.1, 0, -0.3))), (st + Vector((-0.1, 0, -0.25)), hd + Vector((0.05, 0, -0.15))),
                 (bb, rw), (st + Vector((0, 0, -0.2)), rw), (hd, fw)):
        cyl(p, a, b, 0.07, 0.07, MINT, seg=6)
    cyl(p, st, st + Vector((0.05, 0, 0.3)), 0.05, 0.05, METAL, seg=5)
    ball(p, st + Vector((0.1, 0, 0.42)), (0.4, 0.2, 0.1), SEAT, seg=(8, 4))
    cyl(p, hd, hd + Vector((0.15, 0, 0.35)), 0.05, 0.05, METAL, seg=5)
    hb = hd + Vector((0.2, 0, 0.38))
    cyl(p, hb + Vector((0, -0.55, 0)), hb + Vector((0, 0.55, 0)), 0.045, 0.045, METAL, seg=5)
    for s in (-1, 1):
        cyl(p, hb + Vector((0, s * 0.45, 0)), hb + Vector((0, s * 0.62, 0)), 0.07, 0.07, SEAT, seg=5)
    ring(p, bb + Vector((0, -0.1, 0)), 0.28, 0.04, METAL, useg=10, vseg=3, m=rot(x=90))  # 체인 톱니
    box(p, bb + Vector((0.1, -0.3, -0.25)), (0.3, 0.1, 0.06), DARK)  # 페달
    cyl(p, bb, bb + Vector((-0.2, 0.35, -0.75)), 0.03, 0.03, METAL, seg=4)  # 받침대
    # 앞 바구니 + 뒤 짐받이
    box(p, hd + Vector((-0.45, 0, -0.1)), (0.8, 0.75, 0.55), WICKER, bev=0.06, seg=1)
    box(p, hd + Vector((-0.45, 0, 0.18)), (0.84, 0.79, 0.04), WOOD_D)
    box(p, rw + Vector((-0.2, 0, 0.55)), (1.0, 0.45, 0.05), METAL)
    cyl(p, rw + Vector((0.2, 0, 0.53)), rw, 0.03, 0.03, METAL, seg=4)
    ring(p, fw + Vector((0, 0, 0)), R + 0.05, 0.04, MINT, useg=10, vseg=3, m=rot(x=90) @ rot(z=0))  # 흙받이 대신 앞 테
    return p


def briquette_stack():
    p = Prop("BriquetteStack")
    r, h = 0.68, 0.7
    cols = [(-0.72, -0.72), (0.72, -0.72), (-0.72, 0.72), (0.72, 0.72)]
    heights = [3, 3, 3, 2]
    for (x, y), n in zip(cols, heights):
        for k in range(n):
            top = k == n - 1
            col = COAL_BURNT if (x > 0 and y < 0 and k == 0) else COAL
            cyl(p, (x, y, k * h + 0.01), (x, y, (k + 1) * h - 0.01), r, r, col, seg=8)
            if top:
                for j in range(5):  # 구멍 (윗면 어두운 점)
                    a = 2 * math.pi * j / 5
                    q = Vector((x + math.cos(a) * 0.36, y + math.sin(a) * 0.36, (k + 1) * h - 0.01))
                    cyl(p, q, q + Vector((0, 0, 0.012)), 0.08, 0.08, HOLE, seg=4)
                q = Vector((x, y, (k + 1) * h - 0.01))
                cyl(p, q, q + Vector((0, 0, 0.012)), 0.08, 0.08, HOLE, seg=4)
    return p


def pot_basin():
    p = Prop("PotBasin")
    lathe(p, [(0.95, 0.0), (1.12, 0.62), (1.25, 0.7), (1.25, 0.8), (1.1, 0.8), (1.05, 0.72)], BASIN, seg=14, cap_bottom=True)
    lathe(p, [(1.06, 0.66), (0.0, 0.7)], SOIL, seg=14)
    for k in range(6):  # 상추 잎
        a = 2 * math.pi * k / 6
        c = Vector((math.cos(a) * 0.45 - 0.25, math.sin(a) * 0.4, 0.95))
        ball(p, c, (0.32, 0.16, 0.08), LEAF if k % 2 else LEAF_D, seg=(6, 4), m=rot(z=math.degrees(a)) @ rot(y=-35))
    ball(p, (-0.25, 0, 1.0), (0.2, 0.2, 0.18), LEAF, seg=(6, 4))
    cyl(p, (0.55, 0.1, 0.7), (0.55, 0.1, 1.7), 0.04, 0.03, LEAF_D, seg=4)  # 고추 줄기 + 잎 + 고추
    for k, z in enumerate((1.0, 1.3, 1.55)):
        s = 1 if k % 2 else -1
        ball(p, (0.55 + s * 0.2, 0.1, z), (0.2, 0.08, 0.05), LEAF, seg=(6, 3), m=rot(y=s * 20))
    for (dx, z, col) in ((0.12, 1.15, PEPPER), (-0.14, 1.4, LEAF_D), (0.1, 1.6, PEPPER)):
        cyl(p, (0.55 + dx, 0.12, z), (0.55 + dx * 1.3, 0.12, z - 0.32), 0.05, 0.015, col, seg=5)
    return p


def plastic_crate():
    p = Prop("PlasticCrate")
    W, D, H, t = 2.0, 1.5, 1.5, 0.09
    box(p, (0, 0, t / 2), (W, D, t), CRATE)
    for s in (-1, 1):
        box(p, (s * (W / 2 - t / 2), 0, H / 2), (t, D, H), CRATE, bev=0.03, seg=1)
        box(p, (0, s * (D / 2 - t / 2), H / 2), (W, t, H), CRATE, bev=0.03, seg=1)
        box(p, (s * (W / 2 + 0.005), 0, H - 0.3), (0.02, 0.5, 0.18), CRATE_D)  # 손잡이 구멍 (어두운 홈)
        box(p, (0, s * (D / 2 + 0.005), H * 0.45), (1.4, 0.02, 0.5), CRATE_D)  # 옆면 홈 (글자 자리 없이)
    for k in (-1, 0, 1):  # 칸막이
        box(p, (k * W / 4, 0, H * 0.45), (0.05, D - 2 * t, H * 0.9), CRATE_D)
    box(p, (0, 0, H * 0.45), (W - 2 * t, 0.05, H * 0.9), CRATE_D)
    return p


def pyeongsang():
    p = Prop("Pyeongsang")
    W, D, H = 8.0, 5.0, 1.5
    top = H - 0.12
    for k in range(10):  # 마루 널
        x = -W / 2 + 0.4 + k * (W - 0.8) / 9
        box(p, (x, 0, top), (0.74, D - 0.5, 0.14), WOOD if k % 2 else (222, 186, 138))
    for s in (-1, 1):  # 테두리 틀
        box(p, (0, s * (D / 2 - 0.15), top - 0.02), (W, 0.3, 0.22), WOOD_D, bev=0.05, seg=1)
        box(p, (s * (W / 2 - 0.15), 0, top - 0.02), (0.3, D, 0.22), WOOD_D, bev=0.05, seg=1)
    for x in (-W / 2 + 0.35, 0, W / 2 - 0.35):  # 다리 6개
        for y in (-D / 2 + 0.35, D / 2 - 0.35):
            box(p, (x, y, (top - 0.1) / 2), (0.36, 0.36, top - 0.1), WOOD_D)
    for y in (-D / 2 + 0.35, D / 2 - 0.35):  # 아래 가로대
        box(p, (0, y, 0.35), (W - 0.7, 0.16, 0.16), WOOD_D)
    return p


def ac_unit():
    p = Prop("AcUnit")
    W, H, D = 3.0, 2.5, 1.2
    c = Vector((0, -D / 2, H / 2 + 0.1))
    box(p, c, (W, D, H), CREAM, bev=0.14, seg=2)
    fc = c + Vector((-0.4, -D / 2 - 0.01, 0))  # 팬 덮개
    ring(p, fc, 0.85, 0.06, GRILLE, useg=16, vseg=4, m=rot(x=90))
    ring(p, fc, 0.5, 0.035, GRILLE, useg=12, vseg=3, m=rot(x=90))
    for a in (0, 60, 120):
        d = Vector((math.cos(math.radians(a)), 0, math.sin(math.radians(a)))) * 0.85
        cyl(p, fc - d, fc + d, 0.025, 0.025, GRILLE, seg=3)
    ball(p, fc + Vector((0, -0.02, 0)), (0.16, 0.06, 0.16), GRILLE, seg=(8, 4))
    for k in range(5):  # 오른쪽 옆 통풍 줄
        box(p, c + Vector((W / 2 - 0.45, -D / 2 - 0.005, -0.7 + k * 0.35)), (0.6, 0.02, 0.06), (210, 204, 190))
    for s in (-1, 1):  # 벽 받침 다리
        box(p, (s * 1.1, -0.6, 0.05), (0.12, 1.2, 0.1), ARM)
        cyl(p, (s * 1.1, -0.02, 0.05), (s * 1.1, -0.02, -0.7), 0.05, 0.05, ARM, seg=4)
        cyl(p, (s * 1.1, -1.15, 0.05), (s * 1.1, -0.05, -0.7), 0.04, 0.04, ARM, seg=4)
    cyl(p, c + Vector((W / 2 - 0.3, D / 2 - 0.3, -H / 2)), c + Vector((W / 2 - 0.3, D / 2 - 0.3, -H / 2 - 0.6)), 0.05, 0.05, PORCELAIN, seg=5)
    return p


def gas_tank():
    p = Prop("GasTank")
    lathe(p, [(0.0, 0.0), (0.55, 0.0), (0.62, 0.12), (0.62, 2.15), (0.5, 2.42), (0.24, 2.55), (0.0, 2.57)], GAS, seg=12)
    lathe(p, [(0.64, 0.02), (0.64, 0.18), (0.6, 0.2)], GAS_D, seg=12)  # 아래 받침 링
    lathe(p, [(0.26, 2.5), (0.34, 2.52), (0.34, 2.9), (0.3, 2.95), (0.26, 2.9)], GAS_D, seg=10)  # 목 보호 링
    cyl(p, (0, 0, 2.55), (0, 0, 2.82), 0.08, 0.08, METAL, seg=6)  # 밸브
    cyl(p, (0, -0.12, 2.75), (0, -0.28, 2.75), 0.05, 0.05, METAL, seg=5)
    ring(p, (0, 0, 2.86), 0.12, 0.03, METAL, useg=8, vseg=3)
    return p


def trash_bin():
    p = Prop("TrashBin")
    lathe(p, [(0.0, 0.0), (0.72, 0.0), (0.8, 2.55), (0.84, 2.6), (0.84, 2.65)], BIN, seg=14)
    for z in (0.6, 1.5):  # 띠 두 줄
        ring(p, (0, 0, z), 0.74 + z * 0.03, 0.04, BIN_D, useg=14, vseg=3)
    lathe(p, [(0.88, 2.62), (0.88, 2.7), (0.6, 2.86), (0.2, 2.92), (0.0, 2.93)], BIN_D, seg=14)  # 뚜껑
    cyl(p, (-0.18, 0, 2.95), (0.18, 0, 2.95), 0.035, 0.035, METAL, seg=4)  # 손잡이
    for s in (-1, 1):
        cyl(p, (s * 0.18, 0, 2.95), (s * 0.18, 0, 2.88), 0.03, 0.03, METAL, seg=4)
        cyl(p, (s * 0.84, 0, 2.2), (s * 0.95, 0, 2.2), 0.04, 0.04, BIN_D, seg=4)  # 옆 손잡이
    return p


def mailbox():
    p = Prop("Mailbox")
    cyl(p, (0, 0, 0), (0, 0, 2.3), 0.14, 0.12, POST_RED, seg=8)
    box(p, (0, 0, 0.04), (0.6, 0.6, 0.08), DARK, bev=0.03, seg=1)
    c = Vector((0, 0, 3.05))
    box(p, c, (1.1, 0.85, 1.3), POST_RED, bev=0.1, seg=2)
    cyl(p, c + Vector((-0.55, 0, 0.65)), c + Vector((0.55, 0, 0.65)), 0.42, 0.42, POST_RED, seg=10)  # 둥근 지붕
    box(p, c + Vector((0, -0.43, 0.3)), (0.6, 0.04, 0.08), DARK, bev=0.02, seg=1)  # 넣는 구멍
    box(p, c + Vector((0, -0.43, -0.25)), (0.7, 0.03, 0.55), (196, 78, 72), bev=0.03, seg=1)  # 꺼내는 문
    ball(p, c + Vector((0.25, -0.46, -0.25)), 0.04, METAL, seg=(5, 3))
    return p


def shop_sign():
    p = Prop("ShopShutterSign")
    box(p, (0, 0.04, 0), (14.0, 0.2, 2.5), SIGN_RIM, bev=0.45, seg=3)  # 둥근 테두리 판 (뒤)
    box(p, (0, -0.06, 0), (13.4, 0.14, 1.95), SIGN, bev=0.35, seg=3)  # 글씨 쓸 앞판
    return p


PROPS = [utility_pole(), street_lamp(), bicycle(), briquette_stack(), pot_basin(), plastic_crate(),
         pyeongsang(), ac_unit(), gas_tank(), trash_bin(), mailbox(), shop_sign()]
BUDGET = {"UtilityPole": 1000, "Bicycle": 1000}

# ───────────── 오브젝트 + 팔레트 재질 ─────────────
IMG = palette_image()
MAT = bpy.data.materials.new("AlleyPalette")
MAT.use_nodes = True
nt = MAT.node_tree
bsdf = nt.nodes["Principled BSDF"]
bsdf.inputs["Roughness"].default_value = 0.8
tex = nt.nodes.new("ShaderNodeTexImage")
tex.image = IMG
tex.interpolation = "Closest"
nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])

rows = []
objs = []
for p in PROPS:
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
    me.materials.append(MAT)
    o = bpy.data.objects.new(p.name, me)
    scene.collection.objects.link(o)
    objs.append(o)
    tris = sum(len(f.vertices) - 2 for f in me.polygons)
    lo = Vector([min(v.co[i] for v in me.vertices) for i in range(3)])
    hi = Vector([max(v.co[i] for v in me.vertices) for i in range(3)])
    c, s = (lo + hi) / 2, hi - lo
    piv = -c  # 경계 상자 가운데 → 기준점(원점), Roblox 좌표 (-x, z, y)
    ok = "OK" if tris <= BUDGET.get(p.name, 600) else "OVER"
    rows.append(f"{p.name}\ttris={tris} ({ok})\tsize=({s.x:.2f}, {s.z:.2f}, {s.y:.2f})\tcenter_to_pivot=({-piv.x:.2f}, {piv.z:.2f}, {piv.y:.2f})")
with open(os.path.join(OUT, "alley_parts.txt"), "w", encoding="utf-8") as f:
    f.write("# 이름\t삼각형\tRoblox 크기 (X, Y, Z)\tMeshPart 가운데에서 기준점까지 (Roblox 좌표)\n" + "\n".join(rows) + "\n")
print("\n".join(rows))

for o in objs:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "dalgona_alley.glb"), export_format="GLB", use_selection=True, export_apply=True)

# ───────────── 미리 보기 (가져가지 않는 배치) ─────────────
layout = {"UtilityPole": (-13, 3), "StreetLamp": (-12.4, 2.6), "Bicycle": (-7.5, 0), "BriquetteStack": (-3, 0),
          "PotBasin": (0, -0.5), "PlasticCrate": (2.6, 0), "Pyeongsang": (8.5, 2), "AcUnit": (14.5, 3),
          "GasTank": (17.5, 0), "TrashBin": (19.7, 0), "Mailbox": (22, 0), "ShopShutterSign": (4, 9)}
lifts = {"StreetLamp": 15.0, "AcUnit": 3.0, "ShopShutterSign": 4.0}
for o in objs:
    x, y = layout[o.name]
    o.location = (x, y, lifts.get(o.name, 0))
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.82, 0.86, 0.9, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
scene.world = world
bpy.ops.mesh.primitive_plane_add(size=80, location=(4, 0, 0))
fl = bpy.context.active_object
fm = bpy.data.materials.new("Floor")
fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.62, 0.58, 0.54, 1)
fl.data.materials.append(fm)
bpy.ops.mesh.primitive_plane_add(size=1, location=(4, 11.5, 6))
wall = bpy.context.active_object
wall.scale = (60, 1, 12)
wall.rotation_euler = (math.radians(90), 0, 0)
wm = bpy.data.materials.new("Wall")
wm.use_nodes = True
wm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.78, 0.55, 0.48, 1)
wall.data.materials.append(wm)
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.0
sun.data.angle = math.radians(20)
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-30))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.lens = 32
cam.location = (4, -44, 13)
cam.rotation_euler = (Vector((4, 2, 8.5)) - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 1800, 900
scene.view_settings.view_transform = "Standard"
scene.render.filepath = os.path.join(OUT, "alley_preview.png")
bpy.ops.render.render(write_still=True)
print("[alley] done")
