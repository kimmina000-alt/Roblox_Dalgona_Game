# 달고나 노점 소품: 설탕 양은 그릇 + 설탕 더미, 소다 깡통 + 라벨 + 소다 가루, 나무 숟가락(설탕), 쇠 티스푼(소다)
# 참고: 레퍼런스/2.jpg·7.jpg (설탕을 담은 납작한 양은 그릇), 8.jpg (소다 봉지와 구리 그릇), 옛날 노점 사진들.
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/props.py -- <출력 폴더>
# 결과: <출력>/dalgona_props.glb (오브젝트 이름 = Roblox 메시 이름), props_preview.png, props_offsets.txt
#
# 크기는 게임 stud 그대로 (1 Blender 단위 = 1 stud). 원점 = 게임에서 붙이는 기준점:
#   그릇·깡통 = 바닥 가운데, 숟가락 = 숟가락 오목한 곳 가운데(게임의 Scoop 부품 자리).
# 숟가락 손잡이는 Blender -Y 방향(= Roblox에서 180° 돌려 붙이면 플레이어 쪽 +Z).
# Roblox MeshPart는 경계 상자 가운데가 기준이라, 기준점에서 경계 상자 가운데까지 거리를 props_offsets.txt에 적는다.

import math
import os
import sys

import bmesh
import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = argv[0] if argv else "."

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def mat(name, rgb, metal=0.0, rough=0.5):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*rgb, 1)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    return m


def lin(c):
    return tuple(((v / 255) ** 2.2) for v in c)


M_YANGEUN = mat("Yangeun", lin((214, 196, 140)), 1.0, 0.35)  # 양은(누르스름한 알루미늄)
M_TIN = mat("Tin", lin((200, 202, 206)), 1.0, 0.3)
M_LABEL = mat("Label", lin((210, 40, 46)), 0.0, 0.6)
M_WHITE = mat("Powder", lin((250, 250, 250)), 0.0, 0.9)
M_WOOD = mat("Wood", lin((214, 176, 120)), 0.0, 0.7)
M_STEEL = mat("Steel", lin((205, 207, 212)), 1.0, 0.25)


