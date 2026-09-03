#!/usr/bin/env python3
# 이름을 갈아 끼운 뒤 어긋난 조사를 바로잡는다.
#
#     python scripts/tools/fix_particles.py --dry docs scripts data
#     python scripts/tools/fix_particles.py docs scripts data
#
# 「스티커를」이 「동전를」이 된다. 받침이 바뀌었기 때문이다. 갈아 끼운
# 말들 뒤에 붙은 조사만 골라 받침에 맞게 되돌린다.

import argparse
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except AttributeError:
        pass

# 갈아 끼운 말. 긴 것부터 잡는다.
WORDS = [
    "동전 슬롯", "기본 점수", "보드 확장", "트랙 강화", "다트통",
    "테이블", "스티커", "동전", "장갑", "상인", "사탕", "뱃지", "리롤",
]

# (받침 있을 때, 받침 없을 때)
PAIRS = [("이", "가"), ("을", "를"), ("은", "는"), ("과", "와"), ("으로", "로")]


def tail(ch):
    """마지막 글자의 받침. 없으면 0, ㄹ 이면 8."""
    if not ("가" <= ch <= "힣"):
        return -1
    return (ord(ch) - 0xAC00) % 28


def right(word, pair):
    t = tail(word[-1])
    if t < 0:
        return None
    has = t != 0
    if pair == ("으로", "로"):
        # ㄹ 받침은 「로」를 쓴다 — 「테이블로」지 「테이블으로」가 아니다
        return "로" if (not has or t == 8) else "으로"
    return pair[0] if has else pair[1]


RULES = []
for w in WORDS:
    for pair in PAIRS:
        ok = right(w, pair)
        if ok is None:
            continue
        wrong = [p for p in pair if p != ok]
        for bad in wrong:
            RULES.append((w, bad, ok))

# 긴 말 · 긴 조사부터
RULES.sort(key=lambda r: (-len(r[0]), -len(r[1])))
PAT = re.compile("|".join("(?P<g%d>%s%s)" % (i, re.escape(w), re.escape(b))
                          for i, (w, b, _) in enumerate(RULES)))
FIX = {("g%d" % i): (w + g) for i, (w, _, g) in enumerate(RULES)}

EXT = {".gd", ".csv", ".md", ".json", ".py", ".tscn"}
SKIP_DIR = {".godot", ".git", "imported_models", "addons", "__pycache__",
            "shots", "export", "테스트버전"}
SKIP_FILE = {"fix_particles.py", "rename_terms.py"}


def swap(s):
    def one(m):
        for k, v in FIX.items():
            if m.group(k):
                return v
        return m.group(0)
    return PAT.sub(one, s)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("roots", nargs="*", default=["docs"])
    ap.add_argument("--dry", action="store_true")
    a = ap.parse_args()

    total = 0
    for r in a.roots or ["docs"]:
        base = os.path.join(ROOT, r)
        for dirpath, dirs, files in os.walk(base):
            dirs[:] = [d for d in dirs if d not in SKIP_DIR]
            for f in files:
                if os.path.splitext(f)[1] not in EXT or f in SKIP_FILE:
                    continue
                path = os.path.join(dirpath, f)
                try:
                    old = open(path, encoding="utf-8").read()
                except (UnicodeDecodeError, OSError):
                    continue
                new = swap(old)
                if new == old:
                    continue
                n = sum(1 for _ in PAT.finditer(old))
                total += n
                print("%-46s %d곳" % (os.path.relpath(path, ROOT), n))
                if a.dry:
                    for m in list(PAT.finditer(old))[:4]:
                        print("      %s → %s" % (m.group(0), swap(m.group(0))))
                else:
                    open(path, "w", encoding="utf-8", newline="").write(new)
    print("\n%d곳%s" % (total, " (미리보기)" if a.dry else " 고침"))


if __name__ == "__main__":
    main()
