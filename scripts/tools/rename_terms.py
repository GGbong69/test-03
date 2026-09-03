#!/usr/bin/env python3
# 용어를 한 번에 갈아 끼운다.
#
#     python scripts/tools/rename_terms.py --dry            무엇이 바뀌는지만 본다
#     python scripts/tools/rename_terms.py docs             기획서와 문서만
#     python scripts/tools/rename_terms.py docs scripts data 전부
#
# 동시 치환이다. 「스티커 → 동전」과 「가공 → 스티커」가 사슬로 물리면
# 가공이 동전이 되어 버린다. 한 번에 훑어 각 자리를 한 번만 바꾼다.
#
# 파수꾼(같은 말로 가는 짝)이 있어야 긴 말이 먼저 걸린다.
#   트랙 → 트랙        「랙」이 트랙 안을 파먹는 것을 막는다
#   보드 개조 → 보드 확장   「보드 보드 확장」이 되는 것을 막는다

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

RENAME = {
    # ── 파수꾼: 긴 말이 먼저 걸려야 안쪽 짧은 말이 안 바뀐다 ──
    "영역 강화 트랙": "트랙",
    "트랙": "트랙",
    "보드 개조": "보드 확장",
    "스티커 랙": "동전 슬롯",
    "스티커 슬롯": "동전 슬롯",
    "빈 랙": "빈 동전 슬롯",
    "소비 칸": "사탕 칸",
    "소비 슬롯": "사탕 칸",
    "스타트 팩": "다트통",
    "스타트팩": "다트통",
    # ── 실제로 바꾸는 말 ──
    "칩": "기본 점수",
    "스티커": "동전",
    "랙": "동전 슬롯",
    "개조": "보드 확장",
    "영역 강화": "트랙 강화",
    "소비 아이템": "사탕",
    "소비": "사탕",          # 홑말. 긴 것 뒤에 와야 한다
    "가공": "스티커",
    "매대": "테이블",
    "딜러": "상인",
    "새로고침": "리롤",
    "설비": "사진",
    "딱지": "뱃지",
    "팩": "다트통",
}

PAT = re.compile("|".join(sorted((re.escape(k) for k in RENAME), key=len, reverse=True)))

EXT = {".gd", ".csv", ".md", ".json", ".py", ".tscn", ".cfg"}
# 이 둘은 사전 자체를 들고 있다. 훑으면 사전의 왼쪽까지 바뀌어 뜻이 뒤집힌다.
SKIP_FILE = {"rename_terms.py", "make_deck.py"}
SKIP = {".godot", ".git", "imported_models", "addons", "__pycache__", "shots",
        "export", "테스트버전"}


def swap(s):
    return PAT.sub(lambda m: RENAME[m.group(0)], s)


def walk(roots):
    for r in roots:
        base = os.path.join(ROOT, r)
        if os.path.isfile(base):
            yield base
            continue
        for dirpath, dirs, files in os.walk(base):
            dirs[:] = [d for d in dirs if d not in SKIP]
            for f in files:
                if os.path.splitext(f)[1] in EXT and f not in SKIP_FILE:
                    yield os.path.join(dirpath, f)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("roots", nargs="*", default=["docs"])
    ap.add_argument("--dry", action="store_true")
    a = ap.parse_args()

    total, touched = 0, 0
    for path in walk(a.roots or ["docs"]):
        try:
            old = open(path, encoding="utf-8").read()
        except (UnicodeDecodeError, OSError):
            continue
        new = swap(old)
        if new == old:
            continue
        n = sum(1 for _ in PAT.finditer(old) if True)
        hits = sum(1 for m in PAT.finditer(old) if RENAME[m.group(0)] != m.group(0))
        total += hits
        touched += 1
        print("%-52s %d곳" % (os.path.relpath(path, ROOT), hits))
        if not a.dry:
            open(path, "w", encoding="utf-8", newline="").write(new)
    print("\n파일 %d개 · %d곳%s" % (touched, total, " (미리보기)" if a.dry else " 바꿈"))


if __name__ == "__main__":
    main()
