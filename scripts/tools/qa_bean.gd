extends SceneTree
# 잭과 콩나무 · 슬롯 둥실거림(2026-10-08 · game.gd BEAN · FLOAT) — 못 박는 것:
#   ① 콩나무가 없으면 다트는 제 크기다. 있으면 자란 걸음만큼 커지고 열 걸음(2.2 배)에서 멈춘다.
#      봉인되면 안 큰다.
#   ② 맞히면 정산에 「bean」 걸음이 서고, 그 걸음에서 방금 꽂힌 자루가 다음 크기로 쑥 큰다 —
#      꽂힌 순간은 던질 때의 크기다. 점수 · 배수 · 총점은 그 걸음에서 안 바뀐다.
#   ③ 다음 발은 큰 크기로 꽂히고, 양옆 칸을 먹는 걸음(pierce)이 먹은 칸 수를 싣고 판에 빛을 세운다.
#   ④ 3D 자루는 촉 끝이 착탄점 그대로인 채 통째로 커진다.
#   ⑤ 쑥 크기는 넘쳤다가 제 크기에 앉는다 · 움직임 끄기면 곧장 선다.
#   ⑥ 둥실거림은 칸마다 박자가 다르고 FLOAT.amp 안이다 · 움직임 끄기면 0 · 칸(판정)은 안 움직인다.
#   godot --headless --path . --script scripts/tools/qa_bean.gd
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
var g = null
var ok := 0
var bad := 0
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_qa_bean_g.cfg"
	Save.path = "user://_qa_bean.cfg"
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


func _bean_item() -> Dictionary:
	for it in GameData.items():
		if String(it.get("side", "")) == "bigdart":
			var c: Dictionary = (it as Dictionary).duplicate()
			c.gs = 0
			c.bought = 0
			return c
	return {}


func _throw(pt: Vector2) -> Array:
	g.state = g.S.RESOLVE
	g.aim = pt
	g.queue = []
	g.burst_hits = []
	g._land()
	var ks := []
	for st in g.queue:
		ks.append(String((st as Dictionary).get("k", "")))
	return ks


