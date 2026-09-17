# 시계 판 견줌 장 — shot_board_clock.gd 가 찍은 것을 판만 잘라 한 장에 늘어놓는다.
#   python scripts/tools/sheet_board_clock.py [새 접두=ck_] [옛 접두=ck_old_] [그 사이 접두 …]
# 줄마다 접두 하나(옛 판 → 사이 판 → 새 판 차례, 같은 장면끼리 세로로 짝), 끝에 새 판 기본을
# 두 배로 한 장. 옛 접두에 없는 장면(죽은 크림 · 실띠 · 넓은 판)은 칸이 빈다.
# 게임 한 배 크기(판 250px)로 줄인 줄 장도 같이 떨군다 — 한눈에 시계로 읽히는지는 그 크기에서 본다.
import sys
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SHOTS = ROOT / "shots"
new = sys.argv[1] if len(sys.argv) > 1 else "ck_"
old = sys.argv[2] if len(sys.argv) > 2 else "ck_old_"
mid = sys.argv[3:]
names = ["plain", "paint", "aim_trp", "aim_dbl", "aim_sgl", "aim_bull", "dead_col", "dead_idx", "dead_aim",
         "dead_cream", "band_05", "band_15"]
cx, cy, h = 640, 392, 250          # 판 한가운데(BC 320,196 의 두 배)와 반 폭
box = (cx - h, cy - h, cx + h, cy + h)
cell = 2 * h
rows = [old] + mid + [new]
sheet = Image.new("RGB", (cell * len(names), cell * len(rows)), (20, 17, 31))
small = Image.new("RGB", (250 * len(names), 250 * len(rows)), (20, 17, 31))
d = ImageDraw.Draw(sheet)
for ri, pre in enumerate(rows):
    for ci, nm in enumerate(names):
        p = SHOTS / f"{pre}{nm}.png"
        if not p.exists():
            continue
        im = Image.open(p).convert("RGB").crop(box)
        sheet.paste(im, (ci * cell, ri * cell))
        small.paste(im.resize((250, 250), Image.LANCZOS), (ci * 250, ri * 250))
        d.text((ci * cell + 6, ri * cell + 4), f"{pre}{nm}", fill=(255, 220, 120))
sheet.save(SHOTS / f"{new}sheet.png")
small.save(SHOTS / f"{new}sheet_1x.png")
big = Image.open(SHOTS / f"{new}plain.png").convert("RGB").crop(box)
big.resize((cell * 2, cell * 2), Image.NEAREST).save(SHOTS / f"{new}plain_x2.png")
print("sheet", SHOTS / f"{new}sheet.png")
