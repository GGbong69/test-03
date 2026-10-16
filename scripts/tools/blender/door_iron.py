# 술집 문 쇠붙이 — Blender(bpy)로 짓고 glb 로 내보낸다 (2026-10-16 「블렌더 깔았으니까 활용해봐」).
#
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup \
#       --python scripts/tools/blender/door_iron.py -- [--preview 그림.png]
#
# 제목 화면 문(door3d.gd _slab)의 쇠붙이 셋을 짓는다 — 모양만이다. 자리 · 도는 축 · 누름 판정은 게임 상수
# (Door3D.DOOR)가 쥐고, 조각마다 원점을 게임이 앉히는 자리에 둔다:
#   Pull   — 놋쇠 손잡이(활 모양 막대 · 굽 받침 둘) · 뒤판(끝이 잎 모양) · 나사 둘 · 열쇠 구멍판.
#            원점 = 문 앞면의 손잡이 한가운데(Hinge 안 (hx, (hy0+hy1)/2, thick)). 막대 곧은 몸이 hy0..hy1 을
#            덮는다(Door3D.handle_rect 그대로).
#   Strap  — 창끝 띠(문짝 쪽 · 둥글린 망치 쇠) · 둥근 못 머리 셋 · 말아 감은 경첩 눈.
#            원점 = 경첩 쪽 문 앞면(Hinge 안 (0, strap_y, thick)). 문짝과 같이 돈다.
#   Pintle — 문틀 쪽 경첩 통 둘 · 핀(위 둥근 머리 · 밑 두드린 끝) · 문틀 앞면 핀 판(모서리를 감아 든다) · 못 둘.
#            원점 = (x0, strap_y, 0)(문 장면 바닥 · z 는 그대로).
# 좌표는 게임 그대로(m · x 오른쪽 · y 위 · z 앞) 짓고 끝에 X 축 90° 로 Blender 의 Z-up 에 눕힌다(glTF 가 다시 세운다).
# 재질은 이름만 붙인다(brass · brass_hi · brass_dk · iron · knuck · stud · hole) — door3d 가 이름으로 제 재질
# (단으로 끊는 놋쇠 BRASS_SHADER · 망치 자국 쇠 그림 _iron_img · 램프 깜박이 미는 것)을 끼운다.
# 쇠(iron)의 UV 는 앞에서 본 평면 그대로다 — u = (x + 0.08) / 0.40 · v(게임) = (1/24 − y) / (1/12). 게임이
# 그 상자에 1 텍셀 = 판 평면 논리 1px 로 쇠 그림을 굽는다(IRON_BOX).
# 화면에서 1 cm 가 3.6px 다 — 3mm 밑 무늬는 안 보이므로 모양(활 · 잎 끝 · 창 날 · 못 머리 둥긂)으로 말한다.
import bpy
import bmesh
import math
import os
import random
import sys
from mathutils import Vector, Matrix

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "assets", "models", "door_iron.glb")

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIEW = argv[argv.index("--preview") + 1] if "--preview" in argv else ""

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# ── Door3D.DOOR 의 값(바꾸면 같이 바꾼다) ─────────────────────
HZ = 0.045                 # 막대 가운데가 문 앞면에서 뜬 몫
HR = 0.011                 # 막대 반지름(handle_rect 폭)
HL = 0.28                  # hy0 − hy1 — 곧은 몸 길이
KY = 0.065 + HL * 0.5      # 열쇠 구멍 — 손잡이 가운데에서 위로
STRAP_L = 0.30
STRAP_H = 0.034
KH = (STRAP_H + 0.016 - 0.006) / 3.0     # 경첩 통 한 마디 높이
CASE_W = 0.07
CASE_Z = 0.018
FACE = -0.03
IRON_BOX = (-0.08, -1.0 / 24.0, 0.40, 1.0 / 12.0)   # x0 · y0 · 폭 · 높이 — 게임 IRON_BOX 와 같다

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


