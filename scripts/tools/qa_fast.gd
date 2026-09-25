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
func _stage(n: int) -> void:
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
	g.settle_n = g.queue.size()
	g.burst_n = 0
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
func _play(n: int, hold: bool) -> Dictionary:
	_stage(n)
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
	while g.state == g.S.RESOLVE and frames < 4000:
		var ps0: int = g.pitch_step
		g._process(1.0 / 60.0)
		frames += 1
		cur += 1
		if g.chip_j <= 0.0:
			danced = true
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
			if g.pitch_step - ps0 > 1:
				two = true
			steps.append(cur)
			cur = 0
			danced = false
	if hold:
		_btn(false)
	return {"frames": frames, "steps": steps, "two": two, "leak": leak,
			"src_leak": src_leak,
			"pitch": g.pitch_step, "total": g.total, "gold": g.gold - gold0,
			"chip": g.cur_chip, "mult": g.cur_mult, "shown": g.shown,
			"flash": maxf(maxf(g.total_flash, g.chip_j),
					maxf(g.mult_j, g.gain_roll))}


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
	#  pace 0.30 은 걸음 0.102초 = 6.1프레임. 한도가 1.53 이라 딱 4프레임이다.
	var pslow := _play(20, false)
	var pfast := _play(20, true)
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
	_stage(20)                       # pace 0.30
	g.fast_mul = 3.0
	_btn(true)
	_ok("사다리 3배도 바닥에 눌린다",
			g._fast_rate() <= g._fast_lim() + 0.0001
			and g._fast_rate() < 3.0,
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
