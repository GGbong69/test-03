extends RefCounted

# ══════════════════════════════════════════════════════════
#  개발자 모드
# ──────────────────────────────────────────────────────────
#  여는 키는 \ 다. 게임에 든 것을 손으로 다 켜 보는 자리. 프로브는 "값이 맞는가" 를 재고
#  이것은 "만져 보면 어떤가" 를 본다 — 둘은 다른 일이다. 스티커 178장을
#  하나씩 사서 확인하려면 런을 백 번 돌아야 한다.
#
#  ── 지우는 법 ────────────────────────────────────────────
#  정식 출시에 이것이 들어가면 안 된다. 지우는 자리를 **셋으로** 못 박는다.
#    ① 이 파일(scripts/dev.gd)을 지운다
#    ② game.gd 의 `const Dev = preload("res://scripts/dev.gd")` 한 줄
#    ③ game.gd 가 Dev 를 부르는 네 줄 — 전부 `# DEV` 주석이 달려 있다
#         _process()         Dev.tick(d)
#         _unhandled_input() Dev.key(self, k.keycode)
#         _click()           Dev.click(self, m)
#         _draw()            Dev.draw(self)
#  `grep -n "# DEV" scripts/game.gd` 로 그 다섯이 한 번에 나온다.
#
#  게임 상태는 여기서만 만진다. game.gd 에 개발자용 갈래를 파지 않는다 —
#  파는 순간 지우기가 "세 줄" 이 아니게 되고, 그러면 안 지워진다.
# ══════════════════════════════════════════════════════════

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

static var on := false
static var page := 0
static var pick := {}            # 목록형 줄의 지금 고른 번호
static var msg := ""
static var msg_t := 0.0

const PAGES := ["경제·진행", "물건", "판·조준", "해금"]
const W := 300.0
const ROW := 15.0


# ── 바깥과 닿는 셋 ────────────────────────────────────────

static func key(g: Node, code: int) -> bool:
	# \ 는 [ ] 옆이라 손이 이미 거기 있다 — 게이지 속도 조절과 같은 자리다.
	if code == KEY_BACKSLASH:
		on = not on
		if on:
			msg = "\\ 로 닫는다"
			msg_t = 2.0
		return true
	if not on:
		return false
	if code == KEY_TAB:
		page = (page + 1) % PAGES.size()
		return true
	return false


static func click(g: Node, m: Vector2) -> bool:
	if not on:
		return false
	for i in PAGES.size():
		if _tab(i).has_point(m):
			page = i
			return true
	var rows := _rows(g)
	for i in rows.size():
		var r := _row(i)
		if not r.has_point(m):
			continue
		var e: Dictionary = rows[i]
		if String(e.t) == "list":
			# 왼쪽 3분의 1 은 이전, 오른쪽 3분의 1 은 다음, 가운데는 실행
			var f: float = (m.x - r.position.x) / r.size.x
			var n: int = int(e.n)
			if n > 0:
				var cur: int = int(pick.get(e.k, 0))
				if f < 0.30:
					pick[e.k] = (cur - 1 + n) % n
				elif f > 0.70:
					pick[e.k] = (cur + 1) % n
				else:
					_run(g, e)
		else:
			_run(g, e)
		return true
	return _panel().has_point(m)          # 판 안의 헛클릭은 삼킨다


static func draw(g: Node) -> void:
	if not on:
		return
	var p := _panel()
	g.draw_rect(p, Color(0.04, 0.03, 0.07, 0.94))
	g.draw_rect(Rect2(p.position, Vector2(p.size.x, 2.0)), Color(1.0, 0.35, 0.35))
	g.draw_string(g.font, p.position + Vector2(8.0, 15.0), "개발자",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.35, 0.35))
	g.draw_string(g.font, p.position + Vector2(0.0, 15.0), "\\ 닫기 · TAB 다음 쪽",
			HORIZONTAL_ALIGNMENT_RIGHT, p.size.x - 8.0, 11, Color(0.55, 0.52, 0.60))

	for i in PAGES.size():
		var t := _tab(i)
		g.draw_rect(t, Color(0.16, 0.14, 0.22) if i != page else Color(0.30, 0.26, 0.40))
		g.draw_string(g.font, t.position + Vector2(0.0, 11.0), PAGES[i],
				HORIZONTAL_ALIGNMENT_CENTER, t.size.x, 11,
				Color(1, 1, 1) if i == page else Color(0.6, 0.58, 0.66))

	var rows := _rows(g)
	for i in rows.size():
		var e: Dictionary = rows[i]
		var r := _row(i)
		g.draw_rect(r, Color(0.13, 0.11, 0.18))
		g.draw_string(g.font, r.position + Vector2(6.0, 11.0), String(e.n1),
				HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12.0, 11, Color(0.86, 0.86, 0.92))
		if String(e.t) == "list":
			g.draw_string(g.font, r.position + Vector2(0.0, 11.0),
					"◀ %s ▶" % _cur_name(e), HORIZONTAL_ALIGNMENT_RIGHT,
					r.size.x - 6.0, 11, Color(1.0, 0.80, 0.35))

	if msg != "":
		g.draw_string(g.font, p.position + Vector2(6.0, p.size.y - 6.0), msg,
				HORIZONTAL_ALIGNMENT_LEFT, p.size.x - 12.0, 11, Color(0.55, 1.0, 0.65))


