extends SceneTree
# ══════════════════════════════════════════════════════════
#  런 끝 — 헛클릭이 런을 버리지 않는가
#
#  실행:  godot --headless --path . --script scripts/tools/qa_over.gd
#  종료 코드 = 실패 개수
#
#  왜 있는가
#    S.OVER 는 _click 이 **좌표를 한 번도 안 봤다** — 화면 어디를 눌러도
#    즉시 새 런이었고, 직전까지 정산을 넘기려고 두드리던 손이 그대로
#    흘러들었다. 고침은 둘이 짝이다: **확정 표적을 「새 런」 줄 안으로
#    좁히고**(진짜 고침) 0.40초 잠금을 얹는다(보조).
#
#  ⚠ SPACE 는 지금까지 **우연히** 살아 있던 길이다
#    _click(-1,-1) 로 흘러 들어가 「좌표를 안 보는 덕분에」 동작했다. 단추
#    안에서만 받게 되는 순간 조용히 죽는다 — 자동 검사가 없던 자리라
#    손으로 눌러 보기 전에는 안 드러난다. 그래서 여기에 단언을 박는다.
#
#  ⚠ 툴팁 앵커
#    「마지막까지 든 것」의 동전은 동전 슬롯이 아니다. tip_slot 으로 넘기면
#    _tip_pos 가 앵커를 _slot_rect 로 갈아타 툴팁이 **상단 슬롯**에 붙는다.
#    tip_mark 여야 하고 tip_slot 은 -1 이어야 한다.
#
#  자리는 노드 좌표다 — _click 을 직접 부르므로 view_pad 를 안 지난다.
#  키는 InputEventKey 를 만들어 _unhandled_input 에 **바로 넣는다**(qa_hudbtn 의
#  TAB 어법). 헤드리스에는 창 포커스가 없어 Input.parse_input_event 로 민 키는
#  노드까지 안 배달된다 — 마우스 단추는 배달되므로(input_probe) 손짓만 진짜
#  이벤트로 넣는다. 이 갈라둠을 안 적어 두면 다음 사람이 또 재 본다.
# ══════════════════════════════════════════════════════════
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var ok := 0
var bad := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_over_g.cfg"
	Save.path = "user://_qa_over.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	_run()
	print("\n통과 %d · 실패 %d" % [ok, bad])
	quit(bad)


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-46s %s" % ["통과" if cond else "실패", nm, note])


func _calm() -> void:
	g.swap_live = false
	g.photo = ""
	g.photo_rack = ""
	g._tutor_close()
	g.tutor_id = ""
	g.tutor_q.clear()
	g.tutor_out = 0.0
	g.hand_st = g.H.NONE
	g._autoplay = false
	g.pause_from = -1


#  런 끝 화면을 세운다. t 는 흐른 시간이다.
func _over(t: float) -> void:
	_calm()
	g.state = g.S.OVER
	g.over_t = t
	g.won = false
	g.motion_off = false


