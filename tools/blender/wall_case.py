# 벽면 진열장 (D57 진열장 6단계 마지막 "벽면 진열장" = 누적 70칸, 2026-11-27 PM 묶음 1127)
#   지금 가게 가구 칸 61 (유리 진열장 4 + 걸이판 6×5 + 작은 탁자 3×3 ×3)이라 70을 못 채움 → 벽에 세우는 선반장 하나 더, 4열 × 3단 = 12칸 (61 + 12 = 73 ≥ 70).
#   칸 자리는 모델 부품이 아니라 서버(SalesService.furnitureSlot)가 가구 Role 부품 상자로 계산하는 방식이라, 걸이판("달고나 걸이판")과 같은 계산을 쓰게 만듦:
#     WallCaseBack = 뒤판 하나만 든 MeshPart, Role "벽면 진열장". 서버는 이 상자의 위 줄부터 rows 줄 · 옆으로 cols 칸,
#     칸 가운데 = 달고나 가운데, 막대 끝(놓는 자리) = 칸 가운데 − (lookSize/2 + lookStick[1]) = −0.825.
#     그래서 선반 윗면을 줄마다 칸 가운데 − 0.825에 둠 → 달고나가 선반 위에 서 있는 것처럼 보임.
#   뒤판 크기: 폭 8.4 (4칸 × 2.1) × 높이 6.0 (3단 × 2.0) × 두께 0.3. 선반 깊이 0.9.
# 좌표: 원점 = 바닥, 벽에 닿는 뒷면 가운데. 앞(가게 안) = Blender -Y (Roblox -Z). Studio에서 걸이판처럼 옆벽에 붙이면 됨 (뒤판이 가게 축 X로 얇게).
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/wall_case.py -- <출력 폴더(절대 경로)>
# 결과: dalgona_wall_case.glb (WallCaseBack, WallCase), dalgona_wall_case_parts.txt, dalgona_wall_case_preview.png

import math
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from cozy_kit import box, cyl, finish, flat_shape, part, preview, rot, star_pts  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else ".")
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)

WOOD = (198, 144, 98)
WOOD_D = (146, 98, 62)
WOOD_L = (222, 176, 122)
CREAM = (246, 234, 212)
MINT = (150, 204, 176)
BUTTER = (246, 214, 140)
PINK = (246, 178, 196)

COLS, ROWS = 4, 3
CELL_W, CELL_H = 2.1, 2.0
BW, BH, BT = COLS * CELL_W, ROWS * CELL_H, 0.3      # 뒤판 (Role 부품)
BASE = 0.7                                          # 아래 받침 높이 (뒤판 아래 끝)
DEPTH = 1.0                                         # 옆판 깊이
LIFT = 1.15 * 0.5 + 0.25                            # SALES.lookSize/2 + lookStick[1]

back = part("WallCaseBack", f"뒤판 = Role '벽면 진열장' (서버가 이 상자로 칸 {COLS}×{ROWS} 계산), {BW}×{BH}×{BT}. 크림 판. 충돌 켬")
body = part("WallCase", "옆판·선반·받침·위 장식 (Role 없음, 뒤판과 같은 Model에). 충돌 켬")
by = -BT / 2                                        # 뒤판 가운데 y (벽면 y = 0)
bz0 = BASE
box(back, (0, by, bz0 + BH / 2), (BW, BT, BH), CREAM, bev=0.03, seg=1)

fy = -DEPTH / 2                                     # 옆판 가운데 y
# 받침 (아래 서랍장 모양) + 옆판 + 위 판
box(body, (0, fy, BASE / 2), (BW + 0.6, DEPTH + 0.1, BASE), WOOD_D, bev=0.1, seg=2)
for k in range(COLS):
    cx = -BW / 2 + (k + 0.5) * CELL_W
    box(body, (cx, -DEPTH - 0.03, BASE / 2), (CELL_W - 0.35, 0.06, BASE - 0.25), WOOD, bev=0.03, seg=1)
    cyl(body, (cx, -DEPTH - 0.06, BASE / 2), (cx, -DEPTH - 0.16, BASE / 2), 0.07, 0.07, BUTTER, seg=8)
for sx in (-1, 1):
    box(body, (sx * (BW / 2 + 0.15), fy, bz0 + BH / 2), (0.3, DEPTH, BH), WOOD, bev=0.08, seg=2)
top_z = bz0 + BH
box(body, (0, fy - 0.05, top_z + 0.12), (BW + 0.7, DEPTH + 0.2, 0.24), WOOD_D, bev=0.08, seg=2)
# 위 장식판: 민트 물결 + 가운데 별 (글자 없음)
box(body, (0, by - 0.05, top_z + 0.75), (BW * 0.7, 0.16, 1.0), WOOD_L, bev=0.08, seg=2)
flat_shape(body, (0, by - 0.14, top_z + 0.75), star_pts(0.35), 0.04, BUTTER, m=rot(x=90))
for k in range(8):  # 장식판 위 끝 물결 (민트·분홍 반달)
    cx = -BW * 0.35 + (k + 0.5) * (BW * 0.7 / 8)
    flat_shape(body, (cx, by - 0.14, top_z + 1.25), [(math.cos(math.pi * j / 8) * 0.27, math.sin(math.pi * j / 8) * 0.27) for j in range(9)], 0.04,
               MINT if k % 2 == 0 else PINK, m=rot(x=90))
# 선반: 줄마다 윗면 = 칸 가운데 − LIFT (달고나가 선반 위에 섬), 앞 턱
for r in range(ROWS):
    row_c = top_z - (r + 0.5) * CELL_H
    st = row_c - LIFT
    box(body, (0, fy - 0.02, st - 0.06), (BW, DEPTH - 0.06, 0.12), WOOD_L, bev=0.03, seg=1)
    box(body, (0, -DEPTH + 0.02, st + 0.04), (BW, 0.08, 0.16), WOOD, bev=0.03, seg=1)   # 앞 턱 (달고나 안 떨어지게)
    # 칸 사이 작은 이름표 자리 (버터색 판, 글자는 없음)
    for k in range(COLS):
        cx = -BW / 2 + (k + 0.5) * CELL_W
        box(body, (cx, -DEPTH - 0.03, st - 0.07), (0.6, 0.03, 0.16), BUTTER, bev=0, seg=1)

marker = part("WallCase_Pt_Slots", "참고용: 칸 가운데 12개 (달고나 가운데 자리). 서버는 이걸 안 씀 — 지워도 됨. 투명·충돌 끔")
for r in range(ROWS):
    for k in range(COLS):
        cx = -BW / 2 + (k + 0.5) * CELL_W
        box(marker, (cx, -BT - 0.1, top_z - (r + 0.5) * CELL_H), (0.15, 0.15, 0.15), PINK, bev=0, seg=1)

base = "dalgona_wall_case"
objs = finish(OUT, base, f"# {base} — tools/blender/wall_case.py (원점 = 바닥, 벽에 닿는 뒷면 가운데, 앞 = Roblox -Z). 칸 {COLS}×{ROWS} = {COLS * ROWS}")
preview(OUT, base, objs, {"preview": ((6.5, -11.0, 5.5), (0, 0, 3.6), 35)})
print(f"[{base}] done")
