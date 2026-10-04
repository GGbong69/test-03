extends SceneTree
#  창 맞춤 비교 촬영(2026-10-04) — 같은 창 크기에서 두 길을 나란히 찍는다.
#    frac  비정수 배율로 창을 꽉 채운다
#    int   정수 배율(창 ÷ 내림 배율)로 찍고 남는 자리는 방을 더 보여 준다
#  shots/winfit_<창>_<길>.png. 창이 있어야 돈다:
#    godot --path . --script scripts/tools/shot_winfit.gd
const Save = preload("res://scripts/save.gd")
const DT := 1.0 / 120.0
const SIZES := [Vector2i(1500, 844), Vector2i(1366, 768)]
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_winfit_g.cfg"
	Save.path = "user://_shot_winfit.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	seed(20261004)


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


func _step(sec: float) -> void:
	var n: int = int(ceil(sec / DT))
	for k in n:
		g.idle_act = -1
		g.idle_wait = 99.0
		g.mouse_at = Vector2(-50.0, -50.0)
		g._process(DT)


func _shot() -> Image:
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _mode(ws: Vector2i, frac: bool) -> void:
	root.size = ws
	await _wait(3)
	if frac:
		root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
		root.content_scale_size = Vector2i(640, 360)
	else:
		var s: float = minf(float(ws.x) / 640.0, float(ws.y) / 360.0)
		var k: float = maxf(floorf(s), 1.0)
		root.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
		root.content_scale_size = Vector2i(int(float(ws.x) / k), int(float(ws.y) / k))
	await _wait(3)
	_step(0.05)


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 찍힌다")
		quit(0)
		return
	for id in ["u_leg", "u_skip", "u_boss", "u_score", "u_clear", "u_shop", "u_rack",
			"u_cons", "u_sell", "u_reroll", "u_give", "u_boot", "u_gift"]:
		Save.teach(id)
	g.set_process(false)
	g._new_run(true)
	g._tutor_close()
	g.tutor_q.clear()
	_step(1.5)
	for ws in SIZES:
		for frac in [true, false]:
			await _mode(ws, frac)
			var im: Image = await _shot()
			var nm := "winfit_%dx%d_%s" % [ws.x, ws.y, "frac" if frac else "int"]
			im.save_png("res://shots/%s.png" % nm)
			print("  %s · 그림 %dx%d · 논리 %s · 여백 %s" % [nm, im.get_width(), im.get_height(),
					str(root.get_visible_rect().size), str(g.view_pad)])
	quit(0)
