extends SceneTree
# 방향키 · Enter 로 플레이(2026-10-11 · game.gd KB) — 못 박는 것:
#   ① 첫 방향키는 고르기만 한다 — 그 화면이 처음 고를 것(제목은 「시작」) · 커서가 그 한가운데
#   ② 방향키가 그 방향의 가장 가까운 것으로 옮긴다 · 그 방향에 없으면 그대로
#   ③ Enter 는 그 자리를 누른 것과 같다(제목 「컬렉션」 → 컬렉션)
#   ④ 설정 — 위아래는 줄 · 게이지 줄의 ← → 는 값 · 켬끔 줄은 끔 · 켬 · 해상도는 한 칸
#   ⑤ 판 — Enter 로 다트를 고르고 조준을 잠가 던진다(표준 조준 · 판 한가운데를 누른다)
#   ⑥ 커서 자리 조준(찍기) — 방향키가 고르지 않고 커서를 민다
#   ⑦ 상점 — 처음 고를 것은 「다음 판」 · 물건을 고르고 Enter 면 겨눈다(톡과 같다)
#   ⑧ 진짜 마우스가 움직이면 키보드 고르기를 내려놓는다 · Enter 를 쥐면 정산이 빨리 감긴다
#   godot --headless --path . --script scripts/tools/qa_kb.gd
const Save = preload("res://scripts/save.gd")
var g = null
var ok := 0
var bad := 0
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_qa_kb_g.cfg"
	Save.path = "user://_qa_kb.cfg"
	Save.prof_fmt = "user://_qa_kb_%d.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if g != null:
		g.set_process(false)
	if busy:
		return false
	busy = true
	_run()
	print("통과 %d · 실패 %d" % [ok, bad])
	quit(1 if bad > 0 else 0)
	return false


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-44s %s" % ["통과" if cond else "실패", nm, note])


func _key(kc: int, pressed := true, echo := false) -> void:
	var e := InputEventKey.new()
	e.keycode = kc
	e.pressed = pressed
	e.echo = echo
	g._unhandled_input(e)


func _enter() -> void:
	_key(KEY_ENTER, true)
	_key(KEY_ENTER, false)


func _tgt(id: String) -> Dictionary:
	for t in g._kb_targets():
		if String(t.id) == id:
			return t
	return {}


