extends SceneTree

const GameData = preload("res://scripts/data.gd")

# ══════════════════════════════════════════════════════════
#  상점 창구 검사 — 임시 도구
#
#  실행:  godot --path . --headless --script scripts/tools/shop_probe.gd
#  종료 코드 = 실패 개수
#
#  손으로 마우스를 못 굴리므로 _hand_press / _hand_motion / _hand_release 를
#  직접 부른다. 래치(_chute_at)는 따로 격자로 훑어 확인한다.
#
#  보는 것 넷
#    ① 방향이 뜻이 되는가   매물→오른쪽 = 구매 · 랙 칩→왼쪽 = 판매
#    ② 반대로 밀면 거절하는가
#    ③ 펠트에 놓으면 그냥 옮기는가
#    ④ 물리로는 창구에 못 닿는가 — 트레이 네 귀가 빗변 안쪽인가
# ══════════════════════════════════════════════════════════


func _initialize() -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	var fail := 0
	fail += _t_geometry(g)
	fail += _t_latch(g)
	fail += _t_buy(g)
	fail += _t_buy_wrong(g)
	fail += _t_sell(g)
	fail += _t_sell_wrong(g)
	fail += _t_move(g)
	print("\n%s" % ("실패 %d건" % fail if fail > 0 else "일곱 검사 전부 통과"))
	quit(mini(fail, 125))


func _say(ok: bool, name: String, detail := "") -> int:
	print("  %s %-28s %s" % ["OK  " if ok else "실패", name, detail])
	return 0 if ok else 1


# ① 물리 트레이의 어느 점에서도 물건이 빗변을 안 넘는가
func _t_geometry(g: Node) -> int:
	var worst := 999.0
	var where := ""
	for hw in [19.0, 22.0, 37.5]:
		for r in [19.0, 21.0, 9.0]:
			var w: float = g.DROP.w_lo
			while w <= g.DROP.w_hi:
				var top: float = g._p2g(w) - r * g.TBL.flat
				var bot: float = g._p2g(w) + r * g.TBL.flat
				for y in [top, bot]:
					var e: float = g._chute_edge(y)
					var m: float = (g.DROP.u_lo + hw - hw) - e   # 왼쪽 여백
					if m < worst:
						worst = m
						where = "hw %.1f r %.1f y %.1f" % [hw, r, y]
				w += 2.0
	return _say(worst > 0.0, "트레이가 창구에 못 닿는다",
			"최소 여백 %.1fpx (%s)" % [worst, where])


# ② 래치 — 펠트 한가운데는 -1, 좌우 끝은 각각 판매·구매
func _t_latch(g: Node) -> int:
	var bad := 0
	var y: float = g.TBL.fy + 4.0
	while y < g.TBL.ny:
		var e: float = g._chute_edge(y)
		if g._chute_at(Vector2(maxf(e - 2.0, 1.0), y), 0.0) != g.Z_SELL and e > 4.0:
			bad += 1
		if g._chute_at(Vector2(minf(g.VIEW.x - e + 2.0, g.VIEW.x - 1.0), y), 0.0) != g.Z_BUY and e > 4.0:
			bad += 1
		if g._chute_at(Vector2(g.VIEW.x * 0.5, y), 0.0) != -1:
			bad += 1
		y += 4.0
	# 판 밖은 언제나 -1
	for p in [Vector2(2.0, 10.0), Vector2(2.0, 340.0), Vector2(320.0, 300.0)]:
		if g._chute_at(p, 0.0) != -1:
			bad += 1
	return _say(bad == 0, "창구 래치", "어긋난 점 %d개" % bad)


func _shop(g: Node) -> void:
	g._open_shop()
	g._drop_settle()
	g.gold = 99


func _drag(g: Node, p0: Vector2, p1: Vector2) -> void:
	if not g._hand_press(p0):
		return
	g._hand_motion(p1)          # slip 을 넘겨 _hand_take 가 돌게 한다
	g.hand_m = p1
	g.hand_zone = g._chute_at(p1, 0.0)
	g._hand_release(p1)


func _item_pt(g: Node, i: int) -> Vector2:
	return Vector2(g.drop[i].u, g._p2g(g.drop[i].w))


func _buy_pt(g: Node) -> Vector2:
	return Vector2(g.VIEW.x - 3.0, g.TBL.fy + 30.0)


func _sell_pt(g: Node) -> Vector2:
	return Vector2(3.0, g.TBL.fy + 30.0)


# ③ 매물을 오른쪽으로 → 산다
func _t_buy(g: Node) -> int:
	_shop(g)
	var i := -1
	for k in g.stock.size():
		if g._buy_block(k) == "":
			i = k
			break
	if i < 0:
		return _say(false, "매물 → 오른쪽 = 구매", "살 수 있는 매물이 없다")
	var before: int = g.gold
	var cost: int = g.stock[i].cost
	_drag(g, _item_pt(g, i), _buy_pt(g))
	return _say(g.stock[i].sold and g.gold == before - cost, "매물 → 오른쪽 = 구매",
			"골드 %d → %d (가격 %d)" % [before, g.gold, cost])


# ④ 매물을 왼쪽으로 → 거절하고 판으로 돌아온다
func _t_buy_wrong(g: Node) -> int:
	_shop(g)
	var before: int = g.gold
	_drag(g, _item_pt(g, 0), _sell_pt(g))
	var it: Dictionary = g.drop[0]
	var inside: bool = it.u >= g.DROP.u_lo + it.hw - 0.01 and it.u <= g.DROP.u_hi - it.hw + 0.01
	return _say(not g.stock[0].sold and g.gold == before and inside and not it.held,
			"매물 → 왼쪽 = 거절", "골드 %d · u %.1f · 사유 '%s'" % [g.gold, it.u, g.pay_msg])


# ⑤ 랙 칩을 왼쪽으로 → 판다
func _t_sell(g: Node) -> int:
	_shop(g)
	g.owned.clear()
	for it in GameData.items():
		g.owned.append(it)
		if g.owned.size() >= 2:
			break
	g._panel_reset()
	var before: int = g.gold
	var v: int = GameData.sell_value(g.owned[0])
	var n: int = g.owned.size()
	_drag(g, g._slot_rect(0).get_center(), _sell_pt(g))
	return _say(g.owned.size() == n - 1 and g.gold == before + v, "랙 칩 → 왼쪽 = 판매",
			"골드 %d → %d (+%d) · 남은 칩 %d" % [before, g.gold, v, g.owned.size()])


# ⑥ 랙 칩을 오른쪽으로 → 거절하고 랙에 그대로 있다
func _t_sell_wrong(g: Node) -> int:
	_shop(g)
	g.owned.clear()
	g.owned.append(GameData.items()[0])
	g._panel_reset()
	var before: int = g.gold
	_drag(g, g._slot_rect(0).get_center(), _buy_pt(g))
	return _say(g.owned.size() == 1 and g.gold == before, "랙 칩 → 오른쪽 = 거절",
			"골드 %d · 남은 칩 %d · 사유 '%s'" % [g.gold, g.owned.size(), g.pay_msg])


# ⑦ 펠트에 놓으면 그냥 옮긴다
func _t_move(g: Node) -> int:
	_shop(g)
	var before: int = g.gold
	var to := Vector2(300.0, g.TBL.fy + 70.0)
	_drag(g, _item_pt(g, 0), to)
	var it: Dictionary = g.drop[0]
	return _say(not g.stock[0].sold and g.gold == before and not it.held,
			"펠트에 놓으면 이동", "u %.1f w %.1f" % [it.u, it.w])
