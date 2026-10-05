extends SceneTree
#  팩 촬영(2026-10-06 「일단 지금 다른 아이템에 비해 팩의 퀄리티가 그대로 잖아?」).
#  shots/ 에:
#    packs_shop.png      상점 테이블 — 작은 팩 · 큰 팩 · 동전 · 사진(1280x720 · 기본 필터)
#    packs_shop2.png     작은 팩 · 사탕 · 동전 · 다트
#    packs_zoom.png      위 둘의 테이블 띠를 2배로
#    packs_open.png      팩 열기 화면(큰 팩)
#  창이 있어야 돈다:  godot --path . --script scripts/tools/shot_packs.gd
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
const DT := 1.0 / 120.0
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_packs_g.cfg"
	Save.path = "user://_shot_packs.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	seed(20261006)


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
	for k in int(ceil(sec / DT)):
		g.idle_act = -1
		g.idle_wait = 99.0
		g.mouse_at = Vector2(-50.0, -50.0)
		g._process(DT)


func _shot() -> Image:
	g.queue_redraw()
	for k in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _row(rows: Array, id: String) -> Dictionary:
	for r in rows:
		if String(r.id) == id:
			return r
	return rows[0]


func _put(kinds: Array) -> void:
	for i in mini(kinds.size(), g.stock.size()):
		var k: Array = kinds[i]
		var d: Dictionary = {}
		match String(k[0]):
			"boost": d = _row(GameData.boosters(), String(k[1]))
			"item": d = GameData.items()[3]
			"cons": d = GameData.candies()[0]
			"fix": d = GameData.fixtures()[0]
			"dart": d = GameData.darts()[1]
		g.stock[i] = {"type": String(k[0]), "d": d, "sold": false,
				"cost": int((g.stock[i] as Dictionary).get("cost", 4))}
	_step(0.3)


func _run() -> void:
	await _wait(10)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for id in ["u_leg", "u_skip", "u_boss", "u_score", "u_clear", "u_shop", "u_rack",
			"u_cons", "u_sell", "u_reroll", "u_give", "u_boot", "u_gift"]:
		Save.teach(id)
	g.set_process(false)
	g._new_run(true)
	g._tutor_close()
	g.tutor_q.clear()
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
		_step(DT)
		g._swap_skip()
	g.clear_t = 99.0
	_step(0.2)
	g._clear_go()
	_step(2.5)
	g._tutor_close()
	g.tutor_q.clear()
	g.gold = 99
	g.crt = g.CRT_DEF
	g.warp = g.WARP_DEF
	g.vhs = g.VHS_DEF
	g.dot = g.DOT_DEF
	g._crt_apply()
	_put([["boost", "b_small"], ["boost", "b_big"], ["item", ""], ["fix", ""]])
	var a: Image = await _shot()
	a.save_png("res://shots/packs_shop.png")
	_put([["boost", "b_small"], ["cons", ""], ["item", ""], ["dart", ""]])
	var b: Image = await _shot()
	b.save_png("res://shots/packs_shop2.png")
	var za := a.get_region(Rect2i(160, 300, 960, 260))
	var zb := b.get_region(Rect2i(160, 300, 960, 260))
	var z := Image.create(960, 526, false, za.get_format())
	z.blit_rect(za, Rect2i(0, 0, 960, 260), Vector2i(0, 0))
	z.blit_rect(zb, Rect2i(0, 0, 960, 260), Vector2i(0, 266))
	z.resize(1920, 1052, Image.INTERPOLATE_NEAREST)
	z.save_png("res://shots/packs_zoom.png")
	#  팩 열기 — 큰 팩
	g._boost_deal(_row(GameData.boosters(), "b_big"))
	_step(1.2)
	var c: Image = await _shot()
	c.save_png("res://shots/packs_open.png")
	print("state ", g.state)
	quit(0)
