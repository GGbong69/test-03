extends SceneTree
#  도트 팔레트 촬영 (2026-10-04) — shaders/dot.gdshader 가 제목 · 판 · 상점을 어떻게 줄이나.
#  game.gd 는 안 고친다 — 층(CanvasLayer 97 + 온 화면 ColorRect)을 여기서 직접 세운다.
#  shots/ 에(접두 pre, 기본 retro_dot):
#    <pre>_<장면>_<세기>.png    온 화면 1280x720 — 장면 title · board · shop, 세기 0 · 30 · 60 · 100
#    <pre>_<장면>_zoom.png      글이 몰린 자리를 기기 픽셀 2배로 — 줄마다 세기 하나
#    <pre>_<장면>_crt.png       게임의 CRT 층(기본 0.4) 위에 겹친 모습(도트 = 셰이더 기본 세기)
#    <pre>_<장면>_crt100.png    사용자 저장값(CRT 1.0 · 화면 굴곡 0.34) 위에 겹친 모습
#    <pre>_shop_hi_*.png · <pre>_shop_zoom_hi.png   2560x1440 창(논리 1px = 기기 4px)
#  상점에서는 「값」 줄도 찍는다 — 도트를 끈 채 · 1.0 의 GPU 시간(ms), 1280x720 · 2560x1440.
#  창이 있어야 돈다(화면 읽기라 렌더러가 없으면 안 그린다):
#    godot --path . --script scripts/tools/shot_retro_dot.gd [-- pre=접두 이름=값 …]
#  「이름=값」은 셰이더 uniform 을 그 값으로 민다(견줘 볼 때).
#  모션을 끄고 시계를 멈춰 찍는다 — 세기 말고 다른 것이 장마다 갈리지 않게.
const Save = preload("res://scripts/save.gd")
const DOT_SHADER := "res://shaders/dot.gdshader"
const DOT_LAYER := 97
const LEVELS := [0.0, 0.3, 0.6, 1.0]
var g = null
var busy := false
var pre := "retro_dot"
var over := {}
var dot_layer: CanvasLayer = null
var dot_rect: ColorRect = null
var mouse := Vector2(-50.0, -50.0)   # 커서는 화면 밖 — 제목 판의 칸 밝힘이 안 뜬다


func _initialize() -> void:
	Save.gpath = "user://_shot_dot_g.cfg"
	Save.path = "user://_shot_dot.cfg"
	Save.wipe()
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=", true, 1)
		if kv.size() != 2:
			continue
		if kv[0] == "pre":
			pre = kv[1]
		else:
			over[kv[0]] = float(kv[1])
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
	g.mouse_at = mouse


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


#  층 97 — 덮개(95) 위 · CRT(100) 밑. 게임이 세울 자리와 같다.
func _dot_open() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load(DOT_SHADER) as Shader
	dot_layer = CanvasLayer.new()
	dot_layer.name = "Dot"
	dot_layer.layer = DOT_LAYER
	dot_rect = ColorRect.new()
	dot_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	dot_rect.material = mat
	dot_layer.add_child(dot_rect)
	root.add_child(dot_layer)


func _dot(lv: float) -> void:
	var on := lv > 0.004
	dot_layer.visible = on
	var mat := dot_rect.material as ShaderMaterial
	mat.set_shader_parameter("strength", lv)
	mat.set_shader_parameter("logical", g.get_viewport_rect().size)
	for k in over:
		mat.set_shader_parameter(k, over[k])


func _crt(lv: float, wp := 0.0) -> void:
	g.crt = lv
	g.warp = wp
	g._crt_apply()


func _grab(lv: float) -> Image:
	_dot(lv)
	await _settle(4)
	return root.get_texture().get_image()


#  논리 좌표의 사각을 창 그림에서 떠서 기기 픽셀 kp 배로 키운다(최근접).
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


func _tag(lv: float) -> String:
	return "%d" % int(roundf(lv * 100.0))


