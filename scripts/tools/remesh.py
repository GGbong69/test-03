#!/usr/bin/env python3
# 폴리곤을 줄인다. Meshy 가 뽑는 것은 200만 삼각형대라 640x360 화면엔 못 쓴다.
#
#     python scripts/tools/remesh.py imported_models/Dart/Dart.glb --faces 500
#     python scripts/tools/remesh.py <glb> --faces 3000 --out models/table.glb
#
# UV 가 있으면 텍스처를 지키는 감축을 쓴다. 없으면 일반 감축이다.
# 결과는 원본 옆에 <이름>_<면수>.obj 로 떨어진다. pymeshlab 은 glb 를 못 쓴다.

import argparse
import os
import sys
import time

import pymeshlab

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except AttributeError:
        pass


def run(src, faces, out=None, quality=0.3, flat=False):
    ms = pymeshlab.MeshSet()
    t0 = time.time()
    ms.load_new_mesh(src)
    m = ms.current_mesh()
    f0, v0 = m.face_number(), m.vertex_number()
    has_uv = (m.has_wedge_tex_coord() or m.has_vertex_tex_coord()) and not flat
    # 텍스처를 지키는 갈래는 6만쯤에서 더 안 내려간다 — UV 이음매가 벽이다.
    # 평면 색으로 쓸 것이면 UV 를 버리고 줄여야 목표까지 간다.
    print("읽음  면 {:,} · 정점 {:,} · UV {} · {:.1f}초"
          .format(f0, v0, "있음" if has_uv else "없음", time.time() - t0))

    t0 = time.time()
    opts = dict(targetfacenum=faces, qualitythr=quality,
                preserveboundary=True, preservenormal=True,
                planarquadric=True, autoclean=True)
    # 한 번으로는 목표까지 안 간다 — Meshy 메시는 첫 판에서 3% 쯤에 멈춘다.
    # 같은 필터를 다시 걸면 그 자리에서 또 내려간다. 안 줄면 멈춘다.
    prev = f0
    for _ in range(12):
        if has_uv:
            o = dict(opts)
            o.pop("autoclean", None)      # 텍스처 갈래는 이 인자를 안 받는다
            ms.meshing_decimation_quadric_edge_collapse_with_texture(**o)
        else:
            ms.meshing_decimation_quadric_edge_collapse(**opts)
        n = ms.current_mesh().face_number()
        if n <= faces * 1.07 or n >= prev * 0.98:
            break
        prev = n
    m = ms.current_mesh()
    print("줄임  면 {:,} → {:,} ({:.3f}%) · {:.1f}초"
          .format(f0, m.face_number(), m.face_number() * 100.0 / max(1, f0),
                  time.time() - t0))

    if out is None:
        base, _ = os.path.splitext(src)
        out = "%s_%d.obj" % (base, m.face_number())
    if out.lower().endswith(".glb"):
        out = out[:-4] + ".obj"      # pymeshlab 은 glb 쓰기를 모른다
    # glb 안에 박힌 텍스처는 이름에 확장자가 없어 MeshLab 이 못 쓴다.
    # 텍스처는 원본 옆의 jpg 를 그대로 쓰면 되므로 메시만 내보낸다.
    ms.save_current_mesh(out, save_textures=False)
    print("씀    %s · %.2f MB" % (out, os.path.getsize(out) / 1048576))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("--faces", type=int, required=True, help="목표 삼각형 수")
    ap.add_argument("--out", default=None)
    ap.add_argument("--flat", action="store_true",
                    help="UV 를 버리고 줄인다. 평면 색으로 쓸 때")
    ap.add_argument("--quality", type=float, default=0.3,
                    help="낮을수록 더 과감하게 줄인다 (기본 0.3)")
    a = ap.parse_args()
    run(a.src, a.faces, a.out, a.quality, a.flat)


if __name__ == "__main__":
    main()
