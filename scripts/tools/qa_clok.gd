extends SceneTree

# 시계 판 — 「라운드 더 클록」 검사 (2026-09-26).
#   「시계가 효과가 너무 쓰레기인데?」 — 칸 값을 전부 눕히기만 하던 것을
#   실제 다트 연습 게임의 규칙으로 갈았다.
#     차례인 칸이 세 배 · 맞히면 맞힌 링만큼 다음 칸으로(싱글 1 · 더블 2 ·
#     트리플 3) · 차례는 열두 시 자리에서 시작해 시계 방향으로 돈다
#   여기서 못 박는 것은 **차례가 실제로 그 규칙대로 도는가**와
#   **시계 판이 아닌 판은 한 톨도 안 바뀌는가** 둘이다.
#
#   godot --path . --headless --script scripts/tools/qa_clok.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.path = "user://_qa_clok.cfg"
	Save.gpath = "user://_qa_clok_g.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-40s %s" % ["통과" if c else "실패", n, d])


#  판 하나를 세운다. mid 가 빈 문자열이면 기본 판이다.
func _board(mid: String) -> void:
	#  qa_break 의 _board 와 같은 길이다 — 보드 확장은 mods_own 이 쥐고
	#  판은 _board_bake 가 굽는다. 그 뒤에 _start_leg 가 차례를 세운다.
	g.state = g.S.TITLE
	g._new_run()
	g.mods_own = [] if mid == "" else [mid]
	g._board_bake()
	g._start_leg()


#  칸 i 의 한가운데, 그 링의 한가운데를 겨눈다.
func _aim_at(i: int, ring: String) -> Vector2:
	var sw: float = g._sec_w()
	var a: float = float(i) * sw
	var r: float = g.R * (g.rt_bull_o + g.rt_trp_in) * 0.5
	if ring == "double":
		r = g.R * (g.rt_dbl_in + g.rt_dbl_out) * 0.5
	elif ring == "triple":
		r = g.R * (g.rt_trp_in + g.rt_trp_out) * 0.5
	return g.BC + Vector2(sin(a), -cos(a)) * r


func _throw(i: int, ring := "single") -> void:
	g.aim = _aim_at(i, ring)
	g._land()


#  큐에서 chip 걸음의 값을 뜬다.
func _chip_of(q: Array) -> int:
	for st in q:
		if String(st.get("k", "")) == "chip":
			return int(st.get("v", 0))
	return 0


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


