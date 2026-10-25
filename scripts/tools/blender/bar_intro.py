# 바에서 눈 뜨는 인트로 소품 — Blender(bpy)로 짓고 glb 하나로 내보낸다 (2026-10-25 「모델링은 최대한 하고 좀 이팩트같은걸로
# 가려야 될거 같은데?」 · 판지 outputs/prologue/bar_board).
#
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup \
#       --python scripts/tools/blender/bar_intro.py -- [--preview 폴더]
#
# 굳은 몸만 짓는다 — 움직이는 것(팔뚝 · 손 · 잔 돌리기 · 천 꼬리 갈아 끼우기 · TV 기울기)은 게임이 노드로 옮긴다.
# 좌표는 게임 그대로(m · x 오른쪽 · y 위 · z 앞 — 손님 쪽이 +z) · Blender 로는 (x, −z, y). 오브젝트마다 제 원점에 선다:
#   BarTorso        상인 허리 ~ 깃(머리 없음 · 깃 안은 void 마개) · 셔츠 · 조끼(단추 다섯 · 웰트 주머니 셋 · 회중시계 줄 ·
#                   공단 깃) · 허리띠 · 위팔(셔츠 소매 · 놋쇠 소매 띠). 원점 = 발 밑 바닥 한가운데 · 얼굴이 +z.
#                   팔꿈치 ElbowR(−x) · ElbowL(+x) 빈 노드 — game.gd _fore3_build 의 팔뚝 뿌리(팔꿈치)가 여기 선다.
#   PolishGlass     상인이 닦는 빈 파인트(곧은 셰이커) · 원점 = 밑바닥 한가운데 · 축 +y
#   TowelWrap       닦는 잔을 감싼 바 천(밑동 감쌈 · 말린 테) — PolishGlass 와 같은 원점 · 같이 돈다
#   TowelBand       엄지 밑 뭉치에서 안벽을 타고 테를 넘는 납작한 천 자락(한 색) — 같은 원점 · 잔 좌표 +x 쪽(게임이 집는
#                   자리로 돌린다)
#   TowelTail_A/B/C 받치는 손 밑으로 늘어진 천 꼬리 셋(곧게 · +x 로 · −x 로 비튼) · 원점 = 꼬리 윗끝(모인 자리) · −y 로
#                   늘어진다(늘 세계 위를 보게 둔다 — 잔을 따라 기울지 않는다)
#   Pint · PintBeer 손님 앞 반 남은 논익 파인트 — 유리(glass) / 맥주 · 거품(beer · foam) · 원점 = 잔 밑바닥
#   Coaster         판지 받침 지름 10cm · 두께 2.2mm · 원점 = 밑면 한가운데(잔은 y 0.0022 에 선다)
#   BarCrt          천장 TV(14″ 브라운관) + 받침 띠 · 쟁반(TV 와 같이 기운다) · 원점 = 기울기 축(양옆 손잡이 축 한가운데) ·
#                   화면 유리 재질 crt_glass(UV 0..1 = 화면 칸) · TV 앞면이 +z
#   TvMount         천장 판 · 늘어진 관 · 높이 손잡이 · 멍에(거꾸로 된 U) · 축 손잡이 · 관을 타고 내려가 TV 뒤로 드는 줄 ·
#                   원점 = 천장 면(판 윗면 한가운데) · 기울기 축은 (0, PIVOT_Y, 0)
#   CntRail         카운터 손님 쪽 팔걸이(시카고 쇠시리 — 둥근 등 · 둥근 코 · 물받이 홈) + 윗판과의 이음 줄 · 길이 1(x −0.5..0.5 —
#                   게임이 늘린다) · 원점은 CntNose 와 같다(앞판보다 0.08 앞 · 윗판 윗면 높이)
#   BarMat          고무 레일 매트 69 × 8.3cm · 돌기 격자 · 원점 = 밑면 한가운데(긴 쪽이 x)
#   NutBowl         나무 그릇 · 땅콩 한 줌 · 원점 = 밑면 한가운데
# 재질은 이름만(게임이 이름으로 제 셰이더를 끼운다 — 이 미리보기 빛깔은 참고):
#   shirt · shirt_btn · vest · lapel · vest_back · trousers · belt · brass · chain · void(깃 안 · 주머니 틈 — 먹) ·
#   cloth · cloth_stripe · glass · beer · foam · coaster · coaster_ink · coaster_wet · card ·
#   crt_body · crt_bezel · crt_glass · crt_btn · crt_led · crt_grille · iron · knob · cable · rail · wood_dk ·
#   rubber · wood · nut · frost · tin
#   PendDiffuser    펜던트 갓 안 젖빛 접시(인트로에서만 · bar_props Lamp 와 같은 원점 — 갓마다 같은 자리에 끼운다)
#   GlassRack       천장에 매단 잔 걸이(레일 셋 · 거꾸로 걸린 와인잔 여덟) · 원점 = 천장 면 · 잔 테가 0.33 밑
#   TinTile         눌러 찍은 양철 천장 판 61cm(밑으로 솟는 구슬 · 꽃) · 원점 = 판 한가운데 천장 면 · 게임이 깔아 잇는다
#   UpperArmR/L     위팔(셔츠 소매 · 놋쇠 소매 띠) · 원점 = 어깨 관절 · 팔꿈치 (0, −L_UA, 0) — BarTorso 의 ShoulderR/L 에 세운다
# 화면에서 1cm 가 1.5 ~ 15px(상인 1.3m 3px · 코앞 잔 0.25m 15px · 천장 TV 1.7m 2.3px) — 모서리는 깎아서 빛 단이 테에
# 한 줄 서게 한다(그 줄이 낮은 해상도에서 「잘 지은 물건」을 판다). 사람 비는 손 표(game.gd HAND3 — 손 길이 19cm ·
# 너클 폭 10.2cm · 팔뚝 11.8cm · 위팔 13cm)에 맞춘다: 가슴 37 : 위팔 13 : 팔뚝 11.8 : 손 10.2 = 3.2 : 1.1 : 1.0 : 0.86.
import bpy
import bmesh
import math
import os
import random
import sys
from mathutils import Vector, Matrix, noise

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "assets", "models", "bar_intro.glb")

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


SHIRT = mat("shirt", (0.42, 0.50, 0.66))          # game.gd SHIRT3(174,188,212) — 식은 크림
SHIRT_BTN = mat("shirt_btn", (0.80, 0.78, 0.72))
VEST = mat("vest", (0.032, 0.034, 0.078))         # game.gd VEST3.vest(50,52,78)
LAPEL = mat("lapel", (0.021, 0.023, 0.052), 0.0, 0.3)
VEST_BACK = mat("vest_back", (0.03, 0.02, 0.03), 0.0, 0.3)
TROUSERS = mat("trousers", (0.02, 0.02, 0.025))
BELT = mat("belt", (0.05, 0.025, 0.015), 0.0, 0.4)
BRASS = mat("brass", (0.58, 0.32, 0.09), 0.85, 0.25)
CHAIN = mat("chain", (0.87, 0.54, 0.09), 0.9, 0.2)
VOID = mat("void", (0.0, 0.0, 0.0))
CLOTH = mat("cloth", (0.74, 0.70, 0.58))
STRIPE = mat("cloth_stripe", (0.30, 0.16, 0.08))
GLASS = mat("glass", (0.70, 0.76, 0.76), 0.0, 0.05)
BEER = mat("beer", (0.65, 0.25, 0.03))
FOAM = mat("foam", (0.90, 0.85, 0.70))
COASTER = mat("coaster", (0.62, 0.52, 0.36))
INK = mat("coaster_ink", (0.30, 0.04, 0.04))
WET = mat("coaster_wet", (0.36, 0.27, 0.16))
CARD = mat("card", (0.84, 0.80, 0.70))
CRT_BODY = mat("crt_body", (0.035, 0.035, 0.04), 0.0, 0.45)
CRT_BEZEL = mat("crt_bezel", (0.008, 0.008, 0.01))
CRT_GLASS = mat("crt_glass", (0.015, 0.02, 0.022), 0.0, 0.08)
CRT_BTN = mat("crt_btn", (0.08, 0.08, 0.09), 0.0, 0.4)
CRT_LED = mat("crt_led", (0.8, 0.02, 0.02))
CRT_GRILLE = mat("crt_grille", (0.005, 0.005, 0.006))
IRON = mat("iron", (0.03, 0.025, 0.028), 0.6, 0.4)
KNOB = mat("knob", (0.02, 0.02, 0.022), 0.0, 0.35)
CABLE = mat("cable", (0.008, 0.008, 0.008), 0.0, 0.5)
RAIL = mat("rail", (0.12, 0.04, 0.01), 0.0, 0.2)     # 팔걸이 니스 — 둥근 등이라 게임은 빛 단 + 가는 반짝 줄(넓은 니스 반짝은 큰 크림 원판이 된다)
WOOD_DK = mat("wood_dk", (0.03, 0.008, 0.002))
RUBBER = mat("rubber", (0.012, 0.012, 0.012), 0.0, 0.8)
WOOD = mat("wood", (0.11, 0.035, 0.008))
NUT = mat("nut", (0.50, 0.28, 0.10))

CUR = []


def G(x, y, z):
    """게임 좌표 → Blender 좌표"""
    return Vector((x, -z, y))


def V3(x, y, z):
    return Vector((x, y, z))


def link(ob, mats):
    bpy.context.collection.objects.link(ob)
    for m in (mats if isinstance(mats, (list, tuple)) else [mats]):
        if m is not None:
            ob.data.materials.append(m)
    CUR.append(ob)
    return ob


def from_bm(name, bm, mats, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new(name, me), mats)
    for p in ob.data.polygons:
        p.use_smooth = smooth
    return ob


def orient_closed(bm):
    """닫힌 몸 — 부호 있는 부피가 음이면 면을 다 뒤집는다(게임은 뒷면을 안 그린다)."""
    s = 0.0
    for f in bm.faces:
        f.normal_update()
        s += f.calc_center_median().dot(f.normal) * f.calc_area()
    if s < 0.0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])


def sgnpow(v, e):
    return math.copysign(abs(v) ** e, v)


def lerp(a, b, t):
    return a + (b - a) * t


def smooth01(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3.0 - 2.0 * t)


def table(ys, vs, y):
    if y <= ys[0]:
        return vs[0]
    for i in range(1, len(ys)):
        if y <= ys[i]:
            t = (y - ys[i - 1]) / (ys[i] - ys[i - 1])
            return lerp(vs[i - 1], vs[i], t)
    return vs[-1]


def box(name, size, at, m, bevel=0.0, seg=1, rot=None):
    """size (x, y, z) · at 가운데(게임 좌표) · rot (게임 축 x 둘레 도)"""
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    bmesh.ops.scale(bm, vec=Vector((size[0], size[2], size[1])), verts=bm.verts)
    if bevel > 0.0:
        bmesh.ops.bevel(bm, geom=bm.edges[:] + bm.verts[:], offset=bevel, segments=seg, affect="EDGES", profile=0.5)
    if rot is not None:
        bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(math.radians(rot), 3, "X"))
    bmesh.ops.translate(bm, vec=G(*at), verts=bm.verts)
    return from_bm(name, bm, m, smooth=seg > 1)


