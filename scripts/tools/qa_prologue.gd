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
#    ⑨ 앞 토막 — 비디오테이프를 넣는 손(2026-10-22 · Plg TAPE). TV 방의 때가 TAPE_LEN 뒤로 섰다 · 카세트는 데크 안에서
#       끝난다(등이 덮개 뒤 · 내려앉았다) · 덮개가 열렸다 닫혔다(등이 지나간 뒤에 닫히기 시작) · 손끝이 앞판을 안 뚫는다 ·
#       손은 눈이 오르기 전에 그림 밖으로 빠졌다 · 표시등이 빨강 → 초록 · 앞 토막 소리 넷이 한 번씩(제 자리 넷) ·
#       눈이 TV 더미가 켜지기 전에 cam_start 에 닿는다 · 다 쓴 손 · 카세트 · 빛 한 줄기는 걷힌다 · 창밖 비는 제 자리
#       (Rain 버스 · 표 소리와 다른 사본)에서 돌다 끝에 걷힌다 · 일찍 끊어도 소리 자리가 안 남는다
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
var flap_max := 0.0          # 앞 토막 — 덮개가 가장 젖혀진 각(도)
var flap_end := 99.0         # 철컥 뒤 덮개 각
var tape_in := false         # 철컥 뒤 카세트가 데크 안(등이 덮개 뒤 · 내려앉음)
var poke := 0.0              # 손끝이 앞판(구멍 밖)을 뚫은 가장 깊은 m
var hand_out := false        # 눈이 오르기 직전 손이 다 그림 밖
var hand_seen := false       # 그 틀을 쟀다
var led0 := false            # 철컥 전 표시등이 빨강
var led1 := false            # 철컥 뒤 초록
var snd_n := -1              # 철컥 뒤 앞 토막 소리 자리 수
var cam_at := -1.0           # TV 더미가 켜지기 전 눈과 cam_start 의 거리(가장 먼 것 · 안 쟀으면 −1)
var cam_fov := true
var freed := false           # 눈이 오른 뒤 손 · 카세트 · 빛 한 줄기가 걷혔다
var rain_on := false         # 앞 토막 동안 비가 돌았다


func _initialize() -> void:
	Save.gpath = "user://_qa_plg_g.cfg"
	Save.path = "user://_qa_plg.cfg"
	Save.prof_fmt = "user://_qa_plg_%d.cfg"
	Save.wipe()
	b = load("res://scenes/boot.tscn").instantiate()
	root.add_child(b)


