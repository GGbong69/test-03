extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  챌린지 고르는 길 — 새 런 화면의 탭 한 쌍
#
#  실행:  godot --headless --path . --script scripts/tools/qa_chalpick.gd
#  종료 코드 = 실패 개수
#
#  효과 일곱은 qa_chal 이 이미 잰다. 여기서 재는 것은 **고르는 길**과
#  그 길이 만든 새 경우다 — 여태 GameData.challenge 를 세우는 게임 코드가
#  0줄이었으므로 일곱은 「한 번도 플레이어가 켜 본 적이 없는 코드」다.
#
#  ⚠ **글자를 한 자도 새로 안 썼다**는 것이 이 검사의 둘째 단언이다.
#  목록의 이름·효과가 challenges.csv 의 name · desc 와 글자 단위로 같아야
#  한다 — 기획서 P.16 일곱 줄이 이미 「제약 · 보상」 한 쌍의 꼴이다.
# ══════════════════════════════════════════════════════════

var g = null
var fails := 0
var done := false


func _initialize() -> void:
	Save.path = "user://_qa_chalpick.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(nm: String, cond: bool, detail := "") -> void:
	print("  %s %-48s %s" % ["OK  " if cond else "실패", nm, detail])
	if not cond:
		fails += 1


func _key(code: int) -> void:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	g._unhandled_input(e)


func _raw_rows() -> Array:
	var out := []
	for r in GameData.rows("chal"):
		if String(r.get("id", "")) == "none":
			continue
		out.append(r)
	return out


