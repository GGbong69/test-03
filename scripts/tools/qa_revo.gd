extends SceneTree

# 「정조준」 해금 — 기획서 s27 「[리볼버] 조준 상태에서 모든 다트를 볼스아이에」.
# 표만 맞으면 안 된다. 실제로 **그렇게만** 열리는지 돌려서 본다.
#
#   godot --path . --headless --script scripts/tools/qa_revo.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.path = "user://_qa_revo.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-34s %s" % ["통과" if c else "실패", n, d])


# 한 발이 다 정산될 때까지 돌린다. 판이 안 끝나는 경우(목표를 크게 잡은
# 검사)에도 서야 하므로 "끝난 상태" 가 아니라 **"정산 중이 아닌 상태"** 로 센다.
func _settle() -> void:
	for i in 1500:
		g._process(1.0 / 60.0)
		var busy2: bool = (g.state == g.S.CONFIRM or g.state == g.S.FLY
				or g.state == g.S.RESOLVE)
		if not busy2:
			return


func _throw(p: Vector2) -> void:
	g.state = g.S.CONFIRM
	g.confirm_t = 99.0
	g.aim = p
	g._process(1.0 / 60.0)
	_settle()


# 불 한가운데. hit_info 에게 물어 확인한다 — 짐작하지 않는다.
func _bull() -> Vector2:
	return g.BC


func _off_bull() -> Vector2:
	for k in 720:
		var a: float = float(k) * TAU / 720.0
		var p: Vector2 = g.BC + Vector2(cos(a), sin(a)) * 60.0
		if int(g.hit_info(p).idx) >= 0:
			return p
	return Vector2(-1.0, -1.0)


# 판 하나를 돌린다. 목표를 아주 크게 잡아 **던지는 동안은 안 끝나게** 하고,
# 다 던진 뒤에 목표를 낮춰 「넘긴 판」으로 친다. 전에는 목표를 1 로 두어
# 첫 발에 판이 끝나 버렸고, 그래서 「한 발 빗나가면」 검사가 둘째 발을
# 아예 안 던졌다 — 게임이 아니라 자가 틀렸던 자리다.
func _leg(aim_mode: String, spots: Array) -> void:
	g.leg_no = 1
	g._start_leg()
	g.aim_mode = aim_mode
	g.target = 9999999
	for p in spots:
		_throw(p)
	g.target = 1                      # 넘긴 판으로 친다
	g._finish_leg()


func _process(_d: float) -> bool:
	if g != null: g.set_process(false)
	if busy: return false
	busy = true
	_run()
	return false


func _run() -> void:
	for i in 8:
		g._process(1.0 / 60.0)
	print("\n정조준 해금 검사 — 리볼버로 전탄 볼스아이\n")

	var bull := _bull()
	var off := _off_bull()
	_ok("불 한가운데를 찾았다", int(g.hit_info(bull).idx) == -1,
			"idx %d · mult %d" % [g.hit_info(bull).idx, g.hit_info(bull).mult])
	_ok("불이 아닌 칸을 찾았다", int(g.hit_info(off).idx) >= 0,
			"칸 %d" % g.hit_info(off).sector)

	# ① 기본 조준으로 불만 맞힌다 — 안 열려야 한다
	Save.wipe()
	_leg("std", [bull])
	_ok("기본 조준으로 불만 맞혀도 안 선다", Save.stat("revo_bull_leg") == 0,
			"revo_bull_leg %d" % Save.stat("revo_bull_leg"))

	# ② 리볼버인데 불을 놓친 발이 있다 — 안 열려야 한다
	Save.wipe()
	_leg("kick", [bull, off])
	_ok("리볼버라도 한 발 빗나가면 안 선다", Save.stat("revo_bull_leg") == 0,
			"revo_bull_leg %d" % Save.stat("revo_bull_leg"))

	# ③ 리볼버로 던진 것이 전부 불이다 — 열려야 한다
	Save.wipe()
	_leg("kick", [bull])
	var got := Save.stat("revo_bull_leg")
	_ok("리볼버로 전탄 불이면 선다", got == 1, "revo_bull_leg %d" % got)

	# ④ 한 발도 안 던진 판은 안 센다
	Save.wipe()
	g.leg_no = 1
	g._start_leg()
	g.aim_mode = "kick"
	g.total = 999
	g.target = 1
	g._finish_leg()
	_ok("한 발도 안 던진 판은 안 센다", Save.stat("revo_bull_leg") == 0,
			"revo_bull_leg %d" % Save.stat("revo_bull_leg"))

	# ⑤ 판이 새로 서면 처음부터 — 지난 판의 실패가 안 넘어온다
	Save.wipe()
	_leg("kick", [off])                       # 더럽힌 판
	_leg("kick", [bull])                      # 깨끗한 판
	_ok("판마다 처음부터 센다", Save.stat("revo_bull_leg") == 1,
			"revo_bull_leg %d" % Save.stat("revo_bull_leg"))

	# ⑥ 누적 볼스아이로는 안 열린다 — 전에 이 자리가 bulls 150 이었다
	Save.wipe()
	for i in 200:
		Save.bump("bulls")
	_ok("볼스아이를 200발 쌓아도 안 선다", Save.stat("revo_bull_leg") == 0,
			"bulls %d · revo_bull_leg %d"
			% [Save.stat("bulls"), Save.stat("revo_bull_leg")])

	# ⑦ 해금 문이 그 열쇠를 본다
	var row := {}
	for r in GameData.rows("items"):
		if String(r.get("name", "")) == "정조준":
			row = r
	_ok("표가 그 열쇠를 가리킨다",
			String(row.get("unlock_stat", "")) == "revo_bull_leg"
			and int(row.get("unlock_v", "0")) == 1,
			"%s %s" % [row.get("unlock_stat", ""), row.get("unlock_v", "")])

	print("\n%s\n" % ("전부 통과" if fail == 0 else "실패 %d건" % fail))
	print("통과 %d · 실패 %d" % [okn, fail])
	quit(0 if fail == 0 else 1)
