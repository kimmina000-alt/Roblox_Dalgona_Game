# 달고나 사러 오는 손님 NPC 7종 (사용자 디자인 2026-11-22: 동물 손님 그림 2장)
#   뽀글이(갈색 푸들, 버건디 베레모, 동그란 안경), 꿀단지(노란 곰), 설기(옛 모찌, 흰 토끼, 세라복·하늘 치마·분홍 리본),
#   고등어 아저씨(회색 고등어 무늬 고양이, 흰 수염, 러닝셔츠, 초록 운동복 바지), 도토리(회색 다람쥐, 남색 모자·제복, 갈색 가방),
#   부엉이(보라 부엉이, 머리 위 초승달, 별무늬 남색 망토), 퐁퐁이(노란 오리, 하늘색 벙거지·원피스, 병아리 가방)
#
# 리깅 = 부품 나눔 (스킨드 메시 아님). 이유: 판매 코드(SalesService)는 손님을 Humanoid 없이 Anchored 부품으로 만들고
#   서버가 매 프레임 부품 CFrame을 직접 놓는다 (폰 부담). 그래서 손님 1명 = MeshPart 6개
#   Head(얼굴·귀·모자 포함) / Body(몸·옷·꼬리·망토) / ArmL / ArmR / LegL / LegR.
#   팔·다리는 똑바로 아래로 늘어진 모양이라 지금 코드처럼 "가운데 + Size.Y" 로 팔을 놓아도 맞고,
#   관절(어깨·엉덩이·목) 자리를 CustomerRig.lua에 적어 두어 그 점을 중심으로 돌리면 걷기·먹기가 된다.
#
# 색 = 팔레트 텍스처 한 장 (16×16 칸, 칸마다 살짝 펠트 결). 모든 부품이 같은 텍스처를 쓰고 UV가 칸 가운데를 가리킨다.
#   (glb의 여러 재질·정점 색 대신 — Roblox MeshPart는 텍스처 1장이라)
#
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/customers.py -- <출력 폴더(절대 경로)> [저장소 루트]
# 결과: <출력>/dalgona_customers.glb (손님마다 빈 노드 Customer_<id> 아래 <id>_Head ... 메시),
#       customers_preview.png (서 있는 모습), customers_preview2.png (걷기·먹기 자세, 비스듬히),
#       customers_parts.txt, 저장소 루트를 주면 src/shared/CustomerRig.lua (자동 생성)
# 크기 = 게임 stud. 손님마다 원점 = 두 발 가운데 바닥. 앞 = Blender -Y (Roblox로 가져오면 -Z, 즉 LookVector 쪽).
# 좌표 변환 Blender (x, y, z) → Roblox (-x, z, y). 왼쪽 = Blender +X = Roblox -X.

import math
import os
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else ".")
REPO = os.path.abspath(argv[1]) if len(argv) > 1 else None
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# ───────────── 팔레트 ─────────────
PALETTE, PIDX = [], {}
GRID = 16  # 16×16 = 256색


def C(rgb):
    key = tuple(int(v) for v in rgb)
    if key not in PIDX:
        PIDX[key] = len(PALETTE)
        PALETTE.append(key)
        assert len(PALETTE) <= GRID * GRID, "팔레트 칸이 모자람"
    return PIDX[key]


