extends SceneTree
# 화면 고르기(2026-10-10 · game.gd FSEL) — 못 박는 것:
#   ① 처음이면 고를 차례다 · 열면 넷 다 기본값(칸마다 제 묶음이 서려면) · 음악이 없다 · 칸 셋이 화면 안에
#      겹치지 않고 패는 제 칸 밑이다
#   ② 필터 층은 제 칸 안에만 — CRT 는 가운데(브라운관) · VHS · 도트는 오른쪽(비디오테이프) · 옮겨 붙이는
#      장면 칸은 그림 칸과 크기가 같다(1:1)
#   ③ 얹으면 그 칸 — 그림 칸이나 패
#   ④ 「끔」을 누르면 게이지 넷이 0 으로 저장되고 · 다시 안 묻고 · 처음이면 인트로로 · 층 창이 온 화면으로
#   ⑤ 「브라운관」 · 「비디오테이프」 — 제 둘만 기본값으로
#   ⑥ 설정 「화면」 탭 — 제목에서 연 설정에만 「화면 고르기」 줄이 있고, 누르면 고르기 · 고르면 설정으로
#   ⑦ 다시 연 것은 ESC 로 옛 값 그대로 돌아간다 · 처음 켤 때는 ESC 를 안 받는다
#   ⑧ 키 — ← → 로 고르고 Enter 로 정한다 · 정한 뒤 또 누르면 아무 일도 없다
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


func _win(r) -> Vector4:
	if r == null or not is_instance_valid(r):
		return Vector4(-9, -9, -9, -9)
	var m := (r as ColorRect).material as ShaderMaterial
	return m.get_shader_parameter("win") if m != null else Vector4(-9, -9, -9, -9)


func _key(kc: int) -> void:
	var e := InputEventKey.new()
	e.keycode = kc
	e.pressed = true
	g._unhandled_input(e)


func _vals() -> String:
	return "%.2f %.2f %.2f %.2f" % [g.crt, g.warp, g.vhs, g.dot]


func _saved(c: float, w: float, v: float, d: float) -> bool:
	return is_equal_approx(float(Save.get_set("crt", -1.0)), c) \
			and is_equal_approx(float(Save.get_set("warp", -1.0)), w) \
			and is_equal_approx(float(Save.get_set("vhs", -1.0)), v) \
			and is_equal_approx(float(Save.get_set("dot", -1.0)), d)


