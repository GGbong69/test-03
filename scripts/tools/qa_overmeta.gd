extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  런 끝 · 컬렉션 · 프로필의 「이번 런 값」 (2026-10-21)
#
#  실행:  godot --headless --path . --script scripts/tools/qa_overmeta.gd
#  종료 코드 = 실패 개수
#
#  ① 「최고 판 점수」는 이번 런 값이다 — 튜토리얼 런 끝에도 선다
#  ② 통계로 여는 다트통 여섯이 진짜 조건 한 줄과 지금 값을 쓴다
#  ③ 동전마다 이번 런 발동 수 — 정산 걸음이 세고 툴팁 태그가 읽는다
#  ④ 컬렉션의 잠긴 전설은 [잠김] · 조건 태그 · 런 끝 쪽지는 여는 조건 태그
#  ⑤ 런 끝 「거의 다 왔다」 쪽지 — ⅔ 넘게 찬 잠긴 것 하나 · 이름과 값
#  ⑥ 신기록 도장(런 시작 때 기록을 넘었나) · 「새로 찾음 N」 · 줄은 다섯까지
#  ⑦ 런 끝 · 프로필을 한 틀씩 그려 본다 · 프로필이 한 발 최고 점수 · 컬렉션 수를 읽는다
# ══════════════════════════════════════════════════════════

var g = null
var ok := 0
var bad := 0
var done := false


func _initialize() -> void:
	Save.gpath = "user://_qa_overmeta_g.cfg"
	Save.path = "user://_qa_overmeta.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-46s %s" % ["통과" if cond else "실패", nm, note])


func _arm(tut: bool) -> void:
	GameData.challenge = ""
	GameData.endless = false
	GameData.league = "white"
	GameData.pack = "base"
	g._new_run()
	g.tut_run = tut
	g.owned.clear()


#  판 하나를 끝낸다 — 점수 sc 로.
func _leg(leg: int, sc: int) -> void:
	g.leg_no = leg
	g.target = GameData.target_of(leg)
	g.total = sc
	g.darts_left = 3
	g._finish_leg()


func _pack(id: String) -> Dictionary:
	for r in GameData.packs():
		if String(r.get("id", "")) == id:
			return r
	return {}


func _plain_has(k: String) -> bool:
	for kv in g.RUN_PLAIN:
		if String(kv[0]) == k:
			return true
	return false


func _tags() -> Array:
	var out := []
	for tg in g.tip_tags:
		out.append(String(tg.t))
	return out


func _row(nm: String) -> String:
	for r in g._over_rows():
		if String(r[0]) == nm:
			return String(r[1])
	return ""


func _process(_d: float) -> bool:
	if done:
		return false
	done = true
	_run()
	return false


