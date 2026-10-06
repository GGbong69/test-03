#!/usr/bin/env python3
# -*- coding: utf-8 -*-
u"""팩 그림 굽기 — 봉인 편지봉투 둘과 밀랍 봉인을 assets/pack/ 에 낸다.

    python scripts/tools/make_pack_env.py           셋 다 굽는다
    python scripts/tools/make_pack_env.py --try     크게 본다 → shots/pack_env_try.png
    godot --headless --path . --import              ← 새 png 가 생긴 뒤 한 번

2026-10-06 「일단 지금 다른 아이템에 비해 팩의 퀄리티가 그대로 잖아?」 — 피자 동전 ·
폴라로이드 · 젤리 곰 곁에서 팩만 회색 네모였다. 상인의 카운터에 어울리는 **봉인
편지봉투**로 짓는다.

  env_small.png  작은 팩   담황 편지봉투 — 얇다
  env_big.png    큰 팩     크라프트 소포 봉투 — 두툼하고 노끈으로 묶었다
  env_seal.png   둘이 같이 쓰는 밀랍 봉인 — 다트판(백색 · 흑색 칸 · 빨강 · 초록 띠)이 찍혔다

둘 다 등을 보이고 눕는다. 윗날개(V)가 한가운데까지 내려와 그 끝을 봉인이 누른다.
여는 연출은 그 한가운데를 가로질러 찢는다 — 봉인이 깨지고 종이가 두 쪽 난다.

── 크기 ────────────────────────────────────────────────────
  종이 30 x 43. 테이블 위 팩의 면(PACK.w · PACK.h 에 GOODS_K 를 곱한 30.16 x 42.92)이
  그 크기다 — 동전(36)·사진(32x24)과 같이 **도트 하나가 화면 한 칸**이다.
  봉인 36 x 36 은 **두 배**다(화면 18px). 아래 「밀랍 봉인」 절.
  누우면 세로가 0.788 로 눌린다. 한 줄짜리 가는 선에 뜻을 걸지 마라.
  가장자리(종이 끝의 너덜한 결)와 두께는 그림이 아니라 game.gd 가 깎는다 —
  그래야 그림자 · 히트 · 조각 · 여는 연출이 같은 다각형을 읽는다.

── 한 벌의 말투(동전 · 사진과 같다) ─────────────────────────
  ① 빛이 하나다          왼쪽 위
  ② 테두리선이 없다      종이와 펠트는 밝기 차로 갈린다
  ③ 강조색은 하나다      밀랍의 빨강. 노끈 · 종이는 난색 무채
  ④ 물감은 도트 팔레트다  넓은 면은 shaders/dot.gdshader 의 색(dot_pal.py)에 앉힌다.
                        밖의 색은 기본 필터가 디더로 쪼갠다 — 처음 구운 담황(d0b585)이
                        살 3 · 흰 1 사이로 쪼개져 분홍 낀 흰 종이가 됐다. 사이 색은
                        **일부러** 옆날개 · 그늘에만 써서 종이 결로 지글거리게 둔다
"""
import math
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "pack")
SHOTS = os.path.join(ROOT, "shots")
W, H = 30, 43
CX, CY = W * 0.5, H * 0.5          # 면 한가운데 — 봉인 자리이자 찢기는 줄

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except AttributeError:
        pass

#  ── 종이 램프 (0 어둠 → 6 밝음) ───────────────────────────
#  짝수 단이 도트 팔레트 색이고 홀수 단은 그 사이다(필터가 디더로 쪼갠다).
#    small  살 1 a8634f · 살 2 dc9a73 · 살 3 f5cda3 · 흰 3 fbf6ea
#    big    나무 2 5e3317 · 나무 3 8a5636 · 나무 4 c48b5a · 살 2 dc9a73
PAPER = {
    "small": ["a8634f", "c27e61", "dc9a73", "eab68d", "f5cda3", "f8e2c6", "fbf6ea"],
    "big":   ["5e3317", "744527", "8a5636", "a77049", "c48b5a", "d09366", "dc9a73"],
}
#  밀랍 — 벨벳 2 · 빨강 1 · 빨강 그늘 · C_RED · C_MULT(반짝임). 다 팔레트 색이다.
WAX = ["4a1412", "8c2233", "b03a32", "d8483d", "e8705c"]
#  다트판 — data/colors.csv 의 백색 · 흑색, 띠는 C_RED · C_GREEN.
BOARD = {"w": "e8dfc8", "b": "2b2438", "r": "d8483d", "g": "479a58"}
#  노끈 — 백색 칸 · 흰 1 · 잿빛 2.
TWINE = ["5e5856", "c9bfae", "e8dfc8"]


