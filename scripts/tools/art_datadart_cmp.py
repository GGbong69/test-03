# -*- coding: utf-8 -*-
u"""다트 네 자루 — 옛 그림 | 새 그림을 한 장에 나란히 붙인다.

    godot --path . --quit-after 4000 --script scripts/tools/shot_art_datadart.gd -- old   (바꾸기 전)
    godot --path . --quit-after 4000 --script scripts/tools/shot_art_datadart.gd -- new   (바꾼 뒤)
    python scripts/tools/art_datadart_cmp.py
    → shots/art_dart_cmp.png       자리마다 한 줄, 왼쪽 옛 · 오른쪽 새
    → shots/art_dart_gray.png      새 미리보기 판의 회색조 — 색을 빼도 넷이 갈리는가

작은 자리(컬렉션 · 벽 · 테이블)는 도트가 보이게 정수배로 키운다(NEAREST).
"""
import os
import sys
from PIL import Image

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "shots")
BG = (34, 29, 51)
GAP = 12

#  자리 이름, 찍은 파일(꼬리표 앞), 자를 사각(1280x720 기준, None 이면 통째), 배율
#  (나는 자루 판은 가로 넷 × 1440 이라 절반으로 줄인다)
ROWS = [
    ("collect", "collect", (60, 140, 720, 260), 2),
    ("wall", "wall", (0, 260, 240, 640), 2),
    ("board3d", "wall", (400, 150, 880, 640), 1),
    ("title", "title", (460, 200, 820, 640), 1),
    ("shop", "shop", (380, 250, 900, 540), 2),
    ("fly", "fly", None, 0.5),
    ("cups", "cups", None, 1),
    ("sheet", "sheet", None, 1),
]


def load(name, tag, box, sc):
    p = os.path.join(ROOT, "art_dart_%s_%s.png" % (name, tag))
    if not os.path.exists(p):
        return None
    im = Image.open(p).convert("RGB")
    if box:
        im = im.crop(box)
    if sc != 1:
        im = im.resize((int(im.width * sc), int(im.height * sc)), Image.NEAREST)
    return im


def main():
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    pairs = []
    for key, name, box, sc in ROWS:
        a = load(name, "old", box, sc)
        b = load(name, "new", box, sc)
        if a is None and b is None:
            print("  없음", key)
            continue
        pairs.append((key, a, b))
    if not pairs:
        print("찍은 파일이 없다 — shot_art_datadart.gd 를 먼저 돌려라")
        sys.exit(1)
    cw = max(max(x.width for x in (a, b) if x is not None) for _, a, b in pairs)
    H = sum(max(x.height for x in (a, b) if x is not None) + GAP for _, a, b in pairs)
    out = Image.new("RGB", (cw * 2 + GAP * 3, H + GAP), BG)
    y = GAP
    for key, a, b in pairs:
        h = max(x.height for x in (a, b) if x is not None)
        if a is not None:
            out.paste(a, (GAP, y))
        if b is not None:
            out.paste(b, (GAP * 2 + cw, y))
        y += h + GAP
        print("  %-8s %s" % (key, "옛 | 새" if a is not None and b is not None else "한쪽뿐"))
    dst = os.path.join(ROOT, "art_dart_cmp.png")
    out.save(dst)
    print(os.path.normpath(dst), out.size)
    sh = os.path.join(ROOT, "art_dart_sheet_new.png")
    if os.path.exists(sh):
        g = Image.open(sh).convert("L").convert("RGB")
        dst = os.path.join(ROOT, "art_dart_gray.png")
        g.save(dst)
        print(os.path.normpath(dst), g.size)


if __name__ == "__main__":
    main()
