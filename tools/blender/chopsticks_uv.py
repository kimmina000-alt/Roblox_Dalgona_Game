# 사용자 나무젓가락 glb(레퍼런스/dalgona_joggalack.glb)의 나뭇결이 젓가락 길이를 따라가게 UV를 다시 만든다.
# Roblox는 MeshPart 재질(Wood) 무늬를 메시 UV대로 입히고, 나뭇결은 텍스처 U 방향으로 그려진다
# (Studio EditableMesh로 확인: 길이 방향이 V일 때 결이 가로로 보임).
# 그래서 젓가락 길이(Blender Z) → U, 둘레 → V 로 투영한다. 둘레 쪽은 길이와 같은 비율(1 stud당 같은 UV 양).
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/chopsticks_uv.py -- <입력 glb> <출력 glb>
# 모양·크기·이름은 그대로 (포장지 조각은 손대지 않음).

import math
import sys

import bpy

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, DST = argv[0], argv[1]
STICKS = {"나무젓가락1", "나무젓가락1-2", "나무젓가락2", "나무젓가락2-2"}
U_PER_STUD = 0.35  # 결 길이 (작을수록 결이 길게 늘어남)

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
for o in bpy.context.scene.objects:
    if o.type != "MESH" or o.name not in STICKS:
        continue
    me = o.data
    zs = [v.co.z for v in me.vertices]
    zmin = min(zs)
    cx = sum(v.co.x for v in me.vertices) / len(me.vertices)
    cy = sum(v.co.y for v in me.vertices) / len(me.vertices)
    uv = me.uv_layers.active
    for poly in me.polygons:
        # 면마다 둘레 위치: 면 가운데의 각도 → 둘레 길이로 (이음매가 면 경계에만 생김)
        mid = poly.center
        a0 = math.atan2(mid.y - cy, mid.x - cx)
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            a = math.atan2(co.y - cy, co.x - cx)
            if a - a0 > math.pi:
                a -= 2 * math.pi
            elif a0 - a > math.pi:
                a += 2 * math.pi
            r = math.hypot(co.x - cx, co.y - cy)
            uv.data[li].uv = ((co.z - zmin) * U_PER_STUD, (a * max(r, 0.02) + 0.5) * U_PER_STUD)
    print("[chopsticks_uv] grain along length:", o.name)
bpy.ops.export_scene.gltf(filepath=DST, export_format="GLB")
print("[chopsticks_uv] done", DST)
