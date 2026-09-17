extends SceneTree
# 도넛 판(보드 확장 「도넛」)이 입는 옷을 한 벌씩 찍는다.
#   godot --path . --quit-after 9000 --script scripts/tools/shot_board_donut.gd
#   DN_TAG=old 를 주면 이름 앞에 old_ 가 붙는다(고치기 전 판을 같은 구도로 남길 때).
# 찍는 것 — 기본(다트 셋) · 부푼 판(명중) · 누운 판(전환) · 트리플 조준 · 더블 조준 ·
# 구멍 곁 조준(불이 없는 판) · 칠한 칸(주홍 · 쪽빛) · 죽은 색(먹) · 죽은 칸(크림 자리) ·
# 라지(판 바깥선 1.10).
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false
var tag := ""


func _initialize() -> void:
	Save.gpath = "user://_shot_dn_g.cfg"
	Save.path = "user://_shot_dn.cfg"
	Save.wipe()
	var t := OS.get_environment("DN_TAG")
	tag = (t + "_") if t != "" else ""
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
	root.get_texture().get_image().save_png("res://shots/dnut_%s%s.png" % [tag, nm])


func _leg() -> void:
	g.set_process(true)
	g.mods_own = ["dnut"]
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


#  칸 i 한가운데 방위로 반지름 k(R 배수)인 점.
func _at(i: int, k: float) -> Vector2:
	var a: float = float(i) * g._sec_w()
	return g.BC + Vector2(sin(a), -cos(a)) * g.R * k


func _aim(p: Vector2) -> void:
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
	await _leg()
	var nsc: int = g.sec_col.size()
	var keep: Array = g.sec_col.duplicate()
	g.darts = [
		{"p": _at(0, 0.61) + Vector2(2.0, 0.0), "id": "std", "rot": 0.10},
		{"p": _at(6, 0.95), "id": "std", "rot": 0.30},
		{"p": _at(13, 0.30), "id": "std", "rot": -0.20},
	]
	_plain()
	await _hold(8)
	_snap("plain")
	#  (검토 추가) 판은 구워 둔 삼각형 묶음을 내민다 — 명중해 부푼 판(push)과 전환 중
	#  누운 판(세로 배율 변환)에서도 묶음이 판 자리 · 눕힘을 따라가는지 본다.
	g.board_punch = 1.0
	await _hold(4)
	_snap("punch")
	g.board_punch = 0.0
	for i in 4:
		g.swap_live = true
		g.swap_in = true
		g.swap_t = float(g.SWAP.lead) + float(g.SWAP.rise) * 0.55
		g.grip_t = 9.0
		g.queue_redraw()
		await process_frame
	_snap("lie")
	g.swap_live = false
	g.darts = []
	_aim(_at(4, 0.61))
	await _hold(6)
	_snap("aim_trp")
	_aim(_at(15, 0.95))
	await _hold(6)
	_snap("aim_dbl")
	_aim(g.BC + Vector2(4.0, 5.0))
	await _hold(6)
	_snap("aim_hole")
	_aim(_at(9, 0.40))
	await _hold(6)
	_snap("aim_single")
	#  칠한 칸 — 크림 자리 · 먹 자리에 주홍 · 쪽빛을 한 번씩
	g.sec_col[2] = 2
	g.sec_col[3] = 2
	g.sec_col[nsc - 3] = 3
	g.sec_col[nsc - 2] = 3
	_plain()
	await _hold(6)
	_snap("paint")
	g.sec_col = keep.duplicate()
	g.dead_col = 1
	await _hold(6)
	_snap("deadcol")
	_aim(_at(8, 0.61))
	await _hold(6)
	_snap("deadcol_aim")
	g.dead_col = -1
	g.dead_idx = 4
	g.sec_col[7] = 2
	_plain()
	await _hold(6)
	_snap("deadidx")
	g.dead_idx = -1
	g.sec_col = keep.duplicate()
	var d0: float = g.rt_dbl_out
	var di: float = g.rt_dbl_in
	g.rt_dbl_out = 1.10
	g.rt_dbl_in = 1.00
	await _hold(6)
	_snap("large")
	g.rt_dbl_out = d0
	g.rt_dbl_in = di
	print("  찍음 %d" % nsc)
	quit(0)