def lathe(name, prof, at, m, seg=16, axis="y", basis=None, mats=None, matf=None):
    """prof [(반지름, 높이)] — 축으로 돌린 회전체(윤곽 두 끝이 축 위면 닫힌 몸). axis y(위) · x(옆) · z(앞).
    basis — 게임 좌표 3x3(축 y 를 어디로 세울지). matf(r, y) → mats 차례(면 한가운데의 반지름 · 높이로 재질을 고른다)."""
    bm = bmesh.new()
    vs = [bm.verts.new(Vector((r, 0.0, y))) for r, y in prof]
    for a, b in zip(vs, vs[1:]):
        bm.edges.new((a, b))
    bmesh.ops.spin(bm, geom=bm.verts[:] + bm.edges[:], cent=Vector((0, 0, 0)), axis=Vector((0, 0, 1)),
                   angle=math.tau, steps=seg, use_merge=True)
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
    if matf is not None:
        for f in bm.faces:
            c = f.calc_center_median()
            f.material_index = matf(math.hypot(c.x, c.y), c.z)
    # 지금 Blender 축 z 가 회전축이다 — 게임 y 로 세운다(Blender (x, y, z) = 게임 (x, −z, y) 이므로 그대로 게임 y = Blender z)
    if basis is not None:
        # 게임 basis(열: 게임 축 x' y' z') — Blender 로 옮긴 행렬
        Bm = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
        Bi = Bm.inverted()
        bmesh.ops.transform(bm, verts=bm.verts, matrix=(Bm @ basis @ Bi).to_4x4())
    elif axis == "x":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(math.radians(90.0), 3, "Y"))
    elif axis == "z":
        bmesh.ops.rotate(bm, verts=bm.verts, cent=Vector((0, 0, 0)), matrix=Matrix.Rotation(math.radians(90.0), 3, "X"))
    bmesh.ops.translate(bm, vec=G(*at), verts=bm.verts)
    orient_closed(bm) if (prof[0][0] < 1e-9 and prof[-1][0] < 1e-9) else None
    return from_bm(name, bm, mats if mats is not None else m)


def basis_y_to(n):
    """게임 축 y 를 n 으로 세우는 3x3(게임 좌표)."""
    n = n.normalized()
    a = Vector((0, 0, 1)) if abs(n.z) < 0.9 else Vector((1, 0, 0))
    x = a.cross(n).normalized()
    z = x.cross(n).normalized()
    return Matrix((x, n, z)).transposed()


def ring_loft(name, rings, m, cap0="flat", cap1="flat", smooth=True, matf=None, mats=None):
    """rings — 게임 Vector 고리들(점 수가 같다). cap: None 열림 · 'flat' · Vector 꼭지(게임)."""
    bm = bmesh.new()
    rs = [[bm.verts.new(G(*p)) for p in r] for r in rings]
    n = len(rings[0])
    for k, (a, b) in enumerate(zip(rs, rs[1:])):
        for i in range(n):
            j = (i + 1) % n
            f = bm.faces.new((a[i], a[j], b[j], b[i]))
            if matf is not None:
                f.material_index = matf(k, i)
    for cap, r, first in ((cap0, rs[0], True), (cap1, rs[-1], False)):
        if cap is None:
            continue
        if cap == "flat":
            bm.faces.new(r[::-1] if first else r)
        else:
            c = bm.verts.new(G(*cap))
            for i in range(n):
                j = (i + 1) % n
                bm.faces.new((r[j], r[i], c) if first else (r[i], r[j], c))
    if cap0 is not None and cap1 is not None:
        orient_closed(bm)
    return from_bm(name, bm, mats if mats is not None else m, smooth)


def shell(name, base, nu, nv, t, m, k=0.0, wrap_u=False, matf=None, mats=None, smooth=True, h=1e-3):
    """두께 있는 판 · 천 — base(u, v) → 게임 Vector(또는 (점, 바깥 법선)). 겉은 법선 쪽 t·(1−k) · 안은 t·k.
    wrap_u 면 u 가 고리로 닫힌다. matf(u, v) → mats 차례."""
    def ev(u, v):
        r = base(u, v)
        return r if isinstance(r, tuple) else (r, None)

    def nrm(u, v):
        p, n = ev(u, v)
        if n is not None:
            return p, n.normalized()
        if wrap_u:
            ua, ub = u - h, u + h
        else:
            ua, ub = max(u - h, 0.0), min(u + h, 1.0)
        va, vb = max(v - h, 0.0), min(v + h, 1.0)
        tu = ev(ub, v)[0] - ev(ua, v)[0]
        tv = ev(u, vb)[0] - ev(u, va)[0]
        n = tu.cross(tv)
        return p, (n.normalized() if n.length > 1e-12 else Vector((0, 1, 0)))

    nU = nu if wrap_u else nu + 1
    bm = bmesh.new()
    O, I = [], []
    for i in range(nU):
        ro, ri = [], []
        for j in range(nv + 1):
            p, n = nrm(i / nu, j / nv)
            ro.append(bm.verts.new(G(*(p + n * t * (1.0 - k)))))
            ri.append(bm.verts.new(G(*(p - n * t * k))))
        O.append(ro)
        I.append(ri)
    for i in range(nu):
        i2 = (i + 1) % nU if wrap_u else i + 1
        for j in range(nv):
            mi = matf((i + 0.5) / nu, (j + 0.5) / nv) if matf is not None else 0
            bm.faces.new((O[i][j], O[i2][j], O[i2][j + 1], O[i][j + 1])).material_index = mi
            bm.faces.new((I[i][j + 1], I[i2][j + 1], I[i2][j], I[i][j])).material_index = mi
        bm.faces.new((O[i2][0], O[i][0], I[i][0], I[i2][0]))
        bm.faces.new((O[i][nv], O[i2][nv], I[i2][nv], I[i][nv]))
    if not wrap_u:
        for j in range(nv):
            bm.faces.new((O[0][j], O[0][j + 1], I[0][j + 1], I[0][j]))
            bm.faces.new((O[nu][j + 1], O[nu][j], I[nu][j], I[nu][j + 1]))
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-7)
    orient_closed(bm)
    return from_bm(name, bm, mats if mats is not None else m, smooth)


def frames(pts, ref):
    """꺾은선의 틀(평행 이동) — T 접선 · N(ref 쪽) · B = T × N."""
    T = []
    for i in range(len(pts)):
        a = pts[max(i - 1, 0)]
        b = pts[min(i + 1, len(pts) - 1)]
        T.append((b - a).normalized())
    n0 = ref - T[0] * ref.dot(T[0])
    if n0.length < 1e-6:
        n0 = Vector((1, 0, 0)) - T[0] * T[0].x
    N = [n0.normalized()]
    for i in range(1, len(pts)):
        q = T[i - 1].rotation_difference(T[i])
        n = q @ N[-1]
        n = (n - T[i] * n.dot(T[i])).normalized()
        N.append(n)
    B = [T[i].cross(N[i]).normalized() for i in range(len(pts))]
    return T, N, B


def tube_path(name, pts, secf, m, n=12, cap0=0.0, cap1=0.0, ref=Vector((0, 0, 1)), smooth=True, mats=None,
              matf=None):
    """pts 게임 Vector 꺾은선 · secf(i, q) → (w(B 쪽 폭), t(N 쪽 두께), 모서리 지수, 물결 세기, 물결 수, 물결 위상).
    cap: None 열림 · 0 평평 · 양수 그 길이의 둥근 마개."""
    T, N, B = frames(pts, ref)
    L = [0.0]
    for a, b in zip(pts, pts[1:]):
        L.append(L[-1] + (b - a).length)
    tot = max(L[-1], 1e-9)
    rings = []
    secs = []
    for i, c in enumerate(pts):
        w, t, sq, amp, kk, ph = secf(i, L[i] / tot)
        secs.append((w, t, sq, amp, kk, ph))
        r = []
        for k in range(n):
            th = math.tau * k / n
            ex, ey = sgnpow(math.cos(th), 2.0 / sq), sgnpow(math.sin(th), 2.0 / sq)
            rs = 1.0 + amp * math.sin(kk * th + ph)
            r.append(c + B[i] * (ex * w * 0.5 * rs) + N[i] * (ey * t * 0.5 * rs))
        rings.append(r)

    def dome(end):
        i = 0 if end == 0 else len(pts) - 1
        ln = cap0 if end == 0 else cap1
        sgn = -1.0 if end == 0 else 1.0
        c = pts[i]
        out = []
        for s in (0.38, 0.7, 0.92):
            a = s * math.pi * 0.5
            sc = math.cos(a)
            off = T[i] * (sgn * ln * math.sin(a))
            out.append([c + off + (p - c) * sc for p in rings[i]])
        return out, c + T[i] * (sgn * ln)

    c0 = c1 = None
    if cap0 is not None and cap0 > 0.0:
        d, c0 = dome(0)
        rings = d[::-1] + rings
    if cap1 is not None and cap1 > 0.0:
        d, c1 = dome(1)
        rings = rings + d
    return ring_loft(name, rings, m, None if cap0 is None else (c0 if c0 is not None else "flat"),
                     None if cap1 is None else (c1 if c1 is not None else "flat"), smooth, matf, mats)


def along(pts, L, d):
    """꺾은선에서 길이 d 자리의 점."""
    for i in range(1, len(pts)):
        if L[i] >= d:
            t = (d - L[i - 1]) / max(L[i] - L[i - 1], 1e-9)
            return pts[i - 1].lerp(pts[i], t)
    return pts[-1]


