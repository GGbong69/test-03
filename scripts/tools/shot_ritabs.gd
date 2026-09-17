extends SceneTree
# 런 정보 네 탭을 차례로 — 판 크기가 탭마다 같은가.
#   godot --path . --quit-after 900 --script scripts/tools/shot_ritabs.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_ri_g.cfg"
	Save.path = "user://_shot_ri.cfg"
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
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g._new_run()
	await _wait(20)
	g.run_from = g.S.PICK
	g.state = g.S.RUNINFO
	for t in g.RI_TABS.size():
		g.runinfo_tab = t
		for k in 3:
			g._tutor_close()
			g.tutor_out = 0.0
			g.swap_live = false
			g.mouse_at = Vector2(-50.0, -50.0)
			g.queue_redraw()
			await process_frame
		root.get_texture().get_image().save_png("res://shots/ri_tab%d.png" % t)
		print("  탭 %d 판 %s" % [t, g._ri_panel()])
	print("  찍음")
	quit(0)
