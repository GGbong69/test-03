extends SceneTree
# 탭 단추를 본다 — 컬렉션 탭 줄 · 런 정보 탭 줄(첫 탭 고름 · 옆 탭에 커서).
#   godot --path . --quit-after 900 --script scripts/tools/shot_tabs.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_tab_g.cfg"
	Save.path = "user://_shot_tab.cfg"
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


func _shot(nm: String, m: Vector2) -> void:
	for i in 3:
		g._tutor_close()
		g.tutor_out = 0.0
		g.mouse_at = m
		g.queue_redraw()
		await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g._new_run()
	await _wait(20)
	g.state = g.S.COLLECT
	g.collect_tab = 0
	await _wait(8)
	await _shot("tab_col", g._col_tab_rect(1).get_center())
	g.run_from = g.S.PICK
	g.state = g.S.RUNINFO
	g.runinfo_tab = 0
	await _wait(8)
	await _shot("tab_ri", g._ri_tab_rect(2).get_center())
	print("  col %s · ri %s %s" % [g._col_tab_rect(0), g._ri_tab_rect(0), g._ri_tab_rect(3)])
	print("  찍음")
	quit(0)
