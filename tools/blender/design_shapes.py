# 안쪽 선이 있는 도안(문어·호랑이·공룡·궁전 + 최고 등급 Master 4종)을 그려서 shape_data.json으로 저장한다.
# 실행 (Blender 말고 그냥 python, OpenCV 필요): python tools/blender/design_shapes.py
# 결과 tools/blender/shape_data.json: { id: { outline: 바깥 외곽선, holes: 안쪽 구멍(같이 뚫어야 하는 닫힌 선), lines: 각인만 되는 장식선 } }
# 좌표는 shapes.py와 같은 단위(대략 -1~1, y 위). 크기 조정은 shapes.py가 한다.
# 방법: 원·막대·다각형을 흑백 그림에 칠해 합친 뒤(OpenCV) 테두리를 따서 외곽선을 얻는다.

import json
import math
import os

import cv2
import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
N = 1100  # 그림 크기 (px)
PX = 480  # 1 단위 = 480 px


def to_px(p):
    return (int(round(N / 2 + p[0] * PX)), int(round(N / 2 - p[1] * PX)))


def to_unit(q):
    return (round((q[0] - N / 2) / PX, 4), round((N / 2 - q[1]) / PX, 4))


class Canvas:
    def __init__(self):
        self.m = np.zeros((N, N), np.uint8)
        self.lines = []  # 각인 장식선
        self.holes = []  # 정확한 구멍(시에르핀스키처럼 직접 준 것)

    def poly(self, pts, on=True):
        cv2.fillPoly(self.m, [np.array([to_px(p) for p in pts], np.int32)], 255 if on else 0, cv2.LINE_8)

    def circle(self, c, r, on=True):
        cv2.circle(self.m, to_px(c), int(r * PX), 255 if on else 0, -1)

    def ellipse(self, c, rx, ry, ang=0, on=True):
        cv2.ellipse(self.m, to_px(c), (int(rx * PX), int(ry * PX)), -ang, 0, 360, 255 if on else 0, -1)

    def rect(self, x0, y0, x1, y1, on=True):
        self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], on)

    def tube(self, path, w0, w1=None):
        """점 경로를 따라 굵기 w0 → w1로 줄어드는 관."""
        w1 = w0 if w1 is None else w1
        dense = []
        for a, b in zip(path, path[1:]):
            n = max(2, int(math.dist(a, b) * PX / 3))
            dense += [(a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n) for i in range(n)]
        dense.append(path[-1])
        for i, p in enumerate(dense):
            t = i / max(1, len(dense) - 1)
            cv2.circle(self.m, to_px(p), max(1, int((w0 + (w1 - w0) * t) / 2 * PX)), 255, -1)

    def line(self, pts, closed=False):
        self.lines.append({"pts": [list(map(lambda v: round(v, 4), p)) for p in pts], "closed": closed})

    def loop_circle(self, c, r, n=20):
        self.line([(c[0] + math.cos(2 * math.pi * k / n) * r, c[1] + math.sin(2 * math.pi * k / n) * r) for k in range(n)], True)

    def result(self, eps=1.6):
        cs, hier = cv2.findContours(self.m, cv2.RETR_CCOMP, cv2.CHAIN_APPROX_NONE)
        outer = max((i for i in range(len(cs)) if hier[0][i][3] < 0), key=lambda i: cv2.contourArea(cs[i]))

        def simp(c):
            c = cv2.approxPolyDP(c, eps, True)
            return [list(to_unit(q[0])) for q in c]

        holes = [simp(cs[i]) for i in range(len(cs)) if hier[0][i][3] == outer and cv2.contourArea(cs[i]) > 40]
        return {"outline": simp(cs[outer]), "holes": holes + self.holes, "lines": self.lines}


def arc(c, r, a0, a1, n=12):
    return [(c[0] + math.cos(math.radians(a0 + (a1 - a0) * i / n)) * r, c[1] + math.sin(math.radians(a0 + (a1 - a0) * i / n)) * r) for i in range(n + 1)]


def spiral_path(start, ang, length, turn, n=40):
    """start에서 ang(도) 방향으로 출발해 끝으로 갈수록 turn(도)만큼 더 감기는 경로."""
    pts, (x, y) = [start], start
    for i in range(1, n + 1):
        t = i / n
        a = math.radians(ang + turn * t * t)
        x += math.cos(a) * length / n
        y += math.sin(a) * length / n
        pts.append((x, y))
    return pts


