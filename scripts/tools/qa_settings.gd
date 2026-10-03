extends SceneTree

# 설정 화면 검사. 2026-09-13 사용자 제보 — "게임 나가기가 잘렸네"
#   행이 화면 안에 다 든다 · 행끼리 안 겹친다 · 누르는 자리와 그리는 자리가 같다 —
#   **쪽마다** 잰다.
#
# 2026-10-03 — 평평한 일곱 줄을 갈래로 접었다(「esc를 누르면 일시정지가 되어야지
#   일시정지에 설정을 누르면 설정창이 되어야지 ㅇㅋ?」). 같은 날 「설정 UI 좀 더 개선
#   해봐 레퍼런스 찾아보면서 작업해줘」로 설정이 **가운데 뜨는 창**이 됐다 — 발라트로 ·
#   런 정보의 문법(맨 위 탭 · 줄 안에서 미는 조작 · 맨 밑 「뒤로」). 일시정지는 「이전의
#   방식이 좀 더 괜찮았는데?」로 옛 글줄 + 오른쪽 판에 돌아왔고, 그 판이 설정 창으로 자란다.
#     일시정지     계속하기 · 설정 ‖ 로비로 나가기 · 게임 나가기     (판 중에만)
#     설정 창      [화면] [소리] 탭 · 그 탭의 줄 · 뒤로               (제목은 곧장 여기)
#                  화면  전체화면 [끔|켬] · CRT 필터 · 화면 굴곡
#                  소리  효과음 · 음악
#   예전 일곱 줄의 일이 **하나도 안 빠지고** 어딘가에 산다는 것, 키(ESC)와 화면 누름
#   둘 다로 한 단씩 오르내린다는 것, 조작이 **그 줄 안에서** 된다는 것을 잰다.
#
#   godot --path . --quit-after 900 --script scripts/tools/qa_settings.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	#  사람의 저장을 안 건드린다 — 게이지를 끌면 Save.set_set 이 곧바로 쓴다.
	Save.gpath = "user://_qa_settings_g.cfg"
	Save.path = "user://_qa_settings.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-34s %s" % ["통과" if c else "실패", n, d])


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


func _shoot(nm: String) -> void:
	#  헤드리스에는 그린 화면이 없다(get_image 가 빈손) — 창으로 돌릴 때만 찍는다.
	if DisplayServer.get_name() == "headless":
		return
	for i in 4:
		g._process(1.0 / 60.0)
	g.queue_redraw()
	var fr = g.get_node_or_null("Front")
	if fr != null:
		fr.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)


#  쪽을 세운다 — 다 떠오른 자리에서 잰다.
func _page(pg: String, from := -1) -> void:
	g.state = g.S.SETTINGS
	g.pause_from = from
	g._set_go(pg)
	g.set_t = 1.0
	g.set_pg_t = 1.0


func _w20(s: String) -> float:
	return g.font_sm.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x


