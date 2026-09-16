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


#  게임 시간을 **손으로** 민다. 창이 몇 프레임을 그리든 판의 시계는
#  여기서만 간다 — 프레임을 세서 기다리면 vsync 가 꺼진 창에서 30프레임이
#  0.05초밖에 안 돼 자루가 아직 날고 있다(그 자리에서 한 번 물렸다).
func _step(n: int) -> void:
	for i in n:
		g._title_tick(1.0 / 60.0)
	await process_frame


var pin := Vector2(4.0, 4.0)        # 찍는 동안 붙들어 둘 커서 자리


func _shot(nm: String) -> void:
	#  창 위의 진짜 마우스가 조금만 움직여도 모션 이벤트가 mouse_at 을
	#  덮어쓴다. 찍는 두 프레임 동안 다시 박아 둔다.
	g.mouse_at = pin
	g.queue_redraw()
	await process_frame
	g.mouse_at = pin
	g.queue_redraw()
	await process_frame
	g.mouse_at = pin
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g.state = g.S.TITLE
	pin = Vector2(4.0, 4.0)
	await _wait(20)
	await _shot("ttl_0_bare")

	#  커서가 판 위 — 얹힌 칸이 밝아지고 숫자가 뜬다
	pin = g.BC + Vector2(-44.0, -62.0)
	await _wait(8)
	await _shot("ttl_1_hover")
	pin = g.BC + Vector2(3.0, 2.0)          # 안쪽 불
	await _wait(8)
	await _shot("ttl_2_bull")

	#  나는 중 — 시간을 손으로 놓는다
	pin = Vector2(4.0, 4.0)
	for k in [0.35, 0.75]:
		g.ttl_fly.clear()
		g.ttl_stuck.clear()
		g._ttl_throw(g.BC + Vector2(-38.0, 44.0))
		g.ttl_fly[0].t = float(g.TTL.fly) * k
		await _shot("ttl_3_fly_%d" % int(k * 100.0))
	await _step(30)
	await _shot("ttl_4_stuck")

	#  여섯 자루 — 눌러서 놓는다
	g.ttl_stuck.clear()
	for p in [Vector2(0.0, 0.0), Vector2(52.0, -60.0), Vector2(-70.0, -18.0),
			Vector2(24.0, 78.0), Vector2(-14.0, -88.0), Vector2(66.0, 30.0)]:
		g._ttl_throw(g.BC + p)
		await _step(22)
	pin = g.BC + Vector2(40.0, -20.0)
	await _wait(6)
	await _shot("ttl_5_full")

	#  지는 중 — 자루마다 나이를 손으로 놓는다. 앞의 것일수록 늙었다.
	pin = Vector2(4.0, 4.0)
	for k in [0.3, 0.7]:
		for i in g.ttl_stuck.size():
			var age: float = float(g.TTL.life) + float(g.TTL.gone) 					* (k - float(i) * 0.16)
			g.ttl_stuck[i].t = maxf(age, 0.2)
		await _shot("ttl_6_fade_%d" % int(k * 100.0))

	#  자루 위에 커서 — 뽑는 손이다
	g.ttl_stuck.clear()
	g._ttl_throw(g.BC + Vector2(30.0, 40.0))
	await _step(30)
	if not g.ttl_stuck.is_empty():
		var e0: Dictionary = g.ttl_stuck[0]
		pin = (e0.p as Vector2) - (e0.u as Vector2) * float(g.TTL.dl1)
	await _wait(6)
	await _shot("ttl_7_pull")
	print("  찍음")
	quit(0)
