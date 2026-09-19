extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  휠 검사 — 굴리는 것이 화살표·탭·게이지가 하는 일과 **같은가**
#
#  실행:  godot --path . --quit-after 900 --script scripts/tools/qa_wheel.gd
#  종료 코드 = 실패 개수
#
#  왜 있는가
#    저장소에 휠을 쏘는 자가 하나도 없었다 — cons_probe · swap_probe ·
#    qa_hudbtn · input_probe 가 전부 button_index 를 LEFT 로 박는다. 휠은
#    _unhandled_input 의 **맨 앞**에서 갈리므로, 그 갈래가 왼쪽 버튼 경로를
#    안 다쳤는지는 진짜 이벤트로만 잴 수 있다.
#
#  무엇이 규칙인가
#    휠은 **이미 선 화살표·탭·게이지가 하는 일만** 한다. 새 길을 안 만들고,
#    되돌릴 수 없는 행동(사기·팔기·던지기)에는 안 탄다. 받는 화면은 컬렉션 ·
#    런 정보 · 새 런 · 설정 · 프로필 **다섯뿐**이고 나머지는 조용히 흘린다.
#    dir 은 위 = -1 · 아래 = +1. 쪽·탭·줄은 +dir, 값은 -dir(위 = 크게).
#
#  어떻게 재는가
#    진짜 InputEventMouseButton 을 Input 에 밀어 넣어 _unhandled_input 을
#    지나게 한다 — 핸들러를 직접 부르면 그 관문을 통째로 건너뛴다. 자리는
#    뷰포트 좌표로 넣는다(_vp) — 첫 줄이 view_pad 를 뺀다. 헤드리스가 아닌
#    창 모드라 view_pad 가 0 이 아닌 값으로 서고, 그 채로 탭/격자 판별이
#    맞는지가 ⑦번 잣대다.
#
#    쿨다운(WHEEL_MS 60)은 **실시간**이라 한 프레임에 여러 번 쏘면 막힌다.
#    한 칸씩 재는 자리에서는 g.wheel_ms 를 0 으로 되돌려 문을 연다.
#    트랙패드 흉내(⑥)만 안 되돌리고 연달아 쏜다.
# ══════════════════════════════════════════════════════════

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.path = "user://_qa_wheel.cfg"
	Save.gpath = "user://_qa_wheel_g.cfg"
	Save.wipe()
	for r in GameData.tutor():
		var id := String(r.get("id", ""))
		if id != "":
			Save.teach(id)
	Input.use_accumulated_input = false
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c:
		okn += 1
	else:
		fail += 1
	print("  %s %-38s %s" % ["통과" if c else "실패", n, d])


func _process(_d: float) -> bool:
	if g != null:
		g.set_process(false)
	if busy:
		return false
	busy = true
	_run()
	return false


#  노드 좌표 → 창 좌표. 둘을 거친다.
#    ① _unhandled_input 첫 줄이 view_pad 를 뺀다 — 더해서 넣는다.
#    ② 창 모드는 논리 640x360 을 1280x720 로 늘린다(canvas_items x2). 들어오는
#       이벤트를 Viewport 가 그 역으로 되돌리므로 **여기서 미리 곱해야** 한다.
#       안 곱하면 자리가 절반이 되어, 격자를 겨눈 것이 탭 줄 위로 올라가
#       「굴렸더니 엉뚱한 것이 넘어간다」로 보인다(2026-09-19 여기서 한 번 속았다).
func _vp(p: Vector2) -> Vector2:
	return root.get_final_transform() * (p + g.view_pad)


# 휠 한 칸. 진짜 이벤트로 눌림·뗌 두 번을 쏜다 — 사람 손이 그렇게 들어온다.
func _roll(p: Vector2, dir: int, open_gate := true) -> void:
	if open_gate:
		g.wheel_ms = 0          # 쿨다운을 열어 둔다(실시간이라 프레임이 못 넘긴다)
	for down in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_WHEEL_UP if dir < 0 else MOUSE_BUTTON_WHEEL_DOWN
		e.pressed = down
		e.factor = 1.0
		e.position = _vp(p)
		Input.parse_input_event(e)
	Input.flush_buffered_events()


func _tick(n := 1) -> void:
	for i in n:
		g._process(1.0 / 60.0)


