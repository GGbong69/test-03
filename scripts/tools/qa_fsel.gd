extends SceneTree
# 화면 고르기(2026-10-10 · game.gd FSEL) — 못 박는 것:
#   ① 처음이면 고를 차례다 · 열면 왼쪽(켬)이 기본값 필터로 선다 · 음악이 없다
#   ② 「필터 켬」에 얹으면 금이 오른끝(온 화면 켬) · 「필터 끔」에 얹으면 왼끝(온 화면 끔)
#   ③ 「필터 끔」을 누르면 게이지 넷이 0 으로 저장되고 · 다시 안 묻고 · 처음이면 인트로로
#   ④ 다시 열어 「필터 켬」을 누르면 기본값으로 저장되고 제목으로 돌아간다
#   ⑤ 키 — → 로 고르고 Enter 로 정한다 · ESC 는 안 받는다(화면이 그대로다)
#   ⑥ 고르기를 뜨면 셰이더 가름이 걷힌다(split 2)
#   godot --headless --path . --script scripts/tools/qa_fsel.gd
const Save = preload("res://scripts/save.gd")
var g = null
var ok := 0
var bad := 0
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_qa_fsel_g.cfg"
	Save.path = "user://_qa_fsel.cfg"
	Save.prof_fmt = "user://_qa_fsel_%d.cfg"
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


func _plate(i: int) -> Vector2:
	return (g._fsel_rect(i) as Rect2).get_center()


func _split() -> float:
	var r = g.dot_rect
	if r == null or not is_instance_valid(r):
		return -9.0
	var m := (r as ColorRect).material as ShaderMaterial
	return float(m.get_shader_parameter("split")) if m != null else -9.0


func _tick(n := 30) -> void:
	for i in n:
		g._fsel_tick(1.0 / 60.0)


func _run() -> void:
	# ① — 검사 전역 파일은 Save.wipe 가 안 비운다(지난 실행이 남긴 "fsel")
	Save.set_set("fsel", false)
	_ok("① 처음이면 고를 차례다", g._fsel_due())
	g._fsel_begin(true)
	_ok("① 고르기 화면이 선다", g.state == g.S.FSEL)
	_ok("① 왼쪽(켬)은 기본값 필터다", is_equal_approx(g.crt, g.CRT_DEF) and is_equal_approx(g.warp, g.WARP_DEF)
			and is_equal_approx(g.vhs, g.VHS_DEF) and is_equal_approx(g.dot, g.DOT_DEF))
	_ok("① 음악이 없다(인트로 앞이다)", g._mus_want() == "")
	_ok("① 두 패가 화면 안 · 겹치지 않는다", not (g._fsel_rect(0) as Rect2).intersects(g._fsel_rect(1))
			and Rect2(Vector2.ZERO, g.VIEW).encloses(g._fsel_rect(0))
			and Rect2(Vector2.ZERO, g.VIEW).encloses(g._fsel_rect(1)))

	# ②
	g.mouse_at = _plate(0)
	_tick(90)
	_ok("② 「필터 켬」에 얹으면 금이 오른끝이다", g.fsel_hot == 0 and g.fsel_x > 0.99, "금 %.3f" % g.fsel_x)
	g.mouse_at = _plate(1)
	_tick(90)
	_ok("② 「필터 끔」에 얹으면 금이 왼끝이다", g.fsel_hot == 1 and g.fsel_x < 0.01, "금 %.3f" % g.fsel_x)
	g.mouse_at = Vector2(200.0, 120.0)
	_tick(90)
	var want: float = (200.0 + g.view_pad.x) / (g.VIEW.x + g.view_pad.x * 2.0)
	_ok("② 패 밖이면 금이 커서를 따른다", absf(g.fsel_x - want) < 0.01, "금 %.3f · 커서 %.3f" % [g.fsel_x, want])
	if _split() > -9.0:
		_ok("② 셰이더 가름이 금 자리다", absf(_split() - g.fsel_x) < 0.001, "%.3f" % _split())

	# ③
	g._click(_plate(1))
	_ok("③ 「필터 끔」 — 게이지 넷이 0", g.crt == 0.0 and g.warp == 0.0 and g.vhs == 0.0 and g.dot == 0.0)
	_ok("③ 0 으로 저장된다", float(Save.get_set("crt", -1.0)) == 0.0 and float(Save.get_set("warp", -1.0)) == 0.0
			and float(Save.get_set("vhs", -1.0)) == 0.0 and float(Save.get_set("dot", -1.0)) == 0.0)
	_ok("③ 다시 안 묻는다", not g._fsel_due())
	_ok("③ 처음이면 인트로로 간다", g.state == g.S.INTRO, "state %d" % g.state)

	# ⑥
	_tick(1)
	if _split() > -9.0:
		_ok("⑥ 뜨면 셰이더 가름이 걷힌다", _split() > 1.5, "%.3f" % _split())

	# ④
	g._intro_end()
	g._fsel_begin(false)
	_ok("④ 다시 열면 켬 쪽은 기본값으로 선다", is_equal_approx(g.crt, g.CRT_DEF))
	g._click(_plate(0))
	_ok("④ 「필터 켬」 — 기본값으로 저장", is_equal_approx(float(Save.get_set("crt", -1.0)), g.CRT_DEF)
			and is_equal_approx(float(Save.get_set("dot", -1.0)), g.DOT_DEF))
	_ok("④ 다시 연 것이면 제목으로", g.state == g.S.TITLE, "state %d" % g.state)

	# ⑤
	g._fsel_begin(false)
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	g._unhandled_input(esc)
	_ok("⑤ ESC 는 안 받는다", g.state == g.S.FSEL, "state %d" % g.state)
	var rt := InputEventKey.new()
	rt.keycode = KEY_RIGHT
	rt.pressed = true
	g._unhandled_input(rt)
	_tick(1)
	_ok("⑤ → 로 「필터 끔」을 고른다", g.fsel_hot == 1)
	var en := InputEventKey.new()
	en.keycode = KEY_ENTER
	en.pressed = true
	g._unhandled_input(en)
	_ok("⑤ Enter 로 정한다", g.state == g.S.TITLE and g.crt == 0.0)
	g._fsel_choose(0)
	_ok("⑤ 정한 뒤 누름은 아무 일도 없다", g.crt == 0.0 and g.state == g.S.TITLE)
