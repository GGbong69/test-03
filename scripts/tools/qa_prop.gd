extends SceneTree
# 판 소품 몸짓(2026-10-02) — 팔면 상인이 판 동전을 저울에서 집어 가고, 사면 등록기를
# 내리친다(시안 C — 「C 로 바로」 · 「NPC가 수금기 내리 치면 좋겠어」).
# 몸짓은 그림이다. 못 박는 것:
#   ① 값이 몸짓과 무관하다 — 몸짓을 켜고 끈 두 판매 · 두 구매가 골드 · 동전 · 매물 · 봉인 ·
#      매듭에서 글자 하나 안 다르고, 확정 순간도 같다(_sell · _pay_take 가 돌아온 그 줄).
#      몸짓이 도는 동안 · 판 효과(동전 · 조각)가 다 가라앉을 때까지 값이 한 톨도 안 움직인다.
#   ② 팔면 · 사면 몸짓이 서고 제 시간(PROP.s_end · b_end) 안에 끝나며, 두 손이 쉼으로
#      돌아온다(손바닥 자리가 몸짓 전과 같다).
#   ③ 팔이 안 늘어난다 — 어깨 → 손목 거리가 위팔 + 팔뚝을 안 넘는다. 집은 동전이 손끝을
#      따라온다(npc_hold = 동전 과녁). 서랍은 손바닥이 닿는 박자에 튀어나온다.
#   ④ 못 서면 옛 응수다 — 움직임 끔 · 건네는 중 · 쓰는 중 · 진열대가 없다(헤드리스 기본).
#      서던 몸짓도 건네기 · 쓸기가 들면 끊겨 쉼으로 돌아간다.
#   ⑤ 연달아 팔고 사도 멈춘 손 · 남은 동전 그림이 없다.
#   ⑥ 개발자 「상인 몸짓」의 두 줄(저울에 올리기 · 등록기 내리치기)이 값을 안 건드린다.
#   ⑧ 주먹(2026-10-03) — 사탕을 상점에서 쓰면 값은 그 순간 오르고 사탕이 펠트에 떨어져 주먹에
#      부서진다(사탕 색 조각 · 설탕 반짝이 · 글). 빈 테이블 리롤은 쓸기 대신 주먹이 테이블을
#      치고, 판은 닿는 틀에 깔리고, 문(sweep_live)은 눌러 둔 주먹이 튀고 나서 열린다. 주먹
#      밑면이 과녁에 닿고 · 팔이 안 늘어나고 · 손목이 한도 안이다. 못 서면 옛 길(칸 팝 · 쓸기).
#   ⑦ 내리치기 — 손이 치켜 올랐다가 손바닥이 건반에 닿고(손목 한도 안), 그 박자에 서랍이
#      크게 튀어나오고 값 깃이 솟고 화면이 흔들리고 동전 · 나뭇조각 · 놋쇠 부스러기가 튀어
#      바닥에 떨어져 다 가라앉는다. 한 사건의 소리가 넷 안이다. 판 효과는 매 틀 새로 안
#      짓는다(칸 수가 그대로 · 정적 메모리가 안 는다). 움직임 끔 · 바쁜 상인 · 화면을 떠남의
#      옛 길(서랍만 · 한 번에 · 걷힘)이 산다.
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
	g.reg_t = -1.0
	g.reg_open = 0.0
	g.reg_fx = Vector3.ZERO
	g._burst_clear()
	g.th_fly.clear()
	g.th_bits.clear()
	g.th_marks.clear()
	g.th_flash.clear()
	g.shake = 0.0


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
			var dr0: bool = g.reg_t >= 0.0
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
			rb.append([c0, _econ(), live2, fl0, t_flash, g._idle_name(), dr0])
		g.prop_force = false
		_ok("구매 값이 몸짓과 무관하다", rb[0][0] == rb[1][0], "%s | %s" % [rb[0][0], rb[1][0]])
		_ok("구매 — 몸짓 동안 값이 안 움직인다", rb[1][0] == rb[1][1], rb[1][1])
		_ok("구매 — 진열대가 없으면 옛 끄덕 · 바로 서랍",
				not bool(rb[0][2]) and float(rb[0][3]) >= 0.99 and rb[0][5] == "끄덕"
				and bool(rb[0][6]),
				"몸짓 %s · 번쩍임 %.2f · 서랍 %s · 응수 %s" % [rb[0][2], float(rb[0][3]), rb[0][6],
				rb[0][5]])
		#  몸짓 시계는 빠르기(PROP.tempo_buy)배로 돈다 — 실시간 닿는 순간은 b_hit / 빠르기.
		var pz: float = float(g.PROP.b_hit) / float(g.PROP.tempo_buy)
		_ok("구매 — 서랍은 손바닥이 닿는 박자에",
				bool(rb[1][2]) and float(rb[1][3]) < 0.01
				and absf(float(rb[1][4]) - pz) <= DT + 0.001,
				"확정 때 %.2f · 튄 때 %.3f초 (닿음 %.2f)" % [float(rb[1][3]), float(rb[1][4]), pz])

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
	#  던진 동전(2026-10-04 「들어 올리고 오른쪽으로 던져버리는건 어때? 그럼 동전은 쓩 날아가서
	#  오른쪽 벽이랑 부딪혀서 부숴지는거지」) — 놓는 박자에 날아가 벽에 닿아 조각 · 불티가 튀고,
	#  다 가라앉는다. 값은 판 순간 그대로다(①).
	_restore(base)
	_clear_acts()
	_calm()
	g.sell_sel = 0
	var gth0: int = g.gold
	g._chute_click(g.Z_SELL)
	var gth1: int = g.gold
	var TH: Dictionary = g.THROW
	var fx_max := 0.0
	var rel_pt := -1.0
	var bits_max := 0
	var flash_seen := false
	var hit_at := Vector2(-1.0, -1.0)
	var tth := 0.0
	while tth < 3.0:
		var pt0: float = g.prop_t[0]
		g._prop_tick(DT)
		tth += DT
		if rel_pt < 0.0 and not g.th_fly.is_empty():
			rel_pt = pt0
		for f in g.th_fly:
			fx_max = maxf(fx_max, (g._throw_at(f, clampf(float(f.t) / float(TH.t), 0.0, 1.0))
					as Vector2).x)
		bits_max = maxi(bits_max, g.th_bits.size())
		flash_seen = flash_seen or not g.th_flash.is_empty()
		if not g.th_marks.is_empty():
			hit_at = g.th_marks[0].p
		if tth > 0.5 and g.th_fly.is_empty() and g.th_bits.is_empty() and g.th_marks.is_empty() 				and g.th_flash.is_empty() and not g._prop_live(0):
			break
	_ok("판매 — 놓는 박자에 동전이 날아간다", rel_pt >= 0.0
			and absf(rel_pt - float(g.PROP.s_rel)) <= DT * 2.0, "놓은 틀 %.3f (표 %.2f)" % [rel_pt,
			float(g.PROP.s_rel)])
	#  날던 마지막 틀은 벽 앞 한 틀(초속 2000px 언저리라 33px 안)이다 — 깨진 자리는 금이 말한다.
	_ok("판매 — 오른쪽 벽까지 날아가 깨진다(조각 · 불티 · 번쩍임)", fx_max >= (TH.to as Vector2).x - 40.0
			and hit_at.is_equal_approx(TH.to) and bits_max == int(TH.bits) + int(TH.sparks)
			and flash_seen, "날던 오른끝 %.0f · 깨진 자리 %s · 조각 %d" % [fx_max, hit_at, bits_max])
	_ok("판매 — 조각 · 금 · 번쩍임이 다 사라진다", g.th_bits.is_empty() and g.th_marks.is_empty()
			and g.th_flash.is_empty() and tth < 3.0, "%.2f초" % tth)
	_ok("판매 — 던지는 동안 값이 안 움직인다(판 순간 그대로)", g.gold == gth1 and gth1 > gth0,
			"%d → %d → %d" % [gth0, gth1, g.gold])
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
				"%.3f초 (표 %.2f — 0.8~1.0 안)" % [t, float(g.PROP.b_end)])
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
		_ok("쓸기가 들면 구매 몸짓이 끊기고 서랍은 연다(조용히)", not g._prop_live(1)
				and g.pay_flash > 0.0 and g.reg_t >= 0.0 and not g.reg_slam and g.bu_n == 0,
				"번쩍임 %.2f · 서랍 %.2f · 판 효과 %d" % [g.pay_flash, g.reg_open, g.bu_n])
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
	_ok("개발자 줄에 소품 몸짓 넷이 있다", names.size() == na + 4
			and names[na] == "저울에 올리기" and names[na + 1] == "등록기 내리치기"
			and names[na + 2] == "사탕 부수기" and names[na + 3] == "테이블 내리치기",
			"%d줄 · %s" % [names.size(), ", ".join(names.slice(na))])
	Dev.pick["npcact"] = na
	Dev._run(g, {"t": "list", "k": "npcact", "n": na + 2})
	var dl0: bool = g._prop_live(0)
	_tick(2.0)
	Dev.pick["npcact"] = na + 1
	Dev._run(g, {"t": "list", "k": "npcact", "n": na + 2})
	var dl1: bool = g._prop_live(1)
	var dburst := 0
	var dtt := 0.0
	while dtt < 2.0:
		g._prop_tick(DT)
		dtt += DT
		dburst = maxi(dburst, int(g.bu_n))
	_ok("개발자 「저울에 올리기」 · 「등록기 내리치기」가 선다", dl0 and dl1, "")
	_ok("개발자 「등록기 내리치기」가 판 효과까지 낸다", dburst > 0 and g.bu_n == 0,
			"최대 %d알 · 남은 %d" % [dburst, g.bu_n])
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
	_slam()
	_pound()


