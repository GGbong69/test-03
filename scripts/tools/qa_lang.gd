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
#   ⑨ 길이 — 말 셋마다 고정 칸에 든다(2026-10-13 「다른 언어로 하면 길이가 달라지면서 이상해지는 부분
#      꼼꼼히 체크해」): 판 단추 · 설정 줄 이름 · 설정 탭 · 제목 칠판 프로필 · 챌린지 줄 · 상인의 말 두 줄 ·
#      튜토리얼 말상자 · 막는 말 한 줄 · 런 정보 탭 · 트랙 「판 숫자」 칸 · 컬렉션 탭 · 툴팁 접기
#      (줄머리 금지 글자 · 글자로 끊은 끝줄 한두 자)
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
	#  부호(、。！？％～) 말고는 페이퍼로지 — 메움 글꼴(도트)로 그린 한자가 이름 한가운데 섞이면 결이
	#  갈린다(「天秤」의 秤 · 「オーク樽」의 樽가 그랬다 — 가나로 썼다).
	var mixed := {}
	for r in GameData._raw.get("lang", []):
		_pl_only(String(r.get("ja", "")), mixed)
	for tb in GameData._raw:
		for r in GameData._raw[tb]:
			for k in r:
				if String(k).ends_with("_ja"):
					_pl_only(String(r[k]), mixed)
	_ok("④ 부호 말고는 페이퍼로지 한 글꼴", mixed.is_empty(), str(mixed.keys()))
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
	_ok("⑧ 자리 꼬리표(§) — 한국어로는 앞까지만", GameData.L("완주§통계") == "완주")

	# ⑨
	for l in ["ko", "en", "ja"]:
		GameData.set_lang(l)
		_fit(l)
	GameData.set_lang("ko")


func _w(s: String, sz: int) -> float:
	var f: Font = g.font_sm if sz == 20 else g.font
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x


