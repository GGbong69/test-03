extends SceneTree

#  스펙 정합 프로브 (HIGHTONE 통합 컨텍스트 2026-08-23)
#
#  이번에 새로 낸 경로 넷을 잰다. 넷 다 확정 규칙에서 나왔고, 어느 것도
#  기존 프로브가 안 보던 자리다.
#
#    ① 창구 확정이 눌렀다 뗄 때 실행되는가 (아이템 구매·사용 = release)
#    ② 동전 슬롯 드래그 재정렬이 순서를 실제로 바꾸는가 (아이템순서변경=True)
#       — 함수만이 아니라 **마우스 경로로**, 화면별로 잰다
#    ③ 사탕 — 사면 칸에 들어가고, 쓰면 트랙 레벨이 오르는가
#    ④ 조건 missp — 직전 투척이 빗나갔을 때만 서는가 (스펙 100003)
#
#  실행:  godot --path . --headless -s scripts/tools/spec_probe.gd

const GameData = preload("res://scripts/data.gd")

var g = null
var step := 0
var fails := 0


func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _ok(name: String, cond: bool, detail: String) -> void:
	print("  %s %-28s %s" % ["OK  " if cond else "실패", name, detail])
	if not cond:
		fails += 1


func _chute_pt(right: bool) -> Vector2:
	return Vector2(634.0 if right else 6.0, (g.TBL.fy + g.TBL.ny) * 0.5)


