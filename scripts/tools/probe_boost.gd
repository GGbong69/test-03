extends SceneTree
# 팩을 사면 뜯기고, 뜯기면 테이블에 값 0 으로 쏟아지는가.
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
	g.gold = 60
	g._open_shop()
	g._drop_settle()
	var bi := -1
	for i in g.stock.size():
		if g.stock[i].type == "boost":
			bi = i
			break
	if bi < 0:
		print("팩이 안 떴다 — 실패"); quit(); return

	var s0: int = g.stock.size()
	var d0: int = g.drop.size()
	print("사기 전: 재고 %d · 낙하 %d · 골드 %d" % [s0, d0, g.gold])
	print("팩: %s %d골드" % [g.stock[bi].d.n, g.stock[bi].cost])
	g._buy(bi)
	print("산 직후: 뜯는 시간 %.2f · 쏟을 것 %d · 골드 %d" % [g.boost_t, g.boost_spill.size(), g.gold])

	# 연출이 끝날 때까지 돌린다
	for k in 200:
		g._boost_tick(1.0 / 60.0)
		if g.boost_t < 0.0:
			break
	print("뜯긴 뒤: 재고 %d(+%d) · 낙하 %d(+%d)"
			% [g.stock.size(), g.stock.size() - s0, g.drop.size(), g.drop.size() - d0])
	var free := 0
	for i in range(s0, g.stock.size()):
		print("   %-5s %-14s 값 %d" % [g.stock[i].type, g.stock[i].d.n, g.stock[i].cost])
		if int(g.stock[i].cost) == 0:
			free += 1
	var ok: bool = g.stock.size() == g.drop.size() and free == g.stock.size() - s0
	print("재고와 낙하가 짝이 맞고 전부 공짜인가: %s" % ("성공" if ok else "실패"))
	quit()
