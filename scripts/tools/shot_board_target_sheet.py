#!/usr/bin/env python3
# -*- coding: utf-8 -*-
u"""과녁 판 비교판 — shot_board_target.gd 가 찍은 장을 판만 오려 옛 판 · 새 판을 나란히 붙인다.

    godot --path . --quit-after 9000 --script scripts/tools/shot_board_target.gd -- tgold   ← 고치기 전
    godot --path . --quit-after 9000 --script scripts/tools/shot_board_target.gd            ← 고친 뒤(tg)
    python scripts/tools/shot_board_target_sheet.py

    shots/tg_sheet.png   왼쪽 옛 판 · 오른쪽 새 판, 한 줄에 한 장면(1:1)
    shots/tg_zoom.png    새 판 왼쪽 위 사분면을 네 배로(짚 결 · 핀 · 구분선을 도트 단위로 본다)

옛 장(tgold_*)이 없으면 새 판만 두 줄로 붙인다.
"""
import os
import sys
from PIL import Image

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
SHOTS = os.path.join(ROOT, "shots")
# 1280x720 장에서 판(그림자 · 짚 끝까지)이 드는 자리 — BC(320,196) × 2 에서 반지름 ~130 × 2
BOX = (380, 130, 900, 660)
ROWS = ["plain", "paint", "aim_trp", "aim_dbl", "aim_bull", "deadcol", "deadidx", "band"]
BG = (20, 17, 31)
GAP = 8


def crop(name):
    p = os.path.join(SHOTS, name + ".png")
    if not os.path.exists(p):
        return None
    return Image.open(p).convert("RGB").crop(BOX)


def main():
    w, h = BOX[2] - BOX[0], BOX[3] - BOX[1]
    pairs = [(crop("tgold_" + r), crop("tg_" + r)) for r in ROWS]
    pairs = [p for p in pairs if p[1] is not None]
    if not pairs:
        print("tg_*.png 가 없다 — shot_board_target.gd 를 먼저 돌린다")
        return 1
    has_old = any(p[0] is not None for p in pairs)
    ncol = 2 if has_old else 4
    if has_old:
        sheet = Image.new("RGB", (w * 2 + GAP, len(pairs) * (h + GAP)), BG)
        for k, (old, new) in enumerate(pairs):
            y = k * (h + GAP)
            if old is not None:
                sheet.paste(old, (0, y))
            sheet.paste(new, (w + GAP, y))
    else:
        rows = (len(pairs) + ncol - 1) // ncol
        sheet = Image.new("RGB", (ncol * (w + GAP), rows * (h + GAP)), BG)
        for k, (_, new) in enumerate(pairs):
            sheet.paste(new, ((k % ncol) * (w + GAP), (k // ncol) * (h + GAP)))
    out = os.path.join(SHOTS, "tg_sheet.png")
    sheet.save(out)
    print("  비교판", out)
    z = crop("tg_paint")
    if z is not None:
        q = z.crop((0, 0, w // 2, h // 2))
        q = q.resize((q.width * 4, q.height * 4), Image.NEAREST)
        out2 = os.path.join(SHOTS, "tg_zoom.png")
        q.save(out2)
        print("  확대", out2)
    return 0


if __name__ == "__main__":
    sys.exit(main())
