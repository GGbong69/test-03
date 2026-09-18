extends SceneTree
# 글자 키우기 B 묶음 — 판 고르기 · 제약 고르기 · 상점 · 툴팁 · 사진 판 · 배움.
# 가장 긴 글줄(긴 이름 · 긴 효과 · 두 자리 값 · 꽉 찬 뱃지 줄)을 깔아 한 장씩.
#   godot --path . --quit-after 4000 --script scripts/tools/shot_text_b.gd -- before
#   → shots/txtb_<꼬리>_*.png (꼬리는 -- 뒤 낱말, 없으면 now)
#
# 게임의 _process 는 끈다. 툴팁은 실제 커서(_cursor)를 읽어 매 프레임 새로
# 세우므로, 켜 두면 박아 둔 툴팁이 한 프레임 만에 걷힌다(tip_shots.gd 와 같다).
# 얹힘 그림은 mouse_at 을 읽으므로 그 값은 매 프레임 핀으로 박는다.
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false
var pin := Vector2(-50.0, -50.0)
var tip := {}           # 박아 둘 툴팁 대상. 비면 툴팁을 끈다
var tail := "now"


func _initialize() -> void:
	var ua := OS.get_cmdline_user_args()
	if not ua.is_empty():
		tail = String(ua[0])
	Save.gpath = "user://_shot_txtb_g.cfg"
	Save.path = "user://_shot_txtb.cfg"
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
	if g == null:
		return
	g.mouse_at = pin
	g.swap_live = false
	if tip.is_empty():
		g.tip_a = 0.0
		g._tip_clear()
	else:
		g._tip_build(tip)
		g.tip_a = 1.0
	#  얹힘 짙기는 _process 가 민다 — 꺼 두었으니 손으로 민다
	g._ui_hover_tick(0.5)
	g.queue_redraw()


func _tick(n: int) -> void:
	#  게임 시계를 손으로 민다(물건이 자리에 앉고 카드가 깔린다)
	for i in n:
		g._process(1.0 / 60.0)
		g._swap_skip()
		g._tutor_close()
		g.tutor_out = 0.0


func _shot(nm: String, at := Vector2(-50.0, -50.0), hit := {}) -> void:
	pin = at
	tip = hit
	for i in 4:
		_pin()
		await process_frame
	root.get_texture().get_image().save_png("res://shots/txtb_%s_%s.png" % [tail, nm])
	print("  %-18s hot '%s' · 툴팁 '%s'" % [nm, g.ui_hot, g.tip_title])
	tip = {}
	pin = Vector2(-50.0, -50.0)


func _by_item(a: Dictionary, b: Dictionary) -> bool:
	return String(a.n).length() + String(g._tip_eff(a)).length() 			> String(b.n).length() + String(g._tip_eff(b)).length()


func _by_tag(a: Dictionary, b: Dictionary) -> bool:
	return String(a.get("name", "")).length() > String(b.get("name", "")).length()


func _by_desc(a: Dictionary, b: Dictionary) -> bool:
	return String(a.d).length() > String(b.d).length()


#  가장 긴 효과 · 이름을 가진 동전 다섯
func _long_items(n: int) -> Array:
	var its: Array = GameData.items().duplicate()
	its.sort_custom(_by_item)
	var out := []
	for it in its.slice(0, n):
		var c: Dictionary = it.duplicate()
		c.gs = 0
		c.bought = 1
		out.append(c)
	return out


