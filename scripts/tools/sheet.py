#!/usr/bin/env python3
# -*- coding: utf-8 -*-
u"""표 — data/*.csv 를 엑셀 한 권으로 내고, 고친 것을 도로 넣는다.

    python scripts/tools/sheet.py out        표를 낸다
    python scripts/tools/sheet.py in         고친 것을 CSV 로 되넣는다
    python scripts/tools/sheet.py in --dry   안 쓰고 무엇이 바뀌는지만 본다
    python scripts/tools/sheet.py check      왕복이 무손실인지 잰다(파일 안 건드림)

CSV 가 원본이고 엑셀은 렌즈다. 표를 깃에 안 들이는 까닭이 그것이다 —
기록은 data/*.csv 에 남고, 엑셀은 그것을 보기 좋게 편 한 장일 뿐이다.

되넣기가 지켜야 하는 것
  · 값이 안 바뀐 칸은 **글자까지 그대로** 둔다. 0.10 을 0.1 로 고쳐 놓으면
    안 건드린 줄까지 깃 diff 에 떠서 무엇을 고쳤는지 안 보인다.
  · 파일마다 BOM·줄끝(CRLF/LF)이 다르다. 있던 대로 되쓴다.
  · 쉼표·따옴표가 든 칸은 따옴표로 싼다. 안 싸면 로더가 열을 민다
    (data.gd:236 이 그 오류를 뱉는다).
  · 엑셀이 글을 날짜로 먹은 칸은 **쓰지 않고 멈춘다**. 조용히 넣으면
    "sec:4,10" 이 1904년이 되어 표에 앉는다.

표 목록은 data.gd 의 FILES 에서 읽는다. 표를 새로 늘리면 여기 손 안 대도
다음 out 에 시트가 선다 — 반대로 설명이 없는 표는 소리를 낸다.

make_item_xlsx.py 와 헷갈리지 마라. 그것은 **문서**다 — 동전 한 장을
기획서 꼴로 펴 보이고 id 를 다시 매기며, 되넣는 길이 없다. 이쪽은
**조종간**이라 고친 것이 CSV 로 돌아간다.
"""
import csv
import datetime
import io
import os
import re
import sys

import openpyxl
from openpyxl.styles import Alignment, Border, Font, PatternFill, Side
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.datavalidation import DataValidation

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except AttributeError:
        pass

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(ROOT, "data")
OUT = os.path.join(ROOT, "shots", "표", "하이톤.xlsx")

#  표가 무엇인가 — 한 줄. 수치는 안 적는다(줄 수는 낼 때 센다).
#  FILES 에 있는데 여기 없으면 out 이 멈춘다. 새 표가 조용히 빠지는 것을
#  막는 자리라 일부러 빡빡하게 둔다.
ABOUT = {
    "items": ("동전", "경제"),
    "cons": ("사탕", "경제"),
    "packs": ("팩", "경제"),
    "boosters": ("부스터", "경제"),
    "shop": ("상점 뽑기", "경제"),
    "tuning": ("스칼라", "고리"),
    "rounds": ("라운드 곡선", "고리"),
    "legs": ("판", "고리"),
    "leagues": ("리그", "고리"),
    "chal": ("도전", "고리"),
    "mods": ("보드 확장", "판"),
    "modifiers": ("제약", "판"),
    "darts": ("다트", "판"),
    "areas": ("영역", "판"),
    "area_up": ("영역 강화", "판"),
    "colors": ("칸 색", "판"),
    "rarity": ("등급", "붙이"),
    "tags": ("태그", "붙이"),
    "tutor": ("배움", "붙이"),
}
TAB = {"경제": "FF217346", "고리": "FF1F4E79",
       "판": "FF7F3F00", "붙이": "FF5B2C6F"}

HEAD_BG = "FF217346"
OFF_BG = "FFF2F2F2"
NOTE_FG = "FF808080"
THIN = Side(style="thin", color="FFBFBFBF")
BOX = Border(left=THIN, right=THIN, top=THIN, bottom=THIN)
F8 = Font(name="맑은 고딕", size=8, color=NOTE_FG)
F10 = Font(name="맑은 고딕", size=10)
F10N = Font(name="맑은 고딕", size=10, color=NOTE_FG)

