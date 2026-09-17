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
    홀 dusk · wood-3/2        짝 cream · night-2/1       시계 gold · wood-1/0
    과녁 steel · steel-1/0    피자 wood · night-1/0      도넛 skin · night-2/1
  엠블럼의 명암 구조도 안 겹친다 — 어두운 공 속에서 빛나는 둥근 핵(핵심) · 밝은
  쇠고리에 검은 눈(테두리) · 대각 타원 고리(천체 고리) · 밝은 공과 번지는
  후광(대기권) · 방패를 뚫는 손잡이(라지) · 금 화살과 어두운 화살 ⇅(역지사지) ·
  밝은 천에 쌓인 흑돌 사다리꼴(홀) · 어두운 천에 쌓인 흰 돌 피라미드(짝) · 흰 판에
  세로 바늘(시계) · 오색 동심원(과녁) · 유일한 삼각 한 조각(피자) · 분홍 고리에
  검은 구멍(도넛).

── 두 번째 눈(2026-09-17 검토) ──────────────────────────────
  만든 사람이 아닌 눈으로 게임 크기(컬렉션 26px · 명판 18px)에서 다시 봤다.
  여섯 장이 뜻과 다른 것으로 읽혀 고쳤다 — 핵심 원그래프 · 역지사지 금
  트로피 · 홀 주사위 3 · 짝 주사위 4 · 피자 십자와 꽃 · 도넛 크리스마스 리스.
  **주사위와 트럼프 무늬(♣)는 동전이 걷어낸 노름 기호**라 가장 먼저 걷었다.
  장마다 무엇이 무엇으로 읽혔고 무엇으로 갈랐는지는 그 장의 「두 번째 눈」에.
  나머지 여섯(테두리 · 천체 고리 · 대기권 · 라지 · 시계 · 과녁)은 그대로다.

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
#  물건: 쐐기를 도려낸 행성 속에서 **둥근 핵이 빛난다.**
#  트리플 띠는 판의 가운데 고리다 — 행성의 가운데 층(외핵)을 실제보다 확
#  두껍게 달군다. 배타 짝인 테두리는 바깥 쇠고리가 두꺼워 무게중심이 반대다.
#  NASA 의 지구 절개도(구에서 쐐기 하나를 도려내 속 층을 보인다) 구도,
#  USGS 의 「축척을 무시하고 속을 키운 그림」 관례, 껍질은 어둡고 속은 뜨거운
#  색(calacademy)으로 가는 명암 방향을 가져왔다.
#
#  ── 두 번째 눈(2026-09-17 검토) ──
#  첫 판은 12~3시 사분면을 평평한 층 무늬로 채웠는데, 26px 에서 **원그래프**
#  (어두운 원에 주황 4분의 1)로 읽혔다. 원그래프와 가르는 것은 셋이다 —
#    ① 핵을 쐐기 안에 가두지 않고 **온 원**으로 한복판에 둔다(원그래프 한복판에는
#       공이 없다). gold-3 가 공 전체에서 가장 밝은 칸이다 — 이름이 「핵심」이다
#    ② 쐐기를 사분면보다 넓게(−8°~108°) 벌려 칼선이 수직 · 수평에 안 붙는다
#    ③ 두 절단면의 값을 한 단 가른다 — 빛 쪽(왼) 면은 orange-3 · red-3, 먼 면은
#       orange-2 · red-2. 평면 둘이 접힌 입체로 읽힌다
#  NASA Cut-away Diagram of Earth's Interior 는 속 공(내핵)이 가장 밝고 둥글게
#  남는 구도를, 절개도 검색 요약(「glowing heat」)에서는 핵만 스스로 빛나고
#  껍질은 어둡게 남는 관례를 봤다. 공의 왼위 초승달은 dusk-2 로 남긴다 — 붉은 천과
#  어두운 공의 값을 가르는 쪽이다.
def soks():
    f = Wappen("soks", u"핵심", rim="red", cloth="red", cloth_base=1)
    R = 11.0
    ball = disc(CX, CY, R)
    put(f, ball, "night", 2)
    hi = set(disc(CX - 1.4, CY - 1.4, R))
    put(f, [p for p in ball if p not in hi], "night", 1)
    lo = set(disc(CX + 1.8, CY + 1.8, R))
    put(f, [p for p in ball if p not in lo], "dusk", 2)
    A0, A1, FOLD = -8.0, 108.0, 50.0
    for (x, y) in ball:
        d = dist(x, y)
        s = (ang(x, y) + 180.0) % 360.0 - 180.0
        if not (A0 <= s <= A1) or d > 9.6:
            continue                        # 껍질(r 9.6 밖)은 그대로 — 얇은 검은 테
        far = s > FOLD                      # 오른아래 절단면은 빛을 덜 받는다
        if d > 8.2:
            f.dot(x, y, "red", 2 if far else 3)        # 맨틀
        elif d > 3.8:
            f.dot(x, y, "orange", 2 if far else 3)     # 외핵 — 가장 두꺼운 층
    for (x, y) in disc(CX, CY, 3.8):
        #  내핵 — 온 원. 왼위가 한 단 더 밝다
        f.dot(x, y, "gold", 3 if dist(x, y, CX - 0.8, CY - 0.8) < 2.4 else 2)
    for (x, y) in ((17, 15), (18, 15), (17, 16)):
        f.dot(x, y, "cream", 3)             # 한복판
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
#  물건: 나란히 선 두 화살 ⇅ — 위로 오르는 굵은 금 화살과 내려가는 어두운 화살.
#  易地 — 자리를 서로 바꾼다(한국경제 생글생글). 바닥의 작은 칸이 판 꼭대기
#  값(20)으로 올라가니, 오르는 쪽을 금빛에 굵고 길게, 내려가는 쪽을 dusk 에
#  짧게 둔다.
#
#  ── 두 번째 눈(2026-09-17 검토) ──
#  첫 판은 가운데 축에 아래 작은 검은 부채와 위 큰 금 부채를 맞대고 양옆에 위
#  화살을 세웠다. 크게 보면 뜻이 서는데, 26px 에서는 **금 트로피**(잔 · 받침 ·
#  양옆 손잡이)나 모래시계로 읽혔다 — 두 부채가 한 점에서 맞닿으면 잔 모양이
#  된다. 부채를 버리고 교환 기호 하나만 남긴다. 원형 화살은 계속 뺀다(리롤 ·
#  새로고침으로 읽힌다). 작은 그림은 특징 하나만(slynyrd Pixelblog 47), 자수
#  패치는 작을수록 굵은 한 덩어리로(americanpatch 디자인 글: 작은 패치는 잔
#  무늬를 버리고 주 이미지에 집중하고, 보색 대비가 또렷하다 — 분홍 천에 금).
def pang():
    f = Wappen("pang", u"역지사지", rim="pink", cloth="pink", cloth_base=1)
    #  오르는 화살 — 자루 4칸(x 10~13, y 11~27) · 머리 y 4~11 에서 넓어진다
    up = [(x, y) for (x, y) in _all() if 10 <= x <= 13 and 11 <= y <= 27]
    up += [(x, y) for (x, y) in _all()
           if 4 <= y <= 11 and abs(x + 0.5 - 12.0) <= (y - 3.5) * 0.85]
    f.cells(up, "gold", 2)
    #  내려가는 화살 — 한 칸 낮게 시작해 머리가 방패 끝 쪽(y 27)을 가리킨다
    dn = [(x, y) for (x, y) in _all() if 22 <= x <= 25 and 5 <= y <= 20]
    dn += [(x, y) for (x, y) in _all()
           if 20 <= y <= 27 and abs(x + 0.5 - 24.0) <= (27.5 - y) * 0.85]
    f.cells(dn, "dusk", 1)
    return f


