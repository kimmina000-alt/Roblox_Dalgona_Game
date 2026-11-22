# 달고나 사러 오는 손님 NPC 7종 (사용자 디자인 2026-11-22: 동물 손님 그림 2장, 3D 그림 기준으로 동글동글·복실복실하게)
#   뽀글이(갈색 푸들, 버건디 베레모, 동그란 안경), 꿀단지(노란 곰, 종이 왕관), 모찌(흰 토끼, 세라복·하늘 치마·분홍 리본),
#   춘식이 아저씨(회색 줄무늬 고양이, 흰 수염, 러닝셔츠, 초록 운동복 바지), 도토리(회색 다람쥐, 남색 모자·제복, 갈색 가방),
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
from mathutils import Matrix, Vector, noise

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
        """새로 생긴 면에 색. rgb가 함수면 면 가운데 위치로 색을 고름 (줄무늬·곱슬 색 얼룩)."""
        idx = None if callable(rgb) else C(rgb) + 1
        for f in self.bm.faces:
            if f[self.col] == 0:
                f[self.col] = idx or (C(rgb(f.calc_center_median())) + 1)


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


# ───────────── 동글동글 복실복실 도형 ─────────────
# 털 = 정점을 법선 방향으로 노이즈만큼 밀어냄 (세계 좌표 노이즈라 부품 사이 이음매가 없음).
#   soft = 부드러운 인형 털 결, curl = 보로노이 셀마다 볼록한 곱슬 (푸들).
SOFT = ("soft", 0.022, 8.0)  # 펠트 인형
FLUFF = ("soft", 0.034, 6.5)  # 복실한 털 (곰·토끼·오리)
FEATHER = ("soft", 0.026, 5.0)
CURLY = ("curl", 0.075, 5.2)  # 푸들 곱슬


def fluff_at(w, fl):
    if not fl:
        return 0.0
    kind, amp, freq = fl
    if kind == "soft":
        return amp * (noise.noise(w * freq) + 0.5 * noise.noise(w * freq * 2.3 + Vector((7, 3, 1))))
    d, _ = noise.voronoi(w * freq, distance_metric="DISTANCE")
    t = min(max((d[1] - d[0]) * 2.4, 0.0), 1.0)
    return amp * (math.sqrt(t) - 0.35) + 0.25 * amp * noise.noise(w * freq * 3)


def _shape(p, seg, place, rgb, fl=None, keep=None, mask=None):
    """단위 구를 만들고 place(u) → (세계 점, 법선)으로 옮긴 뒤 털 노이즈. keep(u)가 False인 정점은 지움."""
    res = bmesh.ops.create_uvsphere(p.bm, u_segments=seg[0], v_segments=seg[1], radius=1.0, matrix=I4)
    dead = []
    for v in res["verts"]:
        u = v.co.normalized()
        w, n = place(u)
        k = mask(u) if mask else 1.0
        v.co = w + n * fluff_at(w, fl) * k
        if keep and not keep(u):
            dead.append(v)
    if dead:
        bmesh.ops.delete(p.bm, geom=dead, context="VERTS")
    p.paint(rgb)


def blob(p, c, r, rgb, seg=(32, 20), m=I4, pear=0.0, fl=None, keep=None, mask=None):
    """타원구. pear > 0 이면 아래가 통통한 서양배 모양."""
    r = (r, r, r) if isinstance(r, (int, float)) else r
    c = V(c)
    R3 = m.to_3x3()

    def place(u):
        s = 1 - pear * u.z
        loc = Vector((u.x * r[0] * s, u.y * r[1] * s, u.z * r[2]))
        n = R3 @ Vector((u.x / (r[0] * s), u.y / (r[1] * s), u.z / r[2]))
        return c + R3 @ loc, n.normalized()

    _shape(p, seg, place, rgb, fl, keep, mask)


def capsule(p, a, b, r0, r1, rgb, seg=(18, 12), fl=None, flat=1.0):
    """a(반지름 r0) → b(반지름 r1) 둥근 끝 원기둥. flat < 1 이면 앞뒤(Y)로 납작 (날개)."""
    a, b = V(a), V(b)
    R3 = Vector((0, 0, 1)).rotation_difference((b - a).normalized()).to_matrix()

    def place(u):
        q = Vector((u.x, u.y * flat, u.z))
        if u.z < 0:
            return a + R3 @ (q * r0), (R3 @ u).normalized()
        return b + R3 @ (q * r1), (R3 @ u).normalized()

    _shape(p, seg, place, rgb, fl)


def lathe(p, prof, rgb, seg=40, pleats=0, depth=0.0, cap=False):
    """prof = [(r, z)...] 위에서 아래로. pleats개 주름 (치마)."""
    rings = []
    for (r, z) in prof:
        ring = []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            rr = r * (1 + depth * abs(math.sin(a * pleats / 2))) if pleats else r
            ring.append(p.bm.verts.new((math.cos(a) * rr, math.sin(a) * rr, z)))
        rings.append(ring)
    faces = []
    for A, B in zip(rings, rings[1:]):
        for k in range(seg):
            k2 = (k + 1) % seg
            faces.append(p.bm.faces.new((A[k], A[k2], B[k2], B[k])))
    if cap:
        faces.append(p.bm.faces.new(rings[-1]))
    bmesh.ops.recalc_face_normals(p.bm, faces=faces)
    p.paint(rgb)


def star(p, c, R, rgb, m=I4, thick=0.03, inner=0.45):
    """앞(-Y)을 보는 납작한 별."""
    M = Matrix.Translation(V(c)) @ m
    pts = []
    for k in range(10):
        a = math.pi / 2 + k * math.pi / 5
        rr = R if k % 2 == 0 else R * inner
        pts.append((math.cos(a) * rr, math.sin(a) * rr))
    front = [p.bm.verts.new(M @ Vector((x, -thick / 2, z))) for x, z in pts]
    back = [p.bm.verts.new(M @ Vector((x, thick / 2, z))) for x, z in pts]
    cf = p.bm.verts.new(M @ Vector((0, -thick, 0)))
    cb = p.bm.verts.new(M @ Vector((0, thick, 0)))
    faces = []
    for k in range(10):
        k2 = (k + 1) % 10
        faces.append(p.bm.faces.new((cf, front[k2], front[k])))
        faces.append(p.bm.faces.new((cb, back[k], back[k2])))
        faces.append(p.bm.faces.new((front[k], front[k2], back[k2], back[k])))
    bmesh.ops.recalc_face_normals(p.bm, faces=faces)
    p.paint(rgb)


