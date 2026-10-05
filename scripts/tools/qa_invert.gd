extends SceneTree
#  불스아이 반전(2026-10-06 · game.gd 의 INV · _invert_kick · _inv_tick).
#  「다트의 볼스아이를 맞췄을때 진짜 짧게 색상 반전 주는거 어때? 시작 화면 말고 인게임 플레이에서만」
#  못 박는 것:
#    ① 판에서 안쪽 불(5단)이 꽂히면 반전 층(96)이 서고, INV.ms 뒤에 숨는다.
#    ② 바깥 불(4단) · 트리플(3단)에는 안 선다.
#    ③ 시작 화면 · 모션 끔에서는 안 선다.
#    ④ 선 동안 화면이 정말 뒤집힌다 — 판 한가운데 한 점의 밝기가 뒤집힌다.
#  shots/invert_on.png · invert_off.png 를 남긴다. 창이 있어야 돈다:
#    godot --path . --script scripts/tools/qa_invert.gd
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false
var ok := 0
var bad := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_invert_g.cfg"
	Save.path = "user://_qa_invert.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if busy:
		return false
	busy = true
	_run()
	return false


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-40s %s" % ["통과" if cond else "실패", nm, note])


func _wait(n: int) -> void:
	for _i in n:
		await process_frame


func _ms(ms: int) -> void:
	var t0: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < ms:
		await process_frame


func _shot() -> Image:
	g.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _on() -> bool:
	return g.inv_rect != null and is_instance_valid(g.inv_rect) and g.inv_rect.visible


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 선다")
		quit(0)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	for id in ["u_leg", "u_skip", "u_boss", "u_score", "u_clear", "u_shop", "u_rack",
			"u_cons", "u_sell", "u_reroll", "u_give", "u_boot", "u_gift"]:
		Save.teach(id)
	#  모션은 켠다 — 검사 도구는 _cine_ok 가 막으므로 force 대신 도구 막음만 푼다.
	g.motion_off = false
	g._new_run(true)
	g._tutor_close()
	g.tutor_q.clear()
	g._swap_skip()
	g._begin_leg()
	g._swap_skip()
	await _wait(20)
	print("① · ④ 안쪽 불")
	var off_im: Image = await _shot()
	off_im.save_png("res://shots/invert_off.png")
	g._invert_kick(true)          # 도구 막음(_cine_ok)을 넘는 길 — 부르는 자리는 ②가 따로 본다
	var on_im: Image = await _shot()
	on_im.save_png("res://shots/invert_on.png")
	_ok("서는 틀에 층이 보인다", _on())
	var p := Vector2i(int(g.BC.x * 2.0) + 40, int(g.BC.y * 2.0) + 60)
	var a: Color = off_im.get_pixelv(p)
	var b: Color = on_im.get_pixelv(p)
	_ok("화면이 뒤집혔다", absf((a.r + b.r) - 1.0) < 0.2 and absf((a.g + b.g) - 1.0) < 0.2
			and absf((a.b + b.b) - 1.0) < 0.2, "%s → %s" % [str(a), str(b)])
	await _ms(int(g.INV.ms) + 60)
	_ok("INV.ms 뒤에 숨는다", not _on(), "%d ms" % int(g.INV.ms))
	print("② 안쪽 불이면 부른다 · 다른 칸은 안 부른다")
	var src: String = (g.get_script() as GDScript).source_code
	var i5 := src.find("\t\t5:\n", src.find("func _impact("))
	var i4 := src.find("\t\t4:\n", src.find("func _impact("))
	var e5 := src.find("\n\n", i5)
	_ok("5단(안쪽 불)이 _invert_kick 을 부른다", i5 > 0 and src.substr(i5, e5 - i5).find("_invert_kick(") > 0)
	_ok("4단(바깥 불)은 안 부른다", i4 > 0 and src.substr(i4, i5 - i4).find("_invert_kick(") < 0)
	print("③ 막는 자리")
	var st = g.state
	g.state = g.S.TITLE
	g.inv_until = 0
	g._inv_tick()
	g._invert_kick(true)
	_ok("시작 화면은 안 선다(force 여도)", not _on())
	g.state = st
	g.motion_off = true
	g._invert_kick(true)
	_ok("모션 끔은 안 선다", not _on())
	g.motion_off = false
	g._invert_kick()
	_ok("검사 도구(force 없이)는 안 선다", not _on())
	print("통과 %d · 실패 %d" % [ok, bad])
	quit(bad)
