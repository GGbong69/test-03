extends SceneTree
# 판 선택·제약 선택을 눈으로 본다. 커서를 카드 위에 얹어 한 장을 세운다.
#   godot --path . --quit-after 600 --script scripts/tools/shot_quad.gd
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
func _hover(p: Vector2, n: int) -> void:
	g.mouse_at = p
	for k in n:
		g._tip_update(1.0 / 60.0)
		g._process(1.0 / 60.0)
		g.mouse_at = p
func _run() -> void:
	for i in 20:
		g._process(1.0 / 60.0)
	g.state = g.S.TITLE
	g._new_run()
	for k in 60:
		g._process(1.0 / 60.0)
	# ── 판 선택 ──
	print("상태 %d · 판 %d" % [g.state, g.leg_no])
	_hover(g._row_rect(0, GameData.legs_per_round()).get_center(), 40)
	await _shoot("quad_leg0")
	_hover(g._row_rect(2, GameData.legs_per_round()).get_center(), 40)
	await _shoot("quad_leg2")
	# ── 제약 선택 ── 보스 판에서만 깔린다
	g.leg_no = GameData.legs_per_round()
	g._open_stage()
	for k in 60:
		g._process(1.0 / 60.0)
	_hover(g._stage_rect(1).get_center(), 40)
	await _shoot("quad_stage1")
	_hover(g._stage_rect(0).get_center(), 40)
	await _shoot("quad_stage0")
	print("찍었다")
	quit(0)