def new_obj(name, bm, material, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    o.data.materials.append(material)
    if smooth:
        for p in o.data.polygons:
            p.use_smooth = True
    return o


def lathe(name, profile, material, seg=48, cap_bottom=False):
    """profile: [(r, z)...] 아래에서 위로 (바깥 → 안쪽으로 돌아오는 닫힌 단면이면 두께가 생김)."""
    bm = bmesh.new()
    rings = []
    for (r, z) in profile:
        rings.append([bm.verts.new((math.cos(2 * math.pi * k / seg) * r, math.sin(2 * math.pi * k / seg) * r, z)) for k in range(seg)])
    for a, b in zip(rings, rings[1:]):
        for k in range(seg):
            k2 = (k + 1) % seg
            bm.faces.new((a[k], a[k2], b[k2], b[k]))
    if cap_bottom:
        c = bm.verts.new((0, 0, profile[0][1]))
        for k in range(seg):
            bm.faces.new((rings[0][(k + 1) % seg], rings[0][k], c))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_obj(name, bm, material)


def loft(name, sections, material):
    """sections: [(center Vector, side Vector, up Vector, half_w, half_h)...] 단면 = 납작한 타원. 양 끝 막음."""
    bm = bmesh.new()
    n = 14
    rings = []
    for (c, side, up, hw, hh) in sections:
        ring = []
        for k in range(n):
            a = 2 * math.pi * k / n
            ring.append(bm.verts.new(c + side * (math.cos(a) * hw) + up * (math.sin(a) * hh)))
        rings.append(ring)
    for a, b in zip(rings, rings[1:]):
        for k in range(n):
            k2 = (k + 1) % n
            bm.faces.new((a[k], a[k2], b[k2], b[k]))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return new_obj(name, bm, material)


# ---------------------------------------------------------------- 설탕 양은 그릇 (지름 1.5, 높이 0.42)
def sugar_bowl():
    R0, R1, H, T = 0.5, 0.72, 0.42, 0.03
    prof = [(0.0001, 0.0)]
    # 바깥 벽: 바닥 → 살짝 둥근 아랫모서리 → 벌어지는 벽
    for i in range(0, 7):
        a = math.radians(-90 + 90 * i / 6)
        prof.append((R0 - 0.06 + math.cos(a) * 0.06, 0.06 + math.sin(a) * 0.06))
    for i in range(1, 9):
        t = i / 8
        prof.append((R0 + (R1 - R0) * t, 0.06 + (H - 0.06) * t))
    # 말린 테두리 (둥근 입술)
    for i in range(1, 11):
        a = math.radians(-90 + 360 * i / 10 * 0.75)
        prof.append((R1 + 0.02 + math.cos(a) * 0.025, H + 0.01 + math.sin(a) * 0.025))
    # 안쪽 벽 (위 → 아래)
    for i in range(8, -1, -1):
        t = i / 8
        prof.append((R0 - T + (R1 - R0) * t, T + 0.06 + (H - 0.06 - T) * t))
    prof.append((0.0001, T))
    bowl = lathe("SugarBowlMesh", prof, M_YANGEUN, seg=56)
    # 양은 그릇 특유의 찌그러진 자국: 몇 군데 살짝 눌림
    dents = [(0.6, 0.0), (2.4, 0.03), (4.1, -0.02)]
    for v in bowl.data.vertices:
        r = math.hypot(v.co.x, v.co.y)
        if r < 0.3:
            continue
        a = math.atan2(v.co.y, v.co.x)
        for (da, dz) in dents:
            d = math.atan2(math.sin(a - da), math.cos(a - da))
            k = math.exp(-(d / 0.25) ** 2) * math.exp(-((v.co.z - 0.25 - dz) / 0.12) ** 2)
            v.co.x -= math.cos(a) * 0.035 * k
            v.co.y -= math.sin(a) * 0.035 * k
    # 설탕 더미 (그릇 안쪽 벽을 따라 채우고 가운데가 볼록) — 색은 Roblox에서 흰 설탕 / 황설탕으로
    prof = [(0.0001, 0.07), (R0 - T - 0.01, 0.07)]
    for i in range(1, 5):  # 안쪽 벽을 따라 올라감
        t = i / 4
        z = 0.07 + (0.3 - 0.07) * t
        prof.append((R0 - T - 0.01 + (R1 - R0) * (z - 0.09) / (H - 0.09), z))
    rim = prof[-1][0]
    for i in range(1, 11):  # 윗면: 가장자리에서 가운데로 볼록하게
        t = i / 10
        prof.append((rim * (1 - t), 0.3 + 0.09 * math.sin(t * math.pi / 2) + 0.012 * math.sin(t * 11)))
    prof[-1] = (0.0001, prof[-1][1])
    lathe("SugarHeapMesh", prof, M_WHITE, seg=40)


# ---------------------------------------------------------------- 소다 깡통 (지름 0.9, 높이 0.62)
def soda_can():
    R, H = 0.45, 0.62
    prof = [(0.0001, 0.0), (R - 0.03, 0.0), (R, 0.03)]
    # 옆면 홈 2줄 (깡통 테)
    for z in (0.08, 0.54):
        prof += [(R, z - 0.025), (R - 0.012, z), (R, z + 0.025)]
    prof += [(R, H - 0.02)]
    for i in range(1, 9):  # 말린 윗테
        a = math.radians(-90 + 300 * i / 8)
        prof.append((R + math.cos(a) * 0.018, H + math.sin(a) * 0.018))
    prof += [(R - 0.02, H - 0.02), (R - 0.02, 0.03), (0.0001, 0.03)]
    lathe("SodaCanMesh", prof, M_TIN, seg=48)
    # 빨간 라벨 띠 (두 홈 사이)
    lathe("SodaLabelMesh", [(R + 0.004, 0.12), (R + 0.004, 0.5)], M_LABEL, seg=48)
    # 소다 가루 (깡통 안, 위에서 조금 아래)
    prof = [(0.0001, 0.5)]
    for i in range(1, 9):
        t = i / 8
        prof.append(((R - 0.03) * t, 0.56 - 0.04 * t * t))
    prof.append((R - 0.03, 0.5))
    lathe("SodaPowderMesh", prof, M_WHITE, seg=40)


# ---------------------------------------------------------------- 숟가락
def spoon(name, bowl_w, bowl_l, depth, handle_len, handle_w, rise, material, thick):
    bm = bmesh.new()
    # 오목한 숟가락 머리: 반쪽 타원체 껍질 (가장자리 높이 0, 아래로 depth)
    nu, nv = 24, 8
    outer, inner = [], []
    for i in range(nv + 1):
        t = i / nv  # 0 = 가장자리, 1 = 바닥 가운데
        rows_o, rows_i = [], []
        for k in range(nu):
            a = 2 * math.pi * k / nu
            s = math.cos(t * math.pi / 2)
            x = math.cos(a) * bowl_w / 2 * s
            y = math.sin(a) * bowl_l / 2 * s
            z = -depth * math.sin(t * math.pi / 2)
            rows_o.append(bm.verts.new((x, y, z - thick)))
            rows_i.append(bm.verts.new((x * 0.97, y * 0.97, z)))
        outer.append(rows_o)
        inner.append(rows_i)
    for rows, flip in ((outer, False), (inner, True)):
        for i in range(nv):
            for k in range(nu):
                k2 = (k + 1) % nu
                f = (rows[i][k], rows[i][k2], rows[i + 1][k2], rows[i + 1][k])
                bm.faces.new(tuple(reversed(f)) if flip else f)
    for k in range(nu):  # 가장자리 이음
        k2 = (k + 1) % nu
        bm.faces.new((inner[0][k], inner[0][k2], outer[0][k2], outer[0][k]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    head = new_obj(name, bm, material)
    # 손잡이: 숟가락 머리 끝(-Y)에서 시작해 -Y로 뻗으며 위로 휨, 끝으로 갈수록 넓어짐
    secs = []
    steps = 16
    for i in range(steps + 1):
        t = i / steps
        y = -bowl_l / 2 * 0.92 - handle_len * t
        z = -thick / 2 + rise * (t ** 1.4)
        c = Vector((0, y, z))
        dz = rise * 1.4 * (t ** 0.4) / handle_len if t > 0 else 0
        fwd = Vector((0, -1, dz)).normalized()
        side = Vector((1, 0, 0))
        up = side.cross(fwd).normalized() * -1
        w = handle_w * (0.55 + 0.45 * t) if t < 0.85 else handle_w * (1.0 - (t - 0.85) / 0.15 * 0.25)
        secs.append((c, side, up, w / 2, thick * 0.9))
    h = loft(name + "_h", secs, material)
    bpy.ops.object.select_all(action="DESELECT")
    head.select_set(True)
    h.select_set(True)
    bpy.context.view_layer.objects.active = head
    bpy.ops.object.join()
    return head


sugar_bowl()
soda_can()
spoon("WoodSpoonMesh", 0.62, 0.8, 0.12, 1.9, 0.16, 0.5, M_WOOD, 0.04)
spoon("TinSpoonMesh", 0.4, 0.52, 0.07, 1.3, 0.1, 0.3, M_STEEL, 0.02)

# 경계 상자 가운데 (기준점에서) — Roblox에 붙일 때 씀
lines = []
for o in scene.objects:
    vs = [o.matrix_world @ v.co for v in o.data.vertices]
    mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    mx = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    c = (mn + mx) / 2
    s = mx - mn
    lines.append(f"{o.name} center=({c.x:.4f}, {c.y:.4f}, {c.z:.4f}) size=({s.x:.3f}, {s.y:.3f}, {s.z:.3f}) tris={sum(len(p.vertices) - 2 for p in o.data.polygons)}")
print("\n".join(lines))
with open(os.path.join(OUT, "props_offsets.txt"), "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "dalgona_props.glb"), export_format="GLB", use_selection=True, export_apply=True)

# 미리 보기: 비스듬히 위에서, 소품을 나란히
layout = {"SugarBowlMesh": (-2.0, 0.8), "SugarHeapMesh": (-2.0, 0.8), "SodaCanMesh": (0.0, 0.8), "SodaLabelMesh": (0.0, 0.8),
          "SodaPowderMesh": (0.0, 0.8), "WoodSpoonMesh": (1.7, 1.2), "TinSpoonMesh": (2.8, 1.0)}
for o in scene.objects:
    x, y = layout.get(o.name, (0, 0))
    o.location = (x, y, 0.16 if "Spoon" in o.name else 0)  # 숟가락 머리는 기준점보다 아래로 오목해서 띄움
heap = scene.objects["SugarHeapMesh"]
heap.data.materials[0] = mat("SugarTint", lin((250, 250, 250)), 0, 0.9)
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.5, 0.52, 0.56, 1)
world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.9
scene.world = world
bpy.ops.mesh.primitive_plane_add(size=14, location=(0, 0, -0.001))
fl = bpy.context.active_object
fl.data.materials.append(mat("Table", lin((132, 92, 58)), 0, 0.8))
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3.5
sun.rotation_euler = (math.radians(40), math.radians(-15), math.radians(30))
scene.collection.objects.link(sun)
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
cam.data.lens = 45
cam.location = (0.3, -5.6, 4.4)
d = Vector((0.3, 0.4, 0.2)) - cam.location
cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
scene.collection.objects.link(cam)
scene.camera = cam
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 1400, 900
scene.view_settings.view_transform = "Standard"
scene.render.filepath = os.path.join(OUT, "props_preview.png")
bpy.ops.render.render(write_still=True)
print("[props] done")
