extends SceneTree
# 막대 물리 검증 — 같은 세기로 밀어도 자루 방향에 따라 거리가 달라야 한다.
#     godot --headless --script scripts/tools/probe_dart_phys.gd
#
# 밀 방향은 늘 u(테이블의 넓은 축)로 고정한다 — w 는 깊이가 102px 뿐이라
# 벽에 먼저 닿아 마찰을 못 잰다. 대신 자루의 방향(psi)을 돌린다.
# psi=0 이면 밀 방향과 자루가 나란해 긁히고, psi=90° 면 가로질러 굴러간다.

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
		print("다트 없음")
		quit()
		return

	var it: Dictionary = g.drop[di]
	print("다트 %s · 마찰비 굴림 %.2f 미끄럼 %.2f"
			% [g.stock[di].d.id, g.DROP.mu_roll, g.DROP.mu_slide])

	var cases := [[0.0, "자루와 나란히 밀기 (긁힌다)"],
			[PI * 0.25, "45도 어긋나게 밀기"],
			[PI * 0.5, "자루를 가로질러 밀기 (구른다)"]]
	for pair in cases:
		var ps: float = pair[0]
		var u0 := 320.0
		var w0 := 70.0
		it.u = u0
		it.w = w0
		it.psi = ps
		it.roll = 0.0
		it.om = 0.0
		it.wob = 0.0
		it.wv = 0.0
		it.h = 0.0
		it.vh = 0.0
		it.air = false
		it.sleep = false
		it.rest = 0.0
		it.vu = -260.0
		it.vw = 0.0
		g.drop_awake = true
		g.drop_toss = true
		g.drop_t = 0.0
		g.drop_acc = 0.0
		for k in 400:
			g._drop_update(1.0 / 60.0)
			if it.sleep:
				break
		var dist := Vector2(it.u - u0, it.w - w0).length()
		print("%-34s 거리 %6.1fpx · 구른 각 %5.2frad (%.2f바퀴)"
				% [pair[1], dist, it.roll, it.roll / TAU])
	quit()
