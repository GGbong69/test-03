extends SceneTree
#  「한 줄기 빛」 촬영 (2026-10-04 · 던지기 화면 WALL3 · 판 고르기 LEGB).
#  「아... 좀 촌스러운데..? 좀 세련된 디자인 없어?」 — 두 화면을 상점과 견준다.
#  shots/ 에(1280x720 · 게임 기본 화면 필터 CRT · 휨 · VHS · 도트):
#    design_noir_throw.png      첫 축 조준(AIM_V) — 조준 줄
#    design_noir_pick.png       다트 고르기(PICK) — 앞서 던진 다트 둘이 판에 꽂혀 있고 꽂이 두 칸이 비었다
#    design_noir_leg.png        라운드 1 판 고르기(셋째 판이 보스 · 막힌 칸)
#    design_noir_legdone.png    라운드 1 의 보스 차례 — 첫 판 클리어 · 둘째 판 건너뜀
#    design_noir_shop.png       상점(견줌 — 안 바뀐다)
#    design_noir_throw_off.png · design_noir_leg_off.png   필터 넷 다 0
#  인자 pre=이름 이면 design_noir 대신 그 이름으로 찍는다(고치기 전 · 뒤 견줄 때).
#  창이 있어야 돈다:  godot --path . --script scripts/tools/shot_noir.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const DT := 1.0 / 120.0
var g = null
var busy := false
var pre := "design_noir"
var only := ""            # only=throw · only=leg — 한쪽만 찍는다(빛 · 재질 맞출 때)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := String(a).split("=", true, 1)
		if kv.size() == 2 and kv[0] == "pre":
			pre = kv[1]
		elif kv.size() == 2 and kv[0] == "only":
			only = kv[1]
	Save.gpath = "user://_shot_noir_g.cfg"
	Save.path = "user://_shot_noir.cfg"
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
	g.mouse_at = Vector2(-50.0, -50.0)
	g._tutor_close()
	g.tutor_q.clear()


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
func _shot(nm: String, on := true) -> void:
	_filt(on)
	await _bake()
	for _k in 12:
		_calm()
		g._process(0.0)
		g.queue_redraw()
		var fr = g.get_node_or_null("Front")
		if fr != null:
			fr.queue_redraw()
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://shots/%s_%s.png" % [pre, nm])
	print("  %s_%s · state %d" % [pre, nm, g.state])


#  판 고르기를 연다 — no 판 · 건너뛴 판들. 딜을 다 돌린다.
func _leg(no: int, skipped: Array) -> void:
	g._swap_skip()
	g.leg_skipped = {}
	for s in skipped:
		g.leg_skipped[int(s)] = true
	g.leg_no = no
	g.state = g.S.LEG
	g._open_leg()
	g._turn_skip()
	_step(1.6)


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

	# ── 판 고르기 — 쉬는 모습 ──
	if only != "throw":
		_leg(1, [])
		await _shot("leg")
		await _shot("leg_off", false)

		# ── 판 고르기 — 지난 판(클리어 · 건너뜀) ──
		_leg(3, [2])
		await _shot("legdone")
		if only == "leg":
			_filt(false)
			quit(0)
			return

	# ── 던지기 — 판 고르기에서 판으로 ──
	_leg(1, [])
	await _bake()
	g.legb_force = false
	g._swap_skip()
	g._begin_leg()
	g._swap_skip()
	_step(1.2)
	g.grip_t = 9.0
	#  앞서 던진 둘 — 판에 꽂혀 있고 꽂이 위 두 칸이 비었다.
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
	await _shot("pick")
	g._pick_dart(0)
	g._aim_begin()
	for _i in 22:
		g._aim_tick(1.0 / 60.0)
	await _shot("throw")
	await _shot("throw_off", false)

	# ── 상점(견줌) ──
	g.darts = []
	g._swap_skip()
	g.state = g.S.SHOP
	g.leg_no = 1
	g.gold = 24
	g._open_shop()
	_step(2.5)
	await _shot("shop")
	_filt(false)
	print("찍었다 — %s_*" % pre)
	quit(0)