def crown(p, c, r, low, high, n, rgb, thick=0.03):
    """종이 왕관: 위가 톱니(n개 봉우리)인 고리, 안팎 두 겹."""
    c = V(c)
    seg = n * 2
    outer, inner = [], []
    for k in range(seg):
        a = 2 * math.pi * k / seg
        top = high if k % 2 == 0 else low
        for lst, rr in ((outer, r), (inner, r - thick)):
            lst.append((p.bm.verts.new(c + Vector((math.cos(a) * rr, math.sin(a) * rr, 0))),
                        p.bm.verts.new(c + Vector((math.cos(a) * rr, math.sin(a) * rr, top)))))
    faces = []
    for k in range(seg):
        k2 = (k + 1) % seg
        faces.append(p.bm.faces.new((outer[k][0], outer[k2][0], outer[k2][1], outer[k][1])))
        faces.append(p.bm.faces.new((inner[k][1], inner[k2][1], inner[k2][0], inner[k][0])))
        faces.append(p.bm.faces.new((outer[k][1], outer[k2][1], inner[k2][1], inner[k][1])))
        faces.append(p.bm.faces.new((inner[k][0], inner[k2][0], outer[k2][0], outer[k][0])))
    p.paint(rgb)


def fib(n):
    g = math.pi * (3 - math.sqrt(5))
    for i in range(n):
        z = 1 - 2 * (i + 0.5) / n
        rr = math.sqrt(1 - z * z)
        yield Vector((math.cos(g * i) * rr, math.sin(g * i) * rr, z))


def curls(p, place, n, rmin, rmax, tones, skip=None, seg=(6, 4)):
    """곱슬 털 방울을 고르게 뿌림. place(u) → 표면 점, skip(u) 이면 건너뜀."""
    for i, u in enumerate(fib(n)):
        if skip and skip(u):
            continue
        k = (i * 7919) % 97 / 97
        blob(p, place(u), rmin + (rmax - rmin) * k, tones[(i * 31) % len(tones)], seg=seg)


def on_blob(c, r, pear=0.0, out=0.0):
    c = V(c)

    def f(u):
        s = 1 - pear * u.z
        return c + Vector((u.x * (r[0] * s + out), u.y * (r[1] * s + out), u.z * (r[2] + out)))
    return f


def smooth(a, b, x):
    t = min(max((x - a) / (b - a), 0.0), 1.0)
    return t * t * (3 - 2 * t)


# ───────────── 손님 공통 몸 ─────────────
class Char:
    def __init__(self, cid, label, **s):
        self.id, self.label, self.s = cid, label, s
        self.parts = {n: Part(n) for n in ("Head", "Body", "ArmL", "ArmR", "LegL", "LegR")}
        s.setdefault("foot", (s["leg_r"] * 1.15, s["leg_r"] * 1.5, s["leg_r"] * 0.75))
        self.hip = s["leg"]
        self.neck = self.hip + s["torso_h"]
        self.hr = s["hr"]
        self.hcz = self.neck + self.hr[2] * s.get("head_sink", 0.78)
        self.shz = self.neck - s["arm_r"] * 1.4
        self.shx = s["torso_w"] / 2 + s["arm_r"] * 0.35
        self.hipx = s.get("hipx", s["torso_w"] * 0.22)
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
        """머리 앞면 위의 점 (x = 옆, z = 머리 가운데 기준 높이). out > 0 이면 더 앞으로."""
        rx, ry, rz = self.hr
        t = 1 - (x / rx) ** 2 - (z / rz) ** 2
        return Vector((x, -ry * math.sqrt(max(t, 0.0)) - out, self.hcz + z))

    def head(self, rgb, fl=None, mask=None, seg=(44, 28)):
        blob(self.P("Head"), (0, 0, self.hcz), self.hr, rgb, seg=seg, fl=fl, mask=mask)

    def torso(self, rgb, fl=None, pear=0.14, seg=(36, 24), scale=1.0):
        s = self.s
        blob(self.P("Body"), (0, 0, self.hip + s["torso_h"] * 0.5),
             (s["torso_w"] / 2 * scale, s["torso_d"] / 2 * scale, s["torso_h"] * 0.62 * scale), rgb, seg=seg, pear=pear, fl=fl)

    def shell(self, rgb, keep, grow=1.06, fl=None, pear=0.14, seg=(36, 24)):
        """몸 위에 입힌 옷 (몸보다 조금 큰 껍데기, keep으로 모양을 자름)."""
        s = self.s
        blob(self.P("Body"), (0, 0, self.hip + s["torso_h"] * 0.5),
             (s["torso_w"] / 2 * grow, s["torso_d"] / 2 * grow, s["torso_h"] * 0.62 * grow), rgb, seg=seg, pear=pear, fl=fl, keep=keep)

    def limbs(self, arm, paw, leg, foot, fl=None, sleeve=None, sleeve_len=0.0, sleeve_fl=None, foot_fl="same", flat_arm=1.0):
        s = self.s
        ar, lr = s["arm_r"], s["leg_r"]
        fr = s["foot"]
        for side, sx in (("L", 1), ("R", -1)):
            x = sx * self.hipx
            L = self.P("Leg" + side)
            capsule(L, (x, 0, self.hip + 0.05), (x, 0, fr[2] * 1.1), lr, lr * 0.96, leg, seg=(20, 12), fl=fl)
            blob(L, (x, -fr[1] * 0.28, fr[2]), fr, foot, seg=(20, 12), fl=fl if foot_fl == "same" else foot_fl,
                 keep=None)
            x = sx * self.shx
            A = self.P("Arm" + side)
            top, bot = self.shz, self.shz - s["arm_len"]
            capsule(A, (x, 0, top), (x, -0.03, bot + ar * 1.2), ar * 0.86, ar * 1.06, arm, seg=(20, 14), fl=fl, flat=flat_arm)
            if paw:
                blob(A, (x, -0.05, bot + ar * 1.2), (ar * 1.24, ar * 1.2 * flat_arm, ar * 1.2), paw, seg=(16, 10), fl=fl)
            if sleeve:
                capsule(A, (x, 0, top + ar * 0.1), (x, -0.01, top - sleeve_len), ar * 1.34, ar * 1.3, sleeve, seg=(20, 12), fl=sleeve_fl)

    # 얼굴 소품
    def eyes(self, gap, z, r=(0.085, 0.05, 0.11), shine=True, color=(36, 28, 32)):
        h = self.P("Head")
        for sx in (1, -1):
            c = self.fp(sx * gap, z, 0.0)
            blob(h, c, r, color, seg=(14, 10))
            if shine:
                blob(h, c + Vector((sx * -0.025, -r[1] * 0.8, r[2] * 0.4)), 0.026, (255, 255, 255), seg=(8, 6))
                blob(h, c + Vector((sx * 0.02, -r[1] * 0.8, -r[2] * 0.35)), 0.012, (255, 255, 255), seg=(6, 4))

    def happy_eyes(self, gap, z, R=0.085, r=0.024):
        h = self.P("Head")
        for sx in (1, -1):
            c = self.fp(sx * gap, z, 0.01)
            torus(h, c, R, r, (45, 32, 36), m=rot(z=sx * 10), a0=15, a1=165, useg=12, vseg=6)

    def blush(self, gap, z, r=(0.13, 0.04, 0.08), color=(255, 160, 172)):
        for sx in (1, -1):
            blob(self.P("Head"), self.fp(sx * gap, z, 0.0), r, color, seg=(12, 8))

    def open_mouth(self, z, w=0.1, out=0.0, color=(170, 60, 72), tongue=(255, 140, 150), x=0.0):
        h = self.P("Head")
        c = self.fp(x, z, out)
        blob(h, c, (w, 0.05, w * 0.72), color, seg=(14, 8), keep=lambda q: q.z < 0.3 or q.y > 0)
        if tongue:
            blob(h, c + Vector((0, -0.02, -w * 0.32)), (w * 0.6, 0.04, w * 0.34), tongue, seg=(10, 6))

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


