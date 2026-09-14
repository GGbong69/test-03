extends SceneTree
# 화면 비를 바꿔 가며 찍는다. 16:9 가 아닌 화면에서 여백이 방으로 차는가.
#   godot --path . --quit-after 2400 --script scripts/tools/shot_aspect.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false

func _initialize() -> void:
	Save.gpath = "user://_shot_asp_g.cfg"
	Save.path = "user://_shot_asp.cfg"
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
	for sz in [Vector2i(1280, 720), Vector2i(1280, 800), Vector2i(1720, 720)]:
		DisplayServer.window_set_size(sz)
		await _wait(20)
		var vs: Vector2 = g.get_viewport_rect().size
		print("  창 %dx%d → 뷰포트 %.0fx%.0f · 여백 %s"
				% [sz.x, sz.y, vs.x, vs.y, g.view_pad])
		await _shot("asp_%dx%d" % [sz.x, sz.y])
	print("찍었다")
	quit(0)
