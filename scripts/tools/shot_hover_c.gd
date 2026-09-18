extends SceneTree
# 테이블 화면 얹힘(C 묶음) — 창구 둘 · 쌓인 뱃지 · 건너뛴다 툴팁 · 테이블 물건 ·
# 제약 카드를 안 올린 것과 올린 것으로 나란히 찍는다.
#   godot --path . --quit-after 3000 --script scripts/tools/shot_hover_c.gd
#
# 툴팁 판정(_tip_update)은 mouse_at 이 아니라 **진짜 OS 커서**(_cursor)를 읽는다.
# 찍는 동안 사용자의 커서가 창 어디에 있든 같은 그림이 나와야 하므로, 게임이
# 한 프레임을 다 돈 **뒤에** 도는 노드(Pin)가 커서 · 툴팁 · 손 상태를 다시 박는다.
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var busy := false
var pin := Vector2(-50.0, -50.0)
var tip := {"k": "-", "i": 0}   # 박을 툴팁. "-" 는 아무것도 안 뜬 상태
var hand := {}                  # 박을 손 상태(누르는 중). 비면 안 건드린다


class Pin extends Node:
	var t = null

	func _process(_d: float) -> void:
		t._pin()


func _initialize() -> void:
	Save.gpath = "user://_shot_hovc_g.cfg"
	Save.path = "user://_shot_hovc.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	var p := Pin.new()
	p.t = self
	p.process_priority = 1000
	root.add_child(p)


func _process(_d: float) -> bool:
	if busy:
		return false
	busy = true
	_run()
	return false


func _pin() -> void:
	if g == null:
		return
	g._tutor_close()
	g.tutor_out = 0.0
	g.swap_live = false
	g.mouse_at = pin
	g._tip_build(tip)
	g.tip_a = 1.0 if g.tip_title != "" else 0.0
	#  보스 카드는 tip_mark 를 읽어 테가 달아오른다 — _tip_build 가 이미
	#  세웠으므로 여기서 따로 밀 것이 없다(옛 제약 카드는 stage_stand 를
	#  손으로 밀어야 섰다).
	if not hand.is_empty():
		g.hand_st = hand.st
		g.hand_src = hand.src
		g.hand_i = hand.i
	g.queue_redraw()


func _wait(n: int) -> void:
	for i in n:
		await process_frame


#  cut 은 게임 좌표(640x360). 창은 1280x720 이라 두 배로 잘라 두 배로 키운다.
func _shot(nm: String, at: Vector2, t: Dictionary, cut: Rect2) -> void:
	pin = at
	tip = t
	await _wait(24)
	var img: Image = root.get_texture().get_image()
	img.save_png("res://shots/%s.png" % nm)
	var s: float = float(img.get_width()) / 640.0
	var r := Rect2i(Vector2i(cut.position * s), Vector2i(cut.size * s))
	var z: Image = img.get_region(r)
	z.resize(z.get_width() * 2, z.get_height() * 2, Image.INTERPOLATE_NEAREST)
	z.save_png("res://shots/%s_zoom.png" % nm)
	print("  %-22s hot=%-10s hov=%s" % [nm, g.ui_hot, str(g.ui_hov)])


func _run() -> void:
	await _wait(10)
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 화면이 있어야 돈다")
		quit(0)
		return
	var none := {"k": "-", "i": 0}
	g._new_run()
	await _wait(30)
	g.leg_t = 9.0
	#  ── 판 고르기 — 쌓인 뱃지 · 건너뛴다 툴팁 ──
	g.pending_tags.clear()
	var n := 0
	for tg in GameData.tags():
		if String(tg.get("when", "now")) != "now" and n < 3:
			g._take_tag(tg)
			n += 1
	await _wait(90)                 # 받은 뱃지 이름이 떠올랐다 사라질 때까지
	var low := Rect2(0.0, 250.0, 330.0, 110.0)
	await _shot("hovc_leg_none", Vector2(-50.0, -50.0), none, low)
	await _shot("hovc_leg_pend", g._pend_rect(1).get_center(), {"k": "pend", "i": 1}, low)
	await _shot("hovc_leg_skip", g._leg_skip().get_center(),
			{"k": "tag", "i": g.leg_no}, Rect2(0.0, 180.0, 330.0, 180.0))
	#  ── 보스 카드 — 얹히면 테가 달아오른다 ──
	#  제약은 보스 판에만 걸린다 — 첫 보스 판으로 옮겨 연다
	while not GameData.is_boss(g.leg_no) and g.leg_no < 40:
		g.leg_no += 1
	g._open_leg()
	await _wait(10)
	g.leg_t = 9.0
	var mid := Rect2(100.0, 110.0, 440.0, 200.0)
	var bi: int = GameData.leg_idx(g._round_boss())
	var bper: int = GameData.legs_per_round()
	await _shot("hovc_stage_none", Vector2(-50.0, -50.0), none, mid)
	await _shot("hovc_stage_hov", g._row_rect(bi, bper).get_center(),
			{"k": "legboss", "i": g._round_boss()}, mid)
	#  ── 상점 — 창구 둘 · 테이블 물건 ──
	g.gold = 99
	if g.owned.is_empty():
		g.owned.append(GameData.items()[0].duplicate())
	g._open_shop()
	await _wait(20)
	g._drop_settle()
	await _wait(10)
	var right := Rect2(470.0, 110.0, 170.0, 170.0)
	var left := Rect2(0.0, 110.0, 170.0, 170.0)
	var buy_at := Vector2(622.0, 175.0)
	var sell_at := Vector2(18.0, 175.0)
	g.buy_sel = -1
	g.sell_sel = -1
	await _shot("hovc_buy_none", Vector2(-50.0, -50.0), none, right)
	await _shot("hovc_buy_idle", buy_at, none, right)
	g.buy_sel = 0
	await _shot("hovc_buy_act_none", Vector2(-50.0, -50.0), none, right)
	await _shot("hovc_buy_act", buy_at, none, right)
	hand = {"st": g.H.ARMED, "src": 2, "i": 1}
	await _shot("hovc_buy_press", buy_at, none, right)
	hand = {"st": g.H.NONE, "src": 0, "i": -1}
	await _wait(2)
	hand = {}
	g.buy_sel = -1
	g.sell_sel = 0
	await _shot("hovc_sell_act_none", Vector2(-50.0, -50.0), none, left)
	await _shot("hovc_sell_act", sell_at, none, left)
	g.sell_sel = -1
	await _shot("hovc_sell_idle", sell_at, none, left)
	var gc: Vector2 = g._obj_box(0).get_center()
	await _shot("hovc_good_hov", gc, {"k": "stock", "i": 0},
			Rect2(gc.x - 90.0, gc.y - 70.0, 180.0, 140.0))
	#  ── 사진 테이블(It's Not About Money) — 판매 창구가 표적 ──
	g._photo_open("burn", 2)
	await _wait(10)
	g._drop_settle()
	await _wait(10)
	g.buy_sel = 0
	await _shot("hovc_burn_sell_none", Vector2(-50.0, -50.0), none, left)
	await _shot("hovc_burn_sell_act", sell_at, none, left)
	await _shot("hovc_burn_buy_idle", buy_at, none, right)
	print("  찍음")
	quit(0)
