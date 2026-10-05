extends SceneTree
#  「① 던지기 + ② 판 고르기」 촬영 (2026-10-05 · 던지기 화면 WALL3 「한 줄기 빛」 · 판 고르기
#  LEGB 「맞춤 다트 장」). 두 화면을 상점과 견준다.
#  shots/ 에(1280x720 · 게임 기본 화면 필터 CRT · 휨 · VHS · 도트 — 열두 틀을 넘겨 잔상이 앉은 뒤):
#    hybrid_throw.png        첫 축 조준(AIM_V) — 조준 줄
#    hybrid_pick.png         다트 고르기(PICK) — 앞서 던진 다트 둘이 판에 꽂혀 있고 꽂이 두 칸이 비었다
#    hybrid_leg.png          라운드 1 판 고르기(셋째 판이 보스 · 막힌 칸)
#    hybrid_leg_hover.png    보스 판에 커서
#    hybrid_legdone.png      라운드 1 의 보스 차례 — 첫 판 클리어 · 둘째 판 건너뜀
#    hybrid_pick_strip.png   여덟 박자 — 「던진다」 → 상인이 판을 집는다 → 판 갈이 → 벽에 판이 선다
#    hybrid_clear_strip.png  여덟 박자 — 마지막 다트 → 정산 → 덮개 → 상점
#    hybrid_shop.png         상점(견줌 — 안 바뀐다)
#    hybrid_1440.png         던지기 1440x900 · hybrid_219.png 던지기 1920x820(21:9)
#    hybrid_throw_off.png · hybrid_leg_off.png   필터 넷 다 0
#  덤(맞춰 볼 거리 — hybrid_x_ 앞붙이):
#    x_wide          라운드 8(목표 다섯 자리) 판 고르기
#    x_bignow        라운드 1 둘째 판 — 큰 판이 지금 판(뜸 · 1.08 배)일 때 판과 밑 글
#    x_dealflip      딜 네 박자 · 건너뛰기(판을 엎는다) 네 박자
#    x_over · x_title  런 끝 · 제목의 판(같은 BOARDART 숫자 고리 · 테)
#    x_mods          보스 제약마다의 판 얼굴 · 긴 보스 이름
#    x_swapmid       판 갈이 한가운데(테이블이 빠지고 판이 아직 누워 있다 — 받침판 · 걸쇠)
#    x_break         판 깨짐 — 판이 뜬 자리(받침판 · 걸쇠)
#    x_shake         흔들림 한가운데 — 1:1 벽 결이 안 일렁이는가
#    x_43 · x_1080   1024x768 · 1920x1080 던지기
#    x_swapfine      「던진다」 뒤 판 갈이 여덟 박자(0.03 초 간격) — 빛이 한 번에 옮겨 가는가
#    x_swap1610 · x_swap219 · x_swap43   16:10 · 21:9 · 4:3 판 갈이 세 박자(0.06 · 0.12 · 0.18) —
#                    여백에 카운터 조각 · 누운 판이 안 남는가
#    x_throwboss     보스 판(막힌 칸)을 던지는 화면 — 벽 판의 참나무 쪽
#    x_shopwipe      상점 → 판 고르기 덮개가 걷히는 세 박자 — 가운데 판이 먼저 빠진다
#    x_revswap       움직임 끔 — 정산 → 상점이 거꾸로 타는 판 갈이 여덟 박자(램프가 판과 같이 꺼진다)
#  인자 only=leg · only=throw · only=strip · only=size — 한 갈래만 찍는다(빛 · 재질 맞출 때).
#  창이 있어야 돈다:  godot --path . --script scripts/tools/shot_hybrid.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const DT := 1.0 / 120.0
var g = null
var busy := false
var pre := "hybrid"
var only := ""
var hov_at := Vector2(-50.0, -50.0)
var hov_on := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=", true, 1)
		if kv.size() == 2 and kv[0] == "pre":
			pre = kv[1]
		elif kv.size() == 2 and kv[0] == "only":
			only = kv[1]
	Save.gpath = "user://_shot_hybrid_g.cfg"
	Save.path = "user://_shot_hybrid.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	seed(20261005)


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
	g.npc_eye = 0.0
	g.mouse_at = hov_at
	g._tutor_close()
	g.tutor_q.clear()


