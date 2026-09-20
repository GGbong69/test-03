extends SceneTree
# ══════════════════════════════════════════════════════════
#  소리를 짓는다
#     godot --headless --script scripts/tools/sfx_bake.gd
#     godot --headless --script scripts/tools/sfx_bake.gd -- egg_crack   ← 이름만
#     godot --headless --import          ← 구운 뒤 한 번. .import 를 세운다
#
#  res://sfx/<이름>.wav 를 여기서 **굽는다.** 빌려 온 팩이 아니라 이 게임의
#  물건이 부딪히는 소리라, 파일이 아니라 **수치가 원본**이다 — 아래 _build
#  한 곳을 고치고 다시 구우면 소리가 바뀐다.
#
#  ── 크기는 합성음이 정한다 ───────────────────────────────
#  파일은 표의 그 자리를 **대신 서는** 것이므로 그 자리의 크기를 물려받아야
#  한다. 그런데 피크를 표의 a 에 맞추면 안 된다 — 두 소리의 속이 다르다.
#      합성음   사인 55% + 사각 45% · 감쇠 (1-t/d)²  → 단위피크 RMS 0.818
#      모달합   사인 여럿의 합 · 감쇠 exp(-t/tau)     → 단위피크 RMS 0.12~0.18
#  같은 피크로 맞추면 파일이 합성음보다 10dB 이상 **작게** 들린다. 그래서
#  여기서는 합성음을 **그 자리에서 그대로 렌더해**(_ref — _fill_audio 의 식을
#  옮긴 것이다) 앞 50ms 에너지를 재고, 파일을 그 에너지에 맞춘다.
#  자리마다 수를 박는 대신 게임 제 목소리가 자가 된다.
#
#  한 번 깨진 것이 이것이다. 빌려 온 팩은 0dB 로 정규화돼 있어서 판 밖이
#  판 위보다 피크로 평균 16.5dB 크게 울렸다 — 자리마다 수치는 다 맞는데
#  게임 전체가 "안 맞는" 것이 그 하나에서 왔다.
#
#  ── 층을 쌓는 규약 ───────────────────────────────────────
#  층을 만들고 → 엔벨로프를 걸고 → **그 다음에** 피크 1.0 으로 정규화하고
#  → 층 무게를 곱해 얹는다(_lay 가 이 순서다). 정규화를 엔벨로프 앞에 두면
#  필터 뒤 잡음의 최대 샘플이 시드마다 딴 데 앉아서 실제 층 크기가 명목치
#  아래 무작위 값으로 떨어진다. 무게는 _lay 에 한 번만 준다 — 안쪽 진폭과
#  층 무게에 두 번 곱하면 층이 사라진다.
#
#  ── 연장 ────────────────────────────────────────────────
#  _mod  부분음을 감쇠시켜 더한다. 비가 배음이 아니면 금속, 배음이면 통.
#        고역 부분음이 먼저 죽는 것이 금속의 알맹이다.
#  _air  잡음을 밴드패스로 훑는다. 중심을 밀면 바람을 가르는 소리가 된다.
#        스윕은 **지수**다 — 귀가 주파수를 비로 듣는다.
#  _pap  고역 잡음을 잘게 끊는다. 종이·카드.
#  _one  부분음 하나. 음을 미끄러뜨릴 수 있다.
#  _comb 짧은 되울림 탭. 쇠가 울리는 자리에만.
#
#  잡음은 씨를 박은 LCG 로 낸다 — 같은 씨면 몇 번 구워도 같은 파일이 나온다.
#  (엔진 RNG 는 판 바뀌면 값이 달라질 수 있어서 안 쓴다.)
#
#  ── 임포트 ──────────────────────────────────────────────
#  .import 를 여기서 같이 쓴다. 두 값이 기본과 달라야 한다.
#    compress/mode=0  기본값 QOA 는 48ms 딸깍의 첫 순간을 뭉갠다
#    edit/trim=false  트림 문턱은 절대 -30dBFS(0.0316)다. 이 파일들은 피크가
#                     0.1 언저리라 그 문턱이 피크의 3분의 1이다 — 트림을 켜면
#                     어택 램프와 여운을 통째로 잘라 간다. 앞무음은 애초에
#                     0 으로 굽으므로 트림이 할 일도 없다.
# ══════════════════════════════════════════════════════════

const SR := 44100.0
const OUT := "res://sfx/"
const SHEET := "res://.godot/sfx_sheet.wav"   # 전부를 한 줄로 이은 것. 들어 보는 용
const WIN := 50.0                             # 크기를 재는 창(ms)

var SFX := {}          # game.gd 의 표
var cur := {}          # 지금 굽는 이름의 표 줄
var _rs := 0           # 잡음 씨


# ── 연장: 바탕 ────────────────────────────────────────────

func _seed(s: int) -> void:
	_rs = s & 0xFFFFFFFF


func _rnd() -> float:
	_rs = (_rs * 1664525 + 1013904223) & 0xFFFFFFFF
	return float(_rs) / 2147483648.0 - 1.0


func _n(ms: float) -> int:
	return maxi(int(round(ms * 0.001 * SR)), 1)


func _blank(n: int) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(n)
	return b


func _gain(x: PackedFloat32Array, g: float) -> PackedFloat32Array:
	for i in x.size():
		x[i] *= g
	return x


func _peak(x: PackedFloat32Array) -> float:
	var p := 0.0
	for v in x:
		p = maxf(p, absf(v))
	return p


func _unit(x: PackedFloat32Array) -> PackedFloat32Array:
	# 피크를 1.0 으로. **엔벨로프를 다 건 뒤에** 부른다.
	var p := _peak(x)
	return x if p <= 0.0 else _gain(x, 1.0 / p)


func _lay(dst: PackedFloat32Array, src: PackedFloat32Array, w: float,
		at_ms := 0.0) -> PackedFloat32Array:
	# 층 하나를 얹는다. 정규화 → 무게 → 자리. 무게는 여기서 한 번만 준다.
	_unit(src)
	_gain(src, w)
	var at := _n(at_ms) if at_ms > 0.0 else 0
	var need := at + src.size()
	if dst.size() < need:
		dst.resize(need)
	for i in src.size():
		dst[at + i] += src[i]
	return dst


# ── 연장: 엔벨로프 ────────────────────────────────────────

func _atk(x: PackedFloat32Array, ms: float) -> PackedFloat32Array:
	# 어택 램프. 손에 닿는 자리는 30ms 안에 서야 하므로 기본이 1~3ms 다.
	# 0 에서 바로 세우면 딸깍(DC 계단)이 끼므로 최소한 이만큼은 필요하다.
	var k := _n(ms)
	for i in mini(k, x.size()):
		x[i] *= float(i) / float(k)
	return x


func _dec(x: PackedFloat32Array, tau: float, hold_ms := 0.0,
		pow2 := false) -> PackedFloat32Array:
	# 지수 감쇠. hold_ms 까지는 1.0 로 버티고 그 뒤부터 굴린다 —
	# 버티는 구간이 없으면 "부풀었다 빠지는" 소리를 못 짓는다.
	var h := _n(hold_ms) if hold_ms > 0.0 else 0
	var dk := exp(-1.0 / (maxf(tau, 0.0005) * SR))
	var e := 1.0
	for i in x.size():
		if i >= h:
			x[i] *= (e * e) if pow2 else e
			e *= dk
	return x


func _fade(x: PackedFloat32Array, ms: float) -> PackedFloat32Array:
	# 끝을 0 으로 눕힌다. 잘린 끝이 딸깍으로 들리는 것을 막는다.
	var k := mini(_n(ms), x.size())
	for i in k:
		x[x.size() - 1 - i] *= float(i) / float(k)
	return x


# ── 연장: 필터 ────────────────────────────────────────────

func _bp(x: PackedFloat32Array, f0: float, f1: float, q: float,
		sweep_ms := 0.0) -> PackedFloat32Array:
	# 밴드패스(RBJ, 상시 피크게인). 중심을 f0 에서 f1 로 **지수**로 민다 —
	# 귀가 주파수를 비로 들으므로 선형 스윕은 앞머리만 훑고 지나간다.
	# sweep_ms 를 주면 거기서 f1 에 닿고 그 뒤로는 고정이다.
	var n := x.size()
	var span := float(_n(sweep_ms)) if sweep_ms > 0.0 else float(maxi(n - 1, 1))
	var rat := f1 / maxf(f0, 1.0)
	var z1 := 0.0
	var z2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in n:
		var t := minf(float(i) / span, 1.0)
		var fc := clampf(f0 * pow(rat, t), 20.0, SR * 0.45)
		var w := TAU * fc / SR
		var al := sin(w) / (2.0 * maxf(q, 0.05))
		var a0 := 1.0 + al
		var b0 := al / a0
		var a1 := -2.0 * cos(w) / a0
		var a2 := (1.0 - al) / a0
		var xi := x[i]
		var y := b0 * xi - b0 * z2 - a1 * y1 - a2 * y2
		z2 = z1
		z1 = xi
		y2 = y1
		y1 = y
		x[i] = y
	return x


func _lp(x: PackedFloat32Array, fc: float, poles := 1) -> PackedFloat32Array:
	# 원폴 로우패스를 몇 단. 유리 딸깍이 되지 않게 위를 덮는 데 쓴다.
	var a := exp(-TAU * fc / SR)
	for _p in maxi(poles, 1):
		var y := 0.0
		for i in x.size():
			y = x[i] * (1.0 - a) + y * a
			x[i] = y
	return x


func _hp(x: PackedFloat32Array, fc: float) -> PackedFloat32Array:
	var a := exp(-TAU * fc / SR)
	var y := 0.0
	var px := 0.0
	for i in x.size():
		y = a * (y + x[i] - px)
		px = x[i]
		x[i] = y
	return x


func _soft(x: PackedFloat32Array, k: float) -> PackedFloat32Array:
	# 살짝 밀어 넣는다. 피크는 안 올리고 속을 채운다.
	if k <= 0.0:
		return x
	var t := tanh(k)
	for i in x.size():
		x[i] = tanh(x[i] * k) / t
	return x


func _drive(x: PackedFloat32Array, k: float) -> PackedFloat32Array:
	# 정규화 전에 속을 채운다. 봉우리는 안 올리고 에너지만 올리므로
	# **크레스트가 내려간다** — 같은 에너지를 더 낮은 피크로 낸다.
	# tanh 는 입력 크기에 좌우되니 걸기 전에 1.0 으로 펴서 k 의 뜻을 못 박는다.
	return _soft(_unit(x), k)


func _comb(x: PackedFloat32Array, ms: float, fb: float,
		taps := 2) -> PackedFloat32Array:
	# 되울림 탭 몇 개. **되먹임이 아니라 탭**이라 사다리를 안 뒤집는다 —
	# 되먹임 콤은 지연에 걸린 음만 키워서 오르는 관계를 거꾸로 세운다.
	var dn := _n(ms)
	var src := x.duplicate()
	var g := fb
	for t in maxi(taps, 1):
		var at := dn * (t + 1)
		for i in src.size():
			if at + i < x.size():
				x[at + i] += src[i] * g
		g *= fb
	return x


# ── 연장: 재질 ────────────────────────────────────────────

func _mod(ms: float, base: float, parts: Array) -> PackedFloat32Array:
	# 부분음을 감쇠시켜 더한다. parts 는 [비, 진폭, 감쇠초] 줄들.
	# 비가 1:2.76:5.40:8.93 처럼 배음이 아니면 금속판, 1:2:3 이면 통이 된다.
	var n := _n(ms)
	var out := _blank(n)
	for p in parts:
		var f: float = base * float(p[0])
		if f >= SR * 0.45:
			continue                      # 귀 밖은 굽지 않는다
		var amp: float = float(p[1])
		var dk := exp(-1.0 / (maxf(float(p[2]), 0.0005) * SR))
		var w := TAU * f / SR
		var ph := 0.0
		var e := 1.0
		for i in n:
			out[i] += sin(ph) * amp * e
			ph = fmod(ph + w, TAU)
			e *= dk
	return out


func _one(ms: float, f0: float, f1: float, tau: float,
		atk_ms := 1.0) -> PackedFloat32Array:
	# 부분음 하나. f0 에서 f1 로 미끄러진다 — 다트가 멀어지는 소리에 쓴다.
	var n := _n(ms)
	var out := _blank(n)
	var dk := exp(-1.0 / (maxf(tau, 0.0005) * SR))
	var ph := 0.0
	var e := 1.0
	for i in n:
		var t := float(i) / float(maxi(n - 1, 1))
		out[i] = sin(ph) * e
		ph = fmod(ph + TAU * lerpf(f0, f1, t) / SR, TAU)
		e *= dk
	return _atk(out, atk_ms)


func _air(ms: float, f0: float, f1: float, q: float, seed: int,
		sweep_ms := 0.0) -> PackedFloat32Array:
	# 바람. 잡음을 중심이 움직이는 밴드패스로 훑는다.
	var n := _n(ms)
	var out := _blank(n)
	_seed(seed)
	for i in n:
		out[i] = _rnd()
	return _bp(out, f0, f1, q, sweep_ms)


func _pap(ms: float, fc: float, grain_ms: float, seed: int) -> PackedFloat32Array:
	# 종이. 고역 잡음을 잘게 끊어 결을 낸다.
	var n := _n(ms)
	var out := _blank(n)
	_seed(seed)
	var step := maxi(_n(grain_ms), 1)
	var g := 0.0
	for i in n:
		if i % step == 0:
			g = absf(_rnd()) * 0.7 + 0.3
		out[i] = _rnd() * g
	return _bp(out, fc, fc * 0.6, 1.2)


# ── 자: 합성음을 그 자리에서 렌더한다 ─────────────────────
#  식은 scripts/tools/sfx_voice.gd 에 **한 곳만** 둔다. probe_sfx 가 같은 식으로
#  재므로, 굽는 값과 재는 값이 갈라질 수가 없다.

const Voice = preload("res://scripts/tools/sfx_voice.gd")


func _ref(nm: String) -> PackedFloat32Array:
	return Voice.ref(SFX.get(nm, {}))


func _rms(x: PackedFloat32Array, win_ms := WIN) -> float:
	return Voice.rms(x, win_ms)


func _norm_rms(x: PackedFloat32Array, target: float) -> PackedFloat32Array:
	var r := _rms(x)
	if r <= 0.0:
		return x
	_gain(x, target / r)
	var p := _peak(x)
	if p > 0.90:
		_gain(x, 0.90 / p)      # 깎이는 것보다는 통째로 내린다
	return x


func _atk_ms(x: PackedFloat32Array) -> float:
	# 봉우리의 절반에 처음 닿는 데까지. probe_sfx 와 같은 자다.
	var p := _peak(x)
	if p <= 0.0:
		return -1.0
	for i in x.size():
		if absf(x[i]) >= p * 0.5:
			return float(i) / SR * 1000.0
	return -1.0


# ── 굽기 ──────────────────────────────────────────────────

func _save(nm: String, x: PackedFloat32Array) -> int:
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = int(SR)
	st.stereo = false
	var d := PackedByteArray()
	d.resize(x.size() * 2)
	for i in x.size():
		d.encode_s16(i * 2, int(round(clampf(x[i], -1.0, 1.0) * 32767.0)))
	st.data = d
	var err := st.save_to_wav(OUT + nm + ".wav")
	_import(nm)
	return err


