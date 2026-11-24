# 작은 탁자 마름모 테이블보용 꽃무늬 타일 (2026-11-25, 판매 세션 요청: 연한 크림·민트 바탕 + 작은 파란·연두 꽃 촘촘히, 파스텔)
# 이음매 없이 반복: 가장자리에 걸친 무늬는 반대쪽에도 그림 (±크기로 한 번씩 더 그림).
# 실행: python tools/floral_tile.py <출력 png> [크기=512]
import math
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

OUT = sys.argv[1]
SIZE = int(sys.argv[2]) if len(sys.argv) > 2 else 512
SS = 4                      # 4배로 그리고 줄여서 가장자리 부드럽게
S = SIZE * SS
random.seed(11)

BG = (240, 243, 228)        # 연한 크림·민트
GRID = (214, 226, 190)      # 아주 옅은 마름모 격자
BLUE = (150, 176, 220)
BLUE_D = (118, 146, 198)
LIME = (184, 208, 120)
LEAF = (150, 186, 120)
CENTER = (250, 236, 170)

img = Image.new("RGB", (S, S), BG)
d = ImageDraw.Draw(img)


def wrap(fn, x, y):
    for ox in (-S, 0, S):
        for oy in (-S, 0, S):
            fn(x + ox, y + oy)


def ellipse(cx, cy, rx, ry, col, ang=0):
    # 기울인 타원 = 다각형
    pts = []
    for i in range(24):
        t = 2 * math.pi * i / 24
        px, py = rx * math.cos(t), ry * math.sin(t)
        pts.append((cx + px * math.cos(ang) - py * math.sin(ang), cy + px * math.sin(ang) + py * math.cos(ang)))
    d.polygon(pts, fill=col)


# 옅은 마름모 격자 (대각선, 무늬 사이)
step = S // 4
w = max(1, S // 400)
for k in range(-8, 9):
    d.line([(k * step, 0), (k * step + S, S)], fill=GRID, width=w)
    d.line([(k * step, S), (k * step + S, 0)], fill=GRID, width=w)


def flower(x, y, r, col, dark, rot):
    for i in range(5):
        a = rot + 2 * math.pi * i / 5
        ellipse(x + r * 0.62 * math.cos(a), y + r * 0.62 * math.sin(a), r * 0.48, r * 0.34, col, a)
        ellipse(x + r * 0.8 * math.cos(a), y + r * 0.8 * math.sin(a), r * 0.12, r * 0.09, dark, a)
    ellipse(x, y, r * 0.24, r * 0.24, CENTER)


def motif(cx, cy):
    u = S / 512 * 1.3                       # 512 기준 픽셀 (1.3배: 게임에서 2스터드 한 장이라 너무 잘면 뭉개짐)
    rot = random.uniform(0, math.pi)
    # 잎 3장
    for i in range(3):
        a = rot + i * 2.1 + 0.6
        def leaf(x, y, a=a):
            ellipse(x + 13 * u * math.cos(a), y + 13 * u * math.sin(a), 8 * u, 3.4 * u, LEAF, a)
        wrap(leaf, cx, cy)
    # 큰 꽃 1 + 작은 꽃 2 (송이)
    wrap(lambda x, y: flower(x, y, 11 * u, BLUE, BLUE_D, rot), cx, cy)
    for i in range(2):
        a = rot + math.pi * 0.9 + i * 1.3
        px, py = cx + 15 * u * math.cos(a), cy + 15 * u * math.sin(a)
        wrap(lambda x, y: flower(x, y, 6.5 * u, BLUE, BLUE_D, rot + i), px, py)
    # 연두 점 4개
    for i in range(4):
        a = random.uniform(0, 2 * math.pi)
        rr = random.uniform(20, 26) * u
        wrap(lambda x, y: ellipse(x, y, 2.6 * u, 2.6 * u, LIME), cx + rr * math.cos(a), cy + rr * math.sin(a))


# 엇갈린 줄 (마름모 배치): 가로 4개, 세로 8줄
for j in range(8):
    for i in range(4):
        cx = (i * 128 + (j % 2) * 64 + 32) * S / 512
        cy = (j * 64 + 32) * S / 512
        motif(cx, cy)

img = img.resize((SIZE, SIZE), Image.LANCZOS).filter(ImageFilter.SMOOTH)
img.save(OUT)
# 이음매 확인용 2×2
chk = Image.new("RGB", (SIZE * 2, SIZE * 2))
for ox in (0, SIZE):
    for oy in (0, SIZE):
        chk.paste(img, (ox, oy))
chk.save(OUT.replace(".png", "_2x2.png"))
print("saved", OUT)
