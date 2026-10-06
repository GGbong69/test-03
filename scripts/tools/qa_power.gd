extends SceneTree
# 브라운관 켜기 · 끄기(2026-10-06 · game.gd PWR) — 못 박는 것:
#   ① 틀 수 없는 실행(검사 도구 · 헤드리스)에서 끄기는 기다리지 않고 곧장 cb 다 — 「종료」가
#      안 늦는다. 켜기는 층을 안 세운다.
#   ② 켜기는 PWR.on_t 에 끝나고 층을 숨긴다. 그동안 인트로 시계는 안 간다.
#   ③ 끄기는 PWR.off_t 에 cb 를 **한 번** 부른다. 그동안 입력을 안 받는다.
#   ④ 한 틀이 길어도(굽기 · 첫 셰이더) 시계는 1/30 초씩만 간다 — 줄이 뻗는 것을 안 건너뛴다.
#   ⑤ 끄는 중에 한 번 더 닫으면 기다리지 않는다(_pwr_quit 의 두 번째 부름).
#   godot --headless --path . --script scripts/tools/qa_power.gd
const Save = preload("res://scripts/save.gd")
var g = null
var ok := 0
var bad := 0


func _initialize() -> void:
	Save.gpath = "user://_qa_power_g.cfg"
	Save.path = "user://_qa_power.cfg"
	Save.wipe()
	g = load("res://scenes/main.tscn").instantiate()
	root.add_child(g)


#  _initialize 안에서는 루트가 아직 나무에 안 들어가 Game 의 _ready(층을 세운다)가
#  안 돌았다 — 첫 틀에서 잰다(qa_crt 와 같은 길).
var busy := false


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
	print("  %s %-40s %s" % ["통과" if cond else "실패", nm, note])


#  _cine_ok 를 건너 손으로 세운다 — 도구에서는 연출이 안 트므로 시계만 잰다.
func _force(on: bool, cb := Callable()) -> void:
	g.pwr_t = 0.0
	g.pwr_on = on
	g.pwr_cb = cb
	g._pwr_set(0.0)
	g.pwr_layer.visible = true


func _run() -> void:
	_ok("층이 섰다", g.pwr_layer != null and g.pwr_rect != null)
	_ok("켤 때 층은 숨어 있다(도구는 안 튼다)", not g.pwr_layer.visible and g.pwr_t < 0.0)

	# ① 곧장 cb
	var hits := [0]
	g._pwr_start(false, func() -> void: hits[0] += 1)
	_ok("① 도구에서 끄기는 곧장 cb", hits[0] == 1 and g.pwr_t < 0.0, "cb %d" % hits[0])

	# ② 켜기 — 인트로가 기다린다
	g._intro_begin()
	_force(true)
	var t := 0.0
	while g.pwr_t >= 0.0 and t < 3.0:
		g._intro_tick(1.0 / 60.0)
		g._pwr_tick(1.0 / 60.0)
		t += 1.0 / 60.0
	var want: float = float(g.PWR.on_t)
	_ok("② 켜기가 제 길이에 끝난다", absf(t - want) < 0.04, "%.3f초 · 표 %.2f" % [t, want])
	_ok("② 다 켜면 층이 숨는다", not g.pwr_layer.visible)
	_ok("② 켜는 동안 인트로 시계가 안 갔다", g.intro_t <= 1.0 / 60.0 + 0.0001,
			"intro_t %.3f" % g.intro_t)
	g._intro_tick(1.0 / 60.0)
	_ok("② 다 켠 뒤 인트로가 간다", g.intro_t > 0.0)
	g.state = g.S.TITLE

	# ③ 끄기 — cb 한 번 · 입력 막힘
	hits[0] = 0
	_force(false, func() -> void: hits[0] += 1)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = g._menu_rect(1).get_center()
	var st0: int = g.state
	g._unhandled_input(ev)
	_ok("③ 끄는 동안 누름이 안 먹는다", g.state == st0, "state %d → %d" % [st0, g.state])
	t = 0.0
	while g.pwr_t >= 0.0 and t < 3.0:
		g._pwr_tick(1.0 / 60.0)
		t += 1.0 / 60.0
	for i in 10:
		g._pwr_tick(1.0 / 60.0)
	want = float(g.PWR.off_t)
	_ok("③ 끄기가 제 길이에 끝난다", absf(t - want) < 0.04, "%.3f초 · 표 %.2f" % [t, want])
	_ok("③ cb 를 한 번만 부른다", hits[0] == 1, "cb %d" % hits[0])
	_ok("③ 끈 화면은 검게 남는다(층이 선 채)", g.pwr_layer.visible)
	g.pwr_layer.visible = false

	# ④ 긴 틀
	_force(true)
	g._pwr_tick(2.0)
	_ok("④ 2초짜리 틀 하나에도 1/30 초만 간다", absf(g.pwr_t - 1.0 / 30.0) < 0.0001,
			"%.4f" % g.pwr_t)
	g.pwr_t = -1.0
	g.pwr_layer.visible = false

	# ⑤ 두 번째 닫기
	#  진짜로 부르면 도구가 닫히므로 길만 읽는다.
	_ok("⑤ 끄는 중 두 번째 부름은 곧장 닫는 길이다",
			g.has_method("_pwr_quit") and String(g.get_script().source_code).contains(
			"if pwr_t >= 0.0 and not pwr_on:\n\t\tget_tree().quit()"))
