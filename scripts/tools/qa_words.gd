extends SceneTree

#  사용자 눈에 닿는 글이 **효과와 값만**인가를 잰다.
#    godot --path . --headless --script scripts/tools/qa_words.gd
#
#  사용자가 세 번 반려한 것이 「해설 문장」이다. 그 규칙이 여태 사람 눈으로만
#  지켜졌고, 그래서 다트통 설명 여섯이 존댓말 해설로 남아 있었다(2026-09-24).
#  이 자가 재는 것 여섯:
#    ① 판 위 안내줄 · 조준 줄 — 존댓말 없음 · 상태 이름 없음 · 화면 폭 안 ·
#       끝이 명사형 「-기」다(「다트판을 눌러 … 결정」이 여덟 줄이었다)
#    ② 다트통 줄 — 존댓말 없음. 줄글을 비운 다트통이 **빈 채로 서지 않는다**
#    ③ 런 끝 해금 쪽지 — 머리와 값이 같은 낱말을 두 번 말하지 않는다
#    ④ 못 사는 까닭 — 칸이 꽉 찬 둘은 값(「슬롯 5/5」)이고 문장이 아니다
#    ⑤ 그리는 세 소스의 큰따옴표 전수 — 존댓말 없음 · 금칙어 없음
#    ⑥ **표(data/*.csv)의 name · desc · text** — 존댓말 없음 · 금칙어 없음 ·
#       마침표로 문장을 잇지 않는다
#
#  ⚠ 글꼴이 없는 실행(헤드리스)에서는 폭을 못 잰다 — 그 한 줄만 건너뛰고
#  나머지는 다 돈다. 「재는 자리가 없다고 검사가 조용히 통과해 버리는 것」을
#  막으려고 건너뛴 것을 말로 적는다(_tutor_wrap 의 그 규약).
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var okn := 0
var fail := 0
var skip := 0

#  존댓말 · 해설 꼬리. 이것으로 끝나면 효과가 아니라 말을 건 것이다.
const POLITE := ["세요", "십시오", "합니다", "습니다", "됩니다", "입니다",
		"립니다", "니다", "세오"]
#  판 위 안내줄이 쓸 수 있는 가로 폭. 640 짜리 화면에 가운데로 선다.
const HINT_W := 600.0

#  ── 금칙어 ────────────────────────────────────────────────
#  2026-09-25 에 한 번에 걷어낸 말들이다. 왼쪽이 나면 오른쪽으로 쓴다.
#  전수로 세서 **지금 전부 0곳**이고, 이 자가 0 을 지킨다 — 규칙서를 안 읽은
#  다음 사람도 여기서 막힌다.
#  ⚠ 일부러 뺀 셋. 낱말로 가를 수 없어 눈으로 지킨다:
#    · 「구역」 — 제약 이름 「막힌 칸」이 아직 산다(용어 결정이 남았다)
#    · 「카드」 — 동전을 가리킬 때만 금칙어다. 「교통카드」(동전 이름) ·
#      「보스 카드」 · 점수 카드 연출이 같은 글자를 쓴다
#    · 「랙」 — 「트랙」 안에 들어 있다
#  ⚠ 「통과」는 「관통과」 · 「다트통과」 안에도 들어 있다. 지금은 그 꼴이
#  주석과 _note 칸에만 있어 이 자의 그물 밖이지만, 화면 글에 나면 오탐이다.
const BANNED := {
	"명중": "맞히면 · 빗나가면",
	"발동": "켜진다 · 켜질 때마다",
	"보유": "지운다 — 누구 것인지는 물을 것이 없다",
	"클리어": "판은 넘김 · 런은 완주",
	"통과": "판은 넘김 · 런은 완주 — 넷째 말을 안 만든다",
	"플레이": "판에서",
	"승급": "강화",
	"수 있다": "값으로 닫거나 평서 「-다」로 닫는다",
	"랜덤": "무작위",
	"소모품": "사탕",
	"코인": "골드",
	"멀티": "배수",
	"칩": "점수",
	"스티커": "슬롯",
	"불스아이": "불",
	"가끔": "확률을 그대로 적는다",
	"때때로": "확률을 그대로 적는다",
	"종종": "확률을 그대로 적는다",
	"드물게": "확률을 그대로 적는다",
	"대략": "수치를 그대로 적는다",
	"살짝": "수치를 그대로 적는다",
	"결정": "잡기 · 고르기",
	"다트판을 눌러": "무엇을 정하는지만 적는다",
}
#  표에서 사람이 쓴 글이 사는 칸. 나머지 열은 값이거나 우리끼리 보는 주석이다.
const TXT_COLS := ["name", "desc", "text"]
#  값 표(손잡이 설명이 길게 붙는다)는 화면 글이 아니다.
const SKIP_TABLES := ["tuning"]
#  콘솔은 화면이 아니다 — 이 낱말이 든 줄의 글은 ⑤ 가 안 본다.
const CONSOLE := ["push_warning(", "push_error(", "printerr(", "print("]


