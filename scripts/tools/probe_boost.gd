extends SceneTree
# 팩이 상점에 뜨고, 사면 펼쳐지고, 고르면 칸에 들어가는가.
#     godot --headless --script scripts/tools/probe_boost.gd
var g = null
var n := 0
var busy := false
func _process(_d: float) -> bool:
	if busy: return false
	n += 1
	if n == 1:
		g = load("res://scenes/main.tscn").instantiate()
		root.add_child(g)
	elif n == 6:
		busy = true
		_go()
	return false

func _go() -> void:
	var gd = load("res://scripts/data.gd")
	print("팩 표: %d종" % gd.boosters().size())
	for b in gd.boosters():
		print("  %-8s %-8s 펼침 %d · 고름 %d · 값 %d" % [b.id, b.n, b.size, b.pick, b.cost])

	g.gold = 60
	g._open_shop()
	g._drop_settle()
	var types := []
	for st in g.stock: types.append(st.type)
	print("\n재고: %s" % str(types))

	var bi := -1
	for i in g.stock.size():
		if g.stock[i].type == "boost":
			bi = i
			break
	if bi < 0:
		print("팩이 안 떴다 — 실패")
		quit(); return

	print("팩 자리 %d · %s · %d골드" % [bi, g.stock[bi].d.n, g.stock[bi].cost])
	var g0: int = g.gold
	g._buy(bi)
	print("사고 나서 state=%s (BOOST=%d) · 펼친 수 %d · 고를 수 %d · 골드 %d→%d"
			% [g.state, g.S.BOOST, g.boost_open.size(), g.boost_left, g0, g.gold])
	for e in g.boost_open:
		print("   %-5s %s" % [e.k, e.d.n])

	var o0: int = g.owned.size()
	var c0: int = g.cons.size()
	var f0: int = gd.fixtures_own.size()
	g._boost_take(0)
	print("첫 장을 골랐다 -> 동전 %d→%d · 사탕 %d→%d · 사진 %d→%d · state=%s"
			% [o0, g.owned.size(), c0, g.cons.size(), f0, gd.fixtures_own.size(), g.state])
	print("성공" if g.state != g.S.BOOST else "아직 고르는 중")
	quit()
