#!/usr/bin/env python3
# -*- coding: utf-8 -*-
u"""움직이는 동전 얼굴 층 굽기 — assets/coin/<id>.png 를 바탕 · 움직이는 것으로 가른다.

    python scripts/tools/make_coin_anim.py
    godot --headless --path . --import      ← 구운 뒤 한 번. .import 를 세운다

make_coin_art.py 가 얼굴을 다시 구우면 이것도 다시 돌린다(그 PNG 에서 뜬다).
게임(game.gd COINANIM)은 상태가 0 이면 원래 얼굴을 그대로 그리고, 움직일 때만
바탕 위에 움직이는 층을 얹는다 — 그래서 **바탕 + 쉬는 자세 = 원래 얼굴**이 화소
하나까지 같아야 한다. 굽는 끝에 그것을 잰다.

  c02 닌자     c02_bg · c02_fg     수리검(회색 넷)을 떼어 가운데에서 돌린다
  u18 머니건   u18_bg · u18_fg     총(빨강 넷)을 떼어 반동으로 튕긴다
  c36 연속사진 c36_bg · c36_f0~3   말 · 기수를 떼어 네 자세로 달린다(f0 = 원래 자세)

뗀 자리는 둘레 바탕 빛으로 메운다(가장 가까운 바탕 화소 — 여러 곳에서 한꺼번에 번진다).
"""
import math
import os
import sys
from collections import deque

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_coin_art as M  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DIR = os.path.join(ROOT, "assets", "coin")
SZ = 36

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except AttributeError:
        pass

#  움직이는 것의 빛 — 그림에서 읽었다(faces.txt 의 그 장 팔레트).
FG = {
    "c02": {(221, 227, 236), (58, 63, 82), (163, 171, 187), (104, 112, 133)},
    "u18": {(216, 72, 61), (242, 125, 99), (140, 34, 51), (74, 20, 38)},
    #  말 · 기수 · 꼬리. 연한 갈색(85,50,34)은 필름 테와 같은 빛이라 필름 안(7~28 줄)만 말이다.
    "c36": {(42, 24, 18), (85, 50, 34), (138, 86, 54), (196, 139, 90), (251, 246, 234)},
}
#  반지름으로 메우는 장 — (테 안쪽 반지름, 테 빛, 안 빛). 둘레에서 번지면 테 빛이 줄무늬로 샌다.
FILL = {
    "c02": (13.5, (140, 34, 51), (216, 72, 61)),
    "u18": (14.2, (201, 191, 174), (232, 223, 200)),
}
#  수리검이 바탕에 드리운 그림자 — 테 안쪽의 짙은 빨강. 바탕에서 걷고 게임이 돌아가는 수리검
#  실루엣(c02_sh)을 비껴 찍는다(그림자는 수리검을 따라 돈다).
SHADOW = {"c02": (140, 34, 51)}
HORSE_ROWS = range(7, 29)
LEG_TOP = 23          # 이 줄부터 밑은 다리다(몸통 밑 줄이 22)
DARK = (42, 24, 18, 255)
MID = (85, 50, 34, 255)

#  질주 자세 — 다리마다 (엉덩이 · 무릎 · 발굽). 엉덩이는 23 줄 다리 윗머리 그대로다.
#  뒷다리 둘(HA 뒤 · HB 앞) · 앞다리 둘(FA 뒤 · FB 앞). bob 은 몸이 뜨는 화소(위로 −).
#  f0 은 원래 그림의 다리라 여기 없다.
GAIT = [
    #  f1 — 앞다리 하나가 디뎌 뒤로 밀고 하나는 접혀 든다 · 뒷다리 둘은 배 밑으로 앞으로 온다
    {"bob": 0, "legs": [((10, 23), (11, 25), (13, 26)), ((14, 23), (16, 24), (17, 26)),
                        ((21, 23), (20, 25), (18, 27)), ((24, 23), (26, 24), (25, 26))]},
    #  f2 — 네 다리를 배 밑에 모은 채 뜬다(머이브리지의 그 장) · 몸이 한 화소 뜬다
    {"bob": -1, "legs": [((10, 22), (12, 24), (15, 25)), ((14, 22), (16, 24), (18, 24)),
                         ((21, 22), (21, 24), (18, 25)), ((24, 22), (24, 24), (21, 25))]},
    #  f3 — 뒷다리가 앞으로 딛고 앞다리 둘은 앞으로 뻗는다 → f0(앞발이 딛고 뒷발이 뒤로 민다)
    {"bob": 0, "legs": [((10, 23), (12, 25), (14, 27)), ((14, 23), (16, 25), (18, 27)),
                        ((21, 23), (24, 24), (27, 25)), ((24, 23), (27, 23), (30, 24))]},
]


def load(cid):
    return Image.open(os.path.join(DIR, cid + ".png")).convert("RGBA")


def is_fg(cid, im, x, y):
    p = im.getpixel((x, y))
    if p[3] == 0 or p[:3] not in FG[cid]:
        return False
    if cid == "c36" and y not in HORSE_ROWS:
        return False
    return True


