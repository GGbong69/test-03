extends SceneTree
# 판 고르기의 나무 간판을 본다 — 첫 판 · 하나 깬 뒤 · 깨고 건너뛴 뒤(보스 앞).
#   godot --path . --quit-after 900 --script scripts/tools/shot_signs.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_sign_g.cfg"
	Save.path = "user://_shot_sign.cfg"
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
	for i in 3:
		g._tutor_close()
		g.tutor_out = 0.0
		g.swap_live = false
		g.leg_t = 9.0
		g.mouse_at = Vector2(-50.0, -50.0)
		g.queue_redraw()
		await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)


func _leg(no: int, skipped: Array) -> void:
	g.leg_skipped = {}
	for s in skipped:
		g.leg_skipped[int(s)] = true
	g.leg_no = no
	g._open_leg()


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g._new_run()
	await _wait(20)
	_leg(1, [])
	await _shot("sign_1")
	_leg(2, [])
	await _shot("sign_2")
	_leg(3, [2])
	await _shot("sign_3")
	#  딜 중 — 조각이 미끄러져 오는 동안에도 다각형이 안 깨지는가
	_leg(2, [])
	for t in [0.05, 0.15, 0.30]:
		for k in 2:
			g.leg_t = t
			g.swap_live = false
			g._tutor_close()
			g.queue_redraw()
			await process_frame
	print("  찍음")
	quit(0)