# 다섯 값을 한 줄로 — 「아무것도 안 움직였다」를 한 번에 잰다.
func _snap() -> Array:
	return [g.collect_page, g.collect_tab, g.runinfo_tab, g.newrun_pip,
			g.prof_sel, g.vol, g.vol_mus]


func _run() -> void:
	print("── 휠 ──────────────────────────────────────")
	print("  view_pad %s" % str(g.view_pad))
	_gate()
	_collect()
	_collect_tip()
	_runinfo()
	_newrun()
	_settings()
	_profile()
	_dead()
	_busy()
	_dev()
	print("── 통과 %d · 실패 %d ─────────────────────────" % [okn, fail])
	quit(fail)


# ── ① 한 쌍이 한 칸 · ② 왼쪽 버튼 경로를 안 다쳤다 ──────────
func _gate() -> void:
	g.state = g.S.COLLECT
	g.collect_tab = 0
	g.collect_page = 0
	var down: bool = g.mouse_down
	var at: Vector2 = g.mouse_at
	_roll(g._col_cell(0).get_center(), 1)
	_ok("한 쌍에 한 칸", g.collect_page == 1, "쪽 %d" % g.collect_page)
	_ok("mouse_down 을 안 덮는다", g.mouse_down == down,
			"%s → %s" % [down, g.mouse_down])
	_ok("mouse_at 을 안 덮는다", g.mouse_at.is_equal_approx(at))
	# ⑥ 트랙패드 흉내 — 문을 **한 번만** 열고 마흔 번 연달아 쏜다.
	#    한 번 쓸기가 이벤트 수십 개라, 쿨다운이 없으면 세 쪽이 통째로 감긴다.
	g.collect_page = 0
	g.wheel_ms = 0
	for i in 40:
		_roll(g._col_cell(0).get_center(), 1, false)
	_ok("쿨다운이 마흔 개를 한 칸으로", g.collect_page == 1,
			"쪽 %d" % g.collect_page)


# ── ③④⑦ 컬렉션 ────────────────────────────────────────
func _collect() -> void:
	g.state = g.S.COLLECT
	g.collect_tab = 0
	g.collect_page = 0
	var pages: int = g._col_pages()
	_ok("동전 탭 쪽 수", pages == 3, "%d 쪽 (%d 종 / %d)"
			% [pages, g._col_total(), g.COL_PAGE])

	# 격자 위 — 쪽이 넘어간다. 아래로 세 번이면 제자리(감긴다).
	var grid: Vector2 = g._col_cell(0).get_center()
	_roll(grid, 1)
	var p1: int = g.collect_page
	_roll(grid, 1)
	_roll(grid, 1)
	_ok("격자 위 = 쪽 · 감긴다", p1 == 1 and g.collect_page == 0,
			"1→%d … →%d" % [p1, g.collect_page])
	_roll(grid, -1)
	_ok("위로 = 앞 쪽", g.collect_page == pages - 1, "쪽 %d" % g.collect_page)

	# 쪽 번호·화살표 줄 위에서도 넘어간다(탭 줄 밖 전부)
	g.collect_page = 0
	_roll(g._col_arrow_rect(true).get_center(), 1)
	_ok("화살표 줄 위도 쪽", g.collect_page == 1, "쪽 %d" % g.collect_page)

	#  **화면 밖**에서는 안 넘어간다. 21:9 에서 view_pad.x 가 220 이라 좌우
	#  검은 띠가 통째로 살아 있는 휠 자리가 되어 있었다 — 게임이 한 점도 안
	#  그려진 자리다(2026-09-19). 여기는 진짜 이벤트가 아니라 라우터를 곧장
	#  부른다 — 창 밖 좌표는 창의 입력 길에서 살아남는다는 보장이 없고,
	#  재려는 것은 _wheel 안의 사각 검사 하나다.
	g.collect_page = 1
	var out := true
	for q in [Vector2(-180.0, 500.0), Vector2(900.0, -40.0),
			Vector2(-1.0, 100.0), Vector2(320.0, 400.0)]:
		g.wheel_ms = 0
		g._wheel(q, 1)
		if g.collect_page != 1:
			out = false
	_ok("화면 밖 휠은 흘린다", out, "쪽 %d" % g.collect_page)

	# 탭 줄 위 — 탭이 넘어가고 쪽이 0 으로 박힌다
	g.collect_tab = 0
	g.collect_page = 2
	_roll(g._col_tab_rect(0).get_center(), 1)
	_ok("탭 줄 위 = 탭 · 쪽 0",
			g.collect_tab == 1 and g.collect_page == 0,
			"탭 %d · 쪽 %d" % [g.collect_tab, g.collect_page])
	# 마지막 탭 위에서 굴려도 탭 줄이므로 탭이 돈다
	g.collect_tab = g.COL_TABS.size() - 1
	_roll(g._col_tab_rect(g.COL_TABS.size() - 1).get_center(), 1)
	_ok("탭이 감긴다", g.collect_tab == 0, "탭 %d" % g.collect_tab)

	# ④ 1쪽짜리 탭 — 격자 위에서 굴려도 쪽이 안 움직인다
	var single := 0
	var moved := 0
	for t in g.COL_TABS.size():
		g.collect_tab = t
		g.collect_page = 0
		if g._col_pages() > 1:
			continue
		single += 1
		_roll(grid, 1)
		if g.collect_page != 0:
			moved += 1
		# 탭 줄 위에서는 언제나 탭이 돈다 — 죽은 자리가 안 생긴다
		var tb: int = g.collect_tab
		_roll(g._col_tab_rect(t).get_center(), 1)
		if g.collect_tab == tb:
			moved += 1
	_ok("1쪽 탭에서 쪽이 안 돈다", moved == 0 and single >= 4,
			"1쪽 탭 %d개 · 어긋남 %d" % [single, moved])

	# ⑦ 탭 줄과 격자가 안 겹친다 — view_pad 가 실린 채로 잰다
	var tb2: Rect2 = g._col_tab_rect(0).merge(
			g._col_tab_rect(g.COL_TABS.size() - 1))
	var over := false
	for i in g.COL_PAGE:
		if tb2.intersects(g._col_cell(i)):
			over = true
	_ok("탭 줄과 격자가 안 겹친다", not over,
			"탭 y%.0f~%.0f · 격자 y%.0f~" % [tb2.position.y, tb2.end.y,
				g._col_cell(0).position.y])