func _import(nm: String) -> void:
	# .import 를 같이 세운다. uid 는 적지 않는다 — 고닷이 가져갈 때 채운다.
	var p := OUT + nm + ".wav.import"
	if FileAccess.file_exists(p):
		var old := FileAccess.get_file_as_string(p)
		if old.contains("compress/mode=0") and old.contains("edit/trim=false"):
			return
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null:
		return
	f.store_string("[remap]\n\nimporter=\"wav\"\ntype=\"AudioStreamWAV\"\n\n"
			+ "[deps]\n\nsource_file=\"res://sfx/%s.wav\"\n\n" % nm
			+ "[params]\n\nforce/8_bit=false\nforce/mono=false\n"
			+ "force/max_rate=false\nforce/max_rate_hz=44100\n"
			+ "edit/trim=false\nedit/normalize=false\nedit/loop_mode=0\n"
			+ "edit/loop_begin=0\nedit/loop_end=-1\ncompress/mode=0\n")
	f.close()


func _addat(dst: PackedFloat32Array, src: PackedFloat32Array,
		at_ms := 0.0) -> PackedFloat32Array:
	# 정규화 없이 그대로 얹는다. 부분음 다발은 서로의 진폭이 뜻을 가지므로
	# 층마다 1.0 으로 펴면 안 된다 — _lay 는 잡음층에만 쓴다.
	var at := _n(at_ms) if at_ms > 0.0 else 0
	var need := at + src.size()
	if dst.size() < need:
		dst.resize(need)
	for i in src.size():
		dst[at + i] += src[i]
	return dst


func _pt(ms: float, base: float, parts: Array,
		atk_ms := 1.0) -> PackedFloat32Array:
	# 부분음 다발 하나. [비, 진폭, 감쇠초] 줄들에 어택 하나.
	return _atk(_mod(ms, base, parts), atk_ms)


func _nz(ms: float, f0: float, f1: float, q: float, seed: int, taun: float,
		atk_ms := 0.3) -> PackedFloat32Array:
	# 잡음층 하나. 끝을 눕혀 둔다 — 감쇠 도중에 잘리면 그 계단이 틱으로 난다.
	var v := _air(ms, f0, f1, q, seed)
	_atk(v, atk_ms)
	_dec(v, taun)
	return _fade(v, minf(2.0, ms * 0.25))


# ══════════════════════════════════════════════════════════
#  표 — 이름마다 무엇이 무엇에 닿는 소리인가
#
#  크기는 여기서 안 정한다(_norm_rms 가 합성음에서 읽어 온다). 길이는 표의
#  d 와 seq·gap 이 정한 박자를 따른다 — 한 음이면 d 근처, 여러 음이면
#  gap*(n-1)+d 다. 여기서 정하는 것은 **재질과 관계**뿐이다.
# ══════════════════════════════════════════════════════════

func _build(nm: String) -> PackedFloat32Array:
	# 가족마다 한 함수. 빈 것이 오면 다음 가족에 묻는다.
	for f in [_b_throw(nm), _b_hit(nm), _b_settle(nm), _b_leg(nm),
			_b_shop(nm), _b_hand(nm), _b_menu(nm)]:
		if not f.is_empty():
			return f
	return PackedFloat32Array()


func _b_throw(nm: String) -> PackedFloat32Array:
	match nm:
		# ══ 던지기 ═══════════════════════════════════════
		#  코르크 판에 강철 다트 하나. 금속은 전부 판·막대 비율
		#  1 : 2.76 : 5.40 : 8.93 위에 얹고, 고역 부분음이 먼저 죽는다.
		#  공기는 밴드 중심을 **내리쓸어** 낸다(올리면 휘파람이 된다).
		"dart_pick":
			# 마른 코르크가 강철 촉을 놓아 준다. 임펄스가 없는 것이 「집는 손」이다
			var x := _pt(70.0, 262.0, [[1.0, 1.00, 0.00450],
					[2.76, 0.18, 0.00434], [5.40, 0.08, 0.00232]], 4.0)
			# 이탈 마찰 — 위에서 아래로 빠진다. aim_lock_first 와 갈리는 자리가 이 층이다
			_lay(x, _nz(30.0, 2600.0, 1300.0, 1.2, 1262, 0.00800, 2.0), 0.90)
			return _fade(x, 8.0)
		"aim_lock_first":
			# 멈춤쇠가 한 칸 가볍게 걸린다. 공명통이 없다 — 그 빈칸이 last 와의 차다
			var x := _pt(62.0, 300.0, [[1.0, 1.00, 0.00666],
					[2.76, 0.62, 0.00376], [5.40, 0.75, 0.00400],
					[8.93, 0.50, 0.00250]], 0.3)
			_lay(x, _nz(6.0, 3200.0, 3200.0, 0.9, 1300, 0.00160, 0.2), 0.85)
			return _fade(x, 6.0)
		"aim_lock_last":
			# 같은 멈춤쇠가 홈 바닥까지 앉는다. 기구를 안 바꾸고 무게만 얹는다 —
			# 200Hz 몸통(first 에 없는 층)과 9ms 되울림이 그 무게다
			var x := _pt(95.0, 400.0, [[1.0, 1.00, 0.00840],
					[2.76, 0.55, 0.00492], [5.40, 0.72, 0.00520],
					[8.93, 0.40, 0.00300], [0.5, 0.55, 0.00724]], 0.3)
			_lay(x, _nz(6.0, 2600.0, 2600.0, 0.9, 1400, 0.00072, 0.2), 0.30)
			_comb(x, 9.0, 0.18, 2)
			_drive(x, 0.25)
			return _fade(x, 8.0)
		"kick_shot":
			# 작은 쇠 다트가 바람을 짧게 긁고 판에 턱 박힌다. 한 동작이다
			var x := _blank(_n(105.0))
			_lay(x, _nz(30.0, 4200.0, 1500.0, 1.6, 1520, 0.00145, 3.0), 0.55)
			var th := _pt(83.0, 520.0, [[1.0, 1.00, 0.00579],
					[2.76, 0.20, 0.00174]], 1.0)
			_lay(th, _nz(14.0, 1900.0, 1900.0, 1.1, 1521, 0.00174), 0.60)
			_drive(th, 0.4)
			_lay(x, th, 1.0, 22.0)
			return _fade(x, 8.0)
		"dart_fly":
			# 제 크기 다트가 손을 떠나 바람을 가르며 멀어진다. 턱은 없다 —
			# 착탄음이 그 뒤에 온다. 리볼버에서는 이 소리가 안 난다(kick_shot 이 쓴다)
			var x := _blank(_n(150.0))
			var a1 := _air(150.0, 2400.0, 700.0, 2.2, 1522)
			_atk(a1, 25.0)
			_dec(a1, 0.00796, 70.0)
			_fade(a1, 12.0)
			_lay(x, a1, 1.00)
			var a2 := _air(130.0, 900.0, 420.0, 0.9, 1523)
			_atk(a2, 20.0)
			_dec(a2, 0.00796, 55.0)
			_fade(a2, 10.0)
			_lay(x, a2, 0.45, 20.0)
			_lay(x, _one(110.0, 520.0, 500.0, 0.01448, 20.0), 0.20, 40.0)
			return _fade(x, 12.0)

		_:
			return PackedFloat32Array()


func _b_hit(nm: String) -> PackedFloat32Array:
	match nm:
		# ══ 착탄 ═════════════════════════════════════════
		#  강철 팁이 재질을 가르고 **그 뒤에 같은 판이 운다.** 여섯 전부
		#  98Hz 판 모드(= 392/4) 위에 결(밴드패스 잡음, 중심이 아래로
		#  미끄러진다) + 접점(감쇠 사인 다발)을 얹은 한 물체의 소리다.
		#  등급이 오르는 것은 **접점 개수와 재질**로 적는다:
		#    miss 알맹이 없음 → single 쇠줄 없음 → double·triple 쇠줄 딸깍
		#    → bull 쇠줄이 사라지고 판이 제 배음렬로 운다(방사 쇠줄이
		#      물리적으로 거기서 끝난다 — 그 없음이 등급 신호다)
		"hit_miss":
			# 낮고 둔한 속 빈 판때기 노크. 알맹이도 이빨도 없이 뒤판만 운다
			var x := _blank(_n(220.0))
			_lay(x, _nz(18.0, 1700.0, 520.0, 0.9, 1501, 0.012), 0.45)
			_addat(x, _pt(215.0, 150.0, [[1.0, 1.00, 0.058],
					[2.76, 0.30, 0.022], [5.40, 0.10, 0.009]], 3.0), 2.0)
			_addat(x, _pt(220.0, 98.0, [[1.0, 0.40, 0.075],
					[2.755, 0.13, 0.026]], 4.0))
			_drive(x, 1.35)
			_lp(x, 6500.0)
			return _fade(x, 18.0)
		"hit_single":
			# 짧고 건조한 「툭」 — 섬유를 가르고 다발이 눌린다. 링이 없다.
			# 셋째 부분음을 뺀다: 한 런에 수백 번 나는 자리라 피로가 된다
			var x := _blank(_n(130.0))
			_lay(x, _nz(16.0, 3200.0, 950.0, 1.1, 1601, 0.010), 0.90)
			_addat(x, _pt(128.0, 160.0, [[1.0, 1.00, 0.030],
					[2.76, 0.22, 0.012]], 0.8), 1.5)
			_addat(x, _pt(130.0, 98.0, [[1.0, 0.30, 0.040],
					[2.755, 0.10, 0.016]], 1.5))
			_drive(x, 1.4)
			_lp(x, 6500.0)
			return _fade(x, 10.0)
		"hit_double":
			var x := _blank(_n(190.0))
			_hit_c(x, 0.0, 330.0, 1.00, 3301, [0.038, 0.015, 0.007], 3600.0, 1100.0)
			_hit_c(x, 75.0, 330.0, 0.88, 3302, [0.038, 0.015, 0.007], 3600.0, 1100.0)
			# 판은 한 번만 실린다 — 접점마다 다시 때리지 않는다.
			# 98Hz tau 0.055 가 75ms 의 바닥을 정한다(넘기면 둘째 상승이 깎인다)
			_addat(x, _pt(190.0, 98.0, [[1.0, 0.38, 0.055],
					[2.755, 0.12, 0.020]], 2.0))
			_drive(x, 1.6)
			_lp(x, 6500.0)
			return _fade(x, 16.0)
		"hit_triple":
			var x := _blank(_n(260.0))
			_hit_c(x, 0.0, 330.0, 1.00, 3301, [0.038, 0.015, 0.007], 3600.0, 1100.0)
			_hit_c(x, 70.0, 415.0, 0.90, 4151, [0.036, 0.014, 0.007], 3750.0, 1150.0)
			_hit_c(x, 140.0, 494.0, 0.82, 4941, [0.034, 0.013, 0.006], 3900.0, 1200.0)
			_addat(x, _pt(260.0, 98.0, [[1.0, 0.44, 0.062],
					[2.755, 0.14, 0.022]], 2.0))
			_drive(x, 1.6)
			_lp(x, 6500.0)
			return _fade(x, 14.0)
		"hit_bull_o":
			var x := _blank(_n(290.0))
			_hit_b(x, 0.0, 262.0, 1.00, 2621)
			_hit_b(x, 70.0, 392.0, 0.92, 3921)
			_hit_b(x, 140.0, 523.0, 0.86, 5231)
			# 529 = 98x5.40. 접점 3 의 523 과 6Hz 차라 한 박도 못 돌고 죽는다 —
			# 흔들림이 아니라 판이 같이 우는 두께로 들린다. 트리플에 없는 음색이다
			_addat(x, _pt(290.0, 98.0, [[1.0, 0.58, 0.095],
					[2.755, 0.24, 0.033], [5.40, 0.18, 0.100]], 2.5))
			_drive(x, 2.2)
			_lp(x, 6500.0)
			return _fade(x, 16.0)
		"hit_bull_i":
			var x := _blank(_n(370.0))
			_hit_b(x, 0.0, 262.0, 1.00, 2621)
			_hit_b(x, 70.0, 392.0, 0.92, 3921)
			_hit_b(x, 140.0, 523.0, 0.86, 5231)
			_hit_b(x, 210.0, 659.0, 0.80, 6591)
			# 접점은 안 건드리고 판만 늘린다 — 더 센 하중이 같은 판을 더 길게 울린다
			_addat(x, _pt(370.0, 98.0, [[1.0, 0.64, 0.115],
					[2.755, 0.26, 0.040], [5.40, 0.20, 0.120]], 2.5))
			# 불 안쪽은 이 게임의 잭팟이다 — 종을 아주 얕게 한 번 얹는다.
			# 쇠줄이 아니므로 「불에는 방사 쇠줄이 없다」는 등급 신호는 그대로다
			_lay(x, _bell(200.0, 659.0, 0.050), 0.14, 210.0)
			_drive(x, 2.2)
			_lp(x, 6500.0)
			return _fade(x, 24.0)
		"board_thud":
			# 등급 밑에 깔리는 접촉 한 번. 결이 눌리는 마른 딱(8ms)에
			# 판 몸통(131 = 392/3, 판·막대 비 위에 얹는다)과 걸이가 같이
			# 운다 — 걸이는 여섯이 쓰는 그 98Hz 판 모드 그대로다.
			# 위를 5.2kHz 로 덮어 등급 소리의 결(6.5kHz)과 자리를 안 다툰다.
			var x := _blank(_n(96.0))
			_lay(x, _nz(8.0, 2400.0, 1100.0, 1.0, 1607, 0.0055), 0.55)
			_addat(x, _pt(94.0, 131.0, [[1.0, 1.00, 0.026],
					[2.76, 0.24, 0.010], [5.40, 0.07, 0.004]], 1.0), 0.8)
			_addat(x, _pt(96.0, 98.0, [[1.0, 0.32, 0.036],
					[2.755, 0.10, 0.013]], 2.0))
			_drive(x, 1.3)
			_lp(x, 5200.0)
			return _fade(x, 10.0)
		"egg_crack":
			# 제목 판이 쪼개진다. 「콰득 지직」 — 판이 한 번에 갈라지는 두꺼운
			# 딱 몇이 30ms 안에 몰리고(콰득), 그 뒤로 결이 찢어지며 잔 딱이
			# 점점 성기고 여려진다(지직). 유리가 아니라 판이다: 속은 나무처럼
			# 빨리 죽는 비배음이고, 같은 98Hz 판 모드가 밑에서 둔하게 운다.
			# 위를 5kHz 로 덮어 반려된 유리 딸깍 대역을 비운다.
			var x := _blank(_n(260.0))
			# 콰득 — 갈라지는 딱. 넓은 대역 둘에 좁은 것 둘이 겹쳐 두껍다
			#  딱의 중심을 1~2kHz 에 둔다. 3kHz 위로 올리면 나무가 아니라
			#  유리·플라스틱 딸깍으로 들린다(스펙트럼 무게중심으로 쟀다)
			var crunch := [[0.0, 1500.0, 1.00], [3.5, 900.0, 0.85],
					[11.0, 2000.0, 0.55], [24.0, 1200.0, 0.50]]
			for i in crunch.size():
				var c: Array = crunch[i]
				_lay(x, _clk(40.0, 3.5, float(c[1]), float(c[1]) * 0.5, 0.7,
						0.012, 7101 + i, 0.2), float(c[2]), float(c[0]))
			# 나무 속 — 짧은 비배음. 금속보다 훨씬 빨리 죽는다
			_addat(x, _pt(140.0, 185.0, [[1.0, 1.30, 0.026], [2.31, 0.65, 0.013],
					[3.92, 0.32, 0.007]], 0.5), 1.0)
			# 판자가 속 빈 소리로 한 번 노크된다
			_addat(x, _pt(80.0, 620.0, [[1.0, 0.55, 0.012], [1.9, 0.28, 0.006]], 0.4), 2.0)
			# 같은 판이 둔하게 운다
			_addat(x, _pt(170.0, 98.0, [[1.0, 0.50, 0.050], [2.755, 0.16, 0.018]], 1.5))
			# 지직 — 결이 찢어진다. 흩는 값을 먼저 뽑는다: _clk 가 제 씨로
			# 잡음 상태를 덮으므로 도중에 뽑으면 딱마다 같은 값이 나온다
			_seed(7110)
			var us := []
			for i in 12:
				us.append((_rnd() + 1.0) * 0.5)
			var t := 30.0
			var g := 0.50
			for i in 12:
				var u: float = us[i]
				var fc: float = 1000.0 + 1800.0 * u
				_lay(x, _clk(16.0, 1.4, fc, fc * 0.6, 1.1, 0.0040, 7120 + i, 0.1), g, t)
				t += 5.0 + 10.0 * u + float(i) * 1.2
				g *= 0.85
			# 찢어지는 결 밑의 거친 잡음 — 짧게 깔고 빨리 뺀다
			_lay(x, _nz(160.0, 1800.0, 700.0, 0.9, 7130, 0.045, 5.0), 0.20, 20.0)
			_drive(x, 1.8)
			_lp(x, 5000.0)
			return _fade(x, 20.0)
		_:
			return PackedFloat32Array()


