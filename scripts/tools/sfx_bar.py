# -*- coding: utf-8 -*-
# ══════════════════════════════════════════════════════════
#  술집에서 눈을 뜬다 — 그 장면의 소리를 굽는다 (2026-10-25)
#     py -3 scripts/tools/sfx_bar.py            ← 여섯을 굽고 잰다(sfx/bar_*.wav · .import)
#     godot --headless --import                 ← 구운 뒤 한 번
#     godot --headless --script scripts/tools/qa_barsfx.gd   ← 이름으로 읽고 · 로패스 버스로 트는지
#
#  sfx_bake.gd 와 같은 규약이다 — 파일이 아니라 **수치가 원본**이고, 잡음은 씨를 박아 몇 번 구워도 같은 파일이
#  나오고, 크기는 game.gd SFX 표의 그 줄(합성음 앞 50ms 에너지 — sfx_voice.gd 의 식을 옮겼다)에 맞춘다.
#  여기만 numpy 인 까닭: 작은 방 잔향(합성 IR 컨볼루션)과 8 초 순환을 FFT 로 돈다 — sfx_bake 의 샘플 루프로는 못 돈다.
#
#  ── 순환 넷은 원 위에서 짓는다 ──────────────────────────
#  bar_room · bar_polish · bar_tv_static · bar_tv_hum. 음은 길이의 정수 배 주파수만 · 떨림 · 숨은 길이에 정수 바퀴 ·
#  필터와 잔향은 원형(FFT 한 바퀴) · 계단은 원 위에서 다듬는다 — 끝 샘플 다음이 정확히 첫 샘플이라 이음에 딸깍이
#  날 자리가 없다(main 이 이음 뜀 · 표와의 크기 · 6k 위 몫 · 닿는 때를 재고, 넘으면 1 로 끝난다). 게임은 rain 처럼 사본에 LOOP_FORWARD 를 걸어 돌린다(.import 의 loop 는 0 —
#  개발자 판 소리 쪽에서 틀면 한 번만 난다).
#
#  ── 지붕 ────────────────────────────────────────────────
#  probe_sfx 의 「6kHz 위 에너지 2%」 를 넘지 않게 5kHz 4단으로 덮는다. 수평 편향 고음(bar_tv_hum)만 그 위다 —
#  NTSC 15.734kHz 의 한 옥타브 아래 7867Hz(tv_on 의 「가는 고음」 7.6~7.9k 와 같은 자리). 진짜 15.7k 는 어른 귀 ·
#  노트북 스피커 밖이고 이 저장소 지붕(6k)의 두 배 반이라, 옥타브를 내려 웅 밑 에너지 5% 로만 얹는다.
# ══════════════════════════════════════════════════════════
import re
import sys
import wave
from pathlib import Path

import numpy as np

SR = 44100
ROOT = Path(__file__).resolve().parents[2]
SFX_DIR = ROOT / "sfx"
WIN = 0.050          # 크기를 재는 창(초) — sfx_voice.gd WIN
ROOF = 5000.0
WHINE = 7867.0       # 15.734kHz / 2


def ns(sec):
    return max(int(round(sec * SR)), 1)


def rms(x):
    return float(np.sqrt(np.mean(x * x))) if len(x) else 0.0


def unit(x):
    r = rms(x)
    return x / r if r > 0 else x


# ── 모양(주파수 쪽 크기 · 영위상) ─────────────────────────
def lp(f, fc, k=2):
    return 1.0 / np.sqrt(1.0 + (f / fc) ** (2 * k))


def hp(f, fc, k=2):
    return 1.0 / np.sqrt(1.0 + (fc / np.maximum(f, 1e-3)) ** (2 * k))


def bell(f, fc, db, octv):
    return 10.0 ** (db / 20.0 * np.exp(-0.5 * (np.log2(np.maximum(f, 1e-3) / fc) / octv) ** 2))


def shape(x, fn, loop):
    #  loop 면 원형 — 이음이 그대로 잇는다. 아니면 앞울림이 꼬리로 안 접히게 덧대고 자른다.
    n = len(x)
    m = n if loop else n + ns(0.05)
    X = np.fft.rfft(x, m) * fn(np.fft.rfftfreq(m, 1.0 / SR))
    return np.fft.irfft(X, m)[:n]


