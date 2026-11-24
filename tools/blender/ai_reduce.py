# 고폴리 AI 모델(삼각형 수십만·4K 텍스처) → 삼각형 target개 + 새 UV + 원본 색을 텍스처 한 장(기본 1024)에 굽기.
#   그냥 줄이기만 하면 UV 이음새가 어긋나 흰 줄이 생겨서, 줄인 메시에 UV를 새로 펴고 원본에서 색을 구움 (Cycles bake).
#   키를 height(stud)로 맞추고 원점 = 바닥 가운데. 노멀·거칠기 텍스처는 버림 (가볍게).
# 실행: "D:\Blender 5.2lender.exe" -b --factory-startup -P tools/blender/ai_reduce.py -- <원본.glb> <id> <키> <삼각형 수> <출력 폴더> [텍스처 크기]
# 결과: <출력>/<id>_low.glb  (손님 7종: tools/blender/customers_ai.py 가 이어서 부품으로 나눔)
import bpy, sys, os, bmesh
from mathutils import Vector
argv = sys.argv[sys.argv.index("--") + 1:]
src, cid, height, target, out = argv[0], argv[1], float(argv[2]), int(argv[3]), argv[4]
RES = int(argv[5]) if len(argv) > 5 else 1024
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
bpy.ops.import_scene.gltf(filepath=src)
H = [x for x in sc.objects if x.type == "MESH"][0]
for x in sc.objects: x.select_set(x == H)
bpy.context.view_layer.objects.active = H
bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
before = sum(len(p.vertices) - 2 for p in H.data.polygons)
# 낮은 폴리 복사본
L = H.copy(); L.data = H.data.copy(); L.name = L.data.name = cid
sc.collection.objects.link(L)
for x in sc.objects: x.select_set(x == L)
bpy.context.view_layer.objects.active = L
m = L.modifiers.new("D", "DECIMATE"); m.ratio = target / before; m.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier="D")
after = sum(len(p.vertices) - 2 for p in L.data.polygons)
while L.data.uv_layers: L.data.uv_layers.remove(L.data.uv_layers[0])
L.data.uv_layers.new(name="UVMap")
bpy.ops.object.mode_set(mode="EDIT"); bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=1.15, island_margin=0.004)
bpy.ops.uv.pack_islands(margin=0.004)
bpy.ops.object.mode_set(mode="OBJECT")
img = bpy.data.images.new(cid + "_color", RES, RES)
mat = bpy.data.materials.new(cid)
mat.use_nodes = True
nt = mat.node_tree; bsdf = nt.nodes["Principled BSDF"]
bsdf.inputs["Roughness"].default_value = 0.8
tn = nt.nodes.new("ShaderNodeTexImage"); tn.image = img; nt.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
nt.nodes.active = tn
L.data.materials.clear(); L.data.materials.append(mat)
# 굽기 (고폴리 색 → 저폴리)
sc.render.engine = "CYCLES"; sc.cycles.samples = 1; sc.cycles.device = "CPU"
for x in sc.objects: x.select_set(x in (H, L))
bpy.context.view_layer.objects.active = L
size = max(L.dimensions)
bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, use_selected_to_active=True, cage_extrusion=size * 0.02, max_ray_distance=size * 0.06, margin=8)
img.pack()
bpy.data.objects.remove(H, do_unlink=True)
# 키 맞추고 원점 = 두 발 가운데 바닥
ws = [v.co for v in L.data.vertices]
lo = Vector([min(w[k] for w in ws) for k in range(3)]); hi = Vector([max(w[k] for w in ws) for k in range(3)])
k = height / (hi.z - lo.z)
for v in L.data.vertices:
    v.co = Vector(((v.co.x - (lo.x + hi.x) / 2) * k, (v.co.y - (lo.y + hi.y) / 2) * k, (v.co.z - lo.z) * k))
for p in L.data.polygons: p.use_smooth = True
for x in sc.objects: x.select_set(x == L)
bpy.ops.export_scene.gltf(filepath=os.path.join(out, cid + "_low.glb"), export_format="GLB", use_selection=True, export_image_format="JPEG", export_jpeg_quality=90)
print("DONE", cid, before, "->", after, "size", os.path.getsize(os.path.join(out, cid + "_low.glb")))
