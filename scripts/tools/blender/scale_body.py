# 저울 — Blender(bpy)로 짓고 glb 로 내보낸다 (2026-10-16 「블렌더 깔았으니까 활용해봐」 — 등록기 다음).
#
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup \
#       --python scripts/tools/blender/scale_body.py -- [--preview 그림.png]
#
# 한 glb 에 메시 넷 — 게임(room3d.gd _scale_prop)이 노드 이름으로 집어 제 노드에 앉힌다:
#   ScaleBody   움직이지 않는 몸(발 · 서랍 받침 · 몰딩 단 · 청동 굽 · 깎은 기둥 · 굴대 북 · 꼭지). 저울 제 좌표.
#   ScaleBeam   저울대 + 가운데 혹 + 바늘. 굴대(SCALE_PIV)가 원점 — 게임의 Arm 노드가 돌린다.
#   ScalePan    접시 하나(고리 · 사슬 셋 · 말린 테 접시). 저울대 끝 걸이가 원점 — PanL · PanR 이 같이 쓴다.
#               안 바닥 한가운데가 PAN_TOP(−24.1) 그대로다(판 동전 · 상인 손이 pan_top 으로 거기 선다).
#   ScaleWeight 추 하나(바닥 가운데가 원점) — 바깥 접시에 둘(큰 것 · 0.7 배).
# 좌표는 저울 안쪽 단위 그대로다: 게임의 (u, h, w) = Blender 의 (x, z, −y)(glTF 가 Z-up 을 Y-up 으로 돌린다).
# 물체는 다 제자리 변환 없이(원점 · 회전 0) 꼭짓점에 좌표를 굽는다 — 게임은 메시만 꺼내 쓴다.
# 재질은 이름만 붙인다(brass · bronze · wood · wood_lt · patina · ink) — 게임이 이름으로 제 재질을 끼운다.
# 화면에서 저울은 한 단위가 가로 2px · 높이 1.2px(곱 2 · 52° 내려다봄)다 — 1 단위보다 가는 무늬는 안 보이고
# 기울 때 반짝이는 잡음이 된다. 단 · 테 · 고리는 1 단위 언저리 위로 둔다.
import bpy
import bmesh
import math
import os
import sys
from mathutils import Vector, Matrix

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "assets", "models", "scale_body.glb")

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
    bsdf.inputs["Roughness"].default_value = 0.4
    if name in ("brass", "bronze", "patina"):
        bsdf.inputs["Metallic"].default_value = 0.85
    MATS[name] = m
    return m


# 미리보기 빛깔(게임은 이름으로 제 재질을 쓴다 — 등록기와 같은 이름 · 같은 재질)
BRASS = mat("brass", (0.80, 0.55, 0.18))
BRONZE = mat("bronze", (0.30, 0.17, 0.07))
WOOD = mat("wood", (0.12, 0.06, 0.03))
WOOD_LT = mat("wood_lt", (0.36, 0.20, 0.11))
PATINA = mat("patina", (0.25, 0.20, 0.08))
INK = mat("ink", (0.05, 0.04, 0.04))

PARTS = {"ScaleBody": [], "ScaleBeam": [], "ScalePan": [], "ScaleWeight": []}
CUR = ["ScaleBody"]


def G(u, h, w):
    """게임 좌표 → Blender 좌표"""
    return Vector((u, -w, h))


def link(ob, m):
    bpy.context.collection.objects.link(ob)
    if m is not None:
        ob.data.materials.append(m)
    PARTS[CUR[0]].append(ob)
    return ob


def box(name, size, at, m, bevel=0.0, seg=1):
    """size (u, h, w) · at 가운데(게임 좌표). 모깎음은 45° 한 단(seg 1) — 모서리마다 빛 날 하나"""
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


