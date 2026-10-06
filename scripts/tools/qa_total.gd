extends SceneTree
# ══════════════════════════════════════════════════════════
#  늦게 도착한 총합 — **박자가 0 인가 · 값이 맞는 자리에서 나는가** (2026-09-26)
#
#  실행:  godot --headless --path . --script scripts/tools/qa_total.gd
#  종료 코드 = 실패 개수
#
#  왜 있는가
#    합계 걸음에 층을 넷 얹었다(띠 굴림 · 흔들림 · 음정 · 색). 넷 다 「걸음
#    시간 안에서만」 난다는 것이 계약이고, 한 판에 정산 걸음이 수십 번 나므로
#    **층이 걸음을 한 프레임이라도 늘리면 런 전체가 늘어진다.**
#    걸음 길이는 _tot_qt 한 곳이 정한다(2026-10-06) — 크기(gn)만큼 길어지고
#    (beat × (TALLY.tot + TALLY.tot_gn × gn)) 돌파는 beat × TALLY.brk 고정이다.
#    그래서 이 자의 본문은 **「걸음 벽시계 길이가 그 식 그대로인가」**다.
#
#  무엇이 기계적 증거인가
#    넷 중 qt 를 건드리는 줄이 하나도 없다는 것은 ① 이 프레임으로 증명한다 —
#    r 을 0.02 에서 50.0 까지 밀어도 걸음 프레임이 식에서 1 안이면 qt 에 손댄
#    줄이 없다는 뜻이다. 그리고 ② 가 「창 ÷ qt」를 부등식으로 재므로
#    **새 벽시계 상수가 하나라도 박혔으면 beat 0.015 에서만 터진다** —
#    curve_probe 가 실제로 그 값을 쓴다.
#
#  ⚠ 오토플레이는 beat 를 0.10 으로 눌러 도니 도구가 찍는 프레임 수를
#    그대로 인용하면 3.4배 틀린다. 여기는 전부 손으로 큐를 세운다.
#
#  ①~⑬ 은 _initialize 에서, ⑭(띠 톡 · 2026-10-06) · ⑮(착지)는 첫 틀에서 돈다 —
#  톡을 tick_pl 에서, 착지 소리를 자리 넷에서 들어야 하는데 그 자리는 Game 의
#  _ready 가 세운다.
#
#  합계 걸음은 머리가 「+0」으로 조용하고, lead 뒤 카드 「+n」과 상단 띠가 한 굴림을
#  타고 오르며 끝값에 닿는 프레임(착지 · _tally_land)에 내리친다(2026-10-06).
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
	#  ⑭ 는 첫 틀에서 잰다 — 소리 자리(sfx_pool · tick_pl)는 Game 의 _ready 가
	#  세우는데, _initialize 안에서는 루트가 아직 나무에 안 들어가 그것이 안 돌았다
	#  (qa_power 와 같은 길).


var busy := false


