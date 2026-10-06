"""포스터 「상점 테이블」(key=shop) — 판형마다 레이어를 짓고 poster_lib.build() 로 굽는다.

  PYTHONIOENCODING=utf-8 python scripts/tools/poster/compose_shop.py <판형 A1|A3|XB> [dpi] [--quick]

원화는 shot_shop.gd 가 outputs/poster/shop/raw/ 에 둔다(층마다 투명 PNG · 15배 9600x5400 ·
shop_meta.json 에 배율과 물건 · 든 동전 자리 · 판형별 진열대). 다트판은 shot_board.gd(시안
「다트판 정면」에서 빌려 온 것)가 outputs/poster/board/render/ 에 둔다(판 · 꽂힌 다트 · 다트 그림자).
배치는 캔버스 너비 · 높이의 비와 게임 논리 px 로 잡는다 — A1 과 A3 는 비율이 같아 그대로 줄어든다.

  게임 화면에서 가운데 띠(논리 x0~x1)만 캔버스 너비에 맞춘다(S = 캔버스 너비 / (x1 − x0)).
  진열대는 판형마다 펠트를 앞으로 늘려 새로 지은 것(shop_table_A · _X)이라 가까운 난간이 캔버스
  밑 10% 언저리에 선다. 물건은 하나씩 따로 찍었으므로 판형마다 제 자리로 옮기고 앞일수록 크게
  놓는다(원근 속임) — 든 동전이 초점이고 나머지가 그 밑을 받치는 호를 그린다. 저울 · 등록기는
  펠트 앞 두 귀퉁이에 온전히 세운다(파는 저울 · 사는 등록기 — 상점). 다트판은 뒤 판자 벽에
  작은 램프 빛을 받고 걸린다(다트 셋 — 하나는 이너 불).
  등급 빛은 게임의 육각 고리(계단 진 띠) 대신 물건 실루엣에서 매끈하게 다시 짓는다.
  네온 제목은 관처럼 — 흰 분홍 심(벡터 제목) · 그 둘레 좁고 진한 분홍 관벽 · 가까운 빛 · 아주 옅은 번짐.

레이어(아래 → 위)
  배경        바탕 · 방(흐림) · 방(선명, 숨김) · 상인 뒤 그늘
  다트판      벽 램프 빛 · 판 그림자 · 판 · 판 그늘 · 다트 그림자 · 다트
  상인        몸통 — 조끼
  진열대      벨벳 · 먼 턱
  물건        (물건마다) 그림자 · 등급 빛 · 몸
  상인 손     손 그림자 · 든 동전 그림자(게임, 숨김) · 든 동전 그림자 · 든 동전 등급 빛(게임, 숨김) ·
              든 동전 빛 · 팔 · 손 · 든 동전 · 집는 검지
  소품        저울(그림자 · 몸) · 금전 등록기(그림자 · 몸)
  진열대 앞   가까운 난간 · 앞판
  빛 · 그림자 위 어둠 · 램프 빛 · 스포트 밖 어둠 · 가장자리 어둠 · 아래 어둠
  네온        번짐 · 빛 · 관벽     (제목 둘레 분홍 빛)
  제목        하이톤 · HIGHTON     (벡터 — .ai 에는 윤곽 경로)
"""
from __future__ import annotations

import json
import math
import os
import sys
import time

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import poster_lib as pl  # noqa: E402

Image.MAX_IMAGE_PIXELS = None

ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
RAW = os.path.join(ROOT, "outputs", "poster", "shop", "raw")
BOARD = os.path.join(ROOT, "outputs", "poster", "board", "render")
OUT = os.path.join(ROOT, "outputs", "poster", "shop")
FONT_KO = os.path.join(ROOT, "fonts", "Paperlogy-5Medium.ttf")
FONT_EN = os.path.join(ROOT, "fonts", "Paperlogy-5Medium.ttf")

#  물건 자리 — (종류, id) → (논리 x, 논리 y(바닥 닿는 점), 크기 배, 돌림 도). 논리 좌표는 늘린
#  진열대의 것(게임 화면 좌표를 아래로 잇는다). 크기는 앞(아래)일수록 크다 — 원근 속임.
GOODS_A = {
    ("boost", "b_big"): (268.0, 194.0, 1.00, 12.0),
    ("cons", "c_bl"): (424.0, 186.0, 0.94, 0.0),
    ("item", "l04"): (293.0, 230.0, 1.04, 0.0),
    ("item", "l05"): (397.0, 228.0, 1.04, 0.0),
    ("dart", ""): (346.0, 238.0, 1.06, 20.0),
}
#  X배너 — 든 동전을 꼭짓점으로 아래로 벌어지는 V(Λ): 동전 곁(팩 · 사탕) → 한 단 아래(동전 둘)
#  → 맨 아래 다트. 앞일수록 크게(원근). 저울 · 등록기는 진열대 뒤 귀퉁이(2026-10-07).
GOODS_X = {
    ("boost", "b_big"): (288.0, 242.0, 1.25, 12.0),
    ("cons", "c_bl"): (410.0, 236.0, 1.22, 0.0),
    ("item", "l04"): (276.0, 318.0, 1.45, 0.0),
    ("item", "l05"): (404.0, 322.0, 1.45, 0.0),
    ("dart", ""): (342.0, 404.0, 1.60, 30.0),
}