static func tick(d: float) -> void:
	if msg_t > 0.0:
		msg_t -= d
		if msg_t <= 0.0:
			msg = ""


# ── 자리 ──────────────────────────────────────────────────

static func _panel() -> Rect2:
	return Rect2(Vector2(4.0, 22.0), Vector2(W, 330.0))


static func _tab(i: int) -> Rect2:
	var p := _panel()
	var w: float = (p.size.x - 12.0) / float(PAGES.size())
	return Rect2(p.position + Vector2(6.0 + float(i) * w, 20.0), Vector2(w - 2.0, 14.0))


static func _row(i: int) -> Rect2:
	var p := _panel()
	return Rect2(p.position + Vector2(6.0, 40.0 + float(i) * ROW),
			Vector2(p.size.x - 12.0, ROW - 2.0))


# ── 쪽마다 무엇이 있나 ────────────────────────────────────
#  n1  화면에 적을 이름
#  t   "act" 누르면 실행 · "list" 좌우로 고르고 가운데를 누르면 실행
#  k   목록 열쇠 · n 목록 길이

static func _rows(g: Node) -> Array:
	match page:
		0:
			return [
				{"n1": "골드 +50", "t": "act", "a": "gold", "v": 50},
				{"n1": "골드 −50", "t": "act", "a": "gold", "v": -50},
				{"n1": "이 판 목표 채우기", "t": "act", "a": "fill"},
				{"n1": "이 판 클리어", "t": "act", "a": "clear"},
				{"n1": "즉시 실패", "t": "act", "a": "lose"},
				{"n1": "판 +1", "t": "act", "a": "round", "v": 1},
				{"n1": "판 −1", "t": "act", "a": "round", "v": -1},
				{"n1": "상점 열기", "t": "act", "a": "shop"},
				{"n1": "판 선택 열기", "t": "act", "a": "blind"},
				{"n1": "다트 다시 채우기", "t": "act", "a": "refill"},
			]
		1:
			return [
				{"n1": "스티커 주기", "t": "list", "k": "item",
						"n": GameData.items().size()},
				{"n1": "스티커 무작위", "t": "act", "a": "item_rand"},
				{"n1": "랙 비우기", "t": "act", "a": "item_clear"},
				{"n1": "소비 주기", "t": "list", "k": "cons",
						"n": GameData.consumables().size()},
				{"n1": "개조 달기", "t": "list", "k": "mod",
						"n": GameData.mods().size()},
				{"n1": "다트 바꾸기", "t": "list", "k": "dart",
						"n": GameData.darts().size()},
				{"n1": "설비 주기", "t": "list", "k": "vou",
						"n": GameData.vouchers().size()},
				{"n1": "딱지 주기", "t": "list", "k": "tag",
						"n": GameData.tags().size()},
				{"n1": "매대 다시 굴리기", "t": "act", "a": "restock"},
			]
		2:
			return [
				{"n1": "제약 걸기", "t": "list", "k": "mf",
						"n": GameData.modifiers().size()},
				{"n1": "제약 풀기", "t": "act", "a": "mf_off"},
				{"n1": "조준 방식", "t": "list", "k": "aim",
						"n": GameData.AIM_MODES.size()},
				{"n1": "계산 방식", "t": "list", "k": "score",
						"n": GameData.SCORE_MODES.size()},
				{"n1": "리그", "t": "list", "k": "stake",
						"n": GameData.stakes().size()},
				{"n1": "팩", "t": "list", "k": "pack",
						"n": GameData.packs().size()},
				{"n1": "판 다시 굽기", "t": "act", "a": "bake"},
			]
		_:
			return [
				{"n1": "해금 전부 열기", "t": "act", "a": "unlock_all"},
				{"n1": "해금 전부 잠그기", "t": "act", "a": "unlock_none"},
				{"n1": "통계 지우기", "t": "act", "a": "stat_clear"},
				{"n1": "저장 통째로 지우기", "t": "act", "a": "wipe"},
			]


static func _list(k: String) -> Array:
	match k:
		"item": return GameData.items()
		"cons": return GameData.consumables()
		"mod": return GameData.mods()
		"dart": return GameData.darts()
		"vou": return GameData.vouchers()
		"tag": return GameData.tags()
		"mf": return GameData.modifiers()
		"stake": return GameData.stakes()
		"pack": return GameData.packs()
	return []


static func _cur_name(e: Dictionary) -> String:
	var k := String(e.k)
	var i: int = int(pick.get(k, 0))
	if k == "aim":
		return String(GameData.AIM_MODES[i % maxi(GameData.AIM_MODES.size(), 1)])
	if k == "score":
		return String(GameData.SCORE_MODES[i % maxi(GameData.SCORE_MODES.size(), 1)])
	var rows := _list(k)
	if rows.is_empty():
		return "(없음)"
	var r: Dictionary = rows[i % rows.size()]
	var nm := String(r.get("n", r.get("name", r.get("id", "?"))))
	return "%d/%d %s" % [i + 1, rows.size(), nm]


