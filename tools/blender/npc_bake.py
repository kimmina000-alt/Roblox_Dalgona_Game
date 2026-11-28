# 손님 NPC 색 옮기기 (2026-11-28 사용자 "캐릭터 표면 얼룩·노이즈·색 번짐 제거" 작업 지시서).
#   예전: Cycles "selected to active" 광선 굽기 → 광선이 옆 조각(팔 속 몸통, 치마 속, 뒤통수 너머 제복)을 맞히거나 아무것도
#   못 맞혀 까맣게 나오고, 까만 면은 이웃 면 색 한 점으로 덮어서(UV를 한 점으로 모음) 줄무늬·얼룩·번짐이 생겼음.
#   지금: 낮은 메시(새 UV)의 텍셀마다 3D 점·면 방향을 구하고, 원본(Tripo) 표면에서
#     1) 면 방향 따라 바깥→안 짧은 광선, 맞힌 면 방향이 같은 쪽일 때만
#     2) 아니면 가장 가까운 점 중 면 방향이 크게 어긋나지 않는 것
#   의 원본 UV 색을 그대로 가져옴. 둘 다 없으면 비워 두고, 같은 UV 섬 안의 가장 가까운 채운 텍셀 색으로 메움(번짐 없이).
#   마지막에 섬 바깥 margin 픽셀까지 늘려 이음매 선이 안 보이게.
# 쓰는 곳: tools/blender/npc_customers.py, tools/blender/gomdol.py (from npc_bake import transfer)

import math

import bmesh
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def _image_of(mat):
    if not mat or not mat.use_nodes:
        return None
    for n in mat.node_tree.nodes:
        if n.type == "BSDF_PRINCIPLED" and n.inputs["Base Color"].links:
            src = n.inputs["Base Color"].links[0].from_node
            if src.type == "TEX_IMAGE" and src.image:
                return src.image
    for n in mat.node_tree.nodes:
        if n.type == "TEX_IMAGE" and n.image:
            return n.image
    return None


def _flat_color(mat):
    if mat and mat.use_nodes:
        for n in mat.node_tree.nodes:
            if n.type == "BSDF_PRINCIPLED":
                return np.array(n.inputs["Base Color"].default_value[:3], dtype=np.float32)
    return np.array([0.8, 0.8, 0.8], dtype=np.float32)


class _High:
    """원본 메시: 삼각형별 3점·UV·재질 그림, BVH."""

    def __init__(self, obj):
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        bm.transform(obj.matrix_world)
        bmesh.ops.triangulate(bm, faces=bm.faces[:])
        bm.faces.ensure_lookup_table()
        bm.normal_update()
        uvl = bm.loops.layers.uv.active
        self.tree = BVHTree.FromBMesh(bm)
        n = len(bm.faces)
        self.co = np.zeros((n, 3, 3), np.float64)
        self.uv = np.zeros((n, 3, 2), np.float64)
        self.mat = np.zeros(n, np.int32)
        for f in bm.faces:
            for k, l in enumerate(f.loops):
                self.co[f.index, k] = l.vert.co
                if uvl:
                    self.uv[f.index, k] = l[uvl].uv
            self.mat[f.index] = f.material_index
        bm.free()
        self.imgs, self.flat = [], []
        mats = list(obj.data.materials) or [None]
        for m in mats:
            im = _image_of(m)
            if im is not None:
                w, h = im.size
                px = np.empty(w * h * 4, np.float32)
                im.pixels.foreach_get(px)
                self.imgs.append(px.reshape(h, w, 4)[:, :, :3])
            else:
                self.imgs.append(None)
            self.flat.append(_flat_color(m))
        self.has_uv = uvl is not None

    def color(self, fi, p):
        a, b, c = self.co[fi]
        v0, v1, v2 = b - a, c - a, np.asarray(p) - a
        d00, d01, d11 = v0 @ v0, v0 @ v1, v1 @ v1
        d20, d21 = v2 @ v0, v2 @ v1
        den = d00 * d11 - d01 * d01
        if abs(den) < 1e-18:
            w = np.array([1 / 3, 1 / 3, 1 / 3])
        else:
            y = (d11 * d20 - d01 * d21) / den
            z = (d00 * d21 - d01 * d20) / den
            w = np.clip(np.array([1 - y - z, y, z]), 0, 1)
            w /= w.sum()
        mi = min(self.mat[fi], len(self.imgs) - 1)
        img = self.imgs[mi]
        if img is None or not self.has_uv:
            return self.flat[mi]
        uv = w @ self.uv[fi]
        h, wd = img.shape[:2]
        # 바둑판 반복 UV도 감기(%)로, 쌍선형 보간
        x = (uv[0] % 1.0) * wd - 0.5
        yv = (uv[1] % 1.0) * h - 0.5
        x0, y0 = int(math.floor(x)), int(math.floor(yv))
        fx, fy = x - x0, yv - y0
        x0c, x1c = x0 % wd, (x0 + 1) % wd
        y0c, y1c = y0 % h, (y0 + 1) % h
        top = img[y0c, x0c] * (1 - fx) + img[y0c, x1c] * fx
        bot = img[y1c, x0c] * (1 - fx) + img[y1c, x1c] * fx
        return top * (1 - fy) + bot * fy


