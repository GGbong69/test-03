#!/usr/bin/env python3
# -*- coding: utf-8 -*-
u"""사진 아이템 그림 굽기 — assets/photo_src/<id>.txt 를 assets/photo/<id>.png 로 낸다.

    python scripts/tools/make_photo_art.py                 전부 굽는다
    python scripts/tools/make_photo_art.py v_fake           한 장만 굽는다
    python scripts/tools/make_photo_art.py --try v_fake [레퍼런스]
                                                            크게 본다 → shots/photo_try_<id>.png
    python scripts/tools/make_photo_art.py --sheet          아홉 장을 한 판에 → shots/photo_sheet.png
    godot --headless --path . --import                     ← 새 png 가 생긴 뒤 한 번

동전 얼굴(make_coin_art.py)과 같은 규약이다. 원본은 파일이 아니라 **격자**다.
글 하나가 도트 하나이고, 장마다 제 팔레트를 들고 있다. 레퍼런스는 구도와 색의
분위기만 보고, 사진을 도트로 접지 않는다 — 접는 순간 그 한 장만 다른 게임에서
온 것으로 보이고, 빌려 온 것이 조건을 단다(make_coin_art 머리말). 받아 둔
레퍼런스는 저장소에 넣지 않는다.

── 격자 ────────────────────────────────────────────────────
  == <id>  <이름>      첫 줄
  = <글> <색>          팔레트 한 줄(색은 coin_paint.PAL 또는 INK 안에서)
  그 뒤 스물네 줄      한 줄에 서른두 글자. 비우는 글자는 없다 — 인화지는 꽉 찬다

── 크기 ────────────────────────────────────────────────────
  32 x 24 (4:3). 테이블 위 폴라로이드의 인화면이 화면에서 그 크기다
  (FIX_W·FIX_H 에 GOODS_K 1.16 을 곱한 카드 39x32 에서 테두리를 남긴 자리).
  누우면 세로가 0.788 로 눌려 줄 몇이 빠진다 — 한 줄짜리 가는 선에 뜻을 걸지 마라.

── 한 벌의 말투(동전과 같다) ─────────────────────────────────
  ① 팔레트가 하나다      coin_paint.PAL 의 램프 열넷 × 네 단 + INK
  ② 빛이 하나다          왼쪽 위
  ③ 테두리선이 없다      물건끼리는 선이 아니라 밝기 차로 가른다
"""
import io
import os
import sys

from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import coin_paint as P      # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "assets", "photo_src")
OUT = os.path.join(ROOT, "assets", "photo")
SHOTS = os.path.join(ROOT, "shots")
W, H = 32, 24

#  사진 아이템 아홉 — 표(consumables.csv)의 줄 순서
IDS = ["v_cash", "v_pick", "v_redo", "v_par", "v_moth", "v_fake", "v_pnt", "v_peek", "c_again"]

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except AttributeError:
        pass


def read(pid):
    path = os.path.join(SRC, pid + ".txt")
    lines = io.open(path, encoding="utf-8").read().splitlines()
    name = ""
    pal = {}
    rows = []
    for ln in lines:
        if ln.startswith("#") or not ln.strip() and not rows:
            continue
        if ln.startswith("== "):
            parts = ln[3:].split(None, 1)
            if parts[0] != pid:
                raise SystemExit("%s: 머리의 id '%s' 가 파일 이름과 다르다" % (path, parts[0]))
            name = parts[1].strip() if len(parts) > 1 else ""
            continue
        if ln.startswith("= "):
            _, ch, hx = ln.split()
            pal[ch] = hx.lower()
            continue
        if ln.strip():
            rows.append(ln.rstrip("\n"))
    errs = []
    if len(rows) != H:
        errs.append("줄이 %d — %d 이어야 한다" % (len(rows), H))
    for y, r in enumerate(rows):
        if len(r) != W:
            errs.append("%d번 줄이 %d 글자 — %d 이어야 한다" % (y + 1, len(r), W))
        for ch in r:
            if ch not in pal:
                errs.append("%d번 줄의 '%s' 가 팔레트에 없다" % (y + 1, ch))
                break
    for ch, hx in pal.items():
        if hx not in P.ALL:
            errs.append("팔레트 '%s' %s 가 coin_paint.PAL · INK 밖이다" % (ch, hx))
    if errs:
        raise SystemExit("%s\n  " % path + "\n  ".join(errs))
    return name, pal, rows


