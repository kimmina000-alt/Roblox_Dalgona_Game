# 시대별 달고나 기계 (업그레이드 순서) + 시대별 도구. docs/MACHINE_ERAS.md 참고.
#   1단계 1950~80년대 연탄 화로 + 구리 국자  → 이미 있음 (사용자 모델 dalgona_wharo.glb, dalgona_gukja.glb)
#   2단계 1990~2000년대 1세대 철제 달고나 판매기 (스테인리스 윗판 + 열선 화구 2개 + 금형 견본판 + 빨간 몸통 + 동전 투입구)
#   3단계 2000년대 후반~2010년대 2세대 분홍 캐릭터 자판기 (보라 안내판 + 동전기 + 둥근 버튼, 가운데 선반: 녹이는 컵 + 검은 누름판)
#   4단계 2020년대 가정용 미니 달고나 메이커 (파스텔 둥근 전기 화구 + 금색 다이얼) + 스테인리스 손잡이 냄비·누름판·헤라
# 실제 기계의 상표·캐릭터 그림은 따라 그리지 않는다 (색 면과 단순한 무늬만).
#
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/machines.py -- <출력 폴더>
# 결과: <출력>/dalgona_machines.glb (오브젝트 이름 = Roblox 메시 이름), machines_preview.png,
#       machines_parts.txt (부품 이름 · 색 · 재질 · 기준점에서 경계 상자 가운데까지 거리)
#
# 크기 = 게임 stud (1 Blender 단위 = 1 stud). 테이블 윗면 높이 3.5, 국자 그릇 지름 1.7 (지금 화로 자리에 놓이는 크기).
# 기계 원점 = 바닥 가운데 (테이블 윗면에 놓음). 앞(플레이어 쪽) = Blender -Y (Roblox로 가져오면 +Z가 됨, CLAUDE.md 참고).
# 화구 높이: 지금 철망 높이(테이블 위 3.8)와 비슷하게 → 국자·컵 높이 조작이 그대로 맞음.

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "."

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
PARTS = []  # (이름, 색, 재질)


def lin(c):
    return tuple(((v / 255) ** 2.2) for v in c)


MATS = {}


def mat(key, rgb, metal=0.0, rough=0.5):
    if key in MATS:
        return MATS[key]
    m = bpy.data.materials.new(key)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*lin(rgb), 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    m["rgb"] = rgb
    MATS[key] = m
    return m


# Roblox 재질 이름은 부품 목록에 같이 적어 둔다
STEEL = ("Steel", (200, 203, 208), 1.0, 0.28, "Metal")
STEEL_DARK = ("SteelDark", (120, 122, 126), 1.0, 0.4, "Metal")
ALU = ("Aluminum", (186, 186, 182), 1.0, 0.35, "Metal")
BLACK = ("Black", (34, 34, 36), 0.0, 0.5, "SmoothPlastic")
COIL = ("Coil", (60, 56, 52), 0.6, 0.5, "Metal")
RED_BODY = ("RedBody", (150, 34, 38), 0.2, 0.5, "Metal")
PINK = ("Pink", (244, 150, 196), 0.0, 0.45, "SmoothPlastic")
PURPLE = ("Purple", (156, 128, 214), 0.0, 0.45, "SmoothPlastic")
YELLOW = ("Yellow", (250, 206, 40), 0.0, 0.4, "SmoothPlastic")
BLUE = ("Blue", (40, 120, 220), 0.0, 0.4, "SmoothPlastic")
REDB = ("RedButton", (230, 50, 40), 0.0, 0.4, "SmoothPlastic")
WHITE = ("White", (244, 242, 236), 0.0, 0.5, "SmoothPlastic")
CREAM = ("Cream", (246, 238, 222), 0.0, 0.45, "SmoothPlastic")
MINT = ("Mint", (176, 222, 196), 0.0, 0.45, "SmoothPlastic")
GOLD = ("Gold", (214, 170, 80), 1.0, 0.3, "Metal")
GREEN_PL = ("GreenHandle", (40, 160, 90), 0.0, 0.4, "SmoothPlastic")
WOOD = ("Wood", (120, 74, 44), 0.0, 0.6, "Wood")
LIGHT_WOOD = ("LightWood", (222, 190, 140), 0.0, 0.6, "Wood")
STICKER_Y = ("StickerYellow", (250, 220, 90), 0.0, 0.6, "SmoothPlastic")
STICKER_W = ("StickerWhite", (250, 248, 240), 0.0, 0.6, "SmoothPlastic")


def finish(name, bm, spec, smooth=False):
    key, rgb, metal, rough, rbx = spec
    me = bpy.data.meshes.new(name)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)  # 돌려 만든 얇은 껍질도 바깥을 보게 (glb는 한쪽 면만 그림)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    o.data.materials.append(mat(key, rgb, metal, rough))
    for p in me.polygons:
        p.use_smooth = smooth
    PARTS.append((name, rgb, rbx))
    return o


def add_box(bm, center, size, bevel=0.0):
    m = Matrix.Translation(Vector(center)) @ Matrix.Diagonal((size[0], size[1], size[2], 1))
    r = bmesh.ops.create_cube(bm, size=1.0, matrix=m)
    if bevel > 0:
        edges = list({e for v in r["verts"] for e in v.link_edges})
        bmesh.ops.bevel(bm, geom=edges, offset=bevel, segments=2, affect="EDGES", clamp_overlap=True)


