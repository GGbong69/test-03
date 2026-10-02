extends SceneTree
#  시안 C 촬영 (2026-10-02) — 화면 끝에 걸친 큰 저울 · 금전등록기와 내리치기.
#  「C 로 바로」(game.gd PROP 머리말 · room3d.gd 「시안 C」). shots/ 에:
#    edge_shop.png        상점 온 화면 — 판매 · 구매 이름과 값이 다 선 틀
#    edge_leg.png         판 고르기 온 화면(소품이 거기에도 선다)
#    edge_buy_strip.png   내리치기 여덟 박자 — 오른쪽 반(x 320~640 · y 20~250) 게임 배율(2배)
#    edge_sell_strip.png  판매 여덟 박자 — 왼쪽 반(x 0~320 · y 20~250) 게임 배율
#    edge_props_x3.png    두 소품 쉼 3배(왼쪽 저울 · 오른쪽 등록기)
#    edge_mark.png        튜토리얼이 「구매」를 밝힌 틀(chute_buy)
#    edge_slam_x3.png     내리치는 박자(0.31~) 등록기 3배 — 서랍 · 값 깃 · 건반 · 빛살을 가까이
#  창이 있어야 돈다:
#    godot --path . --script scripts/tools/shot_edge.gd
#  게임 시계를 손으로 민다(shot_prop 과 같은 수) — _process 를 끄고 1/120 초씩 부른다.
#  손 3D 자세는 그리기가 세운 것을 다음 틀 _process 가 옮기므로 박자마다 시계를 안 민
#  틀을 셋 더 돌린다. 확대는 최근접으로만.
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
const L_RECT := Rect2(0.0, 20.0, 320.0, 230.0)
const R_RECT := Rect2(320.0, 20.0, 320.0, 230.0)
const SELL_T := [0.10, 0.20, 0.34, 0.46, 0.60, 0.80, 0.96, 1.16]
const BUY_T := [0.12, 0.24, 0.31, 0.345, 0.37, 0.42, 0.52, 0.76]
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_edge_g.cfg"
	Save.path = "user://_shot_edge.cfg"
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


func _settle(n: int) -> void:
	for _i in n:
		await process_frame
		_calm()
		g._process(0.0)
		g.queue_redraw()
	await RenderingServer.frame_post_draw


func _step_to(k: int, tt: float) -> void:
	var guard := 0
	while float(g.prop_t[k]) >= 0.0 and float(g.prop_t[k]) < tt - 0.0001 and guard < 4000:
		_calm()
		g._process(minf(1.0 / 120.0, tt - float(g.prop_t[k])))
		guard += 1
	await _settle(3)


func _crop(im: Image, r: Rect2, k: float) -> Image:
	var s: float = float(im.get_width()) / 640.0
	var part := im.get_region(Rect2i(int(r.position.x * s), int(r.position.y * s),
			int(r.size.x * s), int(r.size.y * s)))
	part.resize(int(r.size.x * k), int(r.size.y * k), Image.INTERPOLATE_NEAREST)
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


func _shot() -> Image:
	return root.get_texture().get_image()


