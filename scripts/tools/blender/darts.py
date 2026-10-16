# 다트 네 자루 — Blender(bpy)로 짓고 glb 하나로 내보낸다 (2026-10-16 「다트들의 외형을 새로 디자인」).
#
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup \
#       --python scripts/tools/blender/darts.py -- [--preview 그림.png]
#
#   표준   경기용 다트 — 바늘 촉 · 홈 판 배럴 · 쇠 고리 단 샤프트 · 십자 날개(인쇄)
#   무거운 쿠나이 — 곧게 벌어진 마름모 날(가운데 등날) · 촘촘히 감은 짧은 자루 · 굵은 고리
#   가벼운 종이비행기 다트 — 가는 바늘 · 쥠 테 · 접은 종이 날개 둘(살짝 V) · 코에 겹친 세모 깃 · 밑 용골
#   자석   말굽 자석 — 강철 극 띠 · 빨간 막대 배럴 · 네모 단면 말굽 U · 강철 극 캡
#
# 좌표 — 온 길이 1 · s 는 촉 0 → 꽁지 1 · Blender z = s − 0.5(게임 자루 로컬 +Y 가 꽁지 · 촉 끝이 −0.5).
# 납작한 표식(쿠나이 날 · 고리 · 비행기 날개 · 말굽)은 Blender XZ 평면에 눕히고 낯은 −y 를 본다 — 게임에서
# 그 낯이 로컬 +Z 이고 _dart3_face_u 가 그쪽을 눈으로 돌린다(glTF 가 Z-up → Y-up · Blender −y = 게임 +Z).
#
# 재질은 이름만 — 「램프_단[_m]」. 게임(_dart3_meshes)이 이 이름으로 네 단 램프 칠(_dart3_toon)을 고른다.
#   body  이 자루 몸 램프 · 단은 몸 단에 더한다      fin   날개 단(크림만 몸보다 한 단 아래)에 더한다
#   print 날개 단 + 인쇄(테 · 띠 — DART3_FORM std 날개 줄 그대로 · UV 가 그 줄의 몫)
#   그 밖  그 램프 그 단 그대로(steel · dusk · night · cream)        _m  쇠(광택 문턱)
# 오브젝트 하나 = 재질 하나 — 이름이 「종류_번호」. 면은 평평한 법선(네 단 램프가 마디에서 딱 갈린다) ·
# 관(고리 · 끈)만 매끈하다.
import bpy
import bmesh
import math
import os
import sys
from mathutils import Vector, Matrix

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "assets", "models", "darts.glb")

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIEW = argv[argv.index("--preview") + 1] if "--preview" in argv else ""

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# 미리보기 빛깔(게임은 이름으로 제 칠을 쓴다)
PREV = {"steel": (0.55, 0.58, 0.65), "dusk": (0.30, 0.26, 0.38), "night": (0.08, 0.07, 0.12),
        "cream": (0.80, 0.76, 0.66)}
MATS = {}


def mat(name):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*PREV.get(name.split("_")[0], (0.7, 0.7, 0.7)), 1.0)
    bsdf.inputs["Roughness"].default_value = 0.4
    if name.endswith("_m"):
        bsdf.inputs["Metallic"].default_value = 0.85
    MATS[name] = m
    return m


def Z(s):
    return s - 0.5


def finish(name, bm, m, smooth=False, weld=True):
    if weld:
        bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    ob.data.materials.append(mat(m))
    for p in ob.data.polygons:
        p.use_smooth = smooth
    return ob


def lathe(name, rows, m, seg=12, grooves=(), cap=True):
    """rows: [(s, 반지름)] — z 축 둘레 회전체. 홈 자리마다 V 를 판다(그 자리 반지름의 다섯에 하나 · 앞뒤 0.008)."""
    def w(s):
        for (s0, r0), (s1, r1) in zip(rows, rows[1:]):
            if s0 <= s <= s1:
                return r0 if s1 - s0 < 1e-9 else r0 + (r1 - r0) * (s - s0) / (s1 - s0)
        return 0.0
    pts = list(rows)
    for g in grooves:
        pts += [(g - 0.008, w(g - 0.008)), (g, w(g) * 0.8), (g + 0.008, w(g + 0.008))]
    pts.sort(key=lambda q: q[0])
    bm = bmesh.new()
    rings = []
    for s, r in pts:
        rings.append([bm.verts.new((r * math.cos(math.tau * j / seg), r * math.sin(math.tau * j / seg), Z(s)))
                      for j in range(seg)])
    for a, b in zip(rings, rings[1:]):
        for j in range(seg):
            j1 = (j + 1) % seg
            bm.faces.new((a[j], a[j1], b[j1], b[j]))
    if cap:
        for ring in (rings[0], rings[-1]):
            if ring[0].co.xy.length > 1e-7:
                bm.faces.new(ring)
    return finish(name, bm, m)


