extends SceneTree

# ══════════════════════════════════════════════════════════
#  발견 검사 — 컬렉션이 「처음 내 판에 들어온 것」만 세는가
#
#  godot --path . --headless --script scripts/tools/qa_found.gd
#  종료 코드 = 실패 개수
#
#  이 자가 못 박는 것 넷:
#    ① 여섯 탭이 표 전량을 알고, 발견은 그 위를 덮는다 (0 / N 에서 시작)
#    ② 기록하는 문 열넷이 **각자 제 탭만** 올린다
#    ③ 발견이 **팩 풀을 한 칸도 안 움직인다** — 규칙 6 이 여기서 끝난다
#    ④ 이주는 한 번만 돌고, 「발견 전부 잠그기」가 그 빗장을 다시 세운다
#
#  ⚠ 사람의 저장을 안 만진다 — Save.path 를 제 자리로 박는다(save.gd 의 규약).
#  2026-09-19
# ══════════════════════════════════════════════════════════

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

const PATH := "user://_qa_found.cfg"

var g = null
var okn := 0
var fail := 0
var done := false


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-44s %s" % ["통과" if c else "실패", n, d])


func _initialize() -> void:
	Save.gpath = "user://_qa_found_g.cfg"
	Save.path = PATH
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _process(_d: float) -> bool:
	if done:
		return true
	done = true
	_run()
	print("\n통과 %d · 실패 %d" % [okn, fail])
	quit(mini(fail, 125))
	return true


# ── 도우미 ──────────────────────────────────────────────
func _n(t: int) -> int:
	return g._col_found_n(t)


#  여섯 탭을 한 줄로. 「무엇만 늘었나」를 한 번에 잰다.
func _six() -> Array:
	var out := []
	for t in 6:
		out.append(_n(t))
	return out


func _wipe_found() -> void:
	g._dev_unlock_off()
	Save.unfound_all()


#  상점 한 칸을 만들어 진짜 _buy 를 지난다. 값을 직접 박으면 「이 문이
#  발견을 적는가」가 안 잡힌다 — dev_probe 가 좌표를 만드는 그 까닭이다.
func _buy_one(tp: String, d: Dictionary) -> void:
	g.gold = 9999
	g.stock = [{"type": tp, "cost": 0, "d": d, "sold": false}]
	g.buy_sel = -1
	g.sell_sel = -1
	g._buy(0)


#  다트통은 GameData 의 static 이 쥔다(_new_run 이 pack_row() 로 읽는다).
func _fresh_run(pack := "") -> void:
	if pack != "":
		GameData.pack = pack
	g._new_run()
	g._swap_skip()


# ══════════════════════════════════════════════════════════
func _run() -> void:
	print("\n발견 검사 — 못 본 것은 물음표 원반\n")

	_tables()
	_start_empty()
	_doors()
	_cons_share()
	_darts()
	_modf()
	_dev_given()
	_pack_pool()
	_contracts()
	_disk()
	_migrate()


# ── ① 표 여섯과 id 유일성 ────────────────────────────────
func _tables() -> void:
	print("── 표 ──────────────────────────────────────")
	var want := [69, 12, 4, 5, 9, 10]
	var got := []
	for t in 6:
		got.append(g._col_rows(t).size())
	_ok("여섯 표의 수", got == want, "%s (합 %d)" % [str(got), _sum(got)])

	#  **접두사를 나눠 쓰는 사탕·사진이 안 부딪히려면 id 가 유일해야 한다.**
	#  탭 열쇠가 아니라 id 로 적는 설계가 여기에 기대고 있다.
	var seen := {}
	var dup := PackedStringArray()
	for t in 6:
		for r in g._col_rows(t):
			var id := String(r.get("id", ""))
			if seen.has(id) and int(seen[id]) != t:
				#  사탕/사진은 같은 표를 갈라 쓰므로 자기들끼리는 안 겹친다
				dup.append(id)
			seen[id] = t
	_ok("여섯 표의 id 가 전부 유일하다", dup.is_empty(),
			"%d개 · 겹침 %s" % [seen.size(), "없음" if dup.is_empty() else ", ".join(dup)])


