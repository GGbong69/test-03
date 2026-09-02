#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
HIGHTONE 지식 내보내기 — 게임에 들어 있는 모든 요소와 규칙을 한 뭉치로 뽑는다.

만드는 것 둘.
    docs/export/hightone_kb.json   기계가 읽는다. 표 전부 + 코드 상수 + 어휘 사전
    docs/export/hightone_kb.md     사람과 LLM 이 읽는다. 같은 내용을 문장과 표로

출처는 둘뿐이다.
    data/*.csv        수치. 한 칸도 손으로 안 적는다
    scripts/*.gd      표로 안 뺀 것 — 기하 · 술어 · 상태 · 조작 상수

숫자를 이 파일에 다시 적지 마라. 그 순간 출처가 셋이 된다.
쓰기:  python scripts/tools/export_kb.py
"""

from __future__ import annotations

import csv
import io
import json
import math
import os
import re
import sys
from datetime import date

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(ROOT, "data")
SCRIPTS = os.path.join(ROOT, "scripts")
# 저장소 규약이 LF 다(.gitattributes). 윈도우 기본 텍스트 모드로 쓰면 매번
# 전 줄이 바뀐 것으로 잡혀 내보낸 문서의 diff 를 아무도 못 읽는다.
LF = chr(10)
OUT = os.path.join(ROOT, "docs", "export")


# ══════════════════════════════════════════════════════════
#  CSV 읽기 — data.gd 의 _read 와 같은 규약
#    · 헤더 이름으로만 접근한다
#    · 밑줄로 시작하는 열은 사람이 읽는 주석이라 그대로 담는다
#    · 빈 칸은 "미정" 이다. None 으로 두어 0 과 안 섞는다
# ══════════════════════════════════════════════════════════
def read_csv(name: str) -> list[dict]:
    path = os.path.join(DATA, name + ".csv")
    with io.open(path, "r", encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))
    out = []
    for r in rows:
        if not any((v or "").strip() for v in r.values()):
            continue
        out.append({(k or "").strip(): ((v or "").strip() or None) for k, v in r.items()})
    return out


def num(v, dflt=None):
    if v is None or v == "":
        return dflt
    try:
        f = float(v)
    except ValueError:
        return v
    return int(f) if f == int(f) and "." not in str(v) else f


def typed(rows: list[dict], int_cols=(), float_cols=(), bool_cols=()) -> list[dict]:
    """표시는 문자열이지만 JSON 은 수로 나가야 한다. 열 이름으로만 캐스팅한다."""
    out = []
    for r in rows:
        d = {}
        for k, v in r.items():
            if v is None:
                d[k] = None
            elif k in bool_cols:
                d[k] = bool(int(v))
            elif k in int_cols:
                d[k] = int(float(v))
            elif k in float_cols:
                d[k] = float(v)
            else:
                d[k] = v
        out.append(d)
    return out


# ══════════════════════════════════════════════════════════
#  GDScript 상수 긁기 — 표로 안 뺀 것들
# ══════════════════════════════════════════════════════════
def src(rel: str) -> str:
    with io.open(os.path.join(SCRIPTS, rel), "r", encoding="utf-8") as f:
        return f.read()


def _span(text: str, start: int, op: str, cl: str) -> str:
    """여는 괄호에서 짝이 맞는 닫는 괄호까지."""
    depth, i = 0, start
    while i < len(text):
        if text[i] == op:
            depth += 1
        elif text[i] == cl:
            depth -= 1
            if depth == 0:
                return text[start : i + 1]
        i += 1
    return ""


def _strip_comments(s: str) -> str:
    return "\n".join(re.sub(r"(?<!\S)#.*$", "", ln) for ln in s.split("\n"))


def gd_array(text: str, name: str):
    m = re.search(r"const\s+%s\s*:=\s*\[" % re.escape(name), text)
    if not m:
        return None
    body = _strip_comments(_span(text, m.end() - 1, "[", "]"))[1:-1]
    return _parse_items(body)


def gd_dict(text: str, name: str):
    m = re.search(r"const\s+%s\s*:=\s*\{" % re.escape(name), text)
    if not m:
        return None
    body = _strip_comments(_span(text, m.end() - 1, "{", "}"))[1:-1]
    out = {}
    for k, v in _parse_pairs(body):
        out[k] = v
    return out


def _split_top(body: str) -> list[str]:
    parts, depth, cur = [], 0, ""
    for ch in body:
        if ch in "[{(":
            depth += 1
        elif ch in "]})":
            depth -= 1
        if ch == "," and depth == 0:
            parts.append(cur)
            cur = ""
        else:
            cur += ch
    if cur.strip():
        parts.append(cur)
    return [p.strip() for p in parts if p.strip()]


def _val(tok: str):
    tok = tok.strip()
    if tok.startswith('"') and tok.endswith('"'):
        return tok[1:-1]
    if tok.startswith("["):
        return _parse_items(tok[1:-1])
    if tok.startswith("{"):
        return {k: v for k, v in _parse_pairs(tok[1:-1])}
    m = re.match(r"Vector2\(([^)]*)\)", tok)
    if m:
        return [float(x) for x in m.group(1).split(",")]
    m = re.match(r'Color\("([^"]*)"\)', tok)
    if m:
        return "#" + m.group(1)
    try:
        return int(tok)
    except ValueError:
        pass
    try:
        return float(tok)
    except ValueError:
        return tok


def _parse_items(body: str) -> list:
    return [_val(t) for t in _split_top(body)]


def _parse_pairs(body: str):
    for part in _split_top(body):
        if ":" not in part:
            continue
        k, _, v = part.partition(":")
        yield _val(k), _val(v)


def gd_match(text: str, func: str) -> dict:
    """`match` 한 덩어리에서 "열쇠": return "말" 을 걷는다."""
    m = re.search(r"(static\s+)?func\s+%s\s*\(" % re.escape(func), text)
    if not m:
        return {}
    tail = text[m.end() :]
    stop = re.search(r"\n(static\s+)?func\s", tail)
    body = tail[: stop.start()] if stop else tail
    out = {}
    for mm in re.finditer(r'^\s*"([^"]+)":\s*return\s+"([^"]*)"', body, re.M):
        out[mm.group(1)] = mm.group(2)
    for mm in re.finditer(r'^\s*"([^"]+)":\s*return\s+"([^"]*)"\s*%', body, re.M):
        out[mm.group(1)] = mm.group(2)
    return out


def gd_enum(text: str, name: str) -> list[str]:
    m = re.search(r"enum\s+%s\s*\{" % re.escape(name), text)
    if not m:
        return []
    body = _strip_comments(_span(text, m.end() - 1, "{", "}"))[1:-1]
    return [t.strip() for t in body.replace("\n", " ").split(",") if t.strip()]


def gd_colors(text: str) -> dict:
    return {
        m.group(1): "#" + m.group(2)
        for m in re.finditer(r'const\s+(C_[A-Z_]+)\s*:=\s*Color\("([0-9a-fA-F]{6})"\)', text)
    }


# ══════════════════════════════════════════════════════════
#  표 읽기
# ══════════════════════════════════════════════════════════
ITEMS = typed(read_csv("items"),
              int_cols=("value", "cost", "gv", "v2", "gstep", "dadd", "min_round"),
              float_cols=("weight",), bool_cols=("enabled",))
RARITY = typed(read_csv("rarity"), int_cols=("min_round",), float_cols=("weight",))
MODS = typed(read_csv("mods"), int_cols=("cost",), float_cols=("v0", "v1"))
DARTS = typed(read_csv("darts"),
              int_cols=("mult", "cost"), float_cols=("gauge", "pierce_side", "magnet"),
              bool_cols=("fix1",))
MODIFIERS = typed(read_csv("modifiers"), float_cols=("v", "weight"))
ANTES = typed(read_csv("antes"),
              int_cols=("ante", "shop_items", "shop_mods", "shop_darts", "darts"),
              float_cols=("curve_a", "curve_b"))
BLINDS = typed(read_csv("blinds"), int_cols=("reward",), float_cols=("mult",),
               bool_cols=("skippable", "boss"))
AREAS = typed(read_csv("areas"), int_cols=("wb", "base", "mult", "track"))
AREA_UP = typed(read_csv("area_upgrades"),
                int_cols=("rec", "track", "level", "add_score", "add_mult"))
CONSUMABLES = typed(read_csv("consumables"), int_cols=("wb", "track", "cost"),
                    bool_cols=("enabled",))
PROCESSING = typed(read_csv("processing"), int_cols=("wb", "max_stack"), bool_cols=("enabled",))
PACKS = typed(read_csv("packs"),
              int_cols=("darts_add", "gold_add", "item_slots", "cons_slots",
                        "dart_gold", "interest_off", "unlock_v"),
              float_cols=("target_mul",))
STAKES = typed(read_csv("stakes"),
               int_cols=("reward_small", "seal_items", "darts_add", "interest_add",
                         "perish", "rent"),
               float_cols=("shop_cost_mul",))
TAGS = typed(read_csv("tags"), int_cols=("v", "min_ante"), float_cols=("weight",))
VOUCHERS = typed(read_csv("vouchers"), int_cols=("cost", "min_ante"),
                 float_cols=("v", "weight"))
COLORS = typed(read_csv("colors"), int_cols=("id",))
SPEC_MAP = read_csv("spec_map")
STATS_CSV = typed(read_csv("_stats"),
                  int_cols=("value", "cost", "samples", "seed"),
                  float_cols=("fire_pct", "gain_per_dart", "gain_per_round",
                              "gain_per_gold", "gold_per_round"))
TUNING = read_csv("tuning")

TUNE = {}
for r in TUNING:
    TUNE[r["key"]] = int(float(r["value"])) if r["type"] == "int" else float(r["value"])


# ══════════════════════════════════════════════════════════
#  코드 상수
# ══════════════════════════════════════════════════════════
D = src("data.gd")
G = src("game.gd")
S = src("save.gd")

CODE = {
    "board": {
        "SECTORS_BASE": gd_array(D, "SECTORS_BASE"),
        "BOARD_BASE": gd_dict(D, "BOARD_BASE"),
        "GEO": gd_dict(D, "GEO"),
        "VAL_W": gd_dict(D, "VAL_W"),
    },
    "vocab": {
        "RARITIES": gd_array(D, "RARITIES"),
        "CONDS": gd_array(D, "CONDS"),
        "COND_SUB": gd_dict(D, "COND_SUB"),
        "COND_PART": gd_array(D, "COND_PART"),
        "KINDS": gd_array(D, "KINDS"),
        "GOLDS": gd_array(D, "GOLDS"),
        "MOD_AXES": gd_array(D, "MOD_AXES"),
        "MODIFIER_AXES": gd_array(D, "MODIFIER_AXES"),
        "VOUCHER_KEYS": gd_dict(D, "VOUCHER_KEYS"),
        "VOUCHER_OPS": gd_array(D, "VOUCHER_OPS"),
        "PACK_KINDS": gd_array(D, "PACK_KINDS"),
        "AIM_MODES": gd_array(D, "AIM_MODES"),
        "AIM_STAGES": gd_dict(D, "AIM_STAGES"),
        "AIM_HINT": gd_dict(D, "AIM_HINT"),
        "SCORE_MODES": gd_array(D, "SCORE_MODES"),
        "TAG_WHEN": gd_array(D, "TAG_WHEN"),
        "TAG_KINDS": gd_array(D, "TAG_KINDS"),
    },
    "text": {
        "cond_tag": gd_match(D, "cond_tag"),
        "cond_text": gd_match(D, "cond_text"),
        "aim_name": gd_match(D, "aim_name"),
        "aim_text": gd_match(D, "aim_text"),
        "score_name": gd_match(D, "score_name"),
        "gold_tag": gd_match(D, "gold_tag"),
    },
    "feel": {
        "PULL": gd_dict(G, "PULL"),
        "KICK": gd_dict(G, "KICK"),
        "DRIFT": gd_dict(G, "DRIFT"),
        "PACE": gd_dict(G, "PACE"),
    },
    "screen": {
        "VIEW": gd_dict(G, "VIEW") or [640, 360],
        "BOARD_CENTER": _val(re.search(r"const BC := (Vector2\([^)]*\))", G).group(1)),
        "STATES": gd_enum(G, "S"),
        "PALETTE": gd_colors(G),
    },
    "save": {
        "STATS": gd_array(S, "STATS"),
        "PEAKS": gd_array(S, "PEAKS"),
        "PATH": re.search(r'const PATH := "([^"]+)"', S).group(1),
    },
}
CODE["screen"]["VIEW"] = _val(re.search(r"const VIEW := (Vector2\([^)]*\))", G).group(1))


# ══════════════════════════════════════════════════════════
#  효과 문장 — data.gd 의 eff_line / gold_text 를 그대로 옮긴다.
#  게임이 카드 얼굴에 찍는 문장과 같아야 표가 거짓말을 안 한다.
# ══════════════════════════════════════════════════════════
COND_TEXT = CODE["text"]["cond_text"]
COND_TAG = CODE["text"]["cond_tag"]
AIM_TEXT = dict(CODE["text"]["aim_text"])
AIM_TEXT["kick"] = ("한 발이 작은 다트 %d발이 되고 발마다 점수의 %d%%를 받으며, "
                    "쏠 때마다 조준이 밀립니다"
                    % (TUNE["kick_n"], round(TUNE["kick_share"] * 100)))
AIM_NAME = CODE["text"]["aim_name"]


def color_name(i: int) -> str:
    for c in COLORS:
        if c["id"] == i:
            return c["name"]
    return ""


def cond_text(c) -> str:
    if not c:
        return ""
    if c in COND_TEXT:
        return COND_TEXT[c]
    if c.startswith("sec:"):
        return c[4:].replace(",", "·") + "번 명중 시"
    if c.startswith("col:"):
        return "·".join(color_name(int(t)) for t in c[4:].split(",")) + " 칸 명중 시"
    return c


def eff_text(k, v) -> str:
    return {
        "chip": "점수 +%d" % (v or 0),
        "mult": "배수 +%d" % (v or 0),
        "xmult": "배수 ×%d" % (v or 0),
        "mult_streak": "배수 +%d" % (v or 0),
        "mult_rand": "배수 +0~%d 무작위" % (v or 0),
        "save": "실패 1회 방지 (총점이 목표의 %d%% 이상일 때)" % (v or 0),
    }.get(k, "")


PER_TEXT = {
    "darts_left": "남은 다트 1개당 ", "items": "보유 아이템 1개당 ",
    "gold": "보유 골드 1당 ", "gold5": "보유 골드 5당 ",
    "mag_hvy": "무거운 다트 1개당 ", "missing": "기본에서 줄어든 다트 1개당 ",
    "low": "라운드 최저 명중 숫자 1당 ", "zonehist": "이 영역의 런 누적 명중 1회당 ",
}


def eff_line(it: dict) -> str:
    if it.get("aim"):
        return AIM_TEXT.get(it["aim"], "")
    k, v = it.get("kind"), it.get("value")
    if not k:
        if it.get("dadd"):
            return "라운드 시작 다트 %+d" % it["dadd"]
        if it.get("side") == "trackup25":
            return "발동 4회 중 1회, 맞은 영역 강화 +1"
        return ""
    grow, gstep = it.get("grow"), it.get("gstep") or 0
    if grow == "hitmiss":
        return "명중마다 배수 +%d · 빗나가면 −%d" % (gstep, gstep)
    if grow == "fire":
        return "발동할 때마다 %s +%d 누적" % ("점수" if k == "chip" else "배수", gstep)
    if grow == "tdec":
        return "%s +%d 에서 시작 · 던질 때마다 −%d" % (
            "점수" if k == "chip" else "배수", v, gstep)
    if grow == "rdec":
        return "배수 +%d 에서 시작 · 라운드마다 −%d · 0이면 파괴" % (v, gstep)
    base = eff_text(k, v)
    per = it.get("per")
    if per in PER_TEXT:
        return PER_TEXT[per] + base
    if per == "rackval":
        return "다른 아이템 판매가 합계만큼 " + base.split(" ")[0] + " 추가"
    if per == "empty":
        return "배수 × 빈 아이템 칸 수 (최소 ×1)"
    if it.get("k2"):
        base += " · " + eff_text(it["k2"], it.get("v2"))
    if it.get("dadd"):
        base += " · 라운드 시작 다트 %+d" % it["dadd"]
    if it.get("side") == "trackup25":
        base += " · 4회 중 1회 영역 강화 +1"
    if it.get("boom") == "r6":
        base += " · 라운드마다 1/6 확률로 파괴"
    elif it.get("boom") == "r1000":
        base += " · 라운드마다 0.1% 확률로 파괴"
    return base


def gold_text(g, gv) -> str:
    return {
        "clear": "클리어 시 골드 +%d" % (gv or 0),
        "spare": "남은 다트 1개당 골드 +%d" % (gv or 0),
        "clean": "한 발도 안 빗나가면 골드 +%d" % (gv or 0),
        "blitz": "남은 다트 %d개 이상이면 골드 +%d" % (TUNE["gold_blitz"], gv or 0),
        "broke": "정산 때 보유 골드 %d 이하면 +%d" % (TUNE["gold_broke"], gv or 0),
        "round": "라운드마다 골드 +%d" % (gv or 0),
        "risk50": "더블·트리플·불 명중 시 절반 확률로 골드 +%d" % (gv or 0),
        "hit": "발동할 때마다 골드 +%d" % (gv or 0),
    }.get(g, "")


def sell_value(cost) -> int:
    return max(TUNE["sell_min"], (cost or 0) // TUNE["sell_div"])


def pack_desc(p: dict) -> str:
    """data.gd 의 pack_desc — 팩 설명은 총량과 증감을 둘 다 꽂는다.
    _d 는 절댓값이다. 방향은 낱말이 쥐므로 부호가 두 번 붙지 않게 한다."""
    tpl = p.get("desc")
    if not tpl:
        return ""
    isl = p["item_slots"] if p.get("item_slots") is not None else TUNE["max_items"]
    csl = p["cons_slots"] if p.get("cons_slots") is not None else TUNE["cons_slots"]
    da = p.get("darts_add") or 0
    ga = p.get("gold_add") or 0
    return desc_fill(tpl, {
        "darts": TUNE["darts_base"] + da,
        "gold": TUNE["start_gold"] + ga,
        "items": isl, "cons": csl,
        "dartgold": p["dart_gold"] if p.get("dart_gold") is not None else TUNE["gold_per_dart"],
        "darts_d": abs(da), "gold_d": abs(ga),
        "items_d": abs(isl - TUNE["max_items"]),
        "cons_d": abs(csl - TUNE["cons_slots"]),
    }, {})


def desc_fill(tpl, row, keys) -> str:
    """desc 열의 {v0} · {mult:+} 자리를 표 값으로 채운다 (data.gd 의 _fmt)."""
    if not tpl:
        return ""
    def sub(m):
        key, spec = m.group(1), m.group(2)
        v = row.get(keys.get(key, key))
        if v is None:
            return "미정"
        if isinstance(v, float) and v == int(v):
            v = int(v)
        return ("%+g" % v) if spec == "+" else ("%g" % v if isinstance(v, float) else str(v))
    return re.sub(r"\{(\w+)(?::(\+))?\}", sub, tpl)


# 측정 통계를 id 로 붙인다
STAT_BY_ID = {r["id"]: r for r in STATS_CSV}

RARITY_KO = {r["id"]: r["name"] for r in RARITY}
RARITY_W = {r["id"]: r for r in RARITY}


def item_weight(it):
    if it.get("weight") is not None:
        return it["weight"]
    return RARITY_W.get(it.get("rarity"), {}).get("weight", 1.0)


def item_min_round(it):
    if it.get("min_round") is not None:
        return it["min_round"]
    return RARITY_W.get(it.get("rarity"), {}).get("min_round", 1)


def item_cond(it: dict) -> str:
    """sec·col 조건은 숫자 집합을 `secs` 열에 따로 들고 있다.
    data.gd 의 items() 와 같이 "sec:4,10" 꼴로 굳혀야 판정 문장이 선다."""
    c = it.get("cond") or ""
    if c in ("sec", "col"):
        return c + ":" + (it.get("secs") or "").replace(";", ",")
    return c


def item_view(it: dict) -> dict:
    """카드 얼굴에 뜨는 모양 그대로. JSON 과 MD 가 같은 것을 읽는다."""
    st = STAT_BY_ID.get(it["id"], {})
    cnd = item_cond(it)
    return {
        "id": it["id"],
        "name": it["name"],
        "rarity": it.get("rarity"),
        "rarity_ko": RARITY_KO.get(it.get("rarity"), it.get("rarity")),
        "enabled": it.get("enabled"),
        "cond": cnd or None,
        "cond_ko": cond_text(cnd),
        "kind": it.get("kind"),
        "value": it.get("value"),
        "effect_ko": eff_line(it),
        "gold": it.get("gold"),
        "gold_ko": gold_text(it.get("gold"), it.get("gv")),
        "cost": it.get("cost"),
        "sell": sell_value(it.get("cost")),
        "weight": item_weight(it),
        "min_round": item_min_round(it),
        "per": it.get("per"),
        "grow": it.get("grow"),
        "gstep": it.get("gstep"),
        "boom": it.get("boom"),
        "dadd": it.get("dadd"),
        "side": it.get("side"),
        "aim": it.get("aim"),
        "k2": it.get("k2"),
        "v2": it.get("v2"),
        "tags": (it.get("_tags") or "").split(";") if it.get("_tags") else [],
        "note": it.get("_note"),
        "measured": {
            "fire_pct": st.get("fire_pct"),
            "gain_per_dart": st.get("gain_per_dart"),
            "gain_per_round": st.get("gain_per_round"),
            "gold_per_round": st.get("gold_per_round"),
        } if st else None,
    }


ITEM_VIEWS = [item_view(it) for it in ITEMS]
ON = [i for i in ITEM_VIEWS if i["enabled"]]
OFF = [i for i in ITEM_VIEWS if not i["enabled"]]


# ══════════════════════════════════════════════════════════
#  파생 — 라운드 표를 실제 목표로 펼친다
# ══════════════════════════════════════════════════════════
BLINDS_PER = len(BLINDS)
ROUNDS_N = len(ANTES) * BLINDS_PER


# 앤티 기본 목표. data.gd 의 ante_base 와 **같은 식**이다 — 표에서 열이
# 사라졌으므로 여기도 손잡이 셋을 읽어 다시 센다. 두 구현이 갈리면
# KB 의 목표가 게임의 목표와 달라지므로, 식을 바꿀 때는 둘을 같이 고친다.
def ante_base(a: int) -> float:
    n = len(ANTES)
    first = float(TUNE["curve_first"])
    last = float(TUNE["curve_last"])
    if n <= 1 or first <= 0 or last <= 0:
        return max(first, 1.0)
    a = min(max(a, 1), n)
    # 양 끝은 식을 안 태운다 — data.gd 의 ante_base 와 같은 이유, 같은 처방이다.
    if a == 1:
        return first
    if a == n:
        return last
    t = (a - 1) / (n - 1)
    k = (a - 1) * (n - a)
    bow = float(TUNE["curve_bow"]) * k / (((n - 1) ** 2) / 4.0)
    return 10 ** (math.log10(first) + t * (math.log10(last) - math.log10(first)) + bow)


def stake_mul(ante_row, stake_row) -> float:
    col = stake_row.get("curve", "base")
    if col in ("base", None, ""):
        return 1.0
    v = ante_row.get(col)
    return float(v) if v else 1.0


def schedule(stake_id="white") -> list[dict]:
    stake = next(s for s in STAKES if s["id"] == stake_id)
    out = []
    for n in range(1, ROUNDS_N + 1):
        a = ANTES[(n - 1) // BLINDS_PER]
        b = BLINDS[(n - 1) % BLINDS_PER]
        reward = b["reward"]
        if (n - 1) % BLINDS_PER == 0 and stake.get("reward_small") is not None:
            reward = stake["reward_small"]
        out.append({
            "round_no": n,
            "ante": a["ante"],
            "blind": b["id"],
            "blind_ko": b["name"],
            "base": round(ante_base(a["ante"])),
            "blind_mult": b["mult"],
            "stake_mul": stake_mul(a, stake),
            "target": round(ante_base(a["ante"]) * b["mult"] * stake_mul(a, stake)),
            "darts": a["darts"],
            "reward_gold": reward,
            "skippable": b["skippable"],
            "boss": b["boss"],
            "shop_next": {"items": a["shop_items"], "mods": a["shop_mods"],
                          "darts": a["shop_darts"]},
        })
    return out


SCHEDULE = {s["id"]: schedule(s["id"]) for s in STAKES}


def board_val(b, sec) -> float:
    w = CODE["board"]["VAL_W"]
    a_trp = b["to"] ** 2 - b["ti"] ** 2
    if b["t2o"] > 0:
        a_trp += b["t2o"] ** 2 - b["t2i"] ** 2
    a_dbl = b["dout"] ** 2 - b["din"] ** 2
    a_pln = (b["dout"] ** 2 - b["bo"] ** 2) - a_trp - a_dbl
    s = sum(sec) / len(sec)
    return (w["bull_i"] * b["bi"] ** 2 + w["bull_o"] * (b["bo"] ** 2 - b["bi"] ** 2)
            + s * (w["trp"] * a_trp + w["dbl"] * a_dbl + w["plain"] * a_pln))


BOARD_VAL_BASE = board_val(CODE["board"]["BOARD_BASE"], CODE["board"]["SECTORS_BASE"])


# ══════════════════════════════════════════════════════════
#  규칙 — 코드에서 읽은 흐름을 문장으로. 근거 줄을 같이 적는다.
# ══════════════════════════════════════════════════════════
RULES = {
    "identity": {
        "title": "HIGHTONE / 하이톤",
        "genre": "싱글플레이 로그라이트 · 다트 스코어어택",
        "engine": "Godot 4.7 (GDScript)",
        "viewport": CODE["screen"]["VIEW"],
        "art": "코드로 그린다. 이미지·오디오 리소스 파일이 0개다 (소리는 "
               "AudioStreamGenerator 로 실시간 합성).",
        "language": "한국어",
        "reference": "발라트로의 런 구조(앤티 × 블라인드 · 상점 · 조커)를 다트 위에 옮겼다.",
    },
    "core_loop": {
        "run": "런 = 앤티 %d개 × 판 %d개 = 판 %d개. 진행 상태는 정수 round_no(1..%d) 하나뿐이다."
               % (len(ANTES), BLINDS_PER, ROUNDS_N, ROUNDS_N),
        "derive": "앤티 = (n-1)/%d + 1 · 판 종류 = (n-1) %% %d" % (BLINDS_PER, BLINDS_PER),
        "round": "판 하나 = 다트 %d발(기본). 목표 점수를 넘기면 즉시 종료, 못 넘기면 런이 끝난다."
                 % TUNE["darts_base"],
        "between": "판을 넘길 때마다 상점이 열린다. 보스 판 앞에는 제약 선택 화면이 선다.",
        "sequence": ["제목", "새 런(팩·리그 선택)", "판 선택(던지기/건너뛰기)",
                     "[보스 앞] 제약 선택", "조준 → 착탄 → 정산 반복", "판 정산(골드)",
                     "상점", "다음 판"],
    },
    "scoring": {
        "formula": "한 발의 점수 = 칩 × 배수 (score_mode 'std'). 'bal' 은 ((칩+배수)/2)² 이다.",
        "chip_source": "꽂힌 칸의 값(1~20 · 불 25 · 이너 불 50 · 보드 아웃 0).",
        "mult_source": "꽂힌 영역의 배수(싱글 1 · 더블 2 · 트리플 3 · 불 1 · 빗나감은 큐가 1을 넣는다).",
        "queue": ["칩(칸 값)", "배수(영역)", "[관통 다트] 양옆 칸 평균의 절반",
                  "발동한 스티커를 랙 순서대로", "합산 — 칩 × 배수를 총점에 더한다"],
        "order_note": "스티커는 랙에 꽂힌 순서대로 정산된다. ×배수가 뒤에 오면 앞의 +배수를 "
                      "전부 곱하므로 순서가 곧 빌드다.",
        "kill_axes": "칸을 죽이는 축은 번호 → 색 → 홀짝 순으로 좁아진다. 링을 죽이는 축은 "
                     "값은 두고 배수만 1로 내린다.",
        "dart_then_track": "다트 보정(fix1 · mult · pierce)이 먼저, 영역 강화 트랙이 그 뒤다. "
                           "무거운 다트가 트랙 투자를 통째로 먹지 않게 한 순서다.",
        "pattern_timing": "\"…맞힌 뒤\" 조건은 완성한 그 발이 아니라 다음 발부터 선다.",
        "settle_pace": "정산 걸음은 %s걸음까지 같은 박자, 그 뒤로 걸음마다 %s씩 짧아져 %s에서 멎는다."
                       % (CODE["feel"]["PACE"]["free"], CODE["feel"]["PACE"]["step"],
                          CODE["feel"]["PACE"]["min"]),
        "pitch": "정산 한 걸음마다 소리가 반음씩 오른다(392Hz × 2^(n/12)). 게임 이름이 여기서 왔다.",
    },
    "board": {
        "sectors": "칸 20개. 실물 다트판 배치를 그대로 쓴다.",
        "radii": "판 반지름 R = %s px. 아래 값은 R 에 대한 비율이다." % TUNE["board_r"],
        "order": "bi ≤ bo < t2i < t2o < ti < to < din < dout — hit_info 의 if 사슬이 "
                 "전제하는 순서 그 자체다. 개조가 이 순서를 깨면 매대에 안 뜬다.",
        "board_val": "판값 = 균등 조준 다트당 기대 점수. 기본 판 %.4f. 개조가 이 값을 "
                     "기본의 %s배 넘게 올리면 매대에 안 뜬다."
                     % (BOARD_VAL_BASE, TUNE["val_max_mul"]),
        "miss_rate": "기본 판·기본 조준의 빗나감은 37.68%% (게이지 진폭 %s / 반지름 %s = %.4f)."
                     % (TUNE["aim_swing"], TUNE["board_r"],
                        TUNE["aim_swing"] / TUNE["board_r"]),
    },
    "aim": {
        "default": "게이지가 왕복하고 누른 순간 그 축이 잠긴다. 세로 먼저, 가로 다음.",
        "modes": "조준 방식은 **든 스티커**가 쥔다(a*** 스티커 7장). 팩이 아니라 스티커라 "
                 "사고 팔고 봉인되는 규칙 아래 놓인다.",
        "stages": "잠그는 횟수는 방식마다 다르다 — 2회(기본·원·빗각) / 1회(나머지).",
        "gauge": "게이지 속도 %s. 게임 중 [ ] 키로 조절된다. 제약 '역풍'과 설비 '침착'이 "
                 "같은 축을 민다." % TUNE["gauge_speed"],
    },
    "economy": {
        "income": ["판 클리어 보상 (작은 %d · 큰 %d · 보스 %d)"
                   % tuple(b["reward"] for b in BLINDS),
                   "남은 다트 1개당 %d골드" % TUNE["gold_per_dart"],
                   "이자 — 보유 %d골드당 1, 상한 %d" % (TUNE["interest_per"], TUNE["interest_max"]),
                   "골드 스티커 (정산 시점 8종)",
                   "스티커 판매",
                   "건너뛴 판의 딱지"],
        "outgo": ["매대 구매(스티커 · 개조 · 다트 · 소비)", "유료 새로고침", "설비 구매",
                  "리그 유지비 — 판마다 %d골드 (%s)"
                  % (max(s["rent"] or 0 for s in STAKES),
                     ", ".join(s["name"] for s in STAKES if s["rent"]))],
        "start": "시작 자금 %d골드. 팩이 이 값을 덮는다." % TUNE["start_gold"],
        "sell": "판매가 = 구매가 ÷ %d(내림), 최소 %d. 4/7/11/14 → 2/3/5/7 이다."
                % (TUNE["sell_div"], TUNE["sell_min"]),
        "reroll": "무료 %d회, 이후 %d골드에서 시작해 %d씩 오른다."
                  % (TUNE["free_rerolls"], TUNE["reroll_base"], TUNE["reroll_step"]),
        "slots": "스티커 슬롯 %d칸 · 소비 슬롯 %d칸. 팩이 덮는다."
                 % (TUNE["max_items"], TUNE["cons_slots"]),
    },
    "shop": {
        "when": "판 N 을 클리어한 뒤 N+1 을 위해 열린다. 마지막 판 뒤에는 안 연다.",
        "stock": "매대 자리는 정확히 4개다 (스티커 %d · 개조 %d · 다트 %d)."
                 % (ANTES[0]["shop_items"], ANTES[0]["shop_mods"], ANTES[0]["shop_darts"]),
        "weighted": "스티커는 등급 가중치로 뽑는다. 이미 가진 것과 아직 안 풀린 것은 "
                    "애초에 후보에서 빠진다.",
        "mods": "판이 더는 못 받는 개조(기하 순서 위반 · 판값 상한 초과)와 이미 산 개조는 "
                "후보에서 빠진다. 무효 구매가 존재할 수 없다.",
        "voucher": "설비는 매대가 아니라 왼쪽 벽에 걸린다. 앤티당 하나, 새로고침으로 안 씻긴다.",
        "physics": "매물은 딜러가 펠트 위로 던져 굴린다. 새로고침하면 쓸어 담고 다시 던진다. "
                   "구매는 물건을 계산대로 밀거나 두 번 누른다.",
    },
    "difficulty": {
        "stakes": "리그 %d단. 완주하면 다음 단이 열린다." % len(STAKES),
        "modifiers": "보스 판 앞에 제약 %d장을 깔고 **반드시 하나를 고른다**(스킵 없음). "
                     "발라트로는 보스 블라인드를 못 고르는데 이 게임은 고른다."
                     % TUNE["stage_picks"],
        "axes": "제약의 축은 네 갈래다 — 칸(sector_kill·color_kill·odd_mul·spin) · "
                "링(band_mul·ring_kill) · 조준(gauge_mul·fog) · "
                "판밖(darts_add·seal_items·target_mul·reward_mul).",
    },
    "meta": {
        "save": "user://hightone.cfg (Godot ConfigFile · INI). 설정 · 해금 · 통계 셋을 담는다. "
                "깨진 파일이어도 게임은 빈 설정으로 뜬다.",
        "unlock_packs": "기본 팩은 완주로 표 순서대로 열린다. 히든 팩은 통계 조건으로 열린다.",
        "unlock_stakes": "리그는 앞 단을 완주하면 다음 단이 열린다.",
    },
    "undecided": {
        "processing": "가공 %d종 — 전부 제안 상태, enabled=0. 대상 선택 흐름 미구현."
                      % len(PROCESSING),
        "consumables": "소비 아이템은 전부 '가안'. 가격이 미정이라 임시가 %d골드를 쓴다."
                       % TUNE["cons_price_tmp"],
        "area_upgrades": "영역 강화 트랙은 표와 코드가 다 서 있고 수치도 들어갔다. "
                         "다만 소비 아이템 매대 구성(shop_cons)이 임시 규칙이다.",
        "hidden_pack": "히든 팩 p_x1 은 자리만 세워 둔 것이다 — 지금은 기본과 똑같이 돈다.",
        "target_mul": "제약 '높은 목표'의 1.25 는 임시값(TODO).",
    },
}


# ══════════════════════════════════════════════════════════
#  JSON
# ══════════════════════════════════════════════════════════
def build_json() -> dict:
    return {
        "meta": {
            "title": "HIGHTONE 게임 데이터 전체 내보내기",
            "purpose": "게임 기획서 작성을 위해 LLM 에게 이 게임의 모든 요소와 규칙을 "
                       "학습시키는 용도. 사람이 손으로 적은 수치는 한 칸도 없다.",
            "generated": date.today().isoformat(),
            "generator": "scripts/tools/export_kb.py",
            "sources": ["data/*.csv (16장)", "scripts/data.gd", "scripts/game.gd",
                        "scripts/save.gd"],
            "conventions": {
                "_note": "표의 밑줄 열은 사람이 읽는 설계 근거다. 값이 아니라 이유가 적혀 있다.",
                "null": "빈 칸은 '미정' 이다. 0 과 다르다.",
                "enabled": "0 인 행은 데이터만 실려 있고 게임에 안 뜬다.",
                "status": "확정 / 가안 / 제안 — 기획 확정도다.",
            },
        },
        "rules": RULES,
        "code_constants": CODE,
        "tuning": {
            "values": TUNE,
            "rows": TUNING,
        },
        "tables": {
            "items": ITEM_VIEWS,
            "items_raw": ITEMS,
            "rarity": RARITY,
            "mods": [dict(m, desc_ko=desc_fill(m.get("desc"), m, {})) for m in MODS],
            "darts": [dict(d, desc_ko=desc_fill(d.get("desc"), d, {})) for d in DARTS],
            "modifiers": [dict(m, desc_ko=desc_fill(m.get("desc"), m, {})) for m in MODIFIERS],
            "areas": AREAS,
            "area_upgrades": AREA_UP,
            "consumables": CONSUMABLES,
            "processing": PROCESSING,
            "antes": ANTES,
            "blinds": BLINDS,
            "packs": [dict(p, desc_ko=pack_desc(p)) for p in PACKS],
            "stakes": STAKES,
            "tags": [dict(t, desc_ko=desc_fill(t.get("desc"), t, {})) for t in TAGS],
            "vouchers": [dict(v, desc_ko=desc_fill(v.get("desc"), v, {})) for v in VOUCHERS],
            "colors": COLORS,
            "spec_map": SPEC_MAP,
            "measured_stats": STATS_CSV,
        },
        "derived": {
            "rounds_n": ROUNDS_N,
            "blinds_per_ante": BLINDS_PER,
            "board_val_base": round(BOARD_VAL_BASE, 6),
            "board_val_max": round(BOARD_VAL_BASE * TUNE["val_max_mul"], 6),
            "schedule": SCHEDULE,
            "counts": {
                "items_total": len(ITEMS),
                "items_enabled": len(ON),
                "items_disabled": len(OFF),
                "items_by_rarity": {r["id"]: sum(1 for i in ON if i["rarity"] == r["id"])
                                    for r in RARITY},
                "items_by_kind": {k: sum(1 for i in ON if i["kind"] == k)
                                  for k in CODE["vocab"]["KINDS"]},
                "mods": len(MODS), "darts": len(DARTS), "modifiers": len(MODIFIERS),
                "tags": len(TAGS), "vouchers": len(VOUCHERS), "packs": len(PACKS),
                "stakes": len(STAKES), "areas": len(AREAS),
                "consumables_enabled": sum(1 for c in CONSUMABLES if c["enabled"]),
                "processing": len(PROCESSING),
                "aim_modes": len(CODE["vocab"]["AIM_MODES"]),
            },
        },
    }


# ══════════════════════════════════════════════════════════
#  Markdown
# ══════════════════════════════════════════════════════════
def md_table(headers, rows) -> str:
    out = ["| " + " | ".join(headers) + " |",
           "|" + "|".join(["---"] * len(headers)) + "|"]
    for r in rows:
        cells = []
        for c in r:
            if c is None or c == "":
                c = "—"
            cells.append(str(c).replace("|", "\\|").replace("\n", " "))
        out.append("| " + " | ".join(cells) + " |")
    return "\n".join(out)


def g(v, dflt="—"):
    return dflt if v is None or v == "" else v


def build_md() -> str:
    L = []
    w = L.append

    w("# HIGHTONE — 게임 전체 정보 (LLM 학습용 자료)\n")
    w("> 이 문서는 게임 기획서를 쓰기 위한 **원본 자료**다. 게임 빌드에서 자동으로 뽑았다.")
    w("> `scripts/tools/export_kb.py` 가 `data/*.csv` 16장과 `scripts/*.gd` 3장을 읽어 만든다.")
    w("> 사람이 손으로 적은 수치는 한 칸도 없다. 짝이 되는 기계용 파일은 `hightone_kb.json` 이다.\n")
    w("**읽는 규약**\n")
    w("- 빈 칸(`—`)은 **미정**이다. 0 과 다르다.")
    w("- `사용` 열이 `✗` 인 행은 데이터만 실려 있고 게임에 안 뜬다.")
    w("- `비고` 열은 그 값을 그렇게 정한 **이유**다. 밸런스 판단의 근거로 쓴다.")
    w("- 확정도는 세 단계다 — **확정** / **가안** / **제안**.\n")
    w("**LLM 에 먹이는 법**\n")
    w("1. 기획서 초안을 쓰게 하려면 이 `.md` 를 통째로 올린다. 문장과 표가 같이 있어 "
      "맥락이 안 끊긴다.")
    w("2. 수치 계산·밸런스 시뮬레이션·표 재가공을 시키려면 `hightone_kb.json` 을 올린다. "
      "같은 내용이 타입 있는 값으로 들어 있다.")
    w("3. 둘 다 올리는 것이 가장 좋다. 그리고 이렇게 못 박아 준다 — "
      "**\"미정 칸을 임의로 채우지 말고 미정으로 남겨라. 없는 수치를 지어내지 마라.\"**")
    w("4. 이 문서에 없는 것 — 상업 계획 · 가격 · 출시 일정 · 아트 리소스 · 스토리 대사. "
      "아직 정하지 않았다.\n")
    w("---\n")

    # 목차
    w("## 목차\n")
    for i, t in enumerate([
        "게임 정체", "핵심 루프", "점수 계산", "다트판 기하", "조준 방식",
        "스티커 (아이템)", "보드 개조", "다트", "소비 아이템과 영역 강화",
        "제약 (보스 판)", "딱지 (건너뛰기 보상)", "설비 (바우처)",
        "스타트팩", "리그 (난이도 단계)", "라운드 곡선과 목표",
        "경제 상수", "화면과 조작", "저장 · 해금 · 통계",
        "어휘 사전", "아직 안 정한 것", "측정 데이터",
    ], 1):
        w("%d. [%s](#%d-%s)" % (i, t, i, t.replace(" ", "-").replace("(", "").replace(")", "")))
    w("\n---\n")

    # 1
    idn = RULES["identity"]
    w("## 1. 게임 정체\n")
    w(md_table(["항목", "값"], [
        ["제목", idn["title"]], ["장르", idn["genre"]], ["엔진", idn["engine"]],
        ["해상도", "%d × %d (정수 배율 확대)" % tuple(idn["viewport"])],
        ["언어", idn["language"]], ["아트", idn["art"]], ["참고작", idn["reference"]],
        ["전체 판 수", "%d판 (앤티 %d × 판 %d)" % (ROUNDS_N, len(ANTES), BLINDS_PER)],
    ]))
    w("")
    w("**한 줄 요약** — 던지는 손(조준)과 읽는 머리(빌드)가 **곱해지는** 다트 로그라이트. "
      "꽂힌 자리가 앞의 수를, 들고 있는 스티커가 뒤의 수를 정하고 둘은 더해지지 않고 곱해진다.\n")
    w("**규모**\n")
    c = build_json()["derived"]["counts"]
    w(md_table(["갈래", "수"], [
        ["스티커(아이템)", "%d장 (활성 %d · 대기 %d)" % (c["items_total"], c["items_enabled"], c["items_disabled"])],
        ["  등급별(활성)", " · ".join("%s %d" % (RARITY_KO[k], v) for k, v in c["items_by_rarity"].items())],
        ["보드 개조", "%d종" % c["mods"]], ["다트", "%d종" % c["darts"]],
        ["제약", "%d종" % c["modifiers"]], ["딱지", "%d종" % c["tags"]],
        ["설비", "%d종" % c["vouchers"]], ["스타트팩", "%d종" % c["packs"]],
        ["리그", "%d단" % c["stakes"]], ["착탄 영역", "%d종" % c["areas"]],
        ["소비 아이템", "%d종 (활성)" % c["consumables_enabled"]],
        ["가공", "%d종 (전부 미구현)" % c["processing"]],
        ["조준 방식", "%d종" % c["aim_modes"]],
    ]))
    w("\n---\n")

    # 2
    cl = RULES["core_loop"]
    w("## 2. 핵심 루프\n")
    for k in ("run", "derive", "round", "between"):
        w("- " + cl[k])
    w("\n**화면 순서**\n")
    w("```")
    w("\n  ↓\n".join("  " + s for s in cl["sequence"]))
    w("```\n")
    w("**한 판 안에서**\n")
    w("```")
    w("""  다트 고르기(PICK) → 조준 1축(AIM_V) → 조준 2축(AIM_H) → 확인(CONFIRM)
        → 비행(FLY) → 정산(RESOLVE) → [목표 미달이고 다트 남음] 다시 PICK
                                     → [목표 달성 또는 다트 소진] 판 정산(CLEAR)""")
    w("```\n")
    w("- 목표를 **넘긴 순간** 라운드가 끝난다. 남은 다트는 골드로 환산된다.")
    w("- 목표를 못 넘기면 런이 끝난다. 단, `save` 종류 스티커가 있으면 1회 무를 수 있다.")
    w("\n---\n")

    # 3
    sc = RULES["scoring"]
    w("## 3. 점수 계산\n")
    w("### 3-1. 공식\n")
    w("```")
    w("  한 발의 점수 = 칩(chip) × 배수(mult)")
    w("  라운드 총점 = Σ 한 발의 점수")
    w("  클리어 조건 = 총점 ≥ 목표")
    w("```\n")
    w("- **칩**: " + sc["chip_source"])
    w("- **배수**: " + sc["mult_source"])
    w("- 계산 방식은 스타트팩이 쥔다. `std` = 칩 × 배수 · `bal` = ((칩+배수)/2)². "
      "`bal` 은 한쪽만 쌓는 빌드를 죽이고 양쪽을 고르게 올린 빌드를 가장 크게 만든다.\n")
    w("### 3-2. 한 발의 정산 큐\n")
    w("정산은 큐를 한 걸음씩 판다. 걸음마다 소리가 반음 오른다.\n")
    for i, s in enumerate(sc["queue"], 1):
        w("%d. %s" % (i, s))
    w("")
    for k in ("order_note", "kill_axes", "dart_then_track", "pattern_timing", "settle_pace", "pitch"):
        w("- " + sc[k])
    w("\n### 3-3. 효과 종류 (`kind`)\n")
    w(md_table(["kind", "정산에서 하는 일", "표기"], [
        ["chip", "cur_chip 에 더한다", "점수 +N"],
        ["mult", "cur_mult 에 더한다", "배수 +N"],
        ["xmult", "cur_mult 에 곱한다", "배수 ×N"],
        ["mult_streak", "연속 명중 수 × N 을 배수에 더한다", "배수 +N (연속 1회마다)"],
        ["mult_rand", "0~N 무작위를 배수에 더한다", "배수 +0~N 무작위"],
        ["save", "정산에 안 실린다. 라운드 실패를 1회 무르고 자신을 부순다", "실패 1회 방지"],
    ]))
    w("\n### 3-4. 골드가 나오는 시점 (`gold`)\n")
    w(md_table(["gold", "시점", "문장"], [
        [k, "착탄 즉시" if k in ("risk50", "hit") else "판 정산", gold_text(k, 0).replace(" +0", " +N")]
        for k in CODE["vocab"]["GOLDS"]
    ]))
    w("\n### 3-5. 배율 재료 (`per`)\n")
    w("효과값에 곱해지는 문맥 값이다.\n")
    w(md_table(["per", "무엇을 곱하는가"], [
        ["darts_left", "남은 다트 수"], ["items", "보유 아이템 수"],
        ["gold", "보유 골드"], ["gold5", "보유 골드 ÷ 5"],
        ["mag_hvy", "탄창의 무거운 다트 수"], ["missing", "기본에서 줄어든 다트 수"],
        ["low", "이번 라운드 최저 명중 숫자"], ["zonehist", "이 영역의 런 누적 명중 수"],
        ["rackval", "다른 아이템 판매가 합계"], ["empty", "빈 아이템 칸 수 (최소 1)"],
    ]))
    w("\n### 3-6. 성장과 마모 (`grow` · `boom`)\n")
    w(md_table(["열쇠", "값", "동작"], [
        ["grow", "fire", "발동할 때마다 값이 gstep 만큼 누적"],
        ["grow", "hitmiss", "명중마다 +gstep · 빗나가면 −gstep"],
        ["grow", "tdec", "값에서 시작해 던질 때마다 gstep 감소"],
        ["grow", "rdec", "값에서 시작해 라운드마다 gstep 감소 · 0이면 파괴"],
        ["boom", "r6", "라운드마다 1/6 확률로 파괴"],
        ["boom", "r1000", "라운드마다 0.1% 확률로 파괴"],
        ["side", "trackup25", "발동 4회 중 1회, 맞은 영역의 강화 트랙 +1"],
        ["dadd", "정수", "라운드 시작 다트 수를 더하거나 뺀다"],
    ]))
    w("\n---\n")

    # 4
    bd = RULES["board"]
    bb = CODE["board"]["BOARD_BASE"]
    w("## 4. 다트판 기하\n")
    w("- " + bd["sectors"])
    w("- " + bd["radii"])
    w("- " + bd["miss_rate"])
    w("- " + bd["board_val"])
    w("\n**칸 배치 (12시부터 시계방향)**\n")
    w("`" + ", ".join(str(x) for x in CODE["board"]["SECTORS_BASE"]) + "`\n")
    w("**기본 반지름 (R 대비 비율)**\n")
    w(md_table(["열쇠", "값", "뜻"], [
        ["bi", bb["bi"], "한복판(이너 불 50) 바깥 경계"],
        ["bo", bb["bo"], "불(아우터 불 25) 바깥 경계"],
        ["ti", bb["ti"], "트리플 띠 안쪽"],
        ["to", bb["to"], "트리플 띠 바깥"],
        ["t2i", bb["t2i"], "둘째 트리플 띠 안쪽 (0 = 없음 · 개조 '아랫목'이 켠다)"],
        ["t2o", bb["t2o"], "둘째 트리플 띠 바깥"],
        ["din", bb["din"], "더블 띠 안쪽"],
        ["dout", bb["dout"], "판의 끝 = 빗나감 경계"],
    ]))
    w("\n- 순서 규칙: `" + bd["order"] + "`\n")
    w("**착탄 영역** (`areas.csv` · 전부 확정)\n")
    w(md_table(["key", "이름", "기본 점수", "기본 배수", "강화 트랙", "비고"],
               [[a["key"], a["name"], g(a["base"], "칸 값"), a["mult"], a["track"],
                 g(a["_note"])] for a in AREAS]))
    w("\n**기하 제약** (`GEO` — 밸런스 상한이 아니라 판이 성립하기 위한 조건)\n")
    w(md_table(["열쇠", "값", "뜻"], [
        [k, v, {"bi_min": "한복판 최소 반경", "bull_gap": "25 띠의 최소 폭 (0이면 25칸이 사라진다)",
                "bo_min": "불 최소 반경", "ti_min": "트리플 띠가 한복판까지 못 기어들어오게",
                "band_min": "링의 최소 폭", "gap": "띠와 띠 사이 단색의 최소 폭",
                "eps": "부동소수 오차 흡수"}.get(k, "")]
        for k, v in CODE["board"]["GEO"].items()]))
    w("\n**판값 가중치** (`VAL_W` — 균등 조준 다트당 기대 점수를 적분할 때 쓴다)\n")
    w("`" + " · ".join("%s %s" % (k, v) for k, v in CODE["board"]["VAL_W"].items()) + "`\n")
    w("**칸 색** (`colors.csv` — 기하와 무관한 넷째 속성. 제약 '그늘'과 조건 `col:` 이 읽는다)\n")
    w(md_table(["id", "이름", "hex", "비고"],
               [[c["id"], c["name"], "#" + c["hex"], g(c["_note"])] for c in COLORS]))
    w("\n---\n")

    # 5
    w("## 5. 조준 방식\n")
    w("- " + RULES["aim"]["modes"])
    w("- " + RULES["aim"]["default"])
    w("- " + RULES["aim"]["gauge"])
    w("")
    rows = []
    for m in CODE["vocab"]["AIM_MODES"]:
        hint = CODE["vocab"]["AIM_HINT"].get(m, [])
        rows.append([m, AIM_NAME.get(m, m), CODE["vocab"]["AIM_STAGES"].get(m),
                     AIM_TEXT.get(m, "게이지가 왕복하고 누른 순간 그 축이 잠긴다"),
                     " → ".join(hint) if isinstance(hint, list) else hint])
    w(md_table(["mode", "이름", "잠금 횟수", "하는 일", "화면 안내"], rows))
    w("")
    w("**손맛 상수**\n")
    w(md_table(["묶음", "열쇠", "값", "뜻"], [
        ["PULL(당김)", "vs", CODE["feel"]["PULL"]["vs"], "속도 → 거리 변환 계수(초)"],
        ["PULL", "win", CODE["feel"]["PULL"]["win"], "속도를 재는 창(초)"],
        ["PULL", "least", CODE["feel"]["PULL"]["least"], "이보다 안 나가면 안 던진다"],
        ["PULL", "spread", CODE["feel"]["PULL"]["spread"], "산포(px)"],
        ["KICK(반동)", "gap", CODE["feel"]["KICK"]["gap"], "발 사이 간격(초)"],
        ["KICK", "up", CODE["feel"]["KICK"]["up"], "발마다 위로 밀리는 양(px)"],
        ["KICK", "side", CODE["feel"]["KICK"]["side"], "좌우 흔들림 폭(px)"],
        ["KICK", "settle", CODE["feel"]["KICK"]["settle"], "반동 회복 속도(px/s)"],
        ["KICK", "n / share", "%s / %s" % (TUNE["kick_n"], TUNE["kick_share"]),
         "연발 수 / 작은 다트 한 발의 점수 몫 (튜닝 표)"],
        ["DRIFT(흔들)", "span", CODE["feel"]["DRIFT"]["span"], "떠도는 원의 반지름 = R × 이 값"],
        ["DRIFT", "hold", CODE["feel"]["DRIFT"]["hold"], "다음 자리를 뽑기까지(초)"],
        ["DRIFT", "speed", CODE["feel"]["DRIFT"]["speed"], "달려가는 속도(px/s)"],
    ]))
    w("\n---\n")

    # 6 items
    w("## 6. 스티커 (아이템)\n")
    w("게임의 조커 자리다. 슬롯 **%d칸**이고 넣는 것이 곧 빼는 것이 된다." % TUNE["max_items"])
    w("조건이 맞은 스티커만 그 다트에서 발동한다. 랙에 꽂힌 **순서대로** 정산되므로 순서가 곧 빌드다.\n")
    w("등급은 등장 가중치와 해금 라운드를 정한다.\n")
    w(md_table(["id", "이름", "색", "가중치", "최소 라운드", "비고"],
               [[r["id"], r["name"], "#" + r["color"], r["weight"], r["min_round"], g(r["_note"])]
                for r in RARITY]))
    w("")

    def item_rows(items):
        return [[i["id"], i["name"], i["rarity_ko"], g(i["cond_ko"]), g(i["effect_ko"]),
                 g(i["gold_ko"]), i["cost"], i["sell"], "R%d" % i["min_round"],
                 g((i.get("measured") or {}).get("fire_pct")),
                 g((i.get("measured") or {}).get("gain_per_dart"))] for i in items]

    head = ["id", "이름", "등급", "조건", "효과", "골드", "가격", "판매", "해금",
            "발동률%", "다트당"]

    # 갈래는 셋이고 겹치지 않는다 — 조준 스티커 → 스펙 유래(j###) → 나머지가 기본 세트.
    # id 첫 글자로 가르면 alc·alm 같은 기본 세트가 조준 쪽으로 새어 표에서 사라진다.
    aims = [i for i in ON if i["aim"]]
    spec = [i for i in ON if not i["aim"] and re.match(r"^j\d", i["id"])]
    hand = [i for i in ON if i not in aims and i not in spec]

    w("### 6-1. 기본 세트 — %d장\n" % len(hand))
    w("손으로 설계한 원본. `_tags` 로 갈래가 붙어 있다.\n")
    w(md_table(head, item_rows(hand)))
    w("\n### 6-2. 스펙 시트 유래 (`j###`) — %d장\n" % len(spec))
    w("HIGHTONE 스펙 워크북에서 옮겨 온 것 중 엔진이 지원하는 것만 켜 두었다.\n")
    w(md_table(head, item_rows(spec)))
    w("\n### 6-3. 조준 스티커 (`a###`) — %d장\n" % len(aims))
    w("점수도 배수도 안 준다. **드는 순간 이 런의 조준 방식이 바뀐다.** "
      "팩이 아니라 스티커라서 사고 팔고 봉인되는 규칙 아래 놓인다.\n")
    w(md_table(["id", "이름", "등급", "조준 방식", "하는 일", "가격", "판매"],
               [[i["id"], i["name"], i["rarity_ko"], AIM_NAME.get(i["aim"], i["aim"]),
                 i["effect_ko"], i["cost"], i["sell"]] for i in aims]))
    w("\n### 6-4. 대기 중 (`enabled=0`) — %d장\n" % len(OFF))
    w("데이터는 실려 있지만 게임에 안 뜬다. **엔진이 아직 못 하는 것**이 무엇인지가 "
      "비고에 적혀 있다 — 개발 로드맵으로 읽으면 된다.\n")
    w(md_table(["id", "이름", "등급", "가격", "막힌 이유(비고)"],
               [[i["id"], i["name"], i["rarity_ko"], i["cost"], g(i["note"])] for i in OFF]))
    w("\n**발동 조건 전체 목록**은 [19. 어휘 사전](#19-어휘-사전)에 있다.\n")
    w("---\n")

    # 7 mods
    w("## 7. 보드 개조\n")
    w("판의 **기하**를 영구히 바꾼다. 상점에서 사면 런이 끝날 때까지 남는다.")
    w("판은 상태가 아니라 산 개조 목록의 함수다 — 살 때마다 기본 판에서 표 순서대로 다시 굽는다. "
      "그래서 \"먼저 산 개조가 나중 개조를 흔드는가\" 라는 물음이 아예 성립하지 않는다.\n")
    w("- 기하 순서를 깨거나 판값을 기본의 %s배 넘게 올리는 개조는 **매대에 안 뜬다**." % TUNE["val_max_mul"])
    w("- `excl` 이 걸린 둘은 서로를 되돌리므로 같이 못 산다.\n")
    w(md_table(["id", "이름", "축", "v0", "v1", "배타", "가격", "효과", "비고"],
               [[m["id"], m["name"], m["axis"], g(m["v0"]), g(m["v1"]), g(m["excl"]),
                 m["cost"], desc_fill(m.get("desc"), m, {}), g(m["_note"])] for m in MODS]))
    w("\n**축이 하는 일**\n")
    w(md_table(["축", "동작"], [
        ["band", "링 폭 주고받기. v = [트리플 증분, 더블 증분], 합이 0이다"],
        ["slide", "트리플 띠 이동. v = 더블 안쪽에서 띄울 간격"],
        ["ring", "트리플 띠 추가. v = [안, 밖]"],
        ["bull", "불 이중 구조. v = [한복판, 불]"],
        ["out", "판 바깥 경계. v = 새 dbl_out"],
        ["swap", "가장 작은 v칸을 20으로 올린다"],
        ["odd", "칸마다 짝이 생긴다 · 짝수 칸 −1 (v는 안 쓴다)"],
    ]))
    w("\n---\n")

    # 8 darts
    w("## 8. 다트\n")
    w("탄창(magazine)에 드는 것. 상점에서 사면 표준 다트 한 자루를 대체한다.")
    w("기본 탄창은 표준 %d자루다.\n" % TUNE["darts_base"])
    w(md_table(["id", "이름", "게이지", "배수", "고정1", "관통", "자석", "가격", "효과", "비고"],
               [[d["id"], d["name"], d["gauge"], g(d["mult"]), "✓" if d["fix1"] else "—",
                 g(d["pierce_side"]), g(d["magnet"]), d["cost"],
                 desc_fill(d.get("desc"), d, {}) or d.get("desc"), g(d["_note"])]
                for d in DARTS]))
    w("")
    w("- `gauge` — 조준 게이지 속도 배율. 낮을수록 느리고(=맞히기 쉽고) 높을수록 빠르다.")
    w("- `mult` — 배수 보정. 하한 1 을 통과한 뒤 영역 강화가 그 위에 얹힌다.")
    w("- `fix1` — 배수를 1로 고정한다. 트리플·더블·링 조건 스티커가 전부 죽는다.")
    w("- `pierce_side` — 양옆 칸 값의 이 비율만큼을 칩으로 더 받는다.")
    w("- `magnet` — 착탄점을 중심으로 이 비율만큼 당긴다. 빗나감이 37.68% → 5.52% 가 된다.\n")
    w("---\n")

    # 9 consumables
    w("## 9. 소비 아이템과 영역 강화\n")
    w("사서 쟁여 뒀다가 한 번 쓰고 사라진다. 칸 **%d개**." % TUNE["cons_slots"])
    w("확정 규칙 — 상점에서 즉시 사용 가능 · 보관 가능 · 라운드 중 사용 가능 · "
      "사용 확정은 누르고 뗄 때 · 확인 버튼과 비교 팝업은 만들지 않는다.\n")
    w("**⚠ 전부 '가안' 이다.** 가격이 미정이라 임시가 %d골드를 쓴다." % TUNE["cons_price_tmp"])
    w("매대 구성도 임시 규칙이다 — `shop_cons`(현재 %d)가 켜져 있으면 스티커 자리 하나를 "
      "소비 아이템으로 바꾼다.\n" % TUNE["shop_cons"])
    w(md_table(["id", "wb", "이름", "설명", "상태", "갈래", "대상", "트랙", "사용", "비고"],
               [[c["id"], c["wb"], c["name"], c["desc"], c["status"], c["cat"],
                 c["target"], g(c["track"]), "✓" if c["enabled"] else "✗", g(c["_note"])]
                for c in CONSUMABLES]))
    w("\n### 9-1. 영역 강화 트랙 (발라트로의 행성 카드 자리)\n")
    w("소비 아이템이 트랙 레벨을 올리고, 1..lv 레벨 행의 수치를 합친 것이 착탄에 얹힌다.")
    w("적용 순서는 **다트 보정 뒤**다 — 무거운 다트가 트랙 투자를 통째로 먹지 않게 한 순서다.\n")
    tracks = {}
    for a in AREA_UP:
        tracks.setdefault((a["track"], a["name"]), []).append(a)
    rows = []
    for (tid, tname), lv in tracks.items():
        s = sum(x["add_score"] or 0 for x in lv)
        m = sum(x["add_mult"] or 0 for x in lv)
        rows.append([tid, tname, len(lv),
                     "레벨당 +%s" % (lv[0]["add_score"] or 0),
                     "홀수 레벨마다 +1" if m and m < len(lv) else ("레벨당 +1" if m else "—"),
                     "+%d / +%d" % (s, m), g(lv[0]["_note"])])
    w(md_table(["트랙", "영역", "최대 레벨", "점수", "배수", "만렙 누적(점수/배수)", "비고"], rows))
    w("\n### 9-2. 가공 (processing) — 전부 미구현\n")
    w("아이템과 다트에 덧입히는 변형. `enabled` 가 전부 0 이고 대상 선택 흐름이 없다.\n")
    w(md_table(["id", "wb", "이름", "상태", "대상", "설명", "비고"],
               [[p["id"], p["wb"], p["name"], p["status"], p["target"], p["desc"], g(p["_note"])]
                for p in PROCESSING]))
    w("\n---\n")

    # 10 modifiers
    w("## 10. 제약 (보스 판)\n")
    w("보스 판 앞에 **%d장**을 깔고 그중 **하나를 반드시 고른다**. 스킵이 없다." % TUNE["stage_picks"])
    w("발라트로는 보스 블라인드를 못 고르는데 이 게임은 고른다 — 그 차이가 이 화면의 전부다.\n")
    w("- " + RULES["difficulty"]["axes"] + "\n")
    w(md_table(["id", "이름", "축", "값", "가중치", "효과", "비고"],
               [[m["id"], m["name"], m["axis"], m["v"], m["weight"],
                 desc_fill(m.get("desc"), m, {}), g(m["_note"])] for m in MODIFIERS]))
    w("\n---\n")

    # 11 tags
    w("## 11. 딱지 (건너뛰기 보상)\n")
    w("작은 판과 큰 판은 건너뛸 수 있다. 건너뛰면 점수도 골드도 없고 대신 딱지를 받는다 — "
      "그 교환이 이 화면의 전부다. 보스 판은 못 건너뛴다.\n")
    w("지급 시점 네 갈래 — `now`(즉시) · `round`(다음 판) · `shop`(다음 상점) · `stage`(다음 보스 판)\n")
    w(md_table(["id", "이름", "갈래", "값", "시점", "최소 앤티", "가중치", "효과", "비고"],
               [[t["id"], t["name"], t["kind"], t["v"], t["when"], t["min_ante"],
                 t["weight"], desc_fill(t.get("desc"), t, {}), g(t["_note"])] for t in TAGS]))
    w("\n---\n")

    # 12 vouchers
    w("## 12. 설비 (바우처)\n")
    w("상점에서 사면 런 내내 남는 영구 업그레이드. 리그(런 시작에 고른다)와 "
      "딱지(한 번 쓰고 사라진다) 사이의 빈 자리다.\n")
    w("- 매대가 아니라 **왼쪽 벽**에 걸린다. 새로고침해도 안 씻긴다.")
    w("- 앤티당 하나. 사면 사라지고 그 앤티에는 다시 안 뜬다.")
    w("- `prereq` 가 있으면 앞 단을 사야 뜬다.\n")
    w(md_table(["id", "이름", "미는 값", "v", "연산", "가격", "선행", "최소 앤티", "가중치", "효과", "비고"],
               [[v["id"], v["name"], v["key"], v["v"], v["op"], v["cost"], g(v["prereq"]),
                 v["min_ante"], v["weight"], desc_fill(v.get("desc"), v, {}), g(v["_note"])]
                for v in VOUCHERS]))
    w("\n**설비가 밀 수 있는 축과 범위** (`VOUCHER_KEYS` — 목록이 곧 계약이다)\n")
    w(md_table(["열쇠", "바닥", "천장"],
               [[k, v[0] if isinstance(v, list) else v, v[1] if isinstance(v, list) else ""]
                for k, v in (CODE["vocab"]["VOUCHER_KEYS"] or {}).items()]))
    w("\n---\n")

    # 13 packs
    w("## 13. 스타트팩\n")
    w("발라트로의 덱 자리다. 런의 **시작 조건**을 쥔다. 기본 팩은 완주하면 표 순서대로 다음 것이 열린다.\n")
    w("팩은 효과를 직접 들고 있지 않고 **물건으로** 준다(`grant_*`). "
      "그래야 그 물건이 사고 팔고 봉인되는 규칙 아래 놓인다.\n")
    w(md_table(["id", "이름", "갈래", "선행", "다트±", "골드±", "스티커 칸", "소비 칸",
                "이자", "잔탄 골드", "조준", "계산", "해금 조건", "설명"],
               [[p["id"], p["name"], p["kind"], g(p["prereq"]), g(p["darts_add"], "0"),
                 g(p["gold_add"], "0"), g(p["item_slots"]), g(p["cons_slots"]),
                 "끔" if p["interest_off"] else "켬", g(p["dart_gold"]),
                 g(p.get("aim"), "std"), g(p.get("score"), "std"),
                 ("%s ≥ %s" % (p["unlock_stat"], p["unlock_v"])) if p.get("unlock_stat") else "—",
                 g(pack_desc(p))] for p in PACKS]))
    w("")
    w("**팩 비고 (설계 근거)**\n")
    for p in PACKS:
        if p.get("_note"):
            w("- **%s** — %s" % (p["name"], p["_note"]))
    w("\n---\n")

    # 14 stakes
    w("## 14. 리그 (난이도 단계)\n")
    w("발라트로의 스테이크 자리다. **%d단**이고 앞 단을 완주하면 다음 단이 열린다." % len(STAKES))
    w("리그는 곡선을 **고르는** 것이지 곱하는 것이 아니다 — `curve` 열이 `antes.csv` 의 "
      "어느 열을 볼지 가리킨다.\n")
    w(md_table(["id", "이름", "곡선", "작은판 보상", "봉인", "다트±", "매대가", "이자상한+",
                "삭음", "유지비", "선행", "비고"],
               [[s["id"], s["name"], s["curve"], s["reward_small"], s["seal_items"],
                 s["darts_add"], s["shop_cost_mul"], s["interest_add"], s["perish"],
                 s["rent"], g(s["prereq"]), g(s["_note"])] for s in STAKES]))
    w("")
    w("- **봉인** — 매 판 스티커 하나가 무작위로 봉인된 채 시작한다(제약 '둔화'의 상시판).")
    w("- **삭음** — 산 스티커가 N판 뒤에 부서진다.")
    w("- **유지비** — 판마다 골드를 낸다. 골드가 없으면 0에서 멈춘다(빚을 안 만든다).\n")
    w("---\n")

    # 15 antes
    w("## 15. 라운드 곡선과 목표\n")
    w("```")
    w("  목표 = 앤티 기본 × 판 배수(blind.mult) × 리그 곡선(stake.curve)")
    w("  앤티 기본 = 10 ^ ( 직선(curve_first → curve_last) + curve_bow · 배부름 )")
    w("  배부름(n) = (n-1)(N-n) / ((N-1)^2 / 4)      양 끝 0, 한가운데 1")
    w("```\n")
    w("**곡선 손잡이** (`tuning.csv`) — curve_first %s · curve_last %s · curve_bow %s\n"
      % (TUNE["curve_first"], TUNE["curve_last"], TUNE["curve_bow"]))
    w("**앤티 표** (`antes.csv` · 기본은 손잡이에서 나온다)\n")
    w(md_table(["앤티", "기본", "curve_a", "curve_b", "매대(스티커/개조/다트)", "다트", "비고"],
               [[a["ante"], round(ante_base(a["ante"])), a["curve_a"], a["curve_b"],
                 "%d / %d / %d" % (a["shop_items"], a["shop_mods"], a["shop_darts"]),
                 a["darts"], g(a["_note"])] for a in ANTES]))
    w("\n**판 종류 표** (`blinds.csv`)\n")
    w(md_table(["id", "이름", "목표 배수", "보상 골드", "건너뛰기", "보스", "비고"],
               [[b["id"], b["name"], b["mult"], b["reward"],
                 "가능" if b["skippable"] else "불가", "✓" if b["boss"] else "—", g(b["_note"])]
                for b in BLINDS]))
    w("\n**펼친 진행표 — 흰 리그 기준 (%d판)**\n" % ROUNDS_N)
    w(md_table(["판", "앤티", "종류", "목표", "다트", "보상", "건너뛰기", "다음 상점(스티커/개조/다트)"],
               [[s["round_no"], s["ante"], s["blind_ko"], s["target"], s["darts"],
                 s["reward_gold"], "가능" if s["skippable"] else "불가",
                 "%d / %d / %d" % (s["shop_next"]["items"], s["shop_next"]["mods"],
                                   s["shop_next"]["darts"])]
                for s in SCHEDULE["white"]]))
    w("\n**리그별 최종 목표 (24판째)**\n")
    w(md_table(["리그", "곡선", "24판 목표", "8앤티 작은판", "8앤티 큰판"],
               [[next(x["name"] for x in STAKES if x["id"] == k),
                 next(x["curve"] for x in STAKES if x["id"] == k),
                 v[-1]["target"], v[-3]["target"], v[-2]["target"]]
                for k, v in SCHEDULE.items()]))
    w("\n---\n")

    # 16 tuning
    w("## 16. 경제 상수\n")
    w("`tuning.csv` — 행이 안 느는 스칼라만 모은다. 밸런스 상수는 이 표 한 곳에만 있고 "
      "코드에 복제본이 없다.\n")
    groups = {}
    for r in TUNING:
        groups.setdefault(r["group"], []).append(r)
    for gname, rs in groups.items():
        w("### %s\n" % gname)
        w(md_table(["열쇠", "값", "형", "범위", "뜻"],
                   [[r["key"], r["value"], r["type"], "%s ~ %s" % (g(r["min"]), g(r["max"])),
                     g(r["_note"])] for r in rs]))
        w("")
    w("**골드가 들어오는 곳**\n")
    for s in RULES["economy"]["income"]:
        w("- " + s)
    w("\n**골드가 나가는 곳**\n")
    for s in RULES["economy"]["outgo"]:
        w("- " + s)
    w("")
    w("- " + RULES["economy"]["sell"])
    w("- " + RULES["economy"]["reroll"])
    w("- 판매 스프레드(구매가 − 판매가) = 2 / 4 / 6 / 7. 이것이 "
      "\"한 정산만 빌려 쓰고 되팔기\" 의 손익선이다.\n")
    w("**상점 규칙**\n")
    for k in ("when", "stock", "weighted", "mods", "voucher", "physics"):
        w("- " + RULES["shop"][k])
    w("\n---\n")

    # 17 screens
    w("## 17. 화면과 조작\n")
    w("**상태 기계** (`enum S`)\n")
    st_ko = {
        "PICK": "다트 고르기", "AIM_V": "조준 1축", "AIM_H": "조준 2축",
        "CONFIRM": "확인 텀", "FLY": "비행", "RESOLVE": "정산",
        "CLEAR": "판 정산(골드 내역)", "SHOP": "상점", "STAGE": "제약 선택",
        "OVER": "런 종료", "TITLE": "제목", "SETTINGS": "설정(게임 중엔 일시정지)",
        "COLLECT": "컬렉션", "NEWRUN": "새 런 설정", "BLIND": "판 선택",
    }
    w(md_table(["상태", "화면"], [[s, st_ko.get(s, "")] for s in CODE["screen"]["STATES"]]))
    w("\n**조작**\n")
    w(md_table(["입력", "하는 일"], [
        ["마우스 왼쪽 클릭", "모든 화면의 기본 입력. 조준 잠금 · 구매 · 카드 선택"],
        ["마우스 드래그", "상점 — 매물을 계산대로 민다 / 랙 — 스티커 순서 바꾸기·판매"],
        ["스페이스", "진행(조준 잠금 · 다음 판 · 새 런 시작)"],
        ["ESC", "설정 열기(일시정지) · 선택 취소 · 뒤로"],
        ["F11", "전체화면"],
        ["[ / ]", "조준 게이지 속도 −0.05 / +0.05 (범위 0.15~4.0)"],
        ["− / =", "정산 박자 +0.03 / −0.03 (범위 0.08~1.0)"],
        ["; / '", "확인 텀 −0.05 / +0.05 (범위 0~1.5)"],
    ]))
    w("\n**화면 구성**\n")
    w("- 뷰포트 %d × %d, 정수 배율 확대(`stretch/aspect = keep`). "
      "모든 좌표가 이 전제 위에 서 있다." % tuple(CODE["screen"]["VIEW"]))
    w("- 다트판 중심 (%g, %g), 반지름 %s px." % (CODE["screen"]["BOARD_CENTER"][0],
                                                CODE["screen"]["BOARD_CENTER"][1],
                                                TUNE["board_r"]))
    w("- 상시 HUD — 상단바(목표·총점) · 자금판 · 스티커 랙 · 소비 칸 · 남은 다트 부채.")
    w("- 상점은 오버헤드 정사영(앙각 52°)으로 그린 펠트 테이블이다. 딜러가 매물을 던지고 쓸어 담는다.")
    w("- 테이블 화면 ↔ 다트판 화면은 판이 누운 채 올라와 서는 전환 연출로 잇는다.\n")
    w("**팔레트** (코드 상수)\n")
    w(md_table(["이름", "hex", "쓰임"],
               [[k, v, {"C_BG": "배경", "C_LIGHT": "밝은 칸", "C_DARK": "어두운 칸",
                        "C_RED": "더블 띠", "C_GREEN": "트리플 띠", "C_WIRE": "철선",
                        "C_TXT": "글자", "C_DIM": "흐린 글자", "C_ACC": "강조(희귀)",
                        "C_PANEL": "패널", "C_CHIP": "칩(점수)", "C_MULT": "배수",
                        "C_GOLD": "골드", "C_FELT": "랙 펠트", "C_TABLE": "상점 펠트",
                        "C_WOOD": "나무", "C_DIECUT": "스티커 다이컷 테두리",
                        "C_LINER": "이형지"}.get(k, "")]
                for k, v in sorted(CODE["screen"]["PALETTE"].items())]))
    w("\n**소리** — 오디오 파일이 없다. `AudioStreamGenerator` 로 사인파를 실시간 합성한다. "
      "정산 걸음마다 392Hz 에서 반음씩 올라간다.\n")
    w("---\n")

    # 18 save
    w("## 18. 저장 · 해금 · 통계\n")
    w("- " + RULES["meta"]["save"])
    w("- " + RULES["meta"]["unlock_packs"])
    w("- " + RULES["meta"]["unlock_stakes"])
    w("- 해금 키는 갈래를 앞에 둔다 — `pack:mag` · `stake:green`.\n")
    w("**통계 키** (해금 조건이 읽는다. 조건보다 먼저 세기 시작한다)\n")
    stat_ko = {
        "runs": "시작한 런", "wins": "완주", "darts": "던진 다트", "triples": "트리플",
        "doubles": "더블", "bulls": "불", "misses": "빗나감",
        "items_bought": "산 스티커", "mods_bought": "산 개조", "darts_bought": "산 다트",
        "cons_used": "쓴 소비 아이템", "rerolls": "새로고침", "sold": "판 스티커",
        "gold_earned": "번 골드", "skips": "건너뛴 판", "vouchers_bought": "산 설비",
        "best_round": "최고 도달 판", "best_score": "한 판 최고 점수",
        "best_gold": "최고 보유 골드", "best_track": "최고 트랙 레벨",
    }
    w(md_table(["키", "뜻", "연산"],
               [[k, stat_ko.get(k, ""), "최댓값" if k in CODE["save"]["PEAKS"] else "누적"]
                for k in CODE["save"]["STATS"]]))
    w("\n---\n")

    # 19 vocab
    w("## 19. 어휘 사전\n")
    w("### 19-1. 발동 조건 (`cond`) — %d가지\n" % len(CODE["vocab"]["CONDS"]))
    # sec·col 은 인자를 받는 조건이라 표에 그 꼴로 적는다. 맨 이름으로는 안 선다.
    PARAM = {"sec": ("sec:20,5", "20·5번"), "col": ("col:1", "먹")}
    rows = []
    for c in CODE["vocab"]["CONDS"]:
        if c in PARAM:
            ex, tag = PARAM[c]
            rows.append(["`%s`" % ex, tag, cond_text(ex)])
        else:
            rows.append([c, g(COND_TAG.get(c)), g(cond_text(c))])
    w(md_table(["cond", "짧은 말", "카드 문장"], rows))
    w("")
    w("- `sec:N,M` — 지정한 번호 칸에 명중. `col:N` — 지정한 색 칸에 명중.")
    w("- 빗나가면 명중 조건은 전부 죽는다. 예외는 `miss` 와 `missp` 둘뿐이다.")
    w("- \"…맞힌 뒤\" 패턴 조건은 완성한 그 발이 아니라 **다음 발부터** 선다.\n")
    w("**포함 관계** (`COND_SUB` — A 로 뜨는 다트는 B 로도 뜬다)\n")
    w(md_table(["A", "담는 것 B"],
               [[k, ", ".join(v)] for k, v in (CODE["vocab"]["COND_SUB"] or {}).items()]))
    w("\n**완전분할** (`COND_PART` — 같은 효과로 한 분할을 다 덮으면 무조건 카드가 된다)\n")
    for p in CODE["vocab"]["COND_PART"] or []:
        w("- " + " + ".join(p))
    w("\n### 19-2. 용어\n")
    w(md_table(["게임 안 말", "코드 이름", "뜻"], [
        ["스티커", "item / owned", "발라트로의 조커. 랙에 %d칸" % TUNE["max_items"]],
        ["개조", "mod / mods_own", "판의 기하를 바꾸는 영구 구매"],
        ["탄창", "magazine", "이 런의 다트 구성"],
        ["제약", "modifier / active_mods", "보스 판에 걸리는 페널티. 셋 중 하나를 고른다"],
        ["딱지", "tag / pending_tags", "판을 건너뛴 값"],
        ["설비", "voucher / shelf", "런 내내 남는 영구 업그레이드"],
        ["팩", "pack", "스타트팩. 발라트로의 덱"],
        ["리그", "stake", "난이도 단계. 발라트로의 스테이크"],
        ["앤티", "ante", "라운드 묶음. 앤티 하나에 판 %d개" % BLINDS_PER],
        ["판", "round / round_no", "블라인드 하나. 런 전체에서 1..%d" % ROUNDS_N],
        ["칩", "chip / cur_chip", "점수의 앞 수"],
        ["배수", "mult / cur_mult", "점수의 뒤 수"],
        ["영역", "area / track", "착탄 영역. 강화 트랙의 단위"],
        ["정산", "resolve / settle", "한 발의 점수를 큐로 한 걸음씩 세는 것"],
        ["봉인", "seal / sealed", "스티커 하나가 그 판 동안 발동 못 하게 되는 것"],
    ]))
    w("\n---\n")

    # 20 undecided
    w("## 20. 아직 안 정한 것\n")
    w("기획서에 \"미정\" 으로 적어야 하는 자리다. 데이터에 `status` · `enabled` · TODO 로 남아 있다.\n")
    for k, v in RULES["undecided"].items():
        w("- **%s** — %s" % (k, v))
    w("")
    w("**엔진이 아직 못 하는 것** (대기 스티커 %d장의 비고에서 뽑았다)\n" % len(OFF))
    reasons = {}
    for i in OFF:
        n = (i["note"] or "").split("—")[0].strip()
        if n:
            reasons[n] = reasons.get(n, 0) + 1
    w(md_table(["막힌 이유", "장수"],
               sorted(([k, v] for k, v in reasons.items()), key=lambda x: -x[1])))
    w("\n**스펙 워크북 대응표** (`spec_map.csv` — 스펙 문서의 ID 와 게임 ID 를 잇는다)\n")
    w("총 %d행. 상태별 — %s\n" % (
        len(SPEC_MAP),
        " · ".join("%s %d" % (s, sum(1 for r in SPEC_MAP if r.get("status") == s))
                   for s in sorted({r.get("status") for r in SPEC_MAP if r.get("status")}))))
    w("---\n")

    # 21 stats
    w("## 21. 측정 데이터\n")
    w("`data/_stats.csv` — 게임이 **안 읽는** 표다. 밑줄이 그 뜻이다. "
      "`scripts/tools/item_stats.gd` 가 실제 판정 함수에 표본을 통과시켜 덮어쓴다.\n")
    if STATS_CSV:
        s0 = STATS_CSV[0]
        w(md_table(["항목", "값"], [
            ["표본 수", "{:,}".format(s0.get("samples") or 0)],
            ["시드", s0.get("seed")], ["판", s0.get("board")],
            ["조준 모델", s0.get("aim_model")],
            ["측정 행 수", len(STATS_CSV)],
        ]))
    w("")
    w("**열이 뜻하는 것**\n")
    w(md_table(["열", "뜻"], [
        ["fire_pct", "발동률(%) — 이 스티커가 한 발에서 조건을 만족할 확률"],
        ["gain_per_dart", "다트당 기여 점수"],
        ["gain_per_round", "라운드당 기여 점수"],
        ["gain_per_gold", "가격 1골드당 다트당 기여"],
        ["gold_per_round", "라운드당 벌어 주는 골드"],
    ]))
    w("\n**다트당 기여 상위 15**\n")
    top = sorted([s for s in STATS_CSV if s.get("gain_per_dart") is not None],
                 key=lambda s: -s["gain_per_dart"])[:15]
    w(md_table(["id", "이름", "등급", "가격", "발동률%", "다트당", "골드당"],
               [[s["id"], s["name"], RARITY_KO.get(s["rarity"], s["rarity"]), s["cost"],
                 s["fire_pct"], s["gain_per_dart"], s["gain_per_gold"]] for s in top]))
    w("\n---\n")
    w("*이 문서는 자동 생성된다. 고칠 것이 있으면 `data/*.csv` 나 "
      "`scripts/tools/export_kb.py` 를 고치고 다시 돌려라.*")
    return "\n".join(L) + "\n"


def main() -> int:
    os.makedirs(OUT, exist_ok=True)
    j = build_json()
    jp = os.path.join(OUT, "hightone_kb.json")
    with io.open(jp, "w", encoding="utf-8", newline=LF) as f:
        json.dump(j, f, ensure_ascii=False, indent=1)
    mp = os.path.join(OUT, "hightone_kb.md")
    with io.open(mp, "w", encoding="utf-8", newline=LF) as f:
        f.write(build_md())
    print("JSON  %s  (%.1f KB)" % (jp, os.path.getsize(jp) / 1024))
    print("MD    %s  (%.1f KB)" % (mp, os.path.getsize(mp) / 1024))
    print("스티커 %d장(활성 %d) · 표 16장 · 판 %d개"
          % (len(ITEMS), len(ON), ROUNDS_N))
    return 0


if __name__ == "__main__":
    sys.exit(main())
