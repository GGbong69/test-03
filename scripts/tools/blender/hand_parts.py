# 상인 손 — Blender(bpy)로 마디마다 살 덩어리를 짓고 glb 로 내보낸다 (2026-10-16 「블렌더 깔았으니까 활용해봐」).
#
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b --factory-startup \
#       --python scripts/tools/blender/hand_parts.py -- [--preview 그림.png]
#
# 짓는 법 — 마디마다 살을 부호 거리장(SDF)으로 적는다: 둥근 원뿔(뼈대) · 타원체(너클 혹 · 마디 부풂 · 볼 · 두덩)를
# 부드러운 합(smin)으로 녹여 붙이고, 손바닥 가운데 오목은 부드러운 차(smax)로 판다. 격자에서 겉면을 떠(surface nets)
# Blender 메시로 만들고, Decimate 로 줄인 뒤 겉면으로 되붙여 법선을 거리장 기울기로 준다(매끈한 법선 — 게임의 빛
# 사다리 shaders/hand3.gdshader 가 너클 · 마디 · 손끝 볼을 따라 단을 세운다). 손톱은 손끝 겉을 0.2 띄운 얇은 판이다.
#
# 조각마다 제 관절 원점이다 — game.gd _hand3_build 가 그 노드에 붙인다(자세 · IK · 쥠 · 그림자 사본은 게임이 쥔다):
#   palm · palm_mir    손바닥(in) — 손목 원점 · 엄지 쪽 −z / 거울 손(+z)
#   f1_0..3            손가락 첫 마디(j1 — 너클 원점)
#   f2_0..3 · f2s_0..3 가운데 + 끝 마디(j2 — PIP 원점) · 그림자 사본의 짧은 끝(손끝 그림자가 발톱이 안 되게)
#   tm · thenar        엄지 손허리뼈(thumb — CMC 원점) · 엄지 두덩(반지름 1 꼴 — 게임이 THUMB3.th_r 배율로 늘린다)
#   tp · td · tds      엄지 첫마디(t1) · 끝마디(t2) · 그림자 사본의 짧은 끝
# 좌표는 손 좌표 그대로다: 게임 (x 손끝, y 손등, z 폭) = Blender (x, −z, y) — glTF 가 Z-up 을 Y-up 으로 돌린다.
# 치수(너클 자리 · 마디 길이 · 폭 · 두께)는 game.gd FING3 · THUMB3 · HAND3 의 사본이다 — 표를 고치면 여기도 고치고 다시
# 굽는다(qa_hand3 이 조각 끝이 마디 길이에 맞는지 잰다). 재질은 이름만(skin · nail) — 게임이 이름으로 끼운다.
# 화면에서 1 단위가 1px(라이벌 손 1.45px)이다 — 주름 · 땀구멍 · 핏줄은 잡음이라 안 넣는다. 덩어리(너클 · 힘줄 등성이 ·
# 마디 부풂 · 볼 · 두덩)만 빚는다 — 2px 언저리보다 작은 것은 빛 사다리에서 단 하나도 못 세운다.
import bpy
import math
import os
import sys
import numpy as np
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
OUT = os.path.join(ROOT, "assets", "models", "hand_parts.glb")

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
PREVIEW = argv[argv.index("--preview") + 1] if "--preview" in argv else ""

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene

# ── game.gd 표 사본 ─────────────────────────────────────────────────
FX = [30.5, 31.0, 30.5, 28.5]          # FING3.fx — 너클(첫 관절)
FZ = [-11.2, -3.75, 3.75, 11.0]        # FING3.fz
FW = [7.4, 7.6, 7.2, 6.2]              # FING3.fw
FT = [6.4, 6.6, 6.2, 5.4]              # FING3.ft
L1 = [12.5, 13.5, 12.8, 10.0]          # FING3.l1
L2 = [11.5, 13.5, 12.5, 9.5]           # FING3.l2
FY = 0.6                               # FING3.fy
LM, LP, LD = 17.0, 10.0, 7.8           # THUMB3.lm · lp · ld
MW0, MT0, MW1, MT1 = 7.0, 7.0, 9.8, 8.2
PW0, PT0, PW1, PT1 = 9.0, 7.8, 8.4, 7.0
DW0, DT0, DW1, DT1 = 8.0, 6.8, 6.4, 5.4
M_BACK = 4.0


