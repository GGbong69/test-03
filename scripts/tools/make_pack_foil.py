#!/usr/bin/env python3
# -*- coding: utf-8 -*-
u"""팩 겉면 굽기 — 포일 봉투 두 장(작은 팩 · 큰 팩)을 assets/pack/foil_<크기>.png 로 낸다(2026-10-06 겉 셋 — 포일).

    python scripts/tools/make_pack_foil.py            둘 다 굽는다
    python scripts/tools/make_pack_foil.py --sheet    크게 본다 → shots/pack_foil_sheet.png
    godot --headless --path . --import              ← 새 png 가 생긴 뒤 한 번

「일단 지금 다른 아이템에 비해 팩의 퀄리티가 그대로 잖아?」(사용자, 2026-10-06).
동전은 구운 얼굴, 사진은 구운 인화면, 사탕은 3D 인데 팩만 회색 네모 둘이었다.

── 무엇을 굽나 ─────────────────────────────────────────────
  은박(작은 팩) · 청동박(큰 팩) 봉투의 **앞면 한 장**. 위아래 열 봉합 띠(세로 주름),
  부푼 박의 면과 귀퉁이 주름, 가운데를 가로지르는 뜯는 띠, 그 위의 다트판 봉인
  (백색 · 흑색 칸 · 빨강 · 초록 더블 한 줄 · 가운데 불).
  큰 팩은 같은 말에 한 겹을 더한다 — 봉인을 두른 놋쇠 한 줄 · 봉합 띠 안쪽 리본 한 줄.
  (뜯는 실 · 눈금은 게임이 그린다 — 실은 봉인 밑으로 끊기고 큰 팩은 두 줄이다.)
  모양(크림프 톱니 · 찢긴 이 · 뜯는 홈)은 game.gd 의 다각형 그대로이고, 이 그림은
  그 다각형에 면 좌표로 얹힌다 — 그래서 가장자리를 그림에 칠하지 않는다.

── 크기 ────────────────────────────────────────────────────
  game.gd PACK 의 면(반폭 13 · 반높이 18.5)에 GOODS_K 1.16 을 곱한 화면 크기 그대로다
  — 도트 하나가 테이블에서 화면 한 칸이다(사진 · 동전과 같은 밀도).
  작은 팩 30x43 · 큰 팩은 PACK.big(1.10) 배라 33x47.
  누우면 세로가 0.788 로 눌린다 — 한 줄짜리 가는 선에 뜻을 걸지 마라.

── 장 ──────────────────────────────────────────────────────
  한 파일에 **빛 장 FR 장**이 가로로 선다. 0 은 쉬는 장(빛 없음),
  1..FR-1 은 박 위를 미끄러지는 빛의 자리다(얹거나 · 쥐거나 · 여는 동안).
  장마다 둘레 1px 을 이웃 칸으로 덧대 최근접 표본이 옆 장을 안 집게 한다.

── 말투 ────────────────────────────────────────────────────
  coin_paint 의 규칙 넷을 그대로 진다 — 팔레트 하나(PAL) · 빛 하나(왼쪽 위) ·
  테두리선 없음 · 글자 없음.
"""
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import coin_paint as P      # noqa: E402 — 팔레트(PAL · INK) 안에서만 고르는지 잰다

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "pack")
SHOTS = os.path.join(ROOT, "shots")

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except AttributeError:
        pass

#  game.gd 와 짝 — PACK(w · h · seam · band · big) · GOODS_K · PACK_ART.f
PW, PH = 13.0, 18.5
SEAM, BAND = 1.6, 1.7
GOODS_K = 1.16
BIG = 1.10
FR = 9

#  면(밑값) 위의 자리
SEAL = 3.3                       # 봉합 띠 높이(바깥 끝에서)
RIB = SEAM * BAND                # 뜯는 띠 반높이 = 2.72 — game.gd 의 띠 다각형과 같은 자
MED = 5.9                        # 봉인 반지름


def hx(h):
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


