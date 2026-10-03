extends SceneTree
#  CRT 필터 촬영 (2026-10-03) — 설정의 「CRT 필터」 게이지가 상점을 어떻게 덮나.
#  shots/ 에:
#    crt_shop_0.png · crt_shop_40.png · crt_shop_100.png   상점 온 화면(1280x720 창 · 2배)
#    crt_zoom.png      글이 몰린 세 자리(HUD 골드 · 매물 값 · 「구매」 + 값)를 논리 4배
#                      (= 기기 픽셀 2배)로 — 줄마다 0 · 40 · 100
#    crt_settings.png  상점에서 연 설정 — 「CRT 필터」 줄을 고른 채(기본 40)
#    crt_shop_40_hi.png · crt_zoom_hi.png   같은 것을 2560x1440 창(4배)에서 —
#                      고해상도 모니터는 논리 1px 이 기기 4px 이라 주사선 모양이 다르다
#  창 크기를 1280x720 으로 못 박는다 — 화면 배율(DPI)에 따라 기본 창이 2560x1440 으로
#  뜨는 자리가 있어서, 안 박으면 「기본 창에서 어떻게 보이나」를 못 잰다.
#  창이 있어야 돈다(CRT 는 화면 읽기라 렌더러가 없으면 아무것도 안 그린다):
#    godot --path . --script scripts/tools/shot_crt.gd
#  모션을 끄고 찍는다 — 깜박임 · 낟알이 세 장 사이에 끼면 세기 말고 다른 것이 갈린다.
#  확대는 최근접으로만 — 보간하면 주사선이 녹아 그 자리를 못 본다.
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
const LEVELS := [0.0, 0.4, 1.0]
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_crt_g.cfg"
	Save.path = "user://_shot_crt.cfg"
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
	g.npc_eye = 0.0


func _settle(n: int) -> void:
	for _i in n:
		await process_frame
		_calm()
		g._process(0.0)
		g.queue_redraw()
		var fr = g.get_node_or_null("Front")
		if fr != null:
			fr.queue_redraw()
	await RenderingServer.frame_post_draw


func _grab(lv: float) -> Image:
	g.crt = lv
	g._crt_apply()
	await _settle(4)
	return root.get_texture().get_image()


#  논리 좌표의 사각을 창 그림에서 떠서 **기기 픽셀** kp 배로 키운다 — 주사선 ·
#  마스크가 기기 픽셀마다 서므로 그 단위로 키워야 한 줄 한 줄이 보인다.
func _crop(im: Image, r: Rect2, kp: int) -> Image:
	var s: float = float(im.get_width()) / float(g.get_viewport_rect().size.x)
	var rr := Rect2i(int(r.position.x * s), int(r.position.y * s),
			int(r.size.x * s), int(r.size.y * s))
	var part := im.get_region(rr)
	part.resize(rr.size.x * kp, rr.size.y * kp, Image.INTERPOLATE_NEAREST)
	return part


func _win(sz: Vector2i) -> void:
	DisplayServer.window_set_size(sz)
	await _wait(12)
	g._crt_apply()
	await _settle(4)


