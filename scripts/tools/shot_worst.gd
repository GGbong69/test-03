extends SceneTree
const GameData = preload("res://scripts/data.gd")
var g = null
var busy := false
func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false
func _run() -> void:
	for i in 20:
		g._process(1.0 / 60.0)
	g.state = g.S.TITLE
	g._new_run()
	g._click(g._leg_go().get_center())
	for k in 60:
		g._process(1.0 / 60.0)
	g.target = 8000
	var Dev = load("res://scripts/dev.gd")
	Dev._run(g, {"t": "act", "a": "worst"})
	g.motion_off = true
	for k in 20:
		g._process(1.0 / 60.0)
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/ui_worst.png")
	print("제약 %d · 동전 %d · 사탕 %d" % [g.active_mods.size(), g.owned.size(), g.cons.size()])
	quit(0)
