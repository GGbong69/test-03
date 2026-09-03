#!/usr/bin/env python3
# 사탕 모델 다섯을 아이콘 크기로 다듬어 assets/candy/ 에 놓는다.
#
#     python scripts/tools/prep_candy.py
#
# 아이콘 칸이 26x38px 이다. 삼각형 500 과 256px 텍스처면 넘친다.
# glb 안에 박힌 텍스처는 바이트를 그대로 꺼내 줄여 옆에 jpg 로 둔다 —
# pymeshlab 이 glb 를 못 쓰므로 메시는 obj 로 나간다.

import io
import json
import os
import struct
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
DL = os.path.join(os.path.expanduser("~"), "Downloads")
OUT = os.path.join(ROOT, "assets", "candy")
TEX = 256
FACES = 500

# (내보낼 이름, 원본 파일, 어느 트랙의 사탕인가)
JOBS = [
    ("gummy", "gummy-candy-light.glb", "싱글"),
    ("twist", "Meshy_AI_twist_candy_0903130838_image-to-3d-texture.glb", "더블"),
    ("cane", "candy-cane-light.glb", "트리플"),
    ("pop", "lollipop-candy-light.glb", "불"),
    ("bar", "Meshy_AI_chocolate_bar_0903130824_image-to-3d-texture.glb", "보드 아웃"),
]

MTL = """# %s — prep_candy.py 가 씀
newmtl %s
Kd 1.000 1.000 1.000
map_Kd %s.jpg
"""


def glb_json_bin(path):
    b = open(path, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + n])
    # JSON 청크 뒤가 BIN 청크다. 헤더 8바이트를 건너뛴다.
    off = 20 + n
    blen = struct.unpack("<I", b[off:off + 4])[0]
    return j, b[off + 8:off + 8 + blen]


def base_color(j):
    """베이스 컬러 텍스처의 image 인덱스. 없으면 첫 장."""
    for m in j.get("materials", []):
        p = m.get("pbrMetallicRoughness", {})
        t = p.get("baseColorTexture")
        if t is not None:
            ti = j["textures"][t["index"]]
            if "source" in ti:
                return ti["source"]
    return 0 if j.get("images") else None


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, src, track in JOBS:
        p = os.path.join(DL, src)
        if not os.path.exists(p):
            print("없음: %s" % src)
            continue
        print("── %s  (%s 사탕)" % (name, track))

        j, binb = glb_json_bin(p)
        ii = base_color(j)
        if ii is None:
            print("   텍스처가 없다")
        else:
            bvi = j["images"][ii]["bufferView"]
            bv = j["bufferViews"][bvi]
            o = bv.get("byteOffset", 0)
            raw = binb[o:o + bv["byteLength"]]
            im = Image.open(io.BytesIO(raw)).convert("RGB")
            w0 = im.width
            im = im.resize((TEX, TEX), Image.LANCZOS)
            dst = os.path.join(OUT, name + ".jpg")
            im.save(dst, "JPEG", quality=88, optimize=True)
            print("   텍스처 %d → %d · %.2f MB"
                  % (w0, TEX, os.path.getsize(dst) / 1048576))

        obj = os.path.join(OUT, name + ".obj")
        remesh.run(p, FACES, obj)
        with open(os.path.join(OUT, name + ".mtl"), "w", encoding="utf-8") as fh:
            fh.write(MTL % (name, name, name))
        body = open(obj, encoding="utf-8").read()
        if "mtllib" not in body:
            with open(obj, "w", encoding="utf-8") as fh:
                fh.write("mtllib %s.mtl\nusemtl %s\n%s" % (name, name, body))

    tot = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT))
    print("\nassets/candy/ 합계 %.2f MB" % (tot / 1048576))


if __name__ == "__main__":
    main()
