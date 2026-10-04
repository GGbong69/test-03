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
#    ⑤ 판에서 벽을 짓고, settle 틀 뒤에는 굽기를 멈춘다(매 틀 안 굽는다)
#    ⑥ 화판의 한가운데가 BC 이고 여백까지 덮는다 · 화판 크기 = 논리 크기 × 창 배율
#    ⑦ 판 테가 바뀌면 다시 굽고 링이 따라간다
#    ⑧ 창이 16:10 으로 바뀌면 다시 맞춰 여백까지 덮는다
#    ⑨ 화면 픽셀 — 판 옆 판자 자리가 켜면 C_BG 가 아니고 끄면 C_BG 다
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
	await _tick(20)
	_ok("판이 도는 동안에도 멈춰 있다", vp.render_target_update_mode == SubViewport.UPDATE_DISABLED)
	_ok("벽이 깔린다(_wall3_live)", g._wall3_live())

	# ── ⑥ 자리 · 크기 ──
	var r: Rect2 = g._wall3_rect()
	_ok("화판 한가운데가 BC", r.get_center().distance_to(g.BC) < 0.01, str(r.get_center()))
	_ok("화판이 여백까지 덮는다", r.encloses(g._full()), "%s ⊇ %s" % [r, g._full()])
	var k: int = g._wall3_k()
	_ok("화판 크기 = 논리 크기 × 창 배율",
			vp.size == Vector2i(roundi(r.size.x * k), roundi(r.size.y * k)),
			"%s · 배율 %d" % [vp.size, k])

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
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _wait(4)
	_end()


func _end() -> void:
	print("통과 %d · 실패 %d" % [ok, bad])
	quit(1 if bad > 0 else 0)
