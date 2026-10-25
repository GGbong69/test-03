extends SceneTree
#  바 인트로 촬영(scripts/prologue_bar3d.gd · 2026-10-25) — 실제 게임처럼 scenes/boot.tscn 을 열고(제 저장 자리) 바 인트로를
#  틀어, 정한 때의 스틸을 창 크기 그대로 찍는다. 넘김 뒤 2 초(게임 인트로)까지 돌고 닫는다.
#  영상은 Movie Maker 로 같이 굽는다(틀 · 소리) — 시작 틀 번호를 찍어 두니 그 앞을 잘라 쓴다.
#  틀마다 무대 카메라를 적어 두고 끝에 잰다(<스틸 폴더>/motion.txt · GATE 줄) — 「사람의 시야」 · 「TV 가 중앙」(개발자):
#    ① 눈길 각속도 — 어느 틀도 45°/s 를 안 넘고 · 길마다 첫 · 끝 틀은 5°/s 아래(덜컥 붙거나 딱 서지 않는다). 다이브는
#       유리 속으로 빨려 드는 효과라 따로 적기만 한다.
#    ② TV 유리 한가운데가 그림 한가운데 — TV 가 다 들어온 뒤(멈춤 · 밀기 · 다이브) |dx| · |dy| ≤ 그림 폭 · 높이의 5%.
#    ③ 다가감 빠르기(틀당 그림이 커지는 몫 — 거리 · 화각) — 뛰어듦 앞은 어느 틀도 Z_MAX 를 안 넘고(밀기는 천천히) ·
#       뛰어듦(Plg dive_w 세제곱)은 handoff 까지 줄지 않고 는다(유리 앞에서 서지 않고 뚫는다).
#  <스틸 폴더>/tmap.txt — 그린 틀마다 [틀 번호 · plg_t · 유리까지 거리 · 화각 · glint · spark · portal · 번쩍 단 ·
#  CRT · VHS · 도트 켜짐] — Movie Maker 그림 번호는 틀 번호 − 1. 게임 필터는 처음 켠 값(CRT_DEF …)으로 찍는다.
#   godot --path . --resolution 1280x720 --fixed-fps 60 [--write-movie <폴더>/m.png] \
#       --script scripts/tools/shot_barintro.gd -- <스틸 폴더> [때,때,…]
const Save = preload("res://scripts/save.gd")
const TIMES := [1.0, 2.0, 2.8, 7.3, 10.8, 13.7, 15.3, 16.3]
const W_MAX := 45.0
const W_EDGE := 5.0
const C_MAX := 0.05
const J_MAX := 2.0
const Z_MAX := 0.01
var b: Node = null
var g: Node = null
var f := 0
var drawn := 0
var out := ""
var times: Array = TIMES
var done := {}
var started := false
var ended := false
var last_t := 0.0
var after := 0.0
var rec := []            # [t, 카메라 basis, 화면 한가운데 dx, dy, TV 다 들어옴, 유리까지 거리, 화각]
var tmap := []


func _initialize() -> void:
	Save.gpath = "user://_bi_g.cfg"
	Save.path = "user://_bi.cfg"
	Save.prof_fmt = "user://_bi_%d.cfg"
	Save.wipe()
	var a := OS.get_cmdline_user_args()
	out = a[0] if a.size() > 0 else OS.get_user_data_dir().path_join("barintro")
	if a.size() > 1:
		times = []
		for s in String(a[1]).split(","):
			times.append(float(s))
	DirAccess.make_dir_recursive_absolute(out)
	b = load("res://scenes/boot.tscn").instantiate()
	root.add_child(b)
	RenderingServer.frame_post_draw.connect(_post)


func _process(d: float) -> bool:
	f += 1
	if DisplayServer.get_name() == "headless":
		print("창이 있어야 찍힌다")
		quit(1)
		return false
	if f == 10:
		g = b.game
		#  게임 필터는 처음 켠 값으로(도구는 끈 채 뜬다) — 번쩍의 맨 밝은 틀에 켜지는 것까지 찍는다
		g.crt = g.CRT_DEF
		g.warp = g.WARP_DEF
		g.vhs = g.VHS_DEF
		g.dot = g.DOT_DEF
		g._plg_begin("bar")
		started = true
		print("START_FRAME %d" % drawn)
	if started and not g._plg_live():
		if not ended:
			ended = true
			print("END_FRAME %d" % drawn)
			_report()
		after += d
		if after > 2.0:
			print("DONE_FRAME %d" % drawn)
			quit(0)
	return false


func _post() -> void:
	drawn += 1
	if not started:
		return
	var t: float = g.plg_t if g._plg_live() else last_t + after
	if g._plg_live():
		last_t = t
		_track(t)
	for tt in times:
		var k := "%.2f" % float(tt)
		if t >= float(tt) - 0.001 and not done.has(k):
			done[k] = true
			var im := root.get_texture().get_image()
			im.save_png(out.path_join("still_%s.png" % k))


