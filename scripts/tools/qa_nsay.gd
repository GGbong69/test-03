extends SceneTree
# 상인의 말(2026-10-11 · game.gd NSAY · data/npc_say.csv) — 못 박는 것:
#   ① 표 — 갈래(when)마다 말이 있다 · 귀띔 글의 {열쇠}가 다 채워진다(수가 표 값 그대로) · 검증기 오류 없음
#   ② 말상자가 두 줄 안 · 동전 슬롯 밑 이름 줄(y 61)을 안 덮고 펠트 안쪽(y 150)까지만 · 왼쪽 「사탕·사진」 글을 비킨다
#   ③ 귀띔 — 상점에 들어서면 delay 뒤 한 번 선다 · 다 나오고 hold 뒤 진다 · 그 방문에는 다시 안 선다
#   ④ 귀띔은 튜토리얼 런 · 팩을 뜯는 동안 · 튜토리얼 말상자가 선 동안 안 선다 · 서 있다가 팩을 뜯으면 진다
#   ⑤ 같은 갈래의 말은 표를 한 바퀴 돌 때까지 안 되풀이한다
#   ⑥ 말상자를 누르면 — 나오는 중이면 다 보여 주고, 다 나왔으면 걷는다 · 밖을 누르면 안 삼킨다
#   ⑦ 대사 — 몸을 누르면 poke · 손을 누르면 hand · 건네면 give 말이 선다 · 막 선 말(min_gap)은 안 덮는다
#   ⑧ 쉬는 초 — 산 뒤 cool 초 동안은 다시 buy 말이 안 선다
#   ⑨ 상인이 없는 화면으로 가면 말상자가 걷힌다
#   ⑩ 전역 난수를 안 건드린다(시드를 박고 도는 검사의 뽑기가 안 밀린다)
#   ⑪ 개발자 모드 「상인 귀띔」 줄 · 갈래
#   godot --headless --path . --script scripts/tools/qa_nsay.gd
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
var g = null
var ok := 0
var bad := 0
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_qa_nsay_g.cfg"
	Save.path = "user://_qa_nsay.cfg"
	Save.prof_fmt = "user://_qa_nsay_%d.cfg"
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
		g._nsay_tick(1.0 / 60.0)


func _shop() -> void:
	g.state = g.S.SHOP
	g.nsay_was = false
	g.nsay_row = {}
	g.nsay_out = 0.0
	g.nsay_cool = {}