# ---------------------------------------------------------------- 다시 그린 도안
def octopus():
    c = Canvas()
    c.ellipse((0, 0.32), 0.56, 0.52)
    c.ellipse((0, -0.02), 0.52, 0.3)
    # 다리 6개 (레퍼런스처럼 통통하게): 바깥 쌍은 옆으로 뻗어 위로 말리고, 나머지는 아래로 내려가 바깥으로 말린다
    for s in (-1, 1):
        c.tube(spiral_path((s * 0.44, -0.04), 90 - s * 105, 0.6, s * 250), 0.15, 0.07)
        c.tube(spiral_path((s * 0.28, -0.2), 90 - s * 150, 0.6, s * 210), 0.15, 0.07)
        c.tube(spiral_path((s * 0.1, -0.26), 90 - s * 176, 0.55, s * 170), 0.14, 0.07)
    for s in (-1, 1):
        c.loop_circle((s * 0.2, 0.3), 0.065)
    r = c.result()
    r["holes"] = []  # 다리 끝 말린 안쪽 틈은 막는다 (잘라 낼 구멍 아님)
    return r


def tiger():
    c = Canvas()
    c.ellipse((0, -0.04), 0.8, 0.7)
    for s in (-1, 1):
        c.circle((s * 0.56, 0.55), 0.24)
        c.poly([(s * 0.7, 0.05), (s * 0.92, -0.2), (s * 0.66, -0.3)])  # 볼 털
        c.poly([(s * 0.6, -0.36), (s * 0.78, -0.48), (s * 0.48, -0.52)])
    for s in (-1, 1):
        c.line(arc((s * 0.56, 0.55), 0.12, 0, 360, 16), True)  # 귀 안쪽
        c.loop_circle((s * 0.3, 0.06), 0.1)  # 눈
        c.line([(s * 0.5, 0.2), (s * 0.4, 0.26), (s * 0.22, 0.26)])  # 눈썹 줄무늬
        for k in range(3):  # 뺨 줄무늬
            y = -0.08 - k * 0.13
            c.line([(s * 0.7, y), (s * 0.58, y - 0.03), (s * 0.48, y - 0.08)])
    c.line([(0, 0.6), (0, 0.4)])  # 이마 王 무늬
    c.line([(-0.16, 0.56), (0.16, 0.56)])
    c.line([(-0.12, 0.46), (0.12, 0.46)])
    c.line([(-0.12, -0.1), (0.12, -0.1), (0, -0.24)], True)  # 코
    c.line(arc((-0.12, -0.26), 0.12, 200, 360, 8) + arc((0.12, -0.26), 0.12, 180, 340, 8))  # 입
    return c.result()


def dinosaur():
    # 오른쪽을 보는 티라노사우루스: 이빨 벌린 입, 짧은 팔, 두 다리, 긴 꼬리
    c = Canvas()
    body = [
        (-1.0, -0.06), (-0.6, 0.05), (-0.3, 0.18), (0.0, 0.34), (0.2, 0.47), (0.32, 0.62), (0.42, 0.78), (0.6, 0.83),
        (0.85, 0.79), (0.98, 0.69), (1.0, 0.58), (0.95, 0.53),
        (0.9, 0.47), (0.86, 0.53), (0.81, 0.47), (0.77, 0.53), (0.72, 0.47), (0.68, 0.52),  # 윗니
        (0.6, 0.5), (0.68, 0.43), (0.72, 0.38), (0.76, 0.43), (0.8, 0.38), (0.84, 0.43),  # 아랫니
        (0.9, 0.38), (0.83, 0.31), (0.56, 0.3), (0.45, 0.2),
        (0.5, 0.13), (0.63, 0.1), (0.67, 0.03), (0.6, 0.04), (0.53, 0.05), (0.44, 0.05),  # 팔
        (0.38, -0.15), (0.31, -0.3), (0.34, -0.66), (0.47, -0.76), (0.47, -0.86), (0.17, -0.86), (0.19, -0.58), (0.1, -0.4),
        (0.03, -0.46), (-0.03, -0.7), (0.04, -0.77), (0.04, -0.86), (-0.27, -0.86), (-0.24, -0.58), (-0.27, -0.3),
        (-0.47, -0.16), (-0.76, -0.12),
    ]
    c.poly(body)
    c.loop_circle((0.64, 0.7), 0.04, 12)
    c.line([(0.36, -0.15), (0.24, -0.32), (0.22, -0.5)])  # 앞다리 허벅지
    return c.result(eps=1.2)