# 접점 유닛 C — 띠(double·triple)가 문자 그대로 같은 것을 쓴다.
# 쇠줄 비 1 : 1.509 는 배음이 아니라 쇠다. 상한을 4.33kHz 로 막아
# 반려된 9.7kHz 유리 딸깍 대역에 아무것도 두지 않는다.
func _hit_c(x: PackedFloat32Array, t0: float, f0: float, g: float, seed: int,
		tau3: Array, fc0: float, fc1: float) -> void:
	_lay(x, _nz(18.0, fc0, fc1, 1.3, seed, 0.011), 0.85 * g, t0)
	_addat(x, _pt(30.0, 2870.0, [[1.0, 0.55 * g, 0.008],
			[1.509, 0.30 * g, 0.004]], 0.3), t0 + 1.2)
	_addat(x, _pt(120.0, f0, [[1.0, 1.00 * g, float(tau3[0])],
			[2.76, 0.26 * g, float(tau3[1])],
			[5.40, 0.09 * g, float(tau3[2])]], 0.6), t0 + 1.2)


# 접점 유닛 B — 불 둘이 공유한다. 쇠줄 부분음이 **없고** 몸통이 배음렬이다:
# 방사 쇠줄이 불 반지름부터 없으므로 딸깍이 아니라 판이 제 배음렬로 운다.
func _hit_b(x: PackedFloat32Array, t0: float, f0: float, g: float,
		seed: int) -> void:
	_lay(x, _nz(22.0, 3600.0, 1100.0, 1.1, seed, 0.013), 0.82 * g, t0)
	_addat(x, _pt(140.0, f0, [[1.0, 1.00 * g, 0.034], [2.0, 0.42 * g, 0.024],
			[3.0, 0.14 * g, 0.011], [4.0, 0.10 * g, 0.009]], 0.8), t0 + 1.5)


func _init() -> void:
	var g = load("res://scripts/game.gd")
	SFX = g.SFX
	var names: Array = SFX.keys()
	#  -- 뒤에 이름을 주면 그것만 굽는다. 다른 파일은 손대지 않는다.
	var only := OS.get_cmdline_user_args()
	if not only.is_empty():
		names = names.filter(func(nm): return only.has(String(nm)))
	var done := 0
	var skip := []
	var made := {}          # 구운 것을 들고 있는다 — 이어 붙일 때 다시 읽지
							# 않는다. 방금 쓴 파일은 아직 임포트가 안 돼 있다

	print("%-16s %7s %7s %7s %8s %7s  %s"
			% ["이름", "길이", "기준", "피크", "RMS차", "어택", "말"])
	print("-".repeat(78))
	for nm in names:
		cur = SFX[nm]
		var x := _build(nm)
		if x.is_empty():
			skip.append(nm)
			continue
		var rf := _ref(nm)
		var want := _rms(rf)
		_norm_rms(x, want)
		var err := _save(nm, x)
		made[nm] = x
		var got := _rms(x)
		var say := ""
		if err != 0:
			say = "못 썼다(%d)" % err
		var pk := _peak(x)
		if pk >= 0.90:
			say = "피크가 천장에 붙었다 — 표의 a 를 보라"
		var db := 0.0
		if want > 0.0 and got > 0.0:
			db = 20.0 * (log(got / want) / log(10.0))
		print("%-16s %6.0fms %6.0fms %7.3f %+7.1fdB %5.1fms  %s"
				% [nm, float(x.size()) / SR * 1000.0,
				float(rf.size()) / SR * 1000.0, pk, db, _atk_ms(x), say])
		done += 1

	# 한 줄로 이어 둔다 — 게임을 켜지 않고 쭉 들어 보는 자리다.
	# 표 순서 그대로라 가족끼리 붙어서 견줘 들린다.
	var sheet := PackedFloat32Array()
	for nm in names:
		if not made.has(nm):
			continue
		_addat(sheet, made[nm], float(sheet.size()) / SR * 1000.0 + 260.0)
	var sv := AudioStreamWAV.new()
	sv.format = AudioStreamWAV.FORMAT_16_BITS
	sv.mix_rate = int(SR)
	sv.stereo = false
	var sd := PackedByteArray()
	sd.resize(sheet.size() * 2)
	for i in sheet.size():
		sd.encode_s16(i * 2, int(round(clampf(sheet[i], -1.0, 1.0) * 32767.0)))
	sv.data = sd
	sv.save_to_wav(SHEET)

	print("")
	print("이어 둔 것 %s — %.1f초" % [SHEET, float(sheet.size()) / SR])
	print("구운 것 %d · 아직 안 지은 것 %d" % [done, skip.size()])
	if not skip.is_empty():
		print("  " + " ".join(skip))
	quit()


# ── 연장: 정산이 쓰는 것 ──────────────────────────────────

# 놋쇠 혀 — 사다리 셋과 total · target_hit 이 **한 비율표를 공유한다.**
# [비, 진폭, 감쇠배]. 고역이 먼저 죽는다.
const TONGUE := [[1.0, 1.00, 1.0], [2.76, 0.45, 0.5238], [5.40, 0.22, 0.2667],
		[8.93, 0.10, 0.1714], [13.34, 0.05, 0.1143]]

# 동전 원판 — settle_bal 전용. 감쇠가 d1/r 이라 고역이 저역의 0.38 배까지 짧다.
const COIN := [[1.0, 1.00], [1.59, 0.62], [2.13, 0.42], [2.30, 0.30],
		[2.65, 0.20]]


func _d6(d: float) -> float:
	# 정산 가족의 d 는 **-60dB 까지의 초**다. tau 로 바꿔 쓴다.
	return d / 6.908


func _tongue(f0: float, d1: float, top: float, swap3 := 0.0,
		g := 1.0) -> Array:
	# 혀의 부분음 줄들. top 이상으로 올라가는 부분음은 **넣지 않는다.**
	#
	# top 이 자리마다 다른 이유 — settle_step · pierce · item 은 _sfx(name, f)
	# 로 pitch_scale = f/392 를 받아 파일 **전체**가 같은 비로 리샘플된다.
	# 사다리 천장이 3.78배이므로 렌더 시점의 1250Hz 가 재생 시점의 4724Hz 다.
	# 안 받는 자리(total · target_hit)는 렌더 값이 그대로 나므로 3400 이다.
	var out := []
	for p in TONGUE:
		var r: float = float(p[0])
		if swap3 > 0.0 and absf(r - 5.40) < 0.01:
			r = swap3          # 1 : 2.76 : 3.15 도 비배음이라 금속이 산다
		if f0 * r >= top:
			continue
		out.append([r, float(p[1]) * g, _d6(d1 * float(p[2]))])
	return out


func _coin(d1: float, g := 1.0) -> Array:
	var out := []
	for p in COIN:
		var r: float = float(p[0])
		out.append([r, float(p[1]) * g, _d6(d1 / r)])
	return out


func _lpn(ms: float, fc: float, d: float, seed: int,
		atk_ms := 0.3) -> PackedFloat32Array:
	# 원폴 저역통과 잡음. 쿵 — 판이 바닥을 치는 소리.
	var n := _n(ms)
	var out := _blank(n)
	_seed(seed)
	var a := 1.0 - exp(-TAU * fc / SR)
	var y := 0.0
	for i in n:
		y += a * (_rnd() - y)
		out[i] = y
	_atk(out, atk_ms)
	_dec(out, _d6(d))
	return _fade(out, minf(2.0, ms * 0.25))


func _ring(x: PackedFloat32Array, f: float, depth: float) -> PackedFloat32Array:
	# 링모듈레이션. 측대역이 앞의 두 동전 음으로 떨어지게 f 를 고른다.
	var ph := 0.0
	for i in x.size():
		x[i] *= (1.0 - depth) + depth * sin(ph)
		ph = fmod(ph + TAU * f / SR, TAU)
	return x


func _fbd(x: PackedFloat32Array, ms: float, g: float,
		at_ms := 0.0) -> PackedFloat32Array:
	# 되먹임 딜레이. 제자리 재귀라 꼬리가 저절로 여러 탭이 된다 —
	# 판이 열린 듯 울리는 자리에만 쓴다(사다리 위에 걸면 음마다 이득이
	# 달라져 오르는 관계가 뒤집힌다 — 판과런 가족에서 그래서 뺐다).
	var dn := _n(ms)
	var st := maxi(_n(at_ms) if at_ms > 0.0 else 0, dn)
	for i in range(st, x.size()):
		x[i] += g * x[i - dn]
	return x


func _brst(ms: float, burst_ms: float, f0: float, f1: float, q: float,
		seed: int, atk_ms := 0.3) -> PackedFloat32Array:
	# 버스트는 짧게 넣고 **버퍼는 길게** 둔다 — 높은 Q 의 자연 감쇠
	# tau = Q/(pi*f) 가 버스트 뒤에 남는 것이 재질이다. 잘라 내면 색이 없다.
	# q 가 0 이하면 밴드패스 대신 원폴 저역통과다(접촉음 — 색이 없는 톡).
	var n := _n(ms)
	var out := _blank(n)
	_seed(seed)
	var b := mini(_n(burst_ms), n)
	for i in b:
		out[i] = _rnd()
	_atk(out, atk_ms)
	if q <= 0.0:
		_lp(out, f0)
	else:
		_bp(out, f0, f1, q)
	return _fade(out, minf(2.0, ms * 0.2))


func _lin(x: PackedFloat32Array, from_ms: float) -> PackedFloat32Array:
	# from_ms 에서 끝까지 1 에서 0 으로 곧게 내린다. 미끄러지는 종이의 봉투다.
	var s := _n(from_ms)
	var n := x.size()
	for i in range(mini(s, n), n):
		x[i] *= 1.0 - float(i - s) / float(maxi(n - s, 1))
	return x


func _slide(ms: float, fcA: float, fcB: float, q: float, seed: int,
		atk_ms: float, hold_ms: float, depth: float) -> PackedFloat32Array:
	# 종이·판지가 미끄러진다. 대역을 아래로 밀고, 두 번째 잡음을 220Hz 로
	# 눌러 그것으로 진폭을 흔든다 — 그 흔들림이 결이다.
	var v := _air(ms, fcA, fcB, q, seed)
	var a := 1.0 - exp(-TAU * 220.0 / SR)
	var y := 0.0
	_seed(seed + 7)
	for i in v.size():
		y += a * (_rnd() - y)
		v[i] *= (1.0 - depth) + depth * clampf(y * 3.0, -1.0, 1.0)
	_atk(v, atk_ms)
	return _lin(v, atk_ms + hold_ms)


