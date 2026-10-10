extends SceneTree
# 런 시간(2026-10-10 · game.gd run_secs) — 못 박는 것:
#   ① 판 위 · 상점에서 흐르고, 제목 · 런 끝 화면에서는 안 흐른다.
#   ② 이어하기는 적힌 시간을 그대로 잇는다(옛 판은 되살리며 0 으로 지웠다).
#   ③ 새 런은 0 에서 센다(옛 판은 지난 런의 시간을 이었다).
#   godot --headless --path . --script scripts/tools/qa_runsecs.gd
const Save = preload("res://scripts/save.gd")
var g = null
var ok := 0
var bad := 0
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_qa_runsecs_g.cfg"
	Save.path = "user://_qa_runsecs.cfg"
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
	print("  %s %-40s %s" % ["통과" if cond else "실패", nm, note])


func _run() -> void:
	g._new_run()
	g.tut_run = false
	g._open_leg()
	g._swap_skip()
	g._begin_leg()
	g._swap_skip()
	g.state = g.S.PICK
	_ok("① 판 위에서 시계가 돈다", g._run_clock_on())
	g.state = g.S.SHOP
	_ok("① 상점에서도 돈다", g._run_clock_on())
	g.state = g.S.TITLE
	_ok("① 제목에서는 안 돈다", not g._run_clock_on())
	g.state = g.S.OVER
	_ok("① 런 끝 화면에서는 안 돈다", not g._run_clock_on())

	# ②
	g.state = g.S.PICK
	g.run_secs = 754.0
	g._knot("leg")
	g.run_secs = 0.0
	g._run_load()
	_ok("② 이어하기는 시간을 잇는다", is_equal_approx(g.run_secs, 754.0), "%.1f" % g.run_secs)

	# ③
	g._new_run()
	_ok("③ 새 런은 0 에서 센다", is_zero_approx(g.run_secs), "%.1f" % g.run_secs)
