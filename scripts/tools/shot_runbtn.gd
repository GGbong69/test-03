extends SceneTree
# 런 안의 화면을 한 장씩 — 런 정보·일시정지 단추가 설 자리를 본다.
#   godot --path . --quit-after 1500 --script scripts/tools/shot_runbtn.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_rb_g.cfg"
	Save.path = "user://_shot_rb.cfg"
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


#  설명 띠는 매 장 걷는다 — 단추 자리를 가린다.
func _shot(nm: String) -> void:
	g._tutor_close()
	g.tutor_out = 0.0
	g.mouse_at = Vector2(-50.0, -50.0)
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g._new_run()
	await _wait(30)
	for st in [["rb_leg", "_open_leg"], ["rb_stage", "_open_stage"],
			["rb_shop", "_open_shop"]]:
		g.call(st[1])
		g.swap_live = false
		await _wait(40)
		await _shot(st[0])
	g.swap_live = false
	g.state = g.S.AIM_V
	await _wait(30)
	await _shot("rb_aim")
	g.state = g.S.PICK
	await _wait(20)
	await _shot("rb_pick")
	g.state = g.S.CLEAR
	g.clear_t = 9.0
	await _wait(20)
	await _shot("rb_clear")
	if g._runinfo_ok():
		g.run_from = g.state
		g.state = g.S.RUNINFO
		await _wait(20)
		await _shot("rb_runinfo")
	print("  찍음")
	quit(0)