func _b_settle(nm: String) -> PackedFloat32Array:
	match nm:
		# ══ 정산 ═════════════════════════════════════════
		#  코르크 판에 박힌 **놋쇠 혀 하나.** 사다리 셋은 그것을 392Hz 에서
		#  세 가지 두께로 걸고, total 은 같은 혀를 한 옥타브 아래에서 통째로
		#  치고, target_hit 은 그 타격을 네 번 겹쳐 열고, miss 는 같은 자리에서
		#  울림 없이 죽고, bal 만 그 위에 떨어지는 동전 두 장이다.
		#
		#  셋(step · pierce · item)은 _sfx(name, f) 로 pitch 를 받는다 —
		#  파일 전체가 f/392 배로 리샘플되고 사다리 천장이 3.78배다.
		#  그래서 이 셋만 부분음 상한이 1250Hz 다(재생 시점 4724Hz).
		"settle_step":
			# 혀가 한 칸에 걸린다. 사다리의 기본 걸음이다
			var x := _pt(108.0, 392.0, _tongue(392.0, 0.100, 1250.0, 3.15), 0.5)
			_lay(x, _nz(2.0, 1400.0, 1400.0, 2.0, 3921, _d6(0.004), 0.2), 0.55)
			_drive(x, 2.2)
			return _fade(x, 10.0)
		"settle_pierce":
			# 촉이 걸리지 않고 판을 뚫고 지나간다. 중심이 **올라가는** 것이
			# 「빠져나갔다」다 — 다른 자리의 잡음은 다 내려간다
			var x := _blank(_n(125.0))
			_lay(x, _nz(11.0, 1100.0, 1900.0, 1.6, 3922, _d6(0.016)), 0.60)
			_addat(x, _pt(115.0, 392.0,
					_tongue(392.0, 0.115, 1250.0, 3.15), 0.5), 10.0)
			_drive(x, 2.2)
			return _fade(x, 12.0)
		"settle_item":
			# 칩이 펠트에 엎어진다. 칩이 2ms 먼저 서고 펠트가 뒤를 받는다.
			# 테두리 대역을 1200 으로 낮췄다 — 이 자리는 pitch 를 x3.78 까지
			# 미는 자리라 2600 을 쓰면 9.8kHz 로 올라가 유리 딸깍이 된다
			var x := _pt(125.0, 392.0, _tongue(392.0, 0.110, 1250.0, 3.15), 0.5)
			_lay(x, _chip(40.0, 392.0, 0.0050, 3933, 0.45, 1.0, 1200.0), 0.36)
			_lay(x, _nz(2.0, 1400.0, 1400.0, 2.0, 3923, _d6(0.004), 0.2), 0.45)
			_addat(x, _pt(120.0, 130.0, [[1.0, 0.85, _d6(0.030)],
					[2.0, 0.22, _d6(0.018)]], 1.0), 2.0)
			_drive(x, 2.2)
			return _fade(x, 12.0)
		"settle_miss":
			# 꽂히지 못하고 아무 데도 안 걸린다. **부분음이 없는 것이 내용이다** —
			# 어택도 둔해서(1.5ms) 촉이 안 박힌 것이 첫 순간에 이미 들린다
			var x := _pt(240.0, 180.0, [[1.0, 1.00, _d6(0.200)]], 1.5)
			_lay(x, _lpn(15.0, 300.0, 0.018, 1801), 0.50)
			return _fade(x, 24.0)
		"settle_bal":
			# 큰 동전과 작은 동전이 떨어져 한 값에서 멎는다. 262 와 523 의
			# 산술 평균이 392.5 라 셋째 타가 392 에서 멎는다 — 표의 seq 가
			# 적어 둔 셈이 그대로 소리다
			var x := _blank(_n(340.0))
			_addat(x, _pt(180.0, 262.0, _coin(0.110), 0.4))
			_addat(x, _pt(180.0, 523.0, _coin(0.110), 0.4), 70.0)
			var t3 := _pt(200.0, 392.0, _coin(0.200), 0.4)
			# 131 = 262/2 — 측대역이 정확히 261 과 523 이라 앞의 두 동전이
			# 셋째 타 **안에서** 들린다. 깊이 0.15 를 넘기면 뜻이 기운다
			_ring(t3, 131.0, 0.15)
			_fbd(t3, 26.0, 0.35)
			_addat(x, t3, 140.0)
			# 두 동전이 떨어지는 곳은 금속 접시다 — 그 바닥이 셋을 묶는다
			_lay(x, _tray(300.0, 196.0, 0.055), 0.26, 30.0)
			_drive(x, 3.2)
			return _fade(x, 30.0)
		"settle_total":
			# 저울판이 바닥을 친다 — 셈이 닫힌다. 같은 혀를 **한 옥타브 아래**
			# 에서 치므로 step 에서 탈락했던 8.93·13.34 배가 여기서 살아난다.
			# 악기를 바꾸지 않고 f0 만 절반으로 둔 것이 「더 큰 개체」다
			var x := _blank(_n(420.0))
			_lay(x, _lpn(30.0, 200.0, 0.030, 1961), 0.90)
			_addat(x, _pt(400.0, 196.0, _tongue(196.0, 0.340, 3400.0), 0.5), 8.0)
			_addat(x, _pt(300.0, 196.0, [[1.0, 0.30, _d6(0.070)],
					[2.0, 0.18, _d6(0.050)], [3.0, 0.10, _d6(0.035)]], 1.0), 8.0)
			# 셈이 닫히면 값이 치러진다 — 동전이 접시로 쏟아지고 트레이가
			# 그 아래에 깔려 낱개를 하나로 묶는다
			_lay(x, _tray(380.0, 262.0, 0.075), 0.40, 20.0)
			_pour(x, 30.0, 250.0, 9, 784.0, 5.0, 0.055, 19601, 0.32)
			_drive(x, 2.2)
			return _fade(x, 40.0)
		"target_hit":
			# 같은 판을 네 번 쳐서 걸쇠가 풀린다. 네 음이 겹쳐 화음이 되는
			# 것이 「열렸다」다. 첫 음 392 는 사다리 바닥이고 마지막 784 는
			# 그 옥타브 위 — 이 두 값은 못 바꾼다.
			# 쿵을 여기서 따로 놓는다: 이 소리가 나면 settle_total 은 **안 난다**
			# (한 if/else 의 두 갈래다). 그 자리를 비워 두면 셈이 안 닫힌다
			var x := _blank(_n(720.0))
			_lay(x, _lpn(34.0, 200.0, 0.034, 1962), 1.00)
			_addat(x, _pt(120.0, 196.0, [[1.0, 0.30, _d6(0.060)]], 1.0))
			_addat(x, _pt(300.0, 392.0, _tongue(392.0, 0.260, 3400.0, 0.0, 1.00), 0.5))
			_addat(x, _pt(300.0, 523.0, _tongue(523.0, 0.260, 3400.0, 0.0, 0.94), 0.5), 80.0)
			_addat(x, _pt(300.0, 659.0, _tongue(659.0, 0.260, 3400.0, 0.0, 0.88), 0.5), 160.0)
			_addat(x, _pt(300.0, 784.0, _tongue(784.0, 0.260, 3400.0, 0.0, 0.82), 0.5), 240.0)
			_fbd(x, 48.0, 0.42, 240.0)
			# 걸쇠가 풀리는 자리 — 네 타를 종으로 한 번 더 적고, 그 뒤로
			# 동전이 쏟아진다. 이 게임에서 가장 큰 지불이다
			_lay(x, _bell(420.0, 392.0, 0.100), 0.28)
			_lay(x, _bell(300.0, 784.0, 0.066), 0.20, 240.0)
			_lay(x, _tray(420.0, 262.0, 0.080), 0.28, 280.0)
			_pour(x, 300.0, 340.0, 12, 880.0, 6.0, 0.050, 19602, 0.28)
			_drive(x, 2.2)
			return _fade(x, 60.0)
		_:
			return PackedFloat32Array()


# 바 모달비(금속) — 판과런의 금고쪽 넷이 공유한다. 부분음이 높을수록
# tau 가 짧다. 8.93 배는 **금이 갔다**는 표식이라 save_life 만 쓴다.
func _bar(f: float, amps: Array, taus: Array) -> Array:
	var rs := [1.0, 2.76, 5.40, 8.93]
	var out := []
	for k in amps.size():
		out.append([rs[k], float(amps[k]), float(taus[k])])
	return out


func _b_leg(nm: String) -> PackedFloat32Array:
	match nm:
		# ══ 판과 런 ══════════════════════════════════════
		#  금고쪽 넷(leg_clear · save_life · run_win · run_lose)은 **바 하나**
		#  를 때린다 — 모달비 1 : 2.76 : 5.40 : 8.93. 카드쪽 넷(leg_open ·
		#  leg_go · stage_open · stage_pick)은 금속이 0 이고 같은 종이 키트다.
		#  등급·짝은 감쇠초 · 부분음 개수 · 반음 차로만 갈린다.
		#
		#  콤(되먹임 딜레이)은 넷 다에서 **뺐다.** 지연에 걸린 음만 이득이
		#  올라가서 262-330-392-523-659 오르는 사다리를 거꾸로 세운다
		#  (573샘플 콤의 실제 응답이 262 에서 -1.4dB, 392 에서 +1.5dB 였다).
		#  금속 울림은 「부분음이 높을수록 tau 가 짧다」가 이미 낸다.
		#
		#  ── 동전이 부서진다 (2026-09-19) ─────────────────
		#  판 끝 파괴는 **판 밖**이다(_draw_clear 머리말이 이미 정했다 —
		#  「릴 굴림과 칩 소리는 판 밖의 어휘라 여기서는 써도 된다」).
		#  뼈대는 shop_smash 다섯 층 그대로다 — ① 접촉 0ms → ② 파열
		#  +12ms → ③ 몸통 +10ms → ④ 꼬리 → ⑤ 밑. **재질층은 ②③④,
		#  공통층은 ①⑤** 라 재질을 갈 때 가운데만 바뀌고, 그래서 여섯
		#  갈래가 한 소리 가족으로 남는다.
		#
		#  ⚠ **상한 6kHz 를 지킨다.** 9.7kHz 유리 딸깍 대역은 반려당한
		#  자리라 비워 둔다(SFX 표 머리말이 못 박았다). 유리는 대역이
		#  아니라 **밀도 · 비조화 비 · 빠른 감쇠**로 낸다 — 부분음이
		#  촘촘하고 비조화이고 전부 빨리 꺼지면 6kHz 아래에서도 유리다.
		"coin_break":
			#  기본 · 150ms. shop_smash 를 동전 하나 크기로 줄인 것이다.
			#  파열이 셋이 아니라 **둘**이고 몸통이 120 의 절반이고 꼬리가
			#  일곱이 아니라 **다섯**이다 — 매물 하나가 아니라 38px 동전
			#  하나가 부서지는 소리라 몸이 그만큼 작다.
			var x := _blank(_n(150.0))
			_lay(x, _chip(22.0, 294.0, 0.0042, 2401, 0.50), 1.00)
			var cb := [[11.0, 1420.0, 0.92], [16.0, 900.0, 0.70]]
			for i in cb.size():
				var c: Array = cb[i]
				_lay(x, _clk(28.0, 2.6, float(c[1]), float(c[1]) * 0.5, 0.7,
						0.009, 2410 + i, 0.2), float(c[2]), float(c[0]))
			_addat(x, _pt(62.0, 294.0, _rat(DISC, [1.00, 0.40, 0.17, 0.07],
					[0.016, 0.010, 0.007, 0.005]), 0.4), 9.0)
			#  흩는 값을 **먼저** 뽑는다 — _clk/_chip 이 제 씨로 잡음
			#  상태를 덮으므로 도중에 뽑으면 딱마다 같은 값이 난다
			#  (egg_crack · shop_smash 가 이미 밟은 자리)
			_seed(2430)
			var us := []
			for i in 5:
				us.append((_rnd() + 1.0) * 0.5)
			var t := 24.0
			var g := 0.42
			for i in 5:
				var u: float = us[i]
				_lay(x, _chip(13.0, 294.0 * pow(2.0, u * 7.0 / 12.0), 0.0026,
						2440 + i, 0.32), g, t)
				t += 6.0 + 10.0 * u + float(i) * 1.3
				g *= 0.84
			_lay(x, _nz(80.0, 1500.0, 620.0, 1.0, 2450, 0.026, 3.0), 0.16, 13.0)
			_drive(x, 1.5)
			_lp(x, 6000.0)
			return _fade(x, 12.0)
		"coin_break_glass":
			#  유리 · 130ms. 기본보다 **짧고 촘촘하다.** 접촉 감쇠가 절반
			#  (0.0022)이고 테두리가 0.72 로 날이 서 있다. ⑤ 밑이 **없다** —
			#  유리는 바닥이 안 남는다. 그 부재가 「깨졌다」의 절반이다.
			var x := _blank(_n(130.0))
			_lay(x, _chip(14.0, 392.0, 0.0022, 2461, 0.72), 1.00)
			#  파열 **넷**, 전부 6k 아래. 대역을 올리는 대신 개수를 늘린다.
			var cg := [[8.0, 2400.0, 1.00], [12.0, 3350.0, 0.78],
					[17.0, 1750.0, 0.62], [23.0, 4400.0, 0.44]]
			for i in cg.size():
				var c: Array = cg[i]
				_lay(x, _clk(20.0, 1.8, float(c[1]), float(c[1]) * 0.5, 0.9,
						0.0055, 2470 + i, 0.2), float(c[2]), float(c[0]))
			#  몸통 — DISC(1:2.08:3.41:5.06) 대신 **조밀한 비조화 비**다.
			#  이 한 줄이 「얇은 원판」과 「유리」를 가른다.
			_addat(x, _pt(46.0, 392.0, [[1.00, 0.70, 0.010],
					[2.76, 0.52, 0.0075], [4.11, 0.34, 0.0055],
					[5.43, 0.20, 0.0040]], 0.3), 7.0)
			_seed(2480)
			var ug := []
			for i in 9:
				ug.append((_rnd() + 1.0) * 0.5)
			var t2 := 18.0
			var g2 := 0.40
			for i in 9:
				var u: float = ug[i]
				_lay(x, _chip(9.0, 392.0 * pow(2.0, u * 9.0 / 12.0), 0.0013,
						2490 + i, 0.40), g2, t2)
				t2 += 5.0 + 7.0 * u + float(i) * 0.8
				g2 *= 0.88
			_drive(x, 1.5)
			_lp(x, 6000.0)
			return _fade(x, 10.0)
		"coin_break_wax":
			#  밀랍 · 260ms. **② 파열 층이 아예 없다** — 밀랍은 안 터진다.
			#  그 한 칸의 부재가 「녹는다」의 전부다. 꼬리 대신 느린 하강
			#  글라이드가 서고, _lp 2600 이라 고역이 없다.
			var x := _blank(_n(260.0))
			_lay(x, _chip(30.0, 165.0, 0.0090, 2501, 0.20), 1.00)
			_addat(x, _pt(140.0, 165.0, [[1.00, 0.90, 0.055],
					[1.52, 0.34, 0.036]], 0.8), 8.0)
			var gl := _air(210.0, 880.0, 360.0, 0.8, 2510)
			_atk(gl, 22.0)
			_dec(gl, 0.075, 30.0)
			_lay(x, _fade(gl, 20.0), 0.26, 10.0)
			_lay(x, _nz(180.0, 900.0, 300.0, 1.0, 2520, 0.070, 6.0), 0.22, 14.0)
			_drive(x, 1.3)
			_lp(x, 2600.0)
			return _fade(x, 22.0)
		"coin_safe":
			#  **부서지는 층이 빠진 소리.** 70ms. 파괴음과 같은 가족인데
			#  ② 파열도 ⑤ 밑도 없다 — 그 부재가 귀로 듣는 「안 부서졌다」다.
			#  판 밖 어휘의 가장 작은 것: 동전 하나가 트레이 펠트에 얹히는 톡.
			var x := _blank(_n(70.0))
			_lay(x, _chip(20.0, 523.0, 0.0038, 2531, 0.42), 1.00)
			_lay(x, _nz(22.0, 1900.0, 800.0, 1.2, 2535, 0.010, 3.0), 0.09, 4.0)
			_drive(x, 1.2)
			_lp(x, 6000.0)
			return _fade(x, 8.0)
		"leg_clear":
			# 바를 392-494-587 로 올려 때리고 첫 타 아래에 나무 통이 받친다.
			# 8.93 배가 없다 — 금이 안 간 몸통이다
			var x := _blank(_n(360.0))
			# 바를 때리던 것을 **종**으로 갈았다 — 판을 깨는 것은 이 게임에서
			# 값을 받는 자리다. 사다리 392-494-587 은 그대로다
			_addat(x, _bell(300.0, 392.0, 0.062, 1.00, 1.0))
			_addat(x, _bell(280.0, 494.0, 0.058, 0.92, 1.0), 90.0)
			_addat(x, _bell(180.0, 587.0, 0.052, 0.84, 1.0), 180.0)
			_lay(x, _pt(200.0, 131.0, [[1.0, 0.90, 0.045]], 3.0), 0.45)
			_drive(x, 1.8)
			return _fade(x, 45.0)
		"save_life":
			# 금속 토큰이 쪼개지고(554) 남은 조각이 울리며 올라간다(739).
			# 뿌리를 leg_clear 의 392 에서 트라이톤 위로 옮겼다 — 이 둘은
			# **같은 프레임에 난다**(목숨이 판을 살릴 때마다). 392 로 두면
			# 부분음이 셋 다 겹쳐서 한 소리로 뭉갠다
			var x := _blank(_n(250.0))
			var cr := _nz(30.0, 1500.0, 900.0, 1.4, 1102, 0.009, 0.6)
			_drive(cr, 2.2)
			_lay(x, cr, 0.85)
			# 8.93 배(4950Hz)는 상한 밖이라 5.40 배(2994Hz)가 「금이 갔다」를 맡는다
			_addat(x, _pt(120.0, 554.4, [[1.0, 1.00, 0.036],
					[2.76, 0.70, 0.015], [5.40, 0.42, 0.011]], 1.0))
			# 남은 조각이 종처럼 울리며 올라간다 — 살아남은 것이 값이다
			_addat(x, _bell(160.0, 739.2, 0.088, 1.00, 2.0), 90.0)
			_drive(x, 2.0)
			return _fade(x, 35.0)
		"run_win":
			# 다섯 장을 262-330-392-523-659 로 올려 때리고 마지막 고음만
			# 길게 남는다. **첫 타가 가장 크다** — 끝에서 부풀면 누른 순간이
			# 아니라 620ms 뒤가 봉우리가 되고 그건 손과 따로 논다
			var x := _blank(_n(620.0))
			# **잭팟이다.** 다섯 장을 종으로 올려 때린다. 첫 타가 가장 크다 —
			# 끝에서 부풀면 누른 순간이 아니라 620ms 뒤가 봉우리가 된다
			_addat(x, _bell(400.0, 262.0, 0.095, 1.00, 1.5))
			_addat(x, _bell(360.0, 330.0, 0.090, 0.88, 1.5), 100.0)
			_addat(x, _bell(340.0, 392.0, 0.092, 0.84, 1.5), 200.0)
			_addat(x, _bell(320.0, 523.0, 0.095, 0.80, 1.5), 300.0)
			# 여기서만 규칙을 뒤집는다 — 고역 tau 가 앞 넷보다 길어서 마지막
			# 음만 남는다. 대신 진폭을 낮춰 첫 타에서 봉우리를 안 빼앗는다
			# 여기서만 규칙을 뒤집는다 — 감쇠가 앞 넷보다 2.6배 길어서
			# 마지막 음만 남는다. 대신 진폭을 낮춰 첫 타의 봉우리를 안 빼앗는다
			_addat(x, _bell(220.0, 659.0, 0.210, 0.55, 1.5), 400.0)
			var wd := _pt(220.0, 131.0, [[1.0, 0.85, 0.060],
					[2.0, 0.30, 0.028], [3.0, 0.10, 0.014]], 1.5)
			_lay(x, wd, 0.80)
			# 87Hz — run_lose 와 공유하는 몸통이다(그 파일의 저역 알맹이가 80~92Hz)
			_addat(x, _pt(400.0, 87.3, [[1.0, 0.16, 0.090]], 4.0))
			# 종 아래에서 동전이 쏟아진다. 트레이가 그 낱개를 묶는다
			_lay(x, _tray(560.0, 262.0, 0.090), 0.30, 60.0)
			_pour(x, 90.0, 460.0, 16, 880.0, 7.0, 0.050, 19603, 0.26)
			_drive(x, 1.8)
			return _fade(x, 90.0)
		"run_lose":
			# 낮은 금속 셋이 300-240-180 으로 **피치를 흘리며** 떨어지고
			# 공기가 빠진 뒤 90Hz 만 남는다. run_win 의 거울이다 —
			# 같은 바, 같은 저역 받침, 방향만 반대
			var x := _blank(_n(500.0))
			_addat(x, _pt(340.0, 300.0, _bar(300.0, [1.00, 0.55, 0.24],
					[0.110, 0.045, 0.022]), 1.5))
			_addat(x, _pt(300.0, 240.0, _bar(240.0, [1.00, 0.50, 0.20],
					[0.115, 0.048, 0.024]), 1.5), 130.0)
			_addat(x, _pt(240.0, 180.0, _bar(180.0, [1.00, 0.42, 0.15],
					[0.150, 0.055, 0.026]), 1.5), 260.0)
			_addat(x, _pt(300.0, 150.0, [[1.0, 0.35, 0.130]], 2.0))
			_addat(x, _pt(300.0, 120.0, [[1.0, 0.35, 0.140]], 2.0), 130.0)
			# 마지막 90Hz 가 서랍 닫힘이다
			_addat(x, _pt(240.0, 90.0, [[1.0, 0.40, 0.190]], 3.0), 260.0)
			# 이긴 쪽이 종이면 진 쪽은 **막힌 종**이다 — tierce 와 hum 만 남고
			# 곧 죽는다. 같은 종이 안 울리는 것이 거울이다
			_lay(x, _pt(220.0, 300.0, [[1.2, 0.60, 0.030],
					[0.5, 0.35, 0.060]], 1.5), 0.30)
			var ar := _air(460.0, 1800.0, 260.0, 0.9, 1104)
			_atk(ar, 6.0)
			_lin(ar, 6.0)
			_lay(x, ar, 0.50)
			_drive(x, 1.6)
			return _fade(x, 60.0)
		"leg_open":
			# 카드지가 미끄러져 서고 펠트에 두 번 닿는다(392→523).
			# 금속 성분 0 — 여기 넷은 같은 종이 키트다
			var x := _blank(_n(190.0))
			_lay(x, _slide(95.0, 5200.0, 1500.0, 1.1, 1105, 4.0, 12.0, 0.35), 0.55)
			_leg_tap(x, 0.0, 392.0, 0.50, 2600.0, 0.45, 14.0, 0.20, 0.038, 1115)
			_leg_tap(x, 70.0, 523.0, 0.50, 2600.0, 0.45, 14.0, 0.20, 0.034, 1116)
			_addat(x, _pt(120.0, 98.0, [[1.0, 0.22, 0.030]], 3.0))
			_drive(x, 1.6)
			return _fade(x, 25.0)
		"leg_go":
			# 엄지 밑 스위치가 523 에 딸깍 하고 끝난다. 400~3200Hz 에 갇힌다 —
			# 위로 새면 유리 톡이 되고 그건 반려당한 소리다
			var x := _blank(_n(60.0))
			var ck := _brst(50.0, 1.6, 3200.0, 3200.0, 0.0, 1106, 0.3)
			_hp(ck, 400.0)
			_lay(x, ck, 0.75)
			_lay(x, _brst(50.0, 1.6, 523.0, 523.0, 16.0, 1106, 0.3), 0.40)
			_addat(x, _pt(55.0, 523.0, [[1.0, 1.00, 0.011], [2.0, 0.28, 0.006],
					[0.5, 0.35, 0.014]], 1.0))
			_lay(x, _detent(40.0, 523.0, 1116, 0.55, 0.20), 0.40)
			_drive(x, 1.6)
			return _fade(x, 8.0)
		"boss_seal":
			#  간판에 칩 한 장이 박힌다. 330 에서 247 로 **내려** 닿는다 —
			#  leg_open 이 392→523 오름(문이 열린다)이라 봉인은 내림이다.
			#  금속 0 — 위 머리말이 못 박은 「카드쪽 넷의 종이 키트」 그대로다.
			#  콤은 안 쓴다(넷과 같은 이유 — 지연에 걸린 음만 이득이 오른다).
			#  씨 1119(→1120) · 1122(→1123) · 1132 는 이 파일에서 안 쓰던 것이다
			#  — 겹치면 같은 잡음이 두 소리에 실린다(2026-09-18).
			var x := _blank(_n(240.0))
			_lay(x, _slide(70.0, 4000.0, 1200.0, 1.0, 1109, 4.0, 12.0, 0.40), 0.42)
			_leg_tap(x, 0.0, 330.0, 0.50, 2600.0, 0.45, 16.0, 0.20, 0.052, 1119)
			_leg_tap(x, 110.0, 247.0, 0.50, 2600.0, 0.45, 20.0, 0.20, 0.060, 1122)
			#  마지막에 칩 한 장이 얹힌다 — 판 밖은 카지노 목소리다
			_lay(x, _chip(40.0, 247.0, 0.0050, 1132, 0.40), 0.34, 110.0)
			_addat(x, _pt(160.0, 98.0, [[1.0, 0.30, 0.046]], 3.0), 110.0)
			_drive(x, 1.6)
			return _fade(x, 30.0)
		"stage_open":
			# 판지가 더 느리고 무겁게 미끄러져 서고 3도로 닿는다(392→494).
			# 팩 경로에서는 찢김 결이 한 층 더 실린다
			var x := _blank(_n(230.0))
			_lay(x, _slide(120.0, 4400.0, 1250.0, 1.1, 1107, 5.0, 14.0, 0.35), 0.58)
			_leg_tap(x, 0.0, 392.0, 0.52, 2600.0, 0.45, 18.0, 0.20, 0.046, 1117)
			_leg_tap(x, 90.0, 494.0, 0.52, 2600.0, 0.45, 18.0, 0.20, 0.042, 1118)
			_addat(x, _pt(150.0, 98.0, [[1.0, 0.28, 0.038]], 3.0))
			_lay(x, _slide(60.0, 3800.0, 1100.0, 0.8, 1127, 2.0, 6.0, 0.55),
					0.32, 90.0)
			_drive(x, 1.6)
			return _fade(x, 30.0)
		"stage_pick":
			# 판지 셋을 523-659-784 로 단호하게 내려놓고 잠긴 뒤 알갱이가
			# 흩어져 떨어진다. 앞머리만 단단하다
			var x := _blank(_n(260.0))
			_lay(x, _brst(20.0, 1.0, 5200.0, 5200.0, 0.0, 1108, 0.2), 0.70)
			_leg_tap(x, 0.0, 523.0, 0.48, 3000.0, 0.42, 11.0, 0.22, 0.034, 1128)
			_leg_tap(x, 70.0, 659.0, 0.48, 3000.0, 0.42, 11.0, 0.22, 0.030, 1129)
			_leg_tap(x, 140.0, 784.0, 0.48, 3000.0, 0.42, 11.0, 0.22, 0.026, 1130)
			# 잠금 핑 — 비 1 : 1.709 라 배음이 아니다(작은 유리·금속)
			_addat(x, _pt(60.0, 1568.0, [[1.0, 0.30, 0.026],
					[1.709, 0.16, 0.014]], 0.5), 140.0)
			# 고른 것 위에 칩 한 장이 얹힌다
			_lay(x, _chip(40.0, 523.0, 0.0050, 1131, 0.40), 0.30, 140.0)
			# 흩어지는 꼬리 — 알갱이 다섯. 팩 쏟김도 이 자리를 쓴다
			var gf := [2400.0, 1700.0, 3100.0, 1300.0, 2050.0]
			var ga := [0.20, 0.16, 0.14, 0.12, 0.09]
			var gt := [178.0, 196.0, 211.0, 229.0, 244.0]
			for k in 5:
				_lay(x, _brst(14.0, 6.0, float(gf[k]), float(gf[k]), 2.0,
						1140 + k, 0.5), float(ga[k]), float(gt[k]))
			_addat(x, _pt(30.0, 150.0, [[1.0, 0.10, 0.012]], 1.0), 196.0)
			_addat(x, _pt(30.0, 150.0, [[1.0, 0.10, 0.012]], 1.0), 229.0)
			_drive(x, 2.2)
			return _fade(x, 20.0)
		_:
			return PackedFloat32Array()


