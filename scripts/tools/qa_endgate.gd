extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  이어하기 문지기 — 상한이 하나에서 둘로 늘었다
#
#  실행:  godot --headless --path . --script scripts/tools/qa_endgate.gd
#  종료 코드 = 실패 개수
#
#  _run_ok 는 「하나라도 어긋나면 **아무 말 없이** 이어하기 없음」이 규약이라
#  틀려도 오류가 안 난다 — 껐다 켜면 런이 말없이 사라지는 것이 전부다.
#  그래서 저장을 손으로 빚어 경우마다 답을 댄다.
#
#  ⚠ **막는 경우가 넷 늘었다.** 무한을 여는 것과 상한을 없애는 것은 다른
#  말이다 — 무한 칸이 참인 저장만 위쪽 구간을 받고, 그 구간도 위아래가
#  둘 다 닫혀 있다. 반평면이 되지 않았다.
#
#  ⚠ 그리고 **제목의 흐림과 되살리기가 계속 같은 술어를 쓰는가**를 같이
#  잰다(어제 고친 자리의 짝이다). 열한 경우 모두에서 답이 같아야 한다.
# ══════════════════════════════════════════════════════════

var g = null
var fails := 0
var done := false


func _initialize() -> void:
	Save.path = "user://_qa_endgate.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(nm: String, cond: bool, detail := "") -> void:
	print("  %s %-46s %s" % ["OK  " if cond else "실패", nm, detail])
	if not cond:
		fails += 1


#  성한 저장 한 벌을 빚는다. 뼈대(탄창 · 다트통 · 리그 · 매듭)를 다 채운다.
func _plant(leg: int, endless: Variant, chal := "") -> void:
	Save.run_drop()
	Save.run_set("ver", Save.RUN_VER)
	Save.run_set("slot", Save.slot())
	Save.run_set("at", "leg")
	Save.run_set("seed", 1234)
	Save.run_set("rng", 0)
	Save.run_set("pack", String(GameData.packs()[0].get("id", "")))
	Save.run_set("league", String(GameData.leagues()[0].get("id", "")))
	Save.run_set("challenge", chal)
	Save.run_set("endless", endless)
	Save.run_set("leg_no", leg)
	Save.run_set("magazine", PackedStringArray(["std", "std", "std"]))
	Save.flush()


#  제목 줄과 술어가 같은 답을 내는가. 이 짝이 깨지면 「밝은 채로 죽은
#  계속하기」가 돌아온다.
func _pair(nm: String, want: bool) -> void:
	var ok: bool = g._run_ok()
	var rows: Array = g._title_rows()
	var shown := false
	for r in rows:
		if String(r.n) == "계속하기":
			shown = true
	_ok(nm, ok == want and shown == want,
			"술어 %s · 제목 줄 %s" % [str(ok), str(shown)])


func _process(_d: float) -> bool:
	if done:
		return false
	done = true
	for i in 8:
		g._process(1.0 / 60.0)
	g._autoplay = false
	GameData.challenge = ""
	GameData.endless = false

	print("이어하기 문지기 — 구간이 둘로 늘었다\n")

	print("① 무한 거짓 — 본편 구간만")
	_plant(1, false)
	_pair("판 1 은 통과", true)
	_plant(24, false)
	_pair("판 24 는 통과", true)
	_plant(25, false)
	_pair("판 25 는 **막힌다**", false)
	_plant(0, false)
	_pair("판 0 은 막힌다", false)
	_plant(-3, false)
	_pair("판 −3 은 막힌다", false)

	print("\n② 무한 참 — 위쪽 구간만. 위아래가 둘 다 닫혀 있다")
	_plant(25, true)
	_pair("판 25 는 통과", true)
	_plant(61, true)
	_pair("판 61 은 통과", true)
	_plant(102, true)
	_pair("판 102 는 통과", true)
	_plant(24, true)
	_pair("무한인데 판 24 — **막힌다**(새로 막는다)", false)
	_plant(103, true)
	_pair("무한인데 판 103 — **막힌다**(새로 막는다)", false)

	print("\n③ 자료형 — 제목에서 매 프레임 도는 자리다")
	_plant(25, 1)
	_pair("무한 칸에 int — 막힌다", false)
	_plant(25, "true")
	_pair("무한 칸에 문자열 — 막힌다", false)

	print("\n④ 챌린지도 뼈대다")
	_plant(5, false, "blind")
	_pair("표에 있는 id 는 통과", true)
	_plant(5, false, "none")
	_pair("\"none\" 도 통과", true)
	_plant(5, false, "표에_없는_id")
	_pair("표에서 사라진 id — **통째로 버린다**(새로 막는다)", false)

	print("\n⑤ 되살린 무한 런이 무한인가")
	_plant(61, true, "blind")
	var loaded: bool = g._run_load()
	_ok("되살아난다", loaded)
	_ok("무한 칸이 돌아왔다", GameData.endless, str(GameData.endless))
	_ok("판 번호가 돌아왔다", g.leg_no == 61, str(g.leg_no))
	_ok("챌린지가 돌아왔다", GameData.challenge == "blind", GameData.challenge)
	_ok("legs_top() 이 102 다", GameData.legs_top() == 102)
	#  되살린 뒤 목표가 껐을 때와 같은가 — 무한 칸이 안 돌아왔으면 여기서 운다
	var want: int = GameData.target_of(61)
	_ok("판 61 목표가 라운드 21 의 것이다",
			GameData.round_of(61) == 21 and want > 0,
			"라운드 %d · 목표 %s" % [GameData.round_of(61), GameData.big(want)])
	#  화면 갈래는 저장에 안 적는다 — 되살린 런은 아직 완주 화면을 안 봤다
	_ok("endless_ok 는 안 살아난다", not g.endless_ok)

	print("\n⑥ 본편 런은 무한이 안 켜진 채로 돌아온다")
	_plant(7, false)
	g._run_load()
	_ok("무한 칸이 거짓이다", not GameData.endless)
	_ok("legs_top() 이 24 다", GameData.legs_top() == 24)

	GameData.endless = false
	GameData.challenge = ""
	print("\n%s" % ("전부 통과" if fails == 0 else "실패 %d건" % fails))
	quit(mini(fails, 125))
	return true
