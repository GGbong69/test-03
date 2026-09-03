#!/usr/bin/env python3
# OBJ → GDScript ArrayMesh 상수.
#
# const 가 아니라 static var 다 — Vector3() 배열은 GDScript 에서 상수식이 아니다.
#
# Meshy 가 뽑은 형태를 파일이 아니라 코드로 들인다. 저장소의 "이미지 0개"
# 규칙이 유지되고, .import 부산물도 .uid 도 안 생긴다.
# _cup3_leaf (scripts/game.gd:9463) 가 이미 쓰는 어법과 같다.
#
# 사용:
#     python scripts/tools/obj_to_gd.py models/dart_std.obj --const DART_STD --height 0.81
#
# 결과는 stdout 으로 나온다. 파일로 받으려면 리다이렉트해라.

import argparse, sys
from pathlib import Path

# 윈도우 기본 콘솔이 cp949 라 한글·em dash 에서 죽는다. 출력을 UTF-8 로 고정한다.
for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except AttributeError:
        pass


def load(path):
    vs, ns, tris = [], [], []
    for ln in Path(path).read_text(encoding="utf-8", errors="replace").splitlines():
        p = ln.split()
        if not p:
            continue
        if p[0] == "v" and len(p) >= 4:
            vs.append((float(p[1]), float(p[2]), float(p[3])))
        elif p[0] == "vn" and len(p) >= 4:
            ns.append((float(p[1]), float(p[2]), float(p[3])))
        elif p[0] == "f" and len(p) >= 4:
            corner = []
            for tok in p[1:]:
                bits = tok.split("/")
                vi = int(bits[0])
                ni = int(bits[2]) if len(bits) > 2 and bits[2] else 0
                corner.append((vi, ni))
            for i in range(1, len(corner) - 1):          # 부채꼴 삼각분할
                tris.append((corner[0], corner[i], corner[i + 1]))
    if not vs or not tris:
        sys.exit("정점이나 면이 없다: %s" % path)
    return vs, ns, tris


def idx(i, n):
    return i - 1 if i > 0 else n + i                     # OBJ 는 음수 색인을 허용한다


def fit(vs, height):
    ys = [v[1] for v in vs]
    xs = [v[0] for v in vs]
    zs = [v[2] for v in vs]
    span = max(ys) - min(ys)
    s = (height / span) if (height and span > 1e-9) else 1.0
    cx = (max(xs) + min(xs)) * 0.5
    cy = (max(ys) + min(ys)) * 0.5
    cz = (max(zs) + min(zs)) * 0.5
    return [((v[0] - cx) * s, (v[1] - cy) * s, (v[2] - cz) * s) for v in vs]


def vec3(v):
    return "Vector3(%.5f, %.5f, %.5f)" % v


def wrap(items, per, ind):
    out, row = [], []
    for it in items:
        row.append(it)
        if len(row) == per:
            out.append(ind + ", ".join(row))
            row = []
    if row:
        out.append(ind + ", ".join(row))
    return ",\n".join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("obj")
    ap.add_argument("--const", required=True, help="상수 이름 (대문자)")
    ap.add_argument("--height", type=float, default=0.0,
                    help="이 높이에 맞춰 균등 축소. 0 이면 원본 크기")
    a = ap.parse_args()

    vs, ns, tris = load(a.obj)
    vs = fit(vs, a.height)

    verts, norms, order, seen = [], [], [], {}
    for tri in tris:
        for vi, ni in tri:
            k = (vi, ni)
            if k not in seen:
                seen[k] = len(verts)
                verts.append(vs[idx(vi, len(vs))])
                norms.append(ns[idx(ni, len(ns))] if (ni and ns) else (0.0, 0.0, 0.0))
            order.append(seen[k])

    name = a.const
    print("# %s — %s 에서 구움. 정점 %d · 삼각형 %d"
          % (name, Path(a.obj).name, len(verts), len(order) // 3))
    print("# 파일은 저장소에 안 들어간다. 이 상수가 형태 전부다.")
    print("static var %s_V := PackedVector3Array([" % name)
    print(wrap([vec3(v) for v in verts], 3, "\t"))
    print("])")
    if ns:
        print("static var %s_N := PackedVector3Array([" % name)
        print(wrap([vec3(n) for n in norms], 3, "\t"))
        print("])")
    print("static var %s_I := PackedInt32Array([" % name)
    print(wrap([str(i) for i in order], 12, "\t"))
    print("])")
    print()
    print("""func _mesh_%s() -> ArrayMesh:
\tvar a := []
\ta.resize(Mesh.ARRAY_MAX)
\ta[Mesh.ARRAY_VERTEX] = %s_V""" % (name.lower(), name))
    if ns:
        print("\ta[Mesh.ARRAY_NORMAL] = %s_N" % name)
    print("""\ta[Mesh.ARRAY_INDEX] = %s_I
\tvar m := ArrayMesh.new()
\tm.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
\treturn m""" % name)


if __name__ == "__main__":
    main()
