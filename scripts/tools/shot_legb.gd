extends SceneTree
#  판 고르기 다트판 촬영 (2026-10-04 · game.gd 의 LEGB · LEGH).
#  shots/ 에:
#    legb_rest.png         라운드 1 — 작은 판(지금) · 큰 판 · 보스(막힌 칸 판자) 쉬는 모습
#    legb_hover.png        보스 판에 커서 — 쇠테가 달아오르고 툴팁이 뜬다
#    legb_deal.png         딜 한가운데 — 두 손이 판을 들고 와 내려놓는다
#    legb_deal_strip.png   딜 여덟 박자
#    legb_done.png         라운드 1 의 보스 — 첫 판은 깨져 다트가 꽂혔고 둘째 판은 엎었다
#    legb_flip_strip.png   건너뛰기 — 판을 엎는다
#    legb_pick_strip.png   집기 — 「던진다」 를 누르면 손이 판을 집어 들고 판 갈이로 간다(작은 판)
#    legb_pick.png         집기 한가운데(든 판) 온 화면
#    legb_pick_mid.png     집기 — 가운데 큰 판(오른손) · 보스(오른손) 한 장씩
#    legb_mods.png         보스 제약마다의 판 얼굴(보스 칸을 2배로)
#    legb_1440.png         1440x900 창
#    legb_shop.png         같은 런의 상점(견줌)
#  창이 있어야 돈다:  godot --path . --script scripts/tools/shot_legb.gd
#  시계는 손으로 민다(게임 _process 를 끄고 1/120 초씩). 검사 도구라 연출이 꺼져 뜨므로
#  legb_force 로 켠다(손 · 엎기). 3D 손은 _process 가 지난 그림의 자세를 화판에 옮기므로
#  한 장마다 그리기 → 맞추기 → 그리기 순서로 찍는다(_shot).
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const DT := 1.0 / 120.0
var g = null
var busy := false
var hov_at := Vector2(-50.0, -50.0)
var hov_on := false


func _initialize() -> void:
	Save.gpath = "user://_shot_legb_g.cfg"
	Save.path = "user://_shot_legb.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	seed(20261004)


func _process(_d: float) -> bool:
	if g != null:
		g.hover_live = false
		g.tip_pin = {}
		if not hov_on:
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
	g.mouse_at = hov_at
	g._tutor_close()
	g.tutor_q.clear()


func _step(sec: float) -> void:
	var n: int = int(ceil(sec / DT))
	for k in n:
		_calm()
		g._process(DT)


func _hov() -> void:
	if not hov_on:
		return
	g.mouse_at = hov_at
	g._tip_build(g._tip_hit(hov_at))
	g.tip_a = 1.0