def add_cyl(bm, center, r, h, seg=40, axis="Z"):
    rot = Matrix.Identity(4)
    if axis == "Y":
        rot = Matrix.Rotation(math.pi / 2, 4, "X")
    elif axis == "X":
        rot = Matrix.Rotation(math.pi / 2, 4, "Y")
    m = Matrix.Translation(Vector(center)) @ rot
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r, depth=h, matrix=m)


def add_lathe(bm, profile, center=(0, 0, 0), seg=48, cap=False):
    cx, cy, cz = center
    rings = []
    for (r, z) in profile:
        rings.append([bm.verts.new((cx + math.cos(2 * math.pi * k / seg) * r, cy + math.sin(2 * math.pi * k / seg) * r, cz + z)) for k in range(seg)])
    for a, b in zip(rings, rings[1:]):
        for k in range(seg):
            k2 = (k + 1) % seg
            bm.faces.new((a[k], a[k2], b[k2], b[k]))
    if cap:
        c = bm.verts.new((cx, cy, cz + profile[0][1]))
        for k in range(seg):
            bm.faces.new((rings[0][(k + 1) % seg], rings[0][k], c))


def add_coil(bm, center, r0, r1, turns, wire, seg_per_turn=40):
    """평평한 나선 열선 (전기 화구). 굵기 wire인 사각 관을 나선을 따라 이음."""
    cx, cy, cz = center
    n = int(turns * seg_per_turn)
    prev = None
    for i in range(n + 1):
        t = i / n
        a = 2 * math.pi * turns * t
        r = r0 + (r1 - r0) * t
        p = Vector((cx + math.cos(a) * r, cy + math.sin(a) * r, cz))
        outward = Vector((math.cos(a), math.sin(a), 0))
        ring = [bm.verts.new(p + outward * dx + Vector((0, 0, dz))) for dx, dz in ((-wire, -wire), (wire, -wire), (wire, wire), (-wire, wire))]
        if prev:
            for k in range(4):
                bm.faces.new((prev[k], prev[(k + 1) % 4], ring[(k + 1) % 4], ring[k]))
        prev = ring


def add_star(bm, center, r_out, r_in, depth, points=5, rot=0.0):
    cx, cy, cz = center
    vs_top, vs_bot = [], []
    for i in range(points * 2):
        a = rot + math.pi / 2 + i * math.pi / points
        r = r_out if i % 2 == 0 else r_in
        vs_top.append(bm.verts.new((cx + math.cos(a) * r, cy + math.sin(a) * r, cz + depth / 2)))
        vs_bot.append(bm.verts.new((cx + math.cos(a) * r, cy + math.sin(a) * r, cz - depth / 2)))
    bm.faces.new(vs_top)
    bm.faces.new(list(reversed(vs_bot)))
    n = len(vs_top)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((vs_bot[i], vs_bot[j], vs_top[j], vs_top[i]))


def add_heart(bm, center, s, depth, seg=24):
    cx, cy, cz = center
    pts = []
    for i in range(seg):
        t = 2 * math.pi * i / seg
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x / 17 * s, y / 17 * s))
    top = [bm.verts.new((cx + x, cy + y, cz + depth / 2)) for x, y in pts]
    bot = [bm.verts.new((cx + x, cy + y, cz - depth / 2)) for x, y in pts]
    bm.faces.new(top)
    bm.faces.new(list(reversed(bot)))
    for i in range(seg):
        j = (i + 1) % seg
        bm.faces.new((bot[i], bot[j], top[j], top[i]))


def place(objs, offset):
    for o in objs:
        pv = o.get("pv", (0, 0))
        o.location = Vector(offset) + Vector((pv[0], pv[1], 0))


