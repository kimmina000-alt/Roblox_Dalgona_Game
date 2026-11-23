# 가게 모서리 세로 걸이 간판 (사용자 2026-11-24: 사진처럼 "똑같이 구현")
#   지금 Studio 자리 = PlotLayout.ShopModel["Cube.007"]["Cube.029"] (Role "세로 걸이 간판", 빈 크림 판)
#   + "Cube.017"["Cube.032"] (걸이 간판 받침쇠, 작은 상자).
#   사진: 둥근 네모 라이트박스(황갈색 테 + 크림 면), 위에 동그라미 안 별, 아래로 세로 글씨 "달고나"(갈색),
#         검은 쇠 팔걸이(벽 판 + 가로 팔 + 아래 소용돌이 장식)에 막대 두 개로 매달림. 양쪽 면 같은 그림.
#
# 부품 (한 부품 = 색 하나, Studio에서 Color만 넣음):
#   HSign_Bracket 쇠 팔걸이·막대·고리 (짙은 쇠)   HSign_Frame 테 (황갈색 나무)
#   HSign_Face 크림 면 (빛나는 면)               HSign_Disc 동그라미 속 살구색 + 별 속 주황
#   HSign_Art 갈색 선·글씨 (동그라미 테·별 테·반짝 표시·"달고나")
# 크기 = 게임 stud. 원점 = 벽면(Blender y=0)·판 세로 가운데·판 두께 가운데. 간판은 벽에서 Blender -Y로 나옴,
#   면은 ±X를 봄. 좌표 변환 Blender (x, y, z) → Roblox (-x, z, y) (glb 가져오면 앞뒤가 뒤집힐 수 있어 Studio에서 화면으로 맞춤).
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/hanging_sign.py -- <출력 폴더(절대 경로)>
# 결과: dalgona_hanging_sign.glb, hanging_sign_preview.png, hanging_sign_parts.txt

import math
import os
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else ".")
os.makedirs(OUT, exist_ok=True)
FONT = r"C:\Windows\Fonts\malgunbd.ttf"

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# ───────── 치수 ─────────
W, H = 4.0, 8.4          # 판 폭(벽에서 나오는 쪽) · 높이
T = 0.8                  # 테 두께
RIM = 0.32               # 테 폭
R_OUT = 1.25             # 판 모서리 둥글기
GAP = 0.9                # 벽과 판 사이
YC = -(GAP + W / 2)      # 판 가운데 y
FACE_IN = 0.07           # 면이 테보다 들어간 깊이
ART_UP = 0.035           # 그림이 면에서 나온 높이
ARM_Z = H / 2 + 1.25     # 가로 팔 높이
ARM_LEN = GAP + W + 0.7

COL = {
    "HSign_Bracket": (54, 46, 42),
    "HSign_Frame": (214, 160, 104),
    "HSign_Face": (253, 243, 224),
    "HSign_Disc": (246, 204, 146),
    "HSign_Art": (122, 74, 42),
}
NOTES = {
    "HSign_Bracket": "쇠 팔걸이: 벽 판·가로 팔·끝 공·아래 소용돌이 장식·매다는 막대 2개·고리",
    "HSign_Frame": "둥근 네모 테 (황갈색 나무), 모서리 둥글게",
    "HSign_Face": "크림 면 양쪽 (라이트박스 빛 나는 면, PointLight 붙이면 좋음)",
    "HSign_Disc": "동그라미 속 살구색 + 별 속 연한 주황 (양쪽)",
    "HSign_Art": "갈색: 동그라미 테·별 테·반짝 표시 3개·세로 글씨 달고나 (양쪽)",
}
BMS = {k: bmesh.new() for k in COL}