func _key(code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	g._unhandled_input(e)


#  든 동전 n 장. _new_run 이 동전 슬롯을 비우므로 재고 나서 다시 채운다.
func _give(n: int) -> void:
	g.owned = []
	for it in GameData.items():
		g.owned.append((it as Dictionary).duplicate())
		if g.owned.size() >= n:
			return


func _run() -> void:
	g._new_run()
	_calm()
	#  든 동전 셋으로 시작한다 — 툴팁과 표적 간격을 재려면 물건이 있어야 한다.
	_give(3)

	var btn: Rect2 = g._over_newrun_rect()
	_ok("「새 런」 줄이 손가락 크기다",
			btn.size.x >= 56.0 and btn.size.y >= 20.0, "%s" % btn.size)
	_ok("「새 런」 줄이 판 안이다",
			(g._over_panel() as Rect2).encloses(btn), "%s ⊂ %s" % [btn, g._over_panel()])

	# ── ⓐ 잠긴 동안은 단추 한가운데도 안 먹는다 ──────────────
	_over(0.0)
	g._click(btn.get_center())
	_ok("잠긴 동안 — 단추 한가운데를 눌러도 안 간다", g.state == g.S.OVER,
			"state %d" % g.state)
	_over(0.39)
	g._click(btn.get_center())
	_ok("0.39초 — 아직 안 간다", g.state == g.S.OVER)

	# ── ⓑ 잠금이 풀리면 단추 안에서 간다 ────────────────────
	_over(0.40)
	_ok("0.40초에 잠금이 풀린다", g._over_live(),
			"over_t %.2f · lock %.2f" % [g.over_t, g.OVER_LOCK])
	g._click(btn.get_center())
	_ok("잠금이 풀리면 「새 런」으로 간다", g.state == g.S.NEWRUN,
			"state %d" % g.state)

	# ── ⓒ 잠금이 풀려도 단추 **밖**은 안 먹는다 ──────────────
	var outs := {
		"판 한가운데": Vector2(320.0, 180.0),
		"판 밖 왼쪽": Vector2(20.0, 180.0),
		"검은 띠 위": Vector2(320.0, -40.0),
		"좌표 없음(-1,-1)": Vector2(-1.0, -1.0),
		"단추 바로 위": btn.get_center() - Vector2(0.0, 24.0),
	}
	for nm in outs:
		_over(2.0)
		g._click(outs[nm])
		_ok("잠금 뒤에도 단추 밖은 안 먹는다 — %s" % nm, g.state == g.S.OVER,
				"state %d" % g.state)

	# ── ⓓ 오토플레이는 잠금 밖이다 (소크 무변경) ──────────────
	_over(0.0)
	g._autoplay = true
	g._click(Vector2(320.0, 180.0))
	_ok("오토플레이 — 잠금 없이 곧장 새 런", g.state != g.S.OVER,
			"state %d" % g.state)
	g._autoplay = false

	# ── ⓔ ESC 와 SPACE ────────────────────────────────
	_over(0.0)
	_key(KEY_ESCAPE)
	_ok("ESC — 잠긴 동안은 아무 일도 없다", g.state == g.S.OVER,
			"state %d" % g.state)
	_over(1.0)
	_key(KEY_ESCAPE)
	_ok("ESC — 잠금이 풀리면 「새 런」과 같은 문으로 간다",
			g.state == g.S.NEWRUN, "state %d" % g.state)
	_over(0.0)
	_key(KEY_SPACE)
	_ok("SPACE — 잠긴 동안은 아무 일도 없다", g.state == g.S.OVER,
			"state %d" % g.state)
	_over(1.0)
	_key(KEY_SPACE)
	_ok("SPACE — 잠금이 풀리면 「새 런」과 같은 문으로 간다 (조용히 죽던 길)",
			g.state == g.S.NEWRUN, "state %d" % g.state)

	# ── ⓕ 그리는 사각과 누르는 사각이 같은 함수다 ────────────
	var src := FileAccess.get_file_as_string("res://scripts/game.gd")
	var draws := 0
	var clicks := 0
	for ln in src.split("\n"):
		var t := String(ln).strip_edges()
		if t.begins_with("#") or t.begins_with("func "):
			continue
		if t.contains("_over_newrun_rect()"):
			draws += 1
		if t.contains("_over_coin_rect("):
			clicks += 1
	_ok("「새 런」 사각을 쓰는 자리가 셋 이상 (그리기 · 누르기)",
			draws >= 2, "%d곳" % draws)
	_ok("동전 사각을 쓰는 자리가 셋 이상 (그리기 · 잡기 · 앵커)",
			clicks >= 3, "%d곳" % clicks)

	# ── ⓖ 남은 시간을 글자로 안 적는다 ─────────────────────
	var in_fn := false
	var strings := 0
	for ln in src.split("\n"):
		var t := String(ln)
		if t.begins_with("func _draw_over("):
			in_fn = true
			continue
		if in_fn and t.begins_with("func "):
			break
		if in_fn and not t.strip_edges().begins_with("#") \
				and t.contains("draw_string("):
			strings += 1
	#  여덟은 고친 뒤에도 고치기 전과 같은 수다 — 잠금은 **떠오름**으로만
	#  말하고 남은 시간을 숫자로 안 적는다. 이 수가 늘면 글자를 더한 것이다.
	_ok("런 끝 화면의 글자 수가 그대로 (잠금을 숫자로 안 적는다)",
			strings == 8, "draw_string %d곳" % strings)

	# ── ⓗ 모션을 꺼도 잠금은 0.40 그대로 ───────────────────
	_over(0.30)
	g.motion_off = true
	_ok("모션을 꺼도 잠금이 안 줄어든다", not g._over_live(),
			"over_t 0.30 · live %s" % g._over_live())
	g._click(btn.get_center())
	_ok("모션 끔 — 0.30초에는 그래도 안 간다", g.state == g.S.OVER)
	g.motion_off = false

	# ── ⓘ 잠긴 동안 거절이 안 운다 ───────────────────────
	_over(0.0)
	g.deny_flash = 0.0
	for i in 5:
		g._click(btn.get_center())
	_ok("잠긴 동안 거절이 안 운다 (연달아 울면 잔소리다)",
			is_equal_approx(g.deny_flash, 0.0), "%.3f" % g.deny_flash)

	# ── ⓙ 동전 표적 ─────────────────────────────────
	#  ⚠ 위 오토플레이 갈래가 _new_run 을 돌려 동전 슬롯을 비웠다. 다시 채운다.
	_over(2.0)
	_give(3)
	var c0: Rect2 = g._over_coin_rect(0)
	_ok("동전 사각이 24x24", is_equal_approx(c0.size.x, 24.0)
			and is_equal_approx(c0.size.y, 24.0), "%s" % c0.size)
	_ok("동전 사각이 판 안이다",
			(g._over_panel() as Rect2).encloses(c0), "%s" % c0)
	#  든 것이 여덟까지는 24px 원이 안 겹치고 아홉이면 23.33 으로 겹친다.
	#  읽기 전용 표적이라 오탭의 대가가 「옆 동전을 읽었다」뿐이다 — 수를
	#  찍어 남긴다.
	var keep: Array = g.owned.duplicate()
	for n in [2, 8, 9]:
		g.owned = []
		for i in n:
			g.owned.append((keep[i % keep.size()] as Dictionary).duplicate())
		var gap: float = (g._over_coin_rect(1) as Rect2).get_center().x \
				- (g._over_coin_rect(0) as Rect2).get_center().x
		_ok("든 것 %d — 중심 거리 %.2fpx %s" % [n, gap,
				"(24px 원 통과)" if gap >= 24.0 else "(아슬하게 겹친다 · 읽기 전용)"],
				gap >= 23.0, "%.2f" % gap)
	g.owned = keep

	# ── ⓚ 툴팁 앵커 — 6be42ea 재발 방지 ────────────────────
	_over(2.0)
	var hit: Dictionary = g._tip_hit((g._over_coin_rect(1) as Rect2).get_center())
	_ok("런 끝 동전이 잡힌다", String(hit.get("k", "")) == "rack"
			and int(hit.get("i", -1)) == 1, "%s" % hit)
	g._tip_build(hit)
	_ok("앵커가 tip_mark 다 (상단 슬롯에 안 붙는다)",
			(g.tip_mark as Rect2).size.x > 0.0, "%s" % g.tip_mark)
	_ok("tip_slot 이 -1 이다 (가린 막 뒤 얹힘 링을 안 켠다)",
			g.tip_slot == -1, "tip_slot %d" % g.tip_slot)
	_ok("앵커가 그 동전 자리다",
			(g.tip_mark as Rect2) == (g._over_coin_rect(1) as Rect2),
			"%s" % g.tip_mark)
	_ok("제목이 그 동전 이름이다",
			g.tip_title == String((g.owned[1] as Dictionary).get("n", "")),
			g.tip_title)
	#  같은 열쇠가 동전 슬롯에서는 **여태 그대로** tip_slot 으로 간다.
	g.state = g.S.SHOP
	g._tip_build({"k": "rack", "i": 1})
	_ok("동전 슬롯에서는 여태 그대로 tip_slot 이다",
			g.tip_slot == 1 and (g.tip_mark as Rect2).size.x <= 0.0,
			"tip_slot %d · mark %s" % [g.tip_slot, g.tip_mark])

	# ── 판 밖은 안 잡는다 ────────────────────────────
	_over(2.0)
	_ok("빈 자리는 안 잡는다", g._tip_hit(Vector2(320.0, 300.0)).is_empty())
	g.owned = []
	_ok("동전이 없으면 빈손", g._tip_hit(Vector2(400.0, 175.0)).is_empty())
