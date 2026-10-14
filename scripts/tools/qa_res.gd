extends SceneTree
# 해상도(2026-10-11 · game.gd RES) — 못 박는 것:
#   ① 설정 「화면」 탭 — 「전체화면」 바로 밑이 「해상도」 줄(제목 · 판 중 둘 다)
#   ② 모니터를 모르면(헤드리스) 크기 여섯 다 · 값 글은 「가로 × 세로」
#   ③ ▶ 는 한 칸 크게 · 끝에서 감는다 · ◀ 는 한 칸 작게 · 고른 가로가 저장된다
#   ④ ◀ · ▶ 단추가 줄 안 · 조작 칸(이름 칸 뒤) · 서로 안 겹친다 · 누르면 그 쪽으로 민다
#   ⑤ 일곱 줄이 「뒤로」에 안 닿고 줄 높이 26 이다(2026-10-14 「화면 고르기」 줄을 걷어 여덟 → 일곱)
#   ⑥ 넓은 화면 — 펠트 · 창구가 넓어지고 저울 · 등록기가 바깥으로(화면 안) · TBL_WIDE 까지
#   godot --headless --path . --script scripts/tools/qa_res.gd
const Save = preload("res://scripts/save.gd")
const Room3D = preload("res://scripts/room3d.gd")
var g = null
var ok := 0
var bad := 0
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_qa_res_g.cfg"
	Save.path = "user://_qa_res.cfg"
	Save.prof_fmt = "user://_qa_res_%d.cfg"
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
	# ①
	g.pause_from = -1
	g._set_go("screen")
	g.state = g.S.SETTINGS
	g.set_t = 1.0
	g.set_pg_t = 1.0
	var rows: Array = g._set_rows()
	_ok("① 제목 — 전체화면 바로 밑이 해상도", rows.find("res") == rows.find("fs") + 1, "%s" % [rows])
	g.pause_from = g.S.PICK
	var rp: Array = g._set_rows()
	_ok("① 판 중 — 전체화면 바로 밑이 해상도", rp.find("res") == rp.find("fs") + 1, "%s" % [rp])
	g.pause_from = -1

	# ②
	var ls: Array = g._res_list()
	_ok("② 헤드리스면 크기 여섯 다", ls.size() == 6, "%d" % ls.size())
	g.res_w = 1280
	_ok("② 값 글 — 1280 × 720", g._res_label() == "1280 × 720", g._res_label())

	# ③
	g._res_step(1)
	_ok("③ ▶ 한 칸 — 1600", g.res_w == 1600 and int(Save.get_set("res", 0)) == 1600, "%d" % g.res_w)
	g.res_w = 3840
	g._res_step(1)
	_ok("③ 끝에서 감는다 — 3840 → 1280", g.res_w == 1280, "%d" % g.res_w)
	g._res_step(-1)
	_ok("③ ◀ 한 칸 — 1280 → 3840", g.res_w == 3840, "%d" % g.res_w)
	_ok("③ 고른 가로가 저장된다", int(Save.get_set("res", 0)) == 3840)

	# ④
	var ri := rows.find("res")
	var r: Rect2 = g._set_rect(ri)
	var la: Rect2 = g._res_arrow_rect(ri, false)
	var ra: Rect2 = g._res_arrow_rect(ri, true)
	_ok("④ 단추 둘이 줄 안", r.encloses(la) and r.encloses(ra), "%s %s %s" % [r, la, ra])
	_ok("④ 단추는 이름 칸 뒤", la.position.x >= r.position.x + float(g.SETW.name_w) - 0.5)
	_ok("④ 두 단추가 안 겹치고 값 글 자리가 남는다", ra.position.x - la.end.x >= 90.0,
			"%.0f" % (ra.position.x - la.end.x))
	g.res_w = 1920
	g._click(la.get_center())
	_ok("④ ◀ 를 누르면 작게", g.res_w == 1600, "%d" % g.res_w)
	g._click(ra.get_center())
	_ok("④ ▶ 를 누르면 크게", g.res_w == 1920, "%d" % g.res_w)
	g._click(r.position + Vector2(20.0, r.size.y * 0.5))
	_ok("④ 이름 쪽을 누르면 다음 크기", g.res_w == 2560, "%d" % g.res_w)

	# ⑤
	var last: Rect2 = g._set_rect(rows.size() - 2)
	var back: Rect2 = g._set_rect(rows.size() - 1)
	_ok("⑤ 일곱 줄이 「뒤로」에 안 닿는다", rows.size() == 8 and last.end.y < back.position.y,
			"%d줄 · %.0f < %.0f" % [rows.size() - 1, last.end.y, back.position.y])
	_ok("⑤ 줄 높이 26", is_equal_approx(r.size.y, 26.0), "%.0f" % r.size.y)

	# ⑥ 넓은 화면의 테이블(2026-10-14) — 펠트 · 창구가 양옆으로 넓어지고 저울 · 등록기가 그만큼 바깥으로
	var s0: Rect2 = g._prop_rect_raw(0)
	var b0: Rect2 = g._prop_rect_raw(1)
	var e0: float = g._chute_edge(float(g.TBL.ny))
	g.view_pad = Vector2(100.0, 0.0)
	Room3D.wide = g._tbl_wide()
	_ok("⑥ 넓은 화면 — 펠트 앞 모서리가 100 바깥", is_equal_approx(g._chute_edge(float(g.TBL.ny)), e0 - 100.0),
			"%.1f → %.1f" % [e0, g._chute_edge(float(g.TBL.ny))])
	#  소실점이 멀어진 만큼 깊이 축의 기욺(lean)이 조금 달라 1px 안쪽으로 어긋난다
	_ok("⑥ 저울 · 등록기가 100 씩 바깥으로", absf(g._prop_rect_raw(0).position.x - (s0.position.x - 100.0)) < 2.0
			and absf(g._prop_rect_raw(1).position.x - (b0.position.x + 100.0)) < 2.0,
			"%.1f · %.1f" % [g._prop_rect_raw(0).position.x, g._prop_rect_raw(1).position.x])
	_ok("⑥ 저울 · 등록기가 보이는 화면 안", g._full().encloses(g._prop_rect_raw(0))
			and g._full().encloses(g._prop_rect_raw(1)))
	g.view_pad = Vector2(400.0, 0.0)
	_ok("⑥ 아주 넓어도 TBL_WIDE 까지만(상인 팔이 닿는 자리)", is_equal_approx(g._tbl_wide(), float(g.TBL_WIDE)))
	g.view_pad = Vector2.ZERO
	Room3D.wide = 0.0
