extends SceneTree
# 상인 연출을 한 장씩 굽는다 — 몸짓 넷 × 세 박자.
#   godot --path . --quit-after 4000 --script scripts/tools/shot_idle.gd
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
	# 몸짓을 하나씩 강제로 걸고 박자마다 찍는다
	for i in g.IDLE.acts.size():
		var nm: String = String(g.IDLE.acts[i])
		var dur: float = float(g.IDLE.len[i])
		for k in 3:
			g.idle_act = i
			g.idle_t = dur * (0.3 + 0.25 * float(k))
			g._body3_sync()
			await _shot("idle_%d_%d" % [i, k])
		print("%s 찍었다" % nm)
	g.idle_act = -1
	g.idle_t = 0.0
	g._body3_sync()
	await _shot("idle_rest")
	print("끝")
	quit(0)
