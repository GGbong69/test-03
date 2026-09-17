extends SceneTree
# 과녁 판(보드 확장 「과녁」 aimb)이 입는 옷을 찍는다 — 기본 · 칠 · 조준 밝힘(트리플 · 더블 ·
# 불 · 싱글) · 죽은 색 · 죽은 칸 · 띠 폭이 바뀐 판.
#   godot --path . --quit-after 9000 --script scripts/tools/shot_board_target.gd -- [접두사]
# 접두사를 안 주면 tg. 옛 판과 나란히 보려면 고치기 전에 `-- tgold` 로 한 번 찍는다.
# 조각 비교판은 scripts/tools/shot_board_target_sheet.py 가 만든다.
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false
var pre := "tg"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and String(args[0]) != "":
		pre = String(args[0])
	Save.gpath = "user://_shot_tg_g.cfg"
	Save.path = "user://_shot_tg.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if busy: return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _hold(n: int) -> void:
	for i in n:
		g._tutor_close()
		g.tutor_out = 0.0
		g.swap_live = false
		g.grip_t = 9.0
		g.mouse_at = Vector2(-50.0, -50.0)
		g.queue_redraw()
		await process_frame


func _snap(nm: String) -> void:
	root.get_texture().get_image().save_png("res://shots/%s_%s.png" % [pre, nm])


func _leg(mods: Array) -> void:
	g.set_process(true)
	g.mods_own = mods
	g._board_bake()
	g._start_leg()
	g._swap_skip()
	g.state = g.S.PICK
	g._pick_dart(0)
	await _wait(6)
	g.set_process(false)


#  칸 i 한가운데, 반지름 k(R 배수)인 점
func _at(i: int, k: float) -> Vector2:
	var a: float = float(i) * g._sec_w()
	return g.BC + Vector2(sin(a), -cos(a)) * g.R * k


func _plain(nm: String) -> void:
	g._bd3_close()
	g.state = g.S.PICK
	g.aim_dim = 0.0
	await _hold(8)
	await _snap(nm)


func _aim(nm: String, p: Vector2) -> void:
	g._bd3_close()
	g.state = g.S.AIM_H
	g.aim_mode = "std"
	g.aim = p
	g.aim_dim = 1.0
	await _hold(6)
	await _snap(nm)


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g._new_run()
	await _wait(20)
	await _leg(["aimb"])
	print("  판 = ", g._board_theme(), " · 칸 ", g._sec_n(), " · 불 배수 ", g.rt_m_bull)
	var base: Array = g.sec_col.duplicate()
	g.darts = [
		{"p": _at(1, 0.61), "id": "std", "rot": 0.10},
		{"p": _at(12, 0.40), "id": "std", "rot": 0.30},
		{"p": g.BC + Vector2(4.0, -3.0), "id": "std", "rot": -0.20},
	]
	await _plain("plain")
	# 칠 — 주홍 둘(이웃 한 쌍 · 먹 사이 하나) · 쪽빛 둘
	g.sec_col[3] = 2
	g.sec_col[4] = 2
	g.sec_col[9] = 3
	g.sec_col[15] = 3
	g.sec_col[17] = 2
	await _plain("paint")
	await _aim("aim_trp", _at(3, 0.61))
	await _aim("aim_dbl", _at(15, 0.95))
	await _aim("aim_bull", g.BC + Vector2(2.0, 3.0))
	await _aim("aim_x", g.BC + Vector2(1.0, 1.0))
	await _aim("aim_sgl", _at(7, 0.36))
	await _aim("aim_osgl", _at(10, 0.78))
	g.sec_col = base.duplicate()
	g.dead_col = 1
	await _plain("deadcol")
	g.dead_col = -1
	g.dead_idx = 5
	await _plain("deadidx")
	await _aim("deadidx_aim", _at(5, 0.61))
	g.dead_idx = -1
	# 띠 폭 1.6 배(띠 넓힘 제약과 같은 식)
	var tc: float = (g.trp_in + g.trp_out) * 0.5
	var tb: float = (g.trp_out - g.trp_in) * 0.5
	g.rt_trp_in = tc - tb * 1.6
	g.rt_trp_out = tc + tb * 1.6
	g.rt_dbl_in = g.dbl_out - (g.dbl_out - g.dbl_in) * 1.6
	await _plain("band")
	g._start_leg()
	g._swap_skip()
	g.state = g.S.PICK
	g.aim_dim = 0.0
	# 맞은 순간 — 판이 부푼다(짚 결을 다시 굽는 길)
	g.board_punch = 0.8
	g.hit_flash = 0.6
	g.hit_bull = false
	g.hit_idx = 1
	g.hit_r0 = g.R * g.rt_trp_in
	g.hit_r1 = g.R * g.rt_trp_out
	await _hold(1)
	g.board_punch = 0.8
	g.queue_redraw()
	await _wait(2)
	await _snap("punch")
	g.board_punch = 0.0
	g.hit_flash = 0.0
	# 판 갈이 — 누운 판이 올라오는 도중
	g.swap_live = true
	g.swap_in = true
	g.swap_scr = g.S.SHOP
	g.swap_t = float(g.SWAP.lead) + float(g.SWAP.rise) * 0.35
	g.queue_redraw()
	await _wait(2)
	await _snap("lie")
	g._swap_skip()
	g.darts = []
	print("  찍음")
	quit(0)
