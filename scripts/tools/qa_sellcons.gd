extends SceneTree
# 사탕·사진 판매(2026-10-08 · game.gd _sell_cons) — 못 박는 것:
#   ① 상점에서 사탕·사진 칸의 것을 판매 창구로 끌어다 놓으면 팔린다 — 칸에서 빠지고 판매가만큼 골드.
#   ② 판매가는 동전과 같은 식(GameData.sell_value)이다.
#   ③ 가운데로 끌어 놓으면 여전히 쓴다(파는 길이 쓰는 길을 안 막는다).
#   ④ 상점 밖(판 위)에서는 판매 창구가 없어 안 팔린다.
#   godot --headless --path . --script scripts/tools/qa_sellcons.gd
const Save = preload("res://scripts/save.gd")
const GameData = preload("res://scripts/data.gd")
var g = null
var ok := 0
var bad := 0
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_qa_sellcons_g.cfg"
	Save.path = "user://_qa_sellcons.cfg"
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


func _row(id: String) -> Dictionary:
	for c in GameData.consumables():
		if String(c.get("id", "")) == id:
			return (c as Dictionary).duplicate()
	return {}


#  칸 i 의 것을 집어 to 로 끌고 가 놓는다. 헤드리스는 마우스 버튼이 늘 떼어져 있어
#  _hand_update 를 못 돌리므로(qa_clone 머리말) 걸음이 정할 창구 값만 먹인다.
func _drag(i: int, to: Vector2, zone: int) -> void:
	var from: Vector2 = g._cons_rect(i).get_center()
	g._hand_press(from)
	for k in range(1, 9):
		g._hand_motion(from.lerp(to, float(k) / 8.0))
	g.hand_zone = zone
	g._hand_release(to)


func _run() -> void:
	g._new_run()
	g.tut_run = false
	g.gold = 20
	g._open_shop()
	g._swap_skip()

	# ①②
	var redo := _row("v_redo")
	_ok("표에 또 같은 아침이 있다", not redo.is_empty())
	g.cons = [redo]
	var g0: int = g.gold
	var want: int = GameData.sell_value(redo)
	var sell_at := Vector2(6.0, float(g.TBL.fy) + 12.0)
	_ok("판매 창구 자리", g._chute_at(sell_at, 0.0) == g.Z_SELL)
	_drag(0, sell_at, g.Z_SELL)
	_ok("① 판매 창구에 놓으면 칸에서 빠진다", g.cons.is_empty())
	_ok("② 판매가만큼 골드(동전과 같은 식)", g.gold - g0 == want and want > 0,
			"+%d (sell_value %d)" % [g.gold - g0, want])

	# ③
	g.cons = [_row("v_cash")]
	var g1: int = g.gold
	_drag(0, g._use_spot(), -1)
	_ok("③ 가운데로 놓으면 여전히 쓴다", g.cons.is_empty() and g.gold > g1,
			"골드 %d → %d" % [g1, g.gold])

	# ④
	g._open_leg()
	g._swap_skip()
	g._begin_leg()
	g._swap_skip()
	g.state = g.S.PICK
	g.cons = [_row("v_par")]
	_ok("④ 판 위에서는 팔 수 없다", not g._cons_sellable())
	_drag(0, sell_at, g.Z_SELL)
	_ok("④ 놓아도 칸에 남는다", g.cons.size() == 1)
