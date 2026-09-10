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

	# ① 비상금 — 보유 골드가 갑절이 되되 늘어나는 폭에 상한이 있다
	if _hold("v_cash"):
		var cap: int = int(_find("v_cash").get("v", 0))
		g.gold = 5
		g._cons_use(0)
		_ok("비상금 — 갑절", g.gold == 10, "5 → %d" % g.gold)
		_ok("비상금 — 쓰면 사라진다", g.cons.is_empty(), "손에 %d장" % g.cons.size())
		_hold("v_cash")
		g.gold = 100                     # 갑절이면 +100 인데 상한이 막는다
		g._cons_use(0)
		_ok("비상금 — 상한이 막는다", g.gold == 100 + cap,
				"100 → %d (상한 +%d)" % [g.gold, cap])
	else:
		_ok("비상금이 표에 있다", false, "못 찾음")

	# ② 동전 줍기 — 든 동전의 판매가 합
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
		_ok("동전 줍기 — 판매가 합", g.gold == want,
				"동전 %d장 · 골드 %d (바라는 값 %d)" % [g.owned.size(), g.gold, want])
		# 동전이 없으면 0 이다 — 살 때를 고르는 것 자체가 판단이 된다
		_hold("v_pick")
		g.owned.clear()
		g.gold = 0
		g._cons_use(0)
		_ok("동전 줍기 — 빈손이면 0", g.gold == 0, "골드 %d" % g.gold)
	else:
		_ok("동전 줍기가 표에 있다", false, "못 찾음")

	# ③ 재도전 — 점수와 다트가 판 시작으로 돌아간다. 목표는 그대로다.
	if _hold("v_redo"):
		g.target = 500                   # _start_leg 은 목표를 안 세운다
		var tgt: int = int(g.target)
		g.total = 999
		g.darts_left = 1
		g._cons_use(0)
		_ok("재도전 — 점수가 0 으로", g.total == 0, "999 → %d" % g.total)
		_ok("재도전 — 다트가 돌아온다", g.darts_left > 1,
				"1 → %d" % g.darts_left)
		_ok("재도전 — 목표는 그대로", g.target == tgt,
				"%d → %d" % [tgt, g.target])
		_ok("재도전 — 쓰면 사라진다", g.cons.is_empty(), "손에 %d장" % g.cons.size())
	else:
		_ok("재도전이 표에 있다", false, "못 찾음")

	# ④ 면죄부 — 다음 보스 판에서 고른 제약이 안 걸린다
	if _hold("v_par"):
		g._cons_use(0)
		_ok("면죄부 — 깃발이 선다", g.pardon_next, "pardon_next %s" % g.pardon_next)
		# 보스 판을 열고 하나 고른다. 몇 번째가 보스인지는 표가 정하므로
		# 숫자를 박지 않고 물어본다 — legs_per_round 가 바뀌어도 안 깨진다.
		var boss := -1
		for n in range(1, GameData.legs_n() + 1):
			if GameData.is_boss(n):
				boss = n
				break
		g.leg_no = boss
		g._open_stage()
		if g.stage_pick.is_empty():
			_ok("면죄부 — 보스 판이 열린다", false, "제약 카드가 안 깔렸다")
		else:
			g._pick_stage(0)
			_ok("면죄부 — 제약이 안 걸린다", g.active_mods.is_empty(),
					"걸린 제약 %d개" % g.active_mods.size())
			_ok("면죄부 — 한 번만 선다", not g.pardon_next,
					"pardon_next %s" % g.pardon_next)
	else:
		_ok("면죄부가 표에 있다", false, "못 찾음")

	# ⑤ 자리 제한 — 쓸 수 없는 자리에서는 손에서 안 없어져야 한다
	g.state = g.S.SHOP
	_hold("v_pnt")
	g._cons_use(0)
	_ok("페인트 — 상점에서는 못 쓴다", g.cons.size() == 1 and g.photo == "",
			"손에 %d장 · photo '%s'" % [g.cons.size(), g.photo])
	g.state = g.S.PICK
	_hold("v_moth")
	g._cons_use(0)
	_ok("불나방 — 판에서는 못 쓴다", g.cons.size() == 1 and g.photo == "",
			"손에 %d장 · photo '%s'" % [g.cons.size(), g.photo])

	# ⑥ 불나방 — 테이블이 갈리고 판매 창구가 부순다
	g.state = g.S.SHOP
	g.owned.clear()
	var coin: Dictionary = GameData.items()[0].duplicate()
	coin.gs = 0
	g.owned.append(coin)
	var want_g: int = GameData.sell_value(coin) * 2
	_hold("v_moth")
	g._cons_use(0)
	_ok("불나방 — 테이블이 내 동전으로 갈린다",
			g.photo == "burn" and g.stock.size() == 1,
			"photo '%s' · 테이블 %d개" % [g.photo, g.stock.size()])
	g.gold = 0
	g.buy_sel = 0
	g._chute_click(g.Z_SELL)
	_ok("불나방 — 부수고 판매가의 곱절", g.owned.is_empty() and g.gold == want_g,
			"동전 %d장 · 골드 %d (바라는 값 %d)" % [g.owned.size(), g.gold, want_g])
	_ok("불나방 — 테이블이 돌아온다", g.photo == "", "photo '%s'" % g.photo)

	# ⑦ 위조화폐 — 복제 창구가 한 장을 더 준다
	g.owned.clear()
	g.owned.append(GameData.items()[0].duplicate())
	_hold("v_fake")
	g._cons_use(0)
	_ok("위조화폐 — 테이블이 갈린다", g.photo == "clone", "photo '%s'" % g.photo)
	g.buy_sel = 0
	g._chute_click(g.Z_BUY)
	_ok("위조화폐 — 한 장이 더 생긴다", g.owned.size() == 2,
			"동전 %d장" % g.owned.size())
	_ok("위조화폐 — 반대쪽 창구로는 안 된다", g.photo == "", "photo '%s'" % g.photo)

	# ⑧ 페인트 — 고른 칸의 점수가 곱해진다
	g.state = g.S.PICK
	g.leg_no = 1
	g._start_leg()
	_hold("v_pnt")
	g._cons_use(0)
	_ok("페인트 — 고르는 화면이 열린다", g.photo == "paint", "photo '%s'" % g.photo)
	# 판 위의 한 자리를 눌러 그 칸을 칠한다
	var pt: Vector2 = g.BC + Vector2(0.0, -g.R * 0.75)
	var idx: int = g._paint_hit(pt)
	var raw_v: int = int(g.hit_info(pt).base)
	g._paint_click(pt)
	_ok("페인트 — 칸이 칠해진다", g.paint_sec == idx and g.photo == "",
			"칸 %d · photo '%s'" % [g.paint_sec, g.photo])
	g.aim = pt
	g.total = 0
	g.target = 1 << 30
	g.darts_left = 9
	g._land()
	while not g.queue.is_empty():
		g._next_step()
	_ok("페인트 — 점수가 곱해진다", g.total >= raw_v * 2,
			"칠 안 한 값 %d · 실제 %d" % [raw_v, g.total])
	g._start_leg()
	_ok("페인트 — 판이 바뀌면 풀린다", g.paint_sec == -1, "칸 %d" % g.paint_sec)

	# ⑨ 한 수 앞 — 본 셋이 그 판에 그대로 깔린다
	g.state = g.S.SHOP
	g.leg_no = 1
	_hold("v_peek")
	g._cons_use(0)
	_ok("한 수 앞 — 셋을 읽는다",
			g.photo == "peek" and g.peek_pick.size() == GameData.stage_picks(),
			"photo '%s' · %d장" % [g.photo, g.peek_pick.size()])
	var seen := []
	for e in g.peek_pick:
		seen.append(String(e.d.get("id", "")))
	var pl: int = int(g.peek_leg)
	g.photo = ""
	g.leg_no = pl
	g._open_stage()
	var got := []
	for e in g.stage_pick:
		got.append(String(e.d.get("id", "")))
	_ok("한 수 앞 — 본 것이 그대로 뜬다", seen == got,
			"본 것 %s · 뜬 것 %s" % [str(seen), str(got)])

	print("\n%s" % ("전부 통과" if fails == 0 else "실패 %d건" % fails))
	quit(mini(fails, 125))
	return true