# ─────────────────────────── 2단계: 1세대 철제 달고나 판매기 (1990~2000년대) ───────────────────────────
# 사용자 사진: 스테인리스 윗판에 둥근 화구 2개(국자 2개), 가운데 작은 컵, 뒤쪽에 도안 금형 견본판(가로로 8칸),
# 몸통은 빨간 철판 + 은색 테두리, 앞면에 동전 투입기 3개와 가운데 나오는 구멍, 안에는 설탕 통(투명) + 배선.
def era2():
    W, D, H = 5.4, 3.6, 3.7  # 테이블 위 크기 (화구 높이 ≈ 3.75 → 지금 철망과 비슷)
    objs = []
    bm = bmesh.new()  # 빨간 몸통
    add_box(bm, (0, 0, (H - 0.25) / 2), (W - 0.12, D - 0.12, H - 0.25), bevel=0.04)
    objs.append(finish("Era2_Body", bm, RED_BODY))
    bm = bmesh.new()  # 스테인리스 윗판 (화구 2개 구멍 자리는 위에 링으로 덮음)
    add_box(bm, (0, 0, H - 0.12), (W, D, 0.24), bevel=0.05)
    # 아래 테두리 띠
    add_box(bm, (0, -D / 2 + 0.02, 0.12), (W, 0.08, 0.24), bevel=0.02)
    objs.append(finish("Era2_Top", bm, STEEL))
    # 화구 2개: 어두운 쇠 링 + 나선 열선
    bm = bmesh.new()
    for x in (-1.45, 1.45):
        add_lathe(bm, [(0.98, 0.0), (1.02, 0.05), (0.96, 0.08), (0.82, 0.02), (0.82, -0.06)], center=(x, -0.15, H), seg=48)
    objs.append(finish("Era2_BurnerRing", bm, STEEL_DARK, smooth=True))
    bm = bmesh.new()
    for x in (-1.45, 1.45):
        add_coil(bm, (x, -0.15, H + 0.02), 0.12, 0.74, 5.5, 0.035)
    objs.append(finish("Era2_Coil", bm, COIL))
    # 가운데 작은 쇠 컵 (소다·젓는 도구 꽂이)
    bm = bmesh.new()
    add_lathe(bm, [(0.0, 0.0), (0.32, 0.0), (0.34, 0.5), (0.3, 0.5), (0.28, 0.06), (0.0, 0.06)], center=(0, -0.1, H), seg=32)
    objs.append(finish("Era2_Cup", bm, STEEL, smooth=True))
    # 뒤쪽 금형 견본판: 기울어진 검은 쇠판 + 금색 도안 8칸 (별·하트·원·세모·우산 대신 단순 도형)
    bm = bmesh.new()
    add_box(bm, (0, D / 2 - 0.25, H + 0.75), (W - 0.2, 0.18, 1.3), bevel=0.04)
    add_box(bm, (-W / 2 + 0.25, D / 2 - 0.25, H + 0.35), (0.12, 0.12, 0.7))
    add_box(bm, (W / 2 - 0.25, D / 2 - 0.25, H + 0.35), (0.12, 0.12, 0.7))
    objs.append(finish("Era2_MoldPanel", bm, STEEL_DARK))
    bm = bmesh.new()
    xs = [-2.2 + i * 0.63 for i in range(8)]
    for i, x in enumerate(xs):
        c = (x, D / 2 - 0.36, H + 0.8)
        kind = i % 4
        if kind == 0:
            add_star(bm, c, 0.24, 0.1, 0.05, rot=0)
        elif kind == 1:
            add_heart(bm, c, 0.22, 0.05)
        elif kind == 2:
            add_cyl(bm, c, 0.21, 0.05, seg=24, axis="Y")
        else:
            add_star(bm, c, 0.24, 0.24 * 0.5, 0.05, points=3)
    # 도형 판이 뒤로 기울지 않게 Y 두께 방향으로 세움 (별·하트는 XY 평면에 만들어졌으니 X축으로 90° 돌림)
    bmesh.ops.rotate(bm, verts=[v for v in bm.verts], cent=(0, D / 2 - 0.36, H + 0.8), matrix=Matrix.Rotation(math.pi / 2, 3, "X"))
    objs.append(finish("Era2_Molds", bm, GOLD))
    # 앞면: 동전 투입기 3개(은색 판 + 검은 구멍), 가운데 나오는 구멍, 흰·노란 스티커
    bm = bmesh.new()
    for x in (-1.6, 0.0, 1.6):
        add_box(bm, (x, -D / 2 + 0.03, 1.15), (0.62, 0.08, 0.5), bevel=0.02)
    add_box(bm, (0, -D / 2 + 0.03, 0.55), (0.7, 0.1, 0.32), bevel=0.02)
    add_box(bm, (0, -D / 2 + 0.01, H - 0.45), (W - 0.2, 0.06, 0.14))  # 윗판 아래 은색 띠
    objs.append(finish("Era2_CoinPlates", bm, STEEL))
    bm = bmesh.new()
    for x in (-1.6, 0.0, 1.6):
        add_box(bm, (x - 0.12, -D / 2 - 0.02, 1.2), (0.05, 0.04, 0.22))
        add_box(bm, (x + 0.15, -D / 2 - 0.02, 1.1), (0.16, 0.04, 0.12))
    add_box(bm, (0, -D / 2 - 0.02, 0.52), (0.42, 0.06, 0.16))
    objs.append(finish("Era2_Slots", bm, BLACK))
    bm = bmesh.new()
    add_box(bm, (-0.6, -D / 2 - 0.0, 2.15), (1.9, 0.04, 0.62))
    objs.append(finish("Era2_StickerW", bm, STICKER_W))
    bm = bmesh.new()
    add_box(bm, (-1.95, -D / 2 - 0.0, 2.2), (0.36, 0.04, 0.5))
    add_box(bm, (1.2, -D / 2 - 0.0, 2.3), (1.0, 0.04, 0.3))
    objs.append(finish("Era2_StickerY", bm, STICKER_Y))
    return objs


# 2단계 도구: 알루미늄 국자 + 초록 플라스틱 손잡이 (사진 오른쪽 국자)
def era2_ladle():
    objs = []
    bm = bmesh.new()
    add_lathe(bm, [(0.0, -0.36), (0.45, -0.34), (0.72, -0.2), (0.85, 0.02), (0.88, 0.06), (0.84, 0.06), (0.8, 0.0), (0.68, -0.16), (0.42, -0.29), (0.0, -0.31)], seg=48)
    # 손잡이 앞쪽(쇠 부분)
    add_box(bm, (0, -1.25, 0.12), (0.16, 1.0, 0.05))
    objs.append(finish("Era2_Ladle", bm, ALU, smooth=True))
    bm = bmesh.new()
    add_box(bm, (0, -2.45, 0.22), (0.24, 1.5, 0.12), bevel=0.04)
    objs.append(finish("Era2_LadleGrip", bm, GREEN_PL))
    return objs