#  판형마다 배치. x0 · x1 = 캔버스 너비에 맞추는 게임 화면 논리 x 범위.
#  y0 = 게임 화면 윗변(논리 y 0)이 서는 자리(캔버스 높이 비).
LAYOUT = {
    "A": {
        "x0": 175.0, "x1": 465.0, "y0": 0.240, "table": "A",
        "ko_base": 0.138, "ko_w": 0.54,         # 하이톤 — 기준선 · 글줄 너비(캔버스 너비 비)
        "en_base": 0.194, "en_w": 0.38, "en_track": 0.34,
        #  다트판은 뺐다(2026-10-07 「상점 NPC 얼굴쪽에 다트판에 왜 넣은거야? 넣지마 그냥」). 빈 자리는
        #  띠를 175~465 로 좁혀(장면 1.1배) 상인을 끌어올려 메운다 — 앞판은 그대로 0.1H 안팎.
        "board": None,                          # 다트판 한가운데 x(W) · y(H) · 바깥 숫자 고리 반지름(W) — 2026-10-07 뺐다
        #  벽 램프 웅덩이 — 판 반지름 배 · 세로 배 · 한가운데(판 반지름 단위, + 아래). A 는 판 둘레에만 —
        #  밑으로 번지면 조끼 V 깃이 빛을 받아 판이 상인 머리로 읽혔다.
        "lamp_r": 2.6, "lamp_v": 0.9, "lamp_dy": -0.2,
        #  판 밑 · 몸통 위 가운데 어둠 — 판 아랫변과 조끼 깃 사이를 비워 판이 머리로 안 읽히게
        "neck": (320.0, 34.0, 72.0, 40.0, 0.85),
        "hand_k": 1.0,                          # 든 팔 원근 휨(1 이면 게임 비율 그대로)
        "goods": GOODS_A,
        #  소품 — 몸 한가운데 x(W) · 받침 밑 논리 y · 크기 배. 게임처럼 진열대 뒤 귀퉁이 · 상인 양옆 —
        #  「저울이랑 수금기가 왜 밑에 있어?」(2026-10-07). 손 · 물건 뒤 층이다.
        "props": {"scale": (0.120, 150.0, 0.62), "register": (0.890, 150.0, 0.62)},
        "top_dark": (0.04, 0.20, 0.70),         # 위 어둠 — 다 어두운 끝 · 풀리는 끝(높이 비) · 짙기
        "bot_dark": (296.0, 370.0, 0.62),       # 아래 어둠 — 논리 y 시작 · 끝 · 짙기
        "lamp": (340.0, 205.0, 185.0, 105.0),   # 램프 웅덩이 — 가운데 x · y · 가로 · 세로 반지름(논리)
        "spot": (335.0, 200.0, 200.0, 130.0),   # 스포트 밖 어둠이 풀리는 타원
        "vig": (0.62, 0.55),
    },
    "XB": {
        #  1:3 — 위에 제목, 그 밑에 상인 · 늘린 펠트 · 물건이 세로를 채운다.
        #  네 모서리 고리 구멍(50mm) 안에는 아무것도 안 둔다.
        "x0": 200.0, "x1": 440.0, "y0": 0.200, "table": "X",
        "ko_base": 0.092, "ko_w": 0.70,
        "en_base": 0.122, "en_w": 0.50, "en_track": 0.34,
        "board": None,
        "lamp_r": 2.3, "lamp_v": 1.35, "lamp_dy": 0.30,
        "neck": (320.0, 26.0, 70.0, 44.0, 0.85),   # 판 밑 · 몸통 위 가운데 어둠(논리 x · y · 가로 · 세로 반지름 · 짙기)
        "hand_k": 1.0,
        "goods": GOODS_X,
        "props": {"scale": (0.120, 150.0, 0.70), "register": (0.880, 150.0, 0.70)},
        "top_dark": (0.04, 0.16, 0.80),
        "bot_dark": (466.0, 560.0, 0.62),
        "lamp": (340.0, 250.0, 165.0, 170.0),
        "spot": (335.0, 265.0, 175.0, 200.0),
        "vig": (0.70, 0.52),
    },
}
ROOM = "shop_room_shelves.png"
ROOM_BLUR = 2.2        # 방 흐림 반지름(논리 px)
ROOM_DIM = 1.0
ROOM_SAT = 0.65
SPOT_OUT = 0.30        # 스포트 밖 어둠의 짙기
A_LAMP = 0.20          # 램프 빛

#  색
BG = (7, 5, 9)
NEON_FAR = (255, 60, 150)      # 먼 번짐 — 아주 옅게
NEON_NEAR = (255, 70, 158)     # 가까운 빛
NEON_WALL = (255, 92, 172)     # 관벽 — 심 둘레 좁고 진한 분홍
CORE_KO = (255, 242, 249)      # 심 — 달아오른 관(흰 분홍)
CORE_EN = (255, 236, 246)
LAMP = (255, 206, 146)
COIN = (255, 150, 205)         # 레전더리 분홍
HELD_SH = 0.62                 # 든 동전 그림자 짙기
#  상인 윗동을 녹이는 자리 — 게임 화면 논리 y.
BODY_FADE = (34.0, 92.0)
ARM_FADE = (46.0, 92.0)
#  테두리 빛 — 조끼 옆구리 · 걷은 소매 바깥 테에 따뜻한 뒷빛(술병 선반 빛) 한 줄. 몸통이 거의 검정이라
#  팔이 허공에서 나오는 것처럼 읽혀, 팔이 어깨에서 나오는 사람의 테를 살짝 살린다. 목 · 얼굴 자리는
#  그대로 어둠(RIM_Y — 논리 y 이 위로는 0, 그 아래 RIM_LO 까지 풀린다).
RIM_RGB = (255, 196, 140)
RIM_A = 0.55
RIM_W = 1.6            # 테 폭(논리 px)
RIM_Y = (44.0, 70.0, 120.0, 160.0)   # 0 → 1(풀림) · 1 → 0(사그라짐) 논리 y
SHADE = (318.0, -6.0, 125.0, 150.0, 0.85)     # 상인 뒤 그늘 — 가운데 x · y · 가로 · 세로 반지름 · 짙기

GOOD_NAMES = {
    ("boost", "b_big"): "팩",
    ("item", "l04"): "동전 — 잭과 콩나무",
    ("item", "l05"): "동전 — 녹는 시계",
    ("cons", "c_bl"): "사탕",
    ("fix", "v_pnt"): "사진",
    ("dart", ""): "다트",
}
LEGEND = {"l02", "l04", "l05"}


def _rgba(path: str) -> Image.Image:
    return Image.open(path).convert("RGBA")


def _resize(im: Image.Image, size: tuple[int, int]) -> Image.Image:
    """투명 가장자리가 검게 번지지 않도록 미리 곱한 알파로 줄인다."""
    return im.convert("RGBa").resize(size, Image.LANCZOS).convert("RGBA")


def _smooth(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3.0 - 2.0 * x)


def _solid(rgb, alpha: np.ndarray) -> Image.Image:
    """한 색 + 알파 판(0..1 float) → RGBA."""
    h, w = alpha.shape
    a = np.empty((h, w, 4), np.uint8)
    a[..., 0], a[..., 1], a[..., 2] = rgb
    a[..., 3] = np.clip(alpha * 255.0 + 0.5, 0, 255).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def _blur_a(a: np.ndarray, r: float) -> np.ndarray:
    """0..1 판을 가우스로(PIL — 큰 반지름도 빠르다)."""
    im = Image.fromarray(np.clip(a * 255.0 + 0.5, 0, 255).astype(np.uint8), "L")
    return np.asarray(im.filter(ImageFilter.GaussianBlur(r)), np.float32) / 255.0


def _fade_top(im: Image.Image, S: float, fade) -> Image.Image:
    """윗동을 녹인다 — 논리 y fade[0] 에서 투명, fade[1] 에서 제 알파. im 의 윗변이 논리 y 0."""
    a = np.asarray(im).copy()
    yy = np.arange(a.shape[0], dtype=np.float32) / S
    k = _smooth((yy - fade[0]) / (fade[1] - fade[0]))
    a[..., 3] = (a[..., 3].astype(np.float32) * k[:, None] + 0.5).astype(np.uint8)
    return Image.fromarray(a, "RGBA")


def _trimmed(name, im: Image.Image, left: int, top: int, **kw):
    bb = im.getchannel("A").getbbox()
    if bb is None:
        return None
    return pl.Layer(name, im.crop(bb), left + bb[0], top + bb[1], **kw)


def _halo(name, lay: pl.Layer, r_px: float, alpha: float, rgb, grow: float = 0.0, blend="scrn"):
    """레이어 실루엣에서 매끈한 빛 — 계단 없는 등급 빛 · 든 동전 빛."""
    a = np.asarray(lay.img.getchannel("A"), np.float32) / 255.0
    pad = int(math.ceil(r_px * 3 + grow))
    a = np.pad(a, pad)
    if grow > 0:
        a = _blur_a(a, grow * 0.5)
        a = np.clip(a * 2.0, 0, 1)
    g = _blur_a(a, r_px)
    g = np.clip(g * 1.6, 0, 1) * alpha
    return pl.Layer(name, _solid(rgb, g), lay.left - pad, lay.top - pad, blend=blend)


