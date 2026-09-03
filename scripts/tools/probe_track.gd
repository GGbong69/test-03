extends SceneTree
# 트랙 강화가 실제로 점수에 반영되는가.
#     godot --headless --script scripts/tools/probe_track.gd
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
	g._new_run()
	print("― 강화 전후 점수 ―")
	for a in gd.areas_all():
		var tk: int = int(a.get("track", 0))
		if tk == 0:
			continue
		g.track_lv.clear()
		var b0 = gd.track_bonus(tk, 0)
		g.track_lv[tk] = 1
		var b1 = gd.track_bonus(tk, 1)
		g.track_lv[tk] = 3
		var b3 = gd.track_bonus(tk, 3)
		print("  %-8s 기본 %3d x%d  ->  Lv1 +%d/+%d  Lv3 +%d/+%d"
				% [a.get("n","?"), a.get("base",0), a.get("mult",1),
					b0.s + b1.s - b0.s, b1.m, b3.s, b3.m])

	print("― 뱃지로 올려 본다 ―")
	g.track_lv.clear()
	var before: int = g.track_lv.size()
	g._take_tag({"kind": "track", "v": 1, "when": "now", "name": "영역 승급"})
	var after: int = g.track_lv.size()
	print("  뱃지 1회: 올린 트랙 수 %d -> %d %s" % [before, after, "ok" if after == 1 else "실패"])
	for tk in g.track_lv:
		print("  %s = 강화 %d회 (화면 표기 Lv.%d)"
				% [g._track_name(tk), g.track_lv[tk], int(g.track_lv[tk]) + 1])
	quit()
