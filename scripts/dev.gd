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
#    ③ game.gd 가 Dev 를 부르는 여섯 줄 — 전부 `# DEV` 주석이 달려 있다
#         _process()         Dev.tick(self, d)
#         _unhandled_input() Dev.key(self, k.keycode)
#         _click()           Dev.click(self, m)
#         _wheel()           Dev.wheel(self, m, dir)
#         _draw()            Dev.draw(self)
#         _draw()            if OS.is_debug_build() and Dev.on:  ← 조절 값 줄.
#                            이 줄만이 아니라 **그 안 draw_string 을 같이** 지운다
#  `grep -n "# DEV" scripts/game.gd` 로 그 일곱이 한 번에 나온다(머리말 한 줄 포함).
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

# 「점수 카드 걸음」 미리보기. 0 = 안 돎 · 1 = 걸음 · 2 = 합계 카드.
#
# 미리보기는 진짜 정산 큐를 빌려 타는데, 큐가 비는 순간 _next_step 의 빈 큐
# 갈래가 **한 발이 끝나는 진짜 길**을 탄다 — _wear_spent 가 다 쓴 동전을 지우고
# _finish_leg 가 Save 를 디스크에 앉힌다. 연출을 한 번 다시 보려고 누른 줄이
# 판과 개인 기록을 건드리면 안 된다(2026-09-18).
#
# Dev.tick 이 game.gd:3188 에서 **상태 기계(3197)보다 먼저** 돌므로, 큐가 빈 채
# qt 가 0 을 찍는 그 프레임을 여기서 가로채 제자리로 되돌린다.
static var card_ph := 0
static var card_back := {}       # 되돌릴 자리

# 사다리를 차례로 낼 줄. [이름, f, 다음까지 초] 줄들. f 가 0 이면 표의 음이다.
static var _q := []
static var _qt := 0.0
static var _sfx_rows := []       # 소리 이름 목록. 표에서 한 번만 읽는다
static var _aimw_key := ""       # 조준 저울 줄을 마지막에 센 (고른 라운드|든 동전)
static var _aimw_txt := ""       # 그때 나온 글. 열쇠가 같으면 다시 안 센다

const PAGES := ["경제·진행", "물건", "판·조준", "해금", "소리"]
# 글자는 페이퍼로지 Bold 12 하나다. 줄 칸(13px) · 탭 · 단추(14px)의 **한가운데**에
# 잉크(한글 10px)를 세운다(_base — 기준선 11 · 11.5). 갈무리 때 박은 기준선 12 는
# 페이퍼로지 잉크가 기준선 밑으로 내려가 글자 밑이 칸 바닥에 붙었다(「69 녹는 시계」 ·
# 「저장 통째로 지우기」, 2026-09-17). 값 칸 128 · 고르개 520 폭에 「1/69 발라트로의 조커」
# 가 그대로 든다.
const W := 300.0
const ROW := 15.0
const ARW := 13.0              # 화살표 칸 너비 — ◀ · ▶ 잉크 12px 가 든다
const VALW := 128.0            # 값 칸 너비

# 고르개는 판보다 넓다 — 640 폭에서 524 까지 쓴다. 세 칸 × 열여덟 줄이면
# 한 쪽에 쉰넷이라 켜진 동전 62장이 두 쪽에 담긴다.
#
# 열아홉 줄로 잡았더니 마지막 줄이 바닥 안내 문구와 겹쳤다 — 줄 끝이 343,
# 문구 윗변이 339 였다. 한 줄을 덜어 그 4px 를 띄운다.
const PW := 520.0
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


# 휠. click 과 **같은 인자 차례 · 같은 가로채기 규약**이다 — 게임에 휠 쪽
# 넘기기를 내면 개발자 모드에 정확히 같은 모양의 화살표가 남는다.
# 화면 글은 한 자도 안 늘린다(판 오른쪽 위 줄이 길어지면 고르개 머리와
# 폭이 어긋난다). 쿨다운은 게임의 wheel_ms 하나를 같이 쓴다 — 제 시계를
# 따로 들면 고르개에서만 감도가 달라진다. 2026-09-19
static func wheel(g: Node, m: Vector2, dir: int) -> bool:
	if not on:
		return false
	# 고르개가 떠 있으면 그것이 휠을 통째로 가진다 — click 과 같은 규약이다.
	# 한 쪽이 PCOL x PROW = 54 라 켜진 동전이 두 쪽이고, 여기가 휠이 제일
	# 값어치 있는 자리다.
	if open_k != "":
		open_page = posmod(open_page + dir, _pick_pages(_names(open_k).size()))
		return true
	for i in PAGES.size():
		if _tab(i).has_point(m):
			page = posmod(page + dir, PAGES.size())   # TAB 키와 같은 값
			return true
	var rows := _rows(g)
	for i in rows.size():
		if not _row(i).has_point(m):
			continue
		var e: Dictionary = rows[i]
		if String(e.t) == "list" and int(e.n) > 0:
			pick[e.k] = posmod(int(pick.get(e.k, 0)) + dir, int(e.n))
			# **고른 것이 곧 적용이다** — ◀▶ 와 같은 길이다.
			_run(g, e)
		# 값이 없는 줄 위에서는 아무 일도 안 하되 삼킨다. 안 삼키면 판 밑
		# 화면의 쪽이 대신 넘어간다.
		return true
	return _panel().has_point(m)          # 판 안의 헛굴림도 삼킨다


#  글자 한 줄을 칸(top · h)의 세로 한가운데에 세우는 기준선. 게임의 _menu_base_y 와 같은
#  식이다 — 줄 상자(ascent + descent)의 한가운데가 페이퍼로지 잉크의 한가운데다. 이 파일은
#  통째로 지워질 자리라 게임 쪽 함수를 안 빌리고 한 줄을 따로 든다.
static func _base(g: Node, top: float, h: float, sz := 12) -> float:
	var f: Font = g.font
	var ad: float = float(sz) * 0.78
	if f != null:
		ad = f.get_ascent(sz) - f.get_descent(sz)
	return top + roundf(h + ad) * 0.5


static func draw(g: Node) -> void:
	if not on:
		return
	var p := _panel()
	g.draw_rect(p, Color(0.04, 0.03, 0.07, 0.94))
	g.draw_rect(Rect2(p.position, Vector2(p.size.x, 2.0)), Color(1.0, 0.35, 0.35))
	g.draw_string(g.font, p.position + Vector2(8.0, 15.0), "개발자",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.35, 0.35))
	g.draw_string(g.font, p.position + Vector2(0.0, 15.0), "\\ 닫기 · TAB 다음 쪽",
			HORIZONTAL_ALIGNMENT_RIGHT, p.size.x - 8.0, 12, Color(0.55, 0.52, 0.60))

	for i in PAGES.size():
		var t := _tab(i)
		g.draw_rect(t, Color(0.16, 0.14, 0.22) if i != page else Color(0.30, 0.26, 0.40))
		g.draw_string(g.font, Vector2(t.position.x, _base(g, t.position.y, t.size.y)), PAGES[i],
				HORIZONTAL_ALIGNMENT_CENTER, t.size.x, 12,
				Color(1, 1, 1) if i == page else Color(0.6, 0.58, 0.66))

	var rows := _rows(g)
	for i in rows.size():
		var e: Dictionary = rows[i]
		var r := _row(i)
		g.draw_rect(r, Color(0.13, 0.11, 0.18))
		var by: float = _base(g, r.position.y, r.size.y)
		g.draw_string(g.font, Vector2(r.position.x + 6.0, by), String(e.n1),
				HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 12.0, 12, Color(0.86, 0.86, 0.92))
		if String(e.t) == "list":
			var col := Color(1.0, 0.80, 0.35)
			var la := _arrow(r, false)
			var ra := _arrow(r, true)
			g.draw_string(g.font, Vector2(la.position.x, by), "◀",
					HORIZONTAL_ALIGNMENT_CENTER, la.size.x, 12, col)
			g.draw_string(g.font, Vector2(ra.position.x, by), "▶",
					HORIZONTAL_ALIGNMENT_CENTER, ra.size.x, 12, col)
			var vb := _val_box(r)
			g.draw_string(g.font, Vector2(vb.position.x, by), _cur_name(g, e),
					HORIZONTAL_ALIGNMENT_CENTER, vb.size.x, 12, col)

	if msg != "":
		g.draw_string(g.font, p.position + Vector2(6.0, p.size.y - 6.0), msg,
				HORIZONTAL_ALIGNMENT_LEFT, p.size.x - 12.0, 12, Color(0.55, 1.0, 0.65))

	# 고르개는 판보다 넓어서 통째로 덮는다 — 맨 나중에 그려야 위로 온다.
	if open_k != "":
		_pick_draw(g)


static func tick(g: Node, d: float) -> void:
	if msg_t > 0.0:
		msg_t -= d
		if msg_t <= 0.0:
			msg = ""
	if card_ph > 0:
		_card_tick(g, d)
	# 사다리는 한 소리가 아니라 **오르는 관계**가 내용이라, 한 번에 하나씩
	# 내면 들을 수가 없다. 줄을 세워 두고 여기서 한 칸씩 흘린다.
	if not _q.is_empty():
		_qt -= d
		if _qt <= 0.0:
			var s: Array = _q.pop_front()
			g._sfx(String(s[0]), float(s[1]))
			_qt = float(s[2])


