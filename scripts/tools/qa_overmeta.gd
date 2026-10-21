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


func _row(nm: String) -> String:
	for r in g._over_rows():
		if String(r[0]) == nm:
			return String(r[1])
	return ""


func _process(_d: float) -> bool:
	if done:
		return false
	done = true
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

	print("\n통과 %d · 실패 %d" % [ok, bad])
	quit(bad)
	return false
