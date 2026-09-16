# -*- coding: utf-8 -*-
"""음악을 짓는다.

    python scripts/tools/mus_bake.py
    godot --headless --path . --import      ← 구운 뒤 한 번

assets/music/<이름>.wav 를 여기서 **굽는다.** 효과음(scripts/tools/sfx_bake.gd)
과 같은 규약이다 — 원본은 파일이 아니라 이 안의 수치이고, 수치는 이 저장소의
것이다. 그래서 음악에도 조건이 안 붙는다(docs/크레딧.md 의 그 빈 자리).

── 왜 새로 굽는가 ──────────────────────────────────────────
빌려 온 네 곡은 서로 **남**이었다. game.gd 의 MUS_ADAPTIVE 주석이 그 셋을
이미 재 놓았다.
    템포   85.26 ~ 85.68 BPM   (0.42 어긋난다 → 62초에 반 박이 밀린다)
    길이   61.574 ~ 61.973초   (명세 허용치는 0.001초)
    끝     넷 중 셋이 페이드아웃한다 (루프 자리가 아니다)
그래서 겹쳐 넘기는 방식을 걷고 나갔다 들어오는 방식으로 바꿔야 했고,
발라트로처럼 한 타임라인에 묶는 적응형은 아예 못 켰다.

여기서 굽는 넷은 **한 곡의 네 편곡**이다. 같은 조(A 단조) · 같은 화성 ·
같은 템포 · 같은 길이 · 같은 마디 자리 · 같은 자로 잰 크기. 넷이 언제
바뀌어도 박자가 안 밀리고, 겹쳐도 부딪히지 않는다.

── 루프가 이음매 없이 도는 이유 ───────────────────────────
길이를 먼저 정하고(N 샘플) 그 위에 음을 얹는다. 끝을 넘어가는 여운은
**앞으로 감아** 더한다(_add 의 % N). 잔향도 같은 규칙을 지나므로 마지막
샘플 다음이 첫 샘플과 이어진다 — 페이드아웃이 없는 것이 그 결과다.

── 목소리 ─────────────────────────────────────────────────
_bass    낮은 사인 + 배음 한 줌 + 손가락 딸깍. 콘트라베이스 자리다.
_keys    로즈. 사인 셋을 살짝 어긋나게 겹치고 종 같은 어택을 얹는다.
_pad     톱니 둘을 어긋나게 — 보스의 현이다. 떨림(트레몰로)이 알맹이다.
_lead    부드러운 어택의 사인+홀수배음. 뮤트 트럼펫 자리다.
_kick    사인의 음높이를 110 → 45 로 떨어뜨린다. 그 미끄러짐이 킥이다.
_snare   잡음 + 180Hz 몸통. _brush 는 같은 잡음을 부풀렸다 재운다.
_hat     고역 잡음 짧게. _ride 는 거기에 **비배음** 부분음 몇을 더한다.

── 되먹임을 파이썬 고리로 안 돈다 ─────────────────────────
빗 필터 y[i] += g·y[i−d] 는 i 와 i−d 만 엮이므로, 버퍼를 (줄, d) 로 접으면
줄 사이의 점화식이 된다. 200만 번이 2천 번이 되고 그 2천 번이 벡터 연산이다.
"""

import math
import os
import struct
import sys

import numpy as np

SR = 44100
BPM = 86.0
BARS = 16
BEATS = BARS * 4
#  루프 길이(샘플). 이 수가 먼저고 템포는 여기서 따라 나온다 — 거꾸로
#  두면 마지막 박이 반올림으로 한두 샘플 어긋나 이음매에 딸깍이 생긴다.
N = int(round(BEATS * 60.0 / BPM * SR))
SPB = N / float(BEATS)          # 한 박의 샘플 수

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "music")

#  잡음은 씨를 박는다 — 같은 씨면 몇 번 구워도 같은 파일이 나온다
#  (sfx_bake.gd 와 같은 규약이다).
rng = np.random.default_rng(20260916)


