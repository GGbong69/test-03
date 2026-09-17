extends SceneTree
# 인트로를 움짤로 — 1/12 초마다 한 장(shots/intro_gif/f###.png). 묶는 것은 파이썬이 한다.
#   godot --path . --quit-after 8000 --script scripts/tools/shot_intro_gif.gd
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_ig_g.cfg"
	Save.path = "user://_shot_ig.cfg"
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/intro_gif"))
	g._intro_begin()
	g.set_process(false)
	var dt := 1.0 / 60.0
	for f in 390:
		g.mouse_at = Vector2(-50.0, -50.0)
		g._process(dt)
		await process_frame
		if f % 5 == 0:
			root.get_texture().get_image().save_png("res://shots/intro_gif/f%03d.png" % (f / 5))
	print("  찍음")
	quit(0)
