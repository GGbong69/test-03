"""포스터 굽기 공용 도구 — 레이어 .psd 와 벡터 .ai/.pdf (2026-10-06).

「지금 게임에 포스터가 필요 하거든? A3 사이즈랑 A1 사이즈? 그리고 포스터를 기반으로
세로로 긴 라벨? … 조건은 어도비 프로그램 일러랑 포토샵으로 만들어야해」.
이 PC 에는 어도비가 없어서 두 프로그램이 여는 원본을 여기서 짓는다.

  .psd — 포토샵 3.0 형식(8비트 RGB). 레이어마다 RLE 로 눌러 담고, 묶음(폴더) ·
         한글 레이어 이름(luni) · 해상도(dpi) · 합친 그림(포토샵이 아닌 프로그램과
         일러의 「가져오기」가 읽는 미리보기)을 같이 쓴다.
  .ai  — PDF 호환 .ai(일러 9 이후 .ai 의 겉이 PDF 다). 일러가 그대로 연다.
         재단 상자(TrimBox) · 도련 상자(BleedBox)를 세우고, 그림은 한 장으로 깔고,
         제목은 글꼴 윤곽을 벡터 경로로 바꿔 얹는다 — 글꼴이 없는 PC 에서도 안 깨진다.
  .pdf — .ai 와 같은 내용. 인쇄소에 넘기는 쪽.

크기는 mm 로 받고 도련 3mm 를 사방에 더한다. 그림 좌표는 **도련 포함 캔버스**의 px 이다.
"""
from __future__ import annotations

import io
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


def write_ai(ai_path: str, pdf_path: str | None, key: str, art: Image.Image,
             titles: list[Title], dpi: int | None = None, jpeg_q: int = 0) -> None:
    """art(도련 포함 캔버스 크기 RGB) 위에 벡터 제목을 얹은 PDF 호환 .ai(그리고 같은 .pdf).

    jpeg_q 가 0 이면 그림을 무손실(Flate)로 담는다."""
    import pymupdf
    d = dpi or SIZES[key]["dpi"]
    tw, th = SIZES[key]["mm"]
    pt = 72.0 / MM_PER_IN
    W, H = (tw + 2 * BLEED_MM) * pt, (th + 2 * BLEED_MM) * pt
    px2pt = 72.0 / d
    doc, page = _pdf_page(W, H)
    b = BLEED_MM * pt
    page.set_bleedbox(pymupdf.Rect(0, 0, W, H))
    page.set_trimbox(pymupdf.Rect(b, b, W - b, H - b))

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
    with open(ai_path, "wb") as f:
        f.write(data)
    if pdf_path:
        with open(pdf_path, "wb") as f:
            f.write(data)


def build(out_stem: str, key: str, items, titles: list[Title], dpi: int | None = None,
          title_group: str = "제목") -> Image.Image:
    """한 판형을 통째로: <stem>.psd · <stem>.ai · <stem>.pdf · <stem>_preview.png.

    items 는 그림 레이어(아래 → 위). 제목은 벡터로 받아 .psd 에는 맨 위 레이어로,
    .ai/.pdf 에는 벡터 경로로 넣는다."""
    d = dpi or SIZES[key]["dpi"]
    size = canvas_px(key, d)
    art_flat = composite(size, items)
    t_img = title_raster(size, titles, ss=2) if titles else None
    psd_items = list(items)
    if t_img is not None:
        psd_items.append(Group(title_group, [Layer(t.name, title_raster(size, [t], ss=2)) for t in titles]))
    flat = composite(size, psd_items)
    write_psd(out_stem + ".psd", size, psd_items, d, flat=flat)
    write_ai(out_stem + ".ai", out_stem + ".pdf", key, art_flat, titles, d)
    pv = flat.copy()
    pv.thumbnail((1400, 1400 * 3), Image.LANCZOS)
    pv.save(out_stem + "_preview.png")
    return flat
