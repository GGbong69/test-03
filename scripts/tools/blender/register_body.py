# 금전등록기 몸체 — Blender(bpy)로 짓고 glb 로 내보낸다 (2026-10-16 「블렌더 깔았으니까 활용해봐」).
#
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup \
#       --python scripts/tools/blender/register_body.py -- [--preview 그림.png]
#
# 움직이지 않는 몸만 여기서 짓는다 — 서랍(Drawer) · 건반(Keys) · 값 깃(Flags) · 값 창 유리는 게임(room3d.gd
# _register_prop)이 짓고 움직인다. 좌표는 등록기 안쪽 단위 그대로다: 게임의 (u, h, w) = Blender 의 (x, z, −y)
# (glTF 가 Z-up 을 Y-up 으로 돌린다 · 앞(w +)이 Blender −y). 재질은 이름만 붙인다(brass · bronze · wood ·
# wood_dk · patina · ink) — 게임이 이름으로 제 재질을 끼운다(빛 · 반사 · prop_glow 가 그 재질을 민다).
# 화면에서 등록기는 한 단위가 2~3px 이다 — 1 단위보다 가는 무늬는 안 보이므로 돋을새김 · 테는 1 단위 언저리로 둔다.
import bpy
import bmesh
import math
import os
import sys
from mathutils import Vector, Matrix

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "assets", "models", "register_body.glb")

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIEW = argv[argv.index("--preview") + 1] if "--preview" in argv else ""

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

MATS = {}


def mat(name, col):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*col, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.45
    if name in ("brass", "bronze", "patina"):
        bsdf.inputs["Metallic"].default_value = 0.85
    MATS[name] = m
    return m


# 미리보기 빛깔(게임은 이름으로 제 재질을 쓴다)
BRASS = mat("brass", (0.80, 0.55, 0.18))
BRONZE = mat("bronze", (0.30, 0.17, 0.07))
WOOD = mat("wood", (0.33, 0.17, 0.08))
WOOD_DK = mat("wood_dk", (0.20, 0.10, 0.05))
PATINA = mat("patina", (0.25, 0.30, 0.18))
INK = mat("ink", (0.05, 0.04, 0.04))


def G(u, h, w):
    """게임 좌표 → Blender 좌표"""
    return Vector((u, -w, h))


def link(ob, m):
    bpy.context.collection.objects.link(ob)
    if m is not None:
        ob.data.materials.append(m)
    return ob


def box(name, size, at, m, bevel=0.0, seg=2):
    """size (u, h, w) · at 가운데(게임 좌표)"""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector((size[0], size[2], size[1])), verts=bm.verts)
    bmesh.ops.translate(bm, vec=G(*at), verts=bm.verts)
    if bevel > 0.0:
        bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=bevel, segments=seg,
                        affect="EDGES", profile=0.5)
    bm.to_mesh(me)
    bm.free()
    return link(bpy.data.objects.new(name, me), m)


def lathe(name, prof, at, m, seg=16, axis="h", arc=math.tau):
    """prof: [(반지름, 높이)] — 축을 따라 돌린 회전체. axis h(위) 또는 w(앞)"""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    vs = [bm.verts.new(Vector((r, 0.0, z))) for r, z in prof]
    for a, b in zip(vs, vs[1:]):
        bm.edges.new((a, b))
    bmesh.ops.spin(bm, geom=bm.verts[:] + bm.edges[:], cent=Vector((0, 0, 0)), axis=Vector((0, 0, 1)),
                   angle=arc, steps=seg, use_merge=arc >= math.tau - 1e-4)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
    if axis == "w":
        # 축 z → 앞(Blender −y)
        bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector((0, 0, 0)),
                         matrix=Matrix.Rotation(math.radians(90.0), 3, "X"))
    bmesh.ops.translate(bm, vec=G(*at), verts=bm.verts)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new(name, me), m)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def tube(name, pts, r, m, closed=False, res=6):
    """게임 좌표 꺾은선을 따라 둥근 관(소용돌이 · 테) — 곡선에 굵기를 주어 메시로"""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = 2
    cu.resolution_u = res
    sp = cu.splines.new("BEZIER")
    sp.bezier_points.add(len(pts) - 1)
    for bp, p in zip(sp.bezier_points, pts):
        bp.co = G(*p)
        bp.handle_left_type = bp.handle_right_type = "AUTO"
    sp.use_cyclic_u = closed
    ob = bpy.data.objects.new(name, cu)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(m)
    return ob