def lathe(name, prof, at, m, seg=24, axis="h", inside=False, closed=False):
    """prof: [(반지름, 높이)] — 축을 따라 돌린 회전체. axis h(위) · w(앞) · u(오른쪽).
    inside — 겉이 축 쪽을 보는 판(접시 안). closed — 윤곽 끝을 처음과 잇는다(고리)."""
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    vs = [bm.verts.new(Vector((r, 0.0, z))) for r, z in prof]
    for a, b in zip(vs, vs[1:]):
        bm.edges.new((a, b))
    if closed:
        bm.edges.new((vs[-1], vs[0]))
    bmesh.ops.spin(bm, geom=bm.verts[:] + bm.edges[:], cent=Vector((0, 0, 0)), axis=Vector((0, 0, 1)),
                   angle=math.tau, steps=seg, use_merge=True)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-4)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    # 열린 판은 앞뒤가 정해지지 않는다 — 겉(밖 · 위)이 바깥을 보게 맞춘다
    s = 0.0
    for f in bm.faces:
        c = f.calc_center_median()
        rad = Vector((c.x, c.y, 0.0))
        s += f.normal.dot(rad.normalized() if rad.length > 1e-6 else Vector((0, 0, 1))) * f.calc_area()
    if (s < 0.0) != inside:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    if axis == "w":
        # 축 z → 앞(Blender −y)
        bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector((0, 0, 0)),
                         matrix=Matrix.Rotation(math.radians(90.0), 3, "X"))
    elif axis == "u":
        # 축 z → 오른쪽(Blender x)
        bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector((0, 0, 0)),
                         matrix=Matrix.Rotation(math.radians(90.0), 3, "Y"))
    bmesh.ops.translate(bm, vec=G(*at), verts=bm.verts)
    bm.to_mesh(me)
    bm.free()
    return link(bpy.data.objects.new(name, me), m)


def ring(name, c, ax, ay, rx, ry, r, m, seg=12, rseg=6):
    """고리(타원 도넛) — 가운데 c · 두 축 ax ay(게임 좌표 방향) · 반지름 rx ry · 굵기 r"""
    ax = Vector(ax).normalized()
    ay = Vector(ay).normalized()
    az = ax.cross(ay).normalized()
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    grid = []
    for i in range(seg):
        t = math.tau * i / seg
        p = Vector(c) + ax * (rx * math.cos(t)) + ay * (ry * math.sin(t))
        out = (ax * (math.cos(t) / rx) + ay * (math.sin(t) / ry)).normalized()
        row = []
        for j in range(rseg):
            s = math.tau * j / rseg
            q = p + out * (r * math.cos(s)) + az * (r * math.sin(s))
            row.append(bm.verts.new(G(*q)))
        grid.append(row)
    for i in range(seg):
        for j in range(rseg):
            a, b = grid[i][j], grid[(i + 1) % seg][j]
            cc, d = grid[(i + 1) % seg][(j + 1) % rseg], grid[i][(j + 1) % rseg]
            bm.faces.new((a, b, cc, d))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(me)
    bm.free()
    return link(bpy.data.objects.new(name, me), m)


def chain(a, b, m, pitch=2.1, wid=0.62, wire=0.3):
    """사슬 — a 에서 b 까지 고리를 엇갈려(90°) 꿴다. 고리 길이 pitch 의 1.15 배(이웃과 맞물린다)"""
    a = Vector(a)
    b = Vector(b)
    d = b - a
    n = max(2, round(d.length / pitch))
    t = d.normalized()
    side = t.cross(Vector((0.0, 0.0, 1.0)))
    if side.length < 1e-3:
        side = Vector((1.0, 0.0, 0.0))
    side.normalize()
    side2 = t.cross(side).normalized()
    step = d.length / n
    for i in range(n):
        c = a + t * (step * (i + 0.5))
        ring("link", c, t, side if i % 2 == 0 else side2, step * 0.62, wid, wire, m, seg=10, rseg=5)


# ══ ScaleBody — 움직이지 않는 몸 ═════════════════════════════════════
# 받침 네 귀 놋쇠 번 발(SELL_FOOT ±11.4 · ±8.9 안)
FOOT = [(0.0, 0.0), (1.2, 0.0), (1.7, 0.35), (1.9, 0.9), (1.7, 1.5), (1.3, 1.9), (0.0, 1.9)]
for fu in (-8.6, 8.6):
    for fw in (-6.2, 6.2):
        lathe("foot", FOOT, (fu, 0.0, fw), BRASS, seg=14)
