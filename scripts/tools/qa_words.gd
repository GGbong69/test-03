extends SceneTree

#  사용자 눈에 닿는 글이 **효과와 값만**인가를 잰다.
#    godot --path . --headless --script scripts/tools/qa_words.gd
#
#  사용자가 세 번 반려한 것이 「해설 문장」이다. 그 규칙이 여태 사람 눈으로만
#  지켜졌고, 그래서 다트통 설명 여섯이 존댓말 해설로 남아 있었다(2026-09-24).
#  이 자가 재는 것 넷:
#    ① 판 위 안내줄 · 조준 줄 — 존댓말 없음 · 상태 이름 없음 · 화면 폭 안
#    ② 다트통 줄 — 존댓말 없음. 줄글을 비운 다트통이 **빈 채로 서지 않는다**
#    ③ 런 끝 해금 쪽지 — 머리와 값이 같은 낱말을 두 번 말하지 않는다
#    ④ 못 사는 까닭 — 칸이 꽉 찬 둘은 값(「슬롯 5/5」)이고 문장이 아니다
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
		if t.ends_with(e):
			return true
	return false


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
	_ok("사탕 칸이 꽉 참은 값으로만 말한다",
			not _polite(t_cons) and not t_cons.ends_with("다")
					and t_cons.contains("/"), "「%s」" % t_cons)

	print("\n%s" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d · 건너뜀 %d" % [okn, fail, skip])
	quit(0 if fail == 0 else 1)


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
