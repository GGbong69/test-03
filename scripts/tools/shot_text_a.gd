extends SceneTree
# 그룹 A — 게임 중 HUD · 판 위의 글자 크기를 본다. 가장 붐비는 상태까지.
#   godot --path . --quit-after 3000 --script scripts/tools/shot_text_a.gd -- before
#   → shots/txta_<태그>_<이름>.png  (태그를 안 주면 now)
#
#  게임의 _process 는 끄고 여기서 한 프레임씩 민 뒤, 보고 싶은 값(keep)을
#  덮어쓰고 커서(pin)를 박는다 — 게임이 스프링·시계로 값을 되돌리기 전에 그린다.
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false
var pin := Vector2(-50.0, -50.0)
var keep := {}
var tag := "now"
var live := true       # 거짓이면 게임 시계를 안 민다(손 · 팩 · 카드가 제멋대로 끝나지 않게)


func _initialize() -> void:
	var ua := OS.get_cmdline_user_args()
	if ua.size() > 0:
		tag = String(ua[0])
	Save.gpath = "user://_shot_txta_g.cfg"
	Save.path = "user://_shot_txta.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if g != null and busy:
		_hold()
	if busy:
		return false
	busy = true
	_run()
	return false


func _hold() -> void:
	g._tutor_close()
	g.tutor_out = 0.0
	g.swap_live = false
	for k in keep.keys():
		g.set(k, keep[k])
	g.mouse_at = pin
	g.queue_redraw()


func _tick(n: int) -> void:
	for i in n:
		if live:
			g._process(1.0 / 60.0)
		_hold()
		await process_frame


func _shot(nm: String, frames := 12) -> void:
	await _tick(frames)
	root.get_texture().get_image().save_png("res://shots/txta_%s_%s.png" % [tag, nm])
	print("  shot %s" % nm)


func _item(id: String) -> Dictionary:
	for it in GameData.items():
		if String(it.id) == id:
			return it.duplicate()
	return GameData.items()[0].duplicate()


func _cons(id: String) -> Dictionary:
	for c in GameData.consumables():
		if String(c.id) == id:
			return c
	return GameData.consumables()[0]


