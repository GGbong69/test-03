extends SceneTree
# 문이 열릴 때 제목 판의 자루(2026-10-11 · game.gd _ttl3_open_pose) — 못 박는 것:
#   ① 여는 정도마다 촉이 2D 판이 그 착탄점을 그리는 화면 자리에 투영된다(문 카메라 · 다가간 몫 · 옆 몫)
#   ② 촉이 돈 문 판면 위다(경첩째 돈 판 한가운데 · 문짝 법선)
#   ③ 여는 정도 open_axis 부터 몸은 문짝 법선과 나란하다 · 닫힌 문(0)에서는 옛 자세 그대로
#   ④ 자루 길이 · 굵기(배율)는 그대로다
#   ⑤ 판에 진 2D 그림자는 open_shade 에서 다 진다
#   godot --headless --path . --script scripts/tools/qa_dopen.gd
const Save = preload("res://scripts/save.gd")
const Door3D = preload("res://scripts/door3d.gd")
var g = null
var ok := 0
var bad := 0
var busy := false


func _initialize() -> void:
	Save.gpath = "user://_qa_dopen_g.cfg"
	Save.path = "user://_qa_dopen.cfg"
	Save.prof_fmt = "user://_qa_dopen_%d.cfg"
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


func _hinge(k: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, deg_to_rad(float(Door3D.DOOR.open_deg) * k)), g._ttl3_hinge_at())


func _run() -> void:
	var D: Dictionary = Door3D.DOOR
	var T: Dictionary = g.TTL
	var pts := [Vector2(-70, -70), Vector2(75, -60), Vector2(80, 50), Vector2(-60, 70), Vector2(0, 0)]
	var worst := 0.0
	var plane := 0.0
	var axis_bad := 0.0
	var len_bad := 0.0
	g.state = g.S.TITLE
	g.door_k0 = 0.0
	for t in [0.05, 0.12, 0.25, 0.4, 0.6, 0.9, 1.1]:
		g.door_t = t
		var dk: float = g._door_k()
		var hx := _hinge(dk)
		for o in pts:
			var lp: Vector2 = g.BC + o
			var p0: Transform3D = g._ttl3_pose(lp, g._ttl3_jit(lp))
			var pw: Transform3D = g._ttl3_open_pose(p0, lp, dk, hx)
			var sc: float = pw.basis.x.length()
			var ln: float = float(g.BD3.len) * sc
			var yv: Vector3 = pw.basis.y.normalized()
			var tip: Vector3 = pw.origin - yv * ln * 0.5
			# ①
			var s: Vector2 = g._door_set_mat(Vector2.ZERO) * lp
			var pr: Vector2 = Door3D.proj(tip, g.BC, g._door_dz(), g._door_cam())
			worst = maxf(worst, pr.distance_to(s))
			# ②
			var q: Vector3 = hx * (Vector3(float(D.bx), float(D.by), 0.0) - g._ttl3_hinge_at())
			var nv: Vector3 = hx.basis * Vector3(0.0, 0.0, 1.0)
			plane = maxf(plane, absf(nv.dot(tip - q)))
			# ③
			if dk >= float(T.open_axis):
				axis_bad = maxf(axis_bad, 1.0 - absf(yv.dot(nv)))
			# ④
			len_bad = maxf(len_bad, absf(sc - p0.basis.x.length()))
	_ok("① 촉이 2D 판의 그 자리에 투영된다", worst < 0.05, "최대 %.4f px" % worst)
	_ok("② 촉이 돈 문 판면 위", plane < 0.0001, "최대 %.6f m" % plane)
	_ok("③ open_axis 부터 몸이 문짝 법선과 나란하다", axis_bad < 0.001, "1−cos %.5f" % axis_bad)
	_ok("④ 자루 배율 그대로", len_bad < 0.000001)
	g.door_t = -1.0
	g.door_peek = 0.0
	_ok("③ 닫힌 문 — 여는 정도 0(옛 자세 그대로 쓴다)", g._door_k() == 0.0)
	var src: String = FileAccess.get_file_as_string("res://scripts/game.gd")
	_ok("③ 여는 동안만 새 자세 — 닫히면 옛 hinv 자세", src.contains("if dk > 0.0:\n\t\t\t#  문이 열리는 중")
			and src.contains("n0.transform = hinv * pose"))
	_ok("⑤ 판 그림자가 open_shade 에서 진다", src.contains("1.0 - smoothstep(0.0, float(TTL.open_shade), _door_k())"))
