"""포스터 굽기 공용 도구 — 레이어 .psd 와 벡터 .ai/.pdf (2026-10-06).

「지금 게임에 포스터가 필요 하거든? A3 사이즈랑 A1 사이즈? 그리고 포스터를 기반으로
세로로 긴 라벨? … 조건은 어도비 프로그램 일러랑 포토샵으로 만들어야해」.
이 PC 에는 어도비가 없어서 두 프로그램이 여는 원본을 여기서 짓는다.

  .psd — 포토샵 3.0 형식(8비트 RGB). 레이어마다 RLE 로 눌러 담고, 묶음(폴더) ·
         한글 레이어 이름(luni) · 해상도(dpi) · 합친 그림(포토샵이 아닌 프로그램과
         일러의 「가져오기」가 읽는 미리보기)을 같이 쓴다.
  .ai  — PDF 호환 .ai(일러 9 이후 .ai 의 겉이 PDF 다). 일러가 그대로 연다.
         재단 상자(TrimBox) · 도련 상자(BleedBox)를 세우고, 그림은 **레이어마다 낱개 이미지
         객체**로(혼합 · 불투명도 그대로), 제목은 글꼴 윤곽을 벡터 경로로 바꿔 얹는다 —
         글꼴이 없는 PC 에서도 안 깨진다. 일러는 PDF 레이어를 무시해 객체가 한 레이어에 든다.
  _ai_kit/ — 일러 스크립트(.jsx) + 낱장 PNG. 일러에서 돌리면 .psd 와 같은 이름의
         레이어 · 하위 레이어로 일러가 직접 .ai 를 짓는다.
  .pdf — 인쇄소에 넘기는 쪽. 그림은 한 장으로 합치고 제목은 벡터.

크기는 mm 로 받고 도련 3mm 를 사방에 더한다. 그림 좌표는 **도련 포함 캔버스**의 px 이다.
"""
from __future__ import annotations

import io
import os
import struct
from dataclasses import dataclass, field

import numpy as np
from PIL import Image

from psd_tools.compression import rle_impl

MM_PER_IN = 25.4
BLEED_MM = 3.0

#  판형 — 재단 크기(mm) · 굽는 dpi.
#  A1 은 200dpi(가로 4724px) — 1m 밖에서 보는 크기라 이 정도면 픽셀이 안 보이고,
#  제목은 벡터라 dpi 와 무관하게 또렷하다. A3 는 손에 들고 보므로 300dpi.
#  X배너는 실사 출력이 보통 100~150dpi 다.
SIZES = {
    "A1": {"mm": (594.0, 841.0), "dpi": 200},
    "A3": {"mm": (297.0, 420.0), "dpi": 300},
    "XB": {"mm": (600.0, 1800.0), "dpi": 150},
}


def canvas_px(key: str, dpi: int | None = None) -> tuple[int, int]:
    """도련 포함 캔버스 크기(px)."""
    s = SIZES[key]
    d = dpi or s["dpi"]
    w = (s["mm"][0] + 2 * BLEED_MM) / MM_PER_IN * d
    h = (s["mm"][1] + 2 * BLEED_MM) / MM_PER_IN * d
    return int(round(w)), int(round(h))


def bleed_px(key: str, dpi: int | None = None) -> int:
    d = dpi or SIZES[key]["dpi"]
    return int(round(BLEED_MM / MM_PER_IN * d))


# ─────────────────────────────────────────────────────────────
#  레이어
# ─────────────────────────────────────────────────────────────
@dataclass
class Layer:
    name: str
    img: Image.Image            # RGBA. 캔버스 전체 크기거나 left/top 에 놓이는 조각
    left: int = 0
    top: int = 0
    opacity: int = 255
    visible: bool = True
    blend: str = "norm"         # norm · mul  · scrn · over · lddg(선형 닷지) …


@dataclass
class Group:
    name: str
    children: list = field(default_factory=list)   # 아래 → 위 순서
    visible: bool = True
    opened: bool = True


#  합친 그림을 짓는 데 쓰는 혼합식. 포토샵 키 → numpy 식.
def _blend(key: str, b: np.ndarray, s: np.ndarray) -> np.ndarray:
    if key == "norm":
        return s
    if key == "mul ":
        return b * s
    if key == "scrn":
        return 1.0 - (1.0 - b) * (1.0 - s)
    if key == "over":
        return np.where(b <= 0.5, 2.0 * b * s, 1.0 - 2.0 * (1.0 - b) * (1.0 - s))
    if key == "lddg":
        return np.minimum(b + s, 1.0)
    if key == "lite":
        return np.maximum(b, s)
    if key == "dark":
        return np.minimum(b, s)
    raise ValueError(f"혼합식 없음: {key}")


def _blend_key(k: str) -> bytes:
    k = {"mul": "mul ", "multiply": "mul ", "screen": "scrn", "overlay": "over",
         "add": "lddg", "normal": "norm", "lighten": "lite", "darken": "dark"}.get(k, k)
    if len(k) != 4:
        raise ValueError(f"포토샵 혼합 키는 네 글자: {k!r}")
    return k.encode("ascii")


def _flat_layers(items, out=None, vis=True):
    """묶음을 풀어 아래 → 위 순서의 (Layer, 보이는가) 목록."""
    out = [] if out is None else out
    for it in items:
        if isinstance(it, Group):
            _flat_layers(it.children, out, vis and it.visible)
        else:
            out.append((it, vis and it.visible))
    return out


