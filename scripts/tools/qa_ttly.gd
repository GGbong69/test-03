extends SceneTree
# 제목 판 밑 분필 점수(2026-10-10 · game.gd TTLY) — 못 박는 것:
#   ① 방금 꽂힌 값이 판 밑 나무에 분필로 적힌다(떠다니는 글 · 칠판 대신).
#   ② 던진 수는 안 센다(「걍 시작 화면에서 던진 발 횟수는 빼자」) — 세기 열쇠를 안 쓴다.
#   ③ 쓸 때마다 문 위 다른 자리(판 밖 · 문 안 · 바로 앞 자리와 떨어져) · 손으로 쓴 기울기.
#   ⑤ 손잡이에 얹으면 문이 살짝 열리고 · 누르면 그 자리에서 이어 연다(DOORT.peek_*).
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

	# ③ 쓸 때마다 문 위 다른 자리 — 판(숫자 고리) 밖 · 문 안 · 바로 앞 자리와 떨어져
	g.state = g.S.TITLE
	var seen := {}
	var all_out := true
	var all_in := true
	var near := 0
	var prev: Vector2 = g.ttly_at
	for i in 12:
		g._ttl_throw(g.BC + Vector2(0.0, -g.R * 0.61))
		for j in 30:
			g._ttl_board(1.0 / 60.0)
		var at: Vector2 = g.ttly_at
		seen[str(at.round())] = true
		if at.length() <= g.R * 1.2:
			all_out = false
		if absf(at.x) > 215.0 or at.y > 185.0:
			all_in = false
		if at.distance_to(prev) < float(g.TTLY.apart) * 0.5:
			near += 1
		prev = at
	_ok("③ 자리가 그때그때 다르다", seen.size() >= 8, "%d곳" % seen.size())
	_ok("③ 판 밖에만 쓴다", all_out)
	_ok("③ 문 안에만 쓴다", all_in)
	_ok("③ 바로 앞 자리와 겹치지 않는다", near <= 1, "%d번" % near)
	_ok("③ 손으로 쓴 기울기", absf(g.ttly_rot) <= float(g.TTLY.tilt) + 0.0001)

	# ⑤ 손잡이에 얹으면 문이 살짝 — 다 열림의 peek_deg / open_deg 몫 · 누르면 그 자리에서 이어 연다
	g.door_t = -1.0
	g.door_peek = 1.0
	var pk: float = g._door_k()
	var want_pk: float = float(g.DOORT.peek_deg) / float(g.Door3D.DOOR.open_deg)
	_ok("⑤ 얹으면 살짝 열린다(%.0f°)" % float(g.DOORT.peek_deg), absf(pk - want_pk) < 0.0001,
			"%.4f" % pk)
	g.door_k0 = pk
	g.door_t = 0.0
	_ok("⑤ 누르면 열린 자리에서 이어 연다", absf(g._door_k() - pk) < 0.0001)
	g.door_t = 10.0
	_ok("⑤ 끝엔 다 열린다", absf(g._door_k() - 1.0) < 0.0001)
	g.door_t = -1.0
	g.door_peek = 0.0
	g.door_k0 = 0.0
	_ok("⑤ 떼면 닫힌다", g._door_k() == 0.0)
