# 아늑한 가게 그림체의 2·3단계 기계 (사용자 2026-11-24: "2·3단계 기계도 아늑한 그림체로 만들어 줘")
#   지금 가게 기계 자리(MachineLayout.Stage2·Stage3)의 구성과 크기를 그대로 따름:
#     2단계 = 화구 2개 달린 판매대 + 뒤 선반(설탕 병·소다 깡통·그릇) — 예전 회색 철판 화구
#     3단계 = 나무 받침장 + 위 유리 진열 상자(안에 열판·설탕/소다 노즐·컵·누름판) — 예전 크림 상자
#   그림체는 cozy_factory.py·cozy_line.py와 같음: 따뜻한 나무, 크림, 구리·놋쇠, 사탕색 단추, 모서리 3단 둥글게 깎기,
#   평평한 면은 평평하게(set_sharp_from_angle), 팔레트 텍스처 한 장. 글자·상표 없음. 천막(차양)은 넣지 않음 (11-24 4단계에서 뺌).
#
# 부품 이름: 2단계 S2_*, 3단계 S3_* (예전 틀에 있던 S2_Soda·S3_HotPlate·S3_SugarDrip·S3_SodaDrip 이름은 같은 역할에 그대로 씀).
#   움직임 제안(Anim)은 *_parts.txt 에 적음. 아직 게임 코드에는 없음.
#
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/cozy_stage23.py -- <출력 폴더(절대 경로)> <2|3>
# 결과: dalgona_cozy_stage<n>.glb, cozy_stage<n>_preview.png, cozy_stage<n>_parts.txt
# 크기 = 게임 stud (1배). 원점 = 바닥 가운데. 앞(손님·플레이어 쪽) = Blender -Y. 좌표 변환 Blender (x, y, z) → Roblox (-x, z, y).

import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else ".")
STAGE = int(argv[1]) if len(argv) > 1 else 2
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)

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
    img = bpy.data.images.new(f"CozyStage{STAGE}Palette", size, size, alpha=False)
    rgba = np.ones((size, size, 4), dtype=np.float32)
    rgba[:, :, :3] = np.clip(arr, 0, 1) ** 2.2
    img.pixels.foreach_set(rgba.ravel())
    img.pack()
    return img


WOOD = (198, 144, 98)
WOOD_D = (146, 98, 62)
WOOD_L = (222, 176, 122)
CREAM = (246, 234, 212)
CREAM_D = (230, 212, 184)
ORANGE = (238, 172, 122)
BRASS = (226, 186, 110)
COPPER = (204, 138, 96)
COPPER_D = (172, 110, 74)
IRON = (86, 74, 68)
BULB = (255, 226, 160)
GLASS = (224, 236, 234)
SUGAR = (252, 250, 244)
SODA = (244, 246, 248)
DALGONA = (226, 172, 98)
DALGONA_D = (182, 126, 64)
STEEL = (210, 206, 198)
BOARD = (70, 60, 54)
RED_BTN = (230, 120, 104)
MINT_BTN = (150, 204, 176)
SKY_BTN = (150, 190, 226)
LEMON_BTN = (246, 214, 120)
PINK_BTN = (246, 178, 196)
STICK = (240, 226, 196)

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


P = {}
NOTES = {}


def part(name, note):
    P[name] = Part(name)
    NOTES[name] = note
    return P[name]


def V(v):
    return Vector(v)


def box(p, c, size, rgb, bev=None, seg=3, m=I4):
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


def ring(p, c, r, w, h, rgb, seg=24, m=I4):
    """납작한 고리 (화구 코일·테)."""
    lathe(p, [(r - w, 0), (r + w, 0), (r + w, h), (r - w, h), (r - w, 0)], rgb, seg=seg, c=c, m=m)


def rounded_disc(p, c, r, h, rgb, seg=20, m=I4):
    e = min(h * 0.45, r * 0.2)
    lathe(p, [(0, 0), (r - e, 0), (r - e * 0.3, e * 0.3), (r, e), (r, h - e), (r - e * 0.3, h - e * 0.3), (r - e, h), (0, h)], rgb, seg=seg, c=c, m=m)


