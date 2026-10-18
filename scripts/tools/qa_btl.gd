extends SceneTree
# 술병 이스터에그(2026-10-10 · game.gd BTL · BDUEL · _secret_deal) — 못 박는 것:
#   ① 술병 자리는 씨 고정이다 — 몇 번을 물어도 같은 표 · 일흔 병 남짓 · 선반 셋.
#   ② 상점(튜토리얼 아님)에서만 깬다. 한 번에 고른 병과 그 이웃이 깨지고, 이웃은 같은 선반이 먼저다.
#   ③ 다 깨면 상인이 내리치고(단 1) 시계 뒤 술병 대결로 간다 — 그동안 상점을 못 떠난다.
#   ③′ 상인 몸 · 팔과 동전 슬롯 띠가 가린 병은 다 깨기에 안 든다 — 보이는 병만 깨도 내리치고 선반이 빈다
#      (2026-10-16 「상인 뒤 술병은 이스터에그 발동에 필요없도록」) · 이웃도 보이는 병만 고른다.
#   ④ 대결은 판 상태(꽂힌 다트 · 제약 · 판 기하)를 비켜 두고 영구 판으로 한다.
#   ⑤ 상인이 n 병 · 내가 n 병 — 점수는 판의 수 그대로(칸 × 띠 · 불 · 빗나감 0)이고 합으로 겨룬다.
#      잡기 차례에는 불이 늘 잡힌다(가운데 줄은 어느 반쪽이든 지킨다).
#   ⑥ 이기면 비밀 상점 — 테이블이 레전더리 동전으로만 깔린다 · 판 상태가 돌아온다 · 단 2.
#   ⑦ 지면 상점 그대로 돌아간다 · 단 2(런마다 한 번).
#   ⑧ 깬 병 · 단은 이어하기에 적히고, 새 런은 선반을 다시 세운다.
#   ⑨ 대결 중에는 일시정지가 안 열린다(ESC).
#   ⑩ 보스(2026-10-18) — 상인 · 나 번갈아 · 수(잡기 · 깨기 · 쉬기)는 대결마다 셋 다 한 번씩 ·
#      잡기는 지키는 반쪽으로 던지면 0점 · 반대쪽은 산다 · 깨기는 셈이 끝난 뒤 던지면 0점 · 셈 안에 던지면 산다.
#   godot --headless --path . --script scripts/tools/qa_btl.gd
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
const Room3D = preload("res://scripts/room3d.gd")
var g = null
var ok := 0
var bad := 0
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_qa_btl_g.cfg"
	Save.path = "user://_qa_btl.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if g != null:
		g.set_process(false)
	if busy:
		return false
	busy = true
	_run()
	print("통과 %d · 실패 %d" % [ok, bad])
	quit(1 if bad > 0 else 0)
	return false


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-52s %s" % ["통과" if cond else "실패", nm, note])


func _shop() -> void:
	g._new_run()
	g.tut_run = false
	g.gold = 30
	g._open_shop()
	g._swap_skip()


#  대결을 끝까지 민다. mine 은 내 병이 꽂힐 자리.
func _duel(mine: Vector2) -> void:
	_duel_f(func(): return mine)


#  대결을 끝까지 민다 — 내 병 자리는 pick(차례마다 부른다) · slow 면 깨기 셈이 끝난 뒤 잡는다.
#  나는 병이 떠날 때마다 누가 던졌는지를 돌려준다.
func _duel_f(pick: Callable, slow := false) -> Array:
	var order := []
	var ph0 := ""
	for i in 4000:
		if g.bd_ph == "end":
			break
		if g.bd_ph == "aim_v" and (not slow or g.bd_ready or g.bd_move != "shoot"):
			g._bduel_click(Vector2(-1.0, -1.0))
		elif g.bd_ph == "aim_h":
			g.aim = pick.call()
			g._bduel_click(Vector2(-1.0, -1.0))
		if g.bd_ph == "fly" and ph0 != "fly":
			order.append(g.bd_who)
		ph0 = g.bd_ph
		g._bduel_tick(1.0 / 60.0)
	return order


