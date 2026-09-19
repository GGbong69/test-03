extends SceneTree
# 사진 아이템 그림이 게임에 붙은 모습 — 상점 테이블 · 사탕·사진 칸 · 컬렉션.
#   godot --path . --quit-after 1500 --script scripts/tools/shot_photos.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_ph_g.cfg"
	Save.path = "user://_shot_ph.cfg"
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


func _shot(nm: String, frames := 3) -> void:
	for i in frames:
		g._tutor_close()
		g.tutor_out = 0.0
		g.swap_live = false
		g.mouse_at = Vector2(-50.0, -50.0)
		g.tip_a = 0.0
		g.tip_spot = -1
		g.queue_redraw()
		await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g.state = g.S.TITLE
	g._new_run()
	await _wait(30)
	g.gold = 99
	g.leg_no = 3
	g._open_shop()
	await _wait(20)
	var fx: Array = GameData.fixtures()
	#  테이블 — 다섯 장씩 두 번(아홉 장을 다 본다)
	for batch in [[0, 1, 2, 3, 4], [5, 6, 7, 8]]:
		g.stock.clear()
		for k in batch:
			if k < fx.size():
				g.stock.append({"type": "fix", "d": fx[k], "cost": 15, "sold": false})
		g._drop_roll()
		g._drop_settle()
		await _wait(40)
		await _shot("photo_shop_%d" % int(batch[0]), 20)
	#  사탕·사진 칸 — 두 장
	g.cons = [fx[5].duplicate(), fx[0].duplicate()]
	await _shot("photo_hud", 10)
	#  컬렉션 — 사진 탭
	#  못 본 칸은 물음표라 그림이 안 보인다 — 전부 발견으로 그린다(저장은 안 만진다)
	g._dev_unlock_all()
	g.state = g.S.COLLECT
	g.collect_tab = 4
	g.collect_page = 0
	await _shot("photo_collect", 10)
	print("  찍음")
	quit(0)
