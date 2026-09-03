extends SceneTree

# 판에 꽂힌 자루를 한 장 찍는다. 자루 형태를 눈으로 보려는 것뿐이다.
# 헤드리스로는 못 돈다 — 3D 무대가 렌더러 없으면 안 열린다.
#
#     godot --script scripts/tools/shot_dart.gd

var g = null
var frames := 0


func _initialize() -> void:
	var scn: PackedScene = load("res://scenes/main.tscn")
	g = scn.instantiate()
	root.add_child(g)
	g.set_process(false)


func _process(_d: float) -> bool:
	if g != null:
		g.set_process(false)
		g._process(1.0 / 60.0)
		g.tip_a = 0.0
		g.tip_title = ""
		g.queue_redraw()
	frames += 1
	if frames == 10:
		g.state = g.S.AIM_V
		g.darts.clear()
		# 가운데부터 바깥까지 다섯 발. 각도를 흩어 원근이 읽히게 둔다.
		for i in 5:
			var a := TAU * float(i) / 5.0 + 0.4
			var r := 10.0 + 19.0 * float(i)
			g.darts.append({
				"p": g.BC + Vector2(cos(a), sin(a)) * r,
				"id": "std",
				"rot": 0.35 * float(i) - 0.7,
			})
		g.queue_redraw()
	if frames == 26:
		_save("shot_dart3.png")
		quit()
	return false


func _save(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png("res://shots/" + name)
	print("저장: ", name, "  ", img.get_width(), "x", img.get_height())