def render(pid):
    name, pal, rows = read(pid)
    im = Image.new("RGB", (W, H))
    px = im.load()
    for y, r in enumerate(rows):
        for x, ch in enumerate(r):
            hx = pal[ch]
            px[x, y] = (int(hx[0:2], 16), int(hx[2:4], 16), int(hx[4:6], 16))
    return name, im


def bake(pid):
    name, im = render(pid)
    os.makedirs(OUT, exist_ok=True)
    im.save(os.path.join(OUT, pid + ".png"))
    return name, im


def _font(sz):
    try:
        return ImageFont.truetype("C:/Windows/Fonts/malgun.ttf", sz)
    except Exception:
        return ImageFont.load_default()


def _polaroid(im, k):
    """게임 테이블의 폴라로이드를 흉내 낸다 — 크림 카드에 인화면, 아래 여백이 넓다."""
    cw, ch = 39, 32
    card = Image.new("RGB", (cw, ch), (0xfb, 0xf6, 0xea))
    card.paste(im, (3, 3))
    return card.resize((cw * k, ch * k), Image.NEAREST)


def try_one(pid, ref=None):
    name, im = bake(pid)
    big = im.resize((W * 12, H * 12), Image.NEAREST)
    pol1 = _polaroid(im, 2)           # 게임 창(1280x720)에서의 실제 크기
    lying = _polaroid(im, 2).resize((39 * 2, int(32 * 2 * 0.788)), Image.NEAREST)
    pad = 16
    ref_im = None
    if ref:
        ref_im = Image.open(ref).convert("RGB")
        ref_im.thumbnail((W * 12, H * 12))
    wid = pad + big.width + pad + (ref_im.width + pad if ref_im else 0) + 200
    hei = pad * 2 + max(big.height, ref_im.height if ref_im else 0) + 30
    sheet = Image.new("RGB", (wid, hei), (0x14, 0x11, 0x1f))
    d = ImageDraw.Draw(sheet)
    f = _font(16)
    x = pad
    d.text((x, 4), "%s %s — 도트 x12" % (pid, name), font=f, fill=(0xf2, 0xc9, 0x4c))
    sheet.paste(big, (x, pad + 16))
    x += big.width + pad
    if ref_im:
        d.text((x, 4), "레퍼런스", font=f, fill=(0x9b, 0x92, 0xb4))
        sheet.paste(ref_im, (x, pad + 16))
        x += ref_im.width + pad
    d.text((x, 4), "게임 크기", font=f, fill=(0x9b, 0x92, 0xb4))
    sheet.paste(pol1, (x, pad + 16))
    sheet.paste(lying, (x, pad + 16 + pol1.height + 12))
    os.makedirs(SHOTS, exist_ok=True)
    out = os.path.join(SHOTS, "photo_try_%s.png" % pid)
    sheet.save(out)
    print(out)


def sheet_all():
    ims = []
    for pid in IDS:
        if os.path.exists(os.path.join(SRC, pid + ".txt")):
            ims.append((pid,) + render(pid))
    k = 8
    cw, ch = W * k + 20, H * k + 60
    cols = 3
    rows = (len(ims) + cols - 1) // cols
    s = Image.new("RGB", (cw * cols, ch * rows), (0x14, 0x11, 0x1f))
    d = ImageDraw.Draw(s)
    f = _font(15)
    for i, (pid, name, im) in enumerate(ims):
        x, y = (i % cols) * cw + 10, (i // cols) * ch + 8
        s.paste(im.resize((W * k, H * k), Image.NEAREST), (x, y))
        pol = _polaroid(im, 2)
        s.paste(pol, (x + W * k - pol.width, y + H * k + 4))
        d.text((x, y + H * k + 6), "%s  %s" % (pid, name), font=f, fill=(0xe8, 0xdf, 0xc8))
    out = os.path.join(SHOTS, "photo_sheet.png")
    s.save(out)
    print(out)


def main(argv):
    if argv and argv[0] == "--try":
        try_one(argv[1], argv[2] if len(argv) > 2 else None)
        return
    if argv and argv[0] == "--sheet":
        sheet_all()
        return
    ids = argv if argv else [p for p in IDS if os.path.exists(os.path.join(SRC, p + ".txt"))]
    for pid in ids:
        name, _ = bake(pid)
        print("%s  %s" % (pid, name))


if __name__ == "__main__":
    main(sys.argv[1:])
