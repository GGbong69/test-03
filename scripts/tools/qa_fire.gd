extends SceneTree
# ══════════════════════════════════════════════════════════
#  달아오르는 가장자리와 빈 박 — **박자 0 · 문턱 · 상한**을 프레임으로 못 박는다
#  (2026-09-26 · 사용자: 「점수 올라갈 때 화면 테두리가 불타거나 화면이
#   흔들리거나 이팩트 있거나」)
#
#  실행:  godot --headless --path . --script scripts/tools/qa_fire.gd
#  종료 코드 = 실패 개수
#
#  왜 있는가
#    합계 걸음에 층을 넷 얹었다 — 테두리(빛) · 멈춤 깊이(시간) · 흔들림 누수
#    수선 · 침묵(뺀 소리). 한 판에 합계 걸음이 수십 번 나므로 계약은 둘이다:
#      ① **걸음이 한 프레임도 안 는다**(늘린 멈춤은 같은 줄에서 qt 에서 뺀다).
#      ② **문턱이 있다** — 실측 절반이 0단(아무 일도 안 나는 단)이고 가장 센
#         4단은 **판에 한 번**을 구조적으로 못 넘는다(깃발을 쓰고 태운다).
#    그리고 이 층은 **글자 0자**다 — 숫자·빛·소리로만 말한다.
#
#  ⚠ 여기서 세우는 값은 전부 **검사대 위의 값**이다. 점수·배수·목표·보상·
#    확률을 정하는 자리를 한 글자도 안 건드린다 — ⑮ 가 그것을 되짚어 잰다.
#
#  ⚠ 그리기 호출 수를 세는 길이 없다(draw_rect 는 _draw 안에서만 돌고 세는
#    고리가 저장소에 없다). 그래서 기하는 **표를 그대로 다시 셈한 거울**로
#    재고, ⑨-0 이 그 거울이 표와 어긋나지 않았는지를 먼저 잠근다. 눈으로 보는
#    쪽은 shot_fire 그림이 맡는다.
# ══════════════════════════════════════════════════════════
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")

var g = null
var ok := 0
var bad := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_fire_g.cfg"
	Save.path = "user://_qa_fire.cfg"
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
	print("  %s %-52s %s" % ["통과" if cond else "실패", nm, note])


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
	g.fire_lock = -1
	g.fire_mul = 1.0


#  gn → r 의 되돌림. _grow_n 은 r = 0.05 부터 2.00 까지를 로그로 눕히므로
#  r = r_lo × (r_hi / r_lo) ^ gn 이다. 문턱을 r 로 말하려면 이 한 줄이 필요하다.
func _r_of(gn: float) -> float:
	var lo := float(g.GROW.r_lo)
	var hi := float(g.GROW.r_hi)
	return lo * pow(hi / lo, gn)


#  합계 걸음 하나를 손으로 세운다. qa_total 의 _stage_total 과 **같은 어법**이다 —
#  target 을 1000 으로 못 박고 두 칸을 그 비에 맞춘다.
func _stage(r: float, pace_load: int, tgt := 1000) -> void:
	g.set_process(false)
	g._start_leg()
	g._card_reset()
	g.target = tgt
	g.total = 0
	g.shown = 0.0
	g.cur_chip = int(round(r * float(tgt)))
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


#  합계 걸음 **여섯**을 한 큐에 넣는다.
#  ⚠ 이 세움이 필요한 까닭을 재 보고 알았다. 처음엔 걸음마다 _push 로 다시
#  세웠는데, 큐가 비는 프레임에 _next_step 이 `total >= target` 을 보고
#  **_finish_leg 를 부르고 판이 새로 시작**해서 fire_used 가 되돌아왔다 —
#  여섯 걸음 중 두 번이 4단으로 찍혔다. 큐를 미리 채우면 큐가 안 비므로
#  판이 안 끝난다.
#  ⚠ total 을 목표 **위**에서 출발시킨다. 그래야 was_short 가 거짓이라
#  brk 가 안 서고(돌파는 4단을 안 받는다) 순수하게 깃발만 재게 된다. 이것은
#  무한 런과 반동으로 목표를 넘긴 뒤 걸음이 이어지는 **실제 자리**이기도 하다.
func _stage_many(r: float, n: int, tgt := 1000) -> void:
	_stage(r, 1, tgt)
	g.total = tgt * 5
	g.shown = float(tgt * 5)
	g.queue.clear()
	for _i in range(n):
		g.queue.append({"k": "total"})


#  합계 걸음이 **나는 프레임마다** 단·멈춤·침묵을 적는다(total 이 오르는
#  프레임 하나로 잡는다 — grow_dist 가 쓰는 그 검출이다).
func _walk(n: int) -> Array:
	var out := []
	var prev: int = int(g.total)
	var fr := 0
	while g.state == g.S.RESOLVE and out.size() < n and fr < 6000:
		g._process(1.0 / 60.0)
		fr += 1
		if int(g.total) != prev:
			prev = int(g.total)
			out.append({"hot": int(g.fire_hot),
					"stop": snappedf(float(g.hitstop), 0.001),
					"snd": float(g.fire_snd) > 0.0})
	return out


#  큐에 합계 걸음 하나를 더한다(판을 새로 시작하지 않는다 — 「판에 한 번」을
#  재려면 **같은 판 안에서** 걸음을 이어야 한다).
func _push(r: float) -> void:
	g.cur_chip = int(round(r * float(maxi(g.target, 1))))
	g.cur_mult = 1
	g.card_mode = 0
	g.calc_lit = false
	g.roll_t = -1.0
	g.queue.clear()
	g.queue.append({"k": "total"})
	g.state = g.S.RESOLVE
	g.qt = g.beat * g._pace()


