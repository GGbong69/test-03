extends SceneTree
#  화면 필터 셋(도트 97 · VHS 98 · CRT 100)을 게임에 붙인 뒤의 최종 촬영 (2026-10-04).
#  shots/ 에(접두 pre, 기본 retro_final):
#    <pre>_<장면>_<off|default|max>.png        1280x720 창(논리 1px = 기기 2px)
#    <pre>_<장면>_<off|default|max>_hi.png     2560x1440 창(기기 4px)
#        장면 title · shop · leg · settings(일시정지 › 설정 › 화면 탭) · over(게임 오버 확대 도중)
#        off      — 넷 다 0(CRT · 굴곡 · VHS · 도트)
#        default  — 게임 기본값(CRT_DEF · WARP_DEF · VHS_DEF · DOT_DEF)
#        max      — CRT · VHS · 도트 100 · 굴곡은 기본값
#    <pre>_text_zoom.png · <pre>_text_zoom_hi.png
#        작은 글이 모인 자리를 논리 4배 최근접으로 — 줄마다 한 자리, 칸은 off · default · max
#  후보 견주기(기본값 고르기):
#    godot --path . --script scripts/tools/shot_retro_final.gd -- cand=1
#    → <pre>_cand_<VHS>_<도트>.png(상점 온 화면) · <pre>_cand_zoom.png(줄마다 후보 하나)
#  「이름=값」 으로 기본값 자리를 민다(vhs= · dot= · crt= · warp=).
#  창이 있어야 돈다:  godot --path . --script scripts/tools/shot_retro_final.gd
#  움직임은 켠 채 찍는다(VHS 흔들림 · 낟알이 기본 화면의 일부다). 테이프 시계는 clock 으로
#  트래킹 띠가 없는 틀(0.5 초)에 박는다. 칸마다 열두 틀을 넘겨 잔상이 앞 칸을 안 남긴다.
const Save = preload("res://scripts/save.gd")
const DT := 1.0 / 120.0
var g = null
var busy := false
var pre := "retro_final"
var over := {}
var cand := false
var sfx := ""


func _initialize() -> void:
	Save.gpath = "user://_shot_retro_final_g.cfg"
	Save.path = "user://_shot_retro_final.cfg"
	Save.wipe()
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=", true, 1)
		if kv.size() != 2:
			continue
		if kv[0] == "pre":
			pre = kv[1]
		elif kv[0] == "cand":
			cand = kv[1] == "1"
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
	g.mouse_at = Vector2(-50.0, -50.0)


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


func _def(k: String) -> float:
	if over.has(k):
		return float(over[k])
	match k:
		"crt": return float(g.CRT_DEF)
		"warp": return float(g.WARP_DEF)
		"vhs": return float(g.VHS_DEF)
		"dot": return float(g.DOT_DEF)
	return 0.0


#  [CRT, 굴곡, VHS, 도트]
func _mode(m: String) -> Array:
	match m:
		"off": return [0.0, 0.0, 0.0, 0.0]
		"max": return [1.0, _def("warp"), 1.0, 1.0]
	return [_def("crt"), _def("warp"), _def("vhs"), _def("dot")]


func _set_f(v: Array) -> void:
	g.crt = float(v[0])
	g.warp = float(v[1])
	g.vhs = float(v[2])
	g.dot = float(v[3])
	g._crt_apply()
	var vm := g.vhs_rect.material as ShaderMaterial
	vm.set_shader_parameter("clock", 0.5)


func _grab(v: Array) -> Image:
	_set_f(v)
	await _settle(12)
	return root.get_texture().get_image()


func _crop(im: Image, r: Rect2, kp: int) -> Image:
	var s: float = float(im.get_width()) / float(g.get_viewport_rect().size.x)
	var rr := Rect2i(int(roundf(r.position.x * s)), int(roundf(r.position.y * s)),
			int(r.size.x * s), int(r.size.y * s))
	rr.position = rr.position.clamp(Vector2i.ZERO, im.get_size() - rr.size)
	var part := im.get_region(rr)
	part.resize(rr.size.x * kp, rr.size.y * kp, Image.INTERPOLATE_NEAREST)
	return part