# ── 바탕 ───────────────────────────────────────────────────

def hz(midi):
    """MIDI 번호 → 헤르츠. A4(69) = 440."""
    return 440.0 * (2.0 ** ((midi - 69) / 12.0))


def _add(buf, x, at):
    """at 샘플에 얹는다. 끝을 넘으면 앞으로 감는다 — 루프가 이음매 없이
    도는 것이 전부 이 한 줄에서 온다."""
    n = len(x)
    if n <= 0:
        return
    at = int(at) % N
    if at + n <= N:
        buf[at:at + n] += x
        return
    k = N - at
    buf[at:] += x[:k]
    rest = x[k:]
    while len(rest) >= N:
        buf += rest[:N]
        rest = rest[N:]
    if len(rest):
        buf[:len(rest)] += rest


def _env(n, a_ms, d_ms, s=0.0, r_ms=0.0, curve=2.0):
    """어택-감쇠. s 가 0 이면 붙었다 그대로 진다."""
    e = np.zeros(n)
    a = min(max(int(a_ms * 0.001 * SR), 1), n)
    e[:a] = np.linspace(0.0, 1.0, a) ** 0.6
    rest = n - a
    if rest <= 0:
        return e
    d = max(d_ms * 0.001 * SR, 1.0)
    body = np.exp(-(np.arange(rest) / d) * curve)
    if s > 0.0:
        body = s + (1.0 - s) * body
        if r_ms > 0.0:
            r = min(max(int(r_ms * 0.001 * SR), 1), rest)
            body[-r:] *= np.linspace(1.0, 0.0, r) ** 1.4
    e[a:] = body
    return e


def _noise(n):
    return rng.standard_normal(n)


def _lp(x, fc):
    """한 극 저역통과. 지수 커널과 콘볼브한다 — 되먹임을 파이썬으로 돌 일이
    없고, 꼬리가 60dB 떨어지는 자리에서 끊으면 차이가 안 들린다."""
    a = math.exp(-2.0 * math.pi * fc / SR)
    if a <= 1e-6:
        return x.astype(float).copy()
    ln = int(min(len(x), math.ceil(math.log(1e-3) / math.log(a)) + 1))
    ker = (1.0 - a) * (a ** np.arange(ln))
    return np.convolve(x, ker)[:len(x)]


def _hp(x, fc):
    return x - _lp(x, fc)


def _bp(x, f0, q):
    """대역통과. 저역·고역 하나씩 겹친다 — 자리에 맞으면 되는 자리라
    급한 기울기가 필요 없다."""
    w = 1.0 + 1.0 / max(q, 0.3)
    return _hp(_lp(x, min(f0 * w, SR * 0.48)), f0 / w)


def _sine(f, n, ph=0.0):
    return np.sin((2.0 * math.pi * f / SR) * np.arange(n) + ph)


def _saw(f, n, ph=0.0, top=4200.0):
    """대역제한 톱니. top 헤르츠까지만 배음을 쌓는다 — 그냥 톱니는
    되접힘이 잡음으로 들리고, 어차피 뒤에서 저역통과를 지난다."""
    t = np.arange(n) / float(SR)
    y = np.zeros(n)
    k = 1
    while f * k < min(top, SR * 0.45) and k <= 24:
        y += np.sin(2.0 * math.pi * f * k * t + ph) / k
        k += 1
    return y * 0.55


def _comb(x, d, g):
    """y[i] += g·y[i−d]. (줄, d) 로 접으면 줄 사이의 점화식이다."""
    pad = (-len(x)) % d
    y = np.concatenate([x, np.zeros(pad)]) if pad else x.astype(float).copy()
    v = y.reshape(-1, d)
    for i in range(1, v.shape[0]):
        v[i] += v[i - 1] * g
    return y[:len(x)]


def _allpass(x, d, g):
    """슈뢰더 올패스.  y[n] = −g·x[n] + x[n−d] + g·y[n−d]"""
    xd = np.concatenate([np.zeros(d), x[:-d]]) if d < len(x) else np.zeros(len(x))
    return _comb(-g * x + xd, d, g)


