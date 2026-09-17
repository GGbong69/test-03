# -*- coding: utf-8 -*-
u"""보드 확장 와펜 열두 장의 밑그림 — 붓으로 짓고 assets/coin_src/mods.txt 에 낸다.

    python scripts/tools/mod_wappen.py            밑그림을 mods.txt 에 쓴다(손질이 덮인다)
    python scripts/tools/mod_wappen.py --print    쓰지 않고 찍기만 한다

동전 얼굴과 같은 길이다 — 붓(coin_paint)으로 밑그림을 지은 뒤 격자를 손으로
다듬는다. **mods.txt 가 원본이다.** 이 파일을 다시 돌리면 손질이 덮이므로,
손질은 여기 레시피에 점(dot)으로 옮겨 적은 뒤 돌린다.

── 틀(coin_paint.Wappen) ────────────────────────────────────
  방패 실루엣 · 실밥 테 3칸(윗·왼 +1, 아랫·오른 −1, 사선 땀) · 천(가운데 base,
  가장자리 base−1) · 엠블럼 중심 (17.5, 16) 반지름 ≤ 12 · 방패 끝은 빈 천.

── 열두 장 가르기 ──────────────────────────────────────────
  테 램프가 서로 안 겹친다. 천은 가운데/가장자리 단.
    핵심 red · red-1/0        테두리 teal · teal-1/0     천체 고리 violet · violet-1/0
    대기권 blue · night-1/0   라지 green · green-1/0     역지사지 pink · pink-1/0
    홀 dusk · cream-2/1       짝 cream · night-2/1       시계 gold · wood-1/0
    과녁 steel · steel-1/0    피자 wood · night-1/0      도넛 skin · night-2/1
  엠블럼의 명암 구조도 안 겹친다 — 어두운 공에 켜진 쐐기(핵심) · 밝은 쇠고리에
  검은 눈(테두리) · 대각 타원 고리(천체 고리) · 밝은 공과 번지는 후광(대기권) ·
  방패를 뚫는 손잡이(라지) · 위는 크고 아래는 작은 부채(역지사지) · 대각 검은
  점 셋(홀) · 네모 흰 점 넷(짝) · 흰 판에 세로 바늘(시계) · 오색 동심원(과녁) ·
  번갈아 도는 조각과 V 틈(피자) · 빨강·초록 고리에 검은 구멍(도넛).

── 효과 암시 ──────────────────────────────────────────────
  판에서 바뀌는 부분을 엠블럼의 가장 굵은 덩어리로 과장한다. 트리플 띠 →
  가운데 층, 더블 띠 → 바깥 테, 불 → 가운데 공과 후광, 칸 값 → 개수·바늘·크기.

레퍼런스는 구도·색·분위기만 봤다(docs/크레딧.md). 받아 둔 원본은 저장소에 없다.
"""
import io
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import coin_paint as P      # noqa: E402
from coin_paint import Wappen, col  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "coin_src", "mods.txt")
N = P.N
CX, CY = P.EMB

for _s in (sys.stdout, sys.stderr):
    try:
        _s.reconfigure(encoding="utf-8")
    except AttributeError:
        pass


#  ── 칸 모음 ─────────────────────────────────────────────
def _all():
    return [(x, y) for y in range(N) for x in range(N)]


def dist(x, y, cx=CX, cy=CY):
    return math.hypot(x - cx, y - cy)


def ang(x, y, cx=CX, cy=CY):
    u"""12시가 0°, 시계 방향으로 는다."""
    return math.degrees(math.atan2(x - cx, -(y - cy))) % 360.0


def disc(cx, cy, r):
    return [(x, y) for (x, y) in _all() if dist(x, y, cx, cy) <= r]


def ring(cx, cy, r0, r1):
    return [(x, y) for (x, y) in _all() if r0 < dist(x, y, cx, cy) <= r1]


def lit(x, y, cx=CX, cy=CY):
    u"""중심에서 본 이 칸의 방향이 빛(왼쪽 위)을 얼마나 보는가. −1~1."""
    dx, dy = x - cx, y - cy
    ln = math.hypot(dx, dy)
    if ln < 1e-6:
        return 0.0
    return (dx * P._L[0] + dy * P._L[1]) / ln


def seg(x0, y0, x1, y1, w):
    u"""굵기 w 짜리 곧은 획. 칸 가운데가 선분에서 w/2 안이면 칠한다."""
    out = []
    vx, vy = x1 - x0, y1 - y0
    l2 = vx * vx + vy * vy
    for (x, y) in _all():
        t = max(0.0, min(1.0, ((x - x0) * vx + (y - y0) * vy) / l2))
        if math.hypot(x - (x0 + vx * t), y - (y0 + vy * t)) <= w * 0.5:
            out.append((x, y))
    return out


