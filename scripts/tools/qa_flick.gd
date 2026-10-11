extends SceneTree
# 시작화면 불 깜박(2026-10-11 · game.gd FLICK) — 못 박는 것:
#   ① 박자 목록은 늘어나는 때 · 짝수 개(켜진 채 끝난다)
#   ② 제목에 서 있으면 간판 · 램프 사건이 온다(40초에 간판 넷 이상 · 램프 둘 이상)
#   ③ 사건이 끝나면 글자 일곱 다 켜짐 · 번짐 1 · 램프 1 · 그늘 0
#   ④ 글자 하나 사건 — 그 글자만 꺼지고 번짐 6/7 · 통째 사건 — 다 꺼지고 번짐 0
#   ⑤ 간판 사건은 대개 낡은 관 하나다 · 통째는 가끔
#   ⑥ 램프가 떨면 그늘이 진다(바닥 몫만큼) · 판 위 반사 · 손잡이 반짝이 그 몫만큼 준다
#   ⑦ 움직임 끔 · 문이 열리는 중 · 제목 밖(인트로)이면 안 떤다 — 사건이 있었으면 곧장 걷는다
#   ⑧ 개발자 모드 「시작화면 불 깜박」 — 제목에서 통째 · 램프 사건을 지금 세운다 · 밖에서는 false
#   ⑨ 문 3D 의 밖의 빛 둘(Lamp · Neon)이 몫만큼 내려가고 1 이면 제 빛으로 돌아온다
#   godot --headless --path . --script scripts/tools/qa_flick.gd
const Save = preload("res://scripts/save.gd")
const Door3D = preload("res://scripts/door3d.gd")
var g = null
var ok := 0
var bad := 0
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_qa_flick_g.cfg"
	Save.path = "user://_qa_flick.cfg"
	Save.prof_fmt = "user://_qa_flick_%d.cfg"
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
	print("  %s %-48s %s" % ["통과" if cond else "실패", nm, note])


func _title() -> void:
	g.state = g.S.TITLE
	g.motion_off = false
	g.door_t = -1.0
	g.door_fresh = 0
	g.flk_n = {}
	g.flk_l = {}
	g.flk_weak = -1


func _all_lit() -> bool:
	for i in 7:
		if not g._flk_letter(i):
			return false
	return true


