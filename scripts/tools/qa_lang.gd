extends SceneTree
# 말(2026-10-13 · GameData.L · data/lang.csv · 표의 *_en · *_ja 열) — 못 박는 것:
#   ① 검증기 — 번역의 자리(%d · %s · {v} …)가 원문과 같다 · 빈 번역 없음
#   ② 코드의 L("…") · _L("…") 글이 영어 · 일본어 짝을 다 갖는다(lang.csv 나 표 옆 열)
#   ③ 고르면 글이 바뀐다 — 코드 글 · 표 이름 · 채운 표 글(_fd) · 수 단위(big) · 조건 글(조사 · fire)
#   ④ 일본어 글자가 글꼴(페이퍼로지 + 메움 갈무리11)에 다 있다
#   ⑤ 띄어쓰기 없는 말을 글자 단위로 접는다 — 폭 안 · 한 자씩 셈(_wrap_gap)이 안 어긋난다
#   ⑥ 설정 「게임」 탭의 「언어」 줄 — ◀ ▶ 가 한국어 → 영어 → 일본어로 돌고 전역 저장에 남는다
#   ⑦ 개발자 모드 「언어」 줄
#   ⑧ 한국어로 돌아오면 원문 그대로(검증기 · 다른 검사가 한국어를 본다)
#   godot --headless --path . --script scripts/tools/qa_lang.gd
const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")
var g = null
var ok := 0
var bad := 0
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_qa_lang_g.cfg"
	Save.path = "user://_qa_lang.cfg"
	Save.prof_fmt = "user://_qa_lang_%d.cfg"
	Save.wipe()
	Save.set_set("lang", "ko")
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if g != null:
		g.set_process(false)
	if busy:
		return false
	busy = true
	_run()
	print("통과 %d · 실패 %d" % [ok, bad])
	GameData.set_lang("ko")
	quit(1 if bad > 0 else 0)
	return false


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-52s %s" % ["통과" if cond else "실패", nm, note])


func _code_strings() -> Array:
	var out := {}
	var re := RegEx.create_from_string("(?<![A-Za-z_])_?L\\(\"((?:[^\"\\\\\\n]|\\\\.)*)\"\\)")
	for p in ["res://scripts/game.gd", "res://scripts/data.gd"]:
		var src := FileAccess.get_file_as_string(p)
		for m in re.search_all(src):
			var s := m.get_string(1)
			if GameData.has_ko(s):
				out[s] = true
	return out.keys()