def composite(size: tuple[int, int], items, bg=(255, 255, 255)) -> Image.Image:
    """레이어를 아래부터 겹친 RGB 한 장. 포토샵이 합친 그림과 같은 식."""
    w, h = size
    base = np.empty((h, w, 3), np.float32)
    base[:] = np.array(bg, np.float32) / 255.0
    for lay, vis in _flat_layers(items):
        if not vis:
            continue
        im = lay.img.convert("RGBA")
        x0, y0 = lay.left, lay.top
        x1, y1 = x0 + im.width, y0 + im.height
        cx0, cy0, cx1, cy1 = max(x0, 0), max(y0, 0), min(x1, w), min(y1, h)
        if cx0 >= cx1 or cy0 >= cy1:
            continue
        a = np.asarray(im, np.float32)[cy0 - y0:cy1 - y0, cx0 - x0:cx1 - x0] / 255.0
        s = a[..., :3]
        al = a[..., 3:4] * (lay.opacity / 255.0)
        b = base[cy0:cy1, cx0:cx1]
        mixed = _blend(_blend_key(lay.blend).decode(), b, s)
        base[cy0:cy1, cx0:cx1] = b * (1.0 - al) + mixed * al
    return Image.fromarray(np.clip(base * 255.0 + 0.5, 0, 255).astype(np.uint8), "RGB")


# ─────────────────────────────────────────────────────────────
#  .psd 쓰기 — Adobe Photoshop File Formats Specification(2016) 그대로
# ─────────────────────────────────────────────────────────────
def _pascal(name: str, pad: int) -> bytes:
    raw = name.encode("ascii", "replace")[:255]
    b = bytes([len(raw)]) + raw
    while len(b) % pad:
        b += b"\x00"
    return b


def _unicode(s: str) -> bytes:
    return struct.pack(">I", len(s)) + s.encode("utf-16-be")


def _tagged(key: bytes, data: bytes) -> bytes:
    if len(data) % 2:
        data += b"\x00"
    return b"8BIM" + key + struct.pack(">I", len(data)) + data


def _rle_plane(plane: np.ndarray) -> tuple[list[int], bytes]:
    """한 채널(높이 x 너비, uint8)을 줄마다 PackBits. (줄 길이들, 이어 붙인 자료)"""
    counts, chunks = [], []
    for row in plane:
        enc = rle_impl.encode(row.tobytes())
        counts.append(len(enc))
        chunks.append(enc)
    return counts, b"".join(chunks)


def _channel_blob(plane: np.ndarray) -> bytes:
    """레이어 채널 자료: 압축 종류(1=RLE) + 줄 길이(u16) + 자료."""
    if plane.size == 0:
        return struct.pack(">H", 0)
    counts, data = _rle_plane(plane)
    if max(counts) > 0xFFFF:
        raise ValueError("줄 하나가 64KB 를 넘는다 — PSB 가 필요하다")
    return struct.pack(">H", 1) + struct.pack(f">{len(counts)}H", *counts) + data


def _trim(lay: Layer) -> tuple[np.ndarray, int, int]:
    """투명한 가장자리를 깎는다 — 파일이 줄고 포토샵의 레이어 경계가 그림에 맞는다."""
    a = np.asarray(lay.img.convert("RGBA"))
    alpha = a[..., 3]
    ys, xs = np.nonzero(alpha)
    if len(xs) == 0:
        return a[:0, :0], lay.top, lay.left
    y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
    return a[y0:y1, x0:x1], lay.top + int(y0), lay.left + int(x0)


_BLEND_RANGES = b"\x00\x00\xff\xff" * 10      # 포토샵 RGB 기본값(회색 + 네 채널, 원본 · 대상)


def _record(name, top, left, bottom, right, blobs, blend: bytes, opacity, visible,
            lsct: bytes | None, lid: int) -> bytes:
    rec = struct.pack(">iiii", top, left, bottom, right)
    rec += struct.pack(">H", len(blobs))
    for cid, blob in blobs:
        rec += struct.pack(">hI", cid, len(blob))
    flags = 0x00 if visible else 0x02           # 비트 1 이 서면 숨김
    if lsct is not None:
        flags |= 0x18                           # 묶음 칸 — 비트 3 · 4(픽셀 자료 무관)
    rec += b"8BIM" + blend + struct.pack(">BBBB", opacity, 0, flags, 0)
    extra = struct.pack(">I", 0)                                   # 레이어 마스크 없음
    extra += struct.pack(">I", len(_BLEND_RANGES)) + _BLEND_RANGES
    extra += _pascal(name, 4)
    extra += _tagged(b"luni", _unicode(name))
    extra += _tagged(b"lyid", struct.pack(">I", lid))
    if lsct is not None:
        extra += _tagged(b"lsct", lsct)
    rec += struct.pack(">I", len(extra)) + extra
    return rec


