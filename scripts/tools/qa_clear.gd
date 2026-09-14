extends SceneTree

# 정산 연출 검사. docs/UI개편_설계.md C12·C13.
#   줄이 차례로 들고 · 합계선은 그 뒤에 · 총액이 굴러 오르고 ·
#   누르면 즉시 끝나고 · 모션을 끄면 곧장 최종값
#
#   godot --path . --headless --script scripts/tools/qa_clear.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.path = "user://_qa_clear.cfg"
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


func _enter() -> void:
	g.state = g.S.TITLE
	g._new_run()
	g._click(g._leg_go().get_center())
	for k in 60:
		g._process(1.0 / 60.0)
	g.target = 1
	g.state = g.S.CONFIRM
	g.confirm_t = 99.0
	g.aim = g.BC
	for k in 600:
		g._process(1.0 / 60.0)
		if g.state == g.S.CLEAR:
			return


func _run() -> void:
	for i in 20:
		g._process(1.0 / 60.0)
	print("\n정산 연출 검사\n")

	_enter()
	_ok("정산으로 들어왔다", g.state == g.S.CLEAR, "state %d" % g.state)
	_ok("내역이 섰다", (g.clear_gold_detail as Array).size() >= 3,
			"%d줄" % (g.clear_gold_detail as Array).size())
	_ok("첫 줄이 판 이름이 아니다",
			String(g.clear_gold_detail[0].n) == "클리어 보상",
			"'%s' — 판 이름은 제목이 이미 말한다" % g.clear_gold_detail[0].n)

	# ① 판 위 팝업은 판 위에서 끝난다
	_ok("판 위 팝업을 안 끌고 온다", (g.pops as Array).is_empty(),
			"%d개" % (g.pops as Array).size())

	# ② 총액이 0 에서 오른다
	g.clear_t = 0.0
	var at0: int = g._clear_roll()
	for k in 8:
		g._process(1.0 / 60.0)
	var at1: int = g._clear_roll()
	for k in 200:
		g._process(1.0 / 60.0)
	var at2: int = g._clear_roll()
	_ok("총액이 0 에서 시작한다", at0 == 0, "%d" % at0)
	_ok("총액이 굴러 오른다", at2 > at1 or at1 > at0,
			"%d → %d → %d (골드 %d)" % [at0, at1, at2, g.gold])
	_ok("다 구르면 제값", at2 == g.gold, "%d / %d" % [at2, g.gold])
	_ok("다 구르면 끝났다고 말한다", g._clear_done(), "")

	# ③ 누르면 즉시 끝난다 — 연출이 입력을 삼키면 안 된다
	g.clear_t = 0.0
	g._process(1.0 / 60.0)
	_ok("구르는 중에는 안 끝났다", not g._clear_done(),
			"보이는 값 %d / %d" % [g._clear_roll(), g.gold])
	var st0: int = g.state
	g._click(Vector2(320.0, 300.0))
	_ok("누르면 굴림만 끝내고 화면은 그대로",
			g.state == st0 and g._clear_done(),
			"state %d · 보이는 값 %d" % [g.state, g._clear_roll()])

	# ④ 모션을 끄면 곧장 최종값
	g.motion_off = true
	g.clear_t = 0.0
	_ok("모션 끄면 곧장 제값", g._clear_roll() == g.gold and g._clear_done(),
			"%d / %d" % [g._clear_roll(), g.gold])
	g.motion_off = false

	# ⑤ 표가 화면 한가운데 축에 선다
	var mid: float = float(g.CLR.x) + float(g.CLR.w) * 0.5
	_ok("표가 화면 한가운데 축", is_equal_approx(mid, g.VIEW.x * 0.5),
			"표 중심 %.0f · 화면 중심 %.0f" % [mid, g.VIEW.x * 0.5])

	print("\n%s\n" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	quit(0 if fail == 0 else 1)
