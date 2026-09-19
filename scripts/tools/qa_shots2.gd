extends SceneTree

# 2단계 화면 검사. 컬렉션 여섯 탭과 설명창을 찍는다.
#   godot --path . --quit-after 900 --script scripts/tools/qa_shots2.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false


func _initialize() -> void:
	Save.path = "user://_qa_s2.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _shoot(name: String) -> void:
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/" + name)
	print("저장: %s" % name)


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	g._new_run()
	g._swap_skip()
	for i in 20:
		g._process(1.0 / 60.0)

	# 컬렉션 여섯 탭
	#  못 본 칸은 물음표라 그림이 안 보인다 — 전부 발견으로 그린다(저장은 안 만진다)
	g._dev_unlock_all()
	g.state = g.S.COLLECT
	for t in 6:
		g.collect_tab = t
		g.collect_page = 0
		g.tip_a = 0.0
		g._tip_clear()
		await _shoot("s2_col_%d.png" % t)

	# 설명창 — 태그가 둘인 동전(조건 있는 것)
	g.state = g.S.COLLECT
	g.collect_tab = 0
	for i in GameData.items().size():
		var it: Dictionary = GameData.items()[i]
		if String(it.get("c", "")) == "always" or String(it.get("c", "")) == "":
			continue
		g.collect_page = i / 24
		g._tip_build({"k": "citem", "i": i})
		g.tip_a = 1.0
		await _shoot("s2_tip_coin.png")
		break

	# 확률이 든 동전
	for i in GameData.items().size():
		if String(GameData.items()[i].n) == "유리 대포":
			g.collect_page = i / 24
			g._tip_build({"k": "citem", "i": i})
			g.tip_a = 1.0
			await _shoot("s2_tip_odds.png")
			break

	# 다트 · 사진
	g.collect_tab = 2
	g.collect_page = 0
	g._tip_build({"k": "cdart", "i": 1})
	g.tip_a = 1.0
	await _shoot("s2_tip_dart.png")
	g.collect_tab = 4
	g._tip_build({"k": "cfix", "i": 4})
	g.tip_a = 1.0
	await _shoot("s2_tip_fix.png")

	quit(0)
