extends SceneTree
# 상인을 통째로 본다 — 카메라를 물려 어깨·목·머리·챙까지.
#   godot --path . --quit-after 900 --script scripts/tools/shot_dealer.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_dlr_g.cfg"
	Save.path = "user://_shot_dlr.cfg"
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


func _shot(nm: String) -> void:
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	#  시작 화면 — 쓸 자리에서 본다. 무대는 _process 가 알아서 연다.
	g.state = g.S.TITLE
	g.mouse_at = Vector2(4.0, 4.0)
	await _wait(40)
	await _shot("dlr_title")
	#  커서를 좌우로 — 따라보기가 사는가
	g.mouse_at = Vector2(30.0, 300.0)
	await _wait(50)
	await _shot("dlr_title_l")
	g.mouse_at = Vector2(620.0, 60.0)
	await _wait(50)
	await _shot("dlr_title_r")
	#  상점도 한 장 — 머리가 한 픽셀도 안 새는지 본다
	g.mouse_at = Vector2(320.0, 300.0)
	g.state = g.S.SHOP
	await _wait(40)
	await _shot("dlr_shop")
	print("  찍음")
	quit(0)