# 미리보기 빛깔(게임은 이름으로 제 재질을 쓴다)
BRASS = mat("brass", (0.62, 0.42, 0.14), 0.9)
BRASS_HI = mat("brass_hi", (0.85, 0.62, 0.22), 0.9)
BRASS_DK = mat("brass_dk", (0.40, 0.25, 0.08), 0.9)
IRON = mat("iron", (0.05, 0.045, 0.045), 0.3)
KNUCK = mat("knuck", (0.04, 0.035, 0.035), 0.3)
STUD = mat("stud", (0.08, 0.07, 0.07), 0.4)
HOLE = mat("hole", (0.01, 0.01, 0.012))

UP = Matrix.Rotation(math.radians(90.0), 4, "X")     # 게임 (x, y, z) → Blender (x, −z, y)


class Piece:
    """조각 하나 — 게임 좌표로 bmesh 에 쌓고 끝에 한 메시로 낸다. 재질은 차례(slot)로 단다."""

    def __init__(self, name):
        self.name = name
        self.bm = bmesh.new()
        self.mats = []
        self.uv = self.bm.loops.layers.uv.new("UVMap")
        self.flat = set()

    def slot(self, m):
        if m not in self.mats:
            self.mats.append(m)
        return self.mats.index(m)

    def face(self, vs, m, flat=False):
        f = self.bm.faces.new(vs)
        f.material_index = self.slot(m)
        if flat:
            self.flat.add(f)
        return f

    def done(self):
        bm = self.bm
        # 면은 짓는 손마다 바깥을 보게 감았다 — recalc_face_normals 는 열린 통 · 판이 섞인 몸을 통째로 뒤집어
        # (판 앞면이 문 뒤로 숨고 옆벽 안쪽이 노란 덩이로 섰다) 쓰지 않는다
        # 쇠 UV — 앞에서 본 평면(게임 IRON_BOX). 놋쇠는 단 셰이더라 UV 를 안 쓴다.
        bx, by, bw, bh = IRON_BOX
        for f in bm.faces:
            for lp in f.loops:
                co = lp.vert.co
                lp[self.uv].uv = ((co.x - bx) / bw, (co.y - by) / bh)
        for f in bm.faces:
            f.smooth = f not in self.flat
        # 삼각형으로 — 오목한 윤곽(뒤판 홈 · 열쇠 구멍)이 내보내기에서 비틀리지 않고 탄젠트가 선다
        bmesh.ops.triangulate(bm, faces=bm.faces[:], quad_method="BEAUTY", ngon_method="EAR_CLIP")
        bm.normal_update()
        # 매끈함 — 각 35° 넘는 모서리 · 면마다 한 빛인 면(판 · 창 날)의 모서리는 선다. 둥글린 쇠 · 활은 매끈하다.
        # (shade_smooth_by_angle 은 면마다 한 빛을 다시 매끈하게 덮어서 쓰지 않는다 — 큰 판 앞면이 테의 비탈 법선을
        # 받아 한 단 밝게 섰다)
        for e in bm.edges:
            fs = e.link_faces
            e.smooth = (len(fs) == 2 and fs[0].smooth and fs[1].smooth
                        and fs[0].normal.angle(fs[1].normal, 0.0) < math.radians(35.0))
        bmesh.ops.transform(bm, matrix=UP, verts=bm.verts[:])
        me = bpy.data.meshes.new(self.name)
        bm.to_mesh(me)
        bm.free()
        for m in self.mats:
            me.materials.append(m)
        ob = bpy.data.objects.new(self.name, me)
        bpy.context.collection.objects.link(ob)
        return ob


# ── 짓는 손 ────────────────────────────────────────────────
def grid(P, rings, m, flat_fn=None):
    """x 를 따라 선 단면 고리(같은 수의 점 · 밑에서 앞으로 돌아 위로 · 뒤로 닫힌다)들을 잇는 로프트. 끝은 부채로 막는다."""
    bm = P.bm
    vr = [[bm.verts.new(Vector(p)) for p in r] for r in rings]
    n = len(rings[0])
    for i in range(len(vr) - 1):
        a, b = vr[i], vr[i + 1]
        for j in range(n):
            j2 = (j + 1) % n
            P.face([a[j], b[j], b[j2], a[j2]], m, flat_fn(i) if flat_fn else False)
    for r, back in ((vr[0], False), (vr[-1], True)):
        c = sum((v.co for v in r), Vector()) / len(r)
        vc = bm.verts.new(c)
        for j in range(n):
            tri = [r[j], r[(j + 1) % n], vc]
            P.face(tri[::-1] if back else tri, m)