MEAN_ROW = 1        # 열이 무엇인가 — 값에서 뽑는다
HEAD_ROW = 2        # CSV 머리와 **글자까지 같다**. 되읽을 때 여기를 찾는다
DATA_ROW = 3
WIDE_COLS = ("_note", "desc", "text", "_src_hash")
MAX_W, MIN_W = 60, 6
DROP_MAX = 12       # 다른 값이 이보다 많으면 고르는 목록을 안 단다


# ── CSV 를 있는 그대로 ────────────────────────────────────────
class Table(object):
    """한 장. 디스크에 있던 모양(BOM·줄끝)을 같이 들고 다닌다."""

    def __init__(self, key, path):
        self.key = key
        self.path = path
        raw = io.open(path, "rb").read()
        self.bom = raw[:3] == b"\xef\xbb\xbf"
        self.nl = "\r\n" if b"\r\n" in raw else "\n"
        text = io.open(path, encoding="utf-8-sig", newline="").read()
        rows = list(csv.reader(io.StringIO(text)))
        self.head = [c.strip() for c in rows[0]]
        self.rows = [r for r in rows[1:] if r and r[0].strip() != ""]
        #  ── 있던 줄을 글자 그대로 쥔다 ───────────────────────────
        #  안 건드린 줄은 **다시 안 짠다**. 이 표에는 쉼표가 없는데도
        #  따옴표로 싸인 칸이 있고(sector_max·track_mult), 다시 짜면 그
        #  따옴표가 벗겨져 고치지도 않은 줄이 깃 diff 에 뜬다 — 한 칸
        #  고친 자리가 다섯 줄에 묻힌다.
        #  줄 안에 줄바꿈이 있으면 물리적 줄과 레코드가 어긋난다. 그때는
        #  쥐기를 통째로 접고 전부 다시 짠다(맞게는 나오고 따옴표만 바뀐다).
        recs = [x for x in re.split(r"\r\n|\r|\n", text) if x.strip() != ""]
        self.raw = recs[1:] if len(recs) == len(self.rows) + 1 else None
        self.raw_head = recs[0] if self.raw is not None else None
        #  줄을 무엇으로 짚는가. 첫 열이 대개 id 지만 **늘 그렇지는 않다** —
        #  tutor 는 한 id 에 걸음이 여럿이라 id 만으로 짚으면 열아홉 줄이
        #  열두 줄로 뭉개진다. 겹치지 않을 때까지 앞에서부터 열을 더 쥔다.
        self.kn = 1
        while self.kn < len(self.head):
            ks = [self.rk(r) for r in self.rows]
            if len(set(ks)) == len(ks):
                break
            self.kn += 1

    def rk(self, r):
        return tuple(c.strip() for c in r[:self.kn])

    @property
    def name(self):
        return os.path.basename(self.path)

    def col(self, j):
        return [r[j] if j < len(r) else "" for r in self.rows]

    def write(self, rows):
        was = {}
        for i, r in enumerate(self.rows):
            was.setdefault(self.rk(r), (i, r))
        out = [self.raw_head if self.raw is not None else self._fmt(self.head)]
        for r in rows:
            hit = was.get(self.rk(r))
            if self.raw is not None and hit is not None and hit[1] == r:
                out.append(self.raw[hit[0]])     # 안 바뀐 줄 — 있던 글자 그대로
            else:
                out.append(self._fmt(r))
        s = self.nl.join(out) + self.nl
        if self.bom:
            s = "﻿" + s
        io.open(self.path, "w", encoding="utf-8", newline="").write(s)

    @staticmethod
    def _fmt(row):
        buf = io.StringIO()
        csv.writer(buf, lineterminator="").writerow(row)
        return buf.getvalue()