# ───────────── 손님들 (사용자 3D 그림 기준) ─────────────
def toward(n):
    """앞(-Y)을 보는 납작한 것을 법선 n 쪽으로 돌리는 회전."""
    return Vector((0, -1, 0)).rotation_difference(n.normalized()).to_matrix().to_4x4()


def cell_tone(freq, tones):
    """곱슬 셀마다 조금 다른 색."""
    def f(w):
        _, pts = noise.voronoi(w * freq, distance_metric="DISTANCE")
        q = pts[0]
        h = int(abs(q.x * 73.1 + q.y * 37.7 + q.z * 19.3)) % len(tones)
        return tones[h]
    return f


def ppogeuli():
    ch = Char("Ppogeuli", "뽀글이", leg=0.7, torso_h=1.2, torso_w=1.3, torso_d=1.1, hr=(0.9, 0.82, 0.82),
              arm_len=1.0, arm_r=0.24, leg_r=0.28, foot=(0.3, 0.36, 0.2))
    tones = [(170, 104, 68), (156, 92, 58), (184, 118, 80)]
    FUR = tones[0]
    MUZ = (196, 140, 104)
    ch.head(FUR, fl=SOFT)
    ch.torso(FUR, fl=SOFT)
    ch.limbs(FUR, FUR, FUR, tones[1], fl=SOFT)
    h, b = ch.P("Head"), ch.P("Body")
    # 곱슬 방울: 머리 (눈·주둥이 자리는 비움), 귀, 몸, 팔다리
    face = Vector((0, -1, -0.1)).normalized()
    curls(h, on_blob((0, 0, ch.hcz), ch.hr, out=0.02), 110, 0.13, 0.17, tones,
          skip=lambda u: u.z < -0.75 or (u.dot(face) > 0.72) or (u.z > 0.55 and u.y > -0.6))
    for sx in (1, -1):  # 늘어진 곱슬 귀
        ec = Vector((sx * 0.86, 0.06, ch.hcz - 0.18))
        blob(h, ec, (0.22, 0.2, 0.42), FUR, seg=(16, 12), fl=SOFT)
        curls(h, on_blob(ec, (0.22, 0.2, 0.42), out=0.02), 26, 0.11, 0.14, tones)
    curls(b, on_blob((0, 0, ch.hip + ch.s["torso_h"] * 0.5), (ch.s["torso_w"] / 2, ch.s["torso_d"] / 2, ch.s["torso_h"] * 0.62), pear=0.14, out=0.02),
          72, 0.14, 0.18, tones, skip=lambda u: u.z > 0.8)
    for side, sx in (("L", 1), ("R", -1)):
        A, L = ch.P("Arm" + side), ch.P("Leg" + side)
        for row in range(5):
            for k in range(5):
                a = 2 * math.pi * (k + 0.5 * (row % 2)) / 5
                z = ch.shz - 0.05 - row * 0.2
                blob(A, (sx * ch.shx + math.cos(a) * 0.24, math.sin(a) * 0.24, z), 0.12 + 0.02 * ((row + k) % 2), tones[(row + k) % 3], seg=(6, 4))
                if row < 4:
                    z = ch.hip - 0.02 - row * 0.15
                    blob(L, (sx * ch.hipx + math.cos(a) * 0.28, math.sin(a) * 0.28, z), 0.12 + 0.02 * ((row + k) % 2), tones[(row + k + 1) % 3], seg=(6, 4))
    mc = ch.fp(0, -0.27, -0.1)
    blob(h, mc, (0.3, 0.26, 0.24), MUZ, seg=(24, 16), fl=SOFT)
    blob(h, mc + Vector((0, -0.25, 0.1)), (0.1, 0.07, 0.075), (52, 32, 28), seg=(12, 8))
    blob(h, mc + Vector((0, -0.2, -0.1)), (0.11, 0.06, 0.07), (150, 52, 60), seg=(12, 8))
    blob(h, mc + Vector((0, -0.23, -0.13)), (0.07, 0.04, 0.04), (255, 140, 150), seg=(8, 6))
    ch.eyes(0.3, 0.1, r=(0.075, 0.05, 0.09))
    GL = (64, 38, 30)
    for sx in (1, -1):  # 동그란 안경
        c = ch.fp(sx * 0.31, 0.1, 0.07)
        torus(h, c, 0.2, 0.032, GL, m=rot(z=sx * 14), useg=32)
        capsule(h, c + Vector((sx * 0.2, 0.04, 0.02)), (sx * 0.9, 0.2, ch.hcz + 0.14), 0.022, 0.022, GL, seg=(8, 6))
    torus(h, ch.fp(0, 0.14, 0.12), 0.08, 0.025, GL, a0=20, a1=160, useg=10)
    # 버건디 베레모 + 꼭지
    BR = (124, 32, 46)
    bc = Vector((0.06, 0.1, ch.hcz + ch.hr[2] * 0.86))
    blob(h, bc, (0.9, 0.86, 0.25), BR, seg=(40, 20), m=rot(y=12, x=-6), fl=("soft", 0.008, 10))
    capsule(h, bc + Vector((0.07, 0, 0.22)), bc + Vector((0.1, 0, 0.36)), 0.05, 0.035, BR, seg=(10, 8))
    # 흰 둥근 칼라 (턱 밑)
    for sx in (1, -1):
        blob(b, (sx * 0.2, -ch.s["torso_d"] * 0.42, ch.neck - 0.05), (0.26, 0.1, 0.14), (252, 248, 240), seg=(16, 10), m=rot(z=-sx * 18, x=-20))
    tc = Vector((0, ch.s["torso_d"] * 0.5 + 0.22, ch.hip + 0.45))
    curls(b, on_blob(tc, (0.14, 0.14, 0.14)), 14, 0.11, 0.14, tones)
    ch.mouth = mc + Vector((0, -0.3, -0.1))
    return ch


