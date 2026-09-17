extends SceneTree
# 단추 얹힘 — 커서를 올린 단추와 안 올린 단추를 한 장에.
#   godot --path . --quit-after 1500 --script scripts/tools/shot_hover.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false
var pin := Vector2(-50.0, -50.0)


func _initialize() -> void:
	Save.gpath = "user://_shot_hov_g.cfg"
	Save.path = "user://_shot_hov.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if busy:
		g.mouse_at = pin
		return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		g._tutor_close()
		g.tutor_out = 0.0
		g.swap_live = false
		g.mouse_at = pin
		await process_frame


func _shot(nm: String, at: Vector2) -> void:
	pin = at
	await _wait(20)
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g._new_run()
	await _wait(30)
	g.leg_t = 9.0
	await _shot("hov_leg_none", Vector2(-50.0, -50.0))
	await _shot("hov_leg_go", g._leg_go().get_center())
	await _shot("hov_leg_skip", g._leg_skip().get_center())
	g._open_shop()
	await _wait(30)
	await _shot("hov_shop_reroll", g._reroll_rect().get_center())
	await _shot("hov_shop_next", g._next_rect().get_center())
	await _shot("hov_shop_info", g._hud_btn_rect(0).get_center())
	print("  hov %s" % str(g.ui_hov))
	print("  찍음")
	quit(0)