def flat_shape(p, c, pts, h, rgb, m=I4):
    """2D 다각형(pts, 시계 반대)을 h만큼 세운 판. 가운데 점으로 부채꼴."""
    M = Matrix.Translation(V(c)) @ m
    top = [p.bm.verts.new(M @ Vector((x, y, h))) for x, y in pts]
    bot = [p.bm.verts.new(M @ Vector((x, y, 0))) for x, y in pts]
    cx = sum(x for x, _ in pts) / len(pts)
    cy = sum(y for _, y in pts) / len(pts)
    ct = p.bm.verts.new(M @ Vector((cx, cy, h)))
    faces = []
    n = len(pts)
    for k in range(n):
        k2 = (k + 1) % n
        faces.append(p.bm.faces.new((ct, top[k], top[k2])))
        faces.append(p.bm.faces.new((bot[k], bot[k2], top[k2], top[k])))
    bmesh.ops.recalc_face_normals(p.bm, faces=faces)
    p.paint(rgb)


def star_pts(R, n=5, inner=0.45):
    return [(math.cos(math.pi / 2 + k * math.pi / n) * (R if k % 2 == 0 else R * inner),
             math.sin(math.pi / 2 + k * math.pi / n) * (R if k % 2 == 0 else R * inner)) for k in range(2 * n)]


def heart_pts(R):
    pts = []
    for k in range(24):
        t = 2 * math.pi * k / 24
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x / 17 * R, y / 17 * R))
    return pts


def poly_pts(R, n, a0=90):
    return [(math.cos(math.radians(a0) + 2 * math.pi * k / n) * R, math.sin(math.radians(a0) + 2 * math.pi * k / n) * R) for k in range(n)]


def dalgona(p, c, r=0.34, h=0.06, star=True, m=I4):
    rounded_disc(p, c, r, h, DALGONA, seg=18, m=m)
    if star:
        flat_shape(p, V(c) + (m.to_3x3() @ Vector((0, 0, h - 0.005))), star_pts(r * 0.55), 0.02, DALGONA_D, m=m)


def ladle(p, c, r, handle_dir, length, rgb=COPPER):
    """구리 국자: 둥근 그릇 + 놋쇠 띠 + 길게 뻗은 손잡이(나무 끝)."""
    c = V(c)
    lathe(p, [(0, 0), (r * 0.6, 0.0), (r * 0.9, r * 0.25), (r, r * 0.55), (r * 1.02, r * 0.62), (r * 0.95, r * 0.6), (r * 0.88, r * 0.3), (r * 0.55, r * 0.08), (0, r * 0.08)],
          rgb, seg=18, c=c)
    d = V(handle_dir).normalized()
    a = c + d * r * 0.95 + Vector((0, 0, r * 0.55))
    b = a + d * length + Vector((0, 0, length * 0.25))
    cyl(p, a, b, 0.05, 0.045, BRASS, seg=8)
    cyl(p, b - (b - a).normalized() * 0.35, b + (b - a).normalized() * 0.05, 0.08, 0.07, WOOD_D, seg=8)


