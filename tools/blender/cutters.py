# 달고나 도안 틀 18종(+사용자 추가 도안)을 한 번에 만든다.
# 사용자가 만든 모형틀(레퍼런스/3D.blend, user_cutters.py)이 있는 도안은 그 모델을 게임 크기로 맞춰 쓰고,
# 나머지는 shapes.py 외곽선으로 만든다. 3D.blend가 없으면 전부 생성.
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/cutters.py -- <출력 폴더> <저장소 루트>
# 결과:
#   <출력>/dalgona_cutters.glb          18개 메시 (이름 Cutter_<id>), Studio에서 한 번에 가져오기
#   <출력>/cutters_sheet.png            전체 미리보기
#   <저장소>/src/shared/CutterShapes.lua  게임용 외곽선 좌표 + 메시 중심 위치 (자동 생성)
# 모양은 star_cutter.py와 같다: 얇은 금속 띠(높이 0.28, 두께 0.045) + 맨 아래 점에서 뻗은 손잡이 철사 + 끝 고리.

import math
import os
import sys

import bpy
import bmesh
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import shapes  # noqa: E402
import user_cutters  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "."
REPO = argv[1] if len(argv) > 1 else os.path.dirname(os.path.dirname(HERE))

STRIP_H, STRIP_T = 0.28, 0.045
CORNER = 0.035
HANDLE_LEN = 1.45
WIRE_R = 0.028
LOOP_R = 0.13
GRID_X, GRID_Y = 3.4, 4.6

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def round_corners(pts):
    """점이 적은(각진) 외곽선만 꼭짓점을 살짝 둥글게. 곡선 외곽선은 그대로."""
    if len(pts) > 40:
        return pts
    out = []
    n = len(pts)
    for i in range(n):
        p = Vector(pts[i])
        a, b = Vector(pts[i - 1]), Vector(pts[(i + 1) % n])
        la, lb = (a - p).length, (b - p).length
        c = min(CORNER, la * 0.3, lb * 0.3)
        out.append(tuple(p + (a - p).normalized() * c))
        out.append(tuple(p + (b - p).normalized() * c))
    return out


def strip_mesh(bm, pts, height, thickness):
    n = len(pts)
    P = [Vector((x, y, 0)) for (x, y) in pts]
    inner, outer = [], []
    for i in range(n):
        p0, p1, p2 = P[i - 1], P[i], P[(i + 1) % n]
        d0 = (p1 - p0).normalized()
        d1 = (p2 - p1).normalized()
        n0 = Vector((d0.y, -d0.x, 0))  # 반시계 외곽선의 바깥쪽
        n1 = Vector((d1.y, -d1.x, 0))
        bis = n0 + n1
        if bis.length < 1e-6:
            bis = n0.copy()
        bis.normalize()
        scale = (thickness / 2) / max(bis.dot(n0), 0.3)
        outer.append(p1 + bis * scale)
        inner.append(p1 - bis * scale)
    rings = []
    for loop in (outer, inner):
        rings.append(([bm.verts.new((v.x, v.y, 0)) for v in loop], [bm.verts.new((v.x, v.y, height)) for v in loop]))
    (ob, ot), (ib, it) = rings
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((ob[i], ob[j], ot[j], ot[i]))
        bm.faces.new((ib[j], ib[i], it[i], it[j]))
        bm.faces.new((ot[i], ot[j], it[j], it[i]))
        bm.faces.new((ib[i], ib[j], ob[j], ob[i]))


def handle_curve(name, start):
    z = STRIP_H - WIRE_R
    s = Vector((start[0], start[1] - STRIP_T / 2, z))
    e = s + Vector((0, -HANDLE_LEN, 0))
    path = [s, e]
    cx, cy = e.x + LOOP_R, e.y
    for k in range(1, 25):
        a = math.pi + k * (2 * math.pi) / 24
        path.append(Vector((cx + math.cos(a) * LOOP_R, cy + math.sin(a) * LOOP_R, z)))
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = WIRE_R
    cu.bevel_resolution = 2
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    sp.points.add(len(path) - 1)
    for i, p in enumerate(path):
        sp.points[i].co = (p.x, p.y, p.z, 1)
    obj = bpy.data.objects.new(name, cu)
    scene.collection.objects.link(obj)
    return obj