def circ_smooth(x, ms):
    #  원 위의 한닝 창 — 계단 모서리를 ms 로만 굴린다(딸깍은 지우고 계단은 남긴다).
    k = max(ns(ms / 1000.0), 2)
    w = np.zeros(len(x))
    w[:k] = np.hanning(k)
    w /= w.sum()
    out = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(w), len(x))
    return np.roll(out, -(k // 2))


def raised(n, a_ms, r_ms):
    #  올리고 내리는 반코사인 창
    e = np.ones(n)
    a, r = min(ns(a_ms / 1000.0), n), min(ns(r_ms / 1000.0), n)
    e[:a] *= 0.5 - 0.5 * np.cos(np.pi * np.arange(a) / a)
    e[n - r:] *= 0.5 + 0.5 * np.cos(np.pi * np.arange(r) / r)
    return e


def mode(n, f, amp, tau, t0=0.0, split=0.0):
    #  부분음 하나 — 갈라진 짝(유리의 겹친 모드가 비대칭으로 갈라져 천천히 맥놀이한다)
    t = np.arange(n) / SR - t0
    y = np.zeros(n)
    on = t >= 0
    tt = t[on]
    if split > 0:
        s = 0.6 * np.sin(2 * np.pi * (f - split / 2) * tt) + 0.4 * np.sin(2 * np.pi * (f + split / 2) * tt)
    else:
        s = np.sin(2 * np.pi * f * tt)
    y[on] = amp * np.exp(-tt / tau) * s * np.minimum(tt / 0.0003, 1.0)
    return y


def burst(n, t0, dur, tau, rng, fn):
    #  잡음 토막 — 먼저 깎고 그 다음에 감쇠(앞울림이 안 선다)
    m = ns(dur)
    v = shape(rng.standard_normal(m), fn, False)
    tt = np.arange(m) / SR
    v *= np.exp(-tt / tau) * np.minimum(tt / 0.0002, 1.0)
    y = np.zeros(n)
    i = ns(t0) if t0 > 0 else 0
    j = min(n, i + m)
    y[i:j] = v[: j - i]
    return y


# ── 작은 방 — 합성 IR ────────────────────────────────────
#  빈 술집(나무 바 · 병 선반 · 낮은 천장) — 이른 반사 여덟(벽 · 카운터 · 천장) 위에 확산 꼬리가 7ms 뒤 15ms 에 걸쳐
#  선다. 꼬리는 대역마다 RT60 이 다르다(저역 0.55 · 중역 0.45 · 고역 0.26 초 — 고역이 먼저 죽는다). 에너지 1.
ER = ((3.1, 0.70), (5.4, -0.55), (8.9, 0.50), (12.6, -0.42), (15.2, 0.36), (19.7, -0.30), (24.3, 0.26), (31.0, -0.20))


def room_ir(seed=2510):
    rng = np.random.default_rng(seed)
    n = ns(0.9)
    t = np.arange(n) / SR
    F = np.fft.rfft(rng.standard_normal(n))
    f = np.fft.rfftfreq(n, 1.0 / SR)
    tail = np.zeros(n)
    for m, rt in ((lp(f, 350), 0.55), (hp(f, 350) * lp(f, 2500), 0.45), (hp(f, 2500), 0.26)):
        tail += np.fft.irfft(F * m, n) * np.exp(-6.908 * t / rt)
    tail *= np.clip((t - 0.007) / 0.015, 0.0, 1.0)
    er = np.zeros(n)
    for ms, g in ER:
        er[ns(ms / 1000.0)] += g
    tail *= np.sqrt(3.0 * np.sum(er ** 2) / np.sum(tail ** 2))     # 확산 : 이른 반사 = 3 : 1(에너지)
    ir = shape(er + tail, lambda f: lp(f, 6000, 1), False)
    return ir / np.sqrt(np.sum(ir ** 2))


IR = room_ir()


def verb(x, dry, wet, loop):
    if loop:
        w = np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(IR, len(x)), len(x))
    else:
        m = len(x) + len(IR)
        w = np.fft.irfft(np.fft.rfft(x, m) * np.fft.rfft(IR, m), m)[: len(x)]
    return dry * x + wet * w


def roof(x, loop, lo=35.0):
    return shape(x, lambda f: hp(f, lo, 2) * lp(f, ROOF, 4), loop)


# ══════════════════════════════════════════════════════════
#  여섯 — 무엇이 무엇에 닿는 소리인가
# ══════════════════════════════════════════════════════════

def b_room():
    #  빈 홀의 방 소리(순환 8초) — 바 밑 냉장고 압축기(전기 웅 120 · 회전 58.75 와 배음 — 117.5 와 120 이 2.5Hz 로
    #  천천히 맥놀이한다) · 압축기 몸의 덜덜(58.75Hz 로 떨리는 낮은 잡음) · 응축기 팬(500Hz 언저리 바람 · 날개 104Hz) ·
    #  네온 안정기 지잉(120Hz 배음 서른셋 · 상자 속이라 3.5k 밑) · 관의 아주 옅은 지글(120Hz 로 맥박) · 방 공기(분홍).
    #  사람 소리 없음 — 홀이 비었다.
    L = 8.0
    n = ns(L)
    t = np.arange(n) / SR
    rng = np.random.default_rng(2601)
    cyc = lambda k: 2 * np.pi * k / L          # 길이에 k 바퀴
    hum = np.zeros(n)
    for f, a in ((120.0, 1.0), (240.0, 0.35), (360.0, 0.18), (480.0, 0.08), (600.0, 0.05),
                 (58.75, 0.55), (117.5, 0.30), (176.25, 0.22), (235.0, 0.12), (293.75, 0.07)):
        k = int(rng.integers(1, 4))
        hum += a * np.sin(2 * np.pi * f * t + rng.uniform(0, 2 * np.pi)
                          + rng.uniform(0.2, 0.8) * np.sin(cyc(k) * t + rng.uniform(0, 2 * np.pi)))
    hum *= 1.0 + 0.07 * np.sin(cyc(3) * t + 0.4) + 0.04 * np.sin(cyc(7) * t + 2.1)
    mech = shape(rng.standard_normal(n), lambda f: hp(f, 70) * lp(f, 650), True)
    mech *= 1.0 + 0.35 * np.sin(2 * np.pi * 58.75 * t)
    fan = shape(rng.standard_normal(n), lambda f: hp(f, 150) * lp(f, 2200, 1) * bell(f, 520, 4.0, 1.0), True)
    fan = unit(fan) * (1.0 + 0.12 * np.sin(2 * np.pi * 20.875 * t))
    fan += 0.06 * np.sin(2 * np.pi * 104.375 * t) + 0.025 * np.sin(2 * np.pi * 208.75 * t + 1.0)
    buzz = np.zeros(n)
    for k in range(1, 34):
        buzz += k ** -1.1 * np.sin(2 * np.pi * 120.0 * k * t + rng.uniform(0, 2 * np.pi))
    buzz = shape(buzz, lambda f: lp(f, 3500), True) * (1.0 + 0.1 * np.sin(cyc(2) * t))
    fizz = shape(rng.standard_normal(n), lambda f: hp(f, 2500) * lp(f, 4800), True) * np.sin(2 * np.pi * 60.0 * t) ** 2
    air = shape(rng.standard_normal(n), lambda f: hp(f, 60) * lp(f, 3000, 1) / np.sqrt(np.maximum(f, 20.0)), True)
    x = (unit(hum) * 1.0 + unit(mech) * 0.30 + unit(fan) * 0.32 + unit(buzz) * 0.13
         + unit(fizz) * 0.03 + unit(air) * 0.24)
    return roof(verb(x, 0.85, 0.40, True), True), True


def b_clink():
    #  먼 잔 — 바 끝에서 두꺼운 잔 둘이 가볍게 닿고(1520 · 1745Hz 텀블러 · 부분음 1 : 2.29 : 3.95 : 5.92 · 울림 0.25 초 밑 ·
    #  짝마다 1.5~4Hz 맥놀이) 속 얼음이 두 번 똑똑 친다(52 · 121ms). 멀어서 3kHz 위가 꺾이고 잔향이 직접음보다 크다.
    n = ns(1.3)
    rng = np.random.default_rng(2611)
    parts = ((1.0, 1.0, 0.25), (2.29, 0.5, 0.14), (3.95, 0.22, 0.07), (5.92, 0.08, 0.04))
    x = np.zeros(n)
    for f0, g, tk in ((1520.0, 1.0, 1.0), (1745.0, 0.55, 0.75)):
        for r, a, tau in parts:
            x += mode(n, f0 * r, a * g, tau * tk, 0.0, rng.uniform(1.5, 4.0))
    x += 0.25 * burst(n, 0.0, 0.004, 0.00025, rng, lambda f: hp(f, 2500))
    for t0, g in ((0.052, 0.35), (0.121, 0.22)):
        x += g * burst(n, t0, 0.006, 0.0008, rng, lambda f: hp(f, 2000) * lp(f, 4500))
        x += mode(n, 1520.0, g * 0.5, 0.2, t0, 2.2)
    x = shape(x, lambda f: hp(f, 300) * lp(f, 3000), False)
    x = verb(x, 0.5, 0.9, False)
    return roof(x, False, 120.0) * raised(n, 0.0, 250.0), False


def b_polish():
    #  잔을 닦는 천(순환 3초 = 비틀기 1.5초 둘) — 마른 천이 잔 안벽을 문지른다. 비틀 때마다 빠르기가 sin^1.5 로 서고
    #  돌아설 때 0 에 닿는다. 문지름(350~3200 띠 · 잔이 1250 · 2900Hz 로 옅게 운다 · 올이 긁는 거친 결) 위에 마찰
    #  삐걱(붙었다 미끄러지는 1.7kHz 대 음 · 10ms 마다 끊긴다)이 네 획 중 넷에 세기를 달리해 든다.
    #  t=0 은 첫 정방향 비틀기의 가장 빠른 때(세게 삐걱) — 돌아서는 때(가장 조용)는 0.375 · 1.125 · 1.875 · 2.625 초.
    L = 3.0
    n = ns(L)
    t = np.arange(n) / SR
    rng = np.random.default_rng(2621)
    half = 0.75
    v = np.zeros(n)
    for s0, g in ((0.0, 1.0), (0.75, 0.8), (1.5, 0.92), (2.25, 0.85)):
        tau = t - s0
        on = (tau >= 0) & (tau < half)
        v[on] = g * np.sin(np.pi * tau[on] / half) ** 1.5
    glass = lambda f: bell(f, 1250, 6.0, 0.08) * bell(f, 2900, 5.0, 0.07)
    rub = shape(rng.standard_normal(n), lambda f: hp(f, 350) * lp(f, 3200) * bell(f, 1100, 4.0, 1.0) * glass(f), True)
    rasp = np.maximum(1.0 + 0.6 * unit(shape(rng.standard_normal(n), lambda f: lp(f, 45), True)), 0.2)
    rub = rub * rasp * v ** 1.3
    rub /= rms(rub[v > 0.7])
    sq = np.zeros(n)
    for a0, a1, g in ((0.38, 0.58, 1.0), (1.08, 1.17, 0.6), (1.90, 1.97, 0.45), (2.55, 2.73, 0.8)):
        i0, m = ns(a0), ns(a1 - a0)
        tt = np.arange(m) / SR
        jit = unit(shape(rng.standard_normal(m), lambda f: lp(f, 12), False))
        f_s = (1700.0 + 400.0 * (v[i0:i0 + m] - 0.6)) * (1.0 + 0.04 * np.sin(2 * np.pi * 7.0 * tt) + 0.02 * jit)
        ph = np.cumsum(2 * np.pi * f_s / SR)
        tone = sum(k ** -2.0 * np.sin(k * ph) for k in range(1, 4))
        cells = int(np.ceil(m / ns(0.010)))
        gate = np.repeat((rng.random(cells) < 0.8).astype(float), ns(0.010))[:m]
        gate = np.convolve(gate, np.hanning(ns(0.002)) / np.hanning(ns(0.002)).sum(), "same")
        sq[i0:i0 + m] += g * tone * gate * raised(m, 20.0, 20.0)
    held = sq != 0
    sq = shape(sq, lambda f: hp(f, 700) * lp(f, 4500) * bell(f, 1250, 4.0, 0.1) * bell(f, 2900, 4.0, 0.1), True)
    sq /= rms(sq[held])
    x = rub + 0.6 * sq
    x = roof(verb(x, 0.9, 0.22, True), True, 250.0)
    return np.roll(x, -ns(0.375)), True


def b_glass_down():
    #  닦은 빈 잔을 나무 카운터에 놓는다 — 밑굽 테가 먼저 닿는 톡(2~5k 딸깍 · 손에 쥔 채라 잔 울림은 90ms 에 죽는다) ·
    #  두꺼운 바 상판의 둔한 쿵(172 · 296 · 455 · 690 · 1040Hz · 11~50ms) · 14ms 뒤 굽이 판판히 내려앉는 둘째 닿음
    #  (0.45) · 60ms 뒤 1cm 미끄러지는 옅은 마찰.
    n = ns(0.8)
    rng = np.random.default_rng(2631)
    x = np.zeros(n)
    wood = ((172.0, 1.0, 0.05), (296.0, 0.7, 0.038), (455.0, 0.45, 0.026), (690.0, 0.3, 0.019), (1040.0, 0.18, 0.011))
    for t0, g in ((0.0, 1.0), (0.014, 0.45)):
        x += g * 0.5 * burst(n, t0, 0.003, 0.0004, rng, lambda f: hp(f, 2000) * lp(f, 5000))
        for f, a, tau in wood:
            x += g * mode(n, f * (1.0 if t0 == 0 else 1.03), a, tau, t0)
        x += g * 0.6 * burst(n, t0, 0.04, 0.012, rng, lambda f: lp(f, 400))
        for r, a, tau in ((1.0, 0.5, 0.09), (2.31, 0.25, 0.05), (4.02, 0.1, 0.03)):
            x += g * mode(n, 1380.0 * r, a, tau, t0, 2.5)
    m = ns(0.08)
    sl = shape(rng.standard_normal(m), lambda f: hp(f, 1200) * lp(f, 3500), False) * np.sin(np.pi * np.arange(m) / m)
    x[ns(0.06):ns(0.06) + m] += 0.06 * unit(sl)
    x = verb(x, 1.0, 0.3, False)
    return roof(x, False, 60.0) * raised(n, 0.0, 200.0), False


def b_tv_static():
    #  바 뒤 천장에 걸린 작은 브라운관 TV 의 지지직(순환 4초) — tv_static 과 같은 세 층(쉿 · 크래클 · 몸)을 작은 통
    #  스피커로 받는다(300~4800 · 950 · 2600Hz 통 울림). 몸은 수직 동기 60Hz 지잉(펄스 배음 마흔). 큰 세기가 **계단**
    #  으로 뛴다 — 0.08~0.42 초씩 버티는 넷(0.18 · 0.4 · 0.7 · 1.0)과 가끔 30~70ms 끊김(0.05) · 모서리 3ms.
    #  쉿은 16ms 칸마다 0.55~1.0 으로 거칠게 끊긴다. t=0 은 1.0 단의 머리다.
    L = 4.0
    n = ns(L)
    t = np.arange(n) / SR
    rng = np.random.default_rng(2641)
    holds, lv = [], []
    last = None
    while sum(holds) < L:
        if lv and rng.random() < 0.12:
            holds.append(rng.uniform(0.03, 0.07))
            lv.append(0.05)
            continue
        c = 1.0 if not lv else float(rng.choice([l for l in (0.18, 0.4, 0.7, 1.0) if l != last]))
        holds.append(rng.uniform(0.08, 0.42))
        lv.append(c)
        last = c
    edges = np.round(np.cumsum([0.0] + holds) * (n / sum(holds))).astype(int)
    step = np.zeros(n)
    for i, c in enumerate(lv):
        step[edges[i]:edges[i + 1]] = c
    step = circ_smooth(step, 3.0)
    cell = ns(0.016)
    gate = circ_smooth(np.repeat(rng.uniform(0.55, 1.0, int(np.ceil(n / cell))), cell)[:n], 1.5)
    hiss = unit(rng.standard_normal(n)) * gate
    ck = np.zeros(n)
    for _ in range(int(30 * L)):
        i0 = int(rng.integers(0, n))
        m = ns(0.0015)
        ck[(i0 + np.arange(m)) % n] += rng.random() ** 2 * rng.standard_normal(m) * np.exp(-np.arange(m) / (0.0004 * SR))
    ck = shape(ck, lambda f: hp(f, 2000) * lp(f, 4800), True)
    buzz = sum(k ** -0.8 * np.cos(2 * np.pi * 60.0 * k * t) for k in range(1, 41))
    x = unit(hiss) * step + 0.35 * unit(ck) * step + 0.22 * unit(buzz) * (0.4 + 0.6 * step)
    x = shape(x, lambda f: hp(f, 300) * lp(f, 4800, 4) * bell(f, 950, 5.0, 0.8) * bell(f, 2600, 3.0, 0.7), True)
    c = 3.0 * rms(x)                # 작은 콘이 봉우리를 먹는다 — 튀는 크래클이 봉우리를 쥐면 머리가 「부푼다」
    x = c * np.tanh(x / c)
    return roof(verb(x, 0.9, 0.3, True), True, 120.0), True


def b_tv_hum():
    #  그 TV 가 켜져 있는 바탕(순환 4초) — 수직 편향 60Hz 지잉(홀수 배음이 굵다 · 작은 통이라 80~1200) 위에
    #  수평 편향 고음 7867Hz(0.75Hz 로 8% 숨)를 웅 밑 에너지 5% 로만 얹는다(머리말 「지붕」).
    L = 4.0
    n = ns(L)
    t = np.arange(n) / SR
    rng = np.random.default_rng(2651)
    hum = sum((1.4 if k % 2 else 1.0) / k * np.sin(2 * np.pi * 60.0 * k * t + rng.uniform(0, 2 * np.pi))
              for k in range(1, 21))
    hum = shape(hum, lambda f: hp(f, 80) * lp(f, 1200), True) * (1.0 + 0.05 * np.sin(2 * np.pi * t / L))
    hum = verb(hum, 0.9, 0.2, True)
    wh = np.sin(2 * np.pi * WHINE * t) * (1.0 + 0.08 * np.sin(2 * np.pi * 0.75 * t))
    wh = verb(wh, 0.9, 0.2, True)
    share = 0.05
    return unit(hum) + unit(wh) * np.sqrt(share / (1.0 - share)), True


#  인광 점 속으로(2026-10-28 · prologue3d PHOS) — 파일 PH_H 초가 handoff(무대를 끊고 게임 필터를 켜는 틀) · 파일 0 초가
#  뛰어듦 첫 틀(prologue_bar3d · prologue3d entry_at). 그 앞 틀 자리는 결이 바뀌는 틀(PH_STEPS — 유리가 화면을 덮는 틀 ·
#  stripe · round 배에 닿는 틀) · 뒤는 겹침 단(PH_CONV) — 둘 다 handoff 기준 60Hz 틀. 손으로 옮겨 적지 않고
#  prologue3d.gd 의 표를 읽는다(표를 바꾸면 다시 굽는다 · Plg phos_lunge · phos_m 과 같은 셈).
def phos_table():
    src = (ROOT / "scripts" / "prologue3d.gd").read_text(encoding="utf-8")
    ph = re.search(r"^const PHOS := \{(.*?)^\}", src, re.S | re.M).group(1)
    num = lambda k: float(re.search(r'"%s":\s*([\d.]+)' % k, ph).group(1))
    solid, run, v0, rp = int(num("solid")), int(num("run")), num("v0"), num("ramp")
    m0, m1 = (float(v) for v in re.search(r'"mag":\s*\[([\d.]+),\s*([\d.]+)\]', ph).groups())
    vm = (np.log(m1 / m0) - v0 * rp * 0.5) / (run - rp * 0.5)
    mag = lambda F: m0 * np.exp(v0 * min(F, rp) + (vm - v0) * min(F, rp) ** 2 / (2.0 * rp) + vm * max(F - rp, 0.0))
    steps = [-run] + [next(F for F in range(run) if mag(F) >= num(k)) - run for k in ("stripe", "round")]
    cv = re.search(r'"conv":\s*\[(.*?)\]\],', ph, re.S).group(1)
    conv = [int(v) for v in re.findall(r"\[(\d+),", cv)]
    return (solid + run) / 60.0, tuple(steps), tuple(conv)


PH_H, PH_STEPS, PH_CONV = phos_table()


def b_phos():
    #  브라운관 속으로 빨려 든다 — 차오르는 웅(수직 편향 60Hz 홀수 배음 · 60 → 90Hz 로 오른다) 위에 이잉(2.4 → 4.5kHz 로
    #  오르는 가는 사인 — 처음부터 같은 띠의 잡음을 섞어 순음이 안 선다 · 옛 1.2 → 4.6k 홀로 오르는 사인은 충전음 · 휘슬로
    #  들렸다) · 결이 바뀔 때마다 지직(유리가 화면을 덮는 틀 · R · G · B 줄이 서는 틀 · 줄 끝이 둥글어지는 틀 —
    #  고압 톡 · 1.8~4.8k 띠 잡음이 잦아든다 · 뒤로 갈수록 세다). 차오름은 웅이 처음의 여섯 배 남짓에서 선다(옛 열두 배는
    #  쌓은 꼭대기가 도착한 쾅보다 컸다). handoff 에 셋이 5ms 로 끊기고 60Hz 웅 꼬리 · 겹침 단마다 작아지는 톡 — 넘김엔
    #  때리는 소리가 없다(0.33 초 뒤 두 낱말이 붙는 쾅이 「들어왔다」 한 박) · 방에 울리지 않는다(TV 속이다 · 잔향 없음).
    L = PH_H + 0.47
    n = ns(L)
    t = np.arange(n) / SR
    rng = np.random.default_rng(2661)
    pre = t < PH_H
    u = np.clip(t / PH_H, 0.0, 1.0)
    cut = np.clip((PH_H - t) / 0.005, 0.0, 1.0)            # handoff 에 5ms 로 끊는다
    #  웅 — 위상을 쌓아 오르는 음정(60 → 90Hz)
    fh = 60.0 * (1.0 + 0.5 * u ** 2)
    ph = 2 * np.pi * np.cumsum(fh) / SR
    hum = sum((1.4 if k % 2 else 1.0) / k * np.sin(k * ph + rng.uniform(0, 2 * np.pi)) for k in range(1, 21))
    hum = shape(hum, lambda f: hp(f, 70) * lp(f, 1400), False) * (0.16 + 0.84 * u ** 1.6) * cut
    #  이잉 — 사인과 같은 띠 잡음을 반씩(검토 2 — 웅이 59% 라 150Hz 밑이 빠지는 노트북 · 발표장 스피커에서 차오르는 동안
    #  거의 안 들렸다 → 이잉 · 띠 잡음 +6dB · 2~6kHz 몫이 차오르는 내내 12% 넘게)
    fw = 2400.0 * (4500.0 / 2400.0) ** (u ** 1.4) * (1.0 + 0.004 * np.sin(2 * np.pi * 6.0 * t))
    ew = u ** 1.2 * cut                                  # 일찍 들린다(옛 u^2.2 는 앞 0.5 초 2~6k 가 4% 밑)
    wh = np.sin(2 * np.pi * np.cumsum(fw) / SR) * ew
    wn = unit(shape(rng.standard_normal(n), lambda f: hp(f, 2200) * lp(f, 4800, 3), False)) * ew
    #  지직 — 결이 바뀌는 틀마다
    fz = np.zeros(n)
    tk = np.zeros(n)
    st = [PH_H + f / 60.0 for f in PH_STEPS] + [PH_H]
    band = lambda f: hp(f, 1800) * lp(f, 4800, 3)
    for i in range(len(PH_STEPS)):
        a, b = ns(st[i]), ns(st[i + 1])
        lv = 0.55 + 0.45 * i / (len(PH_STEPS) - 1)
        seg = unit(shape(rng.standard_normal(b - a), band, False))
        tt = np.arange(b - a) / SR
        fz[a:b] += lv * seg * np.exp(-tt / 0.035) * np.minimum(tt / 0.002, 1.0)
        tk += lv * burst(n, st[i], 0.004, 0.0006, rng, band)
        for _ in range(2 + i):
            tk += lv * 0.5 * rng.random() * burst(n, rng.uniform(st[i], st[i + 1]), 0.003, 0.0004, rng, band)
    fz *= cut
    tk *= cut
    #  넘김 — 웅 꼬리 · 겹침 단마다 작아지는 톡
    tl = np.clip(t - PH_H, 0.0, None)
    post = ~pre
    tail = np.zeros(n)
    tph = 2 * np.pi * 60.0 * tl[post]
    tail[post] = (np.sin(tph) + 0.5 * np.sin(3 * tph) + 0.25 * np.sin(5 * tph)) * np.exp(-tl[post] / 0.15)         * np.minimum(tl[post] / 0.004, 1.0)
    cv = np.zeros(n)
    for j, f in enumerate(PH_CONV[1:]):
        cv += (0.5 - 0.08 * j) * burst(n, PH_H + f / 60.0, 0.003, 0.0005, rng, band)
    pk = lambda y: y / max(np.max(np.abs(y)), 1e-9)       # 봉우리 1 로 맞춰 섞는다(섞는 몫이 곧 봉우리)
    x = (0.32 * pk(hum) + 0.10 * wh + 0.10 * pk(wn) + 0.30 * pk(fz) + 0.40 * pk(tk) + 0.07 * tail
         + 0.10 * pk(cv))
    return roof(x, False, 35.0) * raised(n, 0.0, 60.0), False


BUILD = {"bar_room": b_room, "bar_clink": b_clink, "bar_polish": b_polish,
         "bar_glass_down": b_glass_down, "bar_tv_static": b_tv_static, "bar_tv_hum": b_tv_hum, "bar_phos": b_phos}
#  부푸는 소리 — 봉우리가 끝(handoff)에 선다(「닿는 때 30ms」 검사를 안 건다 · tv_glint 와 같은 꼴)
SWELL = {"bar_phos"}


# ══════════════════════════════════════════════════════════
#  자 — 크기는 표가 정한다 · 재는 것은 probe_sfx 와 같은 식
# ══════════════════════════════════════════════════════════

def table_row(src, nm):
    m = re.search(r'"%s":\s*\{"f":\s*([\d.]+),\s*"d":\s*([\d.]+),\s*"a":\s*([\d.]+)\}' % nm, src)
    if not m:
        sys.exit("game.gd SFX 표에 %s 줄이 없다 — 표에 먼저 적어라" % nm)
    return tuple(float(v) for v in m.groups())


def ref_rms(f, d, a):
    #  sfx_voice.gd ref() + rms() — 사인 55% + 사각 45% · 감쇠 (1-t/d)² 의 앞 50ms 에너지
    n, w = ns(d), ns(WIN)
    i = np.arange(n)
    s = np.sin(2 * np.pi * f * i / SR)
    env = np.maximum(1.0 - i / (d * SR), 0.0)
    x = ((s * 0.55 + np.sign(s) * 0.45) * env * env * a)[:w]
    return float(np.sqrt(np.sum(x * x) / w))


def rms50(x):
    w = ns(WIN)
    return float(np.sqrt(np.sum(x[:w] ** 2) / w))


def above6k(x):
    #  probe_sfx _above — 1극 하이패스 두 단 · 앞 1000ms 의 에너지 몫
    a = np.exp(-2 * np.pi * 6000.0 / SR)
    y = x[: ns(1.0)].astype(float).tolist()
    for _ in range(2):
        o = px = 0.0
        for i, v in enumerate(y):
            o = a * (o + v - px)
            px = v
            y[i] = o
    w = ns(1.0)
    hi = np.sqrt(np.sum(np.square(y)) / w)
    full = float(np.sqrt(np.sum(x[:w] ** 2) / w))
    return (hi / full) ** 2 if full > 0 else 0.0


def kw(x):
    #  BS.1770 K 가중(48k 계수의 크기를 그대로 — 에너지만 쓰므로 위상은 상관없다)
    m = len(x) + ns(0.1)
    f = np.fft.rfftfreq(m, 1.0 / SR)
    z = np.exp(-1j * 2 * np.pi * f / 48000.0)
    h1 = (1.53512485958697 - 2.69169618940638 * z + 1.19839281085285 * z * z) / \
         (1.0 - 1.69065929318241 * z + 0.73248077421585 * z * z)
    h2 = (1.0 - 2.0 * z + z * z) / (1.0 - 1.99004745483398 * z + 0.99007225036621 * z * z)
    return np.fft.irfft(np.fft.rfft(x, m) * np.abs(h1 * h2), m)[: len(x)]


def loud(x, loop):
    #  (통합 LUFS, 순간 최대 LUFS). 순환은 두 바퀴 이어 잰다. 400ms 보다 짧으면 무음을 덧댄 한 토막.
    y = kw(np.tile(x, 2) if loop else x)
    b = ns(0.4)
    if len(y) < b:
        y = np.concatenate([y, np.zeros(b - len(y))])
    c = np.concatenate([[0.0], np.cumsum(y * y)])
    hop = ns(0.1)
    blk = np.array([(c[i + b] - c[i]) / b for i in range(0, len(y) - b + 1, hop)])
    mom = (c[b:] - c[:-b]) / b
    lk = lambda p: -0.691 + 10 * np.log10(max(p, 1e-12))
    g = blk[blk > 10 ** ((-70 + 0.691) / 10)]
    if len(g):
        g = g[g > np.mean(g) * 0.1]
    return lk(np.mean(g) if len(g) else 1e-12), lk(mom.max())


def read_wav(p):
    with wave.open(str(p), "rb") as w:
        d = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(float) / 32768.0
        return d.reshape(-1, w.getnchannels())[:, 0]


def write_wav(nm, x):
    with wave.open(str(SFX_DIR / (nm + ".wav")), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(np.round(np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2").tobytes())
    imp = SFX_DIR / (nm + ".wav.import")
    if imp.exists():
        old = imp.read_text(encoding="utf-8")
        if "compress/mode=0" in old and "edit/trim=false" in old:
            return
    #  sfx_bake.gd _import 와 같은 두 값(QOA 끔 · 트림 끔) · uid 는 고닷이 가져갈 때 채운다
    imp.write_text("[remap]\n\nimporter=\"wav\"\ntype=\"AudioStreamWAV\"\n\n"
                   "[deps]\n\nsource_file=\"res://sfx/%s.wav\"\n\n" % nm
                   + "[params]\n\nforce/8_bit=false\nforce/mono=false\n"
                   "force/max_rate=false\nforce/max_rate_hz=44100\n"
                   "edit/trim=false\nedit/normalize=false\nedit/loop_mode=0\n"
                   "edit/loop_begin=0\nedit/loop_end=-1\ncompress/mode=0\n", encoding="utf-8")


def stretch(x, pitch):
    #  _sfx(nm, f) 의 pitch_scale — 파일 전체를 다시 뽑는다(재는 용 · 선형)
    m = int(len(x) / pitch)
    return np.interp(np.arange(m) * pitch, np.arange(len(x)), x)


def lp_godot(x, fc, db=0.0):
    #  AudioEffectLowPassFilter(공진 0.5 · 2차) 크기 + 볼륨 — 프롤로그에서 「들리는」 비를 재는 용
    m = len(x) + ns(0.1)
    w = np.fft.rfftfreq(m, 1.0 / SR) / fc
    h = 1.0 / np.sqrt((1 - w * w) ** 2 + (w / 0.5) ** 2)
    return np.fft.irfft(np.fft.rfft(x, m) * h, m)[: len(x)] * 10 ** (db / 20)


def main():
    src = (ROOT / "scripts" / "game.gd").read_text(encoding="utf-8")
    only = sys.argv[1:]
    print("%-15s %7s %6s %6s %7s %7s %7s %6s %7s" % ("이름", "길이", "피크", "닿는때", "RMS차", "LUFS", "순간최대", "6k위", "이음"))
    print("-" * 72)
    bad = []
    for nm, fn in BUILD.items():
        if only and nm not in only:
            continue
        x, loop = fn()
        f, d, a = table_row(src, nm)
        x = x * (ref_rms(f, d, a) / rms50(x))
        pk = float(np.max(np.abs(x)))
        if pk > 0.9:
            bad.append("%s — 피크 %.2f 가 천장에 붙었다 · 표의 a 를 내려라" % (nm, pk))
            x *= 0.9 / pk
        write_wav(nm, x)
        y = read_wav(SFX_DIR / (nm + ".wav"))           # 16비트로 쓴 그것을 다시 잰다
        ddb = 20 * np.log10(rms50(y) / ref_rms(f, d, a))
        hi = above6k(y)
        atk = float(np.argmax(np.abs(y) >= 0.5 * np.max(np.abs(y)))) / SR * 1000.0   # probe_sfx 의 닿는 때
        li, lm = loud(y, loop)
        dif = np.abs(np.diff(y))
        seam = abs(y[0] - y[-1]) / max(np.percentile(dif, 99.9), 1e-9) if loop else 0.0
        print("%-15s %6.2fs %6.3f %4.0fms %+6.1fdB %7.1f %7.1f %5.1f%% %7s"
              % (nm, len(y) / SR, np.max(np.abs(y)), atk, ddb, li, lm, hi * 100, "%.2f" % seam if loop else "-"))
        if abs(ddb) > 0.5:
            bad.append("%s — 표와 %+.1fdB" % (nm, ddb))
        if atk > 30.0 and nm not in SWELL:
            bad.append("%s — 봉우리 절반에 %.0fms 뒤에 닿는다(probe_sfx 「부푸는 소리」)" % (nm, atk))
        if hi >= 0.02:
            bad.append("%s — 6kHz 위 %.1f%%" % (nm, hi * 100))
        if seam > 1.0:
            bad.append("%s — 이음 뜀이 보통 샘플 차의 %.1f 배(딸깍)" % (nm, seam))
    #  견줄 자 — 지금 프롤로그(테이프 여는 장면)가 실제로 내는 크기
    print("\n- 지금 프롤로그 -")
    refs = (("rain", lambda x: lp_godot(x, 700.0, 4.0), True, "Rain 버스 700Hz · +4dB"),
            ("tv_static", lambda x: stretch(x, 0.45), False, "×0.45"),
            ("tv_on", None, False, ""), ("tape_rattle", None, False, ""), ("tape_in", None, False, ""),
            ("deck_btn", None, False, ""), ("deck_clunk", None, False, ""), ("deck_whir", None, False, ""))
    for nm, fx, loop, say in refs:
        y = read_wav(SFX_DIR / (nm + ".wav"))
        if fx:
            y = fx(y)
        li, lm = loud(y, loop)
        print("%-15s %6.2fs %6.3f %15s %7.1f %7.1f  %s" % (nm, len(y) / SR, np.max(np.abs(y)), "", li, lm, say))
    if bad:
        print("\n- 볼 것 -")
        for b in bad:
            print("  " + b)
        sys.exit(1)


if __name__ == "__main__":
    main()
