extends SceneTree

# 설정 화면 검사. 2026-09-13 사용자 제보 — "게임 나가기가 잘렸네"
#   행이 화면 안에 다 든다 · 행끼리 안 겹친다 · 게이지 수가 홈 밖에 있다 ·
#   누르는 자리와 그리는 자리가 같다 — **쪽마다** 잰다.
#
# 2026-10-03 — 평평한 일곱 줄을 갈래로 접었다.
#   「지금 설정이 저기서 다 나열되기 보단 화면안에 전체화면, crt 필터 이렇게 좀 상위가
#   있으면 좋겠는데, 지금 게임안에서 esc를 누르면 일시정지가 되어야지 일시정지에 설정을
#   누르면 설정창이 되어야지 ㅇㅋ?」(사용자)
#     일시정지  계속하기 · 설정 ‖ 로비로 나가기 · 게임 나가기     (판 중에만)
#     설정      화면 › · 소리 › ‖ 뒤로                            (제목은 곧장 여기)
#     화면      전체화면 · CRT 필터 · 화면 굴곡 ‖ 뒤로
#     소리      효과음 · 음악 ‖ 뒤로
#   예전 일곱 줄의 일(전체화면 · 효과음 · 음악 · CRT · 로비 · 나가기 · 계속)이 **하나도
#   안 빠지고** 어딘가의 쪽에 산다는 것, 들어가고 나오는 길이 키(ESC)와 화면 줄 둘 다로
#   한 단씩 오르내린다는 것을 잰다. 검사를 느슨하게 하지 않는다 — 옛 「제목 6줄 · 판 중
#   7줄」은 쪽마다의 줄 수로 바뀌었을 뿐 같은 자(화면 안 · 안 겹침 · 판과 안 닿음)로 잰다.
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


#  쪽을 세운다 — 다 밀려 든 자리에서 잰다.
func _page(pg: String, from := -1) -> void:
	g.state = g.S.SETTINGS
	g.pause_from = from
	g._set_go(pg)
	g.set_t = 1.0
	g.set_pg_t = 1.0


