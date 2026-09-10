extends RefCounted

# ══════════════════════════════════════════════════════════
#  개발자 모드
# ──────────────────────────────────────────────────────────
#  여는 키는 \ 다. 게임에 든 것을 손으로 다 켜 보는 자리. 프로브는 "값이 맞는가" 를 재고
#  이것은 "만져 보면 어떤가" 를 본다 — 둘은 다른 일이다. 동전 178장을
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

# 목록 고르개 — 값 칸을 누르면 열린다. 화살표로 한 장씩 넘기는 것은 동전
# 95장 앞에서 못 쓴다(끝까지 가려면 아흔네 번을 눌러야 한다). "" 면 닫힘.
static var open_k := ""
static var open_n1 := ""     # 머리에 적을 줄 이름
static var open_page := 0

const PAGES := ["경제·진행", "물건", "판·조준", "해금"]
const W := 300.0
const ROW := 15.0
const ARW := 13.0              # 화살표 칸 너비
const VALW := 116.0            # 값 칸 너비

# 고르개는 판보다 넓다 — 640 폭에서 480 까지 쓴다. 세 칸 × 열여덟 줄이면
# 한 쪽에 쉰넷이라 켜진 동전 62장이 두 쪽에 담긴다.
#
# 열아홉 줄로 잡았더니 마지막 줄이 바닥 안내 문구와 겹쳤다 — 줄 끝이 343,
# 문구 윗변이 339 였다. 한 줄을 덜어 그 4px 를 띄운다.
const PW := 476.0
const PCOL := 3
const PROW := 18


# ── 바깥과 닿는 셋 ────────────────────────────────────────

static func key(g: Node, code: int) -> bool:
	# \ 는 [ ] 옆이라 손이 이미 거기 있다 — 게이지 속도 조절과 같은 자리다.
	if code == KEY_BACKSLASH:
		on = not on
		open_k = ""              # 열어 둔 고르개를 남기면 다음에 열 때 그게 뜬다
		if on:
			msg = "\\ 로 닫는다"
			msg_t = 2.0
		return true
	if not on:
		return false
	# 고르개가 열려 있으면 ESC 는 그것만 닫는다. 개발자 모드까지 같이 닫으면
	# 목록을 잘못 열었을 때 되돌아올 자리가 없다.
	if code == KEY_ESCAPE and open_k != "":
		open_k = ""
		return true
	if code == KEY_TAB:
		page = (page + 1) % PAGES.size()
		return true
	return false


static func click(g: Node, m: Vector2) -> bool:
	if not on:
		return false
	# 고르개가 위에 떠 있으면 그것이 클릭을 통째로 가진다. 아래 판까지
	# 같이 판정하면 가려진 줄이 눌린다.
	if open_k != "":
		return _pick_click(g, m)
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
			var n: int = int(e.n)
			if n > 0:
				var cur: int = int(pick.get(e.k, 0))
				# 값 칸을 누르면 전체 목록을 편다. 화살표는 옆칸을 볼 때
				# 그대로 쓰고, 멀리 있는 것은 목록에서 바로 집는다.
				if _val_box(r).has_point(m):
					open_k = String(e.k)
					open_n1 = String(e.get("n1", ""))
					open_page = cur / _pick_per()
					return true
				if _arrow(r, false).has_point(m):
					pick[e.k] = (cur - 1 + n) % n
				elif _arrow(r, true).has_point(m):
					pick[e.k] = (cur + 1) % n
				# **고른 것이 곧 적용이다.** 화살표가 값만 바꾸고 적용을 따로
				# 눌러야 하면, 검사 도구에서 그 한 번을 빠뜨리는 것이 기본값이
				# 된다 — 눌러도 게임이 안 바뀌는 것으로 보인다.
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
			var col := Color(1.0, 0.80, 0.35)
			var la := _arrow(r, false)
			var ra := _arrow(r, true)
			g.draw_string(g.font, la.position + Vector2(0.0, 11.0), "◀",
					HORIZONTAL_ALIGNMENT_CENTER, la.size.x, 11, col)
			g.draw_string(g.font, ra.position + Vector2(0.0, 11.0), "▶",
					HORIZONTAL_ALIGNMENT_CENTER, ra.size.x, 11, col)
			var vb := _val_box(r)
			g.draw_string(g.font, vb.position + Vector2(0.0, 11.0), _cur_name(e),
					HORIZONTAL_ALIGNMENT_CENTER, vb.size.x, 11, col)

	if msg != "":
		g.draw_string(g.font, p.position + Vector2(6.0, p.size.y - 6.0), msg,
				HORIZONTAL_ALIGNMENT_LEFT, p.size.x - 12.0, 11, Color(0.55, 1.0, 0.65))

	# 고르개는 판보다 넓어서 통째로 덮는다 — 맨 나중에 그려야 위로 온다.
	if open_k != "":
		_pick_draw(g)


