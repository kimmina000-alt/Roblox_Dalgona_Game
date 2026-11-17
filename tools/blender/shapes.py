# 달고나 도안 18종의 외곽선 (기획서 SYSTEMS_SPECIFICATION 6장 / ART_AND_ASSET_GUIDE 5장)
# 좌표: 단위 크기(대략 -1~1), y가 위. build()에서 게임 크기로 줄인다 (별 바깥 반지름 0.8 = 1.0 * 0.8).
# 모든 외곽선은 자기 자신과 교차하지 않는 닫힌 다각형(반시계 방향)이다.
# 일부 도안(물고기·새·나비·궁궐·호랑이·용 등)은 게임 오리지널 디자인이다.

import math

SCALE = 0.8


def _arc(cx, cy, r, a0, a1, n):
    return [(cx + math.cos(a0 + (a1 - a0) * i / n) * r, cy + math.sin(a0 + (a1 - a0) * i / n) * r) for i in range(n + 1)]


def _bezier(p0, p1, p2, p3, n):
    pts = []
    for i in range(n + 1):
        t = i / n
        u = 1 - t
        pts.append((
            u ** 3 * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t ** 3 * p3[0],
            u ** 3 * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t ** 3 * p3[1],
        ))
    return pts


def _mirror(right_half):
    """x>=0 쪽 반을 (아래 가운데 → 위 가운데 순서로) 주면 좌우 대칭 외곽선을 만든다."""
    left = [(-x, y) for (x, y) in reversed(right_half[1:-1])]
    return right_half + left


def _dedupe(pts, eps=1e-4):
    out = []
    for p in pts:
        if not out or (abs(p[0] - out[-1][0]) > eps or abs(p[1] - out[-1][1]) > eps):
            out.append(p)
    if len(out) > 2 and abs(out[0][0] - out[-1][0]) < eps and abs(out[0][1] - out[-1][1]) < eps:
        out.pop()
    return out


def _polar(fn, n=120):
    return [(math.cos(2 * math.pi * i / n) * fn(2 * math.pi * i / n), math.sin(2 * math.pi * i / n) * fn(2 * math.pi * i / n)) for i in range(n)]


def circle():
    return _arc(0, 0, 0.92, 0, 2 * math.pi, 64)[:-1]


def square():
    h, r = 0.74, 0.08
    pts = []
    for cx, cy, a in ((h - r, -h + r, -math.pi / 2), (h - r, h - r, 0), (-h + r, h - r, math.pi / 2), (-h + r, -h + r, math.pi)):
        pts += _arc(cx, cy, r, a, a + math.pi / 2, 4)
    return pts


def triangle():
    pts = []
    R, r = 1.0, 0.07
    for k in range(3):
        a = math.radians(90 + 120 * k)  # 위 꼭짓점이 +y
        cx, cy = math.cos(a) * (R - 2 * r), math.sin(a) * (R - 2 * r) - 0.2
        pts += _arc(cx, cy, r, a - math.radians(60), a + math.radians(60), 4)
    return pts


def heart():
    pts = []
    for i in range(96):
        t = 2 * math.pi * i / 96
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x / 17.0, (y + 2.5) / 17.0))
    return list(reversed(pts))


def star():
    pts = []
    for k in range(10):
        a = math.radians(90 + k * 36)
        r = 1.0 if k % 2 == 0 else 0.45
        pts.append((math.cos(a) * r, math.sin(a) * r))
    return pts


def umbrella():
    pts = []
    pts += _arc(0, 0, 0.95, 0, math.pi, 40)  # 우산 지붕 (오른쪽 → 위 → 왼쪽)
    # 왼쪽 아래 물결 2개 (-0.95 → -0.07)
    for k in range(2):
        x0 = -0.95 + k * 0.44
        for i in range(1, 9):
            f = i / 8
            pts.append((x0 + 0.44 * f, 0.12 * math.sin(math.pi * f)))
    # 손잡이 대 (왼쪽 면 아래로) + J 고리
    pts.append((-0.07, -0.66))
    pts += _arc(-0.21, -0.66, 0.14, 0, -math.pi, 10)[1:]
    pts.append((-0.47, -0.66))
    pts += _arc(-0.21, -0.66, 0.26, -math.pi, 0, 14)[1:]
    pts.append((0.05, 0.0))
    # 오른쪽 아래 물결 2개 (0.05 → 0.95)
    for k in range(2):
        x0 = 0.05 + k * 0.45
        for i in range(1, 9):
            f = i / 8
            pts.append((x0 + 0.45 * f, 0.12 * math.sin(math.pi * f)))
    return pts[:-1]