def loft(name, stations, m_of, smooth=False):
    """stations: [(s, [(x, y) …])] — 같은 수의 단면을 이어 붙인다. m_of(k) 는 단면 변 k 의 재질 이름.
    재질마다 따로 오브젝트로 낸다(오브젝트 하나 = 재질 하나)."""
    n = len(stations[0][1])
    groups = {}
    for k in range(n):
        groups.setdefault(m_of(k), []).append(k)
    out = []
    for mname, ks in groups.items():
        bm = bmesh.new()
        rings = [[bm.verts.new((x, y, Z(s))) for x, y in sec] for s, sec in stations]
        for a, b in zip(rings, rings[1:]):
            for k in ks:
                k1 = (k + 1) % n
                q = [a[k], a[k1], b[k1], b[k]]
                if len({v.co.to_tuple(7) for v in q}) >= 3:
                    try:
                        bm.faces.new(q if len({v.co.to_tuple(7) for v in q}) == 4 else
                                     [v for i, v in enumerate(q) if v.co.to_tuple(7) not in
                                      {u.co.to_tuple(7) for u in q[:i]}])
                    except ValueError:
                        pass
        # 끝 마개 — 점으로 모이지 않은 끝만(첫 재질 몫)
        if mname == m_of(0):
            for ring in (rings[0], rings[-1]):
                if len({v.co.to_tuple(6) for v in ring}) == n:
                    bm.faces.new(ring)
        out.append(finish("%s_%s" % (name, mname), bm, mname, smooth))
    return out


def sweep(name, path, sec, m, closed=False, smooth=True, up=Vector((0.0, -1.0, 0.0))):
    """path: Blender 점 줄 · sec: [(a, b)] 단면(a = 길 옆 · b = up 쪽). up 은 단면의 b 축이 가리킬 쪽."""
    bm = bmesh.new()
    n = len(path)
    rings = []
    for i in range(n):
        if closed:
            t = path[(i + 1) % n] - path[i - 1]
        else:
            t = path[min(i + 1, n - 1)] - path[max(i - 1, 0)]
        t.normalize()
        b = up - t * up.dot(t)
        if b.length < 1e-6:
            b = Vector((1.0, 0.0, 0.0)) - t * t.x
        b.normalize()
        a = t.cross(b)
        rings.append([bm.verts.new(path[i] + a * u + b * v) for u, v in sec])
    k = len(sec)
    pairs = list(zip(rings, rings[1:])) + ([(rings[-1], rings[0])] if closed else [])
    for r0, r1 in pairs:
        for j in range(k):
            j1 = (j + 1) % k
            bm.faces.new((r0[j], r0[j1], r1[j1], r1[j]))
    if not closed:
        bm.faces.new(rings[0])
        bm.faces.new(rings[-1])
    return finish(name, bm, m, smooth)


def circle(r, n=8):
    return [(r * math.cos(math.tau * j / n), r * math.sin(math.tau * j / n)) for j in range(n)]


