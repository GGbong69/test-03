extends SceneTree
# 연 다트통의 윤. 빛띠 한 바퀴를 여섯 토막으로 찍는다.
#   godot --path . --quit-after 9000 --script scripts/tools/shot_sheen.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false

func _initialize() -> void:
	Save.path = "user://_shot_sheen.cfg"
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
	g._open_newrun()
	await _wait(80)
	# 한 바퀴(GLITCH.sheen_t 초)를 여섯으로 나눠 찍는다
	var per := int(60.0 * float(g.GLITCH.sheen_t) / 6.0)
	for k in 6:
		await _shot("sheen_%d" % k)
		await _wait(per)
	print("윤 여섯 장 · 한 토막 %d프레임" % per)
	# 잠긴 다트통에는 윤이 없어야 한다 — 눈으로도 본다
	Save.wipe()
	g._pack_view(1)
	g._cup3_close()
	g._cup3_open()
	await _wait(80)
	print("  잠김 확인 open=%s" % g._pack_open(1))
	await _shot("sheen_shut")
	quit(0)