def lathe(P, prof, at, m, seg=14, axis="z"):
    """prof [(반지름, 높이)] 를 축(z 앞 · y 위)으로 돌린 몸. at 은 바닥 가운데. 윤곽은 밑 → 바깥 → 위 차례(바깥을 본다)."""
    rings = []
    for k in range(seg):
        a = math.tau * k / seg
        ca, sa = math.cos(a), math.sin(a)
        ring = []
        for r, h in prof:
            if axis == "z":
                ring.append(Vector((at[0] + r * ca, at[1] + r * sa, at[2] + h)))
            else:
                ring.append(Vector((at[0] + r * sa, at[1] + h, at[2] + r * ca)))
        rings.append(ring)
    bm = P.bm
    vr = [[bm.verts.new(p) for p in r] for r in rings]
    n = len(prof)
    for k in range(seg):
        a, b = vr[k], vr[(k + 1) % seg]
        for j in range(n - 1):
            P.face([a[j], b[j], b[j + 1], a[j + 1]], m)


def dome(P, r, h, at, m, seg=12, axis="z", s=1.0):
    """둥근 머리(못 · 나사) — 밑 가장자리가 살짝 선 낮은 돔. s = −1 이면 뒤집는다."""
    prof = [(0.0001, -0.0006 * s), (r, -0.0006 * s), (r * 0.98, h * 0.22 * s), (r * 0.86, h * 0.58 * s),
            (r * 0.62, h * 0.85 * s), (r * 0.30, h * 0.98 * s), (0.0001, h * s)]
    lathe(P, prof if s > 0 else prof[::-1], at, m, seg=seg, axis=axis)


def plate(P, wfun, y0, y1, z0, z1, m, bev=0.0028, step=0.0015, keys=(), cx=0.0, cy=0.0):
    """좌우 대칭 판 — 반폭 w(y)(y0..y1) 윤곽을 z0..z1 로 밀고 앞 모서리를 45° 로 한 번 깎는다(1px 비탈 — 위 · 왼쪽은
    빛 테 · 아래 · 오른쪽은 그늘 테). 면마다 한 빛이다. 앞면은 가로 띠(같은 y 의 좌우 짝)로 깐다 — y 마다 한 구간인
    윤곽이라 오목한 홈(뒤판 잎 사이 · 열쇠 구멍 목)도 그대로 선다(ngon 을 귀 자르기로 쪼개니 오목한 데가 메워졌다).
    (비탈을 두 마디로 둥글리면 마디마다 0.3px 라 바깥 마디의 짙은 끝 색만 남았다 — 찍어 봤다)"""
    ys = set(round(y0 + step * k, 6) for k in range(int((y1 - y0) / step) + 1))
    ys |= {y0, y1} | {round(k, 6) for k in keys if y0 < k < y1}
    ys = sorted(y for y in ys if y0 <= y <= y1)
    bm = P.bm

    def ring(z, shrink):
        lo, hi = y0 + shrink, y1 - shrink
        pts = []
        for y in ys:
            yy = lo + (y - y0) * (hi - lo) / (y1 - y0)
            pts.append((max(wfun(yy) - shrink, 0.0003), yy))
        right = [bm.verts.new(Vector((cx + x, cy + y, z))) for x, y in pts]
        left = [bm.verts.new(Vector((cx - x, cy + y, z))) for x, y in pts]
        return right, left

    def loop(rl):
        return rl[0] + rl[1][::-1]          # 오른쪽을 올라가 왼쪽으로 내려온다(반시계)

    def strip(rl, up):
        r, l = rl
        for k in range(len(ys) - 1):
            q = [l[k], r[k], r[k + 1], l[k + 1]]
            P.face(q if up else q[::-1], m, flat=True)

    def band(a, b):
        n = len(a)
        for i in range(n):
            j = (i + 1) % n
            P.face([a[i], a[j], b[j], b[i]], m, flat=True)

    back = ring(z0, 0.0)
    mid = ring(z1 - bev, 0.0) if bev > 0.0 else back
    front = ring(z1, bev)
    strip(back, False)
    if bev > 0.0:
        band(loop(back), loop(mid))
    band(loop(mid), loop(front))
    strip(front, True)


