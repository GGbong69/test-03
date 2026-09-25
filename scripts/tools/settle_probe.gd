extends SceneTree

const GameData = preload("res://scripts/data.gd")

# ══════════════════════════════════════════════════════════
#  정산 큐 · 판 종료 회귀 검사
#
#  실행:  godot --path . --headless --script scripts/tools/settle_probe.gd
#  종료 코드 = 실패 개수
#
#  세 결함을 못 박는다. 셋 다 오토플레이가 오류 0으로 통과시켰고, 화면에도
#  아무 일이 안 일어나서 눈으로는 안 보였다 — 조용히 지나가는 종류다.
#    ① mult_rand 가 정산 match 에 갈래가 없어 배수에 안 실렸다
#       (표는 그 카드를 87장 중 4위로 적고 있었다)
#    ② owned 에서 기본 점수를 뺄 때 sealed 를 안 밀어 엉뚱한 기본 점수가 봉인으로 읽혔다
#       (헬퍼가 아니라 호출부 — 마모·목숨 — 를 밟는다. 봉인된 목숨도 본다)
#    ③ 마지막 판에서 목숨이 터지면 완주 검사를 건너뛰어
#       빈 상점과 유령 9판이 열렸다
#    ④ 점수판이 애니메이션 값을 버려 45 를 "44 / 45" 로 적었다
#    ⑤ 상점이 다음 판 행의 폭을 읽어 7판 뒤 테이블이 통째로 비었다
#    ⑥ 제약 카드는 테이블에 눕는다. 히트 칸이 **쉬는 모습**(누운 카드)이어야
#       아직 안 선 카드의 허공을 눌러도 안 잡힌다
# ══════════════════════════════════════════════════════════

var fails := 0


func _say(ok: bool, name: String, detail := "") -> void:
	print("  %s %-30s %s" % ["OK  " if ok else "실패", name, detail])
	if not ok:
		fails += 1


# 2026-09-06 에 동전 표가 통째로 갈리면서 여기 박아 둔 id 다섯이 한꺼번에
# 죽었다. 이 검사가 보는 것은 특정 동전이 아니라 **갈래** 다 — 무작위 배수 ·
# 판마다 닳는 것 · 목숨 · 평범한 점수. 그래서 id 대신 모양으로 찾는다.
func _item(id: String) -> Dictionary:
	for it in GameData.items():
		if String(it.id) == id:
			return it.duplicate()
	push_error("settle_probe: 동전 '%s' 가 표에 없다" % id)
	return {}


func _by_kind(k: String) -> Dictionary:
	for it in GameData.items():
		if String(it.get("k", "")) == k:
			return it.duplicate()
	push_error("settle_probe: 효과 '%s' 인 동전이 표에 없다" % k)
	return {}


func _by_grow(gw: String) -> Dictionary:
	for it in GameData.items():
		if String(it.get("grow", "")) == gw:
			return it.duplicate()
	push_error("settle_probe: 성장 '%s' 인 동전이 표에 없다" % gw)
	return {}


# 조건도 성장도 안 걸린 평범한 점수 동전. 봉인이 따라가는지만 보는
# 자리라 무엇이든 되지만 서로 달라야 한다 — 같은 id 둘이면 "따라갔다" 가
# 우연히 맞을 수 있다.
func _plain(nth: int) -> Dictionary:
	var seen := 0
	for it in GameData.items():
		if String(it.get("k", "")) == "chip" and String(it.get("grow", "")) == "" 				and String(it.get("aim", "")) == "" and String(it.get("per", "")) == "":
			if seen == nth:
				return it.duplicate()
			seen += 1
	push_error("settle_probe: 평범한 점수 동전이 %d장도 없다" % (nth + 1))
	return {}


