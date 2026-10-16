# 술집 안 소품 — Blender(bpy)로 짓고 glb 하나로 내보낸다 (2026-10-16 「블렌더 깔았으니까 활용해봐」).
#
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup \
#       --python scripts/tools/blender/bar_props.py -- [--preview 그림.png]
#
# 제목 문이 열리면 보이는 술집 안(door3d.gd _inside)의 소품 모양만 여기서 짓는다 — 자리 · 방향 · 크기 몫은
# 게임의 BAR 상수가 쥔다. 소품마다 한 오브젝트(이름이 곧 게임이 찾는 노드 이름)이고 다 원점에 선다:
#   Stool · StoolBack · Chair   바닥 위 한가운데(앉는 쪽이 −z · 등받이는 +z)
#   Table                       바닥 위 한가운데 · 윗면 높이 0.75
#   Lamp                        갓 밑 테 한가운데(전구 빛 자리 · 줄은 게임이 천장까지 잇는다)
#   CntNose                     카운터 윗판 앞 모서리(앞판보다 0.08 앞 · 윗면 높이) · x 는 길이 1(게임이 늘린다)
#   Tap                         카운터 윗면 위 한가운데
#   Cabinet · CabLamp           다트 장 — 판 한가운데 · 뒷벽 면
#   CabDoor                     다트 장 문짝 한가운데(바깥이 +z · 안쪽 칠판 자리는 게임이 그림을 붙인다)
# 좌표는 게임 그대로(m · x 오른쪽 · y 위 · z 앞) — Blender 로는 (x, −z, y)(glTF 가 Z-up 을 Y-up 으로 돌린다).
# 재질은 이름만 붙인다 — 게임(door3d _bar_mats)이 이름으로 안 재질(IN_SHADER · 빛 단 · 디더)을 끼운다.
# 화면에서 술집 안은 1m 가 140(뒷벽) ~ 270(앞 의자) 논리 px 다 — 1cm 가 1.4 ~ 2.7px 라 테 · 띠는 1cm 언저리로 둔다.
# 술병 · 맥주잔은 도트 그림 그대로다 — 회전체 병(꼴 넷 · 딱지 · 목 띠 · 마개)을 지어 찍어 봤더니 6~9px 폭에서 1px 빛 줄 ·
# 테 그늘이 빠져 밋밋한 플라스틱 병으로 읽혔다(2026-10-11 「너무 도트 풍이 아니야」로 그림이 된 그 자리다).
import bpy
import bmesh
import math
import os
import sys
from mathutils import Vector, Matrix

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "assets", "models", "bar_props.glb")

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIEW = argv[argv.index("--preview") + 1] if "--preview" in argv else ""

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

MATS = {}


def mat(name, col, metal=0.0):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*col, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.5
    bsdf.inputs["Metallic"].default_value = metal
    MATS[name] = m
    return m


# 미리보기 빛깔(게임은 이름으로 제 재질을 쓴다 — door3d BAR 색)
LEATHER = mat("leather", (0.34, 0.10, 0.09))
LEATHER_DK = mat("leather_dk", (0.18, 0.05, 0.05))
IRON = mat("iron", (0.12, 0.09, 0.10), 0.6)
BRASS = mat("brass", (0.66, 0.46, 0.16), 0.85)
WOOD = mat("wood", (0.37, 0.20, 0.09))
VARNISH = mat("varnish", (0.40, 0.22, 0.10))     # 니스 — 게임이 반짝을 준다(테이블 윗판 · 카운터 코)
TRIM = mat("trim", (0.54, 0.34, 0.21))
WOOD_DK = mat("wood_dk", (0.17, 0.08, 0.03))
OAK = mat("oak", (0.40, 0.24, 0.16))
ENAMEL = mat("enamel", (0.18, 0.39, 0.25))
LAMP_IN = mat("lamp_in", (0.99, 0.92, 0.63))
BULB = mat("bulb", (0.98, 0.96, 0.92))
GLOW = mat("glow", (1.0, 0.81, 0.54))
TAPS = [mat("tap0", (0.10, 0.08, 0.14)), mat("tap1", (0.55, 0.13, 0.20)), mat("tap2", (0.18, 0.39, 0.25))]

CUR = []          # 지금 짓는 소품의 조각들


