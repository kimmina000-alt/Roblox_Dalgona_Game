# 손님 NPC 7종 — 사용자가 가져온 AI 3D 모델판 (2026-11-25)
#   1) tools/blender/ai_reduce.py 로 원본(삼각형 40만~50만, 4K 텍스처 3장)을 삼각형 5,000개 + 새 UV + 색 1024 한 장으로 구움
#      → 레퍼런스/customers_ai/<id>_low.glb
#   2) 이 스크립트가 그 7개를 손님 리그 부품 6개(Head/Body/ArmL/ArmR/LegL/LegR)로 나누고 CustomerRig.lua를 다시 만듦.
#      판매 코드(SalesService)는 그대로: 부품 가운데·관절 점만 바뀜.
#
# 나누기 = 면 가운데 높이·좌우 위치로 부품을 정함 (캐릭터마다 CUT 값). T자로 벌린 팔은 어깨 관절에서 ARM_DROP 도 아래로 내림.
# 도토리: 원본 모델 오른쪽 앞에 붙은 판 조각(팔처럼 보이는 것)은 사용자 요청으로 지움 (DELETE).
#
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/customers_ai.py -- <레퍼런스/customers_ai> [저장소 루트]
# 결과: <입력 폴더>/dalgona_customers_ai.glb (손님마다 빈 노드 Customer_<id> 아래 <id>_Head ... 메시, 손님마다 텍스처 1장),
#       customers_ai_preview.png (서 있기), customers_ai_preview2.png (걷기·먹기), 저장소 루트를 주면 src/shared/CustomerRig.lua
# 좌표 = customers.py와 같음: 원점 = 두 발 가운데 바닥, 앞 = Blender -Y, Blender (x, y, z) → Roblox (-x, z, y). 왼쪽 = +X.

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
SRC = os.path.abspath(argv[0])
REPO = os.path.abspath(argv[1]) if len(argv) > 1 else None

ORDER = ["Ppogeuli", "Kkuldanji", "Mochi", "Godeungeo", "Dotori", "Owl", "Pongpong"]
LABEL = {"Ppogeuli": "뽀글이", "Kkuldanji": "꿀단지", "Mochi": "설기", "Godeungeo": "고등어 아저씨",
         "Dotori": "도토리", "Owl": "부엉이", "Pongpong": "퐁퐁이"}
# hip = 다리 위 끝 높이, neck = 머리 아래 끝, arm = (팔 시작 |x|, 팔 띠 아래 z, 위 z), far = 이보다 바깥이면 목 높이 조금 위까지도 팔
#   (팔 윗면이 목 높이를 넘는 모델), arm_y = 팔로 칠 앞뒤 범위. 단위 stud (모델 키 = 예전 손님 키).
# 자르기 = 평면(bisect)으로 경계를 곧게 자른 뒤 부품마다 잘린 구멍을 막음(뚜껑 = 경계 한 점의 색) → 움직여도 찢긴 틈이 안 보임.
CUT = {
    "Ppogeuli": dict(hip=0.45, neck=1.88, arm=(0.78, 1.22, 1.88), far=1.08),
    "Kkuldanji": dict(hip=0.42, neck=1.42, arm=(0.62, 0.95, 1.42)),
    "Mochi": dict(hip=0.5, neck=1.88, arm=(0.7, 1.25, 1.85)),
    "Godeungeo": dict(hip=0.55, neck=2.18, arm=(0.82, 1.65, 2.18), far=0.98),
    "Dotori": dict(hip=0.55, neck=1.62, arm=(0.55, 1.15, 1.6), arm_y=(-0.7, 0.42)),  # 뒤쪽 큰 꼬리는 몸
    "Owl": dict(hip=0.28, neck=1.9, arm=(1.05, 0.85, 1.68), drop=0),  # 날개는 이미 망토 따라 내려와 있음
    "Pongpong": dict(hip=0.32, neck=1.48, arm=(0.72, 0.95, 1.45)),
}
DELETE = {"Dotori": lambda c: (c.y < -0.95 and 1.35 < c.z < 2.08 and c.x < -0.2) or (c.x < -0.6 and 1.5 < c.z < 2.1)}  # 오른쪽 판 조각 (앞으로 뻗은 부분 + 어깨 위 뿌리). 얼굴은 z 2.1 위, 진짜 오른팔은 z 1.5 아래
ARM_DROP = 55  # 도

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


