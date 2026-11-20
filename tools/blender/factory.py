# 최고 등급(Lv5) = 달고나 공장 (사용자 요청 2026-11-18: 공장식 기계를 더 크고 정교하게, 텍스처 넣어서, 아예 공장으로).
# docs/MACHINE_ERAS.md "Lv5 달고나 공장".
#
# 생산 라인 (왼쪽 → 오른쪽, 앞 = 플레이어 쪽 = Blender -Y):
#   ① 설탕 저장 탑: 투명 큰 설탕 통 2개 + 철골 받침 + 사다리 + 나사 공급관
#   ② 끓이는 솥 2개: 스테인리스 이중솥 + 빨간 가열 자켓 + 계기판 + 밸브 + 배관
#   ③ 반죽 노즐대: 컨베이어를 가로지르는 문형 프레임 + 노즐 6개
#   ④ 컨베이어: 긴 고무 벨트 + 다리 + 옆 가드 + 틀 쟁반(달고나 6칸) 여러 개
#   ⑤ 찍는 프레스: 큰 철골 프레스 + 유압 실린더 2개 + 도장판 (노랑·검정 위험 줄무늬)
#   ⑥ 식히는 터널: 상자 터널 + 환풍기 + 투명 비닐 커튼
#   ⑦ 나오는 곳: 미끄럼판 + 받는 상자들 (완성된 달고나 더미)
#   ⑧ 제어대: 기울어진 판(계기판·도안 고르기 버튼 6개 그림) + 버섯 버튼 + 3색 경고탑
#   + 공장 건물: 콘크리트 바닥(노란 안전선), 뒤·왼쪽 벽(창문), 철골 기둥·들보, 매달린 조명, 안전 난간
#
# 텍스처는 이 스크립트가 numpy로 그려서 glb에 넣는다 (솔질 스테인리스, 위험 줄무늬, 고무 벨트, 콘크리트, 칠한 벽, 제어판 면).
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/factory.py -- <출력 폴더(절대 경로)> [line]
#   끝에 line을 붙이면 Lv4 연속 생산 설비(build_line) → dalgona_line.glb, line_preview*.png, line_parts.txt
# 결과: dalgona_factory.glb, factory_preview.png, factory_preview2.png, factory_parts.txt
# 크기 = 게임 stud. 원점 = 공장 바닥 가운데. 바닥 44 × 28, 벽 높이 16.

import math
import os
import random
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else ".")
random.seed(11)
rng = np.random.default_rng(11)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
PARTS = []


def lin(c):
    return tuple(((v / 255) ** 2.2) for v in c)


# ───────────── 텍스처 (numpy로 그림) ─────────────
def make_image(name, arr):
    h, w, _ = arr.shape
    img = bpy.data.images.new(name, w, h, alpha=False)
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[:, :, :3] = np.clip(arr, 0, 1) ** 2.2  # sRGB → 선형 (Blender 픽셀은 선형으로 받음)
    img.pixels.foreach_set(rgba[::-1].ravel())
    img.pack()
    return img


def tex_brushed(base, size=256, streak=0.025):
    a = np.ones((size, size, 3)) * np.array(base) / 255
    lines = rng.normal(0, 1, (size, 1)) * streak
    lines = np.repeat(lines, size, axis=1) + rng.normal(0, streak * 0.4, (size, size))
    return a + lines[:, :, None]