# ── 목소리 ─────────────────────────────────────────────────

def _bass(midi, beats, amp=1.0):
    """콘트라베이스 한 음. 손가락이 줄을 뜯는 딸깍이 앞에 붙는다 —
    그 8ms 가 없으면 베이스가 아니라 저역 사인이다."""
    n = int(beats * SPB) + int(0.20 * SR)
    f = hz(midi)
    e = _env(n, 4.0, beats * SPB / SR * 620.0, curve=2.4)
    y = _sine(f, n) + _sine(f * 2.0, n) * 0.24 + _sine(f * 3.0, n) * 0.08
    y *= e
    cn = int(0.012 * SR)
    y[:cn] += _bp(_noise(cn), f * 6.0, 1.1) * _env(cn, 0.4, 6.0, curve=4.0) * 0.30
    return y * (0.34 * amp)


def _keys(midis, beats, amp=1.0, spread=0.004):
    """로즈 한 화음. 음마다 사인 셋을 살짝 어긋나게 겹쳐 두께를 낸다."""
    n = int(beats * SPB) + int(0.5 * SR)
    out = np.zeros(n)
    dms = beats * SPB / SR * 700.0
    for j, m in enumerate(midis):
        f = hz(m)
        e = _env(n, 6.0, dms, curve=2.0)
        v = np.zeros(n)
        for d in (-spread, 0.0, spread):
            v += _sine(f * (1.0 + d), n, ph=j * 1.1)
        v *= 1.0 / 3.0
        #  종 같은 어택 — 4.1배음이 34ms 만 산다. 로즈의 톤바가 그 소리다.
        v += _sine(f * 4.1, n) * _env(n, 1.0, 34.0, curve=3.2) * 0.13
        v += _sine(f * 2.0, n) * 0.18
        out += v * e * (1.0 - 0.06 * j)
    return out * (0.46 * amp / max(len(midis), 1))


def _pad(midis, beats, amp=1.0):
    """현. 톱니 둘을 어긋나게 겹치고 통째로 떨린다 — 떨림이 없으면
    오르간이 된다."""
    n = int(beats * SPB) + int(0.35 * SR)
    out = np.zeros(n)
    for j, m in enumerate(midis):
        f = hz(m)
        out += (_saw(f * 0.9965, n, ph=j * 0.7, top=2600.0)
                + _saw(f * 1.0035, n, ph=j * 2.1, top=2600.0)) * 0.5
    trem = 0.80 + 0.20 * np.sin((2.0 * math.pi * 5.2 / SR) * np.arange(n))
    e = _env(n, 260.0, 900.0, s=0.72, r_ms=420.0, curve=1.4)
    out = _lp(out, 2100.0) * e * trem
    return out * (0.29 * amp / max(len(midis), 1))


def _lead(midi, beats, amp=1.0):
    """뮤트 트럼펫 자리. 어택이 느리고 홀수 배음이 산다."""
    n = int(beats * SPB) + int(0.25 * SR)
    f = hz(midi)
    ms = beats * SPB / SR * 1000.0
    e = _env(n, 26.0, ms * 0.5, s=0.45, r_ms=ms * 0.45, curve=2.0)
    y = (_sine(f, n) + _sine(f * 2.0, n) * 0.10 + _sine(f * 3.0, n) * 0.22
         + _sine(f * 5.0, n) * 0.09)
    #  숨 — 아주 옅은 잡음이 음 위에 얹힌다. 없으면 그냥 사인 톤이다.
    y += _bp(_noise(n), f * 2.4, 1.6) * 0.05
    t = np.arange(n) / float(SR)
    y *= 1.0 + 0.0035 * np.sin(2.0 * math.pi * 5.0 * t) * np.minimum(t * 3.0, 1.0)
    return y * e * (0.20 * amp)