#  한 틀 그린다 — 그리는 길에서 멎는 줄이 없는가(SCRIPT ERROR 는 도는 쪽이 센다).
func _frame() -> void:
	g.queue_redraw()
	await process_frame
	await process_frame


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	g._autoplay = false

	print("① 이번 런 최고 판 점수")
	_arm(true)
	_ok("새 런은 0 에서 선다", g.run_leg_top == 0, "%d" % g.run_leg_top)
	var t1: int = GameData.target_of(1)
	_leg(1, t1 + 700)
	_leg(2, GameData.target_of(2) + 10)
	_ok("판마다 가장 높은 값을 쥔다", g.run_leg_top == maxi(t1 + 700, GameData.target_of(2) + 10),
			"%d" % g.run_leg_top)
	_ok("튜토리얼 런 끝에도 「최고 판 점수」가 선다",
			_row("최고 판 점수") == GameData.big(g.run_leg_top), _row("최고 판 점수"))
	_ok("튜토리얼 런은 프로필 「던진 다트」를 안 세운다", _row("던진 다트") == "")
	_ok("프로필 최고값은 안 민다(튜토리얼)", Save.stat("best_score") == 0,
			"%d" % Save.stat("best_score"))
	_ok("이어하기에 적힌다(RUN_PLAIN)", _plain_has("run_leg_top"))
	_arm(false)
	_ok("다음 런은 다시 0", g.run_leg_top == 0)

	print("\n② 통계로 여는 다트통의 조건 글")
	Save.peak("best_dart_lgt", 2)
	var lgt: String = g._pack_cond(_pack("p_lgt"))
	_ok("조건과 지금 값", lgt == "가벼운 다트 3개 이상 들고 완주 · 2 / 3", lgt)
	var rack: String = g._pack_cond(_pack("p_rack"))
	_ok("이하 조건은 값 없이 글만", rack == "동전 4개 이하로 완주", rack)
	for id in ["p_rack", "p_adv", "p_iron", "p_lgt", "p_mgn", "p_solo"]:
		var c: String = g._pack_cond(_pack(id))
		_ok("%s — 「완주로 열린다」가 아니다 · 열쇠 글자가 안 샌다" % id,
				c != "완주로 열린다" and not c.contains("cond_"), c)
	_ok("히든은 그대로 「조건 미달」", g._pack_cond(_pack("p_x1")) == "조건 미달")

	print("\n③ 동전마다 이번 런 발동 수")
	_arm(false)
	_ok("새 런은 비어 있다", g.run_fires.is_empty())
	var it: Dictionary = (GameData.items()[0] as Dictionary).duplicate()
	g.owned = [it]
	for n in 2:
		g.queue = [{"k": "item", "i": 0, "lbl": "", "kind": "chip", "v": 5}]
		g._next_step()
	_ok("정산 「item」 걸음마다 하나씩", int(g.run_fires.get(String(it.id), 0)) == 2, str(g.run_fires))
	g.state = g.S.SHOP
	g._tip_build({"k": "rack", "i": 0})
	var tags := []
	for tg in g.tip_tags:
		tags.append(String(tg.t))
	_ok("동전 툴팁에 「발동 2」 태그", tags.has("발동 2"), str(tags))
	g.run_fires.clear()
	g._tip_build({"k": "rack", "i": 0})
	var t0 := true
	for tg in g.tip_tags:
		t0 = t0 and not String(tg.t).begins_with("발동")
	_ok("0 이면 태그가 없다", t0)
	_ok("이어하기에 적힌다(RUN_PLAIN)", _plain_has("run_fires"))

	print("\n④ 컬렉션의 잠긴 전설 · 런 끝 쪽지의 여는 조건")
	var li := -1
	var ci := -1
	for k in GameData.items().size():
		var r: Dictionary = GameData.items()[k]
		if String(r.get("ustat", "")) == "best_gain":
			li = k
		elif ci < 0 and String(r.get("ustat", "")) == "":
			ci = k
	g.state = g.S.COLLECT
	g._tip_build({"k": "citem", "i": li})
	var lt := _tags()
	_ok("잠긴 전설 — 제목은 ??? 그대로", g.tip_title == "???", g.tip_title)
	_ok("잠긴 전설 — [잠김] · 조건 태그", lt == ["동전", "잠김", "한 발 100000점"], str(lt))
	g._tip_build({"k": "citem", "i": ci})
	_ok("보통 동전의 못 본 칸은 그대로", _tags() == ["동전"], str(_tags()))
	Save.unlock("item:" + String(GameData.items()[li].id))
	g._tip_build({"k": "citem", "i": li})
	_ok("열렸지만 못 받은 전설은 ??? 뿐", _tags() == ["동전"], str(_tags()))
	Save.lock("item:" + String(GameData.items()[li].id))

	g.state = g.S.OVER
	g.over_t = 2.0
	g.owned = []
	g.run_unlocked = [g._unl_tag("다트통", "여벌 다트통", "p_mag"), g._unl_tag("리그", "초록 리그", "green")]
	var nrs: Array = g._over_note_rects(g._over_notes())
	var hit: Dictionary = g._tip_hit((nrs[0] as Rect2).get_center())
	_ok("쪽지가 잡힌다", String(hit.get("k", "")) == "unl" and int(hit.get("i", -1)) == 0, str(hit))
	g._tip_build(hit)
	_ok("다트통 쪽지 — 여는 조건 태그", _tags() == ["기본 다트통 완주"], str(_tags()))
	_ok("앵커가 그 쪽지다", g.tip_mark == nrs[0], "%s" % g.tip_mark)
	g._tip_build(g._tip_hit((nrs[1] as Rect2).get_center()))
	_ok("리그 쪽지 — 이 다트통 완주 수", _tags() == ["기본 다트통 1회 완주"], str(_tags()))
	g.run_unlocked = []
	for r in GameData.packs():
		g.run_unlocked.append(g._unl_tag("다트통", String(r.get("name", "")), String(r.get("id", ""))))
	var p: Rect2 = g._over_panel()
	var inside := true
	for rr in g._over_note_rects(g._over_notes()):
		inside = inside and (rr as Rect2).end.x <= p.end.x - 24.0
	_ok("쪽지가 많아도 칠판 안쪽에서 멎는다", inside)
	g.run_unlocked = []

	print("\n⑤ 「거의 다 왔다」 쪽지 하나")
	#  ② 가 깃털(가벼운 다트 3개)을 2 로 올려 두었다
	var nr: Dictionary = g._over_near()
	_ok("⅔ 찬 잠긴 다트통 — 이름과 값", String(nr.get("t", "")) == "깃털 다트통 2 / 3", str(nr))
	_ok("툴팁 태그는 조건 글", String(nr.get("c", "")) == "가벼운 다트 3개 이상 들고 완주")
	var nts: Array = g._over_notes()
	_ok("쪽지 줄 끝에 선다", nts.size() == 1 and bool(nts[0].get("near", false)))
	Save.peak("best_gain", 70000)
	_ok("더 많이 찬 것 하나 — 못 본 전설은 이름 대신 ???",
			String(g._over_near().get("t", "")) == "??? 70000 / 100000", str(g._over_near()))
	Save.unlock("item:" + String(GameData.items()[li].id))
	_ok("열린 것은 안 고른다", String(g._over_near().get("t", "")) == "깃털 다트통 2 / 3")
	Save.unlock("pack:p_lgt")
	_ok("⅔ 밑이면 쪽지가 없다", g._over_near().is_empty(), str(g._over_near()))
	Save.lock("pack:p_lgt")
	g.tut_run = true
	_ok("기록을 안 미는 런(튜토리얼)에서는 안 선다", g._over_near().is_empty())
	g.tut_run = false

	print("\n⑥ 신기록 도장 · 새로 찾음")
	Save.peak("best_score", 500)
	_arm(false)
	_ok("런 시작 때 내 기록을 쥔다", g.run_rec0 == 500, "%d" % g.run_rec0)
	g.run_leg_top = 500
	_ok("같으면 신기록이 아니다", not g._over_rec())
	g.run_leg_top = 501
	_ok("넘으면 신기록", g._over_rec())
	g.tut_run = true
	_ok("기록을 안 미는 런에서는 도장이 없다", not g._over_rec())
	g.tut_run = false
	g.run_rec0 = -1
	_ok("모르는 기준(옛 저장)은 도장이 없다", not g._over_rec())
	_ok("새 런은 새로 찾음 0", g.run_found == 0, "%d" % g.run_found)
	var fid := String(GameData.items()[ci].id)
	g._found("item", fid)
	g._found("item", fid)
	_ok("처음 든 것만 센다", g.run_found == 1, "%d" % g.run_found)
	g.won = false
	var rs: Array = g._over_rows()
	_ok("실패 · 새로 찾음 — 줄은 다섯까지(「던진 다트」가 비킨다)",
			rs.size() == 5 and _row("새로 찾음") == "1" and _row("던진 다트") == "", str(rs))
	g.run_found = 0
	_ok("0 이면 줄이 없다 · 「던진 다트」는 넷째 그대로",
			_row("새로 찾음") == "" and String(g._over_rows()[3][0]) == "던진 다트", str(g._over_rows()))
	g.won = true
	g.run_found = 2
	_ok("완주 · 새로 찾음 — 다섯 줄", g._over_rows().size() == 5 and _row("새로 찾음") == "2")
	_ok("이어하기에 적힌다(RUN_PLAIN)", _plain_has("run_rec0") and _plain_has("run_found"))

	print("\n⑦ 그려 본다 — 런 끝(도장 · 쪽지 · 발동 수) · 프로필(여섯 줄)")
	g.state = g.S.OVER
	g.won = true
	g.owned = []
	for k in 3:
		g.owned.append((GameData.items()[k] as Dictionary).duplicate())
		g.run_fires[String(GameData.items()[k].id)] = k + 1
	g.run_unlocked = [g._unl_tag("다트통", "여벌 다트통", "p_mag")]
	g.run_rec0 = 0
	g.run_leg_top = 501
	g.over_t = 0.58
	g._process(0.05)               # 도장 때(0.60)를 지난다 — 종 한 번
	_ok("도장 때를 지났다", g.over_t >= float(g.OVERB.stamp_at), "%.2f" % g.over_t)
	await _frame()
	_ok("쪽지 둘(열린 것 · 거의 다 왔다)", g._over_notes().size() == 2, str(g._over_notes()))
	#  프로필 — 이 도구만의 자리에 여섯 줄이 다 서는 프로필을 짓는다(남의 _tool_ 파일을 안 건드린다)
	Save.prof_fmt = "user://_qa_overmeta_prof_%d.cfg"
	var pc := ConfigFile.new()
	for kv in [["runs", 4], ["wins", 1], ["best_leg", 9], ["best_score", 23456], ["best_gain", 123456789]]:
		pc.set_value("통계", String(kv[0]), int(kv[1]))
	pc.set_value("발견", "item:c01", true)
	pc.set_value("발견", "_v", 1)
	pc.save(Save.slot_path(1))
	var inf: Dictionary = Save.slot_info(1)
	_ok("프로필 — 한 발 최고 · 컬렉션 수를 읽는다",
			int(inf.get("best_gain", 0)) == 123456789 and int(inf.get("found", 0)) == 1, str(inf))
	g._open_profile()
	g.prof_sel = 1
	await _frame()
	_ok("프로필이 섰다", g.state == g.S.PROFILE)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Save.slot_path(1)))
	Save.prof_fmt = Save.PROF

	print("\n통과 %d · 실패 %d" % [ok, bad])
	quit(bad)
