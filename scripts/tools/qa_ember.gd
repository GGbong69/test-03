extends SceneTree

# 판 사건 · 불씨 검사 (2026-10-06).
#   사용자: 「지금 게임에 너무 갑작스러운 도전성이 없는거 같아 변수가 없으니 하면
#   할수록 좀 재미가 적어지거든?」 — 작은 판 · 큰 판이 열릴 때 사건 하나(data/events.csv).
#   불씨 수정: 「불씨가 배수를 주면 너무 사기니까 … 1골드씩 주는걸로 하자」.
#   못 박는 것:
#     ① 표 — 갈래 넷 · 처음 가중치(없음 2 · 불씨 3 · 주문 2 · 단골 2) · 검증기 오류 0
#     ② 뽑기가 run_rng 하나로 같은 판을 다시 낸다 · 뽑는 수가 판마다 같다 · 갈래 몫
#     ③ 보스 판은 사건이 없다
#     ④ 튜토리얼 런 — 첫 판 없음 · 둘째 판 불씨(첫 발 전) · 주문 · 단골 0
#     ⑤ 불은 안 뽑힌다 · 칸은 0..n−1 · 띠는 셋 중 하나 · 피자는 싱글만
#     ⑥ 이 판에서 가장 많이 맞힌 칸은 피한다
#     ⑦ 피는 때 — k 번째 발 정산이 끝난 뒤에 핀다(그 앞은 안 서 있다)
#     ⑧ 맞히면 「불씨」 걸음 하나 → 골드 +1 · 동전 뒤 · 모음 · 합계 앞 · 오름 없음
#     ⑨ 맞힌 링만큼 옮겨 붙는다(트리플 3 · 더블 2 · 싱글 1)
#     ⑩ 다른 데 꽂거나 빗나가면 꺼지고 그 판에 다시 안 선다
#     ⑪ 연발의 작은 다트는 맞히지도 끄지도 않는다
#     ⑫ 점수는 한 톨도 안 바뀐다
#     ⑬ 걸음이 _pace 를 탄다 · 카드에 글이 안 선다
#     ⑭ 판이 끝나면 사라진다 · 판이 새로 서면 비운다
#     ⑮ 되살리기(판 매듭)가 같은 사건 · 같은 칸을 다시 낸다
#     ⑯ 주문 · 단골 판에는 불씨가 없다(주문은 qa_order · 단골은 qa_regular)
#     ⑰ 개발자 판 「불씨 피우기」 — 열아홉 줄 안 · 게임 함수로 곧장 핀다
#     ⑱ 그림 — 글자 0 · 새 색 0 · 난수 0 · 모션 끄기면 일렁임이 없다
#
#   godot --headless --path . --script scripts/tools/qa_ember.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.path = "user://_qa_ember.cfg"
	Save.gpath = "user://_qa_ember_g.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-44s %s" % ["통과" if c else "실패", n, d])


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	print("\n통과 %d · 실패 %d" % [okn, fail])
	quit(fail)
	return false


#  새 런 하나 — 판 갈이를 감고 목표를 높여 던져도 판이 안 끝나게 둔다.
func _fresh(mods := []) -> void:
	g.state = g.S.TITLE
	g._new_run()
	g.tut_run = false
	g.mods_own = mods
	g._board_bake()
	g.owned.clear()


#  조건 없는 배수 +2 한 장(c01) — 값이 늘 같은 동전이라 두 판의 걸음을 댈 수 있다.
func _give_c01() -> void:
	for it in GameData.items():
		if String(it.get("id", "")) == "c01":
			var cp: Dictionary = it.duplicate()
			cp.erase("w")
			cp.gs = 0
			cp.bought = 1
			g.owned.append(cp)
			return


#  판 n 을 씨앗 s 로 세운다. _start_leg 이 판 사건을 굴린다.
func _roll_at(n: int, s: int) -> void:
	g.leg_no = n
	g.run_seed = s
	g.run_rng.seed = s
	g._start_leg()
	g._swap_skip()
	g.target = 99999999


func _tuple() -> Array:
	return [g.leg_ev, g.ember_band, g.ember_k, g.ember_u, g.ember_idx]


