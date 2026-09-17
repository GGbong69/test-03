extends SceneTree
# 판 위 조준이 가리키는 칸이 밝아지는가 — 기본(둘째 칸) · 십자 · 확인 · 불.
#   godot --path . --quit-after 900 --script scripts/tools/shot_aimglow.gd
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_ag_g.cfg"
	Save.path = "user://_shot_ag.cfg"
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


#  게임의 _process 를 끈 채 조준점을 못 박고 찍는다 — 게이지가 돌면 매번 딴 칸이다.
func _shot(nm: String, mode: String, st: int, at: Vector2) -> void:
	g.aim_mode = mode
	g.state = st
	g.aim = at
	for i in 3:
		g._tutor_close()
		g.tutor_out = 0.0
		g.swap_live = false
		g.grip_t = 9.0
		g.aim = at
		g.queue_redraw()
		await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g._new_run()
	await _wait(20)
	g._start_leg()
	g._swap_skip()
	g.state = g.S.PICK
	g._pick_dart(0)
	await _wait(10)
	g.set_process(false)
	var bc: Vector2 = g.BC
	var r: float = g.R
	#  기본 · 둘째 칸 — 트리플 20 쪽
	await _shot("aglow_std_h", "std", g.S.AIM_H, bc + Vector2(4.0, -r * 0.60))
	#  기본 · 첫 칸 — 점이 없으니 안 밝힌다
	await _shot("aglow_std_v", "std", g.S.AIM_V, bc + Vector2(0.0, -r * 0.40))
	#  십자 — 더블 6 쪽
	await _shot("aglow_cross", "cross", g.S.AIM_V, bc + Vector2(r * 0.97, 2.0))
	#  확인 — 불
	await _shot("aglow_confirm", "std", g.S.CONFIRM, bc + Vector2(2.0, 3.0))
	print("  찍음")
	quit(0)