# ── 거리장 ──────────────────────────────────────────────────────────
def A(*v):
    return np.array(v, dtype=np.float64)


def ln(v):
    return np.sqrt(np.sum(v * v, axis=-1))


def smin(a, b, k):
    h = np.maximum(k - np.abs(a - b), 0.0) / k
    return np.minimum(a, b) - h * h * k * 0.25


def smax(a, b, k):
    return -smin(-a, -b, k)


def ellipsoid(p, c, r):
    q = (p - c) / r
    k0 = ln(q)
    k1 = ln(q / r)
    return k0 * (k0 - 1.0) / np.maximum(k1, 1e-9)


def rcone(p, a, b, r1, r2):
    """둥근 원뿔 — a 반지름 r1 에서 b 반지름 r2 로(구 마개). Inigo Quilez 의 식."""
    ba = b - a
    l2 = float(ba @ ba)
    rr = r1 - r2
    a2 = l2 - rr * rr
    il2 = 1.0 / l2
    pa = p - a
    y = pa @ ba
    z = y - l2
    q = pa * l2 - y[:, None] * ba
    x2 = np.sum(q * q, axis=-1)
    y2 = y * y * l2
    z2 = z * z * l2
    k = math.copysign(1.0, rr) * rr * rr * x2
    d3 = (np.sqrt(np.maximum(x2 * a2 * il2, 0.0)) + y * rr) * il2 - r1
    d3 = np.where(np.sign(y) * a2 * y2 < k, np.sqrt(x2 + y2) * il2 - r1, d3)
    return np.where(np.sign(z) * a2 * z2 > k, np.sqrt(x2 + z2) * il2 - r2, d3)


def squash(fn, s):
    """공간을 s 배로 — 둥근 단면을 타원 단면으로(손가락은 폭보다 얇다)."""
    s = A(*s)
    return lambda p: fn(p / s) * float(s.min())


def box2(px, pz, c, half, r):
    """xz 평면의 모깎은 네모(손톱 자리)."""
    qx = np.abs(px - c[0]) - (half[0] - r)
    qz = np.abs(pz - c[1]) - (half[1] - r)
    return np.sqrt(np.maximum(qx, 0.0) ** 2 + np.maximum(qz, 0.0) ** 2) + np.minimum(np.maximum(qx, qz), 0.0) - r


# ── 손바닥 ──────────────────────────────────────────────────────────
# 바탕은 옛 단면(game.gd _hand3_palm_secs)을 그대로 이은 덩어리다 — 손목 단면(27 × 16)이 팔뚝 끝과 맞고 윤곽이 qa_hand3
# 의 엄지 쪽 윤곽 · 물갈퀴 재기와 같다. 그 위에 해부를 얹는다:
#   손등 아치 — 손허리뼈 넷이 이루는 가로 활. 가운데가 솟고 양 옆이 낮다(옛 단면보다 깊게).
#   너클(손허리뼈 머리) 넷 — 가운데가 가장 솟는 호. 넓게 겹친 한 줄 등성이에 봉우리 넷.
#   손등 손허리뼈 넷 — 손목 쪽으로 모이는 낮은 등성이(살 밑 뼈 · 펴짐근 힘줄 자리). 0.35 만 솟는다.
#   새끼두덩(새끼 쪽 손바닥 둔덕) · 손바닥 먼 쪽 볼(손가락 뿌리 밑 살 줄) · 손바닥 가운데 오목.
# 엄지 두덩은 엄지 손허리뼈와 같이 도는 조각(thenar)이라 여기 없다.
SEC = np.array([   # x · 반폭 · 가운데 높이 · 손바닥 쪽 반두께 · 손등 쪽 반두께 · 아치(손등 가운데를 더 솟게) · 지수(클수록 네모)
    (0.0, 13.5, 1.0, 8.0, 8.0, 0.0, 2.3),
    (4.5, 14.1, 0.7, 6.8, 6.0, 1.3, 2.4),
    (12.0, 14.75, 0.4, 6.0, 4.4, 2.6, 2.5),
    (21.0, 15.3, 0.3, 5.5, 3.7, 2.8, 2.6),
    (27.0, 15.5, 0.2, 5.0, 3.4, 1.9, 2.6),
    (30.0, 15.2, 0.1, 4.6, 3.2, 1.0, 2.5),
])
SEC_CAP = 1.6


