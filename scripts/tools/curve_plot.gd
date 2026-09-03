extends SceneTree

const GameData = preload("res://scripts/data.gd")

# ══════════════════════════════════════════════════════════
#  목표 곡선 눈으로 보기 — 시뮬레이션 없이 1초
#
#  실행:  godot --path . --headless -s scripts/tools/curve_plot.gd
#         (리그을 같이 보려면)  ... -- green   ·   ... -- purple
#
#  curve_probe 는 24판을 실제로 돌려 통과율을 재느라 16런에 8분이 든다.
#  손잡이(curve_first · curve_last · curve_bow)를 만질 때마다 그걸 돌릴
#  수는 없다. 여기서는 **식이 뱉는 수열만** 본다 — 모양이 맞는지는
#  이걸로 보고, 그 모양이 이길 만한지는 curve_probe 가 답한다.
# ══════════════════════════════════════════════════════════

const BAL := [300.0, 800.0, 2000.0, 5000.0, 11000.0, 20000.0, 35000.0, 50000.0]


func _bar(v: float, lo: float, hi: float, w: int) -> String:
	# 로그 자로 잰다. 총 배율이 328배라 선형 막대면 앞 다섯 라운드가 다 0칸이다.
	var t := (log(maxf(v, 1.0)) - log(lo)) / maxf(log(hi) - log(lo), 0.0001)
	var n := clampi(int(round(t * float(w))), 0, w)
	return "█".repeat(n) + "·".repeat(w - n)


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		var t := String(a)
		if String(GameData.league_row(t).get("id", "")) == t:
			GameData.league = t
	GameData.boot()
	var n := GameData.rounds_n()
	var unarmed := float(GameData.tune_i("darts_base")) * 14.4

	print("리그: %s" % (GameData.league if GameData.league != "" else "흰색(기본)"))
	print("손잡이 — 첫값 %.0f · 끝값 %.0f · 배부름 %.2f"
			% [GameData.tune("curve_first"), GameData.tune("curve_last"),
			GameData.tune("curve_bow")])
	print("무장 없는 한 판 기댓값 %.0f점 (%d발 x 14.4)\n"
			% [unarmed, GameData.tune_i("darts_base")])

	var lo := GameData.round_base(1)
	var hi := GameData.round_base(n) * 2.0
	print("라운드   기본     작은     큰     보스   배율   로그 자")
	var prev := 0.0
	for a in range(1, n + 1):
		var b := GameData.round_base(a)
		# 판 번호로 되돌려 실제 목표를 읽는다 — 판돈·다트통 배수까지 탄 값이다.
		var r0 := (a - 1) * GameData.legs_per_round() + 1
		var row := ""
		for k in GameData.legs_per_round():
			row += "%8d" % GameData.target_of(r0 + k)
		print("A%d %8.0f%s   %s  %s" % [a, b, row,
				"  — " if prev <= 0.0 else "%.2f" % (b / prev),
				_bar(b, lo, hi, 24)])
		prev = b

	# 발라트로와 **모양**을 맞댄다. 크기는 다르므로 각자의 첫값으로 나눈다 —
	# 남는 것이 곡선의 모양뿐이다.
	print("\n모양 대조 (각자 첫 라운드 = 1.00)")
	print("라운드   이 게임   발라트로")
	for a in range(1, mini(n, BAL.size()) + 1):
		print("A%d %9.1f %10.1f"
				% [a, GameData.round_base(a) / GameData.round_base(1), BAL[a - 1] / BAL[0]])

	print("\n총 배율 %.0f배 · 첫 판 목표가 무장 없는 기댓값의 %.0f%%"
			% [GameData.round_base(n) / GameData.round_base(1),
			100.0 * GameData.target_of(1) / unarmed])
	var errs: PackedStringArray = GameData.errors()
	if errs.is_empty():
		print("검증 통과")
	else:
		for e in errs:
			print("!! %s" % e)
	quit(0)


func _process(_d: float) -> bool:
	return true
