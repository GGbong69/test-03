extends SceneTree
# ══════════════════════════════════════════════════════════
#  겨눔 — 「로비로 나가기」가 프로필 지우기와 **같은 문법**인가
#
#  실행:  godot --headless --path . --script scripts/tools/qa_arm.gd
#  종료 코드 = 실패 개수
#
#  왜 있는가
#    설정의 「로비로 나가기」는 한 번 누름으로 런을 버린다. _set_rows 머리말이
#    「소리를 만지다가 손이 미끄러져 런을 버리는 자리」라고 이미 적어 둔
#    자리다. 확인창이 아니라 **겨눔 한 단**을 둔다 — 첫 누름이 겨누고
#    둘째가 나간다(톡의 규약 ③).
#
#  무엇이 규칙인가
#    · 첫 누름 — 상태가 S.SETTINGS 그대로이고 lobby_arm 이 선다. 소리는
#      prof_arm 이 쓰는 menu_pick2 다.
#    · 둘째 누름 — 같은 줄이어야 나간다.
#    · 풀림 넷 — 딴 줄 · 게이지 홈 · 설정을 닫음 · 화면이 바뀜 · 2.5초 만료.
#      **풀릴 때는 소리가 안 난다** — 풀림은 사건이 아니다.
#    · **글자는 한 자도 안 는다** — 겨눈 동안에도 _set_rows 의 줄 수와
#      _set_info("lobby") 의 이름이 한 글자도 안 바뀐다.
#
#  자리는 노드 좌표다
#    _click 을 직접 부르므로 view_pad 를 안 지난다 — _set_rect 가 내는 값을
#    그대로 쓴다. 띠가 다 밀려 들어온 뒤라야 줄이 제자리이므로 set_t 를
#    1 로 못 박고 잰다.
# ══════════════════════════════════════════════════════════
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var ok := 0
var bad := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_arm_g.cfg"
	Save.path = "user://_qa_arm.cfg"
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


#  판 중에 연 설정. 여섯 줄이라 「로비로 나가기」가 선다.
func _open() -> void:
	_calm()
	g.lobby_arm = false
	g.state = g.S.PICK
	g._pause_open()
	g.set_t = 1.0            # 다 밀려 들어온 자리에서 잰다
	g.set_drag = -1


func _row(key: String) -> int:
	var rows: Array = g._set_rows()
	return rows.find(key)


func _at(key: String) -> Vector2:
	return (g._set_rect(_row(key)) as Rect2).get_center()


func _tap(key: String) -> void:
	g._click(_at(key))


