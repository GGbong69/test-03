extends SceneTree
# 다트가 구르는 모습 한 장.
#     godot --script scripts/tools/shot_dart_flip.gd
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
	g._drop_settle()
	await process_frame

	var di := -1
	for i in g.stock.size():
		if g.stock[i].type == "dart":
			di = i
			break
	if di < 0:
		print("다트 없음 — 종료")
		quit()
		return
	print("다트: ", g.stock[di].d.id)
	var it: Dictionary = g.drop[di]

	g.hand_st = g.H.CARRY
	g.hand_src = 0
	g.hand_i = di
	g.hand_zone = -1
	it.held = true
	it.h = 0.0
	g.hand_v = Vector2(-1800.0, 0.0)
	g._hand_release(Vector2(200.0, 240.0))

	for k in 8:
		g._drop_update(1.0 / 60.0)
	g.queue_redraw()
	await process_frame
	root.get_texture().get_image().save_png("res://shots/dart_flip.png")
	print("저장: dart_flip.png  roll=", it.roll)
	quit()