def put(f, cells, ramp, step):
    u"""빛을 안 거치는 칠. 스스로 빛나거나 손으로 명암을 준 면."""
    for (x, y) in cells:
        f.dot(x, y, ramp, step)


#  ══════════════════════════════════════════════════════════
#  1. 핵심 — 트리플 띠 +0.06
#  물건: 쐐기 하나를 도려낸 뜨거운 행성 단면. 미션 패치에 수놓인 천체 하나.
#  트리플 띠는 판의 가운데 고리다 — 행성의 가운데 층(외핵)을 실제보다 확
#  두껍게 달군다. 배타 짝인 테두리는 바깥 쇠고리가 두꺼워 무게중심이 반대다.
#  NASA 의 지구 절개도(구에서 쐐기 하나를 도려내 속 층을 보인다) 구도,
#  USGS 의 「축척을 무시하고 속을 키운 그림」 관례, 껍질은 어둡고 속은 뜨거운
#  색(calacademy)으로 가는 명암 방향을 가져왔다.
def soks():
    f = Wappen("soks", u"핵심", rim="red", cloth="red", cloth_base=1)
    R = 11.0
    ball = disc(CX, CY, R)
    put(f, ball, "night", 1)
    #  왼위 초승달은 dusk-2 — 붉은 천과 공의 값을 가르는 쪽이다
    lo = set(disc(CX + 1.6, CY + 1.6, R))
    put(f, [p for p in ball if p not in lo], "dusk", 2)
    hi = set(disc(CX - 1.6, CY - 1.6, R))
    put(f, [p for p in ball if p not in hi], "night", 0)
    #  절개 — 12시~3시 사분면을 중심까지. 단면은 스스로 빛나 빛을 안 탄다
    for (x, y) in ball:
        if x < 18 or y > 16:
            continue
        d = dist(x, y)
        if d > 9.5:
            continue                        # 껍질은 그대로 — 얇은 검은 테
        if d > 8.0:
            f.dot(x, y, "red", 2)           # 맨틀
        elif d > 7.0:
            f.dot(x, y, "orange", 3)        # 외핵 바깥 한 칸
        elif d > 3.0:
            f.dot(x, y, "orange", 2)        # 외핵 — 가장 두꺼운 층
        else:
            f.dot(x, y, "gold", 3)          # 내핵
    for (x, y) in ((18, 15), (19, 15), (18, 16), (19, 16)):
        f.dot(x, y, "cream", 3)             # 한복판
    #  불티 둘 — 절개 모서리 바깥 천
    f.dot(29, 4, "orange", 3)
    f.dot(31, 7, "orange", 3)
    return f


#  ══════════════════════════════════════════════════════════
#  2. 테두리 — 트리플 띠 −0.06 · 더블 띠 +0.06
#  물건: 무거운 선창. 두꺼운 쇠 테에 볼트가 박혔고 가운데 유리는 작다.
#  바깥(더블)은 두껍게, 안쪽(트리플)은 가늘게 — 두꺼운 쇠 테와 눌린 개스킷이
#  그 비율이다. 선창(handwiki Porthole: 모래로 떠낸 두꺼운 금속 고리와 둘레를
#  조이는 dog 들) · 무거운 황동 선창(toplicht: 틀과 유리 사이 개스킷) ·
#  다트판 서라운드(dartscorner: 바깥 테가 판을 압도하는 무게감)를 봤다.
def guts():
    f = Wappen("guts", u"테두리", rim="teal", cloth="teal", cloth_base=1)
    f.cells(ring(CX, CY, 7.0, 12.0), "steel", 2)          # 베젤 — 가장자리가 빛을 탄다
    for k in range(6):
        a = math.radians(30 + 60 * k)
        bx = CX + 9.5 * math.sin(a)
        by = CY - 9.5 * math.cos(a)
        x0, y0 = int(round(bx - 1.0)), int(round(by - 1.0))
        for dx in (0, 1):
            for dy in (0, 1):
                f.dot(x0 + dx, y0 + dy, "steel", 3)
        f.dot(x0 + 1, y0 + 2, "steel", 0)                  # 볼트 그늘
        f.dot(x0 + 2, y0 + 1, "steel", 0)
    put(f, ring(CX, CY, 6.0, 7.0), "night", 2)             # 눌린 개스킷
    for (x, y) in disc(CX, CY, 6.0):
        f.dot(x, y, "night" if (x - CX) + (y - CY) > 0.5 else "blue",
              1 if (x - CX) + (y - CY) > 0.5 else 0)
    f.dot(14, 13, "cream", 3)                              # 유리 반짝임
    f.dot(15, 12, "cream", 3)
    f.dot(16, 11, "blue", 3)
    return f