func _check(tag: String) -> void:
	g.set_t = 1.0              # 다 떠오른 상태로 잰다
	g.set_pg_t = 1.0
	var rows: Array = g._set_rows()
	var v: Vector2 = g.VIEW
	var w: Rect2 = g._set_win()
	var lip: float = float(g.PANEL_LIP)
	var inner := Rect2(w.position, w.size - Vector2(0.0, lip))
	#  설정 창은 윗변에 이름표가 반쯤 걸친다 — 그것까지 화면 안이어야 한다.
	var wl := w
	if g._set_pg() != "pause":
		wl = wl.grow_side(SIDE_TOP, float(g.SETW.plate_h) * 0.5)
	_ok("%s — 판이 화면 안에 든다" % tag, Rect2(Vector2(6.0, 6.0), v - Vector2(12.0, 12.0))
			.encloses(wl), "%s" % [wl])
	if g._set_pg() == "pause":
		_pause_check(tag, rows)
		return
	var bad := PackedStringArray()
	var prev := Rect2()
	for i in rows.size():
		var r: Rect2 = g._set_rect(i)
		if not inner.encloses(r):
			bad.append("%d 창 밖" % i)
		if i > 0 and r.position.y < prev.end.y:
			bad.append("%d↔%d" % [i - 1, i])
		prev = r
		# 누르는 자리와 그리는 자리가 같은가 — 한가운데를 찍어 본다
		var mid := r.position + r.size * 0.5
		if g._set_hit(mid) != i:
			bad.append("%d 못 누름" % i)
		var inf: Dictionary = g._set_info(String(rows[i]))
		var nm := String(inf.get("n", ""))
		#  이름이 이름 칸(150)에 든다 — 왼쪽 10 · 홈 앞 8.
		if g._set_pg() != "pause" and String(rows[i]) != "back" \
				and 10.0 + _w20(nm) > float(g.SETW.name_w) - 8.0:
			bad.append("%s 이름이 넘친다" % nm)
		if bool(inf.get("g", false)):
			var tr: Rect2 = g._vol_track(i)
			var num_l: float = r.end.x - 10.0 - _w20("100")
			if not r.encloses(Rect2(tr.position.x - 2.0, tr.position.y - 5.0,
					tr.size.x + 4.0, 16.0)):
				bad.append("%s 손잡이가 줄 밖" % nm)
			#  100 에서도 손잡이(오른끝 +3)가 수를 안 덮는다.
			if tr.end.x + 3.0 > num_l - 2.0:
				bad.append("%s 손잡이 %.0f · 수 %.0f" % [nm, tr.end.x + 3.0, num_l])
			if not (g._set_grab(i) as Rect2).has_point(tr.get_center()):
				bad.append("%s 홈을 못 쥔다" % nm)
		if inf.has("tg"):
			var s0: Rect2 = g._set_seg_rect(i, 0)
			var s1: Rect2 = g._set_seg_rect(i, 1)
			if not r.encloses(s0) or not r.encloses(s1) or s0.intersects(s1):
				bad.append("%s 켬끔 칸" % nm)
			if s0.position.x < r.position.x + 10.0 + _w20(nm) + 8.0:
				bad.append("%s 켬끔 칸이 이름에 닿는다" % nm)
	_ok("%s — 줄이 창 안 · 안 겹침 · 누르는 자리 = 그리는 자리" % tag, bad.is_empty(),
			"%d줄 · %s" % [rows.size(), "없다" if bad.is_empty() else ", ".join(bad)])
	#  탭 — 창 안 · 서로 안 겹침 · 이름표 밑 · 첫 줄 위. 「뒤로」는 맨 밑.
	var t0: Rect2 = g._set_tab_rect(0)
	var t1: Rect2 = g._set_tab_rect(1)
	var r0: Rect2 = g._set_rect(0)
	var head_end: float = w.position.y + float(g.SETW.plate_h) * 0.5
	_ok("%s — 탭이 창 안 · 이름표와 첫 줄 사이" % tag, inner.encloses(t0) and inner.encloses(t1)
			and not t0.intersects(t1) and t0.position.y >= head_end + 6.0
			and t0.end.y <= r0.position.y,
			"탭 %.0f~%.0f · 이름표 끝 %.0f · 첫 줄 %.0f" % [t0.position.y, t0.end.y, head_end,
				r0.position.y])
	_ok("%s — 탭 양 끝이 줄 양 끝과 같은 세로선" % tag,
			is_equal_approx(t0.position.x, r0.position.x) and is_equal_approx(t1.end.x, r0.end.x),
			"%.0f/%.0f · %.0f/%.0f" % [t0.position.x, r0.position.x, t1.end.x, r0.end.x])
	var bi: int = rows.find("back")
	var br: Rect2 = g._set_rect(bi)
	_ok("%s — 「뒤로」가 맨 밑 · 턱 위" % tag, bi == rows.size() - 1
			and br.end.y <= inner.end.y - 4.0
			and br.position.y >= (g._set_rect(maxi(bi - 1, 0)) as Rect2).end.y + 6.0,
			"%s" % [br])