def crs(ctrl, per=8):
    """Catmull-Rom — 점들을 지나는 매끈한 꺾은선(게임 Vector)."""
    P = [ctrl[0]] + list(ctrl) + [ctrl[-1]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for s in range(per):
            t = s / per
            t2, t3 = t * t, t * t * t
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
                              (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
    out.append(ctrl[-1])
    return out


def ellipsoid(name, c, r, m, sub=2, lump=0.0, seed=0.0, freq=4.0):
    """찌그러진 공 — 반지름 r(x, y, z) · lump 만큼 잡음으로 울퉁불퉁."""
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=1.0)
    for v in bm.verts:
        d = v.co.normalized()
        k = 1.0 + lump * noise.noise(d * freq + Vector((seed, seed * 0.7, seed * 1.3)))
        g = V3(d.x, d.z, -d.y)   # Blender 방향 → 게임 방향
        p = V3(g.x * r[0] * k, g.y * r[1] * k, g.z * r[2] * k) + c
        v.co = G(*p)
    orient_closed(bm)
    return from_bm(name, bm, m)


def finish(name, angle=35.0):
    """지금 조각들을 한 몸으로 — 매끈함은 각으로 가른다."""
    global CUR
    obs = [o for o in CUR if o.type == "MESH"]
    for o in bpy.context.collection.objects:
        o.select_set(False)
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    if len(obs) > 1:
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
    bb = [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    lo = Vector((min(p.x for p in bb), min(p.z for p in bb), min(-p.y for p in bb)))
    hi = Vector((max(p.x for p in bb), max(p.z for p in bb), max(-p.y for p in bb)))
    print("%-14s tris %6d  game AABB (%.3f %.3f %.3f) .. (%.3f %.3f %.3f)" % (
        name, sum(len(p.vertices) - 2 for p in ob.data.polygons), lo.x, lo.y, lo.z, hi.x, hi.y, hi.z))
    CUR = []
    return ob


def empty(name, at, parent):
    e = bpy.data.objects.new(name, None)
    e.empty_display_size = 0.03
    bpy.context.collection.objects.link(e)
    e.parent = parent
    e.location = G(*at)
    e["done"] = 1
    return e


# ══ 상인 — 허리 ~ 깃 · 위팔 ═══════════════════════════════════════════
#  몸통 단면(높이 y → 반 폭 · 반 두께 · 앞으로 나온 몫 · 모서리 지수). 가슴(겨드랑이 1.33) 반 폭 0.165 = 가슴 33cm(사진:
#  겨드랑이 높이 가슴 32cm). 0.186 이던 통짜 조끼에 위팔 반쪽이 묻혀 보이는 몸통 : 위팔 폭이 6:1 — 가는 관 팔이 달린
#  마네킹이었다(검토 3). 허리는 더 좁힌다. 어깨는 둥근 지붕으로 목밑(1.508 · 반 폭 0.07)까지 좁아든다 — 팔 머리(삼각근)는
#  위팔 마개가 짓는다(어깨 관절은 가슴 옆 밖 — S_R).
TY = [0.85, 0.93, 0.99, 1.05, 1.12, 1.20, 1.27, 1.33, 1.38, 1.42, 1.452, 1.478, 1.495, 1.508]
THW = [0.166, 0.160, 0.154, 0.150, 0.150, 0.155, 0.162, 0.165, 0.165, 0.160, 0.145, 0.112, 0.085, 0.070]
THD = [0.112, 0.112, 0.110, 0.108, 0.110, 0.116, 0.122, 0.123, 0.118, 0.108, 0.094, 0.082, 0.072, 0.066]
TCZ = [0.000, 0.002, 0.004, 0.006, 0.009, 0.013, 0.017, 0.018, 0.015, 0.008, 0.002, -0.003, -0.006, -0.008]
TSQ = [2.5, 2.5, 2.5, 2.5, 2.6, 2.7, 2.8, 2.8, 2.7, 2.5, 2.3, 2.1, 2.0, 2.0]


def _tp(phi, y):
    """몸통 겉의 한 점 — phi 0 이 앞(+z) · π/2 가 +x 옆."""
    hw, hd, cz, sq = table(TY, THW, y), table(TY, THD, y), table(TY, TCZ, y), table(TY, TSQ, y)
    return V3(hw * sgnpow(math.sin(phi), 2.0 / sq), y, cz + hd * sgnpow(math.cos(phi), 2.0 / sq))


def torso_n(phi, y):
    e = 1e-3
    tp = _tp(phi + e, y) - _tp(phi - e, y)
    ty = _tp(phi, y + e) - _tp(phi, y - e)
    n = ty.cross(tp)
    p = _tp(phi, y)
    if n.dot(V3(p.x, 0.0, p.z - table(TY, TCZ, y))) < 0.0:
        n = -n
    return n.normalized()


def torso_at(phi, y, off):
    return _tp(phi, y) + torso_n(phi, y) * off


def phi_of_x(x, y):
    """몸통 앞 반쪽에서 x 에 선 점의 phi(−π/2 .. π/2)."""
    lo, hi = -math.pi * 0.5, math.pi * 0.5
    for _ in range(40):
        mid = (lo + hi) * 0.5
        if _tp(mid, y).x < x:
            lo = mid
        else:
            hi = mid
    return (lo + hi) * 0.5


# ── 셔츠 몸 · 바지 ──
#  셔츠 겨드랑이 옆구리 — 진동(조끼 팔 구멍) 밑 8~10cm 가 셔츠로 보인다. 겨드랑이에서 비스듬히 내려가는 골.
def shirt_ripple(phi, y):
    side = math.exp(-((abs(phi) - math.pi * 0.5) / 0.45) ** 2)
    pit = smooth01(1.15, 1.25, y) * (1.0 - smooth01(1.40, 1.45, y))
    return 0.0035 * math.sin(phi * 13.0 + y * 55.0) * side * pit


NR = 72
rings = []
y = 0.955
ys = []
while y < 1.508:
    ys.append(y)
    y += 0.008
ys.append(1.508)
for yy in ys:
    rings.append([torso_at(math.tau * i / NR, yy, shirt_ripple(math.tau * i / NR, yy)) for i in range(NR)])
ring_loft("shirt_body", rings, SHIRT)
rings = [[torso_at(math.tau * i / NR, yy, 0.0045) for i in range(NR)] for yy in (0.85, 0.90, 0.95, 0.993)]
ring_loft("trousers", rings, TROUSERS)

#  허리띠 — 바지 허리 위 · 조끼 끝 사이로 · 버클은 조끼 뾰족 둘 사이 홈에서 비친다
shell("belt", lambda u, v: (torso_at(math.tau * u, lerp(0.966, 1.003, v), 0.0055), torso_n(math.tau * u, 0.985)),
      NR, 3, 0.003, BELT, wrap_u=True)
for (sx, sy, cx, cy) in ((0.044, 0.007, 0.0, 0.9995), (0.044, 0.007, 0.0, 0.9695), (0.007, 0.037, -0.0185, 0.9845),
                         (0.007, 0.037, 0.0185, 0.9845)):
    box("buckle", (sx, sy, 0.005), (cx, cy, table(TY, TCZ, 0.985) + table(TY, THD, 0.985) + 0.010), BRASS, 0.0016, 2)
box("prong", (0.026, 0.0035, 0.004), (0.004, 0.9845, table(TY, TCZ, 0.985) + table(TY, THD, 0.985) + 0.0115), BRASS,
    0.0012, 2)

# ── 조끼 ──
Y_V = 1.268        # V 꼭짓점(첫 단추) — 깃 홈 밑 23cm
Y_T = 1.492        # 어깨 끈 윗변(목밑)
Y_AH, Y_AT = 1.205, 1.420     # 진동(팔 구멍) 밑 · 위
OFF_U, OFF_O = 0.0065, 0.0100   # 밑판(+x · 입은 사람 왼쪽) · 윗판(−x · 오른쪽이 왼쪽 위로 여민다)
VT = 0.0035        # 조끼 천 두께


def x_edge(y, top):
    """앞 끝(제 쪽 x — +x 판 기준). V 밑에서는 가운데 너머로 겹친다."""
    if y <= Y_V:
        return -0.0135 if top else -0.011
    return 0.004 + (y - Y_V) / (Y_T - Y_V) * 0.060


def phi_e(y):
    """앞판 바깥 끝 — 진동 앞 테(Y_AH..Y_AT) · 그 밖은 옆 솔기."""
    if Y_AH < y < Y_AT:
        t = (y - Y_AH) / (Y_AT - Y_AH)
        return math.radians(103.0 - 46.0 * math.sin(math.pi * t) ** 0.7)
    return math.radians(103.0)


YB_U = [0.0, 0.05, 0.14, 0.30, 0.55, 1.0]
YB_Y = [0.990, 0.975, 0.948, 0.975, 0.995, 1.005]   # 앞판 밑단 — 가운데 홈 · 뾰족 · 옆으로 오른다


def vest_front(s):
    top = s < 0.0
    off = OFF_O if top else OFF_U

    def base(u, v):
        y = lerp(table(YB_U, YB_Y, u), Y_T, v)
        p0 = phi_of_x(x_edge(y, top), y)
        ph = lerp(p0, phi_e(y), u)
        p = torso_at(ph, y, off)
        n = torso_n(ph, y)
        return V3(p.x * s, p.y, p.z), V3(n.x * s, n.y, n.z)
    return base


for s in (1.0, -1.0):
    shell("vest_front", vest_front(s), 30, 56, VT, VEST)


def phi_b(y):
    if Y_AH < y < Y_AT:
        t = (y - Y_AH) / (Y_AT - Y_AH)
        return math.radians(99.0 + 34.0 * math.sin(math.pi * t) ** 0.7)
    return math.radians(99.0)


def vest_back(u, v):
    y = lerp(1.000, Y_T, v)
    ph = lerp(phi_b(y), math.tau - phi_b(y), u)
    return torso_at(ph, y, OFF_U - 0.0013), torso_n(ph, y)


shell("vest_back", vest_back, 40, 40, VT, VEST_BACK)

#  공단 깃 — V 테를 따라 3cm · 한 단 솟는다(빛 단이 테에 한 줄 선다)
for s in (1.0, -1.0):
    top = s < 0.0
    off = (OFF_O if top else OFF_U) + VT + 0.0004

    def lap(u, v, s=s, top=top, off=off):
        y = lerp(Y_V - 0.010, Y_T, v)
        x0 = x_edge(y, top)
        w = 0.002 + 0.030 * smooth01(Y_V - 0.010, Y_V + 0.05, y)
        ph = phi_of_x(x0 + w * u, y)
        p = torso_at(ph, y, off + 0.0025 * math.sin(math.pi * u))
        n = torso_n(ph, y)
        return V3(p.x * s, p.y, p.z), V3(n.x * s, n.y, n.z)
    shell("lapel", lap, 6, 26, 0.0022, LAPEL)

#  웰트 주머니 — 아래 둘(넷째 단추 높이 · 바깥이 7° 오른다) · 왼가슴 하나. 솟은 띠 + 그 위 먹 틈
POCKETS = [(1.0, 0.044, 0.148, 1.064, 7.0, 0.013), (-1.0, 0.044, 0.148, 1.064, 7.0, 0.013),
           (1.0, 0.064, 0.136, 1.300, 5.0, 0.011)]
for (s, x0, x1, y0, tilt, hh) in POCKETS:
    off = (OFF_O if s < 0 else OFF_U) + VT

    def welt(u, v, s=s, x0=x0, x1=x1, y0=y0, tilt=tilt, hh=hh, off=off, dy=0.0, hgt=None):
        x = lerp(x0, x1, u)
        y = y0 + (x - x0) * math.tan(math.radians(tilt)) + v * (hgt if hgt else hh) + dy
        ph = phi_of_x(x, y)
        p = torso_at(ph, y, off + 0.0003)
        n = torso_n(ph, y)
        return V3(p.x * s, p.y, p.z), V3(n.x * s, n.y, n.z)
    shell("welt", welt, 10, 2, 0.0026, VEST)
    shell("slit", lambda u, v, w=welt, hh=hh: w(u, v, dy=hh + 0.0002, hgt=0.0018), 10, 1, 0.0005, VOID)

#  단추 다섯 — 7cm 간격 · 맨 아래는 풀려 밑판(+x)에 비켜 앉는다
BTN_Y = [1.258, 1.192, 1.126, 1.060, 0.997]
BUT = [(0.0, 0.0028), (0.0060, 0.0028), (0.0072, 0.0018), (0.0068, 0.0006), (0.0, 0.0006)]
BUT = [(0.0, 0.0034), (0.0042, 0.0032), (0.0064, 0.0026), (0.0073, 0.0014), (0.0070, 0.0), (0.0, 0.0)]
for k, by in enumerate(BTN_Y):
    last = k == len(BTN_Y) - 1
    bx = 0.012 if last else 0.002
    ph = phi_of_x(bx, by)
    off = (OFF_U if last else OFF_O) + VT
    lathe("button", BUT, torso_at(ph, by, off), BRASS, 16, basis=basis_y_to(torso_n(ph, by)))

#  회중시계 줄 — 셋째 단추의 T 막대에서 왼쪽 아래 주머니로 처진다(폭 11cm · 처짐 3.5cm). 고리 마디만큼 굵기가 물결친다
CH0 = (0.002, BTN_Y[2])
CH1 = (0.108, 1.064 + (0.108 - 0.044) * math.tan(math.radians(7.0)) + 0.013)
cpts = []
NS = 40
for i in range(NS + 1):
    t = i / NS
    x = lerp(CH0[0], CH1[0], t)
    yy = lerp(CH0[1], CH1[1], t) - 0.036 * math.sin(math.pi * t) ** 1.1
    ph = phi_of_x(x, yy)
    cpts.append(torso_at(ph, yy, OFF_O + VT + 0.0026))
tube_path("chain", cpts, lambda i, q: (0.0034 + 0.0012 * math.cos(i * math.pi), 0.0034 + 0.0012 * math.cos(i * math.pi),
                                     2.0, 0.0, 0.0, 0.0), CHAIN, n=6, cap0=0.0, cap1=0.0)
ph = phi_of_x(0.0, BTN_Y[2])
tb = torso_at(ph, BTN_Y[2], OFF_O + VT + 0.0026)
tube_path("tbar", [tb + V3(-0.009, 0, 0), tb + V3(0.009, 0, 0)], lambda i, q: (0.0026, 0.0026, 2.0, 0.0, 0.0, 0.0),
          CHAIN, n=6, cap0=0.0012, cap1=0.0012)

# ── 셔츠 앞 단(V 안) · 셔츠 단추 · 깃 ──
def placket(u, v):
    x = lerp(-0.016, 0.016, u)
    y = lerp(1.18, 1.497, v)
    ph = phi_of_x(x, y)
    return torso_at(ph, y, 0.0006), torso_n(ph, y)


shell("placket", placket, 4, 20, 0.0016, SHIRT)
for by in (1.300, 1.378, 1.452):
    ph = phi_of_x(0.0, by)
    lathe("sbtn", [(0.0, 0.0016), (0.0036, 0.0013), (0.0042, 0.0), (0.0, 0.0)],
          torso_at(ph, by, 0.0022), SHIRT_BTN, 10, basis=basis_y_to(torso_n(ph, by)))

#  깃 — 목을 두른 띠(앞이 트였다) · 두 날개가 목밑에서 앞 · 밖으로 접혀 내려온다. 띠 안은 먹 마개(머리는 없다)
NK_HW, NK_HD, NK_CZ = 0.071, 0.068, -0.006


def neck_at(phi, y, grow=0.0):
    k = 1.0 + grow
    return V3(NK_HW * k * math.sin(phi), y, NK_CZ + NK_HD * k * math.cos(phi))


def band(u, v):
    ph = lerp(math.radians(9.0), math.radians(351.0), u)
    y = lerp(1.486, 1.536, v)
    return neck_at(ph, y, 0.06 * v)


shell("collar", band, 48, 4, 0.0028, SHIRT, k=1.0)
bm = bmesh.new()
cr = [bm.verts.new(G(*neck_at(math.tau * i / 32, 1.505, -0.03))) for i in range(32)]
orient = bm.faces.new(cr)
orient.normal_update()
if orient.normal.z < 0.0:
    bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
from_bm("void", bm, VOID, smooth=False)
for s in (1.0, -1.0):
    def wing(u, v, s=s):
        ph = lerp(math.radians(8.0), math.radians(62.0), u)
        F = neck_at(ph, 1.536, 0.08)
        tx = lerp(0.046, 0.085, u)
        ty = lerp(1.452, 1.486, u)
        tph = phi_of_x(tx, ty)
        Tp = torso_at(tph, ty, OFF_O + VT + 0.004)
        p = F.lerp(Tp, v)
        out = V3(p.x, 0.0, p.z - NK_CZ)
        p = p + out.normalized() * (0.007 * math.sin(math.pi * v))
        return V3(p.x * s, p.y, p.z)
    shell("wing", wing, 8, 6, 0.0022, SHIRT)

#  목 — 깃 안을 메운 먹 기둥(머리는 없다 · 어느 쪽에서 보아도 구멍이 안 뚫린다). 게임은 void 를 가장 어두운 단으로 둔다
ring_loft("neck", [[neck_at(math.tau * i / 32, yy, -0.16) for i in range(32)] for yy in (1.47, 1.575)], VOID)

S_R = V3(-0.208, 1.392, -0.012)     # 어깨 관절(입은 사람 오른쪽 · −x) — 가슴 옆(0.165) 밖으로 빼 위팔이 조끼 밖에 선다
E_R = V3(-0.226, 1.103, 0.046)      # 쉬는 팔꿈치 — 갈비에 붙고 조금 앞
torso = finish("BarTorso", 48.0)
empty("ElbowR", E_R, torso)
empty("ElbowL", V3(-E_R.x, E_R.y, E_R.z), torso)
empty("ShoulderR", S_R, torso)
empty("ShoulderL", V3(-S_R.x, S_R.y, S_R.z), torso)

# ── 위팔 — 셔츠 소매 · 놋쇠 소매 띠(따로 — 어깨에서 돈다) ──
#  UpperArmR · UpperArmL — 원점 = 어깨 관절 · 팔꿈치가 (0, −L_UA, 0) · +z 가 팔 앞 · 바깥이 R −x / L +x. 게임이 ShoulderR/L 에 세우고
#  y 축을 팔꿈치 → 어깨로 겨눈다(닦기 자세마다 팔꿈치가 다르다 — 일하는 팔은 앞으로 든다). 길이 L_UA 는 굳다.
#  위팔 단면 폭 13 · 두께 10.5cm(셔츠가 부푼 몫) — game.gd HAND3.up_w0 40 · up_w1 37 · up_d 30 단위 × 0.00328.
#  팔꿈치 너머 3.6cm 둥근 마개(HAND3.up_w1 × 0.3) — 팔뚝 뿌리(_fore3_build · 팔꿈치 뒤 back 12 단위 = 3.9cm)가 그 안에 묻힌다.
#  놋쇠 띠는 팔꿈치 위 10.5cm(FORE3.g_el 32 단위) · 길이 2.6cm · 소매보다 5mm 솟는다 — 위아래로 천이 부푼다.
L_UA = (E_R - S_R).length
G_EL, G_LEN = 0.105, 0.026


def arm_w(q):
    """위팔 폭(어깨 0 → 팔꿈치 1) — 삼각근에서 팔꿈치로 좁아든다. 팔꿈치 12.1cm 가 팔뚝 뿌리(11.8cm)를 덮는다."""
    return table([0.0, 0.3, 0.6, 1.0], [0.134, 0.132, 0.127, 0.121], q)


def arm_t(q):
    return table([0.0, 0.3, 0.6, 1.0], [0.116, 0.110, 0.106, 0.103], q)


for nm, s in (("UpperArmL", 1.0), ("UpperArmR", -1.0)):
    #  어깨에서 곧게 내려오되 이두가 앞으로 조금 부푼다(가운데 8mm)
    pts = crs([V3(0.0, 0.0, 0.0), V3(s * 0.004, -L_UA * 0.5, 0.008), V3(0.0, -L_UA, 0.0)], 14)
    L = [0.0]
    for a, b in zip(pts, pts[1:]):
        L.append(L[-1] + (b - a).length)
    tot = L[-1]
    gq0 = 1.0 - (G_EL + G_LEN) / tot
    gq1 = 1.0 - G_EL / tot
    gm = (gq0 + gq1) * 0.5
    hb = (gq1 - gq0) * 0.5

    def arm_sec(i, q, gm=gm, hb=hb, s=s):
        #  띠 밑은 조여 들고(띠보다 안) · 띠 바로 위아래는 천이 부풀어 잔주름이 모인다
        d = abs(q - gm)
        under = 1.0 - smooth01(hb * 0.8, hb * 1.3, d)
        g2 = math.exp(-((d - hb - 0.03) / 0.05) ** 2) * (1.0 - under)
        puff = 0.009 * math.exp(-((d - hb - 0.035) / 0.03) ** 2)
        w = arm_w(q) - 0.012 * under + puff
        t = arm_t(q) - 0.012 * under + puff
        amp = (lerp(0.025, 0.06, q * q) * (1.0 - g2) + 0.045 * g2) * (1.0 - 0.85 * under)
        return w, t, 2.15, amp, 5.0 + 6.0 * g2, 0.5 + q * 3.4 + (0.0 if s > 0 else 1.7)
    #  ref +z — 폭(B) 축이 몸 옆(x)으로 · 두께가 앞뒤로 눕는다
    tube_path("sleeve", pts, arm_sec, SHIRT, n=28, cap0=0.055, cap1=0.036, ref=V3(0, 0, 1))
    gpts = [along(pts, L, tot - (G_EL + G_LEN * (1.0 - f))) for f in (0.0, 0.15, 0.5, 0.85, 1.0)]

    def gar_sec(i, q, gm=gm):
        #  두 테가 솟은 둥근 띠(game.gd _up3_build 의 띠 단면) — 끝은 소매 속으로 접혀 든다
        dp = [-0.002, 0.005, 0.0035, 0.005, -0.002][i]
        return arm_w(gm) + dp, arm_t(gm) + dp, 2.15, 0.0, 0.0, 0.0
    tube_path("garter", gpts, gar_sec, BRASS, n=28, cap0=0.0, cap1=0.0, ref=V3(0, 0, 1))
    ua = finish(nm, 48.0)
    empty(nm + "Elbow", V3(0.0, -L_UA, 0.0), ua)
print("L_UA", round(L_UA, 4))


# ══ 닦는 잔 · 바 천 ═══════════════════════════════════════════════
#  곧은 셰이커 파인트(빈 잔 — 닦는 잔에 맥주가 있으면 거짓말이다) · 입지름 8.8 · 밑 6 · 높이 14.8 · 벽 2.8mm · 밑 9mm
def polish_ro(y):
    return lerp(0.0306, 0.0440, max(0.0, min(1.0, (y - 0.004) / 0.144)))


prof = [(0.0, 0.0), (0.0290, 0.0), (0.0302, 0.0012), (0.0306, 0.004)]
for yy in (0.03, 0.06, 0.09, 0.12, 0.146):
    prof.append((polish_ro(yy), yy))
prof += [(0.0437, 0.1474), (0.0430, 0.1481), (0.0421, 0.1480), (0.0414, 0.1474)]
for yy in (0.146, 0.12, 0.09, 0.06, 0.03, 0.0098):
    prof.append((polish_ro(yy) - 0.0028, yy))
prof += [(0.020, 0.0092), (0.0, 0.0090)]
lathe("pglass", prof, (0, 0, 0), GLASS, 48)
finish("PolishGlass", 30.0)

#  천 — 밑동 감쌈(잔 밑 30% · 큰 주름 넷 · 위끝은 말린 테 — 잘린 껍데기 끝이 종이 상자 · 검은 구멍으로 읽혔다) · 잔 허리
#  뭉치(빈 잔 속이 천으로 찬다 — 입 높이에 두면 맥주 거품으로 읽혔다)
def wrap_top(ph):
    return 0.037 + 0.005 * math.sin(2.0 * ph + 0.7) + 0.0025 * math.sin(5.0 * ph)


def wrap_fold(ph, yy, q):
    return (0.0042 * (0.5 + 0.5 * math.sin(4.0 * ph + yy * 50.0)) + 0.0012 * math.sin(9.0 * ph)) * (0.3 + 0.7 * q)


def wrap(u, v):
    ph = math.tau * u
    if v < 0.25:
        rr = lerp(0.004, polish_ro(0.0) + 0.0035, v / 0.25)
        yy = -0.0045
    else:
        q = (v - 0.25) / 0.75
        yy = lerp(-0.0045, wrap_top(ph), q)
        rr = polish_ro(max(yy, 0.0)) + 0.0035 + wrap_fold(ph, yy, q)
    return V3(rr * math.cos(ph), yy, rr * math.sin(ph))


shell("wrap", wrap, 56, 14, 0.0026, CLOTH, wrap_u=True)
lip = []
for i in range(65):
    ph = math.tau * i / 64.0
    yy = wrap_top(ph)
    rr = polish_ro(yy) + 0.0035 + wrap_fold(ph, yy, 1.0) + 0.0022
    lip.append(V3(rr * math.cos(ph), yy - 0.0012, rr * math.sin(ph)))
tube_path("lip", lip, lambda i, q: (0.0072, 0.0058, 2.0, 0.12, 5.0, q * 31.0), CLOTH, n=10, cap0=0.0, cap1=0.0,
          ref=V3(0.0, 1.0, 0.0))
finish("TowelWrap", 50.0)

#  테를 넘는 천 — 엄지가 밀어 넣은 천 한 자락: 엄지 밑 뭉치(잔 입 밑 · 안벽에 붙는다)에서 안벽을 타고 올라 테를 넘어
#  바깥 벽으로 2cm(검지가 바깥에서 집는다). 폭 4~5cm 의 납작한 접힘이 잔 둘레를 따라 굽는다 · 한 색(줄무늬 막대가
#  엄지 · 검지 사이에 낀 담배로 읽혔다 · 검토 3) · 주름 단 셋. 잔 허리에 뜬 뭉치는 레몬 공으로 읽혀 여기로 옮겨 작게
#  (2/3) 엄지 끝에 붙인다. 잔 좌표 +x 쪽에 짓는다 — 게임이 집는 자리로 돌린다.
BAND_P = crs([V3(r, yy, 0.0) for r, yy in ((0.022, 0.112), (0.031, 0.124), (0.0376, 0.137), (0.0396, 0.1455),
                                            (0.0428, 0.1512), (0.0470, 0.1462), (0.0481, 0.137), (0.0486, 0.127))], 4)
BAND_L = [0.0]
for a_, b_ in zip(BAND_P, BAND_P[1:]):
    BAND_L.append(BAND_L[-1] + (b_ - a_).length)


def band_sheet(u, v):
    p = along(BAND_P, BAND_L, BAND_L[-1] * v)
    r = math.hypot(p.x, p.z)
    w = lerp(0.036, 0.050, smooth01(0.2, 0.8, v))
    a = (u - 0.5) * w / max(r, 0.02)
    #  주름 단 — 둘레로 세 번 물결(엄지가 누른 자리는 납작하다)
    rr = r + 0.0016 * math.sin(math.tau * 1.5 * u + 0.6) * (0.4 + 0.6 * abs(u - 0.5) * 2.0)
    return V3(rr * math.cos(a), p.y, rr * math.sin(a))


shell("band", band_sheet, 14, 24, 0.0024, CLOTH)
ellipsoid("wad", V3(0.016, 0.104, 0.0), (0.019, 0.016, 0.021), CLOTH, 3, 0.16, 2.3, 5.0)
finish("TowelBand", 50.0)

#  천 꼬리 — 받치는 손 밑으로 30cm · 손 길이의 1.6배 · 큰 세로 주름 셋~넷 · 끝단 말아 박음 · 밤색 줄 둘(주름을 타고 꺾인다).
#  셋을 갈아 끼우며 한 박자 늦게 흔들린다(영상 — 비틀기 0.5~0.7s 에 꼬리 ±3~5cm). A 곧게 · B +x · C −x 로 비틀린다.
TAIL_L = 0.30


def tail_base(sw, ph, tw, lift):
    def base(u, v):
        W = lerp(0.034, 0.150, v ** 0.7)
        A = 0.003 + 0.020 * v ** 0.85
        x = (u - 0.5) * W
        z = A * math.sin(math.tau * 1.75 * u + ph) + 0.004 * math.sin(math.tau * 5.0 * u + 1.3) * (1.0 - v)
        a = tw * v
        x, z = x * math.cos(a) - z * math.sin(a), x * math.sin(a) + z * math.cos(a)
        yy = -TAIL_L * v * (1.0 - lift * (u - 0.5))
        return V3(x + sw * v * v, yy, z + 0.010 * math.sin(math.pi * v))
    return base


def tail_mat(u, v):
    return 1 if (0.835 <= v <= 0.858 or 0.875 <= v <= 0.89) else 0


for nm, (sw, ph, tw, lift) in (("TowelTail_A", (0.0, 0.0, 0.0, 0.0)), ("TowelTail_B", (0.045, 0.7, 0.22, 0.06)),
                               ("TowelTail_C", (-0.040, -0.6, -0.38, -0.10))):
    b = tail_base(sw, ph, tw, lift)
    shell("tail", b, 28, 40, 0.0032, CLOTH, k=0.5, matf=tail_mat, mats=[CLOTH, STRIPE])
    hem = [b(i / 40.0, 1.0) + V3(0.0, 0.0012, 0.0) for i in range(41)]
    tube_path("hem", hem, lambda i, q: (0.0055, 0.0055, 2.0, 0.0, 0.0, 0.0), CLOTH, n=6, cap0=0.002, cap1=0.002)
    ellipsoid("bunch", V3(0.0, -0.006, 0.002), (0.026, 0.020, 0.022), CLOTH, 2, 0.22, 5.0 + sw * 50.0, 4.0)
    finish(nm, 50.0)


# ══ 손님 앞 반 남은 논익 파인트 · 판지 받침 ════════════════════════════════
#  568ml 논익 — 높이 15 · 입지름 8.7 · 밑 6cm · 불룩 띠는 테에서 2.8cm 밑(지름 +4%) · 벽 3mm · 밑 12mm.
#  맥주 면은 높이의 절반(7.5cm) · 김 빠진 거품 6~9mm(벽을 타고 오른 테).
NY = [0.000, 0.003, 0.006, 0.105, 0.110, 0.118, 0.1225, 0.127, 0.132, 0.137, 0.143, 0.150]
NR_ = [0.0298, 0.0306, 0.0308, 0.0408, 0.0414, 0.0440, 0.0452, 0.0447, 0.0434, 0.0428, 0.0431, 0.0436]


def nonic_ro(y):
    return table(NY, NR_, y)


def nonic_ri(y):
    return nonic_ro(y) - 0.0030


NBASE = 0.0125
prof = [(0.0, 0.0), (0.0284, 0.0), (0.0298, 0.0008), (0.0306, 0.003)]
ysmp = [0.006, 0.02, 0.04, 0.06, 0.08, 0.095, 0.105, 0.110, 0.114, 0.118, 0.1205, 0.1225, 0.1245, 0.127, 0.1295,
        0.132, 0.1345, 0.137, 0.140, 0.143, 0.1465]
for yy in ysmp:
    prof.append((nonic_ro(yy), yy))
prof += [(0.0437, 0.1488), (0.0432, 0.1499), (0.0421, 0.1503), (0.0411, 0.1499), (0.0406, 0.1488)]
for yy in reversed([NBASE + 0.0005] + ysmp[1:]):
    if yy > NBASE:
        prof.append((nonic_ri(yy), yy))
prof += [(nonic_ri(NBASE) - 0.0012, NBASE), (0.0, NBASE + 0.0006)]
lathe("pint", prof, (0, 0, 0), GLASS, 64)
finish("Pint", 30.0)

BEER_Y = 0.0750
GAP = 0.0004
prof = [(0.0, NBASE + 0.0002), (nonic_ri(NBASE) - 0.0016, NBASE + 0.0002)]
for yy in (0.016, 0.03, 0.045, 0.06, 0.07):
    prof.append((nonic_ri(yy) - GAP, yy))
prof += [(nonic_ri(BEER_Y) - GAP, BEER_Y + 0.0012), (nonic_ri(BEER_Y) - 0.0030, BEER_Y + 0.0002), (0.0, BEER_Y)]
lathe("beer", prof, (0, 0, 0), BEER, 64)
F0 = BEER_Y - 0.0002
prof = [(0.0, F0), (nonic_ri(F0) - GAP - 0.0001, F0)]
for yy in (0.078, 0.081, 0.0838):
    prof.append((nonic_ri(yy) - GAP - 0.0001, yy))
prof += [(nonic_ri(0.0838) - 0.0018, 0.0846), (nonic_ri(0.083) - 0.0042, 0.0832), (nonic_ri(0.082) - 0.0080, 0.0818),
         (0.016, 0.0812), (0.0, 0.0809)]
lathe("foam", prof, (0, 0, 0), FOAM, 64)
rng = random.Random(25)
for k in range(10):
    a = rng.uniform(0.0, math.tau)
    r = rng.uniform(0.006, 0.030) if k < 4 else rng.uniform(0.0, 0.032)
    rad = rng.uniform(0.0055, 0.0080) if k < 4 else rng.uniform(0.0018, 0.0032)
    ellipsoid("bub", V3(r * math.cos(a), 0.0812 - rad * 0.35, r * math.sin(a)), (rad, rad * 0.75, rad), FOAM, 1, 0.1,
              rng.uniform(0, 9))
#  거품 고리는 짓지 않는다 — 조각 · 흐른 자국은 빈 윗부분을 얼룩무늬로 채웠고(검토 3) · 이은 가는 호는 앉은 눈에서 1px 밑이라
#  점선 · 둘째 테로 읽혔다. 반 남은 잔은 맥주 면 · 거품 테가 말한다.
finish("PintBeer", 40.0)

#  받침 — 둥근 판지 10cm · 2.2mm · 둥근 테 · 흰 판지 단면 · 인쇄는 네 갈래 별 하나(두 색 · 고리 없음 — 동심원 인쇄가 평평한 면의
#  빛 고리로 읽혔다). 별은 윗면 위 0.15mm 판(잔 밑동 둘레로 끝 넷만 나온다)
CR = 0.050
CT = 0.0022
cprof = [(0.0, 0.0), (CR - 0.0010, 0.0), (CR, 0.0006), (CR, CT - 0.0006), (CR - 0.0010, CT), (0.0, CT)]


def coaster_mat(r, y):
    if y < CT - 1e-4:
        return 0 if y < 1e-4 else 3
    if r > CR - 0.0008:
        return 3
    return 0


lathe("coaster", cprof, (0, 0, 0), None, 64, mats=[COASTER, INK, WET, CARD], matf=coaster_mat)
bm = bmesh.new()
cv = bm.verts.new(G(0.0, CT + 0.00015, 0.0))
ring = []
for k in range(16):
    a = math.tau * k / 16.0 + math.pi / 4.0
    r = 0.0455 if k % 4 == 0 else (0.0215 if k % 2 == 1 else 0.0175)
    ring.append(bm.verts.new(G(r * math.cos(a), CT + 0.00015, r * math.sin(a))))
for k in range(16):
    f = bm.faces.new((cv, ring[k], ring[(k + 1) % 16]))
    f.normal_update()
    if f.normal.z < 0.0:
        f.normal_flip()
star = from_bm("star", bm, [COASTER, INK], False)
for pl in star.data.polygons:
    pl.material_index = 1
finish("Coaster", 30.0)


# ══ 천장 TV — 14″ 브라운관 · 받침 띠 · 쟁반 ════════════════════════════════
#  13~14″ 상품표: 앞면 37 × 34.5 · 깊이 37cm. 화면 칸 너비 78% × 높이 62%(4:3) · 윗 테 13% · 밑 조작 구역 24%.
#  앞 껍데기 띠(깊이 25%) 뒤로 한 단 준 혹(앞면의 75 × 70%) → 뒤로 55%까지 좁아든다 · 혹 옆에 숨구멍 띠.
#  테는 두 단 — 바깥 평면 테 · 안으로 꺾여 드는 짙은 비탈(crt_bezel) · 볼록 유리(crt_glass · UV 0..1 = 화면 칸).
#  짓는 틀은 TV 밑 앞 가운데가 원점(y 위 · 앞면 z 0) — 끝에 기울기 축(PIV)으로 옮긴다.
TW, TH, TD = 0.370, 0.345, 0.370
SW, SH = 0.144, 0.108            # 화면 칸 반 폭 · 반 높이
SY = TH - 0.045 - SH             # 화면 한가운데 높이
SQ_N = 5.0
PIV = V3(0.0, TH * 0.68, -0.130)  # 기울기 축 — 윗면에서 높이의 32% 밑 · 앞에서 13cm 뒤(무게 가운데)
NQ = 48


def sq(t, n):
    c, s_ = math.cos(t), math.sin(t)
    return (math.copysign(abs(c) ** (2.0 / n), c), math.copysign(abs(s_) ** (2.0 / n), s_))


def ringq(cx, cy, hw, hh, z, n):
    return [V3(cx + hw * p[0], cy + hh * p[1], z) for p in (sq(math.tau * i / NQ, n) for i in range(NQ))]


def strip(name, rings_, m):
    bm = bmesh.new()
    rs = [[bm.verts.new(G(*p)) for p in r] for r in rings_]
    for a, b in zip(rs, rs[1:]):
        for i in range(NQ):
            j = (i + 1) % NQ
            bm.faces.new((a[i], a[j], b[j], b[i]))
    for f in bm.faces:
        f.normal_update()
        if f.normal.y > 0.0:      # 앞(+z · Blender −y)을 보게
            f.normal_flip()
    return from_bm(name, bm, m, smooth=False)


def front_plate(name, x0, x1, y0, y1, cx, cy, hw, hh, m, n, z=0.0):
    """앞판 [x0,x1]×[y0,y1] — (cx, cy) 의 둥근 구멍(tvs.py 와 같은 짜임)."""
    bm = bmesh.new()
    inner, outer, angs = [], [], []
    for i in range(NQ):
        p = sq(math.tau * i / NQ, n)
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
    for i in range(NQ):
        j = (i + 1) % NQ
        bm.faces.new((inner[i], inner[j], outer[j], outer[i]))
    for kx, ky in ((x1, y1), (x0, y1), (x0, y0), (x1, y0)):
        a = math.atan2(ky - cy, kx - cx)
        for i in range(NQ):
            j = (i + 1) % NQ
            d = (angs[j] - angs[i]) % math.tau
            if 0.0 < (a - angs[i]) % math.tau < d:
                c = bm.verts.new(G(kx, ky, z))
                bm.faces.new((outer[i], outer[j], c))
                break
    bmesh.ops.remove_doubles(bm, verts=bm.verts[:], dist=1e-6)
    for f in bm.faces:
        f.normal_update()
        if f.normal.y > 0.0:
            f.normal_flip()
    return from_bm(name, bm, m, smooth=False)


def screen(cx, cy, hw, hh, z0, bulge, n, rings_n=10):
    """볼록 유리 — UV 는 화면 칸 그대로(Blender 왼 아래 0,0 → 게임 왼 위 0,0)."""
    bm = bmesh.new()
    uvl = bm.loops.layers.uv.new("UVMap")
    rows = []
    for k in range(1, rings_n + 1):
        r = k / rings_n
        row = []
        for i in range(NQ):
            p = sq(math.tau * i / NQ, n)
            row.append(bm.verts.new(G(cx + hw * p[0] * r, cy + hh * p[1] * r, z0 + bulge * (1.0 - r * r))))
        rows.append(row)
    c = bm.verts.new(G(cx, cy, z0 + bulge))
    for i in range(NQ):
        j = (i + 1) % NQ
        bm.faces.new((c, rows[0][i], rows[0][j]))
    for a, b in zip(rows, rows[1:]):
        for i in range(NQ):
            j = (i + 1) % NQ
            bm.faces.new((a[i], b[i], b[j], a[j]))
    for f in bm.faces:
        f.normal_update()
    if sum(f.normal.y for f in bm.faces) > 0.0:
        bmesh.ops.reverse_faces(bm, faces=bm.faces[:])
    for f in bm.faces:
        for lp in f.loops:
            co = lp.vert.co
            lp[uvl].uv = ((co.x - (cx - hw)) / (2.0 * hw), (co.z - (cy - hh)) / (2.0 * hh))
    return from_bm("crt_glass", bm, CRT_GLASS, smooth=True)


#  앞 껍데기 — 앞 4.5cm 는 네 벽만(앞판 · 테 · 유리가 그 안에 앉는다) · 그 뒤 통
K_F = 0.045
D1 = 0.095
box("band", (TW, TH, D1 - K_F), (0.0, TH * 0.5, -(K_F + D1) * 0.5), CRT_BODY, 0.012, 2)
WT = 0.016
for (sx_, sy_, cx_, cy_) in ((TW, WT, 0.0, TH - WT * 0.5), (TW, WT, 0.0, WT * 0.5), (WT, TH, -(TW - WT) * 0.5, TH * 0.5),
                             (WT, TH, (TW - WT) * 0.5, TH * 0.5)):
    box("wall", (sx_, sy_, K_F + 0.012), (cx_, cy_, 0.002 - (K_F + 0.012) * 0.5), CRT_BODY, 0.006, 2)
M1 = 0.016       # 바깥 평면 테가 화면 칸을 두른 여백
front_plate("face", -TW * 0.5 + WT, TW * 0.5 - WT, WT, TH - WT, 0.0, SY, SW + M1, SH + M1, CRT_BODY, SQ_N, 0.0)
#  안 비탈 — 바깥 테 안끝 → 한 단 꺾여 → 유리 테
strip("bezel", [ringq(0.0, SY, SW + M1, SH + M1, 0.0, SQ_N), ringq(0.0, SY, SW + 0.004, SH + 0.004, -0.010, SQ_N),
                ringq(0.0, SY, SW, SH, -0.016, SQ_N), ringq(0.0, SY, SW - 0.001, SH - 0.001, -0.026, SQ_N)], CRT_BEZEL)
screen(0.0, SY, SW, SH, -0.020, 0.016, SQ_N)
#  밑 조작 구역 — 짙은 들어간 띠 · 전원 단추(둥근) · 붉은 대기등 · 작은 단추 넷 · 오른쪽 세로 스피커 망 · 이름 없는 명판
box("cstrip", (0.20, 0.020, 0.004), (-0.030, 0.042, -0.001), CRT_BEZEL, 0.0015, 2)
lathe("power", [(0.0, 0.006), (0.0068, 0.0055), (0.0082, 0.003), (0.0082, 0.0), (0.0, 0.0)], (-0.112, 0.042, 0.0),
      CRT_BTN, 16, axis="z")
box("led", (0.0045, 0.0045, 0.004), (-0.094, 0.042, 0.0015), CRT_LED, 0.0012, 2)
for k in range(4):
    box("btn", (0.016, 0.0075, 0.005), (0.000 + k * 0.021, 0.042, 0.0012), CRT_BTN, 0.0018, 2)
box("plate", (0.046, 0.007, 0.002), (0.0, 0.070, 0.0008), CRT_BTN, 0.001, 2)
box("grille", (0.050, 0.046, 0.003), (0.128, 0.046, -0.0005), CRT_GRILLE)
for k in range(9):
    box("slat", (0.0028, 0.044, 0.004), (0.106 + k * 0.0055, 0.046, 0.0012), CRT_BODY, 0.0008, 1)
#  뒤 혹 — 앞 띠 뒤로 한 단 줄어 뒤로 좁아든다(브라운관 목). 혹 한가운데는 화면 높이에 맞춘다
#  밑은 평평하게 둔다(탁자에 앉는 통 — 밑면이 앞 띠와 한 판) · 위 · 옆만 좁아든다
HZ = [-D1 + 0.004, -0.15, -0.26, -0.335, -TD]
HW_ = [0.75, 0.74, 0.66, 0.58, 0.55]
HH_ = [0.70, 0.69, 0.60, 0.52, 0.49]
hump = []
for z, fw, fh in zip(HZ, HW_, HH_):
    hump.append(ringq(0.0, TH * fh * 0.5 + 0.001, TW * fw * 0.5, TH * fh * 0.5, z, 6.0))
ring_loft("hump", hump, CRT_BODY, "flat", "flat", smooth=False)
HC = TH * HH_[-1] * 0.5           # 뒤판 한가운데 높이


def hump_at(z):
    return table(HZ[::-1], HW_[::-1], z), table(HZ[::-1], HH_[::-1], z)


#  숨구멍 띠 — 혹 옆 · 위에 가로 슬롯(짙은 바탕 위 갈비)
for s in (1.0, -1.0):
    for k in range(6):
        z = -0.13 - k * 0.022
        fw, fh = hump_at(z)
        box("vent", (0.006, 0.050, 0.010), (s * (TW * fw * 0.5 + 0.0005), TH * fh * 0.5 + 0.02, z), CRT_GRILLE)
for k in range(7):
    z = -0.12 - k * 0.022
    fw, fh = hump_at(z)
    box("vent", (0.13, 0.006, 0.010), (0.0, TH * fh + 0.0015, z), CRT_GRILLE)
#  뒤판 — 줄이 드는 자리 · 들어간 판
box("bpanel", (0.10, 0.07, 0.006), (0.0, HC, -TD - 0.001), CRT_BEZEL, 0.002, 2)
lathe("relief", [(0.0, 0.0), (0.0085, 0.0), (0.0085, 0.010), (0.0065, 0.022), (0.0055, 0.03), (0.0, 0.03)],
      (0.045, HC - 0.015, -TD), CABLE, 10, axis="z", basis=Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0))).transposed())