static func tick(d: float) -> void:
	if msg_t > 0.0:
		msg_t -= d
		if msg_t <= 0.0:
			msg = ""


# ── 자리 ──────────────────────────────────────────────────

static func _panel() -> Rect2:
	return Rect2(Vector2(4.0, 22.0), Vector2(W, 330.0))


# 목록 줄의 화살표 칸. **그려지는 자리와 눌리는 자리가 같아야 한다.**
# 예전에는 "◀ 값 ▶" 을 오른쪽 정렬로 그려 놓고 줄을 3등분해서 판정했다.
# 그러면 두 화살표가 다 오른쪽 3분의 1 안에 들어가서 ◀ 가 "다음" 이 되고,
# 적용은 아무것도 안 그려진 가운데 빈 칸을 눌러야 일어났다 — 화살표를
# 아무리 눌러도 게임이 안 바뀌는 것으로 보였다.
static func _arrow(r: Rect2, next: bool) -> Rect2:
	var right: float = r.position.x + r.size.x - 6.0
	var x: float = right - ARW if next else right - ARW - VALW - ARW
	return Rect2(Vector2(x, r.position.y), Vector2(ARW, r.size.y))


static func _val_box(r: Rect2) -> Rect2:
	var la := _arrow(r, false)
	return Rect2(Vector2(la.position.x + ARW, r.position.y),
			Vector2(VALW, r.size.y))


static func _tab(i: int) -> Rect2:
	var p := _panel()
	var w: float = (p.size.x - 12.0) / float(PAGES.size())
	return Rect2(p.position + Vector2(6.0 + float(i) * w, 20.0), Vector2(w - 2.0, 14.0))


static func _row(i: int) -> Rect2:
	var p := _panel()
	return Rect2(p.position + Vector2(6.0, 40.0 + float(i) * ROW),
			Vector2(p.size.x - 12.0, ROW - 2.0))


# ── 목록 고르개 ───────────────────────────────────────────

static func _pick_panel() -> Rect2:
	return Rect2(Vector2(4.0, 22.0), Vector2(PW, 330.0))


# 한 쪽에 담기는 칸 수. 쪽 나누기와 자리 계산이 같은 수를 봐야 한다 —
# 따로 적어 두면 한쪽만 고쳤을 때 마지막 줄이 조용히 안 눌린다.
static func _pick_per() -> int:
	return PCOL * PROW


static func _pick_cell(j: int) -> Rect2:
	var p := _pick_panel()
	var cw: float = (p.size.x - 12.0) / float(PCOL)
	var c: int = j / PROW
	var r: int = j % PROW
	return Rect2(p.position + Vector2(6.0 + float(c) * cw, 36.0 + float(r) * ROW),
			Vector2(cw - 2.0, ROW - 2.0))


# 0 이전 쪽 · 1 다음 쪽 · 2 닫기
static func _pick_btn(which: int) -> Rect2:
	var p := _pick_panel()
	var y: float = p.position.y + 4.0
	var right: float = p.position.x + p.size.x - 6.0
	match which:
		2: return Rect2(Vector2(right - 30.0, y), Vector2(30.0, 14.0))
		1: return Rect2(Vector2(right - 30.0 - 16.0, y), Vector2(14.0, 14.0))
		_: return Rect2(Vector2(right - 30.0 - 34.0, y), Vector2(14.0, 14.0))


# 고르개가 늘어놓을 이름들. aim·score 는 표가 아니라 상수 목록이라
# _list 를 안 지난다 — _cur_name 이 이미 같은 갈래를 쥐고 있다.
static func _names(k: String) -> PackedStringArray:
	var out := PackedStringArray()
	if k == "aim":
		for m in GameData.AIM_MODES:
			out.append(GameData.aim_name(String(m)))
		return out
	if k == "score":
		for m in GameData.SCORE_MODES:
			out.append(GameData.score_name(String(m)))
		return out
	for r in _list(k):
		out.append(String(r.get("n", r.get("name", r.get("id", "?")))))
	return out


static func _pick_pages(n: int) -> int:
	return maxi(1, (n + _pick_per() - 1) / _pick_per())


