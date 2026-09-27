extends SceneTree

# 튜토리얼 런 검사 (2026-09-26 · 2026-09-27 두 번 갈아엎음).
#   「튜토리얼을 게임의 매력을 보여 주는 걸로 특화하자 — 개사기 아이템 주는 거」
#   사용자와 절차대로 정한 흐름:
#     ① 처음 켠 사람의 첫 런은 2라운드 6판짜리 튜토리얼 런이다
#     ② 첫 상점 두 장 → 리롤을 가리키고 세 장 더 → 둘째·셋째 상점은 보드 확장 ·
#        사탕 · 팩 · 사진(TUT.pages) · 태그 [서비스]
#        · 안 집으면 다음 상점에 다시 · 곱하기는 알아서 오른쪽 끝
#     ③ 첫 상점 상인 두 줄 · SAFETY LAST! 첫 발동 한 줄
#     ④ 판 목표는 튜토리얼 런에서만 오른다(TUT.target)
#     ⑤ 6판을 넘기면 「튜토리얼 끝」 → 로비. 그때 배움 표에 적는다
#     ⑥ 챌린지·무한·검사 도구가 곧장 부르는 _new_run() 에는 안 선다 · 기록 0
#
#   godot --path . --headless --script scripts/tools/qa_boot.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.path = "user://_qa_boot.cfg"
	Save.gpath = "user://_qa_boot_g.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-44s %s" % ["통과" if c else "실패", n, d])


func _ids() -> Array:
	var out := []
	for o in g.owned:
		out.append(String(o.get("id", "")))
	return out


#  테이블에 선 선물의 자리들 — 공짜이면서 선물 표에 있는 것.
func _gift_at() -> Array:
	var out := []
	for i in g.stock.size():
		var s: Dictionary = g.stock[i]
		if bool(s.get("free", false)) and g._tut_svc(String(s.type), String(s.d.id)):
			out.append(i)
	return out


func _gift_ids() -> Array:
	var out := []
	for i in _gift_at():
		out.append(String(g.stock[i].d.id))
	out.sort()
	return out


func _tut() -> void:
	Save.wipe()
	GameData.challenge = ""
	g.state = g.S.TITLE
	g._new_run(true)


func _shop(leg: int) -> void:
	g.state = g.S.SHOP
	g.leg_no = leg
	g.gold = 4
	g._open_shop()


func _take_all() -> void:
	for i in _gift_at():
		g._buy(i)


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


