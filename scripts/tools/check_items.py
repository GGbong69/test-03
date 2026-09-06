#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# data.gd 의 동전 검사를 파이썬으로 흉내 낸다.
#
#     python scripts/tools/check_items.py
#
# Godot 이 없는 자리에서 표를 고칠 때 쓰는 임시 자다. **진짜 자는 게임 안의
# 검증기다** — 이 파일은 data.gd 를 베낀 것이라 언젠가 어긋난다. 표를 고친
# 뒤에는 반드시 한 번 돌린다:
#
#     godot --headless --script scripts/tools/validate.gd
#
# 옮겨 온 검사는 넷이다. data.gd 의 _v_items 가 원본이다.
#   ① 칸 값이 어휘 안에 있는가          (모르는 조건 · 효과 · 성장 · 골드)
#   ② 조준 동전에 발동 조건이 붙었는가
#   ③ 상위호환 — 조건이 상대를 담고 값이 크고 값이 싸면 그 상대는 안 팔린다
#   ④ 완전분할 — 한 분할을 같은 효과로 다 덮으면 조건이 사라진다
import csv
import os
import sys

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except AttributeError:
        pass

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "data", "items.csv")

CONDS = ["always", "triple", "double", "band", "bull", "odd", "even", "left",
         "right", "big", "mid", "small", "same", "diff", "first", "last",
         "streak", "warm", "miss", "missp",
         "risk", "risk1", "few", "sixth",
         "pair", "trip", "quad", "pair2", "spread",
         "zone3", "zones2", "zones4", "rezone", "sec", "col"]
KINDS = ["chip", "mult", "xmult", "mult_streak", "mult_rand", "save"]
GOLDS = ["clear", "spare", "clean", "blitz", "broke", "leg", "risk50", "hit"]
GROWS = ["fire", "hitmiss", "tdec", "rdec"]
BOOMS = ["r6", "r1000"]
SIDES = ["trackup25"]
PERS = ["darts_left", "items", "gold", "gold5", "mag_hvy", "missing", "low",
        "zonehist", "rackval", "empty"]
AIMS = ["ring", "tilt", "cross", "drift", "place", "pull", "kick"]
RARITIES = ["common", "uncommon", "rare", "legendary"]

COND_SUB = {
    "always": ["triple", "double", "band", "bull", "odd", "even", "left", "right",
               "big", "mid", "small", "same", "diff", "first", "last", "streak",
               "warm", "risk", "risk1", "few", "sixth", "pair", "trip", "quad",
               "pair2", "spread", "zone3", "zones2", "zones4", "rezone", "sec"],
    "risk": ["triple", "double", "band", "bull", "risk1"],
    "band": ["triple", "double"],
    "same": ["streak"], "streak": ["same"],
    "diff": ["first"],
    "pair": ["trip", "quad", "pair2"],
    "trip": ["quad"],
    "zones2": ["zones4"],
}
COND_PART = [["left", "right"], ["odd", "even"], ["mid", "big", "small"]]
COST_RARITY = {4: "common", 8: "uncommon", 12: "rare", 20: "legendary"}


def closure():
    """COND_SUB 를 전이폐포로 닫는다. data.gd 의 _sub_closure 와 같은 일이다."""
    sub = {k: set(v) for k, v in COND_SUB.items()}
    changed = True
    while changed:
        changed = False
        for k in list(sub):
            for c in list(sub[k]):
                for d in sub.get(c, ()):
                    if d not in sub[k]:
                        sub[k].add(d)
                        changed = True
    return sub


def i(r, k):
    v = r.get(k, "").strip()
    try:
        return int(v)
    except ValueError:
        return 0


