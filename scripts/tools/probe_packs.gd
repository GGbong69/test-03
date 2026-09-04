extends SceneTree
# 다트통 아홉이 실제로 런 시작에 무엇을 바꾸는가.
#     godot --headless --script scripts/tools/probe_packs.gd
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
	print("%-8s %-12s %-6s %-5s %-4s %-4s %-4s %-5s %s"
			% ["id", "이름", "갈래", "다트", "발", "골드", "칸", "계산", "받는 것"])
	for r in gd.packs():
		gd.pack = String(r.get("id",""))
		g._new_run()
		var mag := {}
		for d in g.magazine:
			var nm := String(d.get("n", "?"))
			mag[nm] = int(mag.get(nm, 0)) + 1
		var carry := []
		if g.owned.size() > 0: carry.append("동전%d" % g.owned.size())
		if g.cons.size() > 0: carry.append("사탕%d" % g.cons.size())
		if gd.fixtures_own.size() > 0: carry.append("사진%d" % gd.fixtures_own.size())
		print("%-8s %-12s %-6s %-5s %-4d %-4d %-4d %-5s %s"
				% [r.get("id","?"), r.get("name", r.get("n","?")), r.get("kind", "base"), str(mag), g.magazine.size(),
					g.gold, gd.max_items(), gd.score_mode(),
					", ".join(carry) if carry.size() > 0 else "-"])
	quit()
