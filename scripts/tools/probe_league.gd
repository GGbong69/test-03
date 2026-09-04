extends SceneTree
# 리그 여덟이 무엇을 미는가 · 남의 동전이 장당인가.
#     godot --headless --script scripts/tools/probe_league.gd
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
	var gd = load("res://scripts/data.gd")
	for r in gd.leagues():
		gd.league = String(r.get("id", ""))
		var names := []
		for e in g._league_lines():
			names.append(String(e.n))
		print("%-10s %s" % [r.get("name", "?"), " · ".join(names)])

	print("")
	print("― 남의 동전이 장당인가 (검정 리그) ―")
	gd.league = "black"
	for cnt in [0, 2, 5]:
		g._new_run()
		g.owned.clear()
		var its = gd.items()
		for k in cnt:
			g.owned.append(its[k])
		g.gold = 50
		var before: int = g.gold
		g._finish_leg()
		print("  동전 %d장 -> 골드 %d에서 %d로 (%d 냈다)"
				% [cnt, before, g.gold, before - g.gold])
	quit()
