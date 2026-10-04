extends SceneTree
#  주먹 촬영 (2026-10-03) — 사탕을 상점에서 쓰면 사탕이 펠트에 떨어지고 상인이 주먹으로
#  부순다 · 빈 테이블 리롤은 주먹으로 테이블을 친다(game.gd POUND 머리말) · 판 동전은 저울
#  접시에서 왼손 주먹에 부서진다(SELLX). shots/ 에:
#    sell_smash_strip.png   판매 여덟 박자 — 화면 왼쪽(x 0~320 · y 20~200) 2배
#    sell_smash_hit.png     닿은 박자의 온 화면
#    pound_candy_strip.png  사탕 여덟 박자 — 화면 가운데(x 60~520 · y 16~250) 2배
#    pound_table_strip.png  빈 테이블 여덟 박자 — 같은 자리
#    pound_candy_hit.png · pound_table_hit.png  닿은 박자의 온 화면
#  창이 있어야 돈다:  godot --path . --script scripts/tools/shot_pound.gd
#  시계는 손으로 민다(shot_prop 과 같은 어법 — 게임 _process 를 끄고 1/120 초씩).
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
const C_RECT := Rect2(60.0, 16.0, 460.0, 234.0)
const TS := [0.10, 0.22, 0.30, 0.38, 0.44, 0.47, 0.56, 0.80]
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_pound_g.cfg"
	Save.path = "user://_shot_pound.cfg"
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
	g.mouse_at = Vector2(320.0, 352.0)
	g.npc_eye = 0.0


func _settle(n: int) -> void:
	for _i in n:
		await process_frame
		_calm()
		g._process(0.0)
		g.queue_redraw()
	await RenderingServer.frame_post_draw


func _step_to(tt: float) -> void:
	var guard := 0
	while float(g.prop_t[1]) >= 0.0 and float(g.prop_t[1]) < tt - 0.0001 and guard < 4000:
		_calm()
		g._process(minf(1.0 / 120.0, tt - float(g.prop_t[1])))
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


func _strip(nm: String) -> void:
	var cells := []
	for tt in TS:
		await _step_to(float(tt))
		var im: Image = root.get_texture().get_image()
		cells.append(_crop(im, C_RECT, 1))
		print("  %s t %.2f · 팔 %.3f · 손목 %s · 흔들림 %.1f · 알 %d" % [nm, float(g.prop_t[1]),
				float(g.prop_rr[1]), g.npc_wb[1], g.shake, g.bu_n])
		if absf(float(tt) - 0.47) < 0.001:
			im.save_png("res://shots/pound_%s_hit.png" % nm)
	_sheet(cells, 4).save_png("res://shots/pound_%s_strip.png" % nm)
	await _step_to(1.2)
	await _settle(6)


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
	await _wait(200)
	g._tutor_close()
	g.tutor_q.clear()
	g.set_process(false)
	g.motion_off = false
	await _settle(20)
	print("주먹 — 진열대 %s · 손 3D %s" % [g._room3d_tbl(), g._hand3_live()])

	# ── 판매 — 저울 접시의 판 동전을 왼손 주먹으로 부순다(2026-10-04) ──
	var picks := []
	for it in GameData.items():
		if String((it as Dictionary).get("rarity", "")) == "rare":
			picks.append((it as Dictionary).duplicate())
			break
	for c in picks:
		c.gs = 0
		c.bought = g.leg_no
		g.owned.append(c)
	g._panel_reset()
	await _settle(10)
	g.sell_sel = 0
	g._chute_click(g.Z_SELL)
	print("판매 — 섰다 %s" % g._prop_live(0))
	var cells := []
	var rt := 0.0
	#  실시간(몸짓 시계는 PROP.tempo_sell 배) — 접시 0.16 · 치켜듦 0.21 · 예비 0.29 · 닿음 0.35.
	for want in [0.10, 0.20, 0.28, 0.33, 0.36, 0.40, 0.50, 0.75]:
		while rt < float(want) - 0.0001:
			_calm()
			g._process(1.0 / 120.0)
			rt += 1.0 / 120.0
		await _settle(3)
		var im: Image = root.get_texture().get_image()
		cells.append(_crop(im, Rect2(0.0, 20.0, 320.0, 180.0), 2))
		print("  sell %.2f · t %.2f · 팔 %.3f · 손목 %s · 기울기 %.2f · 알 %d" % [rt,
				float(g.prop_t[0]), float(g.prop_rr[0]), g.npc_wb[0], g.scale_tilt, g.bu_n])
		if absf(float(want) - 0.36) < 0.001:
			im.save_png("res://shots/sell_smash_hit.png")
	_sheet(cells, 4).save_png("res://shots/sell_smash_strip.png")
	for k in 120:
		_calm()
		g._process(1.0 / 120.0)
	await _settle(6)

	# ── 사탕 ──
	for c in GameData.candies():
		if String((c as Dictionary).get("id", "")) == "c_tr":
			g.cons = [(c as Dictionary).duplicate()]
	g._cons_use(0)
	print("사탕 — 섰다 %s · %s" % [g._prop_live(1), g.pc_id])
	await _strip("candy")

	# ── 빈 테이블 ──
	for i in g.stock.size():
		g.stock[i].sold = true
	for i in g.drop.size():
		g.drop[i].sold = 1.0
	await _settle(30)
	g._reroll()
	print("빈 테이블 — 주먹 %s · 쓸기 %s" % [g.sweep_pound, g.sweep_live])
	await _strip("table")
	quit(0)
