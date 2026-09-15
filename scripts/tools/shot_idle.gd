extends SceneTree
# 상인 연출을 한 장씩 굽는다 — 몸짓마다 세 박자.
#   godot --path . --quit-after 9000 --script scripts/tools/shot_idle.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false

func _initialize() -> void:
	Save.gpath = "user://_shot_idle_g.cfg"
	Save.path = "user://_shot_idle.cfg"
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
	# 몸짓을 하나씩 강제로 걸고 박자마다 찍는다. 한 손 몸짓은 오른손으로.
	for i in g.IDLE.acts.size():
		var nm: String = String((g.IDLE.acts[i] as Dictionary).n)
		for k in 3:
			g.idle_act = i
			g.idle_side = 1
			g.idle_t = float((g.IDLE.acts[i] as Dictionary).t) \
					* (0.30 + 0.24 * float(k))
			g._body3_sync()
			await _shot("idle_%02d_%d" % [i, k])
		print("%d %s" % [i, nm])
	g.idle_act = -1
	g.idle_t = 0.0
	g._body3_sync()
	await _shot("idle_rest")
	print("끝 %d종" % g.IDLE.acts.size())
	quit(0)