def sec_at(x):
    return [np.interp(x, SEC[:, 0], SEC[:, i]) for i in range(1, 7)]


def loft(p, cap=True):
    x = p[:, 0]
    hw, yc, hd, hu, ar, ex = sec_at(np.clip(x, SEC[0, 0], SEC[-1, 0]))
    yy = p[:, 1] - yc
    zr = np.abs(p[:, 2]) / hw
    # 손등은 가로로 휜 아치다(손허리뼈 넷이 이루는 활) — 가운데가 솟고 양 옆이 낮다.
    h = np.where(yy > 0.0, hu + ar * np.maximum(0.0, 1.0 - zr * zr), hd)
    n = (zr ** ex + np.abs(yy / h) ** ex) ** (1.0 / ex)
    dx = x - SEC[-1, 0]
    n = np.where(dx > 0.0, np.sqrt(n * n + (np.maximum(dx, 0.0) / SEC_CAP) ** 2), n)
    d = (n - 1.0) * np.minimum(hw, h)
    return np.maximum(d, -x) if cap else d   # 손목은 평평하게 닫는다 — 팔뚝 끝과 맞붙는 면


def top_at(x, z):
    """바탕 손등 윗면 높이(아치 포함)."""
    hw, yc, hd, hu, ar, ex = sec_at(x)
    zr = min(abs(z) / hw, 0.999)
    return yc + (hu + ar * max(0.0, 1.0 - zr * zr)) * (1.0 - zr ** ex) ** (1.0 / ex)


KN_UP = [1.2, 1.5, 1.3, 0.9]               # 너클이 손등 위로 솟는 높이 — 가운데가 가장 높은 호


def palm_sdf(p, cap=True):
    d = loft(p, cap)
    for f in range(4):
        hx = FX[f] - 1.6
        ty = top_at(hx, FZ[f])
        # 너클 — 손허리뼈 머리. 관절(FX)이 그 머리 한가운데 언저리라 손가락이 굽어도 혹이 남는다(주먹의 혹 넷).
        # 넓게 겹쳐 한 줄 등성이에 봉우리 넷 — 따로 선 구슬 넷이면 상자 끝에 얹은 공으로 읽힌다(미리보기).
        r = A(3.4, 3.2, FW[f] * (0.46 if f in (0, 3) else 0.52))     # 바깥 둘은 손 폭(palm_w) 안에
        d = smin(d, ellipsoid(p, A(hx, ty + KN_UP[f] - r[1], FZ[f]), r), 1.8)
        # 손등 손허리뼈 · 펴짐근 힘줄 — 손목 쪽(x 6)으로 모이는 낮은 등성이. 0.35 만 솟는다.
        z0 = FZ[f] * 0.62
        a = A(6.0, top_at(6.0, z0) - 1.55, z0)
        b = A(hx - 2.5, top_at(hx - 2.5, FZ[f]) - 1.55, FZ[f])
        d = smin(d, rcone(p, a, b, 1.9, 1.9), 2.2)
    d = smin(d, ellipsoid(p, A(12.5, -2.4, 10.0), A(10.0, 3.6, 4.8)), 2.4)
    # 손바닥 먼 쪽 볼 — 손가락 뿌리 밑 살 줄(손금 「감정선」 밑의 그 둔덕).
    d = smin(d, ellipsoid(p, A(27.0, -2.6, 0.6), A(3.2, 2.7, 13.8)), 1.6)
    # 손바닥 가운데 오목 — 두 두덩 사이.
    d = smax(d, -ellipsoid(p, A(16.5, -7.9, -0.5), A(8.5, 2.6, 7.2)), 2.0)
    return d