func _run() -> void:
	print("\n== 튜토리얼 런 ==")
	var T: Dictionary = g.TUT

	# ── ① 누가 튜토리얼 런을 받는가 ───────────────────
	print("① 문")
	Save.wipe()
	g.state = g.S.TITLE
	g._new_run()
	_ok("검사 도구가 곧장 부르는 새 런은 튜토리얼이 아니다", not g.tut_run, "")
	_tut()
	_ok("처음 켠 사람이 「시작」을 누르면 튜토리얼 런이다", g.tut_run, "")
	_ok("런 시작에 손에 넣어 주지 않는다", _ids().is_empty(), str(_ids()))
	_ok("라운드가 둘로 보인다", g._run_rounds() == 2, "%d" % g._run_rounds())
	_ok("기록을 안 남긴다", g._rec_off(), "")
	_ok("이어하기에 적힌다", str(g.RUN_PLAIN).find("tut_run") >= 0, "")

	# ── ② 상점 셋 ────────────────────────────────────
	print("② 상점 셋")
	_shop(1)
	_ok("첫 상점에는 첫 쪽만 선다(리롤 전)", _gift_ids() == ["r14", "u26"], str(_gift_ids()))
	var free0 := true
	for i in _gift_at():
		if int(g.stock[i].cost) != 0:
			free0 = false
	_ok("값이 0 이다", free0, "")
	_ok("테이블 폭은 그대로다(나머지는 평소 매물)",
			g.stock.size() == GameData.shop_slots(1), "%d / %d"
			% [g.stock.size(), GameData.shop_slots(1)])
	_ok("상인 두 줄이 줄에 선다",
			g.tutor_q.has("u_gift") or String(g.tutor_id) == "u_gift", str(g.tutor_q))
	var steps := GameData.tutor_steps("u_gift")
	_ok("상인 말이 고른 그대로다", steps.size() == 2
			and String(steps[0].text) == "처음 보는 손님이군"
			and String(steps[1].text) == "이건 서비스야 가져가", "")
	g.drop_fast = true
	for k in 200:
		g._drop_step(1.0 / 60.0)
	_ok("과녁이 선물을 감싼다", g._mark_rect("gift").size.x > 2.0, "")
	#  곱하기를 먼저 집어도 오른쪽 끝에 선다
	var at := _gift_at()
	var xi := -1
	for i in at:
		if String(g.stock[i].d.get("k", "")) == "xmult":
			xi = i
	g._buy(xi)
	_ok("한 장만으로는 리롤을 안 가리킨다", not g.tutor_q.has("u_more"), "")
	_take_all()
	_ok("곱하기는 알아서 오른쪽 끝이다", _ids() == ["r14", "u26"], str(_ids()))
	_ok("두 장을 쥐면 상인이 리롤을 가리킨다", g.tutor_q.has("u_more"), str(g.tutor_q))
	var more := GameData.tutor_steps("u_more")
	_ok("리롤 말이 고른 그대로다", more.size() == 1
			and String(more[0].text) == "다른 것도 한번 봐봐"
			and String(more[0].mark) == "reroll", "")
	_ok("평소 리롤 설명은 겹쳐 안 뜬다", Save.taught("u_reroll"), "")
	var g1: int = g.gold
	g._reroll()
	_ok("첫 리롤은 무료다", g.gold == g1, "골드 %d → %d" % [g1, g.gold])
	_ok("리롤하면 세 장이 더 선다", _gift_ids() == ["c03", "c06", "u11"], str(_gift_ids()))
	_ok("그래도 테이블 폭은 그대로다", g.stock.size() == GameData.shop_slots(1),
			"%d" % g.stock.size())
	_take_all()
	_ok("동전 다섯 칸이 첫 상점에서 다 찬다",
			_ids() == ["r14", "u11", "c03", "u26", "c06"], str(_ids()))
	_ok("동전 슬롯을 안 넘긴다", g.owned.size() <= GameData.max_items(), "")
	_shop(2)
	_ok("둘째 상점에 보드 확장과 사탕이 선다", _gift_ids() == ["c_tr", "dnut"],
			str(_gift_ids()))
	_take_all()
	_ok("보드 확장이 끼워졌다", (g.mods_own as Array).has("dnut"), str(g.mods_own))
	var held := []
	for c in g.cons:
		held.append(String(c.get("id", "")))
	_ok("사탕이 칸에 들었다", held.has("c_tr"), str(held))
	g.cons.clear()          # 셋째 판에 썼다고 친다
	_shop(3)
	_ok("셋째 상점에 팩과 사진이 선다", _gift_ids() == ["b_small", "c_again"],
			str(_gift_ids()))
	var pk_ok := false
	for i in _gift_at():
		if String(g.stock[i].type) == "boost":
			pk_ok = (g.stock[i].d.get("pool", []) as Array) == ["cons", "fix"]
	_ok("선물 팩은 사탕·사진만 쏟는다(동전 칸이 꽉 찼다)", pk_ok, "")
	for i in _gift_at():
		if String(g.stock[i].type) == "fix":
			g._buy(i)
	_ok("받아 간 사진은 적힌다", (g.tut_got as Array).has("f:c_again"), str(g.tut_got))
	_shop(4)
	_ok("넷째 상점에는 안 받은 팩만 다시 선다", _gift_ids() == ["b_small"],
			str(_gift_ids()))
	_ok("사탕은 써서 사라져도 다시 안 선다", not _gift_ids().has("c_tr"), "")

	# ── ③ 안 집은 사람 ───────────────────────────────
	print("③ 안 집고 나가면")
	_tut()
	_shop(1)
	_ok("리롤을 안 하면 세 장은 안 선다", _gift_at().size() == 2, "%d장" % _gift_at().size())
	_shop(2)
	_ok("다음 상점에 앞 쪽까지 다 다시 선다", _gift_at().size() == 7,
			"%d장 %s · 판 %d" % [_gift_at().size(), str(_gift_ids()), g.stock.size()])

	# ── ④ 태그 ───────────────────────────────────────
	print("④ 태그")
	_ok("선물은 [서비스] 다", g._tut_svc("item", "r14") and g._tut_svc("mod", "dnut")
			and g._tut_svc("boost", "b_small") and g._tut_svc("cons", "c_tr")
			and g._tut_svc("fix", "c_again"), "")
	_ok("선물이 아닌 것은 아니다", not g._tut_svc("item", "c01"), "")
	var src := FileAccess.get_file_as_string("res://scripts/game.gd")
	_ok("태그 자리가 넷이다(슬롯 · 테이블 · 낀 판 · 사탕 칸)",
			src.count("_tip_tag(\"서비스\", C_ACC)") == 4, "")
	_ok("값표가 「공짜」를 적는다", src.find("\"공짜\"") >= 0, "")

	# ── ⑤ 판 목표 ────────────────────────────────────
	print("⑤ 판 목표")
	var tg_ok := true
	var note := ""
	for n in range(1, int(T.legs) + 1):
		var tt: int = int(T.target[n - 1])
		var got: int = g._target_at(n)
		if tt > 0 and got < tt:
			tg_ok = false
		note += "%d " % got
	_ok("튜토리얼 런은 제 목표를 쓴다", tg_ok, note)
	var raised := false
	for n in range(2, int(T.legs) + 1):
		if int(T.target[n - 1]) > GameData.target_of(n):
			raised = true
	_ok("둘째 판부터 본편보다 높다", raised, str(T.target))
	_ok("첫 판은 본편 그대로다(선물 전)", int(T.target[0]) == 0, "")
	#  보스 제약에서 「문턱」·「먹통」이 빠진다 — 잰 목표가 무너지는 둘이다.
	var bad_mod := 0
	for k in 300:
		g._roll_boss_mods(3, true)
		for mid in g.boss_mods.get(3, PackedStringArray()):
			if String(mid) == "tgt" or String(mid) == "dull":
				bad_mod += 1
	_ok("튜토리얼 보스에는 문턱·먹통이 안 걸린다", bad_mod == 0, "300번 중 %d" % bad_mod)
	g.tut_run = false
	_ok("튜토리얼이 아니면 본편 목표다", g._tut_target(2) == 0, "")
	var seen_bad := false
	for k in 300:
		g._roll_boss_mods(3, true)
		for mid in g.boss_mods.get(3, PackedStringArray()):
			if String(mid) == "tgt" or String(mid) == "dull":
				seen_bad = true
	_ok("본편 보스에는 그대로 걸린다", seen_bad, "")
	g.tut_run = true

	# ── ⑥ 6판에서 끝난다 ──────────────────────────────
	print("⑥ 끝")
	g.state = g.S.RESOLVE
	g.leg_no = int(T.legs)
	g.target = 100
	g.total = 200
	g.queue.clear()
	g.burst_hits.clear()
	g._finish_leg()
	_ok("6판을 넘기면 런 끝 화면이다", g.state == g.S.OVER and g.won, "")
	_ok("그때 배움 표에 적는다", Save.taught("u_boot"), "")
	_ok("무한 갈래를 안 연다", not g.endless_ok, "")
	g.state = g.S.TITLE
	g._new_run(true)
	_ok("다음 런은 튜토리얼이 아니다", not g.tut_run, "")
	#  중간에 지면 다음 런이 다시 튜토리얼이다
	_tut()
	g.state = g.S.RESOLVE
	g.leg_no = 3
	g.target = 1000
	g.total = 10
	g.darts_left = 0
	g.queue.clear()
	g.burst_hits.clear()
	g._finish_leg()
	_ok("중간에 지면 배움 표에 안 적는다", g.state == g.S.OVER and not g.won
			and not Save.taught("u_boot"), "")
	g.state = g.S.TITLE
	g._new_run(true)
	_ok("그 다음 런이 다시 튜토리얼이다", g.tut_run, "")

	# ── ⑦ 제약을 걸고 도는 런 ─────────────────────────
	print("⑦ 챌린지·무한")
	Save.wipe()
	GameData.challenge = "solo"
	g.state = g.S.TITLE
	g._new_run(true)
	_ok("챌린지 런은 튜토리얼이 아니다", not g.tut_run, "")
	GameData.challenge = ""

	# ── ⑧ SAFETY LAST! 가 처음 켜질 때 ─────────────────
	print("⑧ 끝이 절정인 장")
	_tut()
	for it in GameData.items():
		if String(it.id) == "u26":
			var cp: Dictionary = it.duplicate()
			cp.gs = 0
			cp.bought = 0
			g.owned.append(cp)
	g._tutor_close()
	g.tutor_q.clear()
	g.state = g.S.RESOLVE
	g.cur_chip = 40
	g.cur_mult = 4
	g.queue.clear()
	g.queue.append({"k": "item", "i": 0, "kind": "xmult", "v": 3, "lbl": "배수 ×3"})
	g._next_step()
	_ok("처음 켜질 때 한 줄이 선다", g.tutor_q.has("u_last"), str(g.tutor_q))

	# ── ⑨ 표를 안 건드린다 ────────────────────────────
	print("⑨ 밸런스")
	var i0: int = src.find("func _boot_stock")
	var i1: int = src.find("\nfunc ", i0 + 10)
	var body: String = src.substr(i0, i1 - i0)
	_ok("선물 고르는 자가 값을 한 개도 안 고친다",
			body.find("score") < 0 and body.find("target") < 0
			and body.find("gold") < 0, "")

	print("\n통과 %d · 실패 %d" % [okn, fail])
	quit(fail)