def scroll(cx, cy, r0, turns, side, plane="front", w=0.0, u=0.0, h=0.0, rr=0.45, m=None, n=18, flip=1.0):
    """소용돌이(C 스크롤) — 판 위에 돋을새김. plane front 는 (u, h) 평면(앞 w) · side 는 (w, h) 평면(옆 u)"""
    pts = []
    for i in range(n + 1):
        t = i / n
        a = flip * (turns * math.tau * t) + math.pi * 0.5
        r = r0 * (1.0 - 0.72 * t)
        x = cx + r * math.cos(a)
        y = cy + r * math.sin(a)
        if plane == "front":
            pts.append((x, y, w))
        else:
            pts.append((u, y, x))
    return tube("scroll", pts, rr, m or BRASS)


# ── 서랍장(나무) — u ±20 · h 0..10 · w −8.5..11.5 ─────────────────────
box("case", (40.0, 10.0, 20.0), (0.0, 5.0, 1.5), WOOD, bevel=0.6)
# 받침(굽 단) · 그 위 쇠시리(ogee — 두 단)
box("plinth", (42.0, 1.4, 22.0), (0.0, 0.7, 1.5), WOOD_DK, bevel=0.45)
box("plinth2", (41.0, 0.8, 21.0), (0.0, 1.7, 1.5), WOOD, bevel=0.35)
# 굽 — 네 귀의 둥근 발(카운터에 닿는 데는 받침이 먼저다 · 발은 받침 밖으로 조금만 나온다)
for su in (-1.0, 1.0):
    for sw in (-8.0, 11.0):
        lathe("foot", [(0.0, 0.0), (1.9, 0.0), (2.2, 0.5), (1.9, 1.1), (1.2, 1.4), (0.0, 1.4)],
              (su * 19.6, 0.0, sw), WOOD_DK, seg=12)
# 옆판 짜임 — 틀(테) 안에 한 단 들어간 판
for su in (-1.0, 1.0):
    x = su * 20.05
    box("side_rail_t", (0.5, 1.2, 18.0), (x, 8.6, 1.5), WOOD_DK, bevel=0.2)
    box("side_rail_b", (0.5, 1.2, 18.0), (x, 3.2, 1.5), WOOD_DK, bevel=0.2)
    box("side_stile_f", (0.5, 6.6, 1.2), (x, 5.9, 10.0), WOOD_DK, bevel=0.2)
    box("side_stile_b", (0.5, 6.6, 1.2), (x, 5.9, -7.0), WOOD_DK, bevel=0.2)
# 윗 테(놋쇠 줄무늬 띠) · 앞 모서리 놋쇠 갓
box("case_band", (41.0, 0.9, 21.0), (0.0, 10.35, 1.5), BRASS, bevel=0.3)
for su in (-1.0, 1.0):
    box("corner", (2.4, 9.6, 1.4), (su * 19.4, 5.4, 11.7), BRASS, bevel=0.4)
    # 갓 위 · 아래 작은 꽃 단추
    lathe("rosette", [(0.0, 0.0), (0.9, 0.0), (0.9, 0.3), (0.5, 0.7), (0.0, 0.8)],
          (su * 19.4, 8.6, 12.4), BRASS, seg=10, axis="w")

# ── 몸통(청동 주물) — u ±18 · h 10.8..31 · w −8.5..0.5 ───────────────
box("body", (36.0, 20.2, 9.0), (0.0, 20.9, -4.0), BRONZE, bevel=1.1, seg=3)
# 옆판 돋을새김 — 테 하나 + 소용돌이 넷(옆면 평면)
for su in (-1.0, 1.0):
    x = su * 18.15
    tube("side_frame", [(x, 13.0, -7.0), (x, 29.0, -7.0), (x, 29.0, -0.8), (x, 13.0, -0.8)],
         0.35, BRASS, closed=True, res=2)
    for (cy, fl) in ((25.0, 1.0), (17.0, -1.0)):
        scroll(-3.9, cy, 2.6, 0.9, "side", plane="side", u=x, m=BRASS, rr=0.32, flip=fl)
    lathe("side_boss", [(0.0, 0.0), (1.1, 0.0), (1.0, 0.4), (0.4, 0.8), (0.0, 0.85)],
          (x, 21.0, -3.9), BRASS, seg=10)
