extends SceneTree
#  팩 남은 것 부수기 촬영 (2026-10-06) — 고르고 남은 것을 상인이 부순다(game.gd CRUSH 머리말).
#  shots/ 에:
#    crush_small_strip.png  작은 팩 — 하나를 고르면 주먹이 남은 것 위로 내리친다(여덟 박자 · 2배)
#    crush_big_strip.png    큰 팩 — 테이블을 내리치고 남은 셋이 떴다가 떨어지며 부서진다(열 박자)
#    crush_small_hit.png · crush_big_air.png  그 박자의 온 화면(2배 그대로)
#  창이 있어야 돈다:
#    godot --path . --script scripts/tools/shot_crush.gd
#  게임 시계를 손으로 민다 — 게임 노드의 _process 를 끄고 1/120 초씩 부른다(shot_prop 과 같다).
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
const CROP := Rect2(150.0, 30.0, 400.0, 230.0)
const SMALL_T := [0.0, 0.12, 0.24, 0.31, 0.34, 0.42, 0.58, 0.90]
const BIG_T := [0.0, 0.24, 0.32, 0.42, 0.56, 0.68, 0.76, 0.82, 0.90, 1.10]
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_crush_g.cfg"
	Save.path = "user://_shot_crush.cfg"
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


func _calm() -> void:
	g.idle_act = -1
	g.idle_wait = 99.0
	g.mouse_at = Vector2(320.0, 352.0)
	g.npc_eye = 0.0


func _settle(n: int) -> void:
	for _i in n:
		await process_frame
		_calm()
		g._process(0.0)
		g.queue_redraw()
	await RenderingServer.frame_post_draw


#  실시간 sec 초를 민다(1/120 초씩).
func _step(sec: float) -> void:
	var left := sec
	while left > 0.0001:
		var d: float = minf(1.0 / 120.0, left)
		_calm()
		g._process(d)
		left -= d
	await _settle(3)


func _crop(im: Image, r: Rect2, k: int) -> Image:
	var s: float = float(im.get_width()) / 640.0
	var part := im.get_region(Rect2i(int(r.position.x * s), int(r.position.y * s),
			int(r.size.x * s), int(r.size.y * s)))
	part.resize(int(r.size.x) * k, int(r.size.y) * k, Image.INTERPOLATE_NEAREST)
	return part


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


#  팩을 뜯어 쏟고 다 앉힌다 — 쏟은 것의 stock 자리.
func _open(size: int) -> Array:
	var bd: Dictionary = {}
	for b in GameData.boosters():
		if int((b as Dictionary).get("size", 0)) == size:
			bd = b
	var before: int = g.stock.size()
	g._boost_deal(bd)
	await _step(2.4)
	g._drop_settle()
	var out := []
	for i in range(before, g.stock.size()):
		if bool(g.stock[i].get("pack", false)):
			out.append(i)
	return out


func _shop() -> void:
	g._sweep_reset()
	g.gold = 99
	g.owned = []
	g.cons = []
	g._roll_stock()
	await _step(2.4)
	g._drop_settle()
	#  팩 물건이 잘 보이게 — 매물은 둘만 남긴다.
	for i in g.stock.size():
		if i >= 2:
			g.stock[i].sold = true
	g._drop_sold_sync()


func _strip(ts: Array, name: String, full_at: float) -> void:
	var cells := []
	var tt := 0.0
	for t in ts:
		await _step(float(t) - tt)
		tt = float(t)
		var im: Image = root.get_texture().get_image()
		cells.append(_crop(im, CROP, 2))
		print("  %s t %.2f · 주먹 %s %.2f · 뜬 것 %d · 조각 %d · 흔들림 %.1f" % [name, tt,
				g.prop_pound, float(g.prop_t[1]), _air(), g.shards.size(), g.shake])
		if absf(tt - full_at) < 0.001:
			im.save_png("res://shots/%s.png" % ("crush_small_hit" if name == "small"
					else "crush_big_air"))
	_sheet(cells, 4).save_png("res://shots/crush_%s_strip.png" % name)


func _air() -> int:
	var n := 0
	for it in g.drop:
		if int((it as Dictionary).get("doom", 0)) == 2 and not bool(it.gone):
			n += 1
	return n


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 찍힌다")
		quit(0)
		return
	g._new_run()
	for id in ["u_leg", "u_skip", "u_boss", "u_score", "u_clear", "u_shop", "u_rack",
			"u_cons", "u_sell", "u_reroll", "u_give", "u_pack", "u_info", "u_buy"]:
		Save.teach(id)
	g._tutor_close()
	g.tutor_q.clear()
	g.state = g.S.SHOP
	g.leg_no = 1
	g.gold = 99
	g._open_shop()
	await _wait(200)
	g._tutor_close()
	g.tutor_q.clear()
	g.set_process(false)
	await _settle(20)
	print("팩 부수기 — 진열대 %s · 손 3D %s" % [g._room3d_tbl(), g._hand3_live()])

	# ── 작은 팩 ──────────────────────────────────────
	await _shop()
	var ks: Array = await _open(2)
	if ks.size() != 2:
		print("  작은 팩이 안 쏟아졌다 %d" % ks.size())
		quit(1)
		return
	g.drop[ks[0]].u = 250.0
	g.drop[ks[0]].w = 90.0
	g.drop[ks[1]].u = 420.0
	g.drop[ks[1]].w = 74.0
	await _settle(4)
	g._pay_take(ks[0])
	print("작은 팩 — 주먹 %s" % g.prop_pound)
	await _strip(SMALL_T, "small", 0.34)
	await _step(1.0)

	# ── 큰 팩 ────────────────────────────────────────
	await _shop()
	var kb: Array = await _open(4)
	if kb.size() != 4:
		print("  큰 팩이 안 쏟아졌다 %d" % kb.size())
		quit(1)
		return
	var spots := [Vector2(230.0, 96.0), Vector2(300.0, 60.0), Vector2(372.0, 100.0),
			Vector2(470.0, 66.0)]
	for j in 4:
		g.drop[kb[j]].u = (spots[j] as Vector2).x
		g.drop[kb[j]].w = (spots[j] as Vector2).y
	await _settle(4)
	g._pay_take(kb[0])
	print("큰 팩 — 주먹 %s · 과녁 %s" % [g.prop_pound, str(g.prop_pound_at)])
	await _strip(BIG_T, "big", 0.56)
	quit(0)