func _process(_d: float) -> bool:
	step += 1
	if step < 12:
		return false

	g.gold = 99
	g._open_shop()
	g._drop_settle()

	# ── ① 창구 커밋은 release 다. 마우스 경로(_hand_press/_hand_release)로
	#      누르기만 하면 안 팔리고, 같은 창구 안에서 떼야 팔린다.
	g._autoplay = false          # _hand_press 가 오토플레이를 걸러내므로 끈다
	g.owned = [GameData.items()[0], GameData.items()[1], GameData.items()[2]]
	g._panel_reset()
	g._click(g._slot_rect(0).get_center())
	var g0: int = g.gold
	var took: bool = g._hand_press(_chute_pt(false))
	_ok("창구 누름 → 아직 안 판다", took and g.gold == g0 and g.owned.size() == 3,
			"press 삼킴 %s · 골드 %d · 기본 점수 %d" % [took, g.gold, g.owned.size()])
	g._hand_release(Vector2(320.0, 180.0))      # 창구 밖에서 뗌 = 취소
	_ok("창구 밖에서 뗌 → 취소", g.gold == g0 and g.owned.size() == 3,
			"골드 %d · 기본 점수 %d" % [g.gold, g.owned.size()])
	g._click(g._slot_rect(0).get_center())      # 다시 고른다 (탭이 풀렸을 수 있다)
	if g.sell_sel != 0:
		g._click(g._slot_rect(0).get_center())
	g._hand_press(_chute_pt(false))
	g._hand_release(_chute_pt(false))           # 같은 창구 안에서 뗌 = 판매
	_ok("창구 안에서 뗌 → 판매", g.gold > g0 and g.owned.size() == 2,
			"골드 %d → %d · 기본 점수 %d" % [g0, g.gold, g.owned.size()])

	# ── ② 동전 슬롯 재정렬 — 0번을 맨 뒤로 끼우면 순서가 민다
	g.owned = [GameData.items()[0], GameData.items()[1], GameData.items()[2]]
	g._panel_reset()
	var n0: String = g.owned[0].n
	var n1: String = g.owned[1].n
	g._rack_reorder(0, 2)
	_ok("재정렬 0 → 2", g.owned[0].n == n1 and g.owned[2].n == n0,
			"순서 [%s, %s, %s]" % [g.owned[0].n, g.owned[1].n, g.owned[2].n])

	# ── ②-b 재정렬을 **마우스 경로로** 잰다. _rack_reorder 를 직접 부르면
	#      "함수가 도는가" 만 알 뿐, 손이 거기까지 닿는지는 안 잰다 —
	#      그 사이에 상태 잠금 셋이 있었고, 판에서는 하나도 안 열렸다.
	for row in [["SHOP", g.S.SHOP, true], ["PICK", g.S.PICK, true],
			["AIM_V", g.S.AIM_V, true], ["LEG", g.S.LEG, true],
			["STAGE", g.S.STAGE, true], ["RESOLVE", g.S.RESOLVE, false]]:
		g.state = row[1]
		g.burst_left = 0
		g.owned = [GameData.items()[0], GameData.items()[1], GameData.items()[2]]
		g._panel_reset()
		var a: String = g.owned[0].n
		var b: String = g.owned[1].n
		var p_from: Vector2 = g._slot_rect(0).get_center()
		var p_to: Vector2 = g._slot_rect(2).get_center()
		g._hand_press(p_from)
		g._hand_motion(p_to)             # HAND.slip 을 넘겨 ARMED → CARRY
		var carried: bool = g.hand_st == g.H.CARRY
		g._hand_release(p_to)
		var moved: bool = g.owned[0].n == b and g.owned[2].n == a
		_ok("%s 에서 끌어 재정렬" % row[0], carried == row[2] and moved == row[2],
				"집힘 %s · 순서 [%s, %s, %s]"
				% [carried, g.owned[0].n, g.owned[1].n, g.owned[2].n])
	g.state = g.S.SHOP

	# ── ③ 사탕 — 산다 · 칸에 선다 · 쓰면 트랙이 오른다
	var pool: Array = GameData.consumables()
	_ok("사탕 표", pool.size() >= 5, "%d종 (트랙 강화 5 + 스티커 2 중 활성)" % pool.size())
	var ci := -1
	for i in g.stock.size():
		if g.stock[i].type == "cons":
			ci = i
			break
	if ci < 0:
		# 테이블에 안 떴으면 직접 심는다 — 여기서 재는 것은 등장 확률이 아니라 경로다
		g.stock[0] = {"type": "cons", "d": pool[0], "cost": pool[0].cost, "sold": false}
		ci = 0
	var cg: int = g.gold
	g._buy(ci)
	_ok("사탕 구매 → 칸", g.cons.size() == 1 and g.gold == cg - g.stock[ci].cost,
			"칸 %d/%d · 골드 %d" % [g.cons.size(), GameData.cons_slots(), g.gold])
	var trk: int = g.cons[0].track
	var lv0: int = int(g.track_lv.get(trk, 0))
	g._cons_use(0)
	_ok("사용 → 트랙 레벨 +1", int(g.track_lv.get(trk, 0)) == lv0 + 1 and g.cons.is_empty(),
			"트랙 %d Lv %d → %d · 칸 %d" % [trk, lv0, int(g.track_lv.get(trk, 0)), g.cons.size()])

	# ── ④ missp — 직전이 빗나갔을 때만. 이번이 빗나가도 산다(연속 빗나감).
	var hit_prev_miss := GameData.check("missp",
			{"miss": false, "missp": true, "sector": 20, "mult": 1})
	var hit_prev_ok := GameData.check("missp",
			{"miss": false, "missp": false, "sector": 20, "mult": 1})
	var miss_prev_miss := GameData.check("missp",
			{"miss": true, "missp": true, "sector": -1, "mult": 0})
	var plain_on_miss := GameData.check("always",
			{"miss": true, "missp": false, "sector": -1, "mult": 0})
	_ok("missp 판정", hit_prev_miss and not hit_prev_ok and miss_prev_miss
			and not plain_on_miss,
			"명중+직전빗 %s · 명중+직전명중 %s · 연속빗나감 %s · 빗나감에 always %s"
			% [hit_prev_miss, hit_prev_ok, miss_prev_miss, plain_on_miss])

	# ⑨ 툴팁이 폭을 안 넘는다 — draw_string 은 폭을 넘으면 자를 뿐이라
	#    "던질 때마다 −5" 의 −5 가 통째로 사라져 있었다. 폭은 고정이고
	#    넘치면 아래로 늘어난다.
	g._tip_clear()
	g.tip_title = "긴 설명"
	g._tip_add("점수 +100 에서 시작 · 던질 때마다 −5", 11, g.C_TXT)
	var wrapped: int = g.tip_lines[0].wr.size()
	var over := 0
	for seg in g.tip_lines[0].wr:
		if g.font.get_string_size(seg, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x \
				> g.TIP.w - g.TIP.pad * 2.0 + 0.5:
			over += 1
	var tall: float = g._tip_size().y
	g._tip_clear()
	g.tip_title = "짧은 설명"
	g._tip_add("점수 +5", 11, g.C_TXT)
	var short: float = g._tip_size().y
	_ok("툴팁이 폭을 안 넘고 아래로 는다", wrapped >= 2 and over == 0 and tall > short,
			"%d줄 · 넘친 줄 %d · 높이 %.0f > %.0f" % [wrapped, over, tall, short])
	g._tip_clear()

	# ⑩ 칸 색 — 기본 배치는 실물 다트판대로 교대이고, 화면과 판정이
	#    같은 배열을 읽는다. 불·아웃은 색이 없다(-1).
	var base_alt := true
	for i in g.sec_col.size():
		if int(g.sec_col[i]) != i % 2:
			base_alt = false
	var bull: Dictionary = g.hit_info(g.BC)
	var out: Dictionary = g.hit_info(g.BC + Vector2(g.R * 2.0, 0.0))
	var wedge: Dictionary = g.hit_info(g.BC + Vector2(0.0, -g.R * 0.5))
	_ok("칸 색 기본 배치", base_alt and g.sec_col.size() == 20,
			"%d칸 · 교대 %s" % [g.sec_col.size(), base_alt])
	_ok("불·아웃은 색이 없다", int(bull.col) == -1 and int(out.col) == -1,
			"불 %d · 아웃 %d" % [int(bull.col), int(out.col)])
	_ok("칸은 표의 색을 돌려준다",
			int(wedge.col) == g._sec_col(int(wedge.idx))
			and int(wedge.col) >= 0 and int(wedge.col) < GameData.color_n(),
			"%d번 칸 색 %d / %d종" % [int(wedge.sector), int(wedge.col),
			GameData.color_n()])
	# 조건은 색을 읽는다 — 맞는 색이면 서고 다른 색이면 안 선다
	var cx := {"sector": 20, "mult": 1, "miss": false, "col": 2}
	_ok("색 조건이 색을 가린다",
			GameData.check("col:2", cx) and not GameData.check("col:0,1", cx)
			and GameData.check("col:1,2", cx),
			"col:2 참 · col:0,1 거짓 · col:1,2 참")

	print("%s" % ("열셋 검사 전부 통과" if fails == 0 else "실패 %d건" % fails))
	quit(1 if fails > 0 else 0)
	return false
