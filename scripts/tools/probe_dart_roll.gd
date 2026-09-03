extends SceneTree
# 다트도 사탕처럼 굴러 넘어가는지 헤드리스로 잰다.
#     godot --headless --script scripts/tools/probe_dart_roll.gd

func _initialize() -> void:
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.gold = 30
	g._open_shop()
	g._drop_settle()

	var di := -1
	for i in g.stock.size():
		if g.stock[i].type == "dart":
			di = i
			break
	if di < 0:
		print("이번 상점엔 다트가 없다 — 다시 굴려 본다")
		g._open_shop()
		g._drop_settle()
		for i in g.stock.size():
			if g.stock[i].type == "dart":
				di = i
				break
	print("다트 자리: ", di, " id=", (g.stock[di].d.id if di >= 0 else "?"))

	for spd in [400.0, 1100.0, 1800.0]:
		var it: Dictionary = g.drop[di]
		var u0: float = it.u
		g.hand_st = g.H.CARRY
		g.hand_src = 0
		g.hand_i = di
		g.hand_zone = -1
		it.held = true
		it.h = 0.0
		g.hand_v = Vector2(-spd, 0.0)
		g._hand_release(Vector2(200.0, 240.0))
		for k in 200:
			g._drop_update(1.0 / 60.0)
			if it.sleep and absf(it.wob) < 0.01 and absf(it.wv) < 0.01:
				break
		var dist: float = absf(it.u - u0)
		print("손속도 %6.0f -> 미끄럼 %6.1fpx -> roll %.2frad (%.1f바퀴)"
				% [spd, dist, it.roll, it.roll / TAU])
		it.u = u0
		it.vu = 0.0; it.vw = 0.0; it.om = 0.0
		it.wob = 0.0; it.wv = 0.0; it.roll = 0.0
		it.sleep = true
	quit()