def tables():
    """표 목록은 data.gd 의 FILES 하나에서만 온다. 여기 또 적으면 출처가 둘이다."""
    src = io.open(os.path.join(ROOT, "scripts", "data.gd"), encoding="utf-8").read()
    m = re.search(r"const FILES := \{(.*?)\n\}", src, re.S)
    if not m:
        sys.exit("data.gd 에서 FILES 를 못 찾았다")
    out = []
    for k, v in re.findall(r'"([^"]+)"\s*:\s*"([^"]+)"', m.group(1)):
        out.append(Table(k, os.path.join(DATA, v)))
    miss = [t.key for t in out if t.key not in ABOUT]
    if miss:
        sys.exit("표에 설명이 없다: %s — sheet.py 의 ABOUT 에 한 줄 적어라"
                 % ", ".join(miss))
    return out


# ── 값 재기 ──────────────────────────────────────────────────
def as_num(s):
    """숫자로 읽히면 (int|float), 아니면 None. 빈 칸도 None 이다."""
    s = s.strip()
    if s == "":
        return None
    try:
        return int(s)
    except ValueError:
        pass
    try:
        f = float(s)
    except ValueError:
        return None
    if f != f or f in (float("inf"), float("-inf")):
        return None
    return f


def kind_of(vals):
    """이 열이 무슨 열인가 — 'int' | 'float' | 'text'."""
    got = [v for v in vals if v.strip() != ""]
    if not got:
        return "text"
    nums = [as_num(v) for v in got]
    if any(n is None for n in nums):
        return "text"
    return "int" if all(isinstance(n, int) for n in nums) else "float"


def mean_of(name, vals):
    """열 뜻 한 줄. 손으로 안 짓고 **값에서 뽑는다** — 그래야 안 상한다."""
    got = [v for v in vals if v.strip() != ""]
    blank = len(vals) - len(got)
    tail = " · 빈칸 %d" % blank if blank else ""
    if name.startswith("_"):
        return "사람이 읽는 칸 — 게임이 안 읽는다" + tail
    if not got:
        return "빈 열" + tail
    k = kind_of(vals)
    if k in ("int", "float"):
        ns = [as_num(v) for v in got]
        lo, hi = min(ns), max(ns)
        fmt = "%d" if k == "int" else "%g"
        nm = "정수" if k == "int" else "실수"
        if lo == hi:
            return ("%s · 모두 " + fmt) % (nm, lo) + tail
        return ("%s " + fmt + " ~ " + fmt) % (nm, lo, hi) + tail
    seen = []
    for v in got:
        if v not in seen:
            seen.append(v)
    if len(seen) <= 6:
        return " · ".join(seen) + tail
    return "글 %d종" % len(seen) + tail


def picks(vals):
    """고르는 목록에 걸 값들. 글 열이고 가짓수가 적을 때만."""
    got = [v.strip() for v in vals if v.strip() != ""]
    if not got or kind_of(vals) != "text":
        return None
    seen = []
    for v in got:
        if v not in seen:
            seen.append(v)
    if len(seen) > DROP_MAX or len(seen) < 2:
        return None
    #  엑셀은 목록을 한 글자열에 쉼표로 이어 담는다. 값에 쉼표가 있으면
    #  그 자리에서 갈라져 없는 값이 둘 생긴다 — 그럴 땐 목록을 안 단다.
    if any("," in v or '"' in v or len(v) > 24 for v in seen):
        return None
    return seen


# ── 내기 ─────────────────────────────────────────────────────
def head_cell(ws, row, col, text, bg=HEAD_BG):
    c = ws.cell(row, col, text)
    c.font = Font(name="맑은 고딕", size=10, bold=True, color="FFFFFFFF")
    c.fill = PatternFill("solid", start_color=bg)
    c.alignment = Alignment(horizontal="center")
    c.border = BOX
    return c