# 종이 탁 하나 — 접촉(색 없는 톡) · 판지 색(높은 Q 의 자연 감쇠) ·
# 음높이(4도·3도 간격을 읽히게 하는 약한 사인) 셋이 한 벌이다.
func _leg_tap(x: PackedFloat32Array, t0: float, f: float, ca: float,
		cfc: float, sa: float, sq: float, ta: float, ttau: float,
		seed: int) -> void:
	_lay(x, _brst(30.0, 1.2, cfc, cfc, 0.0, seed, 0.2), ca, t0)
	_lay(x, _brst(60.0, 4.0, f, f, sq, seed + 1, 0.2), sa, t0)
	_addat(x, _pt(ttau * 4000.0, f, [[1.0, ta, ttau]], 2.0), t0)








# 얇은 금속 원판 — 상점의 알맹이. 비배음 1 : 2.08 : 3.41 : 5.06.
# 메뉴의 랙 뚜껑(newrun_open)도 이 줄을 쓴다.
const DISC := [1.0, 2.08, 3.41, 5.06]
# 판·막대 모달비 — _bar 가 「금속」이라 부르는 그 줄이고 던지기·착탄도
# 같은 줄을 쓴다. **상점의 몸통이 아니다.** 비율이 나무를 만든 게 아니라
# 이 줄을 196~220Hz 기음에 tau 22~55ms 로 걸어 둔 것이 만들었다 — 음정이
# 서고 여운이 **40~120ms 나 남으니** 판 밖이 통째로 나무 두드리는 소리가
# 됐다. 지수로는 -40dB 까지 101~253ms 지만 실제로는 거기 못 간다 —
# _pt(ms,…) 가 버퍼 길이를 박아 두고 _lay·_addat 은 그 길이만큼만 얹으므로
# 아직 -15~-35dB 인 자리에서 잘린다. 잘려도 음정은 이미 선 뒤다. 접착층은 칩과 트레이로 갈았고, 여기 남은 것은 fixture_buy 의 판
# 알맹이(392~659Hz) 하나다.
const PLATE := [1.0, 2.76, 5.40, 8.93]


func _rat(tab: Array, amps: Array, taus: Array) -> Array:
	# 비율표 하나에 진폭·감쇠를 꿰어 부분음 줄들을 낸다.
	var out := []
	for k in amps.size():
		out.append([float(tab[k]), float(amps[k]), float(taus[k])])
	return out


func _gate(x: PackedFloat32Array, step_ms: float, p: float, lo: float,
		hi: float, seed: int) -> PackedFloat32Array:
	# 그레인 게이트. 잡음을 잘게 끊어 종이가 찢기는 결을 낸다.
	var step := maxi(_n(step_ms), 1)
	_seed(seed)
	var g := 1.0
	for i in x.size():
		if i % step == 0:
			var r := (_rnd() + 1.0) * 0.5
			g = 0.0 if r > p else lerpf(lo, hi, (_rnd() + 1.0) * 0.5)
		x[i] *= g
	return x


