# 손님 NPC 교체 (2026-11-28 사용자 레퍼런스/NPC.glb): 사용자가 Tripo 원본을 리토폴로지해서 캐릭터마다 조각(머리·몸·팔2·다리2)으로 나눈 7마리.
#   곰돌은 tools/blender/gomdol.py로 이미 함. 나머지 6마리를 같은 방법으로:
#   1) 조각을 원본에 겹치고(머리 쪽 점들의 가운데로 맞춤), 원본(또는 사용자가 칠한 그림)의 색을 새 UV(1024 한 장)에 구움
#   2) 키 HEIGHT로 키우고 원점 = 두 발 가운데 바닥, 옆으로 뻗은 팔은 어깨에서 내려(A자) 걷기·먹기(X축 회전) 때 팔이 앞뒤로 흔들리게
#   3) 손님 리그 부품 <id>_Head/Body/ArmL/ArmR/LegL/LegR로 내보내고 src/shared/CustomerRig.lua의 그 id 칸을 다시 씀
#
# 실행: "D:\Blender 5.2\blender.exe" -b --factory-startup -P tools/blender/npc_customers.py -- <레퍼런스 폴더> <다운로드 폴더> <출력 폴더> [저장소 루트] [id ...]
#   레퍼런스 폴더 = NPC.glb · NPC1.glb · npc/부엉이.png 가 있는 곳, 다운로드 폴더 = Tripo 원본 glb들
# 결과: <출력>/dalgona_customers_npc.glb (손님마다 빈 노드 Customer_<id> 아래 <id>_<부품>, 손님마다 텍스처 1장),
#       <출력>/<id>_preview.png (서기·걷기·먹기)
# 좌표 = customers_ai.py·gomdol.py와 같음: 앞 = Blender -Y, Blender (x, y, z) → Roblox (-x, z, y). 왼쪽 = +X.

import math
import os
import re
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import npc_bake  # noqa: E402

argv = sys.argv[sys.argv.index("--") + 1:]
REF, DL, OUT = (os.path.abspath(a) for a in argv[:3])
REPO = os.path.abspath(argv[3]) if len(argv) > 3 and os.path.isdir(argv[3]) else None
ONLY = set(argv[4:]) if len(argv) > 4 else None
os.makedirs(OUT, exist_ok=True)
TEX = 1024

# node = NPC.glb 조각 이름의 Tripo 노드 id 앞부분, high = 색 원본, image = 색 그림을 사용자 그림으로 바꿀 때
# merge = 몸에 합칠 조각 이름 끝(꼬리 등), drop/out = 팔 내리는 각도·어깨 바깥으로 빼는 거리(stud), dark = 굽기 빈 곳 판정 밝기
# 팔: 2026-11-28 사용자 "캐릭터들 팔 확인" → 50~55°로 내리면 둥근 몸통 옆에 붙어 가려짐. 곰돌(꿀단지)처럼 40° · 어깨 0.22 바깥으로
CHARS = [
    # 부엉이: 사용자가 조각 UV에 직접 칠한 그림(npc/부엉이.png, NPC.glb에 들어 있음)을 그대로 구움. UV 없는 날개 두 장은 머리 뒤 색
    dict(id="Owl", label="부엉이", node="e13fd375", high="@self", flat=["ArmL", "ArmR"], height=3.8, drop=0, out=0.0, shoulders=False),  # 날개를 안 내려서 어깨 채우기 없음
    # 뽀글이: 곱슬 털 결이 디자인이라 흐림 1번만, 묻힌 자리 메우기는 털 결 없는 판이 생겨 끔 (2026-11-28)
    dict(id="Ppogeuli", label="뽀글이", node="6ead940e", high="624a2904-7790-493a-aba6-d2f3bde6f51f.glb", height=3.7, drop=40, out=0.22,
         clean=(12, 0.45, 1), bury=False, erase=[(0.577, 0.112, 0.014)]),  # erase = 머리 옆 빨간 점 (원본 얼룩, 사용자 표시 2026-11-28)
    dict(id="Mochi", label="설기", node="5552b582", high="2a470809-7a60-42fa-9b60-2a0058a0764f.glb", height=4.0, drop=40, out=0.22,
         cage=0.02, ray=0.08, normals=False, bury=False),  # 치마 속 면이 가까워서 광선을 길게 하거나 면 방향을 다시 잡으면 안쪽을 맞힘
    # 고등어: NPC.blend는 예전에 칠한 NPC1.png를 쓰지만 얼룩져서, 줄무늬 털·러닝셔츠·초록 츄리닝이 깔끔한 Tripo 원본으로 구움
    dict(id="Godeungeo", label="고등어 아저씨", node="5dd62282", high="72074874-0075-400e-adbc-617e296774b7.glb", height=3.8, drop=40, out=0.22),
    # 2026-11-28 원본 보고 정함: da9ebd85 = 노란 오리(병아리) → 퐁퐁이, 96fa4588 = 경찰 회색 고양이(꼬리 조각 .007은 몸) → 도토리 (이름 그대로, 사용자 확인 2026-11-28)
    # bury=False: 날개가 가슴 앞에 붙어 있던 모델이라 "묻힌 자리 메우기"를 하면 셔츠 앞 단추가 지워짐 (2026-11-28)
    dict(id="Pongpong", label="퐁퐁이", node="da9ebd85", high="dcba157d-4bdb-4326-8837-096c61c8e4df.glb", height=3.3, drop=40, out=0.22,
         cage=0.06, ray=0.2, bury=False),
    dict(id="Dotori", label="도토리", node="96fa4588", high="policeman cat 3d model.glb", merge=[".007"], height=3.7, drop=40, out=0.22),
]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def imported(path):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=path)
    return [o for o in bpy.data.objects if o not in before]