def build_sheet(ws, t):
    head, nrow = t.head, len(t.rows)
    en = head.index("enabled") if "enabled" in head else -1

    for j, nm in enumerate(head, start=1):
        vals = t.col(j - 1)
        k = kind_of(vals)
        c = ws.cell(MEAN_ROW, j, mean_of(nm, vals))
        c.font = F8
        c.alignment = Alignment(wrap_text=True, vertical="top")
        head_cell(ws, HEAD_ROW, j, nm)

        w = max([len(nm) * 1.4] + [len(v) * (1.1 if v.isascii() else 1.9)
                                   for v in vals[:200]] + [MIN_W])
        ws.column_dimensions[get_column_letter(j)].width = min(
            MAX_W if nm in WIDE_COLS else 24, max(MIN_W, w))

        for i, r in enumerate(t.rows):
            v = r[j - 1] if j - 1 < len(r) else ""
            n = as_num(v) if k in ("int", "float") else None
            c = ws.cell(DATA_ROW + i, j, n if n is not None else (v or None))
            c.border = BOX
            if nm in WIDE_COLS or nm.startswith("_"):
                c.font = F10N
                c.alignment = Alignment(wrap_text=True, vertical="top")
            else:
                c.font = F10
                c.alignment = Alignment(
                    horizontal="center" if k != "text" else "left")
            if k == "text":
                #  글 열은 '@' 로 잠근다. 안 잠그면 엑셀이 "3-1" 을 날짜로 먹는다
                c.number_format = "@"
            if en >= 0 and (r[en] if en < len(r) else "") == "0":
                c.fill = PatternFill("solid", start_color=OFF_BG)

        p = picks(vals)
        if p and nrow:
            dv = DataValidation(
                type="list", formula1='"%s"' % ",".join(p),
                allow_blank=True, errorStyle="warning", errorTitle="처음 보는 값",
                error="지금 표에 없는 값이다. 새 값이면 그대로 둬도 된다 — "
                      "검증기(validate.gd)가 진짜 문이다")
            ws.add_data_validation(dv)
            dv.add("%s%d:%s%d" % (get_column_letter(j), DATA_ROW,
                                  get_column_letter(j), DATA_ROW + nrow - 1))

    #  tuning 은 표 안에 min·max 를 들고 있다 — 그 두 칸을 그대로 문으로 쓴다.
    #  범위를 파이썬에 옮겨 적지 않는 까닭이다. 표가 바뀌면 문도 같이 바뀐다.
    if "min" in head and "max" in head and "value" in head and nrow:
        v = get_column_letter(head.index("value") + 1)
        lo = get_column_letter(head.index("min") + 1)
        hi = get_column_letter(head.index("max") + 1)
        dv = DataValidation(
            type="decimal", operator="between",
            formula1="%s%d" % (lo, DATA_ROW), formula2="%s%d" % (hi, DATA_ROW),
            errorStyle="warning", errorTitle="표가 적어 둔 범위 밖",
            error="같은 줄의 min·max 밖이다. 넓혀야 하면 그 두 칸을 같이 고쳐라")
        ws.add_data_validation(dv)
        dv.add("%s%d:%s%d" % (v, DATA_ROW, v, DATA_ROW + nrow - 1))

    ws.row_dimensions[MEAN_ROW].height = 30
    ws.freeze_panes = "B%d" % DATA_ROW
    if nrow:
        ws.auto_filter.ref = "A%d:%s%d" % (
            HEAD_ROW, get_column_letter(len(head)), DATA_ROW + nrow - 1)
    ws.sheet_properties.tabColor = TAB[ABOUT[t.key][1]]


def build_toc(ws, ts):
    for col, w in (("A", 14), ("B", 20), ("C", 8), ("D", 8), ("E", 22), ("F", 64)):
        ws.column_dimensions[col].width = w
    lines = [
        "고치고 저장한 뒤 —  python scripts/tools/sheet.py in",
        "되돌리려면 —  git checkout -- data/",
        "값이 맞는지 —  godot --headless --path . --script scripts/tools/validate.gd",
        "",
        "원본은 data/*.csv 다. 이 표는 렌즈라 깃에 안 들어간다 —"
        " 고친 것은 in 으로 넣어야 남는다.",
        "1행은 값에서 뽑은 열 뜻이고 2행이 CSV 머리다. 2행은 고치지 마라 —"
        " 되넣기가 그 줄로 열을 찾는다.",
        "회색 줄은 enabled 0 — 게임에 안 나오는 줄이다.",
    ]
    for i, s in enumerate(lines, start=1):
        c = ws.cell(i, 1, s)
        c.font = Font(name="맑은 고딕", size=10, bold=(i <= 3),
                      color=None if i <= 3 else NOTE_FG)
    r = len(lines) + 2
    for j, s in enumerate(("시트", "무엇", "줄", "열", "파일", "첫 줄"), start=1):
        head_cell(ws, r, j, s)
    for i, t in enumerate(ts, start=1):
        first = t.rows[0][1] if t.rows and len(t.rows[0]) > 1 else ""
        for j, v in enumerate((t.key, ABOUT[t.key][0], len(t.rows),
                               len(t.head), t.name, first), start=1):
            c = ws.cell(r + i, j, v)
            c.font = F10 if j <= 4 else F10N
            c.border = BOX
    ws.freeze_panes = "A%d" % (r + 1)