def _kick(amp=1.0):
    n = int(0.42 * SR)
    t = np.arange(n) / float(SR)
    f = 45.0 + 65.0 * np.exp(-t * 46.0)
    y = np.sin(2.0 * math.pi * np.cumsum(f) / SR) * _env(n, 1.0, 105.0, curve=2.4)
    cn = int(0.004 * SR)
    y[:cn] += _hp(_noise(cn), 1800.0) * _env(cn, 0.2, 2.0, curve=5.0) * 0.30
    return y * (0.62 * amp)


def _snare(amp=1.0, bright=1.0):
    n = int(0.26 * SR)
    body = (_sine(182.0, n) * 0.6 + _sine(268.0, n) * 0.35) \
        * _env(n, 1.0, 46.0, curve=3.0)
    wire = _hp(_noise(n), 1500.0 * bright) * _env(n, 1.0, 78.0, curve=2.6)
    return (body * 0.5 + wire * 0.62) * (0.40 * amp)


def _brush(beats, amp=1.0):
    """브러시가 판을 훑는다. 스네어와 같은 잡음인데 붙었다 지는 대신
    부풀었다 진다 — 그 봉투 하나가 스틱과 브러시를 가른다."""
    n = int(beats * SPB)
    y = _bp(_noise(n), 3400.0, 0.8)
    t = np.linspace(0.0, 1.0, n)
    return y * (np.sin(np.pi * t ** 0.8) ** 1.6) * (0.18 * amp)


def _hat(open_=False, amp=1.0):
    n = int((0.22 if open_ else 0.055) * SR)
    y = _hp(_noise(n), 6800.0) * _env(n, 0.4, 20.0 if open_ else 7.0, curve=3.0)
    return y * (0.16 * amp)


def _ride(amp=1.0):
    n = int(0.55 * SR)
    y = _hp(_noise(n), 5200.0) * _env(n, 0.5, 42.0, curve=2.0) * 0.55
    #  비배음 부분음 — 쇠가 울리는 자리다. 배음이면 통이 된다.
    t = np.arange(n)
    for r, a, d in ((1.0, 0.30, 0.40), (2.71, 0.20, 0.30),
                    (4.13, 0.13, 0.20), (5.43, 0.09, 0.14)):
        y += _sine(2380.0 * r, n) * np.exp(-t / (d * SR)) * a
    return y * (0.10 * amp)


def _shaker(amp=1.0):
    n = int(0.09 * SR)
    return _bp(_noise(n), 7200.0, 1.2) * _env(n, 2.0, 16.0, curve=2.4) * (0.13 * amp)


# ── 잔향 ───────────────────────────────────────────────────

def _verb(x, mix=0.18):
    """슈뢰더 한 벌 — 빗 넷과 올패스 둘. 라운지의 방 하나면 되는 자리라
    이른 반사도 모듈레이션도 안 판다. **루프 안에서 돈다** — 버퍼를
    두 바퀴 이어 붙여 재우고 뒷바퀴만 쓰면 꼬리가 앞으로 감긴다."""
    two = np.concatenate([x, x])
    wet = np.zeros(len(two))
    for dl, g in ((1116, 0.805), (1188, 0.795), (1277, 0.783), (1356, 0.774)):
        wet += _comb(two, dl, g) * 0.25
    for dl, g in ((556, 0.7), (441, 0.7)):
        wet = _allpass(wet, dl, g)
    wet = _lp(wet, 5200.0)[len(x):]
    return x * (1.0 - mix * 0.35) + wet * mix