def palace():
    # 뾰족 탑이 여러 개 있는 궁전: 가운데 큰 탑(깃발), 안쪽 탑 2개, 바깥 탑 2개, 아치 문
    c = Canvas()
    c.rect(-0.62, -0.86, 0.62, -0.1)
    c.rect(-0.22, -0.1, 0.22, 0.38)
    c.poly([(-0.27, 0.38), (0.27, 0.38), (0, 0.8)])
    c.tube([(0, 0.78), (0, 1.0)], 0.035)
    c.poly([(0, 1.0), (0.22, 0.94), (0, 0.88)])
    for s in (-1, 1):
        c.rect(s * 0.62, -0.86, s * 0.9, 0.18) if s > 0 else c.rect(-0.9, -0.86, -0.62, 0.18)
        c.poly([(s * 0.57, 0.18), (s * 0.95, 0.18), (s * 0.76, 0.66)])
        c.rect(min(s * 0.3, s * 0.5), -0.1, max(s * 0.3, s * 0.5), 0.26)
        c.poly([(s * 0.26, 0.26), (s * 0.54, 0.26), (s * 0.4, 0.62)])
        c.tube([(s * 0.4, 0.6), (s * 0.4, 0.76)], 0.03)
        c.poly([(s * 0.4, 0.76), (s * 0.4 + 0.15, 0.72), (s * 0.4, 0.68)])
    c.rect(-0.17, -0.87, 0.17, -0.5, on=False)  # 아치 문
    c.circle((0, -0.5), 0.17, on=False)
    for x in (-0.76, -0.4, 0.4, 0.76):  # 창문
        c.line([(x - 0.06, -0.45), (x - 0.06, -0.3)] + arc((x, -0.3), 0.06, 180, 0, 6)[1:] + [(x + 0.06, -0.45)], True)
    for x in (-0.76, 0.76):
        c.line([(x - 0.05, -0.05), (x - 0.05, 0.05)] + arc((x, 0.05), 0.05, 180, 0, 6)[1:] + [(x + 0.05, -0.05)], True)
    c.line([(-0.07, 0.05), (-0.07, 0.17)] + arc((0, 0.17), 0.07, 180, 0, 6)[1:] + [(0.07, 0.05)], True)
    c.line([(-0.62, -0.1), (0.62, -0.1)])  # 성벽 윗선
    return c.result()


# ---------------------------------------------------------------- 최고 등급 (Master)
def spider():
    c = Canvas()
    c.ellipse((0, -0.32), 0.3, 0.42)  # 배
    c.circle((0, 0.2), 0.2)  # 머리가슴
    c.circle((0, 0.42), 0.1)
    legs = [  # (시작, 무릎, 발끝) 오른쪽, 왼쪽은 대칭
        [(0.12, 0.3), (0.42, 0.62), (0.5, 0.98)],
        [(0.16, 0.22), (0.6, 0.42), (0.84, 0.6)],
        [(0.16, 0.12), (0.6, 0.02), (0.86, -0.3)],
        [(0.12, 0.04), (0.48, -0.32), (0.56, -0.96)],
    ]
    for leg in legs:
        for s in (-1, 1):
            c.tube([(s * x, y) for (x, y) in leg], 0.075, 0.035)
    c.line([(-0.2, 0.0), (0, 0.06), (0.2, 0.0)])  # 몸 마디
    c.line([(0, -0.08), (0, -0.62)])  # 배 무늬
    c.line([(-0.16, -0.2), (0, -0.3), (0.16, -0.2)])
    c.line([(-0.18, -0.42), (0, -0.52), (0.18, -0.42)])
    return c.result(eps=1.2)


def sierpinski():
    c = Canvas()
    h = 1.8 * math.sqrt(3) / 2
    A, B, C = (-0.9, -h / 2), (0.9, -h / 2), (0, h / 2)
    c.poly([A, B, C])
    holes = []

    def rec(a, b, cc, d):
        ab = ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)
        bc = ((b[0] + cc[0]) / 2, (b[1] + cc[1]) / 2)
        ca = ((cc[0] + a[0]) / 2, (cc[1] + a[1]) / 2)
        holes.append([list(ab), list(bc), list(ca)])
        if d > 1:
            rec(a, ab, ca, d - 1)
            rec(ab, b, bc, d - 1)
            rec(ca, bc, cc, d - 1)

    rec(A, B, C, 3)
    r = c.result()
    r["outline"] = [list(A), list(B), list(C)]
    # 구멍이 바깥선·서로와 붙지 않게 살짝 줄인다
    shrunk = []
    for t in holes:
        cx, cy = sum(p[0] for p in t) / 3, sum(p[1] for p in t) / 3
        shrunk.append([[round(cx + (p[0] - cx) * 0.8, 4), round(cy + (p[1] - cy) * 0.8, 4)] for p in t])
    r["holes"] = shrunk
    return r