func _hov() -> void:
	if not hov_on:
		return
	g.mouse_at = hov_at
	g._tip_build(g._tip_hit(hov_at))
	g.tip_a = 1.0


func _step(sec: float) -> void:
	var n: int = int(ceil(sec / DT))
	for _k in n:
		_calm()
		g._process(DT)


#  벽 굽기를 끝낸다 — 도구는 g 의 _process 를 손으로 부르므로 그려진 틀마다 한 번씩 민다.
func _bake() -> void:
	var guard := 0
	while int(g.wall3_fresh) > 0 and guard < 60:
		g._wall3_tick()
		await process_frame
		guard += 1


#  [CRT, 휨, VHS, 도트]
func _filt(on: bool) -> void:
	if on:
		g.crt = float(g.CRT_DEF)
		g.warp = float(g.WARP_DEF)
		g.vhs = float(g.VHS_DEF)
		g.dot = float(g.DOT_DEF)
	else:
		g.crt = 0.0
		g.warp = 0.0
		g.vhs = 0.0
		g.dot = 0.0
	g._crt_apply()
	if g.vhs_rect != null:
		var vm := g.vhs_rect.material as ShaderMaterial
		if vm != null:
			vm.set_shader_parameter("clock", 0.5)


#  그리기(손 자세를 셈한다) → 맞추기(3D 손에 옮긴다 · 시계는 0) → 그리기 — 열두 틀을 넘겨
#  화면 필터의 잔상이 가라앉은 뒤 찍는다.
func _grab() -> Image:
	await _bake()
	for _k in 12:
		_calm()
		g._process(0.0)
		_hov()
		g.queue_redraw()
		var fr = g.get_node_or_null("Front")
		if fr != null:
			fr.queue_redraw()
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _shot(nm: String, on := true) -> void:
	_filt(on)
	var im: Image = await _grab()
	im.save_png("res://shots/%s_%s.png" % [pre, nm])
	print("  %s_%s · %dx%d · state %d" % [pre, nm, im.get_width(), im.get_height(), g.state])


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
	g.wipe_t = -1.0
	g.leg_skipped = {}
	for s in skipped:
		g.leg_skipped[int(s)] = true
	g.leg_no = no
	g.state = g.S.LEG
	g._open_leg()
	g._turn_skip()
	if settle:
		_step(1.6)


#  판을 열고(PICK) 앞서 던진 둘을 판에 꽂는다.
func _play(no: int) -> void:
	_leg(no, [])
	await _bake()
	g.legb_force = false
	g._swap_skip()
	g._begin_leg()
	g._swap_skip()
	_step(1.2)
	g.grip_t = 9.0
	var bc: Vector2 = g.BC
	var r: float = g.R
	g.darts = [
		{"p": bc + Vector2(r * 0.42, -r * 0.30), "id": "std", "rot": 0.18},
		{"p": bc + Vector2(-r * 0.24, r * 0.52), "id": "std", "rot": -0.20},
	]
	for _k in 2:
		if g.remaining.size() > 1:
			g.remaining.remove_at(0)
			g.grip_slot.remove_at(0)
	g.darts_left = g.remaining.size()
	g.state = g.S.PICK
	g.grip_pick = -1
	g.legb_force = true


func _aim() -> void:
	g._pick_dart(0)
	g._aim_begin()
	for _i in 22:
		g._aim_tick(1.0 / 60.0)


#  시계를 want 까지 밀며 찍는다(필터 켬 · 반 크기).
func _strip(times: Array) -> Array:
	_filt(true)
	var cells := []
	var tt := 0.0
	for want in times:
		while tt < float(want) - 0.0001:
			_calm()
			g._process(DT)
			tt += DT
		var im: Image = await _grab()
		cells.append(_half(im))
		print("  %.2f · state %d · leg_t %.2f · 집기 %.2f · 갈이 %s %.2f · 덮개 %.2f" % [tt, g.state,
				g.leg_t, g.legb_pick_t, g.swap_live, g.swap_t, g.wipe_t])
	return cells