#  한 걸음을 끝까지 돌린다. 걸음이 끝나는 자리(state 가 RESOLVE 를 벗어남)로
#  잰다 — qa_total 의 _play_step 과 같은 자다.
func _play(hold_fast := false) -> Dictionary:
	var frames := 0
	var stop_f := 0            # 멈춤이 살아 있던 프레임
	var fire_f := 0            # 테두리 창이 살아 있던 프레임
	var quiet_f := 0           # 늦춘 소리가 안 난 프레임(= 침묵)
	var shk_hi := 0.0
	var env_hi := 0.0
	var hot := 0
	var stop0 := 0.0
	g.fast_lock = hold_fast
	while g.state == g.S.RESOLVE and frames < 6000:
		g._process(1.0 / 60.0)
		frames += 1
		hot = maxi(hot, int(g.fire_hot))
		stop0 = maxf(stop0, float(g.hitstop))
		if g.hitstop > 0.0:
			stop_f += 1
		if g.fire_snd > 0.0:
			quiet_f += 1
		if g.fire_t > 0.0:
			fire_f += 1
			env_hi = maxf(env_hi, g._fire_env())
		shk_hi = maxf(shk_hi, float(g.shake))
	g.fast_lock = false
	return {"frames": frames, "stop": stop_f, "fire": fire_f,
			"quiet": quiet_f, "shk": shk_hi, "hot": hot, "env": env_hi,
			"stop0": stop0, "shake_end": float(g.shake)}


func _spread(a: Array) -> int:
	var lo := 999999
	var hi := -999999
	for v in a:
		lo = mini(lo, int(v))
		hi = maxi(hi, int(v))
	return hi - lo


#  ── 표를 그대로 다시 셈한 거울 ────────────────────────────
#  _fire_edge 가 그리는 사각을 목록으로 낸다. ⑨-0 이 이 거울이 표와 어긋나지
#  않았는지를 먼저 잠근다.
func _rects(hot: int) -> Array:
	var out := []
	if hot <= 0:
		return out
	var top: float = float(g.LAY.bar.size.y)
	var w: float = float(g.FIRE.w)
	for k in int(g.FIRE.lay[hot]):
		var o: float = float(k) * w
		var x0: float = o
		var y0: float = top + o
		var sw: float = g.VIEW.x - o * 2.0
		var sh2: float = g.VIEW.y - top - o * 2.0
		if sw <= 0.0 or sh2 <= 0.0:
			break
		out.append(Rect2(x0, y0, sw, w))
		out.append(Rect2(x0, y0 + sh2 - w, sw, w))
		out.append(Rect2(x0, y0 + w, w, sh2 - w * 2.0))
		out.append(Rect2(x0 + sw - w, y0 + w, w, sh2 - w * 2.0))
	return out


#  sRGB 한 채널을 선형으로.
func _lin(c: float) -> float:
	return c / 12.92 if c <= 0.04045 else pow((c + 0.055) / 1.055, 2.4)


