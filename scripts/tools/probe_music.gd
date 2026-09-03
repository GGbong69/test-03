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
