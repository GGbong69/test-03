extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  동전 QA — 켜진 동전이 **하나도 빠짐없이 실제로 일한다** 를 본다
#
#  실행:  godot --path . --headless --script scripts/tools/qa_items.gd
#  종료 코드 = 실패 개수
#
#  item_stats 는 균등 조준 36만 발로 "얼마나 버는가" 를 잰다. 그 자는
#  전제가 넷이라(한 장만 · 균등 조준 · 기본 판 · 표준 다트) 조건이 좁거나
#  다른 물건에 기대는 동전이 0 으로 나온다 — 안 도는 것과 구별이 안 된다.
#  그래서 여기서는 **조건을 일부러 만족시킨 문맥**을 만들어 넣는다.
#
#  네 갈래로 본다
#    ① 정산  조건이 서는가(check) · 수량이 나오는가(item_amt)
#    ② 조준  든 동전이 조준 방식을 쥐는가(_aim_from_items)
#    ③ 골드  정산 골드가 실제로 붙는가(_gold_from_items) · 착탄 골드
#    ④ 소크  전부 쥐고 오토플레이 — 런타임 오류가 나는가
# ══════════════════════════════════════════════════════════

var g = null
var frames := 0
var fails := 0
var soak_arm := 0
# 소크 길이는 인자로 받는다. 조건이 좁은 동전(spread · sec:8)은 짧은 창에서
# 한 번도 안 걸릴 수 있어 "안 쌓였다" 와 "못 만났다" 가 섞인다.
var soak_n := 3600
# only=<id> 를 주면 그 동전만 쥐고 돈다. 조건이 희소한 동전이 "안 도는 것"
# 인지 "못 만난 것" 인지는 이렇게만 갈린다.
var only := ""
var grew := {}          # 소크에서 실제로 값이 쌓인 동전
var lines := []


func _initialize() -> void:
	Save.path = "user://_qa_items.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("frames="):
			soak_n = maxi(600, int(a.substr(7)))
		if a.begins_with("only="):
			only = a.substr(5)
	_static_checks()


func _bad(id: String, nm: String, why: String) -> void:
	fails += 1
	lines.append("  실패  %-6s %-16s %s" % [id, nm, why])


# 조건이 서는 문맥을 만든다. check() 가 무조건 읽는 열쇠를 전부 채운 뒤
# 조건마다 한 칸씩 비튼다 — 안 채우면 없는 열쇠로 죽는다.
func _ctx_for(c: String) -> Dictionary:
	var x := {
		"miss": false, "missp": false, "mult": 1, "sector": 7, "col": 1,
		"left": true, "same": false, "first": false, "last": false,
		"streak": 0, "warm": false,
		# item_amt 가 읽는 것들 — 배율원이 0 이면 수량도 0 이 된다
		"darts_left": 3, "items_n": 4, "gold": 20, "mag_hvy": 2,
		"leg_base": 6, "leg_darts": 4, "low": 5, "zonehist": 2,
		"empty_n": 2, "rackval_others": 6, "rand01": 1.0,
	}
	match c:
		"triple": x.mult = 3
		"double": x.mult = 2
		"band": x.mult = 2
		"bull": x.sector = 25
		"odd": x.sector = 3
		"even": x.sector = 4
		"big": x.sector = 16
		"mid": x.sector = 10
		"small": x.sector = 3
		"left": x.left = true
		"right": x.left = false
		"same": x.same = true
		"diff": x.same = false
		"first": x.first = true
		"last": x.last = true
		"streak": x.streak = 2
		"warm": x.warm = true
		"miss": x.miss = true
		"missp": x.missp = true
		"risk": x.mult = 2
	# 깃발형 조건은 이름 그대로 켠다
	for k in ["risk1", "few", "sixth", "pair", "trip", "quad", "pair2",
			"spread", "zone3", "zones2", "zones4", "rezone"]:
		x[k] = c == k
	if c.begins_with("sec:"):
		x.sector = int(c.substr(4).split(",")[0])
	if c.begins_with("col:"):
		x.col = int(c.substr(4).split(",")[0])
		x.sector = 4          # 불·아웃은 색이 없다 — 칸에 꽂혀야 한다
	return x