func _process(_d: float) -> bool:
	if g != null:
		g.set_process(false)
	if busy:
		return false
	busy = true
	_run_tick()
	print("\n통과 %d · 실패 %d" % [ok, bad])
	quit(bad)
	return false


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
#    frames   머리 숨 + 합계 걸음 전체 프레임
#    step     합계 걸음만의 프레임(걸음이 선 프레임 다음부터 끝 프레임까지)
#    nom      걸음이 선 프레임의 이름값 qt + hitstop(멈춤은 qt 에서 빠진다)
func _play_step(hold_fast: bool) -> Dictionary:
	var frames := 0
	var roll_f := 0            # score_roll 이 살아 있던 프레임
	var shake_f := 0           # shake 가 살아 있던 프레임
	var shk_max := 0.0
	var qt0: float = g.qt
	var step_f := 0
	var nom := -1.0
	g.fast_lock = hold_fast
	while g.state == g.S.RESOLVE and frames < 4000:
		var ps0: int = g.pitch_step
		g._process(1.0 / 60.0)
		frames += 1
		if nom >= 0.0:
			step_f += 1
		elif g.pitch_step > ps0:
			nom = float(g.qt) + float(g.hitstop)
		if g.score_roll > 0.0:
			roll_f += 1
		if g.shake > 0.0:
			shake_f += 1
		shk_max = maxf(shk_max, g.shake)
	g.fast_lock = false
	return {"frames": frames, "roll": roll_f, "shake": shake_f,
			"shk": shk_max, "qt0": qt0, "shown": g.shown, "total": g.total,
			"score_roll": g.score_roll, "step": step_f, "nom": nom}


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

	# ── ① 걸음 벽시계 길이가 _tot_qt 의 식 그대로다 ─────────
	#  다섯 층 중 하나라도 qt 를 건드렸으면 여기서 터진다.
	#  안 넘기는 걸음은 크기(gn)만큼 길어진다(2026-10-06): 프레임이 r 을 따라
	#  **안 줄고**, 하나하나가 60 × beat × (TALLY.tot + TALLY.tot_gn × gn) 에서
	#  1 안이다(멈춤 프레임의 올림 하나까지 +1). 이름값(qt + hitstop)은 식과 같다.
	#
	#  ⚠ **갈래를 갈라서 잰다 — 처음엔 안 갈랐다가 한 번 틀렸다.** r ≥ 1.0 은
	#  이 걸음에서 목표를 넘기므로 qt 가 beat × TALLY.brk 로 선다(판이 끝나는
	#  자리라 크기와 무관하게 길게 둔다). 그 갈래 안에서는 서로 1 안이다.
	#  덤: 안 넘기는 무리 안에 「한 방」 문턱(0.50)이 들어 있어 **hitstop 이
	#  걸음 벽시계에 중립**이라는 계약(qt 에서 같은 값을 뺀다)도 같이 잠긴다.
	var sizes := [0.02, 0.50, 1.00, 2.00, 50.0]
	var lo_r := [0.02, 0.10, 0.49, 0.90]     # 목표를 안 넘긴다
	var hi_r := [1.00, 2.00, 50.0]           # 이 걸음에서 목표를 넘긴다
	var tl: Dictionary = g.TALLY
	var fr_lo := []
	var want_lo := []
	var lo_mono := true
	var lo_fit := true
	var nom_ok := true
	for r in lo_r:
		_stage_total(float(r), 1)
		var gn_r: float = g._grow_of(int(round(float(r) * 1000.0)))
		var want: float = g.beat * (float(tl.tot) + float(tl.tot_gn) * gn_r)
		var st1 := _play_step(false)
		var f1: int = int(st1.step)
		if not fr_lo.is_empty() and f1 < int(fr_lo[fr_lo.size() - 1]):
			lo_mono = false
		if f1 < int(floor(want * 60.0)) or f1 > int(ceil(want * 60.0)) + 1:
			lo_fit = false
		if absf(float(st1.nom) - want) > 0.0005:
			nom_ok = false
		fr_lo.append(f1)
		want_lo.append(snappedf(want * 60.0, 0.1))
	var fr_hi := []
	var want_hi: float = g.beat * float(tl.brk)
	var hi_fit := true
	for r in hi_r:
		_stage_total(float(r), 1)
		var st2 := _play_step(false)
		fr_hi.append(int(st2.step))
		if absf(float(st2.nom) - want_hi) > 0.0005:
			hi_fit = false
	_ok("① 안 넘기는 합계 걸음이 크기를 따라 안 준다", lo_mono,
			"r %s → %s프레임" % [lo_r, fr_lo])
	_ok("①-a 그 프레임이 _tot_qt 의 식에서 1 안이다", lo_fit and nom_ok,
			"%s프레임 · 식 %s" % [fr_lo, want_lo])
	_ok("①-b 목표를 넘기는 걸음은 크기와 무관하다",
			_spread(fr_hi) <= 1 and hi_fit,
			"r %s → %s프레임 · 식 %.1f" % [hi_r, fr_hi, want_hi * 60.0])

	# ── ①-c 모음 걸음이 합계 앞에 제 길이만큼 선다 (2026-10-06) ──
	#  [합계] 와 [모음, 합계] 를 같은 값으로 돌린다. 걸음별 프레임은 pitch_step 으로
	#  가른다(0 머리 숨 · 1 · 2). 합계 걸음은 두 큐에서 같은 프레임이고, 전체는
	#  그 위에 모음 걸음(beat × TALLY.wind)만큼 는다.
	#  「+n」은 머리에서 「+0」이고(봉우리 없음 · 착지 대기) 착지 프레임에 처음 끝값에
	#  선다 — 그 사이는 한 번도 안 내려가고 끝값 밑이다(2026-10-06).
	var segs := []
	var slam_ok := true
	var slam_txt := ""
	for wq in [false, true]:
		_stage_total(0.40, 1)
		if wq:
			g.queue.push_front({"k": "wind"})
			g.settle_n = 2
		var seg := [0, 0, 0]
		var cf := 0
		var live0 := false
		var cg_prev := -1
		var landed := 0
		var vals := {}
		while g.state == g.S.RESOLVE and cf < 4000:
			var ps1: int = g.pitch_step
			g._process(1.0 / 60.0)
			cf += 1
			seg[mini(g.pitch_step, 2)] += 1
			if g.pitch_step > ps1 and g.card_mode == 1:
				if g.last_gain <= 0 or g._card_gain() != 0 or g.gain_roll > 0.0 \
						or not g.land_live:
					slam_ok = false
				slam_txt += "머리 +%d · " % g._card_gain()
				cg_prev = 0
			elif g.card_mode == 1 and g.land_live:
				var cv: int = g._card_gain()
				if cv < cg_prev or cv >= g.last_gain:
					slam_ok = false
				cg_prev = cv
				vals[cv] = true
			if live0 and not g.land_live:
				landed += 1
				if g._card_gain() != g.last_gain or not is_equal_approx(g.gain_roll, 1.0):
					slam_ok = false
				slam_txt += "센 값 %d가지 · 착지 +%d/%d · " % [vals.size(), g._card_gain(),
						g.last_gain]
			live0 = g.land_live
		if landed != 1 or vals.size() < 10:
			slam_ok = false
		segs.append(seg)
	var tot_bare: int = int(segs[0][1])
	var wd_f: int = int(segs[1][1])
	var tot_wd: int = int(segs[1][2])
	var wd_want: float = g.beat * float(tl.wind) * 60.0
	_ok("①-c 모음 걸음이 합계 앞에 제 길이로 선다",
			tot_wd == tot_bare and int(segs[1][0]) == int(segs[0][0])
			and wd_f >= int(floor(wd_want)) and wd_f <= int(ceil(wd_want)) + 1,
			"머리 %d · 모음 %d (식 %.1f) · 합계 %d ↔ 모음 없이 %d"
			% [segs[1][0], wd_f, wd_want, tot_wd, tot_bare])
	_ok("①-d 「+n」이 머리에서 +0 이고 세어 올라 착지 프레임에 처음 끝값이다",
			slam_ok and slam_txt != "", slam_txt)

	# ── ①-e 「+n」 봉우리가 크기를 따라 안 줄고 카드 안에 든다 (2026-10-06) ──
	#  크기 = 36 × (1 + amt × gain_roll²) · amt = amt_tot0 + amt_tot_gn × gn +
	#  amt_tot × 자릿수(상한 amt_tot_cap). 봉우리는 착지 프레임(gain_roll 1)이다.
	#  잉크 윗변은 바닥선(total_mid 의 36 자리) − ascent × INK.num 으로 잰다 —
	#  카드 판 윗변(0) 밑이어야 한다. 몸이 뜨면 판과 글자가 같이 뜨므로 이 차는
	#  카드 자리(74 · 206)와 리프트에 안 매인다.
	#  ⚠ 이 도구는 _initialize 에서 돌아 _ready 전이라 g.font 가 비어 있다 — 그러면
	#  _ink_mid_y 가 ascent 를 크기로 어림한다. 재는 동안만 진짜 글꼴을 쥐여 준다.
	var font0 = g.font
	if g.font == null:
		g.font = load(g.FONT_PATH)
	var pk_prev := 0
	var pk_mono := true
	var pk_max := 0
	var pk_txt := ""
	g.target = 1000
	g.gain_roll = 1.0
	for rr in [0.001, 0.01, 0.05, 0.10, 0.216, 0.50, 1.0, 2.0, 10.0, 100.0, 1000.0]:
		g.last_gain = int(round(float(rr) * 1000.0))
		var pz: int = g._gain_sz()
		if pz < pk_prev:
			pk_mono = false
		pk_prev = pz
		pk_max = maxi(pk_max, pz)
		pk_txt += "%d " % pz
	var cap_sz: int = int(36.0 * (1.0 + float(g.CARDFX.amt_tot_cap)))
	var base_y: float = g._ink_mid_y(float(g.CARDTXT.total_mid), 36)
	var ink_top: float = -1.0
	if g.font != null:
		ink_top = base_y - g.font.get_ascent(pk_max) * float(g.INK.num)
	g.font = font0
	_ok("①-e 봉우리가 크기를 따라 안 준다 · 상한 안이다",
			pk_mono and pk_max <= cap_sz and pk_max > 36, "%s(상한 %d)" % [pk_txt, cap_sz])
	_ok("①-f 가장 큰 봉우리의 잉크가 카드 안이다", ink_top >= 0.0,
			"%dpx · 바닥선 %.1f − 잉크 %.1f = 윗변 %.1f"
			% [pk_max, base_y, base_y - ink_top, ink_top])
	g.motion_off = true
	var mo_sz: int = g._gain_sz()
	g.motion_off = false
	g.gain_roll = 0.0
	_ok("①-g 모션 끄기 · 앉은 뒤에는 36px 이다",
			mo_sz == 36 and g._gain_sz() == 36, "모션 끔 %d · 앉음 %d" % [mo_sz, g._gain_sz()])

	# ── ② 굴림 창이 언제나 걸음 안에서 끝난다 ────────────
	#  창÷qt 를 스무 갈래에서 잰다. **새 벽시계 상수가 하나라도 박혔으면
	#  beat 0.015 에서만 터진다** — curve_probe 가 그 값을 쓴다.
	#  합계 걸음은 짐(load)을 안 탄다 — 짐 40 은 머리 숨만 누른다. pace 바닥의
	#  합계 걸음은 연발 중간 발 하나뿐이라(TALLY.mid × _pace()) 그 갈래를 따로
	#  세운다: 남은 작은 다트를 하나 두고, 그 다트가 꽂히는 프레임(burst_hits 가
	#  비는 프레임)에서 끊는다. total 을 목표 위에서 출발시켜 돌파 갈래를 뺀다.
	var beat0: float = g.beat
	var worst := 0.0
	var best := 9.9
	var where := ""
	for r in sizes:
		for bt in [beat0, 0.015]:
			for ld in [1, 40, -1]:
				g.beat = bt
				_stage_total(float(r), maxi(int(ld), 1))
				g.beat = bt
				var roll_n := 0
				var len_n := 0
				if int(ld) > 0:
					var st := _play_step(false)
					roll_n = int(st.roll)
					len_n = int(st.frames)
				else:
					g.total = g.target * 5
					g.shown = float(g.total)
					g.burst_hits = [g.BC]
					g.burst_n = GameData.tune_i("kick_n")
					var on := false
					for _f in 4000:
						var ps0: int = g.pitch_step
						g._process(1.0 / 60.0)
						if (g.burst_hits as Array).is_empty():
							break
						if not on and g.pitch_step > ps0:
							on = true
						if on:
							len_n += 1
							if g.score_roll > 0.0:
								roll_n += 1
				var ratio: float = float(roll_n) / maxf(float(len_n), 1.0)
				if ratio > worst:
					worst = ratio
					where = "r%.2f beat%.3f %s" % [r, bt,
							"연발 중간" if int(ld) < 0 else "load%d" % ld]
				best = minf(best, ratio)
	g.beat = beat0
	_ok("② 굴림 창이 걸음 안에서 끝난다", worst <= 1.0 and best > 0.0,
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
	#  목표를 넘는 프레임은 TALLY.cross_shk(7)로 낮췄다 — 오르는 띠가 읽히게 착지
	#  흔들림 천장(12.0) 밑에 둔다(2026-10-06 · 그 전에는 13.0 이 천장 위였다).
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
	_ok("⑤-b 목표를 넘는 프레임 흔들림이 착지 천장 밑이다",
			float(g.TALLY.cross_shk) < hi and float(g.TALLY.cross_shk) > 0.0,
			"넘기 %.2f < 천장 %.2f" % [float(g.TALLY.cross_shk), hi])

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

	# ── ⑦ 흔들림이 걸음을 안 넘긴다 — 정산이 끝나는 프레임에서 잰다 (2026-10-06) ──
	#  shake 감쇠는 fast_rate 를 **안 탄다**(그 규약은 착탄·거절·판 깨짐이
	#  같이 쓰므로 안 바꾼다). 흔들림은 착지(걸음의 0.78 ~ 0.82 · 돌파 0.65)와 목표를
	#  넘는 프레임에 서므로, 빨리 보기이거나 판이 끝나는 걸음에서는 _shk_room 이 남은
	#  걸음으로 묶는다. gn 0 · 0.5 · 1(돌파) · 1(목표 위에서 출발 — 판이 끝나는 보통
	#  합계)을 2.5배로, 판이 끝나는 둘은 1배로도 돌려 정산이 끝나는 프레임의 shake 를 잰다.
	var life: float = 12.0 / 34.0
	var sh_ok := true
	var sh_txt := ""
	for cs in [[0.05, false, true], [0.316, false, true], [2.0, false, true],
			[2.0, true, true], [2.0, false, false], [2.0, true, false]]:
		_stage_total(float(cs[0]), 1)
		if bool(cs[1]):
			g.total = g.target * 5
			g.shown = float(g.total)
		var st7a := _play_step(bool(cs[2]))
		if g.shake > 0.0001 or float(st7a.shk) <= 0.0:
			sh_ok = false
		sh_txt += "r%.2f%s%s 봉우리 %.2f 끝 %.3f · " % [float(cs[0]),
				"(위)" if bool(cs[1]) else "", " 2.5배" if bool(cs[2]) else " 1배",
				float(st7a.shk), g.shake]
	_ok("⑦ 빨리 보기 · 판이 끝나는 걸음은 정산이 끝나는 프레임에 흔들림이 0", sh_ok, sh_txt)
	#  ── ⑦-a 1배 · 판이 안 끝나는 걸음은 착지 흔들림을 안 묶는다 ──
	#  착지 프레임(land_live 가 내려가는 프레임)의 shake 가 lerp(shk_lo, shk_hi, gn²) 그대로다.
	_stage_total(0.316, 1)
	var lv7 := false
	var shk7 := -1.0
	var gn7 := -1.0
	for _f7 in 4000:
		if g.state != g.S.RESOLVE:
			break
		g._process(1.0 / 60.0)
		if lv7 and not g.land_live and shk7 < 0.0:
			shk7 = g.shake
			gn7 = g._grow_n()
		lv7 = g.land_live
	var want7: float = lerpf(float(g.GROW.shk_lo), float(g.GROW.shk_hi), gn7 * gn7)
	_ok("⑦-a 1배 · 판이 안 끝나는 착지 흔들림은 식 그대로다", gn7 > 0.0
			and absf(shk7 - want7) < 0.001, "gn %.2f · 착지 %.3f · 식 %.3f" % [gn7, shk7, want7])
	#  ── ⑦-b 멈춤이 만든 누수의 크기 (2026-09-26) ───────────
	#  ⚠ **고치기 전 모형을 그때 리터럴로 남긴다**(beat 0.34 · 합계 2.6박) — 수선의
	#  까닭을 적는 줄이라 지금 박자로 바꾸면 이유 없이 빨개진다. 그 모형에
	#  hitstop 이 **없다**: 멈춤이 걸린 프레임에서 _process 가 통째로
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
	var stepw: float = 0.34 * 2.6 / 2.5                  # 그때의 빨리 보기 합계 걸음
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
	#  qt TALLY.brk 갈래라 이 줄이 재려는 것과 섞인다). qa_fire ⑥ 도 같은 날 같이 고쳤다.
	#  ⚠ 합계 걸음이 gn 으로 길어진 뒤(2026-10-06)로는 지금 박자에서 수선이 없어도
	#  다 죽는다. 그래서 **박자를 눌러 걸음을 그때 길이(0.34 × 2.6박 = 0.884초)에
	#  맞춘다** — 여유 0 인 자리에서 재야 수선이 빠졌을 때 빨개진다.
	var beat7: float = g.beat
	_stage_total(1.90, 1)
	g.beat = 0.34 * 2.6 / (float(tl.tot) + float(tl.tot_gn) * g._grow_of(1900))
	g.total = g.target * 5
	g.shown = float(g.total)
	g.fire_lock = 4
	var st7 := _play_step(true)
	g.fire_lock = -1
	g.beat = beat7
	_ok("⑦-c 4단 · 빨리 보기에서 걸음 끝 흔들림이 0 이다",
			g.shake <= 0.0001, "끝 shake %.3f · 걸음 %d프레임 (이름값 %.3f초)"
			% [g.shake, st7.step, st7.nom])

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
	#  화면이 한 번 선다 — 옛 9.0 고정은 수명 0.2647초가 그때 눌린 걸음
	#  (0.34 × 2.6 × 0.30 = 0.2652초)과 사실상 같아서 **한 번도 안 서던 자리**다.
	#  눌린 합계 걸음은 이제 연발 중간 발(TALLY.mid × PACE.min)이다(2026-10-06).
	var share: float = float(GameData.tune("kick_share"))
	g.target = 1000
	g.last_gain = 216                      # 실측 중앙값 r 0.216
	var n_base: float = g._grow_n()
	g.last_gain = int(round(216.0 * share))
	var n_burst: float = g._grow_n()
	var s_burst: float = lerpf(6.0, 12.0, n_burst * n_burst)
	var step_lo: float = g.beat * float(tl.mid) * float(g.PACE.min)
	_ok("⑧-b 연발 작은 다트가 더 조용하다", n_burst < n_base,
			"n %.3f → %.3f (share %.2f)" % [n_base, n_burst, share])
	#  옛 9.0 고정의 수명 9 ÷ 34 = 0.2647초 · 그때 눌린 걸음 0.34 × 2.6 × 0.30 = 0.2652초 —
	#  사실상 같았다(기록이다 · 단언이 아니다).
	_ok("⑧-c 그 크기에서는 걸음 사이에 화면이 선다",
			s_burst / 34.0 < step_lo,
			"수명 %.4f초 < 눌린 걸음 %.4f초" % [s_burst / 34.0, step_lo])

	# ── ⑨ 음정 — 새로 굽지 않았고 n=0 이 오늘 그대로다 ───────
	var p0 := pow(2.0, -float(g.GROW.semi) * 0.0 / 12.0)
	var p1 := pow(2.0, -float(g.GROW.semi) * 1.0 / 12.0)
	_ok("⑨ n=0 의 음정이 정확히 1.000", is_equal_approx(p0, 1.0), "%.4f" % p0)
	_ok("⑨-b n=1 이 완전5도(0.667) 위다", p1 > 0.66 and p1 < 0.67, "%.4f" % p1)
	#  ── ⑨-c 꼬리가 다음 발의 착탄 전에 끝난다 (2026-10-06) ──
	#  settle_total 은 착지 프레임에 난다 — 그 뒤 가장 짧은 틈은 gn 0 합계 걸음의 남은
	#  몫((1 − land_lo) × beat × tot) + 다음 발의 확인 텀(confirm_hold) + 날기(fly_time)다.
	#  확인을 눌러 넘겨도 그 사이에 조준 두 축이 든다.
	var tot_lo: float = g.beat * float(tl.tot)
	var gap_lo: float = (1.0 - float(tl.land_lo)) * tot_lo \
			+ float(GameData.tune("confirm_hold")) + float(GameData.tune("fly_time"))
	_ok("⑨-c 꼬리가 다음 발의 착탄 전에 끝난다",
			0.34 / p1 < gap_lo, "꼬리 %.3f초 < 착지 뒤 %.3f초" % [0.34 / p1, gap_lo])
	#  ── ⑨-c2 빈 박이 늦춘 만큼 꼬리가 밀린다 (2026-09-26) ───
	#  4단은 이 소리를 멈춤이 풀리는 프레임으로 늦춘다(0.120초 = 7.2프레임).
	#  그만큼 꼬리가 뒤로 밀리므로 **여유 수를 따로 적는다** — 위 ⑨-c 의 여유가
	#  7.2프레임 준다. 근거가 다르므로 따로 잠근다.
	var tail4: float = float(g.CARDFX.stop) * 2.0 + 0.34 / p1
	_ok("⑨-c2 늦춘 꼬리도 다음 발의 착탄 전에 끝난다", tail4 < gap_lo,
			"멈춤 %.3f + 꼬리 %.3f = %.3f초 < 착지 뒤 %.3f초 (여유 %.1f프레임)"
			% [float(g.CARDFX.stop) * 2.0, 0.34 / p1, tail4, gap_lo,
			(gap_lo - tail4) * 60.0])
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
	#  띠와 「+n」이 **한 프레임도 안 기어간다**: lead 동안은 떠난 자리(+0)에 섰다가
	#  lead 가 끝나는 프레임에 끝값으로 뛰고, 그 프레임이 착지다(2026-10-06).
	#  걸음 내내 재서 사이 값이 한 프레임이라도 보이면 진다.
	_stage_total(0.90, 1)
	g.shown = 50.0
	g.total = 50
	g.motion_off = true
	var mid_fr := 0
	var mo_shake := 0.0
	var mo_fr := 0
	var mo_from := 50.0
	var jump_f := -1
	var land_f := -1
	var mo_live := false
	while g.state == g.S.RESOLVE and mo_fr < 4000:
		g._process(1.0 / 60.0)
		mo_fr += 1
		var on_from: bool = absf(g.shown - mo_from) < 0.0001 and g._card_gain() == 0
		var on_end: bool = absf(g.shown - float(g.total)) < 0.0001 \
				and g._card_gain() == g.last_gain
		if g.card_mode == 1 and not on_from and not on_end:
			mid_fr += 1
		if g.card_mode == 1 and on_end and jump_f < 0:
			jump_f = mo_fr
		if mo_live and not g.land_live:
			land_f = mo_fr
		mo_live = g.land_live
		mo_shake = maxf(mo_shake, g.shake)
	var mo_total: int = g.total
	g.motion_off = false
	_ok("⑩ 모션 끄기 — 띠 · 「+n」이 사이 값 없이 끝값으로 뛰고 그 프레임이 착지다",
			mid_fr == 0 and mo_total > 50 and jump_f > 0 and land_f == jump_f,
			"사이 값 %d프레임 / %d · 뛴 프레임 %d · 착지 %d · total %d"
			% [mid_fr, mo_fr, jump_f, land_f, mo_total])
	#  ⚠ 소리와 색은 안 죽는다. 음정은 motion_off 를 한 글자도 안 읽는다.
	_ok("⑩-b 모션 끄기가 음정을 안 건드린다",
			is_equal_approx(pow(2.0, -float(g.GROW.semi) * 1.0 / 12.0), p1))
	_ok("⑩-c 모션 끄기에서도 흔들림 값은 선다",
			mo_shake >= float(g.GROW.shk_lo) - 0.0001, "%.2f" % mo_shake)

	# ── ⑪ 되돌리기가 샌 자리가 없다 ─────────────────────
	#  굴림 · 넘기 · 착지가 다 걸려 있는 프레임(돌파 걸음의 lead 안)에서 접는다.
	_stage_total(2.00, 1)
	for _f11 in 400:
		g._process(1.0 / 60.0)
		if g.land_live and g.cross_live:
			break
	var armed11: bool = g.land_live and g.cross_live and g.tick_n > 0
	g._card_reset()
	_ok("⑪ 판이 바뀌면 굴림 · 넘기 · 착지와 선이 안 남는다", armed11 and
			g.score_roll == 0.0 and g.score_from == 0.0
			and g.src_t == 0.0 and g.src_slot == -1
			and is_equal_approx(g.score_div, g._tally_div(0.0, false))
			and not g.land_live and not g.cross_live and g.tick_n == 0,
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

	# ── ⑬ 개발자 미리보기 둘이 게임과 같은 걸음 길이를 세운다 (2026-10-06) ──
	#  「한 방」(_card_big)과 「총합 걸음 다시 보기」가 식을 손으로 베끼면 크기로
	#  자라는 길이가 미리보기에서만 갈린다. 같은 값(r 0.90 · 목표 안 넘김)을 게임
	#  걸음과 _card_big 에 태워 이름값(qt + hitstop)을 대고, 다시 보기 네 단은
	#  _tot_qt 의 식과 댄다.
	_stage_total(0.90, 1)
	var nom_game: float = float(_play_step(false).nom)
	_stage_total(0.90, 1)
	Dev._card_big(g)
	var nom_dev: float = float(g.qt) + float(g.hitstop)
	Dev.card_ph = 0
	Dev.card_back = {}
	var gr_ok := true
	var gr_txt := ""
	for ci in (Dev.GROW_R as Array).size():
		_stage_total(0.90, 1)
		Dev.pick["grow"] = ci
		Dev._run(g, {"k": "grow"})
		var gw: float = g.beat * (float(tl.tot) + float(tl.tot_gn) * g._grow_n())
		if absf(float(g.qt) - gw) > 0.0005:
			gr_ok = false
		gr_txt += "%.3f/%.3f " % [g.qt, gw]
	g._card_reset()
	_ok("⑬ 「한 방」이 게임 걸음과 같은 길이를 세운다",
			nom_game > 0.0 and absf(nom_dev - nom_game) < 0.0005,
			"게임 %.4f초 · 한 방 %.4f초" % [nom_game, nom_dev])
	_ok("⑬-b 「총합 걸음 다시 보기」 네 단이 _tot_qt 의 식이다", gr_ok, gr_txt)
	#  ── ⑬-c 「한 방」이 카드 · 띠를 (총점 − 이득) → 총점으로 굴리고 착지에서 멈춘다 ──
	#  판 점수를 안 더하는 미리보기라 떠난 자리를 이득만큼 내려 둔다 — 「총합 걸음
	#  다시 보기」와 같은 자리다. 착지는 게임 쪽 _tally_land 가 낸다(이득 900 ≥ 목표의 반이라
	#  멈춤이 선다). 총점은 한 톨도 안 바뀐다.
	_stage_total(0.90, 1)
	g.queue.clear()
	g.total = 950
	g.shown = 950.0
	Dev._card_big(g)
	var bg_from: float = g.score_from
	var bg_head: bool = g.land_live and g._card_gain() == 0 \
			and absf(bg_from - (950.0 - float(g.last_gain))) < 0.001
	var bg_land := false
	var bg_hs := 0.0
	var bg_mid := false
	var lvb: bool = g.land_live
	for _fb in 900:
		g._process(1.0 / 60.0)
		if g.land_live and g.shown > bg_from + 1.0 and g.shown < 949.0 \
				and g._card_gain() > 0 and g._card_gain() < g.last_gain:
			bg_mid = true
		if lvb and not g.land_live:
			bg_land = absf(g.shown - 950.0) < 0.001 and g._card_gain() == g.last_gain
			bg_hs = g.hitstop
		lvb = g.land_live
		if Dev.card_ph != 2:
			break
	var bg_tot: int = g.total
	Dev.card_ph = 0
	Dev.card_back = {}
	g._card_reset()
	g.hitstop = 0.0
	_ok("⑬-c 「한 방」이 카드 · 띠를 (총점 − 이득)에서 굴려 착지에서 멈춘다",
			bg_head and bg_mid and bg_land and bg_hs > 0.0 and bg_tot == 950,
			"떠난 자리 %.0f · 머리 %s · 중간 %s · 착지 %s · 멈춤 %.3f · 총점 %d"
			% [bg_from, bg_head, bg_mid, bg_land, bg_hs, bg_tot])
	#  ── ⑬-d 개발자 굴림 배 1.5 · 2 도 착지가 걸음 안이다(TALLY.land_max) ──
	#  굴림 창을 늘리는 사다리라 묶지 않으면 착지 · 금이 걸음 끝을 넘는다. 바닥(gn 0)과
	#  돌파(r 2)에서 착지가 정산이 끝나는 프레임보다 앞이고 걸음의 land_max 몫 안이다.
	var gr2_ok := true
	var gr2_txt := ""
	for grv in [1.5, 2.0]:
		for rr2 in [0.05, 2.0]:
			_stage_total(float(rr2), 1)
			g.grow_roll = float(grv)
			var f2 := 0
			var st_f := -1
			var ld_f := -1
			var cr_f := -1
			var lv2 := false
			var cl2 := false
			while g.state == g.S.RESOLVE and f2 < 4000:
				var p2: int = g.pitch_step
				g._process(1.0 / 60.0)
				f2 += 1
				if g.pitch_step > p2 and st_f < 0:
					st_f = f2
				if lv2 and not g.land_live:
					ld_f = f2
				if cl2 and not g.cross_live:
					cr_f = f2
				lv2 = g.land_live
				cl2 = g.cross_live
			var frac: float = float(ld_f - st_f) / maxf(float(f2 - st_f), 1.0)
			if ld_f < 0 or ld_f >= f2 or frac > float(tl.land_max) + 0.03 \
					or (float(rr2) >= 1.0 and (cr_f < 0 or cr_f > ld_f)):
				gr2_ok = false
			gr2_txt += "×%.1f r%.2f 착지 %.2f · " % [float(grv), float(rr2), frac]
	g.grow_roll = 1.0
	_ok("⑬-d 굴림 배 1.5 · 2 도 착지 · 넘기가 걸음 안이다", gr2_ok, gr2_txt)


#  합계 걸음 하나를 돌리며 띠 톡을 **tick_pl 에서 듣는다.** 칸마다 음이 다르므로
#  (stream · pitch_scale) 이 바뀐 프레임이 곧 톡이 난 프레임이다. 착지 소리(settle_total)는
#  자리 넷에서 듣는다. above 면 total 을 목표 위에서 출발시켜 돌파 갈래(판 깨짐 소리)를 뺀다.
#    heard   톡이 난 프레임들 · coin  coin_land 가 tick_pl 에서 난 수(0 이어야 한다)
#    n       세운 칸 수 · rose  tick_i 가 오른 프레임 수 · jump  한 프레임에 칸이 둘
#            넘게 넘어간 적이 있나
#    start   합계 걸음이 선 프레임 · land  착지 프레임(land_live 가 내려간 프레임) ·
#    lands   착지 수 · st  settle_total 이 자리 넷에서 난 프레임들 · end  끝 프레임
#    moved   톡이 난 프레임에 sfx_next 가 돌았나(판이 끝나는 걸음은 판 깨짐 소리가
#            같은 프레임에 날 수 있다) · in_pool  자리 넷에서 score_tick · coin_land 가 났나
#    hs      착지 프레임의 멈춤 · qt_drop  착지 프레임에 qt 가 줄어든 몫 · rate  그 프레임 배수
#    shk_land  착지 프레임의 shake · shk_start  걸음이 선 프레임의 shake · shk_pre  그 앞 프레임
#    st_start  걸음이 선 프레임에 settle_total 이 났나 · sync  카드 「+n」과 띠가 같은 몫을
#            벗어난 프레임 수 · gain_n  카드가 지난 값 가짓수
#  gr 은 grow_roll 이다(_stage_total 의 _calm 이 1 로 되돌리므로 세운 뒤에 민다).
func _tick_play(r: float, fast: bool, mo: bool, above: bool, gr := 1.0) -> Dictionary:
	_stage_total(r, 1)
	if above:
		g.total = g.target * 5
		g.shown = float(g.total)
	g.motion_off = mo
	g.fast_lock = fast
	g.grow_roll = gr
	var tp: AudioStreamPlayer = g.tick_pl
	tp.stream = null
	tp.pitch_scale = 1.0
	var o := {"heard": [], "coin": 0, "n": 0, "rose": 0, "jump": false,
			"start": -1, "land": -1, "lands": 0, "st": [], "end": -1, "moved": false,
			"in_pool": false, "gn": -1.0, "hs": 0.0, "qt_drop": 0.0, "rate": 1.0,
			"shk_land": -1.0, "shk_start": -1.0, "shk_pre": 0.0, "st_start": false,
			"sync": 0, "gain_n": 0, "big": false}
	var key0 := _tick_key(tp)
	var f := 0
	var live0 := false
	var gains := {}
	while g.state == g.S.RESOLVE and f < 4000:
		var sn0: int = g.sfx_next
		var ti0: int = g.tick_i
		var ps0: int = g.pitch_step
		var qt0: float = g.qt
		var shk0: float = g.shake
		g._process(1.0 / 60.0)
		f += 1
		var news := _pool_new(sn0)
		if news.has("score_tick") or news.has("coin_land"):
			o.in_pool = true
		if news.has("settle_total"):
			(o.st as Array).append(f)
		if g.pitch_step > ps0:
			o.n = g.tick_n
			o.gn = g._grow_n()
			o.start = f
			o.shk_start = g.shake
			o.shk_pre = shk0
			o.st_start = news.has("settle_total")
			o.big = float(g.last_gain) >= float(g.CARDFX.big) * float(g.target)
		elif g.tick_i > ti0:
			o.rose += 1
			if g.tick_i - ti0 >= 2:
				o.jump = true
		if live0 and not g.land_live:
			o.lands += 1
			o.land = f
			o.hs = g.hitstop
			o.qt_drop = qt0 - g.qt
			o.rate = g.fast_rate
			o.shk_land = g.shake
		if g.land_live and g.card_mode == 1 and int(o.start) >= 0:
			gains[g._card_gain()] = true
			var span: float = float(g.total) - g.score_from
			if span > 0.0:
				var bar: float = (g.shown - g.score_from) / span
				var card: float = float(g._card_gain()) / float(maxi(g.last_gain, 1))
				if absf(bar - card) > 1.0 / float(maxi(g.last_gain, 1)) + 0.0001:
					o.sync += 1
		live0 = g.land_live
		var nm := _tick_name(tp)
		var key := _tick_key(tp)
		if key != key0:
			key0 = key
			if nm == "coin_land":
				o.coin += 1
			else:
				(o.heard as Array).append(f)
			if g.sfx_next != sn0:
				o.moved = true
	o.end = f
	o.gain_n = gains.size()
	g.fast_lock = false
	g.motion_off = false
	g.grow_roll = 1.0
	return o


#  자리 넷에서 sn0 뒤로 새로 난 소리 이름들(qa_break 와 같은 셈).
func _pool_new(sn0: int) -> Array:
	var pool: Array = g.sfx_pool
	var out := []
	if pool.is_empty():
		return out
	var dn: int = posmod(int(g.sfx_next) - sn0, pool.size())
	for k in dn:
		var sp: AudioStreamPlayer = pool[posmod(int(g.sfx_next) - dn + k, pool.size())]
		out.append("" if sp.stream == null
				else String(sp.stream.resource_path).get_file().get_basename())
	return out


func _tick_name(tp: AudioStreamPlayer) -> String:
	return "" if tp.stream == null \
			else String(tp.stream.resource_path).get_file().get_basename()


#  칸마다 음이 다르다 — 이 열쇠가 바뀐 프레임에 톡이 났다.
func _tick_key(tp: AudioStreamPlayer) -> String:
	return "%s@%.6f" % [_tick_name(tp), tp.pitch_scale]


#  칸 수의 식 — TALLY.tick0 + TALLY.tick_gn × gn 을 4 ~ 24 로 묶는다.
func _tick_want(gn: float) -> int:
	var tl: Dictionary = g.TALLY
	return clampi(int(round(float(tl.tick0) + float(tl.tick_gn) * gn)), 4, 24)


#  톡 사이 프레임들.
func _gaps(hd: Array) -> Array:
	var gaps := []
	for i in range(1, hd.size()):
		gaps.append(int(hd[i]) - int(hd[i - 1]))
	return gaps


func _run_tick() -> void:
	g._new_run()
	_calm()
	var tl: Dictionary = g.TALLY
	var gap_min: int = int(ceil(float(tl.tick_gap) - 0.001))

	# ── ⑭ 띠 톡 — 칸을 넘을 때 · 2프레임 밑으로 안 붙고 · 자리 넷 밖 (2026-10-06) ──
	#  카드 「+n」과 상단 띠는 창의 앞 TALLY.lead 를 선 채로 있다가 pow(k, TALLY.ease)로
	#  올라 끝값에 닿고, 값으로 고르게 놓인 칸을 넘을 때마다 톡(score_tick)이 난다.
	#  끝 칸은 톡이 아니라 착지(settle_total · 자리 넷)다 — coin_land 는 안 난다.
	#   · 톡 사이가 TALLY.tick_gap(2프레임) 밑이면 그 칸은 소리 없이 넘는다.
	#   · 1배 톡 사이가 안 넓어진다(프레임 올림 1 안) · 뒤 절반이 앞 절반보다 짧다.
	#   · 톡이 자리 넷에서 한 번도 안 난다. 판이 안 끝나는 걸음(판 깨짐 소리가 없다)에서는
	#     톡이 난 프레임에 sfx_next 가 아예 안 돈다.
	var tp = g.tick_pl
	var pool: Array = g.sfx_pool
	_ok("⑭ 띠 톡 자리가 섰고 자리 넷 밖이다",
			tp != null and pool.size() == 4 and not pool.has(tp),
			"tick_pl %s · 자리 %d" % [tp != null, pool.size()])
	if tp == null:
		return
	var one_ok := true
	var one_txt := ""
	var n_ok := true
	var gap_ok := true
	var gap_txt := ""
	var pool_ok := true
	var pool_txt := ""
	for rr in [[0.02, false], [0.216, false], [0.90, false], [2.0, true], [1.5, false]]:
		var o := _tick_play(float(rr[0]), false, false, bool(rr[1]))
		var hd: Array = o.heard
		var gaps := _gaps(hd)
		if hd.is_empty() or hd.size() > int(o.n) - 1 or int(o.coin) != 0 \
				or int(o.lands) != 1 or int(o.land) <= int(hd[hd.size() - 1]) \
				or int(o.land) > int(o.end) or int(o.rose) < hd.size() or int(o.n) < 4:
			one_ok = false
		if int(o.n) != _tick_want(float(o.gn)):
			n_ok = false
		one_txt += "r%.2f %d/%d칸 " % [float(rr[0]), hd.size(), int(o.n)]
		var h := floori(gaps.size() / 2.0)
		var s_lo := 0
		var s_hi := 0
		for i in gaps.size():
			if int(gaps[i]) < gap_min:
				gap_ok = false
			if i > 0 and int(gaps[i]) > int(gaps[i - 1]) + 1:
				gap_ok = false
			if i < h:
				s_lo += int(gaps[i])
			elif i >= gaps.size() - h:
				s_hi += int(gaps[i])
		if h < 2 or s_hi >= s_lo:
			gap_ok = false
		gap_txt += "%s " % [gaps]
		if bool(o.in_pool) or not bool(rr[1]) and float(rr[0]) < 1.0 and bool(o.moved):
			pool_ok = false
			pool_txt += "r%.2f 돎 %s · 앉음 %s " % [float(rr[0]), o.moved, o.in_pool]
	_ok("⑭-a 1배 — 칸마다 톡 · 끝 칸은 착지 · coin_land 0 · 걸음 안", one_ok, one_txt)
	_ok("⑭-b 칸 수가 식이다 (gn 0 → 6 · 1 → 22)",
			n_ok and _tick_want(0.0) == 6 and _tick_want(1.0) == 22,
			"식 %d · %d" % [_tick_want(0.0), _tick_want(1.0)])
	_ok("⑭-c 1배 톡 사이가 %d프레임 밑으로 안 가고 갈수록 좁아진다" % gap_min, gap_ok, gap_txt)
	#  2.5배 — 칸을 소리 없이 넘는 프레임이 실제로 있어야(rose > heard) 이 줄이 뜻이 있다.
	var fast_ok := true
	var skipped := false
	var fast_txt := ""
	for rr2 in [[0.216, false], [2.0, true]]:
		var o2 := _tick_play(float(rr2[0]), true, false, bool(rr2[1]))
		var hd2: Array = o2.heard
		for gp in _gaps(hd2):
			if int(gp) < gap_min:
				fast_ok = false
		if hd2.is_empty() or hd2.size() > int(o2.n) - 1 or int(o2.lands) != 1 \
				or int(o2.coin) != 0 or int(o2.land) > int(o2.end):
			fast_ok = false
		if int(o2.rose) > hd2.size() + 1 or bool(o2.jump):
			skipped = true
		if bool(o2.in_pool) or not bool(rr2[1]) and bool(o2.moved):
			pool_ok = false
			pool_txt += "2.5배 r%.2f 돎 %s · 앉음 %s " % [float(rr2[0]), o2.moved, o2.in_pool]
		fast_txt += "r%.2f %d/%d칸 %s · 걸음 %d프레임 " % [float(rr2[0]), hd2.size(),
				int(o2.n), _gaps(hd2), int(o2.end)]
	_ok("⑭-d 2.5배 — 붐비는 칸은 소리 없이 넘고(톡 사이 %d프레임 이상) 착지는 난다" % gap_min,
			fast_ok and skipped, fast_txt + ("· 넘긴 칸 있음" if skipped else "· 넘긴 칸 없음"))
	var om := _tick_play(0.90, false, true, false)
	_ok("⑭-e 모션 끄기 — 톡 없이 착지 소리 하나가 lead 끝 프레임에 난다",
			(om.heard as Array).is_empty() and int(om.lands) == 1
			and (om.st as Array) == [int(om.land)] and int(om.land) > int(om.start),
			"톡 %d · 착지 %d번 · settle_total %s · 착지 %d (걸음 %d)"
			% [(om.heard as Array).size(), int(om.lands), om.st, int(om.land), int(om.start)])
	_ok("⑭-f 톡은 자리 넷을 안 돈다", pool_ok, pool_txt)

	#  ── ⑭-g 연발 중간 발(가장 짧은 합계 걸음 · 2.5배)에서도 착지가 걸음 안에서 난다 ──
	#  score_roll 이 한 프레임에 크게 줄어 hold 를 건너 0 에 닿을 수 있는 자리다. 다음
	#  다트가 꽂히면(_land → _card_reset) 착지가 접히므로 그 프레임까지 났어야 한다 —
	#  착지 소리(settle_total)를 자리 넷에서 듣는다. 톡도 2프레임 밑으로 안 붙는다.
	_stage_total(0.216, 1)
	g.total = g.target * 5
	g.shown = float(g.total)
	g.burst_hits = [g.BC]
	g.burst_n = GameData.tune_i("kick_n")
	g.fast_lock = true
	tp.stream = null
	tp.pitch_scale = 1.0
	var mk0 := _tick_key(tp)
	var mid_land := false
	var mid_n := 0
	var mid_hd := []
	var mf := 0
	for _f in 4000:
		var msn: int = g.sfx_next
		g._process(1.0 / 60.0)
		mf += 1
		if int(g.tick_n) > 0:
			mid_n = int(g.tick_n)
		if _pool_new(msn).has("settle_total"):
			mid_land = true
		var mk := _tick_key(tp)
		if mk != mk0:
			mk0 = mk
			mid_hd.append(mf)
		if (g.burst_hits as Array).is_empty():
			break
	g.fast_lock = false
	var mid_gap := true
	for gp in _gaps(mid_hd):
		if int(gp) < gap_min:
			mid_gap = false
	_ok("⑭-g 연발 중간 발 2.5배 — 다음 다트 전에 착지가 나고 톡이 안 붙는다",
			mid_land and mid_n >= 4 and mid_gap, "칸 %d · 톡 %s" % [mid_n, _gaps(mid_hd)])

	#  ── ⑭-h 개발자 미리보기 둘이 같은 칸을 세운다 · 접으면 칸도 접힌다 ──
	var o_g := _tick_play(0.90, false, false, false)
	_stage_total(0.90, 1)
	Dev._card_big(g)
	var big_n: int = g.tick_n
	var big_ok: bool = big_n == int(o_g.n) and g.tick_i == 0 and g.score_roll == 1.0
	Dev.card_ph = 0
	Dev.card_back = {}
	var gr_ok := true
	var gr_txt := ""
	for ci in (Dev.GROW_R as Array).size():
		_stage_total(0.90, 1)
		Dev.pick["grow"] = ci
		Dev._run(g, {"k": "grow"})
		if int(g.tick_n) != _tick_want(g._grow_n()) or int(g.tick_i) != 0:
			gr_ok = false
		gr_txt += "%d " % int(g.tick_n)
	g._card_reset()
	_ok("⑭-h 「한 방」 · 「총합 걸음 다시 보기」가 게임과 같은 칸을 세운다",
			big_ok and gr_ok, "한 방 %d (게임 %d) · 다시 보기 %s" % [big_n, int(o_g.n), gr_txt])
	_ok("⑭-i 접으면 칸도 접힌다", g.tick_n == 0 and g.tick_i == 0,
			"칸 %d · 난 칸 %d" % [g.tick_n, g.tick_i])
	#  grow_roll 0 은 손대기 전 띠다 — 굴림도 칸도 안 서고 머리에서 곧장 착지한다.
	var o0 := _tick_play(0.90, false, false, false, 0.0)
	_ok("⑭-j 굴림을 끄면(grow_roll 0) 톡이 없고 머리에서 착지한다",
			int(o0.n) == 0 and (o0.heard as Array).is_empty() and bool(o0.st_start),
			"칸 %d · %d번 · 머리 소리 %s" % [int(o0.n), (o0.heard as Array).size(), o0.st_start])

	# ── ⑮ 착지 — 머리는 조용하고 끝값에서 내리친다 (2026-10-06) ──────
	#  머리에서 하던 것(settle_total · 흔들림 · 멈춤 · 크기 봉우리)이 전부 착지 프레임으로
	#  옮겼다. 멈춤은 그 프레임의 남은 qt 에서 빌린다(qt 가 멈춤 + 한 프레임만큼 준다).
	#  착지 자리는 걸음의 lerp(land_lo, land_hi, gn) 몫이고 그 뒤 0.20 ~ 0.26초를 선다.
	var la_ok := true
	var la_txt := ""
	var at_ok := true
	var at_txt := ""
	for r5 in [0.02, 0.216, 0.90]:
		var o5 := _tick_play(float(r5), false, false, false)
		var gn5: float = float(o5.gn)
		var shk_want: float = lerpf(float(g.GROW.shk_lo), float(g.GROW.shk_hi), gn5 * gn5)
		#  머리 — 소리 없음 · 흔들림이 안 선다(앞 프레임 값에서 줄기만 한다) · 멈춤 0.
		if bool(o5.st_start) or float(o5.shk_start) > float(o5.shk_pre) + 0.0001:
			la_ok = false
		#  착지 — settle_total 한 번(그 프레임) · 흔들림이 식 · 「한 방」이면 멈춤이 qt 에서 빠진다.
		var st5: Array = o5.st
		if st5.size() != 1 or int(st5[0]) != int(o5.land) \
				or absf(float(o5.shk_land) - shk_want) > 0.001:
			la_ok = false
		if bool(o5.big):
			var drop_want: float = float(o5.hs) + float(o5.rate) / 60.0
			if float(o5.hs) <= 0.0 or absf(float(o5.qt_drop) - drop_want) > 0.0005:
				la_ok = false
		elif float(o5.hs) > 0.0:
			la_ok = false
		if int(o5.sync) > 0 or int(o5.gain_n) < 6:
			la_ok = false
		la_txt += "r%.2f 착지 %d · 흔들림 %.2f(식 %.2f) · 멈춤 %.3f · 카드 값 %d가지 · 어긋남 %d · " \
				% [float(r5), int(o5.land), float(o5.shk_land), shk_want, float(o5.hs),
				int(o5.gain_n), int(o5.sync)]
		var steps5: int = int(o5.end) - int(o5.start)
		var at5: float = float(int(o5.land) - int(o5.start)) / maxf(float(steps5), 1.0)
		var want5: float = lerpf(float(tl.land_lo), float(tl.land_hi), gn5)
		var hold5: float = float(int(o5.end) - int(o5.land)) / 60.0
		if absf(at5 - want5) > 2.0 / maxf(float(steps5), 1.0) or hold5 < 0.18 or hold5 > 0.28:
			at_ok = false
		at_txt += "gn %.2f → %.3f(식 %.3f) · 뒤 %.3f초 · " % [gn5, at5, want5, hold5]
	_ok("⑮-a 머리는 소리 · 흔들림 · 멈춤이 없고 착지 프레임에 내리친다 · 카드와 띠가 한 몫",
			la_ok, la_txt)
	_ok("⑮-b 착지가 걸음의 land 몫에 서고 뒤를 0.18 ~ 0.28초 선다", at_ok, at_txt)

	#  ── ⑮-c 이득 0 은 조용하다 — 칸 · 착지 · 소리가 없고 카드가 0 을 적는다 ──
	var oz := _tick_play(0.0, false, false, false)
	_ok("⑮-c 이득 0 — 톡 · 착지 · 합계 소리가 없다",
			int(oz.n) == 0 and (oz.heard as Array).is_empty() and int(oz.lands) == 0
			and (oz.st as Array).is_empty() and g.last_gain == 0 and g._card_gain() == 0,
			"칸 %d · 톡 %d · 착지 %d · settle_total %s · 카드 %d"
			% [int(oz.n), (oz.heard as Array).size(), int(oz.lands), oz.st, g._card_gain()])

	#  ── ⑮-d 일시정지 — 정산 위에 연 설정 뒤에서는 굴림 · 톡 · 착지 · 멈춤이 선다 ──
	#  굴림 중간과 착지 멈춤 안에서 각각 열어 1초를 돌리고, 닫은 뒤 착지가 한 번 난다.
	var pz_ok := true
	var pz_txt := ""
	for at_land in [false, true]:
		_stage_total(0.90, 1)
		tp.stream = null
		tp.pitch_scale = 1.0
		var lv_p := false
		var landed_p := 0
		var opened := false
		for _f6 in 4000:
			if g.state != g.S.RESOLVE:
				break
			g._process(1.0 / 60.0)
			if lv_p and not g.land_live:
				landed_p += 1
			lv_p = g.land_live
			var hit: bool = (g.hitstop > 0.0 and landed_p == 1) if at_land \
					else (g.land_live and g.tick_i >= 3)
			if hit and not opened:
				opened = true
				var snap := [g.score_roll, g.shown, g.tick_i, g.tick_flash, g.gain_p,
						g.qt, g.hitstop, g.gain_roll, g.land_live]
				var key6 := _tick_key(tp)
				var sn6: int = g.sfx_next
				g._pause_open()
				for _k6 in 60:
					g._process(1.0 / 60.0)
				var snap2 := [g.score_roll, g.shown, g.tick_i, g.tick_flash, g.gain_p,
						g.qt, g.hitstop, g.gain_roll, g.land_live]
				var heard6: bool = _tick_key(tp) != key6
				var news6: Array = _pool_new(sn6)
				if snap != snap2 or heard6 or news6.has("settle_total"):
					pz_ok = false
				pz_txt += "%s 그대로 %s · 톡 %s · 착지 소리 %s · " % ["착지 멈춤" if at_land
						else "굴림", snap == snap2, heard6, news6.has("settle_total")]
				g.state = g.pause_from
				g.pause_from = -1
		if landed_p != 1 or not opened:
			pz_ok = false
		pz_txt += "착지 %d번 · " % landed_p
	_ok("⑮-d 정산 위 일시정지 뒤에서 굴림 · 톡 · 착지 · 멈춤이 멎는다", pz_ok, pz_txt)
	#  ── ⑮-e 일시정지에서 로비로 나가면 남은 톡 · 착지가 제목 화면에서 안 난다 ──
	_stage_total(0.90, 1)
	tp.stream = null
	tp.pitch_scale = 1.0
	for _f7 in 4000:
		g._process(1.0 / 60.0)
		if g.land_live and g.tick_i >= 3:
			break
	g._pause_open()
	g._to_lobby()
	var key7 := _tick_key(tp)
	var st7 := false
	for _k7 in 120:
		var s7: int = g.sfx_next
		g._process(1.0 / 60.0)
		if _pool_new(s7).has("settle_total"):
			st7 = true
	_ok("⑮-e 로비로 나가면 남은 톡 · 착지가 안 난다",
			_tick_key(tp) == key7 and not st7 and not g.land_live and g.score_roll == 0.0,
			"톡 %s · 착지 소리 %s · 남은 착지 %s · 굴림 %.2f"
			% [_tick_key(tp) != key7, st7, g.land_live, g.score_roll])
	g.state = g.S.PICK
