extends SceneTree
# 메뉴 재질(2026-10-06 · game.gd MENUM) — 못 박는 것:
#   ① 칠판은 한 붓이다 — 석판을 칠하는 줄이 _chalk_board 하나뿐이고, 제목 칠판 · 주문 칠판 ·
#      메뉴 칠판 · 설정 창이 다 그 붓을 부른다(따로 베낀 칠판이 다시 생기면 붉다).
#   ② 화면 칠판(MENUM.board)이 테까지 화면 안이고, 새 런 · 컬렉션 · 프로필의 누르는 사각이
#      전부 석판 위다 — 칠판 밖(벽 위)에 떠 있는 단추가 없다.
#   ③ 설정 창 · 일시정지의 오른쪽 판이 테 · 이름표까지 화면 안이다.
#   ④ 분필 · 새긴 글씨가 읽힌다 — 석판 · 나무 패 · 놋쇠 판 · 고른 줄 띠 위의 대비(WCAG),
#      리그 이름(표의 색 — 재질은 _on_chalk 로 밝힌다)이 석판 위에서 큰 글씨 대비 3:1 을 넘는다.
#      대비는 이 도구가 따로 센다(게임의 _wcag 를 안 빌린다).
#   ⑤ 재질 붓(mat_draw)이 그 화면 밖으로 안 샌다 — 새 런 · 컬렉션 · 프로필 · 설정 창(제목 위 ·
#      판 위 · 일시정지)을 한 틀씩 그린 뒤에 늘 내려가 있다. 재질 끔이면 옛 글자색 그대로다.
#   ⑥ 벽이 안 구워지는 자리(헤드리스)에서는 메뉴 바닥이 옛 스크림이다 — 벽을 안 짓는다.
#   ⑦ 개발자 판 — 「메뉴 재질」 줄이 열아홉 줄 안의 쪽에 서고 같은 값을 켜고 끈다.
#   godot --headless --path . --script scripts/tools/qa_menumat.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")
var g = null
var ok := 0
var bad := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_menumat_g.cfg"
	Save.path = "user://_qa_menumat.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


#  _initialize 안에서는 Game 의 _ready 가 안 돌았다 — 첫 틀에서 잰다(qa_power 와 같은 길).
var busy := false


func _process(_d: float) -> bool:
	if g != null:
		g.set_process(false)
	if busy:
		return false
	busy = true
	_go()
	return false


func _go() -> void:
	await _run()
	print("통과 %d · 실패 %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-44s %s" % ["통과" if cond else "실패", nm, note])


#  WCAG 상대휘도 · 대비(qa_ui 와 같은 식).
func _lin(c: float) -> float:
	return c / 12.92 if c <= 0.03928 else pow((c + 0.055) / 1.055, 2.4)


func _lum(c: Color) -> float:
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


func _contrast(a: Color, b: Color) -> float:
	var la := _lum(a)
	var lb := _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


#  알파 글자를 바탕 위에 얹은 색.
func _over(fg: Color, bg: Color) -> Color:
	return Color(lerpf(bg.r, fg.r, fg.a), lerpf(bg.g, fg.g, fg.a), lerpf(bg.b, fg.b, fg.a))


#  함수 몸 — func 줄부터 다음 func 줄 앞까지.
func _body(src: String, fn: String) -> String:
	var a := src.find("\nfunc %s(" % fn)
	if a < 0:
		return ""
	var b := src.find("\nfunc ", a + 1)
	return src.substr(a, (b if b > 0 else src.length()) - a)


#  한 틀 그린다 — 게임 판과 앞판(설정)을 둘 다 다시 그리게 하고 틀을 넘긴다.
func _frame() -> void:
	g.queue_redraw()
	var fr = g.get_node_or_null("Front")
	if fr != null:
		fr.queue_redraw()
	await process_frame
	await process_frame


