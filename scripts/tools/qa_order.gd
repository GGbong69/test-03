extends SceneTree

# 판 사건 · 칠판 주문 검사 (2026-10-06).
#   사용자: 「지금 게임에 너무 갑작스러운 도전성이 없는거 같아 변수가 없으니 하면
#   할수록 좀 재미가 적어지거든?」 — 고른 셋 중 둘째. 판 옆 칠판에 분필 눈금(남은 발)과
#   보상 그림, 판 위 영역 하나가 분필빛. 눈금 안에 그 영역에 꽂으면 보상 한 장.
#   못 박는 것:
#     ① 표 — order 줄 · 눈금 2~3 · 검증기 오류 0 · 보상 줄이 tags.csv 의 when=now 다
#     ② 뽑기가 run_rng 하나로 같은 판을 다시 낸다 · 전역 난수에 안 흔들린다 · 여섯 번 민다
#     ③ 영역 조각이 판 위 모든 점에서 GameData.check 와 같다(영역 아홉 · 칸 여럿 · 판 일곱)
#     ④ 실제로 던진 발도 같다 — 다트 특성 · 트랙 강화가 배수를 바꿔도 판이 그린 그대로다
#     ⑤ 그릴 수 없는 영역은 안 뽑힌다(피자의 띠 · 도넛의 불)
#     ⑥ 눈금 — 던질 때마다 하나 · 연발은 한 발에 하나
#     ⑦ 채우면 「주문」 걸음 하나 → 보상 한 장 · 자리 · 연발 여럿이 꽂혀도 하나 · 그 뒤는 없다
#     ⑧ 눈금이 다 하면 X — 보상 없음 · 그 뒤 영역에 꽂아도 없다
#     ⑨ 판 끝 — 목표를 넘는 발에 채우면 판이 끝나기 전에 받는다 · 끝난 뒤에는 아무것도 안 준다
#     ⑩ 튜토리얼 런 · 보스 판에는 안 선다
#     ⑪ 보상 안의 뽑기가 씨앗 줄기다 · 빈손은 골드 보상이 없다 · 꽉 찬 칸의 보상은 빠진다
#     ⑫ 팝 — 칠판 위에 값만 선다(뱃지 이름 줄 없음) · 골드는 자금판 밑
#     ⑬ 칠판 자리 — 판 · HUD · 동전 · 사탕 칸 · 카드 두 자리 · 자루 걸이 · 조준 가로선 ·
#        안내 줄 · 목표 달성과 안 겹친다 · 판 갈이 · 판 밖 화면에서는 안 선다
#     ⑭ 되살리기(판 매듭)가 같은 주문을 다시 낸다
#     ⑮ 개발자 판 「주문 걸기」 — 열아홉 줄 안 · 게임 함수 · 한 판에 사건 하나
#     ⑯ 그림 — 글자 0 · 새 색 0 · 난수 0 · 모션 끄기면 숨을 안 쉰다 · 테두리 그늘은 영역 밖에만 ·
#        아홉 영역 다 영역이 나머지보다 밝다(헤드리스 대용 셈 — 그린 조각 · 판 색 · 판 빛 · 숨 바닥)
#
#   godot --headless --path . --script scripts/tools/qa_order.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.path = "user://_qa_order.cfg"
	Save.gpath = "user://_qa_order_g.cfg"
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
	g.tag_copy = 0


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


#  사건 없는 판 하나 — 주문은 이 위에 손으로 건다.
func _plain() -> void:
	_roll_at(1, 3)
	g._ev_clear()


#  줄 동전이 있는 판(둘째 판)의 사건 없는 판 — 첫 판은 「견본」이 안 뽑힌다(rarity min_leg).
func _plain2() -> void:
	_roll_at(2, 3)
	g._ev_clear()


func _tag(id: String) -> Dictionary:
	for r in GameData.tags():
		if String(r.get("id", "")) == id:
			return r
	return {}


func _tuple() -> Array:
	return [g.leg_ev, g.order_cond, g.order_n, String(g.order_tag.get("id", "")), g.order_u]


#  칸 i · 띠 한가운데. 게임의 자리 함수를 안 빌린다.
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


func _throw(p: Vector2, mark := true) -> void:
	g.aim = p
	g._land(mark)


#  한 발의 정산을 끝까지 판다. 큐가 빈 뒤 한 번 더 — 그 자리가 「한 발이 끝났다」다.
#  지나간 걸음 이름을 돌려준다(연발이면 작은 다트 여럿의 걸음이 다 든다).
func _settle() -> Array:
	var seen := []
	var guard := 0
	while g.state == g.S.RESOLVE and guard < 600:
		if not (g.queue as Array).is_empty():
			seen.append(String((g.queue[0] as Dictionary).get("k", "")))
		g._next_step()
		guard += 1
	return seen


#  연발 한 발 — 작은 다트 여럿이 전부 mark=false 로 내려앉는다(게임의 S.FLY · _next_step 길).
func _burst(spots: Array) -> Array:
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


#  판이 그린 그대로의 진실 — 게임의 _order_ctx 를 안 빌리고 hit_info 에서 손으로 짓는다.
func _truth(cond: String, p: Vector2) -> bool:
	var hi: Dictionary = g.hit_info(p)
	var x := {"sector": int(hi.sector), "bull": bool(hi.get("bull", false)),
			"mult": int(hi.mult), "miss": int(hi.mult) == 0, "missp": false,
			"left": p.x < g.BC.x, "col": int(hi.get("col", -1))}
	return GameData.check(cond, x)


#  판 위 한 점(반지름 r · 각 an — 0 이 위 · 시계 방향)의 판 색. 판 구멍(_board_holes)과 같은
#  갈래 — 안쪽 불 C_RED · 바깥 불 C_GREEN · 트리플 · 더블 띠는 칸의 띠 색 · 그 밖은 칸 색
#  (_board_cols — 죽은 칸 가라앉힘까지).
func _board_px(r: float, an: float, cols: Array) -> Color:
	if r < g.R * g.rt_bull_i:
		return g.C_RED
	if r < g.R * g.rt_bull_o:
		return g.C_GREEN
	var sw: float = g._sec_w()
	var i: int = int(floor(fposmod(an + sw * 0.5, TAU) / sw)) % int(g._sec_n())
	var ring: bool = (r >= g.R * g.rt_trp_in and r < g.R * g.rt_trp_out) \
			or r >= g.R * g.rt_dbl_in \
			or (r >= g.R * g.rt_trp2_in and r < g.R * g.rt_trp2_out)
	return cols[i][1] if ring else cols[i][0]


#  조각이 홑 띠(불 밖 · 트리플 · 더블 · 둘째 트리플 띠가 아닌 고리)인가 — 조각 한가운데
#  반지름을 판 고리 자(rt_*)에 댄다(_board_px 와 같은 갈래).
func _single(pc: Array) -> bool:
	var r: float = (float(pc[0]) + float(pc[1])) * 0.5
	if r < g.R * g.rt_bull_o or r >= g.R * g.rt_dbl_in:
		return false
	if r >= g.R * g.rt_trp_in and r < g.R * g.rt_trp_out:
		return false
	return not (r >= g.R * g.rt_trp2_in and r < g.R * g.rt_trp2_out)


#  조각 한가운데 각이 든 칸 번호(_board_px 와 같은 식).
func _pc_sec(pc: Array) -> int:
	var sw: float = g._sec_w()
	var an: float = (float(pc[2]) + float(pc[3])) * 0.5
	return int(floor(fposmod(an + sw * 0.5, TAU) / sw)) % int(g._sec_n())


