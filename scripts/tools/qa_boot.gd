extends SceneTree

# 튜토리얼 런 검사 (2026-09-26 · 2026-09-27 여러 번 갈아엎음).
#   「튜토리얼을 게임의 매력을 보여 주는 걸로 특화하자 — 개사기 아이템 주는 거」
#   사용자와 절차대로 정한 흐름:
#     ① 처음 켠 사람의 첫 런은 1라운드 3판짜리 튜토리얼 런이다
#     ② 첫 상점 두 장 → 리롤을 가리키고 동전 셋 · 사탕 → 둘째 상점은 석양이 진다 ·
#        보드 확장 · 팩 · 사진(TUT.pages) · 태그 [서비스]
#        · 석양이 진다는 동전 칸이 차 있어 하나를 팔아야 집힌다(2026-10-06 「하나 팔고
#          받기」) — 둘째 상점에 판매 말상자(u_sell)가 선다
#        · 판을 못 건너뛴다(2026-10-06) — 본편 런은 건너뛴다
#        · 안 집으면 다음 상점에 다시 · 곱하기는 알아서 오른쪽 끝
#     ③ 상인 말(표에 있으면) — 문구는 사람이 표에서 고친다
#     ④ 판 목표 · 보스 제약은 본편 그대로 — 넘치는 점수(「점수뽕」)가 목적이다
#     ⑤ 3판을 클리어하면 「튜토리얼 끝」 → 로비. 그때 배움 표에 적는다
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


#  표에 그 갈래가 있는가 — 튜토리얼 문장은 사람이 표에서 고치고 지운다
#  (2026-09-27). 문구를 글자 그대로 박지 않는다: 있으면 제자리에 뜨는지만 본다.
func _has(id: String) -> bool:
	return not GameData.tutor_steps(id).is_empty()


