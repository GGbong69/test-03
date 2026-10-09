extends SceneTree
# 사진 찢기(2026-10-08 · game.gd PTEAR) — 못 박는 것:
#   ① 사진을 칸에서 쓰면 찢기가 하나 서고 칸에서 출발해 화면 가운데로 커지며 온다(팩 뜯기와 같은 흐름).
#   ② 가운데로 끌어 놓아 쓰면 놓은 자리에서 출발한다 · 놓은 자리는 한 번만 읽는다.
#   ③ 사탕은 찢기가 안 선다. 못 쓰는 자리(거절)에서도 안 선다.
#   ④ 오는 · 찢기는 · 사라지는 몫이 차례로 선다 · 다 끝나면 사라진다.
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
		var p0: Dictionary = g._ptear_pose(e)
		_ok("① 칸 자리에서 칸 크기로 출발한다", (p0.c as Vector2).is_equal_approx(at)
				and is_equal_approx(float(p0.k), float(g.PTEAR.k0)), "%s %.2f" % [p0.c, p0.k])
		e.t = float(g.PTEAR.rise)
		var p1: Dictionary = g._ptear_pose(e)
		var mid := Vector2(g.VIEW.x * 0.5, g.VIEW.y * float(g.PTEAR.cy))
		_ok("① 가운데로 커지며 온다(팩과 같은 자리)", (p1.c as Vector2).is_equal_approx(mid)
				and is_equal_approx(float(p1.k), float(g.PTEAR.big)), "%s %.2f" % [p1.c, p1.k])
		_ok("① 이름을 단다", String(e.get("n", "")) != "", String(e.get("n", "")))
	g.ptears.clear()

	# ②
	g.cons = [_row("v_cash")]
	g.use_from = g.BC + Vector2(5, -3)
	g._cons_use(0)
	_ok("② 끌어 놓아 쓰면 놓은 자리에서 출발한다", g.ptears.size() == 1
			and (g.ptears[0].p as Vector2).is_equal_approx(g.BC + Vector2(5, -3)))
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
	var e4: Dictionary = g.ptears[0]
	e4.t = float(g.PTEAR.rise) * 0.5
	var a: Dictionary = g._ptear_pose(e4)
	e4.t = float(g.PTEAR.rise) + float(g.PTEAR.tear) * 0.5
	var b: Dictionary = g._ptear_pose(e4)
	e4.t = float(g.PTEAR.rise) + float(g.PTEAR.tear) + float(g.PTEAR.out) * 0.5
	var c: Dictionary = g._ptear_pose(e4)
	_ok("④ 오는 동안은 안 찢긴다 · 그다음 찢긴다 · 그다음 사라진다",
			float(a.u) == 0.0 and float(b.u) > 0.0 and float(b.o) == 0.0 and float(c.o) > 0.0
			and float(c.u) == 1.0, "%s %s %s" % [a.u, b.u, c.o])
	e4.t = 0.0
	for i in int(ceil(g._ptear_len() * 60.0)) + 2:
		g._ptear_tick(1.0 / 60.0)
	_ok("④ 다 끝나면 사라진다", g.ptears.is_empty())
