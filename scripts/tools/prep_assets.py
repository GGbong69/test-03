#!/usr/bin/env python3
# Meshy 산출물을 게임에 들일 꼴로 다듬어 assets/ 에 놓는다.
#
#     python scripts/tools/prep_assets.py
#
# imported_models/ 는 플러그인이 받아 오는 자리라 gitignore 다. 여기서
# 줄이고 깎아 assets/ 로 옮긴 것만 저장소에 들어간다.
#
# 하는 일 셋.
#   1. 메시를 목표 면수까지 줄인다(UV 유지). remesh.run 을 그대로 쓴다.
#   2. 텍스처를 512 로 줄인다 — 화면이 640x360 이라 4096 은 낭비다.
#   3. .mtl 을 써서 obj 가 그 텍스처를 가리키게 한다.
#
# 리깅된 상인은 손대지 않는다. 스킨 가중치가 감축에서 살아남지 않는다.

import os
import shutil
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import remesh

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except AttributeError:
        pass

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "imported_models")
OUT = os.path.join(ROOT, "assets")
TEX = 512

# (이름, 폴더, glb, 목표 면수, 알베도 파일)
JOBS = [
    ("table", "balatro-table-hole-3d", "balatro-table-hole-3d.glb", 8000,
     "balatro-table-hole-3d_base_color.jpg"),
    ("cap", "balatro-hole-cap-3d", "balatro-hole-cap-3d.glb", 2000,
     "balatro-hole-cap-3d_base_color.jpg"),
]

MTL = """# %s — prep_assets.py 가 씀
newmtl %s
Ka 1.000 1.000 1.000
Kd 1.000 1.000 1.000
Ks 0.000 0.000 0.000
Ns 10.0
d 1.0
illum 2
map_Kd %s
"""


def shrink(src, dst, side=TEX):
    im = Image.open(src).convert("RGB")
    im = im.resize((side, side), Image.LANCZOS)
    im.save(dst, "JPEG", quality=88, optimize=True)
    return os.path.getsize(dst)


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, folder, glb, faces, albedo in JOBS:
        d = os.path.join(SRC, folder)
        obj = os.path.join(OUT, name + ".obj")
        print("── %s" % name)
        remesh.run(os.path.join(d, glb), faces, obj)

        tex = os.path.join(OUT, name + "_albedo.jpg")
        n = shrink(os.path.join(d, albedo), tex)
        print("텍스처 %d x %d · %.2f MB" % (TEX, TEX, n / 1048576))

        with open(os.path.join(OUT, name + ".mtl"), "w", encoding="utf-8") as fh:
            fh.write(MTL % (name, name, name + "_albedo.jpg"))
        # pymeshlab 이 쓴 obj 는 mtl 을 안 건다. 머리에 한 줄 얹는다.
        with open(obj, encoding="utf-8") as fh:
            body = fh.read()
        if "mtllib" not in body:
            with open(obj, "w", encoding="utf-8") as fh:
                fh.write("mtllib %s.mtl\nusemtl %s\n%s" % (name, name, body))

    # 상인은 그대로 옮긴다 — 리깅과 애니메이션이 붙어 있다
    dl = os.path.join(SRC, "balatro-dealer-rigged", "Meshy_AI_balatro_dealer_rigged_biped")
    for src_name, dst_name in (
            ("Meshy_AI_balatro_dealer_rigged_biped_Character_output.glb", "dealer.glb"),
            ("Meshy_AI_balatro_dealer_rigged_biped_Animation_Walking_withSkin.glb",
             "dealer_walk.glb")):
        s = os.path.join(dl, src_name)
        if os.path.exists(s):
            shutil.copy2(s, os.path.join(OUT, dst_name))
            print("── %s  %.1f MB (리깅이라 안 줄임)"
                  % (dst_name, os.path.getsize(s) / 1048576))

    tot = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT))
    print("\nassets/ 합계 %.1f MB" % (tot / 1048576))


if __name__ == "__main__":
    main()
