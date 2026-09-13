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
		# 태그는 이제 여러 장이다(tip_tags) — 2026-09-13 에 설명창이 [동전]
		# [일반] 처럼 밑줄에 태그를 달면서 tip_tag 한 장이 배열이 됐다.
		# 이 자는 그 뒤로 조용히 죽어 있었다.
		var tags := PackedStringArray()
		for tg in g.tip_tags:
			tags.append(String(tg.get("t", "")))
		print("  %-8s 열쇠 %-6s 태그 %-10s 첫 항목 %-14s %s"
				% [g.COL_TABS[t].n, got, "/".join(tags), g.tip_title,
					"ok" if pass_ else "실패"])
	print("전체 %s" % ("통과" if ok else "실패"))
	quit()