#  ══════════════════════════════════════════════════════════
#  7. 홀 — 칸마다 짝이 생긴다 · 짝수 칸 −1
#  물건: 바둑판 빛 천 위에 쌓인 흑돌 다섯 — 아래 셋, 위 둘.
#  돌가리기에서 한 사람이 흰 돌을 한 줌 쥐고, 다른 사람이 흑돌 하나(홀) ·
#  둘(짝)을 올려 맞힌다(polgote · gomagic Nigiri) — 홀 · 짝은 흑과 백의 일이다.
#  돌은 두 구가 겹친 볼록 렌즈 꼴이라 빛이 한 점에 모인다(gafferongames Shape
#  of the Go Stone) — 돌마다 왼위에 반짝임 하나. 흑돌 가장자리의 푸르스름한
#  빛(ymimports)은 dusk 로.
#
#  ── 두 번째 눈(2026-09-17 검토) ──
#  첫 판은 크림 천에 떨어진 검은 돌 셋을 대각으로 놓았다. 돌을 키워도 26px 에서
#  흰 네모에 검은 점 셋 — **주사위 3** 이었다. 주사위는 동전이 걷어낸 노름
#  기호다. 가르는 것은 둘이다 —
#    ① 천을 크림에서 바둑판 빛(wood-3, 가장자리 wood-2)으로. 흰 바탕이 아니면
#       주사위 면이 안 된다
#    ② 돌을 **떨어뜨려 늘어놓지 않고 맞닿게 쌓는다.** 주사위 눈은 서로 안 닿는다
#  셋을 삼각으로 쌓으면 이번에는 **트럼프 클럽(♣)** 이 된다(원 셋이 삼각으로
#  맞닿은 꼴이 곧 클럽이다) — 이것도 노름 기호라, 다섯(아래 셋 · 위 둘)으로
#  쌓아 사다리꼴 무더기로 둔다. 다섯은 홀이고, 짝(여섯)의 꼭대기 한 알이 빠진
#  꼴이라 두 장이 한 쌍으로 읽힌다.
STONE_HI = 0.25     # 반짝임 반지름 — 돌 반지름의 배수