def kkuldanji():
    ch = Char("Kkuldanji", "꿀단지", leg=0.6, torso_h=1.05, torso_w=1.25, torso_d=1.05, hr=(0.9, 0.8, 0.8),
              arm_len=0.85, arm_r=0.24, leg_r=0.28, foot=(0.29, 0.36, 0.19))
    FUR, LIGHT, IN = (252, 206, 72), (255, 228, 145), (238, 168, 70)
    ch.head(FUR, fl=FLUFF)
    ch.torso(FUR, fl=FLUFF, pear=0.18)
    ch.limbs(FUR, FUR, FUR, FUR, fl=FLUFF)
    h, b = ch.P("Head"), ch.P("Body")
    for sx in (1, -1):
        blob(h, (sx * 0.62, 0.06, ch.hcz + 0.56), (0.28, 0.18, 0.27), FUR, seg=(20, 14), fl=FLUFF)
        blob(h, (sx * 0.62, -0.06, ch.hcz + 0.55), (0.16, 0.06, 0.15), IN, seg=(14, 8))
    mc = ch.fp(0, -0.25, -0.12)
    blob(h, mc, (0.32, 0.24, 0.23), LIGHT, seg=(24, 16), fl=("soft", 0.012, 9))
    blob(h, mc + Vector((0, -0.23, 0.09)), (0.1, 0.06, 0.07), (72, 44, 32), seg=(12, 8))
    blob(h, mc + Vector((0, -0.2, -0.08)), (0.1, 0.06, 0.07), (150, 52, 60), seg=(12, 8))
    blob(h, mc + Vector((0, -0.23, -0.11)), (0.065, 0.04, 0.04), (255, 140, 150), seg=(8, 6))
    ch.eyes(0.3, 0.08, r=(0.07, 0.05, 0.085))
    ch.blush(0.5, -0.14)
    # 앞머리 털 한 줌 (곱슬)
    for k, (x, z, a) in enumerate(((-0.12, 0.6, 20), (0.0, 0.66, 0), (0.12, 0.6, -20))):
        capsule(h, ch.fp(x, z, -0.05), ch.fp(x * 1.6, z + 0.14, -0.1), 0.09, 0.04, FUR, seg=(12, 8), fl=FLUFF)
    torus(h, ch.fp(0.05, 0.5, 0.0), 0.07, 0.03, FUR, m=rot(z=10), a0=0, a1=300, useg=14)
    # 종이 왕관
    crown(h, (0, 0.04, ch.hcz + ch.hr[2] * 0.72), 0.44, 0.16, 0.4, 5, (244, 242, 232), thick=0.035)
    blob(b, (0, ch.s["torso_d"] * 0.5 + 0.12, ch.hip + 0.3), 0.17, FUR, seg=(14, 10), fl=FLUFF)
    ch.mouth = mc + Vector((0, -0.28, -0.08))
    return ch