#  무대 카메라 한 틀 — basis · TV 유리 한가운데의 그림 자리(그림 폭 · 높이 몫) · 유리 네 귀가 다 그림 안인가
func _track(t: float) -> void:
	var hn: Node = g.plg_vp
	if hn == null or not hn.has_meta("cam"):
		return
	var P = g.PlgBar
	var cam := hn.get_meta("cam") as Camera3D
	var vs := Vector2((hn.get_meta("vp") as SubViewport).size)
	var G: Dictionary = P._tv_glass()
	var c: Vector3 = G.c
	var dx := 9.0
	var dy := 9.0
	var full := false
	if not cam.is_position_behind(c):
		var sp := cam.unproject_position(c)
		dx = sp.x / vs.x - 0.5
		dy = sp.y / vs.y - 0.5
		full = true
		var gb: AABB = G.gb
		var gx: Transform3D = G.xf
		for cx in [gb.position.x, gb.end.x]:
			for cy in [gb.position.y, gb.end.y]:
				var w: Vector3 = gx * Vector3(cx, cy, gb.end.z)
				var q := cam.unproject_position(w)
				full = full and not cam.is_position_behind(w) and Rect2(Vector2.ZERO, vs).has_point(q)
	var dd: float = cam.global_position.distance_to(c)
	rec.append([t, cam.global_transform.basis.orthonormalized(), dx, dy, full, dd, cam.fov])
	var m: ShaderMaterial = hn.get_meta("scr")
	var fl := (hn.get_meta("root") as Control).get_node("Flash") as CanvasItem
	tmap.append("%d %.4f %.4f %.2f %.3f %d %.3f %.3f %s" % [drawn, t, dd, cam.fov, float(m.get_shader_parameter("glint")),
			int(m.get_shader_parameter("spark")), float(m.get_shader_parameter("portal")),
			float((fl.material as ShaderMaterial).get_shader_parameter("k")) if fl.visible else 0.0,
			"%d%d%d" % [int(g.crt_layer.visible), int(g.vhs_rect.visible), int(g.dot_rect.visible)]])


#  두 basis 사이 각(도) — 작은 각도 정확하게(acos 는 1 언저리에서 0.02° 로 뭉개져 틀마다 0 · 2.4°/s 가 번갈았다)
static func _ang(a: Basis, b: Basis) -> float:
	var q := Quaternion(a).inverse() * Quaternion(b)
	return rad_to_deg(2.0 * atan2(Vector3(q.x, q.y, q.z).length(), absf(q.w)))


