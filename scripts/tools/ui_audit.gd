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

	# 판 고르기 — **런을 실제로 연다.** 전에는 상태를 손으로 세워서 판이
	# 안 그려진 그림이 나왔고, 그래서 이 아래 두 화면을 못 봤다.
	g.state = g.S.TITLE
	g._new_run()
	g.owned = []
	for it in GameData.items():
		if g.owned.size() < 3:
			g.owned.append(it.duplicate())
	g.cons = [GameData.candies()[0], GameData.fixtures()[0]]
	for k in 30:
		g._process(1.0 / 60.0)
	await _shoot("04_leg")

	# 판 플레이 — 게임이 쓰는 문으로 들어가고 실제로 한 발 던진다.
	# 목표를 크게 올려 둔다. 안 올리면 첫 발이 판을 넘겨 버려서 이 자리가
	# 정산 화면을 찍는다 — 조준 화면을 여태 한 번도 못 본 이유가 그것이다.
	g._click(g._leg_go().get_center())
	for k in 60:
		g._process(1.0 / 60.0)
	g.target = 99999
	# 조준 중 — 게이지가 반쯤 찬 자리에서 멈춘다
	for k in 40:
		g._process(1.0 / 60.0)
	await _shoot("05a_aim")
	g.state = g.S.CONFIRM
	g.confirm_t = 99.0
	g.aim = g.BC + Vector2(18.0, -12.0)
	for k in 400:
		g._process(1.0 / 60.0)
		if g.state != g.S.CONFIRM and g.state != g.S.FLY and g.state != g.S.RESOLVE:
			break
	await _shoot("05_play")

	# 정산 — 목표를 낮춰 넘긴다
	g.target = 1
	g.state = g.S.CONFIRM
	g.confirm_t = 99.0
	g.aim = g.BC
	for k in 600:
		g._process(1.0 / 60.0)
		if g.state == g.S.CLEAR:
			break
	await _shoot("06_clear")

	# 상점
	g.gold = 40
	g._open_shop()
	g._drop_settle()
	await _shoot("07_shop")

	# 보스 카드 — **게임이 쓰는 문으로 연다.** 상태만 세우면 제약이 안
	# 굴려져서 카드에 아무것도 안 앉는다(제약 고르기 화면은 걷혔다).
	g.leg_no = 3
	g._open_leg()
	for k in 60:
		g._process(1.0 / 60.0)
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
	g.set_t = 1.0
	await _shoot("10_settings")

	# 런 끝 — 해금 줄이 서는 모양도 같이 본다.
	# **설정을 먼저 완전히 닫는다.** 앞에서 설정을 열어 둔 채로 상태만
	# 갈아 끼우면 set_t 가 안 잦아들어 흐림 판과 글줄이 이 화면 위에 남는다.
	g.pause_from = -1
	g.state = g.S.TITLE
	for k in 60:
		g._process(1.0 / 60.0)
	g.won = false
	g.run_unlocked = [{"k": "리그", "n": "초록 리그"},
			{"k": "다트통", "n": "여벌 다트통"}]
	g.over_t = 9.0
	g.state = g.S.OVER
	await _shoot("11_over")

	print("\nshots/ui_*.png\n")
	quit(0)
