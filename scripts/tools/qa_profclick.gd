extends SceneTree
# 프로필 한 번 누름(2026-10-10 · game.gd _click S.PROFILE) — 못 박는 것:
#   ① 다른 프로필 줄을 한 번 누르면 그 프로필로 간다(옛 판은 첫 누름이 고르기 · 둘째가 들어가기).
#   ② 돌아오는 것도 한 번이다.
#   ③ 쓰는 줄을 또 누르면 아무것도 안 바뀐다.
#   ④ 지우기는 여전히 두 번 묻는다 — 한 번 누름에 안 지워진다.
#   godot --headless --path . --script scripts/tools/qa_profclick.gd
const Save = preload("res://scripts/save.gd")
var g = null
var ok := 0
var bad := 0
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_qa_profclick_g.cfg"
	Save.path = "user://_qa_profclick.cfg"
	Save.prof_fmt = "user://_qa_profclick_%d.cfg"
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
	print("  %s %-44s %s" % ["통과" if cond else "실패", nm, note])


func _row(i: int) -> Vector2:
	return (g._prof_rect(i) as Rect2).get_center()


func _run() -> void:
	Save.use_slot(1)
	Save.set_pick("league", "std")
	Save.flush()
	g._open_profile()
	_ok("프로필 화면이 1번에서 연다", g.state == g.S.PROFILE and Save.slot() == 1)

	# ①
	g._click(_row(1))
	_ok("① 2번 줄을 한 번 누르면 2번 프로필로 간다", Save.slot() == 2 and g.prof_sel == 2,
			"쓰는 줄 %d · 고른 줄 %d" % [Save.slot(), g.prof_sel])
	_ok("① 화면은 그대로 프로필이다", g.state == g.S.PROFILE)

	# ②
	g._click(_row(0))
	_ok("② 1번으로 돌아오는 것도 한 번이다", Save.slot() == 1, "쓰는 줄 %d" % Save.slot())

	# ③
	g._click(_row(0))
	_ok("③ 쓰는 줄을 또 누르면 그대로다", Save.slot() == 1 and g.prof_sel == 1)

	# ④
	_ok("1번이 쓰인 자리다(지우기의 전제)", Save.slot_used(1))
	g._click((g._prof_del_rect() as Rect2).get_center())
	_ok("④ 지우기는 한 번 누름에 안 지운다", Save.slot_used(1) and g.prof_arm == 1,
			"겨눔 %d" % g.prof_arm)
	g._click(_row(1))
	_ok("④ 딴 줄을 누르면 겨눔이 풀린다", g.prof_arm == -1 and Save.slot_used(1))
