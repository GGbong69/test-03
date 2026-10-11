extends SceneTree
# 컬렉션 넘김 — 칠판을 지우고 다시 쓴다(2026-10-11 · game.gd COLF) — 못 박는 것:
#   ① 오른쪽 화살표 — 값은 곧장 다음 쪽 · 지우기가 선다(왼쪽에서 오른쪽 · 옛 쪽은 앞 쪽) · 툴팁이 새 쪽을 본다
#   ② 넘기는 중에 또 넘기면 그때 써지던 쪽이 옛 쪽이다 · 시계가 처음부터 · 왼쪽 화살표는 거꾸로
#   ③ 탭 — 쪽은 0 · 옛 것은 그때의 탭 · 쪽 · 오른쪽 탭은 앞으로 · 왼쪽 탭은 거꾸로 · 같은 탭 같은 쪽은 안 돈다
#   ④ 휠 — 격자 위는 쪽 · 탭 줄 위는 탭 · 방향은 휠 그대로
#   ⑤ 모션 끄기 — 컷(값만 바뀐다) · 도는 중에 끄면 그 자리에서 멎는다 · 화면을 떠나면 멎는다
#   ⑥ 시계 — 다 쓰기 전에는 안 끝나고 · 끝나면 −1 로 돌아온다
#   ⑦ 지우개 길 — 석판 안에서 넘기는 쪽으로 · 칸줄이 지우개 앞머리 차례로 지워지고 · 새 칸은 지나간 칸줄부터 위에서 아래로
#   ⑧ 소리 chalk_wipe — 표에 있고 · 파일이 있고 · 제 자리 하나
#   ⑨ 개발자 판 「컬렉션 넘김 다시 보기」 — 「다시 보기」 쪽 · 컬렉션에서만
#   godot --headless --path . --script scripts/tools/qa_colf.gd
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")
var g = null
var ok := 0
var bad := 0
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_qa_colf_g.cfg"
	Save.path = "user://_qa_colf.cfg"
	Save.prof_fmt = "user://_qa_colf_%d.cfg"
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


func _open(tab := 0, page := 0) -> void:
	g.motion_off = false
	g.state = g.S.COLLECT
	g.collect_tab = tab
	g.collect_page = page
	g.colf_t = -1.0


func _st() -> String:
	return "탭 %d 쪽 %d · t %.2f dir %d · 옛 %d/%d" % [g.collect_tab, g.collect_page,
			g.colf_t, g.colf_dir, g.colf_tab, g.colf_page]