# ───────────────────────── 2단계 ─────────────────────────
def build_stage2():
    W, D, H = 6.6, 4.0, 3.2  # 몸통 폭·깊이·높이 (예전 회색 화구대 7.15 × 4.5 × 5.5(선반 포함))
    body = part("S2_Body", "나무 받침장·크림 문판·놋쇠 손잡이·크림 윗판·동전 상자·뒤 선반 기둥과 판 (Wood/SmoothPlastic)")
    box(body, (0, 0, 0.12), (W + 0.1, D + 0.1, 0.24), WOOD_D, bev=0.08)
    box(body, (0, 0, H / 2 + 0.1), (W, D, H - 0.2), WOOD, bev=0.16)
    for sx in (-1, 1):  # 앞 문판 2개 + 손잡이
        box(body, (sx * W / 4, -D / 2 - 0.03, 1.55), (W / 2 - 0.55, 0.08, 2.0), CREAM, bev=0.05)
        box(body, (sx * W / 4, -D / 2 - 0.05, 1.55), (W / 2 - 0.85, 0.08, 1.7), CREAM_D, bev=0.04)
        ball(body, (sx * 0.4, -D / 2 - 0.12, 1.75), 0.09, BRASS, seg=(10, 6))
    box(body, (0, 0, H + 0.08), (W + 0.25, D + 0.25, 0.18), CREAM, bev=0.08)  # 크림 칠 윗판
    box(body, (0, -D / 2 - 0.05, H - 0.08), (W + 0.2, 0.12, 0.16), BRASS, bev=0.04)  # 앞 놋쇠 띠
    # 오른쪽 옆 동전 상자 (글자 없음)
    box(body, (W / 2 + 0.22, -0.6, 2.2), (0.4, 0.9, 1.1), WOOD_D, bev=0.08)
    box(body, (W / 2 + 0.44, -0.6, 2.35), (0.06, 0.55, 0.12), BRASS, bev=0.02, seg=1)
    box(body, (W / 2 + 0.47, -0.6, 2.35), (0.03, 0.32, 0.04), IRON, bev=0.005, seg=1)
    # 화구 2개: 무쇠 받침 + 놋쇠 테 (코일은 따로 = 데워지면 빛남)
    TZ = H + 0.17
    coil = part("S2_Coils", "화구 코일 2개 (Anim heat: 데울 때 주황 Neon)")
    for i, x in enumerate((-1.6, 1.6)):
        lathe(body, [(0, 0), (1.05, 0), (1.1, 0.06), (1.05, 0.12), (0, 0.12)], IRON, seg=24, c=(x, -0.3, TZ))
        ring(body, (x, -0.3, TZ + 0.1), 1.08, 0.05, 0.05, BRASS, seg=24)
        for r in (0.3, 0.55, 0.8):
            ring(coil, (x, -0.3, TZ + 0.12), r, 0.06, 0.04, (120, 92, 80), seg=20)
    # 화구 손잡이 (앞 띠 위, 2개)
    knob = part("S2_Knobs", "화구 불 조절 손잡이 2개 (Anim turn: 켤 때 앞뒤 축으로 90° 돌림, 각 손잡이 가운데)")
    for x in (-1.6, 1.6):
        cyl(knob, (x, -D / 2 - 0.1, H - 0.08), (x, -D / 2 - 0.32, H - 0.08), 0.17, 0.15, CREAM_D, seg=12)
        box(knob, (x, -D / 2 - 0.33, H - 0.08), (0.06, 0.04, 0.26), WOOD_D, bev=0.01, seg=1)
    # 화구 위 구리 국자 2개
    for i, (x, hd) in enumerate(((-1.6, (-1, -0.35, 0)), (1.6, (1, -0.35, 0)))):
        lp = part(f"S2_Ladle_{i + 1}", f"화구 위 구리 국자 {i + 1} (Anim stir: 그릇 가운데 축으로 천천히 흔들기)")
        ladle(lp, (x, -0.3, TZ + 0.16), 0.62, hd, 1.1)
        rounded_disc(lp, (x, -0.3, TZ + 0.2), 0.48, 0.06, DALGONA, seg=18)  # 국자 속 녹은 설탕
    # 뒤 선반: 기둥 2개 + 선반 판 2단 + 견본판(도안 8칸)
    by = D / 2 - 0.3
    for sx in (-1, 1):
        box(body, (sx * (W / 2 - 0.2), by, H + 1.5), (0.26, 0.26, 3.0), WOOD_D, bev=0.07)
    box(body, (0, by, H + 1.25), (W - 0.2, 0.08, 1.3), BOARD, bev=0.03)  # 견본판
    sample = part("S2_Samples", "견본판 도안 8칸 (놋쇠 모양, Anim 없음 — 도안 바꾸면 반짝이게 할 수 있음)")
    shapes = [star_pts(0.28), heart_pts(0.3), poly_pts(0.3, 3), poly_pts(0.27, 4, 45), poly_pts(0.28, 24),
              star_pts(0.3, 6, 0.6), poly_pts(0.3, 6), heart_pts(0.26)]
    for k, pts in enumerate(shapes):
        x = -W / 2 + 0.75 + k * (W - 1.5) / 7
        flat_shape(sample, (x, by - 0.04, H + 1.25), pts, 0.05, BRASS, m=rot(x=90))
    box(body, (0, by, H + 2.02), (W + 0.1, 0.9, 0.14), WOOD_L, bev=0.05)  # 위 선반
    box(body, (0, by, H + 3.02), (W - 0.1, 0.8, 0.12), WOOD_L, bev=0.05)  # 꼭대기 판
    # 선반 위: 유리 설탕 병 2 · 소다 깡통 · 그릇 2
    jar = part("S2_Jars", "유리 설탕 병 2개 (Glass, Transparency 0.5)")
    jsug = part("S2_JarSugar", "병 속 설탕 (Anim hopper: 쓸 때 높이 줄임)")
    for x in (-2.3, -1.3):
        c = (x, by, H + 2.1)
        lathe(jar, [(0.2, 0), (0.36, 0.02), (0.38, 0.1), (0.38, 0.78), (0.3, 0.86), (0.22, 0.9), (0, 0.9)], GLASS, seg=16, c=c)
        lathe(jsug, [(0, 0.03), (0.34, 0.03), (0.35, 0.55), (0.2, 0.6), (0, 0.6)], SUGAR, seg=14, c=c)
        lathe(body, [(0, 0.88), (0.26, 0.88), (0.28, 0.96), (0.24, 1.02), (0, 1.02)], WOOD_D, seg=14, c=c)
    soda = part("S2_Soda", "소다 깡통 + 숟가락 (예전 S2_Soda 자리)")
    lathe(soda, [(0, 0), (0.3, 0), (0.32, 0.05), (0.32, 0.55), (0.3, 0.6), (0, 0.6)], STEEL, seg=16, c=(0.0, by, H + 2.1))
    lathe(soda, [(0.33, 0.2), (0.34, 0.2), (0.34, 0.4), (0.33, 0.4)], RED_BTN, seg=16, c=(0.0, by, H + 2.1))
    cyl(soda, (0.05, by, H + 2.6), (0.25, by - 0.2, H + 3.0), 0.03, 0.03, STEEL, seg=6)
    for x, col in ((1.2, CREAM), (2.2, CREAM_D)):
        lathe(body, [(0, 0), (0.22, 0), (0.38, 0.12), (0.42, 0.26), (0.38, 0.27), (0.34, 0.15), (0, 0.06)], col, seg=16, c=(x, by, H + 2.1))
        rounded_disc(body, (x, by, H + 2.18), 0.3, 0.06, SUGAR if x < 2 else DALGONA, seg=14)
    # 꼭대기 등불 (돌 때 켜짐)
    lamp = part("S2_Lamp", "꼭대기 등불 유리 (Anim lampRun: 돌 때 Neon)")
    lx = W / 2 - 0.5
    cyl(body, (lx, by, H + 3.08), (lx, by, H + 3.2), 0.18, 0.18, BRASS, seg=10)
    ball(lamp, (lx, by, H + 3.45), (0.2, 0.2, 0.26), BULB, seg=(12, 8))
    cyl(body, (lx, by, H + 3.7), (lx, by, H + 3.82), 0.08, 0.16, BRASS, seg=10)
    # 앞 받는 쟁반 (다 된 달고나)
    out = part("S2_Output", "앞 나무 쟁반의 다 된 달고나 (Anim outlet: 나오는 곳)")
    box(body, (0, -D / 2 - 0.45, H - 0.45), (1.6, 0.8, 0.08), WOOD_L, bev=0.03)
    box(body, (0, -D / 2 - 0.15, H - 0.7), (1.2, 0.3, 0.5), WOOD_D, bev=0.05)
    for k, (dx, dy) in enumerate(((-0.45, -0.05), (0.0, 0.05), (0.45, -0.05))):
        dalgona(out, (dx, -D / 2 - 0.45 + dy, H - 0.4), r=0.24, h=0.05, m=rot(z=k * 25))
    return dict(W=W, D=D, H=H, cam=((5.5, -11.5, 7.5), (0, 0, 3.0)))


