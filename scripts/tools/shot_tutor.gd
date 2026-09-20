extends SceneTree
# 배움 걸음이 화면에서 어떻게 보이는가 — 조명·말상자·느린 시간.
#   godot --path . --quit-after 3000 --script scripts/tools/shot_tutor.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false

func _initialize() -> void:
	Save.gpath = "user://_shot_tut_g.cfg"
	Save.path = "user://_shot_tut.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)

func _process(_d: float) -> bool:
	if busy: return false
	busy = true
	_run()
	return false

func _wait(n: int) -> void:
	for i in n:
		await process_frame

func _shot(nm: String) -> void:
	g.queue_redraw()
	await process_frame
	await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)

func _step(id: String, k: int, nm: String) -> void:
	g.tutor_q.clear()
	g.tutor_id = id
	g.tutor_i = k
	g.tutor_t = 9.0          # 다 떠 있는 상태
	g.tutor_out = 0.0
	await _wait(3)
	await _shot(nm)
	print("%s %d · 배율 ×%.2f · %s" % [id, k + 1, g._tutor_slow(), g._tutor_text()])

func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀"); quit(0); return
	g.state = g.S.TITLE
	g._new_run()
	g.gold = 40
	g.leg_no = 2
	g._open_shop()
	await _wait(70)
	g._drop_settle()
	Save.forget_all()
	await _step("u_shop", 1, "tut_buy")      # 오른쪽 창구
	await _step("u_sell", 0, "tut_sell")     # 왼쪽 창구
	await _step("u_rack", 1, "tut_rack")     # 동전 슬롯
	await _step("u_give", 0, "tut_give")     # 상인
	#  판 위의 셋 — 여기 그림이 **한 장도 없었다.** 그래서 u_score 셋째 걸음의
	#  과녁이 자금판(지갑)을 가리키는 것을 아무도 못 봤다. 사용자가 화면을
	#  보내며 「튜토리얼이 이게 맞아?」라고 물어서야 드러났다(2026-09-20).
	g._begin_leg()
	await _wait(12)
	await _step("u_score", 0, "tut_score1")  # 판
	await _step("u_score", 1, "tut_score2")  # 동전 슬롯
	await _step("u_score", 2, "tut_score3")  # 이 판의 몫 — 상단 바
	print("끝")
	quit(0)
