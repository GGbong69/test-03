extends SceneTree
# 보스 판 흑백 TV(2026-10-10 · game.gd BOSSTV · shaders/bosstv.gdshader) — 못 박는 것:
#   ① 모양(_btv_pose) — 처음 0 에서 in 동안 흑백으로 떨어지고 · hold 동안 흑백 그대로 ·
#      out 의 flick 몫에서 색이 돌아오려다(back) 다시 꺼지고 · 끝에서 0.
#   ② 미끄럼은 처음에 가장 크고 slip_t 에 0 · 떨림은 잦아들어 jit_hold 로 남는다 ·
#      띠는 위 밖에서 아래 밖으로 한 번 굴러간다.
#   ③ 보스 판만 튼다 — _begin_leg 의 보스 갈래에만 _btv_begin 이 있다(소스).
#   ④ 검사 도구 · 화면 없는 실행은 안 탄다(btv_force 없이 btv_live 가 안 선다).
#   ⑤ 판을 떠나면 곧장 걷힌다.
#   godot --headless --path . --script scripts/tools/qa_bosstv.gd
const Save = preload("res://scripts/save.gd")
var g = null
var ok := 0
var bad := 0
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_qa_bosstv_g.cfg"
	Save.path = "user://_qa_bosstv.cfg"
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


func _run() -> void:
	var B: Dictionary = g.BOSSTV
	var t_in: float = float(B["in"])
	var t_out: float = t_in + float(B.hold)
	var t_end: float = g._btv_len()
	var fl: Array = B.flick
	var out: float = float(B.out)

	# ①
	_ok("① 처음은 원래 색", is_zero_approx(float(g._btv_pose(0.0).bw)))
	_ok("① in 이 지나면 흑백", is_equal_approx(float(g._btv_pose(t_in).bw), 1.0))
	_ok("① hold 가운데도 흑백", is_equal_approx(float(g._btv_pose((t_in + t_out) * 0.5).bw), 1.0))
	var kf: float = (float(fl[0]) + float(fl[1])) * 0.5
	var bf: float = float(g._btv_pose(t_out + out * kf).bw)
	_ok("① flick 몫에서 색이 돌아오려 한다", is_equal_approx(bf, float(B.back)), "%.2f" % bf)
	var ba: float = float(g._btv_pose(t_out + out * (float(fl[1]) + 0.01)).bw)
	_ok("① 그 뒤 다시 꺼진다", ba > 0.95, "%.2f" % ba)
	_ok("① 끝에서 원래 색", float(g._btv_pose(t_end).bw) < 0.001)

	# ②
	var s0: float = float(g._btv_pose(0.0).slip)
	_ok("② 미끄럼은 처음에 가장 크다", is_equal_approx(s0, float(B.slip)), "%.3f" % s0)
	_ok("② slip_t 에 미끄럼이 멎는다", is_zero_approx(float(g._btv_pose(float(B.slip_t)).slip)))
	var jh: float = float(g._btv_pose(t_in + float(B.jit_t)).jit)
	_ok("② 떨림은 jit_hold 로 남는다", is_equal_approx(jh, float(B.jit_hold)), "%.2f" % jh)
	_ok("② 띠는 위 밖에서", float(g._btv_pose(0.0).roll) < 0.0)
	_ok("② 아래 밖으로 굴러간다", float(g._btv_pose(float(B.roll_t)).roll) > 1.0)

	# ③
	var src := FileAccess.get_file_as_string("res://scripts/game.gd")
	var a := src.find("func _begin_leg() -> void:")
	var b := src.find("\nfunc ", a + 10)
	var body := src.substr(a, b - a)
	var early := body.find("if not GameData.is_boss(leg_no):")
	var ret := body.find("return", early)
	var call := body.find("_btv_begin()")
	_ok("③ _begin_leg 에 _btv_begin 이 있다", call > 0)
	_ok("③ 보통 판은 그 앞에서 돌아간다(보스 갈래에만)", early > 0 and ret > early and call > ret)
	_ok("③ 다른 자리에서는 안 튼다", src.count("_btv_begin()") == 1)

	# ④
	g._new_run()
	g.tut_run = false
	g.btv_force = false
	g._btv_begin(0.0)
	_ok("④ 검사 도구는 안 탄다", not g.btv_live)

	# ⑤
	g.btv_live = true
	g.btv_t = 0.2
	g.state = g.S.SHOP
	g._btv_tick(0.016)
	_ok("⑤ 판을 떠나면 곧장 걷힌다", not g.btv_live)
