# -*- coding: utf-8 -*-
u"""전설 동전 다섯을 그림으로 굽는다 — assets/coin/leg/<id>{,_soul,_mask,_glow}.png

2026-10-12 「전설 동전들 좀 멋있는 모양이랑 일러로」 → 시안(scripts/tools/coin_redesign_mock.py)에서 사용자가
「이대로 + 영혼」을 골랐다. 효과에서 딴 실루엣 다섯 · 분홍 금 테 · 그 실루엣을 꽉 채운 그림 · 판 밖으로
떠오르는 「영혼」 한 겹(발라트로 전설 조커의 떠오르는 얼굴).

  l01 데칼코마니  접은 나비 날개 — 좌우가 같다(score=bal). 먹 번짐 종이 · 영혼은 나비
  l02 정조준      조준경 — 둥근 렌즈 + 네 갈래 가늠쇠(aim=place). 영혼은 한가운데 꽂힌 다트
  l03 NULL        깨진 고리 — 속이 빈 검은 구멍(값이 없다) · 영혼은 떨어져 나간 조각 둘
  l04 잭과 콩나무  위로 긴 아치(자란다) — 하늘 · 구름 성 · 콩나무 · 영혼은 오르는 잭과 꼭대기 잎
  l05 녹는 시계    회중시계가 아래로 녹아 흐른다(side=carry) · 영혼은 떨어지는 방울

그림은 coin_paint 의 네 규칙을 그대로 지킨다 — 팔레트 하나(PAL) · 빛은 왼쪽 위 · 테두리선 없음 · 바탕은
가운데가 밝다. 격자만 44 칸이다(동전 36 칸보다 크다 — 전설은 판 전체가 얼굴이다). 한 칸 = 게임 논리 1px.
테(분홍 금 비탈)는 K 배로 매끈하게 짓고 그림은 K 배 nearest 로 키워 얹는다 — 일반 동전의 쇠 테(벡터)와
도트 얼굴이 만나는 그 짝이다.

물리 원(chip_r 22.04) 안에 다 든다 — 캔버스 반폭 22.0. 번짐만 G 칸 더 넓은 캔버스에 따로 굽는다.

  python scripts/tools/make_legend_art.py           굽기 + outputs/coin_redesign/legend_sheet.png
  python scripts/tools/make_legend_art.py 40 <폴더>  포스터용 큰 판(K 40) — assets 는 안 건드린다
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from coin_paint import PAL, INK  # noqa: E402

ROOT = HERE.parents[1]
OUT = ROOT / "assets/coin/leg"
SHEET = ROOT / "outputs/coin_redesign/legend_sheet.png"
N = 44                  # 그림 격자(논리 px)
K = 4                   # 텍스처 px / 논리 px
G = 10                  # 번짐 캔버스 여백(논리 px)
R = 21.6                # 실루엣 반지름(논리 px) — chip_r 22.04 안
RIM = 2.6               # 분홍 금 테 폭(논리 px)
LIGHT = np.array([-0.62, -0.78])
ROSE = [(86, 22, 54), (196, 82, 136), (248, 162, 196), (255, 232, 242)]


def hx(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def P(ramp, step):
    if ramp == "ink":
        return hx(INK)
    return hx(PAL[ramp][max(0, min(3, step))])


# ─────────────────────────────────────────────────────────────
#  실루엣 — 논리 좌표(가운데 0,0 · 아래 +y). 다각형 · 타원 · 구멍을 합친다.
# ─────────────────────────────────────────────────────────────
def ell(cx, cy, rx, ry, rot=0.0, n=96):
    out = []
    for t in np.linspace(0, 2 * math.pi, n, endpoint=False):
        x, y = math.cos(t) * rx, math.sin(t) * ry
        out.append((cx + x * math.cos(rot) - y * math.sin(rot), cy + x * math.sin(rot) + y * math.cos(rot)))
    return out


def rrect(x0, y0, x1, y1, r, n=8):
    out = []
    for cx, cy, a0 in ((x1 - r, y0 + r, -90), (x1 - r, y1 - r, 0), (x0 + r, y1 - r, 90), (x0 + r, y0 + r, 180)):
        for t in np.linspace(math.radians(a0), math.radians(a0 + 90), n):
            out.append((cx + math.cos(t) * r, cy + math.sin(t) * r))
    return out


SHAPES = {
    "l01": {"add": [ell(-R * .47, -R * .22, R * .50, R * .44, .45), ell(R * .47, -R * .22, R * .50, R * .44, -.45),
                    ell(-R * .36, R * .44, R * .36, R * .30, -.40), ell(R * .36, R * .44, R * .36, R * .30, .40),
                    ell(0, 0, R * .22, R * .62)], "sub": []},
    "l02": {"add": [ell(0, 0, R * .74, R * .74)] + [
        [(math.cos(a) * R * .99, math.sin(a) * R * .99),
         (math.cos(a) * R * .60 - math.sin(a) * R * .17, math.sin(a) * R * .60 + math.cos(a) * R * .17),
         (math.cos(a) * R * .60 + math.sin(a) * R * .17, math.sin(a) * R * .60 - math.cos(a) * R * .17)]
        for a in (0, math.pi / 2, math.pi, 3 * math.pi / 2)], "sub": []},
    "l03": {"add": [ell(0, 0, R * .92, R * .92)], "sub": [ell(0, 0, R * .50, R * .50),
            [(0, 0)] + [(math.cos(a) * R * 1.2, math.sin(a) * R * 1.2)
                        for a in np.linspace(math.radians(-72), math.radians(-18), 12)]]},
    "l04": {"add": [rrect(-R * .62, -R * .30, R * .62, R * .94, R * .14), ell(0, -R * .30, R * .62, R * .66)],
            "sub": []},
    "l05": {"add": [ell(0, -R * .10, R * .76, R * .70), rrect(-R * .11, -R * .98, R * .11, -R * .68, R * .05),
                    ell(0, -R * .94, R * .17, R * .11)] +
                   [rrect(R * (x - w), R * .25, R * (x + w), R * (.30 + L), R * w)
                    for x, L, w in ((-.44, .48, .12), (.06, .66, .14), (.48, .38, .10))], "sub": []},
}


def mask_at(shape, scale, size, ox=0.0):
    """실루엣 알파(0..1) — scale 배(px/논리), size 한 변 px, 가운데 정렬."""
    ss = 3
    m = Image.new("L", (size * ss, size * ss))
    d = ImageDraw.Draw(m)
    c = size * ss / 2

    def tr(pts):
        return [(c + (x + ox) * scale * ss, c + y * scale * ss) for x, y in pts]
    for pts in shape["add"]:
        d.polygon(tr(pts), fill=255)
    for pts in shape["sub"]:
        d.polygon(tr(pts), fill=0)
    return np.asarray(m.resize((size, size), Image.Resampling.LANCZOS), np.float32) / 255.0


def cells_of(shape, inset=0.0):
    """그림 칸(N x N) — 칸 가운데가 실루엣 안(테 안쪽 inset 논리 px)에 드는가."""
    m = mask_at(shape, 8, N * 8)
    if inset > 0:
        im = Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.MinFilter(int(inset * 8 * 2) | 1))
        m = np.asarray(im, np.float32) / 255.0
    return m[4::8, 4::8] > 0.5


# ─────────────────────────────────────────────────────────────
#  붓 — coin_paint.Face 의 네 규칙을 44 칸 · 마스크 바탕으로
# ─────────────────────────────────────────────────────────────
class Art:
    def __init__(s, inside):
        s.inside = inside                       # 바탕이 깔리는 칸(실루엣 안)
        s.objs = []
        s.dots = {}
        s.bg = None

    def background(s, fn):
        u"""fn(x, y) → (ramp, step) — 칸마다 바탕을 고른다(하늘 띠 · 종이 · 렌즈)."""
        s.bg = fn

    def add(s, cells, ramp, base=2, shade=True):
        s.objs.append((set((x, y) for x, y in cells if 0 <= x < N and 0 <= y < N), ramp, base, shade))
        return s

    def ellipse(s, cx, cy, rx, ry, ramp, base=2, shade=True):
        return s.add([(x, y) for y in range(N) for x in range(N)
                      if ((x - cx) / (rx + .5)) ** 2 + ((y - cy) / (ry + .5)) ** 2 <= 1.0], ramp, base, shade)

    def poly(s, pts, ramp, base=2, shade=True):
        cells = []
        for y in range(N):
            yc = y + .5
            xs = []
            for i in range(len(pts)):
                x1, y1 = pts[i]
                x2, y2 = pts[(i + 1) % len(pts)]
                if (y1 <= yc < y2) or (y2 <= yc < y1):
                    xs.append(x1 + (yc - y1) * (x2 - x1) / float(y2 - y1))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                for x in range(int(math.ceil(xs[i] - .5)), int(math.floor(xs[i + 1] - .5)) + 1):
                    cells.append((x, y))
        return s.add(cells, ramp, base, shade)

    def rect(s, x0, y0, x1, y1, ramp, base=2, shade=True):
        return s.add([(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)], ramp, base, shade)

    def dot(s, x, y, ramp, step=2):
        x, y = int(x), int(y)
        if 0 <= x < N and 0 <= y < N:
            s.dots[(x, y)] = P(ramp, step)
        return s

    def line(s, x0, y0, x1, y1, ramp, step=2):
        x0, y0, x1, y1 = int(x0), int(y0), int(x1), int(y1)
        dx, dy = abs(x1 - x0), -abs(y1 - y0)
        sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
        err = dx + dy
        while True:
            s.dot(x0, y0, ramp, step)
            if x0 == x1 and y0 == y1:
                break
            e2 = 2 * err
            if e2 >= dy:
                err += dy
                x0 += sx
            if e2 <= dx:
                err += dx
                y0 += sy
        return s

    def rgba(s):
        out = np.zeros((N, N, 4), np.uint8)
        if s.bg is not None:
            for y in range(N):
                for x in range(N):
                    if s.inside[y, x]:
                        r, st = s.bg(x, y)
                        out[y, x, :3] = P(r, st)
                        out[y, x, 3] = 255
        top = {}
        for o in s.objs:
            for p in o[0]:
                top[p] = o
        for (x, y), (cells, ramp, base, shade) in top.items():
            st = base
            if shade:
                edge = [(x + dx, y + dy) not in cells for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
                if any(edge):
                    k = (-1 if (x - 1, y) not in cells else 0) * -1 * .62 + (1 if (x + 1, y) not in cells else 0) * -.62
                    k += (-1 if (x, y - 1) not in cells else 0) * -1 * .78 + (1 if (x, y + 1) not in cells else 0) * -.78
                    if k > .35:
                        st = base + 1
                    elif k < -.35:
                        st = base - 1
            out[y, x, :3] = P(ramp, st)
            out[y, x, 3] = 255
        for (x, y), c in s.dots.items():
            out[y, x, :3] = c
            out[y, x, 3] = 255
        return out


# ─────────────────────────────────────────────────────────────
#  다섯의 그림 · 영혼
# ─────────────────────────────────────────────────────────────
CX = (N - 1) / 2.0


def art_l01(inside):
    u"""데칼코마니 — 반으로 접어 찍은 먹 번짐. 왼쪽만 짓고 거울로 옮긴다(좌우가 같다 = 효과)."""
    a = Art(inside)
    a.background(lambda x, y: ("cream", 3 if math.hypot(x - CX, y - 20) < 15 else 2))
    blots = [((14, 13), 6.5, 5.0, "violet", 1), ((8, 20), 5.0, 6.0, "pink", 2), ((16, 24), 4.0, 3.5, "violet", 2),
             ((11, 31), 4.5, 3.5, "pink", 2), ((18, 33), 2.5, 2.0, "violet", 1), ((6, 12), 2.5, 2.0, "pink", 2),
             ((18, 17), 2.0, 3.0, "pink", 3)]
    for (bx, by), rx, ry, ramp, base in blots:
        for side in (0, 1):
            cx = bx if side == 0 else N - 1 - bx
            a.ellipse(cx, by, rx, ry, ramp, base)
    for y in range(4, 40):                          # 접은 금
        a.dot(CX, y, "cream", 1)
        a.dot(CX + 1, y, "cream", 1)
    return a


def soul_l01(inside):
    u"""나비 — 날개 넷(주황 · 하늘) · 몸 · 더듬이. 작게(먹 번짐 종이가 보이게) 실루엣 위쪽에 떠오른다."""
    a = Art(inside)
    for side in (-1, 1):
        a.ellipse(CX + side * 4.6, 9, 4.0, 3.0, "orange", 2)
        a.dot(CX + side * 4.6, 8, "orange", 3)
        a.ellipse(CX + side * 3.8, 14, 2.8, 2.4, "blue", 2)
        a.dot(CX + side * 3.6, 14, "pink", 3)
    a.rect(int(CX), 6, int(CX) + 1, 16, "night", 1)
    a.line(CX, 6, CX - 2, 3, "night", 1)
    a.line(CX + 1, 6, CX + 3, 3, "night", 1)
    return a


def art_l02(inside):
    u"""정조준 — 렌즈(청록 · 가운데 밝다) · 십자선(가운데 끊김) · 눈금 · 안 고리 · 왼쪽 위 반사."""
    a = Art(inside)
    a.background(lambda x, y: ("teal", 3 if math.hypot(x - CX + 4, y - CX + 4) < 7 else
                               (2 if math.hypot(x - CX, y - CX) < 13 else 1)))
    for r0 in (9.5,):
        a.add([(x, y) for y in range(N) for x in range(N)
               if abs(math.hypot(x - CX, y - CX) - r0) < .7], "night", 1, shade=False)
    for d in range(3, 15):
        for (x, y) in ((CX + d, CX), (CX - d, CX), (CX, CX + d), (CX, CX - d)):
            a.dot(x, y, "night", 0)
    for d in (5, 8, 11):                             # 눈금
        for s_ in (-1, 1):
            a.dot(CX + s_ * d, CX - 1, "night", 0)
            a.dot(CX - 1, CX + s_ * d, "night", 0)
    for t in np.linspace(math.radians(200), math.radians(250), 9):   # 반사
        a.dot(CX + math.cos(t) * 12, CX + math.sin(t) * 12, "teal", 3)
    a.dot(CX, CX, "red", 2)
    return a


def soul_l02(inside):
    u"""한가운데 꽂힌 다트 — 촉은 렌즈 한가운데, 몸통과 깃이 보는 쪽 오른 위로 튀어나온다."""
    a = Art(inside)
    tip = (CX + .5, CX + .5)
    a.line(tip[0], tip[1], tip[0] + 6, tip[1] - 6, "steel", 2)           # 촉 · 배럴
    a.line(tip[0] + 1, tip[1], tip[0] + 7, tip[1] - 6, "steel", 1)
    a.poly([(CX + 6, CX - 8), (CX + 10, CX - 11), (CX + 9, CX - 6)], "steel", 3)
    a.poly([(CX + 9, CX - 10), (CX + 16, CX - 18), (CX + 18, CX - 14), (CX + 12, CX - 9)], "pink", 2)   # 깃
    a.poly([(CX + 10, CX - 12), (CX + 12, CX - 20), (CX + 14, CX - 18), (CX + 12, CX - 11)], "pink", 3)
    a.poly([(CX + 11, CX - 9), (CX + 19, CX - 11), (CX + 18, CX - 8), (CX + 12, CX - 7)], "pink", 1)
    a.dot(CX, CX, "red", 3)
    return a


def art_l03(inside):
    u"""NULL — 속은 검은 구멍. 깨진 화소 몇 줄(분홍 · 청록)이 떠다닌다. 고리는 테가 맡는다."""
    a = Art(inside)
    rng = np.random.default_rng(4)
    a.background(lambda x, y: ("night", 0 if math.hypot(x - CX, y - CX) < 10.5 else 1))
    for _ in range(9):
        y = int(rng.integers(13, 31))
        x0 = int(rng.integers(12, 26))
        L = int(rng.integers(2, 6))
        ramp = ["pink", "teal", "cream"][int(rng.integers(0, 3))]
        for x in range(x0, x0 + L):
            if math.hypot(x - CX, y - CX) < 10:
                a.dot(x, y, ramp, 3 if ramp != "cream" else 2)
    return a


def soul_l03(inside):
    u"""떨어져 나간 조각 둘 — 깨진 틈(오른 위) 밖에 떠 있다. 게임이 화소째 떨게 한다."""
    a = Art(inside)
    for (a0, a1, push) in ((-70, -48, 3.0), (-44, -22, 5.0)):
        pts = []
        for t in np.linspace(math.radians(a0), math.radians(a1), 6):
            pts.append((CX + .5 + math.cos(t) * (R * .92 + push), CX + .5 + math.sin(t) * (R * .92 + push)))
        for t in np.linspace(math.radians(a1), math.radians(a0), 6):
            pts.append((CX + .5 + math.cos(t) * (R * .50 + push), CX + .5 + math.sin(t) * (R * .50 + push)))
        a.poly(pts, "pink", 2)
    return a


def art_l04(inside):
    u"""잭과 콩나무 — 위는 하늘(밝게) · 구름 위 작은 성 · 아래는 땅 · 가운데를 감아 오르는 콩나무와 잎."""
    a = Art(inside)
    a.background(lambda x, y: ("blue", 3 if y < 16 else 2) if y < 36 else ("green", 1))
    a.ellipse(13, 13, 6, 2.6, "cream", 3)            # 구름 — 왼쪽(잭이 가운데로 나온다)
    a.ellipse(19, 14, 5, 2.2, "cream", 2)
    a.rect(10, 8, 15, 11, "dusk", 3)                 # 구름 위 작은 성
    for x in (10, 12, 15):
        a.rect(x, 6, x, 7, "dusk", 3)
    a.rect(12, 9, 13, 11, "dusk", 1)
    # 콩나무 — 사인으로 감아 오른다(두께 3) · 잎은 굽이마다
    for y in range(12, 44):
        x = CX + math.sin(y * .32) * 4.0
        for dx in (-1, 0, 1):
            a.add([(int(round(x + dx)), y)], "green", 2 if dx < 1 else 1, shade=False)
    for y, side in ((16, 1), (22, -1), (28, 1), (34, -1), (40, 1)):
        x = CX + math.sin(y * .32) * 4.0
        a.ellipse(x + side * 5, y - 1, 3.6, 1.8, "green", 2)
        a.dot(x + side * 4, y - 2, "green", 3)
    return a


def soul_l04(inside):
    u"""오르는 잭(빨강 윗옷 · 파랑 바지) — 아치 꼭대기 위로 머리와 팔이 나온다 · 꼭대기 잎 한 장."""
    a = Art(inside)
    x0 = int(CX) + 2
    a.ellipse(x0, 3, 2.2, 2.2, "skin", 2)            # 머리
    a.rect(x0 - 2, 1, x0 + 2, 1, "wood", 1)          # 머리칼
    a.rect(x0 - 2, 6, x0 + 2, 10, "red", 2)          # 윗옷
    a.line(x0 + 2, 6, x0 + 4, 2, "skin", 3)          # 위로 뻗은 팔
    a.line(x0 - 2, 7, x0 - 4, 9, "skin", 2)
    a.rect(x0 - 2, 11, x0 - 1, 15, "blue", 2)        # 바지
    a.rect(x0 + 1, 11, x0 + 2, 13, "blue", 1)
    a.ellipse(CX - 6, 4, 4.2, 2.0, "green", 2)       # 꼭대기 잎
    a.line(CX - 2, 6, CX - 8, 3, "green", 1)
    return a


def art_l05(inside):
    u"""녹는 시계 — 크림 시계판(가운데 밝다) · 열두 눈금 · 늘어진 바늘 둘. 아래 방울은 테(케이스)가 맡는다."""
    a = Art(inside)
    a.background(lambda x, y: ("cream", 3 if math.hypot(x - CX + 3, y - 17) < 9 else 2) if y < 32 else
                 ("gold", 2))
    cy = CX - 2.2
    for h in range(12):
        t = h / 12 * 2 * math.pi
        d = 11.5 if h % 3 else 10.5
        a.dot(CX + math.sin(t) * d, cy - math.cos(t) * d, "night", 1)
        if h % 3 == 0:
            a.dot(CX + math.sin(t) * (d + 1), cy - math.cos(t) * (d + 1), "night", 1)
    a.line(CX, cy, CX - 4, cy - 6, "night", 0)       # 짧은바늘
    pts = [(CX + i * .9, cy + i * .55 + (i / 9.0) ** 2 * 6) for i in range(10)]   # 늘어진 긴바늘
    for (x1, y1), (x2, y2) in zip(pts, pts[1:]):
        a.line(x1, y1, x2, y2, "night", 0)
    a.dot(CX, cy, "red", 2)
    return a


def soul_l05(inside):
    u"""떨어지는 방울 — 가운데 늘어진 방울 밑. 게임이 늘였다 떨어뜨린다."""
    a = Art(inside)
    a.ellipse(CX + 1.2, 40.5, 1.8, 2.2, "pink", 2)
    a.dot(CX + .6, 39.5, "pink", 3)
    return a


ARTS = {"l01": (art_l01, soul_l01), "l02": (art_l02, soul_l02), "l03": (art_l03, soul_l03),
        "l04": (art_l04, soul_l04), "l05": (art_l05, soul_l05)}


# ─────────────────────────────────────────────────────────────
#  굽기 — 테(K 배 매끈) + 그림(K 배 nearest)
# ─────────────────────────────────────────────────────────────
def ramp(stops, t):
    t = np.clip(t, 0, 1) * (len(stops) - 1)
    i = np.clip(np.floor(t).astype(int), 0, len(stops) - 2)
    f = (t - i)[..., None]
    s = np.array(stops, np.float32)
    return s[i] * (1 - f) + s[i + 1] * f


def minf(im, k):
    u"""ImageFilter.MinFilter(k) 와 같은 네모 깎기 — 가로 · 세로를 따로, 창을 두 배씩 넓힌다.
    PIL 은 칸마다 k² 를 골라 포스터 굽기(K 40)에선 끝나지 않는다."""
    a = np.asarray(im, np.float32) / 255.0
    r = k // 2
    for _ in range(2):
        m = np.pad(a, ((r, r), (0, 0)), mode="edge")
        w = 1
        while w < k:
            s = min(w, k - w)
            m = np.minimum(m[:-s], m[s:])
            w += s
        a = m.T
    return a


def boxf(a, r):
    u"""실수 상자 흐림(가로 · 세로 두 번씩). K 를 키워 구우면 8비트 흐림의 계단이 테 빛에 등고선으로 선다 —
    기울기를 내기 전에 이것으로 고른다. r 0(K 4 — 게임 그림)은 그대로."""
    if r < 1:
        return a
    for _ in range(2):
        for _ in range(2):
            c = np.cumsum(np.pad(a, ((r + 1, r), (0, 0)), mode="edge"), 0)
            a = (c[2 * r + 1:] - c[:-2 * r - 1]) / (2 * r + 1)
        a = a.T
    return a


def frame(shape, size):
    u"""분홍 금 테 — 실루엣 가장자리 RIM 폭의 비탈. 빛은 흐린 마스크의 기울기(바깥 법선)로 낸다."""
    m = mask_at(shape, K, size)
    mi = Image.fromarray((m * 255).astype(np.uint8))
    er = minf(mi, int(RIM * K * 2) | 1)
    ring = np.clip(m - er, 0, 1)
    b = np.asarray(mi.filter(ImageFilter.GaussianBlur(RIM * K * .5)), np.float32) / 255.0
    gy, gx = np.gradient(boxf(b, K // 8))
    n = np.sqrt(gx * gx + gy * gy) + 1e-6
    lit = (-(gx / n) * LIGHT[0] - (gy / n) * LIGHT[1]) * .5 + .5
    # 마루(테 한가운데)가 가장 밝다 — 테 안에서의 깊이로 고른다
    depth = minf(mi, int(RIM * K * .9) | 1)
    crest = np.clip(m - depth, 0, 1) * (1 - np.clip(depth - er, 0, 1) * .0)
    t = .30 + .55 * lit + .12 * (1 - crest)
    col = ramp(ROSE, t)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    th = np.arctan2(yy - size / 2, xx - size / 2)
    hue = (th / (2 * math.pi) + .5) * 2.0
    holo = np.stack([.5 + .5 * np.sin(2 * math.pi * (hue + o)) for o in (0, .33, .66)], -1) * 255
    col = col * .84 + holo * .16
    out = np.zeros((size, size, 4), np.float32)
    out[..., :3] = col
    out[..., 3] = ring * 255
    # 안 가장자리 그늘 — 그림이 테 밑으로 움푹 들어앉는다(빛 쪽 안쪽이 어둡다)
    inner = er
    ib = np.asarray(Image.fromarray((inner * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(K * .8)),
                    np.float32) / 255.0
    igy, igx = np.gradient(boxf(ib, K // 8))
    ilit = (-(igx) * LIGHT[0] - (igy) * LIGHT[1])
    #  기울기는 K 배로 굽을수록 칸마다 옅다 — 문턱도 K 에 맞춘다(K 4 에서 40)
    shade = np.clip(inner - minf(Image.fromarray((inner * 255).astype(np.uint8)), int(K * 2.2) | 1), 0, 1) \
        * np.clip(ilit * 10 * K, 0, 1) * .55
    return out, m, er, shade


def bake(ident):
    shape = SHAPES[ident]
    size = N * K
    fr, m, inner, shade = frame(shape, size)
    inside = cells_of(shape, RIM * .55)
    a_fn, s_fn = ARTS[ident]
    art = Image.fromarray(a_fn(inside).rgba(), "RGBA").resize((size, size), Image.Resampling.NEAREST)
    art = np.asarray(art, np.float32)
    art[..., 3] *= inner                            # 그림은 테 안에서만
    art[..., :3] *= (1 - shade[..., None])
    base = np.zeros((size, size, 4), np.float32)
    base[..., :3] = (52, 14, 40)                    # 그림이 비우는 칸(투명이 아니라 짙은 판)
    base[..., 3] = inner * 255
    out = base.copy()
    a_ = art[..., 3:] / 255
    out[..., :3] = out[..., :3] * (1 - a_) + art[..., :3] * a_
    out[..., 3] = np.maximum(out[..., 3], art[..., 3])
    f_ = fr[..., 3:] / 255
    out[..., :3] = out[..., :3] * (1 - f_) + fr[..., :3] * f_
    out[..., 3] = np.maximum(out[..., 3], fr[..., 3])
    coin = Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")
    every = np.ones((N, N), bool)
    soul = Image.fromarray(s_fn(every).rgba(), "RGBA").resize((size, size), Image.Resampling.NEAREST)
    a = np.asarray(coin.getchannel("A"), np.float32) / 255.0
    mk = np.zeros((size, size, 4), np.uint8)
    mk[..., :3] = 255
    mk[..., 3] = (a * 255).astype(np.uint8)
    gsize = (N + 2 * G) * K
    gm = np.zeros((gsize, gsize), np.float32)
    o = G * K
    gm[o:o + size, o:o + size] = a
    gb = np.asarray(Image.fromarray((gm * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(K * 4.0)),
                    np.float32) / 255.0
    gl = np.zeros((gsize, gsize, 4), np.uint8)
    gl[..., :3] = 255
    gl[..., 3] = np.clip(gb * 1.6 * 255, 0, 255).astype(np.uint8)
    OUT.mkdir(parents=True, exist_ok=True)
    coin.save(OUT / f"{ident}.png")
    soul.save(OUT / f"{ident}_soul.png")
    Image.fromarray(mk, "RGBA").save(OUT / f"{ident}_mask.png")
    Image.fromarray(gl, "RGBA").save(OUT / f"{ident}_glow.png")
    return coin, soul


def main():
    sheet = Image.new("RGB", (5 * 420 + 40, 520), (22, 14, 20))
    for i, ident in enumerate(ARTS):
        coin, soul = bake(ident)
        view = Image.new("RGBA", coin.size)
        view.alpha_composite(coin)
        sh = Image.new("RGBA", soul.size, (0, 0, 0, 0))
        sh.putalpha(soul.getchannel("A").point(lambda v: int(v * .45)))
        view.alpha_composite(sh.filter(ImageFilter.GaussianBlur(K)), (K, K * 2))
        view.alpha_composite(soul, (0, -K * 3))
        v = view.resize((400, 400), Image.Resampling.NEAREST)
        sheet.paste(v, (20 + i * 420, 60), v)
    SHEET.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(SHEET)
    print("baked", ", ".join(ARTS), "→", OUT)


if __name__ == "__main__":
    if len(sys.argv) == 3:                          # 포스터용 큰 판: make_legend_art.py <K> <폴더>
        K, OUT = int(sys.argv[1]), Path(sys.argv[2])
        for ident in ARTS:
            bake(ident)
        print("baked K", K, "→", OUT)
    else:
        main()
