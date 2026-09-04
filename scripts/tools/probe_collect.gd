extends SceneTree
# 컬렉션 탭 여섯이 각자 제 것을 집는가. 탭을 늘릴 때 어긋나기 쉬운 자리다.
#     godot --headless --script scripts/tools/probe_collect.gd
var g = null
var n := 0
var busy := false
func _process(_d: float) -> bool:
	if busy: return false
	n += 1
	if n == 1:
		g = load("res://scenes/main.tscn").instantiate()
		root.add_child(g)
	elif n == 6:
		busy = true
		_go()
	return false

func _go() -> void:
	g.state = g.S.COLLECT
	var ok := true
	for t in g.COL_TABS.size():
		g.collect_tab = t
		g.collect_page = 0
		var c: Vector2 = g._col_cell(0).get_center()
		var hit: Dictionary = g._tip_hit(c)
		g._tip_build(hit)
		var want: String = String(g.COL_TABS[t].k)
		var got: String = String(hit.get("k", "?"))
		var pass_: bool = got == want and g.tip_title != ""
		if not pass_:
			ok = false
		print("  %-8s 열쇠 %-6s 태그 %-6s 첫 항목 %-14s %s"
				% [g.COL_TABS[t].n, got, g.tip_tag, g.tip_title,
					"ok" if pass_ else "실패"])
	print("전체 %s" % ("통과" if ok else "실패"))
	quit()
