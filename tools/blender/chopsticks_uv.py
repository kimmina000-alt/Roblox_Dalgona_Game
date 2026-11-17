# 사용자 나무젓가락 glb(레퍼런스/dalgona_joggalack.glb)의 나뭇결 방향을 90° 돌린다.
# Roblox는 MeshPart 재질(Wood) 무늬를 메시 UV대로 입히므로, 젓가락 UV를 90° 돌리면 결이 길이 방향으로 바뀐다.
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/chopsticks_uv.py -- <입력 glb> <출력 glb>
# 모양·크기·이름은 그대로 (포장지 조각은 손대지 않음).

import math
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, DST = argv[0], argv[1]
STICKS = {"나무젓가락1", "나무젓가락1-2", "나무젓가락2", "나무젓가락2-2"}

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
for o in bpy.context.scene.objects:
    if o.type != "MESH" or o.name not in STICKS:
        continue
    uv = o.data.uv_layers.active
    us = [d.uv.copy() for d in uv.data]
    cu = (min(u.x for u in us) + max(u.x for u in us)) / 2
    cv = (min(u.y for u in us) + max(u.y for u in us)) / 2
    for d in uv.data:  # 가운데를 기준으로 90° 회전
        x, y = d.uv.x - cu, d.uv.y - cv
        d.uv = (cu - y, cv + x)
    print("[chopsticks_uv] rotated", o.name)
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB")
print("[chopsticks_uv] done", DST)
