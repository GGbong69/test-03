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
			"calc_flash": 0.0, "total_flash": 0.0,
			# 카드 춤 축 아홉을 같이 못 박는다. 안 박으면 여섯 컷이 매번 다른
			# 프레임으로 찍혀 **전후 비교가 죽는다** — 코드가 아니라 자가
			# 망가지는 것이라 한참 뒤에 안다(2026-09-18).
			# gain_roll 을 total_flash 와 **다른 축**으로 뺀 것이 이 때문이다:
			# 굴림 시계를 total_flash 에 물렸으면 card_total_flash 컷이 "+0" 으로
			# 찍혀 컷의 뜻이 바뀐다. 축을 가르면 여섯 컷이 한 픽셀도 안 바뀐다.
			"card_pop": 0.0, "card_vel": 0.0, "chip_j": 0.0, "mult_j": 0.0,
			"chip_amt": 0.30, "mult_amt": 0.30, "card_burst": 0.0,
			"gain_roll": 0.0, "card_jrate": 4.0}
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
	#  달아오른 순간 — 저울 두 수가 한 번 부푼다(24 × 1.45) · 총점이 부푼다(36 × 1.55)
	#
	#  **시계를 1.0 이 아니라 0.662 에 꽂는다**(2026-09-18). 춤이 생기면서 시계 1.0 의
	#  뜻이 「다 부풀었다」에서 「막 시작했다(예비 눌림 직전)」로 바뀌었다 — 봉우리는
	#  u = 1 − f = 0.338, 곧 f = 0.662 다. 1.0 로 두면 이 두 컷이 안 부푼 카드를 찍어
	#  **컷의 뜻이 바뀐다.** 크기 상한은 그대로라, 이렇게 꽂으면 고치기 전 여섯 장과
	#  픽셀 단위로 같은 그림이 다시 나온다 — 그게 이 두 컷이 지키는 것이다
	#  (칸 24 × 1.45 = 34 · 총점 36 × 1.54 = 55).
	var f_top := 0.662
	keep = cb.duplicate()
	keep["calc_lit"] = true
	keep["score_mode"] = "bal"
	keep["calc_c"] = 9999
	keep["calc_m"] = 999
	keep["cur_chip"] = 5499
	keep["cur_mult"] = 5499
	#  색은 calc_flash(1.0 이 가장 희다) · 크기는 chip_j·mult_j(0.662 가 봉우리).
	#  두 축이 갈라져 있어 한 프레임에 둘 다 꼭대기로 세울 수 있다.
	keep["calc_flash"] = 1.0
	keep["chip_j"] = f_top
	keep["mult_j"] = f_top
	keep["chip_amt"] = 0.45
	keep["mult_amt"] = 0.45
	await _shot("card_flash")
	keep = cb.duplicate()
	keep["calc_lit"] = true
	keep["score_mode"] = "bal"
	keep["calc_c"] = 9999
	keep["calc_m"] = 999
	keep["cur_chip"] = 5499
	keep["cur_mult"] = 5499
	keep["card_mode"] = 1
	keep["last_gain"] = 99999
	keep["total_flash"] = f_top
	await _shot("card_total_flash")

	# ── 5. 가운데에 놓아 쓰기 — 이름 · 거절 ──────────────
	g.cons = [_cons("v_moth"), _cons("v_par")]
	keep = {"state": g.S.PICK, "shown": 120.0, "card_p": 0.0, "hand_st": g.H.CARRY,
			"hand_src": 4, "hand_i": 0, "hand_m": g.BC}
	await _shot("use_on")
	keep["hand_i"] = 1
	await _shot("use_block")

	# ── 5-1. 떠오르는 글자 — 크기 다섯 단(10 · 12 · 20 · 24) ─────
	#  t 0.4 면 튀어 오름(exp(-12t))이 끝나 멎은 크기로 선다.
	var pp := []
	for e in [[g.BC + Vector2(0.0, -38.0), "불스아이", g.C_ACC, 24],
			[g.BC + Vector2(0.0, 40.0), "목표 달성", g.C_ACC, 24],
			[g.BC + Vector2(-110.0, -10.0), "트리플", g.C_ACC, 20],
			[g.BC + Vector2(110.0, -10.0), "아우터 불", g.C_GREEN.lightened(0.55), 20],
			[g.BC + Vector2(-110.0, 90.0), "더블", g.C_ACC, 12],
			[g.BC + Vector2(110.0, 90.0), "배수 +12", g.C_MULT, 20],
			[g._slot_rect(0).get_center() + Vector2(0.0, 22.0), "순서 변경", g.C_TXT, 10],
			[g._slot_rect(3).get_center() + Vector2(0.0, 24.0),
					"%s — 실패를 막았다" % String(_item("c48").n), g.C_ACC, 12]]:
		pp.append({"p": e[0], "txt": e[1], "c": e[2], "sz": e[3],
				"t": 0.4, "life": 4.0})
	keep = {"state": g.S.PICK, "shown": 120.0, "card_p": 0.0, "hand_st": g.H.NONE,
			"hand_i": -1, "pops": pp}
	await _shot("pops")
	g.pops = []
	keep = {"state": g.S.PICK, "shown": 120.0, "hand_st": g.H.NONE, "hand_i": -1,
			"card_p": 0.0}
	await _tick(3)
	live = true
	g.photo = ""
	g.photo_rack = ""
	g.photo_rack_i = -1

	# ── 6. 아래 안내 줄 — 가장 긴 것 ─────────────────────
	g.aim_mode = "kick"
	#  카드를 내린다(2026-09-18). 앞의 카드 컷들이 card_target 을 1 로 올려 둔 채라
	#  여기서 card_p 를 안 박으면 「+99999」가 든 카드가 안내 줄 위에 그대로 남아
	#  찍혔다 — 이 컷이 재려는 것은 **아래 안내 줄**이지 카드가 아니다.
	keep = {"state": g.S.AIM_V, "shown": 120.0, "card_p": 0.0}
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
	#  상점으로 단추에 얹힘 — 몸이 한 칸 뜬다
	pin = Vector2(320.0, 310.0)
	await _shot("clear_hover", 20)
	pin = Vector2(-50.0, -50.0)

	# ── 9. 보드 확장 명판 — 가장 긴 이름 · 판 위 ─────────
	keep = {}
	g.clear_gold_detail = []
	g.gold = 12
	g.mods_own = ["arst"]
	g.leg_no = 1
	g._start_leg()
	g._swap_skip()
	g.state = g.S.PICK
	await _tick(20)
	keep = {"state": g.S.PICK, "shown": 0.0, "card_p": 0.0}
	await _shot("modplate", 20)
	g.mods_own = ["pang"]
	await _shot("modplate2", 20)
	g.mods_own = []
	keep = {}

	# ── 10. 인트로 — 180 합계 · 네온 켜지는 중 · 붙은 간판 ──
	g._intro_begin()
	var clock := 0.0
	var at := [[2.70, "intro_180"], [3.55, "intro_sign"], [4.30, "intro_snap"]]
	var k := 0
	while k < at.size():
		g.mouse_at = Vector2(-50.0, -50.0)
		g._tutor_close()
		g._process(1.0 / 60.0)
		clock += 1.0 / 60.0
		await process_frame
		if clock >= float(at[k][0]):
			await process_frame
			root.get_texture().get_image().save_png("res://shots/txta_%s_%s.png" % [tag, at[k][1]])
			print("  shot %s" % at[k][1])
			k += 1
	print("  찍음")
	quit(0)