# ── 손가락 ──────────────────────────────────────────────────────────
# 마디마다 뼈대는 관절에 구 마개를 둔 둥근 원뿔이다 — 굽힐 때 두 마디의 둥근 끝이 겹친 채 돌아 관절이 공처럼 읽힌다.
# 단면은 폭 w · 두께 t 의 타원(squash). 그 위에 손등 쪽 관절 혹(PIP · DIP 머리) · 손바닥 쪽 볼(마디마다 살 패드)을 얹는다.
def f1_sdf(w, t, l1):
    sy = t / w

    def core(p):
        d = smin(rcone(p, A(-1.2, 0.0, 0.0), A(l1 * 0.45, 0.0, 0.0), w * 0.49, w * 0.45),
                 rcone(p, A(l1 * 0.45, 0.0, 0.0), A(l1 - 1.2, 0.0, 0.0), w * 0.45, w * 0.48), 1.0)
        return d
    cs = squash(core, (1.0, sy, 1.0))

    def f(p):
        d = cs(p)
        d = smin(d, ellipsoid(p, A(l1 * 0.58, -t * 0.16, 0.0), A(l1 * 0.28, t * 0.33, w * 0.40)), 1.2)   # 볼
        d = smin(d, ellipsoid(p, A(l1 - 1.0, t * 0.24, 0.0), A(1.9, t * 0.32, w * 0.36)), 0.8)          # PIP 머리
        return d
    return f


def f2_sdf(w, t, l2, short=False):
    sy = t / w
    dip = l2 * 0.58
    if short:
        return squash(lambda p: rcone(p, A(-0.4, 0.0, 0.0), A(l2 * 0.4, 0.0, 0.0), w * 0.41, w * 0.31),
                      (1.0, sy, 1.0))

    def mid(p):
        return smin(rcone(p, A(-0.4, 0.0, 0.0), A(l2 * 0.3, 0.0, 0.0), w * 0.47, w * 0.42),
                    rcone(p, A(l2 * 0.3, 0.0, 0.0), A(dip, -0.1 / sy, 0.0), w * 0.42, w * 0.43), 0.9)
    ms = squash(mid, (1.0, sy, 1.0))
    # 끝 마디는 더 납작하다(손톱 쪽이 평평하고 볼이 처진다)
    ds = squash(lambda p: rcone(p, A(dip, -0.1, 0.0), A(l2 - 2.9, -0.35, 0.0), w * 0.42, w * 0.36),
                (1.0, sy * 0.92, 1.0))

    def f(p):
        d = smin(ms(p), ds(p), 0.8)
        d = smin(d, ellipsoid(p, A(l2 - 2.4, -0.35, 0.0), A(2.4, t * 0.37, w * 0.40)), 0.8)            # 손끝
        d = smin(d, ellipsoid(p, A(dip * 0.48, -t * 0.17, 0.0), A(dip * 0.36, t * 0.30, w * 0.38)), 1.0)  # 가운데 볼
        d = smin(d, ellipsoid(p, A(l2 - 2.6, -t * 0.2, 0.0), A(2.5, t * 0.33, w * 0.40)), 1.0)        # 끝 볼
        d = smin(d, ellipsoid(p, A(dip, t * 0.2, 0.0), A(1.3, t * 0.3, w * 0.33)), 0.7)               # DIP 머리
        return d
    return f


def nail_sdf(skin, c, half, lift=0.22):
    """손톱 — 손끝 겉(skin)을 lift 만큼 띄운 얇은 판을 손등 쪽 모깎은 네모(c · half)로 자른다."""
    def f(p):
        d = skin(p)
        sh = np.maximum(d - lift, -(d + 0.35))
        cut = box2(p[:, 0], p[:, 2], c, half, half[1] * 0.85)
        return np.maximum(np.maximum(sh, cut), 0.4 - p[:, 1])     # 손등 쪽만
    return f


# ── 엄지 ────────────────────────────────────────────────────────────
def tm_sdf():
    sy = MT1 / MW1
    core = squash(lambda p: rcone(p, A(-M_BACK + 3.4, 0.0, 0.0), A(LM - 3.2, 0.0, 0.0), MW0 * 0.5, MW1 * 0.48),
                  (1.0, sy, 1.0))

    def f(p):
        d = core(p)
        return smin(d, ellipsoid(p, A(LM - 1.3, 0.2, 0.0), A(2.4, MT1 * 0.5, MW1 * 0.48)), 1.0)       # MCP 머리
    return f


