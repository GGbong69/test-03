# -*- coding: utf-8 -*-
u"""동전 얼굴 한 장을 미리 본다 — faces.txt 조각을 받아 그림으로 낸다.

    python scripts/tools/coin_try.py <조각.txt> <낼 곳.png> [배율] [한 줄 장수]

조각은 assets/coin_src/faces.txt 와 같은 형식이다(== id / = 글 색 / 격자).
여러 장이 들어 있으면 가로로 이어 붙인다. 기본 배율 10 이면 36 도트가
360px 이 되어 눈으로 고칠 만하다.

**구운 그림과 같은 길을 지난다** — make_coin_art 의 draw_face 와 원형
알파를 그대로 쓴다. 미리보기가 결과와 다르면 미리보기를 볼 이유가 없다.
"""
import io
import os
import sys

from PIL import Image, ImageChops, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_coin_art as M   # noqa: E402
import coin_paint as P      # noqa: E402

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except AttributeError:
        pass


def read(path):
    out, cur, pal, rows_ = [], None, {}, []
    for ln in io.open(path, encoding="utf-8").read().splitlines():
        if ln.startswith("=="):
            if cur:
                out.append((cur, pal, rows_))
            cur = ln.split()[1]
            pal, rows_ = {}, []
        elif ln.startswith("= "):
            t = ln.split()
            pal[t[1]] = t[2]
        elif ln.strip() and not ln.lstrip().startswith("#") and cur:
            rows_.append(ln.rstrip())
    if cur:
        out.append((cur, pal, rows_))
    return out


def one(pal, rows_):
    im = M.draw_face(pal, rows_)
    mask = Image.new("L", (M.SZ * 4, M.SZ * 4), 0)
    ImageDraw.Draw(mask).ellipse(
        (0, 0, M.SZ * 4 * M.EDGE, M.SZ * 4 * M.EDGE), fill=255)
    a = im.getchannel("A").point(lambda v: 255 if v > 0 else 0)
    im.putalpha(ImageChops.multiply(a, mask.resize((M.SZ, M.SZ), Image.LANCZOS)))
    return im


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    cards = read(sys.argv[1])
    if not cards:
        print("조각에 == 로 시작하는 장이 없다")
        return 1
    z = int(sys.argv[3]) if len(sys.argv) > 3 else 10
    cols = int(sys.argv[4]) if len(sys.argv) > 4 else len(cards)
    cols = max(1, min(cols, len(cards)))
    w = M.SZ * z
    lines = (len(cards) + cols - 1) // cols
    sheet = Image.new("RGB", (w * cols, w * lines), (26, 23, 36))
    for k, (cid, pal, rows_) in enumerate(cards):
        bad = [i for i, r in enumerate(rows_) if len(r) != len(rows_)]
        off = P.off_palette(pal)
        print("%-5s %d줄 · 색 %d가지%s%s"
              % (cid, len(rows_), len(pal),
                 "" if not bad else "  ← 줄 길이가 줄 수와 다르다: %s" % bad[:6],
                 "" if not off else "  ← 팔레트 밖의 색: %s" % " ".join(off)))
        im = one(pal, rows_).resize((w, w), Image.NEAREST)
        bg = Image.new("RGBA", (w, w), (26, 23, 36, 255))
        bg.alpha_composite(im)
        sheet.paste(bg.convert("RGB"), ((k % cols) * w, (k // cols) * w))
    sheet.save(sys.argv[2])
    print("→ %s" % sys.argv[2])
    return 0


if __name__ == "__main__":
    sys.exit(main())
