# 손님 NPC "곰돌" (2026-11-27 사용자 레퍼런스/npc/곰돌.glb)
#   사용자가 Tripo 원본을 리토폴로지해서 6조각(머리·몸·팔2·다리2)으로 나눈 모델. 리토폴로지에서 UV가 빠져서
#   원본(Tripo glb, 삼각형 약 39만 + 4K 색)의 색을 새 UV(1024 한 장)에 구워 넣고, 지금 손님 리그(Shared.CustomerRig:
#   부품 6개를 관절 점 기준으로 돌림, SalesService 걷기·먹기)에 맞는 부품 Gomdol_<부품>으로 내보냄.
#
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/gomdol.py -- <곰돌.glb> <Tripo 원본.glb> <출력 폴더> [저장소 루트]
# 결과: <출력 폴더>/dalgona_gomdol.glb (빈 노드 Customer_Gomdol 아래 Gomdol_Head ... 메시, 텍스처 1장),
#       gomdol_preview.png (서 있기 / 걷기 / 먹기), 저장소 루트를 주면 src/shared/CustomerRig.lua 안 Gomdol 칸을 다시 씀
# 좌표 = customers_ai.py와 같음: 원점 = 두 발 가운데 바닥, 앞 = Blender -Y, Blender (x, y, z) → Roblox (-x, z, y). 왼쪽 = +X.

import math
import os
import re
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:]
LOW, HIGH, OUT = (os.path.abspath(a) for a in argv[:3])
REPO = os.path.abspath(argv[3]) if len(argv) > 3 else None
os.makedirs(OUT, exist_ok=True)

