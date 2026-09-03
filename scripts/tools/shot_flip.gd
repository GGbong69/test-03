extends SceneTree

# 세게 던진 사탕이 구르며 뒤집히는 과정을 여러 장 찍는다.
#     godot --script scripts/tools/shot_flip.gd

var g = null
var frames := 0
var busy := false

func _initialize() -> void:
	var scn: PackedScene = load("res://scenes/main.tscn")
	g = scn.instantiate()
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

	var ci := -1
	for i in g.stock.size():
		if g.stock[i].type == "cons":
			ci = i
			break
	print("사탕: ", g.stock[ci].d.name)
	var it: Dictionary = g.drop[ci]

	g.hand_st = g.H.CARRY
	g.hand_src = 0
	g.hand_i = ci
	g.hand_zone = -1
	it.held = true
	it.h = 0.0
	g.hand_v = Vector2(-1800.0, 0.0)      # 최대 세기
	g._hand_release(Vector2(200.0, 240.0))
	print("던진 뒤 vu=", it.vu)

	var cum := 0
	for step in [6, 20]:
		for k in step:
			g._drop_update(1.0 / 60.0)
		cum += step
		g.queue_redraw()
		await process_frame
		var img := root.get_texture().get_image()
		img.save_png("res://shots/flip_%03d.png" % cum)
		print("저장: flip_%03d.png  roll=%.2f(%.1f바퀴) u=%.0f sleep=%s"
				% [cum, it.roll, it.roll / TAU, it.u, it.sleep])
	quit()
