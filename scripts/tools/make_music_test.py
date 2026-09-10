# -*- coding: utf-8 -*-
"""적응형 BGM 시험용 편곡 넷을 만든다.

    python scripts/tools/make_music_test.py

명세(godot_adaptive_bgm_spec)는 **같은 곡의 편곡 넷**을 요구한다. 지금
assets/music 의 네 곡은 그 계약을 못 맞춘다(템포가 0.42 BPM 어긋나고 길이가
0.32초 다르고 셋은 끝에서 페이드아웃한다). 명세의 missing_assets 조항이
그 경우 "직접 만든 동일 길이 테스트 신호"를 쓰라고 하므로 이 파일이 그것을
만든다.

넷은 **같은 화음 진행 위에 쌓는 층만 다르다** — 그래서 크로스페이드가
음악으로 들린다. 공통 악기(패드)가 넷 다에 있는 것이 명세가 선형 진폭
보간을 고른 전제(curve_reason)와 같은 전제다.

길이는 프레임까지 정확히 같다. BPM 을 84 로 고른 것이 그 때문이다 —
44100 / (84/60) 이 31500 프레임으로 딱 떨어져서 8마디가 1,008,000 프레임
(22.857142...초)이 된다. 소수점이 남는 템포는 마지막 마디에서 프레임이
어긋나고, 그 어긋남이 곧 명세가 막으려는 드리프트다. 지금 게임 음악 넷이
85.26~85.68 BPM 으로 흩어져 있는 것이 바로 그 고장이다.

형식은 **모노 16비트 PCM WAV** 다. 명세는 OGG 를 선호하지만 이 환경의
libsndfile vorbis 인코더가 프로세스를 죽여서(헤더만 쓰고 종료) 명세가
대체로 허용한 PCM WAV 로 간다. 44.1kHz 는 프로젝트 믹스레이트와 같고,
내용이 어차피 모노라 채널을 둘로 늘리면 크기만 두 배가 된다.

루프 이음매는 **겹쳐 접어서** 없앤다. 16마디보다 길게 그린 다음 넘친 꼬리를
맨 앞에 더한다 — 잔향이 루프를 넘어 이어지므로 경계에서 뚝 끊기지 않는다.
"""
import numpy as np, soundfile as sf, os

SR = 44100
BEAT_FR = 31500                 # 프레임/박 — 정수라야 길이가 안 어긋난다
BPM = SR * 60.0 / BEAT_FR       # 84.0
BEATS_PER_BAR = 4
BARS = 8
BAR_FR = BEAT_FR * BEATS_PER_BAR
N = BAR_FR * BARS               # 1,008,000 프레임
TAIL = BAR_FR * 2               # 접어 넣을 꼬리

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "audio", "music", "tracks")

# 가온다 기준 반음 → Hz
def hz(n): return 440.0 * 2.0 ** ((n - 9) / 12.0)

# Am - F - C - G, 각 두 마디. 넷이 이 진행을 공유한다.
PROG = [(-12, [0, 3, 7]), (-16, [0, 4, 7]), (-9, [0, 4, 7]), (-14, [0, 4, 7])]


def env(n, a, d, r, sus):
    """어택-디케이-서스테인-릴리스. 길이 n 프레임. 0 에서 시작해 0 으로 끝난다 —
    끝을 0 으로 못 박아야 음이 겹칠 때 딸깍거리지 않는다."""
    ai, di, ri = min(int(a * SR), n), 0, 0
    di = min(int(d * SR), n - ai)
    ri = min(int(r * SR), n - ai - di)
    e = np.full(n, sus, dtype=np.float64)
    if ai: e[:ai] = np.linspace(0.0, 1.0, ai, endpoint=False)
    if di: e[ai:ai + di] = np.linspace(1.0, sus, di, endpoint=False)
    if ri: e[n - ri:] = np.linspace(sus, 0.0, ri)
    return e


def tone(buf, at, dur, f, amp, kind="saw", **kw):
    n = int(dur * SR)
    if at >= len(buf): return
    n = min(n, len(buf) - at)
    if n <= 0: return
    t = np.arange(n) / SR
    ph = 2 * np.pi * f * t
    if kind == "sine":   w = np.sin(ph)
    elif kind == "tri":  w = 2 / np.pi * np.arcsin(np.sin(ph))
    elif kind == "sq":   w = np.sign(np.sin(ph)) * 0.6
    else:                w = 2 * (t * f - np.floor(0.5 + t * f))
    e = env(n, kw.get("a", 0.01), kw.get("d", 0.08), kw.get("r", 0.25), kw.get("s", 0.55))
    buf[at:at + n] += w * e * amp


def noise(buf, at, dur, amp, hp=0.0):
    n = int(dur * SR)
    if at >= len(buf): return
    n = min(n, len(buf) - at)
    if n <= 0: return
    x = np.random.RandomState(at % 9973).randn(n)
    if hp > 0:
        # 1차 하이패스를 차분으로 근사한다. 정확한 필터가 필요한 자리가
        # 아니라 "쇳소리만 남기면 되는" 자리라 이걸로 충분하고, 표본마다
        # 도는 파이썬 루프를 안 만든다.
        k = max(1, int(SR / (2.0 * np.pi * hp)))
        x = np.diff(np.concatenate([np.zeros(k), x]), n=1)[:n] if k == 1 else             x - np.convolve(x, np.ones(k) / k, mode="same")
    buf[at:at + n] += x * env(n, 0.0005, 0.02, 0.03, 0.02) * amp


