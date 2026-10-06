extends SceneTree
# 팩 남은 것 부수기(2026-10-06) — 「플레이어가 아이템을 고른후 남은 아이템들은 NPC가 부쉬는걸로
# 해줄래? 2개 짜리 팩이면 하나만 부쉬면 되겠고 4개 짜리는 NPC가 테이블을 내리치고 아이템들이 위로
# 올라갔다가 테이블에 떨어지면서 부숴지는걸로 하자」. 못 박는 것:
#   ① 작은 팩 — 하나를 고르면 남은 하나는 값이 닫히고(sold) 판 위에 남아 못 집히고 · 계산대로 안
#      날고 · 등록기 대신 주먹(crush)이 그 위로 온다. 주먹 밑면이 물건 자리에 닿고 · 팔이 안
#      늘어나고 · 닿는 틀에 그 자리에서 부서진다(조각이 사방으로). 값은 고른 순간 그대로다.
#   ② 큰 팩 — 하나를 고르면 상인이 빈 자리를 내리치고(slam · 주먹이 남은 것 위가 아니다) 닿는
#      틀에 남은 셋이 다 뜬다. 뜬 것은 밑의 물건을 안 민다. 하나씩 다른 틀에 펠트에 닿으며
#      부서지고 · 1초 안에 다 사라진다. 팩 밖 매물은 안 부서진다.
#   ③ 하나라도 팔 밖이면 slam 이다.
#   ④ 몸짓이 못 서면(진열대 없음) 그 자리에서 곧장 부서진다 · 움직임을 끄면 조각 없이 사라진다.
#   ⑤ 끊기면(닿기 전) 그 자리에서 부서진다 · 뜬 채 정착(_drop_settle)이 들면 그 자리에서 부서진다.
#   ⑥ 매듭(저장)이 남은 것을 팔린 것으로 적는다 — 되살린 상점에 안 돌아온다.
#   ⑦ 개발자 「상인 몸짓 — 팩 하나 부수기 · 팩 셋 내리치기」가 서고 값을 안 건드린다.
# 헤드리스라 진열대(3D)가 없다 — 몸짓은 prop_force 로 세우고, 손 자세는 npc_dry 로 셈한다.
#   godot --headless --path . --script scripts/tools/qa_crush.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const DT := 1.0 / 60.0
var g = null
var ok := 0
var bad := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_crush_g.cfg"
	Save.path = "user://_qa_crush.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
	_run()
	print("통과 %d · 실패 %d" % [ok, bad])
	quit(1 if bad > 0 else 0)


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-48s %s" % ["통과" if cond else "실패", nm, note])


func _calm() -> void:
	g.idle_act = -1
	g.idle_t = 0.0
	g.idle_wait = 99.0
	g.npc_eye = 0.0


func _clear_acts() -> void:
	for i in 2:
		if g._prop_live(i):
			g._prop_end(i)


#  한 틀 — 몸짓 시계 · 낙하(조각 포함) · 손 자세.
func _frame() -> void:
	g._prop_tick(DT)
	g._drop_update(DT)
	g.npc_dry = true
	g._npc_arms()
	g.npc_dry = false


func _fist_pt() -> Vector3:
	var w: Vector3 = g.prop_lw[1]
	var b := Basis(Vector3.UP, -float(g.prop_la[1])) * Basis(Vector3.BACK, -float(g.prop_lp[1])) \
			* Basis(Vector3.RIGHT, deg_to_rad(g._fist_roll(1)))
	var tp: Vector3 = g.PROP.p_fist
	return w + b * (Vector3(tp.x, tp.y, -tp.z) * float(g.NPC.sc_r))


func _econ() -> String:
	var so := ""
	for s in g.stock:
		so += "1" if bool((s as Dictionary).get("sold", false)) else "0"
	var ow := []
	for o in g.owned:
		ow.append(String((o as Dictionary).get("id", "")))
	return "금화 %d · 동전 %s · 매물 %s · 사탕 %d · 몫 %d" % [g.gold, ",".join(ow), so,
			g.cons.size(), g.boost_pick]


#  새 상점 — 매물을 깔고 다 앉힌다.
func _shop() -> void:
	_clear_acts()
	_calm()
	g._sweep_reset()
	g.gold = 99
	g.owned = []
	g.cons = []
	g.motion_off = false
	g.buy_sel = -1
	g._roll_stock()
	g._drop_settle()


#  팩을 사서 다 뜯는다 — 쏟은 것의 stock 자리. 쏟은 것도 다 앉힌다.
func _open(size: int) -> Array:
	var bd: Dictionary = {}
	for b in GameData.boosters():
		if int((b as Dictionary).get("size", 0)) == size:
			bd = b
	var before: int = g.stock.size()
	g._boost_deal(bd)
	for k in 400:
		g._boost_tick(DT)
		if g.boost_t < 0.0:
			break
	g._drop_settle()
	var out := []
	for i in range(before, g.stock.size()):
		if bool(g.stock[i].get("pack", false)):
			out.append(i)
	return out