def sweep(P, path, radii, mfun, seg=16):
    """길(게임 좌표 점 · x=0 평면)을 따라 반지름이 변하는 관. 고리마다 재질 mfun(i)."""
    bm = P.bm
    n = len(path)
    rings = []
    N = Vector((1.0, 0.0, 0.0))
    for i in range(n):
        a = path[max(i - 1, 0)]
        b = path[min(i + 1, n - 1)]
        T = (b - a).normalized()
        B = T.cross(N).normalized()
        ring = []
        for k in range(seg):
            ph = math.tau * k / seg
            ring.append(bm.verts.new(path[i] + radii[i] * (N * math.cos(ph) + B * math.sin(ph))))
        rings.append(ring)
    for i in range(n - 1):
        m = mfun(i)
        for k in range(seg):
            k2 = (k + 1) % seg
            P.face([rings[i][k], rings[i][k2], rings[i + 1][k2], rings[i + 1][k]], m)
    for r, first in ((rings[0], True), (rings[-1], False)):
        c = sum((v.co for v in r), Vector()) / len(r)
        vc = bm.verts.new(c)
        for k in range(seg):
            tri = [r[k], r[(k + 1) % seg], vc]
            P.face(tri[::-1] if first else tri, mfun(0))


def smooth01(t):
    t = min(max(t, 0.0), 1.0)
    return t * t * (3.0 - 2.0 * t)


# ══ Pull — 놋쇠 손잡이 · 뒤판 · 열쇠 구멍판 ══════════════════════
pull = Piece("Pull")

# 뒤판 — 곧은 몸 · 굽 자리 둥근 잎 · 끝 뾰족(고딕 창끝). 잎과 몸 사이에 2px 오목한 홈이 선다.
FOOT_Y = 0.132                  # 활의 굽(문에 닿는 데) — 잎 한가운데
LOBE_R = 0.0215


def plate_w(y):
    a = abs(y)
    body = 0.0185 if a <= 0.114 else 0.0
    lobe = math.sqrt(max(LOBE_R ** 2 - (a - FOOT_Y) ** 2, 0.0))
    tip = 0.011 * max(1.0 - (a - 0.146) / 0.022, 0.0) if a >= 0.146 else 0.0
    return max(body, lobe, tip)


plate(pull, plate_w, -0.168, 0.168, 0.0, 0.004, BRASS_DK, keys=(-0.114, 0.114))

# 활 — 곧은 몸(손이 닳린 가운데는 brass_hi) · 몸 끝 구슬 테 · 굽 쪽으로 휘어 문에 든다.
R_BEND = 0.026                  # 굽이 받침 안에 거의 묻힌다 — 길면 비껴 본 굽 옆이 짙은 덩이로 섰다
YS = FOOT_Y - R_BEND            # 곧은 몸 끝
path, rad, zone = [], [], []


def grip_r(y):
    a = abs(y)
    cig = 0.0104 + 0.0010 * (1.0 - (a / YS) ** 2)          # 가운데가 조금 부푼 시가 꼴
    bead = 0.0030 * math.exp(-((a - 0.098) / 0.0024) ** 2)  # 구슬 테
    neck = -0.0012 * math.exp(-((a - 0.106) / 0.0030) ** 2)
    return cig + bead + neck


