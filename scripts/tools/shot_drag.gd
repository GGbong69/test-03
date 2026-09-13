extends SceneTree
const GameData = preload("res://scripts/data.gd")
var g = null
var busy := false
func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false
#  손 상태를 **_process 뒤에** 세운다. _process 안에 「창 밖에서 떼어
#  released 를 못 받은 경우의 안전망」이 있어서, 실제 버튼을 못 쥐는 자가
#  프레임을 돌리면 그 그물에 걸려 그 자리에서 놓아 버린다. 게임이 아니라
#  자의 한계라, 돌린 **뒤에** 손을 세우고 그대로 찍는다.
func _shoot(nm: String, at: Vector2) -> void:
	for i in 4:
		g._process(1.0 / 60.0)
	g.hand_st = g.H.CARRY
	g.hand_src = 4
	g.hand_i = 0
	g.hand_m = at
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)
func _run() -> void:
	for i in 20:
		g._process(1.0 / 60.0)
	g.state = g.S.TITLE
	g._new_run()
	g._click(g._leg_go().get_center())
	for k in 60:
		g._process(1.0 / 60.0)
	g.target = 99999
	g.cons = [GameData.candies()[2].duplicate(), GameData.fixture_of("v_cash")]
	await _shoot("drag_on", g.BC + Vector2(6.0, -4.0))
	await _shoot("drag_off", Vector2(150.0, 300.0))
	quit(0)
