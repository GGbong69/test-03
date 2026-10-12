u"""동전 다시 디자인 시안(2026-10-12 「게임 내 동전 디자인 다시 디자인 하자」 → 「전설 동전들 좀 멋있는 모양이랑
일러로 · 몸통·테」). 게임에 넣기 전에 그림으로 견주는 판 — 게임 코드는 안 건드린다.

  A 주화      찍어 낸 쇠 — 등급이 쇠를 고른다(일반 동 · 언커먼 은 · 희귀 금) · 솟은 테 · 빗살 · 움푹한 얼굴 ·
              박음은 테에 박힌 보석(언커먼 셋 · 희귀 여섯)
  B 칩        카지노 칩 — 지금 등급 색 몸통 · 두꺼운 테에 흰 인레이(박음) · 얼굴 위 볼록한 광
  전설        효과에서 딴 다섯 실루엣 · 분홍 금 테 · 홀로 · 얼굴 밖으로 떠오르는 「영혼」 한 겹(발라트로 전설 조커)

  python scripts/tools/coin_redesign_mock.py   → outputs/coin_redesign/mock.png
"""
from __future__ import annotations

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[2]
FACE = ROOT / "assets/coin"
OUT = ROOT / "outputs/coin_redesign"
K = 8                    # 논리 px 하나 = K 화소
SS = 3                   # 슈퍼샘플
LIGHT = np.array([-0.62, -0.78])   # 빛 — 왼쪽 위(화면 좌표, y 아래)
METAL = {
    "동": [(64, 34, 22), (150, 86, 52), (214, 146, 98), (255, 214, 176)],
    "은": [(64, 68, 86), (140, 146, 166), (206, 210, 222), (255, 255, 255)],
    "금": [(92, 56, 12), (196, 140, 40), (246, 204, 104), (255, 246, 200)],
    "분홍금": [(86, 22, 54), (196, 82, 136), (248, 162, 196), (255, 232, 242)],
}
GEM = {"uncommon": (92, 156, 255), "rare": (255, 150, 40)}
TIER_BODY = {"common": (222, 213, 192), "uncommon": (125, 90, 208), "rare": (36, 30, 51)}


def ramp(stops, t):
    t = np.clip(t, 0, 1) * (len(stops) - 1)
    i = np.clip(np.floor(t).astype(int), 0, len(stops) - 2)
    f = (t - i)[..., None]
    s = np.array(stops, np.float32)
    return s[i] * (1 - f) + s[i + 1] * f


def face_img(ident, d):
    im = Image.open(FACE / f"{ident}.png").convert("RGBA")
    return im.resize((d, d), Image.Resampling.NEAREST)


def bevel(mask: np.ndarray, width: float):
    """마스크 가장자리의 비탈 — (테 알파, 빛 받는 몫 0~1). 거리장 대신 흐린 마스크의 기울기로 법선을 쓴다."""
    m = Image.fromarray((mask * 255).astype(np.uint8))
    er = np.asarray(m.filter(ImageFilter.MinFilter(int(width) | 1)), np.float32) / 255.0
    ring = np.clip(mask - er, 0, 1)
    b = np.asarray(m.filter(ImageFilter.GaussianBlur(width * .6)), np.float32) / 255.0
    gy, gx = np.gradient(b)
    n = np.sqrt(gx * gx + gy * gy) + 1e-6
    lit = (-(gx / n) * LIGHT[0] - (gy / n) * LIGHT[1]) * 0.5 + 0.5      # 바깥 비탈이 빛을 보면 밝다
    return ring, lit


def disc_mask(size, c, r):
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    return np.clip(r - np.sqrt((xx - c) ** 2 + (yy - c) ** 2) + .5, 0, 1)


