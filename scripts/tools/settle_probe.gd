extends SceneTree

const GameData = preload("res://scripts/data.gd")

# ══════════════════════════════════════════════════════════
#  정산 큐 · 라운드 종료 회귀 검사
#
#  실행:  godot --path . --headless --script scripts/tools/settle_probe.gd
#  종료 코드 = 실패 개수
#
#  세 결함을 못 박는다. 셋 다 오토플레이가 오류 0으로 통과시켰고, 화면에도
#  아무 일이 안 일어나서 눈으로는 안 보였다 — 조용히 지나가는 종류다.
#    ① mult_rand 가 정산 match 에 갈래가 없어 배수에 안 실렸다
#       (표는 그 카드를 87장 중 4위로 적고 있었다)
#    ② owned 에서 칩을 뺄 때 sealed 를 안 밀어 엉뚱한 칩이 봉인으로 읽혔다
#       (헬퍼가 아니라 호출부 — 마모·목숨 — 를 밟는다. 봉인된 목숨도 본다)
#    ③ 마지막 라운드에서 목숨이 터지면 완주 검사를 건너뛰어
#       빈 상점과 유령 9라운드가 열렸다
#    ④ 점수판이 애니메이션 값을 버려 45 를 "44 / 45" 로 적었다
#    ⑤ 상점이 다음 라운드 행의 폭을 읽어 7라운드 뒤 매대가 통째로 비었다
#    ⑥ 제약 카드는 테이블에 눕는다. 히트 칸이 **쉬는 모습**(누운 카드)이어야
#       아직 안 선 카드의 허공을 눌러도 안 잡힌다
# ══════════════════════════════════════════════════════════

var fails := 0


func _say(ok: bool, name: String, detail := "") -> void:
	print("  %s %-30s %s" % ["OK  " if ok else "실패", name, detail])
	if not ok:
		fails += 1


func _item(id: String) -> Dictionary:
	for it in GameData.items():
		if String(it.id) == id:
			return it.duplicate()
	return {}


func _initialize() -> void:
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)

	# ① mult_rand 가 배수에 실린다 — 정산 큐에 직접 넣고 한 걸음 돌린다
	g.owned = [_item("j036")]          # 오차 인쇄 — 배수 +0~23 무작위
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

	# ② 봉인이 칩을 따라간다 — 헬퍼를 직접 부르면 산술만 재고 끝난다.
	# 결함이 있던 자리는 호출부(_round_end_wear · _finish_round)이므로
	# 거기를 실제로 밟는다. rdec 이 0 에 닿아 앞자리가 부서지는 라운드다.
	var dec: Dictionary = _item("j040")     # 소모성 증폭기 — rdec 4, 값 20
	dec.gs = 4                              # 다음 걸음에 20 − 4*5 ≤ 0 → 파괴
	g.owned = [dec, _item("dbl"), _item("bnd")]
	g._panel_reset()
	g.sealed = 2
	var keep: String = String(g.owned[2].id)
	g._round_end_wear()
	var ok2: bool = g.owned.size() == 2 and g.sealed == 1 \
			and String(g.owned[g.sealed].id) == keep
	_say(ok2, "라운드 마모가 봉인을 민다", "칩 %d장 · sealed %d → %s"
			% [g.owned.size(), g.sealed,
			String(g.owned[g.sealed].id) if g.sealed >= 0 else "-"])

	# 봉인된 칩은 목숨을 안 쓴다 — 봉인은 발동을 막는 것이고 목숨도 발동이다
	g.round_no = 3
	g.target = 1000
	g.total = 900
	g.owned = [_item("j099")]               # 비상 골격
	g._panel_reset()
	g.sealed = 0
	g.won = false
	g._finish_round()
	_say(g.state == g.S.OVER and not g.won, "봉인된 목숨은 안 터진다",
			"state %d · 칩 %d장" % [g.state, g.owned.size()])

	# 목숨이 터지면 봉인도 같이 정리된다 — 봉인이 뒷자리일 때
	g.round_no = 3
	g.total = 900
	g.owned = [_item("j099"), _item("bnd")]
	g._panel_reset()
	g.sealed = 1
	g._finish_round()
	_say(g.sealed == 0 and g.owned.size() == 1, "목숨이 터져도 봉인이 칩을 따라간다",
			"sealed %d · 칩 %d장" % [g.sealed, g.owned.size()])

	# ③ 마지막 라운드에서 목숨이 터져도 완주다
	g.sealed = -1
	g.round_no = GameData.rounds_n()
	g.target = 1000
	g.total = 900
	g.owned = [_item("j099")]          # 비상 골격 — 목표의 v% 이상이면 실패를 무른다
	g._panel_reset()
	g.won = false
	g._finish_round()
	_say(g.state == g.S.OVER and g.won, "마지막 라운드 목숨 = 완주",
			"state %d · won %s · round %d" % [g.state, g.won, g.round_no])

	# ③-b 마지막이 아니면 정산으로 간다
	g.round_no = 3
	g.target = 1000
	g.total = 900
	g.owned = [_item("j099")]
	g._panel_reset()
	g._finish_round()
	_say(g.state == g.S.CLEAR, "그 앞 라운드는 정산으로", "state %d" % g.state)

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

	# ⑤ 상점 폭은 그 라운드 **뒤**의 것이다 — 마지막 앞 라운드에도 매대가 선다
	var last: int = GameData.rounds_n()
	g.round_no = last - 1
	g.gold = 99
	g.owned = []
	g.mods_own = []
	g._panel_reset()
	g._roll_stock()
	_say(g.stock.size() == 4, "마지막 앞 라운드에도 매대가 넷",
			"R%d 뒤 매물 %d칸" % [g.round_no, g.stock.size()])

	# ⑥ 누운 제약 카드 — 칸이 펠트 안이고 서로 안 겹치며, 눌러서 골라진다
	g.sealed = -1
	g._new_run()
	g.round_no = 3                      # 보스 판이라 제약 셋이 깔린다
	g._open_stage()
	var inside := true
	for a in g.stage_pick.size():
		var ra: Rect2 = g._stage_rect(a)
		if ra.position.y < g.TBL.fy or ra.end.y > g.TBL.ny:
			inside = false
		for b in g.stage_pick.size():
			if a != b and ra.intersects(g._stage_rect(b)):
				inside = false
	_say(inside and g.stage_pick.size() == 3,
			"누운 카드가 펠트 안에 안 겹치게", "%d장" % g.stage_pick.size())
	_say(g.stage_stand.size() == g.stage_pick.size()
			and float(g.stage_stand[0]) == 0.0,
			"쉬는 카드는 누워 있다", "선 정도 %.2f" % float(g.stage_stand[0]))
	# 마지막 장이 설 때까지는 못 고른다 — 그 규칙을 먼저 확인하고,
	# 딜을 끝낸 뒤 눌러 본다.
	g._click(g._stage_rect(1).get_center())
	_say(g.state == g.S.STAGE and g.active_mods.is_empty(),
			"딜 중에는 안 골라진다", "state %d" % g.state)
	g.stage_t = g._deal_time() + 0.1
	g._click(g._stage_rect(1).get_center())
	_say(g.state != g.S.STAGE and g.active_mods.size() == 1,
			"누운 칸을 눌러 고른다",
			"state %d · 제약 %d" % [g.state, g.active_mods.size()])

	print("\n%s" % ("실패 %d건" % fails if fails > 0 else "열넷 검사 전부 통과"))
	quit(mini(fails, 125))