def flower():
    return _polar(lambda a: 0.5 + 0.45 * (0.5 + 0.5 * math.cos(5 * (a - math.pi / 2))) ** 0.7, 150)


def fish():
    upper = _bezier((0.95, 0.0), (0.75, 0.55), (-0.15, 0.6), (-0.5, 0.06), 24)
    tail = [(-0.95, 0.5), (-0.78, 0.0), (-0.95, -0.5)]
    lower = _bezier((-0.5, -0.06), (-0.15, -0.6), (0.75, -0.55), (0.95, 0.0), 24)
    return _dedupe(upper + tail + lower[:-1])


def bird():
    # 옆에서 본 작은 새: 머리(오른쪽 위) · 부리 · 둥근 몸 · 꼬리(왼쪽)
    pts = []
    pts += _bezier((0.95, 0.38), (0.78, 0.3), (0.7, 0.26), (0.62, 0.22), 4)  # 부리 아래
    pts += _bezier((0.62, 0.22), (0.75, -0.2), (0.5, -0.6), (0.0, -0.62), 12)  # 가슴 · 배
    pts += _bezier((0.0, -0.62), (-0.35, -0.62), (-0.55, -0.45), (-0.72, -0.3), 8)
    pts += [(-0.98, -0.42), (-0.9, -0.12)]  # 꼬리
    pts += _bezier((-0.9, -0.12), (-0.55, 0.05), (-0.2, 0.25), (0.1, 0.32), 10)  # 등
    pts += _bezier((0.1, 0.32), (0.2, 0.75), (0.65, 0.78), (0.72, 0.5), 12)  # 머리
    pts += _bezier((0.72, 0.5), (0.8, 0.46), (0.88, 0.42), (0.95, 0.38), 3)  # 부리 위
    return _dedupe(pts)


def butterfly():
    def r(a):
        upper = math.sin(a) > 0
        w = 1.0 if upper else 0.78
        return 0.2 + 0.78 * w * abs(math.sin(2 * a)) ** 0.65

    return _polar(r, 160)


def airplane():
    right = [(0.0, -0.78), (0.36, -0.92), (0.36, -0.8), (0.08, -0.6), (0.08, -0.1), (0.95, -0.28), (0.95, -0.12), (0.08, 0.32), (0.08, 0.72)]
    right += _arc(0.0, 0.72, 0.08, 0, math.pi / 2, 4)[1:]
    return _dedupe(_mirror(right))


def cross():
    w, arm_y0, arm_y1, arm = 0.17, 0.12, 0.44, 0.64
    right = [(0.0, -0.95), (w, -0.95), (w, arm_y0), (arm, arm_y0), (arm, arm_y1), (w, arm_y1), (w, 0.95), (0.0, 0.95)]
    return _dedupe(_mirror(right))


def sword():
    right = [(0.0, -0.98), (0.1, -0.9), (0.06, -0.8), (0.06, -0.45), (0.42, -0.42), (0.42, -0.32), (0.13, -0.3), (0.13, 0.72), (0.0, 0.98)]
    return _dedupe(_mirror(right))


def octopus():
    pts = _arc(0, 0.18, 0.66, 0, math.pi, 30)  # 머리 (오른쪽 → 위 → 왼쪽)
    # 다리 4개: 왼쪽 → 오른쪽으로 아래로 늘어진 물결
    n = 64
    for i in range(1, n):
        t = i / n
        x = -0.66 - 0.22 * math.sin(math.pi * t) * (1 - 2 * t) + 1.32 * t
        y = 0.18 - 0.2 - 0.74 * (math.sin(4 * math.pi * t) ** 2) ** 0.45 * (0.65 + 0.35 * math.sin(math.pi * t))
        pts.append((x, y))
    return _dedupe(pts)