# 앞 기둥 둘 — 깎은 놋쇠(구슬 · 허리)
PIL = [(1.8, 0.0), (1.8, 0.9), (1.3, 1.3), (1.1, 1.8), (1.4, 2.6), (1.1, 3.4), (1.0, 16.6), (1.4, 17.4),
       (1.1, 18.2), (1.3, 18.9), (1.8, 19.3), (1.8, 20.2), (0.0, 20.2)]
for su in (-1.0, 1.0):
    lathe("pillar", PIL, (su * 17.4, 10.8, -0.2), BRASS, seg=12)
# 윗 처마 — 두 단(놋쇠 띠 · 그 위 나무 쇠시리)
box("cornice", (37.8, 1.4, 10.4), (0.0, 31.6, -4.0), BRASS, bevel=0.45)
box("cornice2", (36.4, 0.9, 9.4), (0.0, 32.65, -4.0), BRONZE, bevel=0.35)

# ── 건반판(기운 면) · 놋쇠 테 — KEY_B0 (−16.2, 11, 10.5) · KEY_B3 (−16.2, 29, 0.5) ─────
b0 = (-16.2, 11.0, 10.5)
b3 = (-16.2, 29.0, 0.5)
me = bpy.data.meshes.new("slope")
bm = bmesh.new()
q = [bm.verts.new(G(*p)) for p in (b0, (16.2, 11.0, 10.5), (16.2, 29.0, 0.5), b3)]
bm.faces.new(q)
bm.to_mesh(me)
bm.free()
link(bpy.data.objects.new("slope", me), mat("slope", (0.12, 0.07, 0.03)))
nrm = Vector((0.0, -18.0, 10.0)).normalized()     # 게임 KEY_N (0, 10, 18) → Blender (0, −18, 10)
for a, b in ((b0, (16.2, 11.0, 10.5)), ((16.2, 11.0, 10.5), (16.2, 29.0, 0.5)),
             ((16.2, 29.0, 0.5), b3), (b3, b0)):
    pa = G(*a) + nrm * 0.35
    pb = G(*b) + nrm * 0.35
    cu = bpy.data.curves.new("slope_rim", "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = 0.55
    cu.bevel_resolution = 1
    sp = cu.splines.new("POLY")
    sp.points.add(1)
    sp.points[0].co = (*pa, 1.0)
    sp.points[1].co = (*pb, 1.0)
    ob = bpy.data.objects.new("slope_rim", cu)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(BRASS)

# ── 값 창 틀 — u ±15 · h 32.4..45 · w −7.5..−3.5 (안 유리 · 깃은 게임) ──────────
box("win_bot", (31.0, 1.8, 4.2), (0.0, 33.25, -5.5), BRASS, bevel=0.5)
box("win_top", (31.0, 1.8, 4.2), (0.0, 44.15, -5.5), BRASS, bevel=0.5)
for su in (-1.0, 1.0):
    box("win_side", (3.0, 9.6, 4.2), (su * 13.5, 38.7, -5.5), BRASS, bevel=0.5)
    # (창 옆 귀 소용돌이는 화면에서 삐죽한 더듬이로 읽혀 걷었다 — 2026-10-16 찍어 봤다)
# 창 아래 띠(앞 청동판) — 가운데 돋을새김 소용돌이 한 쌍
box("fascia", (34.0, 2.4, 1.0), (0.0, 31.9, 0.9), BRONZE, bevel=0.35)

# ── 볏 — 반원 아치(투각 소용돌이) · 가운데 꽃 · 꼭지 ─────────────────────
# 아치 겉 테(반원)
arc_pts = []
for i in range(17):
    a = math.pi * i / 16
    arc_pts.append((math.cos(a) * 11.0, 45.0 + math.sin(a) * 9.5, -5.5))
tube("crest_rim", arc_pts, 0.9, BRASS, res=4)
inner = []
for i in range(13):
    a = math.pi * i / 12
    inner.append((math.cos(a) * 6.6, 45.0 + math.sin(a) * 5.6, -5.5))
tube("crest_in", inner, 0.55, BRASS, res=4)
# 아치 밑 가로대
box("crest_base", (23.0, 1.6, 2.6), (0.0, 45.7, -5.5), BRASS, bevel=0.45)
# 투각 — 겉 테와 속 테 사이에 소용돌이 여섯(좌우 거울)
for su in (-1.0, 1.0):
    for k, (r, a0) in enumerate(((2.0, 25.0), (1.9, 70.0), (1.8, 115.0))):
        a = math.radians(a0 if su > 0 else 180.0 - a0)
        cx = math.cos(a) * 8.7
        cy = 45.0 + math.sin(a) * 7.5
        scroll(cx, cy, r, 0.8, "front", w=-5.5, m=BRASS, rr=0.42, flip=su)
# 가운데 바탕(녹) 반원 · 꽃(혹)
lathe("crest_field", [(0.0, -0.5), (6.2, -0.5), (6.2, 0.5), (0.0, 0.5)], (0.0, 45.0, -6.0), PATINA,
      seg=16, axis="w", arc=math.pi)
lathe("crest_boss", [(0.0, 0.0), (2.6, 0.0), (2.4, 0.6), (1.6, 1.4), (0.6, 1.8), (0.0, 1.9)],
      (0.0, 48.2, -5.6), BRASS, seg=14, axis="w")
for k in range(8):
    a = math.tau * k / 8
    lathe("petal", [(0.0, 0.0), (0.7, 0.0), (0.5, 0.5), (0.0, 0.6)],
          (math.cos(a) * 3.0, 48.2 + math.sin(a) * 3.0, -5.4), BRASS, seg=8, axis="w")
# 꼭지 — 아치 꼭대기(h 54.5)에서 위로
lathe("finial", [(1.6, 0.0), (1.9, 0.8), (1.4, 1.6), (2.3, 2.6), (1.9, 3.5), (1.0, 4.0), (0.6, 4.6), (0.0, 4.8)],
      (0.0, 54.2, -5.5), BRASS, seg=14)

# ── 옆 손잡이 — 오른 옆구리 축 · 비스듬한 자루 · 나무 알 ─────────────────
lathe("crank_hub", [(0.0, 0.0), (3.0, 0.0), (3.0, 0.8), (2.2, 1.6), (0.0, 1.8)],
      (18.4, 21.0, -4.0), BRASS, seg=14)
tube("crank_arm", [(19.6, 21.0, -4.0), (21.6, 17.6, -4.0), (23.4, 13.4, -4.0)], 0.85, BRASS, res=4)
lathe("crank_knob", [(0.0, 0.0), (1.4, 0.6), (2.1, 1.8), (2.0, 3.0), (1.2, 3.8), (0.0, 4.0)],
      (23.6, 9.4, -4.0), WOOD_DK, seg=12)

# ── 한 몸으로 합치고 내보낸다 ───────────────────────────────────────────
for ob in list(bpy.context.collection.objects):
    if ob.type == "CURVE":
        bpy.context.view_layer.objects.active = ob
        ob.select_set(True)
        bpy.ops.object.convert(target="MESH")
        ob.select_set(False)
obs = [o for o in bpy.context.collection.objects if o.type == "MESH"]
for o in obs:
    o.select_set(True)
bpy.context.view_layer.objects.active = obs[0]
bpy.ops.object.join()
body = bpy.context.view_layer.objects.active
body.name = "RegisterBody"
# 매끈함은 각 30° 로 가른다 — 모서리는 서고 회전체 · 관은 둥글다
try:
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(30.0))
except Exception:
    bpy.ops.object.shade_smooth()
print("tris", sum(len(p.vertices) - 2 for p in body.data.polygons))

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True,
                          export_yup=True, export_animations=False, export_cameras=False, export_lights=False)
print("wrote", OUT)

if PREVIEW:
    # 게임 진열대 카메라 — 직교 · 앞에서 52° 내려다본다
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 75.0
    cam.rotation_euler = (math.radians(52.0), 0.0, 0.0)
    cam.location = Vector((0.0, -120.0, 28.0)) + Vector((0.0, -math.cos(math.radians(52.0)) * 0, 0.0))
    d = Vector((0.0, math.sin(math.radians(52.0)), -math.cos(math.radians(52.0))))
    target = Vector((0.0, -1.5, 26.0))
    cam.location = target - d * 150.0
    scene.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(40.0), math.radians(-25.0), math.radians(20.0))
    scene.collection.objects.link(sun)
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 480
    scene.render.resolution_y = 480
    scene.render.film_transparent = False
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.08, 0.06, 0.09, 1.0)
    scene.world = w
    scene.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
    print("preview", PREVIEW)