# ── 컬렉션 2·3 쪽의 툴팁을 처음으로 잰다 ─────────────────
#  probe_collect 는 collect_page = 0 을 박고 돈다. 휠로 넘긴 쪽에서
#  _tip_hit 의 collect_page * COL_PAGE + i 가 맞는 물건을 집는지 잴 자가
#  저장소에 없었다.
func _collect_tip() -> void:
	g.state = g.S.COLLECT
	g.collect_tab = 0
	var rows: Array = GameData.items()
	var bad := ""
	for pg in g._col_pages():
		g.collect_page = pg
		var n: int = g._col_count()
		for i in [0, n - 1]:
			var hit: Dictionary = g._tip_hit(g._col_cell(i).get_center())
			var idx: int = int(hit.get("i", -1))
			var want: int = pg * g.COL_PAGE + i
			g._tip_build(hit)
			if String(hit.get("k", "")) != "citem" or idx != want \
					or g.tip_title != String(rows[want].get("n", "")):
				bad += " %d쪽칸%d" % [pg + 1, i]
	_ok("쪽마다 툴팁이 표 순서와 맞다", bad == "",
			"쪽 %d · 어긋남%s" % [g._col_pages(), bad if bad != "" else " 없음"])


# ── 런 정보 ──────────────────────────────────────────────
func _runinfo() -> void:
	g._new_run()
	g._swap_skip()
	g.run_from = g.state
	g.state = g.S.RUNINFO
	g.runinfo_tab = 0
	var c: Vector2 = g._ri_panel().get_center()
	_roll(c, 1)
	var t1: int = g.runinfo_tab
	for i in g.RI_TABS.size() - 1:
		_roll(c, 1)
	_ok("판 위 휠 = 탭 · 감긴다", t1 == 1 and g.runinfo_tab == 0,
			"1→%d … →%d" % [t1, g.runinfo_tab])
	_roll(c, -1)
	_ok("위로 = 앞 탭", g.runinfo_tab == g.RI_TABS.size() - 1,
			"탭 %d" % g.runinfo_tab)

	# 판 높이가 탭을 갈아도 안 변한다 — 휠로 훑어도 판이 안 뛴다
	var h: float = g._ri_panel().size.y
	var same := true
	for t in g.RI_TABS.size():
		g.runinfo_tab = t
		if not is_equal_approx(g._ri_panel().size.y, h):
			same = false
	_ok("탭을 갈아도 판이 안 뛴다", same, "높이 %.0f" % h)

	# 판 **밖**에서 굴리면 아무 일도 안 난다
	g.runinfo_tab = 1
	_roll(Vector2(8.0, 8.0), 1)
	_ok("판 밖 휠은 흘린다", g.runinfo_tab == 1, "탭 %d" % g.runinfo_tab)

	# 「보유」 동전 툴팁 — 그리는 자와 짚는 자가 같은가
	g.runinfo_tab = 3
	_ri_coins()


