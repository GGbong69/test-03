extends SceneTree
# ══════════════════════════════════════════════════════════
#  늦게 도착한 총합 — **박자가 0 인가 · 값이 맞는 자리에서 나는가** (2026-09-26)
#
#  실행:  godot --headless --path . --script scripts/tools/qa_total.gd
#  종료 코드 = 실패 개수
#
#  왜 있는가
#    합계 걸음에 층을 넷 얹었다(띠 굴림 · 흔들림 · 음정 · 색). 넷 다 「이미
#    비어 있던 시간 안에서만」 난다는 것이 계약이고, 한 판에 정산 걸음이
#    수십 번 나므로 **걸음이 한 프레임이라도 늘면 런 전체가 늘어진다.**
#    그래서 이 자의 본문은 「좋아 보이는가」가 아니라 **「걸음 벽시계 길이가
#    크기와 무관하게 같은가」**다.
#
#  무엇이 기계적 증거인가
#    넷 중 qt 를 건드리는 줄이 하나도 없다는 것은 ① 이 프레임으로 증명한다 —
#    r 을 0.02 에서 50.0 까지 밀어도 걸음 프레임이 서로 1 안이면 qt 에 손댄
#    줄이 없다는 뜻이다. 그리고 ② 가 「창 ÷ qt」를 부등식으로 재므로
#    **새 벽시계 상수가 하나라도 박혔으면 beat 0.015 에서만 터진다** —
#    curve_probe 가 실제로 그 값을 쓴다.
#
#  ⚠ 오토플레이는 beat 를 0.10 으로 눌러 도니 도구가 찍는 프레임 수를
#    그대로 인용하면 3.4배 틀린다. 여기는 전부 손으로 큐를 세운다.
# ══════════════════════════════════════════════════════════
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")

var g = null
var ok := 0
var bad := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_total_g.cfg"
	Save.path = "user://_qa_total.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	_run()
	print("\n통과 %d · 실패 %d" % [ok, bad])
	quit(bad)


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-48s %s" % ["통과" if cond else "실패", nm, note])


func _calm() -> void:
	g.swap_live = false
	g.photo = ""
	g.photo_rack = ""
	g._tutor_close()
	g.tutor_id = ""
	g.tutor_q.clear()
	g.tutor_out = 0.0
	g.pause_from = -1
	g.hand_st = g.H.NONE
	g._autoplay = false
	Dev.on = false
	g.fast_lock = false
	g.fast_mul = 2.5
	g.motion_off = false
	g.grow_roll = 1.0
	g.grow_shake = 1.0
	g.link_mode = 3


#  합계 걸음 하나를 손으로 세운다. r = last_gain ÷ target 이 그대로 서도록
#  **target 을 1000 으로 못 박고 두 칸을 그 비에 맞춘다.**
#  ⚠ 점수·배수·목표를 게임이 정하는 자리는 한 글자도 안 건드린다 — 여기서
#    세우는 것은 검사대 위의 값이다.
func _stage_total(r: float, pace_load: int) -> void:
	g.set_process(false)
	g._start_leg()
	g._card_reset()
	g.target = 1000
	g.total = 0
	g.shown = 0.0
	g.cur_chip = int(round(r * 1000.0))
	g.cur_mult = 1
	g.score_mul = 1.0
	g.score_mode = "std"
	g.card_mode = 0
	g.calc_lit = false
	g.roll_t = -1.0
	g.pitch_step = 0
	g.queue.clear()
	g.queue.append({"k": "total"})
	g.settle_n = pace_load
	g.burst_n = 0
	g.burst_hits.clear()
	g.card_side = 1
	g.card_y = 74.0
	g.card_p = 1.0
	g.card_target = 1.0
	g.hitstop = 0.0
	g.state = g.S.RESOLVE
	g.qt = g.beat * g._pace()
	g.gold = 50
	_calm()