#  한 장면 — 세기마다 온 화면 · 글 자리 확대 · CRT 겹침.
func _scene(nm: String, spots: Array, hi := false) -> void:
	var shots := {}
	var suf := "_hi" if hi else ""
	for lv in LEVELS:
		var im: Image = await _grab(float(lv))
		shots[_tag(float(lv))] = im
		im.save_png("res://shots/%s_%s%s_%s.png" % [pre, nm, suf, _tag(float(lv))])
	var cells := []
	for lv in LEVELS:
		for r in spots:
			cells.append(_crop(shots[_tag(float(lv))], r, 1 if hi else 2))
	_sheet(cells, spots.size()).save_png("res://shots/%s_%s_zoom%s.png" % [pre, nm, suf])
	if hi:
		return
	#  CRT 층 위에 겹친다 — 도트는 기본값(셰이더의 strength 기본). 게임 기본(CRT 0.4 · 굴곡 0)
	#  한 벌, 사용자 저장(CRT 1.0 · 굴곡 0.34) 한 벌.
	var mat := dot_rect.material as ShaderMaterial
	var def: float = float(RenderingServer.shader_get_parameter_default(
			mat.shader.get_rid(), "strength"))
	for cw in [[0.4, 0.0, "crt"], [1.0, 0.34, "crt100"]]:
		_crt(float(cw[0]), float(cw[1]))
		var cim: Image = await _grab(def)
		cim.save_png("res://shots/%s_%s_%s.png" % [pre, nm, cw[2]])
	_crt(0.0)
	print("  %s — 기본 세기 %.2f" % [nm, def])


#  값 — GPU 가 한 프레임에 쓴 시간(ms)을 도트를 끈 채 · 1.0 으로 60 프레임씩 재 견준다.
func _cost(tag: String) -> void:
	var vp := root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var ms := []
	for lv in [0.0, 1.0]:
		_dot(float(lv))
		await _settle(10)
		var sum := 0.0
		for _i in 60:
			await RenderingServer.frame_post_draw
			sum += RenderingServer.viewport_get_measured_render_time_gpu(vp)
		ms.append(sum / 60.0)
	RenderingServer.viewport_set_measure_render_time(vp, false)
	print("  값 %s — GPU 끔 %.2f ms · 1.0 %.2f ms" % [tag, float(ms[0]), float(ms[1])])


func _shop() -> Rect2:
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
	g.set_process(true)
	await _wait(200)
	g._tutor_close()
	g.tutor_q.clear()
	mouse = Vector2(320.0, 352.0)
	g.mouse_at = mouse
	g.set_process(false)
	await _settle(20)
	var bi := -1
	for i in g.stock.size():
		if int(g.stock[i].cost) <= g.gold and g._buy_block(i) == "":
			bi = i
			break
	g.buy_sel = bi
	await _settle(4)
	#  집은 매물의 값표 둘레 — 물건은 굴러 앉아 매번 자리가 달라 거기서 뜬다(shot_crt 와 같다).
	if bi >= 0 and bi < g.drop.size():
		var it: Dictionary = g.drop[bi]
		var by: float = g._p2g(it.w) + float(g.DROP.bill_dy) + float(g.BILL.dy)
		return Rect2(roundf(float(it.u)) - 60.0, roundf(by) - 40.0, 120.0, 52.0)
	return Rect2(260.0, 220.0, 120.0, 52.0)


func _board() -> void:
	g._new_run()
	g._swap_skip()
	g._begin_leg()
	g._swap_skip()
	g._tutor_close()
	g.tutor_q.clear()
	g.state = g.S.PICK
	g.set_process(true)
	await _wait(60)
	g._tutor_close()
	g.tutor_q.clear()
	g.set_process(false)
	await _settle(20)


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 찍힌다")
		quit(0)
		return
	_dot_open()
	await _win(Vector2i(1280, 720))
	g.motion_off = true
	print("논리 %s · 덧민 값 %s" % [g.get_viewport_rect().size, over])

	# ── 제목 ──
	await _wait(90)
	g.set_process(false)
	await _settle(10)
	await _scene("title", [Rect2(8.0, 60.0, 160.0, 70.0), Rect2(4.0, 180.0, 170.0, 170.0),
			Rect2(330.0, 220.0, 110.0, 100.0)])

	# ── 판 ──
	await _board()
	await _scene("board", [Rect2(4.0, 4.0, 150.0, 70.0), Rect2(250.0, 110.0, 140.0, 140.0),
			Rect2(480.0, 4.0, 156.0, 70.0)])

	# ── 상점 ──
	var mid: Rect2 = await _shop()
	var spots := [Rect2(6.0, 4.0, 72.0, 40.0), mid, Rect2(560.0, 150.0, 80.0, 60.0)]
	await _scene("shop", spots)
	await _cost("1280x720")

	# ── 고해상도 상점(4배) ──
	await _win(Vector2i(2560, 1440))
	await _scene("shop", spots, true)
	await _cost("2560x1440")
	print("찍었다 — %s_*" % pre)
	quit(0)