func _ri_coins() -> void:
	var out := []
	for it in GameData.items():
		if out.size() < 3:
			var cp: Dictionary = it.duplicate()
			cp.gs = 0
			out.append(cp)
	g.owned = out
	g.sealed = -1
	g._panel_reset()
	# 옛 그리기 식과 새 자가 같은 점을 내는가
	var p: Rect2 = g._ri_panel()
	var xl: float = p.position.x + 16.0
	var cxw: float = xl + float(g.RI.coin_x)
	var step: float = minf(34.0, (xl + p.size.x - 32.0 - cxw - 24.0)
			/ float(g.owned.size()))
	var same := true
	for i in g.owned.size():
		var want := Vector2(cxw + 12.0 + float(i) * step,
				p.position.y + float(g.RI.top) + 10.0)
		if not g._ri_coin_rect(i).get_center().is_equal_approx(want):
			same = false
	_ok("동전 자 하나 — 그리기 식과 같다", same)

	var hit_ok := true
	for i in g.owned.size():
		var hit: Dictionary = g._tip_hit(g._ri_coin_rect(i).get_center())
		if String(hit.get("k", "")) != "rack" or int(hit.get("i", -1)) != i:
			hit_ok = false
		g._tip_build(hit)
		if g.tip_title != String(g.owned[i].n):
			hit_ok = false
	_ok("「보유」 동전이 제 툴팁을 세운다", hit_ok,
			"동전 %d장" % g.owned.size())

	#  **앵커가 커서 밑 동전에 붙는가.** 같은 열쇠(rack)가 HUD 상단 슬롯에서도
	#  오므로, _tip_build 가 tip_slot 을 그대로 넘기면 _tip_pos 가 앵커를
	#  _slot_rect 로 갈아타 툴팁이 딴 자리에 뜨고(가로 최대 86px) 제 상자가
	#  가리킨 동전 줄을 덮는다. 덤으로 _draw_rack 의 얹힘 링이 엉뚱한 슬롯에서
	#  켜진다. 여기서 잰다 — 2026-09-19 에 한 번 그랬다.
	var anc := true
	var cov := ""
	for i in g.owned.size():
		var cr: Rect2 = g._ri_coin_rect(i)
		g._tip_build(g._tip_hit(cr.get_center()))
		if g.tip_slot != -1 or not g.tip_mark.get_center().is_equal_approx(
				cr.get_center()):
			anc = false
		var box := Rect2(g._tip_pos(g._tip_size()), g._tip_size())
		if absf(box.get_center().x - cr.get_center().x) > 4.0 \
				and box.position.x > 4.0 and box.end.x < g.VIEW.x - 4.0:
			anc = false
		if box.intersects(cr):
			cov += " %d" % i
	_ok("툴팁이 그 동전에 붙는다", anc, "동전 %d장" % g.owned.size())
	_ok("툴팁이 그 동전을 안 덮는다", cov == "",
			"덮음%s" % (cov if cov != "" else " 없음"))

	#  HUD 상단 슬롯 쪽은 한 칸도 안 변했는가 — 거기는 사각이 아니라 링이고,
	#  앵커도 _slot_rect 그대로여야 한다.
	var keep: int = g.state
	g.state = g.S.PICK
	g._tip_build({"k": "rack", "i": 0})
	var sb := Rect2(g._tip_pos(g._tip_size()), g._tip_size())
	_ok("상단 슬롯은 그대로 링 · 제 슬롯에 붙는다",
			g.tip_slot == 0 and g.tip_mark.size.x == 0.0
			and absf(sb.get_center().x
				- g._slot_rect(0).get_center().x) <= 4.0,
			"슬롯 %d · 가로차 %.0f" % [g.tip_slot,
				sb.get_center().x - g._slot_rect(0).get_center().x])
	g.state = keep
	# 다른 탭에서는 안 잡는다 — 그림이 없는 자리다
	g.runinfo_tab = 0
	var none: Dictionary = g._tip_hit(g._ri_coin_rect(0).get_center())
	_ok("다른 탭에서는 안 잡는다", String(none.get("k", "")) != "rack")
	g.runinfo_tab = 3
	# 칸끼리 안 겹친다
	var over := false
	for i in g.owned.size():
		for j in range(i + 1, g.owned.size()):
			if g._ri_coin_rect(i).intersects(g._ri_coin_rect(j)):
				over = true
	_ok("동전 칸끼리 안 겹친다", not over)
	g.owned = []
	g._panel_reset()