def palace():
    right = [
        (0.0, -0.95), (0.86, -0.95), (0.86, -0.8), (0.56, -0.8), (0.56, -0.02),  # 기단 · 벽
        (0.92, 0.06), (1.0, 0.2), (0.74, 0.2), (0.34, 0.3),  # 아래 지붕 처마 (끝이 들림)
        (0.34, 0.46), (0.64, 0.52), (0.7, 0.64), (0.44, 0.66), (0.28, 0.8), (0.0, 0.8),  # 위 지붕
    ]
    return _dedupe(_mirror(right))


def _chaikin(pts, sharp=(), it=2):
    """닫힌 다각형 모서리를 둥글게 (쿠키 틀 같은 부드러운 실루엣). sharp에 든 꼭짓점 번호는 뾰족하게 둔다."""
    keep = [i in sharp for i in range(len(pts))]
    for _ in range(it):
        out, ok = [], []
        n = len(pts)
        for i in range(n):
            p, q = pts[i], pts[(i + 1) % n]
            if keep[i]:
                out.append(p); ok.append(True)
            else:
                out.append((0.75 * p[0] + 0.25 * q[0], 0.75 * p[1] + 0.25 * q[1])); ok.append(False)
            if not keep[(i + 1) % n]:
                out.append((0.25 * p[0] + 0.75 * q[0], 0.25 * p[1] + 0.75 * q[1])); ok.append(False)
        pts, keep = out, ok
    return pts


# 호랑이·용·범선은 실제 달고나 틀(레퍼런스 사진: 공룡·말·곰 등 옆모습 실루엣)처럼
# 통통하고 단순한 옆모습 외곽선 + 둥근 모서리로 그린다.
def tiger():
    # 오른쪽을 보고 걷는 호랑이 옆모습: 귀 2개, 앞·뒷다리, 위로 말린 꼬리
    pts = [
        (-0.55, 0.26), (0.0, 0.32), (0.32, 0.3), (0.42, 0.42), (0.44, 0.56), (0.49, 0.72), (0.58, 0.6), (0.68, 0.61),
        (0.78, 0.73), (0.83, 0.56), (0.91, 0.48), (0.99, 0.34), (0.96, 0.21), (0.82, 0.14), (0.68, 0.08), (0.62, -0.05),
        (0.64, -0.66), (0.75, -0.72), (0.75, -0.84), (0.42, -0.84), (0.42, -0.26), (0.1, -0.3), (-0.28, -0.26),
        (-0.3, -0.7), (-0.21, -0.75), (-0.21, -0.84), (-0.6, -0.84), (-0.62, -0.32), (-0.71, -0.02), (-0.68, 0.16),
        (-0.78, 0.24), (-0.9, 0.42), (-0.95, 0.62), (-0.86, 0.73), (-0.79, 0.58), (-0.75, 0.43), (-0.64, 0.31),
    ]
    return _chaikin(pts, sharp={5, 8})