func _sum(a: Array) -> int:
	var s := 0
	for v in a:
		s += int(v)
	return s


# ── ② 빈 프로필은 0 / N ─────────────────────────────────
func _start_empty() -> void:
	print("── 빈 프로필 ───────────────────────────────")
	_wipe_found()
	_ok("여섯 탭이 전부 0", _six() == [0, 0, 0, 0, 0, 0], str(_six()))
	#  **자리가 안 줄어든다** — 쪽 수는 표가 낸다
	g.collect_tab = 0
	_ok("동전 3쪽 그대로", g._col_pages() == 3, "%d쪽" % g._col_pages())


# ── ③ 기록하는 문마다 제 탭만 올린다 ────────────────────
func _doors() -> void:
	print("── 기록하는 문 ─────────────────────────────")
	_fresh_run()
	_wipe_found()

	#  동전 — _buy "item"
	var before := _six()
	_buy_one("item", (GameData.items()[3] as Dictionary).duplicate())
	_ok("_buy 동전 → 동전만 1", _only(before, 0, 1), "%s → %s" % [str(before), str(_six())])

	#  보드 확장 — _buy "mod" 가 _apply_mod 로 간다
	before = _six()
	var md: Dictionary = GameData.mods()[1]
	_buy_one("mod", md.duplicate())
	_ok("_buy 보드 확장 → 보드 확장만 1", _only(before, 1, 1),
			"%s → %s" % [str(before), str(_six())])

	#  다트 — _buy "dart"
	before = _six()
	var dt := _dart_of("hvy")
	if not dt.is_empty():
		_buy_one("dart", dt.duplicate())
	_ok("_buy 다트 → 다트만 1", _only(before, 2, 1), "%s → %s" % [str(before), str(_six())])

	#  사탕 — _buy "cons"
	g.cons.clear()
	before = _six()
	_buy_one("cons", (GameData.candies()[0] as Dictionary).duplicate())
	_ok("_buy 사탕 → 사탕만 1", _only(before, 3, 1), "%s → %s" % [str(before), str(_six())])

	#  사진 — _buy "fix"
	g.cons.clear()
	before = _six()
	_buy_one("fix", (GameData.fixtures()[0] as Dictionary).duplicate())
	_ok("_buy 사진 → 사진만 1", _only(before, 4, 1), "%s → %s" % [str(before), str(_six())])

	#  뱃지가 쥐여 주는 사탕 — _take_cons
	g.cons.clear()
	before = _six()
	g._take_cons([(GameData.candies()[1] as Dictionary)], 1, "칸이 꽉 찼다")
	_ok("_take_cons → 사탕만 1", _only(before, 3, 1), "%s → %s" % [str(before), str(_six())])

	#  마릴린 딥틱 복제 — 이미 든 장이라 수가 안 늘어야 한다(같은 id)
	before = _six()
	if not g.owned.is_empty():
		g._photo_apply("clone", 0)
	_ok("복제는 같은 id 라 수가 그대로", _six() == before,
			"%s → %s" % [str(before), str(_six())])


#  탭 tab 만 d 만큼 늘었는가
func _only(before: Array, tab: int, d: int) -> bool:
	var now := _six()
	for t in 6:
		var want: int = int(before[t]) + (d if t == tab else 0)
		if int(now[t]) != want:
			return false
	return true


func _dart_of(id: String) -> Dictionary:
	for d in GameData.darts():
		if String(d.get("id", "")) == id:
			return d
	return {}


# ── ④ 사탕과 사진이 접두사를 나눠 쓴다 ──────────────────
#  ⚠ 「구성 VIII」의 id 가 c_again 인데 **사진 탭**이다 — 이름으로 갈랐으면
#  여기서 죽었을 자리다(data.gd 의 is_fixture 가 그래서 있다).
func _cons_share() -> void:
	print("── 사탕 · 사진 ─────────────────────────────")
	_wipe_found()
	var ag := GameData.fixture_of("c_again")
	_ok("c_again 이 사진 표에 있다", not ag.is_empty(), "id c_again")
	g.cons.clear()
	_buy_one("fix", ag.duplicate())
	_ok("c_ 로 시작해도 사진 탭이 오른다", _n(4) == 1 and _n(3) == 0,
			"사탕 %d · 사진 %d" % [_n(3), _n(4)])
	#  같은 접두사 하나로 적힌다
	var keys := Save.found_of("cons")
	_ok("열쇠는 cons: 하나다", keys.size() == 1 and String(keys[0]) == "c_again",
			"%s" % str(keys))