static func _pick_click(g: Node, m: Vector2) -> bool:
	var names := _names(open_k)
	var pages := _pick_pages(names.size())
	open_page = clampi(open_page, 0, pages - 1)
	if _pick_btn(2).has_point(m):
		open_k = ""
		return true
	if _pick_btn(0).has_point(m):
		open_page = (open_page - 1 + pages) % pages
		return true
	if _pick_btn(1).has_point(m):
		open_page = (open_page + 1) % pages
		return true
	for j in _pick_per():
		var idx: int = open_page * _pick_per() + j
		if idx >= names.size():
			break
		if _pick_cell(j).has_point(m):
			# 판 위의 줄과 같은 길로 적용한다 — _run 이 pick 를 읽으므로
			# 여기서 게임 상태를 직접 만지면 두 길이 갈라진다.
			pick[open_k] = idx
			_run(g, {"k": open_k})
			open_k = ""
			return true
	# 판 밖을 누르면 닫는다. 안쪽 빈자리는 삼킨다.
	if not _pick_panel().has_point(m):
		open_k = ""
	return true


static func _pick_draw(g: Node) -> void:
	var p := _pick_panel()
	var names := _names(open_k)
	var pages := _pick_pages(names.size())
	open_page = clampi(open_page, 0, pages - 1)
	var cur: int = int(pick.get(open_k, 0))

	# 판(0.94)과 달리 고르개는 **불투명**이다. 뒤가 비치면 예순두 줄을
	# 읽는 데 방해가 된다 — 다트판이 밝아서 2% 만 새도 눈에 걸린다.
	g.draw_rect(p, Color(0.05, 0.04, 0.09))
	g.draw_rect(Rect2(p.position, Vector2(p.size.x, 2.0)), Color(1.0, 0.80, 0.35))
	g.draw_string(g.font, p.position + Vector2(8.0, 15.0),
			"%s — %d개 · %d/%d쪽" % [_pick_title(), names.size(),
					open_page + 1, pages],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(1.0, 0.80, 0.35))
	for w in 3:
		var b := _pick_btn(w)
		g.draw_rect(b, Color(0.20, 0.17, 0.28))
		g.draw_string(g.font, b.position + Vector2(0.0, 11.0),
				["◀", "▶", "닫기"][w], HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 11,
				Color(0.90, 0.88, 0.95))

	for j in _pick_per():
		var idx: int = open_page * _pick_per() + j
		if idx >= names.size():
			break
		var c := _pick_cell(j)
		var sel := idx == cur
		g.draw_rect(c, Color(0.30, 0.26, 0.40) if sel else Color(0.13, 0.11, 0.18))
		g.draw_string(g.font, c.position + Vector2(4.0, 11.0),
				"%d %s" % [idx + 1, names[idx]],
				HORIZONTAL_ALIGNMENT_LEFT, c.size.x - 8.0, 11,
				Color(1.0, 0.90, 0.55) if sel else Color(0.86, 0.86, 0.92))

	g.draw_string(g.font, p.position + Vector2(8.0, p.size.y - 5.0),
			"누르면 바로 적용 · ESC 나 판 밖을 눌러 닫는다",
			HORIZONTAL_ALIGNMENT_LEFT, p.size.x - 16.0, 11, Color(0.55, 0.52, 0.60))