def _rgb(hx):
    return (int(hx[0:2], 16), int(hx[2:4], 16), int(hx[4:6], 16))


def _hash(x, y, s):
    v = (x * 374761393 + y * 668265263 + s * 2147483647) & 0xFFFFFFFF
    v = ((v ^ (v >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((v ^ (v >> 16)) & 0xFFFF) / 65535.0


#  봉투 등의 네 날개. 좌표는 텍셀 가운데(x+0.5, y+0.5).
#    top    윗날개 — 맨 위에 덮인다. 끝이 한가운데(봉인)에 닿는다
#    bottom 아랫날개 — 아래 두 귀에서 한가운데 밑으로 올라온다
#    side   옆날개 — 나머지
def _region(px, py):
    u = abs(px - CX) / CX           # 0 가운데 → 1 옆 끝
    if py <= CY - u * (CY - 0.6):
        return "top"
    if py >= (CY + 5.0) + u * (H - 0.6 - CY - 5.0):
        return "bottom"
    return "side"


def paint(kind):
    ramp = PAPER[kind]
    big = kind == "big"
    top = len(ramp) - 1
    idx = [[0] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            px, py = x + 0.5, y + 0.5
            r = _region(px, py)
            #  윗날개만 팔레트 색 그대로 평평하고 밝다 — ✉ 의 V 가 이 물건의 이름이다.
            #  나머지는 한 끗 아래 사이 색이라 필터가 성긴 점으로 결을 낸다.
            #  (처음 판은 아랫날개도 밝혀 X 가 서서 봉투가 아니라 상자 뚜껑으로 읽혔다.)
            v = {"top": 4, "side": 3, "bottom": 3}[r]
            #  날개는 완전히 평평하지 않다 — 빛(왼쪽 위)을 등진 오른쪽 옆날개가 한 단
            #  더 어둡다. 기본 필터(CRT 번짐)가 밝은 종이를 한 덩어리로 띄우므로 날개끼리
            #  이만큼은 갈려야 판 위에서 접힌 부피가 남는다. 몸 전체에 비스듬한 그늘을
            #  깔아 봤더니 그 경계가 날개 하나가 더 있는 금으로 읽혔다.
            if r == "side" and px > CX:
                v = 2
            if r == "top" and (px / W) * 0.55 + (py / H) * 0.45 > 0.62:
                v = 3
            #  두툼한 봉투는 속이 부풀어 가장자리가 말린다 — 윗 · 왼 끝은 빛을
            #  받고 아래 · 오른 끝은 그늘이 진다.
            if big:
                if x <= 0 or y <= 0:
                    v += 1
                if x >= W - 1 or y >= H - 1:
                    v -= 2
                elif x >= W - 2 or y >= H - 2:
                    v -= 1
            #  종이 결 — 듬성듬성한 섬유 한 톨. 반 단만 흔든다.
            h = _hash(x, y, 7 if big else 3)
            if h < 0.035:
                v -= 1
            elif h > 0.975:
                v += 1
            idx[y][x] = v
    #  날개 모서리. 윗날개의 오른쪽 변은 빛 반대편이라 그 밑 종이에 그늘이 진다.
    #  왼쪽 변은 빛을 받는 턱이라 한 단 밝다. 아랫날개도 같은 규약이다.
    for y in range(H):
        for x in range(W):
            px, py = x + 0.5, y + 0.5
            r = _region(px, py)
            up = _region(px, py - 1.0)
            if r != "top" and (up == "top" or _region(px, py - 2.0) == "top"):
                idx[y][x] = 1 if (px > CX and up == "top") else 2
            if r == "top" and _region(px, py + 1.0) != "top" and px < CX:
                idx[y][x] = 5
            if r == "bottom" and up != "bottom":
                idx[y][x] = 4 if px < CX else 2
    #  노끈(큰 팩) — 가로 · 세로로 한 바퀴씩 감아 봉인 밑에서 묶었다.
    #  꼰 실이라 두 톤이 번갈아 서고, 오른쪽 · 아래 칸에 그늘 한 줄이 진다.
    #  가로 줄은 한가운데(찢기는 줄)에서 세 칸 위다 — 거기 두면 찢긴 이가 노끈을
    #  먹어 찢긴 자리가 흰 줄과 뒤엉켰다.
    twine = {}
    if big:
        ty, tx = int(CY) - 3, int(CX) - 1
        for x in range(W):
            twine[(x, ty)] = 2 if x % 2 == 0 else 1
            idx[ty + 1][x] = 2
        for y in range(H):
            twine[(tx, y)] = 2 if y % 2 == 0 else 1
            if y != ty:
                idx[y][tx + 1] = 2
    im = Image.new("RGBA", (W, H))
    pxl = im.load()
    for y in range(H):
        for x in range(W):
            pxl[x, y] = _rgb(ramp[max(0, min(top, idx[y][x]))]) + (255,)
    for (x, y), t in twine.items():
        pxl[x, y] = _rgb(TWINE[t]) + (255,)
    return im


#  ── 밀랍 봉인 ──────────────────────────────────────────
#  **봉인만 두 배로 굽는다**(36x36 = 화면 18px). 종이 도트(30x43)로 찍으면 다트판이
#  아홉 칸 안에 갇혀 「빨간 점에 무언가」가 됐다(2026-10-06 해 봤다). 동전의 테 ·
#  고리가 화면 두 배로 그어지는 것과 같은 자리다 — 바탕은 도트, 표식은 곱게.
#  필터의 색은 기기 픽셀마다 고르므로 두 배 결이 산다(dot.gdshader 머리말).
#  덩어리 · 찍힌 홈 · 다트판 세 겹이고, 종이에 지는 그늘도 이 알파가 같이 진다.
#  다트판은 덩어리의 반을 조금 넘게만 차지한다 — 처음 판(0.68)은 밀랍이 가는 테로
#  남아 「봉인」이 아니라 「다트판 딱지」로 읽혔다.
SEAL = 36
SC = SEAL * 0.5
SEAL_R = 14.6                  # 덩어리 반지름(텍셀) — 화면 7.3px
SEAL_IN = 0.60                 # 찍힌 홈의 바깥 / 덩어리
LX, LY = -0.70, -0.71          # 빛(왼쪽 위)


def _seal_rad(a):
    #  밀랍은 녹아 퍼진 자리라 둥글되 고르지 않다. 왼쪽 아래로 한 번 더 흘렀다.
    return SEAL_R * (1.0 + 0.028 * math.sin(7.0 * a + 0.7) + 0.024 * math.sin(4.0 * a + 2.1)
            + 0.07 * max(0.0, math.cos(a - 2.25)) ** 8)


def seal():
    im = Image.new("RGBA", (SEAL, SEAL), (0, 0, 0, 0))
    px = im.load()
    rb = SEAL_IN * SEAL_R
    for y in range(SEAL):
        for x in range(SEAL):
            dx, dy = x + 0.5 - SC, y + 0.5 - SC
            d = math.hypot(dx, dy)
            R = _seal_rad(math.atan2(dy, dx))
            if d >= R:
                #  종이에 지는 그늘 — 오른쪽 아래로 두 텍셀.
                sx, sy = dx - 1.6, dy - 2.0
                if math.hypot(sx, sy) < _seal_rad(math.atan2(sy, sx)):
                    px[x, y] = (40, 10, 14, 110)
                continue
            e = d / R
            nd = (dx * LX + dy * LY) / max(d, 0.001)     # 빛 쪽이면 +
            if d > rb + 1.6:
                #  퍼진 밀랍 — 빛 쪽 어깨가 밝고 맞은편이 어둡다. 맨 끝 한 겹은
                #  얇아져 한 단 더 짙다(종이에 스며든 자리).
                if e > 0.93 and nd < 0.1:
                    c = WAX[0]
                elif nd > 0.55 and e > 0.72:
                    c = WAX[3]
                elif nd > -0.25:
                    c = WAX[2]
                else:
                    c = WAX[1]
            elif d > rb:
                #  찍힌 홈의 벽 — 빛 쪽 벽은 그늘, 맞은편 벽이 빛을 받는다.
                c = WAX[0] if nd > -0.2 else WAX[3]
            else:
                c = _board(dx, dy, rb)
            px[x, y] = _rgb(c) + (255,)
    #  밀랍의 반짝임 — 빛 쪽 어깨에 짧은 호 하나.
    for a in (-2.62, -2.48, -2.34, -2.20):
        r = SEAL_R * 0.84
        x, y = int(SC + math.cos(a) * r), int(SC + math.sin(a) * r)
        px[x, y] = _rgb(WAX[4]) + (255,)
    return im


#  찍힌 다트판. 바깥부터 흑색 테 · 겹띠(칸마다 빨강 · 초록) · 칸 열여섯(백색 · 흑색
#  번갈아) · 불(초록 고리 · 빨강 점). 칸 하나가 12시에 서는 것이 실물 판의 차례다.
#  반지름 8.8 텍셀 안이라 텍셀 가운데 한 점으로 칸을 가르면 계단에 먹혀 네 방향
#  칸만 남아 십자 · 바퀴로 읽혔다 — 한 텍셀을 4x4 로 쪼개 많은 쪽 색을 고른다.
#  칸 수도 그래서 열여섯이다(열은 바퀴살, 스물은 낟알).
BOARD_N = 16


def _board_one(dx, dy, rr):
    d = math.hypot(dx, dy)
    a = (math.atan2(dy, dx) + math.pi * 0.5 + math.pi / BOARD_N) % (2.0 * math.pi)
    k = int(a / (2.0 * math.pi / BOARD_N))
    if d < 1.3:
        return "r"
    if d < 2.3:
        return "g"
    if d > rr - 0.6:
        return "b"
    if d > rr - 1.9:
        return "r" if k % 2 == 0 else "g"
    return "w" if k % 2 == 0 else "b"


def _board(dx, dy, rr):
    n = {}
    for sy in range(4):
        for sx in range(4):
            c = _board_one(dx + (sx + 0.5) / 4.0 - 0.5, dy + (sy + 0.5) / 4.0 - 0.5, rr)
            n[c] = n.get(c, 0) + 1
    return BOARD[max(n, key=lambda c: (n[c], c == "w"))]


def bake():
    os.makedirs(OUT, exist_ok=True)
    out = {"seal": seal()}
    out["seal"].save(os.path.join(OUT, "env_seal.png"))
    print(os.path.join(OUT, "env_seal.png"))
    for pid, kind in (("env_small", "small"), ("env_big", "big")):
        im = paint(kind)
        im.save(os.path.join(OUT, pid + ".png"))
        out[pid] = im
        print(os.path.join(OUT, pid + ".png"))
    return out


#  봉인을 얹은 봉투 한 장(두 배). 게임의 _pack_piece 와 같은 자리에 얹는다 —
#  봉인 반폭 = 면 반폭 × PACK.seal(0.60).
def _compose(paper, sl):
    im = paper.resize((W * 2, H * 2), Image.NEAREST)
    s = int(round(W * 0.60 * 2))
    im.alpha_composite(sl.resize((s, s), Image.NEAREST), (W - s // 2, H - s // 2))
    return im


def try_sheet():
    ims = bake()
    k = 5
    felt = (0x4a, 0x14, 0x12)
    sheet = Image.new("RGB", (W * 2 * k * 2 + 60 + 300, H * 2 * k + 40), felt)
    x = 20
    for pid in ("env_small", "env_big"):
        c = _compose(ims[pid], ims["seal"])
        big = c.resize((W * 2 * k, H * 2 * k), Image.NEAREST)
        sheet.paste(big, (x, 20), big)
        x += W * 2 * k + 20
        ims[pid + "_c"] = c
    #  게임 창(1280x720)에서의 실제 크기 — 도트 하나가 2px, 세로는 0.788 로 눌린다.
    y = 30
    for pid in ("env_small", "env_big"):
        c = ims[pid + "_c"]
        im = c.resize((W * 2, int(round(H * 2 * 0.788))), Image.NEAREST)
        sheet.paste(im, (x, y), im)
        im3 = c.resize((int(W * 2 * 2.59), int(round(H * 2 * 2.59 * 0.788))), Image.NEAREST)
        sheet.paste(im3, (x + 80, y), im3)
        y += 220
    os.makedirs(SHOTS, exist_ok=True)
    out = os.path.join(SHOTS, "pack_env_try.png")
    sheet.save(out)
    print(out)


if __name__ == "__main__":
    if sys.argv[1:] and sys.argv[1] == "--try":
        try_sheet()
    else:
        bake()
