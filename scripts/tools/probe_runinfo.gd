extends SceneTree
# 런 정보가 어디서 열리고 어디서 안 열리는가 · 닫으면 제자리로 오는가.
#     godot --headless --script scripts/tools/probe_runinfo.gd

func _initialize() -> void:
	var g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g._new_run()

	var names := {}
	names[g.S.PICK] = "PICK(판 위)"
	names[g.S.SHOP] = "SHOP"
	names[g.S.LEG] = "LEG(판 선택)"
	names[g.S.CLEAR] = "CLEAR(정산)"
	names[g.S.RESOLVE] = "RESOLVE(연출)"
	names[g.S.TITLE] = "TITLE"
	names[g.S.COLLECT] = "COLLECT"
	for st in names:
		g.state = st
		print("%-14s 열림가능=%s" % [names[st], g._runinfo_ok()])

	# 판 위에서 열고 닫으면 제자리로 오는가
	g.state = g.S.PICK
	g.run_from = g.state
	g.state = g.S.RUNINFO
	print("열었다 state=RUNINFO? %s" % (g.state == g.S.RUNINFO))
	# 탭 넷이 다 눌리는가
	for t in 4:
		g.runinfo_tab = 0
		g._click(g._ri_tab_rect(t).get_center())
		print("탭 %d 클릭 -> runinfo_tab=%d %s"
				% [t, g.runinfo_tab, "ok" if g.runinfo_tab == t else "실패"])
	#  키는 닫지 않고 **넘긴다**(2026-09-19). 닫기를 넘기기와 같은 자리에 두면
	#  마지막 탭에서 한 번 더 누르는 순간 화면이 사라진다.
	g.state = g.S.PICK
	g.run_from = g.state
	g.runinfo_tab = 2
	g._runinfo_step()
	print("닫혀 있을 때 한 번 -> 열림=%s · 탭=%d(마지막에 보던 자리) %s"
			% [g.state == g.S.RUNINFO, g.runinfo_tab,
			"ok" if g.state == g.S.RUNINFO and g.runinfo_tab == 2 else "실패"])
	g.runinfo_tab = 0
	var seq := []
	for _k in 5:
		g._runinfo_step()
		seq.append(g.runinfo_tab)
		if g.state != g.S.RUNINFO:
			break
	print("다섯 번 눌러 %s · 안 닫힌다=%s %s"
			% [str(seq), g.state == g.S.RUNINFO,
			"ok" if seq == [1, 2, 3, 0, 1] and g.state == g.S.RUNINFO else "실패"])

	var mid: Vector2 = g._runinfo_back_rect().get_center()
	g._click(mid)
	print("닫기 클릭 후 제자리(PICK)? %s" % (g.state == g.S.PICK))
	quit()
