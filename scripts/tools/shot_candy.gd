extends SceneTree

# 사탕 그림을 실제 크기로 본다. 칸이 둘뿐이라 두 번에 나눠 찍는다.
#     godot --script scripts/tools/shot_candy.gd

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
		_shots()
	return false

func _shots() -> void:
	g.gold = 24
	g._open_shop()
	g._drop_settle()
	await process_frame
	var gd = load("res://scripts/data.gd")
	var all: Array = gd.consumables()
	var by := {}
	for c in all:
		by[String(c.id)] = c
	var sets := [["c_sg", "c_db"], ["c_tr", "c_bl"], ["c_bo", "c_sg"]]
	for k in sets.size():
		g.cons.clear()
		for id in sets[k]:
			if by.has(id):
				g.cons.append(by[id].duplicate())
		g.queue_redraw()
		await process_frame
		await process_frame
		var img := root.get_texture().get_image()
		img.save_png("res://shots/candy%d.png" % k)
		print("저장: candy%d.png  %s" % [k, sets[k]])
	quit()