def write_psd(path: str, size: tuple[int, int], items, dpi: int,
              flat: Image.Image | None = None) -> Image.Image:
    """items(아래 → 위)를 레이어로 담은 .psd. 합친 그림을 돌려준다."""
    w, h = size
    if w > 30000 or h > 30000:
        raise ValueError("PSD 는 한 변 30000px 까지 — 더 크면 PSB")
    flat = flat if flat is not None else composite(size, items)
    if flat.size != (w, h):
        raise ValueError("합친 그림 크기가 캔버스와 다르다")

    records: list[bytes] = []
    data: list[bytes] = []
    lid = [0]

    def empty_blobs():
        return [(cid, struct.pack(">H", 0)) for cid in (-1, 0, 1, 2)]

    def add_layer(lay: Layer, vis: bool):
        arr, top, left = _trim(lay)
        hh, ww = arr.shape[:2]
        blobs = []
        for cid, ch in ((-1, 3), (0, 0), (1, 1), (2, 2)):
            blobs.append((cid, _channel_blob(np.ascontiguousarray(arr[..., ch]))))
        lid[0] += 1
        records.append(_record(lay.name, top, left, top + hh, left + ww, blobs,
                               _blend_key(lay.blend), int(lay.opacity), vis, None, lid[0]))
        data.extend(b for _, b in blobs)

    def walk(items_, vis_parent=True):
        for it in items_:
            if isinstance(it, Group):
                # 아래 → 위: 닫는 칸(</Layer group>) · 자식들 · 여는 칸(묶음 이름)
                lid[0] += 1
                blobs = empty_blobs()
                records.append(_record("</Layer group>", 0, 0, 0, 0, blobs, b"norm", 255,
                                       True, struct.pack(">I", 3), lid[0]))
                data.extend(b for _, b in blobs)
                walk(it.children, vis_parent and it.visible)
                lid[0] += 1
                blobs = empty_blobs()
                kind = 1 if it.opened else 2
                records.append(_record(it.name, 0, 0, 0, 0, blobs, b"pass", 255, it.visible,
                                       struct.pack(">I", kind) + b"8BIMpass", lid[0]))
                data.extend(b for _, b in blobs)
            else:
                add_layer(it, it.visible)

    walk(items)

    layer_info = struct.pack(">h", len(records)) + b"".join(records) + b"".join(data)
    while len(layer_info) % 4:
        layer_info += b"\x00"
    lmi = struct.pack(">I", len(layer_info)) + layer_info + struct.pack(">I", 0)

    # 이미지 리소스 — 해상도(0x03ED) · 버전 정보(0x0421, 합친 그림이 진짜임)
    def res(rid: int, payload: bytes) -> bytes:
        if len(payload) % 2:
            payload += b"\x00"
        return b"8BIM" + struct.pack(">H", rid) + b"\x00\x00" + struct.pack(">I", len(payload)) + payload

    fx = int(round(dpi * 65536))
    resinfo = struct.pack(">IHHIHH", fx, 1, 2, fx, 1, 2)     # ppi · 표시 단위 cm
    verinfo = struct.pack(">IB", 1, 1) + _unicode("HIGHTON poster_lib") + _unicode("Adobe Photoshop") + struct.pack(">I", 1)
    resources = res(0x03ED, resinfo) + res(0x0421, verinfo)

    # 합친 그림 — 압축 1 · 모든 채널의 줄 길이를 먼저 · 그다음 자료
    fa = np.asarray(flat.convert("RGB"))
    all_counts, all_data = [], []
    for ch in range(3):
        c, d = _rle_plane(np.ascontiguousarray(fa[..., ch]))
        all_counts += c
        all_data.append(d)
    merged = struct.pack(">H", 1) + struct.pack(f">{len(all_counts)}H", *all_counts) + b"".join(all_data)

    with open(path, "wb") as f:
        f.write(b"8BPS" + struct.pack(">H", 1) + b"\x00" * 6)
        f.write(struct.pack(">HIIHH", 3, h, w, 8, 3))
        f.write(struct.pack(">I", 0))                              # 색 모드 자료 없음
        f.write(struct.pack(">I", len(resources)) + resources)
        f.write(struct.pack(">I", len(lmi)) + lmi)
        f.write(merged)
    return flat


# ─────────────────────────────────────────────────────────────
#  제목 — 글꼴 윤곽을 벡터 경로로
# ─────────────────────────────────────────────────────────────
@dataclass
class Title:
    """캔버스 px 좌표의 글줄 하나. x 는 align 에 따라 왼쪽 · 가운데 · 오른쪽."""
    text: str
    font: str                   # .ttf 경로
    size_px: float              # 글자 크기(em, px)
    x: float
    baseline: float             # 기준선 y(px)
    rgb: tuple = (245, 238, 225)
    tracking: float = 0.0       # em 비율로 자간(예: 0.08)
    align: str = "center"       # left · center · right
    name: str = "제목"


def _glyph_contours(title: Title):
    """[(윤곽 = [("M",(x,y)) | ("L",(x,y)) | ("C",(x1,y1,x2,y2,x,y))] …)] — 캔버스 px."""
    from fontTools.ttLib import TTFont
    from fontTools.pens.basePen import BasePen

    font = TTFont(title.font)
    gs = font.getGlyphSet()
    cmap = font.getBestCmap()
    upm = font["head"].unitsPerEm
    k = title.size_px / upm
    hmtx = font["hmtx"]

    names, adv = [], []
    for ch in title.text:
        gn = cmap.get(ord(ch))
        if gn is None:
            raise ValueError(f"글꼴에 없는 글자: {ch!r}")
        names.append(gn)
        adv.append(hmtx[gn][0] * k)
    track = title.tracking * title.size_px
    total = sum(adv) + track * (len(names) - 1)
    x0 = {"left": title.x, "center": title.x - total / 2, "right": title.x - total}[title.align]

    contours = []

    class Pen(BasePen):
        def __init__(self, gs_, ox):
            super().__init__(gs_)
            self.ox = ox
            self.cur = None

        def _p(self, pt):
            return (self.ox + pt[0] * k, title.baseline - pt[1] * k)

        def _moveTo(self, pt):
            self.cur = [("M", self._p(pt))]

        def _lineTo(self, pt):
            self.cur.append(("L", self._p(pt)))

        def _curveToOne(self, p1, p2, p3):
            a, b, c = self._p(p1), self._p(p2), self._p(p3)
            self.cur.append(("C", (*a, *b, *c)))

        def _closePath(self):
            if self.cur:
                contours.append(self.cur)
            self.cur = None

        _endPath = _closePath

    x = x0
    for gn, a in zip(names, adv):
        gs[gn].draw(Pen(gs, x))
        x += a + track
    return contours


