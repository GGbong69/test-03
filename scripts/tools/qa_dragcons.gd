extends SceneTree

# 사탕·사진을 끌어다 쓰기. 2026-09-14 사용자 지시 —
#   "아이템을 드레그 앤 드랍으로 가운데로 끌고오면 사용되도록 만들어줘"
#
#   godot --path . --headless --script scripts/tools/qa_dragcons.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.path = "user://_qa_drag.cfg"
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


#  손짓 하나 — 칸에서 집어 to 로 끌고 가 놓는다.
func _drag(slot: int, to: Vector2) -> void:
	var from: Vector2 = g._cons_rect(slot).get_center()
	g._hand_press(from)
	#  한 번에 끌지 않는다. 실제 손처럼 몇 걸음 나눠 움직여야 ARMED → CARRY
	#  문턱(HAND.slip)을 지나는 길이 자와 게임에서 같다.
	for k in range(1, 9):
		g._hand_motion(from.lerp(to, float(k) / 8.0))
	g._hand_release(to)


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	print("\n끌어다 쓰기 검사 — 가운데에 놓으면 쓴다\n")

	var candy: Dictionary = GameData.candies()[0]
	var fix: Dictionary = GameData.fixture_of("v_cash")

	# ① 가운데 자리가 판 한가운데다
	_ok("놓는 자리가 판 한가운데", g._use_spot().is_equal_approx(g.BC),
			"%s (BC %s)" % [g._use_spot(), g.BC])
	_ok("자리 안은 맞고 밖은 틀리다",
			g._use_hit(g.BC) and not g._use_hit(g.BC + Vector2(90.0, 0.0)),
			"반지름 %.0f" % g.USE.r)

	# ② 가운데로 끌면 쓴다
	g.leg_no = 2
	g._start_leg()
	g.cons = [candy.duplicate()]
	var lv0: int = int(g.track_lv.get(candy.track, 0))
	_drag(0, g.BC)
	_ok("가운데에 놓으면 쓴다", g.cons.is_empty(),
			"손에 %d장 · 트랙 %d → %d"
			% [g.cons.size(), lv0, int(g.track_lv.get(candy.track, 0))])
	_ok("효과가 실제로 난다",
			int(g.track_lv.get(candy.track, 0)) == lv0 + 1,
			"Lv %d" % int(g.track_lv.get(candy.track, 0)))

	# ③ 딴 데 놓으면 안 쓴다 — 칸으로 돌아간다
	g.cons = [candy.duplicate()]
	var lv1: int = int(g.track_lv.get(candy.track, 0))
	_drag(0, Vector2(60.0, 330.0))
	_ok("딴 데 놓으면 안 쓴다", g.cons.size() == 1,
			"손에 %d장" % g.cons.size())
	_ok("딴 데 놓으면 효과도 없다",
			int(g.track_lv.get(candy.track, 0)) == lv1, "Lv 그대로")

	# ④ 누르고 떼는 옛 길이 그대로 산다
	g.cons = [candy.duplicate()]
	var at: Vector2 = g._cons_rect(0).get_center()
	g._hand_press(at)
	g._hand_release(at)
	_ok("눌렀다 떼는 길이 그대로", g.cons.is_empty(),
			"손에 %d장" % g.cons.size())

	# ⑤ 여기서 못 쓰는 것은 끌어도 안 된다 — 놓기 **전에** 이유가 선다
	g.state = g.S.SHOP
	g.cons = [fix.duplicate()]
	var play_only: Dictionary = {}
	for f in GameData.fixtures():
		if String(f.get("use_at", "any")) == "play":
			play_only = f
	g.cons = [play_only.duplicate()]
	var why: String = String(g._cons_block(play_only))
	_ok("상점에서 못 쓰는 사진은 이유가 있다", why != "", "사유 '%s'" % why)
	_drag(0, g.BC)
	_ok("못 쓰는 것은 끌어도 안 쓰인다", g.cons.size() == 1,
			"손에 %d장" % g.cons.size())

	# ⑥ 빈 칸을 집으려 해도 아무 일 없다
	g.cons = []
	g._hand_press(g._cons_rect(0).get_center())
	_ok("빈 칸은 안 집힌다", g.hand_st == g.H.NONE,
			"hand_st %d" % g.hand_st)

	print("\n%s\n" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	quit(0 if fail == 0 else 1)
