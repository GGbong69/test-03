extends SceneTree
# 히든 다트통의 겉. 잠긴 것은 깨진 신호로, 열린 것은 후광으로 선다.
#   godot --path . --quit-after 9000 --script scripts/tools/shot_hidden.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false

func _initialize() -> void:
	Save.path = "user://_shot_hidden.cfg"
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

func _idx(id: String) -> int:
	for i in GameData.packs().size():
		if String(GameData.packs()[i].get("id", "")) == id:
			return i
	return -1

func _shot(nm: String) -> void:
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)

func _run() -> void:
	await _wait(6)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 통은 화면이 있어야 선다")
		quit(0)
		return
	var hid := ["p_x1", "p_rnd", "p_dev"]
	# ── 잠긴 히든 — 깨진 신호 ──
	Save.wipe()
	g._open_newrun()
	await _wait(60)
	for id in hid:
		g._pack_view(_idx(id))
		g._cup3_close()
		g._cup3_open()
		await _wait(70)
		print("  잠김 %-6s open=%s" % [id, g._pack_open(_idx(id))])
		await _shot("hid_shut_%s" % id)
		await _wait(9)                       # 걸음 하나 뒤 — 조각이 다시 뽑힌다
		await _shot("hid_shut_%s_b" % id)
	# ── 열린 히든 — 후광 ──
	for r in GameData.packs():
		Save.unlock("pack:" + String(r.get("id", "")))
	for id in hid:
		g._pack_view(_idx(id))
		g._cup3_close()
		g._cup3_open()
		await _wait(70)
		print("  열림 %-6s open=%s" % [id, g._pack_open(_idx(id))])
		await _shot("hid_open_%s" % id)
	print("찍었다")
	quit(0)
