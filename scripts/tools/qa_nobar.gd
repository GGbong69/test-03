extends SceneTree
# 상단 띠 걷기 · 점수 칠판과 규칙 명판(2026-10-11 · game.gd topbar_on · SCOREB · RULEP) — 못 박는 것:
#   ① 띠는 어디서도 안 선다(판 고르기 · 판 · 정산 · 상점) — 첫 줄은 어디서나 상점 높이(HUD_UP)
#   ② 자금판이 늘어나 라운드 칸 여덟을 진다 — 칸이 판 안 · 라운드 넘김의 제자리가 그 칸
#   ③ 불 테두리는 화면 위끝에서 시작한다(띠가 없다)
#   ④ 명판이 없으면 칠판은 제자리(SCOREB.box)
#   ⑤ 명판이 하나 · 둘 · 셋 · 넷 · 다섯(+ 사건)이어도 칠판과 안 겹치고 칠판 테가 바닥(floor) 안이다
#   ⑥ 명판 둘(보통 보스 판 + 사건)까지는 칠판이 머리(라운드 · 판 이름)를 안 접는다
#   ⑦ 칠판은 명판 자리를 미끄러져 따라간다 · 움직임 끔이면 곧장
#   ⑧ 개발자 「상단 띠」 — 켜면 판에서 띠가 서고 첫 줄이 옛 자리(0) · 줄 · 갈래가 있다
#   godot --headless --path . --script scripts/tools/qa_nobar.gd
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
var g = null
var ok := 0
var bad := 0
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_qa_nobar_g.cfg"
	Save.path = "user://_qa_nobar.cfg"
	Save.prof_fmt = "user://_qa_nobar_%d.cfg"
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
	print("  %s %-52s %s" % ["통과" if cond else "실패", nm, note])


func _tick(sec: float) -> void:
	var n := int(ceil(sec / (1.0 / 60.0)))
	for i in n:
		g._rulep_tick(1.0 / 60.0)
		g._score_board_tick(1.0 / 60.0)


func _plates(mods: Array, ev: bool) -> void:
	g._ev_clear()
	g.rulep.clear()
	g.active_mods = mods
	if ev:
		g._order_open(g._order_region(0.3, 12345), 3, g._order_tag_pick(0.2), 777)
	_tick(1.5)


func _check(tag: String) -> Dictionary:
	var sb: Rect2 = g._score_board_box()
	var fr: float = float(g.SCOREB.frame)
	var outer := sb.grow(fr)
	var lap := false
	for it in g._rulep_layout():
		if (g._rulep_at(it) as Rect2).intersects(outer):
			lap = true
	var inside: bool = outer.end.y <= float(g.SCOREB.floor) + 0.5
	return {"lap": lap, "inside": inside, "full": sb.size.y >= (g.SCOREB.box as Rect2).size.y,
			"note": "%s 칠판 %s · 명판 %d" % [tag, outer, g._rulep_layout().size()]}