for side in (-1.0, 1.0):
    seg_pts = []
    # 굽 — 뒤판에서 곧게 솟는다
    for k in range(6):
        z = 0.0035 + (HZ - R_BEND - 0.0035) * k / 5.0
        seg_pts.append((Vector((0.0, side * FOOT_Y, z)), 0.0086, 0))
    # 휨 — 90°
    for k in range(1, 16):
        th = math.radians(90.0 * k / 16.0)
        y = side * (FOOT_Y - R_BEND * (1.0 - math.cos(th)))
        z = (HZ - R_BEND) + R_BEND * math.sin(th)
        seg_pts.append((Vector((0.0, y, z)), 0.0086 + (grip_r(YS) - 0.0086) * smooth01(k / 15.0), 0))
    if side < 0:
        first = list(reversed(seg_pts))
    else:
        last = seg_pts
# 곧은 몸
mid = []
y = -YS
while y <= YS + 1e-9:
    mid.append((Vector((0.0, y, HZ)), grip_r(y), 1 if abs(y) < 0.088 else 0))
    y += 0.002
for p, r, zz in first + mid + last:
    path.append(p)
    rad.append(r)
    zone.append(zz)
sweep(pull, path, rad, lambda i: BRASS_HI if zone[i] and zone[i + 1] else BRASS, seg=16)

# 굽 받침(장미 꽃받침) — 잎 위에 나팔처럼 벌어진 받침
for side in (-1.0, 1.0):
    lathe(pull, [(0.0145, 0.0036), (0.0146, 0.0052), (0.0128, 0.0066), (0.0104, 0.0082), (0.0092, 0.0110),
                 (0.0088, 0.0140)], (0.0, side * FOOT_Y, 0.0), BRASS, seg=16)
    # 나사 — 잎 끝 창끝 자리
    dome(pull, 0.0036, 0.0022, (0.0, side * 0.157, 0.0040), BRASS, seg=10)

# 열쇠 구멍판 — 물방울 꼴(둥근 위 · 좁아지는 밑) · 비탈 테 · 열쇠 구멍(둥근 머리 · 밑으로 벌어진 홈)
ER = 0.0145


def esc_w(y):
    if y >= 0.006:
        return math.sqrt(max(ER ** 2 - (y - 0.006) ** 2, 0.0))
    return ER * ((y + 0.028) / 0.034) ** 0.55 if y > -0.028 else 0.0


# (안 테를 한 단 더 들였더니 10px 판에 바탕이 2px 만 남아 얼룩이 됐다 — 비탈 테 하나로)
plate(pull, esc_w, -0.028, 0.006 + ER, 0.0, 0.0045, BRASS, bev=0.0026, step=0.0012, cy=KY)
KR = 0.0055


def key_w(y):
    """열쇠 구멍 — 둥근 머리(4px) · 밑으로 벌어진 홈(1 → 2px). 머리와 홈이 같은 폭이면 막대(3x7px)로, 머리가
    3px 이면 십자로 읽혔다."""
    head = math.sqrt(max(KR ** 2 - (y - 0.0045) ** 2, 0.0))
    slot = 0.0032 + (0.0013 - 0.0032) * (y + 0.012) / 0.0118 if y <= -0.0002 else 0.0
    return max(head, slot)


plate(pull, key_w, -0.012, 0.0045 + KR, 0.0040, 0.0049, HOLE, bev=0.0, step=0.0008, keys=(-0.0002,), cy=KY)

# ══ Strap — 창끝 띠 · 못 머리 · 경첩 눈 ═══════════════════════════
random.seed(6030)
strap = Piece("Strap")
T = 0.0062                      # 띠 두께 — 문 앞면에 눕는다
XB = STRAP_L - 0.055            # 창 날 시작
TIP = STRAP_L + 0.012
HALF = STRAP_H * 0.5


def strap_h(x):
    """반높이 — 경첩 눈 쪽 목(통 높이) → 띠 → 허리(날 앞 잘록) → 창 날(미늘) → 끝"""
    if x < 0.032:
        return KH * 0.5 + (HALF - KH * 0.5) * smooth01((x - 0.004) / 0.028)
    if x < XB - 0.022:
        return HALF
    if x < XB:
        return HALF - 0.0045 * math.sin(math.pi * (x - (XB - 0.022)) / 0.022)
    if x < XB + 0.016:
        return HALF + (STRAP_H * 0.82 - HALF) * ((x - XB) / 0.016) ** 0.8
    return max(STRAP_H * 0.82 * (1.0 - (x - XB - 0.016) / (TIP - XB - 0.016)), 0.0007)


