# 프롤로그 TV 더미 — Blender(bpy)로 짓고 glb 하나로 내보낸다 (2026-10-18 「게임 시작 할 때 프롤로그 …
# tv더미?가 눈에 들어오고 계속 클로즈업 되서 tv화면이 전체 화면이 되고」).
#
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup \
#       --python scripts/tools/blender/tvs.py -- [--preview 그림.png]
#
# 사용자가 준 사진(나무 장 TV 가 벽처럼 쌓인 어두운 방 · 알록달록한 휴대용 TV 벽 · 젠레스 존 제로의 TV 더미)
# 에서 꼴을 잰다. 첫 판은 테가 넓어 「tv가 아니라 전자레인지 같아」였다 — 사진 속 TV 는 **화면이 앞면의
# 대부분**이다(나무 장 TV 는 화면이 폭의 일곱에 넷 · 테는 2~5cm · 오른쪽 조작판 한 뼘). 그래서 테를 얇게,
# 화면 귀를 둥글게(브라운관 관 꼴), 유리를 볼록하게, 뒤에 관 혹을 단다.
#   TvWood     나무 장 — 왼쪽 큰 화면 · 오른쪽 조작판(채널 다이얼 · 볼륨 · 스피커 망) · 다리 넷
#   TvConsole  넓은 나무 — 위 큰 화면 · 밑 가로 스피커 띠 · 오른쪽 아래 다이얼
#   TvPort     휴대용 플라스틱 — 둥근 몸 · 큰 화면 · 오른쪽 다이얼 둘 · 위 손잡이(몸 빛깔은 게임이 칠한다)
#   TvMon      모니터 — 얇은 테 · 밑 조작 띠 · 뒤로 좁아지는 혹
#   TvBox      작은 쇠 상자 — 화면 · 오른쪽 작은 다이얼 셋
#   Speaker    짙은 통 · 검은 앞판 · 우퍼 둘 · 트위터
#   TvHero     주인공(게임 TV) — 쇳빛 장 · 꺾여 드는 화면 틀 · 손잡이 다이얼 둘 · 슬라이더 · RGB 등
#   Deck       주인공 밑 비디오 데크
# 화면 귀는 초타원 지수 n 으로 — 클수록 네모(주인공 6 · 나머지 5 언저리). 3.8 은 「tv의 테두리가 너무 둥글지
# 않아?」였다(2026-10-18 · 사용자가 준 젠레스 존 제로 런처 TV 는 귀만 둥근 네모).
# 화면 UV 는 화면 칸 그대로(0..1) — 게임이 그 위에 꺼짐 · 지지직 · 크레딧을 붙인다.
# 좌표는 게임 그대로(m · x 오른쪽 · y 위 · z 앞 — 화면이 +z) · 원점은 바닥 한가운데 · 앞면이 z 0.
# Blender 로는 (x, −z, y). 재질은 이름만 — 게임(prologue3d.gd)이 이름으로 안 재질을 끼운다:
#   wood · plastic · metal · panel · bezel · glass · knob · grille · trim · gun · cap · led_r/g/b · lcd
import bpy
import bmesh
import math
import os
import sys
from mathutils import Vector, Matrix

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "assets", "models", "tvs.glb")

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIEW = argv[argv.index("--preview") + 1] if "--preview" in argv else ""

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
MATS = {}


def mat(name, col, metal=0.0, rough=0.5):
    if name in MATS:
        return MATS[name]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*col, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    MATS[name] = m
    return m


WOOD = mat("wood", (0.30, 0.16, 0.07))
PLASTIC = mat("plastic", (0.70, 0.18, 0.14))
METAL = mat("metal", (0.55, 0.56, 0.58), 0.6)
PANEL = mat("panel", (0.16, 0.15, 0.15), 0.4)
BEZEL = mat("bezel", (0.05, 0.05, 0.06))
GLASS = mat("glass", (0.12, 0.15, 0.16), 0.0, 0.1)
KNOB = mat("knob", (0.75, 0.75, 0.72), 0.8)
GRILLE = mat("grille", (0.07, 0.06, 0.06))
TRIM = mat("trim", (0.62, 0.60, 0.55), 0.8)
GUN = mat("gun", (0.10, 0.11, 0.13), 0.5, 0.4)
CAPM = mat("cap", (0.80, 0.80, 0.78))
LEDR = mat("led_r", (0.9, 0.1, 0.1))
LEDG = mat("led_g", (0.1, 0.8, 0.2))
LEDB = mat("led_b", (0.1, 0.3, 0.9))
LCD = mat("lcd", (0.03, 0.05, 0.05))