# ─────────────────────────── 3단계: 2세대 분홍 캐릭터 자판기 (2000년대 후반~2010년대) ───────────────────────────
# 레퍼런스(구글 이미지 '달고나 자판기 문방구'): 분홍 캐비닛, 위쪽 보라 안내판(만화 그림·풍선·구름), 동전기(은색),
# 둥근 버튼 (노랑 시작 · 파랑 · 빨강 불빛 · 흰색), 가운데 움푹한 선반: 왼쪽 알루미늄 컵(설탕 녹이기, 꼬치가 꽂힘),
# 오른쪽 검은 사각 누름판과 그 위 검은 원통 누름 손잡이, 아래 노란 주의 스티커. 그림은 따라 그리지 않고 색 도형만.
def era3():
    W, D, H = 4.6, 3.4, 5.8
    SHELF = 3.0  # 선반 높이 (테이블 위) → 컵 위치가 지금 국자와 비슷한 높이
    objs = []
    bm = bmesh.new()  # 분홍 캐비닛: 뒤판·옆판·바닥·선반 위 덮개
    add_box(bm, (0, D / 2 - 0.1, H / 2), (W, 0.2, H), bevel=0.04)  # 뒤판
    for x in (-W / 2 + 0.1, W / 2 - 0.1):
        add_box(bm, (x, 0, H / 2), (0.2, D, H), bevel=0.04)  # 옆판
    add_box(bm, (0, 0, SHELF / 2), (W, D, SHELF), bevel=0.04)  # 아래 몸통
    add_box(bm, (0, -0.1, H - 0.7), (W, D - 0.2, 1.4), bevel=0.04)  # 위 몸통 (안내판 뒤)
    objs.append(finish("Era3_Body", bm, PINK))
    bm = bmesh.new()  # 보라 안내판 (앞으로 살짝 기울어짐)
    add_box(bm, (0, -D / 2 - 0.02, H - 0.72), (W - 0.24, 0.08, 1.3), bevel=0.03)
    objs.append(finish("Era3_Panel", bm, PURPLE))
    bm = bmesh.new()  # 동전기 + 안내판 둘레 은색
    add_box(bm, (0.15, -D / 2 - 0.1, H - 0.7), (0.5, 0.1, 0.8), bevel=0.02)
    add_box(bm, (0, -D / 2 + 0.05, SHELF + 0.03), (W - 0.3, 0.12, 0.06))  # 선반 앞 모서리
    objs.append(finish("Era3_Coin", bm, STEEL))
    bm = bmesh.new()  # 버튼: 노랑(시작) · 파랑 · 흰색
    add_cyl(bm, (1.05, -D / 2 - 0.12, H - 0.5), 0.2, 0.12, axis="Y")
    objs.append(finish("Era3_ButtonY", bm, YELLOW, smooth=True))
    bm = bmesh.new()
    add_cyl(bm, (1.7, -D / 2 - 0.12, H - 0.5), 0.2, 0.12, axis="Y")
    add_cyl(bm, (-1.7, -D / 2 - 0.12, H - 1.05), 0.15, 0.1, axis="Y")
    objs.append(finish("Era3_ButtonB", bm, BLUE, smooth=True))
    bm = bmesh.new()
    add_cyl(bm, (1.4, -D / 2 - 0.12, H - 1.05), 0.18, 0.12, axis="Y")
    objs.append(finish("Era3_ButtonR", bm, REDB, smooth=True))
    bm = bmesh.new()  # 안내판 장식: 노란 별·구름 같은 도형 (그림 대신)
    add_star(bm, (-1.3, 0, 0), 0.28, 0.12, 0.04)
    add_cyl(bm, (-0.65, 0, 0.25), 0.16, 0.04, seg=20)
    bmesh.ops.rotate(bm, verts=[v for v in bm.verts], cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"))
    bmesh.ops.translate(bm, verts=[v for v in bm.verts], vec=(0, -D / 2 - 0.08, H - 0.65))
    objs.append(finish("Era3_Deco", bm, YELLOW))
    # 선반 위 왼쪽: 전기 화구(검은 원통) + 알루미늄 녹이는 컵 → 컵은 도구로 따로 (Era3_Cup)
    bm = bmesh.new()
    add_cyl(bm, (-1.15, -0.25, SHELF + 0.2), 0.75, 0.4)
    objs.append(finish("Era3_Heater", bm, BLACK, smooth=True))
    bm = bmesh.new()
    add_coil(bm, (-1.15, -0.25, SHELF + 0.42), 0.1, 0.6, 4.5, 0.03)
    objs.append(finish("Era3_Coil", bm, COIL))
    # 선반 위 오른쪽: 검은 사각 누름판 + 검은 원통 누름 손잡이(위에서 내려옴)
    bm = bmesh.new()
    add_box(bm, (1.05, -0.25, SHELF + 0.12), (1.7, 1.7, 0.24), bevel=0.03)
    add_cyl(bm, (1.45, 0.15, SHELF + 1.15), 0.18, 1.6)
    add_box(bm, (1.45, 0.15, SHELF + 1.95), (0.5, 0.5, 0.16), bevel=0.03)
    objs.append(finish("Era3_Press", bm, BLACK))
    # 아래 앞면: 노란 주의 스티커 + 흰 안내 스티커
    bm = bmesh.new()
    add_box(bm, (0.9, -D / 2 - 0.01, 2.3), (1.6, 0.04, 0.5))
    objs.append(finish("Era3_StickerY", bm, STICKER_Y))
    bm = bmesh.new()
    add_box(bm, (-1.3, -D / 2 - 0.01, 1.7), (0.7, 0.04, 0.9))
    objs.append(finish("Era3_StickerW", bm, STICKER_W))
    return objs


# 3단계 도구: 알루미늄 녹이는 컵 (손잡이 짧은 쇠 컵) + 나무 꼬치
def era3_cup():
    objs = []
    bm = bmesh.new()
    add_lathe(bm, [(0.0, 0.0), (0.42, 0.0), (0.5, 0.06), (0.52, 0.7), (0.56, 0.72), (0.5, 0.72), (0.47, 0.08), (0.0, 0.06)], seg=40)
    add_box(bm, (0.78, 0, 0.55), (0.5, 0.12, 0.05))
    objs.append(finish("Era3_Cup", bm, ALU, smooth=True))
    bm = bmesh.new()
    add_cyl(bm, (0, 0, 0.0), 0.025, 2.2)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(0.35, 3, "Y"))
    bmesh.ops.translate(bm, verts=bm.verts, vec=(-0.1, 0, 0.95))
    objs.append(finish("Era3_Stick", bm, LIGHT_WOOD, smooth=True))
    return objs


