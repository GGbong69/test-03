extends SceneTree

# 판 사건 · 단골 검사 (2026-10-06).
#   사용자: 「지금 게임에 너무 갑작스러운 도전성이 없는거 같아 변수가 없으니 하면
#   할수록 좀 재미가 적어지거든?」 — 고른 셋 중 셋째. k 번째 발 정산 뒤 단골 자루가 옆에서
#   날아와 내가 방금 점수를 낸 칸 · 띠에 꽂혀 그 띠 한 칸을 막는다(0점). 그 자루를 맞히면
#   떨어지고 「단골」 걸음이 그 칸의 값을 얹는다. 두 발 뒤에 뽑아 간다.
#   못 박는 것:
#     ① 표 — regular 줄 · 반지름 9 · 뽑아 가기 2 · 검증기 오류 0
#     ② 뽑기 — 같은 씨앗이면 같은 때 · 같은 씨앗 · run_rng 를 늘 같은 두 번(+ 사건 한 번) ·
#        전역 난수에 안 흔들린다 · 때 1 · 2 · 3 이 다 나온다 · 몫이 2/9 둘레
#     ③ 들어오는 때 — k 번째 발 정산 뒤 · 다음 고르기 전 · 그 앞 발에는 없다 · 빗나간 발이면
#        다음 점수 낸 발로 미룬다 · 판이 그 발에 끝나면 안 선다 · 걸음 길이 · 발 셈 한 번
#     ④ 자리 — 그 칸 · 그 띠 안 · 꽂힌 자루와 gap 넘게 · 같은 씨앗 · 같은 자루면 같은 자리
#     ⑤ 막힘 — 판 위 모든 점이 「그 칸 · 그 띠」와 같다 · 던진 발이 0점 · 같은 칸 다른 띠 ·
#        옆 칸은 산다
#     ⑥ 가로채기 — 반지름 안 · 밖 경계 · 「단골」 걸음 값 = 칸 값 × 띠 배수 · 걸음 자리(동전 ·
#        주문 뒤 · 저울 · 모음 · 합계 앞) · _pace · 막힘이 풀린다 · 뽑아 가기가 없다 · 판 밖은 안 친다
#     ⑦ 뽑아 가기 — 두 발 뒤 · 걸음 길이 · 막힘이 풀린다 · 다시 안 들어온다
#     ⑧ 불 — 바깥 불 · 안쪽 불을 반지름으로 막는다 · 불을 가로챈다
#     ⑨ 연발 — 작은 다트도 막힌다 · 가로채기는 한 번 · 연발은 한 발로 센다 · 들어올 자리는 그
#        발의 마지막으로 점수 낸 작은 다트
#     ⑩ 튜토리얼 런 · 보스 판에는 안 선다 · 큰 판에는 선다
#     ⑪ 되살리기(판 매듭) — 같은 단골이 다시 기다린다 · 같은 자리에 던지면 같은 자리
#     ⑫ 그림 — 나는 길(화면 밖 옆에서 꽂힌 자세로 · 내 자루의 식) · 꽂히는 프레임 · 떨어짐 ·
#        빠짐 · 빨리 보기를 탄다 · 모션 끄기 · 참나무 쪽 · 자루 색 · 글자 0 · 새 색 0 · 난수 0
#     ⑬ 개발자 판 「단골 던지기」 — 열아홉 줄 안 · 게임 함수 · 한 판에 사건 하나
#
#   godot --headless --path . --script scripts/tools/qa_regular.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.path = "user://_qa_regular.cfg"
	Save.gpath = "user://_qa_regular_g.cfg"
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
	GameData.challenge = ""
	g._new_run()
	g.tut_run = false
	g.mods_own = mods
	g._board_bake()
	g.owned.clear()
	g.cons.clear()
	g.track_lv = {}
	g.motion_off = false


#  조건 없는 배수 +2 한 장(c01) — 동전 걸음이 하나 선다.
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


#  단골 판 — 들어오는 때가 k 인(−1 이면 아무 때) 첫 씨앗.
func _reg_leg(k := -1) -> int:
	for s in range(1, 4000):
		_roll_at(1, s)
		if g.leg_ev == "regular" and (k < 0 or g.rgl_k == k):
			return s
	return -1


#  사건 없는 판 하나 — 단골은 이 위에 손으로 들인다.
func _plain() -> void:
	_roll_at(1, 3)
	g._ev_clear()


#  칸 i · 띠 한가운데. 게임의 자리 함수를 안 빌린다. "bo" 바깥 불 · "bi" 안쪽 불(가운데).
func _aim(i: int, band: String, da := 0.0) -> Vector2:
	var a: float = (float(i) + da) * g._sec_w()
	var r := 0.0
	match band:
		"t": r = g.R * (g.rt_trp_in + g.rt_trp_out) * 0.5
		"d": r = g.R * (g.rt_dbl_in + g.rt_dbl_out) * 0.5
		"s": r = g.R * (g.rt_trp_out + g.rt_dbl_in) * 0.5
		"si": r = g.R * (g.rt_bull_o + g.rt_trp_in) * 0.5
		"bo": r = g.R * (g.rt_bull_i + g.rt_bull_o) * 0.5
		"bi": r = 0.0
		"out": r = g.R * 1.4
	return g.BC + Vector2(sin(a), -cos(a)) * r


#  던진다 — 화면에 꽂고(게임의 _land 가 mark 에서 하듯) 정산 큐를 세운다.
func _throw(p: Vector2, mark := true) -> void:
	g.aim = p
	g._land(mark)