func _skip(n: String, why: String) -> void:
	print("  건너뜀 %-44s %s" % [n, why])


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
	_ok("라운드가 하나로 보인다", g._run_rounds() == 1, "%d" % g._run_rounds())
	_ok("기록을 안 남긴다", g._rec_off(), "")
	_ok("이어하기에 적힌다", str(g.RUN_PLAIN).find("tut_run") >= 0, "")

	# ── ② 상점 둘 ────────────────────────────────────
	print("② 상점 둘")
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
	if _has("u_gift"):
		_ok("상인 말이 줄에 선다",
				g.tutor_q.has("u_gift") or String(g.tutor_id) == "u_gift", str(g.tutor_q))
	else:
		_skip("상인 말이 줄에 선다", "표에서 u_gift 를 지웠다")
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
	var has_more := _has("u_more")
	if has_more:
		_ok("한 장만으로는 리롤을 안 가리킨다", not g.tutor_q.has("u_more"), "")
	_take_all()
	_ok("곱하기는 알아서 오른쪽 끝이다", _ids() == ["r14", "u26"], str(_ids()))
	if has_more:
		_ok("두 장을 쥐면 상인이 리롤을 가리킨다", g.tutor_q.has("u_more"), str(g.tutor_q))
	else:
		_skip("두 장을 쥐면 상인이 리롤을 가리킨다", "표에서 u_more 를 지웠다")
	_ok("평소 리롤 설명은 겹쳐 안 뜬다", Save.taught("u_reroll"), "")
	_ok("리롤 전에는 정보 단추 줄이 안 뜬다(리롤 쪽이 아직 안 섰다)",
			not g.tutor_q.has("u_info"), str(g.tutor_q))
	var g1: int = g.gold
	g._reroll()
	_ok("첫 리롤은 무료다", g.gold == g1, "골드 %d → %d" % [g1, g.gold])
	_ok("리롤하면 동전 셋과 사탕이 선다", _gift_ids() == ["c03", "c06", "c_tr", "u11"],
			str(_gift_ids()))
	_ok("그래도 테이블 폭은 그대로다", g.stock.size() == GameData.shop_slots(1),
			"%d" % g.stock.size())
	_take_all()
	_ok("동전 다섯 칸이 첫 상점에서 다 찬다",
			_ids() == ["r14", "u11", "c03", "u26", "c06"], str(_ids()))
	if _has("u_info"):
		_ok("선물을 다 받으면 정보 단추 줄이 선다", g.tutor_q.has("u_info")
				or String(g.tutor_id) == "u_info", str(g.tutor_q))
		_ok("정보 단추 과녁이 선다", g._mark_rect("info").size.x > 2.0,
				str(g._mark_rect("info")))
	else:
		_skip("선물을 다 받으면 정보 단추 줄이 선다", "표에서 u_info 를 지웠다")
	_ok("동전 슬롯을 안 넘긴다", g.owned.size() <= GameData.max_items(), "")
	var held := []
	for c in g.cons:
		held.append(String(c.get("id", "")))
	_ok("사탕이 칸에 들었다", held.has("c_tr"), str(held))
	g.cons.clear()          # 둘째 판에 썼다고 친다
	_shop(2)
	_ok("둘째 상점에 석양이 진다 · 보드 확장 · 팩 · 사진이 선다",
			_gift_ids() == ["b_small", "c_again", "dnut", "r05"], str(_gift_ids()))
	_ok("테이블 폭은 그대로다(선물 넷이 네 칸을 다 쓴다)",
			g.stock.size() == GameData.shop_slots(2), "%d" % g.stock.size())
	if _has("u_sell"):
		_ok("둘째 상점에 판매 말상자가 선다", g.tutor_q.has("u_sell")
				or String(g.tutor_id) == "u_sell", str(g.tutor_q))
	else:
		_skip("둘째 상점에 판매 말상자가 선다", "표에서 u_sell 을 지웠다")
	#  석양이 진다 — 동전 칸이 차 있어 못 집고, 하나를 팔면 집힌다(「하나 팔고 받기」).
	var sun := -1
	for i in _gift_at():
		if String(g.stock[i].d.id) == "r05":
			sun = i
	_ok("석양이 진다는 동전 칸이 차 있어 못 집는다", sun >= 0 and g._buy_block(sun) != "",
			"「%s」" % (g._buy_block(sun) if sun >= 0 else "없다"))
	var sold_id := String(g.owned[0].get("id", ""))
	g._sell(0)
	_ok("동전 하나를 팔면 집힌다", sun >= 0 and g._buy_block(sun) == "",
			"판 것 %s · 「%s」" % [sold_id, g._buy_block(sun) if sun >= 0 else "없다"])
	if sun >= 0:
		g._buy(sun)
	_ok("석양이 진다가 동전 칸에 든다", _ids().has("r05") and g.owned.size() <= GameData.max_items(),
			str(_ids()))
	var pk_ok := false
	for i in _gift_at():
		if String(g.stock[i].type) == "boost":
			pk_ok = (g.stock[i].d.get("pool", []) as Array) == ["cons", "fix"]
	_ok("선물 팩은 사탕·사진만 쏟는다(동전 칸이 꽉 찼다)", pk_ok, "")
	for i in _gift_at():
		if String(g.stock[i].type) == "fix" or String(g.stock[i].type) == "mod":
			g._buy(i)
	_ok("보드 확장이 끼워졌다", (g.mods_own as Array).has("dnut"), str(g.mods_own))
	_ok("받아 간 사진은 적힌다", (g.tut_got as Array).has("f:c_again"), str(g.tut_got))
	#  상점 셋째는 튜토리얼 런에 없다(3판에서 끝난다) — 남은 것이 다시 서는
	#  규칙만 잰다.
	_shop(3)
	#  판 선물 동전은 「가졌는가」로 보므로(_boot_stock — 깨진 유리 대포 · 이카로스가 다시
	#  서는 그 규칙) 석양이 진다를 받으려고 판 동전도 다시 선다.
	var want := ["b_small", sold_id]
	want.sort()
	_ok("다음 상점에는 안 받은 팩과 판 동전만 다시 선다", _gift_ids() == want,
			str(_gift_ids()))
	_ok("사탕은 써서 사라져도 다시 안 선다", not _gift_ids().has("c_tr"), "")

	# ── ③ 안 집은 사람 ───────────────────────────────
	print("③ 안 집고 나가면")
	_tut()
	_shop(1)
	_ok("리롤을 안 하면 리롤 쪽은 안 선다", _gift_at().size() == 2, "%d장" % _gift_at().size())
	_shop(2)
	_ok("다음 상점에 앞 쪽까지 다 다시 선다", _gift_at().size() == 10,
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

	# ── ⑤ 판 목표 · 보스 제약은 본편 그대로 ─────────────
	#  한때 튜토리얼 런에서만 목표를 올리고 보스 제약 둘을 뺐다 — 반려됐다
	#  (2026-09-27 「점수뽕을 느끼는 걸 제공할 거였는데 … 점수 곡선도 걍 기본으로」).
	print("⑤ 판 목표 · 보스 제약")
	var same := true
	var note := ""
	for n in range(1, int(T.legs) + 1):
		var a0: int = g._target_at(n)
		g.tut_run = false
		var a1: int = g._target_at(n)
		g.tut_run = true
		if a0 != a1:
			same = false
		note += "%d " % a0
	_ok("튜토리얼 런도 본편 목표다", same and not T.has("target"), note)
	var seen_bad := false
	for k in 300:
		g._roll_boss_mods(3, true)
		for mid in g.boss_mods.get(3, PackedStringArray()):
			if String(mid) == "tgt" or String(mid) == "dull":
				seen_bad = true
	_ok("튜토리얼 보스도 제약 표를 그대로 쓴다", seen_bad, "")

	# ── ⑥ 마지막 판에서 끝난다 ──────────────────────────────
	print("⑥ 끝")
	g.state = g.S.RESOLVE
	g.leg_no = int(T.legs)
	g.target = 100
	g.total = 200
	g.queue.clear()
	g.burst_hits.clear()
	g._finish_leg()
	_ok("%d판을 클리어하면 런 끝 화면이다" % int(T.legs), g.state == g.S.OVER and g.won, "")
	_ok("그때 배움 표에 적는다", Save.taught("u_boot"), "")
	_ok("무한 갈래를 안 연다", not g.endless_ok, "")
	g.state = g.S.TITLE
	g._new_run(true)
	_ok("다음 런은 튜토리얼이 아니다", not g.tut_run, "")
	#  튜토리얼은 한 번뿐이다 — 선 순간 적고, 중간에 져도 다음 런은 본편이다.
	#  「처음 튜토리얼 할때만 물건 소개겸 이렇게 줘야지 일단 플레이에서 무료로
	#  주면 어떻게」(2026-10-02). 전에는 끝까지 깨야 적어서 새 런마다 또 섰다.
	_tut()
	_ok("튜토리얼이 서는 순간 배움 표에 적는다", g.tut_run and Save.taught("u_boot"), "")
	g.state = g.S.RESOLVE
	g.leg_no = 3
	g.target = 1000
	g.total = 10
	g.darts_left = 0
	g.queue.clear()
	g.burst_hits.clear()
	g._finish_leg()
	_ok("중간에 지면 런이 끝난다", g.state == g.S.OVER and not g.won, "")
	g.state = g.S.TITLE
	g._new_run(true)
	_ok("중간에 져도 다음 런은 튜토리얼이 아니다", not g.tut_run, "")
	#  옛 저장 — 끝까지 안 깨서 u_boot 가 없지만 첫 상점 대사(u_gift)는 본 사람.
	Save.wipe()
	Save.teach("u_gift")
	g.state = g.S.TITLE
	g._new_run(true)
	_ok("첫 상점 대사를 본 옛 저장은 튜토리얼을 또 안 받는다", not g.tut_run, "")

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
	if _has("u_last"):
		_ok("처음 켜질 때 한 줄이 선다", g.tutor_q.has("u_last"), str(g.tutor_q))
	else:
		_skip("처음 켜질 때 한 줄이 선다", "표에서 u_last 를 지웠다")

	# ── ⑧-b 말하는 줄 — 비주얼 노벨처럼 (2026-09-27) ──────
	#  tutor.csv 의 who 가 찬 줄은 이름표가 서고 한 자씩 나온다. 첫 누름은 다
	#  보여 주기, 둘째 누름이 넘기기다. 어느 줄이 말하는 줄인지는 사람이 표에서
	#  정한다 — 표에서 who 가 찬 첫 줄을 골라 잰다.
	print("⑧-b 말하는 줄")
	var talk_id := ""
	var talk_i := 0
	for r in GameData.tutor():
		if String(r.get("who", "")).strip_edges() != "" and String(r.get("id", "")) != "":
			talk_id = String(r.id)
			talk_i = int(r.get("step", "1")) - 1
			break
	if talk_id == "":
		_skip("말하는 줄이 한 자씩 나온다", "표에 who 가 찬 줄이 없다")
	else:
		g._tutor_close()
		g.tutor_q.clear()
		g.tutor_id = talk_id
		g.tutor_i = talk_i
		g.tutor_t = 0.0
		g.tutor_pre = 0.0
		g.tutor_out = 0.0
		g.motion_off = false
		var full := String(g._tutor_step().get("text", "")).length()
		_ok("이름표가 표의 who 를 읽는다", g._tutor_who() != "", g._tutor_who())
		_ok("처음에는 한 자도 안 보인다", g._tutor_shown() == 0, "%d" % g._tutor_shown())
		g.tutor_t = 0.1
		var mid: int = g._tutor_shown()
		_ok("시간이 가면 한 자씩 나온다", mid > 0 and mid < full, "%d / %d" % [mid, full])
		g.tutor_t = float(g.TUTOR.lead) + 0.01
		if g._tutor_typing():
			var i_before: int = g.tutor_i
			g._tutor_click(Vector2(-1.0, -1.0))
			_ok("다 안 나왔을 때 누르면 먼저 다 보여 준다",
					not g._tutor_typing() and g.tutor_i == i_before
					and String(g.tutor_id) == talk_id, "%d / %d" % [g._tutor_shown(), full])
		else:
			_skip("다 안 나왔을 때 누르면 먼저 다 보여 준다", "lead 안에 다 나오는 짧은 줄")
		var i2: int = g.tutor_i
		g._tutor_click(Vector2(-1.0, -1.0))
		_ok("다 나온 뒤에 누르면 넘어간다", g.tutor_i != i2 or String(g.tutor_id) != talk_id, "")
		g.tutor_id = talk_id
		g.tutor_i = talk_i
		g.tutor_t = 0.0
		g.motion_off = true
		_ok("모션을 끄면 한 번에 다 선다", g._tutor_shown() == full, "")
		g.motion_off = false
		g._tutor_close()
	#  설명(내레이션) 줄도 한 자씩 나온다 — 「텍스트가 나올때 한번에 나오지
	#  않고 한글자씩 나오면서 웅웅 소리도」(2026-10-02). 전에는 한 번에 섰다.
	var narr_id := ""
	for r in GameData.tutor():
		if String(r.get("who", "")).strip_edges() == "" and String(r.get("id", "")) != "":
			narr_id = String(r.id)
			break
	if narr_id != "":
		g.tutor_id = narr_id
		g.tutor_i = 0
		g.tutor_t = 0.0
		var nfull := String(g._tutor_step().get("text", "")).length()
		_ok("설명 줄도 처음에는 한 자도 안 보인다", g._tutor_shown() == 0, narr_id)
		g.tutor_t = 0.1
		var nmid: int = g._tutor_shown()
		_ok("설명 줄도 시간이 가면 한 자씩 나온다", nmid > 0 and nmid <= nfull,
				"%d / %d" % [nmid, nfull])
		#  말소리 — 틱이 글자를 내면 「웅」 이 하나 난다(talk_n 이 센다).
		g.tutor_t = 0.0
		g.tutor_pre = 0.0
		g.tutor_out = 0.0
		g.talk_cool = 0.0
		var tn0: int = g.talk_n
		for _k in 6:
			g._tutor_tick(1.0 / 60.0)
		_ok("글자가 나오면 말소리가 난다", g.talk_n > tn0, "%d → %d" % [tn0, g.talk_n])
		g._tutor_close()
	_ok("정보 과녁 이름이 표에 있다", GameData.TUTOR_MARKS.has("info"), "")

	# ── ⑨ 표를 안 건드린다 ────────────────────────────
	print("⑨ 밸런스")
	var i0: int = src.find("func _boot_stock")
	var i1: int = src.find("\nfunc ", i0 + 10)
	var body: String = src.substr(i0, i1 - i0)
	_ok("선물 고르는 자가 값을 한 개도 안 고친다",
			body.find("score") < 0 and body.find("target") < 0
			and body.find("gold") < 0, "")

	# ── ⑩ 판 건너뛰기 ──────────────────────────────
	#  「튜토리얼때 건너뛰기가 가능한가? 가능하면 안되게 막아주고」(2026-10-06) — 세 판이
	#  곧 선물 상점 둘이라 한 판만 건너뛰어도 선물 한 쪽과 빌드가 빠진다.
	print("⑩ 판 건너뛰기")
	_tut()
	var l0: int = g.leg_no
	_ok("튜토리얼 런은 판을 못 건너뛴다", not g._can_skip(1) and not g._can_skip(2)
			and GameData.skippable(1), "")
	_ok("건너뛰기 보상(뱃지)을 안 굴린다", g._leg_tag(1).is_empty() and g._leg_tag(2).is_empty(),
			str(g.leg_tags))
	_ok("건너뛰기 말상자를 안 띄운다", not g.tutor_q.has("u_skip")
			and String(g.tutor_id) != "u_skip", str(g.tutor_q))
	g._skip_leg()
	_ok("눌러도 판이 그대로다", g.leg_no == l0 and not g.leg_skipped.has(l0), "판 %d" % g.leg_no)
	Save.wipe()
	g.state = g.S.TITLE
	g._new_run()
	_ok("본편 런은 건너뛴다", g._can_skip(1) and not g._leg_tag(1).is_empty(),
			str(g._leg_tag(1).get("id", "")))

	print("\n통과 %d · 실패 %d" % [okn, fail])
	quit(fail)
