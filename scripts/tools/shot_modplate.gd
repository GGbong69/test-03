extends SceneTree
# 낀 보드 확장 명판 — 던지는 화면 오른쪽 아래. 평소 · 올려 툴팁 · 조준 중 점수 카드와 같이.
#   godot --path . --quit-after 3000 --script scripts/tools/shot_modplate.gd
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false
var pin := Vector2(-50.0, -50.0)


func _initialize() -> void:
	Save.gpath = "user://_shot_mp_g.cfg"
	Save.path = "user://_shot_mp.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if g != null:
		g.mouse_at = pin
	if busy: return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		g._tutor_close()
		g.tutor_out = 0.0
		await process_frame


func _leg(mods: Array) -> void:
	g.mods_own = mods
	g._board_bake()
	g._start_leg()
	g._swap_skip()
	g.state = g.S.PICK
	g._pick_dart(0)
	await _wait(20)


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		quit(0)
		return
	g._new_run()
	await _wait(20)
	for id in ["arst", "pang", "dnut"]:
		pin = Vector2(-50.0, -50.0)
		await _leg([id])
		root.get_texture().get_image().save_png("res://shots/mplate_%s.png" % id)
	pin = g._modplate_rect().get_center()
	#  툴팁은 OS 커서(get_local_mouse_position)를 읽는다 — 게임의 매 프레임 갱신을 끄고
	#  못 박은 자리로 직접 세운다
	g.set_process(false)
	for f in 30:
		g._tip_build(g._tip_hit(pin))
		g.tip_a = 1.0
		g.queue_redraw()
		await process_frame
	root.get_texture().get_image().save_png("res://shots/mplate_hover.png")
	print("  찍음")
	quit(0)
