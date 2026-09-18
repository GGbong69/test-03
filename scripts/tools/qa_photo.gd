extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  사진 QA — 1회성 사진이 실제로 일하는가
#
#  실행:  godot --path . --headless --script scripts/tools/qa_photo.gd
#  종료 코드 = 실패 개수
#
#  2026-09-10 기획서에서 사진이 상시 강화에서 1회성으로 바뀌었다. 쓰는 길은
#  사탕과 같다(_cons_use) — 대상을 안 고르는 넷만 켜져 있고, 고르는 흐름이
#  필요한 넷은 표에 눕혀 뒀다.
#
#  넷을 하나씩 손에 쥐여 주고 눌러 본다. 쓰고 나면 손에서 사라져야 한다 —
#  1회성이라는 말이 그 뜻이다.
# ══════════════════════════════════════════════════════════

var g = null
var fails := 0
var done := false


func _initialize() -> void:
	Save.path = "user://_qa_photo.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(nm: String, cond: bool, detail: String) -> void:
	print("  %s %-26s %s" % ["OK  " if cond else "실패", nm, detail])
	if not cond:
		fails += 1


func _find(id: String) -> Dictionary:
	for c in GameData.consumables():
		if String(c.id) == id:
			return c.duplicate()
	return {}


func _hold(id: String) -> bool:
	var c := _find(id)
	if c.is_empty():
		return false
	g.cons = [c]
	return true