func _doomed(v: int) -> Array:
	var out := []
	for i in g.drop.size():
		if int(g.drop[i].get("doom", 0)) == v and not bool(g.drop[i].gone):
			out.append(i)
	return out


func _run() -> void:
	g.state = g.S.TITLE
	g._new_run()
	g.leg_no = 2
	g._open_shop()
	g.drop_fast = true
	print("상점 — 매물 %d · 진열대 %s(헤드리스는 거짓)" % [g.stock.size(), g._room3d_tbl()])
	_small()
	_big()
	_far()
	_fallback()
	_cut()
	_knot()
	_dev()


# ① 작은 팩
func _small() -> void:
	_shop()
	g.prop_force = true
	var ks := _open(2)
	_ok("① 작은 팩 — 둘이 쏟아진다", ks.size() == 2, "%d" % ks.size())
	if ks.size() != 2:
		return
	var pick: int = ks[0]
	var left: int = ks[1]
	#  팔 안 자리로 옮긴다(팔 밖은 ③).
	g.drop[left].u = 430.0
	g.drop[left].w = 70.0
	var at0 := Vector2(float(g.drop[left].u), float(g.drop[left].w))
	var n0: int = g.crush_n
	var sh0: int = g.shards.size()
	g._pay_take(pick)
	var e1 := _econ()
	_ok("① 고른 것은 손에 · 남은 것은 값이 닫힌다", bool(g.stock[pick].sold)
			and bool(g.stock[left].sold) and g.boost_pick == 0, e1)
	_ok("① 남은 것은 판 위에 남아 주먹을 기다린다", int(g.drop[left].get("doom", 0)) == 1
			and not bool(g.drop[left].gone) and float(g.drop[left].sold) <= 0.0, "")
	_ok("① 등록기 대신 주먹 — 그 물건 위로(crush)", g._prop_live(1) and g.prop_pound == "crush"
			and Vector2(g.prop_pound_at.x, g.prop_pound_at.z).distance_to(at0) < 0.5,
			"%s · %s" % [g.prop_pound, str(g.prop_pound_at)])
	var sc: Vector2 = g._p2s(float(g.drop[left].u), float(g.drop[left].w), 0.0)
	_ok("① 남은 것은 못 집는다", g._shop_hit(sc) != left, "누른 자리 %s → %d" % [str(sc),
			g._shop_hit(sc)])
	var P: Dictionary = g.PROP
	var hit := false
	var gone_at := -1.0
	var err := 0.0
	var rr := 0.0
	var top := -999.0
	var hit_h := 999.0
	var leave := false
	var sh_hit := 0
	var tt := 0.0
	while tt < 2.0:
		var was: float = g.prop_t[1]
		_frame()
		tt += DT
		var pt: float = g.prop_t[1]
		if float(g.drop[left].sold) > 0.0:
			leave = true
		if pt >= float(P.p_up) and pt < float(P.p_hit):
			top = maxf(top, _fist_pt().y)
		if pt >= float(P.p_up) and pt < float(P.p_hold):
			err = maxf(err, _fist_pt().distance_to(g._pound3(pt)))
			rr = maxf(rr, float(g.prop_rr[1]))
		if was >= 0.0 and was < float(P.p_hit) and (pt >= float(P.p_hit) or pt < 0.0):
			hit = true
			hit_h = _fist_pt().y
			sh_hit = g.shards.size() - sh0
		if gone_at < 0.0 and bool(g.drop[left].gone):
			gone_at = pt
	_ok("① 주먹이 치켜 올랐다 그 위로 내리친다", hit and top - hit_h >= 30.0,
			"주먹 밑 h %.1f → %.1f" % [top, hit_h])
	_ok("① 주먹 밑면이 과녁에 닿는다 · 팔이 안 늘어난다", err < 1.0 and rr <= 1.0,
			"어긋남 %.2f · 늘어남 %.3f" % [err, rr])
	_ok("① 닿는 틀에 부서진다", gone_at >= float(P.p_hit) - 0.02 and gone_at < float(P.p_hit) + 0.03
			and g.crush_n == n0 + 1, "사라진 틀 t %.3f (닿음 %.2f)" % [gone_at, float(P.p_hit)])
	_ok("① 조각이 사방으로 튄다", sh_hit >= int(g.CRUSH.shard) - 1, "조각 %d" % sh_hit)
	_ok("① 계산대로 안 난다", not leave, "")
	_ok("① 몸짓 동안 값이 안 움직인다", _econ() == e1, "%s | %s" % [e1, _econ()])
	_ok("① 끝나면 쉬고 조각도 가라앉는다", not g._prop_live(1) and g.shards.is_empty(),
			"조각 %d" % g.shards.size())
	g.prop_force = false


