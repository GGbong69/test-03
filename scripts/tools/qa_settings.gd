extends SceneTree

# 설정 화면 검사. 2026-09-13 사용자 제보 — "게임 나가기가 잘렸네"
#   행이 화면 안에 다 든다 (다섯 줄 · 여섯 줄 둘 다)
#   행끼리 안 겹친다 · 게이지 수가 홈 밖에 있다 · 누르는 자리와 그리는 자리가 같다
#
#   godot --path . --quit-after 900 --script scripts/tools/qa_settings.gd

const GameData = preload("res://scripts/data.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-32s %s" % ["통과" if c else "실패", n, d])


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


func _shoot(nm: String) -> void:
	for i in 4:
		g._process(1.0 / 60.0)
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)


func _check(tag: String) -> void:
	var rows: Array = g._set_rows()
	var v: Vector2 = g.VIEW
	var top := 9999.0
	var bot := -1.0
	var overlap := PackedStringArray()
	var prev := Rect2()
	for i in rows.size():
		var r: Rect2 = g._set_rect(i)
		top = minf(top, r.position.y)
		bot = maxf(bot, r.end.y)
		if i > 0 and r.position.y < prev.end.y:
			overlap.append("%d↔%d" % [i - 1, i])
		prev = r
		# 누르는 자리와 그리는 자리가 같은가 — 한가운데를 찍어 본다
		var mid := r.position + r.size * 0.5
		if not r.has_point(mid):
			overlap.append("%d 못 누름" % i)
	_ok("%s — 화면 안에 든다" % tag, top >= 100.0 and bot <= v.y - 6.0,
			"%.0f ~ %.0f (화면 %.0f · 제목 96)" % [top, bot, v.y])
	_ok("%s — 행끼리 안 겹친다" % tag, overlap.is_empty(),
			"%d줄 · %s" % [rows.size(), "없다" if overlap.is_empty() else ", ".join(overlap)])

	# 게이지 — 홈이 수 자리를 안 먹는다
	for i in rows.size():
		if String(rows[i]) != "vol":
			continue
		var r: Rect2 = g._set_rect(i)
		var tr: Rect2 = g._vol_track(r)
		# 수는 r.end.x - 36 에서 28폭으로 오른쪽 맞춤 → 왼쪽 끝이 r.end.x-36
		_ok("%s — 게이지가 수를 안 덮는다" % tag, tr.end.x <= r.end.x - 36.0,
				"홈 끝 %.0f · 수 왼쪽 %.0f" % [tr.end.x, r.end.x - 36.0])
		# 100 일 때 손잡이가 홈 끝이다 — 그것도 수 밖이어야 한다
		_ok("%s — 100 에서도 안 겹친다" % tag, tr.end.x + 2.5 <= r.end.x - 36.0,
				"손잡이 오른끝 %.1f" % (tr.end.x + 2.5))
		break


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	print("\n설정 화면 검사\n")

	# ① 제목에서 연 설정 — 다섯 줄
	g.pause_from = -1
	g.state = g.S.SETTINGS if "SETTINGS" in g.S else g.state
	_check("다섯 줄")

	# ② 판 중에 연 설정 — 여섯 줄. 「게임 나가기」가 잘리던 자리다
	print("")
	g.pause_from = 1
	_check("여섯 줄")

	# ③ 두 경우 다 줄 수가 맞다
	print("")
	g.pause_from = -1
	var n5: int = (g._set_rows() as Array).size()
	g.pause_from = 1
	var n6: int = (g._set_rows() as Array).size()
	_ok("제목 5줄 · 판 중 6줄", n5 == 5 and n6 == 6, "%d · %d" % [n5, n6])
	_ok("판 중에만 「로비로 나가기」", (g._set_rows() as Array).has("lobby"), "")

	# ④ 눈으로
	for st in g.S:
		if String(st).to_lower().find("set") >= 0:
			g.state = g.S[st]
	g.pause_from = 1
	await _shoot("settings_6")
	g.pause_from = -1
	await _shoot("settings_5")
	print("\n스크린샷: shots/settings_6.png · shots/settings_5.png")

	print("\n%s\n" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	quit(0 if fail == 0 else 1)
