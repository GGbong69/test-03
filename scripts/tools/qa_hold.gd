extends SceneTree
# ══════════════════════════════════════════════════════════
#  읽기 관문 — 톡 · 길게 누르기 · 판매 단추 자리
#
#  실행:  godot --headless --path . --script scripts/tools/qa_hold.gd
#  종료 코드 = 실패 개수
#
#  왜 있는가
#    여태 툴팁은 얹힘 하나로 섰다. 손가락에는 얹힘이 없어 **모바일에서
#    동전 효과를 읽을 길이 한 곳도 없었다.** 읽기의 문을 둘 더 판다 —
#    지목(톡)과 길게 누르기. 층은 **손가락 쪽에서만** 갈린다.
#
#  이 자가 지키는 두 계약
#    ① **데스크톱 무변경.** hover_live 가 참인 동안 새 갈래는 하나도 안
#       돈다 — 얹힘만으로 태그까지 전부 서고 tip_lite 가 매 프레임 거짓으로
#       되돌려진다. 「데스크톱에서 툴팁이 0.45초 늦게 뜬다」가 구조적으로
#       불가능해야 한다.
#    ② **값 불변.** 톡도 길게 누르기도 owned · gold · cons · total 을 한 톨도
#       안 바꾼다. 임계를 넘는 순간 여는 것은 읽기뿐이고 그 손짓은 뗄 때도
#       아무것도 확정 안 한다(WCAG 2.5.2).
#
#  판매 단추 ④ 도 여기서 잰다 — 같은 손가락 자리를 두고 부딪히던 짝이라
#  한 자에서 같이 봐야 다음에 하나만 움직이는 일이 없다.
#
#  자를 새로 안 만든다
#    손가락 크기 56x20 · 자루 간격 GRIP.cy − 118 − GRIP.hit · 취소 반경
#    HAND.slip · 조준 원 BC 와 aim_click_r — 전부 있는 것을 빌린다.
#  자리는 뷰포트 좌표다(노드 좌표 + view_pad) — 손짓은 진짜 이벤트로 넣는다.
# ══════════════════════════════════════════════════════════
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")

var g = null
var ok := 0
var bad := 0
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_qa_hold_g.cfg"
	Save.path = "user://_qa_hold.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


#  ⚠ 일은 **_initialize 가 아니라 여기서** 한다. 헤드리스에서 Input 으로 민
#  손짓은 트리가 한 바퀴 돌기 시작해야 노드까지 배달된다 — _initialize 안에서
#  누르면 Input.is_mouse_button_pressed 만 서고 _unhandled_input 은 안 불린다.
#  input_probe 가 같은 자리에서 같은 이유로 _process 를 쓴다.
#  게임의 제 프레임은 끈다 — 프레임을 미는 것은 이 자다.
func _process(_d: float) -> bool:
	if g != null:
		g.set_process(false)
	if busy:
		return false
	busy = true
	_run()
	print("\n통과 %d · 실패 %d" % [ok, bad])
	quit(bad)
	return true


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
	g.hand_st = g.H.NONE
	g._autoplay = false
	g.pause_from = -1
	Dev.on = false


func _vp(p: Vector2) -> Vector2:
	return p + g.view_pad