def title_width(title: Title) -> float:
    from fontTools.ttLib import TTFont
    font = TTFont(title.font)
    cmap = font.getBestCmap()
    k = title.size_px / font["head"].unitsPerEm
    adv = [font["hmtx"][cmap[ord(c)]][0] * k for c in title.text]
    return sum(adv) + title.tracking * title.size_px * (len(adv) - 1)


def _pdf_page(w_pt, h_pt):
    import pymupdf
    doc = pymupdf.open()
    page = doc.new_page(width=w_pt, height=h_pt)
    return doc, page


def _draw_title(page, title: Title, px2pt: float, oc: int = 0):
    import pymupdf
    sh = page.new_shape()
    for con in _glyph_contours(title):
        cur = None
        start = None
        for op, v in con:
            if op == "M":
                cur = pymupdf.Point(v[0] * px2pt, v[1] * px2pt)
                start = cur
            elif op == "L":
                p = pymupdf.Point(v[0] * px2pt, v[1] * px2pt)
                sh.draw_line(cur, p)
                cur = p
            else:
                p1 = pymupdf.Point(v[0] * px2pt, v[1] * px2pt)
                p2 = pymupdf.Point(v[2] * px2pt, v[3] * px2pt)
                p3 = pymupdf.Point(v[4] * px2pt, v[5] * px2pt)
                sh.draw_bezier(cur, p1, p2, p3)
                cur = p3
        if start is not None and cur is not None and (abs(cur.x - start.x) > 1e-6 or abs(cur.y - start.y) > 1e-6):
            sh.draw_line(cur, start)
    rgb = tuple(c / 255.0 for c in title.rgb)
    sh.finish(color=None, fill=rgb, even_odd=False, closePath=True, oc=oc)
    sh.commit()


def title_raster(size: tuple[int, int], titles: list[Title], ss: int = 1) -> Image.Image:
    """제목 벡터를 그대로 래스터로 — .psd 의 제목 레이어가 .ai 와 한 점도 안 어긋난다."""
    import pymupdf
    w, h = size
    doc, page = _pdf_page(w, h)                 # 1px = 1pt 페이지
    for t in titles:
        _draw_title(page, t, 1.0)
    pix = page.get_pixmap(matrix=pymupdf.Matrix(ss, ss), alpha=True)
    im = Image.frombytes("RGBA", (pix.width, pix.height), pix.samples)
    if ss != 1:
        im = im.resize((w, h), Image.LANCZOS)
    doc.close()
    return im


# ─────────────────────────────────────────────────────────────
#  .pdf — 인쇄용. 그림 한 장 + 벡터 제목
# ─────────────────────────────────────────────────────────────
def write_pdf(pdf_path: str, key: str, art: Image.Image, titles: list[Title],
              dpi: int | None = None, jpeg_q: int = 0) -> None:
    """art(도련 포함 캔버스 크기 RGB) 위에 벡터 제목을 얹은 인쇄용 PDF.

    인쇄소 RIP 이 투명 · 혼합을 다르게 풀 일이 없게 그림은 **한 장으로 합쳐** 담는다.
    jpeg_q 가 0 이면 그림을 무손실(Flate)로 담는다."""
    import pymupdf
    d = dpi or SIZES[key]["dpi"]
    tw, th = SIZES[key]["mm"]
    pt = 72.0 / MM_PER_IN
    W, H = (tw + 2 * BLEED_MM) * pt, (th + 2 * BLEED_MM) * pt
    px2pt = 72.0 / d
    doc, page = _pdf_page(W, H)
    b = BLEED_MM * pt
    #  상자는 **페이지가 실제로 잡힌 크기**에서 잰다. MuPDF 가 페이지를 float32 로 쥐어
    #  A1(1700.8 x 2401.0pt)은 넘긴 값보다 0.0001pt 작게 잡히고, 넘긴 값으로 BleedBox 를
    #  세우면 「BleedBox not in MediaBox」 로 멈췄다(A3 · X배너는 우연히 맞았다).
    mb = page.mediabox
    page.set_bleedbox(mb)
    page.set_trimbox(pymupdf.Rect(mb.x0 + b, mb.y0 + b, mb.x1 - b, mb.y1 - b))

    oc_art = doc.add_ocg("그림", on=True)
    oc_title = doc.add_ocg("제목", on=True)

    buf = io.BytesIO()
    if jpeg_q:
        art.convert("RGB").save(buf, "JPEG", quality=jpeg_q, subsampling=0, dpi=(d, d))
    else:
        art.convert("RGB").save(buf, "PNG", dpi=(d, d))
    page.insert_image(pymupdf.Rect(0, 0, W, H), stream=buf.getvalue(), keep_proportion=False, oc=oc_art)
    for t in titles:
        _draw_title(page, t, px2pt, oc=oc_title)

    doc.set_metadata({"title": "HIGHTON", "creator": "", "producer": ""})
    data = doc.tobytes(garbage=3, deflate=True)
    doc.close()
    with open(pdf_path, "wb") as f:
        f.write(data)