def transfer(low, high, img, scale, margin=12, skip=None, mask_path=None, part_attr=None, off=None, ray=None, face_part=None, face_base=None, bury=True):
    """low(UV 있는 낮은 메시 오브젝트)의 활성 UV 위 img에, high(원본 오브젝트)의 색을 옮김.
    scale = 모델 키(같은 단위) — 광선·거리 기준. skip(face) -> True면 그 면은 건너뜀(색 칠하지 않음).
    face_base = 얼굴(face_part 조각의 앞을 보는 곳) 텍셀은 이 그림(예전 Cycles 굽기 결과, H×W×3 numpy)을 그대로 씀.
      새 방식은 눈·코 같은 얇은 겹 조각에서 엉뚱한 겹을 집어 얼굴이 깨져서, 얼굴은 예전 그대로 (표정 변경 금지).
    part_attr = 면 속성 이름(조각 번호). 주면 다른 조각 속에 묻힌 자리(원본에서 팔이 붙어 있던 어깨 등)는 원본 색을 안 가져오고
      같은 섬의 보이는 자리 색으로 메움 → 팔을 내리면 드러나는 어깨에 팔 털 색 덩어리가 안 생김.
    돌려줌: 채운 텍셀 수, 비어서 메운 텍셀 수."""
    W, H = img.size
    H_ = _High(high)
    bm = bmesh.new()
    bm.from_mesh(low.data)
    bm.transform(low.matrix_world)
    bm.normal_update()
    uvl = bm.loops.layers.uv.active
    # 조각별 BVH (다른 조각 속인지 판정)
    parts_tree = {}
    if part_attr and bury:
        pl = bm.faces.layers.int.get(part_attr)
        ids = sorted({f[pl] for f in bm.faces})
        for pid in ids:
            sub = bmesh.new()
            vm = {}
            for f in bm.faces:
                if f[pl] != pid:
                    continue
                vs = []
                for v in f.verts:
                    if v not in vm:
                        vm[v] = sub.verts.new(v.co)
                    vs.append(vm[v])
                try:
                    sub.faces.new(vs)
                except ValueError:
                    pass
            sub.normal_update()
            parts_tree[pid] = BVHTree.FromBMesh(sub)
            sub.free()
    bury = 0.012 * scale

    def buried(pid, p):
        for q, t in parts_tree.items():
            if q == pid:
                continue
            loc, hn, fi, d = t.find_nearest(p, 0.25 * scale)
            if fi is None:
                continue
            if d < bury or (p - loc).dot(hn) < 0:
                return True
        return False

    hidden = np.zeros((H, W), bool)
    front = np.zeros((H, W), bool)  # 앞(-Y)을 보는 자리: npc_clean이 작은 디테일(단추·끈·배지)을 남기는 곳
    face = np.zeros((H, W), bool)  # 머리 앞쪽 = 얼굴: npc_clean이 손대지 않음 (얼굴·표정 그대로)
    if part_attr and not bm.faces.layers.int.get(part_attr):
        part_attr = None
    plf = bm.faces.layers.int.get(part_attr) if part_attr else None
    out = np.zeros((H, W, 3), np.float32)
    have = np.zeros((H, W), bool)  # 색을 찾은 텍셀
    cover = np.zeros((H, W), np.int32)  # 섬 번호+1 (0 = 섬 밖)
    # off·ray = 예전 굽기의 cage_extrusion·max_ray_distance (손님마다 맞춘 값, 원본 단위). 없으면 키 비율
    off = off if off is not None else 0.02 * scale
    ray = ray if ray is not None else 0.07 * scale
    near = max(0.08 * scale, ray)
    # UV 섬 번호 (UV 이음매 기준으로 이어진 면들)
    island = {}
    cur = 0
    for f0 in bm.faces:
        if f0.index in island:
            continue
        cur += 1
        stack = [f0]
        island[f0.index] = cur
        while stack:
            f = stack.pop()
            for l in f.loops:
                e = l.edge
                for g in e.link_faces:
                    if g.index in island:
                        continue
                    # 같은 UV를 쓰는 이음매만 이어짐
                    lg = [x for x in g.loops if x.edge == e]
                    if not lg:
                        continue
                    lg = lg[0]
                    a1, a2 = l[uvl].uv, l.link_loop_next[uvl].uv
                    b1, b2 = lg[uvl].uv, lg.link_loop_next[uvl].uv
                    if ((a1 - b2).length < 1e-5 and (a2 - b1).length < 1e-5) or ((a1 - b1).length < 1e-5 and (a2 - b2).length < 1e-5):
                        island[g.index] = cur
                        stack.append(g)
    filled = missed = 0
    tris = bm.calc_loop_triangles()
    for tri in tris:
        f = tri[0].face
        if skip and skip(f):
            continue
        uvs = [Vector((l[uvl].uv.x * W, l[uvl].uv.y * H)) for l in tri]
        cos = [l.vert.co for l in tri]
        nos = [l.vert.normal if f.smooth else f.normal for l in tri]
        xs, ys = [u.x for u in uvs], [u.y for u in uvs]
        x0, x1 = max(0, int(math.floor(min(xs)))), min(W - 1, int(math.ceil(max(xs))))
        y0, y1 = max(0, int(math.floor(min(ys)))), min(H - 1, int(math.ceil(max(ys))))
        a, b, c = uvs
        den = (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
        if abs(den) < 1e-12:
            continue
        isl = island.get(f.index, 0)
        for py in range(y0, y1 + 1):
            for px in range(x0, x1 + 1):
                cx, cy = px + 0.5, py + 0.5
                w0 = ((b.y - c.y) * (cx - c.x) + (c.x - b.x) * (cy - c.y)) / den
                w1 = ((c.y - a.y) * (cx - c.x) + (a.x - c.x) * (cy - c.y)) / den
                w2 = 1 - w0 - w1
                if min(w0, w1, w2) < -0.02:  # 삼각형 밖 (가장자리 텍셀은 조금 넉넉히)
                    continue
                if have[py, px]:
                    continue
                cover[py, px] = isl
                p = cos[0] * w0 + cos[1] * w1 + cos[2] * w2
                n = (nos[0] * w0 + nos[1] * w1 + nos[2] * w2)
                if n.length < 1e-9:
                    n = f.normal
                n = n.normalized()
                if n.y < -0.3:
                    front[py, px] = True
                    if n.y < -0.55 and face_part is not None and plf is not None and f[plf] == face_part:
                        face[py, px] = True
                        if face_base is not None:
                            out[py, px] = face_base[py, px]
                            have[py, px] = True
                            filled += 1
                            continue
                if parts_tree and buried(f[pl], p):
                    hidden[py, px] = True
                    continue
                col = None
                loc, hn, fi, d = H_.tree.ray_cast(p + n * off, -n, off + ray)
                if fi is not None and hn.dot(n) > 0.15:
                    col = H_.color(fi, loc)
                if col is None:
                    loc, hn, fi, d = H_.tree.ray_cast(p + n * (off + ray), -n, off + ray)  # 원본이 더 바깥에 있을 때
                    if fi is not None and hn.dot(n) > 0.15:
                        col = H_.color(fi, loc)
                if col is None:
                    loc, hn, fi, d = H_.tree.find_nearest(p, near)
                    if fi is not None and hn.dot(n) > -0.1:
                        col = H_.color(fi, loc)
                if col is not None:
                    out[py, px] = col
                    have[py, px] = True
                    filled += 1
                else:
                    missed += 1
    # 빈 텍셀: 같은 섬 안의 채운 텍셀에서 번져 들어오게 (섬 밖 색은 안 씀)
    out, have = _grow(out, have, cover, inside=True)
    # 섬 전체가 묻혀 있어 메울 색이 없던 텍셀은 원본 색으로 (다시 한 번, 묻힘 무시)
    if parts_tree and (hidden & ~have).any():
        _fill_hidden(bm, uvl, H_, out, have, hidden, W, H, off, ray, near)
        out, have = _grow(out, have, cover, inside=True)
    # 섬 바깥 margin: 이음매에서 밉맵이 섞여도 같은 색이 나오게
    out, _ = _grow(out, have, None, inside=False, steps=margin)
    bm.free()
    rgba = np.ones((H, W, 4), np.float32)
    rgba[:, :, :3] = np.clip(out, 0, 1)
    img.pixels.foreach_set(rgba.ravel())
    img.update()
    if mask_path:  # UV 섬 자리 (npc_clean.py가 섬 안만 정리하고 섬 밖은 늘려 채움)
        m = bpy.data.images.new("mask_tmp", W, H)
        mk = np.ones((H, W, 4), np.float32)
        mk[:, :, 0] = cover > 0
        mk[:, :, 1] = front
        mk[:, :, 2] = face
        m.pixels.foreach_set(mk.ravel())
        m.filepath_raw = mask_path
        m.file_format = "PNG"
        m.save()
        bpy.data.images.remove(m)
    return filled, missed


def clean(img, mask_path, tmp_dir, k=12, pull=0.6, iters=4, erase=()):
    """npc_clean.py(시스템 파이썬 + OpenCV)로 얼룩 정리 후 img에 다시 넣음. 실패하면 그대로 두고 False."""
    import os
    import subprocess

    here = os.path.dirname(os.path.abspath(__file__))
    a = os.path.join(tmp_dir, img.name + "_raw.png")
    b = os.path.join(tmp_dir, img.name + "_clean.png")
    img.filepath_raw = a
    img.file_format = "PNG"
    img.save()
    r = subprocess.run(["python", os.path.join(here, "npc_clean.py"), a, mask_path, b, str(k), str(pull), str(iters)] + ["%g,%g,%g" % e for e in erase], capture_output=True,
                       encoding="utf-8", errors="replace", env=dict(os.environ, PYTHONIOENCODING="utf-8"))
    print((r.stdout or "").strip(), (r.stderr or "").strip()[-500:])
    if r.returncode != 0 or not os.path.exists(b):
        return False
    c = bpy.data.images.load(b)
    px = np.empty(len(img.pixels), np.float32)
    c.pixels.foreach_get(px)
    img.pixels.foreach_set(px)
    img.update()
    bpy.data.images.remove(c)
    return True


def _fill_hidden(bm, uvl, H_, out, have, hidden, W, H, off, ray, near):
    for tri in bm.calc_loop_triangles():
        f = tri[0].face
        uvs = [Vector((l[uvl].uv.x * W, l[uvl].uv.y * H)) for l in tri]
        a, b, c = uvs
        den = (b.y - c.y) * (a.x - c.x) + (c.x - b.x) * (a.y - c.y)
        if abs(den) < 1e-12:
            continue
        x0, x1 = max(0, int(min(u.x for u in uvs))), min(W - 1, int(max(u.x for u in uvs)) + 1)
        y0, y1 = max(0, int(min(u.y for u in uvs))), min(H - 1, int(max(u.y for u in uvs)) + 1)
        if not (hidden[y0:y1 + 1, x0:x1 + 1] & ~have[y0:y1 + 1, x0:x1 + 1]).any():
            continue
        for py in range(y0, y1 + 1):
            for px in range(x0, x1 + 1):
                if have[py, px] or not hidden[py, px]:
                    continue
                cx, cy = px + 0.5, py + 0.5
                w0 = ((b.y - c.y) * (cx - c.x) + (c.x - b.x) * (cy - c.y)) / den
                w1 = ((c.y - a.y) * (cx - c.x) + (a.x - c.x) * (cy - c.y)) / den
                w2 = 1 - w0 - w1
                if min(w0, w1, w2) < -0.02:
                    continue
                p = tri[0].vert.co * w0 + tri[1].vert.co * w1 + tri[2].vert.co * w2
                loc, hn, fi, d = H_.tree.find_nearest(p, near * 3)
                if fi is not None:
                    out[py, px] = H_.color(fi, loc)
                    have[py, px] = True


def _grow(out, have, cover, inside, steps=4096):
    """채운 텍셀에서 4방향으로 한 칸씩 번지기. inside면 같은 섬(cover 값이 같은 곳)으로만."""
    out = out.copy()
    have = have.copy()
    for _ in range(steps):
        if inside:
            need = (cover > 0) & ~have
        else:
            need = ~have
        if not need.any():
            break
        acc = np.zeros_like(out)
        cnt = np.zeros(have.shape, np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sh = np.roll(have, (dy, dx), (0, 1))
            so = np.roll(out, (dy, dx), (0, 1))
            ok = sh & need
            if inside:
                ok &= np.roll(cover, (dy, dx), (0, 1)) == cover
            acc[ok] += so[ok]
            cnt[ok] += 1
        new = cnt > 0
        if not new.any():
            break
        out[new] = acc[new] / cnt[new][:, None]
        have |= new
    return out, have


# 관절 이음새 (2026-11-28 작업 지시서 "어깨·팔 관절, 움직일 때 메시가 벌어지거나 끊어지는 현상"):
#   손님은 조각 6개를 관절 점에서 돌리는 리그라 팔을 흔들거나 머리를 숙이면 조각 사이가 벌어져 속이 보임.
#   팔·머리 조각에 관절 점을 가운데로 한 둥근 이음새(타원 공)를 붙여, 돌아가도 그 자리를 메움. 색 = 그 조각에서 가장 가까운 점의 UV.
CAPS = {"ArmL": 0.36, "ArmR": 0.36, "Head": 0.30}


def add_cap(sub, name, joint, rest=None):
    uvl = sub.loops.layers.uv.active
    vs = [v.co.copy() for v in sub.verts]
    if not vs:
        return
    # 크기: 팔 = 관절 가까운 점들의 굵기, 머리 = 몸 윗부분 굵기
    if name == "Head" and rest:
        top = max(p.z for p in rest)
        ring = [p for p in rest if p.z > top - 0.25] or rest
        w = min(max(p.x for p in ring) - min(p.x for p in ring), max(p.y for p in ring) - min(p.y for p in ring))
        r = w * CAPS[name]
        rz = r * 0.9
        center = joint + Vector((0, 0, -rz * 0.35))
    else:
        near = sorted(vs, key=lambda p: (p - joint).length)[: max(12, len(vs) // 8)]
        rad = sum((p - joint).length for p in near) / len(near)
        r = max(0.08, rad * CAPS[name] * 2)
        rz = r
        center = joint
    # UV: 조각 점마다 가장 가까운 loop UV
    pts, uvs = [], []
    for f in sub.faces:
        for l in f.loops:
            pts.append(l.vert.co.copy())
            uvs.append(l[uvl].uv.copy())
    if not pts:
        return
    bm2 = bmesh.new()
    bmesh.ops.create_uvsphere(bm2, u_segments=14, v_segments=8, radius=1.0)
    off = len(sub.verts)
    newv = {}
    for v in bm2.verts:
        p = center + Vector((v.co.x * r, v.co.y * r, v.co.z * rz))
        newv[v] = sub.verts.new(p)
    for f in bm2.faces:
        try:
            nf = sub.faces.new([newv[v] for v in f.verts])
        except ValueError:
            continue
        nf.smooth = True
        for l in nf.loops:
            q = l.vert.co
            k = min(range(len(pts)), key=lambda i: (pts[i] - q).length_squared)
            l[uvl].uv = uvs[k]
    bm2.free()


def cycles_bake(scene, high, low, img, cage, ray):
    """예전 방식 Cycles 굽기 (얼굴용 face_base). 돌려줌: H×W×3 numpy."""
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 4
    scene.cycles.device = "CPU"
    scene.render.bake.use_selected_to_active = True
    scene.render.bake.cage_extrusion = cage
    scene.render.bake.max_ray_distance = ray
    scene.render.bake.margin = 6
    bpy.ops.object.select_all(action="DESELECT")
    high.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"})
    W, H = img.size
    px = np.empty(W * H * 4, np.float32)
    img.pixels.foreach_get(px)
    return px.reshape(H, W, 4)[:, :, :3].copy()