func _process(_d: float) -> bool:
	if done:
		return false
	done = true
	for i in 8:
		g._process(1.0 / 60.0)
	g._autoplay = false
	GameData.challenge = ""
	GameData.endless = false

	print("챌린지 고르는 길\n")

	# ── ① 잠금 ────────────────────────────────────────────
	print("① 잠금 — 완주 한 번")
	Save.wipe()
	_ok("완주 0 이면 잠겨 있다", not g._chal_unlocked(),
			"완주 %d" % Save.stat("wins"))
	g._open_newrun()
	g._click(g._nr_tab(1).get_center())
	_ok("잠긴 탭을 눌러도 안 열린다", g.newrun_tab == 0, "탭 %d" % g.newrun_tab)
	_ok("거절이 울었다", g.deny_flash > 0.0)
	Save.bump("wins")
	_ok("완주 1 이면 열린다", g._chal_unlocked())

	# ── ② 표의 글자 그대로 ────────────────────────────────
	print("\n② 목록 — 새로 쓴 글이 한 자도 없다")
	var raw := _raw_rows()
	var lst: Array = g._chal_list()
	_ok("줄이 일곱이다(「없음」은 줄이 아니라 탭이다)", lst.size() == 7,
			"%d줄" % lst.size())
	var same := true
	var bad := ""
	for i in mini(lst.size(), raw.size()):
		if String(lst[i].n) != String(raw[i].get("name", "")) \
				or String(lst[i].d) != String(raw[i].get("desc", "")):
			same = false
			bad = String(lst[i].n)
	_ok("이름·효과가 표와 글자 단위로 같다", same, bad)
	var names := []
	for c in lst:
		names.append(String(c.n))
	print("     %s" % str(names))
	#  본문에 해설이 안 섞였는가 — desc 는 「제약 · 보상」 한 쌍이다
	var pairs := true
	for c in lst:
		if String(c.d).split(" · ", false).size() != 2:
			pairs = false
	_ok("효과가 「제약 · 보상」 두 토막이다", pairs)

	# ── ③ 탭이 곧 고름이다 ────────────────────────────────
	print("\n③ 고르기")
	g._open_newrun()
	_ok("화면이 기본 탭으로 열린다", g.newrun_tab == 0)
	_ok("기본 탭이 곧 「없음」이다", GameData.challenge == "",
			"'%s'" % GameData.challenge)
	var keep_pack := String(GameData.packs()[2].get("id", ""))
	GameData.pack = keep_pack
	GameData.league = String(GameData.leagues()[0].get("id", ""))
	g._click(g._nr_tab(1).get_center())
	_ok("탭이 열렸다", g.newrun_tab == 1)
	#  ⚠ 「탭에 들어왔는데 아무것도 안 골라진 상태」를 안 만든다
	_ok("첫 줄이 곧장 골라진 채로 선다",
			GameData.challenge == String(lst[0].id),
			"'%s'" % GameData.challenge)
	for i in lst.size():
		g._click(g._chal_row(i).get_center())
		if GameData.challenge != String(lst[i].id):
			_ok("줄 %d 을 누르면 그 id 다" % i, false, GameData.challenge)
			break
	_ok("일곱 줄이 저마다 제 id 를 세운다",
			GameData.challenge == String(lst[lst.size() - 1].id),
			GameData.challenge)
	#  휠도 같은 자를 쓴다
	var was: int = g.newrun_chal
	g._wheel(Vector2(320.0, 180.0), -1)
	_ok("휠이 줄 고름을 옮긴다", g.newrun_chal != was,
			"%d → %d" % [was, g.newrun_chal])
	g._click(g._nr_tab(0).get_center())
	_ok("기본 탭으로 가면 지워진다", GameData.challenge == "",
			"'%s'" % GameData.challenge)
	_ok("다트통이 되돌아온다", GameData.pack == keep_pack, GameData.pack)

	# ── ④ 챌린지 런은 다트통·리그을 안 고른다 ─────────────
	print("\n④ 변수를 하나로 줄인다")
	GameData.pack = keep_pack
	g._click(g._nr_tab(1).get_center())
	_ok("다트통이 표의 첫 행이다",
			GameData.pack == String(GameData.packs()[0].get("id", "")),
			GameData.pack)
	_ok("리그이 표의 첫 행이다",
			GameData.league == String(GameData.leagues()[0].get("id", "")),
			GameData.league)
	_ok("그 첫 행은 늘 열려 있다", g._pack_open(0) and g._league_open(0))

	# ── ④-b 탭을 나가는 문 셋 ─────────────────────────────
	#  ⚠ **못 박은 값이 사람의 고름을 덮으면 안 된다.** 탭 1 은 다트통·리그을
	#  표 첫 행으로 못 박고 참값을 newrun_keep 에만 둔다. 되돌리는 자리가
	#  _nr_tab_set(0) 하나뿐이었을 때는 「뒤로」·ESC·「시작」 셋이 그 함수를
	#  안 지나서, 탭을 **한 번 스치기만 해도** 고른 통이 base/white 로 굳은
	#  채 _open_newrun 의 _pack_save() 에 실려 디스크에 앉았다 — 저장에서 다시
	#  읽는 자리가 부팅과 프로필 교체 둘뿐이라 **되돌릴 길이 없다.**
	#  최댓값과 같은 종류의 사고다. 2026-09-20
	print("\n④-b 탭을 나가도 고른 통이 산다")
	var p2 := String(GameData.packs()[2].get("id", ""))
	var l2 := String(GameData.leagues()[0].get("id", ""))
	for way in ["뒤로", "ESC", "런"]:
		Save.set_pick("pack", p2)
		Save.set_pick("league", l2)
		g._open_newrun()
		GameData.pack = p2
		GameData.league = l2
		g.newrun_pip = 2
		g._click(g._nr_tab(1).get_center())
		if way == "뒤로":
			g._click(g._newrun_back().get_center())
		elif way == "ESC":
			_key(KEY_ESCAPE)
		else:
			#  챌린지 런을 한 판 하고 나온 길 — 런이 끝나면 「새 런」이
			#  _open_newrun 으로 돌아온다.
			g._new_run()
		_ok("%s — 디스크의 다트통이 안 덮인다" % way,
				String(Save.get_pick("pack", "")) == p2,
				String(Save.get_pick("pack", "")))
		_ok("%s — 디스크의 리그이 안 덮인다" % way,
				String(Save.get_pick("league", "")) == l2,
				String(Save.get_pick("league", "")))
		#  로비를 다시 열어도 앉히는 것은 사람이 고른 쪽이다
		g._open_newrun()
		_ok("%s — 로비를 다시 열어도 그 통이다" % way,
				GameData.pack == p2 and String(Save.get_pick("pack", "")) == p2,
				"%s / %s" % [GameData.pack, String(Save.get_pick("pack", ""))])
		_ok("%s — 탭이 기본으로 돌아온다" % way, g.newrun_tab == 0,
				"탭 %d" % g.newrun_tab)

	# ── ⑤ 자리 ────────────────────────────────────────────
	print("\n⑤ 자리 — 겹치지 않는가 · 손가락에 드는가")
	var rects := {
		"탭0": g._nr_tab(0), "탭1": g._nr_tab(1),
		"시작": g._newrun_go(), "뒤로": g._newrun_back(),
	}
	for i in lst.size():
		rects["줄%d" % i] = g._chal_row(i)
	var keys := rects.keys()
	var over := ""
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: Rect2 = rects[keys[i]]
			var b: Rect2 = rects[keys[j]]
			if a.intersects(b):
				over = "%s x %s" % [keys[i], keys[j]]
	_ok("서로 한 픽셀도 안 겹친다", over == "", over)
	var outside := ""
	var small := ""
	for k in keys:
		var r: Rect2 = rects[k]
		if r.position.x < 0.0 or r.position.y < 0.0 \
				or r.end.x > 640.0 or r.end.y > 352.0:
			outside = k
		if r.size.x < 56.0 or r.size.y < 20.0:
			small = k
	_ok("전부 화면(y0~352) 안이다", outside == "", outside)
	_ok("전부 56x20 을 넘는다(모바일)", small == "", small)
	#  머리글 잉크(x16~111)와 안 겹친다
	_ok("탭이 머리글 잉크와 안 겹친다", g._nr_tab(0).position.x > 111.0,
			"탭 x %.0f" % g._nr_tab(0).position.x)
	#  「시작」·「뒤로」가 안 움직였다
	_ok("「시작」이 제자리다", g._newrun_go() == Rect2(236.0, 316.0, 168.0, 34.0))
	_ok("「뒤로」가 제자리다", g._newrun_back() == Rect2(44.0, 318.0, 88.0, 30.0))

	# ── ⑥ 「시작」의 문은 하나다 ──────────────────────────
	print("\n⑥ 문 하나")
	#  ⚠ 푸는 검사(확정 단추 밖이면 겨눔이 풀린다)가 표적보다 먼저 선다
	g.start_arm = true
	g._click(g._chal_row(2).get_center())
	_ok("확정 단추 밖을 누르면 겨눔이 풀린다", not g.start_arm)
	#  이어할 것이 없으면 겨눔이 아예 안 선다 — 한 번 누름 그대로다
	Save.run_drop()
	_ok("이어할 것이 없으면 _start_go 가 곧장 참이다", g._start_go())

	# ── ⑦ 툴팁 ────────────────────────────────────────────
	print("
⑦ 툴팁 — 본문은 제목과 효과만, 곁말은 태그 줄에")
	g._open_newrun()
	g._click(g._nr_tab(1).get_center())
	var hit: Dictionary = g._tip_hit(g._chal_row(4).get_center())
	_ok("줄이 잡힌다", String(hit.get("k", "")) == "chal"
			and int(hit.get("i", -1)) == 4, str(hit))
	g._tip_build(hit)
	_ok("제목이 그 이름이다", g.tip_title == String(lst[4].n), g.tip_title)
	_ok("본문이 제약 / 보상 **두 줄**이다", g.tip_lines.size() == 2,
			"%d줄" % g.tip_lines.size())
	var tt := []
	for t in g.tip_tags:
		tt.append(String((t as Dictionary).get("t", "")))
	_ok("태그가 [챌린지] 하나다", tt == ["챌린지"], str(tt))
	g._click(g._nr_tab(0).get_center())
	_ok("기본 탭에서 목록 자리를 짚어도 빈손이다",
			g._tip_hit(g._chal_row(4).get_center()).is_empty(),
			str(g._tip_hit(g._chal_row(4).get_center())))

	# ── ⑧ 클리어 표시 ─────────────────────────────────────
	print("\n⑧ 클리어 표시 — 목록이 곧 해금 표다")
	var cid := String(lst[3].id)
	_ok("아직 안 깼다", not Save.unlocked("chal:" + cid))
	GameData.challenge = cid
	g._chal_win_mark()
	_ok("완주 표시가 선다", Save.unlocked("chal:" + cid))
	_ok("다른 줄에는 안 선다", not Save.unlocked("chal:" + String(lst[4].id)))
	GameData.challenge = ""
	g._chal_win_mark()
	_ok("챌린지 없는 런은 아무 표시도 안 남긴다",
			Save.unlocked_of("chal").size() == 1,
			"%d개" % Save.unlocked_of("chal").size())

	print("\n%s" % ("전부 통과" if fails == 0 else "실패 %d건" % fails))
	quit(mini(fails, 125))
	return true
