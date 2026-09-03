extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# 사진 선반을 눈으로 본다 — 걸린 상점, 못 사는 상점, 넓어진 테이블, 늘어난 벽.
#
#   godot --path . --quit-after 900 --script scripts/tools/fixture_shots.gd

var g = null
var busy := false


func _initialize() -> void:
	Save.path = "user://_shot_vou.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _process(_d: float) -> bool:
	if g != null:
		g.set_process(false)
	if busy:
		return false
	busy = true
	_run()
	return false


func _shoot(name: String) -> void:
	for i in 30:
		g._process(1.0 / 60.0)
		g.tip_a = 0.0
		g._swap_skip()
	g._drop_settle()
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/" + name)
	print("저장: %-22s 사진 %d개" % [name, GameData.fixtures_own.size()])


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	GameData.fixture_clear()
	g._new_run()
	g._swap_skip()

	# 걸린 선반 — 살 수 있을 때
	g.leg_no = 1
	g.gold = 40
	g.shelf_round = 0
	g._open_shop()
	await _shoot("vou_shelf.png")

	# 못 살 때
	g.gold = 2
	g.queue_redraw()
	await _shoot("vou_poor.png")

	# 다 사고 난 테이블 — 진열대 둘이면 여섯 칸
	GameData.fixture_set(["v_shelf", "v_shelf2", "v_mag"])
	g.gold = 40
	g.shelf_round = 0
	g._open_shop()
	await _shoot("vou_wide.png")

	# 늘어난 벽 — 다트 아홉
	g.leg_no = 1
	g._start_leg()
	g._swap_skip()
	while g.remaining.size() < 9:
		g.remaining.append(g.remaining[0])
	g.grip_n = g.remaining.size()
	g.grip_slot.clear()
	g.grip_hov.clear()
	for k in g.grip_n:
		g.grip_slot.append(k)
		g.grip_hov.append(0.0)
	await _shoot("vou_grip.png")
	quit()
