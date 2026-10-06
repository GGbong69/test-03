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
#   ⑧ 나무 패의 결이 글(설정 탭은 그림까지)의 잉크에서 1.5px 넘게 떨어진다 — 잉크는 이 도구가
#      TextServer 의 글리프 그림으로 따로 재고(게임의 _ink_box 를 안 빌린다) 1px 키운다(2배 창은
#      글을 두 배로 구워 잉크가 캔버스 반 칸 더 나온다). 2026-10-06
#   ⑨ 새 런 다트통 액자 — 테 · 그늘이 다트통 이름 잉크와 5px 넘게 떨어진다.
#   ⑩ 일시정지 글줄 · 런 정보도 같은 재질이다 — 분필 글 · 따뜻한 흐림 · 나무 테 칠판 · 나무 패
#      탭. 칠판 테가 화면 안이고 누르는 사각이 석판 위다. 재질을 끄면 옛 그대로다.
#   ⑪ 제목 칠판에서 밀고 들어간다 — 컬렉션 · 프로필 · 설정이 컷이 아니라 PUSH.t 초 동안 칠판이
#      커진다. 누르는 사각은 그동안도 · 뒤에도 그대로이고, 누름 · 키는 밀기를 끝내고 삼킨다.
#      칠판은 제목 칠판에서 출발하고(첫 틀 = 제목 칠판 붓), 제목 칠판 글은 넉 틀 안에 지며 밑의
#      제목 칠판에서는 빠진다. 컬렉션 · 프로필의 화면은 PUSH.ink 뒤에 커지는 칠판 안으로 잘려
#      짙어지고, 밀고 들어간 설정이 떠 있는 동안 제목 칠판 글이 그늘 밑에 안 남는다.
#      모션 끄기 · 재질 끔 · 문이 안 선 제목은 옛 컷이다. 헤드리스라 문 한 장을 빈 그림으로 세운다.
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
			_body(src, "_title_chalk_ink").contains("_chalk_head(")
			and _body(src, "_title_chalk").contains("_title_chalk_ink(")
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
		["꺼진 글 분필 · 석판", _over(Color(ink, off), chalk), chalk, 3.5],
		["새긴 글씨 · 놋쇠 판", g.MENUM.engrave, g.Door3D.COL.brass, 4.5],
		["분필 2층 · 나무 패", _over(Color(ink, dim), g.MENUM.wood), g.MENUM.wood, 4.5],
	]
	var hot_bg: Color = g.MENUM.wood_hot
	rows.append(["얹힌 패 분필 · 얹힌 나무", _over(Color(ink, lerpf(dim, 1.0, 0.8)), hot_bg),
			hot_bg, 4.5])
	#  램프 웅덩이가 가장 밝은 석판(_menu_light — 석판을 촘촘히 짚어 찾는다) 위에서도 2층 ·
	#  꺼진 글이 읽힌다. 그늘은 석판을 어둡게만 하므로 밝은 글의 대비를 올린다.
	var lamp: Color = g.Door3D.COL.lamp
	var pool := 0.0
	var mb: Rect2 = g.MENUM.board
	for yy in 21:
		for xx in 41:
			var lp: Vector2 = g._menu_light_at(mb, mb.position + mb.size * Vector2(
					float(xx) / 40.0, float(yy) / 20.0))
			pool = maxf(pool, lp.x)
	#  웅덩이 가운데도 짚는다 — 가운데가 석판 안이면 거기가 가장 밝다(격자에 안 걸릴 수 있다).
	pool = maxf(pool, g._menu_light_at(mb, mb.position + mb.size * (g.MENUM.lamp_c as Vector2)).x)
	var lit_s := _over(Color(lamp, pool), chalk)
	rows.append(["글 2층 분필 · 가장 밝은 석판(웅덩이 %.3f)" % pool, _over(Color(ink, dim), lit_s),
			lit_s, 4.5])
	rows.append(["꺼진 글 분필 · 가장 밝은 석판", _over(Color(ink, off), lit_s), lit_s, 3.5])
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
	#  런 정보의 뜻 색(레벨 초록 · 점수 파랑 · 배수 붉음 · 맞힘 금)도 석판 위에서 3:1 이다.
	var weak2 := []
	for nc in [["레벨", g.C_GREEN.lightened(0.2)], ["점수", g.C_CHIP], ["배수", g.C_MULT],
			["맞힘", g.C_GOLD]]:
		var c2: Color = g._on_chalk(nc[1] as Color)
		var cr2 := _contrast(c2, chalk)
		if cr2 < 3.0:
			weak2.append("%s %.2f" % [nc[0], cr2])
	_ok("④ 런 정보의 뜻 색이 석판 위에서 3:1 넘는다", weak2.is_empty(), "%s" % [weak2])

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
	await _run2()


