extends SceneTree
#  다트판 벽 촬영 (2026-10-04 · game.gd 의 WALL3 · room3d.gd 의 make_wall).
#  shots/ 에(1280x720, 마지막 하나만 1440x900):
#    wall_pick.png      판 첫머리 — 벽 꽂이의 다트 줄을 고르는 화면(PICK)
#    wall_aimv.png      첫 축 조준(AIM_V)
#    wall_aimh.png      둘째 축 조준(AIM_H)
#    wall_fly.png       나는 다트(FLY) — 꽂힌 다트 셋이 판에 있다
#    wall_resolve.png   착탄 뒤 정산 걸음(RESOLVE)
#    wall_clear.png     판 정산(CLEAR) 덮개
#    wall_swap.png      판 갈이 한가운데(테이블이 빠지고 판이 선다)
#    wall_swap_b.png    판 갈이 끝무렵
#    wall_break.png     판 깨짐 — 판이 뜬 자리(벽에 남은 자국)
#    wall_off.png       벽을 끈 옛 화면(개발자 5쪽 「다트판 벽」)과 맞대기
#    wall_wide.png      1440x900(16:10) — 여백(view_pad)까지 덮는가
#  인자 -- off 이면 벽을 끄고 같은 이름 앞에 off_ 를 붙여 찍는다.
#  창이 있어야 돈다:  godot --path . --script scripts/tools/shot_wall.gd
const Save = preload("res://scripts/save.gd")
const DT := 1.0 / 120.0
var g = null
var busy := false
var pre := "wall_"
var off := false


func _initialize() -> void:
	var ua := OS.get_cmdline_user_args()
	if ua.has("off"):
		off = true
		pre = "off_wall_"
	Save.gpath = "user://_shot_wall_g.cfg"
	Save.path = "user://_shot_wall.cfg"
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
	g.mouse_at = Vector2(-50.0, -50.0)
	g._tutor_close()
	g.tutor_q.clear()


func _step(sec: float) -> void:
	var n: int = int(ceil(sec / DT))
	for k in n:
		_calm()
		g._process(DT)


func _shot(nm: String) -> void:
	g.queue_redraw()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://shots/%s%s.png" % [pre, nm])
	print("  %s%s · state %d · 벽 %s" % [pre, nm, g.state, str(g.get("wall3_on"))])


func _leg_pick() -> void:
	#  판 고르기 → 판(PICK). 판 갈이는 건너뛴다.
	g._swap_skip()
	g._begin_leg()
	g._swap_skip()
	_step(1.2)
	g.grip_t = 9.0


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 찍힌다")
		quit(0)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for id in ["u_leg", "u_skip", "u_boss", "u_score", "u_clear", "u_shop", "u_rack",
			"u_cons", "u_sell", "u_reroll", "u_give", "u_boot", "u_gift", "u_aim",
			"u_pick", "u_throw"]:
		Save.teach(id)
	g.set_process(false)
	if off and g.get("wall3_on") != null:
		g.wall3_on = false
	g._new_run(true)
	_calm()
	_step(1.5)
	await _wait(4)

	# ── 판 갈이 — 판 고르기에서 판으로 ──
	g._begin_leg()
	_step(0.02)
	await _wait(12)             # 벽이 처음 굽히는 틀 — 잡음 결이 앉을 틈
	_step(0.12)
	await _shot("swap")
	_step(0.12)
	await _shot("swap_b")
	g._swap_skip()
	_step(1.2)
	g.grip_t = 9.0

	# ── 판 첫머리(PICK) — 자루가 다 같은 종류면 곧장 조준이라 손으로 세운다 ──
	g.state = g.S.PICK
	g.grip_pick = -1
	await _shot("pick")

	# ── 조준 ──
	g._pick_dart(0)
	g._aim_begin()
	for i in 22:
		g._aim_tick(1.0 / 60.0)
	await _shot("aimv")
	g._advance()
	for i in 30:
		g._aim_tick(1.0 / 60.0)
	await _shot("aimh")

	# ── 꽂힌 다트를 깔고 나는 다트 ──
	var bc: Vector2 = g.BC
	var r: float = g.R
	g.darts = [
		{"p": bc + Vector2(4.0, -r * 0.58), "id": "std", "rot": 0.10},
		{"p": bc + Vector2(r * 0.50, r * 0.36), "id": "std", "rot": 0.30},
		{"p": bc + Vector2(-r * 0.44, r * 0.20), "id": "std", "rot": -0.22},
	]
	g._advance()
	var guard := 0
	while g.state != g.S.FLY and guard < 600:
		g._process(DT)
		guard += 1
	_step(0.05)
	await _shot("fly")
	guard = 0
	while g.state != g.S.RESOLVE and guard < 600:
		g._process(DT)
		guard += 1
	_step(0.25)
	await _shot("resolve")

	# ── 판 깨짐 — 뜬 자리 ──
	g._brk_skip()
	g.state = g.S.PICK
	g._brk_arm(2)
	g.brk_free = true
	guard = 0
	while not g.brk_fired and guard < 600:
		g._brk_tick(1.0 / 60.0)
		guard += 1
	for i in 26:
		g._brk_tick(1.0 / 60.0)
	await _shot("break")
	g._brk_skip()

	# ── 판 정산 ──
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
	_step(0.3)
	await _shot("clear")

	# ── 16:10 창 — 여백까지 ──
	g._click(Vector2(-1.0, -1.0))
	_step(2.5)
	g._tutor_close()
	g.tutor_q.clear()
	await _shot("shop")
	g._click(g._next_rect().get_center())
	_step(2.0)
	guard = 0
	while g.state == g.S.LEG and guard < 3:
		g._begin_leg()
		g._swap_skip()
		guard += 1
	_step(1.2)
	g.grip_t = 9.0
	DisplayServer.window_set_size(Vector2i(1440, 900))
	await _wait(8)
	g._view_fit()
	_step(0.02)
	await _wait(12)
	await _shot("wide")
	#  1920x1080 — 굽는 배율이 창 배율(3)을 따라가는가
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	await _wait(8)
	g._view_fit()
	_step(0.02)
	await _wait(12)
	await _shot("1080")
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await _wait(4)
	quit(0)
