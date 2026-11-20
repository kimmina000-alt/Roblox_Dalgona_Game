# 달고나 반죽 3D 메시 (사용자가 보낸 유튜브 쇼츠 2편을 프레임별로 보고 만든 것, docs/DALGONA_LOOK.md "영상 분석")
#   DalgonaMound : 국자에서 미끄러져 나온 걸쭉한 반죽이 리본처럼 접히며 쌓인 언덕 (주름·접힘)
#   DalgonaPuff  : 언덕이 퍼져 굳은 도톰한 원판. 가장자리가 둥글게 부풀고 윗면에 크고 작은 기포 구멍
#   DalgonaFlat  : 누름판으로 3번 눌러 얇아진 원판. 가장자리가 살짝 울퉁불퉁, 고운 구멍 자국
#   PourRibbon   : 국자에서 흘러나오는 굵은 반죽 리본 (위는 넓고 아래로 좁아지며 접힘). 길이 1 (Y 방향, 위 = +Y)
# + 나무젓가락 4개를 길이가 X축이 되게 눕힘 (Roblox 나무 결은 부품 X축을 따라감)
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/dalgona_mesh.py -- <출력 폴더> <젓가락 glb>
# 결과: <출력>/dalgona_batter.glb, dalgona_batter_preview.png
# 크기: 원판·언덕은 지름 2(반지름 1), 바닥 가운데 원점. Roblox에서 Size로 맞춘다.

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector, noise

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "."
STICK_GLB = argv[1] if len(argv) > 1 else None
random.seed(11)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def mat(name, rgb, rough=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    return m


BATTER = mat("Batter", (0.72, 0.36, 0.08), 0.45)


def to_mesh(obj, name):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    m = bpy.context.active_object
    m.name = name
    m.data.name = name
    return m


def finish(o, smooth=True):
    for p in o.data.polygons:
        p.use_smooth = smooth
    o.data.materials.clear()
    o.data.materials.append(BATTER)
    # 원점 = 바닥 가운데
    vs = [o.matrix_world @ v.co for v in o.data.vertices]
    minz = min(v.z for v in vs)
    cx = (min(v.x for v in vs) + max(v.x for v in vs)) / 2
    cy = (min(v.y for v in vs) + max(v.y for v in vs)) / 2
    for v in o.data.vertices:
        v.co -= Vector((cx, cy, minz))
    o.location = (0, 0, 0)
    return o


# ---------------------------------------------------------------- 1) 접히며 쌓인 언덕 (메타볼 리본)
def mound():
    mb = bpy.data.metaballs.new("MoundMB")
    mb.resolution = 0.05
    mb.render_resolution = 0.05
    obj = bpy.data.objects.new("MoundMB", mb)
    scene.collection.objects.link(obj)
    # 반죽 리본이 아래에서 위로 똬리 틀듯 접혀 쌓임: 나선 경로 위에 공을 촘촘히 (위로 갈수록 작아지고 중심 쪽)
    turns = 2.6
    n = 70
    for i in range(n):
        t = i / (n - 1)
        a = t * turns * 2 * math.pi + random.uniform(-0.15, 0.15)
        r = 0.62 * (1 - t) ** 0.8 + 0.08
        z = 0.12 + 0.55 * t ** 0.9
        e = mb.elements.new()
        e.co = (math.cos(a) * r + random.uniform(-0.04, 0.04), math.sin(a) * r * 0.9, z)
        e.radius = 0.36 * (1 - 0.45 * t) + random.uniform(-0.03, 0.03)
        e.stiffness = 2.0
    # 바닥 퍼짐 (철판에 닿아 넓게)
    for k in range(10):
        a = 2 * math.pi * k / 10
        e = mb.elements.new()
        e.co = (math.cos(a) * 0.62, math.sin(a) * 0.6, 0.05)
        e.radius = 0.32
        e.stiffness = 2.0
    o = to_mesh(obj, "DalgonaMound")
    # 주름: 위쪽 표면을 살짝 물결치게
    for v in o.data.vertices:
        n3 = noise.noise(v.co * 6.0)
        v.co += v.normal * n3 * 0.025 if hasattr(v, "normal") else Vector()
    o.scale = (1.0, 1.0, 1.0)
    return finish(o)


# ---------------------------------------------------------------- 2) 굳은 도톰한 원판 (둥근 가장자리 + 기포 구멍)
def puff():
    bm = bmesh.new()
    seg, rings = 128, 40  # Roblox 메시 한도(삼각형 2만) 안에서 구멍이 둥글게 보이게
    H = 0.32
    verts = []
    for i in range(rings + 1):
        t = i / rings  # 0 = 가운데, 1 = 가장자리 끝
        row = []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            # 가장자리가 살짝 울퉁불퉁한 원
            rr = 1 + 0.035 * math.sin(a * 5 + 1) + 0.02 * math.sin(a * 11)
            if t < 0.8:
                r = t / 0.8 * 0.86 * rr
                z = H * (0.92 + 0.08 * (1 - (t / 0.8) ** 2))
            else:
                # 둥글게 말려 내려가는 가장자리
                u = (t - 0.8) / 0.2
                ang = u * math.pi / 2
                r = (0.86 + 0.14 * math.sin(ang)) * rr
                z = H * 0.92 * math.cos(ang) + 0.02
            row.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)))
        verts.append(row)
    for i in range(rings):
        for k in range(seg):
            k2 = (k + 1) % seg
            bm.faces.new((verts[i][k], verts[i][k2], verts[i + 1][k2], verts[i + 1][k]))
    bot = bm.verts.new((0, 0, 0))
    for k in range(seg):
        bm.faces.new((verts[rings][(k + 1) % seg], verts[rings][k], bot))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # 기포 구멍: 윗면을 동그랗게 눌러 팜 (크고 작은 구멍 30개)
    craters = []
    for _ in range(30):
        a = random.uniform(0, 2 * math.pi)
        r = math.sqrt(random.random()) * 0.8
        craters.append((Vector((math.cos(a) * r, math.sin(a) * r)), random.choice([0.035, 0.05, 0.07, 0.1, 0.13]), random.uniform(0.4, 0.8)))
    for v in bm.verts:
        if v.co.z < H * 0.5:
            continue
        p = Vector((v.co.x, v.co.y))
        for (c, rad, depth) in craters:
            d = (p - c).length
            if d < rad * 1.25:
                if d < rad:
                    v.co.z -= depth * rad * (1 - (d / rad) ** 2)
                else:
                    v.co.z += 0.15 * rad * (1 - (d - rad) / (0.25 * rad))  # 구멍 둘레 살짝 솟음
        # 잔잔한 울퉁불퉁
        v.co.z += noise.noise(Vector((v.co.x * 5, v.co.y * 5, 0.3))) * 0.012
    me = bpy.data.meshes.new("DalgonaPuff")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("DalgonaPuff", me)
    scene.collection.objects.link(o)
    return finish(o)


