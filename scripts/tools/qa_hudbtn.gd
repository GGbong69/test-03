extends SceneTree
# 런 정보 · 설정 단추 — 키 없이(모바일) TAB · ESC 가 하던 일을 할 수 있는가.
#   godot --headless --path . --script scripts/tools/qa_hudbtn.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var ok := 0
var bad := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_hb_g.cfg"
	Save.path = "user://_qa_hb.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	_run()
	print("통과 %d · 실패 %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-44s %s" % ["통과" if cond else "실패", nm, note])


func _calm() -> void:
	g.swap_live = false
	g.photo = ""
	g.photo_rack = ""
	g._tutor_close()
	g.tutor_out = 0.0
	g.pause_from = -1


func _run() -> void:
	g._new_run()
	_calm()

	# ── 어디에 서는가 ───────────────────────────────────
	var on_states := {"조준": g.S.AIM_V, "고르기": g.S.PICK, "상점": g.S.SHOP,
			"스테이지": g.S.STAGE, "판 고르기": g.S.LEG, "정산": g.S.CLEAR}
	for nm in on_states:
		g.state = on_states[nm]
		_ok("선다 — %s" % nm, g._hud_btns_on())
	var off_states := {"제목": g.S.TITLE, "설정": g.S.SETTINGS, "컬렉션": g.S.COLLECT,
			"새 런": g.S.NEWRUN, "런 정보": g.S.RUNINFO, "런 끝": g.S.OVER}
	for nm in off_states:
		g.state = off_states[nm]
		_ok("안 선다 — %s" % nm, not g._hud_btns_on())
	g.state = g.S.SHOP
	g.swap_live = true
	_ok("갈아 끼우는 동안은 안 선다", not g._hud_btns_on())
	_calm()

	# ── 겹치지 않는다 ──────────────────────────────────
	for nm in on_states:
		g.state = on_states[nm]
		var r0: Rect2 = g._hud_btn_rect(0)
		var r1: Rect2 = g._hud_btn_rect(1)
		_ok("둘이 안 겹친다 — %s" % nm, not r0.intersects(r1), "%s · %s" % [r0, r1])
		_ok("화면 안이다 — %s" % nm,
				r0.position.x >= 0.0 and r1.end.x <= 640.0 and r0.position.y >= 0.0)
		var pair0: Rect2 = r0.merge(r1)
		if g.state != g.S.CLEAR:
			_ok("자금판과 안 겹친다 — %s" % nm, not g._bank_rect().intersects(pair0))
		#  첫 줄의 이웃 — 동전 꼬리표 · 다트 꼬리표와 안 겹치고, 같은 높이에 선다
		var dy: float = g._hud_dy()
		var cap: Rect2 = g.LAY.cap
		cap.position.y += dy
		var dts: Rect2 = g.LAY.darts
		dts.position.y += dy
		_ok("동전 · 다트 꼬리표와 안 겹친다 — %s" % nm,
				not cap.intersects(pair0) and not dts.intersects(pair0),
				"단추 %s · 다트 %s" % [pair0, dts])
		_ok("첫 줄과 위아래가 맞는다 — %s" % nm,
				is_equal_approx(pair0.position.y, cap.position.y)
				and is_equal_approx(pair0.end.y, cap.end.y),
				"단추 y%.0f~%.0f · 동전 y%.0f~%.0f"
				% [pair0.position.y, pair0.end.y, cap.position.y, cap.end.y])
		_ok("오른쪽 여백이 자금판 왼쪽 여백과 같다 — %s" % nm,
				is_equal_approx(640.0 - pair0.end.x, float(g.LAY.bank.position.x)),
				"%.0f · %.0f" % [640.0 - pair0.end.x, g.LAY.bank.position.x])
		_ok("손가락 크기다 — %s" % nm, r0.size.x >= 56.0 and r0.size.y >= 20.0,
				"%s" % r0.size)
	#  조준 중 벽의 자루 — 자루가 가장 많아 간격이 가장 좁을 때를 잰다
	g.state = g.S.AIM_V
	var pair: Rect2 = g._hud_btn_rect(0).merge(g._hud_btn_rect(1))
	var top_hit: float = float(g.GRIP.cy) - 118.0 - float(g.GRIP.hit)
	_ok("벽의 자루 잡기 판정과 안 겹친다", pair.end.y < top_hit,
			"단추 밑 %.0f · 자루 판정 위 %.0f" % [pair.end.y, top_hit])
	#  정산에서도 조준 때와 같은 높이 — 화면이 바뀌어도 단추가 안 뛴다.
	#  (상점·스테이지는 첫 줄이 통째로 16 오르고 단추도 그 줄의 일부다)
	var y_aim: float = g._hud_btn_rect(0).position.y
	g.state = g.S.CLEAR
	_ok("정산에서도 같은 높이다", is_equal_approx(g._hud_btn_rect(0).position.y, y_aim),
			"%.0f · %.0f" % [g._hud_btn_rect(0).position.y, y_aim])

	# ── 누르면 키가 하던 일을 한다 ──────────────────────
	g.state = g.S.SHOP
	var c0: Vector2 = g._hud_btn_rect(0).get_center()
	var c1: Vector2 = g._hud_btn_rect(1).get_center()
	var ok_ri: bool = g._runinfo_ok()
	g._click(c0)
	_ok("「정보」 → 런 정보가 열린다(상점)", ok_ri and g.state == g.S.RUNINFO
			and g.run_from == g.S.SHOP, "state %d" % g.state)
	g._runinfo_toggle()
	_ok("다시 닫으면 상점으로", g.state == g.S.SHOP)
	g._click(c1)
	_ok("「설정」 → 일시정지(상점)", g.state == g.S.SETTINGS and g.pause_from == g.S.SHOP,
			"state %d · from %d" % [g.state, g.pause_from])
	g._settings_back()
	_ok("설정을 닫으면 상점으로", g.state == g.S.SHOP)

	#  조준 중 — 단추를 누른 손이 조준을 잠그면 안 된다
	_calm()
	g.state = g.S.AIM_V
	var aim_before = g.aim
	g._click(g._hud_btn_rect(1).get_center())
	_ok("「설정」 → 일시정지(조준)", g.state == g.S.SETTINGS and g.pause_from == g.S.AIM_V)
	g._settings_back()
	_ok("조준으로 돌아온다 · 조준이 안 잠겼다", g.state == g.S.AIM_V and g.aim == aim_before,
			"state %d" % g.state)

	#  연출 중(RESOLVE)에는 런 정보를 못 연다 — 누르면 거절 소리만
	_calm()
	g.state = g.S.RESOLVE
	var can: bool = g._runinfo_ok()
	g._click(g._hud_btn_rect(0).get_center())
	_ok("연출 중 「정보」 는 안 열린다", not can and g.state == g.S.RESOLVE,
			"runinfo_ok %s · state %d" % [can, g.state])

	#  키와 단추가 같은 길이다 — TAB 을 흉내 내 같은 결과인지
	_calm()
	g.state = g.S.LEG
	var ev := InputEventKey.new()
	ev.keycode = KEY_TAB
	ev.pressed = true
	g._unhandled_input(ev)
	var via_key: int = g.state
	g._runinfo_toggle()
	g._click(g._hud_btn_rect(0).get_center())
	_ok("TAB 과 「정보」 가 같은 곳으로 간다", via_key == g.S.RUNINFO and g.state == g.S.RUNINFO)
	g._runinfo_toggle()

	#  단추 자리 밖은 원래 판별로 간다
	_calm()
	g.state = g.S.TITLE
	_ok("제목에서는 그 자리를 눌러도 단추가 아니다",
			not g._hud_btn_click(c0))

	# ── 설명 띠의 건너뛰기 ─────────────────────────────
	_calm()
	g.state = g.S.SHOP
	var tid := ""
	for r in GameData.tutor():
		var k := String(r.get("id", ""))
		if GameData.tutor_steps(k).size() > 1:
			tid = k
			break
	if tid == "":
		_ok("여러 걸음짜리 설명이 있다", false)
		return
	g.tutor_id = tid
	g.tutor_i = 0
	g.tutor_t = 5.0
	var sk: Rect2 = g._tutor_skip_rect()
	var box: Rect2 = g._tutor_box()
	_ok("건너뛰기 단추가 말상자 안이다", box.encloses(sk), "%s ⊂ %s" % [sk, box])
	_ok("건너뛰기가 손가락 크기다", sk.size.x >= 56.0 and sk.size.y >= 14.0, "%s" % sk.size)
	g._tutor_click(box.position + Vector2(20.0, 10.0))
	_ok("말상자 다른 곳 → 다음 걸음", g.tutor_id == tid and g.tutor_i == 1, "i %d" % g.tutor_i)
	g.tutor_t = 5.0
	g._tutor_click(g._tutor_skip_rect().get_center())
	_ok("건너뛰기 → 설명이 닫힌다", g.tutor_id == "", "id '%s'" % g.tutor_id)