# ── 「점수 카드 걸음」 미리보기의 끝맺음 ────────────────────
#  **_next_step 의 빈 큐 갈래를 안 밟는다.** 거기는 연출이 아니라 한 발이
#  끝나는 진짜 길이다 — burst_n 을 0 으로 내리고, _wear_spent 가 다 쓴 동전을
#  owned 에서 지우고, _finish_leg 가 Save.peak 을 디스크에 앉히거나 _to_pick 이
#  화면을 넘긴다. 연출을 한 번 다시 보는 값으로는 너무 비싸다(2026-09-18).
#
#  tick 이 game.gd:3188 에서 상태 기계(3197)보다 **먼저** 도는 것을 쓴다. 큐가
#  빈 채 qt 가 0 을 찍는 프레임을 여기서 가로채므로 game.gd 에 갈래를 안 판다.
static func _card_tick(g: Node, d: float) -> void:
	# 카드가 다 미끄러져 나간 **뒤에** 수를 되돌린다. 나가는 동안은 마지막
	# 걸음이 적은 값을 그대로 이고 간다 — 진짜 정산도 그렇게 나간다(빈 큐
	# 갈래는 card_target 만 내리고 수는 다음 _land 까지 그대로 둔다). 나가기
	# 전에 되돌리면 「0 × 0」이 0.3초 동안 미끄러져 나간다.
	if card_ph == 3:
		# 새 발이 내려앉았다 — _land 가 이미 다 되돌렸으므로 덮으면 그 발이 상한다.
		if g.card_target > 0.0:
			card_ph = 0
			card_back = {}
			return
		if g.card_p > 0.02:
			return
		_card_nums(g)
		return
	# 다른 줄이 화면을 옮겼다 — 되돌릴 자리가 이미 없으니 손을 뗀다.
	if g.state != g.S.RESOLVE:
		card_ph = 0
		card_back = {}
		return
	# 마지막 걸음이 아직 화면에 서 있다.
	if not g.queue.is_empty() or g.qt - d > 0.0:
		return
	if card_ph == 1 and bool(card_back.get("big", false)):
		_card_big(g)
		return
	_card_done(g)


#  「한 방」의 합계 카드를 **손으로** 놓는다. 큐에 {"k": "total"} 을 넣으면
#  _next_step 이 _score_combine 을 돌려 판 점수에 더하고 Save.peak("best_gain")
#  을 쓴다 — 이 단은 4900 × 90 = 441,000 이라 best_gain 의 전설 동전 해금 문턱
#  (100,000)을 한 번에 넘긴다. 그림만 따 오고 셈과 저장은 안 건드린다.
#  _score_combine 은 순수 함수라 읽기만 하는 것이 안전하다(3716~3741).
static func _card_big(g: Node) -> void:
	card_ph = 2
	g.pitch_step += 1
	g.card_mode = 1
	g.card_item = ""
	g.calc_lit = false
	g.roll_t = -1.0
	g.last_gain = g._score_combine(g.cur_chip, g.cur_mult)
	g.total_flash = 1.0
	g.gain_roll = 1.0
	g.card_burst = 1.0
	g.shake = 9.0
	g.board_punch = 1.0
	g.qt = g.beat * 2.6 * g._pace()
	g._card_kick(float(g.CARDFX.kick_total), float(g.CARDFX.press_total))
	g._card_kick(float(g.CARDFX.kick_big) - float(g.CARDFX.kick_total),
			float(g.CARDFX.press_big))
	g._sfx("settle_total")
	# 멈춤도 걸음의 절반으로 묶는다 — 게임 쪽(총점 걸음)과 같은 뺄셈이라야
	# 미리보기의 걸음 길이가 「큼」 단과 같다.
	if not g.motion_off:
		g.hitstop = minf(float(g.CARDFX.stop), g.qt * 0.5)
		g.qt -= g.hitstop
	g.card_jrate = 1.0 / maxf(g.qt * float(g.CARDFX.jspan), 0.02)


#  누르기 전 자리로 되돌린다. card_target 0 은 빈 큐 갈래가 하던 그 한 줄이다 —
#  카드가 미끄러져 나가는 것까지가 연출이라 그것만 가져온다. 카드에 적힌 수는
#  나간 뒤에 되돌린다(_card_tick 의 3단).
static func _card_done(g: Node) -> void:
	g.card_target = 0.0
	g.calc_lit = false
	g.roll_t = -1.0
	g.queue.clear()
	g.qt = 0.0
	g.state = int(card_back.get("state", g.S.PICK))
	g.pitch_step = int(card_back.get("pitch", 0))
	g.settle_n = int(card_back.get("settle_n", 0))
	g.burst_n = int(card_back.get("burst_n", 0))
	card_ph = 3
	g.queue_redraw()