func _run() -> void:
	# ①
	var errs := []
	for e in GameData.errors():
		if String(e).contains("자리가 원문과 다르다") or String(e).begins_with("lang"):
			errs.append(e)
	_ok("① 번역의 자리가 원문과 같다", errs.is_empty(), str(errs.slice(0, 3)))
	var empty := []
	for w in GameData.warnings():
		if String(w).begins_with("lang"):
			empty.append(w)
	_ok("① 빈 번역 없음", empty.is_empty(), str(empty))

	# ②
	var miss := {"en": [], "ja": []}
	var cs := _code_strings()
	for l in ["en", "ja"]:
		GameData.set_lang(l)
		for s in cs:
			if GameData.L(s) == s:
				miss[l].append(s)
	_ok("② 코드 글 %d개가 영어 짝을 갖는다" % cs.size(), miss.en.is_empty(), str(miss.en.slice(0, 5)))
	_ok("② 코드 글이 일본어 짝을 갖는다", miss.ja.is_empty(), str(miss.ja.slice(0, 5)))
	#  표 글 — name · desc · text · who 의 한국어 칸마다 옆 열
	var tmiss := []
	for tb in GameData._raw:
		if tb == "lang" or tb == "tuning" or String(tb).begins_with("_"):
			continue
		for r in GameData._raw[tb]:
			for c in ["name", "desc", "text", "who"]:
				var v := String(r.get(c, ""))
				if v != "" and GameData.has_ko(v) and (String(r.get(c + "_en", "")) == ""
						or String(r.get(c + "_ja", "")) == ""):
					tmiss.append("%s:%s" % [tb, v])
	_ok("② 표 글의 한국어 칸마다 영어 · 일본어 옆 열", tmiss.is_empty(), str(tmiss.slice(0, 5)))

	# ③
	GameData.set_lang("en")
	_ok("③ 영어 — 코드 글", GameData.L("뒤로") == "Back", GameData.L("뒤로"))
	_ok("③ 영어 — 표 이름(동전)", GameData.L("발라트로의 조커") == "Balatro's Joker")
	_ok("③ 영어 — 표 글(화면 글 열쇠)", GameData.text("tut_skip") == "Skip")
	var cons: Array = GameData.consumables()
	var vc: Dictionary = {}
	for c in cons:
		if String(c.id) == "v_cash":
			vc = c
	_ok("③ 채운 표 글 — 상태는 한국어 · 그리면 영어", not vc.is_empty() and GameData.has_ko(String(vc.d))
			and GameData.L(String(vc.d)).begins_with("Double your Gold"), GameData.L(String(vc.get("d", ""))))
	_ok("③ 영어 — 수 단위(천 단위 M)", GameData.big(12345678) == "12M", GameData.big(12345678))
	_ok("③ 영어 — 칸 번호 조건(조사 없음)", GameData.cond_text("sec:8,16") == "Hit 8·16:", GameData.cond_text("sec:8,16"))
	_ok("③ 영어 — 쌓이는 동전 조건(「~맞히면」 갈래)",
			GameData.cond_text("pair", true) == "Hit one number twice this leg:"
			and GameData.cond_text("pair") == "From the 2nd hit on one number this leg:")
	var nsr: Dictionary = GameData.npc_say("tip")[0]
	_ok("③ 영어 — 상인 귀띔({열쇠} 채움)", not GameData.has_ko(GameData.npc_say_text(nsr))
			and not GameData.npc_say_text(nsr).contains("{"), GameData.npc_say_text(nsr))
	GameData.set_lang("ja")
	_ok("③ 일본어 — 코드 글 · 수 단위(万)", GameData.L("뒤로") == "戻る" and GameData.big(12345678) == "1234万")
	_ok("③ 일본어 — 칸 번호 조건", GameData.cond_text("sec:8,16") == "8·16に当てると", GameData.cond_text("sec:8,16"))

	# ④
	var fb: Font = load(g.FONT_FALLBACK)
	var gone := {}
	var have_pl := 0
	for r in GameData._raw.get("lang", []):
		_chars(String(r.get("ja", "")), fb, gone)
	for tb in GameData._raw:
		for r in GameData._raw[tb]:
			for k in r:
				if String(k).ends_with("_ja"):
					_chars(String(r[k]), fb, gone)
	for ch in "コインスコア倍率":
		if g.font.has_char(ch.unicode_at(0)):
			have_pl += 1
	_ok("④ 일본어 글자가 페이퍼로지 · 갈무리11 에 다 있다", gone.is_empty(), str(gone.keys()))
	_ok("④ 가나 · 상용 한자는 페이퍼로지가 그린다", have_pl == 8)
	_ok("④ 메움 글꼴이 붙었다", g.font.fallbacks.size() > 0 and g.font_sm.fallbacks.size() > 0)

	# ⑤
	var jp := "早くレッグを終えれば残りダーツ1本につき1ゴールド払ってやる"
	var lines: PackedStringArray = g._tutor_wrap(jp, 200.0)
	var wide := false
	for ln in lines:
		if g._tutor_tw(ln) > 200.0:
			wide = true
	_ok("⑤ 띄어쓰기 없는 말 — 글자 단위로 폭 안", lines.size() >= 2 and not wide and "".join(lines) == jp,
			str(lines))
	_ok("⑤ 글자로 끊은 자리는 빈칸을 안 먹는다", g._wrap_gap(jp, lines, 0) == 0)
	var kr := "판을 일찍 끝내면 남은 다트 한 발에 골드씩 쳐 주지"
	var kl: PackedStringArray = g._tutor_wrap(kr, 200.0)
	_ok("⑤ 낱말 사이에서 끊으면 빈칸 하나", kl.size() >= 2 and g._wrap_gap(kr, kl, 0) == 1)

	# ⑥
	GameData.set_lang("ko")
	_ok("⑥ 설정 탭 셋 — 화면 · 소리 · 게임", (g.SET_TABS as Array) == ["screen", "sound", "game"])
	_ok("⑥ 게임 탭은 「언어」 한 줄 · 뒤로", (g._set_info("game").kids as Array) == ["lang"])
	var seq := []
	for i in 3:
		g._lang_step(1)
		seq.append(GameData.lang)
	_ok("⑥ ▶ 가 영어 → 일본어 → 한국어로 돈다", seq == ["en", "ja", "ko"], str(seq))
	g._lang_step(-1)
	_ok("⑥ ◀ 는 거꾸로 · 전역 저장에 남는다", GameData.lang == "ja"
			and String(Save.get_set("lang", "")) == "ja")
	_ok("⑥ 값은 그 말 자신의 글", String(g._set_info("lang").get("v", "")) == "日本語")

	# ⑦
	var dsrc := FileAccess.get_file_as_string("res://scripts/dev.gd")
	_ok("⑦ 개발자 모드 「언어」 줄", dsrc.contains("\"a\": \"lang\"") and dsrc.contains("g._lang_step(1)"))

	# ⑧
	g._lang_step(1)
	_ok("⑧ 한국어로 돌아오면 원문 그대로", GameData.lang == "ko" and GameData.L("뒤로") == "뒤로"
			and GameData.cond_text("sec:8,16") == "8·16을 맞히면" and GameData.big(12345678) == "1234만")


func _chars(s: String, fb: Font, gone: Dictionary) -> void:
	for i in s.length():
		var u := s.unicode_at(i)
		if u < 0x80:
			continue
		if not g.font.has_char(u) and not fb.has_char(u):
			gone[s[i]] = true
