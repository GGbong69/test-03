# 찍은 표본에서 한 조각을 잘라 키운다. 눈으로 판정하는 자리라,
# 12px 짜리 그림을 1:1 로 봐서는 아무것도 안 보인다.
#   python scripts/tools/art_zoom.py <png> <x> <y> <w> <h> <배율> <나갈곳>
# 좌표는 **논리 640x360** 기준이다(찍힌 그림은 2배다).
import sys
from PIL import Image

src, x, y, w, h, k, out = sys.argv[1:8]
im = Image.open(src)
s = im.width // 640
box = (int(x) * s, int(y) * s, (int(x) + int(w)) * s, (int(y) + int(h)) * s)
im.crop(box).resize((int(w) * int(k), int(h) * int(k)), Image.NEAREST).save(out)
print("%s  %s -> %s" % (src, box, out))
