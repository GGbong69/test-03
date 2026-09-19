extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  동전의 죽음 QA — 부서짐과 「남았다」를 수로 잰다   (2026-09-19)
#
#  실행:  godot --path . --headless --script scripts/tools/qa_wreck.gd
#  종료 코드 = 실패 개수
#
#  **노드도 뷰포트도 타이머도 await 도 하나도 안 만든다.** CARDFX 머리말이
#  이미 글로 적어 둔 규약이고 헤드리스 검사 여섯이 그 위에 서 있다.
#  그리기 함수는 _draw 밖에서 못 부르므로 **선반 자리는 같은 식을 다시
#  세워 재고, 조각은 순수 함수(_wreck_clamp)를 직접 부른다.**
#
#  이 도구가 못 박는 것 셋이 다른 것보다 무겁다.
#    ④ 난수 흐름이 안 바뀌었다 — **밸런스 불변의 유일한 증거**다.
#       qa_deck 은 표를 재는 것이라 이걸 못 잡는다.
#    ① 제거는 여전히 동기다 — qa_grow_step 과 settle_probe 가 거는
#       계약을 한 번 더 못 박는다. 연출이 이 줄을 깨는 설계로 흐르면
#       여기서 멈춘다.
#    ⑧ 박자가 안 늘었다 — _finish_leg 가 **돌아온 자리에서** 잰다.
# ══════════════════════════════════════════════════════════

var g = null
var fails := 0
#  _process 는 프레임마다 돌아온다. 중간에서 스크립트 오류가 나면 quit()
#  까지 못 가고 같은 검사를 영영 다시 돈다 — 로그가 수백 벌로 불어나
#  **진짜 오류 한 줄이 묻힌다**(2026-09-19, 실제로 그랬다). 한 번만 돈다.
var ran := false


func _initialize() -> void:
	Save.path = "user://_qa_wreck.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(nm: String, cond: bool, detail: String) -> void:
	print("  %s %-34s %s" % ["OK  " if cond else "실패", nm, detail])
	if not cond:
		fails += 1


func _find(id: String) -> Dictionary:
	for it in GameData.items():
		if String(it.id) == id:
			return (it as Dictionary).duplicate(true)
	return {}


#  손에 쥐여 준다. bought 를 지금 판으로 놓아 삭음이 안 걸리게 한다 —
#  안 놓으면 검정 리그에서 모든 검사가 perish 로 먼저 죽는다.
func _hold(ids: Array) -> void:
	g.owned.clear()
	g.sealed = -1
	for id in ids:
		var it := _find(String(id))
		it["bought"] = g.leg_no
		g.owned.append(it)
	g._panel_reset()
	g.wreck.clear()
	g.wreck_n = 0
	g.wreck_snd_from = 0


#  시체 시계를 손으로 굴린다. _process 가 없으므로(set_process(false))
#  이 도구는 언제나 제 걸음으로만 시간을 민다.
func _tick(n: int, d := 1.0 / 60.0) -> void:
	for i in n:
		g._wreck_tick(d)


func _why_list() -> Array:
	var out := []
	for e in g.wreck:
		out.append(String(e.why))
	return out


