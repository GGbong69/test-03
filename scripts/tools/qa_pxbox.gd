extends SceneTree
#  도트 화판(scripts/boot.gd · 2026-10-18 「게임만 도트 · CRT는 그대로」) — 창이 있어야 돈다. 못 박는 것:
#    ① 게임이 SubViewport 안에 선다 · 배율이 정수다 · 화판이 창 ÷ 배율만큼 넓어 남는 테가 배율보다 작다
#    ② CRT · VHS · 도트 팔레트 층은 바깥(창 해상도)에, 반전 층은 화판 안에 선다
#    ③ 바깥 창의 누름 · 움직임 · 키가 화판의 같은 논리 자리로 들어간다
#    ④ 판(그린 띠 · 원)이 논리 격자에 선다 — 찍은 화면의 판 자리가 배율 × 배율 덩어리다
#   godot --path . --script scripts/tools/qa_pxbox.gd
const Save = preload("res://scripts/save.gd")
var b = null
var g = null
var f := 0
var ok := 0
var bad := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_pxbox_g.cfg"
	Save.path = "user://_qa_pxbox.cfg"
	Save.prof_fmt = "user://_qa_pxbox_%d.cfg"
	Save.wipe()
	b = load("res://scenes/boot.tscn").instantiate()
	root.add_child(b)


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-44s %s" % ["통과" if cond else "실패", nm, note])


func _process(_d: float) -> bool:
	f += 1
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 화판이 선다")
		quit(0)
		return false
	if f == 20:
		g = b.game
		g._new_run()
		g._start_leg()
		g._swap_skip()
	if f == 60:
		_run()
		_point()
	if f == 64:
		_point_check()
		_grid()
		print("통과 %d · 실패 %d" % [ok, bad])
		quit(1 if bad > 0 else 0)
	return false


func _run() -> void:
	var vp: Viewport = g.get_viewport()
	var k: int = _k()
	var ws := Vector2(root.size)
	var left: Vector2 = ws - Vector2(vp.size) * float(k)
	_ok("① 게임이 SubViewport 안이다", vp is SubViewport and vp != root)
	_ok("① 배율이 정수 · 창의 내림", k >= 1 and k == maxi(1, int(floor(minf(ws.x / 640.0, ws.y / 360.0)))),
			"창 %s · 배율 %d" % [root.size, k])
	_ok("① 화판이 창을 채운다(남는 테 < 배율)", left.x >= 0.0 and left.y >= 0.0 and left.x < float(k)
			and left.y < float(k) and vp.size.x >= 640 and vp.size.y >= 360, "화판 %s · 남음 %s" % [vp.size, left])
	g._crt_open()
	g._retro_open()
	g._inv_open()
	_ok("② CRT 층은 바깥(창 해상도)", g.crt_layer != null and g.crt_layer.get_viewport() == root)
	_ok("② VHS · 도트 팔레트 층도 바깥", g.vhs_rect != null and g.vhs_rect.get_viewport() == root
			and g.dot_rect != null and g.dot_rect.get_viewport() == root)
	_ok("② 반전 층은 화판 안", g.inv_rect != null and g.inv_rect.get_viewport() == vp)



#  ③ — 바깥 창에 기기 자리로 누름 · 움직임 · 키를 넣고(root.push_input — 창이 받는 그 길), 화판 안에 세운
#  기록 노드가 논리 자리로 받는지 본다. 검사 실행에서는 Input.parse_input_event 가 게임까지 안 가서
#  (화판 없이도 같다) 기록 노드로 잰다.
class Rec extends Node:
	var got := []
	func _unhandled_input(e: InputEvent) -> void:
		if e is InputEventMouse:
			got.append((e as InputEventMouse).position)
		elif e is InputEventKey:
			got.append((e as InputEventKey).keycode)


var rec: Rec = null


func _k() -> int:
	return int(b.box.stretch_shrink)


#  화판의 논리 자리 p 가 창의 기기 자리 어디인가
func _dev(p: Vector2) -> Vector2:
	return b.box.position + p * float(_k())


func _point() -> void:
	rec = Rec.new()
	g.get_viewport().add_child(rec)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = _dev(g.BC + g.view_pad)
	mb.global_position = mb.position
	root.push_input(mb)
	var mm := InputEventMouseMotion.new()
	mm.position = _dev(Vector2(37.0, 21.0))
	mm.global_position = mm.position
	root.push_input(mm)
	var ek := InputEventKey.new()
	ek.keycode = KEY_ESCAPE
	ek.pressed = true
	root.push_input(ek)


func _point_check() -> void:
	var want := [g.BC + g.view_pad, Vector2(37.0, 21.0), KEY_ESCAPE]
	_ok("③ 바깥 창의 누름 · 움직임 · 키가 화판의 논리 자리로", rec != null and str(rec.got) == str(want),
			"%s · %s" % [str(rec.got if rec != null else []), str(want)])


func _grid() -> void:
	var k: float = float(_k())
	#  ④ — 판 자리(가운데 반지름 R 안)를 배율 칸으로 나눠 칸마다 한 색인지 센다
	var im: Image = root.get_texture().get_image()
	var kk: int = int(roundf(k))
	var c: Vector2 = _dev(g.BC + g.view_pad)
	var r: int = int(g.R * k * 0.9)
	var mixed := 0
	var cells := 0
	var o: Vector2i = Vector2i(b.box.position)
	var x0: int = (int(c.x) - r - o.x) / kk * kk + o.x
	var y0: int = (int(c.y) - r - o.y) / kk * kk + o.y
	for y in range(y0, int(c.y) + r - kk, kk):
		for x in range(x0, int(c.x) + r - kk, kk):
			if Vector2(x, y).distance_to(c) > float(r):
				continue
			cells += 1
			var p0: Color = im.get_pixel(x, y)
			var same := true
			for dy in kk:
				for dx in kk:
					same = same and im.get_pixel(x + dx, y + dy).is_equal_approx(p0)
			if not same:
				mixed += 1
	_ok("④ 판이 논리 격자에 선다(칸마다 한 색)", cells > 100 and mixed == 0, "%d / %d 칸이 섞였다" % [mixed, cells])
