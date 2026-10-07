"""게임 그림 낱장 자르기 — shot_assets.gd 가 찍은 판을 투명 PNG 낱장으로 (2026-10-07).

「게임 내에 상점 주인의 그 달라는 손 동작 이미지랑 동전들 이미지 좀 줘볼래?」

    python scripts/tools/poster/cut_assets.py

outputs/poster/assets/raw/ 를 읽어 outputs/poster/assets/ 에:
  동전/NN_<id>_<이름>.png   동전 하나씩(투명 · 동전 슬롯 그림 그대로 · 16배)
  동전_전체.png              한 판에 이름과 함께(어두운 바탕)
  손/달라는손_<왼|오른>손.png     내미는 손 하나만(투명)
  손/달라는손_양손_<왼|오른>손내밈.png  두 팔 다(투명 · 게임 자리 그대로)
  손/상점_<왼|오른>손내밈.png     HUD 없는 상점 한 장
"""
import csv
import json
import os
import re

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
RAW = os.path.join(ROOT, "outputs", "poster", "assets", "raw")
OUT = os.path.join(ROOT, "outputs", "poster", "assets")
FONT = os.path.join(ROOT, "fonts", "Paperlogy-6SemiBold.ttf")
PAD = 8


def _crop_alpha(im: Image.Image, pad: int = PAD) -> Image.Image:
    bb = im.getchannel("A").getbbox()
    if bb is None:
        return im
    return im.crop((max(bb[0] - pad, 0), max(bb[1] - pad, 0),
                    min(bb[2] + pad, im.width), min(bb[3] + pad, im.height)))


def _safe(s: str) -> str:
    return re.sub(r'[\\/:*?"<>|]', "_", s).strip() or "_"


def coins() -> None:
    names = {r["id"]: r["name"] for r in csv.DictReader(
        open(os.path.join(ROOT, "data", "items.csv"), encoding="utf-8-sig"))}
    meta = json.load(open(os.path.join(RAW, "coins.json"), encoding="utf-8"))
    sheet = Image.open(os.path.join(RAW, "coins_sheet.png")).convert("RGBA")
    k = float(meta["k"])
    half = int(round(float(meta["cell"]) * k * 0.5))
    d = os.path.join(OUT, "동전")
    os.makedirs(d, exist_ok=True)
    for fn in os.listdir(d):
        if fn.endswith(".png"):
            os.remove(os.path.join(d, fn))
    tiles = []
    for c in meta["coins"]:
        cx, cy = int(round(float(c["x"]) * k)), int(round(float(c["y"]) * k))
        cell = sheet.crop((cx - half, cy - half, cx + half, cy + half))
        coin = _crop_alpha(cell)
        nm = names.get(c["id"], c["id"])
        coin.save(os.path.join(d, "%02d_%s_%s.png" % (c["i"] + 1, c["id"], _safe(nm))))
        tiles.append((c, nm, cell))
    #  한 판 — 칸마다 동전 · 그 밑에 번호 · 이름
    cols = 10
    tw = 360
    th = tw + 90
    rows = (len(tiles) + cols - 1) // cols
    board = Image.new("RGB", (cols * tw, rows * th), (30, 26, 40))
    dr = ImageDraw.Draw(board)
    f = ImageFont.truetype(FONT, 30)
    for n, (c, nm, cell) in enumerate(tiles):
        x, y = (n % cols) * tw, (n // cols) * th
        t = cell.resize((tw - 40, tw - 40), Image.LANCZOS)
        board.paste(t, (x + 20, y + 20), t)
        label = "%d. %s" % (c["i"] + 1, nm)
        w = dr.textlength(label, font=f)
        while w > tw - 16 and len(label) > 4:
            label = label[:-2] + "…"
            w = dr.textlength(label, font=f)
        dr.text((x + (tw - w) / 2, y + tw - 6), label, font=f, fill=(235, 228, 245))
    board.save(os.path.join(OUT, "동전_전체.png"))
    print("동전", len(tiles), "장")


def hands() -> None:
    d = os.path.join(OUT, "손")
    os.makedirs(d, exist_ok=True)
    for side, nm in ((0, "왼"), (1, "오른")):
        p = os.path.join(RAW, "reach_hand_%d.png" % side)
        if not os.path.exists(p):
            continue
        both = Image.open(p).convert("RGBA")
        _crop_alpha(both, 24).save(os.path.join(d, "달라는손_양손_%s손내밈.png" % nm))
        #  내민 쪽만 — 두 팔 사이 빈 세로 띠(알파가 없는 열)에서 가른다
        a = np.asarray(both.getchannel("A"))
        cols = np.nonzero(a.max(0) > 0)[0]
        gaps = np.nonzero(np.diff(cols) > 1)[0]
        mid = int((cols[gaps[0]] + cols[gaps[0] + 1]) // 2) if len(gaps) else both.width // 2
        one = both.crop((0, 0, mid, both.height)) if side == 0 else both.crop((mid, 0, both.width, both.height))
        _crop_alpha(one, 24).save(os.path.join(d, "달라는손_%s손.png" % nm))
        sc = os.path.join(RAW, "reach_scene_%d.png" % side)
        if os.path.exists(sc):
            Image.open(sc).convert("RGB").save(os.path.join(d, "상점_%s손내밈.png" % nm))
    print("손 끝")


if __name__ == "__main__":
    coins()
    hands()
