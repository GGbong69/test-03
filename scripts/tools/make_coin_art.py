#!/usr/bin/env python3
# -*- coding: utf-8 -*-
u"""동전 얼굴 굽기 — assets/coin_src/faces.txt 를 assets/coin/<id>.png 로 낸다.
보드 확장 와펜도 여기서 굽는다 — assets/coin_src/mods.txt 를 assets/mod/<id>.png 로.

    python scripts/tools/make_coin_art.py           동전 · 와펜 둘 다
    python scripts/tools/make_coin_art.py --mods    와펜만(아래 「보드 확장 와펜」 절)
    godot --headless --path . --import      ← 구운 뒤 한 번. .import 를 세운다

원본은 파일이 아니라 **faces.txt 의 격자**다. 글 하나가 도트 하나이고,
장마다 제 팔레트를 들고 있다. 효과음(sfx_bake.gd)·음악(mus_bake.py)과 같은
규약이라, 동전 얼굴에도 빌려 온 것이 없다(docs/크레딧.md).

── 사진을 걷은 자리 ────────────────────────────────────────
여기는 한때 스톡 사진을 잘라 도트로 접었다. 38px 에서 도형으로 지은
실루엣이 "무엇인지 모르겠다" 는 말을 들었고, 사진은 뭉개져도 색과 덩어리가
남아서 알아보기 쉬웠기 때문이다. 그 길은 두 가지 이유로 걷었다(2026-09-16).
  ① **알아보는 것보다 결이 먼저다.** 640x360 도트 게임에 사진 한 장이
     얹히면 그 한 장만 다른 게임에서 온 것으로 보인다. 손으로 찍은 스무
     장과 사진에서 구운 서른일곱 장을 한 판에 늘어놓으면 그 경계가 그대로
     보였다 — shots/coin_sheet.png 가 그 판이고, scripts/tools/coin_sheet.py
     가 그것을 찍는다.
  ② **빌려 온 것은 조건을 단다.** 사진을 도트로 접어도 사진이다.
그래서 이 파일에는 자르기·여백 깎기·색 접기가 더 이상 없다. 다시 넣지
마라 — 넣는 순간 ①과 ②가 같이 돌아온다.

굽는 동안 하는 일은 둘뿐이다.
  ① 격자를 그림으로 편다. **줄 수가 곧 해상도다** — 스무 줄짜리 옛 장과
     서른여섯 줄짜리 새 장이 한 파일에 섞여 있어도 각자 제 크기로 읽힌 뒤
     같은 크기로 늘어난다.
  ② **원형 알파를 굽는다.** 동전은 원반이라 네모 그림이 올라가면 안 맞고,
     누운 자세에서 타원 사각에 그리면 이 알파가 같이 눌려 저절로 맞는다.

한 장을 고치는 동안에는 scripts/tools/coin_try.py 로 그 장만 크게 본다.
"""
import csv
import io
import os
import sys

from PIL import Image, ImageChops, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "coin")
FACES = os.path.join(ROOT, "assets", "coin_src", "faces.txt")
#  게임 안에서 동전 얼굴은 **35px** 이다(테이블 rx 19 에서 테두리를 뺀 값).
#  파일을 거기 맞춰 굽는다 — 더 크게 구우면 줄이면서 뭉개지고, 더 작게
#  구우면 쓸 수 있는 해상도를 버린다.
SZ = 36
EDGE = 0.965        # 원형 알파의 바깥. 1.0 이면 테두리에 톱니가 남는다

#  얼굴을 아예 안 붙이는 장. **재질이 이미 그 동전을 말한다.**
#  유리 대포는 유리인 것이 전부고(속이 비쳐야 하는데 그림을 얹으면 막힌다),
#  NULL 은 아무것도 안 찍힌 것이 뜻이다. 그림을 얹으면 둘 다 제 말을 잃는다.
NOART = {"c03", "l03"}

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except AttributeError:
        pass


def rows():
    p = os.path.join(ROOT, "data", "items.csv")
    return [r for r in csv.DictReader(io.open(p, encoding="utf-8-sig", newline=""))
            if r["enabled"] == "1"]


