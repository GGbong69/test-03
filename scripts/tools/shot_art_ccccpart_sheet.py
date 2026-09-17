# -*- coding: utf-8 -*-
u"""얼굴이 없던 동전 열 장 — 전 · 후를 한 판에 붙인다.

    godot --path . --quit-after 2400 --script scripts/tools/shot_art_ccccpart.gd
    python scripts/tools/shot_art_ccccpart_sheet.py
    → shots/artc_sheet.png

한 줄에 한 장이다. 왼쪽부터
  ① 컬렉션 칸  전(조건 기호만) · 후        (게임 화면 두 배 갈무리를 세 배로)
  ② 동전 슬롯  전 · 후
  ③ 구운 얼굴  assets/coin/<id>.png 여섯 배 — 한 도트씩 보는 큰 판
갈무리 좌표는 shot_art_ccccpart.gd 가 적어 둔 shots/artc_cells.json 을 따른다.
"""
import io
import json
import os
import sys

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SH = os.path.join(ROOT, "shots")
IDS = ["c11", "c16", "c17", "c18", "c19", "c31", "c39", "c40", "c41", "c47"]
BG = (26, 23, 36)
CROP = 64          # 1280x720 갈무리에서 자르는 한 변
ZC = 3             # 갈무리 조각 배율
ZF = 6             # 구운 얼굴 배율

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except AttributeError:
        pass


def crop(img, x, y):
    h = CROP // 2
    c = img.crop((int(x * 2) - h, int(y * 2) - h, int(x * 2) + h, int(y * 2) + h))
    return c.resize((CROP * ZC, CROP * ZC), Image.NEAREST)


def main():
    cells = json.load(io.open(os.path.join(SH, "artc_cells.json"), encoding="utf-8"))
    shots = {}

    def shot(nm):
        if nm not in shots:
            shots[nm] = Image.open(os.path.join(SH, nm + ".png")).convert("RGB")
        return shots[nm]

    tile = CROP * ZC
    face = 36 * ZF
    pad = 8
    row_h = max(tile, face) + pad
    w = 4 * (tile + pad) + face + pad * 3 + 32     # 끝에 id 글자 자리
    sheet = Image.new("RGB", (w, len(IDS) * row_h + 24), BG)
    dr = ImageDraw.Draw(sheet)
    heads = ["collection old", "collection new", "slot old", "slot new", "baked x6"]
    for k, t in enumerate(heads):
        dr.text((pad + k * (tile + pad), 6), t, fill=(170, 164, 190))
    for r, cid in enumerate(IDS):
        y = 24 + r * row_h
        ce = cells[cid]
        x = pad
        for ver in ("old", "new"):
            im = shot("artc_col_%s_%d" % (ver, int(ce["page"])))
            sheet.paste(crop(im, ce["x"], ce["y"]), (x, y))
            x += tile + pad
        sl = ce.get("slot")
        for ver in ("old", "new"):
            if sl:
                im = shot("artc_shop_%s_%d" % (ver, int(sl["b"])))
                sheet.paste(crop(im, sl["x"], sl["y"]), (x, y))
            x += tile + pad
        png = os.path.join(ROOT, "assets", "coin", cid + ".png")
        if os.path.exists(png):
            f = Image.open(png).convert("RGBA").resize((face, face), Image.NEAREST)
            t = Image.new("RGBA", (face, face), BG + (255,))
            t.alpha_composite(f)
            sheet.paste(t.convert("RGB"), (x, y))
        dr.text((x + face + 4, y + 4), cid, fill=(170, 164, 190))
    out = os.path.join(SH, "artc_sheet.png")
    sheet.save(out)
    print(u"열 장 전·후 → %s  (%dx%d)" % (os.path.relpath(out, ROOT), sheet.size[0],
                                       sheet.size[1]))


if __name__ == "__main__":
    main()