def cmd_out(ts):
    if os.path.exists(OUT):
        try:
            io.open(OUT, "r+b").close()
        except IOError:
            sys.exit("표가 엑셀에 열려 있다. 닫고 다시 해라: %s" % OUT)
    wb = openpyxl.Workbook()
    build_toc(wb.active, ts)
    wb.active.title = "목차"
    for t in ts:
        build_sheet(wb.create_sheet(t.key), t)
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    wb.save(OUT)
    print("씀: %s" % OUT)
    print("  시트 %d장 · 줄 %d · 열 %d"
          % (len(ts), sum(len(t.rows) for t in ts), sum(len(t.head) for t in ts)))


# ── 되넣기 ───────────────────────────────────────────────────
def cell_str(v, where):
    """엑셀 칸 하나를 CSV 글자로. 날짜가 나오면 **멈춘다**."""
    if v is None:
        return ""
    if isinstance(v, bool):
        return "1" if v else "0"
    if isinstance(v, (datetime.datetime, datetime.date, datetime.time)):
        sys.exit("%s — 엑셀이 이 칸을 날짜로 먹었다(%s). 칸 서식을 '텍스트'로 "
                 "되돌리고 값을 다시 적어라. 그대로 넣으면 표가 망가진다"
                 % (where, v))
    if isinstance(v, int):
        return str(v)
    if isinstance(v, float):
        if v == int(v) and abs(v) < 1e15:
            return str(int(v))
        return ("%.10f" % v).rstrip("0").rstrip(".")
    return str(v).strip()


def read_sheet(ws, fws, t):
    """시트를 CSV 줄들로. 머리 줄을 글자로 맞춰 찾는다.
    ws 는 값이 든 판, fws 는 수식이 그대로 든 같은 판이다."""
    hr = 0
    for i in range(1, 6):
        got = [cell_str(ws.cell(i, j + 1).value, "").strip()
               for j in range(len(t.head))]
        if got == t.head:
            hr = i
            break
    if hr == 0:
        sys.exit("%s 시트의 머리 줄을 못 찾았다. %d행이 CSV 머리와 같아야 한다 "
                 "(%s ...)" % (t.key, HEAD_ROW, ", ".join(t.head[:3])))
    out = []
    for i in range(hr + 1, ws.max_row + 1):
        row = []
        for j in range(len(t.head)):
            at = "%s!%s%d" % (t.key, get_column_letter(j + 1), i)
            v = ws.cell(i, j + 1).value
            #  수식은 엑셀이 계산해 둔 값으로만 읽힌다. 계산값이 없으면 빈
            #  칸으로 보이는데, 그대로 넣으면 값이 **조용히 지워진다**.
            #  엑셀에서 한 번 열어 저장하면 계산값이 박힌다.
            f = fws.cell(i, j + 1).value
            if v is None and isinstance(f, str) and f.startswith("="):
                sys.exit("%s — 수식(%s)인데 계산값이 없다. 엑셀에서 열어 저장한 "
                         "뒤 다시 하거나, 값을 직접 적어라" % (at, f[:40]))
            row.append(cell_str(v, at))
        if row[0].strip() == "":
            continue
        out.append(row)
    return out


