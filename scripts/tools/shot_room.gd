extends SceneTree
#  3D 방 · 테이블 촬영 (2026-10-01) — 상점 · 옛 단색 · 판 고르기 세 장을 shots/room_*.png 로.
#  창이 있어야 돈다:  godot --path . --script scripts/tools/shot_room.gd
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_room_g.cfg"
	Save.path = "user://_shot_room.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	seed(20261001)


func _process(_d: float) -> bool:
	if busy:
		return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for _i in n:
		await process_frame


func _quiet() -> void:
	g._tutor_close()
	g.tutor_q.clear()
	g.mouse_at = Vector2(-50, -50)


func _run() -> void:
	await _wait(10)
	g._new_run()
	for id in ["u_leg", "u_skip", "u_boss", "u_score", "u_clear", "u_shop", "u_rack", "u_cons", "u_sell", "u_reroll", "u_give"]:
		Save.teach(id)
	_quiet()
	g.state = g.S.SHOP
	g.leg_no = 1
	g.gold = 24
	g._open_shop()
	await _wait(200)
	_quiet()
	await _wait(30)
	root.get_texture().get_image().save_png("res://shots/room_shop.png")
	g.room3d_on = false
	await _wait(10)
	root.get_texture().get_image().save_png("res://shots/room_shop_old.png")
	g.room3d_on = true
	g.leg_no = 2
	g._open_leg()
	await _wait(120)
	_quiet()
	await _wait(30)
	root.get_texture().get_image().save_png("res://shots/room_leg.png")
	quit(0)
