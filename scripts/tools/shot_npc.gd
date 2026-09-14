extends SceneTree
# 상인을 확대해 본다. 쉬는 자세와 쓸는 자세 둘.
#   godot --path . --quit-after 1500 --script scripts/tools/shot_npc.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false

func _initialize() -> void:
	Save.gpath = "user://_shot_npc_g.cfg"
	Save.path = "user://_shot_npc.cfg"
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
	await _wait(40)
	print("상태 %d" % g.state)
	await _shot("npc_rest")
	# 상점에서 쓸기
	g.gold = 40
	g.leg_no = 2
	g._open_shop()
	await _wait(60)
	await _shot("npc_shop")
	g._sweep_start() if g.has_method("_sweep_start") else g._roll_stock()
	await _wait(14)
	await _shot("npc_sweep")
	print("찍었다")
	quit(0)