func _btn(p: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	e.pressed = down
	e.position = _vp(p)
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _move(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if g.mouse_down else 0
	e.relative = p - g.mouse_at
	e.position = _vp(p)
	Input.parse_input_event(e)
	Input.flush_buffered_events()


#  손가락인 척. 한 번 꺼지면 다시 안 켜지므로 검사가 직접 되돌린다.
func _finger(on: bool) -> void:
	g.hover_live = not on
	g.tip_pin = {}
	g.tip_lite = false
	g.press_read = false
	g.hold_a = 0.0


func _tap(p: Vector2) -> void:
	_btn(p, true)
	g._process(1.0 / 60.0)
	_btn(p, false)
	g._process(1.0 / 60.0)
	g._tip_update(1.0 / 60.0)


#  ms 밀리초 동안 누르고 있는다. 진짜 벽시계를 쓴다 — 길게 누르기는
#  실시간으로 재므로(hitstop · 배움 늦추기에서 감도가 달라지면 안 된다)
#  프레임을 세어서는 못 잰다.
func _hold(p: Vector2, ms: int, release := true) -> void:
	_btn(p, true)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		g._process(1.0 / 60.0)
		OS.delay_msec(4)
	g._process(1.0 / 60.0)
	if release:
		_btn(p, false)
		g._process(1.0 / 60.0)
	g._tip_update(1.0 / 60.0)


func _tags() -> int:
	return (g.tip_tags as Array).size()


#  판 중 화면을 세운다. 동전 셋과 사탕 하나를 쥐여 준다.
func _stage_play() -> void:
	g._new_run()
	_calm()
	g._begin_leg()
	g._swap_skip()
	g.state = g.S.PICK
	g.owned = []
	for it in GameData.items():
		g.owned.append((it as Dictionary).duplicate())
		if g.owned.size() >= 3:
			break
	g.cons = []
	for c in GameData.candies():
		g.cons.append((c as Dictionary).duplicate())
		break
	g.sell_sel = -1
	g.buy_sel = -1
	g._panel_reset()
	g.card_p = 0.0
	g.card_target = 0.0
	_calm()


#  상점. 테이블 물건이 다 앉을 때까지 돌린다(input_probe 와 같은 어법).
func _stage_shop() -> void:
	_stage_play()
	g._open_shop()
	for i in 600:
		if not g._drop_busy():
			break
		g._process(1.0 / 60.0)
	g.buy_sel = -1
	g.sell_sel = -1
	_calm()


func _run() -> void:
	_stage_play()
	var slot0: Vector2 = (g._slot_rect(0) as Rect2).get_center()

	# ══ 데스크톱 무변경 — 회귀 금지선 (트리 안에서 재는 몫) ══
	_finger(false)
	g.mouse_at = slot0
	#  마우스가 움직이면 핀이 그 프레임에 풀린다.
	g.tip_pin = {"k": "rack", "i": 2, "st": g.state}
	_move(slot0 + Vector2(3.0, 0.0))
	_ok("마우스가 조금만 움직여도 핀이 풀린다", (g.tip_pin as Dictionary).is_empty())
	#  길게 눌러도 데스크톱에서는 관문을 못 지난다.
	g.mouse_at = slot0
	_ok("데스크톱에서는 길게 누르기 관문이 안 열린다", not g._hold_ok())
	_hold(slot0, 700)
	_ok("데스크톱 — 길게 눌러도 읽기로 안 바뀐다", not g.press_read)
	_ok("데스크톱 — 층이 여전히 안 갈린다", not g.tip_lite)

	# ══ 손가락 — 톡 = 지목 = 읽기 ═══════════════════
	_stage_play()
	_finger(true)
	var own0: int = (g.owned as Array).size()
	var gold0: int = g.gold
	var cons0: int = (g.cons as Array).size()
	var total0: int = g.total
	_tap(slot0)
	_ok("톡 — 지목이 선다 (sell_sel)", g.sell_sel == 0,
			"sell_sel %d" % g.sell_sel)
	_ok("톡 — 같은 톡이 읽기도 연다", g.tip_title != "", g.tip_title)
	_ok("톡 — 얕은 층이다 (태그 줄을 안 낸다)", _tags() == 0 and g.tip_lite,
			"태그 %d · lite %s" % [_tags(), g.tip_lite])
	_ok("얕은 층은 판이 그만큼 낮다",
			is_equal_approx(g._tip_tags_h(), 0.0), "태그 높이 %.1f" % g._tip_tags_h())
	var lite_h: float = (g._tip_size() as Vector2).y
	_ok("얕은 층에도 등급 색이 산다 (tip_rar 는 태그 앞에 선다)",
			g.tip_rar != "", "등급 '%s'" % g.tip_rar)
	_ok("톡 — 값이 한 톨도 안 바뀐다",
			(g.owned as Array).size() == own0 and g.gold == gold0
			and (g.cons as Array).size() == cons0 and g.total == total0)

	# ══ 길게 누르기 = 태그 줄까지 전부 ═══════════════
	_finger(true)
	g.sell_sel = -1
	_hold(slot0, 700)
	_ok("길게 누르기 — 태그 둘이 선다", _tags() == 2,
			"태그 %d" % _tags())
	_ok("길게 누르기 — 깊은 층이다", not g.tip_lite)
	_ok("깊은 층이 얕은 층보다 판이 높다",
			(g._tip_size() as Vector2).y > lite_h,
			"%.1f > %.1f" % [(g._tip_size() as Vector2).y, lite_h])
	_ok("길게 누르기 — 값이 한 톨도 안 바뀐다",
			(g.owned as Array).size() == own0 and g.gold == gold0
			and (g.cons as Array).size() == cons0 and g.total == total0)
	_ok("길게 누르기 — 손 상태가 무르기로 끝난다",
			g.hand_st == g.H.NONE, "hand_st %d" % g.hand_st)

	# ══ 취소 반경 — HAND.slip 5 양쪽 ══════════════════
	_finger(true)
	g.tip_pin = {}
	_btn(slot0, true)
	g._process(1.0 / 60.0)
	_move(slot0 + Vector2(4.0, 0.0))
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 700:
		g._process(1.0 / 60.0)
		OS.delay_msec(4)
	_ok("4px 은 손떨림 — 읽기가 선다", g.press_read)
	_btn(slot0, false)
	g._process(1.0 / 60.0)

	_finger(true)
	g.tip_pin = {}
	_btn(slot0, true)
	g._process(1.0 / 60.0)
	_move(slot0 + Vector2(9.0, 0.0))
	t0 = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 700:
		g._process(1.0 / 60.0)
		OS.delay_msec(4)
	_ok("9px 은 진짜 끌기 — 읽기가 안 선다", not g.press_read,
			"hold_a %.2f" % g.hold_a)
	_btn(slot0 + Vector2(9.0, 0.0), false)
	g._process(1.0 / 60.0)

	# ══ 사탕 — 길게 누르면 읽히고 안 쓰인다 ═══════════
	_stage_play()
	_finger(true)
	var cons_n: int = (g.cons as Array).size()
	var cell: Vector2 = (g._cons_rect(0) as Rect2).get_center()
	_hold(cell, 700)
	_ok("사탕 — 길게 누르면 읽힌다", g.tip_title != "", g.tip_title)
	_ok("사탕 — 안 쓰인다", (g.cons as Array).size() == cons_n,
			"%d → %d장" % [cons_n, (g.cons as Array).size()])
	_ok("사탕 — 손이 무르기로 끝난다", g.hand_st == g.H.NONE)
	#  짧은 톡은 여태 그대로 쓴다 — 아무것도 안 삼켰다는 증거다.
	_finger(true)
	_tap(cell)
	_ok("사탕 — 톡은 여태 그대로 쓴다 (관문이 안 삼킨다)",
			(g.cons as Array).size() == cons_n - 1,
			"%d → %d장" % [cons_n, (g.cons as Array).size()])

	# ══ 무르기가 지목을 안 지운다 — buy_sel 은 상점에서만 산다 ══
	#  _hand_update 가 상점 밖에서는 매 프레임 buy_sel 을 지우므로(펜딩은
	#  한 화면의 것이다) 이 짝은 반드시 상점에서 재야 한다.
	_stage_shop()
	_finger(true)
	if (g.stock as Array).size() > 0 and (g.cons as Array).size() > 0:
		g.buy_sel = 0
		var scell: Vector2 = (g._cons_rect(0) as Rect2).get_center()
		var sc_n: int = (g.cons as Array).size()
		_hold(scell, 700)
		_ok("상점 — 길게 누르면 읽히고 안 쓰인다",
				(g.cons as Array).size() == sc_n and g.tip_title != "",
				"%d장 · [%s]" % [(g.cons as Array).size(), g.tip_title])
		_ok("무르기가 지목을 안 지운다 (press_buy 되돌림)", g.buy_sel == 0,
				"buy_sel %d" % g.buy_sel)
	else:
		_ok("상점에 잴 것이 없다", false,
				"매물 %d · 사탕 %d" % [(g.stock as Array).size(),
						(g.cons as Array).size()])

	# ══ 읽으려고 연 화면은 첫 톡이 깊은 층 ═════════════
	_stage_play()
	_finger(true)
	g.state = g.S.OVER
	g.over_t = 2.0
	_tap((g._over_coin_rect(0) as Rect2).get_center())
	_ok("런 끝 — 첫 톡이 곧 깊은 층", _tags() == 2 and not g.tip_lite,
			"태그 %d" % _tags())
	g.state = g.S.COLLECT
	g.collect_tab = 0
	g.collect_page = 0
	_ok("컬렉션도 깊은 층이다", g._read_deep())

	# ══ S.RESOLVE 에서는 읽기가 손짓을 안 뺏는다 (①과의 충돌) ══
	_stage_play()
	_finger(true)
	g.state = g.S.RESOLVE
	_ok("정산에서는 길게 누르기 관문이 안 열린다", not g._hold_ok())

	# ══ 문턱이 [300,600] 안이다 ══════════════════════
	var keep_ch: float = g.confirm_hold
	for v in [0.0, 0.05, 0.45, 1.5]:
		g.confirm_hold = float(v)
		_ok("confirm_hold %.2f → 문턱 %dms" % [v, g._hold_ms()],
				g._hold_ms() >= 300 and g._hold_ms() <= 600)
	g.confirm_hold = keep_ch

	# ══════════════════════════════════════════════
	#  ④ 판매 단추 자리
	# ══════════════════════════════════════════════
	_stage_play()
	_finger(false)
	g.sell_sel = 0
	g.sell_t = 0.0
	var sb: Rect2 = g._sell_btn_rect()
	_ok("판매 단추가 선다", sb.size.x > 0.0, "%s" % sb)
	_ok("손가락 크기다 (qa_hudbtn 의 자 56x20)",
			sb.size.x >= 56.0 and sb.size.y >= 20.0, "%s" % sb.size)
	_ok("자금판 밑에 붙어 선다",
			is_equal_approx(sb.position.x, (g._bank_rect() as Rect2).position.x)
			and is_equal_approx(sb.position.y, (g._bank_rect() as Rect2).end.y + 2.0),
			"자금판 %s" % g._bank_rect())
	#  24px 원 검사 — 중심끼리 24px 이상 떨어져야 한다.
	var sc: Vector2 = sb.get_center()
	for i in GameData.max_items():
		var d: float = sc.distance_to((g._slot_rect(i) as Rect2).get_center())
		_ok("동전 칸 %d 과 24px 원이 안 겹친다" % i, d >= 24.0, "%.1fpx" % d)
	for i in (g.cons as Array).size():
		var d2: float = sc.distance_to((g._cons_rect(i) as Rect2).get_center())
		_ok("사탕 칸 %d 과 24px 원이 안 겹친다" % i, d2 >= 24.0, "%.1fpx" % d2)
	for nm in ["cap", "darts", "menu"]:
		var r: Rect2 = g.LAY[nm]
		r.position.y += g._hud_dy()
		_ok("%s 꼬리표와 24px 원이 안 겹친다" % nm,
				sc.distance_to(r.get_center()) >= 24.0,
				"%.1fpx" % sc.distance_to(r.get_center()))
	#  조준 원 — 사각의 가장 가까운 점에서 BC 까지.
	var near := Vector2(clampf(g.BC.x, sb.position.x, sb.end.x),
			clampf(g.BC.y, sb.position.y, sb.end.y))
	var aimr: float = g.R * GameData.tune("aim_click_r")
	_ok("판 조준 원과 아예 안 만난다",
			near.distance_to(g.BC) > aimr,
			"가장 가까운 점까지 %.1fpx · 조준 원 %.2f" % [near.distance_to(g.BC), aimr])
	#  벽의 자루 — qa_hudbtn 과 **같은 잣대**를 쓴다.
	var grip_top: float = float(g.GRIP.cy) - 118.0 - float(g.GRIP.hit)
	_ok("벽의 자루 잡기 판정과 안 겹친다", sb.end.y < grip_top,
			"단추 밑 %.0f · 자루 판정 위 %.0f" % [sb.end.y, grip_top])
	#  버튼 · 창구 · 리롤과도 안 겹친다.
	_ok("리롤 단추와 안 겹친다", not sb.intersects(g._reroll_rect()))
	_ok("다음 판 단추와 안 겹친다", not sb.intersects(g._next_rect()))
	#  뜨는 모든 화면에서 사각이 같다.
	var first := Rect2()
	var same := true
	for st in ["PICK", "AIM_V", "AIM_H", "LEG"]:
		g.state = int(g.S[st])
		var r2: Rect2 = g._sell_btn_rect()
		if first.size.x <= 0.0:
			first = r2
		elif r2 != first:
			same = false
	_ok("뜨는 모든 화면에서 자리가 같다", same, "%s" % first)
	g.state = g.S.SHOP
	_ok("상점에서는 안 뜬다 (창구가 그 일을 한다)",
			(g._sell_btn_rect() as Rect2).size.x <= 0.0)
	g.state = g.S.PICK

	#  고른 동전의 이름 줄이 되살아났다 — 억누르던 갈래를 걷은 증거다.
	var src := FileAccess.get_file_as_string("res://scripts/game.gd")
	_ok("칸 밑 이름을 억누르던 갈래가 없어졌다",
			not src.contains("if i == sell_sel and _sell_btn_rect().size.x > 0.0:"))

	#  확정 문법은 한 줄도 안 바뀐다 — 눌렀다 같은 사각에서 떼야 판다.
	_stage_play()
	_finger(false)
	g.sell_sel = 0
	g.sell_t = 0.0
	var n0: int = (g.owned as Array).size()
	var gd0: int = g.gold
	sb = g._sell_btn_rect()
	_btn(sb.get_center(), true)
	g._process(1.0 / 60.0)
	_ok("누름은 지목만 한다 — 아직 안 팔린다",
			(g.owned as Array).size() == n0 and g.gold == gd0,
			"hand_src %d" % g.hand_src)
	_btn(sb.get_center(), false)
	g._process(1.0 / 60.0)
	_ok("같은 사각에서 떼면 판다",
			(g.owned as Array).size() == n0 - 1 and g.gold > gd0,
			"동전 %d → %d · 골드 %d → %d" % [n0, (g.owned as Array).size(), gd0, g.gold])

	_stage_play()
	_finger(false)
	g.sell_sel = 0
	g.sell_t = 0.0
	n0 = (g.owned as Array).size()
	sb = g._sell_btn_rect()
	_btn(sb.get_center(), true)
	g._process(1.0 / 60.0)
	_btn(sb.get_center() + Vector2(0.0, 60.0), false)
	g._process(1.0 / 60.0)
	_ok("사각 **밖**에서 떼면 안 판다", (g.owned as Array).size() == n0,
			"동전 %d장" % (g.owned as Array).size())

	_stage_play()
	_finger(false)
	g.sell_sel = 0
	g.sell_t = 0.0
	n0 = (g.owned as Array).size()
	sb = g._sell_btn_rect()
	_btn(sb.get_center(), true)
	g._process(1.0 / 60.0)
	for k in range(1, 9):
		_move(sb.get_center() + Vector2(0.0, float(k) * 8.0))
		g._process(1.0 / 60.0)
	_btn(sb.get_center() + Vector2(0.0, 64.0), false)
	g._process(1.0 / 60.0)
	_ok("끌면 취소다", (g.owned as Array).size() == n0,
			"동전 %d장" % (g.owned as Array).size())

	_desk()


# ══════════════════════════════════════════════════════════
#  데스크톱 회귀 금지선 — **얹힘 길**은 트리 밖에서 잰다
#
#  _cursor() 는 뷰포트가 있으면 엔진에 진짜 커서를 묻고, 없으면 마지막으로
#  받은 자리(mouse_at)를 쓴다. 헤드리스에서는 진짜 커서를 못 옮기므로,
#  얹힘을 재려면 노드를 트리에서 잠깐 내려 그 갈래를 타야 한다.
#  손짓(누름·뗌)은 반대로 트리 **안**에서만 배달되므로 위에서 다 쟀다.
# ══════════════════════════════════════════════════════════
func _desk() -> void:
	_stage_play()
	var slot0: Vector2 = (g._slot_rect(0) as Rect2).get_center()
	root.remove_child(g)
	_finger(false)
	g.mouse_at = slot0
	g._tip_update(1.0 / 60.0)
	var desk_tags := _tags()
	var desk_title: String = g.tip_title
	_ok("얹힘만으로 태그가 둘 선다 (오늘 그대로)", desk_tags == 2,
			"[%s] 태그 %d" % [desk_title, desk_tags])
	_ok("마우스에서는 층이 안 갈린다", not g.tip_lite)
	#  층을 억지로 켜도 매 프레임 되돌린다 — 이것이 첫째 겹이다.
	g.tip_lite = true
	g._tip_update(1.0 / 60.0)
	_ok("층을 억지로 켜도 매 프레임 되돌린다",
			not g.tip_lite and _tags() == 2, "태그 %d" % _tags())
	#  핀을 억지로 꽂아도 얹힘이 이긴다 — 둘째 겹이다.
	g.tip_pin = {"k": "rack", "i": 2, "st": g.state}
	g.tip_pin_at = (g._slot_rect(2) as Rect2).get_center()
	g._tip_update(1.0 / 60.0)
	_ok("얹힘이 무조건 이긴다 (핀이 있어도 같은 결과)",
			g.tip_title == desk_title and _tags() == desk_tags,
			"[%s] 태그 %d" % [g.tip_title, _tags()])
	#  얹힘이 빈손일 때만 핀이 선다.
	g.mouse_at = Vector2(320.0, 300.0)
	g.tip_pin = {"k": "rack", "i": 2, "st": g.state}
	g.tip_pin_at = (g._slot_rect(2) as Rect2).get_center()
	g._tip_update(1.0 / 60.0)
	_ok("얹힘이 빈손이면 핀이 선다",
			g.tip_title == String((g.owned[2] as Dictionary).get("n", "")),
			"[%s]" % g.tip_title)
	#  물건이 없어지면 핀이 스스로 낫는다. 동전 **칸**은 물건이 빠져도 칸
	#  자체가 남아 같은 열쇠를 내므로(자리의 툴팁이다) 사탕으로 잰다 —
	#  사탕 칸은 든 장수만큼만 서서, 쓰면 그 자리가 통째로 없어진다.
	g.mouse_at = Vector2(320.0, 300.0)
	g.tip_pin = {"k": "held", "i": 0, "st": g.state}
	g.tip_pin_at = (g._cons_rect(0) as Rect2).get_center()
	g._tip_update(1.0 / 60.0)
	_ok("사탕 핀이 선다", g.tip_title != "", "[%s]" % g.tip_title)
	g.cons.clear()
	g._tip_update(1.0 / 60.0)
	_ok("물건이 없어지면 핀이 스스로 풀린다",
			(g.tip_pin as Dictionary).is_empty(), "%s" % g.tip_pin)
	root.add_child(g)
