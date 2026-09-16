extends SceneTree
# 제목 판 이스터에그를 눈으로 본다 — 금 셋 단계 · 깨지는 중 · 오르는 중.
#   godot --path . --quit-after 1500 --script scripts/tools/shot_egg.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false
var pin := Vector2(4.0, 4.0)


func _initialize() -> void:
	Save.gpath = "user://_shot_egg_g.cfg"
	Save.path = "user://_shot_egg.cfg"
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


#  게임 시간을 손으로 민다(shot_title 과 같은 까닭).
func _step(n: int) -> void:
	for i in n:
		g._title_tick(1.0 / 60.0)
	await process_frame


func _shot(nm: String) -> void:
	g.mouse_at = pin
	g.queue_redraw()
	await process_frame
	g.mouse_at = pin
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
	await _wait(20)
	for n in [8, 18, 29]:
		g.egg_streak = n
		await _step(90)
		g.shake = 0.0
		await _shot("egg_crack_%02d" % n)
	g._ttl_throw(g.BC)
	await _step(18)
	await _step(8)
	g.shake = 0.0
	g.screen_flash = 0.0
	await _shot("egg_burst")
	await _step(22)
	g.shake = 0.0
	await _shot("egg_fly")
	await _step(int((float(g.EGG.fly) + float(g.EGG.hold)) * 60.0) - 50 + 20)
	g.shake = 0.0
	await _shot("egg_rise")
	await _step(80)
	g.shake = 0.0
	g.board_punch = 0.0
	await _shot("egg_new")
	print("  찍음")
	quit(0)