func _check(tag: String) -> void:
	g.set_t = 1.0              # 다 밀려 든 상태로 잰다
	g.set_pg_t = 1.0
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
		if not r.has_point(mid) or g._set_hit(mid) != i:
			overlap.append("%d 못 누름" % i)
	_ok("%s — 화면 안에 든다" % tag, top >= 96.0 and bot <= v.y - 6.0,
			"%.0f ~ %.0f (화면 %.0f · 머리 78)" % [top, bot, v.y])
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
	#  갈래 판은 안의 줄을 편다 — 줄 수만큼의 기준선(82 + 28k)이 판 바닥(턱 위) 안이다.
	var most := 0
	for k in rows:
		var inf: Dictionary = g._set_info(String(k))
		if inf.has("kids"):
			most = maxi(most, (inf["kids"] as Array).size())
	var last_y: float = pn.position.y + 82.0 + float(maxi(most - 1, 0)) * 28.0
	_ok("%s — 갈래 판의 줄이 판 안에 든다" % tag, last_y + 6.0 <= pn.end.y - float(g.PANEL_LIP),
			"마지막 기준선 %.0f · 판 바닥 %.0f" % [last_y, pn.end.y - float(g.PANEL_LIP)])


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

	# ① 쪽 넷 — 같은 자로 잰다
	_page("pause", g.S.SHOP)
	_check("일시정지")
	print("")
	_page("top", g.S.SHOP)
	_check("설정(판 중)")
	print("")
	_page("top", -1)
	_check("설정(제목)")
	print("")
	_page("screen", g.S.SHOP)
	_check("화면")
	print("")
	_page("sound", g.S.SHOP)
	_check("소리")

	# ② 줄의 차림 — 옛 일곱 줄의 일이 하나도 안 빠졌다
	print("")
	_page("pause", g.S.AIM_V)
	var rp: Array = g._set_rows()
	_ok("일시정지 — 계속하기 · 설정 · 로비 · 게임 나가기", rp == ["back", "set", "lobby", "quit"],
			"%s" % [rp])
	_ok("일시정지 맨 위는 「계속하기」", String(g._set_info("back").get("n", "")) == "계속하기")
	_page("top", -1)
	var rt: Array = g._set_rows()
	_ok("설정 — 화면 · 소리 · 뒤로", rt == ["screen", "sound", "back"], "%s" % [rt])
	_ok("제목에서 연 설정에는 「로비로 나가기」가 없다", not rt.has("lobby"))
	_page("pause", -1)
	_ok("판이 없으면 일시정지 쪽도 설정으로 읽는다", g._set_pg() == "top"
			and (g._set_rows() as Array) == ["screen", "sound", "back"])
	var screen_k: Array = g._set_info("screen").get("kids", [])
	var sound_k: Array = g._set_info("sound").get("kids", [])
	_ok("「화면」 = 전체화면 · CRT 필터 · 화면 굴곡", screen_k == ["fs", "crt", "warp"], "%s" % [screen_k])
	_ok("「소리」 = 효과음 · 음악", sound_k == ["vol", "mus"], "%s" % [sound_k])
	_page("screen", g.S.SHOP)
	_ok("화면 쪽 줄이 갈래의 안과 같다", (g._set_rows() as Array).slice(0, 3) == screen_k)
	_page("sound", g.S.SHOP)
	_ok("소리 쪽 줄이 갈래의 안과 같다", (g._set_rows() as Array).slice(0, 2) == sound_k)
	var all_keys := {}
	for pg in ["pause", "top", "screen", "sound"]:
		_page(pg, g.S.SHOP)
		for k in g._set_rows():
			all_keys[String(k)] = true
	var olds := ["back", "fs", "vol", "mus", "crt", "lobby", "quit"]
	var lost := []
	for k in olds:
		if not all_keys.has(k):
			lost.append(k)
	_ok("옛 일곱 줄의 일이 다 어딘가에 산다", lost.is_empty(), "빠짐 %s" % [lost])
	#  글줄 · 설명에 키 이름이 없다(「뒤로 ESC」 같은 글 금지 — 사용자 규칙).
	var keyname := []
	for k in all_keys.keys() + ["set", "screen", "sound", "warp"]:
		for pg in ["pause", "top", "screen"]:
			_page(pg, g.S.SHOP)
			var inf: Dictionary = g._set_info(String(k))
			var txt := String(inf.get("n", "")) + " " + String(inf.get("d", ""))
			for kn in ["ESC", "Esc", "TAB", "스페이스", "엔터", "Space"]:
				if txt.contains(kn):
					keyname.append(txt)
	_ok("글줄 · 설명에 키 이름이 없다", keyname.is_empty(), "%s" % [keyname])
	#  설명은 한 줄 — 판 안 폭(346)에 든다(효과만).
	var long := []
	for k in ["back", "fs", "vol", "mus", "crt", "warp", "lobby", "quit"]:
		var d := String(g._set_info(k).get("d", ""))
		if g.font.get_string_size(d, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x > g.SETP.size.x - 40.0:
			long.append(d)
	_ok("설명이 한 줄로 판에 든다", long.is_empty(), "%s" % [long])

	# ③ 오르내림 — 줄을 눌러 들어가고, 「뒤로」 · ESC 로 한 단씩 오른다
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
	_ok("상점의 일시정지 → 일시정지 쪽", g.state == g.S.SETTINGS and g._set_pg() == "pause"
			and g.pause_from == g.S.SHOP, "쪽 %s" % g._set_pg())
	_tap("set")
	_ok("「설정」을 누르면 설정 쪽", g._set_pg() == "top" and g.state == g.S.SETTINGS, g._set_pg())
	_ok("판은 그대로 멈춰 있다(돌아갈 자리를 안다)", g.pause_from == g.S.SHOP)
	_tap("screen")
	_ok("「화면」을 누르면 화면 쪽 · 첫 줄을 골라 둔다", g._set_pg() == "screen"
			and g.set_sel == 0, "%s · %d" % [g._set_pg(), g.set_sel])
	_tap("back")
	_ok("화면의 「뒤로」 → 설정 · 「화면」 줄에 손이 선다", g._set_pg() == "top"
			and String(g._set_rows()[g.set_sel]) == "screen")
	_tap("sound")
	_esc()
	_ok("소리에서 ESC → 설정 · 「소리」 줄", g._set_pg() == "top"
			and String(g._set_rows()[g.set_sel]) == "sound")
	_esc()
	_ok("설정에서 ESC → 일시정지 · 「설정」 줄", g._set_pg() == "pause"
			and String(g._set_rows()[g.set_sel]) == "set")
	_tap("set")
	_tap("back")
	_ok("설정의 「뒤로」 → 일시정지", g._set_pg() == "pause" and g.state == g.S.SETTINGS)
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
	_ok("제목의 「설정」 → 곧장 설정 쪽", g.state == g.S.SETTINGS and g._set_pg() == "top"
			and g.pause_from == -1, "state %d · 쪽 %s" % [g.state, g._set_pg()])
	_tap("screen")
	_esc()
	_esc()
	_ok("제목에서 연 설정은 ESC 두 번에 제목", g.state == g.S.TITLE, "state %d" % g.state)

	# ④ 밀려 들어오는 중 — 반쯤 들어온 자리가 화면 밖으로 안 나간다
	print("")
	_page("pause", 1)
	g.set_t = 0.5
	var half: Rect2 = g._set_rect(0)
	g.set_t = 0.0
	var out0: Rect2 = g._set_rect(0)
	g.set_t = 1.0
	var done: Rect2 = g._set_rect(0)
	_ok("밀려 들어온다", out0.position.x < half.position.x
			and half.position.x < done.position.x,
			"0%% %.0f → 50%% %.0f → 100%% %.0f"
			% [out0.position.x, half.position.x, done.position.x])
	_ok("다 들어오면 제자리", is_equal_approx(done.position.x, float(g.SET.x)),
			"%.0f (표 %.0f)" % [done.position.x, g.SET.x])
	#  쪽을 갈 때는 작게(SET_PG_SLIDE) 밀려 든다 — 그리는 자리와 누르는 자리가 같이 간다.
	g._set_go("top")
	var pg0: Rect2 = g._set_rect(0)
	for k in 30:
		g._set_tick(1.0 / 60.0)
	var pg1: Rect2 = g._set_rect(0)
	_ok("쪽을 갈면 새 줄이 작게 밀려 든다", pg0.position.x < pg1.position.x
			and pg1.position.x - pg0.position.x <= float(g.SET_PG_SLIDE) + 0.01
			and is_equal_approx(pg1.position.x, float(g.SET.x)),
			"%.1f → %.1f" % [pg0.position.x, pg1.position.x])
	g.motion_off = true
	g._set_go("sound")
	_ok("모션 끄기면 쪽도 곧장 제자리", is_equal_approx(g._set_rect(0).position.x, float(g.SET.x)))
	g.motion_off = false

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
		#  쪽을 갈아도 흐림은 그대로 선다 — 판은 한 번 멈췄을 뿐이다.
		g._set_go("screen")
		g._set_tick(1.0 / 60.0)
		var still: bool = blur.visible
		g.state = g.S.TITLE
		for k in 60:
			g._set_tick(1.0 / 60.0)
		_ok("설정에서 켜지고 쪽을 갈아도 선 채 · 닫으면 꺼진다", on and still and not blur.visible,
				"열림 %s · 쪽 갈이 %s → 닫힘 %s" % [on, still, blur.visible])

	# ⑥ 얹힘 띠 — 커서를 올리면 왼쪽에서 쓸려 들어온다
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

	# ⑦ 눈으로 — 띠가 다 든 한 장씩
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
	g.set_sel = 0                 # 효과음 — 오른쪽 판에 게이지가 선다
	await _shoot("settings_vol")
	_page("pause", 1)
	g.set_sel = (g._set_rows() as Array).find("quit")   # 게임 나가기
	await _shoot("settings_quit")
	print("
스크린샷: settings_pause.png · settings_hover.png · settings_vol.png · settings_quit.png")

	print("\n%s\n" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	quit(0 if fail == 0 else 1)
