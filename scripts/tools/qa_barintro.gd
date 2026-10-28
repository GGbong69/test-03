extends SceneTree
#  바 인트로(scripts/prologue_bar3d.gd · game.gd PLGP.kind · 2026-10-25) — 창이 있어야 돈다. 못 박는 것:
#    ① 같은 API(make · tick · cues · handoff · feed_at · length) — feed_at < handoff < length · 켤 때 기본은 테이프
#    ② 전역 "plg_kind" 가 bar 면 _plg_begin() 이 바를 튼다 · 인트로 단 안 · 무대 · 층은 화판 밖 · 덮개 동안 필터가 꺼진다
#    ③ 상인 머리(깃 위)는 서 있는 동안 어느 틀에도 그림 안에 안 든다 · TV 빛은 상인 층을 안 비춘다 · 펜던트는 비춘다 ·
#      손목 — 손끝 축이 팔뚝 축에서 35° 안(「손목이 이상하지 않아?」 — 팔 옆에 90° 로 꺾여 붙은 주걱이었다) ·
#      잔을 내려놓는 동안 받치는 손 · 천 꼬리가 카운터 윗면 위(「컵을 잡고 있는손 테이블 뚫는거 알지?」 — 밑을 받친 채 내렸다)
#    ④ TV 그림 간판 — 밀기 동안 앞당겨 켜지고(plg_sign_t) 넘김 뒤 · 끝에 안 남는다
#    ④ 로패스 버스가 섰다가 넘김에 걷히고 · TV 스피커 효과(SFX)도 걷힌다 · 끝까지 가면 인트로가 이어진다
#    ⑤ 누름 — 첫 누름 빨리 감기 · 둘째 누름 끝 → 버스 · 효과 · 무대가 안 남는다
#    ⑧ 런 끝(완주 · 실패)의 「새 런」 — 바를 틀고 끝나면(건너뛰어도) 인트로 나머지 없이 제목 문으로(2026-10-28)
#    ⑥ 개발자 판 — 「바 인트로 보기」 · 「켤 때 인트로」 줄이 있고 그 쪽이 열아홉 줄 안 · 켤 때 인트로 줄이 전역 값을 바꾼다
#    ⑦ 유리 뚫기(테이프 Plg 와 같은 반짝 · 번쩍 · 삐싱 소리는 없다) — 반짝 때(glint_at)가 handoff − GLINT.cue · 밀기가 서는 때 = 뛰어듦 시작 · 빗금은
#      handoff − GLINT.lead 틀에 서고 별은 번쩍 앞에 진다 · 번쩍은 handoff −4 틀 ~ +6 틀만 · 필터는 맨 밝은 틀(lit_at)에 켜지고
#      잔상은 calm_at 까지 0 · handoff 뒤 층은 Flash 만 · TV 스피커는 반짝 틀에 걷혀 있다(게임 필터는 처음 켠 값으로 돈다) ·
#      번쩍 오름 단은 유리 둘레 안(Flash pn)에만 · 인트로 박자(램프는 깜박임 뒤 · 쾅은 건넌 뒤 · 간판 소리는 SIGN.t0) ·
#      LEN(방 소리 꼬리)은 인트로 끝 앞
#   godot --path . --script scripts/tools/qa_barintro.gd
const Save = preload("res://scripts/save.gd")
const Dev = preload("res://scripts/dev.gd")
var b: Node = null
var g: Node = null
var f := 0
var ok := 0
var bad := 0
var st := 0
var head_in := 0           # 상인 깃 위가 그림 안에 든 틀 수
var head_n := 0
var head_t := []           # 그림 안에 든 때 [처음 · 끝]
var wrist_max := 0.0       # 손끝 축 ↔ 팔뚝 축 가장 큰 각(도)
var down_low := INF        # 내려놓는 동안 받치는 손 · 천 꼬리 밑끝 − 카운터 윗면(m) 가장 작은 값
var down_n := 0
var bus_seen := false
var spk_seen := false
var fx0 := 0               # 처음 SFX 효과 수
var cover_ok := true
var late_intro := 0.0
var sign_on := false       # 밀기 동안 간판을 앞당겨 켰나
var sign_late := false     # 넘김 뒤에도 앞당김이 남았나
var early_intro := false
var gl0 := -1.0            # ⑦ 빗금이 처음 선 때 · 별이 마지막으로 선 때 · 번쩍이 처음 · 마지막 선 때 · 필터가 처음 선 때
var sp1 := -1.0
var fl0 := -1.0
var fl1 := -1.0
var lit0 := -1.0
var trail_ok := true       # calm_at 앞 필터가 선 틀은 잔상 0
var cut_ok := true         # handoff 뒤 층에 Flash 말고 선 것이 없다
var spk_late := false      # 반짝이 서고 나서도 TV 스피커가 걸려 있었다
var sign_snd := -1.0       # 인트로 간판 소리가 난 때
var fk0 := -1.0            # 번쩍 오름 단(Flash 를 유리 둘레로 자른 틀 — pn)이 처음 · 마지막 선 때
var fk1 := -1.0