steel = bpy.data.materials.new("Steel")
steel.use_nodes = True
bsdf = steel.node_tree.nodes.get("Principled BSDF")
bsdf.inputs["Base Color"].default_value = (0.78, 0.79, 0.81, 1)
bsdf.inputs["Metallic"].default_value = 1.0
bsdf.inputs["Roughness"].default_value = 0.28

SPAN = 1.6  # 모양(손잡이 빼고) 가로·세로 중 긴 쪽 = 생성 도안과 같은 크기


def load_user_cutters():
    path = os.path.join(REPO, user_cutters.BLEND)
    if not os.path.exists(path):
        print("[cutters] 3D.blend 없음 → 전부 생성")
        return {}
    with bpy.data.libraries.load(path, link=False) as (src, dst):
        dst.objects = [n for n in src.objects if n in user_cutters.USER_CUTTERS]
    out = {}
    for o in dst.objects:
        if o is not None:
            out[user_cutters.USER_CUTTERS[o.name]] = o
    return out


def build_from_user(sid, src):
    """사용자 모형틀을 원점 = 모양 중심, 모양 크기 SPAN, 높이 STRIP_H, 벽 두께 STRIP_T로 맞춘 새 오브젝트."""
    mw = src.matrix_world
    V = [tuple(mw @ v.co) for v in src.data.vertices]
    E = [tuple(e.vertices) for e in src.data.edges]
    pts, _ = user_cutters.extract(V, E)
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    f = SPAN / max(max(xs) - min(xs), max(ys) - min(ys))
    zmin, zmax = min(v[2] for v in V), max(v[2] for v in V)
    fz = STRIP_H / (zmax - zmin)
    mesh = src.data.copy()
    mesh.name = "Cutter_" + sid
    for v, w in zip(mesh.vertices, V):
        v.co = ((w[0] - cx) * f, (w[1] - cy) * f, (w[2] - zmin) * fz)
    mesh.materials.clear()
    obj = bpy.data.objects.new("Cutter_" + sid, mesh)
    scene.collection.objects.link(obj)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.mesh.remove_doubles(threshold=0.002)
    bpy.ops.object.mode_set(mode="OBJECT")
    sol = obj.modifiers.new("Wall", "SOLIDIFY")
    sol.thickness = STRIP_T
    sol.offset = 0
    bpy.ops.object.modifier_apply(modifier="Wall")
    outline = [((x - cx) * f, (y - cy) * f) for (x, y) in pts]
    return obj, outline


user_objs = load_user_cutters()
ALL = list(shapes.SHAPES) + [(sid, n, g, None) for (sid, n, g) in user_cutters.EXTRA_SHAPES if sid in user_objs]

def finish(obj, idx, sid, name_ko, grade, outline, src):
    vs = [v.co for v in obj.data.vertices]
    minx, maxx = min(v.x for v in vs), max(v.x for v in vs)
    miny, maxy = min(v.y for v in vs), max(v.y for v in vs)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    # 미리보기용 격자 배치 (원점 = 외곽선 중심, 위치는 내보낸 뒤 Studio에서 상관없음)
    col, row = idx % 6, idx // 6
    obj.location = (col * GRID_X, -row * GRID_Y, 0)
    print(f"[cutters] {sid:10s} {src} tris={tris:4d} size=({maxx - minx:.2f}, {maxy - miny:.2f})")
    return {"id": sid, "name": name_ko, "grade": grade, "outline": outline, "center": ((minx + maxx) / 2, (miny + maxy) / 2),
            "size": (maxx - minx, maxy - miny), "tris": tris, "src": src}