def coin_A(ident, rarity, r=19.0):
    """주화 — 솟은 테(쇠) · 빗살 · 움푹한 얼굴 · 보석 박음."""
    metal = {"common": "동", "uncommon": "은", "rare": "금"}[rarity]
    R = r * K * SS
    size = int(R * 2 + 40 * SS)
    c = size / 2
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    dx, dy = xx - c, yy - c
    rr = np.sqrt(dx * dx + dy * dy)
    th = np.arctan2(dy, dx)
    outer = disc_mask(size, c, R)
    if rarity == "rare":                                   # 물린 테 — 여섯 군데를 안으로 판다
        bite = np.zeros_like(outer)
        for j in range(6):
            a = math.radians(15 + 60 * j)
            bx, by = c + math.cos(a) * R * 1.02, c + math.sin(a) * R * 1.02
            bite = np.maximum(bite, np.clip(R * .13 - np.sqrt((xx - bx) ** 2 + (yy - by) ** 2) + .5, 0, 1))
        outer = np.clip(outer - bite, 0, 1)
    r_in = R * .80
    inner = disc_mask(size, c, r_in)
    rim = np.clip(outer - inner, 0, 1)
    # 쇠 빛 — 테는 솟은 고리: 바깥 비탈은 빛 쪽이 밝고, 안 비탈(얼굴로 내려가는 턱)은 반대가 밝다
    cosl = (np.cos(th) * LIGHT[0] + np.sin(th) * LIGHT[1])
    u = (rr - r_in) / (R - r_in)
    slope = np.where(u > .55, cosl, -cosl * .7)
    t = .55 + .40 * slope
    reed = (u > .80) * (0.5 + 0.5 * np.sin(th * 96)) * .22   # 빗살 — 바깥 끝 띠에만
    t = t - reed
    col = ramp(METAL[metal], t)
    # 광 — 왼쪽 위 테 한 줄
    gloss = np.clip(cosl, 0, 1) ** 10 * (np.abs(u - .40) < .22) * .85
    col = col + (255 - col) * gloss[..., None]
    img = np.zeros((size, size, 4), np.float32)
    img[..., :3] = col
    img[..., 3] = rim * 255
    # 얼굴 — 움푹하다: 위 왼쪽 안쪽에 그늘(턱이 드리운다)
    d = int(r_in * 2)
    f = np.asarray(face_img(ident, d), np.float32)
    fa = np.zeros((size, size, 4), np.float32)
    o = int(c - d / 2)
    fa[o:o + d, o:o + d] = f
    fm = inner * (fa[..., 3] / 255.0)
    shade = np.clip((-(dx * LIGHT[0] + dy * LIGHT[1]) / r_in), 0, 1)   # 빛 반대쪽이 아니라 빛 쪽 안 가장자리가 그늘
    edge_dist = np.clip((r_in - rr) / (R * .12), 0, 1)
    sh = (1 - edge_dist) * np.clip(-cosl, 0, 1) * .55 + (1 - edge_dist) * .18
    fcol = fa[..., :3] * (1 - sh[..., None])
    img[..., :3] = img[..., :3] * (1 - fm[..., None]) + fcol * fm[..., None]
    img[..., 3] = np.maximum(img[..., 3], fm * 255)
    del shade
    # 보석 박음 — 테 한가운데 띠에
    n = {"common": 0, "uncommon": 3, "rare": 6}[rarity]
    out = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA")
    dr = ImageDraw.Draw(out)
    gr = R * .085
    for j in range(n):
        a = math.radians(-90 + 360 / n * j + (30 if rarity == "rare" else 0))
        gx, gy = c + math.cos(a) * R * .90, c + math.sin(a) * R * .90
        g = GEM[rarity]
        dr.ellipse((gx - gr * 1.25, gy - gr * 1.25, gx + gr * 1.25, gy + gr * 1.25), fill=tuple(int(v * .45) for v in g) + (255,))
        dr.ellipse((gx - gr, gy - gr, gx + gr, gy + gr), fill=g + (255,))
        dr.ellipse((gx - gr * .55, gy - gr * .75, gx - gr * .05, gy - gr * .25), fill=(255, 255, 255, 220))
    return out.resize((size // SS, size // SS), Image.Resampling.LANCZOS)


def coin_B(ident, rarity, r=19.0):
    """칩 — 등급 색 몸통 · 두꺼운 테 흰 인레이 · 얼굴 위 볼록한 광."""
    R = r * K * SS
    size = int(R * 2 + 40 * SS)
    c = size / 2
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    dx, dy = xx - c, yy - c
    rr = np.sqrt(dx * dx + dy * dy)
    th = np.arctan2(dy, dx)
    body = np.array(TIER_BODY[rarity], np.float32)
    outer = disc_mask(size, c, R)
    r_in = R * .74
    inner = disc_mask(size, c, r_in)
    cosl = (np.cos(th) * LIGHT[0] + np.sin(th) * LIGHT[1])
    col = np.broadcast_to(body, (size, size, 3)).astype(np.float32).copy()
    col *= (0.82 + 0.22 * cosl * (rr > r_in))[..., None]
    n = {"common": 4, "uncommon": 6, "rare": 8}[rarity]
    seg = (np.mod(th / (2 * math.pi) * n + 1.0, 1.0) < .28) & (rr > R * .80) & (rr < R * .97)
    col[seg] = (246, 240, 228)
    ring = (np.abs(rr - R * .77) < R * .012)
    col[ring] = col[ring] * .55
    img = np.dstack([col, outer * 255])
    d = int(r_in * 2)
    f = np.asarray(face_img(ident, d), np.float32)
    fa = np.zeros((size, size, 4), np.float32)
    o = int(c - d / 2)
    fa[o:o + d, o:o + d] = f
    fm = inner * (fa[..., 3] / 255.0)
    img[..., :3] = img[..., :3] * (1 - fm[..., None]) + fa[..., :3] * fm[..., None]
    # 볼록한 광 — 얼굴 위 왼쪽 반달
    gl = np.clip(1 - np.sqrt(((dx + r_in * .30) / (r_in * .55)) ** 2 + ((dy + r_in * .42) / (r_in * .28)) ** 2), 0, 1)
    img[..., :3] += (255 - img[..., :3]) * (gl * .45 * inner)[..., None]
    out = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA")
    return out.resize((size // SS, size // SS), Image.Resampling.LANCZOS)


# ── 전설 ────────────────────────────────────────────────────────
def leg_shape(kind, R, size):
    """전설 다섯의 실루엣(논리 반지름 R 원 안 — 물리 chip_r 22.04 를 안 넘는다)."""
    c = size / 2
    m = Image.new("L", (size, size))
    d = ImageDraw.Draw(m)

    def ell(cx, cy, rx, ry, rot=0.0, fill=255):
        pts = [(c + cx + math.cos(t) * rx * math.cos(rot) - math.sin(t) * ry * math.sin(rot),
                c + cy + math.cos(t) * rx * math.sin(rot) + math.sin(t) * ry * math.cos(rot))
               for t in np.linspace(0, 2 * math.pi, 90)]
        d.polygon(pts, fill=fill)
    if kind == "wing":            # l01 데칼코마니 — 접어 찍은 나비 날개(좌우가 같다)
        for s in (-1, 1):
            ell(s * R * .47, -R * .22, R * .50, R * .44, s * -.45)
            ell(s * R * .36, R * .44, R * .36, R * .30, s * .40)
        ell(0, 0, R * .22, R * .62)
    elif kind == "scope":         # l02 정조준 — 조준경: 둥근 렌즈 + 네 갈래 가늠쇠
        ell(0, 0, R * .74, R * .74)
        for k in range(4):
            a = k * math.pi / 2
            ca, sa = math.cos(a), math.sin(a)
            tip = (c + ca * R * .99, c + sa * R * .99)
            b1 = (c + ca * R * .60 - sa * R * .17, c + sa * R * .60 + ca * R * .17)
            b2 = (c + ca * R * .60 + sa * R * .17, c + sa * R * .60 - ca * R * .17)
            d.polygon([tip, b1, b2], fill=255)
    elif kind == "broken":        # l03 NULL — 깨진 고리: 한 조각이 떨어져 나가 떠 있다
        ell(0, 0, R * .90, R * .90)
        ell(0, 0, R * .50, R * .50, fill=0)
        d.pieslice((c - R, c - R, c + R, c + R), -70, -20, fill=0)
    elif kind == "arch":          # l04 잭과 콩나무 — 위로 긴 아치(자란다)
        w, h = R * .60, R * .92
        d.rounded_rectangle((c - w, c - h + w * .2, c + w, c + h), radius=w * .25, fill=255)
        ell(0, -h + w * .95, w, w)
    elif kind == "melt":          # l05 녹는 시계 — 회중시계가 아래로 녹아 흐른다
        ell(0, -R * .08, R * .74, R * .70)
        d.rounded_rectangle((c - R * .10, c - R * .96, c + R * .10, c - R * .70), radius=R * .05, fill=255)
        ell(0, -R * .93, R * .16, R * .10)
        for x, L, w in ((-.42, .40, .11), (.08, .62, .13), (.46, .30, .09)):
            d.rounded_rectangle((c + R * (x - w), c + R * .30, c + R * (x + w), c + R * (.30 + L) + R * .2),
                                radius=R * w, fill=255)
    return np.asarray(m, np.float32) / 255.0


def coin_leg(ident, kind, R=22.0, soul=True):
    S = R * K * SS
    size = int(S * 2 + 60 * SS)
    m = leg_shape(kind, S, size)
    m = np.asarray(Image.fromarray((m * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(SS * .7)),
                   np.float32) / 255.0
    rim, lit = bevel(m, S * .14)
    c = size / 2
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    th = np.arctan2(yy - c, xx - c)
    col = ramp(METAL["분홍금"], .30 + .65 * lit)
    # 홀로 — 테 위를 무지개가 돈다(옅게)
    hue = (th / (2 * math.pi) + .5) * 3.0
    holo = np.stack([.5 + .5 * np.sin(2 * math.pi * (hue + o)) for o in (0, .33, .66)], -1) * 255
    col = col * .78 + holo * .22
    inner = np.clip(m - rim, 0, 1)
    img = np.zeros((size, size, 4), np.float32)
    img[..., :3] = col
    img[..., 3] = rim * 255
    # 얼굴 — 실루엣 안을 꽉 채운다(옛 플라크는 작은 메달이 떠 있었다)
    if ident != "l03":
        bb = Image.fromarray((inner * 255).astype(np.uint8)).getbbox()
        dd = int(max(bb[2] - bb[0], bb[3] - bb[1]) * 1.02)
        f = np.asarray(face_img(ident, dd), np.float32)
        fa = np.zeros((size, size, 4), np.float32)
        ox, oy = int((bb[0] + bb[2]) / 2 - dd / 2), int((bb[1] + bb[3]) / 2 - dd / 2)
        x0, y0 = max(0, ox), max(0, oy)
        fa[y0:oy + dd, x0:ox + dd] = f[y0 - oy:, x0 - ox:][:size - y0, :size - x0]
        base = np.array((52, 14, 40), np.float32)
        fc = fa[..., :3] * (fa[..., 3:] / 255) + base * (1 - fa[..., 3:] / 255)
        img[..., :3] = img[..., :3] * (1 - inner[..., None]) + fc * inner[..., None]
    else:                                            # NULL — 빈 속: 검은 구멍에 깨진 화소
        rng = np.random.default_rng(4)
        vc = np.array((10, 6, 14), np.float32)
        img[..., :3] = img[..., :3] * (1 - inner[..., None]) + vc * inner[..., None]
        for _ in range(26):
            px = int(c + rng.uniform(-.8, .8) * S)
            py = int(c + rng.uniform(-.8, .8) * S)
            w = int(rng.uniform(.04, .12) * S)
            h = int(SS * K * rng.choice([1, 1, 2]))
            colr = [(255, 70, 160), (90, 230, 255), (255, 255, 255)][rng.integers(0, 3)]
            sl = (slice(py, py + h), slice(px, px + w))
            mm = inner[sl][..., None] * .9
            img[sl][..., :3] = img[sl][..., :3] * (1 - mm) + np.array(colr, np.float32) * mm
    img[..., 3] = np.maximum(img[..., 3], inner * 255)
    out = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGBA")
    if kind == "broken":                             # 떨어져 나간 조각 — 틈 밖에 떠 있다
        dr = ImageDraw.Draw(out)
        for (a0, a1, push) in ((-66, -46, .16), (-44, -24, .26)):
            pts = []
            for a in np.linspace(math.radians(a0), math.radians(a1), 8):
                pts.append((c + math.cos(a) * S * (.90 + push), c + math.sin(a) * S * (.90 + push)))
            for a in np.linspace(math.radians(a1), math.radians(a0), 8):
                pts.append((c + math.cos(a) * S * (.52 + push), c + math.sin(a) * S * (.52 + push)))
            dr.polygon(pts, fill=(232, 120, 170, 255), outline=(255, 220, 236, 255))
    if soul:                                         # 영혼 — 얼굴의 주인공이 판 밖으로 떠오른 한 겹(그림자 · 위로 밀림)
        out = add_soul(out, ident, kind, S, size)
    return out.resize((size // SS, size // SS), Image.Resampling.LANCZOS)


SOUL = {   # 영혼 한 겹 — 얼굴 그림에서 주인공만 오린다(얼굴 칸 좌표 0..36) · 얼마나 떠오르나(얼굴 비)
    "l01": ((6, 4, 30, 30), .16),       # 나비
    "l02": ((14, 14, 22, 22), .10),     # 붉은 점 · 가운데 십자
    "l04": ((9, 8, 22, 30), .14),       # 매달린 잭
    "l05": ((8, 3, 30, 34), .10),       # 녹는 시계 판
}


def add_soul(out, ident, kind, S, size):
    if ident not in SOUL:
        return out
    (x0, y0, x1, y1), up = SOUL[ident]
    face = Image.open(FACE / f"{ident}.png").convert("RGBA")
    bgc = face.getpixel((1, 18))
    a = np.asarray(face, np.float32).copy()
    diff = np.abs(a[..., :3] - np.array(bgc[:3], np.float32)).sum(-1)
    a[..., 3] *= (diff > 60)                         # 바탕색 언저리를 걷어 주인공만
    crop = Image.fromarray(a.astype(np.uint8)).crop((x0, y0, x1, y1))
    k = S * 2 * .62 / 36
    crop = crop.resize((max(1, int(crop.width * k)), max(1, int(crop.height * k))), Image.Resampling.NEAREST)
    c = size / 2
    px = int(c + (x0 - 18) * k)
    py = int(c + (y0 - 18) * k - S * up)
    shadow = Image.new("RGBA", crop.size, (0, 0, 0, 0))
    shadow.putalpha(crop.getchannel("A").point(lambda v: int(v * .55)))
    out.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(SS * 6)), (px + int(S * .05), py + int(S * .12)))
    out.alpha_composite(crop, (px, py))
    return out


def label(dr, x, y, text, size=28, fill=(240, 228, 216)):
    from PIL import ImageFont
    f = ImageFont.truetype(str(ROOT / "fonts/Paperlogy-6SemiBold.ttf"), size)
    dr.text((x, y), text, font=f, fill=fill)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    regular = [("c04", "common"), ("c33", "common"), ("u21", "uncommon"), ("u28", "uncommon"),
               ("r01", "rare"), ("r04", "rare")]
    cell = 360
    W = cell * 6 + 80
    H = 220 + cell * 2 + 140 + 440 + 120
    sheet = Image.new("RGB", (W, H), (22, 14, 20))
    dr = ImageDraw.Draw(sheet)
    label(dr, 40, 24, "동전 다시 디자인 — 시안", 44)
    for row, (name, fn) in enumerate((("A 주화 — 동 · 은 · 금 쇠 · 솟은 테 · 빗살 · 보석 박음", coin_A),
                                      ("B 칩 — 지금 등급 색 · 흰 인레이 · 볼록한 광", coin_B))):
        y0 = 110 + row * (cell + 70)
        label(dr, 40, y0, name, 30)
        for i, (ident, rar) in enumerate(regular):
            im = fn(ident, rar)
            im.thumbnail((cell - 40, cell - 40))
            sheet.paste(im, (40 + i * cell + (cell - im.width) // 2, y0 + 50 + (cell - 40 - im.height) // 2), im)
    y0 = 110 + 2 * (cell + 70)
    label(dr, 40, y0, "전설 — 효과에서 딴 실루엣 · 분홍 금 테 · 홀로 · 판 밖으로 떠오르는 「영혼」", 30)
    legs = [("l01", "wing", "데칼코마니 · 접은 나비"), ("l02", "scope", "정조준 · 조준경"),
            ("l03", "broken", "NULL · 깨진 고리"), ("l04", "arch", "잭과 콩나무 · 아치"),
            ("l05", "melt", "녹는 시계 · 녹는 회중시계")]
    lc = (W - 80) // 5
    for i, (ident, kind, nm) in enumerate(legs):
        im = coin_leg(ident, kind)
        im.thumbnail((lc - 20, 400))
        sheet.paste(im, (40 + i * lc + (lc - im.width) // 2, y0 + 50), im)
        label(dr, 40 + i * lc + 20, y0 + 470, nm, 26, (220, 196, 210))
    sheet.save(OUT / "mock.png")
    print("saved", OUT / "mock.png")


if __name__ == "__main__":
    main()
