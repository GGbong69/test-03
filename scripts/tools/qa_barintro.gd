extends SceneTree
#  바 인트로(scripts/prologue_bar3d.gd · game.gd PLGP.kind · 2026-10-25) — 창이 있어야 돈다. 못 박는 것:
#    ① 같은 API(make · tick · cues · handoff · feed_at · length) — feed_at < handoff < length · 켤 때 기본은 테이프
#    ② 전역 "plg_kind" 가 bar 면 _plg_begin() 이 바를 튼다 · 인트로 단 안 · 무대 · 층은 화판 밖 · 덮개 동안 필터가 꺼진다
#    ③ 상인 머리(깃 위)는 서 있는 동안 어느 틀에도 그림 안에 안 든다 · TV 빛은 상인 층을 안 비춘다 · 펜던트는 비춘다
#    ④ 로패스 버스가 섰다가 넘김에 걷히고 · TV 스피커 효과(SFX)도 걷힌다 · 끝까지 가면 인트로가 이어진다
#    ⑤ 누름 — 첫 누름 빨리 감기 · 둘째 누름 끝 → 버스 · 효과 · 무대가 안 남는다
#    ⑥ 개발자 판 — 「바 인트로 보기」 · 「켤 때 인트로」 줄이 있고 그 쪽이 열아홉 줄 안 · 켤 때 인트로 줄이 전역 값을 바꾼다
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
var bus_seen := false
var spk_seen := false
var fx0 := 0               # 처음 SFX 효과 수
var cover_ok := true
var late_intro := 0.0
var early_intro := false


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
						and P.cues() is Dictionary and g.Plg.length() > 0.0)
				_ok("① 켤 때 기본은 테이프", String(Save.get_set("plg_kind", g.PLGP.kind)) == "tape")
				fx0 = _sfx_fx()
				Save.set_set("plg_kind", "bar")
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
				if t < P.feed_at() - 0.05:
					early_intro = early_intro or g.intro_t > 0.0
				else:
					late_intro = g.intro_t
				#  상인 깃 위(목 · 머리 자리) — 다이브 앞 모든 틀에서 그림 밖
				var mn: Node3D = (hn.get_meta("merch") as Dictionary).n if hn.has_meta("merch") else null
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
				_ok("④ 로패스 버스가 섰다가 걷혔다", bus_seen and _no_bar_bus())
				_ok("④ TV 스피커 효과가 섰다가 걷혔다", spk_seen and _sfx_fx() == fx0, "%d → %d" % [fx0, _sfx_fx()])
				_ok("④ 끝 — 무대가 걷히고 인트로가 이어진다", g.plg_vp == null and g.state == g.S.INTRO
						and g.intro_t >= late_intro - 0.01, "intro %.2f" % g.intro_t)
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