#  글 한 줄의 잉크 사각 — TextServer 가 구운 글리프 그림에서 알파가 선 픽셀(> 0.02)만 모은다
#  (그림 가장자리의 1px 여백은 뺀다). x0 은 글의 왼끝, by 는 기준선이다.
func _ink_rect(f: Font, t: String, sz: int, x0: float, by: float) -> Rect2:
	var ts := TextServerManager.get_primary_interface()
	var sh := ts.create_shaped_text()
	ts.shaped_text_add_string(sh, t, f.get_rids(), sz)
	var gl: Array = ts.shaped_text_get_glyphs(sh)
	var pen := 0.0
	var out := Rect2()
	var first := true
	var fs := Vector2i(sz, 0)
	for gd in gl:
		var rid: RID = gd.get("font_rid", RID())
		var idx: int = int(gd.get("index", 0))
		var go: Vector2 = gd.get("offset", Vector2.ZERO)
		if rid.is_valid():
			ts.font_render_glyph(rid, fs, idx)
			var off: Vector2 = ts.font_get_glyph_offset(rid, fs, idx)
			var uv: Rect2 = ts.font_get_glyph_uv_rect(rid, fs, idx)
			var tix: int = ts.font_get_glyph_texture_idx(rid, fs, idx)
			var img: Image = ts.font_get_texture_image(rid, fs, tix) if tix >= 0 else null
			var l := 9999
			var r := -1
			var tp := 9999
			var bt := -1
			if img != null:
				for y in int(uv.size.y):
					for x in int(uv.size.x):
						if img.get_pixel(int(uv.position.x) + x, int(uv.position.y) + y).a > 0.02:
							l = mini(l, x)
							r = maxi(r, x)
							tp = mini(tp, y)
							bt = maxi(bt, y)
			if r >= l:
				var q := Rect2(x0 + pen + go.x + off.x + float(l), by + go.y + off.y + float(tp),
						float(r - l + 1), float(bt - tp + 1))
				out = q if first else out.merge(q)
				first = false
		pen += float(gd.get("advance", 0.0))
	ts.free_rid(sh)
	return out


#  결 토막들이 잉크에서 떨어진 거리 — 잰 잉크를 1px 키운 사각에서 결 토막까지(가로 · 세로 중
#  큰 쪽). 1.5px 밑이면 붙었다. [붙은 수, 결 수, 가장 가까운 거리(결이 없으면 99)]
func _grain_hits(body: Rect2, ink_game: Rect2, ink_meas: Rect2) -> Array:
	var gr: Array = g._plaque_grain(body, ink_game)
	var b := ink_meas.grow(1.0)
	var hit := 0
	var near := 99.0
	for q0 in gr:
		var q: Rect2 = q0
		var dx: float = maxf(maxf(b.position.x - q.end.x, q.position.x - b.end.x), 0.0)
		var dy: float = maxf(maxf(b.position.y - q.end.y, q.position.y - b.end.y), 0.0)
		var clr: float = maxf(dx, dy)
		near = minf(near, clr)
		if clr < 1.5:
			hit += 1
	return [hit, gr.size(), near]


