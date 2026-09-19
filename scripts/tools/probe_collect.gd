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

#  두 겹으로 돈다. **잠긴 것이 잠기는가**와 **열린 것이 열리는가**는 다른
#  질문이라 한 겹으로는 둘 중 하나가 늘 안 잡힌다 — 이 자의 본래 뜻(「탭이
#  각자 제 것을 집는가」)은 발견 상태에서만 잴 수 있고, 잠긴 쪽 규약(제목
#  ??? · 태그 한 장 · 본문 0줄 · 등급 안 샘)은 미발견 상태에서만 잴 수 있다.
#  2026-09-19
func _go() -> void:
	g.state = g.S.COLLECT
	var ok := true
	#  ── ① 못 본 칸 ──────────────────────────────────────
	#  ⚠ 이 자는 Save.path 를 안 박으므로 **도구들이 공유하는** 자리
	#  (user://_tool_profile_N.cfg)에서 돈다 — 옆 도구가 남긴 발견이 들쭉날쭉
	#  섞여 있다. 그래서 대역을 끄는 것으로는 모자라고 절을 실제로 비운다.
	#  사람의 저장이 아니다(Save._tool_run 이 자리를 돌린다).
	g._dev_unlock_none()
	print("  못 본 칸 — 제목 ??? · 태그 한 장 · 본문 0줄 · 등급 안 샌다")
	for t in g.COL_TABS.size():
		g.collect_tab = t
		g.collect_page = 0
		var hit: Dictionary = g._tip_hit(g._col_cell(0).get_center())
		g._tip_build(hit)
		var want: String = String(g.COL_TABS[t].k)
		var got: String = String(hit.get("k", "?"))
		var pass_: bool = got == want and g.tip_title == "???" \
				and g.tip_tags.size() == 1 and g.tip_lines.is_empty() \
				and String(g.tip_rar) == "" and (g.tip_chip as Dictionary).is_empty()
		if not pass_:
			ok = false
		print("    %-8s 열쇠 %-6s 제목 %-6s 태그 %d · 본문 %d줄 · 등급 '%s' %s"
				% [g.COL_TABS[t].n, got, g.tip_title, g.tip_tags.size(),
					g.tip_lines.size(), g.tip_rar, "ok" if pass_ else "실패"])

	#  ── ② 발견한 칸 ─────────────────────────────────────
	#  옛 단언 그대로다 — 탭이 각자 제 것을 집는가.
	g._dev_unlock_all()
	print("  발견한 칸 — 탭이 각자 제 것을 집는다")
	for t in g.COL_TABS.size():
		g.collect_tab = t
		g.collect_page = 0
		var c: Vector2 = g._col_cell(0).get_center()
		var hit: Dictionary = g._tip_hit(c)
		g._tip_build(hit)
		var want: String = String(g.COL_TABS[t].k)
		var got: String = String(hit.get("k", "?"))
		var pass_: bool = got == want and g.tip_title != "" and g.tip_title != "???"
		if not pass_:
			ok = false
		# 태그는 이제 여러 장이다(tip_tags) — 2026-09-13 에 설명창이 [동전]
		# [일반] 처럼 밑줄에 태그를 달면서 tip_tag 한 장이 배열이 됐다.
		# 이 자는 그 뒤로 조용히 죽어 있었다.
		var tags := PackedStringArray()
		for tg in g.tip_tags:
			tags.append(String(tg.get("t", "")))
		print("    %-8s 열쇠 %-6s 태그 %-10s 첫 항목 %-14s %s"
				% [g.COL_TABS[t].n, got, "/".join(tags), g.tip_title,
					"ok" if pass_ else "실패"])
	print("전체 %s" % ("통과" if ok else "실패"))
	quit(0 if ok else 1)
