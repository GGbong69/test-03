extends SceneTree

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

# ══════════════════════════════════════════════════════════
#  판 갈이 회귀 검사
#
#  실행:  godot --path . --headless --quit-after 4000 --script scripts/tools/swap_probe.gd
#  종료 코드 = 실패 개수
#
#  이 연출의 약속은 하나다 — **그림만 붙잡고 게임은 안 만진다.**
#  그 약속이 깨지는 순간 프로브 열두 벌이 같이 무너지므로 여기서 못 박는다.
#
#  재는 것
#    ① 흐름 — 던지면 전환이 켜지고 상태·데이터는 그 프레임에 다 선다
#    ② 첫 프레임에 판이 실제로 **누워 화면 안에** 있고, 판이 뜰 때
#       테이블은 이미 화면 밖이다 (두 층은 안 겹친다)
#    ③ 전환 중에는 클릭이 안 먹고, 아무 키나 누르면 건너뛴다
#    ④ 판정 사각은 전환 중에 한 픽셀도 안 움직인다
#    ⑤ 전환은 게임 상태를 한 비트도 안 바꾼다
#    ⑥ 스스로 끝나고, 끝나면 두 값이 정확히 제자리다
#    ⑦ 돌아오는 길도 같은 함수로 돈다
#    ⑧ 소크(drop_fast)와 테이블 아닌 화면에서는 아예 안 켜진다
# ══════════════════════════════════════════════════════════

var fails := 0


func _say(ok: bool, name: String, detail := "") -> void:
	print("  %s %-32s %s" % ["OK  " if ok else "실패", name, detail])
	if not ok:
		fails += 1


func _wind(g: Node, sec: float) -> void:
	var t := 0.0
	while t < sec:
		g._process(1.0 / 60.0)
		t += 1.0 / 60.0


# 판정에 쓰이는 사각 전부. 전환이 이 중 하나라도 옮기면 안 보이는 자리를
# 누르게 된다 — 그리기와 판정이 갈려 있다는 주장의 유일한 증거다.
func _rects(g: Node) -> Array:
	return [g._mag_rect(0), g._slot_rect(0), g._cons_rect(0), g._panel_rect(),
			g._bank_rect(), g._reroll_rect(), g._next_rect(), g._stage_rect(0)]


func _key(g: Node, code: int) -> void:
	var e := InputEventKey.new()
	e.pressed = true
	e.keycode = code
	g._unhandled_input(e)