func _initialize() -> void:
	Save.gpath = "user://_bi_qa_g.cfg"
	Save.path = "user://_bi_qa.cfg"
	Save.prof_fmt = "user://_bi_qa_%d.cfg"
	Save.wipe()
	b = load("res://scenes/boot.tscn").instantiate()
	root.add_child(b)


func _ok(nm: String, cond: bool, note := "") -> void:
	if cond:
		ok += 1
	else:
		bad += 1
	print("  %s %-46s %s" % ["통과" if cond else "실패", nm, note])


func _sfx_fx() -> int:
	var bi := AudioServer.get_bus_index("SFX")
	return AudioServer.get_bus_effect_count(bi) if bi >= 0 else 0


func _process(_d: float) -> bool:
	f += 1
	if DisplayServer.get_name() == "headless":
		print("  건너뜀 — 창이 있어야 바 인트로가 선다")
		quit(0)
		return false
	match st:
		0:
			if f == 10:
				g = b.game
				var P = g.PlgBar
				_ok("① 같은 API · 때 차례", P.feed_at() < P.handoff() and P.handoff() < P.length()
						and P.length() < P.feed_at() + float(g.INTRO.end) and P.cues() is Dictionary and g.Plg.length() > 0.0)
				_ok("① 켤 때 기본은 테이프", String(Save.get_set("plg_kind", g.PLGP.kind)) == "tape")
				fx0 = _sfx_fx()
				Save.set_set("plg_kind", "bar")
				#  게임 필터는 처음 켠 값으로(도구는 끈 채 뜬다) — 덮개 · 맨 밝은 틀에 켜지는 것을 잰다
				g.crt = g.CRT_DEF
				g.warp = g.WARP_DEF
				g.vhs = g.VHS_DEF
				g.dot = g.DOT_DEF
				g._plg_begin()
				_ok("② 전역 bar 면 바를 튼다 · 인트로 단 안", g.plg_mod == g.PlgBar and g._plg_live()
						and g.state == g.S.INTRO)
				_ok("② 무대 · 층은 화판 밖", g.plg_vp != null and g.plg_vp.get_parent() == b)
				var hn: Node = g.plg_vp
				var tl: Array = hn.get_meta("tvl", [])
				var L: Dictionary = hn.get_meta("L", {})
				var pend_ok: bool = (L.get("pend", []) as Array).size() == 3
				for p in L.get("pend", []):
					pend_ok = pend_ok and ((p as Light3D).light_cull_mask & P.L_MERCH) != 0
				_ok("③ TV 빛은 상인 층을 안 비춘다 · 펜던트 셋은 비춘다", tl.size() == 2 and pend_ok
						and ((tl[0] as Light3D).light_cull_mask & P.L_MERCH) == 0
						and ((tl[1] as Light3D).light_cull_mask & P.L_MERCH) == 0)
				_ok("③ 상인 · TV · 손님 잔이 섰다", hn.has_meta("merch") and hn.get_meta("scr") != null
						and hn.has_meta("end"))
				bus_seen = AudioServer.get_bus_index((hn as Node).get("bus")) >= 0
				st = 1
		1:
			if g._plg_live():
				var hn: Node = g.plg_vp
				var P = g.PlgBar
				var t: float = g.plg_t
				if g._plg_cover():
					cover_ok = cover_ok and not (g.crt_layer.visible or g.vhs_rect.visible or g.dot_rect.visible)
				spk_seen = spk_seen or _sfx_fx() >= fx0 + 3
				#  ⑦ 유리 뚫기 — 틀마다 유리 재질 · 층 · 필터를 본다
				var hf: float = P.handoff()
				var sm: ShaderMaterial = hn.get_meta("scr")
				if gl0 < 0.0 and float(sm.get_shader_parameter("glint")) > -1.0:
					gl0 = t
				if int(sm.get_shader_parameter("spark")) > 0:
					sp1 = t
				var rt := hn.get_meta("root") as Control
				var fl := rt.get_node("Flash") as CanvasItem
				if fl.visible and int((fl.material as ShaderMaterial).get_shader_parameter("pn")) > 2:
					fk0 = t if fk0 < 0.0 else fk0
					fk1 = t
				elif fl.visible:
					fl0 = t if fl0 < 0.0 else fl0
					fl1 = t
				if g.crt_layer.visible and lit0 < 0.0:
					lit0 = t
				if g.crt_layer.visible and t < P.calm_at():
					var tr = (g.crt_rect.material as ShaderMaterial).get_shader_parameter("trail")
					trail_ok = trail_ok and tr != null and float(tr) == 0.0
				if t >= hf + 0.5 / 60.0:
					for c in rt.get_children():
						cut_ok = cut_ok and (c == fl or not (c as CanvasItem).visible)
				if t >= P.glint_at():
					spk_late = spk_late or _sfx_fx() > fx0
				if sign_snd < 0.0 and g.intro_rang.has("sign"):
					sign_snd = t
				if t < P.feed_at() - 0.05:
					early_intro = early_intro or g.intro_t > 0.0
				else:
					late_intro = g.intro_t
				if t > float(P.SIGN.t0) + 0.3 and t < P.handoff():
					sign_on = sign_on or g.plg_sign_t >= float(P.SIGN.from)
				if t > P.handoff() + 0.05:
					sign_late = sign_late or g.plg_sign_t >= 0.0
				#  상인 깃 위(목 · 머리 자리) — 다이브 앞 모든 틀에서 그림 밖
				var mn: Node3D = (hn.get_meta("merch") as Dictionary).n if hn.has_meta("merch") else null
				if mn != null and mn.visible:
					var M: Dictionary = hn.get_meta("merch")
					for sd in ["R", "L"]:
						var hx: Vector3 = ((M.hj[sd] as Dictionary).root as Node3D).transform.basis.x
						var fx: Vector3 = ((M.fo[sd] as Dictionary).root as Node3D).transform.basis.x
						wrist_max = maxf(wrist_max, rad_to_deg(hx.angle_to(fx)))
					if t >= float(P.POLISH.down[0]):
						var top: float = (mn.global_transform * (P.MERCH.down as Vector3)).y
						var parts: Array = ((M.hj.L as Dictionary).root as Node).find_children("*", "MeshInstance3D", true, false)
						if (M.tail as Node3D).visible:
							parts.append(M.tail)
						for mi in parts:
							if (mi as MeshInstance3D).is_visible_in_tree():
								var ab: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
								down_low = minf(down_low, ab.position.y - top)
						down_n += 1
				if t < float(P.T.dive0) and mn != null and mn.visible:
					var cam := hn.get_meta("cam") as Camera3D
					head_n += 1
					for y in [1.56, 1.66, 1.78]:
						for x in [-0.08, 0.0, 0.08]:
							if cam.is_position_in_frustum(mn.global_transform * Vector3(x, y, 0.04)):
								head_in += 1
								head_t = [t] if head_t.is_empty() else [head_t[0], t]
								break
			else:
				_ok("② 덮개 동안 CRT · VHS · 도트가 꺼져 있다", cover_ok)
				_ok("② 인트로 시계 — TV 가 그림을 틀기 전엔 안 가고 그 뒤로 간다", not early_intro and late_intro > 2.0,
						"%.2f" % late_intro)
				_ok("③ 상인 깃 위는 그림 밖", head_n > 100 and head_in == 0, "%d / %d 틀 %s" % [head_in, head_n, str(head_t)])
				_ok("③ 손목 — 손끝 축이 팔뚝 축에서 35° 안", head_n > 100 and wrist_max <= 35.0, "%.1f°" % wrist_max)
				_ok("③ 잔 내려놓기 — 받치는 손 · 천 꼬리가 카운터 위", down_n > 20 and down_low >= -0.002,
						"%d 틀 · 가장 낮은 밑끝 %+.1f cm" % [down_n, down_low * 100.0])
				_ok("④ TV 간판 — 밀기 동안 켜지고 넘김 뒤 · 끝에 안 남는다", sign_on and not sign_late and g.plg_sign_t < 0.0)
				_ok("④ 로패스 버스가 섰다가 걷혔다", bus_seen and _no_bar_bus())
				_ok("④ TV 스피커 효과가 섰다가 걷혔다", spk_seen and _sfx_fx() == fx0, "%d → %d" % [fx0, _sfx_fx()])
				_ok("④ 끝 — 무대가 걷히고 인트로가 이어진다", g.plg_vp == null and g.state == g.S.INTRO
						and g.intro_t >= late_intro - 0.01, "intro %.2f" % g.intro_t)
				#  ⑦ 때는 틀 단위 — 창 실행이라 틀이 빠질 수 있어 3 틀까지 본다
				var P = g.PlgBar
				var Pg = g.Plg
				var hf: float = P.handoff()
				var fr := 1.0 / 60.0
				var cr: Array = P.DIVE.creep
				var mp: Array = P.MOVE[3]
				var l0: float = float(P.T.dive0) + float(cr[2]) * (float(P.T.dive1) - float(P.T.dive0))
				_ok("⑦ 유리 뚫기 — 반짝 때 · 삐싱 소리 없음 · 밀기 끝 = 뛰어듦 시작 · 다가감 몫", is_equal_approx(P.glint_at(),
						hf - float(Pg.GLINT.cue)) and P.cues().is_empty()
						and absf(float(mp[0]) + float(mp[1]) - l0) < fr and Pg.dive_w(float(cr[2]), cr) == 0.0
						and is_equal_approx(Pg.dive_w(1.0, cr), 1.0) and P.lit_at() < hf and P.lit_at() > hf - fr
						and P.calm_at() > hf + 6.0 * fr, "반짝 %.3f · 뛰어듦 %.3f" % [P.glint_at(), l0])
				_ok("⑦ 빗금 · 별 · 번쩍(오름 단은 유리 둘레 안 · 맨 밝은 틀부터 화면) · 필터 때",
						absf(gl0 - (hf - float(Pg.GLINT.lead) * fr)) <= 3.0 * fr
						and sp1 > 0.0 and sp1 < hf - 4.0 * fr and fk0 >= hf - 4.5 * fr and fk1 < hf
						and fl0 >= hf - 0.5 * fr and fl0 < hf + 3.0 * fr
						and fl1 < hf + 6.0 * fr and lit0 >= P.lit_at() and lit0 < hf + 3.0 * fr,
						"빗금 H%+.0f · 별 끝 H%+.0f · 유리 번쩍 H%+.0f~H%+.0f · 화면 번쩍 H%+.0f~H%+.0f · 필터 H%+.0f 틀" % [
						(gl0 - hf) / fr, (sp1 - hf) / fr, (fk0 - hf) / fr, (fk1 - hf) / fr, (fl0 - hf) / fr, (fl1 - hf) / fr,
						(lit0 - hf) / fr])
				#  인트로 박자 — 램프 딸깍은 TV 앞 깜박임 뒤 · 쾅은 번쩍 · 잔상이 걷힌 뒤 게임 속 · TV 그림의 소리(램프 · 꺼짐 · 쾅)는
				#  반짝 쉬익 ~ 잔상 창 밖 · 간판 소리는 이 장면이 간판을 켜는 때(SIGN.t0)
				var IN: Dictionary = g.INTRO
				var fa: float = P.feed_at()
				var lid: Array = P.LID
				var snap: float = fa + float(IN.snap) + float(IN.snap_t)
				var w0: float = P.glint_at() - float(P.SND.tv_out)
				var beat_ok: bool = fa + float(IN.lamp) > float(lid[lid.size() - 1][0]) and snap > P.calm_at()
				for bt in [fa + float(IN.lamp), fa + float(IN.off), snap]:
					beat_ok = beat_ok and (bt < w0 or bt > P.calm_at())
				_ok("⑦ 인트로 박자 — 램프는 깜박임 뒤 · 쾅은 건넌 뒤 따로 · 건너기 창에 TV 그림 소리 없음",
						beat_ok and sign_snd >= float(P.SIGN.t0) - fr and sign_snd < float(P.SIGN.t0) + 3.0 * fr,
						"램프 %.2f · 쾅 %.2f(H%+.0f) · 간판 소리 %.2f" % [fa + float(IN.lamp), snap, (snap - hf) / fr, sign_snd])
				_ok("⑦ 잔상 calm 까지 0 · 넘김 뒤 층은 번쩍만 · 반짝에 TV 스피커가 걷힌다", trail_ok and cut_ok and not spk_late)
				st = 2
				f = 0
		2:
			if f == 30:
				g._plg_begin("bar")
				g.plg_t = float(g.PLGP.lock) + 0.01
				g._intro_press()
				_ok("⑤ 첫 누름은 빨리 감기", g._plg_live() and g.plg_ff)
				g.plg_t = float(g.PlgBar.feed_at()) + 0.5
				g._plg_tick(0.0)
				_ok("⑤ 그림이 비치는 동안 TV 스피커가 걸린다", _sfx_fx() == fx0 + 3)
				g._intro_press()
			if f == 34:
				_ok("⑤ 둘째 누름 끝 — 무대 · 버스 · 효과가 안 남는다", not g._plg_live() and g.plg_vp == null
						and _no_bar_bus() and _sfx_fx() == fx0, "효과 %d" % _sfx_fx())
				#  ⑥ 개발자 판
				var pg0: int = Dev.page
				var found := {}
				var rows_ok := true
				for pg in Dev.PAGES.size():
					Dev.page = pg
					var rs: Array = Dev._rows(g)
					rows_ok = rows_ok and rs.size() <= 19
					for r in rs:
						var a := String((r as Dictionary).get("a", ""))
						if a in ["plg_bar", "plg_kind"]:
							found[a] = pg
				Dev.page = pg0
				_ok("⑥ 개발자 판 줄 둘 · 쪽마다 열아홉 줄 안", found.size() == 2 and rows_ok, str(found))
				Save.set_set("plg_kind", "tape")
				Dev._run(g, {"t": "act", "a": "plg_kind"})
				var k1 := String(Save.get_set("plg_kind", ""))
				Dev._run(g, {"t": "act", "a": "plg_kind"})
				_ok("⑥ 켤 때 인트로 줄이 전역 값을 바꾼다", k1 == "bar" and String(Save.get_set("plg_kind", "")) == "tape")
				Dev._run(g, {"t": "act", "a": "plg_bar"})
				_ok("⑥ 「바 인트로 보기」가 바를 튼다", g._plg_live() and g.plg_mod == g.PlgBar)
				g._plg_end()
			if f == 40:
				_ok("⑥ 끝내면 버스가 안 남는다", _no_bar_bus() and _sfx_fx() == fx0)
				#  ⑧ 런 끝 — 「새 런」이 바를 틀고(제목행) · 끝나면 인트로 나머지 없이 제목 문
				g.state = g.S.OVER
				g.tut_run = false
				g.won = false
				g._open_newrun()
				_ok("⑧ 런 끝 「새 런」 — 바가 돈다 · 끝나면 제목으로", g._plg_live() and g.plg_mod == g.PlgBar
						and g.plg_title and g.state == g.S.INTRO)
				g.plg_t = float(g.PLGP.lock) + 0.01
				g._intro_press()
				g._intro_press()
				_ok("⑧ 건너뛰면 곧장 제목 문 · 바가 안 남는다", not g._plg_live() and not g.plg_title
						and g.state == g.S.TITLE, "state %d" % g.state)
			if f == 46:
				_ok("⑧ 끝내면 버스가 안 남는다", _no_bar_bus() and _sfx_fx() == fx0)
				print("통과 %d · 실패 %d" % [ok, bad])
				quit(1 if bad > 0 else 0)
	if f > 3000:
		print("  시간 끝")
		quit(1)
	return false


func _no_bar_bus() -> bool:
	for i in AudioServer.bus_count:
		if AudioServer.get_bus_name(i).begins_with("BarAmb"):
			return false
	return true