func _run() -> void:
	print("\n== 시계 판 검사 — 라운드 더 클록 ==")

	# ── ① 차례가 선다 ────────────────────────────────
	print("① 판이 설 때")
	_board("clok")
	_ok("시계 판은 열두 시 자리에서 시작한다", g.clok_at == 0,
			"clok_at %d" % g.clok_at)
	_ok("배수가 표에서 온다", g.clok_mul > 1.0, "×%.1f" % g.clok_mul)
	_board("")
	_ok("시계 판이 아니면 차례가 없다", g.clok_at == -1,
			"clok_at %d" % g.clok_at)
	_board("pizz")
	_ok("다른 보드 확장도 차례가 없다", g.clok_at == -1,
			"clok_at %d" % g.clok_at)

	# ── ② 맞힌 링만큼 넘어간다 ───────────────────────
	print("② 싱글 하나 · 더블 둘 · 트리플 셋")
	var n: int = 0
	for pair in [["single", 1], ["double", 2], ["triple", 3]]:
		_board("clok")
		n = g._sec_n()
		var at0: int = g.clok_at
		_throw(at0, String(pair[0]))
		_ok("%s 를 맞히면 %d칸 간다" % [String(pair[0]), int(pair[1])],
				g.clok_at == (at0 + int(pair[1])) % n,
				"%d → %d" % [at0, g.clok_at])

	# ── ③ 차례가 아닌 칸은 안 민다 ───────────────────
	print("③ 다른 칸")
	_board("clok")
	var at1: int = g.clok_at
	_throw((at1 + 3) % n, "triple")
	_ok("차례가 아닌 칸은 차례를 안 민다", g.clok_at == at1,
			"clok_at %d" % g.clok_at)

	# ── ④ 배수는 차례인 칸에만 ───────────────────────
	print("④ 세 배")
	_board("clok")
	var flat: int = int(g.sectors[0])
	var here: Dictionary = g.hit_info(_aim_at(g.clok_at, "single"))
	var there: Dictionary = g.hit_info(_aim_at((g.clok_at + 5) % n, "single"))
	_ok("판은 여전히 칸 값이 눕는다", int(there.base) == flat,
			"칸 값 %d" % int(there.base))
	#  hit_info 는 날값이라 배수가 안 붙는다 — 붙이는 자리는 _land 다.
	_ok("hit_info 는 날값 그대로다", int(here.base) == flat,
			"차례 칸 날값 %d" % int(here.base))
	#  ⚠ **total 로 재면 안 된다.** _land 는 정산 큐를 세울 뿐이고 total 은
	#  걸음이 돌아야(_next_step) 오른다 — 이 자는 _process 를 안 돌리므로
	#  total 이 영영 0 이다(처음에 그렇게 적었다가 빨개졌다).
	#  큐가 실은 chip 값을 본다 — 그것이 곧 이 발이 낸 점수다.
	_board("clok")
	_throw(g.clok_at, "single")
	var got: int = _chip_of(g.queue)
	_board("clok")
	_throw((g.clok_at + 5) % n, "single")
	var got2: int = _chip_of(g.queue)
	_ok("차례인 칸이 %.0f배로 더 준다" % g.clok_mul,
			got == int(round(float(got2) * g.clok_mul)) and got > got2,
			"차례 %d · 남 %d" % [got, got2])

	# ── ⑤ 한 바퀴 ────────────────────────────────────
	print("⑤ 바퀴")
	_board("clok")
	for k in n:
		_throw(g.clok_at, "single")
	_ok("싱글 스무 번이면 제자리로 돌아온다", g.clok_at == 0,
			"clok_at %d" % g.clok_at)
	_ok("바퀴를 한 번 셌다", g.clok_lap == 1, "lap %d" % g.clok_lap)

	# ── ⑥ 연발은 한 발에 한 번 ───────────────────────
	print("⑥ 연발")
	_board("clok")
	var at2: int = g.clok_at
	for k2 in 6:
		g.aim = _aim_at(at2, "single")
		g._land(false)           # 작은 다트 — 한 발을 여섯으로 쪼갠 것
	_ok("연발의 작은 다트는 차례를 안 민다", g.clok_at == at2,
			"여섯 발 뒤 clok_at %d" % g.clok_at)

	# ── ⑦ 판이 새로 서면 처음부터 ────────────────────
	print("⑦ 다음 판")
	_board("clok")
	_throw(g.clok_at, "triple")
	var mid: int = g.clok_at
	g._start_leg()
	_ok("판이 새로 서면 열두 시로 돌아간다", g.clok_at == 0,
			"%d → %d" % [mid, g.clok_at])
	_ok("바퀴도 같이 0 이다", g.clok_lap == 0, "lap %d" % g.clok_lap)

	# ── ⑧ 글자 0자 ───────────────────────────────────
	print("⑧ 글")
	var src := FileAccess.get_file_as_string("res://scripts/game.gd")
	var i0: int = src.find("func _board_lit_sector")
	var i1: int = src.find("func _board_dim_sector", i0)
	var body: String = src.substr(i0, i1 - i0)
	_ok("밝히는 자가 글을 한 자도 안 띄운다",
			body.find("draw_string") < 0 and body.find("pop(") < 0, "")
	#  ⚠ 처음엔 「C_LIGHT 를 옅게 깐다」로 적었는데, 시계 판의 문자판이
	#  이미 상아색이라 크림 위의 크림이 되어 안 보였다 — 그 칸을 칠하는
	#  대신 나머지를 얕게 가라앉히는 쪽으로 갈아서 이 줄도 같이 고쳤다.
	#  못 박을 것은 어느 색을 쓰느냐가 아니라 **새 색을 안 만드는 것**이다.
	_ok("새 색을 한 개도 안 만든다",
			body.find("Color(\"") < 0 and body.find("_board_dim_sector") >= 0, "")

	print("\n통과 %d · 실패 %d" % [okn, fail])
	quit(fail)