# ── 실행 ──────────────────────────────────────────────────

static func _say(t: String) -> void:
	msg = t
	msg_t = 2.5


static func _run(g: Node, e: Dictionary) -> void:
	var k := String(e.get("k", ""))
	var i: int = int(pick.get(k, 0))
	match String(e.get("a", "")):
		"gold":
			g.gold = maxi(g.gold + int(e.v), 0)
			_say("골드 %d" % g.gold)
			return
		"fill":
			g.total = g.target
			g.shown = float(g.target)
			_say("점수 %d" % g.total)
			return
		"clear":
			g.total = g.target
			g._finish_round()
			_say("클리어")
			return
		"lose":
			g.total = 0
			g.darts_left = 0
			g.remaining.clear()
			g._finish_round()
			_say("실패")
			return
		"round":
			g.round_no = clampi(g.round_no + int(e.v), 1, GameData.rounds_n())
			g._open_blind()
			_say("판 %d" % g.round_no)
			return
		"shop":
			g._open_shop()
			_say("상점")
			return
		"blind":
			g._open_blind()
			_say("판 선택")
			return
		"refill":
			g._start_round()
			_say("다트 %d발" % g.remaining.size())
			return
		"item_rand":
			var pool := GameData.items()
			if not pool.is_empty():
				_give_item(g, pool[randi() % pool.size()])
			return
		"item_clear":
			g.owned.clear()
			g.sealed = -1
			g._panel_reset()
			_say("랙 비움")
			return
		"restock":
			g._roll_stock()
			_say("매대 다시")
			return
		"mf_off":
			g.active_mods = []
			g._start_round()
			_say("제약 없음")
			return
		"bake":
			g._board_bake()
			_say("판 다시 구움")
			return
		"unlock_all":
			var n := 0
			for r in GameData.packs():
				if Save.unlock("pack:" + String(r.get("id", ""))):
					n += 1
			for r in GameData.packs():
				for st in GameData.stakes():
					if Save.unlock(GameData.stake_key(String(st.get("id", "")),
							String(r.get("id", "")))):
						n += 1
			_say("%d개 열었다" % n)
			return
		"unlock_none":
			var n2 := 0
			for key2 in Save.unlock_keys():
				if Save.lock(String(key2)):
					n2 += 1
			_say("%d개 잠갔다" % n2)
			return
		"stat_clear", "wipe":
			Save.wipe()
			_say("저장 지움")
			return

	# 목록형 — 지금 고른 것을 적용한다
	var rows := _list(k)
	match k:
		"aim":
			g.aim_mode = String(GameData.AIM_MODES[i % GameData.AIM_MODES.size()])
			_say("조준 '%s'" % g.aim_mode)
		"score":
			g.score_mode = String(GameData.SCORE_MODES[i % GameData.SCORE_MODES.size()])
			_say("계산 '%s'" % g.score_mode)
		"item":
			if not rows.is_empty():
				_give_item(g, rows[i % rows.size()])
		"cons":
			if not rows.is_empty() and g.cons.size() < GameData.cons_slots():
				g.cons.append(rows[i % rows.size()])
				_say("소비 %d/%d" % [g.cons.size(), GameData.cons_slots()])
		"mod":
			if not rows.is_empty():
				var mid := String(rows[i % rows.size()].id)
				if not g.mods_own.has(mid):
					g.mods_own.append(mid)
				g._board_bake()
				_say("개조 %s" % mid)
		"dart":
			if not rows.is_empty():
				var dd: Dictionary = rows[i % rows.size()]
				g.magazine.clear()
				for z in 6:
					g.magazine.append(dd)
				g._start_round()
				_say("다트 %s" % dd.get("n", dd.get("name", "")))
		"vou":
			if not rows.is_empty():
				GameData.voucher_add(String(rows[i % rows.size()].id))
				_say("설비 %d개" % GameData.vouchers_own.size())
		"tag":
			if not rows.is_empty():
				g._take_tag(rows[i % rows.size()])
		"mf":
			if not rows.is_empty():
				g.active_mods = [rows[i % rows.size()]]
				g._start_round()
				_say("제약 %s" % g.active_mods[0].get("n", ""))
		"stake":
			if not rows.is_empty():
				GameData.stake = String(rows[i % rows.size()].get("id", ""))
				_say("리그 %s" % GameData.stake)
		"pack":
			if not rows.is_empty():
				GameData.pack = String(rows[i % rows.size()].get("id", ""))
				_say("팩 %s — 새 런부터" % GameData.pack)


static func _give_item(g: Node, it: Dictionary) -> void:
	if g.owned.size() >= GameData.max_items():
		_say("랙이 꽉 찼다")
		return
	var c: Dictionary = it.duplicate()
	c.gs = 0
	c.bought = g.round_no
	g.owned.append(c)
	g._panel_reset()
	_say("%s" % c.get("n", ""))
