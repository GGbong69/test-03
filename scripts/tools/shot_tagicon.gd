extends SceneTree
# 뱃지 그림 열둘을 한 줄에 늘어놓는다. 새 갈래 여섯이 제 그림을 갖는지,
# 그리고 얹힘 띠에 세로 줄이 안 서는지 같이 본다.
#   godot --path . --quit-after 900 --script scripts/tools/shot_tagicon.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false

func _initialize() -> void:
	Save.gpath = "user://_shot_tag_g.cfg"
	Save.path = "user://_shot_tag.cfg"
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
		print("  건너뜀"); quit(0); return
	# ① 얹힘 띠
	g.state = g.S.TITLE
	g.mouse_at = g._menu_rect(2).get_center()
	await _wait(30)
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/tag_band.png")
	print("찍었다 · 띠")
	# ② 뱃지 그림 — 쌓인 뱃지 줄에 갈래를 하나씩 깔아 본다
	g.leg_no = 1
	g._open_leg()
	g.pending_tags.clear()
	for r in GameData.tags():
		g.pending_tags.append({"kind": String(r.get("kind", "")),
				"v": 1, "n": String(r.get("name", "")), "d": "", "w": "",
				"rar": String(r.get("rarity", ""))})
	g.mouse_at = Vector2(320.0, 8.0)
	await _wait(8)
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/tag_icons.png")
	print("찍었다 · 그림 %d개" % g.pending_tags.size())
	# 줄이 640 에 아홉까지라 나머지를 따로 한 장 더
	g.pending_tags.clear()
	for r2 in GameData.tags():
		if not ["free", "boss_gold", "skip_gold", "track_top", "copy"].has(
				String(r2.get("kind", ""))):
			continue
		g.pending_tags.append({"kind": String(r2.get("kind", "")),
				"v": 1, "n": String(r2.get("name", "")), "d": "", "w": "",
				"rar": String(r2.get("rarity", ""))})
	await _wait(6)
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/tag_icons2.png")
	print("찍었다 · 나머지 %d개" % g.pending_tags.size())
	quit(0)
