extends SceneTree
#  브라운관 강화 촬영 (2026-10-04) — CRT 필터의 옛 판과 새 판을 같은 장면에서 맞대 본다.
#  shots/ 에:
#    retro_crt_<장면>_<판>_<세기>.png  제목 · 판 · 상점 온 화면(1280x720 창 · 2배).
#                     판 = old · new, 세기 40 · 100. 세기 0(필터 끔 · 굴곡만)은 _0 한 장.
#    retro_crt_<장면>_zoom.png         글이 몰린 자리를 기기 픽셀 2배 최근접으로 —
#                     줄마다 0 · 옛 40 · 새 40 · 옛 100 · 새 100(옛 판이 없으면 0 · 40 · 100)
#    retro_crt_<장면>_zoom_hi.png      같은 것을 2560x1440 창(4배)에서 기기 픽셀 1배로
#    retro_crt_shop_zoom_3x.png        1920x1080 창(3배 — 흔한 전체화면)에서 상점만
#    retro_crt_shop_new_40_hi.png       고해상도 온 화면 한 장
#    retro_crt_band.png                흐르는 띠 — 모션 켠 화면 − 끈 화면을 열 배로(회색이 0).
#                     위 · 아래 두 칸이 2.5 초 사이 — 띠가 내려간다
#    retro_crt_trail.png               잔상 — 판 밑을 지나가는 흰 네모 · 금빛 점.
#                     줄마다 잔상 없음 100 · 있음 40 · 있음 100
#  창이 있어야 돈다(CRT 는 화면 읽기라 렌더러가 없으면 아무것도 안 그린다):
#    godot --path . --script scripts/tools/shot_retro_crt.gd -- --old=<옛 셰이더 글 경로>
#  --old 를 안 주면 새 판만 찍는다. 옛 글은 고치기 전 커밋에서 뜬다
#  (git show 6f67b1f:shaders/crt.gdshader > 파일).
#  굴곡은 사용자 값(34)으로 둔다. 모션은 끄고 찍는다 — 깜박임 · 낟알이 칸 사이에 끼면
#  세기 말고 다른 것이 갈린다(띠 · 잔상 칸만 켠다). 확대는 최근접으로만 — 보간하면
#  주사선이 녹는다.
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
const Trail = preload("res://scripts/crt_trail.gd")
const LEVELS := [0.4, 1.0]
const WARP_USER := 0.34
var g = null
var busy := false
var sh_new: Shader = null
var sh_old: Shader = null
var hi := false                    # 지금 2560 · 1920 창인가 — 확대를 기기 1배로
var sfx := ""                      # 확대 파일 꼬리 — "" · _hi · _3x


func _initialize() -> void:
	Save.gpath = "user://_shot_retro_crt_g.cfg"
	Save.path = "user://_shot_retro_crt.cfg"
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


func _mat() -> ShaderMaterial:
	return g.crt_rect.material as ShaderMaterial


#  판(옛 · 새)을 갈아 끼우고 세기 lv 로 한 장.
func _grab(sh: Shader, lv: float) -> Image:
	_mat().shader = sh
	g.crt = lv
	g.warp = WARP_USER
	g._crt_apply()
	await _settle(4)
	return root.get_texture().get_image()


#  논리 좌표의 사각을 창 그림에서 떠서 **기기 픽셀** kp 배로 키운다.
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
	print("  창 %s · 논리 %s" % [DisplayServer.window_get_size(), g.get_viewport_rect().size])


func _sheet(cells: Array, cols: int) -> Image:
	var rows: int = (cells.size() + cols - 1) / cols
	var gap := 8
	var cws := []
	var ch := 0
	for i in cols:
		cws.append(0)
	for i in cells.size():
		var c: Image = cells[i]
		cws[i % cols] = maxi(int(cws[i % cols]), c.get_width())
		ch = maxi(ch, c.get_height())
	var tw := gap * (cols - 1)
	for w in cws:
		tw += int(w)
	var sh := Image.create(tw, ch * rows + gap * (rows - 1), false,
			(cells[0] as Image).get_format())
	sh.fill(Color(0.5, 0.5, 0.5))
	for i in cells.size():
		var c: Image = cells[i]
		var x := 0
		for j in i % cols:
			x += int(cws[j]) + gap
		sh.blit_rect(c, Rect2i(0, 0, c.get_width(), c.get_height()),
				Vector2i(x, (i / cols) * (ch + gap)))
	return sh


