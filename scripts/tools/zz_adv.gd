extends SceneTree
const GameData = preload("res://scripts/data.gd")

func _initialize() -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
	g._new_run()
	g._start_round()
	seed(1234)

	# ── 1. 오토플레이와 똑같은 분포로 한 발 기댓값 ──────────
	var N := 400000
	var s := 0.0
	var best := 0.0
	var bestp := Vector2.ZERO
	for i in N:
		var a := randf() * TAU
		var p: Vector2 = g.BC + Vector2(cos(a), sin(a)) * sqrt(randf()) * g.R * 0.95
		var h: Dictionary = g.hit_info(p)
		s += float(h.base) * float(h.mult)
	print("[A] 오토플레이 분포(판 안 균일) 한 발 기댓값 = %.2f" % (s / float(N)))

	# ── 2. 판 전체에서 가장 좋은 자리 ───────────────────────
	for xi in range(-140, 141):
		for yi in range(-140, 141):
			var p: Vector2 = g.BC + Vector2(float(xi), float(yi))
			var h: Dictionary = g.hit_info(p)
			var v := float(h.base) * float(h.mult)
			if v > best:
				best = v
				bestp = Vector2(float(xi), float(yi))
	print("[B] 판 위 최고점 = %.0f  (중심에서 %.1f px, %s)" % [best, bestp.length(), str(bestp)])

	# ── 3. 그 자리를 겨눈 사람 — 오차 sigma 별 기댓값 ────────
	for sg in [2.0, 4.0, 6.0, 8.0, 12.0, 16.0, 24.0, 32.0]:
		var t := 0.0
		var miss := 0
		var M := 200000
		for i in M:
			var p: Vector2 = g.BC + bestp + Vector2(randfn(0.0, sg), randfn(0.0, sg))
			var h: Dictionary = g.hit_info(p)
			if int(h.mult) == 0:
				miss += 1
			t += float(h.base) * float(h.mult)
		print("[C] 최고점 겨냥 sigma=%4.0fpx → 한 발 %6.2f  (6발 %7.0f, 빗나감 %4.1f%%)"
				% [sg, t / float(M), 6.0 * t / float(M), 100.0 * float(miss) / float(M)])

	# ── 4. 불(bull) 겨냥 ────────────────────────────────────
	for sg in [4.0, 8.0, 16.0]:
		var t := 0.0
		var M := 200000
		for i in M:
			var p: Vector2 = g.BC + Vector2(randfn(0.0, sg), randfn(0.0, sg))
			var h: Dictionary = g.hit_info(p)
			t += float(h.base) * float(h.mult)
		print("[D] 불 겨냥      sigma=%4.0fpx → 한 발 %6.2f  (6발 %7.0f)" % [sg, t / float(M), 6.0 * t / float(M)])

	# ── 5. 목표 곡선 — 지금 값과 대안들 ─────────────────────
	print("\n[E] 앤티 기본 (first=%.0f last=%.0f bow=%.2f)"
			% [GameData.tune("curve_first"), GameData.tune("curve_last"), GameData.tune("curve_bow")])
	for a in range(1, GameData.antes_n() + 1):
		print("   앤티 %d  기본 %8.1f   작은 %7d  큰 %7d  보스 %7d"
				% [a, GameData.ante_base(a),
				int(round(GameData.ante_base(a))),
				int(round(GameData.ante_base(a) * 1.5)),
				int(round(GameData.ante_base(a) * 2.0))])

	# ── 6. 리그(스테이크) 곡선 ──────────────────────────────
	print("\n[F] 리그별 앤티 8 보스 목표")
	for r in GameData.stakes():
		var id := String(r.get("id", ""))
		GameData.stake = id
		print("   %-7s %-8s 곡선열=%-7s  앤티8보스 %9d   다트 %d"
				% [id, String(r.get("name", "")), String(r.get("curve", "")),
				GameData.target_of(24), GameData.darts_of(24) + int(r.get("darts_add", 0))])
	GameData.stake = "white"
	quit(0)