def thenar_sdf(p):
    """엄지 두덩 — 반지름 1 언저리의 물방울(뿌리 쪽이 굵고 MCP 쪽으로 가늘다 · 손바닥 쪽이 둥글고 붙는 쪽이 납작)."""
    d = rcone(p, A(-0.42, 0.05, 0.0), A(0.5, 0.0, 0.0), 0.62, 0.42)
    d = smin(d, ellipsoid(p, A(-0.15, -0.05, 0.0), A(0.78, 0.8, 0.8)), 0.3)
    return smax(d, p[:, 1] - 0.82, 0.25)


def tp_sdf():
    sy = PT0 / PW0
    core = squash(lambda p: smin(rcone(p, A(0.6, 0.0, 0.0), A(LP * 0.5, 0.0, 0.0), PW0 * 0.5, PW0 * 0.46),
                                 rcone(p, A(LP * 0.5, 0.0, 0.0), A(LP - 0.9, 0.0, 0.0), PW0 * 0.46, PW1 * 0.5), 1.0),
                  (1.0, sy, 1.0))

    def f(p):
        d = core(p)
        d = smin(d, ellipsoid(p, A(LP * 0.48, -PT0 * 0.15, 0.0), A(LP * 0.32, PT0 * 0.32, PW0 * 0.42)), 1.1)  # 볼
        return smin(d, ellipsoid(p, A(LP - 1.0, PT1 * 0.2, 0.0), A(1.8, PT1 * 0.3, PW1 * 0.36)), 0.8)        # IP 머리
    return f


def td_sdf(short=False):
    sy = DT0 / DW0
    if short:
        return squash(lambda p: rcone(p, A(-0.3, 0.0, 0.0), A(LD - 3.2, 0.0, 0.0), DW0 * 0.45, DW1 * 0.4),
                      (1.0, sy, 1.0))
    core = squash(lambda p: rcone(p, A(-0.4, 0.0, 0.0), A(LD - 2.6, -0.3, 0.0), DW0 * 0.5, DW1 * 0.42),
                  (1.0, sy * 0.95, 1.0))

    def f(p):
        d = core(p)
        d = smin(d, ellipsoid(p, A(LD - 2.6, -0.45, 0.0), A(2.6, DT1 * 0.46, DW1 * 0.5)), 0.8)          # 손끝
        return smin(d, ellipsoid(p, A(LD - 3.0, -DT1 * 0.22, 0.0), A(2.7, DT1 * 0.36, DW1 * 0.46)), 1.0)  # 볼
    return f


