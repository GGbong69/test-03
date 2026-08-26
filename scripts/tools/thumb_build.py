# -*- coding: utf-8 -*-
"""썸네일 합성.

thumb.gd 가 shots/tb_*.png 로 떨군 소재를 1280×720 한 장으로 합친다.
게임 화면은 draw_* 로 그은 벡터라 3배(1920×1080)로 찍혀 있다. 여기서는
그 원해상도에서 잘라 쓰고, 줄일 때만 줄인다 — 늘리지 않는다.

빛과 그늘은 게임 안에서 주지 않고 여기서 준다. 게임 쪽 hit_flash 로
불을 태워 봤더니 가운데가 분홍 얼룩으로 떴다. 세기를 눈으로 맞출 수
있는 자리는 여기다.

실행:  python scripts/tools/thumb_build.py
결과:  shots/thumb_a.png · thumb_b.png · thumb_c.png
"""

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SRC = "shots"
OUT = "shots"
W, H = 1280, 720

BG   = (0x14, 0x11, 0x1f)      # C_BG   밤의 벽
ACC  = (0xf2, 0xb1, 0x34)      # C_ACC  간판 불빛
GOLD = (0xf2, 0xc9, 0x4c)      # C_GOLD

#  판 소재(tb_board.png) 안에서 판 한가운데가 있는 자리. thumb.gd 의 _look 이
#  판 중심을 뷰포트 한가운데에 놓으므로 1920×1080 의 정가운데다. 여기를
#  BC×3 (960,588) 로 잡았다가 원 마스크가 48px 내려앉아 위쪽 숫자를 잘랐다.
BOARD_C = (960, 540)
#  게임 좌표의 판 바깥 반지름 = board_r(106) × 1.07. 픽셀 환산의 기준.
BOARD_RU = 106.0 * 1.07
#  판에 꽂아 둔 다트 세 발의 자리 (BC 기준 게임 좌표). thumb.gd 와 같은 값.
DARTS_U = [(-2.0, 1.0), (-5.81, -64.40), (7.33, -66.38)]


def load(name):
    return Image.open(f"{SRC}/{name}").convert("RGB")


def cutout(img, bg, thr=8.0, feather=7.0):
    """단색 배경을 알파로 판다. 배경이 딱 한 색이라 색차만 보면 된다."""
    a = np.asarray(img, dtype=np.float32)
    d = np.abs(a - np.asarray(bg, dtype=np.float32)).max(axis=2)
    al = np.clip((d - thr) / feather, 0.0, 1.0)
    return Image.fromarray(np.dstack([a, al * 255.0]).astype(np.uint8), "RGBA")


def board_layer(diameter):
    """판을 배경 없이, 원하는 지름으로.

    네모로 잘라 오면 왼쪽 탄창 열의 다트가 같이 딸려 온다 (한 번 나왔다 —
    판 옆에 다트 한 자루가 허공에 떠 있었다). 숫자까지만 남기고 원으로 자른다.
    """
    half = 400
    keep = 392.0
    x, y = BOARD_C
    im = load("tb_board.png").crop((x - half, y - half, x + half, y + half))
    cut = np.asarray(cutout(im, BG), np.float32)
    yy, xx = np.mgrid[0:half * 2, 0:half * 2].astype(np.float32)
    r = np.sqrt((xx - half) ** 2 + (yy - half) ** 2)
    cut[:, :, 3] *= np.clip((keep - r) / 3.0, 0.0, 1.0)
    lay = Image.fromarray(cut.astype(np.uint8), "RGBA")
    n = int(round(half * 2 * diameter / (BOARD_RU * 3.0 * 2.0)))
    return lay.resize((n, n), Image.LANCZOS)


def dart_glow(size, center, diameter, radius, peak):
    """꽂힌 자리마다 작은 빛. 작게 줄이면 다트가 제일 먼저 사라진다."""
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    k = diameter / (BOARD_RU * 2.0)
    a = np.zeros((h, w), np.float32)
    for i, (ux, uy) in enumerate(DARTS_U):
        cx = center[0] + ux * k
        cy = center[1] + uy * k
        # 첫 발은 불에 꽂힌 것이다. 여기에 같은 빛을 주면 불의 빨강이
        # 노랑에 먹혀 가운데가 뿌옇게 뜬다 — 절반만 준다.
        m = 0.45 if i == 0 else 1.0
        r = np.sqrt((xx - cx) ** 2 + (yy - cy) ** 2) / (radius * (0.7 if i == 0 else 1.0))
        a = np.maximum(a, np.clip(1.0 - r, 0.0, 1.0) ** 2.0 * peak * m)
    rgb = np.zeros((h, w, 3), np.float32) + np.asarray(GOLD, np.float32)
    return Image.fromarray(np.dstack([rgb, a * 255.0]).astype(np.uint8), "RGBA")