def rim_layer(name, im: Image.Image, top: int, S: float, mode: str, split: float | None = None):
    """실루엣 바깥 테에 따뜻한 뒷빛 한 줄 — mode both(양옆) · outer(split 왼쪽은 왼 테, 오른쪽은 오른 테).
    im 은 윗변이 논리 y 0 인 캔버스 너비 띠. RIM_Y 밖의 줄은 셈하지 않는다."""
    r0 = int(max(0, RIM_Y[0] * S))
    r1 = int(min(im.height, RIM_Y[3] * S))
    if r1 <= r0:
        return None
    a = np.asarray(im.getchannel("A").crop((0, r0, im.width, r1)), np.float32) / 255.0
    d = max(1, int(round(RIM_W * S)))
    left = np.zeros_like(a)
    right = np.zeros_like(a)
    left[:, d:] = np.clip(a[:, d:] - a[:, :-d], 0, 1)
    right[:, :-d] = np.clip(a[:, :-d] - a[:, d:], 0, 1)
    if mode == "both":
        e = np.maximum(left, right)
    else:
        xs = np.arange(a.shape[1], dtype=np.float32)[None, :]
        e = np.where(xs < split, left, right)
    del left, right
    e = _blur_a(e * a, d * 0.45)
    yy = (np.arange(a.shape[0], dtype=np.float32) + r0) / S
    w = _smooth((yy - RIM_Y[0]) / (RIM_Y[1] - RIM_Y[0])) * (1.0 - _smooth((yy - RIM_Y[2]) / (RIM_Y[3] - RIM_Y[2])))
    e = np.clip(e * 1.6, 0, 1) * w[:, None] * RIM_A
    return _trimmed(name, _solid(RIM_RGB, e), 0, top + r0, blend="scrn")


class Placer:
    """원화(K 배)의 한 물건을 캔버스로 — 바닥 닿는 점(앵커)을 과녁으로, 크기 s 배, 돌림 rot 도."""

    def __init__(self, K: int, S: float, cx, cy):
        self.K, self.S, self.cx, self.cy = K, S, cx, cy

    def place(self, im: Image.Image, src_xy, dst_xy, s: float, rot: float = 0.0, bbox=None):
        K = self.K
        bb = bbox or im.getchannel("A").getbbox()
        if bb is None:
            return None, 0, 0
        pad = 2
        bb = (max(bb[0] - pad, 0), max(bb[1] - pad, 0), min(bb[2] + pad, im.width), min(bb[3] + pad, im.height))
        cr = im.crop(bb)
        f = self.S * s / K
        w, h = max(1, int(round(cr.width * f))), max(1, int(round(cr.height * f)))
        cr = _resize(cr, (w, h))
        ax = (src_xy[0] * K - bb[0]) * f
        ay = (src_xy[1] * K - bb[1]) * f
        if abs(rot) > 0.01:
            c0 = (w / 2.0, h / 2.0)
            cr = cr.convert("RGBa").rotate(rot, resample=Image.BICUBIC, expand=True).convert("RGBA")
            c1 = (cr.width / 2.0, cr.height / 2.0)
            a = math.radians(rot)
            dx, dy = ax - c0[0], ay - c0[1]
            ax = c1[0] + dx * math.cos(a) + dy * math.sin(a)
            ay = c1[1] - dx * math.sin(a) + dy * math.cos(a)
        left = int(round(self.cx(dst_xy[0]) - ax))
        top = int(round(self.cy(dst_xy[1]) - ay))
        return cr, left, top


