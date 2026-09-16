# -*- coding: utf-8 -*-
u"""동전 얼굴을 **한 말투로** 짓는 붓.

    import sys; sys.path.insert(0, "scripts/tools")
    from coin_paint import Face
    f = Face("c04", "위대한 피자", bg="wood")
    f.ellipse(17.5, 17.5, 12, 12, "gold")            # 물건 하나 = 한 재질
    f.ellipse(17.5, 17.5, 9, 9, "orange")
    f.dot(14, 15, "red", 3)                          # 손으로 찍는 점
    print(f.text())                                  # faces.txt 에 넣을 한 장

── 왜 붓이 따로 있나 ───────────────────────────────────────
쉰일곱 장을 한 판에 놓으면 **장마다 솜씨가 아니라 말투가 달랐다.**
외곽선이 있다 없다, 빛이 왼쪽에서 왔다 오른쪽에서 왔다, 바탕이 흰색·검정·
분홍·회색, 색은 판마다 따로 뽑았다. 한 장씩은 괜찮은데 한 판으로는 남의
그림 쉰일곱 장이었다. 세련돼 보이는 도트 세트가 공유하는 것은 솜씨가
아니라 **규칙 넷**이다.

  ① 팔레트가 하나다     PAL 의 램프 열넷 × 네 단. 밖의 색은 못 쓴다
  ② 빛이 하나다         왼쪽 위. 윗·왼 가장자리가 한 단 밝고 아랫·오른쪽이
                        한 단 어둡다 — 사람이 칠하면 장마다 방향이 샌다
  ③ **테두리선이 없다**  물건과 물건은 선이 아니라 **값(밝기)의 차**로 가른다.
                        외곽선을 둘렀더니 피자가 어둡고 답답해졌다 — 선 없이
                        밝고 큰 덩어리였던 첫 판이 더 나았다(2026-09-16).
                        outline·edge 는 남겨 두되 기본은 끈다
  ④ 바탕이 하나의 꼴이다  한 램프로 가운데가 밝고 가장자리가 한 단 어둡다 —
                        찍어 누른 동전 면처럼 들어가 보인다

이 넷을 사람 손에 맡기면 열두 손이 열두 가지로 지킨다. 붓이 지키게 둔다.
붓이 내는 것은 여전히 **격자**라서, 굽고 난 뒤 한 칸씩 손으로 고칠 수 있다.
"""
import math

N = 36

#  ── ① 팔레트 ────────────────────────────────────────────
#  램프마다 네 단(0 어둠 → 3 밝음). 어둠은 보라 쪽으로, 밝음은 크림 쪽으로
#  색상을 민다 — 명도만 내리면 그늘이 탁해지고, 게임 바탕(C_BG 14111f ·
#  C_DARK 2b2438)과 같은 식구로 안 보인다.
INK = "1a1424"
PAL = {
    "night":  ["14111f", "221c33", "352d4d", "4f4670"],   # 게임 바탕 계열
    "dusk":   ["2b2438", "4a4160", "7a7192", "b3abc8"],   # 회보라 — C_WIRE
    "cream":  ["8f8577", "c9bfae", "e8dfc8", "fbf6ea"],   # C_LIGHT · C_TXT
    "steel":  ["3a3f52", "687085", "a3abbb", "dde3ec"],
    "skin":   ["6e3b39", "a8634f", "dc9a73", "f5cda3"],
    "red":    ["4a1426", "8c2233", "d8483d", "f27d63"],   # C_RED · C_MULT
    "orange": ["6b2a1c", "b0512a", "e8873a", "f7ba70"],
    "gold":   ["5c3a1a", "a8762a", "f2c94c", "fdeaa0"],   # C_GOLD
    "green":  ["1d3326", "2f6340", "479a58", "94d68e"],   # C_GREEN · C_ODDS
    "teal":   ["14343f", "1f6570", "36a3a0", "8fe0cf"],
    "blue":   ["1a2150", "2b4a95", "3f7fd8", "91cbf5"],   # C_CHIP
    "violet": ["2b1d4f", "523a8f", "8161c9", "bca1ed"],
    "pink":   ["4d1840", "8e2f6e", "d45a9e", "f5a3cb"],
    "wood":   ["2a1812", "553222", "8a5636", "c48b5a"],   # C_WOOD
}
ALL = {INK} | {c for r in PAL.values() for c in r}

