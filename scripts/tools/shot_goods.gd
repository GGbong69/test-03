extends SceneTree
# 상점 물건 여섯 갈래를 한 테이블에 깔아 크기를 견준다.
#   godot --path . --quit-after 1500 --script scripts/tools/shot_goods.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false

func _initialize() -> void:
	Save.gpath = "user://_shot_gd_g.cfg"
	Save.path = "user://_shot_gd.cfg"
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

func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀"); quit(0); return
	g.state = g.S.TITLE
	g._new_run()
	await _wait(30)
	g.gold = 99
	g.leg_no = 3
	g._open_shop()
	await _wait(20)
	#  여섯 갈래를 손으로 깐다. 자리는 물리가 정하되 갈래는 고정이다.
	g.stock.clear()
	g.stock.append({"type": "item", "d": GameData.items()[0], "cost": 4, "sold": false})
	g.stock.append({"type": "mod", "d": GameData.mods()[0], "cost": 5, "sold": false})
	g.stock.append({"type": "dart", "d": GameData.darts()[1], "cost": 5, "sold": false})
	g.stock.append({"type": "cons", "d": GameData.candies()[0], "cost": 3, "sold": false})
	g.stock.append({"type": "fix", "d": GameData.fixtures()[0], "cost": 4, "sold": false})
	var bs := GameData.boosters()
	if not bs.is_empty():
		g.stock.append({"type": "boost", "d": bs[0], "cost": 4, "sold": false})
	g._drop_roll()
	g._drop_settle()
	await _wait(30)
	for k in g.stock.size():
		var d: Dictionary = g.drop[k]
		var bx: Rect2 = g._obj_box(k)
		print("  %-6s %-14s 화면 %.0f x %.0f px" % [String(g.stock[k].type),
				String(g.stock[k].d.get("n", g.stock[k].d.get("name", "?"))),
				bx.size.x, bx.size.y])
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/goods.png")
	print("찍었다")
	quit(0)
