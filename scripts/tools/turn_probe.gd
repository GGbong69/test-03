extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")

# ══════════════════════════════════════════════════════════
#  라운드 경계 한 박자 회귀 검사
#
#  실행:  godot --path . --headless --quit-after 4000 --script scripts/tools/turn_probe.gd
#  종료 코드 = 실패 개수
#
#  이 연출의 약속은 판 갈이(_swap_*)와 같다 — **그림만 붙잡고 게임은 안
#  만진다.** 여기에 하나가 더 붙는다: **라운드 경계에서만 난다.** 판과 판
#  사이에서도 나면 「넘어갔다」라는 뜻이 그 자리에서 사라진다.
#
#  재는 것
#    ① 경계에서만 난다 — 런에 정확히 일곱 번
#    ② 박자 — _deal_time() 에 묶여 있고 [0.36, 0.56] 밖으로 안 나간다
#    ③ 키와 클릭 **둘 다** 즉시 끝낸다(모바일에 키가 없다).
#       클릭은 **진짜 이벤트**로 잰다 — g._click() 을 직접 부르면 그 앞에 선
#       _tutor_click · _hand_press 가 누름을 삼키는 사고를 못 잡는다
#    ④ 매듭이 연출보다 **먼저** 적힌다
#    ⑤ 게임 상태를 한 비트도 안 바꾼다(run_rng 포함)
#    ⑥ 판정 사각이 한 픽셀도 안 움직인다
#    ⑦ 큰 줄이 화면 안이고 선 카드를 안 덮는다
#    ⑧ 드는 문 넷이 다 막힌다
#    ⑨ 단추가 연출 중에 안 선다
#    ⑩ 소리 — 새 파일이 하나도 안 늘었다 · 반음 사다리가 맞다
# ══════════════════════════════════════════════════════════

const F := 1.0 / 60.0

var fails := 0


func _say(ok: bool, name: String, detail := "") -> void:
	print("  %s %-46s %s" % ["OK  " if ok else "실패", name, detail])
	if not ok:
		fails += 1


func _wind(g: Node, sec: float) -> void:
	var t := 0.0
	while t < sec:
		g._process(F)
		t += F


func _key(g: Node, code: int) -> void:
	var e := InputEventKey.new()
	e.pressed = true
	e.keycode = code
	g._unhandled_input(e)


#  **진짜 이벤트**로 누른다. g._click() 을 직접 부르면 그 앞에 선 _tutor_click
#  과 _hand_press 를 통째로 건너뛰어, 저 둘이 누름을 삼키는 사고를 못 잡는다 —
#  실제로 동전 슬롯이 연출 중에 잡히고 있었는데 옛 검사가 통과했다. 2026-09-20
func _press(g: Node, p: Vector2, down := true) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = p + g.view_pad
	g._unhandled_input(e)


#  동전 한 닢. owned 는 **사전 배열**이다 — 문자열을 넣으면 _run_save 와
#  _tip_build 가 조용히 토한다. 2026-09-20
func _coin(id: String) -> Dictionary:
	for it in GameData.items():
		if String(it.id) == id:
			var c: Dictionary = it.duplicate()
			c.gs = 0
			c.bought = 1
			return c
	return {}