func _run() -> void:
	g._new_run()
	_calm()

	# ── 겨눔 한 단 ──────────────────────────────────
	_open()
	var rows0: int = (g._set_rows() as Array).size()
	var name0 := String((g._set_info("lobby") as Dictionary).get("n", ""))
	var desc0 := String((g._set_info("lobby") as Dictionary).get("d", ""))
	_ok("판 중 설정에 「로비로 나가기」가 있다", _row("lobby") >= 0,
			"%d번째 줄 · %s" % [_row("lobby"), g._set_rect(_row("lobby"))])
	_tap("lobby")
	_ok("첫 누름 — 화면이 안 바뀐다", g.state == g.S.SETTINGS,
			"state %d" % g.state)
	_ok("첫 누름 — 겨눔이 선다", g.lobby_arm)
	_ok("겨눈 동안 줄 수가 안 바뀐다",
			(g._set_rows() as Array).size() == rows0, "%d줄" % rows0)
	_ok("겨눈 동안 글자가 한 자도 안 바뀐다",
			String((g._set_info("lobby") as Dictionary).get("n", "")) == name0
			and String((g._set_info("lobby") as Dictionary).get("d", "")) == desc0,
			"%s / %s" % [name0, desc0])
	_tap("lobby")
	_ok("둘째 누름 — 제목으로 나간다", g.state == g.S.TITLE,
			"state %d" % g.state)
	_ok("나간 뒤 겨눔이 안 남는다", not g.lobby_arm)

	# ── 풀림 ① 딴 줄 ────────────────────────────────
	_open()
	_tap("lobby")
	_tap("vol")
	_ok("풀림 — 딴 줄을 누르면 풀린다", not g.lobby_arm)
	_ok("풀림 — 딴 줄을 누른 뒤에는 한 번 더 겨눠야 한다", g.state == g.S.SETTINGS)
	_tap("lobby")
	_ok("풀린 뒤 첫 누름은 다시 겨눔이다",
			g.lobby_arm and g.state == g.S.SETTINGS)

	# ── 풀림 ② 게이지 홈 ─────────────────────────────
	_open()
	_tap("vol")                    # 홈이 효과음을 쥐게 한다
	_tap("lobby")
	_ok("게이지 앞 — 겨눔이 섰다", g.lobby_arm)
	g.set_sel = _row("vol")
	g.set_hot = -1
	g._click((g._vol_track() as Rect2).get_center())
	_ok("풀림 — 소리를 끄는 손이 겨눔을 안 들고 다닌다", not g.lobby_arm,
			"set_drag %d" % g.set_drag)
	g._set_slide_end()

	# ── 풀림 ③ 설정을 닫는다 ──────────────────────────
	_open()
	_tap("lobby")
	g._settings_back()
	_ok("풀림 — 설정을 닫으면 풀린다", not g.lobby_arm)

	# ── 풀림 ④ 화면이 바뀐다(다시 연다) ────────────────────
	_open()
	_tap("lobby")
	g.state = g.S.PICK
	g._pause_open()
	_ok("풀림 — 설정을 다시 열면 겨눔이 안 남는다", not g.lobby_arm)

	# ── 풀림 ⑤ 2.5초 만료 · 소리 없이 ────────────────────
	_open()
	_tap("lobby")
	_ok("만료 전 — 아직 서 있다", g.lobby_arm)
	for i in 100:                          # 100프레임 = 1.67초
		g._set_tick(1.0 / 60.0)
	_ok("1.67초 — 아직 서 있다", g.lobby_arm,
			"%.2f초" % g.lobby_arm_t)
	for i in 60:
		g._set_tick(1.0 / 60.0)
	_ok("2.5초 넘으면 풀린다", not g.lobby_arm,
			"%.2f초" % g.lobby_arm_t)
	#  풀린 뒤에 「로비」를 누르면 **또 겨눔**이어야 한다 — 만료가 확정을
	#  물려 주면 그것이 가장 나쁜 사고다.
	_tap("lobby")
	_ok("만료 뒤 첫 누름은 겨눔이다", g.lobby_arm and g.state == g.S.SETTINGS)

	# ── 화면을 떠나면 시계가 스스로 푼다 ───────────────────
	_open()
	_tap("lobby")
	g.state = g.S.PICK
	g._set_tick(1.0 / 60.0)
	_ok("설정 밖으로 나가면 시계가 스스로 푼다", not g.lobby_arm)

	# ── prof_arm 과 같은 문법인가 ───────────────────────
	#  같은 손짓을 프로필 지우기에 보내 두 거동을 나란히 찍는다.
	Save.use_slot(1)
	Save.set_pick("league", "std")
	Save.flush()
	g.state = g.S.PROFILE
	g.prof_arm = -1
	g.prof_sel = 1
	var dsel: int = clampi(g.prof_sel, 1, Save.SLOTS)
	_ok("프로필 1번이 쓰인 자리다(겨눔 비교의 전제)", Save.slot_used(dsel),
			"slot_used %s" % Save.slot_used(dsel))
	g._click((g._prof_del_rect() as Rect2).get_center())
	_ok("프로필 — 첫 누름은 겨눔이다(같은 문법)", g.prof_arm == dsel,
			"prof_arm %d · state %d" % [g.prof_arm, g.state])
	g._click((g._prof_del_rect() as Rect2).get_center())
	_ok("프로필 — 둘째 누름이 확정이다",
			g.prof_arm == -1 and not Save.slot_used(dsel))

	# ── _row_band 의 새 인자가 다른 호출자를 안 건드린다 ──────
	#  기본값 1.0 이라 **부르는 쪽이 한 줄도 안 바뀐다.** 그림을 가로채는
	#  대역 캔버스는 못 만든다(draw_rect 는 네이티브라 덮어쓸 수 없다) —
	#  그래서 qa_ui 의 어법 그대로 **소스를 읽어** 센다.
	var src := FileAccess.get_file_as_string("res://scripts/game.gd")
	var thick_calls := 0
	var band_calls := 0
	for ln in src.split("\n"):
		var t := String(ln).strip_edges()
		if t.begins_with("#"):
			continue
		if not t.contains("_row_band("):
			continue
		if t.begins_with("func _row_band("):
			continue
		band_calls += 1
		#  인자 여덟 = thick 을 넘긴 자리. 「3.0 if armed else 1.0」이 그 한 줄이다.
		if t.contains("if armed else"):
			thick_calls += 1
	_ok("띠를 부르는 자리가 남아 있다", band_calls >= 5, "%d곳" % band_calls)
	_ok("굵기를 넘기는 자리는 겨눔 한 곳뿐",
			thick_calls == 1, "%d곳 / 전체 %d곳" % [thick_calls, band_calls])
	#  설정 글줄을 그리는 함수 안의 draw_string 수. 글줄 이름 하나와 게이지
	#  수 하나, 딱 둘이다 — 겨눔이 **글자를 한 자도 안 더했다**는 기계적 증거다.
	var in_fn := false
	var strings := 0
	for ln in src.split("\n"):
		var t := String(ln)
		if t.begins_with("func _draw_settings("):
			in_fn = true
			continue
		if in_fn and t.begins_with("func "):
			break
		if in_fn and not t.strip_edges().begins_with("#") \
				and t.contains("draw_string("):
			strings += 1
	_ok("설정 글줄에 글자가 딱 둘 (이름 · 게이지 수)", strings == 2,
			"draw_string %d곳" % strings)