def mochi():
    ch = Char("Mochi", "모찌", leg=0.65, torso_h=1.05, torso_w=1.1, torso_d=0.92, hr=(0.88, 0.8, 0.82),
              arm_len=0.85, arm_r=0.2, leg_r=0.24, foot=(0.25, 0.36, 0.18))
    FUR, PINK, BLUE, WHITE, RB = (253, 250, 248), (255, 188, 204), (168, 208, 242), (252, 252, 255), (255, 150, 186)
    ch.head(FUR, fl=FLUFF)
    ch.torso(FUR, fl=FLUFF)
    ch.limbs(FUR, FUR, FUR, FUR, fl=FLUFF, sleeve=WHITE, sleeve_len=0.3, sleeve_fl=("soft", 0.01, 8))
    h, b = ch.P("Head"), ch.P("Body")
    for sx in (1, -1):  # 긴 귀 + 분홍 안쪽
        a = Vector((sx * 0.28, 0.06, ch.hcz + 0.55))
        e = Vector((sx * 0.4, 0.1, ch.hcz + 1.38))
        capsule(h, a, e, 0.2, 0.18, FUR, seg=(22, 16), fl=FLUFF, flat=0.62)
        capsule(h, a + Vector((0, -0.1, 0.18)), e + Vector((0, -0.09, -0.04)), 0.1, 0.09, PINK, seg=(16, 12), flat=0.3)
    bc = Vector((0.52, -0.06, ch.hcz + 0.66))  # 리본 (오른쪽 귀 밑)
    for sx in (1, -1):
        blob(h, bc + Vector((sx * 0.15, 0, 0.02)), (0.16, 0.07, 0.11), RB, seg=(14, 10), m=rot(y=-sx * 18))
        capsule(h, bc, bc + Vector((sx * 0.08, -0.02, -0.18)), 0.04, 0.035, RB, seg=(8, 6))
    blob(h, bc, 0.06, (240, 120, 160), seg=(10, 8))
    ch.happy_eyes(0.28, 0.06)
    ch.blush(0.46, -0.12, r=(0.15, 0.045, 0.09))
    blob(h, ch.fp(0, -0.1, 0.0), (0.06, 0.04, 0.04), (245, 140, 165), seg=(10, 6))
    ch.open_mouth(-0.27, w=0.11)
    # 세라복: 흰 블라우스, 하늘색 깃, 분홍 스카프, 주름치마
    ch.shell(WHITE, keep=lambda u: u.z > -0.5, grow=1.05, fl=("soft", 0.008, 8))
    ch.shell(BLUE, keep=lambda u: u.z > 0.42 and not (u.y < -0.3 and abs(u.x) < 0.5), grow=1.1)
    ch.shell(WHITE, keep=lambda u: 0.4 < u.z < 0.5 and not (u.y < -0.3 and abs(u.x) < 0.5), grow=1.12)
    d = ch.s["torso_d"]
    kc = Vector((0, -d * 0.58, ch.neck - 0.32))
    blob(b, kc, (0.08, 0.06, 0.07), RB, seg=(10, 8))
    for sx in (1, -1):
        blob(b, kc + Vector((sx * 0.13, 0, 0.02)), (0.13, 0.05, 0.08), RB, seg=(12, 8), m=rot(y=-sx * 15))
        capsule(b, kc, kc + Vector((sx * 0.1, -0.03, -0.26)), 0.05, 0.04, RB, seg=(10, 8), flat=0.5)
    w = ch.s["torso_w"]
    hz = ch.hip
    lathe(b, [(w * 0.5, hz + 0.42), (w * 0.56, hz + 0.25), (w * 0.68, hz + 0.0), (w * 0.76, hz - 0.2)], BLUE, seg=48, pleats=18, depth=0.06)
    blob(b, (0, d * 0.5 + 0.22, hz - 0.02), 0.2, FUR, seg=(16, 12), fl=FLUFF)
    ch.mouth = ch.fp(0, -0.27, 0.05)
    return ch


def chunsik():
    ch = Char("Chunsik", "춘식이 아저씨", leg=0.85, torso_h=1.35, torso_w=1.35, torso_d=1.1, hr=(0.95, 0.84, 0.82),
              arm_len=1.1, arm_r=0.25, leg_r=0.3, foot=(0.3, 0.38, 0.19))
    GRAY, DARK, WHITE, PINK, GREEN = (150, 150, 158), (102, 102, 112), (246, 246, 244), (238, 158, 170), (66, 146, 82)
    hc = Vector((0, 0, ch.hcz))

    def head_col(w):
        r = w - hc
        if r.z > 0.45 and r.y < 0.4:
            if abs(r.x) < 0.06 or 0.16 < abs(r.x) < 0.25:
                return DARK
        if abs(r.x) > 0.7 and r.y > -0.2 and (0.0 < r.z < 0.09 or -0.2 < r.z < -0.11):
            return DARK
        return GRAY

    def arm_col(w):
        return DARK if (w.z % 0.32) < 0.08 and w.z > ch.shz - 0.7 else GRAY

    ch.head(head_col, fl=SOFT)
    ch.torso(GRAY, fl=SOFT, pear=0.1)
    ch.limbs(arm_col, GRAY, GREEN, GRAY, fl=SOFT, foot_fl=SOFT)
    h, b = ch.P("Head"), ch.P("Body")
    for sx in (1, -1):  # 뾰족 귀
        a, e = Vector((sx * 0.5, 0.06, ch.hcz + 0.45)), Vector((sx * 0.72, 0.1, ch.hcz + 1.0))
        capsule(h, a, e, 0.32, 0.03, GRAY, seg=(20, 12), fl=SOFT, flat=0.6)
        capsule(h, a + Vector((0, -0.09, 0.04)), e + Vector((0, -0.07, -0.12)), 0.18, 0.02, PINK, seg=(14, 10), flat=0.35)
        blob(h, a + Vector((sx * 0.02, -0.12, 0.08)), (0.09, 0.05, 0.12), WHITE, seg=(10, 8), fl=FLUFF)
    # 심술 눈
    for sx in (1, -1):
        c = ch.fp(sx * 0.31, 0.06, 0.0)
        blob(h, c, (0.16, 0.06, 0.11), (242, 210, 78), seg=(16, 10))
        blob(h, c + Vector((sx * -0.03, -0.045, -0.01)), (0.04, 0.03, 0.09), (34, 28, 28), seg=(10, 8))
        blob(h, c + Vector((sx * -0.06, -0.06, 0.02)), 0.018, (255, 255, 255), seg=(6, 4))
        blob(h, c + Vector((0, -0.015, 0.04)), (0.18, 0.08, 0.09), GRAY, seg=(16, 10), keep=lambda q: q.z > -0.05)
        capsule(h, ch.fp(sx * 0.13, 0.22, 0.05), ch.fp(sx * 0.5, 0.33, 0.02), 0.06, 0.045, (232, 232, 234), seg=(12, 8), fl=FLUFF)
    # 흰 주둥이·분홍 코·팔자 수염·턱수염·뚱한 입
    mc = ch.fp(0, -0.26, -0.1)
    for sx in (1, -1):
        blob(h, mc + Vector((sx * 0.13, -0.06, 0)), (0.18, 0.15, 0.14), WHITE, seg=(16, 10), fl=FLUFF)
        capsule(h, mc + Vector((sx * 0.18, -0.1, -0.02)), mc + Vector((sx * 0.5, -0.04, -0.2)), 0.08, 0.03, WHITE, seg=(12, 8), fl=FLUFF)
    blob(h, mc + Vector((0, -0.19, 0.11)), (0.08, 0.05, 0.055), PINK, seg=(10, 6))
    bc = Vector((0, mc.y + 0.02, ch.hcz - ch.hr[2] * 0.6))
    blob(h, bc, (0.3, 0.2, 0.26), WHITE, seg=(20, 14), fl=FLUFF)
    capsule(h, bc + Vector((0, -0.04, -0.1)), bc + Vector((0.02, -0.08, -0.42)), 0.16, 0.05, WHITE, seg=(14, 10), fl=FLUFF)
    torus(h, mc + Vector((0, -0.2, -0.08)), 0.06, 0.018, (90, 50, 54), a0=200, a1=340, useg=10)
    # 흰 러닝셔츠 + 초록 운동복 바지 (흰 줄, 허리끈)
    ch.shell(WHITE, keep=lambda u: u.z > -0.35 and not (u.y < -0.45 and u.z > 0.55) and not (abs(u.x) > 0.6 and u.z > 0.45), grow=1.05,
             fl=("soft", 0.006, 10), pear=0.1)
    ch.shell(GREEN, keep=lambda u: u.z < -0.25, grow=1.08, pear=0.1)
    d, w = ch.s["torso_d"], ch.s["torso_w"]
    for sx in (1, -1):
        capsule(b, (sx * 0.05, -d * 0.6, ch.hip + 0.26), (sx * 0.1, -d * 0.62, ch.hip - 0.02), 0.025, 0.025, WHITE, seg=(6, 4))
        blob(b, (sx * 0.1, -d * 0.63, ch.hip - 0.04), 0.04, WHITE, seg=(8, 6))
        L = ch.P("LegL" if sx > 0 else "LegR")
        x = sx * (ch.hipx + ch.s["leg_r"] * 0.97)
        capsule(L, (x, 0, ch.hip), (x, -0.01, ch.s["foot"][2] * 1.5), 0.035, 0.035, WHITE, seg=(6, 4))
    # 줄무늬 꼬리 (뒤에서 옆으로 올라감)
    pts = [Vector((0.12 * math.sin(t * 3) + 0.4 * t, d * 0.5 + 0.08 + 0.4 * math.sin(t * 1.6), ch.hip + 0.15 + 1.1 * t)) for t in [k / 10 for k in range(11)]]
    for k, (a, e) in enumerate(zip(pts, pts[1:])):
        capsule(b, a, e, 0.12, 0.115 if k < 9 else 0.1, DARK if k % 2 else GRAY, seg=(12, 8), fl=SOFT)
    ch.mouth = mc + Vector((0, -0.25, -0.1))
    return ch


