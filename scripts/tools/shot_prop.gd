extends SceneTree
#  판 소품 몸짓 촬영 (2026-10-02) — 팔면 상인이 판 동전을 저울 왼 접시에서 집어 가고,
#  사면 등록기 건반을 쳐 서랍이 튀어나온다(game.gd PROP 머리말). shots/ 에:
#    prop_sell_strip.png  판매 여덟 박자 — 화면 왼쪽 반(x 0~330 · y 40~220) 3배
#    prop_buy_strip.png   구매 여섯 박자 — 오른쪽 반(x 310~640 · y 40~220) 3배
#    prop_sell_x4.png     접시에서 테를 집은 손 4배
#    prop_buy_x4.png      건반을 누르는 검지 4배
#    prop_sell_full.png · prop_buy_full.png  그 박자의 온 화면(2배 그대로)
#  창이 있어야 돈다:
#    godot --path . --script scripts/tools/shot_prop.gd
#  게임 시계를 손으로 민다 — 게임 노드의 _process 를 끄고 정해진 틀(1/120 초)로 부른다.
#  찍는 틀이 멈춰도 몸짓이 그만큼 뛰지 않는다(창 캡처는 한 틀을 붙든다). 손 3D 자세는
#  그리기(_npc_arms)가 세운 것을 다음 틀 _process 가 옮기므로(_hand3_sync) 박자마다 시계를
#  안 민 틀을 셋 더 돌려 손이 따라오게 한다.
#  확대는 최근접으로만 — 보간하면 손가락 골과 팔 굵기 단이 흐려진다.
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
const L_RECT := Rect2(0.0, 40.0, 330.0, 180.0)
const R_RECT := Rect2(310.0, 40.0, 330.0, 180.0)
const SELL_T := [0.12, 0.20, 0.32, 0.46, 0.58, 0.74, 0.94, 1.08]
const BUY_T := [0.10, 0.22, 0.29, 0.33, 0.42, 0.62]
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_prop_g.cfg"
	Save.path = "user://_shot_prop.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	seed(20261002)


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


#  시계를 안 민 틀 n 개 — 그리기가 세운 자세를 3D 손이 따라온다.
func _settle(n: int) -> void:
	for _i in n:
		await process_frame
		_calm()
		g._process(0.0)
		g.queue_redraw()
	await RenderingServer.frame_post_draw


#  손 k 의 몸짓 시계를 tt 까지 민다(1/120 초씩 — 박자를 건너뛰지 않는다).
func _step_to(k: int, tt: float) -> void:
	var guard := 0
	while float(g.prop_t[k]) >= 0.0 and float(g.prop_t[k]) < tt - 0.0001 and guard < 4000:
		_calm()
		g._process(minf(1.0 / 120.0, tt - float(g.prop_t[k])))
		guard += 1
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


func _s(v: Vector3) -> Vector2:
	#  (u, w, h) → 화면
	return g._p2s(v.x, v.y, v.z)


#  (u, h, w) → 화면
func _s3(v: Vector3) -> Vector2:
	return g._p2s(v.x, v.z, v.y)