def dragon():
    # 일어선 용 옆모습 (공룡 틀처럼): 등 가시 5개, 뿔, 벌린 입, 팔, 굵은 다리, 길게 끌리는 꼬리
    pts, sharp = [(-1.0, -0.76)], {0}
    pts.append((-0.68, -0.56))
    ax, ay, bx, by = -0.44, -0.3, 0.06, 0.48
    dx, dy = bx - ax, by - ay
    L = math.hypot(dx, dy)
    nx, ny = -dy / L, dx / L
    for k in range(5):
        t0, tm, t1 = (k + 0.1) / 5, (k + 0.5) / 5, (k + 0.9) / 5
        pts.append((ax + dx * t0, ay + dy * t0))
        sharp.add(len(pts))
        pts.append((ax + dx * tm + nx * 0.17, ay + dy * tm + ny * 0.17))
        pts.append((ax + dx * t1, ay + dy * t1))
    pts += [(0.1, 0.62)]
    sharp.add(len(pts)); pts.append((0.1, 0.9))  # 뿔
    pts += [(0.26, 0.72), (0.48, 0.74), (0.82, 0.62), (0.94, 0.5)]
    sharp.add(len(pts)); pts.append((0.62, 0.45))  # 입 안쪽
    pts += [(0.84, 0.36), (0.74, 0.27), (0.42, 0.26), (0.42, 0.1), (0.62, 0.08)]
    sharp.add(len(pts)); pts.append((0.68, -0.02))  # 발톱
    pts += [(0.4, -0.04), (0.32, -0.28), (0.32, -0.7), (0.5, -0.76), (0.5, -0.87), (-0.12, -0.87), (-0.14, -0.62), (-0.44, -0.64), (-0.72, -0.74)]
    return _chaikin(pts, sharp=sharp)


def sailboat():
    # 배 몸통 + 큰 돛(오른쪽) + 작은 돛(왼쪽) + 돛대 끝 깃발
    return [
        (-0.62, -0.86), (0.62, -0.86), (0.92, -0.46), (0.06, -0.46), (0.06, -0.33), (0.72, -0.33), (0.06, 0.86),
        (0.06, 1.0), (-0.3, 0.92), (-0.04, 0.84), (-0.04, 0.6), (-0.62, -0.31), (-0.04, -0.31), (-0.04, -0.46), (-0.92, -0.46),
    ]


# 기획서 순서: (id, 한국어 이름, 등급, 함수)
SHAPES = [
    ("Circle", "동그라미", "Common", circle),
    ("Square", "네모", "Common", square),
    ("Triangle", "세모", "Common", triangle),
    ("Heart", "하트", "Uncommon", heart),
    ("Star", "별", "Uncommon", star),
    ("Umbrella", "우산", "Uncommon", umbrella),
    ("Flower", "꽃", "Rare", flower),
    ("Fish", "물고기", "Rare", fish),
    ("Bird", "새", "Rare", bird),
    ("Butterfly", "나비", "Epic", butterfly),
    ("Airplane", "비행기", "Epic", airplane),
    ("Cross", "십자가", "Epic", cross),
    ("Sword", "검", "Legendary", sword),
    ("Sailboat", "범선", "Legendary", sailboat),
    ("Octopus", "문어", "Legendary", octopus),
    ("Palace", "궁궐", "Mythic", palace),
    ("Tiger", "호랑이", "Mythic", tiger),
    ("Dragon", "용", "Mythic", dragon),
]


def outline(shape_id):
    for sid, _, _, fn in SHAPES:
        if sid == shape_id:
            pts = _dedupe(fn())
            # 반시계 방향으로 통일
            area = sum(pts[i][0] * pts[(i + 1) % len(pts)][1] - pts[(i + 1) % len(pts)][0] * pts[i][1] for i in range(len(pts)))
            if area < 0:
                pts.reverse()
            return [(x * SCALE, y * SCALE) for (x, y) in pts]
    raise KeyError(shape_id)


def self_intersects(pts):
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    n = len(pts)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        for j in range(i + 2, n):
            if i == 0 and j == n - 1:
                continue
            c, d = pts[j], pts[(j + 1) % n]
            d1, d2, d3, d4 = cross(c, d, a), cross(c, d, b), cross(a, b, c), cross(a, b, d)
            if ((d1 > 0) != (d2 > 0)) and ((d3 > 0) != (d4 > 0)):
                return (i, j)
    return None


if __name__ == "__main__":
    for sid, name, grade, _ in SHAPES:
        pts = outline(sid)
        xs, ys = [p[0] for p in pts], [p[1] for p in pts]
        print(f"{sid:10s} {name:4s} pts={len(pts):3d} x[{min(xs):.2f},{max(xs):.2f}] y[{min(ys):.2f},{max(ys):.2f}] selfX={self_intersects(pts)}")
