extends SceneTree
# 누른 물건이 어떻게 튀는지 — 누르기 직전과 직후 넉 장.
#   godot --path . --quit-after 2000 --script scripts/tools/shot_knock.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false

func _initialize() -> void:
	Save.gpath = "user://_shot_knock_g.cfg"
	Save.path = "user://_shot_knock.cfg"
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
	g.gold = 60
	g.leg_no = 2
	g._open_shop()
	await _wait(80)
	g._drop_settle()
	# 제일 큰 물건을 고른다 — 튀는 것이 제일 잘 보인다
	var pick := 0
	for q in g.stock.size():
		if String(g.stock[q].type) == "item":
			pick = q
			break
	var it: Dictionary = g.drop[pick]
	await _shot("knock_0")
	print("0  누르기 전  lift %.1f  wob %.2f" % [it.lift, it.wob])
	g._knock(pick)
	for k in 3:
		await _wait(2)
		await _shot("knock_%d" % (k + 1))
		print("%d  lift %.1f  wob %+.2f" % [k + 1, it.lift, it.wob])
	print("끝")
	quit(0)