def lohi(ps):
    return Vector([min(p[i] for p in ps) for i in range(3)]), Vector([max(p[i] for p in ps) for i in range(3)])


def world_verts(o):
    return [o.matrix_world @ v.co for v in o.data.vertices]


def head_center(objs):
    ps = [p for o in objs for p in world_verts(o)]
    zmax = max(p.z for p in ps)
    top = [p for p in ps if p.z > zmax * 0.72]
    return sum(top, Vector()) / len(top)


def rbx(v):
    return (-v.x, v.z, v.y)


def v3(v):
    return "Vector3.new(%.3f, %.3f, %.3f)" % rbx(v)


def size3(sz):
    return "Vector3.new(%.3f, %.3f, %.3f)" % (sz.x, sz.z, sz.y)


# 조각들은 NPC.glb 하나에 모두 있음 → 한 번 불러 두고 캐릭터마다 복제해서 씀
npc_all = [o for o in imported(os.path.join(REF, "NPC.glb")) if o.type == "MESH"]
for o in npc_all:
    o.data.transform(o.matrix_world)
    o.matrix_world = Matrix()
    o.hide_render = True
    o.hide_set(True)

npc_names = [o.name for o in npc_all]
results = []


CAPS, add_cap = npc_bake.CAPS, npc_bake.add_cap


