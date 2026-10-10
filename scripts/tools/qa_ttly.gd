extends SceneTree
# 제목 판 밑 분필 점수(2026-10-10 · game.gd TTLY) — 못 박는 것:
#   ① 방금 꽂힌 값이 판 밑 나무에 분필로 적힌다(떠다니는 글 · 칠판 대신).
#   ② 던진 수는 안 센다(「걍 시작 화면에서 던진 발 횟수는 빼자」) — 세기 열쇠를 안 쓴다.
#   ③ 글 칸은 판 밑 나무에 선다 — 판 테(숫자 고리) 밖 · 판과 같은 가로 한가운데.
#   ④ 인트로 세 발의 합은 문에 적히고, 제목은 빈 문으로 선다(「시작 할때는 없어야지」).
#   godot --headless --path . --script scripts/tools/qa_ttly.gd
const Save = preload("res://scripts/save.gd")
var g = null
var ok := 0
var bad := 0
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_qa_ttly_g.cfg"
	Save.path = "user://_qa_ttly.cfg"
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
	g.state = g.S.TITLE
	_ok("던지기 전엔 빈 칠판", g.ttly_last == "")

	# ① · ②
	var tg: Vector2 = g.BC + Vector2(0.0, -g.R * 0.61)
	g._ttl_throw(tg)
	for i in 30:
		g._ttl_board(1.0 / 60.0)
	var inf: Dictionary = g.hit_info(tg)
	var want := str(int(inf.base) * maxi(int(inf.mult), 0))
	_ok("① 꽂힌 값이 칠판에 적힌다", g.ttly_last == want and g.ttly_last_t >= 0.0,
			"「%s」 (바란 것 %s)" % [g.ttly_last, want])
	_ok("② 던진 수를 안 센다", Save.tally("title:darts") == 0)

	# ④ 인트로 — 세 발의 합을 문에 고쳐 쓰고, 제목은 빈 문으로 선다
	g._intro_begin()
	var mid := ""
	for i in 600:
		g._intro_tick(1.0 / 60.0)
		g._ttl_board(1.0 / 60.0)
		if g.state == g.S.INTRO and g.ttly_last != "":
			mid = g.ttly_last
		if g.state == g.S.TITLE:
			break
	_ok("④ 인트로 중엔 합이 문에 적힌다", mid != "", "「%s」" % mid)
	_ok("④ 제목은 빈 문으로 선다", g.state == g.S.TITLE and g.ttly_last == "" and g.ttly_prev == "",
			"「%s」" % g.ttly_last)

	# ③
	var box: Rect2 = g._ttly_box()
	_ok("③ 판 밑 · 숫자 고리 밖", box.position.y - g.BC.y > g.R * 1.25, "%.0f" % (box.position.y - g.BC.y))
	_ok("③ 판과 같은 가로 한가운데", absf(box.get_center().x - g.BC.x) < 0.5)