func _buy_idx() -> int:
	for i in g.stock.size():
		if int(g.stock[i].cost) <= g.gold and g._buy_block(i) == "" 				and not bool(g.stock[i].get("sold", false)):
			return i
	return -1


#  손바닥 닿는 점 — 그 틀 손(손목 축 · 손각 · 숙임)에서 PROP.b_palm 을 낸다(_prop_place 의 역).
func _palm_pt() -> Vector3:
	var w: Vector3 = g.prop_lw[1]
	var b := Basis(Vector3.UP, -float(g.prop_la[1])) * Basis(Vector3.BACK, -float(g.prop_lp[1]))
	var tp: Vector3 = g.PROP.b_palm
	return w + b * (Vector3(tp.x, tp.y, -tp.z) * float(g.NPC.sc_r))


# ⑦ 내리치기 — 「물건 구매하면 NPC가 수금기 내리 치면 좋겠어 수금기는 그럼 열리면서
#  이팩트로 동전이랑 무서진(부서진) 조각같은것들도 조금 날아가면서」.
func _slam() -> void:
	var base := _snap()
	_restore(base)
	_clear_acts()
	_calm()
	g.prop_force = true
	g.gold = 99
	var bi := _buy_idx()
	_ok("⑦ 살 매물이 있다", bi >= 0, "%d" % bi)
	if bi < 0:
		return
	var P: Dictionary = g.PROP
	var e0 := _econ()
	g.buy_sel = bi
	g._pay_click()
	var e1 := _econ()
	var t := 0.0
	var hit_t := -1.0
	var top_h := -999.0
	var hit_h := 999.0
	var palm_err := 0.0
	var dr_max := 0.0
	var fl_max := 0.0
	var key_max := 0.0
	var jo_min := 0.0
	var shake_hit := 0.0
	var kinds := [0, 0, 0]
	var all_land := false
	var n_max := 0
	var burst_end := -1.0
	var sz0: int = -1
	var sz_same := true
	var wb_hit := Vector2.ZERO
	while t < 2.5:
		var was: float = g.prop_t[1]
		g._prop_tick(DT)
		t += DT
		_pose()
		var pt: float = g.prop_t[1]
		var ph: float = (g.npc_palm[1] as Vector3).z
		if pt >= float(P.b_up) and pt < float(P.b_hit):
			top_h = maxf(top_h, ph)
		if was >= 0.0 and was < float(P.b_hit) and (pt >= float(P.b_hit) or pt < 0.0):
			hit_t = t
			hit_h = ph
			shake_hit = g.shake
			wb_hit = g.npc_wb[1]
			for i in g.bu_t.size():
				if float(g.bu_t[i]) >= 0.0:
					kinds[int(g.bu_k[i])] += 1
			sz0 = g.bu_t.size()
		if pt >= float(P.b_up) and pt < float(P.b_hold):
			var tg: Vector3 = g._prop_slam3(pt)
			palm_err = maxf(palm_err, _palm_pt().distance_to(tg))
		dr_max = maxf(dr_max, g.reg_open)
		fl_max = maxf(fl_max, (g.reg_fx as Vector3).x)
		key_max = maxf(key_max, (g.reg_fx as Vector3).z)
		jo_min = minf(jo_min, (g.reg_fx as Vector3).y)
		n_max = maxi(n_max, int(g.bu_n))
		if sz0 >= 0 and g.bu_t.size() != sz0:
			sz_same = false
		if hit_t > 0.0 and g.bu_n > 0:
			var landed := true
			for i in g.bu_t.size():
				if int(g.bu_k[i]) == 0 and float(g.bu_t[i]) >= 0.0 and int(g.bu_land[i]) == 0:
					landed = false
			if landed:
				all_land = true
		if hit_t > 0.0 and burst_end < 0.0 and g.bu_n == 0:
			burst_end = t
	var e2 := _econ()
	_ok("⑦ 값은 확정 순간 그대로 · 판 효과 동안 안 움직인다", e0 != e1 and e1 == e2,
			"%s → %s" % [e1, e2])
	_ok("⑦ 손이 치켜 올랐다 내리친다", hit_t > 0.0 and top_h - hit_h >= 24.0,
			"치켜든 손등 h %.1f → 닿은 틀 %.1f (%.1f)" % [top_h, hit_h, top_h - hit_h])
	_ok("⑦ 손바닥이 건반에 닿는다(치켜든 자리 · 닿은 자리)", palm_err < 1.0,
			"어긋남 최대 %.2f" % palm_err)
	_ok("⑦ 닿은 틀 손목이 한도 안", wb_hit.x <= 15.05 and wb_hit.y <= 25.05,
			"옆 %.1f° · 굽힘 %.1f°" % [wb_hit.x, wb_hit.y])
	var dpx: float = float(g.Room3D.REG_OPEN) * float(g.Room3D.BUY_K) * float(g.TBL.flat) * dr_max
	_ok("⑦ 서랍이 크게 튀어나온다(화면 18px 넘게)", dr_max >= 1.0 and dpx >= 18.0,
			"나온 몫 %.2f · 화면 %.1fpx" % [dr_max, dpx])
	_ok("⑦ 값 깃이 솟고 · 건반이 들어가고 · 몸이 튄다", fl_max > 1.05 and key_max > 0.99
			and jo_min < -0.1, "깃 %.2f · 건반 %.2f · 몸 튐 %.2f" % [fl_max, key_max, jo_min])
	_ok("⑦ 닿은 틀에 화면이 흔들린다", shake_hit >= float(g.BURST.shake) - 0.6,
			"%.2fpx" % shake_hit)
	var B: Dictionary = g.BURST
	_ok("⑦ 동전 · 나뭇조각 · 놋쇠 부스러기가 튄다", kinds[0] == int(B.coin)
			and kinds[1] == int(B.wood) and kinds[2] == int(B.brass),
			"동전 %d · 나무 %d · 놋쇠 %d" % [kinds[0], kinds[1], kinds[2]])
	_ok("⑦ 동전이 바닥에 떨어져 튄다", all_land, "")
	_ok("⑦ 판 효과가 다 가라앉는다", burst_end > 0.0 and burst_end - hit_t
			<= float((B.life as Vector2).y) + DT * 2.0,
			"닿은 뒤 %.2f초 (수명 상한 %.2f)" % [burst_end - hit_t, float((B.life as Vector2).y)])
	_ok("⑦ 한 사건의 소리가 넷 안(쿵 하나 + 톡)", 1 + int(g.bu_snd) <= 4
			and int(g.bu_snd) >= 1, "톡 %d" % int(g.bu_snd))
	_ok("⑦ 서랍이 다 닫히고 쉰다", g.reg_t < 0.0 and g.reg_open == 0.0
			and g.reg_fx == Vector3.ZERO, "")
	_ok("⑦ 판 효과 칸을 매 틀 새로 안 짓는다", sz_same and sz0 == int(B.coin) + int(B.wood)
			+ int(B.brass), "칸 %d" % sz0)
	#  정적 메모리 — 산 판 효과를 600 틀 굴리는 동안(다 가라앉으면 다시 낸다).
	g._burst_spawn()
	for k in 30:
		g._burst_tick(DT)
	var m0: int = OS.get_static_memory_usage()
	for k in 600:
		if g.bu_n <= 0:
			g._burst_spawn()
		g._burst_tick(DT)
		g._reg_tick(DT)
	var m1: int = OS.get_static_memory_usage()
	_ok("⑦ 판 효과가 매 틀 메모리를 안 짓는다", m0 > 0 and m1 - m0 <= 0,
			"정적 메모리 %d → %+d 바이트 (600 틀)" % [m0, m1 - m0])
	g._burst_clear()

	# 화면을 떠나면 걷힌다
	g._burst_spawn()
	g.state = g.S.LEG
	g._prop_tick(DT)
	_ok("⑦ 상점을 떠나면 판 효과가 걷힌다", g.bu_n == 0, "%d" % g.bu_n)
	g.state = g.S.SHOP

	# 움직임 끔 — 서랍이 한 번에 열리고 한 번에 닫힌다 · 흔들림 · 판 효과 없다
	_restore(base)
	_clear_acts()
	_calm()
	g.motion_off = true
	g.gold = 99
	bi = _buy_idx()
	g.buy_sel = bi
	g._pay_click()
	var mid := false
	var opened: bool = g.reg_open == 1.0
	var tm := 0.0
	var shut_t := -1.0
	while tm < 1.0:
		g._prop_tick(DT)
		tm += DT
		if g.reg_open > 0.0 and g.reg_open < 1.0:
			mid = true
		if shut_t < 0.0 and g.reg_open == 0.0:
			shut_t = tm
	_ok("⑦ 움직임 끔 — 서랍만 한 번에 열렸다 닫힌다", not g._prop_live(1) and opened
			and not mid and shut_t > 0.3 and g.bu_n == 0 and g.shake == 0.0,
			"열림 %s · 사이값 %s · 닫힘 %.2f초 · 판 효과 %d · 흔들림 %.1f" % [opened, mid, shut_t,
			g.bu_n, g.shake])
	g.motion_off = false

	# 바쁜 상인(건네는 중) — 옛 끄덕 + 서랍만 조용히
	_restore(base)
	_clear_acts()
	_calm()
	g.gold = 99
	g._give_begin(0, Vector2(200.0, g.TBL.fy))
	bi = _buy_idx()
	g.buy_sel = bi
	g._pay_click()
	g._prop_tick(DT)
	_ok("⑦ 바쁜 상인 — 끄덕 · 서랍만(판 효과 · 흔들림 없이)", not g._prop_live(1)
			and g.reg_t >= 0.0 and not g.reg_slam and g.bu_n == 0 and g.shake == 0.0,
			"서랍 %.2f · 판 효과 %d" % [g.reg_open, g.bu_n])
	g._give_end()
	g.give_rel = 0.0
	g.prop_force = false