def read_faces():
    u"""faces.txt 를 읽는다.

        == <id>  <이름>     새 장
        = <글> <hex>        팔레트 한 줄
        <격자 줄>           마침표는 비운다(동전 바탕이 비친다)
    """
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
    #  격자의 **줄 수가 곧 해상도**다.
    n = max(len(rows_), 1)
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = im.load()
    for y in range(min(n, len(rows_))):
        ln = rows_[y]
        for x in range(min(n, len(ln))):
            ch = ln[x]
            if ch == "." or ch not in pal:
                continue
            h = pal[ch]
            px[x, y] = (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)
    return im.resize((SZ, SZ), Image.NEAREST)


def disc():
    u"""원형 알파 한 장. 네 배로 그려 줄여 테두리의 톱니를 없앤다."""
    m = Image.new("L", (SZ * 4, SZ * 4), 0)
    ImageDraw.Draw(m).ellipse((0, 0, SZ * 4 * EDGE, SZ * 4 * EDGE), fill=255)
    return m.resize((SZ, SZ), Image.LANCZOS)


#  ══════════════════════════════════════════════════════════
#   보드 확장 와펜 — assets/coin_src/mods.txt → assets/mod/<id>.png
#  ──────────────────────────────────────────────────────────
#  동전과 같은 격자 · 같은 팔레트로 그리고 틀만 방패다(coin_paint.Wappen).
#  한 장이 **36x72** 다 — 위 36 줄이 윗면, 아래 36 줄이 옆면이다.
#    윗면  격자 그대로. 알파는 원형이 아니라 **방패 마스크**다 — 격자의 마침표가
#          곧 방패 밖이고, 굽는 동안 마스크(coin_paint.SHIELD) 밖에 칠이 샌 칸은
#          지우고 알린다. 라지만 손잡이 칸(MASK_EXTRA)을 더 허용한다.
#          알파는 0 · 255 둘뿐이다. 동전처럼 네 배로 그려 줄이면 방패 끝이
#          반투명 톱니가 되어 도트가 번진다.
#    옆면  같은 실루엣을 테 램프 base−1 로 채우고 (x−y)%3==0 칸에 base−2 사선
#          땀을 넣는다. 게임은 이것을 윗면 밑으로 1 · 2px 밀어 깔아 **얇게 땀이
#          난 옆면**을 만들고(동전 옆면은 두껍고 민무늬), 검게 물들여 실루엣
#          모양 그림자로도 쓴다(game.gd 의 _mod_art_draw).
#  옆면을 게임이 윗면에서 뽑지 않는 것은 팔레트 때문이다 — 윗면을 어둡게 곱하면
#  PAL 밖의 색이 된다.
MOD_OUT = os.path.join(ROOT, "assets", "mod")
MODS = os.path.join(ROOT, "assets", "coin_src", "mods.txt")


def mod_rows():
    p = os.path.join(ROOT, "data", "mods.csv")
    return list(csv.DictReader(io.open(p, encoding="utf-8-sig", newline="")))


def read_mods(path=MODS):
    u"""mods.txt 를 읽는다. {id: (이름, 테 램프, 팔레트, 격자)}"""
    import re
    if not os.path.exists(path):
        return {}
    out, cur, pal, rows_, head = {}, None, {}, [], ("", "")
    for ln in io.open(path, encoding="utf-8").read().splitlines():
        if ln.startswith("#"):
            continue
        if ln.startswith("=="):
            if cur:
                out[cur] = (head[0], head[1], pal, rows_)
            m = re.match(r"==\s+(\S+)\s+(.*?)\s*\[테\s+(\w+)\]\s*$", ln)
            if not m:
                raise SystemExit(u"mods.txt: 머리 줄 꼴이 다르다 — %s" % ln)
            cur = m.group(1)
            head = (m.group(2), m.group(3))
            pal, rows_ = {}, []
        elif ln.startswith("= "):
            t = ln.split()
            pal[t[1]] = t[2]
        elif ln.strip() and cur:
            rows_.append(ln.rstrip())
    if cur:
        out[cur] = (head[0], head[1], pal, rows_)
    return out


def mod_mask(mid):
    import coin_paint as P
    m = set(P.SHIELD)
    if mid in MASK_EXTRA:
        m |= MASK_EXTRA[mid]()
    return m


def _panb_extra():
    import coin_paint as P
    import mod_wappen as W
    return {p for p in W.HANDLE if p not in P.SHIELD}


MASK_EXTRA = {"panb": _panb_extra}


