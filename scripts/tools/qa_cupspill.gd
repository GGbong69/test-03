extends SceneTree
# 넘긴 뒤 자루가 어디에 서 있는가. 눈으로는 「좀 기울었네」와 「통 밖에
# 떠 있다」가 안 갈려서 수로 찍는다.
#   godot --path . --quit-after 9000 --script scripts/tools/qa_cupspill.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false

func _initialize() -> void:
	Save.path = "user://_qa_spill.cfg"
	Save.wipe()
	for r in GameData.packs():
		Save.unlock("pack:" + String(r.get("id", "")))
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)

func _process(_d: float) -> bool:
	if busy: return false
	busy = true
	_run()
	return false

func _wait(n: int) -> void:
	for i in n:
		await process_frame

func _run() -> void:
	await _wait(6)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g._open_newrun()
	await _wait(90)
	print("\n넘긴 뒤 자루가 선 자리 — 촉 반지름(r배) · 촉 높이(h배) · 기울기(도)\n")
	var worst := 0.0
	var pinned := 0
	var laid := 0
	for pi in GameData.packs().size():
		if pi > 0:
			g._pack_step(1)
		await _wait(150)
		if g.cup_rigs.is_empty():
			continue
		var rig: Dictionary = g.cup_rigs[0]
		var cx: float = rig.cup.position.x
		var rr: float = float(rig.r)
		var hh: float = float(rig.get("h", g.CUP3.h))
		var dl: float = float(g.CUP3.dl)
		var out := PackedStringArray()
		var bad := 0
		for b in rig.darts:
			var t: Transform3D = b.global_transform
			var tip: Vector3 = t.origin - t.basis.y * dl
			var tl: Vector3 = t.origin + t.basis.y * dl
			var rad: float = Vector2(tip.x - cx, tip.z).length() / rr
			var hgt: float = tip.y / hh
			var flat: float = Vector2(tl.x - tip.x, tl.z - tip.z).length()
			var lean: float = rad_to_deg(asin(clampf(flat / (2.0 * dl), 0.0, 1.0)))
			worst = maxf(worst, lean)
			if rad > 0.95:
				pinned += 1
			if lean > 39.0:
				laid += 1
			if rad > 0.95 or lean > 39.0 or hgt > 0.35:
				bad += 1
			out.append("%.2f/%.2f/%.0f" % [rad, hgt, lean])
		print("  %-8s %-14s %s%s" % [GameData.packs()[pi].get("id", ""),
				GameData.packs()[pi].get("name", ""), " ".join(out),
				"   ← %d발" % bad if bad > 0 else ""])
	#  통과선. 39도는 자루가 아가리에 걸쳐 눕기 시작하는 자리고, 촉 0.95×r 은
	#  벽에 밀린 것이다 — 통을 다시 좁히면 여기가 운다. 0.62 로 조였던 외줄이
	#  35·37도에 촉 1.00 이었고, 눈으로는 「좀 기울었네」와 안 갈렸다.
	print("
가장 기운 자루 %.0f도 · 벽에 밀린 촉 %d발 · 걸쳐 누운 자루 %d발"
			% [worst, pinned, laid])
	print("%s" % ("전부 통과" if pinned == 0 and laid == 0 else "실패"))
	quit(mini(pinned + laid, 125))