#  한 발의 정산을 끝까지 판다(단골의 들어오기 · 뽑아 가기 걸음까지). 지나간 걸음 이름과
#  걸음마다 선 qt 를 돌려준다.
var step_qt := {}
func _settle() -> Array:
	var seen := []
	var guard := 0
	while g.state == g.S.RESOLVE and guard < 600:
		var nk := ""
		if not (g.queue as Array).is_empty():
			nk = String((g.queue[0] as Dictionary).get("k", ""))
			seen.append(nk)
		g._next_step()
		if nk != "":
			step_qt[nk] = g.qt
		guard += 1
	return seen


#  연발 한 발 — 작은 다트 여럿이 전부 mark=false 로 내려앉는다. 게임에서는 쏘는 동안
#  화면에 꽂으므로(_kick_fire) 여기서도 darts 에 먼저 꽂는다.
func _burst(spots: Array) -> Array:
	for p in spots:
		g.darts.append({"p": p, "id": "std", "rot": 0.0})
	g.burst_hits = spots.duplicate()
	g.burst_n = spots.size()
	g.aim = g.burst_hits.pop_front()
	g._land(false)
	return _settle()


func _kinds(q: Array) -> Array:
	var out := []
	for st in q:
		out.append(String((st as Dictionary).get("k", "")))
	return out


#  큐의 첫 chip 걸음 값 — 이 발이 판에서 낸 칸 값(막혔으면 0).
func _chip0() -> int:
	for st in g.queue:
		if String((st as Dictionary).get("k", "")) == "chip":
			return int(st.v)
	return -1


#  들인다 — 개발자 판과 같은 길(_rgl_at · _rgl_open · _rgl_in). 나는 시간 0 이면 곧장 꽂힌다.
func _enter(p: Vector2, u := 1) -> void:
	g._rgl_open(g._rgl_at(p), u)
	g._rgl_in(0.0)


#  막힌 띠 한 칸 안에서 단골 자루와 반지름보다 먼 점 하나(없으면 INF).
func _far_in_cell(rr: RandomNumberGenerator) -> Vector2:
	for k in 6000:
		var ang := rr.randf() * TAU
		var rad: float = sqrt(rr.randf()) * g.R
		var p: Vector2 = g.BC + Vector2(cos(ang), sin(ang)) * rad
		if g._rgl_blocks(g.hit_info(p)) and p.distance_to(g.rgl_p) > g._rgl_rad() + 0.5:
			return p
	return Vector2.INF


#  그 칸 · 그 띠 — hit_info 에서 손으로 짓는다(게임의 _rgl_blocks 를 안 빌린다).
func _truth_block(p: Vector2) -> bool:
	var hi: Dictionary = g.hit_info(p)
	var r := p.distance_to(g.BC)
	if g.rgl_idx >= 0:
		return int(hi.idx) == g.rgl_idx and absf(float(hi.r0) - g.rgl_r.x) < 0.01 \
				and absf(float(hi.r1) - g.rgl_r.y) < 0.01
	if not bool(hi.get("bull", false)):
		return false
	if g.rgl_r.x <= 0.0:
		return r <= g.R * g.rt_bull_i
	return r > g.R * g.rt_bull_i and r <= g.R * g.rt_bull_o


#  화면에 비치는 자리 — 눈 거리 d 의 원근(z 0 면이 1px = 1).
func _proj(o: Vector3) -> Vector2:
	var d: float = g._bd3_eye()
	var s: float = d / maxf(d - o.z, 0.001)
	return Vector2(g.BC.x + o.x * s, g.BC.y - o.y * s)