# ── 화성 ───────────────────────────────────────────────────
#  A 단조. 여덟 마디를 두 번 돈다 — 네 편곡이 전부 이 표를 본다.
#  (베이스 뿌리 MIDI, 화음 네 음, 이름)
PROG = [
    (45, [60, 64, 67, 71], "Am9"),
    (50, [60, 65, 69, 72], "Dm9"),
    (47, [62, 65, 69, 74], "Bm7b5"),
    (52, [56, 62, 65, 71], "E7b9"),
    (45, [60, 64, 67, 71], "Am9"),
    (41, [57, 60, 64, 69], "Fmaj7"),
    (50, [57, 60, 65, 69], "Dm7"),
    (52, [56, 62, 64, 71], "E7sus"),
]
#  걷는 베이스가 박마다 딛는 음 — 뿌리에서의 반음 차다. 넷째 박은 표를
#  안 보고 **다음 뿌리로 반음 다가간다**(_lay_bass). 걷는 베이스는 그 한
#  음이 전부다.
WALK = [
    [0, 7, 12, 8], [0, 7, 12, 10], [0, 6, 10, 13], [0, 7, 10, 11],
    [0, 7, 12, 8], [0, 7, 12, 13], [0, 7, 10, 12], [0, 7, 11, 12],
]
#  가락. (마디, 박, 길이(박), MIDI). 여덟 마디 한 줄이다.
TUNE = [
    (0, 2.0, 1.5, 76), (0, 3.5, 0.5, 74), (1, 0.0, 2.0, 72),
    (1, 2.5, 1.5, 69), (2, 1.0, 1.0, 74), (2, 2.0, 2.0, 77),
    (3, 0.5, 1.0, 76), (3, 2.0, 1.5, 72),
    (4, 2.0, 1.5, 76), (4, 3.5, 0.5, 79), (5, 0.0, 2.5, 81),
    (5, 3.0, 1.0, 77), (6, 0.0, 1.5, 76), (6, 2.0, 2.0, 74),
    (7, 1.0, 1.0, 71), (7, 2.0, 2.0, 69),
]


def beat(bar, b):
    return int(round((bar * 4 + b) * SPB))


def chord(bar):
    return PROG[bar % 8]


# ── 얹는 층 ────────────────────────────────────────────────

def _lay_bass(buf, walking, amp=1.0):
    for bar in range(BARS):
        root = chord(bar)[0]
        if not walking:
            _add(buf, _bass(root, 2.2, amp), beat(bar, 0))
            _add(buf, _bass(root + 7, 1.6, amp * 0.82), beat(bar, 2.5))
            continue
        nxt = chord(bar + 1)[0]
        steps = WALK[bar % 8]
        for b in range(4):
            m = (nxt - 1 if bar % 2 == 0 else nxt + 1) if b == 3 \
                else root + steps[b]
            _add(buf, _bass(m, 0.98, amp), beat(bar, b))


def _lay_keys(buf, mode, amp=1.0):
    for bar in range(BARS):
        notes = chord(bar)[1]
        if mode == "sustain":
            _add(buf, _keys(notes, 3.6, amp), beat(bar, 0))
        elif mode == "comp":
            #  뒤 박에 얹는다. 앞 박에 두면 베이스와 한 덩어리가 된다.
            _add(buf, _keys(notes, 1.1, amp), beat(bar, 1.5))
            _add(buf, _keys(notes, 1.4, amp * 0.85), beat(bar, 3.0))
            if bar % 4 == 3:
                _add(buf, _keys(notes, 0.6, amp * 0.7), beat(bar, 2.25))
        elif mode == "stab":
            _add(buf, _keys(notes, 0.7, amp), beat(bar, 0))
            _add(buf, _keys(notes, 0.5, amp * 0.8), beat(bar, 2.5))


def _lay_lead(buf, amp=1.0, halves=(1,)):
    """halves 0 = 앞 여덟 마디 · 1 = 뒤 여덟 마디. 한쪽만 얹으면 같은
    루프가 앞뒤로 다르게 들린다 — 45초 루프가 90초처럼 도는 법이다."""
    for h in halves:
        for (bar, b, ln, m) in TUNE:
            _add(buf, _lead(m, ln, amp * (1.0 if h else 0.86)),
                 beat(bar + h * 8, b))


