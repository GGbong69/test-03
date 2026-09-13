extends SceneTree

# 녹는 시계 — 「판 종료시 남은 다트는 다음 판으로 이월한다」. 기획서 s27.
# 해금은 「보드 확장[시계]를 장착하고 연속 보드 아웃 3회」.
#
#   godot --path . --headless --script scripts/tools/qa_carry.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.path = "user://_qa_carry.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-34s %s" % ["통과" if c else "실패", n, d])


func _clock() -> Dictionary:
	for it in GameData.items():
		if String(it.id) == "l05":
			return it
	return {}


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	g._new_run()
	g._swap_skip()
	for i in 20:
		g._process(1.0 / 60.0)

	print("\n녹는 시계 검사\n")

	# ① 표
	var it := _clock()
	_ok("l05 가 켜져 있다", not it.is_empty(), String(it.get("n", "없다")))
	_ok("side 가 carry 다", String(it.get("side", "")) == "carry",
			String(it.get("side", "")))
	_ok("해금이 clok_out_streak 3 이다",
			String(it.get("ustat", "")) == "clok_out_streak"
			and int(it.get("uv", 0)) == 3,
			"%s %d" % [String(it.get("ustat", "")), int(it.get("uv", 0))])
	_ok("설명이 이월을 말한다",
			GameData.eff_line(it).find("다음 판") >= 0, GameData.eff_line(it))
	_ok("통계 열쇠가 등록돼 있다",
			GameData.Save_STATS.has("clok_out_streak") and Save.STATS.has("clok_out_streak")
			and Save.PEAKS.has("clok_out_streak"))

	# ② 안 들었을 때 — 이월 없다
	print("")
	g.owned = []
	g._start_leg()
	var base: int = g.darts_left
	while g.remaining.size() > 2:
		g.remaining.pop_back()
	g.darts_left = g.remaining.size()
	g._finish_leg()
	_ok("안 들면 안 담는다", g.carry_darts == 0, "carry %d" % g.carry_darts)
	g._start_leg()
	_ok("안 들면 다트가 그대로", g.darts_left == base,
			"%d (기본 %d)" % [g.darts_left, base])

	# ③ 들었을 때 — 잔탄만큼 는다
	g.owned = [_clock().duplicate()]
	g._start_leg()
	while g.remaining.size() > 2:
		g.remaining.pop_back()
	g.darts_left = g.remaining.size()
	g._finish_leg()
	_ok("들면 잔탄을 담는다", g.carry_darts == 2, "carry %d" % g.carry_darts)
	g._start_leg()
	_ok("다음 판에 그만큼 는다", g.darts_left == base + 2,
			"%d (기본 %d + 2)" % [g.darts_left, base])

	# ④ 한 번만 먹는다
	_ok("푼 뒤 0 으로 돌아간다", g.carry_darts == 0, "carry %d" % g.carry_darts)
	g._start_leg()
	_ok("그다음 판은 안 는다", g.darts_left == base,
			"%d (기본 %d)" % [g.darts_left, base])

	# ⑤ 해금 통계 — 시계를 낀 채 연속 보드 아웃 3회
	print("")
	Save.wipe()
	g.owned = []
	g.mods_own = ["clok"]
	g._start_leg()
	g.state = g.S.PICK
	var out: Vector2 = g.BC + Vector2(0.0, -240.0)     # 판 밖
	for i in 3:
		g.state = g.S.CONFIRM
		g.confirm_t = 99.0
		g.aim = out
		g._process(1.0 / 60.0)
		for k in 1200:
			g._process(1.0 / 60.0)
			if g.state == g.S.PICK or g.state == g.S.CLEAR or g.state == g.S.OVER:
				break
	_ok("시계를 끼고 세 번 빗나가면 3", Save.stat("clok_out_streak") >= 3,
			"clok_out_streak %d · clok_out %d"
			% [Save.stat("clok_out_streak"), g.clok_out])

	# 시계를 안 끼면 안 오른다
	Save.wipe()
	g.mods_own = []
	g._start_leg()
	for i in 3:
		g.state = g.S.CONFIRM
		g.confirm_t = 99.0
		g.aim = out
		g._process(1.0 / 60.0)
		for k in 1200:
			g._process(1.0 / 60.0)
			if g.state == g.S.PICK or g.state == g.S.CLEAR or g.state == g.S.OVER:
				break
	_ok("시계를 안 끼면 안 오른다", Save.stat("clok_out_streak") == 0,
			"clok_out_streak %d" % Save.stat("clok_out_streak"))

	# 판이 새로 서면 0
	g.mods_own = ["clok"]
	g.clok_out = 2
	g._start_leg()
	_ok("판이 새로 서면 끊긴다", g.clok_out == 0, "clok_out %d" % g.clok_out)

	print("\n통과 %d · 실패 %d" % [okn, fail])
	quit(mini(fail, 125))