for sx_ in (-1.0, 1.0):
    for sz_ in (-0.03, -0.28):
        box("foot", (0.030, 0.006, 0.030), (sx_ * (TW * 0.5 - 0.04), -0.003, sz_), RUBBER, 0.002, 2)
#  받침 — 양옆 납작한 띠(폭 1.3cm · 3mm) · 축 자리 둥근 판 · 윗 모서리를 누르는 집게 · 밑을 감싼 쟁반(앞 턱)
STW, STT = 0.013, 0.003
for s in (1.0, -1.0):
    x = s * (TW * 0.5 + STT * 0.5 + 0.0005)
    box("strap", (STT, TH + 0.004, STW), (x, TH * 0.5 - 0.002, PIV.z), IRON, 0.0009, 2)
    lathe("hub", [(0.0, 0.004), (0.026, 0.004), (0.028, 0.002), (0.028, 0.0), (0.0, 0.0)],
          (s * (TW * 0.5 + STT + 0.0005), PIV.y, PIV.z), IRON, 24,
          basis=Matrix(((0, -s, 0), (s, 0, 0), (0, 0, 1))).transposed())
    box("clip", (0.040, STT, STW + 0.004), (s * (TW * 0.5 - 0.018), TH + STT * 0.5 + 0.0005, PIV.z), IRON, 0.0009, 2)
    box("pad", (0.034, 0.002, STW), (s * (TW * 0.5 - 0.018), TH + 0.0002, PIV.z), RUBBER)
