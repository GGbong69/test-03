extends SceneTree
# 판 소품 몸짓(2026-10-02) — 팔면 상인이 판 동전을 저울에서 집어 가고, 사면 등록기를 친다.
# 몸짓은 그림이다. 못 박는 것:
#   ① 값이 몸짓과 무관하다 — 몸짓을 켜고 끈 두 판매 · 두 구매가 골드 · 동전 · 매물 · 봉인 ·
#      매듭에서 글자 하나 안 다르고, 확정 순간도 같다(_sell · _pay_take 가 돌아온 그 줄).
#      몸짓이 도는 동안 값이 한 톨도 안 움직인다.
#   ② 팔면 · 사면 몸짓이 서고 제 시간(PROP.s_end · b_end) 안에 끝나며, 두 손이 쉼으로
#      돌아온다(손바닥 자리가 몸짓 전과 같다).
#   ③ 팔이 안 늘어난다 — 어깨 → 손목 거리가 위팔 + 팔뚝을 안 넘는다. 집은 동전이 손끝을
#      따라온다(npc_hold = 동전 과녁). 서랍은 검지가 누르는 박자에 튀어나온다.
#   ④ 못 서면 옛 응수다 — 움직임 끔 · 건네는 중 · 쓰는 중 · 진열대가 없다(헤드리스 기본).
#      서던 몸짓도 건네기 · 쓸기가 들면 끊겨 쉼으로 돌아간다.
#   ⑤ 연달아 팔고 사도 멈춘 손 · 남은 동전 그림이 없다.
#   ⑥ 개발자 「상인 몸짓」의 두 줄(저울에 올리기 · 등록기 치기)이 값을 안 건드린다.
# 헤드리스라 진열대(3D)가 없다 — 몸짓은 prop_force 로 세우고, 손 자세는 npc_dry 로
# 그리기 밖에서 셈한다(_npc_arms).
#   godot --headless --path . --script scripts/tools/qa_prop.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")
const DT := 1.0 / 60.0
var g = null
var ok := 0
var bad := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_prop_g.cfg"
	Save.path = "user://_qa_prop.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	_run()
	print("통과 %d · 실패 %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-44s %s" % ["통과" if cond else "실패", nm, note])


func _calm() -> void:
	g.idle_act = -1
	g.idle_t = 0.0
	g.idle_wait = 99.0
	g.npc_eye = 0.0


func _tick(sec: float) -> void:
	var n: int = int(ceil(sec / DT))
	for k in n:
		g._prop_tick(DT)


func _pose() -> void:
	g.npc_dry = true
	g._npc_arms()
	g.npc_dry = false
	_wrist_take()


#  ── 손목 — 「물건 팔때 손이 좀 꺽이네?」 ─────────────────────
#  자세를 셈한 틀마다 두 손의 손목 꺾임(npc_wb — 팔뚝 축에 대한 옆 · 굽힘)을 잰다.
#  한도는 옆 15° · 굽힘 25°. 쉴 때부터 그 한도를 넘는 손(화면 오른손은 안으로 18° 모아
#  쉰다 — NPC.ang_r)은 그 넘는 몫을 몸짓 섞임만큼만 걷어도 된다(첫 틀에 손이 안 튄다).
var rest_wb := [Vector2.ZERO, Vector2.ZERO]   # 쉼 자세의 꺾임
var wb_bad := 0                               # 한도를 넘은 틀
var wb_note := ""
var wb_act := [Vector2.ZERO, Vector2.ZERO]    # 몸짓이 다 선 틀(섞임 0.9 넘음)의 최대(옆 · 굽힘)
var wb_all := [Vector2.ZERO, Vector2.ZERO]    # 몸짓이 선 모든 틀의 최대


