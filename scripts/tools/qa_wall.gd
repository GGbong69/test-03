extends SceneTree
#  다트판 벽 검사 (2026-10-04 · game.gd WALL3 · scripts/wall3d.gd).
#  헤드리스로도 · 창으로도 돈다:
#    godot --headless --path . --script scripts/tools/qa_wall.gd
#    godot --path . --script scripts/tools/qa_wall.gd
#  어디서나:
#    ① 개발자 5쪽(조작감 — 「3D 방」 줄과 같은 쪽)에 「다트판 벽」 줄이 판 안에 그려지고,
#       누르면 켬 · 끔이 바뀐다
#    ② 벽이 서는 화면 — 판 · 런 정보 · 정산 · 판 갈이는 참, 제목 · 판 고르기 · 상점은 거짓
#    ③ 꽂이 구멍 자리(_grip_base)가 자루 판정 상자의 한가운데와 같다(판정은 그대로다)
#  헤드리스면:
#    ④ 벽을 안 짓는다(렌더러가 없다 — 판 내내 wall3_vp 가 비어 있다)
#  창이 있으면:
#    ⑤ 제목에는 안 짓고 판 고르기에서 미리 짓는다 · settle 틀 뒤에는 굽기를 멈춘다(매 틀 안 굽는다)
#       · 다 구우면 그림 한 장(wall3_tex)만 쥐고 화판은 2px 로 놓는다(렌더 버퍼 VRAM)
#    ⑥ 화판의 한가운데가 BC(반 픽셀 안)이고 여백까지 덮는다 · 한 텍셀 = 창 한 픽셀(비정수 배율)
#    ⑦ 판 테가 바뀌면 다시 굽고 링이 따라간다
#    ⑧ 창이 16:10 으로 바뀌면 다시 맞춰 여백까지 덮는다 · HUD 띠 위 여백이 C_PANEL 판때기가 아니다
#    ⑨ 화면 픽셀 — 판 옆 판자 자리가 켜면 C_BG 가 아니고 끄면 C_BG 다
#    ⑩ 정산 → 상점 판 갈이 첫 틀이 정산 그림과 같다(글자 · HUD 밖 열네 점)
#    ⑪ 판 갈이 첫 틀에는 꽂이를 안 그리고(테이블이 덮고 있다) 테이블이 비켜나면 그린다
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")
const Wall3D = preload("res://scripts/wall3d.gd")
const DT := 1.0 / 60.0
var g = null
var busy := false
var ok := 0
var bad := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_wall_g.cfg"
	Save.path = "user://_qa_wall.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


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
	print("  %s %-44s %s" % ["통과" if cond else "실패", nm, note])


func _wait(n: int) -> void:
	for _i in n:
		await process_frame


#  게임 시계를 한 틀씩 — 틀마다 실제로 그려지게 기다린다(굽기는 그려진 틀로 센다).
func _tick(n: int) -> void:
	for _i in n:
		g.mouse_at = Vector2(-50.0, -50.0)
		g._tutor_close()
		g.tutor_q.clear()
		g._process(DT)
		await process_frame


func _open() -> void:
	g.state = g.S.TITLE
	g._new_run()
	g._click(g._leg_go().get_center())
	for _k in 60:
		g._process(DT)
	g._swap_skip()


func _find(label: String) -> int:
	var rows: Array = Dev._rows(g)
	for i in rows.size():
		if String(rows[i].get("n1", "")) == label:
			return i
	return -1


func _px(im: Image, p: Vector2) -> Color:
	var s: Vector2 = root.get_final_transform().get_scale()
	var q: Vector2 = (p + g.view_pad) * s
	return im.get_pixel(int(q.x), int(q.y))


