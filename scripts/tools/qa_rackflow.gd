extends SceneTree
# 동전 슬롯 끌기 — 발라트로처럼 비켜선다(2026-10-08 · game.gd RACKF) — 못 박는 것:
#   ① 끄는 동안 다른 동전의 칸은 「든 동전을 빼고 떨어질 칸에 끼운 차례」다 — 떨어질 칸이 빈다.
#      칸 밖 · 창구 위에서는 제자리가 빈 채로 기다린다.
#   ② 떨어질 칸(_rack_drop_at)은 뗄 때 실제로 끼우는 칸과 같다 — 놓은 뒤 차례가 그 칸에 서 있다.
#   ③ 그려지는 자리는 스프링으로 그 칸에 닿는다(1초 안에 0.5px).
#   ④ 놓는 순간 비켜서 있던 동전은 안 튄다 — 새 차례의 제 칸에 이미 서 있다. 든 동전은 놓은
#      자리에서 시작해 제 칸으로 내려앉는다.
#   ⑤ 팔아서 빠지면 뒤 동전이 제 자리에서 빈 칸으로 미끄러져 온다.
#   ⑥ 든 동전은 끄는 쪽으로 기울고 놓으면 선다 · 움직임 끄기면 기울지도 미끄러지지도 않는다.
#   ⑦ 옛 스티커 말림(peel_t · _peel_now · _panel_gap)이 없다.
#   godot --headless --path . --script scripts/tools/qa_rackflow.gd
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
var g = null
var ok := 0
var bad := 0
var busy := false
const DT := 1.0 / 60.0


func _initialize() -> void:
	Save.gpath = "user://_qa_rackflow_g.cfg"
	Save.path = "user://_qa_rackflow.cfg"
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
	print("  %s %-50s %s" % ["통과" if cond else "실패", nm, note])


func _ids() -> Array:
	return g.owned.map(func(x): return String(x.id))


func _sx(k: int) -> float:
	return (g._slot_rect(k) as Rect2).get_center().x


func _carry(i: int, m: Vector2) -> void:
	g.hand_st = g.H.CARRY
	g.hand_src = 1
	g.hand_i = i
	g.hand_m = m
	g.hand_zone = -1


func _tick(n: int) -> void:
	for _k in n:
		g._rack_vis_tick(DT)


func _settled() -> float:
	var worst := 0.0
	for k in g.owned.size():
		if g.hand_st == g.H.CARRY and k == g.hand_i:
			continue
		worst = maxf(worst, absf(float(g.rack_vx[k]) - _sx(g._rack_view_slot(k))))
		worst = maxf(worst, absf(float(g.rack_vy[k])))
	return worst


func _run() -> void:
	g._new_run()
	g.tut_run = false
	g._open_leg()
	g.owned.clear()
	var its := GameData.items()
	for k in 5:
		var c: Dictionary = (its[k * 7] as Dictionary).duplicate()
		c.gs = 0
		c.bought = 0
		g.owned.append(c)
	g._panel_reset()
	g.motion_off = false
	_tick(2)
	var ids0 := _ids()

	# ⑦
	_ok("⑦ 옛 말림이 없다", g.get("peel_t") == null and not g.has_method("_peel_now")
			and not g.has_method("_panel_gap"))

	# ① 끄는 동안의 차례
	var c3: Vector2 = (g._slot_rect(3) as Rect2).get_center()
	_carry(0, c3)
	_ok("① 떨어질 칸 = 커서 밑 칸", g._rack_drop_at() == 3, str(g._rack_drop_at()))
	var vs := []
	for k in 5:
		vs.append(g._rack_view_slot(k))
	_ok("① 나머지가 비켜서 칸 3 이 빈다", vs.slice(1) == [0, 1, 2, 4], str(vs))
	_carry(0, Vector2(c3.x, 300.0))
	vs = []
	for k in range(1, 5):
		vs.append(g._rack_view_slot(k))
	_ok("① 칸 밖이면 제자리가 빈 채로 기다린다", g._rack_drop_at() == -1 and vs == [1, 2, 3, 4], str(vs))
	_carry(0, c3)
	g.hand_zone = g.Z_SELL
	_ok("① 판매 창구 위에서도 안 비켜선다", g._rack_drop_at() == -1)
	g.hand_zone = -1

	# ③ 스프링이 닿는다
	_carry(0, c3)
	_tick(60)
	_ok("③ 1초 안에 비켜선 칸에 닿는다", _settled() < 0.5, "%.3fpx" % _settled())
	var before := []
	for k in 5:
		before.append(float(g.rack_vx[k]))

	# ② ④ 놓는다
	var drop := c3 + Vector2(5.0, 9.0)
	g._hand_release(drop)
	var ids1 := _ids()
	_ok("② 놓으면 떨어질 칸에 끼운다", ids1 == [ids0[1], ids0[2], ids0[3], ids0[0], ids0[4]],
			"%s → %s" % [ids0, ids1])
	var jump := 0.0
	for k in [0, 1, 2, 4]:
		jump = maxf(jump, absf(float(g.rack_vx[k]) - _sx(k)))
	_ok("④ 비켜서 있던 동전은 놓는 순간 안 튄다", jump < 0.6, "%.3fpx" % jump)
	_ok("④ 든 동전은 놓은 자리에서 시작한다", absf(float(g.rack_vx[3]) - drop.x) < 0.01
			and float(g.rack_vy[3]) > 1.0, "x %.1f · y %+.1f" % [float(g.rack_vx[3]), float(g.rack_vy[3])])
	_tick(60)
	_ok("④ 그리고 제 칸으로 내려앉는다", absf(float(g.rack_vx[3]) - _sx(3)) < 0.5
			and absf(float(g.rack_vy[3])) < 0.5)

	# ⑤ 팔아서 빠진다
	g._panel_pull(1)
	g.owned.remove_at(1)
	var x_was: float = float(g.rack_vx[1])
	_ok("⑤ 뒤 동전이 제 자리를 들고 온다", absf(x_was - _sx(2)) < 0.6, "%.1f (옛 칸 %.1f)" % [x_was, _sx(2)])
	_tick(60)
	_ok("⑤ 그리고 빈 칸으로 미끄러진다", absf(float(g.rack_vx[1]) - _sx(1)) < 0.5)

	# ⑥ 기울기
	g.motion_off = false
	_carry(0, c3)
	g.hold_px = c3
	for k in 6:
		g.hand_m = c3 + Vector2(float(k + 1) * 8.0, 0.0)
		g._rack_vis_tick(DT)
	_ok("⑥ 오른쪽으로 끌면 기운다", g.hold_tilt > 0.05, "%.3f" % g.hold_tilt)
	g.hand_st = g.H.NONE
	g._rack_vis_tick(DT)
	_ok("⑥ 놓으면 선다", g.hold_tilt == 0.0)
	g.motion_off = true
	_carry(0, c3)
	g.hold_px = c3
	g.hand_m = c3 + Vector2(40.0, 0.0)
	g._rack_vis_tick(DT)
	_ok("⑥ 움직임 끄기 — 안 기울고 한 틀에 칸에 선다", g.hold_tilt == 0.0 and _settled() < 0.001,
			"%.3f · %.3fpx" % [g.hold_tilt, _settled()])
	g.hand_st = g.H.NONE
	g.motion_off = false