#  박 램프 — 깊음 · 낮음 · 가운데 · 밝음 · 반짝. PAL 안에서만 고른다.
FOIL = {
    "small": ["3a3f52", "687085", "a3abbb", "dde3ec", "fbf6ea"],     # steel + cream 3
    #  큰 팩 — 청동박이 방(와인 벨벳)을 되비친다: 그늘은 와인, 가운데 · 밝음은 청동.
    #  통째로 와인이면 펠트에 묻히고 붉은 판 + 금 + 빨강 · 초록 판이 성탄 장식으로 읽혔다.
    #  먹(1a1424)까지 내리면 펠트 위에서 판이 통째로 어두운 봉투가 됐다 — 가장 깊은 단이 와인이다.
    "big": ["4a1426", "6b2a1c", "8a5636", "c48b5a", "fdeaa0"],       # red 0 · orange 0 · wood 2 · 3 · gold 3
}
#  띠 — 위 빛 · 몸 · 아래 그늘
RIBBON = {
    "small": ["4f4670", "221c33", "14111f"],                         # night
    "big": ["8c2233", "221c33", "14111f"],                           # 와인 날 + night
}
INK = "1a1424"
WHITE = ["fbf6ea", "e8dfc8"]     # 다트판 백색 — 빛 쪽 · 그늘 쪽
RED = "d8483d"
GREEN = "479a58"
#  놋쇠 한 줄 — 큰 팩만. C_GOLD(f2c94c)는 돈의 색이라 안 쓴다 — 한 단 가라앉은 놋쇠.
BRASS = "a8762a"


def size_of(kind):
    s = BIG if kind == "big" else 1.0
    return (int(round(2.0 * PW * GOODS_K * s)), int(round(2.0 * PH * GOODS_K * s)))


#  박의 결 — **부푼 봉투**다. 높이 마당 하나(가로로 둥글고 봉합 띠 곁에서 납작해진다)의
#  법선으로 빛을 받는다. 금속은 「밝은 자리가 좁고 그 곁이 바로 어둡다」로 읽힌다 —
#  넓은 가운데 단으로 칠한 첫 판의 청동은 종이 · 나무 상자로 읽혔다. 그래서
#  번짐(diffuse)은 낮게, 반짝(specular)은 좁고 세게, 맞은편 끝에 되비침 한 줄.
LDIR = (-0.45, -0.62, 0.64)      # 빛 — 왼쪽 위에서 비스듬히(등불)


def _norm(v):
    l = math.sqrt(sum(c * c for c in v))
    return tuple(c / l for c in v)


def height(X, Y):
    u = X / PW
    inner = PH - SEAL
    #  봉합 띠로 갈수록 납작해진다 — 끝 4 단위에서 0 으로
    t = max(0.0, min(1.0, (inner - abs(Y)) / 3.8))
    t = t * t * (3.0 - 2.0 * t)
    return math.sqrt(max(0.0, 1.0 - u * u * 0.92)) * (0.35 + 0.65 * t)


def shade(X, Y):
    u"""박 한 점의 밝기(0..1 남짓)."""
    e = 0.35
    hx_ = (height(X + e, Y) - height(X - e, Y)) / (2 * e)
    hy_ = (height(X, Y + e) - height(X, Y - e)) / (2 * e)
    A = 9.0                                     # 부풂의 세기(면 단위)
    n = _norm((-hx_ * A, -hy_ * A, 1.0))
    L = _norm(LDIR)
    dif = max(0.0, n[0] * L[0] + n[1] * L[1] + n[2] * L[2])
    hv = _norm((L[0], L[1], L[2] + 1.0))
    spec = max(0.0, n[0] * hv[0] + n[1] * hv[1] + n[2] * hv[2]) ** 18
    #  되비침 — 맞은편(오른쪽 아래)을 보는 면이 방의 등불을 한 줄 문다
    rim = max(0.0, n[0] * 0.8 + n[1] * 0.35) ** 2
    return 0.16 + 0.40 * dif + 0.95 * spec + 0.45 * rim


#  밝기 → 단. 문턱은 「가운데 단이 넓고 반짝이 좁다」에 맞춘다.
#  넷째(반짝)는 반사의 꼭대기 몇 칸만 — 박이 등불을 「문다」.
STEPS = (0.28, 0.48, 0.66, 1.05)


def step_of(v):
    st = 0
    for th in STEPS:
        if v >= th:
            st += 1
    return st


#  주름 — 봉합 띠 네 귀에서 안으로 비스듬히 들어오는 접힌 금(실물 봉투가 그렇다)과
#  몸통의 짧은 구김 둘. (시작 점, 끝 점) — 금의 왼쪽 위가 빛을 문다.
WRINKLE = [
    ((-12.0, -14.6), (-6.5, -9.2)), ((12.0, -14.6), (7.0, -10.4)),
    ((-12.0, 14.6), (-7.0, 10.0)), ((12.0, 14.6), (6.0, 9.6)),
    ((-4.0, -13.6), (1.5, -11.2)), ((3.0, 12.4), (8.5, 13.8)),
]
LIGHT = (-0.62, -0.78)          # 빛이 오는 쪽 — 왼쪽 위


