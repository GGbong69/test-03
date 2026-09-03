extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# 툴팁을 갈래마다 찍는다. 툴팁은 커서가 있어야 뜨는데 촬영에는 커서가
# 없어서 여태 한 장도 안 찍혀 있었다 — 흰 테두리 어긋남이 그래서 살아남았다.
# _tip_build 를 직접 불러 세운다.
#
#   godot --path . --quit-after 900 --script scripts/tools/tip_shots.gd

var g = null
var busy := false


func _initialize() -> void:
	Save.path = "user://_shot_tip.cfg"
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


func _shoot(name: String, hit: Dictionary) -> void:
	for i in 4:
		g._process(1.0 / 60.0)
		g._swap_skip()
	g._tip_build(hit)
	g.tip_a = 1.0
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/" + name)
	print("저장: %-18s %-6s %s" % [name, g.tip_tag, g.tip_title])


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	GameData.fixture_clear()
	g._new_run()
	g._swap_skip()

	# 테이블 — 한 자리에 네 갈래가 섞여 뜬다
	g.leg_no = 1
	g.gold = 60
	g._open_shop()
	g._swap_skip()
	g._drop_settle()
	for k in g.stock.size():
		await _shoot("tip_stock%d.png" % k, {"k": "stock", "i": k})

	# 보스 제약
	g.leg_no = GameData.legs_per_round()
	g._open_stage()
	g.stage_t = 9.0
	await _shoot("tip_stage.png", {"k": "stage", "i": 1})

	# 든 사탕 — 산 뒤로는 아무 데서도 효과를 안 말하던 자리다
	g.leg_no = 1
	g._open_shop()
	g._swap_skip()
	g.cons.clear()
	for c in GameData.consumables():
		if g.cons.size() < 2:
			g.cons.append(c)
	await _shoot("tip_held.png", {"k": "held", "i": 0})

	# 건너뛰기 뱃지 — 버튼에는 효과 한 줄, 툴팁에 이름과 때
	g.leg_no = 1
	g._open_leg()
	g._swap_skip()
	if g.leg_tag.is_empty():
		g.leg_tag = GameData.tags()[0]
	await _shoot("tip_tag.png", {"k": "tag", "i": 0})

	# 쌓아 둔 뱃지
	g.pending_tags.clear()
	for t in GameData.tags():
		if String(t.get("when", "now")) != "now" and g.pending_tags.size() < 2:
			g._take_tag(t)
	await _shoot("tip_pend.png", {"k": "pend", "i": 0})

	# 탄창 자루
	g.leg_no = 1
	g._start_leg()
	g._swap_skip()
	await _shoot("tip_mag.png", {"k": "mag", "i": 0})

	# 조준 동전 — 이 장들은 조건도 배수도 없고 조준이 곧 효과다.
	# 문구가 길어 접힐 수 있으므로 눈으로 확인할 자리가 필요하다.
	for it in GameData.items():
		if String(it.get("aim", "")) == "":
			continue
		g.owned = [it.duplicate()]
		g.sealed = -1
		g._panel_reset()
		await _shoot("tip_aim_%s.png" % it.get("aim"), {"k": "rack", "i": 0})
	quit()