def snowflake():
    c = Canvas()
    for k in range(6):
        a = math.radians(90 + 60 * k)
        d = (math.cos(a), math.sin(a))
        c.tube([(0, 0), (d[0] * 0.95, d[1] * 0.95)], 0.11, 0.07)
        for r0, ln in ((0.42, 0.3), (0.68, 0.2)):
            p = (d[0] * r0, d[1] * r0)
            for s in (-1, 1):
                b = a + s * math.radians(55)
                c.tube([p, (p[0] + math.cos(b) * ln, p[1] + math.sin(b) * ln)], 0.08, 0.055)
        c.circle((d[0] * 0.95, d[1] * 0.95), 0.06)
    c.poly([(math.cos(math.radians(60 * k)) * 0.26, math.sin(math.radians(60 * k)) * 0.26) for k in range(6)])
    r = c.result(eps=1.2)
    r["lines"].append({"pts": [[round(math.cos(math.radians(30 + 60 * k)) * 0.14, 4), round(math.sin(math.radians(30 + 60 * k)) * 0.14, 4)] for k in range(6)], "closed": True})
    return r


def lotus():
    # 연꽃 문양: 꽃잎 5장 + 받침 + 양쪽으로 말린 덩굴
    c = Canvas()
    c.ellipse((0, 0.32), 0.17, 0.5)
    for s in (-1, 1):
        c.ellipse((s * 0.26, 0.22), 0.15, 0.44, ang=s * -28)
        c.ellipse((s * 0.5, 0.06), 0.13, 0.36, ang=s * -58)
    c.ellipse((0, -0.22), 0.62, 0.17)
    c.rect(-0.08, -0.6, 0.08, -0.3)
    c.ellipse((0, -0.66), 0.42, 0.12)
    for s in (-1, 1):
        c.tube(spiral_path((s * 0.5, -0.24), 90 - s * 120, 0.55, s * 330, 60), 0.09, 0.05)
        c.tube(spiral_path((s * 0.3, -0.66), 90 - s * 110, 0.45, s * -300, 60), 0.075, 0.045)
    c.line([(0, -0.1), (0, 0.66)])  # 꽃잎 잎맥
    for s in (-1, 1):
        c.line([(s * 0.08, -0.1), (s * 0.32, 0.5)])
        c.line([(s * 0.22, -0.12), (s * 0.66, 0.24)])
    c.line([(-0.5, -0.22), (0.5, -0.22)])
    c.line([(-0.3, -0.66), (0.3, -0.66)])
    return c.result(eps=1.2)


DESIGNS = {
    "Octopus": octopus, "Tiger": tiger, "Dinosaur": dinosaur, "Palace": palace,
    "Spider": spider, "Sierpinski": sierpinski, "Snowflake": snowflake, "Lotus": lotus,
}

if __name__ == "__main__":
    data = {k: fn() for k, fn in DESIGNS.items()}
    with open(os.path.join(HERE, "shape_data.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    # 확인용 그림
    import sys
    out = sys.argv[1] if len(sys.argv) > 1 else None
    if out:
        W = np.full((2 * 420, 4 * 420, 3), 255, np.uint8)
        for i, (k, d) in enumerate(data.items()):
            ox, oy = (i % 4) * 420 + 210, (i // 4) * 420 + 210

            def P(p):
                return (int(ox + p[0] * 180), int(oy - p[1] * 180))

            cv2.fillPoly(W, [np.array([P(p) for p in d["outline"]], np.int32)], (150, 200, 230))
            cv2.polylines(W, [np.array([P(p) for p in d["outline"]], np.int32)], True, (0, 0, 0), 2)
            for h in d["holes"]:
                cv2.fillPoly(W, [np.array([P(p) for p in h], np.int32)], (255, 255, 255))
                cv2.polylines(W, [np.array([P(p) for p in h], np.int32)], True, (0, 0, 200), 2)
            for ln in d["lines"]:
                cv2.polylines(W, [np.array([P(p) for p in ln["pts"]], np.int32)], ln["closed"], (60, 60, 60), 1)
            cv2.putText(W, k, (ox - 200, oy - 190), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 0, 255), 1)
            print(k, "outline", len(d["outline"]), "holes", len(d["holes"]), "lines", len(d["lines"]))
        cv2.imwrite(out, W)