# ───────────────────────── 3단계 ─────────────────────────
def build_stage3():
    W, D, H = 6.8, 4.6, 3.0  # 받침장 (예전 나무장 7.1 × 3.6 × 5.1)
    body = part("S3_Body", "나무 받침장·크림 판·놋쇠 띠·유리 상자 크림 틀·노즐 받침·단추판·막대 통 (Wood/SmoothPlastic)")
    box(body, (0, 0, 0.12), (W + 0.1, D + 0.1, 0.24), WOOD_D, bev=0.08)
    box(body, (0, 0, H / 2 + 0.1), (W, D, H - 0.2), WOOD, bev=0.16)
    box(body, (-0.6, -D / 2 - 0.03, 1.5), (W - 2.2, 0.08, 1.9), CREAM, bev=0.05)
    box(body, (-0.6, -D / 2 - 0.05, 1.5), (W - 2.6, 0.08, 1.6), CREAM_D, bev=0.04)
    box(body, (0, 0, H + 0.06), (W + 0.25, D + 0.25, 0.16), WOOD_L, bev=0.07)
    box(body, (0, -D / 2 - 0.05, H - 0.1), (W + 0.2, 0.12, 0.14), BRASS, bev=0.04)
    # 오른쪽 앞 단추판 (동전 구멍 + 사탕 단추 4개)
    px = W / 2 - 0.8
    box(body, (px, -D / 2 - 0.08, 1.6), (1.1, 0.14, 2.1), CREAM, bev=0.06)
    box(body, (px, -D / 2 - 0.16, 2.35), (0.5, 0.04, 0.14), BRASS, bev=0.02, seg=1)
    box(body, (px, -D / 2 - 0.19, 2.35), (0.32, 0.03, 0.04), IRON, bev=0.005, seg=1)
    btn = part("S3_Buttons", "사탕 단추 4개 (Anim lampRun: 돌 때 차례로 반짝)")
    for k, col in enumerate((PINK_BTN, SKY_BTN, LEMON_BTN, MINT_BTN)):
        q = (px + (-0.22 if k % 2 == 0 else 0.22), -D / 2 - 0.16, 1.85 - (k // 2) * 0.45)
        cyl(btn, q, (q[0], q[1] - 0.12, q[2]), 0.16, 0.14, col, seg=12)
    # 앞 배출구 (나무 서랍 모양 + 쟁반)
    out = part("S3_Output", "앞 배출구 쟁반의 다 된 달고나 (Anim outlet)")
    box(body, (-0.6, -D / 2 - 0.25, 0.75), (1.8, 0.5, 0.12), WOOD_L, bev=0.04)
    for k, dx in enumerate((-0.45, 0.0, 0.45)):
        dalgona(out, (-0.6 + dx, -D / 2 - 0.25, 0.82), r=0.22, h=0.05, m=rot(z=k * 30))
    # 유리 진열 상자 (위)
    CW, CD, CH = 5.0, 3.8, 3.2
    cz = H + 0.14
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(body, (sx * (CW / 2 - 0.12), sy * (CD / 2 - 0.12), cz + CH / 2), (0.24, 0.24, CH), CREAM, bev=0.07)
    for z in (cz + 0.08, cz + CH - 0.1):
        for sy in (-1, 1):
            box(body, (0, sy * (CD / 2 - 0.12), z), (CW, 0.24, 0.2), CREAM, bev=0.07)
        for sx in (-1, 1):
            box(body, (sx * (CW / 2 - 0.12), 0, z), (0.24, CD, 0.2), CREAM, bev=0.07)
    box(body, (0, 0, cz + CH + 0.06), (CW + 0.3, CD + 0.3, 0.16), WOOD_D, bev=0.06)  # 지붕
    box(body, (0, 0, cz + 0.02), (CW - 0.2, CD - 0.2, 0.06), CREAM_D, bev=0.02)  # 바닥 판
    glass = part("S3_Glass", "진열 상자 유리 4면 (Glass, Transparency 0.6)")
    for sy in (-1, 1):
        box(glass, (0, sy * (CD / 2 - 0.12), cz + CH / 2), (CW - 0.4, 0.04, CH - 0.36), GLASS, bev=0.01, seg=1)
    for sx in (-1, 1):
        box(glass, (sx * (CW / 2 - 0.12), 0, cz + CH / 2), (0.04, CD - 0.4, CH - 0.36), GLASS, bev=0.01, seg=1)
    # 안: 열판(왼쪽) + 컵·막대 / 누름판(오른쪽) / 천장 노즐 2개(설탕·소다)
    hx = -1.0
    lathe(body, [(0, 0), (0.85, 0), (0.9, 0.08), (0.85, 0.16), (0, 0.16)], WOOD_D, seg=20, c=(hx, 0.1, cz + 0.05))
    hot = part("S3_HotPlate", "열판 (Anim heat: 데울 때 주황 Neon, 예전 S3_HotPlate 자리)")
    lathe(hot, [(0, 0), (0.7, 0), (0.72, 0.04), (0, 0.06)], COPPER_D, seg=20, c=(hx, 0.1, cz + 0.2))
    cup = part("S3_Cup", "구리 컵 + 저을 막대 (Anim stir: 컵 가운데 축으로 막대가 돎)")
    lathe(cup, [(0, 0), (0.38, 0), (0.42, 0.05), (0.45, 0.55), (0.48, 0.6), (0.42, 0.6), (0.4, 0.1), (0, 0.1)], COPPER, seg=18, c=(hx, 0.1, cz + 0.27))
    rounded_disc(cup, (hx, 0.1, cz + 0.5), 0.38, 0.06, DALGONA, seg=16)
    cyl(cup, (hx + 0.1, 0.1, cz + 0.4), (hx + 0.35, 0.25, cz + 1.6), 0.04, 0.04, STICK, seg=6)
    for k, (nx, col) in enumerate(((-1.35, SUGAR), (-0.6, SODA))):
        cyl(body, (nx, 0.1, cz + CH - 0.2), (nx, 0.1, cz + CH - 0.75), 0.18, 0.18, BRASS, seg=12)
        cyl(body, (nx, 0.1, cz + CH - 0.75), (nx, 0.1, cz + CH - 1.0), 0.18, 0.06, BRASS, seg=12)
        lathe(body, [(0, 0), (0.3, 0), (0.32, 0.4), (0.25, 0.45), (0, 0.45)], CREAM_D, seg=14, c=(nx, 0.1, cz + CH - 0.55))
    sd = part("S3_SugarDrip", "설탕 노즐 끝 알갱이 (Anim drip: 컵으로 떨어짐, 예전 S3_SugarDrip 자리)")
    ball(sd, (-1.35, 0.1, cz + CH - 1.12), 0.07, SUGAR, seg=(8, 6))
    so = part("S3_SodaDrip", "소다 노즐 끝 알갱이 (Anim drip, 예전 S3_SodaDrip 자리)")
    ball(so, (-0.6, 0.1, cz + CH - 1.12), 0.07, SODA, seg=(8, 6))
    # 누름판 (오른쪽): 받침 틀 + 위 기둥 + 움직이는 누름 머리
    rx = 1.3
    box(body, (rx, 0.1, cz + 0.15), (1.4, 1.4, 0.2), WOOD_D, bev=0.06)
    rounded_disc(body, (rx, 0.1, cz + 0.25), 0.5, 0.05, DALGONA, seg=18)
    box(body, (rx, 0.85, cz + 1.2), (0.25, 0.25, 2.2), WOOD_D, bev=0.07)
    box(body, (rx, 0.45, cz + 2.25), (0.3, 1.0, 0.22), WOOD_D, bev=0.07)
    press = part("S3_Press", "누름 머리 (Anim press: Roblox Y로 약 0.9 내리면 달고나에 닿음)")
    cyl(press, (rx, 0.1, cz + 2.15), (rx, 0.1, cz + 1.55), 0.07, 0.07, STEEL, seg=10)
    lathe(press, [(0, 0), (0.55, 0), (0.6, 0.06), (0.6, 0.18), (0.4, 0.26), (0, 0.27)], BRASS, seg=20, c=(rx, 0.1, cz + 1.3))
    flat_shape(press, (rx, 0.1, cz + 1.3), star_pts(0.32), -0.03, COPPER_D)
    # 지붕 위 등불 (가운데)
    lamp = part("S3_Lamp", "지붕 위 둥근 등 (Anim lampRun)")
    lz = cz + CH + 0.14
    cyl(body, (0, 0, lz), (0, 0, lz + 0.14), 0.25, 0.22, BRASS, seg=12)
    ball(lamp, (0, 0, lz + 0.4), 0.28, BULB, seg=(14, 8))
    # 받침장 위 옆: 왼쪽 설탕 병 / 오른쪽 막대 통
    jar = part("S3_Jar", "왼쪽 유리 설탕 병 (Glass)")
    jx = -W / 2 + 0.45
    lathe(jar, [(0.18, 0), (0.3, 0.02), (0.32, 0.1), (0.32, 0.9), (0.25, 0.98), (0, 1.0)], GLASS, seg=14, c=(jx, -0.8, H + 0.14))
    lathe(body, [(0, 0.03), (0.28, 0.03), (0.29, 0.6), (0, 0.65)], SUGAR, seg=12, c=(jx, -0.8, H + 0.14))
    lathe(body, [(0, 0.98), (0.24, 0.98), (0.25, 1.08), (0, 1.1)], WOOD_D, seg=12, c=(jx, -0.8, H + 0.14))
    sx_ = W / 2 - 0.45
    lathe(body, [(0, 0), (0.28, 0), (0.3, 0.7), (0.26, 0.7), (0.24, 0.06), (0, 0.06)], COPPER, seg=14, c=(sx_, -0.8, H + 0.14))
    sticks = part("S3_Sticks", "막대 통의 나무 막대 (꽂혀 있음)")
    for k in range(7):
        a = 2 * math.pi * k / 7
        b = V((sx_ + math.cos(a) * 0.12, -0.8 + math.sin(a) * 0.12, H + 0.2))
        cyl(sticks, b, b + V((math.cos(a) * 0.12, math.sin(a) * 0.12, 1.3)), 0.025, 0.025, STICK, seg=5)
    return dict(W=W, D=D, H=H + CH, cam=((5.8, -11.0, 8.2), (0, 0, 3.2)))


info = build_stage2() if STAGE == 2 else build_stage3()

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

rows, objs, total = [], [], 0
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
rows.append(f"# 합계 삼각형 {total}. center = 기계 원점(바닥 가운데)에서 MeshPart 가운데까지 (Roblox 좌표, 1배). 앞 = Roblox +Z 쪽이 아니라 Blender -Y → Roblox -Z.")
with open(os.path.join(OUT, f"cozy_stage{STAGE}_parts.txt"), "w", encoding="utf-8") as f:
    f.write("\n".join(rows) + "\n")
print("\n".join(rows))

for o in objs:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, f"dalgona_cozy_stage{STAGE}.glb"), export_format="GLB", use_selection=True, export_apply=True)

