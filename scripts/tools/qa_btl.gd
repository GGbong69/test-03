extends SceneTree
# 술병 이스터에그(2026-10-10 · game.gd BTL · BDUEL · _secret_deal) — 못 박는 것:
#   ① 술병 자리는 씨 고정이다 — 몇 번을 물어도 같은 표 · 일흔 병 남짓 · 선반 셋.
#   ② 상점(튜토리얼 아님)에서만 깬다. 한 번에 고른 병과 그 이웃이 깨지고, 이웃은 같은 선반이 먼저다.
#   ③ 다 깨면 상인이 내리치고(단 1) 시계 뒤 술병 대결로 간다 — 그동안 상점을 못 떠난다.
#   ④ 대결은 판 상태(꽂힌 다트 · 제약 · 판 기하)를 비켜 두고 영구 판으로 한다.
#   ⑤ 상인이 n 병 · 내가 n 병 — 점수는 판의 수 그대로(칸 × 띠 · 불 · 빗나감 0)이고 합으로 겨룬다.
#   ⑥ 이기면 비밀 상점 — 테이블이 레전더리 동전으로만 깔린다 · 판 상태가 돌아온다 · 단 2.
#   ⑦ 지면 상점 그대로 돌아간다 · 단 2(런마다 한 번).
#   ⑧ 깬 병 · 단은 이어하기에 적히고, 새 런은 선반을 다시 세운다.
#   ⑨ 대결 중에는 일시정지가 안 열린다(ESC).
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
	for i in 2000:
		if g.bd_ph == "end":
			break
		if g.bd_ph == "aim_v":
			g._bduel_click(Vector2(-1.0, -1.0))
		elif g.bd_ph == "aim_h":
			g.aim = mine
			g._bduel_click(Vector2(-1.0, -1.0))
		g._bduel_tick(1.0 / 60.0)


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
	g._btl_break(0, 4)
	_ok("② 한 번에 고른 병과 이웃 넷", g.btl_gone.size() == 4 and g.btl_gone.has(0), str(g.btl_gone))
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
	_ok("⑤ 합은 병마다 점수의 합", int(g.bd_sc[0]) == s0 and int(g.bd_sc[1]) == bull * int(g.BDUEL.n),
			"상인 %d · 나 %d" % [g.bd_sc[0], g.bd_sc[1]])
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
