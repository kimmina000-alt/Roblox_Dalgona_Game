# 골목 슈퍼 · 장보기 봉지 · 주문 대기 의자 (D54·D55, 2026-11-25, PM 묶음 → 3D 세션)
#   market: 들어갈 수 있는 레트로 동네 슈퍼 "골목 슈퍼" (가상 간판, 실제 상표 없음). 골목 동쪽 끝 꾸미기 가게 자리, 문은 길 쪽.
#           밖: 줄무늬 차양·큰 유리창·간판·음료 상자·아이스크림 냉동고·나무 의자 / 안: 진열대 섬 2개·벽 선반·냉장 진열장·계산대(금전 등록기)·천장 등
#           진열 물건은 게임 재료 위주(설탕 포대·소다 상자·나무젓가락 묶음·포장지 두루마리·빵끈·연탄) + 과자·음료.
#   bags:   손에 드는 장바구니 봉지 소·중·대 (산 양에 따라). 원점 = 손잡이 잡는 곳 → 코드가 오른손에 붙이면 됨.
#   chair:  주문 손님 대기 의자 (손님 NPC 엉덩이 관절 높이 0.75~0.95에 맞춤). 원점 = 바닥 가운데.
# 그림체 = cozy_kit (모서리 둥글게, 팔레트 텍스처 한 장). 폰: 슈퍼는 서버에 하나라 삼각형 1.5만 안쪽, 봉지 각 300~600, 의자 약 1천.
# 좌표: 원점 = 슈퍼 앞면(길 쪽 벽 바깥면) 가운데 바닥. 앞(길) = Blender -Y. Blender (x,y,z) → Roblox (-x, z, y).
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/cozy_market.py -- <출력 폴더(절대 경로)> <market|bags|chair>
# 결과: dalgona_<종류>.glb, dalgona_<종류>_parts.txt, dalgona_<종류>_*.png

import math
import os
import random
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cozy_kit import (I4, Vector, arc_tube, ball, box, cyl, finish, flat_shape, heart_pts, lathe, part, poly_pts, preview, quad, rot,  # noqa: E402
                      star_pts, text)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else ".")
KIND = argv[1] if len(argv) > 1 else "market"
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
rng = random.Random(25)

# ───────── 색 (골목 꾸미기 가게·사용자 가게와 같은 낮은 채도 파스텔) ─────────
WALL = (186, 222, 206)      # 민트 벽 (골목슈퍼 = 민트, AlleyBuilder와 같은 계열)
WALL_D = (150, 196, 178)
TILE = (236, 238, 226)      # 바닥 타일
TILE_D = (206, 220, 204)
CREAM = (246, 234, 212)
CREAM_D = (230, 212, 184)
WHITE = (250, 248, 242)
WOOD = (198, 144, 98)
WOOD_D = (146, 98, 62)
WOOD_L = (222, 176, 122)
ALU = (206, 214, 214)       # 알루미늄 창틀
GLASS = (214, 236, 238)
CORAL = (226, 112, 96)      # 간판 글씨
PINK = (246, 178, 196)
BUTTER = (246, 214, 140)
SKY = (160, 196, 226)
LILAC = (196, 176, 220)
MINT_B = (150, 204, 176)
LEAF = (130, 178, 110)
COAL = (64, 60, 60)
SUGAR = (252, 250, 244)
KRAFT = (214, 180, 132)     # 종이 포대
LAMP = (255, 246, 220)
IRON = (86, 74, 68)
RED = (230, 120, 104)


def goods(p, x0, x1, y, z, depth, face=-1):
    """선반 한 칸에 물건 채우기. x0~x1, 가운데 y, 선반 윗면 z, 깊이 depth, face = 앞 방향(-1 = -Y)."""
    x = x0 + 0.15
    while x < x1 - 0.4:
        k = rng.random()
        col = rng.choice((PINK, BUTTER, SKY, LILAC, MINT_B, CORAL, CREAM, WHITE))
        if k < 0.3:      # 과자 상자
            w, h = rng.uniform(0.55, 0.8), rng.uniform(0.8, 1.15)
            box(p, (x + w / 2, y, z + h / 2), (w, depth * 0.7, h), col, bev=0, seg=1)
            box(p, (x + w / 2, y + face * depth * 0.355, z + h * 0.62), (w * 0.7, 0.02, h * 0.3), WHITE, bev=0, seg=1)
        elif k < 0.55:   # 깡통 2개
            w = 0.9
            for dx in (0.22, 0.66):
                cyl(p, (x + dx, y, z), (x + dx, y, z + 0.55), 0.2, 0.2, col, seg=6)
        elif k < 0.75:   # 병
            w = 0.5
            cyl(p, (x + 0.25, y, z), (x + 0.25, y, z + 0.75), 0.2, 0.2, col, seg=6)
            cyl(p, (x + 0.25, y, z + 0.75), (x + 0.25, y, z + 1.0), 0.2, 0.08, col, seg=6)
        else:            # 봉지 과자 (둥근 베개 모양)
            w, h = 0.75, 0.9
            box(p, (x + w / 2, y, z + h / 2), (w, depth * 0.45, h), col, bev=0.12, seg=1)
        x += w + 0.08


def sugar_sack(p, c, s=1.0):
    box(p, c, (1.1 * s, 0.7 * s, 1.3 * s), SUGAR, bev=0.2 * s, seg=1)
    box(p, (c[0], c[1] - 0.36 * s, c[2] + 0.1 * s), (0.6 * s, 0.02, 0.4 * s), SKY, bev=0, seg=1)


