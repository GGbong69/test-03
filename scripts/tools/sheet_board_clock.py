# 시계 판 견줌 장 — shot_board_clock.gd 가 찍은 것을 판만 잘라 한 장에 늘어놓는다.
#   python scripts/tools/sheet_board_clock.py [새 접두=ck_] [옛 접두=ck_old_]
# 윗줄은 옛 판 · 아랫줄은 새 판(같은 장면끼리 세로로 짝), 끝에 새 판 기본을 두 배로 한 장.
import sys
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SHOTS = ROOT / "shots"
new = sys.argv[1] if len(sys.argv) > 1 else "ck_"
old = sys.argv[2] if len(sys.argv) > 2 else "ck_old_"
names = ["plain", "paint", "aim_trp", "aim_dbl", "aim_sgl", "aim_bull", "dead_col", "dead_idx", "dead_aim"]
cx, cy, h = 640, 392, 250          # 판 한가운데(BC 320,196 의 두 배)와 반 폭
box = (cx - h, cy - h, cx + h, cy + h)
cell = 2 * h
rows = [old, new]
sheet = Image.new("RGB", (cell * len(names), cell * len(rows)), (20, 17, 31))
d = ImageDraw.Draw(sheet)
for ri, pre in enumerate(rows):
    for ci, nm in enumerate(names):
        p = SHOTS / f"{pre}{nm}.png"
        if not p.exists():
            continue
        sheet.paste(Image.open(p).convert("RGB").crop(box), (ci * cell, ri * cell))
        d.text((ci * cell + 6, ri * cell + 4), f"{pre}{nm}", fill=(255, 220, 120))
sheet.save(SHOTS / f"{new}sheet.png")
big = Image.open(SHOTS / f"{new}plain.png").convert("RGB").crop(box)
big.resize((cell * 2, cell * 2), Image.NEAREST).save(SHOTS / f"{new}plain_x2.png")
print("sheet", SHOTS / f"{new}sheet.png")