#  일시정지 — 옛 자로 잰다: 글줄이 머리(78) 밑 · 화면 안 · 안 겹침 · 오른쪽 판과 안 닿음.
func _pause_check(tag: String, rows: Array) -> void:
	var v: Vector2 = g.VIEW
	var top := 9999.0
	var bot := -1.0
	var bad := PackedStringArray()
	var prev := Rect2()
	for i in rows.size():
		var r: Rect2 = g._set_rect(i)
		top = minf(top, r.position.y)
		bot = maxf(bot, r.end.y)
		if i > 0 and r.position.y < prev.end.y:
			bad.append("%d↔%d" % [i - 1, i])
		prev = r
		if g._set_hit(r.get_center()) != i:
			bad.append("%d 못 누름" % i)
		if r.end.x > (g.SETP as Rect2).position.x:
			bad.append("%d 판에 닿음" % i)
	_ok("%s — 글줄이 화면 안 · 안 겹침 · 판과 안 닿음" % tag, bad.is_empty()
			and top >= 96.0 and bot <= v.y - 6.0,
			"%.0f ~ %.0f · %s" % [top, bot, "없다" if bad.is_empty() else ", ".join(bad)])
	_ok("%s — 판은 오른쪽 판(SETP)" % tag, (g._set_win() as Rect2).is_equal_approx(g.SETP))
	_ok("%s — 탭이 없다" % tag, g._set_tab_hit((g.SETP as Rect2).get_center()) == -1)
	#  판의 설명 줄이 판 안 폭에 든다 · 「설정」은 안에 든 갈래를 편다.
	var long := []
	for k in rows:
		var d := String(g._set_info(String(k)).get("d", ""))
		if g.font.get_string_size(d, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x \
				> (g.SETP as Rect2).size.x - 40.0:
			long.append(d)
	_ok("%s — 설명이 한 줄로 판에 든다" % tag, long.is_empty(), "%s" % [long])


#  줄을 화면 그대로 누른다(_click) — 키 길과 같은 문을 지나는지 잰다.
func _tap(key: String) -> bool:
	g.set_t = 1.0
	g.set_pg_t = 1.0
	var i: int = (g._set_rows() as Array).find(key)
	if i < 0:
		return false
	g._click((g._set_rect(i) as Rect2).get_center())
	g.set_pg_t = 1.0
	return true


func _tab(key: String) -> void:
	g.set_t = 1.0
	g.set_pg_t = 1.0
	g._click((g._set_tab_rect((g.SET_TABS as Array).find(key)) as Rect2).get_center())
	g.set_pg_t = 1.0


func _esc() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.pressed = true
	g._unhandled_input(e)
	g.set_pg_t = 1.0


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	print("\n설정 화면 검사\n")

	# ① 쪽 — 같은 자로 잰다
	_page("pause", g.S.SHOP)
	_check("일시정지")
	print("")
	_page("screen", g.S.SHOP)
	_check("화면 탭(판 중)")
	print("")
	_page("screen", -1)
	_check("화면 탭(제목)")
	print("")
	_page("sound", g.S.SHOP)
	_check("소리 탭")
	#  설정 창의 높이는 탭을 갈아도 그대로다 — 탭 줄과 「뒤로」가 손 밑에서 안 뛴다.
	_page("screen", g.S.SHOP)
	var ws: Rect2 = g._set_win()
	var bs: Rect2 = g._set_rect((g._set_rows() as Array).find("back"))
	_page("sound", g.S.SHOP)
	_ok("탭을 갈아도 창 · 「뒤로」가 제자리", (g._set_win() as Rect2).is_equal_approx(ws)
			and (g._set_rect((g._set_rows() as Array).find("back")) as Rect2).is_equal_approx(bs),
			"%s · %s" % [ws, bs])

	# ② 줄의 차림 — 옛 일곱 줄의 일이 하나도 안 빠졌다
	print("")
	_page("pause", g.S.AIM_V)
	var rp: Array = g._set_rows()
	_ok("일시정지 — 계속하기 · 설정 · 로비 · 게임 나가기", rp == ["back", "set", "lobby", "quit"],
			"%s" % [rp])
	_ok("일시정지 맨 위는 「계속하기」", String(g._set_info("back").get("n", "")) == "계속하기")
	_page("top", -1)
	var rt: Array = g._set_rows()
	_ok("설정 창은 첫 탭(화면)으로 연다", g._set_pg() == "screen"
			and rt == ["fs", "crt", "warp", "back"], "%s · %s" % [g._set_pg(), rt])
	_ok("제목에서 연 설정에는 「로비로 나가기」가 없다", not rt.has("lobby"))
	_page("pause", -1)
	_ok("판이 없으면 일시정지 쪽도 설정 창으로 읽는다", g._set_pg() == "screen")
	_page("sound", g.S.SHOP)
	_ok("소리 탭 — 효과음 · 음악 · 뒤로", (g._set_rows() as Array) == ["vol", "mus", "back"],
			"%s" % [g._set_rows()])
	_ok("탭은 「화면」 · 「소리」 둘", (g.SET_TABS as Array) == ["screen", "sound"]
			and String(g._set_info("screen").get("n", "")) == "화면"
			and String(g._set_info("sound").get("n", "")) == "소리")
	var all_keys := {}
	for pg in ["pause", "screen", "sound"]:
		_page(pg, g.S.SHOP)
		for k in g._set_rows():
			all_keys[String(k)] = true
	var olds := ["back", "fs", "vol", "mus", "crt", "lobby", "quit"]
	var lost := []
	for k in olds:
		if not all_keys.has(k):
			lost.append(k)
	_ok("옛 일곱 줄의 일이 다 어딘가에 산다", lost.is_empty(), "빠짐 %s" % [lost])
	#  글줄에 키 이름이 없다(「뒤로 ESC」 같은 글 금지 — 사용자 규칙).
	#  설명 줄도 없다 — 「효과만, 해설 금지」. 값을 밀면 화면이 곧 그렇게 된다.
	var keyname := []
	var desc := []
	for k in all_keys.keys() + ["set", "screen", "sound", "warp"]:
		for pg in ["pause", "screen"]:
			_page(pg, g.S.SHOP)
			var inf: Dictionary = g._set_info(String(k))
			var txt := String(inf.get("n", "")) + " " + String(inf.get("v", ""))
			for kn in ["ESC", "Esc", "TAB", "스페이스", "엔터", "Space"]:
				if txt.contains(kn):
					keyname.append(txt)
			if inf.has("d"):
				desc.append(String(k))
	_ok("글줄에 키 이름이 없다", keyname.is_empty(), "%s" % [keyname])
	#  설명은 일시정지 줄만 — 설정 창 줄에는 없다(효과만).
	var desc_set := []
	for k in desc:
		if not (k in ["back", "lobby", "quit"]):
			desc_set.append(k)
	_page("screen", g.S.SHOP)
	if g._set_info("back").has("d"):
		desc_set.append("back(설정 창)")
	_ok("설정 창 줄에는 설명이 없다", desc_set.is_empty(), "%s" % [desc_set])
	_page("pause", g.S.SHOP)
	_ok("일시정지 줄은 오른쪽 판이 펼 설명을 갖는다", g._set_info("back").has("d")
			and g._set_info("lobby").has("d") and g._set_info("quit").has("d")
			and (g._set_info("set").get("kids", []) as Array) == ["screen", "sound"])

	# ③ 오르내림 — 줄 · 탭을 눌러 가고, 「뒤로」 · ESC 로 한 단씩 오른다
	print("")
	g._new_run()
	g.swap_live = false
	g.turn_live = false
	g.sweep_live = false
	g.boost_t = -1.0
	g._tutor_close()
	g.tutor_q.clear()
	g.state = g.S.SHOP
	g._pause_open()
	_ok("상점의 일시정지 → 일시정지 창", g.state == g.S.SETTINGS and g._set_pg() == "pause"
			and g.pause_from == g.S.SHOP, "쪽 %s" % g._set_pg())
	_tap("set")
	_ok("「설정」을 누르면 설정 창 · 화면 탭 · 첫 줄", g._set_pg() == "screen"
			and g.state == g.S.SETTINGS and g.set_sel == 0, "%s · %d" % [g._set_pg(), g.set_sel])
	_ok("판은 그대로 멈춰 있다(돌아갈 자리를 안다)", g.pause_from == g.S.SHOP)
	_tab("sound")
	_ok("「소리」 탭을 누르면 소리 줄", g._set_pg() == "sound"
			and (g._set_rows() as Array).has("vol"), g._set_pg())
	_tab("sound")
	_ok("고른 탭을 또 누르면 그대로", g._set_pg() == "sound")
	_tab("screen")
	_ok("「화면」 탭으로 되돌아온다", g._set_pg() == "screen")
	_tap("back")
	_ok("설정의 「뒤로」 → 일시정지 · 「설정」 줄에 손이 선다", g._set_pg() == "pause"
			and String(g._set_rows()[g.set_sel]) == "set")
	_tap("set")
	_tab("sound")
	_esc()
	_ok("소리 탭에서 ESC → 일시정지(탭은 단이 아니다)", g._set_pg() == "pause"
			and g.state == g.S.SETTINGS and String(g._set_rows()[g.set_sel]) == "set")
	_esc()
	_ok("일시정지에서 ESC → 판으로", g.state == g.S.SHOP and g.pause_from == -1,
			"state %d" % g.state)
	g._pause_open()
	_tap("back")
	_ok("「계속하기」 → 판으로", g.state == g.S.SHOP)
	#  제목 — 일시정지를 안 지난다
	g.state = g.S.TITLE
	g.pause_from = -1
	var trows: Array = g._title_rows()
	for i in trows.size():
		if String(trows[i].n) == "설정":
			g._click((g._menu_rect(i) as Rect2).get_center())
	_ok("제목의 「설정」 → 곧장 설정 창", g.state == g.S.SETTINGS and g._set_pg() == "screen"
			and g.pause_from == -1, "state %d · 쪽 %s" % [g.state, g._set_pg()])
	_tab("sound")
	_esc()
	_ok("제목에서 연 설정은 ESC 한 번에 제목", g.state == g.S.TITLE, "state %d" % g.state)

	# ④ 조작은 줄 안에서 — 끌기 · 이름 · 휠 · 켬끔
	print("")
	_page("sound", g.S.SHOP)
	var vi: int = (g._set_rows() as Array).find("vol")
	var vr: Rect2 = g._set_rect(vi)
	g.vol = 0.5
	g.set_sel = 0
	g._click(vr.position + Vector2(30.0, vr.size.y * 0.5))
	_ok("이름 쪽을 누르면 고르기만 한다", g.set_drag == -1 and is_equal_approx(g.vol, 0.5)
			and g.set_sel == vi, "drag %d · %.2f" % [g.set_drag, g.vol])
	var tr: Rect2 = g._vol_track(vi)
	g._click(Vector2(tr.position.x + tr.size.x * 0.25, vr.get_center().y + 9.0))
	_ok("홈 둘레(줄 높이 안)를 누르면 그 자리 · 끈다", g.set_drag == vi
			and is_equal_approx(g.vol, 0.25), "drag %d · %.2f" % [g.set_drag, g.vol])
	g._set_slide(g.set_drag, Vector2(tr.position.x + tr.size.x * 0.8, 0.0))
	_ok("끌면 따라온다(줄 밖 높이여도)", is_equal_approx(g.vol, 0.8), "%.2f" % g.vol)
	g._set_slide(g.set_drag, Vector2(tr.position.x - 40.0, 0.0))
	_ok("홈 왼쪽 밖으로 끌면 0", is_equal_approx(g.vol, 0.0), "%.2f" % g.vol)
	g._set_slide(g.set_drag, Vector2(tr.position.x + tr.size.x * 0.6, 0.0))
	g._set_slide_end()
	_ok("떼면 놓고 저장한다", g.set_drag == -1
			and is_equal_approx(float(Save.get_set("vol", -1.0)), 0.6),
			"디스크 %s" % [Save.get_set("vol", -1.0)])
	var mi: int = (g._set_rows() as Array).find("mus")
	var mus0: float = g.vol_mus
	g.wheel_ms = 0
	g._wheel((g._set_rect(mi) as Rect2).position + Vector2(30.0, 15.0), -1)
	_ok("휠 — 게이지 줄 어디서 굴려도 그 값 +5", is_equal_approx(g.vol_mus,
			minf(mus0 + 0.05, 1.0)) and g.set_sel == mi, "%.2f → %.2f" % [mus0, g.vol_mus])
	g._vol_save_due()
	g.wheel_ms = 0
	g._wheel((g._set_tab_rect(1) as Rect2).get_center(), -1)
	_ok("휠 — 탭 줄 위는 탭을 간다", g._set_pg() == "screen", g._set_pg())
	g.wheel_ms = 0
	g._wheel((g._set_rect((g._set_rows() as Array).find("back")) as Rect2).get_center(), 1)
	_ok("휠 — 「뒤로」 위는 아무 일 없다", g._set_pg() == "screen" and g.state == g.S.SETTINGS)
	#  켬끔 — 이미 그 값인 칸은 안 뒤집는다(저장 무변경). 다른 칸은 뒤집는다.
	_page("screen", g.S.SHOP)
	var fi: int = (g._set_rows() as Array).find("fs")
	var on0: bool = bool(g._set_info("fs").get("tg", false))
	Save.set_set("fullscreen", on0)
	g._click((g._set_seg_rect(fi, 1 if on0 else 0) as Rect2).get_center())
	_ok("켬끔 — 지금 값 칸을 누르면 그대로", bool(Save.get_set("fullscreen", on0)) == on0)
	g._click((g._set_seg_rect(fi, 0 if on0 else 1) as Rect2).get_center())
	_ok("켬끔 — 다른 칸을 누르면 뒤집는다", bool(Save.get_set("fullscreen", on0)) != on0,
			"저장 %s" % [Save.get_set("fullscreen", on0)])
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	Save.set_set("fullscreen", false)

	# ⑤ 밀려 듦 · 떠오름 · 자람 — 그리는 자리와 누르는 자리가 같이 간다
	print("")
	_page("pause", 1)
	g.set_t = 0.0
	var out0: Rect2 = g._set_rect(0)
	g.set_t = 0.5
	var half: Rect2 = g._set_rect(0)
	g.set_t = 1.0
	var done: Rect2 = g._set_rect(0)
	_ok("일시정지 글줄은 왼쪽에서 밀려 든다", out0.position.x < half.position.x
			and half.position.x < done.position.x,
			"0%% %.0f → 50%% %.0f → 100%% %.0f"
			% [out0.position.x, half.position.x, done.position.x])
	_ok("다 들어오면 제자리", is_equal_approx(done.position.x, float(g.SET.x)),
			"%.0f (표 %.0f)" % [done.position.x, g.SET.x])
	_page("screen", 1)
	g.set_t = 0.0
	var wy0: float = (g._set_win() as Rect2).position.y
	var ry0: float = (g._set_rect(0) as Rect2).position.y
	g.set_t = 1.0
	var wy1: float = (g._set_win() as Rect2).position.y
	var ry1: float = (g._set_rect(0) as Rect2).position.y
	_ok("설정 창은 밑에서 떠오른다 · 줄이 같이 간다", wy0 > wy1 and is_equal_approx(wy0 - wy1,
			ry0 - ry1), "창 %.0f → %.0f · 줄 %.0f → %.0f" % [wy0, wy1, ry0, ry1])
	#  일시정지 → 설정 — 오른쪽 판이 자라 설정 창이 된다.
	_page("pause", 1)
	g._set_go("top")
	var b0: Rect2 = g._set_box()
	for k in 30:
		g._set_tick(1.0 / 60.0)
	var b1: Rect2 = g._set_box()
	_ok("설정으로 가면 오른쪽 판에서 창이 자란다", b0.is_equal_approx(g.SETP)
			and b1.size.is_equal_approx(g.SETW.set), "%s → %s" % [b0, b1])
	g._set_go("sound")
	_ok("탭만 갈면 창은 그대로", (g._set_box() as Rect2).is_equal_approx(b1))
	g._set_go("pause")
	var b2: Rect2 = g._set_box()
	for k in 30:
		g._set_tick(1.0 / 60.0)
	_ok("「뒤로」면 창이 오른쪽 판으로 줄어든다", b2.is_equal_approx(b1)
			and (g._set_box() as Rect2).is_equal_approx(g.SETP))
	g.motion_off = true
	g._set_go("screen")
	_ok("모션 끄기면 곧장 제 크기", (g._set_box() as Rect2).size.is_equal_approx(g.SETW.set))
	g.motion_off = false

	# ⑥ 흐림 판이 세기를 따라간다 — 설정이 아니면 꺼져 있어야 한다.
	#    켜 두면 화면을 후면 복사해 아홉 번 따는 값을 매 프레임 낸다.
	var blur = g.get_node_or_null("Blur")
	_ok("흐림 판이 있다", blur != null, "scenes/main.tscn 의 Blur")
	if blur != null:
		g.state = g.S.SETTINGS
		g.set_t = 0.0
		for k in 60:
			g._set_tick(1.0 / 60.0)
		var on: bool = blur.visible
		#  쪽을 갈아도 흐림은 그대로 선다 — 판은 한 번 멈췄을 뿐이다.
		g._set_go("sound")
		g._set_tick(1.0 / 60.0)
		var still: bool = blur.visible
		g.state = g.S.TITLE
		for k in 60:
			g._set_tick(1.0 / 60.0)
		_ok("설정에서 켜지고 쪽을 갈아도 선 채 · 닫으면 꺼진다", on and still and not blur.visible,
				"열림 %s · 쪽 갈이 %s → 닫힘 %s" % [on, still, blur.visible])
	#  닫히는 동안 일시정지 창은 일시정지 창으로 접힌다 — 설정 창으로 바뀌어 접히면 안 된다.
	g.state = g.S.SHOP
	g._pause_open()
	g.set_t = 1.0
	g.set_pg_t = 1.0
	_esc()
	_ok("일시정지가 닫히는 동안에도 일시정지 창", g.state == g.S.SHOP and g._set_pg() == "pause",
			g._set_pg())

	# ⑦ 얹힘 띠 — 커서를 올리면 왼쪽에서 쓸려 들어온다
	print("")
	_page("pause", 1)
	g.set_sel = 0
	var mid: Vector2 = g._set_rect(3).get_center()
	g.mouse_at = mid
	g._set_tick(1.0 / 60.0)
	_ok("커서 아래 줄을 집는다", g.set_hot == 3, "set_hot %d" % g.set_hot)
	_ok("얹힌 줄의 띠가 찬다", float(g.set_row_e[3]) > 0.0,
			"%.2f" % float(g.set_row_e[3]))
	for k in 30:
		g._set_tick(1.0 / 60.0)
	_ok("끝까지 차면 1", is_equal_approx(float(g.set_row_e[3]), 1.0),
			"%.2f" % float(g.set_row_e[3]))
	g.mouse_at = Vector2(-50.0, -50.0)
	for k in 30:
		g._set_tick(1.0 / 60.0)
	_ok("떠나면 진다", float(g.set_row_e[3]) < 0.02
			and float(g.set_row_e[0]) > 0.9,
			"떠난 줄 %.2f · 고른 줄 %.2f"
			% [float(g.set_row_e[3]), float(g.set_row_e[0])])
	# 나가는 동안 폭이 안 줄어야 한다 — 줄면 띠가 왼쪽으로 오므라든다
	g.mouse_at = mid
	for k in 30:
		g._set_tick(1.0 / 60.0)
	g.mouse_at = Vector2(-50.0, -50.0)
	g._set_tick(1.0 / 60.0)
	g._set_tick(1.0 / 60.0)
	_ok("질 때 폭은 그대로", float(g.set_row_w[3]) > 0.99
			and float(g.set_row_e[3]) < 1.0,
			"폭 %.2f · 짙기 %.2f"
			% [float(g.set_row_w[3]), float(g.set_row_e[3])])
	for k in 30:
		g._set_tick(1.0 / 60.0)
	_ok("다 진 뒤 폭을 접는다", float(g.set_row_w[3]) == 0.0,
			"폭 %.2f" % float(g.set_row_w[3]))
	#  쪽을 갈면 띠를 새로 세운다 — 앞 쪽 넷째 줄의 금빛이 새 쪽에 안 남는다.
	g._set_go("sound")
	_ok("쪽을 갈면 띠가 비고 첫 줄을 고른다", g.set_row_e.is_empty() and g.set_sel == 0)
	#  탭 얹힘 — 고른 탭이 아닌 탭 위에서 얹힘 열쇠가 선다(딸깍 · 뜸).
	_page("screen", 1)
	g.ui_hot = ""
	g.mouse_at = (g._set_tab_rect(1) as Rect2).get_center()
	g._set_tick(1.0 / 60.0)
	_ok("고르지 않은 탭에 얹히면 열쇠가 선다", g.ui_hot == "tab:소리", g.ui_hot)
	g.ui_hot = ""
	g.mouse_at = (g._set_tab_rect(0) as Rect2).get_center()
	g._set_tick(1.0 / 60.0)
	_ok("고른 탭에는 안 선다", g.ui_hot == "", g.ui_hot)
	g.mouse_at = Vector2(-50.0, -50.0)

	# ⑧ 눈으로 — 띠가 다 든 한 장씩
	_page("pause", 1)
	g.set_hot = -1
	g.set_sel = 0
	for k in 30:
		g._set_tick(1.0 / 60.0)
	await _shoot("settings_pause")
	g.mouse_at = g._set_rect(1).get_center()
	g._set_tick(1.0 / 60.0)
	g._set_tick(1.0 / 60.0)
	await _shoot("settings_hover")
	g.mouse_at = Vector2(-50.0, -50.0)
	_page("sound", 1)
	g.set_sel = 0                 # 효과음 — 줄 안에 게이지가 선다
	await _shoot("settings_vol")
	_page("pause", 1)
	g.set_sel = (g._set_rows() as Array).find("quit")   # 게임 나가기
	await _shoot("settings_quit")
	print("
스크린샷: settings_pause.png · settings_hover.png · settings_vol.png · settings_quit.png")

	print("\n%s\n" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	quit(0 if fail == 0 else 1)
