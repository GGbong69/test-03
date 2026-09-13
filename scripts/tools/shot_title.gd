extends SceneTree
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
	for i in 30:
		g._process(1.0 / 60.0)
	g.state = g.S.TITLE
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/title_now.png")
	quit(0)