# 아래 단 — 짙은 나무 함(h 1.7..5.0). 앞에 추를 넣는 서랍(등록기 몸통과 같은 청동 앞판 · 짙은 틈 · 놋쇠 꼭지).
# 놋쇠 띠(22.8 × 17.8)가 함보다 0.4 만 내민다 — 더 내밀면 52° 로 내려다보는 앞면을 띠가 가린다.
box("case", (22.0, 3.3, 17.0), (0.0, 3.35, 0.0), WOOD, bevel=0.45)
box("drawer_gap", (13.0, 2.3, 0.3), (0.0, 3.2, 8.55), INK)
box("drawer", (12.2, 1.7, 0.4), (0.0, 3.2, 8.7), BRONZE, bevel=0.18)
lathe("drawer_knob", [(0.0, 0.0), (0.6, 0.0), (0.95, 0.25), (0.95, 0.5), (0.5, 0.7), (0.0, 0.75)],
      (0.0, 3.2, 8.85), BRASS, seg=12, axis="w")
# 앞 두 모서리 놋쇠 갓 · 꽃 단추 — 등록기 서랍장 모서리와 같은 말씨
for su in (-1.0, 1.0):
    box("corner", (1.8, 3.1, 1.0), (su * 10.4, 3.3, 8.25), BRASS, bevel=0.3)
    lathe("rosette", [(0.0, 0.0), (0.7, 0.0), (0.7, 0.25), (0.4, 0.55), (0.0, 0.6)],
          (su * 10.4, 3.3, 8.7), BRASS, seg=10, axis="w")
# 놋쇠 띠(받침에서 가장 넓은 단 — foot_clear 가 대 보는 귀)
box("band", (22.8, 0.8, 17.8), (0.0, 5.3, 0.0), BRASS, bevel=0.3)
# 위 단 — 옅은 나무 몰딩 두 단(단마다 윗면이 빛을 받아 줄이 선다)
box("tier1", (18.4, 0.8, 15.0), (0.0, 6.1, 0.0), WOOD_LT, bevel=0.3)
box("tier2", (17.0, 1.3, 14.0), (0.0, 7.1, 0.0), WOOD_LT, bevel=0.45)
# 굽 — 기둥이 서는 둥근 놋쇠 종(밑 테 · 오지 · 고리). 넓은 종 윗면이 램프를 받아 받침의 빛 자리다
# (청동으로 지었더니 기둥 밑이 검은 구멍으로 가라앉아 저울 전체가 어두워 보였다 — 찍어 봤다).
lathe("socle", [(0.0, 7.7), (6.8, 7.7), (6.8, 8.4), (6.3, 8.7), (5.2, 9.2), (4.6, 9.8), (0.0, 9.8)],
      (0.0, 0.0, 0.0), BRASS, seg=28)
lathe("socle_ring", [(0.0, 9.7), (4.4, 9.7), (4.7, 10.0), (4.7, 10.7), (4.4, 11.0), (0.0, 11.0)],
      (0.0, 0.0, 0.0), BRASS, seg=28)
# 기둥 — 깎은 놋쇠 발루스터: 밑 항아리 · 고리 · 가늘어지는 몸 · 머리 고리 · 목
COL = [(0.0, 11.0), (3.4, 11.0), (3.0, 11.5), (3.5, 12.3), (3.8, 13.5), (3.6, 14.9), (3.0, 16.1),
       (2.6, 17.2), (2.6, 18.6), (3.4, 19.0), (3.4, 20.8), (2.6, 21.2), (2.45, 26.0), (2.25, 34.0),
       (2.1, 41.6), (3.0, 42.2), (3.3, 43.0), (3.3, 44.8), (3.0, 45.6), (2.0, 46.2), (1.8, 47.0),
       (1.8, 51.0), (2.4, 51.6), (2.6, 52.4), (0.0, 52.6)]
lathe("column", COL, (0.0, 0.0, 0.0), BRASS, seg=28)
# 굴대 북 — 저울대가 꿰는 통(SCALE_PIV 높이 56 이 한가운데). 청동 통에 놋쇠 테 둘 — 등록기 몸통처럼
# 짙은 주물을 닦은 테가 두른다(한 빛깔이면 저울대 · 혹 · 꼭지가 한 덩어리로 붙는다).
lathe("hub", [(0.0, 53.6), (3.1, 53.6), (3.1, 58.4), (0.0, 58.4)], (0.0, 0.0, 0.0), BRONZE, seg=24)
lathe("hub_lo", [(0.0, 52.9), (1.9, 53.1), (3.0, 53.5), (3.45, 54.0), (3.45, 54.5), (3.0, 54.8), (0.0, 54.8)],
      (0.0, 0.0, 0.0), BRASS, seg=24)
