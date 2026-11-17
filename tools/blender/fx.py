# 제작 효과용 3D 메시: 설탕 결정, 설탕 더미(결정 수백 개), 소다 가루 더미, 부푼 달고나 거품
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/fx.py -- <출력 폴더>
# 결과: <출력>/dalgona_fx.glb → Studio에서 가져와 ReplicatedStorage.Assets.Fx 폴더에 (클라이언트가 씀), fx_preview.png
# 모든 메시는 바닥 가운데가 원점, 지름 2(반지름 1) 기준이라 Roblox에서 Size로 크기를 맞춘다 (결정만 한 변 1).

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "."
random.seed(7)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def mat(name, rgb, rough=0.6, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Roughness"].default_value = rough
    return m


def finish(name, bm, material, smooth):
    bm.normal_update()
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = smooth
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    o.data.materials.append(material)
    return o


def add_cube(bm, center, size, rot, squash=1.0):
    m = Matrix.Translation(center) @ rot.to_matrix().to_4x4() @ Matrix.Diagonal((size, size, size * squash, 1))
    bmesh.ops.create_cube(bm, size=1.0, matrix=m)


def add_ico(bm, center, r, subdiv=1):
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=r, matrix=Matrix.Translation(center))


def lathe_dome(bm, height, seg=40, rings=10, noise=0.0):
    """반지름 1 돔 (바닥 막음). noise = 표면 울퉁불퉁."""
    verts = []
    for i in range(rings + 1):
        t = i / rings
        r = math.cos(t * math.pi / 2)
        z = height * math.sin(t * math.pi / 2)
        row = []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            n = 1 + (random.uniform(-noise, noise) if 0 < i < rings else 0)
            row.append(bm.verts.new((math.cos(a) * r * n, math.sin(a) * r * n, z * (1 + (random.uniform(-noise, noise) if i < rings else 0)))))
        verts.append(row)
    for i in range(rings):
        for k in range(seg):
            k2 = (k + 1) % seg
            bm.faces.new((verts[i][k], verts[i][k2], verts[i + 1][k2], verts[i + 1][k]))
    top = bm.verts.new((0, 0, height))
    for k in range(seg):
        bm.faces.new((verts[rings][k], verts[rings][(k + 1) % seg], top))
    bot = bm.verts.new((0, 0, 0))
    for k in range(seg):
        bm.faces.new((verts[0][(k + 1) % seg], verts[0][k], bot))


WHITE = mat("Sugar", (0.95, 0.95, 0.96), 0.35)
FOAM = mat("Foam", (0.66, 0.38, 0.12), 0.5)

# 1) 설탕 결정 하나: 모서리가 살짝 깎인 정육면체 (한 변 1)
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1.0)
bmesh.ops.bevel(bm, geom=list(bm.edges), offset=0.12, segments=1, affect="EDGES")
for v in bm.verts:
    v.co += Vector((random.uniform(-0.04, 0.04) for _ in range(3)))
finish("SugarCrystal", bm, WHITE, False)

# 2) 설탕 더미: 낮은 돔 위에 결정 450개 (반지름 1, 높이 0.42)
H = 0.42
bm = bmesh.new()
lathe_dome(bm, H * 0.82, seg=32, rings=6)
for _ in range(450):
    a = random.uniform(0, 2 * math.pi)
    r = math.sqrt(random.random()) * 0.98
    z = H * (1 - r * r) ** 0.6 * random.uniform(0.75, 1.0)
    s = random.uniform(0.045, 0.075)
    add_cube(bm, Vector((math.cos(a) * r, math.sin(a) * r, z)), s, Euler((random.uniform(0, 3), random.uniform(0, 3), random.uniform(0, 3))))
finish("SugarPile", bm, WHITE, False)

# 3) 소다 가루 더미: 고운 가루라 결정 대신 잔잔하게 울퉁불퉁한 원뿔형 돔 + 작은 덩어리 (반지름 1, 높이 0.6)
bm = bmesh.new()
lathe_dome(bm, 0.55, seg=36, rings=12, noise=0.035)
for _ in range(60):
    a = random.uniform(0, 2 * math.pi)
    r = math.sqrt(random.random()) * 0.95
    z = 0.55 * math.sin(math.acos(min(r, 1))) * 0.98
    add_ico(bm, Vector((math.cos(a) * r, math.sin(a) * r, z)), random.uniform(0.03, 0.06), 1)
finish("SodaMound", bm, WHITE, True)

# 4) 부푼 거품: 둥글게 부푼 돔 + 표면에 크고 작은 기포 (반지름 1, 높이 0.5)
bm = bmesh.new()
lathe_dome(bm, 0.45, seg=48, rings=12, noise=0.02)
for _ in range(110):
    a = random.uniform(0, 2 * math.pi)
    r = math.sqrt(random.random()) * 0.97
    z = 0.45 * math.sin(math.acos(min(r, 1)))
    rr = random.choice([0.03, 0.04, 0.05, 0.07, 0.09])
    add_ico(bm, Vector((math.cos(a) * r, math.sin(a) * r, z - rr * 0.35)), rr, 1)
finish("FoamPuff", bm, FOAM, True)

for o in scene.objects:
    tris = sum(len(p.vertices) - 2 for p in o.data.polygons)
    d = o.dimensions
    print(f"[fx] {o.name} tris={tris} size=({d.x:.3f}, {d.y:.3f}, {d.z:.3f})")

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "dalgona_fx.glb"), export_format="GLB", use_selection=True, export_apply=True)

# 미리 보기
pos = {"SugarCrystal": (-3.2, 0, 0.3), "SugarPile": (-1.2, 0, 0), "SodaMound": (1.1, 0, 0), "FoamPuff": (3.4, 0, 0)}
for o in scene.objects:
    o.location = pos[o.name]
    if o.name == "SugarCrystal":
        o.scale = (0.5, 0.5, 0.5)
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.45, 0.47, 0.5, 1)
scene.world = world
bpy.ops.mesh.primitive_plane_add(size=20, location=(0, 0, -0.001))
bpy.context.active_object.data.materials.append(mat("Copper", (0.45, 0.2, 0.09), 0.5))
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.5
sun.rotation_euler = (math.radians(45), math.radians(-10), math.radians(30))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.lens = 50
cam.location = (0.1, -7.5, 4.0)
cam.rotation_euler = (Vector((0.1, 0, 0.2)) - cam.location).to_track_quat("-Z", "Y").to_euler()
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 1500, 700
scene.view_settings.view_transform = "Standard"
scene.render.filepath = os.path.join(OUT, "fx_preview.png")
bpy.ops.render.render(write_still=True)
print("[fx] done")