#  한 장면 — 0 · (옛 40 · 새 40) · (옛 100 · 새 100). 온 화면은 1280 에서만 남긴다.
func _scene(nm: String, spots: Array, full := true) -> void:
	var rows := []
	var im0: Image = await _grab(sh_new, 0.0)
	rows.append(im0)
	if full and not hi:
		im0.save_png("res://shots/retro_crt_%s_0.png" % nm)
	for lv in LEVELS:
		var tag := "%d" % int(roundf(float(lv) * 100.0))
		for pair in [["old", sh_old], ["new", sh_new]]:
			if pair[1] == null:
				continue
			var im: Image = await _grab(pair[1], float(lv))
			rows.append(im)
			if not full:
				pass
			elif not hi:
				im.save_png("res://shots/retro_crt_%s_%s_%s.png" % [nm, pair[0], tag])
			elif nm == "shop" and pair[0] == "new" and tag == "40":
				im.save_png("res://shots/retro_crt_shop_new_40_hi.png")
	var cells := []
	for im in rows:
		for r in spots:
			cells.append(_crop(im, r, 1 if hi else 2))
	_sheet(cells, spots.size()).save_png("res://shots/retro_crt_%s_zoom%s.png" % [nm, sfx])
	print("  %s — %d줄 × %d자리" % [nm, rows.size(), spots.size()])


func _to_title() -> void:
	g.set_process(true)
	g.state = g.S.TITLE
	await _wait(30)
	g.set_process(false)
	g.mouse_at = Vector2(4.0, 4.0)
	await _settle(6)


func _to_leg() -> void:
	g.set_process(true)
	g._new_run()
	for id in ["u_leg", "u_skip", "u_boss", "u_score", "u_clear", "u_shop", "u_rack",
			"u_cons", "u_sell", "u_reroll", "u_give", "u_boot", "u_gift", "u_more",
			"u_info", "u_last"]:
		Save.teach(id)
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
	g.mouse_at = Vector2(600.0, 340.0)
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


#  글 자리 — 작은 HUD 글(8~10 논리 px)이 몰린 곳.
#  제목: 「하이톤 · HIGHTON」 · 판 숫자 · 「프로필 1」
const TITLE_SPOTS := [Rect2(14.0, 70.0, 100.0, 56.0), Rect2(200.0, 76.0, 100.0, 56.0),
		Rect2(18.0, 310.0, 152.0, 36.0)]
#  판: 왼쪽 위(R1/8 · 골드 · 사탕·사진) · 오른쪽 위(동전 · 다트 · 정보 · 일시정지) · 판 숫자
const LEG_SPOTS := [Rect2(4.0, 2.0, 160.0, 76.0), Rect2(484.0, 18.0, 154.0, 50.0),
		Rect2(200.0, 76.0, 100.0, 56.0)]


#  상점: 왼쪽 위(골드 · 이자 · 사탕·사진) · 오른쪽 위(동전 · 정보 · 일시정지) ·
#  「구매」 + 값(오른끝) · 집은 매물 값 · 「막힌 칸 목표」(아래 가운데)
func _shop_spots() -> Array:
	return [Rect2(4.0, 4.0, 160.0, 62.0), Rect2(484.0, 4.0, 154.0, 48.0),
			Rect2(590.0, 160.0, 50.0, 40.0)]


func _shop_spots2() -> Array:
	var mid := Rect2(260.0, 220.0, 120.0, 52.0)
	var bi: int = g.buy_sel
	if bi >= 0 and bi < g.drop.size():
		var it: Dictionary = g.drop[bi]
		var by: float = g._p2g(it.w) + float(g.DROP.bill_dy) + float(g.BILL.dy)
		mid = Rect2(roundf(float(it.u)) - 50.0, roundf(by) - 30.0, 100.0, 42.0)
	return [mid, Rect2(250.0, 294.0, 120.0, 28.0), Rect2(80.0, 284.0, 110.0, 48.0)]


# ── 흐르는 띠 ─────────────────────────────────────────────
#  모션 켠 화면 − 끈 화면(×10, 회색 0.5 가 0). 깜박임 · 낟알은 이 칸에서만 0 으로 눌러
#  띠만 남긴다. 띠는 TIME 으로 흐르므로 위치는 그때그때다 — 두 칸 사이 2.5 초.
#  오른쪽 끝 띠는 행마다 평균 차이(밝을수록 띠 한가운데).
func _band() -> void:
	var cells := []
	var fl = _mat().get_shader_parameter("flick")     # 안 넣었으면 null — 되돌리면 기본값
	_mat().set_shader_parameter("flick", 0.0)
	for k in 2:
		g.motion_off = false
		g.crt = 1.0
		g._crt_apply()
		await _settle(2)
		var a: Image = root.get_texture().get_image()
		g.motion_off = true
		g._crt_apply()
		await _settle(2)
		var b: Image = root.get_texture().get_image()
		var w: int = a.get_width() / 2
		var d := Image.create(w + 24, a.get_height() / 2, false, Image.FORMAT_RGB8)
		var best := 0.0
		var at := 0
		for y in d.get_height():
			var row := 0.0
			for x in w:
				var ca: Color = a.get_pixel(x * 2, y * 2)
				var cb: Color = b.get_pixel(x * 2, y * 2)
				var v := ca.get_luminance() - cb.get_luminance()
				row += v
				d.set_pixel(x, y, Color(0.5 + v * 10.0, 0.5 + v * 10.0, 0.5 + v * 10.0))
			row /= float(w)
			for x in 24:
				d.set_pixel(w + x, y, Color(row * 40.0, row * 40.0, row * 20.0))
			if row > best:
				best = row
				at = y
		cells.append(d)
		print("  띠 %d — 행 평균이 가장 밝아진 자리 y %d(논리) · %.4f" % [k, at, best])
		await create_timer(2.5).timeout
	_mat().set_shader_parameter("flick", fl)
	_sheet(cells, 1).save_png("res://shots/retro_crt_band.png")