#  ══════════════════════════════════════════════════════════
#  3. 천체 고리 — 안쪽에 트리플 띠 하나 더
#  물건: 고리가 행성에 바싹 붙어 두 줄로 도는 고리 행성.
#  행성(불) 바로 바깥에 띠가 하나 더 생긴다 — 행성에 붙은 안쪽 고리를 금색으로
#  따로 밝혀 「하나 더」를 세게 한다. 토성 고리(위키백과: 가장 밝은 B 고리,
#  그 바깥 어두운 카시니 간극) · NASA 「Gaps in the Darkness」(고리가 행성
#  몸에 드리우는 그림자) · 픽셀 토성 구도(고리가 뒤로 갔다 앞으로 나온다) ·
#  발라트로의 보라 행성 카드(판을 올리는 행성은 보라)를 봤다.
def arst():
    f = Wappen("arst", u"천체 고리", rim="violet", cloth="violet", cloth_base=1)
    for (x, y) in ((9, 9), (27, 23), (25, 5)):
        f.dot(x, y, "cream", 3)
    for (x, y) in ((8, 5), (7, 6), (8, 6), (9, 6), (8, 7)):
        f.dot(x, y, "gold", 3)
    f.dot(17, 31, "cream", 2)
    PR = 7.0
    planet = disc(CX, CY, PR)
    #  행성은 gold-2 한 덩어리에 오아래만 gold-1 로 가라앉힌다. 붓 빛으로
    #  왼위를 gold-3 로 올렸더니 금빛 안쪽 띠(gold-3)가 행성의 밝은 쪽과 한
    #  덩어리가 되어 고리가 행성에 녹았다(햄버거로 읽혔다). gold-1 로 통째로
    #  내렸더니 금빛 공이 아니라 갈색 공이 됐다.
    put(f, planet, "gold", 2)
    hi = set(disc(CX - 1.5, CY - 1.5, PR))
    put(f, [p for p in planet if p not in hi], "gold", 1)
    t = math.radians(-20.0)
    ux, uy = math.cos(t), math.sin(t)
    vx, vy = -uy, ux
    RX, RY = 12.5, 4.2
    K = RX / RY
    inp = set(planet)
    #  띠무늬 — 고리와 같은 기울기
    for (x, y) in planet:
        v = (x - CX) * vx + (y - CY) * vy
        if P._on_edge(inp, x, y):
            continue
        if abs(v + 3.5) < 0.5 or abs(v + 0.8) < 0.5:
            f.dot(x, y, "orange", 2)
    #  고리 — 띠 두께를 **화면 칸**으로 잰다. 타원 반지름(e)으로 재면 앞쪽
    #  (행성을 가로지르는 자리)에서 띠가 ry/rx 배로 얇아져 한 칸도 안 남았다.
    #  e 의 기울기로 나눠 화면 거리로 바꾸면 앞에서도 두 칸이 선다.
    E0 = 7.9
    front = set()
    for (x, y) in _all():
        dx, dy = x - CX, y - CY
        u = dx * ux + dy * uy
        v = dx * vx + dy * vy
        e = math.hypot(u, v * K)
        gl = math.hypot(u, v * K * K) / max(e, 1e-6)
        sd = (e - E0) / max(gl, 1e-6)
        if sd <= 0.0 or sd > 4.6:
            continue
        on_p = (x, y) in inp
        if on_p and v < 0:
            continue                         # 뒤로 가는 고리는 행성에 가린다
        if sd <= 1.7:
            f.dot(x, y, "gold", 3)           # 새로 생긴 안쪽 띠 — 제일 밝다
        elif sd <= 2.7:
            #  카시니 간극 — 행성 앞이면 그 틈으로 고리 그늘 진 행성이 비친다
            f.dot(x, y, "gold" if on_p else "violet", 1 if on_p else 0)
        else:
            f.dot(x, y, "cream", 2)
        if on_p:
            front.add((x, y))
    for (x, y) in planet:
        if (x, y) not in front and (x, y + 1) in front:
            f.dot(x, y, "gold", 0)           # 앞 고리가 행성에 드리운 그림자
    return f