def dotori():
    ch = Char("Dotori", "도토리", leg=0.55, torso_h=1.0, torso_w=1.05, torso_d=0.9, hr=(0.84, 0.76, 0.76),
              arm_len=0.8, arm_r=0.19, leg_r=0.23, foot=(0.24, 0.32, 0.17))
    GRAY, LIGHT, NAVY, GOLD, BROWN = (150, 152, 164), (234, 234, 240), (58, 80, 142), (246, 204, 84), (152, 100, 60)
    ch.head(GRAY, fl=SOFT)
    ch.torso(NAVY, fl=("soft", 0.006, 9))
    ch.limbs(GRAY, GRAY, GRAY, (124, 124, 136), fl=SOFT, sleeve=NAVY, sleeve_len=0.62, sleeve_fl=("soft", 0.006, 9))
    h, b = ch.P("Head"), ch.P("Body")
    for sx in (1, -1):
        capsule(h, (sx * 0.45, 0.08, ch.hcz + 0.42), (sx * 0.58, 0.1, ch.hcz + 0.8), 0.17, 0.03, GRAY, seg=(14, 10), fl=SOFT, flat=0.6)
    mc = ch.fp(0, -0.24, -0.14)
    blob(h, mc, (0.44, 0.26, 0.28), LIGHT, seg=(26, 16), fl=("soft", 0.012, 9))
    blob(h, mc + Vector((0, -0.25, 0.12)), (0.07, 0.045, 0.05), (48, 40, 44), seg=(10, 6))
    blob(h, mc + Vector((0, -0.23, -0.06)), (0.09, 0.05, 0.065), (150, 52, 60), seg=(12, 8))
    blob(h, mc + Vector((0, -0.25, -0.09)), (0.06, 0.035, 0.035), (255, 140, 150), seg=(8, 6))
    ch.eyes(0.28, 0.1, r=(0.09, 0.055, 0.11))
    ch.blush(0.5, -0.12, r=(0.14, 0.045, 0.1))
    # 남색 제복 모자
    top = ch.hcz + ch.hr[2] * 0.5
    lathe(h, [(0.62, top + 0.36), (0.6, top + 0.2), (0.6, top - 0.04)], (36, 40, 66), seg=32)
    blob(h, (0, 0.04, top + 0.36), (0.78, 0.74, 0.13), NAVY, seg=(32, 14), m=rot(x=-6))
    blob(h, (0, -0.5, top + 0.0), (0.5, 0.34, 0.05), (32, 36, 58), seg=(24, 10), keep=lambda q: q.y < 0.25, m=rot(x=12))
    star(h, (0, -0.66, top + 0.22), 0.09, GOLD, thick=0.03)
    # 제복 단추·깃 + 가방
    d, w = ch.s["torso_d"], ch.s["torso_w"]
    for sx in (1, -1):
        blob(b, (sx * 0.14, -d * 0.52, ch.neck - 0.15), (0.13, 0.04, 0.16), (46, 64, 120), seg=(10, 8), m=rot(y=sx * 25))
    blob(b, (0, -d * 0.55, ch.neck - 0.12), (0.06, 0.03, 0.09), LIGHT, seg=(8, 6))
    for k in range(3):
        blob(b, (0, -d * 0.6 + k * 0.02, ch.neck - 0.38 - k * 0.22), 0.045, GOLD, seg=(8, 6))
    bag = Vector((w * 0.56 + 0.06, -0.12, ch.hip + 0.22))
    rbox(b, bag, (0.24, 0.62, 0.48), BROWN, 0.08)
    rbox(b, bag + Vector((-0.01, -0.02, 0.15)), (0.28, 0.66, 0.2), (124, 80, 48), 0.07)
    blob(b, bag + Vector((0.14, -0.02, 0.08)), (0.03, 0.06, 0.05), GOLD, seg=(8, 6))
    for k in range(2):
        rbox(b, bag + Vector((-0.02, -0.1 + k * 0.17, 0.3)), (0.03, 0.22, 0.24), (252, 250, 244), 0.01, m=rot(x=14 - k * 24))
    blob(b, bag + Vector((-0.02, -0.1, 0.36)), (0.03, 0.05, 0.05), (230, 90, 90), seg=(6, 4))
    capsule(b, (-w * 0.38, -d * 0.5, ch.neck - 0.05), bag + Vector((0, 0, 0.2)), 0.035, 0.035, (124, 80, 48), seg=(8, 6))
    # 크게 말린 꼬리
    cc = Vector((0, d * 0.5 + 0.78, ch.hip + 1.3))
    k, n = 0, 15
    for k in range(n):
        t = k / (n - 1)
        ang = math.radians(-118 + t * 400)
        R = 1.3 * (1 - 0.72 * t)
        p = cc + Vector((0, math.cos(ang) * R, math.sin(ang) * R))
        col = (188, 188, 202) if (k // 2) % 2 == 0 else (150, 150, 164)
        blob(b, p, 0.46 - 0.24 * t, col, seg=(16, 12), fl=FLUFF)
    ch.mouth = mc + Vector((0, -0.3, -0.06))
    return ch


def owl():
    ch = Char("Owl", "부엉이", leg=0.38, torso_h=1.45, torso_w=1.55, torso_d=1.3, hr=(0.98, 0.86, 0.82), head_sink=0.66,
              arm_len=1.0, arm_r=0.22, leg_r=0.11, foot=(0.28, 0.32, 0.08))
    PURP, PURP2, BELLY, CAPE = (160, 118, 208), (128, 90, 184), (204, 180, 238), (52, 62, 138)
    STAR, BEAK, FOOT = (252, 216, 92), (250, 192, 60), (248, 166, 58)
    ch.head(PURP, fl=FEATHER)
    ch.torso(PURP, fl=FEATHER, pear=0.2)
    ch.limbs(PURP, PURP2, FOOT, FOOT, fl=FEATHER, foot_fl=None, flat_arm=0.55)
    h, b = ch.P("Head"), ch.P("Body")
    for side, sx in (("L", 1), ("R", -1)):
        L = ch.P("Leg" + side)
        for k in (-1, 0, 1):  # 발가락 + 발톱
            a = Vector((sx * ch.hipx + k * 0.12, -0.18, 0.06))
            capsule(L, a, a + Vector((k * 0.05, -0.2, -0.01)), 0.06, 0.05, FOOT, seg=(10, 6))
            capsule(L, a + Vector((k * 0.05, -0.22, -0.01)), a + Vector((k * 0.06, -0.29, -0.05)), 0.03, 0.01, (90, 70, 60), seg=(6, 4))
        A = ch.P("Arm" + side)
        x = sx * ch.shx
        for k in range(3):  # 날개 끝 깃
            z = ch.shz - ch.s["arm_len"] + 0.05 + k * 0.12
            capsule(A, (x, -0.02, z + 0.2), (x + sx * 0.05 * (k - 1), -0.02, z - 0.08), 0.1, 0.03, PURP2, seg=(10, 6), flat=0.5)
    for sx in (1, -1):  # 귀깃
        capsule(h, (sx * 0.58, 0.06, ch.hcz + 0.5), (sx * 0.92, 0.12, ch.hcz + 1.02), 0.26, 0.04, PURP, seg=(16, 12), fl=FEATHER, flat=0.6)
    # 큰 눈 (반쯤 감은) + 속눈썹
    for sx in (1, -1):
        c = ch.fp(sx * 0.34, 0.02, 0.0)
        blob(h, c, (0.33, 0.09, 0.31), (210, 188, 240), seg=(20, 12))
        e = c + Vector((0, -0.06, 0))
        blob(h, e, (0.23, 0.07, 0.22), (255, 242, 196), seg=(18, 12))
        blob(h, e + Vector((0, -0.04, -0.03)), (0.15, 0.05, 0.15), (240, 168, 56), seg=(14, 10))
        blob(h, e + Vector((sx * -0.02, -0.075, -0.03)), (0.08, 0.03, 0.085), (34, 26, 36), seg=(10, 8))
        blob(h, e + Vector((sx * -0.05, -0.1, 0.02)), 0.025, (255, 255, 255), seg=(6, 4))
        blob(h, e + Vector((0, -0.02, 0.02)), (0.25, 0.1, 0.24), (104, 72, 158), seg=(18, 12), keep=lambda q: q.z > 0.1)
        for k in range(3):
            a = e + Vector((sx * (0.12 + k * 0.05), -0.08, 0.06 - k * 0.04))
            capsule(h, a, a + Vector((sx * 0.12, -0.02, 0.05 - k * 0.04)), 0.022, 0.008, (60, 40, 80), seg=(6, 4))
    capsule(h, ch.fp(0, -0.04, 0.06), ch.fp(0, -0.3, 0.1), 0.11, 0.025, BEAK, seg=(12, 8))
    torus(h, (0, 0.05, ch.hcz + ch.hr[2] + 0.4), 0.3, 0.13, (248, 230, 160), a0=50, a1=320, taper=True, useg=26, vseg=10)
    # 배 깃털 (밝은 비늘)
    d, w, th = ch.s["torso_d"], ch.s["torso_w"], ch.s["torso_h"]
    blob(b, (0, -d * 0.3, ch.hip + th * 0.42), (0.52, 0.2, 0.55), BELLY, seg=(22, 16), fl=FEATHER)
    for row in range(4):
        for j in range(4 - row % 2):
            x = -0.27 + j * 0.18 + (row % 2) * 0.09
            z = ch.hip + 0.18 + row * 0.2
            blob(b, (x, -d * 0.47 + abs(x) * 0.25, z), (0.08, 0.035, 0.06), (186, 158, 228), seg=(10, 6), keep=lambda q: q.z < 0.3)
    # 별무늬 망토 + 초승달 잠금
    rad = (w / 2 * 1.12, d / 2 * 1.12, th * 0.62 * 1.12)
    cen = Vector((0, 0, ch.hip + th * 0.5))
    keep = lambda u: -0.8 < u.z < 0.88 and not (u.y < -0.25 and abs(u.x) < 0.58)
    ch.shell(CAPE, keep=keep, grow=1.12, pear=0.2, fl=("soft", 0.008, 7))
    for q in fib(46):
        if not keep(q) or q.z > 0.8 or q.z < -0.7:
            continue
        s = 1 - 0.2 * q.z
        pos = cen + Vector((q.x * rad[0] * s, q.y * rad[1] * s, q.z * rad[2]))
        star(b, pos, 0.07, STAR, m=toward(Vector((q.x, q.y, q.z * 0.5))) @ rot(y=float(int(q.x * 97) % 60)))
    blob(b, (0, -d * 0.36, ch.neck - 0.04), (0.42, 0.18, 0.08), CAPE, seg=(16, 8))
    torus(b, (0, -d * 0.5, ch.neck - 0.14), 0.09, 0.04, STAR, a0=60, a1=330, taper=True, useg=14)
    ch.mouth = ch.fp(0, -0.3, 0.12)
    return ch


def pongpong():
    ch = Char("Pongpong", "퐁퐁이", leg=0.45, torso_h=1.05, torso_w=1.1, torso_d=0.95, hr=(0.88, 0.8, 0.8),
              arm_len=0.8, arm_r=0.19, leg_r=0.1, foot=(0.3, 0.4, 0.07))
    YEL, ORA, BLUE, HAT, HATD = (255, 224, 92), (255, 154, 56), (172, 210, 242), (150, 194, 232), (118, 164, 214)
    ch.head(YEL, fl=FLUFF)
    ch.torso(YEL, fl=FLUFF)
    ch.limbs(YEL, YEL, ORA, ORA, fl=FLUFF, foot_fl=None, flat_arm=0.6, sleeve=BLUE, sleeve_len=0.26, sleeve_fl=("soft", 0.008, 8))
    h, b = ch.P("Head"), ch.P("Body")
    for side, sx in (("L", 1), ("R", -1)):  # 물갈퀴 발가락
        for k in (-1, 0, 1):
            blob(ch.P("Leg" + side), (sx * ch.hipx + k * 0.13, -0.36, 0.05), (0.08, 0.1, 0.05), ORA, seg=(10, 6))
    # 부리 (웃으며 벌림)
    bc = ch.fp(0, -0.18, -0.12)
    blob(h, bc + Vector((0, -0.14, 0.04)), (0.38, 0.3, 0.11), ORA, seg=(24, 12), m=rot(x=-10))
    blob(h, bc + Vector((0, -0.1, -0.12)), (0.3, 0.24, 0.08), (240, 132, 48), seg=(20, 10), m=rot(x=12))
    blob(h, bc + Vector((0, -0.16, -0.05)), (0.22, 0.16, 0.05), (160, 60, 64), seg=(14, 8))
    blob(h, bc + Vector((0, -0.2, -0.08)), (0.12, 0.08, 0.035), (255, 140, 150), seg=(10, 6))
    for sx in (1, -1):
        blob(h, bc + Vector((sx * 0.1, -0.38, 0.1)), (0.025, 0.015, 0.015), (200, 110, 40), seg=(6, 4))
    ch.happy_eyes(0.32, 0.14)
    ch.blush(0.5, -0.05, r=(0.13, 0.045, 0.08))
    # 하늘색 벙거지
    top = ch.hcz + ch.hr[2] * 0.42
    blob(h, (0, 0.02, top + 0.2), (0.8, 0.78, 0.46), HAT, seg=(32, 18), keep=lambda q: q.z > -0.35, fl=("soft", 0.006, 9))
    lathe(h, [(0.8, top + 0.14), (0.82, top - 0.02)], HATD, seg=36)
    lathe(h, [(0.8, top + 0.0), (1.08, top - 0.2), (1.11, top - 0.25), (1.06, top - 0.26), (0.78, top - 0.06), (0.8, top + 0.0)], HAT, seg=40)
    # 원피스 + 흰 칼라 + 단추 + 병아리 가방
    d, w = ch.s["torso_d"], ch.s["torso_w"]
    ch.shell(BLUE, keep=lambda u: u.z < 0.75, grow=1.06, fl=("soft", 0.006, 9))
    lathe(ch.P("Body"), [(w * 0.56, ch.hip + 0.3), (w * 0.64, ch.hip + 0.05), (w * 0.7, ch.hip - 0.12)], BLUE, seg=40, pleats=10, depth=0.03)
    for sx in (1, -1):
        blob(b, (sx * 0.2, -d * 0.45, ch.neck - 0.06), (0.24, 0.1, 0.13), (252, 252, 250), seg=(16, 10), m=rot(z=-sx * 18, x=-20))
    for k in range(2):
        blob(b, (0, -d * 0.6, ch.neck - 0.38 - k * 0.22), 0.04, (252, 252, 250), seg=(8, 6))
    bag = Vector((-w * 0.56 - 0.08, -0.16, ch.hip + 0.06))
    blob(b, bag, 0.22, YEL, seg=(18, 12), fl=FLUFF)
    blob(b, bag + Vector((0, -0.22, 0)), (0.06, 0.05, 0.035), ORA, seg=(8, 6))
    for sx in (1, -1):
        blob(b, bag + Vector((sx * 0.08, -0.19, 0.08)), 0.026, (40, 30, 34), seg=(6, 4))
    capsule(b, (w * 0.38, -d * 0.48, ch.neck - 0.05), bag + Vector((0, 0, 0.2)), 0.03, 0.03, HATD, seg=(8, 6))
    for k in (-1, 0, 1):  # 꼬리깃
        capsule(b, (k * 0.08, d * 0.45, ch.hip + 0.2), (k * 0.14, d * 0.5 + 0.28, ch.hip + 0.42), 0.09, 0.03, YEL, seg=(10, 6), fl=FLUFF)
    ch.mouth = bc + Vector((0, -0.35, -0.05))
    return ch


CHARS = [ppogeuli(), kkuldanji(), mochi(), chunsik(), dotori(), owl(), pongpong()]

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