# ── 잔상 ─────────────────────────────────────────────────
#  층 99(CRT 밑)에 흰 네모 · 금빛 점을 세우고 틀마다 오른쪽으로 민다. 진짜 틀을 하나씩
#  넘겨야 앞 틀이 선다 — 시계를 손으로 미는 것이 아니라 틀을 기다린다.
class Mover extends Node2D:
	var x := 40.0
	func _draw() -> void:
		draw_rect(Rect2(x, 322.0, 10.0, 10.0), Color(1.0, 1.0, 1.0))
		draw_circle(Vector2(x - 4.0, 344.0), 3.0, Color(1.0, 0.8, 0.25))


func _trail() -> void:
	var lay := CanvasLayer.new()
	lay.layer = 99
	var mv := Mover.new()
	lay.add_child(mv)
	root.add_child(lay)
	#  게임이 CRT 층에 붙인 잔상 손(CrtTrail)은 이 칸 동안 떼어 둔다 — 「잔상 없음」 줄이 그것으로
	#  잔상을 내면 맞대는 뜻이 없다. 끝에 다시 붙인다(_ready 를 다시 돌려 신호를 잇는다).
	var own = g.crt_layer.get_node_or_null("CrtTrail")
	if own != null:
		g.crt_layer.remove_child(own)
	var tr = Trail.new()
	tr.mat = _mat()
	tr.layer = g.crt_layer
	var cells := []
	for case in [[false, 1.0], [true, 0.4], [true, 1.0]]:
		g.motion_off = false
		g.crt = float(case[1])
		g.warp = WARP_USER
		g._crt_apply()
		if bool(case[0]) and tr.get_parent() == null:
			g.add_child(tr)
		elif not bool(case[0]) and tr.get_parent() != null:
			tr.get_parent().remove_child(tr)
		mv.x = 40.0
		for f in 36:
			mv.x += 14.0
			mv.queue_redraw()
			await process_frame
		await RenderingServer.frame_post_draw
		var im: Image = root.get_texture().get_image()
		cells.append(_crop(im, Rect2(0.0, 300.0, 640.0, 56.0), 1))
		print("  잔상 %s · 세기 %.1f · 복사 %s · prev %s" % [case[0], float(case[1]),
				tr.err, _mat().get_shader_parameter("prev")])
	_sheet(cells, 1).save_png("res://shots/retro_crt_trail.png")
	if tr.get_parent() != null:
		tr.get_parent().remove_child(tr)
	tr.queue_free()
	lay.queue_free()
	_mat().set_shader_parameter("prev", null)
	if own != null:
		own.request_ready()
		g.crt_layer.add_child(own)
	g.motion_off = true
	g._crt_apply()


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 찍힌다")
		quit(0)
		return
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--old="):
			var p := String(a).substr(6)
			var f := FileAccess.open(p, FileAccess.READ)
			if f != null:
				sh_old = Shader.new()
				sh_old.code = f.get_as_text()
	sh_new = _mat().shader
	print("옛 판 %s · state %d" % ["있다" if sh_old != null else "없다", g.state])
	g.motion_off = true
	g._crt_apply()

	for wsz in [Vector2i(1280, 720), Vector2i(2560, 1440)]:
		hi = wsz.x > 2000
		sfx = "_hi" if hi else ""
		await _win(wsz)
		await _to_title()
		await _scene("title", TITLE_SPOTS)
		await _to_leg()
		await _scene("leg", LEG_SPOTS)
		if not hi:
			_mat().shader = sh_new
			await _band()
			await _trail()
		await _to_shop()
		await _scene("shop", _shop_spots())
		await _scene("shop2", _shop_spots2(), false)
	#  1920x1080(3배) — 전체화면에서 가장 흔한 배율. 상점 글 자리만.
	hi = true
	sfx = "_3x"
	await _win(Vector2i(1920, 1080))
	await _settle(6)
	await _scene("shop", _shop_spots(), false)
	_mat().shader = sh_new
	await _win(Vector2i(1280, 720))
	print("찍었다")
	quit(0)