# ② 큰 팩
func _big() -> void:
	_shop()
	g.prop_force = true
	var ks := _open(4)
	_ok("② 큰 팩 — 넷이 쏟아진다", ks.size() == 4, "%d" % ks.size())
	if ks.size() != 4:
		return
	var pick: int = ks[0]
	var lefts: Array = ks.slice(1)
	var n0: int = g.crush_n
	#  팩 밖 매물 자리 — 뜬 것이 밀면 움직인다.
	var others := {}
	for i in g.drop.size():
		if not bool(g.stock[i].get("pack", false)) and not bool(g.drop[i].gone) \
				and float(g.drop[i].sold) <= 0.0:
			others[i] = Vector2(float(g.drop[i].u), float(g.drop[i].w))
	g._pay_take(pick)
	var e1 := _econ()
	_ok("② 남은 셋이 주먹을 기다린다", _doomed(1).size() == 3, "%s" % str(_doomed(1)))
	_ok("② 테이블을 내리친다(slam)", g._prop_live(1) and g.prop_pound == "slam", g.prop_pound)
	var at := Vector2(g.prop_pound_at.x, g.prop_pound_at.z)
	var near := 1.0e9
	for i in lefts:
		near = minf(near, at.distance_to(Vector2(float(g.drop[i].u), float(g.drop[i].w))))
	_ok("② 주먹은 남은 것 위가 아니다", near >= 30.0, "가장 가까운 것 %.1f" % near)
	var P: Dictionary = g.PROP
	var hit_t := -1.0
	var up_all := false
	var maxh := {}
	var gone_t := {}
	var sh_max := 0
	var tt := 0.0
	while tt < 2.5:
		var was: float = g.prop_t[1]
		_frame()
		tt += DT
		var pt: float = g.prop_t[1]
		if hit_t < 0.0 and was >= 0.0 and was < float(P.p_hit) and pt >= float(P.p_hit):
			hit_t = tt
			up_all = _doomed(2).size() == 3
		for i in lefts:
			maxh[i] = maxf(float(maxh.get(i, 0.0)), float(g.drop[i].h))
			if not gone_t.has(i) and bool(g.drop[i].gone):
				gone_t[i] = tt
		sh_max = maxi(sh_max, g.shards.size())
	_ok("② 닿는 틀에 셋이 다 뜬다", hit_t > 0.0 and up_all, "")
	var lo := 999.0
	for i in lefts:
		lo = minf(lo, float(maxh.get(i, 0.0)))
	_ok("② 높이 뜬다", lo >= 25.0, "가장 낮은 정점 h %.1f" % lo)
	var ts := []
	for i in lefts:
		ts.append(float(gone_t.get(i, -1.0)))
	ts.sort()
	_ok("② 다 부서진다 — 1초 안", ts.size() == 3 and float(ts[0]) > hit_t
			and float(ts[2]) - hit_t <= 1.0 and g.crush_n == n0 + 3,
			"닿음 뒤 %s" % str(ts.map(func(x): return snappedf(float(x) - hit_t, 0.01))))
	_ok("② 하나씩 다른 틀에 떨어진다", ts.size() == 3 and float(ts[1]) - float(ts[0]) >= 0.03
			and float(ts[2]) - float(ts[1]) >= 0.03, "")
	_ok("② 조각이 난다", sh_max >= 2 * int(g.CRUSH.shard), "동시 최대 %d" % sh_max)
	var moved := 0.0
	var lost := 0
	for i in others:
		if bool(g.drop[i].gone):
			lost += 1
		moved = maxf(moved, (others[i] as Vector2).distance_to(
				Vector2(float(g.drop[i].u), float(g.drop[i].w))))
	_ok("② 팩 밖 매물은 그대로다", lost == 0 and moved < 0.5,
			"사라짐 %d · 가장 많이 밀림 %.2f" % [lost, moved])
	_ok("② 몸짓 동안 값이 안 움직인다", _econ() == e1, "%s | %s" % [e1, _econ()])
	_ok("② 끝나면 쉬고 물리가 잔다", not g._prop_live(1) and not g.drop_awake
			and g.shards.is_empty(), "")
	g.prop_force = false


