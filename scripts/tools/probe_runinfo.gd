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
	names[g.S.STAGE] = "STAGE"
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
	var mid: Vector2 = g._runinfo_back_rect().get_center()
	g._click(mid)
	print("닫기 클릭 후 제자리(PICK)? %s" % (g.state == g.S.PICK))
	quit()