# ---------------------------------------------------------------- 3) 눌린 얇은 원판 (고운 구멍 자국)
def flat():
    bm = bmesh.new()
    seg, rings = 96, 20
    H = 0.06
    verts = []
    for i in range(rings + 1):
        t = i / rings
        row = []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            rr = 1 + 0.025 * math.sin(a * 7 + 2) + 0.015 * math.sin(a * 13)
            if t < 0.9:
                r = t / 0.9 * 0.97 * rr
                z = H
            else:
                u = (t - 0.9) / 0.1
                r = (0.97 + 0.03 * math.sin(u * math.pi / 2)) * rr
                z = H * math.cos(u * math.pi / 2) + 0.004
            row.append(bm.verts.new((math.cos(a) * r, math.sin(a) * r, z)))
        verts.append(row)
    for i in range(rings):
        for k in range(seg):
            k2 = (k + 1) % seg
            bm.faces.new((verts[i][k], verts[i][k2], verts[i + 1][k2], verts[i + 1][k]))
    bot = bm.verts.new((0, 0, 0))
    for k in range(seg):
        bm.faces.new((verts[rings][(k + 1) % seg], verts[rings][k], bot))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    pores = []
    for _ in range(70):
        a = random.uniform(0, 2 * math.pi)
        r = math.sqrt(random.random()) * 0.9
        pores.append((Vector((math.cos(a) * r, math.sin(a) * r)), random.uniform(0.015, 0.04)))
    for v in bm.verts:
        if v.co.z < H * 0.6:
            continue
        p = Vector((v.co.x, v.co.y))
        for (c, rad) in pores:
            d = (p - c).length
            if d < rad:
                v.co.z -= 0.02 * (1 - (d / rad) ** 2)
        v.co.z += noise.noise(Vector((v.co.x * 9, v.co.y * 9, 0.7))) * 0.004
    me = bpy.data.meshes.new("DalgonaFlat")
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new("DalgonaFlat", me)
    scene.collection.objects.link(o)
    return finish(o)


