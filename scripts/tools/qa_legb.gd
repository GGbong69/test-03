extends SceneTree
#  판 고르기 다트판 · 판 손(2026-10-04 · game.gd 의 LEGB · LEGH) — **연출 길**을 탄다.
#  다른 검사는 전부 _cine_ok 가 거짓이라 집기 · 엎기 · 손 딜을 한 번도 안 지난다 — 그 틈으로
#  집기가 판 갈이 뒤까지 남아 판 중 · 상점의 누름이 다 죽은 고장이 빠져나갔다(검토).
#  못 박는 것:
#    ① 딜 — 판 밑 글은 제 판이 닿기 전엔 없다 · 손은 딜 + 놓기 + 돌아가기 안에 걷힌다
#    ② 「던진다」 — 집는 동안은 판 고르기의 누름을 삼키고, LEGH.go 틀에 판을 **한 번** 연다
#    ③ 판 갈이가 끝나면 집기를 거둔다 — 판 중 사탕 칸 · 상점 매물 · 상점 사탕 칸 누름이 산다
#    ④ 집는 동안 누르면 그 틀에 판을 연다
#    ⑤ 건너뛰기 — 판을 엎고 끝에 엎기를 내린다 · 뱃지 팝은 건너뛴 판 위에 줄을 지어 선다
#    ⑥ 움직임 끔 — 「던진다」 가 누른 틀에 판을 연다(집기 없음)
#    ⑦ 개발자 「판 손 · 집기」 미리 보기 — 판을 안 열고 거둔다
#  창이 있어야 돈다(3D 손은 렌더러가 있어야 선다):
#    godot --path . --script scripts/tools/qa_legb.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const DT := 1.0 / 120.0
var g = null
var busy := false
var ok := 0
var bad := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_legb_g.cfg"
	Save.path = "user://_qa_legb.cfg"
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
	print("  %s %-46s %s" % ["통과" if cond else "실패", nm, note])


func _calm() -> void:
	g.idle_act = -1
	g.idle_wait = 99.0
	g._tutor_close()
	g.tutor_q.clear()


func _step(sec: float) -> void:
	var n: int = int(ceil(sec / DT))
	for k in n:
		_calm()
		g._process(DT)


#  판 고르기를 연다 — no 판. settle 이면 딜을 다 돌린다.
func _leg(no: int, settle := true) -> void:
	g._swap_skip()
	g.leg_skipped = {}
	g.leg_no = no
	g.state = g.S.LEG
	g._open_leg()
	g._turn_skip()
	if settle:
		_step(1.3)


