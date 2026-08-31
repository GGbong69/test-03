extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")

# 개발자 모드를 쪽마다 찍는다.
var g = null
var busy := false


func _initialize() -> void:
	Save.path = "user://_shot_dev.cfg"
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
	g._new_run()
	g._swap_skip()
	g.round_no = 1
	g._start_round()
	g._swap_skip()
	Dev.on = true
	for pg in Dev.PAGES.size():
		Dev.page = pg
		for i in 4:
			g._process(1.0 / 60.0)
			g.tip_a = 0.0
		g.queue_redraw()
		await process_frame
		await process_frame
		var nm := "dev_%d.png" % pg
		root.get_texture().get_image().save_png("res://shots/" + nm)
		print("저장: %-12s %s" % [nm, Dev.PAGES[pg]])
	quit()