func _wrist_take() -> void:
	for h in 2:
		if not g._prop_live(h):
			continue
		var wb: Vector2 = g.npc_wb[h]
		var ke: float = g.prop_lk[h]
		var r: Vector2 = rest_wb[h]
		var ld: float = 15.0 + maxf(r.x - 15.0, 0.0) * (1.0 - ke) + 0.05
		var lf: float = 25.0 + maxf(r.y - 25.0, 0.0) * (1.0 - ke) + 0.05
		wb_all[h] = Vector2(maxf((wb_all[h] as Vector2).x, wb.x), maxf((wb_all[h] as Vector2).y, wb.y))
		if ke >= 0.9:
			wb_act[h] = Vector2(maxf((wb_act[h] as Vector2).x, wb.x), maxf((wb_act[h] as Vector2).y, wb.y))
		if wb.x > ld or wb.y > lf:
			wb_bad += 1
			if wb_bad <= 12:
				print("    [손목] 손 %d t %.3f 섞임 %.2f 끊김 %.2f 앞자세 %.2f · 옆 %.2f/%.2f 굽힘 %.2f/%.2f" % [
						h, float(g.prop_t[h]), ke, float(g.prop_cut[h]), float(g.prop_snap_k[h]),
						wb.x, ld, wb.y, lf])
			if wb_note == "":
				wb_note = "손 %d · t %.2f · 옆 %.1f/%.1f · 굽힘 %.1f/%.1f" % [h, float(g.prop_t[h]),
						wb.x, ld, wb.y, lf]


#  몸짓 시계를 밀며 틀마다 자세를 셈한다(손목을 잰다).
func _tick_pose(sec: float) -> void:
	var n: int = int(ceil(sec / DT))
	for k in n:
		g._prop_tick(DT)
		_pose()


#  두 손 몸짓을 걷는다(앞 검사의 꼬리를 안 남긴다).
func _clear_acts() -> void:
	for i in 2:
		if g._prop_live(i):
			g._prop_end(i)
	g.prop_ghost.clear()
	g.scale_tilt = 0.0
	g.scale_tv = 0.0
	g.scale_ring = 0.0


func _ids(a: Array) -> String:
	var s := ""
	for it in a:
		s += String((it as Dictionary).get("id", "?")) + ","
	return s


func _sold(a: Array) -> String:
	var s := ""
	for it in a:
		s += "1" if bool((it as Dictionary).get("sold", false)) else "0"
	return s


func _snap() -> Dictionary:
	return {"gold": g.gold, "owned": g.owned.duplicate(true), "stock": g.stock.duplicate(true),
			"drop": g.drop.duplicate(true), "cons": g.cons.duplicate(true), "sealed": g.sealed,
			"bought": g.bought_item}


func _restore(s: Dictionary) -> void:
	g.gold = int(s.gold)
	g.owned = (s.owned as Array).duplicate(true)
	g.stock = (s.stock as Array).duplicate(true)
	g.drop = (s.drop as Array).duplicate(true)
	g.cons = (s.cons as Array).duplicate(true)
	g.sealed = int(s.sealed)
	g.bought_item = bool(s.bought)
	g.sell_sel = -1
	g.buy_sel = -1
	g._panel_reset()


func _econ() -> String:
	return "금화 %d · 동전 %s · 봉인 %d · 매물 %s · 사탕 %d · 매듭 %s" % [g.gold, _ids(g.owned),
			g.sealed, _sold(g.stock), g.cons.size(), str(Save.run_get("gold", "-"))]