func _process(_d: float) -> bool:
	if ran:
		quit(mini(fails, 125))
		return true
	ran = true
	print("동전의 죽음 검사 — 부서짐과 「남았다」\n")

	# ── ① 제거는 여전히 동기다 ──────────────────────────
	#  qa_grow_step(196·203)·settle_probe(105)가 g._leg_end_wear() 를
	#  시계 없이 부르고 **그 줄 다음에** owned 를 잰다. 시체를 owned 에
	#  눕히거나 제거를 미루는 설계로 흐르면 여기서 즉시 멈춘다.
	g.leg_no = 3
	_hold(["c04", "c04", "c04"])
	for o in g.owned:
		o.gs = int(o.v) / int(o.gstep) - 1       # 다음 판 끝에 0 에 닿는다
	var n_before: int = g.owned.size()
	g._leg_end_wear()
	_ok("제거는 여전히 동기다", g.owned.is_empty() and n_before == 3,
			"%d장 → 그 줄 다음에 %d장" % [n_before, g.owned.size()])
	_ok("시체는 owned 밖에 눕는다", g.wreck.size() == 3,
			"owned 0 · wreck %d" % g.wreck.size())

	# ── ② 갈래가 맞는가 ─────────────────────────────────
	#  파괴 셋 · 소진 · 목숨이 각각 제 낱말을 받고, **거래 둘은
	#  선반에 한 글자도 안 온다.**
	_hold(["c04"])
	g.owned[0].gs = int(g.owned[0].v) / int(g.owned[0].gstep) - 1
	g._leg_end_wear()
	_ok("rdec 는 rdec 다", _why_list() == ["rdec"], str(_why_list()))

	_hold(["c34"])
	g.owned[0].gs = int(g.owned[0].v) / int(g.owned[0].gstep)
	g._wear_spent()
	_ok("tdec 는 spent 다", _why_list() == ["spent"], str(_why_list()))
	_ok("spent 는 수가 없다", g.wreck.size() == 1 and int(g.wreck[0].bn) == 0,
			"bn %d" % (int(g.wreck[0].bn) if g.wreck.size() > 0 else -1))

	#  판매 — 눌렀고 골드를 받았다. 파괴가 아니다.
	_hold(["c04"])
	g.state = g.S.SHOP
	g.sell_sel = 0
	g._sell(0)
	_ok("판매는 선반에 안 온다", g.wreck.is_empty() and g.owned.is_empty(),
			"wreck %d · owned %d" % [g.wreck.size(), g.owned.size()])

	#  태우기 — consumables.csv 문안은 「파괴」인데 **코드는 파는 길**이다
	#  (sell_value 가 골드로 들어오고 Save.bump("sold") 가 오르고 소리도
	#  sell). 눌렀고 값을 받았으니 여기도 거래다. 문안이 코드와 어긋난
	#  것은 보고만 한다 — desc 열은 툴팁 층이 먹는 글이다.
	_hold(["c04"])
	g.state = g.S.SHOP
	g.photo_rack = "burn"
	g.photo_v = 1.0
	g._photo_apply("burn", 0)
	_ok("태우기는 선반에 안 온다", g.wreck.is_empty(),
			"wreck %d" % g.wreck.size())

	# ── ③ 굴린 것만 말한다 — 1:1 이다 ───────────────────
	#  boom 있는 동전(c03)과 없는 동전(c04)을 같이 들고 판 끝을 200회
	#  돈다. 안 굴린 동전에 「남았다」가 **단 한 번도** 안 나야 하고,
	#  굴린 동전의 「남았다」+「부서졌다」 합이 **정확히 200** 이어야 한다.
	#  「발동 안 했는데 번쩍임」과 「발동했는데 안 번쩍임」이 **둘 다**
	#  버그라는 그 1:1 규칙이다.
	seed(20260919)
	var n_safe := 0
	var n_boom := 0
	var n_other := 0
	for i in 200:
		g.leg_no = 3
		_hold(["c03", "c04"])
		g._leg_end_wear()
		for e in g.wreck:
			match String(e.why):
				"safe": n_safe += 1
				"boom": n_boom += 1
				_: n_other += 1
	_ok("굴린 것만 말한다 — 1:1", n_safe + n_boom == 200 and n_other == 0,
			"남았다 %d + 부서졌다 %d = %d (200) · 그 밖 %d"
			% [n_safe, n_boom, n_safe + n_boom, n_other])
	#  c03 은 1/2 이다. 200판이면 100 언저리고, 60~140 을 벗어나면
	#  확률이 실제로 움직인 것이다(p=1/2 에서 σ 7.07 → 5.7σ 창).
	_ok("1/2 이 그대로다", n_boom >= 60 and n_boom <= 140,
			"200판에 %d회 부서짐 (바라는 값 ≈100)" % n_boom)

	# ── ④ 난수 흐름이 안 바뀐다 ─────────────────────────
	#  **밸런스 불변의 유일한 증거다.** 옛 길(`bn > 0 and randf() < …`)과
	#  새 길(`rolled` / `boomed`)은 단축평가가 똑같이 걸려야 randf 호출
	#  **수와 차례가 한 칸도 안 달라진다.** 같은 씨로 옛 길을 손으로
	#  다시 돌려 굴림 결과 배열을 통째로 맞댄다.
	var old_roll := []
	seed(4242)
	for i in 300:
		#  옛 줄 그대로 — boom 없는 동전(bn 0)에서는 randf 가 **안** 돈다
		for bn in [0, 2, 0, 10, 0]:
			if bn > 0 and randf() < 1.0 / float(bn):
				old_roll.append(1)
			else:
				old_roll.append(0)
	var new_roll := []
	seed(4242)
	for i in 300:
		for bn in [0, 2, 0, 10, 0]:
			var rolled: bool = bn > 0
			var boomed: bool = rolled and randf() < 1.0 / float(bn)
			new_roll.append(1 if boomed else 0)
	_ok("난수 흐름이 안 바뀐다", old_roll == new_roll,
			"굴림 결과 %d칸 · 어긋난 칸 0" % old_roll.size())
	#  연출 쪽이 randf 를 한 번이라도 쓰면 여기가 빨개진다.
	seed(777)
	var probe_a := randf()
	_hold(["c03"])
	g._wreck_safe(0, g.owned[0], 10)
	g._wreck_add(0, g.owned[0], "boom", 10)
	g._wreck_sfx()
	seed(777)
	var _skip := randf()
	_ok("연출이 randf 를 안 쓴다", is_equal_approx(randf(), _next_after(777)),
			"씨 777 의 둘째 randf 가 그대로")
	probe_a = probe_a      # 쓰임새 없음 — 씨를 실제로 소비했다는 표시

	# ── ⑤ 삭아 죽은 장에 「남았다」를 안 말한다 ──────────
	#  검정 리그(perish 5)를 켜고 bought 를 다섯 판 전으로 맞춘 c06
	#  (1/10)을 세운다. 그 장은 perish 로 확정 사망인데 boom 도 굴려진다.
	#  **확정이 굴림을 이긴다** — 부서짐 1 · 「남았다」 0 · why perish ·
	#  그리고 **수가 안 붙는다**(확정 죽음은 1/10 을 말할 자격이 없다).
	var per_league := ""
	for lg in GameData.leagues():
		if float(lg.get("perish", 0.0)) > 0.0:
			per_league = String(lg.id)
			break
	var per_ok := false
	var per_msg := "perish 리그가 표에 없다"
	if per_league != "":
		#  리그는 GameData 가 쥔다(league_row 가 그 전역을 읽는다).
		GameData.league = per_league
		g.leg_no = 9
		seed(1)
		var p_boom := 0
		var p_safe := 0
		var p_per := 0
		var p_odds := 0
		for i in 60:
			_hold(["c06"])
			g.owned[0]["bought"] = 1        # 여덟 판 전 — perish 5 를 넘는다
			g._leg_end_wear()
			for e in g.wreck:
				match String(e.why):
					"perish":
						p_per += 1
						if int(e.bn) > 0:
							p_odds += 1
					"boom": p_boom += 1
					"safe": p_safe += 1
		per_ok = p_per == 60 and p_safe == 0 and p_boom == 0 and p_odds == 0
		per_msg = "perish %d · 굴려 죽음 %d · 남았다 %d · 수가 붙은 것 %d" \
				% [p_per, p_boom, p_safe, p_odds]
		GameData.league = ""
	_ok("삭아 죽은 장은 「남았다」를 안 한다", per_ok, per_msg)

	# ── ⑥ 선반이 아무것도 안 밟는다 ─────────────────────
	#  내역 줄 수 3~9(큰 표 x0 190 · 작은 표 x0 227 둘 다) · 항목 수
	#  1~max_items 를 다 돌며 항목 · 조각 · 부스러기 전부를 수로 잰다.
	#  옛 pop 이 「제목을 가로질렀다」로 한 번 반려한 자리라 수로 못 박는다.
	var box_bad := 0
	var worst := ""
	var shard_max := 0.0
	var n_max: int = maxi(GameData.max_items(), 6)
	for n in range(1, n_max + 1):
		var gap: float = minf(float(g.WRECK.gap_max),
				float(g.WRECK.span) / float(maxi(n - 1, 1)))
		for k in n:
			var cy: float = float(g.WRECK.y0) + gap * float(k)
			#  동전 몸 — 고리까지 r+2 다
			var top: float = cy - float(g.PANEL.r) - 2.0
			var bot: float = cy + float(g.PANEL.r) + 2.0
			var lf: float = float(g.WRECK.x) - float(g.PANEL.r) - 2.0
			var rt: float = float(g.WRECK.x) + float(g.PANEL.r) + 2.0
			#  ⓓ 제목 잉크 y≤46 · ⓔ 상단 띠 y≤18 · ⓒ 단추 y≥290 ·
			#  ⓐ 표 x≥190 · 글자 왼끝 96
			if top < 52.0 or bot > 276.0 or lf < 8.0 or rt > 88.0:
				box_bad += 1
				worst = "n=%d k=%d → y[%.0f,%.0f] x[%.0f,%.0f]" \
						% [n, k, top, bot, lf, rt]
	_ok("선반 %d줄까지 상자 안" % n_max, box_bad == 0,
			"밟은 것 %d개%s" % [box_bad, (" · " + worst) if worst != "" else ""])
	#  조각 — 실제로 날려 보고 클램프 뒤 자리를 잰다.
	#  ⚠ **중심이 아니라 다각형 끝을 잰다.** 중심만 재던 첫 벌은 벽 88 을
	#  통과시켰는데 그림에서는 조각이 98 까지 가서 글자(x 96)를 밟고 있었다
	#  — 점이 동전 중심 기준 국소 좌표라 다각형이 제 둘레 반지름만큼 더
	#  나간다. 재는 자가 틀리면 검사가 초록인 채로 회귀가 산다.
	var mats := ["glass", "wax", "cast", "pixel", "hollow", ""]
	var ids := {"glass": "c03", "wax": "c06", "cast": "c30",
			"pixel": "r09", "hollow": "l03", "": "c04"}
	var sh_bad := 0
	var sh_worst := ""
	#  **줄 수를 1부터 상한까지 다 돌며 잰다.** 한 줄만 재던 첫 벌은
	#  세로 벽이 띠 전체(y[46,276])인 것을 못 잡았다 — 유리는 0.215초에
	#  50px 을 내려가는데 줄 간격은 36~42 뿐이라 구조적으로 한 줄을
	#  넘었고, 그림에서 첫 줄 조각이 둘째 줄 「남았다」의 **온전한 동전
	#  위에** 앉아 있었다(2026-09-19). 검사가 줄을 하나만 세우면 이
	#  회귀가 초록인 채로 산다.
	var deep := 0.0          # 이웃 동전 몸으로 가장 깊이 들어간 깊이
	var deep_msg := ""
	var play_min := 999.0    # 가장 빡빡한 줄이 실제로 가진 세로 놀이
	for n in range(1, n_max + 1):
		var gp: float = minf(float(g.WRECK.gap_max),
				float(g.WRECK.span) / float(maxi(n - 1, 1)))
		for k in n:
			var cy2: float = float(g.WRECK.y0) + gp * float(k)
			#  _wreck_draw 가 넘기는 것과 **같은 식**으로 줄의 몫을 세운다.
			var row := Vector2(
					float(g.WRECK.wy0) if k <= 0 else cy2 - gp * 0.5,
					float(g.WRECK.wy1) if k >= n - 1 else cy2 + gp * 0.5)
			for m in mats:
				_hold([String(ids[m])])
				g.wreck_seed += 1
				g._wreck_add(0, g.owned[0], "boom", 2)
				var c := Vector2(float(g.WRECK.x), cy2)
				for f in 60:
					_tick(1)
					if g.wreck.is_empty():
						break
					for pc in (g.wreck[0].pcs as Array):
						#  벽에 넘기는 것은 **늘어난 뒤의 반지름**이다 —
						#  그리기가 쓰는 함수를 그대로 불러 낸다.
						var ex0: float = float(pc.get("ex", 0.0))
						var symx: float = g._wreck_sy_max(ex0, row,
								String(g.BREAK[m].mode))
						var ex: float = ex0 * symx
						var p: Vector2 = g._wreck_clamp(c, pc.p,
								true, ex, row)
						#  **창을 직접 잰다.** 지나간 자리를 재면 옆으로만
						#  간 조각이 0 으로 나와 창이 열려 있는지를 못
						#  말한다 — 위아래로 아주 멀리 찍어 보고 어디서
						#  멎는지로 창의 높이를 잰다.
						#  ⚠ **띠가 조각보다 좁은 줄은 뺀다.** 밀랍은
						#  늘어나며 둘레 반지름이 29 까지 가서 마지막
						#  줄(중심 253)에서는 띠 아래끝 276 이 먼저 닿는다
						#  — 거기서는 놀이보다 벽이 먼저고, 벽을 지키는
						#  것은 바로 아래 꼭짓점 검사가 증명한다.
						if cy2 - ex >= float(g.WRECK.wy0) \
								and cy2 + ex <= float(g.WRECK.wy1):
							play_min = minf(play_min,
									g._wreck_clamp(c, Vector2(0.0, 999.0),
											true, ex, row).y
									- g._wreck_clamp(c, Vector2(0.0, -999.0),
											true, ex, row).y)
						#  **회전도 밀랍 늘어남도 먹인 실제 꼭짓점**을
						#  잰다 — 그리기가 쓰는 바로 그 함수를 부른다.
						#  규칙을 여기서 베껴 적으면 그리기가 달라져도
						#  검사가 초록인 채로 남는다.
						for q in g._wreck_poly(g.wreck[0], pc, p, symx):
							shard_max = maxf(shard_max, q.x)
							if q.x < 8.0 or q.x > 88.0 \
									or q.y < 46.0 or q.y > 276.0:
								sh_bad += 1
								sh_worst = "n=%d k=%d %s (%.1f, %.1f)" \
										% [n, k, m, q.x, q.y]
							#  이웃 줄의 **동전 몸**을 얼마나 파고드는가.
							for nb in [-1, 1]:
								if k + nb < 0 or k + nb >= n:
									continue
								var nc := Vector2(float(g.WRECK.x),
										cy2 + gp * float(nb))
								var dp: float = float(g.PANEL.r) \
										- q.distance_to(nc)
								if dp > deep:
									deep = dp
									deep_msg = "n=%d k=%d %s" % [n, k, m]
	_ok("조각이 글자 왼끝 96 을 안 넘는다", sh_bad == 0 and shard_max <= 88.0,
			"가장 오른쪽 꼭짓점 x %.1f (벽 88 · 글자 96)%s"
			% [shard_max, (" · " + sh_worst) if sh_worst != "" else ""])
	#  **이웃 줄을 덮지 않는다.** 비대칭이 「조각인가 온전한가」 하나에
	#  실려 있으므로 이웃의 온전한 실루엣을 조각이 덮으면 그 자리에서
	#  읽기가 무너진다. 꼭짓점 하나가 테를 스치는 것까지는 둔다 — 줄
	#  간격이 36~42 인데 동전 지름이 38 이라 스침은 구조적으로 못 피한다.
	#  **자는 계산해서 나온다**: 조각 중심이 제 줄에서 최대 row_play(8)
	#  만큼 가고 둘레 반지름이 PANEL.r(19) 이라 꼭짓점은 27 까지 간다.
	#  가장 빡빡한 줄 간격이 36 이므로 이웃 중심에서 9 가 남고, 파고드는
	#  깊이의 상한은 19 − 9 = 10 이다. 그보다 깊으면 놀이가 커졌거나
	#  조각이 커진 것이다(밀랍이 늘어난 채로 오면 여기가 먼저 빨개진다).
	var gap_min: float = minf(float(g.WRECK.gap_max),
			float(g.WRECK.span) / float(maxi(n_max - 1, 1)))
	var deep_bar: float = float(g.PANEL.r) - (gap_min
			- float(g.WRECK.row_play) - float(g.PANEL.r))
	_ok("조각이 이웃 줄 동전 몸을 안 덮는다", deep <= deep_bar,
			"가장 깊이 파고든 것 %.1fpx (자 %.1f = 테 %.0f − 남은 %.0f)%s"
			% [deep, deep_bar, float(g.PANEL.r),
					gap_min - float(g.WRECK.row_play) - float(g.PANEL.r),
					(" · " + deep_msg) if deep_msg != "" else ""])
	#  **못 박으면 도로 온전해 보인다.** 조각이 하나도 안 움직이면 여섯이
	#  다시 원물건 실루엣으로 타일링되어 「안 부서진 것」이 된다.
	_ok("가장 빡빡한 줄에도 세로 놀이가 있다",
			play_min >= float(g.WRECK.row_play) - 0.01,
			"가장 좁은 줄의 세로 창 %.1fpx (최소 %.1f)"
			% [play_min, float(g.WRECK.row_play)])

	# ── ⑦ 좌표가 두 번 눌리는 함정 ──────────────────────
	#  _shard_cut 이 내는 점은 **면 좌표**(chip_r 22.04)고 랙 동전은
	#  **화면 정원**(PANEL.r 19)이다. TBL.flat(0.788)을 잘못 곱하면
	#  ⓒ 가 **세로에서 먼저** 틀어진다.
	var cut_bad := 0
	var cut_msg := ""
	var min_area := 99999.0
	var kk: float = float(g.PANEL.r) / float(g.TBL.chip_r)
	for it in GameData.items():
		var shell := {"type": "item", "d": it}
		var cuts: Array = g._shard_cut(shell, 4, 7, 0.0)
		if cuts.size() < 2:
			cut_bad += 1
			cut_msg = "%s 조각 %d" % [String(it.id), cuts.size()]
			continue
		for q in cuts:
			var ar: float = absf(g._coin_area(q)) * kk * kk
			min_area = minf(min_area, ar)
			if ar < 40.0:
				cut_bad += 1
				cut_msg = "%s 조각 넓이 %.1f" % [String(it.id), ar]
			for v in (q as PackedVector2Array):
				var p2: Vector2 = (v as Vector2) * kk
				if absf(p2.x) > 21.0 or absf(p2.y) > 21.0:
					cut_bad += 1
					cut_msg = "%s 꼭짓점 (%.1f, %.1f)" % [String(it.id), p2.x, p2.y]
	_ok("조각이 세로로 두 번 안 눌린다", cut_bad == 0,
			"동전 %d장 · 어긋남 %d · 가장 작은 조각 %.0f면px²%s"
			% [GameData.items().size(), cut_bad, min_area,
			(" · " + cut_msg) if cut_msg != "" else ""])

	# ── ⑧ 박자 불변 ─────────────────────────────────────
	#  ⚠ **_leg_end_wear 가 아니라 _finish_leg 를 잰다** — _leg_end_wear
	#  는 state 를 안 건드린다. 나중에 누가 1414-1415 사이에 await 나
	#  상태를 끼우면 이 줄이 즉시 빨개진다.
	g.leg_no = 3
	_hold(["c04"])
	g.total = 999999
	g.target = 1
	g._finish_leg()
	_ok("박자가 한 프레임도 안 늘었다",
			g.state == g.S.CLEAR and is_zero_approx(g.clear_t),
			"_finish_leg 가 돌아온 자리에서 state %d · clear_t %.3f"
			% [g.state, g.clear_t])

	# ── ⑨ 여럿이 죽어도 소리는 하나 ─────────────────────
	#  「같은 소리 둘이 같은 ms 에 겹치면 한 덩어리가 된다」를 SMASH 가
	#  이미 실측했고, 판 끝은 18ms 를 벌 방법이 없으니 아예 하나로 간다.
	g.leg_no = 3
	seed(11)
	var many_ok := true
	var glass_ok := true
	var safe_in_break := 0
	var seen_multi := 0
	var seen_mixed := 0
	var worst_snd := ""
	for i in 400:
		_hold(["c03", "c03", "c06", "c03", "c06", "c03"])
		g.wreck_snd_n = 0
		g._leg_end_wear()
		var dead := 0
		var glass_dead := false
		for e in g.wreck:
			if not bool(e.safe):
				dead += 1
				if String(e.mat) == "glass":
					glass_dead = true
		if dead >= 2:
			seen_multi += 1
			if g.wreck_snd_n > 1:
				many_ok = false
				worst_snd = "%d회" % g.wreck_snd_n
			if String(g.wreck_snd_last) == "coin_safe":
				safe_in_break += 1
		if glass_dead:
			seen_mixed += 1
			if String(g.wreck_snd_last) != "coin_break_glass":
				glass_ok = false
				worst_snd = String(g.wreck_snd_last)
	_ok("여럿이 죽어도 소리는 하나", many_ok and seen_multi > 0,
			"둘 이상 죽은 판 %d번 · 어긋남 %s"
			% [seen_multi, worst_snd if not many_ok else "0"])
	_ok("유리가 섞이면 유리가 첫 장", glass_ok and seen_mixed > 0,
			"유리가 섞인 판 %d번 · 어긋남 %s"
			% [seen_mixed, worst_snd if not glass_ok else "0"])
	_ok("부서진 판에는 coin_safe 가 0회", safe_in_break == 0,
			"손실이 머리기사다 — 샌 것 %d번" % safe_in_break)
	_ok("흔들림은 0 그대로", is_zero_approx(g.shake) and is_zero_approx(g.hitstop),
			"shake %.2f · hitstop %.3f" % [g.shake, g.hitstop])
	#  아무것도 안 부서진 판에서만 톡 하나.
	var got_safe := false
	var safe_snd := "(안 나옴)"
	for i in 60:
		_hold(["c06"])
		g.wreck_snd_n = 0
		g._leg_end_wear()
		if _why_list() == ["safe"]:
			got_safe = g.wreck_snd_n == 1 \
					and String(g.wreck_snd_last) == "coin_safe"
			safe_snd = "%s ×%d" % [g.wreck_snd_last, g.wreck_snd_n]
			break
	_ok("남기만 한 판은 톡 하나", got_safe, safe_snd)
	#  목숨(pixel)은 세지 않는다 — save_life 가 이미 울었다.
	_hold(["r09"])
	g.wreck_snd_n = 0
	g.wreck_seed += 1
	g.wreck_snd_from = g.wreck.size()
	g._wreck_add(0, g.owned[0], "save", 0)
	g._wreck_sfx()
	_ok("목숨에는 파괴음을 안 얹는다", g.wreck_snd_n == 0,
			"울린 것 %s" % (g.wreck_snd_last if g.wreck_snd_n > 0 else "(없음)"))
	#  소진은 손 어휘다 — 판 위에서 나는 유일한 갈래라 새 소리를 안 짓는다.
	_hold(["c34"])
	g.owned[0].gs = int(g.owned[0].v) / int(g.owned[0].gstep)
	g.wreck_snd_n = 0
	g._wear_spent()
	_ok("소진은 hand_drop 이다", String(g.wreck_snd_last) == "hand_drop",
			"울린 것 %s" % g.wreck_snd_last)
	#  **상한에서 잘라내도 묶음이 안 잘린다.** 앞에서 지우면 인덱스가
	#  통째로 내려가는데 묶음 시작을 같이 안 밀면 이번 묶음의 **앞부분이
	#  소리 훑기에서 빠진다** — 첫 장이 유리였으면 유리 대신 기본음이
	#  나고, 잘린 수가 묶음 시작과 같아지면 range 가 통째로 비어 **한 번도
	#  안 운다.** 이 일감의 원인이 「판 끝에 소리가 0」이었으니 되살아나면
	#  안 되는 자리다(2026-09-19, 검토가 잡았다).
	_hold(["c04"])
	g.wreck_seed += 1
	g.wreck_snd_from = g.wreck.size()
	g._wreck_add(0, _find("c04"), "rdec", 0)       # 앞 묶음 하나
	g._wreck_sfx()
	g.wreck_seed += 1
	g.wreck_snd_from = g.wreck.size()
	g._wreck_add(0, _find("c03"), "boom", 2)       # 이번 묶음의 첫 장이 유리다
	for ci in range(int(g.WRECK.cap) - 1):         # 여기서 앞 묶음이 잘려 나간다
		g._wreck_add(0, _find("c04"), "rdec", 0)
	g.wreck_snd_n = 0
	g._wreck_sfx()
	_ok("상한에서 잘라내도 묶음의 첫 장이 안 빠진다",
			g.wreck_snd_n == 1
			and String(g.wreck_snd_last) == "coin_break_glass",
			"시체 %d(상한 %d) → %s ×%d" % [g.wreck.size(),
					int(g.WRECK.cap), g.wreck_snd_last, g.wreck_snd_n])

	# ── ⑩ 모션 끄기는 일부러 다르다 ─────────────────────
	#  _smash_at 의 모션 끄기(아무것도 없다)와 **일부러 다른** 자리다.
	#  리롤 조각은 장식이고 이것은 정보다 — 껐어도 잔해와 글자가 남고
	#  **소리는 난다.** 그리고 owned 는 똑같이 줄어든다.
	g.motion_off = true
	g.leg_no = 3
	_hold(["c04"])
	g.owned[0].gs = int(g.owned[0].v) / int(g.owned[0].gstep) - 1
	g._leg_end_wear()
	var mo_pcs: int = (g.wreck[0].pcs as Array).size() if g.wreck.size() > 0 else 0
	var mo_still := true
	_tick(30)
	if not g.wreck.is_empty():
		for pc in (g.wreck[0].pcs as Array):
			if (pc.p as Vector2).length() > 7.0:
				mo_still = false
	_ok("모션 끄기 — 잔해는 남고 안 움직인다",
			g.owned.is_empty() and mo_pcs > 0 and mo_still
			and not g.wreck.is_empty(),
			"owned 0 · 조각 %d · 0.5초 뒤에도 서 있다 %s"
			% [mo_pcs, str(mo_still)])
	#  **여섯 재질 전부가 정지 그림에 무언가를 남겨야 한다.** 처음에는
	#  pixel 이 모션 끄기에서도 칸을 차례로 꺼서 「막았다」 넉 자만 허공에
	#  떴다(그림으로 잡았다). 여기서는 재질마다 **수명의 끝 무렵에** 보일
	#  것이 있는지를 잰다 — 그림이 다 말해야 하는 쪽이 이 갈래다.
	var mo_bad := []
	for m in ["glass", "wax", "cast", "pixel", "hollow", ""]:
		_hold([String({"glass": "c03", "wax": "c06", "cast": "c30",
				"pixel": "r09", "hollow": "l03", "": "c04"}[m])])
		g.wreck_seed += 1
		g._wreck_add(0, g.owned[0], "boom", 2)
		if g.wreck.is_empty():
			mo_bad.append(m)
			continue
		var e0: Dictionary = g.wreck[0]
		var br0: Dictionary = g.BREAK[m]
		#  수명의 90% 지점까지 밀고, **그리기가 실제로 쓰는 알파 함수**를
		#  그대로 불러 잰다(_wreck_pa · _wreck_fa). 규칙을 여기서 베껴
		#  적으면 그리기가 달라져도 검사가 초록인 채로 남는다.
		e0.t = float(e0.tot) * 0.9
		var vis := false
		if String(br0.mode) == "ring":
			vis = g._wreck_fa(e0) > 0.01   # 테는 모션 끄기에서 0.45r 로 선다
		else:
			var np: int = (e0.pcs as Array).size()
			for j in np:
				if g._wreck_pa(e0, j, np) > 0.01:
					vis = true
					break
		if not vis:
			mo_bad.append(m)
	_ok("모션 끄기 — 여섯 재질 다 무언가를 남긴다", mo_bad.is_empty(),
			"빈 재질 " + str(mo_bad))
	#  **반대쪽도 잰다.** 위 줄만 있으면 「언제나 참」인 검사가 되어
	#  회귀를 못 잡는다 — 모션이 **켜져** 있을 때 픽셀은 수명 끝에
	#  칸이 다 꺼져 있어야 하고(그것이 「칸이 꺼진다」의 읽기다),
	#  그 둘이 갈리는 것이 이 재질의 전부다.
	g.motion_off = false
	_hold(["r09"])
	g.wreck_seed += 1
	g._wreck_add(0, g.owned[0], "save", 0)
	var px: Dictionary = g.wreck[0]
	px.t = float(px.tot) * 0.9
	var px_on := 0
	var npx: int = (px.pcs as Array).size()
	for j in npx:
		if g._wreck_pa(px, j, npx) > 0.01:
			px_on += 1
	_ok("모션 켜면 픽셀은 칸이 다 꺼진다", px_on == 0 and npx > 0,
			"수명 90%% 에서 켜진 칸 %d / %d" % [px_on, npx])

	# ── ⑪ 자리는 한 번 정하면 안 바뀐다 ─────────────────
	g.state = g.S.PICK
	_hold(["c34"])
	g.owned[0].gs = int(g.owned[0].v) / int(g.owned[0].gstep)
	g._wear_spent()
	_ok("판 중 시체는 슬롯을 고른다", g._wreck_scr() == 1,
			"state PICK → scr %d" % g._wreck_scr())
	#  **그 슬롯이 산 동전의 칸이면 안 된다.** e.i 는 지우기 전의 자리라
	#  owned.remove_at 이 뒷 동전을 그 칸으로 당긴다 — 조각과 「다 썼다」
	#  넉 자가 멀쩡한 이웃에 붙어 **화면이 산 동전을 죽었다고 말했다**
	#  (2026-09-19, 그림으로 잡았다). 가운데 칸이 죽는 판을 세워 못 박는다.
	#  배정은 그리기 밖(_wreck_seat)이라 헤드리스에서 그대로 부른다.
	_hold(["c04", "c34", "c04"])
	g.owned[1].gs = int(g.owned[1].v) / int(g.owned[1].gstep)
	g._wear_spent()
	g._wreck_seat(1)
	var seat_i: int = int(g.wreck[0].si) if g.wreck.size() == 1 else -1
	_ok("시체는 빈 칸에 선다",
			g.owned.size() == 2 and seat_i == 2,
			"산 동전 %d장(칸 0·1) → 시체는 칸 %d" % [g.owned.size(), seat_i])
	#  둘이 같은 프레임에 죽으면 다음 빈 칸으로 한 칸씩 민다.
	_hold(["c34", "c34", "c04"])
	for w in 2:
		g.owned[w].gs = int(g.owned[w].v) / int(g.owned[w].gstep)
	g._wear_spent()
	g._wreck_seat(1)
	var two_ok: bool = g.wreck.size() == 2 and g.owned.size() == 1 \
			and int(g.wreck[0].si) != int(g.wreck[1].si)
	for we in g.wreck:
		if int(we.si) < g.owned.size():
			two_ok = false
	_ok("둘이 같이 죽어도 칸을 안 겹친다", two_ok,
			"산 동전 %d장 → 칸 %s" % [g.owned.size(),
					str([int(g.wreck[0].si), int(g.wreck[1].si)])
					if g.wreck.size() == 2 else "(시체 %d)" % g.wreck.size()])
	g.state = g.S.CLEAR
	_ok("정산에서는 선반을 고른다", g._wreck_scr() == 0,
			"state CLEAR → scr %d" % g._wreck_scr())
	g.state = g.S.SHOP
	_ok("상점은 슬롯 쪽이다", g._wreck_scr() == 1,
			"state SHOP → scr %d" % g._wreck_scr())
	g.state = g.S.OVER
	_ok("런이 끝난 화면에는 안 그린다", g._wreck_scr() == -1,
			"state OVER → scr %d" % g._wreck_scr())
	#  건너뛰기에 안 죽는다 — 시체 시계는 clear_t 와 **따로** 돈다.
	g.state = g.S.CLEAR
	_hold(["c03"])
	g.wreck_seed += 1
	g._wreck_add(0, g.owned[0], "boom", 2)
	g.clear_t = 99.0
	_tick(20)                                     # 0.333초
	_ok("clear_t 를 99 로 밀어도 시체가 산다", not g.wreck.is_empty(),
			"0.333초 뒤 시체 %d개 (유리 총 0.400초)" % g.wreck.size())
	_tick(10)                                     # 0.500초 — 유리를 넘긴다
	_ok("제 길이만큼만 산다", g.wreck.is_empty(),
			"0.500초 뒤 시체 %d개" % g.wreck.size())

	# ── ⑫ 재질 여섯이 실제로 갈린다 · 표 전제가 안 무너진다 ──
	var lens := {}
	var pcsn := {}
	for m in mats:
		var br: Dictionary = g.BREAK[m]
		lens[m] = float(br.hold) + float(br.fly) + float(br.sink)
		_hold([String(ids[m])])
		g.wreck_seed += 1
		g._wreck_add(0, g.owned[0], "boom", 2)
		pcsn[m] = (g.wreck[0].pcs as Array).size()
	_ok("유리가 밀랍보다 짧고 많다",
			float(lens["glass"]) < float(lens["wax"])
			and int(pcsn["glass"]) > int(pcsn["wax"]),
			"유리 %.3fs·%d조각 대 밀랍 %.3fs·%d조각"
			% [lens["glass"], pcsn["glass"], lens["wax"], pcsn["wax"]])
	_ok("가장 긴 것이 CLEAR 의 0.6초 안",
			float(lens["wax"]) <= 0.60,
			"밀랍 %.3fs (정산이 저절로 주는 0.60~1.15초)" % lens["wax"])
	#  boom 칸이 찬 줄이 셋이 되면 「판당 0.9회」 전제가 바뀐다.
	var boom_rows := []
	for it in GameData.items():
		if GameData.boom_n(String(it.get("boom", ""))) > 0:
			boom_rows.append("%s 1/%d" % [String(it.id),
					GameData.boom_n(String(it.boom))])
	_ok("boom 칸이 찬 줄은 정확히 둘", boom_rows.size() == 2,
			"%s" % str(boom_rows))
	#  헤드리스 누수 — _process 가 없어도 여섯에서 딱 잘린다.
	_hold(["c04"])
	for i in 100:
		g.wreck_seed += 1
		g._wreck_add(0, _find("c04"), "rdec", 0)
	_ok("헤드리스 누수 방어", g.wreck.size() <= int(g.WRECK.cap),
			"100번 눕혀도 wreck %d (상한 %d)" % [g.wreck.size(), int(g.WRECK.cap)])

	# ── 소리 넷이 굽혔고 상한을 지킨다 ──────────────────
	#  ⚠ 9.7kHz 유리 딸깍 대역은 반려당한 자리라 비워 둔다. 유리는
	#  대역이 아니라 밀도·비조화 비·빠른 감쇠로 낸다.
	for nm in ["coin_break", "coin_break_glass", "coin_break_wax", "coin_safe"]:
		_ok("%s 가 표에 있다" % nm, g.SFX.has(nm), "")
	var hi_bad := 0
	var hi_msg := ""
	for nm in ["coin_break", "coin_break_glass", "coin_break_wax", "coin_safe"]:
		var st: AudioStream = load("res://sfx/%s.wav" % nm)
		if st == null:
			hi_bad += 1
			hi_msg = "%s 파일이 없다" % nm
			continue
		var cap: float = 2600.0 if nm == "coin_break_wax" else 6000.0
		var sh := _hi_share(st, cap * 1.25)
		if sh > 0.02:
			hi_bad += 1
			hi_msg = "%s 상한 위 %.2f%%" % [nm, sh * 100.0]
		else:
			print("       %-18s %.0fHz 위 에너지 %.2f%%" % [nm, cap * 1.25,
					sh * 100.0])
	_ok("넷 다 제 상한을 지킨다", hi_bad == 0,
			"어긋남 %d%s" % [hi_bad, (" · " + hi_msg) if hi_msg != "" else ""])

	print("\n%s" % ("전부 통과" if fails == 0 else "실패 %d건" % fails))
	quit(mini(fails, 125))
	return true


