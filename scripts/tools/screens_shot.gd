extends SceneTree

#  제목·설정·컬렉션 화면을 png 로 뽑는다. 헤드리스로는 못 돈다 —
#  뷰포트가 실제로 그려져야 화소가 나온다.
#
#  실행:  godot --path . -s scripts/tools/screens_shot.gd

var g = null
var frames := 0
var plan := []


func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	plan = [
		{"at": 14, "st": g.S.TITLE, "png": "scr_title.png"},
		{"at": 22, "st": g.S.SETTINGS, "png": "scr_settings.png"},
		{"at": 30, "st": g.S.COLLECT, "tab": 0, "png": "scr_collect_items.png"},
		{"at": 38, "st": g.S.COLLECT, "tab": 1, "png": "scr_collect_mods.png"},
		{"at": 46, "st": g.S.COLLECT, "tab": 3, "png": "scr_collect_cons.png"},
		{"at": 54, "st": g.S.COLLECT, "tab": 4, "png": "scr_collect_modf.png"},
		{"at": 62, "st": g.S.COLLECT, "tab": 0, "page": 1, "png": "scr_collect_items_p2.png"},
	]


func _process(_d: float) -> bool:
	frames += 1
	if g == null:
		return true
	g.tip_a = 0.0
	g.tip_title = ""
	for p in plan:
		if frames == p.at - 2:
			g.state = p.st
			if p.has("tab"):
				g.collect_tab = p.tab
			g.collect_page = p.get("page", 0)
			g.queue_redraw()
		elif frames == p.at:
			var img := root.get_texture().get_image()
			img.save_png("res://shots/" + p.png)
			print("저장: ", p.png)
	if frames > 66:
		quit()
	return false
