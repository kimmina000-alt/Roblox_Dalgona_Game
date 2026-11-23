# 아늑한 파스텔 그림체 공용 도구 (cozy_factory·cozy_stage23와 같은 방식, 2026-11-25 cozy_market부터 모듈로 뺌)
#   부품(Part) = bmesh 하나 = Roblox MeshPart 하나. 면마다 팔레트 칸 번호 → 8×8 팔레트 텍스처 한 장 공용.
#   모서리 3단 둥글게(box bev), 평평한 면은 평평하게(set_sharp_from_angle 35°).
# 쓰는 법: sys.path에 이 폴더 넣고 `from cozy_kit import *`, 부품을 만든 뒤 finish(OUT, 이름, notes_header)
import math
import os

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

I4 = Matrix.Identity(4)
GRID = 8
PALETTE, PIDX = [], {}
P, NOTES = {}, {}
_rng = np.random.default_rng(7)


def C(rgb):
    key = tuple(int(v) for v in rgb)
    if key not in PIDX:
        PIDX[key] = len(PALETTE)
        PALETTE.append(key)
        assert len(PALETTE) <= GRID * GRID, "팔레트 64색 넘음"
    return PIDX[key]


def palette_image(name):
    cell = 16
    size = cell * GRID
    arr = np.ones((size, size, 3))
    for i, rgb in enumerate(PALETTE):
        cx, cy = i % GRID, i // GRID
        arr[cy * cell:(cy + 1) * cell, cx * cell:(cx + 1) * cell] = np.array(rgb) / 255 + _rng.normal(0, 0.005, (cell, cell, 1))
    img = bpy.data.images.new(name, size, size, alpha=False)
    rgba = np.ones((size, size, 4), dtype=np.float32)
    rgba[:, :, :3] = np.clip(arr, 0, 1) ** 2.2
    img.pixels.foreach_set(rgba.ravel())
    img.pack()
    return img


def rot(x=0, y=0, z=0):
    return Matrix.Rotation(math.radians(z), 4, "Z") @ Matrix.Rotation(math.radians(y), 4, "Y") @ Matrix.Rotation(math.radians(x), 4, "X")


class Part:
    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.col = self.bm.faces.layers.int.new("col")

    def paint(self, rgb):
        idx = C(rgb) + 1
        for f in self.bm.faces:
            if f[self.col] == 0:
                f[self.col] = idx


def part(name, note):
    if name not in P:
        P[name] = Part(name)
        NOTES[name] = note
    return P[name]


def V(v):
    return Vector(v)


def box(p, c, size, rgb, bev=None, seg=3, m=I4):
    if bev is None:
        bev = min(min(size) * 0.18, 0.12)
    res = bmesh.ops.create_cube(p.bm, size=1.0, matrix=Matrix.Translation(V(c)) @ m @ Matrix.Diagonal((*size, 1)))
    if bev > 0:
        vs = res["verts"]
        es = list({e for v in vs for e in v.link_edges})
        bmesh.ops.bevel(p.bm, geom=vs + es, offset=bev, offset_type="OFFSET", segments=seg, profile=0.5, affect="EDGES", clamp_overlap=True)
    p.paint(rgb)


def quad(p, corners, rgb):
    """평평한 사각형 하나 (바닥 무늬·글자판). corners = 시계 반대 4점."""
    vs = [p.bm.verts.new(V(c)) for c in corners]
    p.bm.faces.new(vs)
    p.paint(rgb)


def ball(p, c, r, rgb, seg=(12, 8), m=I4):
    r = (r, r, r) if isinstance(r, (int, float)) else r
    bmesh.ops.create_uvsphere(p.bm, u_segments=seg[0], v_segments=seg[1], radius=1.0,
                              matrix=Matrix.Translation(V(c)) @ m @ Matrix.Diagonal((*r, 1)))
    p.paint(rgb)


def cyl(p, a, b, r0, r1, rgb, seg=12):
    a, b = V(a), V(b)
    d = b - a
    R = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    bmesh.ops.create_cone(p.bm, cap_ends=True, cap_tris=False, segments=seg, radius1=r0, radius2=r1, depth=d.length,
                          matrix=Matrix.Translation((a + b) / 2) @ R)
    p.paint(rgb)


