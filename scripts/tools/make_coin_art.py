#!/usr/bin/env python3
# -*- coding: utf-8 -*-
u"""동전 얼굴 굽기 — 레퍼런스 사진을 잘라 assets/coin/<id>.png 로 낸다.

    python scripts/tools/make_coin_art.py <레퍼런스 폴더>
    godot --headless --path . --import      ← 구운 뒤 한 번. .import 를 세운다

레퍼런스는 **파일 번호 = 쓰는 동전(enabled=1)의 줄 번호** 로 짝이 맞는다.
번호 구멍은 아직 레퍼런스가 없는 동전이고, 그 자리는 손으로 그린 얼굴
(_icon_item 의 match)이 그대로 맡는다.

자동 규칙이 어긋나는 장은 FIX 에 자리를 손으로 적는다. 규칙을 고치면 잘
나오던 쉰 장이 같이 흔들리므로 예외는 예외로 둔다.

왜 손으로 안 그리고 자르는가 — 38px 에서 도형으로 지은 실루엣은 "무엇인지
모르겠다" 는 말을 들었다. 사진은 뭉개져도 색과 덩어리가 남아서 오히려
알아보기 쉽다. 알아보는 것이 먼저다.

굽는 동안 하는 일
  ① 가장자리의 단색 여백을 깎는다. 스톡 사진은 흰 여백이 절반인 것이 많아
     그대로 줄이면 피사체가 8px 이 된다.
  ② 남은 것의 가운데를 정사각으로 딴다.
  ③ 채도와 대비를 올린다. 줄이면 평균이 나면서 둘 다 죽는다.
  ④ **도트로 접는다.** 20x20 으로 줄이고 색을 열로 접은 뒤 정수배로 되늘린다
     — 도트 하나가 화면에서 두 픽셀이다. 640x360 픽셀 게임에 사진이 얹혀
     있는 것이 지금 제일 안 어울리는 자리였다.
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
GRID = 20           # 그림의 **실제 해상도**. 도트 하나가 화면에서 두 픽셀이다
SZ = GRID * 2       # 파일 크기. 정수배라야 도트가 고르게 선다
COLORS = 10         # 색 수. 사진의 그러데이션을 면으로 접는다
EDGE = 0.965        # 원형 알파의 바깥. 1.0 이면 테두리에 톱니가 남는다

#  자리를 손으로 잡는 장. (가로중심, 세로중심, 따는 크기) — 셋 다 **원본**
#  기준의 0~1 비율이다. 자리를 적은 장은 여백 깎기를 건너뛴다 — 깎기가 먼저
#  돌면 기준 그림이 장마다 달라져서 어디를 가리키는지 셀 수가 없다. 자동 규칙(여백 깎기 + 위쪽 정사각)이 어긋나는
#  자리만 적는다. 규칙을 고치면 잘 나오던 쉰 장이 같이 흔들리므로,
#  **예외는 예외로 둔다.**
FIX = {
    "c15": (0.52, 0.55, 0.62),   # HOPE — 표지판만. 하늘과 아스팔트를 걷는다
    "r04": (0.50, 0.50, 0.96),   # 카우보이 — 검은 모자다. 당길수록 검어지므로
                                 #   흰 배경을 남긴다. 실루엣이 곧 그 물건이다
    "r02": (0.50, 0.46, 0.82),   # 수전증 — 잔을 쥔 손
    "l03": (0.50, 0.50, 1.00),   # NULL — 판을 통째로. 글자가 곧 그림이다
    "u31": (0.55, 0.52, 0.72),   # 딱정벌레의 도로 — 걷는 넷이 있는 가운데
    "u22": (0.29, 0.28, 0.42),   # WHITE ALBUM — 넷 중 왼쪽 위 하나.
                                 #   20px 에 넷을 넣으면 얼굴이 5px 이 된다
    "c45": (0.50, 0.40, 0.72),   # 삼미신 — 셋의 상반신
    "c43": (0.50, 0.44, 0.78),   # 감자 먹는 사람들 — 등불과 둘러앉은 자리
    "c50": (0.50, 0.44, 0.82),   # 트리플 엘비스 — 겹친 셋
    "l02": (0.50, 0.48, 0.58),   # 정조준 — 조준선만. 흰 여백이 너무 넓었다
    "u28": (0.50, 0.50, 0.94),   # 피보나치 — 나선이 칸을 채우게
    "u24": (0.52, 0.62, 0.72),   # 비포 선라이즈 — 첨탑. 제목 줄을 걷는다
    "c48": (0.50, 0.32, 0.64),   # 더 굿 더 베드 — 모자와 눈. 글자를 걷는다
    "u20": (0.50, 0.50, 0.90),   # 그 탑을 잡아라 — 탑 꼭대기가 가운데 오게
    "c35": (0.50, 0.50, 0.86),   # quite my tempo — 스틱과 드럼이 같이 들게
    "c44": (0.50, 0.48, 0.70),   # 어린 왕자 — 장미만. 배경 초록을 줄인다
    "u18": (0.46, 0.52, 0.86),   # 머니건 — 총과 지폐
    "r03": (0.50, 0.46, 0.88),   # 더 사일런트 — 두건과 쌍검이 다 들게
}

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


def square(im, fix=None):
    w, h = im.size
    if fix is not None:
        fx, fy, fz = fix
        s = int(min(w, h) * fz)
        x0 = int(w * fx - s * 0.5)
        y0 = int(h * fy - s * 0.5)
        x0 = max(0, min(x0, w - s))
        y0 = max(0, min(y0, h - s))
        return im.crop((x0, y0, x0 + s, y0 + s))
    s = min(w, h)
    #  세로로 긴 것(포스터·책 표지)은 **위쪽**을 딴다. 가운데를 따면
    #  제목과 얼굴이 잘리고 옷자락만 남는 일이 잦다.
    y0 = (h - s) // 4 if h > w else (h - s) // 2
    return im.crop(((w - s) // 2, y0, (w - s) // 2 + s, y0 + s))


def dots(im):
    """도트로 접는다. 640x360 픽셀 게임에 사진이 얹혀 있는 것이 지금 제일
    안 어울리는 자리다.

    ① GRID 로 줄여 **그림의 실제 해상도**를 정한다. 여기가 도트 크기다.
    ② 색을 COLORS 로 접는다. 디더는 안 쓴다 — 20px 에서 오차확산은 결이
       아니라 먼지로 보인다. 면으로 접는 편이 이 크기에서 읽힌다.
    ③ 정수배로 되늘린다. NEAREST 라야 도트가 도트로 남는다."""
    sm = im.resize((GRID, GRID), Image.LANCZOS)
    sm = sm.quantize(colors=COLORS, method=Image.MEDIANCUT,
                     dither=Image.Dither.NONE).convert("RGB")
    return sm.resize((SZ, SZ), Image.NEAREST)


def bake(src, dst, fix=None):
    im = Image.open(src).convert("RGB")
    im = square(im if fix is not None else trim(im), fix)
    #  색은 **접기 전에** 올린다. 접은 뒤에 올리면 열 가지 색만 세져서
    #  면이 형광으로 뜬다.
    im = ImageEnhance.Color(im).enhance(1.45)
    im = ImageEnhance.Contrast(im).enhance(1.22)
    out = dots(im).convert("RGBA")
    mask = Image.new("L", (SZ * 4, SZ * 4), 0)
    ImageDraw.Draw(mask).ellipse(
        (0, 0, SZ * 4 * EDGE, SZ * 4 * EDGE), fill=255)
    out.putalpha(mask.resize((SZ, SZ), Image.LANCZOS))
    out.save(dst)


#  ── 손으로 찍은 도트가 사진을 이긴다 ──────────────────────
#  사진은 도트로 접어도 사진이다. "누가 봐도 패러디" 로 가려면 구도와
#  팔레트만 보고 **직접 찍어야** 한다. 여기 있는 id 는 사진을 안 쓴다.
#
#  글 하나가 도트 하나다. 첫 줄들이 `= <글> <색>` 으로 팔레트를 적고,
#  그 뒤 GRID 줄이 그림이다. 마침표는 비운다(동전 바탕이 비친다).
FACES = os.path.join(ROOT, "assets", "coin_src", "faces.txt")


def read_faces():
    if not os.path.exists(FACES):
        return {}
    out, cur, pal, rows_ = {}, None, {}, []
    for ln in io.open(FACES, encoding="utf-8").read().splitlines():
        if ln.startswith("=="):
            if cur:
                out[cur] = (pal, rows_)
            cur = ln.split()[1]
            pal, rows_ = {}, []
        elif ln.startswith("= "):
            t = ln.split()
            pal[t[1]] = t[2]
        elif ln.strip() and cur:
            rows_.append(ln.rstrip())
    if cur:
        out[cur] = (pal, rows_)
    return out


def draw_face(pal, rows_):
    im = Image.new("RGBA", (GRID, GRID), (0, 0, 0, 0))
    px = im.load()
    for y in range(min(GRID, len(rows_))):
        ln = rows_[y]
        for x in range(min(GRID, len(ln))):
            ch = ln[x]
            if ch == "." or ch not in pal:
                continue
            h = pal[ch]
            px[x, y] = (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)
    return im.resize((SZ, SZ), Image.NEAREST)


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
    faces = read_faces()
    rs = rows()
    n = d = 0
    miss = []
    for i, r in enumerate(rs, 1):
        dst = os.path.join(OUT, "%s.png" % r["id"])
        if r["id"] in faces:
            pal, g = faces[r["id"]]
            im = draw_face(pal, g)
            mask = Image.new("L", (SZ * 4, SZ * 4), 0)
            ImageDraw.Draw(mask).ellipse(
                (0, 0, SZ * 4 * EDGE, SZ * 4 * EDGE), fill=255)
            a = im.getchannel("A").point(lambda v: 255 if v > 0 else 0)
            im.putalpha(ImageChops.multiply(
                a, mask.resize((SZ, SZ), Image.LANCZOS)))
            im.save(dst)
            d += 1
            continue
        f = have.get(i)
        if f is None:
            miss.append(r["name"])
            continue
        bake(f, dst, FIX.get(r["id"]))
        n += 1
    print("직접 찍은 것 %d장 · 사진에서 구운 것 %d장 → %s"
          % (d, n, os.path.relpath(OUT, ROOT)))
    print("아직 빈 %d장: %s" % (len(miss), " · ".join(miss)))


if __name__ == "__main__":
    main()
