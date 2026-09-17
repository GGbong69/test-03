extends SceneTree
# 자금판의 골드 — 판 위(벽이 선다)와 상점에서 자릿수별로.
#   godot --path . --quit-after 900 --script scripts/tools/shot_bank.gd
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_bank_g.cfg"
	Save.path = "user://_shot_bank.cfg"
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


func _shot(nm: String) -> void:
	for i in 3:
		g._tutor_close()
		g.tutor_out = 0.0
		g.swap_live = false
		g.mouse_at = Vector2(-50.0, -50.0)
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
	g.state = g.S.AIM_V
	g.grip_t = 9.0
	for v in [4, 20, 100]:
		g.gold = v
		await _shot("bank_aim_%d" % v)
	g._open_shop()
	for v in [4, 20, 100]:
		g.gold = v
		await _shot("bank_shop_%d" % v)
	print("  찍음")
	quit(0)