def draw_mod(mid, rim, pal, rows_, warn=None):
    u"""와펜 한 장 → 36x72 RGBA(윗면 · 옆면)."""
    import coin_paint as P
    n = P.N
    mask = mod_mask(mid)
    im = Image.new("RGBA", (n, n * 2), (0, 0, 0, 0))
    px = im.load()
    leak = 0
    for y in range(min(n, len(rows_))):
        ln = rows_[y]
        for x in range(min(n, len(ln))):
            ch = ln[x]
            if ch == "." or ch not in pal:
                continue
            if (x, y) not in mask:
                leak += 1
                continue
            h = pal[ch]
            px[x, y] = (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)
    if leak and warn is not None:
        warn.append(u"%s: 방패 밖 %d칸을 지웠다" % (mid, leak))
    side = P.PAL[rim]
    for (x, y) in mask:
        if px[x, y][3] == 0:
            continue
        h = side[0] if (x - y) % 3 == 0 else side[1]
        px[x, y + n] = (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)
    return im


#  .import 한 장. 편집기가 새 png 를 보면 이것을 쓰는데, 이 저장소는 편집기를
#  안 띄우고 굽는 일이 잦아 **굽는 쪽이 같이 세운다.** 값은 assets/photo ·
#  assets/coin 의 것(무손실 · 밉맵 없음)과 같고, 임포트 경로의 꼬리는 고닷이
#  쓰는 대로 res:// 경로의 md5 다. uid 는 비워 둔다 — 첫 임포트가 채운다.
#  임포트가 아직 안 돈 자리(.godot/imported 에 ctex 가 없다)에서는 게임이
#  png 를 직접 읽는다(game.gd 의 _mod_art).
IMPORT = u"""[remap]

importer="texture"
type="CompressedTexture2D"
path="res://.godot/imported/{name}-{h}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{res}"
dest_files=["res://.godot/imported/{name}-{h}.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""


def write_import(dst):
    import hashlib
    q = dst + ".import"
    if os.path.exists(q):
        return
    rel = os.path.relpath(dst, ROOT).replace(os.sep, "/")
    res = "res://" + rel
    h = hashlib.md5(res.encode("utf-8")).hexdigest()
    with io.open(q, "w", encoding="utf-8", newline="\n") as fp:
        fp.write(IMPORT.format(name=os.path.basename(dst), h=h, res=res))


def bake_mods():
    os.makedirs(MOD_OUT, exist_ok=True)
    cards = read_mods()
    warn, miss, n = [], [], 0
    for r in mod_rows():
        mid = r["id"]
        dst = os.path.join(MOD_OUT, "%s.png" % mid)
        if mid not in cards:
            for q in (dst, dst + ".import"):
                if os.path.exists(q):
                    os.remove(q)
            miss.append(r["name"])
            continue
        _nm, rim, pal, g = cards[mid]
        draw_mod(mid, rim, pal, g, warn).save(dst)
        write_import(dst)
        n += 1
    print(u"와펜 %d장 → %s" % (n, os.path.relpath(MOD_OUT, ROOT)))
    for w in warn:
        print(u"  " + w)
    if miss:
        print(u"아직 빈 %d장: %s" % (len(miss), u" · ".join(miss)))


def main():
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    if "--mods" in sys.argv:
        bake_mods()
        return
    bake_mods()
    os.makedirs(OUT, exist_ok=True)
    faces = read_faces()
    mask = disc()
    n = 0
    miss = []
    for r in rows():
        dst = os.path.join(OUT, "%s.png" % r["id"])
        if r["id"] in NOART or r["id"] not in faces:
            #  .import 도 같이 지운다. 원본만 지우면 고닷은 이미 구워 둔
            #  리소스를 보고 ResourceLoader.exists 에 **있다**고 답한다 —
            #  유리 대포가 얼굴을 계속 달고 있던 것이 그래서였다.
            for q in (dst, dst + ".import"):
                if os.path.exists(q):
                    os.remove(q)
            if r["id"] not in NOART:
                miss.append(r["name"])
            continue
        pal, g = faces[r["id"]]
        im = draw_face(pal, g)
        a = im.getchannel("A").point(lambda v: 255 if v > 0 else 0)
        im.putalpha(ImageChops.multiply(a, mask))
        im.save(dst)
        n += 1
    print(u"얼굴 %d장 → %s" % (n, os.path.relpath(OUT, ROOT)))
    #  얼굴이 없는 장은 게임이 손으로 그린다(game.gd 의 _icon_item match).
    print(u"아직 빈 %d장: %s" % (len(miss), u" · ".join(miss)))


if __name__ == "__main__":
    main()
