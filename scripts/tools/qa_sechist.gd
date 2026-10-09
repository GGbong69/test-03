extends SceneTree
# 연속사진 — 숫자별 맞힌 수를 동전이 쥔다(2026-10-08 · per sechist) — 못 박는 것:
#   ① 같은 숫자면 싱글 · 더블 · 트리플을 안 가리고 같이 쌓인다(20 · 20 더블 · 20 트리플 → 3).
#   ② 다른 숫자는 따로 쌓인다 · 불은 안쪽 · 바깥쪽이 하나(25)다.
#   ③ 수량은 이번 발을 포함한 그 숫자의 맞힌 수 × 값이다.
#   ④ 빗나감은 안 센다.
#   ⑤ 이어하기 — 저장했다 되살려도 숫자별 맞힌 수가 그대로다.
#   ⑥ 문구 「맞힌 숫자를 지금까지 맞힌 1발당 배수 +1」.
#   godot --headless --path . --script scripts/tools/qa_sechist.gd
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
var g = null
var ok := 0
var bad := 0
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_qa_sechist_g.cfg"
	Save.path = "user://_qa_sechist.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


func _process(_d: float) -> bool:
	if g != null:
		g.set_process(false)
	if busy:
		return false
	busy = true
	_run()
	print("통과 %d · 실패 %d" % [ok, bad])
	quit(1 if bad > 0 else 0)
	return false


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-50s %s" % ["통과" if cond else "실패", nm, note])


func _coin() -> Dictionary:
	for it in GameData.items():
		if String(it.id) == "c36":
			var c: Dictionary = (it as Dictionary).duplicate()
			c.erase("w")
			c.gs = 0
			c.bought = 0
			return c
	return {}


#  판 위 한 점 — 칸 idx 의 띠 band(s 바깥 싱글 · d 더블 · t 트리플).
func _at(val: int, band: String) -> Vector2:
	var i: int = g.sectors.find(val)
	return g._ember_at(i, band)


func _throw(p: Vector2) -> Dictionary:
	g.state = g.S.RESOLVE
	g.aim = p
	g.queue = []
	g.burst_hits = []
	g._land()
	return g.last_ctx


func _run() -> void:
	g._new_run()
	g.tut_run = false
	g._open_leg()
	g._begin_leg()
	g.target = 999999
	g.darts.clear()
	g.cur_dart = GameData.darts()[0].duplicate()
	var c := _coin()
	_ok("표에 연속사진(per sechist)이 있다", String(c.get("per", "")) == "sechist")
	g.owned = [c]
	g._panel_reset()
	var o: Dictionary = g.owned[0]

	# ①
	_throw(_at(20, "s"))
	_throw(_at(20, "d"))
	var x := _throw(_at(20, "t"))
	var hd: Dictionary = o.get("hist", {})
	_ok("① 20 · 20 더블 · 20 트리플이 같이 쌓인다", int(hd.get(20, 0)) == 3, str(hd))
	# ③
	var amt: int = GameData.item_amt(o, x)
	_ok("③ 수량은 그 숫자의 맞힌 수(이번 발 포함) × 값", amt == int(o.v) * 3,
			"%d (값 %s)" % [amt, o.v])

	# ②
	_throw(_at(5, "t"))
	hd = o.get("hist", {})
	_ok("② 다른 숫자는 따로", int(hd.get(5, 0)) == 1 and int(hd.get(20, 0)) == 3, str(hd))
	_throw(g.BC)
	_throw(g.BC + Vector2(g.R * (g.rt_bull_i + g.rt_bull_o) * 0.5, 0.0))
	hd = o.get("hist", {})
	_ok("② 불은 안쪽 · 바깥쪽이 하나(25)", int(hd.get(25, 0)) == 2, str(hd))

	# ④
	var before := str(o.get("hist", {}))
	_throw(g.BC + Vector2(g.R * 1.5, 0.0))
	_ok("④ 빗나감은 안 센다", str(o.get("hist", {})) == before)

	# ⑤
	g._swap_skip()
	g.state = g.S.PICK
	g._knot("leg")
	g.owned = []
	g._run_load()
	var o2: Dictionary = g.owned[0] if not g.owned.is_empty() else {}
	var h2: Dictionary = o2.get("hist", {})
	_ok("⑤ 이어하기 — 숫자별 맞힌 수가 그대로", int(h2.get(20, 0)) == 3 and int(h2.get(5, 0)) == 1
			and int(h2.get(25, 0)) == 2, str(h2))

	# ⑥
	var line: String = GameData.eff_line(c)
	_ok("⑥ 문구 — 숫자 · 지금까지", line.begins_with("맞힌 숫자를 지금까지 맞힌 1발당"), line)
