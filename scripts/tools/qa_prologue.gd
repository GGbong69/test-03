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
#       손은 눈이 오르기 전에 그림 밖으로 빠졌다 · 표시등이 빨강 → 초록 · 앞 토막 소리 다섯이 한 번씩(제 자리 다섯) ·
#       눈이 TV 더미가 켜지기 전에 cam_start 에 닿는다 · 다 쓴 손 · 카세트 · 빛 한 줄기는 걷힌다 · 창밖 비는 제 자리
#       (Rain 버스 · 표 소리와 다른 사본)에서 돌다 끝에 걷힌다 · 일찍 끊어도 소리 자리가 안 남는다
#       재생 단추(2026-10-23 「손가락을 펴서 한번 버튼 클릭하기로 하지 않았어?」) — 단추가 들어갔다 돌아온다 · VFD 재생
#       세모는 누른 뒤에만 든다 · 위잉은 철컥이 아니라 누를 때 · 누를 때 검지가 펴져 단추에 닿고 셋은 말렸다 · 걷은
#       소매 단이 미는 동안 · 누르는 동안 그림 안에 든다
#       다시(2026-10-23 「좀 더 꾹 누르고 테이프도 그냥 빨려가는거 같아」 · 「라이팅이랑 쉐이딩 더 퀄리티 있게」) — 단추가 2.5mm
#       넘게 들어가 바닥에서 버틴다 · 떼면 앞으로 조금 넘쳤다 선다 · 바닥에서 검지 끝마디가 젖는다 · 카세트는 걸려 서고 →
#       낚아채여 확 → 고른 빠르기로 끌리고 → 멎은 뒤 내려앉는다 · 소리 일곱(걸림 딸깍 · 모터) · 키가 그림자를 드리운다(손 ·
#       덮개 · 단추만 — 카세트는 아니다) · 먼지 낀 공기 · 빛줄기 기둥이 섰다 · 층이 걷힐 때 3D 층의 색 · 낟알 · 안개가 다 걷혔다
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
var btn_deep := 0.0          # 단추가 가장 깊이 들어간 m
var btn_back := -1.0         # 다 뗀 뒤 단추가 들어가 있는 m(안 쟀으면 −1)
var play_early := false      # 누르기 전(철컥 뒤)에 VFD 재생 세모가 들었다
var play_late := false       # 누른 뒤 들어 있다
var poke_btn := true         # 바닥에서 검지 끝이 단추에 닿아 있고 검지가 펴졌고 셋은 말렸다(잰 틀마다)
var poke_n := 0
var cuff_out := [0, 0]       # 걷은 소매 단이 그림 밖이던 틀 수 [미는 동안 · 누르는 동안]
var cuff_seen := [0, 0]      # 잰 틀 수
var deep_hold := 0.0         # 단추가 2.5mm 넘게 들어가 있던 동안(초)
var btn_over := 0.0          # 뗀 뒤 단추가 앞으로 넘친 가장 큰 m
var dip_ok := false          # 바닥에서 검지 끝마디가 젖었다
var t_prev := -1.0
var gone_k := -1.0           # handoff 언저리의 3D 층 색 · 낟알 몫(안 쟀으면 −1)
var gone_fog := -1.0         # 그때 안개 밀도


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
	if t < float(TP.shut) - float(TP.snap):
		flap_max = maxf(flap_max, fa)
	elif t > ck + 0.3 and t < TL:
		flap_end = fa
	var dk := hn.get_meta("deck") as Node3D
	var di: Transform3D = dk.global_transform.affine_inverse()
	var dm: Dictionary = hn.get_meta("deck_m")
	var led := dm.led_deck as StandardMaterial3D
	if t > 1.5 and t < ck - 0.05:
		led0 = led.emission.is_equal_approx(TP.led[0]) and led.emission_energy_multiplier > float(TP.led_e) * 0.5
	if t > ck + float(TP.led_gap) + 0.05 and t < TL:
		led1 = led.emission.is_equal_approx(TP.led[1]) and led.emission_energy_multiplier > float(TP.led_e) * 0.5
		if t > ck + 0.1:
			snd_n = g.plg_aud.size()
	#  재생 단추 — 들어갔다 돌아온다 · VFD 재생 세모는 누른 뒤에만
	var pr: Array = TP.press
	var bt: Dictionary = hn.get_meta("btn")
	if not bt.is_empty():
		var bz: float = (bt.xf as Transform3D).origin.z - (bt.n as Node3D).transform.origin.z
		btn_deep = maxf(btn_deep, bz)
		if t > float(pr[4]) + 0.05 and t < TL:
			btn_back = bz
		if bz >= 0.0025 and t_prev >= 0.0:
			deep_hold += t - t_prev
		if t > float(pr[3]):
			btn_over = maxf(btn_over, -bz)
	var pe: float = (dm.vfd_on as StandardMaterial3D).emission_energy_multiplier
	if t > ck + 0.1 and t < float(pr[2]) - 0.02:
		play_early = play_early or pe > float(TP.vfd_e) * 0.5
	if t > float(pr[2]) + 0.02 and t < TL:
		play_late = pe > float(TP.vfd_e) * 0.5
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
		#  누르는 바닥 — 검지 끝이 들어간 단추 앞면에 · 검지는 곧고(너클에서 끝까지 거의 두 마디 길이) · 셋은 말려 끝이
		#  앞판에서 2cm 넘게 떨어졌다
		if t >= float(pr[2]) and t <= float(pr[3]):
			var t0: Vector3 = (hj.tips[0] as Node3D).global_position
			var ln: float = (float(g.FING3.l1[0]) + float(g.FING3.l2[0])) * float(TP.s)
			var pk: bool = (di * t0).distance_to((TP.btn as Vector3) - Vector3(0.0, 0.0, float(TP.sink))) < 0.003 \
					and (hj.j1[0] as Node3D).global_position.distance_to(t0) > ln * 0.9
			for k in range(1, 4):
				pk = pk and (di * (hj.tips[k] as Node3D).global_position).z > 0.02
			poke_btn = poke_btn and pk
			poke_n += 1
			#  힘이 실린 바닥 — 끝마디가 뒤로 젖는다(j2 는 Basis(BACK, −굽힘) — 젖으면 + 각)
			if t >= float(pr[2]) + 0.03:
				dip_ok = dip_ok or (hj.j2[0] as Node3D).basis.get_euler().z > deg_to_rad(5.0)
		#  걷은 소매 단(단의 팔꿈치 쪽 끝) — 미는 동안 · 누르는 동안 무대 화판 안
		var w := -1
		if t >= float(TP.push[0]) and t <= float(TP.push[1]):
			w = 0
		elif t >= float(pr[1]) and t <= float(pr[3]):
			w = 1
		if w >= 0:
			var cm := hn.get_meta("cam") as Camera3D
			var vz: Vector2 = (hn.get_meta("vp") as SubViewport).size
			var rp: Vector3 = (tp.fo.roll as Node3D).global_position
			var rs: Vector2 = cm.unproject_position(rp)
			cuff_seen[w] += 1
			if cm.is_position_behind(rp) or rs.x < 0.0 or rs.x > vz.x or rs.y < 0.0 or rs.y > vz.y:
				cuff_out[w] += 1
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
				and dk.get_node_or_null("Arm") == null and not hn.has_meta("shaft")
	if t >= P.handoff() - 0.03:
		gone_k = float((hn.get_meta("grade") as ShaderMaterial).get_shader_parameter("k"))
		gone_fog = (hn.get_meta("env") as Environment).volumetric_fog_density
	t_prev = t


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
				var shut: float = float(TP.shut)
				var spine: float = P._tape_at(shut - float(TP.snap)).origin.z + (TP.tape as Vector3).z * 0.5
				_ok("⑨ 덮개는 카세트 등이 지나간 뒤에 닫히기 시작한다", spine < float(TP.hinge) - 0.0015, "등 z %.4f" % spine)
				var cu: Dictionary = P.cues()
				var tape_snd := ["tape_rattle", "tape_in", "deck_grab", "deck_motor", "deck_whir", "deck_clunk", "deck_btn"]
				var cu_ok: bool = cu.has("rain") and cu.has("hero") and cu.has("tvs") and cu.has("maker")
				for k in tape_snd:
					cu_ok = cu_ok and cu.has(k) and float(cu[k]) < TL and g._sfx_file(k) != null
				_ok("⑨ 소리 때 — 비 · TV · 앞 토막 일곱(파일이 있다)", cu_ok, str(cu.keys()))
				_ok("⑨ 철컥 소리의 쿵이 TAPE.clunk 에 선다", is_equal_approx(float(cu.deck_clunk) + float(TP.lead), float(TP.clunk)))
				var pb: float = float(TP.press[2])
				_ok("⑨ 단추 딸깍은 바닥에 · 위잉은 철컥이 아니라 누를 때", is_equal_approx(float(cu.deck_btn), pb)
						and float(cu.deck_whir) >= pb and float(cu.deck_whir) < pb + 0.2 and float(cu.deck_whir) > float(TP.clunk) + 0.2,
						"딸깍 %.2f · 위잉 %.2f · 철컥 %.2f" % [float(cu.deck_btn), float(cu.deck_whir), float(TP.clunk)])
				_ok("⑨ 재생 단추가 따로 섰다", not (g.plg_vp.get_meta("btn") as Dictionary).is_empty())
				_ok("⑨ 손 · 카세트 · 덮개 · 빛 한 줄기가 섰다", g.plg_vp.has_meta("tape") and g.plg_vp.has_meta("key")
						and not (g.plg_vp.get_meta("flap") as Dictionary).is_empty() and g.plg_vp.has_meta("vfd_l"))
				_ok("⑨ 비 자리가 섰다(Rain 버스 · 표 소리와 다른 사본)", g.plg_rain != null and g.plg_rain.bus == "Rain"
						and AudioServer.get_bus_index("Rain") >= 0 and g.plg_rain.stream != g._sfx_file("rain"))
				#  카세트 길(순수 함수라 틀 빠르기와 상관없이 잰다) — 걸려 선다 → 낚아채여 확 → 고르게 끌린다 → 멎은 뒤 내려앉는다
				var gb: float = float(TP.grab)
				var mo: Array = TP.motor
				var fz := func(tt: float) -> float: return P._tape_at(tt).origin.z
				var vz := func(tt: float) -> float: return (fz.call(tt + 0.002) - fz.call(tt - 0.002)) / 0.004
				var pause_v := 0.0
				for i in 10:
					pause_v = maxf(pause_v, absf(vz.call(gb - 0.05 + 0.005 * float(i))))
				var jerk_v := 0.0
				for i in 10:
					jerk_v = maxf(jerk_v, absf(vz.call(gb + 0.004 * float(i))))
				var jerk_d: float = fz.call(gb) - fz.call(gb + 0.04)
				var vs := []
				for i in 20:
					vs.append(-vz.call(float(mo[0]) + 0.06 + (2.97 - float(mo[0]) - 0.06) * float(i) / 19.0))
				var vm := 0.0
				for v in vs:
					vm += float(v) / vs.size()
				var vd := 0.0
				for v in vs:
					vd = maxf(vd, absf(float(v) - vm))
				_ok("⑨ 카세트 — 덮개가 걸어 선다(낚아채기 앞)", pause_v < 0.02, "%.3f m/s" % pause_v)
				_ok("⑨ 카세트 — 낚아채여 확(2mm 넘게 · 빠르게)", jerk_d > 0.002 and jerk_v > 0.15,
						"%.1fmm · %.3f m/s" % [jerk_d * 1000.0, jerk_v])
				_ok("⑨ 카세트 — 모터 빠르기로 고르게 끌린다", vm > 0.12 and vm < 0.22 and vd < vm * 0.08,
						"%.3f ± %.3f m/s" % [vm, vd])
				var sy: float = (TP.slot as Vector3).y
				var y_slide: float = P._tape_at(float(TP.fall[0]) - 0.01).origin.y
				var y_end: float = P._tape_at(float(TP.clunk)).origin.y
				_ok("⑨ 카세트 — 끌기가 멎은 뒤 홀더째 내려앉아 철컥", is_equal_approx(y_slide, sy)
						and absf(vz.call(float(TP.fall[0]))) < 0.01 and absf(sy - float(TP.drop) - y_end) < 0.0001
						and float(TP.drop) >= 0.008, "%.1fmm" % ((sy - y_end) * 1000.0))
				var key := g.plg_vp.get_meta("key") as SpotLight3D
				var arm: Node = (g.plg_vp.get_meta("tape") as Dictionary).arm
				var hand_cast := false
				for gi in arm.find_children("*", "GeometryInstance3D", true, false):
					hand_cast = hand_cast or ((gi as GeometryInstance3D).layers & key.shadow_caster_mask) != 0
				#  카세트는 안 드리운다 — 쥔 손가락이 그 그늘에 묻혀 손끝이 털처럼 번졌다(검토)
				var tp_n: Node = (g.plg_vp.get_meta("tape") as Dictionary).n
				_ok("⑨ 키가 무른 그림자를 드리운다(손 · 덮개 · 단추만 — 카세트는 아니다)", key.shadow_enabled
						and key.light_size > 0.0 and hand_cast and (key.shadow_caster_mask & 1) == 0
						and ((tp_n as GeometryInstance3D).layers & key.shadow_caster_mask) == 0)
				var env := g.plg_vp.get_meta("env") as Environment
				var shaft: FogVolume = g.plg_vp.get_meta("shaft") if g.plg_vp.has_meta("shaft") else null
				_ok("⑨ 먼지 낀 공기 · 구석 TV 빛줄기 기둥", env.volumetric_fog_enabled and key.light_volumetric_fog_energy > 0.0
						and shaft != null and (shaft.material as FogMaterial).density > 0.0)
				#  레퍼런스 2차(2026-10-25) — 둘레 TV 대기등이 초점 흐림 · 더하기 번짐에 붉은 원판이 됐다
				var sb: int = g.plg_vp.find_children("Standby", "MeshInstance3D", true, false).size()
				_ok("⑨ 대기등은 크레딧 TV 하나 · 번짐은 덮기 두 단", sb == 1
						and env.glow_blend_mode == Environment.GLOW_BLEND_MODE_SCREEN
						and env.get_glow_level(1) > 0.0 and env.get_glow_level(2) == 0.0, "대기등 %d" % sb)
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
				_ok("⑨ 앞 토막 소리 일곱이 한 번씩(제 자리 일곱)", snd_n == 7, str(snd_n))
				var TP2: Dictionary = g.Plg.TAPE
				_ok("⑨ 재생 단추가 들어갔다(sink) 다 떼면 돌아온다", btn_deep > float(TP2.sink) * 0.9 and btn_back >= 0.0
						and btn_back < 0.0001, "%.4f → %.4f m" % [btn_deep, btn_back])
				_ok("⑨ VFD 재생 세모는 누른 뒤에만 든다", not play_early and play_late)
				_ok("⑨ 꾹 — 단추가 2.5mm 넘게 들어가 바닥에서 버틴다", btn_deep >= 0.0025 and deep_hold >= 0.15,
						"%.1fmm · %.2f초" % [btn_deep * 1000.0, deep_hold])
				_ok("⑨ 꾹 — 떼면 단추가 앞으로 조금 넘쳤다 선다", btn_over > 0.0002 and btn_over < 0.001,
						"%.2fmm" % (btn_over * 1000.0))
				_ok("⑨ 꾹 — 바닥에서 검지 끝마디가 젖는다", dip_ok)
				_ok("⑨ 층이 걷힐 때 3D 층의 색 · 낟알 · 안개가 다 걷혔다", gone_k == 0.0 and gone_fog == 0.0,
						"%.3f · %.4f" % [gone_k, gone_fog])
				_ok("⑨ 누를 때 검지가 펴져 단추에 닿고 셋은 말렸다", poke_n > 0 and poke_btn, "%d 틀" % poke_n)
				_ok("⑨ 걷은 소매 단이 미는 동안 · 누르는 동안 그림 안", cuff_seen[0] > 0 and cuff_seen[1] > 0
						and cuff_out[0] == 0 and cuff_out[1] == 0, "밖 %s / 잰 %s 틀" % [str(cuff_out), str(cuff_seen)])
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
				#  단추를 누른 뒤(위잉이 도는 중)로 건너 소리 일곱을 낸 뒤 끊는다 — 3.6 초 위잉이 인트로에 새면 안 된다
				g.plg_t = float(g.Plg.cues().deck_whir) + 0.1
				g._plg_tick(0.0)
				var mid_n: int = g.plg_aud.size()
				g._intro_press()
				_ok("④ 둘째 누름은 곧장 끝 — 주인공 전이면 인트로가 처음부터", not g._plg_live() and g.plg_vp == null
						and g.state == g.S.INTRO and g.intro_t == 0.0)
				_ok("⑨ 일찍 끊어도 비 · 앞 토막 소리 자리가 안 남는다", mid_n == 7 and g.plg_rain == null and g.plg_aud.is_empty(),
						"끊기 전 %d" % mid_n)
				print("통과 %d · 실패 %d" % [ok, bad])
				quit(1 if bad > 0 else 0)
	if f > 2000:
		print("  시간 끝")
		quit(1)
	return false