func _process(_d: float) -> bool:
	if done:
		return false
	done = true
	g.set_process(false)
	for i in 8:
		g._process(1.0 / 60.0)
	g._new_run()
	g.leg_no = 1
	g._start_leg()
	g._autoplay = false

	print("사진 검사 — 대상을 안 고르는 넷\n")

	# ① 오리 금고 — 보유 골드가 갑절이 되되 늘어나는 폭에 상한이 있다
	if _hold("v_cash"):
		var cap: int = int(_find("v_cash").get("v", 0))
		g.gold = 5
		g._cons_use(0)
		_ok("오리 금고 — 갑절", g.gold == 10, "5 → %d" % g.gold)
		_ok("오리 금고 — 쓰면 사라진다", g.cons.is_empty(), "손에 %d장" % g.cons.size())
		_hold("v_cash")
		g.gold = 100                     # 갑절이면 +100 인데 상한이 막는다
		g._cons_use(0)
		_ok("오리 금고 — 상한이 막는다", g.gold == 100 + cap,
				"100 → %d (상한 +%d)" % [g.gold, cap])
	else:
		_ok("오리 금고가 표에 있다", false, "못 찾음")

	# ② 금고 속 수영 — 든 동전의 판매가 합
	if _hold("v_pick"):
		g.owned.clear()
		var want := 0
		for it in GameData.items():
			if g.owned.size() >= 3:
				break
			var cp: Dictionary = it.duplicate()
			cp.gs = 0
			g.owned.append(cp)
			want += GameData.sell_value(cp)
		g.gold = 0
		g._cons_use(0)
		_ok("금고 속 수영 — 판매가 합", g.gold == want,
				"동전 %d장 · 골드 %d (바라는 값 %d)" % [g.owned.size(), g.gold, want])
		# 동전이 없으면 0 이다 — 살 때를 고르는 것 자체가 판단이 된다
		_hold("v_pick")
		g.owned.clear()
		g.gold = 0
		g._cons_use(0)
		_ok("금고 속 수영 — 빈손이면 0", g.gold == 0, "골드 %d" % g.gold)
	else:
		_ok("금고 속 수영이 표에 있다", false, "못 찾음")

	# ③ 또 같은 아침 — 점수와 다트가 판 시작으로 돌아간다. 목표는 그대로다.
	if _hold("v_redo"):
		g.target = 500                   # _start_leg 은 목표를 안 세운다
		var tgt: int = int(g.target)
		g.total = 999
		g.darts_left = 1
		g._cons_use(0)
		_ok("또 같은 아침 — 점수가 0 으로", g.total == 0, "999 → %d" % g.total)
		_ok("또 같은 아침 — 다트가 돌아온다", g.darts_left > 1,
				"1 → %d" % g.darts_left)
		_ok("또 같은 아침 — 목표는 그대로", g.target == tgt,
				"%d → %d" % [tgt, g.target])
		_ok("또 같은 아침 — 쓰면 사라진다", g.cons.is_empty(), "손에 %d장" % g.cons.size())
	else:
		_ok("또 같은 아침이 표에 있다", false, "못 찾음")

	# ④ GOOD AFTERNOON — 다음 보스 판의 제약과 오른 목표가 같이 풀린다
	# use_at rest 라 상점이나 판 고르기에 서야 쓴다(기획서 s33).
	#  깃발이 아니라 **판 번호**를 못 박는다 — 읽고 끄는 자리가 하나뿐이면
	#  그 자리가 사라지는 날 15G 짜리 카드가 조용히 아무 일도 안 한다.
	#  셋(무효 표시 · 제약 없음 · 목표 원복)을 한 번에 잰다. 하나만 빠져도
	#  조용히 죽는 자리다 — 「문턱」이 걸린 보스에서 제약만 지우면 목표가
	#  오른 채 남는다(2026-09-18).
	g.state = g.S.SHOP
	if _hold("v_par"):
		# 몇 번째가 보스인지는 표가 정하므로 숫자를 박지 않고 물어본다.
		var boss := -1
		for n in range(1, GameData.legs_n() + 1):
			if GameData.is_boss(n):
				boss = n
				break
		g.leg_no = 1
		#  「문턱」을 손으로 꽂아 목표 원복까지 같이 잰다.
		g._roll_boss_mods(boss, true)
		g.boss_mods[boss] = PackedStringArray(["tgt"])
		var bare: int = GameData.target_of(boss)
		var lifted: int = g._target_at(boss)
		_ok("문턱이 목표를 민다", lifted > bare, "%d → %d" % [bare, lifted])
		g._cons_use(0)
		_ok("GOOD AFTERNOON — 그 판이 무효로 선다", g.boss_void.has(boss),
				"무효 %s" % str(g.boss_void.keys()))
		_ok("GOOD AFTERNOON — 목표가 맨 목표로 돌아온다",
				g._target_at(boss) == bare,
				"%d (맨 목표 %d)" % [g._target_at(boss), bare])
		g.leg_no = boss
		g._begin_leg()
		_ok("GOOD AFTERNOON — 제약이 안 걸린다", g.active_mods.is_empty(),
				"걸린 제약 %d개" % g.active_mods.size())
		_ok("GOOD AFTERNOON — 판정 목표도 맨 목표다", g.target == bare,
				"%d (맨 목표 %d)" % [g.target, bare])
		g.boss_void.clear()
	else:
		_ok("GOOD AFTERNOON 이 표에 있다", false, "못 찾음")

	# ⑤ 자리 제한 — 쓸 수 없는 자리에서는 손에서 안 없어져야 한다
	g.state = g.S.SHOP
	_hold("v_pnt")
	g._cons_use(0)
	_ok("빨강, 파랑, 노랑 — 상점에서는 못 쓴다", g.cons.size() == 1 and g.photo == "",
			"손에 %d장 · photo '%s'" % [g.cons.size(), g.photo])
	# 기획서 s33 이 It's Not About Money 를 「상관없음」으로 적었다. 판 위에는
	# 테이블이 없으므로 동전 슬롯에서 고른다 — 고르기 전에는 손에 남는다.
	g.state = g.S.PICK
	g.owned.clear()
	var c0: Dictionary = GameData.items()[0].duplicate()
	c0.gs = 0
	g.owned.append(c0)
	_hold("v_moth")
	g._cons_use(0)
	_ok("It's Not About Money — 판에서는 동전 슬롯에서 고른다",
			g.photo_rack == "burn" and g.cons.size() == 1,
			"photo_rack '%s' · 손에 %d장" % [g.photo_rack, g.cons.size()])
	var wg: int = GameData.sell_value(c0) * 2
	g.gold = 0
	g._photo_rack_click(g._slot_rect(0).get_center())
	_ok("It's Not About Money — 고르면 부수고 판매가 2배",
			g.gold == wg and g.owned.is_empty() and g.cons.is_empty(),
			"골드 %d/%d · 동전 %d · 손 %d" % [g.gold, wg, g.owned.size(), g.cons.size()])
	g.photo_rack = ""

	# ⑥ It's Not About Money — 테이블이 갈리고 판매 창구가 부순다
	g.state = g.S.SHOP
	g.owned.clear()
	var coin: Dictionary = GameData.items()[0].duplicate()
	coin.gs = 0
	g.owned.append(coin)
	var want_g: int = GameData.sell_value(coin) * 2
	_hold("v_moth")
	g._cons_use(0)
	_ok("It's Not About Money — 테이블이 내 동전으로 갈린다",
			g.photo == "burn" and g.stock.size() == 1,
			"photo '%s' · 테이블 %d개" % [g.photo, g.stock.size()])
	g.gold = 0
	g.buy_sel = 0
	g._chute_click(g.Z_SELL)
	_ok("It's Not About Money — 부수고 판매가의 곱절", g.owned.is_empty() and g.gold == want_g,
			"동전 %d장 · 골드 %d (바라는 값 %d)" % [g.owned.size(), g.gold, want_g])
	_ok("It's Not About Money — 테이블이 돌아온다", g.photo == "", "photo '%s'" % g.photo)

	# ⑦ 마릴린 딥틱 — 복제 창구가 한 장을 더 준다
	g.owned.clear()
	g.owned.append(GameData.items()[0].duplicate())
	_hold("v_fake")
	g._cons_use(0)
	_ok("마릴린 딥틱 — 테이블이 갈린다", g.photo == "clone", "photo '%s'" % g.photo)
	g.buy_sel = 0
	g._chute_click(g.Z_BUY)
	_ok("마릴린 딥틱 — 한 장이 더 생긴다", g.owned.size() == 2,
			"동전 %d장" % g.owned.size())
	_ok("마릴린 딥틱 — 반대쪽 창구로는 안 된다", g.photo == "", "photo '%s'" % g.photo)

	# ⑧ 빨강, 파랑, 노랑 — 고른 칸의 점수가 곱해진다
	g.state = g.S.PICK
	g.leg_no = 1
	g._start_leg()
	_hold("v_pnt")
	g._cons_use(0)
	_ok("빨강, 파랑, 노랑 — 고르는 화면이 열린다", g.photo == "paint", "photo '%s'" % g.photo)
	# 판 위의 한 자리를 눌러 그 칸을 칠한다
	var pt: Vector2 = g.BC + Vector2(0.0, -g.R * 0.75)
	var idx: int = g._paint_hit(pt)
	var raw_v: int = int(g.hit_info(pt).base)
	g._paint_click(pt)
	_ok("빨강, 파랑, 노랑 — 칸이 칠해진다", g.paint_sec == idx and g.photo == "",
			"칸 %d · photo '%s'" % [g.paint_sec, g.photo])
	g.aim = pt
	g.total = 0
	g.target = 1 << 30
	g.darts_left = 9
	g._land()
	while not g.queue.is_empty():
		g._next_step()
	_ok("빨강, 파랑, 노랑 — 점수가 곱해진다", g.total >= raw_v * 2,
			"칠 안 한 값 %d · 실제 %d" % [raw_v, g.total])
	g._start_leg()
	_ok("빨강, 파랑, 노랑 — 판이 바뀌면 풀린다", g.paint_sec == -1, "칸 %d" % g.paint_sec)

	# ⑨ 프리크라임 — 다시 뽑으면 **실제로 달라진다**
	#  읽기에서 다시 뽑기로 갈아탔다(2026-09-18). 옛 검사는 「본 것이
	#  그대로 뜬다」를 쟀는데, 제약이 카드에 상시로 보이는 지금 그 검사는
	#  통과하면서 게임만 죽은 카드를 쥐고 있게 된다.
	g.state = g.S.SHOP
	g.leg_no = 1
	var pboss: int = g._boss_ahead()
	g._roll_boss_mods(pboss, true)
	var was: PackedStringArray = g.boss_mods.get(pboss, PackedStringArray())
	var before := []
	for mid in was:
		before.append(String(mid))
	_hold("v_peek")
	g._cons_use(0)
	var now := []
	for mid in g.boss_mods.get(pboss, PackedStringArray()):
		now.append(String(mid))
	_ok("프리크라임 — 보스 제약이 달라진다", before != now and not now.is_empty(),
			"%s → %s" % [str(before), str(now)])
	_ok("프리크라임 — 쓰면 사라진다", g.cons.is_empty(), "손에 %d장" % g.cons.size())

	print("\n%s" % ("전부 통과" if fails == 0 else "실패 %d건" % fails))
	quit(mini(fails, 125))
	return true