func _run() -> void:
	var src := FileAccess.get_file_as_string("res://scripts/game.gd")
	_ok("소스를 읽는다", src.length() > 1000)

	# ── ① 한 붓 ─────────────────────────────────────────
	var slate := []
	var lines := src.split("\n")
	for i in lines.size():
		var t := String(lines[i]).strip_edges()
		if t.begins_with("#") or not t.contains("draw_rect("):
			continue
		var u := t.replace("DOORT.chalk_ink", "")
		if u.contains("DOORT.chalk"):
			slate.append(i + 1)
	_ok("① 석판을 칠하는 줄이 하나뿐", slate.size() == 1, "%s행" % [slate])
	var brush := _body(src, "_chalk_board")
	_ok("① 그 줄이 _chalk_board 안이다", slate.size() == 1 and brush != ""
			and brush.contains("Color(DOORT.chalk, a)"))
	for fn in ["_title_chalk", "_order_board_draw", "_menu_back", "_set_win_draw"]:
		_ok("① %s 가 그 붓을 부른다" % fn, _body(src, fn).contains("_chalk_board("))
	_ok("① 머리 붓도 하나 — 「하이톤」과 메뉴 머리",
			_body(src, "_title_chalk").contains("_chalk_head(")
			and _body(src, "_hdr").contains("_chalk_head("))

	# ── ② 화면 칠판 ─────────────────────────────────────
	var view := Rect2(Vector2.ZERO, g.VIEW)
	var board: Rect2 = g.MENUM.board
	_ok("② 칠판이 테까지 화면 안이다", view.encloses(board.grow(4.0)), "%s" % board)
	var hits := {}
	for t in 2:
		hits["새 런 탭 %d" % t] = g._nr_tab(t)
	for rt in [false, true]:
		hits["다트통 넘김 %s" % rt] = g._pack_arrow(rt)
		hits["컬렉션 넘김 %s" % rt] = g._col_arrow_rect(rt)
	hits["다트통 판"] = g._pack_rect()
	for i in GameData.leagues().size():
		hits["리그 칩 %d" % i] = g._league_rect(i)
	for k in GameData.packs().size():
		hits["다트통 점 %d" % k] = g._pack_pip_rect(k)
	for i in g._chal_list().size():
		hits["챌린지 줄 %d" % i] = g._chal_row(i)
	hits["시작"] = g._newrun_go()
	hits["새 런 뒤로"] = g._newrun_back()
	for t in g.COL_TABS.size():
		hits["컬렉션 탭 %d" % t] = g._col_tab_rect(t)
	for i in g.COL_PAGE:
		hits["컬렉션 칸 %d" % i] = g._col_cell(i)
	hits["메뉴 뒤로"] = g._menu_back_rect()
	for i in Save.SLOTS:
		hits["프로필 줄 %d" % i] = g._prof_rect(i)
	hits["지우기"] = g._prof_del_rect()
	var out := []
	for k in hits:
		if not board.encloses(hits[k] as Rect2):
			out.append("%s %s" % [k, hits[k]])
	_ok("② 누르는 사각 %d개가 다 석판 위다" % hits.size(), out.is_empty(), "%s" % [out])

	# ── ③ 설정 창 ───────────────────────────────────────
	var wout := []
	for pg in ["pause", "screen", "sound"]:
		var w: Rect2 = g._set_to(pg)
		if not view.encloses(w.grow(4.0)):
			wout.append("%s 테 %s" % [pg, w])
		if pg != "pause" and not view.encloses(g._set_plate(w)):
			wout.append("%s 이름표" % pg)
	_ok("③ 창 · 판의 테와 이름표가 화면 안이다", wout.is_empty(), "%s" % [wout])

	# ── ④ 읽힘 ──────────────────────────────────────────
	var ink: Color = g.DOORT.chalk_ink
	var chalk: Color = g.DOORT.chalk
	var dim: float = float(g.MENUM.dim)
	var off: float = float(g.MENUM.off)
	var rows := [
		["글 1층 분필 · 석판", _over(ink, chalk), chalk, 7.0],
		["글 2층 분필 · 석판", _over(Color(ink, dim), chalk), chalk, 4.5],
		["꺼진 글 분필 · 석판", _over(Color(ink, off), chalk), chalk, 2.5],
		["새긴 글씨 · 놋쇠 판", g.MENUM.engrave, g.Door3D.COL.brass, 4.5],
		["분필 2층 · 나무 패", _over(Color(ink, dim), g.MENUM.wood), g.MENUM.wood, 4.5],
	]
	var hot_bg: Color = g.MENUM.wood_hot
	rows.append(["얹힌 패 분필 · 얹힌 나무", _over(Color(ink, lerpf(dim, 1.0, 0.8)), hot_bg),
			hot_bg, 4.5])
	var band := _over(Color(g.C_ACC, float(g.SETB.a)), chalk)
	rows.append(["고른 줄 분필 · 띠 위", _over(ink, band), band, 4.5])
	for r in rows:
		var cr := _contrast(r[1] as Color, r[2] as Color)
		_ok("④ %s" % r[0], cr >= float(r[3]), "%.2f:1 (바라는 값 %.1f)" % [cr, r[3]])
	var weak := []
	for lg in GameData.leagues():
		var lc := Color(String(lg.get("color", "cfc9bd")))
		if lc.get_luminance() < 0.34:
			lc = lc.lightened(0.55)        # _draw_newrun 이 어두운 단을 밝히는 그 식
		lc = g._on_chalk(lc)               # 재질에서 석판 위로 한 단씩 밝힌다
		var cr := _contrast(lc, chalk)
		if cr < 3.0:
			weak.append("%s %.2f" % [lg.get("name", ""), cr])
	_ok("④ 리그 이름이 석판 위에서 3:1 넘는다", weak.is_empty(), "%s" % [weak])

	# ── ⑤ 붓이 안 샌다 ──────────────────────────────────
	g.menu_mat_on = true
	g.mouse_at = Vector2(-50.0, -50.0)
	var leak := []
	g._open_newrun()
	for tab in [0, 1]:
		g._nr_tab_set(tab)
		await _frame()
		if g.mat_draw:
			leak.append("새 런 %d" % tab)
	g._nr_tab_set(0)
	g.state = g.S.COLLECT
	await _frame()
	if g.mat_draw:
		leak.append("컬렉션")
	g._open_profile()
	await _frame()
	if g.mat_draw:
		leak.append("프로필")
	for from in [-1, g.S.SHOP]:
		for pg in ["pause", "screen", "sound"]:
			if from < 0 and pg == "pause":
				continue
			g.state = g.S.TITLE
			g.pause_from = from
			g._set_go(pg)
			g.set_pg_t = 1.0
			g.set_t = 1.0
			g.state = g.S.SETTINGS
			await _frame()
			if g.mat_draw:
				leak.append("설정 %s %d" % [pg, from])
	#  여는 첫 틀(창이 아직 0) — _draw_settings 가 일찍 돌아가는 길
	g.set_t = 0.0
	await _frame()
	if g.mat_draw:
		leak.append("설정 첫 틀")
	g.state = g.S.TITLE
	g.pause_from = -1
	await _frame()
	_ok("⑤ 그린 뒤 재질 붓이 내려가 있다", leak.is_empty() and not g.mat_draw, "%s" % [leak])
	g.mat_draw = false
	var old := [g._mtx(0.0), g._mtx(1.0), g._mtx_off(0.0), g._mtx(0.5, 0.5)]
	var want := [Color(g.C_DIM, 1.0), Color(g.C_TXT, 1.0), Color(g.C_OFF, 1.0),
			Color(g.C_DIM.lerp(g.C_TXT, 0.5), 0.5)]
	_ok("⑤ 재질 밖에서는 옛 글자색 그대로", old == want, "%s" % [old])

	# ── ⑥ 헤드리스 바닥 ─────────────────────────────────
	g._open_newrun()
	for i in 4:
		g._wall3_tick()
	_ok("⑥ 렌더러 없으면 벽을 안 짓는다", g.wall3_vp == null)
	_ok("⑥ 그때 메뉴 바닥은 옛 스크림이다(벽 아님)", not g._mat_wall())

	# ── ⑦ 개발자 판 ─────────────────────────────────────
	var pg0 := Dev.page
	var hit := -1
	var nrow := 0
	var row := {}
	for pg in Dev.PAGES.size():
		Dev.page = pg
		var rs: Array = Dev._rows(g)
		for r in rs:
			if String((r as Dictionary).get("a", "")) == "menumat":
				hit = pg
				nrow = rs.size()
				row = r
	_ok("⑦ 개발자 판에 「메뉴 재질」 줄이 있다", hit >= 0, "%d쪽" % hit)
	_ok("⑦ 그 쪽이 열아홉 줄 안이다", nrow <= 19 and nrow > 0, "%d줄" % nrow)
	_ok("⑦ 줄 이름이 지금 값을 말한다", String(row.get("n1", "")) == "메뉴 재질 켬",
			String(row.get("n1", "")))
	Dev._run(g, row)
	var off1: bool = not g.menu_mat_on
	Dev._run(g, row)
	_ok("⑦ 누르면 끄고 다시 누르면 켠다", off1 and g.menu_mat_on)
	Dev.page = pg0
