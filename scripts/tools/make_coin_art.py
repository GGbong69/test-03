#!/usr/bin/env python3
# -*- coding: utf-8 -*-
u"""동전 얼굴 굽기 — 레퍼런스 사진을 잘라 assets/coin/<id>.png 로 낸다.

    python scripts/tools/make_coin_art.py <레퍼런스 폴더>
    godot --headless --path . --import      ← 구운 뒤 한 번. .import 를 세운다

레퍼런스는 **파일 번호 = 쓰는 동전(enabled=1)의 줄 번호** 로 짝이 맞는다.
번호 구멍은 아직 레퍼런스가 없는 동전이고, 그 자리는 손으로 그린 얼굴
(_icon_item 의 match)이 그대로 맡는다.

왜 손으로 안 그리고 자르는가 — 38px 에서 도형으로 지은 실루엣은 "무엇인지
모르겠다" 는 말을 들었다. 사진은 뭉개져도 색과 덩어리가 남아서 오히려
알아보기 쉽다. 알아보는 것이 먼저다.

굽는 동안 하는 일
  ① 가장자리의 단색 여백을 깎는다. 스톡 사진은 흰 여백이 절반인 것이 많아
     그대로 줄이면 피사체가 8px 이 된다.
  ② 남은 것의 가운데를 정사각으로 딴다.
  ③ 40x40 으로 줄인다. 테이블 얼굴이 35px 이라 거기 맞춘 값이다.
  ④ 채도와 대비를 올린다. 40px 로 줄이면 평균이 나면서 둘 다 죽는다.
  ⑤ **원형 알파를 굽는다.** 동전은 원반이라 네모 그림이 올라가면 안 맞고,
     누운 자세에서 타원 사각에 그리면 이 알파가 같이 눌려 저절로 맞는다.
"""
import csv
import glob
import io
import os
import sys

from PIL import Image, ImageEnhance, ImageDraw, ImageChops

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "coin")
SZ = 40
EDGE = 0.965        # 원형 알파의 바깥. 1.0 이면 테두리에 톱니가 남는다

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except AttributeError:
        pass


def rows():
    p = os.path.join(ROOT, "data", "items.csv")
    return [r for r in csv.DictReader(io.open(p, encoding="utf-8-sig", newline=""))
            if r["enabled"] == "1"]


def trim(im):
    """가장자리 단색 여백을 깎는다. 네 모서리의 평균색을 배경으로 본다."""
    rgb = im.convert("RGB")
    w, h = rgb.size
    cor = [rgb.getpixel(p) for p in
           ((0, 0), (w - 1, 0), (0, h - 1), (w - 1, h - 1))]
    bg = tuple(sum(c[i] for c in cor) // 4 for i in range(3))
    #  모서리 넷이 서로 다르면 여백이 아니다 — 그때는 안 깎는다
    if max(max(abs(c[i] - bg[i]) for i in range(3)) for c in cor) > 26:
        return im
    diff = ImageChops.difference(rgb, Image.new("RGB", rgb.size, bg))
    box = diff.convert("L").point(lambda v: 255 if v > 26 else 0).getbbox()
    if box is None:
        return im
    #  너무 바짝 깎으면 물건이 테두리에 닿는다. 한 뼘 남긴다.
    pad = int(min(box[2] - box[0], box[3] - box[1]) * 0.06)
    return im.crop((max(box[0] - pad, 0), max(box[1] - pad, 0),
                    min(box[2] + pad, w), min(box[3] + pad, h)))


def square(im):
    w, h = im.size
    s = min(w, h)
    #  세로로 긴 것(포스터·책 표지)은 **위쪽**을 딴다. 가운데를 따면
    #  제목과 얼굴이 잘리고 옷자락만 남는 일이 잦다.
    y0 = (h - s) // 4 if h > w else (h - s) // 2
    return im.crop(((w - s) // 2, y0, (w - s) // 2 + s, y0 + s))


def bake(src, dst):
    im = Image.open(src).convert("RGB")
    im = square(trim(im)).resize((SZ, SZ), Image.LANCZOS)
    im = ImageEnhance.Color(im).enhance(1.35)
    im = ImageEnhance.Contrast(im).enhance(1.18)
    out = im.convert("RGBA")
    mask = Image.new("L", (SZ * 4, SZ * 4), 0)
    ImageDraw.Draw(mask).ellipse(
        (0, 0, SZ * 4 * EDGE, SZ * 4 * EDGE), fill=255)
    out.putalpha(mask.resize((SZ, SZ), Image.LANCZOS))
    out.save(dst)


def main():
    src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        os.path.expanduser("~"), "Downloads", "새 폴더 (2)")
    have = {}
    for f in glob.glob(os.path.join(src, "*")):
        b = os.path.basename(f)
        try:
            have[int(b.split(".")[0])] = f
        except ValueError:
            pass
    os.makedirs(OUT, exist_ok=True)
    rs = rows()
    n = 0
    miss = []
    for i, r in enumerate(rs, 1):
        f = have.get(i)
        if f is None:
            miss.append(r["name"])
            continue
        bake(f, os.path.join(OUT, "%s.png" % r["id"]))
        n += 1
    print("구운 것 %d장 → %s" % (n, os.path.relpath(OUT, ROOT)))
    print("레퍼런스 없는 %d장(손그림이 맡는다): %s" % (len(miss), " · ".join(miss)))


if __name__ == "__main__":
    main()