#  ══════════════════════════════════════════════════════════
#  4. 대기권 — 불 0.20
#  물건: 대기가 두툼하게 빛나는 푸른 행성.
#  불은 판의 가운데 공이고 이 장은 아우터 불을 넓힌다 — 공은 그대로 두고
#  둘레의 빛 띠만 공만큼 두껍게 그린다. 판의 아우터 불이 초록이라 빛도 teal
#  쪽이다. NASA 「Thin Blue Line」(행성 가장자리에 붙은 가장 밝은 림) ·
#  대기광(오로라와 달리 가장자리를 고르게 감싸는 띠) · 대기 층 도해(바깥으로
#  갈수록 밝음→파랑→검정)를 봤다. 별은 안 넣는다 — 빛 번짐이 주인공이다.
def mung():
    f = Wappen("mung", u"대기권", rim="blue", cloth="night", cloth_base=1)
    for (x, y) in disc(CX, CY, 11.0):
        d = dist(x, y)
        k = lit(x, y)
        dark = 1 if k < -0.3 else 0
        if d <= 6.0:
            continue
        if d <= 7.0 or (d <= 8.0 and k > 0.3):
            f.dot(x, y, "teal", 3 - dark)
        elif d <= 8.5:
            f.dot(x, y, "teal", 2 - dark)
        else:
            f.dot(x, y, "teal", 1 - dark)
    ball = disc(CX, CY, 6.0)
    put(f, ball, "blue", 2)
    lo = set(disc(CX + 1.3, CY + 1.3, 6.0))
    hi = set(disc(CX - 1.3, CY - 1.3, 6.0))
    put(f, [p for p in ball if p not in hi], "blue", 1)
    put(f, [p for p in ball if p not in lo], "blue", 3)
    for x in range(14, 18):
        f.dot(x, 14, "blue", 3)             # 구름 줄 둘 — 어긋나게(「=」 로 안 읽힌다)
    for x in range(18, 22):
        f.dot(x, 17, "blue", 3)
    return f


#  ══════════════════════════════════════════════════════════
#  5. 라지 — 판이 1.10배로 커진다
#  물건: 다트판을 크게 비추는 손잡이 돋보기. 너무 커서 방패 틀을 뚫고 나온다.
#  판 크기를 바꾸는 유일한 장이 와펜 실루엣을 넘는 유일한 장이다. 렌즈 속은
#  미니 판이 아니라 칸 두 개와 호 하나 — 한 칸이 렌즈 절반을 먹어야 「확대」로
#  읽힌다. 돋보기(위키백과: 아이콘으로 줄이면 원 + 손잡이만 남는다) · 황동
#  돋보기(렌즈보다 긴 손잡이와 이음매 고리) · 3피트 거대 다트판(칸 하나하나가
#  눈에 띄게 크다)을 봤다.
LC = (16.0, 15.0)
HANDLE = seg(24.8, 23.8, 33.6, 33.6, 3.2)


def panb():
    extra = [p for p in HANDLE if p not in P.SHIELD]
    f = Wappen("panb", u"라지", rim="green", cloth="green", cloth_base=1, extra=extra)
    lx, ly = LC
    #  손잡이 — 윗변(오른위를 보는 변)이 밝다
    nx, ny = math.sqrt(0.5), -math.sqrt(0.5)
    for (x, y) in HANDLE:
        o = (x - 24.8) * nx + (y - 23.8) * ny
        along = ((x - 24.8) + (y - 23.8)) * math.sqrt(0.5)
        if along < 2.2:
            f.dot(x, y, "gold", 2)          # 이음매 고리
        else:
            f.dot(x, y, "wood", 3 if o > 0.6 else (1 if o < -0.6 else 2))
    #  렌즈 속 — 확대된 판 조각
    for (x, y) in disc(lx, ly, 10.5):
        right = x >= 16
        a = math.hypot(x - lx, y - 44.0)
        if 22.0 <= a <= 25.0:
            f.dot(x, y, "green" if right else "red", 2)
        else:
            f.dot(x, y, "night" if right else "cream", 2)
    f.dot(9, 10, "cream", 3)                # 유리 반짝임
    f.dot(10, 9, "cream", 3)
    f.dot(11, 8, "cream", 3)
    #  틀 — 테를 덮고 올라앉는다
    for (x, y) in ring(lx, ly, 10.5, 12.5):
        k = lit(x, y, lx, ly)
        f.dot(x, y, "wood", 3 if k > 0.35 else (1 if k < -0.35 else 2))
    return f