def swatch_uv(i):
    return ((i % GRID) + 0.5) / GRID, ((i // GRID) + 0.5) / GRID


def palette_image():
    cell = 16
    size = cell * GRID
    arr = np.ones((size, size, 3))
    for i, rgb in enumerate(PALETTE):
        cx, cy = i % GRID, i // GRID
        base = np.array(rgb) / 255
        noise = rng.normal(0, 0.018, (cell, cell, 1))  # 펠트 결
        arr[cy * cell:(cy + 1) * cell, cx * cell:(cx + 1) * cell] = base + noise
    img = bpy.data.images.new("CustomerPalette", size, size, alpha=False)
    rgba = np.ones((size, size, 4), dtype=np.float32)
    rgba[:, :, :3] = np.clip(arr, 0, 1) ** 2.2
    img.pixels.foreach_set(rgba.ravel())  # 행 0 = 아래 (UV v와 같은 방향)
    img.pack()
    return img


# ───────────── 도형 (부품 bmesh에 쌓음) ─────────────
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


def V(*a):
    return Vector(a[0]) if len(a) == 1 else Vector(a)


def sph(p, c, r, rgb, seg=(16, 10), keep=None, m=I4):
    """타원구. r = 반지름(숫자 또는 (x, y, z)). keep(로컬 단위 좌표) 가 False인 정점은 지움 (껍데기 모양)."""
    r = (r, r, r) if isinstance(r, (int, float)) else r
    M = Matrix.Translation(V(c)) @ m @ Matrix.Diagonal((*r, 1))
    res = bmesh.ops.create_uvsphere(p.bm, u_segments=seg[0], v_segments=seg[1], radius=1.0, matrix=M)
    if keep:
        Mi = M.inverted()
        dead = [v for v in res["verts"] if not keep(Mi @ v.co)]
        if dead:
            bmesh.ops.delete(p.bm, geom=dead, context="VERTS")
    p.paint(rgb)


def cyl(p, a, b, r0, r1, rgb, seg=14):
    a, b = V(a), V(b)
    d = b - a
    R = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    M = Matrix.Translation((a + b) / 2) @ R
    bmesh.ops.create_cone(p.bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r0, radius2=r1, depth=d.length, matrix=M)
    p.paint(rgb)


def rbox(p, c, size, rgb, bev, m=I4):
    M = Matrix.Translation(V(c)) @ m @ Matrix.Diagonal((*size, 1))
    res = bmesh.ops.create_cube(p.bm, size=1.0, matrix=M)
    vs = res["verts"]
    es = list({e for v in vs for e in v.link_edges})
    if bev > 0:
        bmesh.ops.bevel(p.bm, geom=vs + es, offset=bev, offset_type="OFFSET", segments=4, profile=0.5, affect="EDGES", clamp_overlap=True)
    p.paint(rgb)


def torus(p, c, R, r, rgb, m=I4, a0=0.0, a1=360.0, useg=28, vseg=8, taper=False):
    """XZ 면(앞 -Y를 봄)에 놓인 고리. a0~a1 도 = 호. taper면 가운데가 두꺼운 초승달 단면."""
    closed = abs(a1 - a0) >= 359.9
    n = useg if closed else useg + 1
    M = Matrix.Translation(V(c)) @ m
    rings = []
    for i in range(n):
        t = i / useg
        u = math.radians(a0 + (a1 - a0) * t)
        rr = r * (0.15 + 0.85 * math.sin(math.pi * t)) if taper else r
        cu, su = math.cos(u), math.sin(u)
        ring = []
        for j in range(vseg):
            w = 2 * math.pi * j / vseg
            rad = R + rr * math.cos(w)
            ring.append(p.bm.verts.new(M @ Vector((rad * cu, rr * math.sin(w), rad * su))))
        rings.append(ring)
    faces = []
    pairs = list(zip(rings, rings[1:])) + ([(rings[-1], rings[0])] if closed else [])
    for A, B in pairs:
        for j in range(vseg):
            j2 = (j + 1) % vseg
            faces.append(p.bm.faces.new((A[j], B[j], B[j2], A[j2])))
    if not closed:
        faces.append(p.bm.faces.new(list(reversed(rings[0]))))
        faces.append(p.bm.faces.new(rings[-1]))
    bmesh.ops.recalc_face_normals(p.bm, faces=faces)
    p.paint(rgb)


def fib(n):
    g = math.pi * (3 - math.sqrt(5))
    for i in range(n):
        z = 1 - 2 * (i + 0.5) / n
        rr = math.sqrt(1 - z * z)
        yield Vector((math.cos(g * i) * rr, math.sin(g * i) * rr, z))


# ───────────── 손님 공통 몸 ─────────────
class Char:
    def __init__(self, cid, label, **s):
        self.id, self.label, self.s = cid, label, s
        self.parts = {n: Part(n) for n in ("Head", "Body", "ArmL", "ArmR", "LegL", "LegR")}
        s.setdefault("foot", (s["leg_r"] * 1.1, s["leg_r"] * 1.5, 0.15))
        self.hip = s["leg"]
        self.neck = self.hip + s["torso_h"]
        self.hr = s["hr"]
        self.hcz = self.neck + self.hr[2] * 0.82
        self.shz = self.neck - s["arm_r"] * 1.1
        self.shx = s["torso_w"] / 2 + s["arm_r"] * 0.55
        self.hipx = s["torso_w"] * 0.24
        self.joints = {
            "Head": Vector((0, 0, self.neck)),
            "Body": Vector((0, 0, self.hip)),
            "ArmL": Vector((self.shx, 0, self.shz)),
            "ArmR": Vector((-self.shx, 0, self.shz)),
            "LegL": Vector((self.hipx, 0, self.hip)),
            "LegR": Vector((-self.hipx, 0, self.hip)),
        }

    def P(self, n):
        return self.parts[n]

    def fp(self, x, z, out=0.0):
        """머리 앞면 위의 점 (x = 옆, z = 머리 가운데 기준 높이)."""
        rx, ry, rz = self.hr
        t = 1 - (x / rx) ** 2 - (z / rz) ** 2
        return Vector((x, -ry * math.sqrt(max(t, 0.0)) - out, self.hcz + z))

    def body(self, fur, torso, legc, foot, sleeve=None, sleeve_len=0.0, paw=None, egg=False, head=True):
        s = self.s
        for side, sx in (("L", 1), ("R", -1)):
            x = sx * self.hipx
            leg = self.P("Leg" + side)
            fr = s["foot"]
            cyl(leg, (x, 0, self.hip + 0.06), (x, 0, fr[2] * 0.9), s["leg_r"], s["leg_r"] * 0.93, legc)
            sph(leg, (x, -fr[1] * 0.3, fr[2]), fr, foot, seg=(14, 8))
            x = sx * self.shx
            arm = self.P("Arm" + side)
            top, bot = self.shz, self.shz - s["arm_len"]
            ar = s["arm_r"]
            if sleeve:
                sph(arm, (x, 0, top), ar * 1.18, sleeve, seg=(12, 8))
                cyl(arm, (x, 0, top), (x, 0, top - sleeve_len), ar * 1.16, ar * 1.12, sleeve)
            else:
                sph(arm, (x, 0, top), ar * 1.03, fur, seg=(12, 8))
            cyl(arm, (x, 0, top), (x, 0, bot + ar), ar, ar * 0.95, fur)
            sph(arm, (x, -0.02, bot + ar * 1.1), (ar * 1.22, ar * 1.15, ar * 1.15), paw or fur, seg=(12, 8))
        b = self.P("Body")
        w, d, h = s["torso_w"], s["torso_d"], s["torso_h"]
        if egg:
            sph(b, (0, 0, self.hip + h * 0.5), (w / 2, d / 2, h * 0.56), torso, seg=(24, 14))
        else:
            rbox(b, (0, 0, self.hip + h / 2), (w, d, h), torso, min(w, d) * 0.42)
        if head:
            sph(self.P("Head"), (0, 0, self.hcz), self.hr, fur, seg=(28, 18))

    # 얼굴 소품
    def dot_eyes(self, gap, z, r=(0.075, 0.045, 0.095), shine=True):
        h = self.P("Head")
        for sx in (1, -1):
            c = self.fp(sx * gap, z, -0.015)
            sph(h, c, r, (40, 30, 34), seg=(10, 8))
            if shine:
                sph(h, c + Vector((sx * -0.02, -0.035, r[2] * 0.4)), 0.022, (255, 255, 255), seg=(6, 4))

    def happy_eyes(self, gap, z, R=0.075):
        h = self.P("Head")
        for sx in (1, -1):
            c = self.fp(sx * gap, z, -0.005)
            torus(h, c, R, 0.022, (45, 32, 36), m=rot(x=0, y=0, z=sx * 12) @ rot(x=0), a0=20, a1=160, useg=10, vseg=6)

    def blush(self, gap, z, r=(0.12, 0.03, 0.07)):
        for sx in (1, -1):
            sph(self.P("Head"), self.fp(sx * gap, z, -0.01), r, (255, 165, 175), seg=(10, 6))

    def smile(self, z, w=0.09, color=(190, 70, 85), tongue=True):
        h = self.P("Head")
        c = self.fp(0, z, -0.02)
        sph(h, c, (w, 0.04, w * 0.75), color, seg=(10, 6), keep=lambda q: q.z < 0.25)
        if tongue:
            sph(h, c + Vector((0, -0.012, -w * 0.3)), (w * 0.55, 0.03, w * 0.35), (255, 140, 150), seg=(8, 6))

    def build(self, mat):
        root = bpy.data.objects.new("Customer_" + self.id, None)
        scene.collection.objects.link(root)
        self.objs = {}
        self.boxes = {}
        for n, p in self.parts.items():
            bm = p.bm
            uv = bm.loops.layers.uv.verify()
            for f in bm.faces:
                u, v = swatch_uv(max(f[p.col] - 1, 0))
                for l in f.loops:
                    l[uv].uv = (u, v)
            lo = Vector([min(v.co[i] for v in bm.verts) for i in range(3)])
            hi = Vector([max(v.co[i] for v in bm.verts) for i in range(3)])
            c = (lo + hi) / 2
            bmesh.ops.translate(bm, verts=bm.verts, vec=-c)
            me = bpy.data.meshes.new(f"{self.id}_{n}")
            bm.normal_update()
            bm.to_mesh(me)
            bm.free()
            for poly in me.polygons:
                poly.use_smooth = True
            me.materials.append(mat)
            o = bpy.data.objects.new(f"{self.id}_{n}", me)
            scene.collection.objects.link(o)
            o.parent = root
            o.location = c
            self.objs[n] = o
            self.boxes[n] = (c, hi - lo)
        self.root = root
        return root

    def pose(self, rots):
        """rots[부품] = 회전 행렬 (관절 중심). 미리 보기용."""
        for n, R in rots.items():
            j = self.joints[n]
            c, _ = self.boxes[n]
            self.objs[n].matrix_basis = Matrix.Translation(j) @ R @ Matrix.Translation(c - j)


# ───────────── 손님들 ─────────────
def ppogeuli():
    ch = Char("Ppogeuli", "뽀글이", leg=0.95, torso_h=1.15, torso_w=1.2, torso_d=0.95, hr=(0.78, 0.72, 0.72),
              arm_len=1.0, arm_r=0.2, leg_r=0.24, foot=(0.25, 0.32, 0.16))
    FUR, CURL, MUZ = (182, 118, 82), (160, 100, 68), (206, 152, 116)
    ch.body(FUR, FUR, FUR, CURL)
    h, b = ch.P("Head"), ch.P("Body")
    # 2026-11-22 사용자: 겉에 붙은 곱슬 방울은 지우고 정돈 → 뒤로 부푼 머리털 덩어리 하나 + 길게 늘어진 귀
    sph(h, (0, 0.12, ch.hcz + 0.2), (0.84, 0.72, 0.62), CURL, seg=(24, 14))
    for sx in (1, -1):
        sph(h, (sx * 0.82, 0.06, ch.hcz - 0.15), (0.2, 0.2, 0.42), CURL, seg=(14, 10))
    # 주둥이·코·입
    sph(h, ch.fp(0, -0.22, 0.12), (0.3, 0.2, 0.22), MUZ, seg=(14, 10))
    sph(h, ch.fp(0, -0.12, 0.3), (0.09, 0.06, 0.07), (60, 36, 32), seg=(10, 6))
    ch.smile(-0.38, w=0.08)
    ch.dot_eyes(0.27, 0.08)
    # 동그란 안경
    GL = (92, 56, 42)
    for sx in (1, -1):
        c = ch.fp(sx * 0.27, 0.08, 0.07)
        torus(h, c, 0.17, 0.026, GL, m=rot(z=sx * 8))
        cyl(h, c + Vector((sx * 0.17, 0, 0)), Vector((sx * ch.hr[0] * 0.95, 0.1, ch.hcz + 0.1)), 0.02, 0.02, GL, seg=6)
    cyl(h, ch.fp(0.1, 0.1, 0.1), ch.fp(-0.1, 0.1, 0.1), 0.02, 0.02, GL, seg=6)
    # 베레모
    sph(h, (0.1, 0.06, ch.hcz + ch.hr[2] * 0.92), (0.78, 0.74, 0.22), (138, 38, 56), seg=(24, 12), m=rot(y=14, x=-6))
    cyl(h, (0.14, 0.06, ch.hcz + ch.hr[2] * 1.08), (0.16, 0.06, ch.hcz + ch.hr[2] * 1.08 + 0.13), 0.04, 0.03, (120, 30, 46), seg=8)
    # 흰 칼라
    torus(b, (0, 0, ch.neck - 0.03), 0.42, 0.08, (250, 246, 240), m=rot(x=90), vseg=8)
    # 동그란 꼬리
    d = ch.s["torso_d"]
    sph(b, (0, d * 0.5 + 0.18, ch.hip + 0.3), 0.22, CURL, seg=(12, 8))
    ch.mouth = ch.fp(0, -0.38, 0.05)
    return ch


def kkuldanji():
    ch = Char("Kkuldanji", "꿀단지", leg=0.75, torso_h=1.0, torso_w=1.15, torso_d=0.9, hr=(0.78, 0.7, 0.7),
              arm_len=0.85, arm_r=0.21, leg_r=0.25, foot=(0.26, 0.33, 0.16))
    FUR, LIGHT, IN = (250, 205, 70), (255, 232, 155), (240, 170, 70)
    ch.body(FUR, FUR, FUR, FUR, paw=FUR)
    h, b = ch.P("Head"), ch.P("Body")
    for sx in (1, -1):
        sph(h, (sx * 0.56, 0.05, ch.hcz + 0.5), (0.25, 0.14, 0.25), FUR, seg=(14, 8))
        sph(h, (sx * 0.56, -0.05, ch.hcz + 0.49), (0.15, 0.06, 0.15), IN, seg=(10, 6))
    sph(h, ch.fp(0, -0.22, 0.1), (0.3, 0.2, 0.21), LIGHT, seg=(14, 10))
    sph(h, ch.fp(0, -0.12, 0.27), (0.09, 0.06, 0.065), (84, 52, 38), seg=(10, 6))
    ch.smile(-0.36, w=0.1)
    ch.dot_eyes(0.27, 0.1, r=(0.08, 0.05, 0.1))
    ch.blush(0.45, -0.12)
    for k, x in enumerate((-0.12, 0.0, 0.12)):  # 앞머리 털
        sph(h, ch.fp(x, 0.52, -0.02), (0.1, 0.08, 0.1), FUR, seg=(8, 6))
    # 배
    sph(b, (0, -ch.s["torso_d"] * 0.36, ch.hip + 0.45), (0.38, 0.12, 0.38), LIGHT, seg=(14, 10))
    sph(b, (0, ch.s["torso_d"] * 0.5 + 0.08, ch.hip + 0.25), 0.16, FUR, seg=(10, 8))
    ch.mouth = ch.fp(0, -0.36, 0.05)
    return ch


def mochi():
    ch = Char("Mochi", "설기", leg=0.85, torso_h=1.05, torso_w=1.0, torso_d=0.8, hr=(0.72, 0.66, 0.68),
              arm_len=0.9, arm_r=0.18, leg_r=0.2, foot=(0.21, 0.33, 0.15))
    FUR, PINK, BLUE, WHITE = (252, 248, 246), (255, 186, 204), (164, 204, 238), (250, 251, 255)
    ch.body(FUR, WHITE, FUR, FUR, sleeve=WHITE, sleeve_len=0.32)
    h, b = ch.P("Head"), ch.P("Body")
    for sx in (1, -1):  # 긴 귀
        m = rot(y=-sx * 10)
        c = Vector((sx * 0.27, 0.06, ch.hcz + ch.hr[2] + 0.42))
        sph(h, c, (0.17, 0.11, 0.56), FUR, seg=(14, 10), m=m)
        sph(h, c + Vector((0, -0.07, 0.02)), (0.09, 0.05, 0.42), PINK, seg=(10, 8), m=m)
    # 리본
    RB = (255, 140, 178)
    rc = Vector((0.42, -0.02, ch.hcz + ch.hr[2] * 0.82))
    for sx in (1, -1):
        sph(h, rc + Vector((sx * 0.15, 0, 0)), (0.15, 0.06, 0.1), RB, seg=(10, 6), m=rot(z=0, y=sx * 15))
    sph(h, rc, 0.06, RB, seg=(8, 6))
    ch.happy_eyes(0.25, 0.06)
    ch.blush(0.42, -0.1)
    sph(h, ch.fp(0, -0.08, 0.0), (0.05, 0.03, 0.035), (240, 140, 160), seg=(8, 6))
    ch.smile(-0.24, w=0.1)
    # 세라복 깃 + 스카프
    w, d = ch.s["torso_w"], ch.s["torso_d"]
    sph(b, (0, 0.02, ch.neck - 0.05), (w * 0.58, d * 0.62, 0.32), BLUE, seg=(24, 12),
        keep=lambda q: q.z > -0.2 and not (q.y < -0.2 and abs(q.x) < 0.5))
    sc = Vector((0, -d * 0.5 - 0.02, ch.neck - 0.26))
    sph(b, sc, (0.1, 0.07, 0.08), PINK, seg=(10, 6))
    for sx in (1, -1):
        sph(b, sc + Vector((sx * 0.08, -0.02, -0.16)), (0.07, 0.04, 0.16), PINK, seg=(8, 6), m=rot(y=sx * 20))
    # 하늘 주름치마
    cyl(b, (0, 0, ch.hip + 0.28), (0, 0, ch.hip - 0.28), w * 0.52, w * 0.74, BLUE, seg=16)
    sph(b, (0, d * 0.5 + 0.22, ch.hip - 0.05), 0.18, FUR, seg=(10, 8))
    ch.mouth = ch.fp(0, -0.24, 0.05)
    return ch


def godeungeo():
    ch = Char("Godeungeo", "고등어 아저씨", leg=1.05, torso_h=1.3, torso_w=1.3, torso_d=1.0, hr=(0.8, 0.72, 0.7),
              arm_len=1.1, arm_r=0.22, leg_r=0.28, foot=(0.27, 0.34, 0.16))
    FUR, DARK, WHITE, PINK, GREEN = (152, 152, 160), (104, 104, 114), (246, 246, 244), (240, 160, 170), (72, 152, 88)
    ch.body(FUR, WHITE, GREEN, FUR)
    h, b = ch.P("Head"), ch.P("Body")
    for sx in (1, -1):  # 뾰족 귀
        cyl(h, (sx * 0.48, 0.02, ch.hcz + 0.38), (sx * 0.64, 0.06, ch.hcz + 0.86), 0.27, 0.02, FUR, seg=12)
        cyl(h, (sx * 0.47, -0.08, ch.hcz + 0.42), (sx * 0.6, -0.04, ch.hcz + 0.76), 0.16, 0.01, PINK, seg=10)
    for x in (-0.16, 0, 0.16):  # 이마 줄무늬
        sph(h, ch.fp(x, 0.5, -0.03), (0.05, 0.05, 0.13), DARK, seg=(8, 6))
    for sx in (1, -1):  # 옆 줄무늬
        sph(h, (sx * ch.hr[0] * 0.95, 0.0, ch.hcz + 0.05), (0.06, 0.25, 0.05), DARK, seg=(8, 6))
    # 심술 눈: 노란 눈 + 세로 동공 + 눈꺼풀 + 처진 눈썹
    for sx in (1, -1):
        c = ch.fp(sx * 0.28, 0.06, -0.02)
        sph(h, c, (0.13, 0.05, 0.1), (242, 212, 80), seg=(12, 8))
        sph(h, c + Vector((sx * -0.02, -0.03, -0.01)), (0.035, 0.03, 0.08), (36, 30, 30), seg=(8, 6))
        sph(h, c + Vector((0, -0.012, 0.035)), (0.145, 0.065, 0.075), FUR, seg=(12, 8), keep=lambda q: q.z > -0.1)
        rbox(h, c + Vector((sx * 0.02, -0.06, 0.13)), (0.24, 0.06, 0.05), (235, 235, 235), 0.02, m=rot(y=sx * 18))
    # 흰 주둥이 + 분홍 코 + 수염 + 턱수염
    for sx in (1, -1):
        sph(h, ch.fp(sx * 0.11, -0.22, 0.06), (0.16, 0.12, 0.12), WHITE, seg=(12, 8))
        sph(h, ch.fp(sx * 0.26, -0.27, 0.05), (0.2, 0.06, 0.06), WHITE, seg=(10, 6), m=rot(y=sx * 20))
    sph(h, ch.fp(0, -0.14, 0.16), (0.07, 0.05, 0.05), PINK, seg=(8, 6))
    sph(h, (0, -ch.hr[1] * 0.72, ch.hcz - ch.hr[2] * 0.62), (0.24, 0.16, 0.2), WHITE, seg=(12, 8))
    sph(h, (0, -ch.hr[1] * 0.8, ch.hcz - ch.hr[2] * 0.85), (0.1, 0.08, 0.12), WHITE, seg=(8, 6))
    # 러닝셔츠(흰 몸) 아래 초록 운동복 허리 + 끈 + 바지 흰 줄
    w, d = ch.s["torso_w"], ch.s["torso_d"]
    rbox(b, (0, 0, ch.hip + 0.18), (w * 1.03, d * 1.03, 0.5), GREEN, min(w, d) * 0.4)
    for sx in (1, -1):
        cyl(b, (sx * 0.06, -d * 0.52, ch.hip + 0.3), (sx * 0.08, -d * 0.53, ch.hip + 0.06), 0.022, 0.022, WHITE, seg=6)
        leg = ch.P("LegL" if sx > 0 else "LegR")
        x = sx * (ch.hipx + ch.s["leg_r"] * 0.92)
        cyl(leg, (x, 0, ch.hip), (x, 0, 0.3), 0.04, 0.04, WHITE, seg=6)
    # 꼬리 (줄무늬 고리)
    for k in range(9):
        t = k / 8
        sph(b, (0.15 * math.sin(t * 2.5), d * 0.5 + 0.1 + 0.35 * math.sin(t * 1.4), ch.hip + 0.1 + 0.9 * t), 0.11, DARK if k % 2 else FUR, seg=(10, 6))
    ch.mouth = ch.fp(0, -0.32, 0.05)
    return ch


def dotori():
    ch = Char("Dotori", "도토리", leg=0.75, torso_h=1.0, torso_w=1.0, torso_d=0.8, hr=(0.7, 0.64, 0.64),
              arm_len=0.85, arm_r=0.17, leg_r=0.2, foot=(0.2, 0.3, 0.14))
    FUR, LIGHT, NAVY, GOLD, BROWN = (152, 152, 164), (228, 228, 234), (62, 84, 148), (244, 204, 84), (156, 104, 64)
    ch.body(FUR, NAVY, FUR, (120, 120, 132), sleeve=NAVY, sleeve_len=0.65)
    h, b = ch.P("Head"), ch.P("Body")
    for sx in (1, -1):
        cyl(h, (sx * 0.42, 0.06, ch.hcz + 0.36), (sx * 0.52, 0.08, ch.hcz + 0.7), 0.15, 0.02, FUR, seg=10)
    sph(h, ch.fp(0, -0.18, 0.06), (0.38, 0.2, 0.25), LIGHT, seg=(14, 10))
    sph(h, ch.fp(0, -0.08, 0.22), (0.06, 0.04, 0.045), (50, 40, 44), seg=(8, 6))
    ch.smile(-0.28, w=0.075)
    ch.dot_eyes(0.25, 0.1)
    ch.blush(0.4, -0.12)
    # 남색 모자 (집배원)
    cz = ch.hcz + ch.hr[2] * 0.55
    cyl(h, (0, 0.03, cz), (0, 0.03, cz + 0.34), 0.58, 0.66, NAVY, seg=20)
    sph(h, (0, 0.03, cz + 0.34), (0.68, 0.66, 0.09), NAVY, seg=(20, 8))
    sph(h, (0, -0.48, cz + 0.02), (0.46, 0.3, 0.05), (38, 44, 72), seg=(16, 8), keep=lambda q: q.y < 0.2)
    sph(h, (0, -0.56, cz + 0.2), (0.08, 0.03, 0.08), GOLD, seg=(8, 6))
    # 제복 단추 + 가방 + 끈 + 편지
    w, d = ch.s["torso_w"], ch.s["torso_d"]
    for k in range(3):
        sph(b, (0, -d * 0.5 - 0.01, ch.hip + 0.25 + k * 0.25), 0.045, GOLD, seg=(8, 6))
    bag = Vector((w * 0.5 + 0.12, -0.12, ch.hip + 0.2))
    rbox(b, bag, (0.22, 0.6, 0.48), BROWN, 0.06)
    rbox(b, bag + Vector((-0.01, -0.02, 0.18)), (0.25, 0.63, 0.16), (132, 86, 52), 0.05)
    for k in range(2):
        rbox(b, bag + Vector((0, -0.08 + k * 0.16, 0.3)), (0.04, 0.2, 0.22), (252, 250, 244), 0.01, m=rot(x=12 - k * 20))
    cyl(b, (-w * 0.42, -d * 0.48, ch.neck - 0.05), (w * 0.5, -d * 0.48, ch.hip + 0.35), 0.035, 0.035, BROWN, seg=6)
    # 큰 꼬리
    for k in range(14):
        t = k / 13
        y = d * 0.5 + 0.25 + 0.45 * math.sin(t * math.pi * 0.9)
        z = ch.hip + 0.05 + 1.9 * t
        if t > 0.75:  # 끝에서 앞으로 말림
            y -= (t - 0.75) * 1.4
        sph(b, (0, y, z), 0.24 + 0.16 * math.sin(t * math.pi), (184, 184, 198) if k % 3 else (140, 140, 154), seg=(12, 8))
    ch.mouth = ch.fp(0, -0.28, 0.05)
    return ch


def owl():
    ch = Char("Owl", "부엉이", leg=0.5, torso_h=1.35, torso_w=1.4, torso_d=1.1, hr=(0.85, 0.74, 0.72),
              arm_len=1.0, arm_r=0.22, leg_r=0.12, foot=(0.26, 0.3, 0.09))
    PURP, BELLY, CAPE, STAR, BEAK = (160, 118, 206), (198, 172, 232), (56, 66, 138), (250, 216, 92), (250, 172, 62)
    ch.body(PURP, PURP, BEAK, BEAK, paw=(130, 92, 180), egg=True)
    h, b = ch.P("Head"), ch.P("Body")
    for side, sx in (("L", 1), ("R", -1)):  # 발가락
        for k in (-1, 0, 1):
            sph(ch.P("Leg" + side), (sx * ch.hipx + k * 0.1, -0.3, 0.06), (0.06, 0.1, 0.05), BEAK, seg=(8, 6))
    for sx in (1, -1):  # 귀깃
        cyl(h, (sx * 0.52, 0.04, ch.hcz + 0.4), (sx * 0.78, 0.06, ch.hcz + 0.8), 0.2, 0.02, PURP, seg=10)
    # 큰 눈 (반쯤 감은)
    for sx in (1, -1):
        c = ch.fp(sx * 0.3, 0.05, -0.04)
        sph(h, c, (0.25, 0.07, 0.24), (238, 224, 250), seg=(16, 10))
        sph(h, c + Vector((0, -0.04, -0.03)), (0.15, 0.05, 0.14), (240, 186, 70), seg=(12, 8))
        sph(h, c + Vector((sx * -0.02, -0.07, -0.03)), (0.075, 0.03, 0.08), (40, 30, 40), seg=(8, 6))
        sph(h, c + Vector((0, -0.02, 0.02)), (0.27, 0.1, 0.25), (122, 86, 176), seg=(16, 10), keep=lambda q: q.z > 0.12)
    cyl(h, ch.fp(0, -0.02, -0.05), ch.fp(0, -0.24, 0.12), 0.11, 0.01, BEAK, seg=8)
    # 머리 위 초승달
    torus(h, (0, 0.04, ch.hcz + ch.hr[2] + 0.36), 0.26, 0.11, (246, 232, 168), a0=60, a1=330, taper=True, useg=22)
    # 배 깃털
    sph(b, (0, -ch.s["torso_d"] * 0.36, ch.hip + 0.6), (0.45, 0.14, 0.5), BELLY, seg=(14, 10))
    for k in range(3):
        for j in range(3 - k % 2):
            sph(b, (-0.2 + j * 0.2 + (k % 2) * 0.1, -ch.s["torso_d"] * 0.47, ch.hip + 0.35 + k * 0.25), (0.07, 0.03, 0.05), (178, 148, 220), seg=(8, 6))
    # 별무늬 망토 (앞은 열림) + 달 잠금
    w, d, hh = ch.s["torso_w"], ch.s["torso_d"], ch.s["torso_h"]
    cc = Vector((0, 0.04, ch.hip + hh * 0.52))
    rad = (w * 0.56, d * 0.6, hh * 0.62)
    keep = lambda q: q.z > -0.9 and not (q.y < -0.3 and abs(q.x) < 0.5)
    sph(b, cc, rad, CAPE, seg=(28, 16), keep=keep)
    for q in fib(40):
        if not keep(q) or q.z > 0.85 or q.z < -0.8:
            continue
        sph(b, cc + Vector((q.x * rad[0], q.y * rad[1], q.z * rad[2])) * 1.0, (0.05, 0.05, 0.05), STAR, seg=(6, 4))
    torus(b, (0, -d * 0.45, ch.neck - 0.12), 0.08, 0.035, STAR, a0=60, a1=330, taper=True, useg=12)
    ch.mouth = ch.fp(0, -0.24, 0.05)
    return ch


def pongpong():
    ch = Char("Pongpong", "퐁퐁이", leg=0.6, torso_h=1.0, torso_w=1.0, torso_d=0.85, hr=(0.72, 0.66, 0.66),
              arm_len=0.8, arm_r=0.18, leg_r=0.1, foot=(0.26, 0.38, 0.08))
    YEL, ORA, BLUE, HAT = (255, 226, 92), (255, 158, 60), (170, 208, 238), (150, 192, 228)
    ch.body(YEL, BLUE, ORA, ORA, sleeve=BLUE, sleeve_len=0.28)
    h, b = ch.P("Head"), ch.P("Body")
    # 부리 (웃는 입)
    sph(h, ch.fp(0, -0.14, 0.12), (0.32, 0.26, 0.1), ORA, seg=(14, 8))
    sph(h, ch.fp(0, -0.28, 0.08), (0.24, 0.2, 0.08), (240, 130, 50), seg=(12, 8))
    sph(h, ch.fp(0, -0.21, 0.14), (0.16, 0.12, 0.04), (180, 70, 70), seg=(10, 6))
    ch.happy_eyes(0.26, 0.1)
    ch.blush(0.42, -0.08)
    # 하늘색 벙거지
    top = ch.hcz + ch.hr[2] * 0.5
    cyl(h, (0, 0, top - 0.05), (0, 0, top + 0.38), 0.68, 0.6, HAT, seg=20)
    sph(h, (0, 0, top + 0.38), (0.6, 0.6, 0.14), HAT, seg=(20, 8))
    cyl(h, (0, 0, top - 0.08), (0, 0, top + 0.06), 0.98, 0.7, HAT, seg=24)
    cyl(h, (0, 0, top + 0.05), (0, 0, top + 0.15), 0.67, 0.65, (118, 160, 204), seg=20)
    # 흰 깃 + 병아리 가방
    w, d = ch.s["torso_w"], ch.s["torso_d"]
    torus(b, (0, 0, ch.neck - 0.04), 0.36, 0.07, (252, 252, 250), m=rot(x=90))
    cyl(b, (0, 0, ch.hip + 0.35), (0, 0, ch.hip - 0.15), w * 0.5, w * 0.66, BLUE, seg=16)
    bag = Vector((-w * 0.5 - 0.1, -0.15, ch.hip + 0.05))
    sph(b, bag, 0.22, YEL, seg=(12, 8))
    sph(b, bag + Vector((0, -0.21, 0)), (0.06, 0.04, 0.03), ORA, seg=(8, 6))
    for sx in (1, -1):
        sph(b, bag + Vector((sx * 0.08, -0.19, 0.07)), 0.025, (40, 30, 34), seg=(6, 4))
    cyl(b, (w * 0.4, -d * 0.48, ch.neck - 0.05), bag + Vector((0, 0, 0.18)), 0.03, 0.03, (120, 170, 214), seg=6)
    cyl(b, (0, d * 0.4, ch.hip + 0.2), (0, d * 0.5 + 0.25, ch.hip + 0.32), 0.14, 0.03, YEL, seg=8)  # 꼬리깃
    ch.mouth = ch.fp(0, -0.22, 0.1)
    return ch


CHARS = [ppogeuli(), kkuldanji(), mochi(), godeungeo(), dotori(), owl(), pongpong()]

# ───────────── 재질·오브젝트 ─────────────
IMG = palette_image()
MAT = bpy.data.materials.new("CustomerPalette")
MAT.use_nodes = True
nt = MAT.node_tree
bsdf = nt.nodes["Principled BSDF"]
bsdf.inputs["Roughness"].default_value = 0.85
tex = nt.nodes.new("ShaderNodeTexImage")
tex.image = IMG
tex.interpolation = "Closest"
nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])

