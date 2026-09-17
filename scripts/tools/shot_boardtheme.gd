extends SceneTree
# 판을 바꾸는 보드 확장 — 피자 · 시계 · 도넛 판이 입는 옷. 판마다 기본 · 조준 밝힘.
#   godot --path . --quit-after 8000 --script scripts/tools/shot_boardtheme.gd
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_bt_g.cfg"
	Save.path = "user://_shot_bt.cfg"
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
	var bc: Vector2 = g.BC
	var r: float = g.R
	for id in ["pizz", "clok", "aimb", "dnut"]:
		await _leg([id])
		var nsc: int = g.sec_col.size()
		if nsc >= 8:
			g.sec_col[3] = 2
			g.sec_col[nsc - 2] = 3
		g.darts = [
			{"p": bc + Vector2(3.0, -r * 0.61), "id": "std", "rot": 0.10},
			{"p": bc + Vector2(r * 0.50, r * 0.42), "id": "std", "rot": 0.30},
		]
		g._bd3_close()
		g.state = g.S.PICK
		g.aim_dim = 0.0
		await _hold(8)
		await _snap("btheme_%s" % id)
		g.state = g.S.AIM_H
		g.aim_mode = "std"
		g.aim = bc + Vector2(r * 0.55, r * 0.20)
		g.aim_dim = 1.0
		await _hold(6)
		await _snap("btheme_%s_aim" % id)
		g.darts = []
		g._bd3_close()
	print("  찍음")
	quit(0)
