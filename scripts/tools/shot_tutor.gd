extends SceneTree
# 배움 띠가 화면에서 어떻게 보이는가 — 상점과 제약 두 장.
#   godot --path . --quit-after 2500 --script scripts/tools/shot_tutor.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false

func _initialize() -> void:
	Save.gpath = "user://_shot_tut_g.cfg"
	Save.path = "user://_shot_tut.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)

func _process(_d: float) -> bool:
	if busy: return false
	busy = true
	_run()
	return false

func _wait(n: int) -> void:
	for i in n:
		await process_frame

func _shot(nm: String) -> void:
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)

func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀"); quit(0); return
	g.state = g.S.TITLE
	g._new_run()
	g.gold = 40
	g.leg_no = 2
	g._open_shop()
	await _wait(70)
	# 줄에 선 것을 비우고 상점 줄만 다시 세운다
	g.tutor_q.clear()
	g.tutor_id = ""
	g.tutor_t = 0.0
	Save.forget_all()
	g._tutor("u_shop")
	await _wait(70)
	await _shot("tutor_shop")
	print("상점 · %s · 알파 %.2f" % [g.tutor_id, g._tutor_a()])
	g.tutor_q.clear()
	g.tutor_id = ""
	g.tutor_t = 0.0
	g._tutor("u_rack")
	await _wait(70)
	await _shot("tutor_rack")
	print("동전 · %s · 알파 %.2f" % [g.tutor_id, g._tutor_a()])
	print("끝")
	quit(0)