# ─────────────────────────────────────────────────────────────
#  레이어 하나씩 — .ai 와 일러 짓기 꾸러미가 같이 쓴다
# ─────────────────────────────────────────────────────────────
#  「일러에서 개별로 이미지를 넣어줄래? 이러면 내가 편집을 할 수 없는데」(2026-10-06) —
#  .ai 가 합친 그림 한 장이라 일러에서 고칠 것이 제목뿐이었다. 레이어를 하나씩 따로 담는다.
#  ⚠ 일러는 PDF 의 레이어(OCG)를 **무시하고** 한 레이어에 다 넣는다(Adobe 커뮤니티
#  「Illustrator flattens existing layers when opened PDF」). 그래서 .ai 는 「낱개 객체」까지만
#  되고, 이름 붙은 레이어는 일러 스크립트(write_ai_kit)가 일러 안에서 짓는다.
_PDF_BM = {"norm": "Normal", "mul ": "Multiply", "scrn": "Screen", "over": "Overlay",
           "dark": "Darken", "lite": "Lighten", "lddg": "Screen"}
#  일러에는 선형 닷지(더하기)가 없다 — 스크린이 가장 가깝다.
_AI_BM = {"norm": "NORMAL", "mul ": "MULTIPLY", "scrn": "SCREEN", "over": "OVERLAY",
          "dark": "DARKEN", "lite": "LIGHTEN", "lddg": "SCREEN"}


def _walk_layers(items, path=(), vis=True):
    """(묶음 경로, Layer, 조상까지 보이는가) — 아래 → 위."""
    for it in items:
        if isinstance(it, Group):
            yield from _walk_layers(it.children, path + (it.name,), vis and it.visible)
        else:
            yield path, it, vis


def _hidden_groups(items, path=()):
    for it in items:
        if isinstance(it, Group):
            if not it.visible:
                yield path + (it.name,)
            yield from _hidden_groups(it.children, path + (it.name,))


def _anchors(title: Title):
    """제목 윤곽 → 윤곽마다 [[ax, ay, lx, ly, rx, ry] …] — 일러 PathPoint 의 앵커 · 왼 핸들 · 오른 핸들."""
    out = []
    for con in _glyph_contours(title):
        pts = []
        for op, v in con:
            if op in ("M", "L"):
                pts.append([v[0], v[1], v[0], v[1], v[0], v[1]])
            else:
                pts[-1][4], pts[-1][5] = v[0], v[1]
                pts.append([v[4], v[5], v[2], v[3], v[4], v[5]])
        #  닫는 점이 첫 점과 같으면 하나로 — 그 점의 왼 핸들을 첫 점이 물려받는다.
        if len(pts) > 1 and abs(pts[-1][0] - pts[0][0]) < 1e-6 and abs(pts[-1][1] - pts[0][1]) < 1e-6:
            last = pts.pop()
            pts[0][2], pts[0][3] = last[2], last[3]
        if len(pts) >= 2:
            out.append(pts)
    return out


# ─────────────────────────────────────────────────────────────
#  .ai — 편집용. 레이어마다 낱개 이미지 객체(혼합 · 불투명도 그대로) + 벡터 제목
# ─────────────────────────────────────────────────────────────
def _pdf_text(s: str) -> bytes:
    return b"<FEFF" + s.encode("utf-16-be").hex().upper().encode() + b">"


def _f(v: float) -> bytes:
    s = f"{v:.4f}".rstrip("0").rstrip(".")
    return (s if s not in ("", "-0") else "0").encode()


class _PdfOut:
    """PDF 를 파일로 흘려 쓴다 — 레이어 일흔 장을 한꺼번에 들고 있지 않는다."""

    def __init__(self, f):
        self.f = f
        self.off = {}
        self.n = 0
        f.write(b"%PDF-1.6\n%\xe2\xe3\xcf\xd3\n")

    def new(self) -> int:
        self.n += 1
        return self.n

    def put(self, num: int, body: bytes) -> None:
        self.off[num] = self.f.tell()
        self.f.write(b"%d 0 obj\n" % num + body + b"\nendobj\n")

    def stream(self, num: int, dic: bytes, data: bytes) -> None:
        self.put(num, b"<<" + dic + b" /Length %d>>\nstream\n" % len(data) + data + b"\nendstream")

    def close(self, root: int, info: int) -> None:
        x = self.f.tell()
        self.f.write(b"xref\n0 %d\n0000000000 65535 f \n" % (self.n + 1))
        for i in range(1, self.n + 1):
            self.f.write(b"%010d 00000 n \n" % self.off[i])
        self.f.write(b"trailer\n<< /Size %d /Root %d 0 R /Info %d 0 R >>\nstartxref\n%d\n%%%%EOF\n"
                     % (self.n + 1, root, info, x))