func _run() -> void:
	for i in 10:
		await process_frame
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	g.set_process(false)
	_tick(8)
	g._new_run()
	_tick(30)
	g.gold = 99
	g.owned = _long_items(GameData.max_items())
	g._panel_reset()
	var fx: Array = GameData.fixtures()
	var longfix: Dictionary = fx[0]
	for f in fx:
		if String(f.d).length() > String(longfix.d).length():
			longfix = f
	g.cons = [longfix.duplicate(), GameData.candies()[0].duplicate()]

	# ── 판 고르기 ─────────────────────────────────────────
	#  건너뛰기 뱃지는 효과 줄이 가장 긴 것 · 쌓인 뱃지는 이름이 긴 것부터 꽉
	var tags: Array = GameData.tags().duplicate()
	tags.sort_custom(_by_tag)
	var longdesc: Dictionary = tags[0]
	for t in tags:
		if g._tag_text(t).length() > g._tag_text(longdesc).length():
			longdesc = t
	g.leg_skipped = {}
	g.leg_no = 1
	g._open_leg()
	_tick(40)
	g.leg_t = 9.0
	g.leg_tag = longdesc
	g.leg_tags[1] = longdesc
	g.pending_tags.clear()
	for t in tags:
		if g.pending_tags.size() >= 9:
			break
		g.pending_tags.append({"kind": String(t.get("kind", "")), "v": 1,
				"n": String(t.get("name", "")), "d": g._tag_text(t),
				"w": g._tag_when(t), "rar": String(t.get("rarity", ""))})
	await _shot("leg1")
	#  실제로 쌓이는 만큼(상점 · 보스 갈래 넷)
	var few: Array = g.pending_tags.duplicate()
	g.pending_tags.clear()
	for t in GameData.tags():
		if String(t.get("when", "now")) != "now":
			g.pending_tags.append({"kind": String(t.get("kind", "")), "v": 1,
					"n": String(t.get("name", "")), "d": g._tag_text(t),
					"w": g._tag_when(t), "rar": String(t.get("rarity", ""))})
	await _shot("leg1_fewtags", g._pend_rect(1).get_center())
	g.pending_tags = few
	await _shot("leg1_pendhov", g._pend_rect(1).get_center(), {"k": "pend", "i": 1})
	await _shot("leg1_skiptip", g._leg_skip().get_center(), {"k": "tag", "i": 1})
	await _shot("leg1_racktip", g._slot_rect(0).get_center(), {"k": "rack", "i": 0})
	await _shot("leg1_heldtip", g._cons_rect(0).get_center(), {"k": "held", "i": 0})
	#  깨진 판 · 건너뛴 판 · 보스 판(못 건너뛴다)
	g.leg_skipped = {2: true}
	g.leg_no = 3
	g._open_leg()
	_tick(40)
	g.leg_t = 9.0
	await _shot("leg3")
	#  뒤 라운드 — 큰 목표 수 · 가운데 카드가 선다
	g.leg_skipped = {}
	g.leg_no = GameData.legs_n() - 1
	g._open_leg()
	_tick(40)
	g.leg_t = 9.0
	g.leg_tag = longdesc
	await _shot("leg_late")

	# ── 보스 카드가 든 제약 ───────────────────────────────
	for lv in range(1, 30):
		if GameData.is_boss(lv):
			g.leg_no = lv
			break
	g._open_leg()
	#  이름이 가장 긴 제약을 보스 카드에 꽂는다 — 이름 칸(100px)이
	#  언제 _elide 를 무는지가 이 사진의 쓸모다.
	var mfs: Array = GameData.modifiers().duplicate()
	mfs.sort_custom(_by_desc)
	var bn: int = g._round_boss()
	g.boss_mods[bn] = PackedStringArray([String(mfs[0].id)])
	g.mods_own = []
	for md in GameData.mods().slice(0, 1):
		g.mods_own.append(String(md.id))
	g.leg_t = 9.0
	_tick(40)
	g.leg_t = 9.0
	await _shot("stage", Vector2(-50.0, -50.0))
	await _shot("stage_tip",
			g._row_rect(GameData.leg_idx(bn), GameData.legs_per_round()).get_center(),
			{"k": "legboss", "i": bn})
	#  겹치기 — 명판 둘 · 이름 없는 줄
	g.boss_mods[bn] = PackedStringArray([String(mfs[0].id), String(mfs[1].id)])
	g.leg_t = 9.0
	await _shot("stage_left", Vector2(-50.0, -50.0))
	g.boss_mods[bn] = PackedStringArray([String(mfs[0].id)])

	# ── 상점 ─────────────────────────────────────────────
	g.leg_no = 4
	g.gold = 9
	g._open_shop()
	_tick(20)
	g.stock.clear()
	var its := _long_items(3)
	g.stock.append({"type": "item", "d": its[0], "cost": 14, "sold": false})
	g.stock.append({"type": "item", "d": its[1], "cost": 8, "sold": false})
	g.stock.append({"type": "fix", "d": longfix, "cost": 12, "sold": false})
	g.stock.append({"type": "mod", "d": GameData.mods()[1], "cost": 10, "sold": false})
	g.stock.append({"type": "item", "d": its[2], "cost": 0, "sold": false, "pack": true})
	g.boost_pick = 2
	g._drop_roll()
	g._drop_settle()
	_tick(90)
	g._drop_settle()
	g.sell_sel = 0
	g.buy_sel = 0
	g.pay_msg = "%s — 동전을 고른다" % String(longfix.n)
	g.pay_msg_t = 9.0
	await _shot("shop")
	g.pay_msg_t = 0.0
	g.sell_sel = -1
	g.buy_sel = -1
	await _shot("shop_stocktip", g._obj_box(0).get_center(), {"k": "stock", "i": 0})
	await _shot("shop_fixtip", g._obj_box(2).get_center(), {"k": "stock", "i": 2})
	await _shot("shop_racktip", g._slot_rect(4).get_center(), {"k": "rack", "i": 4})
	g.gold = 99
	await _shot("shop_rich")
	#  리롤 값이 붙은 단추(못 사는 색) · 거절 한 줄
	var rc0: int = g.reroll_cost
	g.reroll_cost = 5
	g.gold = 3
	g.deny_flash = 1.0
	await _shot("shop_reroll")
	g.deny_flash = 0.0
	g.reroll_cost = rc0
	g.gold = 99
	#  사진이 깐 테이블 — 태우기(판매) · 복제
	g._photo_open("burn", 2)
	_tick(90)
	g._drop_settle()
	g.buy_sel = 0
	await _shot("shop_burn")
	g._photo_close()
	g._photo_open("clone", 2)
	_tick(90)
	g._drop_settle()
	g.buy_sel = 0
	await _shot("shop_clone")
	g._photo_close()
	_tick(10)

	# ── 사진이 연 판 — 칠하기 ───────────────────────────────
	#  미리보기 판은 걷혔다. 「프리크라임」이 읽기에서 다시 뽑기로 갈아타
	#  결과가 보스 카드와 상점 명판에 바로 보이므로 띄울 화면이 없다.
	g.photo = "paint"
	g.photo_v = 3
	await _shot("paint", g.BC + Vector2(0.0, -60.0))
	g.photo = ""

	# ── 배움 말상자 ───────────────────────────────────────
	g.leg_no = 4
	g._open_shop()
	_tick(40)
	g._drop_settle()
	for st in [["u_rack", 1, "tut_rack"], ["u_shop", 1, "tut_buy"], ["u_clear", 0, "tut_clear"]]:
		g.tutor_q.clear()
		g.tutor_id = String(st[0])
		g.tutor_i = int(st[1])
		g.tutor_t = 9.0
		g.tutor_out = 0.0
		await _shot(String(st[2]))
		await _shot(String(st[2]) + "_skiphov", g._tutor_skip_rect().get_center())
	g.tutor_id = ""

	# ── 새 런의 리그 줄 툴팁 ─────────────────────────────
	g._open_newrun()
	_tick(10)
	if not g._league_lines().is_empty():
		await _shot("newrun_lgtip", g._league_line_rect(0).get_center(), {"k": "lg", "i": 0})
	print("  찍음")
	quit(0)