box("tray", (TW + 0.012, STT, 0.25), (0.0, -0.008, -0.135), IRON, 0.0012, 2)
box("lip", (TW + 0.012, 0.020, STT), (0.0, 0.002, -0.010), IRON, 0.0012, 2)
for s in (1.0, -1.0):
    box("tray_side", (STT, 0.018, 0.25), (s * (TW * 0.5 + STT * 0.5 + 0.0005), 0.001, -0.135), IRON, 0.0009, 2)
crt = finish("BarCrt", 32.0)
crt.data.transform(Matrix.Translation(-G(*PIV)))
crt.data.update()

# ══ 천장 걸이 — 판 · 늘어진 관 · 높이 손잡이 · 거꾸로 된 U 멍에 · 축 손잡이 · 줄 ════════════════════
#  원점 = 천장 면. 관 지름 3.5cm · 판 지름 12.4cm 볼트 넷 · 멍에 가로판 = 0.74W · U 바깥 폭 1.17W · 가로판과 TV 윗면 틈 7.5cm.
#  축은 PIVOT_Y — TV(BarCrt) 원점을 여기 두고 x 축으로 기울인다(설계 15° · 위가 앞으로).
LP = 0.160
Y_PB = -(0.040 + LP)                 # 관 밑끝
Y_CB = Y_PB - 0.031                  # 가로판 한가운데
PIVOT_Y = Y_CB - 0.006 - 0.075 - (TH - PIV.y)
AX = TW * 0.5 + STT + 0.0105 + 0.0085    # U 팔 한가운데 x(축 판 바깥 5mm 틈)
lathe("flange", [(0.0, 0.0), (0.062, 0.0), (0.062, -0.004), (0.058, -0.0065), (0.0, -0.0065)], (0, 0, 0), IRON, 32)
for k in range(4):
    a = math.tau * (k + 0.5) / 4
    lathe("bolt", [(0.0, 0.0), (0.0062, 0.0), (0.0062, -0.0025), (0.0045, -0.0034), (0.0, -0.0034)],
          (0.045 * math.cos(a), -0.0064, 0.045 * math.sin(a)), IRON, 6)
