extends SceneTree
#  일시정지 · 설정 갈래 · 화면 굴곡 촬영 (2026-10-03)
#  「약간 발라트로 같이 그 화면의 왜곡? 그런건 못 넣어? 또 지금 설정이 저기서 다
#  나열되기 보단 화면안에 전체화면, crt 필터 이렇게 좀 상위가 있으면 좋겠는데,
#  지금 게임안에서 esc를 누르면 일시정지가 되어야지 일시정지에 설정을 누르면
#  설정창이 되어야지 ㅇㅋ?」(사용자).
#  shots/ 에:
#    pause_menu.png       상점 위의 일시정지 — 「설정」 줄을 고른 채(판이 갈래 둘을 편다)
#    settings_top.png     설정 쪽 — 「화면」 줄(판이 안의 세 줄과 값을 편다)
#    settings_screen.png  화면 쪽 — 「화면 굴곡」 게이지
#    settings_sound.png   소리 쪽 — 「효과음」 게이지
#    title_settings.png   제목 → 설정(일시정지를 안 지난다)
#    warp_0.png · warp_50.png · warp_100.png   CRT 40 의 상점에 굴곡 0 · 50 · 100
#    warp_click.png       왼쪽 = 굴곡 50 의 화면에서 누른 자리(번호 고리),
#                         오른쪽 = 평평한 게임에서 그 누름이 닿는 자리(같은 번호 십자)
#  메뉴 넷은 **게임 기본값**(CRT 40 · 굴곡 50)으로 찍는다 — 처음 켠 사람이 보는 그대로.
#  사람의 저장은 안 건드린다. 모션을 끄고 찍는다(깜박임 · 낟알 · 밀려 듦이 안 끼게).
#  창이 있어야 돈다:  godot --path . --script scripts/tools/shot_pause.gd
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_pause_g.cfg"
	Save.path = "user://_shot_pause.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	seed(20261003)


func _process(_d: float) -> bool:
	if g != null:
		g.hover_live = false
		g.tip_pin = {}
		g.tip_a = 0.0
	if busy:
		return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for _i in n:
		await process_frame


func _calm() -> void:
	g.idle_act = -1
	g.idle_wait = 99.0
	g.npc_eye = 0.0


func _settle(n: int) -> void:
	for _i in n:
		await process_frame
		_calm()
		g._process(0.0)
		g._set_tick(1.0 / 60.0)
		g.queue_redraw()
		var fr = g.get_node_or_null("Front")
		if fr != null:
			fr.queue_redraw()
	await RenderingServer.frame_post_draw


#  띠가 다 쓸려 들 때까지(_row_ease 7f) 넉넉히 돌린다 — 반쯤 든 띠는 「고른 줄」로 안 읽힌다.
func _snap(nm: String) -> Image:
	await _settle(24)
	var im: Image = root.get_texture().get_image()
	im.save_png("res://shots/%s.png" % nm)
	print("  %s — %dx%d" % [nm, im.get_width(), im.get_height()])
	return im


func _look(crt: float, warp: float) -> void:
	g.crt = crt
	g.warp = warp
	g._crt_apply()


#  쪽의 줄을 **진짜 누름**으로 누른다 — 굴곡을 되짚는 길까지 같이 지난다.
#  줄의 원본 자리를 화면 자리로 되돌리는 것은 g 의 역(뉴턴 몇 걸음)이다.
func _press_row(key: String) -> void:
	var rows: Array = g._set_rows()
	var i := rows.find(key)
	if i < 0:
		print("  ⚠ 줄 없음 %s · %s" % [key, rows])
		return
	g.set_t = 1.0
	g.set_pg_t = 1.0
	var tgt: Vector2 = (g._set_rect(i) as Rect2).get_center() + g.view_pad
	var d := _inv(tgt)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = down
		e.position = d
		g._unhandled_input(e)


#  g(d) = s 를 푸는 d. 셰이더는 앞으로만 미므로 역은 촬영 · 검사에서만 쓴다.
func _inv(s: Vector2) -> Vector2:
	var w: float = g._warp_live()
	if w <= 0.0:
		return s
	var L: Vector2 = g.get_viewport_rect().size
	var d := s
	for _k in 30:
		var f: Vector2 = g._warp_src(d, L, w) - s
		if f.length() < 1e-5:
			break
		var h := 0.01
		var jx: Vector2 = (g._warp_src(d + Vector2(h, 0.0), L, w) - g._warp_src(d, L, w)) / h
		var jy: Vector2 = (g._warp_src(d + Vector2(0.0, h), L, w) - g._warp_src(d, L, w)) / h
		var det: float = jx.x * jy.y - jy.x * jx.y
		if absf(det) < 1e-9:
			break
		d -= Vector2((jy.y * f.x - jy.x * f.y) / det, (-jx.y * f.x + jx.x * f.y) / det)
	return d