#  ══════════════════════════════════════════════════════════
#  6. 역지사지 — 가장 작은 3 칸이 20이 된다
#  물건: 가운데 축을 두고 아래의 작고 어두운 부채 셋이 위의 크고 금빛인 부채
#  셋으로 올라가는 그림. 양옆에 위로 가는 화살.
#  판에서 3 은 20 의 정반대인 맨 아래다(위키백과 Darts 의 숫자 차례). 易地 —
#  자리를 서로 바꾼다(한국경제 생글생글). 원형 화살(새로고침 · 리롤 기호로
#  읽힌다)은 뺐다 — 작은 그림은 특징 하나만 남긴다(slynyrd Pixelblog 47).
def pang():
    f = Wappen("pang", u"역지사지", rim="pink", cloth="pink", cloth_base=1)
    #  축을 한 칸 내려(y 18) 위 부채를 길게, 폭은 ±33°. 가운데 쐐기를 가장
    #  밝게(gold-3) 둔다 — 20 은 그 한가운데다.
    ax, ay = 17.5, 18.0
    for (x, y) in _all():
        d = dist(x, y, ax, ay)
        a = ang(x, y, ax, ay)
        s = (a + 180.0) % 360.0 - 180.0      # 12시 기준 −180~180
        if 1.5 <= d <= 13.5 and -33.0 <= s < 33.0:
            f.dot(x, y, "gold", 3 if -11.0 <= s < 11.0 else 2)
        b = (a % 360.0) - 180.0              # 6시 기준
        if 1.5 <= d <= 7.0 and -33.0 <= b < 33.0:
            f.dot(x, y, "night", 0 if -11.0 <= b < 11.0 else 1)
    for (x, y) in ((17, 17), (18, 17), (17, 18), (18, 18)):
        f.dot(x, y, "cream", 3)
    #  화살 — 샤프트 2px 에 머리 세 줄(2 · 4 · 6). 머리를 한 줄(4px)로 두었더니
    #  26px 에서 화살이 아니라 T 자 기둥 둘로 읽혔고, 기둥이 부채보다 먼저 보였다.
    for x0 in (6, 28):
        for y in range(15, 23):
            f.dot(x0, y, "cream", 3)
            f.dot(x0 + 1, y, "cream", 3)
        for r in range(3):
            for x in range(x0 - r, x0 + 2 + r):
                f.dot(x, 12 + r, "cream", 3)
    return f


#  ══════════════════════════════════════════════════════════
#  7. 홀 — 칸마다 짝이 생긴다 · 짝수 칸 −1
#  물건: 밝은 천 위의 검은 바둑돌 셋, 대각으로 선다.
#  돌가리기에서 흑돌 하나는 홀, 둘은 짝이다(polgote) — 홀은 흑돌. 아이들
#  홀짝 놀이는 손에 쥔 알 개수를 맞힌다(브런치). 흑돌 가장자리의 푸르스름한
#  빛(ymimports)은 회보라 night-3 하이라이트로, 양볼록 돌의 볼록에 모이는 빛
#  (gafferongames)은 돌마다 왼위 점 하나로. 테는 dusk — night 테는 게임
#  바탕에 실루엣이 묻힌다.
def holl():
    f = Wappen("holl", u"홀", rim="dusk", cloth="cream", cloth_base=2)
    #  돌은 반지름 4.2 — 서로 한 칸 남짓 떨어질 만큼 크다. 3.5 로 두었더니
    #  밝은 네모 천 위의 작은 검은 점 셋이 **주사위 3** 으로 읽혔다. 주사위는
    #  동전이 걷어낸 노름 기호라, 점이 아니라 돌이 되게 키우고 윤을 낸다.
    stones = ((24.5, 8.5), (17.5, 15.5), (10.5, 22.5))
    #  그림자와 돌을 둘 다 **물건**으로 쌓는다. 점(dot)은 늘 물건 위라
    #  그림자를 점으로 찍으면 돌을 덮는다.
    for (sx, sy) in stones:
        f.cells(disc(sx + 1.0, sy + 1.0, 4.2), "cream", 1, shade=False)
    for (sx, sy) in stones:
        f.cells(disc(sx, sy, 4.2), "night", 1)
        f.dot(int(sx - 2.0), int(sy - 1.5), "night", 3)
        f.dot(int(sx - 1.0), int(sy - 2.5), "night", 3)
        f.dot(int(sx - 1.0), int(sy - 1.5), "dusk", 2)
    return f