def _lay_drums(buf, kind):
    for bar in range(BARS):
        if kind == "brush":
            #  브러시 훑기 — 2와 4에서 판을 문지른다. 킥은 첫 박만.
            _add(buf, _brush(1.0, 0.9), beat(bar, 1))
            _add(buf, _brush(1.0, 0.75), beat(bar, 3))
            _add(buf, _kick(0.42), beat(bar, 0))
            for b in (0.5, 1.5, 2.5, 3.5):
                _add(buf, _ride(0.34), beat(bar, b))
        elif kind == "light":
            _add(buf, _kick(0.68), beat(bar, 0))
            _add(buf, _kick(0.50), beat(bar, 2.5))
            _add(buf, _snare(0.50, 1.2), beat(bar, 1))
            _add(buf, _snare(0.50, 1.2), beat(bar, 3))
            for b in (0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5):
                _add(buf, _shaker(1.0 if float(b).is_integer() else 0.62),
                     beat(bar, b))
        elif kind == "full":
            _add(buf, _kick(1.0), beat(bar, 0))
            _add(buf, _kick(0.72), beat(bar, 2.5))
            if bar % 4 == 3:
                _add(buf, _kick(0.60), beat(bar, 3.5))
            _add(buf, _snare(0.95), beat(bar, 1))
            _add(buf, _snare(0.95), beat(bar, 3))
            if bar % 8 == 7:
                #  여덟 마디 끝의 채움. 루프 자리를 귀가 알아보게 한다.
                for i, b in enumerate((3.25, 3.5, 3.75)):
                    _add(buf, _snare(0.50 + 0.14 * i), beat(bar, b))
            for i, b in enumerate((0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5)):
                _add(buf, _ride(0.90 if i % 2 == 0 else 0.55), beat(bar, b))
        elif kind == "boss":
            #  네 박을 다 친다. 급한 것이 보스의 전부다.
            for b in range(4):
                _add(buf, _kick(1.0 if b % 2 == 0 else 0.72), beat(bar, b))
            _add(buf, _snare(0.85, 0.8), beat(bar, 1))
            _add(buf, _snare(0.85, 0.8), beat(bar, 3))
            for b in (0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5):
                _add(buf, _hat(False, 0.85 if float(b).is_integer() else 0.5),
                     beat(bar, b))
            if bar % 4 == 3:
                _add(buf, _hat(True, 0.9), beat(bar, 3.5))


# ── 편곡 넷 ────────────────────────────────────────────────

def track_lobby():
    """로비 — 타이틀·설정·컬렉션. 가장 성기다. 손님이 여기 오래 머무르므로
    반복이 덜 지겨워야 하고, 그러려면 얹는 것이 적어야 한다."""
    b = np.zeros(N)
    _lay_bass(b, walking=False, amp=0.95)
    _lay_keys(b, "sustain", 0.95)
    _lay_drums(b, "brush")
    _lay_lead(b, 0.50, halves=(1,))
    return _verb(b, 0.26)


def track_select():
    """고르는 자리 — 판 선택·상점·정산. 베이스가 걷기 시작한다."""
    b = np.zeros(N)
    _lay_bass(b, walking=True, amp=0.95)
    _lay_keys(b, "comp", 1.00)
    _lay_drums(b, "light")
    _lay_lead(b, 0.42, halves=(1,))
    return _verb(b, 0.20)


def track_game():
    """판 위 — 작은 판·큰 판. 다 얹는다."""
    b = np.zeros(N)
    _lay_bass(b, walking=True, amp=1.05)
    _lay_keys(b, "comp", 0.92)
    _lay_drums(b, "full")
    _lay_lead(b, 0.62, halves=(0, 1))
    return _verb(b, 0.16)


def track_boss():
    """보스 판. 같은 화성인데 **가락이 없고** 현이 깔린다 — 노래가
    사라지고 바탕만 남는 것이 조여드는 소리다."""
    b = np.zeros(N)
    _lay_bass(b, walking=True, amp=1.15)
    _lay_keys(b, "stab", 0.68)
    _lay_drums(b, "boss")
    for bar in range(BARS):
        _add(b, _pad([m - 12 for m in chord(bar)[1]], 3.9, 1.0), beat(bar, 0))
    #  낮은 드론 하나. 마디마다 안 끊기고 통째로 깔린다.
    _add(b, _pad([33], BEATS - 0.1, 0.55), 0)
    return _verb(b, 0.14)