func _run() -> void:
	# ① — 검사 전역 파일은 Save.wipe 가 안 비운다(지난 실행이 남긴 "fsel")
	Save.set_set("fsel", false)
	_ok("① 처음이면 고를 차례다", g._fsel_due())
	g._fsel_begin(true)
	_ok("① 고르기 화면이 선다", g.state == g.S.FSEL)
	_ok("① 넷 다 기본값으로 선다", is_equal_approx(g.crt, g.CRT_DEF) and is_equal_approx(g.warp, g.WARP_DEF)
			and is_equal_approx(g.vhs, g.VHS_DEF) and is_equal_approx(g.dot, g.DOT_DEF), _vals())
	_ok("① 음악이 없다(인트로 앞이다)", g._mus_want() == "")
	var view := Rect2(Vector2.ZERO, g.VIEW)
	var apart := true
	for i in 3:
		var r: Rect2 = (g._fsel_rect(i) as Rect2).grow(float(g.FSEL.frame))
		var pl: Rect2 = g._fsel_plate(i)
		apart = apart and view.encloses(r) and view.encloses(pl) and pl.position.y >= r.end.y \
				and absf(pl.get_center().x - r.get_center().x) < 1.0
		for j in range(i + 1, 3):
			apart = apart and not r.intersects((g._fsel_rect(j) as Rect2).grow(float(g.FSEL.frame)))
	_ok("① 칸 셋이 화면 안 · 안 겹치고 · 패는 제 칸 밑", apart)

	# ②
	if g.crt_rect != null:
		_ok("② CRT 는 가운데 칸에만", _win(g.crt_rect).is_equal_approx(g._fsel_uv(g._fsel_rect(1))))
		_ok("② VHS 는 오른쪽 칸에만", _win(g.vhs_rect).is_equal_approx(g._fsel_uv(g._fsel_rect(2))))
		_ok("② 도트는 오른쪽 칸에만", _win(g.dot_rect).is_equal_approx(g._fsel_uv(g._fsel_rect(2))))
	_ok("② 옮겨 붙이는 장면 칸은 그림 칸과 크기가 같다(1:1)",
			(g.FSEL.src as Rect2).size.is_equal_approx((g._fsel_rect(0) as Rect2).size))
	_ok("② 층이 선다", g.fsel_layer != null and g.fsel_layer.visible)

	# ③
	g.mouse_at = (g._fsel_rect(1) as Rect2).get_center()
	g._fsel_tick(0.016)
	_ok("③ 가운데 칸에 얹으면 1", g.fsel_hot == 1)
	g.mouse_at = (g._fsel_plate(2) as Rect2).get_center()
	g._fsel_tick(0.016)
	_ok("③ 오른쪽 패에 얹으면 2", g.fsel_hot == 2)
	g.mouse_at = Vector2(320.0, 20.0)
	g._fsel_tick(0.016)
	_ok("③ 칸 밖이면 없다", g.fsel_hot == -1)

	# ④
	g._click((g._fsel_rect(0) as Rect2).get_center())
	_ok("④ 「끔」 — 게이지 넷이 0", g.crt == 0.0 and g.warp == 0.0 and g.vhs == 0.0 and g.dot == 0.0, _vals())
	_ok("④ 0 으로 저장된다", _saved(0.0, 0.0, 0.0, 0.0))
	_ok("④ 다시 안 묻는다", not g._fsel_due())
	_ok("④ 처음이면 인트로로 간다", g.state == g.S.INTRO, "state %d" % g.state)
	g._fsel_tick(0.016)
	if g.crt_rect != null:
		_ok("④ 층 창이 온 화면으로", _win(g.crt_rect).is_equal_approx(Vector4(0, 0, 1, 1))
				and _win(g.dot_rect).is_equal_approx(Vector4(0, 0, 1, 1)))
	_ok("④ 층이 걷힌다", g.fsel_layer == null or not g.fsel_layer.visible)
	g._intro_end()

	# ⑤
	g._fsel_begin(false)
	g._click((g._fsel_plate(1) as Rect2).get_center())
	_ok("⑤ 「브라운관」 — CRT · 굴곡만", _saved(g.CRT_DEF, g.WARP_DEF, 0.0, 0.0), _vals())
	_ok("⑤ 다시 연 것이면 제목으로", g.state == g.S.TITLE, "state %d" % g.state)
	g._fsel_begin(false)
	g._click((g._fsel_rect(2) as Rect2).get_center())
	_ok("⑤ 「비디오테이프」 — VHS · 도트만", _saved(0.0, 0.0, g.VHS_DEF, g.DOT_DEF), _vals())

	# ⑥
	g.pause_from = -1
	g._set_go("screen")
	g.state = g.S.SETTINGS
	var rows: Array = g._set_rows()
	_ok("⑥ 제목에서 연 설정에 「화면 고르기」 줄", rows.has("fsel"))
	var fi := rows.find("fsel")
	g._click((g._set_rect(fi) as Rect2).get_center())
	_ok("⑥ 누르면 고르기", g.state == g.S.FSEL and g.fsel_from == g.S.SETTINGS)
	_ok("⑥ 설정에서 연 것은 로비 곡 그대로", g._mus_want() == "lobby")
	g._click((g._fsel_rect(1) as Rect2).get_center())
	_ok("⑥ 고르면 설정으로 돌아온다", g.state == g.S.SETTINGS, "state %d" % g.state)
	var last: Rect2 = g._set_rect(rows.size() - 2)
	var back: Rect2 = g._set_rect(rows.size() - 1)
	_ok("⑥ 일곱 줄이 「뒤로」에 안 닿는다", last.end.y < back.position.y, "%.0f < %.0f" % [last.end.y, back.position.y])
	_ok("⑥ 설정 창이 화면 안", Rect2(Vector2.ZERO, g.VIEW).encloses(g._set_to("screen")))
	g.pause_from = g.S.PICK
	_ok("⑥ 판 중에 연 설정에는 없다", not (g._set_rows() as Array).has("fsel"))
	g.pause_from = -1

	# ⑦
	g._fsel_begin(false, g.S.SETTINGS)
	_key(KEY_ESCAPE)
	_ok("⑦ 다시 연 것은 ESC 로 돌아간다", g.state == g.S.SETTINGS, "state %d" % g.state)
	_ok("⑦ 옛 값 그대로(브라운관)", is_equal_approx(g.crt, g.CRT_DEF) and g.vhs == 0.0, _vals())
	g._fsel_begin(true)
	_key(KEY_ESCAPE)
	_ok("⑦ 처음 켤 때는 ESC 를 안 받는다", g.state == g.S.FSEL, "state %d" % g.state)

	# ⑧
	g.mouse_at = Vector2(320.0, 20.0)
	g._fsel_tick(0.016)
	_key(KEY_RIGHT)
	g._fsel_tick(0.016)
	_ok("⑧ → 처음은 왼쪽 칸", g.fsel_hot == 0)
	_key(KEY_RIGHT)
	_key(KEY_RIGHT)
	g._fsel_tick(0.016)
	_ok("⑧ → 둘 더면 오른쪽 칸", g.fsel_hot == 2)
	_key(KEY_LEFT)
	g._fsel_tick(0.016)
	_ok("⑧ ← 하나면 가운데", g.fsel_hot == 1)
	_key(KEY_ENTER)
	_ok("⑧ Enter 로 정한다(브라운관 · 처음이라 인트로로)", g.state == g.S.INTRO and is_equal_approx(g.crt, g.CRT_DEF)
			and g.vhs == 0.0, "state %d · %s" % [g.state, _vals()])
	g._fsel_choose(0)
	_ok("⑧ 정한 뒤 또 누르면 아무 일도 없다", is_equal_approx(g.crt, g.CRT_DEF))