#  카드에 적힌 수만 되돌린다. 3단이 끝날 때와, 나가는 중에 줄을 또 누를 때
#  둘 다 여기를 지난다 — 두 자리에 같은 값을 두 번 적으면 한쪽만 고치게 된다.
static func _card_nums(g: Node) -> void:
	g.card_mode = 0
	g.card_item = ""
	g.cur_chip = int(card_back.get("chip", 0))
	g.cur_mult = int(card_back.get("mult", 0))
	g.last_gain = int(card_back.get("gain", 0))
	card_ph = 0
	card_back = {}


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
	#  빨리 보기 사다리 — _cur_name 과 **짝으로** 낸다. 한쪽만 내면 값 칸을
	#  눌렀을 때 고르개가 텅 빈 채로 뜬다(2026-09-19).
	if k == "fast":
		for nm in FAST_NAMES:
			out.append(String(nm))
		return out
	#  조준 저울도 표가 아니라 라운드 번호라 _list 를 안 지난다. 안 넣으면
	#  값 칸을 눌렀을 때 고르개가 텅 빈 채로 뜬다. 사다리(aim_w)를 적는다 —
	#  이미 든 쪽의 바닥은 _cur_name 이 "(든 뒤)" 를 달아 말해 준다.
	#  n 은 **판 번호**다(라운드 번호가 아니다) — aim_floor 가 shop_slots 와
	#  같은 어법이라 안에서 round_of 를 돈다. 2026-09-18
	if k == "aimw":
		for n in GameData.rounds_n():
			out.append("R%d %.2f" % [n + 1,
					GameData.aim_floor(n * GameData.legs_per_round() + 1)])
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
	#  머리는 단추 이름과 같은 기준선(단추 14px 의 한가운데 — _base)에 선다.
	var hb: float = _base(g, _pick_btn(0).position.y, _pick_btn(0).size.y)
	g.draw_string(g.font, Vector2(p.position.x + 8.0, hb),
			"%s — %d개 · %d/%d쪽" % [_pick_title(), names.size(),
					open_page + 1, pages],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.80, 0.35))
	for w in 3:
		var b := _pick_btn(w)
		g.draw_rect(b, Color(0.20, 0.17, 0.28))
		g.draw_string(g.font, Vector2(b.position.x, hb),
				["◀", "▶", "닫기"][w], HORIZONTAL_ALIGNMENT_CENTER, b.size.x, 12,
				Color(0.90, 0.88, 0.95))

	for j in _pick_per():
		var idx: int = open_page * _pick_per() + j
		if idx >= names.size():
			break
		var c := _pick_cell(j)
		var sel := idx == cur
		#  동전 줄은 칸 바탕에 등급색을 어둡게 깐다(2026-09-18). 한 쪽에 네
		#  등급이 **띠로 갈려** 보이므로 「몇 번째 줄부터 레어인가」를 세지
		#  않아도 된다. 고른 칸은 지금처럼 밝게 — 고른 것이 먼저다.
		var cb := Color(0.30, 0.26, 0.40) if sel else Color(0.13, 0.11, 0.18)
		if not sel and open_k.begins_with("item"):
			var rows2 := _list(open_k)
			if idx < rows2.size():
				var rr := String(rows2[idx].get("rarity", ""))
				if rr != "":
					cb = cb.lerp(GameData.rarity_color(rr).darkened(0.62), 0.75)
		g.draw_rect(c, cb)
		g.draw_string(g.font, Vector2(c.position.x + 4.0, _base(g, c.position.y, c.size.y)),
				"%d %s" % [idx + 1, names[idx]],
				HORIZONTAL_ALIGNMENT_LEFT, c.size.x - 8.0, 12,
				Color(1.0, 0.90, 0.55) if sel else Color(0.86, 0.86, 0.92))

	g.draw_string(g.font, p.position + Vector2(8.0, p.size.y - 5.0),
			"누르면 바로 적용 · ESC 나 판 밖을 눌러 닫는다",
			HORIZONTAL_ALIGNMENT_LEFT, p.size.x - 16.0, 12, Color(0.55, 0.52, 0.60))


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
				{"n1": "최악의 상태", "t": "act", "a": "worst"},
				{"n1": "정산 다시 재생", "t": "act", "a": "replay"},
				#  동전이 부서지는 자리를 다시 보는 둘(2026-09-19).
				#  「판 끝 마모 한 번」은 **실제 경로 그대로** 태우는 줄이다 —
				#  「부서졌다」가 한 글자도 안 보이던 원인(_settle_clear 의
				#  pops.clear())이 바로 그 경로에 있었다.
				{"n1": "판 끝 마모 한 번", "t": "act", "a": "wear1"},
				{"n1": "선반 여섯 채우기", "t": "act", "a": "wreck6"},
				{"n1": "점수 카드 걸음", "t": "list", "k": "cardfx", "n": 3},
				#  정산 빨리 보기(2026-09-19). 사다리 = 1배 / 2배 / 2.5배 / 3배.
				#  게임 기본은 2.5(셋째)다. **바닥(걸음 4프레임)은 사다리
				#  위에서도 그대로 걸린다** — _fast_rate 가 minf(FAST.mul,
				#  _fast_lim()) 로 씌우므로 3배를 골라도 눌린 박자에서는
				#  한도가 1.53 이다. 고정은 안 눌러도 걸리는 toggle 자리다.
				{"n1": "정산 빨리 보기", "t": "list", "k": "fast", "n": 4},
				{"n1": "빨리 보기 고정", "t": "act", "a": "fast_lock"},
				{"n1": "런 끝 잠금 풀기", "t": "act", "a": "over_unlock"},
			]
		1:
			return [
				{"n1": "동전 주기", "t": "list", "k": "item",
						"n": GameData.items().size()},
				#  등급별로 훑는 넉 줄(2026-09-18). 고르개와 실행은 한 줄도 안
				#  고쳐도 돈다 — k 가 무엇이든 _list(k) 의 행을 주기 때문이다.
				{"n1": "일반 주기", "t": "list", "k": "item_common",
						"n": _list("item_common").size()},
				{"n1": "희귀 주기", "t": "list", "k": "item_uncommon",
						"n": _list("item_uncommon").size()},
				{"n1": "레어 주기", "t": "list", "k": "item_rare",
						"n": _list("item_rare").size()},
				{"n1": "레전더리 주기", "t": "list", "k": "item_legendary",
						"n": _list("item_legendary").size()},
				{"n1": "등급 한 벌 랙에", "t": "act", "a": "rank_rack"},
				{"n1": "재질x등급 랙에", "t": "act", "a": "rank_mat"},
				{"n1": "등급 한 벌 테이블에", "t": "act", "a": "rank_table"},
				#  모양 열아홉을 훑는 넉 줄(2026-09-18). 등급 넉 줄 바로 밑에
				#  둔다 — 「등급이 먼저 읽히는가」와 「개체가 갈리는가」를
				#  ↑/↓ 한 칸으로 번갈아 보게 하려는 자리다.
				{"n1": "레전더리 다섯 랙에", "t": "act", "a": "form_leg"},
				{"n1": "레어 변형 랙에", "t": "act", "a": "form_var"},
				{"n1": "레전더리 다섯 테이블에", "t": "act", "a": "form_leg_table"},
				{"n1": "레어 변형 테이블에", "t": "act", "a": "form_var_table"},
				{"n1": "등급 테 끄기/켜기", "t": "act", "a": "rank_off"},
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
				#  **보는 줄이다. 누르는 줄이 아니다.** 다른 list 줄은 click() 의
				#  「고른 것이 곧 적용」을 따르는데 이 줄만 다르다 — "a" 키가 없고
				#  _run 의 match k 에도 "aimw" 가 없어 ◀▶ 를 눌러도 게임 상태가
				#  안 바뀐다. 라운드별 조준 저울을 눈으로 훑기만 한다.
				#  바로 아래가 「테이블 다시 굴리기」라 라운드를 맞추고 →
				#  다시 굴리고 → 테이블을 눈으로 본다가 손가락 두 번에 끝난다.
				#  2026-09-18
				{"n1": "조준 저울", "t": "list", "k": "aimw",
						"n": GameData.rounds_n()},
				{"n1": "테이블 다시 굴리기", "t": "act", "a": "restock"},
				{"n1": "쓸기 다시 보기", "t": "act", "a": "sweep"},
				{"n1": "매물 아홉으로 쓸기", "t": "act", "a": "sweep9"},
				{"n1": "부딪힘 한 번", "t": "act", "a": "smash1"},
				#  여섯 재질을 **한 줄에 나란히 댄다** — ◀▶ 로 짚으면
				#  유리(0.400s·5조각·방사)가 밀랍(0.560s·3조각·아래로만)보다
				#  짧고 많고 빠른가가 손가락 두 번에 드러난다.
				#  바로 밑 줄과 번갈아 눌러 **비대칭**(0.80초 조용함 대
				#  0.40초 파열)을 ↑↓ 한 칸으로 재 본다.
				{"n1": "부서짐 재질", "t": "list", "k": "breakmat", "n": 6},
				{"n1": "굴림 남았다 한 번", "t": "act", "a": "safe1"},
				{"n1": "테이블에 사진 깔기", "t": "act", "a": "restock_fix"},
				{"n1": "모션 끄기/켜기", "t": "act", "a": "motion"},
				#  ── 손가락 길을 데스크톱에서 밟아 본다(2026-09-19) ──
				#  「손가락인 척」이 dev-mode-parity 의 요점이다. 끄면 얹힘
				#  길이 통째로 죽고 **누름-읽기만 남는다** — 톡 한 번에 얕은
				#  층, 0.45초에 깊은 층, 고리가 차오르는 것까지 모바일 전체를
				#  손으로 밟아 볼 수 있다. 읽기 관문이 오직 여기서만 검증된다.
				{"n1": "손가락인 척", "t": "act", "a": "touch"},
				{"n1": "판매 단추 세우기", "t": "act", "a": "sell_arm"},
				{"n1": "툴팁 얕게/깊게", "t": "act", "a": "tip_layer"},
				{"n1": "로비 겨눔 세우기", "t": "act", "a": "lobby_arm"},
			]
		2:
			return [
				{"n1": "제약 걸기", "t": "list", "k": "mf",
						"n": GameData.modifiers().size()},
				{"n1": "제약 풀기", "t": "act", "a": "mf_off"},
				#  위 둘은 **판 위에** 지금 꽂아 「판이 어떻게 달라지나」를
				#  재는 길이고, 아래 셋은 **카드가 무엇을 말하나**를 재는
				#  길이다. 둘이 갈려 있어야 「미리 정한 것」과 「지금 걸린
				#  것」이 화면에서 갈린다(2026-09-18).
				{"n1": "보스 제약 정하기", "t": "list", "k": "bmf",
						"n": GameData.modifiers().size()},
				{"n1": "보스 제약 다시 굴리기", "t": "act", "a": "boss_roll"},
				{"n1": "보스 제약 무효 켜기/끄기", "t": "act", "a": "boss_void"},
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
				{"n1": "제목 판 금 가기 직전", "t": "act", "a": "egg_crack"},
				{"n1": "제목 판 깨기 직전", "t": "act", "a": "egg"},
				{"n1": "인트로 다시 보기", "t": "act", "a": "intro"},
			]
		3:
			return [
				{"n1": "해금 전부 열기", "t": "act", "a": "unlock_all"},
				{"n1": "해금 전부 잠그기", "t": "act", "a": "unlock_none"},
				{"n1": "발견 전부 열기", "t": "act", "a": "found_all"},
				{"n1": "발견 전부 잠그기", "t": "act", "a": "found_none"},
				{"n1": "통계 지우기", "t": "act", "a": "stat_clear"},
				{"n1": "저장 통째로 지우기", "t": "act", "a": "wipe"},
			]
		_:
			# 소리는 프로브가 못 본다 — 수치가 맞아도 손에 안 맞는 것이 여기서만
			# 드러난다. 표 순서 그대로 놓으므로 가족끼리 붙어서 견줘 들린다.
			return [
				{"n1": "소리 하나", "t": "list", "k": "sfx",
						"n": _list("sfx").size()},
				{"n1": "정산 사다리 12칸", "t": "act", "a": "sfx_lad"},
				{"n1": "착탄 사다리 여섯", "t": "act", "a": "sfx_hit"},
				{"n1": "손 짝 넷", "t": "act", "a": "sfx_pair"},
				{"n1": "표 전부 차례로", "t": "act", "a": "sfx_all"},
				{"n1": "그치기", "t": "act", "a": "sfx_stop"},
			]


#  등급 하나만 걸러 낸다(2026-09-18). 지금 고르개는 「번호 이름」 한 줄뿐이라
#  등급이 **어디에도 안 떴다** — 백 줄을 훑으며 「이건 무슨 등급이지」를
#  물을 자리가 없었다. 네 줄로 갈라 두면 ←/→ 로 등급 경계를 연달아 넘으며
#  박음 0→3→6→온띠와 원반→물린 원→플라크가 **한 자리에서** 갈리는 것이 보인다.
static func _item_by(id: String) -> Dictionary:
	for it in GameData.items():
		if String(it.get("id", "")) == id:
			return it
	return {}