#  ══════════════════════════════════════════════════════════
#  8. 짝 — 칸마다 짝이 생긴다 · 홀수 칸 +1
#  물건: 어두운 슬레이트 천 위의 흰 바둑돌 넷, 두 쌍으로 네모지게.
#  홀의 거울 — 천 명암 · 돌 색 · 개수(셋 대 넷)가 전부 뒤집힌다. 흰 돌을
#  둘씩 짝지어 센다(polgote), 조개 흰 돌 윗면의 가는 결(ymimports), 둥근
#  볼록면의 반달 음영(gafferongames).
def jjak():
    f = Wappen("jjak", u"짝", rim="cream", cloth="night", cloth_base=2)
    #  홀과 같은 까닭으로 돌을 키웠다 — 네모로 떨어진 작은 흰 점 넷은 주사위 4 다.
    stones = ((12.5, 10.5), (22.5, 10.5), (12.5, 20.5), (22.5, 20.5))
    for (sx, sy) in stones:
        put(f, disc(sx + 1.0, sy + 1.0, 4.0), "night", 0)
    for (sx, sy) in stones:
        st = disc(sx, sy, 4.0)
        put(f, st, "cream", 3)
        hi = set(disc(sx - 1.2, sy - 1.2, 4.0))
        put(f, [p for p in st if p not in hi], "cream", 2)
        for x in range(int(sx - 2.5), int(sx + 1.5)):
            f.dot(x, int(sy - 1.5), "steel", 3)
    return f


#  ══════════════════════════════════════════════════════════
#  9. 시계 — 모든 칸 값이 12 가 된다
#  물건: 놋쇠 벽시계, 두 바늘이 12 에 겹쳐 곧게 선다.
#  바늘은 전부 12 를, 눈금도 열둘이다. 판 테마(CLOCKART)의 놋쇠 링 · 빨간
#  초침과 같은 재질이다. 시계 문자판(위키백과 Clock face: 시침은 짧고 굵고
#  분침은 길고 가늘다) · 스위스 철도 시계(지시봉 모양 빨간 초침) · 샌드블라스트
#  놋쇠의 무광(toplicht)을 봤다 — 베젤은 번쩍이는 금이 아니라 gold-1.
def clok():
    f = Wappen("clok", u"시계", rim="gold", cloth="wood", cloth_base=1)
    for (x, y) in ring(CX, CY, 10.0, 12.0):
        k = lit(x, y)
        f.dot(x, y, "gold", 2 if k > 0.35 else (0 if k < -0.35 else 1))
    for (x, y) in disc(CX, CY, 10.0):
        f.dot(x, y, "cream", 2 if dist(x, y) > 8.4 else 3)
    for h in range(12):
        a = math.radians(30 * h)
        sx, sy = math.sin(a), -math.cos(a)
        if h == 0:
            continue
        rs = (8.0, 9.0) if h % 3 == 0 else (8.5,)
        for r in rs:
            f.dot(int(math.floor(CX + r * sx)), int(math.floor(CY + r * sy)), "wood", 1)
    for x in (17, 18):
        for y in (7, 8, 9):
            f.dot(x, y, "night", 0)         # 12 — 가장 굵다
    for x in (17, 18):
        for y in range(11, 17):
            f.dot(x, y, "night", 0)         # 시침
    for y in range(8, 11):
        f.dot(17, y, "night", 0)            # 분침(가늘고 길다)
    a = math.radians(120.0)
    f.line(18, 16, int(round(CX + 8.0 * math.sin(a))), int(round(CY - 8.0 * math.cos(a))),
           "red", 2)                        # 초침
    f.dot(16, 15, "red", 2)
    f.dot(15, 15, "red", 2)
    for (x, y) in ((17, 15), (18, 15), (17, 16), (18, 16)):
        f.dot(x, y, "gold", 2)              # 축
    return f


#  ══════════════════════════════════════════════════════════
#  10. 과녁 — 모든 칸 값 10 · 불 배수 5
#  물건: 양궁 과녁면. 다섯 색 동심원이고 가운데 금이 규정보다 크고 반짝인다.
#  모든 칸 값 10 은 양궁 최고점 10 이다. 과녁 색 순서(archerygeekery: 흰 ·
#  검정 · 하늘 00B4E4 · 빨강 F65058 · 금 FFE552, 링 폭이 같다)와 점수 구조
#  (World Archery: 금 10·9)를 가져왔다. 같은 색 안의 가는 검은 점수선은
#  외곽선 규칙에 따라 뺐다. 화살은 안 꽂는다 — 다트와 섞인다.
def aimb():
    f = Wappen("aimb", u"과녁", rim="steel", cloth="steel", cloth_base=1)
    f.cells(disc(CX, CY, 12.0), "cream", 3)
    f.cells(disc(CX, CY, 10.0), "night", 1, shade=False)
    f.cells(disc(CX, CY, 8.0), "blue", 3, shade=False)
    f.cells(disc(CX, CY, 6.0), "red", 2, shade=False)
    f.cells(disc(CX, CY, 4.0), "gold", 2)
    f.dot(17, 16, "gold", 1)                # X 링 핀홀
    for (x, y) in ((12, 11), (11, 12), (12, 12), (13, 12), (12, 13)):
        f.dot(x, y, "cream", 3)             # 반짝임
    return f


