extends SceneTree
# 배움 — 처음 만난 것을 한 번만 가르치는가. 프로필마다 각각인가.
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
	print("  %s %-40s %s" % ["통과" if cond else "실패", nm, note])

func _show(n: int) -> void:
	for k in n:
		g._tutor_tick(1.0 / 60.0)

func _drain() -> void:
	# 줄에 선 것을 다 흘려보낸다
	for k in 3000:
		g._tutor_tick(1.0 / 60.0)
		if g.tutor_id == "" and g.tutor_q.is_empty():
			return

func _run() -> void:
	# ① 표가 있고 문구가 다 찼는가 — 검증기가 이미 보지만 여기서도 못 박는다
	var rows: Array = GameData.tutor()
	_ok("표가 비지 않았다", rows.size() >= 8, "%d줄" % rows.size())
	var empty := ""
	for r in rows:
		if String(r.get("text", "")).strip_edges() == "":
			empty = String(r.get("id", ""))
	_ok("빈 문구가 없다", empty == "", empty)
	_ok("없는 id 는 빈 사전", GameData.tutor_of("없는것").is_empty(), "")
	#  **표에만 있고 아무도 안 부르는 줄**이 제일 흔한 실패다. 검증기는
	#  표 안쪽만 보므로 여기서 게임 원문을 읽어 부르는 자리를 찾는다.
	var src := ""
	var fh := FileAccess.open("res://scripts/game.gd", FileAccess.READ)
	if fh != null:
		src = fh.get_as_text()
		fh.close()
	_ok("게임 원문을 읽었다", src.length() > 1000, "%d자" % src.length())
	var dead := PackedStringArray()
	for r in rows:
		var id: String = String(r.get("id", ""))
		if not src.contains('_tutor("%s")' % id):
			dead.append(id)
	_ok("표의 모든 줄을 누군가 부른다", dead.is_empty(),
			"안 부르는 것: %s" % ", ".join(dead))

	# ② 처음이면 뜨고, 두 번째부터는 안 뜬다
	Save.wipe()
	g._new_run()
	#  _new_run 이 판 고르기를 여는 길이라 u_leg·u_skip 이 이미 줄에 선다.
	#  그것부터 흘려보내야 이 검사가 **내가 부른 줄**을 재게 된다.
	_drain()
	g._tutor("u_shop")
	_ok("처음 만나면 줄에 선다", g.tutor_q.size() == 1, "%d" % g.tutor_q.size())
	g._tutor("u_shop")
	_ok("같은 것을 또 불러도 한 번", g.tutor_q.size() == 1, "%d" % g.tutor_q.size())
	_show(2)
	_ok("띠에 떴다", g.tutor_id == "u_shop", g.tutor_id)
	_ok("문구가 나온다", g._tutor_text() != "", g._tutor_text())
	_drain()
	_ok("시간이 지나면 진다", g.tutor_id == "" and not g._tutor_live(), "")
	g._tutor("u_shop")
	_ok("배운 것은 다시 안 뜬다", g.tutor_q.is_empty(), "%d" % g.tutor_q.size())

	# ③ 저장에 남는다
	_ok("배운 것으로 적혔다", Save.taught("u_shop"), "")
	_ok("안 배운 것은 안 적혔다", not Save.taught("u_stage"), "")

	# ④ 봉투 — 들고 머물고 진다. 양끝이 0 이라야 띠가 안 튄다
	g._tutor("u_stage")
	_show(1)
	g.tutor_t = 0.0
	_ok("들머리에서 0", g._tutor_a() < 0.001, "%.3f" % g._tutor_a())
	g.tutor_t = float(g.TUTOR.fade) + float(g.TUTOR.hold) * 0.5
	_ok("한가운데는 1", g._tutor_a() > 0.999, "%.3f" % g._tutor_a())
	g.tutor_t = float(g.TUTOR.fade) * 2.0 + float(g.TUTOR.hold)
	_ok("날머리에서 0", g._tutor_a() < 0.001, "%.3f" % g._tutor_a())
	_drain()

	# ⑤ 둘이 한꺼번에 와도 줄을 선다 — 겹쳐 그리면 둘 다 못 읽는다
	g._tutor("u_score")
	g._tutor("u_clear")
	_ok("둘이 줄에 선다", g.tutor_q.size() == 2, "%d" % g.tutor_q.size())
	_show(2)
	_ok("한 번에 하나만 뜬다", g.tutor_id == "u_score" and g.tutor_q.size() == 1,
			"%s · 줄 %d" % [g.tutor_id, g.tutor_q.size()])
	_drain()
	_ok("다음 것도 나왔다", Save.taught("u_clear"), "")

	# ⑥ 하단 안내가 비킨다 — 같은 자리를 쓴다
	g._tutor("u_rack")
	_show(2)
	_ok("띠가 뜨면 하단 안내가 비킨다", g._tutor_live(), "")
	_drain()

	# ⑦ 프로필마다 각각이다
	Save.path = "user://_qa_tutor2.cfg"
	Save.wipe()
	_ok("새 프로필은 처음부터", not Save.taught("u_shop"), "")
	Save.path = "user://_qa_tutor.cfg"
	Save.boot()
	_ok("옛 프로필은 그대로", Save.taught("u_shop"), "")

	# ⑧ 다시 배우게 할 수 있다
	Save.forget_all()
	_ok("잊으면 처음으로", not Save.taught("u_shop"), "")

	# ⑨ 진짜 길을 밟는다 — 상점을 열면 상점 줄이 선다
	Save.wipe()
	g._new_run()
	g.state = g.S.SHOP
	g.gold = 40
	g.leg_no = 2
	g._open_shop()
	_ok("상점을 열면 가르친다", Save.taught("u_shop"), "")
	_ok("첫 상점에서는 리롤·건네기를 안 한다",
			not Save.taught("u_reroll") and not Save.taught("u_give"), "")
	_drain()
	g._open_shop()
	_ok("두 번째 상점에서 리롤·건네기",
			Save.taught("u_reroll") and Save.taught("u_give"), "")
	#  런을 새로 시작하면 줄과 상점 셈이 비어야 한다
	g._tutor("u_cons")
	g._new_run()
	_ok("새 런은 줄이 빈다",
			g.tutor_q.is_empty() and g.tutor_id == "" and g.shop_seen == 0,
			"줄 %d · 상점 %d" % [g.tutor_q.size(), g.shop_seen])