func _buyable() -> int:
	for i in g.stock.size():
		if int(g.stock[i].cost) <= g.gold and g._buy_block(i) == "" \
				and not bool(g.stock[i].get("sold", false)):
			return i
	return -1


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
	print("진열대 %s · 손 3D %s · 저울 %s · 등록기 %s" % [g._room3d_tbl(), g._hand3_live(),
			str(g._prop_rect(0)), str(g._prop_rect(1))])

	# ── 상점 온 화면 — 팔 것 · 살 것을 다 고른 틀(이름 · 값이 둘 다 선다) ──
	g.sell_sel = 0
	g.buy_sel = _buyable()
	await _settle(6)
	_shot().save_png("res://shots/edge_shop.png")
	#  두 소품 3배 — 쉼
	var im0 := _shot()
	var px := Image.create(1, 1, false, im0.get_format())
	var a := _crop(im0, Rect2(0.0, 52.0, 132.0, 150.0), 3.0)
	var b := _crop(im0, Rect2(508.0, 40.0, 132.0, 162.0), 3.0)
	px = Image.create(a.get_width() + b.get_width() + 12, maxi(a.get_height(), b.get_height()),
			false, im0.get_format())
	px.fill(Color.BLACK)
	px.blit_rect(a, Rect2i(0, 0, a.get_width(), a.get_height()), Vector2i.ZERO)
	px.blit_rect(b, Rect2i(0, 0, b.get_width(), b.get_height()), Vector2i(a.get_width() + 12, 0))
	px.save_png("res://shots/edge_props_x3.png")
	g.sell_sel = -1
	g.buy_sel = -1
	await _settle(4)

	# ── 판매 ──────────────────────────────────────────
	var gold0: int = g.gold
	g.sell_sel = 0
	g._chute_click(g.Z_SELL)
	print("판매 — 섰다 %s · 금화 %d → %d" % [g._prop_live(0), gold0, g.gold])
	var cells := []
	for tt in SELL_T:
		await _step_to(0, float(tt))
		cells.append(_crop(_shot(), L_RECT, 2.0))
		print("  판매 t %.2f · 팔 %.3f · 기울기 %.2f · 쥠 %.2f" % [float(g.prop_t[0]),
				float(g.prop_rr[0]), g.scale_tilt, g._give_grip(0)])
	_sheet(cells, 2).save_png("res://shots/edge_sell_strip.png")
	await _step_to(0, 1.5)
	await _settle(6)

	# ── 구매 — 내리치기 ────────────────────────────────
	var bi := _buyable()
	if bi < 0:
		print("  살 것이 없다")
		quit(1)
		return
	g.buy_sel = bi
	g._pay_click()
	print("구매 — 섰다 %s · 금화 %d" % [g._prop_live(1), g.gold])
	cells.clear()
	var slam3 := []
	for tt in BUY_T:
		await _step_to(1, float(tt))
		var imb := _shot()
		cells.append(_crop(imb, R_RECT, 2.0))
		if float(tt) >= 0.30 and slam3.size() < 6:
			slam3.append(_crop(imb, Rect2(520.0, 40.0, 120.0, 170.0), 3.0))
		print("  구매 t %.3f · 팔 %.3f · 서랍 %.2f · 손목 옆 %.1f 굽힘 %.1f" % [float(g.prop_t[1]),
				float(g.prop_rr[1]), g.reg_open if "reg_open" in g else g.pay_flash,
				(g.npc_wb[1] as Vector2).x, (g.npc_wb[1] as Vector2).y])
	_sheet(cells, 2).save_png("res://shots/edge_buy_strip.png")
	_sheet(slam3, 3).save_png("res://shots/edge_slam_x3.png")
	await _step_to(1, 2.0)
	for _i in 120:
		_calm()
		g._process(1.0 / 60.0)
	await _settle(6)

	# ── 튜토리얼 — 「구매」를 밝힌 틀 ─────────────────────
	var ss: Array = GameData.tutor_steps("u_shop")
	var si := -1
	for i in ss.size():
		if String((ss[i] as Dictionary).get("mark", "")) == "chute_buy":
			si = i
			break
	if si >= 0:
		g.tutor_id = "u_shop"
		g.tutor_i = si
		g.tutor_pre = 0.0
		g.tutor_out = 0.0
		g.tutor_t = 30.0
		await _settle(8)
		_shot().save_png("res://shots/edge_mark.png")
		print("튜토리얼 밝힘 — %s" % str(g._mark_rect("chute_buy")))
		g._tutor_close()
		g.tutor_out = 0.0
	else:
		print("  chute_buy 를 밝히는 걸음이 없다")

	# ── 판 고르기 ──────────────────────────────────────
	g.set_process(true)
	g.leg_no = 2
	g._open_leg()
	await _wait(150)
	g._tutor_close()
	g.tutor_q.clear()
	g.mouse_at = Vector2(-50, -50)
	await _wait(30)
	_shot().save_png("res://shots/edge_leg.png")
	print("찍었다 — edge_shop · edge_leg · edge_buy_strip · edge_sell_strip · edge_props_x3 · edge_mark")
	quit(0)