def kick(buf, at, amp=0.9):
    n = int(0.28 * SR)
    if at >= len(buf): return
    n = min(n, len(buf) - at)
    t = np.arange(n) / SR
    f = 110 * np.exp(-t * 28) + 45
    buf[at:at + n] += np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9) * amp


def render(layers):
    """layers 를 그려 N+TAIL 길이로 만든 뒤 꼬리를 접어 N 으로 돌려준다."""
    buf = np.zeros(N + TAIL)
    for fn in layers:
        fn(buf)
    out = buf[:N].copy()
    out[:TAIL] += buf[N:N + TAIL]      # 루프를 넘어온 잔향을 앞에 얹는다
    return out


def bar_at(b): return b * BAR_FR
def chord_of(b): return PROG[(b // 2) % 4]


def L_pad(buf):                      # 공통 악기 — 넷 다에 있다
    for b in range(BARS + 2):
        root, iv = chord_of(b)
        for k in iv:
            tone(buf, bar_at(b), 2.9, hz(root + k + 12), 0.075,
                 "tri", a=0.35, d=0.4, s=0.8, r=0.9)

def L_bass(buf):
    for b in range(BARS + 2):
        root, _ = chord_of(b)
        for beat in (0, 2):
            tone(buf, bar_at(b) + beat * BEAT_FR, 0.62, hz(root - 12), 0.30,
                 "saw", a=0.005, d=0.14, s=0.4, r=0.12)

def L_arp(buf):
    for b in range(BARS + 2):
        root, iv = chord_of(b)
        for i in range(8):
            k = iv[i % len(iv)] + (12 if i >= 4 else 0)
            tone(buf, bar_at(b) + i * BEAT_FR // 2, 0.30, hz(root + k + 12), 0.10,
                 "sine", a=0.004, d=0.10, s=0.25, r=0.12)

def L_pulse(buf):                    # 조준 — 뒷박을 때리는 긴장
    for b in range(BARS + 2):
        root, _ = chord_of(b)
        for beat in range(4):
            tone(buf, bar_at(b) + beat * BEAT_FR + BEAT_FR // 2, 0.16,
                 hz(root + 7 + 12), 0.085, "sq", a=0.002, d=0.05, s=0.15, r=0.06)

def L_hat(buf):
    for b in range(BARS + 2):
        for i in range(8):
            noise(buf, bar_at(b) + i * BEAT_FR // 2, 0.05,
                  0.030 if i % 2 else 0.045, hp=6000)

def L_perc(buf):
    for b in range(BARS + 2):
        kick(buf, bar_at(b), 0.55)
        kick(buf, bar_at(b) + 2 * BEAT_FR, 0.45)
        noise(buf, bar_at(b) + BEAT_FR, 0.12, 0.16, hp=1800)
        noise(buf, bar_at(b) + 3 * BEAT_FR, 0.12, 0.16, hp=1800)

def L_lead(buf):                     # 마지막 — 선율이 올라온다
    mel = [0, 3, 7, 10, 7, 3, 5, 7]
    for b in range(BARS + 2):
        root, _ = chord_of(b)
        for i, k in enumerate(mel):
            if i % 2 and b % 2: continue
            tone(buf, bar_at(b) + i * BEAT_FR // 2, 0.34, hz(root + k + 24), 0.075,
                 "tri", a=0.006, d=0.12, s=0.3, r=0.14)


ARR = {
    "main":  [L_pad, L_bass, L_hat],
    "shop":  [L_pad, L_arp],
    "aim":   [L_pad, L_bass, L_pulse, L_hat],
    "final": [L_pad, L_bass, L_perc, L_lead],
}

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    print(f"BPM {BPM:.4f} · {BARS}마디 · {N} 프레임 ({N/SR:.6f}초) · {SR}Hz 모노 16비트")
    peaks = {}
    raw = {k: render(v) for k, v in ARR.items()}
    # 크로스페이드 중 청취 음량이 맞도록 RMS 를 맞춘다(명세 7절 마지막 줄)
    ref = np.sqrt((raw["main"] ** 2).mean())
    for k, x in raw.items():
        x *= ref / max(np.sqrt((x ** 2).mean()), 1e-9)
        p = np.abs(x).max()
        if p > 0.89: x *= 0.89 / p         # 헤드룸
        path = os.path.abspath(os.path.join(OUT, k + ".wav"))
        sf.write(path, x, SR, format="WAV", subtype="PCM_16")
        peaks[k] = (np.abs(x).max(), np.sqrt((x ** 2).mean()))
        print(f"  {k:6s} 피크 {peaks[k][0]:.3f}  RMS {peaks[k][1]:.4f}  ->  {path}")
