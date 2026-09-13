extends SceneTree

# 구성 VIII — 「던진 다트 궤적대로 한 번 더 던진다」. 기획서 s33 신설.
# 판 플레이 중 · 단 첫 다트 착탄 이후. 탄창을 안 쓰는 덤 한 발이다.
#
#   godot --path . --headless --script scripts/tools/qa_again.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.path = "user://_qa_again.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-34s %s" % ["통과" if c else "실패", n, d])


func _hold() -> void:
	for c in GameData.consumables():
		if String(c.id) == "c_again":
			g.cons = [c.duplicate()]
			return


# 던진 발이 꽂히고 정산 큐가 비어 판 고르기로 돌아올 때까지 돌린다.
func _settle() -> void:
	for i in 1200:
		g._process(1.0 / 60.0)
		if g.state == g.S.PICK or g.state == g.S.CLEAR 				or g.state == g.S.OVER:
			return


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	g._new_run()
	g._swap_skip()
	for i in 20:
		g._process(1.0 / 60.0)

	print("\n구성 VIII 검사\n")

	# ① 표가 기획서대로인가
	var c := {}
	for x in GameData.consumables():
		if String(x.id) == "c_again": c = x
	_ok("표에 있다 · 15G · play", not c.is_empty()
			and int(c.cost) == 15 and String(c.get("use_at", "")) == "play",
			"%s %dG %s" % [String(c.get("n", "?")), int(c.get("cost", 0)),
					String(c.get("use_at", ""))])

	# ② 첫 다트 전에는 거절
	g._start_leg()
	g.state = g.S.PICK
	_hold()
	_ok("판이 막 서면 궤적이 없다", g.again_aim.x < 0.0, str(g.again_aim))
	g._cons_use(0)
	_ok("첫 다트 전에는 거절", g.cons.size() == 1 and g.state == g.S.PICK,
			"%s" % g.pay_msg)

	# ③ 한 발 던진다 — 조준을 세우고 CONFIRM 을 넘긴다
	g.state = g.S.CONFIRM
	g.confirm_t = 99.0
	g.aim = g.BC + Vector2(0.0, -30.0)
	g._process(1.0 / 60.0)
	_ok("던지면 FLY 로 간다", g.state == g.S.FLY, "state %d" % g.state)
	_ok("궤적이 남는다", g.again_aim.x >= 0.0, str(g.again_aim))
	var shot: Vector2 = g.again_aim
	# 날아가 꽂히고 **정산까지** 끝난다. FLY 를 벗어나는 것만 보면
	# 아직 RESOLVE 라 총점이 안 올라가 있다.
	_settle()
	var darts0: int = g.darts_left
	var left0: int = g.remaining.size()
	var total0: int = g.total

	# ④ 쓰면 탄창을 안 건드리고 같은 자리로 한 발 더
	g.state = g.S.PICK
	_hold()
	g._cons_use(0)
	_ok("쓰면 FLY 로 간다", g.state == g.S.FLY, "state %d" % g.state)
	_ok("같은 자리로 던진다", g.aim.is_equal_approx(shot),
			"%s vs %s" % [str(g.aim), str(shot)])
	_ok("탄창이 안 줄어든다", g.darts_left == darts0
			and g.remaining.size() == left0,
			"%d→%d · %d→%d" % [darts0, g.darts_left, left0, g.remaining.size()])
	_ok("손에서 없어진다", g.cons.is_empty(), "손 %d장" % g.cons.size())
	_settle()
	_ok("점수가 또 난다", g.total > total0, "%d → %d" % [total0, g.total])

	# ⑤ 새 판이 서면 궤적이 지워진다
	g._start_leg()
	_ok("새 판이면 궤적이 없다", g.again_aim.x < 0.0, str(g.again_aim))

	print("\n통과 %d · 실패 %d" % [okn, fail])
	quit(mini(fail, 125))