# ③ 팔 밖
func _far() -> void:
	_shop()
	g.prop_force = true
	var ks := _open(2)
	if ks.size() != 2:
		_ok("③ 작은 팩", false)
		return
	g.drop[ks[1]].u = 150.0
	g.drop[ks[1]].w = 112.0
	g._pay_take(ks[0])
	_ok("③ 하나라도 팔 밖이면 테이블을 내리친다", g.prop_pound == "slam", g.prop_pound)
	var n0: int = g.crush_n
	var tt := 0.0
	var flew := false
	while tt < 2.0:
		_frame()
		tt += DT
		flew = flew or float(g.drop[ks[1]].h) > 10.0
	_ok("③ 떴다가 부서진다", flew and bool(g.drop[ks[1]].gone) and g.crush_n == n0 + 1, "")
	g.prop_force = false


# ④ 못 서면 · 움직임 끔
func _fallback() -> void:
	for off in [false, true]:
		_shop()
		g.prop_force = false
		var ks := _open(4)
		if ks.size() != 4:
			_ok("④ 큰 팩", false)
			return
		g.motion_off = off
		var sh0: int = g.shards.size()
		var n0: int = g.crush_n
		g._pay_take(ks[0])
		var gone := 0
		for i in ks.slice(1):
			if bool(g.drop[i].gone):
				gone += 1
		var nm := "움직임 끔 — 조각 없이 사라진다" if off else "진열대가 없다 — 그 자리에서 곧장 부서진다"
		_ok("④ " + nm, not g._prop_live(1) and gone == 3 and g.crush_n == n0 + 3
				and (g.shards.size() == sh0 if off else g.shards.size() > sh0),
				"사라짐 %d · 조각 %d → %d" % [gone, sh0, g.shards.size()])
		g.motion_off = false


# ⑤ 끊김 · 정착
func _cut() -> void:
	_shop()
	g.prop_force = true
	var ks := _open(2)
	if ks.size() != 2:
		_ok("⑤ 작은 팩", false)
		return
	g.drop[ks[1]].u = 430.0
	g.drop[ks[1]].w = 70.0
	g._pay_take(ks[0])
	for k in 6:
		_frame()
	g._prop_cut_now(1)
	_ok("⑤ 닿기 전에 끊겨도 그 자리에서 부서진다", bool(g.drop[ks[1]].gone)
			and not g.shards.is_empty(), "")
	for k in 60:
		_frame()
	_ok("⑤ 끊긴 손은 쉼으로", not g._prop_live(1), "")
	_shop()
	var kb := _open(4)
	if kb.size() != 4:
		_ok("⑤ 큰 팩", false)
		return
	g._pay_take(kb[0])
	var P: Dictionary = g.PROP
	var guard := 0
	while g.prop_t[1] < float(P.p_hit) + 0.05 and guard < 200:
		_frame()
		guard += 1
	var up := _doomed(2).size()
	g._drop_settle()
	var gone := 0
	for i in kb.slice(1):
		if bool(g.drop[i].gone):
			gone += 1
	_ok("⑤ 뜬 채 정착이 들면 그 자리에서 부서진다", up == 3 and gone == 3,
			"뜬 것 %d · 사라짐 %d" % [up, gone])
	_clear_acts()
	g.prop_force = false


# ⑥ 매듭
func _knot() -> void:
	_shop()
	var ks := _open(4)
	if ks.size() != 4:
		_ok("⑥ 큰 팩", false)
		return
	g._pay_take(ks[0])
	var st: Array = Save.run_get("stock", [])
	var packs := 0
	var open := 0
	for e in st:
		if bool((e as Dictionary).get("pack", false)):
			packs += 1
			if not bool((e as Dictionary).get("sold", false)):
				open += 1
	_ok("⑥ 매듭이 남은 것을 팔린 것으로 적는다", packs == 4 and open == 0 \
			and int(Save.run_get("boost_pick", -1)) == 0, "팩 %d · 열린 것 %d" % [packs, open])


# ⑦ 개발자 줄
func _dev() -> void:
	for z in [4, 5]:
		_shop()
		g.prop_force = true
		var e0 := _econ()
		var n0: int = g.crush_n
		var why: String = g._prop_preview(z)
		var kind: String = g.prop_pound
		var want := 1 if z == 4 else 3
		var tt := 0.0
		while tt < 2.5:
			_frame()
			tt += DT
		_ok("⑦ 개발자 「%s」" % ("팩 하나 부수기" if z == 4 else "팩 셋 내리치기"), why == ""
				and kind == ("crush" if z == 4 else "slam") and g.crush_n == n0 + want,
				"%s · %s · 부서짐 %d" % [why, kind, g.crush_n - n0])
		var e1 := _econ()
		#  지은 팩 줄은 sold 로 매물 끝에 붙는다 — 그 몫을 빼고 견준다.
		_ok("⑦ 값을 안 건드린다", e1.begins_with(e0.substr(0, e0.find(" · 매물")))
				and g.boost_pick == 0, "%s | %s" % [e0, e1])
	g.prop_force = false
