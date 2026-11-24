# 임시 기본 손님 NPC (2026-11-25 사용자: "손님 NPC 개발 후순위로 보류, 임시 기본 NPC로 진행")
#   동물 손님 7종 대신 단순한 동글이 사람 하나를 색만 바꿔 7명. id·이름(뽀글이 … 퐁퐁이)은 그대로 둬서 게임 코드는 안 바뀜.
#   가볍게: 손님 1명 삼각형 약 1,500개, 부품 6개 (Head/Body/ArmL/ArmR/LegL/LegR), 팔레트 텍스처 1장 공용.
#   도형·팔레트·Char·Lua 쓰기·내보내기·미리 보기는 customers.py를 그대로 불러 씀 (그림체·리그 형식 같음).
#   나중에 진짜 손님(동물 7종)을 다시 하면 customers.py 또는 AI판(customers_ai.py)으로 CustomerRig를 다시 만든다.
#
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/basic_npc.py -- <레퍼런스/customers_basic(절대 경로)> [저장소 루트]
# 결과: <출력>/dalgona_customers_basic.glb (Customer_<id> 아래 <id>_Head …), customers_preview.png, customers_preview2.png,
#       저장소 루트를 주면 src/shared/CustomerRig.lua

import os

_here = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(_here, "customers.py"), encoding="utf-8").read()
_head = _src[:_src.index("# ───────────── 손님들 ─────────────")]
_tail = _src[_src.index("# ───────────── 재질·오브젝트 ─────────────"):]
_tail = _tail.replace('"dalgona_customers.glb"', '"dalgona_customers_basic.glb"')
_tail = _tail.replace("-- 자동 생성: tools/blender/customers.py (손으로 고치지 말 것)",
                      "-- 자동 생성: tools/blender/basic_npc.py (손으로 고치지 말 것) — 임시 기본 손님 (동물 7종은 보류)")
_tail = _tail.replace("(dalgona_customers.glb)", "(dalgona_customers_basic.glb)")
exec(compile(_head, os.path.join(_here, "customers.py"), "exec"))  # noqa: S102 (같은 저장소 스크립트)

SKIN = (250, 216, 186)
# (id, 이름, 셔츠, 바지, 머리카락, 신발)
LOOKS = [
    ("Ppogeuli", "뽀글이", (232, 120, 120), (84, 96, 140), (110, 72, 50), (80, 62, 56)),
    ("Kkuldanji", "꿀단지", (246, 196, 72), (96, 124, 160), (60, 46, 40), (88, 70, 60)),
    ("Mochi", "설기", (150, 196, 236), (240, 240, 244), (40, 36, 40), (230, 130, 150)),
    ("Godeungeo", "고등어 아저씨", (244, 244, 240), (70, 150, 86), (150, 150, 156), (90, 90, 96)),
    ("Dotori", "도토리", (90, 112, 170), (70, 76, 100), (140, 96, 60), (70, 56, 50)),
    ("Owl", "부엉이", (156, 120, 210), (70, 60, 110), (60, 44, 80), (90, 70, 110)),
    ("Pongpong", "퐁퐁이", (140, 210, 190), (246, 214, 96), (200, 140, 70), (240, 150, 70)),
]


def basic(cid, label, shirt, pants, hair, shoe):
    ch = Char(cid, label, leg=0.85, torso_h=1.05, torso_w=1.15, torso_d=0.85, hr=(0.72, 0.68, 0.68),
              arm_len=0.95, arm_r=0.19, leg_r=0.23, foot=(0.24, 0.32, 0.15))
    ch.body(SKIN, shirt, pants, shoe, sleeve=shirt, sleeve_len=0.38, head=False)
    h = ch.P("Head")
    sph(h, (0, 0, ch.hcz), ch.hr, SKIN, seg=(20, 12))
    # 머리카락: 위쪽 덮개 + 앞머리 (얼굴은 비움)
    sph(h, (0, 0.04, ch.hcz + 0.08), (0.76, 0.72, 0.68), hair, seg=(20, 10), keep=lambda q: q.z > 0.15 or q.y > 0.35)
    ch.dot_eyes(0.24, 0.02, r=(0.06, 0.04, 0.08))
    ch.blush(0.4, -0.16, r=(0.1, 0.03, 0.06))
    ch.smile(-0.26, w=0.07, tongue=False)
    ch.mouth = ch.fp(0, -0.26, 0.05)
    return ch


CHARS = [basic(*look) for look in LOOKS]
exec(compile(_tail, os.path.join(_here, "customers.py"), "exec"))  # noqa: S102