def plate(name, outline, thick, m, plane="xz", uv=None, rot_z=0.0):
    """outline: [(가로, s)] 볼록 다각형 — plane xz 면 가로가 x(낯 −y) · yz 면 가로가 y. 두께 thick 만큼 판.
    uv(가로, s) → (u, v) 이면 그 UV 를 단다(앞 · 뒤 낯 같은 값). rot_z 는 z 축 둘레로 돌리는 각(도)."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap") if uv else None
    h = thick * 0.5

    def P(c, s, d):
        return Vector((c, d, Z(s))) if plane == "xz" else Vector((d, c, Z(s)))
    front = [bm.verts.new(P(c, s, -h)) for c, s in outline]
    back = [bm.verts.new(P(c, s, h)) for c, s in outline]
    bm.verts.index_update()
    faces = [bm.faces.new(front), bm.faces.new(list(reversed(back)))]
    n = len(outline)
    for i in range(n):
        i1 = (i + 1) % n
        faces.append(bm.faces.new((front[i], back[i], back[i1], front[i1])))
    if uv:
        for f in faces:
            for lp in f.loops:
                vi = lp.vert.index % n
                lp[uvl].uv = uv(*outline[vi])
    if rot_z:
        bmesh.ops.rotate(bm, verts=bm.verts[:], cent=Vector((0, 0, 0)),
                         matrix=Matrix.Rotation(math.radians(rot_z), 3, "Z"))
    return finish(name, bm, m)


def prism(name, tris, thick, m):
    """세모마다 y 로 두께를 준 얇은 판(종이) — 세모끼리 안 붙인다(겹친 옆벽이 안 생긴다)."""
    bm = bmesh.new()
    h = Vector((0.0, thick * 0.5, 0.0))
    for a, b, c in tris:
        f = [bm.verts.new(p - h) for p in (a, b, c)]
        k = [bm.verts.new(p + h) for p in (a, b, c)]
        bm.faces.new(f)
        bm.faces.new(list(reversed(k)))
        for i in range(3):
            i1 = (i + 1) % 3
            bm.faces.new((f[i], k[i], k[i1], f[i1]))
    return finish(name, bm, m, weld=False)


# ══ 표준 — 경기용 다트 ══════════════════════════════════════════
# 비율은 2D(DK_PARTS std)와 옛 선반 자루 그대로 — 촉 0~0.245 · 배럴 0.245~0.54 · 목 0.54~0.70 · 날개 0.64~1.0.
# 라이벌 손이 쥐는 자리(RIVAL.grip s 0.39)가 배럴 한가운데다. 홈은 다섯(링 그립) · 샤프트 끝에 쇠 고리 하나.
lathe("std_tip", [(0.0, 0.0), (0.03, 0.0035), (0.22, 0.0065), (0.245, 0.0075)], "steel_2_m", seg=8)
lathe("std_barrel", [(0.245, 0.0075), (0.25, 0.011), (0.268, 0.020), (0.285, 0.022), (0.50, 0.022),
                     (0.525, 0.017), (0.54, 0.009)], "body_0_m", seg=12,
      grooves=(0.32, 0.355, 0.39, 0.425, 0.46))
lathe("std_shaft", [(0.54, 0.0085), (0.665, 0.0085)], "dusk_1", seg=8)
lathe("std_ring", [(0.665, 0.0085), (0.668, 0.0115), (0.70, 0.0115), (0.70, 0.0)], "steel_2_m", seg=8)
# 날개 — 곧은 앞변 · 평평한 뒤끝 방패꼴 판 두 장을 십자로. 줄은 DART3_FORM std 의 fin 과 같다(인쇄가 그 줄로 구워진다).
FIN = [(0.64, 0.0085), (0.90, 0.078), (1.0, 0.078)]
FW = 0.078
fin_out = [(-r, s) for s, r in reversed(FIN)] + [(r, s) for s, r in FIN]


def fin_uv(c, s):
    return ((c / FW + 1.0) * 0.5, (s - FIN[0][0]) / (FIN[-1][0] - FIN[0][0]))


plate("std_fin_a", fin_out, 0.0025, "print_0", "xz", fin_uv)
plate("std_fin_b", fin_out, 0.0025, "print_0", "yz", fin_uv)

# ══ 무거운 — 쿠나이 ════════════════════════════════════════════
# 비율은 사용자가 준 쿠나이 사진(2026-10-16)을 잰 값 — 날이 온 길이의 0.69 · 자루 0.69~0.885 · 고리 끝 1.0.
# 날은 촉에서 곧게 벌어져 s 0.58 에서 가장 넓고(반폭 0.072) 짧게 오므라들어 자루로 들어간다(코등 없음).
# 단면은 마름모 — 가운데 등날이 앞뒤로 서서 낯마다 두 면이 다른 단을 받는다. 자루는 촘촘히 감은 끈(고리
# 마디 열둘). 통에 꽂히면 s 0.6 밑이 잠기므로 통에서는 날 어깨 · 감은 자루 · 고리가 쿠나이를 말한다.
# (첫 안은 글로 된 치수만 보고 날 0.42 · 자루 0.42 의 잎꼴로 지어 자루가 너무 길었다.)
LEAF = [(0.0, 0.0), (0.58, 0.072), (0.64, 0.050), (0.69, 0.027)]


def blade_sec(w):
    t = 0.003 + 0.35 * w
    return [(w, 0.0), (0.0, -t), (-w, 0.0), (0.0, t)]


loft("hvy_blade", [(s, blade_sec(w)) for s, w in LEAF], lambda k: "body_0_m")


def oval(a, b, n=8):
    return [(a * math.cos(math.tau * j / n), b * math.sin(math.tau * j / n)) for j in range(n)]


# 감은 자루 — 마디마다 끈 한 바퀴(불룩) · 사이 골. 평평한 법선이라 마디가 한 단씩 갈려 감은 줄로 선다.
grip = [(0.685, oval(0.022, 0.017))]
NG = 12
for i in range(NG):
    s0 = 0.692 + (0.88 - 0.692) * i / NG
    s1 = 0.692 + (0.88 - 0.692) * (i + 1) / NG
    grip += [(s0, oval(0.025, 0.020)), ((s0 + s1) * 0.5, oval(0.028, 0.022)), (s1, oval(0.025, 0.020))]
grip.append((0.885, oval(0.020, 0.016)))
loft("hvy_grip", grip, lambda k: "dusk_1")
lathe("hvy_neck", [(0.882, 0.012), (0.915, 0.012)], "body_-1_m", seg=8)
# 고리 — XZ 평면의 도넛(낯이 −y). 굵은 관 · 작은 구멍. 바깥 끝이 s 0.99.
RR, RT = 0.030, 0.0115
rc = 0.99 - RR - RT
ring = [Vector((RR * math.sin(math.tau * i / 24), 0.0, Z(rc) - RR * math.cos(math.tau * i / 24))) for i in range(24)]
sweep("hvy_ring", ring, circle(RT, 8), "body_0_m", closed=True, up=Vector((0.0, -1.0, 0.0)))

# ══ 가벼운 — 종이비행기 다트 ══════════════════════════════════
# 기본 다트 종이비행기 사진(2026-10-16 이미지 검색)을 보고 지었다 — 가늘고 긴 코 · 곧은 앞변 · 평평한 뒤끝 ·
# 가운데 접힌 날개 뿌리 · 밑에 접힌 용골 · 코 쪽에 접어 겹친 세모 깃(앞변 0.55 → 뿌리 0.8 의 접힌 줄).
# 가는 바늘(0~0.30) · 초록 쥠 테가 코를 꿴다. 날개는 뿌리에서 V 10° 로 들려 두 장이 다른 단을 받고, 겹친 깃은
# 한 단 어둡다(접힌 겹). 반폭 0.13(가늘어지는 배율 vis 0.72 를 먹으면 0.094) — 0.17 은 판 위에서 칸을 가렸다.
lathe("lgt_tip", [(0.0, 0.0), (0.035, 0.0035), (0.28, 0.0055), (0.30, 0.006)], "steel_2_m", seg=8)
lathe("lgt_grip", [(0.30, 0.006), (0.31, 0.011), (0.38, 0.011), (0.40, 0.007)], "body_0_m", seg=10)
PN, PS, PD = 0.33, 0.13, math.radians(10.0)


def pw(x, s, lift=0.0):
    """날개 면 위의 점 — 가로 x 의 높이는 V(PD)를 따른다 · lift 만큼 낯 쪽으로 띄운다"""
    return Vector((x, -abs(x) * math.tan(PD) - lift, Z(s)))


def span(s):
    return PS * (s - PN) / (1.0 - PN)


wing, flap = [], []
for sd in (1.0, -1.0):
    wing.append((pw(0.0, PN), pw(0.0, 1.0), pw(PS * sd, 1.0)))
    sl, sr = PN + (1.0 - PN) * 0.55, PN + (1.0 - PN) * 0.8
    flap.append((pw(0.0, PN + 0.004, 0.0026), pw(span(sl) * 0.96 * sd, sl, 0.0026), pw(0.0, sr, 0.0026)))
prism("lgt_wing", wing, 0.0022, "fin_0")
prism("lgt_flap", flap, 0.0022, "fin_-1")
plate("lgt_keel", [(0.0, PN), (0.045, 0.55), (0.05, 1.0), (0.0, 1.0)], 0.0022, "fin_-1", "yz")

# ══ 자석 — 말굽 자석 ═════════════════════════════════════════
# 강철 극 띠(0.28~0.335) · 각진 빨간 막대 배럴 · 어두운 목 · 네모 단면 말굽 U(굽은 데 가운데 s 0.72 · 다리
# 반폭 0.040) · 강철 극 캡(0.90~1.0). 갈래 사이 틈(안쪽 반폭 0.028)은 2D 처럼 지킨다 — 메워지면 「빨간 주걱」.
lathe("mag_tip", [(0.0, 0.0), (0.03, 0.004), (0.25, 0.0065), (0.28, 0.0075)], "steel_2_m", seg=8)
lathe("mag_pole", [(0.28, 0.0075), (0.29, 0.028), (0.335, 0.028)], "steel_2_m", seg=8)
lathe("mag_bar", [(0.335, 0.028), (0.555, 0.028), (0.57, 0.016), (0.58, 0.0085)], "body_0_m", seg=8)
lathe("mag_shaft", [(0.575, 0.0085), (0.68, 0.0085), (0.68, 0.0)], "dusk_1", seg=8)
UR, UB, UP = 0.040, 0.72, 0.90
upath = [Vector((-UR, 0.0, Z(UP))), Vector((-UR, 0.0, Z(UB)))]
for i in range(1, 12):
    a = math.pi + math.pi * i / 12
    upath.append(Vector((UR * math.cos(a), 0.0, Z(UB) + UR * math.sin(a))))
upath += [Vector((UR, 0.0, Z(UB))), Vector((UR, 0.0, Z(UP)))]
SEC_U = [(0.012, 0.010), (-0.012, 0.010), (-0.012, -0.010), (0.012, -0.010)]
sweep("mag_u", upath, SEC_U, "body_0_m", smooth=False)
SEC_C = [(0.0128, 0.0108), (-0.0128, 0.0108), (-0.0128, -0.0108), (0.0128, -0.0108)]
for sd in (-1.0, 1.0):
    sweep("mag_cap", [Vector((UR * sd, 0.0, Z(UP))), Vector((UR * sd, 0.0, Z(1.0)))], SEC_C, "steel_2_m",
          smooth=False)

# ══ 내보내기 — 오브젝트 이름은 「종류_번호」 ═══════════════════════
count = {}
tris = {}
for ob in sorted(bpy.data.objects, key=lambda o: o.name):
    kind = ob.name.split("_")[0]
    count[kind] = count.get(kind, 0) + 1
    tris[kind] = tris.get(kind, 0) + sum(len(p.vertices) - 2 for p in ob.data.polygons)
    ob.name = "%s_%02d" % (kind, count[kind] - 1)
print("tris", tris)
for ob in bpy.data.objects:
    ob.select_set(True)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True,
                          export_yup=True, export_animations=False, export_cameras=False, export_lights=False)
print("wrote", OUT)

if PREVIEW:
    # 넷을 나란히 눕혀 위 비스듬히 — 날개 · 날 · 고리 낯(−y)이 눈을 본다
    for i, kind in enumerate(("std", "hvy", "lgt", "mag")):
        for ob in bpy.data.objects:
            if ob.name.startswith(kind + "_"):
                ob.rotation_euler = (0.0, math.radians(90.0), 0.0)
                ob.location = Vector((0.0, 0.0, 0.33 - i * 0.22))
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.15
    cam.location = Vector((0.0, -3.0, 0.0))
    cam.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    scene.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(60.0), math.radians(-30.0), math.radians(-20.0))
    scene.collection.objects.link(sun)
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 900
    scene.render.resolution_y = 900
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.08, 0.06, 0.09, 1.0)
    scene.world = w
    scene.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
    print("preview", PREVIEW)