# 고르개 머리에 적을 이름. 열 때 줄 이름을 그대로 받아 둔다 — 여는 순간에는
# 그 줄을 손에 쥐고 있고, 그릴 때 다시 찾으면 쪽이 바뀌었을 때 못 찾는다.
static func _pick_title() -> String:
	return open_n1 if open_n1 != "" else open_k


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
				{"n1": "판 +1", "t": "act", "a": "leg", "v": 1},
				{"n1": "판 −1", "t": "act", "a": "leg", "v": -1},
				{"n1": "상점 열기", "t": "act", "a": "shop"},
				{"n1": "판 선택 열기", "t": "act", "a": "leg"},
				{"n1": "다트 다시 채우기", "t": "act", "a": "refill"},
			]
		1:
			return [
				{"n1": "동전 주기", "t": "list", "k": "item",
						"n": GameData.items().size()},
				{"n1": "동전 무작위", "t": "act", "a": "item_rand"},
				{"n1": "동전 슬롯 비우기", "t": "act", "a": "item_clear"},
				{"n1": "사탕 주기", "t": "list", "k": "cons",
						"n": _list("cons").size()},
				{"n1": "사진 주기", "t": "list", "k": "photo",
						"n": _list("photo").size()},
				{"n1": "손에 든 것 쓰기", "t": "act", "a": "cons_use"},
				{"n1": "보드 확장 달기", "t": "list", "k": "mod",
						"n": GameData.mods().size()},
				{"n1": "다트 바꾸기", "t": "list", "k": "dart",
						"n": GameData.darts().size()},
				{"n1": "뱃지 주기", "t": "list", "k": "tag",
						"n": GameData.tags().size()},
				{"n1": "팩 열기", "t": "list", "k": "boost",
						"n": GameData.boosters().size()},
				{"n1": "테이블 다시 굴리기", "t": "act", "a": "restock"},
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
				{"n1": "챌린지", "t": "list", "k": "chal",
						"n": GameData.challenges().size()},
				{"n1": "리그", "t": "list", "k": "league",
						"n": GameData.leagues().size()},
				{"n1": "다트통", "t": "list", "k": "pack",
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
		# 사탕과 사진이 한 표에 산다(둘 다 "골라서 쓰는" 물건이라 길이 같다).
		# 개발자 판에서는 갈라 보여야 한다 — 섞어 놓으면 사진 여덟이 사탕
		# 틈에 묻혀 "왜 없지" 가 된다.
		"cons": return GameData.consumables().filter(
				func(c): return String(c.get("cat", "")) == "area")
		"photo": return GameData.consumables().filter(
				func(c): return String(c.get("cat", "")) != "area")
		"mod": return GameData.mods()
		"dart": return GameData.darts()
		"vou": return GameData.fixtures()
		"tag": return GameData.tags()
		"mf": return GameData.modifiers()
		"league": return GameData.leagues()
		"pack": return GameData.packs()
		"chal": return GameData.challenges()
		"boost": return GameData.boosters()
	return []


static func _cur_name(e: Dictionary) -> String:
	var k := String(e.k)
	var i: int = int(pick.get(k, 0))
	# 표가 아니라 상수 목록이라 _list 를 안 지난다 — 그래도 화면에서는
	# 다른 줄과 같은 꼴("3/8 빗각")로 보여야 몇 가지 중 몇 번째인지 안다.
	if k == "aim":
		var am: Array = GameData.AIM_MODES
		var j: int = i % maxi(am.size(), 1)
		return "%d/%d %s" % [j + 1, am.size(), GameData.aim_name(String(am[j]))]
	if k == "score":
		var sm: Array = GameData.SCORE_MODES
		var j2: int = i % maxi(sm.size(), 1)
		return "%d/%d %s" % [j2 + 1, sm.size(),
				GameData.score_name(String(sm[j2]))]
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


# 조준 방식을 **동전으로도** 쥐여 준다. 값만 박아 두면 다음 _start_leg
# 가 든 동전을 다시 읽어 std 로 되돌린다 — 판을 넘기는 순간 조용히
# 풀리는 것이다. 게임에서 방식이 오는 길이 동전 하나뿐이므로,
# 검사도 그 길로 가야 검사한 것이 실제로 도는 것과 같아진다.
static func _aim_sticker(g: Node, am: String) -> void:
	for j in range(g.owned.size() - 1, -1, -1):
		if String(g.owned[j].get("aim", "")) != "":
			g.owned.remove_at(j)      # 겹치면 앞엣것이 이긴다. 먼저 뗀다
	if am != "std":
		for it in GameData.items():
			if String(it.get("aim", "")) == am:
				while g.owned.size() >= GameData.max_items():
					g.owned.pop_back()
				g.owned.insert(0, it.duplicate())
				break
	g.sealed = -1                 # 뗀 자리 때문에 봉인 번호가 밀렸다
	g._panel_reset()


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
			g._finish_leg()
			_say("클리어")
			return
		"lose":
			g.total = 0
			g.darts_left = 0
			g.remaining.clear()
			g._finish_leg()
			_say("실패")
			return
		"leg":
			g.leg_no = clampi(g.leg_no + int(e.v), 1, GameData.legs_n())
			g._open_leg()
			_say("판 %d" % g.leg_no)
			return
		"shop":
			g._open_shop()
			_say("상점")
			return
		"leg":
			g._open_leg()
			_say("판 선택")
			return
		"refill":
			g._start_leg()
			_say("다트 %d발" % g.remaining.size())
			return
		"item_rand":
			var pool := GameData.items()
			if not pool.is_empty():
				_give_item(g, pool[randi() % pool.size()])
			return
		"cons_use":
			# 사진은 쓰는 순간 화면이 하나 더 열린다. 주기만 해서는 그 화면을
			# 못 보므로 여기서 바로 눌러 준다 — 슬롯을 클릭하는 것과 같은 길이다.
			if g.cons.is_empty():
				_say("손이 비었다")
				return
			var nm := String(g.cons[0].get("n", ""))
			g._cons_use(0)
			_say("%s 사용" % nm)
			return
		"item_clear":
			g.owned.clear()
			g.sealed = -1
			g._panel_reset()
			_say("동전 슬롯 비움")
			return
		"restock":
			g._roll_stock()
			_say("테이블 다시")
			return
		"mf_off":
			g.active_mods = []
			g._start_leg()
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
				for st in GameData.leagues():
					if Save.unlock(GameData.league_key(String(st.get("id", "")),
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
			var am := String(GameData.AIM_MODES[i % GameData.AIM_MODES.size()])
			g.aim_mode = am
			# 방식마다 쓰는 값이 달라 갈아탄 자리에 남은 값이 섞인다 —
			# 반지름·축을 여기서 새로 세운다.
			g._aim_begin()
			_aim_sticker(g, am)
			_say("조준 %s" % GameData.aim_name(am))
		"score":
			g.score_mode = String(GameData.SCORE_MODES[i % GameData.SCORE_MODES.size()])
			_say("계산 '%s'" % g.score_mode)
		"item":
			if not rows.is_empty():
				_give_item(g, rows[i % rows.size()])
		"photo", "cons":
			if not rows.is_empty() and g.cons.size() < GameData.cons_slots():
				g.cons.append(rows[i % rows.size()])
				_say("사탕 %d/%d" % [g.cons.size(), GameData.cons_slots()])
		"boost":
			# 팩은 상점 테이블을 굴려야만 만나고, 어느 팩인지도 못 골랐다.
			# 게임과 같은 길(_boost_deal)로 편다 — 여기서 상태를 직접
			# 만들면 검사한 것이 실제로 도는 것과 갈라진다.
			if not rows.is_empty():
				g._boost_deal(rows[i % rows.size()])
				_say("팩 %s" % String(rows[i % rows.size()].get("n", "?")))
		"mod":
			if not rows.is_empty():
				var mid := String(rows[i % rows.size()].id)
				if not g.mods_own.has(mid):
					g.mods_own.append(mid)
				g._board_bake()
				_say("보드 확장 %s" % mid)
		"dart":
			if not rows.is_empty():
				var dd: Dictionary = rows[i % rows.size()]
				g.magazine.clear()
				for z in 6:
					g.magazine.append(dd)
				g._start_leg()
				_say("다트 %s" % dd.get("n", dd.get("name", "")))
		"vou":
			if not rows.is_empty():
				# 사진은 1회성이라 사탕 칸으로 들어간다
				if g.cons.size() < GameData.cons_slots():
					g.cons.append(rows[i % rows.size()].duplicate())
					_say("사진 %s" % rows[i % rows.size()].get("n", ""))
				else:
					_say("사탕 칸이 꽉 찼다")
		"tag":
			if not rows.is_empty():
				g._take_tag(rows[i % rows.size()])
		"mf":
			if not rows.is_empty():
				g.active_mods = [rows[i % rows.size()]]
				g._start_leg()
				_say("제약 %s" % g.active_mods[0].get("n", ""))
		"chal":
			if not rows.is_empty():
				GameData.challenge = String(rows[i % rows.size()].get("id", ""))
				# 챌린지는 시작 골드·슬롯 상한처럼 런을 여는 자리를 바꾼다.
				# 새 런을 열어야 그 값들이 실제로 선다 — 판 도중에 갈면
				# "골랐는데 아무 일도 안 난다" 로 보인다.
				g._new_run()
				_say("챌린지 %s — 새 런" % rows[i % rows.size()].get("n", ""))
		"league":
			if not rows.is_empty():
				GameData.league = String(rows[i % rows.size()].get("id", ""))
				_say("리그 %s" % GameData.league)
		"pack":
			if not rows.is_empty():
				GameData.pack = String(rows[i % rows.size()].get("id", ""))
				_say("다트통 %s — 새 런부터" % GameData.pack)


static func _give_item(g: Node, it: Dictionary) -> void:
	if g.owned.size() >= GameData.max_items():
		_say("동전 슬롯이 꽉 찼다")
		return
	var c: Dictionary = it.duplicate()
	c.gs = 0
	c.bought = g.leg_no
	g.owned.append(c)
	g._panel_reset()
	_say("%s" % c.get("n", ""))
