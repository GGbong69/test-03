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
	#  낙하가 안 끝나면 _hand_press 가 _drop_busy 로 통째로 거절한다 —
	#  누름 검사가 아니라 낙하 검사가 되어 버린다.
	g._drop_settle()
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

	# ③ **누르는 순간** 그쪽을 본다 — 끌기가 시작되기 전이다
	_clear()
	_ok("빈 자리를 누르면 아무 일도 없다",
			not g._hand_press(Vector2(8.0, 350.0)) and g.idle_act < 0,
			"act %d" % g.idle_act)
	var it0: Dictionary = g.drop[0]
	var at: Vector2 = (g._obj_box(0) as Rect2).get_center()
	_clear()
	var got: bool = g._hand_press(at)
	_ok("매물을 누르면 눈길",
			got and g._idle_name() == "눈길"
			and g.idle_side == g._npc_side(at.x),
			"%s · 손 %d (자리 x %.0f)" % [g._idle_name(), g.idle_side, at.x])
	_ok("누른 것만으로는 아직 안 쥔다", g.hand_st == g.H.ARMED,
			"손 %d" % g.hand_st)
	#  끌기가 시작될 때 같은 응수가 **또** 걸리면 안 된다 — 봉투가 튄다
	g.idle_t = 0.42
	g._hand_take()
	_ok("끌기 시작에 응수가 겹치지 않는다", absf(g.idle_t - 0.42) < 0.0001,
			"t %.2f" % g.idle_t)
	g._hand_abort()

	# ④ 연타해도 봉투가 안 튄다 — 같은 응수는 시계를 0 으로 안 되돌린다
	_clear()
	g._npc_react("눈길", 1)
	g.idle_t = 0.55
	var e0: float = g._idle_env()
	g._npc_react("눈길", 1)
	_ok("같은 응수를 다시 불러도 안 튄다",
			g.idle_t <= float(g.IDLE["in"]) + 0.0001 and g._idle_env() >= e0 - 0.001,
			"t %.2f · 봉투 %.2f→%.2f" % [g.idle_t, e0, g._idle_env()])
	g._npc_react("끄덕")
	_ok("다른 응수는 처음부터", g._idle_name() == "끄덕" and g.idle_t == 0.0,
			"%s · t %.2f" % [g._idle_name(), g.idle_t])

	# ⑤ 눌렀다 그대로 떼면(탭) 그 물건을 짚어 보인다
	_clear()
	g._shop_tap(0)
	_ok("탭하면 짚는다",
			g._idle_name() == "짚기"
			and g.idle_side == g._npc_side(float(it0.u)),
			"%s · 손 %d" % [g._idle_name(), g.idle_side])
	#  짚기는 눈길보다 한 발 더 나가야 한다 — 같으면 둘일 이유가 없다
	var pk := 0.0
	var lk := 0.0
	for nm2 in ["짚기", "눈길"]:
		_clear()
		g._npc_react(nm2, 1)
		g.idle_t = g._idle_len() * 0.5
		var hh: Dictionary = g._idle_hand(1)
		if nm2 == "짚기":
			pk = float(hh.dw)
		else:
			lk = float(hh.dw)
	_ok("짚기가 눈길보다 멀리 나간다", pk > lk * 2.0,
			"짚기 %.0f · 눈길 %.0f" % [pk, lk])

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
