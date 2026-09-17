#!/usr/bin/env python3
# -*- coding: utf-8 -*-
u"""과녁 판 비교판 — shot_board_target.gd 가 찍은 장을 판만 오려 옛 판 · 첫 벌 · 새 판을 나란히 붙인다.

    godot --path . --quit-after 9000 --script scripts/tools/shot_board_target.gd -- tgold   ← 옷 입기 전(토너먼트 판)
    godot --path . --quit-after 9000 --script scripts/tools/shot_board_target.gd -- tgprev  ← 고치기 전 벌(있으면)
    godot --path . --quit-after 9000 --script scripts/tools/shot_board_target.gd            ← 지금(tg)
    python scripts/tools/shot_board_target_sheet.py

    shots/tg_sheet.png   한 줄에 한 장면 — 왼쪽부터 옛 판 · 첫 벌 · 새 판(있는 것만, 1:1)
    shots/tg_zoom.png    새 판 왼쪽 위 사분면을 세 배로(짚 결 · 핀 · 링 줄을 도트 단위로 본다) —
                         칠한 판 · 죽은 먹 칸 판을 나란히

옛 장이 하나도 없으면 새 판만 네 칸씩 붙인다.
"""
import os
import sys
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SHOTS = os.path.join(ROOT, "shots")
# 1280x720 장에서 판(그림자 · 짚 끝까지)이 드는 자리 — BC(320,196) × 2 에서 반지름 ~130 × 2
BOX = (380, 130, 900, 660)
ROWS = ["plain", "paint", "aim_trp", "aim_dbl", "aim_bull", "deadcol", "deadidx", "deadidx_aim", "band"]
COLS = ["tgold", "tgprev", "tg"]
BG = (20, 17, 31)
GAP = 8


def crop(name):
    p = os.path.join(SHOTS, name + ".png")
    if not os.path.exists(p):
        return None
    return Image.open(p).convert("RGB").crop(BOX)


def main():
    w, h = BOX[2] - BOX[0], BOX[3] - BOX[1]
    rows = [[crop("%s_%s" % (c, r)) for c in COLS] for r in ROWS]
    rows = [row for row in rows if row[-1] is not None]
    if not rows:
        print("tg_*.png 가 없다 — shot_board_target.gd 를 먼저 돌린다")
        return 1
    cols = [k for k in range(len(COLS)) if any(row[k] is not None for row in rows)]
    if len(cols) > 1:
        sheet = Image.new("RGB", (len(cols) * (w + GAP), len(rows) * (h + GAP)), BG)
        for y, row in enumerate(rows):
            for x, k in enumerate(cols):
                if row[k] is not None:
                    sheet.paste(row[k], (x * (w + GAP), y * (h + GAP)))
    else:
        ncol = 4
        n = (len(rows) + ncol - 1) // ncol
        sheet = Image.new("RGB", (ncol * (w + GAP), n * (h + GAP)), BG)
        for k, row in enumerate(rows):
            sheet.paste(row[-1], ((k % ncol) * (w + GAP), (k // ncol) * (h + GAP)))
    out = os.path.join(SHOTS, "tg_sheet.png")
    sheet.save(out)
    print("  비교판", out)
    zs = [z for z in (crop("tg_paint"), crop("tg_deadcol")) if z is not None]
    if zs:
        qs = [z.crop((0, 0, w // 2, h // 2)) for z in zs]
        qs = [q.resize((q.width * 3, q.height * 3), Image.NEAREST) for q in qs]
        zoom = Image.new("RGB", (sum(q.width for q in qs) + GAP * (len(qs) - 1), qs[0].height), BG)
        for k, q in enumerate(qs):
            zoom.paste(q, (k * (q.width + GAP), 0))
        out2 = os.path.join(SHOTS, "tg_zoom.png")
        zoom.save(out2)
        print("  확대", out2)
    return 0


if __name__ == "__main__":
    sys.exit(main())
