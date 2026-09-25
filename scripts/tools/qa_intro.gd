extends SceneTree

# 인트로 건너뛰기 검사 (2026-09-25).
#   「게임 건너뛰기가 너무 잘 돼서 오프닝을 못 보여주네」 —
#   아무 누름 하나가 5.35초를 통째로 지우던 것을 두 걸음으로 바꿨다.
#     앞 lock 초는 안 먹는다 · 첫 누름은 빨리 감기 · 두 번째 누름이 넘긴다
#   키와 손가락이 **같은 문**(_intro_press)을 지나는지도 여기서 못 박는다.
#
#   godot --path . --headless --script scripts/tools/qa_intro.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.path = "user://_qa_intro.cfg"
	Save.gpath = "user://_qa_intro_g.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-38s %s" % ["통과" if c else "실패", n, d])


#  인트로를 손으로 연다. 부팅 때 여는 문(_intro_wanted)은 도구에서 거짓이다.
func _open() -> void:
	g._intro_begin()


func _wind(sec: float) -> void:
	var n: int = int(sec * 60.0)
	for i in n:
		g._intro_tick(1.0 / 60.0)


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


func _run() -> void:
	print("\n== 인트로 검사 — 오프닝이 한 번에 안 지워진다 ==")
	var lock: float = float(g.INTRO.lock)
	var ff: float = float(g.INTRO.ff)
	var endt: float = float(g.INTRO.end)

	# ── ① 앞머리는 안 먹는다 ──────────────────────────
	print("① 실행 직후에 딸려 온 누름")
	_open()
	_wind(lock * 0.5)
	var t0: float = g.intro_t
	g._intro_press()
	_ok("잠긴 동안 누름이 아무 일도 안 한다",
			g.state == g.S.INTRO and not g.intro_ff,
			"t %.2f < lock %.2f" % [t0, lock])
	#  여러 번 두들겨도 마찬가지다 — 실행 직후에는 연타가 흔하다
	for i in 5:
		g._intro_press()
	_ok("잠긴 동안은 연타도 안 먹는다",
			g.state == g.S.INTRO and not g.intro_ff, "다섯 번 눌렀다")

	# ── ② 첫 누름은 빨리 감기 ────────────────────────
	print("② 첫 누름 — 끝을 보여 준다")
	_wind(lock)
	g._intro_press()
	_ok("첫 누름이 빨리 감기를 켠다",
			g.state == g.S.INTRO and g.intro_ff, "state 그대로 · ff true")
	var a: float = g.intro_t
	_wind(0.2)
	var d1: float = g.intro_t - a
	_ok("실제로 %.1f배로 흐른다" % ff,
			absf(d1 - 0.2 * ff) < 0.02, "0.2초에 %.3f초" % d1)

	# ── ③ 두 번째 누름이 넘긴다 ──────────────────────
	print("③ 두 번째 누름 — 그때 넘어간다")
	g._intro_press()
	_ok("제목으로 넘어간다", g.state == g.S.TITLE, "state %d" % g.state)
	#  ⚠ **꽂힌 것과 나는 것을 같이 센다.** _ttl_throw 는 자루를 ttl_fly 에
	#  얹고, 그것이 ttl_stuck 으로 넘어가는 것은 _process 안의 날기 시계다 —
	#  이 자는 _intro_tick 만 돌리므로 날던 자루가 영영 안 꽂힌다.
	#  못 박을 것은 「어디에 있느냐」가 아니라 **세 자루가 다 있느냐**다.
	_ok("넘긴 뒤 자루 셋이 다 있다",
			(g.ttl_stuck as Array).size() + (g.ttl_fly as Array).size()
					== int((g.INTRO.darts as Array).size()),
			"꽂힘 %d · 나는 중 %d" % [(g.ttl_stuck as Array).size(),
					(g.ttl_fly as Array).size()])
	_ok("넘어간 뒤에는 누름이 인트로를 안 건드린다",
			g.intro_t < 0.0, "intro_t %.2f" % g.intro_t)

	# ── ④ 아무도 안 누르면 스스로 끝난다 ─────────────
	print("④ 손대지 않으면")
	_open()
	_wind(endt + 0.2)
	_ok("제 시간에 제목으로 간다", g.state == g.S.TITLE,
			"end %.2f 초" % endt)
	_ok("끝까지 본 판에도 자루 셋이 그대로다",
			(g.ttl_stuck as Array).size() + (g.ttl_fly as Array).size()
					== int((g.INTRO.darts as Array).size()),
			"꽂힘 %d · 나는 중 %d" % [(g.ttl_stuck as Array).size(),
					(g.ttl_fly as Array).size()])

	# ── ⑤ 두 길이 한 문을 지난다 ─────────────────────
	print("⑤ 키와 손가락")
	var src := FileAccess.get_file_as_string("res://scripts/game.gd")
	_ok("입력 두 자리가 _intro_press 를 부른다",
			src.count("_intro_press()") >= 3,
			"부르는 자리 %d (키 · 손가락 · 함수 제 몸)"
					% src.count("_intro_press()"))
	_ok("_intro_end 를 입력에서 직접 안 부른다",
			src.count("_intro_end()") == 3,
			"틱 하나 · 제 몸 하나 · _intro_press 하나")

	# ── ⑥ 다시 보기(개발자 판)는 그대로 ──────────────
	print("⑥ 개발자 판의 다시 보기")
	var Dev = load("res://scripts/dev.gd")
	g.state = g.S.TITLE
	Dev._run(g, {"a": "intro"})
	_ok("개발자 판이 인트로를 다시 연다", g.state == g.S.INTRO,
			"state %d · t %.2f" % [g.state, g.intro_t])
	_ok("다시 열면 빨리 감기가 내려가 있다", not g.intro_ff, "")

	# ── ⑦ 글자 0자 ───────────────────────────────────
	print("⑦ 글")
	var i0: int = src.find("func _intro_press")
	var i1: int = src.find("func _intro_end", i0)
	var body: String = src.substr(i0, i1 - i0)
	_ok("새 문이 글을 한 자도 안 띄운다",
			body.find("draw_string") < 0 and body.find("pop(") < 0, "")

	print("\n통과 %d · 실패 %d" % [okn, fail])
	quit(fail)
