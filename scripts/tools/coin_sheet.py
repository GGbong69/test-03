# -*- coding: utf-8 -*-
u"""동전 얼굴을 한 판에 늘어놓는다 — 구운 것 전부를 눈으로 한 번에 본다.

    python scripts/tools/coin_sheet.py [배율]

assets/coin/*.png 를 items.csv 차례로 깔고 이름을 밑에 적는다. 한 장씩
열어 보면 서로 견줄 수가 없어서 「이것만 튄다」 를 못 잡는다 — 결을
맞추는 일은 한 판에 놓고 봐야 한다.
"""
import csv
import io
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
ART = os.path.join(ROOT, "assets", "coin")
BG = (26, 23, 36)

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except AttributeError:
        pass


def main():
    z = int(sys.argv[1]) if len(sys.argv) > 1 else 3
    rs = [r for r in csv.DictReader(
        io.open(os.path.join(ROOT, "data", "items.csv"),
                encoding="utf-8-sig", newline="")) if r["enabled"] == "1"]
    have = [r for r in rs if os.path.exists(os.path.join(ART, r["id"] + ".png"))]
    cell = 36 * z
    pad = 4
    cols = 10
    rows = (len(have) + cols - 1) // cols
    w = cols * (cell + pad) + pad
    h = rows * (cell + pad + 11) + pad
    sheet = Image.new("RGB", (w, h), BG)
    dr = ImageDraw.Draw(sheet)
    for k, r in enumerate(have):
        im = Image.open(os.path.join(ART, r["id"] + ".png")).convert("RGBA")
        im = im.resize((cell, cell), Image.NEAREST)
        x = pad + (k % cols) * (cell + pad)
        y = pad + (k // cols) * (cell + pad + 11)
        tile = Image.new("RGBA", (cell, cell), BG + (255,))
        tile.alpha_composite(im)
        sheet.paste(tile.convert("RGB"), (x, y))
        dr.text((x, y + cell + 1), r["id"], fill=(170, 164, 190))
    out = os.path.join(ROOT, "shots", "coin_sheet.png")
    sheet.save(out)
    print("동전 %d장 → %s  (%dx%d)"
          % (len(have), os.path.relpath(out, ROOT), w, h))


if __name__ == "__main__":
    main()