#  상대 휘도(WCAG).
func _lum(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


#  fg 를 bg 위에 알파 a 로 얹은 색의 휘도.
func _over(fg: Color, bg: Color, a: float) -> float:
	return _lum(Color(bg.r + a * (fg.r - bg.r), bg.g + a * (fg.g - bg.g),
			bg.b + a * (fg.b - bg.b)))


# ══════════════════════════════════════════════════════════
func _run() -> void:
	g._new_run()
	_calm()
	var F: Dictionary = g.FIRE

	# ── ① 박자 0 — 단이 걸음 프레임을 한 개도 안 더한다 ──────
	#  「빈 박」의 본체다. 멈춤을 2단 0.060 · 3단 0.090 · 4단 0.120 으로 갈랐는데
	#  **같은 줄에서 qt 에서 빼므로** 걸음 벽시계가 다섯 단에서 글자 하나까지
	#  같아야 한다. r 0.90 을 쓴다 — 목표(1000)를 안 넘기므로 qt 가 2.6 갈래로
	#  서고, 0.50 을 넘으므로 「한 방」 블록에 들어 멈춤이 실제로 걸린다.
	print("\n── ① 박자 0 ────────────────────────────────────")
	var beat0: float = g.beat
	for pl in [1, 40]:
		for ff in [false, true]:
			var fr := []
			for t in range(5):
				_stage(0.90, pl)
				g.fire_lock = t
				fr.append(int(_play(ff).frames))
				g.fire_lock = -1
			_ok("① 단 0~4 걸음 길이가 같다 (짐 %d · 빨리 %s)"
					% [pl, "2.5" if ff else "끔"], _spread(fr) <= 1,
					"%s프레임" % [fr])
	#  값이 아무리 커도 같은가 — 무한 런의 큰 수에서 안 터지는지를 같이 잰다.
	#  ⚠ **갈래를 갈라서 잰다.** qa_total ① 이 먼저 겪은 함정이다: r ≥ 1.0 은
	#  이 걸음에서 목표를 넘기므로 게임이 **손대기 전부터** qt 를 2.6 → 3.4 로
	#  늘린다(판이 끝나는 자리라 길게 둔 것이다). 안 가르고 재면 75 ↔ 91 이
	#  나오는데 그건 내 층이 아니라 그 갈래다 — 처음 돌렸을 때 실제로 그랬다.
	var frv := []
	for r in [0.02, 0.32, 0.60, 0.90]:
		_stage(float(r), 1)
		frv.append(int(_play().frames))
	_ok("①-b 안 넘기는 걸음이 r 0.02~0.90 에서 같다", _spread(frv) <= 1,
			"%s프레임" % [frv])
	var frh := []
	for r in [1.00, 2.00, 1.00e6, 1.00e12]:
		_stage(float(r), 1)
		frh.append(int(_play().frames))
	_ok("①-d 넘기는 걸음도 r 1.0~1e12 에서 같다", _spread(frh) <= 1,
			"%s프레임 (무한 런의 큰 수에서 안 터진다)" % [frh])
	#  curve_probe 가 beat 를 0.015 로 누른 자리 — 상한 qt*0.5 가 물어야 한다.
	g.beat = 0.015
	var frb := []
	for t in range(5):
		_stage(0.90, 1)
		g.fire_lock = t
		frb.append(int(_play().frames))
		g.fire_lock = -1
	g.beat = beat0
	_ok("①-c beat 0.015 에서도 걸음 길이가 같다", _spread(frb) <= 1,
			"%s프레임 (상한 qt*0.5 가 문다)" % [frb])

	# ── ② 0단 자물쇠 — 아무 일도 안 나는 단이 정확히 0 이다 ──
	#  하나라도 옅게 켜지면 걸음의 절반에 테두리가 들어와 **상시 장식**이 된다
	#  (2026-09-17 에 금빛 윗띠를 걷은 그 실수).
	print("\n── ② 0단 자물쇠 ───────────────────────────────")
	var z_ok := true
	var z_note := ""
	for r in [0.02, 0.05, 0.10, 0.30]:
		_stage(float(r), 1)
		var st := _play()
		var rects: int = _rects(int(g.fire_hot)).size()
		if int(st.hot) != 0 or float(g.fire_t) > 0.0 or rects != 0 \
				or int(st.quiet) != 0 or float(st.stop0) > 0.0:
			z_ok = false
			z_note += "r%.2f→단%d/창%d/사각%d/침묵%d/멈춤%.3f " % [r, st.hot,
					st.fire, rects, st.quiet, st.stop0]
	_ok("② r ≤ 0.30 에서 사각 0 · 창 0 · 멈춤 0 · 침묵 0", z_ok,
			z_note if z_note != "" else "넷 다 0")
	_ok("②-b FIRE.gain[0] 이 정확히 0 이다",
			is_equal_approx(float(F.gain[0]), 0.0) and int(F.lay[0]) == 0,
			"세기 %.2f · 겹 %d" % [F.gain[0], F.lay[0]])

	# ── ③ 단 경계 — 부등호 방향을 못 박는다 ─────────────────
	print("\n── ③ 단 경계 ──────────────────────────────────")
	var pts := [0.4999, 0.50, 0.6239, 0.624, 0.8759, 0.876, 0.9999, 1.00]
	var want := [0, 1, 1, 2, 2, 3, 3, 3]
	var got := []
	for gn in pts:
		#  깃발을 태운 상태로 잰다 — 4단은 ④ · ⑤ 가 따로 잰다.
		g.fire_lock = -1
		g.fire_used = true
		g.fire_peak = 0
		g.last_gain = 0
		got.append(g._fire_tier(float(gn), false))
	_ok("③ gn 여덟 점이 0·1·1·2·2·3·3·3 으로 갈린다", got == want,
			"%s (바람 %s)" % [got, want])
	_ok("③-b 문턱 셋이 r 로 옮겨도 그 자리다",
			absf(_r_of(float(F.t1)) - 0.316) < 0.004
			and absf(_r_of(float(F.t2)) - 0.500) < 0.002
			and absf(_r_of(float(F.t3)) - 1.266) < 0.006,
			"t1 r %.4f · t2 r %.4f (CARDFX.big %.2f) · t3 r %.4f"
			% [_r_of(float(F.t1)), _r_of(float(F.t2)), g.CARDFX.big,
			_r_of(float(F.t3))])
	#  t2 를 CARDFX.big 과 **같은 수**로 맞춘 것이 「빈도를 안 올렸다」의 근거다.
	_ok("③-c t2 가 CARDFX.big 과 같은 자리다",
			absf(_r_of(float(F.t2)) - float(g.CARDFX.big)) < 0.002,
			"r %.5f 대 %.5f" % [_r_of(float(F.t2)), g.CARDFX.big])
	#  깃발이 살아 있으면 같은 자리에서 4단이 난다.
	g.fire_used = false
	g.fire_peak = 0
	g.last_gain = 0
	_ok("③-d 깃발이 살아 있으면 t3 에서 4단이 난다",
			g._fire_tier(float(F.t3), false) == 4)

	# ── ④ 판에 한 번 — 구조적 방벽 ─────────────────────────
	#  문턱만으로는 절대 얻을 수 없는 보장이다. 연발 여섯 걸음 · 무한 런의
	#  포화 · 리볼버가 한 발을 쪼개는 자리에서 빈도가 **원리적으로** 안 오른다.
	print("\n── ④ 판에 한 번 ───────────────────────────────")
	_stage_many(2.00, 6, 1000)
	var walk := _walk(6)
	var tiers := []
	var stops := []
	var snds := []
	for w in walk:
		tiers.append(int(w.hot))
		stops.append(float(w.stop))
		snds.append(bool(w.snd))
	var n4 := tiers.count(4)
	_ok("④ 한 판 여섯 걸음에서 4단이 **한 번**만 난다", n4 == 1,
			"단 %s · 멈춤 %s · 늦춘소리 %s" % [tiers, stops, snds])
	_ok("④-b 나머지 다섯이 3단이고 멈춤이 0.090 이다",
			tiers.count(3) == 5 and absf(float(stops[5]) - 0.090) < 0.004,
			"단 %s · 마지막 멈춤 %.3f" % [tiers, stops[5]])
	_ok("④-c 4단만 소리를 늦춘다", snds.count(true) == 1,
			"늦춘 걸음 %d개 · 자리 %d번째" % [snds.count(true), snds.find(true) + 1])
	_ok("④-b2 멈춤 깊이가 4단만 0.120 이다",
			absf(float(stops[tiers.find(4)]) - 0.120) < 0.004,
			"4단 멈춤 %.3f · 3단 %.3f" % [stops[tiers.find(4)], stops[5]])
	#  ⚠ **여기가 이 설계의 피로 방벽이 통째로 사라지는 유일한 자리다.**
	#  _card_reset 은 발마다 돈다(한 판 여섯 발) — 거기서 자격을 되돌리면
	#  「판에 한 번」이 「발마다 한 번」이 된다.
	g._card_reset()
	_ok("④-d _card_reset 이 자격을 **안** 되돌린다", bool(g.fire_used),
			"fire_used %s · fire_peak %d" % [g.fire_used, g.fire_peak])
	g._start_leg()
	_ok("④-e _start_leg 이 자격을 되돌린다",
			not g.fire_used and int(g.fire_peak) == 0,
			"fire_used %s · fire_peak %d" % [g.fire_used, g.fire_peak])

	# ── ⑤ 문 ② — 판 최고 기록이라는 달리는 축 ────────────────
	#  자(r)가 라운드마다 뒤집히는 것을 4단만 비켜 가게 하는 문이다.
	print("\n── ⑤ 문 ②(판 최고 기록) ───────────────────────")
	#  ⚠ **여기서 산수 하나를 배웠다 — 걸음을 마음대로 이을 수 없다.**
	#  같은 판에서 걸음 둘을 이으려면 두 이득의 합이 목표를 안 넘어야 한다
	#  (넘으면 brk 가 서고 판이 끝난다). 즉 r ≥ 0.50 짜리 걸음은 한 판에
	#  **사실상 한 번뿐**이다 — 0.50 + 0.50 이 이미 목표다. 처음엔 0.60 → 0.90
	#  으로 이었는데 둘째가 목표를 넘겨 brk 가 서서 2단이 나왔다.
	#  그래서 이 절은 **합이 1.0 을 안 넘는 짝**으로만 잰다.
	#  이 산수 자체가 「4단이 판에 한 번을 못 넘는다」의 둘째 근거다 — 깃발이
	#  없어도 목표가 이미 막고 있고, 깃발은 무한 런과 반동(목표를 넘긴 뒤
	#  걸음이 이어지는 자리)을 위한 방벽이다.
	_stage(0.30, 1, 100000)
	var t_first := int(_play().hot)
	_ok("⑤ 판의 **첫** 합계 걸음은 새 기록이어도 4단이 아니다", t_first != 4,
			"첫 걸음 %d단 (fire_peak 0 이라 rec 가 안 선다)" % t_first)
	_push(0.60)                       # 새 기록 · gn ≥ t2 · 합 0.90 < 1.0
	var t_rec := int(_play().hot)
	_ok("⑤-b 둘째 이후의 새 기록이 4단이 된다", t_rec == 4,
			"%d단 (gn %.3f · t2 %.3f)" % [t_rec, g._grow_n(), F.t2])
	#  ⑤-c 는 **순수 함수로** 잰다. 같은 판에서 큰 걸음 셋을 이으려면 합이
	#  목표를 넘어야 하므로 실제 경로로는 세울 수가 없다(위 산수).
	g.fire_used = true
	g.fire_peak = 100
	g.last_gain = 999999          # 새 기록
	var t_burn: int = g._fire_tier(float(F.t2) + 0.10, false)
	_ok("⑤-c 태운 뒤의 기록은 3단으로도 안 올라가고 2단에 머문다", t_burn == 2,
			"%d단" % t_burn)
	g.fire_used = false
	g.fire_peak = 100
	g.last_gain = 999999
	_ok("⑤-c2 태우기 전 같은 자리는 4단이다",
			g._fire_tier(float(F.t2) + 0.10, false) == 4)
	#  R8 급 목표에서 작은 비의 발이 실제로 4단을 받는가 — 라운드 뒤집힘이
	#  잡혔는가를 재는 **유일한 줄**이다(자 r 은 R8 에서 p90 이 0.568 로 내려간다).
	_stage(0.40, 1, 15000)
	_play()
	_push(0.55)                       # 합 0.95 < 1.0 · gn 0.650 ≥ t2
	var t_r8 := int(_play().hot)
	_ok("⑤-d R8 급 목표(15000)에서 r 0.55 짜리 발이 4단이 된다", t_r8 == 4,
			"%d단 · gn %.3f · 이득 %d / 목표 %d"
			% [t_r8, g._grow_n(), g.last_gain, g.target])

	# ── ⑥ 흔들림 누수 수선 ─────────────────────────────────
	#  ⚠ 이 줄은 **수선 전 코드에서 빨개진다** — 오늘 이미 1.40프레임(잔광
	#  0.79px)을 샌다. _process 의 멈춤 블록 안 `if stop_fire:` 한 줄이 같이
	#  들어가야 초록이 된다.
	print("\n── ⑥ 흔들림 누수 ─────────────────────────────")
	var leak_ok := true
	var leak_note := ""
	for t in [2, 3, 4]:
		_stage(0.90, 1)
		g.fire_lock = t
		var st := _play(true)
		g.fire_lock = -1
		if float(st.shake_end) > 0.0001:
			leak_ok = false
		leak_note += "%d단 끝 %.3f · " % [t, st.shake_end]
	_ok("⑥ 빨리 보기 2.5 에서 2·3·4단 걸음 끝 흔들림이 0", leak_ok, leak_note)
	#  ⑥-b **착탄 멈춤의 잔광이 한 톨도 안 바뀌었는가.** 깃발로 잠갔으므로
	#  정산이 안 세운 멈춤에서는 감쇠가 오늘 그대로 안 돌아야 한다.
	_stage(0.90, 1)
	g.state = g.S.RESOLVE
	g.queue.clear()
	g.shake = 15.0                    # 이너 불
	g.hitstop = 0.15
	g.stop_fire = false
	#  여덟 프레임만 감는다 — 0.15 − 8/60 = 0.017 이라 아직 얼어 있다.
	#  더 감으면 멈춤이 풀려 **본 감쇠**가 돌므로 이 줄이 재려는 것과 섞인다.
	for _i in range(8):
		g._process(1.0 / 60.0)
	_ok("⑥-b 착탄 멈춤에서는 감쇠가 오늘 그대로 안 돈다",
			is_equal_approx(float(g.shake), 15.0) and g.hitstop > 0.0,
			"이너 불 15.0 → %.3f (8프레임 뒤 · 남은 멈춤 %.3f)"
			% [g.shake, g.hitstop])
	#  ⑥-c 돌파 멈춤도 그대로다 — stop_fire 가 안 서므로.
	_stage(2.00, 1)                   # 목표 1000 을 이 걸음에서 넘긴다
	_play()
	_ok("⑥-c 돌파 걸음은 stop_fire 를 안 세운다", not bool(g.stop_fire),
			"stop_fire %s" % g.stop_fire)

	# ── ⑦ 창이 걸음을 못 넘는다 — 부등식으로 증명한다 ────────
	#  「새 벽시계 상수 0개」를 검사가 대신 증명하는 자리다. 창 = qt × jspan
	#  이므로 beat 가 0.34 든 0.015 든 · pace 가 1.00 이든 0.30 이든 · 빨리
	#  보기가 1.0 이든 2.5 든 구조적으로 걸음을 못 넘는다.
	print("\n── ⑦ 창 ÷ 걸음 ───────────────────────────────")
	var worst := 0.0
	var wnote := ""
	for bt in [0.34, 0.015]:
		for pl in [1, 40]:
			for ff in [false, true]:
				g.beat = bt
				_stage(0.90, pl)
				g.beat = bt
				g.fire_lock = 3
				var st := _play(ff)
				g.fire_lock = -1
				var ratio: float = float(st.fire) / maxf(float(st.frames), 1.0)
				if ratio > worst:
					worst = ratio
					wnote = "beat%.3f 짐%d 빨리%s → %.3f (%d/%d프레임)" \
							% [bt, pl, "2.5" if ff else "끔", ratio,
							st.fire, st.frames]
	g.beat = beat0
	_ok("⑦ 테두리 창이 여덟 구석에서 걸음을 못 넘는다", worst <= 1.0, wnote)
	#  돌파 걸음에서도 뜬다 — 테두리는 값 크기를 잇는 읽기다.
	_stage(2.00, 1)
	var stb := _play()
	_ok("⑦-b 돌파 걸음에서도 테두리가 뜬다",
			int(stb.fire) > 0 and int(stb.hot) >= 1,
			"%d단 · 창 %d/%d프레임" % [stb.hot, stb.fire, stb.frames])
	_ok("⑦-c 봉투가 창 안에서 1.0 에 닿는다", stb.env > 0.90 and stb.env <= 1.0001,
			"최대 %.3f" % stb.env)

	# ── ⑧ 면적과 휘도 — 실시간 쿨다운이 왜 0개인가 ───────────
	#  ⚠ 설계 후보의 면적 산수가 **틀렸다.** 「10° 시야 213×120 의 모서리에
	#  18px 띠 = 25,560 − 195×102 = 5,670 = 22.2%」는 각 변에서 18 을 한 번만
	#  뺀 값이다(= 9px 테). 폭 18 의 테라면 177×84 라 테가 41.8% 로 25% 를
	#  **넘는다.** 규정을 바르게 읽으면 10° 중심 시야는 화면 **가운데 창**이고
	#  이 테는 화면 **가장자리**라 그 창과 한 픽셀도 안 겹친다 → 0%.
	#  화면 전체로 재도 15.1% 로 밑이다. 어느 쪽으로 재도 안전하지만 **근거가
	#  다르므로** 두 수를 다 잠근다.
	print("\n── ⑧ 면적과 휘도 ─────────────────────────────")
	var band: float = float(F.w) * float(F.lay[3])
	#  10° 중심 창 — 640×360 의 가운데 3분의 1.
	var c10 := Rect2(g.VIEW.x / 3.0, g.VIEW.y / 3.0, g.VIEW.x / 3.0, g.VIEW.y / 3.0)
	var hit10 := 0.0
	for rc in _rects(3):
		var isec: Rect2 = (rc as Rect2).intersection(c10)
		hit10 += isec.size.x * isec.size.y
	_ok("⑧ 테가 10° 중심 창과 한 픽셀도 안 겹친다", hit10 <= 0.0,
			"겹친 면적 %.0fpx² / 창 %.0fpx²" % [hit10, c10.size.x * c10.size.y])
	var full: float = g.VIEW.x * g.VIEW.y
	var inner: float = (g.VIEW.x - band * 2.0) * (g.VIEW.y - band * 2.0)
	var shr: float = (full - inner) / full
	_ok("⑧-b 화면 전체로 재도 25% 밑이다", shr < 0.25,
			"띠 %.0fpx → %.0fpx² = %.1f%%" % [band, full - inner, shr * 100.0])
	#  휘도 — 이 수가 「실시간 쿨다운이 0개」라는 주장의 전부다.
	var ymax: float = _lum(g.C_TXT)
	var thr: float = ymax * 0.10
	var ybg: float = _lum(g.C_BG)
	var d1: float = _over(g.C_GOLD, g.C_BG, float(F.a[0])) - ybg
	#  ⚠ 개발자 사다리의 **천장을 표에서 읽는다** — 손으로 2.0 을 박아 두면
	#  저쪽 천장을 내린 뒤에도 초록이라 짝이 깨진 것을 못 잡는다(밑값 0.20 과
	#  천장 150% 는 짝이다 — 200% 면 문턱을 넘는다).
	var top_mul := 0.0
	for v in (Dev.FIRE_STEPS["fglow"] as Array):
		top_mul = maxf(top_mul, float(v))
	var d2: float = _over(g.C_GOLD, g.C_BG, float(F.a[0]) * top_mul) - ybg
	_ok("⑧-c 가장 밝은 겹이 섬광 휘도 문턱 밑이다", d1 < thr,
			"α %.2f → ΔY %.4f / 문턱 %.4f = %.1f%% (최대 휘도 %.3f)"
			% [F.a[0], d1, thr, 100.0 * d1 / thr, ymax])
	_ok("⑧-d 개발자 사다리 천장도 문턱 밑이다", d2 < thr,
			"천장 %d%% → α %.2f → ΔY %.4f = %.1f%%"
			% [int(top_mul * 100.0), float(F.a[0]) * top_mul, d2,
			100.0 * d2 / thr])
	#  ⚠ 짝이 깨지는 자리를 못으로 박는다 — 밑값을 올리면서 천장을 안 내리면
	#  여기가 빨개진다. 「200% 면 넘는다」를 검사가 직접 셈해 보인다.
	var d3: float = _over(g.C_GOLD, g.C_BG, float(F.a[0]) * 2.0) - ybg
	_ok("⑧-d2 천장을 200% 로 되돌리면 문턱을 넘는다(짝이라는 증거)", d3 >= thr,
			"α %.2f → ΔY %.4f = %.1f%%"
			% [float(F.a[0]) * 2.0, d3, 100.0 * d3 / thr])
	#  붉은 섬광 규정 — 포화 적색이 아니다.
	var rr: float = g.C_GOLD.r / maxf(g.C_GOLD.r + g.C_GOLD.g + g.C_GOLD.b, 0.001)
	_ok("⑧-e 붉은 섬광 규정에서 멀다", rr < 0.8, "R/(R+G+B) = %.3f" % rr)

	# ── ⑨ 가독성 · 자리 ───────────────────────────────────
	#  받아들인 값을 수로 못 박아 다음 사람이 모르고 넓히는 것을 막는다.
	print("\n── ⑨ 가독성 · 자리 ───────────────────────────")
	#  ⑨-0 거울이 표와 어긋나지 않았는가 — 아래 넷의 전제다.
	_ok("⑨-0 거울이 표 그대로다(겹 %d × 사각 4)" % int(F.lay[3]),
			_rects(3).size() == int(F.lay[3]) * 4
			and _rects(1).size() == 4 and _rects(0).size() == 0,
			"3단 %d · 1단 %d · 0단 %d" % [_rects(3).size(), _rects(1).size(),
			_rects(0).size()])
	var bar: Rect2 = g.LAY.bar
	var hit_bar := 0.0
	for rc in _rects(3):
		var ib: Rect2 = (rc as Rect2).intersection(bar)
		hit_bar += ib.size.x * ib.size.y
	_ok("⑨ 상단 띠(점수·목표·게이지)를 한 픽셀도 안 덮는다", hit_bar <= 0.0,
			"겹친 면적 %.0fpx²" % hit_bar)
	#  카드 — 오른쪽 자리 x[370,614]. 우측 겹이 x[622,640] 이라 8px 떠야 한다.
	var cx: float = g.VIEW.x - 26.0 - float(g.CARD_W)
	var gap: float = (g.VIEW.x - band) - (cx + float(g.CARD_W))
	_ok("⑨-b 카드와 8px 뜬다", gap >= 8.0 - 0.001,
			"카드 오른끝 %.0f · 겹 안끝 %.0f · 틈 %.0fpx (금테 3px 에도 %.0f 남는다)"
			% [cx + g.CARD_W, g.VIEW.x - band, gap,
			gap - float(g.CARDFX.burst)])
	#  자금판 · 메뉴칸 — 바깥 14px 가 씻긴다. **글자는 한 자도 안 덮인다**
	#  (골드 숫자는 72px 판 가운데 x≈40).
	var bank: Rect2 = g.LAY.bank
	var menu: Rect2 = g.LAY.menu
	_ok("⑨-c 자금판은 왼쪽 14px 만 겹친다",
			absf((band - bank.position.x) - 14.0) < 0.001,
			"판 x[%.0f,%.0f] · 겹 x[0,%.0f] → %.0fpx"
			% [bank.position.x, bank.position.x + bank.size.x, band,
			band - bank.position.x])
	_ok("⑨-d 메뉴칸은 오른쪽 14px 만 겹친다",
			absf(((menu.position.x + menu.size.x) - (g.VIEW.x - band)) - 14.0)
			< 0.001,
			"칸 x[%.0f,%.0f] · 겹 x[%.0f,640] → %.0fpx"
			% [menu.position.x, menu.position.x + menu.size.x, g.VIEW.x - band,
			(menu.position.x + menu.size.x) - (g.VIEW.x - band)])

	# ── ⑩ 여백 — _full() 이 아니라 VIEW 를 쓴다 ──────────────
	#  _full() 은 Rect2(-view_pad, VIEW + view_pad*2) 라 21:9 창에서 좌·우 띠가
	#  통째로 레터박스에 앉아 **화면에서 사라진다.** 그래서 VIEW 를 쓴다.
	print("\n── ⑩ 여백 ────────────────────────────────────")
	var pad_ok := true
	var pad_note := ""
	var scr := Rect2(Vector2.ZERO, g.VIEW)
	for px in [0.0, 10.0, 40.0]:
		g.view_pad = Vector2(px, 0.0)
		for rc in _rects(3):
			if not scr.encloses(rc as Rect2):
				pad_ok = false
		#  같은 자리를 _full() 로 앉히면 실제로 사라진다 — 그쪽이 지는 것도 잰다.
		var f0: Rect2 = g._full()
		if px >= 18.0 and f0.position.x + float(F.w) > 0.0:
			pad_note += "(_full 판본은 pad %.0f 에서 좌측 겹이 x%.0f 라 화면 밖) " \
					% [px, f0.position.x]
	g.view_pad = Vector2.ZERO
	_ok("⑩ 여백을 밀어도 띠가 640×360 안쪽에 선다", pad_ok, pad_note)

	# ── ⑪ 모션 끄기 — 움직임만 꺼지고 빛·소리는 남는다 ────────
	print("\n── ⑪ 모션 끄기 ───────────────────────────────")
	_stage(0.90, 1)
	g.motion_off = true
	g.fire_lock = 4
	var stm := _play()
	g.fire_lock = -1
	g.motion_off = false
	_ok("⑪ 모션 끄기에서도 테두리가 뜬다(사각 수가 켰을 때와 같다)",
			_rects(int(stm.hot)).size() == _rects(4).size() and int(stm.fire) > 0,
			"%d단 · 사각 %d · 창 %d프레임"
			% [stm.hot, _rects(int(stm.hot)).size(), stm.fire])
	_ok("⑪-b 모션 끄기에서 멈춤이 0 이고 침묵이 0 이다",
			float(stm.stop0) <= 0.0 and int(stm.quiet) == 0
			and float(g.fire_snd) <= 0.0,
			"멈춤 %.3f · 침묵 %d프레임 · 남은 pitch %.1f"
			% [stm.stop0, stm.quiet, g.fire_snd])
	#  card_burst 는 같은 자리에서 `and not motion_off` 로 **빛인데 죽는다** —
	#  그 결함을 안 베꼈음을 이 줄이 잰다.
	_ok("⑪-c _fire_edge 에 motion_off 가드가 없다",
			not _src_has("func _fire_edge", "motion_off"),
			"card_burst 의 결함을 안 베꼈다")

	# ── ⑫ 연발 · 무한 · 실패한 판 ──────────────────────────
	print("\n── ⑫ 연발 · 무한 · 실패한 판 ─────────────────")
	#  대입(=) 규약 — maxf 면 불이 안 꺼져 **상시 장식**이 된다. 연발은 합계
	#  걸음이 여섯 번 붙어 나므로 여기가 그 규약이 깨지는 유일한 자리다.
	#  걸음마다 다시 섰다 죽는지를 「창이 0 인 프레임이 걸음 사이에 있는가」로
	#  잰다 — 창이 걸음의 78% 라 남은 22% 는 반드시 0 이어야 한다.
	_stage_many(2.00, 6, 1000)
	var zero_fr := 0
	var live_run := 0
	var live_max := 0
	var steps_seen := 0
	var prev_tt: int = int(g.total)
	var fr6 := 0
	while g.state == g.S.RESOLVE and fr6 < 6000:
		g._process(1.0 / 60.0)
		fr6 += 1
		if int(g.total) != prev_tt:
			prev_tt = int(g.total)
			steps_seen += 1
		if g.fire_t > 0.0:
			live_run += 1
			live_max = maxi(live_max, live_run)
		else:
			live_run = 0
			if steps_seen > 0:
				zero_fr += 1
	_ok("⑫ 여섯 걸음에서 창이 걸음 사이마다 0 에 닿는다(대입 규약)",
			zero_fr >= steps_seen and steps_seen == 6,
			"걸음 %d개 · 창 0 인 프레임 %d개 · 가장 긴 연속 점등 %d프레임 / 전체 %d"
			% [steps_seen, zero_fr, live_max, fr6])
	_ok("⑫-a2 한 번도 1.6초(96프레임) 넘게 이어 켜지지 않는다", live_max < 96,
			"가장 긴 연속 점등 %d프레임" % live_max)
	#  무한 런의 큰 수 — 단도 프레임도 안 터진다.
	var inf_t := []
	var inf_f := []
	for r in [2.0, 1.0e6, 1.0e12]:
		_stage(float(r), 1)
		var si := _play()
		inf_t.append(int(si.hot))
		inf_f.append(int(si.frames))
	_ok("⑫-b r 2.0 · 1e6 · 1e12 에서 단과 프레임이 같다",
			_spread(inf_t) == 0 and _spread(inf_f) <= 1,
			"단 %s · %s프레임" % [inf_t, inf_f])
	#  실패한 판 · 건너뛴 판에서 자격이 다음 판으로 안 샌다.
	_stage(2.00, 1, 100000)
	_push(2.00)
	_play()
	g._start_leg()
	_ok("⑫-c 판이 바뀌면 자격·기록·늦춘 소리가 안 샌다",
			not g.fire_used and int(g.fire_peak) == 0
			and float(g.fire_snd) <= 0.0 and int(g.fire_hot) == 0
			and float(g.fire_t) <= 0.0 and not bool(g.stop_fire),
			"used %s · peak %d · snd %.1f · hot %d"
			% [g.fire_used, g.fire_peak, g.fire_snd, g.fire_hot])

	# ── ⑬ 리셋 — 발 단위와 판 단위가 갈려 있다 ───────────────
	print("\n── ⑬ 리셋 ────────────────────────────────────")
	g.fire_t = 0.7
	g.fire_hot = 3
	g.stop_fire = true
	g.fire_snd = 123.0
	g.fire_used = true
	g.fire_peak = 4242
	g._card_reset()
	_ok("⑬ _card_reset 이 넷만 내린다",
			float(g.fire_t) <= 0.0 and int(g.fire_hot) == 0
			and not bool(g.stop_fire) and float(g.fire_snd) <= 0.0
			and bool(g.fire_used) and int(g.fire_peak) == 4242,
			"used %s · peak %d (안 바뀌어야 한다)" % [g.fire_used, g.fire_peak])
	g._start_leg()
	_ok("⑬-b _start_leg 이 여섯 다 내린다",
			float(g.fire_t) <= 0.0 and int(g.fire_hot) == 0
			and not bool(g.stop_fire) and float(g.fire_snd) <= 0.0
			and not bool(g.fire_used) and int(g.fire_peak) == 0)

	# ── ⑭ 개발자 모드 ─────────────────────────────────────
	print("\n── ⑭ 개발자 모드 ─────────────────────────────")
	_ok("⑭ 쪽 수가 여섯 그대로다(탭 폭 %.1fpx)"
			% ((Dev.W - 12.0) / float(Dev.PAGES.size())),
			Dev.PAGES.size() == 6 and (Dev.W - 12.0) / float(Dev.PAGES.size()) >= 54.0)
	var page0: int = Dev.page
	Dev.page = 5
	var rows5: int = Dev._rows(g).size()
	Dev.page = page0
	_ok("⑭-b 5쪽이 11줄이고 한 쪽 한계 19 안이다", rows5 == 11 and rows5 <= 19,
			"%d줄 (한계는 _panel y[22,352] ÷ ROW %.0f)" % [rows5, Dev.ROW])
	#  살아 있는 판을 한 톨도 안 만진다 — qa_break 의 「목표 42→42」 어법.
	_stage(0.90, 1)
	g.target = 4200
	g.total = 777
	g.last_gain = 55
	g.gold = 31
	var snap := [int(g.target), int(g.total), int(g.last_gain), int(g.leg_no),
			int(g.gold)]
	for i in range(1, 6):
		Dev.pick["ftier"] = i
		Dev._run(g, {"k": "ftier"})
	Dev.pick["fglow"] = 4
	Dev._run(g, {"k": "fglow"})
	var snap2 := [int(g.target), int(g.total), int(g.last_gain), int(g.leg_no),
			int(g.gold)]
	_ok("⑭-c 단 강제와 세기 밀기가 런 진도를 한 톨도 안 바꾼다", snap == snap2,
			"%s → %s" % [snap, snap2])
	#  _fire_sync — ▶ 한 번이 살아 있는 값을 안 내린다.
	g.fire_lock = 2
	g.fire_mul = 1.0
	Dev._grow_sync(g)
	#  ⚠ 칸 번호를 손으로 박지 않는다 — 사다리 천장을 200% → 150% 로 내린 날
	#  이 줄이 빨개졌다(1.5 가 3번 칸에서 4번 칸으로 옮겼다). 표에서 찾는다.
	var want_g: int = (Dev.FIRE_STEPS["fglow"] as Array).find(1.0)
	_ok("⑭-d 값 칸이 살아 있는 값에 매번 맞는다",
			int(Dev.pick["ftier"]) == 3 and int(Dev.pick["fglow"]) == want_g,
			"ftier %d(바람 3) · fglow %d(바람 %d)"
			% [Dev.pick["ftier"], Dev.pick["fglow"], want_g])
	g.fire_lock = -1
	g.fire_mul = 1.0
	#  「총합 걸음 다시 보기」 넷이 **가장자리도 같이** 세운다.
	_stage(0.90, 1)
	g.fire_t = 0.0
	g.fire_hot = 0
	Dev.pick["grow"] = 3              # 천장 2.00
	Dev._run(g, {"k": "grow"})
	_ok("⑭-e 「총합 걸음 다시 보기」가 테두리도 세운다",
			int(g.fire_hot) >= 1 and float(g.fire_t) > 0.0,
			"%d단 · 창 %.2f" % [g.fire_hot, g.fire_t])
	#  「한 방」(_card_big)도 같은 한 함수를 부른다 — 사본을 안 늘렸다.
	_stage(0.90, 1)
	g.fire_t = 0.0
	g.fire_hot = 0
	Dev._card_big(g)
	_ok("⑭-f 「한 방」도 테두리와 멈춤 배수를 같이 세운다",
			int(g.fire_hot) >= 1 and float(g.fire_t) > 0.0
			and float(g.hitstop) > 0.0,
			"%d단 · 창 %.2f · 멈춤 %.3f" % [g.fire_hot, g.fire_t, g.hitstop])
	_ok("⑭-g dev 쪽이 게임 식을 새로 베끼지 않았다(_fire_arm 을 부른다)",
			_dev_calls("_fire_arm") >= 2,
			"_fire_arm 부르는 자리 %d곳" % _dev_calls("_fire_arm"))

	# ── ⑮ 글자 0자 · 밸런스 불변 · 입력 ──────────────────────
	print("\n── ⑮ 글자 0자 · 밸런스 불변 · 입력 ──────────")
	_ok("⑮ _fire_edge 가 글자를 한 자도 안 그린다",
			not _src_has("func _fire_edge", "draw_string")
			and not _src_has("func _fire_edge", "pop("))
	_ok("⑮-b _fire_arm · _fire_tier 도 글자를 안 낸다",
			not _src_has("func _fire_tier", "pop(")
			and not _src_has("func _fire_arm", "pop("))
	#  세기와 단을 끝에서 끝까지 밀어도 값이 완전히 같다.
	var res := []
	for pair in [[-1, 0.0], [-1, 1.0], [0, 1.0], [4, 2.0]]:
		_stage(0.90, 1)
		g.fire_lock = int(pair[0])
		g.fire_mul = float(pair[1])
		_play()
		res.append([int(g.total), int(g.last_gain), int(g.gold), int(g.leg_no)])
	g.fire_lock = -1
	g.fire_mul = 1.0
	var same := true
	for r2 in res:
		if r2 != res[0]:
			same = false
	_ok("⑮-c 단·세기를 어떻게 밀어도 총점·이득·골드·판이 같다", same, "%s" % [res])
	#  입력이 안 막힌다 — 멈춤은 _process 만 조기 반환하고 _unhandled_input 은
	#  따로 돈다. 얼어 있는 동안 빨리 보기를 걸면 그 프레임부터 빨라진다.
	_stage(0.90, 1)
	g.fire_lock = 4
	#  걸음이 서는 프레임까지 감는다 — qt 가 다 닳아야 _next_step 이 돈다.
	var wait_n := 0
	while g.hitstop <= 0.0 and wait_n < 400:
		g._process(1.0 / 60.0)
		wait_n += 1
	var froze: float = float(g.hitstop)
	g.fast_lock = true
	g._process(1.0 / 60.0)
	var rate_in_freeze: float = float(g.fast_rate)
	g.fast_lock = false
	g.fire_lock = -1
	_ok("⑮-d 얼어 있는 동안 손을 대면 그 프레임부터 빨라진다",
			froze > 0.0 and rate_in_freeze > 1.0,
			"멈춤 %.3f · 그 프레임 배수 %.2f" % [froze, rate_in_freeze])
	#  가장 긴 멈춤이 얼마인가 — 체감의 상한이다.
	_ok("⑮-e 가장 긴 멈춤이 0.120초(빨리 보기 0.048초)다",
			absf(float(g.CARDFX.stop) * float(F.stop_mul[2]) - 0.120) < 0.001,
			"%.3f초" % (float(g.CARDFX.stop) * float(F.stop_mul[2])))


#  ── 소스 훑기 ────────────────────────────────────────────
#  「글자 0자」와 「가드를 안 베꼈다」를 재는 길이 소스 훑기밖에 없다 —
#  qa_words 가 같은 어법을 쓴다.
func _src_has(head: String, needle: String) -> bool:
	var f := FileAccess.open("res://scripts/game.gd", FileAccess.READ)
	if f == null:
		return true               # 못 읽으면 진다 — 조용히 통과시키지 않는다
	var txt := f.get_as_text()
	f.close()
	var i := txt.find(head)
	if i < 0:
		return true
	#  다음 최상위 func 까지가 그 함수 몸이다.
	var j := txt.find("\nfunc ", i + head.length())
	if j < 0:
		j = txt.length()
	return txt.substr(i, j - i).find(needle) >= 0


func _dev_calls(needle: String) -> int:
	var f := FileAccess.open("res://scripts/dev.gd", FileAccess.READ)
	if f == null:
		return 0
	var txt := f.get_as_text()
	f.close()
	var n := 0
	var i := txt.find("g." + needle)
	while i >= 0:
		n += 1
		i = txt.find("g." + needle, i + 1)
	return n