lathe("socket", [(0.0, -0.005), (0.026, -0.005), (0.026, -0.012), (0.022, -0.018), (0.021, -0.040), (0.0, -0.040)],
      (0, 0, 0), IRON, 24)
lathe("pipe", [(0.0, -0.035), (0.0175, -0.035), (0.0175, Y_PB + 0.004), (0.0, Y_PB + 0.004)], (0, 0, 0), IRON, 20)
lathe("collar", [(0.0, -0.088), (0.0225, -0.088), (0.0235, -0.092), (0.0235, -0.108), (0.0225, -0.112),
                 (0.0, -0.112)], (0, 0, 0), IRON, 20)
#  높이 별 손잡이 — 다섯 날개
bm = bmesh.new()
pts = []
for i in range(40):
    a = math.tau * i / 40
    rr = 0.015 + 0.007 * max(0.0, math.cos(5.0 * a)) ** 1.5
    pts.append((rr * math.cos(a), rr * math.sin(a)))
f0 = [bm.verts.new(G(0.040, -0.100 + py, px)) for px, py in pts]
f1 = [bm.verts.new(G(0.052, -0.100 + py, px)) for px, py in pts]
for i in range(40):
    j = (i + 1) % 40
    bm.faces.new((f0[i], f0[j], f1[j], f1[i]))
