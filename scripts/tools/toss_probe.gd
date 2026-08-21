extends SceneTree

# ══════════════════════════════════════════════════════════
#  던지기 수렴 검사 — 임시 도구
#
#  실행:  godot --path . --headless --script scripts/tools/toss_probe.gd
#
#  사람 손 없이 _hand_land(it, v) 를 직접 불러 놓고, 잠들 때까지 프레임을
#  감아 네 가지를 본다.
#    ① 멈추는가            drop_awake 가 t_max 전에 내려가는가
#    ② 얼마나 가는가        미끄럼 거리가 설계값(v²/2a)과 맞는가
#    ③ 트레이 안에 있는가   u·w 가 벽 안인가
#    ④ 겹치지 않는가        정착 정의를 그대로 다시 잰다
#
#  던지기가 낙하와 다른 상태라는 것도 같이 본다 — 미끄러지는 동안
#  _drop_busy() 는 false 여야 한다(툴팁·집기·클릭이 안 막힌다).
# ══════════════════════════════════════════════════════════

const FPS := 1.0 / 60.0


func _initialize() -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)

	var fail := 0
	for case in [Vector2(600.0, 0.0), Vector2(-1200.0, 300.0),
			Vector2(0.0, -900.0), Vector2(80.0, 40.0), Vector2(4000.0, 4000.0)]:
		fail += _run(g, case)

	print("\n%s" % ("실패 %d건" % fail if fail > 0 else "다섯 경우 전부 통과"))
	quit(mini(fail, 125))


func _run(g: Node, hand_v: Vector2) -> int:
	g._open_shop()
	g._drop_settle()

	var it: Dictionary = g.drop[0]
	var p0 := Vector2(it.u, it.w)
	var v: Vector2 = g._toss_of(hand_v)
	g._hand_land(it, v)

	var busy_seen := false
	var t := 0.0
	var n := 0
	while g.drop_awake and n < 600:
		g._drop_update(FPS)
		busy_seen = busy_seen or g._drop_busy()
		t += FPS
		n += 1

	var p1 := Vector2(it.u, it.w)
	var want := v.length_squared() / (2.0 * float(g.DROP.a_fric))
	var bad := []

	if g.drop_awake:
		bad.append("10초 안에 안 멈춘다")
	if busy_seen:
		bad.append("미끄러지는 동안 _drop_busy() 가 켜졌다 — 낙하와 안 갈렸다")
	if v == Vector2.ZERO and t > FPS * 1.5:
		bad.append("죽은 띠인데 적분기가 돌았다")
	for e in g.drop:
		if e.u < g.DROP.u_lo + e.hw - 0.01 or e.u > g.DROP.u_hi - e.hw + 0.01 \
				or e.w < g.DROP.w_lo - 0.01 or e.w > g.DROP.w_hi + 0.01:
			bad.append("트레이 밖 (u %.1f w %.1f)" % [e.u, e.w])
		if e.h > 0.001:
			bad.append("떴다 (h %.3f)" % e.h)
	var ov := _overlap(g)
	if ov > 0.01:
		bad.append("겹침 %.3f px" % ov)

	print("손 %-16s → 던짐 %6.1f · 간 거리 %6.1f (설계 %6.1f) · %.2f초 · %s"
			% [str(hand_v), v.length(), p0.distance_to(p1), want, t,
				"OK" if bad.is_empty() else " / ".join(bad)])
	return 0 if bad.is_empty() else 1


func _overlap(g: Node) -> float:
	var worst := 0.0
	for a in g.drop.size():
		for b in range(a + 1, g.drop.size()):
			var A: Dictionary = g.drop[a]
			var B: Dictionary = g.drop[b]
			if A.gone or B.gone:
				continue
			for ia in int(A.nb):
				for ib in int(B.nb):
					var d: float = g._drop_sub(A, ia).distance_to(g._drop_sub(B, ib))
					worst = maxf(worst, float(A.r) + float(B.r) - d)
	return worst