def wrinkle(X, Y):
    u"""주름 곁이면 +1(빛 쪽) / -1(그늘 쪽), 아니면 0."""
    for (x0, y0), (x1, y1) in WRINKLE:
        dx, dy = x1 - x0, y1 - y0
        L = math.hypot(dx, dy)
        tx, ty = dx / L, dy / L
        qx, qy = X - x0, Y - y0
        t = qx * tx + qy * ty
        if t < 0.0 or t > L:
            continue
        d = -qx * ty + qy * tx
        #  법선(-ty, tx)이 빛을 보면 그 쪽이 날
        face = 1.0 if (-ty * LIGHT[0] + tx * LIGHT[1]) > 0 else -1.0
        if 0.0 <= d * face < 0.95:
            return 1
        if -0.95 < d * face < 0.0:
            return -1
    return 0


def sector(X, Y, n, off=0.0):
    a = math.atan2(Y, X) + math.pi + off
    return int(math.floor(a / (2.0 * math.pi) * n)) % n


def medallion(X, Y, r, kind):
    u"""다트판 봉인. 백색 · 흑색 칸에 빨강 · 초록 고리 한 줄, 가운데 불.
    None 이면 봉인 밖. 고리는 더블 하나만 — 트리플까지 두르면 13px 에서 빨강 · 초록이
    판을 덮어 칩(사행성 기호)의 가장자리 무늬로 읽혔다."""
    R = MED
    if kind == "big" and R < r <= R + 0.95:
        return BRASS                                   # 놋쇠 한 줄
    if r > R:
        return None
    lit = (X * LIGHT[0] + Y * LIGHT[1]) > 0.0
    k = sector(X, Y, 10, math.pi / 10.0)
    if r > R - 1.0:
        return INK                                     # 숫자 고리(검은 테)
    if r > R - 1.95:
        return RED if k % 2 == 0 else GREEN            # 더블
    if r > 1.75:
        return (WHITE[0] if lit else WHITE[1]) if k % 2 == 0 else INK
    if r > 0.95:
        return GREEN
    return RED


def paint(kind, frame):
    W, H = size_of(kind)
    F = FOIL[kind]
    RB = RIBBON[kind]
    img = Image.new("RGB", (W, H))
    px = img.load()
    #  빛 장 — 왼쪽 위에서 오른쪽 아래로 쓸고 가는 띠의 자리(면 좌표의 대각 거리)
    sweep = None
    if frame > 0:
        q = (frame - 1) / float(FR - 2)
        sweep = -20.0 + q * 40.0
    for y in range(H):
        for x in range(W):
            X = ((x + 0.5) / W * 2.0 - 1.0) * PW
            Y = ((y + 0.5) / H * 2.0 - 1.0) * PH
            r = math.hypot(X, Y)
            #  빛 띠 안인가 — 띠는 대각(1, 0.75)을 따라 미끄러진다
            gl = 0.0
            if sweep is not None:
                dd = (X * 0.8 + Y * 0.6) - sweep
                #  날(core) 한 줄 + 곁(halo) — 번지는 띠가 아니라 **선 하나**가 지나가야
                #  금속이 문 빛으로 읽힌다(넓게 깔면 박이 통째로 하얘졌다 깨어난다)
                ad = abs(dd)
                gl = 1.0 if ad < 0.95 else (0.5 if ad < 2.3 else 0.0)
            m = medallion(X, Y, r, kind)
            if m is not None:
                c = m
                if gl >= 1.0 and m == WHITE[1]:
                    c = WHITE[0]
                px[x, y] = hx(c)
                continue
            ay = abs(Y)
            if ay <= RIB:
                #  뜯는 띠 — 위 한 줄이 빛, 아래 한 줄이 그늘
                if Y < -RIB + 0.95:
                    c = RB[0]
                elif Y > RIB - 0.95:
                    c = RB[2]
                else:
                    c = RB[1]
                if gl >= 1.0 and c == RB[1]:
                    c = RB[0]
                px[x, y] = hx(c)
                continue
            if ay >= PH - SEAL:
                #  열 봉합 띠 — 세로 주름. 안쪽 끝 한 줄은 눌린 골
                inner = PH - SEAL
                if ay < inner + 0.9:
                    st = 0 if Y > 0 else 1
                else:
                    st = 2 if x % 2 == 0 else 1
                    if X < -PW * 0.2 and Y < 0 and x % 2 == 0:
                        st = 3
                if gl > 0.0:
                    st = min(st + (2 if gl >= 1.0 else 1), 4)
                px[x, y] = hx(F[st])
                continue
            st = step_of(shade(X, Y))
            inner = PH - SEAL
            #  봉합 띠 곁 — 위는 부푼 박이 빛을 물고, 아래는 그늘로 접힌다
            if -inner <= Y < -inner + 1.1:
                st = min(st + 1, 3)          # 날 한 줄 — 반짝까지 가면 금 막대로 읽혔다
            if inner - 1.1 < Y <= inner:
                st -= 1
            #  뜯는 띠 곁 — 띠 위는 그늘, 띠 아래는 빛(띠가 한 겹 위에 얹혀 있다)
            if -RIB - 1.0 < Y < -RIB:
                st -= 1
            if RIB < Y < RIB + 1.0 and st < 3:
                st += 1
            st += wrinkle(X, Y)
            st = max(0, min(4, st))
            #  큰 팩 — 봉합 띠 안쪽에 **띠 한 줄 더**(리본 색 가는 줄). 겉이 한 겹 더
            #  공들였다를 그림이 말한다. 옆 끝 돋을 테두리도 해 봤는데 세로 줄 둘이
            #  나무 상자의 틀로 읽혀서 걷었다(2026-10-06).
            if kind == "big" and inner - 2.35 < ay <= inner - 1.45:
                c = RB[1] if gl < 1.0 else RB[0]
                px[x, y] = hx(c)
                continue
            if gl > 0.0:
                #  빛은 박만 문다. 날은 두 단(반짝까지), 곁은 한 단
                st = min(st + (2 if gl >= 1.0 else 1), 4)
            px[x, y] = hx(F[st])
    return img