#  원형 알파의 반지름(make_coin_art.EDGE 0.965). 이 밖은 안 보인다.
R_VIS = N * 0.965 / 2.0
C = (N - 1) / 2.0


def col(ramp, step):
    if ramp == "ink":
        return INK
    return PAL[ramp][max(0, min(3, step))]


class _Obj:
    def __init__(s, cells, ramp, base, z, shade, outline, edge):
        s.cells, s.ramp, s.base, s.z = cells, ramp, base, z
        s.shade, s.outline, s.edge = shade, outline, edge


class Face:
    u"""한 장. bg 는 바탕 램프, bg_base 는 바탕 가운데의 단(가장자리는 한 단 아래)."""

    def __init__(s, cid, name, bg="night", bg_base=2):
        s.cid, s.name = cid, name
        s.bg, s.bg_base = bg, bg_base
        s.objs = []
        s.dots = {}
        s._z = 0

    #  ── 물건 ─────────────────────────────────────────────
    #  물건 하나 = 칸 모음 하나 + 재질(램프) 하나. base 는 그 물건의 가운데 단.
    #    shade    ② 빛을 받는다(윗·왼 +1, 아랫·오른 −1)
    #    outline  둘레에 ink 를 두른다 — ③ 에 따라 기본은 끈다
    #    edge     아래 물건과 맞닿은 칸을 제 base−2 로 가른다 — 기본은 끈다
    #  z 를 안 주면 부른 차례가 곧 쌓는 차례다.
    def _add(s, cells, ramp, base, z, shade, outline, edge):
        if z is None:
            s._z += 1
            z = s._z
        cells = {(x, y) for x, y in cells if 0 <= x < N and 0 <= y < N}
        s.objs.append(_Obj(cells, ramp, base, z, shade, outline, edge))
        return cells

    def ellipse(s, cx, cy, rx, ry, ramp, base=2, z=None, shade=True,
                outline=False, edge=False):
        cells = [(x, y) for y in range(N) for x in range(N)
                 if ((x - cx) / (rx + 0.5)) ** 2 + ((y - cy) / (ry + 0.5)) ** 2 <= 1.0]
        return s._add(cells, ramp, base, z, shade, outline, edge)

    def rect(s, x0, y0, x1, y1, ramp, base=2, z=None, shade=True,
             outline=False, edge=False):
        cells = [(x, y) for y in range(y0, y1 + 1) for x in range(x0, x1 + 1)]
        return s._add(cells, ramp, base, z, shade, outline, edge)

    def poly(s, pts, ramp, base=2, z=None, shade=True, outline=False, edge=False):
        u"""다각형. 칸의 **가운데**가 안에 들면 칠한다 — 경계를 반올림하면
        대각선이 두 칸씩 계단 져서 톱니가 된다."""
        cells = []
        for y in range(N):
            yc = y + 0.5
            xs = []
            for i in range(len(pts)):
                x1, y1 = pts[i]
                x2, y2 = pts[(i + 1) % len(pts)]
                if (y1 <= yc < y2) or (y2 <= yc < y1):
                    xs.append(x1 + (yc - y1) * (x2 - x1) / float(y2 - y1))
            xs.sort()
            for i in range(0, len(xs) - 1, 2):
                for x in range(int(math.ceil(xs[i] - 0.5)),
                               int(math.floor(xs[i + 1] - 0.5)) + 1):
                    cells.append((x, y))
        return s._add(cells, ramp, base, z, shade, outline, edge)

    def cells(s, cells, ramp, base=2, z=None, shade=True, outline=False, edge=False):
        return s._add(cells, ramp, base, z, shade, outline, edge)

    def line(s, x0, y0, x1, y1, ramp, step=2):
        u"""한 칸 굵기 선(손으로 찍는 점의 줄). 브레젠험이라 계단이 겹치지 않는다."""
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

    def dot(s, x, y, ramp, step=2):
        u"""손으로 찍는 점. 빛·외곽선을 안 거치고 맨 위에 앉는다."""
        x, y = int(x), int(y)
        if 0 <= x < N and 0 <= y < N:
            s.dots[(x, y)] = col(ramp, step)

    #  ── 굽기 ─────────────────────────────────────────────
    def grid(s):
        top = {}
        for o in sorted(s.objs, key=lambda o: o.z):
            for p in o.cells:
                top[p] = o
        g = [[None] * N for _ in range(N)]
        #  ④ 바탕 — 가운데 밝고 가장자리 한 단 어둡다
        for y in range(N):
            for x in range(N):
                d = math.hypot(x - C, y - C)
                st = s.bg_base if d <= R_VIS - 3.2 else s.bg_base - 1
                g[y][x] = col(s.bg, st)
        #  ③ 외곽선 — 물건 밖, 외곽선 물건에 네 방향으로 닿는 칸
        for y in range(N):
            for x in range(N):
                if (x, y) in top:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    o = top.get((x + dx, y + dy))
                    if o is not None and o.outline:
                        g[y][x] = INK
                        break
        #  물건 — ② 빛과 ③ 셀아웃
        for (x, y), o in top.items():
            if o.edge:
                under = [top.get((x + dx, y + dy)) for dx, dy in
                         ((1, 0), (-1, 0), (0, 1), (0, -1))]
                if any(u is not None and u is not o and u.z < o.z for u in under):
                    g[y][x] = col(o.ramp, o.base - 2)
                    continue
            st = o.base
            if o.shade and _on_edge(o.cells, x, y):
                k = _facing(o.cells, x, y)
                if k > 0.35:
                    st = o.base + 1
                elif k < -0.35:
                    st = o.base - 1
            g[y][x] = col(o.ramp, st)
        for (x, y), c in s.dots.items():
            g[y][x] = c
        return g

    def text(s):
        u"""faces.txt 에 넣을 한 장. 팔레트 글자는 쓰인 차례로 붙는다."""
        g = s.grid()
        used = []
        for row in g:
            for c in row:
                if c not in used:
                    used.append(c)
        keys = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
        if len(used) > len(keys):
            raise ValueError("%s: 색이 %d 가지다" % (s.cid, len(used)))
        m = {c: keys[i] for i, c in enumerate(used)}
        out = ["== %s  %s" % (s.cid, s.name)]
        out += ["= %s %s" % (m[c], c) for c in used]
        out += ["".join(m[c] for c in row) for row in g]
        return "\n".join(out) + "\n"