func _b_shop(nm: String) -> PackedFloat32Array:
	match nm:
		# ══ 상점 ═════════════════════════════════════════
		#  가구 **하나**로 낸다. 펠트 깐 카운터 위의 점토 칩과 동전
		#  트레이(1 : 2.41 : 3.83)가 몸통이고, 그 위에 얹히는 얇은 금속
		#  원판(1 : 2.08 : 3.41 : 5.06)이 알맹이고, 둘 사이를 같은 펠트
		#  잡음이 잇는다. 상한은 6kHz — 9.7kHz 유리 딸깍은 이 가구에 없다.
		#
		#  몸통이 **나무 카운터**(1 : 2.76 : 5.40 : 8.93)이던 때가 있었다.
		#  196~220Hz 기음에 tau 22~55ms 를 걸어 두었더니 40~120ms
		#  를 울렸는데, **음정 + 여운이 곧 두드림이다** — 값을 치르는 자리마다
		#  나무를 퉁 치는 소리가 났다(deny 는 300Hz 아래에 에너지의 98%,
		#  sweep_sink 는 196Hz 한 점에 38% 를 두고 있었다).
		#  접착층 자체는 여전히 필요하다 — 빼면 이 여섯이 흩어진다. 같은
		#  196/220Hz 자리를 칩과 트레이가 받는다: 칩은 몸통이 f×2.5 로 올라
		#  앉고 표의 f 에는 조용한 닻만 남아 44ms 안에 끝나고, 트레이는
		#  비배음이라 같은 음을 짚어도 음정이 안 선다.
		#
		#  잡음층의 무게가 부분음보다 크게 적힌 자리가 있다. 좁은 대역 잡음은
		#  피크 대비 RMS 가 사인의 절반도 안 돼서, 피크를 맞추면 **안 들린다** —
		#  들리게 하려면 그만큼 올려야 한다.
		"shop_open":
			# 서랍이 열리고 펠트가 쓸린다. 어택 4ms 가 펠트다(0.5ms 면 유리다)
			var x := _blank(_n(340.0))
			var wd := _mod(340.0, 440.0, [[0.25, 0.45, 0.075], [0.50, 0.70, 0.085],
					[1.00, 1.00, 0.070], [2.76, 0.22, 0.022], [5.40, 0.08, 0.010]])
			_atk(wd, 4.0)
			_drive(wd, 1.4)
			_lay(x, wd, 1.00)
			var ft := _air(180.0, 1800.0, 700.0, 1.1, 2001)
			_atk(ft, 3.0)
			_dec(ft, 0.055)
			_lay(x, _fade(ft, 12.0), 1.00)
			# 천 저역 — 무음 낙하 대여섯 개를 덮는 몸통이다
			var cl := _air(300.0, 300.0, 170.0, 0.9, 2002)
			_atk(cl, 12.0)
			_dec(cl, 0.130)
			_lay(x, _fade(cl, 20.0), 1.80)
			# **현금 서랍이다.** 판재가 밀려 나오고 동전 접시가 덜그럭거리고
			# 작은 종이 한 번 울린다 — 이 셋이 상점의 문을 연다
			_lay(x, _tray(300.0, 220.0, 0.070), 0.34, 20.0)
			_pour(x, 40.0, 180.0, 5, 698.0, 6.0, 0.045, 20021, 0.22)
			_lay(x, _bell(220.0, 1046.0, 0.050), 0.20, 12.0)
			return _fade(x, 30.0)
		#  ── 매물이 펠트에 앉는다 (2026-09-20) ────────────
		#  등급이 **나타나는 순간**의 소리다. 둘 다 이 가구 위에서 낸다 —
		#  현금 서랍(shop_open)과 동전 트레이가 이미 선 그 카운터다.
		#  **종을 안 쓴다**: 잭팟 종은 run_win · target_hit 이 「이겼다」로
		#  쥐고 있고 상점에서는 한 번도 안 운다. BELL 이 못 박은 **tierce 1.2
		#  를 아래 둘에 한 개도 안 넣었다** — 그 비가 종을 종으로 만든다.
		"coin_land":
			#  얇은 금속 원판 한 장이 펠트에 앉는다. 희귀(392) · 레어(523) ·
			#  예고 톡 셋(294/330/392)이 **이 한 파일을 pitch_scale 로 나눠 쓴다.**
			#  ⚠ **밑음이 반드시 392(SFX_BASE)여야 한다** — _sfx 가
			#  pitch_scale = f/392 로 미므로, 여기가 어긋나면 523 호출이
			#  다른 음으로 난다. probe_sfx 가 스펙트럼 봉우리로 잰다.
			var x := _blank(_n(110.0))
			_addat(x, _pt(90.0, 392.0, _rat(DISC, [1.00, 0.42, 0.18, 0.07],
					[0.028, 0.017, 0.011, 0.007]), 1.0))
			#  몸통은 동전 트레이다. **비배음(1 : 2.41 : 3.83)이라 같은 음을
			#  짚어도 음정이 안 선다** — 원판이 음을 쥐고 트레이는 무게만 준다.
			_lay(x, _tray(110.0, 196.0, 0.030), 0.26, 6.0)
			#  펠트 한 겹. **어택 4ms 가 펠트다** — shop_open 주석이 이미
			#  적었다(0.5ms 면 유리다). 물건은 펠트에 앉는다.
			var ft2 := _air(70.0, 900.0, 380.0, 1.0, 2401)
			_atk(ft2, 4.0)
			_dec(ft2, 0.022)
			_lay(x, _fade(ft2, 14.0), 0.90)
			#  상한 6kHz — 9.7kHz 유리 딸깍 대역은 반려당한 자리라 비워 둔다.
			_lp(x, 6000.0, 2)
			return _fade(x, 14.0)
		"coin_plaque":
			#  레전더리 한 장. 알맹이가 원판이 아니라 **두꺼운 판재**다 —
			#  STK_TIERS 머리말이 「레전더리는 사다리의 다섯째 단이 아니라
			#  **종이 다른 것**」이라고 적었고, 실제로 그것은 원반이 아니라
			#  플라크다. 그래서 여기만 PLATE 비(1 : 2.76 : 5.40 : 8.93)를
			#  기음을 눌러 얹는다.
			#  ⚠ 밑음 262 다. game.gd 는 **인자 없이** 부른다 — f 를 주면
			#  262/392 = 175Hz 가 된다.
			var x := _blank(_n(240.0))
			_addat(x, _pt(200.0, 262.0, [[1.00, 0.85, 0.070],
					[2.76, 0.30, 0.034], [5.40, 0.14, 0.020],
					[8.93, 0.07, 0.012]], 1.2))
			#  몸통은 coin_land 와 **같은 트레이**다 — 가족을 안 떠난다.
			#  무게만 더 얹어(0.34 · tau 0.075) 판재가 두껍게 앉는다.
			_lay(x, _tray(240.0, 196.0, 0.075), 0.34, 8.0)
			var ft3 := _air(150.0, 700.0, 260.0, 0.9, 2402)
			_atk(ft3, 5.0)
			_dec(ft3, 0.060)
			_lay(x, _fade(ft3, 26.0), 0.85)
			_lp(x, 5200.0, 2)
			return _fade(x, 26.0)
		"buy":
			# 원판 두 장이 523→659 로 **올라간다**. 값을 내고 물건이 앉는다
			var x := _blank(_n(230.0))
			_addat(x, _pt(200.0, 523.0, _rat(DISC, [1.00, 0.55, 0.30, 0.16],
					[0.060, 0.038, 0.026, 0.016]), 1.0))
			var t2 := _pt(160.0, 659.0, _rat(DISC, [1.00, 0.50, 0.26, 0.13],
					[0.075, 0.045, 0.030, 0.018]), 1.0)
			_comb(t2, 11.0, 0.18, 2)      # 슬롯 울림
			_addat(x, t2, 70.0)
			# 칩 한 장이 스택 위에 앉는다 — 가족을 한 카운터로 묶는 접착층.
			# 나무 턱(196Hz · tau 35ms)이던 자리다: 60ms 를 -14.9dB 에서 자를
			# 때까지 끌어서
			# 원판 둘 밑에 음정 있는 「퉁」이 두 번 깔렸다. 칩은 몸통이 490Hz
			# 로 올라앉고 196 에는 닻 하나만 남아 44ms 에 끝난다.
			# 무게는 한 번만 준다
			var jc := _chip(46.0, 196.0, 0.0060, 2031, 0.42)
			_lay(x, jc, 0.34)
			_lay(x, jc.duplicate(), 0.34, 70.0)
			var sl := _air(60.0, 2600.0, 1500.0, 2.0, 2003)
			_atk(sl, 10.0)
			_lin(sl, 10.0)
			_lay(x, sl, 0.35, 8.0)
			# **카ー칭.** 둘째 원판 위에 종이 한 번 울리고 접시가 받는다 —
			# 값이 치러졌다는 표시고, 파는 쪽과 갈리는 자리이기도 하다
			_lay(x, _bell(150.0, 1318.0, 0.042), 0.26, 70.0)
			_lay(x, _tray(200.0, 262.0, 0.055), 0.24, 70.0)
			return _fade(x, 15.0)
		"sell":
			# 원판 두 장이 880→659 로 **내려간다.** buy 의 거울이다 —
			# 둘 다 올라가면 값을 내는 것과 받는 것이 같은 손짓이 된다
			var x := _blank(_n(170.0))
			_addat(x, _pt(150.0, 880.0, _rat(DISC, [1.00, 0.40, 0.16],
					[0.045, 0.032, 0.018]), 1.0))
			_addat(x, _pt(120.0, 659.0, _rat(DISC, [1.00, 0.45, 0.20],
					[0.055, 0.028, 0.018]), 1.0), 45.0)
			# buy 와 같은 접착층 — 칩 한 장이 카운터에 놓인다. 나무 턱
			# (196Hz · tau 22ms · 40ms 를 -15.8dB 에서 자른다)이던 자리다
			_lay(x, _chip(34.0, 196.0, 0.0045, 2032, 0.40), 0.26, 45.0)
			var tl := _air(50.0, 1200.0, 600.0, 0.8, 2004)
			_atk(tl, 8.0)
			_lin(tl, 8.0)
			_lay(x, tl, 0.25, 115.0)
			# 받은 값이 접시로 들어간다. 종은 안 울린다 — 종은 사는 쪽 것이다
			_lay(x, _tray(150.0, 196.0, 0.048), 0.30, 45.0)
			_pour(x, 50.0, 90.0, 3, 880.0, 5.0, 0.040, 20041, 0.24)
			return _fade(x, 12.0)
		"deny":
			# 물린 칩 둘. **원판 비율을 한 개도 안 쓴다** — 오간 것이 없으니
			# 금속 울림이 남으면 안 된다.
			# 나무 노크 둘(200 · 150Hz · tau 30·34ms)이던 자리다. 200Hz 줄이
			# 120ms 를 울려서 이 파일이 300Hz 아래에 에너지의 98% 를
			# 두고 있었다 — 카운터를 두드리는 소리였지 거절이 아니었다.
			# 거절을 거절로 만드는 것은 아래 150/158Hz 울음이지 이 둘이 아니다
			var x := _blank(_n(150.0))
			_lay(x, _chip(44.0, 200.0, 0.0050, 2051, 0.34), 1.25)
			_lay(x, _chip(40.0, 150.0, 0.0055, 2052, 0.30, 0.92), 1.15, 60.0)
			var sp := _air(12.0, 900.0, 420.0, 1.4, 2005)
			_atk(sp, 1.0)
			_lin(sp, 1.0)
			_lay(x, sp, 0.30)
			_lay(x, sp.duplicate(), 0.30, 60.0)
			# 낮은 **부저**. 150 과 158 이 8Hz 로 맞물려 울음이 생긴다 —
			# 카지노에서 안 된다고 하는 소리는 음이 아니라 이 울음이다
			_addat(x, _pt(140.0, 150.0, [[1.0, 0.45, 0.045],
					[1.0533, 0.45, 0.045]], 1.0))
			_lp(x, 2200.0)               # 어택의 날을 깎는다
			_drive(x, 1.3)
			return _fade(x, 20.0)
		"reroll":
			# 동전을 내려꽂고 펠트를 긁어 판을 다시 굴린다. 기본음만 한 반음
			# 흘러내린다 — 내려꽂는 손짓이 거기에만 실린다
			var x := _blank(_n(240.0))
			_addat(x, _one(200.0, 392.0, 370.0, 0.040, 1.0))
			_addat(x, _pt(160.0, 392.0, _rat(DISC, [0.0, 0.42, 0.20, 0.09],
					[0.040, 0.024, 0.015, 0.010]), 1.0))
			# 가족의 바닥. 220 은 shop_open 이 이미 **트레이로** 쓰는 자리라
			# 나무 턱을 그 트레이로 갈았다. tau 55ms 가 120ms 버퍼에 -19dB 에서
			# 잘리는데(구운 파일에서 220Hz 가 약 145ms 에 사라진다) 그래도
			# 240ms 짜리 이 파일이 끝날 때까지 220Hz 음정이 남아 있었다 —
			# 트레이는 비배음(1 : 2.41 : 3.83)이라 같은 220 을 짚어도 음이 안 선다
			_lay(x, _tray(120.0, 220.0, 0.028), 0.30)
			# 칩을 훑는다(리플). 넷이 5ms 씩 엇물려 한 동작으로 들린다 —
			# 판을 다시 굴리기 전에 손이 하는 짓이 이것이다
			for k in 4:
				_lay(x, _chip(30.0, 392.0 * pow(2.0, float(k) * 0.04),
						0.0045, 2060 + k, 0.40, 1.0 - float(k) * 0.12),
						0.30, 40.0 + float(k) * 5.0)
			var sc := _air(205.0, 2400.0, 700.0, 1.6, 2006)
			_atk(sc, 20.0)
			_dec(sc, 0.065, 20.0)
			_lay(x, _fade(sc, 20.0), 0.80, 30.0)
			var dr := _air(160.0, 260.0, 160.0, 1.0, 2007)
			_atk(dr, 15.0)
			_dec(dr, 0.080, 15.0)
			_lay(x, _fade(dr, 12.0), 0.22, 40.0)
			return _fade(x, 10.0)
		"fixture_buy":
			# 알맹이가 원판이 아니라 **두꺼운 판**이다 — 8.93 부분음이 이
			# 이름에만 있다. 셋을 392-523-659 로 올려 박고 상자가 쿵 한다.
			# PLATE 가 남은 유일한 자리다: 기음이 392 위라 낮은 울림이 안 생긴다
			# (150~230Hz 에 이 파일 에너지의 0.06% 뿐이다). 소리는 안 바꾼다
			var x := _blank(_n(300.0))
			# 상자 쿵을 t=0 으로 옮겼다 — 140ms 에 두면 봉우리가 거기 서서
			# 누른 순간이 아니라 143ms 뒤가 가장 큰 소리가 된다
			_addat(x, _pt(200.0, 98.0, [[1.0, 0.35, 0.075]], 2.0))
			_addat(x, _pt(200.0, 392.0, _rat(PLATE, [1.00, 0.40, 0.16, 0.06],
					[0.055, 0.024, 0.013, 0.007]), 0.8))
			_addat(x, _pt(180.0, 523.0, _rat(PLATE, [1.00, 0.36, 0.14, 0.05],
					[0.060, 0.026, 0.014, 0.007]), 0.8), 70.0)
			_addat(x, _pt(160.0, 659.0, _rat(PLATE, [0.62, 0.32, 0.12, 0.04],
					[0.055, 0.030, 0.015, 0.007]), 0.8), 140.0)
			_lay(x, _pt(90.0, 262.0, _rat(DISC, [1.00, 0.47, 0.20],
					[0.045, 0.026, 0.016]), 1.0), 0.30)
			# 꽂혀 앉는 발 위에 종이 한 번. 사진은 값이 큰 물건이다
			_lay(x, _bell(180.0, 1318.0, 0.048), 0.22, 140.0)
			_lay(x, _tray(220.0, 262.0, 0.060), 0.22, 140.0)
			for t in [0.0, 70.0, 140.0, 150.0]:
				var gr := _air(8.0, 4200.0, 2800.0, 2.2, 2010 + int(t))
				_gate(gr, 1.11, 0.6, 1.0, 1.0, 2020 + int(t))
				_lay(x, _fade(gr, 2.0), 0.28, t)
			return _fade(x, 15.0)
		"cons_use":
			# 포장을 뜯어 쓴다. buy 와 같은 두 음(523·659)이므로 **재질만이
			# 구분선이다** — 원판도 8.93 판재도 여기엔 한 개도 없다
			var x := _blank(_n(230.0))
			_addat(x, _pt(40.0, 523.0, [[1.0, 0.55, 0.018],
					[2.76, 0.12, 0.007]], 1.2))
			_addat(x, _pt(40.0, 659.0, [[1.0, 0.50, 0.020],
					[2.76, 0.10, 0.008]], 1.2), 60.0)
			# 포장지 몸통 — 대역 자체의 음높이가 들릴 만큼 좁다(Q 3.0).
			# 중심이 계단으로 523x4 → 659x4 로 올라가는 것이 「음을 든다」다
			var w1 := _air(60.0, 2092.0, 2092.0, 3.0, 2008)
			_gate(w1, 0.73, 0.55, 0.4, 1.0, 2028)
			_dec(w1, 0.030)
			_lay(x, _fade(w1, 4.0), 0.45)
			var w2 := _air(150.0, 2636.0, 2636.0, 3.0, 2009)
			_gate(w2, 0.73, 0.55, 0.4, 1.0, 2029)
			_dec(w2, 0.040)
			_lay(x, _fade(w2, 8.0), 0.38, 60.0)
			var rs := _air(225.0, 5200.0, 3400.0, 1.3, 2011)
			_atk(rs, 15.0)
			_dec(rs, 0.035, 15.0)
			_lay(x, _fade(rs, 20.0), 0.40)
			return _fade(x, 10.0)
		"shop_smash":
			#  매물 하나가 창구 턱에 처박힌다. **190ms.**
			#  유리·도자기 깨짐은 어디서나 세 층이다: 접촉(낮고 둔탁) →
			#  파열(밝은 트랜지언트, 접촉 +10~15ms) → 파편 꼬리.
			#  **꼬리를 빼면 가짜로 들린다.** 뼈대는 egg_crack 을 그대로 들고
			#  오되 ②의 몸통만 나무(185/98Hz)에서 상점 가족으로 간다 —
			#  리롤은 판 밖이라 나무 카운터가 아니라 펠트 깐 카지노 카운터다.
			var x := _blank(_n(190.0))
			# ① 접촉 0ms — 점토 칩이 턱에 닿는 첫 점. 감쇠 5ms 대가 칩의
			#    정체다(이보다 길면 칩이 아니라 접시가 된다)
			_lay(x, _chip(30.0, 262.0, 0.0050, 2301, 0.52), 1.00)
			# ② 파열 +12ms — 콰득 넷을 셋으로 줄이고 중심을 1~2kHz 안에
			#    가둔다. 3kHz 위로 올리면 점토가 아니라 유리·플라스틱
			#    딸깍으로 들린다(egg_crack 이 스펙트럼 무게중심으로 잰 값)
			var cr := [[12.0, 1500.0, 1.00], [16.0, 950.0, 0.82],
					[24.0, 1900.0, 0.50]]
			for i in cr.size():
				var c: Array = cr[i]
				_lay(x, _clk(34.0, 3.0, float(c[1]), float(c[1]) * 0.5, 0.7,
						0.010, 2310 + i, 0.2), float(c[2]), float(c[0]))
			# ③ 몸통 +10ms — 얇은 원판이 쪼개진다
			_addat(x, _pt(120.0, 262.0, _rat(DISC, [1.00, 0.44, 0.20, 0.09],
					[0.022, 0.014, 0.009, 0.006]), 0.4), 10.0)
			# ④ 꼬리 28~165ms — 흩는 값 일곱을 **먼저** 뽑는다. _clk/_chip 이
			#    제 씨로 잡음 상태를 덮으므로 도중에 뽑으면 딱마다 같은 값이
			#    난다(egg_crack 이 이미 밟은 자리)
			_seed(2330)
			var us := []
			for i in 7:
				us.append((_rnd() + 1.0) * 0.5)
			var t := 28.0
			var g := 0.44
			for i in 7:
				var u: float = us[i]
				_lay(x, _chip(14.0, 262.0 * pow(2.0, u * 7.0 / 12.0), 0.0028,
						2340 + i, 0.34), g, t)
				t += 7.0 + 12.0 * u + float(i) * 1.5
				g *= 0.84
			# ⑤ 밑 — 펠트에 쏟아지고 턱이 저역을 먹는다. 좁은 대역 잡음은
			#    피크 대비 RMS 가 사인의 절반도 안 돼서, 무게를 부분음보다
			#    크게 적는 것이 맞다
			_lay(x, _nz(120.0, 1600.0, 650.0, 1.0, 2350, 0.035, 3.0), 0.18, 16.0)
			var ah := _air(60.0, 420.0, 300.0, 0.7, 2351)
			_atk(ah, 6.0)
			_lin(ah, 6.0)
			_lay(x, ah, 0.20)
			_drive(x, 1.6)
			_lp(x, 6000.0)
			return _fade(x, 16.0)
		"shop_smash_lo":
			#  겹칠 때 쓰는 가벼운 판. **110ms.** 층 ①② 만 쓰고 **몸통(DISC)이
			#  없다** — 그 하나가 이 소리를 가볍게 만드는 전부고, 부딪힘이
			#  7~14ms 간격으로 오는 매물 아홉에서 한 덩어리로 뭉치는 것을
			#  막는 자리다. sweep_sink 가 「한두 프레임에 대여섯이 겹친다」고
			#  감쇠를 짧게 맨 이유를 그대로 물려받는다.
			var x := _blank(_n(110.0))
			_lay(x, _chip(26.0, 196.0, 0.0042, 2360, 0.46), 1.00)
			var cr2 := [[10.0, 1300.0, 0.78], [15.0, 880.0, 0.60]]
			for i in cr2.size():
				var c: Array = cr2[i]
				_lay(x, _clk(26.0, 2.6, float(c[1]), float(c[1]) * 0.5, 0.7,
						0.008, 2364 + i, 0.2), float(c[2]), float(c[0]))
			_seed(2370)
			var us2 := []
			for i in 3:
				us2.append((_rnd() + 1.0) * 0.5)
			var t2 := 22.0
			var g2 := 0.36
			for i in 3:
				var u: float = us2[i]
				_lay(x, _chip(12.0, 196.0 * pow(2.0, u * 7.0 / 12.0), 0.0024,
						2372 + i, 0.30), g2, t2)
				t2 += 7.0 + 11.0 * u + float(i) * 1.5
				g2 *= 0.82
			_lay(x, _nz(70.0, 1500.0, 620.0, 1.0, 2375, 0.022, 3.0), 0.14, 12.0)
			_drive(x, 1.5)
			_lp(x, 6000.0)
			return _fade(x, 10.0)
		"sweep_whip":
			#  팔이 펠트를 가른다. **150ms · 금속 부분음 0개.**
			#  공기만 쓰면 카지노가 아니다 — 펠트 깐 카운터가 곧 이 가구다.
			#  어택 14ms 가 그 펠트다(1ms 면 딱이 된다).
			var x := _blank(_n(150.0))
			var a1 := _air(90.0, 700.0, 2400.0, 1.1, 2380)   # 올라가는 대역 = 다가온다
			_atk(a1, 14.0)
			_dec(a1, 0.030)
			_lay(x, _fade(a1, 10.0), 1.00)
			var a2 := _air(70.0, 2400.0, 800.0, 1.2, 2381)   # 지나간다
			_atk(a2, 4.0)
			_dec(a2, 0.022)
			_lay(x, _fade(a2, 8.0), 0.70, 70.0)
			var ft := _air(60.0, 1200.0, 600.0, 0.8, 2382)   # 펠트 결
			_gate(ft, 0.9, 0.62, 0.35, 1.0, 2383)            # 그레인이 천의 결이다
			_atk(ft, 6.0)
			_dec(ft, 0.030)
			_lay(x, _fade(ft, 6.0), 0.30, 20.0)
			_lp(x, 5200.0)
			return _fade(x, 16.0)
		"sweep_sink":
			# 밀대가 칩 둘을 구멍으로 밀어 넣는다. 금속 부분음 0 개.
			# **motion_off 전용으로 남는다** — 움직임을 켠 손님은 이제 턱에서
			# 부서진다(shop_smash). 감쇠를 짧게 맨 이유는 shop_smash_lo 가
			# 그대로 물려받았다.
			# 한두 프레임에 대여섯이 같이 나므로 감쇠를 짧게 맨다.
			# 나무 몸통(196Hz)이던 자리다 — 그 한 층이 이 파일 에너지의 38% 를
			# 196Hz 한 점에 쥐고 있어서, 대여섯이 겹치면 **같은 음이 대여섯 번**
			# 겹쳐 울려 게임에서 가장 나무 두드리는 소리가 됐다
			var x := _blank(_n(55.0))
			_lay(x, _chip(46.0, 196.0, 0.0070, 2022, 0.50), 1.00)
			_lay(x, _chip(34.0, 262.0, 0.0045, 2024, 0.38, 0.85), 0.70, 5.0)
			var sk := _air(18.0, 1500.0, 900.0, 1.8, 2012)
			_atk(sk, 1.0)
			_lin(sk, 1.0)
			_lay(x, sk, 0.30)
			# 구멍 테두리가 쇠다 — 알이 그 턱을 긁고 들어간다
			_lay(x, _nz(10.0, 2400.0, 1400.0, 2.4, 2023, 0.0015, 0.2), 0.24)
			var ah := _air(40.0, 380.0, 300.0, 0.7, 2013)
			_atk(ah, 6.0)
			_lin(ah, 6.0)
			# 구멍이 빨아들이는 저역. 0.16 이던 것을 올렸다 — 나무 몸통이 빠진
			# 만큼 앞 50ms 에너지를 **음정 없는** 공기가 메워야 한다. 안 메우면
			# _norm_rms 가 통째로 올려서 피크만 뾰족해진다(0.16 그대로면 표의
			# a 의 3.9배까지 선다. 0.34 면 2.5배다)
			_lay(x, ah, 0.34, 10.0)
			return _fade(x, 7.0)
		"drop_skip":
			# 여럿이 같이 멎는다 — 같은 나무 탭 셋이 반음 위아래로 갈려
			# 4ms 간격으로 겹친다. 위를 잘라 금속 딸깍이 안 되게 한다
			var x := _blank(_n(50.0))
			# 칩 셋이 반음 위아래로 갈려 4ms 간격으로 겹친다 — 여럿이 같이
			# 멎는 소리다. 나무 탭이던 것을 칩으로 갈았다
			_lay(x, _chip(45.0, 330.0, 0.0050, 2141, 0.52), 1.00)
			_lay(x, _chip(40.0, 311.0, 0.0042, 2142, 0.44, 0.9), 0.72, 4.0)
			_lay(x, _chip(36.0, 349.0, 0.0036, 2143, 0.40, 0.8), 0.60, 9.0)
			_addat(x, _pt(45.0, 110.0, [[1.0, 0.55, 0.022]], 1.5))
			var pm := _air(22.0, 700.0, 380.0, 1.2, 2014)
			_atk(pm, 2.0)
			_lin(pm, 2.0)
			_lay(x, pm, 0.34)
			_lp(x, 3000.0)
			return _fade(x, 8.0)
		"chute_enter":
			# 알이 통로에 든다. 몸통이 없다 — 그 몸통은 뒤에 오는 buy/sell 이
			# 맡는다. 원판 비율의 2.08 하나만 얹어 「같은 523 의 원판」을 적는다
			var x := _blank(_n(38.0))
			_addat(x, _pt(34.0, 523.0, [[1.0, 1.00, 0.010],
					[2.76, 0.22, 0.004]], 0.3))
			_addat(x, _pt(20.0, 1088.0, [[1.0, 0.16, 0.006]], 0.3))
			var sc2 := _air(10.0, 2200.0, 1600.0, 2.2, 2015)
			_atk(sc2, 0.5)
			_lin(sc2, 0.5)
			_lay(x, sc2, 0.24)
			_hp(x, 300.0)
			return _fade(x, 6.0)
		_:
			return PackedFloat32Array()