func _run() -> void:
	for i in 10:
		await process_frame
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 3D 손이 선다")
		quit(0)
		return
	for id in ["u_leg", "u_skip", "u_boss", "u_score", "u_clear", "u_shop", "u_rack",
			"u_cons", "u_sell", "u_reroll", "u_give", "u_boot", "u_gift"]:
		Save.teach(id)
	g.set_process(false)
	g.legb_force = true
	g._new_run(true)
	_step(1.0)
	var L: Dictionary = g.LEGH
	var cand: Dictionary = GameData.candies()[0].duplicate()

	# ① 딜
	_leg(1, false)
	_ok("3D 손이 선다(연출 길)", g._legh_ok(), "")
	_ok("딜 첫 틀 — 판 밑 글이 아직 없다", g._legb_label_a(0) == 0.0 and g._legb_label_a(2) == 0.0, "")
	_step(0.2)
	_ok("딜 한가운데 — 왼손이 첫 판을 들고 온다", g._legb_held(0) and g._legh_live(0), "")
	var rel_end: float = g._deal_time() + float(L.rel) + float(L.ret)
	_step(rel_end - g.leg_t + DT * 2.0)
	_ok("딜 + 놓기 + 돌아가기 안에 손이 걷힌다", not g._legh_any(), "leg_t %.3f" % g.leg_t)
	_ok("딜 뒤 — 판 밑 글 셋이 다 섰다", g._legb_label_a(0) == 1.0 and g._legb_label_a(1) == 1.0
			and g._legb_label_a(2) == 1.0, "")

	# ② 「던진다」 — 집기
	g.cons.clear()
	g.cons.append(cand.duplicate())
	g._click(g._leg_go().get_center())
	_ok("던진다 — 집기가 선다(판 고르기 그대로)", g.legb_pick_i == GameData.leg_idx(g.leg_no)
			and g.state == g.S.LEG, "칸 %d · state %d" % [g.legb_pick_i, g.state])
	_ok("집는 동안 판 고르기의 누름은 삼킨다", not g._hand_press_at(g._cons_rect(0).get_center()), "")
	g.hand_st = g.H.NONE
	var t := 0.0
	while g.state == g.S.LEG and t < 1.5:
		_calm()
		g._process(DT)
		t += DT
	_ok("LEGH.go 틀에 판을 연다", g.state != g.S.LEG and absf(t - float(L.go)) <= DT * 1.5,
			"연 틀 %.3f (go %.2f)" % [t, float(L.go)])
	_ok("판을 열면 판 갈이가 돌고 손은 판을 마저 든다", g.swap_live and g.legb_pick_i >= 0
			and g.legb_pick_go, "")
	var tg: int = g.target
	g.target = -12345
	var tt := 0.0
	while (g.swap_live or g.legb_pick_i >= 0) and tt < 2.0:
		_calm()
		g._process(DT)
		tt += DT
	_ok("판은 한 번만 연다(판 갈이 동안 다시 안 연다)", g.target == -12345, "")
	g.target = tg
	_ok("판 갈이가 끝나면 집기를 거둔다", g.legb_pick_i == -1 and not g.swap_live,
			"칸 %d · %.2f 초" % [g.legb_pick_i, tt])

	# ③ 판 중 · 상점 누름
	_ok("판 중 — 사탕 칸 누름이 산다", g._hand_press_at(g._cons_rect(0).get_center()),
			"state %d" % g.state)
	g.hand_st = g.H.NONE
	g._swap_skip()
	g._open_shop()
	g.gold = 99
	_step(2.5)
	_calm()
	var mi := -1
	var mp := Vector2.ZERO
	for i in g.drop.size():
		if g.drop[i].sold > 0.0:
			continue
		var c: Vector2 = g._obj_box(i).get_center()
		if g._shop_hit(c) == i:
			mi = i
			mp = c
			break
	_ok("상점 — 누를 매물이 있다", mi >= 0, "state %d · 매물 %d" % [g.state, g.drop.size()])
	if mi >= 0:
		_ok("상점 — 매물 누름이 산다", g._hand_press_at(mp), "매물 %d" % mi)
	g.hand_st = g.H.NONE
	if g.cons.is_empty():
		g.cons.append(cand.duplicate())
	_ok("상점 — 사탕 칸 누름이 산다", g._hand_press_at(g._cons_rect(0).get_center()), "")
	g.hand_st = g.H.NONE

	# ④ 집는 동안 누르면 그 틀에 연다
	_leg(1)
	g._click(g._leg_go().get_center())
	_step(0.05)
	_ok("집는 중 — 아직 판 고르기", g.state == g.S.LEG and g.legb_pick_i >= 0, "")
	g._click(Vector2(320.0, 200.0))
	_ok("집는 중 누르면 그 틀에 판을 연다", g.state != g.S.LEG and g.legb_pick_go,
			"state %d · 집기 시계 %.2f" % [g.state, g.legb_pick_t])
	g._swap_skip()
	_step(0.1)
	_ok("— 그 뒤에도 집기를 거둔다", g.legb_pick_i == -1, "")

	# ⑤ 건너뛰기 — 엎기 · 뱃지 팝
	_leg(1)
	g.pops.clear()
	g.leg_tag = {"kind": "track", "v": 1, "when": "now", "name": "트랙 강화"}
	var top0: Vector2 = g._legb_top(0, 1)
	g._click(g._leg_skip().get_center())
	_ok("건너뛰면 그 판을 엎는다", g.leg_no == 2 and g.legb_flip_rn == 1,
			"판 %d · 엎는 판 %d" % [g.leg_no, g.legb_flip_rn])
	var pys := []
	var px_ok := true
	for p in g.pops:
		pys.append(float(p.p.y))
		px_ok = px_ok and absf(float(p.p.x) - top0.x) < 0.5
	pys.sort()
	var above: bool = not pys.is_empty() and float(pys[pys.size() - 1]) <= top0.y - 3.9
	_ok("뱃지 팝은 건너뛴 판 윗끝 위에 선다", above and px_ok,
			"팝 %d · y %s · 판 윗끝 %.1f" % [pys.size(), str(pys), top0.y])
	var apart := true
	for k in range(1, pys.size()):
		apart = apart and float(pys[k]) - float(pys[k - 1]) >= 13.9
	_ok("— 두 줄 이상이면 한 줄씩 쌓인다", pys.size() >= 2 and apart, "")
	_step(float(g.LEGB.flip) + 0.1)
	_ok("엎기가 끝나면 내린다", g.legb_flip_rn == -1 and g.legb_flip_t < 0.0, "")
	_ok("건너뛴 뒤 딜은 다시 안 돈다", not g._legh_any() and g._legb_label_a(0) == 1.0, "")

	# ⑥ 움직임 끔
	g.motion_off = true
	_leg(1)
	g._click(g._leg_go().get_center())
	_ok("움직임 끔 — 누른 틀에 판을 연다(집기 없음)", g.state != g.S.LEG and g.legb_pick_i == -1,
			"state %d" % g.state)
	g.motion_off = false
	g._swap_skip()

	# ⑦ 미리 보기
	_leg(1)
	var why: String = g._legb_pick_preview()
	_ok("미리 보기가 선다", why == "" and g.legb_pick_dry, why)
	_step(float(L.reach) + float(L.hold) + float(L.lift) + 0.05)
	_ok("미리 보기 — 다 든 자리에서도 판을 안 연다", g.state == g.S.LEG and g.leg_no == 1, "")
	_step(1.0)
	_ok("미리 보기 — 되짚어 내려놓고 거둔다", g.state == g.S.LEG and g.legb_pick_i == -1
			and g.leg_no == 1, "")
	_ok("미리 보기 뒤 — 판 고르기 누름이 산다", g._hand_press_at(g._cons_rect(0).get_center()), "")
	g.hand_st = g.H.NONE

	print("통과 %d · 실패 %d" % [ok, bad])
	quit(1 if bad > 0 else 0)