CID, LABEL = "Kkuldanji", "꿀단지"  # 2026-11-28 사용자: 곰돌 = 꿀단지 (메시 이름 Kkuldanji_<부품>)
HEIGHT = 3.8  # stud (다른 손님 3.0 ~ 4.1)
TEX = 1024
ARM_DROP = 40  # 옆으로 뻗은 팔을 어깨에서 내리는 각도 (도). 내려야 걷기·먹기(X축 회전)에서 팔이 앞뒤로 흔들림
# 2026-11-28 사용자: 58°면 둥근 배 속으로 팔이 들어감 → 40°로 덜 내리고 어깨를 바깥으로 ARM_OUT(stud)만큼 빼서 A자처럼
ARM_OUT = 0.22

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def imported(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def bbox(objs):
    pts = [o.matrix_world @ Vector(c) for o in objs for c in o.bound_box]
    return Vector([min(p[i] for p in pts) for i in range(3)]), Vector([max(p[i] for p in pts) for i in range(3)])


# 1) 원본(색) + 리토폴로지 조각
high = [o for o in imported(HIGH) if o.type == "MESH"][0]
low = [o for o in imported(LOW) if o.type == "MESH"]
for o in low:  # 조각마다 변환을 메시에 적용
    o.data.transform(o.matrix_world)
    o.matrix_world = Matrix()
lo, hi = bbox(low)
hlo, hhi = bbox([high])
# 리토폴로지는 원본을 옆으로 옮겨 둔 것: 가로·앞뒤 가운데를 원본에 맞춤 (높이는 둘 다 바닥 0)
shift = Vector((((hlo + hhi) / 2).x - ((lo + hi) / 2).x, ((hlo + hhi) / 2).y - ((lo + hi) / 2).y, 0))
for o in low:
    o.data.transform(Matrix.Translation(shift))
print("[gomdol] shift", tuple(round(v, 4) for v in shift))

# 2) 조각 이름: 가장 높은 = 머리, 아래 두 개 = 다리, 가운데 가장 큰 = 몸, 나머지 두 개 = 팔 (x > 0 = 왼쪽)
def center(o):
    a, b = bbox([o])
    return (a + b) / 2, b - a


info = sorted(low, key=lambda o: bbox([o])[1].z)
legs = sorted(info[:2], key=lambda o: center(o)[0].x)
rest = info[2:]
head = max(rest, key=lambda o: bbox([o])[1].z)
rest.remove(head)
body = max(rest, key=lambda o: center(o)[1].length)
rest.remove(body)
arms = sorted(rest, key=lambda o: center(o)[0].x)
parts = {"Head": head, "Body": body, "ArmR": arms[0], "ArmL": arms[1], "LegR": legs[0], "LegL": legs[1]}
for n, o in parts.items():
    o.name = f"{CID}_{n}"
    c, s = center(o)
    print("[gomdol]", n, "center", tuple(round(v, 3) for v in c), "size", tuple(round(v, 3) for v in s))

# 잘린 구멍 막기 (팔·다리가 돌 때 몸 안이 비어 보이지 않게)
for o in parts.values():
    bm = bmesh.new()
    bm.from_mesh(o.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    cap = bm.faces.layers.int.new("cap")
    bnd = [e for e in bm.edges if e.is_boundary]
    if bnd:
        res = bmesh.ops.holes_fill(bm, edges=bnd, sides=0)
        for f in res["faces"]:
            f[cap] = 1
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(o.data)
    bm.free()
    for p in o.data.polygons:
        p.use_smooth = True

# 3) 하나로 합쳐 UV 한 장 → 원본 색 굽기 → 다시 나눔 (면 속성 part)
order = list(parts.keys())
for i, n in enumerate(order):
    o = parts[n]
    a = o.data.attributes.new("part", "INT", "FACE")
    for p in o.data.polygons:
        a.data[p.index].value = i
bpy.ops.object.select_all(action="DESELECT")
for o in parts.values():
    o.select_set(True)
bpy.context.view_layer.objects.active = parts["Body"]
bpy.ops.object.join()
joined = bpy.context.view_layer.objects.active
joined.name = "GomdolJoined"
joined.data.uv_layers.new(name="UVMap")
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.01)
bpy.ops.object.mode_set(mode="OBJECT")

img = bpy.data.images.new("Gomdol_Color", TEX, TEX)
mat = bpy.data.materials.new("Gomdol")
mat.use_nodes = True
nt = mat.node_tree
tex = nt.nodes.new("ShaderNodeTexImage")
tex.image = img
nt.links.new(tex.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
nt.nodes.active = tex
joined.data.materials.clear()
joined.data.materials.append(mat)

scene.render.engine = "CYCLES"
scene.cycles.samples = 4
scene.cycles.device = "CPU"
scene.render.bake.use_selected_to_active = True
scene.render.bake.cage_extrusion = 0.02
scene.render.bake.max_ray_distance = 0.08
scene.render.bake.margin = 6
bpy.ops.object.select_all(action="DESELECT")
high.select_set(True)
joined.select_set(True)
bpy.context.view_layer.objects.active = joined
bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"})
img.filepath_raw = os.path.join(OUT, "gomdol_color.png")
img.file_format = "PNG"
img.save()
img.pack()
bpy.data.objects.remove(high, do_unlink=True)

# 4) 크기(키 HEIGHT) · 원점(두 발 가운데 바닥) 맞추고 부품별로 나눔
lo, hi = bbox([joined])
s = HEIGHT / (hi.z - lo.z)
joined.data.transform(Matrix.Scale(s, 4))
src = bmesh.new()
src.from_mesh(joined.data)
pl = src.faces.layers.int["part"]
cl = src.faces.layers.int.get("cap")
leg_ix = (order.index("LegL"), order.index("LegR"))
feet = [v.co for f in src.faces if f[pl] in leg_ix for v in f.verts]
fx = (min(p.x for p in feet) + max(p.x for p in feet)) / 2
fy = (min(p.y for p in feet) + max(p.y for p in feet)) / 2
fz = min(v.co.z for v in src.verts)
bmesh.ops.translate(src, verts=src.verts, vec=Vector((-fx, -fy, -fz)))
uvl = src.loops.layers.uv.active
# 어깨·엉덩이처럼 원본에서는 팔·다리 속이던 자리는 굽기에서 검게 나옴 → 머리(눈·입은 진짜 검정) 말고는
# 검게 구워진 면의 UV를 맞닿은 밝은 면의 UV 한 점으로 바꿈 (안쪽으로 번져 가며)
px = list(img.pixels)


def lum(uv):
    x = min(TEX - 1, max(0, int(uv.x * TEX)))
    y = min(TEX - 1, max(0, int(uv.y * TEX)))
    i = (y * TEX + x) * 4
    return 0.3 * px[i] + 0.59 * px[i + 1] + 0.11 * px[i + 2]


head_ix = order.index("Head")
dark = set()
for f in src.faces:
    if f[pl] == head_ix:
        continue
    c = sum((l[uvl].uv for l in f.loops), Vector((0, 0))) / len(f.loops)
    if lum(c) < 0.3 or min(lum(l[uvl].uv.lerp(c, 0.3)) for l in f.loops) < 0.3:
        dark.add(f)
print("[gomdol] dark faces", len(dark))
while dark:
    fixed = []
    for f in dark:
        for e in f.edges:
            for g in e.link_faces:
                if g is not f and g not in dark and g[pl] == f[pl]:
                    uv = g.loops[0][uvl].uv.copy()
                    for l in f.loops:
                        l[uvl].uv = uv
                    fixed.append(f)
                    break
            if fixed and fixed[-1] is f:
                break
    if not fixed:
        break
    for f in fixed:
        dark.discard(f)

root = bpy.data.objects.new("Customer_" + CID, None)
scene.collection.objects.link(root)
objs, boxes, verts = {}, {}, {}
for i, n in enumerate(order):
    sub = bmesh.new()
    uv2 = sub.loops.layers.uv.new("UVMap")
    vmap = {}
    for f in src.faces:
        if f[pl] != i:
            continue
        vs = []
        for v in f.verts:
            if v not in vmap:
                vmap[v] = sub.verts.new(v.co)
            vs.append(vmap[v])
        try:
            nf = sub.faces.new(vs)
        except ValueError:
            continue
        for a, b in zip(f.loops, nf.loops):
            b[uv2].uv = a[uvl].uv
    verts[n] = [v.co.copy() for v in sub.verts]
    objs[n] = sub
src.free()
bpy.data.objects.remove(joined, do_unlink=True)

# 관절 점: 머리 = 머리 아래 끝(목), 몸 = 다리 위 끝 높이(엉덩이), 팔 = 몸 쪽 끝 위쪽(어깨), 다리 = 위 끝 가운데
def lohi(ps):
    return Vector([min(p[i] for p in ps) for i in range(3)]), Vector([max(p[i] for p in ps) for i in range(3)])


hlo_, hhi_ = lohi(verts["Head"])
legtop = max(lohi(verts["LegL"])[1].z, lohi(verts["LegR"])[1].z)
joints = {"Head": Vector((0, 0, hlo_.z + (hhi_.z - hlo_.z) * 0.08)), "Body": Vector((0, 0, legtop * 0.85))}
for n in ("LegL", "LegR"):
    a, b = lohi(verts[n])
    top = [p for p in verts[n] if p.z > b.z - (b.z - a.z) * 0.15]
    joints[n] = Vector((sum(p.x for p in top) / len(top), sum(p.y for p in top) / len(top), b.z - (b.z - a.z) * 0.12))
# 어깨 = 몸 가운데에서 양쪽 같은 거리(두 팔 안쪽 끝 중 바깥 쪽), 팔 위쪽. 사용자 모델은 오른팔 조각이 몸 속까지 잘려 있어서
# 안쪽 끝을 그대로 쓰면 내린 오른팔이 몸에 묻힘
bc = sum(lohi(verts["Body"]), Vector()) / 2
aL, bL = lohi(verts["ArmL"])
aR, bR = lohi(verts["ArmR"])
sx = max(aL.x - bc.x, bc.x - bR.x)
for n, (a, b), side in (("ArmL", (aL, bL), 1), ("ArmR", (aR, bR), -1)):
    joints[n] = Vector((bc.x + side * (sx + ARM_OUT), (a.y + b.y) / 2, (a.z + b.z) / 2 + (b.z - a.z) * 0.25))

for n, sub in objs.items():
    if n in ("ArmL", "ArmR") and ARM_OUT:
        bmesh.ops.translate(sub, verts=sub.verts, vec=Vector(((1 if n == "ArmL" else -1) * ARM_OUT, 0, 0)))
    if n in ("ArmL", "ArmR") and ARM_DROP:
        j = joints[n]
        R = Matrix.Rotation(math.radians(ARM_DROP if n == "ArmL" else -ARM_DROP), 4, "Y")
        bmesh.ops.transform(sub, matrix=Matrix.Translation(j) @ R @ Matrix.Translation(-j), verts=sub.verts)
    a, b = lohi([v.co for v in sub.verts])
    c = (a + b) / 2
    bmesh.ops.translate(sub, verts=sub.verts, vec=-c)
    me = bpy.data.meshes.new(f"{CID}_{n}")
    sub.to_mesh(me)
    sub.free()
    for p in me.polygons:
        p.use_smooth = True
    me.materials.append(mat)
    o = bpy.data.objects.new(f"{CID}_{n}", me)
    scene.collection.objects.link(o)
    o.parent = root
    o.location = c
    objs[n], boxes[n] = o, (c, b - a)

# 손 = 오른팔에서 어깨와 가장 먼 점, 입 = 머리 앞면 아래쪽 1/3
jr = joints["ArmR"]
cr = boxes["ArmR"][0]
hand = max((cr + v.co for v in objs["ArmR"].data.vertices), key=lambda p: (p - jr).length)
hc, hs = boxes["Head"]
zs = (hc.z - hs.z * 0.35, hc.z - hs.z * 0.1)
front = [hc + v.co for v in objs["Head"].data.vertices]
front = [p for p in front if abs(p.x) < hs.x * 0.15 and zs[0] < p.z < zs[1]] or [hc + Vector((0, -hs.y / 2, 0))]
mouth = Vector((0, min(p.y for p in front) - 0.05, sum(zs) / 2))
tris = sum(len(o.data.polygons) for o in objs.values())
print(f"[gomdol] tris {tris}, joints", {n: tuple(round(v, 3) for v in j) for n, j in joints.items()})


def rbx(v):
    return (-v.x, v.z, v.y)


def v3(v):
    return "Vector3.new(%.3f, %.3f, %.3f)" % rbx(v)


def size3(sz):
    return "Vector3.new(%.3f, %.3f, %.3f)" % (sz.x, sz.z, sz.y)


if REPO:
    path = os.path.join(REPO, "src", "shared", "CustomerRig.lua")
    with open(path, encoding="utf-8") as f:
        text = f.read()
    height = max(boxes[n][0].z + boxes[n][1].z / 2 for n in boxes)
    L = [f"\t\t{CID} = {{ -- tools/blender/gomdol.py (레퍼런스/npc/곰돌.glb, 2026-11-27)", f'\t\t\tlabel = "{LABEL}",', f"\t\t\theight = {height:.3f},",
         f"\t\t\tmouth = {v3(mouth)},", f"\t\t\thand = {v3(hand)},", "\t\t\tparts = {"]
    for n in ("Head", "Body", "ArmL", "ArmR", "LegL", "LegR"):
        c, sz = boxes[n]
        L.append(f"\t\t\t\t{n} = {{ center = {v3(c)}, size = {size3(sz)}, joint = {v3(joints[n])} }},")
    L += ["\t\t\t},", "\t\t},"]
    block = "\n".join(L) + "\n"
    text = re.sub(r"\t\t" + CID + r" = \{.*?\n\t\t\},\n", "", text, flags=re.S)  # 예전 칸 지움
    text = text.replace("\t},\n}", block + "\t},\n}", 1)
    if f'"{CID}"' not in text.split("types")[0]:
        text = re.sub(r'(order = \{[^}]*?)( \},)', lambda m: m.group(1) + f', "{CID}"' + m.group(2), text, count=1)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("[gomdol] wrote", path)

# 내보내기
bpy.ops.object.select_all(action="DESELECT")
root.select_set(True)
for o in objs.values():
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "dalgona_gomdol.glb"), export_format="GLB", use_selection=True,
                          export_image_format="JPEG", export_jpeg_quality=90)

