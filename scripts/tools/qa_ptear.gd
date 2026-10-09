extends SceneTree
# 사진 찢기(2026-10-08 · game.gd PTEAR) — 못 박는 것:
#   ① 사진을 칸에서 쓰면 찢기가 하나 서고, 칸 밑으로 빠져나오는 거리(drop)를 단다.
#   ② 가운데로 끌어 놓아 쓰면 놓은 자리에서 찢기고 빠져나오지 않는다 · 놓은 자리는 한 번만 읽는다.
#   ③ 사탕은 찢기가 안 선다. 못 쓰는 자리(거절)에서도 안 선다.
#   ④ 찢기는 PTEAR.t 뒤 사라진다.
#   godot --headless --path . --script scripts/tools/qa_ptear.gd
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
var g = null
var ok := 0
var bad := 0
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_qa_ptear_g.cfg"
	Save.path = "user://_qa_ptear.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if g != null:
		g.set_process(false)
	if busy:
		return false
	busy = true
	_run()
	print("통과 %d · 실패 %d" % [ok, bad])
	quit(1 if bad > 0 else 0)
	return false


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-50s %s" % ["통과" if cond else "실패", nm, note])


func _row(id: String) -> Dictionary:
	for c in GameData.consumables():
		if String(c.get("id", "")) == id:
			return (c as Dictionary).duplicate()
	return {}


func _run() -> void:
	g._new_run()
	g.tut_run = false
	g.gold = 40
	g._open_shop()
	g._swap_skip()
	g.ptears.clear()

	# ①
	g.cons = [_row("v_cash")]
	var at: Vector2 = g._cons_rect(0).get_center()
	g._cons_use(0)
	_ok("① 사진을 칸에서 쓰면 찢기가 선다", g.ptears.size() == 1)
	if g.ptears.size() == 1:
		var e: Dictionary = g.ptears[0]
		_ok("① 칸 자리에서 · 칸 밑으로 빠져나온다", (e.p as Vector2).is_equal_approx(at)
				and is_equal_approx(float(e.dy), float(g.PTEAR.drop)), "%s %s" % [e.p, e.dy])
	g.ptears.clear()

	# ②
	g.cons = [_row("v_cash")]
	g.use_from = g.BC + Vector2(5, -3)
	g._cons_use(0)
	_ok("② 끌어 놓아 쓰면 놓은 자리 · 안 빠져나온다", g.ptears.size() == 1
			and (g.ptears[0].p as Vector2).is_equal_approx(g.BC + Vector2(5, -3))
			and float(g.ptears[0].dy) == 0.0)
	_ok("② 놓은 자리는 한 번만 읽는다", not g.use_from.is_finite())
	g.ptears.clear()

	# ③
	g.cons = [_row("c_sg")]
	g._cons_use(0)
	_ok("③ 사탕은 찢기가 안 선다", g.ptears.is_empty())
	g.owned = []
	g.cons = [_row("v_moth")]
	g._cons_use(0)
	_ok("③ 못 쓰는 자리(거절)에서는 안 선다", g.ptears.is_empty() and g.cons.size() == 1)

	# ④
	g.cons = [_row("v_cash")]
	g._cons_use(0)
	for i in int(ceil(float(g.PTEAR.t) * 60.0)) + 2:
		g._ptear_tick(1.0 / 60.0)
	_ok("④ PTEAR.t 뒤 사라진다", g.ptears.is_empty())
