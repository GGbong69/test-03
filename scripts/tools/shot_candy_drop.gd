extends SceneTree

# 사탕이 상점 테이블에 떨어지는 과정을 본다 — 공중 두 장, 정착 한 장.
#     godot --script scripts/tools/shot_candy_drop.gd

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
	# stock 의 사탕 자리를 찾아, 물리를 손으로 몇 스텝 감아 공중 프레임을 잡는다.
	var ci := -1
	for i in g.stock.size():
		if g.stock[i].type == "cons":
			ci = i
			break
	print("사탕 자리: ", ci, " id=", (g.stock[ci].d.id if ci >= 0 else "?"))

	for step in [4, 14]:
		for k in step:
			g._drop_update(1.0 / 60.0)
		g.queue_redraw()
		await process_frame
		await process_frame
		var img := root.get_texture().get_image()
		img.save_png("res://shots/candy_air_%d.png" % step)
		print("저장: candy_air_%d.png" % step)

	g._drop_settle()
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/candy_rest.png")
	print("저장: candy_rest.png")
	quit()