def _on_edge(cells, x, y):
    return any((x + dx, y + dy) not in cells
               for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))


#  ② 빛 — 가장자리가 **어느 쪽을 보는가**를 반경 2 안에서 모아 잰다.
#  네 이웃만 보면 대각선 계단의 칸마다 윗면과 옆면이 번갈아 걸려서 큰
#  물건의 가장자리가 밝음·어둠 줄무늬로 떨린다(큰 파도가 그랬다). 둘레
#  스물네 칸 중 바깥인 칸의 방향을 더하면 계단이 아니라 곡면의 방향이 나온다.
_L = (-math.sqrt(0.5), -math.sqrt(0.5))       # 빛이 오는 쪽 — 왼쪽 위


def _facing(cells, x, y):
    nx = ny = 0.0
    for dy in range(-2, 3):
        for dx in range(-2, 3):
            if (dx or dy) and (x + dx, y + dy) not in cells:
                w = 1.0 / math.hypot(dx, dy)
                nx += dx * w
                ny += dy * w
    ln = math.hypot(nx, ny)
    if ln < 1e-6:
        return 0.0
    return (nx * _L[0] + ny * _L[1]) / ln


def off_palette(pal):
    u"""팔레트 밖의 색. faces.txt 의 한 장({글: hex})을 받는다."""
    return sorted(h.lower() for h in pal.values() if h.lower() not in ALL)