def lathe(p, prof, rgb, seg=16, c=(0, 0, 0), m=I4):
    M = Matrix.Translation(V(c)) @ m
    rings = []
    for (r, z) in prof:
        rings.append([p.bm.verts.new(M @ Vector((math.cos(2 * math.pi * k / seg) * r, math.sin(2 * math.pi * k / seg) * r, z))) for k in range(seg)])
    faces = []
    for A, B in zip(rings, rings[1:]):
        for k in range(seg):
            k2 = (k + 1) % seg
            faces.append(p.bm.faces.new((A[k], A[k2], B[k2], B[k])))
    bmesh.ops.remove_doubles(p.bm, verts=[v for r in rings for v in r], dist=1e-5)
    faces = [f for f in faces if f.is_valid]
    bmesh.ops.recalc_face_normals(p.bm, faces=faces)
    p.paint(rgb)


def flat_shape(p, c, pts, h, rgb, m=I4):
    """2D 다각형(pts, 시계 반대)을 h만큼 세운 판. 가운데 점으로 부채꼴."""
    M = Matrix.Translation(V(c)) @ m
    top = [p.bm.verts.new(M @ Vector((x, y, h))) for x, y in pts]
    bot = [p.bm.verts.new(M @ Vector((x, y, 0))) for x, y in pts]
    cx = sum(x for x, _ in pts) / len(pts)
    cy = sum(y for _, y in pts) / len(pts)
    ct = p.bm.verts.new(M @ Vector((cx, cy, h)))
    cb = p.bm.verts.new(M @ Vector((cx, cy, 0)))
    faces = []
    n = len(pts)
    for k in range(n):
        k2 = (k + 1) % n
        faces.append(p.bm.faces.new((ct, top[k], top[k2])))
        faces.append(p.bm.faces.new((cb, bot[k2], bot[k])))
        faces.append(p.bm.faces.new((bot[k], bot[k2], top[k2], top[k])))
    bmesh.ops.recalc_face_normals(p.bm, faces=faces)
    p.paint(rgb)


def star_pts(R, n=5, inner=0.45):
    return [(math.cos(math.pi / 2 + k * math.pi / n) * (R if k % 2 == 0 else R * inner),
             math.sin(math.pi / 2 + k * math.pi / n) * (R if k % 2 == 0 else R * inner)) for k in range(2 * n)]


def heart_pts(R):
    pts = []
    for k in range(24):
        t = 2 * math.pi * k / 24
        x = 16 * math.sin(t) ** 3
        y = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        pts.append((x / 17 * R, y / 17 * R))
    return pts


def poly_pts(R, n, a0=90):
    return [(math.cos(math.radians(a0) + 2 * math.pi * k / n) * R, math.sin(math.radians(a0) + 2 * math.pi * k / n) * R) for k in range(n)]


def arc_tube(p, pts, r, rgb, seg=8):
    """점 목록을 따라 가는 관 (손잡이·고리). 마디마다 원기둥."""
    for a, b in zip(pts, pts[1:]):
        cyl(p, a, b, r, r, rgb, seg=seg)


FONT = r"C:\Windows\Fonts\malgunbd.ttf"
HIDDEN = {"MarketSpot", "MarketDoor", "MarketCounter", "MarketOwner", "OrderSeat"}  # 투명 판정 부품 (미리 보기에서 숨김)


def text(p, s, c, size, depth, rgb, m=I4):
    """글자 판 (말굽 고딕 굵은체). 글자 가운데 = c, 글자 면은 m의 XY 평면, 두께 방향 m의 +Z."""
    cu = bpy.data.curves.new("t", "FONT")
    cu.body = s
    cu.font = bpy.data.fonts.load(FONT, check_existing=True)
    cu.size = size
    cu.resolution_u = 5
    o = bpy.data.objects.new("t", cu)
    bpy.context.scene.collection.objects.link(o)
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(o.evaluated_get(dg))
    bpy.data.objects.remove(o, do_unlink=True)
    xs = [v.co.x for v in me.vertices]
    ys = [v.co.y for v in me.vertices]
    mx, my = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
    bm = bmesh.new()
    bm.from_mesh(me)
    bpy.data.meshes.remove(me)
    M = Matrix.Translation(V(c)) @ m
    for v in bm.verts:
        v.co = M @ Vector((v.co.x - mx, v.co.y - my, 0))
    bm.normal_update()
    ext = bmesh.ops.extrude_face_region(bm, geom=list(bm.faces))
    nv = [g for g in ext["geom"] if isinstance(g, bmesh.types.BMVert)]
    bmesh.ops.translate(bm, verts=nv, vec=m.to_3x3() @ Vector((0, 0, depth)))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    tmp = bpy.data.meshes.new("tt")
    bm.to_mesh(tmp)
    bm.free()
    n0 = len(p.bm.faces)
    p.bm.from_mesh(tmp)
    bpy.data.meshes.remove(tmp)
    p.bm.faces.ensure_lookup_table()
    p.paint(rgb)
    return len(p.bm.faces) - n0