func _run() -> void:
	await _wait(6)
	var win: bool = DisplayServer.get_name() != "headless"
	if win:
		DisplayServer.window_set_size(Vector2i(1280, 720))
		await _wait(6)
		# ── ⑤ 앞 — 제목에는 안 짓고, 판 고르기에서 미리 짓는다 ──
		await _tick(2)
		_ok("제목에서는 벽을 안 짓는다", g.wall3_vp == null, "state %d" % g.state)
		g.state = g.S.TITLE
		g._new_run()
		await _tick(2)
		_ok("판 고르기에서 미리 짓는다(판 갈이 첫 틀에 구워져 있다)",
				g.wall3_vp != null and g._wall3_live(), "state %d" % g.state)
	_open()
	print("판 — state %d · 창 %s" % [g.state, win])

	# ── ① 개발자 줄 ──
	Dev.page = 5
	var i0 := _find("다트판 벽 켬")
	_ok("조작감 쪽(5)에 「다트판 벽 켬」 줄이 있다", i0 >= 0, "줄 %d" % i0)
	if i0 >= 0:
		_ok("그 줄이 판 안에 그려진다", Dev._panel().encloses(Dev._row(i0)), str(Dev._row(i0)))
		Dev._run(g, Dev._rows(g)[i0])
		_ok("누르면 끈다", not g.wall3_on, "wall3_on %s" % g.wall3_on)
		_ok("줄 이름이 지금 값을 적는다", _find("다트판 벽 끔") == i0)
		Dev._run(g, Dev._rows(g)[i0])
		_ok("한 번 더 누르면 켠다", g.wall3_on)

	# ── ② 벽이 서는 화면 ──
	var s0: int = g.state
	_ok("판(던지는 화면)에 선다", g._wall3_here(), "state %d" % s0)
	g.state = g.S.RUNINFO
	g.run_from = s0
	_ok("런 정보(판 위)에 선다", g._wall3_here())
	g.state = g.S.CLEAR
	_ok("정산에 선다", g._wall3_here())
	for sx in [["제목", g.S.TITLE], ["판 고르기", g.S.LEG], ["상점", g.S.SHOP]]:
		g.state = int(sx[1])
		_ok("%s에는 안 선다" % String(sx[0]), not g._wall3_here())
	g.state = g.S.SHOP
	g.swap_live = true
	_ok("판 갈이에는 선다(상점으로 돌아가는 쪽도)", g._wall3_here())
	g.swap_live = false
	g.state = s0

	# ── ③ 꽂이 구멍 = 판정 상자 한가운데 ──
	var worst := 0.0
	for i in (g.remaining as Array).size():
		var slot: int = g.grip_slot[i] if i < (g.grip_slot as Array).size() else i
		var d: float = (g._grip_pose(i).hit as Rect2).get_center().distance_to(g._grip_base(slot))
		worst = maxf(worst, d)
	_ok("구멍 자리가 자루 판정 상자 한가운데다", worst < 0.001,
			"자루 %d · 어긋남 %.4f" % [(g.remaining as Array).size(), worst])

	if not win:
		# ── ④ 헤드리스는 안 짓는다 ──
		for _k in 30:
			g._process(DT)
		_ok("헤드리스는 벽을 안 짓는다", g.wall3_vp == null)
		_ok("헤드리스는 옛 그림 그대로다(_wall3_live 거짓)", not g._wall3_live())
		_end()
		return

	# ── ⑤ 짓고 · 굽고 · 멈춘다 ──
	await _tick(2)
	_ok("판에서 벽을 짓는다", g.wall3_vp != null)
	var st: int = int(g.WALL3.settle)
	await _tick(st + 4)
	var vp: SubViewport = g.wall3_vp
	_ok("굽기가 끝나면 멈춘다(매 틀 안 굽는다)",
			vp.render_target_update_mode == SubViewport.UPDATE_DISABLED and g.wall3_fresh == 0,
			"mode %d · 남은 틀 %d" % [vp.render_target_update_mode, g.wall3_fresh])
	_ok("다 구우면 그림 한 장만 쥐고 화판을 놓는다",
			g.wall3_tex != null and vp.size == Vector2i(2, 2)
					and Vector2i(g.wall3_tex.get_size()) == g.wall3_px,
			"화판 %s · 그림 %s" % [vp.size, g.wall3_tex.get_size() if g.wall3_tex != null else Vector2.ZERO])
	await _tick(20)
	_ok("판이 도는 동안에도 멈춰 있다", vp.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	_ok("벽이 깔린다(_wall3_live)", g._wall3_live())

	# ── ⑥ 자리 · 크기 ──
	var r: Rect2 = g._wall3_rect()
	var sc: float = root.get_final_transform().get_scale().x
	var cd: Vector2 = (r.get_center() - g.BC).abs()
	_ok("화판 한가운데가 BC(창 반 픽셀 안)", cd.x <= 0.5 / sc + 0.001 and cd.y <= 0.5 / sc + 0.001,
			"%s · 배율 %.3f" % [r.get_center(), sc])
	_ok("화판이 여백까지 덮는다", r.encloses(g._full()), "%s ⊇ %s" % [r, g._full()])
	_ok("한 텍셀 = 창 한 픽셀", _texel_ok(r, sc), "%s · 배율 %.3f / %.3f" % [g.wall3_px, sc, g.wall3_kf])

	# ── ⑦ 판 테가 바뀌면 ──
	var r0: float = g.R
	g.R = r0 * 1.1
	await _tick(1)
	_ok("판 테가 바뀌면 다시 굽는다", g.wall3_fresh > 0, "남은 틀 %d" % g.wall3_fresh)
	var ring: MeshInstance3D = vp.get_node("Wall/Ring")
	var want: float = (g._wall3_ro() - 1.0) / Wall3D.S
	_ok("링 안쪽 끝이 판 테 밑 1px", absf((ring.mesh as TorusMesh).inner_radius - want) < 0.0001,
			"%.4f / %.4f" % [(ring.mesh as TorusMesh).inner_radius, want])
	g.R = r0
	await _tick(st + 4)

	# ── ⑨ 화면 픽셀 ──
	g.queue_redraw()
	await RenderingServer.frame_post_draw
	var im: Image = root.get_texture().get_image()
	var probe := Vector2(g.BC.x + 168.0, g.BC.y + 40.0)      # 링 바깥 판자 — 판 · HUD · 다트 줄 밖
	var c_on := _px(im, probe)
	g.wall3_on = false
	await _tick(2)
	g.queue_redraw()
	await RenderingServer.frame_post_draw
	im = root.get_texture().get_image()
	var c_off := _px(im, probe)
	g.wall3_on = true
	var bg: Color = g.C_BG
	var d_on: float = Vector3(c_on.r - bg.r, c_on.g - bg.g, c_on.b - bg.b).length()
	var d_off: float = Vector3(c_off.r - bg.r, c_off.g - bg.g, c_off.b - bg.b).length()
	_ok("켜면 판 옆이 판자다(C_BG 가 아니다)", d_on > 0.08, "%s · 거리 %.3f" % [c_on.to_html(false), d_on])
	_ok("끄면 옛 C_BG 다", d_off < 0.03, "%s · 거리 %.3f" % [c_off.to_html(false), d_off])

	# ── ⑧ 16:10 ──
	DisplayServer.window_set_size(Vector2i(1440, 900))
	await _wait(6)
	g._view_fit()
	await _tick(st + 4)
	r = g._wall3_rect()
	_ok("16:10 — 여백이 생긴다", g.view_pad.y > 0.0, str(g.view_pad))
	_ok("16:10 — 화판이 여백까지 덮는다", r.encloses(g._full()), "%s ⊇ %s" % [r, g._full()])
	_ok("16:10 — 다시 굽고 멈췄다", vp.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	sc = root.get_final_transform().get_scale().x
	_ok("16:10 — 한 텍셀 = 창 한 픽셀(배율 %.2f)" % sc, _texel_ok(r, sc), str(g.wall3_px))
	g.queue_redraw()
	await RenderingServer.frame_post_draw
	im = root.get_texture().get_image()
	var pan: Color = g.C_PANEL
	var far := 0.0
	for x in [60.0, 200.0, 320.0, 440.0, 580.0]:
		var c := _px(im, Vector2(x, -g.view_pad.y * 0.5))
		far = maxf(far, Vector3(c.r - pan.r, c.g - pan.g, c.b - pan.b).length())
	_ok("16:10 — HUD 띠 위 여백이 판때기(C_PANEL)가 아니라 벽이다", far > 0.02, "가장 먼 거리 %.3f" % far)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _wait(6)
	g._view_fit()
	await _tick(st + 4)

	# ── ⑪ 판 갈이의 꽂이 ──
	g.state = g.S.LEG
	g.swap_live = true
	g.swap_in = true
	g.swap_t = 0.0
	_ok("판 갈이 첫 틀 — 꽂이를 안 그린다(테이블이 덮고 있다)", not g._wall3_holder_free())
	g.swap_t = 0.03
	_ok("테이블이 비켜나면 꽂이가 벽에 있다", g._wall3_holder_free(), "gone %.2f" % g._swap_gone())
	g.swap_live = false
	g.swap_t = 0.0
	g.state = s0

	# ── ⑩ 정산 → 상점 판 갈이 첫 틀 = 정산 ──
	g._brk_skip()
	g.total = g.target
	g.darts_left = 0
	g.remaining.clear()
	g._finish_leg()
	var guard := 0
	while g.state != g.S.CLEAR and guard < 900:
		g.mouse_at = Vector2(-50.0, -50.0)
		g._tutor_close()
		g.tutor_q.clear()
		g._process(DT)
		g._swap_skip()
		guard += 1
	g.clear_t = 99.0
	await _tick(st + 4)
	g.queue_redraw()
	await RenderingServer.frame_post_draw
	var ia: Image = root.get_texture().get_image()
	g._click(Vector2(-1.0, -1.0))
	_ok("정산 → 상점이 판 갈이(나가는 쪽)로 간다", g.swap_live and not g.swap_in, "state %d" % g.state)
	g.queue_redraw()
	await RenderingServer.frame_post_draw
	var ib: Image = root.get_texture().get_image()
	var wd := 0.0
	var at := ""
	var ro: float = g._wall3_ro()
	for p in [Vector2(40, 100), Vector2(40, 250), Vector2(600, 100), Vector2(600, 250),
			Vector2(110, 330), Vector2(530, 330), Vector2(170, 104), Vector2(470, 104),
			Vector2(170, 116), Vector2(470, 116), Vector2(220, 256), Vector2(420, 256),
			g.BC + Vector2(ro * 0.72, ro * 0.72), g.BC + Vector2(-ro * 0.72, ro * 0.72)]:
		var ca := _px(ia, p)
		var cb := _px(ib, p)
		var d: float = Vector3(ca.r - cb.r, ca.g - cb.g, ca.b - cb.b).length()
		if d > wd:
			wd = d
			at = "%s %s/%s" % [p, ca.to_html(false), cb.to_html(false)]
	_ok("판 갈이 첫 틀이 정산 그림과 같다(턱 위 띠 · 판 자리 · 양옆)", wd < 0.02, "가장 먼 %.3f · %s" % [wd, at])
	g._swap_skip()
	_end()


#  화판 한 텍셀이 창의 정수 픽셀에 앉는가 — 화판 크기(px) × (창 배율 / 굽는 배율) 가 화면에서
#  차지하는 픽셀 수와 같고, 그 몫이 정수다.
func _texel_ok(r: Rect2, sc: float) -> bool:
	var n: float = sc / float(g.wall3_kf)
	var px := Vector2(g.wall3_px)
	return absf(r.size.x * sc - px.x * n) < 0.01 and absf(r.size.y * sc - px.y * n) < 0.01 \
			and absf(n - roundf(n)) < 0.001


func _end() -> void:
	print("통과 %d · 실패 %d" % [ok, bad])
	quit(1 if bad > 0 else 0)
