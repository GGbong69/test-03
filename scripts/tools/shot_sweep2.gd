extends SceneTree
# 쓸기 세 박자를 굽는다 — 뻗기 · 훑기 · 복귀.
#   godot --path . --quit-after 2500 --script scripts/tools/shot_sweep2.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false

func _initialize() -> void:
	Save.gpath = "user://_shot_sw2_g.cfg"
	Save.path = "user://_shot_sw2.cfg"
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
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)

func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀"); quit(0); return
	g.state = g.S.TITLE
	g._new_run()
	g.gold = 40
	g.leg_no = 2
	g._open_shop()
	await _wait(40)
	g._sweep_begin()
	for k in 6:
		await _wait(9)
		await _shot("sw2_%d" % k)
		print("%d : t=%.2f amt=%.2f" % [k, g.sweep_t, g._sweep_amt()])
	print("끝")
	quit(0)