#  id 목록을 누운 테이블에 앞에서부터 꽂는다(2026-09-18). rank_table 과 **같은
#  길**이라 툴팁도 창구도 물리도 그대로 산다 — 게임이 까는 것과 같은 모양이다.
#  꺼진 동전(enabled=0)은 GameData.items() 가 이미 걸러 두므로 조용히 건너뛴다.
#
#  **공짜 칸을 건너뛰지 않는다.** rank_table 은 건너뛰는데, 상점에 공짜 한
#  장이 서면(_item_free_pick) 칸이 다섯 중 넷으로 줄어 **마지막 하나가
#  조용히 안 뜬다** — 실제로 그랬다: l05 녹는 시계가 테이블에 한 번도 안
#  올라오고 l03 이 두 장 보였다(2026-09-18 실측). 다섯을 다 보려고 낸 줄이
#  다섯 중 넷만 보여 주면 그 줄은 거짓말이다. 공짜 표는 그 자리에 그대로
#  남긴다 — 값이 0 인 것은 상점의 성질이지 모양의 성질이 아니다.
static func _form_table(g: Node, ids: Array) -> void:
	if g.state != g.S.SHOP:
		g._open_shop()
	g._roll_stock()
	for i in ids.size():
		if i >= g.stock.size():
			break
		var d: Dictionary = _item_by(String(ids[i]))
		if d.is_empty():
			continue
		var fr: bool = bool(g.stock[i].get("free", false))
		var e := {"type": "item", "d": d, "sold": false,
				"cost": 0 if fr else g._league_cost(int(d.get("cost", 0)))}
		if fr:
			e["free"] = true
		g.stock[i] = e
	g._drop_roll()


static func _rar_items(rar: String) -> Array:
	var out := []
	for it in GameData.items():
		if String(it.get("rarity", "common")) == rar:
			out.append(it)
	return out


static func _list(k: String) -> Array:
	match k:
		"item": return GameData.items()
		"item_common": return _rar_items("common")
		"item_uncommon": return _rar_items("uncommon")
		"item_rare": return _rar_items("rare")
		"item_legendary": return _rar_items("legendary")
		# 사탕과 사진이 한 표에 산다(둘 다 "골라서 쓰는" 물건이라 길이 같다).
		# 개발자 판에서는 갈라 보여야 한다 — 섞어 놓으면 사진 여덟이 사탕
		# 틈에 묻혀 "왜 없지" 가 된다.
		"cons": return GameData.candies()
		"photo": return GameData.fixtures()
		"mod": return GameData.mods()
		"dart": return GameData.darts()
		"vou": return GameData.fixtures()
		"tag": return GameData.tags()
		"mf", "bmf": return GameData.modifiers()
		"league": return GameData.leagues()
		"pack": return GameData.packs()
		"chal": return GameData.challenges()
		"boost": return GameData.boosters()
		"sfx":
			# game.gd 의 SFX 표를 그 순서대로 읽는다. dev.gd 는 game.gd 를
			# preload 할 수 없다(game.gd 가 이쪽을 preload 한다) — 이미 올라와
			# 있는 것을 load 로 집는다. probe_sfx.gd 도 같은 길로 본다.
			if _sfx_rows.is_empty():
				for k2 in load("res://scripts/game.gd").SFX.keys():
					_sfx_rows.append({"n": String(k2)})
			return _sfx_rows
	return []


# 점수 카드를 다시 볼 세 단. 이름과 큐를 한 곳에서 쥔다.
const CARDFX_STEPS := ["담담", "큼", "한 방"]
#  정산 빨리 보기 사다리. 게임 기본은 2.5(셋째)다 — 3.0 은 settle_step 소리
#  (0.10초)와 겹치기 직전이라 **개발자 사다리에만** 둔다(2026-09-19).
const FAST_STEPS := [1.0, 2.0, 2.5, 3.0]
const FAST_NAMES := ["1배", "2배", "2.5배", "3배"]

#  부서짐 재질 여섯. 표(game.gd 의 BREAK)와 **같은 차례**로 적는다 —
#  ◀▶ 로 훑을 때 유리 → 밀랍이 이웃이라 둘의 차이(0.400 대 0.560 ·
#  5조각 대 3조각 · 방사 대 아래로만)가 한 칸 옆에서 바로 보인다.
#  대표 동전은 MATS 가 실제로 그 재질을 매어 둔 id 다.
const BREAK_MATS := [
	{"m": "glass", "n": "유리", "id": "c03"},
	{"m": "wax", "n": "밀랍", "id": "c06"},
	{"m": "cast", "n": "주물", "id": "c30"},
	{"m": "pixel", "n": "픽셀", "id": "r09"},
	{"m": "hollow", "n": "빈 것", "id": "l03"},
	{"m": "", "n": "기본", "id": "c04"},
]


#  ── 동전의 죽음을 다시 보는 줄들이 쓰는 셋 (2026-09-19) ──
#  smash1(1062-1065)이 **실제로 밟은 자리**다 — 갈래가 _sweep_begin 을
#  안 부르면 _sweep_reset 도 안 돌아 소리 문이 닫힌 채 남아 다섯째
#  누름부터 영영 무음이었다. 여기도 같은 셋을 앞머리에 놓는다.
static func _wreck_open(g: Node) -> void:
	g.wreck_snd_from = g.wreck.size()   # 이번 묶음을 새로 연다
	g.wreck_seed += 1                   # 안 밀면 눌러도 같은 조각이 같은 자리다
	if g.owned.is_empty():
		#  비었으면 다시 깐다 — 줄이 죽은 것으로 보이는 회귀를 막는
		#  그 자리다. c03(유리 1/2) · c06(밀랍 1/10) 둘이면 굴림도
		#  재질도 한 번에 선다.
		for bid in ["c03", "c06"]:
			var it := _item_by_id(bid)
			if not it.is_empty():
				g.owned.append(it)
		g._panel_reset()


static func _item_by_id(id: String) -> Dictionary:
	for it in GameData.items():
		if String(it.get("id", "")) == id:
			return (it as Dictionary).duplicate(true)
	return {}


#  시체를 태어난 자리로 되돌린다. 조각의 t 는 **음수에서 시작**하므로
#  (언 흰 실루엣 구간) 0 이 아니라 -hold 로 되돌려야 언 프레임이 다시 선다.
static func _wreck_rewind(g: Node) -> void:
	for we in g.wreck:
		we.t = 0.0
		var t0: float = 0.0 if g.motion_off \
				else -float(g.BREAK.get(String(we.mat), g.BREAK[""]).hold)
		for pc in (we.pcs as Array):
			pc.p = (pc.d0 as Vector2) * 6.0 if g.motion_off else Vector2.ZERO
			pc.v = pc.v0
			pc.rot = 0.0
			pc.t = t0
		for gr in (we.gr as Array):
			gr.p = (gr.d0 as Vector2) * 7.0 if g.motion_off else Vector2.ZERO
			gr.v = gr.v0
			gr.t = t0


