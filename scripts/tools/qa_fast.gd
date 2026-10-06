extends SceneTree
# ══════════════════════════════════════════════════════════
#  정산 빨리 보기 — 걸음을 **하나도 안 건너뛰는가**
#
#  실행:  godot --headless --path . --script scripts/tools/qa_fast.gd
#  종료 코드 = 실패 개수
#
#  왜 있는가
#    빨리 보기는 편의성이다. 편의성이 값을 바꾸면 그건 편의성이 아니라
#    난이도 조절이다. 그래서 이 자의 본문은 「빨라졌는가」가 아니라
#    **「걸음 수 · 점수 · 골드가 한 톨도 안 바뀌었는가」**다.
#
#  무엇이 기계적 증거인가
#    _next_step 은 걸음마다 pitch_step 을 정확히 +1 하고 queue 를 하나 꺼낸다.
#    그러므로 **pitch_step 증가분과 큐 소비 수**가 배속 1 과 2.5 에서 같으면
#    「건너뛰지 않았다」가 증명된다. 프레임당 한 걸음이 구조적 상한인 것도
#    같은 자리에서 잰다(_process 의 S.RESOLVE 가지에 루프가 없다).
#
#  카드 춤 짝
#    걸음 시계(qt)만 빨리 깎고 카드 시계 다섯(total_flash · calc_flash ·
#    chip_j · mult_j · gain_roll)을 그대로 두면 글자춤이 걸음보다 2.5배
#    길어져 **다음 걸음으로 새어 나간다.** 이 자의 ⓙ 가 그 한 줄을 잡는다 —
#    걸음마다 chip_j 가 그 걸음 **안**에서 0 에 닿아야 한다.
#
#  손짓은 진짜 이벤트로 넣는다
#    「누르고 있음」은 Input.is_mouse_button_pressed 로 읽으므로 버튼 상태가
#    진짜여야 한다 — parse_input_event 가 그 상태까지 세운다(input_probe 의
#    머리말과 같은 어법). 자리는 뷰포트 좌표다(노드 좌표 + view_pad).
#    HUD 단추 둘을 피해 판 아래를 누른다 — 문지기가 그 둘을 빼기 때문이다.
# ══════════════════════════════════════════════════════════
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")

#  HUD 단추(578,20,58,44)와 사탕·사진 칸 · 동전 칸 어디에도 안 닿는 자리.
const HOLD_AT := Vector2(320.0, 330.0)

var g = null
var ok := 0
var bad := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_fast_g.cfg"
	Save.path = "user://_qa_fast.cfg"
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
	print("  %s %-46s %s" % ["통과" if cond else "실패", nm, note])


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


func _vp(p: Vector2) -> Vector2:
	return p + g.view_pad