func _run() -> void:
	var F: Dictionary = g.FLICK
	var D := 1.0 / 60.0

	# ①
	var good := true
	for key in ["neon_pat", "whole_pat", "lamp_pat"]:
		for pat in F[key]:
			if (pat as Array).size() % 2 != 0:
				good = false
			for i in range(1, (pat as Array).size()):
				if float(pat[i]) <= float(pat[i - 1]):
					good = false
	_ok("① 박자 — 늘어나는 때 · 짝수 개", good)

	# ②
	seed(7)
	_title()
	var n_ev := 0
	var l_ev := 0
	var off_fr := 0
	var dim_fr := 0
	var had_n := false
	var had_l := false
	for i in 2400:
		g._flk_tick(D)
		var hn: bool = not g.flk_n.is_empty()
		var hl: bool = not g.flk_l.is_empty()
		if hn and not had_n:
			n_ev += 1
		if hl and not had_l:
			l_ev += 1
		had_n = hn
		had_l = hl
		if not _all_lit():
			off_fr += 1
		if g._flk_lamp() < 1.0:
			dim_fr += 1
	_ok("② 40초 — 간판 사건 넷 이상", n_ev >= 4, "%d" % n_ev)
	_ok("② 40초 — 램프 사건 둘 이상", l_ev >= 2, "%d" % l_ev)
	_ok("② 꺼진 글자 · 떨어진 램프 틀이 있다", off_fr > 0 and dim_fr > 0, "%d · %d" % [off_fr, dim_fr])
	_ok("② 그래도 대부분은 켜져 있다", off_fr < 2400 / 5 and dim_fr < 2400 / 10, "%d · %d" % [off_fr, dim_fr])

	# ③
	var guard := 0
	while (not g.flk_n.is_empty() or not g.flk_l.is_empty()) and guard < 600:
		g._flk_tick(D)
		guard += 1
	_ok("③ 끝나면 글자 일곱 다 켜짐", _all_lit())
	_ok("③ 끝나면 번짐 1 · 램프 1 · 그늘 0",
			g._flk_neon() == 1.0 and g._flk_lamp() == 1.0 and g._flk_shade() == 0.0)

	# ④
	_title()
	g.flk_weak = 2
	g.flk_n = {"t": 0.0, "pat": [0.0, 0.1], "who": 2}
	var only := true
	for i in 7:
		if g._flk_letter(i) != (i != 2):
			only = false
	_ok("④ 글자 하나 — 그 글자만 꺼진다", only)
	_ok("④ 글자 하나 — 번짐 6/7", is_equal_approx(g._flk_neon(), 6.0 / 7.0), "%.3f" % g._flk_neon())
	g.flk_n = {"t": 0.0, "pat": [0.0, 0.1], "who": -1}
	var none := true
	for i in 7:
		if g._flk_letter(i):
			none = false
	_ok("④ 통째 — 다 꺼지고 번짐 0", none and g._flk_neon() == 0.0)
	g.flk_n.t = 0.1
	_ok("④ 두 번째 뒤바뀜에서 다시 켜진다", _all_lit() and g._flk_neon() == 1.0)

	# ⑤
	seed(11)
	_title()
	g.flk_weak = 4
	var whole := 0
	var weak := 0
	var N := 600
	for i in N:
		var ev: Dictionary = g._flk_neon_ev()
		if int(ev.who) < 0:
			whole += 1
		elif int(ev.who) == 4:
			weak += 1
	_ok("⑤ 대개 낡은 관 하나", float(weak) / N > 0.5, "%d/%d" % [weak, N])
	_ok("⑤ 통째는 가끔", float(whole) / N > 0.1 and float(whole) / N < 0.35, "%d/%d" % [whole, N])

	# ⑥
	_title()
	g.flk_l = {"t": 0.0, "pat": [0.0, 0.1], "lo": 0.25}
	_ok("⑥ 램프가 떨면 몫이 바닥까지", is_equal_approx(g._flk_lamp(), 0.25))
	_ok("⑥ 그늘 = (1 − 몫) × shade", is_equal_approx(g._flk_shade(), 0.75 * float(F.shade)),
			"%.3f" % g._flk_shade())
	var src: String = FileAccess.get_file_as_string("res://scripts/game.gd")
	_ok("⑥ 판 위 램프 빛 · 반사 획 · 손잡이 반짝이 몫을 받는다",
			src.contains("float(DOORB.top_a) * lk") and src.contains("float(DOORB.spec_a) * lk")
			and src.contains("0.60 * sin(ph * PI) * _flk_lamp()"))
	_ok("⑥ 판 · 자루 · 간판 판자 · 칠판 · 분필이 그늘을 받는다",
			src.contains("_flk_board_shade()   #") and src.contains("_ttly_draw(1.0 - _flk_shade())")
			and src.contains("_flk_shade() * float(FLICK.chalk)") and src.contains("draw_rect(r.grow(fw), Color(0.0, 0.0, 0.0, fs))"))

	# ⑦
	_title()
	g.motion_off = true
	g.flk_n = {"t": 0.0, "pat": [0.0, 0.1], "who": -1}
	g._flk_tick(D)
	var quiet: bool = g.flk_n.is_empty() and _all_lit()
	for i in 2400:
		g._flk_tick(D)
		if not g.flk_n.is_empty() or not g.flk_l.is_empty():
			quiet = false
	_ok("⑦ 움직임 끔 — 안 떤다 · 있던 사건을 걷는다", quiet)
	_title()
	g.flk_l = {"t": 0.0, "pat": [0.0, 0.1], "lo": 0.2}
	g.door_t = 0.1
	g._flk_tick(D)
	_ok("⑦ 문이 열리는 중 — 걷는다", g.flk_l.is_empty() and g._flk_lamp() == 1.0)
	_title()
	g.state = g.S.INTRO
	var q2 := true
	for i in 2400:
		g._flk_tick(D)
		if not _all_lit():
			q2 = false
	_ok("⑦ 인트로 — 안 떤다", q2)

	# ⑧
	_title()
	_ok("⑧ 제목 — 지금 세운다", g._flk_now() and not g.flk_n.is_empty() and not g.flk_l.is_empty())
	_ok("⑧ 통째 · 램프가 곧장 꺼진 몫", g._flk_neon() == 0.0 and g._flk_lamp() < 1.0)
	g.state = g.S.SHOP
	g.flk_n = {}
	g.flk_l = {}
	_ok("⑧ 제목 밖 — false", not g._flk_now())
	var dsrc: String = FileAccess.get_file_as_string("res://scripts/dev.gd")
	_ok("⑧ 개발자 모드 줄 · 갈래", dsrc.contains("\"a\": \"flk\"") and dsrc.contains("g._flk_now()"))

	# ⑨
	var vp := SubViewport.new()
	var rt := Node3D.new()
	rt.name = "Door"
	vp.add_child(rt)
	var la := SpotLight3D.new()
	la.name = "Lamp"
	rt.add_child(la)
	var ne := OmniLight3D.new()
	ne.name = "Neon"
	rt.add_child(ne)
	root.add_child(vp)
	Door3D.door_lights(vp, 0.25, 0.0)
	var le: float = float(Door3D.LOOK.lamp_e)
	var nee: float = float(Door3D.LOOK.neon_e)
	_ok("⑨ 몫만큼 내려간다", is_equal_approx(la.light_energy, le * 0.25) and ne.light_energy == 0.0,
			"%.2f · %.2f" % [la.light_energy, ne.light_energy])
	Door3D.door_lights(vp, 1.0, 1.0)
	_ok("⑨ 1 이면 제 빛", is_equal_approx(la.light_energy, le) and is_equal_approx(ne.light_energy, nee))
	vp.queue_free()