#  앞 토막 — 틀마다 잰다(⑨). 덮개 각은 노드 변환에서 되읽는다(glb 자리에 대한 x 축 돌림).
func _tape_watch() -> void:
	var P = g.Plg
	var TP: Dictionary = P.TAPE
	var t: float = g.plg_t
	var hn: Node = g.plg_vp
	var TL: float = float(P.TAPE_LEN)
	var ck: float = float(TP.clunk)
	if t < TL and g.plg_rain != null and g.plg_rain.playing:
		rain_on = true
	var fl: Dictionary = hn.get_meta("flap")
	var rel: Basis = (fl.xf as Transform3D).basis.inverse() * (fl.n as Node3D).transform.basis
	var dn: Vector3 = rel * Vector3.DOWN
	var fa: float = rad_to_deg(atan2(-dn.z, -dn.y))
	if t < ck - float(TP.lead) - float(TP.snap):
		flap_max = maxf(flap_max, fa)
	elif t > ck + 0.3 and t < TL:
		flap_end = fa
	var dk := hn.get_meta("deck") as Node3D
	var di: Transform3D = dk.global_transform.affine_inverse()
	var dm: Dictionary = hn.get_meta("deck_m")
	var led := dm.led_deck as StandardMaterial3D
	if t > 1.5 and t < ck - 0.05:
		led0 = led.emission.is_equal_approx(TP.led[0]) and led.emission_energy_multiplier > 0.5
	if t > ck + float(TP.led_gap) + 0.05 and t < TL:
		led1 = led.emission.is_equal_approx(TP.led[1]) and led.emission_energy_multiplier > 0.5
		if t > ck + 0.1:
			snd_n = g.plg_aud.size()
	var cr: Array = TP.crane
	if hn.has_meta("tape"):
		var tp: Dictionary = hn.get_meta("tape")
		var tx: Transform3D = (tp.n as Node3D).transform
		if t > ck + 0.05:
			tape_in = tx.origin.z + (TP.tape as Vector3).z * 0.5 < float(TP.hinge) - 0.001 \
					and tx.origin.y < (TP.slot as Vector3).y - float(TP.drop) * 0.9
		var hj: Dictionary = tp.hj
		var pts := []
		for tn in hj.tips:
			pts.append((tn as Node3D).global_position)
		pts.append((hj.ttip as Node3D).global_position)
		var sl: Vector3 = TP.slot
		var ho: Vector2 = TP.hole
		for p in pts:
			var q: Vector3 = di * p
			if absf(q.x - sl.x) > ho.x * 0.5 or absf(q.y - sl.y) > ho.y * 0.5:
				poke = maxf(poke, -q.z)
		if t > float(TP.leave[1]) and t < float(cr[0]):
			var cam := hn.get_meta("cam") as Camera3D
			var vs: Vector2 = (hn.get_meta("vp") as SubViewport).size
			pts.append((hj.root as Node3D).global_position)
			var fo: Node3D = tp.fo.root
			for k in [0.0, 0.5, 1.0]:
				pts.append(fo.global_transform * Vector3(k, 0.0, 0.0))
			hand_seen = true
			hand_out = true
			for p in pts:
				var sp: Vector2 = cam.unproject_position(p)
				hand_out = hand_out and (cam.is_position_behind(p) or sp.x > vs.x + 30.0 or sp.x < -30.0
						or sp.y > vs.y + 30.0 or sp.y < -30.0)
	if t >= TL and t < float(P.ON.tvs):
		var cam2 := hn.get_meta("cam") as Camera3D
		cam_at = maxf(cam_at, cam2.global_position.distance_to((hn.get_meta("start") as Dictionary).at))
		cam_fov = cam_fov and is_equal_approx(cam2.fov, float(P.CAM.fov))
	if t > TL + 0.1 and t < float(P.ON.tvs):
		freed = not hn.has_meta("tape") and not hn.has_meta("key") and dk.get_node_or_null("Tape") == null \
				and dk.get_node_or_null("Arm") == null


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
				var P = g.Plg
				var TP: Dictionary = P.TAPE
				var TL: float = float(P.TAPE_LEN)
				_ok("⑨ TV 방의 때가 앞 토막 뒤로 섰다", float(P.ON.tvs) > TL and P.feed_at() > TL and P.handoff() > TL
						and P.length() >= TL + 6.0 and float(P.REEL.tune) > TL and float(P.T.push0) > TL)
				_ok("⑨ 눈이 다 오른 뒤에 TV 더미가 켜진다", float(TP.crane[1]) <= TL and float(P.ON.tvs) > float(TP.crane[1]))
				var shut: float = float(TP.clunk) - float(TP.lead)
				var spine: float = P._tape_at(shut - float(TP.snap)).origin.z + (TP.tape as Vector3).z * 0.5
				_ok("⑨ 덮개는 카세트 등이 지나간 뒤에 닫히기 시작한다", spine < float(TP.hinge) - 0.0015, "등 z %.4f" % spine)
				var cu: Dictionary = P.cues()
				var tape_snd := ["tape_rattle", "tape_in", "deck_whir", "deck_clunk"]
				var cu_ok: bool = cu.has("rain") and cu.has("hero") and cu.has("tvs") and cu.has("maker")
				for k in tape_snd:
					cu_ok = cu_ok and cu.has(k) and float(cu[k]) < TL and g._sfx_file(k) != null
				_ok("⑨ 소리 때 — 비 · TV · 앞 토막 넷(파일이 있다)", cu_ok, str(cu.keys()))
				_ok("⑨ 철컥 소리의 쿵이 TAPE.clunk 에 선다", is_equal_approx(float(cu.deck_clunk) + float(TP.lead), float(TP.clunk)))
				_ok("⑨ 손 · 카세트 · 덮개 · 빛 한 줄기가 섰다", g.plg_vp.has_meta("tape") and g.plg_vp.has_meta("key")
						and not (g.plg_vp.get_meta("flap") as Dictionary).is_empty() and g.plg_vp.has_meta("vfd_l"))
				_ok("⑨ 비 자리가 섰다(Rain 버스 · 표 소리와 다른 사본)", g.plg_rain != null and g.plg_rain.bus == "Rain"
						and AudioServer.get_bus_index("Rain") >= 0 and g.plg_rain.stream != g._sfx_file("rain"))
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
				_tape_watch()
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
				_ok("⑨ 덮개가 열렸다(카세트가 밀고 든다)", flap_max > 60.0, "%.1f°" % flap_max)
				_ok("⑨ 철컥 뒤 덮개가 닫혀 있다", absf(flap_end) < 0.5, "%.2f°" % flap_end)
				_ok("⑨ 카세트는 데크 안에서 끝난다(등이 덮개 뒤 · 내려앉음)", tape_in)
				_ok("⑨ 손끝이 앞판(구멍 밖)을 안 뚫는다", poke < 0.002, "%.4f m" % poke)
				_ok("⑨ 손은 눈이 오르기 전에 그림 밖으로 빠졌다", hand_seen and hand_out)
				_ok("⑨ 표시등 — 철컥 전 빨강 · 뒤 초록", led0 and led1)
				_ok("⑨ 앞 토막 소리 넷이 한 번씩(제 자리 넷)", snd_n == 4, str(snd_n))
				_ok("⑨ TV 더미가 켜지기 전에 눈이 cam_start 에 닿았다(화각도)", cam_at >= 0.0 and cam_at < 0.001 and cam_fov,
						"%.4f" % cam_at)
				_ok("⑨ 다 쓴 손 · 카세트 · 빛 한 줄기를 걷었다", freed)
				_ok("⑨ 비가 돌다가 끝에 걷혔다", rain_on and g.plg_rain == null and g.plg_aud.is_empty())
				st = 2
				f = 0
		2:
			if f == 30:
				g._plg_begin()
				g._intro_press()
				_ok("④ lock 앞 누름은 안 먹는다", g._plg_live() and not g.plg_ff)
			if f == 60:
				#  잠금(lock)은 시계로 잰다 — 틀 수가 아니라. 손 · 카세트 짓기가 든 뒤로 서른 틀이 0.65 초를 못 채운다.
				g.plg_t = maxf(g.plg_t, float(g.PLGP.lock) + 0.01)
				g._intro_press()
				_ok("④ 첫 누름은 빨리 감기(인트로도)", g._plg_live() and g.plg_ff and g.intro_ff, "%.2f" % g.plg_t)
				#  철컥 뒤(위잉이 도는 중)로 건너 소리 넷을 낸 뒤 끊는다 — 3.6 초 위잉이 인트로에 새면 안 된다
				g.plg_t = float(g.Plg.TAPE.clunk) + 0.1
				g._plg_tick(0.0)
				var mid_n: int = g.plg_aud.size()
				g._intro_press()
				_ok("④ 둘째 누름은 곧장 끝 — 주인공 전이면 인트로가 처음부터", not g._plg_live() and g.plg_vp == null
						and g.state == g.S.INTRO and g.intro_t == 0.0)
				_ok("⑨ 일찍 끊어도 비 · 앞 토막 소리 자리가 안 남는다", mid_n == 4 and g.plg_rain == null and g.plg_aud.is_empty(),
						"끊기 전 %d" % mid_n)
				print("통과 %d · 실패 %d" % [ok, bad])
				quit(1 if bad > 0 else 0)
	if f > 2000:
		print("  시간 끝")
		quit(1)
	return false