#  칸 i · 띠 한가운데. 불씨 쪽 함수(_ember_at)를 안 빌린다 — 자가 재는 것과 같은
#  식을 쓰면 둘이 같이 틀려도 초록이다.
func _aim(i: int, band: String) -> Vector2:
	var a: float = float(i) * g._sec_w()
	var r := 0.0
	match band:
		"t": r = g.R * (g.rt_trp_in + g.rt_trp_out) * 0.5
		"d": r = g.R * (g.rt_dbl_in + g.rt_dbl_out) * 0.5
		"s": r = g.R * (g.rt_trp_out + g.rt_dbl_in) * 0.5
		"si": r = g.R * (g.rt_bull_o + g.rt_trp_in) * 0.5
		"bull": r = 0.0
		"out": r = g.R * 1.4
	return g.BC + Vector2(sin(a), -cos(a)) * r


func _throw(i: int, band: String, mark := true) -> void:
	g.aim = _aim(i, band)
	g._land(mark)


#  한 발의 정산을 끝까지 판다. 큐가 빈 뒤 한 번 더 — 그 자리가 「한 발이 끝났다」다.
func _settle() -> void:
	var guard := 0
	while g.state == g.S.RESOLVE and guard < 400:
		g._next_step()
		guard += 1


func _kinds(q: Array) -> Array:
	var out := []
	for st in q:
		out.append(String((st as Dictionary).get("k", "")))
	return out


