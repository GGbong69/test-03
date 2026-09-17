extends SceneTree
# 배움 예고 — 조여 드는 어둠 · 튀는 「!」 · 말상자. 판 고르기(u_leg)와 판 위 점수(u_score 첫 과녁 board).
#   godot --path . --quit-after 3000 --script scripts/tools/shot_tutor_pre.gd
const Save = preload("res://scripts/save.gd")
const AT := [0.06, 0.22, 0.40, 0.62, 0.80]
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_tp_g.cfg"
	Save.path = "user://_shot_tp.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if g != null:
		g.mouse_at = Vector2(-50.0, -50.0)
	if busy: return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _seq(tag: String) -> void:
	g.set_process(false)
	var clock := 0.0
	var k := 0
	var dt := 1.0 / 60.0
	while k < AT.size():
		g._tutor_tick(dt)
		g.queue_redraw()
		clock += dt
		await process_frame
		if clock >= float(AT[k]):
			root.get_texture().get_image().save_png("res://shots/tpre_%s_%d.png" % [tag, k])
			k += 1
	g._tutor_close()
	g.tutor_out = 0.0
	g.set_process(true)


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		quit(0)
		return
	g._new_run()
	await _wait(10)
	#  판 고르기 — _open_leg 가 u_leg 를 줄에 세운다
	g._open_leg()
	g._swap_skip()
	await _seq("leg")
	#  판 위 — 점수 설명의 첫 과녁(board)
	g._start_leg()
	g._swap_skip()
	g.state = g.S.PICK
	g._pick_dart(0)
	await _wait(10)
	g.tutor_q.clear()
	g._tutor_close()
	g.tutor_out = 0.0
	g._tutor("u_score")
	await _seq("score")
	print("  찍음")
	quit(0)