func _shop() -> void:
	g.motion_off = true
	g._new_run()
	for r in GameData.tutor():
		var id := String(r.get("id", ""))
		if id != "":
			Save.teach(id)
	g._tutor_close()
	g.tutor_q.clear()
	g.state = g.S.SHOP
	g.leg_no = 1
	g.gold = 24
	g._open_shop()
	await _wait(200)
	g._tutor_close()
	g.tutor_q.clear()
	g.mouse_at = Vector2(-50.0, -50.0)
	g.set_process(false)
	await _settle(20)


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 찍힌다")
		quit(0)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _wait(12)
	await _shop()
	print("논리 %s · 여백 %s" % [g.get_viewport_rect().size, g.view_pad])

	#  ── 굴곡 셋 — CRT 40 의 상점 ─────────────────────────
	var flat: Image = null
	var w50: Image = null
	for w in [0.0, 0.5, 1.0]:
		_look(0.4, float(w))
		var im: Image = await _snap("warp_%d" % int(roundf(float(w) * 100.0)))
		if is_equal_approx(float(w), 0.5):
			w50 = im
	_look(0.0, 0.0)
	flat = await _snap("_warp_flat")

	#  ── 누른 자리 → 닿는 자리 ──────────────────────────
	_look(0.4, 0.5)
	_click_sheet(w50, flat)

	#  ── 메뉴 넷 — 기본값(CRT 40 · 굴곡 50) ──────────────
	_look(g.CRT_DEF, g.WARP_DEF)
	g._pause_open()
	g.set_t = 1.0
	g.set_sel = (g._set_rows() as Array).find("set")
	g.mouse_at = Vector2(-50.0, -50.0)
	await _snap("pause_menu")
	_press_row("set")
	g.mouse_at = Vector2(-50.0, -50.0)
	await _snap("settings_top")
	_press_row("screen")
	g.set_sel = (g._set_rows() as Array).find("warp")
	g.mouse_at = Vector2(-50.0, -50.0)
	await _snap("settings_screen")
	g._settings_back()
	_press_row("sound")
	g.mouse_at = Vector2(-50.0, -50.0)
	await _snap("settings_sound")
	g._settings_back()
	g._settings_back()
	g._settings_back()
	await _settle(30)

	#  ── 제목 → 설정 ─────────────────────────────────────
	g.state = g.S.TITLE
	g.pause_from = -1
	g.mouse_at = Vector2(-50.0, -50.0)
	await _settle(30)
	var trows: Array = g._title_rows()
	for i in trows.size():
		if String(trows[i].n) == "설정":
			var d := _inv((g._menu_rect(i) as Rect2).get_center() + g.view_pad)
			for down in [true, false]:
				var e := InputEventMouseButton.new()
				e.button_index = MOUSE_BUTTON_LEFT
				e.pressed = down
				e.position = d
				g._unhandled_input(e)
	g.set_t = 1.0
	g.mouse_at = Vector2(-50.0, -50.0)
	await _snap("title_settings")
	print("state %d · 쪽 %s · 줄 %s" % [g.state, g._set_pg(), g._set_rows()])
	quit(0)


#  왼쪽 = 굴곡 50 화면 위의 누른 자리(고리), 오른쪽 = 평평한 게임 위의 닿는 자리(십자).
#  같은 번호 · 같은 색이 같은 누름이다 — 두 자리 밑의 그림이 같은 물건이면 되짚기가 맞다.
func _click_sheet(warped: Image, flat: Image) -> void:
	if warped == null or flat == null:
		return
	var L: Vector2 = g.get_viewport_rect().size
	var s: float = float(warped.get_width()) / L.x
	var pts := [Vector2(18, 14), Vector2(320, 14), Vector2(622, 14),
			Vector2(18, 180), Vector2(320, 180), Vector2(622, 180),
			Vector2(18, 346), Vector2(320, 346), Vector2(622, 346),
			Vector2(600, 40), Vector2(40, 40), Vector2(600, 300), Vector2(4, 4)]
	var cols := [Color.RED, Color.ORANGE, Color.YELLOW, Color.LIME, Color.CYAN,
			Color.DODGER_BLUE, Color.MAGENTA, Color.WHITE, Color.HOT_PINK,
			Color.SPRING_GREEN, Color.GOLD, Color.VIOLET, Color.TOMATO]
	var a: Image = warped.duplicate()
	var b: Image = flat.duplicate()
	for i in pts.size():
		var d: Vector2 = pts[i]
		var col: Color = cols[i % cols.size()]
		var hit: bool = g._warp_hit(d)
		var src: Vector2 = g._warp_v(d)
		_ring(a, d * s, 9.0, col)
		if hit:
			_cross(b, src * s, 9.0, col)
		else:
			_ring(b, d * s, 5.0, Color(0.4, 0.4, 0.4))   # 테 — 아무것도 안 누른다
		print("  %2d  화면 %s → 게임 %s %s" % [i + 1, d, src.snapped(Vector2(0.1, 0.1)),
				"" if hit else "(테 — 안 누른다)"])
	var sh := Image.create(a.get_width() * 2 + 16, a.get_height(), false, a.get_format())
	sh.fill(Color(0.5, 0.5, 0.5))
	sh.blit_rect(a, Rect2i(Vector2i.ZERO, a.get_size()), Vector2i.ZERO)
	sh.blit_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(a.get_width() + 16, 0))
	sh.save_png("res://shots/warp_click.png")
	print("  warp_click — %dx%d" % [sh.get_width(), sh.get_height()])


func _dot(im: Image, x: int, y: int, col: Color) -> void:
	if x >= 0 and y >= 0 and x < im.get_width() and y < im.get_height():
		im.set_pixel(x, y, col)


func _ring(im: Image, c: Vector2, r: float, col: Color) -> void:
	for k in 180:
		var t: float = float(k) / 180.0 * TAU
		for dr in [-1.0, 0.0, 1.0]:
			var p: Vector2 = c + Vector2(cos(t), sin(t)) * (r + float(dr))
			_dot(im, int(p.x), int(p.y), col)


func _cross(im: Image, c: Vector2, r: float, col: Color) -> void:
	for k in range(-int(r), int(r) + 1):
		for t in [-1, 0, 1]:
			_dot(im, int(c.x) + k, int(c.y) + t, col)
			_dot(im, int(c.x) + t, int(c.y) + k, col)
