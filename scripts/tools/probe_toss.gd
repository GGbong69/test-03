extends SceneTree
# 여러 세기로 던져 실제 미끄럼 거리가 달라지는지 잰다(헤드리스).
#     godot --headless --script scripts/tools/probe_toss.gd

func _initialize() -> void:
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.gold = 30
	g._open_shop()
	g._drop_settle()

	var ci := -1
	for i in g.stock.size():
		if g.stock[i].type == "cons":
			ci = i
			break

	for spd in [150.0, 400.0, 700.0, 1100.0, 1500.0, 1800.0]:
		var it: Dictionary = g.drop[ci]
		var u0: float = it.u
		g.hand_st = g.H.CARRY
		g.hand_src = 0
		g.hand_i = ci
		g.hand_zone = -1
		it.held = true
		it.h = 0.0
		g.hand_v = Vector2(-spd, 0.0)
		g._hand_release(Vector2(200.0, 240.0))
		var om0: float = it.om
		var vu0: float = it.vu
		for k in 200:
			g._drop_update(1.0 / 60.0)
			if it.sleep and absf(it.wob) < 0.01 and absf(it.wv) < 0.01:
				break
		var dist: float = absf(it.u - u0)
		print("손속도 %6.0f -> vu=%7.1f -> 미끄럼 거리 %6.1fpx -> roll %.2frad (%.1f바퀴)"
				% [spd, vu0, dist, it.roll, it.roll / TAU])
		# 원위치로 되돌려 다음 세기를 같은 조건에서 잰다
		it.u = u0
		it.vu = 0.0
		it.vw = 0.0
		it.om = 0.0
		it.wob = 0.0
		it.wv = 0.0
		it.roll = 0.0
		it.sleep = true
	quit()
