# 골목 슈퍼 계산대 너구리 사장님 NPC (D54 슈퍼마켓, GDD 15장, 2026-11-25)
#   손님 7종(customers.py)과 같은 그림체·같은 리그 방식 (Humanoid 없이 부품 6개: Head/Body/ArmL/ArmR/LegL/LegR, 팔레트 텍스처 1장).
#   생김새: 회색 너구리, 눈가 검은 띠, 흰 주둥이·눈썹, 줄무늬 꼬리, 크림색 반팔 셔츠 + 짙은 초록 앞치마(흰 주머니·노란 이름표),
#   갈색 바지, 귀 뒤에 꽂은 연필. (특정 게임 캐릭터와 닮지 않게: 갈색 너구리·나뭇잎·파란 앞치마는 쓰지 않음)
#
# 도형·팔레트·Char 클래스는 customers.py 앞부분("손님들" 위까지)을 그대로 불러 씀 → 그림체가 같게 유지됨.
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/shopkeeper.py -- <출력 폴더(절대 경로)> [저장소 루트]
# 결과: <출력>/dalgona_shopkeeper.glb (빈 노드 Shopkeeper_Raccoon 아래 Raccoon_Head ... 메시 6개),
#       shopkeeper_preview.png (서 있기), shopkeeper_preview2.png (인사: 오른손 흔들기 + 고개 끄덕),
#       저장소 루트를 주면 src/shared/ShopkeeperRig.lua (자동 생성)
# 좌표 = 손님과 같음: 원점 = 두 발 가운데 바닥, 앞 = Blender -Y (Roblox -Z). Blender (x, y, z) → Roblox (-x, z, y).

import os

_here = os.path.dirname(os.path.abspath(__file__))
_src = open(os.path.join(_here, "customers.py"), encoding="utf-8").read()
_head = _src[:_src.index("# ───────────── 손님들 ─────────────")]
exec(compile(_head, os.path.join(_here, "customers.py"), "exec"))  # noqa: S102 (같은 저장소 스크립트)


def raccoon():
    ch = Char("Raccoon", "너구리 사장님", leg=0.95, torso_h=1.3, torso_w=1.36, torso_d=1.05, hr=(0.8, 0.72, 0.7),
              arm_len=1.05, arm_r=0.22, leg_r=0.27, foot=(0.27, 0.36, 0.16))
    FUR, DARK, LIGHT = (150, 146, 142), (62, 58, 60), (240, 236, 228)
    SHIRT, APRON, PANTS, SHOE = (250, 236, 204), (52, 112, 80), (118, 88, 66), (70, 52, 44)
    ch.body(FUR, SHIRT, PANTS, SHOE, sleeve=SHIRT, sleeve_len=0.42)
    h, b = ch.P("Head"), ch.P("Body")
    # 동그란 귀 (흰 테두리 안쪽 진한 색)
    for sx in (1, -1):
        sph(h, (sx * 0.5, 0.06, ch.hcz + 0.56), (0.24, 0.12, 0.24), FUR, seg=(14, 8))
        sph(h, (sx * 0.5, -0.04, ch.hcz + 0.55), (0.15, 0.05, 0.15), DARK, seg=(12, 6))
    # 눈가 검은 띠 + 흰 눈썹 + 이마 줄
    for sx in (1, -1):
        sph(h, ch.fp(sx * 0.3, 0.04, -0.03), (0.26, 0.06, 0.16), DARK, seg=(14, 8), m=rot(y=sx * -12))
        sph(h, ch.fp(sx * 0.3, 0.27, -0.025), (0.16, 0.05, 0.06), LIGHT, seg=(10, 6), m=rot(y=sx * 10))
    # 눈: 검은 띠 위라 흰 테 먼저
    for sx in (1, -1):
        c = ch.fp(sx * 0.29, 0.05, -0.02)
        sph(h, c, (0.1, 0.04, 0.11), (250, 250, 248), seg=(10, 8))
        e = ch.fp(sx * 0.29, 0.04, 0.02)
        sph(h, e, (0.06, 0.04, 0.075), (40, 30, 34), seg=(10, 8))
        sph(h, e + Vector((sx * -0.02, -0.03, 0.03)), 0.02, (255, 255, 255), seg=(6, 4))
    # 흰 주둥이 + 코 + 웃는 입 + 볼
    sph(h, ch.fp(0, -0.24, 0.08), (0.36, 0.2, 0.22), LIGHT, seg=(14, 10))
    sph(h, ch.fp(0, -0.13, 0.25), (0.08, 0.05, 0.06), (40, 32, 34), seg=(8, 6))
    ch.smile(-0.34, w=0.08)
    ch.blush(0.5, -0.18)
    # 귀 뒤 연필 (오른쪽 = Blender -X)
    p0 = Vector((-0.66, 0.1, ch.hcz + 0.32))
    p1 = Vector((-0.86, -0.42, ch.hcz + 0.12))
    cyl(h, p0, p1, 0.04, 0.04, (246, 200, 70), seg=6)
    cyl(h, p1, p1 + (p1 - p0).normalized() * 0.1, 0.04, 0.005, (230, 196, 150), seg=6)
    cyl(h, p0 - (p1 - p0).normalized() * 0.06, p0, 0.042, 0.042, (240, 140, 150), seg=6)
    # 앞치마 (가슴~무릎 위) + 목끈 + 허리끈 + 주머니 + 이름표
    w, d, th = ch.s["torso_w"], ch.s["torso_d"], ch.s["torso_h"]
    fy = -d * 0.5 - 0.03
    rbox(b, (0, fy, ch.hip + th * 0.42), (w * 0.82, 0.07, th * 1.02), APRON, 0.03)
    for sx in (1, -1):
        cyl(b, (sx * w * 0.36, fy, ch.hip + th * 0.92), (sx * 0.22, 0.0, ch.neck + 0.02), 0.035, 0.035, APRON, seg=6)
    torus(b, (0, 0, ch.hip + th * 0.38), w * 0.52, 0.035, APRON, m=Matrix.Diagonal((1, d / w, 1, 1)) @ rot(x=90), useg=24, vseg=6)
    rbox(b, (0, fy - 0.045, ch.hip + th * 0.2), (w * 0.5, 0.03, 0.3), LIGHT, 0.02)
    cyl(b, (0, fy - 0.06, ch.hip + th * 0.06), (0, fy - 0.06, ch.hip + th * 0.34), 0.012, 0.012, APRON, seg=4)
    rbox(b, (w * 0.2, fy - 0.045, ch.hip + th * 0.72), (0.26, 0.03, 0.12), (246, 206, 84), 0.015)
    # 줄무늬 꼬리 (복슬, 띠 2개씩)
    for k in range(9):
        t = k / 8
        y = d * 0.5 + 0.2 + 0.4 * math.sin(t * 1.6)
        z = ch.hip + 0.05 + 1.2 * t
        sph(b, (0.08 * math.sin(t * 3), y, z), 0.2 + 0.08 * math.sin(t * math.pi), DARK if k % 2 else FUR, seg=(10, 6))
    ch.mouth = ch.fp(0, -0.34, 0.05)
    return ch