TRACKS = [("lobby", track_lobby), ("select", track_select),
          ("game", track_game), ("boss", track_boss)]


# ── 마무리 ─────────────────────────────────────────────────

def rms_db(x):
    return 20.0 * math.log10(max(float(np.sqrt(np.mean(x * x))), 1e-9))


def seam_db(x):
    """이음매의 계단. 마지막 샘플과 첫 샘플의 차를 신호의 RMS 로 잰다 —
    루프가 도는 자리에서 딸깍이 나는지는 귀보다 이 수가 먼저 안다."""
    step = abs(float(x[0]) - float(x[-1]))
    return 20.0 * math.log10(max(step, 1e-9) / max(float(np.sqrt(np.mean(x * x))), 1e-9))


def write_wav(path, x):
    pcm = (np.clip(x, -1.0, 1.0) * 32767.0).astype("<i2")
    raw = pcm.tobytes()
    with open(path, "wb") as f:
        f.write(b"RIFF")
        f.write(struct.pack("<I", 36 + len(raw)))
        f.write(b"WAVEfmt ")
        f.write(struct.pack("<IHHIIHH", 16, 1, 1, SR, SR * 2, 2, 16))
        f.write(b"data")
        f.write(struct.pack("<I", len(raw)))
        f.write(raw)


def write_import(path, name):
    """.import 를 같이 쓴다. uid 와 remap 경로는 안 적는다 — 고닷이
    가져갈 때 채운다. 기본과 달라야 하는 값은 둘이다.
      edit/loop_mode=2   Forward. **가져오기의 번호는 AudioStreamWAV 와 다르다** — 0 이
                         「WAV 에서 알아내기」라 한 칸씩 밀려, 1 이 끄기고 2 가 Forward 다.
      edit/trim=false    앞뒤를 자르면 루프 자리가 밀린다
    """
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write('[remap]\n\nimporter="wav"\ntype="AudioStreamWAV"\n\n')
        f.write('[deps]\n\nsource_file="res://assets/music/%s.wav"\n\n' % name)
        f.write("[params]\n\nforce/8_bit=false\nforce/mono=false\n"
                "force/max_rate=false\nforce/max_rate_hz=44100\n"
                "edit/trim=false\nedit/normalize=false\nedit/loop_mode=2\n"
                "edit/loop_begin=0\nedit/loop_end=-1\ncompress/mode=0\n")


def main():
    only = [a for a in sys.argv[1:] if not a.startswith("-")]
    os.makedirs(OUT, exist_ok=True)
    print("길이 %d 샘플 = %.3f초 · %d마디 · %.2f BPM · 한 박 %.1f 샘플"
          % (N, N / float(SR), BARS, BPM, SPB))
    raw = {}
    for name, fn in TRACKS:
        if only and name not in only:
            continue
        raw[name] = fn()
        print("  %-7s 지음  피크 %.3f" % (name, float(np.max(np.abs(raw[name])))))

    #  넷을 **같은 자로** 잰다. 따로 정규화하면 편곡이 바뀔 때 크기가
    #  계단으로 튄다 — 빌려 온 넷이 그래서 안 맞았다.
    top = max(float(np.max(np.abs(v))) for v in raw.values())
    out = {}
    for name, x in raw.items():
        out[name] = np.tanh(x / top * 1.30) * 0.94
    top2 = max(float(np.max(np.abs(v))) for v in out.values())
    for name in out:
        out[name] *= 0.89 / top2

    for name, y in out.items():
        wp = os.path.join(OUT, name + ".wav")
        write_wav(wp, y)
        write_import(wp + ".import", name)
        print("  %-7s 구움  RMS %+.1f dB · 피크 %.3f · 이음매 %+.1f dB · %.1f MB"
              % (name, rms_db(y), float(np.max(np.abs(y))), seam_db(y),
                 os.path.getsize(wp) / 1048576.0))


if __name__ == "__main__":
    main()
