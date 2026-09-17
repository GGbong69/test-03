# -*- coding: utf-8 -*-
u"""보드 확장 와펜을 크게 · 게임 크기로 본다.

    python scripts/tools/mod_try.py [mods.txt] [낼 곳.png]
    → 기본 shots/mod_try.png
    python scripts/tools/mod_try.py --oldnew
    → shots/art_mods_oldnew.png — 게임에서 찍은 옛 도식과 와펜을 나란히
      (먼저 shot_art_datamods.gd 를 돌려야 한다)

한 판에 세 줄을 깐다.
  ① 여덟 배 — 도트를 고치는 눈
  ② 게임 크기(물리 픽셀, 창 1280x720 = 논리 640x360 의 두 배)
       컬렉션 · 앞치마 r13 → 52px · 명판 r9 → 36px · 상점 테이블(누움) 88x69 + 옆면
  ③ 같은 크기의 동전 몇 장 — 동전과 한 식구이되 갈리는지
**구운 그림과 같은 길을 지난다** — make_coin_art.draw_mod 를 그대로 쓴다.
팔레트 밖의 색이 있으면 장마다 알린다.
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import coin_paint as P      # noqa: E402
import make_coin_art as M   # noqa: E402

ROOT = M.ROOT
BG = (20, 17, 31)            # C_BG 14111f
FELT = (22, 40, 31)          # 펠트 16281f

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except AttributeError:
        pass


def flat(im, w, h, side_px=2):
    u"""테이블에 누운 자세 — 윗면을 세로로 누르고 옆면을 1 · 2px 밑에 깐다."""
    top = im.crop((0, 0, 36, 36)).resize((w, h), Image.NEAREST)
    side = im.crop((0, 36, 36, 72)).resize((w, h), Image.NEAREST)
    out = Image.new("RGBA", (w, h + side_px * 2 + 4), (0, 0, 0, 0))
    sh = side.copy()
    sh.putdata([(0, 0, 0, int(a * 0.3)) for (_r, _g, _b, a) in side.get_flattened_data()])
    out.alpha_composite(sh, (1, side_px + 3))
    for k in range(side_px, 0, -1):
        out.alpha_composite(side, (0, k))
    out.alpha_composite(top, (0, 0))
    return out


def oldnew():
    u"""shot_art_datamods.gd 가 찍은 옛(*_old) · 새 갈무리를 나란히 놓는다."""
    sh = os.path.join(ROOT, "shots")
    pairs = [
        #  (옛, 새, 자를 곳 — 1280x720 물리 픽셀)
        ("art_mods_collect_old.png", "art_mods_collect.png", (40, 140, 1240, 380)),
        ("art_mods_shop_0_old.png", "art_mods_shop_0.png", (300, 330, 900, 540)),
    ]
    rows = []
    for a, b, box in pairs:
        pa, pb = os.path.join(sh, a), os.path.join(sh, b)
        if not (os.path.exists(pa) and os.path.exists(pb)):
            print("없다: %s · %s — shot_art_datamods.gd 를 먼저 돌린다" % (a, b))
            return 1
        ia = Image.open(pa).convert("RGB").crop(box)
        ib = Image.open(pb).convert("RGB").crop(box)
        rows.append((ia, ib))
    big = os.path.join(sh, "art_mods_sheet_1.png")
    w = max(ia.width + ib.width + 12 for ia, ib in rows)
    h = sum(max(ia.height, ib.height) + 12 for ia, ib in rows)
    if os.path.exists(big):
        bi = Image.open(big).convert("RGB")
        h += bi.height + 12
        w = max(w, bi.width)
    out = Image.new("RGB", (w, h), BG)
    y = 0
    for ia, ib in rows:
        out.paste(ia, (0, y))
        out.paste(ib, (ia.width + 12, y))
        y += max(ia.height, ib.height) + 12
    if os.path.exists(big):
        out.paste(bi, (0, y))
    dst = os.path.join(sh, "art_mods_oldnew.png")
    out.save(dst)
    print("→ %s  (왼쪽 옛 · 오른쪽 새, 아래 판은 위 두 줄 새 · 아래 두 줄 옛)" % dst)
    return 0


def main():
    if "--oldnew" in sys.argv:
        return oldnew()
    src = sys.argv[1] if len(sys.argv) > 1 else M.MODS
    dst = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, "shots", "mod_try.png")
    cards = M.read_mods(src)
    ids = [r["id"] for r in M.mod_rows() if r["id"] in cards]
    ims = {}
    for mid in ids:
        nm, rim, pal, g = cards[mid]
        warn = []
        off = P.off_palette(pal)
        bad = [i for i, r in enumerate(g) if len(r) != 36]
        ims[mid] = M.draw_mod(mid, rim, pal, g, warn)
        print("%-5s %s · 색 %d%s%s%s" % (
            mid, nm, len(pal),
            "" if not off else "  ← 팔레트 밖: " + " ".join(off),
            "" if not bad else "  ← 줄 길이: %s" % bad[:5],
            "" if not warn else "  ← " + " ".join(warn)))
    Z = 8
    cell = 36 * Z + 12
    W = cell * 6
    H = cell * 2 + 104 + 12 + 60 + 44 + 110 + 70 + 40
    sheet = Image.new("RGB", (W, H), BG)
    for k, mid in enumerate(ids):
        big = ims[mid].crop((0, 0, 36, 36)).resize((36 * Z, 36 * Z), Image.NEAREST)
        sheet.paste(big, (6 + (k % 6) * cell, 6 + (k // 6) * cell), big)
    step = W // 12
    y = cell * 2 + 6
    #  컬렉션 크기를 두 배로 — 눈으로 보는 줄
    for k, mid in enumerate(ids):
        c2 = ims[mid].crop((0, 0, 36, 36)).resize((104, 104), Image.NEAREST)
        sheet.paste(c2, (k * step + (step - 104) // 2, y), c2)
    y += 104 + 12
    #  게임 크기(물리 픽셀) — 컬렉션 · 앞치마 52px
    for k, mid in enumerate(ids):
        c52 = ims[mid].crop((0, 0, 36, 36)).resize((52, 52), Image.NEAREST)
        sheet.paste(c52, (k * step + (step - 52) // 2, y), c52)
    y += 60
    #  명판 36px
    for k, mid in enumerate(ids):
        c36 = ims[mid].crop((0, 0, 36, 36))
        sheet.paste(c36, (k * step + (step - 36) // 2, y), c36)
    y += 44
    #  상점 테이블 — 펠트에 누움
    felt = Image.new("RGBA", (W, 110), FELT + (255,))
    for k, mid in enumerate(ids):
        fl = flat(ims[mid], 88, 69)
        felt.alpha_composite(fl, (k * step + (step - 88) // 2, 16))
    sheet.paste(felt.convert("RGB"), (0, y))
    y += 110 + 8
    #  동전 몇 장을 같은 크기로
    for k, cid in enumerate(["c04", "c08", "c33", "l02", "u23", "r01", "c09", "c10"]):
        p = os.path.join(ROOT, "assets", "coin", cid + ".png")
        if not os.path.exists(p):
            continue
        co = Image.open(p).convert("RGBA").resize((52, 52), Image.NEAREST)
        sheet.paste(co, (k * step + (step - 52) // 2, y), co)
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    sheet.save(dst)
    print("→ %s" % dst)


if __name__ == "__main__":
    main()
