extends SceneTree
# 게이지 걸림(2026-10-10 · game.gd _set_slide · SETDET) — 못 박는 것:
#   ① 10 의 둘레(pull) 안으로 끌면 그 값에 앉는다.
#   ② 둘레 밖은 1 단위로 그대로 흐른다.
#   ③ 걸림에 드는 순간 톡 한 알 · 같은 걸림 안에서 더 끌면 안 난다 · 다음 걸림에서 또 난다.
#   ④ 걸림 사이를 끄는 동안 음량 톡이 안 난다(걸림 톡이 맡는다 · 겹침 없음).
#   ⑤ 누르는 순간은 누름 톡 하나뿐이다(걸림 자리에 눌러도 둘이 안 난다).
#   ⑥ 음악 · 화면 게이지에도 걸린다.
#   godot --headless --path . --script scripts/tools/qa_setdet.gd
const Save = preload("res://scripts/save.gd")
var g = null
var ok := 0
var bad := 0
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_qa_setdet_g.cfg"
	Save.path = "user://_qa_setdet.cfg"
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
	print("  %s %-46s %s" % ["통과" if cond else "실패", nm, note])


func _snd(cb: Callable) -> Array:
	var pool: int = maxi((g.sfx_pool as Array).size(), 1)
	var prev: int = g.sfx_next
	cb.call()
	var dn: int = posmod(int(g.sfx_next) - prev, pool)
	var out := []
	for k in dn:
		var pi: int = posmod(prev + k, pool)
		var st = (g.sfx_pool[pi] as AudioStreamPlayer).stream
		out.append("" if st == null
				else String(st.resource_path).get_file().get_basename())
	return out


func _page(pg: String) -> void:
	g.state = g.S.SETTINGS
	g.pause_from = -1
	g._set_go(pg)
	g.set_t = 1.0
	g.set_pg_t = 1.0


func _at(tr: Rect2, v: float) -> Vector2:
	return Vector2(tr.position.x + tr.size.x * v, tr.get_center().y)


func _run() -> void:
	_page("sound")
	var rows: Array = g._set_rows()
	var vi: int = rows.find("vol")
	var tr: Rect2 = g._vol_track(vi)
	print("  홈 폭 %.0fpx · 걸림 둘레 %.1fpx" % [tr.size.x, tr.size.x * float(g.SETDET.pull)])
	g.vol = 0.5
	g.vol_snd_ms = 0

	# ⑤ 누름 — 걸림 자리(0.30)
	var s0 := _snd(func(): g._click(_at(tr, 0.30)))
	_ok("⑤ 걸림 자리를 눌러도 톡 하나", s0 == ["menu_pick2"] and g.set_drag == vi, str(s0))
	_ok("① 누른 자리가 걸림이면 그 값", is_equal_approx(g.vol, 0.30), "%.2f" % g.vol)

	# ① · ③ 걸림 둘레
	var s1 := _snd(func(): g._set_slide(vi, _at(tr, 0.318)))
	_ok("① 둘레 안(0.318)은 0.30 에 앉는다", is_equal_approx(g.vol, 0.30), "%.2f" % g.vol)
	_ok("③ 같은 걸림 안에서는 톡이 없다", s1.is_empty(), str(s1))

	# ② · ④ 걸림 사이
	g.vol_snd_ms = 0
	var s2 := _snd(func():
			for k in 6:
				g._set_slide(vi, _at(tr, 0.335 + 0.006 * float(k))))
	_ok("② 둘레 밖(0.365)은 1 단위로 흐른다", is_equal_approx(g.vol, 0.37)
			or is_equal_approx(g.vol, 0.36), "%.2f" % g.vol)
	_ok("④ 걸림 사이를 끄는 동안 톡이 없다", s2.is_empty(), str(s2))

	# ③ 다음 걸림
	var s3 := _snd(func(): g._set_slide(vi, _at(tr, 0.39)))
	_ok("③ 다음 걸림(0.39 → 0.40)에 들면 톡", s3 == ["menu_pick2"] and is_equal_approx(g.vol, 0.40),
			"%s · %.2f" % [str(s3), g.vol])
	var s4 := _snd(func(): g._set_slide(vi, _at(tr, 0.41)))
	_ok("③ 그 걸림 안에서 더 끌면 안 난다", s4.is_empty() and is_equal_approx(g.vol, 0.40),
			"%s · %.2f" % [str(s4), g.vol])
	g._set_slide(vi, _at(tr, 0.45))
	var s5 := _snd(func(): g._set_slide(vi, _at(tr, 0.41)))
	_ok("③ 나갔다 같은 걸림에 다시 들면 또 톡", s5 == ["menu_pick2"], str(s5))
	g._set_slide_end()
	_ok("떼면 걸림 기억을 비운다", g.set_det == -1 and g.set_drag == -1)

	# ⑥ 음악 · 화면
	var mi: int = rows.find("mus")
	var mt: Rect2 = g._vol_track(mi)
	g.set_drag = mi
	g._set_slide(mi, _at(mt, 0.684))
	_ok("⑥ 음악 게이지도 걸린다(0.684 → 0.70)", is_equal_approx(g.vol_mus, 0.70), "%.2f" % g.vol_mus)
	g._set_slide_end()
	_page("screen")
	var srows: Array = g._set_rows()
	var ci: int = srows.find("crt")
	if ci >= 0:
		var ct: Rect2 = g._vol_track(ci)
		g.set_drag = ci
		g._set_slide(ci, _at(ct, 0.217))
		_ok("⑥ 화면 게이지도 걸린다(0.217 → 0.20)", is_equal_approx(g.crt, 0.20), "%.2f" % g.crt)
		g._set_slide_end()
	else:
		_ok("화면 쪽에 CRT 게이지가 있다", false, str(srows))