class Ch:
    pass


def load(cid):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=os.path.join(SRC, cid + "_low.glb"))
    new = [o for o in bpy.data.objects if o not in before]
    src = [o for o in new if o.type == "MESH"][0]
    bm = bmesh.new()
    bm.from_mesh(src.data)
    bmesh.ops.transform(bm, matrix=src.matrix_world, verts=bm.verts)
    mat = src.data.materials[0]
    for o in new:
        bpy.data.objects.remove(o, do_unlink=True)
    return bm, mat


def build(cid, x0):
    cut = CUT[cid]
    bm, mat = load(cid)
    if cid in DELETE:
        dead = [f for f in bm.faces if DELETE[cid](f.calc_center_median())]
        bmesh.ops.delete(bm, geom=dead, context="FACES")
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    # 두 다리(발) 가운데를 원점으로 (몸이 한쪽으로 치우친 모델·긴 꼬리 보정)
    feet = [v.co for v in bm.verts if v.co.z < cut["hip"]]
    cx = (min(p.x for p in feet) + max(p.x for p in feet)) / 2
    cy = (min(p.y for p in feet) + max(p.y for p in feet)) / 2
    bmesh.ops.translate(bm, verts=bm.verts, vec=Vector((-cx, -cy, 0)))
    ax, az0, az1 = cut["arm"]
    far = cut.get("far")
    ay0, ay1 = cut.get("arm_y", (-9, 9))
    # UV 이음새로 갈라진 정점 붙이기 (UV는 면 모서리마다 남음) → 진짜 경계만 남음
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-4)
    # 부품 경계를 평면으로 곧게 자름
    planes = [((0, 0, cut["hip"]), (0, 0, 1)), ((0, 0, cut["neck"]), (0, 0, 1)), ((0, 0, az0), (0, 0, 1)), ((0, 0, az1), (0, 0, 1)),
              ((ax, 0, 0), (1, 0, 0)), ((-ax, 0, 0), (1, 0, 0))]
    if far:
        planes += [((far, 0, 0), (1, 0, 0)), ((-far, 0, 0), (1, 0, 0)), ((0, 0, az1 + 0.25), (0, 0, 1))]
    if "arm_y" in cut:
        planes += [((0, ay0, 0), (0, 1, 0)), ((0, ay1, 0), (0, 1, 0))]
    for co, no in planes:
        geom = bm.verts[:] + bm.edges[:] + bm.faces[:]
        bmesh.ops.bisect_plane(bm, geom=geom, dist=1e-5, plane_co=co, plane_no=no)
    groups = {n: [] for n in ("Head", "Body", "ArmL", "ArmR", "LegL", "LegR")}
    for f in bm.faces:
        c = f.calc_center_median()
        arm = ay0 < c.y < ay1 and (abs(c.x) > ax and az0 < c.z < az1 or far and abs(c.x) > far and az1 <= c.z < az1 + 0.25)
        if c.z < cut["hip"]:
            groups["LegL" if c.x > 0 else "LegR"].append(f)
        elif arm:
            groups["ArmL" if c.x > 0 else "ArmR"].append(f)
        elif c.z >= cut["neck"]:
            groups["Head"].append(f)
        else:
            groups["Body"].append(f)
    legs = [v.co for f in groups["LegL"] for v in f.verts]
    lx = sum(abs(p.x) for p in legs) / max(len(legs), 1)
    sz = (az0 + az1) / 2
    ch = Ch()
    ch.id, ch.label = cid, LABEL[cid]
    def shoulder(side):
        ps = [v.co for f in groups[side] for v in f.verts if abs(abs(v.co.x) - ax) < 1e-3]
        if not ps:
            return Vector((ax if side == "ArmL" else -ax, 0, sz))
        return Vector((ax if side == "ArmL" else -ax, sum(p.y for p in ps) / len(ps), sum(p.z for p in ps) / len(ps)))

    ch.joints = {
        "Head": Vector((0, 0, cut["neck"])), "Body": Vector((0, 0, cut["hip"])),
        "ArmL": shoulder("ArmL"), "ArmR": shoulder("ArmR"),
        "LegL": Vector((lx, 0, cut["hip"])), "LegR": Vector((-lx, 0, cut["hip"])),
    }
    root = bpy.data.objects.new("Customer_" + cid, None)
    scene.collection.objects.link(root)
    ch.objs, ch.boxes = {}, {}
    for n, faces in groups.items():
        sub = bmesh.new()
        uv_src = bm.loops.layers.uv.active
        uv_dst = sub.loops.layers.uv.new("UVMap")
        vmap = {}
        for f in faces:
            vs = []
            for v in f.verts:
                if v not in vmap:
                    vmap[v] = sub.verts.new(v.co)
                vs.append(vmap[v])
            try:
                nf = sub.faces.new(vs)
            except ValueError:
                continue
            for l_src, l_dst in zip(f.loops, nf.loops):
                l_dst[uv_dst].uv = l_src[uv_src].uv
        # 잘린 구멍 막기: 뚜껑 색 = 그 구멍 경계 한 점의 UV
        def on_plane(e):
            return any(all(abs((v.co - Vector(co)).dot(Vector(no))) < 2e-4 for v in e.verts) for co, no in planes)
        bnd = [e for e in sub.edges if e.is_boundary and on_plane(e)]
        if bnd:
            res = bmesh.ops.holes_fill(sub, edges=bnd, sides=0)
            for nf in res["faces"]:
                uv = None
                for v in nf.verts:
                    for l in v.link_loops:
                        if l.face is not nf and l.face not in res["faces"]:
                            uv = l[uv_dst].uv.copy()
                            break
                    if uv:
                        break
                for l in nf.loops:
                    l[uv_dst].uv = uv or (0.5, 0.5)
            bmesh.ops.recalc_face_normals(sub, faces=sub.faces[:])
        if n in ("ArmL", "ArmR"):  # T자 팔 → 어깨에서 아래로
            j = ch.joints[n]
            d = cut.get("drop", ARM_DROP)
            R = Matrix.Rotation(math.radians(d if n == "ArmL" else -d), 4, "Y")
            bmesh.ops.transform(sub, matrix=Matrix.Translation(j) @ R @ Matrix.Translation(-j), verts=sub.verts)
        lo = Vector([min(v.co[i] for v in sub.verts) for i in range(3)])
        hi = Vector([max(v.co[i] for v in sub.verts) for i in range(3)])
        c = (lo + hi) / 2
        bmesh.ops.translate(sub, verts=sub.verts, vec=-c)
        me = bpy.data.meshes.new(f"{cid}_{n}")
        sub.to_mesh(me)
        sub.free()
        for p in me.polygons:
            p.use_smooth = True
        me.materials.append(mat)
        o = bpy.data.objects.new(f"{cid}_{n}", me)
        scene.collection.objects.link(o)
        o.parent = root
        o.location = c
        ch.objs[n], ch.boxes[n] = o, (c, hi - lo)
    # 손 = 오른팔에서 어깨와 가장 먼 점, 입 = 머리 앞면 아래쪽
    jr = ch.joints["ArmR"]
    cr = ch.boxes["ArmR"][0]
    ch.hand = max((cr + v.co for v in ch.objs["ArmR"].data.vertices), key=lambda p: (p - jr).length)
    hc, hs = ch.boxes["Head"]
    hz0 = cut["neck"]
    hh = hs.z
    zs = (hz0 + hh * 0.12, hz0 + hh * 0.38)
    front = [hc + v.co for v in ch.objs["Head"].data.vertices]
    front = [p for p in front if abs(p.x) < 0.2 and zs[0] < p.z < zs[1]] or [hc + Vector((0, -hs.y / 2, 0))]
    fy = min(p.y for p in front)
    ch.mouth = Vector((0, fy - 0.05, sum(zs) / 2))
    ch.root = root
    root.location = (x0, 0, 0)
    bm.free()
    return ch


