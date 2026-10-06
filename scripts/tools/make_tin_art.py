#!/usr/bin/env python3
# -*- coding: utf-8 -*-
u"""팩 깡통 뚜껑 굽기 — assets/tin/tin_s.png(작은 팩) · tin_b.png(큰 팩).

    python scripts/tools/make_tin_art.py            두 장을 굽는다
    python scripts/tools/make_tin_art.py --peek     굽고 8배 미리보기(scratch)도 낸다
    godot --headless --path . --import      ← 구운 뒤 한 번. .import 를 세운다

2026-10-06 「일단 지금 다른 아이템에 비해 팩의 퀄리티가 그대로 잖아?」 — 회색 봉투를
옛 사탕 깡통으로 바꾼다. 뚜껑 윗면 한 장만 여기서 굽고, 옆면 · 테 빛 · 여닫이는
game.gd(_tin_*)가 그린다 — 빛이 화면 쪽에서 와야 깡통이 어느 각으로 누워도 맞다.

원본은 남에게서 빌린 그림이 아니라 **이 파일의 규칙**이다(동전 얼굴 faces.txt ·
사진 photo_src 와 같은 규약 — docs/크레딧.md). 도트 하나를 픽셀 가운데로 재서
팔레트 번호로 찍고, 섞은 색(안티에일리어싱)은 한 점도 안 쓴다.

── 크기 ─────────────────────────────────────────────────
뚜껑 그림이 테이블(GOODS_K 1.16)에서 **도트 하나 = 화면 한 칸**이 되게 굽는다.
  큰 팩   면 반폭 13 · 반깊이 18.5 → 30 x 43
  작은 팩 그 0.9배                → 27 x 39
깊이(세로)는 눕히며 TBL.flat 로 눌리므로 그림은 위에서 본 그대로다.

── 그림 ─────────────────────────────────────────────────
  · 에나멜 바탕 — 작은 팩 병초록 · 큰 팩 쪽빛. 값 셋(그늘 · 바탕 · 볼록)
  · 가장자리 — 말린 테(그늘 한 줄)와 그 안 볼록 한 줄. 빛은 둘레 전부 같다
    (방향 빛은 게임이 화면에서 얹는다 — 돌려 놓아도 안 틀린다)
  · 놋쇠 실선 — 안으로 세 칸. 놋쇠는 **선으로만** 쓴다
  · 다트판 메달 — 백색 · 흑색 칸 열둘, 바깥 띠(빨강 · 초록이 칸마다 갈마든다), 불, 놋쇠 테
  · 라벨 띠 — 백색 바탕. 눈금(몇 개 중 몇 개)은 게임이 이 띠 위에 찍는다
글자는 한 자도 안 쓴다.
"""
import os
import sys
import math

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "tin")

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except AttributeError:
        pass


def hx(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), 255)


#  판의 넷 — data/colors.csv 의 백색 · 흑색, 띠의 빨강 · 초록(game.gd C_RED · C_GREEN).
WHITE = hx("e8dfc8")
BLACK = hx("2b2438")
RED = hx("d8483d")
GREEN = hx("479a58")
#  놋쇠 — 저울 · 등록기와 같은 식구. 금(C_GOLD f2c94c)보다 한참 낮고 누렇다 —
#  값표의 금과 붙으면 깡통이 「돈」으로 읽힌다(옛 봉인띠가 그랬다).
#  BRASS · BRASS_D 는 game.gd 의 C_BRASS · C_BRASS_D(경첩)와 같은 수다.
BRASS_D = hx("7a5a2e")
BRASS = hx("b48a48")
BRASS_L = hx("dcbc7c")
#  라벨 띠의 그늘 — 백색을 한 단 내린다.
WHITE_D = hx("c3b796")

#  깡통 둘. 값 셋(e0 그늘 · e1 바탕 · e2 볼록)과 치수.
#  ⚠ game.gd 의 TIN 표와 **같은 수**여야 한다 — e0~e2(옆벽 · 테 빛) · band(눈금 행) ·
#  medal(젖힌 뚜껑 안쪽 자국) · size(th · tw). qa_art ⑤ 가 크기를 잰다.
TINS = {
    "s": {
        "size": (27, 39), "r": 5.8,
        "e0": hx("1c3a2d"), "e1": hx("2c5a45"), "e2": hx("3e765b"),
        "medal": (13.5, 15.0, 8.6), "band": (25, 30), "sectors": 12,
    },
    "b": {
        "size": (30, 43), "r": 4.2,
        "e0": hx("1d3150"), "e1": hx("2f4f78"), "e2": hx("426a98"),
        "medal": (15.0, 16.5, 9.6), "band": (29, 35), "sectors": 12,
    },
}