def add_obj_mesh(name, obj):
    """만든 오브젝트 메시를 부품 bmesh로 합치고 오브젝트는 지움."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev)
    me.transform(obj.matrix_world)
    BMS[name].from_mesh(me)
    bpy.data.meshes.remove(me)
    bpy.data.objects.remove(obj, do_unlink=True)


def link(me, name="tmp"):
    o = bpy.data.objects.new(name, me)
    scene.collection.objects.link(o)
    return o


def rrect(w, h, r, seg=10):
    """둥근 네모 외곽 (u=폭, v=높이), 반시계."""
    r = min(r, w / 2 - 1e-4, h / 2 - 1e-4)
    pts = []
    for cx, cy, a0 in ((w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)):
        for i in range(seg + 1):
            a = math.radians(a0 + 90 * i / seg)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def circle(r, n=48):
    return [(r * math.cos(2 * math.pi * i / n), r * math.sin(2 * math.pi * i / n)) for i in range(n)]


def star(ro, ri, n=5, rot=90):
    pts = []
    for i in range(2 * n):
        r = ro if i % 2 == 0 else ri
        a = math.radians(rot + 180 * i / n)
        pts.append((r * math.cos(a), r * math.sin(a)))
    return pts


def to3(u, v, x):
    """판 위 2D (u=벽에서 먼 쪽 +, v=위 +) → Blender 좌표, x = 면 높이."""
    return Vector((x, YC - u, v))


def slab(name, outer, x0, x1, inner=None, bevel=0.0, u0=0.0, v0=0.0, flip=False):
    """2D 외곽(구멍 inner 선택)을 x0~x1 두께로 세움. flip = 면 반대쪽(-X)에서 볼 때 좌우 뒤집기."""
    bm = bmesh.new()
    s = -1 if flip else 1

    def P(p, x):
        return to3(u0 + s * p[0], v0 + p[1], x)

    if inner is None:
        vs = [bm.verts.new(P(p, x0)) for p in outer]
        f = bm.faces.new(vs if not flip else vs[::-1])
    else:
        vo = [bm.verts.new(P(p, x0)) for p in outer]
        vi = [bm.verts.new(P(p, x0)) for p in inner]
        eo = [bm.edges.new((vo[i], vo[(i + 1) % len(vo)])) for i in range(len(vo))]
        ei = [bm.edges.new((vi[i], vi[(i + 1) % len(vi)])) for i in range(len(vi))]
        bmesh.ops.bridge_loops(bm, edges=eo + ei)
    bm.normal_update()
    faces = list(bm.faces)
    ext = bmesh.ops.extrude_face_region(bm, geom=faces)
    nv = [g for g in ext["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=nv, vec=Vector((x1 - x0, 0, 0)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("s")
    bm.to_mesh(me)
    bm.free()
    o = link(me)
    if bevel > 0:
        m = o.modifiers.new("b", "BEVEL")
        m.width = bevel
        m.segments = 3
        m.limit_method = "ANGLE"
        m.angle_limit = math.radians(40)
    add_obj_mesh(name, o)


def box(name, c, size, rotm=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1)
    bmesh.ops.scale(bm, vec=Vector(size), verts=bm.verts)
    if rotm is not None:
        bmesh.ops.transform(bm, matrix=rotm, verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(c), verts=bm.verts)
    me = bpy.data.meshes.new("b")
    bm.to_mesh(me)
    bm.free()
    o = link(me)
    m = o.modifiers.new("b", "BEVEL")
    m.width = min(size) * 0.18
    m.segments = 2
    add_obj_mesh(name, o)


def tube(name, pts, r, cyclic=False):
    cu = bpy.data.curves.new("c", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = 3
    cu.use_fill_caps = True
    sp = cu.splines.new("POLY")
    sp.points.add(len(pts) - 1)
    for i, p in enumerate(pts):
        sp.points[i].co = (p[0], p[1], p[2], 1)
    sp.use_cyclic_u = cyclic
    o = link(cu)
    add_obj_mesh(name, o)


def ball(name, c, r):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=16, v_segments=10, radius=r)
    bmesh.ops.translate(bm, vec=Vector(c), verts=bm.verts)
    me = bpy.data.meshes.new("ball")
    bm.to_mesh(me)
    bm.free()
    add_obj_mesh(name, link(me))


# ───────── 판: 테 + 크림 면 ─────────
outer = rrect(W, H, R_OUT)
inner = rrect(W - 2 * RIM, H - 2 * RIM, R_OUT - RIM)
slab("HSign_Frame", outer, -T / 2, T / 2, inner=inner, bevel=0.09)
slab("HSign_Face", inner, -T / 2 + FACE_IN, T / 2 - FACE_IN)

# ───────── 그림 (양쪽 면) ─────────
DISC_V = 2.15        # 동그라미 가운데 높이
DISC_R = 1.12
LINE = 0.13          # 갈색 선 굵기
for side in (1, -1):
    flip = side > 0   # +X 면에서 보면 오른쪽 = 벽 쪽(+Y)이라 u를 뒤집어야 글씨가 바로 보임
    xf = side * (T / 2 - FACE_IN)                 # 면 높이
    a0, a1 = sorted((xf, xf + side * ART_UP))      # 살구색 칠
    b0, b1 = sorted((xf, xf + side * ART_UP * 1.8))  # 갈색 선 (조금 더 위)
    # 동그라미: 살구 속 + 갈색 테
    slab("HSign_Disc", circle(DISC_R - LINE * 0.5), a0, a1, v0=DISC_V, flip=flip)
    slab("HSign_Art", circle(DISC_R + LINE * 0.5), b0, b1, inner=circle(DISC_R - LINE * 0.5), v0=DISC_V, flip=flip)
    # 별: 연한 주황 속 + 갈색 테 (살짝 기울임, 손그림 느낌)
    so, si = 0.66, 0.29
    st_out = star(so, si, rot=96)
    st_in = star(so - 0.17, si - 0.075, rot=96)
    slab("HSign_Disc", st_in, b0, b1 - ART_UP * 0.4, v0=DISC_V - 0.04, flip=flip)
    slab("HSign_Art", st_out, b0, b1, inner=st_in, v0=DISC_V - 0.04, flip=flip)
    # 반짝 표시 3개 (동그라미 오른쪽 위 바깥)
    for ang, ln in ((40, 0.34), (58, 0.26), (22, 0.24)):
        a = math.radians(ang)
        cu_, cv_ = (DISC_R + 0.34) * math.cos(a), DISC_V + (DISC_R + 0.34) * math.sin(a)
        bar = rrect(ln, LINE * 0.95, LINE * 0.47, seg=4)
        rb = [(p[0] * math.cos(a) - p[1] * math.sin(a), p[0] * math.sin(a) + p[1] * math.cos(a)) for p in bar]
        slab("HSign_Art", rb, b0, b1, u0=cu_ if not flip else -cu_, v0=cv_, flip=flip)

    # 세로 글씨 달고나
    for ch, cv in (("달", 0.05), ("고", -1.6), ("나", -3.15)):
        cu = bpy.data.curves.new("t", "FONT")
        cu.body = ch
        cu.font = bpy.data.fonts.load(FONT, check_existing=True)
        cu.size = 1.55
        cu.extrude = 0
        cu.resolution_u = 6
        o = link(cu)
        dg = bpy.context.evaluated_depsgraph_get()
        me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
        bpy.data.objects.remove(o, do_unlink=True)
        xs = [v.co.x for v in me.vertices]
        ys = [v.co.y for v in me.vertices]
        mx, my = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
        bm = bmesh.new()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)
        # 글자 평면 (x→u, y→v) → 판 면으로
        for v in bm.verts:
            u = v.co.x - mx
            vv = v.co.y - my + cv
            v.co = to3(-u if flip else u, vv, b0 if side > 0 else b1)
        bm.normal_update()
        ext = bmesh.ops.extrude_face_region(bm, geom=list(bm.faces))
        nv = [g for g in ext["geom"] if isinstance(g, bmesh.types.BMVert)]
        bmesh.ops.translate(bm, verts=nv, vec=Vector((side * ART_UP * 1.8, 0, 0)))
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        me = bpy.data.meshes.new("txt")
        bm.to_mesh(me)
        bm.free()
        BMS["HSign_Art"].from_mesh(me)
        bpy.data.meshes.remove(me)

# ───────── 쇠 팔걸이 ─────────
B = "HSign_Bracket"
box(B, (0, -0.08, ARM_Z - 0.35), (0.95, 0.16, 2.3))                     # 벽 판
for z in (ARM_Z + 0.55, ARM_Z - 1.25):                                   # 벽 판 못
    ball(B, (0, -0.17, z), 0.08)
box(B, (0, -ARM_LEN / 2, ARM_Z), (0.2, ARM_LEN, 0.2))                    # 가로 팔
ball(B, (0, -ARM_LEN - 0.05, ARM_Z), 0.2)                                # 팔 끝 공
# 아래 받침: 벽 판 아래에서 휘어 올라 팔에 붙음 + 그 안쪽 소용돌이 (사진처럼)
pts = []
for i in range(25):
    t = i / 24
    pts.append((0, -0.16 - 2.9 * t, ARM_Z - 1.4 + 1.4 * math.sin(t * math.pi / 2)))
tube(B, pts, 0.07)
cyc, czc, r0 = -1.25, ARM_Z - 0.52, 0.44
pts = []
for i in range(0, 41):
    t = i / 40
    a = math.radians(90 + 560 * t)          # 위(팔에 닿는 곳)에서 시작해 안으로 말림
    r = r0 * (1 - 0.72 * t)
    pts.append((0, cyc + r * math.cos(a), czc + r * math.sin(a)))
tube(B, pts, 0.055)
# 매다는 막대 2개 + 위아래 고리
for du in (-1.05, 1.05):
    y = YC - du
    tube(B, [(0, y, H / 2 + 0.28), (0, y, ARM_Z - 0.06)], 0.055)
    tube(B, [(0, y + 0.16 * math.cos(math.radians(a)), ARM_Z + 0.16 * math.sin(math.radians(a))) for a in range(0, 361, 30)], 0.045, cyclic=True)
    box(B, (0, y, H / 2 + 0.12), (0.32, 0.3, 0.32))                      # 판 위 고리 받침

# ───────── 오브젝트로 ─────────
objs = []
for name, bm in BMS.items():
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    me.set_sharp_from_angle(angle=math.radians(35))
    o = link(me, name)
    mat = bpy.data.materials.new(name)
    rgb = tuple((c / 255) ** 2.2 for c in COL[name]) + (1,)
    mat.diffuse_color = rgb
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = rgb
    bsdf.inputs["Roughness"].default_value = 0.6
    if name == "HSign_Face":
        bsdf.inputs["Emission Color"].default_value = rgb
        bsdf.inputs["Emission Strength"].default_value = 0.35
    me.materials.append(mat)
    objs.append(o)

lines = ["# 세로 걸이 간판 부품 (원점 = 벽면·판 세로 가운데, Blender 좌표, stud)", f"# 판 가운데 y={YC:.2f}, 판 {W}×{H}×{T}, 팔 높이 z={ARM_Z:.2f}, 팔 길이 {ARM_LEN:.2f}"]
tri_total = 0
allv = []
for o in objs:
    me = o.data
    me.calc_loop_triangles()
    tri = len(me.loop_triangles)
    tri_total += tri
    vs = [o.matrix_world @ v.co for v in me.vertices]
    allv += vs
    mn = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    mxv = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    c = (mn + mxv) / 2
    lines.append(f"{o.name}: tri {tri}, 가운데 ({c.x:.3f},{c.y:.3f},{c.z:.3f}), 크기 ({mxv.x-mn.x:.3f},{mxv.y-mn.y:.3f},{mxv.z-mn.z:.3f}), 색 {COL[o.name]} — {NOTES[o.name]}")
mn = Vector((min(v.x for v in allv), min(v.y for v in allv), min(v.z for v in allv)))
mxv = Vector((max(v.x for v in allv), max(v.y for v in allv), max(v.z for v in allv)))
lines.append(f"전체 tri {tri_total}, 범위 min ({mn.x:.3f},{mn.y:.3f},{mn.z:.3f}) max ({mxv.x:.3f},{mxv.y:.3f},{mxv.z:.3f})")
open(os.path.join(OUT, "hanging_sign_parts.txt"), "w", encoding="utf-8").write("\n".join(lines) + "\n")
print("\n".join(lines))

for o in objs:
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "dalgona_hanging_sign.glb"), export_format="GLB", use_selection=True)

# ───────── 미리 보기 ─────────
cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
scene.collection.objects.link(cam)
scene.camera = cam
cam.data.lens = 50
cam.location = Vector((17, -6.5, 2.0))
tgt = Vector((0, -2.8, 0.9))
cam.rotation_euler = (tgt - cam.location).to_track_quat("-Z", "Y").to_euler()
sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
sun.data.energy = 3
sun.rotation_euler = (math.radians(55), math.radians(15), math.radians(70))
scene.collection.objects.link(sun)
wall = link(bpy.data.meshes.new("wall"), "Wall")
bm = bmesh.new()
bmesh.ops.create_cube(bm, size=1)
bmesh.ops.scale(bm, vec=Vector((10, 0.4, 16)), verts=bm.verts)
bmesh.ops.translate(bm, vec=Vector((-2, 0.2, 0)), verts=bm.verts)
bm.to_mesh(wall.data)
bm.free()
wm = bpy.data.materials.new("wall")
wm.diffuse_color = (0.85, 0.78, 0.68, 1)
wm.use_nodes = True
wm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.75, 0.62, 0.5, 1)
wall.data.materials.append(wm)
world = bpy.data.worlds.new("w")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.55, 0.7, 0.9, 1)
scene.world = world
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 700, 1000
scene.view_settings.view_transform = "Standard"
scene.render.filepath = os.path.join(OUT, "hanging_sign_preview.png")
bpy.ops.render.render(write_still=True)
print("[sign] done")