# ─────────────────────────── 4단계: 가정용 미니 달고나 메이커 (2020년대) ───────────────────────────
# 레퍼런스(구글 이미지 '달고나 메이커 가정용'): 파스텔(분홍·흰·민트) 둥근 몸통, 위에 은색 링 + 검은 나선 열선 화구,
# 앞쪽 금색 다이얼, 작은 다리. 함께 쓰는 스테인리스 손잡이 냄비(나무 손잡이), 동그란 누름판, 헤라.
def era4():
    objs = []
    R, Hb = 1.7, 1.1
    bm = bmesh.new()
    add_lathe(bm, [(0.0, 0.12), (1.45, 0.12), (1.62, 0.25), (R, 0.55), (R - 0.04, Hb - 0.1), (R - 0.15, Hb), (1.2, Hb), (1.2, Hb - 0.02), (0.0, Hb - 0.02)], seg=56)
    objs.append(finish("Era4_Body", bm, CREAM, smooth=True))
    bm = bmesh.new()  # 다리 4개
    for a in range(4):
        ang = math.pi / 4 + a * math.pi / 2
        add_cyl(bm, (math.cos(ang) * 1.2, math.sin(ang) * 1.2, 0.06), 0.14, 0.12, seg=16)
    objs.append(finish("Era4_Feet", bm, WHITE, smooth=True))
    bm = bmesh.new()  # 은색 화구 링
    add_lathe(bm, [(1.22, Hb), (1.25, Hb + 0.06), (1.18, Hb + 0.1), (1.05, Hb + 0.04), (1.05, Hb - 0.02)], seg=56)
    objs.append(finish("Era4_Ring", bm, STEEL, smooth=True))
    bm = bmesh.new()
    add_cyl(bm, (0, 0, Hb - 0.01), 1.05, 0.02, seg=48)
    objs.append(finish("Era4_Plate", bm, BLACK))
    bm = bmesh.new()
    add_coil(bm, (0, 0, Hb + 0.03), 0.12, 0.9, 6, 0.032)
    objs.append(finish("Era4_Coil", bm, COIL))
    bm = bmesh.new()  # 금색 다이얼 (앞 = -Y)
    add_cyl(bm, (0, -R + 0.02, 0.55), 0.26, 0.16, axis="Y")
    add_box(bm, (0, -R - 0.08, 0.55), (0.08, 0.06, 0.4))
    objs.append(finish("Era4_Dial", bm, GOLD, smooth=True))
    bm = bmesh.new()  # 다이얼 둘레 민트 띠
    add_lathe(bm, [(R + 0.005, 0.3), (R + 0.02, 0.32), (R + 0.02, 0.4), (R + 0.005, 0.42)], seg=56)
    objs.append(finish("Era4_Band", bm, MINT, smooth=True))
    return objs