bm.faces.new(f0[::-1])
bm.faces.new(f1)
orient_closed(bm)
from_bm("star", bm, KNOB, smooth=False)
lathe("stem", [(0.0, 0.0), (0.006, 0.0), (0.006, 0.020), (0.0, 0.020)], (0.022, -0.100, 0.0), IRON, 10, axis="x")
lathe("hub", [(0.0, Y_PB + 0.006), (0.024, Y_PB + 0.006), (0.025, Y_PB - 0.004), (0.025, Y_CB + 0.006),
              (0.0, Y_CB + 0.006)], (0, 0, 0), IRON, 24)
box("crossbar", (TW * 0.74, 0.012, 0.046), (0.0, Y_CB, 0.0), IRON, 0.004, 2)
for s in (-1.0, 1.0):
    box("screw", (0.008, 0.003, 0.008), (s * TW * 0.30, Y_CB + 0.0072, 0.0), IRON, 0.001, 1)
#  U — 굽은 네모 관(1.7cm) · 가로판 밑을 지나 양 끝에서 둥글게 꺾여 축까지 내려온다
upts = []
RB = 0.030
YU = Y_CB - 0.006 - 0.0085
for i in range(9):
    a = math.pi * 0.5 * i / 8
    upts.append(V3(-AX + RB - RB * math.cos(a), YU - RB + RB * math.sin(a), 0.0))
upts = [V3(-AX, PIVOT_Y, 0.0), V3(-AX, (PIVOT_Y + YU - RB) * 0.5, 0.0)] + upts
upts += [V3(-p.x, p.y, p.z) for p in reversed(upts)]
tube_path("yoke", upts, lambda i, q: (0.017, 0.017, 7.0, 0.0, 0.0, 0.0), IRON, n=16, cap0=0.0, cap1=0.0,
          ref=V3(0, 0, 1))
for s in (-1.0, 1.0):
    #  축 둥근 판 · 바깥 손잡이(지름 5cm · 6cm 튀어나온다 · 홈 열둘)
    lathe("boss", [(0.0, -0.011), (0.017, -0.011), (0.019, -0.006), (0.019, 0.006), (0.017, 0.011), (0.0, 0.011)],
          (s * AX, PIVOT_Y, 0.0), IRON, 20, axis="x")
    kp = []
    for yy, rr in ((0.0, 0.010), (0.012, 0.010), (0.014, 0.022), (0.016, 0.024), (0.036, 0.024), (0.040, 0.022),
                   (0.042, 0.016), (0.0425, 0.0)):
        kp.append((rr, yy))
    kp = [(0.0, 0.0)] + kp
    lathe("knob", kp, (s * (AX + 0.0085), PIVOT_Y, 0.0), KNOB, 24,
          basis=Matrix(((0, -s, 0), (s, 0, 0), (0, 0, 1))).transposed())
#  줄 — 판 가장자리에서 나와 관 옆을 타고 내려오고(묶음 둘) 관 밑에서 느슨한 고리로 가로판 뒤를 지나 TV 혹 뒤로 든다
#  (TV 15° 기울 때 줄 끝이 BarCrt 줄 고정 자리에 닿는다 — 10~18° 는 고리 처짐이 덮는다)
cd = V3(0.6, 0.0, -0.8).normalized() * 0.0235
cab = [V3(0.050, -0.004, -0.020), V3(0.030, -0.012, -0.020), cd + V3(0, -0.045, 0), cd + V3(0, -0.12, 0),
       cd + V3(0, -0.18, 0)]
tilt = math.radians(15.0)
ent = V3(0.045, HC - 0.015, -TD - 0.030) - PIV
ent = V3(ent.x, ent.y * math.cos(tilt) - ent.z * math.sin(tilt), ent.y * math.sin(tilt) + ent.z * math.cos(tilt))
ent = ent + V3(0.0, PIVOT_Y, 0.0)
cab += [V3(0.02, Y_PB - 0.005, -0.045), V3(0.032, Y_CB - 0.03, -0.11), V3(0.048, (Y_CB + ent.y) * 0.5 - 0.06, -0.20),
        V3(ent.x, ent.y - 0.025, ent.z - 0.02), ent]
tube_path("cable", crs(cab, 6), lambda i, q: (0.0095, 0.0095, 2.0, 0.0, 0.0, 0.0), CABLE, n=8, cap0=0.0, cap1=0.0)
mount = finish("TvMount", 32.0)
print("PIVOT_Y", round(PIVOT_Y, 4), "PIV(BarCrt 짓는 틀)", tuple(round(c, 4) for c in PIV), "LP", LP)


# ══ 카운터 손님 쪽 팔걸이 — 시카고 쇠시리 ══════════════════════════════════
#  깊이 12 · 높이 6.4cm · 둥근 등이 윗판보다 2.6cm 솟고 · 둥근 코(앞판보다 7.6cm 앞) · 밑에 물받이 홈. 단면 (z, y) — 원점은
#  CntNose 와 같다(앞판 면 z −0.08 · 윗판 윗면 y 0). 뒤끝에 윗판과 맞닿는 짙은 이음 줄.
def arc_pts(c, r, a0, a1, n):
    return [(c[0] + r * math.cos(a0 + (a1 - a0) * i / n), c[1] + r * math.sin(a0 + (a1 - a0) * i / n))
            for i in range(n + 1)]


rail = [(-0.124, -0.012), (-0.124, 0.004)]
rail += arc_pts((-0.112, 0.004), 0.012, math.pi, math.pi * 0.55, 4)[1:]
crown = [(-0.100, 0.0192), (-0.088, 0.0228), (-0.074, 0.0250), (-0.060, 0.0260), (-0.046, 0.0252), (-0.034, 0.0230)]
rail += crown
rail += arc_pts((-0.024, 0.002), 0.0215, math.radians(118.0), math.radians(-75.0), 12)
rail += [(-0.0255, -0.0255), (-0.0310, -0.0290), (-0.0350, -0.0260), (-0.0385, -0.0262), (-0.0420, -0.0315),
         (-0.0480, -0.0372), (-0.0800, -0.0372), (-0.0800, -0.050), (-0.124, -0.050)]


def extrude_x(name, prof_, x0, x1, m):
    bm = bmesh.new()
    a = [bm.verts.new(G(x0, y, z)) for z, y in prof_]
    b = [bm.verts.new(G(x1, y, z)) for z, y in prof_]
    n = len(prof_)
    for i in range(n):
        j = (i + 1) % n
        bm.faces.new((a[i], a[j], b[j], b[i]))
    bm.faces.new(a)
    bm.faces.new(b[::-1])
    orient_closed(bm)
    return from_bm(name, bm, m)


extrude_x("rail", rail, -0.5, 0.5, RAIL)
box("seam", (1.0, 0.003, 0.004), (0.0, 0.0005, -0.1265), WOOD_DK)
finish("CntRail", 40.0)


# ══ 고무 레일 매트 — 69 × 8.3cm · 바닥판 · 둘레 턱 · 엇갈린 돌기 격자 ═════════════════════════
MW, MD = 0.690, 0.083
box("mbase", (MW, 0.006, MD), (0.0, 0.003, 0.0), RUBBER, 0.0015, 2)
for (sx_, sz_, cx_, cz_) in ((MW, 0.005, 0.0, MD * 0.5 - 0.0025), (MW, 0.005, 0.0, -MD * 0.5 + 0.0025),
                             (0.005, MD, MW * 0.5 - 0.0025, 0.0), (0.005, MD, -MW * 0.5 + 0.0025, 0.0)):
    box("lipm", (sx_, 0.011, sz_), (cx_, 0.0055, cz_), RUBBER, 0.0018, 2)