func _motion(g: Node, p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p + g.view_pad
	g._unhandled_input(e)


#  판정에 쓰이는 사각 전부. 연출이 이 중 하나라도 옮기면 안 보이는 자리를
#  누르게 된다 — swap_probe 의 목록에 판 선택의 단추 둘을 더한다.
func _rects(g: Node) -> Array:
	return [g._mag_rect(0), g._slot_rect(0), g._cons_rect(0), g._panel_rect(),
			g._bank_rect(), g._reroll_rect(), g._next_rect(),
			g._row_rect(0, GameData.legs_per_round()),
			g._leg_go(), g._leg_skip()]


#  게임 상태 한 벌. 연출 전후로 이 문자열이 한 글자라도 달라지면 실패다.
func _snap(g: Node) -> String:
	return "%d|%d|%d|%d|%s|%d|%d|%d|%d|%d|%d|%d|%d|%.4f" % [
			g.leg_no, g.state, g.gold, g.target, g.leg_tag,
			g.leg_tags.size(), g.leg_skipped.size(), g.boss_mods.size(),
			g.magazine.size(), g.owned.size(), g.sealed, g.stock.size(),
			int(g.run_rng.state), g.shake]


#  판 n 에서 판 n+1 로 넘긴다. 연출은 안 감는다.
func _step(g: Node, n: int) -> void:
	g._turn_skip()
	g.leg_no = n
	g._open_leg()
	g._next_leg()


func _initialize() -> void:
	Save.path = "user://_probe_turn.cfg"
	Save.wipe()
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g._new_run()

	var per := GameData.legs_per_round()
	var legs := GameData.legs_n()

	# ── ① 경계에서만 난다 ──────────────────────────────
	print("① 경계에서만 난다")
	var lit: Array[int] = []
	var wrong := 0
	for n in range(1, legs):
		_step(g, n)
		if g.turn_live:
			lit.append(n)
			if GameData.round_of(n + 1) == GameData.round_of(n):
				wrong += 1
		elif GameData.round_of(n + 1) != GameData.round_of(n):
			wrong += 1
	g._turn_skip()
	var want_n: int = GameData.rounds_n() - 1
	_say(lit.size() == want_n and wrong == 0,
			"경계에서만 켜진다", "켜진 판 %s (기대 %d번)" % [str(lit), want_n])
	_say(lit.size() == 7, "한 런에 정확히 일곱 번", "%d번" % lit.size())

	#  _open_leg 은 방아쇠가 아니다 — 되살리기 · 새 런 · dev.gd 가 다 이 길이다
	g.leg_no = per * 2          # 라운드 2 의 마지막 판
	g._open_leg()
	_say(not g.turn_live, "_open_leg 을 직접 불러도 안 켜진다")
	g._new_run()
	_say(not g.turn_live, "런 첫 판에는 안 난다", "판 %d" % g.leg_no)

	#  건너뛰기는 경계를 절대 안 넘는다(legs.csv 의 skippable 이 보스를 막는다)
	var skip_lit := 0
	for n in range(1, legs):
		g._turn_skip()
		g.leg_no = n
		g._open_leg()
		if GameData.skippable(n):
			g._skip_leg()
			if g.turn_live:
				skip_lit += 1
	g._turn_skip()
	_say(skip_lit == 0, "건너뛰기는 경계를 안 넘는다", "켜진 횟수 %d" % skip_lit)

	# ── ② 박자 ────────────────────────────────────────
	print("② 박자")
	var deal: float = g._deal_time()
	var span: float = g._turn_span()
	_say(is_equal_approx(span, clampf(deal, 0.36, 0.56)),
			"박자가 딜에 묶여 있다", "딜 %.3f → %.3f초" % [deal, span])
	_say(absf(deal - 0.56) < 0.001, "딜이 한 톨도 안 밀렸다", "%.3f초" % deal)
	_say(absf(g._turn_total() - 0.56) < 0.001,
			"오늘 총 길이 0.56초", "%.3f초" % g._turn_total())
	_say(span >= 0.36 and span <= 0.56, "반려선 [0.36, 0.56] 안이다")
	_say(absf(float(g.SWAP.dur) - 0.36) < 0.001,
			"판 갈이 0.36 이 그대로다", "%.3f초" % float(g.SWAP.dur))

	#  스스로 끝나고, 끝나면 세 값이 정확히 제자리다
	_step(g, per * 2)
	var total: float = g._turn_total()
	_wind(g, total * 1.05)
	_say(not g.turn_live and is_zero_approx(g.turn_t) and g.turn_from == 0,
			"스스로 끝나고 제자리로",
			"live=%s t=%.4f from=%d" % [g.turn_live, g.turn_t, g.turn_from])

	#  motion_off — 걸음 길이가 아니라 걸음 **수**가 준다. 옮기는 동작
	#  (rise·hold·home)만 빠지고 **크기는 안 빠진다.**
	g.motion_off = true
	_step(g, per * 2)
	var moff: float = g._turn_total()
	var kmin := 9.0
	var kmax := -9.0
	while g.turn_live:
		kmin = minf(kmin, g._turn_k())
		kmax = maxf(kmax, g._turn_k())
		g._process(F)
	_say(absf(moff - 0.190) < 0.002, "모션 끄면 0.190초", "%.3f초" % moff)
	#  ⚠ 여기가 한 번 0 이었다. k 가 0 이면 줄이 5px 이고 스크림(TURN.scrim x k)
	#  도 0 이라, 움직임을 끄러 온 손님은 **사용자가 「모르겠다」고 한 그 크기**
	#  를 받으면서 입력 잠금 0.190초와 단추 깜박임만 치렀다. 지금은 1 로 못
	#  박는다 — 큰 줄이 컷으로 서고 한 프레임도 안 움직인다. 2026-09-20
	_say(is_equal_approx(kmin, 1.0) and is_equal_approx(kmax, 1.0),
			"모션 끄면 큰 줄이 움직임 없이 선다", "k [%.4f, %.4f]" % [kmin, kmax])
	_say(is_equal_approx(float(g.TURN.scrim) * kmax, float(g.TURN.scrim)),
			"모션 꺼도 스크림이 선다 (맨몸으로 단추만 사라지지 않는다)")
	g.motion_off = false

	#  배움 늦추기가 박자를 **안** 늘린다. tutor.csv 의 u_leg 는 slow 0.30 이고
	#  _open_leg 이 바로 그 갈래를 세우므로, 옛 코드에서는 0.56초가 **1.87초**가
	#  됐다 — 반려선 0.59 의 세 배다. 게다가 늦추는 그 말상자는 연출에 가려
	#  보이지도 않았다. 2026-09-20
	_step(g, per * 2)
	g.tutor_id = "u_leg"               # 말상자가 다 서 있는 자리로 박는다
	g.tutor_i = 0
	g.tutor_pre = 0.0
	g.tutor_out = 0.0
	g.tutor_t = 10.0
	_say(absf(g._tutor_slow() - 0.30) < 0.01, "배움 배수가 0.30 이다",
			"%.3f배" % g._tutor_slow())
	var slow_t := 0.0
	while g.turn_live and slow_t < 3.0:
		g._process(F)
		slow_t += F
	_say(absf(slow_t - total) < 0.03, "배움 늦추기 0.30 배에서도 총 길이가 같다",
			"%.3f초 (기대 %.3f)" % [slow_t, total])
	g._tutor_close()
	g._turn_skip()

	# ── ③ 키와 클릭 둘 다 ──────────────────────────────
	print("③ 건너뛰는 길")
	#  두 길을 **각자의 직전 상태**와 견준다. 두 스냅샷을 서로 대면 안 된다 —
	#  라운드가 열릴 때 뱃지(leg_tag)를 전역 randi 로 굴리므로 두 번 열면
	#  당연히 다르다. 물어야 하는 것은 「건너뛰기가 무엇을 바꿨는가」이고,
	#  답은 둘 다 **아무것도** 여야 한다. 2026-09-20
	_step(g, per * 2)
	_wind(g, 0.10)
	var pre_k := _snap(g)
	_key(g, KEY_SPACE)
	var post_k := _snap(g)
	var rest_k := "%s|%.4f|%d" % [g.turn_live, g.turn_t, g.turn_from]
	_say(not g.turn_live, "아무 키나 누르면 끝난다")
	_say(post_k == pre_k, "키로 건너뛰어도 게임이 그대로다")

	_step(g, per * 2)
	_wind(g, 0.10)
	var pre_c := _snap(g)
	var st0: int = g.state
	var rem0: int = g.remaining.size()
	g._click(g._leg_go().get_center())
	var post_c := _snap(g)
	var rest_c := "%s|%.4f|%d" % [g.turn_live, g.turn_t, g.turn_from]
	_say(not g.turn_live, "아무 데나 누르면 끝난다(손가락)")
	_say(post_c == pre_c, "클릭으로 건너뛰어도 게임이 그대로다")
	_say(rest_k == rest_c, "두 길이 같은 끝 상태로 간다", rest_k)
	_say(g.state == st0 and g.remaining.size() == rem0,
			"누름이 밑 화면으로 안 샌다", "state %d · %d발" % [g.state, g.remaining.size()])

	#  ⚠ **진짜 이벤트**로 다시 잰다. 위의 g._click() 은 그 앞에 선
	#  _tutor_click 과 _hand_press 를 통째로 건너뛰므로, 저 둘이 누름을 삼키면
	#  이 검사가 통과한 채로 손님만 잠긴다. 실제로 둘 다 삼키고 있었다.
	#  ① 배움 띠가 살아 있어도 손가락 하나로 끝난다(키 전용 길을 안 만든다)
	_step(g, per * 2)
	_wind(g, 0.10)
	g.tutor_id = "u_leg"
	g.tutor_i = 0
	g.tutor_pre = 0.0
	g.tutor_out = 0.0
	g.tutor_t = 10.0
	_press(g, g._leg_go().get_center())
	_press(g, g._leg_go().get_center(), false)
	_say(not g.turn_live, "배움 띠가 살아 있어도 손가락으로 끝난다")
	g._tutor_close()
	g._turn_skip()

	#  ② 동전 슬롯·사탕 칸을 눌러도 잡히지 않고, 그 누름이 연출을 끝낸다
	g.owned = [_coin("c01"), _coin("c02"), _coin("c03")]
	_step(g, per * 2)
	_wind(g, 0.10)
	var own0 := str(g.owned)
	var slot: Rect2 = g._slot_rect(0)
	_press(g, slot.get_center())
	var grabbed: int = g.hand_st
	_motion(g, g._slot_rect(2).get_center())
	g._process(F)
	_press(g, g._slot_rect(2).get_center(), false)
	_say(grabbed == 0, "연출 중에는 동전 슬롯이 안 잡힌다", "hand_st %d" % grabbed)
	_say(not g.turn_live, "동전 슬롯을 눌러도 연출이 끝난다")
	_say(str(g.owned) == own0, "끌어 떼도 동전 순서가 그대로다",
			"%s %s %s" % [String(g.owned[0].id), String(g.owned[1].id),
			String(g.owned[2].id)])
	g._turn_skip()

	_step(g, per * 2)
	_wind(g, 0.10)
	var cons_r: Rect2 = g._cons_rect(0)
	_press(g, cons_r.get_center())
	var c_grab: int = g.hand_st
	_press(g, cons_r.get_center(), false)
	_say(c_grab == 0 and not g.turn_live,
			"사탕 칸을 눌러도 안 잡히고 연출이 끝난다", "hand_st %d" % c_grab)
	g.owned = []
	g._turn_skip()
	#  딜은 안 건너뛴다 — 오늘과 정확히 같은 자리에 선다
	var lt0: float = g.leg_t
	_wind(g, 0.10)
	_say(g.leg_t > lt0, "건너뛴 뒤에도 딜은 계속 돈다",
			"leg_t %.3f → %.3f" % [lt0, g.leg_t])

	# ── ④ 매듭이 연출보다 먼저 적힌다 ──────────────────
	print("④ 매듭")
	_step(g, per * 2)
	_say(g.turn_live and String(Save.run_get("at", "")) == "leg"
			and int(Save.run_get("leg_no", -1)) == g.leg_no,
			"연출이 도는 프레임에 매듭이 이미 있다",
			"at=%s 판 %d (지금 %d)"
			% [Save.run_get("at", ""), int(Save.run_get("leg_no", -1)), g.leg_no])
	_say(g._knot_ok(), "_knot_ok 에 turn_live 가 안 들어갔다")
	g._turn_skip()

	# ── ⑤ 게임 상태를 한 비트도 안 바꾼다 ──────────────
	print("⑤ 게임을 안 만진다")
	g.leg_no = per * 2
	g._open_leg()
	g._next_leg()
	var s0 := _snap(g)
	_wind(g, total * 1.10)
	_say(_snap(g) == s0, "0.56초를 통째로 감아도 같다", s0)

	g.leg_no = per * 2
	g._open_leg()
	g._next_leg()
	var s1 := _snap(g)
	_wind(g, total * 0.40)
	g._turn_skip()
	_say(_snap(g) == s1, "중간에 건너뛰어도 같다")
	_say(is_zero_approx(g.shake), "흔들림을 안 쓴다", "shake %.4f" % g.shake)

	# ── ⑥ 판정 사각 ───────────────────────────────────
	print("⑥ 판정 사각")
	g.leg_no = per * 2
	g._open_leg()
	var r_before := str(_rects(g))
	g._next_leg()
	var r_open := str(_rects(g))
	_wind(g, 0.28)
	var r_mid := str(_rects(g))
	var r_stamp := ""
	while g.turn_live:
		if g.turn_t >= g._turn_lit_at() and r_stamp == "":
			r_stamp = str(_rects(g))
		g._process(F)
	var r_after := str(_rects(g))
	_say(r_before == r_open and r_open == r_mid and r_mid == r_stamp
			and r_stamp == r_after, "연출 내내 한 픽셀도 안 움직인다")

	# ── ⑦ 큰 줄의 자리 ────────────────────────────────
	print("⑦ 큰 줄의 자리")
	var c0: Rect2 = g._turn_cell(0, 1.0)
	var cz: Rect2 = g._turn_cell(GameData.rounds_n() - 1, 1.0)
	_say(c0.position.x >= 0.0 and cz.end.x <= g.VIEW.x,
			"큰 줄이 화면 안이다", "x[%.1f, %.1f]" % [c0.position.x, cz.end.x])
	#  선 카드의 윗변 = 카드 발치 − h×1.12 − lift 7
	var card_top: float = g._row_rect(0, per).end.y - float(g.CARD.h) * 1.12 - 7.0
	_say(c0.end.y <= card_top, "선 카드를 안 덮는다",
			"줄 아래끝 %.1f · 카드 윗변 %.2f · 여유 %.2fpx"
			% [c0.end.y, card_top, card_top - c0.end.y])
	var home: Rect2 = g._turn_cell(0, 0.0)
	_say(is_equal_approx(home.position.x, g.LAY.bar_pip.position.x)
			and is_equal_approx(home.position.y, g.LAY.bar_pip.position.y)
			and is_equal_approx(home.size.x, g.LAY.bar_pip.size.x),
			"k=0 이면 바의 제자리다", str(home))

	# ── ⑧ 드는 문 넷 ──────────────────────────────────
	print("⑧ 드는 문")
	g._turn_skip()
	g.drop_fast = true
	g._turn_begin(1)
	_say(not g.turn_live, "소크·오토플레이는 안 켠다")
	g.drop_fast = false

	g._turn_begin(0)
	_say(not g.turn_live, "라운드 0 은 안 켠다")

	g._turn_begin(1)
	var was: bool = g.turn_live
	g._swap_skip()
	_say(was and not g.turn_live, "_swap_skip 이 같이 내린다 (도구 마흔다섯)")

	# ⑨ 단추가 연출 중에 안 선다
	g.leg_no = per * 2
	g._open_leg()
	g._next_leg()
	_say(g.turn_live and not g._hud_btns_on(), "연출 중에는 단추가 안 선다")
	#  ⚠ **안 서는 것과 안 보이는 것은 다르다.** 첫 프레임과 끝 프레임은
	#  k 가 0 이라 스크림도 0 인데, 거기서 그림까지 지우면 가리는 것 하나
	#  없이 단추 둘만 사라졌다 돌아온다 — 런에 일곱 번 나는 번쩍임이다.
	#  _hud_btns_draw 는 turn_live 를 **그리기에서 뺀다**. 2026-09-20
	_say(is_zero_approx(g._turn_k()),
			"첫 프레임의 k 가 0 이다 (그래서 스크림도 0)", "k %.4f" % g._turn_k())
	#  그린 김에 눌릴 것처럼 굴면 안 된다 — 얹힘이 살아 있으면 커서가 얹힌
	#  단추가 뜨고 menu_pick2 가 운다. 판 갈이와 같은 줄에 세웠다.
	_say(not g._ui_can_hover(), "연출 중에는 얹힘도 죽는다")
	g._turn_skip()
	_say(g._hud_btns_on(), "끝나면 단추가 다시 선다")

	# ── ⑨' 개발자 모드가 같은 연출을 연다 ──────────────
	print("⑨' 개발자 모드")
	g._turn_skip()
	g.leg_no = per * 3 + 1          # 라운드 4 의 첫 판
	g._open_leg()
	var dev_leg: int = g.leg_no
	var dev_gold: int = g.gold
	Dev._run(g, {"a": "turn"})
	_say(g.turn_live, "「라운드 넘김 다시 보기」가 연출을 연다")
	_say(g.turn_from == GameData.round_of(dev_leg) - 1,
			"직전 라운드에서 넘긴다", "from %d (판 %d 은 R%d)"
			% [g.turn_from, dev_leg, GameData.round_of(dev_leg)])
	_say(g.leg_no == dev_leg and g.gold == dev_gold,
			"런 진도를 한 칸도 안 움직인다", "판 %d · 골드 %d" % [g.leg_no, g.gold])
	_say(is_zero_approx(g.leg_t), "카드 딜도 같이 되감는다", "leg_t %.3f" % g.leg_t)
	#  몇 번이고 다시 볼 수 있다 — 두 번 불러도 판이 안 는다
	Dev._run(g, {"a": "turn"})
	_say(g.leg_no == dev_leg, "다시 눌러도 판이 안 는다", "판 %d" % g.leg_no)
	g._turn_skip()

	# ── ⑩ 소리 ────────────────────────────────────────
	print("⑩ 소리 — 이 연출이 제 파일을 안 팠다")
	var wavs := 0
	var turn_wav := PackedStringArray()
	var d := DirAccess.open("res://sfx")
	if d != null:
		for f in d.get_files():
			if f.ends_with(".wav"):
				wavs += 1
				if f.begins_with("turn"):
					turn_wav.append(f)
	#  파일 **수**를 못 박으면 뒤에 오는 기능이 소리 하나만 구워도 여기가
	#  터진다 — 무한 런의 endless_go.wav 가 실제로 그랬다. 못 박을 것은
	#  「이 연출이 제 파일을 안 팠다」와 「README 가 실제 수와 맞다」다.
	#  2026-09-20
	_say(turn_wav.is_empty(), "라운드 넘김 전용 wav 가 없다", ", ".join(turn_wav))
	_say(ResourceLoader.exists("res://sfx/boss_seal.wav"),
			"boss_seal.wav 가 있다 (없으면 사다리가 말없이 죽는다)")
	_say(ResourceLoader.exists("res://sfx/page.wav"), "page.wav 가 있다")
	var rd := FileAccess.get_file_as_string("res://sfx/README.md")
	_say(rd.find(str(wavs)) >= 0, "README 의 수가 실제와 맞다", "%d개" % wavs)

	var want_hz := [392.0, 415.3, 440.0, 466.2, 493.9, 523.3, 554.4, 587.3]
	var ladder_ok := true
	var got := PackedStringArray()
	var prev := 0.0
	for r in range(1, GameData.rounds_n() + 1):
		g.leg_no = (r - 1) * per + 1
		var hz: float = g._leg_open_f()
		got.append("%.1f" % hz)
		if r <= want_hz.size() and absf(hz - float(want_hz[r - 1])) > 0.1:
			ladder_ok = false
		if hz <= prev:
			ladder_ok = false
		prev = hz
	_say(ladder_ok, "반음 사다리가 맞고 단조 증가다", ", ".join(got))
	_say(prev <= 392.0 * 1.50 + 0.1, "상한 1.50 을 안 넘는다", "%.1fHz" % prev)

	var mid_ok := true
	for r in range(1, GameData.rounds_n() + 1):
		for k in range(1, per):
			g.leg_no = (r - 1) * per + 1 + k
			if not is_zero_approx(g._leg_open_f()):
				mid_ok = false
	_say(mid_ok, "둘째·셋째 판은 안 민다 (0.0)")

	var seal_ok := true
	for n in range(1, legs):
		if GameData.round_of(n + 1) != GameData.round_of(n):
			g.leg_no = n
			g._open_leg()
			g._next_leg()
			if g._leg_open_sfx() != "boss_seal":
				seal_ok = false
			g._turn_skip()
	_say(seal_ok, "경계 일곱 번 전부 boss_seal 이 운다")

	#  도장 프레임이 boss_seal 의 꼬리(약 280ms)와 안 겹친다
	_say(g._turn_lit_at() > 0.30, "page 가 boss_seal 꼬리 뒤에 난다",
			"%.3f초 (봉인 끝 ≈0.280)" % g._turn_lit_at())

	print("\n%s" % ("실패 %d건" % fails if fails > 0 else "전부 통과"))
	quit(mini(fails, 125))