#  ══════════════════════════════════════════════════════════
#  11. 피자 — 모든 칸 값 32 · 더블·트리플 띠가 사라진다
#  물건: 여덟 조각 피자, 아래 조각 하나가 살짝 빠져나와 있다.
#  띠 없이 똑같은 조각 여덟 개 — 판 테마(PIZZAART, shots/btheme_pizz.png)의
#  크러스트 테 · 소스 선 · 번갈아 도는 크림/어두운 조각 · 페퍼로니 · 바질 ·
#  초록 불과 재료가 같다(PAL 최근접: crust wood-3 · sauce red-2 · pep red-1).
#  크러스트의 탄 물집(housegardenhobby cornicione) · 가장자리가 말려 그을린
#  페퍼로니(위키백과 Pepperoni) · 음식끼리 색 돌려쓰기(slynyrd Pixelblog 30)를
#  봤다. 올리브는 26px 에서 뭉개져 뺐다.
def pizz():
    f = Wappen("pizz", u"피자", rim="wood", cloth="night", cloth_base=1)
    pix = {}
    for (x, y) in disc(CX, CY, 12.0):
        d = dist(x, y)
        a = ang(x, y)
        if d > 9.9:
            k = lit(x, y)
            pix[(x, y)] = col("wood", 2 if k < -0.5 and d > 11.0 else 3)
        elif d > 9.0:
            pix[(x, y)] = col("red", 2)
        else:
            sl = int(((a + 22.5) % 360.0) // 45.0)
            #  어두운 조각은 wood **2** 다. 판 테마의 치즈 틴트 먹은 칸(wood-1)을
            #  그대로 썼더니 크림 조각 넷만 떠서 피자가 아니라 **십자**로 읽혔다
            #  (페퍼로니가 크림 조각에만 앉아 더 그랬다). 한 단 올려 조각이
            #  번갈아 도는 것은 남기고 십자를 깬다.
            pix[(x, y)] = col("cream", 2) if sl % 2 == 0 else col("wood", 2)
    for (x, y) in ((8, 11), (14, 5)):
        pix[(x, y)] = col("orange", 3)      # 부푼 크러스트
    for (x, y) in ((29, 13), (26, 25)):
        pix[(x, y)] = col("wood", 1)        # 탄 물집

    def pep(px, py):
        u"""페퍼로니 3x3 — 왼위 한 칸이 밝고 오아래 한 칸이 그을렸다."""
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                s_ = 2 if (dx, dy) == (-1, -1) else (0 if dx + dy >= 2 else 1)
                pix[(px + dx, py + dy)] = col("red", s_)

    #  페퍼로니는 여덟 조각 전부에 — 크림 조각은 바깥(r 6), 어두운 조각은
    #  안쪽(r 5)으로 엇갈려 앉혀 한 줄 고리로 안 읽히게 한다
    for k in range(8):
        a = math.radians(45 * k)
        rr = 6.0 if k % 2 == 0 else 5.0
        pep(int(round(CX + rr * math.sin(a) - 0.5)), int(round(CY - rr * math.cos(a) - 0.5)))
    for a0 in (45, 225):
        a = math.radians(a0)
        bx = int(round(CX + 7.8 * math.sin(a) - 0.5))
        by = int(round(CY - 7.8 * math.cos(a)))
        pix[(bx, by)] = col("green", 2)     # 바질
        pix[(bx + 1, by)] = col("green", 2)
    for (x, y) in disc(CX, CY, 2.5):
        pix[(x, y)] = col("green", 2)
    pix[(17, 16)] = col("red", 2)
    #  빠진 조각 — 6시 크림 조각을 아래로 민다. 두 칼선에 V 틈이 난다
    moved = {}
    gap = []
    for (x, y), c in list(pix.items()):
        d = dist(x, y)
        a = ang(x, y)
        if 157.5 <= a < 202.5 and d > 2.5:
            moved[(x, y + 1)] = c
            gap.append((x, y))
    for p in gap:
        pix[p] = col("wood", 0)
    pix.update(moved)
    for (x, y), c in pix.items():
        f.dots[(x, y)] = c
    return f


#  ══════════════════════════════════════════════════════════
#  12. 도넛 — 불이 사라진다 · 칸 값 올림
#  물건: 빨강·초록 물결 글레이즈를 얹은 도넛, 가운데 구멍이 크고 새까맣다.
#  판의 한복판이 뻥 뚫렸고 그것이 가장 큰 명암 덩어리다. 칸 값 올림은 달게
#  얹힌 글레이즈와 스프링클로 말한다. 판 테마(DONUTART, shots/btheme_dnut.png)의
#  반죽 · 더블 링 자리의 빨강·초록 글레이즈 · 스프링클 · 검은 구멍과 재료가
#  같다(dough skin-2 · dough_dk wood-2 · hole night-0). 스프링클(위키백과:
#  지미는 가느다란 막대) · 링 도넛(윗면만 글레이즈가 덮고 가운데가 뚫렸다)을 봤다.
def dnut():
    f = Wappen("dnut", u"도넛", rim="skin", cloth="night", cloth_base=2)
    wave = [0, 1, 0, 0, 0, 1, 0, -1, 0, 1, 0, 0, 0, 1, 0, -1]
    for (x, y) in disc(CX, CY, 12.0):
        d = dist(x, y)
        a = ang(x, y)
        k = lit(x, y)
        wv = wave[int(a // 22.5) % 16]
        mid = (a % 45.0) - 22.5
        lim = 9.0 + 0.7 * wv + (1.5 if abs(mid) < 4.0 else 0.0)
        if d > lim:
            f.dot(x, y, "skin" if k > -0.35 else "wood",
                  3 if k > 0.35 else 2)
        elif d > 5.5:
            red = int(a // 45.0) % 2 == 0
            f.dot(x, y, "red" if red else "green", 2)
        elif d > 4.5:
            f.dot(x, y, "skin", 2)
        else:
            f.dot(x, y, "night", 0)
    #  스프링클 — 1x2 막대. 빨강 호 위에는 빨강 계열을 안 놓는다
    bars = ((12, 8, 13, 8), (23, 9, 23, 10), (24, 18, 25, 19),
            (13, 22, 14, 22), (9, 15, 9, 16), (19, 23, 20, 23))
    hues = (("cream", 3), ("gold", 2), ("blue", 3), ("pink", 3))
    for i, (x0, y0, x1, y1) in enumerate(bars):
        red = int(ang(x0, y0) // 45.0) % 2 == 0
        ramp, st = hues[i % 4]
        if red and ramp == "pink":
            ramp, st = "blue", 3
        f.dot(x0, y0, ramp, st)
        f.dot(x1, y1, ramp, st)
    for (x, y) in disc(CX, CY, 4.5):
        if dist(x + 1, y + 1) > 4.5:
            f.dot(x, y, "skin", 3)          # 빛 받는 안쪽 벽
    return f


CARDS = [soks, guts, arst, mung, panb, pang, holl, jjak, clok, aimb, pizz, dnut]

HEAD = u"""#  보드 확장 와펜 — 도트 격자. 글 하나가 도트 하나다.
#
#  == <id>  <이름>  [테 <램프>]   새 장이 시작된다. 테 램프는 누운 자세의
#                                  옆면(base−1 · 땀 base−2)을 굽는 데 쓴다
#  = <글> <색>                    팔레트 한 줄(coin_paint.PAL 안에서)
#  그 뒤 서른여섯 줄              그림. 마침표는 방패 밖이다(알파 0)
#
#  동전 얼굴(faces.txt)과 같은 격자 · 같은 팔레트 · 같은 빛 · 외곽선 없음.
#  다른 것은 틀뿐이다 — 방패 실루엣과 실밥 테(coin_paint.Wappen).
#  밑그림은 scripts/tools/mod_wappen.py 가 짓는다. 굽기는 make_coin_art.py,
#  크게 보기는 scripts/tools/mod_try.py.
#  레퍼런스는 구도와 색의 분위기만 봤다. 받아 둔 원본은 저장소에 없다.

"""


def main():
    txt = HEAD + "\n".join(c().text() for c in CARDS)
    if "--print" in sys.argv:
        print(txt)
        return 0
    with io.open(OUT, "w", encoding="utf-8", newline="\n") as fp:
        fp.write(txt)
    print(u"와펜 %d장 → %s" % (len(CARDS), os.path.relpath(OUT, ROOT)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