def glow(size, center, radius, color, peak, squash=1.0):
    """따뜻한 빛 웅덩이. 천장 등 하나가 판 위에 걸린 것처럼."""
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dx = (xx - center[0]) / radius
    dy = (yy - center[1]) / (radius * squash)
    r = np.sqrt(dx * dx + dy * dy)
    a = np.clip(1.0 - r, 0.0, 1.0) ** 2.2 * peak
    rgb = np.zeros((h, w, 3), np.float32) + np.asarray(color, np.float32)
    return Image.fromarray(np.dstack([rgb, a * 255.0]).astype(np.uint8), "RGBA")


def shadow(size, center, radius, peak, squash=1.0, blur=40):
    w, h = size
    im = Image.new("L", (w, h), 0)
    ImageDraw.Draw(im).ellipse(
        [center[0] - radius, center[1] - radius * squash,
         center[0] + radius, center[1] + radius * squash],
        fill=int(peak * 255))
    im = im.filter(ImageFilter.GaussianBlur(blur))
    return Image.merge("RGBA", (Image.new("L", (w, h), 0),) * 3 + (im,))


def vignette(size, strength=0.55, inner=0.55):
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    dx = (xx - w * 0.5) / (w * 0.5)
    dy = (yy - h * 0.5) / (h * 0.5)
    r = np.sqrt(dx * dx + dy * dy) / 1.414
    a = np.clip((r - inner) / (1.0 - inner), 0.0, 1.0) ** 1.6 * strength
    z = np.zeros((h, w, 3), np.float32)
    return Image.fromarray(np.dstack([z, a * 255.0]).astype(np.uint8), "RGBA")


def table_band(top, out_h, feather, lo, hi, bot=742, left=100):
    """딜러와 펠트. 좌우의 '판매/구매' 글자는 잘라 내고, 위쪽은
    어둠으로 흘려 잘린 자리를 지운다. 아래 버튼 줄(y 745~)은 안 쓴다.
    left 는 가로로 미는 값이다 — 딜러의 손이 판 밑에 겹치면 회색 덩어리로
    읽혀서, 판을 비켜 앉도록 옆으로 민다."""
    im = load("tb_sweep.png").crop((left, top, left + 1720, bot))
    im = im.resize((W, out_h), Image.LANCZOS)
    a = np.asarray(im, np.float32)
    # 앞에 있는 것은 어두워야 뒤가 산다. 아래로 갈수록 더 깎는다.
    a = a * np.linspace(hi, lo, out_h, dtype=np.float32)[:, None, None]
    al = np.clip(np.arange(out_h, dtype=np.float32) / max(feather, 1),
                 0.0, 1.0)[:, None]
    al = np.repeat(al, W, axis=1)
    return Image.fromarray(np.dstack([a, al * 255.0]).astype(np.uint8), "RGBA")


def key_light(size, apex, spread, length, color, peak):
    """천장 등이 판 위로 떨어뜨리는 빛. 비어 있는 벽이 그냥 검은 판이
    아니라 어두운 방으로 읽히게 하는 것이 전부다."""
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w].astype(np.float32)
    t = np.clip((yy - apex[1]) / length, 0.0, 1.0)
    half = spread * (0.18 + 0.82 * t)
    d = np.abs(xx - apex[0]) / np.maximum(half, 1.0)
    # 위쪽 끝을 그대로 두면 화면 맨 윗줄에 밝은 띠가 그어진다 (한 번 그었다).
    # 꼭짓점 쪽도 같이 죽여 빛이 화면 밖에서 들어오게 만든다.
    fade = np.clip(t / 0.22, 0.0, 1.0)
    a = np.clip(1.0 - d, 0.0, 1.0) ** 2.0 * (1.0 - t) ** 1.1 * fade * peak
    rgb = np.zeros((h, w, 3), np.float32) + np.asarray(color, np.float32)
    return Image.fromarray(np.dstack([rgb, a * 255.0]).astype(np.uint8), "RGBA")


