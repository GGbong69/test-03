extends SceneTree
#  말상자 촬영 (2026-10-02) — 설명 줄 · 상인 줄이 한 자씩 나오는 도중과 다 나온 뒤.
#  가운데 맞춘 설명 줄이 나오는 동안 옆으로 안 밀리는지 본다. shots/talk_*.png 로.
#  창이 있어야 돈다:  godot --path . --script scripts/tools/shot_talk.gd
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_talk_g.cfg"
	Save.path = "user://_shot_talk.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if busy:
		return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for _i in n:
		await process_frame


#  한 갈래를 걸고 t 초 시점의 말상자를 찍는다.
func _shoot(tid: String, t: float, name: String) -> void:
	g._tutor_close()
	g.tutor_q.clear()
	g.tutor_out = 0.0
	g.tutor_id = tid
	g.tutor_i = 0
	g.tutor_pre = 0.0
	g.tutor_t = t
	await _wait(3)
	g.tutor_t = t
	await _wait(1)
	var im: Image = root.get_texture().get_image()
	var k: float = float(im.get_width()) / 640.0
	var box: Rect2 = g._tutor_box()
	var r := Rect2i(int((box.position.x - 8.0) * k), int((box.position.y - 14.0) * k),
			int((box.size.x + 16.0) * k), int((box.size.y + 22.0) * k))
	im.get_region(r).save_png("res://shots/%s.png" % name)


func _run() -> void:
	await _wait(10)
	g._new_run()
	g.state = g.S.SHOP
	g._open_shop()
	await _wait(60)
	var narr := ""
	var talk := ""
	for r in GameData.tutor():
		var id := String(r.get("id", ""))
		var who := String(r.get("who", "")).strip_edges()
		if narr == "" and who == "" and id == "u_shop":
			narr = id
		if talk == "" and who != "":
			talk = id
	if narr == "":
		narr = "u_leg"
	for tt in [0.15, 0.45, 9.0]:
		await _shoot(narr, tt, "talk_narr_%03d" % int(tt * 100.0))
	if talk != "":
		for tt in [0.15, 9.0]:
			await _shoot(talk, tt, "talk_who_%03d" % int(tt * 100.0))
		await _strip(talk)
	quit(0)


#  글자가 툭툭 나오는 띠(2026-10-03) — 상인 줄 첫 줄을 1/60 초 간격 열두 장, 위에서 아래로.
#  막 나온 글자가 작게 → 크게(넘쳤다) → 제 크기로 앉고, 떨어지며 기울었다 서는지 본다.
func _strip(tid: String) -> void:
	var frames := []
	for f in 12:
		g._tutor_close()
		g.tutor_q.clear()
		g.tutor_out = 0.0
		g.tutor_id = tid
		g.tutor_i = 0
		g.tutor_pre = 0.0
		var tt: float = 0.10 + float(f) / 60.0
		g.tutor_t = tt
		await _wait(2)
		g.tutor_t = tt
		g.queue_redraw()
		await RenderingServer.frame_post_draw
		var im: Image = root.get_texture().get_image()
		var k: float = float(im.get_width()) / 640.0
		var box: Rect2 = g._tutor_box()
		var r := Rect2i(int((box.position.x + 4.0) * k), int((box.position.y + 2.0) * k),
				int(220.0 * k), int(28.0 * k))
		frames.append(im.get_region(r))
	var fw: int = (frames[0] as Image).get_width()
	var fh: int = (frames[0] as Image).get_height()
	var out := Image.create(fw, fh * frames.size(), false, (frames[0] as Image).get_format())
	for i in frames.size():
		out.blit_rect(frames[i], Rect2i(0, 0, fw, fh), Vector2i(0, i * fh))
	out.save_png("res://shots/talk_pop.png")