func _run() -> void:
	# ①
	var whens: Array = GameData.NPC_SAY_WHEN
	var empty := []
	for w in whens:
		if GameData.npc_say(w).is_empty():
			empty.append(w)
	_ok("① 갈래마다 말이 있다", empty.is_empty(), str(empty))
	var left := []
	for r in GameData.npc_say("tip"):
		var t: String = GameData.npc_say_text(r)
		if t.contains("{"):
			left.append(t)
	_ok("① 귀띔 글의 {열쇠}가 다 채워진다", left.is_empty(), str(left))
	var ti: Dictionary = {}
	for r in GameData.npc_say("tip"):
		if String(r.id) == "tip_interest":
			ti = r
	_ok("① 수가 표 값 그대로(이자)", not ti.is_empty() and GameData.npc_say_text(ti).contains(
			str(GameData.tune_i("interest_per"))) and GameData.npc_say_text(ti).contains(
			"+" + str(GameData.tune_i("interest_max"))), GameData.npc_say_text(ti) if not ti.is_empty() else "")
	var errs := []
	for e in GameData._errs:
		if String(e).begins_with("npc_say"):
			errs.append(e)
	_ok("① 검증기 오류 없음", errs.is_empty(), str(errs))

	# 상점을 세운다
	g._new_run()
	g.tut_run = false
	g._open_shop()
	g._swap_skip()
	if g._tutor_live():
		g._tutor_close()
	g.tutor_q.clear()
	g.wipe_t = -1.0
	g.boost_t = -1.0

	# ②
	var lines_bad := []
	var lap := false
	for w in whens:
		for r in GameData.npc_say(w):
			g.nsay_row = r
			g.nsay_txt = GameData.npc_say_text(r)
			var lay: Array = g._nsay_layout()
			var box: Rect2 = lay[0]
			if (lay[1] as PackedStringArray).size() > 2:
				lines_bad.append(String(r.id))
			var plate_top: float = box.position.y - float(g.TUTOR.plate_h) * 0.5
			if plate_top < 61.0 or box.end.y > 150.0 or box.position.x + 12.0 < 156.0:
				lap = true
				lines_bad.append("%s %s" % [r.id, box])
	_ok("② 말상자 두 줄 안 · 이름 줄 밑 · 펠트 안쪽까지 · 왼쪽 글 비킴", lines_bad.is_empty() and not lap,
			str(lines_bad))
	g.nsay_row = {}

	# ③
	_shop()
	g.nsay_rng.seed = 7
	var C: Dictionary = g.NSAY
	var saw := false
	var ended := false
	var again := false
	for i in 1200:              # 20초
		g._nsay_tick(1.0 / 60.0)
		if not g.nsay_row.is_empty() and String(g.nsay_row.when) == "tip":
			if ended:
				again = true
			saw = true
		elif saw:
			ended = true
	#  chance 0.6 이라 안 설 수 있다 — 그 때는 시드를 바꿔 다시 든다
	var tries := 0
	while not saw and tries < 20:
		tries += 1
		_shop()
		g.nsay_was = false
		g.state = g.S.LEG
		g._nsay_tick(0.0)
		g.state = g.S.SHOP
		g.nsay_rng.seed = 100 + tries
		for i in 1200:
			g._nsay_tick(1.0 / 60.0)
			if not g.nsay_row.is_empty():
				saw = true
			elif saw:
				ended = true
	_ok("③ 상점에서 귀띔이 선다", saw)
	_ok("③ 다 나오고 hold 뒤 진다", ended)
	_ok("③ 그 방문에는 다시 안 선다", not again)

	# ④
	_shop()
	g.tut_run = true
	g.nsay_wait = 0.1
	_tick(1.0)
	_ok("④ 튜토리얼 런 — 귀띔 없음", g.nsay_row.is_empty())
	g.tut_run = false
	g.boost_t = 0.0
	g.nsay_wait = 0.1
	_tick(1.0)
	_ok("④ 팩을 뜯는 동안 — 귀띔 없음", g.nsay_row.is_empty())
	g.boost_t = -1.0
	g._nsay("tip", true)
	_tick(0.2)
	g.boost_t = 0.0
	_tick(0.5)
	_ok("④ 서 있다가 팩을 뜯으면 진다", g.nsay_row.is_empty())
	g.boost_t = -1.0
	g.tutor_q = ["u_leg"]
	_ok("④ 튜토리얼 말상자가 기다리면 — 안 선다", not g._nsay("tip", true))
	g.tutor_q.clear()

	# ⑤
	_shop()
	var n_tip: int = GameData.npc_say("tip").size()
	var seen := {}
	var dup := false
	g.nsay_q = {}
	for i in n_tip:
		g.nsay_row = {}
		g._nsay("tip", true)
		var id := String(g.nsay_row.get("id", ""))
		if seen.has(id):
			dup = true
		seen[id] = true
	_ok("⑤ 한 바퀴 동안 안 되풀이", not dup and seen.size() == n_tip, "%d / %d" % [seen.size(), n_tip])

	# ⑥
	_shop()
	g._nsay("tip", true)
	var bx: Rect2 = g._nsay_layout()[0]
	_ok("⑥ 밖을 누르면 안 삼킨다", not g._nsay_click(Vector2(5.0, 340.0)))
	_ok("⑥ 나오는 중에 누르면 다 보여 준다", g._nsay_click(bx.get_center())
			and g._nsay_shown() == g.nsay_txt.length() and g.nsay_out == 0.0)
	_ok("⑥ 다 나왔으면 걷는다", g._nsay_click(bx.get_center()) and g.nsay_out > 0.0)
	_tick(0.5)

	# ⑦
	_shop()
	_ok("⑦ 몸 → poke 말", g._nsay("poke") and String(g.nsay_row.when) == "poke")
	_ok("⑦ 막 선 말은 안 덮는다(min_gap)", not g._nsay("hand"))
	g.nsay_t = float(C.min_gap) + 0.01
	_ok("⑦ min_gap 지나면 손 → hand 말", g._nsay("hand") and String(g.nsay_row.when) == "hand")
	g.nsay_t = float(C.min_gap) + 0.01
	_ok("⑦ 건넴 → give 말", g._nsay("give") and String(g.nsay_row.when) == "give")
	var src: String = FileAccess.get_file_as_string("res://scripts/game.gd")
	_ok("⑦ 누름 · 건넴 · 술병 · 삼 · 팖에 고리가 걸렸다",
			src.contains("_npc_react(\"빼기\", h)\n\t\t_nsay(\"hand\")") and src.contains("npc_poke += 1\n\t_nsay(\"poke\")")
			and src.contains("give_t = 0.0\n\t_nsay(\"give\")") and src.contains("_nsay(\"btl\")")
			and src.contains("_nsay(\"buy\")") and src.contains("_bump(\"sold\")\n\t_nsay(\"sell\")"))

	# ⑧
	_shop()
	g.nsay_rng.seed = 3
	var got := false
	for i in 50:
		g.nsay_row = {}
		if g._nsay("buy"):
			got = true
			break
	_ok("⑧ buy 말이 선다(몫 안에서)", got)
	g.nsay_row = {}
	_ok("⑧ 쉬는 초 동안은 다시 안 선다", not g._nsay("buy") and float(g.nsay_cool.get("buy", 0.0)) > 0.0)

	# ⑨
	_shop()
	g._nsay("poke")
	g.state = g.S.PICK
	g._nsay_tick(1.0 / 60.0)
	_ok("⑨ 상인이 없는 화면 — 걷힌다", g.nsay_row.is_empty())

	# ⑩
	seed(4242)
	var r1 := randf()
	seed(4242)
	_shop()
	g.nsay_rng.seed = 0
	for i in 600:
		g._nsay_tick(1.0 / 60.0)
	g._nsay("poke")
	g.nsay_t = 1.0
	g._nsay("sell")
	var r2 := randf()
	_ok("⑩ 전역 난수를 안 건드린다", r1 == r2)

	# ⑪
	var dsrc: String = FileAccess.get_file_as_string("res://scripts/dev.gd")
	_ok("⑪ 개발자 줄 · 갈래", dsrc.contains("\"a\": \"nsay\"") and dsrc.contains("g._nsay(\"tip\", true)"))
