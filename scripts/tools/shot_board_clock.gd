extends SceneTree
# 시계 판(보드 확장 「시계」)이 입는 옷 — 기본 · 칠 · 조준 밝힘(트리플 · 더블 · 싱글 · 불) ·
# 죽은 색(그늘) · 죽은 칸(막힌 칸). 창이 있어야 찍힌다.
#   godot --path . --quit-after 9000 --script scripts/tools/shot_board_clock.gd -- <접두>
# 끝에 죽은 크림 칸(dead_cream) · 실띠 0.5 / 넓은 판 1.5 의 트리플 조준(band_05 · band_15)도 찍는다.
# 접두를 안 주면 ck_ 로 찍는다(고치기 전 판을 ck_old_ 로 찍어 두고 견준다).
# 견줌 장: python scripts/tools/sheet_board_clock.py [새 접두] [옛 접두] [사이 접두 …]
#   → shots/ck_sheet.png(줄마다 접두 하나) · ck_sheet_1x.png(게임 한 배 크기) · ck_plain_x2.png
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false
var pre := "ck_"


func _initialize() -> void:
	var ua := OS.get_cmdline_user_args()
	if not ua.is_empty():
		pre = String(ua[0])
	Save.gpath = "user://_shot_ck_g.cfg"
	Save.path = "user://_shot_ck.cfg"
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
	root.get_texture().get_image().save_png("res://shots/%s%s.png" % [pre, nm])


func _pol(sec: float, rr: float) -> Vector2:
	var a: float = sec * g._sec_w()
	return g.BC + Vector2(sin(a), -cos(a)) * g.R * rr


func _plain() -> void:
	g.state = g.S.PICK
	g.aim_dim = 0.0
	g.aim_glow_last = Vector2(-9999.0, -9999.0)


func _aim_at(p: Vector2) -> void:
	g.state = g.S.AIM_H
	g.aim_mode = "std"
	g.aim = p
	g.aim_dim = 1.0


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g._new_run()
	await _wait(20)
	g.set_process(true)
	g.mods_own = ["clok"]
	g._board_bake()
	g._start_leg()
	g._swap_skip()
	g.state = g.S.PICK
	g._pick_dart(0)
	await _wait(6)
	g.set_process(false)
	print("  판 옷=", g._board_theme(), " 칸=", g._sec_n())
	var nsc: int = g.sec_col.size()
	var base_col: Array = g.sec_col.duplicate()
	g.darts = [
		{"p": _pol(0.1, 0.61), "id": "std", "rot": 0.10},
		{"p": _pol(6.3, 0.46), "id": "std", "rot": 0.30},
		{"p": _pol(13.0, 0.95), "id": "std", "rot": -0.20},
	]
	g._bd3_close()

	_plain()
	await _hold(8)
	await _snap("plain")

	#  칠 — 주홍(2) 한 칸 · 쪽빛(3) 한 칸
	g.sec_col[3] = 2
	g.sec_col[nsc - 2] = 3
	_plain()
	await _hold(6)
	await _snap("paint")

	#  조준 밝힘 — 트리플(밝은 칸) · 더블(어두운 칸) · 바깥 싱글 · 불
	_aim_at(_pol(2.0, 0.61))
	await _hold(6)
	await _snap("aim_trp")
	_aim_at(_pol(5.0, 0.95))
	await _hold(6)
	await _snap("aim_dbl")
	_aim_at(_pol(13.0, 0.78))
	await _hold(6)
	await _snap("aim_sgl")
	_aim_at(g.BC + Vector2(1.0, 2.0))
	await _hold(6)
	await _snap("aim_bull")
	_aim_at(g.BC + Vector2(g.R * 0.10, 0.0))
	await _hold(6)
	await _snap("aim_bullo")

	#  죽은 색(그늘 — 먹 칸이 죽는다)
	g.sec_col = base_col.duplicate()
	g.dead_col = 1
	_plain()
	await _hold(6)
	await _snap("dead_col")

	#  죽은 칸(막힌 칸) — 칠한 칸과 함께
	g.dead_col = -1
	g.sec_col[3] = 2
	g.sec_col[nsc - 2] = 3
	g.dead_idx = 7
	_plain()
	await _hold(6)
	await _snap("dead_idx")
	g.dead_idx = 8
	_aim_at(_pol(8.0, 0.61))
	await _hold(6)
	await _snap("dead_aim")
	#  크림 칸이 죽는다 — 6시 인덱스(굵은 막대)가 선 칸
	g.dead_idx = 10
	_plain()
	await _hold(6)
	await _snap("dead_cream")
	g.dead_idx = -1

	#  실띠(band_mul 0.5) · 넓은 판(1.5) — _start_leg 와 같은 식으로 띠를 민다
	var t0: Array = [g.rt_trp_in, g.rt_trp_out, g.rt_dbl_in]
	for bw in [0.5, 1.5]:
		var tc: float = (float(t0[0]) + float(t0[1])) * 0.5
		var tb: float = (float(t0[1]) - float(t0[0])) * 0.5
		g.rt_trp_in = tc - tb * bw
		g.rt_trp_out = tc + tb * bw
		g.rt_dbl_in = g.rt_dbl_out - (g.rt_dbl_out - float(t0[2])) * bw
		_aim_at(_pol(2.0, (g.rt_trp_in + g.rt_trp_out) * 0.5))
		await _hold(6)
		await _snap("band_%02d" % int(bw * 10.0))
	g.rt_trp_in = t0[0]
	g.rt_trp_out = t0[1]
	g.rt_dbl_in = t0[2]
	g.darts = []
	g._bd3_close()
	print("  찍음 ", pre)
	quit(0)
