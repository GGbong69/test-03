extends SceneTree
# CRT 필터 검사 (2026-10-03) — 「CRT필터 알아? 그거 넣어 보는거 어때? 설정에서
# 조절할 수 있도록 하고」.
#   godot --headless --path . --script scripts/tools/qa_crt.gd
#
#   ① 셰이더가 읽히고 문법이 선다(헤드리스 렌더러도 셰이더 글을 구문 분석해
#      uniform 목록을 낸다 — 틀리면 목록이 빈다)
#   ② 기본값이 40 이다(빈 저장에서 읽은 값) · 도구 실행은 0 으로 뜬다(인트로와 같은 규약)
#   ③ 층이 맨 위에 서고 클릭을 안 먹는다 · 0 이면 숨고 0 위면 선다
#   ④ 설정 줄이 제목 · 상점 · 판 중 어디서 열어도 있다 — 게이지 줄이다
#   ⑤ 홈을 누르고 끌고 떼면(손가락도 같은 길 — 터치는 마우스로 흉내 난다)
#      값이 움직이고 뗄 때 저장된다 · 휠도 같다
#   ⑥ 저장한 값을 다음 실행이 되읽는다
#   ⑦ 모션 끄기면 깜박임 · 낟알이 꺼진다 · 보이는 논리 크기가 셰이더에 앉는다
#   ⑧ 개발자 판 사다리 다섯 칸(0 · 25 · 40 · 60 · 100)이 같은 값을 민다
#
#   사람의 저장은 안 건드린다 — 전역 · 프로필 둘 다 도구 자리로 돌린다.
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")
const GPATH := "user://_qa_crt_g.cfg"
var g = null
var ok := 0
var bad := 0


func _initialize() -> void:
	Save.gpath = GPATH
	Save.path = "user://_qa_crt.cfg"
	#  기본값을 재려면 전역 파일이 비어 있어야 한다 — 지난 실행이 남긴 도구 파일을
	#  지운다(도구 자리뿐이다. 사람의 highton.cfg 는 이름부터 다르다).
	var gp := ProjectSettings.globalize_path(GPATH)
	if FileAccess.file_exists(GPATH):
		DirAccess.remove_absolute(gp)
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


#  _initialize 안에서는 루트가 아직 나무에 안 들어가 Game 의 _ready(층을 세운다)가
#  안 돌았다 — 첫 틀에서 잰다.
var busy := false


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


