extends SceneTree
# 판 밖 메뉴의 얹힘 — 제목 프로필 패 · 프로필 지우기 · 설정 게이지 · 새 런
# 리그 칩과 설명 줄 · 컬렉션 칸. 한 물건을 안 얹힘 / 얹힘 / (누름)으로
# 위아래에 잘라 붙여 한 장에 둔다. 640x360 을 두 배로 한 번 더 키워 도트가
# 보이게 한다.
#   godot --path . --quit-after 4000 --script scripts/tools/shot_hover_a.gd
#   godot --path . --quit-after 4000 --script scripts/tools/shot_hover_a.gd -- before
#     (before 를 주면 파일 이름이 hova0_ 로 시작한다 — 고치기 전 그림)
#
# 진짜 저장은 안 건드린다. 리그는 대역 저장에 셋만 연다. 프로필 지우기
# 단추는 **1번 프로필 파일이 이미 있을 때만** 찍고, 누르지 않는다 —
# 겨눈 채 누르면 그 파일이 지워진다.
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false
var pin := Vector2(-50.0, -50.0)
var pre := "hova_"
var scale := 2


func _initialize() -> void:
	if OS.get_cmdline_user_args().has("before"):
		pre = "hova0_"
	Save.gpath = "user://_shot_hova_g.cfg"
	Save.prof_fmt = "user://_shot_hova_%d.cfg"
	Save.path = "user://_shot_hova.cfg"
	Save.wipe()
	var ls := GameData.leagues()
	for i in mini(3, ls.size()):
		Save.unlock(GameData.league_key(String(ls[i].get("id", ""))))
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if busy:
		g.mouse_at = pin
		return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		g._tutor_close()
		g.tutor_out = 0.0
		g.swap_live = false
		g.mouse_at = pin
		await process_frame


func _grab(at: Vector2, frames := 20) -> Image:
	pin = at
	await _wait(frames)
	var img: Image = root.get_texture().get_image()
	img.convert(Image.FORMAT_RGBA8)
	print("    %-28s ui_hot=%-14s hov=%s" % [str(at), g.ui_hot, str(g.ui_hov)])
	return img


#  누른 채 — 진짜 누름 사건을 넣는다(Input.is_mouse_button_pressed 가 읽는
#  자리). 사건이 _click 까지 가므로 누르면 안 되는 것에는 안 쓴다.
func _grab_press(at: Vector2, frames := 20) -> Image:
	pin = at
	await _wait(4)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = at * float(scale)
	ev.global_position = ev.position
	Input.parse_input_event(ev)
	var img: Image = await _grab(at, frames)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = ev.position
	up.global_position = ev.position
	Input.parse_input_event(up)
	await _wait(4)
	return img