func _run() -> void:
	print("\n== 판 사건 · 단골 ==")
	var rr := RandomNumberGenerator.new()
	rr.seed = 9191

	# ── ① 표 ─────────────────────────────────────────
	print("① 표")
	var row: Dictionary = GameData.event_of("regular")
	_ok("regular 줄이 있다", not row.is_empty() and GameData.event_w(row) > 0.0)
	_ok("반지름 9 · 뽑아 가기 2", is_equal_approx(float(GameData.event_v(row, "v")), 9.0)
			and int(GameData.event_v(row, "v2")) == 2,
			"v %s · v2 %s" % [str(GameData.event_v(row, "v")), str(GameData.event_v(row, "v2"))])
	var ev_errs := []
	for e in GameData.errors():
		if String(e).begins_with("events"):
			ev_errs.append(e)
	_ok("검증기가 events 에 오류를 안 낸다", ev_errs.is_empty(), str(ev_errs))

	# ── ② 뽑기 ───────────────────────────────────────
	print("② 뽑기")
	_fresh()
	var same := true
	var steps_same := true
	var n_reg := 0
	var ks := {}
	var N := 450
	for s in range(1, N + 1):
		_roll_at(1, s)
		var a := [g.leg_ev, g.rgl_k, g.rgl_u, g.rgl_st]
		var st_a: int = g.run_rng.state
		if g.leg_ev == "regular":
			n_reg += 1
			ks[g.rgl_k] = true
		_roll_at(1, s)
		if [g.leg_ev, g.rgl_k, g.rgl_u, g.rgl_st] != a:
			same = false
		if g.run_rng.state != st_a:
			steps_same = false
	_ok("같은 씨앗 · 같은 판이면 같은 단골", same)
	_ok("run_rng 가 판마다 같은 만큼 간다", steps_same)
	var fr := float(n_reg) / float(N)
	_ok("단골 몫이 2/9 둘레다", fr > 0.14 and fr < 0.31, "%.3f" % fr)
	_ok("들어오는 때 1 · 2 · 3 이 다 나오고 그 밖은 없다", ks.has(1) and ks.has(2) and ks.has(3)
			and ks.size() == 3, str(ks.keys()))
	#  늘 같은 두 번 — 사건 한 번(randf) 뒤에 때 randf · 씨앗 randi.
	var two := 0
	var two_bad := 0
	for x0 in range(1, 600):
		g.run_rng.seed = x0 * 7919
		g._ev_roll()
		if g.leg_ev != "regular":
			continue
		var ref := RandomNumberGenerator.new()
		ref.seed = x0 * 7919
		ref.randf()
		ref.randf()
		ref.randi()
		two += 1
		if ref.state != g.run_rng.state:
			two_bad += 1
	_ok("단골 판은 run_rng 를 늘 같은 두 번(+ 사건 한 번) 민다", two > 20 and two_bad == 0,
			"%d판 · 어긋남 %d" % [two, two_bad])
	var s77 := _reg_leg()
	var b77 := [g.leg_ev, g.rgl_k, g.rgl_u]
	for i in 13:
		randi()
	_roll_at(1, s77)
	_ok("전역 난수가 밀려도 같다", [g.leg_ev, g.rgl_k, g.rgl_u] == b77, str(b77))
	_ok("판이 열리면 기다린다 · 막힘 · 그림이 없다", g.rgl_st == "wait" and g.rgl_ph == ""
			and g.rgl_pa == 0.0 and not g._rgl_blocks(g.hit_info(_aim(0, "t"))))

	# ── ③ 들어오는 때 ─────────────────────────────────
	print("③ 들어오는 때")
	_fresh()
	var sk2 := _reg_leg(2)
	_ok("때가 2 인 단골 판을 찾았다", sk2 > 0, "씨앗 %d" % sk2)
	var i20: int = g.sectors.find(20)
	var i19: int = g.sectors.find(19)
	var i3: int = g.sectors.find(3)
	_throw(_aim(i20, "t"))
	var s1 := _settle()
	_ok("첫 발 뒤에는 안 들어온다", not s1.has("reg_in") and g.rgl_st == "wait", str(s1))
	_throw(_aim(i19, "t"))
	var s2 := _settle()
	var tot_at := s2.rfind("total")
	_ok("둘째 발 정산이 다 끝난 뒤 「단골」 들어오는 걸음", s2.count("reg_in") == 1
			and s2.find("reg_in") > tot_at and s2[s2.size() - 1] == "reg_in", str(s2))
	_ok("걸음 뒤 고르기 · 발 셈은 한 번", g.state != g.S.RESOLVE and g.leg_throws == 2
			and not g.ev_tail, "state %d · 발 %d" % [g.state, g.leg_throws])
	_ok("들어오는 걸음은 REGULAR.in_b 박", absf(float(step_qt.get("reg_in", -1.0))
			- g.beat * float(g.REGULAR.in_b)) < 0.0001, "%.3f" % float(step_qt.get("reg_in", -1.0)))
	_ok("꽂혀 막는다 — 방금 점수 낸 칸 · 띠", g.rgl_st == "on" and g.rgl_idx == i19
			and g.rgl_r.is_equal_approx(Vector2(g.R * g.rt_trp_in, g.R * g.rt_trp_out)),
			"칸 %d · 띠 %s" % [g.rgl_idx, str(g.rgl_r)])
	_ok("값 = 칸 값 × 띠 배수(트리플 19 → 57)", g.rgl_val == 19 * g.rt_m_trp, str(g.rgl_val))
	_ok("뽑아 가기까지 두 발", g.rgl_left == 2)
	#  들어오는 걸음은 정산 중(RESOLVE)에 선다 — 빨리 보기가 거기서만 선다.
	_fresh()
	_reg_leg(1)
	_throw(_aim(i20, "t"))
	var st_in := -1
	var tail_ok := false
	while g.state == g.S.RESOLVE:
		var nk := "" if g.queue.is_empty() else String(g.queue[0].k)
		g._next_step()
		if nk == "reg_in":
			st_in = g.state
			tail_ok = g.ev_tail and g.card_target == 0.0
	_ok("들어오는 걸음 동안 정산 상태 · 카드는 물러났다", st_in == g.S.RESOLVE and tail_ok)
	#  빗나간 발이면 다음 점수 낸 발로 미룬다
	_fresh()
	_reg_leg(1)
	_throw(_aim(i20, "out"))
	var m1 := _settle()
	_ok("때가 왔어도 빗나간 발이면 안 들어온다", not m1.has("reg_in") and g.rgl_st == "wait",
			str(m1))
	_throw(_aim(i3, "d"))
	var m2 := _settle()
	_ok("다음 점수 낸 발 뒤에 그 칸 · 띠로 들어온다", m2.has("reg_in") and g.rgl_idx == i3
			and g.rgl_r.is_equal_approx(Vector2(g.R * g.rt_dbl_in, g.R * g.rt_dbl_out)), str(m2))
	#  판이 그 발에 끝나면 안 선다
	_fresh()
	_reg_leg(1)
	g.total = 0
	g.target = 1
	_throw(_aim(i20, "t"))
	var e1 := _settle()
	_ok("판이 그 발에 끝나면 안 들어오고 걷힌다", not e1.has("reg_in") and g.rgl_st == ""
			and g.leg_ev == "" and g.rgl_ph == "", "%s · state %d" % [str(e1), g.state])

	# ── ④ 자리 ───────────────────────────────────────
	print("④ 자리")
	_fresh()
	_plain()
	var spot_bad := 0
	var gap_bad := 0
	var det_bad := 0
	var spots := {}
	var n_sp := 0
	for band in ["t", "d", "s", "si"]:
		for i in [0, 4, 9, 13, 19]:
			for u in [1, 77, 4242]:
				g.darts.clear()
				var pp := _aim(i, band, rr.randf_range(-0.3, 0.3))
				g.darts.append({"p": pp, "id": "std", "rot": 0.0})
				var tg: Dictionary = g._rgl_at(pp)
				var q: Vector2 = g._rgl_spot(int(tg.idx), tg.band, u)
				n_sp += 1
				var hq: Dictionary = g.hit_info(q)
				if int(hq.idx) != int(tg.idx) or not g._rgl_band(hq).is_equal_approx(tg.band):
					spot_bad += 1
				if q.distance_to(pp) < float(g.REGULAR.gap):
					gap_bad += 1
				if g._rgl_spot(int(tg.idx), tg.band, u) != q:
					det_bad += 1
				if band == "d" and i == 0:
					spots[q] = true
	_ok("자리 %d개가 다 그 칸 · 그 띠 안이다" % n_sp, spot_bad == 0, "어긋남 %d" % spot_bad)
	_ok("꽂힌 자루와 gap(5px) 넘게 비킨다", gap_bad == 0, "가까움 %d" % gap_bad)
	_ok("같은 씨앗 · 같은 자루면 같은 자리", det_bad == 0)
	_ok("씨앗이 다르면 자리가 갈린다", spots.size() >= 2, "%d곳" % spots.size())
	#  꽂힌 자루가 여럿이면 다 피한다
	g.darts.clear()
	var pa := _aim(i20, "d", -0.15)
	var pb := _aim(i20, "d", 0.15)
	g.darts.append({"p": pa, "id": "std", "rot": 0.0})
	g.darts.append({"p": pb, "id": "std", "rot": 0.0})
	var q2: Vector2 = g._rgl_spot(i20, Vector2(g.R * g.rt_dbl_in, g.R * g.rt_dbl_out), 3)
	_ok("꽂힌 자루 둘을 다 피한다", q2.distance_to(pa) >= 5.0 and q2.distance_to(pb) >= 5.0,
			"%.1f · %.1f" % [q2.distance_to(pa), q2.distance_to(pb)])

	# ── ⑤ 막힘 ───────────────────────────────────────
	print("⑤ 막힘")
	for mods in [[], ["pizz"], ["arst"], ["dnut"]]:
		_fresh(mods)
		_plain()
		var bad := 0
		var nin := 0
		var cases := 0
		for cell in [[0, "t"], [7, "d"], [12, "s"], [3, "si"], [0, "bo"], [0, "bi"]]:
			var pp2 := _aim(int(cell[0]) % g._sec_n(), String(cell[1]))
			var hi2: Dictionary = g.hit_info(pp2)
			if int(hi2.mult) <= 0:
				continue
			g.darts.clear()
			g.darts.append({"p": pp2, "id": "std", "rot": 0.0})
			_enter(pp2)
			cases += 1
			for k in 1200:
				var ang := rr.randf() * TAU
				var rad: float = sqrt(rr.randf()) * g.R * 1.05
				var p: Vector2 = g.BC + Vector2(cos(ang), sin(ang)) * rad
				var want := _truth_block(p)
				if want != g._rgl_blocks(g.hit_info(p)):
					bad += 1
				if want:
					nin += 1
		_ok("%s 판 — 막힌 자리가 그 칸 · 그 띠와 같다" % (str(mods) if not mods.is_empty() else "기본"),
				bad == 0 and nin > 0 and cases >= 4, "어긋남 %d · 안 %d · %d곳" % [bad, nin, cases])
	_fresh()
	_plain()
	g.darts.clear()
	_enter(_aim(i20, "d"), 5)
	var far := _far_in_cell(rr)
	_ok("막힌 칸 안에서 단골 자루와 먼 점이 있다", far.is_finite())
	_throw(far)
	_ok("막힌 띠 한 칸에 꽂으면 0점 · 가로채기 아님", _chip0() == 0
			and not _kinds(g.queue).has("regular") and g.rgl_st == "on", str(_kinds(g.queue)))
	_settle()
	_throw(_aim(i20, "t"))
	_ok("같은 칸 다른 띠(트리플)는 산다", _chip0() == 20, str(_chip0()))
	_settle()
	_enter(_aim(i20, "d"), 5)
	var i1: int = g.sectors.find(1)
	var adj: bool = absi(i1 - i20) == 1 or absi(i1 - i20) == g._sec_n() - 1
	var nb: int = i1 if adj else (i20 + 1) % g._sec_n()
	_throw(_aim(nb, "d"))
	_ok("옆 칸 같은 띠(더블)는 산다", _chip0() == int(g.sectors[nb]), "%d · 칸 %d" % [_chip0(),
			int(g.sectors[nb])])
	_settle()

	# ── ⑥ 가로채기 ───────────────────────────────────
	print("⑥ 가로채기")
	_fresh()
	_give_c01()
	_plain()
	var d20 := _aim(i20, "d")
	g.darts = [{"p": d20, "id": "std", "rot": 0.0}]
	_enter(d20, 5)
	var rad: float = g._rgl_rad()
	var rp: Vector2 = g.rgl_p
	var inward: Vector2 = (g.BC - rp).normalized()
	var p_in: Vector2 = rp + inward * (rad - 0.3)
	var p_out: Vector2 = rp + inward * (rad + 0.3)
	_throw(p_out)
	_ok("반지름 밖(+0.3px)은 안 떨어진다", not _kinds(g.queue).has("regular") and g.rgl_st == "on")
	_settle()
	g.darts = [{"p": d20, "id": "std", "rot": 0.0}]
	_enter(d20, 5)
	_ok("같은 자루 · 같은 씨앗이면 같은 자리로 다시 든다", g.rgl_p == rp)
	_throw(p_in)
	var kq := _kinds(g.queue)
	_ok("반지름 안(−0.3px)이면 떨어진다 — 「단골」 걸음 하나", kq.count("regular") == 1
			and g.rgl_st == "hit" and g.rgl_ph == "fall", str(kq))
	var ri := kq.find("regular")
	_ok("동전 걸음 뒤 · 모음 · 합계 앞", ri > kq.rfind("item") and kq.rfind("item") >= 0
			and ri < kq.find("wind") and ri < kq.find("total"), str(kq))
	var chip_d := -1
	var pace_ok := false
	var pops_ok := false
	while not g.queue.is_empty():
		var nk := String((g.queue[0] as Dictionary).get("k", ""))
		var c0: int = g.cur_chip
		if nk == "regular":
			g.pops.clear()
		g._next_step()
		if nk == "regular":
			chip_d = g.cur_chip - c0
			pace_ok = absf(g.qt - g.beat * g._pace()) < 0.0001
			pops_ok = g.pops.size() == 1 and String(g.pops[0].txt) == "+%d" % (20 * g.rt_m_dbl)
	_ok("「단골」 걸음이 칸 값 × 띠 배수(더블 20 → 40)를 점수 칸에", chip_d == 20 * g.rt_m_dbl,
			"%+d" % chip_d)
	_ok("글은 「+40」 하나", pops_ok)
	_ok("「단골」 걸음이 _pace 를 탄다", pace_ok)
	_ok("막힘이 풀렸다", g.rgl_st == "done" and not g._rgl_blocks(g.hit_info(rp)))
	_settle()
	var post := []
	for k in 3:
		_throw(_aim(i20, "d"))
		post += _settle()
	_ok("떨어뜨린 뒤 막힘 · 뽑아 가기 · 다시 들어오기가 없다", not post.has("reg_out")
			and not post.has("reg_in") and not post.has("regular") and g.rgl_st == "done", str(post))
	#  판 밖(빗나감)은 반지름 안이어도 안 친다
	_enter(_aim(i20, "d"), 5)
	var outw: Vector2 = (g.rgl_p - g.BC).normalized()
	var p_miss: Vector2 = g.BC + outw * (g.R * g.rt_dbl_out + 0.6)
	var dm: float = p_miss.distance_to(g.rgl_p)
	_throw(p_miss)
	_ok("판 밖은 반지름 안(%.1fpx)이어도 안 친다" % dm, dm <= rad
			and not _kinds(g.queue).has("regular") and g.rgl_st == "on")
	_settle()
	#  주문 · 저울과의 차례 — 주문 뒤 · 저울 앞
	_plain()
	g.darts.clear()
	_enter(_aim(i20, "t"), 5)
	g.order_st = "open"
	g.order_cond = "triple"
	g.order_n = 3
	g.order_left = 3
	g.order_tag = {"id": "t_gold", "kind": "gold", "v": "6"}
	g.score_mode = "bal"
	_throw(g.rgl_p)
	var kb := _kinds(g.queue)
	_ok("주문 뒤 · 저울 앞", kb.find("order") >= 0 and kb.find("order") < kb.find("regular")
			and kb.find("regular") < kb.find("bal"), str(kb))
	g.score_mode = "std"
	g.queue.clear()
	g.state = g.S.PICK
	g._order_clear()

	# ── ⑦ 뽑아 가기 ──────────────────────────────────
	print("⑦ 뽑아 가기")
	_fresh()
	_reg_leg(1)
	_throw(_aim(i20, "t"))
	_settle()
	var bp: Vector2 = g.rgl_p
	_ok("들어왔다", g.rgl_st == "on")
	_throw(_aim(i3, "s"))
	var o1 := _settle()
	_ok("한 발 더 — 아직 꽂혀 있다", not o1.has("reg_out") and g.rgl_st == "on"
			and g.rgl_left == 1, str(o1))
	_throw(_aim(i3, "s"))
	var o2 := _settle()
	_ok("두 발 더 — 정산 뒤 「단골」 뽑아 가는 걸음", o2[o2.size() - 1] == "reg_out"
			and o2.count("reg_out") == 1 and o2.rfind("total") < o2.find("reg_out"), str(o2))
	_ok("뽑아 가는 걸음은 REGULAR.out_b 박", absf(float(step_qt.get("reg_out", -1.0))
			- g.beat * float(g.REGULAR.out_b)) < 0.0001)
	_ok("막힘이 풀렸다 · 자루가 빠져나간다", g.rgl_st == "done" and g.rgl_ph == "out"
			and not g._rgl_blocks(g.hit_info(bp)))
	_throw(bp)
	_ok("빠진 자리에 꽂으면 산다 · 가로채기 없음", _chip0() == 20
			and not _kinds(g.queue).has("regular"), str(_chip0()))
	var o3 := _settle()
	for k in 3:
		_throw(_aim(i20, "t"))
		o3 += _settle()
	_ok("다시 안 들어온다", not o3.has("reg_in") and not o3.has("reg_out"), str(o3))

	# ── ⑧ 불 ─────────────────────────────────────────
	print("⑧ 불")
	_fresh()
	_plain()
	g.darts.clear()
	var bo_p := _aim(0, "bo")
	g.darts.append({"p": bo_p, "id": "std", "rot": 0.0})
	_enter(bo_p, 2)
	_ok("바깥 불 — 칸 없이 반지름 [안쪽 불, 바깥 불]", g.rgl_idx == -1
			and g.rgl_r.is_equal_approx(Vector2(g.R * g.rt_bull_i, g.R * g.rt_bull_o))
			and g.rgl_val == int(GameData.area("bull_o").base) * g.rt_m_bull, "%s · 값 %d" % [
			str(g.rgl_r), g.rgl_val])
	var opp: Vector2 = g.BC + (g.BC - g.rgl_p).normalized() * g.R * (g.rt_bull_i + g.rt_bull_o) * 0.5
	_throw(opp)
	_ok("반대쪽 바깥 불은 막힌다(0점)", _chip0() == 0 and not _kinds(g.queue).has("regular"),
			"%d · %.1fpx" % [_chip0(), opp.distance_to(g.rgl_p)])
	_settle()
	var inner: Vector2 = g.BC + (g.BC - g.rgl_p).normalized() * g.R * g.rt_bull_i * 0.6
	var din: float = inner.distance_to(g.rgl_p)
	_throw(inner)
	var chip_in := _chip0()
	var kin := _kinds(g.queue)
	_ok("안쪽 불은 산다(단골 자루와 반지름 밖)", chip_in == int(GameData.area("bull_i").base)
			and not kin.has("regular") and din > g._rgl_rad(), "%d · %.1fpx" % [chip_in, din])
	_settle()
	g.darts.clear()
	var bi_p := _aim(0, "bi")
	g.darts.append({"p": bi_p, "id": "std", "rot": 0.0})
	_enter(bi_p, 2)
	_ok("안쪽 불 — 반지름 [0, 안쪽 불]", g.rgl_idx == -1
			and g.rgl_r.is_equal_approx(Vector2(0.0, g.R * g.rt_bull_i))
			and g.rgl_val == int(GameData.area("bull_i").base) * g.rt_m_bull, str(g.rgl_r))
	var bo_far: Vector2 = g.BC + (g.BC - g.rgl_p).normalized() * g.R * (g.rt_bull_i + g.rt_bull_o) * 0.5
	_throw(bo_far)
	_ok("바깥 불은 산다", _chip0() == int(GameData.area("bull_o").base)
			and not _kinds(g.queue).has("regular"), "%.1fpx" % bo_far.distance_to(g.rgl_p))
	_settle()
	_throw(g.rgl_p)
	var kbull := _kinds(g.queue)
	_ok("불 가로채기 — 막힌 안쪽 불에 꽂아 0점 · 「단골」 걸음 하나", _chip0() == 0
			and kbull.count("regular") == 1, str(kbull))
	var cb0 := -1
	while not g.queue.is_empty():
		var nk := String((g.queue[0] as Dictionary).get("k", ""))
		var c1: int = g.cur_chip
		g._next_step()
		if nk == "regular":
			cb0 = g.cur_chip - c1
	_ok("값은 안쪽 불 50", cb0 == int(GameData.area("bull_i").base) * g.rt_m_bull, "%+d" % cb0)
	_settle()

	# ── ⑨ 연발 ───────────────────────────────────────
	print("⑨ 연발")
	_fresh()
	_plain()
	g.darts.clear()
	g.darts.append({"p": _aim(i20, "d"), "id": "std", "rot": 0.0})
	_enter(_aim(i20, "d"), 5)
	var bfar := _far_in_cell(rr)
	var near1: Vector2 = g.rgl_p + (g.BC - g.rgl_p).normalized() * 2.0
	var near2: Vector2 = g.rgl_p + (g.BC - g.rgl_p).normalized() * 4.0
	var th0: int = g.leg_throws
	var chips := []
	g.burst_hits = [near1, near2, _aim(i3, "t")]
	g.burst_n = 4
	g.aim = bfar
	g._land(false)
	chips.append(_chip0())
	var bseen := []
	var guard := 0
	while g.state == g.S.RESOLVE and guard < 300:
		if not g.queue.is_empty():
			bseen.append(String(g.queue[0].k))
		var was_empty: bool = g.queue.is_empty()
		g._next_step()
		if was_empty and g.state == g.S.RESOLVE and not g.queue.is_empty():
			chips.append(_chip0())
		guard += 1
	_ok("작은 다트도 막힌 띠 한 칸에 0점", int(chips[0]) == 0, str(chips))
	_ok("반지름 안 작은 다트 둘 — 가로채기 한 번", bseen.count("regular") == 1, str(bseen))
	_ok("연발은 한 발로 센다", g.leg_throws == th0 + 1, "%d → %d" % [th0, g.leg_throws])
	#  연발 하나가 뽑아 가기 한 발이다
	_enter(_aim(i20, "t"), 9)
	var left0: int = g.rgl_left
	_burst([_aim(i3, "s"), _aim(i3, "si"), _aim(i3, "s", 0.2)])
	_ok("연발 한 발에 뽑아 가기가 하나 준다", g.rgl_left == left0 - 1, "%d → %d" % [left0, g.rgl_left])
	#  들어올 자리는 그 발의 마지막으로 점수 낸 작은 다트
	_fresh()
	_reg_leg(1)
	var bs := _burst([_aim(i20, "t"), _aim(i19, "d"), _aim(i3, "out")])
	_ok("연발 뒤 — 마지막으로 점수 낸 작은 다트(더블 19)로 들어온다", bs.count("reg_in") == 1
			and g.rgl_idx == i19 and g.rgl_r.is_equal_approx(Vector2(g.R * g.rt_dbl_in,
			g.R * g.rt_dbl_out)), "%s · 칸 %d" % [str(bs), g.rgl_idx])

	# ── ⑩ 튜토리얼 · 보스 ───────────────────────────
	print("⑩ 튜토리얼 · 보스")
	_fresh()
	g.tut_run = true
	var tut_reg := 0
	for s in range(1, 200):
		for ln in [1, 2, 3]:
			_roll_at(ln, s)
			if g.leg_ev == "regular" or g.rgl_st != "":
				tut_reg += 1
	g.tut_run = false
	_ok("튜토리얼 런에는 단골이 안 선다", tut_reg == 0, "%d판" % tut_reg)
	var boss_reg := 0
	var boss_n := 0
	for ln in range(1, GameData.legs_n() + 1):
		if not GameData.is_boss(ln):
			continue
		boss_n += 1
		for s in range(1, 60):
			_roll_at(ln, s)
			if g.leg_ev == "regular" or g.rgl_st != "":
				boss_reg += 1
	_ok("보스 판(%d)에는 단골이 안 선다" % boss_n, boss_reg == 0 and boss_n > 0)
	var r2 := 0
	for s in range(1, 300):
		_roll_at(2, s)
		if g.leg_ev == "regular":
			r2 += 1
	_ok("큰 판에도 선다", r2 > 0, "%d판" % r2)

	# ── ⑪ 되살리기 ───────────────────────────────────
	print("⑪ 되살리기")
	_fresh()
	var sr := -1
	for s in range(1, 4000):
		g.leg_no = 1
		g.run_seed = s
		g.run_rng.seed = s
		g._begin_leg()
		g._swap_skip()
		if g.leg_ev == "regular" and g.rgl_k == 1:
			sr = s
			break
	_ok("때가 1 인 단골 판을 찾았다(판 첫머리 매듭)", sr > 0, "씨앗 %d" % sr)
	if sr > 0:
		var want := [g.leg_ev, g.rgl_k, g.rgl_u, g.rgl_st]
		g.target = 99999999
		_throw(_aim(i20, "t"))
		_settle()
		var p_first: Vector2 = g.rgl_p
		_ok("한 발 던져 들어왔다", g.rgl_st == "on")
		_ok("되살아난다", g._run_load())
		g._swap_skip()
		g.target = 99999999
		_ok("판 첫머리에서 같은 단골이 다시 기다린다", [g.leg_ev, g.rgl_k, g.rgl_u, g.rgl_st] == want
				and g.rgl_ph == "" and g.rgl_pa == 0.0 and g.darts.is_empty(),
				"%s ← %s" % [str([g.leg_ev, g.rgl_k, g.rgl_u, g.rgl_st]), str(want)])
		_throw(_aim(i20, "t"))
		_settle()
		_ok("같은 자리에 던지면 같은 자리에 꽂힌다", g.rgl_st == "on"
				and g.rgl_p.is_equal_approx(p_first), "%s ← %s" % [str(g.rgl_p), str(p_first)])

	# ── ⑫ 그림 ───────────────────────────────────────
	print("⑫ 그림")
	_fresh()
	_plain()
	g.darts.clear()
	g.darts.append({"p": _aim(i20, "t"), "id": "std", "rot": 0.0})
	g._rgl_open(g._rgl_at(_aim(i20, "t")), 11)
	var fly: float = g.beat * float(g.REGULAR.in_b) * float(g.REGULAR.in_k)
	g._rgl_in(fly)
	_ok("나는 동안은 참나무 쪽이 없고 막힘은 선다", g.rgl_ph == "in" and g.rgl_st == "on")
	var end: Transform3D = g._bd3_pose({"p": g.rgl_p, "rot": g.rgl_rot})
	var t0: Transform3D = g._rgl_pose()
	var sp0 := _proj(t0.origin)
	_ok("화면 밖 옆에서 출발한다", absf(sp0.x - g.BC.x) > g.VIEW.x * 0.5
			and signf(sp0.x - g.BC.x) == g.rgl_side, "x %.0f · 쪽 %+.0f" % [sp0.x, g.rgl_side])
	var mine: Transform3D = g._bd3_fly_tf(end, t0.origin, 1.0)
	_ok("내 자루와 같은 식으로 날아 꽂힌 자세에 닿는다", mine.origin.is_equal_approx(end.origin)
			and g._bd3_fly_tf(end, Vector3(1, 2, 3), 0.0).origin.is_equal_approx(Vector3(1, 2, 3)))
	g._rgl_tick(fly * 0.5)
	_ok("반쯤 — 아직 난다", g.rgl_ph == "in" and g.rgl_pa == 0.0)
	var tm: Transform3D = g._rgl_pose()
	_ok("반쯤 — 출발점과 꽂힌 자리 사이", tm.origin.distance_to(end.origin) > 1.0
			and tm.origin.distance_to(end.origin) < t0.origin.distance_to(end.origin))
	g._rgl_tick(fly * 0.5 + 0.001)
	_ok("다 날면 꽂힌다(그 프레임)", g.rgl_ph == "on"
			and g._rgl_pose().origin.is_equal_approx(end.origin))
	g._rgl_tick(float(g.REGULAR.plank_t) + 0.01)
	_ok("꽂히면 참나무 쪽이 선다", is_equal_approx(g.rgl_pa, 1.0), "%.2f" % g.rgl_pa)
	_ok("꽂힌 자루는 그림자 · 받침에 든다", g._darts_stuck().size() == g.darts.size() + 1
			and g.darts.size() == 1)
	_throw(g.rgl_p)
	_ok("맞히면 떨어진다", g.rgl_ph == "fall" and g._darts_stuck().size() == g.darts.size())
	g._rgl_tick(float(g.REGULAR.fall_t) * 0.8)
	var tf: Transform3D = g._rgl_pose()
	_ok("떨어지며 내려간다", tf.origin.y < end.origin.y - 20.0, "%.1f" % (end.origin.y - tf.origin.y))
	g._rgl_tick(float(g.REGULAR.fall_t))
	_ok("다 떨어지면 없어진다", g.rgl_ph == "")
	_settle()
	g._rgl_tick(float(g.REGULAR.plank_t) + 0.01)
	_ok("막힘이 풀리면 참나무 쪽이 걷힌다", g.rgl_pa == 0.0)
	#  빠져나가기
	_enter(_aim(i20, "t"), 11)
	var end2: Transform3D = g._bd3_pose({"p": g.rgl_p, "rot": g.rgl_rot})
	g._rgl_out(0.4)
	_ok("뽑아 가면 빠져나간다", g.rgl_ph == "out" and g.rgl_st == "done")
	g._rgl_tick(0.2)
	var to: Transform3D = g._rgl_pose()
	var spo := _proj(to.origin)
	_ok("빠지는 길 — 꽂힌 자리에서 날아온 쪽으로", to.origin.distance_to(end2.origin) > 1.0
			and signf(spo.x - _proj(end2.origin).x) == g.rgl_side)
	g._rgl_tick(0.21)
	_ok("다 빠지면 없어진다", g.rgl_ph == "")
	#  빨리 보기를 탄다 — _process 가 그 배수를 태워 민다(배움 · 일시정지 · 멈춤 없이)
	_enter(_aim(i20, "t"), 11)
	g._rgl_in(10.0)
	g._tutor_close()
	g.tutor_id = ""
	g.tutor_q.clear()
	g.pause_from = -1
	g.state = g.S.RESOLVE
	g.queue = [{"k": "wind"}]
	g.qt = 99.0
	g.hitstop = 0.0
	g.fast_lock = true
	g.fast_mul = 2.5
	var vt0: float = g.rgl_vt
	g._process(0.1)
	var rate: float = g.fast_rate
	g.fast_lock = false
	_ok("빨리 보기면 나는 시계도 그 배로 간다", rate > 1.0
			and absf((g.rgl_vt - vt0) - 0.1 * rate) < 0.0001, "배 %.2f · %.3f" % [rate, g.rgl_vt - vt0])
	g.queue = []
	g.state = g.S.PICK
	#  모션 끄기
	g.motion_off = true
	_enter(_aim(i20, "t"), 11)
	g._rgl_in(0.5)
	_ok("모션 끄기 — 날지 않고 곧장 꽂힌다", g.rgl_ph == "on")
	g._rgl_tick(0.0)
	_ok("모션 끄기 — 참나무 쪽이 곧장 선다", g.rgl_pa == 1.0)
	_throw(g.rgl_p)
	g._rgl_tick(0.016)
	_ok("모션 끄기 — 떨어뜨리면 곧장 없어진다", g.rgl_ph == "")
	_settle()
	g._rgl_tick(0.0)
	_ok("모션 끄기 — 참나무 쪽이 곧장 걷힌다", g.rgl_pa == 0.0)
	g.motion_off = false
	#  색
	var cr: Color = g._dart3_col("reg")
	var others := []
	for id in ["std", "hvy", "lgt", "mag"]:
		others.append(g._dart3_col(id))
	_ok("단골 자루 색은 내 다트 넷과 다르다", not others.has(cr), cr.to_html(false))
	_ok("그 색은 ART_PAL 의 파랑 그대로다", g.DK_PAL["blue"] == g.ART_PAL["blue"])
	#  그리는 자 — 글 · 새 색 · 난수
	var src := FileAccess.get_file_as_string("res://scripts/game.gd")
	var j0: int = src.find("func _rgl_plank")
	var j1: int = src.find("# ── 피자 한 벌 ──", j0)
	var body: String = src.substr(j0, j1 - j0)
	_ok("참나무 쪽 그리는 자가 글을 안 띄운다 · 새 색 0 · 난수 0", j0 > 0 and j1 > j0
			and body.find("draw_string") < 0 and body.find("Color(\"") < 0
			and body.find("randf") < 0 and body.find("randi") < 0)
	var k0: int = src.find("func _rgl_clear")
	var k1: int = src.find("# ══", k0)
	var logic: String = src.substr(k0, k1 - k0)
	var bare := logic.replace("run_rng.randf()", "").replace("run_rng.randi()", "")
	_ok("단골 갈래는 run_rng 말고 난수를 안 굴린다 · 글을 안 띄운다", k0 > 0 and k1 > k0
			and bare.find("randf") < 0 and bare.find("randi") < 0
			and logic.find("draw_string") < 0 and logic.find("pop(") < 0)

	# ── ⑬ 개발자 판 ──────────────────────────────────
	print("⑬ 개발자 판")
	var pg0 := Dev.page
	var drow := {}
	var rows_n := 0
	var erow := {}
	for pg in Dev.PAGES.size():
		Dev.page = pg
		for rw in Dev._rows(g):
			if String((rw as Dictionary).get("n1", "")) == "단골 던지기":
				drow = rw
				rows_n = Dev._rows(g).size()
			if String((rw as Dictionary).get("n1", "")) == "불씨 피우기":
				erow = rw
	_ok("「단골 던지기」 줄이 있다", not drow.is_empty())
	_ok("그 쪽이 열아홉 줄 안이다", rows_n <= 19 and rows_n > 0, "%d줄" % rows_n)
	_fresh()
	_plain()
	_throw(_aim(i19, "d"))
	_settle()
	var gl0: int = g.gold
	var tg0: int = g.target
	var rng0: int = g.run_rng.state
	Dev._run(g, drow)
	_ok("누르면 마지막으로 점수 낸 칸 · 띠에 곧장 날아든다", g.leg_ev == "regular"
			and g.rgl_st == "on" and g.rgl_ph == "in" and g.rgl_idx == i19
			and g.rgl_r.is_equal_approx(Vector2(g.R * g.rt_dbl_in, g.R * g.rt_dbl_out)),
			"칸 %d · %s" % [g.rgl_idx, g.rgl_ph])
	_ok("골드 · 목표 · run_rng 를 안 건드린다", g.gold == gl0 and g.target == tg0
			and g.run_rng.state == rng0)
	_throw(g.rgl_p)
	_ok("개발자 단골도 게임과 같이 떨어뜨린다", _kinds(g.queue).has("regular"))
	_settle()
	_plain()
	Dev._run(g, drow)
	_ok("점수 낸 칸이 없으면 무작위 칸 · 띠", g.rgl_st == "on"
			and g._rgl_blocks(g.hit_info(g.rgl_p)), "칸 %d" % g.rgl_idx)
	Dev._run(g, erow)
	_ok("불씨를 피우면 단골이 걷힌다", g.leg_ev == "ember" and g.rgl_st == "" and g.rgl_ph == ""
			and g.rgl_pa == 0.0 and g.ember_idx >= 0)
	Dev._run(g, drow)
	_ok("단골을 들이면 불씨가 걷힌다", g.leg_ev == "regular" and g.ember_idx < 0 and g.rgl_st == "on")
	g._open_shop()
	var sh_st: String = g.rgl_st
	Dev._run(g, drow)
	_ok("판 밖에서는 아무 일이 없다", g.rgl_st == sh_st)
	Dev.page = pg0
