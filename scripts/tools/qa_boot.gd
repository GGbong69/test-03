extends SceneTree

# 첫 런의 두 장 검사 (2026-09-26).
#   「튜토리얼을 게임의 매력을 보여 주는 걸로 특화하자 — 개사기 아이템 주는 거」
#   첫 런에만 두 장(빌리의 바지 · SAFETY LAST!)을 쥐여 준다.
#   여기서 못 박는 것 셋:
#     ① **딱 한 번이다** — 두 번째 런에는 없다
#     ② 챌린지·무한 런에는 안 준다(제약을 걸고 도는 런의 뜻을 지운다)
#     ③ 슬롯을 안 넘긴다 · 점수 표를 한 톨도 안 건드린다
#
#   godot --path . --headless --script scripts/tools/qa_boot.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.path = "user://_qa_boot.cfg"
	Save.gpath = "user://_qa_boot_g.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-40s %s" % ["통과" if c else "실패", n, d])


func _ids() -> Array:
	var out := []
	for o in g.owned:
		out.append(String(o.get("id", "")))
	return out


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


func _run() -> void:
	print("\n== 첫 런의 두 장 ==")
	var want: Array = (g.BOOT_GIFT as Array).duplicate()

	# ── ① 첫 런 ──────────────────────────────────────
	print("① 처음 켠 사람")
	Save.wipe()
	g.state = g.S.TITLE
	g._new_run()
	var got := _ids()
	var all := true
	for w in want:
		if not got.has(String(w)):
			all = false
	_ok("두 장이 손에 들어온다", all and got.size() == want.size(), str(got))
	#  조건 없는 한 장과 마지막 발 한 장 — 그림이 서는 근거다
	var flat := false
	var last := false
	for it in GameData.items():
		#  ⚠ 조건은 items() 에서 **"c"** 로 온다("cond" 가 아니다) — 표의
		#  열 이름과 사전의 열쇠가 다른 자리다. 처음에 "cond" 로 읽어
		#  두 줄이 빨개졌다. 2026-09-26
		if String(it.id) == "r14":
			flat = String(it.get("c", "")) == "always"
		elif String(it.id) == "u26":
			last = String(it.get("c", "")) == "last"
	_ok("한 장은 조건이 없다 — 빗나가도 그림이 선다", flat, "r14 cond always")
	_ok("한 장은 판 마지막 발이다 — 끝이 절정이다", last, "u26 cond last")

	# ── ② 두 번째 런 ─────────────────────────────────
	print("② 두 번째 런")
	g._new_run()
	_ok("두 번째 런에는 없다", _ids().is_empty(), str(_ids()))
	_ok("배움 표에 한 번으로 적혔다", Save.taught("u_boot"), "")

	# ── ③ 챌린지·무한 ────────────────────────────────
	print("③ 제약을 걸고 도는 런")
	Save.wipe()
	GameData.challenge = "solo"
	g._new_run()
	_ok("챌린지 런에는 안 준다", _ids().is_empty(), str(_ids()))
	_ok("그 런은 배움 표도 안 적는다 — 본편 첫 런이 제 몫을 받는다",
			not Save.taught("u_boot"), "")
	GameData.challenge = ""
	#  ⚠ 무한 런은 **_new_run 을 안 지난다.** 완주 화면에서 하던 런을 잇는
	#  것이라, 여기서 endless 를 켜고 _new_run 을 불러도 그 줄이 곧장 false 로
	#  되돌린다(game.gd:1776) — 처음에 그렇게 재서 빨개졌다. 문지기가 실제로
	#  무엇을 막는지는 주는 자를 **직접** 불러서 본다. 2026-09-26
	Save.wipe()
	g.owned.clear()
	GameData.endless = true
	g._boot_gift()
	_ok("무한 런에는 안 준다", _ids().is_empty(), str(_ids()))
	GameData.endless = false

	# ── ④ 슬롯 ───────────────────────────────────────
	print("④ 슬롯")
	Save.wipe()
	g._new_run()
	_ok("동전 슬롯을 안 넘긴다",
			g.owned.size() <= GameData.max_items(),
			"%d / %d" % [g.owned.size(), GameData.max_items()])
	var bought := 0
	for o in g.owned:
		bought += int(o.get("bought", 0))
	_ok("산 것으로 안 적힌다 — 판매가가 안 붙는다", bought == 0, "bought 합 %d" % bought)

	# ── ⑤ 표를 안 건드린다 ───────────────────────────
	print("⑤ 밸런스")
	var src := FileAccess.get_file_as_string("res://scripts/game.gd")
	var i0: int = src.find("func _boot_gift")
	var i1: int = src.find("\nconst BOOT_GIFT", i0)
	var body: String = src.substr(i0, i1 - i0)
	_ok("주는 자가 값을 한 개도 안 고친다",
			body.find("score") < 0 and body.find("target") < 0
			and body.find("gold") < 0, "")
	_ok("글을 한 자도 안 띄운다",
			body.find("draw_string") < 0 and body.find("pop(") < 0, "")

	print("\n통과 %d · 실패 %d" % [okn, fail])
	quit(fail)
