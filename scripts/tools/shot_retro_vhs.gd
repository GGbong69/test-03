extends SceneTree
#  VHS 비디오테이프 촬영 (2026-10-04) — shaders/vhs.gdshader 를 CanvasLayer 98(덮개 95 위 ·
#  CRT 100 밑)에 **직접** 세워 찍는다. game.gd 는 안 고친다 — 층 · 게이지는 통합 걸음이 단다.
#  shots/ 에:
#    retro_vhs_<장면>_<세기>.png   제목 · 상점 · 판 × 0 · 30 · 60 · 100 — 움직임 켬
#    retro_vhs_<장면>_still.png    움직임 끔(60)
#    retro_vhs_shop_50.png         추천 기본값(50)
#    retro_vhs_zoom.png            글이 몰린 자리(HUD 골드 · 매물 값 · 「구매」 · 판 HUD)를
#                                  기기 2배로 — 줄마다 0 · 30 · 60 · 100
#    retro_vhs_crt_<세기>.png      게임의 CRT 층(기본 40 · 굴곡 50)을 위에 얹은 채 VHS 0 · 30 · 60
#    retro_vhs_crt_user.png        사용자 저장값(CRT 100 · 굴곡 34) + VHS 60
#    retro_vhs_color.png           색 번짐 — 매물 줄 · 판 고리를 기기 2배로, 줄마다 0 · 30 · 60 · 100
#    retro_vhs_shop_60_1610.png    16:10 창(논리 640x400)
#    retro_vhs_*_hi.png            2560x1440 창(논리 1px = 기기 4px)
#  창이 있어야 돈다(화면 읽기라 렌더러가 없으면 아무것도 안 그린다):
#    godot --path . --script scripts/tools/shot_retro_vhs.gd
#  시계는 셰이더의 clock 으로 박는다 — TIME 을 따르면 틀마다 떨림 · 낟알이 갈려 세기 말고
#  다른 것이 갈린다. 게임은 움직임 끔 · _process 끔으로 세운다.
const Save = preload("res://scripts/save.gd")
const VHS_SHADER := "res://shaders/vhs.gdshader"
const VHS_LAYER := 98
const LEVELS := [0.0, 0.3, 0.6, 1.0]
const CLK := 0.5          # 촬영 틀 — 시계를 못 박아 떨림 · 낟알이 장마다 같다
var g = null
var busy := false
var vl: CanvasLayer = null
var vmat: ShaderMaterial = null


func _initialize() -> void:
	Save.gpath = "user://_shot_vhs_g.cfg"
	Save.path = "user://_shot_vhs.cfg"
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
	g.npc_eye = 0.0
	g.mouse_at = Vector2(320.0, 352.0)


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


#  층 98 — 온 화면 ColorRect 하나에 셰이더를 건다(game.gd 의 _crt_open 과 같은 꼴).
func _vhs_open() -> void:
	var sh: Shader = load(VHS_SHADER) as Shader
	vmat = ShaderMaterial.new()
	vmat.shader = sh
	vl = CanvasLayer.new()
	vl.name = "Vhs"
	vl.layer = VHS_LAYER
	var r := ColorRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.material = vmat
	vl.add_child(r)
	g.add_child(vl)


func _vhs(s: float, mo: bool, clk: float) -> void:
	vl.visible = s > 0.004
	vmat.set_shader_parameter("strength", s)
	vmat.set_shader_parameter("logical", g.get_viewport_rect().size)
	vmat.set_shader_parameter("motion", 1.0 if mo else 0.0)
	vmat.set_shader_parameter("clock", clk)


func _grab(s: float, mo := true, clk := CLK) -> Image:
	_vhs(s, mo, clk)
	await _settle(4)
	return root.get_texture().get_image()


func _tag(s: float) -> String:
	return "%d" % int(roundf(s * 100.0))


func _win(sz: Vector2i) -> void:
	DisplayServer.window_set_size(sz)
	await _wait(12)
	g._crt_apply()
	await _settle(4)


#  논리 좌표의 사각을 떠서 **기기 픽셀** kp 배로 키운다(최근접 — 보간하면 결이 녹는다).
func _crop(im: Image, r: Rect2, kp: int) -> Image:
	var s: float = float(im.get_width()) / float(g.get_viewport_rect().size.x)
	var rr := Rect2i(int(r.position.x * s), int(r.position.y * s),
			int(r.size.x * s), int(r.size.y * s))
	var part := im.get_region(rr)
	part.resize(rr.size.x * kp, rr.size.y * kp, Image.INTERPOLATE_NEAREST)
	return part


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