# ══════════════════════════════════════════════════════════
#  카지노 재질 넷
#
#  판 위(던지기 · 착탄)는 안 건드린다 — 다트가 코르크에 박히는 소리는
#  다트여야 한다. 카지노는 **판 밖**에서 난다: 손이 칩을 만지고, 상점에서
#  동전이 트레이에 떨어지고, 메뉴가 릴 디텐트로 걸리고, 이기면 종이 운다.
# ══════════════════════════════════════════════════════════

# 점토 칩 — 얇은 원판의 앞 세 모드. **여운이 없는 것이 칩이다.**
# 쇠붙이면 울리고 나무면 통이 우는데 점토는 둘 다 안 한다.
const CHIP := [1.0, 1.73, 2.33]

# 잭팟 종 — 핸드벨의 부분음. 종을 종으로 만드는 것은 **tierce 1.2(단3도)**다.
# [비, 진폭, 감쇠배] · hum 이 가장 길고 nominal 이 그다음으로 세다.
const BELL := [[0.5, 0.55, 1.00], [1.0, 1.00, 0.72], [1.2, 0.45, 0.50],
		[1.5, 0.30, 0.34], [2.0, 0.50, 0.26], [2.5, 0.18, 0.17],
		[3.0, 0.12, 0.11]]



# 배음 몸통(1 : 2.00 : 3.01 : 4.00)은 **걷어 냈다.** 배음렬은 속 빈 나무
# 상자라, 440Hz 랙(newrun_open)에서 2·3·4배 봉우리 합이 기음보다 +1.1dB
# 세게 서서 상자가 통째로 울었고, 330Hz 뒤로가기(back)는 에너지의 97.7%
# 가 330±25Hz 한 점에 몰려 순음 노크가 됐다. 메뉴의 몸은 릴 디텐트
# (_detent)와 칩이고, 랙 뚜껑만 DISC 를 빌려 쓴다.


func _clk(ms: float, burst_ms: float, fc0: float, fc1: float, q: float,
		tau: float, seed: int, atk_ms := 0.4) -> PackedFloat32Array:
	# 딸깍 하나. 짧은 버스트를 좁은 대역에 통과시키고 지수로 눕힌다.
	var v := _brst(ms, burst_ms, fc0, fc1, q, seed, atk_ms)
	return _dec(v, tau)



func _wide(v: PackedFloat32Array, taun: float,
		atk_ms := 0.3) -> PackedFloat32Array:
	# 넓은 잡음층(Q 가 낮은 것)은 위를 덮어 둔다. 안 덮으면 이 층이 위쪽
	# 대역까지 깔려서 그 위에 얹는 마른 테두리가 제 대역에서 묻힌다.
	_atk(v, atk_ms)
	_dec(v, taun)
	_lp(v, 3000.0, 2)
	return _fade(v, minf(1.5, float(v.size()) / SR * 250.0))


func _bell(ms: float, f: float, d1: float, g := 1.0,
		atk_ms := 0.4) -> PackedFloat32Array:
	# 작은 놋쇠 종 하나. f 는 때린 음(prime)이고 hum 은 그 옥타브 아래다.
	var parts := []
	for p in BELL:
		parts.append([float(p[0]), float(p[1]) * g, d1 * float(p[2])])
	return _pt(ms, f, parts, atk_ms)


# 칩의 알맹이가 앉는 자리. 표의 f 는 **관계**(4도 짝 · 옥타브)이지 칩의
# 기음이 아니다 — 147~349 를 그대로 쓰면 칩이 아니라 둔한 툭이 된다.
# 실제 점토 칩의 알맹이는 700~1200Hz 대이므로 관계를 그대로 들고 올린다.
const CHIP_UP := 2.5


func _chip(ms: float, f: float, d1: float, seed: int, edge := 0.55,
		g := 1.0, efc := 2600.0) -> PackedFloat32Array:
	# 점토 칩 한 장이 부딪힌다. 마른 테두리 2ms + 짧은 몸통 + 낮은 무게.
	# 감쇠가 4ms 대인 것이 요점이다 — 이보다 길면 칩이 아니라 접시다.
	var fu := f * CHIP_UP
	var x := _pt(ms, fu, [[CHIP[0], 1.00 * g, d1],
			[CHIP[1], 0.42 * g, d1 * 0.5], [CHIP[2], 0.16 * g, d1 * 0.28]], 0.3)
	# 무게는 표의 f 자리에 조용히 남긴다 — 관계를 귀가 붙잡을 닻이다
	_addat(x, _pt(ms, f, [[1.0, 0.26 * g, d1 * 1.6]], 0.5))
	_lay(x, _nz(6.0, efc, efc * 0.58, 1.4, seed, 0.0012, 0.15), edge * g)
	return x


