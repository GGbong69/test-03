extends SceneTree
#  장면 전환 덮개 · 게임 오버 연출 촬영 (2026-10-04 · game.gd 의 WIPE · OVERC 머리말).
#  shots/ 에:
#    wipe_strip.png   새 런 「시작」 → 판 고르기 — 덮개 여덟 박자(온 화면 절반 크기)
#    over_strip.png   진 판 → 게임 오버 — 다트판이 다가와 검어지고 결과 화면이 떠오른다(여덟 박자)
#  창이 있어야 돈다:  godot --path . --script scripts/tools/shot_scene.gd
#  시계는 손으로 민다(게임 _process 를 끄고 1/120 초씩) — 검사 도구라 연출이 꺼져 뜨므로
#  wipe_force · over_cine_force 로 켠다.
const Save = preload("res://scripts/save.gd")
const DT := 1.0 / 120.0
const WIPE_T := [0.06, 0.14, 0.22, 0.30, 0.40, 0.50, 0.70, 0.84]
const OVER_T := [0.10, 0.45, 0.70, 0.90, 1.05, 1.20, 1.45, 1.80]
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_scene_g.cfg"
	Save.path = "user://_shot_scene.cfg"
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


func _calm() -> void:
	g.idle_act = -1
	g.idle_wait = 99.0
	g.mouse_at = Vector2(-50.0, -50.0)


func _shot() -> Image:
	g.queue_redraw()
	var fr = g.get_node_or_null("Front")
	if fr != null:
		fr.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var im: Image = root.get_texture().get_image()
	im.resize(im.get_width() / 2, im.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	return im


func _sheet(cells: Array, cols: int) -> Image:
	var c0: Image = cells[0]
	var cw: int = c0.get_width()
	var ch: int = c0.get_height()
	var rows: int = (cells.size() + cols - 1) / cols
	var gap := 6
	var sh := Image.create(cw * cols + gap * (cols - 1), ch * rows + gap * (rows - 1), false,
			c0.get_format())
	sh.fill(Color.BLACK)
	for i in cells.size():
		sh.blit_rect(cells[i], Rect2i(0, 0, cw, ch),
				Vector2i((i % cols) * (cw + gap), (i / cols) * (ch + gap)))
	return sh


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 찍힌다")
		quit(0)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for id in ["u_leg", "u_skip", "u_boss", "u_score", "u_clear", "u_shop", "u_rack",
			"u_cons", "u_sell", "u_reroll", "u_give", "u_boot", "u_gift"]:
		Save.teach(id)
	g.set_process(false)
	g.wipe_force = true
	g.over_cine_force = true

	# ── 덮개 — 새 런 「시작」 ──
	g._open_newrun()
	for k in 30:
		_calm()
		g._process(DT)
	await _wait(4)
	g._wipe(g._new_run.bind(true))
	var cells := []
	var tt := 0.0
	for want in WIPE_T:
		while tt < float(want) - 0.0001:
			_calm()
			g._process(DT)
			tt += DT
		cells.append(await _shot())
		print("  덮개 %.2f · state %d · wipe_t %.2f" % [tt, g.state, g.wipe_t])
	_sheet(cells, 4).save_png("res://shots/wipe_strip.png")
	for k in 120:
		_calm()
		g._process(DT)

	# ── 게임 오버 ──
	g._swap_skip()
	g._begin_leg()
	g._swap_skip()
	for k in 30:
		_calm()
		g._process(DT)
	g.state = g.S.PICK
	g.total = 0
	g.darts_left = 0
	g.remaining.clear()
	for k in 10:
		_calm()
		g._process(DT)
	await _wait(4)
	g._finish_leg()
	print("게임 오버 연출 — over_cine %.2f · state %d" % [g.over_cine, g.state])
	cells.clear()
	tt = 0.0
	for want in OVER_T:
		while tt < float(want) - 0.0001:
			_calm()
			g._process(DT)
			tt += DT
		cells.append(await _shot())
		print("  오버 %.2f · state %d · cine %.2f" % [tt, g.state, g.over_cine])
	_sheet(cells, 4).save_png("res://shots/over_strip.png")
	quit(0)