# ── ⑤ 다트통이 쥐여 준 다트 ─────────────────────────────
func _darts() -> void:
	print("── 다트통 ──────────────────────────────────")
	for pair in [["base", "std"], ["p_iron", "hvy"], ["p_lgt", "lgt"], ["p_mgn", "mag"]]:
		_wipe_found()
		_fresh_run(String(pair[0]))
		var want := String(pair[1])
		var got := Save.found_of("dart")
		_ok("%s 로 새 런 → dart:%s" % [pair[0], want],
				got.size() == 1 and String(got[0]) == want, str(got))
	#  ⚠ 다트통이 쥐여 준 것도 저절로 선다 — p_gift 는 사진과 사탕을 쥔다
	_wipe_found()
	_fresh_run("p_gift")
	var cs := Save.found_of("cons")
	_ok("p_gift 가 쥐여 준 둘이 선다", cs.size() == 2,
			"%s · 사탕 %d · 사진 %d" % [str(cs), _n(3), _n(4)])
	_fresh_run("base")


# ── ⑥ 제약은 판에 걸린 순간 ─────────────────────────────
func _modf() -> void:
	print("── 제약 ────────────────────────────────────")
	_fresh_run()
	_wipe_found()
	var bn := _first_boss()
	g.leg_no = bn
	g.boss_void.clear()
	g._begin_leg()
	var on: int = (g.active_mods as Array).size()
	_ok("보스 판이 서면 걸린 만큼 선다", on > 0 and _n(5) == on,
			"걸린 %d · 제약 탭 %d" % [on, _n(5)])
	_ok("제약 말고는 안 는다", _six()[0] == 0 and _six()[1] == 0,
			str(_six()))

	#  GOOD AFTERNOON — 무효된 보스의 제약은 **안 세어진다**
	_fresh_run()
	_wipe_found()
	g.leg_no = bn
	g.boss_void.clear()
	g.boss_void[bn] = true
	g._begin_leg()
	_ok("무효된 보스는 제약을 안 센다",
			(g.active_mods as Array).is_empty() and _n(5) == 0,
			"걸린 %d · 제약 탭 %d" % [(g.active_mods as Array).size(), _n(5)])
	g.boss_void.clear()


func _first_boss() -> int:
	for n in range(1, 40):
		if GameData.is_boss(n):
			return n
	return 8


# ── ⑦ 개발자 모드가 준 것은 안 세어진다 ─────────────────
#  dev.gd 는 owned · cons · mods_own · magazine 에 **직접** 박는다 —
#  _buy · _apply_mod · _take_cons 를 안 지나므로 _found 가 안 돈다.
#  발라트로·아이작의 「치트로 얻은 것은 발견에 안 센다」가 여기서는 공짜다.
func _dev_given() -> void:
	print("── 개발자 모드 ─────────────────────────────")
	_fresh_run()
	_wipe_found()
	var before := _six()
	g.owned.append((GameData.items()[7] as Dictionary).duplicate())
	g.cons.append((GameData.candies()[2] as Dictionary).duplicate())
	g.mods_own = [String((GameData.mods()[2] as Dictionary).id)]
	_ok("배열에 직접 박은 것은 안 세어진다", _six() == before,
			"%s → %s" % [str(before), str(_six())])
	g.owned.clear()
	g.cons.clear()