# ───────────── 미리 보기 ─────────────
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (1.0, 0.86, 0.7, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.55
scene.world = world
bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
fm = bpy.data.materials.new("Floor")
fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.55, 0.5, 0.46, 1)
bpy.context.active_object.data.materials.append(fm)
bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 3.5, 6))
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
pt = bpy.data.objects.new("Pt", bpy.data.lights.new("Pt", "POINT"))
pt.data.energy = 60
pt.data.color = (1.0, 0.8, 0.55)
pt.location = (0, -3, 6)
scene.collection.objects.link(pt)
emit = bpy.data.materials.new("Glow")
emit.use_nodes = True
eb = emit.node_tree.nodes["Principled BSDF"]
eb.inputs["Base Color"].default_value = (1, 0.85, 0.6, 1)
eb.inputs["Emission Color"].default_value = (1, 0.8, 0.5, 1)
eb.inputs["Emission Strength"].default_value = 4
glass = bpy.data.materials.new("GlassPrev")
glass.use_nodes = True
gb = glass.node_tree.nodes["Principled BSDF"]
gb.inputs["Base Color"].default_value = (0.85, 0.95, 0.95, 1)
gb.inputs["Alpha"].default_value = 0.25
glass.surface_render_method = "BLENDED"
for o in objs:
    if o.name.endswith("_Lamp"):
        o.data.materials[0] = emit
    if o.name.endswith("_Jars") or o.name.endswith("_Jar") or o.name.endswith("_Glass"):
        o.data.materials[0] = glass
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.lens = 35
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 1400, 1100
scene.view_settings.view_transform = "Standard"
loc, tgt = info["cam"]
cam.location = loc
cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
scene.render.filepath = os.path.join(OUT, f"cozy_stage{STAGE}_preview.png")
bpy.ops.render.render(write_still=True)
print(f"[cozy_stage{STAGE}] done")