func _static_checks() -> void:
	var items := GameData.items()
	lines.append("켜진 동전 %d장" % items.size())

	# ── ① 정산 ────────────────────────────────────────────
	var scored := 0
	for it in items:
		var id := String(it.id)
		var nm := String(it.get("n", ""))
		var c := String(it.get("c", ""))
		var k := String(it.get("k", ""))
		if String(it.get("aim", "")) != "" or String(it.get("score", "")) != "":
			continue                     # 조준·계산 방식은 ②에서 본다
		var x := _ctx_for(c)
		if not GameData.check(c, x):
			_bad(id, nm, "조건 '%s' 가 만족 문맥에서도 안 선다" % c)
			continue
		if k == "":
			continue                     # 골드·다트 전업 — ③에서 본다
		if k == "save":
			scored += 1
			continue                     # 목숨은 정산이 아니라 판 실패가 읽는다
		# 쌓이는 동전은 0 에서 시작한다. 게임은 발동하는 그 자리에서 먼저
		# 올리고(game.gd:3049) hitmiss 는 매 발 올린다(game.gd:3097) —
		# 여기서도 한 걸음 넣어야 "한 번 터진 뒤" 를 재는 것이 된다.
		var probe: Dictionary = it.duplicate()
		var gw := String(it.get("grow", ""))
		if gw == "fire" or gw == "hitmiss":
			probe.gs = int(it.get("gstep", 0))
		var amt: int = GameData.item_amt(probe, x)
		if amt <= 0:
			_bad(id, nm, "조건은 서는데 수량이 %d 다 (k=%s v=%s per=%s grow=%s)"
					% [amt, k, it.get("v", 0), it.get("per", ""), it.get("grow", "")])
		else:
			scored += 1
	lines.append("① 정산 — 조건이 서고 수량이 나오는 동전 %d장" % scored)

	# ── ② 조준 ────────────────────────────────────────────
	var aimed := 0
	for it in items:
		var am := String(it.get("aim", ""))
		if am == "":
			continue
		if not GameData.AIM_MODES.has(am):
			_bad(String(it.id), String(it.get("n", "")), "모르는 조준 '%s'" % am)
			continue
		g.owned = [it.duplicate()]
		var got := String(g._aim_from_items())
		if got != am:
			_bad(String(it.id), String(it.get("n", "")),
					"쥐면 조준이 '%s' 여야 하는데 '%s' 다" % [am, got])
		else:
			aimed += 1
	g.owned.clear()
	lines.append("② 조준 — 든 대로 방식이 바뀌는 동전 %d장" % aimed)

	# ②-b 계산 방식 — 2026-09-10 에 저울이 다트통에서 동전으로 내려왔다.
	# 조준과 같은 규약이다: 든 동전이 먼저 쥐고(game.gd:546) 팔면 기본으로
	# 돌아간다. 그래서 조준과 나란히 본다.
	var scored_m := 0
	for it in items:
		var sm := String(it.get("score", ""))
		if sm == "":
			continue
		if not GameData.SCORE_MODES.has(sm):
			_bad(String(it.id), String(it.get("n", "")), "모르는 계산 방식 '%s'" % sm)
			continue
		g.owned = [it.duplicate()]
		g._start_leg()
		if String(g.score_mode) != sm:
			_bad(String(it.id), String(it.get("n", "")),
					"쥐면 계산이 '%s' 여야 하는데 '%s' 다" % [sm, g.score_mode])
		else:
			scored_m += 1
	g.owned.clear()
	if scored_m > 0:
		lines.append("②-b 계산 — 든 대로 계산 방식이 바뀌는 동전 %d장" % scored_m)

	# ── ③ 골드 ────────────────────────────────────────────
	# 정산 골드는 게임의 _gold_from_items 가 유일한 출처다. 그 함수를
	# 그대로 불러 확인한다 — 여기서 제 셈을 하면 게임과 갈라진다.
	var golds := 0
	for it in items:
		var gk := String(it.get("g", ""))
		if gk == "":
			continue
		var gv := int(it.get("gv", 0))
		var nm := String(it.get("n", ""))
		if gk == "risk50" or gk == "hit":
			# 착탄 골드 — 조건이 곧 문이다
			var x := _ctx_for(String(it.get("c", "")))
			if gk == "risk50":
				x.mult = 2          # 더블·트리플·불이라야 선다
			if not GameData.gold_dart_hit(it, x):
				_bad(String(it.id), nm, "착탄 골드 '%s' 가 만족 문맥에서 안 선다" % gk)
				continue
			golds += 1
			continue
		# 정산 골드 — 판이 끝나는 자리를 만들어 준다
		g.owned = [it.duplicate()]
		g.sealed = -1
		g.darts_left = 3
		g.leg_miss = false
		g.gold = 0                  # broke(보유 골드가 적으면) 가 서는 자리
		var rows: Array = g._gold_from_items()
		var sum := 0
		for r in rows:
			sum += int(r.v)
		if sum <= 0:
			_bad(String(it.id), nm, "정산 골드 '%s' (gv %d) 가 한 푼도 안 붙는다" % [gk, gv])
		else:
			golds += 1
	g.owned.clear()
	lines.append("③ 골드 — 실제로 골드가 붙는 동전 %d장" % golds)

	# ── 부가: 다트 증감 ───────────────────────────────────
	for it in items:
		var da := int(it.get("dadd", 0))
		if String(it.get("k", "")) == "" and String(it.get("g", "")) == "" \
				and String(it.get("aim", "")) == "" and da == 0 \
				and String(it.get("score", "")) == "" \
				and String(it.get("side", "")) == "":
			_bad(String(it.id), String(it.get("n", "")), "효과도 부가도 없다")