def rr_sd(px, py, w, h, r):
    u"""픽셀 가운데(px, py)에서 둥근 네모(0..w, 0..h, 귀 반지름 r) 테까지의 부호 거리.
    안이 음수다."""
    cx, cy = w * 0.5, h * 0.5
    qx = abs(px - cx) - (cx - r)
    qy = abs(py - cy) - (cy - r)
    ox, oy = max(qx, 0.0), max(qy, 0.0)
    return math.hypot(ox, oy) + min(max(qx, qy), 0.0) - r


def paint(key):
    t = TINS[key]
    w, h = t["size"]
    r = t["r"]
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = im.load()
    e0, e1, e2 = t["e0"], t["e1"], t["e2"]
    mx, my, mr = t["medal"]
    b0, b1 = t["band"]
    n = t["sectors"]
    for y in range(h):
        for x in range(w):
            cx, cy = x + 0.5, y + 0.5
            sd = rr_sd(cx, cy, w, h, r)
            if sd > 0.0:
                #  귀퉁이 밖도 바탕으로 채운다 — 게임은 둥근 다각형으로 자르므로
                #  여기가 비면 가장자리 표본이 투명을 집어 테가 이빨처럼 빠진다.
                px[x, y] = e0
                continue
            col = e1
            #  말린 테 — 바깥 한 줄 그늘, 그 안 한 줄 볼록.
            if sd > -1.0:
                col = e0
            elif sd > -2.0:
                col = e2
            #  놋쇠 실선 — 안으로 셋째 줄.
            elif -4.0 < sd <= -3.0:
                col = BRASS
            #  라벨 띠 — 백색 리본. 양 끝을 V 로 파 들어간다(제비꼬리) — 네모
            #  띠는 빈 쪽지로 읽혔다. 가운데 줄이 가장 깊이 파인다.
            bx0, bx1 = 5, w - 5
            if b0 <= y <= b1 and sd <= -4.0:
                mid = (b0 + b1) * 0.5
                cut = max(0, 2 - int(round(abs(y - mid) * 1.1)))
                lo, hi = bx0 + cut, bx1 - cut
                if lo <= x < hi:
                    col = WHITE_D if y == b1 else WHITE
            #  다트판 메달.
            d = math.hypot(cx - mx, cy - my)
            if d < mr:
                a = math.atan2(cy - my, cx - mx)
                #  한 칸이 12시 한가운데에 선다(실물 판의 20 자리).
                k = int(math.floor(((a + math.pi * 0.5) / (2 * math.pi) * n) + 0.5)) % n
                dark = (k % 2 == 1)
                #  띠는 **바깥 하나만** 남긴다. 트리플 띠와 안쪽 칸까지 넣었더니 지름
                #  19 도트에서 빨강 · 초록 부스러기가 한가운데에 흩어져 판이 아니라
                #  잡무늬로 읽혔다 — 칸(백색 · 흑색)이 불까지 곧게 뻗어야 판이다.
                f = d / mr
                if f > 0.90:
                    col = BRASS_L if (cx - mx) + (cy - my) < -2.0 else BRASS
                elif f > 0.78:
                    col = BLACK
                elif f > 0.66:
                    col = GREEN if dark else RED
                elif f > 0.22:
                    col = BLACK if dark else WHITE
                elif f > 0.12:
                    col = GREEN
                else:
                    col = RED
            #  메달 그림자 — 오른쪽 아래 반 바퀴에 그늘 한 줄. 눌러 찍은 둔덕이다.
            elif d < mr + 1.0 and (cx - mx) + (cy - my) > 1.5:
                col = e0
            px[x, y] = col
    return im


def main():
    os.makedirs(OUT, exist_ok=True)
    peek = "--peek" in sys.argv
    for key in TINS:
        im = paint(key)
        p = os.path.join(OUT, "tin_%s.png" % key)
        im.save(p)
        print("구웠다", p, im.size)
        if peek:
            sp = os.environ.get("TIN_PEEK", os.path.join(ROOT, "shots"))
            im.resize((im.width * 8, im.height * 8), Image.NEAREST).save(
                os.path.join(sp, "tin_peek_%s.png" % key))


if __name__ == "__main__":
    main()