func _initialize() -> void:
	Save.gpath = "user://_qa_words_g.cfg"
	Save.path = "user://_qa_words.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c:
		okn += 1
	else:
		fail += 1
	print("  %s %-42s %s" % ["통과" if c else "실패", n, d])


func _skip(n: String, why: String) -> void:
	skip += 1
	print("  건너뜀 %-40s %s" % [n, why])


func _process(_d: float) -> bool:
	if g != null:
		g.set_process(false)
	if busy:
		return false
	busy = true
	_run()
	return false


func _polite(t: String) -> bool:
	for e in POLITE:
		if not t.ends_with(e):
			continue
		#  ⚠ 「니다」가 「아니다」를 오탐한다 — 검증기 글 열몇 줄이 그 꼴이다
		#  (「정수가 아니다」 「hex 가 여섯 자가 아니다」). 앞 글자가 「아」면
		#  존댓말이 아니라 평서다.
		if e == "니다" and t.ends_with("아니다"):
			continue
		return true
	return false


#  금칙어가 들었나. 든 것을 「낱말 → 대신 쓸 말」로 돌려준다.
func _banned(t: String) -> Array:
	var out := []
	for w in BANNED:
		if t.contains(w):
			out.append("%s→%s" % [w, BANNED[w]])
	return out