# ── 겉면 뜨기 · 메시 ─────────────────────────────────────────────────
def nets(sdf, lo, hi, h):
    """surface nets — 부호가 바뀌는 칸마다 꼭짓점 하나(모서리 교점의 평균), 부호가 바뀌는 격자 변마다 네모 하나."""
    lo = A(*lo)
    hi = A(*hi)
    n = (np.ceil((hi - lo) / h) + 1).astype(int)
    ax = [lo[i] + h * np.arange(n[i]) for i in range(3)]
    G = np.stack(np.meshgrid(*ax, indexing="ij"), -1)
    D = sdf(G.reshape(-1, 3)).reshape(tuple(n))
    assert (D[0] > 0).all() and (D[-1] > 0).all() and (D[:, 0] > 0).all() and (D[:, -1] > 0).all() \
        and (D[:, :, 0] > 0).all() and (D[:, :, -1] > 0).all(), "격자가 살을 다 못 덮는다"
    ins = D < 0.0
    cs = tuple(n - 1)

    def C(a, o):
        return a[o[0]:o[0] + cs[0], o[1]:o[1] + cs[1], o[2]:o[2] + cs[2]]
    off = [(i, j, k) for i in (0, 1) for j in (0, 1) for k in (0, 1)]
    cnt = sum(C(ins, o).astype(np.int16) for o in off)
    act = (cnt > 0) & (cnt < 8)
    acc = np.zeros(cs + (3,))
    num = np.zeros(cs)
    for a in off:
        for b in off:
            if a < b and sum(abs(x - y) for x, y in zip(a, b)) == 1:
                da = C(D, a)
                db = C(D, b)
                x = (da < 0.0) != (db < 0.0)
                t = np.where(x, da / np.where(x, da - db, 1.0), 0.0)
                pa = C(G, a)
                acc += np.where(x[..., None], pa + t[..., None] * (C(G, b) - pa), 0.0)
                num += x
    vid = -np.ones(cs, dtype=np.int64)
    idx = np.nonzero(act)
    vid[idx] = np.arange(len(idx[0]))
    verts = acc[idx] / num[idx][:, None]
    quads = []
    for axis in range(3):
        b_ = (axis + 1) % 3
        c_ = (axis + 2) % 3
        s0 = ins.take(range(0, n[axis] - 1), axis=axis)
        s1 = ins.take(range(1, n[axis]), axis=axis)
        q = np.array(np.nonzero(s0 != s1))
        ok = (q[b_] >= 1) & (q[b_] <= n[b_] - 2) & (q[c_] >= 1) & (q[c_] <= n[c_] - 2)
        q = q[:, ok]
        st = s0[tuple(q)]
        vs = []
        for db, dc in ((-1, -1), (0, -1), (0, 0), (-1, 0)):
            cc = q.copy()
            cc[b_] += db
            cc[c_] += dc
            vs.append(vid[tuple(cc)])
        quad = np.stack(vs, 1)
        quad[~st] = quad[~st][:, ::-1]           # 밖 → 안으로 넘으면 법선이 −axis
        quads.append(quad)
    return verts, np.concatenate(quads)


def grad(sdf, p, e=0.04):
    g = np.zeros_like(p)
    for i in range(3):
        o = np.zeros(3)
        o[i] = e
        g[:, i] = (sdf(p + o) - sdf(p - o)) / (2.0 * e)
    return g


def project(sdf, p, it=4):
    for _ in range(it):
        g = grad(sdf, p)
        p = p - (sdf(p) / np.maximum(np.sum(g * g, -1), 1e-6))[:, None] * g
    return p


def to_b(p):
    return np.stack([p[:, 0], -p[:, 2], p[:, 1]], -1)


def from_b(p):
    return np.stack([p[:, 0], p[:, 2], -p[:, 1]], -1)


def decimate(v, f, ratio):
    """Blender Decimate(collapse)로 줄인다 — 꼭짓점 · 면을 돌려준다."""
    me = bpy.data.meshes.new("_dec")
    me.from_pydata(to_b(v).tolist(), [], f.tolist())
    ob = bpy.data.objects.new("_dec", me)
    scene.collection.objects.link(ob)
    md = ob.modifiers.new("dec", "DECIMATE")
    md.ratio = ratio
    md.use_collapse_triangulate = True
    ev = ob.evaluated_get(bpy.context.evaluated_depsgraph_get())
    m2 = bpy.data.meshes.new_from_object(ev)
    vv = np.array([x.co[:] for x in m2.vertices])
    ff = [list(pl.vertices) for pl in m2.polygons]
    bpy.data.objects.remove(ob)
    bpy.data.meshes.remove(me)
    bpy.data.meshes.remove(m2)
    return from_b(vv), ff


MATS = {}


def mat(name, col):
    if name not in MATS:
        m = bpy.data.materials.new(name)
        m.use_nodes = True
        bs = m.node_tree.nodes.get("Principled BSDF")
        bs.inputs["Base Color"].default_value = (*col, 1.0)
        bs.inputs["Roughness"].default_value = 0.6
        MATS[name] = m
    return MATS[name]


SKIN = mat("skin", (0.62, 0.40, 0.40))
NAIL = mat("nail", (0.80, 0.62, 0.62))
PARTS = []