#  글자 자리의 루마 — 획의 날(원본에서 기울기가 0.08 넘는 자리만 — 낟알이 민 바탕을
#  안 세게)과 원본과의 평균 차이. 날 1 이면 획이 원본만큼 서 있다(눈으로 보는 것이 먼저다).
func _luma_stat(a: Image, b: Image, r: Rect2) -> Vector2:
	var s: float = float(a.get_width()) / float(g.get_viewport_rect().size.x)
	var x0 := int(r.position.x * s)
	var y0 := int(r.position.y * s)
	var w := int(r.size.x * s)
	var h := int(r.size.y * s)
	var ea := 0.0
	var eb := 0.0
	var df := 0.0
	for y in range(y0, y0 + h):
		var pa := a.get_pixel(x0, y).get_luminance()
		var pb := b.get_pixel(x0, y).get_luminance()
		for x in range(x0 + 1, x0 + w):
			var qa := a.get_pixel(x, y).get_luminance()
			var qb := b.get_pixel(x, y).get_luminance()
			if absf(qa - pa) > 0.08:
				ea += absf(qa - pa)
				eb += absf(qb - pb)
			df += absf(qb - qa)
			pa = qa
			pb = qb
	return Vector2(eb / maxf(ea, 0.0001), df / float(w * h))


func _scene_set(nm: String, spots: Array) -> Dictionary:
	var shots := {}
	for lv in LEVELS:
		var im: Image = await _grab(float(lv))
		im.save_png("res://shots/retro_vhs_%s_%s.png" % [nm, _tag(float(lv))])
		shots[_tag(float(lv))] = im
	var st: Image = await _grab(0.6, false)
	st.save_png("res://shots/retro_vhs_%s_still.png" % nm)
	#  날 · 차이 — 움직임 끔(떨림 없이 번짐 · 바램 · 낟알만)
	for lv in [0.3, 0.6, 1.0]:
		var still: Image = await _grab(float(lv), false)
		var line := "  %s %s —" % [nm, _tag(float(lv))]
		for r in spots:
			var v: Vector2 = _luma_stat(shots["0"], still, r)
			line += " 날 %.2f 차 %.3f ·" % [v.x, v.y]
		print(line)
	print("  %s — %dx%d" % [nm, (shots["0"] as Image).get_width(),
			(shots["0"] as Image).get_height()])
	return shots


func _teach() -> void:
	for id in ["u_leg", "u_skip", "u_boss", "u_score", "u_clear", "u_shop", "u_rack",
			"u_cons", "u_sell", "u_reroll", "u_give", "u_boot", "u_gift", "u_more",
			"u_info", "u_last"]:
		Save.teach(id)


func _shop_open() -> int:
	g._new_run()
	_teach()
	g._tutor_close()
	g.tutor_q.clear()
	g.state = g.S.SHOP
	g.leg_no = 1
	g.gold = 24
	g._open_shop()
	await _wait(200)
	g._tutor_close()
	g.tutor_q.clear()
	g.set_process(false)
	await _settle(20)
	#  매물 하나를 집는다 — 오른쪽 「구매」 가 밝아지고 그 밑에 값이 선다(shot_crt 와 같다).
	var bi := -1
	for i in g.stock.size():
		if int(g.stock[i].cost) <= g.gold and g._buy_block(i) == "":
			bi = i
			break
	g.buy_sel = bi
	await _settle(4)
	return bi