def build_one(key: str, dpi: int | None, quick: bool = False) -> None:
    t0 = time.time()
    d = dpi or pl.SIZES[key]["dpi"]
    Wc, Hc = pl.canvas_px(key, d)
    L = LAYOUT["XB" if key == "XB" else "A"]
    meta = json.load(open(os.path.join(RAW, "shop_meta.json"), encoding="utf-8"))
    K = int(meta["k"])
    X0, X1 = L["x0"], L["x1"]
    S = Wc / (X1 - X0)                     # 논리 px → 캔버스 px
    Y0 = int(round(L["y0"] * Hc))
    print(f"[{key}] {Wc}x{Hc} @ {d}dpi  S={S:.3f}  y0={Y0}  raw x{K}")

    def cx(lx: float) -> float:
        return (lx - X0) * S

    def cy(ly: float) -> float:
        return Y0 + ly * S

    P = Placer(K, S, cx, cy)

    def band_im(fn: str, h_logical: float = 360.0, k: int | None = None) -> Image.Image:
        """원화 한 장의 x0~x1 띠를 캔버스 너비로 — 윗변이 원화 윗변."""
        kk = k or K
        im = _rgba(os.path.join(RAW, fn))
        im = im.crop((int(round(X0 * kk)), 0, int(round(X1 * kk)), int(round(h_logical * kk))))
        return _resize(im, (Wc, int(round(h_logical * S))))

    def band_layer(name, fn, fade=None, **kw):
        im = band_im(fn)
        if fade is not None:
            im = _fade_top(im, S, fade)
        return _trimmed(name, im, 0, Y0, **kw)

    # ── 배경 — 바탕 · 방 ─────────────────────────────────
    bg = pl.Layer("바탕", Image.new("RGBA", (Wc, Hc), BG + (255,)))
    room = Image.open(os.path.join(RAW, ROOM)).convert("RGB")
    rk = room.width / 640.0                # 방 px / 논리 px
    rmid = room.height / 2.0               # 논리 y 180 이 서는 방 px 줄
    y_end = min(Hc, cy(150.0))             # 그 밑은 진열대가 덮는다
    r0 = rmid + ((0.0 - Y0) / S - 180.0) * rk
    r1 = rmid + ((y_end - Y0) / S - 180.0) * rk
    room = room.crop((int(X0 * rk), int(max(0.0, r0)), int(X1 * rk), int(min(room.height, r1))))
    room_soft = room.filter(ImageFilter.GaussianBlur(ROOM_BLUR * rk))
    room_soft = ImageEnhance.Color(room_soft).enhance(ROOM_SAT)
    room_soft = ImageEnhance.Brightness(room_soft).enhance(ROOM_DIM)
    ry = int(round(Y0 + ((max(0.0, r0) - rmid) / rk + 180.0) * S))
    rsz = (Wc, int(round(room.height * S / rk)))
    room_soft = room_soft.resize(rsz, Image.BICUBIC).convert("RGBA")
    room_sharp = room.resize(rsz, Image.LANCZOS).convert("RGBA")
    del room
    #  상인 뒤 그늘 — 몸통 윗동이 녹는 자리 뒤의 술병을 가라앉힌다(넓은 타원).
    sx_, sy_, srx, sry, sa = SHADE
    gx, gy, grx, gry = cx(sx_), cy(sy_), srx * S, sry * S
    gy0, gy1 = int(max(0, gy - gry * 1.6)), int(min(Hc, gy + gry * 1.6))
    yy_ = np.arange(gy0, gy1, dtype=np.float32)[:, None]
    xx_ = np.arange(Wc, dtype=np.float32)[None, :]
    er = np.sqrt(((xx_ - gx) / grx) ** 2 + ((yy_ - gy) / gry) ** 2)
    shade = _solid((0, 0, 0), sa * (1.0 - _smooth((er - 0.55) / 0.95)))
    del er
    g_bg = pl.Group("배경", [
        bg,
        pl.Layer("방 — 선반 · 술병(흐림)", room_soft, 0, ry),
        pl.Layer("방 — 선반 · 술병(선명)", room_sharp, 0, ry, visible=False),
        pl.Layer("상인 뒤 그늘", shade, 0, gy0),
    ])

    # ── 다트판 — 뒤 판자 벽 ─────────────────────────────────
    #  2026-10-07 「상점 NPC 얼굴쪽에 다트판에 왜 넣은거야? 넣지마 그냥」 — 판형에 board 가
    #  없으면 안 짓는다. board_group 은 시안 「다트판 정면」 가족이 다시 쓸 수 있게 남긴다.
    g_board = board_group(key, Wc, Hc, L, room_soft, ry) if L.get("board") else None

    #  판 밑 · 몸통 위 가운데 어둠 — 벽 램프 웅덩이 위 · 판 밑 층(판은 안 어두워진다)
    nk = L.get("neck")
    if nk is not None and g_board is not None:
        nx, ny_, nrx, nry, na = nk
        ncx, ncy, nrxp, nryp = cx(nx), cy(ny_), nrx * S, nry * S
        ny0, ny1 = int(max(0, ncy - nryp * 1.8)), int(min(Hc, ncy + nryp * 1.8))
        nx0, nx1 = int(max(0, ncx - nrxp * 1.8)), int(min(Wc, ncx + nrxp * 1.8))
        yy_ = np.arange(ny0, ny1, dtype=np.float32)[:, None]
        xx_ = np.arange(nx0, nx1, dtype=np.float32)[None, :]
        er = np.sqrt(((xx_ - ncx) / nrxp) ** 2 + ((yy_ - ncy) / nryp) ** 2)
        neck = pl.Layer("판 밑 어둠", _solid((0, 0, 0), na * (1.0 - _smooth((er - 0.45) / 1.0))), nx0, ny0)
        del er, yy_, xx_
        k_board = next(i for i, c in enumerate(g_board.children) if c.name == "판 그림자")
        g_board.children.insert(k_board, neck)

    # ── 상인 몸통 ───────────────────────────────────────
    g_npc = pl.Group("상인", [band_layer("몸통 — 조끼", "shop_body.png", BODY_FADE)])
    rim_body = rim_layer("몸통 테두리 빛", band_im("shop_body.png"), Y0, S, "both")
    if rim_body is not None:
        g_npc.children.append(rim_body)

    # ── 진열대 — 판형별로 펠트를 늘린 것 ─────────────────────
    T = meta["tables"][L["table"]]
    tk = int(T["k"])
    tim = _rgba(os.path.join(RAW, T["file"] + ".png"))
    tim = tim.crop((int(round(X0 * tk)), 0, int(round(X1 * tk)), tim.height))
    t_top = cy(float(T["top"]))
    th = int(round(tim.height * S / tk))
    tim = _resize(tim, (Wc, th))
    rail = int(round((float(T["rail"]) - float(T["top"])) * S))
    ta = np.asarray(tim)
    t_back = Image.fromarray(np.ascontiguousarray(ta[:rail]), "RGBA")
    t_front = Image.fromarray(np.ascontiguousarray(ta[rail:]), "RGBA")
    del ta, tim
    g_tbl = pl.Group("진열대", [x for x in [_trimmed("벨벳 · 먼 턱", t_back, 0, int(round(t_top)))]
                                if x is not None])
    g_front = pl.Group("진열대 앞", [x for x in [_trimmed("가까운 난간 · 앞판", t_front, 0,
                                                         int(round(t_top)) + rail)] if x is not None])

    # ── 물건 — 하나씩 제 자리로 ──────────────────────────
    goods = [gd for gd in meta["goods"] if (gd["type"], gd["id"]) in L["goods"]]
    goods.sort(key=lambda gd: L["goods"][(gd["type"], gd["id"])][1])
    good_groups = []
    for gd in goods:
        tx, ty, s, rot = L["goods"][(gd["type"], gd["id"])]
        nm = GOOD_NAMES.get((gd["type"], gd["id"]), gd["file"])
        src = (float(gd["x"]), float(gd["y"]))
        body_im = _rgba(os.path.join(RAW, gd["file"] + ".png"))
        bim, bl, bt = P.place(body_im, src, (tx, ty), s, rot)
        sh_im = _rgba(os.path.join(RAW, gd["shadow"] + ".png"))
        sim, sl, st = P.place(sh_im, src, (tx, ty), s, rot)
        del body_im, sh_im
        body = pl.Layer(nm, bim, bl, bt)
        kids = [pl.Layer(nm + " — 그림자", sim, sl, st)] if sim is not None else []
        if gd["id"] in LEGEND:
            kids.append(_halo(nm + " — 등급 빛", body, 8.0 * S * 0.5, 0.34, COIN, grow=1.5 * S))
            kids.append(_halo(nm + " — 등급 빛(곁)", body, 2.0 * S * 0.5, 0.40, COIN, grow=0.8 * S))
        kids.append(body)
        good_groups.append(pl.Group(nm, kids))
    g_goods = pl.Group("물건", good_groups)

    # ── 상인 손 ─────────────────────────────────────────
    #  든 팔(동전 쥔 손)은 어깨를 붙박고 hand_k 배로 키운다 — 보는 사람 쪽으로 내민 손이 원근으로
    #  커 보이는 것이다. 팔 · 손 그림자 층은 두 팔이 한 장이라 두 어깨 한가운데에서 가른다.
    hk = float(L.get("hand_k", 1.0))
    shs = meta["shoulders"]
    gsd = int(meta["give_side"])
    sh_x, sh_y = shs[gsd]
    split = cx((shs[0][0] + shs[1][0]) * 0.5)
    anchor = (cx(sh_x), cy(sh_y))

    y_k = cy(float(meta["held"]["y"]))          # 이 높이에서 hk 배가 다 찬다(든 동전)

    def s_at(y):
        return 1.0 + (hk - 1.0) * np.clip((y - anchor[1]) / (y_k - anchor[1]), 0.0, 1.0)

    def y_out(y):
        """원근 속임의 세로 — 어깨에서 내려갈수록 배율이 hk 로 커지므로 y' = ∫ s."""
        y = np.asarray(y, np.float64)
        t = np.clip((y - anchor[1]) / (y_k - anchor[1]), 0.0, 1.0)
        span = y_k - anchor[1]
        below = np.where(y > anchor[1], 0.0, y - anchor[1])
        inner = span * (t + (hk - 1.0) * t * t * 0.5)
        beyond = np.maximum(y - y_k, 0.0) * hk
        return anchor[1] + below + inner + beyond

    def grow(lay, name=None):
        """든 팔 쪽 레이어를 원근으로 — 어깨는 그대로, 손 · 동전 쪽으로 갈수록 hk 배까지 커진다."""
        if lay is None or abs(hk - 1.0) < 1e-3:
            return lay
        im = lay.img
        w, h = im.width, im.height
        ys = np.arange(lay.top, lay.top + h + 1, dtype=np.float64)
        yo = y_out(ys)
        ss = s_at(ys)
        xo0 = float(np.min(anchor[0] + (lay.left - anchor[0]) * ss))
        xo1 = float(np.max(anchor[0] + (lay.left + w - anchor[0]) * ss))
        X0o, X1o = int(math.floor(xo0)), int(math.ceil(xo1))
        Y0o, Y1o = int(math.floor(yo[0])), int(math.ceil(yo[-1]))
        data = []
        step = 6
        for ya in range(Y0o, Y1o, step):
            yb = min(ya + step, Y1o)
            sy0 = float(np.interp(ya, yo, ys))
            sy1 = float(np.interp(yb, yo, ys))
            s0, s1 = float(s_at(sy0)), float(s_at(sy1))
            def sx(x, sv):
                return anchor[0] + (x - anchor[0]) / sv - lay.left
            quad = (sx(X0o, s0), sy0 - lay.top, sx(X0o, s1), sy1 - lay.top,
                    sx(X1o, s1), sy1 - lay.top, sx(X1o, s0), sy0 - lay.top)
            data.append(((0, ya - Y0o, X1o - X0o, yb - Y0o), quad))
        out = im.convert("RGBa").transform((X1o - X0o, Y1o - Y0o), Image.MESH, data,
                                           resample=Image.BICUBIC).convert("RGBA")
        return _trimmed(name or lay.name, out, X0o, Y0o, opacity=lay.opacity, visible=lay.visible,
                        blend=lay.blend)

    def side_split(lay, rest_name, held_name):
        """두 팔이 한 장인 층을 가른다 — (쉬는 쪽, 든 쪽)."""
        if lay is None:
            return None, None
        a = np.asarray(lay.img)
        cut = int(round(split - lay.left))
        cut = min(max(cut, 0), a.shape[1])
        lo = Image.fromarray(np.ascontiguousarray(a[:, :cut]), "RGBA")
        hi = Image.fromarray(np.ascontiguousarray(a[:, cut:]), "RGBA")
        l0 = _trimmed(rest_name, lo, lay.left, lay.top)
        l1 = _trimmed(held_name, hi, lay.left + cut, lay.top)
        if gsd == 0:
            l0, l1 = l1, l0
            l0.name, l1.name = rest_name, held_name
        return l0, grow(l1)

    arm_rest, arm = side_split(band_layer("팔 · 손", "shop_harm.png", ARM_FADE), "쉬는 팔 · 손", "든 팔 · 손")
    rim_arm = rim_layer("소매 테두리 빛", band_im("shop_harm.png"), Y0, S, "outer", split)
    hsh_rest, hsh = side_split(band_layer("손 그림자", "shop_hshadow.png"), "쉬는 손 그림자", "든 손 그림자")
    hcoin = grow(band_layer("든 동전", "shop_hcoin.png"))
    hfront = grow(band_layer("집는 검지", "shop_hfront.png"))
    hglow_g = grow(band_layer("든 동전 등급 빛(게임 고리)", "shop_hglow.png", visible=False))
    hsh_g = grow(band_layer("든 동전 그림자(게임)", "shop_gsh_held.png", visible=False))
    #  든 동전 자리(캔버스) — 어깨에서 키운 뒤
    hcx = anchor[0] + (cx(meta["held"]["x"]) - anchor[0]) * hk
    hcy = float(y_out(cy(meta["held"]["y"])))
    #  든 동전 그림자 — 동전 실루엣을 펠트로 내린다. 직교 −52° 라 높이 h 는 화면으로 h x 0.616 아래,
    #  빛(TBL.light)을 따라 (3.35 + h x 0.1) 만큼 더 민다(게임 _obj_shadow 의 자리). 살짝 든 동전이라
    #  그림자는 동전 바로 밑에 붙고 높이만큼만 비켜난다 — 흐림도 높이에 비례.
    hh = float(meta["held"]["h"])
    dl = 3.35 + hh * 0.10
    sdx = 0.447 * dl * S * hk
    sdy = (float(meta["held"]["floor_y"]) - float(meta["held"]["y"]) + 0.894 * dl) * S * hk
    held_shadow = None
    held_glow = []
    if hcoin is not None:
        a = np.asarray(hcoin.img.getchannel("A"), np.float32) / 255.0
        pad = int(6 * S)
        a = np.pad(a, pad)
        blur = (0.6 + hh * 0.07) * S
        sa_ = _blur_a(a, blur) * HELD_SH
        held_shadow = pl.Layer("든 동전 그림자", _solid((0, 0, 0), sa_),
                               int(round(hcoin.left - pad + sdx)), int(round(hcoin.top - pad + sdy)))
        held_glow = [
            _halo("든 동전 등급 빛", hcoin, 11.0 * S * 0.5, 0.65, COIN, grow=2.5 * S),
            _halo("든 동전 등급 빛(곁)", hcoin, 2.4 * S * 0.5, 0.55, COIN, grow=1.0 * S),
        ]
    #  든 동전 빛 — 동전 둘레 펠트에 번진 분홍 웅덩이(손 · 동전 밑)
    cr_ = 40.0 * S
    c_lo, c_hi = int(hcy - cr_ * 1.2), int(hcy + cr_ * 1.6)
    x_lo, x_hi = int(hcx - cr_ * 1.6), int(hcx + cr_ * 1.6)
    yy2 = np.arange(c_lo, c_hi, dtype=np.float32)[:, None]
    xx2 = np.arange(x_lo, x_hi, dtype=np.float32)[None, :]
    cr2 = np.sqrt(((xx2 - hcx) / cr_) ** 2 + ((yy2 - hcy - cr_ * 0.25) / (cr_ * 0.75)) ** 2)
    coin_pool = pl.Layer("든 동전 빛", _solid(COIN, 0.30 * np.exp(-(cr2 ** 2) * 1.6)), x_lo, c_lo, blend="scrn")
    del yy2, xx2, cr2
    g_hands = pl.Group("상인 손", [x for x in [
        hsh_rest,
        hsh,
        hsh_g,
        held_shadow,
        coin_pool,
        hglow_g,
        *held_glow,
        arm_rest,
        arm,
        rim_arm,
        hcoin,
        hfront,
    ] if x is not None])

    # ── 소품 — 저울 · 등록기, 진열대 뒤 귀퉁이(게임처럼 상인 양옆) ─────────
    prop_items = []
    for fn, nm, pk in (("shop_scale.png", "저울", "scale"), ("shop_register.png", "금전 등록기", "register")):
        fx, by, ks = L["props"][pk]
        im = _rgba(os.path.join(RAW, fn))
        bb = im.getchannel("A").getbbox()
        im = im.crop(bb)
        f = S * ks / K
        im = _resize(im, (int(round(im.width * f)), int(round(im.height * f))))
        #  받침 밑 — 불투명한 마지막 줄(그 밑 10 논리 px 는 게임의 받침 그늘이다)
        aa = np.asarray(im.getchannel("A"))
        base = int(np.nonzero((aa > 200).any(1))[0].max())
        del aa
        left = int(round(fx * Wc - im.width / 2.0))
        top = int(round(cy(by) - base))
        #  접지 그림자 — 받침 밑에 붙은 납작한 타원(램프가 위 · 조금 왼쪽에서)
        sw, sh = im.width * 0.44, im.height * 0.055
        ex, ey = left + im.width * 0.53, top + base - sh * 0.3
        y_lo, y_hi = int(ey - sh * 3), int(ey + sh * 3)
        x_lo, x_hi = int(ex - sw * 1.6), int(ex + sw * 1.6)
        yy = np.arange(y_lo, y_hi, dtype=np.float32)[:, None]
        xx = np.arange(x_lo, x_hi, dtype=np.float32)[None, :]
        rr = np.sqrt(((xx - ex) / sw) ** 2 + ((yy - ey) / sh) ** 2)
        shd = _solid((0, 0, 0), 0.55 * (1.0 - _smooth((rr - 0.4) / 0.9)))
        prop_items.append(pl.Group(nm, [pl.Layer(nm + " — 그림자", shd, x_lo, y_lo),
                                        pl.Layer(nm, im, left, top)]))
        print(f"  {nm}: x {left / Wc:.3f}~{(left + im.width) / Wc:.3f}W  y {top / Hc:.3f}~{(top + im.height) / Hc:.3f}H")
    g_props = pl.Group("소품", prop_items)

    # ── 빛 · 그림자 ───────────────────────────────────────
    ys = np.arange(Hc, dtype=np.float32)[:, None]
    xs = np.arange(Wc, dtype=np.float32)[None, :]
    t0_, t1_, ta_ = L["top_dark"][0] * Hc, L["top_dark"][1] * Hc, L["top_dark"][2]
    top_h = int(np.ceil(t1_))
    a_top = ta_ * (1.0 - _smooth((ys[:top_h] - t0_) / (t1_ - t0_)))
    dark_top = _solid((0, 0, 0), np.repeat(a_top, Wc, axis=1))

    lx, ly, lrx, lry = cx(L["lamp"][0]), cy(L["lamp"][1]), L["lamp"][2] * S, L["lamp"][3] * S
    y_lo, y_hi = int(max(0, ly - lry)), int(min(Hc, ly + lry))
    rr = np.sqrt(((xs - lx) / lrx) ** 2 + ((ys[y_lo:y_hi] - ly) / lry) ** 2)
    lamp = _solid(LAMP, A_LAMP * (1.0 - _smooth(rr)) ** 2)
    del rr

    vcy = cy(L["lamp"][1])
    vr = np.sqrt(((xs - Wc * 0.5) / (Wc * L["vig"][0])) ** 2 + ((ys - vcy) / (Hc * L["vig"][1])) ** 2)
    vig = _solid((0, 0, 0), 0.50 * _smooth((vr - 0.60) / 0.75))
    del vr

    sp = L["spot"]
    sr = np.sqrt(((xs - cx(sp[0])) / (sp[2] * S)) ** 2 + ((ys - cy(sp[1])) / (sp[3] * S)) ** 2)
    spot = _solid((0, 0, 0), SPOT_OUT * _smooth((sr - 0.60) / 0.9))
    del sr

    bd = L["bot_dark"]
    b0 = cy(bd[0])
    b1 = cy(bd[1])
    if b0 < Hc:
        a_bot = bd[2] * _smooth((ys[int(b0):] - b0) / (b1 - b0))
        dark_bot = pl.Layer("아래 어둠", _solid((0, 0, 0), np.repeat(a_bot, Wc, axis=1)), 0, int(b0))
    else:
        dark_bot = None

    g_light = pl.Group("빛 · 그림자", [x for x in [
        pl.Layer("위 어둠", dark_top, 0, 0),
        pl.Layer("램프 빛", lamp, 0, y_lo, blend="scrn"),
        pl.Layer("스포트 밖 어둠", spot, 0, 0),
        pl.Layer("가장자리 어둠", vig, 0, 0),
        dark_bot,
    ] if x is not None])
    del ys, xs

    # ── 제목 ─────────────────────────────────────────────
    ko = pl.Title("하이톤", FONT_KO, 100.0, Wc / 2.0, L["ko_base"] * Hc, CORE_KO, 0.03,
                  "center", "하이톤")
    ko.size_px = 100.0 * (L["ko_w"] * Wc) / pl.title_width(ko)
    en = pl.Title("HIGHTON", FONT_EN, 100.0, Wc / 2.0, L["en_base"] * Hc, CORE_EN, L["en_track"],
                  "center", "HIGHTON")
    en.size_px = 100.0 * (L["en_w"] * Wc) / pl.title_width(en)
    titles = [ko, en]
    g_neon = neon_group(Wc, Hc, titles)

    #  소품(저울 · 등록기)은 진열대 뒤 귀퉁이에 서므로 손 · 물건보다 뒤 — 진열대 바로 위.
    items = [x for x in [g_bg, g_board, g_npc, g_tbl, g_props, g_goods, g_hands, g_front, g_light, g_neon]
             if x is not None]
    os.makedirs(OUT, exist_ok=True)
    stem = os.path.join(OUT, f"{key}_shop" + ("_quick" if quick else ""))
    if quick:
        flat = pl.composite((Wc, Hc), items + [pl.Layer("제목", pl.title_raster((Wc, Hc), titles, 2))])
        pv = flat.copy()
        pv.thumbnail((1400, 1400 * 3), Image.LANCZOS)
        pv.save(stem + "_preview.png")
    else:
        flat = pl.build(stem, key, items, titles, d)
    s3 = flat.copy()
    s3.thumbnail((10000, 300), Image.LANCZOS)
    s3.save(stem + "_3m.png")
    #  인쇄 선명도 보기 — 주 그림(든 동전 · 손) 둘레 1600x1600 을 1:1 로
    hx, hy = hcx, hcy
    hw = min(800, Wc // 2)
    x0 = int(np.clip(hx - hw, 0, Wc - 2 * hw))
    y0 = int(np.clip(hy - hw * 0.8, 0, Hc - 2 * hw))
    flat.crop((x0, y0, x0 + 2 * hw, y0 + 2 * hw)).save(stem + "_detail.png")
    #  다트판 1:1
    if L.get("board"):
        bx, by_, br = L["board"]
        bc = (int(bx * Wc), int(by_ * Hc))
        bx0 = int(np.clip(bc[0] - hw, 0, Wc - 2 * hw))
        flat.crop((bx0, bc[1] - hw, bx0 + 2 * hw, bc[1] + hw)).save(stem + "_board.png")
    #  상인 왼 어깨 · 소매 1:1 — 테두리 빛 보기
    nx0 = int(np.clip(cx(250.0) - hw, 0, Wc - 2 * hw))
    ny0 = int(np.clip(cy(70.0) - hw, 0, Hc - 2 * hw))
    flat.crop((nx0, ny0, nx0 + 2 * hw, ny0 + 2 * hw)).save(stem + "_npc.png")
    #  네온 1:1 — 하이톤 왼쪽 위
    tx0 = int(Wc / 2.0 - pl.title_width(ko) / 2.0 - 0.03 * Wc)
    ty0 = int(L["ko_base"] * Hc - ko.size_px * 0.95)
    flat.crop((tx0, ty0, tx0 + 2 * hw, ty0 + hw)).save(stem + "_title.png")
    print(f"[{key}] done {time.time() - t0:.1f}s  ko {ko.size_px:.0f}px  en {en.size_px:.0f}px")


# ─────────────────────────────────────────────────────────────
#  다트판 — shot_board.gd 의 판 · 꽂힌 다트 · 다트 그림자(램프 그림자 패스)
# ─────────────────────────────────────────────────────────────
def _board_shadow_mask() -> np.ndarray:
    out = os.path.join(BOARD, "shadow.png")
    on, off = (os.path.join(BOARD, n + ".png") for n in ("shadow_on", "shadow_off"))
    if not os.path.exists(out) or os.path.getmtime(out) < max(os.path.getmtime(on), os.path.getmtime(off)):
        a = np.asarray(Image.open(on).convert("L"), np.float32)
        b = np.asarray(Image.open(off).convert("L"), np.float32)
        r = np.clip(a / np.maximum(b, 1.0), 0.0, 1.0)
        Image.fromarray((r * 255.0 + 0.5).astype(np.uint8), "L").save(out)
    return np.asarray(Image.open(out), np.float32) / 255.0


def board_group(key, Wc, Hc, L, room_soft: Image.Image, ry: int) -> pl.Group:
    bm = json.load(open(os.path.join(BOARD, "meta.json"), encoding="utf-8"))
    ro = float(bm["ro"])                       # 바깥 숫자 고리 반지름(판 논리 px)
    bx, by, br = L["board"]
    cxp, cyp = bx * Wc, by * Hc
    rp = br * Wc                               # 캔버스 px 반지름(바깥 고리)
    s = rp / ro                                # 판 논리 px → 캔버스 px

    def place(im: Image.Image, k: float):
        f = s / k
        bb = im.getbbox() if im.mode != "RGBA" else im.getchannel("A").getbbox()
        cr = im.crop(bb)
        w, h = int(round(cr.width * f)), int(round(cr.height * f))
        cr = _resize(cr, (w, h)) if cr.mode == "RGBA" else cr.resize((w, h), Image.LANCZOS)
        left = int(round(cxp + (bb[0] - im.width / 2.0) * f))
        top = int(round(cyp + (bb[1] - im.height / 2.0) * f))
        return cr, left, top

    kb = float(bm["board"]["k"])
    board = _rgba(os.path.join(BOARD, "board.png"))
    #  게임이 판 밑에 깐 그림자(알파 0.40 고리)는 걷고 판 · 옆면만 — 그림자는 아래 「판 그림자」 가 새로 진다.
    ba = np.asarray(board, np.float32).copy()
    ba[..., 3] = np.clip((ba[..., 3] / 255.0 - 0.45) / 0.55, 0.0, 1.0) * 255.0
    board = Image.fromarray((ba + 0.5).astype(np.uint8), "RGBA")
    del ba
    bim, bl, bt = place(board, kb)
    del board
    #  벽에 앉힌다 — 등 뒤 방 흐림과 맞게 아주 조금 무르게(판은 읽혀야 한다)
    bim = bim.convert("RGBa").filter(ImageFilter.GaussianBlur(max(0.6, rp * 0.0016))).convert("RGBA")
    board_l = pl.Layer("판", bim, bl, bt)
    #  판 그림자 — 판 실루엣을 무르게 해 램프 반대쪽(아래 · 조금 오른쪽)으로
    a = np.asarray(bim.getchannel("A"), np.float32) / 255.0
    pad = int(rp * 0.16)
    sa = _blur_a(np.pad(a, pad), rp * 0.035) * 0.70
    board_sh = pl.Layer("판 그림자", _solid((0, 0, 0), sa), bl - pad + int(rp * 0.02), bt - pad + int(rp * 0.07))
    #  판 그늘 — 램프 웅덩이가 판 한가운데 조금 위에 모인다. 가장자리는 0.6 언저리까지.
    h, w = a.shape
    yy = (np.arange(h, dtype=np.float32)[:, None] + bt - cyp) / rp
    xx = (np.arange(w, dtype=np.float32)[None, :] + bl - cxp) / rp
    re = np.sqrt(xx * xx + (yy + 0.25) ** 2)
    shade = 0.38 * _smooth((re - 0.25) / 0.95)
    shade_l = pl.Layer("판 그늘", _solid((14, 6, 4), shade * a), bl, bt)
    del re, xx, yy
    #  다트 그림자 · 다트
    kd = float(bm["darts"]["k"])
    darts = _rgba(os.path.join(BOARD, "darts.png"))
    dim, dlft, dtp = place(darts, kd)
    del darts
    #  다트를 게임 다트(흰 · 은빛) 쪽으로 — 램프 아래 크림 날개가 판 크림 칸에 묻혔다. 채도를 걷고
    #  밝은 쪽을 들어 날개 · 배럴이 희게, 샤프트는 어둡게 남긴다.
    da = np.asarray(dim, np.float32) / 255.0
    rgb, al = da[..., :3], da[..., 3:4]
    lum = (rgb * np.array([0.30, 0.59, 0.11], np.float32)).sum(-1, keepdims=True)
    rgb = lum + (rgb - lum) * 0.22
    rgb = np.clip((rgb - 0.06) / 0.62, 0.0, 1.0) ** 0.85
    rgb = rgb * np.array([0.97, 0.985, 1.0], np.float32)
    #  이너 불 다트 — 셋 가운데 가장 잘 보이게: 판 한가운데 둘레(논리 40) 안만 한 단 더 밝힌다.
    tips = bm.get("dart_tips", [[0.0, 0.0]])
    hh_, ww_ = al.shape[:2]
    yy = (np.arange(hh_, dtype=np.float32)[:, None] + dtp - cyp) / s
    xx = (np.arange(ww_, dtype=np.float32)[None, :] + dlft - cxp) / s
    bull = (np.sqrt((xx - float(tips[0][0]) - 12.0) ** 2 + (yy - float(tips[0][1]) + 6.0) ** 2) < 40.0)
    rgb = np.where(bull[..., None], np.clip(rgb * 1.10 + 0.05, 0, 1), rgb * 0.94)
    dim = Image.fromarray(np.dstack([rgb, al]).__mul__(255.0).clip(0, 255).astype(np.uint8), "RGBA")
    #  다트 테 그늘 — 판 위에서 다트 실루엣이 갈리게(이너 불 다트가 가장 짙다)
    ap = int(round(3.0 * s))
    ab = _blur_a(np.pad(al[..., 0], ap), 0.9 * s)
    wbull = np.pad(bull.astype(np.float32), ap)
    edge = np.clip(ab * (0.38 + 0.30 * wbull), 0, 1)
    dart_edge = pl.Layer("다트 테 그늘", _solid((0, 0, 0), edge), dlft - ap, dtp - ap)
    del da, rgb, al, ab, wbull, edge, yy, xx
    shm = _board_shadow_mask()
    ks = float(bm["shadow"]["k"])
    sm = Image.fromarray(((1.0 - shm) * 255.0 + 0.5).astype(np.uint8), "L")
    smi, sl, st = place(sm, ks)
    #  다트 그림자 — 촉에 붙은 짧은 접지 그림자만(판 위 회색 얼룩이 3m 에서 때로 읽혔다):
    #  촉에서 멀어질수록 빠르게 걷는다(논리 9 언저리).
    sma = np.asarray(smi, np.float32) / 255.0
    yy = (np.arange(sma.shape[0], dtype=np.float32)[:, None] + st - cyp) / s
    xx = (np.arange(sma.shape[1], dtype=np.float32)[None, :] + sl - cxp) / s
    near = np.zeros_like(sma)
    for tp in tips:
        dd = np.sqrt((xx - float(tp[0])) ** 2 + (yy - float(tp[1])) ** 2)
        near = np.maximum(near, np.exp(-(dd / 9.0) ** 2))
    sma = sma * near * 0.55
    del yy, xx, near
    #  판 밖으로 나간 그림자는 판에만 — 판 실루엣 안
    pa = np.zeros_like(sma)
    oy, ox = bt - st, bl - sl
    y0, x0 = max(0, oy), max(0, ox)
    y1, x1 = min(sma.shape[0], oy + h), min(sma.shape[1], ox + w)
    pa[y0:y1, x0:x1] = a[y0 - oy:y1 - oy, x0 - ox:x1 - ox]
    dart_sh = pl.Layer("다트 그림자", _solid((0, 0, 0), sma * pa), sl, st)
    #  벽 램프 빛 — 판 위에서 내리는 작은 따뜻한 빛(벽에 둥근 웅덩이)
    #  웅덩이는 판 위 램프에서 아래로 길게 번진다(세로 1.5 배 · 한가운데가 판보다 조금 밑) —
    #  판과 상인 어깨 사이 벽이 죽은 검정 띠가 안 되게.
    lr = rp * float(L.get("lamp_r", 2.1))
    lv = float(L.get("lamp_v", 1.5))
    ly0, ly1 = int(cyp - lr * 1.0), int(cyp + lr * lv * 1.15)
    lx0, lx1 = int(max(0, cxp - lr)), int(min(Wc, cxp + lr))
    yy = np.arange(ly0, ly1, dtype=np.float32)[:, None]
    xx = np.arange(lx0, lx1, dtype=np.float32)[None, :]
    rr = np.sqrt(((xx - cxp) / lr) ** 2 + ((yy - (cyp + rp * float(L.get("lamp_dy", 0.35)))) / (lr * lv)) ** 2)
    pool = 0.27 * (1.0 - _smooth(rr)) ** 1.5
    pool_l = pl.Layer("벽 램프 빛", _solid(LAMP, pool), lx0, ly0, blend="scrn")
    #  램프가 비춘 판자 벽 — 방 그림(흐림)을 판 둘레만 밝혀 판자 결 · 이음이 드러나게
    wy0, wy1 = max(ly0, ry), min(ly1, ry + room_soft.height)
    wx0, wx1 = max(lx0, 0), min(lx1, room_soft.width)
    lit_l = None
    if wy1 > wy0 and wx1 > wx0:
        wall = np.asarray(room_soft.crop((wx0, wy0 - ry, wx1, wy1 - ry)).convert("RGB"), np.float32)
        warm = np.array([1.0, 0.86, 0.66], np.float32)
        wall = np.clip(wall * 5.0 * warm + np.array([12.0, 7.0, 3.0]), 0, 255)
        rw = rr[wy0 - ly0:wy1 - ly0, wx0 - lx0:wx1 - lx0]
        al = 0.85 * (1.0 - _smooth(rw)) ** 1.3
        lit = np.dstack([wall, al[..., None] * 255.0]).astype(np.uint8)
        lit_l = pl.Layer("램프 받은 벽", Image.fromarray(lit, "RGBA"), wx0, wy0)
    #  판 둘레 어둠 — 술병 빛이 판 테에 번지지 않게 둘레 벽을 한 단 누른다
    rr2 = np.sqrt(((xx - cxp) / (rp * 1.9)) ** 2 + ((yy - cyp) / (rp * 1.9)) ** 2)
    halo = 0.25 * (1.0 - _smooth((rr2 - 0.55) / 0.45))
    halo_l = pl.Layer("판 둘레 어둠", _solid((0, 0, 0), halo), lx0, ly0)
    del yy, xx, rr, rr2
    return pl.Group("다트판", [x for x in [lit_l, halo_l, pool_l, board_sh, board_l, shade_l, dart_sh,
                               dart_edge, pl.Layer("다트", dim, dlft, dtp)] if x is not None])


# ─────────────────────────────────────────────────────────────
#  네온 — 관처럼. 벡터 제목이 흰 분홍 심이고, 그 둘레에 좁고 진한 분홍 관벽 · 가까운 빛 ·
#  아주 옅은 먼 번짐. 넓은 분홍 덩어리(「바깥 광선」)가 안 되게 먼 번짐은 짙기 0.1 언저리.
# ─────────────────────────────────────────────────────────────
def neon_group(Wc, Hc, titles) -> pl.Group:
    q = 2
    small = (Wc // q, Hc // q)
    mask = pl.title_raster((Wc, Hc), titles, ss=1).getchannel("A")
    bb = mask.getbbox()
    ms = np.asarray(mask.resize(small, Image.BOX), np.float32) / 255.0
    del mask
    #  글자 둘레만 셈한다(캔버스 통째로 흐리면 느리다)
    pad = int(0.08 * Wc / q)
    x0, y0 = max(0, bb[0] // q - pad), max(0, bb[1] // q - pad)
    x1, y1 = min(small[0], bb[2] // q + pad), min(small[1], bb[3] // q + pad)
    m = ms[y0:y1, x0:x1]
    del ms

    def blur(r_px):
        return _blur_a(m, r_px / q)

    #  관벽 — 심(벡터) 바로 바깥을 두른다. 조금 불린 마스크를 좁게 흐려 진하게.
    #  관벽 — 심(벡터) 바로 바깥 0.4% W 띠. 불린 마스크(흐림 x 문턱)를 다시 좁게 흐려 테가 무르다.
    grown = np.clip(blur(0.0042 * Wc) * 2.3, 0, 1)
    wall = np.clip(_blur_a(grown, 0.0012 * Wc / q) * 1.05, 0, 1) * 0.95
    del grown
    near = np.clip(blur(0.0105 * Wc) * 1.25, 0, 1) * 0.40
    far = np.clip(blur(0.040 * Wc) * 1.2, 0, 1) * 0.09

    def up(a, rgb, name):
        im = Image.fromarray(np.clip(a * 255.0 + 0.5, 0, 255).astype(np.uint8), "L")
        im = im.resize(((x1 - x0) * q, (y1 - y0) * q), Image.BICUBIC)
        out = Image.new("RGBA", im.size, rgb + (0,))
        out.putalpha(im)
        return pl.Layer(name, out, x0 * q, y0 * q, blend="scrn")

    return pl.Group("네온", [up(far, NEON_FAR, "네온 번짐"), up(near, NEON_NEAR, "네온 빛"),
                             up(wall, NEON_WALL, "네온 관벽")])


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if a != "--quick"]
    k = args[0] if args else "A1"
    dd = int(args[1]) if len(args) > 1 else None
    build_one(k, dd, "--quick" in sys.argv)