#  조각 목록이 그려진 결과의 넓이 가중 평균 밝기 [sRGB 루마, 선형 상대 휘도] — 대용 셈
#  (⑯ 의 「영역이 밝은 쪽이다」 머리말). 조각마다 극좌표 4 × 4 점(넓이 r · dr · da). 판 색 위에
#  판 빛(_board_light: 한가운데 0 에서 테로 갈수록 왼쪽 위 흰빛 light_hi · 오른쪽 아래 그늘
#  light_lo)을 얹고 그 위에 over 를 짙기 a 로 얹는다 — 2D 캔버스는 sRGB 값으로 섞는다.
func _lum_of(pcs: Array, over: Color, a: float) -> Vector2:
	var cols: Array = g._board_cols()
	var rim: float = g.R * g.rt_dbl_out
	var lt := Vector2(-0.6, -0.8)
	var hi: float = float(g.BOARDART.light_hi)
	var lo: float = float(g.BOARDART.light_lo)
	var s_l := 0.0
	var s_y := 0.0
	var s_w := 0.0
	for pc in pcs:
		var ri := float(pc[0])
		var ro := float(pc[1])
		var a0 := float(pc[2])
		var a1 := float(pc[3])
		for u in 4:
			var r := lerpf(ri, ro, (float(u) + 0.5) / 4.0)
			for v in 4:
				var an := lerpf(a0, a1, (float(v) + 0.5) / 4.0)
				var w := r * (ro - ri) * (a1 - a0) / 16.0
				var t := Vector2(sin(an), -cos(an)).dot(lt)
				var k := clampf(r / rim, 0.0, 1.0)
				var c := _board_px(r, an, cols)
				c = c.lerp(Color.WHITE, k * maxf(t, 0.0) * hi)
				c = c.lerp(Color.BLACK, k * maxf(-t, 0.0) * lo)
				c = c.lerp(over, a)
				s_l += c.get_luminance() * w
				s_y += c.srgb_to_linear().get_luminance() * w
				s_w += w
	if s_w <= 0.0:
		return Vector2.ZERO
	return Vector2(s_l / s_w, s_y / s_w)