def soda_box(p, c, s=1.0):
    box(p, c, (0.8 * s, 0.6 * s, 0.9 * s), WHITE, bev=0, seg=1)
    box(p, (c[0], c[1] - 0.31 * s, c[2]), (0.6 * s, 0.02, 0.3 * s), RED, bev=0, seg=1)


def briquette(p, c, h=0.55, r=0.42):
    cyl(p, c, (c[0], c[1], c[2] + h), r, r, COAL, seg=8)


# ───────────────────────── 슈퍼 ─────────────────────────
def build_market():
    W, D, H, T = 32.0, 13.4, 12.5, 0.6         # 바깥 폭·깊이·벽 높이·벽 두께 (연출 세션 골목 자리: 폭 36·깊이 14 이하, 11-25)
    FLOOR = 0.25                               # 바닥 윗면 높이 (길에서 한 번 낮은 턱)
    DOOR_W, DOOR_H = 7.0, 8.0
    WIN_Z0, WIN_Z1 = 2.2, 8.4
    hw = W / 2

    shell = part("Mk_Shell", "벽·바닥·천장·지붕·앞 기둥 (충돌: CollisionFidelity PreciseConvexDecomposition, 문 자리 뚫림)")
    # 바닥 + 타일 무늬
    box(shell, (0, D / 2, FLOOR / 2), (W, D, FLOOR), TILE, bev=0.04, seg=1)
    for i in range(int((W - 2 * T) / 2)):
        for j in range(int((D - 2 * T) / 2)):
            if (i + j) % 2 == 0:
                x0, y0 = -hw + T + i * 2, T + j * 2
                quad(shell, [(x0, y0, FLOOR + 0.01), (x0 + 2, y0, FLOOR + 0.01), (x0 + 2, y0 + 2, FLOOR + 0.01), (x0, y0 + 2, FLOOR + 0.01)], TILE_D)
    # 옆벽·뒷벽
    box(shell, (-hw + T / 2, D / 2, H / 2), (T, D, H), WALL, bev=0.08, seg=2)
    box(shell, (hw - T / 2, D / 2, H / 2), (T, D, H), WALL, bev=0.08, seg=2)
    box(shell, (0, D - T / 2, H / 2), (W - 2 * T, T, H), WALL, bev=0.05, seg=1)
    # 안쪽 벽 아래 띠 (크림 판벽)
    for x in (-hw + T + 0.03, hw - T - 0.03):
        box(shell, (x, D / 2, 1.6), (0.06, D - 2 * T, 2.7), CREAM, bev=0, seg=1)
    box(shell, (0, D - T - 0.03, 1.6), (W - 2 * T, 0.06, 2.7), CREAM, bev=0, seg=1)
    # 앞면: 기둥 · 창 아래 벽 · 창·문 위 벽
    yT = T / 2
    for sx in (-1, 1):
        box(shell, (sx * (hw - 0.75), yT, H / 2), (1.5, T, H), WALL_D, bev=0.1, seg=2)          # 모서리 기둥
        box(shell, (sx * (DOOR_W / 2 + 0.5), yT, H / 2), (1.0, T, H), WALL_D, bev=0.08, seg=2)  # 문 옆 기둥
        wx = sx * (DOOR_W / 2 + 1.0 + (hw - 1.5 - DOOR_W / 2 - 1.0) / 2)
        ww = hw - 1.5 - DOOR_W / 2 - 1.0
        box(shell, (wx, yT, WIN_Z0 / 2), (ww, T, WIN_Z0), WALL, bev=0.06, seg=1)               # 창 아래
        for k in range(int(ww / 0.8)):                                                         # 창 아래 작은 타일 줄
            box(shell, (wx - ww / 2 + 0.4 + k * 0.8, -0.02, 1.1), (0.7, 0.06, 1.6), (WHITE if k % 2 else TILE_D), bev=0, seg=1)
        box(shell, (wx, yT, (WIN_Z1 + H) / 2), (ww, T, H - WIN_Z1), WALL, bev=0.06, seg=1)     # 창 위
    box(shell, (0, yT, (DOOR_H + H) / 2), (DOOR_W, T, H - DOOR_H), WALL, bev=0.06, seg=1)      # 문 위
    # 지붕 (평지붕 + 낮은 난간) + 천장
    box(shell, (0, D / 2, H + 0.2), (W + 0.6, D + 0.6, 0.4), CREAM_D, bev=0.1, seg=2)
    for sx in (-1, 1):
        box(shell, (sx * (hw + 0.1), D / 2, H + 0.75), (0.5, D + 0.6, 0.7), WALL_D, bev=0.1, seg=2)
    box(shell, (0, D + 0.1, H + 0.75), (W + 0.6, 0.5, 0.7), WALL_D, bev=0.1, seg=2)
    box(shell, (0, -0.1, H + 0.75), (W + 0.6, 0.5, 0.7), WALL_D, bev=0.1, seg=2)
    box(shell, (0, D / 2, H - 0.1), (W - 2 * T, D - 2 * T, 0.2), WHITE, bev=0, seg=1)          # 천장
    # 지붕 물탱크 (골목 실루엣)
    lathe(shell, [(0, 0), (1.3, 0), (1.35, 0.1), (1.35, 2.0), (1.2, 2.2), (0, 2.25)], SKY, seg=14, c=(hw - 4, D - 4, H + 0.4))
    for a in range(4):
        q = (hw - 4 + 1.0 * math.cos(a * math.pi / 2 + 0.6), D - 4 + 1.0 * math.sin(a * math.pi / 2 + 0.6))
        cyl(shell, (q[0], q[1], H + 0.4), (q[0], q[1], H + 0.9), 0.1, 0.1, IRON, seg=6)

    # 창틀·문틀 (알루미늄) + 유리
    frame = part("Mk_Frames", "알루미늄 창틀·문틀·문턱 (충돌 끔 가능)")
    glass = part("Mk_Glass", "창 유리·문 유리·냉장고 유리문 (Glass, Transparency 0.6, 충돌: 창만 켬)")
    for sx in (-1, 1):
        ww = hw - 1.5 - DOOR_W / 2 - 1.0
        wx = sx * (DOOR_W / 2 + 1.0 + ww / 2)
        for z in (WIN_Z0, WIN_Z1):
            box(frame, (wx, 0.05, z), (ww, 0.35, 0.18), ALU, bev=0.05, seg=1)
        for k in range(3):
            box(frame, (wx - ww / 2 + k * ww / 2, 0.05, (WIN_Z0 + WIN_Z1) / 2), (0.16, 0.35, WIN_Z1 - WIN_Z0), ALU, bev=0.04, seg=1)
        box(frame, (wx, 0.05, WIN_Z0 + 4.4), (ww, 0.3, 0.12), ALU, bev=0.03, seg=1)  # 가로살
        box(glass, (wx, T / 2, (WIN_Z0 + WIN_Z1) / 2), (ww - 0.1, 0.08, WIN_Z1 - WIN_Z0 - 0.1), GLASS, bev=0, seg=1)
        # 창 유리 안쪽 스티커: 별·하트 (가상, 글자 없음)
        flat_shape(frame, (wx - ww / 4, T / 2 - 0.06, WIN_Z0 + 2.6), star_pts(0.5), 0.02, BUTTER, m=rot(x=90))
        flat_shape(frame, (wx + ww / 4, T / 2 - 0.06, WIN_Z0 + 2.6), poly_pts(0.45, 20), 0.02, PINK, m=rot(x=90))
    # 문틀 + 열어 둔 미닫이 유리문 (왼쪽 창 뒤로 밀림)
    for sx in (-1, 1):
        box(frame, (sx * DOOR_W / 2, 0.0, DOOR_H / 2), (0.2, T + 0.2, DOOR_H), ALU, bev=0.05, seg=1)
    box(frame, (0, 0.0, DOOR_H), (DOOR_W + 0.2, T + 0.2, 0.2), ALU, bev=0.05, seg=1)
    box(frame, (0, 0.0, FLOOR / 2 + 0.02), (DOOR_W, T + 0.4, FLOOR + 0.04), ALU, bev=0.04, seg=1)  # 문턱
    dx = -DOOR_W / 2 - 1.6
    box(frame, (dx, T + 0.25, DOOR_H / 2 + 0.1), (3.0, 0.14, DOOR_H - 0.2), ALU, bev=0.04, seg=1)
    box(glass, (dx, T + 0.25, DOOR_H / 2 + 0.1), (2.7, 0.16, DOOR_H - 0.6), GLASS, bev=0, seg=1)
    box(frame, (dx + 1.2, T + 0.12, DOOR_H / 2), (0.1, 0.1, 1.2), WOOD_D, bev=0.02, seg=1)   # 손잡이

    # 간판 (가상 이름 "골목 슈퍼") + 차양
    sign = part("Mk_Sign", "간판: 크림 판·민트 테·산호색 글씨 '골목 슈퍼'·사과·사탕 그림 (가상 간판, 상표 없음)")
    SZ0, SZ1 = WIN_Z1 + 1.6, H + 0.4
    sz = (SZ0 + SZ1) / 2
    box(sign, (0, -0.35, sz), (W - 3.0, 0.5, SZ1 - SZ0 + 0.5), WALL_D, bev=0.18, seg=3)
    box(sign, (0, -0.62, sz), (W - 3.6, 0.1, SZ1 - SZ0 - 0.1), CREAM, bev=0.05, seg=2)
    text(sign, "골목 슈퍼", (0.4, -0.68, sz), 2.3, 0.12, CORAL, m=rot(x=90))
    for sx, kind in ((-1, "apple"), (1, "candy")):
        cx = sx * (W / 2 - 3.2)
        if kind == "apple":
            flat_shape(sign, (cx, -0.66, sz - 0.1), poly_pts(0.85, 20), 0.08, RED, m=rot(x=90))
            flat_shape(sign, (cx + 0.3, -0.74, sz + 0.85), [(0, 0), (0.5, 0.25), (0.6, 0.55), (0.1, 0.3)], 0.06, LEAF, m=rot(x=90))
        else:
            flat_shape(sign, (cx, -0.66, sz), poly_pts(0.65, 16), 0.08, PINK, m=rot(x=90))
            for s in (-1, 1):
                flat_shape(sign, (cx + s * 0.85, -0.66, sz), [(0, 0), (s * 0.55, 0.4), (s * 0.55, -0.4)] if s > 0 else [(0, 0), (s * 0.55, -0.4), (s * 0.55, 0.4)], 0.08, PINK, m=rot(x=90))
            flat_shape(sign, (cx, -0.74, sz), star_pts(0.32), 0.04, WHITE, m=rot(x=90))
    awn = part("Mk_Awning", "줄무늬 차양 (민트·크림, 물결 끝) — 충돌 끔")
    AZ = WIN_Z1 + 1.2
    n = 18
    sw = (W - 1.0) / n
    tilt = rot(x=-24)
    for i in range(n):
        cx = -W / 2 + 0.5 + (i + 0.5) * sw
        col = MINT_B if i % 2 == 0 else CREAM
        box(awn, (cx, -0.95, AZ - 0.35), (sw, 2.0, 0.12), col, bev=0, seg=1, m=tilt)
        flat_shape(awn, (cx, -1.88, AZ - 0.8), [(math.cos(math.pi + math.pi * k / 8) * sw / 2, math.sin(math.pi + math.pi * k / 8) * 0.55) for k in range(9)],
                   0.1, col, m=rot(x=90))
    for sx in (-1, 1):  # 차양 쇠 받침
        cyl(awn, (sx * (W / 2 - 1.0), 0, AZ + 0.3), (sx * (W / 2 - 1.0), -1.8, AZ - 0.6), 0.06, 0.06, IRON, seg=6)

    # 가게 안 가구
    fix = part("Mk_Fixtures", "진열대 섬 2개·왼쪽 벽 선반·뒷벽 선반·냉장 진열장 몸통·계산대·금전 등록기·뒤 사탕 선반·시계 (충돌 켬)")
    gds = part("Mk_Goods", "진열 물건 전부 (과자·깡통·병·설탕 포대·소다 상자·젓가락 묶음·포장지·빵끈·연탄·우유·음료) — 충돌 끔")
    IX0, IX1 = -hw + T, hw - T                      # 안쪽 x
    # 진열대 섬 2개 (길이 방향 = 앞뒤)
    for gx in (-8.5, -2.5):
        GY0, GY1, GD = 3.8, 8.2, 2.0
        gy = (GY0 + GY1) / 2
        box(fix, (gx, gy, 0.45), (GD, GY1 - GY0, 0.5), WOOD_D, bev=0.08, seg=1)                     # 받침
        box(fix, (gx, gy, 2.6), (0.18, GY1 - GY0, 4.2), CREAM_D, bev=0.04, seg=1)                   # 가운데 판
        for z in (0.7, 2.0, 3.3):
            box(fix, (gx, gy, z), (GD, GY1 - GY0, 0.12), WOOD_L, bev=0.03, seg=1)
        for z in (0.76, 2.06, 3.36):
            for side in (-1, 1):
                # 섬 진열대는 앞뒤(y)로 길어서 물건을 y 방향으로 늘어놓음 (양쪽 면)
                xs = gx + side * GD / 4
                yy = GY0 + 0.15
                while yy < GY1 - 0.5:
                    k = rng.random()
                    col = rng.choice((PINK, BUTTER, SKY, LILAC, MINT_B, CORAL, CREAM, WHITE))
                    if k < 0.3:
                        w, h = rng.uniform(0.55, 0.8), rng.uniform(0.8, 1.1)
                        box(gds, (xs, yy + w / 2, z + h / 2), (GD * 0.35, w, h), col, bev=0, seg=1)
                    elif k < 0.55:
                        w = 0.9
                        for dy in (0.22, 0.66):
                            cyl(gds, (xs, yy + dy, z), (xs, yy + dy, z + 0.55), 0.2, 0.2, col, seg=6)
                    elif k < 0.75:
                        w = 0.5
                        cyl(gds, (xs, yy + 0.25, z), (xs, yy + 0.25, z + 0.75), 0.2, 0.2, col, seg=6)
                        cyl(gds, (xs, yy + 0.25, z + 0.75), (xs, yy + 0.25, z + 1.0), 0.2, 0.08, col, seg=6)
                    else:
                        w, h = 0.75, 0.9
                        box(gds, (xs, yy + w / 2, z + h / 2), (GD * 0.25, w, h), col, bev=0.1, seg=1)
                    yy += w + 0.08
        # 진열대 위 안내판 (글자 없는 버터색 판, 가운데 판 위)
        box(fix, (gx, gy, 5.05), (0.16, 3.2, 0.8), BUTTER, bev=0.06, seg=2)
        flat_shape(fix, (gx - 0.09, gy, 5.05), star_pts(0.25), 0.02, WHITE, m=rot(y=-90))
        flat_shape(fix, (gx + 0.09, gy, 5.05), star_pts(0.25), 0.02, WHITE, m=rot(y=90))
    # 왼쪽 벽 선반 (4단): 재료 코너 — 설탕 포대·소다 상자·젓가락·포장지·빵끈
    LX = IX0 + 0.65
    box(fix, (LX, 7.0, 3.0), (0.12, 8.0, 5.6), CREAM_D, bev=0.03, seg=1)
    for z in (0.6, 2.0, 3.4, 4.8):
        box(fix, (IX0 + 0.7, 7.0, z), (1.3, 8.0, 0.12), WOOD_L, bev=0.03, seg=1)
    for k in range(4):
        sugar_sack(gds, (IX0 + 0.75, 4.0 + k * 1.9, 0.66 + 0.65), 0.95)                 # 1단: 설탕 포대
    for k in range(5):
        soda_box(gds, (IX0 + 0.8, 3.6 + k * 1.4, 2.06 + 0.45), 0.9)                       # 2단: 소다 상자
    for k in range(7):                                                                    # 3단: 나무젓가락 묶음 + 포장지 두루마리
        y = 3.4 + k * 1.15
        if k % 2 == 0:
            for j in range(5):
                cyl(gds, (IX0 + 0.55 + (j % 3) * 0.16, y + (j // 3) * 0.16, 3.46), (IX0 + 0.55 + (j % 3) * 0.16, y + (j // 3) * 0.16, 4.3), 0.06, 0.06, WOOD_L, seg=5)
            box(gds, (IX0 + 0.7, y + 0.1, 3.8), (0.6, 0.45, 0.2), PINK, bev=0.02, seg=1)
        else:
            cyl(gds, (IX0 + 0.75, y - 0.35, 3.75), (IX0 + 0.75, y + 0.35, 3.75), 0.28, 0.28, (WHITE if k % 4 == 1 else SKY), seg=8)
    for k in range(6):                                                                    # 4단: 빵끈 묶음 (작은 고리)
        y = 3.6 + k * 1.3
        cyl(gds, (IX0 + 0.7, y, 4.86), (IX0 + 0.7, y, 5.0), 0.38, 0.38, rng.choice((RED, BUTTER, LEAF, SKY)), seg=10)
        cyl(gds, (IX0 + 0.7, y, 4.86), (IX0 + 0.7, y, 5.01), 0.22, 0.22, CREAM, seg=10)
    # 뒷벽 선반 (왼쪽 절반): 과자·음료 + 아래 연탄
    BY = D - T - 0.65
    box(fix, (-7.0, BY + 0.5, 3.0), (16.0, 0.12, 5.6), CREAM_D, bev=0.03, seg=1)
    for z in (0.6, 2.0, 3.4, 4.8):
        box(fix, (-7.0, BY, z), (16.0, 1.3, 0.12), WOOD_L, bev=0.03, seg=1)
    for z in (2.06, 3.46, 4.86):
        goods(gds, -15.0, 1.0, BY, z, 1.2)
    for k in range(6):                                                                    # 1단: 연탄 더미
        for j in range(3):
            briquette(gds, (-14.4 + k * 2.6 + (j % 2) * 0.9, BY - 0.15 + (j // 2) * 0.0, 0.66 + (j // 2) * 0.56))
    # 냉장 진열장 (뒷벽 오른쪽): 몸통 + 유리문 3 + 안 선반 + 우유·음료 + 위 등
    FX0, FX1, FD, FH = 3.0, IX1 - 0.2, 2.2, 7.6
    fx = (FX0 + FX1) / 2
    fy = D - T - FD / 2
    FW = FX1 - FX0
    box(fix, (fx, fy + FD / 2 - 0.15, FH / 2), (FW, 0.3, FH), WHITE, bev=0.1, seg=1)               # 뒤판 (속이 비어 물건이 보임)
    for sx in (-1, 1):
        box(fix, (fx + sx * (FW / 2 - 0.15), fy, FH / 2), (0.3, FD, FH), WHITE, bev=0.12, seg=2)   # 옆판
    box(fix, (fx, fy, FH - 0.45), (FW, FD, 0.9), WHITE, bev=0.15, seg=2)                         # 위
    box(fix, (fx, fy, 0.4), (FW, FD, 0.8), WHITE, bev=0.12, seg=2)                               # 아래
    box(fix, (fx, fy + FD / 2 - 0.32, FH / 2), (FW - 0.6, 0.04, FH - 1.7), (236, 244, 240), bev=0, seg=1)  # 안 뒤판 밝은 색
    box(fix, (fx, fy - FD / 2 - 0.02, FH - 0.55), (FX1 - FX0 - 0.2, 0.06, 0.6), MINT_B, bev=0.03, seg=1)   # 위 띠
    box(fix, (fx, fy - FD / 2 - 0.02, 0.45), (FX1 - FX0 - 0.2, 0.06, 0.5), WALL_D, bev=0.03, seg=1)        # 아래 띠
    ndoor = 3
    dw = (FX1 - FX0 - 0.4) / ndoor
    for i in range(ndoor):
        cx = FX0 + 0.2 + (i + 0.5) * dw
        box(fix, (cx, fy - FD / 2 + 0.05, (0.8 + FH - 0.9) / 2), (dw - 0.1, 0.12, FH - 1.7), ALU, bev=0.04, seg=1)
        box(glass, (cx, fy - FD / 2 - 0.02, (0.8 + FH - 0.9) / 2), (dw - 0.45, 0.06, FH - 2.0), GLASS, bev=0, seg=1)
        box(fix, (cx + dw / 2 - 0.35, fy - FD / 2 - 0.12, 3.6), (0.1, 0.1, 1.6), ALU, bev=0.02, seg=1)  # 손잡이
    for z in (1.0, 2.6, 4.2, 5.6):
        box(fix, (fx, fy + 0.1, z), (FX1 - FX0 - 0.4, FD - 0.5, 0.08), ALU, bev=0, seg=1)
        x = FX0 + 0.5
        while x < FX1 - 0.6:
            k = rng.random()
            if k < 0.45:   # 우유갑
                col = rng.choice((WHITE, SKY, PINK, BUTTER))
                box(gds, (x + 0.25, fy, z + 0.45), (0.45, 0.45, 0.8), col, bev=0, seg=1)
                box(gds, (x + 0.25, fy, z + 0.95), (0.45, 0.06, 0.2), col, bev=0, seg=1)
                x += 0.6
            else:          # 음료병
                col = rng.choice((MINT_B, CORAL, LILAC, BUTTER, SKY))
                cyl(gds, (x + 0.2, fy, z + 0.04), (x + 0.2, fy, z + 0.85), 0.18, 0.18, col, seg=6)
                cyl(gds, (x + 0.2, fy, z + 0.85), (x + 0.2, fy, z + 1.1), 0.18, 0.07, col, seg=6)
                x += 0.48
    lamps = part("Mk_Lamps", "천장 형광등 3줄 + 냉장고 안 등 (Neon 또는 SurfaceLight 붙이기)")
    box(lamps, (fx, fy - 0.2, FH - 1.05), (FX1 - FX0 - 0.6, 0.15, 0.1), LAMP, bev=0, seg=1)
    for y in (4.0, 9.5):
        box(fix, (-1.5, y, H - 0.32), (7.4, 0.7, 0.18), WHITE, bev=0.05, seg=1)
        box(lamps, (-1.5, y, H - 0.46), (7.0, 0.4, 0.12), LAMP, bev=0.04, seg=1)
    # 계산대 (오른쪽 앞, 길이 = 앞뒤), 주인은 계산대와 오른쪽 벽 사이에 서서 -X(가게 안)를 봄
    CX, CY0, CY1, CH, CDp = 10.4, 2.0, 7.4, 3.1, 1.6   # 문 들어가 오른쪽 안 (연출 세션 부탁)
    cy = (CY0 + CY1) / 2
    box(fix, (CX, cy, CH / 2), (CDp, CY1 - CY0, CH), WOOD, bev=0.15, seg=2)
    box(fix, (CX, cy, CH + 0.08), (CDp + 0.3, CY1 - CY0 + 0.3, 0.16), CREAM, bev=0.07, seg=2)
    for k in range(4):  # 앞판 세로 줄
        box(fix, (CX - CDp / 2 - 0.03, CY0 + 0.9 + k * 1.7, CH / 2), (0.06, 0.9, CH - 0.8), WOOD_L, bev=0.03, seg=1)
    # 금전 등록기 (레트로, 손잡이 쪽 = 주인)
    ry = CY1 - 1.4
    box(fix, (CX + 0.1, ry, CH + 0.5), (1.3, 1.5, 0.7), CREAM_D, bev=0.12, seg=2)
    box(fix, (CX + 0.25, ry, CH + 1.05), (0.7, 1.3, 0.5), CREAM_D, bev=0.1, seg=2, m=rot(y=-15))
    box(fix, (CX + 0.2, ry, CH + 1.4), (0.3, 0.9, 0.3), MINT_B, bev=0.05, seg=1)            # 숫자 창
    for i in range(3):
        for j in range(3):
            cyl(fix, (CX + 0.75 + i * 0.12, ry - 0.4 + j * 0.4, CH + 0.84 - i * 0.04), (CX + 0.75 + i * 0.12, ry - 0.4 + j * 0.4, CH + 0.92 - i * 0.04),
                0.1, 0.1, rng.choice((PINK, BUTTER, SKY, WHITE)), seg=6)
    cyl(fix, (CX + 0.76, ry + 0.75, CH + 0.6), (CX + 0.76, ry + 1.05, CH + 0.6), 0.08, 0.08, IRON, seg=6)    # 옆 손잡이
    ball(fix, (CX + 0.76, ry + 1.12, CH + 0.6), 0.14, RED, seg=(8, 6))
    # 계산대 위: 사탕 병 2 · 봉지 걸이 (봉지 3크기 견본)
    for k, col in enumerate((PINK, BUTTER)):
        c = (CX - 0.2, CY0 + 0.7 + k * 1.0, CH + 0.16)
        lathe(glass, [(0.2, 0), (0.36, 0.02), (0.38, 0.1), (0.38, 0.72), (0.3, 0.8), (0, 0.82)], GLASS, seg=12, c=c)
        lathe(gds, [(0, 0.03), (0.33, 0.03), (0.34, 0.5), (0, 0.5)], col, seg=10, c=c)
        lathe(fix, [(0, 0.8), (0.28, 0.8), (0.3, 0.9), (0, 0.92)], WOOD_D, seg=10, c=c)
    # 주인 뒤 벽 사탕 선반
    for z in (3.8, 5.2):
        box(fix, (IX1 - 0.45, cy, z), (0.9, CY1 - CY0, 0.12), WOOD_L, bev=0.03, seg=1)
        y = CY0 + 0.3
        while y < CY1 - 0.4:
            col = rng.choice((PINK, BUTTER, SKY, LILAC, MINT_B))
            lathe(gds, [(0, 0), (0.25, 0), (0.27, 0.6), (0, 0.7)], col, seg=6, c=(IX1 - 0.45, y + 0.25, z + 0.06))
            y += 0.65
    # 시계 (뒷벽, 냉장고 위)
    cc = (fx, D - T - 0.05, FH + 1.8)
    lathe(fix, [(0, 0), (0.9, 0), (0.95, 0.12), (0.9, 0.2), (0, 0.2)], WOOD_D, seg=20, c=cc, m=rot(x=90))
    lathe(fix, [(0, 0.2), (0.78, 0.2), (0, 0.22)], WHITE, seg=20, c=cc, m=rot(x=90))
    box(fix, (cc[0], cc[1] - 0.25, cc[2] + 0.25), (0.08, 0.04, 0.5), IRON, bev=0, seg=1)
    box(fix, (cc[0] + 0.2, cc[1] - 0.25, cc[2]), (0.4, 0.04, 0.07), IRON, bev=0, seg=1)

    # 가게 밖 소품 (왼쪽 창 아래 나무 의자 + 음료 상자, 오른쪽 창 아래 아이스크림 냉동고)
    props = part("Mk_Props", "밖 소품: 나무 의자·음료 상자 3·아이스크림 냉동고 (충돌 켬)")
    bx = -(DOOR_W / 2 + 1.0 + (hw - 1.5 - DOOR_W / 2 - 1.0) / 2)
    box(props, (bx + 1.0, -1.2, 1.4), (5.0, 1.3, 0.25), WOOD_L, bev=0.08, seg=2)
    for sx in (-1, 1):
        for sy in (-1, 1):
            box(props, (bx + 1.0 + sx * 2.2, -1.2 + sy * 0.45, 0.65), (0.25, 0.25, 1.3), WOOD_D, bev=0.05, seg=1)
    for k, col in enumerate((BUTTER, MINT_B, PINK)):
        c = (bx - 3.0 + (k % 2) * 0.0, -1.4, 0.6 + k * 1.15)
        box(props, c, (2.0, 1.4, 1.1), col, bev=0.12, seg=2)
        box(props, (c[0], c[1] - 0.71, c[2] + 0.1), (1.0, 0.04, 0.35), WHITE, bev=0, seg=1)
        for i in range(4):
            cyl(props, (c[0] - 0.6 + i * 0.4, c[1], c[2] + 0.55), (c[0] - 0.6 + i * 0.4, c[1], c[2] + 0.8), 0.12, 0.08, rng.choice((SKY, CORAL, LEAF)), seg=6)
    fzx = -bx
    box(props, (fzx, -1.3, 1.5), (4.4, 2.0, 2.6), SKY, bev=0.25, seg=2)
    box(props, (fzx, -1.3, 2.86), (4.2, 1.8, 0.16), WHITE, bev=0.06, seg=1)
    box(glass, (fzx, -1.3, 2.97), (3.7, 1.4, 0.06), GLASS, bev=0, seg=1)
    for i in range(6):
        box(gds, (fzx - 1.5 + i * 0.6, -1.3 + (i % 2) * 0.3 - 0.15, 2.8), (0.45, 0.3, 0.12), rng.choice((PINK, BUTTER, WHITE, LILAC)), bev=0.03, seg=1)
    flat_shape(props, (fzx, -2.31, 1.6), heart_pts(0.5), 0.04, WHITE, m=rot(x=90))
    for sx in (-1, 1):
        cyl(props, (fzx + sx * 1.9, -1.3, 0), (fzx + sx * 1.9, -1.3, 0.25), 0.2, 0.2, IRON, seg=8)

    # 자리 표시 (코드가 Attachment로 쓰고 부품은 숨김)
    marks = {
        "Mk_Pt_Door": ((0, -1.5, FLOOR + 0.05), "문 바깥 가운데 (길 안내 화살표 끝·들어가는 곳)"),
        "Mk_Pt_Owner": ((IX1 - 1.4, cy, FLOOR + 0.05), "주인 NPC 서는 곳 (계산대 뒤, 앞 = Roblox +X 쪽 = 가게 안)"),
        "Mk_Pt_Customer": ((CX - CDp / 2 - 1.2, cy, FLOOR + 0.05), "플레이어가 계산대 앞에 서는 곳 (ProximityPrompt '장보기')"),
        "Mk_Pt_Register": ((CX + 0.1, ry, CH + 0.9), "금전 등록기 (딸깍 소리·반짝)"),
        "Mk_Pt_Delivery": ((-hw - 2.5, -1.5, FLOOR + 0.05), "배달 오토바이 세울 곳 (나중, Lv10 전화 배달)"),
    }
    for nm, (c, note) in marks.items():
        mp = part(nm, note + " — 투명·충돌 끔")
        box(mp, c, (0.4, 0.4, 0.1), PINK, bev=0, seg=1)
    # MarketDoor·MarketCounter 등은 골목 코드(AlleyBuilder, feat/alley-market-1125)가 위 Mk_Pt_*에서 만들어 씀 (이름이 겹치지 않게 여기서는 안 만듦)

    info = dict(W=W, D=D, H=H)
    cams = {
        "front": ((-22, -30, 13), (0, 4, 6), 30),
        "inside": ((-13.5, 1.4, 9.5), (4, 10, 1.0), 20),
        "counter": ((-1, 1.6, 7), (12, 5, 2.5), 28),
    }
    return info, cams


# ───────────────────────── 봉지 ─────────────────────────
def build_bags():
    BAG = (250, 246, 238)
    STRIPE = (150, 204, 176)
    specs = (("S", 0.9, 0.55, 0.95), ("M", 1.2, 0.68, 1.25), ("L", 1.5, 0.8, 1.6))
    xs = {"S": -3.0, "M": 0.0, "L": 3.4}
    for tag, w, d, h in specs:
        p = part(f"Bag_{tag}", f"장바구니 봉지 {tag} (폭 {w}, 높이 {h}). 원점 = 이 부품 표의 grip (손잡이 잡는 곳) — 코드가 오른손 Attachment에 맞춤")
        ox = xs[tag]
        top = -0.75                      # 손잡이 잡는 곳 = z 0, 봉지 윗변 = 그 아래 0.75
        zc = top - h / 2
        # 몸통: 아래가 살짝 넓은 둥근 봉지
        box(p, (ox, 0, zc), (w, d, h), BAG, bev=min(0.24, d * 0.35), seg=3)
        # 민트 줄 2개 + 가운데 하트 (가상 무늬)
        for dz in (h * 0.28, h * 0.18):
            box(p, (ox, -d * 0.53, zc + dz), (w * 0.92, 0.03, 0.06), STRIPE, bev=0, seg=1)
        flat_shape(p, (ox, -d * 0.53, zc - h * 0.12), [(x * 0.9, y * 0.9) for x, y in heart_pts(min(w, h) * 0.18)], 0.03, PINK, m=rot(x=90))
        # 손잡이 2개 (앞뒤 판에서 올라와 위에서 만남)
        for sy in (-1, 1):
            pts = []
            for k in range(7):
                t = k / 6
                a = math.pi * t
                pts.append((ox + (w * 0.28) * math.cos(a), sy * d * 0.32 * (1 - math.sin(a) * 0.9), top + 0.02 + 0.72 * math.sin(a)))
            arc_tube(p, pts, 0.05, BAG, seg=5)
        # 위로 삐죽 나온 재료 (크기마다 다르게)
        if tag in ("S", "M", "L"):
            soda_box(p, (ox - w * 0.18, 0.02, top + 0.15), 0.42)
        if tag in ("M", "L"):
            box(p, (ox + w * 0.16, 0.05, top + 0.2), (0.5, 0.36, 0.7), SUGAR, bev=0.12, seg=2)
            box(p, (ox + w * 0.16, -0.14, top + 0.25), (0.28, 0.02, 0.2), SKY, bev=0, seg=1)
        if tag == "L":
            for j in range(4):
                cyl(p, (ox - w * 0.05 + j * 0.07, -0.15, top - 0.3), (ox - w * 0.05 + j * 0.07 + 0.05, -0.18, top + 0.55), 0.035, 0.035, WOOD_L, seg=5)
            box(p, (ox - w * 0.02, -0.17, top + 0.05), (0.32, 0.12, 0.12), PINK, bev=0.02, seg=1)
    cams = {"all": ((1.0, -9.5, 0.6), (0.2, 0, -1.0), 40)}
    return dict(), cams


# ───────────────────────── 의자 ─────────────────────────
def build_chair():
    p = part("OrderChair", "주문 대기 의자: 나무 틀·분홍 방석·등받이 별 구멍 장식. 원점 = 바닥 가운데, 앞 = Blender -Y (Roblox -Z)")
    SH = 0.9           # 방석 윗면 높이 ≈ 손님 엉덩이 관절 (0.75~0.95)
    W, Dp = 1.7, 1.5
    for sx in (-1, 1):
        for sy in (-1, 1):
            cyl(p, (sx * (W / 2 - 0.15), sy * (Dp / 2 - 0.15), 0), (sx * (W / 2 - 0.12), sy * (Dp / 2 - 0.12), SH - 0.2), 0.09, 0.1, WOOD_D, seg=8)
    for sx in (-1, 1):  # 다리 사이 가로대
        box(p, (sx * (W / 2 - 0.14), 0, 0.3), (0.08, Dp - 0.3, 0.08), WOOD_D, bev=0.02, seg=1)
    box(p, (0, 0, SH - 0.15), (W, Dp, 0.14), WOOD, bev=0.06, seg=2)                         # 앉는 판
    box(p, (0, -0.02, SH - 0.02), (W - 0.2, Dp - 0.2, 0.16), PINK, bev=0.07, seg=3)          # 방석
    # 등받이: 기둥 2 + 위 판(별 구멍처럼 크림 별 붙임) + 가로살
    for sx in (-1, 1):
        box(p, (sx * (W / 2 - 0.15), Dp / 2 - 0.12, SH + 0.65), (0.14, 0.14, 1.5), WOOD_D, bev=0.04, seg=1)
    box(p, (0, Dp / 2 - 0.12, SH + 1.3), (W, 0.16, 0.6), WOOD, bev=0.07, seg=2)
    flat_shape(p, (0, Dp / 2 - 0.21, SH + 1.3), star_pts(0.22), 0.02, BUTTER, m=rot(x=90))
    box(p, (0, Dp / 2 - 0.12, SH + 0.55), (W - 0.3, 0.1, 0.12), WOOD_L, bev=0.03, seg=1)
    mp = part("OrderSeat", "앉는 판 (판매 세션 규칙: 이 부품 윗면 = 방석 윗면 0.96에 손님이 앉고 LookVector(-Z) 쪽을 봄) — 투명·충돌 끔")
    box(mp, (0, -0.02, SH + 0.01), (W - 0.2, Dp - 0.2, 0.1), MINT_B, bev=0, seg=1)
    cams = {"chair": ((3.2, -4.2, 2.6), (0, 0, 0.9), 40)}
    return dict(), cams


info, cams = {"market": build_market, "bags": build_bags, "chair": build_chair}[KIND]()
base = f"dalgona_{KIND}"
objs = finish(OUT, base, f"# {base} — tools/blender/cozy_market.py ({KIND})")
preview(OUT, base, objs, cams, glass_suffix=("_Glass",), lamp_suffix=("_Lamps",), ground=(KIND != "bags"))
print(f"[{base}] done")
