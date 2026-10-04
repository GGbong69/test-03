extends SceneTree
#  누운 단추 · 판 ↔ 상점 덮개 촬영 (2026-10-04 · game.gd 의 SLAB · _clear_go · _shop_go).
#  shots/ 에:
#    slab_shop.png · slab_leg.png       상점 · 판 고르기 온 화면(1280x720)
#    slab_zoom.png                      단추 줄을 2배로 — 쉼 · 커서(상점), 쉼(판 고르기)
#    slab_chute.png                     창구 이름 「판매」 · 「구매」(카운터에 누운 글씨) 2배
#    wipe_shop_strip.png                정산 → 상점 덮개 여덟 박자
#    wipe_next_strip.png                상점 → 다음 판 덮개 여덟 박자
#  창이 있어야 돈다:  godot --path . --script scripts/tools/shot_slab.gd
#  시계는 손으로 민다(게임 _process 를 끄고 1/120 초씩) — 검사 도구라 덮개가 꺼져 뜨므로
#  wipe_force 로 켠다.
const Save = preload("res://scripts/save.gd")
const DT := 1.0 / 120.0
const WT := [0.10, 0.30, 0.40, 0.60, 0.70, 0.80, 0.95, 1.30]
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_slab_g.cfg"
	Save.path = "user://_shot_slab.cfg"
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


func _step(sec: float) -> void:
	var n: int = int(ceil(sec / DT))
	for k in n:
		_calm()
		g._process(DT)


func _shot() -> Image:
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _half(im: Image) -> Image:
	var c := im.duplicate() as Image
	c.resize(im.get_width() / 2, im.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	return c


#  논리 사각 r 을 기기 픽셀 그대로(1280 창이면 논리 2배) 잘라 낸다.
func _crop(im: Image, r: Rect2) -> Image:
	var s: float = float(im.get_width()) / 640.0
	return im.get_region(Rect2i(int(r.position.x * s), int(r.position.y * s),
			int(r.size.x * s), int(r.size.y * s)))


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
		var ci: Image = cells[i]
		sh.blit_rect(ci, Rect2i(0, 0, mini(cw, ci.get_width()), mini(ch, ci.get_height())),
				Vector2i((i % cols) * (cw + gap), (i / cols) * (ch + gap)))
	return sh


func _strip(nm: String) -> void:
	var cells := []
	var tt := 0.0
	for want in WT:
		while tt < float(want) - 0.0001:
			_calm()
			g._process(DT)
			tt += DT
		var im: Image = await _shot()
		cells.append(_half(im))
		print("  %s %.2f · state %d · wipe %.2f · 낙하 %.3f · 판 %.3f · 갈이 %s" % [nm, tt, g.state,
				g.wipe_t, g.drop_t, g.leg_t, g.swap_live])
	_sheet(cells, 4).save_png("res://shots/%s.png" % nm)


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
	g._new_run(true)
	g._tutor_close()
	g.tutor_q.clear()
	_step(1.5)
	await _wait(4)

	# ── 판 고르기 ──
	var im_leg: Image = await _shot()
	im_leg.save_png("res://shots/slab_leg.png")
	print("판 고르기 — state %d" % g.state)
	var zl: Image = _crop(im_leg, Rect2(0.0, 272.0, 640.0, 88.0))

	# ── 판 → 정산 → 상점(덮개) ──
	g._swap_skip()
	g._begin_leg()
	g._swap_skip()
	_step(0.5)
	g.total = g.target
	g.darts_left = 0
	g.remaining.clear()
	g._finish_leg()
	for k in 600:
		if g.state == g.S.CLEAR:
			break
		_calm()
		g._process(DT)
		g._swap_skip()
	print("정산 — state %d" % g.state)
	g.clear_t = 99.0
	_step(0.2)
	g._click(Vector2(-1.0, -1.0))
	await _strip("wipe_shop_strip")
	_step(2.0)
	g._tutor_close()
	g.tutor_q.clear()
	g.gold = 99
	_step(0.5)

	# ── 상점 단추 — 쉼 · 커서 · 누름 ──
	var im_shop: Image = await _shot()
	im_shop.save_png("res://shots/slab_shop.png")
	var row := Rect2(0.0, 272.0, 640.0, 88.0)
	var z0: Image = _crop(im_shop, row)
	g.ui_hov["btn:리롤"] = 1.0
	g.ui_hov["btn:다음 판 →"] = 1.0
	var z1: Image = _crop(await _shot(), row)
	g.ui_hov.clear()
	_sheet([z0, z1, zl], 1).save_png("res://shots/slab_zoom.png")
	#  창구 이름(누운 글씨) — 왼끝 「판매」 · 오른끝 「구매」.
	_sheet([_crop(im_shop, Rect2(0.0, 130.0, 150.0, 100.0)),
			_crop(im_shop, Rect2(490.0, 130.0, 150.0, 100.0))], 2).save_png("res://shots/slab_chute.png")

	# ── 상점 → 다음 판(덮개) ──
	g._click(g._next_rect().get_center())
	await _strip("wipe_next_strip")
	quit(0)