def write_ai(ai_path: str, key: str, items, titles: list[Title], dpi: int | None = None) -> int:
    """레이어마다 낱개 이미지 객체로 담은 PDF 호환 .ai. 담은 이미지 수를 돌려준다.

    · 레이어는 투명한 가장자리를 깎은 크기 그대로(SMask 알파) — 일러에서 하나씩 집어 옮긴다.
    · 혼합(스크린 등)과 불투명도는 객체마다 ExtGState 로 — 일러 투명도 패널에 그대로 선다.
    · 숨긴 레이어는 안 담는다(.psd 와 일러 짓기 꾸러미에는 있다).
    · 제목은 글꼴 윤곽 벡터. 좌표는 캔버스 px 를 한 번의 cm 으로 pt · 아래위 뒤집기."""
    import zlib
    d = dpi or SIZES[key]["dpi"]
    tw, th = SIZES[key]["mm"]
    pt = 72.0 / MM_PER_IN
    W, H = (tw + 2 * BLEED_MM) * pt, (th + 2 * BLEED_MM) * pt
    k = 72.0 / d
    b = BLEED_MM * pt
    with open(ai_path, "wb") as f:
        pdf = _PdfOut(f)
        cat, pages, page, cont, info = (pdf.new() for _ in range(5))
        ocg_of: dict[str, int] = {}
        xobj: list[tuple[bytes, int]] = []
        gs_of: dict[tuple, bytes] = {}
        ops: list[bytes] = [b"q %s 0 0 %s 0 %s cm" % (_f(k), _f(-k), _f(H))]

        def ocg(name: str) -> bytes:
            if name not in ocg_of:
                num = pdf.new()
                pdf.put(num, b"<< /Type /OCG /Name " + _pdf_text(name) + b" >>")
                ocg_of[name] = num
            return b"/oc%d" % list(ocg_of).index(name)

        cur_oc = None
        n_img = 0
        for path, lay, vis in _walk_layers(items):
            if not (vis and lay.visible):
                continue
            arr, top, left = _trim(lay)
            hh, ww = arr.shape[:2]
            if hh == 0 or ww == 0:
                continue
            oc = ocg(path[0] if path else lay.name)
            if oc != cur_oc:
                if cur_oc is not None:
                    ops.append(b"EMC")
                ops.append(b"/OC " + oc + b" BDC")
                cur_oc = oc
            alpha = arr[..., 3]
            smask = None
            if alpha.min() < 255:
                smask = pdf.new()
                pdf.stream(smask, b" /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceGray"
                           b" /BitsPerComponent 8 /Filter /FlateDecode" % (ww, hh),
                           zlib.compress(np.ascontiguousarray(alpha).tobytes(), 6))
            im = pdf.new()
            rgb = np.ascontiguousarray(arr[..., :3]).tobytes()
            pdf.stream(im, b" /Type /XObject /Subtype /Image /Width %d /Height %d /ColorSpace /DeviceRGB"
                       b" /BitsPerComponent 8 /Filter /FlateDecode" % (ww, hh)
                       + (b" /SMask %d 0 R" % smask if smask else b""),
                       zlib.compress(rgb, 6))
            del arr, rgb, alpha
            nm = b"/Im%d" % len(xobj)
            xobj.append((nm, im))
            g = (_PDF_BM[_blend_key(lay.blend).decode()], round(lay.opacity / 255.0, 4))
            if g not in gs_of:
                gs_of[g] = b"/GS%d" % len(gs_of)
            ops.append(b"q " + gs_of[g] + b" gs %d 0 0 %d %d %d cm " % (ww, -hh, left, top + hh) + nm + b" Do Q")
            n_img += 1
        if cur_oc is not None:
            ops.append(b"EMC")

        if titles:
            ops.append(b"/OC " + ocg("제목") + b" BDC")
            for t in titles:
                r, g_, bl = (c / 255.0 for c in t.rgb)
                ops.append(b"%s %s %s rg" % (_f(r), _f(g_), _f(bl)))
                for con in _glyph_contours(t):
                    for op, v in con:
                        if op == "M":
                            ops.append(b"%s %s m" % (_f(v[0]), _f(v[1])))
                        elif op == "L":
                            ops.append(b"%s %s l" % (_f(v[0]), _f(v[1])))
                        else:
                            ops.append(b" ".join(_f(c) for c in v) + b" c")
                    ops.append(b"h")
                ops.append(b"f")
            ops.append(b"EMC")
        ops.append(b"Q")
        pdf.stream(cont, b" /Filter /FlateDecode", zlib.compress(b"\n".join(ops), 9))

        ext = b" ".join(nm + b" <</Type /ExtGState /BM /" + bm.encode() + b" /ca " + _f(op) + b" /CA " + _f(op) + b">>"
                        for (bm, op), nm in gs_of.items())
        xo = b" ".join(nm + b" %d 0 R" % num for nm, num in xobj)
        props = b" ".join(b"/oc%d %d 0 R" % (i, num) for i, num in enumerate(ocg_of.values()))
        box = b"[0 0 %s %s]" % (_f(W), _f(H))
        trim = b"[%s %s %s %s]" % (_f(b), _f(b), _f(W - b), _f(H - b))
        pdf.put(page, b"<< /Type /Page /Parent %d 0 R /MediaBox " % pages + box + b" /BleedBox " + box
                + b" /TrimBox " + trim + b" /Contents %d 0 R" % cont
                + b" /Group << /S /Transparency /CS /DeviceRGB >>"
                + b" /Resources << /XObject << " + xo + b" >> /ExtGState << " + ext + b" >> /Properties << "
                + props + b" >> >> >>")
        pdf.put(pages, b"<< /Type /Pages /Kids [%d 0 R] /Count 1 >>" % page)
        order = b" ".join(b"%d 0 R" % n for n in ocg_of.values())
        pdf.put(cat, b"<< /Type /Catalog /Pages %d 0 R /OCProperties << /OCGs [" % pages + order
                + b"] /D << /Order [" + order + b"] /ON [" + order + b"] >> >> >>")
        pdf.put(info, b"<< /Title (HIGHTON) /Producer (HIGHTON poster_lib) >>")
        pdf.close(cat, info)
    return n_img


# ─────────────────────────────────────────────────────────────
#  일러 짓기 꾸러미 — 낱장 PNG + 일러 스크립트(.jsx)
# ─────────────────────────────────────────────────────────────
#  일러에서 스크립트를 한 번 돌리면 **일러가 직접** .ai 를 짓는다 — .psd 의 묶음 · 레이어
#  이름이 일러 레이어 · 하위 레이어로 서고, 하위 레이어 하나에 이미지 하나(심어 넣기 embed),
#  혼합 · 불투명도 · 숨김이 그대로, 제목은 고칠 수 있는 벡터 경로(복합 패스)다.
#  ExtendScript 는 ES3 이고 .jsx 를 시스템 코드 페이지로 읽을 수 있어 한글은 전부 \uXXXX 로 쓴다.
def _js_str(s: str) -> str:
    out = []
    for ch in s:
        o = ord(ch)
        if ch in "\\\"":
            out.append("\\" + ch)
        elif 32 <= o < 127:
            out.append(ch)
        else:
            out.append("\\u%04X" % o)
    return '"' + "".join(out) + '"'


