extends SceneTree
# 물건을 건네면 상인이 살펴보고 돌려주는가. 세 박자를 끝까지 돌려 본다.
#   godot --headless --path . --script scripts/tools/qa_give.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var ok := 0
var bad := 0

func _initialize() -> void:
	Save.gpath = "user://_qa_give_g.cfg"
	Save.path = "user://_qa_give.cfg"
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

func _shop() -> void:
	g.state = g.S.SHOP
	g.gold = 60
	g.leg_no = 2
	g._open_shop()
	g.drop_fast = true
	for k in 240:
		g._drop_step(1.0 / 60.0)

func _step(n: int) -> void:
	for k in n:
		g._give_tick(1.0 / 60.0)

func _run() -> void:
	g.state = g.S.TITLE
	g._new_run()
	_shop()
	var tot: float = float(g.GIVE.take) + float(g.GIVE.look) + float(g.GIVE.back)

	# ① 몸짓 길이와 세 박자의 합이 같아야 한다 — 어긋나면 손이 먼저 내려온다
	var li: int = g._idle_index("살핌")
	_ok("살핌이 표에 있다", li >= 0, "%d번" % li)
	_ok("몸짓 길이가 세 박자와 같다",
			absf(float((g.IDLE.acts[li] as Dictionary).t) - tot) < 0.001,
			"몸짓 %.2f · 박자 %.2f" % [float((g.IDLE.acts[li] as Dictionary).t), tot])

	# ② 과녁이 창구와 안 겹친다 — 위쪽 띠와 좌우 빗변이 따로 살아야 한다
	var top := Vector2(320.0, g.TBL.fy)
	_ok("카운터 위는 건네는 자리", g._give_at(top), "")
	_ok("펠트 한가운데는 아니다",
			not g._give_at(Vector2(320.0, g.TBL.fy + 60.0)), "")
	_ok("건네는 띠에 창구가 없다", g._chute_at(top, 0.0) < 0,
			"창구 %d" % g._chute_at(top, 0.0))

	#  헤드리스라 _npc_arms(그리기)가 안 돌아서 손바닥이 비어 있다.
	#  살핌 때 손이 서는 자리를 그대로 세워 둔다.
	g.npc_palm[1] = Vector3(430.0, 36.0, 15.0)
	g.npc_palm[0] = Vector3(214.0, 36.0, 15.0)

	# ③ 건네면 상인이 든다
	_ok("매물이 있다", g.drop.size() > 0, "%d개" % g.drop.size())
	var it: Dictionary = g.drop[0]
	var from := Vector2(it.u, it.w)
	g._give_begin(0, Vector2(it.u, g.TBL.fy))
	_ok("건네면 상인이 든다", g._give_live() and bool(it.held), "")
	_ok("살핌이 걸렸다", g._idle_name() == "살핌", g._idle_name())

	# ④ 받는 동안 물건이 뜬다 — 곧게 가면 빨려 들어간 것으로 읽힌다
	_step(int(float(g.GIVE.take) * 30.0))
	_ok("받는 동안 물건이 떠 있다", float(it.h) > 4.0, "h %.1f" % float(it.h))

	# ⑤ 살피는 동안 손 위에 머물고 돈다
	var psi0: float = float(it.psi)
	_step(int(float(g.GIVE.look) * 40.0))
	_ok("살피는 동안 돈다", absf(float(it.psi) - psi0) > 0.5,
			"psi %+.2f" % (float(it.psi) - psi0))
	var pm: Vector3 = g.npc_palm[g.give_side]
	_ok("손바닥 위에 얹혔다",
			absf(float(it.h) - (pm.z + float(g.GIVE.hold))) < 0.01,
			"h %.1f = 손바닥 %.1f + %.1f" % [float(it.h), pm.z,
			float(g.GIVE.hold)])
	_ok("손바닥 한가운데다", absf(float(it.u) - pm.x) < 0.01
			and absf(float(it.w) - pm.y) < 0.01,
			"u %.1f/%.1f · w %.1f/%.1f" % [float(it.u), pm.x, float(it.w), pm.y])
	#  카운터 선을 안 넘어야 한다 — 넘으면 벽 사각이 물건을 지운다
	var sy: float = g.TBL.fy + float(it.w) * g.TBL.flat - float(it.h) * g.TBL.tall
	_ok("든 물건이 카운터 밑에 있다", sy > g.TBL.fy,
			"화면 y %.1f (카운터 %.0f)" % [sy, g.TBL.fy])

	# ⑥ 끝나면 물리로 돌아간다
	_step(400)
	_ok("끝나면 손을 뗀다", not g._give_live() and not bool(it.held), "")
	_ok("판 위에 내려놓았다", absf(float(it.h)) < 0.01, "h %.2f" % float(it.h))
	_ok("쟁반 안에 있다",
			float(it.w) >= g.DROP.w_lo - 0.01 and float(it.w) <= g.DROP.w_hi + 0.01,
			"w %.1f" % float(it.w))

	# ⑦ 내려놓기는 있던 자리로, 던지기는 속도를 실어 보낸다
	var laid := 0
	var tossed := 0
	for trial in 40:
		var jt: Dictionary = g.drop[0]
		jt.u = from.x
		jt.w = from.y
		jt.h = 0.0
		g._give_begin(0, Vector2(from.x, g.TBL.fy))
		_step(int((tot + 0.2) * 60.0))
		if absf(float(jt.vu)) + absf(float(jt.vw)) > 1.0:
			tossed += 1
		else:
			laid += 1
	_ok("두 갈래가 다 나온다", laid > 0 and tossed > 0,
			"내려놓기 %d · 던지기 %d" % [laid, tossed])

	# ⑧ 내미는 예고 — 들고 카운터 위로 올라가면 그쪽 손이 마중 나온다
	g.npc_reach = 0.0
	g.hand_st = g.H.CARRY
	g.hand_src = 0
	g.hand_i = 0
	g.hand_m = Vector2(180.0, g.TBL.fy - 4.0)
	for k in 30:
		g._give_tick(1.0 / 60.0)
	_ok("카운터 위로 올리면 손을 내민다", g.npc_reach > 0.5 and g.npc_reach_side == 0,
			"reach %.2f · 손 %d" % [g.npc_reach, g.npc_reach_side])
	g.hand_m = Vector2(180.0, g.TBL.fy + 70.0)
	for k in 40:
		g._give_tick(1.0 / 60.0)
	_ok("팔 안으로 내리면 거둔다", g.npc_reach < 0.05, "reach %.2f" % g.npc_reach)
	g.hand_st = g.H.NONE
	g.hand_i = -1

	# ⑨ 상인이 든 것은 손님이 못 집는다
	g._give_begin(0, Vector2(from.x, g.TBL.fy))
	_step(30)
	var box: Rect2 = g._obj_box(0)
	_ok("상인이 든 것은 안 집힌다",
			g._shop_hit(box.get_center()) != 0,
			"hit %d" % g._shop_hit(box.get_center()))

	# ⑩ 리롤이 돌면 손을 놓는다 — 쓸는 팔이 물건을 들고 있으면 안 된다
	g.sweep_live = true
	g._give_tick(1.0 / 60.0)
	_ok("쓸면 물건을 놓는다", not g._give_live(), "")
	g.sweep_live = false

	# ⑪ 살피는 동안은 다른 응수가 못 들어온다
	g._give_begin(0, Vector2(from.x, g.TBL.fy))
	_step(20)
	g._npc_react("저음")
	_ok("살피는 중엔 응수가 안 든다", g._idle_name() == "살핌", g._idle_name())
	_step(400)