SPACING = 2.4
for i, ch in enumerate(CHARS):
    root = ch.build(MAT)
    root.location = ((i - (len(CHARS) - 1) / 2) * SPACING, 0, 0)  # 앞(-Y)에서 볼 때 왼쪽부터 그림 순서

bpy.context.view_layer.update()


def rbx(v):
    return (-v.x, v.z, v.y)


def v3(v):
    return "Vector3.new(%.3f, %.3f, %.3f)" % rbx(v)


def size3(s):
    return "Vector3.new(%.3f, %.3f, %.3f)" % (s.x, s.z, s.y)


# 부품 목록 + 삼각형 수
lines = []
for ch in CHARS:
    tri = 0
    for n, o in ch.objs.items():
        t = sum(len(p.vertices) - 2 for p in o.data.polygons)
        tri += t
        c, s = ch.boxes[n]
        lines.append(f"{o.name}\ttris={t}\tcenter={rbx(c)}\tsize={(round(s.x, 3), round(s.z, 3), round(s.y, 3))}")
    lines.append(f"# {ch.id} ({ch.label}) total tris = {tri}, height = {max(ch.boxes[n][0].z + ch.boxes[n][1].z / 2 for n in ch.boxes):.2f}")
with open(os.path.join(OUT, "customers_parts.txt"), "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
print("\n".join(lines))

# Roblox 쪽 리그 정보 (Lua)
if REPO:
    L = ["-- 자동 생성: tools/blender/customers.py (손으로 고치지 말 것)",
         "-- 손님 NPC 7종 리그. 좌표 = 손님 Root 기준 (Root = 두 발 가운데 바닥, 앞 = -Z, 오른쪽 = +X), 단위 stud.",
         "-- parts[이름] = { center = 서 있을 때 부품(MeshPart) 가운데, size = 메시 크기, joint = 돌리는 관절 점 }",
         "--   부품 CFrame = root * CFrame.new(joint) * 회전 * CFrame.new(center - joint)",
         "--   Head = 목, Body = 엉덩이 가운데, ArmL/ArmR = 어깨, LegL/LegR = 엉덩이 관절.",
         "-- 메시는 Studio ServerStorage.Assets.Customers.Customer_<id> 안 <id>_<부품> (dalgona_customers.glb).",
         "-- mouth = 입 앞 (먹기 연출), hand = 오른손(ArmR 끝) 가운데, height = 키.",
         "", "return {", "\torder = { " + ", ".join(f'"{c.id}"' for c in CHARS) + " },", "\ttypes = {"]
    for ch in CHARS:
        height = max(ch.boxes[n][0].z + ch.boxes[n][1].z / 2 for n in ch.boxes)
        hand = Vector((-ch.shx, -0.02, ch.shz - ch.s["arm_len"] + ch.s["arm_r"] * 1.1))
        L.append(f"\t\t{ch.id} = {{")
        L.append(f'\t\t\tlabel = "{ch.label}",')
        L.append(f"\t\t\theight = {height:.3f},")
        L.append(f"\t\t\tmouth = {v3(ch.mouth)},")
        L.append(f"\t\t\thand = {v3(hand)},")
        L.append("\t\t\tparts = {")
        for n in ("Head", "Body", "ArmL", "ArmR", "LegL", "LegR"):
            c, s = ch.boxes[n]
            L.append(f"\t\t\t\t{n} = {{ center = {v3(c)}, size = {size3(s)}, joint = {v3(ch.joints[n])} }},")
        L.append("\t\t\t},")
        L.append("\t\t},")
    L += ["\t},", "}", ""]
    with open(os.path.join(REPO, "src", "shared", "CustomerRig.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L))

# ───────────── 내보내기 ─────────────
for o in scene.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "dalgona_customers.glb"), export_format="GLB", use_selection=True, export_apply=True, export_image_format="AUTO")

# ───────────── 미리 보기 ─────────────
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.98, 0.94, 0.88, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.85
scene.world = world
bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, 0))
fl = bpy.context.active_object
fm = bpy.data.materials.new("Floor")
fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.93, 0.84, 0.72, 1)
fl.data.materials.append(fm)
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.2
sun.data.angle = math.radians(12)
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-25))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.lens = 50
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 1800, 760
scene.view_settings.view_transform = "Standard"


def shoot(loc, target, name):
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)


shoot((0, -24, 4.2), (0, 0, 1.9), "customers_preview.png")

# 걷기·먹기 자세 (관절이 제대로 도는지 확인용). 짝수 = 먹기(오른팔 입으로), 홀수 = 걷기
for i, ch in enumerate(CHARS):
    if i % 2 == 0:
        ch.pose({"ArmR": rot(x=-125, y=-18), "ArmL": rot(x=12), "LegL": rot(x=-12), "LegR": rot(x=10), "Head": rot(x=8)})
    else:
        ch.pose({"LegL": rot(x=-28), "LegR": rot(x=26), "ArmL": rot(x=24), "ArmR": rot(x=-24), "Head": rot(z=-6)})
shoot((13, -18, 6.0), (0, 0, 1.6), "customers_preview2.png")
print("[customers] done")
