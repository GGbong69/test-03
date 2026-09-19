extends SceneTree
# 다섯 관문을 눈으로 대 본다 — 겨눔 띠 · 판매 단추 새 자리 · 런 끝 잠금 ·
# 얕은 층 툴팁 · 누름 고리.
#   godot --path . --quit-after 1500 --script scripts/tools/shot_five.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_shot_five_g.cfg"
	Save.path = "user://_shot_five.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if busy:
		return false
	busy = true
	_run()
	return false


func _wait(n: int) -> void:
	for i in n:
		await process_frame


func _calm() -> void:
	g._tutor_close()
	g.tutor_id = ""
	g.tutor_q.clear()
	g.tutor_out = 0.0
	g.swap_live = false
	g.photo = ""
	g.photo_rack = ""


func _shot(nm: String, frames := 30) -> void:
	for i in frames:
		_calm()
		g.queue_redraw()
		var fr: Node = g.get_node_or_null("Front")
		if fr != null:
			fr.queue_redraw()
		await process_frame
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)
	print("  찍음 %s" % nm)


#  얹힘은 **진짜 커서**로만 선다 — _tip_update 는 뷰포트가 있으면
#  get_local_mouse_position 을 묻지 mouse_at 을 안 본다. 창은 1280x720 에
#  논리 640x360 이라 두 배로 민다.
func _hover(p: Vector2) -> void:
	g.mouse_at = p
	Input.warp_mouse((p + g.view_pad) * 2.0)


func _give(n: int) -> void:
	g.owned = []
	for it in GameData.items():
		g.owned.append((it as Dictionary).duplicate())
		if g.owned.size() >= n:
			break
	g._panel_reset()


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g._new_run()
	await _wait(10)
	_calm()
	g._begin_leg()
	g._swap_skip()
	await _wait(10)
	_calm()

	# ── ② 설정 「로비로 나가기」 — 겨눔 전 · 겨눔 뒤 ─────────
	g.pause_from = g.S.PICK
	g.state = g.S.SETTINGS
	g.set_t = 1.0
	g.lobby_arm = false
	g.set_sel = (g._set_rows() as Array).find("lobby")
	_hover(Vector2(-50.0, -50.0))
	await _shot("five_2a_lobby_off")
	g.lobby_arm = true
	g.lobby_arm_t = 0.0
	await _shot("five_2b_lobby_armed")
	g.lobby_arm = false
	g.pause_from = -1

	# ── ④ 판매 단추 새 자리 ─────────────────────────
	g.state = g.S.PICK
	_give(3)
	g.sell_sel = 0
	g.sell_t = 0.0
	_hover((g._slot_rect(0) as Rect2).get_center())
	await _shot("five_4_sell_btn")

	# ── ⑤ 툴팁 두 층 ─────────────────────────────
	g.sell_sel = -1
	g.hover_live = true
	_hover((g._slot_rect(1) as Rect2).get_center())
	g.tip_a = 1.0
	await _shot("five_5a_tip_deep")
	#  얕은 층 — 손가락인 척 + 핀. 매 프레임 _tip_update 가 이 둘을 지킨다.
	g.hover_live = false
	g.tip_pin = {"k": "rack", "i": 1, "st": g.state}
	g.tip_pin_at = (g._slot_rect(1) as Rect2).get_center()
	g.tip_lite = true
	_hover(Vector2(-50.0, -50.0))
	await _shot("five_5b_tip_lite")
	#  누름 고리가 차오르는 중 — 절반쯤. **게임의 _process 를 끈다** —
	#  안 끄면 매 프레임 hold_a 가 0 으로 되돌아가 고리가 바닥값(0.08)으로 선다.
	g.tip_pin = {}
	g.set_process(false)
	g.hand_st = g.H.ARMED
	g.hand_src = 1
	g.hand_i = 1
	g.hold_a = 0.55
	await _shot("five_5c_hold_ring", 3)
	g.hold_a = 0.08
	await _shot("five_5d_hold_start", 3)
	g.set_process(true)
	g.hand_st = g.H.NONE
	g.hold_a = 0.0
	g.hover_live = true

	# ── ③ 런 끝 — 잠긴 동안 · 풀린 뒤 ────────────────
	_give(4)
	g.state = g.S.OVER
	g.won = false
	g.over_t = 0.12
	await _shot("five_3a_over_locked", 1)
	g.over_t = 2.0
	await _shot("five_3b_over_live")
	#  런 끝 동전 툴팁 — 상단 슬롯이 아니라 그 동전에 붙는가.
	_hover((g._over_coin_rect(2) as Rect2).get_center())
	g.tip_a = 1.0
	await _shot("five_3c_over_tip")
	quit(0)
