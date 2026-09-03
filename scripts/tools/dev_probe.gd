extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")

# ══════════════════════════════════════════════════════════
#  개발자 모드 검사 — 누르는 자리가 실제로 일을 하는가
#
#  실행:  godot --path . --headless --script scripts/tools/dev_probe.gd
#  종료 코드 = 실패 개수
#
#  이 판에는 검사가 없었고, 그래서 다음이 그대로 나갔다:
#    "◀ 값 ▶" 을 오른쪽 정렬로 그려 놓고 줄을 3등분해서 판정했다. 두
#    화살표가 다 오른쪽 3분의 1 안에 들어가 ◀ 가 "다음" 이 되고, 적용은
#    아무것도 안 그려진 가운데 빈 칸을 눌러야 일어났다 — 화살표를 아무리
#    눌러도 게임이 안 바뀌었다.
#
#  그래서 여기서는 **좌표를 만들어 Dev.click 을 부른다.** 값을 직접 박으면
#  이 결함이 안 잡힌다. 못 박는 것:
#    ① 그려지는 화살표 칸과 값 칸이 줄 안에서 안 겹치고 안 삐져나온다
#    ② ◀ 는 뒤로, ▶ 는 앞으로 — 방향이 안 뒤집힌다
#    ③ 누르는 그 순간 게임에 반영된다 (따로 적용을 안 눌러도)
#    ④ 반영된 조준이 판을 넘겨도 남는다 — _start_leg 가 든 동전를
#       다시 읽으므로, 값만 박으면 다음 판에서 조용히 std 로 풀린다
#    ⑤ 여덟 방식을 차례로 다 고를 수 있다
# ══════════════════════════════════════════════════════════

var fails := 0


func _say(ok: bool, name: String, detail := "") -> void:
	print("  %s %-36s %s" % ["OK  " if ok else "실패", name, detail])
	if not ok:
		fails += 1


func _initialize() -> void:
	Save.path = "user://_dev_probe.cfg"
	Save.wipe()
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
	g._new_run()
	g._swap_skip()
	g._open_stage()
	g._swap_skip()
	Dev.on = true
	Dev.page = 2

	print("\n── 칸 자리 ───────────────────────────────")
	_geometry(g)
	print("\n── 조준 ──────────────────────────────────")
	_aim(g)
	print("\n── 계산 ──────────────────────────────────")
	_score(g)

	print("\n%s" % ("실패 %d건" % fails if fails > 0 else "개발자 판 전부 통과"))
	quit(mini(fails, 125))


func _find(g: Node, label: String) -> int:
	var rows: Array = Dev._rows(g)
	for i in rows.size():
		if String(rows[i].get("n1", "")) == label:
			return i
	return -1


# ── ① 그려지는 자리와 눌리는 자리 ────────────────────────
func _geometry(g: Node) -> void:
	var bad := []
	for pg in Dev.PAGES.size():
		Dev.page = pg
		var rows: Array = Dev._rows(g)
		for i in rows.size():
			if String(rows[i].get("t", "")) != "list":
				continue
			var r: Rect2 = Dev._row(i)
			var la: Rect2 = Dev._arrow(r, false)
			var ra: Rect2 = Dev._arrow(r, true)
			var vb: Rect2 = Dev._val_box(r)
			var who := "%s쪽 %s" % [pg, rows[i].get("n1", "")]
			if not r.encloses(la) or not r.encloses(ra) or not r.encloses(vb):
				bad.append(who + "(줄 밖)")
			if la.intersects(vb) or ra.intersects(vb) or la.intersects(ra):
				bad.append(who + "(겹침)")
			if la.position.x >= ra.position.x:
				bad.append(who + "(좌우 뒤바뀜)")
	Dev.page = 2
	_say(bad.is_empty(), "화살표·값 칸이 줄 안에서 안 겹친다", "어긋난 줄 " + str(bad))


# ── ②③④⑤ 조준 ─────────────────────────────────────────
func _aim(g: Node) -> void:
	var i := _find(g, "조준 방식")
	if i < 0:
		_say(false, "판·조준 쪽에 조준 줄이 있다")
		return
	var r: Rect2 = Dev._row(i)
	var la: Rect2 = Dev._arrow(r, false)
	var ra: Rect2 = Dev._arrow(r, true)
	Dev.pick["aim"] = 0
	Dev.click(g, ra.get_center())            # 처음부터 한 칸 앞으로
	var first := String(g.aim_mode)
	_say(first == String(GameData.AIM_MODES[1]),
			"▶ 를 누르면 그 자리에서 다음 방식이 된다",
			"기대 %s · 실제 %s" % [GameData.AIM_MODES[1], first])

	Dev.click(g, la.get_center())            # 다시 뒤로
	_say(g.aim_mode == String(GameData.AIM_MODES[0]),
			"◀ 는 뒤로 간다 (방향이 안 뒤집힌다)",
			"기대 %s · 실제 %s" % [GameData.AIM_MODES[0], g.aim_mode])

	# 여덟을 차례로 다 지나 제자리로 돌아온다
	var seen := {}
	for k in GameData.AIM_MODES.size():
		Dev.click(g, ra.get_center())
		seen[String(g.aim_mode)] = true
	_say(seen.size() == GameData.AIM_MODES.size() and g.aim_mode == "std",
			"여덟 방식을 차례로 다 고를 수 있다",
			"지나온 방식 %d · 한 바퀴 뒤 %s" % [seen.size(), g.aim_mode])

	# 판을 넘겨도 남는다 — 이것이 값만 박으면 안 되는 자리다
	Dev.click(g, ra.get_center())
	var want := String(g.aim_mode)
	g._start_leg()
	_say(g.aim_mode == want, "고른 조준이 판을 넘겨도 남는다",
			"고른 %s · 판 넘긴 뒤 %s" % [want, g.aim_mode])
	_say(g._aim_from_items() == want, "동전가 그 방식을 쥐고 있다",
			g._aim_from_items())

	# 겹쳐 고르면 앞엣것이 남지 않는다 — 조준 동전는 한 장뿐이어야 한다
	Dev.click(g, ra.get_center())
	Dev.click(g, ra.get_center())
	var held := 0
	for it in g.owned:
		if String(it.get("aim", "")) != "":
			held += 1
	_say(held <= 1, "조준 동전가 겹쳐 쌓이지 않는다", "쥔 장 %d" % held)
	_say(g.owned.size() <= GameData.max_items(), "동전 슬롯이 안 넘친다",
			"%d / %d" % [g.owned.size(), GameData.max_items()])

	# std 로 돌아오면 동전도 없어진다
	Dev.pick["aim"] = 0
	Dev.click(g, Dev._val_box(r).get_center())
	var left := 0
	for it in g.owned:
		if String(it.get("aim", "")) != "":
			left += 1
	_say(g.aim_mode == "std" and left == 0, "기본으로 돌리면 동전도 떨어진다",
			"방식 %s · 남은 조준 동전 %d" % [g.aim_mode, left])


func _score(g: Node) -> void:
	var i := _find(g, "계산 방식")
	if i < 0:
		_say(false, "판·조준 쪽에 계산 줄이 있다")
		return
	var ra: Rect2 = Dev._arrow(Dev._row(i), true)
	Dev.pick["score"] = 0
	var seen := {}
	for k in GameData.SCORE_MODES.size():
		Dev.click(g, ra.get_center())
		seen[String(g.score_mode)] = true
	_say(seen.size() == GameData.SCORE_MODES.size(),
			"계산 방식도 눌러서 다 고를 수 있다",
			"지나온 방식 %d / %d" % [seen.size(), GameData.SCORE_MODES.size()])