func _initialize() -> void:
	Save.path = "user://_probe_swap.cfg"
	Save.wipe()
	var g: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g._new_run()

	# ① 던지면 전환이 켜진다 — 그리고 상태·데이터는 **그 프레임에** 다 선다
	var want: int = GameData.target_of(1)
	g._click(g._blind_go().get_center())
	_say(g.swap_live and g.state != g.S.BLIND and g.target == want
			and not g.remaining.is_empty(),
			"던지면 켜지되 판은 그 프레임에 선다",
			"live=%s state=%d 목표 %d 다트 %d발"
			% [g.swap_live, g.state, g.target, g.remaining.size()])
	_say(g.swap_scr == g.S.BLIND, "빠져나갈 화면을 기억한다", "scr %d" % g.swap_scr)

	# ② 첫 프레임 — 판이 누웠고, 그 자세가 화면 안이다
	var a0: float = g._swap_rise()
	var top: float = g._swap_map(g.BC.y - g.R * 1.13)
	var bot: float = g._swap_map(g.BC.y + g.R * 1.13)
	_say(a0 < 0.001, "첫 프레임에 판이 누워 있다", "선 정도 %.4f" % a0)
	_say(top >= 360.0,
			"누운 판은 화면 밖에서 시작한다", "윗변 y %.1f" % top)
	_say(g._swap_gone() < 0.001, "테이블은 아직 제자리다",
			"빠진 정도 %.4f" % g._swap_gone())

	# ②' 두 층은 안 겹친다 — 판이 조금이라도 뜬 프레임에는 테이블이
	#     이미 화면 밖이다. 한 프레임을 재는 게 아니라 타임라인 전체를
	#     훑는다. 겹치면 올라오는 판이 남은 펠트 위에 얹힌 물건으로 읽힌다.
	var worst := 0.0
	var high := 360.0
	while g.swap_live:
		var dx: float = float(g.SWAP.dx) * g._swap_gone()
		if dx < g.VIEW.x:                       # 테이블이 아직 화면에 있다
			high = minf(high, g._swap_map(g.BC.y - g.R * 1.13))
			worst = maxf(worst, g.VIEW.x - dx)
		g._process(1.0 / 60.0)
	_say(high >= 360.0, "테이블이 있는 동안 판은 화면 밖이다",
			"판 윗변 최고 y %.1f (테이블 최대 %.0fpx 남음)" % [high, worst])

	# 다시 연다 — 아래 검사들이 도는 전환을 쓴다
	g.round_no = 1
	g._open_blind()
	g._click(g._blind_go().get_center())

	# ④ 판정 사각은 전환 내내 한 픽셀도 안 움직인다
	var r0 := _rects(g)
	_wind(g, 0.28)
	var same := true
	var moved := ""
	var r1 := _rects(g)
	for i in r0.size():
		if r0[i] != r1[i]:
			same = false
			moved = "%d번" % i
	_say(same and g.swap_live, "판정 사각은 안 움직인다", moved)

	# ③ 전환 중에는 클릭이 안 먹는다
	var st: int = g.state
	g._click(g.BC)
	g._click(g._mag_rect(0).get_center())
	_say(g.state == st and g.swap_live,
			"전환 중에는 클릭이 안 먹는다", "state %d" % g.state)

	# ⑤ 게임 상태를 한 비트도 안 바꾼다
	var gold0: int = g.gold
	var rn0: int = g.round_no
	var rem0: int = g.remaining.size()
	_wind(g, 0.18)
	_say(g.gold == gold0 and g.round_no == rn0 and g.remaining.size() == rem0,
			"전환은 게임을 안 만진다",
			"골드 %d · 판 %d · %d발" % [g.gold, g.round_no, g.remaining.size()])

	# ⑥ 스스로 끝나고, 끝나면 두 값이 정확히 제자리다
	_wind(g, 0.62)
	_say(not g.swap_live and is_equal_approx(g._swap_rise(), 1.0)
			and is_zero_approx(g._swap_gone()),
			"끝나면 판이 제자리에 선다",
			"선 정도 %.3f · 빠진 정도 %.3f" % [g._swap_rise(), g._swap_gone()])
	_say(is_equal_approx(g._swap_map(100.0), 100.0),
			"끝나면 눕힘이 항등이다", "y100 → %.3f" % g._swap_map(100.0))

	# ⑦ 돌아오는 길 — 같은 함수가 반대로 돈다
	g.state = g.S.CLEAR
	g._click(Vector2(320.0, 200.0))
	_say(g.swap_live and not g.swap_in and g.state == g.S.SHOP
			and is_equal_approx(g._swap_rise(), 1.0)
			and is_equal_approx(g._swap_gone(), 1.0),
			"돌아올 때는 선 판·빠진 테이블에서 시작",
			"선 %.3f · 빠진 %.3f" % [g._swap_rise(), g._swap_gone()])
	# 돌아오는 길에서는 테이블이 판을 덮으므로 순서가 반대다 — 테이블이
	# 화면에 발을 들이는 프레임에는 판이 이미 다 누워 있어야 한다.
	var hi := 360.0
	while g.swap_live:
		if float(g.SWAP.dx) * g._swap_gone() < g.VIEW.x:
			hi = minf(hi, g._swap_map(g.BC.y - g.R * 1.13))
		g._process(1.0 / 60.0)
	_say(hi >= 360.0, "테이블이 들 때 판은 이미 화면 밖이다",
			"판 윗변 최고 y %.1f" % hi)
	_wind(g, 0.02)
	_say(not g.swap_live and g.state == g.S.SHOP,
			"돌아오는 길도 스스로 끝난다", "state %d" % g.state)

	# ③' 아무 키나 누르면 건너뛴다 — 잠긴 채로 못 나오는 자리를 안 만든다
	g.round_no = 1
	g._open_blind()
	g._click(g._blind_go().get_center())
	_key(g, KEY_SPACE)
	_say(not g.swap_live, "아무 키나 누르면 건너뛴다")

	# ⑧ 소크는 아예 안 켠다 — 켜면 소크와 사람이 다른 게임을 한다
	g._swap_skip()
	g.drop_fast = true
	g.round_no = 1
	g._open_blind()
	g._swap_begin(true)
	_say(not g.swap_live, "소크는 연출을 안 켠다")
	g.drop_fast = false

	# ⑧' 테이블 화면이 아니면 안 켠다
	g.state = g.S.PICK
	g._swap_begin(true)
	_say(not g.swap_live, "테이블에서 온 것이 아니면 안 켠다")
	g.state = g.S.TITLE
	g._swap_begin(false)
	_say(not g.swap_live, "돌아올 곳이 상점이 아니면 안 켠다")

	print("
%s" % ("실패 %d건" % fails if fails > 0 else "열여덟 검사 전부 통과"))
	quit(mini(fails, 125))
