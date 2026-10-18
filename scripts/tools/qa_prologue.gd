extends SceneTree
#  프롤로그(game.gd PLGP · scripts/prologue3d.gd · 2026-10-18) — 창이 있어야 돈다. 못 박는 것:
#    ① 켜면 인트로 단(INTRO) 안에서 프롤로그가 돌고, 층이 걷히기(handoff) 전까지 CRT · VHS · 도트 층이
#       꺼져 있다(TV 밖) · 무대 · 층은 도트 화판 밖(screen_host)에 선다
#    ② 브라운관은 프롤로그 동안 안 켜진다 · 인트로 시계는 주인공이 켜지기(feed_at) 전엔 안 가고 그 뒤로 간다
#    ③ 끝까지 가면 무대가 걷히고 필터가 되살아나며 인트로가 끊김 없이 이어진다(처음으로 안 돌아간다)
#    ④ 누름 — lock 앞은 안 먹고, 첫 누름은 빨리 감기(인트로도), 둘째 누름은 곧장 끝 — 주인공이 켜지기 전이면
#       인트로가 처음부터(브라운관 켜짐 연출은 검사 도구에서 _cine_ok 가 건너뛴다)
#    ⑤ 주인공(게임 TV)이 화판 그림을 틀고(mode 9 · 화판 텍스처) 카메라가 그 유리 앞에서 멎는다 · 크레딧은
#       엑스트라 TV 한 대(흐리지 않다) · 나머지 엑스트라 화면은 어둡다
#    ⑥ 주인공 조작판 — 다이얼 둘 · 슬라이더가 따로 붙고, 켜지기 전엔 슬라이더가 밑에 있다가 제 자리로 오르고
#       켜진 뒤로 다이얼 둘이 돌아 있다
#    ⑦ 영화 TV(첫 빛 TV 포함) — 첫 · 둘째 채널을 다 모아도 겹치는 장면이 없다(켤 때마다 섞인다)
#    ⑧ 둘레 TV 는 다 제작자 TV 보다 뒤에 선다(초점에서 비켜 살짝 흐리다) · 화면이 주인공 · 제작자보다 어둡다
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
var game_on := false
var moved := false
var slid_low := false
var slid_up := false
var early_intro := false
var late_intro := 0.0
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
				_ok("① 무대 · 층은 화판 밖에 선다", g.plg_vp.get_parent() == b)
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
				_ok("⑥ 조작판 — 다이얼 둘 · 슬라이더", (g.plg_vp.get_meta("parts") as Dictionary).size() == 3)
				var firsts := []
				var two_ok := true
				for tv in g.plg_vp.get_meta("tvs"):
					if String(tv.job).begins_with("reel"):
						firsts.append(String(tv.ch[0]))
						two_ok = two_ok and String(tv.ch[0]) != String(tv.ch[1])
				var uniq := {}
				for k in firsts:
					uniq[k] = true
				_ok("⑦ 영화 TV — 첫 채널이 다 다르다", firsts.size() >= 5 and uniq.size() == firsts.size(), str(firsts))
				var mz := 0.0
				for e in g.Plg.PILE:
					if String(e[6]) == "maker":
						mz = float(e[2])
				var back_ok := true
				for e in g.Plg.PILE:
					var jb: String = e[6]
					if jb not in ["game", "maker", ""] and float(e[2]) > mz - 0.05:
						back_ok = false
				_ok("⑧ 둘레 TV 는 제작자 TV 보다 뒤", back_ok)
				_ok("⑧ 둘레 화면은 어둡다", float(g.Plg.EXTRA.dim) < 0.2 and float(g.Plg.REEL.dim) < 0.2)
				_ok("⑦ 둘째 채널은 첫 채널과 다르다", two_ok)
				var all_ch := {}
				var n_ch := 0
				for tv in g.plg_vp.get_meta("tvs"):
					if String(tv.job).begins_with("reel"):
						all_ch[String(tv.ch[0])] = true
						all_ch[String(tv.ch[1])] = true
						n_ch += 2
				_ok("⑦ 첫 · 둘째 채널을 다 모아도 겹치는 장면이 없다(어느 때든 두 화면에 같은 장면이 안 뜬다)",
						all_ch.size() == n_ch, "%d / %d" % [all_ch.size(), n_ch])
				st = 1
		1:
			if g._plg_live() and g.plg_t > g.Plg.length() - 0.2:
				for tv in g.plg_vp.get_meta("tvs"):
					if tv.hero:
						var hm := tv.m as ShaderMaterial
						var pv = hm.get_shader_parameter("pw")
						game_on = pv != null and float(pv) > 0.9 and int(hm.get_shader_parameter("mode")) == 9 								and hm.get_shader_parameter("tex") is ViewportTexture
				var ps: Dictionary = g.plg_vp.get_meta("parts")
				moved = true
				for pn in ["HeroKnobA", "HeroKnobB"]:
					var pd: Dictionary = ps[pn]
					moved = moved and not (pd.n as Node3D).transform.is_equal_approx(pd.xf)
				var cam := g.plg_vp.get_meta("cam") as Camera3D
				cam_d = cam.global_position.distance_to((g.plg_vp.get_meta("end") as Dictionary).at)
			if g._plg_live() and g.plg_t < g.Plg.feed_at() - 0.3:
				var sd: Dictionary = (g.plg_vp.get_meta("parts") as Dictionary).HeroSlider
				slid_low = (sd.n as Node3D).transform.origin.y < (sd.xf as Transform3D).origin.y - 0.05
			if g._plg_live() and g.plg_t > g.Plg.length() - 0.2:
				var sd2: Dictionary = (g.plg_vp.get_meta("parts") as Dictionary).HeroSlider
				slid_up = (sd2.n as Node3D).transform.is_equal_approx(sd2.xf)
			if g._plg_live():
				if g._plg_cover():
					seen_crt = seen_crt or g.crt_layer.visible or g.vhs_rect.visible or g.dot_rect.visible
				seen_pwr = seen_pwr or g.pwr_t >= 0.0
				if g.plg_t < g.Plg.feed_at() - 0.05:
					early_intro = early_intro or g.intro_t > 0.0
				else:
					late_intro = g.intro_t
			else:
				_ok("⑤ 주인공이 화판 그림을 튼다", game_on)
				_ok("⑥ 켜진 뒤 다이얼 둘이 돌아 있다", moved)
				_ok("⑥ 슬라이더 — 켜지기 전엔 밑 · 끝엔 제 자리", slid_low and slid_up)
				_ok("⑤ 끝에 카메라가 게임 TV 유리 앞", cam_d < 0.02, "%.3f" % cam_d)
				_ok("① 층이 걷히기 전엔 CRT · VHS · 도트가 꺼져 있다", not seen_crt)
				_ok("② 브라운관은 안 켜진다", not seen_pwr)
				_ok("② 인트로 시계 — 주인공이 켜지기 전엔 안 가고 그 뒤로 간다", not early_intro and late_intro > 2.0,
						"%.2f" % late_intro)
				_ok("③ 끝 — 무대가 걷힌다", g.plg_vp == null)
				_ok("③ 끝 — 필터가 되살아난다", g.crt_layer.visible and g.vhs_rect.visible and g.dot_rect.visible)
				_ok("③ 끝 — 인트로가 이어진다", g.state == g.S.INTRO and g.intro_t >= late_intro - 0.01,
						"intro %.2f" % g.intro_t)
				st = 2
				f = 0
		2:
			if f == 30:
				g._plg_begin()
				g._intro_press()
				_ok("④ lock 앞 누름은 안 먹는다", g._plg_live() and not g.plg_ff)
			if f == 60:
				g._intro_press()
				_ok("④ 첫 누름은 빨리 감기(인트로도)", g._plg_live() and g.plg_ff and g.intro_ff)
				g._intro_press()
				_ok("④ 둘째 누름은 곧장 끝 — 주인공 전이면 인트로가 처음부터", not g._plg_live() and g.plg_vp == null
						and g.state == g.S.INTRO and g.intro_t == 0.0)
				print("통과 %d · 실패 %d" % [ok, bad])
				quit(1 if bad > 0 else 0)
	if f > 2000:
		print("  시간 끝")
		quit(1)
	return false