func _run2() -> void:
	# ── ⑧ 결이 글의 잉크 밖이다 ─────────────────────────
	#  탭 몸 = 누르는 사각에서 턱(TABB.lip)을 뺀 것(얹히지 않은 채). 글은 몸 가운데 · _menu_base_y.
	var lip: float = float(g.TABB.lip)
	var cases := []           # [이름, 몸, 글꼴, 글, 크기, ox, 그림 사각]
	g.state = g.S.TITLE
	g.pause_from = -1
	g._set_go("screen")
	g.set_pg_t = 1.0
	g.set_t = 1.0
	g.state = g.S.SETTINGS
	for t in g.SET_TABS.size():
		var tr: Rect2 = g._set_tab_rect(t)
		var nm := String(g._set_info(String(g.SET_TABS[t])).get("n", ""))
		var lw: float = g.font_sm.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		var bh: float = tr.size.y - lip
		#  그림(_set_tab_icon) — 가운데 cx · cy 둘레 12 × 12 안이다.
		var cx: float = roundf(tr.get_center().x - lw * 0.5 - 3.0)
		var cy: float = roundf(tr.position.y + bh * 0.5)
		cases.append(["설정 탭 " + nm, Rect2(tr.position, tr.size - Vector2(0.0, lip)), g.font_sm,
				nm, 20, 9.0, Rect2(cx - 6.0, cy - 6.0, 12.0, 12.0)])
	var rows: Array = g._set_rows()
	for i in rows.size():
		if not g._set_info(String(rows[i])).has("tg"):
			continue
		for k in 2:
			var sr: Rect2 = g._set_seg_rect(i, k)
			cases.append(["켬끔 " + ("켬" if k == 1 else "끔"), Rect2(sr.position,
					sr.size - Vector2(0.0, lip)), g.font_sm, "켬" if k == 1 else "끔", 20, 0.0, Rect2()])
	g.state = g.S.TITLE
	for t in 2:
		var nr: Rect2 = g._nr_tab(t)
		cases.append(["새 런 탭 %d" % t, Rect2(nr.position, nr.size - Vector2(0.0, lip)), g.font,
				"기본" if t == 0 else "챌린지", 12, 0.0, Rect2()])
	for t in g.COL_TABS.size():
		var cr: Rect2 = g._col_tab_rect(t)
		var lb := "%s %d/%d" % [g.COL_TABS[t].n, g._col_rows(t).size(), g._col_rows(t).size()]
		cases.append(["컬렉션 탭 " + lb, Rect2(cr.position, cr.size - Vector2(0.0, lip)), g.font,
				lb, 12, 0.0, Rect2()])
	for t in g.RI_TABS.size():
		var rr: Rect2 = g._ri_tab_rect(t)
		cases.append(["런 정보 탭 " + String(g.RI_TABS[t]), Rect2(rr.position,
				rr.size - Vector2(0.0, lip)), g.font_sm, String(g.RI_TABS[t]), 20, 0.0, Rect2()])
	var bad := []
	var with_grain := 0
	var near_all := 99.0
	for cs in cases:
		var body: Rect2 = cs[1]
		var f: Font = cs[2]
		var lb2 := String(cs[3])
		var sz: int = int(cs[4])
		var ox: float = float(cs[5])
		var tw: float = f.get_string_size(lb2, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x
		var by: float = body.position.y + g._menu_base_y(f, sz, 0.0, body.size.y)
		var meas := _ink_rect(f, lb2, sz, body.position.x + ox + (body.size.x - tw) * 0.5, by)
		var icon: Rect2 = cs[6]
		if icon.size.x > 0.0:
			meas = meas.merge(icon)
		var hv := _grain_hits(body, g._tab_ink(body, f, lb2, sz, ox), meas)
		if int(hv[1]) > 0:
			with_grain += 1
			near_all = minf(near_all, float(hv[2]))
		if int(hv[0]) > 0:
			bad.append("%s 결 %d 중 %d(%.1fpx)" % [cs[0], int(hv[1]), int(hv[0]), float(hv[2])])
	#  지우기 — 몸은 누르는 사각에서 턱(UIHOV.lip_hud)을 뺀 것. 글은 몸 가운데 · 20.
	var dr: Rect2 = g._prof_del_rect()
	var db := Rect2(dr.position, dr.size - Vector2(0.0, float(g.UIHOV.lip_hud)))
	var dw: float = g.font_sm.get_string_size("지우기", HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var dmeas := _ink_rect(g.font_sm, "지우기", 20, db.position.x + (db.size.x - dw) * 0.5,
			g._menu_base_y(g.font_sm, 20, db.position.y, db.size.y))
	var dh := _grain_hits(db, g._prof_del_ink(db), dmeas)
	if int(dh[1]) > 0:
		with_grain += 1
		near_all = minf(near_all, float(dh[2]))
	if int(dh[0]) > 0:
		bad.append("지우기 결 %d 중 %d(%.1fpx)" % [int(dh[1]), int(dh[0]), float(dh[2])])
	_ok("⑧ 나무 패 %d장의 결이 글 잉크(그림 포함 · 1px 키움)에서 1.5px 넘게 떨어진다" % (cases.size() + 1),
			bad.is_empty(), "%s · 결이 선 패 %d장 · 가장 가까운 %.1fpx" % [bad, with_grain, near_all])
	#  잉크 상자(_ink_box)가 잰 잉크를 품는다 — 결을 거르는 자가 잉크보다 작으면 위 줄이 운이다.
	#  게임의 상자는 글리프 그림의 1px 테까지 넣으므로 키우지 않고 품어야 한다.
	var small := []
	for cs in cases:
		var body2: Rect2 = cs[1]
		var f2: Font = cs[2]
		var lb3 := String(cs[3])
		var sz2: int = int(cs[4])
		var tw2: float = f2.get_string_size(lb3, HORIZONTAL_ALIGNMENT_LEFT, -1, sz2).x
		var by2: float = body2.position.y + g._menu_base_y(f2, sz2, 0.0, body2.size.y)
		var m2 := _ink_rect(f2, lb3, sz2, body2.position.x + float(cs[5]) + (body2.size.x - tw2) * 0.5,
				by2)
		var gi: Rect2 = g._tab_ink(body2, f2, lb3, sz2, float(cs[5]))
		if not gi.encloses(m2):
			small.append("%s 상자 %s · 잉크 %s" % [cs[0], gi, m2])
	_ok("⑧ 잉크 상자가 글리프 그림을 품는다", small.is_empty(), "%s" % [small])

	# ── ⑨ 다트통 액자와 이름 ─────────────────────────────
	var src := FileAccess.get_file_as_string("res://scripts/game.gd")
	var stg: Rect2 = g._cup_stage()
	var fo: Rect2 = (g._cup_frame() as Rect2).grow(3.0)       # 테 바깥(_wood_frame 의 o)
	var paint_end: float = fo.end.x + 1.0                       # 오른쪽 그늘 1px
	var names := ["잠김", "???"]
	for pk in GameData.packs():
		names.append(String(pk.get("name", "")))
	var gap_min := INF
	var gap_nm := ""
	for nm in names:
		var ir := _ink_rect(g.font, String(nm), 24, 230.0, 82.0)
		if ir.position.x - paint_end < gap_min:
			gap_min = ir.position.x - paint_end
			gap_nm = String(nm)
	_ok("⑨ 액자가 무대 안쪽이다(바깥 테두리 = 무대)", fo.is_equal_approx(stg), "%s / %s" % [fo, stg])
	_ok("⑨ 액자 · 그늘과 다트통 이름 잉크 사이가 5px 넘는다", gap_min >= 5.0,
			"가장 좁은 「%s」 %.1fpx (그늘 끝 x%.0f)" % [gap_nm, gap_min, paint_end])
	_ok("⑨ 이름 자리 · 액자 붓이 이 셈과 같다",
			_body(src, "_draw_newrun").contains("Vector2(230, 82), nm")
			and _body(src, "_cup_draw").contains("_wood_frame(self, _cup_frame(), 3.0)"))
	await _run3(src)


func _run3(src: String) -> void:
	# ── ⑩ 일시정지 글줄 · 런 정보 ───────────────────────
	var view := Rect2(Vector2.ZERO, g.VIEW)
	var ink: Color = g.DOORT.chalk_ink
	var ds := _body(src, "_draw_settings")
	var pl := _body(src, "_pause_list_draw")
	_ok("⑩ 일시정지 글줄을 재질로 그린다(_draw_settings 가 글줄 앞에서 붓을 세운다)",
			ds.find("mat_draw = menu_mat_on") >= 0
			and ds.find("mat_draw = menu_mat_on") < ds.find("_pause_list_draw("))
	_ok("⑩ 일시정지 글 · 꺾쇠가 메뉴 글자색(_mtx) · 그늘이 따뜻한 검정이다",
			pl.contains("_mtx(ee, ra)") and pl.contains("_mtx(ee * 0.6, ra)")
			and pl.contains("WALL3.scrim_col if mat_draw") and not pl.contains("C_DIM.lerp(C_TXT"))
	#  흐림 판의 잠기는 색 — 일시정지를 열고 한 틀 민 뒤 셰이더 값을 읽는다.
	g._new_run()
	g._tutor_close()
	g.tutor_q.clear()
	g.state = g.S.PICK
	g.menu_mat_on = true
	g._pause_open()
	g._process(1.0 / 60.0)
	var blur = g.get_node_or_null("Blur")
	var tint_on: Color = blur.material.get_shader_parameter("tint") if blur != null else Color()
	await _frame()
	var leak_p: bool = g.mat_draw
	g.menu_mat_on = false
	g._process(1.0 / 60.0)
	var tint_off: Color = blur.material.get_shader_parameter("tint") if blur != null else Color()
	g.menu_mat_on = true
	_ok("⑩ 흐림 판이 따뜻한 검정에 잠긴다 · 재질 끄면 옛 보라",
			tint_on.is_equal_approx(g.WALL3.scrim_col) and tint_off.is_equal_approx(g.MENUM.blur_old),
			"켬 %s · 끔 %s" % [tint_on, tint_off])
	_ok("⑩ 일시정지를 그린 뒤 재질 붓이 내려가 있다", not leak_p)
	g._settings_back()
	for i in 30:
		g._process(1.0 / 60.0)
	#  런 정보 — 나무 테 칠판 · 탭 · 「뒤로」 · 동전 칸이 석판 위 · 테가 화면 안.
	var p: Rect2 = g._ri_panel()
	var out := []
	for t in g.RI_TABS.size():
		if not p.encloses(g._ri_tab_rect(t)):
			out.append("탭 %d" % t)
	if not p.encloses(g._runinfo_back_rect()):
		out.append("뒤로")
	for i in maxi((g.owned as Array).size(), 1):
		if not p.encloses(g._ri_coin_rect(i)):
			out.append("동전 %d" % i)
	_ok("⑩ 런 정보 칠판 테가 화면 안 · 누르는 사각이 석판 위", view.encloses(p.grow(4.0))
			and out.is_empty(), "%s %s" % [p, out])
	var dr := _body(src, "_draw_runinfo")
	_ok("⑩ 런 정보 판이 칠판 붓(_chalk_board · CHALKB.win) · 고른 탭 표지가 놋쇠다",
			dr.contains("_chalk_board(self, p, 4.0, CHALKB.win)")
			and dr.contains("Door3D.COL.brass if mat_draw else C_ACC"))
	g.mat_draw = true
	var hc_on: Color = g._ri_head_col()
	var rc_on: Color = g._ri_row_col()
	g.mat_draw = false
	var hc_off: Color = g._ri_head_col()
	var rc_off: Color = g._ri_row_col()
	_ok("⑩ 런 정보 머리 · 줄이 분필 1층 · 2층이다(끄면 옛 금 · 흰 글)",
			hc_on == Color(ink, 1.0) and rc_on == Color(ink, float(g.MENUM.dim))
			and hc_off == g.C_ACC and rc_off == g.C_TXT,
			"%s %s / %s %s" % [hc_on, rc_on, hc_off, rc_off])
	g.state = g.S.PICK
	g._runinfo_toggle()
	var ri_open: bool = g.state == g.S.RUNINFO
	await _frame()
	var leak_r: bool = g.mat_draw
	g._runinfo_toggle()
	_ok("⑩ 런 정보를 그린 뒤 재질 붓이 내려가 있다", ri_open and not leak_r)

	# ── ⑪ 제목 칠판에서 밀고 들어간다 ───────────────────
	#  헤드리스라 문(3D)을 못 굽는다 — _door_live 가 보는 셋(켬 · 화판 · 구운 그림)만 빈 것으로
	#  세운다. 문 화판은 트리에 안 붙어 굽지 않는다(_door_tick 은 렌더러가 없으면 물러선다).
	g.state = g.S.TITLE
	g.pause_from = -1
	g.motion_off = false
	g.menu_mat_on = true
	g.mouse_at = Vector2(-50.0, -50.0)
	var dvp := SubViewport.new()
	g.door_on = true
	g.door_vp = dvp
	g.door_tex = ImageTexture.create_from_image(Image.create(4, 4, false, Image.FORMAT_RGBA8))
	g.door_t = -1.0
	_ok("⑪ 문이 선다(빈 그림)", g._door_live())
	var trows: Array = g._title_rows()
	var ri_col := -1
	var ri_set := -1
	for i in trows.size():
		if String(trows[i].n) == "컬렉션":
			ri_col = i
		if String(trows[i].n) == "설정":
			ri_set = i
	var cbox: Rect2 = g._title_chalk_box()
	#  컬렉션 — 밀기가 서고 칠판이 제목 칠판 석판에서 출발해 화면 칠판에 선다.
	g._click(g._menu_rect(ri_col).get_center())
	var live0: bool = g._push_live() and g.state == g.S.COLLECT
	var b0: Rect2 = g._push_box(g.MENUM.board)
	var ttl0: float = g._push_ttl_a()
	var ttl_gone := -1          # 커지는 칠판 위 제목 글이 0 이 된 틀
	var under_max := 0.0        # 밀기 동안 밑의 제목 칠판 글 짙기
	var ink_first := -1         # 화면이 짙어지기 시작한 틀
	var ink_k := 0.0            # 그 틀의 밀린 몫
	var ink_before := 0.0       # PUSH.ink 앞에서 화면 짙기의 가장 큰 값
	var clip_on := false        # 화면이 짙어지는 틀에 자르기가 섰다
	var n := 0
	var grows := true
	var prev := b0
	while g._push_live() and n < 200:
		g._process(1.0 / 60.0)
		n += 1
		var b: Rect2 = g._push_box(g.MENUM.board)
		if not b.encloses(prev):
			grows = false
		prev = b
		if ttl_gone < 0 and g._push_ttl_a() <= 0.0:
			ttl_gone = n
		if g._push_live():
			under_max = maxf(under_max, g._ttl_ink_a())
		var ia: float = g._push_ink_a()
		if g._push_k() <= float(g.PUSH.ink):
			ink_before = maxf(ink_before, ia)
		if ink_first < 0 and ia > 0.0:
			ink_first = n
			ink_k = g._push_k()
			await _frame()             # 화면이 짙어지는 틀을 그린다 — 자르기가 선다
			clip_on = g.push_clip and g._push_live()
		if n == 6:
			await _frame()             # 밀리는 틀을 한 번 그린다(_push_draw)
	var want_n: int = int(ceil(float(g.PUSH.t) * 60.0 - 0.001))
	_ok("⑪ 컬렉션 — 제목 칠판 석판에서 출발한다", live0 and b0 == cbox, "%s / %s" % [b0, cbox])
	_ok("⑪ PUSH.t 동안 커지기만 하고 화면 칠판에 선다", absi(n - want_n) <= 1 and grows
			and prev == g.MENUM.board and g.state == g.S.COLLECT and not g.mat_draw,
			"%d프레임(바라는 값 %d) · 끝 %s" % [n, want_n, prev])
	_ok("⑪ 커지는 칠판 · 창이 제목 칠판 붓에서 출발한다(_chalk_board 의 from = 제목)",
			_body(src, "_push_draw").contains("CHALKB.menu, 1.0, Rect2(), CHALKB.title, k)")
			and _body(src, "_set_win_draw").contains("CHALKB.title, _push_k())"))
	_ok("⑪ 제목 칠판 글이 커지는 칠판 위에서 넉 틀 안에 지고 밑에서는 빠진다",
			ttl0 >= 1.0 and ttl_gone >= 3 and ttl_gone <= 4 and under_max <= 0.0,
			"첫 틀 %.2f · 0 이 된 틀 %d · 밑 %.2f" % [ttl0, ttl_gone, under_max])
	await _frame()
	_ok("⑪ 컬렉션 화면이 PUSH.ink 뒤에 짙어지고 그동안 칠판 안으로 잘린다 · 끝나면 자르기를 걷는다",
			ink_before <= 0.0 and ink_first > 0 and ink_k > float(g.PUSH.ink) and clip_on
			and not g.push_clip,
			"짙어진 틀 %d(밀린 몫 %.3f) · 자르기 %s → %s" % [ink_first, ink_k, clip_on, g.push_clip])
	#  밀리는 동안의 누름 · 키 — 밀기를 끝내고 삼킨다(「뒤로」 · ESC 가 제목으로 안 간다).
	g.state = g.S.TITLE
	g._click(g._menu_rect(ri_col).get_center())
	g._process(1.0 / 60.0)
	g._click(g._menu_back_rect().get_center())
	var eat_click: bool = g.state == g.S.COLLECT and not g._push_live()
	g.state = g.S.TITLE
	g._click(g._menu_rect(ri_col).get_center())
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	g._unhandled_input(ev)
	var eat_key: bool = g.state == g.S.COLLECT and not g._push_live()
	_ok("⑪ 밀리는 동안 누름 · 키는 밀기를 끝내고 삼킨다", eat_click and eat_key)
	#  프로필 — 프로필 줄(제목 칠판 맨 밑)도 같은 밀기다.
	g.state = g.S.TITLE
	g._click(g._prof_badge_rect().get_center())
	var prof_ok: bool = g._push_live() and g.state == g.S.PROFILE
	g._push_skip()
	_ok("⑪ 프로필 줄도 밀고 들어간다", prof_ok and not g._push_live())
	#  설정 — 창이 제목 칠판에서 제 자리로 커진다. 누르는 사각(줄 · 탭)은 첫 틀부터 다 선
	#  자리 그대로다(떠오름을 안 탄다).
	g.state = g.S.TITLE
	g.set_t = 0.0
	g._click(g._menu_rect(ri_set).get_center())
	var set_live: bool = g._push_live() and g.state == g.S.SETTINGS
	var w0: Rect2 = g._set_win()
	var rects := []
	var moved := 0
	var fr_n := 0
	while fr_n < 200:
		var now := []
		for i in (g._set_rows() as Array).size():
			now.append(g._set_rect(i))
		for t in g.SET_TABS.size():
			now.append(g._set_tab_rect(t))
		if not rects.is_empty() and now != rects:
			moved += 1
		rects = now
		if not g._push_live():
			break
		g._process(1.0 / 60.0)
		fr_n += 1
	var fin := []
	for i in 40:
		g._process(1.0 / 60.0)
	for i in (g._set_rows() as Array).size():
		fin.append(g._set_rect(i))
	for t in g.SET_TABS.size():
		fin.append(g._set_tab_rect(t))
	_ok("⑪ 설정 — 창이 제목 칠판 석판에서 출발해 창 자리에 선다",
			set_live and w0 == cbox and (g._set_win() as Rect2) == g._set_to(g._set_pg()),
			"%s → %s" % [w0, g._set_win()])
	_ok("⑪ 설정 — 누르는 사각이 밀기 동안 · 뒤에 한 px 도 안 움직인다",
			moved == 0 and fin == rects, "%d프레임 · 움직인 틀 %d" % [fr_n, moved])
	#  밀고 들어간 설정이 떠 있는 동안 제목 칠판 글은 그늘 밑에 안 남고, 닫히면 돌아온다.
	var open_a: float = g._ttl_ink_a()
	g._settings_back()
	var mid_a := -1.0
	for i in 30:
		g._process(1.0 / 60.0)
		if i == 3:
			mid_a = g._ttl_ink_a()
	_ok("⑪ 설정 — 밀고 들어간 창이 떠 있는 동안 제목 칠판 글이 그늘 밑에 없고, 닫히면 돌아온다",
			open_a <= 0.0 and mid_a > 0.0 and mid_a < 1.0 and g._ttl_ink_a() >= 1.0
			and not g.push_ttl,
			"뜬 동안 %.2f · 닫히는 넷째 틀 %.2f · 닫힌 뒤 %.2f" % [open_a, mid_a, g._ttl_ink_a()])
	#  옛 컷 — 모션 끄기 · 재질 끔 · 문이 안 선 제목.
	var cut := []
	for k in 3:
		g.state = g.S.TITLE
		g.motion_off = k == 0
		g.menu_mat_on = k != 1
		if k == 2:
			g.door_tex = null
		if k == 2:
			g._click(g._prof_badge_rect().get_center())
		else:
			g._click(g._menu_rect(ri_col).get_center())
		cut.append(g._push_live())
	g.motion_off = false
	g.menu_mat_on = true
	_ok("⑪ 모션 끄기 · 재질 끔 · 문이 안 선 제목은 옛 컷이다", cut == [false, false, false],
			"%s" % [cut])
	g.door_vp = null
	g.door_tex = null
	dvp.free()
	g.state = g.S.TITLE