func _report() -> void:
	var P = g.PlgBar
	var lines := []
	var fail := []
	var w := []
	for i in range(1, rec.size()):
		var dt: float = float(rec[i][0]) - float(rec[i - 1][0])
		w.append([float(rec[i][0]), _ang(rec[i - 1][1], rec[i][1]) / maxf(dt, 0.0001)])
	var dive0: float = P.T.dive0
	var dive1: float = P.T.dive1
	#  ① 길마다 — 가장 빠른 틀 · 첫 · 끝 틀(움직임이 0.05°/s 넘는 첫 · 마지막 틀)
	var H: Dictionary = P.HEAD
	for mv in P.MOVE:
		var a: float = float(mv[0]) - float(H.lead)
		var e: float = minf(float(mv[0]) + float(mv[1]) + float(H.settle), dive0)
		var mx := 0.0
		var at := 0.0
		var first := -1.0
		var last := 0.0
		var jk := 0.0
		var pw := -1.0
		for r in w:
			if float(r[0]) < a or float(r[0]) > e:
				continue
			if float(r[1]) > mx:
				mx = r[1]
				at = r[0]
			if first < 0.0:
				first = r[1]
			last = r[1]
			if pw >= 0.0:
				jk = maxf(jk, absf(float(r[1]) - pw))
			pw = r[1]
		#  첫 · 끝 틀 속도(길 창 첫 · 마지막 틀) · 틀 사이 속도가 가장 크게 뛴 값(덜컥 — 60fps 한 틀에 J_MAX 넘게 붙지 않는다)
		var ok: bool = mx <= W_MAX and first <= W_EDGE and last <= W_EDGE and jk <= J_MAX
		lines.append("길 %-6s %.2f~%.2f  최고 %.1f°/s(%.2f)  첫 %.2f  끝 %.2f  틀 사이 뜀 %.2f  %s" % [mv[4], a, e, mx, at, first,
				last, jk, "통과" if ok else "실패"])
		if not ok:
			fail.append(String(mv[4]))
	var over := 0
	var dmx := 0.0
	for r in w:
		if float(r[0]) >= dive0:
			dmx = maxf(dmx, r[1])
		elif float(r[1]) > W_MAX:
			over += 1
	lines.append("다이브 앞 45°/s 넘는 틀 %d · 다이브 최고 %.1f°/s(효과 — 따로 적기만)" % [over, dmx])
	var sp := []
	for i in range(1, w.size()):
		if float(w[i][0]) < dive0 and absf(float(w[i][1]) - float(w[i - 1][1])) > J_MAX:
			sp.append("%.3f:%.1f→%.1f" % [w[i][0], w[i - 1][1], w[i][1]])
	lines.append("틀 사이 뜀(다이브 앞) %d %s" % [sp.size(), " ".join(sp.slice(0, 12))])
	if not sp.is_empty():
		fail.append("jerk")
	if over > 0:
		fail.append("over")
	#  ② TV 한가운데 — 올려다보기가 선 뒤(멈춤 · 밀기 · 다이브)
	var mv2: Array = P.MOVE[2]
	var c0: float = float(mv2[0]) + float(mv2[1]) + float(H.settle)
	var cx := 0.0
	var cy := 0.0
	var n := 0
	var full := true
	for r in rec:
		if float(r[0]) < c0 or float(r[0]) > dive1:
			continue
		n += 1
		cx = maxf(cx, absf(float(r[2])))
		cy = maxf(cy, absf(float(r[3])))
		full = full and bool(r[4]) if float(r[0]) < dive0 else full
	var cok: bool = n > 30 and cx <= C_MAX and cy <= C_MAX and full
	lines.append("TV 한가운데 %.2f~%.2f  틀 %d  |dx| 최대 %.3f  |dy| 최대 %.3f  다이브 앞 유리 다 듦 %s  %s" % [c0, dive1, n, cx, cy,
			str(full), "통과" if cok else "실패"])
	if not cok:
		fail.append("tv")
	#  ③ 다가감 빠르기 — 틀당 그림이 커지는 몫 z = ln(앞 틀 거리 · tan(화각/2) ÷ 이 틀 것). 밀기 시작 ~ 뛰어듦 앞 · 뛰어듦
	var l0: float = dive0 + float(P.DIVE.creep[2]) * (dive1 - dive0)
	var zmx := 0.0
	var zat := 0.0
	var zdrop := 0
	var pz := -1.0
	var zl := []
	for i in range(1, rec.size()):
		var t1: float = rec[i][0]
		if t1 < float(P.MOVE[3][0]) or t1 >= dive1:
			continue
		var z: float = log(float(rec[i - 1][5]) * tan(deg_to_rad(float(rec[i - 1][6])) * 0.5)
				/ (float(rec[i][5]) * tan(deg_to_rad(float(rec[i][6])) * 0.5)))
		if t1 < l0:
			if z > zmx:
				zmx = z
				zat = t1
		else:
			if pz >= 0.0 and z < pz - 0.00001:
				zdrop += 1
			pz = z
			zl.append("%.3f:%.2f" % [t1, z * 100.0])
	var zok: bool = zmx <= Z_MAX and zdrop == 0 and pz > 0.05
	lines.append("다가감 밀기 최고 %.2f%%/틀(%.2f) · 뛰어듦 %.3f~ 줄어든 틀 %d · 끝 틀 %.1f%%  %s" % [zmx * 100.0, zat, l0, zdrop,
			pz * 100.0, "통과" if zok else "실패"])
	lines.append("뛰어듦(%/틀) " + " ".join(zl))
	if not zok:
		fail.append("zoom")
	#  TV 가 들어오는 길(올려다보기)에서 한가운데로 가는 모양 — 0.25 초마다
	var tl := []
	for r in rec:
		var tt: float = r[0]
		if tt >= float(mv2[0]) and tt <= dive1 and absf(tt * 4.0 - roundf(tt * 4.0)) < 0.009:
			tl.append("%.2f:(%+.3f,%+.3f)" % [tt, r[2], r[3]])
	lines.append("TV 자리 " + " ".join(tl))
	var ws := []
	for r in w:
		if absf(float(r[0]) * 10.0 - roundf(float(r[0]) * 10.0)) < 0.009:
			ws.append("%.1f:%.0f" % [r[0], r[1]])
	lines.append("각속도(°/s) " + " ".join(ws))
	lines.append("GATE %s" % ("통과" if fail.is_empty() else "실패 " + ",".join(fail)))
	var fh := FileAccess.open(out.path_join("motion.txt"), FileAccess.WRITE)
	for l in lines:
		print(l)
		if fh != null:
			fh.store_line(l)
	var th := FileAccess.open(out.path_join("tmap.txt"), FileAccess.WRITE)
	if th != null:
		th.store_string("\n".join(tmap) + "\n")