def _js_num(v: float) -> str:
    return _f(v).decode()


_JSX_BODY = r"""
(function () {
    var here = File($.fileName).parent;
    var K = 72 / DPI;
    var oldUI = app.userInteractionLevel;
    app.userInteractionLevel = UserInteractionLevel.DONTDISPLAYALERTS;
    app.coordinateSystem = CoordinateSystem.DOCUMENTCOORDINATESYSTEM;

    var preset = new DocumentPreset();
    preset.title = NAME;
    preset.width = TRIM_W;
    preset.height = TRIM_H;
    preset.colorMode = DocumentColorSpace.RGB;
    try { preset.units = RulerUnits.Millimeters; } catch (e0) {}
    try { preset.rasterResolution = DocumentRasterResolution.HighResolution; } catch (e1) {}
    try {
        preset.documentBleedLink = true;
        preset.documentBleedOffsetRect = [BLEED, BLEED, BLEED, BLEED];
    } catch (e2) {}
    var doc = null;
    var tries = ["Print", "Art & Illustration", "Web"];
    try {
        var sp = app.startupPresetsList;
        for (var s = 0; s < sp.length; s++) { tries.push(sp[s]); }
    } catch (e3) {}
    for (var t = 0; t < tries.length && doc == null; t++) {
        try { doc = app.documents.addDocument(tries[t], preset, false); } catch (e4) { doc = null; }
    }
    if (doc == null) { doc = app.documents.add(DocumentColorSpace.RGB, TRIM_W, TRIM_H); }

    var ab = doc.artboards[0].artboardRect;          // [left, top, right, bottom]
    var ydir = (ab[1] > ab[3]) ? -1 : 1;             // document coords: y up -> ydir = -1
    if (Math.abs((ab[2] - ab[0]) - TRIM_W) > 0.5 || Math.abs(Math.abs(ab[1] - ab[3]) - TRIM_H) > 0.5) {
        doc.artboards[0].artboardRect = [ab[0], ab[1], ab[0] + TRIM_W, ab[1] + ydir * TRIM_H];
        ab = doc.artboards[0].artboardRect;
    }
    function X(px) { return ab[0] - BLEED + px * K; }
    function Y(px) { return ab[1] + ydir * (px * K - BLEED); }

    var base = doc.layers[0];
    var made = {};
    function sub(parent, name) {
        var L = (parent == null) ? doc.layers.add() : parent.layers.add();
        L.name = name;
        try { L.move(parent == null ? doc : parent, ElementPlacement.PLACEATBEGINNING); } catch (e5) {}
        return L;
    }
    function ensure(path) {
        var parent = null, key = "";
        for (var i = 0; i < path.length; i++) {
            key += "|" + path[i];
            if (!made[key]) { made[key] = sub(parent, path[i]); }
            parent = made[key];
        }
        return parent;
    }

    var fails = [];
    for (var p = 0; p < PARTS.length; p++) {
        var P = PARTS[p];
        var L = sub(ensure(P.g), P.n);
        try {
            var pi = L.placedItems.add();
            pi.file = new File(here.fsName + "/parts/" + P.f);
            pi.width = P.w * K;
            pi.height = P.h * K;
            pi.position = [X(P.x), Y(P.y)];
            var it = pi;
            try { pi.embed(); it = L.pageItems[0]; } catch (e6) { it = pi; }
            try { it.name = P.n; } catch (e7) {}
            if (P.bm != "NORMAL") { try { it.blendingMode = BlendModes[P.bm]; } catch (e8) {} }
            if (P.op < 100) { try { it.opacity = P.op; } catch (e9) {} }
        } catch (err) {
            fails.push(P.f + " " + err);
        }
        if (!P.v) { L.visible = false; }
    }

    for (var q = 0; q < TITLES.length; q++) {
        var T = TITLES[q];
        var TL = sub(ensure([TITLE_GROUP]), T.n);
        var col = new RGBColor();
        col.red = T.rgb[0]; col.green = T.rgb[1]; col.blue = T.rgb[2];
        var cp = TL.compoundPathItems.add();
        for (var c = 0; c < T.c.length; c++) {
            var C = T.c[c];
            var path = cp.pathItems.add();
            var pts = [];
            for (var a = 0; a < C.length; a += 6) { pts.push([X(C[a]), Y(C[a + 1])]); }
            path.setEntirePath(pts);
            for (var a2 = 0, j = 0; a2 < C.length; a2 += 6, j++) {
                var pp = path.pathPoints[j];
                pp.leftDirection = [X(C[a2 + 2]), Y(C[a2 + 3])];
                pp.rightDirection = [X(C[a2 + 4]), Y(C[a2 + 5])];
                pp.pointType = PointType.CORNER;
            }
            path.closed = true;
            path.stroked = false;
            path.filled = true;
            path.fillColor = col;
            try { path.evenodd = false; } catch (e10) {}
        }
        try { cp.name = T.n; } catch (e11) {}
    }

    for (var h = 0; h < HIDDEN_GROUPS.length; h++) {
        try { ensure(HIDDEN_GROUPS[h]).visible = false; } catch (e12) {}
    }
    try { if (base.pageItems.length == 0 && base.layers.length == 0) { base.remove(); } } catch (e13) {}

    var out = new File(here.fsName + "/" + NAME + ".ai");
    var opt = new IllustratorSaveOptions();
    opt.pdfCompatible = true;
    try { opt.embedLinkedFiles = true; } catch (e14) {}
    opt.compressed = true;
    doc.saveAs(out, opt);
    app.userInteractionLevel = oldUI;
    alert(fails.length ? (NAME + ".ai\n" + fails.join("\n")) : (NAME + ".ai"));
})();
"""


