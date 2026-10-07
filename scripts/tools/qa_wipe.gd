extends SceneTree
#  장면 전환 덮개(2026-10-04 · game.gd 의 WIPE · _wipe_hold · _clear_go · _shop_go).
#  못 박는 것:
#    ① 정산 → 상점 · 상점 → 다음 판은 덮개가 다 덮은 틀(WIPE.on)에 화면이 바뀌고, 옛 판 갈이
#       (swap_live)는 안 돈다.
#    ② 다 덮인 동안 새 화면의 시계(매물 낙하 drop_t · 판 깔기 leg_t)가 멈췄다가 걷히면서 돈다.
#    ③ 덮개가 도는 동안 누름은 아무것도 안 한다.
#    ④ 움직임 끔이면 덮개 없이 누른 틀에 바뀐다.
#    ⑤ 설정 「전환 지지직」을 끄면 줄무늬 대신 어두운 막이 같은 박자로 덮고 지지직 소리가 없다.
#  창이 있어야 돈다(덮개는 렌더러가 있어야 선다):
#    godot --path . --script scripts/tools/qa_wipe.gd
const Save = preload("res://scripts/save.gd")
const DT := 1.0 / 120.0
var g = null
var busy := false
var ok := 0
var bad := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_wipe_g.cfg"
	Save.path = "user://_qa_wipe.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	seed(20261004)


func _process(_d: float) -> bool:
	if busy:
		return false
	busy = true
	_run()
	return false


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-44s %s" % ["통과" if cond else "실패", nm, note])


func _step(sec: float) -> void:
	var n: int = int(ceil(sec / DT))
	for k in n:
		g.idle_act = -1
		g.idle_wait = 99.0
		g._process(DT)


#  정산 화면까지 — 판 하나를 이겨 놓는다.
func _to_clear() -> void:
	g._swap_skip()
	g._begin_leg()
	g._swap_skip()
	_step(0.3)
	g.total = g.target
	g.darts_left = 0
	g.remaining.clear()
	g._finish_leg()
	for k in 900:
		if g.state == g.S.CLEAR:
			break
		g._process(DT)
		g._swap_skip()
	g.clear_t = 99.0


#  덮개를 끝까지 민다 — 바뀐 틀 · 덮인 동안의 시계 · 걷힌 뒤의 시계를 잰다.
func _run_wipe(want: int, clock: String) -> Dictionary:
	var r := {"at": -1.0, "swap": false, "c_cover": -1.0, "c_end": 0.0, "c0": 0.0}
	var t := 0.0
	var s0: int = g.state
	while g.wipe_t >= 0.0 and t < 3.0:
		g._process(DT)
		t += DT
		r.swap = bool(r.swap) or g.swap_live
		if float(r.at) < 0.0 and g.state != s0:
			r.at = t
			r.c0 = float(g.get(clock))
		if g.wipe_t >= 0.0 and g.wipe_went and g.wipe_t < float(g.WIPE.off):
			r.c_cover = maxf(float(r.c_cover), float(g.get(clock)))
	_step(0.3)
	r.c_end = float(g.get(clock))
	r["state"] = g.state
	r["want"] = want
	return r


