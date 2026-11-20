# 달고나 별 모양 틀 (철사 틀) — Blender 스크립트로 만든다.
# 실행: "D:\Blender 5.2\blender.exe" -b -P tools/blender/star_cutter.py -- <출력 폴더>
# 결과: dalgona_star_cutter.glb (Roblox용) + 미리보기 렌더 PNG
#
# 크기는 게임 안 별 틀과 같다 (1 Blender 단위 = 1 stud):
#   바깥 꼭짓점 반지름 0.8, 안쪽 0.36, 띠 높이 0.28, 띠 두께 0.045
# 모양은 레퍼런스/15.jpg: 얇은 금속 띠를 별 모양으로 접고, 아래쪽 안 꼭짓점에서 손잡이 철사가 뻗어 나가 끝이 고리로 말림.

import math
import sys

import bpy
import bmesh
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "."

OUTER, INNER = 0.8, 0.36
STRIP_H, STRIP_T = 0.28, 0.045
CORNER = 0.035  # 접힌 모서리 둥글기
HANDLE_LEN = 1.45
WIRE_R = 0.028
LOOP_R = 0.13

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def star_points():
    pts = []
    for k in range(10):
        a = math.radians(90 + k * 36)  # 위쪽(+Y)이 첫 바깥 꼭짓점
        r = OUTER if k % 2 == 0 else INNER
        pts.append(Vector((math.cos(a) * r, math.sin(a) * r, 0)))
    return pts


def strip_from_outline(name, pts, height, thickness):
    """닫힌 외곽선을 따라 세운 띠(벽) 메시. 모서리마다 두께 방향으로 밀어 안팎 면을 만든다."""
    n = len(pts)
    inner, outer = [], []
    for i in range(n):
        p0, p1, p2 = pts[i - 1], pts[i], pts[(i + 1) % n]
        d0 = (p1 - p0).normalized()
        d1 = (p2 - p1).normalized()
        n0 = Vector((d0.y, -d0.x, 0))
        n1 = Vector((d1.y, -d1.x, 0))
        bis = (n0 + n1)
        if bis.length < 1e-6:
            bis = n0
        bis.normalize()
        scale = (thickness / 2) / max(bis.dot(n0), 0.25)  # 마이터 길이 (뾰족한 곳은 제한)
        outer.append(p1 + bis * scale)
        inner.append(p1 - bis * scale)
    bm = bmesh.new()
    rings = []
    for loop in (outer, inner):
        bottom = [bm.verts.new((v.x, v.y, 0)) for v in loop]
        top = [bm.verts.new((v.x, v.y, height)) for v in loop]
        rings.append((bottom, top))
    (ob, ot), (ib, it) = rings
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((ob[i], ob[j], ot[j], ot[i]))  # 바깥 벽
        bm.faces.new((ib[j], ib[i], it[i], it[j]))  # 안 벽
        bm.faces.new((ot[i], ot[j], it[j], it[i]))  # 윗면
        bm.faces.new((ib[i], ib[j], ob[j], ob[i]))  # 아랫면
    mesh = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new(name, mesh)
    scene.collection.objects.link(obj)
    return obj


def wire_along(name, path_pts, radius, segments=8):
    """점들을 잇는 둥근 철사 (곡선 + bevel → 메시)."""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = radius
    cu.bevel_resolution = 2
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    sp.points.add(len(path_pts) - 1)
    for i, p in enumerate(path_pts):
        sp.points[i].co = (p.x, p.y, p.z, 1)
    obj = bpy.data.objects.new(name, cu)
    scene.collection.objects.link(obj)
    return obj


# 1) 별 띠 — 모서리를 아주 살짝 둥글게 (꼭짓점마다 두 점으로 쪼갬)
raw = star_points()
rounded = []
for i, p in enumerate(raw):
    a = raw[i - 1]
    b = raw[(i + 1) % len(raw)]
    rounded.append(p + (a - p).normalized() * CORNER)
    rounded.append(p + (b - p).normalized() * CORNER)
star = strip_from_outline("StarStrip", rounded, STRIP_H, STRIP_T)