func _run() -> void:
	# ① — 제목
	_ok("제목에서 시작한다", g.state == g.S.TITLE, "state %d" % g.state)
	_key(KEY_DOWN)
	_ok("① 첫 방향키 — 키보드 고르기가 선다", g.kb_on)
	_ok("① 처음 고를 것은 「시작」(0 번 줄)", g.kb_id == "ttl:0", g.kb_id)
	_ok("① 커서가 그 한가운데", (g.mouse_at as Vector2).is_equal_approx((g._menu_rect(0) as Rect2).get_center()))

	# ② — 「컬렉션」 줄까지 내려간다
	var rows: Array = g._title_rows()
	var ci := -1
	for i in rows.size():
		if String(rows[i].n) == "컬렉션":
			ci = i
	var guard := 0
	while g.kb_id != "ttl:%d" % ci and guard < 8:
		_key(KEY_DOWN)
		guard += 1
	_ok("② ↓ 로 「컬렉션」 줄에 닿는다", g.kb_id == "ttl:%d" % ci, g.kb_id)
	var before: String = g.kb_id
	_key(KEY_LEFT)
	_ok("② 옆으로 눌러도 고른 것이 남는다", g.kb_id != "", g.kb_id)
	g.kb_id = before
	g._kb_aim(_tgt(before))

	# ③
	_enter()
	_ok("③ Enter — 컬렉션이 열린다", g.state == g.S.COLLECT, "state %d" % g.state)
	if g._push_live():
		g._push_skip()
	g._kb_sync()
	_ok("③ 화면이 바뀌면 그 화면의 처음 것(첫 칸)", g.kb_id == "cell:0", g.kb_id)
	_key(KEY_RIGHT)
	_ok("③ → 로 옆 칸", g.kb_id == "cell:1", g.kb_id)
	_key(KEY_ESCAPE)
	_ok("③ ESC 는 옛 그대로(제목으로)", g.state == g.S.TITLE, "state %d" % g.state)

	# ④ — 설정(제목에서 연)
	g.pause_from = -1
	g._set_go("screen")
	g.set_t = 1.0
	g.set_pg_t = 1.0
	g.state = g.S.SETTINGS
	g._kb_sync()
	var srows: Array = g._set_rows()
	_ok("④ 설정 — 처음 고를 것은 첫 줄", g.kb_id == "set:" + String(srows[0]), g.kb_id)
	var gi := srows.find("crt")
	guard = 0
	while g.kb_id != "set:crt" and guard < 12:
		_key(KEY_DOWN)
		guard += 1
	_ok("④ ↓ 로 「CRT 필터」 줄", g.kb_id == "set:crt", g.kb_id)
	var v0: float = g.crt
	g.wheel_ms = 0
	_key(KEY_RIGHT)
	_ok("④ → 가 게이지를 올린다(0.05)", is_equal_approx(g.crt, minf(v0 + 0.05, 1.0)), "%.2f → %.2f" % [v0, g.crt])
	_ok("④ 좌우는 줄을 안 옮긴다", g.kb_id == "set:crt", g.kb_id)
	g.wheel_ms = 0
	_key(KEY_LEFT)
	_ok("④ ← 가 내린다", is_equal_approx(g.crt, v0), "%.2f" % g.crt)
	g.kb_id = "set:wipe"
	g.wipe_snow = true
	_key(KEY_LEFT)
	_ok("④ 켬끔 줄 ← 는 끔", g.wipe_snow == false)
	_key(KEY_RIGHT)
	_ok("④ 켬끔 줄 → 는 켬", g.wipe_snow == true)
	g.kb_id = "set:res"
	g.res_w = 1280
	_key(KEY_RIGHT)
	_ok("④ 해상도 → 는 한 칸", g.res_w == 1600, "%d" % g.res_w)
	_key(KEY_LEFT)
	_ok("④ 해상도 ← 는 한 칸 뒤로", g.res_w == 1280, "%d" % g.res_w)
	_ok("④ 게이지 줄은 이름 쪽을 누른다(값이 안 튄다)",
			(_tgt("set:crt").get("p", Vector2.ZERO) as Vector2).x < (g._vol_track(gi) as Rect2).position.x)
	g.state = g.S.TITLE

	# ⑤ — 판
	g._new_run()
	_ok("⑤ 런이 서면 판 고르기", g.state == g.S.LEG, "state %d" % g.state)
	g._kb_sync()
	_ok("⑤ 판 고르기에서 처음 고를 것은 「던진다」", g.kb_id == "go", g.kb_id)
	_enter()
	_ok("⑤ Enter 로 판에 선다", g.state == g.S.PICK or g.state == g.S.AIM_V, "state %d" % g.state)
	if g.state == g.S.PICK:
		g._kb_sync()
		_ok("⑤ 다트 고르기에서 처음 고를 것은 첫 다트", g.kb_id == "mag:0", g.kb_id)
		_enter()
	_ok("⑤ Enter 로 다트를 든다", g.state == g.S.AIM_V, "state %d" % g.state)
	g._kb_sync()
	_ok("⑤ 조준이면 판을 고른다", g.kb_id == "board", g.kb_id)
	var guard2 := 0
	while (g.state == g.S.AIM_V or g.state == g.S.AIM_H) and guard2 < 6:
		_enter()
		guard2 += 1
	_ok("⑤ Enter 로 조준을 잠가 던진다", g.state != g.S.AIM_V and g.state != g.S.AIM_H and g.state != g.S.PICK,
			"state %d · 잠금 %d 번" % [g.state, guard2])

	# ⑥ — 찍기 조준
	g.aim_mode = "place"
	g.state = g.S.AIM_V
	_ok("⑥ 찍기 조준이면 커서를 민다", g._kb_free())
	var m0: Vector2 = g.mouse_at
	_key(KEY_RIGHT)
	_ok("⑥ 방향키가 고르지 않는다(커서는 틱이 민다)", g.kb_id == "" or (g.mouse_at as Vector2).is_equal_approx(m0))
	g.aim_mode = "std"

	# ⑦ — 상점
	g._open_shop()
	_ok("⑦ 상점이 선다", g.state == g.S.SHOP, "state %d" % g.state)
	g._drop_settle()                 # 떨어지는 물건을 앉힌다 — 이 검사는 시간이 안 흐른다
	g._kb_sync()
	_ok("⑦ 처음 고를 것은 「다음 판」", g.kb_id == "next", g.kb_id)
	var item := ""
	for t in g._kb_targets():
		if String(t.id).begins_with("item:"):
			item = String(t.id)
			break
	_ok("⑦ 물건이 고를 것에 든다", item != "", item)
	if item != "":
		g.kb_id = item
		g._kb_aim(_tgt(item))
		g.buy_sel = -1
		_enter()
		_ok("⑦ 물건에서 Enter — 사기 겨눔", g.buy_sel == int(item.split(":")[1]), "buy_sel %d" % g.buy_sel)

	# ⑧
	var mm := InputEventMouseMotion.new()
	mm.position = Vector2(100, 100)
	mm.relative = Vector2(4, 0)
	g._unhandled_input(mm)
	_ok("⑧ 마우스가 움직이면 내려놓는다", not g.kb_on)
	g.state = g.S.RESOLVE
	g.kb_on = true
	g.kb_down = true
	_ok("⑧ Enter 를 쥐면 정산이 빨리 감긴다", g._fast_on())
	g.kb_down = false
	g.kb_on = false
	g.state = g.S.SHOP
