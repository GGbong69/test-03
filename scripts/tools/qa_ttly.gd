extends SceneTree
# 제목 판 밑 점수 칠판(2026-10-10 · game.gd TTLY) — 못 박는 것:
#   ① 제목 판에 던질 때마다 수가 하나 오른다(꽂히기 전 · 던지는 순간).
#   ② 수는 프로필마다 따로다 — 다른 프로필로 가면 그 프로필의 수다.
#   ③ 던질 때마다 디스크를 안 친다 — save 초 뒤 한 번 적는다.
#   ④ 칠판은 판 밑에 걸린다 — 판 테(숫자 고리) 밖 · 판과 같은 가로 한가운데.
#   ⑤ 방금 꽂힌 값이 칠판 오른쪽 칸에 적힌다(떠다니는 글 대신).
#   godot --headless --path . --script scripts/tools/qa_ttly.gd
const Save = preload("res://scripts/save.gd")
var g = null
var ok := 0
var bad := 0
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_qa_ttly_g.cfg"
	Save.path = "user://_qa_ttly.cfg"
	Save.prof_fmt = "user://_qa_ttly_%d.cfg"
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


func _run() -> void:
	Save.use_slot(1)
	Save.tally_drop("title:darts")
	g.state = g.S.TITLE
	g._ttl_throw(g.BC + Vector2(10.0, -20.0))
	g._ttl_throw(g.BC)
	_ok("① 던질 때마다 하나씩", Save.tally("title:darts") == 2, "%d" % Save.tally("title:darts"))
	_ok("③ 곧바로는 안 적는다(시계가 선다)", g.ttly_save > 0.0)
	for i in 80:
		g._ttl_board(1.0 / 60.0)
	_ok("③ save 초 뒤 한 번 적는다", g.ttly_save < 0.0)

	# ②
	g._use_profile(2)
	Save.tally_drop("title:darts")
	_ok("② 다른 프로필은 제 수", Save.tally("title:darts") == 0)
	g._ttl_throw(g.BC)
	g._use_profile(1)
	_ok("② 돌아오면 그 프로필의 수 그대로", Save.tally("title:darts") == 2, "%d" % Save.tally("title:darts"))

	# ⑤ 방금 꽂힌 값이 칠판 오른쪽 칸에 적힌다(2026-10-10 「칠판에 분필로」)
	var tg: Vector2 = g.BC + Vector2(0.0, -g.R * 0.61)
	g._ttl_throw(tg)
	for i in 30:
		g._ttl_board(1.0 / 60.0)
	var inf: Dictionary = g.hit_info(tg)
	var want := str(int(inf.base) * maxi(int(inf.mult), 0))
	_ok("⑤ 꽂힌 값이 칠판에 적힌다", g.ttly_last == want and g.ttly_last_t >= 0.0,
			"「%s」 (바란 것 %s)" % [g.ttly_last, want])

	# ④
	var box: Rect2 = g._ttly_box()
	_ok("④ 판 밑 · 숫자 고리 밖", box.position.y - g.BC.y > g.R * 1.25, "%.0f" % (box.position.y - g.BC.y))
	_ok("④ 판과 같은 가로 한가운데", absf(box.get_center().x - g.BC.x) < 0.5)
