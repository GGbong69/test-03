extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# 사탕 아이콘 다섯 종을 실제 칸 크기와 확대로 나란히 찍는다.
var g = null
var busy := false


func _initialize() -> void:
	Save.path = "user://_shot_ico.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _process(_d: float) -> bool:
	if g != null:
		g.set_process(false)
	if busy:
		return false
	busy = true
	_run()
	return false


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	GameData.pack = "p_rack"       # 동전 여섯 칸 다트통
	g._new_run()
	g._swap_skip()
	g.cons.clear()
	for c in GameData.consumables():
		if g.cons.size() < GameData.cons_slots():
			g.cons.append(c)
	g.owned.clear()
	for it in GameData.items():
		if g.owned.size() < GameData.max_items():
			var c2: Dictionary = it.duplicate()
			c2.gs = 0
			c2.bought = 0
			g.owned.append(c2)
	g._panel_reset()
	g.leg_no = 1
	g._open_shop()
	g._swap_skip()
	for i in 20:
		g._process(1.0 / 60.0)
	g._drop_settle()
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/rack6.png")
	print("저장: rack6.png  소비 %d칸" % g.cons.size())
	quit()
