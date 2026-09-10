extends SceneTree
# 화면마다 어느 곡을 원하는가 · 갈릴 때 겹쳐 넘어가는가.
#     godot --headless --script scripts/tools/probe_music.gd
#
# _ready 는 첫 프레임에 돈다 — 소리 자리(mus_pl)가 그때 선다. 그래서
# shot_*.gd 와 같이 몇 프레임 기다린 뒤에 본다.

var g = null
var n := 0
var busy := false

func _process(_d: float) -> bool:
	if busy:
		return false
	n += 1
	if n == 1:
		g = load("res://scenes/main.tscn").instantiate()
		root.add_child(g)
	elif n == 6:
		busy = true
		_go()
	return false

func _go() -> void:
	var gd = load("res://scripts/data.gd")
	g._new_run()
	print("자리 %d 개" % g.mus_pl.size())

	print("- 화면별 곡 -")
	var cases := [
		[g.S.TITLE, -1, 1, "타이틀"],
		[g.S.COLLECT, -1, 1, "컬렉션"],
		[g.S.STAGE, -1, 1, "판 선택"],
		[g.S.SHOP, -1, 1, "상점"],
		[g.S.CLEAR, -1, 1, "정산"],
		[g.S.PICK, -1, 1, "판 위"],
	]
	for c in cases:
		g.state = c[0]
		g.pause_from = c[1]
		g.leg_no = c[2]
		print("  %-10s -> %s" % [c[3], g._mus_want()])
	for k in range(1, gd.legs_n() + 1):
		if gd.is_boss(k):
			g.state = g.S.PICK
			g.leg_no = k
			print("  %-10s -> %s (판 %d)" % ["보스 판 위", g._mus_want(), k])
			break

	print("- 덮개는 뒤를 따르는가 -")
	g.state = g.S.SHOP
	g.leg_no = 1
	g.run_from = g.S.SHOP
	g.state = g.S.RUNINFO
	print("  런 정보 -> %s %s" % [g._mus_want(), "ok" if g._mus_want() == "select" else "실패"])
	g.state = g.S.SETTINGS
	g.pause_from = g.S.PICK
	print("  판 위 일시정지 -> %s %s" % [g._mus_want(), "ok" if g._mus_want() == "game" else "실패"])

	# ── 보스 속도 ─────────────────────────────────
	# 라운드마다 보스가 얼마나 급한가. 값이 아니라 **차이**가 요점이라
	# 라운드 1과 마지막의 간격을 같이 적는다.
	print("- 보스 속도 -")
	g.state = g.S.PICK
	var lo := 0.0
	var hi := 0.0
	for k in range(1, gd.legs_n() + 1):
		if not gd.is_boss(k):
			continue
		g.leg_no = k
		var pv: float = g._mus_pitch_want()
		if lo == 0.0:
			lo = pv
		hi = pv
		print("  라운드 %d 보스 -> x%.4f" % [gd.round_of(k), pv])
	g.leg_no = 1
	print("  판 위(보스 아님) -> x%.4f" % g._mus_pitch_want())
	g.state = g.S.TITLE
	print("  로비 -> x%.4f" % g._mus_pitch_want())
	print("  처음과 끝 차이: %.1f%% (반음 %.2f)"
			% [(hi / lo - 1.0) * 100.0, 12.0 * log(hi / lo) / log(2.0)])

	# 속도가 툭 안 바뀌고 걸어가는가. 보스에 들어선 뒤 몇 초에 다 오르나.
	print("- 속도가 걸어가는가 -")
	g.state = g.S.PICK
	g.leg_no = 1
	g.mus_pitch = 1.0
	for k in range(1, gd.legs_n() + 1):
		if gd.is_boss(k):
			g.leg_no = k
			break
	var t := 0.0
	var tgt: float = g._mus_pitch_want()
	while g.mus_pitch < tgt - 0.0005 and t < 10.0:
		g._mus_update(0.016)
		t += 0.016
		if is_equal_approx(t, 0.48) or is_equal_approx(t, 0.96):
			print("  %.2f초: x%.4f" % [t, g.mus_pitch])
	print("  다 오르기까지 %.2f초 (넘김은 %.2f초) · 두 자리 다 x%.4f/%.4f"
			% [t, g.MUS_FADE, g.mus_pl[0].pitch_scale, g.mus_pl[1].pitch_scale])

	print("- 크로스페이드 -")
	g.pause_from = -1
	g.state = g.S.TITLE
	g._mus_update(0.016)
	print("  타이틀: key=%s 재생=%s" % [g.mus_key, g.mus_pl[g.mus_i].playing])
	g.state = g.S.SHOP
	g._mus_update(0.016)
	print("  전환 직후: 새 %.1fdB · 옛 %.1fdB (둘 다 울린다)"
			% [g.mus_pl[g.mus_i].volume_db, g.mus_pl[1 - g.mus_i].volume_db])
	for k in 60:
		g._mus_update(0.016)
	print("  0.96초: x=%.2f 새 %.1fdB · 옛 %.1fdB"
			% [g.mus_x, g.mus_pl[g.mus_i].volume_db, g.mus_pl[1 - g.mus_i].volume_db])
	for k in 60:
		g._mus_update(0.016)
	print("  끝: x=%.2f 새 %.1fdB · 옛 멈춤=%s"
			% [g.mus_x, g.mus_pl[g.mus_i].volume_db, not g.mus_pl[1 - g.mus_i].playing])
	quit()