# ── 새 런 ────────────────────────────────────────────────
func _newrun() -> void:
	g.state = g.S.TITLE
	g._open_newrun()
	var n: int = GameData.packs().size()
	_ok("다트통 수", n == 13, "%d칸" % n)

	# ⑧ 점 열셋이 서로 · 리그 줄과 안 겹친다
	var over := ""
	for k in n:
		for j in range(k + 1, n):
			if g._pack_pip_rect(k).intersects(g._pack_pip_rect(j)):
				over += " 점%d-%d" % [k, j]
	for k in n:
		for i in GameData.leagues().size():
			if g._pack_pip_rect(k).intersects(g._league_rect(i)):
				over += " 점%d-리그%d" % [k, i]
	var gap: float = g._league_rect(0).position.y - g._pack_pip_rect(0).end.y
	_ok("점 열셋 · 리그 줄과 안 겹친다", over == "" and gap >= 2.0,
			"틈 %.0fpx%s" % [gap, over])

	# 그리는 자리가 누르는 칸 안에 든다
	var inside := true
	for k in n:
		if not g._pack_pip_rect(k).has_point(g._pack_pip(k)):
			inside = false
	_ok("점 그림이 제 칸 안에 있다", inside)

	# 점을 누르면 그 통으로 간다 — 화살표와 같은 값에 닿는가
	var jumped := true
	for k in n:
		g._click(g._pack_pip_rect(k).get_center())
		if g.newrun_pip != k:
			jumped = false
		if String(GameData.pack) != String(GameData.packs()[k].get("id", "")):
			jumped = false
	_ok("점을 누르면 그 통", jumped, "지금 %d" % g.newrun_pip)

	# 통 무대 위 휠 = 화살표 한 칸
	g._pack_view(0)
	_roll(g._pack_rect().get_center(), 1)
	var a1: int = g.newrun_pip
	_roll(g._pack_rect().get_center(), -1)
	_ok("통 무대 휠 = 한 칸 · 되돌아온다",
			a1 == 1 and g.newrun_pip == 0, "0→%d→%d" % [a1, g.newrun_pip])
	# 화살표 자리 위에서도 먹는다
	_roll(g._pack_arrow(true).get_center(), 1)
	_ok("화살표 자리 위도 먹는다", g.newrun_pip == 1, "통 %d" % g.newrun_pip)
	# 리그 줄 위에서는 **안 받는다** — _deny 가 연달아 우는 자리다
	g._pack_view(0)
	_roll(g._league_rect(0).get_center(), 1)
	_ok("리그 줄 위는 흘린다", g.newrun_pip == 0, "통 %d" % g.newrun_pip)

	_pack_save_test()