def ridge(x):
    # 창 날은 가운데 등이 솟는다(두드려 세운 날) — 면마다 한 빛이라 위 날은 밝고 밑 날은 어둡다
    return 0.0055 * smooth01((x - XB + 0.004) / 0.012) if x > XB - 0.004 else 0.0


XS = sorted(set([round(0.004 + 0.003 * k, 5) for k in range(int((TIP - 0.004) / 0.003) + 1)]
                + [XB - 0.022, XB - 0.011, XB, XB + 0.016, TIP]))
TS = [-1.0, -0.82, -0.52, -0.22, 0.0, 0.22, 0.52, 0.82, 1.0]
PROF = [0.30, 0.74, 0.94, 1.0, 1.0, 1.0, 0.94, 0.74, 0.30]
rings = []
for i, x in enumerate(XS):
    h = strap_h(x)
    rg = ridge(x)
    ring = [Vector((x, -h, 0.0))]
    for t, pz in zip(TS, PROF):
        j = 0.0
        if abs(t) < 0.9 and 0 < i < len(XS) - 1:
            j = random.uniform(-0.0007, 0.0007)     # 망치 자국 — 3mm 마다 높낮이가 1mm 안쪽으로 흔들린다
        ring.append(Vector((x, t * h, T * pz + rg * (1.0 - abs(t)) + j)))
    ring.append(Vector((x, h, 0.0)))
    rings.append(ring)
grid(strap, rings, IRON, flat_fn=lambda i: XS[i] >= XB)

# 못 머리 — 둥근 돔(망치로 친 머리)
for x in (0.04, 0.14, 0.24):
    dome(strap, 0.0072, 0.0048, (x, 0.0, T - 0.0004), STUD, seg=12)
# 경첩 눈 — 띠 끝을 말아 감은 통(속에 핀 구멍). 문짝과 같이 돈다.
lathe(strap, [(0.0036, -KH * 0.5), (0.0094, -KH * 0.5), (0.0110, -KH * 0.5 + 0.0016), (0.0110, KH * 0.5 - 0.0016),
              (0.0094, KH * 0.5), (0.0036, KH * 0.5)], (0.002, 0.0, 0.010), KNUCK, seg=14, axis="y")

# ══ Pintle — 문틀 쪽 통 · 핀 · 핀 판 ═══════════════════════════════
random.seed(6040)
pin = Piece("Pintle")
KZ = FACE + 0.010
for s in (-1.0, 1.0):
    lathe(pin, [(0.0036, -KH * 0.5), (0.0094, -KH * 0.5), (0.0110, -KH * 0.5 + 0.0016), (0.0110, KH * 0.5 - 0.0016),
                (0.0094, KH * 0.5), (0.0036, KH * 0.5)], (0.002, s * (KH + 0.003), KZ), KNUCK, seg=14, axis="y")
# 핀 — 통 사이 틈으로 1px 비친다 · 위는 둥근 머리 · 밑은 두드린 끝
PY = KH * 1.5 + 0.003
lathe(pin, [(0.0001, -PY), (0.0040, -PY), (0.0040, PY), (0.0001, PY)], (0.002, 0.0, KZ), STUD, seg=10, axis="y")
dome(pin, 0.0066, 0.0042, (0.002, PY - 0.0004, KZ), STUD, seg=12, axis="y")
dome(pin, 0.0048, 0.0022, (0.002, -PY + 0.0004, KZ), STUD, seg=10, axis="y", s=-1.0)
# 핀 판 — 문틀 앞면(CASE_Z)에 눕고 먼 끝은 둥글다 · 문 쪽 끝은 모서리를 감아 문틀 안벽으로 든다
PH = STRAP_H * 0.42
PX0 = -CASE_W + 0.010


def pin_h(x):
    if x < PX0 + PH:
        return math.sqrt(max(PH ** 2 - (PX0 + PH - x) ** 2, 0.0)) if x > PX0 else 0.0007
    return PH