func _process(_d: float) -> bool:
	frames += 1
	g.set_process(false)
	# ── ④ 소크 — 다섯 장씩 갈아 끼우며 오토플레이 ──────────
	if frames == 2 or frames % 240 == 0:
		var items := GameData.items()
		if only != "":
			items = items.filter(func(z): return String(z.id) == only)
		g.owned.clear()
		for j in mini(5, items.size()):
			var it: Dictionary = items[(soak_arm + j) % items.size()]
			var cp: Dictionary = it.duplicate()
			# only 모드에서는 쌓인 값을 안 지운다 — 지우면 영영 0 이다
			if only == "":
				cp.gs = 0
			elif not g.owned.is_empty():
				cp.gs = int(g.owned[0].get("gs", 0))
			cp.bought = 1
			g.owned.append(cp)
		soak_arm = (soak_arm + 5) % maxi(items.size(), 1)
		g.sealed = -1
	g._process(1.0 / 60.0)
	# 쌓이는 동전이 진짜로 쌓이는가 — 정적 검사는 "한 걸음 넣으면 값이
	# 나온다" 만 본다. 그 걸음을 게임이 실제로 놓는지는 여기서만 보인다.
	for o in g.owned:
		if int(o.get("gs", 0)) != 0:
			grew[String(o.get("id", "?"))] = true
	if frames >= soak_n:
		var growers := []
		for it in GameData.items():
			if String(it.get("grow", "")) != "":
				growers.append(String(it.id))
		var miss := []
		for gi in growers:
			if not grew.has(gi):
				miss.append(gi)
		lines.append("④ 소크 — %d프레임 · 판 %d · 성장형 %d종 중 %d종이 실제로 쌓임"
				% [frames, g.leg_no, growers.size(), grew.size()])
		if not miss.is_empty():
			lines.append("     이 창에서 한 번도 안 쌓인 성장형: %s" % str(miss))
		if grew.is_empty():
			_bad("-", "성장", "소크 내내 어떤 동전도 값이 안 쌓였다")
		for l in lines:
			print(l)
		print("\n%s" % ("전부 통과" if fails == 0 else "실패 %d건" % fails))
		quit(mini(fails, 125))
	return false