CUR = []


def G(x, y, z):
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
    for p in ob.data.polygons:
        p.use_smooth = smooth
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
    return from_bm(name, bm, m, smooth=seg > 1)


def lathe_z(name, prof, at, m, seg=16):
    """prof [(반지름, 앞으로 나온 길이)] — 앞(+z)을 축으로 돌린 다이얼 · 콘. at 은 뿌리(게임 좌표)."""
    bm = bmesh.new()
    vs = [bm.verts.new(Vector((r, 0.0, z))) for r, z in prof]
    for a, b in zip(vs, vs[1:]):
        bm.edges.new((a, b))
    bmesh.ops.spin(bm, geom=bm.verts[:] + bm.edges[:], cent=Vector((0, 0, 0)), axis=Vector((0, 0, 1)),
                   angle=math.tau, steps=seg, use_merge=True)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(math.radians(90.0), 3, "X"))
    bmesh.ops.translate(bm, vec=G(*at), verts=bm.verts)
    return from_bm(name, bm, m)


def sq(t, n):
    """둥근 네모(초타원)의 한 점 — 반지름 1 · 각 t · n 이 작을수록 둥글다(브라운관 관은 4 언저리)."""
    c, s = math.cos(t), math.sin(t)
    return (math.copysign(abs(c) ** (2.0 / n), c), math.copysign(abs(s) ** (2.0 / n), s))


N = 48


def ring(cx, cy, hw, hh, z, n):
    return [G(cx + hw * p[0], cy + hh * p[1], z) for p in (sq(math.tau * i / N, n) for i in range(N))]


def face_front(bm):
    """면이 다 앞(+z · Blender −y)을 보게 — 게임은 뒷면을 안 그린다. 뒤집힌 세모가 빠져 뒤의 몸이 비쳤다."""
    for f in bm.faces:
        f.normal_update()
        if f.normal.y > 0.0:
            f.normal_flip()


def strip(name, rings_, m, smooth=False):
    bm = bmesh.new()
    rs = [[bm.verts.new(p) for p in r] for r in rings_]
    for a, b in zip(rs, rs[1:]):
        for i in range(N):
            j = (i + 1) % N
            bm.faces.new((a[i], a[j], b[j], b[i]))
    face_front(bm)
    return from_bm(name, bm, m, smooth)


def front_plate(name, x0, x1, y0, y1, cx, cy, hw, hh, m, n, z=0.0):
    """앞판 [x0,x1]×[y0,y1](z 0) — (cx, cy) 의 둥근 구멍. 구멍 둘레 점마다 가운데에서 쏜 빛살이 판 가장자리에
    닿는 점을 짝으로 잇고, 판 네 귀는 그 귀를 끼고 있는 두 빛살 사이에 세모로 메운다."""
    bm = bmesh.new()
    inner, outer, angs = [], [], []
    for i in range(N):
        p = sq(math.tau * i / N, n)
        ix, iy = cx + hw * p[0], cy + hh * p[1]
        dx, dy = ix - cx, iy - cy
        L = math.hypot(dx, dy)
        dx, dy = dx / L, dy / L
        ts = []
        if dx > 1e-9:
            ts.append((x1 - cx) / dx)
        if dx < -1e-9:
            ts.append((x0 - cx) / dx)
        if dy > 1e-9:
            ts.append((y1 - cy) / dy)
        if dy < -1e-9:
            ts.append((y0 - cy) / dy)
        t = min(ts)
        inner.append(bm.verts.new(G(ix, iy, z)))
        outer.append(bm.verts.new(G(cx + dx * t, cy + dy * t, z)))
        angs.append(math.atan2(dy, dx))
    for i in range(N):
        j = (i + 1) % N
        bm.faces.new((inner[i], inner[j], outer[j], outer[i]))
    for kx, ky in ((x1, y1), (x0, y1), (x0, y0), (x1, y0)):
        a = math.atan2(ky - cy, kx - cx)
        for i in range(N):
            j = (i + 1) % N
            d = (angs[j] - angs[i]) % math.tau
            if 0.0 < (a - angs[i]) % math.tau < d:
                c = bm.verts.new(G(kx, ky, z))
                bm.faces.new((outer[i], outer[j], c))
                break
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
    face_front(bm)
    return from_bm(name, bm, m, smooth=False)


