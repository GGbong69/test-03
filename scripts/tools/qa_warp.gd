extends SceneTree
# 화면 굴곡 · 입력 되짚기 검사 (2026-10-03)
#   「약간 발라트로 같이 그 화면의 왜곡? 그런건 못 넣어?」(사용자) — 굽힘을 발라트로만큼
#   키우는 대신 **포인터 자리를 전부 셰이더와 같은 식으로 되짚는다.** 화면 d 에 그려진
#   것은 원본 g(d) 이므로 d 를 누른 손은 g(d) 를 누른 것이다.
#
#   godot --headless --path . --script scripts/tools/qa_warp.gd     (①~⑧)
#   godot --path . --script scripts/tools/qa_warp.gd                (①~⑨ — ⑨ 은 창이 있어야)
#
#   ① 셰이더 글에 식이 그대로 있다(warp_src · warp_out 줄) · uniform 이 선다
#   ② 격자 점마다 game.gd 의 g(d) 가 셰이더 식을 GLSL 그대로 옮긴 계산과 1e-4 안이다
#   ③ 굴곡 0 은 **정확한** 항등 — 식 · _warp_v · 이벤트 길 · 층이 꺼졌을 때까지.
#      VHS 필터 · 도트 팔레트(층 98 · 97)는 입력을 되짚지 않는다 — 다 켜도 항등이다
#   ④ 꼴 — 가운데 · 변 가운데는 제자리 · 모서리는 바깥을 집는다 · 화면 모서리는 테 ·
#      원본은 둥근 모서리 말고는 다 보인다
#   ⑤ 단추가 굴곡을 지나 눌린다 — 상점의 「일시정지」 · 「리롤」 · 「다음 판」을 **화면에
#      그려진 자리**에서 진짜 이벤트로 누른다. 원본 자리를 그대로 누르면 빗나가는 점도 있다
#   ⑥ 테는 아무것도 안 누른다 — 「아무 데나 누르면 넘어가는」 말상자도 테에서는 안 넘어간다
#   ⑦ 움직임 · 휠이 같은 되짚기를 지난다(mouse_at = g(d) · 휠은 휘어 그려진 홈에서)
#   ⑧ 일시정지 › 설정 › 화면 › 「화면 굴곡」 게이지를 굴곡 위에서 끈다 — 끄는 동안 굽힘이
#      바뀌어도 손이 쥔 자리를 안 놓치고, 뗄 때 저장된다
#   ⑨ (창) GPU 가 그린 화면에서 셰이더가 실제로 따 온 자리를 읽어 g(d) 와 견준다 —
#      좌표를 색으로 적은 무늬를 깔고 굴곡 0 · 50 · 100 으로 찍어 화소마다 푼다.
#      VHS · 도트(2026-10-04) — 움직임 끔이면 멈춘 화면이 두 틀 같고 잔상이 쉰다 ·
#      VHS 100 의 행 밀림이 맨 밑 다섯 행 위에서 논리 1px 안이다(줄무늬를 깔고 행마다 잰다)
#
#   사람의 저장은 안 건드린다 — 전역 · 프로필 둘 다 도구 자리로 돌린다.
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const GPATH := "user://_qa_warp_g.cfg"
var g = null
var ok := 0
var bad := 0
var busy := false


func _initialize() -> void:
	Save.gpath = GPATH
	Save.path = "user://_qa_warp.cfg"
	#  기본값을 재려면 전역 파일이 비어 있어야 한다 — 지난 실행(⑧ 이 끈 값을 저장한다)이
	#  남긴 도구 파일을 지운다. 사람의 highton.cfg 는 이름부터 다르다(qa_crt 와 같은 규약).
	if FileAccess.file_exists(GPATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GPATH))
	Save.wipe()
	for r in GameData.tutor():
		var id := String(r.get("id", ""))
		if id != "":
			Save.teach(id)
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if g != null:
		g.set_process(false)
	if busy:
		return false
	busy = true
	_run()
	return false


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-46s %s" % ["통과" if cond else "실패", nm, note])


func _wait(n: int) -> void:
	for _i in n:
		await process_frame


# ── 셰이더 식을 GLSL 그대로 옮긴 것 ─────────────────────────
#  vec2 n = d / L * 2.0 - 1.0;
#  vec2 m = n + n * (n.yx * n.yx) * (warp_k * w);
#  return (m + 1.0) * 0.5 * L;
#  game.gd 의 _warp_src 를 **안 부르고** 성분마다 따로 셈한다 — 같은 함수를 두 번 부르면
#  무엇을 대 본 것인지가 없다. warp_k 는 셰이더에 앉은 값을 읽는다(넣는 쪽이 game.gd 라서).
func _ref(d: Vector2, L: Vector2, w: float, k: Vector2) -> Vector2:
	var nx: float = d.x / L.x * 2.0 - 1.0
	var ny: float = d.y / L.y * 2.0 - 1.0
	var yx := Vector2(ny, nx)                 # n.yx
	var sq := Vector2(yx.x * yx.x, yx.y * yx.y)
	var mx: float = nx + nx * sq.x * (k.x * w)
	var my: float = ny + ny * sq.y * (k.y * w)
	return Vector2((mx + 1.0) * 0.5 * L.x, (my + 1.0) * 0.5 * L.y)


