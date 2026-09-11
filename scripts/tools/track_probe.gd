extends SceneTree

const GameData = preload("res://scripts/data.gd")

# ══════════════════════════════════════════════════════════
#  트랙 (= 발라트로의 행성 카드) 회귀 검사
#
#  실행:  godot --path . --headless --script scripts/tools/track_probe.gd
#  종료 코드 = 실패 개수
#
#  이 시스템은 **배관이 다 깔린 채로 죽어 있었다.** _cons_use 가 track_lv 를
#  올리고, _land 가 track_bonus 를 얹고, area_upgrades.csv 가 그 값을 쥔다 —
#  셋이 이어져 있는데 표의 수치 칸이 전부 비어서 언제나 0 이 돌아왔다.
#  사탕이 4골드를 받고 아무 일도 안 하던 것이 그 결과다.
#
#  표를 채웠으니 이제 끝단에서 값이 실제로 나오는지 본다. 표만 읽는 검사는
#  안 한다 — 죽어 있던 이유가 표가 아니라 표와 코드 **사이**였기 때문이다.
#
#  보는 것 여섯
#    ① 트랙 레벨이 점수에 실린다 (다섯 영역 전부)
#    ② 배수를 주는 트랙은 배수에도 실린다
#    ③ 레벨이 누적된다 (1..lv 합)
#    ④ 보드 아웃 강화가 빗나감에 점수를 준다 — 정산 큐가 0 을 박던 자리다
#    ⑤ 그런데 빗나감 **깃발**은 살아 있다 (실패 조건 동전이 안 죽는다)
#    ⑥ 사탕을 쓰면 트랙이 오른다
# ══════════════════════════════════════════════════════════

var fails := 0

# 판 중심에서 얼마나 떨어진 곳이 어느 영역인가 (R 비율).
# BOARD_BASE: 불 0.06 / 아우터 0.14 / 트리플 0.56~0.66 / 더블 0.90~1.00
const AT := {
	"bull_i": 0.03, "bull_o": 0.10, "single": 0.35,
	"triple": 0.61, "double": 0.95, "out": 1.25,
}


func _say(ok: bool, name: String, detail := "") -> void:
	print("  %s %-34s %s" % ["OK  " if ok else "실패", name, detail])
	if not ok:
		fails += 1


# 12시 방향(sectors[0] = 20)의 주어진 반지름에 한 발 꽂고 정산을 끝까지 돌린다.
func _throw(g: Node, where: String) -> Array:      # [점수, 배수, 빗나감인가]
	g.aim = g.BC + Vector2(0.0, -1.0) * g.R * float(AT[where])
	g.cur_chip = 0
	g.cur_mult = 0
	g.queue = []
	g._land()
	var miss := false
	for q in g.queue:
		if String(q.get("k", "")) == "miss":
			miss = true
	var guard := 0
	while not g.queue.is_empty() and guard < 64:
		g._next_step()
		guard += 1
	return [g.cur_chip, g.cur_mult, miss]


func _fresh(g: Node) -> void:
	g._new_run()
	g.state = g.S.AIM_V
	g.owned = []
	g._panel_reset()
	g.track_lv = {}
	g.remaining = [GameData.darts()[0]]
	g.cur_dart = GameData.darts()[0]
	g.darts_left = 9
	g.leg_darts = 9


func _initialize() -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)

	var TRK := {"single": 610001, "double": 610002, "triple": 610003,
			"bull_o": 610004, "bull_i": 610004, "out": 610005}

	# ① · ② 다섯 영역 전부에서 Lv1 이 값을 바꾼다
	for area in ["single", "double", "triple", "bull_o", "bull_i", "out"]:
		_fresh(g)
		var a := _throw(g, area)
		_fresh(g)
		g.track_lv = {TRK[area]: 1}
		var b := _throw(g, area)
		var tb: Dictionary = GameData.track_bonus(TRK[area], 1)
		var moved: bool = b[0] > a[0] or b[1] > a[1]
		_say(moved, "Lv1 이 %s 에 실린다" % area,
				"점수 %d→%d · 배수 %d→%d (표 s+%d m+%d)"
				% [a[0], b[0], a[1], b[1], tb.s, tb.m])

	# ③ 누적 — 2026-09-11 기획서: **홀수 레벨에 점수 · 짝수 레벨에 배수**다.
	#    예전에는 레벨마다 점수가 올라 Lv3 = Lv1 × 3 이었다. 이제 Lv3 은
	#    홀수를 두 번(1·3) 지났으므로 점수는 두 배고, 짝수를 한 번(2)
	#    지났으므로 배수가 처음으로 붙는다.
	var t1: Dictionary = GameData.track_bonus(610003, 1)
	var t2: Dictionary = GameData.track_bonus(610003, 2)
	var t3: Dictionary = GameData.track_bonus(610003, 3)
	_say(t1.m == 0 and t2.m > 0, "배수는 짝수 레벨에 붙는다",
			"Lv1 m%d → Lv2 m%d" % [t1.m, t2.m])
	_say(t2.s == t1.s and t3.s == t1.s * 2, "점수는 홀수 레벨에 붙는다",
			"Lv1 s%d · Lv2 s%d · Lv3 s%d" % [t1.s, t2.s, t3.s])
	# 상한이 없다 — 표가 아니라 식이라 레벨을 계속 올릴 수 있다.
	var t99: Dictionary = GameData.track_bonus(610003, 99)
	_say(t99.s == t1.s * 50 and t99.m == t2.m * 49, "레벨에 상한이 없다",
			"Lv99 s%d m%d" % [t99.s, t99.m])

	# ④ 보드 아웃 강화가 빗나감에 점수를 준다
	_fresh(g)
	var m0 := _throw(g, "out")
	_fresh(g)
	g.track_lv = {610005: 3}
	var m3 := _throw(g, "out")
	_say(m0[0] == 0 and m3[0] > 0, "빗나감이 보드 아웃 강화를 받는다",
			"Lv0 %d점 → Lv3 %d점" % [m0[0], m3[0]])

	# ⑤ 그래도 빗나감 깃발은 산다 — 이게 죽으면 실패 조건 동전이 통째로 죽는다
	_say(m0[2] and m3[2], "점수가 나도 빗나감으로 센다",
			"Lv0 miss=%s · Lv3 miss=%s" % [m0[2], m3[2]])

	# ⑥ 사탕이 트랙을 올린다
	_fresh(g)
	var cs: Array = GameData.consumables()
	var pick := {}
	for c in cs:
		if String(c.get("cat", "")) == "area":
			pick = c
			break
	if pick.is_empty():
		_say(false, "사탕이 트랙을 올린다", "area 갈래 사탕가 없다")
	else:
		g.cons = [pick]
		var before: int = int(g.track_lv.get(pick.track, 0))
		g._cons_use(0)
		var after: int = int(g.track_lv.get(pick.track, 0))
		_say(after == before + 1 and g.cons.is_empty(),
				"사탕이 트랙을 올린다",
				"%s: Lv%d → Lv%d · 칸 %d개 남음" % [pick.n, before, after, g.cons.size()])

	print("\n%s" % ("실패 %d건" % fails if fails > 0 else "열 검사 전부 통과"))
	quit(mini(fails, 125))