xs = [PX0 + 0.0002] + [PX0 + PH * (1.0 - math.cos(math.radians(a))) for a in range(10, 91, 10)]
xs += [PX0 + PH + 0.003 * k for k in range(1, int((0.004 - PX0 - PH) / 0.003) + 1)] + [0.004]
xs = sorted(set(round(x, 5) for x in xs))
rings = []
TP = 0.005
for i, x in enumerate(xs):
    h = max(pin_h(x), 0.0007)
    ring = [Vector((x, -h, CASE_Z))]
    for t, pz in zip(TS, PROF):
        j = random.uniform(-0.0006, 0.0006) if (abs(t) < 0.9 and 0 < i < len(xs) - 1) else 0.0
        ring.append(Vector((x, t * h, CASE_Z + TP * pz + j)))
    ring.append(Vector((x, h, CASE_Z)))
    rings.append(ring)
grid(pin, rings, IRON)
# 감아 든 다리 — 문틀 안벽(x 0 면 · 앞이 +x)에 붙은 짧은 판. 눕혀 지은 판을 y 축으로 돌려 세운다(판의 x → 뒤 −z ·
# 두께 z → +x).
n0 = len(pin.bm.verts)
plate(pin, lambda y: 0.015, -PH, PH, 0.0, TP, KNUCK, bev=0.0018, cx=0.015)
pin.bm.verts.ensure_lookup_table()
M = Matrix(((0.0, 0.0, 1.0, 0.0), (0.0, 1.0, 0.0, 0.0), (-1.0, 0.0, 0.0, CASE_Z + TP - 0.0005), (0.0, 0.0, 0.0, 1.0)))
bmesh.ops.transform(pin.bm, matrix=M, verts=pin.bm.verts[n0:])
for x in (PX0 + 0.012, -0.014):
    dome(pin, 0.0056, 0.0036, (x, 0.0, CASE_Z + TP - 0.0004), STUD, seg=12)

obs = [pull.done(), strap.done(), pin.done()]
for o in obs:
    print(o.name, "tris", sum(len(p.vertices) - 2 for p in o.data.polygons))

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.context.view_layer.update()        # 새로 단 물체의 바탕(base)이 서야 고를 수 있다
for o in bpy.context.view_layer.objects:
    o.select_set(o in obs)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True,
                          export_yup=True, export_animations=False, export_cameras=False, export_lights=False,
                          export_tangents=True)
print("wrote", OUT)

if PREVIEW:
    # 문 앞에서 본 그림 — 조각을 문 위 제자리에 앉힌다(x0 −0.275 · 문 앞면 −0.03 · 손잡이 hx 0.605)
    X0 = -0.275
    hy_mid = (-0.06 - 0.34) * 0.5
    put = {"Pull": [(0.605, hy_mid, FACE)], "Strap": [(X0, 0.21, FACE), (X0, -0.32, FACE)],
           "Pintle": [(X0, 0.21, 0.0), (X0, -0.32, 0.0)]}
    for o in list(obs):
        for k, (x, y, z) in enumerate(put[o.name]):
            ob = o if k == 0 else bpy.data.objects.new(o.name + "2", o.data)
            if k:
                bpy.context.collection.objects.link(ob)
            ob.location = Vector((x, -z, y))
    door = bpy.data.objects.new("door", bpy.data.meshes.new("door"))
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector((0.95, 0.01, 1.4)), verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector((0.20, 0.03 + 0.005, -0.3)), verts=bm.verts)
    bm.to_mesh(door.data)
    bm.free()
    door.data.materials.append(mat("wood", (0.25, 0.16, 0.08)))
    bpy.context.collection.objects.link(door)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 1.0
    cam.location = Vector((0.20, -3.0, -0.05))
    cam.rotation_euler = (math.radians(90.0), 0.0, 0.0)
    scene.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 4.0
    sun.rotation_euler = (math.radians(55.0), math.radians(-20.0), math.radians(-15.0))
    scene.collection.objects.link(sun)
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 720
    scene.render.resolution_y = 720
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.04, 0.05, 1.0)
    scene.world = w
    scene.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
    print("preview", PREVIEW)
