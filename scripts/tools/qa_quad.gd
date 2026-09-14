extends SceneTree

# 카드 네 귀퉁이 검사. 2026-09-14 「판이 왜 이렇게 찌그러져 있어」.
#   선 카드(up=1)는 직사각형 · 누운 카드(up=0)는 뒤가 좁은 사다리꼴.
#   서는 동안 발치가 자리에서 안 미끄러진다.
#
#   godot --path . --headless --script scripts/tools/qa_quad.gd

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-36s %s" % ["통과" if c else "실패", n, d])


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


#  한 카드의 네 귀퉁이를 사람 말로 푼다
func _say(q: PackedVector2Array) -> String:
	return "위 %.1f~%.1f(%.1f) · 아래 %.1f~%.1f(%.1f)" % [
			q[0].x, q[1].x, q[1].x - q[0].x,
			q[3].x, q[2].x, q[2].x - q[3].x]


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	print("\n카드 네 귀퉁이 — 서면 직사각형 · 누우면 사다리꼴\n")

	var CARD: Dictionary = g.CARD
	var n := 3
	for i in n:
		var r: Rect2 = g._row_rect(i, n)
		var sz: Vector2 = r.size

		#  ── 누운 카드 ───────────────────────────────
		var lay: PackedVector2Array = g._card_quad(r.position.x, sz.x, r.end.y,
				0.0, 1.0)
		var wt: float = lay[1].x - lay[0].x
		var wb: float = lay[2].x - lay[3].x
		_ok("카드%d 누우면 뒤가 좁다" % i, wt < wb - 1.0, _say(lay))

		#  ── 선 카드 ────────────────────────────────
		var gs: float = 1.12
		var w2: float = sz.x * gs
		var px2: float = r.position.x - (w2 - sz.x) * 0.5
		var st: PackedVector2Array = g._card_quad(px2, w2, r.end.y,
				1.0, gs, 7.0)
		var swt: float = st[1].x - st[0].x
		var swb: float = st[2].x - st[3].x
		_ok("카드%d 서면 직사각형" % i,
				absf(swt - swb) < 0.01 and absf(st[0].x - st[3].x) < 0.01
				and absf(st[1].x - st[2].x) < 0.01, _say(st))

		#  ── 발치가 안 미끄러진다 ─────────────────────
		#  서면 12% 커지고 7px 뜨므로 폭과 y 는 달라진다. 안 달라져야 하는
		#  것은 **가운데**다 — 자리를 뜨면 어느 카드를 집었는지가 흔들린다.
		var cl: float = (lay[2].x + lay[3].x) * 0.5
		var cs: float = (st[2].x + st[3].x) * 0.5
		_ok("카드%d 서도 발치 가운데가 그대로" % i, absf(cl - cs) < 0.01,
				"누움 %.1f · 섬 %.1f (차 %.2f)" % [cl, cs, absf(cl - cs)])

	#  ── 서는 동안에도 뒤집힌 사다리꼴이 안 나온다 ────────
	#  0 과 1 만 맞아도 중간에 위가 넓어지면 움직이는 내내 찌그러져 보인다.
	print("")
	var worst := 0.0
	var worst_up := 0.0
	for k in 41:
		var up: float = float(k) / 40.0
		var gs2: float = 1.0 + 0.12 * up
		var r0: Rect2 = g._row_rect(0, 3)
		var w3: float = r0.size.x * gs2
		var q: PackedVector2Array = g._card_quad(
				r0.position.x - (w3 - r0.size.x) * 0.5, w3,
				r0.end.y, up, gs2, 7.0 * up)
		var d: float = (q[1].x - q[0].x) - (q[2].x - q[3].x)   # 위 - 아래
		if d > worst:
			worst = d
			worst_up = up
	_ok("서는 내내 위가 아래보다 안 넓다", worst < 0.01,
			"최악 up %.2f 에서 위가 %.2fpx 넓다" % [worst_up, worst])

	print("\n통과 %d · 실패 %d" % [okn, fail])
	quit(mini(fail, 125))