CHARS = [build(cid, (i - 3) * 3.0) for i, cid in enumerate(ORDER)]
bpy.context.view_layer.update()


def rbx(v):
    return (-v.x, v.z, v.y)


def v3(v):
    return "Vector3.new(%.3f, %.3f, %.3f)" % rbx(v)


def size3(s):
    return "Vector3.new(%.3f, %.3f, %.3f)" % (s.x, s.z, s.y)


for ch in CHARS:
    tri = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in ch.objs.values())
    print(f"# {ch.id} ({ch.label}) tris = {tri}, " + ", ".join(f"{n}={len(o.data.polygons)}" for n, o in ch.objs.items()))

if REPO:
    L = ["-- 자동 생성: tools/blender/customers_ai.py (손으로 고치지 말 것)",
         "-- 손님 NPC 7종 리그 (2026-11-25부터 사용자가 가져온 AI 모델을 부품으로 나눈 판). 좌표 = 손님 Root 기준",
         "--   (Root = 두 발 가운데 바닥, 앞 = -Z, 오른쪽 = +X), 단위 stud.",
         "-- parts[이름] = { center = 서 있을 때 부품(MeshPart) 가운데, size = 메시 크기, joint = 돌리는 관절 점 }",
         "--   부품 CFrame = root * CFrame.new(joint) * 회전 * CFrame.new(center - joint)",
         "--   Head = 목, Body = 엉덩이 가운데, ArmL/ArmR = 어깨, LegL/LegR = 엉덩이 관절.",
         "-- 메시는 Studio ServerStorage.Assets.Customers.Customer_<id> 안 <id>_<부품> (dalgona_customers_ai.glb).",
         "-- mouth = 입 앞 (먹기 연출), hand = 오른손(ArmR 끝) 가운데, height = 키.",
         "", "return {", "\torder = { " + ", ".join(f'"{c.id}"' for c in CHARS) + " },", "\ttypes = {"]
    for ch in CHARS:
        height = max(ch.boxes[n][0].z + ch.boxes[n][1].z / 2 for n in ch.boxes)
        L += [f"\t\t{ch.id} = {{", f'\t\t\tlabel = "{ch.label}",', f"\t\t\theight = {height:.3f},",
              f"\t\t\tmouth = {v3(ch.mouth)},", f"\t\t\thand = {v3(ch.hand)},", "\t\t\tparts = {"]
        for n in ("Head", "Body", "ArmL", "ArmR", "LegL", "LegR"):
            c, s = ch.boxes[n]
            L.append(f"\t\t\t\t{n} = {{ center = {v3(c)}, size = {size3(s)}, joint = {v3(ch.joints[n])} }},")
        L += ["\t\t\t},", "\t\t},"]
    L += ["\t},", "}", ""]
    with open(os.path.join(REPO, "src", "shared", "CustomerRig.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(L))

# 내보내기
for o in scene.objects:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(SRC, "dalgona_customers_ai.glb"), export_format="GLB", use_selection=True,
                          export_image_format="JPEG", export_jpeg_quality=90)

# 미리 보기
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.98, 0.94, 0.88, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
scene.world = world
bpy.ops.mesh.primitive_plane_add(size=60)
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
scene.render.resolution_x, scene.render.resolution_y = 2000, 760
scene.view_settings.view_transform = "Standard"


def shoot(loc, target, name):
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(SRC, name)
    bpy.ops.render.render(write_still=True)


def rot(x=0, y=0, z=0):
    return Matrix.Rotation(math.radians(z), 4, "Z") @ Matrix.Rotation(math.radians(y), 4, "Y") @ Matrix.Rotation(math.radians(x), 4, "X")


shoot((0, -30, 4.2), (0, 0, 1.9), "customers_ai_preview.png")
for i, ch in enumerate(CHARS):
    rots = ({"ArmR": rot(x=-110), "Head": rot(x=8)} if i % 2 == 0 else
            {"LegL": rot(x=-28), "LegR": rot(x=26), "ArmL": rot(x=24), "ArmR": rot(x=-24), "Head": rot(z=-6)})
    for n, R in rots.items():
        j = ch.joints[n]
        c, _ = ch.boxes[n]
        ch.objs[n].matrix_basis = Matrix.Translation(j) @ R @ Matrix.Translation(c - j)
shoot((15, -20, 6.0), (0, 0, 1.6), "customers_ai_preview2.png")
print("[customers_ai] done")
