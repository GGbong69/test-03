extends SceneTree
#  창 맞춤(2026-10-04 · project.godot 의 fractional · game.gd 의 _win_snap).
#  못 박는 것:
#    ① 어떤 창 크기든 화면이 창을 꽉 채운다(검은 띠 0) — 옛 integer 는 1279x720 에서 1배로
#       줄고 창 절반이 검었다.
#    ② 창 모드에서 16:9 를 벗어난 창은 크기가 멈추면 16:9 로 되맞춰지고 방 여백이 0 이 된다.
#       더 많이 바뀐 쪽을 지킨다.
#    ③ 이미 16:9 인 창은 안 건드린다.
#  커서 보기는 win_snap_force 가 건너뛴다(진짜 커서를 안 옮긴다).
#  창이 있어야 돈다:
#    godot --path . --script scripts/tools/qa_winfit.gd
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false
var ok := 0
var bad := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_winfit_g.cfg"
	Save.path = "user://_qa_winfit.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
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
	print("  %s %-40s %s" % ["통과" if cond else "실패", nm, note])


func _wait(n: int) -> void:
	for _i in n:
		await process_frame


func _ms(ms: int) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await process_frame


func _band() -> Vector2:
	var vr: Vector2 = root.get_visible_rect().size
	var sc: Vector2 = root.get_final_transform().get_scale()
	return Vector2(root.size) - vr * sc


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 잰다")
		quit(0)
		return
	print("① 꽉 채움(맞춤 끔)")
	for ws in [Vector2i(1280, 720), Vector2i(1279, 720), Vector2i(1366, 768), Vector2i(1500, 844),
			Vector2i(1000, 700), Vector2i(1700, 700), Vector2i(700, 400)]:
		root.size = ws
		await _wait(4)
		var b := _band()
		_ok("창 %dx%d 검은 띠" % [ws.x, ws.y], absf(b.x) < 1.5 and absf(b.y) < 1.5,
				"띠 %s · 논리 %s" % [str(b), str(root.get_visible_rect().size)])
	print("② · ③ 16:9 되맞춤(맞춤 켬)")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _wait(4)
	g.win_snap_force = true
	await _ms(300)
	_ok("16:9 창은 그대로", DisplayServer.window_get_size() == Vector2i(1280, 720),
			str(DisplayServer.window_get_size()))
	#  가로를 넓혔다 → 가로를 지키고 세로를 맞춘다.
	DisplayServer.window_set_size(Vector2i(1100, 700))
	await _ms(400)
	var a: Vector2i = DisplayServer.window_get_size()
	_ok("가로로 비튼 창 → 16:9", absf(float(a.x) / float(a.y) - 16.0 / 9.0) < 0.004, str(a))
	_ok("가로를 지킨다", a.x == 1100, str(a))
	await _wait(4)
	_ok("방 여백 0", g.view_pad == Vector2.ZERO, str(g.view_pad))
	#  세로를 늘였다 → 세로를 지키고 가로를 맞춘다.
	DisplayServer.window_set_size(Vector2i(1120, 720))
	await _ms(400)
	a = DisplayServer.window_get_size()
	_ok("세로로 비튼 창 → 16:9", absf(float(a.x) / float(a.y) - 16.0 / 9.0) < 0.004, str(a))
	_ok("세로를 지킨다", a.y == 720, str(a))
	await _wait(4)
	_ok("방 여백 0", g.view_pad == Vector2.ZERO, str(g.view_pad))
	_ok("검은 띠 0", _band().length() < 1.5, str(_band()))
	g.win_snap_force = false
	print("통과 %d · 실패 %d" % [ok, bad])
	quit(0)