func _sheet(cells: Array, cols: int) -> Image:
	var rows: int = (cells.size() + cols - 1) / cols
	var gap := 8
	var cw := 0
	var ch := 0
	for c in cells:
		cw = maxi(cw, (c as Image).get_width())
		ch = maxi(ch, (c as Image).get_height())
	var sh := Image.create(cw * cols + gap * (cols - 1), ch * rows + gap * (rows - 1), false,
			(cells[0] as Image).get_format())
	sh.fill(Color(0.5, 0.5, 0.5))
	for i in cells.size():
		var c: Image = cells[i]
		sh.blit_rect(c, Rect2i(0, 0, c.get_width(), c.get_height()),
				Vector2i((i % cols) * (cw + gap), (i / cols) * (ch + gap)))
	return sh


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 찍힌다")
		quit(0)
		return
	await _win(Vector2i(1280, 720))
	g.motion_off = true
	g._new_run()
	for id in ["u_leg", "u_skip", "u_boss", "u_score", "u_clear", "u_shop", "u_rack",
			"u_cons", "u_sell", "u_reroll", "u_give", "u_boot", "u_gift", "u_more",
			"u_info", "u_last"]:
		Save.teach(id)
	g._tutor_close()
	g.tutor_q.clear()
	g.state = g.S.SHOP
	g.leg_no = 1
	g.gold = 24
	g._open_shop()
	await _wait(200)
	g._tutor_close()
	g.tutor_q.clear()
	g.mouse_at = Vector2(320.0, 352.0)
	g.set_process(false)
	await _settle(20)
	#  매물 하나를 집는다 — 오른쪽 「구매」 가 밝아지고 그 밑에 값이 선다.
	var bi := -1
	for i in g.stock.size():
		if int(g.stock[i].cost) <= g.gold and g._buy_block(i) == "":
			bi = i
			break
	g.buy_sel = bi
	print("논리 %s · 집은 매물 %d" % [g.get_viewport_rect().size, bi])

	var shots := {}
	for lv in LEVELS:
		var im: Image = await _grab(float(lv))
		var tag := "%d" % int(roundf(float(lv) * 100.0))
		im.save_png("res://shots/crt_shop_%s.png" % tag)
		print("  crt_shop_%s — %dx%d" % [tag, im.get_width(), im.get_height()])
		shots[tag] = im
	#  글이 몰린 세 자리 — HUD 골드(왼쪽 위 모서리) · 매물 값(가운데) ·
	#  「구매」 + 값(오른끝). 모서리 · 끝이 굽힘 · 색 어긋남이 가장 센 자리라 거기서
	#  글이 읽히는지가 요점이다. HUD 와 「구매」 는 화면에 박힌 자리이고, 매물 값은
	#  집은 매물(bi)의 값표 둘레에서 뜬다 — 물건은 굴러 앉아 매번 자리가 다르다.
	var mid := Rect2(260.0, 220.0, 120.0, 52.0)
	if bi >= 0 and bi < g.drop.size():
		var it: Dictionary = g.drop[bi]
		var by: float = g._p2g(it.w) + float(g.DROP.bill_dy) + float(g.BILL.dy)
		mid = Rect2(roundf(float(it.u)) - 60.0, roundf(by) - 40.0, 120.0, 52.0)
	var spots := [Rect2(6.0, 4.0, 72.0, 40.0), mid, Rect2(592.0, 160.0, 48.0, 40.0)]
	_zoom(shots, spots, "crt_zoom")

	#  설정 — 상점에서 연다. 「CRT 필터」 줄을 고른 채 기본 40.
	g.buy_sel = -1
	g.crt = g.CRT_DEF
	g._crt_apply()
	g._pause_open()
	#  CRT 필터는 일시정지 › 설정 › 화면 쪽에 산다(2026-10-03).
	g._set_go("screen")
	g.set_pg_t = 1.0
	var rows: Array = g._set_rows()
	g.set_sel = rows.find("crt")
	g.set_hot = -1
	g.mouse_at = Vector2(600.0, 340.0)
	g.set_t = 1.0
	for k in 40:
		g._set_tick(1.0 / 60.0)
	await _settle(6)
	var st: Image = root.get_texture().get_image()
	st.save_png("res://shots/crt_settings.png")
	while g.state == g.S.SETTINGS:      # 화면 › 설정 › 일시정지 › 상점 — 한 단씩 오른다
		g._settings_back()
	g.buy_sel = bi

	#  고해상도 창(4배) — 같은 상점 · 같은 자리.
	await _win(Vector2i(2560, 1440))
	var hi := {}
	for lv in LEVELS:
		hi["%d" % int(roundf(float(lv) * 100.0))] = await _grab(float(lv))
	(hi["40"] as Image).save_png("res://shots/crt_shop_40_hi.png")
	print("  crt_shop_40_hi — %dx%d" % [(hi["40"] as Image).get_width(),
			(hi["40"] as Image).get_height()])
	_zoom(hi, spots, "crt_zoom_hi", 1)
	g.crt = g.CRT_DEF
	g._crt_apply()
	print("찍었다 — crt_shop_0 · crt_shop_40 · crt_shop_100 · crt_zoom · crt_settings · *_hi")
	quit(0)


#  세 줄(0 · 40 · 100) × 자리 셋.
func _zoom(shots: Dictionary, spots: Array, nm: String, kp := 2) -> void:
	var cells := []
	for tag in ["0", "40", "100"]:
		for r in spots:
			cells.append(_crop(shots[tag], r, kp))
	_sheet(cells, spots.size()).save_png("res://shots/%s.png" % nm)
