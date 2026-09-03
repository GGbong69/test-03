extends SceneTree
# roll 값을 여러 개 강제로 넣어 다트 텍스처의 실제 픽셀 폭(=보이는 길이)이
# 정말 안 변하는지 잰다.
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
		g.queue_redraw()
	frames += 1
	if frames == 10:
		busy = true
		_go()
	return false

func _diag_len(img: Image) -> float:
	# 화면 축(x·y) 폭이 아니라 "가장 먼 두 불투명 점 사이 거리" —
	# 회전하면 가로세로 비중은 당연히 바뀐다. 길이 불변은 이 값으로 잰다.
	var pts := PackedVector2Array()
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.05:
				pts.append(Vector2(x, y))
	var best := 0.0
	for i in pts.size():
		for j in range(i + 1, pts.size()):
			best = maxf(best, pts[i].distance_to(pts[j]))
	return best

func _go() -> void:
	for r in [0.0, PI * 0.25, PI * 0.5, PI * 0.75, PI, PI * 1.25]:
		var t: Texture2D = g._dart_tex_live("std", r, 0.0, true)
		await process_frame
		await process_frame
		var img: Image = t.get_image()
		var ln := _diag_len(img)
		print("roll=%.2f(%.0f°) -> 실제 길이(대각 최대거리) %.1f px"
				% [r, rad_to_deg(r), ln])
	quit()