func _run() -> void:
	print("\n== 판 사건 · 칠판 주문 ==")

	# ── ① 표 ─────────────────────────────────────────
	print("① 표")
	var orow: Dictionary = GameData.event_of("order")
	_ok("order 줄이 있다", not orow.is_empty() and GameData.event_w(orow) > 0.0)
	_ok("눈금은 2 ~ 3", int(GameData.event_v(orow, "v")) == 2
			and int(GameData.event_v(orow, "v2")) == 3,
			"v %d · v2 %d" % [int(GameData.event_v(orow, "v")), int(GameData.event_v(orow, "v2"))])
	var ev_errs := []
	for e in GameData.errors():
		if String(e).begins_with("events"):
			ev_errs.append(e)
	_ok("검증기가 events 에 오류를 안 낸다", ev_errs.is_empty(), str(ev_errs))
	var now_kinds := {}
	for r in GameData.tag_pool(8, "now", g.ORDER.kinds):
		now_kinds[String(r.kind)] = true
	_ok("보상 갈래 다섯이 tags.csv 에 다 있다", now_kinds.size() == 5, str(now_kinds.keys()))
	var bad_when := 0
	for r in GameData.tag_pool(8, "now"):
		if String(r.get("when", "")) != "now":
			bad_when += 1
	_ok("tag_pool 의 when 거름", bad_when == 0)

	# ── ② run_rng ────────────────────────────────────
	print("② 뽑기")
	_fresh()
	var same := true
	var steps_same := true
	var n_order := 0
	var ns := {}
	var conds := {}
	var tag_bad := 0
	var N := 450
	for s in range(1, N + 1):
		_roll_at(1, s)
		var a := _tuple()
		var st_a: int = g.run_rng.state
		if g.leg_ev == "order":
			n_order += 1
			ns[g.order_n] = true
			conds[String(g.order_cond).split(":")[0]] = true
			var tg: Dictionary = g.order_tag
			if String(tg.get("when", "")) != "now" or not g.ORDER.kinds.has(String(tg.get("kind", ""))) \
					or int(tg.get("min_round", "1")) > GameData.round_of(1):
				tag_bad += 1
		_roll_at(1, s)
		if _tuple() != a:
			same = false
		if g.run_rng.state != st_a:
			steps_same = false
	_ok("같은 씨앗 · 같은 자리면 같은 주문", same)
	_ok("run_rng 가 판마다 같은 만큼 간다", steps_same)
	var fo := float(n_order) / float(N)
	_ok("주문 몫이 2/9 둘레다", fo > 0.14 and fo < 0.31, "%.3f" % fo)
	_ok("눈금 2 · 3 이 다 나오고 그 밖은 없다", ns.has(2) and ns.has(3) and ns.size() == 2,
			str(ns.keys()))
	_ok("영역이 여러 갈래로 나온다", conds.size() >= 6, str(conds.keys()))
	_ok("보상은 when=now · 다섯 갈래 · 라운드 안", tag_bad == 0, "어긋남 %d" % tag_bad)
	#  늘 같은 다섯 번 — 사건 한 번(randf) 뒤에 영역 randf · 칸 randi · 눈금 randf · 보상 randf ·
	#  씨앗 randi. 같은 state 에서 짝 줄기를 같은 차례로 밀어 댄다(씨앗이 inc 를 안 바꾸므로
	#  state 만 맞추면 같은 줄기다). 고도의 randf 는 rand() 를 두 번 먹으므로 횟수가 아니라
	#  차례를 그대로 베낀다. 갈래 · 보상 · 영역이 달라도 미는 양이 같아야 한다.
	var five := 0
	var five_bad := 0
	for x0 in range(1, 600):
		g.run_rng.seed = x0 * 7919
		g._ev_roll()
		if g.leg_ev != "order":
			continue
		var ref := RandomNumberGenerator.new()
		ref.seed = x0 * 7919
		ref.randf()
		ref.randf()
		ref.randi()
		ref.randf()
		ref.randf()
		ref.randi()
		five += 1
		if ref.state != g.run_rng.state:
			five_bad += 1
	_ok("주문 판은 run_rng 를 늘 같은 다섯 번(+ 사건 한 번) 민다", five > 20 and five_bad == 0,
			"%d판 · 어긋남 %d" % [five, five_bad])
	_roll_at(1, 77)
	var b77 := _tuple()
	for i in 13:
		randi()
	_roll_at(1, 77)
	_ok("전역 난수가 밀려도 같다", _tuple() == b77, str(b77))

	# ── ③ 영역 = GameData.check ─────────────────────
	print("③ 영역 조각")
	var rr := RandomNumberGenerator.new()
	rr.seed = 4242
	for mods in [[], ["pizz"], ["arst"], ["dnut"], ["mung"], ["pang"], ["clok"]]:
		_fresh(mods)
		_plain()
		var regs := ["double", "triple", "bull", "col:1", "col:0", "left", "right", "small"]
		for k in [0, 3, 7, 11, 19]:
			if k < g.sectors.size():
				regs.append("sec:%d" % int(g.sectors[k]))
		var bad := 0
		var empty := []
		var full := []
		for cond in regs:
			g._order_open(String(cond), 3, _tag("t_gold"), 1)
			var nin := 0
			var nout := 0
			for k in 1500:
				var ang := rr.randf() * TAU
				var rad: float = sqrt(rr.randf()) * g.R * 1.08
				var p: Vector2 = g.BC + Vector2(cos(ang), sin(ang)) * rad
				var want := _truth(String(cond), p)
				if want != g._order_has(p):
					bad += 1
				if want: nin += 1
				elif rad < g.R * g.rt_dbl_out: nout += 1
			if nin == 0:
				empty.append(cond)
			if nout == 0:
				full.append(cond)
		_ok("%s 판 — 조각이 GameData.check 와 같다" % (str(mods) if not mods.is_empty() else "기본"),
				bad == 0, "어긋남 %d · 빈 영역 %s · 판 통째 %s" % [bad, str(empty), str(full)])
	_fresh()
	_plain()
	var std_empty := []
	for cond in ["double", "triple", "bull", "col:1", "col:0", "left", "right", "small", "sec:20"]:
		var pc: Array = g._order_pieces(String(cond))
		if (pc[0] as Array).is_empty() or (pc[1] as Array).is_empty():
			std_empty.append(cond)
	_ok("기본 판에서 영역 아홉이 다 그려지고 판 통째가 아니다", std_empty.is_empty(), str(std_empty))

	# ── ④ 실제로 던진 발 ─────────────────────────────
	print("④ 던진 발")
	_fresh()
	_plain()
	#  트리플 트랙을 올려 배수를 3 → 4 로 민다. 동전 「트리플」 조건은 이 판에서 안 서지만
	#  주문의 트리플 띠는 판이 그린 그대로라 서야 한다.
	g.track_lv = {int(GameData.area("triple").track): 2}
	g.cur_dart = GameData.darts()[0].duplicate()
	var land_bad := 0
	var land_n := 0
	var trp_seen := false
	for cond in ["triple", "double", "bull", "col:1", "left", "small", "sec:20"]:
		for k in 24:
			var ang := rr.randf() * TAU
			var rad: float = sqrt(rr.randf()) * g.R * 1.05
			var p: Vector2 = g.BC + Vector2(cos(ang), sin(ang)) * rad
			g._order_open(String(cond), 3, _tag("t_gold"), 1)
			g.queue = []
			_throw(p)
			var got := _kinds(g.queue).has("order")
			if got != _truth(String(cond), p):
				land_bad += 1
			if got and cond == "triple":
				trp_seen = true
			land_n += 1
			_settle()
	_ok("던진 발 %d 개 — 걸음이 판의 진실과 같다" % land_n, land_bad == 0, "어긋남 %d" % land_bad)
	_ok("트랙이 배수를 올린 트리플도 채운다", trp_seen)
	g.track_lv = {}

	# ── ⑤ 그릴 수 없는 영역 ──────────────────────────
	print("⑤ 그릴 수 없는 영역")
	_fresh(["pizz"])
	_plain()
	var piz_band := false
	var piz_sec := false
	for k in 400:
		var c: String = g._order_region(float(k) / 400.0, k)
		if c == "double" or c == "triple":
			piz_band = true
		if c.begins_with("sec:"):
			piz_sec = true
	_ok("피자는 더블 · 트리플 주문이 없다", not piz_band)
	#  피자는 칸 값이 다 같다(서른둘) — 「칸 하나」가 판 통째라 안 뽑는다.
	_ok("칸 값이 다 같은 판은 「칸 하나」 주문이 없다", not piz_sec,
			"칸 값 %d ~ %d" % [g.sectors.min(), g.sectors.max()])
	_fresh(["dnut"])
	_plain()
	var dn_bull := false
	for k in 400:
		if g._order_region(float(k) / 400.0, k) == "bull":
			dn_bull = true
	_ok("도넛은 불 주문이 없다", not dn_bull, "불 반지름 %.3f" % g.rt_bull_o)
	_fresh()
	_plain()
	var all9 := {}
	for k in 900:
		var c9: String = g._order_region(float(k) / 900.0, k)
		all9[c9.split(":")[0] if c9.begins_with("sec:") else c9] = true
	_ok("기본 판은 영역 아홉이 다 뽑힌다", all9.size() == 9, str(all9.keys()))

	# ── ⑥ 눈금 ───────────────────────────────────────
	print("⑥ 눈금")
	_fresh()
	_plain()
	var i20: int = g.sectors.find(20)
	g._order_open("bull", 3, _tag("t_gold"), 1)
	_throw(_aim(i20, "t"))
	_ok("첫 발이 꽂히면 눈금 하나가 지워진다", g.order_left == 2 and g.order_st == "open",
			"%d/%d" % [g.order_left, g.order_n])
	_settle()
	_ok("정산이 끝나도 그대로", g.order_left == 2 and g.order_st == "open")
	_burst([_aim(i20, "t"), _aim(i20, "d"), _aim(i20, "s"), _aim(i20, "si"), _aim(1, "t")])
	_ok("연발 다섯 다트가 한 발 — 눈금 하나", g.order_left == 1 and g.order_st == "open",
			"%d/%d · 발 %d" % [g.order_left, g.order_n, g.leg_throws])
	_throw(_aim(i20, "t"))
	_ok("셋째 발이 마지막 눈금을 지운다", g.order_left == 0 and g.order_st == "open")
	_settle()
	_ok("그 발의 정산이 끝나면 X", g.order_st == "miss")

	# ── ⑦ 채움 ───────────────────────────────────────
	print("⑦ 채움")
	_fresh()
	_give_c01()
	_plain()
	g._order_open("triple", 3, _tag("t_gold"), 1)
	#  불씨 칸도 같은 자리에 손으로 앉힌다 — 한 판에 사건은 하나라 게임에서는 안 겹치지만
	#  큐 자리(불씨 뒤)를 같이 잰다. _ember_light 를 부르면 주문이 걷히므로 칸만 적는다.
	g.ember_idx = i20
	g.ember_band = "t"
	var gold0: int = g.gold
	_throw(_aim(i20, "t"))
	var ks := _kinds(g.queue)
	var oi := ks.find("order")
	_ok("「주문」 걸음이 하나 선다", ks.count("order") == 1, str(ks))
	_ok("동전 · 불씨 걸음 뒤 · 모음 · 합계 앞", oi > ks.rfind("item") and oi > ks.find("ember")
			and ks.find("ember") >= 0 and oi < ks.find("wind") and oi < ks.find("total"), str(ks))
	_ok("정산 전에는 골드가 그대로다", g.gold == gold0)
	var pace_ok := false
	var step_gold := {}
	while not g.queue.is_empty():
		var nk := String((g.queue[0] as Dictionary).get("k", ""))
		var gb: int = g.gold
		g._next_step()
		if g.gold != gb:
			step_gold[nk] = int(step_gold.get(nk, 0)) + g.gold - gb
		if nk == "order":
			pace_ok = absf(g.qt - g.beat * g._pace()) < 0.0001
			_ok("걸음에서 동그라미(done)", g.order_st == "done")
	_ok("「주문」 걸음 하나가 골드 +6(「삯」)을 낸다", int(step_gold.get("order", 0)) == 6
			and step_gold.size() <= 2 and (step_gold.size() == 1 or step_gold.has("ember")),
			str(step_gold))
	_ok("「주문」 걸음이 _pace 를 탄다", pace_ok)
	g.ember_idx = -1
	_settle()
	var g1: int = g.gold
	_throw(_aim(i20, "t"))
	var ks2 := _kinds(g.queue)
	_settle()
	_ok("채운 뒤 또 꽂아도 「주문」 걸음 · 골드가 없다", not ks2.has("order")
			and g.order_st == "done" and g.gold == g1, "%s · %+d" % [str(ks2), g.gold - g1])
	#  연발 — 작은 다트 넷이 다 영역에 꽂혀도 보상은 한 장
	_plain()
	g._order_open("triple", 3, _tag("t_gold"), 1)
	var gb2: int = g.gold
	var seen := _burst([_aim(i20, "t"), _aim(i20, "t"), _aim(i20, "t"), _aim(i20, "t")])
	_ok("연발 넷이 영역에 — 「주문」 걸음 하나", seen.count("order") == 1 and g.gold == gb2 + 6,
			"%d걸음 · 골드 %+d" % [seen.count("order"), g.gold - gb2])
	_ok("연발 한 발 — 눈금 하나", g.order_left == 2, "%d/%d" % [g.order_left, g.order_n])
	#  연발 — 첫 다트는 밖, 셋째가 영역에. 그 발 안이면 채운다.
	_plain()
	g._order_open("bull", 2, _tag("t_gold"), 1)
	var seen2 := _burst([_aim(i20, "t"), _aim(i20, "d"), _aim(0, "bull"), _aim(i20, "s")])
	_ok("연발의 작은 다트가 채운다(셋째 다트)", seen2.count("order") == 1 and g.order_st == "done",
			str(seen2))

	# ── ⑧ 눈금이 다 함 ───────────────────────────────
	print("⑧ 못 채움")
	_plain()
	g._order_open("bull", 2, _tag("t_gold"), 1)
	var gm: int = g.gold
	var seen3 := []
	_throw(_aim(i20, "t"))
	seen3 += _settle()
	_throw(_aim(i20, "t"))
	seen3 += _settle()
	_ok("두 발 다 밖 — X · 걸음 없음 · 골드 그대로", g.order_st == "miss"
			and not seen3.has("order") and g.gold == gm, "%s · %+d" % [g.order_st, g.gold - gm])
	_throw(_aim(0, "bull"))
	var ks3 := _kinds(g.queue)
	_settle()
	_ok("X 뒤에 불에 꽂아도 없다", not ks3.has("order") and g.gold == gm, str(ks3))

	# ── ⑨ 판 끝 ──────────────────────────────────────
	print("⑨ 판 끝")
	_plain()
	g._order_open("triple", 3, _tag("t_gold"), 1)
	g.total = 0
	g.target = 1                     # 이 발이 판을 끝낸다
	var ge: int = g.gold
	_throw(_aim(i20, "t"))
	_ok("목표를 넘는 발에도 「주문」 걸음이 선다", _kinds(g.queue).has("order"))
	var seen4 := _settle()
	_ok("판이 끝나기 전에 받았다", seen4.has("order") and g.gold >= ge + 6,
			"골드 %+d · state %d" % [g.gold - ge, g.state])
	_ok("판이 끝나면 칠판째 사라진다", g.order_cond == "" and g.order_st == "" and g.leg_ev == ""
			and not g._order_board_on())
	var ga: int = g.gold
	g._order_grant()
	g.queue = [{"k": "order"}]
	g.state = g.S.RESOLVE
	g._next_step()
	g.queue = []
	_ok("판이 끝난 뒤에는 「주문」 걸음도 아무것도 안 준다", g.gold == ga, "%+d" % (g.gold - ga))
	_plain()
	g._order_open("bull", 3, _tag("t_gold"), 1)
	g.total = 0
	g.target = 1
	var gx: int = g.gold
	_throw(_aim(i20, "t"))
	var seen5 := _settle()
	_ok("못 채우고 판이 끝나면 그냥 사라진다(X 없음)", not seen5.has("order")
			and g.order_st == "" and g.order_cond == "", "골드 %+d" % (g.gold - gx))

	# ── ⑩ 튜토리얼 · 보스 ───────────────────────────
	print("⑩ 튜토리얼 · 보스")
	_fresh()
	g.tut_run = true
	var tut_order := 0
	for s in range(1, 200):
		for ln in [1, 2, 3]:
			_roll_at(ln, s)
			if g.leg_ev == "order" or g.order_st != "":
				tut_order += 1
	g.tut_run = false
	_ok("튜토리얼 런에는 주문이 안 선다", tut_order == 0, "%d판" % tut_order)
	var boss_order := 0
	var boss_n := 0
	for ln in range(1, GameData.legs_n() + 1):
		if not GameData.is_boss(ln):
			continue
		boss_n += 1
		for s in range(1, 60):
			_roll_at(ln, s)
			if g.leg_ev == "order" or g.order_st != "":
				boss_order += 1
	_ok("보스 판(%d)에는 주문이 안 선다" % boss_n, boss_order == 0 and boss_n > 0)
	var r2_order := 0
	for s in range(1, 300):
		_roll_at(2, s)
		if g.leg_ev == "order":
			r2_order += 1
	_ok("큰 판에도 선다", r2_order > 0, "%d판" % r2_order)

	# ── ⑪ 보상 안의 뽑기 ─────────────────────────────
	print("⑪ 보상 줄기")
	var outs := {}
	var stable := true
	for u in [5, 77, 901, 4444, 31337, 99991, 123457, 777777]:
		var got := []
		for rep in 2:
			_fresh()
			_plain()
			g._order_open("triple", 3, _tag("t_track"), u)
			for k in 7 * (rep + 1):
				randi()                       # 전역을 민다 — 줄기가 안 흔들려야 한다
			_throw(_aim(i20, "t"))
			_settle()
			got.append(str(g.track_lv))
		if got[0] != got[1]:
			stable = false
		outs[got[0]] = true
	_ok("트랙 강화 — 같은 씨앗이면 같은 트랙(전역 난수와 무관)", stable)
	_ok("씨앗이 다르면 트랙이 갈린다", outs.size() >= 2, "%d갈래" % outs.size())
	#  동전은 둘째 판부터 풀린다(rarity.csv 의 min_leg 2) — 첫 판에는 「견본」이 안 뽑힌다.
	_fresh()
	_plain()
	var it1: bool = g._order_tag_ok(_tag("t_item"))
	_roll_at(2, 3)
	var it2: bool = g._order_tag_ok(_tag("t_item"))
	_ok("줄 동전이 없는 판(첫 판)에는 「견본」이 안 뽑힌다", not it1 and it2)
	var it_same := true
	for u in [12, 345, 6789]:
		var ids := []
		for rep in 2:
			_fresh()
			_roll_at(2, 3)
			g._ev_clear()
			g._order_open("triple", 3, _tag("t_item"), u)
			randi()
			_throw(_aim(i20, "t"))
			_settle()
			ids.append(String(g.owned[g.owned.size() - 1].id) if not g.owned.is_empty() else "")
		if ids[0] != ids[1] or ids[0] == "":
			it_same = false
			print("    견본 씨앗 %d → %s" % [u, str(ids)])
	_ok("견본 — 같은 씨앗이면 같은 동전", it_same)
	var cd_same := true
	for u in [3, 58, 911]:
		var cid := []
		for rep in 2:
			_fresh()
			_plain()
			g._order_open("triple", 3, _tag("t_candy"), u)
			randi()
			_throw(_aim(i20, "t"))
			_settle()
			cid.append(String(g.cons[g.cons.size() - 1].get("id", "")) if not g.cons.is_empty() else "")
		if cid[0] != cid[1] or cid[0] == "":
			cd_same = false
	_ok("군것질 — 같은 씨앗이면 같은 사탕", cd_same)
	_fresh()
	_plain()
	GameData.challenge = "empty"
	#  빈손이 실제로 켜진 채 뽑았는지를 루프 안에서 잡는다 — 되돌린 뒤에 물으면 늘 참이다
	#  (검토, 2026-10-06).
	var empty_on: bool = GameData.chal_on("gold_off")
	var empty_gold := false
	for k in 300:
		if String(g._order_tag_pick(float(k) / 300.0).get("kind", "")) == "gold":
			empty_gold = true
	GameData.challenge = ""
	_ok("빈손은 골드 보상을 안 뽑는다", empty_on and not empty_gold)
	var any_gold := false
	for k in 300:
		if String(g._order_tag_pick(float(k) / 300.0).get("kind", "")) == "gold":
			any_gold = true
	_ok("빈손이 아니면 골드 보상이 뽑힌다", any_gold)
	while g.cons.size() < GameData.cons_slots():
		g.cons.append(GameData.candies()[0].duplicate())
	var full_cons := false
	for k in 300:
		var kd := String(g._order_tag_pick(float(k) / 300.0).get("kind", ""))
		if kd == "candy" or kd == "photo":
			full_cons = true
	_ok("사탕 · 사진 칸이 꽉 차면 사탕 · 사진 보상이 없다", not full_cons)
	g.cons.clear()

	# ── ⑫ 팝 ─────────────────────────────────────────
	print("⑫ 팝")
	_fresh()
	_plain()
	g._order_open("triple", 3, _tag("t_track"), 9)
	_throw(_aim(i20, "t"))
	while not g.queue.is_empty():
		var nk := String((g.queue[0] as Dictionary).get("k", ""))
		if nk == "order":
			g.pops.clear()
		g._next_step()
		if nk == "order":
			break
	var pa: Vector2 = g._order_pop_at()
	var near := true
	var names := false
	var tr_pop := false
	for p in g.pops:
		if absf(float(p.p.x) - pa.x) > 0.5 or float(p.p.y) > pa.y + 0.5 or float(p.p.y) < pa.y - 30.0:
			near = false
		if String(p.txt) == "트랙 강화":
			names = true
		if String(p.txt).find("Lv.") >= 0:
			tr_pop = true
	_ok("트랙 강화 — 값 팝이 칠판 위에 선다", tr_pop and near, str(g.pops.map(func(p): return [p.txt, p.p])))
	_ok("뱃지 이름 줄은 안 선다", not names)
	_ok("팝 자리는 걸음이 끝나면 옛 자리로 돌아간다", not g.tag_pop.is_finite())
	_settle()
	_plain()
	g._order_open("triple", 3, _tag("t_gold"), 9)
	_throw(_aim(i20, "t"))
	while not g.queue.is_empty():
		var nk2 := String((g.queue[0] as Dictionary).get("k", ""))
		if nk2 == "order":
			g.pops.clear()
		g._next_step()
		if nk2 == "order":
			break
	var bank_pop := false
	for p in g.pops:
		if String(p.txt) == "+6" and (p.p as Vector2).distance_to(g._bank_rect().get_center()) < 40.0:
			bank_pop = true
	_ok("골드는 자금판 밑에 「+6」 하나", bank_pop and g.pops.size() == 1,
			str(g.pops.map(func(p): return p.txt)))
	_settle()

	# ── ⑫-b 받기 (2026-10-06) ────────────────────────
	print("⑫-b 받기")
	#  쌓인 「쌍둥이」는 건너뛰기 뱃지의 것이다 — 주문 보상이 안 쓴다(_take_tag_once).
	_fresh()
	_plain()
	g.tag_copy = 1
	g.gold = 4
	g._order_open("triple", 3, _tag("t_gold"), 9)
	_throw(_aim(i20, "t"))
	_settle()
	_ok("쌍둥이를 안 쓴다 — 「삯」 한 장(+6) · 쌍둥이 그대로", g.gold == 10 and g.tag_copy == 1,
			"골드 %d · 쌍둥이 %d" % [g.gold, g.tag_copy])
	g.tag_copy = 0
	#  뽑을 때는 들어가는 것만 고른다 — 그 사이 칸이 찼으면(판 중간에 쓴 사진의 복제 등)
	#  보상 없이 조용히 동그라미만 친다. 「꽉 찼다」 팝 · 거절이 칠판에 안 뜬다.
	_plain()
	g._order_open("triple", 3, _tag("t_candy"), 5)
	while g.cons.size() < GameData.cons_slots():
		g.cons.append(GameData.candies()[0].duplicate())
	var cn0: int = g.cons.size()
	_throw(_aim(i20, "t"))
	var full_txt := []
	var full_seen := false
	while not g.queue.is_empty():
		var fk := String((g.queue[0] as Dictionary).get("k", ""))
		if fk == "order":
			g.pops.clear()
		g._next_step()
		if fk == "order":
			full_seen = true
			for pp in g.pops:
				full_txt.append(String(pp.txt))
			break
	_ok("그 사이 칸이 찼으면 조용히 — 팝 0 · 칸 그대로 · 동그라미", full_seen and full_txt.is_empty()
			and g.cons.size() == cn0 and g.order_st == "done" and g.order_fly.is_empty(),
			"팝 %s · 칸 %d → %d · %s" % [str(full_txt), cn0, g.cons.size(), g.order_st])
	_settle()
	g.cons.clear()
	#  사탕 v 장이 안 들어가면 뽑지 않는다 — 한 칸 남은 사탕 · 사진 칸에 두 장짜리는 안 뽑힌다.
	var two := _tag("t_candy").duplicate()
	two["v"] = "2"
	while g.cons.size() < GameData.cons_slots() - 1:
		g.cons.append(GameData.candies()[0].duplicate())
	_ok("v 장이 안 들어가면 안 뽑는다", g._order_tag_ok(_tag("t_candy"))
			and not g._order_tag_ok(two))
	g.cons.clear()
	#  동전을 받으면 이 발은 제 방식대로 끝나고, 발이 끝나는 자리에서 조준 · 계산 방식을
	#  다시 읽는다 — 다음 발부터 그 동전의 방식이다(_modes_refresh 의 정산 중 규약).
	#  견본 씨앗을 조준 동전(aim 칸이 찬 것)이 나오는 것으로 고른다.
	_fresh()
	_plain2()
	var it_pool: Array = g._tag_items("common")
	var u_aim := -1
	var aim_id := ""
	for u in range(1, 4000):
		var rq := RandomNumberGenerator.new()
		rq.seed = u
		var pk: Dictionary = it_pool[rq.randi() % it_pool.size()]
		if String(pk.get("aim", "")) != "":
			u_aim = u
			aim_id = String(pk.get("id", ""))
			break
	_ok("조준 동전이 나오는 견본 씨앗을 찾았다", u_aim > 0, "씨앗 %d · %s" % [u_aim, aim_id])
	if u_aim > 0:
		g.aim_mode = "std"
		g._order_open("triple", 3, _tag("t_item"), u_aim)
		_throw(_aim(i20, "t"))
		var mid_aim := ""
		while not g.queue.is_empty():
			var mk := String((g.queue[0] as Dictionary).get("k", ""))
			g._next_step()
			if mk == "order":
				mid_aim = g.aim_mode
		_ok("받은 발은 제 방식으로 끝난다 — 걸음 동안 조준 방식 그대로", mid_aim == "std"
				and g.owned.size() == 1 and String(g.owned[0].get("id", "")) == aim_id,
				"걸음 뒤 %s · 동전 %d" % [mid_aim, g.owned.size()])
		_settle()
		_ok("발이 끝나면 새 동전의 조준 방식이 선다", g.aim_mode == g._aim_from_items()
				and g.aim_mode != "std" and not g.modes_due, "%s" % g.aim_mode)
	#  판 위에서는 동전 칸 스프링을 통째로 안 돌린다 — 방금 발동한 동전의 튐 · 빛이 산다.
	_fresh()
	_plain2()
	_give_c01()
	g._panel_reset()
	g._order_open("triple", 3, _tag("t_item"), 7)
	_throw(_aim(i20, "t"))
	var hot0 := -1.0
	var hot1 := -1.0
	var new_sp := []
	while not g.queue.is_empty():
		var sk := String((g.queue[0] as Dictionary).get("k", ""))
		if sk == "order":
			hot0 = float(g.slot_hot[0])
		g._next_step()
		if sk == "order":
			hot1 = float(g.slot_hot[0])
			var ni: int = g.owned.size() - 1
			new_sp = [g.slot_pop[ni], g.slot_vel[ni], g.slot_hot[ni]]
			break
	_ok("판 위 보상 동전 — 앞 동전 스프링이 그대로 · 새 칸만 0 에서", hot0 > 0.0
			and is_equal_approx(hot0, hot1) and g.owned.size() == 2 and new_sp == [0.0, 0.0, 0.0],
			"앞 동전 빛 %.2f → %.2f · 새 칸 %s" % [hot0, hot1, str(new_sp)])
	#  ── 제 칸으로 난다 — 칠판 그림 자리에서 사탕 · 사진 칸 · 동전 칸으로 ──
	#  나는 동안 그 칸은 비어 있고(_order_fly_hides), 앉는 프레임에 동전은 발동 스프링을
	#  받는다. 시계는 빨리 보기를 탄다(_process). 모션 끄기면 날지 않는다.
	_settle()
	_plain()
	g.cons.clear()
	g._order_open("triple", 3, _tag("t_candy"), 5)
	_throw(_aim(i20, "t"))
	while not g.queue.is_empty():
		var ck := String((g.queue[0] as Dictionary).get("k", ""))
		g._next_step()
		if ck == "order":
			break
	var ci: int = g.cons.size() - 1
	var fly0: bool = String(g.order_fly.get("k", "")) == "cons" and int(g.order_fly.get("i", -9)) == ci
	var hide0: bool = g._order_fly_hides("cons", ci)
	g._order_fly_tick(float(g.ORDER.fly_t) * 0.5)
	var hide1: bool = g._order_fly_hides("cons", ci)
	g._order_fly_tick(float(g.ORDER.fly_t) * 0.5 + 0.001)
	var hide2: bool = g._order_fly_hides("cons", ci)
	var ring: bool = not g.order_fly.is_empty()
	g._order_fly_tick(float(g.ORDER.fly_ring))
	_ok("사탕이 칠판에서 사탕 칸으로 난다 — 나는 동안 칸이 비고 앉으면 서고 고리가 식는다",
			fly0 and hide0 and hide1 and not hide2 and ring and g.order_fly.is_empty(),
			"%s %s %s %s 고리 %s" % [fly0, hide0, hide1, hide2, ring])
	var to_c: Array = g._order_fly_to("cons", ci)
	var cr0: Rect2 = g._cons_rect(ci)
	_ok("앉는 자리는 그 사탕 칸의 한가운데 · 칠판에서 떠난다",
			cr0.has_point(to_c[0]) and g._order_foot().has_point(g._order_ico_at()),
			"%s · %s" % [str(to_c[0]), str(g._order_ico_at())])
	_settle()
	_plain2()
	g.owned.clear()
	g._panel_reset()
	g._order_open("triple", 3, _tag("t_item"), 7)
	_throw(_aim(i20, "t"))
	while not g.queue.is_empty():
		var ik := String((g.queue[0] as Dictionary).get("k", ""))
		g._next_step()
		if ik == "order":
			break
	var ii: int = g.owned.size() - 1
	var ifly: bool = String(g.order_fly.get("k", "")) == "item" and g._order_fly_hides("item", ii)
	var v0: float = float(g.slot_vel[ii])
	g._order_fly_tick(float(g.ORDER.fly_t) + 0.001)
	_ok("동전이 동전 칸으로 난다 — 앉는 프레임에 발동 스프링 한 번(이름 줄 없이)", ifly
			and float(g.slot_vel[ii]) > v0 and float(g.slot_hot[ii]) == 0.0,
			"튐 %.2f → %.2f · 이름 %.2f" % [v0, float(g.slot_vel[ii]), float(g.slot_hot[ii])])
	var to_i: Array = g._order_fly_to("item", ii)
	_ok("동전 칸 한가운데로 앉는다", g._slot_rect(ii).has_point(to_i[0]), str(to_i[0]))
	_settle()
	#  빨리 보기를 탄다 — _process 가 그 배수를 태워 민다
	g._order_fly_go("cons", 0)
	g.state = g.S.RESOLVE
	g.queue = [{"k": "wind"}]
	g.qt = 99.0
	g.hitstop = 0.0
	g.pause_from = -1
	g.fast_lock = true
	g.fast_mul = 2.5
	g._process(0.05)
	var frate: float = g.fast_rate
	var ft1: float = float(g.order_fly.get("t", -1.0))
	g.fast_lock = false
	g.queue = []
	g.state = g.S.PICK
	_ok("나는 시계가 빨리 보기 배수를 탄다", frate > 1.0 and absf(ft1 - 0.05 * frate) < 0.0001,
			"배 %.2f · %.3f" % [frate, ft1])
	g.order_fly = {}
	g.motion_off = true
	_plain()
	g.cons.clear()
	g._order_open("triple", 3, _tag("t_candy"), 5)
	_throw(_aim(i20, "t"))
	_settle()
	_ok("모션 끄기면 날지 않고 곧장 선다", g.order_fly.is_empty() and g.cons.size() == 1
			and not g._order_fly_hides("cons", 0))
	g.motion_off = false

	# ── ⑬ 칠판 자리 ─────────────────────────────────
	print("⑬ 칠판 자리")
	_fresh()
	_plain()
	g._order_open("double", 3, _tag("t_gold"), 1)
	var ft: Rect2 = g._order_foot()
	var bx: Rect2 = g.ORDER.box
	_ok("칠판이 화면 안이다", Rect2(Vector2.ZERO, g.VIEW).encloses(ft), str(ft))
	#  판 — 판 테 바깥(숫자 고리 · 테 · 그늘)까지 R × 1.38 로 잡는다(찍어 보니 테 끝 131px).
	var near_pt := Vector2(clampf(g.BC.x, ft.position.x, ft.end.x), clampf(g.BC.y, ft.position.y, ft.end.y))
	var bd: float = near_pt.distance_to(g.BC)
	_ok("판(테 · 그늘까지)과 안 겹친다", bd > g.R * 1.38, "판 중심까지 %.1f · 테 %.1f" % [bd, g.R * 1.38])
	var huds := []
	for k in g.LAY:
		if g.LAY[k] is Rect2:
			huds.append([String(k), g.LAY[k]])
	for i in GameData.cons_slots():
		huds.append(["사탕 칸 %d" % i, g._cons_rect(i)])
	huds.append(["동전 슬롯", g._panel_rect()])
	huds.append(["자금판", g._bank_rect()])
	huds.append(["정보 단추", g._hud_btn_rect(0)])
	huds.append(["일시정지 단추", g._hud_btn_rect(1)])
	#  자루 걸이 — 꽂힌 자루 끝(x + dl) · 뽑힌 자루(pull)까지
	huds.append(["자루 걸이", Rect2(0.0, 0.0, float(g.GRIP.x) + float(g.GRIP.dl)
			+ float(g.GRIP.pull) + 2.0, g.VIEW.y)])
	#  조준 가로선 — 판 가운데 ±151(_aim_h_line)
	huds.append(["조준 가로선", Rect2(g.BC.x - 151.0, 0.0, 302.0, g.VIEW.y)])
	#  안내 줄 — 가장 긴 말 212px · 잉크 y[333.5,351](_draw_hint 머리말)
	huds.append(["안내 줄", Rect2(214.0, 333.0, 212.0, 19.0)])
	var cs0: int = g.card_side
	var cy0: float = g.card_y
	for side in [-1, 1]:
		for cy in [74.0, 206.0]:
			if side < 0 and cy > 100.0:
				continue          # 왼쪽 카드는 늘 위다(_land)
			g.card_side = side
			g.card_y = cy
			#  카드 위 걸음 이름 팝(카드 위 14) · 밑 그늘(8)까지
			huds.append(["카드 %s %d" % ["왼쪽" if side < 0 else "오른쪽", int(cy)],
					Rect2(g._card_sx(), cy - 14.0, g.CARD_W, g.CARD_H + 22.0)])
			var gp: Vector2 = g._goal_pop_at()
			huds.append(["목표 달성 %d" % side, Rect2(gp.x - 90.0, gp.y - 34.0, 180.0, 40.0)])
	g.card_side = cs0
	g.card_y = cy0
	var hits := []
	for h in huds:
		if (h[1] as Rect2).intersects(ft):
			hits.append(h[0])
	_ok("HUD · 칸 · 카드 · 자루 · 조준선 · 안내와 안 겹친다", hits.is_empty(),
			"%d곳 중 겹침 %s" % [huds.size(), str(hits)])
	#  보상 팝 — 다 오른 둘째 줄(14 위 + 24 오름 + 글 12 × 1.45)의 윗끝이 왼쪽 카드 밑보다 밑이다
	var pt: Vector2 = g._order_pop_at()
	var pop_top: float = pt.y - 14.0 - 24.0 - 12.0
	g.card_side = -1
	var lc := Rect2(g._card_sx(), 74.0, g.CARD_W, g.CARD_H + 4.0)
	g.card_side = cs0
	_ok("보상 팝이 다 올라도 왼쪽 카드에 안 닿는다", pop_top > lc.end.y,
			"팝 윗끝 %.0f · 카드 밑 %.0f" % [pop_top, lc.end.y])
	_ok("칠판은 판 위에서 선다", g._order_board_on())
	g.swap_live = true
	_ok("판 갈이(상인이 서는 때)에는 안 선다", not g._order_board_on() and g._npc_on())
	g.swap_live = false
	var st0: int = g.state
	var off_on := []
	for s2 in [g.S.SHOP, g.S.LEG, g.S.CLEAR, g.S.TITLE]:
		g.state = s2
		if g._order_board_on():
			off_on.append(s2)
	g.state = st0
	_ok("상점 · 판 고르기 · 정산 · 제목에서는 안 선다", off_on.is_empty(), str(off_on))
	_ok("칠판 판이 테 안이다", ft.encloses(bx.grow(float(g.ORDER.frame))))

	# ── ⑭ 되살리기 ───────────────────────────────────
	print("⑭ 되살리기")
	_fresh()
	var sr := -1
	for s in range(1, 3000):
		g.leg_no = 1
		g.run_seed = s
		g.run_rng.seed = s
		g._begin_leg()
		g._swap_skip()
		if g.leg_ev == "order":
			sr = s
			break
	_ok("주문 판을 찾았다", sr > 0, "씨앗 %d" % sr)
	if sr > 0:
		var want := _tuple()
		g.target = 99999999
		_throw(_aim(i20, "out"))
		_settle()
		_ok("한 발 던져 눈금이 줄었다", g.order_left == g.order_n - 1)
		_ok("되살아난다", g._run_load())
		g._swap_skip()
		_ok("판 첫머리에서 같은 주문 · 눈금이 다 찼다", _tuple() == want
				and g.order_left == g.order_n and g.order_st == "open",
				"%s ← %s" % [str(_tuple()), str(want)])

	# ── ⑮ 개발자 판 ──────────────────────────────────
	print("⑮ 개발자 판")
	var pg0 := Dev.page
	var row := {}
	var rows_n := 0
	var erow := {}
	for pg in Dev.PAGES.size():
		Dev.page = pg
		for rw in Dev._rows(g):
			if String((rw as Dictionary).get("n1", "")) == "주문 걸기":
				row = rw
				rows_n = Dev._rows(g).size()
			if String((rw as Dictionary).get("n1", "")) == "불씨 피우기":
				erow = rw
	_ok("「주문 걸기」 줄이 있다", not row.is_empty())
	_ok("그 쪽이 열아홉 줄 안이다", rows_n <= 19 and rows_n > 0, "%d줄" % rows_n)
	_fresh()
	_plain()
	var gl0: int = g.gold
	var tg0: int = g.target
	var rng0: int = g.run_rng.state
	Dev._run(g, row)
	var conds_ok := false
	for e in g.ORDER.regions:
		if String(g.order_cond) == String(e[0]) \
				or (String(e[0]) == "sec" and String(g.order_cond).begins_with("sec:")):
			conds_ok = true
	_ok("누르면 지금 판에 곧장 걸린다", g.order_st == "open" and g.leg_ev == "order" and conds_ok
			and g.order_n >= 2 and g.order_n <= 3 and not g.order_tag.is_empty()
			and not g.order_in.is_empty(), str(_tuple()))
	_ok("골드 · 목표 · run_rng 를 안 건드린다", g.gold == gl0 and g.target == tg0
			and g.run_rng.state == rng0)
	#  그 영역 안의 한 점에 꽂으면 게임과 같이 찬다
	var pin := Vector2.INF
	for k in 4000:
		var ang := rr.randf() * TAU
		var rad: float = sqrt(rr.randf()) * g.R
		var p: Vector2 = g.BC + Vector2(cos(ang), sin(ang)) * rad
		if g._order_has(p):
			pin = p
			break
	_throw(pin)
	_ok("개발자 주문도 게임과 같이 찬다", _kinds(g.queue).has("order"))
	_settle()
	#  한 판에 사건 하나 — 불씨를 피우면 주문이 걷히고, 주문을 걸면 불씨가 걷힌다
	Dev._run(g, row)
	Dev._run(g, erow)
	_ok("불씨를 피우면 주문이 걷힌다", g.leg_ev == "ember" and g.order_st == "" and g.ember_idx >= 0)
	Dev._run(g, row)
	_ok("주문을 걸면 불씨가 걷힌다", g.leg_ev == "order" and g.ember_idx < 0 and g.order_st == "open")
	g._open_shop()
	var sh_cond: String = g.order_cond
	Dev._run(g, row)
	_ok("판 밖에서는 아무 일이 없다", g.order_cond == sh_cond)
	Dev.page = pg0

	# ── ⑯ 그림 ───────────────────────────────────────
	print("⑯ 그림")
	_fresh()
	_plain()
	g._order_open("left", 3, _tag("t_gold"), 1)
	g.motion_off = true
	var b_off := []
	for tt in [0.0, 0.3, 0.9, 1.7]:
		g.order_t = float(tt)
		b_off.append(g._order_breathe())
	g.motion_off = false
	var b_on := {}
	for tt in [0.0, 0.3, 0.9, 1.7]:
		g.order_t = float(tt)
		b_on[snappedf(g._order_breathe(), 0.001)] = true
	_ok("모션 끄기면 분필빛이 숨을 안 쉰다", b_off.count(1.0) == b_off.size(), str(b_off))
	_ok("모션 켜면 숨을 쉰다", b_on.size() >= 3, str(b_on.keys()))
	g.order_t = 0.0
	var e0: float = g._order_lit_e()
	g.order_t = 5.0
	var e1: float = g._order_lit_e()
	g.order_st = "done"
	g.order_t = 5.0
	var e2: float = g._order_lit_e()
	_ok("빛은 쓰는 동안 차오르고 동그라미 뒤 식는다", e0 == 0.0 and e1 == 1.0 and e2 == 0.0,
			"%.2f %.2f %.2f" % [e0, e1, e2])
	#  ── 영역 테두리 (2026-10-06) ──
	#  백색 칸 주문은 영역(크림)에 분필빛(크림)을 얹어도 판이 거의 안 바뀌었다(검토) — 영역
	#  둘레에 분필 선을 긋는다. 영역 아홉 다 선이 서고, 선 토막마다 한가운데에서 1.5px 양쪽이
	#  하나는 영역 · 하나는 영역 밖이다(판의 진실 _truth 로 댄다 — 판 밖은 영역이 아니다).
	#  더블 · 불은 둘레 길이가 원 둘레와 2% 안이다(빠진 토막이 없다).
	var rim_ok := true
	var rim_txt := ""
	for rc in ["double", "triple", "bull", "col:1", "col:0", "sec:20", "left", "right", "small"]:
		_plain()
		g._order_open(String(rc), 3, _tag("t_gold"), 1)
		var segs: Array = g.order_rim
		var bad_seg := 0
		var len_sum := 0.0
		for pl in segs:
			var pa2: PackedVector2Array = pl
			for k in pa2.size() - 1:
				len_sum += pa2[k].distance_to(pa2[k + 1])
			var mi: int = pa2.size() / 2
			var m: Vector2 = (pa2[maxi(mi - 1, 0)] + pa2[mi]) * 0.5
			var dv: Vector2 = (pa2[mi] - pa2[maxi(mi - 1, 0)]).normalized().orthogonal()
			if _truth(String(rc), m + dv * 1.5) == _truth(String(rc), m - dv * 1.5):
				bad_seg += 1
		var circ := -1.0
		if rc == "double":
			circ = TAU * g.R * (g.rt_dbl_in + g.rt_dbl_out)
		elif rc == "bull":
			circ = TAU * g.R * g.rt_bull_o
		if segs.is_empty() or bad_seg > 0 or (circ > 0.0 and absf(len_sum - circ) > circ * 0.02):
			rim_ok = false
		rim_txt += "%s %d토막 %.0fpx%s · " % [rc, segs.size(), len_sum,
				"" if bad_seg == 0 else " 어긋남 %d" % bad_seg]
	_ok("영역 아홉 다 테두리가 서고 토막마다 한쪽만 영역이다", rim_ok, rim_txt)
	_ok("나머지를 0.16 보다 세게 누르고 테두리 선 · 그늘이 선다", float(g.ORDER.dim_a) > 0.16
			and float(g.ORDER.rim_a) > 0.5 and float(g.ORDER.rim_dk) > 0.0)
	#  ── 그늘은 선의 밖에만 깔린다 (2026-10-06) ──
	#  양옆에 깔던 그늘은 영역 쪽 1px 도 눌러 선이 안팎을 못 갈랐다(검토). 그늘 토막은 선
	#  토막과 짝이고(수가 같다), 그늘 토막의 한가운데는 짝 선에서 1.5px 떨어진 영역 **밖**이다
	#  (판의 진실 _truth — 판 밖도 영역 밖이다).
	var sh_ok := true
	var sh_txt := ""
	for rc2 in ["double", "triple", "bull", "col:1", "col:0", "sec:20", "left", "right", "small"]:
		_plain()
		g._order_open(String(rc2), 3, _tag("t_gold"), 1)
		var ln: Array = g.order_rim
		var sh: Array = g.order_rim_sh
		var in_n := 0
		var far_n := 0
		if ln.size() != sh.size() or ln.is_empty():
			sh_ok = false
		for j in mini(ln.size(), sh.size()):
			var la: PackedVector2Array = ln[j]
			var sa: PackedVector2Array = sh[j]
			var mi2: int = sa.size() / 2
			var sm: Vector2 = (sa[maxi(mi2 - 1, 0)] + sa[mi2]) * 0.5
			var lm: Vector2 = (la[maxi(mi2 - 1, 0)] + la[mi2]) * 0.5
			if _truth(String(rc2), sm):
				in_n += 1
			if absf(sm.distance_to(lm) - 1.5) > 0.25:
				far_n += 1
		if in_n > 0 or far_n > 0:
			sh_ok = false
		sh_txt += "%s %d/%d%s · " % [rc2, sh.size(), ln.size(),
				"" if in_n + far_n == 0 else " 안 %d · 거리 %d" % [in_n, far_n]]
	_ok("테두리 그늘은 선마다 하나 · 영역 밖 1.5px 에만 깔린다", sh_ok, sh_txt)
	#  ── 영역이 밝은 쪽이다 (2026-10-06) ──
	#  검토: 흑색 칸 주문은 영역(먹 2b2438)에 분필빛을 얹어도 가라앉은 나머지(백색 칸 크림)보다
	#  어두워, 판이 영역을 **어두운 쪽**으로 말했다. 아홉 영역(칸 하나는 이 판의 칸 값 전부)에서
	#  영역의 평균 밝기가 나머지보다 높아야 한다. 헤드리스라 화면을 못 찍으므로 **그린 결과를
	#  셈으로 짓는 대용**이다(_lum_of): 그리는 조각 목록(order_in · order_off) 그대로, 조각마다
	#  극좌표 4 × 4 점을 넓이로 달아 판 색(칸 · 띠 · 불 — 판 구멍과 같은 갈래) 위에 판 빛
	#  (_board_light 의 왼쪽 위 밝힘 · 오른쪽 아래 그늘)을 얹고, 영역은 분필빛(_order_tone 의 빛 ×
	#  숨이 가장 얕을 때 1 − breathe), 나머지는 어둠을 얹는다. 밝기는 sRGB 루마
	#  (Color.get_luminance)와 선형 상대 휘도 둘 다 잰다. 테두리 선 · 그늘 · 구멍 · 철사는
	#  안 넣는다 — 창으로 찍은 실제 화면(저장소 밖 캡처, 2026-10-06)의 판 픽셀 평균과 아홉 영역 ·
	#  흑색 칸 하나의 대소가 같았다(흑색 칸: 영역 루마 0.507 · 나머지 0.270, 옛 세기는 0.389 ·
	#  0.416 으로 거꾸로 — 이 셈도 옛 세기에서 붉다).
	var lu_ok := true
	var lu_txt := ""
	var lu_conds := ["double", "triple", "bull", "col:1", "col:0", "left", "right", "small"]
	var sv_seen := {}
	for sv in g.sectors:
		if not sv_seen.has(int(sv)):
			sv_seen[int(sv)] = true
			lu_conds.append("sec:%d" % int(sv))
	var br_lo: float = 1.0 - float(g.ORDER.breathe)
	var sec_worst := ""
	var sec_gap := INF
	for lcd in lu_conds:
		_plain()
		g._order_open(String(lcd), 3, _tag("t_gold"), 1)
		var tn: Vector2 = g._order_tone()
		var li: Vector2 = _lum_of(g.order_in, g.DOORT.chalk_ink, tn.x * br_lo)
		var lo: Vector2 = _lum_of(g.order_off, Color.BLACK, tn.y)
		var good: bool = li.x > lo.x and li.y > lo.y
		if not good or g.order_in.is_empty():
			lu_ok = false
		if String(lcd).begins_with("sec:"):
			if li.x - lo.x < sec_gap:
				sec_gap = li.x - lo.x
				sec_worst = "%s 루마 %.3f / %.3f · 휘도 %.3f / %.3f%s" % [lcd, li.x, lo.x, li.y, lo.y,
						"" if good else " ✗"]
			if not good:
				lu_txt += "%s ✗ · " % lcd
		else:
			lu_txt += "%s 루마 %.3f / %.3f · 휘도 %.3f / %.3f%s · " % [lcd, li.x, lo.x, li.y, lo.y,
					"" if good else " ✗"]
	lu_txt += "칸 하나 %d가지 중 가장 좁은 %s" % [sv_seen.size(), sec_worst]
	_ok("아홉 영역 다 영역이 나머지보다 밝다 (영역 / 나머지 · 숨 바닥 · 대용 셈)", lu_ok, lu_txt)
	#  흑색 칸뿐인 영역만 세게 민다 — 그 밖은 lit_a · dim_a 그대로다.
	var dk_ok := true
	for dc in [["col:1", true], ["col:0", false], ["double", false], ["small", false],
			["sec:%d" % int(g.sectors[1]), g._sec_col(1) == 1],
			["sec:%d" % int(g.sectors[0]), g._sec_col(0) == 1]]:
		_plain()
		g._order_open(String(dc[0]), 3, _tag("t_gold"), 1)
		if bool(g.order_dk) != bool(dc[1]):
			dk_ok = false
	_ok("흑색 칸뿐인 영역(흑색 칸 · 흑색 칸 하나)만 빛 · 어둠이 세다", dk_ok
			and float(g.ORDER.dk_lit) > float(g.ORDER.lit_a)
			and float(g.ORDER.dk_dim) > float(g.ORDER.dim_a))
	#  ── 홑 띠만으로도 갈린다 (2026-10-06) ──
	#  검토: 흑색 칸 주문의 영역 평균은 띠(트리플 · 더블의 빨강 · 초록)가 끌어올려 나머지를 넘었지만,
	#  판에서 가장 넓은 홑 띠만 놓고 보면 밝힌 흑색 홑 띠와 가라앉은 백색 홑 띠가 거의 같은
	#  밝기였다(dk_dim 0.58 — 1.4:1 밑). 숨 바닥에서 밝힌 흑색 홑 띠 조각(order_in) : 가라앉은
	#  백색 홑 띠 조각(order_off 중 칸 색 0)의 대비 — 선형 상대 휘도의 WCAG 식 — 가 1.5:1 을
	#  넘고 영역 쪽이 밝아야 한다. 흑색 칸(col:1)과 흑색 칸 하나(이 판의 흑색 칸 값 전부).
	#  셈은 위 「영역이 밝은 쪽이다」의 대용(_lum_of)을 홑 띠 조각에만 건다.
	var sg_ok := true
	var sg_txt := ""
	var sg_conds := ["col:1"]
	for si in g._sec_n():
		if g._sec_col(si) == 1 and not sg_conds.has("sec:%d" % int(g.sectors[si])):
			sg_conds.append("sec:%d" % int(g.sectors[si]))
	var sg_worst := INF
	var sg_worst_txt := ""
	for sgc in sg_conds:
		_plain()
		g._order_open(String(sgc), 3, _tag("t_gold"), 1)
		var tn2: Vector2 = g._order_tone()
		var lit_s := []
		var dim_s := []
		for pc in g.order_in:
			if _single(pc):
				lit_s.append(pc)
		for pc in g.order_off:
			if _single(pc) and g._sec_col(_pc_sec(pc)) == 0:
				dim_s.append(pc)
		var yi: float = _lum_of(lit_s, g.DOORT.chalk_ink, tn2.x * br_lo).y
		var yo: float = _lum_of(dim_s, Color.BLACK, tn2.y).y
		var crs: float = (yi + 0.05) / (yo + 0.05)
		if lit_s.is_empty() or dim_s.is_empty() or not g.order_dk or crs < 1.5:
			sg_ok = false
			sg_txt += "%s %.2f:1 ✗ · " % [sgc, crs]
		if crs < sg_worst:
			sg_worst = crs
			sg_worst_txt = "%s 휘도 %.4f / %.4f = %.2f:1" % [sgc, yi, yo, crs]
	sg_txt += "%d가지 중 가장 좁은 %s (dk_lit %.2f · dk_dim %.2f)" % [sg_conds.size(), sg_worst_txt,
			float(g.ORDER.dk_lit), float(g.ORDER.dk_dim)]
	_ok("흑색 칸 · 흑색 칸 하나 — 밝힌 흑색 홑 띠 : 가라앉은 백색 홑 띠 ≥ 1.5:1 (숨 바닥)", sg_ok, sg_txt)
	var src := FileAccess.get_file_as_string("res://scripts/game.gd")
	var i0: int = src.find("func _order_lit_e")
	var i1: int = src.find("func _to_pick", i0)
	var body: String = src.substr(i0, i1 - i0)
	_ok("그리는 자가 글을 한 자도 안 띄운다", i0 > 0 and i1 > i0
			and body.find("draw_string") < 0 and body.find("pop(") < 0)
	_ok("새 색을 안 만든다", body.find("Color(\"") < 0 and body.find("Color.from") < 0)
	_ok("난수를 안 굴린다", body.find("randf") < 0 and body.find("randi") < 0
			and body.find("run_rng") < 0)