# ── ⑧ 규칙 6 — 발견이 팩 풀을 한 칸도 안 움직인다 ───────
func _pack_pool() -> void:
	print("── 팩 풀 (규칙 6) ──────────────────────────")
	_fresh_run()
	g.owned.clear()
	_wipe_found()
	var a := _roll_dist()
	#  109개를 전부 심는다
	for t in 6:
		for r in g._col_rows(t):
			Save.discover(String(g.COL_TABS[t].f) + ":" + String(r.get("id", "")))
	var b := _roll_dist()
	_ok("발견 전후 팩 분포가 글자 그대로 같다", a == b,
			"갈래 %d / %d" % [a.size(), b.size()])

	#  레전더리는 여전히 itemgot: 이 쥔다 — 발견만으로는 한 장도 안 든다.
	#  ⚠ 「itemgot 이 서면 그때부터 든다」의 **긍정 쪽은 legend_probe 가 쥔다**
	#  (120 · 135). 여기서 재면 가중치가 0.03 이라 이천 번에 두 번쯤 뜨는
	#  확률 검사가 되어 조용히 깜빡이는 자가 된다.
	var legs := PackedStringArray()
	for it in GameData.items():
		if GameData.item_weight(it) <= 0.0 and a.has(String(it.id)):
			legs.append(String(it.id))
	_ok("발견만으로는 레전더리가 팩에 안 든다", legs.is_empty(),
			"샌 것: %s" % ("없음" if legs.is_empty() else ", ".join(legs)))
	_wipe_found()


#  seed 를 박고 이천 번 굴려 id 분포를 낸다.
func _roll_dist() -> Dictionary:
	seed(20260919)
	var out := {}
	for i in 2000:
		var d: Dictionary = g._boost_one("item")
		if d.is_empty():
			continue
		var id := String((d.d as Dictionary).get("id", ""))
		out[id] = int(out.get(id, 0)) + 1
	return out


func _legend_id() -> String:
	for it in GameData.items():
		if GameData.item_weight(it) <= 0.0:
			return String(it.id)
	return ""


# ── ⑨ 절을 갈랐다는 증거 — 네 계약이 안 변한다 ──────────
func _contracts() -> void:
	print("── 저장 계약 ───────────────────────────────")
	_wipe_found()
	g.owned.clear()
	#  공짜 매물이 빈손이면 「안 변한다」가 공짜로 참이 된다 — 한 장 세워 둔다.
	Save.unlock("item:" + _legend_id())
	var unl0 := Save.unlock_keys().size()
	var free0 := String((g._item_free_pick() as Dictionary).get("id", ""))
	Save.flush()
	var info0 := _unl_on_disk()

	for t in 6:
		for r in g._col_rows(t):
			Save.discover(String(g.COL_TABS[t].f) + ":" + String(r.get("id", "")))
	Save.flush()

	_ok("109개를 심어도 unlock_keys() 가 그대로", Save.unlock_keys().size() == unl0,
			"%d → %d" % [unl0, Save.unlock_keys().size()])
	#  ⚠ 프로필 화면의 「해금 N개」. slot_info(save.gd:301-304)가 [해금] 키를
	#  **갈래를 안 가리고** 세는 그 규칙을 여기서 같은 파일에 대고 다시 센다
	#  (slot_info 자체는 슬롯 자리를 읽으므로 도구 자리를 박은 이 자가 못
	#  부른다). 발견을 [해금]에 넣었으면 이 수가 두 배가 됐다.
	_ok("109개를 심어도 「해금 N개」가 그대로", _unl_on_disk() == info0,
			"%d → %d" % [info0, _unl_on_disk()])
	_ok("109개를 심어도 공짜 매물이 그대로",
			String((g._item_free_pick() as Dictionary).get("id", "")) == free0 and free0 != "",
			"'%s' → '%s'" % [free0, String((g._item_free_pick() as Dictionary).get("id", ""))])
	#  표를 훑으며 세므로 109 다 — found_keys() 는 "_v" 까지 세어 110 이 된다
	var n := 0
	for t in 6:
		n += _n(t)
	_ok("여섯 탭 합이 109", n == 109, "%d · %s" % [n, str(_six())])
	Save.lock("item:" + _legend_id())
	_wipe_found()


#  slot_info 의 세는 규칙 그대로 — [해금] 절의 참인 키를 갈래 없이 센다.
func _unl_on_disk() -> int:
	var c := ConfigFile.new()
	if c.load(PATH) != OK or not c.has_section("해금"):
		return 0
	var n := 0
	for k in c.get_section_keys("해금"):
		if bool(c.get_value("해금", k, false)):
			n += 1
	return n