def G(x, y, z):
    """게임 좌표 → Blender 좌표"""
    return Vector((x, -z, y))


def link(ob, m):
    bpy.context.collection.objects.link(ob)
    if m is not None:
        ob.data.materials.append(m)
    CUR.append(ob)
    return ob


def from_bm(name, bm, m, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new(name, me), m)
    if smooth:
        for p in ob.data.polygons:
            p.use_smooth = True
    return ob


def box(name, size, at, m, bevel=0.0, seg=1):
    """size (x, y, z) · at 가운데(게임 좌표)"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector((size[0], size[2], size[1])), verts=bm.verts)
    bmesh.ops.translate(bm, vec=G(*at), verts=bm.verts)
    if bevel > 0.0:
        bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=bevel, segments=seg,
                        affect="EDGES", profile=0.5)
    return from_bm(name, bm, m, smooth=False)


def _orient(bm, inward):
    """열린 회전체의 겉 방향을 맞춘다 — 넓이로 무게 준 법선이 축 밖(inward 면 안)을 보게."""
    s = 0.0
    for f in bm.faces:
        c = f.calc_center_median()
        rad = Vector((c.x, c.y, 0.0))
        if rad.length > 1e-6:
            s += f.normal.dot(rad.normalized()) * f.calc_area()
    if (s < 0.0) != inward:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])


def lathe(name, prof, at, m, seg=16, axis="y", arc=math.tau, a0=0.0, closed=False, inward=False):
    """prof: [(반지름, 높이)] — 축을 따라 돌린 회전체. axis y(위) · x(옆) · z(앞).
    a0 — 돌기 시작하는 각(Blender xy 평면 · 반 바퀴만 돌 때). closed — 윤곽을 고리로 닫는다(도넛)."""
    bm = bmesh.new()
    ca, sa = math.cos(a0), math.sin(a0)
    vs = [bm.verts.new(Vector((r * ca, r * sa, z))) for r, z in prof]
    for a, b in zip(vs, vs[1:]):
        bm.edges.new((a, b))
    if closed:
        bm.edges.new((vs[-1], vs[0]))
    full = arc >= math.tau - 1e-4
    bmesh.ops.spin(bm, geom=bm.verts[:] + bm.edges[:], cent=Vector((0, 0, 0)), axis=Vector((0, 0, 1)),
                   angle=arc, steps=seg, use_merge=full)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    solid = closed or (full and prof[0][0] < 1e-6 and prof[-1][0] < 1e-6)
    if solid:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        if inward:
            bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    else:
        _orient(bm, inward)
    if axis == "x":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(math.radians(90.0), 3, "Y"))
    elif axis == "z":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(math.radians(90.0), 3, "X"))
    bmesh.ops.translate(bm, vec=G(*at), verts=bm.verts)
    return from_bm(name, bm, m)


def lathe_between(name, a, b, prof, m, seg=8):
    """a → b(게임 좌표) 를 축으로 깎은 막대. prof: [(반지름, 0..1 길이 몫)]"""
    pa, pb = G(*a), G(*b)
    d = pb - pa
    L = d.length
    bm = bmesh.new()
    vs = [bm.verts.new(Vector((r, 0.0, t * L))) for r, t in prof]
    for p, q in zip(vs, vs[1:]):
        bm.edges.new((p, q))
    bmesh.ops.spin(bm, geom=bm.verts[:] + bm.edges[:], cent=Vector((0, 0, 0)), axis=Vector((0, 0, 1)),
                   angle=math.tau, steps=seg, use_merge=True)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    q = d.normalized().to_track_quat("Z", "Y")
    bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector((0, 0, 0)), matrix=q.to_matrix())
    bmesh.ops.translate(bm, vec=pa, verts=bm.verts)
    return from_bm(name, bm, m)


def rod(name, a, b, r0, r1, m, seg=8):
    return lathe_between(name, a, b, [(0.0, 0.0), (r0, 0.0), (r1, 1.0), (0.0, 1.0)], m, seg)


def torus(name, R, r, at, m, seg=24, rseg=6, axis="y"):
    prof = [(R + r * math.cos(math.tau * i / rseg), r * math.sin(math.tau * i / rseg)) for i in range(rseg)]
    return lathe(name, prof, at, m, seg=seg, axis=axis, closed=True)


def tube(name, pts, r, m, res=6, closed=False, poly=False):
    """게임 좌표 꺾은선을 따라 둥근 관 — 곡선에 굵기를 주어 메시로(합칠 때 메시로 바뀐다)"""
    cu = bpy.data.curves.new(name, "CURVE")
    cu.dimensions = "3D"
    cu.bevel_depth = r
    cu.bevel_resolution = 1
    cu.resolution_u = res
    cu.use_fill_caps = True
    if poly:
        sp = cu.splines.new("POLY")
        sp.points.add(len(pts) - 1)
        for p, c in zip(sp.points, pts):
            p.co = (*G(*c), 1.0)
    else:
        sp = cu.splines.new("BEZIER")
        sp.bezier_points.add(len(pts) - 1)
        for bp, p in zip(sp.bezier_points, pts):
            bp.co = G(*p)
            bp.handle_left_type = bp.handle_right_type = "AUTO"
    sp.use_cyclic_u = closed
    ob = bpy.data.objects.new(name, cu)
    return link(ob, m)


def loft_rect(name, loops, m, cap0=False, cap1=False, plane="xy"):
    """테 두른 판 · 쇠시리 — 모서리가 45° 로 맞물리는 사각 고리를 차례로 잇는다.
    plane xy: loops [(반 폭 x, 반 높이 y, z)] — 앞(+z)을 보는 액자 테.
    plane xz: loops [(반 폭 x, 반 깊이 z, y)] — 위를 보는 처마 · 받침. 가운데는 (0, 0)."""
    bm = bmesh.new()
    rings = []
    for hx, hy, c in loops:
        if plane == "xy":
            pts = [(-hx, -hy, c), (hx, -hy, c), (hx, hy, c), (-hx, hy, c)]
        else:
            pts = [(-hx, c, -hy), (hx, c, -hy), (hx, c, hy), (-hx, c, hy)]
        rings.append([bm.verts.new(G(*p)) for p in pts])
    for r0, r1 in zip(rings, rings[1:]):
        for i in range(4):
            j = (i + 1) % 4
            bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
    if cap0:
        bm.faces.new(rings[0])
    if cap1:
        bm.faces.new(rings[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return from_bm(name, bm, m, smooth=False)


def extrude_x(name, prof, x0, x1, m):
    """(z, y) 단면 다각형을 x0..x1 로 민다(쇠시리 · 둥근 모서리)."""
    bm = bmesh.new()
    a = [bm.verts.new(G(x0, y, z)) for z, y in prof]
    b = [bm.verts.new(G(x1, y, z)) for z, y in prof]
    n = len(prof)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(a)
    bm.faces.new(b[::-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return from_bm(name, bm, m)


def arc_pts(c, r, a0, a1, n):
    """(z, y) 평면의 호 — 쇠시리 단면용"""
    return [(c[0] + r * math.cos(a0 + (a1 - a0) * i / n), c[1] + r * math.sin(a0 + (a1 - a0) * i / n))
            for i in range(n + 1)]


def finish(name, angle=35.0):
    """지금 조각들을 한 몸으로 — 곡선은 메시로 · 매끈함은 각으로 가른다."""
    global CUR
    for ob in CUR:
        ob.select_set(False)
    for ob in CUR:
        if ob.type == "CURVE":
            bpy.context.view_layer.objects.active = ob
            ob.select_set(True)
            bpy.ops.object.convert(target="MESH")
            ob.select_set(False)
    obs = [o for o in bpy.context.collection.objects if o.type == "MESH" and o.get("done") is None]
    for o in bpy.context.collection.objects:
        o.select_set(False)
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = name
    ob.data.name = name
    ob["done"] = 1
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle))
    except Exception:
        bpy.ops.object.shade_smooth()
    ob.select_set(False)
    print(name, "tris", sum(len(p.vertices) - 2 for p in ob.data.polygons))
    CUR = []
    return ob


# ══ 의자 ═══════════════════════════════════════════════════════
def cushion(S, r):
    """둥근 가죽 방석 — 볼록한 윗면 · 둥근 어깨 · 테두리 심(파이핑) · 가운데 단추"""
    lathe("cushion", [(0.0, S + 0.040), (r * 0.40, S + 0.038), (r * 0.70, S + 0.032), (r * 0.88, S + 0.024),
                      (r * 0.96, S + 0.014), (r * 0.99, S + 0.002), (r * 0.975, S - 0.010), (r * 0.93, S - 0.018),
                      (r * 0.88, S - 0.020), (0.0, S - 0.020)], (0, 0, 0), LEATHER, seg=20)
    torus("welt", r * 0.955, 0.0055, (0.0, S + 0.019, 0.0), LEATHER_DK, seg=20, rseg=5)
    lathe("button", [(0.0, S + 0.046), (0.010, S + 0.042), (0.012, S + 0.036), (0.0, S + 0.034)],
          (0, 0, 0), LEATHER_DK, seg=8)


def bar_stool(back):
    S = 0.76
    r = 0.17
    cushion(S, r)
    #  방석 받침(짙은 나무 테) · 돌림 판(쇠)
    lathe("pan", [(0.0, S - 0.020), (r * 0.90, S - 0.020), (r * 0.91, S - 0.032), (r * 0.84, S - 0.046),
                  (0.0, S - 0.048)], (0, 0, 0), WOOD_DK, seg=16)
    lathe("swivel", [(0.0, S - 0.048), (0.075, S - 0.048), (0.075, S - 0.056), (0.050, S - 0.068),
                     (0.0, S - 0.070)], (0, 0, 0), IRON, seg=12)
    #  다리 넷 — 벌어져 선다 · 끝은 놋쇠 굽
    top_r, bot_r = 0.098, 0.185
    ring_y = 0.27
    for k in range(4):
        a = math.tau * (0.125 + 0.25 * k)
        d = (math.cos(a), math.sin(a))
        t = (top_r * d[0], S - 0.040, top_r * d[1])
        b = (bot_r * d[0], 0.016, bot_r * d[1])
        rod("leg", t, b, 0.0135, 0.011, IRON, seg=8)
        lathe("glide", [(0.0, 0.0), (0.016, 0.0), (0.017, 0.006), (0.012, 0.018), (0.0, 0.018)],
              (b[0], 0.0, b[2]), BRASS, seg=8)
    #  발 고리 — 다리가 그 높이에서 벌어진 자리
    rr = bot_r + (top_r - bot_r) * (ring_y - 0.016) / (S - 0.040 - 0.016)
    torus("footring", rr, 0.010, (0.0, ring_y, 0.0), BRASS, seg=24, rseg=6)
    if back:
        #  낮은 등받이 — 뒤(+z)로 굽은 나무 띠 · 기둥 둘 · 살 셋
        span = math.radians(110.0)
        mid = -math.pi * 0.5          # Blender −y = 게임 +z
        lathe("backband", [(0.151, S + 0.262), (0.169, S + 0.262), (0.172, S + 0.282), (0.167, S + 0.298),
                           (0.160, S + 0.302), (0.153, S + 0.296), (0.150, S + 0.280)], (0, 0, 0), WOOD, seg=12,
              arc=span, a0=mid - span * 0.5, closed=True)
        for s in (-1.0, 1.0):
            a = math.pi * 0.5 + s * span * 0.47
            rod("post", (0.135 * math.cos(a), S - 0.005, 0.135 * math.sin(a)),
                (0.160 * math.cos(a), S + 0.27, 0.160 * math.sin(a)), 0.013, 0.011, WOOD, seg=8)
        for s in (-0.5, 0.0, 0.5):
            a = math.pi * 0.5 + s * span * 0.5
            rod("spindle", (0.13 * math.cos(a), S + 0.02, 0.13 * math.sin(a)),
                (0.158 * math.cos(a), S + 0.27, 0.158 * math.sin(a)), 0.0065, 0.0065, WOOD, seg=6)


def chair():
    """술 테이블 의자 — 깎은 나무 다리 넷 · 상자 가름대 · 둥근 가죽 방석 · 살 등받이(굽은 윗살)"""
    S = 0.46
    r = 0.20
    cushion(S, r * 0.92)
    lathe("seat", [(0.0, S - 0.020), (r, S - 0.020), (r * 1.01, S - 0.032), (r * 0.98, S - 0.048),
                   (0.0, S - 0.050)], (0, 0, 0), WOOD, seg=18)
    #  깎은 다리 — 위 덩이 · 구슬 · 가늘어지는 몸 · 발
    LEG = [(0.0, 0.0), (0.019, 0.0), (0.019, 0.10), (0.024, 0.13), (0.019, 0.16), (0.017, 0.30),
           (0.015, 0.80), (0.013, 0.97), (0.015, 1.0), (0.0, 1.0)]
    legs = []
    for k in range(4):
        a = math.tau * (0.125 + 0.25 * k)
        d = (math.cos(a), math.sin(a))
        t = (0.135 * d[0], S - 0.040, 0.135 * d[1])
        b = (0.175 * d[0], 0.0, 0.175 * d[1])
        lathe_between("leg", t, b, LEG, WOOD, seg=8)
        legs.append((t, b))
    #  가름대 — 다리 사이 상자 고리(바닥에서 0.16)
    def at(i, y):
        t, b = legs[i]
        u = (t[1] - y) / (t[1] - b[1])
        return (t[0] + (b[0] - t[0]) * u, y, t[2] + (b[2] - t[2]) * u)
    for i in range(4):
        rod("stretch", at(i, 0.16), at((i + 1) % 4, 0.16), 0.009, 0.009, WOOD, seg=6)
    #  등받이 — 뒤(+z) 기둥 둘 · 굽은 윗살 · 살 셋
    span = math.radians(120.0)
    mid = -math.pi * 0.5
    lathe("crest", [(0.171, S + 0.330), (0.191, S + 0.330), (0.194, S + 0.352), (0.189, S + 0.371),
                    (0.181, S + 0.377), (0.174, S + 0.371), (0.170, S + 0.352)], (0, 0, 0), WOOD, seg=12,
          arc=span, a0=mid - span * 0.5, closed=True)
    for s in (-1.0, 1.0):
        a = math.pi * 0.5 + s * span * 0.48
        rod("post", (0.165 * math.cos(a), S - 0.02, 0.165 * math.sin(a)),
            (0.182 * math.cos(a), S + 0.36, 0.182 * math.sin(a)), 0.014, 0.012, WOOD, seg=8)
    for s in (-0.5, 0.0, 0.5):
        a = math.pi * 0.5 + s * span * 0.5
        rod("spindle", (0.16 * math.cos(a), S + 0.01, 0.16 * math.sin(a)),
            (0.181 * math.cos(a), S + 0.34, 0.181 * math.sin(a)), 0.0075, 0.0075, WOOD, seg=6)


bar_stool(False)
finish("Stool")
bar_stool(True)
finish("StoolBack")
chair()
finish("Chair")

# ══ 둥근 술 테이블 — 윗판(둥근 끝 · 밑 구슬) · 앞치마 고리 · 깎은 주물 기둥 · 휜 발 넷 ══════════
TH = 0.75
lathe("top", [(0.0, TH), (0.284, TH), (0.296, TH - 0.004), (0.300, TH - 0.012), (0.298, TH - 0.020),
              (0.290, TH - 0.026), (0.293, TH - 0.031), (0.288, TH - 0.037), (0.0, TH - 0.037)],
      (0, 0, 0), VARNISH, seg=28)
lathe("apron", [(0.0, TH - 0.037), (0.235, TH - 0.037), (0.235, TH - 0.078), (0.222, TH - 0.084),
                (0.0, TH - 0.084)], (0, 0, 0), WOOD_DK, seg=20)
lathe("column", [(0.0, TH - 0.084), (0.062, TH - 0.084), (0.062, TH - 0.096), (0.036, TH - 0.110),
                 (0.030, TH - 0.150), (0.026, 0.52), (0.034, 0.47), (0.040, 0.42), (0.034, 0.37),
                 (0.026, 0.32), (0.030, 0.27), (0.046, 0.235), (0.054, 0.20), (0.048, 0.17),
                 (0.064, 0.14), (0.072, 0.11), (0.072, 0.085), (0.0, 0.085)], (0, 0, 0), IRON, seg=14)
for k in range(4):
    a = math.tau * (0.125 + 0.25 * k)
    c, s = math.cos(a), math.sin(a)
    pts = [(0.05 * c, 0.115, 0.05 * s), (0.13 * c, 0.105, 0.13 * s), (0.215 * c, 0.065, 0.215 * s),
           (0.255 * c, 0.028, 0.255 * s)]
    tube("foot", pts, 0.017, IRON, res=4)
    lathe("pad", [(0.0, 0.0), (0.026, 0.0), (0.026, 0.008), (0.018, 0.022), (0.0, 0.026)],
          (0.262 * c, 0.0, 0.262 * s), IRON, seg=10)
finish("Table")

# ══ 펜던트 — 법랑 갓(작은 둥근 머리 · 가는 목 · 넓게 벌어진 치마 · 말아 접은 테 — 창고 등 꼴) · 안은 전구 빛 ·
#  놋쇠 소켓. 목이 굵고 키가 크면(0.09 · 0.215) 종으로 읽혔다(2026-10-16 찍어 봤다).
SHADE = [(0.020, 0.180), (0.036, 0.177), (0.050, 0.170), (0.059, 0.160), (0.063, 0.147), (0.066, 0.130),
         (0.074, 0.110), (0.090, 0.088), (0.114, 0.064), (0.141, 0.041), (0.168, 0.021), (0.188, 0.006)]
lathe("shade", SHADE, (0, 0, 0), ENAMEL, seg=20)
lathe("shade_in", [(r - 0.004, y - 0.003) for r, y in SHADE[:-1]] + [(0.184, 0.002)], (0, 0, 0), LAMP_IN,
      seg=20, inward=True)
torus("rim", 0.189, 0.0075, (0.0, 0.002, 0.0), ENAMEL, seg=20, rseg=5)
lathe("socket", [(0.0, 0.250), (0.010, 0.250), (0.012, 0.241), (0.018, 0.233), (0.020, 0.211),
                 (0.027, 0.203), (0.029, 0.191), (0.026, 0.177), (0.0, 0.177)], (0, 0, 0), BRASS, seg=12)
lathe("bulb", [(0.0, -0.022), (0.022, -0.016), (0.036, -0.002), (0.040, 0.016), (0.034, 0.036),
               (0.020, 0.052), (0.014, 0.066), (0.0, 0.068)], (0, 0, 0), BULB, seg=10)
finish("Lamp")

# ══ 카운터 윗판 앞 모서리 — 둥근 코(니스) · 밑 오목 쇠시리 · 구슬(앞판 위 테) ══════════════════
#  단면 (z, y) — 원점이 윗판 앞끝 윗면. 앞판 면은 z −0.08 이다. 길이 1(x −0.5..0.5) — 게임이 늘린다.
nose = [(-0.10, 0.0), (-0.012, 0.0)] + arc_pts((-0.012, -0.024), 0.024, math.pi * 0.5, -math.pi * 0.5, 8)[1:] + \
       [(-0.030, -0.048), (-0.10, -0.048)]
extrude_x("nose", nose, -0.5, 0.5, VARNISH)
cove = [(-0.10, -0.048), (-0.030, -0.048)] + arc_pts((-0.030, -0.074), 0.026, math.pi * 0.5, math.pi, 5)[1:] + \
       [(-0.056, -0.080)] + arc_pts((-0.064, -0.089), 0.010, math.pi * 0.25, -math.pi * 0.6, 4) + \
       [(-0.080, -0.100), (-0.10, -0.100)]
extrude_x("cove", cove, -0.5, 0.5, TRIM)
finish("CntNose", angle=40.0)

# ══ 맥주 탭 — 놋쇠 T 기둥 · 꼭지 셋(아래로 굽은 주둥이) · 빛깔 손잡이 · 물받이 ══════════════════
lathe("base", [(0.0, 0.0), (0.050, 0.0), (0.050, 0.008), (0.040, 0.016), (0.032, 0.022), (0.0, 0.022)],
      (0, 0, 0), BRASS, seg=14)
lathe("col", [(0.0, 0.02), (0.024, 0.02), (0.022, 0.05), (0.026, 0.06), (0.022, 0.07), (0.021, 0.19),
              (0.0, 0.19)], (0, 0, 0), BRASS, seg=12)
lathe("tee", [(0.0, -0.13), (0.022, -0.13), (0.026, -0.124), (0.022, -0.118), (0.021, 0.118), (0.026, 0.124),
              (0.022, 0.13), (0.0, 0.13)], (0.0, 0.205, 0.0), BRASS, seg=12, axis="x")
for i, hx in enumerate((-0.085, 0.0, 0.085)):
    tube("spout", [(hx, 0.205, 0.015), (hx, 0.205, 0.045), (hx, 0.185, 0.062), (hx, 0.158, 0.064)], 0.007, BRASS,
         res=4)
    lathe("collar", [(0.0, 0.0), (0.012, 0.0), (0.012, 0.012), (0.0, 0.012)], (hx, 0.222, 0.0), BRASS, seg=8)
    lathe("handle", [(0.0, 0.0), (0.006, 0.0), (0.010, 0.018), (0.014, 0.060), (0.015, 0.090),
                     (0.012, 0.100), (0.0, 0.102)], (hx, 0.232, 0.0), TAPS[i], seg=8)
box("tray", (0.30, 0.012, 0.10), (0.0, 0.006, 0.062), BRASS, bevel=0.004)
box("grate", (0.27, 0.004, 0.07), (0.0, 0.0125, 0.062), IRON)
finish("Tap")

# ══ 다트 장 — 테 두른 상자 · 처마 · 받침 · 뒷판(판 받침 자리) ══════════════════════════════════
HW = 0.34          # 장 반 폭(BAR.cab)
DEP = 0.11
box("back", (HW * 2 - 0.02, HW * 2 - 0.02, 0.02), (0.0, 0.0, 0.01), WOOD_DK)
#  옆판 넷 — 앞 끝에 액자 쇠시리(바깥 둥근 등 · 안쪽 한 단 들어간 턱)
for sx, sy, w, h in ((0.0, HW - 0.0175, HW * 2, 0.035), (0.0, -HW + 0.0175, HW * 2, 0.035),
                     (-HW + 0.0175, 0.0, 0.035, HW * 2), (HW - 0.0175, 0.0, 0.035, HW * 2)):
    box("side", (w, h, DEP - 0.02), (sx, sy, (DEP - 0.02) * 0.5), OAK)
loft_rect("frame", [(HW + 0.004, HW + 0.004, DEP - 0.02), (HW + 0.004, HW + 0.004, DEP - 0.008),
                    (HW - 0.006, HW - 0.006, DEP + 0.004), (HW - 0.020, HW - 0.020, DEP + 0.006),
                    (HW - 0.034, HW - 0.034, DEP - 0.002), (HW - 0.040, HW - 0.040, DEP - 0.002),
                    (HW - 0.040, HW - 0.040, DEP - 0.03)], OAK)
#  처마 — 위로 벌어진 오목 쇠시리 · 윗판 / 받침 — 밑 띠
loft_rect("crown", [(HW + 0.000, DEP * 0.5 + 0.000, HW), (HW + 0.012, DEP * 0.5 + 0.012, HW + 0.010),
                    (HW + 0.026, DEP * 0.5 + 0.026, HW + 0.024), (HW + 0.034, DEP * 0.5 + 0.034, HW + 0.030),
                    (HW + 0.034, DEP * 0.5 + 0.034, HW + 0.046), (HW + 0.026, DEP * 0.5 + 0.026, HW + 0.052)],
          OAK, cap1=True, plane="xz")
loft_rect("plinth", [(HW + 0.020, DEP * 0.5 + 0.020, -HW - 0.034), (HW + 0.020, DEP * 0.5 + 0.020, -HW - 0.012),
                     (HW + 0.010, DEP * 0.5 + 0.010, -HW - 0.004), (HW + 0.000, DEP * 0.5 + 0.000, -HW)],
          OAK, cap0=True, plane="xz")
#  위 · 아래를 장 깊이 가운데에 앉힌다(loft_rect xz 는 z 가운데 0 — 장은 z 0..DEP)
for o in CUR[-2:]:
    o.location = G(0.0, 0.0, DEP * 0.5)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=False, scale=False)
    o.select_set(False)
#  경첩 넷 — 장 양끝 앞(문짝이 매달린 자리)
for sx in (-1.0, 1.0):
    for sy in (-1.0, 1.0):
        lathe("hinge", [(0.0, -0.03), (0.007, -0.03), (0.007, 0.03), (0.0, 0.03)],
              (sx * (HW + 0.002), sy * (HW - 0.09), DEP + 0.002), BRASS, seg=8)
finish("Cabinet")

#  문짝 — 바깥(+z) 은 테 · 한 단 솟은 판 / 안쪽(−z) 은 칠판 둘레 나무 테(칠판 그림은 게임이 z −0.001 에 붙인다)
DW = HW
DH = HW * 2.0
DT = 0.025
box("leaf", (DW, DH, DT), (0.0, 0.0, DT * 0.5), OAK)
loft_rect("panel", [(DW * 0.5 - 0.035, DH * 0.5 - 0.035, DT), (DW * 0.5 - 0.050, DH * 0.5 - 0.050, DT + 0.006),
                    (DW * 0.5 - 0.060, DH * 0.5 - 0.060, DT + 0.006)], OAK, cap1=True)
loft_rect("rim_in", [(DW * 0.5, DH * 0.5, 0.0), (DW * 0.5, DH * 0.5, -0.006), (DW * 0.5 - 0.008, DH * 0.5 - 0.008, -0.010),
                     (DW * 0.5 - 0.022, DH * 0.5 - 0.022, -0.010), (DW * 0.5 - 0.026, DH * 0.5 - 0.026, -0.002),
                     (DW * 0.5 - 0.026, DH * 0.5 - 0.026, 0.0)], OAK)
finish("CabDoor")

#  그림등 — 벽 판 · 굽은 팔 · 반 원통 놋쇠 갓(끝 막이) · 갓 밑 빛 줄
LY = HW + 0.08
lathe("plate", [(0.0, 0.0), (0.030, 0.0), (0.030, 0.006), (0.024, 0.012), (0.0, 0.012)],
      (0.0, LY - 0.02, 0.0), BRASS, seg=12, axis="z")
tube("arm", [(0.0, LY - 0.02, 0.010), (0.0, LY - 0.005, 0.090), (0.0, LY + 0.020, 0.170)], 0.0075, BRASS, res=6)
span = math.radians(200.0)
lathe("hood", [(0.031, -0.15), (0.034, -0.148), (0.034, 0.148), (0.031, 0.15)], (0.0, LY + 0.02, 0.20), BRASS,
      seg=10, axis="x", arc=span, a0=math.radians(80.0))
for s in (-1.0, 1.0):
    lathe("cap", [(0.0, -0.003), (0.036, -0.003), (0.036, 0.003), (0.0, 0.003)], (s * 0.15, LY + 0.02, 0.20),
          BRASS, seg=10, axis="x", arc=span, a0=math.radians(80.0))
box("strip", (0.26, 0.006, 0.012), (0.0, LY + 0.006, 0.20), GLOW)
finish("CabLamp")

# ── 내보낸다 ────────────────────────────────────────────────────
obs = [o for o in bpy.context.collection.objects if o.get("done") is not None]
for o in bpy.context.collection.objects:
    o.select_set(o in obs)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True,
                          export_yup=True, export_animations=False, export_cameras=False, export_lights=False)
print("wrote", OUT, [o.name for o in obs])

if PREVIEW:
    #  소품을 한 줄로 벌려 세우고 술집 눈높이(조금 위)에서 찍는다
    lay = {"Stool": (-1.9, 0), "StoolBack": (-1.45, 0), "Chair": (-1.0, 0), "Table": (-0.35, 0),
           "Lamp": (0.35, 0.55), "Tap": (0.35, 0.0), "CntNose": (0.35, -0.25), "Cabinet": (1.25, 0.45),
           "CabLamp": (1.25, 0.45), "CabDoor": (1.95, 0.45)}
    for o in obs:
        dx, dy = lay.get(o.name, (0, 0))
        o.location = Vector((dx, 0.0, dy))
        if o.name == "CntNose":
            o.scale = (0.5, 1.0, 1.0)
        if o.name == "CabDoor":
            o.rotation_euler = (0.0, 0.0, math.radians(200.0))
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 4.6
    cam.rotation_euler = (math.radians(80.0), 0.0, 0.0)
    cam.location = Vector((0.0, -8.0, 0.45 + 8.0 * math.tan(math.radians(10.0))))
    scene.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(40.0), math.radians(-25.0), math.radians(20.0))
    scene.collection.objects.link(sun)
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1400
    scene.render.resolution_y = 560
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.08, 0.06, 0.09, 1.0)
    scene.world = w
    scene.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
    print("preview", PREVIEW)