# 휠 열 번에 프로필 파일 쓰기가 한 번인가
func _pack_save_test() -> void:
	g._pack_view(0)
	g._pack_save()
	var was := String(Save.get_pick("pack", ""))
	for i in 10:
		_roll(g._pack_rect().get_center(), 1)
	var mid := String(Save.get_pick("pack", ""))
	var live := String(GameData.pack)
	_ok("굴리는 동안은 디스크를 안 친다", mid == was and live != was,
			"파일 %s · 화면 %s" % [mid, live])
	# 0.30 초가 지나면 한 번 앉는다
	g.state = g.S.NEWRUN
	for i in 30:
		g._process(1.0 / 60.0)
	_ok("굴림이 멎으면 앉는다", String(Save.get_pick("pack", "")) == live,
			"파일 %s" % Save.get_pick("pack", ""))

	# 나가는 자리가 미룬 값을 비운다 — 「시작」·「뒤로」·ESC
	for way in ["go", "back", "esc"]:
		g.state = g.S.TITLE
		g._open_newrun()
		g._pack_view(0)
		g._pack_save()
		_roll(g._pack_rect().get_center(), 1)
		var want := String(GameData.pack)
		match way:
			"go":
				g._new_run()
				g._swap_skip()
			"back":
				g._click(g._newrun_back().get_center())
			"esc":
				_esc()
		_ok("나갈 때 비운다 — %s" % way,
				String(Save.get_pick("pack", "")) == want and g.pack_save_t <= 0.0,
				"파일 %s" % Save.get_pick("pack", ""))


func _esc() -> void:
	var e := InputEventKey.new()
	e.keycode = KEY_ESCAPE
	e.pressed = true
	Input.parse_input_event(e)
	Input.flush_buffered_events()
	var u := InputEventKey.new()
	u.keycode = KEY_ESCAPE
	u.pressed = false
	Input.parse_input_event(u)
	Input.flush_buffered_events()


# ── 설정 ─────────────────────────────────────────────────
func _settings() -> void:
	g.pause_from = -1
	g.state = g.S.SETTINGS
	g.set_t = 1.0
	var rows: Array = g._set_rows()
	g.set_sel = rows.find("vol")
	g.set_hot = -1
	g.vol = 1.0
	g._apply_vol()
	Save.set_set("vol", 1.0)
	var tr: Vector2 = g._vol_track().get_center()

	_roll(tr, 1)
	_ok("아래로 = 작게 0.05", is_equal_approx(g.vol, 0.95), "%.2f" % g.vol)
	_roll(tr, -1)
	_ok("위로 = 크게", is_equal_approx(g.vol, 1.0), "%.2f" % g.vol)
	# 끝에서 선다
	for i in 5:
		_roll(tr, -1)
	_ok("끝에서 선다", is_equal_approx(g.vol, 1.0), "%.2f" % g.vol)

	# 스무 번 굴려도 파일은 한 번 — 그동안 디스크는 옛 값이다
	for i in 4:
		_roll(tr, 1)
	var live: float = g.vol
	_ok("굴리는 동안은 디스크를 안 친다",
			is_equal_approx(float(Save.get_set("vol", -1.0)), 1.0)
			and is_equal_approx(live, 0.8),
			"파일 %.2f · 화면 %.2f" % [Save.get_set("vol", -1.0), live])
	for i in 30:
		g._process(1.0 / 60.0)
	_ok("굴림이 멎으면 앉는다",
			is_equal_approx(float(Save.get_set("vol", -1.0)), live),
			"파일 %.2f" % Save.get_set("vol", -1.0))

	# 홈 밖에서 굴리면 아무 일도 안 난다
	var before: float = g.vol
	_roll(Vector2(20.0, 340.0), 1)
	_ok("홈 밖은 흘린다", is_equal_approx(g.vol, before), "%.2f" % g.vol)
	# 게이지가 아닌 줄을 고른 채로 홈 위에서 굴려도 안 움직인다
	g.set_sel = rows.find("fs")
	_roll(tr, 1)
	_ok("게이지 줄이 아니면 흘린다", is_equal_approx(g.vol, before),
			"%.2f" % g.vol)
	# 음악 줄을 고르면 같은 홈이 음악을 만진다
	g.set_sel = rows.find("mus")
	g.vol_mus = 0.8
	var v0: float = g.vol
	_roll(tr, 1)
	_ok("고른 줄이 어느 소리인지 정한다",
			is_equal_approx(g.vol_mus, 0.75) and is_equal_approx(g.vol, v0),
			"음악 %.2f · 효과음 %.2f" % [g.vol_mus, g.vol])
	for i in 30:
		g._process(1.0 / 60.0)

	# 끊는 단위 — 끌기는 0.01 그대로다
	g.set_sel = rows.find("vol")
	var track: Rect2 = g._vol_track()
	g._set_slide(g.set_sel, Vector2(track.position.x + track.size.x * 0.333,
			track.get_center().y))
	_ok("끌기 단위는 0.01 그대로",
			is_equal_approx(g.vol, snappedf(g.vol, 0.01))
			and not is_equal_approx(g.vol, snappedf(g.vol, 0.05)),
			"%.2f" % g.vol)
	g._set_slide_end()
	g.vol = 1.0
	g._apply_vol()


