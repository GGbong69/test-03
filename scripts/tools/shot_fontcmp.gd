extends SceneTree
# 글꼴 견주기 — 같은 화면을 갈무리(선명한 크기) · 페이퍼로지 두 굵기로 찍는다.
#   godot --path . --quit-after 6000 --script scripts/tools/shot_fontcmp.gd
#  페이퍼로지는 저장소에 안 싣고 내려받은 폴더에서 바로 읽는다(견주기 전용).
const Save = preload("res://scripts/save.gd")
const SRC := "C:/Users/sunyi/Downloads/Paperlogy-1.001/"
var g = null
var busy := false
var pin := Vector2(-50.0, -50.0)


func _initialize() -> void:
	Save.gpath = "user://_shot_fc_g.cfg"
	Save.path = "user://_shot_fc.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if g != null:
		g.mouse_at = pin
	if busy: return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		g._tutor_close()
		g.tutor_out = 0.0
		await process_frame


func _ff(file: String) -> FontFile:
	var f := FontFile.new()
	f.load_dynamic_font(SRC + file)
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	return f


func _snap(nm: String) -> void:
	root.get_texture().get_image().save_png("res://shots/fontcmp_%s.png" % nm)


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		quit(0)
		return
	var gal := [g.font, g.font_sm]
	var sets := [["galmuri", gal[0], gal[1]],
			["paper5", _ff("Paperlogy-5Medium.ttf"), _ff("Paperlogy-5Medium.ttf")],
			["paper7", _ff("Paperlogy-7Bold.ttf"), _ff("Paperlogy-6SemiBold.ttf")]]
	for st in sets:
		g.font = st[1]
		g.font_sm = st[2]
		#  제목
		g.state = g.S.TITLE
		pin = Vector2(-50.0, -50.0)
		await _wait(20)
		await _snap("%s_title" % st[0])
		#  컬렉션 + 툴팁
		#  못 본 칸은 물음표라 그림이 안 보인다 — 전부 발견으로 그린다(저장은 안 만진다)
		g._dev_unlock_all()
		g.state = g.S.COLLECT
		g.collect_tab = 0
		g.collect_page = 0
		pin = g._col_cell(0).get_center()
		await _wait(40)
		await _snap("%s_collect" % st[0])
		#  던지는 화면
		pin = Vector2(-50.0, -50.0)
		g._new_run()
		await _wait(10)
		g._start_leg()
		g._swap_skip()
		g.state = g.S.PICK
		g._pick_dart(0)
		await _wait(20)
		await _snap("%s_play" % st[0])
	print("  찍음")
	quit(0)