def split(cid, im):
    """바탕(뗀 자리를 메운 것) · 움직이는 것(나머지 투명)."""
    fg = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
    bg = im.copy()
    hole = set()
    for y in range(SZ):
        for x in range(SZ):
            if is_fg(cid, im, x, y):
                fg.putpixel((x, y), im.getpixel((x, y)))
                hole.add((x, y))
            elif cid in SHADOW and im.getpixel((x, y))[:3] == SHADOW[cid]                     and math.hypot(x + 0.5 - SZ / 2, y + 0.5 - SZ / 2) < FILL[cid][0]:
                hole.add((x, y))
    if cid in FILL:
        rin, ring, inner = FILL[cid]
        for x, y in hole:
            r = math.hypot(x + 0.5 - SZ / 2, y + 0.5 - SZ / 2)
            bg.putpixel((x, y), (ring if r >= rin else inner) + (im.getpixel((x, y))[3],))
        return bg, fg
    #  메우기 — 바탕 화소에서 한꺼번에 번진다(네 이웃). 먼저 닿은 빛을 받는다.
    q = deque()
    seen = set()
    for y in range(SZ):
        for x in range(SZ):
            if (x, y) not in hole and im.getpixel((x, y))[3] == 255:
                q.append((x, y))
                seen.add((x, y))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            n = (x + dx, y + dy)
            if n in hole and n not in seen:
                seen.add(n)
                #  원형 알파의 가장자리(총 손잡이가 테에 닿는다)는 제 투명도를 지킨다
                bg.putpixel(n, bg.getpixel((x, y))[:3] + (im.getpixel(n)[3],))
                q.append(n)
    assert hole <= seen, cid + " 메우지 못한 자리가 있다"
    return bg, fg


def line(px, a, b, col, w=1):
    """화소 선(브레젠햄). w=2 면 오른쪽 한 칸을 같이 찍는다."""
    (x0, y0), (x1, y1) = a, b
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        for k in range(w):
            if 0 <= x0 + k < SZ and 0 <= y0 < SZ:
                px[(x0 + k, y0)] = col
        if (x0, y0) == (x1, y1):
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def horse_frames(fg):
    body = {}
    for y in range(SZ):
        for x in range(SZ):
            p = fg.getpixel((x, y))
            if p[3] and y < LEG_TOP:
                body[(x, y)] = p
    frames = [fg]
    for g in GAIT:
        px = {(x, y + g["bob"]): c for (x, y), c in body.items()}
        for hip, knee, hoof in g["legs"]:
            #  넓적다리는 두 칸 · 정강이는 한 칸, 발굽 위 한 칸은 밝은 갈색(원래 다리의 결)
            line(px, (hip[0], hip[1] + g["bob"]), knee, DARK, 2)
            line(px, knee, hoof, DARK, 1)
            px[hoof] = DARK
            px[(knee[0], knee[1])] = MID
        im = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
        for (x, y), c in px.items():
            if 0 <= x < SZ and 0 <= y < SZ:
                im.putpixel((x, y), c)
        frames.append(im)
    return frames


def save(im, name):
    dst = os.path.join(DIR, name + ".png")
    im.save(dst)
    M.write_import(dst)          # 얼굴과 같은 가져오기 설정(make_coin_art.IMPORT)
    print("  ", name)


def main():
    for cid in ("c02", "u18", "c36"):
        im = load(cid)
        bg, fg = split(cid, im)
        #  불투명한 화소는 하나도 안 다르다. 가장자리(반투명) 몇 화소는 두 층이 같은 투명도라
        #  겹치면 조금 더 짙다 — 쉴 때는 게임이 원래 얼굴을 그리므로 움직이는 동안만이다.
        back = Image.alpha_composite(bg, fg)
        edge = 0
        for y in range(SZ):
            for x in range(SZ):
                a, b = im.getpixel((x, y)), back.getpixel((x, y))
                if cid in SHADOW and a[:3] == SHADOW[cid] and b[:3] != a[:3]:
                    continue          # 그림자 자리 — 게임이 실루엣으로 다시 찍는다
                if a[3] == 255:
                    assert a == b, "%s (%d,%d) 바탕 + 쉬는 자세가 원래 얼굴과 다르다" % (cid, x, y)
                elif fg.getpixel((x, y))[3]:
                    edge += 1
        print(cid, "가장자리", edge)
        save(bg, cid + "_bg")
        if cid == "c36":
            for k, f in enumerate(horse_frames(fg)):
                save(f, "c36_f%d" % k)
        else:
            save(fg, cid + "_fg")
        if cid in SHADOW:
            sh = Image.new("RGBA", (SZ, SZ), (0, 0, 0, 0))
            for y in range(SZ):
                for x in range(SZ):
                    if fg.getpixel((x, y))[3]:
                        sh.putpixel((x, y), (255, 255, 255, 255))
            save(sh, cid + "_sh")
    print("ok — 바탕 + 쉬는 자세 = 원래 얼굴(불투명 화소 · 셋)")


if __name__ == "__main__":
    main()
