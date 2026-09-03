extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# 넓은 테이블 뱃지가 실제로 도는지 눈으로 본다. 자리 넷을 전제한 주석이
# 남아 있어(_table_draw), 여섯 개를 던지면 겹치는지 확인이 필요하다.

var g = null
var busy := false


func _initialize() -> void:
	Save.path = "user://_shot_wide.cfg"
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
	g._drop_settle()
	g._swap_skip()
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/" + name)
	print("저장: %s  매물 %d개" % [name, g.stock.size()])


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	g._new_run()
	g.gold = 40
	g._open_shop()
	await _shoot("shop_now.png")

	g.pending_tags.append({"kind": "shop", "v": 2, "n": "넓은 테이블"})
	g._open_shop()
	await _shoot("shop_wide.png")
	quit()