# 미리 보기: 서 있기 · 걷기 · 먹기 (관절 점 기준 회전이 리그와 같은지 확인)
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.98, 0.94, 0.88, 1)
scene.world = world
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(-25))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.lens = 50
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 1500, 700
scene.view_settings.view_transform = "Standard"


def rot(x=0, y=0, z=0):
    return Matrix.Rotation(math.radians(z), 4, "Z") @ Matrix.Rotation(math.radians(y), 4, "Y") @ Matrix.Rotation(math.radians(x), 4, "X")


copies = []
for k, pose in enumerate([{}, {"LegL": rot(x=-28), "LegR": rot(x=26), "ArmL": rot(x=24), "ArmR": rot(x=-24)}, {"ArmR": rot(x=-110), "Head": rot(x=8)}]):
    r2 = root.copy() if k else root
    if k:
        scene.collection.objects.link(r2)
    r2.location = ((k - 1) * 3.2, 0, 0)
    for n, o in objs.items():
        o2 = o.copy() if k else o
        if k:
            scene.collection.objects.link(o2)
            o2.parent = r2
        j = joints[n]
        c, _ = boxes[n]
        o2.matrix_basis = Matrix.Translation(j) @ pose.get(n, Matrix()) @ Matrix.Translation(c - j)
cam.location = (0, -15, 3.0)
cam.rotation_euler = (Vector((0, 0, 1.8)) - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.render.filepath = os.path.join(OUT, "gomdol_preview.png")
bpy.ops.render.render(write_still=True)
print("[gomdol] done")