#  주먹 밑면 — 그 틀 손에서 PROP.p_fist 를 낸다(_prop_place 의 역).
func _fist_pt() -> Vector3:
	var w: Vector3 = g.prop_lw[1]
	var b := Basis(Vector3.UP, -float(g.prop_la[1])) * Basis(Vector3.BACK, -float(g.prop_lp[1])) \
			* Basis(Vector3.RIGHT, deg_to_rad(float(g.PROP.p_roll)))
	var tp: Vector3 = g.PROP.p_fist
	return w + b * (Vector3(tp.x, tp.y, -tp.z) * float(g.NPC.sc_r))


#  주먹 한 번을 끝까지 돌리며 잰다 — 닿기 전 · 닿는 틀 · 끝.
func _pound_run(sweep: bool) -> Dictionary:
	var P: Dictionary = g.PROP
	var r := {"hit": false, "top": -999.0, "hit_h": 999.0, "err": 0.0, "rr": 0.0,
			"shake": 0.0, "kinds": [0, 0, 0, 0, 0, 0], "pc_before": "", "pc_after": "x",
			"wb": Vector2.ZERO, "open_t": -1.0, "dealt_t": -1.0, "wmax": 0.0}
	var tt := 0.0
	while tt < 2.0:
		var was: float = g.prop_t[1]
		g._prop_tick(DT)
		if sweep:
			g._sweep_update(DT)
		tt += DT
		_pose()
		var pt: float = g.prop_t[1]
		var fh: float = _fist_pt().y
		if pt >= float(P.p_up) and pt < float(P.p_hit):
			r.top = maxf(float(r.top), fh)
			r.pc_before = g.pc_id
		if pt >= float(P.p_up) and pt < float(P.p_hold):
			r.err = maxf(float(r.err), _fist_pt().distance_to(g._pound3(pt)))
			var wbn: Vector2 = g.npc_wb[1]
			r.wmax = maxf(float(r.wmax), maxf(wbn.x, wbn.y))
			r.rr = maxf(float(r.rr), float(g.prop_rr[1]))
		if was >= 0.0 and was < float(P.p_hit) and (pt >= float(P.p_hit) or pt < 0.0):
			r.hit = true
			r.hit_h = fh
			r.shake = g.shake
			r.wb = g.npc_wb[1]
			r.pc_after = g.pc_id
			for i in g.bu_t.size():
				if float(g.bu_t[i]) >= 0.0:
					(r.kinds as Array)[int(g.bu_k[i])] += 1
		if sweep and float(r.dealt_t) < 0.0 and g.sweep_dealt:
			r.dealt_t = pt
		if sweep and float(r.open_t) < 0.0 and not g.sweep_live:
			r.open_t = pt if pt >= 0.0 else 99.0
	return r