NUB = [(0.0, 0.0), (0.0042, 0.0), (0.0040, 0.0035), (0.0026, 0.0054), (0.0, 0.0058)]
pitch = 0.0125
row = 0
z = -MD * 0.5 + 0.009
while z < MD * 0.5 - 0.008:
    x = -MW * 0.5 + 0.009 + (pitch * 0.5 if row % 2 else 0.0)
    while x < MW * 0.5 - 0.008:
        lathe("nub", NUB, (x, 0.0058, z), RUBBER, 6)
        x += pitch
    z += pitch * 0.866
    row += 1
finish("BarMat", 40.0)


# ══ 나무 그릇 · 땅콩 한 줌 ═════════════════════════════════════════
bowl = [(0.0, 0.0), (0.026, 0.0), (0.0272, 0.0035), (0.0245, 0.0062), (0.034, 0.011), (0.046, 0.022), (0.053, 0.034),
        (0.0565, 0.0425), (0.0555, 0.0452), (0.0530, 0.0450), (0.0505, 0.0410), (0.044, 0.028), (0.032, 0.016),
        (0.016, 0.0105), (0.0, 0.0098)]
lathe("bowl", bowl, (0, 0, 0), WOOD, 40)
for i in range(28):
    a = rng.uniform(0.0, math.tau)
    r = 0.040 * math.sqrt(rng.random())
    yy = 0.014 + 0.017 * (1.0 - (r / 0.045) ** 2) + rng.uniform(0.0, 0.004)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=10, v_segments=6, radius=1.0)
    yaw, pit = rng.uniform(0, math.tau), rng.uniform(-0.5, 0.5)
    rot = Matrix.Rotation(yaw, 3, "Z") @ Matrix.Rotation(pit, 3, "Y")
    for v in bm.verts:
        x = v.co.x
        pinch = 1.0 - 0.16 * math.exp(-(x / 0.35) ** 2)
        v.co = rot @ Vector((x * 0.0090, v.co.y * 0.0056 * pinch, v.co.z * 0.0054 * pinch)) + G(r * math.cos(a), yy,
                                                                                                    r * math.sin(a))
    orient_closed(bm)
    from_bm("nut", bm, NUT)
finish("NutBowl", 45.0)


# ══ 펜던트 젖빛 판 — 갓 치마 안 2cm 위에 끼운다(인트로 · 앉은 눈이 갓 밑을 올려다보면 맨 전구 · 큰 크림 원판이 보였다) ══════
#  bar_props.py Lamp 와 같은 원점(갓 밑 테 한가운데) · 갓 치마 안 반지름(y 0.021 에서 0.168)에 맞춘 얕은 접시 · 둘레 말린 테.
lathe("frost", [(0.0, 0.0150), (0.080, 0.0160), (0.150, 0.0195), (0.163, 0.0215), (0.164, 0.0245), (0.160, 0.0250),
                (0.147, 0.0225), (0.078, 0.0190), (0.0, 0.0180)], (0, 0, 0), mat("frost", (0.95, 0.88, 0.70)), 40)
finish("PendDiffuser", 40.0)


# ══ 천장 잔 걸이 — 레일 셋에 와인잔 여덟이 거꾸로 걸린다(눈과 TV 사이 앞 켜 · 어둠 속 실루엣 · TV 빛에 테만 선다) ══════════
#  원점 = 천장 면 한가운데 · 레일은 x 로 0.46 · 매단 막대 둘. 잔은 발(지름 7cm)이 레일 턱에 얹히고 볼이 밑으로 늘어진다.
RK_Y = -0.150
for sx in (-0.19, 0.19):
    lathe("plate", [(0.0, 0.0), (0.022, 0.0), (0.022, -0.004), (0.0, -0.004)], (sx, 0.0, 0.0), IRON, 16)
    lathe("rod", [(0.0, -0.003), (0.0055, -0.003), (0.0055, RK_Y + 0.004), (0.0, RK_Y + 0.004)], (sx, 0.0, 0.0), IRON, 10)
for rz in (-0.09, 0.0, 0.09):
    box("rail", (0.46, 0.010, 0.010), (0.0, RK_Y - 0.002, rz), IRON, 0.002, 2)
    box("flange", (0.46, 0.003, 0.026), (0.0, RK_Y - 0.0085, rz), IRON, 0.001, 1)
for sx in (-0.225, 0.225):
    box("cross", (0.012, 0.012, 0.20), (sx, RK_Y + 0.002, 0.0), IRON, 0.002, 2)
WINE = [(0.0, 0.0), (0.034, 0.0), (0.0345, -0.0025), (0.006, -0.006), (0.0035, -0.012), (0.0032, -0.060),
        (0.006, -0.070), (0.020, -0.078), (0.034, -0.092), (0.041, -0.112), (0.042, -0.130), (0.039, -0.150),
        (0.0365, -0.165), (0.0350, -0.1665), (0.0335, -0.165), (0.0360, -0.150), (0.0388, -0.130),
        (0.0378, -0.112), (0.031, -0.093), (0.018, -0.081), (0.0, -0.077)]
rng2 = random.Random(7)
for rz in (-0.045, 0.045):
    for k in range(4):
        x = -0.165 + k * 0.11 + rng2.uniform(-0.012, 0.012)
        lathe("wine", WINE, (x, RK_Y - 0.010, rz), GLASS, 32)
finish("GlassRack", 35.0)


# ══ 눌러 찍은 양철 천장 판 — 61cm 네모 하나(게임이 깔아 잇는다) · 테 구슬 · 안 구슬 · 가운데 꽃 · 꽃잎 여덟 · 귀 둥근 혹 ══════
#  밑(−y)으로 솟는다. 둥근 면이라 TV 찬 빛이 등성이마다 빛 단을 세운다(평평한 천장 판은 빛 웅덩이만 받았다).
TT = 0.61


def tin_h(u, v):
    sqd = max(abs(u), abs(v))
    rr = math.hypot(u, v)
    th = math.atan2(v, u)

    def bead(d, at, w, hh):
        t = (d - at) / w
        return hh * math.cos(t * math.pi * 0.5) if abs(t) < 1.0 else 0.0
    h = bead(sqd, 0.455, 0.028, 0.009) + bead(sqd, 0.315, 0.020, 0.006)
    if rr < 0.13:
        h += 0.013 * math.cos(rr / 0.13 * math.pi * 0.5) ** 1.5
    h += 0.006 * max(0.0, math.cos(4.0 * th)) ** 6 * bead(rr, 0.19, 0.06, 1.0)
    for cx in (-0.385, 0.385):
        for cz in (-0.385, 0.385):
            d = math.hypot(u - cx, v - cz)
            if d < 0.045:
                h += 0.007 * math.cos(d / 0.045 * math.pi * 0.5)
    return h


NT = 72
bm = bmesh.new()
vs = [[bm.verts.new(G((i / NT - 0.5) * TT, -tin_h(i / NT - 0.5, j / NT - 0.5) * 1.0, (j / NT - 0.5) * TT))
       for j in range(NT + 1)] for i in range(NT + 1)]
for i in range(NT):
    for j in range(NT):
        f = bm.faces.new((vs[i][j], vs[i + 1][j], vs[i + 1][j + 1], vs[i][j + 1]))
for f in bm.faces:
    f.normal_update()
    if f.normal.z > 0.0:          # 밑(게임 −y = Blender −z)을 보게
        f.normal_flip()
from_bm("tin", bm, mat("tin", (0.20, 0.17, 0.14), 0.7, 0.35))
finish("TinTile", 60.0)


# ── 내보낸다 ────────────────────────────────────────────────────
obs = [o for o in bpy.context.collection.objects if o.get("done") is not None]
for o in bpy.context.collection.objects:
    o.select_set(o in obs)
os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True,
                          export_yup=True, export_animations=False, export_cameras=False, export_lights=False)
print("wrote", OUT, [o.name for o in obs])

if PREVIEW:
    os.makedirs(PREVIEW, exist_ok=True)
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 1200
    scene.render.resolution_y = 900
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.05, 0.06, 1.0)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    scene.world = w
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.5
    sun.rotation_euler = (math.radians(50.0), math.radians(-20.0), math.radians(30.0))
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    byname = {o.name: o for o in obs}

    def shot(fn, show, at, look, lens=50.0):
        for o in obs:
            o.hide_render = o.name not in show and o.type == "MESH"
        cam.location = G(*at)
        d = G(*look) - G(*at)
        cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
        cam.data.lens = lens
        scene.render.filepath = os.path.join(PREVIEW, fn)
        bpy.ops.render.render(write_still=True)

    for nm, sh in (("UpperArmR", S_R), ("UpperArmL", V3(-S_R.x, S_R.y, S_R.z))):
        #  쉬는 자세 — 어깨에 세우고 팔꿈치(ElbowR/L)로 겨눈다
        el = V3(E_R.x * (1.0 if nm.endswith("R") else -1.0), E_R.y, E_R.z)
        uy = (sh - el).normalized()
        uz = (V3(0, 0, 1) - uy * uy.z).normalized()
        bas = Matrix((uy.cross(uz), uy, uz)).transposed()
        Bm = Matrix(((1, 0, 0), (0, 0, -1), (0, 1, 0)))
        byname[nm].matrix_world = Matrix.Translation(G(*sh)) @ (Bm @ bas @ Bm.inverted()).to_4x4()
    arms = ["BarTorso", "UpperArmR", "UpperArmL"]
    shot("merchant.png", arms, (0.35, 1.45, 1.25), (0.0, 1.20, 0.0), 45.0)
    shot("merchant_front.png", arms, (0.0, 1.52, 1.30), (0.0, 1.20, 0.0), 40.0)
    byname["BarCrt"].rotation_euler = (math.radians(15.0), 0.0, 0.0)   # Blender x 둘레 + 가 게임에서도 위가 앞으로
    byname["BarCrt"].location = G(0.0, PIVOT_Y, 0.0)
    shot("tv.png", ["TvMount", "BarCrt"], (0.45, -0.75, 1.30), (0.0, -0.40, 0.0), 40.0)
    shot("tv_side.png", ["TvMount", "BarCrt"], (1.30, -0.35, -0.10), (0.0, -0.35, -0.1), 40.0)
    for nm, p in (("Pint", (0, 0, 0)), ("PintBeer", (0, 0, 0)), ("Coaster", (0, -0.0022, 0)),
                  ("PolishGlass", (0.20, 0, 0)), ("TowelWrap", (0.20, 0, 0)), ("TowelBand", (0.20, 0, 0)), ("TowelTail_A", (0.20, -0.005, 0)),
                  ("TowelTail_B", (0.40, 0.0, 0)), ("TowelTail_C", (0.55, 0.0, 0)), ("NutBowl", (-0.18, -0.0022, 0.05)),
                  ("CntRail", (0.0, -0.0022, 0.25)), ("BarMat", (0.25, -0.0022, -0.18))):
        byname[nm].location = G(*p)
    shot("props.png", ["Pint", "PintBeer", "Coaster", "PolishGlass", "TowelWrap", "TowelBand", "TowelTail_A", "TowelTail_B",
                       "TowelTail_C", "NutBowl", "CntRail", "BarMat"], (0.20, 0.25, 0.75), (0.20, -0.02, 0.0), 35.0)
    shot("pint_low.png", ["Pint", "PintBeer", "Coaster"], (0.0, 0.07, 0.26), (0.0, 0.07, 0.0), 35.0)
    print("preview", PREVIEW)
