extends SceneTree
# 컬렉션의 탭 여섯 · 모든 쪽을 찍는다 — 그림이 없는 아이템을 한눈에 가르는 자료.
#   godot --path . --quit-after 3000 --script scripts/tools/shot_collect_all.gd
#   → shots/colall_<탭>_<쪽>.png
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_ca_g.cfg"
	Save.path = "user://_shot_ca.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if busy: return false
	busy = true
	_run()
	return false


func _run() -> void:
	for i in 10:
		await process_frame
	if DisplayServer.get_name() == "headless":
		quit(0)
		return
	#  잠긴 칸은 실루엣이라 그림이 안 보인다 — 해금을 전부 연다
	if g.has_method("_dev_unlock_all"):
		g._dev_unlock_all()
	g.state = g.S.COLLECT
	for t in g.COL_TABS.size():
		g.collect_tab = t
		g.collect_page = 0
		var pages: int = g._col_pages()
		for pg in pages:
			g.collect_page = pg
			for f in 4:
				g.mouse_at = Vector2(-50.0, -50.0)
				#  등급 맥동을 못박는다(2026-09-18) — 쪽마다 번짐이 달라지면
				#  여섯 탭을 견줄 수가 없다.
				g.rar_t = 0.0
				g.queue_redraw()
				await process_frame
			root.get_texture().get_image().save_png("res://shots/colall_%d_%d.png" % [t, pg])
	print("  찍음")
	quit(0)