func _run() -> void:
	g.state = g.S.TITLE
	g._new_run()
	g.gold = 99
	g.leg_no = 2
	g._open_shop()
	g.drop_fast = true
	for k in 240:
		g._drop_step(DT)
	g._drop_settle()
	g.owned.clear()
	var n := 0
	for it in GameData.items():
		var c: Dictionary = (it as Dictionary).duplicate()
		c.gs = 0
		c.bought = g.leg_no
		g.owned.append(c)
		n += 1
		if n >= 3:
			break
	g._panel_reset()
	g.sealed = 2
	_calm()
	print("상점 — 매물 %d · 동전 %d · 진열대 %s(헤드리스는 거짓)" % [g.stock.size(), g.owned.size(),
			g._room3d_tbl()])
	var base := _snap()

	# ① 판매 — 몸짓을 켜고 끈 두 판이 값에서 같다
	var res := []
	for act in [false, true]:
		_restore(base)
		_clear_acts()
		_calm()
		g.prop_force = act
		g.sell_sel = 0
		g._chute_click(g.Z_SELL)
		var at_commit := _econ()
		var live: bool = g._prop_live(0)
		_tick(2.0)
		res.append([at_commit, _econ(), live, g._idle_name()])
	g.prop_force = false
	_ok("판매 값이 몸짓과 무관하다", res[0][0] == res[1][0], "%s | %s" % [res[0][0], res[1][0]])
	_ok("판매 — 몸짓 동안 값이 안 움직인다", res[1][0] == res[1][1], res[1][1])
	_ok("판매 — 봉인이 같은 동전을 따라 밀린다", g.sealed == 1, "봉인 %d" % g.sealed)
	_ok("판매 — 진열대가 없으면 옛 손짓", not bool(res[0][2]) and res[0][3] == "손짓",
			"몸짓 %s · 응수 %s" % [res[0][2], res[0][3]])
	_ok("판매 — 진열대가 있으면 몸짓이 선다", bool(res[1][2]), "")
	#  끌어 판다 — 동전 슬롯에서 집어 저울에 놓으면 판 동전이 **놓은 자리**에서 난다.
	_restore(base)
	_clear_acts()
	_calm()
	g.prop_force = true
	var sc0: Vector2 = (g._slot_rect(0) as Rect2).get_center()
	var at_sc: Vector2 = (g._prop_rect(g.Z_SELL) as Rect2).get_center()
	var grabbed: bool = g._rack_grab(sc0)
	g._hand_motion(at_sc)
	var carry: bool = g.hand_st == g.H.CARRY
	g.hand_zone = g.Z_SELL
	var gd0: int = g.gold
	g._hand_release(at_sc)
	_ok("끌어 팔면 놓은 자리에서 난다", grabbed and carry and g._prop_live(0)
			and g.prop_from.distance_to(at_sc) < 0.01 and g.gold > gd0
			and not g.sell_drag.is_finite(),
			"잡음 %s · 끎 %s · 몸짓 %s · 금화 %d→%d" % [grabbed, carry, g._prop_live(0), gd0, g.gold])
	_clear_acts()
	g.prop_force = false

	# ① 구매 — 같은 매물을 두 번(되돌려서) 산다
	_restore(base)
	var bi := -1
	for i in g.stock.size():
		if int(g.stock[i].cost) <= g.gold and g._buy_block(i) == "":
			bi = i
			break
	_ok("살 매물이 있다", bi >= 0, "%d" % bi)
	if bi >= 0:
		var rb := []
		for act in [false, true]:
			_restore(base)
			_clear_acts()
			_calm()
			g.pay_flash = 0.0
			g.prop_force = act
			g.buy_sel = bi
			g._pay_click()
			var c0 := _econ()
			var fl0: float = g.pay_flash
			var live2: bool = g._prop_live(1)
			var fl_max := 0.0
			var t_flash := -1.0
			var tt := 0.0
			for k in 120:
				g._prop_tick(DT)
				tt += DT
				if g.pay_flash > fl_max:
					fl_max = g.pay_flash
					if t_flash < 0.0:
						t_flash = tt
			rb.append([c0, _econ(), live2, fl0, t_flash, g._idle_name()])
		g.prop_force = false
		_ok("구매 값이 몸짓과 무관하다", rb[0][0] == rb[1][0], "%s | %s" % [rb[0][0], rb[1][0]])
		_ok("구매 — 몸짓 동안 값이 안 움직인다", rb[1][0] == rb[1][1], rb[1][1])
		_ok("구매 — 진열대가 없으면 옛 끄덕 · 바로 서랍",
				not bool(rb[0][2]) and float(rb[0][3]) >= 0.99 and rb[0][5] == "끄덕",
				"몸짓 %s · 서랍 %.2f · 응수 %s" % [rb[0][2], float(rb[0][3]), rb[0][5]])
		var pz: float = float(g.PROP.b_press)
		_ok("구매 — 서랍은 검지가 누르는 박자에",
				bool(rb[1][2]) and float(rb[1][3]) < 0.01
				and absf(float(rb[1][4]) - pz) <= DT + 0.001,
				"확정 때 %.2f · 튄 때 %.3f초 (누름 %.2f)" % [float(rb[1][3]), float(rb[1][4]), pz])

	# ② 몸짓이 서고 제 시간 안에 끝나며 두 손이 쉼으로 돌아온다
	_restore(base)
	_clear_acts()
	_calm()
	_pose()
	var rest0: Vector3 = g.npc_palm[0]
	var rest1: Vector3 = g.npc_palm[1]
	var body0: Dictionary = g._idle_body()
	rest_wb = [g.npc_wb[0], g.npc_wb[1]]
	print("쉼 손목 — 왼손 옆 %.1f° 굽힘 %.1f° · 오른손 옆 %.1f° 굽힘 %.1f°" % [
			(rest_wb[0] as Vector2).x, (rest_wb[0] as Vector2).y,
			(rest_wb[1] as Vector2).x, (rest_wb[1] as Vector2).y])
	g.prop_force = true
	g.sell_sel = 0
	g._chute_click(g.Z_SELL)
	var t := 0.0
	var rr := 0.0
	var far_u := 999.0
	var hold_err := 0.0
	var grip_mid := 0.0
	while g._prop_live(0) and t < 3.0:
		g._prop_tick(DT)
		t += DT
		_pose()
		rr = maxf(rr, float(g.prop_rr[0]))
		far_u = minf(far_u, (g.npc_palm[0] as Vector3).x)
		var pt: float = g.prop_t[0]
		if pt >= float(g.PROP.s_reach) and pt < float(g.PROP.s_g1):
			#  쥐기 전 — 손의 검지 끝이 접시 동전을 집을 자리에 서 있다(prop_hold3 — 그 틀
			#  손에서 낸 동전 자리)
			var c3: Vector3 = g._prop_pan3()
			var h3: Vector3 = g.prop_hold3
			hold_err = maxf(hold_err, Vector3(c3.x, c3.z, c3.y).distance_to(h3))
		if pt >= float(g.PROP.s_g1) and pt < float(g.PROP.s_lift):
			grip_mid = maxf(grip_mid, g._give_grip(0))
	_ok("판매 몸짓이 선다", t > 0.5, "%.2f초" % t)
	_ok("판매 몸짓이 제 시간 안에 끝난다", t <= float(g.PROP.s_end) + DT * 1.5,
			"%.3f초 (표 %.2f)" % [t, float(g.PROP.s_end)])
	_ok("손이 저울까지 간다", far_u < 90.0, "손바닥 u 최소 %.0f" % far_u)
	_ok("팔이 안 늘어난다", rr <= 1.0, "어깨 → 손목 / 팔 길이 최대 %.3f" % rr)
	_ok("집는 손이 접시 동전 자리에 선다", hold_err < 0.6, "어긋남 최대 %.2f" % hold_err)
	_ok("든 동안 다 쥐었다", grip_mid > 0.99, "쥠 %.2f" % grip_mid)
	_pose()
	var back0: float = (g.npc_palm[0] as Vector3).distance_to(rest0)
	_ok("판 뒤 왼손이 쉼으로 돌아온다", back0 < 0.01 and g._give_grip(0) < 0.001,
			"어긋남 %.3f · 쥠 %.3f" % [back0, g._give_grip(0)])
	_ok("판 뒤 남은 동전 그림이 없다", g.prop_it.is_empty() and g.prop_ghost.is_empty(), "")
	#  가장 먼 박자(접시에서 집는 0.42 · 든 0.50)에서 커서가 어디 있든(몸이 따라본다 —
	#  끌어 팔면 커서는 저울 위다) · 숨이 어느 박자든 팔이 안 늘어난다.
	var clk0: float = g.npc_clock
	var eye0: float = g.npc_eye
	var worst := 0.0
	for pt in [0.42, 0.50]:
		_restore(base)
		_clear_acts()
		_calm()
		g.sell_sel = 0
		g._chute_click(g.Z_SELL)
		while float(g.prop_t[0]) < float(pt):
			g._prop_tick(DT)
		for ey in [-1.0, 0.0, 1.0]:
			for ph in 12:
				g.npc_eye = ey
				g.npc_clock = float(ph) / 12.0 / float(g.IDLE.sway_hz)
				_pose()
				worst = maxf(worst, float(g.prop_rr[0]))
	g.npc_clock = clk0
	g.npc_eye = eye0
	_ok("커서 · 숨이 어떻든 팔이 안 늘어난다", worst <= 1.0, "최대 %.3f" % worst)
	_clear_acts()

	g.buy_sel = -1
	var bj := -1
	for i in g.stock.size():
		if int(g.stock[i].cost) <= g.gold and g._buy_block(i) == "":
			bj = i
			break
	if bj >= 0:
		g.buy_sel = bj
		g._pay_click()
		t = 0.0
		var near_u := 0.0
		rr = 0.0
		while g._prop_live(1) and t < 3.0:
			g._prop_tick(DT)
			t += DT
			_pose()
			rr = maxf(rr, float(g.prop_rr[1]))
			near_u = maxf(near_u, (g.npc_palm[1] as Vector3).x)
		_ok("구매 몸짓이 제 시간 안에 끝난다", t > 0.3 and t <= float(g.PROP.b_end) + DT * 1.5,
				"%.3f초 (표 %.2f)" % [t, float(g.PROP.b_end)])
		_ok("손이 등록기까지 간다", near_u > 540.0, "손바닥 u 최대 %.0f" % near_u)
		_ok("구매 팔도 안 늘어난다", rr <= 1.0, "최대 %.3f" % rr)
		_pose()
		var back1: float = (g.npc_palm[1] as Vector3).distance_to(rest1)
		_ok("산 뒤 오른손이 쉼으로 돌아온다", back1 < 0.01, "어긋남 %.3f" % back1)
	var body1: Dictionary = g._idle_body()
	_ok("몸이 쉼으로 돌아온다", absf(float(body1.roll) - float(body0.roll)) < 0.0001
			and absf(float(body1.lean) - float(body0.lean)) < 0.0001
			and absf(float(body1.yaw) - float(body0.yaw)) < 0.0001, "")

	# ④ 못 서면 옛 응수 · 서던 것도 끊긴다
	_restore(base)
	_clear_acts()
	_calm()
	g.prop_force = true
	g.motion_off = true
	g.sell_sel = 0
	g._chute_click(g.Z_SELL)
	_ok("움직임 끔 — 몸짓 없이 옛 손짓", not g._prop_live(0) and g._idle_name() == "손짓",
			g._idle_name())
	g.motion_off = false
	_restore(base)
	_clear_acts()
	_calm()
	g.sweep_live = true
	_ok("쓰는 중 — 몸짓이 안 선다", not g._prop_sell(g.owned[0], Vector2(200, 40), 0.0)
			and not g._prop_buy(), "")
	g.sweep_live = false
	g._give_begin(0, Vector2(200.0, g.TBL.fy))
	_ok("건네는 중 — 몸짓이 안 선다", g._give_live() and not g._prop_buy()
			and not g._prop_sell(g.owned[0], Vector2(200, 40), 0.0), "")
	g._give_end()
	g.give_rel = 0.0
	_calm()
	g.sell_sel = 0
	g._chute_click(g.Z_SELL)
	_tick_pose(0.3)
	g._give_begin(0, Vector2(440.0, g.TBL.fy))
	var tc := 0.0
	while g._prop_live(0) and tc < 2.0:
		g._prop_tick(DT)
		_pose()
		tc += DT
	_ok("건네기가 들면 몸짓이 끊겨 쉼으로", tc <= float(g.PROP.cut) + DT * 2.0,
			"%.3f초 (끊김 %.2f)" % [tc, float(g.PROP.cut)])
	g._give_end()
	g.give_rel = 0.0
	_tick(0.5)
	_calm()
	g.buy_sel = -1
	var bk := -1
	for i in g.stock.size():
		if int(g.stock[i].cost) <= g.gold and g._buy_block(i) == "":
			bk = i
			break
	if bk >= 0:
		g.pay_flash = 0.0
		g.buy_sel = bk
		g._pay_click()
		_tick_pose(0.1)
		g.sweep_live = true
		_tick_pose(0.3)
		g.sweep_live = false
		_ok("쓸기가 들면 구매 몸짓이 끊기고 서랍은 연다", not g._prop_live(1) and g.pay_flash > 0.0,
				"서랍 %.2f" % g.pay_flash)
	g.state = g.S.LEG
	_ok("상점 밖 — 몸짓이 안 선다", not g._prop_buy(), "")
	g.state = g.S.SHOP

	# ⑤ 연달아 팔고 산다
	_restore(base)
	_clear_acts()
	_calm()
	g.sell_sel = 0
	g._chute_click(g.Z_SELL)
	_tick_pose(0.30)
	var gh_before: bool = g.prop_ghost.is_empty()
	g.sell_sel = 0
	g._chute_click(g.Z_SELL)
	_ok("다시 팔면 처음부터 · 앞 동전은 졸아든다",
			float(g.prop_t[0]) < 0.001 and gh_before and not g.prop_ghost.is_empty()
			and not g.prop_it.is_empty(), "t %.3f" % float(g.prop_t[0]))
	_tick_pose(0.05)
	g.sell_sel = 0
	g._chute_click(g.Z_SELL)
	_tick_pose(0.95)
	g.sell_sel = 0
	if g.owned.size() > 0:
		g._chute_click(g.Z_SELL)
	_tick_pose(3.0)
	_ok("연달아 판 뒤 멈춘 손 · 남은 그림이 없다",
			not g._prop_live(0) and g.prop_it.is_empty() and g.prop_ghost.is_empty()
			and absf(g.scale_tilt) < 0.02, "동전 %d · 기울기 %.3f" % [g.owned.size(), g.scale_tilt])
	for k in 3:
		var bz := -1
		for i in g.stock.size():
			if int(g.stock[i].cost) <= g.gold and g._buy_block(i) == "":
				bz = i
				break
		if bz < 0:
			break
		g.buy_sel = bz
		g._pay_click()
		_tick_pose(0.12)
	_tick_pose(2.0)
	_pose()
	_ok("연달아 산 뒤 멈춘 손이 없다", not g._prop_live(1)
			and (g.npc_palm[1] as Vector3).distance_to(rest1) < 0.01, "")

	#  손목 — 위 ② · ④ · ⑤ 에서 셈한 모든 틀(두 몸짓 · 두 손 · 끊김 · 다시 함)
	_ok("손목 — 모든 틀이 옆 15° · 굽힘 25° 안", wb_bad == 0,
			"넘은 틀 %d %s" % [wb_bad, wb_note])
	var ws: Vector2 = wb_act[0]
	var wbb: Vector2 = wb_act[1]
	_ok("손목 — 저울에 뻗은 손(섞임 0.9 넘음)", ws.x <= 15.05 and ws.y <= 25.05 and ws.y > 0.0,
			"최대 옆 %.1f° · 굽힘 %.1f° (모든 틀 %.1f° · %.1f°)" % [ws.x, ws.y,
			(wb_all[0] as Vector2).x, (wb_all[0] as Vector2).y])
	_ok("손목 — 등록기를 치는 손(섞임 0.9 넘음)", wbb.x <= 15.05 and wbb.y <= 25.05 and wbb.y > 0.0,
			"최대 옆 %.1f° · 굽힘 %.1f° (모든 틀 %.1f° · %.1f°)" % [wbb.x, wbb.y,
			(wb_all[1] as Vector2).x, (wb_all[1] as Vector2).y])

	# ⑥ 개발자 줄 — 값을 안 건드린다
	_restore(base)
	_clear_acts()
	_calm()
	var dev0 := _econ()
	var na: int = (g.IDLE.acts as Array).size() + Dev.NPC_HOLDS.size()
	var names: PackedStringArray = Dev._names("npcact")
	_ok("개발자 줄에 두 몸짓이 있다", names.size() == na + 2
			and names[na] == "저울에 올리기" and names[na + 1] == "등록기 치기",
			"%d줄 · %s · %s" % [names.size(), names[mini(na, names.size() - 1)],
			names[mini(na + 1, names.size() - 1)]])
	Dev.pick["npcact"] = na
	Dev._run(g, {"t": "list", "k": "npcact", "n": na + 2})
	var dl0: bool = g._prop_live(0)
	_tick(2.0)
	Dev.pick["npcact"] = na + 1
	Dev._run(g, {"t": "list", "k": "npcact", "n": na + 2})
	var dl1: bool = g._prop_live(1)
	_tick(2.0)
	_ok("개발자 「저울에 올리기」 · 「등록기 치기」가 선다", dl0 and dl1, "")
	_ok("개발자 줄이 값을 안 건드린다", _econ() == dev0, "%s | %s" % [dev0, _econ()])
	g.owned.clear()
	g._panel_reset()
	Dev.pick["npcact"] = na
	Dev._run(g, {"t": "list", "k": "npcact", "n": na + 2})
	_ok("든 동전이 없어도 저울 몸짓은 선다(매물 · 빈 동전 그림)", g._prop_live(0)
			and not g.prop_it.is_empty(), String(g.prop_it.get("id", "")))
	_tick(2.0)
	g.prop_force = false
	Dev.pick["npcact"] = na + 1
	Dev._run(g, {"t": "list", "k": "npcact", "n": na + 2})
	_ok("진열대가 없으면 개발자 줄도 안 선다", not g._prop_live(1), "")