def write_ai_kit(kit_dir: str, name: str, key: str, items, titles: list[Title],
                 dpi: int | None = None, title_group: str = "제목") -> int:
    """kit_dir/parts/pNNN.png(레이어 낱장 — 도련 포함 캔버스에서 투명 가장자리를 깎은 조각)
    + kit_dir/<name>_illustrator.jsx. 스크립트는 같은 폴더에 <name>.ai 를 짓는다. 낱장 수를 돌려준다."""
    d = dpi or SIZES[key]["dpi"]
    tw, th = SIZES[key]["mm"]
    pt = 72.0 / MM_PER_IN
    parts_dir = os.path.join(kit_dir, "parts")
    os.makedirs(parts_dir, exist_ok=True)
    for fn in os.listdir(parts_dir):
        if fn.endswith(".png"):
            os.remove(os.path.join(parts_dir, fn))
    rows = []
    n = 0
    for path, lay, vis in _walk_layers(items):
        arr, top, left = _trim(lay)
        hh, ww = arr.shape[:2]
        if hh == 0 or ww == 0:
            continue
        n += 1
        fn = "p%03d.png" % n
        Image.fromarray(np.ascontiguousarray(arr), "RGBA").save(os.path.join(parts_dir, fn), dpi=(d, d),
                                                                compress_level=6)
        del arr
        bk = _blend_key(lay.blend).decode()
        rows.append("    {g: [%s], n: %s, f: \"%s\", x: %d, y: %d, w: %d, h: %d, bm: \"%s\", op: %s, v: %s}" % (
            ", ".join(_js_str(g) for g in path), _js_str(lay.name), fn, left, top, ww, hh,
            _AI_BM[bk], _js_num(round(lay.opacity / 255.0 * 100.0, 2)), "true" if lay.visible else "false"))
    trows = []
    for t in titles:
        cons = ["[" + ", ".join(_js_num(v) for a in pts for v in a) + "]" for pts in _anchors(t)]
        trows.append("    {n: %s, rgb: [%d, %d, %d], c: [\n        %s\n    ]}" % (
            _js_str(t.name), t.rgb[0], t.rgb[1], t.rgb[2], ",\n        ".join(cons)))
    hidden = [list(p) for p in _hidden_groups(items)]
    head = [
        "#target illustrator",
        "// HIGHTON %s - Illustrator layer builder (scripts/tools/poster/poster_lib.py write_ai_kit)" % key,
        "var NAME = %s;" % _js_str(name),
        "var DPI = %d;" % d,
        "var TRIM_W = %s;" % _js_num(tw * pt),
        "var TRIM_H = %s;" % _js_num(th * pt),
        "var BLEED = %s;" % _js_num(BLEED_MM * pt),
        "var TITLE_GROUP = %s;" % _js_str(title_group),
        "var PARTS = [\n" + ",\n".join(rows) + "\n];",
        "var TITLES = [\n" + ",\n".join(trows) + "\n];",
        "var HIDDEN_GROUPS = [" + ", ".join("[" + ", ".join(_js_str(g) for g in p) + "]" for p in hidden) + "];",
    ]
    js = "\n".join(head) + "\n" + _JSX_BODY
    js = "".join(ch if ord(ch) < 128 else "\\u%04X" % ord(ch) for ch in js)   # 혹시 남은 한글까지 ASCII 로
    with open(os.path.join(kit_dir, name + "_illustrator.jsx"), "w", encoding="ascii", newline="\r\n") as f:
        f.write(js)
    return n


def build(out_stem: str, key: str, items, titles: list[Title], dpi: int | None = None,
          title_group: str = "제목", kit: bool = True) -> Image.Image:
    """한 판형을 통째로:
      <stem>.psd           포토샵 — 레이어 · 묶음(제목은 래스터 레이어)
      <stem>.ai            일러 — 레이어마다 낱개 이미지 객체 + 벡터 제목
      <stem>.pdf           인쇄용 — 그림 한 장 + 벡터 제목
      <stem>_ai_kit/       일러 스크립트 + 낱장 PNG — 일러가 이름 붙은 레이어로 .ai 를 짓는다
      <stem>_preview.png
    items 는 그림 레이어(아래 → 위)."""
    d = dpi or SIZES[key]["dpi"]
    size = canvas_px(key, d)
    art_flat = composite(size, items)
    psd_items = list(items)
    if titles:
        psd_items.append(Group(title_group, [Layer(t.name, title_raster(size, [t], ss=2)) for t in titles]))
    flat = composite(size, psd_items)
    write_psd(out_stem + ".psd", size, psd_items, d, flat=flat)
    write_pdf(out_stem + ".pdf", key, art_flat, titles, d)
    write_ai(out_stem + ".ai", key, items, titles, d)
    if kit:
        write_ai_kit(out_stem + "_ai_kit", os.path.basename(out_stem), key, items, titles, d, title_group)
    pv = flat.copy()
    pv.thumbnail((1400, 1400 * 3), Image.LANCZOS)
    pv.save(out_stem + "_preview.png")
    return flat