def keep_shape(t, rows):
    """값이 같은 칸은 **있던 글자 그대로** 둔다. 0.10 이 0.1 로 바뀌면
    안 고친 줄까지 diff 에 떠서 무엇을 고쳤는지 안 보인다."""
    old = {}
    for r in t.rows:
        old[t.rk(r)] = r
    for i, r in enumerate(rows):
        o = old.get(t.rk(r))
        if o is None and i < len(t.rows):
            o = t.rows[i]          # 열쇠를 고친 줄 — 자리로 짚는다
        if o is None:
            continue
        for j in range(len(r)):
            if j >= len(o) or r[j] == o[j]:
                continue
            a, b = as_num(o[j]), as_num(r[j])
            if a is not None and b is not None and float(a) == float(b):
                r[j] = o[j]
    return rows


def diff(t, rows):
    """무엇이 바뀌었나 — 줄 기준으로 사람이 읽게."""
    out = []
    oid = [t.rk(r) for r in t.rows]
    nid = [t.rk(r) for r in rows]
    for k in oid:
        if k not in nid:
            out.append("%s 줄 지움" % ":".join(k))
    for k in nid:
        if k not in oid:
            out.append("%s 줄 새로" % ":".join(k))
    om = {t.rk(r): r for r in t.rows}
    for r in rows:
        o = om.get(t.rk(r))
        if o is None:
            continue
        for j, nm in enumerate(t.head):
            a = o[j] if j < len(o) else ""
            b = r[j] if j < len(r) else ""
            if a != b:
                out.append("%s.%s %s→%s" % (":".join(t.rk(r)), nm,
                                            a or "빈칸", b or "빈칸"))
    return out


def cmd_in(ts, dry):
    if not os.path.exists(OUT):
        sys.exit("표가 없다. 먼저 out 을 해라: %s" % OUT)
    wb = openpyxl.load_workbook(OUT, data_only=True)
    fwb = openpyxl.load_workbook(OUT, data_only=False)
    hit = 0
    for t in ts:
        if t.key not in wb.sheetnames:
            print("  %-10s 시트가 없다 — 건너뛴다" % t.key)
            continue
        rows = keep_shape(t, read_sheet(wb[t.key], fwb[t.key], t))
        ch = diff(t, rows)
        if not ch:
            continue
        hit += 1
        more = " 외 %d" % (len(ch) - 6) if len(ch) > 6 else ""
        print("  %s — %s%s" % (t.name, "; ".join(ch[:6]), more))
        if not dry:
            t.write(rows)
    if hit == 0:
        print("  바뀐 것이 없다")
    elif dry:
        print("\n안 썼다(--dry). 넣으려면 --dry 를 빼라")
    else:
        print("\n표 %d장을 되썼다. 값이 맞는지 보려면:" % hit)
        print("  godot --headless --path . --script scripts/tools/validate.gd")
        print("  (되돌리기: git checkout -- data/)")
    return hit


def cmd_check(ts):
    """왕복이 무손실인가. 파일은 안 건드리고 메모리에서만 맞춰 본다."""
    import tempfile
    tmp = os.path.join(tempfile.gettempdir(), "_sheet_check.xlsx")
    wb = openpyxl.Workbook()
    build_toc(wb.active, ts)
    wb.active.title = "목차"
    for t in ts:
        build_sheet(wb.create_sheet(t.key), t)
    wb.save(tmp)
    wb = openpyxl.load_workbook(tmp, data_only=True)
    bad = 0
    for t in ts:
        rows = keep_shape(t, read_sheet(wb[t.key], wb[t.key], t))
        d = diff(t, rows)
        if rows != t.rows or d:
            bad += 1
            print("  실패 %-10s %s" % (t.key, "; ".join(d[:4]) or "줄 수가 다르다"))
        else:
            print("  통과 %-10s %d줄 · %d열" % (t.key, len(rows), len(t.head)))
    os.remove(tmp)
    print("\n왕복 통과 %d · 실패 %d" % (len(ts) - bad, bad))
    return bad


def main():
    a = sys.argv[1:] or ["out"]
    ts = tables()
    if a[0] == "out":
        cmd_out(ts)
    elif a[0] == "in":
        cmd_in(ts, "--dry" in a)
    elif a[0] == "check":
        sys.exit(1 if cmd_check(ts) else 0)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
