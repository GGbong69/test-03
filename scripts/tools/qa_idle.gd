extends SceneTree
# 상인 연출 — 시계와 봉투. 화면이 없어도 도는 부분만 잰다.
#   godot --headless --path . --script scripts/tools/qa_idle.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var ok := 0
var bad := 0

func _initialize() -> void:
	Save.gpath = "user://_qa_idle_g.cfg"
	Save.path = "user://_qa_idle.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	_run()
	print("통과 %d · 실패 %d" % [ok, bad])
	quit(1 if bad > 0 else 0)

func _ok(nm: String, cond: bool, note := "") -> void:
	if cond: ok += 1
	else: bad += 1
	print("  %s %-38s %s" % ["통과" if cond else "실패", nm, note])

func _run() -> void:
	g.state = g.S.SHOP
	# ① 표가 짝이 맞는가 — 이름과 길이를 자리로 읽는다
	_ok("몸짓 이름과 길이가 짝", g.IDLE.acts.size() == g.IDLE.len.size(),
			"%d개" % g.IDLE.acts.size())
	# ② 봉투의 양끝이 0 이다 — 아니면 몸짓마다 자세가 떠내려간다
	var worst := 0.0
	for i in g.IDLE.acts.size():
		g.idle_act = i
		var dur: float = float(g.IDLE.len[i])
		g.idle_t = 0.0
		worst = maxf(worst, absf(g._idle_env()))
		g.idle_t = dur
		worst = maxf(worst, absf(g._idle_env()))
	_ok("봉투 양끝이 0", worst < 0.001, "최대 %.4f" % worst)
	# ③ 봉투 한가운데는 1 이다
	var lowest := 1.0
	for i in g.IDLE.acts.size():
		g.idle_act = i
		g.idle_t = float(g.IDLE.len[i]) * 0.5
		lowest = minf(lowest, g._idle_env())
	_ok("한가운데는 1", lowest > 0.999, "최소 %.4f" % lowest)
	# ④ 몸짓이 끝나면 손이 정확히 제자리로 — 떠내려가면 안 된다
	var far := 0.0
	for i in g.IDLE.acts.size():
		g.idle_act = i
		for t in [0.0, float(g.IDLE.len[i])]:
			g.idle_t = t
			for k in 2:
				far = maxf(far, g._idle_hand(k).length())
	_ok("양끝에서 손이 제자리", far < 0.001, "최대 %.4f" % far)
	# ⑤ 쓸기가 이긴다 — 리롤이 도는 동안은 몸짓을 걷는다
	g.idle_act = 0
	g.idle_t = 0.5
	g.sweep_live = true
	g.sweep_t = 0.30
	g._idle_tick(0.016)
	_ok("쓸기가 몸짓을 걷는다", g.idle_act < 0, "act %d" % g.idle_act)
	_ok("쓸고 나면 쉼이 남는다", g.idle_wait >= 1.2, "%.2f" % g.idle_wait)
	g.sweep_live = false
	g.sweep_t = 0.0
	# ⑥ 상인이 없는 화면에서도 걷는다
	g.idle_act = 1
	g.state = g.S.PICK
	g._idle_tick(0.016)
	_ok("상인이 없으면 안 돈다", g.idle_act < 0, "act %d" % g.idle_act)
	g.state = g.S.SHOP
	# ⑦ 쉼이 끝나면 몸짓이 하나 걸리고, 길이를 넘기면 다시 쉼으로
	g.idle_act = -1
	g.idle_wait = 0.01
	g._idle_tick(0.02)
	_ok("쉼이 끝나면 몸짓이 걸린다", g.idle_act >= 0, "act %d" % g.idle_act)
	var pick: int = g.idle_act
	g.idle_t = float(g.IDLE.len[pick])
	g._idle_tick(0.02)
	_ok("길이를 넘기면 쉼으로", g.idle_act < 0 and g.idle_wait >= float(g.IDLE.gap.x),
			"쉼 %.2f" % g.idle_wait)
	# ⑧ 무게 옮기기는 **늘** 돈다 — 몸짓이 없어도 몸이 움직여야 한다
	g.idle_act = -1
	g.npc_clock = 0.0
	var lo := 9.0
	var hi := -9.0
	for k in 120:
		g.npc_clock = float(k) * 0.1
		var y: float = float(g._idle_body().yaw)
		lo = minf(lo, y)
		hi = maxf(hi, y)
	_ok("몸짓이 없어도 몸이 돈다", hi - lo > 0.05,
			"돌림 폭 %.1f°" % rad_to_deg(hi - lo))
	# ⑨ 한 주기를 다 돈다 — 주기가 너무 길면 화면에서는 정지다
	_ok("한 주기가 20초 안", 1.0 / float(g.IDLE.sway_hz) < 20.0,
			"%.1f초" % (1.0 / float(g.IDLE.sway_hz)))