# 2) 손잡이: 아래쪽 안 꼭짓점(-Y)에서 철사가 아래로 뻗고, 끝이 고리로 말림
bottom_inner = raw[5]  # 각도 270° = 아래쪽 안 꼭짓점
z = STRIP_H - WIRE_R  # 띠 윗부분 높이에서 나옴
start = Vector((bottom_inner.x, bottom_inner.y - STRIP_T / 2, z))
end = start + Vector((0, -HANDLE_LEN, 0))
path = [start, end]
# 고리: 철사 끝에서 원을 한 바퀴 반 돌아 말림
cx, cy = end.x + LOOP_R, end.y
for s in range(1, 25):
    a = math.pi + s * (2 * math.pi * 1.0) / 24
    path.append(Vector((cx + math.cos(a) * LOOP_R, cy + math.sin(a) * LOOP_R, z)))
handle = wire_along("Handle", path, WIRE_R)

# 메시로 합치기
for o in (handle,):
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    o.select_set(False)
bpy.ops.object.select_all(action="DESELECT")
star.select_set(True)
handle.select_set(True)
bpy.context.view_layer.objects.active = star
bpy.ops.object.join()
cutter = bpy.context.active_object
cutter.name = "StarCutter"
bpy.ops.object.shade_smooth()
mod = cutter.modifiers.new("Edges", "EDGE_SPLIT")
mod.split_angle = math.radians(40)
bpy.ops.object.modifier_apply(modifier="Edges")

# 원점 = 별 중심의 바닥 (게임에서 틀을 놓는 기준점과 같게)
bpy.context.scene.cursor.location = (0, 0, 0)
bpy.ops.object.origin_set(type="ORIGIN_CURSOR")

# 스테인리스 재질 (Roblox에는 색만 넘어감, 광택은 Studio에서 SurfaceAppearance로)
mat = bpy.data.materials.new("Steel")
mat.use_nodes = True
bsdf = mat.node_tree.nodes.get("Principled BSDF")
bsdf.inputs["Base Color"].default_value = (0.78, 0.79, 0.81, 1)
bsdf.inputs["Metallic"].default_value = 1.0
bsdf.inputs["Roughness"].default_value = 0.28
cutter.data.materials.append(mat)

tris = sum(len(p.vertices) - 2 for p in cutter.data.polygons)
print(f"[star_cutter] tris={tris} verts={len(cutter.data.vertices)} dims={tuple(round(d, 3) for d in cutter.dimensions)}")

# 내보내기 (Roblox: glTF, +Y 위)
bpy.ops.export_scene.gltf(filepath=f"{OUT}/dalgona_star_cutter.glb", export_format="GLB", use_selection=False, export_apply=True)

# 미리보기 렌더: 레퍼런스 사진처럼 흰 바닥 + 위쪽 소프트박스(금속에 비치는 빛)
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.35, 0.37, 0.42, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
scene.world = world

bpy.ops.mesh.primitive_plane_add(size=12, location=(0, 0, -0.001))
floor = bpy.context.active_object
fm = bpy.data.materials.new("Floor")
fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.86, 0.87, 0.9, 1)
fm.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.6
floor.data.materials.append(fm)

bpy.ops.mesh.primitive_plane_add(size=4, location=(-1.0, 0.5, 4.5))
box = bpy.context.active_object
bm_ = bpy.data.materials.new("Softbox")
bm_.use_nodes = True
em = bm_.node_tree.nodes["Principled BSDF"]
em.inputs["Emission Color"].default_value = (1, 1, 1, 1)
em.inputs["Emission Strength"].default_value = 6.0
box.data.materials.append(bm_)

sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(35), math.radians(-20), math.radians(30))
scene.collection.objects.link(sun)

cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.lens = 50
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 900, 900
scene.view_settings.view_transform = "Standard"


def look(obj, target):
    d = Vector(target) - obj.location
    obj.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()


center = (0.05, -0.62, 0.1)
for tag, loc in (("top", (0.6, -2.4, 4.6)), ("side", (2.9, -3.3, 1.6))):
    cam.location = loc
    look(cam, center)
    scene.render.filepath = f"{OUT}/star_cutter_{tag}.png"
    bpy.ops.render.render(write_still=True)
print("[star_cutter] done")