#  씨 s 를 놓고 randf 를 한 번 버린 뒤의 값. ④ 가 「연출이 전역 RNG 를
#  한 칸도 안 밀었다」를 잴 때 맞댈 기준이다.
func _next_after(s: int) -> float:
	seed(s)
	var _a := randf()
	return randf()


#  fc 위 에너지 몫. 한 극 저역 통과를 **반대로** 걸어(입력 − 저역) 고역만
#  남기고 제곱합을 견준다. FFT 없이 재는 값이라 정확한 스펙트럼이 아니라
#  **상한을 넘겼는지**만 본다 — 그것이 이 검사가 물을 것의 전부다.
func _hi_share(st: AudioStream, fc: float) -> float:
	var d: PackedByteArray = (st as AudioStreamWAV).data
	var sr: float = float((st as AudioStreamWAV).mix_rate)
	var n: int = d.size() / 2
	if n <= 0:
		return 0.0
	var a: float = exp(-TAU * fc / sr)
	var lo := 0.0
	var e_all := 0.0
	var e_hi := 0.0
	for i in n:
		var v: float = float(d.decode_s16(i * 2)) / 32768.0
		lo = lo * a + v * (1.0 - a)
		var hi: float = v - lo
		e_all += v * v
		e_hi += hi * hi
	return 0.0 if e_all <= 0.0 else e_hi / e_all
