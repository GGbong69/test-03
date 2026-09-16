extends SceneTree
# 제목 판을 눈으로 본다 — 날아오는 중 · 꽂힌 판 · 걷히는 중.
#   godot --path . --quit-after 900 --script scripts/tools/shot_title.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_ttl_g.cfg"
	Save.path = "user://_shot_ttl.cfg"
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
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g.state = g.S.TITLE
	g.ttl_wait = 99.0
	g.mouse_at = Vector2(4.0, 4.0)
	await _wait(20)
	await _shot("ttl_0_bare")

	#  나는 중 — 시간을 손으로 놓는다. 프레임을 세면 창이 느릴 때
	#  엉뚱한 순간이 찍힌다.
	for k in [0.2, 0.5, 0.8]:
		g.ttl_fly.clear()
		g.ttl_stuck.clear()
		g._ttl_throw(g.BC + Vector2(-38.0, 44.0))
		g.ttl_fly[0].t = float(g.TTL.fly) * k
		await _shot("ttl_1_fly_%d" % int(k * 100.0))
	await _wait(30)
	await _shot("ttl_2_stuck")

	#  다섯 자루 더. 판이 어떻게 보이는지가 여기서 갈린다.
	for p in [Vector2(0.0, 0.0), Vector2(52.0, -60.0), Vector2(-70.0, -18.0),
			Vector2(24.0, 78.0), Vector2(-14.0, -88.0)]:
		g._ttl_throw(g.BC + p)
		await _wait(20)
	await _shot("ttl_3_full")

	#  걷히는 중 — 여기도 시간을 손으로 놓는다
	for k in [0.3, 0.7]:
		g.ttl_sweep = float(g.TTL.sweep) * (1.0 - k)
		await _shot("ttl_4_sweep_%d" % int(k * 100.0))
	await _wait(60)
	await _shot("ttl_5_clean")

	#  커서가 판 위 — 겨눔점
	g._ttl_throw(g.BC + Vector2(60.0, 20.0))
	await _wait(22)
	g.mouse_at = g.BC + Vector2(-30.0, -34.0)
	await _wait(6)
	await _shot("ttl_6_aim")
	print("  찍음")
	quit(0)
