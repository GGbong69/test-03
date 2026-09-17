extends SceneTree
# 메뉴 화면을 한 장씩 — 제목 · 설정(제목에서 · 판 중에) · 새 런 · 컬렉션 · 런 끝 · 정산.
#   godot --path . --quit-after 1500 --script scripts/tools/shot_menus.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_menu_g.cfg"
	Save.path = "user://_shot_menu.cfg"
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


func _shot(nm: String, frames := 30) -> void:
	for i in frames:
		g._tutor_close()
		g.tutor_out = 0.0
		g.swap_live = false
		g.mouse_at = Vector2(-50.0, -50.0)
		g.queue_redraw()
		await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g.state = g.S.TITLE
	await _shot("menu_title")
	g.pause_from = -1
	g.state = g.S.SETTINGS
	await _shot("menu_settings")
	g.state = g.S.NEWRUN
	if g.has_method("_newrun_open"):
		g._newrun_open()
	await _shot("menu_newrun")
	g.state = g.S.COLLECT
	await _shot("menu_collect")
	g._new_run()
	await _wait(20)
	g._start_leg()
	g.state = g.S.PICK
	g.pause_from = g.S.PICK
	g.state = g.S.SETTINGS
	await _shot("menu_pause")
	g.pause_from = -1
	g.state = g.S.OVER
	await _shot("menu_over", 90)
	print("  찍음")
	quit(0)