func _mouse(p: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = p + g.view_pad
	g._unhandled_input(e)


func _move(p: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = p + g.view_pad
	e.relative = Vector2(1.0, 0.0)
	g._unhandled_input(e)


func _disk_crt() -> Variant:
	var c := ConfigFile.new()
	if c.load(GPATH) != OK:
		return null
	return c.get_value("설정", "crt", null)


func _run() -> void:
	print("\nCRT 필터 검사\n")

	# ── ① 셰이더 ───────────────────────────────────────
	var sh = load(g.CRT_SHADER)
	_ok("셰이더가 읽힌다", sh is Shader, g.CRT_SHADER)
	var names := PackedStringArray()
	if sh is Shader:
		for u in (sh as Shader).get_shader_uniform_list():
			names.append(String((u as Dictionary).get("name", "")))
		_ok("화면 읽기 셰이더다", (sh as Shader).code.contains("hint_screen_texture"))
	var need := ["strength", "logical", "motion", "scan", "mask", "bend", "glow", "vig"]
	var miss := []
	for nm in need:
		if not names.has(nm):
			miss.append(nm)
	_ok("구문이 선다 — uniform 이 다 나온다", miss.is_empty(),
			"%d개" % names.size() if miss.is_empty() else "빠짐 %s · 나온 것 %s" % [miss, names])

	# ── ② 기본값 ───────────────────────────────────────
	var lay: CanvasLayer = g.crt_layer
	var rect: ColorRect = g.crt_rect
	_ok("층이 섰다", lay != null and rect != null)
	if lay == null or rect == null:
		return
	#  도구로 돈 이 실행은 꺼진 채 떴다 — 화소를 재는 프로브가 원본을 받는다.
	_ok("도구 실행은 꺼진 채 뜬다", is_equal_approx(float(g.crt), 0.0) and not lay.visible,
			"%.2f · 보임 %s" % [float(g.crt), lay.visible])
	#  게임이 켤 때 읽는 그 길(_load_settings) — 빈 저장이면 40.
	g._load_settings()
	_ok("기본값 40", is_equal_approx(float(g.CRT_DEF), 0.4)
			and is_equal_approx(float(g.crt), 0.4), "CRT_DEF %.2f · 빈 저장에서 읽은 값 %.2f"
			% [float(g.CRT_DEF), float(g.crt)])
	_ok("저장에 아직 안 적었다", _disk_crt() == null, "%s" % [_disk_crt()])

	# ── ③ 층 ───────────────────────────────────────────
	var top := true
	for n in g.find_children("*", "CanvasLayer", true, false):
		if n != lay and (n as CanvasLayer).layer >= lay.layer:
			top = false
	_ok("맨 위 층이다", top and lay.layer > 0, "layer %d" % lay.layer)
	_ok("클릭을 안 먹는다", rect.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	_ok("온 화면을 덮는다", is_equal_approx(rect.anchor_right, 1.0)
			and is_equal_approx(rect.anchor_bottom, 1.0)
			and rect.anchor_left == 0.0 and rect.anchor_top == 0.0)
	_ok("40 이면 보인다", lay.visible and rect.visible)
	g._vol_set("crt", 0.0)
	_ok("0 이면 층째 숨는다", not lay.visible and not rect.visible)
	g._vol_set("crt", 0.01)
	_ok("1 이면 다시 선다", lay.visible)
	var mat := rect.material as ShaderMaterial
	_ok("세기가 셰이더에 앉는다", mat != null
			and is_equal_approx(float(mat.get_shader_parameter("strength")), 0.01))
	g._vol_set("crt", 0.4)

	# ── ④ 설정 줄 — 여는 자리 셋 ─────────────────────────
	var info: Dictionary = g._set_info("crt")
	_ok("이름 「CRT 필터」 · 게이지", String(info.get("n", "")) == "CRT 필터"
			and bool(info.get("g", false)), "%s" % info)
	_ok("한 줄 설명이 있다", String(info.get("d", "")) != "", String(info.get("d", "")))
	var opens := {"제목": -1, "상점": g.S.SHOP, "판 중": g.S.AIM_V}
	for nm in opens:
		g.pause_from = int(opens[nm])
		var rows: Array = g._set_rows()
		var ci := rows.find("crt")
		_ok("%s에서 연 설정에 줄이 있다" % nm, ci >= 0
				and ci == rows.find("mus") + 1, "%d번째 · %s" % [ci, rows])
		var r: Rect2 = g._set_rect(ci)
		_ok("%s — 줄이 화면 안이다" % nm, r.end.y <= 354.0, "%.0f" % r.end.y)
	#  실제 문으로 연다 — 상점에서 「설정」(_pause_open).
	g._new_run()
	g.swap_live = false
	g.turn_live = false
	g.sweep_live = false
	g.boost_t = -1.0
	g._tutor_close()
	g.tutor_q.clear()
	g.state = g.S.SHOP
	g._open_shop()
	g._tutor_close()
	g.tutor_q.clear()
	g.sweep_live = false
	g.boost_t = -1.0
	g._pause_open()
	_ok("상점에서 설정이 열린다", g.state == g.S.SETTINGS and g.pause_from == g.S.SHOP,
			"state %d · from %d" % [g.state, g.pause_from])
	g.set_t = 1.0
	for k in 4:
		g._set_tick(1.0 / 60.0)

	# ── ⑤ 누르고 · 끌고 · 떼기 ───────────────────────────
	var rows2: Array = g._set_rows()
	var ci2: int = rows2.find("crt")
	#  왼쪽 글줄을 누르면 고르기만 한다(게임이 안 바뀐다).
	_mouse(g._set_rect(ci2).get_center(), true)
	_mouse(g._set_rect(ci2).get_center(), false)
	_ok("글줄을 누르면 고른다", g.set_sel == ci2 and g.state == g.S.SETTINGS,
			"set_sel %d" % g.set_sel)
	g.mouse_at = Vector2(-50.0, -50.0)
	g.set_hot = -1
	_ok("오른쪽 판이 CRT 를 편다", g._set_face() == ci2)
	var tr: Rect2 = g._vol_track()
	var p0 := Vector2(tr.position.x + tr.size.x * 0.20, tr.get_center().y)
	var p1 := Vector2(tr.position.x + tr.size.x * 0.75, tr.get_center().y)
	_mouse(p0, true)
	_ok("홈을 누르면 끈다", g.set_drag == ci2 and is_equal_approx(g.crt, 0.2),
			"drag %d · %.2f" % [g.set_drag, g.crt])
	_move(p1)
	_ok("끌면 따라온다", is_equal_approx(g.crt, 0.75), "%.2f" % g.crt)
	_ok("끄는 동안 층이 그 값을 쓴다", is_equal_approx(
			float(mat.get_shader_parameter("strength")), 0.75))
	_mouse(p1, false)
	_ok("떼면 놓는다", g.set_drag == -1)
	_ok("떼면 저장된다", _disk_crt() != null and is_equal_approx(float(_disk_crt()), 0.75),
			"디스크 %s" % [_disk_crt()])
	#  끝까지 왼쪽으로 끌면 0 — 층이 숨는다.
	_mouse(p0, true)
	_move(Vector2(tr.position.x - 30.0, tr.get_center().y))
	_mouse(Vector2(tr.position.x - 30.0, tr.get_center().y), false)
	_ok("왼끝까지 끌면 0 · 숨는다", is_equal_approx(g.crt, 0.0) and not lay.visible,
			"%.2f · 보임 %s" % [g.crt, lay.visible])
	_ok("0 도 저장된다", _disk_crt() != null and is_equal_approx(float(_disk_crt()), 0.0))
	#  휠 — 홈 위에서 위로 한 칸 = +5.
	g.wheel_ms = 0
	g._wheel(tr.get_center(), -1)
	_ok("휠 한 칸 = 5", is_equal_approx(g.crt, 0.05) and lay.visible, "%.2f" % g.crt)
	g._vol_save_due()
	_ok("휠 값도 저장된다", _disk_crt() != null and is_equal_approx(float(_disk_crt()), 0.05))
	#  수 글은 게이지와 같은 값을 읽는다.
	_ok("수 글이 같은 값", is_equal_approx(g._gauge_v("crt"), g.crt)
			and is_equal_approx(g._gauge_v("vol"), g.vol)
			and is_equal_approx(g._gauge_v("mus"), g.vol_mus))
	g._settings_back()
	_ok("닫으면 상점으로", g.state == g.S.SHOP)

	# ── ⑥ 되읽기 ───────────────────────────────────────
	g._vol_set("crt", 0.63)
	g.set_drag = ci2
	g.pause_from = g.S.SHOP
	g._set_slide_end()
	g.pause_from = -1
	g.crt = 0.9
	g._load_settings()
	_ok("저장한 값을 되읽는다", is_equal_approx(g.crt, 0.63), "%.2f" % g.crt)
	_ok("되읽은 값이 층에 앉는다", is_equal_approx(
			float(mat.get_shader_parameter("strength")), 0.63) and lay.visible)

	# ── ⑦ 모션 · 크기 ─────────────────────────────────
	g.motion_off = true
	g._process(1.0 / 60.0)
	_ok("모션 끄기면 깜박임이 꺼진다",
			is_equal_approx(float(mat.get_shader_parameter("motion")), 0.0))
	g.motion_off = false
	g._process(1.0 / 60.0)
	_ok("모션 켜면 돌아온다",
			is_equal_approx(float(mat.get_shader_parameter("motion")), 1.0))
	var lg: Vector2 = mat.get_shader_parameter("logical")
	_ok("보이는 논리 크기가 앉는다", lg.is_equal_approx(g.get_viewport_rect().size),
			"%s" % lg)

	# ── ⑧ 개발자 판 ──────────────────────────────────
	var pg0 := Dev.page
	var hit := -1
	var rows3: Array = []
	for pg in Dev.PAGES.size():
		Dev.page = pg
		var rs: Array = Dev._rows(g)
		for i in rs.size():
			if String((rs[i] as Dictionary).get("k", "")) == "crt":
				hit = pg
				rows3 = rs
	_ok("개발자 판에 줄이 있다", hit >= 0, "%d쪽 · %d줄" % [hit, rows3.size()])
	_ok("그 쪽이 열아홉 줄 안이다", rows3.size() <= 19, "%d줄" % rows3.size())
	_ok("고르개가 안 빈다", Dev._names("crt").size() == 5, "%s" % [Dev._names("crt")])
	var got := []
	for j in Dev.CRT_STEPS.size():
		Dev.pick["crt"] = j
		Dev._run(g, {"k": "crt"})
		got.append(int(roundf(g.crt * 100.0)))
	_ok("사다리 0 · 25 · 40 · 60 · 100", got == [0, 25, 40, 60, 100], "%s" % [got])
	Dev.pick["crt"] = 0
	Dev._run(g, {"k": "crt"})
	_ok("사다리 0 이면 숨는다", not lay.visible)
	g.crt = 0.6
	Dev.page = hit
	Dev._rows(g)
	_ok("값 칸이 지금 값에 맞는다", int(Dev.pick.get("crt", -1)) == 3
			and String(Dev._cur_name(g, {"k": "crt"})).contains("60"),
			Dev._cur_name(g, {"k": "crt"}))
	Dev.page = pg0
	g.crt = 0.4
	g._crt_apply()