func _run() -> void:
	for i in 10:
		await process_frame
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 덮개가 선다")
		quit(0)
		return
	for id in ["u_leg", "u_skip", "u_boss", "u_score", "u_clear", "u_shop", "u_rack",
			"u_cons", "u_sell", "u_reroll", "u_give", "u_boot", "u_gift"]:
		Save.teach(id)
	g.set_process(false)
	g.wipe_force = true
	g._new_run(true)
	g._tutor_close()
	g.tutor_q.clear()
	_step(1.0)
	var W: Dictionary = g.WIPE

	# ① ② 정산 → 상점
	_to_clear()
	_ok("정산 화면이다", g.state == g.S.CLEAR, str(g.state))
	g._click(Vector2(-1.0, -1.0))
	_ok("정산 → 상점 — 누르면 덮개가 선다 · 화면은 그대로", g.wipe_t >= 0.0 and g.state == g.S.CLEAR, "")
	var a := _run_wipe(g.S.SHOP, "drop_t")
	_ok("정산 → 상점 — 다 덮은 틀에 바뀐다", int(a.state) == g.S.SHOP
			and absf(float(a.at) - float(W.on)) <= DT * 1.5, "바뀐 틀 %.3f (덮음 %.2f)" % [float(a.at),
			float(W.on)])
	_ok("정산 → 상점 — 옛 판 갈이는 안 돈다", not bool(a.swap), "")
	_ok("정산 → 상점 — 덮인 동안 매물 낙하가 멈췄다 걷히며 돈다", float(a.c_cover) <= float(a.c0) + 0.0001
			and float(a.c_end) > float(a.c0) + 0.1, "덮인 동안 %.3f · 끝 %.3f" % [float(a.c_cover),
			float(a.c_end)])
	_step(2.0)
	g._tutor_close()
	g.tutor_q.clear()

	# ③ 덮개 동안 누름
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	g._click(g._next_rect().get_center())
	_ok("상점 → 다음 판 — 누르면 덮개가 선다", g.wipe_t >= 0.0 and g.state == g.S.SHOP, "")
	var rr0: int = g.rerolls_used
	g._unhandled_input(ev)
	_ok("덮개 동안 누름은 삼킨다", g.rerolls_used == rr0 and g.state == g.S.SHOP, "")
	var b := _run_wipe(g.S.LEG, "leg_t")
	_ok("상점 → 다음 판 — 다 덮은 틀에 바뀐다", int(b.state) == g.S.LEG
			and absf(float(b.at) - float(W.on)) <= DT * 1.5, "바뀐 틀 %.3f" % float(b.at))
	_ok("상점 → 다음 판 — 덮인 동안 판 깔기가 멈췄다 걷히며 돈다", float(b.c_cover) <= float(b.c0) + 0.0001
			and float(b.c_end) > float(b.c0) + 0.1, "덮인 동안 %.3f · 끝 %.3f" % [float(b.c_cover),
			float(b.c_end)])

	# ⑤ 설정 「전환 지지직」 끔(2026-10-08) — 줄무늬 대신 어두운 막 · 지지직 소리 없음 · 박자 그대로
	_step(2.0)
	g._tutor_close()
	g.tutor_q.clear()
	g.wipe_snow = false
	var mat := g.wipe_rect.material as ShaderMaterial
	_to_clear()
	var st_n := 0
	for sp in g.sfx_pool:
		var asp := sp as AudioStreamPlayer
		if asp.stream != null and asp.stream.resource_path.get_file().get_basename() == "tv_static":
			asp.stream = null
	g._click(Vector2(-1.0, -1.0))
	for sp in g.sfx_pool:
		var asp2 := sp as AudioStreamPlayer
		if asp2.stream != null and asp2.stream.resource_path.get_file().get_basename() == "tv_static":
			st_n += 1
	_step(DT)
	_ok("지지직 끔 — 덮개 판이 어두운 막이다", float(mat.get_shader_parameter("plain")) == 1.0
			and g.wipe_t >= 0.0, "plain %s" % [mat.get_shader_parameter("plain")])
	_ok("지지직 끔 — 지지직 소리가 안 난다", st_n == 0, "%d" % st_n)
	var c := _run_wipe(g.S.SHOP, "drop_t")
	_ok("지지직 끔 — 같은 박자에 바뀐다", int(c.state) == g.S.SHOP
			and absf(float(c.at) - float(W.on)) <= DT * 1.5, "바뀐 틀 %.3f" % float(c.at))
	g.wipe_snow = true
	_step(2.0)
	g._tutor_close()
	g.tutor_q.clear()

	# ④ 움직임 끔
	g.motion_off = true
	_to_clear()
	g._click(Vector2(-1.0, -1.0))
	_ok("움직임 끔 — 정산 → 상점이 누른 틀에 바뀐다", g.wipe_t < 0.0 and g.state == g.S.SHOP, str(g.state))
	g.motion_off = false
	g._swap_skip()
	print("통과 %d · 실패 %d" % [ok, bad])
	quit(1 if bad > 0 else 0)