func _btn(down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	e.pressed = down
	e.position = _vp(HOLD_AT)
	Input.parse_input_event(e)
	Input.flush_buffered_events()


#  card_shots 의 「살아 있는 정산」과 같은 세움이다. 자를 두 개 만들지 않는다.
#  sn 은 settle_n — 안 주면 큐 길이다. _pace() 가 걸음의 자리(settle_n − 남은
#  큐 − 1)를 읽으므로 sn 을 크게 주면 첫 걸음부터 눌린 자리에 선다.
func _stage(n: int, sn := -1) -> void:
	g.set_process(false)
	g._start_leg()
	g._card_reset()
	g.cur_chip = 0
	g.cur_mult = 0
	g.card_mode = 0
	g.calc_lit = false
	g.roll_t = -1.0
	g.pitch_step = 0
	g.queue.clear()
	for i in n:
		g.queue.append({"k": "chip", "v": 40 + i * 13})
	g.settle_n = sn if sn > 0 else g.queue.size()
	g.burst_n = 0
	g.burst_hits.clear()
	g.card_side = 1
	g.card_y = 74.0
	g.card_p = 1.0
	g.card_target = 1.0
	g.hitstop = 0.0
	g.state = g.S.RESOLVE
	g.qt = g.beat * g._pace()
	#  골드를 **못 박는다.** _start_leg 의 이자가 가진 골드에 비례하므로
	#  검사를 거듭하면 늘어난 골드가 다음 판의 이자를 키워, 배속과 아무
	#  상관없이 두 판의 벌이가 갈린다 — 그것은 게임이 아니라 이 자의 박자다.
	g.gold = 50
	_calm()


#  정산 한 판을 끝까지 돌린다. hold 면 왼쪽 버튼을 쥔 채로 돈다.
#    frames   전체 프레임
#    steps    걸음마다 쓴 프레임 수
#    two      한 프레임에 두 걸음이 난 적이 있나
#    leak     걸음 안에서 chip_j 가 0 에 못 닿은 적이 있나(카드 춤이 샜다)
#    wind_leak · wind_top   모음 시계(wind_t)가 걸음 안에서 0 에 못 닿은 적이
#             있나 · 그 시계가 선 가장 큰 값
#    tick_n · tick_left   띠 톡 칸을 세운 수 · 정산이 끝난 프레임에 끝 칸(착지)에
#             아직 안 닿았나
#    tf_top   띠 점수 톡 빛(tick_flash)이 선 가장 큰 값
#  q 를 주면 chip 줄 대신 그 큐를 세운다(목표는 tgt — 기본은 안 넘기게 올린다).
func _play(n: int, hold: bool, sn := -1, q := [], tgt := 100000) -> Dictionary:
	_stage(n, sn)
	if not q.is_empty():
		g.queue = q.duplicate(true)
		g.settle_n = sn if sn > 0 else q.size()
		g.target = tgt
		g.total = 0
		g.qt = g.beat * g._pace()
	#  골드는 **차이로 잰다.** _start_leg 가 판마다 이자를 얹으므로 절대값은
	#  검사를 거듭할수록 는다 — 그것은 게임이 아니라 이 자의 박자다.
	var gold0: int = g.gold
	if hold:
		_btn(true)
	var frames := 0
	var steps := []
	var cur := 0
	var two := false
	var leak := false
	var danced := false
	var src_leak := false
	var src_danced := false
	var wind_leak := false
	var wind_danced := false
	var wind_top := 0.0
	var tick_n := 0
	var tick_left := false
	var tf_top := 0.0
	while g.state == g.S.RESOLVE and frames < 4000:
		var ps0: int = g.pitch_step
		g._process(1.0 / 60.0)
		frames += 1
		cur += 1
		if g.chip_j <= 0.0:
			danced = true
		#  모음 시계(wind_t)도 같은 자로 잰다. 2026-10-06
		if g.wind_t <= 0.0:
			wind_danced = true
		#  출처 빛도 같은 시계를 탄다 — 카드 춤과 **같은 자로** 잰다.
		#  2026-09-25
		if g.src_t <= 0.0:
			src_danced = true
		if g.pitch_step > ps0:
			#  걸음이 바뀐 프레임. 앞 걸음의 춤이 그 안에서 다 끝났어야 한다 —
			#  첫 걸음(cur 이 세움부터 센 것)만 빼고 본다.
			if steps.size() > 0 and not danced:
				leak = true
			if steps.size() > 0 and not src_danced:
				src_leak = true
			src_danced = false
			if steps.size() > 0 and not wind_danced:
				wind_leak = true
			wind_danced = false
			if g.pitch_step - ps0 > 1:
				two = true
			steps.append(cur)
			cur = 0
			danced = false
		wind_top = maxf(wind_top, g.wind_t)
		#  띠 톡도 걸음 안에서 끝난다(2026-10-06). 합계가 마지막 걸음이라 정산이
		#  끝나는 프레임이 그 걸음의 끝이다 — 그 프레임까지 끝 칸(착지)에 닿았어야 한다.
		#  _tick_score 가 _next_step 앞이라 같은 프레임의 착지도 안이다.
		if g.tick_n > 0:
			tick_n = g.tick_n
			tick_left = g.tick_i < g.tick_n
		tf_top = maxf(tf_top, g.tick_flash)
	if hold:
		_btn(false)
	return {"frames": frames, "steps": steps, "two": two, "leak": leak,
			"src_leak": src_leak, "wind_leak": wind_leak, "wind_top": wind_top,
			"tick_n": tick_n, "tick_left": tick_left, "tf_top": tf_top,
			"tf_end": g.tick_flash, "gn": g._grow_n(), "pitch": g.pitch_step, "total": g.total, "gold": g.gold - gold0,
			"chip": g.cur_chip, "mult": g.cur_mult, "shown": g.shown,
			#  ⚠ 「정산이 끝나면 카드 시계가 다 0」을 재는 그물이 **넷만 보고**
			#  있었다. score_roll·src_t 를 안 적으면 정산 뒤에 굴림과 선이 남는
			#  것을 아무도 못 본다 — total_flash 가 이미 한 번 겪은 사고다
			#  (_card_reset 주석: 「어디서도 안 지워졌다」). 2026-09-26
			#  모음 시계(wind_t) · 띠 점수 톡 빛(tick_flash)도 같은 그물에 든다. 2026-10-06
			"flash": maxf(maxf(maxf(g.total_flash, g.chip_j),
					maxf(g.mult_j, g.gain_roll)),
					maxf(maxf(g.score_roll, g.src_t), maxf(g.wind_t, g.tick_flash)))}


func _min_step(steps: Array) -> int:
	var m := 9999
	for s in steps:
		m = mini(m, int(s))
	return m


func _run() -> void:
	g._new_run()
	_calm()

	# ── ⓐ 안 누르면 오늘 그대로 ────────────────────────
	var slow := _play(8, false)
	_ok("안 누르면 배수가 1 이다", is_equal_approx(g._fast_rate(), 1.0),
			"%.2f" % g._fast_rate())

	# ── ⓑⓒ 걸음 수와 값이 같다 ─────────────────────────
	var fast := _play(8, true)
	_ok("걸음 수가 같다 — 하나도 안 건너뛴다",
			slow.pitch == fast.pitch and slow.steps.size() == fast.steps.size(),
			"보통 %d걸음 · 빨리 %d걸음" % [slow.steps.size(), fast.steps.size()])
	_ok("한 프레임에 두 걸음이 안 난다", not fast.two)
	_ok("점수가 한 톨도 안 바뀐다",
			slow.total == fast.total and slow.chip == fast.chip
			and slow.mult == fast.mult,
			"%d/%d/%d ↔ %d/%d/%d" % [slow.total, slow.chip, slow.mult,
					fast.total, fast.chip, fast.mult])
	_ok("골드가 한 톨도 안 바뀐다", slow.gold == fast.gold,
			"%d ↔ %d" % [slow.gold, fast.gold])
	_ok("점수판이 같은 수에 선다", is_equal_approx(slow.shown, fast.shown),
			"%.4f ↔ %.4f" % [slow.shown, fast.shown])

	# ── ⓓ 프레임만 줄었다 ────────────────────────────
	var ratio: float = float(slow.frames) / maxf(float(fast.frames), 1.0)
	_ok("프레임만 준다 (2.4~2.6배)", ratio > 2.35 and ratio < 2.65,
			"%d → %d 프레임 · %.2f배" % [slow.frames, fast.frames, ratio])

	# ── ⓔ 어떤 걸음도 4프레임 밑으로 안 간다 ───────────────
	_ok("가장 짧은 걸음이 4프레임 이상", _min_step(fast.steps) >= 4,
			"%d프레임 · 걸음들 %s" % [_min_step(fast.steps), fast.steps])

	# ── ⓙ 카드 춤이 걸음을 안 넘긴다 ──────────────────────
	_ok("카드 춤이 걸음 안에서 끝난다 (3273~ 짝)", not fast.leak)
	#  정산 출처 짚기의 빛도 **같은 시계**를 탄다. 안 태우면 2.5배에서
	#  판이 여러 걸음치 밝은 채로 겹쳐 「출처를 더 잘 보여 준다」가 오히려
	#  더 안 읽히게 된다. 2026-09-25
	_ok("출처 빛이 걸음 안에서 끝난다", not fast.src_leak)
	_ok("정산이 끝나면 출처 빛도 0", g.src_t <= 0.0001, "%.4f" % g.src_t)
	_ok("정산이 끝나면 카드 시계가 다 0", fast.flash <= 0.0001,
			"최대 %.4f" % fast.flash)

	# ── 눌린 박자에서도 바닥이 지켜진다 ────────────────────
	#  pace 0.30 은 걸음 0.114초 = 6.8프레임. 한도가 1.71 이라 딱 4프레임이다.
	#  settle_n 40 · 큐 20 이면 첫 걸음이 자리 20 이라 전부 바닥이다.
	var pslow := _play(20, false, 40)
	var pfast := _play(20, true, 40)
	_ok("눌린 박자 — 걸음 수가 같다",
			pslow.pitch == pfast.pitch, "%d ↔ %d" % [pslow.pitch, pfast.pitch])
	_ok("눌린 박자 — 걸음이 4프레임 밑으로 안 간다",
			_min_step(pfast.steps) >= 4,
			"pace %.2f · 최소 %d프레임" % [g._pace(), _min_step(pfast.steps)])
	_ok("눌린 박자 — 값이 같다",
			pslow.total == pfast.total and pslow.gold == pfast.gold
			and pslow.chip == pfast.chip,
			"점수 %d/%d · 골드 %d/%d · 기본 %d/%d" % [pslow.total, pfast.total,
					pslow.gold, pfast.gold, pslow.chip, pfast.chip])

	# ── ⓜ 긴 정산은 앞에서 셈해 뒤로 갈수록 잰다 (2026-10-06) ──────
	#  앞 네 걸음(자리 0~3)은 온 박이고 그 뒤로 한 걸음도 안 길어진다.
	#  steps[0] 은 머리 숨이고 steps[k] 가 자리 k−1 의 걸음이다(마지막 걸음은
	#  정산이 끝나는 프레임에 루프가 멎어 안 적힌다).
	var ramp := _play(16, false)
	var rs: Array = (ramp.steps as Array).slice(1)
	var r_mono := true
	for k in range(1, rs.size()):
		if int(rs[k]) > int(rs[k - 1]):
			r_mono = false
	var floor_f: int = int(ceil(g.beat * float(g.PACE.min) * 60.0))
	_ok("ⓜ 걸음이 자리를 따라 한 번도 안 길어진다", r_mono, "%s" % [rs])
	_ok("ⓜ-b 앞 네 걸음이 같고 다섯째부터 짧아진다",
			rs.size() >= 5 and int(rs[0]) == int(rs[3]) and int(rs[4]) < int(rs[3]),
			"%s" % [rs.slice(0, 6)])
	_ok("ⓜ-c 꼬리 걸음은 바닥(PACE.min)에 닿는다",
			rs.size() >= 12 and absi(int(rs[rs.size() - 1]) - floor_f) <= 1,
			"자리 %d → %d프레임 · 바닥 %d프레임" % [rs.size() - 1,
					int(rs[rs.size() - 1]), floor_f])

	# ── ⓝ 합계 걸음은 정산이 길어도 안 줄어든다 ──────────────
	#  같은 값의 합계 걸음을 자리 2 와 자리 14 에 세운다. 셈 걸음이면 자리 14 는
	#  바닥(0.30)인데 합계 걸음은 두 자리에서 같은 이름값이다.
	#  목표를 안 넘기고 「한 방」 문턱 밑이라 멈춤도 없다.
	var tq := []
	var tp := []
	for sn2 in [3, 15]:
		_stage(1, sn2)
		g.queue = [{"k": "total"}]
		g.cur_chip = 40
		g.cur_mult = 1
		g.score_mul = 1.0
		g.score_mode = "std"
		g.target = 100000
		g.total = 0
		g._next_step()
		tq.append(float(g.qt) + float(g.hitstop))
		tp.append(g._pace())
	_ok("ⓝ 합계 걸음이 자리 2 와 14 에서 같은 길이다",
			absf(float(tq[0]) - float(tq[1])) < 0.0001
			and absf(float(tq[0]) - g.beat * float(g.TALLY.tot)) < 0.0005
			and float(tp[1]) <= float(g.PACE.min) + 0.0001,
			"%.4f초 ↔ %.4f초 (그 자리의 셈 걸음 배수 %.2f ↔ %.2f)"
			% [tq[0], tq[1], tp[0], tp[1]])

	# ── ⓞ 바닥 자리의 합계 걸음도 2.5배를 그대로 탄다 ─────────
	#  한도는 걸음 배수로 서는데 합계 걸음은 _pace() 를 안 타므로 step_pf 가 그
	#  배수를 쥔다. 안 쥐면 긴 정산 끝의 합계가 바닥 걸음 한도에 묶인다.
	_stage(1, 40)
	g.queue = [{"k": "total"}]
	g.cur_chip = 40
	g.cur_mult = 1
	g.target = 100000
	g.total = 0
	g._next_step()                   # 자리 39
	_btn(true)
	var rt_tot: float = g._fast_rate()
	var pf_keep: float = g.step_pf
	g.step_pf = 0.0                  # 같은 자리의 셈 걸음이 받는 한도
	var lim_cnt: float = g._fast_lim()
	g.step_pf = pf_keep
	_btn(false)
	_ok("ⓞ 바닥 자리의 합계 걸음이 2.5배다",
			is_equal_approx(rt_tot, 2.5) and lim_cnt < 2.5,
			"합계 %.2f배 · 같은 자리 셈 걸음 한도 %.2f배" % [rt_tot, lim_cnt])

	# ── ⓟ 모음 걸음 — 시계가 걸음 안에서 끝나고 2.5배를 그대로 탄다 (2026-10-06) ──
	#  [점수 · 배수 · 모음 · 합계] 를 보통 · 빨리 보기로 돌린다. steps[3] 이 모음
	#  걸음이다(steps[0] 은 머리 숨). 모음 걸음은 _pace() 를 안 타므로 바닥 자리
	#  (자리 38)에서도 step_pf 가 한도를 쥔다 — 합계 걸음 ⓞ 와 같은 자리다.
	var wq := [{"k": "chip", "v": 40}, {"k": "mult", "v": 3}, {"k": "wind"},
			{"k": "total"}]
	var wslow := _play(0, false, -1, wq)
	var wfast := _play(0, true, -1, wq)
	_ok("ⓟ 모음 시계가 걸음 안에서 끝난다 (1배 · 2.5배)",
			wslow.wind_top >= 1.0 - 0.0001 and wfast.wind_top >= 1.0 - 0.0001
			and not wslow.wind_leak and not wfast.wind_leak,
			"최대 %.2f · %.2f" % [wslow.wind_top, wfast.wind_top])
	_ok("ⓟ-b 정산이 끝나면 모음 시계도 0", wslow.flash <= 0.0001
			and wfast.flash <= 0.0001 and g.wind_t <= 0.0001,
			"최대 %.4f · %.4f" % [wslow.flash, wfast.flash])
	#  띠 톡 — 합계 걸음 안에서 끝 칸(착지)까지 닿는다(1배 · 2.5배). 2026-10-06
	_ok("ⓟ-f 띠 톡이 합계 걸음 안에서 끝난다 (1배 · 2.5배)",
			int(wslow.tick_n) >= 4 and int(wfast.tick_n) >= 4
			and not bool(wslow.tick_left) and not bool(wfast.tick_left),
			"칸 %d · %d · 남은 칸 %s · %s" % [int(wslow.tick_n), int(wfast.tick_n),
					wslow.tick_left, wfast.tick_left])
	#  띠 점수 톡 빛(tick_flash)도 합계 걸음 안에서 0 에 닿는다 — gn 1 을 목표를
	#  넘기는 발로 세워 보통 · 빨리 보기로 돌린다. 착지 프레임에 빛이 1 로 서고 착지가
	#  카드 시계를 남은 걸음에 다시 매므로 그 걸음 안에서 걷힌다(TALLY.flash_r). 2026-10-06
	var gq := [{"k": "chip", "v": 2000}, {"k": "mult", "v": 1}, {"k": "wind"},
			{"k": "total"}]
	var tslow := _play(0, false, -1, gq, 1000)
	var tfast := _play(0, true, -1, gq, 1000)
	_ok("ⓟ-g 띠 톡 빛이 합계 걸음 안에서 0 에 닿는다 (gn 1 · 1배 · 2.5배)",
			float(tslow.gn) >= 1.0 - 0.0001 and float(tfast.gn) >= 1.0 - 0.0001
			and float(tslow.tf_top) >= 1.0 - 0.0001 and float(tfast.tf_top) >= 1.0 - 0.0001
			and float(tslow.tf_end) <= 0.0001 and float(tfast.tf_end) <= 0.0001
			and not bool(tslow.tick_left) and not bool(tfast.tick_left)
			and float(wslow.tf_top) >= 1.0 - 0.0001,
			"gn %.2f · 끝 빛 %.4f · %.4f · %d → %d프레임" % [float(tslow.gn),
					float(tslow.tf_end), float(tfast.tf_end), int(tslow.frames),
					int(tfast.frames)])
	var wf_want: int = int(ceil(g.beat * float(g.TALLY.wind) * 60.0))
	var wf_fast: int = int(ceil(g.beat * float(g.TALLY.wind) * 60.0 / 2.5))
	_ok("ⓟ-c 모음 걸음이 이름값 그대로 서고 2.5배로 준다",
			(wslow.steps as Array).size() >= 4 and (wfast.steps as Array).size() >= 4
			and absi(int(wslow.steps[3]) - wf_want) <= 1
			and absi(int(wfast.steps[3]) - wf_fast) <= 1,
			"%d → %d프레임 (식 %d → %d)" % [int(wslow.steps[3]),
					int(wfast.steps[3]), wf_want, wf_fast])
	_stage(1, 40)
	g.queue = [{"k": "wind"}, {"k": "total"}]
	g.cur_chip = 40
	g.cur_mult = 1
	g.target = 100000
	g.total = 0
	g._next_step()                   # 자리 38
	_btn(true)
	var rt_wd: float = g._fast_rate()
	_btn(false)
	_ok("ⓟ-d 바닥 자리의 모음 걸음이 2.5배다", is_equal_approx(rt_wd, 2.5),
			"모음 %.2f배 · 그 자리 배수 %.2f" % [rt_wd, g._pace()])
	#  모음은 beat*_pace() 보다 짧은 걸음이라 한도가 _pace() 가 아니라 제 배수로
	#  서야 바닥(4프레임)이 산다. 앞자리(_pace 1)에서 박자를 0.20 으로 눌러 잰다 —
	#  maxf(_pace(), …) 로 서면 2.5배에서 3.4프레임이 된다.
	var b_wd: float = g.beat
	g.beat = 0.20
	_stage(1, 3)
	g.queue = [{"k": "wind"}, {"k": "total"}]
	g.cur_chip = 40
	g.cur_mult = 1
	g.target = 100000
	g.total = 0
	g._next_step()                   # 자리 1 · _pace() 1.0
	_btn(true)
	var rt_lo: float = g._fast_rate()
	_btn(false)
	var wd_fr: float = g.qt * 60.0 / maxf(rt_lo, 1.0)
	g.beat = b_wd
	_ok("ⓟ-e 눌린 박자의 모음 걸음도 4프레임 밑으로 안 간다",
			wd_fr >= float(g.FAST.floor) - 0.001 and rt_lo > 1.0,
			"%.2f배 → %.2f프레임 (그 자리 배수 %.2f)" % [rt_lo, wd_fr, g._pace()])

	# ── ⓖ 떼면 그 프레임부터 제 속도 ──────────────────────
	_stage(8)
	_btn(true)
	for i in 3:
		g._process(1.0 / 60.0)
	var q0: float = g.qt
	g._process(1.0 / 60.0)
	var dheld: float = q0 - g.qt
	_btn(false)
	q0 = g.qt
	g._process(1.0 / 60.0)
	var dfree: float = q0 - g.qt
	_ok("누르는 동안은 2.5배로 깎는다",
			absf(dheld - (1.0 / 60.0) * 2.5) < 0.0005, "%.5f" % dheld)
	_ok("떼면 **그 프레임부터** 제 속도",
			absf(dfree - (1.0 / 60.0)) < 0.0005, "%.5f" % dfree)

	# ── ⓘ 멈춤(hitstop)이 도는 프레임에도 안 얼어붙는다 ──────
	_stage(8)
	_btn(true)
	g.hitstop = 0.10
	var h0: float = g.hitstop
	g._process(1.0 / 60.0)
	_ok("멈춤도 같은 배수로 준다 (비율 불변)",
			absf((h0 - g.hitstop) - (1.0 / 60.0) * 2.5) < 0.0005,
			"%.5f" % (h0 - g.hitstop))
	g.hitstop = 0.0
	_btn(false)

	# ── ⓗ 문지기 ────────────────────────────────────
	_stage(8)
	_btn(true)
	_ok("문지기 — 눌렀으면 켜진다", is_equal_approx(g._fast_rate(), 2.5),
			"%.2f" % g._fast_rate())
	var gates := {
		"배움 중": func(): g.tutor_id = "u_leg",
		"개발자 판": func(): Dev.on = true,
		"갈아 끼우는 중": func(): g.swap_live = true,
		"사진이 덮음": func(): g.photo = "paint",
		"동전 고르는 중": func(): g.photo_rack = "burn",
		"오토플레이": func(): g._autoplay = true,
		"손에 들림": func(): g.hand_st = g.H.ARMED,
	}
	for nm in gates:
		_calm()
		g.state = g.S.RESOLVE
		gates[nm].call()
		_ok("문지기 — %s 에는 안 빨라진다" % nm,
				is_equal_approx(g._fast_rate(), 1.0), "%.2f" % g._fast_rate())
	_calm()
	g.state = g.S.RESOLVE
	#  HUD 단추 위에서는 안 걸린다 — 「설정」을 누르는 손이 정산을 재촉하지
	#  않게 한다. mouse_at 만 옮긴다(누름 상태는 그대로다).
	for i in 2:
		g.mouse_at = g._hud_btn_rect(i).get_center()
		_ok("문지기 — HUD 단추 %d 위에서는 안 빨라진다" % i,
				is_equal_approx(g._fast_rate(), 1.0))
	g.mouse_at = HOLD_AT
	_ok("단추를 벗어나면 다시 걸린다", is_equal_approx(g._fast_rate(), 2.5))
	#  정산이 아닌 화면에서는 눌러도 아무 일이 없다.
	for st in ["PICK", "AIM_V", "SHOP", "LEG", "CLEAR", "OVER"]:
		g.state = int(g.S[st])
		_ok("문지기 — %s 에는 배속이 없다" % st,
				is_equal_approx(g._fast_rate(), 1.0))
	g.state = g.S.RESOLVE
	_btn(false)
	_ok("떼면 꺼진다", is_equal_approx(g._fast_rate(), 1.0))

	# ── 개발자 고정 ──────────────────────────────────
	g.fast_lock = true
	_ok("개발자 고정 — 안 눌러도 걸린다", g._fast_on())
	Dev.on = true
	_ok("개발자 고정 — 개발자 판을 연 채로도 걸린다", g._fast_on())
	Dev.on = false
	g.fast_lock = false

	# ── ⓚ curve_probe 안전 — beat 를 누르면 가속이 통째로 꺼진다 ──
	var b0: float = g.beat
	g.beat = 0.015
	_ok("beat 0.015 → 한도가 1.0 (가속 꺼짐)",
			is_equal_approx(g._fast_lim(), 1.0), "%.3f" % g._fast_lim())
	g.beat = b0
	_ok("돌려놓으면 한도가 1 을 넘는다", g._fast_lim() > 1.0,
			"%.2f" % g._fast_lim())

	# ── 사다리 — 3배를 골라도 바닥이 이긴다 ────────────────
	_stage(20, 40)                   # pace 0.30
	g.fast_mul = 3.0
	_btn(true)
	#  한도가 2.5 밑이어야 「바닥이 이긴다」다 — 앞 합계 걸음의 step_pf 가
	#  세움(_card_reset)에서 안 내려가면 한도가 5.70 으로 서서 여기서 진다.
	_ok("사다리 3배도 바닥에 눌린다",
			g._fast_rate() <= g._fast_lim() + 0.0001
			and g._fast_lim() < float(g.FAST.mul),
			"rate %.2f · 한도 %.2f" % [g._fast_rate(), g._fast_lim()])
	_btn(false)
	g.fast_mul = 2.5

	# ── ⓛ 걸음에 매인 신호가 걸음과 **같은 비로** 준다 (2026-09-25) ──
	#  슬롯 달아오름(PANEL.hot 0.62초)과 동전 팝(0.9초)만 빨리 보기를 안
	#  타고 있었다 — 2.5배에서 각각 걸음 넷 · 여섯을 덮어 「어느 동전이
	#  방금 발동했나」와 「이번 걸음의 수가 몇인가」가 여러 걸음치 겹쳤다.
	#  같은 **벽시계 시간**(25프레임 1배 = 10프레임 2.5배)을 태워 두 값이
	#  같은 자리에 오는지로 잰다. ⓙ 의 카드 시계 여섯과 같은 계약이다.
	var hot := []
	var age := []
	for hz in [[25, 1.0], [10, 2.5]]:
		_stage(8)
		g.fast_lock = float(hz[1]) > 1.0
		g.fast_mul = float(hz[1])
		#  슬롯 배열은 owned 가 아니라 max_items() 로 선다 — 동전을
		#  쥐여 줄 필요가 없다.
		g._panel_reset()
		g._panel_fire(0)
		(g.pops as Array).clear()
		g.pop(g.BC, "+1", g.C_CHIP, 12, 0.9)
		for _f in int(hz[0]):
			g._process(1.0 / 60.0)
		hot.append(float(g.slot_hot[0]))
		age.append(0.0 if (g.pops as Array).is_empty()
				else float((g.pops as Array)[0].t))
	g.fast_lock = false
	g.fast_mul = 2.5
	g._panel_reset()
	_ok("슬롯 달아오름이 빨리 보기를 탄다",
			absf(float(hot[0]) - float(hot[1])) < 0.02,
			"1배 25프레임 %.3f ↔ 2.5배 10프레임 %.3f" % [hot[0], hot[1]])
	_ok("동전 팝이 빨리 보기를 탄다",
			absf(float(age[0]) - float(age[1])) < 0.02,
			"1배 25프레임 %.3f ↔ 2.5배 10프레임 %.3f" % [age[0], age[1]])
