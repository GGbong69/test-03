extends SceneTree

# 딱정벌레의 도로 — 「연속으로 맞춘 두 숫자의 합이 11이면 배수 ×4」.
# 기획서 s25. items.csv u31 · 새 조건 sum11.
#
#   godot --path . --headless --script scripts/tools/qa_sum11.gd

const GameData = preload("res://scripts/data.gd")
const Save = preload("res://scripts/save.gd")

var g = null
var busy := false
var okn := 0
var fail := 0


func _initialize() -> void:
	Save.path = "user://_qa_sum11.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	g.set_process(false)


func _ok(n: String, c: bool, d := "") -> void:
	if c: okn += 1
	else: fail += 1
	print("  %s %-34s %s" % ["통과" if c else "실패", n, d])


func _ctx(sum: int) -> Dictionary:
	return {"sector": 3, "mult": 1, "miss": false, "missp": false, "idx": 2,
			"col": 0, "same": false, "pair_sum": sum}


func _settle() -> void:
	for i in 1200:
		g._process(1.0 / 60.0)
		if g.state == g.S.PICK or g.state == g.S.CLEAR or g.state == g.S.OVER:
			return


# 칸 번호 → 그 칸에 꽂히는 좌표. 각도 식을 짐작하지 않고 실측으로 찾는다 —
# hit_info 가 정본이므로 그것에게 물어본다.
func _spot(sec: int) -> Vector2:
	for k in 720:
		var a: float = float(k) * TAU / 720.0
		var p: Vector2 = g.BC + Vector2(cos(a), sin(a)) * 60.0
		if int(g.hit_info(p).sector) == sec:
			return p
	return Vector2(-1.0, -1.0)


# 한 발을 그 자리에 꽂는다.
func _throw(p: Vector2) -> void:
	g.state = g.S.CONFIRM
	g.confirm_t = 99.0
	g.aim = p
	g._process(1.0 / 60.0)
	_settle()


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

	print("\n딱정벌레의 도로 검사 — 합이 11\n")

	# ① 조건 자체
	_ok("합 11 이면 선다", GameData.check("sum11", _ctx(11)))
	_ok("합 9 면 안 선다", not GameData.check("sum11", _ctx(9)))
	_ok("합 12 면 안 선다", not GameData.check("sum11", _ctx(12)))
	_ok("합 0(칸 밖) 이면 안 선다", not GameData.check("sum11", _ctx(0)))

	# ② 등록
	_ok("CONDS 에 있다", GameData.CONDS.has("sum11"))
	_ok("이름이 있다", GameData.cond_text("sum11") != ""
			and GameData.cond_tag("sum11") != "",
			"%s / %s" % [GameData.cond_text("sum11"), GameData.cond_tag("sum11")])

	# ③ 표
	var it := {}
	for x in GameData.items():
		if String(x.id) == "u31": it = x
	_ok("u31 이 켜져 있고 sum11 이다", not it.is_empty()
			and String(it.get("c", "")) == "sum11",
			"%s · cond '%s' · %s" % [String(it.get("n", "?")),
					String(it.get("c", "")), GameData.eff_line(it)])

	# ④ 실제 투척 — pair_sum 이 만들어지는가
	print("")
	# 합이 11 이 되는 짝 하나(3 + 8)와 안 되는 짝 하나(20 + 1)
	g._start_leg()
	var p3 := _spot(3)
	var p8 := _spot(8)
	var p20 := _spot(20)
	_ok("칸을 겨냥할 수 있다", p3.x >= 0.0 and p8.x >= 0.0 and p20.x >= 0.0)
	_throw(p3)
	var l1: int = g.last_sector
	_throw(p8)
	_ok("3 뒤에 8 — 합 11 이 잡힌다", l1 == 3 and g.last_sector == 8,
			"%d → %d" % [l1, g.last_sector])
	g._start_leg()
	_throw(p20)
	var l2: int = g.last_sector
	_throw(p3)
	_ok("20 뒤에 3 — 합 23 이라 안 선다", l2 == 20 and g.last_sector == 3,
			"%d → %d" % [l2, g.last_sector])

	# ⑤ 첫 발은 직전이 없어 안 선다
	g._start_leg()
	_ok("판이 서면 직전이 없다", g.last_sector == -1, str(g.last_sector))

	# ⑥ 검증기가 안 쓰는 조건으로 안 센다
	var warns := GameData.warnings()
	var unused := ""
	for w in warns:
		if String(w).find("안 쓰는 조건") >= 0: unused = String(w)
	_ok("안 쓰는 조건 목록에 없다", unused.find("sum11") < 0,
			unused.substr(0, 60))

	print("\n통과 %d · 실패 %d" % [okn, fail])
	quit(mini(fail, 125))