# ── ⑩ discover() 는 디스크를 안 친다 ────────────────────
func _disk() -> void:
	print("── 디스크 ──────────────────────────────────")
	_wipe_found()          # unfound_all 이 flush 까지 한다
	Save.discover("item:c01")
	var c := ConfigFile.new()
	c.load(PATH)
	var on_disk: bool = bool(c.get_value("발견", "item:c01", false))
	_ok("discover() 는 flush 를 안 한다", not on_disk, "디스크에 %s" % str(on_disk))
	Save.flush()
	var c2 := ConfigFile.new()
	c2.load(PATH)
	_ok("flush() 뒤에는 디스크에 있다",
			bool(c2.get_value("발견", "item:c01", false)))
	_wipe_found()


# ── ⑪ 이주와 빗장 ───────────────────────────────────────
func _migrate() -> void:
	print("── 이주 ────────────────────────────────────")
	#  새 프로필 — 통계가 0 이고 itemgot 이 없으므로 아무것도 안 나온다
	Save.wipe()
	g._dev_unlock_off()
	g._found_migrate()
	_ok("새 프로필은 이주해도 0 / 109", _six() == [0, 0, 0, 0, 0, 0], str(_six()))
	_ok("[발견]에는 _v 만 선다", Save.found_ready() and Save.found_keys().size() == 1,
			"%s" % str(Save.found_keys()))

	#  이미 플레이한 프로필 — 저장이 아는 것만 읽는다
	Save.wipe()
	g._dev_unlock_off()
	var leg := _legend_id()
	Save.unlock("itemgot:" + leg)
	Save.bump("runs")
	Save.peak("best_dart_hvy", 3)
	Save.tally_up("runs:p_gift")
	g._found_migrate()
	var six := _six()
	_ok("옛 프로필 — 동전 1(받아 본 레전더리)", six[0] == 1, "%d · %s" % [six[0], leg])
	_ok("옛 프로필 — 다트 2 (std · hvy)", six[2] == 2, "%s" % str(Save.found_of("dart")))
	_ok("옛 프로필 — 사탕 1 · 사진 1 (p_gift)", six[3] == 1 and six[4] == 1,
			"사탕 %d · 사진 %d" % [six[3], six[4]])
	_ok("옛 프로필 — 보드 확장 0 · 제약 0", six[1] == 0 and six[5] == 0, str(six))

	#  멱등 — 두 번 불러도 같다
	g._found_migrate()
	_ok("이주는 두 번 불러도 같다", _six() == six, "%s → %s" % [str(six), str(_six())])

	#  ⚠ 이 설계에서 가장 빠뜨리기 쉬운 자리 — unfound_all 이 _v 를 다시
	#  세우지 않으면 「발견 전부 잠그기」가 한 프레임짜리가 된다.
	g._dev_unlock_none()
	_ok("「발견 전부 잠그기」 뒤 0 / 109", _six() == [0, 0, 0, 0, 0, 0], str(_six()))
	g._found_migrate()
	_ok("잠근 뒤 이주가 되살리지 않는다", _six() == [0, 0, 0, 0, 0, 0], str(_six()))

	#  저장 통째로 지우기 — 빗장까지 가므로 이주가 다시 돈다
	Save.wipe()
	_ok("wipe() 뒤에는 빗장이 풀린다", not Save.found_ready())
	g._found_migrate()
	_ok("wipe() 뒤 이주는 0 / 109", _six() == [0, 0, 0, 0, 0, 0], str(_six()))

	#  대역은 저장에 한 글자도 안 쓴다
	var k0 := Save.found_keys().size()
	g._dev_unlock_all()
	_ok("「발견 전부 열기」가 N / N", _six() == [69, 12, 4, 5, 9, 10], str(_six()))
	_ok("「발견 전부 열기」가 저장에 안 쓴다", Save.found_keys().size() == k0,
			"열쇠 %d → %d" % [k0, Save.found_keys().size()])
	g._dev_unlock_off()