func _initialize() -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)

	# ① mult_rand 가 배수에 실린다 — 정산 큐에 직접 넣고 한 걸음 돌린다
	g.owned = [_by_kind("mult_rand")]  # 무작위 배수
	g._panel_reset()
	g.cur_chip = 10
	g.cur_mult = 1
	g.queue = [{"k": "item", "i": 0, "kind": "mult_rand", "v": 7, "lbl": "오차 인쇄"}]
	g._next_step()
	_say(g.cur_mult == 8, "mult_rand 가 배수를 올린다", "1 + 7 → %d" % g.cur_mult)
	# 모르는 효과는 조용히 사라지지 않고 소리를 낸다
	g.cur_mult = 1
	g.queue = [{"k": "item", "i": 0, "kind": "nosuch", "v": 5, "lbl": "x"}]
	g._next_step()
	_say(g.cur_mult == 1, "모르는 효과는 점수에 안 실린다 (에러 한 줄이 위에 뜬다)",
			"cur_mult %d" % g.cur_mult)

	# ② 봉인이 기본 점수를 따라간다 — 헬퍼를 직접 부르면 산술만 재고 끝난다.
	# 결함이 있던 자리는 호출부(_leg_end_wear · _finish_leg)이므로
	# 거기를 실제로 밟는다. rdec 이 0 에 닿아 앞자리가 부서지는 판다.
	var dec: Dictionary = _by_grow("rdec")  # 판마다 닳다가 0 이면 부서진다
	# 다음 한 걸음에 0 에 닿게 맞춘다. 값을 박으면 표가 바뀔 때 또 깨진다 —
	# 그 동전 제 값에서 걸음 수를 역산한다.
	dec.gs = maxi(0, int(dec.v / maxi(int(dec.gstep), 1)) - 1)
	g.owned = [dec, _plain(0), _plain(1)]
	g._panel_reset()
	g.sealed = 2
	var keep: String = String(g.owned[2].id)
	g._leg_end_wear()
	var ok2: bool = g.owned.size() == 2 and g.sealed == 1 \
			and String(g.owned[g.sealed].id) == keep
	_say(ok2, "판 마모가 봉인을 민다", "기본 점수 %d장 · sealed %d → %s"
			% [g.owned.size(), g.sealed,
			String(g.owned[g.sealed].id) if g.sealed >= 0 else "-"])

	# 봉인된 기본 점수는 목숨을 안 쓴다 — 봉인은 발동을 막는 것이고 목숨도 발동이다
	g.leg_no = 3
	g.target = 1000
	g.total = 900
	g.owned = [_by_kind("save")]            # 목숨
	g._panel_reset()
	g.sealed = 0
	g.won = false
	g._finish_leg()
	_say(g.state == g.S.OVER and not g.won, "봉인된 목숨은 안 터진다",
			"state %d · 기본 점수 %d장" % [g.state, g.owned.size()])

	# 목숨이 터지면 봉인도 같이 정리된다 — 봉인이 뒷자리일 때
	g.leg_no = 3
	g.total = 900
	g.owned = [_by_kind("save"), _plain(0)]
	g._panel_reset()
	g.sealed = 1
	g._finish_leg()
	_say(g.sealed == 0 and g.owned.size() == 1, "목숨이 터져도 봉인이 기본 점수를 따라간다",
			"sealed %d · 기본 점수 %d장" % [g.sealed, g.owned.size()])

	# ③ 마지막 판에서 목숨이 터져도 완주다
	g.sealed = -1
	g.leg_no = GameData.legs_n()
	g.target = 1000
	g.total = 900
	g.owned = [_by_kind("save")]       # 목숨 — 목표의 v% 이상이면 실패를 무른다
	g._panel_reset()
	g.won = false
	g._finish_leg()
	_say(g.state == g.S.OVER and g.won, "마지막 판 목숨 = 완주",
			"state %d · won %s · round %d" % [g.state, g.won, g.leg_no])

	# ③-b 마지막이 아니면 정산으로 간다
	g.leg_no = 3
	g.target = 1000
	g.total = 900
	g.owned = [_by_kind("save")]
	g._panel_reset()
	g._finish_leg()
	_say(g.state == g.S.CLEAR, "그 앞 판은 정산으로", "state %d" % g.state)

	# ④ 점수판은 목표에 닿으면 목표를 적는다. lerp 는 밑에서 수렴하므로
	#    버리면 45 가 영원히 44 로 보인다 — 반올림하고 반 점 안에서 붙인다.
	g.total = 45
	g.target = 45
	g.shown = 0.0
	for _i2 in 600:
		g._tick_score(1.0 / 60.0)
	_say(g.shown == 45.0 and int(round(g.shown)) == 45,
			"점수판이 목표에 닿으면 목표를 적는다",
			"shown %.4f → %d" % [g.shown, int(round(g.shown))])

	# ⑤ 상점 폭은 그 판 **뒤**의 것이다 — 마지막 앞 판에도 테이블이 선다
	var last: int = GameData.legs_n()
	g.leg_no = last - 1
	g.gold = 99
	g.owned = []
	g.mods_own = []
	g._panel_reset()
	g._roll_stock()
	# 테이블 자리는 정확히 넷이다(_table_draw 의 ax/ay 가 그 수를 전제한다).
	# 팩·사진·공짜 한 장은 그 넷 **바깥**에 얹히므로 매물 수 전체를 세면
	# 안 된다 — 팩이 붙은 날 이 검사가 5칸을 보고 졌다.
	var deck := 0
	for s in g.stock:
		# 갈래는 이제 자리마다 굴린다(shop.csv). 팩도 사진도 그 여섯 중
		# 하나라 빼면 안 된다 — 공짜 해금 보상 한 장만 폭 밖이다.
		if bool(s.get("free", false)):
			continue
		deck += 1
	var want2: int = GameData.shop_slots(g.leg_no)
	_say(deck == want2, "마지막 앞 판에도 테이블 폭이 표대로다",
			"R%d 뒤 테이블 %d칸 (표가 말하는 %d) · 매물 전체 %d칸"
			% [g.leg_no, deck, want2, g.stock.size()])

	# ⑥ 누운 판 카드 — 칸이 펠트 안이고 서로 안 겹치며, 툴팁이 잡힌다
	#    제약 카드가 걷히고 그 자리를 판 카드 셋이 물려받았다(2026-09-18).
	g.sealed = -1
	g._new_run()
	g.leg_no = 3                      # 보스 판이 든 라운드
	g._open_leg()
	var per: int = GameData.legs_per_round()
	var inside := true
	for a in per:
		var ra: Rect2 = g._row_rect(a, per)
		if ra.position.y < g.TBL.fy or ra.end.y > g.TBL.ny:
			inside = false
		for b in per:
			if a != b and ra.intersects(g._row_rect(b, per)):
				inside = false
	_say(inside and per == 3,
			"누운 카드가 펠트 안에 안 겹치게", "%d장" % per)
	var bn: int = g._round_boss()
	_say(bn > 0 and not g.boss_mods.get(bn, PackedStringArray()).is_empty(),
			"보스 카드가 제약을 든다",
			"%d번 판 %s" % [bn, g.boss_mods.get(bn, PackedStringArray())])
	# 툴팁의 대상 사각은 남고 테두리만 빠진다. _row_rect 는 축정렬 사각인데
	# 카드는 펠트를 따라 좁아진 사다리꼴이라 흰 테가 몇 px 어긋난다 —
	# 눈으로만 보이는 사고라 여기서 못 박는다.
	var bi: int = GameData.leg_idx(bn)
	g._tip_build({"k": "legboss", "i": bn})
	_say(g.tip_mark == g._row_rect(bi, per) and not g.tip_box,
			"보스 카드에는 테두리를 안 두른다",
			"사각 %s · 테두리 %s" % [g.tip_mark == g._row_rect(bi, per), g.tip_box])
	g._tip_clear()
	_say(g.tip_box and g.tip_mark == Rect2(),
			"툴팁이 꺼지면 기본값으로 돌아온다")

	# 딜이 끝나기 전에는 카드 툴팁을 안 잡는다 — 움직이는 것을 가리키면
	# 무엇을 가리켰는지가 커서와 카드 중 어느 쪽 기준인지 갈린다.
	g.leg_t = 0.0
	_say(g._tip_hit(g._row_rect(bi, per).get_center()).is_empty(),
			"딜 중에는 보스 카드를 안 잡는다")
	g.leg_t = g._deal_time() + 0.1
	var hit: Dictionary = g._tip_hit(g._row_rect(bi, per).get_center())
	_say(String(hit.get("k", "")) == "legboss" and int(hit.get("i", 0)) == bn,
			"딜이 끝나면 누운 칸이 보스 카드를 잡는다", "%s" % hit)

	# ── 큐의 새 키 "mx" 는 **선택이다** (2026-09-25) ───────────
	#  정산 출처 짚기가 chip · mult 걸음에 「판이 낸 값에 무언가 얹혔나」를
	#  한 칸으로 싣는다. 걸음 쪽이 그것을 **필수로** 읽으면 큐를 손으로
	#  짓는 도구 여섯(여기 · card_shots · dev_probe · mod_probe · bal_shots)이
	#  그 자리에서 한꺼번에 죽는다. 없으면 0 = 흰색이라는 것을 여기서 못 박는다.
	g.owned = []
	g._panel_reset()
	g.state = g.S.RESOLVE
	g.cur_chip = 0
	g.cur_mult = 0
	g.src_t = 0.0
	g.src_mix = true                       # 안 지워지면 여기서 드러난다
	g.queue = [{"k": "chip", "v": 40}]     # mx 없음 — 옛 도구가 짓는 꼴 그대로
	g._next_step()
	_say(g.cur_chip == 40 and not g.src_mix and g.src_t > 0.0,
			"큐의 mx 가 없어도 안 죽는다", "점수 %d · 얹힘 %s · 빛 %.2f"
			% [g.cur_chip, g.src_mix, g.src_t])
	# 0 만큼 바뀐 걸음은 안 밝는다 — 빗나간 발의 info.base 가 0 인 chip 걸음에서
	# 판을 밝히면 「점수가 났다」고 거짓말한다.
	g.src_t = 0.0
	g.cur_chip = 0
	g.queue = [{"k": "chip", "v": 0, "mx": 0}]
	g._next_step()
	_say(is_zero_approx(g.src_t), "0 만큼 바뀐 chip 걸음은 판을 안 밝힌다",
			"빛 %.2f" % g.src_t)
	g.src_t = 0.0
	g.cur_mult = 5
	g.queue = [{"k": "mult", "v": 5, "mx": 0}]   # 같은 값 재대입
	g._next_step()
	_say(is_zero_approx(g.src_t), "같은 값을 다시 대입하는 mult 걸음도 안 밝힌다",
			"빛 %.2f" % g.src_t)
	# mx 가 1 이면 색이 갈린다 — 판이 낸 값에 무언가 얹혔다.
	g.cur_mult = 0
	g.queue = [{"k": "mult", "v": 3, "mx": 1}]
	g._next_step()
	_say(g.src_ring and g.src_mix and g.src_t > 0.0,
			"mult 걸음은 고리를, mx 1 은 얹힘 색을 켠다",
			"고리 %s · 얹힘 %s" % [g.src_ring, g.src_mix])

	# ── 카드의 이름 줄이 걸음을 건너 안 산다 (2026-09-25) ──────
	#  card_item 을 세우는 갈래는 다섯인데 chip · mult 가 그것을 안 지웠다 —
	#  점수가 나는 빗나감의 큐 [miss, chip, mult, …] 에서 「빗나감」이 양수
	#  점수 옆에 0.68초 더 서 있었다.
	g.cur_chip = 0
	g.cur_mult = 0
	g.card_item = ""
	g.queue = [{"k": "miss"}, {"k": "chip", "v": 12, "mx": 0},
			{"k": "mult", "v": 1, "mx": 0}]
	g._next_step()
	var lbl_miss: String = String(g.card_item)
	g._next_step()
	var lbl_chip: String = String(g.card_item)
	g._next_step()
	var lbl_mult: String = String(g.card_item)
	_say(lbl_miss != "" and lbl_chip == "" and lbl_mult == "",
			"「빗나감」이 다음 걸음으로 안 샌다",
			"miss '%s' → chip '%s' → mult '%s'" % [lbl_miss, lbl_chip, lbl_mult])
	# 제 라벨을 세우는 갈래는 한 픽셀도 안 바뀐다.
	g.queue = [{"k": "pierce", "v": 4}]
	g._next_step()
	_say(String(g.card_item) != "", "제 라벨을 세우는 갈래는 그대로",
			"'%s'" % g.card_item)

	# ── 출처가 **맞는 물건**을 짚는가 (2026-09-25) ─────────────
	#  이 일의 치명상이 여기다 — 틀린 칸이나 틀린 고리를 밝히면 연출이
	#  거짓말을 하는 것이고, 그건 아무것도 안 밝히는 것보다 나쁘다.
	#  실제로 한 발을 꽂아 hit_info 의 진실과 화면이 짚는 자리를 댄다.
	g.state = g.S.RESOLVE
	g.owned = []
	g._panel_reset()
	g.sealed = -1
	g.dead_idx = -1
	g.dead_col = -1
	g.dead_ring = 0
	g.mark_sec = -1
	g.paint_sec = -1
	g.odd_mul = 1.0
	g.track_lv = {}
	g.cur_dart = GameData.darts()[0].duplicate()
	g.total = 0
	g.target = 99999          # 판이 안 끝나게 — 깨짐과 안 섞인다
	#  칸 0(맨 위)의 트리플 한가운데. 판의 각은 위에서 재고 칸 0 의
	#  한가운데가 곧 0 이다.
	var trp: float = g.R * (g.rt_trp_in + g.rt_trp_out) * 0.5
	var pt: Vector2 = g.BC + Vector2(0.0, -trp)
	var truth: Dictionary = g.hit_info(pt)
	g.aim = pt
	g.queue = []
	g.burst_hits = []
	g._land()
	_say(int(g.hit_idx) == int(truth.idx)
			and is_equal_approx(float(g.hit_r0), float(truth.r0))
			and is_equal_approx(float(g.hit_r1), float(truth.r1)),
			"판이 짚는 자리가 hit_info 의 진실과 같다",
			"칸 %d/%d · 고리 %.1f~%.1f" % [g.hit_idx, int(truth.idx),
					g.hit_r0, g.hit_r1])
	#  걸음을 하나씩 파며 모양이 축을 말하는지 본다.
	var shape := []
	while not (g.queue as Array).is_empty():
		var nk := String((g.queue as Array)[0].get("k", ""))
		g.src_t = 0.0
		g._next_step()
		if nk == "chip" or nk == "mult":
			shape.append([nk, g.src_t > 0.0, g.src_ring, g.src_mix])
	var shape_ok := true
	for e in shape:
		if String(e[0]) == "chip" and (not bool(e[1]) or bool(e[2]) or bool(e[3])):
			shape_ok = false
		if String(e[0]) == "mult" and (not bool(e[1]) or not bool(e[2]) or bool(e[3])):
			shape_ok = false
	_say(shape_ok and shape.size() == 2,
			"chip 은 부채 · mult 는 고리 · 얹힌 것이 없으면 흰색",
			"%s" % str(shape))
	#  판 위에 무언가 얹히면 색이 갈린다 — 칠(점수 쪽)과 링 죽이기(배수 쪽).
	g.paint_sec = int(truth.idx)
	g.paint_mul = 2.0
	g.dead_ring = int(truth.mult)
	g.total = 0
	g.queue = []
	g.aim = pt
	g._land()
	var mix := []
	while not (g.queue as Array).is_empty():
		var nk2 := String((g.queue as Array)[0].get("k", ""))
		g._next_step()
		if nk2 == "chip" or nk2 == "mult":
			mix.append([nk2, g.src_mix])
	var mix_ok := mix.size() == 2
	for e2 in mix:
		if not bool(e2[1]):
			mix_ok = false
	_say(mix_ok, "판 위에 얹힌 것이 있으면 두 걸음 다 얹힘 색",
			"%s — 칠 x2.0 · 링 죽이기 %d" % [str(mix), int(truth.mult)])
	g.paint_sec = -1
	g.dead_ring = 0

	# ── 넓은 띠는 **안팎 경계만** 칠한다 (2026-09-25) ──────────
	#  띠 통째로 칠하면 싱글에서 무너진다: 안쪽 싱글이 0.42R(41px) ·
	#  바깥 싱글이 0.24R 이라 판의 3분의 1이 흰 물에 잠기고, 넓이 × 알파로
	#  재면 가장 값싼 싱글이 트리플보다 크게 빛나 세기 사다리가 뒤집힌다.
	#  ⓐ 갈리는 띠가 싱글 둘뿐이고 ⓑ 트리플 · 더블은 통째로 남으며
	#  ⓒ 갈릴 때 두 겹이 안 겹치는 것을 잰다 — 겹치면 알파가 두 번 얹혀
	#  0.9 가 0.99 로 뜬다.
	var ew: float = g.R * g.SRC_EDGE
	#  넷째 칸 = 그려야 하는 겹 수(통째로 1 · 갈리면 2 · 안쪽 경계가 점이면 1).
	#  마지막 줄은 **도넛**이다 — 불을 지워 안쪽 싱글의 r0 가 0 이라,
	#  안 막으면 판 한복판에 아무것도 안 가리키는 점이 하나 뜬다.
	var bands := [
		["안쪽 싱글", g.R * g.rt_bull_o, g.R * g.rt_trp_in, 2],
		["바깥 싱글", g.R * g.rt_trp_out, g.R * g.rt_dbl_in, 2],
		["트리플", g.R * g.rt_trp_in, g.R * g.rt_trp_out, 1],
		["더블", g.R * g.rt_dbl_in, g.R * g.rt_dbl_out, 1],
		["도넛 안쪽", 0.0, g.R * g.rt_trp_in, 1],
	]
	var geo_ok := true
	var geo := []
	for b in bands:
		var br0: float = float(b[1])
		var br1: float = float(b[2])
		var split: bool = (br1 - br0) > ew * 2.0
		var arcs: int = 1
		if split:
			arcs = 2 if br0 > ew else 1
		if arcs != int(b[3]):
			geo_ok = false
		if split and br0 > ew and br0 + ew > br1 - ew:
			geo_ok = false
		geo.append("%s %.1f 겹%d" % [String(b[0]), br1 - br0, arcs])
	_say(geo_ok, "넓은 띠만 안팎 경계로 갈린다 — 트리플 · 더블은 통째로",
			"경계 %.1fpx · %s" % [ew, " · ".join(geo)])

	print("\n%s" % ("실패 %d건" % fails if fails > 0 else "스물여섯 검사 전부 통과"))
	quit(mini(fails, 125))