static func _cur_name(g: Node, e: Dictionary) -> String:
	var k := String(e.k)
	var i: int = int(pick.get(k, 0))
	#  라운드별 조준 저울. **표를 읽어 계산하지 않고 g._stock_items(nxt) 를
	#  실제로 부른다** — _stock_items 가 바닥을 안에서 고르므로 여기가 보는
	#  풀은 상점이 굴리는 풀과 글자 그대로 같다. 거짓말할 길이 없다.
	#  네 칸이 각각 다른 사고를 잡는다: 바닥은 「표가 실제로 읽히는가」(열
	#  이름을 틀리면 0.00), 후보는 「그 라운드에 살아 있는 조준 동전 수」,
	#  칸은 자리 하나가 조준일 확률(폭·뱃지·리롤과 안 얽히는 단위라 이것이
	#  기준이다), 판은 그 폭으로 한 판에 하나라도 뜰 확률. 2026-09-18
	if k == "aimw":
		var rn := GameData.rounds_n()
		var rr: int = i % maxi(rn, 1) + 1
		#  **프레임마다 다시 세지 않는다.** game.gd 의 _process 는 마지막 줄이
		#  조건 없는 queue_redraw() 라 판이 떠 있는 동안 이 줄이 매 프레임
		#  그려진다. 재 보니 _stock_items 한 번이 4.66 ms 고 거기에 돌려받은
		#  장마다 item_weight 를 한 바퀴 더 돌아 프레임당 6.79 ms 였다 —
		#  60프레임 예산 16.7 ms 의 절반이라 이 쪽을 보는 동안 판이 끊겼다
		#  (견줄 값으로 _rows 한 바퀴가 0.01 ms 다). 답이 달라지는 것은 고른
		#  라운드와 든 동전 둘뿐이라 그 둘을 열쇠로 스티커한다. 2026-09-18
		var ids := ""
		for oi in g.owned:
			ids += String(oi.get("id", "")) + ","
		var key := "%d|%s" % [rr, ids]
		if key == _aimw_key:
			return _aimw_txt
		#  그 라운드의 **첫 상점**이 보는 판 번호다. R1 은 leg_no=1 뒤라
		#  nxt=2 인데, 2 로 안 막으면 min_leg(전 등급 2)가 후보를 통째로
		#  걸러 R1 만 「후보 0장」으로 보인다 — 없는 사고가 보이는 자리다.
		var nxt: int = maxi(2, (rr - 1) * GameData.legs_per_round() + 1)
		var own: bool = g._has_aim_item()
		var fw: float = GameData.aim_floor_own(nxt) if own else GameData.aim_floor(nxt)
		#  바닥만 찍으면 min_leg 나 소유로 후보가 비어 결과가 조용히 0 이
		#  되는 사고(하데스에서 Tier 전제가 레전더리 확률을 0 으로 만드는
		#  그 모양)가 안 보인다. **살아 있는 후보 수를 같이 센다.**
		var live := 0
		var sum := 0.0
		var aws := 0.0
		for it in g._stock_items(nxt):
			var w: float = float(it.w) if it.has("w") else GameData.item_weight(it)
			sum += w
			if String(it.get("aim", "")) != "":
				live += 1
				aws += w
		#  갈래 저울은 shop_kinds() 가 쥔다. 열 이름은 "w" 다 — shop.csv 의
		#  weight 를 그 이름으로 옮겨 담는다.
		var ks := 0.0
		var iw := 0.0
		for kk in GameData.shop_kinds():
			var kw := float(kk.get("w", 0.0))
			ks += kw
			if String(kk.id) == "item":
				iw = kw
		var per := 0.0
		if sum > 0.0 and ks > 0.0:
			per = (iw / ks) * (aws / sum)
		var shp := 1.0 - pow(1.0 - per, float(GameData.shop_slots(nxt)))
		_aimw_key = key
		_aimw_txt = "%d/%d · 바닥 %.2f%s · 후보 %d · 칸 %.2f%% · 판 %.2f%%" % [
				rr, rn, fw, " (든 뒤)" if own else "", live, per * 100.0, shp * 100.0]
		return _aimw_txt
	# 표가 아니라 상수 목록이라 _list 를 안 지난다 — 그래도 화면에서는
	# 다른 줄과 같은 꼴("3/8 빗각")로 보여야 몇 가지 중 몇 번째인지 안다.
	if k == "aim":
		var am: Array = GameData.AIM_MODES
		var j: int = i % maxi(am.size(), 1)
		return "%d/%d %s" % [j + 1, am.size(), GameData.aim_name(String(am[j]))]
	# 이것도 _list 를 안 지나는 상수 목록이다. 제 갈래를 안 내면 아래 rows 가
	# 비어서 화면에 「(없음)」이 뜬다 — 줄은 있는데 이름이 없는 꼴이다(2026-09-18).
	if k == "cardfx":
		return "%d/3 %s" % [i % 3 + 1, CARDFX_STEPS[i % 3]]
	#  이것도 _list 를 안 지나는 상수 목록이다. 총 길이를 같이 찍는다 —
	#  「유리 0.40 / 밀랍 0.56」이 한 줄에 보여야 ◀▶ 한 칸으로 견준다.
	if k == "breakmat":
		var bj: int = i % BREAK_MATS.size()
		var bm: Dictionary = BREAK_MATS[bj]
		var bt: Dictionary = load("res://scripts/game.gd").BREAK[String(bm.m)]
		return "%d/%d %s · %d조각 · %.2fs" % [bj + 1, BREAK_MATS.size(),
				bm.n, int(bt.n),
				float(bt.hold) + float(bt.fly) + float(bt.sink)]
	#  빨리 보기 사다리도 표가 아니라 상수 목록이다. **_names 에도 같은
	#  갈래를 낸다** — 한쪽만 내면 고르개를 열었을 때 텅 빈다(2026-09-19).
	if k == "fast":
		return "%d/%d %s" % [i % FAST_STEPS.size() + 1, FAST_STEPS.size(),
				FAST_NAMES[i % FAST_STEPS.size()]]
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
	#  동전 줄에는 등급 낱말을 잇는다(2026-09-18) — 「12/100 태양계 · 레어」.
	#  백 줄을 훑을 때 등급이 **같이** 읽힌다. 그림이 아니라 표가 말하는
	#  자리라, 테가 안 보이는 것과 테를 잘못 그린 것을 여기서 가른다.
	if k.begins_with("item") and String(r.get("rarity", "")) != "":
		nm += " · " + GameData.rarity_name(String(r.rarity))
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
		"sfx_lad":
			# 정산이 반음씩 오르는 것이 게임 이름의 유래다. 한 옥타브를 올려 본다.
			# 파일이 앉은 자리면 pitch_scale 이 같은 비로 밀리는 것까지 들린다.
			_q.clear()
			for k3 in 13:
				_q.append(["settle_step", 392.0 * pow(2.0, float(k3) / 12.0),
						g.beat * 0.5])
			_say("정산 사다리")
			return
		"sfx_hit":
			# 등급이 곧 소리다. 여섯을 붙여 들어야 오르는지 안 오르는지 안다.
			_q.clear()
			#  게임은 등급 밑에 접촉(board_thud)을 같이 깐다. 여기서도 같이
			#  내야 사다리가 게임에서 나는 그 소리로 들린다 — 0.0 은 다음 틱
			#  이라 한 프레임 앞선다(판에서도 몸소리가 먼저다).
			for nm2 in ["hit_miss", "hit_single", "hit_double", "hit_triple",
					"hit_bull_o", "hit_bull_i"]:
				_q.append(["board_thud", 0.0, 0.0])
				_q.append([nm2, 0.0, 0.45])
			_say("착탄 사다리")
			return
		"sfx_pair":
			# 짝은 하나만 들어서는 못 잡는다 — 집다/놓다, 고르다/풀다를 붙인다.
			_q.clear()
			for nm3 in ["hand_take", "hand_drop", "rack_select", "rack_deselect",
					"shop_select", "shop_deselect", "menu_pick", "menu_back"]:
				_q.append([nm3, 0.0, 0.32])
			_say("짝 넷")
			return
		"sfx_all":
			_q.clear()
			for r2 in _list("sfx"):
				_q.append([String(r2.n), 0.0, 0.34])
			_say("표 %d개" % _q.size())
			return
		"sfx_stop":
			_q.clear()
			_say("그쳤다")
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
		"replay":
			# 정산 연출은 한 번 지나가면 다시 못 본다. 고치는 동안 매번
			# 판을 넘길 수는 없다.
			g.clear_t = 0.0
			#  **선반도 같이 되감는다.** clear_t 만 되돌리면 「정산 다시
			#  재생」이 표만 처음부터고 시체는 이미 가라앉아 있어서 정말
			#  처음이 아니다(2026-09-19). 시체의 시계는 clear_t 와 **따로**
			#  도는데 — 그래야 건너뛰기(clear_t = 99)에 안 죽는다 — 그
			#  갈라 둔 값이 여기서는 손으로 이어 줘야 하는 자리다.
			_wreck_rewind(g)
			_say("정산 처음부터")
			return
		"wear1":
			#  **실제 경로 그대로** 태운다. 연출만 보는 줄이 아니라
			#  「진짜 그 길로 가면 보이는가」를 보는 줄이고, 이 넷 중
			#  제일 중요하다 — 「부서졌다」가 한 글자도 안 보이던 원인
			#  (_settle_clear 의 pops.clear())이 바로 이 경로에 있었다.
			#  ⚠ _settle_clear 를 부르므로 **골드가 실제로 정산된다.**
			_wreck_open(g)
			g._leg_end_wear()
			g._settle_clear()
			_say("판 끝 마모 — 골드도 정산됐다")
			return
		"wreck6":
			#  랙을 꽉 채우고 전부 죽여 **최악**을 세운다(「최악의 상태」와
			#  같은 생각이다 — 640x360 에서 이 상태를 못 그리면 지금 고치는
			#  게 나중보다 싸다). 정지 화면에서 볼 것 다섯: 항목이 단추
			#  (y 290)와 큰 표(x 190)를 안 밟는가 · 조각이 글자 왼끝(96)을
			#  안 넘는가 · 소리가 하나인가 · 맥동이 어긋나는가 ·
			#  다섯(gap 42)과 여섯(gap 36)이 둘 다 서는가.
			_wreck_open(g)
			g.owned.clear()
			var want: int = maxi(GameData.max_items(), 1)
			for bm in ["c03", "c06", "c30", "r09", "l03", "c04"]:
				if g.owned.size() >= want:
					break
				var bit := _item_by_id(String(bm))
				if not bit.is_empty():
					g.owned.append(bit)
			while g.owned.size() < want and not GameData.items().is_empty():
				g.owned.append((GameData.items()[g.owned.size()
						% GameData.items().size()] as Dictionary).duplicate())
			g.sealed = -1
			g._panel_reset()
			g.wreck.clear()
			g.wreck_n = 0
			g.wreck_snd_from = 0
			g.wreck_seed += 1
			var n6: int = g.owned.size()
			for wi in range(n6 - 1, -1, -1):
				g._wreck_add(wi, g.owned[wi], "boom" if wi % 2 == 0 else "perish",
						2 if wi % 2 == 0 else 0)
			g.owned.clear()
			g._panel_reset()
			g._wreck_sfx()
			_say("선반 %d 줄" % n6)
			return
		"safe1":
			#  「남았다」 하나. 위 「부서짐 재질」과 **번갈아 눌러** 비대칭이
			#  실제로 읽히는지(0.80초 조용함 대 0.40초 파열)를 ↑↓ 한 칸으로
			#  재 본다. leg_no 를 한 칸씩 밀면 고리 트인 자리와 뜨는 높이가
			#  매번 달라지는지가 보인다 — 습관화 방어가 실제로 도는지 재는
			#  유일한 길이다.
			_wreck_open(g)
			g._wreck_safe(0, g.owned[0], 10)
			g._wreck_sfx()
			_say("남았다 1/10")
			return
		"worst":
			# 제약 넷 · 동전 최대 · 사탕 칸 최대 · 보드 확장. 640x360 에서
			# 이 상태를 못 그리면 레이아웃이 틀린 것이고, **지금 고치는 게
			# 나중보다 싸다.** 화면이 가장 붐비는 순간을 한 줄로 부른다.
			g.active_mods = []
			for mo in GameData.modifiers():
				if g.active_mods.size() < 4:
					g.active_mods.append(mo)
			g.owned = []
			for it in GameData.items():
				if g.owned.size() < GameData.max_items():
					g.owned.append(it.duplicate())
			g.cons = []
			for c in GameData.consumables():
				if g.cons.size() < GameData.cons_slots():
					g.cons.append(c)
			if g.mods_own.is_empty():
				g._apply_mod(String(GameData.mods()[0].id))
			#  보스 카드가 붐비는 모습 — 명판 둘 + 이름 없는 줄이 실제로
			#  서는지를 여기서 한 번에 본다(겹치기 챌린지를 안 켜도 볼 수
			#  있어야 한다). 제 좌표 r 13 명판 둘과 상단 바 아이콘 넷 +
			#  「+2」 규약이 같이 성립하는지가 이 세 줄로 드러난다.
			var wbn: int = g._round_boss()
			if wbn > 0 and GameData.modifiers().size() >= 10:
				g.boss_mods[wbn] = PackedStringArray([
						String(GameData.modifiers()[3].id),      # dead 부채꼴
						String(GameData.modifiers()[9].id)])     # turn 화살표
			g.gold = 99999
			g.sealed = 0
			_say("최악의 상태")
			return
		"restock":
			g._roll_stock()
			_say("테이블 다시")
			return
		"sweep":
			#  쓸기는 상점에서 리롤을 눌러야만 돌고, 골드가 모자라면 그마저
			#  안 돈다(_reroll 의 _deny 갈래). 연출을 고치는 동안 매번 런을
			#  돌 수는 없다 — 「정산 연출은 한 번 지나가면 다시 못 본다」
			#  (replay)와 같은 이유다.
			#  **_reroll 을 안 부른다.** 골드·가격을 건드리면 개발자 모드가
			#  밸런스를 만지는 자리가 된다. _sweep_begin 머리말이 「골드
			#  정산은 _reroll 이 이미 끝냈다. 여기는 연출과 물리만 연다」고
			#  적어 둔 그대로다.
			if g.state != g.S.SHOP:
				g._open_shop()
			g._drop_settle()
			g._sweep_begin()
			_say("쓸기 다시")
			return
		"sweep9":
			#  조각이 가장 붐비는 순간(큰 조각 36 + 부스러기 27)을 한 줄로
			#  부른다. 「최악의 상태」(worst)가 같은 생각의 선례다 —
			#  640x360 에서 이 상태를 못 그리면 지금 고치는 게 나중보다 싸다.
			if g.state != g.S.SHOP:
				g._open_shop()
			g._roll_stock()
			var n0: int = g.stock.size()
			if n0 > 0:
				while g.stock.size() < 9:
					g.stock.append(g.stock[g.stock.size() % n0].duplicate(true))
			g._drop_roll()
			g._drop_settle()
			g._sweep_begin()
			_say("아홉으로 쓸기")
			return
		"smash1":
			#  쓸기 없이 조각만 본다. 조각·먼지·턱 자국·소리를 한 번에
			#  세워 놓고 **2px 밑으로 내려간 조각이 없는지** 정지 화면에서
			#  들여다보는 줄이다. 「제목 판 깨기 직전」(egg)이 이 줄의 본이다.
			if g.state != g.S.SHOP:
				g._open_shop()
			g._drop_settle()
			#  한 번에 한 개를 깨므로 매물 수만큼 누르면 판이 빈다. 그 뒤로는
			#  아래 for 가 한 바퀴를 헛돌고 **아무 일도 안 났다** — 누르는
			#  사람에게는 줄이 죽은 것으로 보인다(2026-09-18, dev_probe 가
			#  다섯째·여섯째 누름에서 잡았다). 비었으면 다시 깐다 — 「테이블
			#  다시 굴리기」(restock)가 부르는 그 함수 그대로라 골드·가격을
			#  안 만진다.
			var live := false
			for si in mini(g.drop.size(), g.stock.size()):
				if not g.drop[si].gone:
					live = true
					break
			if not live:
				g._roll_stock()
				g._drop_settle()
			#  소리 문을 연다. 이 갈래는 _sweep_begin 을 안 부르므로
			#  _sweep_reset 도 안 돈다 — 직전 쓸기가 상한(SMASH.snd_max)을
			#  다 썼으면 smash_snd_n 이 그대로 남아 **다섯 번째 누름부터
			#  영영 무음**이었다(2026-09-18). 여는 값 셋은 연출 카운터라
			#  골드·가격과 무관하다.
			g.smash_snd_n = 0
			g.smash_snd_t = 0.0
			g.smash_n = 0
			#  씨도 한 칸 민다. smash_n 을 0 으로 되돌리면 조각 난수가
			#  (smash_seed·131 + smash_n·17) 로 같은 자리에 떨어져 눌러도
			#  눌러도 똑같은 조각이 난다 — 여러 벌을 보려고 두는 줄이다.
			g.smash_seed += 1
			for si in mini(g.drop.size(), g.stock.size()):
				if g.drop[si].gone:
					continue
				g.drop[si].u = g._chute_dock_u(g.Z_SELL, g.drop[si].w) + g.drop[si].hw
				g.drop[si].vu = -2600.0
				g._smash_at(si)
				break
			_say("부딪힘 한 번")
			return
		"motion":
			# 흔들림·밀려 듦·굴림을 통째로 끈다. 값은 그대로 최종값으로 간다 —
			# 스크린샷 자가 떨림 없는 화면을 잡을 길이고, 도트가 흔들리는
			# 것을 못 견디는 사람도 있다.
			g.motion_off = not g.motion_off
			_say("모션 %s" % ("끔" if g.motion_off else "켬"))
			return
		"fast_lock":
			#  안 눌러도 배속이 걸린다. _fast_on 이 fast_lock 을 Dev.on 검사보다
			#  **먼저** 보므로 개발자 판을 연 채로도 걸린다(2026-09-19).
			g.fast_lock = not g.fast_lock
			_say("빨리 보기 고정 %s" % ("켬" if g.fast_lock else "끔"))
			return
		"over_unlock":
			#  런 끝 잠금 0.40초를 건너뛴다. 갈무리 도구가 쓰는 그 값이다.
			g.over_t = 9.0
			_say("런 끝 잠금 풀림")
			return
		"touch":
			#  얹힘 길을 통째로 죽인다 — 누름-읽기만 남는다. ⑤의 코드가
			#  **오직 여기서만** 손으로 검증된다(dev-mode-parity).
			g.hover_live = not g.hover_live
			g.tip_pin = {}
			_say("얹힘 %s" % ("켬" if g.hover_live else "끔 — 손가락인 척"))
			return
		"sell_arm":
			#  새 자리(4,56,72,22)와 되살아난 이름 줄을 손 없이 재고 찍는다.
			g.sell_sel = 0
			g.sell_t = 0.0
			_say("판매 단추 %s" % g._sell_btn_rect())
			return
		"tip_layer":
			#  ⚠ _tip_update 가 hover_live 참일 때 매 프레임 false 로 되돌리므로
			#  **「손가락인 척」을 켠 뒤에만 뜻이 있다.**
			g.tip_lite = not g.tip_lite
			_say("툴팁 %s%s" % ["얕게" if g.tip_lite else "깊게",
					"" if not g.hover_live else " (손가락인 척부터)"])
			return
		"lobby_arm":
			#  붉은 띠 · 굵은 마침표를 설정을 여닫지 않고 바로 본다.
			g.lobby_arm = not g.lobby_arm
			g.lobby_arm_t = 0.0
			_say("로비 겨눔 %s" % ("섬" if g.lobby_arm else "풀림"))
			return
		"rank_off":
			#  새 테 한 벌(밴드·박음·물림·플라크·맥동)을 통째로 끄고 옛 그림으로
			#  되돌린다. 전·후를 **같은 자리에서** 눈으로 대는 것이 「정말
			#  나아졌나」를 재는 유일한 길이고, 사진 두 장을 뜰 때도 이 하나면 된다.
			g.rank_off = not g.rank_off
			_say("등급 테 %s" % ("끔" if g.rank_off else "켬"))
			return
		"rank_rack":
			#  네 등급을 한 줄에 세운다. 랙은 r=19 라 밴드·박음·물림이 다 사는
			#  **가장 큰 선 자세**다 — 여기서 안 갈리면 더 작은 자리에서도 안 갈린다.
			#  슬롯이 다섯이라(tuning.max_items) 재질 셋은 rank_mat 이 따로 맡는다.
			g.owned = []
			for rr in ["common", "uncommon", "rare", "legendary"]:
				var pl := _rar_items(String(rr))
				if not pl.is_empty():
					g.owned.append(pl[0].duplicate())
			g.sealed = -1
			g._panel_reset()
			_say("등급 한 벌 랙에 — %d장" % g.owned.size())
			return
		"rank_mat":
			#  **회귀가 나면 이 셋 중 하나에서 난다** — 표식과 재질이 실제로
			#  만나는 자리가 셋뿐이다(나머지 재질 셋은 전부 흔함이라 표식이 0개다):
			#    u22 WHITE ALBUM  금테 x 희귀    — 금테와 등급 밴드가 겹치는 유일한 장
			#    r09 불사의 토템  도트 x 레어    — 물림 없이 격자 스냅 박음
			#    l03 NULL         빈 인쇄 x 레전더리 — 윗면 없는 빈 플라크
			#  2026-09-18 — l03 은 `slab` 을 그대로 쥐므로 그림이 안 바뀌지만,
			#  **r09 의 매끈함이 이제 술어가 아니라 표의 값이다**(COIN_FORM
			#  r09 = bare · 슬롯 0x000). `pixel and mill → disc` 하드코딩이
			#  두 자세에 하나씩 있던 것을 표 한 칸으로 옮긴 그 자리를 이 줄에서
			#  눈으로 확인한다 — 한쪽만 고쳤으면 테이블과 랙에서 딴 물건이 된다.
			g.owned = []
			for id2 in ["u22", "r09", "l03"]:
				var d2 := _item_by(String(id2))
				if not d2.is_empty():
					g.owned.append(d2.duplicate())
			g.sealed = -1
			g._panel_reset()
			_say("재질x등급 %d장" % g.owned.size())
			return
		"rank_table":
			#  「사진은 상점당 0.5% 라 눈으로 보려면 길이 따로 있어야 한다」
			#  (restock_fix)와 같은 이유다 — **레전더리는 저울로는 영원히 안 뜬다**
			#  (가중치 0). 누운 자세의 밴드·박음·물림·플라크를 한 테이블에서 견준다.
			#  여기서 **리롤을 한 번 돌리면** _smash_at → _shard_cut 의 새 격자
			#  가지가 플라크를 제 모양으로 타일링하는지, 값표가 안 밀렸는지,
			#  물건끼리 안 겹쳐 눕는지가 한 번에 보인다 — 플라크의 물리를
			#  실제로 굴려 보는 유일한 길이다.
			if g.state != g.S.SHOP:
				g._open_shop()
			g._roll_stock()
			var si := 0
			for rr2 in ["common", "uncommon", "rare", "legendary", "legendary"]:
				var pl2 := _rar_items(String(rr2))
				if pl2.is_empty():
					continue
				while si < g.stock.size() and bool(g.stock[si].get("free", false)):
					si += 1
				if si >= g.stock.size():
					break
				var d3: Dictionary = pl2[randi() % pl2.size()]
				g.stock[si] = {"type": "item", "d": d3,
						"cost": g._league_cost(int(d3.get("cost", 0))), "sold": false}
				si += 1
			g._drop_roll()
			_say("등급 한 벌 테이블에")
			return
		#  ── 모양 열아홉을 훑는 넉 줄 (2026-09-18) ──────────
		#  「게임에 만든 것은 같은 턴에 개발자 모드에도 길을 낸다」.
		#  랙 슬롯이 다섯(tuning.max_items)이라 **레전더리 다섯 = 정확히 한 판**이다.
		"form_leg":
			#  정사각 · 무딘 마름모 · 가로 명판 · 세로 명판 · 늘어짐이 한 줄에
			#  선다. 랙 r=19 는 겹테·박음·맥동이 다 사는 **가장 큰 선 자세**라
			#  여기서 안 갈리면 더 작은 자리에서도 안 갈린다.
			#  보는 것 둘: 다섯이 **서로 다른가** · 다섯이 **같은 등급으로
			#  보이는가**(겹테 2 · 홀로 온 바퀴 · 2.2초 맥동 · 옆면 두께).
			g.owned = []
			for lid in ["l01", "l02", "l03", "l04", "l05"]:
				var ld := _item_by(String(lid))
				if not ld.is_empty():
					g.owned.append(ld.duplicate())
			g.sealed = -1
			g._panel_reset()
			_say("레전더리 %d장 — 정사각·마름모·가로·세로·늘어짐" % g.owned.size())
			return
		"form_var":
			#  다섯 종 대표. **다섯 다 enabled=1 이라 사본 트릭이 필요 없다.**
			#  r=19 에서 물림이 다 사는 자리이고, 여기가 「다섯이 한 가족인가 ·
			#  서로 세어지게 다른가」를 재는 유일한 화면이다.
			g.owned = []
			for rid in ["r13", "r04", "r02", "r01", "r09"]:
				var rd := _item_by(String(rid))
				if not rd.is_empty():
					g.owned.append(rd.duplicate())
			g.sealed = -1
			g._panel_reset()
			_say("레어 변형 %d장 — 고름·축·쏠림·쌍·매끈" % g.owned.size())
			return
		"form_leg_table":
			#  **레전더리는 가중치 0 이라 저울로는 영원히 안 뜨고 팩으로만 온다.**
			#  누운 자세 rx 는 늘 22.04 라 다섯이 최대 크기로 선다. 여기서
			#  리롤을 한 번 돌리면 _smash_at → _shard_cut 의 새 가지가 다섯을
			#  제 모양으로 타일링하는지 · 값표가 안 밀렸는지 · 물건끼리 안
			#  겹쳐 눕는지가 한 번에 보인다.
			_form_table(g, ["l01", "l02", "l03", "l04", "l05"])
			_say("레전더리 다섯 테이블에")
			return
		"form_var_table":
			#  **레어 변형이 가장 크게 보이는 자리가 누운 테이블(rx 22.04)**
			#  이고, 사용자가 실제로 고르는 자리도 여기다. 골 폭 5.73px ·
			#  깊이 2.20px 이 다섯 종에서 어떻게 갈리는지가 여기서만 제 크기로
			#  보인다.
			_form_table(g, ["r13", "r04", "r02", "r01", "r09"])
			_say("레어 변형 다섯 테이블에")
			return
		"restock_fix":
			# 사진은 상점당 0.5% 다(기획서 P.30). 손으로 리롤해서는 이백
			# 번을 굴려도 한 번 볼까 말까라, 테이블 위의 사진을 눈으로
			# 보려면 길이 따로 있어야 한다. 굴린 뒤 자리 하나를 바꾼다 —
			# 게임이 까는 것과 같은 모양이라 툴팁도 창구도 그대로 산다.
			g._roll_stock()
			var fp := GameData.fixtures()
			if fp.is_empty():
				_say("사진 없음")
				return
			var fd: Dictionary = fp[randi() % fp.size()]
			for si in g.stock.size():
				if bool(g.stock[si].get("free", false)):
					continue
				g.stock[si] = {"type": "fix", "d": fd,
						"cost": g._league_cost(int(fd.get("cost", 0))),
						"sold": false}
				break
			g._drop_roll()          # 종이는 안 튄다 — 낙하를 갈래대로 다시 잡는다
			_say("테이블에 사진 %s" % String(fd.get("n", "?")))
			return
		"mf_off":
			g.active_mods = []
			g._start_leg()
			_say("제약 없음")
			return
		"boss_roll":
			var rbn: int = g._round_boss()
			if rbn <= 0:
				_say("이 라운드에 보스 판이 없다")
				return
			#  지금 든 것을 avoid 로 넘긴다 — 눌렀는데 같은 것이 나오면
			#  굴린 것인지 안 굴린 것인지가 화면에서 안 갈린다.
			g._roll_boss_mods(rbn, true,
					g.boss_mods.get(rbn, PackedStringArray()))
			g.queue_redraw()
			_say("보스 제약 %s"
					% ", ".join(g.boss_mods.get(rbn, PackedStringArray())))
			return
		"boss_void":
			var vbn: int = g._round_boss()
			if vbn <= 0:
				_say("이 라운드에 보스 판이 없다")
				return
			if g.boss_void.has(vbn):
				g.boss_void.erase(vbn)
			else:
				g.boss_void[vbn] = true
			g.queue_redraw()
			_say("보스 무효 %s" % ("켬" if g.boss_void.has(vbn) else "끔"))
			return
		"bake":
			g._board_bake()
			_say("판 다시 구움")
			return
		"intro":
			g._intro_begin()
			_say("인트로")
			return
		"egg_crack":
			# 불 여섯에 세워 두고 제목으로 간다 — 한 번 더 물면 첫 금이 튄다.
			g._egg_reset()
			g.state = g.S.TITLE
			g.pause_from = -1
			g.egg_streak = int(g.EGG.from) - 1
			_say("제목 판 — 불 한 번이면 금이 간다")
			return
		"egg":
			# 불 서른 번을 매번 던질 수는 없다. 스물아홉에 세워 두고 제목으로
			# 간다 — 한 번만 더 불을 물면 깨진다.
			g._egg_reset()
			g.state = g.S.TITLE
			g.pause_from = -1
			g.egg_streak = int(g.EGG.need) - 1
			_say("제목 판 — 불 한 번이면 깨진다")
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
		#  ⚠ 바로 위 「해금 전부 잠그기」가 훑는 Save.unlock_keys() 는 **[해금]
		#  절만** 낸다 — [발견]을 안 건드린다. 줄이 따로 있어야 하는 까닭이
		#  이것이고, 덕분에 얻는 것이 있다: 해금을 다 잠가도(itemgot 이
		#  지워져도) 발견 표시가 안 흔들리고, 발견을 다 잠가도 팩 풀이 안
		#  흔들린다. **두 계통이 서로를 모른다.**
		#  그리고 해금과 발견은 다른 단이다 — 한 줄로 두 단을 열면 발견만
		#  껐다 켜며 화면을 보는 일이 못 된다.
		#
		#  비대칭인 까닭 — 「열기」는 저장을 안 쓰고 「잠그기」는 쓴다. 열기는
		#  압도적으로 **도구**가 쓴다(기획서 그림 스무남짓). 잠그기는 사람이
		#  쓰고, 이미 플레이한 프로필에서 이 기능을 보는 유일한 길이다.
		#  2026-09-19
		"found_all":
			g._dev_unlock_all()
			_say("전부 발견")
			return
		"found_none":
			g._dev_unlock_none()
			_say("전부 미발견")
			return
		"stat_clear", "wipe":
			Save.wipe()
			_say("저장 지움")
			return

	# 목록형 — 지금 고른 것을 적용한다
	var rows := _list(k)
	match k:
		"fast":
			#  배수만 민다. 바닥(걸음 4프레임)은 _fast_rate 가 씌우므로
			#  3배를 골라도 눌린 박자에서는 한도가 1.53 이다 —
			#  **사다리 위에서도 걸음을 안 건너뛴다**(2026-09-19).
			var fi: int = i % FAST_STEPS.size()
			g.fast_mul = float(FAST_STEPS[fi])
			_say("빨리 보기 %.1f배" % g.fast_mul)
		"aim":
			var am := String(GameData.AIM_MODES[i % GameData.AIM_MODES.size()])
			g.aim_mode = am
			# 방식마다 쓰는 값이 달라 갈아탄 자리에 남은 값이 섞인다 —
			# 반지름·축을 여기서 새로 세운다.
			g._aim_begin()
			_aim_sticker(g, am)
			_say("조준 %s" % GameData.aim_name(am))
		"breakmat":
			#  고른 재질의 대표 동전을 랙 **첫 빈 칸**에서 부순다 — 시체는
			#  지우고 난 뒤 처음 비는 칸에 서므로 산 동전을 안 덮는다.
			#  **한 줄로 여섯을 나란히 대는 자리**라 유리 → 밀랍이 이웃인
			#  것이 요점이다. 굴림 갈래(유리·밀랍)는 「1/2」·「1/10」이
			#  같이 서고 나머지 넷은 수가 없다 — 수의 있고 없음이
			#  「굴렸는가」를 말하는 그 규칙이 여기서 눈으로 확인된다.
			_wreck_open(g)
			var bmr: Dictionary = BREAK_MATS[i % BREAK_MATS.size()]
			var bmi := _item_by_id(String(bmr.id))
			if bmi.is_empty():
				_say("%s: 대표 동전이 표에 없다" % bmr.n)
				return
			var bbn: int = GameData.boom_n(String(bmi.get("boom", "")))
			g._wreck_add(0, bmi, "boom" if bbn > 0 else "rdec", bbn)
			g._wreck_sfx()
			_say("%s 부서짐" % bmr.n)
			return
		"cardfx":
			# 「정산 다시 재생」은 **판 종료 정산 화면**(clear_t)을 되감는 줄이지
			# 점수 카드의 걸음이 아니다. 카드 연출을 다시 볼 줄은 지금까지 하나도
			# 없었다 — 고치는 동안 매번 판을 넘길 수는 없다(2026-09-18).
			#
			# _land 를 **안 거친다.** 점수 셈도 동전 발동도 닳음도 하나도 안 돈다 —
			# _land 가 하던 초기화를 손으로 놓고 큐만 세운다. 끝맺음은
			# _card_tick 이 가로채므로 빈 큐 갈래(한 발이 끝나는 진짜 길)도
			# 안 밟는다.
			#
			# **조준하는 동안에만 연다.** _is_play() 는 FLY · RESOLVE 까지 참이라,
			# 날아가는 다트 위나 **진행 중인 진짜 정산 위**에서 눌리면 아래
			# queue.clear() 가 그 발의 남은 걸음(합계 걸음까지)을 통째로 버려
			# 그 발 점수가 영영 안 실린다(2026-09-18).
			if not (g.state == g.S.PICK or g._is_aim_stage()):
				_say("조준 중에만")
				return
			var ci := i % 3
			# 앞 미리보기가 아직 미끄러져 나가는 중(3단)이면 그 되돌릴 값이
			# 진짜다 — 지금 화면의 수는 앞 걸음이 남긴 것이라 그대로 베끼면
			# 미리보기를 두 번 누른 뒤에 판이 안 돌아온다.
			if card_ph == 3:
				_card_nums(g)
			# 되돌릴 자리. 미리보기는 판을 한 칸도 안 옮긴다.
			card_back = {
				"state": g.state, "pitch": g.pitch_step,
				"settle_n": g.settle_n, "burst_n": g.burst_n,
				"chip": g.cur_chip, "mult": g.cur_mult, "gain": g.last_gain,
				"big": ci == 2,
			}
			card_ph = 1
			g.card_side = 1
			g.card_y = 206.0
			g.card_mode = 0
			g.cur_chip = 0
			g.cur_mult = 0
			g.card_item = ""
			g.calc_lit = false
			g.roll_t = -1.0
			g.pitch_step = 0
			g._card_reset()
			g.queue.clear()
			# share 가 큰 걸음(0→12 · 0→240)과 작은 걸음이 **한 줄에 섞여 있어야**
			# 「크기 차이가 곧 점수 크기다」가 한 번에 보인다.
			# item 의 i 는 0 을 넘긴다 — 동전 슬롯이 비어도 _panel_fire 가 스스로 막는다.
			match ci:
				0:
					g.queue.append({"k": "chip", "v": 12})
					g.queue.append({"k": "mult", "v": 2})
					g.queue.append({"k": "item", "i": 0, "kind": "chip", "v": 40,
							"lbl": "점수 +40"})
					g.queue.append({"k": "item", "i": 0, "kind": "mult", "v": 3,
							"lbl": "배수 +3"})
				1:
					g.queue.append({"k": "chip", "v": 240})
					g.queue.append({"k": "mult", "v": 9})
					g.queue.append({"k": "item", "i": 0, "kind": "chip", "v": 1200,
							"lbl": "점수 +1200"})
					g.queue.append({"k": "item", "i": 0, "kind": "xmult", "v": 3,
							"lbl": "배수 ×3"})
				_:
					g.queue.append({"k": "chip", "v": 900})
					g.queue.append({"k": "mult", "v": 30})
					g.queue.append({"k": "item", "i": 0, "kind": "chip", "v": 4000,
							"lbl": "점수 +4000"})
					g.queue.append({"k": "item", "i": 0, "kind": "xmult", "v": 3,
							"lbl": "배수 ×3"})
					# 합계 걸음은 **큐에 안 넣는다.** {"k": "total"} 은 연출이
					# 아니라 셈이다 — _score_combine 이 돌아 판 점수에 441,000 이
					# 더해지고 Save.peak("best_gain") 이 앉는다(전설 동전 해금
					# 문턱이 100,000 이다). 마지막 걸음이 끝나는 프레임에
					# _card_big 이 합계 카드를 손으로 놓는다(2026-09-18).
			# _pace() 가 읽는 두 값이다. 안 놓으면 앞 정산의 값이 남아 배속이
			# 틀린 채로 돈다. 「한 방」은 큐 밖의 합계 카드가 한 걸음 더라
			# 하나를 더한다 — 안 더하면 배속이 「큼」과 갈린다.
			g.settle_n = g.queue.size() + (1 if ci == 2 else 0)
			g.burst_n = 0
			g.card_target = 1.0
			g.state = g.S.RESOLVE
			g.qt = g.beat * 1.1
			_say("점수 카드 — %s" % CARDFX_STEPS[ci])
		"score":
			g.score_mode = String(GameData.SCORE_MODES[i % GameData.SCORE_MODES.size()])
			_say("계산 '%s'" % g.score_mode)
		"sfx":
			# 고른 것이 곧 소리다. 화살표로 옆칸을 짚으면 바로 난다 —
			# 따로 "내 보기" 를 눌러야 하면 견줘 듣는 동안 손이 두 배로 든다.
			if not rows.is_empty():
				var snm := String(rows[i % rows.size()].n)
				_q.clear()
				g._sfx(snm)
				_say(snm)
		"item", "item_common", "item_uncommon", "item_rare", "item_legendary":
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
				#  한 장만 낀다 — 게임에서 사는 길(_apply_mod)과 같이 덮는다. 덧붙이던
				#  시절에는 과녁 · 피자 · 도넛이 한 판에 겹쳐 앉았다(사용자, 2026-09-17).
				#  같은 판이 되는 장도 거절 없이 끼운다 — 개발자 판은 막지 않는다.
				g.mods_own = [mid]
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
		"bmf":
			if not rows.is_empty():
				#  한 장만 꽂는다. _start_leg 를 **안 부른다** — 지금 보는
				#  것은 판이 아니라 **카드**다. 열 종을 한 칸씩 넘기며 문장
				#  열 벌과 이름 줄 폭(_elide 가 언제 무는지)을 눈으로 훑는
				#  것이 이 줄의 쓸모다.
				var bn: int = g._round_boss()
				if bn <= 0:
					_say("이 라운드에 보스 판이 없다")
				else:
					var brow: Dictionary = rows[i % rows.size()]
					g.boss_mods[bn] = PackedStringArray([String(brow.id)])
					g.boss_void.erase(bn)
					g.queue_redraw()
					_say("보스 제약 %s" % brow.get("n", "?"))
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
