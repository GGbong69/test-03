extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# 건너뛴 뒤의 판 선택 화면 — 지난 자리가 남는지 본다.
var g = null
var busy := false


func _initialize() -> void:
	Save.path = "user://_shot_sk.cfg"
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


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	g._new_run()
	g._swap_skip()
	g._skip_blind()          # 작은 판을 건너뛴다
	g._swap_skip()
	g.blind_t = 9.0
	for i in 6:
		g._process(1.0 / 60.0)
		g.tip_a = 0.0
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/skip_past.png")
	print("저장: skip_past.png  판 %d · 건너뛴 판 %s" % [g.round_no, g.blind_skipped])
	quit()