#  한 걸음을 끝까지 돌린다. 걸음이 바뀌는 프레임(pitch_step 증가) 하나로만
#  잰다 — qa_fast 가 세운 자와 같다.
func _play_step(hold_fast: bool) -> Dictionary:
	var frames := 0
	var roll_f := 0            # score_roll 이 살아 있던 프레임
	var shake_f := 0           # shake 가 살아 있던 프레임
	var shk_max := 0.0
	var qt0: float = g.qt
	g.fast_lock = hold_fast
	while g.state == g.S.RESOLVE and frames < 4000:
		g._process(1.0 / 60.0)
		frames += 1
		if g.score_roll > 0.0:
			roll_f += 1
		if g.shake > 0.0:
			shake_f += 1
		shk_max = maxf(shk_max, g.shake)
	g.fast_lock = false
	return {"frames": frames, "roll": roll_f, "shake": shake_f,
			"shk": shk_max, "qt0": qt0, "shown": g.shown, "total": g.total,
			"score_roll": g.score_roll}


func _spread(a: Array) -> int:
	var lo := 999999
	var hi := 0
	for v in a:
		lo = mini(lo, int(v))
		hi = maxi(hi, int(v))
	return hi - lo


func _run() -> void:
	g._new_run()
	_calm()

	# ── ① 걸음 벽시계 길이가 크기와 무관하다 ─────────────
	#  「박자 0」의 본체다. 다섯 층 중 하나라도 qt 를 건드렸으면 여기서 터진다.
	#
	#  ⚠ **갈래를 갈라서 잰다 — 처음엔 안 갈랐다가 한 번 틀렸다.** r ≥ 1.0 은
	#  이 걸음에서 목표를 넘기므로 게임이 **손대기 전부터** qt 를 2.6 → 3.4 로
	#  늘린다(판이 끝나는 자리라 길게 둔 것이다). 다섯 크기를 한 줄에 놓고
	#  재면 75 ↔ 91 프레임이 나오는데 그건 내 층이 아니라 그 갈래다.
	#  갈래 안에서 서로 1 안이면 「내가 더한 프레임이 0」이 증명된다.
	#  덤: 안 넘기는 무리 안에 「한 방」 문턱(0.50)이 들어 있어 **hitstop 이
	#  걸음 벽시계에 중립**이라는 계약(qt 에서 같은 값을 뺀다)도 같이 잠긴다.
	var sizes := [0.02, 0.50, 1.00, 2.00, 50.0]
	var lo_r := [0.02, 0.10, 0.49, 0.90]     # 목표를 안 넘긴다
	var hi_r := [1.00, 2.00, 50.0]           # 이 걸음에서 목표를 넘긴다
	var fr_lo := []
	var fr_hi := []
	for r in lo_r:
		_stage_total(float(r), 1)
		fr_lo.append(int(_play_step(false).frames))
	for r in hi_r:
		_stage_total(float(r), 1)
		fr_hi.append(int(_play_step(false).frames))
	_ok("① 안 넘기는 합계 걸음 길이가 크기와 무관하다", _spread(fr_lo) <= 1,
			"r %s → %s프레임" % [lo_r, fr_lo])
	_ok("①-b 목표를 넘기는 걸음도 크기와 무관하다", _spread(fr_hi) <= 1,
			"r %s → %s프레임" % [hi_r, fr_hi])

	# ── ② 굴림 창이 언제나 걸음 안에서 끝난다 ────────────
	#  창÷qt 를 스무 갈래에서 잰다. **새 벽시계 상수가 하나라도 박혔으면
	#  beat 0.015 에서만 터진다** — curve_probe 가 그 값을 쓴다.
	var beat0: float = g.beat
	var worst := 0.0
	var best := 9.9
	var where := ""
	for r in sizes:
		for bt in [0.34, 0.015]:
			for ld in [1, 40]:
				g.beat = bt
				_stage_total(float(r), int(ld))
				g.beat = bt
				var st := _play_step(false)
				var ratio: float = float(st.roll) / maxf(float(st.frames), 1.0)
				if ratio > worst:
					worst = ratio
					where = "r%.2f beat%.3f load%d" % [r, bt, ld]
				best = minf(best, ratio)
	g.beat = beat0
	_ok("② 굴림 창이 걸음 안에서 끝난다", worst <= 1.0,
			"최대 %.3f (%s) · 최소 %.3f" % [worst, where, best])

	# ── ③ 정산이 끝나면 굴림이 0 이고 띠가 total 에 **정확히** 선다 ──
	var exact := true
	var note := ""
	for r in sizes:
		_stage_total(float(r), 1)
		var st := _play_step(false)
		if st.score_roll > 0.0 or int(round(float(st.shown))) != int(st.total) \
				or not is_equal_approx(float(st.shown), float(st.total)):
			exact = false
			note = "r%.2f shown %.4f ≠ total %d" % [r, st.shown, st.total]
	_ok("③ 굴림이 끝나면 띠가 total 에 정확히 선다", exact, note)

	# ── ③-b 무한 R34 의 18자리에서도 정확히 선다 ──────────
	#  float64 의 정수 정확 구간은 9.0e15 까지다. lerp 왕복이 남긴 오차가
	#  int(round(shown)) 에서 total 과 갈릴 수 있는 자리다.
	_stage_total(1.0, 1)
	g.target = 512000000000000000          # 5.12e17 · 18자리
	g.cur_chip = 256000000000000000
	g.cur_mult = 2
	var big := _play_step(false)
	_ok("③-b 18자리에서도 띠가 정확히 선다",
			is_equal_approx(float(big.shown), float(big.total))
			and big.score_roll <= 0.0,
			"shown %.1f · total %d" % [big.shown, big.total])

	# ── ③-c settle_probe ④ 의 경로가 그대로 산다 ─────────
	#  score_roll 이 0 인 채 _tick_score 를 600번 직접 부르는 길이다.
	#  새 갈래가 그 단언을 뒤집으면 여기서 먼저 터진다.
	g.total = 45
	g.target = 45
	g.shown = 0.0
	g.score_roll = 0.0
	for _i in 600:
		g._tick_score(1.0 / 60.0)
	_ok("③-c 걸음 밖 띠는 손대기 전 그대로다",
			g.shown == 45.0 and int(round(g.shown)) == 45,
			"shown %.4f" % g.shown)

	# ── ④ 빨리 보기 2.5배 — 값은 같고 프레임만 준다 ────────
	var fast_ok := true
	var fnote := ""
	for r in sizes:
		_stage_total(float(r), 1)
		var slow := _play_step(false)
		_stage_total(float(r), 1)
		var fast := _play_step(true)
		var ratio: float = float(slow.frames) / maxf(float(fast.frames), 1.0)
		if slow.total != fast.total or not is_equal_approx(
				float(slow.shown), float(fast.shown)) \
				or ratio < 2.35 or ratio > 2.65:
			fast_ok = false
			fnote = "r%.2f %d→%d프레임 %.2f배 · 띠 %.2f↔%.2f" \
					% [r, slow.frames, fast.frames, ratio, slow.shown, fast.shown]
	_ok("④ 빨리 보기 — 값은 같고 프레임만 준다", fast_ok, fnote)

	# ── ⑤ 흔들림이 r 에 단조 증가하고 천장 12.0 을 안 넘는다 ──
	#  위계를 한 칸도 안 깬다: 불 11.0 < 천장 12.0 < 목표돌파 13.0 <
	#  판 깨짐 14.0 < 불속불 15.0. 판이 끝나는 자리가 가장 세다는 계약이 산다.
	var mono := true
	var span := true
	var prev := -1.0
	var lo := 99.0
	var hi := 0.0
	for j in 50:
		var rr: float = pow(10.0, lerpf(-3.0, 2.0, float(j) / 49.0))
		g.target = 1000
		g.last_gain = int(round(rr * 1000.0))
		var n: float = g._grow_n()
		var sh: float = lerpf(float(g.GROW.shk_lo), float(g.GROW.shk_hi), n * n)
		if sh < prev - 0.0001:
			mono = false
		prev = sh
		lo = minf(lo, sh)
		hi = maxf(hi, sh)
		if sh < 6.0 - 0.0001 or sh > 12.0 + 0.0001:
			span = false
	_ok("⑤ 흔들림이 단조 증가하고 6.0~12.0 안이다", mono and span,
			"%.2f ~ %.2f" % [lo, hi])
	_ok("⑤-b 천장이 목표돌파 13.0 밑이다", hi < 13.0, "천장 %.2f" % hi)

	# ── ⑥ 작은 값이 조용하다 — **제곱을 잠근다** ───────────
	#  선형으로 되돌리면 이 줄이 깨진다. 제곱이 이 설계의 주장이다.
	g.target = 1000
	g.last_gain = 50                       # r 0.05 = 바닥
	var n_lo: float = g._grow_n()
	g.last_gain = 110                      # 실측 p25
	var n_p25: float = g._grow_n()
	var s_p25: float = lerpf(6.0, 12.0, n_p25 * n_p25)
	g.last_gain = 216                      # 실측 p50
	var n_p50: float = g._grow_n()
	var s_p50: float = lerpf(6.0, 12.0, n_p50 * n_p50)
	_ok("⑥ 바닥(r 0.05)이 정확히 6.0", is_equal_approx(n_lo, 0.0),
			"n %.4f" % n_lo)
	_ok("⑥-b p25 가 바닥 위 0.30 안", s_p25 - 6.0 < 0.30,
			"%.3f (바닥 위 %.3f)" % [s_p25, s_p25 - 6.0])
	_ok("⑥-c p50 이 오늘 9.0 보다 조용하다", s_p50 < 9.0,
			"%.3f" % s_p50)

	# ── ⑦ 빨리 보기에서 흔들림이 걸음을 안 넘긴다 ───────────
	#  shake 감쇠는 fast_rate 를 **안 탄다**(그 규약은 착탄·거절·판 깨짐이
	#  같이 쓰므로 안 바꾼다). 12.0 수명 0.353초 ≤ 빨리 보기 합계 걸음
	#  0.354초 — **여유가 0 이다.** 13.0 을 넣으면 여기서 실패한다.
	var life: float = 12.0 / 34.0
	var stepw: float = g.beat * 2.6 / 2.5
	_ok("⑦ 빨리 보기에서 흔들림이 걸음을 안 넘긴다", life <= stepw + 0.0001,
			"수명 %.4f초 ≤ 걸음 %.4f초" % [life, stepw])
	#  ── ⑦-b 멈춤이 만든 누수의 크기 (2026-09-26) ───────────
	#  ⚠ **위 ⑦ 의 리터럴은 한 글자도 안 고쳤다** — 그것은 계약이다. 그런데
	#  그 모형에 hitstop 이 **없다**: 멈춤이 걸린 프레임에서 _process 가 통째로
	#  조기 반환하므로 그 동안 shake 감쇠가 안 돌고, _draw 는 randf_range 를
	#  계속 굴린다.
	#
	#  ⚠ **처음엔 예산에서 멈춤을 빼는 모형을 적었다가 틀렸다.** 걸음 벽시계는
	#  멈춤과 **무관**하다 — 같은 줄에서 qt 에서 빼므로 (걸음−멈춤)/2.5 +
	#  멈춤/2.5 = 걸음/2.5 로 멈춤이 상쇄된다. 그게 이 설계의 요지다.
	#  틀린 것은 예산이 아니라 **수명** 쪽이었다: 손대기 전 수명은
	#  멈춤/2.5 + 12/34 라 예산을 그만큼 넘는다.
	#  4단(멈춤 0.120)이면 0.048 + 0.353 = 0.401초 대 예산 0.354초 —
	#  **2.8프레임 적자**다. 그래서 _process 의 멈춤 블록 안에
	#  `if stop_fire: shake = maxf(shake - d * 34.0, 0.0)` 한 줄을 넣어
	#  수명을 멈춤과 무관하게 만들었다.
	var stop4: float = float(g.CARDFX.stop) * 2.0        # 4단 = ×2.0
	var leak: float = stop4 / 2.5 + life - stepw
	_ok("⑦-b 손대기 전 모형은 4단에서 실제로 샌다(수선의 까닭)", leak > 0.0,
			"수명 %.4f초 − 걸음 %.4f초 = 적자 %.4f초(%.2f프레임)"
			% [stop4 / 2.5 + life, stepw, leak, leak * 60.0])
	#  ⚠ 그 수선이 **실제로 코드에 들어 있는가**를 프레임으로 잰다. 위 두 줄은
	#  산수고 이 줄은 실측이다 — 4단 멈춤을 걸고 걸음 끝에서 shake 가 0 인가.
	#  ⚠⚠ **세움을 r 0.90 → 1.90 으로 올리고 목표 위에서 출발시켰다(2026-09-26 ·
	#  되짚어 고침).** r 0.90 이면 shake 가 9.68 밖에 안 서서 수명 0.285초가 빨리
	#  보기 걸음 0.354초 안에 멈춤을 얹어도 다 죽는다 — 즉 이 줄이 **수선이 없어도
	#  초록**이었다(실측 · 고친 뒤 끝 0.0000 · 손대기 전 끝도 0.0000). 갈리는 자리는
	#  shake 가 천장(12.0)에 붙는 r ≳ 1.6 이고 **돌파가 아닌** 걸음이다. total 을
	#  목표 **위**에서 출발시켜 was_short 를 거짓으로 만든다(돌파는 shake 13.0 과
	#  qt 3.4 갈래라 이 줄이 재려는 것과 섞인다). qa_fire ⑥ 도 같은 날 같이 고쳤다.
	_stage_total(1.90, 1)
	g.total = g.target * 5
	g.shown = float(g.total)
	g.fire_lock = 4
	var st7 := _play_step(true)
	g.fire_lock = -1
	_ok("⑦-c 4단 · 빨리 보기에서 걸음 끝 흔들림이 0 이다",
			g.shake <= 0.0001, "끝 shake %.3f · 걸음 %d프레임" % [g.shake, st7.frames])

	# ── ⑧ 연발 — 대입(=) 규약이 지켜진다 ─────────────────
	#  maxf 로 바꾸면 걸음마다 쌓여 천장을 넘긴다. 대입이면 걸음마다 다시
	#  세워졌다 죽는다. 목표를 **안 넘기는** 값으로 세워야 13.0(목표돌파)이
	#  섞이지 않는다 — 처음엔 섞여서 이 줄이 아무것도 안 재고 있었다.
	_stage_total(0.90, 1)
	var one := _play_step(false)
	_stage_total(0.90, 40)                 # pace 바닥
	g.target = 1000000                     # 여섯 걸음이 목표를 안 넘게 연다
	g.queue.clear()
	for _b in 6:
		g.queue.append({"k": "total"})
	g.settle_n = 40
	var fr2 := 0
	var shk_hi := 0.0
	while g.state == g.S.RESOLVE and fr2 < 4000:
		g._process(1.0 / 60.0)
		fr2 += 1
		shk_hi = maxf(shk_hi, g.shake)
	_ok("⑧ 걸음이 이어져도 흔들림이 안 쌓인다",
			shk_hi <= float(g.GROW.shk_hi) + 0.0001,
			"여섯 걸음 최대 %.2f ≤ 천장 %.2f · 한 걸음 %.2f"
			% [shk_hi, g.GROW.shk_hi, one.shk])

	# ── ⑧-b 연발은 **구조적으로** 조용하다 ────────────────
	#  _chip_gain 이 kick_share 를 먹여 작은 다트의 r 을 그만큼 떨어뜨린다.
	#  그래서 **음정이 내려가는 발과 박자가 눌리는 발이 반비례**한다.
	#  그리고 그 크기에서는 흔들림 수명이 눌린 걸음보다 **짧아** 걸음 사이에
	#  화면이 한 번 선다 — 오늘 9.0 고정은 수명 0.2647초가 눌린 걸음
	#  0.2652초와 사실상 같아서 **한 번도 안 서던 자리**다.
	var share: float = float(GameData.tune("kick_share"))
	g.target = 1000
	g.last_gain = 216                      # 실측 중앙값 r 0.216
	var n_base: float = g._grow_n()
	g.last_gain = int(round(216.0 * share))
	var n_burst: float = g._grow_n()
	var s_burst: float = lerpf(6.0, 12.0, n_burst * n_burst)
	var step_lo: float = g.beat * 2.6 * float(g.PACE.min)
	_ok("⑧-b 연발 작은 다트가 더 조용하다", n_burst < n_base,
			"n %.3f → %.3f (share %.2f)" % [n_base, n_burst, share])
	_ok("⑧-c 그 크기에서는 걸음 사이에 화면이 선다",
			s_burst / 34.0 < step_lo and 9.0 / 34.0 >= step_lo - 0.001,
			"수명 %.4f초 < 눌린 걸음 %.4f초 (오늘 9.0 은 %.4f초)"
			% [s_burst / 34.0, step_lo, 9.0 / 34.0])

	# ── ⑨ 음정 — 새로 굽지 않았고 n=0 이 오늘 그대로다 ───────
	var p0 := pow(2.0, -float(g.GROW.semi) * 0.0 / 12.0)
	var p1 := pow(2.0, -float(g.GROW.semi) * 1.0 / 12.0)
	_ok("⑨ n=0 의 음정이 정확히 1.000", is_equal_approx(p0, 1.0), "%.4f" % p0)
	_ok("⑨-b n=1 이 완전5도(0.667) 위다", p1 > 0.66 and p1 < 0.67, "%.4f" % p1)
	_ok("⑨-c 꼬리가 가장 짧은 합계 걸음 안이다",
			0.34 / p1 < g.beat * 2.6, "%.3f초 < %.3f초" % [0.34 / p1, g.beat * 2.6])
	#  ── ⑨-c2 빈 박이 늦춘 만큼 꼬리가 밀린다 (2026-09-26) ───
	#  4단은 이 소리를 멈춤이 풀리는 프레임으로 늦춘다(0.120초 = 7.2프레임).
	#  그만큼 꼬리가 뒤로 밀리므로 **여유 수를 새로 적는다** — pace 1.00 에서
	#  시작 f7.2 · 끝 f37.7 이라 걸음 53.0 안이지만 위 ⑨-c 의 여유가
	#  2.9프레임 준다. 통과는 하지만 근거가 달라졌으므로 따로 잠근다.
	var tail4: float = float(g.CARDFX.stop) * 2.0 + 0.34 / p1
	_ok("⑨-c2 늦춘 꼬리도 합계 걸음 안이다", tail4 < g.beat * 2.6,
			"멈춤 %.3f + 꼬리 %.3f = %.3f초 < 걸음 %.3f초 (여유 %.1f프레임)"
			% [float(g.CARDFX.stop) * 2.0, 0.34 / p1, tail4, g.beat * 2.6,
			(g.beat * 2.6 - tail4) * 60.0])
	#  ⚠ settle_total 은 표 밑음이 196 이라 wav 가 없으면 beep 갈래가 f 를
	#  절대 Hz 로 받아 한 옥타브 위로 난다(board_thud · shop_smash 와 같은
	#  어긋남이다). 파일이 사는 한 그 갈래가 죽어 있으므로 여기서 못 박는다.
	_ok("⑨-d settle_total.wav 가 실재한다",
			ResourceLoader.exists("res://sfx/settle_total.wav"))
	_ok("⑨-e 정산 표를 한 글자도 안 고쳤다",
			is_equal_approx(float(g.SFX["settle_total"].f), 196.0)
			and is_equal_approx(float(g.SFX["settle_step"].f), float(g.SFX_BASE)),
			"total %.0f · step %.0f" % [g.SFX["settle_total"].f,
					g.SFX["settle_step"].f])

	# ── ⑩ 모션 끄기 — 움직임만 죽고 빛·소리는 산다 ──────────
	#  띠가 **한 프레임도 안 기어간다**: 걸음이 값을 세우는 그 프레임부터
	#  shown 이 곧 total 이다. 걸음 내내 재서 한 번이라도 어긋나면 진다.
	_stage_total(0.90, 1)
	g.motion_off = true
	var lag_fr := 0
	var mo_shake := 0.0
	var mo_fr := 0
	while g.state == g.S.RESOLVE and mo_fr < 4000:
		g._process(1.0 / 60.0)
		mo_fr += 1
		if absf(g.shown - float(g.total)) > 0.0001:
			lag_fr += 1
		mo_shake = maxf(mo_shake, g.shake)
	var mo_total: int = g.total
	g.motion_off = false
	#  ⚠ **한 프레임은 어긋난다 — 재 보고 알았다.** _tick_score 가 _process 의
	#  앞쪽에 있고 _next_step 은 그 뒤 S.RESOLVE 갈래에서 도므로, 걸음이 서는
	#  그 프레임에는 total 이 이미 오른 뒤 띠가 아직 안 읽었다. 다음 프레임에
	#  붙는다. 손대기 전에도 같은 순서였고 60fps 에서 눈에 안 띈다 — 순서를
	#  바꾸는 것은 _process 전체를 건드리는 일이라 여기 계약으로 못 박는다.
	_ok("⑩ 모션 끄기 — 띠가 한 프레임 넘게 안 기어간다",
			lag_fr <= 1 and mo_total > 0,
			"어긋난 프레임 %d / %d · total %d" % [lag_fr, mo_fr, mo_total])
	#  ⚠ 소리와 색은 안 죽는다. 음정은 motion_off 를 한 글자도 안 읽는다.
	_ok("⑩-b 모션 끄기가 음정을 안 건드린다",
			is_equal_approx(pow(2.0, -float(g.GROW.semi) * 1.0 / 12.0), p1))
	_ok("⑩-c 모션 끄기에서도 흔들림 값은 선다",
			mo_shake >= float(g.GROW.shk_lo) - 0.0001, "%.2f" % mo_shake)

	# ── ⑪ 되돌리기가 샌 자리가 없다 ─────────────────────
	_stage_total(2.00, 1)
	g._process(1.0 / 60.0)
	g._card_reset()
	_ok("⑪ 판이 바뀌면 굴림과 선이 안 남는다",
			g.score_roll == 0.0 and g.score_from == 0.0
			and g.src_t == 0.0 and g.src_slot == -1
			and is_equal_approx(g.score_div, float(g.GROW.div_lo)),
			"roll %.2f · from %.1f · src_t %.2f · slot %d"
			% [g.score_roll, g.score_from, g.src_t, g.src_slot])

	# ── ⑫ 점수와 보상이 한 톨도 안 바뀐다 ────────────────
	#  _grow_n 이 last_gain 과 target 을 **읽기만** 하는지. 이 줄이 밸런스
	#  금지선이다.
	g.target = 1000
	g.last_gain = 777
	var lg0: int = g.last_gain
	var tg0: int = g.target
	for _k in 20:
		g._grow_n()
	_ok("⑫ 자가 점수와 목표를 안 건드린다",
			g.last_gain == lg0 and g.target == tg0,
			"%d / %d" % [g.last_gain, g.target])
