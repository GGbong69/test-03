extends SceneTree
# 갈무리 두 벌이 크기마다 도트 격자에 딱 떨어지는가 — 실제 창(1280x720, 캔버스 2배)에서 찍는다.
#   godot --path . --quit-after 600 --script scripts/tools/shot_fontgrid.gd
var frames := 0


func _initialize() -> void:
	var s := GDScript.new()
	s.source_code = """extends Node2D
var f9 = load("res://fonts/Galmuri9.ttf")
var f11 = load("res://fonts/Galmuri11.ttf")
func _draw():
	draw_rect(Rect2(0, 0, 640, 360), Color("14111f"))
	var y := 24.0
	for sz in [9, 10, 18, 20]:
		draw_string(f9, Vector2(8, y), "G9 %d 컬렉션 피자 과녁 설정 0123" % sz, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color.WHITE)
		y += float(sz) + 10.0
	for sz in [11, 12, 22, 24]:
		draw_string(f11, Vector2(8, y), "G11 %d 컬렉션 피자 과녁 0123" % sz, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, Color.WHITE)
		y += float(sz) + 10.0
"""
	s.reload()
	var n := Node2D.new()
	n.set_script(s)
	root.add_child(n)


func _process(_d: float) -> bool:
	frames += 1
	if frames == 20:
		root.get_texture().get_image().save_png("res://shots/fontgrid.png")
		print("  찍음")
		quit(0)
	return false