def piece(name, layers, bend=(0.0, 0.0, 0.0)):
    """layers: [(거리장, 격자 lo, hi, 칸, 줄임 비, 재질[, 법선 거리장])] — 겹마다 떠서 한 메시로. 법선 거리장을 주면 법선은
    그 기울기다(손목 마개 · 손톱 판 테처럼 모가 선 자리가 둘레 면을 어둡게 물들이지 않게). bend 는 법선을 그쪽으로 눕힌다(두덩)."""
    vs, fs, ns, mi = [], [], [], []
    base = 0
    for sdf, lo, hi, h, ratio, m, *ns_sdf in layers:
        v, f = nets(sdf, lo, hi, h)
        v = project(sdf, v)
        if ratio < 1.0:
            v, f = decimate(v, f, ratio)
            v = project(sdf, v)
        else:
            f = f.tolist()
        g = grad(ns_sdf[0] if ns_sdf else sdf, v) + A(*bend)
        g /= np.maximum(ln(g), 1e-9)[:, None]
        vs.append(v)
        ns.append(g)
        fs += [[i + base for i in pl] for pl in f]
        mi += [0 if m is SKIN else 1] * len(f)
        base += len(v)
    v = np.concatenate(vs)
    nrm = np.concatenate(ns)
    me = bpy.data.meshes.new(name)
    me.from_pydata(to_b(v).tolist(), [], fs)
    me.materials.append(SKIN)
    me.materials.append(NAIL)
    me.polygons.foreach_set("material_index", mi)
    me.validate()
    me.shade_smooth()
    me.normals_split_custom_set_from_vertices(to_b(nrm).tolist())
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    PARTS.append(ob)
    lo = v.min(0)
    hi = v.max(0)
    t3 = np.array([p[:3] for p in fs])
    fn = np.cross(v[t3[:, 1]] - v[t3[:, 0]], v[t3[:, 2]] - v[t3[:, 0]])
    # 감김이 법선을 거스르는 면 — 법선 거리장을 따로 준 겹(손목 마개 · 손톱 판 안쪽)만 나온다(살 속 · 팔뚝에 붙어 안 보인다)
    flip = int(np.sum(np.sum(fn * nrm[t3].sum(1), -1) < 0.0))
    print("%-9s 꼭짓점 %5d 세모 %5d 뒤집힘 %d  x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f"
          % (name, len(v), sum(len(p) - 2 for p in fs), flip, lo[0], hi[0], lo[1], hi[1], lo[2], hi[2]))
    return ob


def mirror(fn):
    return lambda p: fn(p * A(1.0, 1.0, -1.0))


# ── 짓는다 ──────────────────────────────────────────────────────────
# 격자 칸은 0.25~0.4(손톱 0.1) · 줄임 비 DEC — 법선은 거리장이 주므로 면을 줄여도 빛 단이 매끈하다. 손이 화면 1 단위 =
# 1px 이라 세모 변 0.6 언저리면 윤곽이 반 px 안에 든다(손 둘 + 그림자 사본 둘이 같이 그려진다).
DEC = 0.15
PALM_BOX = ((-1.0, -10.0, -18.0), (36.0, 10.0, 18.0))
piece("palm", [(palm_sdf, *PALM_BOX, 0.42, DEC, SKIN, lambda p: palm_sdf(p, False))])
piece("palm_mir", [(mirror(palm_sdf), *PALM_BOX, 0.42, DEC, SKIN, mirror(lambda p: palm_sdf(p, False)))])
for f in range(4):
    w, t = FW[f], FT[f]
    box = ((-6.0, -t, -w), (L1[f] + 4.0, t, w))
    piece("f1_%d" % f, [(f1_sdf(w, t, L1[f]), *box, 0.26, DEC, SKIN)])
    sk = f2_sdf(w, t, L2[f])
    box = ((-5.0, -t, -w), (L2[f] + 1.5, t, w))
    nb = ((L2[f] - 6.0, 0.0, -w * 0.6), (L2[f] + 1.0, t, w * 0.6))
    piece("f2_%d" % f, [(sk, *box, 0.26, DEC, SKIN),
                        (nail_sdf(sk, (L2[f] - 2.65, 0.0), (1.95, w * 0.27)), *nb, 0.1, DEC * 1.6, NAIL, sk)])
    piece("f2s_%d" % f, [(f2_sdf(w, t, L2[f], True), *box, 0.3, DEC * 1.6, SKIN)])
