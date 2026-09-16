extends SceneTree
# 네 자루를 나란히 놓고 본다 — 표준 · 무거운 · 가벼운 · 자석.
#   godot --path . --quit-after 900 --script scripts/tools/shot_darts4.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_d4_g.cfg"
	Save.path = "user://_shot_d4.cfg"
	Save.wipe()
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
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g.state = g.S.TITLE
	g.mouse_at = Vector2(4.0, 4.0)
	await _wait(20)
	#  판 위에 네 줄로 나란히. 같은 각·같은 자리라 종류만 다르다.
	var ids := ["std", "hvy", "lgt", "mag"]
	var u := Vector2(0.0, -1.0)
	for i in ids.size():
		g.ttl_stuck.append({
			"p": Vector2(258.0 + float(i) * 42.0, 210.0),
			"u": u, "id": ids[i], "rot": g._ttl_rot(u), "t": 2.0})
	await _wait(4)
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/d4.png")
	print("  찍음")
	quit(0)