def tex_hazard(size=256, n=6):
    """사탕 줄무늬 (분홍·흰색). 예전 노랑·검정 위험 줄무늬를 귀여운 느낌으로 (사용자 요청 2026-11-19)"""
    y, x = np.mgrid[0:size, 0:size]
    band = ((x + y) // (size // n)) % 2
    yel = np.array([255, 150, 190]) / 255
    blk = np.array([255, 250, 252]) / 255
    a = np.where(band[:, :, None] == 0, yel, blk)
    return a + rng.normal(0, 0.03, (size, size, 1))


def tex_belt(size=256):
    y, x = np.mgrid[0:size, 0:size]
    ribs = (np.sin(x / size * 2 * math.pi * 16) > 0.6).astype(float)
    a = np.ones((size, size, 3)) * np.array([62, 70, 110]) / 255 - ribs[:, :, None] * 0.05  # 남색 벨트
    return a + rng.normal(0, 0.02, (size, size, 1))


def tex_concrete(size=512):
    """파스텔 타일 바닥: 연노랑·연분홍 바둑판 + 흰 줄눈"""
    a = np.ones((size, size, 3))
    t = size // 4
    y, x = np.mgrid[0:size, 0:size]
    check = ((x // t) + (y // t)) % 2
    a[:] = np.array([255, 244, 214]) / 255
    a[check == 1] = np.array([255, 232, 236]) / 255
    a += rng.normal(0, 0.006, (size, size, 1))
    for k in range(0, size, t):
        a[k:k + 3, :, :] = np.array([255, 252, 245]) / 255
        a[:, k:k + 3, :] = np.array([255, 252, 245]) / 255
    return a


def tex_wall(size=256):
    a = np.ones((size, size, 3)) * np.array([196, 236, 218]) / 255  # 위: 민트
    a[size * 3 // 5:] = np.array([255, 205, 222]) / 255  # 아래: 분홍 띠 (배열 0행 = 그림 위)
    a[size * 3 // 5 - 5: size * 3 // 5] = np.array([255, 255, 255]) / 255
    return a + rng.normal(0, 0.004, (size, size, 1))


def disc(a, cx, cy, r, color):
    h, w, _ = a.shape
    y, x = np.mgrid[0:h, 0:w]
    m = (x - cx) ** 2 + (y - cy) ** 2 <= r * r
    a[m] = np.array(color) / 255


def ring(a, cx, cy, r0, r1, color):
    h, w, _ = a.shape
    y, x = np.mgrid[0:h, 0:w]
    d = (x - cx) ** 2 + (y - cy) ** 2
    a[(d <= r1 * r1) & (d >= r0 * r0)] = np.array(color) / 255


def poly(a, pts, color):
    """볼록·오목 다각형 채우기 (짝홀 규칙)."""
    h, w, _ = a.shape
    y, x = np.mgrid[0:h, 0:w]
    inside = np.zeros((h, w), bool)
    n = len(pts)
    for i in range(n):
        x1, y1 = pts[i]
        x2, y2 = pts[(i + 1) % n]
        cond = ((y1 > y) != (y2 > y)) & (x < (x2 - x1) * (y - y1) / (y2 - y1 + 1e-9) + x1)
        inside ^= cond
    a[inside] = np.array(color) / 255


def star_pts(cx, cy, ro, ri, n=5, rot=-math.pi / 2):
    return [(cx + math.cos(rot + i * math.pi / n) * (ro if i % 2 == 0 else ri), cy + math.sin(rot + i * math.pi / n) * (ro if i % 2 == 0 else ri)) for i in range(2 * n)]


def heart_pts(cx, cy, s):
    pts = []
    for i in range(40):
        t = 2 * math.pi * i / 40
        pts.append((cx + 16 * math.sin(t) ** 3 / 17 * s, cy - (13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)) / 17 * s))
    return pts


def tex_panel(W=512, H=276):
    """제어판 면 (판 비율 4.1 × 2.2): 계기판 3개(위) + 도안 고르기 칸 6개(가운데 한 줄, 금색 도형) + 아래 표시줄."""
    a = np.ones((H, W, 3)) * np.array([96, 84, 140]) / 255 + rng.normal(0, 0.008, (H, W, 1))  # 보라 판
    gold, white, dark = (230, 186, 70), (240, 238, 230), (30, 30, 34)
    R = H * 0.15
    for i, cx in enumerate((W * 0.2, W * 0.5, W * 0.8)):
        cy = H * 0.2
        disc(a, cx, cy, R, (200, 200, 205))
        disc(a, cx, cy, R * 0.86, white)
        for k in range(9):  # 눈금
            ang = math.pi * (0.8 + 1.4 * k / 8)
            for t in np.linspace(0.62, 0.8, 6):
                px, py = cx + math.cos(ang) * R * t, cy + math.sin(ang) * R * t
                a[int(py) - 1:int(py) + 1, int(px) - 1:int(px) + 1] = np.array(dark) / 255
        ang = math.pi * (0.9 + 0.5 * i)  # 바늘
        for t in np.linspace(0, 0.75, 30):
            px, py = cx + math.cos(ang) * R * t, cy + math.sin(ang) * R * t
            a[int(py) - 2:int(py) + 2, int(px) - 2:int(px) + 2] = np.array((210, 40, 40)) / 255
        disc(a, cx, cy, R * 0.1, dark)
    # 도안 칸 6개 (가운데 한 줄)
    shapes = ["star", "heart", "circle", "tri", "umbrella", "square"]
    for i, sh in enumerate(shapes):
        cx = W * (0.1 + 0.16 * i)
        cy = H * 0.56
        r = H * 0.12
        disc(a, cx, cy, r, (70, 60, 110))
        ring(a, cx, cy, r * 0.88, r * 1.0, gold)
        s = r * 0.6
        if sh == "star":
            poly(a, star_pts(cx, cy, s, s * 0.42), gold)
        elif sh == "heart":
            poly(a, heart_pts(cx, cy, s), gold)
        elif sh == "circle":
            disc(a, cx, cy, s * 0.8, gold)
        elif sh == "tri":
            poly(a, [(cx, cy - s), (cx + s * 0.9, cy + s * 0.6), (cx - s * 0.9, cy + s * 0.6)], gold)
        elif sh == "umbrella":
            poly(a, [(cx - s, cy), (cx - s * 0.7, cy - s * 0.6), (cx, cy - s * 0.9), (cx + s * 0.7, cy - s * 0.6), (cx + s, cy)], gold)
            a[int(cy):int(cy + s), int(cx - 2):int(cx + 2)] = np.array(gold) / 255
        else:
            a[int(cy - s * 0.7):int(cy + s * 0.7), int(cx - s * 0.7):int(cx + s * 0.7)] = np.array(gold) / 255
    # 아래 표시줄 (초록 숫자판 느낌)
    a[int(H * 0.8):int(H * 0.93), int(W * 0.1):int(W * 0.9)] = np.array((20, 40, 24)) / 255
    for k in range(8):
        x0 = int(W * (0.14 + k * 0.095))
        a[int(H * 0.83):int(H * 0.9), x0:x0 + int(W * 0.05)] = np.array((90, 230, 110)) / 255
    return a


def tex_window(size=256):
    a = np.ones((size, size, 3)) * np.array([170, 205, 225]) / 255
    y, x = np.mgrid[0:size, 0:size]
    a += ((x + y * 0.5) / size * 0.15)[:, :, None]  # 하늘 반사
    for k in range(0, size, size // 4):
        a[k:k + 8, :, :] = np.array((255, 255, 255)) / 255  # 흰 창살
        a[:, k:k + 8, :] = np.array((255, 255, 255)) / 255
    return a


IMG = {}


def image(name, fn):
    if name not in IMG:
        IMG[name] = make_image(name, fn())
    return IMG[name]


# ───────────── 재질 ─────────────
MATS = {}


def mat(key, rgb=None, metal=0.0, rough=0.5, tex=None, alpha=1.0, rbx="SmoothPlastic", emit=False):
    if key in MATS:
        return MATS[key]
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    nt = m.node_tree
    b = nt.nodes["Principled BSDF"]
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    if tex is not None:
        t = nt.nodes.new("ShaderNodeTexImage")
        t.image = tex
        nt.links.new(t.outputs["Color"], b.inputs["Base Color"])
    else:
        b.inputs["Base Color"].default_value = (*lin(rgb), 1)
    if alpha < 1:
        b.inputs["Alpha"].default_value = alpha
        m.surface_render_method = "BLENDED"
    if emit:
        b.inputs["Emission Color"].default_value = (*lin(rgb), 1)
        b.inputs["Emission Strength"].default_value = 3.0
    m["rbx"] = rbx
    m["rgb"] = list(rgb or (255, 255, 255))
    MATS[key] = m
    return m


def M(name):
    """재질 목록: 이름 → (재질, Roblox 재질, 색)"""
    specs = {
        # 귀여운 파스텔 공장 (사용자 요청 2026-11-19: 둥글둥글하고 귀엽게). 금속은 은은한 펄 느낌, 칠은 파스텔
        "Steel": dict(rgb=(236, 234, 246), metal=0.35, rough=0.35, tex=image("BrushedSteel", lambda: tex_brushed((236, 234, 246), streak=0.008)), rbx="SmoothPlastic"),
        "SteelDark": dict(rgb=(196, 198, 240), metal=0.2, rough=0.45, tex=image("BrushedDark", lambda: tex_brushed((196, 198, 240), streak=0.006)), rbx="SmoothPlastic"),  # 연보라
        "Frame": dict(rgb=(150, 205, 240), rough=0.45, rbx="SmoothPlastic"),  # 하늘색 기둥·들보
        "Hazard": dict(rgb=(255, 150, 190), rough=0.45, tex=image("Hazard", tex_hazard), rbx="SmoothPlastic"),  # 사탕 줄무늬
        "Belt": dict(rgb=(62, 70, 110), rough=0.8, tex=image("Belt", tex_belt), rbx="Rubber"),
        "Concrete": dict(rgb=(252, 238, 190), rough=0.7, tex=image("Concrete", tex_concrete), rbx="SmoothPlastic"),
        "Wall": dict(rgb=(196, 236, 218), rough=0.7, tex=image("Wall", tex_wall), rbx="SmoothPlastic"),
        "Window": dict(rgb=(190, 225, 245), rough=0.1, tex=image("Window", tex_window), rbx="Glass"),
        "Panel": dict(rgb=(96, 84, 140), rough=0.5, tex=image("PanelFace", tex_panel), rbx="SmoothPlastic"),
        "Glass": dict(rgb=(225, 240, 255), rough=0.05, alpha=0.35, rbx="Glass"),
        "Sugar": dict(rgb=(255, 252, 250), rough=0.9, rbx="Sand"),
        "Red": dict(rgb=(255, 140, 170), rough=0.4, rbx="SmoothPlastic"),  # 분홍 (솥 띠·정지 버튼)
        "Yellow": dict(rgb=(255, 228, 120), rough=0.4, rbx="SmoothPlastic"),
        "Black": dict(rgb=(70, 60, 100), rough=0.5, rbx="SmoothPlastic"),
        "Rubber": dict(rgb=(62, 70, 110), rough=0.8, rbx="Rubber"),
        "Copper": dict(rgb=(255, 200, 120), metal=0.5, rough=0.35, rbx="SmoothPlastic"),
        "Dalgona": dict(rgb=(232, 166, 80), rough=0.55, rbx="SmoothPlastic"),
        "Curtain": dict(rgb=(220, 210, 255), rough=0.2, alpha=0.45, rbx="Glass"),
        "Crate": dict(rgb=(214, 160, 110), rough=0.6, rbx="Wood"),  # 나무 상자
        "LampOn": dict(rgb=(255, 244, 210), emit=True, rbx="Neon"),
        "BeaconR": dict(rgb=(255, 120, 160), emit=True, rbx="Neon"),
        "BeaconY": dict(rgb=(255, 220, 110), emit=True, rbx="Neon"),
        "BeaconG": dict(rgb=(120, 230, 170), emit=True, rbx="Neon"),
        "Green": dict(rgb=(120, 220, 160), rough=0.4, rbx="SmoothPlastic"),
        "Paint": dict(rgb=(165, 228, 205), rough=0.45, rbx="SmoothPlastic"),  # 민트 칠
        "Cream": dict(rgb=(255, 248, 228), rough=0.5, rbx="SmoothPlastic"),
        "White": dict(rgb=(255, 255, 255), rough=0.5, rbx="SmoothPlastic"),
        # 장식용 파스텔
        "Pink": dict(rgb=(255, 182, 210), rough=0.45, rbx="SmoothPlastic"),
        "Mint": dict(rgb=(165, 232, 200), rough=0.45, rbx="SmoothPlastic"),
        "Sky": dict(rgb=(160, 210, 250), rough=0.45, rbx="SmoothPlastic"),
        "Lemon": dict(rgb=(255, 235, 140), rough=0.45, rbx="SmoothPlastic"),
        "Lilac": dict(rgb=(210, 180, 250), rough=0.45, rbx="SmoothPlastic"),
        "Bush": dict(rgb=(150, 220, 150), rough=0.8, rbx="SmoothPlastic"),
        "Grass": dict(rgb=(170, 225, 140), rough=0.9, rbx="Grass"),
    }
    return mat(name, **specs[name])


# ───────────── 도형 도우미 ─────────────
def box_uv(bm, scale=0.25):
    """면마다 가장 큰 법선 축으로 평면 투영 UV (텍스처가 모든 면에 고르게)."""
    uv = bm.loops.layers.uv.verify()
    for f in bm.faces:
        n = f.normal
        ax = max(range(3), key=lambda i: abs(n[i]))
        for l in f.loops:
            c = l.vert.co
            if ax == 0:
                u, v = c.y, c.z
            elif ax == 1:
                u, v = c.x, c.z
            else:
                u, v = c.x, c.y
            l[uv].uv = (u * scale, v * scale)


def finish(name, bm, mname, smooth=False, uvscale=0.25):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    box_uv(bm, uvscale)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    m = M(mname)
    o.data.materials.append(m)
    for p in me.polygons:
        p.use_smooth = smooth
    PARTS.append((name, mname))
    return o


def add_box(bm, center, size, bevel=None, rot=None):
    # 둥글둥글하게 (사용자 요청 2026-11-19): 따로 안 주면 가장 짧은 변의 22%(최대 0.35)만큼 모서리를 둥글림
    if bevel is None:
        bevel = min(min(size) * 0.22, 0.35)
    m = Matrix.Translation(Vector(center))
    if rot is not None:
        m = m @ rot
    m = m @ Matrix.Diagonal((size[0], size[1], size[2], 1))
    r = bmesh.ops.create_cube(bm, size=1.0, matrix=m)
    if bevel > 0.004:
        edges = list({e for v in r["verts"] for e in v.link_edges})
        bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=3, affect="EDGES", clamp_overlap=True)


def add_ball(bm, center, r, squash=1.0, seg=20):
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=max(6, seg * 3 // 5), radius=r, matrix=Matrix.Translation(Vector(center)) @ Matrix.Diagonal((1, 1, squash, 1)))


def add_ring(bm, center, R, r, seg=32, tube=10):
    """도넛 (가로로 누운 고리): 소용돌이 사탕 기둥에 씀"""
    prof = [(R + math.cos(2 * math.pi * k / tube) * r, math.sin(2 * math.pi * k / tube) * r) for k in range(tube + 1)]
    add_lathe(bm, prof, center=center, seg=seg)


def lollipop(name_prefix, x, y, z0, h, r, color):
    bm = bmesh.new()
    add_rod(bm, (x, y, z0), (x, y, z0 + h), 0.07, seg=10)
    finish(f"{name_prefix}_Stick", bm, "White", smooth=True)
    bm = bmesh.new()
    add_cyl(bm, (x, y, z0 + h + r * 0.95), r, r * 0.35, seg=28, axis="Y")
    finish(f"{name_prefix}_Candy", bm, color, smooth=True)
    bm = bmesh.new()  # 앞면 소용돌이 무늬 (흰 고리 2개)
    for rr in (r * 0.62, r * 0.3):
        add_lathe(bm, [(rr - 0.05, 0), (rr + 0.05, 0)], center=(0, 0, 0), seg=24)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"))
    for v in bm.verts:
        v.co += Vector((x, y - r * 0.19, z0 + h + r * 0.95))
    finish(f"{name_prefix}_Swirl", bm, "White", smooth=True)


def add_cyl(bm, center, r, h, seg=32, axis="Z", r2=None):
    rot = Matrix.Identity(4)
    if axis == "Y":
        rot = Matrix.Rotation(math.pi / 2, 4, "X")
    elif axis == "X":
        rot = Matrix.Rotation(math.pi / 2, 4, "Y")
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r if r2 is None else r2, depth=h, matrix=Matrix.Translation(Vector(center)) @ rot)


def add_rod(bm, a, b, r, seg=12):
    a, b = Vector(a), Vector(b)
    d = b - a
    q = Vector((0, 0, 1)).rotation_difference(d.normalized())
    m = Matrix.Translation((a + b) / 2) @ q.to_matrix().to_4x4()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r, depth=d.length, matrix=m)


def add_lathe(bm, profile, center=(0, 0, 0), seg=40):
    cx, cy, cz = center
    rings = [[bm.verts.new((cx + math.cos(2 * math.pi * k / seg) * r, cy + math.sin(2 * math.pi * k / seg) * r, cz + z)) for k in range(seg)] for (r, z) in profile]
    for a, b in zip(rings, rings[1:]):
        for k in range(seg):
            k2 = (k + 1) % seg
            bm.faces.new((a[k], a[k2], b[k2], b[k]))


def add_star_disc(bm, center, ro, ri, h, n=5):
    cx, cy, cz = center
    top, bot = [], []
    for i in range(2 * n):
        ang = math.pi / 2 + i * math.pi / n
        r = ro if i % 2 == 0 else ri
        top.append(bm.verts.new((cx + math.cos(ang) * r, cy + math.sin(ang) * r, cz + h / 2)))
        bot.append(bm.verts.new((cx + math.cos(ang) * r, cy + math.sin(ang) * r, cz - h / 2)))
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for i in range(2 * n):
        j = (i + 1) % (2 * n)
        bm.faces.new((bot[i], bot[j], top[j], top[i]))


# ───────────── 공장 건물 ─────────────
FW, FD, FH = 44, 28, 16


def building():
    bm = bmesh.new()
    add_box(bm, (0, 0, -0.25), (FW, FD, 0.5))
    finish("Factory_Floor", bm, "Concrete", uvscale=0.125)
    bm = bmesh.new()  # 노란 안전선 (통로 경계)
    for y in (-5.2, 5.2):
        add_box(bm, (0, y, 0.02), (FW - 4, 0.25, 0.04))
    for x in (-21, 21):
        add_box(bm, (x, 0, 0.02), (0.25, 10.4, 0.04))
    finish("Factory_FloorLines", bm, "Yellow")
    bm = bmesh.new()  # 뒤 벽 + 왼쪽 벽 (오른쪽·앞은 열어 둠: 카메라·플레이어 쪽)
    add_box(bm, (0, FD / 2 + 0.25, FH / 2), (FW, 0.5, FH))
    add_box(bm, (-FW / 2 - 0.25, 0, FH / 2), (0.5, FD, FH))
    finish("Factory_Walls", bm, "Wall", uvscale=0.0625)
    bm = bmesh.new()  # 뒤 벽 창문 (높이 9~13)
    for x in (-15, -5, 5, 15):
        add_box(bm, (x, FD / 2 - 0.02, 11), (7, 0.1, 4))
    finish("Factory_Windows", bm, "Window", uvscale=0.14)
    bm = bmesh.new()  # 철골 기둥 + 위 들보
    for x in (-21.5, -7, 7, 21.5):
        add_box(bm, (x, FD / 2 - 0.6, FH / 2), (0.8, 0.8, FH))
        add_box(bm, (x, 0, FH - 0.5), (0.6, FD, 0.8))
    add_box(bm, (0, FD / 2 - 0.6, FH - 0.5), (FW, 0.6, 0.8))
    finish("Factory_Beams", bm, "Frame")
    # 매달린 조명 6개
    bm = bmesh.new()
    lamps = [(x, y) for x in (-14, 0, 14) for y in (-3, 6)]
    for x, y in lamps:
        add_rod(bm, (x, y, FH - 0.9), (x, y, FH - 4), 0.05, seg=8)
        add_lathe(bm, [(0.12, 0.0), (0.9, -0.6), (0.95, -0.7), (0.12, -0.05)], center=(x, y, FH - 4), seg=24)
    finish("Factory_Lamps", bm, "SteelDark", smooth=True)
    bm = bmesh.new()
    for x, y in lamps:
        add_cyl(bm, (x, y, FH - 4.55), 0.6, 0.06, seg=24)
    finish("Factory_LampLight", bm, "LampOn")
    # 흰 울타리 (앞쪽 통로 경계): 끝이 둥근 말뚝 + 가로대 2줄
    bm = bmesh.new()
    for x in np.arange(-18, 18.1, 1.2):
        add_box(bm, (x, -6.0, 0.55), (0.32, 0.16, 1.1), bevel=0.07)
        add_ball(bm, (x, -6.0, 1.12), 0.17, seg=10)
    add_box(bm, (0, -6.08, 0.85), (36.4, 0.12, 0.16), bevel=0.05)
    add_box(bm, (0, -6.08, 0.35), (36.4, 0.12, 0.16), bevel=0.05)
    finish("Factory_Railing", bm, "White", smooth=True)


# ───────────── 생산 라인 ─────────────
BELT_Z = 3.2  # 벨트 윗면
LINE_Y = 0.0


def hopper_tower():
    x0 = -17
    bm = bmesh.new()  # 철골 받침 (4 기둥 + 가로대 + 위 발판)
    for dx in (-2.2, 2.2):
        for dy in (-2.0, 2.4):
            add_box(bm, (x0 + dx, dy, 3.5), (0.3, 0.3, 7.0))
    for z in (2.5, 6.8):
        add_box(bm, (x0, -2.0, z), (4.7, 0.2, 0.2))
        add_box(bm, (x0, 2.4, z), (4.7, 0.2, 0.2))
        add_box(bm, (x0 - 2.2, 0.2, z), (0.2, 4.6, 0.2))
        add_box(bm, (x0 + 2.2, 0.2, z), (0.2, 4.6, 0.2))
    finish("Line_HopperFrame", bm, "Frame")
    bm = bmesh.new()  # 사다리 (오른쪽 앞)
    for dx in (-0.35, 0.35):
        add_box(bm, (x0 + 2.8 + dx, -2.3, 3.6), (0.1, 0.1, 7.2))
    for z in np.arange(0.5, 7.2, 0.6):
        add_box(bm, (x0 + 2.8, -2.3, z), (0.8, 0.08, 0.08))
    finish("Line_Ladder", bm, "Yellow")
    bm = bmesh.new()  # 위 발판 (위험 줄무늬)
    add_box(bm, (x0, 0.2, 7.0), (4.8, 4.8, 0.2))
    finish("Line_Deck", bm, "Hazard", uvscale=0.5)
    # 투명 설탕 통 2개 + 속 설탕 + 아래 깔때기
    bm = bmesh.new()
    sugar = bmesh.new()
    for dx in (-1.1, 1.1):
        add_box(bm, (x0 + dx, 0.2, 9.2), (2.0, 3.6, 4.0), bevel=0.08)
        add_lathe(bm, [(0.2, 0.0), (0.95, 1.2)], center=(x0 + dx, 0.2, 6.0), seg=4)
        add_box(sugar, (x0 + dx, 0.2, 8.4), (1.8, 3.4, 2.3))
    finish("Line_Hoppers", bm, "Glass")
    finish("Line_HopperSugar", sugar, "Sugar")
    # 나사 공급관: 통 아래 → 솥 위
    bm = bmesh.new()
    for dx, kx in ((-1.1, -11.8), (1.1, -9.2)):
        add_rod(bm, (x0 + dx, 0.2, 6.0), (x0 + dx, 0.2, 7.2 - 2.0), 0.18)
        add_rod(bm, (x0 + dx, 0.2, 5.2), (kx, 0.6, 6.6), 0.2)
    finish("Line_FeedPipes", bm, "Steel", smooth=True)


def kettles():
    bm, jacket, gauge, valves = bmesh.new(), bmesh.new(), bmesh.new(), bmesh.new()
    for kx in (-11.8, -9.2):
        c = (kx, 0.6, 2.4)
        add_lathe(bm, [(0.0, 0.0), (0.25, 0.0), (0.3, 0.3), (1.15, 1.1), (1.2, 3.6), (1.28, 3.7), (1.28, 3.85), (0.0, 3.85)], center=c, seg=40)
        add_lathe(jacket, [(1.22, 1.4), (1.3, 1.45), (1.3, 3.1), (1.22, 3.15)], center=c, seg=40)
        for a in range(3):  # 다리
            ang = a * 2 * math.pi / 3 + 0.5
            add_rod(bm, (kx + math.cos(ang) * 1.0, 0.6 + math.sin(ang) * 1.0, 3.6), (kx + math.cos(ang) * 1.3, 0.6 + math.sin(ang) * 1.3, 0.0), 0.08)
        add_cyl(gauge, (kx, 0.6 - 1.35, 4.9), 0.3, 0.08, axis="Y")  # 앞 계기판
        add_cyl(valves, (kx + 0.7, 0.6 - 1.1, 3.0), 0.16, 0.12, axis="Y")
        add_rod(bm, (kx, 0.6, 2.4), (kx, -0.6, 2.4), 0.12)  # 아래 배출관
    add_rod(bm, (-11.8, -0.6, 2.4), (-6.0, -0.6, 2.4), 0.12)
    add_rod(bm, (-6.0, -0.6, 2.4), (-6.0, LINE_Y, 6.6), 0.12)  # 노즐대로 올라감
    finish("Line_Kettles", bm, "Steel", smooth=True)
    finish("Line_KettleJacket", jacket, "Red", smooth=True)
    finish("Line_KettleGauge", gauge, "White", smooth=True)
    finish("Line_KettleValves", valves, "Red", smooth=True)


def conveyor():
    x0, x1 = -8.0, 16.0
    L = x1 - x0
    cx = (x0 + x1) / 2
    bm = bmesh.new()
    add_box(bm, (cx, LINE_Y, BELT_Z - 0.06), (L, 2.8, 0.12))
    finish("Line_Belt", bm, "Belt", uvscale=0.5)
    bm = bmesh.new()  # 프레임 + 다리 + 롤러 + 옆 가드
    add_box(bm, (cx, LINE_Y, BELT_Z - 0.4), (L + 0.4, 3.2, 0.5))
    for x in np.arange(x0 + 0.5, x1, 3.0):
        for y in (-1.3, 1.3):
            add_box(bm, (x, LINE_Y + y, (BELT_Z - 0.6) / 2), (0.25, 0.25, BELT_Z - 0.6))
    for x in (x0, x1):
        add_cyl(bm, (x, LINE_Y, BELT_Z - 0.3), 0.3, 3.0, axis="Y")
    for y in (-1.55, 1.55):
        add_box(bm, (cx, LINE_Y + y, BELT_Z + 0.2), (L, 0.1, 0.4))
    finish("Line_ConveyorFrame", bm, "SteelDark")
    bm, dal = bmesh.new(), bmesh.new()  # 틀 쟁반 (2 × 3칸) + 노즐 지난 뒤부터 달고나
    for i, x in enumerate(np.arange(x0 + 1.2, x1 - 0.6, 2.2)):
        add_box(bm, (x, LINE_Y, BELT_Z + 0.06), (1.9, 2.4, 0.12), bevel=0.03)
        if x > -5.5:
            for dx in (-0.45, 0.45):
                for dy in (-0.75, 0.0, 0.75):
                    c = (x + dx, LINE_Y + dy, BELT_Z + 0.16)
                    if x > 3.2:  # 프레스 지난 뒤: 별 모양으로 찍힘
                        add_star_disc(dal, c, 0.33, 0.15, 0.07)
                    else:
                        add_lathe(dal, [(0.0, 0.0), (0.3, 0.0), (0.32, 0.04), (0.22, 0.1), (0.0, 0.12)], center=c, seg=16)
    finish("Line_Trays", bm, "Steel")
    finish("Line_Dalgona", dal, "Dalgona", smooth=True)


def depositor():
    x = -5.5
    bm = bmesh.new()
    for y in (-1.9, 1.9):
        add_box(bm, (x, LINE_Y + y, 3.4), (0.3, 0.3, 6.8))
    add_box(bm, (x, LINE_Y, 6.8), (1.0, 4.2, 0.6), bevel=0.04)
    finish("Line_DepositorFrame", bm, "Frame")
    bm = bmesh.new()  # 반죽 통 + 노즐 6개
    add_box(bm, (x, LINE_Y, 5.8), (1.2, 3.2, 1.2), bevel=0.06)
    for dx in (-0.3, 0.3):
        for dy in (-0.9, 0.0, 0.9):
            add_cyl(bm, (x + dx, LINE_Y + dy, 4.9), 0.12, 0.6, seg=12, r2=0.05)
    finish("Line_Depositor", bm, "Steel", smooth=True)


def press():
    x = 1.5
    bm = bmesh.new()  # 기둥 (위험 줄무늬)
    for y in (-2.3, 2.3):
        add_box(bm, (x, LINE_Y + y, 4.8), (1.0, 0.9, 9.6))
    finish("Line_PressColumns", bm, "Hazard", uvscale=0.5)
    bm = bmesh.new()  # 위 들보 + 아래 받침
    add_box(bm, (x, LINE_Y, 9.4), (2.6, 5.8, 1.4), bevel=0.06)
    add_box(bm, (x, LINE_Y, BELT_Z - 0.75), (2.6, 3.4, 0.5))
    finish("Line_PressBody", bm, "Frame")
    bm = bmesh.new()  # 유압 실린더 2개 + 피스톤
    for y in (-0.8, 0.8):
        add_cyl(bm, (x, LINE_Y + y, 7.6), 0.45, 2.2)
        add_cyl(bm, (x, LINE_Y + y, 5.9), 0.2, 1.6)
    finish("Line_PressCylinders", bm, "Steel", smooth=True)
    bm = bmesh.new()  # 도장판 (고른 도안이 끼워짐)
    add_box(bm, (x, LINE_Y, 5.0), (2.2, 2.8, 0.4), bevel=0.05)
    finish("Line_PressHead", bm, "SteelDark")
    bm = bmesh.new()
    for dx in (-0.45, 0.45):
        for dy in (-0.75, 0.0, 0.75):
            add_star_disc(bm, (x + dx, LINE_Y + dy, 4.75), 0.33, 0.15, 0.1)
    finish("Line_PressStamps", bm, "Copper")
    bm = bmesh.new()  # 프레스 위 경고등 2개
    for y in (-2.3, 2.3):
        add_cyl(bm, (x, LINE_Y + y, 9.85), 0.22, 0.4, seg=16)
    finish("Line_PressBeacons", bm, "BeaconY")


def cooling_tunnel():
    x0, x1 = 5.5, 11.5
    cx = (x0 + x1) / 2
    bm = bmesh.new()
    add_box(bm, (cx, LINE_Y, BELT_Z + 1.4), (x1 - x0, 3.6, 0.25), bevel=0.04)  # 지붕
    for y in (-1.8, 1.8):
        add_box(bm, (cx, LINE_Y + y, BELT_Z + 0.7), (x1 - x0, 0.2, 1.6))
    finish("Line_Tunnel", bm, "Steel")
    bm = bmesh.new()  # 지붕 환풍기 2개
    for x in (cx - 1.5, cx + 1.5):
        add_cyl(bm, (x, LINE_Y, BELT_Z + 1.7), 0.8, 0.4)
    finish("Line_TunnelFans", bm, "SteelDark", smooth=True)
    bm = bmesh.new()  # 입구·출구 비닐 커튼 (가는 띠)
    for x in (x0, x1):
        for y in np.arange(-1.5, 1.6, 0.35):
            add_box(bm, (x, LINE_Y + y, BELT_Z + 0.7), (0.03, 0.3, 1.3))
    finish("Line_Curtains", bm, "Curtain")


def output():
    x = 17.0
    bm = bmesh.new()
    add_box(bm, (x, LINE_Y, BELT_Z - 0.9), (2.4, 2.6, 0.1), rot=Matrix.Rotation(-0.5, 4, "Y"))
    for y in (-1.3, 1.3):
        add_box(bm, (x, LINE_Y + y, BELT_Z - 0.7), (2.4, 0.08, 0.5), rot=Matrix.Rotation(-0.5, 4, "Y"))
    finish("Line_Chute", bm, "Steel")
    bm, dal = bmesh.new(), bmesh.new()  # 받는 상자 3개 + 달고나 더미
    for i, (bx, by) in enumerate(((19.2, 0.0), (19.2, -2.6), (19.2, 2.6))):
        add_box(bm, (bx, by, 0.7), (2.2, 2.2, 1.4), bevel=0.05)
        for k in range(10):
            add_star_disc(dal, (bx + random.uniform(-0.7, 0.7), by + random.uniform(-0.7, 0.7), 1.3 + k * 0.03), 0.33, 0.15, 0.06)
    finish("Line_Crates", bm, "Crate")
    finish("Line_CrateDalgona", dal, "Dalgona")


def console():
    x, y = 1.5, -4.2
    bm = bmesh.new()  # 받침 상자
    add_box(bm, (x, y, 1.6), (4.2, 1.4, 3.2), bevel=0.06)
    finish("Line_ConsoleBody", bm, "SteelDark")
    # 기울어진 판 (플레이어 쪽으로 35°): 텍스처 한 장(4.1 × 2.2)이 테두리 위에 딱 붙음
    tilt = Matrix.Rotation(math.radians(35), 3, "X")
    nrm = tilt @ Vector((0, 0, 1))
    c0 = Vector((x, y + 0.02, 3.5)) + nrm * 0.075
    bm = bmesh.new()
    uv = bm.loops.layers.uv.verify()
    corners = [(-2.05, -1.1), (2.05, -1.1), (2.05, 1.1), (-2.05, 1.1)]
    vs = [bm.verts.new(c0 + tilt @ Vector((u, v, 0))) for u, v in corners]
    f = bm.faces.new(vs)
    for l, (u, v) in zip(f.loops, corners):
        l[uv].uv = (u / 4.1 + 0.5, v / 2.2 + 0.5)
    bm.normal_update()
    me = bpy.data.meshes.new("Line_ConsolePanel")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("Line_ConsolePanel", me)
    scene.collection.objects.link(o)
    o.data.materials.append(M("Panel"))
    PARTS.append(("Line_ConsolePanel", "Panel"))
    bm = bmesh.new()  # 판 테두리
    add_box(bm, (x, y + 0.02, 3.5), (4.3, 2.3, 0.12), rot=Matrix.Rotation(math.radians(35), 4, "X"))
    finish("Line_ConsoleRim", bm, "Steel")
    bm = bmesh.new()  # 버섯 버튼 (시작 초록 · 정지 빨강)
    add_cyl(bm, (x - 1.2, y - 0.75, 3.0), 0.28, 0.25, axis="Y")
    finish("Line_StartButton", bm, "Green", smooth=True)
    bm = bmesh.new()
    add_cyl(bm, (x + 1.2, y - 0.75, 3.0), 0.32, 0.25, axis="Y")
    finish("Line_StopButton", bm, "Red", smooth=True)
    # 3색 경고탑
    bm = bmesh.new()
    add_rod(bm, (x + 2.4, y + 0.5, 3.2), (x + 2.4, y + 0.5, 5.4), 0.06)
    finish("Line_TowerPole", bm, "SteelDark", smooth=True)
    for k, mname in enumerate(("BeaconG", "BeaconY", "BeaconR")):
        bm = bmesh.new()
        add_cyl(bm, (x + 2.4, y + 0.5, 5.6 + k * 0.42), 0.2, 0.4, seg=16)
        finish(f"Line_Tower{mname[-1]}", bm, mname, smooth=True)


# ───────────── 귀여운 장식 (사용자 요청 2026-11-19: 둥글둥글하고 귀엽게, 파스텔 사탕 공장 느낌) ─────────────
def cute_factory():
    # 설탕 통·솥 위 사탕 공 (기계 머리 장식)
    bm = bmesh.new()
    for dx in (-1.1, 1.1):
        add_ball(bm, (-17 + dx, 0.2, 11.55), 0.5)
    finish("Deco_HopperBalls", bm, "Pink", smooth=True)
    bm = bmesh.new()
    for kx in (-11.8, -9.2):
        add_ball(bm, (kx, 0.6, 6.55), 0.4)
    finish("Deco_KettleBalls", bm, "Lemon", smooth=True)
    bm = bmesh.new()
    add_ball(bm, (1.5, 0, 10.45), 0.55)
    finish("Deco_PressBall", bm, "Mint", smooth=True)
    # 벽 장식: 커다란 막대사탕 (뒤 벽 앞)
    lollipop("Deco_Lolli1", -20.5, 12.6, 0, 4.0, 1.3, "Pink")
    lollipop("Deco_Lolli2", 20.5, 12.6, 0, 3.2, 1.1, "Sky")
    lollipop("Deco_Lolli3", -9.0, 12.8, 0, 2.6, 0.9, "Lemon")
    # 울타리 밖 둥근 덤불 + 앞쪽 잔디 띠
    bm = bmesh.new()
    add_box(bm, (0, -11.0, 0.05), (FW, 6.0, 0.1), bevel=0.04)
    finish("Deco_Lawn", bm, "Grass")
    bm = bmesh.new()
    for i, x in enumerate(np.arange(-19, 19.5, 2.6)):
        add_ball(bm, (x, -7.2, 0.45), 0.6 + 0.12 * (i % 3), squash=0.85)
    finish("Deco_Bushes", bm, "Bush", smooth=True)
    bm = bmesh.new()  # 덤불 사이 분홍·보라 꽃 덤불
    for i, x in enumerate(np.arange(-17.7, 19, 5.2)):
        add_ball(bm, (x, -7.6, 0.4), 0.45, squash=0.9)
    finish("Deco_FlowerBushes", bm, "Lilac", smooth=True)
    # 앞 모서리 소용돌이 사탕 기둥 2개 (무지개 고리 쌓기)
    cols = ["Pink", "Lemon", "Mint", "Sky", "Lilac"]
    for side, x in (("L", -20.0), ("R", 20.0)):
        groups = {c: bmesh.new() for c in cols}
        for k in range(14):
            R = 1.15 - 0.03 * k
            add_ring(groups[cols[k % 5]], (x, -9.4, 0.3 + k * 0.42), R, 0.24)
        for c, bm in groups.items():
            finish(f"Deco_Swirl{side}_{c}", bm, c, smooth=True)
        bm = bmesh.new()
        add_ball(bm, (x, -9.4, 0.3 + 14 * 0.42 + 0.1), 0.7)
        finish(f"Deco_Swirl{side}_Top", bm, "White", smooth=True)


def cute_line():
    bm = bmesh.new()
    add_ball(bm, (-4.4, 0.3, 6.4), 0.42)
    finish("L4_DecoHopperBall", bm, "Pink", smooth=True)
    bm = bmesh.new()
    add_ball(bm, (0.4, 0, 5.85), 0.36)
    finish("L4_DecoPressBall", bm, "Lemon", smooth=True)
    lollipop("L4_DecoLolli", -5.0, -1.1, 2.35, 1.4, 0.5, "Pink")


# ───────────── Lv4 연속 생산 설비 (컨베이어 라인 기계 한 대) ─────────────
# 사용자 결정 2026-11-19 (docs/SHOP_GROWTH_PLAN.md 2-1·5장): 4단계 = 연속 생산 설비. 가정용 미니 메이커는 뺌.
# 공장(Lv5)보다 작은 기계 한 대: 청록 칠 받침 위에 설탕 통 → 솥 1개 → 노즐 3개 → 짧은 컨베이어 → 작은 프레스 → 식힘 덮개 → 받는 상자.
# 바닥에 놓는 기계 (길이 약 12 · 깊이 3.4 · 높이 약 6.3). 원점 = 바닥 가운데, 앞(플레이어 쪽) = -Y. 부품 이름 L4_*
def build_line():
    BZ = 2.8  # 벨트 윗면
    x0, x1 = -3.2, 4.4  # 벨트
    bm = bmesh.new()  # 받침 캐비닛 (칠한 철판) + 발
    add_box(bm, (0.2, 0, 1.25), (11.0, 2.8, 2.1), bevel=0.06)
    finish("L4_Cabinet", bm, "Paint")
    bm = bmesh.new()
    for x in (-5.0, 5.4):
        for y in (-1.2, 1.2):
            add_box(bm, (x, y, 0.1), (0.4, 0.4, 0.2))
    add_box(bm, (0.2, 0, 2.35), (11.2, 3.0, 0.1))  # 윗판 테두리
    add_box(bm, (0.2, -1.42, 0.55), (10.6, 0.04, 0.12))  # 아래 걸레받이 줄
    finish("L4_Trim", bm, "SteelDark")
    bm = bmesh.new()  # 앞면 점검 문 4개 (크림색 판)
    for x in (-3.6, -1.0, 1.6, 4.2):
        add_box(bm, (x, -1.42, 1.25), (2.2, 0.04, 1.5), bevel=0.02)
    finish("L4_Doors", bm, "Cream")
    bm = bmesh.new()  # 문 손잡이
    for x in (-3.6, -1.0, 1.6, 4.2):
        add_box(bm, (x + 0.8, -1.47, 1.35), (0.08, 0.06, 0.5))
    finish("L4_Handles", bm, "Steel")
    # ① 설탕 통 (투명) + 깔때기, 솥 위
    bm, sugar = bmesh.new(), bmesh.new()
    add_box(bm, (-4.4, 0.3, 5.35), (1.4, 1.4, 1.5), bevel=0.05)
    add_lathe(bm, [(0.15, 0.0), (0.7, 0.55)], center=(-4.4, 0.3, 4.05), seg=4)
    add_box(sugar, (-4.4, 0.3, 5.0), (1.3, 1.3, 0.8))
    finish("L4_Hopper", bm, "Glass")
    finish("L4_HopperSugar", sugar, "Sugar")
    bm = bmesh.new()  # 설탕 통 받침 기둥
    for dx in (-0.65, 0.65):
        add_box(bm, (-4.4 + dx, 1.0, 4.05), (0.12, 0.12, 3.4))
    add_box(bm, (-4.4, 1.0, 4.6), (1.42, 0.12, 0.12))
    finish("L4_HopperFrame", bm, "SteelDark")
    # ② 솥 1개 (스테인리스 + 빨간 가열 띠) + 계기 + 배관 → 노즐
    bm, jacket, gauge = bmesh.new(), bmesh.new(), bmesh.new()
    c = (-4.4, 0.1, 2.4)
    add_lathe(bm, [(0.0, 0.0), (0.2, 0.0), (0.75, 0.5), (0.8, 1.55), (0.86, 1.62), (0.86, 1.7), (0.0, 1.7)], center=c, seg=36)
    add_lathe(jacket, [(0.82, 0.7), (0.88, 0.74), (0.88, 1.3), (0.82, 1.34)], center=c, seg=36)
    add_cyl(gauge, (-4.4, 0.1 - 0.9, 3.35), 0.2, 0.06, axis="Y")
    add_rod(bm, (-3.7, 0.1, 3.0), (-2.4, 0.0, 3.0), 0.09)
    add_rod(bm, (-2.4, 0.0, 3.0), (-2.4, 0.0, 4.05), 0.09)
    finish("L4_Kettle", bm, "Steel", smooth=True)
    finish("L4_KettleJacket", jacket, "Red", smooth=True)
    finish("L4_KettleGauge", gauge, "White", smooth=True)
    # ③ 노즐대 (문형) + 반죽 통 + 노즐 3개
    bm = bmesh.new()
    for y in (-1.15, 1.15):
        add_box(bm, (-2.4, y, 3.4), (0.2, 0.2, 2.0))
    add_box(bm, (-2.4, 0, 4.35), (0.6, 2.5, 0.25))
    finish("L4_DepositorFrame", bm, "Paint")
    bm = bmesh.new()
    add_box(bm, (-2.4, 0, 3.85), (0.8, 1.6, 0.7), bevel=0.05)
    for dy in (-0.5, 0.0, 0.5):
        add_cyl(bm, (-2.4, dy, 3.35), 0.08, 0.35, seg=12, r2=0.035)
    finish("L4_Depositor", bm, "Steel", smooth=True)
    # ④ 컨베이어: 벨트 + 옆 가드 + 롤러 + 틀 쟁반(2×2칸) + 달고나
    L, cx = x1 - x0, (x0 + x1) / 2
    bm = bmesh.new()
    add_box(bm, (cx, 0, BZ - 0.05), (L, 1.7, 0.1))
    finish("L4_Belt", bm, "Belt", uvscale=0.5)
    bm = bmesh.new()
    for y in (-0.95, 0.95):
        add_box(bm, (cx, y, BZ + 0.05), (L + 0.3, 0.12, 0.35))
    for x in (x0, x1):
        add_cyl(bm, (x, 0, BZ - 0.25), 0.22, 1.9, axis="Y")
    add_box(bm, (cx, 0, BZ - 0.3), (L, 1.9, 0.3))
    finish("L4_BeltFrame", bm, "SteelDark")
    bm, dal = bmesh.new(), bmesh.new()
    for x in np.arange(x0 + 0.6, x1 - 0.3, 1.25):
        add_box(bm, (x, 0, BZ + 0.05), (1.05, 1.45, 0.08), bevel=0.02)
        if x > -2.3:
            for dx in (-0.26, 0.26):
                for dy in (-0.36, 0.36):
                    cc = (x + dx, dy, BZ + 0.12)
                    if x > 0.9:  # 프레스 지난 뒤: 별 모양
                        add_star_disc(dal, cc, 0.22, 0.1, 0.05)
                    else:
                        add_lathe(dal, [(0.0, 0.0), (0.2, 0.0), (0.21, 0.03), (0.15, 0.07), (0.0, 0.08)], center=cc, seg=14)
    finish("L4_Trays", bm, "Steel")
    finish("L4_Dalgona", dal, "Dalgona", smooth=True)
    # ⑤ 작은 프레스: 양옆 판(위험 줄무늬) + 위 상자 + 실린더 1개 + 도장판
    px = 0.4
    bm = bmesh.new()
    for y in (-1.15, 1.15):
        add_box(bm, (px, y, 3.9), (1.2, 0.25, 2.3))
    finish("L4_PressSides", bm, "Hazard", uvscale=0.5)
    bm = bmesh.new()
    add_box(bm, (px, 0, 5.25), (1.4, 2.6, 0.7), bevel=0.05)
    finish("L4_PressTop", bm, "Paint")
    bm = bmesh.new()
    add_cyl(bm, (px, 0, 4.55), 0.3, 0.8)
    add_cyl(bm, (px, 0, 3.85), 0.12, 0.7)
    finish("L4_PressCylinder", bm, "Steel", smooth=True)
    bm = bmesh.new()
    add_box(bm, (px, 0, 3.45), (1.0, 1.35, 0.22), bevel=0.03)
    finish("L4_PressHead", bm, "SteelDark")
    bm = bmesh.new()
    for dx in (-0.26, 0.26):
        for dy in (-0.36, 0.36):
            add_star_disc(bm, (px + dx, dy, 3.3), 0.22, 0.1, 0.07)
    finish("L4_PressStamps", bm, "Copper")
    # ⑥ 식힘 덮개 (둥근 지붕) + 환풍구
    bm = bmesh.new()
    prof = []
    for k in range(9):
        a = math.pi * k / 8
        prof.append((math.cos(a) * 1.0, math.sin(a) * 0.7))
    # 반원 단면을 X축으로 밀어 낸 덮개
    xa, xb = 1.8, 3.9
    va = [bm.verts.new((xa, y, BZ + 0.2 + z)) for y, z in prof]
    vb = [bm.verts.new((xb, y, BZ + 0.2 + z)) for y, z in prof]
    for i in range(len(prof) - 1):
        bm.faces.new((va[i], va[i + 1], vb[i + 1], vb[i]))
    finish("L4_CoolCover", bm, "Steel", smooth=True)
    bm = bmesh.new()
    add_cyl(bm, ((xa + xb) / 2, 0, BZ + 0.95), 0.32, 0.15, seg=20)
    finish("L4_CoolFan", bm, "SteelDark", smooth=True)
    # ⑦ 미끄럼판 + 받는 상자
    bm = bmesh.new()
    add_box(bm, (5.0, 0, BZ - 0.45), (1.2, 1.5, 0.08), rot=Matrix.Rotation(-0.55, 4, "Y"))
    finish("L4_Chute", bm, "Steel")
    bm, dal = bmesh.new(), bmesh.new()
    add_box(bm, (6.3, 0, 0.55), (1.5, 1.7, 1.1), bevel=0.04)
    for k in range(8):
        add_star_disc(dal, (6.3 + random.uniform(-0.45, 0.45), random.uniform(-0.55, 0.55), 1.12 + k * 0.025), 0.22, 0.1, 0.05)
    finish("L4_Crate", bm, "Crate")
    finish("L4_CrateDalgona", dal, "Dalgona")
    # ⑧ 앞 조작판 (공장 제어판과 같은 그림: 계기판 3개 + 도안 버튼 6개) + 시작·정지 + 경고등
    tilt = Matrix.Rotation(math.radians(30), 3, "X")
    nrm = tilt @ Vector((0, 0, 1))
    cpx, cpy, cpz = -0.9, -1.75, 2.75
    bm = bmesh.new()
    add_box(bm, (cpx, cpy + 0.15, cpz - 0.5), (2.3, 0.5, 1.0))
    add_box(bm, (cpx, cpy, cpz), (2.3, 1.3, 0.1), rot=Matrix.Rotation(math.radians(30), 4, "X"))
    finish("L4_ControlBox", bm, "SteelDark")
    bm = bmesh.new()
    uv = bm.loops.layers.uv.verify()
    c0 = Vector((cpx, cpy, cpz)) + nrm * 0.06
    corners = [(-1.1, -0.59), (1.1, -0.59), (1.1, 0.59), (-1.1, 0.59)]
    vs = [bm.verts.new(c0 + tilt @ Vector((u, v, 0))) for u, v in corners]
    f = bm.faces.new(vs)
    for l, (u, v) in zip(f.loops, corners):
        l[uv].uv = (u / 2.2 + 0.5, v / 1.18 + 0.5)
    bm.normal_update()
    me = bpy.data.meshes.new("L4_ControlPanel")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("L4_ControlPanel", me)
    scene.collection.objects.link(o)
    o.data.materials.append(M("Panel"))
    PARTS.append(("L4_ControlPanel", "Panel"))
    bm = bmesh.new()
    add_cyl(bm, (cpx - 1.45, cpy + 0.05, cpz - 0.25), 0.16, 0.16, axis="Y")
    finish("L4_StartButton", bm, "Green", smooth=True)
    bm = bmesh.new()
    add_cyl(bm, (cpx + 1.45, cpy + 0.05, cpz - 0.25), 0.18, 0.16, axis="Y")
    finish("L4_StopButton", bm, "Red", smooth=True)
    bm = bmesh.new()
    add_rod(bm, (5.4, 1.1, 2.4), (5.4, 1.1, 4.2), 0.05)
    finish("L4_TowerPole", bm, "SteelDark", smooth=True)
    for k, mname in enumerate(("BeaconG", "BeaconY", "BeaconR")):
        bm = bmesh.new()
        add_cyl(bm, (5.4, 1.1, 4.35 + k * 0.32), 0.15, 0.3, seg=16)
        finish(f"L4_Tower{mname[-1]}", bm, mname, smooth=True)


MODE = argv[1] if len(argv) > 1 else "factory"
if MODE == "line":
    build_line()
    cute_line()
else:
    building()
    hopper_tower()
    kettles()
    conveyor()
    depositor()
    press()
    cooling_tunnel()
    output()
    console()
    cute_factory()
NAME = "line" if MODE == "line" else "factory"

# 부품 목록 (Roblox에서 색·재질 칠할 때 씀)
lines = ["# 이름\t재질키\tRoblox 재질\t색(텍스처 없을 때)\t텍스처\t경계 상자 가운데\t크기\t삼각형"]
total = 0
for o in scene.objects:
    if o.type != "MESH":
        continue
    m = o.data.materials[0]
    bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
    lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
    hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    total += tris
    texname = ""
    for n in m.node_tree.nodes:
        if n.type == "TEX_IMAGE":
            texname = n.image.name
    c, s = (lo + hi) / 2, hi - lo
    lines.append(f"{o.name}\t{m.name}\t{m['rbx']}\t{tuple(m['rgb'])}\t{texname}\t({c.x:.2f}, {c.y:.2f}, {c.z:.2f})\t({s.x:.2f}, {s.y:.2f}, {s.z:.2f})\t{tris}")
    if tris > 20000:
        print("[factory] WARNING over 20k tris:", o.name, tris)
with open(os.path.join(OUT, f"{NAME}_parts.txt"), "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")
print(f"[factory] parts={len(lines) - 1} tris={total}")

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, f"dalgona_{NAME}.glb"), export_format="GLB", use_selection=True, export_apply=True, export_image_format="AUTO")

# 미리 보기 2장: 앞 위에서 전체, 제어대·프레스 가까이
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.62, 0.66, 0.72, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.8
scene.world = world
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(55), math.radians(-20), math.radians(30))
scene.collection.objects.link(sun)
for x, y in ([(x, y) for x in (-14, 0, 14) for y in (-3, 6)] if MODE != "line" else [(-3, -4), (4, -4)]):
    L = bpy.data.objects.new("PL", bpy.data.lights.new("PL", "POINT"))
    L.data.energy = 600
    L.location = (x, y, FH - 5)
    scene.collection.objects.link(L)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "BLENDER_EEVEE"
scene.view_settings.view_transform = "Standard"
scene.render.resolution_x, scene.render.resolution_y = 2000, 1100


def shot(path, loc, target, lens):
    cam.location = loc
    cam.data.lens = lens
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, path)
    bpy.ops.render.render(write_still=True)


if MODE == "line":
    # 바닥 판 (미리 보기용, 내보내기 뒤라 glb에 안 들어감)
    bm = bmesh.new()
    add_box(bm, (0.5, 0, -0.05), (20, 12, 0.1))
    finish("PreviewFloor", bm, "Concrete", uvscale=0.125)
    shot("line_preview.png", (4, -17, 10), (0.6, 0, 2.8), 32)
    shot("line_preview2.png", (-1, -7.5, 5.2), (-0.6, -0.8, 2.9), 30)
else:
    shot("factory_preview.png", (6, -40, 24), (1, 0, 3), 30)
    shot("factory_preview2.png", (6, -14, 9), (1.5, -1, 4), 32)
print("[factory] done")
