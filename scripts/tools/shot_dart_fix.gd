extends SceneTree
var g = null
var frames := 0
var busy := false

func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)

func _process(_d: float) -> bool:
	if busy:
		return false
	if g != null:
		g.set_process(false)
		g._process(1.0 / 60.0)
		g.tip_a = 0.0
		g.tip_title = ""
		g.queue_redraw()
	frames += 1
	if frames == 10:
		busy = true
		_go()
	return false

func _go() -> void:
	g.gold = 30
	g._open_shop()
	for k in 6:
		g._drop_update(1.0 / 60.0)
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/dart_air.png")
	print("저장: dart_air.png (공중 · 그림자 상한 확인용)")

	g._drop_settle()
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/dart_rest.png")
	print("저장: dart_rest.png (정착 · roll 게이트 확인용)")
	quit()