func _run() -> void:
	g._new_run()
	g.tut_run = false
	g._open_leg()
	g._swap_skip()
	var up: float = float(g.HUD_UP)

	# ①
	var all_hidden := true
	for st in [g.S.LEG, g.S.PICK, g.S.AIM_V, g.S.CLEAR, g.S.SHOP]:
		g.state = st
		if not g._bar_hidden() or g._hud_dy() != up:
			all_hidden = false
	_ok("① 판 고르기 · 판 · 조준 · 정산 · 상점 — 띠 없음 · 첫 줄 상점 높이", all_hidden)

	# ②
	g._begin_leg()
	g._swap_skip()
	g.state = g.S.PICK
	var br: Rect2 = g._bank_rect()
	var bp: Vector2 = g._bank_pip_at()
	var pw: float = float(g.LAY.bar_pip_dx) * float(g._run_rounds() - 1) + (g.LAY.bar_pip as Rect2).size.x
	_ok("② 판에서 자금판이 늘어난다", br.size.y == float(g.BANK.tall), str(br))
	_ok("② 라운드 칸 여덟이 자금판 안", br.encloses(Rect2(bp, Vector2(pw, (g.LAY.bar_pip as Rect2).size.y))),
			"%s · %s" % [bp, br])
	g.state = g.S.LEG
	var home: Rect2 = g._turn_cell(0, 0.0)
	_ok("② 라운드 넘김의 제자리가 자금판 칸", home.position == g._bank_pip_at(), str(home))

	# ③
	g.state = g.S.RESOLVE
	_ok("③ 불 테두리는 화면 위끝에서", g._fire_top() == (g._full() as Rect2).position.y,
			"%.1f" % g._fire_top())

	# ④ ~ ⑦
	g.state = g.S.PICK
	g.motion_off = true
	var mf: Array = GameData.modifiers()
	_plates([], false)
	_ok("④ 명판이 없으면 칠판은 제자리", g._score_board_box() == (g.SCOREB.box as Rect2),
			str(g._score_board_box()))
	var cases := [[[mf[0]], false], [[mf[0]], true], [[mf[0], mf[3]], false],
			[[mf[0], mf[3]], true], [[mf[0], mf[1], mf[5]], true],
			[[mf[0], mf[1], mf[5], mf[9]], false], [[mf[0], mf[1], mf[5], mf[9]], true]]
	var lap_all := true
	var in_all := true
	var notes := []
	for c in cases:
		_plates(c[0], c[1])
		var r := _check("%d+%s" % [(c[0] as Array).size(), "사건" if c[1] else "-"])
		if r.lap:
			lap_all = false
			notes.append(r.note)
		if not r.inside:
			in_all = false
			notes.append(r.note)
	_ok("⑤ 명판 하나 ~ 다섯 — 칠판과 안 겹친다", lap_all, str(notes))
	_ok("⑤ 칠판 테가 바닥 안", in_all, str(notes))
	var full_ok := true
	for c in [[[mf[0]], false], [[mf[0]], true], [[mf[0], mf[3]], false]]:
		_plates(c[0], c[1])
		if not _check("").full:
			full_ok = false
	_ok("⑥ 명판 둘까지 — 칠판이 머리를 안 접는다", full_ok)

	# ⑦
	g.motion_off = false
	_plates([], false)
	g.sb_y = NAN
	_tick(0.1)
	var y0: float = g._score_board_box().position.y
	g.active_mods = [mf[0], mf[3]]
	g._rulep_tick(1.0 / 60.0)
	g._score_board_tick(1.0 / 60.0)
	var want: float = g._score_board_want().position.y
	var y1: float = g._score_board_box().position.y
	_ok("⑦ 명판이 들면 칠판이 미끄러져 내려간다(한 틀에 다 안 간다)", want > y0 and y1 > y0 and y1 < want,
			"%.1f → %.1f (설 자리 %.1f)" % [y0, y1, want])
	_tick(1.5)
	_ok("⑦ 곧 설 자리에 앉는다", is_equal_approx(g._score_board_box().position.y, g._score_board_want().position.y))
	g.motion_off = true
	g.active_mods = []
	g.rulep.clear()
	g._score_board_tick(1.0 / 60.0)
	_ok("⑦ 움직임 끔 — 곧장", g._score_board_box().position.y == (g.SCOREB.box as Rect2).position.y)

	# ⑧
	g.topbar_on = true
	g.state = g.S.PICK
	_ok("⑧ 띠를 켜면 판에서 띠가 서고 첫 줄이 옛 자리", not g._bar_hidden() and g._hud_dy() == 0.0)
	g.state = g.S.SHOP
	_ok("⑧ 띠를 켜도 상점은 띠 없음", g._bar_hidden())
	g.topbar_on = false
	var dsrc: String = FileAccess.get_file_as_string("res://scripts/dev.gd")
	_ok("⑧ 개발자 줄 · 갈래", dsrc.contains("\"a\": \"topbar\"") and dsrc.contains("g.topbar_on = not g.topbar_on"))
