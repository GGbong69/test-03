extends SceneTree
# 「피자」 판 한 벌 — 기본(다트 셋) · 조각 밝힘(안 · 밖) · 불 밝힘 · 칠한 조각(주홍 · 쪽빛) ·
# 죽은 색(먹) · 죽은 조각 하나 · 네 재료가 다 선 판(mix) · 그 위의 탄 크림 · 탄 먹(dead_mix) ·
# 칠한 조각 밝힘(aim_paint)을 찍고, 무게(구운 한 장 · 직접 그리는 프레임)를 잰다.
#   godot --path . --quit-after 9000 --script scripts/tools/shot_board_pizza.gd [-- 꼬리표]
#   꼬리표를 주면 파일 이름 앞에 붙는다(기본 pz) — 고치기 전 판을 pz_old 로 찍어 둔다.
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false
var tag := "pz"


func _initialize() -> void:
	var ua := OS.get_cmdline_user_args()
	if not ua.is_empty():
		tag = String(ua[0])
	Save.gpath = "user://_shot_pz_g.cfg"
	Save.path = "user://_shot_pz.cfg"
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
	root.get_texture().get_image().save_png("res://shots/%s_%s.png" % [tag, nm])


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


func _plain() -> void:
	g.state = g.S.PICK
	g.aim_dim = 0.0
	g._bd3_close()


func _dir_of(i: int, n: int) -> Vector2:
	var a := TAU * float(i) / float(n)
	return Vector2(sin(a), -cos(a))


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
	var bc: Vector2 = g.BC
	var r: float = g.R
	await _leg(["pizz"])
	var nsc: int = g.sec_col.size()
	print("  조각 수 %d · 띠 %.2f/%.2f · %.2f/%.2f · 불 %.2f/%.2f" % [nsc, g.rt_trp_in, g.rt_trp_out,
			g.rt_dbl_in, g.rt_dbl_out, g.rt_bull_i, g.rt_bull_o])
	var base_col: Array = g.sec_col.duplicate()
	# ① 기본 — 다트 셋(조각 안 · 크러스트 가까이 · 불)
	g.darts = [
		{"p": bc + Vector2(3.0, -r * 0.61), "id": "std", "rot": 0.10},
		{"p": bc + Vector2(r * 0.50, r * 0.42), "id": "std", "rot": 0.30},
		{"p": bc + Vector2(-r * 0.05, r * 0.03), "id": "std", "rot": -0.2},
	]
	_plain()
	await _hold(8)
	await _snap("plain")
	# ② 조각 밝힘 — 안쪽 반(불 ~ 접힌 트리플) · 바깥 반
	g.darts = []
	_aim_at(bc + Vector2(r * 0.30, r * 0.20))
	await _hold(6)
	await _snap("aim_in")
	_aim_at(bc + Vector2(-r * 0.62, -r * 0.52))
	await _hold(6)
	await _snap("aim_out")
	# ③ 불 밝힘 — 바깥 불 · 안쪽 불
	_aim_at(bc + Vector2(r * 0.10, 0.0))
	await _hold(6)
	await _snap("aim_bull")
	_aim_at(bc + Vector2(1.0, 1.0))
	await _hold(6)
	await _snap("aim_bull_i")
	# ④ 칠한 조각 — 주홍 · 쪽빛
	if nsc >= 8:
		g.sec_col[3] = 2
		g.sec_col[nsc - 2] = 3
	g.darts = [{"p": bc + Vector2(r * 0.30, r * 0.45), "id": "std", "rot": 0.2}]
	_plain()
	await _hold(6)
	await _snap("paint")
	# ⑤ 죽은 색(먹) — 칠은 남긴 채
	g.dead_col = 1
	await _hold(6)
	await _snap("dead_col")
	g.dead_col = -1
	# ⑥ 죽은 조각 하나 + 그 위를 밝힘
	g.sec_col = base_col.duplicate()
	g.dead_idx = 2
	await _hold(6)
	await _snap("dead_idx")
	_aim_at(bc + Vector2(r * 0.55, r * 0.20))
	await _hold(6)
	await _snap("dead_aim")
	g.dead_idx = -1
	g.darts = []
	g._bd3_close()
	# ⑦ 네 재료가 다 선 판 — 크림 · 먹 · 주홍 · 쪽빛이 두 번씩. 이어서 탄 먹(그늘) · 탄 크림 하나
	if nsc >= 8:
		for k in nsc:
			g.sec_col[k] = k % 4
	_plain()
	await _hold(6)
	await _snap("mix")
	_aim_at(bc + _dir_of(3, nsc) * r * 0.80)
	await _hold(6)
	await _snap("aim_paint")
	_plain()
	g.dead_col = 1
	g.dead_idx = 4
	await _hold(6)
	await _snap("dead_mix")
	g.dead_col = -1
	g.dead_idx = -1
	g.sec_col = base_col.duplicate()
	# ⑧ 무게 — 한 프레임 그리기 호출 · 그리는 데 든 시간(토너먼트 판과 견준다)
	_plain()
	for pass_mods in [[], ["pizz"]]:
		await _leg(pass_mods)
		_plain()
		await _hold(4)
		var t0 := Time.get_ticks_usec()
		var fr := 30
		var dc := 0
		for k in fr:
			await _hold(1)
			dc = maxi(dc, int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
		print("  무게 %s — 그리기 호출 %d · 프레임 %.2fms" % ["피자" if not pass_mods.is_empty() else "토너먼트",
				dc, float(Time.get_ticks_usec() - t0) / 1000.0 / float(fr)])
	#  판 전체를 다시 굽는 프레임(판이 설 때) · 조각 하나만 다시 굽는 프레임(사진이 칠할 때)
	if "pz_keys" in g:
		for pass_k in 2:
			if pass_k == 0:
				g.pz_keys = {}
			else:
				g.sec_col[0] = 2 if int(g.sec_col[0]) != 2 else 3
			var worst := 0.0
			for k in 3:
				var t1 := Time.get_ticks_usec()
				await _hold(1)
				worst = maxf(worst, float(Time.get_ticks_usec() - t1) / 1000.0)
			print("  무게 피자(%s) — 가장 무거운 프레임 %.2fms" % ["판 전체 굽기" if pass_k == 0 else "조각 하나 칠",
					worst])
		#  판이 서는 전환 — 화판을 비우고 전환을 안 건너뛴 채 새 판을 연다(lead 동안 흩어 굽는다)
		for pass_mods in [[], ["pizz"]]:
			g.set_process(true)
			g.mods_own = pass_mods
			g._board_bake()
			g.pz_keys = {}
			g.state = g.S.LEG
			g._start_leg()
			var seen: bool = g.swap_live
			var worst3 := 0.0
			for k in 30:
				var t3 := Time.get_ticks_usec()
				await process_frame
				worst3 = maxf(worst3, float(Time.get_ticks_usec() - t3) / 1000.0)
			g.set_process(false)
			print("  무게 %s(판이 서는 전환 %s) — 가장 무거운 프레임 %.2fms" % [
					"피자" if not pass_mods.is_empty() else "토너먼트", "있음" if seen else "없음", worst3])
	print("  찍음 %s" % tag)
	quit(0)