func _run() -> void:
	g._new_run()
	g.tut_run = false
	g._open_leg()
	g._begin_leg()
	g.motion_off = false
	g.sealed = -1
	g.dead_idx = -1
	g.dead_col = -1
	g.dead_ring = 0
	g.mark_sec = -1
	g.paint_sec = -1
	g.track_lv = {}
	g.cur_dart = GameData.darts()[0].duplicate()
	g.total = 0
	g.target = 999999
	g.darts.clear()
	var bean := _bean_item()
	_ok("표에 콩나무(side bigdart)가 있다", not bean.is_empty())

	# ①
	g.owned = []
	g._panel_reset()
	_ok("① 콩나무가 없으면 제 크기", g._bean_now() == 1.0)
	g.owned = [bean]
	g._panel_reset()
	_ok("① 갓 든 콩나무는 아직 제 크기", g._bean_now() == 1.0)
	_ok("① 열 걸음에서 2.2 배로 멈춘다", is_equal_approx(g._bean_sc(10), 2.2)
			and is_equal_approx(g._bean_sc(30), 2.2) and is_equal_approx(g._bean_sc(1), 1.12))
	g.owned[0].gs = 5
	g.sealed = 0
	_ok("① 봉인되면 안 큰다", g._bean_now() == 1.0)
	g.sealed = -1
	g.owned[0].gs = 0

	# ② 첫 발
	var trp: float = g.R * (g.rt_trp_in + g.rt_trp_out) * 0.5
	var pt: Vector2 = g.BC + Vector2(0.0, -trp)
	var ks := _throw(pt)
	var d0: Dictionary = g.darts[g.darts.size() - 1]
	_ok("② 첫 발은 던질 때의 크기로 꽂힌다", float(d0.get("sc", 0.0)) == 1.0)
	_ok("② 정산에 bean 걸음이 선다 · 양옆 칸은 아직 없다", ks.has("bean") and not ks.has("pierce"),
			str(ks))
	var t0: int = g.total
	var c0: int = g.cur_chip
	var m0: int = g.cur_mult
	var grew := false
	while not (g.queue as Array).is_empty():
		var nk := String((g.queue as Array)[0].get("k", ""))
		if nk == "bean":
			c0 = g.cur_chip
			m0 = g.cur_mult
			t0 = g.total
			g._next_step()
			grew = is_equal_approx(float(d0.get("sc", 0.0)), 1.12) and not g.bean_grow.is_empty()
			_ok("② bean 걸음은 점수 · 배수 · 총점을 안 바꾼다",
					g.cur_chip == c0 and g.cur_mult == m0 and g.total == t0)
		else:
			g._next_step()
	_ok("② 그 걸음에서 꽂힌 자루가 다음 크기(1.12)로 큰다", grew, "%.3f" % float(d0.get("sc", 0.0)))

	# ⑤ 넘쳤다 앉는다
	g.bean_grow = {"dk": g.darts.size() - 1, "from": 1.0, "to": 1.12, "t": 0.0}
	var peak := 0.0
	for k in 40:
		g._bean_tick(1.0 / 60.0)
		peak = maxf(peak, g._dart_sc(g.darts[g.darts.size() - 1]))
	_ok("⑤ 쑥 크기는 넘쳤다가", peak > 1.12 + 0.005, "봉우리 %.3f" % peak)
	_ok("⑤ 제 크기에 앉는다", g.bean_grow.is_empty()
			and is_equal_approx(g._dart_sc(g.darts[g.darts.size() - 1]), 1.12))

	# ③ 둘째 발
	ks = _throw(pt)
	var d1: Dictionary = g.darts[g.darts.size() - 1]
	_ok("③ 다음 발은 큰 크기로 꽂힌다", is_equal_approx(float(d1.get("sc", 0.0)), 1.12))
	var pst: Dictionary = {}
	for st in g.queue:
		if String((st as Dictionary).get("k", "")) == "pierce":
			pst = st
	_ok("③ 양옆 칸 걸음이 먹은 칸 수(1)를 싣는다", int(pst.get("reach", -1)) == 1, str(pst))
	while not (g.queue as Array).is_empty():
		var nk2 := String((g.queue as Array)[0].get("k", ""))
		g._next_step()
		if nk2 == "pierce":
			_ok("③ 그 걸음이 판에 먹은 칸 빛을 세운다", int(g.bean_glow.get("reach", 0)) == 1)

	# ④ 3D 자세
	var e := {"p": pt, "rot": 0.0, "sc": 2.0}
	var tf: Transform3D = g._bd3_pose(e)
	var yv: Vector3 = tf.basis.y.normalized()
	var tip: Vector3 = tf.origin - yv * float(g.BD3.len) * 0.5 * 2.0
	var land := Vector3(pt.x - g.BC.x, -(pt.y - g.BC.y), 0.0)
	_ok("④ 3D 자루가 통째로 커진다", absf(tf.basis.x.length() - 2.0) < 0.001
			and absf(tf.basis.y.length() - 2.0) < 0.001)
	_ok("④ 촉 끝은 착탄점 그대로다", tip.distance_to(land) < 0.01, "%.4f" % tip.distance_to(land))

	# ⑤ 움직임 끄기
	g.motion_off = true
	g.owned[0].gs = 3
	ks = _throw(pt)
	while not (g.queue as Array).is_empty():
		g._next_step()
	_ok("⑤ 움직임 끄기 — 곧장 제 크기에 선다", g.bean_grow.is_empty()
			and is_equal_approx(float(g.darts[g.darts.size() - 1].get("sc", 0.0)), g._bean_sc(4)))

	# ⑥ 둥실거림
	g.motion_off = false
	var lo := 0.0
	var hi := 0.0
	var diff := false
	var r0: Rect2 = g._slot_rect(0)
	for k in 240:
		g.float_t = float(k) / 60.0
		var a: float = g._float_dy(0)
		var b: float = g._float_dy(1)
		lo = minf(lo, a)
		hi = maxf(hi, a)
		if absf(a - b) > 0.3:
			diff = true
	var amp: float = float(g.FLOAT.amp)
	_ok("⑥ 위아래로 뜨되 amp 안이다", hi > amp * 0.8 and lo < -amp * 0.8 and hi <= amp + 1e-6
			and lo >= -amp - 1e-6, "%.2f ~ %.2f" % [lo, hi])
	_ok("⑥ 칸마다 박자가 다르다", diff)
	_ok("⑥ 칸(판정)은 안 움직인다", (g._slot_rect(0) as Rect2) == r0)
	g.motion_off = true
	_ok("⑥ 움직임 끄기면 0", g._float_dy(0) == 0.0 and g._float_rot(0) == 0.0)
	g.motion_off = false