#  g(d) = s 를 푸는 d — 화면에 그려진 자리. 셰이더는 앞으로만 미므로 역은 검사에서만 쓴다.
func _inv(s: Vector2) -> Vector2:
	var w: float = g._warp_live()
	if w <= 0.0:
		return s
	var L: Vector2 = g.get_viewport_rect().size
	var d := s
	for _k in 40:
		var f: Vector2 = g._warp_src(d, L, w) - s
		if f.length() < 1e-6:
			break
		var h := 0.01
		var g0: Vector2 = g._warp_src(d, L, w)
		var jx: Vector2 = (g._warp_src(d + Vector2(h, 0.0), L, w) - g0) / h
		var jy: Vector2 = (g._warp_src(d + Vector2(0.0, h), L, w) - g0) / h
		var det: float = jx.x * jy.y - jy.x * jx.y
		if absf(det) < 1e-9:
			break
		d -= Vector2((jy.y * f.x - jy.x * f.y) / det, (-jx.y * f.x + jx.x * f.y) / det)
	return d


#  진짜 이벤트 — 뷰포트 좌표 그대로 넣는다(사람의 손이 오는 자리).
func _btn(d: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = d
	g._unhandled_input(e)


func _tap(d: Vector2) -> void:
	_btn(d, true)
	_btn(d, false)


func _move(d: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = d
	e.relative = Vector2(1.0, 0.0)
	g._unhandled_input(e)


func _wheel(d: Vector2, up: bool) -> void:
	g.wheel_ms = 0
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	e.pressed = true
	e.position = d
	g._unhandled_input(e)


#  노드 좌표의 한 점 → 그것이 그려진 화면 자리(뷰포트).
func _at(p: Vector2) -> Vector2:
	return _inv(p + g.view_pad)


func _set_w(w: float) -> void:
	g.warp = w
	g._crt_apply()


func _calm() -> void:
	g.swap_live = false
	g.turn_live = false
	g.sweep_live = false
	g.boost_t = -1.0
	g.photo = ""
	g.photo_rack = ""
	g._tutor_close()
	g.tutor_q.clear()
	g.tutor_out = 0.0
	g.hand_st = g.H.NONE


func _shop() -> void:
	g._new_run()
	_calm()
	g.state = g.S.SHOP
	g.leg_no = 1
	g.gold = 40
	g._open_shop()
	for _i in 400:
		if not g._drop_busy():
			break
		g._process(1.0 / 60.0)
	_calm()
	g.pause_from = -1


func _run() -> void:
	for _i in 8:
		g._process(1.0 / 60.0)
	print("\n화면 굴곡 · 입력 되짚기 검사\n")
	var L: Vector2 = g.get_viewport_rect().size
	print("  보이는 논리 크기 %s · 여백 %s" % [L, g.view_pad])

	# ── ① 셰이더 글 ─────────────────────────────────────
	var sh = load(g.CRT_SHADER)
	var code: String = (sh as Shader).code if sh is Shader else ""
	_ok("셰이더가 읽힌다", code != "")
	var need := ["vec2 n = d / L * 2.0 - 1.0;",
			"vec2 m = n + n * (n.yx * n.yx) * (warp_k * w);",
			"return (m + 1.0) * 0.5 * L;",
			"src = warp_src(src, logical, warp);",
			"float dist = warp_out(src, logical, warp_rc * warp);",
			"float inb = clamp(0.5 - dist / fe, 0.0, 1.0);"]
	var miss := []
	for ln in need:
		if not code.contains(ln):
			miss.append(ln)
	_ok("셰이더 글에 g(d) · 테 식이 그대로 있다", miss.is_empty(), "빠짐 %s" % [miss])
	var names := PackedStringArray()
	if sh is Shader:
		for u in (sh as Shader).get_shader_uniform_list():
			names.append(String((u as Dictionary).get("name", "")))
	var miss2 := []
	for nm in ["warp", "warp_k", "warp_rc", "warp_fe", "warp_rim", "strength", "logical"]:
		if not names.has(nm):
			miss2.append(nm)
	_ok("굴곡 uniform 이 선다", miss2.is_empty(), "빠짐 %s" % [miss2])

	#  도구 실행은 굴곡 0 으로 뜬다 — 자리를 재는 프로브가 원본을 받는다.
	_ok("도구 실행은 굴곡 0 · CRT 0 으로 뜬다", is_equal_approx(g.warp, 0.0)
			and is_equal_approx(g.crt, 0.0) and not g.crt_layer.visible,
			"굴곡 %.2f · CRT %.2f" % [g.warp, g.crt])
	_ok("도구 실행은 VHS 0 · 도트 0 으로 뜬다 — 층이 숨었다", is_equal_approx(g.vhs, 0.0)
			and is_equal_approx(g.dot, 0.0) and not g.vhs_rect.visible and not g.dot_rect.visible,
			"VHS %.2f · 도트 %.2f" % [g.vhs, g.dot])
	g._load_settings()
	_ok("빈 저장의 기본 굴곡 50", is_equal_approx(g.warp, 0.5)
			and is_equal_approx(float(g.WARP_DEF), 0.5), "%.2f" % g.warp)
	_set_w(0.0)
	g.crt = 0.0
	g._crt_apply()

	# ── ② 격자 — game.gd 의 g(d) 와 셰이더 식 ───────────────
	var mat := g.crt_rect.material as ShaderMaterial
	for w in [0.25, 0.5, 1.0]:
		_set_w(float(w))
		var k: Vector2 = mat.get_shader_parameter("warp_k")
		var sw: float = float(mat.get_shader_parameter("warp"))
		var worst := 0.0
		var n := 0
		for iy in 19:
			for ix in 33:
				var d := Vector2(L.x * float(ix) / 32.0, L.y * float(iy) / 18.0)
				var a: Vector2 = g._warp_v(d)
				var b := _ref(d, L, sw, k)
				worst = maxf(worst, a.distance_to(b))
				n += 1
		_ok("굴곡 %d — 격자 %d점이 셰이더 식과 같다" % [int(w * 100.0), n], worst < 1e-4,
				"최대 차 %.6f px · 셰이더 warp %.2f · k %s" % [worst, sw, k])
	_ok("셰이더에 앉은 k · rc 가 game.gd 의 표 그대로", (mat.get_shader_parameter("warp_k")
			as Vector2).is_equal_approx(g.WARP.k)
			and is_equal_approx(float(mat.get_shader_parameter("warp_rc")), float(g.WARP.rc)))

	# ── ③ 굴곡 0 은 정확한 항등 ────────────────────────────
	_set_w(0.0)
	var exact := true
	var rng := RandomNumberGenerator.new()
	rng.seed = 1003
	for _i in 400:
		var d := Vector2(rng.randf_range(-20.0, L.x + 20.0), rng.randf_range(-20.0, L.y + 20.0))
		if g._warp_v(d) != d or not g._warp_hit(d):
			exact = false
	_ok("굴곡 0 — 400점이 비트까지 제자리 · 다 화면 안", exact)
	_ok("굴곡 0 — 식 자체도 제자리", (g._warp_src(Vector2(123.25, 77.5), L, 0.0) as Vector2)
			.is_equal_approx(Vector2(123.25, 77.5)))
	_set_w(0.003)
	_ok("굴곡 0.3 미만은 0 — 층이 그리지 않는 굽힘으로 안 되짚는다",
			g._warp_live() == 0.0 and g._warp_v(Vector2(3.0, 5.0)) == Vector2(3.0, 5.0))
	#  층이 꺼졌으면(셰이더를 못 읽은 자리) 굴곡 값이 있어도 되짚지 않는다.
	_set_w(0.5)
	g.crt_layer.visible = false
	_ok("층이 꺼졌으면 되짚지 않는다", g._warp_live() == 0.0
			and g._warp_v(Vector2(3.0, 5.0)) == Vector2(3.0, 5.0))
	_set_w(0.0)
	_move(Vector2(17.3, 211.9))
	_ok("굴곡 0 — 움직임 이벤트가 예전 그대로", g.mouse_at == Vector2(17.3, 211.9) - g.view_pad,
			"%s" % g.mouse_at)
	#  VHS · 도트를 끝까지 켜도 되짚기는 굴곡만 따른다 — 둘은 그림만 바꾼다.
	g.vhs = 1.0
	g.dot = 1.0
	g.crt = 1.0
	g._crt_apply()
	var same: bool = g.vhs_rect.visible and g.dot_rect.visible and g._warp_live() == 0.0
	for p in [Vector2(3.0, 5.0), Vector2(320.0, 357.0), L - Vector2(1.0, 1.0)]:
		if g._warp_v(p) != p or not g._warp_hit(p):
			same = false
	_move(Vector2(17.3, 211.9))
	_ok("VHS · 도트 100 · 굴곡 0 — 입력이 제자리", same
			and g.mouse_at == Vector2(17.3, 211.9) - g.view_pad, "%s" % g.mouse_at)
	g.vhs = 0.0
	g.dot = 0.0
	g.crt = 0.0
	g._crt_apply()

	# ── ④ 꼴 ─────────────────────────────────────────────
	_set_w(0.5)
	var c := L * 0.5
	_ok("가운데는 제자리", (g._warp_v(c) as Vector2).is_equal_approx(c))
	var mids := [Vector2(0.0, c.y), Vector2(L.x, c.y), Vector2(c.x, 0.0), Vector2(c.x, L.y)]
	var mid_ok := true
	for p in mids:
		if not (g._warp_v(p) as Vector2).is_equal_approx(p):
			mid_ok = false
	_ok("네 변 가운데는 제자리 — 변 가운데 HUD 가 안 잘린다", mid_ok)
	var near := Vector2(20.0, 20.0)
	var gn: Vector2 = g._warp_v(near)
	_ok("모서리 쪽은 바깥을 집는다", gn.x < near.x and gn.y < near.y, "%s → %s" % [near, gn])
	_ok("화면 모서리는 테다", not g._warp_hit(Vector2(1.0, 1.0))
			and not g._warp_hit(L - Vector2(1.0, 1.0)))
	_ok("한가운데 · 변 가운데 안쪽은 화면이다", g._warp_hit(c)
			and g._warp_hit(Vector2(2.0, c.y)) and g._warp_hit(Vector2(c.x, L.y - 2.0)))
	#  원본이 다 보이는가 — 원본 점마다 역을 풀어 화면 안에 서는지 본다(둥근 모서리 반지름 밖).
	var rc: float = float(g.WARP.rc) * 0.5
	var lost := 0
	for iy in 13:
		for ix in 21:
			var s := Vector2((L.x - 2.0 * rc) * float(ix) / 20.0 + rc,
					(L.y - 2.0 * rc) * float(iy) / 12.0 + rc)
			var d := _inv(s)
			if d.x < 0.0 or d.y < 0.0 or d.x > L.x or d.y > L.y \
					or (g._warp_v(d) as Vector2).distance_to(s) > 1e-3:
				lost += 1
	_ok("원본은 다 화면 안에 그려진다(모서리 반지름 밖)", lost == 0, "못 그려진 점 %d" % lost)
	var cn := _inv(Vector2(rc, rc))
	print("    원본 모서리(반지름 안쪽)가 그려진 화면 자리 %s — 굴곡이 들인 만큼" % cn.snapped(Vector2(0.1, 0.1)))

	# ── ⑤ 단추 — 그려진 자리를 진짜 이벤트로 ─────────────────
	_shop()
	_set_w(0.5)
	var hb: Rect2 = g._hud_btn_rect(1)
	var hd := _at(hb.get_center())
	_ok("「일시정지」가 그려진 자리는 원본에서 옮겨 앉았다",
			hd.distance_to(hb.get_center() + g.view_pad) > 3.0,
			"원본 %s → 화면 %s" % [hb.get_center() + g.view_pad, hd.snapped(Vector2(0.1, 0.1))])
	_tap(hd)
	_ok("굴곡 위의 「일시정지」를 누르면 일시정지가 열린다", g.state == g.S.SETTINGS
			and g.pause_from == g.S.SHOP and g._set_pg() == "pause",
			"state %d · 쪽 %s" % [g.state, g._set_pg()])
	g._settings_back()
	_ok("「계속하기」 문(뒤로)으로 상점에 돌아온다", g.state == g.S.SHOP)
	#  원본 자리를 **그대로** 누르면 빗나가는 점 — 「정보」 단추 오른쪽 위 모서리 안쪽.
	var ib: Rect2 = g._hud_btn_rect(0)
	var corner := ib.position + Vector2(ib.size.x - 3.0, 2.0)
	var flat_hits: bool = ib.has_point(g._warp_v(corner + g.view_pad) - g.view_pad) \
			and g._warp_hit(corner + g.view_pad)
	var warp_hits: bool = ib.has_point(g._warp_v(_at(corner)) - g.view_pad)
	_ok("굴곡을 안 되짚으면 빗나가는 점이 있다 · 되짚으면 맞는다", not flat_hits and warp_hits,
			"원본 자리를 누르면 %s · 그려진 자리를 누르면 %s" % [flat_hits, warp_hits])
	#  리롤 — 값이 나간다(굴린 횟수).
	var used0: int = g.rerolls_used
	var rd := _at(g._reroll_rect().get_center())
	_tap(rd)
	_ok("굴곡 위의 「리롤」이 눌린다", g.rerolls_used == used0 + 1,
			"굴린 횟수 %d → %d" % [used0, g.rerolls_used])
	for _i in 400:
		if not g.sweep_live and not g._drop_busy():
			break
		g._drop_update(0.02)
		g._process(1.0 / 60.0)
	_calm()
	var nd := _at(g._next_rect().get_center())
	_tap(nd)
	_ok("굴곡 위의 「다음 판」이 눌린다", g.state != g.S.SHOP, "state %d" % g.state)

	# ── ⑥ 테 ─────────────────────────────────────────────
	_shop()
	_set_w(0.5)
	var tid := ""
	for r in GameData.tutor():
		var tk := String(r.get("id", ""))
		if GameData.tutor_steps(tk).size() > 2:
			tid = tk
			break
	if tid != "":
		g.tutor_id = tid
		g.tutor_i = 0
		g.tutor_t = 9.0
		var bz := Vector2(1.0, 1.0)
		_btn(bz, true)
		_ok("테를 누르면 말상자가 안 넘어간다", g.tutor_i == 0 and not g.mouse_down,
				"걸음 %d · 눌림 %s" % [g.tutor_i, g.mouse_down])
		_btn(bz, false)
		_ok("짝인 뗌도 삼킨다", g.press_void == false and g.tutor_i == 0)
		g.tutor_t = 9.0
		_tap(_at(g._tutor_box().get_center()))
		_ok("화면 안을 누르면 넘어간다", g.tutor_i == 1, "걸음 %d" % g.tutor_i)
		g._tutor_close()
	else:
		_ok("세 걸음 넘는 설명이 있다", false)
	_calm()
	var st0: int = g.state
	_tap(L - Vector2(1.0, 1.0))
	_ok("테의 누름은 단추도 판도 안 누른다", g.state == st0)

	# ── ⑦ 움직임 · 휠 ─────────────────────────────────────
	var md := Vector2(37.0, 51.0)
	_move(md)
	_ok("움직임 — mouse_at 이 g(d)", (g.mouse_at as Vector2).is_equal_approx(
			_ref(md, L, 0.5, g.WARP.k) - g.view_pad), "%s" % g.mouse_at)
	_move(Vector2(0.5, 0.5))
	_ok("테 위의 커서는 원본 바깥을 가리킨다(아무것도 안 얹힌다)",
			not Rect2(-g.view_pad, L).has_point(g.mouse_at), "%s" % g.mouse_at)
	g._pause_open()
	g.set_t = 1.0
	g._set_go("sound")
	g.set_pg_t = 1.0
	g.set_sel = (g._set_rows() as Array).find("vol")
	g.set_hot = -1
	g.vol = 0.5
	var td := _at(g._vol_track().get_center())
	_wheel(td, true)
	_ok("휠 — 휘어 그려진 홈 위에서 굴리면 받는다", is_equal_approx(g.vol, 0.55), "%.2f" % g.vol)
	_wheel(Vector2(1.0, 1.0), true)
	_ok("휠 — 테에서 굴리면 안 받는다", is_equal_approx(g.vol, 0.55), "%.2f" % g.vol)
	g._vol_save_due()

	# ── ⑧ 화면 굴곡 게이지를 굴곡 위에서 끈다 ────────────────
	#  설정 창(2026-10-03 창 둘) — 탭은 단이 아니라 한 번 오르면 일시정지다.
	g._settings_back()                                # 소리 탭 › 일시정지
	_ok("설정 창에서 오르면 일시정지 · 「설정」 줄을 다시 집는다", g._set_pg() == "pause"
			and String(g._set_rows()[g.set_sel]) == "set")
	g.set_pg_t = 1.0
	_tap(_at(g._set_rect((g._set_rows() as Array).find("set")).get_center()))
	_ok("굴곡 위에서 「설정」을 누르면 화면 탭", g._set_pg() == "screen", g._set_pg())
	g.set_pg_t = 1.0
	#  줄의 이름 쪽을 누른다 — 홈 둘레가 아니라 고르기만 한다.
	var wr: Rect2 = g._set_rect((g._set_rows() as Array).find("warp"))
	_tap(_at(wr.position + Vector2(30.0, wr.size.y * 0.5)))
	_ok("「화면 굴곡」 줄을 고른다", String(g._set_rows()[g.set_sel]) == "warp"
			and g.set_drag == -1)
	g.set_hot = -1
	var tr: Rect2 = g._vol_track()
	var p0 := Vector2(tr.position.x + tr.size.x * 0.20, tr.get_center().y)
	var p1 := Vector2(tr.position.x + tr.size.x * 0.75, tr.get_center().y)
	_btn(_at(p0), true)                              # 굴곡 50 에서 그려진 20% 자리
	_ok("누르면 그 자리 — 20", is_equal_approx(g.warp, 0.2) and g.set_drag >= 0,
			"%.2f · drag %d" % [g.warp, g.set_drag])
	_ok("굴곡이 바뀌면 셰이더도 곧바로", is_equal_approx(
			float(mat.get_shader_parameter("warp")), 0.2))
	var d1 := _at(p1)                                # 이제 굴곡 20 에서 그려진 75% 자리
	_move(d1)
	_ok("끄는 동안 굽힘이 바뀌어도 손이 안 미끄러진다 — 75", is_equal_approx(g.warp, 0.75),
			"%.2f" % g.warp)
	_move(Vector2(L.x - 1.0, d1.y))                  # 오른쪽 테로 끌고 나간다
	_ok("테로 끌고 나가면 홈 끝(100)에 선다", is_equal_approx(g.warp, 1.0), "%.2f" % g.warp)
	_btn(Vector2(L.x - 1.0, d1.y), false)
	_ok("테에서 떼도 놓는다 · 저장된다", g.set_drag == -1
			and is_equal_approx(float(Save.get_set("warp", -1.0)), 1.0),
			"디스크 %s" % [Save.get_set("warp", -1.0)])
	g._settings_back()
	g._settings_back()
	_ok("ESC 문 둘로 판까지 오른다(설정 › 일시정지 › 판)", g.state == g.S.SHOP,
			"state %d" % g.state)

	# ── ⑨ GPU — 셰이더가 실제로 따 온 자리 ──────────────────
	if DisplayServer.get_name() == "headless":
		print("  (⑨ 건너뜀 — 창이 있어야 GPU 가 그린다)")
	else:
		await _gpu()
		await _gpu_retro()

	_set_w(0.0)
	print("\n통과 %d · 실패 %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


# ── ⑨ ───────────────────────────────────────────────────────
#  좌표를 색으로 적은 무늬: R = x/L · G = y/L(굵은 자리) · B = fract(x/8) 또는 fract(y/8)
#  (가는 자리 — 두 번 찍는다). 8비트라 굵은 자리는 ±1.3px 이고 가는 자리가 그것을 0.03px
#  로 좁힌다(굵은 오차가 반 주기 4px 보다 작아 어느 주기인지 안 헷갈린다). 가는 값이 감기는
#  자리(0 · 1 근처)는 날카로운 쌍선형이 두 이웃을 섞으므로 건너뛴다.
#  굴곡 0 은 게임이면 층이 꺼지지만, 여기서는 층을 **억지로 세워** 셰이더의 0 갈래(식을 안
#  지나는 길)가 정말 제자리를 집는지까지 잰다.
#  CRT 세기 0 · 테 그늘 0 으로 찍는다 — 셰이더가 따 온 값이 그대로 나온다. 셰이더는 기기
#  픽셀마다 따므로 읽은 자리는 기기 반 픽셀(2배 창에서 논리 0.25px) 안에서 맞아야 한다.
const PAT := """shader_type canvas_item;
uniform vec2 logical = vec2(640.0, 360.0);
uniform float axis = 0.0;
void fragment() {
	vec2 u = SCREEN_UV * logical;
	float f = axis < 0.5 ? fract(u.x / 8.0) : fract(u.y / 8.0);
	COLOR = vec4(u.x / logical.x, u.y / logical.y, f, 1.0);
}
"""


func _gpu() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _wait(12)
	g._crt_apply()
	var L: Vector2 = g.get_viewport_rect().size
	var lay := CanvasLayer.new()
	lay.layer = 99
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var shp := Shader.new()
	shp.code = PAT
	sm.shader = shp
	sm.set_shader_parameter("logical", L)
	rect.material = sm
	lay.add_child(rect)
	root.add_child(lay)
	var mat := g.crt_rect.material as ShaderMaterial
	print("  ⑨ 창 %s · 논리 %s" % [DisplayServer.window_get_size(), L])
	for w in [0.0, 0.5, 1.0]:
		g.crt = 0.0
		g.warp = float(w)
		g._crt_apply()
		var shown: bool = g.crt_layer.visible or w <= 0.0
		g.crt_layer.visible = true
		g.crt_rect.visible = true
		mat.set_shader_parameter("strength", 0.0)
		mat.set_shader_parameter("warp", float(w))
		mat.set_shader_parameter("logical", L)
		mat.set_shader_parameter("warp_rim", 0.0)
		var ims := []
		for ax in [0.0, 1.0]:
			sm.set_shader_parameter("axis", ax)
			await _wait(4)
			await RenderingServer.frame_post_draw
			ims.append(root.get_texture().get_image())
		var ia: Image = ims[0]
		var ib: Image = ims[1]
		var ppl: float = float(ia.get_height()) / L.y
		var worst := 0.0
		var n := 0
		var skip := 0
		var black := 0
		var black_ok := 0
		var wd := []
		for jy in 37:
			for jx in 65:
				var px := int(float(ia.get_width() - 1) * float(jx) / 64.0)
				var py := int(float(ia.get_height() - 1) * float(jy) / 36.0)
				var d := Vector2((float(px) + 0.5) / ppl, (float(py) + 0.5) / ppl)
				var want: Vector2 = g._warp_src(d, L, float(w)) if w > 0.0 else d
				var dist: float = g._warp_out(want, L, float(g.WARP.rc) * float(w))
				var ca: Color = ia.get_pixel(px, py)
				var cb: Color = ib.get_pixel(px, py)
				if w > 0.0 and dist > 2.0:
					#  테 — 검어야 한다
					black += 1
					if ca.r + ca.g + ca.b < 0.02:
						black_ok += 1
					continue
				if dist > -2.0:
					continue                     # 테를 녹이는 띠는 잴 자리가 아니다
				#  감기는 자리 ±0.08(= 0.64px) — 날카로운 쌍선형이 섞는 이웃은 기기 1px(논리 0.5)
				#  떨어져 있어 그 안이면 감김 너머의 값과 섞인다. 섞인 값은 감김 한가운데(0.5
				#  근처)로 나와 읽은 값으로는 못 거른다 — **바란 자리**의 가는 값으로 거른다
				#  (어느 점을 잴지만 고르고, 잰 값은 읽은 것 그대로 견준다).
				var wf := Vector2(fposmod(want.x / 8.0, 1.0), fposmod(want.y / 8.0, 1.0))
				if wf.x < 0.08 or wf.x > 0.92 or wf.y < 0.08 or wf.y > 0.92 						or ca.b < 0.08 or ca.b > 0.92 or cb.b < 0.08 or cb.b > 0.92:
					skip += 1
					continue
				var got := Vector2(_fine(ca.r * L.x, ca.b), _fine(cb.g * L.y, cb.b))
				if got.distance_to(want) > worst:
					worst = got.distance_to(want)
					wd = [d, want, got, ca, cb]
				n += 1
		var tol := 0.5 / ppl + 0.06
		_ok("GPU 굴곡 %d — %d점에서 따 온 자리가 g(d)" % [int(float(w) * 100.0), n],
				shown and n > 700 and worst <= tol,
				"최대 차 %.3f px(허용 %.3f) · 건너뜀 %d · 층 %s" % [worst, tol, skip, shown])
		if worst > tol and not wd.is_empty():
			print("    가장 먼 점 화면 %s · 바란 %s · 읽은 %s · 색 %s / %s" % wd)
		if w > 0.0:
			_ok("GPU 굴곡 %d — 테 자리 %d점이 검다" % [int(float(w) * 100.0), black],
					black > 0 and black_ok == black, "%d / %d" % [black_ok, black])
	lay.queue_free()
	g.warp = 0.0
	g._crt_apply()


#  굵은 자리(±1.3px)와 가는 자리(8px 주기의 비)로 한 자리를 푼다.
func _fine(coarse: float, f: float) -> float:
	var fx: float = f * 8.0
	var k: float = roundf((coarse - fx) / 8.0)
	return k * 8.0 + fx


# ── ⑨ VHS · 도트 ────────────────────────────────────────────
#  입력은 VHS 를 되짚지 않는다 — 그러니 그림이 논리 1px 넘게 옮겨 앉으면 안 된다. 헤드리스의
#  「입력이 제자리」는 _warp_v 가 VHS 를 안 보니 늘 맞는다. 여기서는 GPU 가 그린 화면을 잰다.
#  줄무늬: 논리 3px 폭 회색 띠가 해시로 켜지고 꺼진다(되풀이가 없어 밀림을 하나로 짚는다).
#  회색이라 VHS 의 색 번짐은 무늬를 안 옮긴다 — 밝기 가장자리만 본다.
const STRIPES := """shader_type canvas_item;
uniform vec2 logical = vec2(640.0, 360.0);
void fragment() {
	float c = floor(SCREEN_UV.x * logical.x / 3.0);
	float h = fract(sin(c * 12.9898) * 43758.5453);
	COLOR = vec4(vec3(h > 0.5 ? 0.85 : 0.15), 1.0);
}
"""


func _shot() -> Image:
	await _wait(4)
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _gpu_retro() -> void:
	var L: Vector2 = g.get_viewport_rect().size
	var mat := g.crt_rect.material as ShaderMaterial
	var vm := g.vhs_rect.material as ShaderMaterial
	var tr = g.crt_layer.get_node_or_null("CrtTrail")
	#  ① 움직임 — 트리를 멈추고 같은 화면을 두 번 찍는다. 끄면 화소까지 같아야 하고, 켜면
	#  갈려야 한다(갈리지 않으면 이 검사가 아무것도 못 잡는 것이다).
	var cases := [[0.0, true], [1.0, true], [1.0, false]]
	paused = true
	for cs in cases:
		var on: float = float(cs[0])
		g.motion_off = bool(cs[1])
		g.crt = on
		g.warp = 0.5 * on
		g.vhs = on
		g.dot = on
		g._crt_apply()
		vm.set_shader_parameter("clock", -1.0)
		await _wait(8)
		var a: Image = await _shot()
		await _wait(7)
		var b: Image = await _shot()
		var mx: float = float(a.compute_image_metrics(b, false).get("max", -1.0))
		if on <= 0.0:
			_ok("GPU 필터 끔 · 멈춘 화면 — 두 틀이 같다(밑그림이 안 움직인다)", mx == 0.0,
					"최대 차 %s" % mx)
		elif bool(cs[1]):
			_ok("GPU 움직임 끔 — CRT · VHS · 도트 100 · 굴곡 50 에서도 두 틀이 화소까지 같다",
					mx == 0.0, "최대 차 %s" % mx)
			_ok("GPU 움직임 끔 — 잔상이 쉰다(prev 비었다)", tr != null and not bool(tr.held)
					and mat.get_shader_parameter("prev") == null,
					"held %s · prev %s" % [tr.held if tr != null else null,
					mat.get_shader_parameter("prev")])
		else:
			_ok("GPU 움직임 켬 — 같은 화면이라도 틀마다 갈린다(위 검사가 잡을 수 있다)", mx > 0.0,
					"최대 차 %s" % mx)
			_ok("GPU 움직임 켬 — 잔상이 앞 틀을 쥔다", tr != null and bool(tr.held)
					and mat.get_shader_parameter("prev") != null, "err %s" % [tr.err if tr != null else null])
	paused = false
	g.motion_off = false
	#  ② VHS 100 의 행 밀림 — 줄무늬(층 96 · VHS 밑)를 VHS 0 과 100 으로 찍어 행마다 견준다.
	g.crt = 0.0
	g.warp = 0.0
	g.dot = 0.0
	g.vhs = 0.0
	g._crt_apply()
	var lay := CanvasLayer.new()
	lay.layer = 96
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var shp := Shader.new()
	shp.code = STRIPES
	sm.shader = shp
	sm.set_shader_parameter("logical", L)
	rect.material = sm
	lay.add_child(rect)
	root.add_child(lay)
	var a0: Image = await _shot()
	a0.convert(Image.FORMAT_RGBA8)
	var da := a0.get_data()
	var iw := a0.get_width()
	var ppl: float = float(a0.get_height()) / L.y
	#  재질에 안 앉힌 uniform 은 null 로 온다 — 셰이더 기본값을 읽는다.
	var hv = RenderingServer.shader_get_parameter_default(vm.shader.get_rid(), "hs_rows")
	var hs: int = int(hv) if hv != null else 5
	#  시계 넷 — 물결 · 떨림이 갈리는 서로 다른 틀.
	var worst := 0
	var bot := 0
	var rows_n := 0
	for clk in [0.5, 1.37, 2.164, 4.4]:
		g.vhs = 1.0
		g._crt_apply()
		vm.set_shader_parameter("clock", float(clk))
		var b0: Image = await _shot()
		b0.convert(Image.FORMAT_RGBA8)
		var db := b0.get_data()
		for r in int(L.y):
			var y := int((float(r) + 0.5) * ppl)
			var k := _row_shift(da, db, iw, y, int(ceilf(6.0 * ppl)))
			if r < int(L.y) - hs:
				worst = maxi(worst, absi(k))
				rows_n += 1
			elif r == int(L.y) - 1:
				bot = maxi(bot, absi(k))
	vm.set_shader_parameter("clock", -1.0)
	_ok("GPU VHS 100 — 맨 밑 %d행 위 %d행의 밀림이 논리 1px(기기 %d) 안" % [hs, rows_n,
			int(ppl)], worst <= int(ppl), "가장 큰 밀림 기기 %d px" % worst)
	_ok("GPU VHS 100 — 맨 밑 행은 헤드 스위칭으로 밀린다(재는 자가 밀림을 본다)",
			bot > int(ppl), "기기 %d px" % bot)
	lay.queue_free()
	g.vhs = 0.0
	g._crt_apply()


#  기기 행 y 의 밝기(0~255) — 화소를 하나씩 집으면 느려서 바이트(RGBA8)로 읽는다.
func _lum(d: PackedByteArray, w: int, y: int) -> PackedFloat32Array:
	var o := PackedFloat32Array()
	o.resize(w)
	var base := y * w * 4
	for x in w:
		var i := base + x * 4
		o[x] = 0.2126 * d[i] + 0.7152 * d[i + 1] + 0.0722 * d[i + 2]
	return o


#  b 가 a 를 몇 기기 px 민 것인지 — 밝기 차 합이 가장 작은 밀림(±m).
func _row_shift(da: PackedByteArray, db: PackedByteArray, w: int, y: int, m: int) -> int:
	var la := _lum(da, w, y)
	var lb := _lum(db, w, y)
	var best := 0
	var bs := INF
	for k in range(-m, m + 1):
		var sad := 0.0
		for x in range(m + 2, w - m - 2, 2):
			sad += absf(lb[x] - la[x + k])
		if sad < bs:
			bs = sad
			best = k
	return best
