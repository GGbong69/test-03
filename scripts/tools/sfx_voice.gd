extends RefCounted
# ══════════════════════════════════════════════════════════
#  합성음의 목소리 — **한 곳에만 둔다**
#
#  game.gd 의 _fill_audio 가 내는 소리를 계산으로 되살린다. 쓰는 데가 둘이다.
#    sfx_bake.gd    파일을 이 크기에 맞춰 굽는다
#    probe_sfx.gd   구운 파일이 그 크기에 서 있는지 잰다
#  식이 두 군데 있으면 갈라진다 — 그러면 재는 자가 굽는 자를 못 잡는다.
#
#  왜 피크가 아니라 에너지인가. 두 소리의 속이 다르다:
#      합성음   사인 55% + 사각 45% · 감쇠 (1-t/d)²  → 단위피크 RMS 0.818
#      모달합   사인 여럿의 합 · 감쇠 exp(-t/tau)     → 단위피크 RMS 0.12~0.18
#  같은 피크로 맞추면 파일이 합성음보다 10dB 이상 **작게** 들린다. 그래서
#  파일이 물려받아야 하는 것은 피크가 아니라 앞 50ms 의 에너지다.
# ══════════════════════════════════════════════════════════

const SR := 44100.0
const WIN := 50.0          # 크기를 재는 창(ms). 붙박이라야 40ms 와 300ms 를
						   # 같은 자로 견준다


static func n(ms: float) -> int:
	return maxi(int(round(ms * 0.001 * SR)), 1)


# 표의 한 줄로 합성음을 낸다. 음 하나가 서면 앞엣것은 **끊긴다**
# (발진기가 하나다) — seq 의 각 음이 gap 에서 잘리는 것까지 같아야
# 에너지가 같아진다.
static func ref(e: Dictionary) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if e.is_empty():
		return out
	var freqs: Array = e.seq if e.has("seq") else [float(e.f)]
	var gap: float = float(e.get("gap", 0.0))
	var d: float = float(e.d)
	var a: float = float(e.a)
	var total: float = d if freqs.size() <= 1 else gap * float(freqs.size() - 1) + d
	out.resize(n(total * 1000.0))
	var ph := 0.0
	var dk := 1.0 / (d * SR)
	for k in freqs.size():
		var at := n(gap * 1000.0 * float(k)) if (gap > 0.0 and k > 0) else 0
		var span := n(d * 1000.0)
		if k < freqs.size() - 1 and gap > 0.0:
			span = mini(span, n(gap * 1000.0))
		var w := TAU * float(freqs[k]) / SR
		var env := 1.0
		for i in span:
			if at + i >= out.size():
				break
			var s := sin(ph)
			out[at + i] = (s * 0.55 + signf(s) * 0.45) * env * env * a
			ph = fmod(ph + w, TAU)
			env = maxf(env - dk, 0.0)
	return out


# 붙박이 창의 에너지. 나눗수가 창 전체이므로 짧은 소리는 창 안에서
# 정말로 에너지가 적게 나온다 — 그게 맞다.
static func rms(x: PackedFloat32Array, win_ms := WIN) -> float:
	var w := n(win_ms)
	var s := 0.0
	for i in mini(w, x.size()):
		s += x[i] * x[i]
	return sqrt(s / float(w))


# 16비트 PCM 을 -1..1 로 편다. probe 가 파일을 이 자로 재려면 필요하다.
static func pcm(st: AudioStreamWAV) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if st == null or st.format != AudioStreamWAV.FORMAT_16_BITS:
		return out
	var d := st.data
	var ch := 2 if st.stereo else 1
	var cnt := d.size() / (2 * ch)
	out.resize(cnt)
	for i in cnt:
		out[i] = float(d.decode_s16(i * 2 * ch)) / 32768.0
	return out