# 4단계 도구: 스테인리스 손잡이 냄비(나무 손잡이), 동그란 누름판(위 고리 손잡이), 납작한 헤라
def era4_tools():
    objs = []
    bm = bmesh.new()
    add_lathe(bm, [(0.0, 0.0), (0.62, 0.0), (0.68, 0.05), (0.7, 0.6), (0.76, 0.66), (0.72, 0.66), (0.66, 0.08), (0.0, 0.05)], seg=48)
    add_box(bm, (0.95, 0, 0.5), (0.55, 0.14, 0.05))
    objs.append(finish("Era4_Pan", bm, STEEL, smooth=True))
    bm = bmesh.new()
    add_cyl(bm, (0, 0, 0), 0.09, 1.4, seg=20, axis="X")
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(-0.25, 3, "Y"))
    bmesh.ops.translate(bm, verts=bm.verts, vec=(1.85, 0, 0.66))
    objs.append(finish("Era4_PanHandle", bm, WOOD, smooth=True))
    bm = bmesh.new()  # 누름판
    add_cyl(bm, (0, 0, 0.04), 1.0, 0.08, seg=48)
    add_lathe(bm, [(0.05, 0.08), (0.05, 0.7), (0.45, 0.75), (0.45, 0.82), (0.0, 0.82)], seg=24)
    objs.append(finish("Era4_Presser", bm, STEEL, smooth=True))
    objs[-1]["pv"] = (2.6, 0.2)
    bm = bmesh.new()  # 헤라
    add_box(bm, (0, 0, 0.02), (0.9, 0.7, 0.03), bevel=0.01)
    add_box(bm, (0, -0.85, 0.2), (0.16, 1.1, 0.06))
    bmesh.ops.rotate(bm, verts=[v for v in bm.verts if v.co.y < -0.3], cent=(0, -0.35, 0.02), matrix=Matrix.Rotation(0.3, 3, "X"))
    objs.append(finish("Era4_Scraper", bm, STEEL))
    objs[-1]["pv"] = (0.6, -2.6)
    return objs



# ─────────────────────────── 5단계(최고 등급): 공장식 달고나 기계 ───────────────────────────
# 사용자 결정 (2026-11-18): 가장 높은 등급 = 진짜 기계로 뽑아내는 공장식. 기계를 눌러 도안을 고르면 그 모양만 뽑아냄.
# 레퍼런스: 사용자 사진(자판기 속: 투명 설탕 통 + 아래 나사식 공급기·흰 손잡이, 아날로그 계기판이 달린 제어판, 배선),
# 사탕 공장 디포지터 라인(설탕 통 → 끓이는 솥 → 노즐로 틀에 떨어뜨림 → 컨베이어 → 눌러 찍기 → 나오는 곳).
# 왼쪽부터: 투명 설탕 통 → 스테인리스 솥(빨간 가열 띠) + 노즐 → 컨베이어 위 틀 쟁반 → 가운데 찍는 프레스(문) →
# 오른쪽 제어판(계기판·도안 고르는 버튼 6개·시작/정지·경고등) → 끝의 미끄럼판 → 받는 쟁반.
GLASS = ("Glass", (220, 236, 240), 0.0, 0.05, "Glass")
BELT = ("Belt", (46, 46, 50), 0.0, 0.8, "Rubber")
GREEN_BTN = ("GreenButton", (60, 190, 90), 0.0, 0.4, "SmoothPlastic")
AMBER = ("Amber", (255, 170, 30), 0.0, 0.3, "Neon")
GAUGE = ("GaugeFace", (246, 244, 236), 0.0, 0.5, "SmoothPlastic")
DALGONA = ("Dalgona", (214, 150, 70), 0.0, 0.6, "SmoothPlastic")