def main():
    rows = list(csv.DictReader(open(SRC, encoding="utf-8-sig")))
    errs, warns = [], []
    sub = closure()

    for r in rows:
        who = "%s(%s)" % (r["name"], r["id"])
        if not 3 <= len(r["id"]) <= 4:
            errs.append("%s — id 는 3~4 글자여야 한다" % who)
        if r["rarity"] not in RARITIES:
            errs.append("%s — 모르는 등급 '%s'" % (who, r["rarity"]))
        if r["enabled"].strip() == "0":
            continue                       # 꺼진 행은 자리다
        aimed = r["aim"].strip() != ""
        if aimed and r["cond"].strip():
            errs.append("%s — 조준 동전에 발동 조건이 붙었다" % who)
        if not aimed and r["cond"] not in CONDS:
            errs.append("%s — 모르는 조건 '%s'" % (who, r["cond"]))
        if r["kind"].strip() == "":
            if not aimed and not (r["gold"].strip() or r["dadd"].strip()
                                  or r["side"].strip()):
                errs.append("%s — 효과도 부가도 없는 빈 카드다" % who)
        elif r["kind"] not in KINDS:
            errs.append("%s — 모르는 효과 '%s'" % (who, r["kind"]))
        if r["kind"].strip() and r["grow"] not in ("fire", "hitmiss") \
                and i(r, "value") <= 0:
            errs.append("%s — 값이 0 이하다" % who)
        for col, vocab, lab in (("grow", GROWS, "성장"), ("boom", BOOMS, "파괴"),
                                ("side", SIDES, "부가"), ("per", PERS, "배율원"),
                                ("aim", AIMS, "조준"), ("gold", GOLDS, "골드 조건")):
            if r[col].strip() and r[col] not in vocab:
                errs.append("%s — 모르는 %s '%s'" % (who, lab, r[col]))
        if r["cond"] == "sec" and not r["secs"].strip():
            errs.append("%s — sec 조건인데 secs 칸이 비었다" % who)
        if r["gold"].strip() and i(r, "gv") <= 0:
            errs.append("%s — 골드 값이 0 이하다" % who)
        if i(r, "cost") <= 0:
            errs.append("%s — 가격이 0 이하다" % who)
        want = COST_RARITY.get(i(r, "cost"), "")
        if want == "":
            warns.append("%s — 가격 %d 는 등급 사다리(4·8·12) 밖이라 등급과 "
                         "대조할 수 없다" % (who, i(r, "cost")))
        elif r["rarity"] != want:
            warns.append("%s — 가격 %s 는 보통 %s 인데 %s 다"
                         % (who, r["cost"], want, r["rarity"]))

    live = [r for r in rows if r["enabled"].strip() != "0"]
    same = ("gold", "per", "grow", "k2", "dadd", "boom", "side", "secs")
    for a in live:
        for b in live:
            if a["id"] == b["id"] or a["kind"] != b["kind"]:
                continue
            if a["aim"].strip() or b["aim"].strip():
                continue
            if any(a[c] != b[c] for c in same):
                continue
            if a["grow"].strip():
                continue
            ca, cb = a["cond"], b["cond"]
            if not (ca == cb or cb in sub.get(ca, ())):
                continue
            # save 는 값이 낮을수록 세다 — data.gd 와 같은 예외를 둔다
            av, bv = i(a, "value"), i(b, "value")
            beats = av <= bv if a["kind"] == "save" else av >= bv
            if beats and i(a, "cost") <= i(b, "cost"):
                errs.append("%s(%s) 가 %s(%s) 의 상위호환이다"
                            % (a["name"], a["id"], b["name"], b["id"]))

    for part in COND_PART:
        for kk in KINDS:
            cov = [c for c in part
                   if any(r["cond"] == c and r["kind"] == kk for r in live)]
            if len(cov) == len(part):
                who = [r["name"] for r in live
                       if r["cond"] in part and r["kind"] == kk]
                warns.append("완전분할 — %s 를 %s 가 다 덮는다: %s"
                             % (" · ".join(part), kk, " · ".join(who)))

    for w in warns:
        print("경고: " + w)
    for e in errs:
        print("오류: " + e)
    print("\n동전 %d장 (켜짐 %d) — 오류 %d · 경고 %d"
          % (len(rows), len(live), len(errs), len(warns)))
    print("이 자는 흉내다. 진짜 검증은 godot --headless --script "
          "scripts/tools/validate.gd")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