def finish(out, base, header):
    """부품 → 오브젝트(팔레트 재질) → glb + 부품 표. 반환 = 오브젝트 목록."""
    img = palette_image(base + "Palette")
    mat = bpy.data.materials.new(base + "Palette")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.7
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    rows, objs, total = [], [], 0
    for p in P.values():
        bm = p.bm
        uv = bm.loops.layers.uv.verify()
        for f in bm.faces:
            i = max(f[p.col] - 1, 0)
            u, v = ((i % GRID) + 0.5) / GRID, ((i // GRID) + 0.5) / GRID
            for l in f.loops:
                l[uv].uv = (u, v)
        bm.normal_update()
        me = bpy.data.meshes.new(p.name)
        bm.to_mesh(me)
        bm.free()
        me.shade_smooth()
        me.set_sharp_from_angle(angle=math.radians(35))
        me.materials.append(mat)
        o = bpy.data.objects.new(p.name, me)
        bpy.context.scene.collection.objects.link(o)
        objs.append(o)
        tris = sum(len(f.vertices) - 2 for f in me.polygons)
        total += tris
        lo = Vector([min(v.co[i] for v in me.vertices) for i in range(3)])
        hi = Vector([max(v.co[i] for v in me.vertices) for i in range(3)])
        c, s = (lo + hi) / 2, hi - lo
        rows.append(f"{p.name}\ttris={tris}\tsize=({s.x:.2f}, {s.z:.2f}, {s.y:.2f})\tcenter=({-c.x:.2f}, {c.z:.2f}, {c.y:.2f})\t{NOTES[p.name]}")
    rows.insert(0, header)
    rows.append(f"# 합계 삼각형 {total}. size·center = Roblox 좌표 (x, y=위, z), 1배, 원점 기준. Blender (x,y,z) → Roblox (-x, z, y).")
    with open(os.path.join(out, base + "_parts.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(rows) + "\n")
    print("\n".join(rows))
    for o in objs:
        o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=os.path.join(out, base + ".glb"), export_format="GLB", use_selection=True, export_apply=True)
    return objs


def preview(out, base, objs, cams, glass_suffix=(), lamp_suffix=(), ground=True, wall=None, res=(1400, 1000)):
    scene = bpy.context.scene
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (1.0, 0.86, 0.7, 1)
    world.node_tree.nodes["Background"].inputs["Strength"].default_value = 0.6
    scene.world = world
    if ground:
        bpy.ops.mesh.primitive_plane_add(size=120, location=(0, 0, -0.01))
        fm = bpy.data.materials.new("Ground")
        fm.use_nodes = True
        fm.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.5, 0.47, 0.44, 1)
        bpy.context.active_object.data.materials.append(fm)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 2.6
    sun.data.angle = math.radians(25)
    sun.data.color = (1.0, 0.92, 0.8)
    sun.rotation_euler = (math.radians(50), math.radians(8), math.radians(-35))
    scene.collection.objects.link(sun)
    emit = bpy.data.materials.new("Glow")
    emit.use_nodes = True
    eb = emit.node_tree.nodes["Principled BSDF"]
    eb.inputs["Base Color"].default_value = (1, 0.95, 0.85, 1)
    eb.inputs["Emission Color"].default_value = (1, 0.95, 0.85, 1)
    eb.inputs["Emission Strength"].default_value = 3
    glass = bpy.data.materials.new("GlassPrev")
    glass.use_nodes = True
    gb = glass.node_tree.nodes["Principled BSDF"]
    gb.inputs["Base Color"].default_value = (0.85, 0.95, 0.97, 1)
    gb.inputs["Alpha"].default_value = 0.22
    glass.surface_render_method = "BLENDED"
    for o in objs:
        if "_Pt_" in o.name or o.name in HIDDEN:   # 자리 표시·판정용 부품은 게임에서 투명 → 미리 보기에서도 숨김
            o.hide_render = True
        if any(o.name.endswith(s) for s in lamp_suffix):
            o.data.materials[0] = emit
        if any(o.name.endswith(s) for s in glass_suffix):
            o.data.materials[0] = glass
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    cam.data.lens = 30
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.view_settings.view_transform = "Standard"
    paths = []
    for tag, (loc, tgt, lens) in cams.items():
        cam.data.lens = lens
        cam.location = loc
        cam.rotation_euler = (Vector(tgt) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(out, f"{base}_{tag}.png")
        bpy.ops.render.render(write_still=True)
        paths.append(scene.render.filepath)
    return paths