ch = raccoon()

IMG = palette_image()
MAT = bpy.data.materials.new("ShopkeeperPalette")
MAT.use_nodes = True
nt = MAT.node_tree
bsdf = nt.nodes["Principled BSDF"]
bsdf.inputs["Roughness"].default_value = 0.85
tex = nt.nodes.new("ShaderNodeTexImage")
tex.image = IMG
tex.interpolation = "Closest"
nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
IMG.name = "ShopkeeperPalette"

root = ch.build(MAT)
root.name = "Shopkeeper_Raccoon"
bpy.context.view_layer.update()


def rbx(v):
    return (-v.x, v.z, v.y)


def v3(v):
    return "Vector3.new(%.3f, %.3f, %.3f)" % rbx(v)


def size3(s):
    return "Vector3.new(%.3f, %.3f, %.3f)" % (s.x, s.z, s.y)


tri = 0
for n, o in ch.objs.items():
    t = sum(len(p.vertices) - 2 for p in o.data.polygons)
    tri += t
    print(f"{o.name}\ttris={t}")
height = max(ch.boxes[n][0].z + ch.boxes[n][1].z / 2 for n in ch.boxes)
print(f"# Raccoon total tris = {tri}, height = {height:.2f}")

if REPO:
    hand = Vector((-ch.shx, -0.02, ch.shz - ch.s["arm_len"] + ch.s["arm_r"] * 1.1))
    L = ["-- 자동 생성: tools/blender/shopkeeper.py (손으로 고치지 말 것)",
         "-- 골목 슈퍼 계산대 너구리 사장님 NPC 리그. 손님(CustomerRig)과 같은 방식·같은 좌표:",
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
         f"\thand = {v3(hand)},",
         "\twave = { raise = 135, swing = 18, speed = 7 },",
         "\tnod = 14,",
         "\tparts = {"]
    for n in ("Head", "Body", "ArmL", "ArmR", "LegL", "LegR"):
        c, s = ch.boxes[n]
        L.append(f"\t\t{n} = {{ center = {v3(c)}, size = {size3(s)}, joint = {v3(ch.joints[n])} }},")
    L += ["\t},", "}", ""]
    with open(os.path.join(REPO, "src", "shared", "ShopkeeperRig.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L))

for o in scene.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "dalgona_shopkeeper.glb"), export_format="GLB", use_selection=True, export_apply=True, export_image_format="AUTO")

# ───────────── 미리 보기 ─────────────
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.98, 0.94, 0.88, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.85
scene.world = world
bpy.ops.mesh.primitive_plane_add(size=30, location=(0, 0, 0))
fm = bpy.data.materials.new("Floor")
fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.93, 0.84, 0.72, 1)
bpy.context.active_object.data.materials.append(fm)
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.2
sun.data.angle = math.radians(12)
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
    scene.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)


# 서 있기: 앞 + 비스듬히 뒤 (꼬리)
root.location = (-1.6, 0, 0)
dup = root.copy()
scene.collection.objects.link(dup)
kids = []
for o in root.children:
    c = o.copy()
    scene.collection.objects.link(c)
    c.parent = dup
    kids.append(c)
dup.location = (1.6, 0, 0)
dup.rotation_euler = (0, 0, math.radians(150))
shoot((0, -13, 3.2), (0, 0, 1.8), "shopkeeper_preview.png")
for o in kids + [dup]:
    bpy.data.objects.remove(o, do_unlink=True)
root.location = (0, 0, 0)
# 인사: 오른팔 들어 흔들기 + 고개 끄덕 (Blender rot(y=+각) = Roblox Angles(0,0,+각), rot(x=+각) = Roblox Angles(-각,0,0))
ch.pose({"ArmR": rot(y=135), "Head": rot(x=14)})
shoot((4.5, -9, 3.0), (0, 0, 2.0), "shopkeeper_preview2.png")
print("[shopkeeper] done")