piece("tm", [(tm_sdf(), (-M_BACK - 1.5, -MT1, -MW1), (LM + 2.5, MT1, MW1), 0.28, DEC, SKIN)])
piece("thenar", [(thenar_sdf, (-1.3, -1.2, -1.2), (1.3, 1.2, 1.2), 0.05, DEC, SKIN)], bend=(0.0, -0.8, 0.0))
piece("tp", [(tp_sdf(), (-5.0, -PT0, -PW0), (LP + 4.0, PT0, PW0), 0.28, DEC, SKIN)])
tdk = td_sdf()
piece("td", [(tdk, (-5.0, -DT0, -DW0), (LD + 1.5, DT0, DW0), 0.24, DEC, SKIN),
             (nail_sdf(tdk, (LD - 2.6, 0.0), (1.8, DW1 * 0.33)), (LD - 6.0, 0.0, -DW0 * 0.6),
              (LD + 1.0, DT0, DW0 * 0.6), 0.1, DEC * 1.6, NAIL, tdk)])
piece("tds", [(td_sdf(True), (-5.0, -DT0, -DW0), (LD + 1.5, DT0, DW0), 0.3, DEC * 1.6, SKIN)])

os.makedirs(os.path.dirname(OUT), exist_ok=True)
bpy.ops.object.select_all(action="DESELECT")
for ob in PARTS:
    ob.select_set(True)
bpy.context.view_layer.objects.active = PARTS[0]
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_apply=True,
                          export_yup=True, export_animations=False, export_cameras=False, export_lights=False,
                          export_normals=True)
print("wrote", OUT)

if PREVIEW:
    # 쉬는 손(game.gd FPOSE.rest · _thumb3_pose)으로 엮어 게임 카메라(직교 · 52° 내려다본다)로 찍는다.
    CB = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))

    def put(name, mg):
        src = bpy.data.objects[name]
        ob = bpy.data.objects.new(name + "_v", src.data)
        scene.collection.objects.link(ob)
        ob.matrix_world = CB @ mg @ CB.inverted()

    def R(axis, deg):
        return Matrix.Rotation(math.radians(deg), 4, axis)

    def T(x, y, z):
        return Matrix.Translation(Vector((x, y, z)))

    for ob in PARTS:
        ob.hide_render = True
    c1 = [7.0, 8.0, 10.0, 13.0]
    c2 = [12.0, 14.0, 16.0, 18.0]
    fan = [1.0, 0.32, -0.32, -1.0]
    hand = R("Y", -90.0)                      # 손끝이 카메라 쪽(+z)
    put("palm", hand)
    for f in range(4):
        j1 = hand @ T(FX[f], FY, FZ[f]) @ R("Y", 3.0 * fan[f]) @ R("Z", -c1[f])
        put("f1_%d" % f, j1)
        put("f2_%d" % f, j1 @ T(L1[f], 0.0, 0.0) @ R("Z", -c2[f]))
    mb = R("Y", 24.0) @ R("X", -12.0) @ R("Z", -10.1)
    tm = hand @ T(6.0, -2.5, -12.0) @ mb
    put("tm", tm)
    put("thenar", tm @ T(LM * 0.36, -2.2, -0.4) @ Matrix.Diagonal((8.6, 4.8, 5.6, 1.0)))
    pb = R("Y", 18.0) @ R("X", -24.0) @ R("Z", -8.0)
    ta = tm @ T(LM, 0.0, 0.0) @ (mb.inverted() @ pb)
    put("tp", ta)
    put("td", ta @ T(LP, 0.0, 0.0) @ R("Z", -10.0))
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    scene.collection.objects.link(cam)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 70.0
    cam.rotation_euler = (math.radians(52.0), 0.0, 0.0)
    d = Vector((0.0, math.sin(math.radians(52.0)), -math.cos(math.radians(52.0))))
    cam.location = Vector((0.0, -28.0, 0.0)) - d * 150.0
    scene.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(35.0), math.radians(-20.0), math.radians(10.0))
    scene.collection.objects.link(sun)
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = 480
    scene.render.resolution_y = 480
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.08, 0.06, 0.09, 1.0)
    scene.world = w
    scene.render.filepath = PREVIEW
    bpy.ops.render.render(write_still=True)
    print("preview", PREVIEW)
