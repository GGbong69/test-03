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
	print("  %s %-40s %s" % ["통과" if cond else "실패", nm, note])

func _run() -> void:
	g.state = g.S.SHOP
	var n: int = g.IDLE.acts.size()
	var auto := 0
	for a in g.IDLE.acts:
		if bool((a as Dictionary).get("auto", false)):
			auto += 1
	_ok("몸짓이 여럿이다", auto >= 8, "제비 %d · 응수 %d" % [auto, n - auto])
	# ① 이름이 겹치지 않는다 — 겹치면 _npc_react 가 먼저 것만 집는다
	var seen := {}
	var dup := ""
	for a in g.IDLE.acts:
		var nm: String = String((a as Dictionary).n)
		if seen.has(nm): dup = nm
		seen[nm] = true
	_ok("이름이 안 겹친다", dup == "", dup)
	# ② 「모으기」는 걷혔다 — 손만 미끄러지던 그 몸짓이다
	_ok("모으기는 없다", not seen.has("모으기"), "")

	# ③ 봉투의 양끝이 0 이다 — 아니면 몸짓마다 자세가 떠내려간다
	var worst := 0.0
	for i in n:
		g.idle_act = i
		g.idle_t = 0.0
		worst = maxf(worst, absf(g._idle_env()))
		g.idle_t = g._idle_len()
		worst = maxf(worst, absf(g._idle_env()))
	_ok("봉투 양끝이 0", worst < 0.001, "최대 %.4f" % worst)
	# ④ 짧은 응수도 봉투가 1 에 닿는다 — 안 닿으면 응수만 흐리다
	var lowest := 1.0
	var thin := ""
	for i in n:
		g.idle_act = i
		g.idle_t = g._idle_len() * 0.5
		var e: float = g._idle_env()
		if e < lowest:
			lowest = e
			thin = g._idle_name()
	_ok("한가운데는 1", lowest > 0.999, "최소 %.4f (%s)" % [lowest, thin])
	# ⑤ 몸짓이 끝나면 손도 몸도 정확히 제자리로
	var far := 0.0
	for i in n:
		g.idle_act = i
		for t in [0.0, g._idle_len()]:
			g.idle_t = t
			for k in 2:
				var h: Dictionary = g._idle_hand(k)
				far = maxf(far, absf(h.du) + absf(h.dw) + absf(h.dh)
						+ absf(h.ang) + absf(h.roll))
	_ok("양끝에서 손이 제자리", far < 0.001, "최대 %.4f" % far)

	# ⑥ 가로로 크게 가는 몸짓은 팔꿈치가 따라온다 — 안 그러면 마술손이다
	var slip := ""
	var slip_v := 0.0
	for i in n:
		g.idle_act = i
		for k in 2:
			g.idle_side = k
			for st in 21:
				g.idle_t = g._idle_len() * float(st) / 20.0
				var h: Dictionary = g._idle_hand(k)
				var du: float = absf(h.du)
				if du > 12.0 and float(h.el) < 0.75:
					if du > slip_v:
						slip_v = du
						slip = "%s du %.0f el %.2f" % [g._idle_name(), du, h.el]
	_ok("옆으로 가는 손은 팔이 따라간다", slip == "", slip)

	# ⑦ 쓸기가 이긴다
	g.idle_act = 0
	g.idle_t = 0.5
	g.sweep_live = true
	g.sweep_t = 0.30
	g._idle_tick(0.016)
	_ok("쓸기가 몸짓을 걷는다", g.idle_act < 0, "act %d" % g.idle_act)
	_ok("쓸고 나면 쉼이 남는다", g.idle_wait >= 1.2, "%.2f" % g.idle_wait)
	g.sweep_live = false
	g.sweep_t = 0.0
	# ⑧ 상인이 없는 화면에서도 걷는다
	g.idle_act = 1
	g.state = g.S.PICK
	g._idle_tick(0.016)
	_ok("상인이 없으면 안 돈다", g.idle_act < 0, "act %d" % g.idle_act)
	g.state = g.S.SHOP

	# ⑨ 제비는 auto 만 뽑는다 — 응수가 저 혼자 나오면 안 된다
	var got := {}
	for k in 400:
		g._idle_pick()
		got[g._idle_name()] = true
	var stray := ""
	for a in g.IDLE.acts:
		var d: Dictionary = a
		if not bool(d.get("auto", false)) and got.has(String(d.n)):
			stray = String(d.n)
	_ok("제비가 응수를 안 뽑는다", stray == "", stray)
	_ok("제비가 골고루 뽑는다", got.size() == auto,
			"%d/%d 종" % [got.size(), auto])

	# ⑩ 응수는 이름으로 불려 하던 몸짓을 밀어낸다
	g.idle_act = 0
	g.idle_t = 0.4
	g._npc_react("끄덕", 0)
	_ok("응수가 몸짓을 밀어낸다",
			g._idle_name() == "끄덕" and g.idle_t == 0.0 and g.idle_side == 0,
			"%s · t %.2f · 손 %d" % [g._idle_name(), g.idle_t, g.idle_side])
	g.idle_act = -1
	g._npc_react("없는몸짓")
	_ok("없는 이름은 아무 일도 안 한다", g.idle_act < 0, "act %d" % g.idle_act)
	g.sweep_live = true
	g._npc_react("끄덕")
	_ok("쓸는 중에는 응수도 안 든다", g.idle_act < 0, "act %d" % g.idle_act)
	g.sweep_live = false

	# ⑪ 무게 옮기기는 **늘** 돈다
	g.idle_act = -1
	var lo := 9.0
	var hi := -9.0
	for k in 160:
		g.npc_clock = float(k) * 0.1
		var y: float = float(g._idle_body().yaw)
		lo = minf(lo, y)
		hi = maxf(hi, y)
	_ok("몸짓이 없어도 몸이 돈다", hi - lo > 0.05,
			"돌림 폭 %.1f°" % rad_to_deg(hi - lo))
	_ok("한 주기가 20초 안", 1.0 / float(g.IDLE.sway_hz) < 20.0,
			"%.1f초" % (1.0 / float(g.IDLE.sway_hz)))
	# ⑫ 몸이 돌면 팔뿌리가 따라 돈다. 팔꿈치(축 뒤)와 손목(축 앞)은 반대다
	var te: float = g._idle_twist(g.NPC.el_l.y, 0.05)
	var tw: float = g._idle_twist(g.NPC.wr_l.y, 0.05)
	_ok("팔뿌리가 몸을 따라 돈다", te < 0.0 and tw > 0.0,
			"팔꿈치 %+.1f · 손목 %+.1f" % [te, tw])
	_ok("안 돌면 안 밀린다", absf(g._idle_twist(g.NPC.wr_l.y, 0.0)) < 0.0001, "")