func _run() -> void:
	print("\n== 판 사건 · 불씨 ==")
	var n := 0

	# ── ① 표 ─────────────────────────────────────────
	print("① 표")
	var w := {}
	for r in GameData.events():
		w[String(r.get("kind", ""))] = GameData.event_w(r)
	_ok("갈래 넷이 다 있다", w.has("none") and w.has("ember") and w.has("order")
			and w.has("regular"), str(w.keys()))
	_ok("처음 가중치 2 · 3 · 2 · 2", is_equal_approx(float(w.get("none", 0)), 2.0)
			and is_equal_approx(float(w.get("ember", 0)), 3.0)
			and is_equal_approx(float(w.get("order", 0)), 2.0)
			and is_equal_approx(float(w.get("regular", 0)), 2.0), str(w))
	var ev_errs := []
	for e in GameData.errors():
		if String(e).begins_with("events"):
			ev_errs.append(e)
	_ok("검증기가 events 에 오류를 안 낸다", ev_errs.is_empty(), str(ev_errs))
	var er: Dictionary = GameData.event_of("ember")
	_ok("불씨 골드는 1", int(GameData.event_v(er, "v")) == 1,
			"v %d · v2 %d" % [int(GameData.event_v(er, "v")), int(GameData.event_v(er, "v2"))])

	# ── ② run_rng 하나로 같은 판 ─────────────────────
	print("② 뽑기")
	#  새 런의 줄기는 씨앗에서 선다 — state 를 0 으로 덮던 때는 모든 런이 같은 줄기라
	#  첫 판 사건이 런마다 늘 같았다.
	_fresh()
	var rs1: int = g.run_rng.state
	var sd1: int = g.run_seed
	_fresh()
	_ok("런마다 줄기가 다르다", g.run_rng.state != rs1 or g.run_seed == sd1,
			"%d · %d" % [rs1, g.run_rng.state])
	_ok("매듭 자리가 그 줄기의 머리다", g.knot_rng == g.run_rng.state)
	var same := true
	var steps_same := true
	var cnt := {"": 0, "ember": 0, "order": 0, "regular": 0}
	var k_seen := {}
	var N := 450
	for s in range(1, N + 1):
		_roll_at(1, s)
		var a := _tuple()
		var st_a: int = g.run_rng.state
		cnt[g.leg_ev] = int(cnt.get(g.leg_ev, 0)) + 1
		if g.leg_ev == "ember":
			k_seen[g.ember_k] = true
		_roll_at(1, s)
		if _tuple() != a:
			same = false
		if g.run_rng.state != st_a:
			steps_same = false
	_ok("같은 씨앗 · 같은 자리면 같은 사건 · 같은 칸", same)
	_ok("run_rng 가 판마다 같은 만큼 간다", steps_same)
	var fe := float(cnt.ember) / float(N)
	var fn := float(cnt[""]) / float(N)
	_ok("불씨 몫이 3/9 둘레다", fe > 0.26 and fe < 0.41, "%.3f" % fe)
	_ok("없음 몫이 2/9 둘레다", fn > 0.16 and fn < 0.29, "%.3f" % fn)
	_ok("주문 · 단골도 뽑힌다", int(cnt.order) > 0 and int(cnt.regular) > 0,
			"주문 %d · 단골 %d" % [cnt.order, cnt.regular])
	_ok("피는 때 0 · 1 · 2 · 3 이 다 나온다", k_seen.has(0) and k_seen.has(1)
			and k_seen.has(2) and k_seen.has(3), str(k_seen.keys()))
	#  전역 난수를 섞어도 같은 판이다 — 뽑기가 전역을 안 쓴다.
	_roll_at(1, 77)
	var b77 := _tuple()
	for i in 13:
		randi()
	_roll_at(1, 77)
	_ok("전역 난수가 밀려도 같다", _tuple() == b77, str(b77))
	#  「빈손」(gold_off)은 불씨를 안 뽑는다 — 불씨가 주는 것은 골드뿐이라 빈손 판에서는 맞혀도
	#  소리만 나고 0 이었다(검토). 거른 줄은 가중치째 빠지고 뽑기는 그대로 한 번이라 같은
	#  씨앗이면 같은 판이다. 2026-10-06
	GameData.challenge = "empty"
	var em_on: bool = GameData.chal_on("gold_off")
	var em_cnt := {}
	var em_same := true
	for s in range(1, 301):
		_roll_at(2, s)
		var ea := _tuple()
		em_cnt[g.leg_ev] = int(em_cnt.get(g.leg_ev, 0)) + 1
		_roll_at(2, s)
		if _tuple() != ea:
			em_same = false
	GameData.challenge = ""
	_ok("빈손은 불씨를 안 뽑는다 · 다른 사건은 뽑힌다 · 같은 씨앗이면 같은 판", em_on
			and int(em_cnt.get("ember", 0)) == 0 and int(em_cnt.get("order", 0)) > 0
			and int(em_cnt.get("regular", 0)) > 0 and em_same, str(em_cnt))

	# ── ③ 보스 판 ────────────────────────────────────
	print("③ 보스 판")
	var boss_n := 0
	for ln in range(1, GameData.legs_n() + 1):
		if GameData.is_boss(ln):
			boss_n = ln
			break
	var boss_any := false
	for s in range(1, 120):
		_roll_at(boss_n, s)
		if g.leg_ev != "" or g.ember_idx >= 0:
			boss_any = true
	_ok("보스 판(%d)은 사건이 없다" % boss_n, not boss_any)
	_ok("보스 판에는 뽑을 줄이 없다", GameData.event_pool(boss_n).is_empty())

	# ── ④ 튜토리얼 런 ────────────────────────────────
	print("④ 튜토리얼 런")
	_fresh()
	g.tut_run = true
	var t1 := false
	var t2_ember := true
	var t2_pre := true
	var t3 := false
	for s in range(1, 80):
		_roll_at(1, s)
		if g.leg_ev != "":
			t1 = true
		_roll_at(2, s)
		if g.leg_ev != "ember":
			t2_ember = false
		if g.ember_k != 0 or g.ember_idx < 0:
			t2_pre = false
		_roll_at(3, s)
		if g.leg_ev != "":
			t3 = true
	_ok("튜토리얼 첫 판은 사건이 없다", not t1)
	_ok("튜토리얼 둘째 판은 늘 불씨다(주문 · 단골 0)", t2_ember)
	_ok("튜토리얼 불씨는 첫 발 전에 핀다", t2_pre)
	_ok("튜토리얼 셋째(보스) 판은 사건이 없다", not t3)
	g.tut_run = false

	# ── ⑤ 칸 · 띠 ────────────────────────────────────
	print("⑤ 칸 · 띠")
	_fresh()
	var bad_cell := 0
	var bands := {}
	var lit_n := 0
	for s in range(1, 400):
		_roll_at(1, s)
		if g.ember_idx < 0:
			continue
		lit_n += 1
		bands[g.ember_band] = true
		var hi: Dictionary = g.hit_info(_aim(g.ember_idx, g.ember_band))
		if g.ember_idx >= g._sec_n() or int(hi.idx) != g.ember_idx \
				or bool(hi.get("bull", false)) or g._ember_band_of(hi) != g.ember_band:
			bad_cell += 1
	_ok("핀 불씨가 있다", lit_n > 20, "%d판" % lit_n)
	_ok("불은 안 뽑히고 칸 · 띠가 판과 맞다", bad_cell == 0, "어긋남 %d" % bad_cell)
	_ok("띠 셋이 다 나온다", bands.has("t") and bands.has("d") and bands.has("s"),
			str(bands.keys()))
	_ok("띠 고르기 경계 — 0 트리플 · 0.5 더블 · 0.99 싱글",
			g._ember_band_pick(0.0) == "t" and g._ember_band_pick(0.5) == "d"
			and g._ember_band_pick(0.99) == "s",
			"%s %s %s" % [g._ember_band_pick(0.0), g._ember_band_pick(0.5),
			g._ember_band_pick(0.99)])
	_fresh(["pizz"])
	g._start_leg()
	g._swap_skip()
	var piz := true
	for u in [0.0, 0.3, 0.5, 0.8, 0.99]:
		if g._ember_band_pick(float(u)) != "s":
			piz = false
	_ok("피자(트리플 · 더블 없음)는 싱글만", piz)

	# ── ⑥ 가장 많이 맞힌 칸 ──────────────────────────
	print("⑥ 가장 많이 맞힌 칸")
	_fresh()
	_roll_at(1, 5)
	var i20: int = g.sectors.find(20)
	g.sec_cnt = {20: 3, 1: 1}
	var hit20 := false
	for u in 200:
		g.ember_u = u
		if g._ember_cell() == i20:
			hit20 = true
	_ok("가장 많이 맞힌 칸(20)은 안 뽑는다", not hit20)
	g.sec_cnt = {}
	var free20 := false
	for u in 200:
		g.ember_u = u
		if g._ember_cell() == i20:
			free20 = true
	_ok("맞힌 것이 없으면 20 도 뽑힌다", free20)

	# ── ⑦ 피는 때 ────────────────────────────────────
	print("⑦ 피는 때")
	_fresh()
	var s2 := -1
	for s in range(1, 3000):
		_roll_at(1, s)
		if g.leg_ev == "ember" and g.ember_k == 2:
			s2 = s
			break
	_ok("두 번째 발 뒤에 필 판을 찾았다", s2 > 0, "씨앗 %d" % s2)
	if s2 > 0:
		_ok("첫 발 전에는 안 서 있다", g.ember_idx < 0)
		_throw(i20, "si")
		_settle()
		_ok("첫 발 뒤에도 안 서 있다", g.ember_idx < 0, "발 %d" % g.leg_throws)
		_throw(i20, "si")
		_ok("둘째 발 정산 중에는 안 서 있다", g.ember_idx < 0)
		_settle()
		_ok("둘째 발 정산이 끝나면 핀다", g.ember_idx >= 0, "발 %d · 칸 %d"
				% [g.leg_throws, g.ember_idx])
		_ok("두 번 맞힌 20 은 피한다", g.ember_idx != i20,
				"칸 값 %d" % int(g.sectors[maxi(g.ember_idx, 0)]))
		_ok("핀 순간 피는 불꽃이 가득이다", is_equal_approx(g._ember_lit_k(), 1.0))

	# ── ⑧ 맞히면 골드 걸음 ───────────────────────────
	print("⑧ 맞히면")
	_fresh()
	_give_c01()
	_roll_at(1, 3)
	n = g._sec_n()
	g._ember_light(5, "t")
	var gold0: int = g.gold
	_throw(5, "t")
	var ks := _kinds(g.queue)
	var ei := ks.find("ember")
	_ok("「불씨」 걸음이 하나 선다", ks.count("ember") == 1, str(ks))
	_ok("동전 · 점수 걸음 뒤 · 모음 · 합계 앞", ks.has("item") and ei > ks.rfind("item")
			and ei > ks.find("mult")
			and ei < ks.find("wind") and ei < ks.find("total"), str(ks))
	_ok("걸음 값이 표의 골드다", int((g.queue[ei] as Dictionary).get("v", 0)) == 1)
	_ok("맞힌 순간 불씨가 옮겨 간다(트리플 셋)", g.ember_idx == (5 + 3) % n,
			"%d → %d" % [5, g.ember_idx])
	_ok("그림은 걸음이 설 때까지 맞힌 칸에 남는다", g.ember_from == 5)
	_ok("정산 전에는 골드가 그대로다", g.gold == gold0)
	#  걸음까지 판다 — 그 걸음의 길이를 본다(⑬).
	var pace_ok := false
	var item_ok := true
	while not g.queue.is_empty():
		var nk := String((g.queue[0] as Dictionary).get("k", ""))
		g._next_step()
		if nk == "ember":
			pace_ok = absf(g.qt - g.beat * g._pace()) < 0.0001
			item_ok = g.card_item == ""
			_ok("걸음에서 골드가 1 오른다", g.gold == gold0 + 1, "%d → %d" % [gold0, g.gold])
			_ok("걸음에서 그림이 새 칸으로 넘어간다", g.ember_from == -1)
	_settle()
	_ok("한 발에 한 번 — 정산 끝 골드 +1", g.gold == gold0 + 1, "%d → %d" % [gold0, g.gold])
	var at2: int = g.ember_idx
	_throw(at2, "t")
	_settle()
	_ok("다시 맞히면 또 +1(오름 없음)", g.gold == gold0 + 2 and g.ember_hits == 2,
			"%d → %d · 맞힘 %d" % [gold0, g.gold, g.ember_hits])

	# ── ⑨ 맞힌 링만큼 ────────────────────────────────
	print("⑨ 옮김")
	for pair in [["t", 3], ["d", 2], ["s", 1]]:
		_roll_at(1, 3)
		g._ember_light(17, String(pair[0]))
		_throw(17, String(pair[0]))
		_ok("%s 를 맞히면 %d칸 간다" % [String(pair[0]), int(pair[1])],
				g.ember_idx == (17 + int(pair[1])) % n, "17 → %d" % g.ember_idx)
	_roll_at(1, 3)
	g._ember_light(n - 1, "t")
	_throw(n - 1, "t")
	_ok("끝 칸에서 한 바퀴 돌아 앞 칸으로", g.ember_idx == 2, "%d → %d" % [n - 1, g.ember_idx])

	# ── ⑩ 꺼진다 ─────────────────────────────────────
	print("⑩ 꺼짐")
	for wrong in [[9, "d", "다른 칸"], [4, "d", "같은 칸 다른 띠"], [4, "si", "같은 칸 안쪽 싱글"],
			[0, "bull", "불"], [0, "out", "빗나감"]]:
		_roll_at(1, 3)
		g._ember_light(4, "t")
		_throw(int(wrong[0]), String(wrong[1]))
		_ok("%s 에 꽂으면 꺼진다" % String(wrong[2]),
				g.ember_idx < 0 and g.ember_out and not _kinds(g.queue).has("ember")
				and g.ember_puff.size() == 1, "칸 %d · 연기 %d" % [g.ember_idx, g.ember_puff.size()])
	_roll_at(1, 3)
	g._ember_light(4, "t")
	g.ember_k = 1                 # 아직 안 핀 것으로 쳐도
	_throw(9, "d")
	_settle()
	_throw(9, "d")
	_settle()
	_ok("꺼진 불씨는 그 판에 다시 안 선다", g.ember_idx < 0, "발 %d" % g.leg_throws)

	# ── ⑪ 연발의 작은 다트 ───────────────────────────
	print("⑪ 연발")
	_roll_at(1, 3)
	g._ember_light(6, "d")
	_throw(6, "d", false)
	_ok("작은 다트는 맞히지 않는다", g.ember_idx == 6 and g.ember_hits == 0
			and not _kinds(g.queue).has("ember"), "칸 %d" % g.ember_idx)
	_throw(12, "t", false)
	_ok("작은 다트는 끄지 않는다", g.ember_idx == 6 and not g.ember_out)

	# ── ⑫ 점수는 그대로 ──────────────────────────────
	print("⑫ 점수")
	_roll_at(1, 3)
	g.ember_idx = -1              # 이 판에 핀 불씨가 있으면 걷는다
	g.ember_k = -1
	_throw(8, "t")
	var q0 := []
	for st in g.queue:
		if String(st.k) != "ember":
			q0.append(st.duplicate())
	_settle()
	var tot0: int = g.total
	_roll_at(1, 3)
	g._ember_light(8, "t")
	_throw(8, "t")
	var q1 := []
	for st in g.queue:
		if String(st.k) != "ember":
			q1.append(st.duplicate())
	_settle()
	_ok("불씨 말고 걸음이 같다", str(q0) == str(q1), "%d · %d걸음" % [q0.size(), q1.size()])
	_ok("총점이 같다", g.total == tot0 and tot0 > 0, "%d · %d" % [tot0, g.total])

	# ── ⑬ 박자 · 글 ──────────────────────────────────
	print("⑬ 걸음")
	_ok("「불씨」 걸음이 _pace 를 탄다", pace_ok)
	_ok("카드에 이름 줄이 안 선다", item_ok)

	# ── ⑭ 판 끝 · 새 판 ──────────────────────────────
	print("⑭ 판 끝")
	_roll_at(1, 3)
	g._ember_light(4, "t")
	g._start_leg()
	g._swap_skip()
	_ok("판이 새로 서면 지난 불씨가 안 남는다", g.ember_hits == 0 and not g.ember_out
			and g.ember_puff.is_empty() and g.leg_throws == 0)
	_roll_at(1, 3)
	g._ember_light(4, "t")
	g.total = g.target
	g._finish_leg()
	_ok("판이 끝나면 사라진다", g.ember_idx < 0 and g.leg_ev == "", "state %d" % g.state)
	#  판 중에 로비로 나가면 걷힌다 — 불씨 그림이 제목 판에 안 남는다(2026-10-06).
	_roll_at(1, 3)
	g._ember_light(4, "t")
	g.state = g.S.PICK
	g._pause_open()
	g._to_lobby()
	_ok("로비로 나가면 사라진다", g.ember_idx < 0 and g.leg_ev == "" and g.ember_puff.is_empty(),
			"state %d · 칸 %d" % [g.state, g.ember_idx])

	# ── ⑮ 되살리기 ───────────────────────────────────
	print("⑮ 되살리기")
	_fresh()
	var sr := -1
	for s in range(1, 3000):
		g.leg_no = 1
		g.run_seed = s
		g.run_rng.seed = s
		g._begin_leg()
		g._swap_skip()
		if g.leg_ev == "ember" and g.ember_k == 0:
			sr = s
			break
	_ok("첫 발 전에 핀 불씨 판을 찾았다", sr > 0, "씨앗 %d" % sr)
	if sr > 0:
		var want := _tuple()
		g.target = 99999999
		_throw(g.ember_idx, "out")          # 판을 던지다 끈 척 — 불씨가 꺼진다
		_settle()
		_ok("던진 뒤 불씨가 꺼졌다", g.ember_idx < 0)
		_ok("되살아난다", g._run_load())
		g._swap_skip()
		_ok("판 첫머리에서 같은 사건 · 같은 칸이다", _tuple() == want,
				"%s ← %s" % [str(_tuple()), str(want)])

	# ── ⑯ 주문 · 단골 ────────────────────────────────
	#  주문 · 단골은 제 갈래가 섰다(2026-10-06 · qa_order · qa_regular 가 잰다) — 여기서는
	#  불씨가 안 서는지와 제 사건이 걸렸는지만 본다.
	print("⑯ 주문 · 단골")
	_fresh()
	for kd in ["order", "regular"]:
		var sk := -1
		for s in range(1, 3000):
			_roll_at(1, s)
			if g.leg_ev == kd:
				sk = s
				break
		_throw(3, "t")
		var kq := _kinds(g.queue)
		if kd == "order":
			_ok("order 판 — 불씨가 없다 · 주문이 걸렸다", sk > 0 and g.ember_idx < 0
					and not kq.has("ember") and g.order_cond != "", "씨앗 %d · %s" % [sk, str(kq)])
		else:
			#  단골은 들어오는 때(1~3 번째 발 정산 뒤)까지 기다린다 — 첫 발의 큐에는 걸음이 없다.
			_ok("regular 판 — 불씨가 없다 · 단골이 기다린다", sk > 0 and g.ember_idx < 0
					and not kq.has("ember") and not kq.has(kd) and g.rgl_st == "wait"
					and g.rgl_k >= 1, "씨앗 %d · %s" % [sk, str(kq)])
		_settle()

	# ── ⑰ 개발자 판 ──────────────────────────────────
	print("⑰ 개발자 판")
	var pg0 := Dev.page
	var row := {}
	var rows_n := 0
	for pg in Dev.PAGES.size():
		Dev.page = pg
		for rw in Dev._rows(g):
			if String((rw as Dictionary).get("n1", "")) == "불씨 피우기":
				row = rw
				rows_n = Dev._rows(g).size()
	_ok("「불씨 피우기」 줄이 있다", not row.is_empty())
	_ok("그 쪽이 열아홉 줄 안이다", rows_n <= 19 and rows_n > 0, "%d줄" % rows_n)
	_roll_at(1, 3)
	g.ember_idx = -1
	g.leg_ev = ""
	var gl0: int = g.gold
	var tg0: int = g.target
	var rng0: int = g.run_rng.state
	Dev._run(g, row)
	_ok("누르면 지금 판에 곧장 핀다", g.ember_idx >= 0 and g.ember_idx < g._sec_n()
			and ["t", "d", "s"].has(g.ember_band) and g.leg_ev == "ember",
			"칸 %d · 띠 %s" % [g.ember_idx, g.ember_band])
	_ok("골드 · 목표 · run_rng 를 안 건드린다", g.gold == gl0 and g.target == tg0
			and g.run_rng.state == rng0)
	_throw(g.ember_idx, g.ember_band)
	_ok("개발자 불씨도 게임과 같이 맞는다", _kinds(g.queue).has("ember"))
	_settle()
	g._open_shop()
	var sh_idx: int = g.ember_idx
	Dev._run(g, row)
	_ok("판 밖에서는 아무 일이 없다", g.ember_idx == sh_idx)
	Dev.page = pg0

	# ── ⑱ 그림 ───────────────────────────────────────
	print("⑱ 그림")
	_roll_at(1, 3)
	g._ember_light(2, "d")
	g.motion_off = true
	var f_off := []
	for tt in [0.0, 0.2, 0.4, 0.7, 1.3]:
		g.ember_t = float(tt)
		f_off.append(g._ember_flick())
	g.motion_off = false
	var f_on := {}
	for tt in [0.0, 0.2, 0.4, 0.7, 1.3, 2.1]:
		g.ember_t = float(tt)
		f_on[snappedf(g._ember_flick(), 0.001)] = true
	_ok("모션 끄기면 일렁이지 않는다", f_off.count(1.0) == f_off.size(), str(f_off))
	_ok("모션 켜면 일렁인다", f_on.size() >= 3, str(f_on.keys()))
	var src := FileAccess.get_file_as_string("res://scripts/game.gd")
	var i0: int = src.find("func _ember_col")
	var i1: int = src.find("func _board_dim_sector", i0)
	var body: String = src.substr(i0, i1 - i0)
	_ok("그리는 자가 글을 한 자도 안 띄운다", i0 > 0 and i1 > i0
			and body.find("draw_string") < 0 and body.find("pop(") < 0)
	_ok("새 색을 안 만든다", body.find("Color(\"") < 0 and body.find("Color.from") < 0)
	_ok("난수를 안 굴린다", body.find("randf") < 0 and body.find("randi") < 0
			and body.find("run_rng") < 0)