func _fit(l: String) -> void:
	var L := func(s: String) -> String: return GameData.L(s)
	#  판 단추 — 이름 20 이 단추 몸 안(양옆 8)
	var bad := []
	for p in [[g._leg_go(), "던진다"], [g._leg_skip(), "건너뛴다"], [g._leg_skip(), "못 건너뛴다"],
			[g._reroll_rect(), "리롤"], [g._next_rect(), "다음 판 →"],
			[Rect2(232, 290, 176, 42), "상점으로"]]:
		if _w(L.call(p[1]), 20) > (p[0] as Rect2).size.x - 16.0:
			bad.append(L.call(p[1]))
	_ok("⑨ %s 판 단추 이름이 단추 안" % l, bad.is_empty(), str(bad))
	#  설정 — 게이지 · ◀ ▶ 줄 이름은 이름 칸(홈 앞 8) · 켬끔 줄 이름은 [끔|켬] 앞 8 · 탭 이름(그림 9 · 양옆 6)
	bad = []
	g.state = g.S.SETTINGS
	g.pause_from = -1
	for tab in g.SET_TABS:
		g.set_page = tab
		var rows: Array = g._set_rows()
		for i in rows.size():
			var key := String(rows[i])
			if key == "back":
				continue
			var inf: Dictionary = g._set_info(key)
			var nm: String = L.call(String(inf.get("n", key)))
			var r: Rect2 = g._set_rect(i)
			var lim: float = float(g.SETW.name_w) - 8.0
			if inf.has("tg"):
				lim = (g._set_seg_rect(i, 0) as Rect2).position.x - r.position.x - 8.0
			elif bool(inf.get("go", false)):
				lim = r.size.x - 24.0          # 끝의 「›」 앞
			if 10.0 + _w(nm, 20) > lim:
				bad.append(nm)
		var t := (g.SET_TABS as Array).find(tab)
		var tnm: String = L.call(String(g._set_info(tab).get("n", tab)))
		if _w(tnm, 20) + 9.0 + 12.0 > (g._set_tab_rect(t) as Rect2).size.x:
			bad.append("탭 " + tnm)
	g.state = g.S.TITLE
	_ok("⑨ %s 설정 줄 · 탭 이름이 제 칸 안" % l, bad.is_empty(), str(bad))
	#  제목 칠판 프로필 — 칸 셋 앞(번호가 안 들면 뗀다 — _prof_chalk_draw 와 같은 셈)
	var room: float = float(g.DOORT.row_w) - 3.0 * float(g.PROFB.pip) - 2.0 * float(g.PROFB.pip_gap) - 6.0 - 18.0
	var pt: String = L.call("프로필 %d") % 3
	if _w(pt, 20) > room:
		pt = L.call("프로필")
	_ok("⑨ %s 제목 칠판 프로필이 칸 셋 앞" % l, _w(pt, 20) <= room, "%s %.0f/%.0f" % [pt, _w(pt, 20), room])
	#  챌린지 — 이름 칸(가장 긴 이름) 뒤 효과 줄이 판 안(오른끝 x584)
	var nw := 96.0
	for c in GameData.challenges():
		nw = maxf(nw, _w(L.call(String(c.get("n", ""))), 20) + 8.0)
	bad = []
	for c in GameData.challenges():
		if _w(L.call(String(c.get("d", ""))), 12) > 576.0 - nw:
			bad.append(c.get("id", ""))
	_ok("⑨ %s 챌린지 효과 줄이 판 안" % l, bad.is_empty() and nw < 200.0, "이름 칸 %.0f %s" % [nw, bad])
	#  상인의 말 — 두 줄 안
	bad = []
	for wh in GameData.NPC_SAY_WHEN:
		for r in GameData.npc_say(wh):
			g.nsay_row = r
			g.nsay_txt = GameData.npc_say_text(r)
			if (g._nsay_layout()[1] as PackedStringArray).size() > 2:
				bad.append(r.id)
	g.nsay_row = {}
	_ok("⑨ %s 상인의 말이 두 줄 안" % l, bad.is_empty(), str(bad))
	#  튜토리얼 — 석 줄 안 · 줄머리 금지 글자 없음 · 끝줄이 한두 자로 홀로 안 남음
	bad = []
	var iw: float = float(g.TUTOR.box_w) - float(g.TUTOR.box_pad) * 2.0
	for r in GameData.tutor():
		var lines: PackedStringArray = g._tutor_wrap(L.call(String(r.get("text", ""))), iw)
		if lines.size() > 3 or not _lines_ok(lines):
			bad.append("%s %s" % [r.get("id", ""), lines])
	_ok("⑨ %s 튜토리얼 말상자 줄" % l, bad.is_empty(), str(bad))
	#  막는 말 — 상점 밑줄 한 칸
	bad = []
	for s in ["없는 매물", "이미 샀다", "이 팩에서 고를 몫을 다 썼다", "바꿀 표준 다트가 없다",
			"사탕·사진 칸이 꽉 찼다", "테이블 물건만 산다", "반대쪽 창구다", "가진 것만 판다",
			"먼저 테이블에서 동전을 고른다", "먼저 판에서 팔 동전을 고른다", "먼저 테이블에서 살 물건을 고른다",
			"동전 슬롯이 꽉 찼다", "골드가 부족하거나 슬롯이 꽉 찼다", "다음 보스 판이 없다", "손에 동전이 없다",
			"첫 다트가 꽂힌 뒤에 쓴다", "이미 무효인 보스다", "아직 준비 중이다", "부술 것이 없다", "상점에서만",
			"움직임을 껐다", "진열대가 없다", "상인이 바쁘다", "판 고르기에서만", "3D 손이 없다"]:
		if _w(L.call(s), 12) > float(g.PAYW):
			bad.append(L.call(s))
	if _w(L.call("골드가 %d 모자란다") % 99, 12) > float(g.PAYW):
		bad.append("골드가 %d 모자란다")
	_ok("⑨ %s 막는 말이 한 줄(%d) 안" % [l, int(g.PAYW)], bad.is_empty(), str(bad))
	#  런 정보 — 탭(20) · 트랙의 「판 숫자」(점수 칸 · 배수 앞 6)
	bad = []
	for t in g.RI_TABS.size():
		if _w(L.call(String(g.RI_TABS[t])), 20) > (g._ri_tab_rect(t) as Rect2).size.x - 8.0:
			bad.append(L.call(String(g.RI_TABS[t])))
	if _w(L.call("판 숫자"), 20) > float(g.RI_TRK.mult) - float(g.RI_TRK.score) - 6.0:
		bad.append(L.call("판 숫자"))
	_ok("⑨ %s 런 정보 탭 · 트랙 칸" % l, bad.is_empty(), str(bad))
	#  컬렉션 탭 — 「이름 수/수」 12 가 탭 안
	bad = []
	for t in g.COL_TABS.size():
		var cn: int = (g._col_rows(t) as Array).size()
		var lab := "%s %d/%d" % [L.call(String(g.COL_TABS[t].n)), cn, cn]
		if _w(lab, 12) > (g._col_tab_rect(t) as Rect2).size.x - 6.0:
			bad.append(lab)
	_ok("⑨ %s 컬렉션 탭 글이 탭 안" % l, bad.is_empty(), str(bad))
	#  툴팁 접기 — 동전 효과 · 표 글(설명)마다
	bad = []
	var tw: float = float(g.TIP.w) - float(g.TIP.pad) * 2.0
	var texts := []
	for it in GameData.items():
		texts.append(g._tip_eff(it))
	for tb in ["cons", "mods", "darts", "modifiers", "tags", "boosters", "events"]:
		for r in GameData._raw.get(tb, []):
			texts.append(L.call(String(r.get("desc", ""))))
	for s in texts:
		if s == "":
			continue
		var wr: PackedStringArray = g._tip_wrap(s, tw, 20)
		if not _lines_ok(wr):
			bad.append(str(wr))
	_ok("⑨ %s 툴팁 줄 — 줄머리 금지 글자 · 홀로 남은 한두 자 없음" % l, bad.is_empty(), str(bad.slice(0, 3)))


#  줄머리에 못 오는 글자가 없고, 가타카나 낱말이 두 줄로 안 갈렸고(「アイテ / ム」), 끝줄이 한두 자로
#  홀로 남지 않았다(한 줄이면 그대로 된다).
func _lines_ok(lines: PackedStringArray) -> bool:
	for i in range(1, lines.size()):
		var ln := String(lines[i])
		if ln != "" and String(g.JPW.head).contains(ln[0]):
			return false
		var pv := String(lines[i - 1])
		if ln != "" and pv != "" and g._kata_run(pv + ln, pv.length()):
			return false
	var n := lines.size()
	return n < 2 or String(lines[n - 1]).strip_edges().length() > 2


func _pl_only(s: String, out: Dictionary) -> void:
	for i in s.length():
		var u := s.unicode_at(i)
		if u >= 0x80 and not "、。！？％～".contains(s[i]) and not g.font.has_char(u):
			out[s[i]] = true


func _chars(s: String, fb: Font, gone: Dictionary) -> void:
	for i in s.length():
		var u := s.unicode_at(i)
		if u < 0x80:
			continue
		if not g.font.has_char(u) and not fb.has_char(u):
			gone[s[i]] = true