def stone(f, sx, sy, r, ramp, base, glint, spark):
    u"""바둑돌 하나. 몸은 빛을 타는 물건(가장자리 ±1), 반짝임은 왼위 한 덩어리 +
    가장 밝은 한 칸. glint · spark 는 (램프, 단)."""
    f.cells(disc(sx, sy, r), ramp, base)
    for (x, y) in disc(sx - r * 0.4, sy - r * 0.4, r * STONE_HI):
        f.dot(x, y, glint[0], glint[1])
    f.dot(int(math.floor(sx - r * 0.55)), int(math.floor(sy - r * 0.55)), spark[0], spark[1])


def pile(f, stones, r, ramp, base, glint, spark, shadow):
    u"""맞닿게 쌓은 돌 무더기. 그림자는 오른아래로 한 칸씩 민 한 덩어리다 —
    돌마다 그림자를 따로 찍으면 돌 사이 틈이 얼룩진다."""
    sh = set()
    for (sx, sy) in stones:
        sh |= set(disc(sx + 1.0, sy + 1.0, r))
    f.cells(sh, shadow[0], shadow[1], shade=False)
    for (sx, sy) in stones:
        stone(f, sx, sy, r, ramp, base, glint, spark)


def holl():
    f = Wappen("holl", u"홀", rim="dusk", cloth="wood", cloth_base=3)
    R = 3.8
    stones = ((13.5, 13.0), (21.5, 13.0),                 # 위 둘
              (9.5, 20.0), (17.5, 20.0), (25.5, 20.0))    # 아래 셋
    pile(f, stones, R, "night", 1, ("dusk", 1), ("dusk", 3), ("wood", 2))
    return f