#  같은 자리(게임 좌표)를 장마다 잘라 위에서 아래로 붙인다.
func _sheet(nm: String, region: Rect2, imgs: Array) -> void:
	var rr := Rect2i(Vector2i(region.position * float(scale)),
			Vector2i(region.size * float(scale)))
	var gap := 4
	var out := Image.create(rr.size.x, rr.size.y * imgs.size() + gap * (imgs.size() - 1),
			false, Image.FORMAT_RGBA8)
	out.fill(Color(1.0, 0.0, 1.0))
	for k in imgs.size():
		var im: Image = imgs[k]
		out.blit_rect(im, rr, Vector2i(0, k * (rr.size.y + gap)))
	out.resize(out.get_width() * 2, out.get_height() * 2, Image.INTERPOLATE_NEAREST)
	out.save_png("res://shots/%s%s.png" % [pre, nm])
	print("  찍음 %s%s" % [pre, nm])


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	var away := Vector2(-50.0, -50.0)
	var probe: Image = root.get_texture().get_image()
	scale = maxi(1, int(round(float(probe.get_width()) / 640.0)))

	# ① 제목 — 프로필 패
	g.state = g.S.TITLE
	var pb: Rect2 = g._prof_badge_rect()
	var t0 = await _grab(away, 30)
	var t1 = await _grab(pb.get_center())
	_sheet("title_prof", pb.grow(8.0), [t0, t1])

	# ② 프로필 — 지우기 단추 · 줄. 단추는 고른 자리에 파일이 있어야 선다.
	#    3번이 비어 있으면 찍는 동안만 빈 파일을 세우고 끝나면 걷는다 —
	#    원래 있던 파일이면 손대지 않는다.
	var made := false
	var sl := 3
	if not Save.slot_used(sl):
		var cf := ConfigFile.new()
		cf.set_value("stats", "runs", 1)
		made = cf.save(Save.slot_path(sl)) == OK
	if Save.slot_used(sl):
		g._open_profile()
		g.prof_sel = sl
		g.prof_arm = -1
		var dr: Rect2 = g._prof_del_rect()
		var p0 = await _grab(away, 30)
		var p1 = await _grab(dr.get_center())
		g.prof_arm = sl
		var p2 = await _grab(away)
		var p3 = await _grab(dr.get_center())
		g.prof_arm = -1
		_sheet("prof_del", dr.grow(8.0), [p0, p1, p2, p3])
		var r1: Rect2 = g._prof_rect(1)
		var q0 = await _grab(away)
		var q1 = await _grab(r1.get_center())
		_sheet("prof_rows", Rect2(8.0, 60.0, 216.0, 150.0), [q0, q1])
	else:
		print("  프로필 파일을 못 세워 지우기 단추는 건너뜀")
	if made:
		Save.erase_slot(sl)

	# ③ 설정 — 효과음 게이지
	g.pause_from = -1
	g.state = g.S.SETTINGS
	var rows: Array = g._set_rows()
	g.set_sel = rows.find("vol")
	await _wait(40)
	var tr: Rect2 = g._vol_track()
	var s0 = await _grab(away)
	var s1 = await _grab(tr.get_center() + Vector2(40.0, 0.0))
	g.set_drag = g.set_sel
	var s2 = await _grab(tr.get_center() + Vector2(40.0, 0.0))
	g.set_drag = -1
	_sheet("set_track", Rect2(214.0, 190.0, 386.0, 40.0), [s0, s1, s2])

	# ④ 새 런 — 리그 칩 · 설명 줄
	g.state = g.S.TITLE
	await _wait(10)
	g._open_newrun()
	GameData.league = String(GameData.leagues()[0].get("id", ""))
	await _wait(60)
	var chips := Rect2(158.0, 188.0, 324.0, 40.0)
	var n0 = await _grab(away)
	var n1 = await _grab(g._league_rect(0).get_center())
	var n2 = await _grab(g._league_rect(1).get_center())
	var n3 = await _grab(g._league_rect(5).get_center())
	var n4 = await _grab_press(g._league_rect(2).get_center())
	GameData.league = String(GameData.leagues()[0].get("id", ""))
	_sheet("league_chips", chips, [n0, n1, n2, n3, n4])
	var ln := Rect2(160.0, 244.0, 330.0, 50.0)
	var m0 = await _grab(away)
	var m1 = await _grab(g._league_line_rect(0).get_center())
	_sheet("league_line", ln, [m0, m1])

	# ⑤ 컬렉션 — 칸
	#  못 본 칸은 물음표라 그림이 안 보인다 — 전부 발견으로 그린다(저장은 안 만진다)
	g._dev_unlock_all()
	g.state = g.S.COLLECT
	g.collect_tab = 0
	g.collect_page = 0
	await _wait(20)
	var c0 = await _grab(away)
	var c1 = await _grab(g._col_cell(1).get_center())
	g.collect_tab = 2
	var c2 = await _grab(away)
	var c3 = await _grab(g._col_cell(1).get_center())
	var cr: Rect2 = g._col_cell(0).merge(g._col_cell(2)).grow(4.0)
	_sheet("collect_cell", cr, [c0, c1, c2, c3])
	g.collect_tab = 0

	# ⑥ 공용 부품 — 소리 열쇠만 확인(그림은 그대로)
	print("  공용 부품 열쇠")
	await _grab(g._col_tab_rect(1).get_center())
	await _grab(g._col_arrow_rect(true).get_center())
	await _grab(g._menu_back_rect().get_center())
	var full = await _grab(g._col_cell(8).get_center())
	full.save_png("res://shots/%scollect_full.png" % pre)
	print("  찍음")
	quit(0)
