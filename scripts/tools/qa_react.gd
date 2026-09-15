extends SceneTree
# 손님이 뭘 하면 상인이 응수하는가. 진짜 길(_hand_take·_sell·_pay_take·_deny)을
# 밟아 본다 — 이름만 맞춰 놓고 아무도 안 부르는 응수가 제일 흔한 실패다.
#   godot --headless --path . --script scripts/tools/qa_react.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var ok := 0
var bad := 0

func _initialize() -> void:
	Save.gpath = "user://_qa_react_g.cfg"
	Save.path = "user://_qa_react.cfg"
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

func _clear() -> void:
	g.idle_act = -1
	g.idle_t = 0.0
	g.idle_side = 1

func _run() -> void:
	g.state = g.S.TITLE
	g._new_run()
	g.gold = 60
	g.leg_no = 2
	g._open_shop()
	g.drop_fast = true
	for k in 200:
		g._drop_step(1.0 / 60.0)
	print("매물 %d · 금화 %d" % [g.stock.size(), g.gold])

	# ① 응수 이름이 표에 다 있는가 — 없는 이름을 부르면 조용히 아무 일도 없다
	var want := ["눈길", "끄덕", "손짓", "저음"]
	var have := {}
	for a in g.IDLE.acts:
		have[String((a as Dictionary).n)] = true
	var miss := ""
	for w in want:
		if not have.has(w):
			miss = w
	_ok("응수 넷이 표에 있다", miss == "", miss)

	# ② 가까운 손을 고른다
	_ok("왼쪽 일은 왼손", g._npc_side(80.0) == 0, "%d" % g._npc_side(80.0))
	_ok("오른쪽 일은 오른손", g._npc_side(560.0) == 1, "%d" % g._npc_side(560.0))

	# ③ 집으면 그쪽을 본다 — 진짜 _hand_take 를 밟는다
	_clear()
	g.hand_src = 0
	g.hand_i = 0
	g.hand_p0 = Vector2(120.0, 200.0)
	g.hand_m = g.hand_p0
	g._hand_take()
	_ok("집으면 눈길", g._idle_name() == "눈길" and g.idle_side == 0,
			"%s · 손 %d" % [g._idle_name(), g.idle_side])
	_clear()
	g.hand_p0 = Vector2(520.0, 200.0)
	g.hand_i = 0
	g._hand_take()
	_ok("오른쪽을 집으면 오른손", g.idle_side == 1, "손 %d" % g.idle_side)
	g._hand_abort()

	# ④ 물리면 젓는다
	_clear()
	g._deny()
	_ok("거절이면 저음", g._idle_name() == "저음", g._idle_name())

	# ⑤ 사면 끄덕인다 — 값이 되는 매물을 골라 진짜로 산다
	_clear()
	var buy := -1
	for i in g.stock.size():
		if int(g.stock[i].cost) <= g.gold and g._buy_block(i) == "":
			buy = i
			break
	if buy < 0:
		_ok("살 것이 있다", false, "매물 %d" % g.stock.size())
	else:
		var before: int = g.gold
		g._pay_take(buy)
		_ok("사면 끄덕", g._idle_name() == "끄덕",
				"%s · 금화 %d→%d" % [g._idle_name(), before, g.gold])

	# ⑥ 팔면 손짓한다 — 판매 창구는 화면 왼쪽이라 왼손이다
	_clear()
	if g.owned.is_empty():
		#  산 것이 동전이 아니었다(다트·사탕은 owned 가 아니다).
		#  파는 길만 재는 것이니 동전 하나를 손으로 올린다.
		for c in GameData.items():
			g.owned.append((c as Dictionary).duplicate())
			break
	if g.owned.is_empty():
		_ok("팔 것이 있다", false, "아이템 표가 비었다")
	else:
		g._sell(0)
		_ok("팔면 손짓", g._idle_name() == "손짓" and g.idle_side == 0,
				"%s · 손 %d" % [g._idle_name(), g.idle_side])

	# ⑦ 응수도 봉투를 탄다 — 끝나면 자세가 제자리로 돌아온다
	var far := 0.0
	for nm in want:
		_clear()
		g._npc_react(nm)
		var dur: float = g._idle_len()
		for t in [0.0, dur]:
			g.idle_t = t
			for k in 2:
				var h: Dictionary = g._idle_hand(k)
				far = maxf(far, absf(h.du) + absf(h.dw) + absf(h.dh))
			var bd: Dictionary = g._idle_body()
			far = maxf(far, absf(bd.rise) + absf(bd.lean))
	_ok("응수 끝에 자세가 제자리", far < 0.001, "최대 %.4f" % far)

	# ⑧ 상인이 없는 화면에서는 응수도 없다 — 판 중에 몸짓이 돌면 안 된다
	_clear()
	g.state = g.S.PICK
	g._deny()
	_ok("판 중에는 응수가 없다", g.idle_act < 0, "act %d" % g.idle_act)
	g.state = g.S.SHOP