# ── 프로필 ───────────────────────────────────────────────
func _profile() -> void:
	g.state = g.S.PROFILE
	g.prof_sel = 1
	g.prof_arm = 2
	var c: Vector2 = g._prof_rect(0).merge(g._prof_rect(Save.SLOTS - 1)).get_center()
	_roll(c, 1)
	_ok("아래로 = 다음 줄 · 겨눔이 풀린다",
			g.prof_sel == 2 and g.prof_arm == -1,
			"줄 %d · 겨눔 %d" % [g.prof_sel, g.prof_arm])
	for i in 5:
		_roll(c, 1)
	_ok("끝에서 선다(안 감긴다)", g.prof_sel == Save.SLOTS,
			"줄 %d / %d" % [g.prof_sel, Save.SLOTS])
	for i in 5:
		_roll(c, -1)
	_ok("위로도 끝에서 선다", g.prof_sel == 1, "줄 %d" % g.prof_sel)
	# 쓰는 프로필은 안 바뀐다 — 들어가는 것은 둘째 클릭이다
	var slot := Save.slot()
	g.prof_sel = 1
	for i in 6:
		_roll(c, 1)
	_ok("휠만으로는 프로필이 안 바뀐다", Save.slot() == slot,
			"쓰는 줄 %d" % Save.slot())
	# 칸 밖은 흘린다
	g.prof_sel = 1
	_roll(g._prof_del_rect().get_center(), 1)
	_ok("지우기 단추 위는 흘린다", g.prof_sel == 1, "줄 %d" % g.prof_sel)


# ── ⑤ 받지 않는 화면에서는 아무것도 안 움직인다 ───────────
func _dead() -> void:
	g.owned = []
	g._panel_reset()
	var spots := [Vector2(320.0, 180.0), Vector2(60.0, 60.0),
			Vector2(560.0, 300.0), Vector2(320.0, 340.0)]
	for nm in ["AIM_V", "SHOP", "TITLE", "RESOLVE", "LEG", "CLEAR", "OVER"]:
		_stage(nm)
		var was := _snap()
		var st: int = g.state
		for p in spots:
			_roll(p, 1)
			_roll(p, -1)
		_ok("%s 에서 흘린다" % nm, _snap() == was and g.state == st,
				"%s" % str(_snap()))


func _stage(name: String) -> void:
	match name:
		"AIM_V":
			g._new_run()
			g._begin_leg()
			g._swap_skip()
			g.state = g.S.PICK
			g.grip_pick = -1
			g._pick_dart(0)
		"SHOP":
			g._new_run()
			g._open_shop()
			g._swap_skip()
			for i in 200:
				if not g._drop_busy():
					break
				g._process(1.0 / 60.0)
		"TITLE":
			g.state = g.S.TITLE
		"RESOLVE":
			g._new_run()
			g._swap_skip()
			g.state = g.S.RESOLVE
		"LEG":
			g._new_run()
			g._swap_skip()
			g.state = g.S.LEG
		"CLEAR":
			g._new_run()
			g._swap_skip()
			g.state = g.S.CLEAR
		"OVER":
			g._new_run()
			g._swap_skip()
			g.state = g.S.OVER