def era5():
    W, D = 8.6, 3.8
    BASE_H = 2.4
    BELT_Z = BASE_H + 0.12
    objs = []
    bm = bmesh.new()  # 스테인리스 받침 몸통 + 다리
    add_box(bm, (0, 0, 0.3 + (BASE_H - 0.3) / 2), (W, D, BASE_H - 0.3), bevel=0.05)
    for x in (-W / 2 + 0.3, W / 2 - 0.3):
        for y in (-D / 2 + 0.3, D / 2 - 0.3):
            add_box(bm, (x, y, 0.15), (0.3, 0.3, 0.3))
    objs.append(finish("Era5_Base", bm, STEEL))
    bm = bmesh.new()  # 앞면 문 손잡이·환기구 줄 (어두운 쇠)
    for x in (-2.8, -0.9, 1.0, 2.9):
        add_box(bm, (x, -D / 2 - 0.02, 1.4), (1.6, 0.04, 1.6), bevel=0.02)
    objs.append(finish("Era5_Doors", bm, STEEL_DARK))
    # 컨베이어: 고무 벨트 + 양 끝 롤러 + 옆 테두리
    bm = bmesh.new()
    add_box(bm, (0.3, -0.5, BELT_Z), (W - 1.2, 1.6, 0.08))
    objs.append(finish("Era5_Belt", bm, BELT))
    bm = bmesh.new()
    for x in (-W / 2 + 0.9, W / 2 - 0.3):
        add_cyl(bm, (x, -0.5, BELT_Z - 0.05), 0.16, 1.7, seg=24, axis="Y")
    for y in (-1.38, 0.38):
        add_box(bm, (0.3, y, BELT_Z + 0.08), (W - 1.0, 0.08, 0.3))
    objs.append(finish("Era5_Rails", bm, STEEL_DARK))
    # 틀 쟁반 4개 (둥근 홈 2개씩) + 그 위 달고나 몇 개
    bm = bmesh.new()
    trays = [-2.7, -0.9, 0.9, 2.7]
    for x in trays:
        add_box(bm, (x, -0.5, BELT_Z + 0.1), (1.5, 1.4, 0.12), bevel=0.02)
    objs.append(finish("Era5_Trays", bm, STEEL))
    bm = bmesh.new()
    for x in trays[1:]:
        for y in (-0.82, -0.18):
            add_cyl(bm, (x, y, BELT_Z + 0.18), 0.28, 0.05, seg=24)
    objs.append(finish("Era5_Dalgona", bm, DALGONA, smooth=True))
    # 왼쪽: 투명 설탕 통 (아래가 좁아지는 깔때기) + 흰 손잡이 공급기 + 솥
    hx = -W / 2 + 1.2
    bm = bmesh.new()
    add_box(bm, (hx, 0.6, BASE_H + 3.9), (1.7, 1.5, 1.6), bevel=0.06)
    add_lathe(bm, [(0.15, 0.0), (0.75, 0.9)], center=(hx, 0.6, BASE_H + 2.2), seg=4)
    objs.append(finish("Era5_Hopper", bm, GLASS))
    bm = bmesh.new()  # 통 속 설탕
    add_box(bm, (hx, 0.6, BASE_H + 3.55), (1.5, 1.3, 0.85))
    objs.append(finish("Era5_Sugar", bm, WHITE))
    bm = bmesh.new()  # 공급기(나사 통) + 흰 손잡이
    add_cyl(bm, (hx, 0.6, BASE_H + 2.05), 0.16, 0.35, seg=20)
    add_cyl(bm, (hx + 0.35, 0.6, BASE_H + 2.05), 0.13, 0.16, seg=20, axis="X")
    objs.append(finish("Era5_Feeder", bm, CREAM, smooth=True))
    bm = bmesh.new()  # 설탕 통 받침대: 기둥 4개 + 통 아래 테
    for dx in (-0.75, 0.75):
        for dy in (-0.05, 1.25):
            add_box(bm, (hx + dx, dy, BASE_H + 1.55), (0.12, 0.12, 3.1))
    add_box(bm, (hx, 0.6, BASE_H + 3.1), (1.8, 1.6, 0.1))
    objs.append(finish("Era5_HopperStand", bm, STEEL_DARK))
    bm = bmesh.new()  # 솥: 원통 + 아래 원뿔, 노즐이 컨베이어 쪽으로
    add_lathe(bm, [(0.0, 0.0), (0.12, 0.0), (0.12, 0.25), (0.65, 0.75), (0.7, 1.6), (0.74, 1.65), (0.0, 1.65)], center=(hx + 0.3, -0.35, BASE_H + 0.2), seg=40)
    add_box(bm, (hx + 0.3, 0.1, BASE_H + 1.45), (0.12, 0.9, 0.12))  # 통 → 솥 관
    objs.append(finish("Era5_Kettle", bm, STEEL, smooth=True))
    bm = bmesh.new()  # 솥 가열 띠
    add_lathe(bm, [(0.72, 0.9), (0.76, 0.92), (0.76, 1.25), (0.72, 1.27)], center=(hx + 0.3, -0.35, BASE_H + 0.2), seg=40)
    objs.append(finish("Era5_Heater", bm, RED_BODY, smooth=True))
    # 가운데 찍는 프레스: 기둥 2개 + 위 들보 + 피스톤 + 도장판(고른 도안이 끼워짐)
    px = 0.9
    bm = bmesh.new()
    for y in (-1.5, 0.5):
        add_box(bm, (px, y, BELT_Z + 1.3), (0.25, 0.25, 2.6))
    add_box(bm, (px, -0.5, BELT_Z + 2.65), (1.0, 2.3, 0.4), bevel=0.04)
    objs.append(finish("Era5_PressFrame", bm, STEEL_DARK))
    bm = bmesh.new()
    add_cyl(bm, (px, -0.5, BELT_Z + 1.95), 0.16, 1.1, seg=24)
    add_box(bm, (px, -0.5, BELT_Z + 1.3), (1.3, 1.25, 0.18), bevel=0.03)
    objs.append(finish("Era5_PressHead", bm, STEEL, smooth=True))
    bm = bmesh.new()  # 도장판 아래 도안 자국 (예시 별 2개, 게임에서 고른 도안으로 바꿈)
    for y in (-0.82, -0.18):
        add_star(bm, (px, y, BELT_Z + 1.2), 0.24, 0.1, 0.04)
    objs.append(finish("Era5_Stamp", bm, GOLD))
    # 오른쪽 제어판: 기울어진 상자 + 계기판 + 도안 버튼 6개 + 시작·정지 + 경고등
    cx = W / 2 - 0.9
    bm = bmesh.new()
    add_box(bm, (cx, 0.9, BASE_H + 1.5), (1.4, 1.2, 3.0), bevel=0.05)
    objs.append(finish("Era5_Panel", bm, STEEL_DARK))
    bm = bmesh.new()
    add_cyl(bm, (cx, 0.28, BASE_H + 2.5), 0.38, 0.06, seg=40, axis="Y")
    objs.append(finish("Era5_Gauge", bm, GAUGE, smooth=True))
    bm = bmesh.new()  # 계기 바늘
    add_box(bm, (cx + 0.1, 0.23, BASE_H + 2.58), (0.32, 0.03, 0.04))
    objs.append(finish("Era5_Needle", bm, BLACK))
    bm = bmesh.new()  # 도안 고르는 버튼 6개 (금색 도형은 따로)
    for i in range(6):
        add_cyl(bm, (cx - 0.4 + (i % 3) * 0.4, 0.28, BASE_H + 1.75 - (i // 3) * 0.42), 0.15, 0.08, seg=24, axis="Y")
    objs.append(finish("Era5_ShapeButtons", bm, WHITE, smooth=True))
    bm = bmesh.new()  # 버튼 위 도형 (별·하트·원·세모·우산 대신 단순 모양)
    for i in range(6):
        c = (cx - 0.4 + (i % 3) * 0.4, 0.22, BASE_H + 1.75 - (i // 3) * 0.42)
        k = i % 3
        if k == 0:
            add_star(bm, (0, 0, 0), 0.09, 0.04, 0.02)
        elif k == 1:
            add_heart(bm, (0, 0, 0), 0.08, 0.02)
        else:
            add_star(bm, (0, 0, 0), 0.09, 0.045, 0.02, points=3)
        vs = [v for v in bm.verts if v.co.length < 0.2 and abs(v.co.z) < 0.02]
        bmesh.ops.rotate(bm, verts=vs, cent=(0, 0, 0), matrix=Matrix.Rotation(math.pi / 2, 3, "X"))
        bmesh.ops.translate(bm, verts=vs, vec=c)
    objs.append(finish("Era5_ShapeIcons", bm, GOLD))
    bm = bmesh.new()
    add_cyl(bm, (cx - 0.3, 0.28, BASE_H + 0.75), 0.18, 0.1, seg=24, axis="Y")
    objs.append(finish("Era5_Start", bm, GREEN_BTN, smooth=True))
    bm = bmesh.new()
    add_cyl(bm, (cx + 0.3, 0.28, BASE_H + 0.75), 0.18, 0.1, seg=24, axis="Y")
    objs.append(finish("Era5_Stop", bm, REDB, smooth=True))
    bm = bmesh.new()  # 경고등
    add_lathe(bm, [(0.0, 0.0), (0.16, 0.0), (0.16, 0.25), (0.12, 0.33), (0.0, 0.36)], center=(cx, 0.9, BASE_H + 3.0), seg=24)
    objs.append(finish("Era5_Beacon", bm, AMBER, smooth=True))
    # 끝: 미끄럼판 + 받는 쟁반
    bm = bmesh.new()
    add_box(bm, (W / 2 + 0.55, -0.5, BELT_Z - 0.6), (1.3, 1.6, 0.06))
    vs = [v for v in bm.verts]
    bmesh.ops.rotate(bm, verts=vs, cent=(W / 2 + 0.55, -0.5, BELT_Z - 0.6), matrix=Matrix.Rotation(-0.6, 3, "Y"))
    add_box(bm, (W / 2 + 1.4, -0.5, 0.35), (1.4, 1.9, 0.7), bevel=0.03)
    objs.append(finish("Era5_Chute", bm, STEEL))
    return objs

groups = {
    "Era2": (era2(), (-12, 0, 0)),
    "Era2Tools": (era2_ladle(), (-12, -5, 0.4)),  # 국자 기준점 = 그릇 테두리 가운데라 미리 보기에선 띄움
    "Era3": (era3(), (-4, 0, 0)),
    "Era3Tools": (era3_cup(), (-4, -5, 0)),
    "Era4": (era4(), (4, 0, 0)),
    "Era4Tools": (era4_tools(), (4, -5, 0)),
    "Era5": (era5(), (14.5, 0, 0)),
}

# 내보내기 전: 모두 원점(0,0,0)에 둔 채로 내보냄 (게임에서 위치를 정함). 크기·기준점 기록
lines = ["# 이름\t색(RGB)\tRoblox 재질\t경계 상자 가운데(기준점에서, Blender 좌표 x y z)\t크기"]
rgb_of = {n: (rgb, rbx) for n, rgb, rbx in PARTS}
for name, (objs, _) in groups.items():
    for o in objs:
        bb = [o.matrix_world @ Vector(c) for c in o.bound_box]
        lo = Vector((min(v.x for v in bb), min(v.y for v in bb), min(v.z for v in bb)))
        hi = Vector((max(v.x for v in bb), max(v.y for v in bb), max(v.z for v in bb)))
        c, s = (lo + hi) / 2, hi - lo
        rgb, rbx = rgb_of[o.name]
        lines.append(f"{o.name}\t{rgb}\t{rbx}\t({c.x:.4f}, {c.y:.4f}, {c.z:.4f})\t({s.x:.3f}, {s.y:.3f}, {s.z:.3f})")
        tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
        if tris > 20000:
            print("[machines] WARNING too many tris", o.name, tris)
with open(os.path.join(OUT, "machines_parts.txt"), "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "dalgona_machines.glb"), export_format="GLB", use_selection=True, export_apply=True)

# 미리 보기: 나란히 놓고 렌더
for name, (objs, off) in groups.items():
    place(objs, off)
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.57, 0.6, 1)
scene.world = world
bpy.ops.mesh.primitive_plane_add(size=60, location=(0, 0, -0.001))
bpy.context.active_object.data.materials.append(mat("Table", (150, 108, 72), 0.0, 0.7))
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.2
sun.rotation_euler = (math.radians(50), math.radians(-15), math.radians(25))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.lens = 35
cam.location = (2.5, -32, 18)
cam.rotation_euler = (Vector((3.0, -1.5, 2.8)) - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 2200, 950
scene.view_settings.view_transform = "Standard"
scene.render.filepath = os.path.abspath(os.path.join(OUT, "machines_preview.png"))
bpy.ops.render.render(write_still=True)
for name, (objs, off) in groups.items():
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in objs)
    print(f"[machines] {name}: {len(objs)} parts, {tris} tris")
print("[machines] done")