func _size(sz: Vector2i, nm: String) -> void:
	DisplayServer.window_set_size(sz)
	await _wait(8)
	if Vector2i(root.size) != sz:
		root.size = sz
		await _wait(4)
	g._view_fit()
	_step(0.02)
	await _wait(4)
	await _shot(nm)


#  지금 창에서 판 갈이(손 없이 곧장 — _begin_leg)를 연 뒤 times 박자마다 찍어 한 장으로.
func _swapmid(nm: String, times: Array) -> void:
	_leg(1, [])
	await _bake()
	g.legb_force = false
	g._begin_leg()
	_filt(true)
	var cells := []
	var tt := 0.0
	for want in times:
		while tt < float(want) - 0.0001:
			_calm()
			g._process(DT)
			tt += DT
		cells.append(_half(await _grab()))
		print("  %s %.2f · 갈이 %s %.3f · 선 %.2f · 빠진 %.2f" % [nm, tt, g.swap_live, g.swap_t,
				g._swap_rise(), g._swap_gone()])
	_sheet(cells, cells.size()).save_png("res://shots/%s_%s.png" % [pre, nm])
	g._swap_skip()
	g.legb_force = true


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 찍힌다")
		quit(0)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _wait(8)
	for id in ["u_leg", "u_skip", "u_boss", "u_score", "u_clear", "u_shop", "u_rack",
			"u_cons", "u_sell", "u_reroll", "u_give", "u_boot", "u_gift", "u_aim",
			"u_pick", "u_throw", "u_more", "u_info", "u_last"]:
		Save.teach(id)
	g.set_process(false)
	g.motion_off = false
	g.legb_force = true
	g._new_run(true)
	_step(1.5)
	await _wait(4)
	var bn: int = g._round_boss()
	g.boss_mods[bn] = PackedStringArray(["dead"])

	# ── 판 고르기 ──
	if only == "" or only == "leg":
		_leg(1, [])
		await _shot("leg")
		await _shot("leg_off", false)
		hov_at = g._row_rect(GameData.leg_idx(bn), GameData.legs_per_round()).get_center()
		hov_on = true
		await _shot("leg_hover")
		hov_on = false
		hov_at = Vector2(-50.0, -50.0)
		g.tip_a = 0.0
		_leg(3, [2])
		await _shot("legdone")
		_leg(2, [])
		await _shot("x_bignow")
		#  딜 넷 · 엎기 넷 — 손이 판을 놓는 틀 · 판을 엎는 한가운데(뒷면이 서는 틀)
		_leg(1, [], false)
		var df: Array = await _strip([0.08, 0.20, 0.36, 0.60])
		_leg(1, [])
		g._skip_leg()
		df.append_array(await _strip([0.06, 0.12, 0.18, 0.40]))
		_sheet(df, 4).save_png("res://shots/%s_x_dealflip.png" % pre)
		#  라운드 8 — 목표 다섯 자리
		var keep_mods: Dictionary = g.boss_mods.duplicate()
		_leg(22, [])
		await _shot("x_wide")
		print("  라운드 8 — 목표 %s · %s · %s" % [g._target_at(22), g._target_at(23), g._target_at(24)])
		g.boss_mods = keep_mods
		#  보스 제약마다 — 판 얼굴 · 이름
		var cells := []
		_filt(true)
		for ids in [["dead"], ["shade"], ["odd"], ["narrow"], ["flat"], ["turn"], ["gust"],
				["tgt"], ["dead", "odd"]]:
			g.boss_mods[bn] = PackedStringArray(ids)
			g.boss_void.erase(bn)
			_leg(1, [])
			cells.append(_crop(await _grab(), Rect2(400.0, 120.0, 200.0, 150.0)))
		g.boss_mods[bn] = PackedStringArray(["tgt"])
		g.boss_void[bn] = true
		_leg(1, [])
		cells.append(_crop(await _grab(), Rect2(400.0, 120.0, 200.0, 150.0)))
		g.boss_void.erase(bn)
		_leg(3, [])
		cells.append(_crop(await _grab(), Rect2(400.0, 120.0, 200.0, 150.0)))
		_sheet(cells, 4).save_png("res://shots/%s_x_mods.png" % pre)
		g.boss_mods[bn] = PackedStringArray(["dead"])
		if only == "leg":
			_filt(false)
			quit(0)
			return

	# ── 집기 → 판 갈이 → 벽에 판이 선다 ──
	if only == "" or only == "strip":
		_leg(1, [])
		await _bake()
		g._leg_commit()
		var pick: Array = await _strip([0.0, 0.18, 0.30, 0.36, 0.42, 0.48, 0.56, 0.80])
		_sheet(pick, 4).save_png("res://shots/%s_pick_strip.png" % pre)
		g._swap_skip()
		#  판 갈이 한가운데 — 판을 뗀 벽(받침판 · 걸쇠)이 비치는 틀
		_leg(1, [])
		await _bake()
		g.legb_force = false
		g._begin_leg()
		_step(0.16)
		await _shot("x_swapmid")
		g._swap_skip()
		g.legb_force = true
		#  「던진다」 뒤 판 갈이를 촘촘히 — 들기 시작한 틀(LEGH.go 0.30)에 판 갈이가 열린다
		_leg(1, [])
		await _bake()
		g._leg_commit()
		var fine: Array = await _strip([0.30, 0.33, 0.36, 0.39, 0.42, 0.45, 0.50, 0.58])
		_sheet(fine, 4).save_png("res://shots/%s_x_swapfine.png" % pre)
		g._swap_skip()

	# ── 던지기 ──
	if only == "" or only == "throw" or only == "strip":
		await _play(1)
		await _shot("pick")
		_aim()
		await _shot("throw")
		await _shot("throw_off", false)
		#  흔들림 — 1:1 벽 결이 틀마다 일렁이지 않는가(반 px 흔들림 두 틀을 견준다)
		g.shake = 6.0
		_step(0.03)
		await _shot("x_shake")
		g.shake = 0.0
		_step(0.5)
		#  판 깨짐 — 판이 뜬 자리
		g._brk_skip()
		g.state = g.S.PICK
		g._brk_arm(2)
		g.brk_free = true
		var guard := 0
		while not g.brk_fired and guard < 600:
			g._brk_tick(1.0 / 60.0)
			guard += 1
		for _i in 26:
			g._brk_tick(1.0 / 60.0)
		await _shot("x_break")
		g._brk_skip()
		#  보스 판(막힌 칸)을 던진다 — 벽 판의 참나무 쪽
		await _play(3)
		_aim()
		await _shot("x_throwboss")

	# ── 마지막 다트 → 정산 → 덮개 → 상점 ──
	if only == "" or only == "strip":
		await _play(1)
		g.darts = []
		while g.remaining.size() > 1:
			g.remaining.remove_at(0)
			g.grip_slot.remove_at(0)
		g.darts_left = g.remaining.size()
		g.total = maxi(g.target - 1, 0)
		_aim()
		g._advance()
		for _i in 30:
			g._aim_tick(1.0 / 60.0)
		g._advance()
		#  확인 걸음 — 조준은 안 움직인다. 판 위 20 칸에 꽂혀 목표를 넘기게 한다.
		g.aim = g.BC + Vector2(2.0, -g.R * 0.40)
		var guard := 0
		while g.state != g.S.FLY and guard < 600:
			g._process(DT)
			guard += 1
		_step(0.04)
		var cells := []
		_filt(true)
		cells.append(_half(await _grab()))
		print("  날기 — state %d" % g.state)
		guard = 0
		while g.state == g.S.FLY and guard < 600:
			_calm()
			g._process(DT)
			guard += 1
		_step(0.10)
		cells.append(_half(await _grab()))
		print("  착탄 — state %d · 합 %d / %d" % [g.state, g.total, g.target])
		guard = 0
		while g.state != g.S.CLEAR and guard < 2400:
			_calm()
			g._process(DT)
			guard += 1
		if g.state != g.S.CLEAR:
			print("  정산 안 섰다 — 손으로 민다 (state %d)" % g.state)
			g._brk_skip()
			g.total = g.target
			g.darts_left = 0
			g.remaining.clear()
			g._finish_leg()
			guard = 0
			while g.state != g.S.CLEAR and guard < 900:
				_calm()
				g._process(DT)
				g._swap_skip()
				guard += 1
		_step(0.25)
		cells.append(_half(await _grab()))
		g.clear_t = 99.0
		_step(0.3)
		cells.append(_half(await _grab()))
		g.wipe_force = true
		g._click(Vector2(-1.0, -1.0))
		cells.append_array(await _strip([0.08, 0.40, 0.72]))
		_step(1.2)
		g.wipe_force = false
		g._tutor_close()
		g.tutor_q.clear()
		cells.append(_half(await _grab()))
		_sheet(cells, 4).save_png("res://shots/%s_clear_strip.png" % pre)
		print("  정산 띠 — state %d" % g.state)
		#  움직임 끔 — 정산 → 상점은 덮개 대신 거꾸로 판 갈이를 탄다
		await _play(1)
		g._brk_skip()
		g.total = g.target
		g.darts_left = 0
		g.remaining.clear()
		g._finish_leg()
		guard = 0
		while g.state != g.S.CLEAR and guard < 900:
			_calm()
			g._process(DT)
			g._swap_skip()
			guard += 1
		g.clear_t = 99.0
		_step(0.1)
		g.motion_off = true
		g._click(Vector2(-1.0, -1.0))
		print("  거꾸로 판 갈이 — 갈이 %s · 들어감 %s · state %d" % [g.swap_live, g.swap_in, g.state])
		var rv: Array = await _strip([0.0, 0.03, 0.07, 0.11, 0.16, 0.22, 0.30, 0.40])
		_sheet(rv, 4).save_png("res://shots/%s_x_revswap.png" % pre)
		g.motion_off = false
		g._swap_skip()

	# ── 상점(견줌) ──
	if only == "":
		g.darts = []
		g._swap_skip()
		g.wipe_t = -1.0
		g.state = g.S.SHOP
		g.leg_no = 1
		g.gold = 24
		g._open_shop()
		_step(2.5)
		await _shot("shop")
		#  상점 → 판 고르기 덮개가 걷히는 세 박자
		g.wipe_force = true
		g._wipe(Callable(g, "_shop_go"))
		var sw: Array = await _strip([0.70, 0.76, 0.82])
		_sheet(sw, 3).save_png("res://shots/%s_x_shopwipe.png" % pre)
		_step(0.6)
		g.wipe_force = false
		g._tutor_close()
		g.tutor_q.clear()
		#  제목 · 런 끝 — 같은 판 그림(BOARDART 숫자 고리 · 테)을 쓴다
		g.state = g.S.OVER
		g.over_t = 9.0
		g.won = false
		_step(0.1)
		await _shot("x_over")
		g.state = g.S.TITLE
		_step(0.5)
		await _shot("x_title")

	# ── 창 크기 ──
	if only == "" or only == "size" or only == "throw":
		await _play(1)
		_aim()
		await _size(Vector2i(1440, 900), "1440")
		await _swapmid("x_swap1610", [0.06, 0.12, 0.18])
		await _play(1)
		_aim()
		await _size(Vector2i(1920, 820), "219")
		await _swapmid("x_swap219", [0.06, 0.12, 0.18])
		if only != "throw":
			await _play(1)
			_aim()
			await _size(Vector2i(1024, 768), "x_43")
			await _swapmid("x_swap43", [0.06, 0.12, 0.18])
			await _play(1)
			_aim()
			await _size(Vector2i(1920, 1080), "x_1080")
		DisplayServer.window_set_size(Vector2i(1280, 720))
		await _wait(6)
	_filt(false)
	print("찍었다 — %s_*" % pre)
	quit(0)
