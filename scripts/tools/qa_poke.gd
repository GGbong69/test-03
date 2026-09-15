extends SceneTree
# 상인을 누르면 응수하는가. 손·팔·몸 셋과, 무엇도 안 뺏는지를 잰다.
#   godot --headless --path . --script scripts/tools/qa_poke.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var ok := 0
var bad := 0

func _initialize() -> void:
	Save.gpath = "user://_qa_poke_g.cfg"
	Save.path = "user://_qa_poke.cfg"
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

func _clear() -> void:
	g.idle_act = -1
	g.idle_t = 0.0

func _run() -> void:
	g.state = g.S.TITLE
	g._new_run()
	g.state = g.S.SHOP
	g.gold = 60
	g.leg_no = 2
	g._open_shop()
	g.drop_fast = true
	for k in 240:
		g._drop_step(1.0 / 60.0)
	g._drop_settle()
	#  헤드리스라 _npc_arms(그리기)가 안 돌아 손 자리가 비어 있다.
	#  쉬는 자세의 값을 그대로 세워 둔다.
	for i in 2:
		var wr: Vector2 = g.NPC.wr_l if i == 0 else g.NPC.wr_r
		var eb: Vector2 = g.NPC.el_l if i == 0 else g.NPC.el_r
		g.npc_palm[i] = Vector3(float(g.NPC.cx) + wr.x, wr.y,
				float(g.HAND3.h_wr) + float(g.HAND3.palm_t))
		g.npc_elbow[i] = Vector2(float(g.NPC.cx) + eb.x, eb.y)

	# ① 세 자리가 다 맞는다
	var body := Vector2(float(g.NPC.cx), 90.0)
	_ok("몸통을 맞힌다", g._npc_hit(body) == 2, "%d" % g._npc_hit(body))
	for i in 2:
		var pm: Vector3 = g.npc_palm[i]
		var hp: Vector2 = g._p2s(pm.x, pm.y, pm.z)
		_ok("%s손을 맞힌다" % ("왼" if i == 0 else "오른"),
				g._npc_hit(hp) == i, "%d (%.0f,%.0f)" % [g._npc_hit(hp), hp.x, hp.y])
		var eb: Vector2 = g.npc_elbow[i]
		var ep: Vector2 = g._p2s(eb.x, eb.y, float(g.HAND3.h_el))
		_ok("%s팔 가운데를 맞힌다" % ("왼" if i == 0 else "오른"),
				g._npc_hit((hp + ep) * 0.5) == i,
				"%d" % g._npc_hit((hp + ep) * 0.5))
	# ② 엉뚱한 자리는 안 맞는다
	_ok("펠트 한가운데는 아니다",
			g._npc_hit(Vector2(320.0, 220.0)) < 0,
			"%d" % g._npc_hit(Vector2(320.0, 220.0)))
	_ok("동전 슬롯 자리는 아니다", g._npc_hit(Vector2(320.0, 30.0)) < 0,
			"%d" % g._npc_hit(Vector2(320.0, 30.0)))
	_ok("몸통 바깥 벽은 아니다", g._npc_hit(Vector2(60.0, 90.0)) < 0,
			"%d" % g._npc_hit(Vector2(60.0, 90.0)))
	# ③ 상인이 없는 화면에서는 아무 데도 안 맞는다
	g.state = g.S.PICK
	_ok("판 중에는 안 맞는다", g._npc_hit(body) < 0, "%d" % g._npc_hit(body))
	g.state = g.S.SHOP

	# ④ 손을 누르면 그 손을 뺀다
	for i in 2:
		_clear()
		var pm2: Vector3 = g.npc_palm[i]
		g._npc_press(g._p2s(pm2.x, pm2.y, pm2.z))
		_ok("%s손을 누르면 뺀다" % ("왼" if i == 0 else "오른"),
				g._idle_name() == "빼기" and g.idle_side == i,
				"%s · 손 %d" % [g._idle_name(), g.idle_side])

	# ⑤ 몸을 누르면 셋이 돌아가며 난다 — 같은 답이 세 번 나오면 소리다
	g.npc_poke = 0
	var seen := []
	for k in g.POKE.body.size():
		_clear()
		g._npc_press(body)
		seen.append(g._idle_name())
	_ok("몸을 누르면 돌아가며 난다",
			seen.size() == g.POKE.body.size()
			and seen.duplicate().size() == seen.size()
			and not seen.has(""),
			" → ".join(PackedStringArray(seen)))
	var uniq := {}
	for n in seen:
		uniq[n] = true
	_ok("셋이 서로 다르다", uniq.size() == g.POKE.body.size(),
			"%d종" % uniq.size())
	_clear()
	g._npc_press(body)
	_ok("한 바퀴 돌면 처음으로", g._idle_name() == String(g.POKE.body[0]),
			g._idle_name())

	# ⑥ 누름을 **안 삼킨다** — 겹치는 것의 클릭을 뺏으면 안 된다
	_clear()
	var swallowed: bool = g._hand_press(body)
	_ok("상인을 눌러도 안 삼킨다", not swallowed, "%s" % swallowed)
	_ok("그래도 응수는 났다", g.idle_act >= 0, g._idle_name())
	_ok("손을 쥐지는 않는다", g.hand_st == g.H.NONE, "손 %d" % g.hand_st)

	# ⑦ 매물이 먼저다 — 상인 응수가 물건 집기를 가로채면 안 된다
	_clear()
	var at: Vector2 = (g._obj_box(0) as Rect2).get_center()
	var took: bool = g._hand_press(at)
	_ok("매물은 그대로 잡힌다", took and g.hand_st == g.H.ARMED,
			"잡음 %s · 손 %d" % [took, g.hand_st])
	_ok("매물을 잡으면 눈길이지 빼기가 아니다", g._idle_name() == "눈길",
			g._idle_name())
	g._hand_abort()

	# ⑧ 응수 셋도 양끝에서 자세가 제자리로 돌아온다
	var far := 0.0
	for nm in ["움찔", "손사래", "빼기"]:
		_clear()
		g._npc_react(nm, 1)
		for t in [0.0, g._idle_len()]:
			g.idle_t = t
			for i in 2:
				var hh: Dictionary = g._idle_hand(i)
				far = maxf(far, absf(hh.du) + absf(hh.dw) + absf(hh.dh)
						+ absf(hh.ang))
			var bd: Dictionary = g._idle_body()
			far = maxf(far, absf(bd.rise) + absf(bd.lean))
	_ok("응수 끝에 자세가 제자리", far < 0.001, "최대 %.4f" % far)
	# ⑨ 셋 다 때리는 쪽이다 — 누른 응수가 느리면 누름이 안 느껴진다
	var slow := ""
	for nm2 in ["움찔", "손사래", "빼기"]:
		_clear()
		g._npc_react(nm2, 1)
		g.idle_t = 4.0 / 60.0
		if g._idle_env() < 0.98:
			slow = "%s %.2f" % [nm2, g._idle_env()]
	_ok("셋 다 네 프레임에 다 선다", slow == "", slow)