def build(cfg):
    cid = cfg["id"]
    pieces = [bpy.data.objects[n] for n in npc_names if cfg["node"] in n and n in bpy.data.objects]
    low = pieces  # 캐릭터마다 한 번만 씀 (합치면 사라짐)
    for o in low:
        o.hide_set(False)
        o.hide_render = False
    # 몸에 합칠 조각 (꼬리 등)
    extra = [o for o in low if any(o.name.split(".")[-1] == m.strip(".") for m in cfg.get("merge", []))]
    # 원본(색)
    hp = cfg["high"]
    if hp == "@self":
        # 조각 중 UV가 있는 것을 복제해 원본으로 (같은 자리라 겹치기 필요 없음)
        copies = []
        for o in low:
            if o.data.uv_layers:
                c = o.copy()
                c.data = o.data.copy()
                scene.collection.objects.link(c)
                copies.append(c)
        bpy.ops.object.select_all(action="DESELECT")
        for o in copies:
            o.select_set(True)
        bpy.context.view_layer.objects.active = copies[0]
        bpy.ops.object.join()
        high = bpy.context.view_layer.objects.active
        shift = Vector()
    else:
        hpath = os.path.join(REF, hp[1:]) if hp.startswith("@") else os.path.join(DL, hp)
        high = [o for o in imported(hpath) if o.type == "MESH"]
        bpy.ops.object.select_all(action="DESELECT")
        for o in high:
            o.select_set(True)
        if len(high) > 1:
            bpy.context.view_layer.objects.active = high[0]
            bpy.ops.object.join()
            high = [bpy.context.view_layer.objects.active]
        high = high[0]
        high.data.transform(high.matrix_world)
        high.matrix_world = Matrix()
        if cfg.get("image"):
            img_over = bpy.data.images.load(os.path.join(REF, cfg["image"]))
            for m in high.data.materials:
                b = m.node_tree.nodes.get("Principled BSDF")
                if b and b.inputs["Base Color"].links:
                    n = b.inputs["Base Color"].links[0].from_node
                    if n.type == "TEX_IMAGE":
                        n.image = img_over
        # 겹치기: 조각 점들을 원본 표면 가장 가까운 점 쪽으로 옮겨 가며(평행 이동) 맞춤. 앞뒤가 반대일 수 있어 0°·180° 둘 다 해 보고 가까운 쪽
        tree = BVHTree.FromObject(high, bpy.context.evaluated_depsgraph_get())
        pts = [p for o in low for p in world_verts(o)]
        pts = pts[:: max(1, len(pts) // 1500)]
        hc, lc = head_center([high]), head_center(low)
        best = None
        for ang in (0, 180):
            R = Matrix.Translation(lc) @ Matrix.Rotation(math.radians(ang), 4, "Z") @ Matrix.Translation(-lc)
            t = Vector((hc.x - lc.x, hc.y - lc.y, 0))
            err = 9
            for _ in range(12):
                acc, n, e = Vector(), 0, 0
                for p in pts:
                    q = R @ p + t
                    hit = tree.find_nearest(q, 0.3)
                    if hit[0] is not None:
                        acc += hit[0] - q
                        e += (hit[0] - q).length
                        n += 1
                if n == 0:
                    break
                t += acc / n
                err = e / n
            if not best or err < best[0]:
                best = (err, R, t, ang)
        err, R, t, ang = best
        M = Matrix.Translation(t) @ R
        for o in low:
            o.data.transform(M)
        shift = t
        print(f"[npc] {cid} 겹치기 {ang}° 평균 거리 {err:.4f}")
    # 조각 이름
    def box(o):
        return lohi(world_verts(o))
    main = [o for o in low if o not in extra]
    info = sorted(main, key=lambda o: box(o)[1].z)
    legs = sorted(info[:2], key=lambda o: sum(box(o), Vector()).x)
    rest = info[2:]
    head = max(rest, key=lambda o: box(o)[1].z)
    rest.remove(head)
    body = max(rest, key=lambda o: (box(o)[1] - box(o)[0]).length)
    rest.remove(body)
    arms = sorted(rest, key=lambda o: sum(box(o), Vector()).x)
    parts = {"Head": head, "Body": body, "ArmR": arms[0], "ArmL": arms[1], "LegR": legs[0], "LegL": legs[1]}
    if extra:
        bpy.ops.object.select_all(action="DESELECT")
        for o in extra + [body]:
            o.select_set(True)
        bpy.context.view_layer.objects.active = body
        bpy.ops.object.join()
        parts["Body"] = bpy.context.view_layer.objects.active
    order = list(parts.keys())
    for i, n in enumerate(order):
        o = parts[n]
        # 면 방향을 바깥으로 (안쪽을 보는 조각은 굽기 광선이 반대쪽 면을 맞혀 얼굴이 까맣게 나옴)
        if cfg.get("normals", True):
            bm = bmesh.new()
            bm.from_mesh(o.data)
            bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
            bm.to_mesh(o.data)
            bm.free()
        for p in o.data.polygons:
            p.use_smooth = True
        a = o.data.attributes.get("part") or o.data.attributes.new("part", "INT", "FACE")
        for p in o.data.polygons:
            a.data[p.index].value = i
        for uv in list(o.data.uv_layers):
            o.data.uv_layers.remove(uv)
    bpy.ops.object.select_all(action="DESELECT")
    for o in parts.values():
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts["Body"]
    bpy.ops.object.join()
    joined = bpy.context.view_layer.objects.active
    joined.name = cid + "Joined"
    joined.data.uv_layers.new(name="UVMap")
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    img = bpy.data.images.new(cid + "_Color", TEX, TEX)
    mat = bpy.data.materials.new(cid)
    mat.use_nodes = True
    nt = mat.node_tree
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    nt.links.new(tex.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
    nt.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.8
    nt.nodes.active = tex
    joined.data.materials.clear()
    joined.data.materials.append(mat)
    # 2026-11-28 작업 지시서(얼룩·번짐 제거): Cycles 광선 굽기 대신 npc_bake.transfer (면 방향 맞는 원본 표면 색만, 빈 곳은 같은 UV 섬 안에서 메움)
    jlo, jhi = lohi(world_verts(joined))
    base = npc_bake.cycles_bake(scene, high, joined, img, cfg.get("cage", 0.06), cfg.get("ray", 0.2))  # 얼굴은 예전 굽기 그대로
    mpath = os.path.join(OUT, cid + "_mask.png")
    got, miss = npc_bake.transfer(joined, high, img, jhi.z - jlo.z, margin=12, mask_path=mpath, part_attr="part", bury=cfg.get("bury", True),
                                     off=cfg.get("cage", 0.06), ray=cfg.get("ray", 0.2), face_part=order.index("Head"), face_base=base)
    print(f"[npc] {cid} 색 옮김 {got} 텍셀, 못 찾아 메움 {miss}")
    # 원본 그림 자체의 얼룩(허옇게 번진 줄·반점) 정리. cfg clean = (K, 당김) 또는 False
    ck = cfg.get("clean", (12, 0.6, 4))
    if ck:
        print(f"[npc] {cid} 얼룩 정리", npc_bake.clean(img, mpath, OUT, *ck, erase=cfg.get("erase", ())))
    img.filepath_raw = os.path.join(OUT, cid + "_color.png")
    img.file_format = "PNG"
    img.save()
    img.pack()
    bpy.data.objects.remove(high, do_unlink=True)

    # 크기·원점, 부품별로 나눔
    lo, hi = lohi(world_verts(joined))
    s = cfg["height"] / (hi.z - lo.z)
    joined.data.transform(Matrix.Scale(s, 4))
    src = bmesh.new()
    src.from_mesh(joined.data)
    pl = src.faces.layers.int["part"]
    leg_ix = (order.index("LegL"), order.index("LegR"))
    feet = [v.co for f in src.faces if f[pl] in leg_ix for v in f.verts]
    fx = (min(p.x for p in feet) + max(p.x for p in feet)) / 2
    fy = (min(p.y for p in feet) + max(p.y for p in feet)) / 2
    fz = min(v.co.z for v in src.verts)
    bmesh.ops.translate(src, verts=src.verts, vec=Vector((-fx, -fy, -fz)))
    uvl = src.loops.layers.uv.active
    # (예전 "까만 면 → 이웃 면 한 점 색으로 UV 모으기"는 줄무늬·번짐의 원인이라 뺌. npc_bake가 빈 곳을 섬 안에서 메움)
    head_ix = order.index("Head")
    # UV 없던 조각(부엉이 날개): 머리 뒤쪽 가운데 면의 색 한 가지로
    flat_ix = [order.index(n) for n in cfg.get("flat", [])]
    if flat_ix:
        hfaces = [f for f in src.faces if f[pl] == head_ix]
        hz = [f.calc_center_median().z for f in hfaces]
        zmid = (min(hz) + max(hz)) / 2
        back = max((f for f in hfaces if abs(f.calc_center_median().z - zmid) < (max(hz) - min(hz)) * 0.15), key=lambda f: f.calc_center_median().y)
        uvb = back.loops[0][uvl].uv.copy()
        for f in src.faces:
            if f[pl] in flat_ix:
                for l in f.loops:
                    l[uvl].uv = uvb

    root = bpy.data.objects.new("Customer_" + cid, None)
    scene.collection.objects.link(root)
    subs, verts = {}, {}
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
        subs[n] = sub
    src.free()
    bpy.data.objects.remove(joined, do_unlink=True)

    # 관절: 머리 = 목, 몸 = 엉덩이, 다리 = 위 끝 가운데, 팔 = 몸 가운데에서 양쪽 같은 거리 + out, 팔 위쪽
    hlo, hhi = lohi(verts["Head"])
    legtop = max(lohi(verts["LegL"])[1].z, lohi(verts["LegR"])[1].z)
    joints = {"Head": Vector((0, 0, hlo.z + (hhi.z - hlo.z) * 0.08)), "Body": Vector((0, 0, legtop * 0.85))}
    for n in ("LegL", "LegR"):
        a, b = lohi(verts[n])
        top = [p for p in verts[n] if p.z > b.z - (b.z - a.z) * 0.15]
        joints[n] = Vector((sum(p.x for p in top) / len(top), sum(p.y for p in top) / len(top), b.z - (b.z - a.z) * 0.12))
    bc = sum(lohi(verts["Body"]), Vector()) / 2
    aL, bL = lohi(verts["ArmL"])
    aR, bR = lohi(verts["ArmR"])
    sx = max(aL.x - bc.x, bc.x - bR.x, 0.05)
    out = cfg.get("out", 0)
    for n, (a, b), side in (("ArmL", (aL, bL), 1), ("ArmR", (aR, bR), -1)):
        joints[n] = Vector((bc.x + side * (sx + out), (a.y + b.y) / 2, (a.z + b.z) / 2 + (b.z - a.z) * 0.25))
    objs, boxes = {}, {}
    drop = cfg.get("drop", 0)
    subs_rest = {"Head": [v.co.copy() for v in subs["Body"].verts]}  # 목 이음새 크기 = 몸 윗부분 굵기
    for n in order:
        sub = subs[n]
        if n in ("ArmL", "ArmR") and out:
            bmesh.ops.translate(sub, verts=sub.verts, vec=Vector(((1 if n == "ArmL" else -1) * out, 0, 0)))
        if n in ("ArmL", "ArmR") and drop:
            j = joints[n]
            R = Matrix.Rotation(math.radians(drop if n == "ArmL" else -drop), 4, "Y")
            bmesh.ops.transform(sub, matrix=Matrix.Translation(j) @ R @ Matrix.Translation(-j), verts=sub.verts)
        if n == "Body" and cfg.get("shoulders", True):
            npc_bake.add_shoulders(sub, {"ArmL": joints["ArmL"], "ArmR": joints["ArmR"]}, {"ArmL": verts["ArmL"], "ArmR": verts["ArmR"]})
        if n in CAPS and cfg.get("caps", True):
            add_cap(sub, n, joints[n], subs_rest.get(n))
        a, b = lohi([v.co for v in sub.verts])
        c = (a + b) / 2
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
        objs[n], boxes[n] = o, (c, b - a)
    jr = joints["ArmR"]
    cr = boxes["ArmR"][0]
    hand = max((cr + v.co for v in objs["ArmR"].data.vertices), key=lambda p: (p - jr).length)
    hc_, hs = boxes["Head"]
    zs = (hc_.z - hs.z * 0.35, hc_.z - hs.z * 0.1)
    front = [hc_ + v.co for v in objs["Head"].data.vertices]
    front = [p for p in front if abs(p.x) < hs.x * 0.15 and zs[0] < p.z < zs[1]] or [hc_ + Vector((0, -hs.y / 2, 0))]
    mouth = Vector((0, min(p.y for p in front) - 0.05, sum(zs) / 2))
    tris = sum(len(o.data.polygons) for o in objs.values())
    print(f"[npc] {cid} tris {tris} shift {tuple(round(v, 3) for v in shift)}")
    return dict(cfg=cfg, root=root, objs=objs, boxes=boxes, joints=joints, hand=hand, mouth=mouth)


for cfg in CHARS:
    if ONLY and cfg["id"] not in ONLY:
        continue
    results.append(build(cfg))
for n in npc_names:
    if n in bpy.data.objects:
        bpy.data.objects.remove(bpy.data.objects[n], do_unlink=True)

# CustomerRig.lua: 그 id 칸만 다시 씀
if REPO:
    path = os.path.join(REPO, "src", "shared", "CustomerRig.lua")
    with open(path, encoding="utf-8") as f:
        text = f.read()
    for r in results:
        cid, cfg, boxes, joints = r["cfg"]["id"], r["cfg"], r["boxes"], r["joints"]
        height = max(boxes[n][0].z + boxes[n][1].z / 2 for n in boxes)
        L = [f"\t\t{cid} = {{ -- tools/blender/npc_customers.py (레퍼런스/NPC.glb, 2026-11-28)", f'\t\t\tlabel = "{cfg["label"]}",', f"\t\t\theight = {height:.3f},",
             f"\t\t\tmouth = {v3(r['mouth'])},", f"\t\t\thand = {v3(r['hand'])},", "\t\t\tparts = {"]
        for n in ("Head", "Body", "ArmL", "ArmR", "LegL", "LegR"):
            c, sz = boxes[n]
            L.append(f"\t\t\t\t{n} = {{ center = {v3(c)}, size = {size3(sz)}, joint = {v3(joints[n])} }},")
        L += ["\t\t\t},", "\t\t},"]
        block = "\n".join(L) + "\n"
        pat = re.compile(r"\t\t" + cid + r" = \{.*?\n\t\t\},\n", re.S)
        if pat.search(text):
            text = pat.sub(lambda m: block, text, count=1)
        else:
            text = text.replace("\t},\n}", block + "\t},\n}", 1)
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    print("[npc] wrote", path)

# 내보내기
bpy.ops.object.select_all(action="DESELECT")
for r in results:
    r["root"].select_set(True)
    for o in r["objs"].values():
        o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "dalgona_customers_npc.glb"), export_format="GLB", use_selection=True,
                          export_image_format="AUTO")  # PNG (JPEG는 Roblox에서 한 번 더 눌려 얼룩져 보임, 2026-11-28)

# 미리 보기: 손님마다 서기 · 걷기 · 먹기
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


POSES = [{}, {"LegL": rot(x=-28), "LegR": rot(x=26), "ArmL": rot(x=24), "ArmR": rot(x=-24)}, {"ArmR": rot(x=-110), "Head": rot(x=8)}]
# 검수용 돌려 보기 (2026-11-28 작업 지시서 "정면·측면·후면, 대기·걷기·뛰기·팔 움직임"): 앞 · 옆 · 뒤 · 크게 걷기(뛰기) · 팔 앞뒤 끝까지
TURN = [(0, {}), (90, {}), (180, {}), (0, {"LegL": rot(x=-45), "LegR": rot(x=42), "ArmL": rot(x=45), "ArmR": rot(x=-45), "Body": rot(z=6)}),
        (90, {"LegL": rot(x=-45), "LegR": rot(x=42), "ArmL": rot(x=60), "ArmR": rot(x=-110), "Head": rot(x=10)})]
SHEETS = [("_preview.png", [(0, p) for p in POSES], 1500), ("_turn.png", TURN, 2400)]
for r in results:
  for suffix, poses, resx in SHEETS:
    scene.render.resolution_x = resx
    pose_list = poses
    for o in scene.objects:
        if o.type == "MESH":
            o.hide_render = True
    made = []
    for k, (yaw, pose) in enumerate(pose_list):
        r2 = r["root"].copy()
        scene.collection.objects.link(r2)
        r2.location = ((k - (len(pose_list) - 1) / 2) * 3.2, 0, 0)
        r2.rotation_euler = (0, 0, math.radians(yaw))
        made.append(r2)
        for n, o in r["objs"].items():
            o2 = o.copy()
            scene.collection.objects.link(o2)
            o2.parent = r2
            o2.hide_render = False
            j = r["joints"][n]
            c, _ = r["boxes"][n]
            o2.matrix_basis = Matrix.Translation(j) @ pose.get(n, Matrix()) @ Matrix.Translation(c - j)
            made.append(o2)
    cam.location = (0, -15 * len(pose_list) / 3, 3.0)
    cam.rotation_euler = (Vector((0, 0, 1.8)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, r["cfg"]["id"] + suffix)
    bpy.ops.render.render(write_still=True)
    for o in made:
        bpy.data.objects.remove(o, do_unlink=True)
print("[npc] done")