func _mid_spot(bi: int) -> Rect2:
	var mid := Rect2(260.0, 220.0, 120.0, 52.0)
	if bi >= 0 and bi < g.drop.size():
		var it: Dictionary = g.drop[bi]
		var by: float = g._p2g(it.w) + float(g.DROP.bill_dy) + float(g.BILL.dy)
		mid = Rect2(roundf(float(it.u)) - 60.0, roundf(by) - 40.0, 120.0, 52.0)
	return mid


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 찍힌다")
		quit(0)
		return
	_vhs_open()
	await _win(Vector2i(1280, 720))
	g.motion_off = true
	_teach()
	print("논리 %s · 층 %d" % [g.get_viewport_rect().size, vl.layer])

	# ── 제목 ──
	g.state = g.S.TITLE
	for _k in 40:
		_calm()
		await process_frame
	g.set_process(false)
	await _settle(10)
	await _scene_set("title", [Rect2(200.0, 260.0, 240.0, 90.0)])

	# ── 판 — 새 런 첫 판(백색 · 흑색 칸 · 빨강 · 초록 고리) ──
	g.set_process(true)
	g._new_run()
	_teach()
	g._tutor_close()
	g.tutor_q.clear()
	g._begin_leg()
	g._swap_skip()
	for _k in 30:
		_calm()
		await process_frame
	g._tutor_close()
	g.tutor_q.clear()
	g._swap_skip()
	g.set_process(false)
	await _settle(10)
	print("판 — state %d" % g.state)
	var leg_spots := [Rect2(0.0, 0.0, 120.0, 60.0), Rect2(520.0, 0.0, 120.0, 60.0)]
	var leg: Dictionary = await _scene_set("leg", leg_spots)

	# ── 상점 ──
	g.set_process(true)
	var bi: int = await _shop_open()
	print("상점 — 집은 매물 %d" % bi)
	var spots := [Rect2(6.0, 4.0, 72.0, 40.0), _mid_spot(bi), Rect2(592.0, 160.0, 48.0, 40.0)]
	var shop: Dictionary = await _scene_set("shop", spots)
	(await _grab(0.5)).save_png("res://shots/retro_vhs_shop_50.png")    # 추천 기본값
	#  세기 0 은 원본 그대로인가 — 층을 세운 채 0 으로 돌려 숨긴 화면과 화소를 댄다.
	var bare: Image = await _grab(0.0)
	_vhs(0.0, true, CLK)
	vl.visible = true
	await _settle(4)
	var zero: Image = root.get_texture().get_image()
	var worst := 0.0
	for y in range(0, bare.get_height(), 3):
		for x in range(0, bare.get_width(), 3):
			var a := bare.get_pixel(x, y)
			var b := zero.get_pixel(x, y)
			worst = maxf(worst, maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))))
	print("  세기 0 · 층 선 채 — 원본과 가장 큰 차 %.4f(1/255 = 0.0039)" % worst)

	#  글 자리 확대 — 줄마다 0 · 30 · 60 · 100. 상점 셋 + 판 HUD 둘.
	var cells := []
	for tag in ["0", "30", "60", "100"]:
		for r in spots:
			cells.append(_crop(shop[tag], r, 2))
		cells.append(_crop(leg[tag], leg_spots[0], 2))
	_sheet(cells, spots.size() + 1).save_png("res://shots/retro_vhs_zoom.png")
	#  색 번짐 — 매물 줄(빨강 · 초록 · 금빛) · 판의 빨강 · 초록 고리.
	var col_spots := [Rect2(230.0, 180.0, 200.0, 85.0)]
	var leg_col := Rect2(200.0, 130.0, 120.0, 85.0)
	cells.clear()
	for tag in ["0", "30", "60", "100"]:
		cells.append(_crop(shop[tag], col_spots[0], 2))
		cells.append(_crop(leg[tag], leg_col, 2))
	_sheet(cells, 2).save_png("res://shots/retro_vhs_color.png")

	#  CRT 층을 위에 얹는다 — 기본(40 · 굴곡 50) · 사용자 저장(100 · 굴곡 34).
	g.crt = g.CRT_DEF
	g.warp = g.WARP_DEF
	g._crt_apply()
	for lv in [0.0, 0.3, 0.6]:
		(await _grab(float(lv))).save_png("res://shots/retro_vhs_crt_%s.png" % _tag(float(lv)))
	g.crt = 1.0
	g.warp = 0.34
	g._crt_apply()
	(await _grab(0.6)).save_png("res://shots/retro_vhs_crt_user.png")
	g.crt = 0.0
	g.warp = 0.0
	g._crt_apply()

	#  16:10 창 — 보이는 논리 크기가 640x400 이 된다(헤드 스위칭이 400 행의 밑에 서는가).
	await _win(Vector2i(1280, 800))
	(await _grab(0.6)).save_png("res://shots/retro_vhs_shop_60_1610.png")
	print("  16:10 — 논리 %s" % g.get_viewport_rect().size)

	#  고해상도 창(4배) — 같은 상점 · 같은 자리.
	await _win(Vector2i(2560, 1440))
	var hi := {}
	for lv in LEVELS:
		hi[_tag(float(lv))] = await _grab(float(lv))
	(hi["60"] as Image).save_png("res://shots/retro_vhs_shop_60_hi.png")
	print("  shop_60_hi — %dx%d" % [(hi["60"] as Image).get_width(),
			(hi["60"] as Image).get_height()])
	cells.clear()
	for tag in ["0", "30", "60", "100"]:
		for r in spots:
			cells.append(_crop(hi[tag], r, 1))
	_sheet(cells, spots.size()).save_png("res://shots/retro_vhs_zoom_hi.png")
	g.crt = g.CRT_DEF
	g.warp = g.WARP_DEF
	g._crt_apply()
	(await _grab(0.6)).save_png("res://shots/retro_vhs_crt_60_hi.png")
	print("찍었다 — retro_vhs_*")
	quit(0)