lathe("hub_hi", [(0.0, 57.2), (3.0, 57.2), (3.45, 57.5), (3.45, 58.0), (3.0, 58.5), (1.9, 58.9), (0.0, 59.1)],
      (0.0, 0.0, 0.0), BRASS, seg=24)
# 꼭지 — 항아리 · 도토리(꼭대기 67.6 은 SELL_HULL 그대로)
lathe("finial", [(1.6, 58.8), (1.0, 59.4), (0.8, 60.3), (1.4, 60.9), (1.4, 61.5), (0.9, 62.0),
                 (1.6, 63.0), (1.9, 64.2), (1.6, 65.4), (1.0, 66.4), (0.5, 67.1), (0.0, 67.6)],
      (0.0, 0.0, 0.0), BRASS, seg=18)

# ══ ScaleBeam — 굴대가 원점 · 저울대는 u 를 따라 ═══════════════════════
CUR[0] = "ScaleBeam"
half = [(0.0, 24.2), (0.9, 24.0), (1.5, 23.4), (1.6, 22.9), (1.2, 22.5), (0.85, 22.3), (0.85, 21.6),
        (1.3, 21.3), (1.55, 20.7), (1.2, 20.2), (1.0, 19.6), (1.15, 12.2), (1.6, 11.6), (1.6, 10.6),
        (1.3, 10.1), (1.5, 6.0), (1.9, 3.7), (2.4, 3.3)]
BEAM = [(r, -z) for r, z in half] + [(r, z) for r, z in reversed(half)]
lathe("beam", BEAM, (0.0, 0.0, 0.0), BRASS, seg=16, axis="u")
# 가운데 혹 — 굴대 앞을 덮는 둥근 단추(북 겉 w 3.2 에서 앞으로)
lathe("boss", [(0.0, 0.0), (2.2, 0.0), (2.35, 0.45), (1.9, 0.95), (1.0, 1.25), (0.0, 1.35)],
      (0.0, 0.0, 2.9), BRASS, seg=20, axis="w")
# 바늘 — 혹 밑에서 기둥 앞으로 내려온다(끝 −13.5 · 옛 바늘 그대로) · 녹 짙은 쇠
lathe("needle", [(0.0, -13.5), (0.4, -12.8), (0.75, -11.5), (0.3, -11.1), (0.35, -4.0), (0.6, -2.4),
                 (0.0, -1.9)], (0.0, 0.0, 3.8), PATINA, seg=8)

# ══ ScalePan — 걸이가 원점 ══════════════════════════════════════════
CUR[0] = "ScalePan"
# 걸이 고리 — 저울대 끝 홈(반지름 0.85)에 걸린다. 접시는 늘 수직으로 서므로 고리는 u 축 둘레로 선다.
ring("hook", (0.0, -0.7, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0), 1.5, 1.5, 0.32, PATINA, seg=14, rseg=6)
lathe("shank", [(0.0, -2.0), (0.45, -2.1), (0.45, -3.2), (0.95, -3.5), (0.95, -4.1), (0.0, -4.3)],
      (0.0, 0.0, 0.0), PATINA, seg=10)
# 사슬 셋 — 걸이 밑에서 말린 테 세 점으로(앞 하나 · 뒤 양옆 둘)
for k in range(3):
    a = math.tau * k / 3.0 + math.pi * 0.5
    chain((0.0, -4.1, 0.0), (math.cos(a) * 9.7, -22.6, math.sin(a) * 9.7), PATINA)
