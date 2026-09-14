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
func _shoot(nm: String) -> void:
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
	g.target = 1
	g.state = g.S.CONFIRM
	g.confirm_t = 99.0
	g.aim = g.BC
	for k in 600:
		g._process(1.0 / 60.0)
		if g.state == g.S.CLEAR:
			break
	print("정산 진입 · 내역 %d줄 · 골드 %d" % [g.clear_gold_detail.size(), g.gold])
	# 구르는 중간
	g.clear_t = 0.0
	for k in 22:
		g._process(1.0 / 60.0)
	await _shoot("clear_mid")
	# 다 끝난 뒤
	for k in 120:
		g._process(1.0 / 60.0)
	await _shoot("clear_end")
	print("끝났나: %s · 보이는 총액 %d / %d" % [g._clear_done(), g._clear_roll(), g.gold])
	quit(0)
