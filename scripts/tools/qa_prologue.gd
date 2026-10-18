extends SceneTree
#  프롤로그(game.gd PLGP · scripts/prologue3d.gd · 2026-10-18) — 창이 있어야 돈다. 못 박는 것:
#    ① 켜면 인트로 단(INTRO) 안에서 프롤로그가 돌고, 그동안 CRT · VHS · 도트 층이 꺼져 있다(TV 밖)
#    ② 브라운관은 프롤로그 동안 안 켜진다 · 인트로 시계도 안 간다
#    ③ 끝까지 가면 무대가 걷히고 필터가 되살아나며 인트로가 처음부터 돈다(브라운관 켜짐 연출은 검사 도구에서
#       _cine_ok 가 건너뛴다 — pwr_t 는 −1 그대로)
#    ④ 누름 — lock 앞은 안 먹고, 첫 누름은 빨리 감기, 둘째 누름은 곧장 끝
#    ⑤ 주인공(게임 TV)은 끝까지 꺼져 있고 카메라가 그 유리 앞에서 멎는다 · 크레딧은 엑스트라 TV 한 대
#       (흐리지 않다) · 나머지 엑스트라 화면은 어둡다
#   godot --path . --script scripts/tools/qa_prologue.gd
const Save = preload("res://scripts/save.gd")
var b = null
var g = null
var f := 0
var ok := 0
var bad := 0
var st := 0
var seen_crt := false
var seen_pwr := false
var seen_intro := false
var game_off := false
var cam_d := 99.0


func _initialize() -> void:
	Save.gpath = "user://_qa_plg_g.cfg"
	Save.path = "user://_qa_plg.cfg"
	Save.prof_fmt = "user://_qa_plg_%d.cfg"
	Save.wipe()
	b = load("res://scenes/boot.tscn").instantiate()
	root.add_child(b)


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-46s %s" % ["통과" if cond else "실패", nm, note])


func _process(_d: float) -> bool:
	f += 1
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 프롤로그가 선다")
		quit(0)
		return false
	match st:
		0:
			if f == 10:
				g = b.game
				g.crt = g.CRT_DEF
				g.vhs = 0.3
				g.dot = 0.3
				g.warp = g.WARP_DEF
				g._plg_begin()
				_ok("① 인트로 단 안에서 돈다", g.state == g.S.INTRO and g._plg_live())
				var heroes := []
				var makers := []
				var dim_ok := true
				for tv in g.plg_vp.get_meta("tvs"):
					var dv = (tv.m as ShaderMaterial).get_shader_parameter("dim")
					var dm: float = 1.0 if dv == null else float(dv)
					if tv.hero:
						heroes.append(String(tv.job))
					elif String(tv.job) == "maker":
						makers.append(dm)
					else:
						dim_ok = dim_ok and dm < 0.5
				_ok("⑤ 주인공 하나 — 게임 TV", heroes == ["game"], str(heroes))
				_ok("⑤ 크레딧은 엑스트라 TV 한 대 · 흐리지 않다", makers == [1.0], str(makers))
				_ok("⑤ 나머지 엑스트라 화면은 어둡다", dim_ok)
				_ok("⑤ 카메라가 다가갈 유리가 있다", not (g.plg_vp.get_meta("end") as Dictionary).is_empty())
				st = 1
		1:
			if g._plg_live() and g.plg_t > g.Plg.length() - 0.2:
				for tv in g.plg_vp.get_meta("tvs"):
					if tv.hero:
						var pv = (tv.m as ShaderMaterial).get_shader_parameter("pw")
						game_off = pv == null or float(pv) == 0.0
				var cam := g.plg_vp.get_meta("cam") as Camera3D
				cam_d = cam.global_position.distance_to((g.plg_vp.get_meta("end") as Dictionary).at)
			if g._plg_live():
				seen_crt = seen_crt or g.crt_layer.visible or g.vhs_rect.visible or g.dot_rect.visible
				seen_pwr = seen_pwr or g.pwr_t >= 0.0
				seen_intro = seen_intro or g.intro_t > 0.0
			else:
				_ok("⑤ 주인공은 끝까지 꺼져 있다", game_off)
				_ok("⑤ 끝에 카메라가 게임 TV 유리 앞", cam_d < 0.02, "%.3f" % cam_d)
				_ok("① 프롤로그 동안 CRT · VHS · 도트가 꺼져 있다", not seen_crt)
				_ok("② 그동안 브라운관 · 인트로 시계가 안 간다", not seen_pwr and not seen_intro)
				_ok("③ 끝 — 무대가 걷힌다", g.plg_vp == null)
				_ok("③ 끝 — 필터가 되살아난다", g.crt_layer.visible and g.vhs_rect.visible and g.dot_rect.visible)
				_ok("③ 끝 — 인트로가 처음부터", g.state == g.S.INTRO and g.intro_t < 0.2, "intro %.2f" % g.intro_t)
				st = 2
				f = 0
		2:
			if f == 30:
				g._plg_begin()
				g._intro_press()
				_ok("④ lock 앞 누름은 안 먹는다", g._plg_live() and not g.plg_ff)
			if f == 60:
				g._intro_press()
				_ok("④ 첫 누름은 빨리 감기", g._plg_live() and g.plg_ff)
				g._intro_press()
				_ok("④ 둘째 누름은 곧장 끝", not g._plg_live() and g.plg_vp == null and g.state == g.S.INTRO)
				print("통과 %d · 실패 %d" % [ok, bad])
				quit(1 if bad > 0 else 0)
	if f > 2000:
		print("  시간 끝")
		quit(1)
	return false