# ── 연출 중 · 배우는 중 · 인트로 · 쥔 손에 안 샌다 ─────────
func _busy() -> void:
	g.state = g.S.COLLECT
	g.collect_tab = 0
	g.collect_page = 0
	var c: Vector2 = g._col_cell(0).get_center()

	g.swap_live = true
	_roll(c, 1)
	_ok("판 갈이 중에 안 샌다", g.collect_page == 0, "쪽 %d" % g.collect_page)
	g.swap_live = false

	g._autoplay = true
	_roll(c, 1)
	_ok("검증 중에 안 샌다", g.collect_page == 0, "쪽 %d" % g.collect_page)
	g._autoplay = false

	g.hand_st = g.H.CARRY
	_roll(c, 1)
	_ok("무언가를 쥔 손에 안 샌다", g.collect_page == 0, "쪽 %d" % g.collect_page)
	g.hand_st = g.H.NONE

	g.photo = "paint"
	_roll(c, 1)
	_ok("덮은 층(사진)에 안 샌다", g.collect_page == 0, "쪽 %d" % g.collect_page)
	g.photo = ""

	var st: int = g.state
	g.state = g.S.INTRO
	_roll(c, 1)
	_ok("인트로를 안 끝낸다", g.state == g.S.INTRO, "%s" % str(g.state))
	g.state = st

	# 배우는 중 — 걸음이 넘어가면 안 된다
	if not g.tutor_id.is_empty():
		pass
	g.state = g.S.COLLECT
	_roll(c, 1)
	_ok("제 화면에서는 다시 먹는다", g.collect_page == 1,
			"쪽 %d" % g.collect_page)

	# 판 갈이 — 클릭으로도 건너뛴다(키와 같은 결과)
	g._new_run()
	g._begin_leg()
	g.swap_t = 0.0
	g.swap_live = true
	g.swap_scr = g.state
	g._click(Vector2(320.0, 200.0))
	_ok("클릭이 판 갈이를 건너뛴다",
			not g.swap_live and g.swap_scr == -1 and is_equal_approx(g.swap_t, 0.0),
			"live %s · scr %d" % [g.swap_live, g.swap_scr])


# ── 개발자 모드 ──────────────────────────────────────────
func _dev() -> void:
	var Dev = load("res://scripts/dev.gd")
	g.state = g.S.COLLECT
	g.collect_tab = 0
	g.collect_page = 0
	Dev.on = true
	Dev.open_k = ""
	Dev.page = 0

	# 판 안에서 굴린 헛바퀴가 밑 화면의 쪽을 안 먹는다
	_roll(Dev._panel().get_center(), 1)
	_ok("개발자 판이 헛굴림을 삼킨다", g.collect_page == 0,
			"쪽 %d" % g.collect_page)

	# 페이지 탭 — TAB 키와 같은 값
	_roll(Dev._tab(0).get_center(), 1)
	var p1: int = Dev.page
	for i in Dev.PAGES.size() - 1:
		_roll(Dev._tab(0).get_center(), 1)
	_ok("탭이 TAB 키와 같은 값 · 감긴다", p1 == 1 and Dev.page == 0,
			"1→%d … →%d" % [p1, Dev.page])

	# 목록 줄 — ◀▶ 와 같은 길
	Dev.page = 0
	var rows: Array = Dev._rows(g)
	var li := -1
	for i in rows.size():
		if String(rows[i].get("t", "")) == "list" and int(rows[i].get("n", 0)) > 1:
			li = i
			break
	if li >= 0:
		var k: String = String(rows[li].k)
		Dev.pick[k] = 0
		_roll(Dev._row(li).get_center(), 1)
		var v1: int = int(Dev.pick.get(k, -1))
		_roll(Dev._row(li).get_center(), -1)
		_ok("목록 줄이 ◀▶ 와 같은 값",
				v1 == 1 and int(Dev.pick.get(k, -1)) == 0,
				"%s 0→%d→%d" % [k, v1, Dev.pick.get(k, -1)])
	else:
		_ok("목록 줄이 ◀▶ 와 같은 값", false, "잴 줄이 없다")

	# 고르개가 떠 있으면 그것이 휠을 통째로 가진다
	Dev.open_k = "item"
	Dev.open_page = 0
	var pages: int = Dev._pick_pages(Dev._names("item").size())
	g.collect_page = 0
	_roll(Vector2(320.0, 180.0), 1)
	_ok("고르개가 휠을 가진다",
			Dev.open_page == posmod(1, pages) and g.collect_page == 0,
			"쪽 %d / %d · 밑 화면 %d" % [Dev.open_page, pages, g.collect_page])
	Dev.open_k = ""

	# 꺼 두면 한 톨도 안 가로챈다
	Dev.on = false
	g.collect_page = 0
	_roll(Dev._panel().get_center(), 1)
	_ok("꺼 두면 안 가로챈다", g.collect_page == 1, "쪽 %d" % g.collect_page)