# ---------------------------------------------------------------- 4) 흘러내리는 굵은 리본
def ribbon():
    mb = bpy.data.metaballs.new("RibbonMB")
    mb.resolution = 0.03
    mb.render_resolution = 0.03
    obj = bpy.data.objects.new("RibbonMB", mb)
    scene.collection.objects.link(obj)
    n = 40
    for i in range(n):
        t = i / (n - 1)  # 0 = 아래 끝, 1 = 국자 쪽
        e = mb.elements.new()
        # 아래로 갈수록 좁아지고, 살짝 S자로 접힘
        e.co = (0.06 * math.sin(t * 7.0), 0.04 * math.sin(t * 4.0 + 1), t)
        e.radius = 0.09 + 0.1 * t ** 0.8
        e.type = "ELLIPSOID"
        e.size_x = 1.6  # 리본처럼 납작하고 넓게
        e.size_y = 0.8
        e.size_z = 1.0
        e.stiffness = 2.0
    o = to_mesh(obj, "PourRibbon")
    for p in o.data.polygons:
        p.use_smooth = True
    o.data.materials.clear()
    o.data.materials.append(BATTER)
    # 원점 = 위 끝 가운데가 아니라 경계 상자 가운데 (Roblox와 같게), 높이는 1로 맞춤
    vs = [v.co for v in o.data.vertices]
    minz, maxz = min(v.z for v in vs), max(v.z for v in vs)
    cx = (min(v.x for v in vs) + max(v.x for v in vs)) / 2
    cy = (min(v.y for v in vs) + max(v.y for v in vs)) / 2
    s = 1 / (maxz - minz)
    for v in o.data.vertices:
        v.co = Vector(((v.co.x - cx) * s, (v.co.y - cy) * s, (v.co.z - (minz + maxz) / 2) * s))
    return o


m = mound()
p = puff()
f = flat()
r = ribbon()
made = [m, p, f, r]

# 나무젓가락: 길이(Blender Z) → X 로 눕힘 (Y축으로 90° 회전)
if STICK_GLB and os.path.exists(STICK_GLB):
    bpy.ops.import_scene.gltf(filepath=STICK_GLB)
    rename = {"나무젓가락1": "Stick1A", "나무젓가락1-2": "Stick1B", "나무젓가락2": "Stick2A", "나무젓가락2-2": "Stick2B"}
    for o in list(scene.objects):
        if o.type == "MESH" and o.name in rename:
            o.name = rename[o.name]
            o.data.name = o.name
            mw = o.matrix_world.copy()
            o.parent = None
            o.data = o.data.copy()  # 다른 조각과 메시를 같이 쓰면 두 번 돌아감
            o.data.transform(Matrix.Rotation(math.radians(90), 4, "Y") @ mw.to_3x3().to_4x4())
            o.matrix_world = Matrix.Translation(mw.translation)
            made.append(o)
        elif o.type == "MESH" and o not in made:
            bpy.data.objects.remove(o)
        elif o.type != "MESH":
            bpy.data.objects.remove(o)

bpy.context.view_layer.update()
for o in made:
    ws = [o.matrix_world @ v.co for v in o.data.vertices]
    d = Vector((max(v.x for v in ws) - min(v.x for v in ws), max(v.y for v in ws) - min(v.y for v in ws), max(v.z for v in ws) - min(v.z for v in ws)))
    print(f"[batter] {o.name} tris={sum(len(pp.vertices) - 2 for pp in o.data.polygons)} size=({d.x:.3f}, {d.y:.3f}, {d.z:.3f})")

bpy.ops.object.select_all(action="DESELECT")
for o in made:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "dalgona_batter.glb"), export_format="GLB", use_selection=True, export_apply=True)

# 미리 보기 (반죽만)
for o in made:
    o.hide_render = o.name.startswith("Stick")
m.location = (-2.4, 0, 0)
p.location = (0, 0, 0)
f.location = (2.4, 0, 0)
r.location = (4.3, 0, 0.5)
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.56, 0.6, 1)
scene.world = world
bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, -0.001))
bpy.context.active_object.data.materials.append(mat("Paper", (0.6, 0.48, 0.36), 0.8))
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.5
sun.rotation_euler = (math.radians(50), math.radians(-10), math.radians(30))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.lens = 30
cam.location = (1.0, -6.5, 4.2)
cam.rotation_euler = (Vector((1.0, 0, 0.3)) - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 1500, 700
scene.view_settings.view_transform = "Standard"
scene.render.filepath = os.path.join(OUT, "dalgona_batter_preview.png")
bpy.ops.render.render(write_still=True)
print("[batter] done")