#  ══════════════════════════════════════════════════════════
#  8. 짝 — 칸마다 짝이 생긴다 · 홀수 칸 +1
#  물건: 어두운 천 위에 피라미드로 쌓인 흰 돌 여섯 — 아래 셋 · 가운데 둘 · 위 하나.
#  홀의 거울 — 천 명암 · 돌 색이 뒤집히고, 홀 무더기에 꼭대기 한 알을 얹어
#  여섯(짝)이 된다. 흰 돌은 조개로 깎아 윗면이 곱게 희다(ymimports 바둑돌 안내).
#
#  ── 두 번째 눈(2026-09-17 검토) ──
#  첫 판의 네모로 떨어진 흰 돌 넷은 26px 에서 **주사위 4** 였다. 넷을 벽돌처럼
#  엇갈려 붙이면 발자국 · 구름, 둘만 두면 땅콩 · 두 눈으로 읽혔다. 맞닿게 쌓은
#  피라미드가 주사위 · 트럼프 어느 쪽도 아니고, 홀과 한 벌로 가장 또렷했다.
def jjak():
    f = Wappen("jjak", u"짝", rim="cream", cloth="night", cloth_base=2)
    R = 3.5
    stones = ((17.5, 7.0),
              (13.5, 13.5), (21.5, 13.5),
              (9.5, 20.0), (17.5, 20.0), (25.5, 20.0))
    pile(f, stones, R, "cream", 2, ("cream", 3), ("cream", 3), ("night", 0))
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
#  물건: 끝이 방패 끝을 가리키는 피자 **한 조각.**
#  띠가 사라진 판은 칸이 곧 조각이다 — 다트판의 한 칸(부채꼴)을 피자 한 조각으로
#  그린다. 재료는 판 테마(PIZZAART, shots/btheme_pizz.png)와 같다 — 크러스트
#  wood-3(c98a45) · 크러스트 빛 orange-3(ecb86e) · 페퍼로니 red-1/2(a8322a ·
#  d0604f) · 바질 green-2(3f8a3a) · 녹은 치즈 gold-3 · cream-3. 크러스트의 탄
#  물집(housegardenhobby cornicione) · 음식끼리 색 돌려쓰기(slynyrd Pixelblog 30).
#
#  ── 두 번째 눈(2026-09-17 검토) ──
#  첫 판은 판 테마를 그대로 옮겨 여덟 조각이 번갈아 도는 온 피자였다. 26px 에서
#  크림 조각 넷이 **십자**, 페퍼로니 고리가 **꽃**으로 읽혔고(3x3 페퍼로니는
#  「+」 모양이었다), 조각 하나 빠진 V 틈은 한 칸이라 사라졌다. 게다가 온 피자는
#  동전 「위대한 피자」(c04)의 얼굴과 같은 꼴이다. 한 조각은 —
#    · 열두 장 중 원이 아홉인 판에서 유일한 **삼각** 실루엣이다
#    · 페퍼로니 셋이 둥근 4x4 로 커도 자리가 남는다
#    · 동전 피자(온 원)와 틀 밖에서도 갈린다
#  작은 도트 피자 조각은 치즈 삼각 + 윗변 크러스트 + 둥근 페퍼로니 셋이 기본
#  구도다(megavoxels How to Make a Pixel Art Pizza — 32x32, 페퍼로니 원 셋).
#  그 강의의 검은 외곽선은 규칙 ③ 에 따라 안 쓰고, 치즈 왼변을 한 단 밝게 ·
#  오른변을 한 단 어둡게 가른다.
def pizz():
    f = Wappen("pizz", u"피자", rim="wood", cloth="night", cloth_base=1)
    ax, ay = 17.5, 29.5          # 조각 끝 — 방패 끝 쪽
    HA = 25.0                    # 반각
    L = 24.5                     # 끝에서 크러스트 바깥까지
    pix = {}
    for (x, y) in _all():
        dx, dy = x - ax, y - ay
        d = math.hypot(dx, dy)
        s = math.degrees(math.atan2(dx, -dy))
        if d < 0.5 or d > L or abs(s) > HA:
            continue
        if d > L - 3.4:
            #  크러스트 — 윗면 왼쪽이 빛, 오른끝과 치즈에 닿는 안쪽 줄이 그늘
            if d > L - 1.3 and s < 8.0:
                c = col("orange", 3)
            elif s > 14.0 or d < L - 2.6:
                c = col("wood", 2)
            else:
                c = col("wood", 3)
        elif s < -HA + 4.5:
            c = col("cream", 3)          # 빛 받는 왼변
        elif s > HA - 4.5:
            c = col("gold", 2)           # 그늘진 오른변
        else:
            c = col("gold", 3)
        pix[(x, y)] = c

    def pep(cx, cy):
        u"""페퍼로니 — 반지름 2.1 원(4x4 에 모서리가 깎인다). 왼위 칸들이 한 단 밝다."""
        for (x, y) in disc(cx, cy, 2.1):
            if (x, y) in pix:
                pix[(x, y)] = col("red", 2 if (x - cx) + (y - cy) < -1.2 else 1)
    pep(14.0, 12.5)
    pep(21.5, 13.5)
    pep(17.5, 20.5)
    for (x, y, st) in ((13, 17, 2), (14, 16, 3), (21, 18, 2), (22, 17, 2)):
        pix[(x, y)] = col("green", st)   # 바질 두 잎
    for (x, y), c in pix.items():
        f.dots[(x, y)] = c
    return f