func _sheet(cells: Array, cols: int) -> Image:
	var rows: int = (cells.size() + cols - 1) / cols
	var gap := 8
	var cws := []
	var rhs := []
	for i in cols:
		cws.append(0)
	for i in rows:
		rhs.append(0)
	for i in cells.size():
		var c: Image = cells[i]
		cws[i % cols] = maxi(int(cws[i % cols]), c.get_width())
		rhs[i / cols] = maxi(int(rhs[i / cols]), c.get_height())
	var tw := gap * (cols - 1)
	for w in cws:
		tw += int(w)
	var th := gap * (rows - 1)
	for h in rhs:
		th += int(h)
	var sh := Image.create(tw, th, false, (cells[0] as Image).get_format())
	sh.fill(Color(0.5, 0.5, 0.5))
	for i in cells.size():
		var c: Image = cells[i]
		var x := 0
		for j in i % cols:
			x += int(cws[j]) + gap
		var y := 0
		for j in i / cols:
			y += int(rhs[j]) + gap
		sh.blit_rect(c, Rect2i(0, 0, c.get_width(), c.get_height()), Vector2i(x, y))
	return sh


func _win(sz: Vector2i) -> void:
	DisplayServer.window_set_size(sz)
	await _wait(12)
	g._crt_apply()
	await _settle(4)
	print("  창 %s · 논리 %s" % [DisplayServer.window_get_size(), g.get_viewport_rect().size])


func _teach() -> void:
	for id in ["u_leg", "u_skip", "u_boss", "u_score", "u_clear", "u_shop", "u_rack",
			"u_cons", "u_sell", "u_reroll", "u_give", "u_boot", "u_gift", "u_more",
			"u_info", "u_last"]:
		Save.teach(id)


func _to_title() -> void:
	g.set_process(true)
	g.state = g.S.TITLE
	await _wait(30)
	g.set_process(false)
	await _settle(6)


func _to_leg() -> void:
	g.set_process(true)
	g._new_run()
	_teach()
	g._tutor_close()
	g.tutor_q.clear()
	await _wait(10)
	g._begin_leg()
	g._swap_skip()
	await _wait(40)
	g._tutor_close()
	g.tutor_q.clear()
	g.set_process(false)
	g.state = g.S.PICK
	await _settle(10)


func _to_shop() -> void:
	g.set_process(true)
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
	var bi := -1
	for i in g.stock.size():
		if int(g.stock[i].cost) <= g.gold and g._buy_block(i) == "":
			bi = i
			break
	g.buy_sel = bi
	await _settle(4)


func _to_settings() -> void:
	g._pause_open()
	g.set_t = 1.0
	g._set_go("top")
	g.set_t = 1.0
	g.set_pg_t = 1.0
	g.set_sel = 0
	g.set_hot = -1
	for _k in 40:
		g._set_tick(1.0 / 60.0)
	await _settle(6)


#  진 판 → 게임 오버 연출. 다트판이 다가오는 도중(0.6 초)에서 멈춘다.
func _to_over() -> void:
	g._settings_back()
	g._settings_back()
	g.over_cine_force = true
	g._swap_skip()
	g._begin_leg()
	g._swap_skip()
	for _k in 30:
		_calm()
		g._process(DT)
	g._tutor_close()
	g.tutor_q.clear()
	g.state = g.S.PICK
	g.total = 0
	g.darts_left = 0
	g.remaining.clear()
	for _k in 10:
		_calm()
		g._process(DT)
	await _wait(4)
	g._finish_leg()
	var tt := 0.0
	while tt < 0.6:
		_calm()
		g._process(DT)
		tt += DT
	print("  게임 오버 — cine %.2f · state %d" % [g.over_cine, g.state])
	await _settle(2)


#  한 장면 — off · default · max 를 찍어 두고 돌려준다.
func _scene(nm: String) -> Dictionary:
	var out := {}
	for m in ["off", "default", "max"]:
		var im: Image = await _grab(_mode(m))
		im.save_png("res://shots/%s_%s_%s%s.png" % [pre, nm, m, sfx])
		out[m] = im
	print("  %s%s — 찍었다" % [nm, sfx])
	return out


#  작은 글 자리(논리 px). 상점: 왼쪽 위(골드 · 이자 · 사탕·사진) · 오른쪽 위(동전 · 정보 ·
#  일시정지) · 「구매」 + 값. 판: 왼쪽 위(R1/8 · 골드). 설정: VHS · 도트 줄.
#  상점 첫 칸은 「사탕·사진 0/2」(y 52 밑)까지 담는다. 판 칸은 위끝에 붙은 「작은 판」이
#  굽은 칸에서 위로 밀려 잘리지 않게 0 부터 뜬다.
const SHOP_SPOTS := [Rect2(4.0, 4.0, 150.0, 62.0), Rect2(484.0, 4.0, 154.0, 48.0),
		Rect2(586.0, 160.0, 54.0, 40.0)]
const LEG_SPOT := Rect2(4.0, 0.0, 150.0, 64.0)
const SET_SPOT := Rect2(132.0, 202.0, 236.0, 72.0)