#  화면에 실제로 그려지는 폭. 글꼴이 없으면 −1.
func _w(t: String, sz: int) -> float:
	if g.font_sm == null:
		return -1.0
	return g.font_sm.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	print("\n글 검사 — 효과와 값만\n")

	# ── ① 판 위 안내줄 · 조준 줄 ─────────────────────────
	var hints := ["던질 다트 고르기"]
	for m in GameData.AIM_HINT:
		for t in GameData.AIM_HINT[m]:
			hints.append(String(t))
	var bad := []
	for t in hints:
		if _polite(t):
			bad.append(t)
	_ok("판 위 줄에 존댓말이 없다", bad.is_empty(),
			"%d줄" % hints.size() if bad.is_empty() else str(bad))
	#  어투가 하나다 — **명사형 「-기」**. 2026-09-24 에 여덟 줄을 「다트판을
	#  눌러 … 결정」으로 모았는데 그것은 어디를 누르라는 입력 지시였고 같은
	#  말이 여섯 번 되풀이됐다. 이 두 줄이 그 되돌이를 막는다.
	var nom := []
	var ins := []
	for t in hints:
		if not t.ends_with("기"):
			nom.append(t)
		if not _banned(t).is_empty():
			ins.append("%s %s" % [t, _banned(t)])
	_ok("판 위 줄이 명사형 「-기」다", nom.is_empty(),
			"%d줄" % hints.size() if nom.is_empty() else str(nom))
	_ok("판 위 줄에 금칙어가 없다", ins.is_empty(),
			"" if ins.is_empty() else str(ins))
	#  상태 이름은 글자가 아니라 그림이 말한다 — 「조준 확인」이 발마다
	#  27프레임씩 떠 있었다. S.CONFIRM 은 빈 줄이라야 한다.
	g.state = g.S.CONFIRM
	var ch_hint := _hint_of(g.S.CONFIRM)
	_ok("확인 구간에는 줄이 없다", ch_hint == "", "「%s」" % ch_hint)
	#  폭 — 가장 긴 줄이 화면 안에 든다
	var wide := ""
	var ww := -1.0
	for t in hints:
		var w := _w(t, 20)
		if w > ww:
			ww = w
			wide = t
	if ww < 0.0:
		_skip("가장 긴 줄이 화면에 든다", "글꼴이 없다(헤드리스)")
	else:
		_ok("가장 긴 줄이 화면에 든다", ww <= HINT_W,
				"「%s」 %.0fpx ≤ %.0f" % [wide, ww, HINT_W])

	# ── ② 다트통 줄 ─────────────────────────────────────
	var pbad := []
	var pempty := []
	for r in GameData.packs():
		var ls: Array = g._pack_lines(r)
		if ls.is_empty():
			pempty.append(String(r.get("name", "")))
		for l in ls:
			if _polite(String(l)):
				pbad.append("%s: %s" % [r.get("name", ""), l])
	_ok("다트통 줄에 존댓말이 없다", pbad.is_empty(),
			"%d통" % GameData.packs().size() if pbad.is_empty() else str(pbad))
	_ok("줄이 빈 다트통이 없다", pempty.is_empty(),
			"" if pempty.is_empty() else str(pempty))
	#  줄글을 비운 다트통은 **표의 열에서** 줄이 나야 한다. 효과가 있는데
	#  줄이 「추가 효과 없음」 하나뿐이면 그 효과가 화면에서 사라진 것이다.
	var mute := []
	for r in GameData.packs():
		var off: bool = int(r.get("darts_add", 0)) != 0 \
				or int(r.get("gold_add", 0)) != 0 \
				or String(r.get("interest_off", "")) != "" \
				or String(r.get("dart_gold", "")) != "" \
				or String(r.get("grant_item", "")) != "" \
				or String(r.get("grant_cons", "")) != "" \
				or String(r.get("grant_fixture", "")) != "" \
				or String(r.get("grant_mod", "")) != "" \
				or (String(r.get("dart_id", "")) != ""
						and String(r.get("dart_id", "")) != "std") \
				or (String(r.get("score", "")) != ""
						and String(r.get("score", "")) != "std") \
				or (String(r.get("score_mul", "")) != ""
						and float(r.get("score_mul", 1.0)) != 1.0) \
				or (String(r.get("item_slots", "")) != ""
						and int(r.get("item_slots", 0)) != GameData.tune_i("max_items")) \
				or (String(r.get("cons_slots", "")) != ""
						and int(r.get("cons_slots", 0)) != GameData.tune_i("cons_slots"))
		var ls2: Array = g._pack_lines(r)
		if off and ls2.size() == 1 and String(ls2[0]) == "추가 효과 없음":
			mute.append(String(r.get("name", "")))
	_ok("효과가 있는데 「추가 효과 없음」인 다트통이 없다", mute.is_empty(),
			"" if mute.is_empty() else str(mute))
	#  ⚠ **빈 칸이 0 으로 생는다.** CSV 의 빈 칸은 「없는 열」이 아니라
	#  「빈 글자」라 .get(기본값) 이 기본값을 안 내고 float("") 은 0.0 이다 —
	#  선물 다트통에 「한 발의 값 0배」가 뗠 적이 있다(2026-09-24).
	#  값이 0 인 효과 줄은 없다 — 없는 효과는 줄을 안 내는 것이 맞다.
	var zero := []
	for r in GameData.packs():
		for l in g._pack_lines(r):
			var t3 := String(l)
			for u in ["0배", "0칸", "0개", "0골드"]:
				if t3.contains(" " + u) or t3.ends_with(u):
					zero.append("%s: %s" % [r.get("name", ""), t3])
					break
	_ok("값이 0 인 효과 줄이 없다", zero.is_empty(),
			"" if zero.is_empty() else str(zero))

	# ── ③ 런 끝 해금 쪽지 ───────────────────────────────
	#  머리와 값이 같은 낱말을 두 번 말하지 않는다 — 「리그 검정 리그」였다.
	var dup := []
	for r in GameData.packs():
		var t: Dictionary = g._unl_tag("다트통", String(r.get("name", "")))
		if String(t.n).contains("다트통") and String(r.get("name", "")) != "다트통":
			dup.append(String(t.n))
	for r in GameData.leagues():
		var t2: Dictionary = g._unl_tag("리그", String(r.get("name", "")))
		if String(t2.n).contains("리그") and String(r.get("name", "")) != "리그":
			dup.append(String(t2.n))
	_ok("해금 쪽지가 겹말이 아니다", dup.is_empty(),
			"" if dup.is_empty() else str(dup))
	#  값이 비면 안 된다 — 뗀 뒤가 비면 이름을 그대로 둔다는 규약.
	var blankt := []
	for r in GameData.packs():
		if String((g._unl_tag("다트통", String(r.get("name", "")))).n).strip_edges() == "":
			blankt.append(String(r.get("name", "")))
	_ok("해금 쪽지의 값이 비지 않는다", blankt.is_empty(),
			"" if blankt.is_empty() else str(blankt))

	# ── ④ 못 사는 까닭 ─────────────────────────────────
	#  칸이 꽉 찬 둘은 **값**이라 태그 줄에 선다. 문장 꼬리가 붙으면 안 된다.
	var t_item: String = g._buy_full_tag({"type": "item"})
	var t_cons: String = g._buy_full_tag({"type": "cons"})
	_ok("슬롯이 꽉 참은 값으로만 말한다",
			not _polite(t_item) and not t_item.ends_with("다")
					and t_item.contains("/"), "「%s」" % t_item)
	_ok("사탕·사진 칸이 꽉 참은 값으로만 말한다",
			not _polite(t_cons) and not t_cons.ends_with("다")
					and t_cons.contains("/"), "「%s」" % t_cons)

	# ── ⑤ 그리는 파일 전수 — 존댓말 글이 한 줄도 없다 ────
	#  ⚠ **위 넷으로는 못 잡는 자리가 있었다.** ①은 _draw_hint 가 내는
	#  state 별 줄과 AIM_HINT 만, ②는 다트통 줄만 훑는다. 그래서 사진
	#  화면이 제 손으로 그리던 「칠할 칸을 고르세요」가 판 위 안내줄을 전부
	#  명사형으로 모은 뒤에도 그대로 남았다(2026-09-25 에 잡았다) — 그
	#  줄은 _photo_draw 안에 있어서 **재는 자리가 애초에 없었다.**
	#
	#  함수를 하나씩 더 적는 길은 안 간다 — 그러면 다음에 새로 그리는
	#  함수가 또 그물 밖에 난다. 파일을 통째로 읽어 **큰따옴표 글 전부**를
	#  본다: 그리는 세 파일 어디에 새 글이 나도 이 자를 지난다.
	#  머리가 # 인 줄(주석)은 건너뛴다 — 무엇이 깨졌는지 적는 우리 주석이
	#  존댓말을 인용하기 때문이다.
	var src_bad := []
	var src_ban := []
	var src_n := 0
	for path in ["res://scripts/game.gd", "res://scripts/dev.gd",
			"res://scripts/data.gd"]:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			_skip("%s 를 읽는다" % path.get_file(), "파일을 못 열었다")
			continue
		var ln := 0
		while not f.eof_reached():
			var line := f.get_line()
			ln += 1
			if line.strip_edges().begins_with("#"):
				continue
			#  콘솔로 나가는 줄은 화면 글이 아니다 — 무엇이 깨졌는지 적는
			#  우리 말이라 용어 사전 밖이다.
			var con := false
			for c in CONSOLE:
				if line.contains(c):
					con = true
					break
			if con:
				continue
			for lit in _lits(line):
				if not _han(lit):
					continue
				src_n += 1
				if _polite(lit):
					src_bad.append("%s:%d 「%s」" % [path.get_file(), ln, lit])
				var bw := _banned(lit)
				if not bw.is_empty():
					src_ban.append("%s:%d 「%s」 %s"
							% [path.get_file(), ln, lit, bw])
		f.close()
	_ok("그리는 파일에 존댓말 글이 없다", src_bad.is_empty(),
			"한글 글 %d개" % src_n if src_bad.is_empty() else str(src_bad))
	_ok("그리는 파일에 금칙어가 없다", src_ban.is_empty(),
			"금칙어 %d갈래" % BANNED.size() if src_ban.is_empty() else str(src_ban))
	#  재는 자리가 실제로 있는지 같이 못 박는다 — 글을 한 개도 안 세고
	#  조용히 통과하면 자가 죽은 것이다.
	_ok("셀 글이 실제로 있다", src_n >= 200, "%d개" % src_n)

	# ── ⑥ 표(data/*.csv)의 사람이 쓴 글 ──────────────────
	#  ⚠ **이 구멍이 2026-09-25 반려의 원인이다.** ⑤ 는 그리는 세 소스의
	#  큰따옴표만 읽어서 data/*.csv 가 통째로 그물 밖이었다 — 배움 글
	#  19줄이 「전부 통과」 밑에서 존댓말로 살아남은 까닭이다. 표를
	#  하나씩 적는 길은 안 간다: GameData.FILES 를 통째로 도므로
	#  **표가 늘어도 이 자를 지난다.**
	var csv_pol := []
	var csv_ban := []
	var csv_dot := []
	var csv_n := 0
	for tbl in GameData.FILES:
		if SKIP_TABLES.has(String(tbl)):
			continue
		for r in GameData.rows(String(tbl)):
			for col in TXT_COLS:
				var t := String(r.get(col, "")).strip_edges()
				if t == "" or not _han(t):
					continue
				csv_n += 1
				var who := "%s:%d/%s 「%s」" % [tbl, r.get("_line", 0), col, t]
				if _polite(t):
					csv_pol.append(who)
				var bw2 := _banned(t)
				if not bw2.is_empty():
					csv_ban.append("%s %s" % [who, bw2])
				#  곁가지는 「 · 」로 잇는다 — 마침표로 이으면 앞도 뒤도 안
				#  읽힌다(aim_text 주석이 2026-09-15 에 세운 집 규칙).
				if _dot_join(t):
					csv_dot.append(who)
	_ok("표 글에 존댓말이 없다", csv_pol.is_empty(),
			"%d칸" % csv_n if csv_pol.is_empty() else str(csv_pol))
	_ok("표 글에 금칙어가 없다", csv_ban.is_empty(),
			"금칙어 %d갈래" % BANNED.size() if csv_ban.is_empty() else str(csv_ban))
	_ok("표 글이 마침표로 문장을 안 잇는다", csv_dot.is_empty(),
			"" if csv_dot.is_empty() else str(csv_dot))
	#  재는 자리가 실제로 있는지 못 박는다 — 표를 한 칸도 안 읽고
	#  조용히 통과하면 이 검사가 죽은 것이다.
	_ok("셀 표 글이 실제로 있다", csv_n >= 150, "%d칸" % csv_n)

	print("\n%s" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d · 건너뜀 %d" % [okn, fail, skip])
	quit(0 if fail == 0 else 1)


#  한 줄에서 큰따옴표 글을 다 뽑는다. 역슬래시 다음 한 글자는 건너뛴다 —
#  그 글자를 버려도 꼬리 판정에는 영향이 없다(오히려 "…합니다\n" 이
#  꼬리를 숨기지 못한다).
func _lits(line: String) -> Array:
	var out := []
	var i := 0
	var n := line.length()
	while i < n:
		if line[i] != '"':
			i += 1
			continue
		var j := i + 1
		var buf := ""
		while j < n:
			var c := line[j]
			if c == "\\":
				j += 2
				continue
			if c == '"':
				break
			buf += c
			j += 1
		out.append(buf)
		i = j + 1
	return out


#  마침표로 문장을 이었나. ⚠ 소수점은 마침표가 아니다 — 「목표 점수 0.7배」
#  같은 값이 수두룩하다. 앞뒤가 둘 다 숫자면 값이고, 아니면 문장을 이은 것이다.
func _dot_join(t: String) -> bool:
	for i in t.length():
		if t[i] != ".":
			continue
		var a := t[i - 1] if i > 0 else ""
		var b := t[i + 1] if i + 1 < t.length() else ""
		if a.is_valid_int() and b.is_valid_int():
			continue
		return true
	return false


#  한글 음절이 한 자라도 있나. 영어 열쇠·경로를 걸러 낸다.
func _han(t: String) -> bool:
	for i in t.length():
		var c := t.unicode_at(i)
		if c >= 0xAC00 and c <= 0xD7A3:
			return true
	return false


#  _draw_hint 의 match 를 자가 읽을 수 있게 같은 표를 여기서 되짚는다.
#  ⚠ 그리는 쪽이 갈래를 늘리면 여기도 늘려야 한다 — 그 어긋남 자체가
#  「화면에 새 글이 났는데 아무도 안 쟀다」는 뜻이다.
func _hint_of(st: int) -> String:
	match st:
		g.S.PICK:
			return "던질 다트 고르기"
		g.S.AIM_V:
			return g._aim_hint(0)
		g.S.AIM_H:
			return g._aim_hint(1)
	return ""