func _run() -> void:
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g.set_process(false)
	await _tick(10)
	g._new_run()
	await _tick(20)

	# ── 1. 판 위 — 평범한 조준 ───────────────────────────
	g._start_leg()
	g.grip_t = 9.0
	g.owned = [_item("c01"), _item("c35")]
	g._panel_reset()
	g.cons = [_cons("v_moth")]
	g.gold = 12
	keep = {"state": g.S.AIM_V}
	await _shot("aim")

	# ── 2. 최악 — 제약 넷 · 동전 가득 · 사탕 가득 · 99999 ───
	var Dev = load("res://scripts/dev.gd")
	Dev._run(g, {"t": "act", "a": "worst"})
	g.owned[1] = _item("c48")
	g.owned[2] = _item("u06")
	g.owned[3] = _item("c35")
	g._panel_reset()
	g.cons = [_cons("v_moth"), _cons("v_par")]
	g.target = 99999
	g.total = 99999
	keep = {"state": g.S.PICK, "shown": 99999.0, "sealed": 0,
			"slot_hot": [0.0, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6]}
	await _shot("worst_pick")
	keep = {"state": g.S.AIM_H, "shown": 99999.0, "sealed": 0, "darts_left": 12}
	await _shot("worst_aim")
	keep = {"state": g.S.PICK, "shown": 99999.0, "sealed": -1, "gold": 999}
	await _shot("pick_gold3")
	keep["gold"] = 9999
	await _shot("pick_gold4")

	# ── 3. 판매 단추 — 고른 동전 밑 · 얹힘 ────────────────
	keep = {"state": g.S.PICK, "shown": 120.0, "sealed": -1, "sell_sel": 2,
			"slot_hot": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]}
	pin = Vector2(-50.0, -50.0)
	await _shot("sell")
	pin = g._sell_btn_rect().get_center()
	await _shot("sell_hover")
	pin = g._hud_btn_rect(0).get_center()
	keep["sell_sel"] = -1
	await _shot("hud_hover")
	pin = g._cons_rect(0).get_center()
	await _shot("cons_hover")
	pin = Vector2(-50.0, -50.0)

	# ── 4. 점수 카드 ─────────────────────────────────────
	live = false
	var cb := {"state": g.S.RESOLVE, "shown": 120.0, "card_p": 1.0, "card_v": 0.0,
			"card_target": 1.0, "card_side": 1, "card_mode": 0,
			"cur_chip": 9999, "cur_mult": 999, "calc_lit": false, "roll_t": -1.0,
			"card_item": String(_item("c48").n), "score_mode": "std",
			"calc_flash": 0.0, "total_flash": 0.0}
	keep = cb.duplicate()
	await _shot("card_std")
	keep = cb.duplicate()
	keep["calc_lit"] = true
	keep["score_mode"] = "bal"
	keep["calc_c"] = 9999
	keep["calc_m"] = 999
	keep["cur_chip"] = 5499
	keep["cur_mult"] = 5499
	await _shot("card_bal")
	keep["score_mode"] = "rand"
	await _shot("card_rand")
	keep = cb.duplicate()
	keep["card_mode"] = 1
	keep["last_gain"] = 99999
	keep["score_mode"] = "bal"
	keep["calc_c"] = 9999
	keep["calc_m"] = 999
	keep["cur_chip"] = 5499
	keep["cur_mult"] = 5499
	await _shot("card_total")

	# ── 5. 가운데에 놓아 쓰기 — 이름 · 거절 ──────────────
	g.cons = [_cons("v_moth"), _cons("v_par")]
	keep = {"state": g.S.PICK, "shown": 120.0, "card_p": 0.0, "hand_st": g.H.CARRY,
			"hand_src": 4, "hand_i": 0, "hand_m": g.BC}
	await _shot("use_on")
	keep["hand_i"] = 1
	await _shot("use_block")
	keep = {"state": g.S.PICK, "shown": 120.0, "hand_st": g.H.NONE, "hand_i": -1,
			"card_p": 0.0}
	await _tick(3)
	live = true
	g.photo = ""
	g.photo_rack = ""
	g.photo_rack_i = -1

	# ── 6. 아래 안내 줄 — 가장 긴 것 ─────────────────────
	g.aim_mode = "kick"
	keep = {"state": g.S.AIM_V, "shown": 120.0}
	await _shot("hint_kick")
	g.aim_mode = "std"

	# ── 7. 상점 — 자금판 이자 줄 · 진행 · 판 위 값표 ─────
	keep = {}
	g.leg_no = 2
	g._open_shop()
	await _tick(30)
	g.gold = 999
	keep = {"state": g.S.SHOP, "gold": 999, "sealed": -1}
	await _shot("shop", 30)
	keep["sell_sel"] = 1
	await _shot("shop_sel")
	keep["sell_sel"] = -1
	keep["leg_no"] = GameData.legs_n() - 1
	await _shot("shop_last")
	keep["leg_no"] = 2
	live = false
	keep["boost_card"] = GameData.boosters()[GameData.boosters().size() - 1]
	keep["boost_t"] = float(g.BOOST.rise)
	await _shot("boost_rise")
	keep["boost_t"] = float(g.BOOST.rise) + float(g.BOOST.tear) * 0.9
	await _shot("boost")
	keep.erase("boost_t")
	keep.erase("boost_card")
	g.boost_t = -1.0
	g.boost_card = {}
	live = true

	# ── 8. 판 고르기 · 정산 ───────────────────────────────
	keep = {}
	g.leg_no = 3
	g._open_leg()
	g.state = g.S.LEG
	g.leg_t = 9.0
	await _shot("leg", 30)
	g.clear_gold_detail = [
		{"n": "클리어 보상", "v": 5},
		{"n": "남은 다트 6개", "v": 6},
		{"n": "이자", "v": 5},
		{"n": "현상금", "v": 25},
		{"n": String(_item("c48").n), "v": 120},
		{"n": String(_item("u06").n), "v": 999},
	]
	g.gold = 99999
	keep = {"state": g.S.CLEAR, "clear_t": 99.0}
	await _shot("clear", 20)
	g.clear_gold_detail = [
		{"n": "클리어 보상", "v": 3},
		{"n": "남은 다트 2개", "v": 2},
		{"n": "이자", "v": 0},
	]
	g.gold = 47
	await _shot("clear_few", 20)
	g.clear_gold_detail = []
	for k in 9:
		g.clear_gold_detail.append({"n": String(_item("c48").n) if k > 2 else "남은 다트 6개", "v": 99 + k})
	g.gold = 99999
	await _shot("clear_many", 20)
	print("  찍음")
	quit(0)
