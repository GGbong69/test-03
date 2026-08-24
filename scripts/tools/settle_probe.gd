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
#    ③ 마지막 라운드에서 목숨이 터지면 완주 검사를 건너뛰어
#       빈 상점과 유령 9라운드가 열렸다
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

	# ② 봉인이 칩을 따라간다 — 앞자리가 부서지면 인덱스가 밀린다
	g.owned = [_item("trp"), _item("dbl"), _item("bnd")]
	g._panel_reset()
	g.sealed = 2
	var keep: String = String(g.owned[2].id)
	g._seal_drop(0)
	g.owned.remove_at(0)
	var ok2: bool = g.sealed == 1 and String(g.owned[g.sealed].id) == keep
	_say(ok2, "봉인이 칩을 따라간다", "sealed %d → %s" % [g.sealed,
			String(g.owned[g.sealed].id) if g.sealed >= 0 else "-"])
	g.sealed = 1
	g._seal_drop(1)
	_say(g.sealed == -1, "봉인 대상이 부서지면 풀린다", "sealed %d" % g.sealed)

	# ③ 마지막 라운드에서 목숨이 터져도 완주다
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

	print("\n%s" % ("실패 %d건" % fails if fails > 0 else "다섯 검사 전부 통과"))
	quit(mini(fails, 125))