def atlas(kind):
    W, H = size_of(kind)
    out = Image.new("RGBA", ((W + 2) * FR, H + 2), (0, 0, 0, 0))
    for f in range(FR):
        im = paint(kind, f).convert("RGBA")
        #  둘레 덧대기 — 최근접 표본이 옆 장을 안 집게
        pad = Image.new("RGBA", (W + 2, H + 2))
        pad.paste(im, (1, 1))
        pad.paste(im.crop((0, 0, W, 1)), (1, 0))
        pad.paste(im.crop((0, H - 1, W, H)), (1, H + 1))
        pad.paste(pad.crop((1, 0, 2, H + 2)), (0, 0))
        pad.paste(pad.crop((W, 0, W + 1, H + 2)), (W + 1, 0))
        out.paste(pad, (f * (W + 2), 0))
    return out


def main():
    #  ① 팔레트 하나 — coin_paint 의 램프 밖 색이 섞이면 여기서 멈춘다
    used = {INK, WHITE[0], WHITE[1], RED, GREEN, BRASS}
    for k in FOIL:
        used |= set(FOIL[k]) | set(RIBBON[k])
    off = sorted(c for c in used if c.lower() not in P.ALL)
    if off:
        raise SystemExit("팔레트 밖의 색: %s" % ", ".join(off))
    os.makedirs(OUT, exist_ok=True)
    for kind, pid in (("small", "foil_small"), ("big", "foil_big")):
        atlas(kind).save(os.path.join(OUT, pid + ".png"))
        print("구웠다  assets/pack/%s.png  %dx%d · 장 %d" % ((pid,) + size_of(kind) + (FR,)))
    if "--sheet" in sys.argv:
        sheet()


def sheet():
    u"""크게(×8) · 테이블 흉내(가로 ×2 · 세로 ×2×0.788, 와인 펠트 위) 둘을 한 판에."""
    felt = (58, 22, 30)
    ims = [paint("small", 0), paint("big", 0), paint("small", 4), paint("big", 5)]
    big = [im.resize((im.width * 8, im.height * 8), Image.NEAREST) for im in ims]
    tbl = [im.resize((im.width * 2, int(round(im.height * 2 * 0.788))), Image.NEAREST)
           for im in ims]
    Wt = sum(b.width for b in big) + 20 * (len(big) + 1)
    Ht = max(b.height for b in big) + max(t.height for t in tbl) + 60
    sh = Image.new("RGB", (Wt, Ht), felt)
    x = 20
    for b, t in zip(big, tbl):
        sh.paste(b, (x, 20))
        sh.paste(t, (x, 40 + max(bb.height for bb in big)))
        x += b.width + 20
    sh.save(os.path.join(SHOTS, "pack_foil_sheet.png"))
    print("찍었다  shots/pack_foil_sheet.png")


if __name__ == "__main__":
    main()
