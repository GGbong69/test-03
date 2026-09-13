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
	var fr = g.get_node_or_null("Front")
	if fr != null:
		fr.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)


func _check(tag: String) -> void:
	g.set_t = g.SET.t          # 다 밀려 든 상태로 잰다
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
	_ok("%s — 화면 안에 든다" % tag, top >= 96.0 and bot <= v.y - 6.0,
			"%.0f ~ %.0f (화면 %.0f · 제목 78)" % [top, bot, v.y])
	_ok("%s — 행끼리 안 겹친다" % tag, overlap.is_empty(),
			"%d줄 · %s" % [rows.size(), "없다" if overlap.is_empty() else ", ".join(overlap)])

	# 게이지는 오른쪽 판에 하나뿐이다. 판 안에 들고, 수가 앉을 자리를 비운다.
	var pn: Rect2 = g.SETP
	var tr: Rect2 = g._vol_track()
	_ok("%s — 홈이 판 안에 든다" % tag,
			pn.encloses(tr.grow(8.0)), "홈 %.0f~%.0f · 판 %.0f~%.0f"
			% [tr.position.x, tr.end.x, pn.position.x, pn.end.x])
	_ok("%s — 100 에서도 수를 안 덮는다" % tag, tr.end.x + 3.0 <= pn.end.x - 60.0,
			"손잡이 오른끝 %.1f · 수 왼쪽 %.0f" % [tr.end.x + 3.0, pn.end.x - 60.0])
	# 글줄과 오른쪽 판이 안 겹친다 — 겹치면 글씨 위에 판이 앉는다
	var lr: Rect2 = g._set_rect(0)
	_ok("%s — 글줄과 판이 안 겹친다" % tag, lr.end.x <= pn.position.x,
			"글줄 끝 %.0f · 판 시작 %.0f" % [lr.end.x, pn.position.x])


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

	# ④ 밀려 들어오는 중 — 반쯤 들어온 자리가 화면 밖으로 안 나간다
	print("")
	g.pause_from = 1
	g.set_t = float(g.SET.t) * 0.5
	var half: Rect2 = g._set_rect(0)
	g.set_t = 0.0
	var out0: Rect2 = g._set_rect(0)
	g.set_t = float(g.SET.t)
	var done: Rect2 = g._set_rect(0)
	_ok("밀려 들어온다", out0.position.x < half.position.x
			and half.position.x < done.position.x,
			"0%% %.0f → 50%% %.0f → 100%% %.0f"
			% [out0.position.x, half.position.x, done.position.x])
	_ok("다 들어오면 제자리", is_equal_approx(done.position.x, float(g.SET.x)),
			"%.0f (표 %.0f)" % [done.position.x, g.SET.x])

	# ⑤ 흐림 판이 세기를 따라간다 — 설정이 아니면 꺼져 있어야 한다.
	#    켜 두면 화면을 후면 복사해 아홉 번 따는 값을 매 프레임 낸다.
	var blur = g.get_node_or_null("Blur")
	_ok("흐림 판이 있다", blur != null, "scenes/main.tscn 의 Blur")
	if blur != null:
		g.state = g.S.SETTINGS
		g.set_t = 0.0
		for k in 60:
			g._set_tick(1.0 / 60.0)
		var on: bool = blur.visible
		g.state = g.S.TITLE
		for k in 60:
			g._set_tick(1.0 / 60.0)
		_ok("설정에서 켜지고 닫으면 꺼진다", on and not blur.visible,
				"열림 %s → 닫힘 %s" % [on, blur.visible])

	# ⑥ 눈으로
	g.state = g.S.SETTINGS
	g.pause_from = 1
	g.set_t = float(g.SET.t)
	g.set_hot = -1
	g.set_sel = 0
	await _shoot("settings_6")
	g.set_sel = 2                 # 효과음 — 오른쪽 판에 게이지가 선다
	await _shoot("settings_vol")
	g.set_sel = 5                 # 게임 나가기
	await _shoot("settings_quit")
	print("
스크린샷: settings_6.png · settings_vol.png · settings_quit.png")

	print("\n%s\n" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	quit(0 if fail == 0 else 1)