func _run() -> void:
	g.found_all = true
	var pages: int = 0
	# ① ─────────────────────────────────────────────
	_open()
	pages = g._col_pages()
	_ok("① 동전 탭이 두 쪽 넘는다(넘길 쪽이 있다)", pages >= 2, "%d 쪽" % pages)
	g._click((g._col_arrow_rect(true) as Rect2).get_center())
	_ok("① 값은 곧장 다음 쪽", g.collect_page == 1, _st())
	_ok("① 지우기가 선다", g.colf_t == 0.0, _st())
	_ok("① 왼쪽에서 오른쪽(+1)", g.colf_dir == 1, _st())
	_ok("① 옛 것은 앞 쪽(탭 0 · 쪽 0)", g.colf_tab == 0 and g.colf_page == 0, _st())
	var hit: Dictionary = g._tip_hit((g._col_cell(0) as Rect2).get_center())
	_ok("① 툴팁이 새 쪽을 본다", int(hit.get("i", -1)) == g.COL_PAGE, "%s" % hit)
	_ok("① 쪽 수가 새 쪽 것", g._col_count() == clampi(g._col_total() - g.COL_PAGE, 0, g.COL_PAGE))

	# ② ─────────────────────────────────────────────
	g._colf_tick(0.2)
	var t_mid: float = g.colf_t
	g._click((g._col_arrow_rect(true) as Rect2).get_center())
	_ok("② 도는 중에 또 넘기면 써지던 쪽이 옛 쪽", g.colf_page == 1 and g.collect_page == 2 % pages, _st())
	_ok("② 시계가 처음부터", t_mid > 0.1 and g.colf_t == 0.0, "%.2f → %.2f" % [t_mid, g.colf_t])
	g._colf_tick(0.1)
	var p_was: int = g.collect_page
	g._click((g._col_arrow_rect(false) as Rect2).get_center())
	_ok("② 왼쪽 화살표는 거꾸로(−1)", g.colf_dir == -1 and g.colf_page == p_was
			and g.collect_page == posmod(p_was - 1, pages), _st())

	# ③ ─────────────────────────────────────────────
	_open(0, 1)
	g._click((g._col_tab_rect(2) as Rect2).get_center())
	_ok("③ 탭 — 쪽은 0 · 탭은 곧장", g.collect_tab == 2 and g.collect_page == 0, _st())
	_ok("③ 옛 것은 그때의 탭 · 쪽", g.colf_tab == 0 and g.colf_page == 1, _st())
	_ok("③ 오른쪽 탭은 앞으로(+1)", g.colf_dir == 1 and g.colf_t == 0.0, _st())
	g._click((g._col_tab_rect(1) as Rect2).get_center())
	_ok("③ 왼쪽 탭은 거꾸로(−1) · 옛 것은 써지던 탭", g.colf_dir == -1 and g.colf_tab == 2
			and g.collect_tab == 1, _st())
	_open(1, 0)
	g._click((g._col_tab_rect(1) as Rect2).get_center())
	_ok("③ 같은 탭 · 같은 쪽은 안 돈다", g.colf_t < 0.0, _st())

	# ④ ─────────────────────────────────────────────
	_open()
	g.wheel_ms = 0
	g._wheel((g._col_cell(10) as Rect2).get_center(), 1)
	_ok("④ 격자 위 휠 아래 — 다음 쪽 · +1", g.collect_page == 1 and g.colf_dir == 1
			and g.colf_page == 0 and g.colf_t == 0.0, _st())
	_open(0, 0)
	g.wheel_ms = 0
	g._wheel((g._col_cell(10) as Rect2).get_center(), -1)
	_ok("④ 격자 위 휠 위 — 앞 쪽(감긴다) · −1", g.collect_page == pages - 1 and g.colf_dir == -1
			and g.colf_page == 0, _st())
	_open(3, 0)
	g.wheel_ms = 0
	g._wheel((g._col_tab_rect(3) as Rect2).get_center(), -1)
	_ok("④ 탭 줄 위 휠 — 탭 · −1 · 옛 탭", g.collect_tab == 2 and g.colf_dir == -1
			and g.colf_tab == 3 and g.colf_t == 0.0, _st())

	# ⑤ ─────────────────────────────────────────────
	_open()
	g.motion_off = true
	g._click((g._col_arrow_rect(true) as Rect2).get_center())
	_ok("⑤ 모션 끄기 — 쪽은 넘고 지우기는 없다", g.collect_page == 1 and g.colf_t < 0.0, _st())
	g._click((g._col_tab_rect(4) as Rect2).get_center())
	_ok("⑤ 모션 끄기 — 탭도 컷", g.collect_tab == 4 and g.colf_t < 0.0, _st())
	_open()
	g._click((g._col_arrow_rect(true) as Rect2).get_center())
	g.motion_off = true
	g._colf_tick(1.0 / 60.0)
	_ok("⑤ 도는 중에 끄면 멎는다", g.colf_t < 0.0, _st())
	_open()
	g._click((g._col_arrow_rect(true) as Rect2).get_center())
	g.state = g.S.TITLE
	g._colf_tick(1.0 / 60.0)
	_ok("⑤ 화면을 떠나면 멎는다", g.colf_t < 0.0, _st())

	# ⑥ ─────────────────────────────────────────────
	_open()
	g._click((g._col_arrow_rect(true) as Rect2).get_center())
	var end: float = g._colf_end()
	var last_ta := 0.0
	for i in g._col_count():
		last_ta = maxf(last_ta, g._colf_ta(i))
	_ok("⑥ 끝은 마지막 칸이 다 선 뒤", end >= last_ta + float(g.COLF.pop), "끝 %.2f · 마지막 칸 %.2f" % [end, last_ta])
	_ok("⑥ 한 초 안에 끝난다", end <= 1.0, "%.2f" % end)
	var n := 0
	var live_half := false
	while g.colf_t >= 0.0 and n < 600:
		g._colf_tick(1.0 / 60.0)
		n += 1
		if absf(float(n) / 60.0 - end * 0.5) < 0.01:
			live_half = g.colf_t >= 0.0
	_ok("⑥ 반쯤에는 아직 돈다", live_half)
	_ok("⑥ 끝나면 −1", g.colf_t < 0.0 and n < 600, "%d 틀(%.2f초)" % [n, float(n) / 60.0])

	# ⑦ ─────────────────────────────────────────────
	var board: Rect2 = g.MENUM.board
	var ew: float = g.COLF.ew
	var eh: float = g.COLF.eh
	for dir in [1, -1]:
		_open()
		g._colf_begin(dir, 0, 1)
		var inside := true
		var mono := true
		var px: float = g._colf_at(0.0).x
		for k in 21:
			var t: float = float(g.COLF.sweep) * float(k) / 20.0
			var e: Vector2 = g._colf_at(t)
			var er := Rect2(e - Vector2(ew, eh) * 0.5, Vector2(ew, eh))
			inside = inside and board.encloses(er)
			if k > 0:
				mono = mono and float(dir) * (e.x - px) > 0.0
			px = e.x
		_ok("⑦ 지우개가 석판 안(%+d)" % dir, inside)
		_ok("⑦ 넘기는 쪽으로만 간다(%+d)" % dir, mono)
		g.colf_t = 0.0
		var w0: Array = []
		for c in g.COL_COLS:
			w0.append(g._colf_wiped(c))
		g.colf_t = float(g.COLF.sweep)
		var all_gone := true
		for c in g.COL_COLS:
			all_gone = all_gone and g._colf_wiped(c) >= 1.0
		var first_c: int = 0 if dir > 0 else g.COL_COLS - 1
		var last_c: int = g.COL_COLS - 1 if dir > 0 else 0
		_ok("⑦ 처음에는 먼 칸줄이 그대로(%+d)" % dir, float(w0[last_c]) == 0.0 and float(w0[first_c]) < 0.5,
				"%s" % [w0])
		_ok("⑦ 다 지나면 칸줄이 다 지워졌다(%+d)" % dir, all_gone)
		var order := true
		for c in g.COL_COLS - 1:
			var a: float = g._colf_ta(c)
			var b: float = g._colf_ta(c + 1)
			order = order and (b > a if dir > 0 else b < a)
		_ok("⑦ 새 칸은 지나간 칸줄부터(%+d)" % dir, order)
		var down := true
		for r in 3:
			down = down and g._colf_ta((r + 1) * g.COL_COLS + 2) > g._colf_ta(r * g.COL_COLS + 2)
		_ok("⑦ 한 칸줄 안에서는 위에서 아래로(%+d)" % dir, down)
		var after := true
		for c in g.COL_COLS:
			g.colf_t = g._colf_ta(c)
			after = after and g._colf_wiped(c) >= 1.0
		_ok("⑦ 새 칸은 옛 칸이 다 지워진 뒤(%+d)" % dir, after)
	_ok("⑦ 톡 — 0 에서 1 + over 를 거쳐 1", is_zero_approx(g._colf_pop(0.0))
			and absf(g._colf_pop(0.6) - (1.0 + float(g.COLF.over))) < 0.001 and g._colf_pop(1.0) == 1.0)

	# ⑧ ─────────────────────────────────────────────
	_ok("⑧ 소리표에 chalk_wipe", g.SFX.has("chalk_wipe"))
	_ok("⑧ 파일이 있다", ResourceLoader.exists("res://sfx/chalk_wipe.wav"))
	var st = load("res://sfx/chalk_wipe.wav") if ResourceLoader.exists("res://sfx/chalk_wipe.wav") else null
	_ok("⑧ 0.3초 넘는 지우개 소리", st != null and (st as AudioStream).get_length() > 0.3,
			"%.3f초" % ((st as AudioStream).get_length() if st != null else -1.0))
	_ok("⑧ 제 자리 하나(자리 넷 밖)", g.colf_pl != null and not (g.sfx_pool as Array).has(g.colf_pl))
	_open()
	g._click((g._col_arrow_rect(true) as Rect2).get_center())
	_ok("⑧ 넘기면 그 자리에 지우개 소리", g.colf_pl.stream == st)

	# ⑨ ─────────────────────────────────────────────
	var pg := Dev.PAGES.find("다시 보기")
	Dev.page = pg
	var rows: Array = Dev._rows(g)
	var row := {}
	for r in rows:
		if String(r.get("a", "")) == "colf":
			row = r
	_ok("⑨ 「다시 보기」 쪽에 줄이 있다", not row.is_empty(), "%d 쪽 · %d 줄" % [pg, rows.size()])
	_ok("⑨ 한 쪽 열아홉 줄 안", rows.size() <= 19, "%d 줄" % rows.size())
	_open(0, 0)
	Dev._run(g, row)
	_ok("⑨ 컬렉션에서 — 다음 쪽으로 지운다", g.collect_page == 1 and g.colf_t == 0.0
			and g.colf_page == 0 and g.colf_dir == 1, _st())
	_open(4, 0)
	var one: bool = g._col_pages() == 1
	Dev._run(g, row)
	_ok("⑨ 쪽이 하나뿐이면 같은 쪽을 다시 쓴다", not one or (g.collect_page == 0 and g.colf_t == 0.0
			and g.colf_tab == 4 and g.colf_page == 0), _st())
	_open()
	g.state = g.S.TITLE
	Dev._run(g, row)
	_ok("⑨ 컬렉션 밖에서는 아무 일도 없다", g.colf_t < 0.0 and g.collect_page == 0, _st())
	g.found_all = false