made = []
for idx, (sid, name_ko, grade, _) in enumerate(ALL):
    if sid in user_objs:
        obj, outline = build_from_user(sid, user_objs[sid])
        bpy.ops.object.shade_smooth()
        mod = obj.modifiers.new("Edges", "EDGE_SPLIT")
        mod.split_angle = math.radians(40)
        bpy.ops.object.modifier_apply(modifier="Edges")
        obj.data.materials.append(steel)
        made.append(finish(obj, idx, sid, name_ko, grade, outline, "user"))
        continue
    outline = shapes.outline(sid)
    pts = round_corners(outline)
    bm = bmesh.new()
    strip_mesh(bm, pts, STRIP_H, STRIP_T)
    mesh = bpy.data.meshes.new("Cutter_" + sid)
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    obj = bpy.data.objects.new("Cutter_" + sid, mesh)
    scene.collection.objects.link(obj)
    # 손잡이: 세로 가운데 선(x=0)이 외곽선과 만나는 가장 아래 점. 안 만나면 가장 아래 점
    low = None
    for i in range(len(outline)):
        (x0, y0), (x1, y1) = outline[i], outline[(i + 1) % len(outline)]
        if (x0 <= 0 <= x1 or x1 <= 0 <= x0) and x0 != x1:
            y = y0 + (y1 - y0) * (0 - x0) / (x1 - x0)
            if low is None or y < low[1]:
                low = (0.0, y)
    if low is None:
        low = min(outline, key=lambda p: (round(p[1], 3), abs(p[0])))
    h = handle_curve("Handle_" + sid, low)
    bpy.ops.object.select_all(action="DESELECT")
    bpy.context.view_layer.objects.active = h
    h.select_set(True)
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    h.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.join()
    bpy.ops.object.shade_smooth()
    mod = obj.modifiers.new("Edges", "EDGE_SPLIT")
    mod.split_angle = math.radians(40)
    bpy.ops.object.modifier_apply(modifier="Edges")
    obj.data.materials.append(steel)
    made.append(finish(obj, idx, sid, name_ko, grade, outline, "gen"))

for o in list(user_objs.values()):
    bpy.data.objects.remove(o)


bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "dalgona_cutters.glb"), export_format="GLB", use_selection=True, export_apply=True)

# 게임용 Luau 모듈 생성
lines = [
    "-- 자동 생성: tools/blender/cutters.py (직접 고치지 말고 shapes.py를 고친 뒤 다시 실행)",
    "-- 도안 틀 18종 + 사용자 추가 도안. source = \"user\"(레퍼런스/3D.blend 모형틀) / \"gen\"(shapes.py). outline = 각인 외곽선 (stud, x 오른쪽 · y 위 = 화면 위쪽, 틀 중심 기준)",
    "-- center = 메시(손잡이 포함) 경계 상자 중심이 틀 중심에서 떨어진 거리 (Blender x, y)",
    "-- Roblox에 붙일 때: mesh.CFrame = root.CFrame * CFrame.new(center.X, 0, -center.Y) * CFrame.Angles(0, math.pi, 0)",
    "",
    "return {",
]
for m in made:
    pts = ", ".join(f"{{{x:.3f}, {y:.3f}}}" for (x, y) in m["outline"])
    lines.append(f'\t{{ id = "{m["id"]}", name = "{m["name"]}", grade = "{m["grade"]}", source = "{m["src"]}", center = Vector2.new({m["center"][0]:.4f}, {m["center"][1]:.4f}), outline = {{ {pts} }} }},')
lines.append("}")
with open(os.path.join(REPO, "src", "shared", "CutterShapes.lua"), "w", encoding="utf-8", newline="\n") as f:
    f.write("\n".join(lines) + "\n")

# 전체 미리보기 (위에서 직교 카메라)
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.35, 0.37, 0.42, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
scene.world = world
rows = (len(made) + 5) // 6
cx, cy = 2.5 * GRID_X, -(rows - 1) / 2 * GRID_Y - 0.6
bpy.ops.mesh.primitive_plane_add(size=40, location=(cx, cy, -0.001))
floor = bpy.context.active_object
fm = bpy.data.materials.new("Floor")
fm.use_nodes = True
fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.88, 0.89, 0.92, 1)
floor.data.materials.append(fm)
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.0
sun.rotation_euler = (math.radians(30), math.radians(-15), math.radians(30))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = 21.5
cam.location = (cx, cy, 20)
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 1500, int(1500 * (rows * GRID_Y + 0.6) / 21.5)
scene.view_settings.view_transform = "Standard"
scene.render.filepath = os.path.join(OUT, "cutters_sheet.png")
bpy.ops.render.render(write_still=True)
print("[cutters] done")
