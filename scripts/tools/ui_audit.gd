extends SceneTree

# UI 훑기 — 화면을 하나씩 세우고 찍는다. 고치기 전에 **무엇이 문제인지**를
# 눈으로 먼저 보려고 만든 자다. 2026-09-13 사용자 물음 "전체적인 ui를 좀
# 개선할까?" 에 답하기 전에 돈다.
#
#   godot --path . --quit-after 1400 --script scripts/tools/ui_audit.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false


func _initialize() -> void:
	Save.path = "user://_ui_audit.cfg"
	Save.wipe()
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
	for i in 6:
		g._process(1.0 / 60.0)
	g.queue_redraw()
	var fr = g.get_node_or_null("Front")
	if fr != null:
		fr.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/ui_%s.png" % nm)
	print("  ui_%s" % nm)


func _run() -> void:
	for i in 10:
		g._process(1.0 / 60.0)
	print("\nUI 훑기 — 화면을 하나씩\n")

	g.state = g.S.TITLE
	await _shoot("01_title")

	g._open_newrun()
	await _shoot("02_newrun")

	g.state = g.S.COLLECT
	for t in 6:
		g.collect_tab = t
		g.collect_page = 0
		await _shoot("03_collect%d" % t)

	# 판 고르기
	g.state = g.S.TITLE
	g._new_run()
	await _shoot("04_leg")

	# 판 플레이 — 다트 몇 발 꽂아 둔다
	g.leg_no = 2
	g._start_leg()
	g.owned = []
	for it in GameData.items():
		if g.owned.size() < 3:
			g.owned.append(it.duplicate())
	g.cons = [GameData.candies()[0], GameData.fixtures()[0]]
	await _shoot("05_play")

	# 정산
	g.total = 9999
	g._finish_leg()
	await _shoot("06_clear")

	# 상점
	g.gold = 40
	g._open_shop()
	g._drop_settle()
	await _shoot("07_shop")

	# 보스 제약 고르기
	g.leg_no = 3
	g.state = g.S.STAGE
	g._stage_open() if g.has_method("_stage_open") else null
	await _shoot("08_stage")

	# 런 정보
	g.state = g.S.SHOP
	g.run_from = g.S.SHOP
	g.state = g.S.RUNINFO
	for t in 4:
		g.runinfo_tab = t
		await _shoot("09_runinfo%d" % t)

	# 설정
	g.pause_from = g.S.SHOP
	g.state = g.S.SETTINGS
	g.set_t = float(g.SET.t)
	await _shoot("10_settings")

	# 런 끝
	g.state = g.S.OVER
	await _shoot("11_over")

	print("\nshots/ui_*.png\n")
	quit(0)