def grade(a, sat=1.14, con=1.07):
    """색을 조금 세우고 대비를 조금 준다. 유튜브는 320×180 으로 줄여
    보여 주므로, 화면에서 맞는 값은 거기서 대개 물러 보인다."""
    g = a.mean(axis=2, keepdims=True)
    a = g + (a - g) * sat
    return (a - 118.0) * con + 118.0


def grain(size, amp=3.0, seed=7):
    """완전 평평한 어둠은 화면 결함처럼 보인다. 아주 얕게만 흔든다."""
    w, h = size
    rng = np.random.default_rng(seed)
    n = rng.normal(0.0, amp, (h, w, 1)).repeat(3, axis=2)
    return n


def over(base, layer, xy=(0, 0)):
    base.alpha_composite(layer, xy)
    return base


def paste_c(base, layer, c):
    over(base, layer, (int(c[0] - layer.width / 2),
                       int(c[1] - layer.height / 2)))


def finish(im, name):
    a = grade(np.asarray(im.convert("RGB"), np.float32)) + grain((W, H))
    Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(f"{OUT}/{name}")


# ══════════════════════════════════════════════════════════
#  A — 판이 주인공이고 테이블은 앞에 깔린다. 왼쪽이 글자 자리다.
# ══════════════════════════════════════════════════════════
def variant_a():
    c, d = (924, 348), 476
    im = Image.new("RGBA", (W, H), BG + (255,))
    over(im, key_light((W, H), (924, -430), 620, 1180, ACC, 0.17))
    over(im, glow((W, H), (924, 340), 700, ACC, 0.13, 0.88))
    over(im, glow((W, H), (924, 340), 300, GOLD, 0.10, 0.92))
    over(im, shadow((W, H), (936, 378), 268, 0.55, 0.98, 44))
    paste_c(im, board_layer(d), c)
    over(im, dart_glow((W, H), c, d, 40, 0.40))
    over(im, table_band(468, 214, 150, 0.42, 0.78, left=200), (0, H - 214))
    over(im, vignette((W, H), 0.56, 0.50))
    finish(im, "thumb_a.png")


# ══════════════════════════════════════════════════════════
#  B — 가게. 딜러가 서 있고 판은 그 뒤 벽에 걸린다.
# ══════════════════════════════════════════════════════════
def variant_b():
    c, d = (966, 208), 344
    im = Image.new("RGBA", (W, H), BG + (255,))
    over(im, key_light((W, H), (966, -380), 520, 980, ACC, 0.17))
    over(im, glow((W, H), (966, 200), 520, ACC, 0.14, 0.92))
    over(im, glow((W, H), (966, 200), 215, GOLD, 0.10, 0.95))
    over(im, shadow((W, H), (975, 224), 196, 0.55, 1.0, 34))
    paste_c(im, board_layer(d), c)
    over(im, dart_glow((W, H), c, d, 31, 0.42))
    over(im, table_band(120, 462, 130, 0.60, 0.94), (0, H - 462))
    over(im, vignette((W, H), 0.56, 0.50))
    finish(im, "thumb_b.png")


# ══════════════════════════════════════════════════════════
#  C — 판 하나. 320×180 으로 줄여도 뭔지 알아보는 쪽.
# ══════════════════════════════════════════════════════════
def variant_c():
    c, d = (856, 372), 552
    im = Image.new("RGBA", (W, H), BG + (255,))
    over(im, key_light((W, H), (858, -450), 680, 1260, ACC, 0.19))
    over(im, glow((W, H), (858, 356), 740, ACC, 0.14, 1.0))
    over(im, glow((W, H), (858, 356), 310, GOLD, 0.11, 1.0))
    over(im, shadow((W, H), (870, 396), 310, 0.6, 1.0, 48))
    paste_c(im, board_layer(d), c)
    over(im, dart_glow((W, H), c, d, 50, 0.48))
    over(im, vignette((W, H), 0.58, 0.48))
    finish(im, "thumb_c.png")


if __name__ == "__main__":
    variant_a()
    variant_b()
    variant_c()
    print("done")