#  ══════════════════════════════════════════════════════════
#  12. 도넛 — 불이 사라진다 · 칸 값 올림
#  물건: 분홍 글레이즈가 흘러내린 링 도넛, 가운데 구멍이 크고 새까맣다.
#  판의 한복판이 뻥 뚫렸고 그것이 가장 큰 명암 덩어리다. 칸 값 올림은 달게
#  얹힌 글레이즈와 스프링클로 말한다. 판 테마(DONUTART, shots/btheme_dnut.png)와
#  재료가 같다 — 반죽 skin-2(d99a52) · 반죽 그늘 skin-1 · 반죽 빛 skin-3 ·
#  구멍 night-0 · 스프링클 다섯 색(cream · gold · blue · pink · green)에서 넷.
#  스프링클(위키백과: 지미는 가느다란 막대) · 링 도넛(윗면만 글레이즈가 덮고
#  가운데가 뚫렸다) · 도트 도넛 강의(megavoxels How to Make a Pixel Art Donut —
#  반죽과 윗면 글레이즈를 두 덩어리로 가르고 스프링클을 네 색으로 흩는다)를 봤고,
#  drawcentral 의 작은 도넛 글은 막혀 검색 요약(녹아 흐른 방울 · 가장자리에서
#  떨어진 곡선 반짝임)만 봤다.
#
#  ── 두 번째 눈(2026-09-17 검토) ──
#  첫 판은 판의 더블 띠처럼 글레이즈를 빨강 · 초록으로 번갈아 칠했는데, 26px 에서
#  **크리스마스 리스**(초록 잎에 빨간 열매)로 읽혔다. 조각 경계를 곧게 다듬어도
#  빨강 · 초록 고리는 리스였고, 빨강 한 색은 반죽(skin-2)과 값이 붙어 케첩이
#  됐다. 분홍(pink-2, 판 스프링클 ff7ab8 의 램프)은 반죽과 색상이 멀어 한눈에
#  「글레이즈 도넛」이다. 글레이즈 가장자리는 물결(10 마루) + 방울 넷으로 흐르고,
#  왼위 한 줄을 pink-3 로 올려 윤을 낸다.
def dnut():
    f = Wappen("dnut", u"도넛", rim="skin", cloth="night", cloth_base=2)
    drips = {200: 2.4, 125: 1.8, 290: 2.0, 40: 1.4}     # 방울 — 각도: 길이
    for (x, y) in disc(CX, CY, 12.0):
        d = dist(x, y)
        a = ang(x, y)
        k = lit(x, y)
        lim = 8.6 + 0.55 * math.cos(math.radians(a * 10.0))
        for da, ln in drips.items():
            off = abs(((a - da) + 180.0) % 360.0 - 180.0)
            if off < 10.0:
                lim = max(lim, 8.6 + ln * (1.0 - off / 10.0) + 0.5)
        if d > lim:
            f.dot(x, y, "skin", 3 if k > 0.45 else (1 if k < -0.45 else 2))   # 반죽
        elif d > 5.8:
            st = 2
            if 6.6 <= d <= 8.0 and k > 0.5:
                st = 3                      # 윤
            if k < -0.6 and d > 7.5:
                st = 1
            f.dot(x, y, "pink", st)
        elif d > 4.2:
            #  구멍 안벽 — 빛은 맞은편(오른아래) 벽에 닿는다
            f.dot(x, y, "skin", 3 if k < -0.3 else (1 if k > 0.5 else 2))
        else:
            f.dot(x, y, "night", 0)
    #  스프링클 — 1x2 막대. 분홍 위라 판의 pink 는 뺀다
    bars = ((19, 7, 20, 7), (25, 12, 25, 13), (23, 20, 24, 21), (12, 21, 13, 21),
            (8, 14, 8, 15), (13, 9, 14, 9), (17, 23, 18, 23), (26, 17, 26, 18))
    hues = (("cream", 3), ("green", 3), ("blue", 3), ("gold", 3))
    for i, (x0, y0, x1, y1) in enumerate(bars):
        ramp, st = hues[i % 4]
        f.dot(x0, y0, ramp, st)
        f.dot(x1, y1, ramp, st)
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
