extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  큰 수 — 값은 안 깎고 **글자만** 깎는다
#
#  실행:  godot --headless --path . --script scripts/tools/qa_bignum.gd
#  종료 코드 = 실패 개수
#
#  ⚠ **화면이 목표보다 먼저 깨진다.** 상단바 목표는 60px·12pt 칸에 그리고
#  같은 자리 주석이 「다섯 자리가 40px」이라 8px/자리 — **일곱 자리가
#  끝**이다. 검정 리그 보스라면 R16(1.9e7, 여덟 자리)에서 게이지를 밀고
#  들어간다.
#
#  ⚠ 「유효숫자 둘 **값** 내림」으로는 글자가 **안 줄어든다** — 2.0e7 을
#  int 로 적으면 "20000000" 여덟 자다. 줄이는 것은 단위 쪽이고, 돌려주는
#  것이 **String** 이라 구조적으로 계산에 못 들어간다.
#
#  그리고 **본편은 한 글자도 안 바뀐다**는 것이 첫 단언이다 — 본편 최악
#  목표가 정확히 100,000 이라 문턱을 10만에 두면 마지막 판이 그 위에
#  얹힌다. 100만이면 안 얹힌다(밸런스 유예를 안 건드린다).
# ══════════════════════════════════════════════════════════

var g = null
var fails := 0
var done := false


func _initialize() -> void:
	Save.path = "user://_qa_bignum.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(nm: String, cond: bool, detail := "") -> void:
	print("  %s %-46s %s" % ["OK  " if cond else "실패", nm, detail])
	if not cond:
		fails += 1


func _w(s: String) -> float:
	return g.font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x


func _process(_d: float) -> bool:
	if done:
		return false
	done = true
	for i in 8:
		g._process(1.0 / 60.0)
	g._autoplay = false
	GameData.challenge = ""
	GameData.endless = false

	print("큰 수 — 글자만 깎는다\n")

	# ── ① 본편은 한 글자도 안 바뀐다 ──────────────────────
	print("① 본편")
	var same := true
	var bad := 0
	for n in range(1, 25):
		var t: int = GameData.target_of(n)
		if GameData.big(t) != str(t):
			same = false
			bad = t
	_ok("판 스물넷의 목표가 str(v) 그대로다", same, str(bad))
	#  본편 최악 = 20000 x 검정 4.00 x 제약 1.25 = 100,000
	_ok("본편 최악 목표(10만)도 그대로다", GameData.big(100000) == "100000",
			GameData.big(100000))
	_ok("문턱 바로 아래도 그대로다", GameData.big(999999) == "999999")
	_ok("문턱부터 깎인다", GameData.big(1000000) == "100만",
			GameData.big(1000000))
	_ok("음수도 깎인다", GameData.big(-2500000) == "−250만",
			GameData.big(-2500000))

	# ── ② 폭 ──────────────────────────────────────────────
	print("\n② 폭 — 목표 칸 60px · 점수 칸 64px")
	_ok("본편 최악이 칸에 든다", _w("100000") <= 60.0,
			"%.0fpx" % _w("100000"))
	var over := ""
	var widest := 0.0
	var widest_s := ""
	GameData.endless = true
	for a in range(GameData.rounds_n() + 1, GameData.endless_rounds() + 1):
		#  한 판의 최악 = 기본 x 보스 2.00 x 검정 리그 4.00 x 보스 제약 1.25
		var v := int(GameData.round_base_endless(a) * 10.0)
		var s := GameData.big(v)
		var w := _w(s)
		if w > widest:
			widest = w
			widest_s = "R%d %s" % [a, s]
		if w > 60.0:
			over = "R%d %s %.0fpx" % [a, s, w]
	_ok("R9~R34 최악 목표가 60px 안이다", over == "", over)
	print("     가장 넓은 것 — %s (%.0fpx)" % [widest_s, widest])
	#  점수는 목표를 넘겨야 클리어라 목표보다 크다. 3.6배까지 본다.
	var over2 := ""
	for a in range(GameData.rounds_n() + 1, GameData.endless_rounds() + 1):
		var v2 := int(GameData.round_base_endless(a) * 36.0)
		if _w(GameData.big(v2)) > 64.0:
			over2 = "R%d %s" % [a, GameData.big(v2)]
	_ok("넘긴 점수(최악의 3.6배)도 64px 안이다", over2 == "", over2)
	GameData.endless = false

	# ── ③ 값도 표도 판정도 안 깎는다 ──────────────────────
	print("\n③ 값은 그대로다")
	_ok("돌려주는 것이 String 이다",
			typeof(GameData.big(1)) == TYPE_STRING)
	_ok("target_of 는 int 그대로다",
			typeof(GameData.target_of(24)) == TYPE_INT)
	_ok("_target_at 도 int 그대로다",
			typeof(g._target_at(24)) == TYPE_INT)

	# ── ④ 깎는 자리가 하나다 ──────────────────────────────
	#  같은 수를 두 꼴로 찍으면 화면이 판을 속인다. 찍는 자리 전부가
	#  이 함수 하나를 지나는가를 원본에서 센다.
	print("\n④ 깎는 자리")
	var src := FileAccess.get_file_as_string("res://scripts/game.gd")
	var uses := src.count("GameData.big(")
	_ok("game.gd 가 아홉 자리 넘게 이 함수를 지난다", uses >= 9,
			"%d곳" % uses)
	_ok("목표를 str() 로 바로 찍는 자리가 없다",
			not src.contains("str(target), HORIZONTAL_ALIGNMENT_RIGHT"))

	print("\n%s" % ("전부 통과" if fails == 0 else "실패 %d건" % fails))
	quit(mini(fails, 125))
	return true