def screen(cx, cy, hw, hh, z0, bulge, n, rings_n=8):
    """볼록 유리 — 가운데가 bulge 만큼 앞으로. UV 는 화면 칸 그대로(왼 아래 0,0 · 오른 위 1,1)."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    rows = []
    for k in range(1, rings_n + 1):
        r = k / rings_n
        row = []
        for i in range(N):
            p = sq(math.tau * i / N, n)
            row.append(bm.verts.new(G(cx + hw * p[0] * r, cy + hh * p[1] * r, z0 + bulge * (1.0 - r * r))))
        rows.append(row)
    c = bm.verts.new(G(cx, cy, z0 + bulge))
    for i in range(N):
        j = (i + 1) % N
        bm.faces.new((c, rows[0][i], rows[0][j]))
    for a, b in zip(rows, rows[1:]):
        for i in range(N):
            j = (i + 1) % N
            bm.faces.new((a[i], b[i], b[j], a[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    if sum(f.normal.y for f in bm.faces) > 0.0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    for f in bm.faces:
        for lp in f.loops:
            co = lp.vert.co
            lp[uvl].uv = ((co.x - (cx - hw)) / (2.0 * hw), (co.z - (cy - hh)) / (2.0 * hh))
    return from_bm("glass", bm, GLASS, smooth=True)


def tube(cx, cy, hw, hh, n=4.2, lip=0.010, deep=0.02, bulge=0.018, z0=0.0):
    """앞판 구멍(z0) → 얇은 테(bezel · 한 번 꺾여 들어간다) → 볼록 유리. 테가 얇아야 TV 다."""
    strip("bezel", [ring(cx, cy, hw, hh, z0, n), ring(cx, cy, hw - lip * 0.5, hh - lip * 0.5, z0 - deep * 0.5, n),
                    ring(cx, cy, hw - lip, hh - lip, z0 - deep, n)], BEZEL)
    screen(cx, cy, hw - lip, hh - lip, z0 - deep, bulge + deep * 0.5, n)


def slats(x0, x1, y0, y1, k, m, z=0.003, vertical=False):
    box("grille", (x1 - x0, y1 - y0, 0.004), ((x0 + x1) * 0.5, (y0 + y1) * 0.5, z - 0.002), GRILLE)
    for i in range(k):
        q = (i + 0.5) / k
        if vertical:
            box("slat", (0.004, y1 - y0, 0.006), (x0 + (x1 - x0) * q, (y0 + y1) * 0.5, z), m)
        else:
            box("slat", (x1 - x0, 0.004, 0.006), ((x0 + x1) * 0.5, y0 + (y1 - y0) * q, z), m)


def dial(x, y, r, m=KNOB, depth=0.02, ribs=False):
    lathe_z("dial", [(0.0, depth), (r * 0.82, depth), (r, depth * 0.75), (r, 0.0), (0.0, 0.0)], (x, y, 0.0), m,
            20 if not ribs else 12)
    box("tick", (0.004, r * 0.7, 0.004), (x, y + r * 0.35, depth + 0.001), BEZEL)


def shell(w, h, y0, d, m, r=0.010, seg=2, t=0.016, k=0.04):
    """몸 — 앞 k 는 네 벽만(앞판 · 테 · 유리가 그 안에 앉는다) · 그 뒤는 통. 통 앞면이 유리를 덮으면 화면이
    가운데 볼록한 데만 비어져 나와 작아 보인다(전자레인지)."""
    box("body", (w, h, d - k), (0.0, y0 + h * 0.5, -(k + d) * 0.5), m, r, seg)
    z = k + 0.012
    for (sx, sy, cx, cy) in ((w, t, 0.0, y0 + h - t * 0.5), (w, t, 0.0, y0 + t * 0.5),
                             (t, h, -(w - t) * 0.5, y0 + h * 0.5), (t, h, (w - t) * 0.5, y0 + h * 0.5)):
        box("wall", (sx, sy, z), (cx, cy, 0.002 - z * 0.5), m, min(r, t * 0.45), seg)


def turned(ob, x, y, z, ang):
    """원점에 지은 것을 (x, y, z) 로 옮기고 앞축(z)으로 ang 도 돌린다 — 합칠 때 변환이 메시에 얹힌다."""
    ob.location = G(x, y, z)
    ob.rotation_euler = (0.0, math.radians(ang), 0.0)
    return ob


def grip_knob(x, y, r, ang):
    """큰 손잡이 다이얼 — 쇠 테(접시) · 검은 둥근 갓 · 갓을 가로지르는 손잡이 막대(젠레스 존 제로 런처 TV)."""
    lathe_z("kring", [(0.0, 0.006), (r * 0.78, 0.006), (r * 0.80, 0.016), (r * 0.92, 0.018), (r, 0.012), (r, 0.0)],
            (x, y, 0.003), KNOB, 36)
    lathe_z("kcap", [(0.0, 0.03), (r * 0.5, 0.028), (r * 0.7, 0.02), (r * 0.72, 0.006)], (x, y, 0.003), BEZEL, 28)
    turned(box("kbar", (0.016, r * 1.62, 0.02), (0.0, 0.0, 0.0), KNOB, 0.005, 2), x, y, 0.034, ang)


def back_hump(w, h, cy, d0, d1, m, r=0.03):
    """브라운관 혹 — 몸 뒤로 좁아지는 상자(옆에서 보면 TV 가 TV 로 읽힌다)."""
    box("hump", (w, h, d1 - d0), (0.0, cy, -(d0 + d1) * 0.5), m, r, 2)


def feet(w, d, m):
    for sx in (-1.0, 1.0):
        for sz in (0.12, d - 0.12):
            box("foot", (0.04, 0.018, 0.04), (sx * (w * 0.5 - 0.06), 0.009, -sz), m, 0.006, 2)


def finish(name, angle=35.0):
    global CUR
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
        pass
    ob.select_set(False)
    print(name, "tris", sum(len(p.vertices) - 2 for p in ob.data.polygons))
    CUR = []
    return ob


# ══ 나무 장 — 화면이 폭의 일곱에 넷 · 테 2~4cm · 오른쪽 조작판 ════════════════
W, H, D = 0.62, 0.48, 0.32
Y0 = 0.018
shell(W, H, Y0, D, WOOD)
back_hump(W * 0.66, H * 0.70, Y0 + H * 0.5, D - 0.02, D + 0.16, WOOD)
SX, SY, SW, SH = -0.075, Y0 + 0.245, 0.215, 0.195
front_plate("face", -W * 0.5 + 0.01, W * 0.5 - 0.01, Y0 + 0.01, Y0 + H - 0.01, SX, SY, SW, SH, WOOD, 5.2)
tube(SX, SY, SW, SH, 5.2)
PX = 0.225
box("panel", (0.125, H - 0.05, 0.006), (PX, Y0 + H * 0.5, 0.003), PANEL)
dial(PX, Y0 + 0.385, 0.034, KNOB, 0.024, True)
dial(PX, Y0 + 0.295, 0.024)
slats(PX - 0.045, PX + 0.045, Y0 + 0.05, Y0 + 0.235, 9, TRIM)
feet(W, D, PANEL)
finish("TvWood")

# ══ 넓은 나무 — 위 큰 화면(테 3cm) · 밑 가로 스피커 띠 · 오른쪽 아래 다이얼 ════════
W, H, D = 0.72, 0.56, 0.34
Y0 = 0.018
shell(W, H, Y0, D, WOOD, 0.012)
back_hump(W * 0.66, H * 0.66, Y0 + H * 0.56, D - 0.02, D + 0.18, WOOD)
SX, SY, SW, SH = 0.0, Y0 + 0.33, 0.315, 0.205
front_plate("face", -W * 0.5 + 0.012, W * 0.5 - 0.012, Y0 + 0.105, Y0 + H - 0.012, SX, SY, SW, SH, WOOD, 5.2)
box("lip", (W - 0.024, 0.093, 0.006), (0.0, Y0 + 0.058, -0.003), WOOD)
tube(SX, SY, SW, SH, 5.2, 0.011, 0.022, 0.022)
slats(-W * 0.5 + 0.04, 0.16, Y0 + 0.022, Y0 + 0.092, 12, TRIM, 0.002, True)
dial(0.235, Y0 + 0.057, 0.024)
dial(0.305, Y0 + 0.057, 0.024)
feet(W, D, PANEL)
finish("TvConsole")

# ══ 휴대용 플라스틱 — 둥근 몸 · 화면이 폭의 셋에 둘 · 다이얼 둘 · 손잡이 ═══════════
W, H, D = 0.44, 0.36, 0.30
shell(W, H, 0.0, D, PLASTIC, 0.035, 3, 0.03)
back_hump(W * 0.62, H * 0.62, H * 0.52, D - 0.03, D + 0.10, PLASTIC, 0.04)
SX, SY, SW, SH = -0.045, 0.185, 0.155, 0.14
front_plate("face", -W * 0.5 + 0.025, W * 0.5 - 0.025, 0.025, H - 0.025, SX, SY, SW, SH, PLASTIC, 4.6)
tube(SX, SY, SW, SH, 4.6, 0.010, 0.018, 0.016)
PX = 0.163
box("panel", (0.07, H - 0.07, 0.006), (PX, H * 0.5, 0.003), PANEL)
dial(PX, 0.25, 0.026, KNOB, 0.026, True)
dial(PX, 0.165, 0.026, KNOB, 0.026, True)
slats(PX - 0.025, PX + 0.025, 0.055, 0.105, 5, TRIM)
for sx in (-0.15, 0.15):
    box("post", (0.02, 0.05, 0.026), (sx, H + 0.02, -D * 0.45), TRIM, 0.006, 2)
box("bar", (0.34, 0.02, 0.03), (0.0, H + 0.05, -D * 0.45), TRIM, 0.008, 2)
finish("TvPort")

# ══ 모니터 — 얇은 테 · 밑 조작 띠 · 뒤로 좁아지는 혹(젠레스 존 제로 TV 더미의 꼴) ════════
W, H, D = 0.46, 0.40, 0.24
shell(W, H, 0.0, D, PLASTIC, 0.016)
back_hump(W * 0.72, H * 0.70, H * 0.54, D - 0.02, D + 0.20, PLASTIC, 0.035)
SX, SY, SW, SH = 0.0, 0.235, 0.205, 0.148
front_plate("face", -W * 0.5 + 0.016, W * 0.5 - 0.016, 0.06, H - 0.016, SX, SY, SW, SH, PLASTIC, 5.6)
tube(SX, SY, SW, SH, 5.6, 0.010, 0.02, 0.016)
box("strip", (W - 0.04, 0.042, 0.006), (0.0, 0.036, -0.002), PANEL)
for k in range(3):
    box("btn", (0.024, 0.012, 0.008), (0.11 + k * 0.032, 0.036, 0.003), KNOB)
box("led", (0.009, 0.009, 0.006), (-0.18, 0.036, 0.004), TRIM)
finish("TvMon")

# ══ 작은 쇠 상자 — 화면 · 오른쪽 작은 다이얼 셋 ═══════════════════════
W, H, D = 0.34, 0.28, 0.24
shell(W, H, 0.0, D, METAL)
back_hump(W * 0.66, H * 0.66, H * 0.52, D - 0.02, D + 0.10, METAL)
SX, SY, SW, SH = -0.035, 0.14, 0.12, 0.112
front_plate("face", -W * 0.5 + 0.01, W * 0.5 - 0.01, 0.01, H - 0.01, SX, SY, SW, SH, METAL, 5.2)
tube(SX, SY, SW, SH, 5.2, 0.008, 0.016, 0.012)
box("panel", (0.055, H - 0.04, 0.006), (0.128, H * 0.5, 0.003), PANEL)
for y in (0.205, 0.145, 0.085):
    dial(0.128, y, 0.014, KNOB, 0.016)
finish("TvBox")

# ══ 스피커 — 짙은 통 · 검은 앞판 · 우퍼 둘 · 트위터 ═══════════════════════
W, H, D = 0.30, 0.46, 0.28
box("body", (W, H, D - 0.01), (0.0, H * 0.5, -(D - 0.01) * 0.5 - 0.01), WOOD, 0.01, 2)
box("baffle", (W - 0.03, H - 0.03, 0.008), (0.0, H * 0.5, -0.002), PANEL)
for (y, r) in ((0.135, 0.105), (0.32, 0.07)):
    lathe_z("ring", [(r, 0.0), (r, 0.006), (r * 0.86, 0.012), (r * 0.80, 0.004)], (0.0, y, 0.0), TRIM, 24)
    lathe_z("cone", [(r * 0.82, 0.004), (r * 0.35, -0.03), (r * 0.22, -0.02), (0.0, -0.016)], (0.0, y, 0.0), GRILLE, 24)
    lathe_z("cap", [(r * 0.24, -0.02), (r * 0.12, -0.008), (0.0, -0.005)], (0.0, y, 0.0), KNOB, 12)
lathe_z("tw", [(0.022, 0.0), (0.022, 0.006), (0.012, 0.012), (0.0, 0.014)], (0.0, 0.415, 0.0), KNOB, 16)
finish("Speaker")

# ══ 주인공 — 게임 TV(가까이 다가가는 그 TV) · 젠레스 존 제로 런처 TV 의 꼴 ═══════════════════
#  쇳빛 장 · 왼쪽 큰 화면 칸(비스듬히 꺾여 드는 틀 → 검은 판 → 테 → 볼록 유리) · 오른쪽 조작판(손잡이 다이얼
#  둘 · 숨구멍 띠 · 눈금 슬라이더 · 빨강 · 초록 · 파랑 등). 사용자가 건넨 그림 「메인 tv가 가운데 크게」.
W, H, D = 0.80, 0.60, 0.52
T = 0.022
shell(W, H, 0.0, D, GUN, 0.012, 2, T, 0.06)
back_hump(W * 0.70, H * 0.72, H * 0.52, D - 0.02, D + 0.20, GUN, 0.04)
CX1 = 0.19
cx, cy = (-W * 0.5 + T + CX1) * 0.5, H * 0.5
hw, hh = (CX1 - (-W * 0.5 + T)) * 0.5, H * 0.5 - T
strip("frame", [ring(cx, cy, hw, hh, 0.002, 16), ring(cx, cy, hw - 0.008, hh - 0.008, 0.002, 16),
                ring(cx, cy, hw - 0.03, hh - 0.03, -0.014, 16)], GUN)
SX, SY, SW, SH = cx, cy + 0.002, 0.240, 0.224
front_plate("mask", cx - hw + 0.03, cx + hw - 0.03, cy - hh + 0.03, cy + hh - 0.03, SX, SY, SW, SH, BEZEL, 6.0, -0.014)
tube(SX, SY, SW, SH, 6.0, 0.012, 0.03, 0.034, -0.014)
PX0, PX1 = CX1, W * 0.5 - T
PXC = (PX0 + PX1) * 0.5
box("face", (PX1 - PX0 + 0.004, H - 2 * T, 0.012), (PXC, H * 0.5, -0.006), GUN)
box("cpanel", (PX1 - PX0 - 0.024, H - 2 * T - 0.024, 0.006), (PXC, H * 0.5, 0.0), PANEL, 0.003, 2)
grip_knob(PXC, 0.495, 0.046, 0.0)
grip_knob(PXC, 0.385, 0.046, 45.0)
slats(PXC - 0.05, PXC + 0.05, 0.268, 0.33, 6, GUN, 0.006)
box("slot", (0.014, 0.18, 0.006), (PXC - 0.005, 0.155, 0.003), BEZEL)
box("slider", (0.026, 0.03, 0.02), (PXC - 0.005, 0.205, 0.012), CAPM, 0.004, 2)
for k in range(15):
    big = k % 4 == 0
    box("tick", (0.02 if big else 0.012, 0.0025, 0.004), (PXC - 0.04 - (0.004 if big else 0.0), 0.068 + k * 0.0123, 0.004),
        TRIM)
for (yy, m) in ((0.215, LEDR), (0.155, LEDG), (0.095, LEDB)):
    box("led", (0.008, 0.044, 0.008), (PXC + 0.035, yy, 0.004), m, 0.002, 2)
for sx in (-1.0, 1.0):
    for sy in (-1.0, 1.0):
        lathe_z("screw", [(0.0, 0.006), (0.005, 0.005), (0.006, 0.0)], (PXC + sx * 0.062, H * 0.5 + sy * 0.258, 0.003),
                KNOB, 10)
feet(W, D, PANEL)
finish("TvHero")

# ══ 데크 — 주인공 밑 비디오 데크(전원 단추 · 테이프 문 · 긴 단추 줄 · 재생 단추 · 숨구멍) ═══════════
W, H, D = 0.98, 0.14, 0.46
shell(W, H, 0.0, D, GUN, 0.008, 2, 0.014, 0.03)
box("face", (W - 0.024, H - 0.024, 0.012), (0.0, H * 0.5, -0.006), GUN)
box("seam", (W - 0.05, 0.003, 0.004), (0.0, H - 0.032, 0.001), BEZEL)
box("pwr", (0.056, 0.044, 0.014), (-0.40, 0.078, 0.004), PANEL, 0.005, 2)
lathe_z("pwr_led", [(0.0, 0.004), (0.009, 0.004), (0.011, 0.0)], (-0.40, 0.078, 0.011), LEDG, 12)
dial(-0.40, 0.03, 0.012, KNOB, 0.012)
box("door", (0.44, 0.058, 0.006), (-0.02, 0.08, 0.001), BEZEL, 0.002, 2)
box("lcd", (0.40, 0.034, 0.004), (-0.02, 0.08, 0.004), LCD)
for k in range(4):
    box("key", (0.095, 0.012, 0.006), (-0.17 + k * 0.105, 0.03, 0.002), PANEL, 0.002, 2)
box("play", (0.066, 0.052, 0.014), (0.29, 0.078, 0.004), PANEL, 0.005, 2)
slats(0.355, 0.455, 0.06, 0.104, 5, GUN, 0.004)
for k in range(3):
    box("btn", (0.03, 0.012, 0.006), (0.37 + k * 0.035, 0.03, 0.002), PANEL, 0.002, 2)
finish("Deck")

# ── 내보낸다 ────────────────────────────────────────────────────
obs = [o for o in bpy.context.collection.objects if o.get("done") is not None]
for o in bpy.context.collection.objects:
    o.select_set(o in obs)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True,
                          export_yup=True, export_animations=False, export_cameras=False, export_lights=False)
print("wrote", OUT, [o.name for o in obs])

if PREVIEW:
    lay = {"TvWood": (-1.55, 0.0), "TvConsole": (-0.75, 0.0), "TvPort": (0.05, 0.0), "TvMon": (0.62, 0.0),
           "TvBox": (1.15, 0.0), "Speaker": (1.6, 0.0)}
    hero = "--hero" in argv      # 주인공 · 데크만 가까이
    if hero:
        lay = {"TvHero": (0.0, 0.14), "Deck": (0.0, 0.0)}
    for o in obs:
        dx, dz = lay.get(o.name, (0, -9))
        o.location = Vector((dx, 0.0, dz))
        o.rotation_euler = (0.0, 0.0, math.radians(-10.0 if hero else -14.0))
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.25 if hero else 4.0
    cam.rotation_euler = (math.radians(82.0), 0.0, 0.0)
    cam.location = Vector((0.0, -8.0, (0.36 if hero else 0.30) + 8.0 * math.tan(math.radians(8.0))))
    scene.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50.0), math.radians(-20.0), math.radians(25.0))
    scene.collection.objects.link(sun)
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1500
    scene.render.resolution_y = 1000 if hero else 460
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.10, 0.09, 0.10, 1.0)
    scene.world = w
    scene.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
    print("preview", PREVIEW)