func _tray(ms: float, f: float, d1: float, g := 1.0) -> PackedFloat32Array:
	# 동전이 떨어지는 금속 접시. 비배음 셋이 낮게 깔려 계속 운다 —
	# 쏟아지는 동전을 하나로 묶는 바닥이다.
	return _pt(ms, f, [[1.0, 1.00 * g, d1], [2.41, 0.46 * g, d1 * 0.62],
			[3.83, 0.22 * g, d1 * 0.38]], 1.0)


func _pour(x: PackedFloat32Array, t0: float, span_ms: float, n: int,
		f0: float, spread: float, d1: float, seed: int,
		g := 1.0) -> PackedFloat32Array:
	# 동전이 쏟아진다. 같은 동전 비율을 n 개, 자리와 음을 흩어 얹는다.
	# 흩는 값은 씨를 박은 LCG 라 몇 번 구워도 같은 소리가 나온다.
	_seed(seed)
	for k in n:
		var u := (_rnd() + 1.0) * 0.5              # 0..1
		var v := _rnd()                            # -1..1
		var at := t0 + span_ms * (float(k) + u * 0.8) / float(n)
		var f := f0 * pow(2.0, v * spread / 12.0)
		var a := g * (0.45 + 0.55 * ((_rnd() + 1.0) * 0.5))
		_lay(x, _pt(d1 * 2400.0, f, _coin(d1), 0.4), a, at)
	return x


func _detent(ms: float, f: float, seed: int, click := 1.0,
		leaf := 0.30) -> PackedFloat32Array:
	# 슬롯 릴이 한 칸 걸린다. 딱딱한 딸깍 + 판스프링이 튕기는 짧은 울림 +
	# 릴이 멎는 낮은 툭. 셋이 한 벌이다.
	var x := _blank(_n(ms))
	# 딸깍이 5ms 다 — 2ms 면 너무 얕아서 릴이 아니라 스위치가 된다
	_lay(x, _nz(7.0, 3200.0, 2000.0, 1.5, seed, 0.0016, 0.15), click)
	# 판스프링이 튕긴다. 비 1 : 1.61 이라 배음이 아니다
	_addat(x, _pt(ms * 0.7, f * 3.4, [[1.0, leaf, 0.0080],
			[1.61, leaf * 0.5, 0.0040]], 0.3))
	# 릴이 멎는 낮은 툭
	_addat(x, _pt(ms * 0.8, f, [[1.0, 0.38, 0.0090],
			[0.5, 0.16, 0.0140]], 0.5))
	return x


func _b_hand(nm: String) -> PackedFloat32Array:
	match nm:
		# ══ 손 ═══════════════════════════════════════════
		#  **점토 칩.** 가장 많이 눌리는 자리라 짧고(38~48ms) 여운이 없다.
		#  칩의 정체는 감쇠다 — 몸통이 4ms 대에서 죽고 마른 테두리가 2ms 다.
		#  이보다 길면 접시가 되고, 부분음을 더하면 쇠가 된다.
		#
		#  표의 f 가 칩의 크기로 읽힌다: 196/147 은 무더기, 349/262 은 한 장.
		#  상점 행과 진열대 행은 **칩과 카드**로 갈린다 — 표가 둘을 같은 f 로
		#  적어 두었으니(349 / 262) 재질이 그 둘을 갈라야 한다.
		"hand_take":
			# 칩 무더기를 집어 든다. 아래 칩들이 스치며 딸려 온다
			var x := _chip(38.0, 196.0, 0.0055, 1147, 0.50)
			_lay(x, _wide(_air(6.0, 3600.0, 5400.0, 1.8, 1157), 0.0018), 0.22)
			_lay(x, _chip(20.0, 262.0, 0.0030, 1167, 0.30, 0.40), 0.34, 3.0)
			return _fade(x, 2.0)
		"hand_drop":
			# 칩 무더기를 놓는다. 두 장이 잇따라 부딪히고 펠트가 받는다
			var x := _chip(46.0, 147.0, 0.0070, 1148, 0.44)
			_lay(x, _chip(24.0, 196.0, 0.0035, 1168, 0.26, 0.45), 0.30, 4.5)
			_lay(x, _wide(_air(7.0, 1500.0, 620.0, 0.8, 1158), 0.0026), 0.30)
			return _fade(x, 2.5)
		"shop_select":
			# 테이블의 칩 한 장을 집는다. 349.333 = 262x4/3 —
			# deselect 의 262 와 정확히 4도 짝이다
			var x := _chip(48.0, 349.333, 0.0045, 1149, 0.58)
			_lay(x, _wide(_air(5.5, 2000.0, 900.0, 0.9, 1159), 0.0016), 0.26)
			return _fade(x, 2.0)
		"shop_deselect":
			# 칩을 내려놓는다. 잡음 대역이 **올라간다** — 접촉이 풀린다.
			# 음높이에는 방향이 없다: 이 소리는 「풀림」에도 나므로
			# 내려가는 음(deny)과 섞이면 거절로 들린다
			var x := _chip(48.0, 262.0, 0.0045, 1150, 0.48)
			_lay(x, _wide(_air(5.5, 900.0, 1800.0, 0.9, 1161), 0.0016), 0.24)
			return _fade(x, 2.0)
		"rack_select":
			# 진열대는 **카드**다. 같은 음인데 칩이 아니라 판지가 선다 —
			# 표가 상점과 같은 f 를 주었으니 재질이 둘을 갈라야 한다
			var x := _blank(_n(48.0))
			_lay(x, _fade(_dec(_atk(_air(3.0, 5200.0, 3100.0, 2.2, 1151),
					0.3), 0.0009), 0.8), 0.60)
			_lay(x, _brst(40.0, 4.0, 349.333, 349.333, 12.0, 1171, 0.2), 0.40)
			_addat(x, _pt(40.0, 349.333, [[1.0, 0.30, 0.0060],
					[2.76, 0.10, 0.0022]], 1.0))
			return _fade(x, 2.0)
		"rack_deselect":
			var x := _blank(_n(48.0))
			_lay(x, _fade(_dec(_atk(_air(3.0, 3100.0, 4700.0, 2.2, 1152),
					0.3), 0.0009), 0.8), 0.54)
			_lay(x, _brst(40.0, 4.0, 262.0, 262.0, 12.0, 1172, 0.2), 0.36)
			_addat(x, _pt(40.0, 262.0, [[1.0, 0.30, 0.0060],
					[2.76, 0.10, 0.0022]], 1.0))
			return _fade(x, 2.0)
		"rack_move":
			# 자리를 바꾼다. 가장 자주 나는 소리다 — **릴 디텐트 한 칸.**
			# 392 는 SFX_BASE 다: 어긋나면 정산 사다리와 음이 안 맞는다.
			# 5.5ms 공백이 종결감을 만드는 유일한 수단이다(여운으로 안 늘린다)
			var x := _blank(_n(48.0))
			_lay(x, _fade(_dec(_atk(_air(2.0, 4200.0, 4200.0, 2.6, 1153),
					0.2), 0.0006), 0.5), 0.30)
			_lay(x, _detent(40.0, 392.0, 1164, 1.00, 0.34), 1.00, 5.5)
			return _fade(x, 2.5)
		_:
			return PackedFloat32Array()


func _b_menu(nm: String) -> PackedFloat32Array:
	match nm:
		# ══ 메뉴 ═════════════════════════════════════════
		#  **슬롯 릴과 레버.** 누르는 자리는 릴이 한 칸 걸리는 디텐트고,
		#  런을 세우는 자리는 레버가 내려가 빗장이 걸리는 소리고, 고르는
		#  자리에는 작은 종이 한 번 울린다. 8kHz 위에는 아무것도 두지 않는다.
		"newrun_open":
			# 칩 랙을 꺼내 뚜껑을 연다. 접촉이 두 번이다.
			# 알맹이를 880~1760 에 두고 440 을 낮췄다 — 이 소리는 menu_pick 과
			# **같은 프레임에 난다**(_open_newrun 이 부르고 돌아와 pick 을 낸다)
			var x := _blank(_n(95.0))
			# 랙 뚜껑이 얇은 금속 원판이다. 나무 통(1 : 2.00 : 3.01 : 4.00)이던
			# 자리다 — **배음렬**이라 2·3·4배 봉우리가 기음보다 +1.1dB 세게 서서
			# 440Hz 상자가 통째로 울었고 에너지의 절반이 440 한 점에 있었다.
			# 비배음으로 갈고 기음을 0.55 → 0.40 으로 낮춘다
			_addat(x, _pt(90.0, 440.0, _rat(DISC, [0.40, 0.80, 0.48, 0.22],
					[0.016, 0.015, 0.010, 0.006]), 0.8))
			_lay(x, _chip(30.0, 523.0, 0.0040, 13, 0.40), 0.30)
			_lay(x, _clk(20.0, 3.0, 900.0, 900.0, 1.0, 0.0025, 11, 0.3), 0.30)
			_addat(x, _pt(60.0, 440.0, _rat(DISC, [0.12, 0.26, 0.16, 0.07],
					[0.010, 0.011, 0.008, 0.004]), 0.8), 22.0)
			_lay(x, _chip(24.0, 392.0, 0.0035, 14, 0.34, 0.8), 0.22, 22.0)
			_lp(x, 7000.0)
			return _fade(x, 5.0)
		"pack_flip":
			# 카드를 딜한다. 스윅-톡 34ms 에 칩 하나가 받는다 —
			# 0.45초 슬라이드를 소리로 따라가지 않는다
			var x := _blank(_n(62.0))
			var sc := _air(34.0, 2400.0, 950.0, 1.1, 21, 34.0)
			_atk(sc, 1.5)
			_dec(sc, 0.016)
			_lin(sc, 30.0)
			_drive(sc, 1.25)
			_lay(x, sc, 1.00)
			_lay(x, _chip(40.0, 196.0, 0.0060, 22, 0.34), 0.55, 6.0)
			_lp(x, 7500.0)
			return _fade(x, 3.0)
		"league_pick":
			# 종이 한 번 울린다 — 고른 것이 확정됐다는 표시.
			# 알맹이가 1443Hz(nominal 위)라 deny 와 붙어 나도 안 섞인다
			var x := _bell(64.0, 523.0, 0.022, 1.0, 0.4)
			_lay(x, _clk(12.0, 2.0, 620.0, 620.0, 1.4, 0.0018, 31, 0.3), 0.30)
			_lp(x, 7500.0)
			return _fade(x, 3.0)
		"run_start":
			# **레버가 내려간다.** 빗장이 걸리고 릴이 물린다.
			# 300~2500Hz 를 비워 둔다 — 바로 뒤 leg_open 의 392→523 오름이
			# 이 위에 그대로 올라탄다. 길이는 표의 d(0.06) 다
			var x := _blank(_n(62.0))
			_addat(x, _one(58.0, 178.0, 160.0, 0.015, 1.0))
			_addat(x, _pt(50.0, 247.0, [[1.0, 0.55, 0.012]], 1.0))
			_addat(x, _pt(58.0, 98.0, [[1.0, 0.40, 0.018]], 1.0))
			_drive(x, 1.4)
			_lay(x, _clk(16.0, 4.0, 3200.0, 2600.0, 1.8, 0.0025, 41, 0.3), 0.45)
			_lay(x, _detent(30.0, 196.0, 42, 0.60, 0.24), 0.45, 26.0)
			return _fade(x, 8.0)
		"menu_pick":
			# 릴이 한 칸 걸린다. 딸깍 둘에 판스프링이 튕기고 낮은 툭이 받는다
			var x := _blank(_n(96.0))
			_lay(x, _detent(60.0, 523.0, 51, 1.00, 0.34), 1.00)
			_lay(x, _clk(20.0, 2.0, 2200.0, 2200.0, 1.6, 0.0030, 52), 0.26, 9.0)
			_addat(x, _pt(80.0, 175.0, [[1.0, 0.25, 0.020]], 0.8))
			_lp(x, 7000.0)
			_drive(x, 1.8)
			return _fade(x, 3.0)
		"menu_pick2":
			# 마른 디텐트 하나. 판스프링도 툭도 얕다 — 1초에 대여섯 번
			# 눌리는 자리라 남는 것이 있으면 드르륵이 된다
			var x := _blank(_n(42.0))
			_lay(x, _detent(34.0, 392.0, 61, 1.00, 0.18), 1.00)
			_lp(x, 7500.0)
			_hp(x, 300.0)
			_drive(x, 2.2)
			return _fade(x, 2.0)
		"menu_back":
			# 물린 것이 풀린다. 딸깍이 pick 의 3200 보다 낮아(1900) 둔하고,
			# 판스프링이 **역순으로** 튕긴다 — 풀림은 한 번에 떨어진다
			var x := _blank(_n(60.0))
			_lay(x, _clk(28.0, 2.5, 1900.0, 1900.0, 1.4, 0.0032, 71), 1.00)
			_addat(x, _pt(56.0, 440.0, [[1.0, 0.42, 0.016],
					[2.76, 0.18, 0.0060]], 0.5))
			_addat(x, _pt(50.0, 165.0, [[1.0, 0.20, 0.016]], 0.8))
			_lp(x, 6000.0)
			return _fade(x, 4.0)
		"back":
			# 칩 한 장을 물려 놓는다. **금속도 종도 안 넣는다** — 상한 3000Hz
			# 로 이 가족의 바닥을 만든다(점토는 쇠도 종도 아니다).
			# 테이블 노크였던 자리다: 330Hz 배음렬에 3kHz 상한이면 속 빈 나무
			# 상자고, 둘째 봉우리가 -18.8dB 아래라 음정만 남아 이 파일 에너지의
			# 97.7% 가 330±25Hz 한 점에 있었다
			var x := _chip(50.0, 330.0, 0.0070, 82, 0.46)
			_lay(x, _clk(20.0, 2.5, 700.0, 700.0, 1.0, 0.0025, 81, 0.3), 0.50)
			# 펠트가 받는다 — 나무 몸통이 빠진 앞 50ms 를 음정 없이 메운다.
			# 안 넣으면 _norm_rms 가 올려서 피크가 표의 a 의 3.2배로 튄다
			var ft := _air(34.0, 1100.0, 480.0, 0.8, 83)
			_atk(ft, 2.0)
			_lin(ft, 2.0)
			_lay(x, ft, 0.45)
			_lp(x, 3000.0)
			return _fade(x, 3.0)
		"page":
			# 카드 한 장이 넘어간다. **음정이 없다** — 사인 한 개도 없이
			# 결 두 겹뿐이다. 중심을 3200/3600 으로 내리고 상한을 5200 3단으로
			# 묶었다: 전에 이 자리가 5kHz 위에 에너지의 절반을 두고 있었다
			var x := _blank(_n(34.0))
			var ga := _air(9.0, 1700.0, 3200.0, 1.4, 91)
			_atk(ga, 1.0)
			_dec(ga, 0.006)
			_lay(x, _fade(ga, 1.5), 1.00)
			var gb := _air(13.0, 2100.0, 3600.0, 1.4, 92)
			_atk(gb, 1.0)
			_dec(gb, 0.006)
			_lay(x, _fade(gb, 1.5), 0.55, 11.0)
			_hp(x, 800.0)
			_lp(x, 5200.0, 3)
			return _fade(x, 2.0)
		_:
			return PackedFloat32Array()
