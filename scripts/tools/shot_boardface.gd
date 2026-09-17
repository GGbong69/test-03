extends SceneTree
# 판의 얼굴 — 기본 · 조준 밝힘 · 보드 확장 넷 · 그늘 · 칠하기 · 제목.
#   godot --path . --quit-after 6000 --script scripts/tools/shot_boardface.gd
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_bs_g.cfg"
	Save.path = "user://_shot_bs.cfg"
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


func _hold(n: int, at := Vector2(-50.0, -50.0)) -> void:
	for i in n:
		g._tutor_close()
		g.tutor_out = 0.0
		g.swap_live = false
		g.grip_t = 9.0
		g.mouse_at = at
		g.queue_redraw()
		await process_frame


func _snap(nm: String) -> void:
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)


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


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g._new_run()
	await _wait(20)
	await _leg([])
	var bc: Vector2 = g.BC
	var r: float = g.R
	if g.sec_col.size() >= 20:
		g.sec_col[3] = 2
		g.sec_col[14] = 3
	g.darts = [
		{"p": bc + Vector2(3.0, -r * 0.61), "id": "std", "rot": 0.10},
		{"p": bc + Vector2(-2.0, -r * 0.30), "id": "std", "rot": -0.20},
		{"p": bc + Vector2(r * 0.50, r * 0.42), "id": "std", "rot": 0.30},
	]
	g._bd3_close()
	g.state = g.S.PICK
	g.aim_dim = 0.0
	await _hold(8)
	await _snap("bfin_pick")
	#  조준 밝힘 — 더블 10 언저리
	g.state = g.S.AIM_H
	g.aim_mode = "std"
	g.aim = bc + Vector2(r * 0.93, r * 0.30)
	g.aim_dim = 1.0
	await _hold(6)
	await _snap("bfin_aim")
	g.darts = []
	g._bd3_close()
	#  보드 확장 — 라지 · 천체 고리 · 피자 · 도넛
	for id in ["panb", "arst", "pizz", "dnut"]:
		await _leg([id])
		g.state = g.S.PICK
		g.aim_dim = 0.0
		await _hold(6)
		await _snap("bfin_mod_%s" % id)
	#  천체 고리 칸을 조준 — 어둠이 새 띠를 한 칸으로 남기나
	await _leg(["arst"])
	g.state = g.S.AIM_H
	g.aim_mode = "std"
	g.aim = bc + Vector2(0.0, -r * 0.42)
	g.aim_dim = 1.0
	await _hold(6)
	await _snap("bfin_mod_arst_aim")
	#  그늘 — 먹색 칸이 죽는다
	await _leg([])
	g.dead_col = 1
	g.state = g.S.PICK
	g.aim_dim = 0.0
	await _hold(6)
	await _snap("bfin_shade")
	g.dead_col = -1
	#  칠하기
	g.photo = "paint"
	g.photo_v = 2
	await _hold(6, bc + Vector2(r * 0.40, -r * 0.35))
	await _snap("bfin_paint")
	g.photo = ""
	#  제목
	g.state = g.S.TITLE
	await _hold(10)
	await _snap("bfin_title")
	print("  찍음")
	quit(0)