func _note(k: int) -> String:
	var sh: Vector2 = _s3(g.prop_ls[k])
	var el: Vector2 = _s3(g.prop_le[k])
	var wr: Vector2 = _s3(g.prop_lw[k])
	var l1: float = (g.prop_ls[k] as Vector3).distance_to(g.prop_le[k])
	var l2: float = (g.prop_le[k] as Vector3).distance_to(g.prop_lw[k])
	return "t %.2f · 팔 %.3f · 위팔 %.0f 팔뚝 %.0f · 화면 어깨 (%.0f,%.0f) 팔꿈치 (%.0f,%.0f) 손목 (%.0f,%.0f) · 화면 길이 %.0f : %.0f · 쥠 %.2f · 기울기 %.2f" % [
			float(g.prop_t[k]), float(g.prop_rr[k]), l1, l2, sh.x, sh.y, el.x, el.y,
			wr.x, wr.y, sh.distance_to(el), el.distance_to(wr), g._give_grip(k), g.scale_tilt]


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 찍힌다")
		quit(0)
		return
	g._new_run()
	for id in ["u_leg", "u_skip", "u_boss", "u_score", "u_clear", "u_shop", "u_rack",
			"u_cons", "u_sell", "u_reroll", "u_give"]:
		Save.teach(id)
	g._tutor_close()
	g.tutor_q.clear()
	g.state = g.S.SHOP
	g.leg_no = 1
	g.gold = 99
	g._open_shop()
	#  든 동전 셋 — 등급 빛이 있는 레어부터.
	var picks := []
	for rar in ["rare", "uncommon", "common"]:
		for it in GameData.items():
			if String((it as Dictionary).get("rarity", "")) == rar:
				picks.append(it)
				break
	for it in picks:
		var c: Dictionary = (it as Dictionary).duplicate()
		c.gs = 0
		c.bought = g.leg_no
		g.owned.append(c)
	g._panel_reset()
	await _wait(200)
	g._tutor_close()
	g.tutor_q.clear()
	g.set_process(false)
	await _settle(20)
	print("저울 · 등록기 — 진열대 %s · 손 3D %s" % [g._room3d_tbl(), g._hand3_live()])

	# ── 판매 ──────────────────────────────────────────
	var gold0: int = g.gold
	g.sell_sel = 0
	g._chute_click(g.Z_SELL)
	print("판매 — 섰다 %s · 금화 %d → %d" % [g._prop_live(0), gold0, g.gold])
	var cells := []
	var full: Image = null
	var x4: Image = null
	for tt in SELL_T:
		await _step_to(0, float(tt))
		var im: Image = root.get_texture().get_image()
		cells.append(_crop(im, L_RECT, 3))
		print("  판매 " + _note(0))
		if absf(float(tt) - 0.46) < 0.001:
			full = im
			var c3: Vector3 = g._prop_coin_now()
			var cs: Vector2 = _s(c3)
			x4 = _crop(im, Rect2(clampf(cs.x - 30.0, 0.0, 530.0), cs.y - 52.0, 110.0, 80.0), 4)
	_sheet(cells, 4).save_png("res://shots/prop_sell_strip.png")
	if full != null:
		full.save_png("res://shots/prop_sell_full.png")
	if x4 != null:
		x4.save_png("res://shots/prop_sell_x4.png")
	await _step_to(0, 1.4)
	await _settle(6)

	# ── 구매 ──────────────────────────────────────────
	var bi := -1
	for i in g.stock.size():
		if int(g.stock[i].cost) <= g.gold and g._buy_block(i) == "":
			bi = i
			break
	if bi < 0:
		print("  살 것이 없다")
		quit(1)
		return
	g.buy_sel = bi
	g._pay_click()
	print("구매 — 섰다 %s · 금화 %d" % [g._prop_live(1), g.gold])
	cells.clear()
	full = null
	x4 = null
	for tt in BUY_T:
		await _step_to(1, float(tt))
		var im2: Image = root.get_texture().get_image()
		cells.append(_crop(im2, R_RECT, 3))
		print("  구매 " + _note(1) + " · 서랍 %.2f" % g.pay_flash)
		if absf(float(tt) - 0.33) < 0.001:
			full = im2
			var k3: Vector3 = g._prop_key3()
			var ks: Vector2 = g._p2s(k3.x, k3.z, k3.y)
			x4 = _crop(im2, Rect2(clampf(ks.x - 70.0, 0.0, 530.0), ks.y - 56.0, 110.0, 80.0), 4)
	_sheet(cells, 3).save_png("res://shots/prop_buy_strip.png")
	if full != null:
		full.save_png("res://shots/prop_buy_full.png")
	if x4 != null:
		x4.save_png("res://shots/prop_buy_x4.png")
	g.set_process(true)
	print("찍었다 — prop_sell_strip · prop_buy_strip · prop_sell_x4 · prop_buy_x4 · *_full")
	quit(0)
