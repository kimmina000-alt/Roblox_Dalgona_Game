# 골목 슈퍼 너구리 사장님 — 사용자가 가져온 AI 3D 모델판 (2026-11-25)
#   원본 "raccoon character 3d model.glb"는 정면·측면·후면 3개가 한 파일 → 정면만 남김(덩어리 중 x가 가장 작은 것),
#   tools/blender/ai_reduce.py로 삼각형 5,000개 + 색 1024 한 장으로 구움 → 레퍼런스/shopkeeper/Raccoon_low.glb
#   (원본 한쪽 옆면은 색이 비어 회색이라 좌우 대칭 색으로 채움 — 그 단계는 일회성이라 저장소 밖에서 함)
#   이 스크립트가 손님과 같은 방식(customers_ai.py의 자르기·뚜껑)으로 부품 6개로 나누고 src/shared/ShopkeeperRig.lua를 만듦.
#   ShopkeeperRig 형식은 예전 shopkeeper.py와 같음 (ShopkeeperClient·AlleyBuilder 그대로).
#
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/shopkeeper_ai.py -- <레퍼런스/shopkeeper> [저장소 루트]
# 결과: <폴더>/dalgona_shopkeeper.glb (빈 노드 Shopkeeper_Raccoon 아래 Raccoon_Head ... 메시 6개),
#       shopkeeper_preview.png (서 있기), shopkeeper_preview2.png (인사: 오른손 흔들기 + 고개 끄덕)

import os

_here = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(_here, "customers_ai.py"), encoding="utf-8").read()
exec(compile(_src[:_src.index("CHARS = [")], os.path.join(_here, "customers_ai.py"), "exec"))  # noqa: S102 (같은 저장소 스크립트)

LABEL["Raccoon"] = "너구리 사장님"
# feet = 발만 있는 높이 (꼬리가 z 0.2부터 내려와서 가운데 맞출 때 뺌), leg_y = 다리로 칠 앞뒤 끝 (뒤 꼬리는 몸)
CUT["Raccoon"] = dict(hip=0.38, neck=1.98, arm=(0.8, 1.12, 1.95), far=1.0, feet=0.18, leg_y=0.3)
WAVE = {"raise": 140, "swing": 18, "speed": 7}  # 팔을 55° 내린 자세에서 140° 더 들면 머리 옆 위
NOD = 14

ch = build("Raccoon", 0.0)
ch.root.name = "Shopkeeper_Raccoon"
bpy.context.view_layer.update()


def rbx(v):
    return (-v.x, v.z, v.y)


def v3(v):
    return "Vector3.new(%.3f, %.3f, %.3f)" % rbx(v)


def size3(s):
    return "Vector3.new(%.3f, %.3f, %.3f)" % (s.x, s.z, s.y)


tri = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in ch.objs.values())
height = max(ch.boxes[n][0].z + ch.boxes[n][1].z / 2 for n in ch.boxes)
print(f"# Raccoon tris = {tri}, height = {height:.2f}, " + ", ".join(f"{n}={len(o.data.polygons)}" for n, o in ch.objs.items()))

if REPO:
    L = ["-- 자동 생성: tools/blender/shopkeeper_ai.py (손으로 고치지 말 것)",
         "-- 골목 슈퍼 계산대 너구리 사장님 NPC 리그 (2026-11-25부터 사용자가 가져온 AI 모델판). 손님(CustomerRig)과 같은 방식·같은 좌표:",
         "--   Root = 두 발 가운데 바닥, 앞 = -Z, 오른쪽 = +X, 단위 stud.",
         "--   parts[이름] = { center = 서 있을 때 부품 가운데, size = 메시 크기, joint = 돌리는 관절 점 }",
         "--   부품 CFrame = root * CFrame.new(joint) * 회전 * CFrame.new(center - joint)",
         "-- 메시는 Studio ServerStorage.Assets.Shopkeeper_Raccoon 안 Raccoon_<부품> (dalgona_shopkeeper.glb).",
         "-- 동작 (미리 보기 shopkeeper_preview2.png와 같은 값):",
         "--   인사(손 흔들기) = ArmR 회전 CFrame.Angles(0, 0, math.rad(wave.raise + math.sin(t * wave.speed) * wave.swing))",
         "--   고개 끄덕 = Head 회전 CFrame.Angles(math.rad(-nod), 0, 0)  (음수 X = 앞으로 숙임)",
         "--   서 있기 = 회전 없음 (원하면 Body를 아주 조금 위아래로 숨쉬기)",
         "", "return {",
         f'\tlabel = "{ch.label}",',
         f"\theight = {height:.3f},",
         f"\tmouth = {v3(ch.mouth)},",
         f"\thand = {v3(ch.hand)},",
         "\twave = { raise = %d, swing = %d, speed = %d }," % (WAVE["raise"], WAVE["swing"], WAVE["speed"]),
         f"\tnod = {NOD},",
         "\tparts = {"]
    for n in ("Head", "Body", "ArmL", "ArmR", "LegL", "LegR"):
        c, s = ch.boxes[n]
        L.append(f"\t\t{n} = {{ center = {v3(c)}, size = {size3(s)}, joint = {v3(ch.joints[n])} }},")
    L += ["\t},", "}", ""]
    with open(os.path.join(REPO, "src", "shared", "ShopkeeperRig.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L))

for o in scene.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(SRC, "dalgona_shopkeeper.glb"), export_format="GLB", use_selection=True,
                          export_image_format="JPEG", export_jpeg_quality=90)

# 미리 보기
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.98, 0.94, 0.88, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
scene.world = world
bpy.ops.mesh.primitive_plane_add(size=30)
fm = bpy.data.materials.new("Floor")
fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.93, 0.84, 0.72, 1)
bpy.context.active_object.data.materials.append(fm)
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-25))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.lens = 50
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 1200, 900
scene.view_settings.view_transform = "Standard"


def shoot(loc, target, name):
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(SRC, name)
    bpy.ops.render.render(write_still=True)


def pose(rots):
    for n, R in rots.items():
        j = ch.joints[n]
        c, _ = ch.boxes[n]
        ch.objs[n].matrix_basis = Matrix.Translation(j) @ R @ Matrix.Translation(c - j)


shoot((0, -12, 3.0), (0, 0, 1.8), "shopkeeper_preview.png")
# 인사: Blender rot Y(+각) = 오른팔(-X)을 바깥 위로 = Roblox Angles(0,0,+각). 고개 rot X(+각) = Roblox Angles(-각,0,0)
pose({"ArmR": Matrix.Rotation(math.radians(WAVE["raise"]), 4, "Y"), "Head": Matrix.Rotation(math.radians(NOD), 4, "X")})
shoot((4.5, -10, 3.0), (0, 0, 2.0), "shopkeeper_preview2.png")
print("[shopkeeper_ai] done")