#  원본 자리 s 가 굴곡 w 에서 그려진 화면 자리 — 굽은 칸은 글이 옮겨 앉았으니 그 자리를 뜬다
#  (qa_warp 의 _inv 와 같은 뉴턴 풀이).
func _drawn(s: Vector2, w: float) -> Vector2:
	if w <= 0.004:
		return s
	var L: Vector2 = g.get_viewport_rect().size
	var d := s
	for _k in 30:
		var f: Vector2 = g._warp_src(d, L, w) - s
		if f.length() < 1e-4:
			break
		var g0: Vector2 = g._warp_src(d, L, w)
		var jx: Vector2 = (g._warp_src(d + Vector2(0.01, 0.0), L, w) - g0) / 0.01
		var jy: Vector2 = (g._warp_src(d + Vector2(0.0, 0.01), L, w) - g0) / 0.01
		var det: float = jx.x * jy.y - jy.x * jx.y
		if absf(det) < 1e-9:
			break
		d -= Vector2((jy.y * f.x - jy.x * f.y) / det, (-jx.y * f.x + jx.x * f.y) / det)
	return d


#  줄마다 한 자리 — off · default · max 를 나란히(논리 4배 최근접). 줄마다 제 폭으로 붙인다.
func _zoom(shop: Dictionary, leg: Dictionary, st: Dictionary) -> void:
	var kp := 1 if sfx == "_hi" else 2
	var spots := []
	for r in SHOP_SPOTS:
		spots.append([shop, r])
	spots.append([leg, LEG_SPOT])
	spots.append([st, SET_SPOT])
	var rows := []
	var tw := 0
	var th := 0
	var gap := 8
	for sp in spots:
		var row := []
		var rw := 0
		var rh := 0
		var r: Rect2 = sp[1]
		for m in ["off", "default", "max"]:
			var w: float = float(_mode(m)[1])
			var c := _drawn(r.get_center(), w)
			var cell := _crop((sp[0] as Dictionary)[m], Rect2(c - r.size * 0.5, r.size), kp)
			row.append(cell)
			rw += cell.get_width() + gap
			rh = maxi(rh, cell.get_height())
		rows.append([row, rh])
		tw = maxi(tw, rw - gap)
		th += rh + gap
	var sh := Image.create(tw, th - gap, false, (rows[0][0][0] as Image).get_format())
	sh.fill(Color(0.5, 0.5, 0.5))
	var y := 0
	for rr in rows:
		var x := 0
		for cell in rr[0]:
			sh.blit_rect(cell, Rect2i(0, 0, cell.get_width(), cell.get_height()), Vector2i(x, y))
			x += (cell as Image).get_width() + gap
		y += int(rr[1]) + gap
	sh.save_png("res://shots/%s_text_zoom%s.png" % [pre, sfx])


func _cands() -> void:
	await _win(Vector2i(1280, 720))
	await _to_leg()
	await _to_shop()
	var combos := [[0.0, 0.0], [0.2, 0.0], [0.3, 0.0], [0.5, 0.0], [0.0, 0.6],
			[0.2, 0.6], [0.3, 0.6], [0.3, 0.4], [0.5, 0.6], [0.3, 1.0]]
	var cells := []
	for cb in combos:
		var im: Image = await _grab([_def("crt"), _def("warp"), float(cb[0]), float(cb[1])])
		im.save_png("res://shots/%s_cand_%d_%d.png" % [pre, int(roundf(float(cb[0]) * 100.0)),
				int(roundf(float(cb[1]) * 100.0))])
		for r in SHOP_SPOTS:
			cells.append(_crop(im, r, 2))
	_sheet(cells, SHOP_SPOTS.size()).save_png("res://shots/%s_cand_zoom.png" % pre)
	print("  후보 %d — %s" % [combos.size(), combos])


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 찍힌다")
		quit(0)
		return
	g.motion_off = false
	_teach()
	print("기본 — CRT %.2f · 굴곡 %.2f · VHS %.2f · 도트 %.2f" % [_def("crt"), _def("warp"),
			_def("vhs"), _def("dot")])
	if cand:
		await _cands()
		quit(0)
		return
	for wsz in [Vector2i(1280, 720), Vector2i(2560, 1440)]:
		sfx = "_hi" if wsz.x > 2000 else ""
		await _win(wsz)
		await _to_title()
		await _scene("title")
		await _to_leg()
		var leg: Dictionary = await _scene("leg")
		await _to_shop()
		var shop: Dictionary = await _scene("shop")
		await _to_settings()
		var st: Dictionary = await _scene("settings")
		await _to_over()
		await _scene("over")
		_zoom(shop, leg, st)
		g.over_cine_force = false
		g.set_process(true)
		for _k in 240:
			await process_frame
		g.set_process(false)
	_set_f(_mode("off"))
	print("찍었다 — %s_*" % pre)
	quit(0)
