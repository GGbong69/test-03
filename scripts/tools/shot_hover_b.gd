extends SceneTree
# 얹힘 B 묶음 — HUD 첫 줄 · 동전 슬롯 · 사탕·사진 칸 · 벽 다트 · 덮인 화면.
# 같은 자리를 안 얹은 것 · 얹은 것 · 누른 것으로 한 장씩.
#   godot --path . --quit-after 3000 --script scripts/tools/shot_hover_b.gd
#
# 커서는 매 프레임 핀으로 박는다(shot_hover.gd 와 같다) — 게임이 입력으로
# mouse_at 을 덮는다. 벽의 뽑힘(grip_hov)은 실제 커서(_cursor)를 보므로
# 그 값도 같이 박는다. 누름은 손 상태(ARMED)를 박아 흉내 낸다 — 그동안은
# 게임의 _process 를 세운다. 안 세우면 「창 밖에서 뗀 안전망」(_hand_update)이
# 실제 마우스 단추가 안 눌린 것을 보고 매 프레임 떼어 버린다(팔고 · 쓰고).
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false
var pin := Vector2(-50.0, -50.0)
var grip := -1          # 뽑아 둘 자루. -1 이면 안 건드린다
var arm := -1           # 누른 채 둘 손 갈래(hand_src). -1 이면 손을 놓는다
var arm_i := -1


func _initialize() -> void:
	Save.gpath = "user://_shot_hovb_g.cfg"
	Save.path = "user://_shot_hovb.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if busy:
		_pin()
		return false
	busy = true
	_run()
	return false


func _pin() -> void:
	g.mouse_at = pin
	if grip >= 0:
		for k in g.grip_hov.size():
			g.grip_hov[k] = 1.0 if k == grip else 0.0
	if arm >= 0:
		g.set_process(false)
		g.hand_st = g.H.ARMED
		g.hand_src = arm
		g.hand_i = arm_i
		g.hand_p0 = pin
		g.hand_m = pin
		g.queue_redraw()


func _wait(n: int) -> void:
	for i in n:
		g._tutor_close()
		g.tutor_out = 0.0
		g.swap_live = false
		_pin()
		await process_frame


func _shot(nm: String, at: Vector2, frames := 24) -> void:
	pin = at
	await _wait(frames)
	root.get_texture().get_image().save_png("res://shots/%s.png" % nm)
	print("  %-20s hot '%s' · 손 %d/%d · 사진 '%s'/'%s'" % [nm, g.ui_hot,
			g.hand_st, g.hand_src, g.photo, g.photo_rack])


func _free_hand() -> void:
	arm = -1
	arm_i = -1
	g.hand_st = g.H.NONE
	g.hand_src = 0
	g.hand_i = -1
	g.set_process(true)


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	var away := Vector2(-50.0, -50.0)
	g._new_run()
	await _wait(30)
	g.leg_t = 9.0
	g.owned = []
	for i in 3:
		var c: Dictionary = GameData.items()[i].duplicate()
		c.gs = 0
		c.bought = 1
		g.owned.append(c)
	g._panel_reset()
	g.cons = [GameData.candies()[0].duplicate(), GameData.fixtures()[5].duplicate()]

	# ── 판 고르기(LEG) — 동전 슬롯 · 사탕·사진 칸 · 판매 단추 ─────────
	await _shot("hb_leg_none", away)
	await _shot("hb_rack_hov", g._slot_rect(1).get_center())
	arm = 1
	arm_i = 1
	await _shot("hb_rack_press", g._slot_rect(1).get_center())
	_free_hand()
	await _shot("hb_cons_hov", g._cons_rect(1).get_center())
	arm = 4
	arm_i = 1
	await _shot("hb_cons_press", g._cons_rect(1).get_center())
	_free_hand()
	g.sell_sel = 0
	g.sell_t = 0.0
	await _shot("hb_sell_none", away)
	await _shot("hb_sell_hov", g._sell_btn_rect().get_center())
	arm = 5
	arm_i = 0
	await _shot("hb_sell_press", g._sell_btn_rect().get_center())
	_free_hand()
	g.sell_sel = -1

	# ── 판 위(PICK) — 벽 다트 · 상단 띠 제약 · 사진으로 고르기 ──
	g._start_leg()
	g.state = g.S.PICK
	g.active_mods = GameData.modifiers().slice(0, 3)
	await _wait(90)         # 자루가 다 날아와 꽂힐 때까지
	await _shot("hb_pick_none", away)
	grip = 1
	await _shot("hb_grip_pick", g._mag_rect(1).get_center())
	grip = -1
	await _shot("hb_mod_hov", Rect2(float(g.LAY.bar_mod) - 4.0, 0.0, 60.0, 18.0).get_center())
	g.photo_rack = "burn"
	await _shot("hb_rack_burn", g._slot_rect(0).get_center())
	g.photo_rack = "clone"
	await _shot("hb_rack_clone", g._slot_rect(0).get_center())
	#  고르는 중에는 다른 단추가 안 뜬다 — 사탕·사진 칸에 얹어 본다
	await _shot("hb_rack_clone_cons", g._cons_rect(0).get_center())
	g.photo_rack = ""

	# ── 조준(AIM_V) — 안 고른 자루가 뽑혀 나오며 밝아진다 ──────
	g._pick_dart(0)
	await _wait(20)
	await _shot("hb_aim_none", away)
	grip = 2
	await _shot("hb_grip_aim", g._mag_rect(2).get_center())
	grip = -1

	# ── 덮인 화면 — 흐림 판 뒤의 리롤이 안 뜬다 ────────────────
	g._open_shop()
	await _wait(40)
	var under := Vector2(50.0, 300.0)
	await _shot("hb_shop_reroll", under)
	#  상점의 태우기는 테이블만 갈아 끼운다 — 리롤은 그대로 눌리므로 뜬다
	g._photo_open("burn", 2)
	await _shot("hb_shop_burn_reroll", under)
	g._photo_close()
	#  미리보기는 화면을 덮는다 — 뒤의 리롤은 안 뜬다
	g.photo = "peek"
	await _shot("hb_under_peek", under)
	g.photo = ""
	g.run_from = g.S.SHOP
	g.state = g.S.RUNINFO
	await _shot("hb_under_runinfo", under)
	g.state = g.S.SHOP
	g.pause_from = g.S.SHOP
	g.state = g.S.SETTINGS
	await _shot("hb_under_settings", under)
	g.state = g.S.SHOP
	g.pause_from = -1
	print("  찍음")
	quit(0)
