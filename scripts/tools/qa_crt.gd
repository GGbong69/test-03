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
#      2026-10-03 부터는 「화면」 갈래 안이다(「설정이 저기서 다 나열되기 보단 화면안에
#      전체화면, crt 필터 이렇게 좀 상위가 있으면 좋겠는데」). 제목은 설정 › 화면,
#      판 중은 일시정지 › 설정 › 화면 으로 **누르며** 들어가 거기 있는지 본다.
#      굽힘은 「화면 굴곡」으로 갈라 나갔다 — CRT 손잡이는 주사선 · 번짐만 민다.
#   ⑤ 홈을 누르고 끌고 떼면(손가락도 같은 길 — 터치는 마우스로 흉내 난다)
#      값이 움직이고 뗄 때 저장된다 · 휠도 같다
#   ⑥ 저장한 값을 다음 실행이 되읽는다
#   ⑦ 모션 끄기면 깜박임 · 낟알이 꺼진다 · 보이는 논리 크기가 셰이더에 앉는다
#   ⑧ 개발자 판 사다리 다섯 칸(0 · 25 · 40 · 60 · 100)이 같은 값을 민다
#   ⑨ VHS 필터 · 도트 팔레트(2026-10-04 — CRT 밑 층 98 · 97) — 셰이더 구문 · 층 자리 ·
#      0 이면 숨음 · 혼자 섬 · 논리 크기 · 모션 끄기(VHS) · 설정 줄을 누르고 끌고 떼고 휠 ·
#      저장 · 되읽기 · 개발자 판 사다리. 잔상 손(crt_trail)이 CRT 층에 붙었는지도 ③ 에서 본다
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
	#  bend 는 없다 — 굽힘이 「화면 굴곡」(warp)으로 갈라 나갔다(qa_warp 가 잰다).
	var need := ["strength", "logical", "motion", "scan", "mask", "warp", "glow", "vig",
			"beam_lo", "beam_hi", "roll", "prev", "trail", "trail_dt"]
	var miss := []
	for nm in need:
		if not names.has(nm):
			miss.append(nm)
	_ok("구문이 선다 — uniform 이 다 나온다", miss.is_empty(),
			"%d개" % names.size() if miss.is_empty() else "빠짐 %s · 나온 것 %s" % [miss, names])
	_ok("CRT 세기가 굽힘을 안 민다(bend 가 없다)", not names.has("bend"))

	# ── ② 기본값 ───────────────────────────────────────
	var lay: CanvasLayer = g.crt_layer
	var rect: ColorRect = g.crt_rect
	_ok("층이 섰다", lay != null and rect != null)
	if lay == null or rect == null:
		return
	#  도구로 돈 이 실행은 꺼진 채 떴다 — 화소를 재는 프로브가 원본을 받는다.
	_ok("도구 실행은 꺼진 채 뜬다", is_equal_approx(float(g.crt), 0.0)
			and is_equal_approx(float(g.warp), 0.0) and not lay.visible,
			"CRT %.2f · 굴곡 %.2f · 보임 %s" % [float(g.crt), float(g.warp), lay.visible])
	_ok("도구 실행은 VHS · 도트도 꺼진 채 뜬다", is_equal_approx(float(g.vhs), 0.0)
			and is_equal_approx(float(g.dot), 0.0) and g.vhs_rect != null and g.dot_rect != null
			and not (g.vhs_rect.get_parent() as CanvasLayer).visible
			and not (g.dot_rect.get_parent() as CanvasLayer).visible,
			"VHS %.2f · 도트 %.2f" % [float(g.vhs), float(g.dot)])
	#  게임이 켤 때 읽는 그 길(_load_settings) — 빈 저장이면 40.
	g._load_settings()
	_ok("기본값 40", is_equal_approx(float(g.CRT_DEF), 0.4)
			and is_equal_approx(float(g.crt), 0.4), "CRT_DEF %.2f · 빈 저장에서 읽은 값 %.2f"
			% [float(g.CRT_DEF), float(g.crt)])
	_ok("저장에 아직 안 적었다", _disk_crt() == null, "%s" % [_disk_crt()])
	_ok("VHS · 도트 기본값도 빈 저장에서 앉는다 · 층이 선다", is_equal_approx(float(g.vhs),
			float(g.VHS_DEF)) and is_equal_approx(float(g.dot), float(g.DOT_DEF))
			and (g.vhs_rect.get_parent() as CanvasLayer).visible == (float(g.VHS_DEF) > 0.004)
			and (g.dot_rect.get_parent() as CanvasLayer).visible == (float(g.DOT_DEF) > 0.004),
			"VHS %.2f(표 %.2f) · 도트 %.2f(표 %.2f)" % [float(g.vhs), float(g.VHS_DEF),
				float(g.dot), float(g.DOT_DEF)])
	#  굴곡도 같은 길로 50 이 앉았다. 아래 클릭은 원본 자리를 그대로 누르므로 굴곡을
	#  0 으로 내리고 잰다 — 굴곡 위의 누름은 qa_warp 가 잰다. 둘 다 서 있는 층에서
	#  CRT 만 0 이면 층은 **선 채로** 남아야 한다(굴곡이 그리는 중이다).
	_ok("굴곡 기본 50 도 같이 앉는다", is_equal_approx(float(g.warp), 0.5), "%.2f" % float(g.warp))
	g._vol_set("crt", 0.0)
	_ok("CRT 0 이어도 굴곡이 서 있으면 층이 선다", lay.visible
			and is_equal_approx(float((g.crt_rect.material as ShaderMaterial)
				.get_shader_parameter("strength")), 0.0))
	g._vol_set("warp", 0.0)
	g._vol_set("crt", 0.4)

	# ── ③ 층 ───────────────────────────────────────────
	#  브라운관 켜기 · 끄기 층(PWR · 2026-10-06)만 그 위다 — 켜고 끄는 동안만 서서 CRT 가
	#  그린 화면을 통째로 눌렀다 편다. 늘 서 있는 층 가운데서는 CRT 가 맨 위다.
	var top := true
	for n in g.find_children("*", "CanvasLayer", true, false):
		if n != lay and n != g.pwr_layer and (n as CanvasLayer).layer >= lay.layer:
			top = false
	_ok("맨 위 층이다(켜기 · 끄기 층 빼고)", top and lay.layer > 0, "layer %d" % lay.layer)
	_ok("켜기 · 끄기 층은 CRT 위 · 평소엔 숨는다", g.pwr_layer != null
			and g.pwr_layer.layer > lay.layer and not g.pwr_layer.visible)
	_ok("클릭을 안 먹는다", rect.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	#  잔상 손 — CRT 층에 붙는다. 헤드리스는 렌더링 디바이스가 없어 쉰다(prev 가 빈다).
	var trn = lay.get_node_or_null("CrtTrail")
	_ok("잔상 손이 CRT 층에 붙었다", trn != null and trn.mat == rect.material
			and trn.layer == lay)
	if DisplayServer.get_name() == "headless":
		_ok("헤드리스면 잔상이 쉰다 — prev 가 비었다", trn != null and trn.rd == null
				and (rect.material as ShaderMaterial).get_shader_parameter("prev") == null)
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
	#  설명 줄은 없다(2026-10-03 창으로 고치며 — 「효과만, 해설 금지」). 값을 밀면 화면이
	#  곧바로 그렇게 된다.
	_ok("설명 줄이 없다", not info.has("d"), "%s" % info)
	_ok("「화면」 갈래가 CRT 를 품는다", (g._set_info("screen").get("kids", []) as Array)
			.has("crt"), "%s" % [g._set_info("screen").get("kids", [])])
	var opens := {"제목": -1, "상점": g.S.SHOP, "판 중": g.S.AIM_V}
	for nm in opens:
		g.state = g.S.SETTINGS
		g.pause_from = int(opens[nm])
		g._set_go("pause" if int(opens[nm]) >= 0 else "top")
		g.set_t = 1.0
		g.set_pg_t = 1.0
		#  누르며 들어간다 — 일시정지 › 설정(첫 탭이 화면). 제목은 곧장 설정 창이다.
		var path := []
		for key in ["set"]:
			var ki: int = (g._set_rows() as Array).find(key)
			if ki >= 0:
				g._click((g._set_rect(ki) as Rect2).get_center())
				g.set_pg_t = 1.0
				path.append(g._set_pg())
		var rows: Array = g._set_rows()
		var ci := rows.find("crt")
		_ok("%s에서 연 설정 › 화면에 줄이 있다" % nm, g._set_pg() == "screen" and ci >= 0
				and ci == rows.find("fs") + 1 and ci == rows.find("warp") - 1,
				"%s · %d번째 · %s" % [path, ci, rows])
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
	_ok("상점에서 일시정지가 열린다", g.state == g.S.SETTINGS and g.pause_from == g.S.SHOP
			and g._set_pg() == "pause",
			"state %d · from %d · 쪽 %s" % [g.state, g.pause_from, g._set_pg()])
	g.set_t = 1.0
	for k in 4:
		g._set_tick(1.0 / 60.0)
	#  진짜 누름으로 들어간다 — 「설정」(첫 탭이 「화면」).
	for key in ["set"]:
		g.set_pg_t = 1.0
		var c0: Vector2 = (g._set_rect((g._set_rows() as Array).find(key)) as Rect2).get_center()
		_mouse(c0, true)
		_mouse(c0, false)
	g.set_pg_t = 1.0
	_ok("일시정지 › 설정 = 화면 탭", g._set_pg() == "screen", g._set_pg())

	# ── ⑤ 누르고 · 끌고 · 떼기 ───────────────────────────
	var rows2: Array = g._set_rows()
	var ci2: int = rows2.find("crt")
	#  줄의 이름 쪽을 누르면 고르기만 한다 — 값이 안 튄다(홈은 이름 칸 뒤에서 시작한다).
	var crt0: float = g.crt
	var nm_at: Vector2 = g._set_rect(ci2).position + Vector2(30.0, g._set_rect(ci2).size.y * 0.5)
	_mouse(nm_at, true)
	_mouse(nm_at, false)
	_ok("이름을 누르면 고르기만 한다", g.set_sel == ci2 and g.state == g.S.SETTINGS
			and g.set_drag == -1 and is_equal_approx(g.crt, crt0),
			"set_sel %d · %.2f → %.2f" % [g.set_sel, crt0, g.crt])
	g.mouse_at = Vector2(-50.0, -50.0)
	g.set_hot = -1
	_ok("띠가 CRT 줄에 선다", g._set_face() == ci2)
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
	_ok("한 번 오르면 일시정지(탭은 단이 아니다)", g._set_pg() == "pause"
			and g.state == g.S.SETTINGS)
	g._settings_back()
	_ok("또 오르면 상점으로", g.state == g.S.SHOP)

	# ── ⑥ 되읽기 ───────────────────────────────────────
	g._vol_set("crt", 0.63)
	g.pause_from = g.S.SHOP
	g.set_page = "screen"
	g.set_drag = ci2
	g._set_slide_end()
	g.pause_from = -1
	g.crt = 0.9
	g._load_settings()
	_ok("저장한 값을 되읽는다", is_equal_approx(g.crt, 0.63), "%.2f" % g.crt)
	#  되읽기는 굴곡(빈 저장이면 50)도 같이 앉힌다 — 아래 「0 이면 숨는다」는 CRT 만 재므로
	#  굴곡을 다시 0 으로 내린다(굴곡이 서 있으면 층이 선 채인 것이 맞다 — ②).
	g.warp = 0.0
	g._crt_apply()
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
	#  「화면 굴곡」 줄 — CRT 줄 바로 밑(개발자 모드에 제때 넣기, 2026-10-03).
	var rs4: Array = Dev._rows(g)
	var ci4 := -1
	var wi4 := -1
	for i in rs4.size():
		var kk := String((rs4[i] as Dictionary).get("k", ""))
		if kk == "crt":
			ci4 = i
		elif kk == "warp":
			wi4 = i
	_ok("개발자 판 「화면 굴곡」이 CRT 줄 바로 밑", ci4 >= 0 and wi4 == ci4 + 1,
			"CRT %d · 굴곡 %d" % [ci4, wi4])
	_ok("굴곡 고르개가 안 빈다", Dev._names("warp").size() == 5, "%s" % [Dev._names("warp")])
	var gotw := []
	for j in Dev.WARP_STEPS.size():
		Dev.pick["warp"] = j
		Dev._run(g, {"k": "warp"})
		gotw.append(int(roundf(g.warp * 100.0)))
	_ok("굴곡 사다리 0 · 25 · 50 · 75 · 100", gotw == [0, 25, 50, 75, 100], "%s" % [gotw])
	_ok("굴곡 100 이 셰이더에 앉는다", is_equal_approx(
			float(mat.get_shader_parameter("warp")), 1.0))
	g.crt = 0.0
	Dev.pick["warp"] = 0
	Dev._run(g, {"k": "warp"})
	_ok("CRT 0 · 굴곡 사다리 0 이면 층이 숨는다", not lay.visible)
	g.warp = 0.75
	Dev._rows(g)
	_ok("굴곡 값 칸이 지금 값에 맞는다", int(Dev.pick.get("warp", -1)) == 3
			and String(Dev._cur_name(g, {"k": "warp"})).contains("75"),
			Dev._cur_name(g, {"k": "warp"}))
	g.warp = 0.0
	Dev.page = pg0
	g.crt = 0.4
	g._crt_apply()

	# ── ⑨ VHS 필터 · 도트 팔레트 ──────────────────────────
	print("")
	_retro_check("vhs", "VHS 필터", g.VHS_SHADER, float(g.VHS_DEF), int(g.VHS_LAYER),
			Dev.VHS_STEPS)
	print("")
	_retro_check("dot", "도트 팔레트", g.DOT_SHADER, float(g.DOT_DEF), int(g.DOT_LAYER),
			Dev.DOT_STEPS)
	#  설정 화면 탭의 차림 — CRT · 굴곡 밑에 VHS · 도트.
	g.state = g.S.SETTINGS
	g.pause_from = g.S.SHOP
	g._set_go("screen")
	_ok("화면 탭 — 전체화면 · CRT · 굴곡 · VHS · 도트 · 전환 지지직 · 뒤로", (g._set_rows() as Array)
			== ["fs", "crt", "warp", "vhs", "dot", "wipe", "back"], "%s" % [g._set_rows()])
	g.state = g.S.SHOP
	g.pause_from = -1


func _disk(key: String) -> Variant:
	var c := ConfigFile.new()
	if c.load(GPATH) != OK:
		return null
	return c.get_value("설정", key, null)


#  ⑨ 층 하나 — VHS(98) · 도트(97). 같은 자로 잰다.
func _retro_check(key: String, nm: String, shp: String, def: float, z: int,
		steps: Array) -> void:
	var rect: ColorRect = g.vhs_rect if key == "vhs" else g.dot_rect
	var shx = load(shp)
	var un := PackedStringArray()
	if shx is Shader:
		for u in (shx as Shader).get_shader_uniform_list():
			un.append(String((u as Dictionary).get("name", "")))
	var needx := ["strength", "logical"]
	if key == "vhs":
		needx.append("motion")
	var missx := []
	for u in needx:
		if not un.has(u):
			missx.append(u)
	_ok("%s — 셰이더 구문이 선다(화면 읽기)" % nm, shx is Shader and missx.is_empty()
			and (shx as Shader).code.contains("hint_screen_texture"),
			"%d개 · 빠짐 %s" % [un.size(), missx])
	_ok("%s — 층이 섰다" % nm, rect != null)
	if rect == null:
		return
	var lay := rect.get_parent() as CanvasLayer
	_ok("%s — 층 %d · 게임 오버(%d) · 덮개(%d) 위 · CRT(%d) 밑" % [nm, lay.layer,
			g.oc_layer.layer, g.wipe_layer.layer, g.crt_layer.layer], lay.layer == z
			and lay.layer > g.wipe_layer.layer and lay.layer > g.oc_layer.layer
			and lay.layer < g.crt_layer.layer)
	_ok("%s — 클릭을 안 먹는다 · 온 화면" % nm, rect.mouse_filter == Control.MOUSE_FILTER_IGNORE
			and is_equal_approx(rect.anchor_right, 1.0) and is_equal_approx(rect.anchor_bottom, 1.0)
			and rect.anchor_left == 0.0 and rect.anchor_top == 0.0)
	var mat := rect.material as ShaderMaterial
	g._vol_set(key, 0.0)
	_ok("%s — 0 이면 층째 숨는다" % nm, not lay.visible and not rect.visible)
	g._vol_set(key, 0.01)
	_ok("%s — 1 이면 선다 · 세기가 앉는다" % nm, lay.visible and rect.visible
			and is_equal_approx(float(mat.get_shader_parameter("strength")), 0.01))
	#  CRT · 굴곡이 둘 다 꺼져 CRT 층이 숨어도 혼자 선다 — 문은 _crt_apply 하나다.
	var c0: float = g.crt
	var w0: float = g.warp
	g.crt = 0.0
	g.warp = 0.0
	g._vol_set(key, 0.5)
	_ok("%s — CRT 층이 숨어도 혼자 선다" % nm, lay.visible and not g.crt_layer.visible)
	g.crt = c0
	g.warp = w0
	g._crt_apply()
	var lg = mat.get_shader_parameter("logical")
	_ok("%s — 보이는 논리 크기가 앉는다" % nm, lg is Vector2
			and (lg as Vector2).is_equal_approx(g.get_viewport_rect().size), "%s" % [lg])
	#  창을 16:10 으로 바꾸면 size_changed 길로 다시 앉는다. 바랄 값은 손으로 셈한 것이다
	#  (640x360 · expand → 640x400) — 넣은 곳과 견주는 곳이 같으면 늘 맞는다.
	var rs0: Vector2i = root.size
	root.size = Vector2i(1280, 800)
	var lg2 = mat.get_shader_parameter("logical")
	_ok("%s — 16:10 창이면 논리 640x400 이 앉는다(창 크기 감시)" % nm, lg2 is Vector2
			and (lg2 as Vector2).is_equal_approx(Vector2(640.0, 400.0)),
			"%s · 창 %s" % [lg2, root.size])
	root.size = rs0
	if key == "vhs":
		g.motion_off = true
		g._process(1.0 / 60.0)
		_ok("VHS — 모션 끄기면 테이프 시계가 선다(motion 0)",
				is_equal_approx(float(mat.get_shader_parameter("motion")), 0.0))
		g.motion_off = false
		g._process(1.0 / 60.0)
		_ok("VHS — 모션 켜면 돌아온다",
				is_equal_approx(float(mat.get_shader_parameter("motion")), 1.0))
	# ── 설정 줄 — 누르고 · 끌고 · 떼고 · 휠
	g.state = g.S.SETTINGS
	g.pause_from = g.S.SHOP
	g._set_go("screen")
	g.set_t = 1.0
	g.set_pg_t = 1.0
	g.mouse_at = Vector2(-50.0, -50.0)
	var rows: Array = g._set_rows()
	var ri := rows.find(key)
	var info: Dictionary = g._set_info(key)
	_ok("%s — 화면 탭의 게이지 줄 · 설명 없음" % nm, ri >= 0 and String(info.get("n", "")) == nm
			and bool(info.get("g", false)) and not info.has("d"), "%d · %s" % [ri, info])
	if ri < 0:
		return
	var r: Rect2 = g._set_rect(ri)
	_ok("%s — 줄이 화면 안이다" % nm, r.end.y <= 354.0 and r.position.y >= 6.0, "%s" % [r])
	var tr: Rect2 = g._vol_track(ri)
	var p0 := Vector2(tr.position.x + tr.size.x * 0.20, tr.get_center().y)
	var p1 := Vector2(tr.position.x + tr.size.x * 0.70, tr.get_center().y)
	_mouse(p0, true)
	_ok("%s — 홈을 누르면 그 자리 · 끈다" % nm, g.set_drag == ri
			and is_equal_approx(g._gauge_v(key), 0.2), "drag %d · %.2f" % [g.set_drag,
			g._gauge_v(key)])
	_move(p1)
	_ok("%s — 끌면 따라온다 · 층이 그 값" % nm, is_equal_approx(g._gauge_v(key), 0.7)
			and is_equal_approx(float(mat.get_shader_parameter("strength")), 0.7),
			"%.2f" % g._gauge_v(key))
	_mouse(p1, false)
	_ok("%s — 떼면 놓고 저장된다" % nm, g.set_drag == -1 and _disk(key) != null
			and is_equal_approx(float(_disk(key)), 0.7), "디스크 %s" % [_disk(key)])
	g.wheel_ms = 0
	g._wheel(r.position + Vector2(30.0, r.size.y * 0.5), -1)
	_ok("%s — 휠 한 칸 = 5(줄 어디서나)" % nm, is_equal_approx(g._gauge_v(key), 0.75),
			"%.2f" % g._gauge_v(key))
	g._vol_save_due()
	_ok("%s — 휠 값도 저장된다" % nm, _disk(key) != null
			and is_equal_approx(float(_disk(key)), 0.75))
	_mouse(p0, true)
	_move(Vector2(tr.position.x - 30.0, tr.get_center().y))
	_mouse(Vector2(tr.position.x - 30.0, tr.get_center().y), false)
	_ok("%s — 왼끝까지 끌면 0 · 숨는다 · 저장" % nm, is_equal_approx(g._gauge_v(key), 0.0)
			and not lay.visible and _disk(key) != null and is_equal_approx(float(_disk(key)), 0.0))
	# ── 되읽기
	Save.set_set(key, 0.42)
	g._vol_set(key, 0.9)
	g._load_settings()
	_ok("%s — 저장한 값을 되읽어 층에 앉힌다" % nm, is_equal_approx(g._gauge_v(key), 0.42)
			and lay.visible and is_equal_approx(float(mat.get_shader_parameter("strength")), 0.42),
			"%.2f" % g._gauge_v(key))
	g.state = g.S.SHOP
	g.pause_from = -1
	# ── 개발자 판 — 굴곡 줄 밑
	var pg0 := Dev.page
	var hit := -1
	for pg in Dev.PAGES.size():
		Dev.page = pg
		var rs: Array = Dev._rows(g)
		var wi := -1
		var ki := -1
		for i in rs.size():
			var kk := String((rs[i] as Dictionary).get("k", ""))
			if kk == key:
				ki = i
			elif kk == "warp":
				wi = i
		if ki >= 0:
			hit = pg
			_ok("%s — 개발자 판 줄이 굴곡 밑 · 열아홉 줄 안" % nm, rs.size() <= 19
					and ki > wi and wi >= 0,
					"%d쪽 · %d번째 · 굴곡 %d · %d줄" % [pg, ki, wi, rs.size()])
			break
	_ok("%s — 개발자 판에 줄이 있다" % nm, hit >= 0)
	_ok("%s — 고르개가 안 빈다" % nm, Dev._names(key).size() == steps.size(),
			"%s" % [Dev._names(key)])
	var got := []
	var want := []
	for j in steps.size():
		Dev.pick[key] = j
		Dev._run(g, {"k": key})
		got.append(int(roundf(g._gauge_v(key) * 100.0)))
		want.append(int(roundf(float(steps[j]) * 100.0)))
	_ok("%s — 사다리가 같은 값을 민다 · 셋째가 기본값" % nm, got == want
			and is_equal_approx(float(steps[2]), def), "%s · 기본 %.2f" % [got, def])
	Dev.pick[key] = 0
	Dev._run(g, {"k": key})
	_ok("%s — 사다리 0 이면 숨는다" % nm, not lay.visible)
	g._vol_set(key, float(steps[3]))
	Dev.page = maxi(hit, 0)
	Dev._rows(g)
	_ok("%s — 값 칸이 지금 값에 맞는다" % nm, int(Dev.pick.get(key, -1)) == 3,
			Dev._cur_name(g, {"k": key}))
	Dev.page = pg0
	g._vol_set(key, def)