func _run() -> void:
	# ①
	var lay: Array = Room3D.bottle_layout()
	var lay2: Array = Room3D.bottle_layout()
	_ok("① 몇 번을 물어도 같은 표", str(lay) == str(lay2))
	_ok("① 일흔 병 남짓", lay.size() >= 50 and lay.size() <= 90, "%d병" % lay.size())
	var shelves := {}
	for b in lay:
		shelves[int(b.s)] = true
	_ok("① 선반 셋", shelves.size() == 3)

	# ②
	_shop()
	_ok("② 상점에서 깬다", g._btl_open())
	g.tut_run = true
	_ok("② 튜토리얼 런에는 없다", not g._btl_open())
	g.tut_run = false
	#  셋 — 가린 병을 빼면(③′) 0 번 곁의 보이는 같은 선반 병이 둘뿐이라 넷째는 바로 위 선반 끝으로 간다
	g._btl_break(0, 3)
	_ok("② 한 번에 고른 병과 이웃 둘", g.btl_gone.size() == 3 and g.btl_gone.has(0), str(g.btl_gone))
	var same := true
	for k in g.btl_gone:
		if int(lay[k].s) != int(lay[0].s):
			same = false
	_ok("② 이웃은 같은 선반이 먼저", same)
	_ok("② 아직 선반 단", g.btl_st == 0)

	# ③
	g._btl_break(g.btl_gone.size(), lay.size())
	for k in lay.size():
		if not g.btl_gone.has(k):
			g._btl_break(k, lay.size())
	_ok("③ 다 깼다", g.btl_gone.size() == lay.size(), "%d / %d" % [g.btl_gone.size(), lay.size()])
	_ok("③ 상인이 내리친다(단 1)", g.btl_st == 1)
	_ok("③ 대결로 가는 시계가 선다", g.btl_go > 0.0, "%.2f" % g.btl_go)
	# ③′
	_shop()
	var vis := []
	for k in lay.size():
		if not g._btl_hid(k):
			vis.append(k)
	_ok("③′ 보이는 병은 가린 병보다 적다(선반 셋 중 위는 띠 밑)", vis.size() >= 10 and vis.size() < lay.size() / 2,
			"%d / %d" % [vis.size(), lay.size()])
	g._btl_break(int(vis[0]), 4)
	var hid_hit := (g.btl_gone as Array).filter(func(k): return g._btl_hid(int(k)))
	_ok("③′ 이웃은 보이는 병만", hid_hit.is_empty(), str(g.btl_gone))
	for k in vis:
		if not g.btl_gone.has(k):
			g._btl_break(int(k), 1)
	_ok("③′ 보이는 병만 깨도 내리친다 · 선반이 빈다", g.btl_st == 1 and g.btl_gone.size() == lay.size(),
			"단 %d · %d / %d" % [g.btl_st, g.btl_gone.size(), lay.size()])
	var leg0: int = g.leg_no
	g._click(g._next_rect().get_center())
	_ok("③ 그동안 상점을 못 떠난다", g.state == g.S.SHOP and g.leg_no == leg0)
	g.darts = [{"p": g.BC, "id": "std", "rot": 0.0}]
	g.active_mods = [{"id": "fog"}]
	g.rt_dbl_out = 0.5
	for i in 120:
		g._btl_tick(1.0 / 60.0)
		if g.state == g.S.BDUEL:
			break
	_ok("③ 시계 뒤 술병 대결", g.state == g.S.BDUEL, "state %d" % g.state)

	# ④
	_ok("④ 꽂힌 다트를 비켜 둔다", g.darts.is_empty())
	_ok("④ 제약을 비켜 둔다", g.active_mods.is_empty())
	_ok("④ 영구 판 기하", is_equal_approx(g.rt_dbl_out, g.dbl_out), "%.2f" % g.rt_dbl_out)

	# ⑤ · ⑥ — 내 병은 전부 이너 불
	var bull: int = g._bduel_score(g.BC)
	var hi: Dictionary = g.hit_info(g.BC)
	_ok("⑤ 점수는 판의 수 그대로(불)", bull == int(hi.base) * int(hi.mult) and bull > 0, "%d" % bull)
	_ok("⑤ 빗나감은 0", g._bduel_score(g.BC + Vector2(g.R * 1.6, 0.0)) == 0)
	_duel(g.BC)
	_ok("⑤ 상인 n 병 · 나 n 병", int(g.bd_i[0]) == int(g.BDUEL.n) and int(g.bd_i[1]) == int(g.BDUEL.n),
			str(g.bd_i))
	var s0 := 0
	for v in g.bd_hits[0]:
		s0 += int(v)
	var free: int = (g.bd_moves as Array).filter(func(m): return m != "catch").size()
	_ok("⑤ 합은 병마다 점수의 합(잡기 차례의 불은 잡힌다)", int(g.bd_sc[0]) == s0
			and int(g.bd_sc[1]) == bull * free, "상인 %d · 나 %d · 수 %s" % [g.bd_sc[0], g.bd_sc[1], str(g.bd_moves)])
	_ok("⑤ 큰 쪽이 이긴다", g.bd_won == (int(g.bd_sc[1]) > int(g.bd_sc[0])))
	g.bd_won = true             # 상인 합이 불 셋을 넘는 판도 있다 — 이긴 길을 못 박는다
	g.bd_t = 1.0
	g._bduel_click(Vector2(-1.0, -1.0))
	_ok("⑥ 상점으로 돌아온다", g.state == g.S.SHOP, "state %d" % g.state)
	_ok("⑥ 판 상태가 돌아온다", g.darts.size() == 1 and g.active_mods.size() == 1
			and is_equal_approx(g.rt_dbl_out, 0.5))
	var all_leg: bool = not g.stock.is_empty()
	for st in g.stock:
		var d: Dictionary = st.d
		if String(st.type) != "item" or String(d.get("rarity", "")) != "legendary" \
				or not bool(st.get("secret", false)):
			all_leg = false
	_ok("⑥ 비밀 상점 — 레전더리 동전으로만", all_leg, "%d칸" % g.stock.size())
	_ok("⑥ 단 2", g.btl_st == 2)
	_ok("⑥ 다시는 깨지 않는다", not g._btl_open())

	# ⑦
	_shop()
	g.btl_st = 1
	g._bduel_enter()
	_duel(g.BC + Vector2(g.R * 1.6, 0.0))
	_ok("⑦ 빗나가기만 하면 진다", not g.bd_won and int(g.bd_sc[1]) == 0)
	var stock0: String = str(g.stock)
	g.bd_t = 1.0
	g._bduel_click(Vector2(-1.0, -1.0))
	_ok("⑦ 지면 상점 그대로", g.state == g.S.SHOP and str(g.stock) == stock0)
	_ok("⑦ 단 2", g.btl_st == 2)

	# ⑧
	_shop()
	g._btl_break(3, 5)
	var gone: Array = (g.btl_gone as Array).duplicate()
	g._knot("shop")
	g.btl_gone = []
	g._run_load()
	_ok("⑧ 이어하기 — 깬 병이 그대로", str(g.btl_gone) == str(gone), str(g.btl_gone))
	g._new_run()
	_ok("⑧ 새 런은 선반을 다시 세운다", g.btl_gone.is_empty() and g.btl_st == 0)

	# ⑨
	_shop()
	g.btl_st = 1
	g._bduel_enter()
	var ev := InputEventKey.new()
	ev.keycode = KEY_ESCAPE
	ev.pressed = true
	g._unhandled_input(ev)
	_ok("⑨ 대결 중 ESC 는 일시정지를 안 연다", g.state == g.S.BDUEL, "state %d" % g.state)

	# ⑩
	_shop()
	g.btl_st = 1
	g._bduel_enter()
	var mv: Array = g.bd_moves
	_ok("⑩ 수는 대결마다 셋 다 한 번씩", mv.size() == 3 and mv.has("catch") and mv.has("shoot") and mv.has("rest"),
			str(mv))
	var order := _duel_f(func(): return g.BC + Vector2(0.0, -g.R * 0.3))
	_ok("⑩ 상인 · 나 번갈아(상인 먼저)", str(order) == str([0, 1, 0, 1, 0, 1]), str(order))
	var far := func(): return g.BC + Vector2(-g.bd_side * g.R * 0.5, 0.0)
	var near := func(): return g.BC + Vector2(g.bd_side * g.R * 0.5, 0.0)
	for c in [["catch", near, false, true], ["catch", far, false, false],
			["shoot", near, true, true], ["shoot", near, false, false], ["rest", near, true, false]]:
		_shop()
		g.btl_st = 1
		g._bduel_enter()
		g.bd_moves = [c[0], c[0], c[0]]
		_duel_f(c[1], c[2])
		var hs: Array = g.bd_hits[1]
		var zero := true
		var some := true
		for v in hs:
			zero = zero and int(v) == 0
			some = some and int(v) > 0
		var side: String = ("지키는 쪽" if c[1] == near else "반대쪽") if c[0] == "catch" else "아무 데"
		var late: String = " · 늦게" if c[2] else ""
		var want: String = "0점" if c[3] else "산다"
		var good: bool = zero if c[3] else some
		_ok("⑩ %s · %s%s → %s" % [c[0], side, late, want], good and hs.size() == 3, str(hs))
