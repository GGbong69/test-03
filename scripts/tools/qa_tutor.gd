extends SceneTree
# 배움 — 걸음·조명·느린 시간. 프로필마다 각각인가.
#   godot --headless --path . --script scripts/tools/qa_tutor.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var ok := 0
var bad := 0

func _initialize() -> void:
	Save.gpath = "user://_qa_tutor_g.cfg"
	Save.path = "user://_qa_tutor.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	_run()
	print("통과 %d · 실패 %d" % [ok, bad])
	quit(1 if bad > 0 else 0)

func _ok(nm: String, cond: bool, note := "") -> void:
	if cond: ok += 1
	else: bad += 1
	print("  %s %-42s %s" % ["통과" if cond else "실패", nm, note])

func _tick(n: int) -> void:
	for k in n:
		g._tutor_tick(1.0 / 60.0)

# 걸음을 끝까지 눌러 넘긴다
func _clickthru() -> int:
	var hits := 0
	for k in 900:
		if not g._tutor_live() and g.tutor_q.is_empty():
			break
		_tick(1)
		if g._tutor_live() and g.tutor_t >= float(g.TUTOR.lead):
			if g._tutor_click():
				hits += 1
	return hits

func _reset() -> void:
	g.tutor_q.clear()
	g.tutor_id = ""
	g.tutor_i = 0
	g.tutor_t = 0.0
	g.tutor_out = 0.0

