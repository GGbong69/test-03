#!/usr/bin/env python3
# Meshy text-to-3D — 저폴리 형태를 뽑아 models/ 에 떨군다.
#
# 키는 환경변수로만 받는다. 인자로도 파일로도 안 받는다.
#     setx MESHY_API_KEY "..."      (윈도우, 새 셸부터 적용)
#     export MESHY_API_KEY="..."    (bash)
#
# 사용:
#     python scripts/tools/meshy_gen.py "worn brass dart, low poly" --name dart_std --poly 200
#     python scripts/tools/meshy_gen.py "..." --name bar_backbar --poly 800 --refine
#
# models/ 는 gitignore 된다. 저장소에 안 들어간다.

import argparse, json, os, sys, time, urllib.request, urllib.error
from pathlib import Path

# 윈도우 기본 콘솔이 cp949 라 한글·em dash 에서 죽는다. 출력을 UTF-8 로 고정한다.
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except AttributeError:
        pass

API = "https://api.meshy.ai/openapi/v2/text-to-3d"
OUT = Path(__file__).resolve().parents[2] / "models"


def key():
    k = os.environ.get("MESHY_API_KEY", "").strip()
    if not k:
        sys.exit("MESHY_API_KEY 가 비어 있다. 환경변수로 넣고 셸을 새로 열어라.")
    return k


def call(method, url, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(url, data=data, method=method)
    req.add_header("Authorization", "Bearer " + key())
    if data:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.loads(r.read().decode())
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:400]
        if e.code == 402:
            sys.exit("크레딧 부족 (402). Meshy 대시보드에서 잔량을 봐라.")
        if e.code == 401:
            sys.exit("키가 거부됐다 (401). MESHY_API_KEY 를 확인해라.")
        sys.exit("HTTP %s — %s" % (e.code, detail))


def wait(task_id, label):
    slept = 0.0
    while True:
        t = call("GET", "%s/%s" % (API, task_id))
        st = t.get("status")
        if st == "SUCCEEDED":
            print("  %s 완료 — 크레딧 %s" % (label, t.get("consumed_credits", "?")))
            return t
        if st in ("FAILED", "CANCELED"):
            sys.exit("%s 실패: %s" % (label, json.dumps(t.get("task_error"), ensure_ascii=False)))
        print("  %s %s%% (%.0fs)" % (label, t.get("progress", 0), slept), end="\r", flush=True)
        time.sleep(5.0)
        slept += 5.0


def fetch(urls, stem, fmts):
    OUT.mkdir(exist_ok=True)
    got = []
    for f in fmts:
        u = urls.get(f)
        if not u:
            continue
        p = OUT / ("%s.%s" % (stem, f))
        with urllib.request.urlopen(u, timeout=180) as r, open(p, "wb") as w:
            w.write(r.read())
        got.append(p)
        print("  %s  (%.1f KB)" % (p, p.stat().st_size / 1024.0))
    return got


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("prompt")
    ap.add_argument("--name", required=True, help="출력 파일 이름(확장자 없이)")
    ap.add_argument("--poly", type=int, default=300, help="목표 삼각형 수 (100~300000)")
    ap.add_argument("--refine", action="store_true", help="정제 단계까지 간다. 크레딧을 더 쓴다")
    ap.add_argument("--formats", default="obj,glb")
    a = ap.parse_args()

    fmts = [x.strip() for x in a.formats.split(",") if x.strip()]
    body = {
        "mode": "preview",
        "prompt": a.prompt,
        "art_style": "realistic",
        "topology": "triangle",
        "target_polycount": max(100, min(300000, a.poly)),
        "should_remesh": True,
        "target_formats": fmts,
    }
    print("preview 요청 — poly %d, 형식 %s" % (body["target_polycount"], ",".join(fmts)))
    tid = call("POST", API, body)["result"]
    print("  task %s" % tid)
    t = wait(tid, "preview")

    if a.refine:
        rid = call("POST", API, {"mode": "refine", "preview_task_id": tid,
                                 "target_formats": fmts})["result"]
        t = wait(rid, "refine")

    files = fetch(t.get("model_urls", {}), a.name, fmts)
    if not files:
        sys.exit("내려받을 파일이 없다. model_urls 가 비었다.")
    print("\n다음: python scripts/tools/obj_to_gd.py models/%s.obj --const %s"
          % (a.name, a.name.upper()))


if __name__ == "__main__":
    main()
