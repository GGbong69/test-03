extends SceneTree
# 판 위에서도 동전을 팔 수 있는가. 상점이 아닌 화면에서 버튼을 눌러 본다.
#     godot --headless --script scripts/tools/probe_sell_any.gd

func _initialize() -> void:
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g._new_run()
	# 동전 둘을 손으로 넣는다
	var gd = load("res://scripts/data.gd")
	var its = gd.items()
	g.owned.append(its[0])
	g.owned.append(its[1])
	g._panel_reset()
	print("동전 %d 개 · 골드 %d" % [g.owned.size(), g.gold])

	for st in [g.S.PICK, g.S.STAGE, g.S.LEG, g.S.SHOP]:
		g.state = st
		g.sell_sel = 1
		var r = g._sell_btn_rect()
		var names := ["PICK(판 위)", "STAGE", "LEG", "SHOP"]
		var nm: String = names[[g.S.PICK, g.S.STAGE, g.S.LEG, g.S.SHOP].find(st)]
		print("%-12s can_sell=%s 버튼=%s"
				% [nm, g._can_sell(), "없음" if r.size.x <= 0.0 else str(r)])

	# 판 위에서 실제로 팔아 본다
	g.state = g.S.PICK
	g.sell_sel = 1
	var r2: Rect2 = g._sell_btn_rect()
	var mid: Vector2 = r2.get_center()
	var g0: int = g.gold
	var n0: int = g.owned.size()
	var want: int = gd.sell_value(g.owned[1])
	g._hand_press(mid)
	print("누른 뒤 hand_src=%d hand_i=%d" % [g.hand_src, g.hand_i])
	g._hand_release(mid)
	print("팔고 나서 동전 %d→%d · 골드 %d→%d (기대 +%d)"
			% [n0, g.owned.size(), g0, g.gold, want])
	print("성공" if g.owned.size() == n0 - 1 and g.gold == g0 + want else "실패")
	quit()