func _run() -> void:
	var rows: Array = GameData.tutor()
	_ok("표가 비지 않았다", rows.size() >= 12, "%d걸음" % rows.size())

	# ① 표에만 있고 아무도 안 부르는 갈래가 없는가
	var src := ""
	var fh := FileAccess.open("res://scripts/game.gd", FileAccess.READ)
	if fh != null:
		src = fh.get_as_text()
		fh.close()
	var ids := {}
	for r in rows:
		ids[String(r.get("id", ""))] = true
	var dead := PackedStringArray()
	for id in ids:
		if not src.contains('_tutor("%s")' % id):
			dead.append(String(id))
	_ok("표의 모든 갈래를 누군가 부른다", dead.is_empty(),
			"안 부르는 것: %s" % ", ".join(dead))

	# ② 과녁이 전부 진짜 사각을 낸다 — 이름만 맞고 빈 사각이면 안 밝힌다
	g._new_run()          # 제약 카드는 런이 서 있어야 깔린다
	g.state = g.S.SHOP
	g.gold = 40
	g.leg_no = 2
	g._open_shop()
	g.drop_fast = true
	for k in 200:
		g._drop_step(1.0 / 60.0)
	var blank := PackedStringArray()
	for mk in GameData.TUTOR_MARKS:
		if String(mk) == "" or String(mk) == "stage":
			continue
		var rr: Rect2 = g._mark_rect(String(mk))
		if rr.size.x < 2.0 or rr.size.y < 2.0:
			blank.append(String(mk))
	_ok("과녁이 다 사각을 낸다", blank.is_empty(),
			"빈 것: %s" % ", ".join(blank))
	#  제약 카드는 상점에 없다 — 그 화면에서 따로 잰다. 여기서 같이 재면
	#  "화면에 없으면 빈 사각" 이라는 올바른 동작이 실패로 잡힌다.
	#  제약은 **보스 판에만** 깔린다(_open_stage 의 첫 갈래). 보통 판에서
	#  부르면 그대로 던지러 가 버려서 카드가 없다.
	for lv in range(1, 40):
		if GameData.is_boss(lv):
			g.leg_no = lv
			break
	g._open_stage()
	var sr: Rect2 = g._mark_rect("stage")
	_ok("제약 과녁은 제약 화면에서 선다", sr.size.x > 2.0 and sr.size.y > 2.0,
			"%.0fx%.0f" % [sr.size.x, sr.size.y])
	g.state = g.S.SHOP
	_ok("모르는 과녁은 빈 사각", g._mark_rect("없는것").size.x < 1.0, "")

	# 못 보여 줄 것은 안 가르친다 — 제약을 보통 판에서 말하던 자리다
	Save.wipe()
	_reset()
	g.leg_no = 1
	for lv in range(1, 40):
		if not GameData.is_boss(lv):
			g.leg_no = lv
			break
	g.stage_pick.clear()
	g.state = g.S.PICK
	g._tutor("u_stage")
	_ok("보통 판에서는 제약을 안 가르친다",
			g.tutor_q.is_empty() and not Save.taught("u_stage"),
			"%d판 · 줄 %d" % [g.leg_no, g.tutor_q.size()])
	#  **배운 것으로도 안 적혔어야** 보스 판에서 다시 걸린다
	for lv2 in range(1, 40):
		if GameData.is_boss(lv2):
			g.leg_no = lv2
			break
	g._open_stage()
	_ok("보스 판에서는 가르친다",
			Save.taught("u_stage") and g.state == g.S.STAGE,
			"%d판 · 상태 %d" % [g.leg_no, g.state])
	#  그 자리에서 과녁이 진짜로 선다 — 구멍 없는 어둠만 깔리면 안 된다
	var mr: Rect2 = g._mark_rect("stage")
	_ok("가르칠 때 과녁이 서 있다", mr.size.x > 2.0 and mr.size.y > 2.0,
			"%.0fx%.0f" % [mr.size.x, mr.size.y])
	_reset()
	Save.wipe()


	# ③ 걸음이 차례로 간다
	Save.wipe()
	g._new_run()
	_reset()
	Save.forget_all()
	g._tutor("u_score")
	_tick(2)
	_ok("첫 걸음이 뜬다", g._tutor_live() and g.tutor_i == 0,
			"%s %d" % [g.tutor_id, g.tutor_i])
	var n: int = GameData.tutor_steps("u_score").size()
	_ok("득점은 여러 걸음", n >= 3, "%d걸음" % n)
	_ok("걸음마다 문구가 다르다",
			String((GameData.tutor_steps("u_score")[0] as Dictionary).text)
			!= String((GameData.tutor_steps("u_score")[1] as Dictionary).text), "")
	_ok("뜨자마자 눌러도 안 넘어간다",
			g._tutor_click() and g.tutor_i == 0, "i %d" % g.tutor_i)
	_tick(int(float(g.TUTOR.lead) * 60.0) + 2)
	g._tutor_click()
	_ok("누르면 다음 걸음", g.tutor_i == 1, "i %d" % g.tutor_i)
	_tick(int(float(g.TUTOR.lead) * 60.0) + 2)
	g._tutor_click()
	_tick(int(float(g.TUTOR.lead) * 60.0) + 2)
	g._tutor_click()
	_ok("마지막을 넘기면 닫힌다", not g._tutor_live(), g.tutor_id)
	_tick(60)
	_ok("닫히고 나면 어둠도 진다", g._tutor_a() <= 0.001, "%.3f" % g._tutor_a())

	# ④ 느린 시간 — 설명 중에만, 그리고 안 멈춘다
	_ok("설명이 없으면 배율 1", absf(g._tutor_slow() - 1.0) < 0.001,
			"%.2f" % g._tutor_slow())
	Save.forget_all()
	_reset()
	g._tutor("u_score")
	_tick(60)
	var sl: float = g._tutor_slow()
	_ok("설명 중에는 늦춘다", sl < 0.5, "×%.2f" % sl)
	_ok("늦추되 안 세운다", sl > 0.0, "×%.2f" % sl)
	var slow_min := 9.0
	var slow_id := ""
	for r in rows:
		var v := float(r.get("slow", 1.0))
		if v < slow_min:
			slow_min = v
			slow_id = String(r.get("id", ""))
	_ok("제일 느린 자리가 득점", slow_id == "u_score",
			"%s ×%.2f" % [slow_id, slow_min])

	# ⑤ ESC 로 갈래를 통째로 건너뛴다
	_ok("건너뛰기 전에는 떠 있다", g._tutor_live(), "")
	g._tutor_close()
	_ok("ESC 로 통째로 닫힌다", not g._tutor_live() and g.tutor_q.is_empty(), "")

	# ⑥ 설명 중 클릭은 게임에 안 간다
	Save.forget_all()
	_reset()
	g._tutor("u_shop")
	_tick(int(float(g.TUTOR.lead) * 60.0) + 4)
	_ok("설명 중 클릭은 삼킨다", g._tutor_click(), "")
	g._tutor_close()
	_reset()
	_ok("설명이 없으면 안 삼킨다", not g._tutor_click(), "")

	# ⑦ 말상자가 두 줄 안에 접힌다 — 세 줄이면 버튼 줄을 먹는다
	var wide := ""
	var w: float = float(g.TUTOR.box_w) - float(g.TUTOR.box_pad) * 2.0
	for r in rows:
		var ln: int = g._tutor_wrap(String(r.get("text", "")), w).size()
		if ln > 2:
			wide = "%s %d줄" % [String(r.get("id", "")), ln]
	_ok("모든 문구가 두 줄 안", wide == "", wide)

	# ⑧ 저장은 프로필마다
	Save.wipe()
	_reset()
	_ok("지우면 처음부터", not Save.taught("u_shop"), "")
	g._tutor("u_leg")
	_ok("한 번 부르면 적힌다", Save.taught("u_leg"), "")
	_reset()
	g._tutor("u_leg")
	_ok("배운 갈래는 다시 안 선다", g.tutor_q.is_empty(), "")
	Save.path = "user://_qa_tutor2.cfg"
	Save.wipe()
	_ok("새 프로필은 처음부터", not Save.taught("u_leg"), "")
	Save.path = "user://_qa_tutor.cfg"
	Save.boot()
	_ok("옛 프로필은 그대로", Save.taught("u_leg"), "")

	# ⑨ 진짜 길 — 상점을 열면 상점 갈래가 서고 눌러서 끝까지 넘어간다
	Save.wipe()
	g._new_run()
	_reset()
	Save.forget_all()
	g.state = g.S.SHOP
	g._open_shop()
	_ok("상점을 열면 가르친다", Save.taught("u_shop"), "")
	_ok("첫 상점에서는 리롤·건네기를 안 한다",
			not Save.taught("u_reroll") and not Save.taught("u_give"), "")
	var hits := _clickthru()
	_ok("눌러서 끝까지 넘어간다", hits >= 3 and not g._tutor_live(),
			"%d번 눌렀다" % hits)
	g._open_shop()
	_ok("두 번째 상점에서 리롤·건네기",
			Save.taught("u_reroll") and Save.taught("u_give"), "")
