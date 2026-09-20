extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  챌린지 QA — 일곱이 실제로 규칙을 바꾸는가
#
#  실행:  godot --path . --headless --script scripts/tools/qa_chal.gd
#  종료 코드 = 실패 개수
#
#  챌린지는 표 한 장이 튜닝을 덮는 꼴이다. 새 계층을 안 팠으므로 "표에
#  적었는데 아무 데도 안 닿는" 실패가 가장 나기 쉽다 — 열마다 그것이
#  실제로 게임 값에 실리는지를 하나씩 본다.
#
#  대가와 보상이 한 줄에 같이 있는 것이 이 표의 규약이라, 둘 다 본다.
# ══════════════════════════════════════════════════════════

var g = null
var fails := 0
var done := false


func _initialize() -> void:
	Save.path = "user://_qa_chal.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(nm: String, cond: bool, detail: String) -> void:
	print("  %s %-28s %s" % ["OK  " if cond else "실패", nm, detail])
	if not cond:
		fails += 1


func _arm(id: String) -> void:
	GameData.challenge = id
	GameData.league = "white"
	GameData.pack = "base"
	g._new_run()
	g.leg_no = 1
	g._start_leg()


func _process(_d: float) -> bool:
	if done:
		return false
	done = true
	g.set_process(false)
	for i in 8:
		g._process(1.0 / 60.0)
	g._autoplay = false

	print("챌린지 검사 — 표가 실제로 게임을 미는가\n")

	# 표에 적힌 일곱이 다 있는가 (없음 한 줄 포함 여덟)
	var ids := []
	for c in GameData.challenges():
		ids.append(String(c.id))
	_ok("표가 선다", ids.size() == 8, "%d줄 %s" % [ids.size(), str(ids)])

	# ── 없음 — 기준선 ─────────────────────────────────────
	_arm("none")
	var base_slots: int = GameData.max_items()
	var base_tgt: int = GameData.target_of(3)
	var base_gold: int = int(g.gold)
	print("  기준선 — 슬롯 %d · 목표(판3) %d · 시작 골드 %d"
			% [base_slots, base_tgt, base_gold])

	# ── 홑장 — 슬롯 하나 · 효과 세 배 ────────────────────
	_arm("solo")
	_ok("홑장 — 슬롯이 하나다", GameData.max_items() == 1,
			"%d → %d" % [base_slots, GameData.max_items()])
	# 효과 배수는 정산 큐에 실린 수로 본다
	g.owned.clear()
	var coin: Dictionary = GameData.items()[0].duplicate()   # 무조건 배수 +4
	coin.gs = 0
	g.owned.append(coin)
	g.target = 1 << 30
	g.total = 0
	g.darts_left = 9
	g.aim = g.BC + Vector2(0.0, -g.R * 0.75)
	g._land()
	var got := 0
	for q in g.queue:
		if String(q.get("k", "")) == "item":
			got = int(q.get("v", 0))
	var want: int = int(coin.v) * 3
	_ok("홑장 — 효과가 세 배", got == want,
			"큐에 %d (기본 %d · 바라는 값 %d)" % [got, int(coin.v), want])
	#  ⚠ 여태 주 효과만 타고 **보조 효과(k2/v2)와 즉시 골드(gv)는 안 탔다** —
	#  슬롯을 하나로 줄인 대가가 복합 동전과 골드 동전에서 반쪽이었다.
	#  조건이 붙은 장은 그 조건을 맞춰야 발동한다 — 불 조건이면 불에 꽂는다.
	var twin := {}
	for it2 in GameData.items():
		if String(it2.get("k2", "")) != "" and int(it2.get("v2", 0)) != 0:
			var cd := String(it2.get("c", ""))
			if cd == "" or cd == "bull":
				twin = it2.duplicate()
				break
	if twin.is_empty():
		print("     (보조 효과가 있는 동전이 표에 없다 — 건너뛴다)")
	else:
		twin.gs = 0
		g.owned.clear()
		g.owned.append(twin)
		g.target = 1 << 30
		g.total = 0
		g.darts_left = 9
		g.aim = g.BC if String(twin.get("c", "")) == "bull" 				else g.BC + Vector2(0.0, -g.R * 0.75)
		g._land()
		var got2 := 0
		for q in g.queue:
			if String(q.get("k", "")) == "item" 					and String(q.get("kind", "")) == String(twin.k2):
				got2 = int(q.get("v", 0))
		_ok("홑장 — 보조 효과도 세 배", got2 == int(twin.v2) * 3,
				"%s · 큐에 %d (기본 %d)" % [twin.n, got2, int(twin.v2)])

	# ── 깜깜이 — 안개 상시 · 목표 0.7배 ───────────────────
	_arm("blind")
	_ok("깜깜이 — 안개가 상시로 켜진다", g.mod_v("fog", 0.0) > 0.0,
			"fog %.1f · 걸린 제약 %d개" % [g.mod_v("fog", 0.0), g.active_mods.size()])
	var bt: int = GameData.target_of(3)
	_ok("깜깜이 — 목표가 0.7배", bt < base_tgt,
			"%d → %d" % [base_tgt, bt])

	# ── 외상 — 빚으로 시작 · 이자 두 배 ───────────────────
	_arm("debt")
	_ok("외상 — 빚으로 시작한다", g.gold == -20, "골드 %d" % g.gold)
	#  ⚠ **빚에서 이자가 음수였다.** mini(−20 / 5, 5) = −4 이고 interest_mul 2
	#  가 그것을 −8 로 만들어 「골드 이자 2배」가 빚을 두 배로 불렸다.
	#  표의 값이 아니라 정수나눗셈이라 「밸런스는 나중에」에 안 걸린다.
	_ok("외상 — 빚에서 이자가 0 이상이다", g._interest_now() >= 0,
			"골드 %d · 이자 %d" % [g.gold, g._interest_now()])
	g.gold = 25
	_ok("외상 — 저축에는 이자가 두 배로 붙는다", g._interest_now() == 10,
			"골드 25 · 이자 %d" % g._interest_now())
	#  미리보기 둘이 같은 자를 쓰는가 — 세 자리가 갈리면 화면이 판을 속인다
	var settle: int = g._interest_now()
	g.total = g.target
	g.darts_left = 0
	g._settle_clear()
	var paid: int = 0
	for row in g.clear_gold_detail:
		if String(row.n) == "이자":
			paid = int(row.v)
	_ok("외상 — 미리보기와 정산이 같은 수다", paid == settle,
			"미리보기 %d · 정산 %d" % [settle, paid])
	#  ⚠ **사탕 「보유 골드 2배」가 빚을 두 배로 불렸다.** 이자와 **같은
	#  종류**인데 그 자리만 maxi(gold, 0) 을 안 지났다 — mini(−20, v) 가
	#  −20 을 내고 _gold_add 는 빼는 쪽을 안 막으므로 −40 이 됐고, 서식이
	#  "골드 +%d" 라 「골드 +−20」으로 찍혔다. 갑절은 **가진 것**의 값이다.
	#  2026-09-20
	var dbl := {}
	for c in GameData.rows("cons"):
		if String(c.get("cat", "")) == "gold":
			dbl = (c as Dictionary).duplicate()
			break
	if dbl.is_empty():
		_ok("외상 — 갑절 사탕이 표에 있다", false, "못 찾음")
	else:
		_arm("debt")
		g.cons = [dbl]
		var g0: int = g.gold
		g._cons_use(0)
		_ok("외상 — 갑절이 빚을 안 불린다", g.gold == g0,
				"골드 %d → %d" % [g0, g.gold])
		_arm("none")
		g.cons = [dbl]
		g.gold = 20
		g._cons_use(0)
		_ok("갑절은 저축에서는 그대로 돈다", g.gold > 20,
				"골드 20 → %d" % g.gold)

	# ── 빈손 — 버는 길이 끊기고 뱃지가 두 배 ──────────────
	_arm("empty")
	g.gold = 0
	g.total = g.target
	g.darts_left = 3
	g._settle_clear()
	_ok("빈손 — 클리어해도 골드가 안 는다", g.gold == 0, "골드 %d" % g.gold)
	#  ⚠ **내역도 같이 막는다.** 클리어와 잔탄은 0 으로 눌러 두는데 동전
	#  골드만 안 눌러서, 「알 낳는 거위 +4」가 금빛으로 서는데 총액은 0 인
	#  정산 표가 나왔다 — 「못 받은 줄은 눌러 둔다」가 한 줄에서만 깨졌다.
	#  2026-09-20
	var lit := []
	for row in g.clear_gold_detail:
		if int(row.v) != 0:
			lit.append("%s %d" % [String(row.n), int(row.v)])
	_ok("빈손 — 내역에 받은 줄이 하나도 없다", lit.is_empty(), str(lit))
	#  동전을 들려서도 잰다 — 새던 자리가 바로 이 갈래다
	_arm("empty")
	g.gold = 0
	var geese := []
	for it in GameData.items():
		if String(it.get("g", "")) == "leg" and int(it.get("gv", 0)) > 0:
			geese.append((it as Dictionary).duplicate())
			break
	if geese.is_empty():
		_ok("빈손 — 판 골드 동전이 표에 있다", false, "못 찾음")
	else:
		#  ⚠ **복제해서 넘긴다.** g.owned = geese 로 넘기면 같은 배열을
		#  가리켜, 밑의 _arm 이 부르는 _new_run 의 owned.clear() 가
		#  이 지역 변수까지 비운다.
		var gname := String(geese[0].get("n", ""))
		g.owned = geese.duplicate(true)
		g.total = g.target
		g.darts_left = 0
		g._settle_clear()
		var lit2 := []
		for row in g.clear_gold_detail:
			if int(row.v) != 0:
				lit2.append("%s %d" % [String(row.n), int(row.v)])
		_ok("빈손 — 동전 골드 줄이 내역에 안 선다", lit2.is_empty(), str(lit2))
		_ok("빈손 — 동전을 들어도 지갑이 안 는다", g.gold == 0,
				"골드 %d" % g.gold)
		#  없음에서는 그 줄이 제 값으로 선다 — 위 단언이 「늘 비었다」가 아니다
		_arm("none")
		g.owned = geese.duplicate(true)
		g.gold = 0
		g.total = g.target
		g.darts_left = 0
		g._settle_clear()
		var gv0 := 0
		for row in g.clear_gold_detail:
			if String(row.n) == gname:
				gv0 = int(row.v)
		_ok("없음에서는 그 동전 줄이 제 값으로 선다", gv0 > 0, "%d" % gv0)
	_arm("empty")
	g.gold = 0
	var tag := {}
	for t in GameData.tags():
		if String(t.get("kind", "")) == "gold":
			tag = t
			break
	if tag.is_empty():
		_ok("빈손 — 골드 뱃지가 표에 있다", false, "못 찾음")
	else:
		g._take_tag(tag)
		_ok("빈손 — 뱃지 골드가 두 배", g.gold == int(tag.get("v", 0)) * 2,
				"골드 %d (뱃지 %d)" % [g.gold, int(tag.get("v", 0))])
	#  ⚠ **여태 새는 갈래가 여섯이었다.** 막는 자리가 둘(이자·잔탄 · 클리어)
	#  뿐이라 정산의 item_gold · 동전 즉시 골드 · 판매 · 사탕 둘 · 사진
	#  태우기가 통째로 샜다. 기획서 P.16 은 「골드를 얻지 않는다」이고
	#  CSV 주석(「클리어·잔탄·이자를 통째로 막고」)은 구현 당시의 메모다 —
	#  **기획서가 계약이다.** 2026-09-20
	_arm("empty")
	g.gold = 0
	_ok("빈손 — 판매가 막힌다", g._gold_add(12, "sell") == 0 and g.gold == 0,
			"골드 %d" % g.gold)
	_ok("빈손 — 동전 즉시 골드가 막힌다", g._gold_add(9, "item") == 0, "")
	_ok("빈손 — 사탕이 막힌다", g._gold_add(20, "cons") == 0, "")
	_ok("빈손 — 사진 태우기가 막힌다", g._gold_add(30, "burn") == 0, "")
	_ok("빈손 — 정산 뭉치가 막힌다", g._gold_add(40, "settle") == 0, "")
	#  ⚠ **현상금만 예외다.** 그것이 「건너뛰기 보상」이고 표가 tag_mul 2 로
	#  일부러 두 배로 키운 그 갈래다 — 막으면 빈손의 유일한 수입이 사라져
	#  챌린지가 플레이 불가가 된다.
	_ok("빈손 — 현상금(뱃지)만 산다", g._gold_add(25, "tag") == 25 and g.gold == 25,
			"골드 %d" % g.gold)
	#  빼는 쪽은 안 막는다
	g.gold = 10
	g._gold_add(-4, "spend")
	_ok("빈손 — 빼는 쪽은 안 막는다", g.gold == 6, "골드 %d" % g.gold)

	# ── 큰손 — 물건이 공짜 ────────────────────────────────
	_arm("rich")
	_ok("큰손 — 값이 0 이다", g._league_cost(12) == 0,
			"12골드 → %d" % g._league_cost(12))
	#  ⚠ 리롤만 _league_cost 를 안 지나 **값을 받고 있었다.** 표가
	#  cost_mul 0 한 값으로 「상점의 **모든** 물건이 공짜」라 적었다 —
	#  대가는 shop_round 가 따로 치른다(보통 런 23번 → 큰손 7번).
	g.rerolls_used = 9
	_ok("큰손 — 리롤도 공짜다", g._reroll_price() == 0,
			"리롤 %d골드" % g._reroll_price())
	g.rerolls_used = 0
	_ok("큰손 — 상점이 라운드마다 한 번이다",
			GameData.chal_i("shop_round", 0) == 1, "shop_round %d" % GameData.chal_i("shop_round", 0))

	# ── 목표물 — 한 칸만 산다 ─────────────────────────────
	_arm("mark")
	_ok("목표물 — 판마다 칸을 뽑는다", g.mark_sec >= 0, "칸 %d" % g.mark_sec)
	var sw := 18.0 * PI / 180.0
	var hit: Vector2 = g.BC + Vector2(sin(float(g.mark_sec) * sw),
			-cos(float(g.mark_sec) * sw)) * g.R * 0.75
	var other: int = (g.mark_sec + 5) % 20
	var miss: Vector2 = g.BC + Vector2(sin(float(other) * sw),
			-cos(float(other) * sw)) * g.R * 0.75
	#  ⚠ **여기가 헛통과였다.** `int(g.hit_info(hit).base) > 0` 만 보고 있었는데
	#  hit_info 는 sec_mul 을 **안 탄다**(적용은 _land 한 곳이다) — 챌린지를
	#  안 걸어도 통과했다. 이제 _land 를 지나 큐로 잰다. 같은 점에 두 번
	#  꽂아 「챌린지가 걸린 때」와 「안 걸린 때」를 나란히 댄다. 2026-09-20
	g.target = 1 << 30
	g.total = 0
	g.darts_left = 9
	g.aim = hit
	g._land()
	while not g.queue.is_empty():
		g._next_step()
	var got_mark: int = g.total
	var keep_sec: int = g.mark_sec
	g.mark_sec = -1                 # 챌린지만 잠깐 끈다
	g.total = 0
	g.darts_left = 9
	g.aim = hit
	g._land()
	while not g.queue.is_empty():
		g._next_step()
	var got_bare: int = g.total
	g.mark_sec = keep_sec
	var want_mul: float = GameData.chal_f("sec_mul", 1.0)
	_ok("목표물 — 뽑힌 칸이 실제로 곱해진다",
			got_bare > 0 and absf(float(got_mark) - float(got_bare) * want_mul)
					<= float(got_bare) * 0.05,
			"칸 %d · 걸림 %d · 맨 %d (x%.1f)" % [keep_sec, got_mark, got_bare, want_mul])
	g.total = 0
	g.darts_left = 9
	g.aim = miss
	g._land()
	while not g.queue.is_empty():
		g._next_step()
	_ok("목표물 — 다른 칸은 0 이다", g.total == 0,
			"다른 칸(%d)에 꽂고 점수 %d" % [other, g.total])
	#  ⚠ **불은 산다.** hit_info 의 불은 idx = −1 이라 여태 else 에 떨어져
	#  0점이 됐다 — 그러면 조준 동전 · 리볼버 · 「정조준」 해금이 그 런에서
	#  통째로 죽는다(챌린지 하나가 다른 시스템 셋을 끈다).
	g.total = 0
	g.darts_left = 9
	g.aim = g.BC
	g._land()
	while not g.queue.is_empty():
		g._next_step()
	_ok("목표물 — 불은 0점이 아니다", g.total > 0, "불 점수 %d" % g.total)
	#  ⚠ **화면에 그려지는가.** mark_sec 이 나오는 줄이 다섯뿐이고 어느
	#  _draw 도 안 읽어서, 여태 어느 칸인지 알 길이 화면에 0곳이었다.
	_ok("목표물 — 뽑힌 칸을 그리는 자가 있다",
			g.has_method("_board_dim_sector"), "_board_dim_sector")
	#  ⚠ **그런데 판 밖까지 따라 나왔다.** mark_sec 을 −1 로 되돌리는 자리가
	#  _start_leg 하나뿐인데 _draw_aim 은 state 를 안 보고 매 프레임 불린다 —
	#  목표물 런을 끝내고 나오면 제목 화면의 다트판이 스무 칸 중 열아홉이
	#  검게 깔린 채였다. 판 뒤에 깔리는 그림은 「판이 서 있는가」를 같이
	#  물어야 한다. 겹쳐 뜨는 화면(런 정보·판 중의 설정)은 **뚫고** 묻는다.
	#  2026-09-20
	g.state = g.S.PICK
	_ok("목표물 — 판 위에서는 깔린다", g.mark_sec >= 0 and g._is_play_deep(),
			"칸 %d" % g.mark_sec)
	g.run_from = g.S.PICK
	g.state = g.S.RUNINFO
	_ok("목표물 — 런 정보를 열어도 안 걷힌다", g._is_play_deep(), "")
	g.pause_from = g.S.PICK
	g.state = g.S.SETTINGS
	_ok("목표물 — 판 중의 설정에서도 안 걷힌다", g._is_play_deep(), "")
	g.pause_from = -1
	for scr in [g.S.TITLE, g.S.NEWRUN, g.S.OVER, g.S.SHOP, g.S.SETTINGS]:
		g.state = scr
		if g._is_play_deep():
			_ok("목표물 — 판 밖(%d)까지 안 따라간다" % scr, false, "")
			break
	_ok("목표물 — 제목·로비·런 끝·상점까지 안 따라간다",
			not g._is_play_deep(), "칸 %d 인 채로 state %d" % [g.mark_sec, g.state])
	g.state = g.S.PICK

	# ── 겹치기 — 제약이 둘 ────────────────────────────────
	_arm("stack")
	var boss := -1
	for n in range(1, GameData.legs_n() + 1):
		if GameData.is_boss(n):
			boss = n
			break
	g.leg_no = boss
	#  「안 고른 카드에서 하나 더」가 사라졌다 — 이제 _roll_boss_mods 가
	#  want = mods_n 만큼 **확정으로** 건다. 카드에 둘 다 보이므로 옛
	#  주석이 걱정하던 「못 본 것이 걸린다」가 통째로 없어졌다(2026-09-18).
	g._open_leg()
	var bids: PackedStringArray = g.boss_mods.get(boss, PackedStringArray())
	_ok("겹치기 — 보스 판에 둘이 정해진다", bids.size() == 2,
			"정해진 제약 %d개" % bids.size())
	var seen := {}
	for mid in bids:
		seen[String(mid)] = true
	_ok("겹치기 — 서로 다른 둘이다", seen.size() == 2, "%s" % str(seen.keys()))
	g._begin_leg()
	_ok("겹치기 — 판이 서면 둘이 걸린다", g.active_mods.size() == 2,
			"걸린 제약 %d개" % g.active_mods.size())

	GameData.challenge = ""
	print("\n%s" % ("전부 통과" if fails == 0 else "실패 %d건" % fails))
	quit(mini(fails, 125))
	return true
