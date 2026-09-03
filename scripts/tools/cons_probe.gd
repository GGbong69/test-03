extends SceneTree

const GameData = preload("res://scripts/data.gd")

# ══════════════════════════════════════════════════════════
#  사탕 — 어느 화면에서 실제로 써지는가
#
#  실행:  godot --path . --headless --quit-after 120000 -s scripts/tools/cons_probe.gd
#
#  "PICK 화면에서 안 쓰인다" 는 보고를 확인한다. 코드를 읽는 대신
#  누르고 떼는 두 사건을 그대로 보내서 트랙 레벨이 오르는지만 본다.
# ══════════════════════════════════════════════════════════

var g: Node = null
var frames := 0
var done := false


func _initialize() -> void:
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)
	seed(1)


func _press(p: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	e.position = p
	g._unhandled_input(e)


func _release(p: Vector2) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = false
	e.position = p
	g._unhandled_input(e)


func _try(label: String) -> void:
	var cp := GameData.consumables()
	var c: Dictionary = {}
	for x in cp:
		if String(x.get("cat", "")) == "area":
			c = x
			break
	g.cons = [c]
	var tk: int = int(c.track)
	var before: int = int(g.track_lv.get(tk, 0))
	var r: Rect2 = g._cons_rect(0)
	var m: Vector2 = r.get_center()
	_press(m)
	_release(m)
	var after: int = int(g.track_lv.get(tk, 0))
	print("  %-10s  칸 좌표 %s · 손 상태 %d · 트랙 %d→%d · 남은 소비 %d  →  %s"
			% [label, str(m), g.hand_st, before, after, g.cons.size(),
			"쓰인다" if after > before else "**안 쓰인다**"])
	g.cons.clear()


func _process(_d: float) -> bool:
	frames += 1
	if done:
		quit(0)
		return true
	# 오토플레이로 판까지 굴린 뒤 상태를 직접 세워서 각 화면을 시험한다.
	g.set_process(false)
	g._process(1.0 / 60.0)
	if frames < 30:
		return false

	print("사탕 사용 — 화면별")
	g._autoplay = false
	var states := {
		"SHOP": g.S.SHOP, "PICK": g.S.PICK, "AIM_V": g.S.AIM_V,
		"LEG": g.S.LEG, "STAGE": g.S.STAGE, "CLEAR": g.S.CLEAR,
	}
	for k in states:
		g.state = states[k]
		g.hand_st = 0
		g.swap_live = false
		_try(k)
	done = true
	return false