# 접시 — 바닥 굽 · 얕은 배(닦은 놋쇠) · 말린 테 · 오목한 안(녹 짙은 놋쇠, 한가운데 PAN_TOP −24.1).
# 안은 얕게 둔다 — 깊은 우묵은 안이 기울어 램프 대신 어둠을 비춰 접시가 검은 원반으로 가라앉았다(찍어 봤다).
lathe("pan", [(0.0, -26.0), (3.9, -26.0), (4.3, -25.85), (4.4, -25.5), (4.1, -25.3), (5.2, -25.1),
              (7.2, -24.75), (8.8, -24.2), (9.7, -23.6), (10.1, -23.1)], (0.0, 0.0, 0.0), BRASS, seg=32)
ring("rim", (0.0, -22.9, 0.0), (1.0, 0.0, 0.0), (0.0, 0.0, 1.0), 10.0, 10.0, 0.5, BRASS, seg=40, rseg=8)
lathe("bowl", [(9.6, -22.95), (9.0, -23.3), (7.8, -23.65), (5.5, -23.95), (2.8, -24.08), (0.0, -24.1)],
      (0.0, 0.0, 0.0), PATINA, seg=32, inside=True)

# ══ ScaleWeight — 추 하나(바닥 가운데가 원점) ════════════════════════════
CUR[0] = "ScaleWeight"
lathe("weight", [(0.0, 0.0), (2.9, 0.0), (3.0, 0.3), (3.0, 2.4), (2.8, 2.9), (2.2, 3.25), (1.4, 3.5),
                 (1.0, 3.8), (1.0, 4.2), (1.5, 4.6), (1.5, 5.1), (1.0, 5.5), (0.0, 5.6)],
      (0.0, 0.0, 0.0), BRASS, seg=16)

# ── 갈래마다 한 몸으로 합치고 내보낸다 ─────────────────────────────────
done = []
for nm, obs in PARTS.items():
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    if len(obs) > 1:
        bpy.ops.object.join()
    ob = bpy.context.view_layer.objects.active
    ob.name = nm
    ob.data.name = nm
    # 매끈함은 각 30° 로 가른다 — 단 · 모서리는 서고 회전체 · 고리는 둥글다
    try:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(30.0))
    except Exception:
        bpy.ops.object.shade_smooth()
    print(nm, "tris", sum(len(p.vertices) - 2 for p in ob.data.polygons))
    done.append(ob)

bpy.ops.object.select_all(action="DESELECT")
for o in done:
    o.select_set(True)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True,
                          export_yup=True, export_animations=False, export_cameras=False, export_lights=False)
print("wrote", OUT)

if PREVIEW:
    # 게임 자세로 늘어놓는다 — 저울대는 평소(+12° · 바깥 접시가 내려앉음) · 추는 바깥 접시에
    piv = G(0.0, 56.0, 0.0)
    t = math.radians(12.0)
    by = {o.name: o for o in done}
    by["ScaleBeam"].matrix_world = Matrix.Translation(piv) @ Matrix.Rotation(-t, 4, "Y")
    pan = by["ScalePan"]
    for s in (-1.0, 1.0):
        p = piv + G(s * 22.0 * math.cos(t), s * 22.0 * math.sin(t), 0.0) - G(0.0, 0.0, 0.0)
        o = pan if s < 0 else bpy.data.objects.new("pan_r", pan.data)
        if s > 0:
            scene.collection.objects.link(o)
        o.matrix_world = Matrix.Translation(p)
        if s < 0:
            wt = by["ScaleWeight"]
            wt.matrix_world = Matrix.Translation(p + G(2.0, -24.1, 0.0))
            w2 = bpy.data.objects.new("wt2", wt.data)
            scene.collection.objects.link(w2)
            w2.matrix_world = Matrix.Translation(p + G(-3.8, -24.1, 0.8)) @ Matrix.Scale(0.7, 4)
    # 게임 진열대 카메라 — 직교 · 앞에서 52° 내려다본다
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 80.0
    cam.rotation_euler = (math.radians(52.0), 0.0, 0.0)
    d = Vector((0.0, math.sin(math.radians(52.0)), -math.cos(math.radians(52.0))))
    target = Vector((0.0, 0.0, 34.0))
    cam.location = target - d * 150.0
    scene.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(40.0), math.radians(-25.0), math.radians(20.0))
    scene.collection.objects.link(sun)
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 520
    scene.render.resolution_y = 480
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.08, 0.06, 0.09, 1.0)
    scene.world = w
    scene.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
    print("preview", PREVIEW)