# ⑧ 주먹 — 「사탕을 사용하면 사탕이 테이블에 떨어지고 상점 주인이 주먹을 쥐고 사탕
#  부수는거」 · 「상점에 아이템이 없을때 리롤을 누르면 … 테이블을 주먹으로 쾅 내리치자」.
func _pound() -> void:
	var base := _snap()
	var P: Dictionary = g.PROP
	var Q: Dictionary = g.POUND
	# ── 사탕 ──
	_restore(base)
	_clear_acts()
	_calm()
	g.prop_force = true
	var cd: Dictionary = {}
	for c in GameData.candies():
		if String((c as Dictionary).get("id", "")).begins_with("c_") \
				and String((c as Dictionary).get("cat", "")) == "area":
			cd = (c as Dictionary).duplicate()
			break
	_ok("⑧ 쓸 사탕이 있다", not cd.is_empty(), String(cd.get("id", "")))
	if cd.is_empty():
		return
	g.cons = [cd]
	var tid: int = int(cd.track)
	var lv0: int = int(g.track_lv.get(tid, 0))
	wb_bad = 0
	wb_note = ""
	g._cons_use(0)
	_ok("⑧ 사탕 — 값은 쓰는 순간 오른다 · 칸이 빈다", int(g.track_lv.get(tid, 0)) == lv0 + 1
			and g.cons.is_empty(), "Lv %d → %d" % [lv0, int(g.track_lv.get(tid, 0))])
	_ok("⑧ 사탕 — 주먹 몸짓이 서고 사탕이 펠트로 난다", g._prop_live(1) and g.prop_pound == "candy"
			and g.pc_id == String(cd.id), "%s · %s" % [g.prop_pound, g.pc_id])
	var e1 := _econ()
	var rc := _pound_run(false)
	_ok("⑧ 사탕 — 닿기 전까지 사탕이 펠트에 있고 닿는 틀에 부서진다",
			bool(rc.hit) and String(rc.pc_before) == String(cd.id) and String(rc.pc_after) == "",
			"전 %s · 후 %s" % [rc.pc_before, rc.pc_after])
	var kc: Array = rc.kinds
	_ok("⑧ 사탕 — 사탕 색 조각 · 설탕 반짝이가 튄다", int(kc[3]) == int(Q.shard)
			and int(kc[4]) == int(Q.spark), "조각 %d · 반짝이 %d · 먼지 %d" % [kc[3], kc[4], kc[5]])
	_ok("⑧ 사탕 — 주먹이 치켜 올랐다 내리친다", float(rc.top) - float(rc.hit_h) >= 30.0,
			"주먹 밑 h %.1f → %.1f" % [float(rc.top), float(rc.hit_h)])
	_ok("⑧ 사탕 — 주먹 밑면이 과녁에 닿는다", float(rc.err) < 1.0, "어긋남 %.2f" % float(rc.err))
	_ok("⑧ 사탕 — 팔이 안 늘어난다", float(rc.rr) <= 1.0, "최대 %.3f" % float(rc.rr))
	_ok("⑧ 사탕 — 닿은 틀 흔들림", float(rc.shake) >= float(Q.shake_candy) - 0.6,
			"%.2fpx" % float(rc.shake))
	_ok("⑧ 사탕 — 손목이 모든 틀 한도 안", wb_bad == 0, "넘은 틀 %d %s" % [wb_bad, wb_note])
	#  망치 주먹 — 「왜 손목이 이렇게 휘어져?」(2026-10-04). 치켜든 뒤 · 닿는 틀 · 튄 뒤까지
	#  손목이 곧다(옆 · 굽힘 다 p_wrist 언저리).
	_ok("⑧ 사탕 — 주먹 동안 손목이 곧다(망치 주먹)", float(rc.wmax) <= float(P.p_wrist) + 0.6,
			"최대 꺾임 %.1f°" % float(rc.wmax))
	_ok("⑧ 사탕 — 몸짓 동안 값이 안 움직인다", _econ() == e1, "%s | %s" % [e1, _econ()])
	_ok("⑧ 사탕 — 끝나면 쉰다", not g._prop_live(1) and g.prop_pound == "" and g.pc_id == "", "")
	# 못 서면 옛 길 — 칸에서 팝(몸짓 없음)
	_restore(base)
	_clear_acts()
	g.prop_force = false
	g.cons = [cd.duplicate()]
	g._cons_use(0)
	_ok("⑧ 사탕 — 진열대가 없으면 옛 길(몸짓 없이 값만)", not g._prop_live(1) and g.pc_id == ""
			and g.cons.is_empty(), "")
	# 닿기 전에 끊기면 글은 지금 낸다
	_restore(base)
	_clear_acts()
	g.prop_force = true
	g.cons = [cd.duplicate()]
	g._cons_use(0)
	g._prop_tick(DT * 3.0)
	g.state = g.S.LEG
	g._prop_tick(DT)
	_ok("⑧ 사탕 — 화면을 떠나면 끊기고 사탕 그림이 안 남는다", g.pc_id == ""
			and float(g.prop_cut[1]) > 0.0, "cut %.2f" % float(g.prop_cut[1]))
	g.state = g.S.SHOP
	_tick(1.0)
	# ── 빈 테이블 ──
	_restore(base)
	_clear_acts()
	_calm()
	g.prop_force = true
	g.drop_fast = false
	for i in g.stock.size():
		g.stock[i].sold = true
	for i in g.drop.size():
		g.drop[i].sold = 1.0
	g.gold = 99
	_ok("⑧ 빈 테이블이다", g._shop_bare(), "")
	var rr0: int = g.rerolls_used
	wb_bad = 0
	wb_note = ""
	g._reroll()
	_ok("⑧ 빈 테이블 리롤 — 쓸기 대신 주먹이 선다", g.sweep_live and g.sweep_pound
			and g._prop_live(1) and g.prop_pound == "table" and g._sweep_amt() == 0.0
			and g.rerolls_used == rr0 + 1, "쓸기 %s · 주먹 %s · %s" % [g.sweep_live, g.sweep_pound,
			g.prop_pound])
	_ok("⑧ 닿기 전에는 판이 그대로(다 팔림)", g._shop_bare(), "")
	var gd1: int = g.gold
	g._reroll()
	_ok("⑧ 주먹 도중 리롤 — 골드가 안 나간다", g.gold == gd1, "%d → %d" % [gd1, g.gold])
	var rt := _pound_run(true)
	_ok("⑧ 빈 테이블 — 닿는 틀에 새 판이 깔린다", bool(rt.hit)
			and float(rt.dealt_t) >= float(P.p_hit) and float(rt.dealt_t) < float(P.p_hit) + DT * 2.0
			and not g._shop_bare(), "깔린 틀 %.3f · 닿음 %.2f" % [float(rt.dealt_t), float(P.p_hit)])
	var kt: Array = rt.kinds
	_ok("⑧ 빈 테이블 — 먼지가 일고 흔들린다", int(kt[5]) == int(Q.dust)
			and float(rt.shake) >= float(Q.shake_table) - 0.6, "먼지 %d · %.2fpx" % [kt[5],
			float(rt.shake)])
	_ok("⑧ 빈 테이블 — 주먹 밑면이 과녁에 닿는다 · 팔이 안 늘어난다", float(rt.err) < 1.0
			and float(rt.rr) <= 1.0, "어긋남 %.2f · 팔 %.3f" % [float(rt.err), float(rt.rr)])
	_ok("⑧ 빈 테이블 — 문은 눌러 둔 주먹이 튀고 나서 열린다", float(rt.open_t) >= float(P.p_hold)
			and float(rt.open_t) < float(P.p_hold) + DT * 2.0 and not g.sweep_live
			and not g.sweep_pound, "열린 틀 %.3f" % float(rt.open_t))
	_ok("⑧ 빈 테이블 — 매듭이 새 판 뒤 금화로 적힌다", int(Save.run_get("gold", -1)) == g.gold,
			"%s · %d" % [str(Save.run_get("gold", "-")), g.gold])
	_ok("⑧ 빈 테이블 — 손목이 모든 틀 한도 안", wb_bad == 0, "넘은 틀 %d %s" % [wb_bad, wb_note])
	# 못 서면 옛 쓸기
	_restore(base)
	_clear_acts()
	g.prop_force = false
	for i in g.stock.size():
		g.stock[i].sold = true
	for i in g.drop.size():
		g.drop[i].sold = 1.0
	g.gold = 99
	g._reroll()
	_ok("⑧ 빈 테이블 — 진열대가 없으면 옛 쓸기", g.sweep_live and not g.sweep_pound
			and not g._prop_live(1), "")
	g._sweep_reset()
	# 안 빈 테이블은 그대로 쓸기
	_restore(base)
	_clear_acts()
	g.prop_force = true
	g.gold = 99
	g._reroll()
	_ok("⑧ 물건이 남은 리롤은 그대로 쓸기", g.sweep_live and not g.sweep_pound
			and not g._prop_live(1), "")
	g._sweep_reset()
	# 개발자 줄 — 사탕 부수기 · 테이블 내리치기는 값을 안 건드린다
	_restore(base)
	_clear_acts()
	_calm()
	var na: int = (g.IDLE.acts as Array).size() + Dev.NPC_HOLDS.size()
	var dv0 := _econ()
	var lvs0: String = str(g.track_lv)
	Dev.pick["npcact"] = na + 2
	Dev._run(g, {"t": "list", "k": "npcact", "n": na + 4})
	var d2: bool = g._prop_live(1) and g.prop_pound == "candy"
	_tick(1.5)
	Dev.pick["npcact"] = na + 3
	Dev._run(g, {"t": "list", "k": "npcact", "n": na + 4})
	var d3: bool = g._prop_live(1) and g.prop_pound == "table"
	_tick(1.5)
	_ok("⑧ 개발자 「사탕 부수기」 · 「테이블 내리치기」가 선다", d2 and d3, "%s · %s" % [d2, d3])
	_ok("⑧ 개발자 줄이 값 · 트랙 레벨 · 판을 안 건드린다", _econ() == dv0
			and str(g.track_lv) == lvs0, "%s | %s" % [dv0, _econ()])
	g.drop_fast = true
	g.prop_force = false
