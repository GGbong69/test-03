extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# 제약 축마다 판이 실제로 어떻게 보이는지 찍는다. 한 장만 찍으면
# 놓친다 — 검정 리그 겹침을 그렇게 놓쳤다. 표의 모든 행을 돈다.
#
#   godot --path . --quit-after 2000 --script scripts/tools/mod_shots.gd

var g = null
var busy := false


func _initialize() -> void:
	Save.path = "user://_shot_mod.cfg"
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
	for m in GameData.modifiers():
		# 표가 만든 사전을 그대로 쓴다. 손으로 셋만 골라 담았더니 id 가 빠져
		# 상단바의 제약 아이콘이 매 프레임 터졌다 — 게임은 modifiers() 의
		# 행을 통째로 싣는다(_pick_stage 의 sp.d).
		g.active_mods = [m]
		g._start_leg()
		g._swap_skip()
		for i in 6:
			g._process(1.0 / 60.0)
			g.tip_a = 0.0
			g._swap_skip()
		g.queue_redraw()
		await process_frame
		await process_frame
		var name := "mod_%s.png" % m.id
		root.get_texture().get_image().save_png("res://shots/" + name)
		print("저장: %-16s %s — %s" % [name, m.n, m.d])
	quit()