#  그리기(손 자세를 셈한다) → 맞추기(3D 손에 옮긴다 · 시계는 0) → 그리기 → 찍기.
func _shot() -> Image:
	for k in 2:
		_calm()
		_hov()
		g.queue_redraw()
		await process_frame
		_calm()
		g._process(0.0)
		_hov()
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _half(im: Image) -> Image:
	var c := im.duplicate() as Image
	c.resize(im.get_width() / 2, im.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	return c


func _crop(im: Image, r: Rect2) -> Image:
	var s: float = float(im.get_width()) / 640.0
	return im.get_region(Rect2i(int(r.position.x * s), int(r.position.y * s),
			int(r.size.x * s), int(r.size.y * s)))


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
		var ci: Image = cells[i]
		sh.blit_rect(ci, Rect2i(0, 0, mini(cw, ci.get_width()), mini(ch, ci.get_height())),
				Vector2i((i % cols) * (cw + gap), (i / cols) * (ch + gap)))
	return sh


#  판 고르기를 연다 — no 판 · 건너뛴 판들. 딜을 다 돌린다.
func _leg(no: int, skipped: Array, settle := true) -> void:
	g._swap_skip()
	g.leg_skipped = {}
	for s in skipped:
		g.leg_skipped[int(s)] = true
	g.leg_no = no
	g.state = g.S.LEG
	g._open_leg()
	g._turn_skip()
	if settle:
		_step(1.3)


#  시계를 want 까지 밀며 찍는다 — 판 갈이로 넘어가도 계속 민다.
func _strip(times: Array, crop := Rect2()) -> Array:
	var cells := []
	var tt := 0.0
	for want in times:
		while tt < float(want) - 0.0001:
			_calm()
			g._process(DT)
			tt += DT
		var im: Image = await _shot()
		cells.append(_crop(im, crop) if crop.size.x > 0.0 else _half(im))
		print("  %.2f · state %d · leg_t %.2f · 집기 %.2f · 갈이 %s" % [tt, g.state, g.leg_t,
				g.legb_pick_t, g.swap_live])
	return cells


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 찍힌다")
		quit(0)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for id in ["u_leg", "u_skip", "u_boss", "u_score", "u_clear", "u_shop", "u_rack",
			"u_cons", "u_sell", "u_reroll", "u_give", "u_boot", "u_gift"]:
		Save.teach(id)
	g.set_process(false)
	g.legb_force = true
	g._new_run(true)
	_step(1.5)
	await _wait(4)
	var bn: int = g._round_boss()
	g.boss_mods[bn] = PackedStringArray(["dead"])

	# ── 쉬는 모습 ──
	_leg(1, [])
	(await _shot()).save_png("res://shots/legb_rest.png")
	print("쉼 — 판 %d · 보스 %d %s" % [g.leg_no, bn, g.boss_mods[bn]])

	# ── 보스에 커서 ──
	hov_at = g._row_rect(GameData.leg_idx(bn), GameData.legs_per_round()).get_center()
	hov_on = true
	(await _shot()).save_png("res://shots/legb_hover.png")
	print("얹힘 — %s · tip_a %.2f" % [g._tip_hit(hov_at), g.tip_a])
	hov_on = false
	hov_at = Vector2(-50.0, -50.0)

	# ── 딜 ──
	_leg(1, [], false)
	var deal: Array = await _strip([0.04, 0.12, 0.20, 0.28, 0.36, 0.46, 0.60, 0.90])
	_sheet(deal, 4).save_png("res://shots/legb_deal_strip.png")
	_leg(1, [], false)
	_step(0.24)
	(await _shot()).save_png("res://shots/legb_deal.png")

	# ── 지난 판 ──
	_leg(3, [2])
	(await _shot()).save_png("res://shots/legb_done.png")

	# ── 건너뛰기 — 엎는다 ──
	_leg(1, [])
	g._skip_leg()
	var flip: Array = await _strip([0.0, 0.06, 0.12, 0.18, 0.24, 0.40],
			Rect2(60.0, 130.0, 360.0, 140.0))
	_sheet(flip, 3).save_png("res://shots/legb_flip_strip.png")

	# ── 집기 ──
	_leg(1, [])
	g._leg_commit()
	var pick: Array = await _strip([0.02, 0.10, 0.18, 0.24, 0.32, 0.42, 0.52, 0.60, 0.66, 0.74])
	_sheet(pick, 4).save_png("res://shots/legb_pick_strip.png")
	g._swap_skip()
	_leg(1, [])
	g._leg_commit()
	_step(0.47)
	(await _shot()).save_png("res://shots/legb_pick.png")
	g._swap_skip()
	var mid := []
	_leg(2, [])
	g._leg_commit()
	mid.append_array(await _strip([0.20, 0.40, 0.56]))
	g._swap_skip()
	_leg(3, [])
	g._leg_commit()
	mid.append_array(await _strip([0.20, 0.40, 0.56]))
	g._swap_skip()
	_sheet(mid, 3).save_png("res://shots/legb_pick_mid.png")

	# ── 보스 제약마다 ──
	var cells := []
	for ids in [["dead"], ["shade"], ["odd"], ["narrow"], ["flat"], ["turn"], ["gust"],
			["tgt"], ["dead", "odd"]]:
		g.boss_mods[bn] = PackedStringArray(ids)
		g.boss_void.erase(bn)
		_leg(1, [])
		cells.append(_crop(await _shot(), Rect2(398.0, 140.0, 180.0, 126.0)))
	g.boss_mods[bn] = PackedStringArray(["tgt"])
	g.boss_void[bn] = true
	_leg(1, [])
	cells.append(_crop(await _shot(), Rect2(398.0, 140.0, 180.0, 126.0)))
	g.boss_void.erase(bn)
	_leg(3, [])
	cells.append(_crop(await _shot(), Rect2(398.0, 140.0, 180.0, 126.0)))
	_leg(4, [])
	cells.append(_crop(await _shot(), Rect2(398.0, 140.0, 180.0, 126.0)))
	_sheet(cells, 4).save_png("res://shots/legb_mods.png")
	g.boss_mods[bn] = PackedStringArray(["dead"])

	# ── 1440x900 ──
	DisplayServer.window_set_size(Vector2i(1440, 900))
	await _wait(8)
	_leg(1, [])
	(await _shot()).save_png("res://shots/legb_1440.png")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _wait(8)

	# ── 상점(견줌) ──
	g._swap_skip()
	g._open_shop()
	_step(2.0)
	g.gold = 99
	_step(0.3)
	(await _shot()).save_png("res://shots/legb_shop.png")
	print("찍음")
	quit(0)
